#!/usr/bin/env bash
# Claude Code status line — context window, model, cost, git, rate limits.
#
# Reads the session JSON on stdin (schema:
# https://code.claude.com/docs/en/statusline) and prints two lines:
#   line 1: dir · git branch · model · effort · output style
#   line 2: context bar · % · tokens · cost · session time · rate limits
#
# Stowed to ~/.claude/statusline.sh and referenced from settings.json.
# Depends on: jq, git (optional). Degrades gracefully if fields are absent.
set -uo pipefail

input=$(cat)

# One jq pass -> fields joined by US (\x1f). Tab can't be used: bash treats it as
# IFS-whitespace and collapses empty fields, misaligning the read. // fallbacks
# keep early-session nulls sane.
IFS=$'\x1f' read -r model effort style pct size in_tok out_tok cost dur_ms five_h seven_d cwd < <(
  printf '%s' "$input" | jq -r '
    [ .model.display_name                       // "?"
    , .effort.level                             // ""
    , .output_style.name                        // ""
    , (.context_window.used_percentage          // 0 | floor)
    , (.context_window.context_window_size      // 200000)
    , (.context_window.total_input_tokens       // 0)
    , (.context_window.total_output_tokens      // 0)
    , (.cost.total_cost_usd                     // 0)
    , (.cost.total_duration_ms                  // 0)
    , (.rate_limits.five_hour.used_percentage   // "")
    , (.rate_limits.seven_day.used_percentage   // "")
    , (.workspace.current_dir // .cwd           // "")
    ] | map(tostring) | join("")'
)

# --- colors -----------------------------------------------------------------
R=$'\e[0m'; DIM=$'\e[2m'; B=$'\e[1m'
GRN=$'\e[32m'; YEL=$'\e[33m'; RED=$'\e[31m'; CYN=$'\e[36m'; BLU=$'\e[34m'; MAG=$'\e[35m'

# --- context bar ------------------------------------------------------------
pct=${pct:-0}
(( pct > 100 )) && pct=100
filled=$(( pct / 10 ))
bar=""
for ((i = 0; i < 10; i++)); do
  if (( i < filled )); then bar+="▓"; else bar+="░"; fi
done
if   (( pct >= 80 )); then bcol=$RED
elif (( pct >= 50 )); then bcol=$YEL
else                       bcol=$GRN
fi

# tokens currently in the context window (input incl. cache + output), in k
usedk=$(( (in_tok + out_tok) / 1000 ))
sizek=$(( size / 1000 ))

# --- session duration -------------------------------------------------------
dur=$(( dur_ms / 1000 ))
if   (( dur >= 3600 )); then dur="$(( dur / 3600 ))h$(( (dur % 3600) / 60 ))m"
elif (( dur >= 60 ));   then dur="$(( dur / 60 ))m"
else                         dur="${dur}s"
fi

# --- git branch (cheap; dotfiles repo is small) -----------------------------
branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && branch+="*"
fi

# --- rate limits (Pro/Max only; absent otherwise) ---------------------------
limits=""
if [ -n "$five_h" ] || [ -n "$seven_d" ]; then
  fh=$([ -n "$five_h" ]  && printf '%.0f' "$five_h"  || echo "?")
  sd=$([ -n "$seven_d" ] && printf '%.0f' "$seven_d" || echo "?")
  limits="  ${CYN}${fh}%/5h ${sd}%/7d${R}"
fi

# --- assemble ---------------------------------------------------------------
dir="${cwd##*/}"
meta="${B}${model}${R}"
[ -n "$effort" ] && meta+=" ${DIM}· ${effort}${R}"
[ -n "$style" ] && [ "$style" != "default" ] && meta+=" ${DIM}· ${style}${R}"

line1="${BLU}${dir}${R}"
[ -n "$branch" ] && line1+="  ${MAG}⎇ ${branch}${R}"
line1+="   ${meta}"

line2="${bcol}${bar}${R} ${B}${pct}%${R} ${DIM}${usedk}k/${sizek}k${R}  ${DIM}${dur}${R}${limits}"

printf '%s\n%s' "$line1" "$line2"
