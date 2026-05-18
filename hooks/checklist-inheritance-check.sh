#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse:Edit|Write Hook — 이전 단계 체크리스트 소거 검증 (G4)
#
# 대상:
#   ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-{plan|result}.md
#
# 동작:
#   1. plan → 이전 = 같은 폴더의 *-analyze.md
#      result → 이전 = 같은 폴더의 *-plan.md
#   2. 이전 산출물의 미체크 항목 (`- [ ]`) 텍스트 추출
#   3. 후속 산출물 본문에 해당 텍스트 (첫 30자) substring 매칭 비율 계산
#   4. 매칭 비율 < 50% → 경고
#
# 예외:
#   - 이전 산출물 부재 → 검증 비활성
#   - 이전 미체크 항목 0건 → 검증 비활성 (표 위주 산출물)
#
# 정책: exit 0 + stderr 경고 (PostToolUse 차단 비활성)
# 출처: task-docs §TD-5

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_read_stdin
hook_parse_file_path
# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || exit 0

FILE_NAME=$(basename "$FILE_PATH")
[ "$FILE_NAME" = "summary.md" ] && exit 0
[ "$FILE_NAME" = "history.md" ] && exit 0

STAGE=$(echo "$FILE_NAME" | grep -oE '\-(plan|result)\.md$' | sed -E 's/^-//;s/\.md$//')
[ -z "$STAGE" ] && exit 0

[ -f "$FILE_PATH" ] || exit 0

WORK_DIR=$(dirname "$FILE_PATH")

case "$STAGE" in
  plan)   PREV_PATTERN='*-analyze.md' ;;
  result) PREV_PATTERN='*-plan.md' ;;
esac

# 이전 파일 검출 (동일 작업 폴더 내)
PREV_FILE=""
for f in "$WORK_DIR"/$PREV_PATTERN; do
  [ -f "$f" ] && PREV_FILE="$f" && break
done

[ -z "$PREV_FILE" ] && exit 0

# 이전 미체크 항목 텍스트 추출 (마크다운 prefix 제거)
PREV_ITEMS=$(grep -E '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$PREV_FILE" | sed -E 's/^[[:space:]]*-[[:space:]]+\[[[:space:]]\][[:space:]]*//')

[ -z "$PREV_ITEMS" ] && exit 0

TOTAL=0
MATCHED=0
MISSING_ITEMS=()

while IFS= read -r item; do
  [ -z "$item" ] && continue
  TOTAL=$((TOTAL + 1))
  # 첫 30자 prefix (literal substring 검색용)
  prefix=$(echo "$item" | cut -c1-30)
  if grep -qF -- "$prefix" "$FILE_PATH"; then
    MATCHED=$((MATCHED + 1))
  else
    [ ${#MISSING_ITEMS[@]} -lt 3 ] && MISSING_ITEMS+=("$item")
  fi
done <<< "$PREV_ITEMS"

[ "$TOTAL" -eq 0 ] && exit 0

PCT=$((MATCHED * 100 / TOTAL))

if [ "$PCT" -lt 50 ]; then
  echo "[CHECKLIST-INHERIT] $FILE_PATH: 이전 단계 미체크 항목 $TOTAL건 중 ${MATCHED}건만 본문에 언급 (${PCT}%)" >&2
  echo "                    이전 산출물: $PREV_FILE" >&2
  echo "                    누락 예시 (최대 3건):" >&2
  for item in "${MISSING_ITEMS[@]}"; do
    truncated=$(echo "$item" | cut -c1-60)
    echo "                      • $truncated" >&2
  done
  echo "                    task-docs §TD-5 — Team 2/3 산출물은 이전 체크 항목 검증 후 잔여 이슈 명시." >&2
fi

exit 0
