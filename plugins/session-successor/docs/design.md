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
                        StopFailure (rate_limit) → scripts/limit-stop.sh
  scripts/watch.sh      measures context; below the threshold injects the handoff instruction, once
  scripts/successor     `name`: the successor's name · `start`: claude --bg + the note for the IDE
  scripts/limit-stop.sh a turn ended on a usage limit: reads the reset time, starts one waiter
  scripts/limit-resume  the waiter: after the reset, sends a background session one continue prompt

JetBrains plugin (jetbrains/session-successor)
  InboxWatcher.kt       per project window: polls the inbox each second, opens the terminal tab

Shared state: ~/.claude/session-successor/{inbox,prompts,warned,active,limits}/
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
point and writes the handoff; the hook only tells it what to produce and where.

**The handoff covers only how to continue the task.** The hook gives the session a fixed template:
what the task is about and when it's done; the state (git and standing rules, docs, progress,
baseline numbers, the check command, the half-done step, the user's unanswered message); the next
steps with commands and expected results; what the session learned (traps, failed approaches,
decisions with their reasons); and where to look, with the old transcript's path filled in by the
hook. Lines that don't apply are dropped, not filled with guesses. Research on compaction and on
human handoffs agrees on what gets lost: constraints and how-to-work rules, half-done or temporary
state, failed approaches and the reasons behind decisions (e.g. arXiv 2610.31778 and 2608.11242;
the I-PASS and HSE shift-handover studies), so the template asks for each by name.
`successor start` wraps the handoff in a fixed opening (who the successor is, why it's taking over,
deal with anything waiting on the user first) and a closing line (check `git status` and the check
command; if the repo differs, trust the repo). Fixed text needs no explanation from the old
session, so the first message makes sense even when the old session created no files of its own.

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

**Editing in place.** A `--bg` session can't edit files in a git checkout until it enters a
worktree (Claude Code's `worktree.bgIsolation` guard). The guard protects a checkout that an
interactive session is still working in; a successor takes over from a session that has stopped,
so the plugin passes `--settings '{"worktree":{"bgIsolation":"none"}}'` (option `worktree_guard`,
default `off`). Per-session, not per-repo: other background sessions keep the guard, and no repo's
`.claude/settings.json` is touched. Verified 2026-11-09: a `--bg` session without the flag got the
refusal; one with it wrote its file.

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

## Continuing after a usage limit

Added in 0.3.0. Every fact in this section was checked against Claude Code 2.1.327 on Linux, with
throwaway background sessions.

**The gap.** Since 2.1.234 an interactive session that stops at a claude.ai usage limit waits and
continues by itself after the reset. Claude Code's docs list where that wait is never offered:
"Background sessions and `-p` runs". Every successor is a background session, so a successor that
stops at a limit stays stopped until someone types into it. In 45 days of the author's own
transcripts, interactive sessions still stopped at the reset continued by themselves 8 times out of
9; background sessions 0 times out of 8, and five of those sat for 6 to 14 hours.

**Goal.** A background session that stops at a usage limit carries on by itself just after the limit
resets, the way an interactive one does. Anti-goals: a second "continue" in a session that already
moved on; an endless chain of automatic continues; touching interactive sessions, which Claude Code
already handles; a silent failure (every decision goes to `limits/log`).

**How it works.**

1. A turn ends on a usage limit, and Claude Code runs the plugin's `StopFailure` hook (matcher
   `rate_limit`): `scripts/limit-stop.sh`.
2. The hook takes the reset time from the transcript and starts one detached waiter for the session:
   `scripts/limit-resume`.
3. The waiter checks at once that the session is a running background session, then sleeps until 90
   seconds after the reset.
4. It checks that the session is still stopped at that limit and sends it one prompt, the text Claude
   Code itself uses: "Your claude.ai usage limit has reset. Continue the task you were working on when
   the limit was reached; do not repeat work that is already complete."

**The trigger is `StopFailure`.** It "runs instead of Stop when the turn ends due to an API error",
and its matcher filters on the error type. In background sessions the hook ran for `rate_limit` (a
fake local API answering 429) and for `model_not_found`. The error name the hook receives equals the
`error` field on the transcript's error line (3 of 3), and that field is `rate_limit` on all 75
usage-limit stops in the transcripts above.

