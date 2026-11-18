#!/usr/bin/env bash
# Checks scripts/limit-resume and scripts/limit-stop.sh against a stand-in `claude` and sample transcript
# lines. Run: bash plugins/session-successor/tests/test-limit-resume.sh (about a minute; needs `script` from util-linux).
root=$(cd "$(dirname "$0")/.." && pwd); fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

SID=11111111-2222-4333-8444-555555555555

# Stand-in for the claude CLI. `agents --json` prints the listing in $FAKE_AGENTS. `--resume <id> <prompt>`
# records both arguments in $FAKE_CALLS, then behaves like the real command: without a terminal on its input
# and output it sends nothing; otherwise it confirms (not with $FAKE_SILENT set) and stays attached, or
# refuses when $FAKE_REFUSE is set. While attached it reads the terminal and records how it ends
# ($FAKE_SIGNALS), any end-of-file it reads ($FAKE_EOF), and its pid with that of a process it started, which
# only the terminal's hangup ends ($FAKE_PIDS). $FAKE_IGNORE_TERM makes it ignore SIGTERM.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/claude" <<'EOF'
#!/bin/bash
[ -n "${FAKE_LOG:-}" ] && echo "$*" >> "$FAKE_LOG"
case "$1" in
  agents) cat "$FAKE_AGENTS" 2>/dev/null ;;
  --resume)
    printf '%s\n%s\n' "$2" "$3" >> "$FAKE_CALLS"
    [ -t 0 ] && [ -t 1 ] || { echo "Your prompt was not sent: no terminal"; exit 1; }
    if [ -n "${FAKE_REFUSE:-}" ]; then
      echo "This session is running in the background. Your prompt was not sent to it: it is waiting on your answer."
      exit 1
    fi
    trap 'echo TERM >> "$FAKE_SIGNALS"; exit 143' TERM
    trap 'echo HUP >> "$FAKE_SIGNALS"; exit 129' HUP
    [ -z "${FAKE_IGNORE_TERM:-}" ] || trap '' TERM
    sleep 30 & echo "$$ $!" >> "$FAKE_PIDS"
    [ -n "${FAKE_SILENT:-}" ] || echo "Sent your prompt to the background session (${2%%-*}); opening it…"
    read -r -t 30 _; [ $? -ne 1 ] || echo "end of input" >> "$FAKE_EOF" ;;
esac
EOF
chmod +x "$tmp/bin/claude"
# The user's login shell, whose startup files could change what runs (even put the real claude first on PATH).
# The helper must never go through it.
printf '#!/bin/sh\necho "$*" >> "%s/login-shell-used"\nexit 1\n' "$tmp" > "$tmp/bin/login-shell"
chmod +x "$tmp/bin/login-shell"

# --- sample data, shaped like what Claude Code 2.1.327 writes -------------------------------------------------

