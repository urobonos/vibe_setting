#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse:Edit|Write Hook — 체크리스트 최소 개수 검증 (G6)
#
# 대상:
#   ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-{analyze|plan|result}.md
#
# 검증:
#   - analyze.md → `- [ ]` + `- [x]` 카운트 ≥ 30
#   - plan.md    → ≥ 20
#   - result.md  → ≥ 20
#
# 예외:
#   - summary.md, history.md → 검증 비활성
#   - 단계 식별 불가 파일 → 검증 비활성
#
# 정책: exit 0 + stderr 경고 (PostToolUse 차단 비활성)
# 출처: task-docs §TD-4

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path
FILE_PATH=$(echo "$FILE_PATH" | tr '\\' '/')

# tasks/YYYYMMDD/{작업명}/ 하위만 검증
echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || exit 0

FILE_NAME=$(basename "$FILE_PATH")
[ "$FILE_NAME" = "summary.md" ] && exit 0
[ "$FILE_NAME" = "history.md" ] && exit 0

# 단계 추출 (analyze|plan|result)
STAGE=$(echo "$FILE_NAME" | grep -oE '\-(analyze|plan|result)\.md$' | sed -E 's/^-//;s/\.md$//')
[ -z "$STAGE" ] && exit 0

# 파일 미존재 시 스킵
[ -f "$FILE_PATH" ] || exit 0

# 임계 결정
case "$STAGE" in
  analyze) MIN=30 ;;
  plan)    MIN=20 ;;
  result)  MIN=20 ;;
  *)       exit 0 ;;
esac

# `- [ ]` + `- [x]` + `- [X]` 카운트
COUNT=$(grep -cE '^[[:space:]]*-[[:space:]]+\[[[:space:]xX]\]' "$FILE_PATH")
COUNT=${COUNT:-0}

if [ "$COUNT" -lt "$MIN" ]; then
  echo "[CHECKLIST] $FILE_PATH: 체크리스트 ${COUNT}개 (필요: ${MIN}개)" >&2
  echo "            task-docs §TD-4 — analyze≥30 / plan≥20 / result≥20." >&2
  exit 0
fi

exit 0
