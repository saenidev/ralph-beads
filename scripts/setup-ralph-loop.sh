#!/bin/bash

# Ralph Loop + Beads Setup Script
# Creates state file for in-session Ralph loop WITH beads epic tracking

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph Loop + Beads - Interactive self-referential development loop with epic tracking

USAGE:
  /ralph-beads [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop in your CURRENT session with automatic Beads epic tracking.
  Creates a beads epic to track the entire loop session.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

EXAMPLES:
  /ralph-beads Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-beads --max-iterations 10 Fix the auth bug
  /ralph-beads Refactor cache layer  (runs forever)

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  Epic is automatically closed when loop completes.
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --max-iterations requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      # Non-option argument - collect all as prompt parts
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join all prompt parts with spaces
PROMPT="${PROMPT_PARTS[*]}"

# Validate prompt is non-empty
if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "" >&2
  echo "   Examples:" >&2
  echo "     /ralph-beads Build a REST API for todos" >&2
  echo "     /ralph-beads Fix the auth bug --max-iterations 20" >&2
  exit 1
fi

# Create state file directory
mkdir -p .claude

# ============================================
# BEADS EPIC CREATION
# ============================================
EPIC_ID=""
BEADS_ENABLED="false"

# Check if beads is initialized and bd command exists
if [[ -d ".beads" ]] && command -v bd &> /dev/null; then
  # Truncate prompt for epic title (first 60 chars)
  EPIC_TITLE="Ralph Loop: ${PROMPT:0:60}"
  if [[ ${#PROMPT} -gt 60 ]]; then
    EPIC_TITLE="${EPIC_TITLE}..."
  fi

  # Build description safely (avoid shell injection from PROMPT)
  MAX_ITER_TEXT="unlimited"
  [[ $MAX_ITERATIONS -gt 0 ]] && MAX_ITER_TEXT="$MAX_ITERATIONS"
  PROMISE_TEXT="none"
  [[ "$COMPLETION_PROMISE" != "null" ]] && PROMISE_TEXT="$COMPLETION_PROMISE"

  # Use printf to safely build description without shell expansion
  EPIC_DESC=$(printf 'Automated Ralph Loop session tracking.\n\n**Prompt:** %s\n\n**Max iterations:** %s\n**Completion promise:** %s\n**Started:** %s' \
    "$PROMPT" "$MAX_ITER_TEXT" "$PROMISE_TEXT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")

  # Create the epic and capture its ID
  EPIC_ID=$(bd create "$EPIC_TITLE" -t epic -p 2 -d "$EPIC_DESC" --silent 2>/dev/null || echo "")

  if [[ -n "$EPIC_ID" ]]; then
    BEADS_ENABLED="true"
    echo "📋 Created beads epic: $EPIC_ID"
  else
    echo "⚠️  Could not create beads epic (continuing without tracking)" >&2
  fi
else
  echo "ℹ️  Beads not initialized - skipping epic tracking"
  echo "   Run '/beads:init' to enable epic tracking for future loops"
fi

# Quote completion promise for YAML with proper escaping
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  # Escape backslashes first, then double quotes for YAML
  ESCAPED_PROMISE="${COMPLETION_PROMISE//\\/\\\\}"
  ESCAPED_PROMISE="${ESCAPED_PROMISE//\"/\\\"}"
  COMPLETION_PROMISE_YAML="\"$ESCAPED_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

# Create state file with beads epic ID
# Note: managed_by field allows ralph-beads hook to identify its own loops
cat > .claude/ralph-loop.local.md <<EOF
---
active: true
managed_by: ralph-beads
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
beads_enabled: $BEADS_ENABLED
beads_epic_id: "$EPIC_ID"
---

$PROMPT
EOF

# Output setup message
cat <<EOF

🔄 Ralph loop activated in this session!

Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "$COMPLETION_PROMISE (ONLY output when TRUE!)"; else echo "none (runs forever)"; fi)
$(if [[ "$BEADS_ENABLED" == "true" ]]; then echo "Beads epic: $EPIC_ID (will be closed on completion)"; fi)

⚠️  WARNING: This loop cannot be stopped manually!

🔄
EOF

# Output the initial prompt
if [[ -n "$PROMPT" ]]; then
  echo ""
  echo "$PROMPT"
fi

# Display completion promise requirements if set
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "CRITICAL - Ralph Loop Completion Promise"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "To complete this loop, output this EXACT text:"
  echo "  <promise>$COMPLETION_PROMISE</promise>"
  echo ""
  echo "STRICT REQUIREMENTS:"
  echo "  ✓ Use <promise> XML tags EXACTLY as shown above"
  echo "  ✓ The statement MUST be completely TRUE"
  echo "  ✓ Do NOT output false statements to exit the loop"
  echo "═══════════════════════════════════════════════════════════"
fi