limit_line() { # limit_line <iso time> <reset epoch> : a turn that ended on a usage limit
  printf '{"parentUuid":"0a","isSidechain":false,"type":"assistant","uuid":"0b","timestamp":"%s","message":{"diagnostics":null,"id":"0c","container":null,"model":"<synthetic>","role":"assistant","stop_details":null,"stop_reason":"stop_sequence","stop_sequence":"","type":"message","usage":{"input_tokens":0,"output_tokens":0},"content":[{"type":"text","text":"You have hit your session limit · resets 3:45pm"}],"context_management":null},"requestId":"0d","apiError":"usage_limit_reached","apiErrorParams":{"rate_limit_info":{"status":"rejected","resetsAt":%s,"rateLimitType":"five_hour","overageStatus":"rejected","overageResetsAt":1796083200,"overageDisabledReason":"org_level_disabled_until","isUsingOverage":false}},"quotaLimits":{"status":"rejected","resetsAt":%s,"unifiedRateLimitFallbackAvailable":false,"rateLimitType":"five_hour","overageStatus":"rejected","overageResetsAt":1796083200,"overageDisabledReason":"org_spend_cap_reached","upgradePaths":["overage"],"isUsingOverage":false},"error":"rate_limit","isApiErrorMessage":true,"apiErrorStatus":429,"apiErrorType":"rate_limit_error","failedResponseHadNoToolCall":true,"sessionKind":"bg","userType":"external","entrypoint":"cli","cwd":"/tmp/app","sessionId":"%s","version":"2.1.327","gitBranch":"main"}\n' "$1" "$2" "$2" "$SID"
}
plain_429_line() { # plain_429_line <iso time> : a 429 that is not a plan limit, so it names no reset
  printf '{"parentUuid":"0a","isSidechain":false,"type":"assistant","uuid":"0b","timestamp":"%s","message":{"diagnostics":null,"id":"0c","container":null,"model":"<synthetic>","role":"assistant","stop_details":null,"stop_reason":"stop_sequence","stop_sequence":"","type":"message","usage":{"input_tokens":0,"output_tokens":0},"content":[{"type":"text","text":"API Error: Request rejected (429)"}],"context_management":null},"requestId":"0d","apiError":null,"apiErrorParams":null,"quotaLimits":null,"error":"rate_limit","isApiErrorMessage":true,"apiErrorStatus":429,"apiErrorType":"rate_limit_error","failedResponseHadNoToolCall":true,"sessionKind":"bg","userType":"external","entrypoint":"cli","cwd":"/tmp/app","sessionId":"%s","version":"2.1.327","gitBranch":"main"}\n' "$1" "$SID"
}
reply_line() { # reply_line <iso time> [sidechain true|false] : an ordinary assistant message
  printf '{"parentUuid":"0a","isSidechain":%s,"type":"assistant","uuid":"0e","timestamp":"%s","message":{"id":"0f","model":"claude-opus-5-5","role":"assistant","stop_reason":"end_turn","type":"message","usage":{"input_tokens":10,"output_tokens":5},"content":[{"type":"text","text":"Done."}]},"requestId":"10","sessionKind":"bg","userType":"external","entrypoint":"cli","cwd":"/tmp/app","sessionId":"%s","version":"2.1.327","gitBranch":"main"}\n' "${2:-false}" "$1" "$SID"
}
typed_line() { # typed_line <iso time> <text> : a prompt somebody typed
  printf '{"parentUuid":"0a","isSidechain":false,"promptId":"11","type":"user","message":{"role":"user","content":"%s"},"uuid":"12","timestamp":"%s","permissionMode":"auto","origin":{"kind":"human"},"promptSource":"typed","turnOrigin":"human","turnPosition":{"promptIndex":1,"turnIndex":1},"sessionKind":"bg","userType":"external","entrypoint":"cli","cwd":"/tmp/app","sessionId":"%s","version":"2.1.327","gitBranch":"main"}\n' "$2" "$1" "$SID"
}
listing() { # listing <file> <kind> <pid|""> <status|""> <state|""> : `claude agents --json`, another session first
  {
    printf '[\n  {\n    "pid": 4242,\n    "id": "99999999",\n    "cwd": "/tmp/other",\n    "kind": "background",\n'
    printf '    "startedAt": 1794046196485,\n    "sessionId": "99999999-0000-4000-8000-000000000000",\n'
    printf '    "name": "other-3",\n    "status": "busy",\n    "state": "working"\n  },\n  {\n'
    [ -n "$3" ] && printf '    "pid": %s,\n' "$3"
    printf '    "id": "11111111",\n    "cwd": "/tmp/app",\n    "kind": "%s",\n    "startedAt": 1794967665981,\n' "$2"
    printf '    "sessionId": "%s",\n    "name": "app-2"' "$SID"
    [ -n "$4" ] && printf ',\n    "status": "%s"' "$4"
    [ -n "$5" ] && printf ',\n    "state": "%s"' "$5"
    printf '\n  }\n]\n'
  } > "$1"
}

