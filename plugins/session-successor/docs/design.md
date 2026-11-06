# session-successor — design notes

Why the parts are built the way they are. Every fact below was checked against a live system
(Claude Code 2.1.318, WebStorm 2026.2.3, Linux) while building it.

## Goal

A Claude Code session that runs low on context hands its work to a fresh session **with no action
from the user**: it writes a handoff prompt, starts its successor, tells its peer sessions the new
name, and the successor appears in a new IDE terminal tab. The old session stays open, read-only.

Anti-goals: anything on the machine able to make the IDE run an arbitrary command; a handoff that
cuts work mid-step without saying so; two successors for one session; a silent failure (if the
tab can't open, the old session still prints `claude attach <name>`).

## Parts

```
Claude Code plugin (plugins/session-successor)
  hooks/hooks.json      UserPromptSubmit + PostToolUse → scripts/watch.sh
  scripts/watch.sh      measures context; below the threshold injects the handoff instruction, once
  scripts/successor     `name`: the successor's name · `start`: claude --bg + the note for the IDE

JetBrains plugin (jetbrains/session-successor)
  InboxWatcher.kt       per project window: polls the inbox each second, opens the terminal tab

Shared state: ~/.claude/session-successor/{inbox,prompts,warned}/
```

## Decisions

**Measuring context from the transcript.** Hooks receive no context figures, and a plugin cannot
set a statusline (plugin `settings` honours only `agent` and `subagentStatusLine`). So `watch.sh`
reads the last main-thread request in the transcript: `input + cache_read + cache_creation` tokens
÷ the context window. On 10 live sessions this matched the statusline's `remaining_percentage`
to within 1 point. The window size is not in the transcript, hence the `context_window` setting.

**Once per session, never in subagents.** A marker in `warned/<session_id>` stops repeats; hook
input with an `agent_id` is a subagent and is skipped.

**The instruction.** Returned as `hookSpecificOutput.additionalContext`, so it lands in the
session's context on its next prompt or tool call. The session itself picks the logical stopping
point and writes the prompt; the hook only tells it what to produce and where.

**Plugins load at session start.** A plugin installed or updated mid-session never reaches sessions
already running: probed by a marker in the hook, it ran in a session started after the install and
never in one started before (`claude plugin update` also says "restart required"). Hook *scripts*,
by contrast, are re-read on every run. Hook runs that print nothing leave no trace in the
transcript, so the hook marks each session it runs in: `active/<session_id>`. That tells a user
which sessions are watched, and lets another handoff mechanism stand down exactly where this one
runs.

**Names.** A name the user set (`-n`, `/rename`) is stored in the transcript as a `custom-title`
record; auto names only ever appear as `ai-title` records, which change over time. So: custom title
→ strip decoration (`✳ name` → `name`), then `name-2`, or `name-N+1` if it already ends in a number;
no custom title → `<folder>[-<branch>]-1`. Names already in `claude agents` are skipped.

**Starting the successor.** `claude --bg --effort <effort> -n <name> "<prompt>"` in the old
session's folder. `--bg` refuses folders Claude hasn't been trusted in; the old session's folder
already is. The successor reports `"effort":"max"` on every request.

**A drop folder, not a network endpoint.** The IDE plugin takes orders from files in
`~/.claude/session-successor/inbox/` (mode 700). An HTTP handler on the IDE's built-in server would
be reachable by any local process and possibly by web pages. The note names a session
(`[A-Za-z0-9._-]{1,64}`); the command `claude attach <name>` is fixed in the plugin.

**Routing.** Every project window polls the inbox; only the window whose project root contains the
note's `cwd` acts (path-component prefix, so `app` doesn't swallow `app-2`). It
claims the note by deleting it before opening the tab, so it opens once. The tab opens at the
project root.

**Stale notes.** A note can outlive its session: the IDE was closed, the session was stopped, the
machine rebooted. The note carries the successor's `pid` (from `claude agents --json`); the IDE
opens the tab only if that process is alive **and** started before the note was written, since a
later start means a recycled pid. A background session's pid is a pre-started `claude bg-spare`
process that it claims, so its start time can be well before the handoff, which is fine. Idle
background sessions keep their process; stopping one ends it.

**The terminal tab.** `TerminalToolWindowTabsManager.getInstance(project).createTabBuilder()
.workingDirectory(root).tabName(name).requestFocus(false).createTab()`, then
`tab.view.createSendTextBuilder().shouldExecute().send("claude attach $name")`: the user's normal
shell prompt, then the command. These come from the terminal plugin's newer frontend module, hence
`sinceBuild = 262` (2026.2).

## Dead ends

- The JetBrains MCP server's `execute_terminal_command` opens tabs, but runs commands with pipes,
  not a TTY (`tty` → "not a tty"), and typing in those tabs never reaches the command.
- Synthesising Ctrl+Shift+T: blocked on Wayland without `ydotool`/uinput, and it would type into
  whatever window has focus.

## Testing notes

- Environment variables don't reach the hooks of a `--bg` session (it is started by Claude's
  background service, not your shell), and `CLAUDE_PLUGIN_OPTION_*` come only from the plugin's
  saved settings. To test a handoff quickly, run a copy of the plugin with a high default threshold:
  `sed -i 's/THRESHOLD:-20/THRESHOLD:-99/' <copy>/scripts/watch.sh`, then
  `claude --bg -n test --plugin-dir <copy> "<a prompt that runs one tool>"`.
- From the repo root, `claude plugin validate .` and `claude plugin validate plugins/session-successor`
  check the manifests.
