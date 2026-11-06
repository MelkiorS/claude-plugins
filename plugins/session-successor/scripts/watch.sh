#!/bin/bash
# Hook (UserPromptSubmit + PostToolUse): once less than THRESHOLD % of the context window is left,
# injects the handoff instruction. Fires once per session.
input=$(cat)
threshold=${CLAUDE_PLUGIN_OPTION_THRESHOLD:-20}
window=${CLAUDE_PLUGIN_OPTION_CONTEXT_WINDOW:-1000000}
STATE="$HOME/.claude/session-successor"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=json.sh
. "$SCRIPTS/json.sh"

field() { json_str "$input" "$1"; }
sid=$(field session_id)
transcript=$(field transcript_path)
[ -n "$sid" ] && [ -f "$transcript" ] || exit 0
# Marks the session as watched. A session started before the plugin was installed never loads this
# hook and never appears in active/, which is how to tell it needs a restart.
mkdir -p "$STATE/active" && : > "$STATE/active/$sid"
[ -z "$(field agent_id)" ] || exit 0 # subagents never hand off
[ -e "$STATE/warned/$sid" ] && exit 0

# Context in use = the last main-thread request's input + cache tokens (matches the statusline's
# context_window.remaining_percentage). Only the tail is read: the last request is near the end.
last=$(tail -n 400 "$transcript" | grep '"type":"assistant"' | grep -v '"isSidechain":true' \
  | grep -v '"model":"<synthetic>"' | tail -1)
[ -n "$last" ] || exit 0
used=$(( $(json_num "$last" input_tokens || echo 0) + $(json_num "$last" cache_read_input_tokens || echo 0) \
  + $(json_num "$last" cache_creation_input_tokens || echo 0) ))
[ "$used" -gt 0 ] || exit 0
remaining=$(awk -v u="$used" -v w="$window" 'BEGIN { r = 100 - u * 100 / w; printf "%d", (r < 0 ? 0 : r) }')
[ "$remaining" -lt "$threshold" ] || exit 0

mkdir -p "$STATE/warned" "$STATE/prompts"
: > "$STATE/warned/$sid"

cwd=$(field cwd)
new=$("$SCRIPTS/successor" name "$transcript" "$cwd")
prompt="$STATE/prompts/$new.md"

read -r -d '' msg <<EOF
CONTEXT HANDOFF REQUIRED: only about ${remaining}% of this session's context window is left.
Do these steps now, in order:
1. Stop at the next logical point. Finish or cleanly park the current step (no half-applied edits); start nothing new.
2. Write a handoff prompt for your successor session \`${new}\` to ${prompt}. Write it so a fresh session with no other context can continue: goal and why; what is done; current state (branch, uncommitted changes, running processes); next steps; key files; open questions and decisions; peer sessions (names and what each one is doing); gotchas. Start it with: "You are ${new}, continuing the work of the previous session."
3. Run: "${SCRIPTS}/successor" start --name ${new} --cwd "${cwd}" --prompt "${prompt}"
4. For every peer session you have exchanged messages with, use SendMessage: "I'm handing off — from now on message ${new}."
5. End with one line: "Handed off to ${new} (claude attach ${new})". Then do no further work in this session.
EOF

printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
  "$(json_escape "$(field hook_event_name)")" "$(json_escape "$msg")"