n=0
newcase() { n=$((n + 1)); c="$tmp/case$n"; mkdir -p "$c/home"; L="$c/home/.claude/session-successor/limits"; }
waiter() { # waiter <reset epoch> [session id] [transcript] : runs limit-resume to its end (15 s at most), short timings
  HOME="$c/home" PATH="$tmp/bin:$PATH" SHELL="$tmp/bin/login-shell" FAKE_AGENTS="$c/agents.json" FAKE_CALLS="$c/calls" \
    FAKE_PIDS="$c/pids" FAKE_EOF="$c/eof" FAKE_SIGNALS="$c/signals" \
    LIMIT_RESUME_MARGIN=${LIMIT_RESUME_MARGIN:-0} LIMIT_RESUME_POLL=1 LIMIT_RESUME_SETTLE=0 \
    LIMIT_RESUME_HELPER_WAIT=${LIMIT_RESUME_HELPER_WAIT:-5} \
    timeout 15 bash "$root/scripts/limit-resume" "${2:-$SID}" "${3:-$c/transcript.jsonl}" "$1"
}
gone() { # gone : the stand-in ran, and neither it nor the process it started is still running
  sleep 0.3; [ -s "$c/pids" ] || return 1
  local p; for p in $(cat "$c/pids"); do ! kill -0 "$p" 2> /dev/null || return 1; done
}
now=$(date +%s); past=$((now - 100))

# --- limit-resume, the waiter -----------------------------------------------------------------------------

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
waiter "$past"
check "R1 sends to a stopped background session"   '[ "$(sed -n 1p "$c/calls" 2>/dev/null)" = "$SID" ] && [ "$(wc -l < "$L/$SID.sent")" -eq 1 ] && grep -q "sent the continue prompt" "$L/log"'
check "R1 sends exactly once"                      '[ "$(wc -l < "$c/calls")" -eq 2 ]'
check "R2 the prompt is Claude Code's own continuation text" '[ "$(sed -n 2p "$c/calls" 2>/dev/null)" = "Your claude.ai usage limit has reset. Continue the task you were working on when the limit was reached; do not repeat work that is already complete." ]'
check "R3 leaves only the log and the send record"  '[ -d "$L" ] && [ -z "$(ls "$L" | grep -v -e "^log$" -e "^$SID\.sent$")" ]'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" interactive 5151 idle ""
waiter "$past"
check "R4 an interactive session gets nothing"     '[ ! -e "$c/calls" ] && grep -q "not a running background session" "$L/log"'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background "" "" blocked
waiter "$past"
check "R5 a background session whose process is gone gets nothing" '[ ! -e "$c/calls" ] && grep -q "not a running background session" "$L/log"'

newcase; { limit_line 2026-11-17T03:18:22.075Z "$past"; reply_line 2026-11-17T03:20:00.000Z; } > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle done
waiter "$past"
check "R6 a session whose last turn was not a limit stop gets nothing" '[ ! -e "$c/calls" ] && grep -q "did not end on a usage limit" "$L/log"'

newcase; soon=$(($(date +%s) + 3)); limit_line 2026-11-17T03:18:22.075Z "$soon" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
( sleep 1; reply_line 2026-11-17T03:19:00.000Z >> "$c/transcript.jsonl" ) &
waiter "$soon"; wait
check "R7 a session that got going during the wait gets nothing" '[ ! -e "$c/calls" ] && grep -q "already moved on" "$L/log"'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 busy working
waiter "$past"
check "R8 a busy session gets nothing"             '[ ! -e "$c/calls" ] && grep -q "the session is busy" "$L/log"'

newcase; limit_line 2026-11-17T03:18:22.075Z $((now + 90000)) > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
SECONDS=0; waiter $((now + 90000))
check "R9 a reset more than 24 hours away is not waited for" '[ "$SECONDS" -lt 5 ] && [ ! -e "$c/calls" ] && grep -q "more than 24 hours away" "$L/log"'

