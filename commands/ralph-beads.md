---
description: Start a Ralph loop with Beads epic tracking
argument-hint: <prompt> [--max-iterations N] [--completion-promise TEXT]
allowed-tools:
  - Bash: ${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh
---

Start a Ralph Loop in your current session with automatic Beads epic tracking.

When you receive this command:
1. Execute the setup script with all provided arguments
2. The script will create a beads epic to track the loop session
3. Begin working on the prompt immediately after setup completes

The stop hook will automatically close the beads epic when the loop completes.
