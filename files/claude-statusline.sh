#!/usr/bin/env bash
# Claude Code status line — Tokyo Night palette, single line, pipe-separated.
# Reads JSON session data from stdin and prints one status line to stdout.
# Schema: https://code.claude.com/docs/en/statusline.md

set -u

input=$(cat)

# ---- Tokyo Night Gogh palette (24-bit truecolor) ----
SEP=$'\033[38;2;65;72;104m'       # #414868  separators (Gogh color_01)
LABEL=$'\033[38;2;86;95;137m'     # #565f89  ctx/5h/7d labels (Helix `comment`)
MODEL_FG=$'\033[38;2;122;162;247m' # #7aa2f7  model (Tokyo Night blue — Helix markup.heading)
MAGENTA=$'\033[38;2;187;154;247m' # #bb9af7  effort
GREEN=$'\033[38;2;158;206;106m'  # #9ece6a  ok / branch
YELLOW=$'\033[38;2;224;175;104m' # #e0af68  warn / cost
RED=$'\033[38;2;247;118;142m'    # #f7768e  critical
RESET=$'\033[0m'

# ---- One jq pass: emit one field per line. mapfile preserves empty lines so
#      absent fields stay aligned (bash `read` collapses adjacent IFS tabs). ----
mapfile -t F < <(
  jq -r '
    .model.display_name      // "?",
    .effort.level            // "",
    (.context_window.used_percentage // 0 | floor | tostring),
    (.rate_limits.five_hour.used_percentage  // "" | tostring),
    (.rate_limits.seven_day.used_percentage  // "" | tostring),
    (.cost.total_cost_usd    // 0 | tostring),
    .workspace.current_dir   // ".",
    .session_id              // "nosession"
  ' <<<"$input"
)
MODEL=${F[0]}; EFFORT=${F[1]}; CTX=${F[2]}
FIVE_H=${F[3]}; SEVEN_D=${F[4]}; COST=${F[5]}
CWD=${F[6]}; SESSION=${F[7]}

# ---- git branch (cached 5s per session_id) ----
CACHE="/tmp/claude-statusline-git-${SESSION}"
now=$(date +%s)
mtime=0
[ -f "$CACHE" ] && mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)
if [ ! -f "$CACHE" ] || [ $((now - mtime)) -gt 5 ]; then
  branch=$(git -C "$CWD" branch --show-current 2>/dev/null || true)
  printf '%s' "$branch" >"$CACHE"
fi
BRANCH=$(cat "$CACHE" 2>/dev/null || true)

# ---- Threshold-based color picker ----
pct_color() { # $1=value $2=mid $3=hi
  local v="${1%.*}"
  if   [ "$v" -ge "$3" ]; then printf '%s' "$RED"
  elif [ "$v" -ge "$2" ]; then printf '%s' "$YELLOW"
  else                          printf '%s' "$GREEN"
  fi
}

# ---- Build line 1 (model / effort / branch) ----
line1=()
if [ -n "$EFFORT" ]; then
  line1+=( "${MODEL_FG}${MODEL}${RESET} ${SEP}|${RESET} ${MAGENTA}${EFFORT}${RESET}" )
else
  line1+=( "${MODEL_FG}${MODEL}${RESET}" )
fi
[ -n "$BRANCH" ] && line1+=( "${GREEN}🌿 ${BRANCH}${RESET}" )

# ---- Build line 2 (ctx / 5h / 7d / cost) ----
line2=()
ctx_c=$(pct_color "$CTX" 70 90)
line2+=( "${LABEL}ctx${RESET} ${ctx_c}${CTX}%${RESET}" )
if [ -n "$FIVE_H" ]; then
  five_int=$(printf '%.0f' "$FIVE_H")
  five_c=$(pct_color "$five_int" 50 80)
  line2+=( "${LABEL}5h${RESET} ${five_c}${five_int}%${RESET}" )
fi
if [ -n "$SEVEN_D" ]; then
  seven_int=$(printf '%.0f' "$SEVEN_D")
  seven_c=$(pct_color "$seven_int" 50 80)
  line2+=( "${LABEL}7d${RESET} ${seven_c}${seven_int}%${RESET}" )
fi
cost_fmt=$(printf '$%.2f' "$COST")
line2+=( "${YELLOW}${cost_fmt}${RESET}" )

# ---- Join each line with " | " and print ----
sep=" ${SEP}|${RESET} "
join_segs() {
  local out="" s
  for s in "$@"; do
    [ -n "$out" ] && out+="$sep"
    out+="$s"
  done
  printf '%b\n' "$out"
}
join_segs "${line1[@]}"
join_segs "${line2[@]}"
