#!/bin/bash
# Hook (StopFailure, matcher rate_limit; Claude Code runs it in the background with asyncRewake): a turn ended
# on a rate limit. When that was a usage limit with a known reset time, it hands over to the waiter
# (scripts/limit-resume), which wakes a background session with a continue prompt just after the reset. It
# makes no `claude` call itself; the waiter does the checking.
input=$(cat)
[ "${CLAUDE_PLUGIN_OPTION_LIMIT_RESUME:-on}" == "on" ] || exit 0
STATE="$HOME/.claude/session-successor/limits"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=json.sh
. "$SCRIPTS/json.sh"

sid=$(json_str "$input" session_id) || exit 0
transcript=$(json_str "$input" transcript_path) || exit 0
[[ $sid =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] && [ -f "$transcript" ] || exit 0
[ -z "$(json_str "$input" agent_id || true)" ] || exit 0 # a subagent's stop is its parent's business

log() { printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$sid" "$*" >> "$STATE/log"; }

# The stop is the transcript's last main-thread assistant line. That line reaches the file a moment after
# the hook starts (live: absent at the start, there two seconds later), and until it does the last line is
# whatever came before, possibly an older stop. So only a line written in the 30 seconds before the hook
# started counts. 30 stays below the waiter's 90-second margin, so a stop that a continue prompt runs into
# can never be taken for the stop before it. A plan limit carries its reset as epoch seconds; any other 429
# has none and starts nothing.
export LC_ALL=C # so ISO times compare as plain strings
since=$(($(date +%s) - 30))
since=$(date -u -d "@$since" +%Y-%m-%dT%H:%M:%S 2> /dev/null || date -u -r "$since" +%Y-%m-%dT%H:%M:%S)
turn=""
for ((i = 0; i < 25; i++)); do
  turn=$(tail -n 400 "$transcript" | grep '"type":"assistant"' | grep -v '"isSidechain":true' | tail -1)
  [[ $turn == *'"isApiErrorMessage":true'* && $turn == *'"error":"rate_limit"'* ]] \
    && ! [[ $(json_str "$turn" timestamp) < $since ]] && break
  turn=""
  sleep 0.2
done
mkdir -p "$STATE" && chmod 700 "${STATE%/*}" "$STATE"
[ -n "$turn" ] || { log "skip: no rate-limit stop in the transcript from the last 30 seconds"; exit 0; }
reset=$(json_num "$turn" resetsAt) || { log "skip: a rate-limit stop with no reset time, so not a plan limit"; exit 0; }

# One waiter per session: nothing to do while a live one already waits for this reset.
if read -r pid waiting 2> /dev/null < "$STATE/$sid.pid" && [ "$waiting" == "$reset" ] && kill -0 "$pid" 2> /dev/null; then
  exit 0
fi

# The waiter takes over this process. Claude Code runs this hook in the background (asyncRewake in hooks.json),
# so the wait blocks nothing, and when the waiter exits with status 2, Claude Code wakes the session's model
# with the text it printed.
exec "$SCRIPTS/limit-resume" "$sid" "$transcript" "$reset"
