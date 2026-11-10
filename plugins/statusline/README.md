# statusline

A compact status line for Claude Code:

```
Opus high │ claude-plugins │ main ● │ ctx: 42% │ session: 63% ↻14:25 │ week: 41% ↻Sat 09:00 │ 🦾 Beast mode!
```

- model with its reasoning effort (when the model supports it), project folder, git branch with a red (uncommitted changes) or green (clean) dot
- context left, green above 50 %, yellow above 25 %, red below
- your usage limits as `/usage` names them: `session` is the 5-hour window, `week` the 7-day one.
  Each shows how much you have used (green below 50 %, yellow below 80 %, red from 80 %) and when it
  resets, as a time today or a weekday and time later. Claude Code sends these only to Pro, Max and
  Ultra subscribers, after the session's first reply, so until then they are hidden
- a motivational phrase that changes every hour

Pure bash: it needs only `git`, `date` and `printf`, no `jq`.

## Install

```
claude plugin install statusline --marketplace MelkiorS/claude-plugins
```

Plugins can't switch a status line on by themselves, so run this once in Claude Code:

```
/statusline:setup            # asks where
/statusline:setup user       # every project, just for you
/statusline:setup project    # this project, for everyone who clones it
/statusline:setup local      # this project, just for you
```

| Scope | Settings file | Script |
| --- | --- | --- |
| `user` | `~/.claude/settings.json` | `~/.claude/statusline-command.sh` |
| `project` | `.claude/settings.json` (commit it) | `.claude/statusline-command.sh` (commit it) |
| `local` | `.claude/settings.local.json` | `~/.claude/statusline-command.sh` |

When several set `statusLine`, local wins over project, and project over user. After a plugin update,
run the setup again with the same scope to pick up the new script.