three_sends() { mkdir -p "$L"; printf '%s\n' 2026-11-17T04:00:00Z 2026-11-17T09:00:00Z 2026-11-17T14:00:00Z > "$L/$SID.sent"; }
newcase; { typed_line 2026-11-17T01:00:00.000Z "start the task"; limit_line 2026-11-17T15:30:00.000Z "$past"; } > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
three_sends; waiter "$past"
check "R10 the fourth continue in a row is not sent" '[ ! -e "$c/calls" ] && grep -q "3 automatic continues in a row" "$L/log"'

newcase; { typed_line 2026-11-17T01:00:00.000Z "start the task"; typed_line 2026-11-17T15:00:00.000Z "carry on please"; limit_line 2026-11-17T15:30:00.000Z "$past"; } > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
three_sends; waiter "$past"
check "R11 a typed prompt starts the count again"  '[ "$(sed -n 1p "$c/calls" 2>/dev/null)" = "$SID" ] && [ "$(wc -l < "$L/$SID.sent")" -eq 4 ]'

newcase; { typed_line 2026-11-17T01:00:00.000Z "start the task"; typed_line 2026-11-17T15:00:00.000Z "Your claude.ai usage limit has reset. Continue the task you were working on when the limit was reached; do not repeat work that is already complete."; limit_line 2026-11-17T15:30:00.000Z "$past"; } > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
three_sends; waiter "$past"
check "R11b the continue prompt itself does not start the count again" '[ ! -e "$c/calls" ] && grep -q "3 automatic continues in a row" "$L/log"'

newcase; soon=$(($(date +%s) + 3)); limit_line 2026-11-17T03:18:22.075Z "$soon" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
( sleep 1; echo "999999 1" > "$L/$SID.pid" ) &
waiter "$soon"; wait
check "R12 a waiter replaced by a newer one sends nothing and leaves the newer one's file" '[ ! -e "$c/calls" ] && [ "$(cat "$L/$SID.pid" 2>/dev/null)" = "999999 1" ] && grep -q "a newer waiter took over" "$L/log"'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
FAKE_REFUSE=1 waiter "$past"
check "R13 a refused prompt is logged and not counted" '[ -s "$c/calls" ] && [ ! -e "$L/$SID.sent" ] && grep -q "FAILED to send" "$L/log" && grep -q "not sent to it" "$L/log"'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
waiter "$past" "not-a-session-id"; a=$?; waiter "$past" "$SID" "$c/missing.jsonl"; b=$?; waiter "soon"; d=$?
check "R14 bad arguments exit with status 2"       '[ "$a" -eq 2 ] && [ "$b" -eq 2 ] && [ "$d" -eq 2 ] && [ ! -e "$c/calls" ]'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; : > "$c/agents.json"
waiter "$past"
check "R15 an empty session listing sends nothing" '[ ! -e "$c/calls" ] && grep -q "not a running background session" "$L/log"'

newcase; { limit_line 2026-11-17T03:18:22.075Z "$past"; reply_line 2026-11-17T03:19:00.000Z true; } > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
waiter "$past"
check "R16 a subagent's later line does not count as the session moving on" '[ "$(sed -n 1p "$c/calls" 2>/dev/null)" = "$SID" ]'

newcase; soon=$(($(date +%s) + 3)); limit_line 2026-11-17T03:18:22.075Z "$soon" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
( sleep 1; limit_line 2026-11-17T03:19:00.000Z "$soon" >> "$c/transcript.jsonl" ) &
waiter "$soon"; wait
check "R17 a second stop at the same limit during the wait still gets one continue" '[ "$(sed -n 1p "$c/calls" 2>/dev/null)" = "$SID" ] && [ "$(wc -l < "$c/calls")" -eq 2 ] && grep -q "sent the continue prompt" "$L/log"'

