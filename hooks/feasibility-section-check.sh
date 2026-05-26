#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "feasibility-section-check" "enter" "pid=$$"
# PostToolUse:Edit|Write Hook — 타당성 검토 섹션 + 엄격 인용 검증 (G1)
#
# 대상:
#   ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-{analyze|plan|unified}.md
#
# 검증 정책 (false positive 회피 우선):
#   1. 산출물에 "## ... 타당성 검토" / "## ... Feasibility Review" 헤더가 *있다면*
#      → 엄격 인용 패턴 [Source: <name> §<id>] 1건 이상 강제 (사용자 의도 명확)
#   2. 헤더가 없는 경우 → 5영역 키워드 다중 매칭 (≥2건) 시 "타당성 검토 권고" heuristic
#      - 키워드 풀: 라이브러리|프레임워크|아키텍처|DB 스키마|통신 패턴|
#                   계층 구조|API 설계|엔드포인트|API 계약|인증 방식|
#                   보안 패턴|OWASP|RFC|권한 모델|SDD|SRS|IDD
#
# 엄격 인용 패턴: \[Source:[^]]+§[^]]+\]
#   예시 통과:
#     [Source: claude-code §hooks]
#     [Source: php-net §8.4-fibers]
#     [Source: rfc-7231 §4.3]
#     [Source: owasp-top10 §A01-2021]
#     [Source: ~/.claude/skills/task-docs §TD-4]
#
# 정책: exit 0 + stderr 경고 (PostToolUse 차단 비활성)
# 출처: CLAUDE.md §4 타당성 검토 5영역, task-docs

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_read_stdin
hook_parse_file_path
# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

# tasks/YYYYMMDD/{작업명}/ 하위만 검증
echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || exit 0

FILE_NAME=$(basename "$FILE_PATH")
[ "$FILE_NAME" = "summary.md" ] && exit 0
[ "$FILE_NAME" = "history.md" ] && exit 0

# analyze/plan/unified 단계만 검증 (result 는 구현 보고로 5영역 결정 시점 아님, unified 는 analyze+plan 포함)
echo "$FILE_NAME" | grep -qE '\-(analyze|plan|unified)\.md$' || exit 0

[ -f "$FILE_PATH" ] || exit 0

HAS_HEADER=0
if grep -qE '^##\s+.*(타당성 검토|Feasibility Review)' "$FILE_PATH"; then
  HAS_HEADER=1
fi

# 엄격 인용 패턴 카운트
SOURCE_COUNT=$(grep -oE '\[Source:[^]]+§[^]]+\]' "$FILE_PATH" | wc -l)
SOURCE_COUNT=${SOURCE_COUNT:-0}

if [ "$HAS_HEADER" -eq 1 ]; then
  # 헤더 존재 → 엄격 인용 1건 이상 강제
  if [ "$SOURCE_COUNT" -lt 1 ]; then
    echo "[FEASIBILITY] $FILE_PATH: '타당성 검토' 섹션은 존재하나 엄격 인용 [Source: <name> §<id>] 누락" >&2
    echo "              예시: [Source: claude-code §hooks], [Source: rfc-7231 §4.3]" >&2
    echo "              CLAUDE.md §4 — 5영역 작업 공식 문서 근거 필수." >&2
  fi
  exit 0
fi

# 헤더 없는 경우 → 5영역 키워드 다중 매칭 heuristic
KEYWORD_PATTERN='(라이브러리|프레임워크|아키텍처|DB 스키마|통신 패턴|계층 구조|API 설계|엔드포인트|API 계약|인증 방식|보안 패턴|OWASP|RFC|권한 모델|SDD|SRS|IDD)'
KEYWORD_HITS=$(grep -oE "$KEYWORD_PATTERN" "$FILE_PATH" | sort -u | wc -l)
KEYWORD_HITS=${KEYWORD_HITS:-0}

if [ "$KEYWORD_HITS" -ge 2 ]; then
  echo "[FEASIBILITY] $FILE_PATH: 5영역 키워드 ${KEYWORD_HITS}종 등장 — '## 타당성 검토' 섹션 + [Source: ...] 인용 권고" >&2
  echo "              CLAUDE.md §4 — 라이브러리/아키텍처/API/보안/설계 작업 근거 필수." >&2
fi

exit 0
