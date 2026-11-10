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
/statusline:setup
```

It copies the script to `~/.claude/statusline-command.sh` and sets `statusLine` in
`~/.claude/settings.json`. After a plugin update, run it again to pick up the new script. A project
whose own `.claude/settings.json` sets `statusLine` keeps its own.
