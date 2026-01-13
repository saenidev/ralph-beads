---
description: Start a Ralph loop with Beads epic tracking
argument-hint: <prompt> [--max-iterations N] [--completion-promise TEXT]
allowed-tools: ["Bash", "Write", "Read"]
---

# Ralph Loop + Beads

Start a Ralph Loop in your current session with automatic Beads epic tracking.

## Argument Parsing

Parse `$ARGUMENTS` to extract:
- **prompt**: All non-flag text (required)
- **--max-iterations N**: Maximum iterations before auto-stop (default: 0 = unlimited)
- **--completion-promise TEXT**: Promise phrase to signal completion (default: null)

If no prompt is provided, show an error and exit.

## Setup Steps

### 1. Create state directory
```bash
mkdir -p .claude
```

### 2. Check for Beads and create epic (optional)

If `.beads/` directory exists and `bd` command is available:
- Create an epic with title: `Ralph Loop: <first 60 chars of prompt>`
- Priority: 2
- Type: epic
- Description should include: prompt, max iterations, completion promise, start time
- Run: `bd create "Ralph Loop: <prompt>" -t epic -p 2 -d "<description>" --silent`
- Capture the epic ID from output

If beads is not available, continue without epic tracking.

### 3. Create state file

Write to `.claude/ralph-loop.local.md`:

```yaml
---
active: true
managed_by: ralph-beads
iteration: 1
max_iterations: <parsed value or 0>
completion_promise: <parsed value or null>
started_at: "<ISO timestamp>"
beads_enabled: <true if epic created, false otherwise>
beads_epic_id: "<epic ID or empty>"
---

<the prompt>
```

### 4. Output confirmation

Display:
```
🔄 Ralph loop activated in this session!

Iteration: 1
Max iterations: <value or "unlimited">
Completion promise: <value or "none">
Beads epic: <epic ID if created>

⚠️  WARNING: This loop cannot be stopped manually!
```

If completion promise is set, also show:
```
═══════════════════════════════════════════════════════════
CRITICAL - Ralph Loop Completion Promise

To complete this loop, output this EXACT text:
  <promise>YOUR_PROMISE_HERE</promise>

STRICT REQUIREMENTS:
  ✓ Use <promise> XML tags EXACTLY as shown above
  ✓ The statement MUST be completely TRUE
  ✓ Do NOT output false statements to exit the loop
═══════════════════════════════════════════════════════════
```

### 5. Begin working

Immediately start working on the prompt after setup completes.

The stop hook will automatically close the beads epic when the loop completes.
