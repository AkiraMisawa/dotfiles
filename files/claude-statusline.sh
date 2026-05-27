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

# ---- One jq pass: emit one field per line. Read line-by-line (instead of
#      `mapfile`, a bash 4+ builtin absent from macOS's bash 3.2) with `IFS=`
#      so empty lines are preserved and absent fields stay aligned. ----
F=()
while IFS= read -r line; do F+=( "$line" ); done < <(
  jq -r '
    .model.display_name      // "?",
    .effort.level            // "",
    (.context_window.used_percentage // 0 | floor | tostring),
    (.rate_limits.five_hour.used_percentage  // "" | tostring),
    (.rate_limits.seven_day.used_percentage  // "" | tostring),
    (.cost.total_cost_usd    // 0 | tostring),
    .workspace.current_dir   // ".",
    .session_id              // "nosession",
    (.context_window.total_input_tokens // 0 | tostring)
  ' <<<"$input"
)
MODEL=${F[0]}; EFFORT=${F[1]}; CTX=${F[2]}
FIVE_H=${F[3]}; SEVEN_D=${F[4]}; COST=${F[5]}
CWD=${F[6]}; SESSION=${F[7]}; CTX_TOK=${F[8]}

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

# ---- Human-readable token count: 512 -> "512", 2000 -> "2k", 25600 -> "25.6k" ----
fmt_tokens() { # $1=integer token count
  awk -v n="$1" 'BEGIN {
    if (n < 1000) { printf "%d", n; exit }
    s = sprintf("%.1f", n / 1000); sub(/\.0$/, "", s); printf "%sk", s
  }'
}

# ---- Build segments (model / effort / ctx / 5h / 7d / cost / branch) ----
segs=()
if [ -n "$EFFORT" ]; then
  segs+=( "${MODEL_FG}${MODEL}${RESET} ${SEP}|${RESET} ${MAGENTA}${EFFORT}${RESET}" )
else
  segs+=( "${MODEL_FG}${MODEL}${RESET}" )
fi

ctx_c=$(pct_color "$CTX" 70 90)
ctx_tok=$(fmt_tokens "$CTX_TOK")
segs+=( "${LABEL}ctx${RESET} ${LABEL}${ctx_tok}${RESET} ${ctx_c}${CTX}%${RESET}" )
if [ -n "$FIVE_H" ]; then
  five_int=$(printf '%.0f' "$FIVE_H")
  five_c=$(pct_color "$five_int" 50 80)
  segs+=( "${LABEL}5h${RESET} ${five_c}${five_int}%${RESET}" )
fi
if [ -n "$SEVEN_D" ]; then
  seven_int=$(printf '%.0f' "$SEVEN_D")
  seven_c=$(pct_color "$seven_int" 50 80)
  segs+=( "${LABEL}7d${RESET} ${seven_c}${seven_int}%${RESET}" )
fi
cost_fmt=$(printf '$%.2f' "$COST")
segs+=( "${YELLOW}${cost_fmt}${RESET}" )

[ -n "$BRANCH" ] && segs+=( "${GREEN}🌿 ${BRANCH}${RESET}" )

# ---- Join with " | " and print ----
sep=" ${SEP}|${RESET} "
out=""
for s in "${segs[@]}"; do
  [ -n "$out" ] && out+="$sep"
  out+="$s"
done
printf '%b\n' "$out"