**The reset time comes from the transcript.** The hook input carries only the rendered message
("… resets 5:20pm (Area/City)"). The transcript's error line carries the same moment as epoch seconds,
`"quotaLimits":{…,"resetsAt":1794889200,…}`, on the real stops inspected. The hook reads the last
main-thread assistant line: it must be an API error with `"error":"rate_limit"` and a `resetsAt`. A
429 that is not a plan limit has no `resetsAt` and starts nothing. Neither does a session that isn't
signed in with a claude.ai subscription: it records no `quotaLimits`.

**The stop's line arrives after the hook starts.** In a background session the error line was not in
the transcript yet when `StopFailure` started (3 stops out of 3). It landed 80 to 90 ms later on the
two stops that were timed, and its `timestamp` was from about 0.1 s before the hook started. Until it
lands, the last line is whatever came
before, and that can be an older limit stop, for instance when the turn after a continue prompt fails
at once. So the hook takes only a line written in the 30 seconds before it started, waits up to 5
seconds for one, and logs it when none appears. 30 stays below the 90-second margin: the stop before
a continue prompt is always older than that.

**The hook stays fast; the waiter decides.** The hook makes no `claude` call: it validates its
input, waits for the stop's line and starts the waiter with `setsid … &`. Claude Code runs a hook
in a session of its own, ignoring only SIGQUIT, and a process started this way from a `StopFailure`
hook in a background session was still running 15 seconds after the hook started. Not `nohup` as
well: the waiter and the `claude` it starts would then ignore hangups, and a process that `claude`
had started outlived the helper that way. Only where there is no `setsid` (macOS) does the hook use
`nohup`. The waiter's first act is the kind check, so in an interactive session it exits within a
second or two.

**Background sessions only, every one of them.** `claude agents --json` is the supported way to read
session state from outside. The waiter needs the entry with this `sessionId` to say
`"kind":"background"` and to have a `pid`. Interactive sessions are left to Claude Code's own wait,
so nothing is sent twice. A background session you started by hand is covered just like a successor.

**Except a session that handed off.** Its successor carries the task now, so "continue the task" in
the old session could redo that work in the same checkout. When `watch.sh` asks a session to hand
off, it notes the successor's name in `warned/<session-id>`; once a session by that name exists, the
waiter leaves the old session stopped. A session that hit the limit halfway through its handoff, with
no successor started yet, still gets its continue, so it can finish the handoff.

