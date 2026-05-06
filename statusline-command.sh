#!/usr/bin/env bash
# Claude Code statusLine command (no jq dependency)

input=$(cat 2>/dev/null || true)

if [ -n "$input" ]; then
  cwd=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | sed 's/"current_dir":"//;s/"//')
  # used_percentage appears 3 times: 1st=context_window, 2nd=five_hour, 3rd=seven_day
  all_pcts=$(echo "$input" | grep -o '"used_percentage":[0-9]*' | grep -o '[0-9]*$')
  ctx=$(echo "$all_pcts" | sed -n '1p')
  five_hour=$(echo "$all_pcts" | sed -n '2p')
  # total tokens: sum of total_input_tokens + total_output_tokens
  total_input=$(echo "$input" | grep -o '"total_input_tokens":[0-9]*' | grep -o '[0-9]*$')
  total_output=$(echo "$input" | grep -o '"total_output_tokens":[0-9]*' | grep -o '[0-9]*$')
  if [ -n "$total_input" ] && [ -n "$total_output" ]; then
    total_tokens=$((total_input + total_output))
  fi
fi

[ -z "$cwd" ] && cwd=$(pwd)
cwd=$(echo "$cwd" | sed 's/\\\\/\//g')
five_hour=${five_hour:-}
ctx=${ctx:-}
total_tokens=${total_tokens:-}

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
[ -n "$ctx" ] && usage="Ctx:${ctx}%%"
[ -n "$five_hour" ] && usage="5h:${five_hour}%% ${usage}"
[ -n "$total_tokens" ] && usage="${usage:+${usage} }Tokens:${total_tokens}"

if [ -n "$usage" ]; then
  printf "${yellow}${cwd}${reset}${cyan}${git_branch}${reset} ${dim}|${reset} ${white}${usage}${reset}"
else
  printf "${yellow}${cwd}${reset}${cyan}${git_branch}${reset}"
fi