newcase; soon=$(($(date +%s) + 3)); limit_line 2026-11-17T03:18:22.075Z "$soon" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
( sleep 1; limit_line 2026-11-17T03:19:00.000Z $((soon + 18000)) >> "$c/transcript.jsonl" ) &
waiter "$soon"; wait
check "R17b a stop at a later limit during the wait gets nothing from this waiter" '[ ! -e "$c/calls" ] && grep -q "already moved on" "$L/log"'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
waiter "$past"
check "R18 the prompt reaches claude in a terminal, never followed by end-of-file" '[ "$(sed -n 1p "$c/calls" 2>/dev/null)" = "$SID" ] && grep -q "sent the continue prompt" "$L/log" && [ ! -e "$c/eof" ]'
check "R19 then claude is ended with SIGTERM and nothing of the helper is left" '[ "$(sed -n 1p "$c/signals" 2>/dev/null)" = TERM ] && gone'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
FAKE_SILENT=1 LIMIT_RESUME_HELPER_WAIT=2 waiter "$past"
check "R20 a prompt never confirmed is logged as FAILED, not counted, and leaves nothing running" '[ -s "$c/calls" ] && [ ! -e "$L/$SID.sent" ] && grep -q "FAILED to send: no confirmation" "$L/log" && gone'

newcase; reset=$(date +%s); limit_line 2026-11-17T03:18:22.075Z "$reset" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
LIMIT_RESUME_MARGIN=3 waiter "$reset" & w=$!
sleep 1; early=$(cat "$c/calls" 2> /dev/null); wait "$w"
check "R21 nothing is sent before the margin after the reset has passed" '[ -z "$early" ] && [ "$(sed -n 1p "$c/calls" 2>/dev/null)" = "$SID" ]'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
FAKE_IGNORE_TERM=1 waiter "$past"; st=$?
check "R22 a claude that ignores SIGTERM neither holds up the waiter nor outlives it" '[ "$st" -eq 0 ] && grep -q "sent the continue prompt" "$L/log" && gone'

check "R23 no helper above ran through the user's login shell" '[ ! -e "$tmp/login-shell-used" ]'

handed_off_to() { mkdir -p "$c/home/.claude/session-successor/warned"; echo "$1" > "$c/home/.claude/session-successor/warned/$SID"; }
newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
sed -i 's/"other-3"/"app-3"/' "$c/agents.json"; handed_off_to app-3
waiter "$past"
check "R24 a session whose successor already runs gets nothing" '[ ! -e "$c/calls" ] && grep -q "handed off to app-3" "$L/log"'

newcase; limit_line 2026-11-17T03:18:22.075Z "$past" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
handed_off_to app-3
waiter "$past"
check "R24b a session stopped before its successor started still gets its continue" '[ "$(sed -n 1p "$c/calls" 2>/dev/null)" = "$SID" ]'

# --- limit-stop.sh, the hook ------------------------------------------------------------------------------

ago() { date -u -d "@$(($(date +%s) - $1))" +%Y-%m-%dT%H:%M:%S.000Z; } # ago <seconds> : that long ago, as a transcript writes it

hookcase() { # a case whose copy of scripts/ has a limit-resume that only records its arguments
  newcase; mkdir -p "$c/scripts"
  cp "$root/scripts/json.sh" "$root/scripts/limit-stop.sh" "$c/scripts/" 2> /dev/null
  printf '#!/bin/bash\necho "$*" > "%s/started"\n' "$c" > "$c/scripts/limit-resume"; chmod +x "$c/scripts/limit-resume"
}
hook_input() { # hook_input <session id> <transcript> [agent id] : what Claude Code passes to a StopFailure hook
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"/tmp/app","scratchpad_dir":"/tmp/scratch","prompt_id":"0e","effort":{"level":"max"},"hook_event_name":"StopFailure","error":"rate_limit","last_assistant_message":"You have hit your session limit · resets 3:45pm"%s}' "$1" "$2" "${3:+,\"agent_id\":\"$3\"}"
}
hook() { # hook <input> : runs the hook; $out is what it printed, $st its exit status
  out=$(printf '%s' "$1" | HOME="$c/home" PATH="$tmp/bin:$PATH" FAKE_LOG="$c/claude-log" bash "$c/scripts/limit-stop.sh" 2>&1); st=$?
}
started() { local i=0; while [ $i -lt 30 ] && [ ! -s "$c/started" ]; do sleep 0.1; i=$((i + 1)); done; cat "$c/started" 2> /dev/null; }
ran_and_started_nothing() { sleep 0.6; [ "$st" -eq 0 ] && [ ! -e "$c/started" ]; }