**Delivering the prompt: `claude --resume <session-id> "<prompt>"` under a pseudo-terminal.** That
command sends a prompt to a running background session as its next turn ("Sent your prompt to the
background session (<id>); opening it…") and then attaches. The docs say it sends nothing and exits
with status 1 when its input or output is piped or redirected, and there is no other way in: no
`claude send`. So the waiter runs it under `script`, waits for the confirmation line and ends the
helper with SIGTERM, which `script` passes on to `claude`; `script` itself kills a `claude` that
ignores it about 2 seconds later (util-linux 2.41). `script` runs its command through `$SHELL`, so the
waiter sets `SHELL=/bin/sh`, which keeps the user's login shell and its startup files out, and writes
`exec claude …`, because `/bin/sh` (dash) does not hand over to the command by itself and `claude`
would otherwise get only the terminal's hangup, never the SIGTERM. `claude --resume` also asks the
workspace-trust question for the folder it runs in, and then never confirms. The waiter runs in the
hook's folder, and Claude Code runs the hook in the session's own folder (checked live), which is
trusted because the session runs there. The waiter never types into the session and never sends
end-of-file. The session ran the new turn and survived the helper's death; it
also worked while another client was attached (the IDE tab), and that client survived too.

**One waiter per session, for its latest limit.** `limits/<session-id>.pid` holds the waiter's pid
and the reset it waits for. The hook starts nothing when a live waiter already waits for the same
reset, so repeated stops at one limit (background tasks waking the session) cost nothing: that one
waiter covers them all. A stop at a different limit starts a new waiter, and the old one, finding
another pid in the file, exits.

**Still stopped?** At the reset the waiter sends only if the session is still a running, idle
background session whose latest turn ended on this same limit: the transcript's last main-thread
assistant line is a usage-limit stop with the reset the waiter waits for. If you, a peer message or a
finished background task got the session going, that line is a reply or a different stop, and the
waiter does nothing. A session that woke up only to hit the same limit again is still stopped there,
so it still gets its continue. Claude Code's own interactive continue arrives about 70 to 80 seconds
after the reset; waiting 90 means that if a later version covers background sessions too, it gets
there first and this waiter stands down.

**The same limits Claude Code sets itself.** No wait when the reset is more than 24 hours away (a
weekly limit). At most three automatic continues in a row: the waiter counts its own sends
(`limits/<session-id>.sent`) since the transcript's last typed prompt and stops at three. Should
transcripts stop marking typed prompts, the count never resets and the cap becomes three per session:
it fails closed.

**Sleep.** The waiter compares wall-clock time every 30 seconds, so after the machine sleeps through
the reset it continues within 30 seconds of waking. Claude Code's interactive wait asks for Enter
after a long sleep; a background session has nobody at its prompt, so this one doesn't ask.

**Approaches considered.**

- *Hook, waiter, prompt* (built): no long-running service, and each part can be checked by itself.
- *`CLAUDE_CODE_RETRY_WATCHDOG=1` for successors*, Claude Code's unattended mode, in which the
  request itself waits for the reset. It works for a plain plan limit: with a 70-second reset the
  request waited and retried, and the variable reaches a background session through
  `--settings '{"env":{…}}'`. But the client refuses to wait when the 429 names a spend limit: with
  the header `anthropic-ratelimit-unified-overage-disabled-reason: org_level_disabled_until` the same
  request failed after 1 second, and the client's code treats `org_spend_cap_reached` the same way.
  An account whose usage credits are capped gets that reason on every stop, so this cannot be the
  mechanism.
- *A supervisor polling `claude agents --json`*: it would also cover sessions whose hook never ran,
  at the price of a long-running service, which this plugin has avoided so far. It stays the fallback
  if hooks prove unreliable.
- *Interactive successors*: they would die with their terminal tab, the opposite of why successors
  run in the background.

## Dead ends

- The JetBrains MCP server's `execute_terminal_command` opens tabs, but runs commands with pipes,
  not a TTY (`tty` → "not a tty"), and typing in those tabs never reaches the command.
- Synthesising Ctrl+Shift+T: blocked on Wayland without `ydotool`/uinput, and it would type into
  whatever window has focus.
- Restarting a stopped session with a prompt: after `claude stop <id>`,
  `claude --bg --resume <session-id> --model … --settings … "<prompt>"` did not continue "under the
  same ID" as its help says. It made a copy with a new id (SessionStart source `fork`), leaving two
  rows with one name.

## Testing notes

- Environment variables don't reach the hooks of a `--bg` session (it is started by Claude's
  background service, not your shell), and `CLAUDE_PLUGIN_OPTION_*` come only from the plugin's
  saved settings. To test a handoff quickly, run a copy of the plugin with a high default threshold:
  `sed -i 's/THRESHOLD:-20/THRESHOLD:-99/' <copy>/scripts/watch.sh`, then
  `claude --bg -n test --plugin-dir <copy> "<a prompt that runs one tool>"`.
- From the repo root, `claude plugin validate .` and `claude plugin validate plugins/session-successor`
  check the manifests.
- `bash plugins/session-successor/tests/test-limit-resume.sh` (about a minute) runs `limit-stop.sh`
  and `limit-resume` against a fake `claude` and sample transcripts, each alone and the hook into the
  waiter, plus the successor name `watch.sh` notes for the waiter. The fake `claude` refuses without a
  terminal, records end-of-file and how it was ended, and starts a process of its own, so delivery is
  checked too. The waiter's timings are shortened there with `LIMIT_RESUME_MARGIN`,
  `LIMIT_RESUME_POLL`, `LIMIT_RESUME_SETTLE` and `LIMIT_RESUME_HELPER_WAIT` (seconds); nothing else
  should set them.
- Live sessions that cost nothing: `claude --bg --model <a name that doesn't exist> …` ends its first
  turn with `model_not_found` before any tokens are used, which is enough to exercise hooks and
  prompt delivery. For a real `rate_limit` stop, point a session at a fake local API through
  `--settings '{"env":{"ANTHROPIC_BASE_URL":"http://127.0.0.1:<port>","ANTHROPIC_AUTH_TOKEN":"dummy"}}'`
  and have it answer 429 with the `anthropic-ratelimit-unified-*` headers.
- The whole chain, live: give the real `limit-stop.sh` a real-shaped hook input whose transcript is a
  copy of a live background session's (one on a nonexistent model), with a fresh limit line appended
  and `LIMIT_RESUME_MARGIN=2`. Run it from the session's folder, as Claude Code does, or
  `claude --resume` stops at the trust question. On 2.1.327 it started the waiter, which sent the
  continue prompt into the session and left nothing running.
- Not checked: the hook on a real subscriber limit stop (the transcript shape comes from real stops,
  the hook was exercised with the fake API), and `script` on macOS.
