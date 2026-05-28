# Claude Statusline

A custom status line for [Claude Code](https://claude.ai/code) that shows model info, context window usage, git state, session cost, and lines changed — all in two compact lines.

## Preview

```
Opus 4.8 1M MAX  │  ⎇ main ●3 ↑2  │  ⚡ AUTORUN [my-session]
ctx ████████░░░░░░░░░░░░ 42%  │  $0.42  │  +120 -34
```

**Line 1** — Model name · params · MAX mode · git branch · dirty files · ahead/behind remote · autorun badge · session name · worktree name

**Line 2** — Context window bar (green → yellow → red) · % used · session cost · lines added/removed

## Installation

1. Copy `statusline.sh` to your Claude config directory:

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

2. Open (or create) `~/.claude/settings.json` and add:

```json
{
  "statusCommand": "~/.claude/statusline.sh"
}
```

3. Restart Claude Code. The status line appears at the top of every session.

## Requirements

- `jq` — for parsing the JSON piped by Claude Code (`brew install jq`)
- `git` — for branch/dirty/ahead-behind info (usually pre-installed)

## How it works

Claude Code pipes a JSON blob to the script on each render. The script reads fields like `.model.display_name`, `.context_window.used_percentage`, `.cost.total_cost_usd`, and `.workspace.current_dir`, then prints two lines of formatted output with ANSI colors.

The cost and lines-changed fields are `0` in a fresh session and populate as you work.