hookcase; limit_line "$(ago 0)" 1794889200 > "$c/transcript.jsonl"
hook "$(hook_input "$SID" "$c/transcript.jsonl")"
check "H1 a usage-limit stop starts the waiter with session, transcript and reset" '[ "$(started)" = "$SID $c/transcript.jsonl 1794889200" ]'
check "H9 the hook prints nothing and exits 0"     '[ "$st" -eq 0 ] && [ -z "$out" ]'
check "H10 the hook itself never calls claude"     '[ "$st" -eq 0 ] && [ ! -e "$c/claude-log" ]'

hookcase; limit_line "$(ago 0)" 1794889200 > "$c/transcript.jsonl"
CLAUDE_PLUGIN_OPTION_LIMIT_RESUME=off hook "$(hook_input "$SID" "$c/transcript.jsonl")"
check "H2 with the option off nothing starts"      'ran_and_started_nothing'

hookcase; plain_429_line "$(ago 0)" > "$c/transcript.jsonl"
hook "$(hook_input "$SID" "$c/transcript.jsonl")"
check "H3 a 429 that names no reset starts nothing and says so in the log" 'ran_and_started_nothing && grep -q "no reset time" "$L/log"'

hookcase; { limit_line "$(ago 60)" 1794889200; reply_line "$(ago 0)"; } > "$c/transcript.jsonl"
hook "$(hook_input "$SID" "$c/transcript.jsonl")"
check "H4 a turn that did not end on a limit starts nothing and says so in the log" 'ran_and_started_nothing && grep -q "no rate-limit stop in the transcript" "$L/log"'

hookcase; limit_line "$(ago 0)" 1794889200 > "$c/transcript.jsonl"
hook "$(hook_input "not-a-session-id" "$c/transcript.jsonl")"; a=$st
hook "$(hook_input "$SID" "$c/missing.jsonl")"; b=$st
hook "not json"
check "H5 a bad session id, a missing transcript or junk input starts nothing" '[ "$a" -eq 0 ] && [ "$b" -eq 0 ] && ran_and_started_nothing'

hookcase; limit_line "$(ago 0)" 1794889200 > "$c/transcript.jsonl"; mkdir -p "$L"; echo "$$ 1794889200" > "$L/$SID.pid"
hook "$(hook_input "$SID" "$c/transcript.jsonl")"
check "H6 a live waiter for the same reset is not doubled" 'ran_and_started_nothing'

hookcase; limit_line "$(ago 0)" 1794889200 > "$c/transcript.jsonl"; mkdir -p "$L"; echo "$$ 1700000000" > "$L/$SID.pid"
hook "$(hook_input "$SID" "$c/transcript.jsonl")"
check "H7 a later limit starts a new waiter"       '[ "$(started)" = "$SID $c/transcript.jsonl 1794889200" ]'

hookcase; limit_line "$(ago 0)" 1794889200 > "$c/transcript.jsonl"; mkdir -p "$L"
( : ) & dead=$!; wait "$dead"; echo "$dead 1794889200" > "$L/$SID.pid"
hook "$(hook_input "$SID" "$c/transcript.jsonl")"
check "H7b a waiter that died is replaced"          '[ "$(started)" = "$SID $c/transcript.jsonl 1794889200" ]'

hookcase; limit_line "$(ago 0)" 1794889200 > "$c/transcript.jsonl"
hook "$(hook_input "$SID" "$c/transcript.jsonl" "agent-7")"
check "H8 a subagent's stop starts nothing"        'ran_and_started_nothing'

