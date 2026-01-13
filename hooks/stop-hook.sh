#!/bin/bash

# Ralph Loop + Beads Stop Hook
# Prevents session exit when a ralph-loop is active
# Closes beads epic when loop completes

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Check if ralph-loop is active
RALPH_STATE_FILE=".claude/ralph-loop.local.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Check if this is a ralph-beads managed loop (vs original ralph-loop)
# This prevents conflicts when both plugins are installed
if ! grep -q '^managed_by: ralph-beads' "$RALPH_STATE_FILE"; then
  # Not our loop - let the original ralph-loop handle it
  exit 0
fi

# Check for required dependencies
if ! command -v jq &> /dev/null; then
  echo "⚠️  Ralph loop: jq not found (required for hook)" >&2
  exit 0
fi
if ! command -v perl &> /dev/null; then
  echo "⚠️  Ralph loop: perl not found (required for promise detection)" >&2
  exit 0
fi

# Parse markdown frontmatter (YAML between ---) and extract values
# Use head -1 to handle potential duplicate fields gracefully
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | head -1 | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | head -1 | sed 's/max_iterations: *//')
# Extract and unescape completion promise (handles escaped quotes from YAML)
COMPLETION_PROMISE_RAW=$(echo "$FRONTMATTER" | grep '^completion_promise:' | head -1 | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
# Unescape: \" → " and \\ → \
COMPLETION_PROMISE="${COMPLETION_PROMISE_RAW//\\\"/\"}"
COMPLETION_PROMISE="${COMPLETION_PROMISE//\\\\/\\}"

# Extract beads fields with proper fallbacks (grep failure → empty → default)
BEADS_ENABLED_RAW=$(echo "$FRONTMATTER" | grep '^beads_enabled:' | head -1 | sed 's/beads_enabled: *//')
BEADS_ENABLED="${BEADS_ENABLED_RAW:-false}"
BEADS_EPIC_ID_RAW=$(echo "$FRONTMATTER" | grep '^beads_epic_id:' | head -1 | sed 's/beads_epic_id: *//' | sed 's/^"\(.*\)"$/\1/')
BEADS_EPIC_ID="${BEADS_EPIC_ID_RAW:-}"

# ============================================
# HELPER FUNCTION: Close beads epic
# ============================================
close_beads_epic() {
  local reason="$1"
  local iterations="$2"

  if [[ "$BEADS_ENABLED" == "true" ]] && [[ -n "$BEADS_EPIC_ID" ]] && command -v bd &> /dev/null; then
    bd close "$BEADS_EPIC_ID" --reason "$reason after $iterations iterations" 2>/dev/null || true
    echo "📋 Closed beads epic: $BEADS_EPIC_ID ($reason)"
  fi
}

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph loop: State file corrupted (invalid iteration)" >&2
  close_beads_epic "State corrupted" "unknown"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph loop: State file corrupted (invalid max_iterations)" >&2
  close_beads_epic "State corrupted" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Ralph loop: Max iterations ($MAX_ITERATIONS) reached."
  close_beads_epic "Max iterations reached" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Get transcript path from hook input (with proper error handling)
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ "$TRANSCRIPT_PATH" == "null" ]]; then
  echo "⚠️  Ralph loop: Invalid hook input (no transcript_path)" >&2
  close_beads_epic "Invalid hook input" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Ralph loop: Transcript file not found" >&2
  close_beads_epic "Transcript missing" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Ralph loop: No assistant messages found in transcript" >&2
  close_beads_epic "No assistant output" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  echo "⚠️  Ralph loop: Failed to extract last assistant message" >&2
  close_beads_epic "Parse error" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Parse JSON with error handling
JQ_STDERR=$(mktemp) || JQ_STDERR="/dev/null"
trap 'rm -f "$JQ_STDERR"' EXIT
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>"$JQ_STDERR")
JQ_EXIT=$?
trap - EXIT

if [[ $JQ_EXIT -ne 0 ]]; then
  echo "⚠️  Ralph loop: Failed to parse assistant message JSON" >&2
  [[ -s "$JQ_STDERR" ]] && echo "   Error: $(cat "$JQ_STDERR")" >&2
  rm -f "$JQ_STDERR"
  close_beads_epic "JSON parse error" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi
rm -f "$JQ_STDERR"

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "⚠️  Ralph loop: Assistant message contained no text content" >&2
  close_beads_epic "Empty output" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags - handles multiline content
  # Perl checks for tag existence and extracts; outputs empty if no match
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -ne '
    if (/<promise>(.*?)<\/promise>/s) {
      my $text = $1;
      $text =~ s/^\s+|\s+$//g;  # trim
      $text =~ s/\s+/ /g;       # normalize whitespace
      print $text;
    }
  ' 2>/dev/null || echo "")

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph loop: Detected <promise>$COMPLETION_PROMISE</promise>"
    close_beads_epic "Completed successfully" "$ITERATION"
    rm "$RALPH_STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Ralph loop: State file corrupted (no prompt)" >&2
  close_beads_epic "Prompt missing" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter (with secure temp file and cleanup trap)
TEMP_FILE=$(mktemp "${RALPH_STATE_FILE}.XXXXXX") || {
  echo "⚠️  Ralph loop: Failed to create temp file" >&2
  close_beads_epic "Temp file error" "$ITERATION"
  rm "$RALPH_STATE_FILE"
  exit 0
}
trap 'rm -f "$TEMP_FILE"' EXIT
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPH_STATE_FILE"
trap - EXIT  # Clear trap after successful move

# Build system message with iteration count and completion promise info
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE!)"
else
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | No completion promise - loop runs infinitely"
fi

# Add beads epic info to system message
if [[ "$BEADS_ENABLED" == "true" ]] && [[ -n "$BEADS_EPIC_ID" ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | Epic: $BEADS_EPIC_ID"
fi

# Output JSON to block the stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
