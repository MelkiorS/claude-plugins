---
description: Switch on the statusline plugin's status line for you, a project, or just you in a project
argument-hint: "[user|project|local]"
---

Set up the status line from the statusline plugin. The scope argument is: `$ARGUMENTS`

1. Pick the scope:
   - `user`, `project` or `local` given → use it.
   - Nothing (or anything else) given → ask with AskUserQuestion, one question, "Where should the
     status line be switched on?", with these options in this order:
     - **User (Recommended)**: every project on this machine, just for you.
     - **Project**: this project, for everyone who clones it (commits the script and settings).
     - **Local**: this project, just for you (not committed).

2. Do what the scope needs. `<root>` is the project root: `git rev-parse --show-toplevel`, or the
   current directory when it is not a git repository.

   | Scope | Script copied to | Settings file | `command` |
   | --- | --- | --- | --- |
   | user | `~/.claude/statusline-command.sh` | `~/.claude/settings.json` | `bash ~/.claude/statusline-command.sh` |
   | project | `<root>/.claude/statusline-command.sh` | `<root>/.claude/settings.json` | `bash "$(git rev-parse --show-toplevel 2>/dev/null \|\| pwd)/.claude/statusline-command.sh"` |
   | local | `~/.claude/statusline-command.sh` | `<root>/.claude/settings.local.json` | `bash ~/.claude/statusline-command.sh` |

   - Copy `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-command.sh` to the script path (overwrite it,
     create `.claude/` if needed) and make it executable.
   - In the settings file, set the top-level `statusLine` key to
     `{"type": "command", "command": "<command from the table>"}`. Create the file if it does not
     exist; keep every other key as it is. If it already has a different `statusLine`, show the user
     the old value before replacing it.
   - Project scope copies the script into the repo so teammates without the plugin get it too, and
     finds it from the git root because the status line can run from a subfolder.

3. If editing a settings file is not allowed, do not work around it: show the user the exact JSON and
   the file it belongs in, and tell them to add it themselves.

4. Tell the user:
   - the status line appears on the next refresh;
   - which settings win when several set `statusLine`: local over project over user;
   - for project scope, to commit `.claude/statusline-command.sh` and `.claude/settings.json`;
   - after a plugin update, run `/statusline:setup` again with the same scope to pick up the new
     script.
