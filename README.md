# Ralph Beads

Ralph Loop + Beads integration for Claude Code. Tracks Ralph loop sessions as Beads epics for better visibility and history.

## What is this?

This plugin combines two powerful Claude Code tools:
- **[Ralph Loop](https://ghuntley.com/ralph/)** - Iterative AI development loops by Geoffrey Huntley
- **[Beads](https://github.com/steveyegge/beads)** - Git-backed issue tracker with dependency support

When you start a Ralph loop with this plugin, it automatically creates a Beads epic to track the session. When the loop completes (or is cancelled), the epic is closed with a summary.

## Installation

Copy to your Claude Code plugins directory:

```bash
cp -r . ~/.claude/plugins/local/ralph-beads/
```

Or clone directly:

```bash
git clone https://github.com/YOUR_USERNAME/ralph-beads ~/.claude/plugins/local/ralph-beads
```

Then restart Claude Code.

## Usage

### Start a Ralph loop with Beads tracking

```bash
/ralph-beads "Build a REST API" --max-iterations 20 --completion-promise "DONE"
```

Options:
- `--max-iterations <n>` - Stop after N iterations (default: unlimited)
- `--completion-promise '<text>'` - Stop when Claude outputs `<promise>TEXT</promise>`

### Cancel an active loop

```bash
/cancel-ralph-beads
```

This stops the loop and closes the Beads epic.

## How it works

1. **On Start**: Creates a Beads epic titled "Ralph Loop: \<prompt\>"
2. **During Loop**: Stop hook intercepts exit attempts and feeds the same prompt back
3. **On Complete**: Closes the epic with iteration count and completion reason

The plugin uses a `managed_by: ralph-beads` marker in the state file to avoid conflicts with the original ralph-loop plugin.

## Requirements

- **jq** - For JSON parsing
- **perl** - For promise tag extraction
- **bd** (optional) - Beads CLI for epic tracking

If Beads isn't initialized in your project, the plugin still works - it just skips epic tracking.

## Files

```
ralph-beads/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   ├── ralph-beads.md        # /ralph-beads command
│   └── cancel-ralph-beads.md # /cancel-ralph-beads command
├── hooks/
│   ├── hooks.json            # Stop hook registration
│   └── stop-hook.sh          # Loop continuation + epic closing
├── scripts/
│   └── setup-ralph-loop.sh   # Loop setup + epic creation
└── README.md
```

## Compatibility

- Designed to coexist with the original `ralph-loop` plugin
- Only processes loops it created (via `managed_by` marker)
- Falls back gracefully if Beads isn't initialized

## Credits

- Ralph Loop technique by [Geoffrey Huntley](https://ghuntley.com/ralph/)
- Beads issue tracker by [Steve Yegge](https://github.com/steveyegge/beads)

## License

MIT
