#!/usr/bin/env bash
# Claude Code statusLine command (no jq dependency)

input=$(cat 2>/dev/null || true)

if [ -n "$input" ]; then
  cwd=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | sed 's/"current_dir":"//;s/"//')
  # used_percentage appears 3 times: 1st=context_window, 2nd=five_hour, 3rd=seven_day
  all_pcts=$(echo "$input" | grep -o '"used_percentage":[0-9]*' | grep -o '[0-9]*$')
  ctx=$(echo "$all_pcts" | sed -n '1p')
  five_hour=$(echo "$all_pcts" | sed -n '2p')
  seven_day=$(echo "$all_pcts" | sed -n '3p')
  # resets_at 은 rate_limits 안에만 있다 (5h → 7d 순, unix epoch seconds)
  all_resets=$(echo "$input" | grep -o '"resets_at":[0-9]*' | grep -o '[0-9]*$')
  five_hour_reset=$(echo "$all_resets" | sed -n '1p')
  seven_day_reset=$(echo "$all_resets" | sed -n '2p')
  sid=$(echo "$input" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')
  model_name=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | sed 's/"display_name":"//;s/"//')
fi

[ -z "$cwd" ] && cwd=$(pwd)
cwd=$(echo "$cwd" | sed 's/\\\\/\//g')
five_hour=${five_hour:-}
seven_day=${seven_day:-}
ctx=${ctx:-}
sid8=${sid:0:8}
model_name=${model_name:-}

# epoch(초) → 로컬 시각. 5h 는 당일이라 HH:MM, 7d 는 날짜가 바뀌므로 MM/DD HH:MM.
# GNU date(-d @epoch) 없는 환경 대비 실패 시 필드 자체를 비운다 (깨진 시각 표시 금지).
five_hour_reset_h=""
[ -n "$five_hour_reset" ] && five_hour_reset_h=$(date -d "@$five_hour_reset" '+%H:%M' 2>/dev/null)
seven_day_reset_h=""
[ -n "$seven_day_reset" ] && seven_day_reset_h=$(date -d "@$seven_day_reset" '+%m/%d %H:%M' 2>/dev/null)

# 5초 TTL 캐시 — Windows + Git Bash 환경에서 매 토큰마다 git fork 비용 누적 방지
git_branch=""
if [ -n "$cwd" ]; then
  cache_key=$(echo "$cwd" | md5sum 2>/dev/null | cut -c1-8)
  cache_file="/tmp/claude_statusline_branch_${cache_key}"
  cache_age=999
  if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
    cache_age=$(( $(date +%s) - cache_mtime ))
  fi
  if [ "$cache_age" -lt 5 ] && [ -f "$cache_file" ]; then
    git_branch=$(cat "$cache_file" 2>/dev/null)
  else
    git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
    echo "$git_branch" > "$cache_file" 2>/dev/null
  fi
fi
[ -n "$git_branch" ] && git_branch=" ($git_branch)"

yellow='\033[33m'
cyan='\033[36m'
white='\033[37m'
dim='\033[2m'
reset='\033[0m'

usage=""
[ -n "$model_name" ] && usage="${model_name}"
[ -n "$sid8" ] && usage="${usage:+${usage} }sid:${sid8}"
if [ -n "$five_hour" ]; then
  usage="${usage:+${usage} }5h:${five_hour}%%"
  [ -n "$five_hour_reset_h" ] && usage="${usage}(${five_hour_reset_h})"
fi
if [ -n "$seven_day" ]; then
  usage="${usage:+${usage} }7d:${seven_day}%%"
  [ -n "$seven_day_reset_h" ] && usage="${usage}(${seven_day_reset_h})"
fi
[ -n "$ctx" ] && usage="${usage:+${usage} }Ctx:${ctx}%%"

# 첫 줄을 비워 실제 내용을 한 칸 아래로 내린다 — 출력 줄 수 = 표시 행 수
if [ -n "$usage" ]; then
  printf "\n${yellow}${cwd}${reset}${cyan}${git_branch}${reset} ${dim}|${reset} ${white}${usage}${reset}"
else
  printf "\n${yellow}${cwd}${reset}${cyan}${git_branch}${reset}"
fi
