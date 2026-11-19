# session-successor

Claude Code sessions die when their context window fills up. **session-successor** hands the work
over before that happens, with no action from you:

1. Once less than **20 %** of a session's context window is left, the session is told to stop at a
   logical point and write a handoff that covers only how to continue the task: what it's about;
   the state (git, docs, progress, baseline numbers, the check command, the half-done step, anything
   waiting on the user); the next steps with their commands; what the session learned; and where to
   look, including the old transcript.
2. It starts its **successor** in the background at **max effort**: `my-task` → `my-task-2` →
   `my-task-3`. Sessions you never named become `<project>-<branch>-1`. The successor's first
   message is the handoff, between a fixed opening (who it is and why it's taking over) and a
   closing line (check git and the tests before editing).
3. It tells every peer session it has talked to: "from now on message `my-task-2`".
4. With the companion [**JetBrains plugin**](https://plugins.jetbrains.com/plugin/35944-session-successor)
   (Session Successor on JetBrains Marketplace), the successor opens in a new terminal tab of the right
   project window (`claude attach my-task-2`), as if you had pressed Ctrl+Shift+T yourself.
5. The old session stays open, read-only, for you to scroll back through.

A successor runs in the background, and a background session that stops at a **usage limit** doesn't
continue by itself the way an interactive one does. So the plugin sees to that too: just after the limit
resets, the session gets a continue prompt and carries on. See [After a usage limit](#after-a-usage-limit).

Two parts:

| Part | What it does | Where in this repo |
| --- | --- | --- |
| Claude Code plugin | watches context, triggers the handoff, starts the successor | `plugins/session-successor` |
| JetBrains plugin | opens the successor's terminal tab | `jetbrains/session-successor` |

The Claude Code plugin works alone; without the JetBrains plugin you attach yourself with
`claude attach <name>` (the old session prints the exact command).

## Install

**Requirements:** Claude Code with background sessions (`claude --bg`, `claude attach`; tested
with 2.1.318, and continuing after a usage limit with 2.1.328), `bash` and `git`; no `jq` needed.
Tested on Linux; macOS should work but is untested.
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
| `limit_resume` | on | `on`: a background session that stops at a usage limit gets a continue prompt just after the reset; `off`: it stays stopped until you type |

**JetBrains plugin**: in Settings → Plugins → **Marketplace**, search for **Session Successor** and
install it ([its JetBrains Marketplace page](https://plugins.jetbrains.com/plugin/35944-session-successor)).
Updates then arrive like any other plugin's. No IDE restart needed.

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

State lives in `~/.claude/session-successor/` (`active/`, `prompts/`, `inbox/`, `warned/`, `limits/`).

**Is a session watched?** `ls ~/.claude/session-successor/active/` lists every session the hook has
run in, by session id. Plugins load when a session starts, so a session that was already running
when you installed (or updated) the plugin isn't watched until you restart it (`claude --resume`). Design notes and
the reasons behind each choice: [docs/design.md](docs/design.md).

## After a usage limit

Since 2.1.234 Claude Code waits at a usage limit and continues by itself after the reset, but only in
interactive sessions: its docs say the wait is never offered in "Background sessions and `-p` runs".
Every successor is a background session, so without help it sits at the limit until you type into it.

With `limit_resume` on (the default):

1. When a turn ends on a usage limit, the plugin reads the reset time from the transcript, and a small
   waiter for that session runs in the background.
2. Ninety seconds after the reset, the waiter checks that the session is still a running background
   session stopped at that same limit. If you, a peer session or a finished background task already
   got it going, it does nothing. A session that woke up only to hit the same limit again is still
   stopped there, so it still gets its continue.
3. It wakes the session with the prompt Claude Code itself uses: "Your claude.ai usage limit has reset.
   Continue the task you were working on when the limit was reached; do not repeat work that is
   already complete." The wake happens inside the session, so it still works after Claude Code has
   updated itself. A terminal tab attached to the session simply shows it carrying on.

This covers every background session the plugin runs in, not only successors, and leaves interactive
sessions to Claude Code. The one exception is an old session that has already handed off: its successor
carries the task now, so the old session stays stopped. It keeps Claude Code's own bounds: no wait when the reset is more than 24
hours away (a weekly limit), and at most three automatic continues in a row until you type a prompt.
If the machine sleeps through the reset, the session continues within half a minute of waking.

The session carries on unattended, in whatever permission mode it has, and spends the fresh allowance.
Set `limit_resume=off` if you'd rather it stayed stopped. What the plugin did and why is in
`~/.claude/session-successor/limits/log`, one line per decision.

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
- Continuing after a usage limit needs a claude.ai subscription login (only those stops record when
  the limit resets).
- Bash only: no native Windows support.
