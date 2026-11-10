#!/usr/bin/env bash
# Prints the spike rules as a hook's additionalContext, for SessionStart and SubagentStart.
# Usage: rules.sh <SessionStart|SubagentStart>
# It always exits 0, so a problem here can never block a session. Plain bash 3.2, no jq.

# json_escape <string>: the string as the inside of a JSON string literal.
# Copied from plugins/session-successor/scripts/json.sh: an install copies only this plugin's folder.
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

case $1 in
  SessionStart|SubagentStart) ;;
  *) exit 0 ;;
esac

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 0
[ -r "$dir/rules.md" ] || exit 0
text=$(<"$dir/rules.md")
# The install hint goes unless the user switched it off (plugin option suggest_tools).
if [ "${CLAUDE_PLUGIN_OPTION_SUGGEST_TOOLS:-on}" != off ] && [ -r "$dir/hint.md" ]; then
  text="$text"$'\n\n'"$(<"$dir/hint.md")"
fi
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$(json_escape "$text")"
exit 0
