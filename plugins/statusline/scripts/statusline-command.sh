#!/bin/bash
# Keeps the git calls below from taking locks in the repo you are working in.
export GIT_OPTIONAL_LOCKS=0
exec 2>/dev/null
input=$(cat)

# Simple JSON parsing using bash
extract_value() {
  local json="$1"
  local key="$2"
  if [[ $json =~ \"$key\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

extract_number() {
  local json="$1"
  local key="$2"
  if [[ $json =~ \"$key\"[[:space:]]*:[[:space:]]*([0-9.]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

model_name=$(extract_value "$input" "display_name")
remaining_pct=$(extract_number "$input" "remaining_percentage")

# Motivational phrases (100 items)
phrases=(
  "🚀 Ship it!"
  "💪 Let's go!"
  "⚡ Full speed!"
  "🎯 Stay focused!"
  "🔥 On fire!"
  "✨ Make magic!"
  "🏆 You got this!"
  "💡 Think big!"
  "🌟 Be awesome!"
  "⭐ Star coder!"
  "🎸 Rock on!"
  "🧠 Big brain time!"
  "💎 Gem quality!"
  "🦾 Beast mode!"
  "🎪 Show time!"
  "🌈 Dream big!"
  "⚔️ Code warrior!"
  "🛡️ Bug slayer!"
  "🎭 Pure art!"
  "🔮 Future proof!"
  "🧩 Piece by piece!"
  "🎯 Bullseye!"
  "🏄 Ride the flow!"
  "🧗 Climb higher!"
  "🎿 Smooth run!"
  "🏃 Sprint mode!"
  "🚴 Keep pedaling!"
  "🏋️ Heavy lifting!"
  "🥊 Fight bugs!"
  "🏹 Sharp aim!"
  "🎣 Hook it!"
  "🎳 Strike!"
  "🎰 Jackpot code!"
  "🎲 Roll the dice!"
  "🃏 Wild card!"
  "♟️ Checkmate!"
  "🧬 DNA of code!"
  "⚗️ Pure alchemy!"
  "🔬 Deep dive!"
  "🔭 See further!"
  "🛸 To infinity!"
  "🌍 Change the world!"
  "🌙 Moon shot!"
  "☀️ Shine bright!"
  "⛈️ Storm chaser!"
  "🌊 Make waves!"
  "🏔️ Peak performance!"
  "🌋 Explosive code!"
  "💫 Stellar work!"
  "🎆 Fireworks!"
  "🎇 Sparkle!"
  "🧨 Dynamite!"
  "💥 Boom!"
  "🎉 Celebrate!"
  "🎊 Party time!"
  "🥳 Woohoo!"
  "🍾 Pop it!"
  "🏅 Gold medal!"
  "🥇 First place!"
  "👑 King mode!"
  "🦁 Lion heart!"
  "🐉 Dragon power!"
  "🦅 Soar high!"
  "🐺 Wolf pack!"
  "🦊 Clever fox!"
  "🐝 Busy bee!"
  "🦋 Transform!"
  "🐙 Octopush!"
  "🦈 Shark mode!"
  "🐋 Whale of code!"
  "🦄 Unicorn dev!"
  "🐲 Slay it!"
  "🔋 Fully charged!"
  "⚙️ Well oiled!"
  "🔧 Fix it!"
  "🔨 Build it!"
  "⛏️ Mine gold!"
  "🗡️ Slash bugs!"
  "🏰 Fortress code!"
  "🗼 Tower of logic!"
  "🌉 Bridge gaps!"
  "🛤️ On track!"
  "✈️ Take off!"
  "🚂 Full steam!"
  "🚁 Hover mode!"
  "🛥️ Smooth sailing!"
  "⛵ Set sail!"
  "🚦 Green light!"
  "💯 Perfect score!"
  "🔝 Top tier!"
  "📈 Level up!"
  "🆙 Power up!"
  "🎮 Game on!"
  "🕹️ Player one!"
  "👾 Invader mode!"
  "🤖 Robot mode!"
  "👨‍💻 Hacker vibes!"
  "🧙 Code wizard!"
  "🦸 Super dev!"
  "🥷 Ninja code!"
  "💪 You can do it!"
  "🌟 It'll all work out!"
  "🔥 You're the best!"
  "🚀 Chase your dream!"
  "✨ You're on the right track!"
  "🏆 Victory is near!"
  "💎 You're a diamond!"
  "⭐ Stars align for you!"
  "🎯 You will make it!"
  "🦁 Unleash the lion!"
  "☀️ Your time is now!"
  "🌈 Sun after the storm!"
  "💫 You create wonders!"
  "🏔️ The summit awaits!"
  "🐉 You're unstoppable!"
  "👑 King of the code!"
  "🦅 Fly even higher!"
  "🌊 Ride the wave of success!"
  "⚡ Energy at max!"
  "🎪 Show them what you got!"
  "🧠 You're a genius!"
  "💡 Ideas are flowing!"
  "🔋 Stay strong, push on!"
  "🌍 You're changing the world!"
  "🎸 You're a rockstar!"
  "🦄 One of a kind!"
  "🏄 Catch the wave!"
  "🌙 Dream without limits!"
  "🐺 Wolf-like focus!"
  "🧗 Almost at the top!"
  "💥 You're dynamite!"
  "🎉 Celebrate every step!"
  "🦸 You're a superhero!"
  "🔮 The future is yours!"
  "🏅 Gold is yours!"
  "⛵ Wind at your back!"
  "🌋 Power off the charts!"
  "🧙 You're a code mage!"
  "🎭 A work of art!"
  "🐝 Hard work pays off!"
  "🌟 Shine even brighter!"
  "🚂 Full speed ahead!"
  "💯 You're 100 percent!"
  "🦋 Transformation in progress!"
  "🏰 Build your empire!"
  "🎆 Firework of talent!"
  "🗡️ Cut through the doubt!"
  "✈️ Soar beyond limits!"
  "🧩 The puzzle is coming together!"
  "🐋 You're a giant!"
)
# Change phrase every hour (Unix timestamp / 3600 seconds)
hour_seed=$(($(date +%s) / 3600))
motivation="${phrases[$((hour_seed % ${#phrases[@]}))]}"

# Model name
model_short="${model_name:-claude}"

# Project name from current directory
project=$(basename "$(pwd)")

# Git branch + color based on status
git_info=""
git_color=""
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  is_dirty=false
  if ! git diff --quiet 2>/dev/null || \
     ! git diff --cached --quiet 2>/dev/null || \
     [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    is_dirty=true
  fi
  [ "$is_dirty" = true ] && branch_dot="\033[31m●\033[0m" || branch_dot="\033[32m●\033[0m"
fi

# Context remaining with color coding
ctx_color="\033[32m"  # green
if [ -n "$remaining_pct" ] && [ "$remaining_pct" != "null" ]; then
  remaining_int=$(printf "%.0f" "$remaining_pct")
  if [ "$remaining_int" -lt 25 ]; then
    ctx_color="\033[31m"  # red
  elif [ "$remaining_int" -lt 50 ]; then
    ctx_color="\033[33m"  # yellow
  fi
  ctx=$(printf "%.0f%%" "$remaining_pct")
else
  ctx="100%"
fi

# Build output with │ separators
DIM="\033[2m"
RST="\033[0m"
output="\033[1m\033[35m${model_short}${RST}"
output="${output} ${DIM}│${RST} \033[1m\033[36m${project}${RST}"
if [ -n "$branch" ]; then
  output="${output} ${DIM}│${RST} \033[32m${branch}${RST} ${branch_dot}"
fi
output="${output} ${DIM}│${RST} ${DIM}ctx:${RST} \033[1m${ctx_color}${ctx}${RST}"
output="${output} ${DIM}│${RST} \033[36m${motivation}${RST}"

printf "%b" "$output"