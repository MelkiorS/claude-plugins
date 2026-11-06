---
description: Switch on the statusline plugin's status line (copies the script and points statusLine at it)
---

Set up the status line from the statusline plugin. Do exactly this:

1. Copy `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-command.sh` to `~/.claude/statusline-command.sh`
   (overwrite it if it exists) and make it executable.
2. In `~/.claude/settings.json`, set the top-level `statusLine` key to:
   `{"type": "command", "command": "bash ~/.claude/statusline-command.sh"}`.
   Keep every other key as it is. If the file has a different `statusLine` already, show the user
   the old value before replacing it.
3. If editing `settings.json` is not allowed, do not work around it: show the user the exact JSON
   above and tell them to add it to `~/.claude/settings.json` themselves.
4. Tell the user the status line appears on the next refresh, and that a project's own
   `.claude/settings.json` `statusLine` takes precedence over this one.
