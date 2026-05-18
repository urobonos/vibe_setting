#!/usr/bin/env bash
# aggregate-hook-stats.sh — telemetry 집계 스크립트 (2026-05-13 도입)
#
# 사용:
#   bin/aggregate-hook-stats.sh                    # 오늘 전체 hook 집계
#   bin/aggregate-hook-stats.sh --date 2026-05-13  # 특정 날짜
#   bin/aggregate-hook-stats.sh --days 7           # 최근 7일
#   bin/aggregate-hook-stats.sh --hook gate-approve --days 30  # 특정 hook 30일
#   bin/aggregate-hook-stats.sh --json             # ndjson 원본 출력 (다른 도구 파이프)
#
# 입력: ~/.claude/logs/*.log (lib/log-helper.sh 표준 ndjson)
# 출력: 표 형식 (hook × event × count) 또는 ndjson
#
# 의존: bash, jq (jq 부재 시 fallback grep/sed)
#
# SSOT: 본 스크립트 + ~/.claude/hooks/lib/log-helper.sh (로거)

set -uo pipefail

LOG_ROOT="${HOME}/.claude/logs"
DATE_FILTER=""
DAYS_FILTER=""
HOOK_FILTER=""
JSON_OUTPUT=false

usage() {
  cat <<EOF
사용: $0 [옵션]

옵션:
  --date YYYY-MM-DD     특정 날짜만 집계 (기본 = 오늘)
  --days N              최근 N 일 집계 (date 와 상호 배제)
  --hook NAME           특정 hook 만 집계 (예: gate-approve)
  --json                ndjson 원본 출력
  --help                본 사용법 표시

예:
  $0                              # 오늘 전체
  $0 --days 7                     # 최근 7일
  $0 --hook gate-approve --days 30
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --date) DATE_FILTER="$2"; shift 2 ;;
    --days) DAYS_FILTER="$2"; shift 2 ;;
    --hook) HOOK_FILTER="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# 기본 = 오늘
if [ -z "$DATE_FILTER" ] && [ -z "$DAYS_FILTER" ]; then
  DATE_FILTER=$(date +%Y-%m-%d)
fi

# 로그 디렉토리 존재 확인
if [ ! -d "$LOG_ROOT" ]; then
  echo "[aggregate] $LOG_ROOT 미존재 — telemetry 인프라 미구축 또는 로그 0건" >&2
  exit 1
fi

# 대상 hook 파일 결정
if [ -n "$HOOK_FILTER" ]; then
  LOG_FILES=("$LOG_ROOT/${HOOK_FILTER}.log")
else
  mapfile -t LOG_FILES < <(find "$LOG_ROOT" -maxdepth 1 -type f -name "*.log" 2>/dev/null)
fi

if [ ${#LOG_FILES[@]} -eq 0 ]; then
  echo "[aggregate] 매칭 로그 0건" >&2
  exit 0
fi

# 날짜 필터 — bash 정규식으로 ts prefix 매칭
date_match_pattern() {
  if [ -n "$DATE_FILTER" ]; then
    echo "$DATE_FILTER"
    return
  fi
  if [ -n "$DAYS_FILTER" ]; then
    local pattern=""
    local i=0
    while [ "$i" -lt "$DAYS_FILTER" ]; do
      local d
      d=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null) || d=$(date -v-${i}d +%Y-%m-%d 2>/dev/null)
      if [ -n "$d" ]; then
        pattern="${pattern:+$pattern|}$d"
      fi
      i=$((i + 1))
    done
    echo "$pattern"
    return
  fi
}

DATE_PATTERN=$(date_match_pattern)

# ─────────────────────────────────────────────────────────
# 출력 1: ndjson 원본 (--json)
# ─────────────────────────────────────────────────────────
if [ "$JSON_OUTPUT" = true ]; then
  for log_file in "${LOG_FILES[@]}"; do
    [ -f "$log_file" ] || continue
    if [ -n "$DATE_PATTERN" ]; then
      grep -E "\"ts\":\"(${DATE_PATTERN})" "$log_file" 2>/dev/null
    else
      cat "$log_file"
    fi
  done
  exit 0
fi

# ─────────────────────────────────────────────────────────
# 출력 2: 집계 표 (hook × event × count)
# ─────────────────────────────────────────────────────────
echo "# Hook Telemetry — date_filter='${DATE_FILTER:-N/A}' days_filter='${DAYS_FILTER:-N/A}' hook_filter='${HOOK_FILTER:-all}'"
echo ""
printf "%-30s %-25s %10s\n" "HOOK" "EVENT" "COUNT"
printf "%-30s %-25s %10s\n" "------------------------------" "-------------------------" "----------"

TOTAL=0
declare -A COUNTS

for log_file in "${LOG_FILES[@]}"; do
  [ -f "$log_file" ] || continue
  local_hook=$(basename "$log_file" .log)

  # 날짜 필터 + event 추출
  while IFS= read -r line; do
    # event 필드 추출 (jq 없는 fallback)
    event=$(echo "$line" | grep -oE '"event":"[^"]*"' | head -1 | sed 's/"event":"\(.*\)"/\1/')
    [ -z "$event" ] && event="unknown"
    key="${local_hook}|${event}"
    COUNTS[$key]=$((${COUNTS[$key]:-0} + 1))
    TOTAL=$((TOTAL + 1))
  done < <(
    if [ -n "$DATE_PATTERN" ]; then
      grep -E "\"ts\":\"(${DATE_PATTERN})" "$log_file" 2>/dev/null
    else
      cat "$log_file"
    fi
  )
done

# 결과 출력 — hook 별로 sort
for key in $(echo "${!COUNTS[@]}" | tr ' ' '\n' | sort); do
  local_hook="${key%|*}"
  event="${key#*|}"
  count="${COUNTS[$key]}"
  printf "%-30s %-25s %10d\n" "$local_hook" "$event" "$count"
done

echo ""
echo "TOTAL events: $TOTAL"
