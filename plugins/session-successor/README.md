# session-successor

Claude Code sessions die when their context window fills up. **session-successor** hands the work
over before that happens, with no action from you:

1. Once less than **20 %** of a session's context window is left, the session is told to stop at a
   logical point and write a handoff prompt (goal, what's done, state, next steps, key files, open
   questions, peer sessions, gotchas).
2. It starts its **successor** in the background at **max effort**: `my-task` → `my-task-2` →
   `my-task-3`. Sessions you never named become `<project>-<branch>-1`.
3. It tells every peer session it has talked to: "from now on message `my-task-2`".
4. With the companion **JetBrains plugin**, the successor opens in a new terminal tab of the right
   project window (`claude attach my-task-2`), as if you had pressed Ctrl+Shift+T yourself.
5. The old session stays open, read-only, for you to scroll back through.

Two parts:

| Part | What it does | Where in this repo |
| --- | --- | --- |
| Claude Code plugin | watches context, triggers the handoff, starts the successor | `plugins/session-successor` |
| JetBrains plugin | opens the successor's terminal tab | `jetbrains/session-successor` |

The Claude Code plugin works alone; without the JetBrains plugin you attach yourself with
`claude attach <name>` (the old session prints the exact command).

## Install

**Requirements:** Claude Code with background sessions (`claude --bg`, `claude attach`; tested
with 2.1.318), `bash` and `git`; no `jq` needed. Tested on Linux; macOS should work but is untested.
JetBrains plugin: any JetBrains IDE **2026.2+** with the bundled Terminal plugin (WebStorm,
IntelliJ IDEA, PyCharm, ...).

**Claude Code plugin** (this also adds the [marketplace](../../README.md) on first use):

```
claude plugin install session-successor --marketplace MelkiorS/claude-plugins
```

Start new sessions after installing; restart sessions that were already running so they load it.
Settings (via `/plugin` → session-successor → configure, or at install time with
`--config threshold=15`):

| Setting | Default | Meaning |
| --- | --- | --- |
| `threshold` | 20 | hand off below this % of context left |
| `effort` | max | effort level the successor starts with |
| `context_window` | 1000000 | your model's context window in tokens |
| `worktree_guard` | off | `off`: the successor edits the repo in place, like the session it replaces; `on`: keep Claude Code's guard (see below) |

**JetBrains plugin**: add this repo's plugin repository once (Settings → Plugins → ⚙ →
*Manage Plugin Repositories…* → **+** →
`https://raw.githubusercontent.com/MelkiorS/claude-plugins/main/jetbrains/updatePlugins.xml`), then
install **Session Successor** from the Marketplace tab. Updates then arrive like any other plugin's.
Or install the zip from [`jetbrains/dist/`](../../jetbrains/dist) with *Install Plugin from Disk…*.
No IDE restart needed.

## How it works

- **Measuring context.** Plugins can't set a statusline, so the hook reads the transcript instead:
  the last request's `input + cache_read + cache_creation` tokens ÷ `context_window`. This matches
  the statusline's `remaining_percentage`. It fires once per session, never in subagents.
- **Names.** A name you set (`claude -n`, `/rename`) is kept and numbered; decoration like `✳ ` is
  stripped; names already in use are skipped.
- **Starting the successor.** `claude --bg --effort max -n <name> "<handoff prompt>"`, in the same
  folder as the old session (Claude refuses to start a background session in a folder it hasn't
  been trusted in; the old session's folder already is).
- **Editing in place.** Claude Code blocks file edits in a background session until it moves into
  a git worktree ("This background session hasn't isolated its changes yet. Call EnterWorktree
  first…"). That guard keeps a background job from editing the checkout under you, but a
  successor *replaces* the old session instead of working beside it, so the plugin starts it with
  `--settings '{"worktree":{"bgIsolation":"none"}}'`. Only successors get this; your own `--bg`
  sessions keep the guard. Set `worktree_guard=on` to keep it for successors too.
- **Opening the tab.** `successor start` writes `{"name", "cwd", "pid"}` into
  `~/.claude/session-successor/inbox/`. Every open IDE window watches that folder; the window whose
  project contains `cwd` opens a terminal tab at its project root and runs `claude attach <name>`.
  The note carries a name (checked against `[A-Za-z0-9._-]`), never a command, and only your user
  can write to the folder: no network port, nothing another program or web page can reach.
- **Stale notes.** A note waits if no matching project window is open, and is discarded instead of
  opening a dead tab once its session is gone (stopped, or the machine rebooted): the IDE checks
  that the `pid` is alive and started before the note was written.

State lives in `~/.claude/session-successor/` (`active/`, `prompts/`, `inbox/`, `warned/`).

**Is a session watched?** `ls ~/.claude/session-successor/active/` lists every session the hook has
run in, by session id. Plugins load when a session starts, so a session that was already running
when you installed (or updated) the plugin isn't watched until you restart it (`claude --resume`). Design notes and
the reasons behind each choice: [docs/design.md](docs/design.md).

## Permissions

The handoff runs `scripts/successor`, writes to `~/.claude/session-successor/prompts/` and uses
`SendMessage`. In `auto` permission mode it has run unattended in testing. In other modes Claude
asks before those steps; to pre-approve them, add to the `permissions.allow` list in
`~/.claude/settings.json`:

```json
"Write(//<your home>/.claude/session-successor/prompts/**)",
"SendMessage",
"ListAgents"
```

plus a `Bash(...)` rule for the `scripts/successor` path shown in the permission prompt.

## Build the JetBrains plugin

```
cd jetbrains/session-successor
./gradlew buildPlugin                                   # downloads WebStorm 2026.2.3 to compile against
./gradlew buildPlugin -PlocalIde=/path/to/your/ide      # or compile against an installed IDE
```

The zip lands in `build/distributions/`.

## Limits

- The terminal-tab API comes from the IDE's newer terminal (`intellij.terminal.frontend`), which
  JetBrains may still change; hence 2026.2+.
- The context window size isn't in the transcript; set `context_window` if yours isn't 1M.
- Bash only: no native Windows support.
