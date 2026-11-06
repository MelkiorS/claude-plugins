# Minimal JSON helpers in pure bash, so the plugin doesn't need jq. They cover what the scripts read:
# flat hook input, the usage numbers on a transcript line and the flat objects of `claude agents --json`.
# Each returns the FIRST match of the key in the text it is given.

# json_str <json> <key>: the key's string value, unescaped; status 1 when the key is absent.
json_str() {
  local re='"'"$2"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  [[ $1 =~ $re ]] || return 1
  local v=${BASH_REMATCH[1]}
  # \\ first becomes a placeholder, so "\\\"" can't be read as an escaped quote.
  v=${v//\\\\/$'\x01'}
  v=${v//\\\"/\"}
  v=${v//\\\//\/}
  v=${v//\\n/$'\n'}
  v=${v//\\t/$'\t'}
  v=${v//$'\x01'/\\}
  printf '%s' "$v"
}

# json_num <json> <key>: the key's integer value; status 1 when the key is absent.
json_num() {
  local re='"'"$2"'"[[:space:]]*:[[:space:]]*(-?[0-9]+)'
  [[ $1 =~ $re ]] || return 1
  printf '%s' "${BASH_REMATCH[1]}"
}

# json_escape <string>: the string as the inside of a JSON string literal.
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}
