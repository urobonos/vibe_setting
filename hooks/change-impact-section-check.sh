#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse:Edit|Write Hook — 변경 영향 기록 섹션 검증 (G2)
#
# 대상:
#   ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-{analyze|plan|result}.md
#
# 검증:
#   1. 헤더 "## .*변경 영향" 또는 "## .*Change Impact" 존재
#   2. 헤더 직후 3열 표(변경/개선/이유) 또는 (Change/Improvement/Why) 헤더 존재
#   3. 표 데이터 행 ≥ 1
#
# 예외:
#   - 본문에 "제안 추가: 없음" 명시 → 통과 (사용자 지시 그대로 반영 케이스)
#   - summary.md, history.md → 검증 비활성
#   - tasks/ 외 경로 → 검증 비활성
#
# 정책: exit 0 + stderr 경고 (PostToolUse 차단 비활성, 사용자 흐름 단절 회피)

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path
FILE_PATH=$(echo "$FILE_PATH" | tr '\\' '/')

# tasks/YYYYMMDD/{작업명}/ 하위만 검증
echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || exit 0

FILE_NAME=$(basename "$FILE_PATH")

# summary.md, history.md 예외
[ "$FILE_NAME" = "summary.md" ] && exit 0
[ "$FILE_NAME" = "history.md" ] && exit 0

# analyze/plan/result 단계 산출물만 검증
echo "$FILE_NAME" | grep -qE '\-(analyze|plan|result)\.md$' || exit 0

# 파일 미존재 (Write 직후 race) 시 스킵
[ -f "$FILE_PATH" ] || exit 0

# 예외 1: "제안 추가: 없음" 명시 시 통과
if grep -qE '제안 추가:?\s*없음' "$FILE_PATH"; then
  exit 0
fi

# 검증 1: "변경 영향" 헤더
if ! grep -qE '^##\s+.*(변경 영향|Change Impact)' "$FILE_PATH"; then
  echo "[CHANGE-IMPACT] $FILE_PATH: '## ... 변경 영향' (또는 '## ... Change Impact') 섹션 누락" >&2
  echo "                CLAUDE.md §4 — analyze/plan/result 모든 단계 필수, 이유 생략 금지." >&2
  echo "                예외: 본문에 '제안 추가: 없음' 명시 시 통과." >&2
  exit 0
fi

# 검증 2: 3열 표 헤더 (변경/개선/이유 또는 Change/Improvement/Why)
HEADER_PATTERN='\|.*(변경|Change)[^|]*\|.*(개선|Improvement)[^|]*\|.*(이유|Why|Reason)[^|]*\|'
if ! grep -qE "$HEADER_PATTERN" "$FILE_PATH"; then
  echo "[CHANGE-IMPACT] $FILE_PATH: '변경 영향' 섹션은 존재하나 3열 표(변경/개선/이유) 헤더 누락" >&2
  echo "                예시: | 변경 사항 | 개선점 | 수행 이유 |" >&2
  exit 0
fi

# 검증 3: 표 데이터 행 ≥ 1
# 헤더 라인 다음에 구분선(|---|...) + 데이터 행 1건 이상 필요
DATA_ROWS=$(awk '
  /^##\s+.*(변경 영향|Change Impact)/ { in_section=1; next }
  in_section && /^##\s+/ { in_section=0 }
  in_section && /^\|.*(변경|Change).*\|.*(개선|Improvement).*\|.*(이유|Why|Reason).*\|/ { in_table=1; next }
  in_table && /^\|[\s\-:|]+\|$/ { next }
  in_table && /^\|/ { count++; next }
  in_table && !/^\|/ { in_table=0 }
  END { print count+0 }
' "$FILE_PATH")

if [ "$DATA_ROWS" -lt 1 ]; then
  echo "[CHANGE-IMPACT] $FILE_PATH: 3열 표 헤더는 존재하나 데이터 행 0개" >&2
  echo "                최소 1건 이상의 변경/개선/이유 행을 작성하세요." >&2
  exit 0
fi

exit 0