# The stop's own line reaches the transcript a moment after the hook starts; until then the last line is
# whatever came before it, here an older stop whose reset has passed.
hookcase; limit_line "$(ago 3600)" $(($(date +%s) - 1800)) > "$c/transcript.jsonl"
( sleep 0.5; plain_429_line "$(ago 0)" >> "$c/transcript.jsonl" ) &
hook "$(hook_input "$SID" "$c/transcript.jsonl")"; wait
check "H11 an older stop is not taken for a 429 whose line lands late" 'ran_and_started_nothing && grep -q "no reset time" "$L/log"'

hookcase; limit_line "$(ago 3600)" $(($(date +%s) - 1800)) > "$c/transcript.jsonl"; later=$(($(date +%s) + 3600))
( sleep 0.5; limit_line "$(ago 0)" "$later" >> "$c/transcript.jsonl" ) &
hook "$(hook_input "$SID" "$c/transcript.jsonl")"; wait
check "H11b a limit stop whose line lands late starts the waiter with its own reset" '[ "$(started)" = "$SID $c/transcript.jsonl $later" ]'

# --- the hook and the waiter together -------------------------------------------------------------------------

chain() { # chain : runs the real hook on this case's transcript; the hook starts the real waiter, detached
  hook_input "$SID" "$c/transcript.jsonl" | HOME="$c/home" PATH="$tmp/bin:$PATH" SHELL="$tmp/bin/login-shell" \
    FAKE_AGENTS="$c/agents.json" FAKE_CALLS="$c/calls" FAKE_PIDS="$c/pids" FAKE_EOF="$c/eof" FAKE_SIGNALS="$c/signals" \
    LIMIT_RESUME_MARGIN=0 LIMIT_RESUME_POLL=1 LIMIT_RESUME_SETTLE=0 LIMIT_RESUME_HELPER_WAIT=5 \
    bash "$root/scripts/limit-stop.sh" > /dev/null 2>&1
}
logged() { # logged <text> : waits up to 15 s for the case's log to contain it
  local i=0
  until grep -q "$1" "$L/log" 2> /dev/null; do [ $((i += 1)) -le 75 ] || return 1; sleep 0.2; done
}

newcase; soon=$(($(date +%s) + 3)); limit_line "$(ago 0)" "$soon" > "$c/transcript.jsonl"; listing "$c/agents.json" background 5151 idle blocked
chain; logged "waiting for the reset"
limit_line "$(ago 0)" "$soon" >> "$c/transcript.jsonl"; chain # woken up, the session hits the same limit again
logged "sent the continue prompt"; sleep 0.5
check "X1 through the hook: a second stop at the same limit adds no waiter, and one continue is sent" '[ "$(grep -c "^$SID$" "$c/calls")" -eq 1 ] && [ "$(grep -c "waiting for the reset" "$L/log")" -eq 1 ] && [ "$(grep -c "sent the continue prompt" "$L/log")" -eq 1 ]'
check "X2 through the hook: afterwards nothing of the helper is left running" 'gone && [ ! -e "$L/$SID.pid" ] && [ ! -e "$tmp/login-shell-used" ]'

# --- watch.sh records the successor's name, which limit-resume reads ------------------------------------------

newcase; mkdir -p "$c/app"; listing "$c/agents.json" background 5151 busy working
printf '{"type":"assistant","isSidechain":false,"timestamp":"%s","message":{"model":"claude-opus-5-5","role":"assistant","usage":{"input_tokens":5,"cache_read_input_tokens":900000,"cache_creation_input_tokens":0,"output_tokens":10}},"sessionId":"%s"}\n' "$(ago 0)" "$SID" > "$c/transcript.jsonl"
printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"UserPromptSubmit"}' "$SID" "$c/transcript.jsonl" "$c/app" \
  | HOME="$c/home" PATH="$tmp/bin:$PATH" FAKE_AGENTS="$c/agents.json" bash "$root/scripts/watch.sh" > "$c/watch.out" 2>&1
check "W1 asking for a handoff, watch.sh notes the successor's name" '[ "$(cat "$c/home/.claude/session-successor/warned/$SID" 2>/dev/null)" = app-1 ] && grep -q "successor session \`app-1\`" "$c/watch.out"'

exit $fail
