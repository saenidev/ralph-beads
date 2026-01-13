---
description: Cancel an active Ralph loop with Beads integration
allowed-tools:
  - Bash: test -f .claude/ralph-loop.local.md
  - Bash: rm .claude/ralph-loop.local.md
  - Bash: bd close *
  - Read: .claude/ralph-loop.local.md
---

Cancel an active Ralph loop and close the associated beads epic.

Steps:
1. Check if `.claude/ralph-loop.local.md` exists
2. If it exists:
   - Read the file to get iteration count and beads_epic_id
   - Close the beads epic with reason "Cancelled by user"
   - Remove the state file
   - Report: "Ralph loop cancelled after N iterations. Epic [ID] closed."
3. If it doesn't exist:
   - Report: "No active Ralph loop found."
