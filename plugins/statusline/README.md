# statusline

A compact status line for Claude Code:

```
Opus │ claude-plugins │ main ● │ ctx: 42% │ 🦾 Beast mode!
```

- model, project folder, git branch with a red (uncommitted changes) or green (clean) dot
- context left, green above 50 %, yellow above 25 %, red below
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
