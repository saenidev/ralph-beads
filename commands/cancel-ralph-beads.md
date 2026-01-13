---
description: Cancel an active Ralph loop with Beads integration
---

# Cancel Ralph Loop

Cancel an active Ralph loop and close the associated beads epic.

## Steps

1. Check if `.claude/ralph-loop.local.md` exists using Bash: `test -f .claude/ralph-loop.local.md`

2. If it **does not exist**:
   - Report: "No active Ralph loop found."
   - Stop here.

3. If it **exists**:
   - Read the file to extract `iteration` and `beads_epic_id` from the YAML frontmatter
   - If `beads_epic_id` is not empty, close the epic:
     ```bash
     bd close "<epic_id>" --reason "Cancelled by user after N iterations"
     ```
   - Remove the state file:
     ```bash
     rm .claude/ralph-loop.local.md
     ```
   - Report: "Ralph loop cancelled after N iterations. Epic [ID] closed." (or without epic part if no epic was tracked)
