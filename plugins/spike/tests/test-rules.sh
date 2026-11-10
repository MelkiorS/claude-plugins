#!/usr/bin/env bash
# Checks scripts/rules.sh. Run: bash plugins/spike/tests/test-rules.sh (python3 parses the JSON).
root=$(cd "$(dirname "$0")/.." && pwd); fail=0
ctx() { # ctx <event> [suggest_tools]: prints the event name, then additionalContext
  CLAUDE_PLUGIN_OPTION_SUGGEST_TOOLS=$2 bash "$root/scripts/rules.sh" "$1" | python3 -I -c '
import json, sys
o = json.load(sys.stdin)["hookSpecificOutput"]
print(o["hookEventName"]); print(o["additionalContext"])'
}
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
s=$(ctx SessionStart); a=$(ctx SubagentStart); off=$(ctx SessionStart off)
want=$(printf '%s\n\n%s' "$(<"$root/scripts/rules.md")" "$(<"$root/scripts/hint.md")")
check "SessionStart event name"      '[ "$(head -1 <<<"$s")" = SessionStart ]'
check "SubagentStart event name"     '[ "$(head -1 <<<"$a")" = SubagentStart ]'
check "rules + hint round-trip"      '[ -n "$want" ] && [ "$(tail -n +2 <<<"$s")" = "$want" ]'
check "hint gone when off"           '[ -n "$off" ] && ! grep -q "Spikes work best with" <<<"$off"'
check "rules kept when off"          'grep -q "Spike rules" <<<"$off"'
check "skipped-source rule kept when off" 'grep -q "Name any source you skipped" <<<"$off"'
check "user's own instructions win"  'grep -q "the user'"'"'s instructions and CLAUDE.md files (user or project) win" <<<"$s"'
check "probes change no shared system" 'grep -q "throwaway probe that changes no shared system" <<<"$s"'
check "no paste-into-subagents line" '! grep -q "for a subagent or another session passes" <<<"$s"'
check "rules + hint under 400 words"  '[ "$(cat "$root/scripts/rules.md" "$root/scripts/hint.md" | wc -w)" -lt 400 ]'
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp "$root/scripts/rules.sh" "$tmp/"   # the script alone, with no rules.md beside it
check "no rules.md prints nothing"   '[ -z "$(bash "$tmp/rules.sh" SessionStart)" ]'
check "off output is exactly rules.md" '[ "$(tail -n +2 <<<"$off")" = "$(<"$root/scripts/rules.md")" ]'
check "unknown event prints nothing" '[ -z "$(bash "$root/scripts/rules.sh" Stop)" ]'
check "always exits 0"               'bash "$root/scripts/rules.sh" Stop; [ $? -eq 0 ]'
exit $fail
