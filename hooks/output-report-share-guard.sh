#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "output-report-share-guard" "enter" "pid=$$"
# PreToolUse:Edit|Write|MultiEdit Hook — 공유용 단일 통합 문서 양식 강제 (2026-05-12 신설)
#
# 대상 경로:
#   - ~/.claude/docs/{product}/output/report/.../{filename}-(share|proposal|sharing)*.md
#
# 강제 규칙:
#   - 단일 통합 SSOT — 필수 12 섹션 모두 포함
#   - 외부 공유 시 1 파일만으로 자족적 이해 가능해야 함
#
# 필수 12 섹션 (## 헤더 패턴 정규식):
#   1. ## .*한 줄 요약            (Executive Summary)
#   2. ## .*(왜|배경|문제|도입 효과) (배경 / 도입 가치)
#   3. ## .*무엇                  (BC / 폴더 / 클래스)
#   4. ## .*어떻게                (아키텍처 / 시퀀스)
#   5. ## .*사용 시나리오          (활용 예시)
#   6. ## .*인터페이스             (코드 시그니처 / API)
#   7. ## .*데이터                (DB 스키마 / 페이로드)
#   8. ## .*(보안|성능|비용)       (비기능)
#   9. ## .*일정                  (Phase / 의존)
#  10. ## .*(결정|권고|리스크)     (의사결정)
#  11. ## .*(성공 지표|향후 확장)  (검증 / 미래)
#  12. ## .*(합의|참조)            (마무리)
#
# 누락 시 exit 2 차단.
#
# 근거: ~/.claude/CLAUDE.md §File Paths "공유용 단일 통합 문서" 룰

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_read_stdin
hook_parse_file_path
# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

# 대상 경로 매칭 — output/report/ 안 share/proposal/sharing 패턴 파일만
echo "$FILE_PATH" | grep -qE '/docs/[^/]+/output/report/.+(share|proposal|sharing)[^/]*\.md$' || exit 0

# Write content / Edit new_string 가져오기 (lib/hook-input.sh 정합)
CONTENT="${TOOL_INPUT_CONTENT:-}"
if [ -z "$CONTENT" ]; then
  CONTENT="${TOOL_INPUT_NEW_STRING:-}"
fi

# 본문 비어 있으면 (file_path 만 입력) skip
[ -z "$CONTENT" ] && exit 0

# 작성 정보 박스 검증 — 7개 메타 (`>` 블록 또는 `## 작성 정보` 표 형식 호환, 개발언어/기술스택 포함 2026-06-01~)
META_PATTERNS=(
  '(^>[[:space:]]*\*\*문서 ID\*\*|^\|[[:space:]]*문서 ID[[:space:]]*\|)'
  '(^>[[:space:]]*\*\*버전\*\*|^\|[[:space:]]*버전[[:space:]]*\|)'
  '(^>[[:space:]]*\*\*상태\*\*|^\|[[:space:]]*상태[[:space:]]*\|)'
  '(^>[[:space:]]*\*\*작성자\*\*|^\|[[:space:]]*작성자[[:space:]]*\|)'
  '(^>[[:space:]]*\*\*작성일\*\*|^\|[[:space:]]*작성일[[:space:]]*\|)'
  '(^>[[:space:]]*\*\*대상 독자\*\*|^\|[[:space:]]*대상 독자[[:space:]]*\|)'
  '(^>[[:space:]]*\*\*개발언어[^*]*\*\*|^\|[[:space:]]*개발언어[^|]*\|)'
)
META_NAMES=(
  "문서 ID"
  "버전"
  "상태"
  "작성자"
  "작성일"
  "대상 독자"
  "개발언어/기술스택"
)
META_MISSING=()
mi=0
while [ $mi -lt ${#META_PATTERNS[@]} ]; do
  pattern="${META_PATTERNS[$mi]}"
  if ! echo "$CONTENT" | grep -qE "$pattern"; then
    META_MISSING+=("$mi")
  fi
  mi=$((mi + 1))
done

if [ ${#META_MISSING[@]} -gt 0 ]; then
  echo "[BLOCKED] 공유용 문서 작성 정보 박스 누락 — ${#META_MISSING[@]}개 메타 필드 부재" >&2
  echo "  파일: $FILE_PATH" >&2
  echo "  누락 메타:" >&2
  for idx in "${META_MISSING[@]}"; do
    echo "    - ${META_NAMES[$idx]}" >&2
  done
  echo "" >&2
  echo "  필수 작성 정보 박스 — 두 양식 중 하나 (호환):" >&2
  echo "    (A) '>' 블록 7 라인 — > **문서 ID**: ... / > **버전**: ... / > **개발언어/기술스택**: ... / ..." >&2
  echo "    (B) '## 작성 정보' 표 형식 — | 문서 ID | ... | / | 버전 | ... | / ..." >&2
  echo "  근거: ~/.claude/CLAUDE.md §File Paths '공유용 단일 통합 문서' 룰 (2026-05-12 시행)" >&2
  command -v log_event >/dev/null 2>&1 && log_event "output-report-share-guard" "block" "reason=share-info-box"
  exit 2
fi

# 필수 12 섹션 정규식
REQUIRED_SECTIONS=(
  "^##[[:space:]].*한 줄 요약"
  "^##[[:space:]].*(왜|배경|문제|도입 효과)"
  "^##[[:space:]].*무엇"
  "^##[[:space:]].*어떻게"
  "^##[[:space:]].*사용 시나리오"
  "^##[[:space:]].*인터페이스"
  "^##[[:space:]].*데이터"
  "^##[[:space:]].*(보안|성능|비용)"
  "^##[[:space:]].*일정"
  "^##[[:space:]].*(결정|권고|리스크)"
  "^##[[:space:]].*(성공 지표|향후 확장)"
  "^##[[:space:]].*(합의|참조)"
)

SECTION_NAMES=(
  "한 줄 요약 (Executive Summary)"
  "배경 / 도입 효과 (왜)"
  "무엇 (BC / 폴더 / 클래스 카탈로그)"
  "어떻게 (아키텍처 / 시퀀스)"
  "사용 시나리오"
  "인터페이스 (코드 시그니처 / API)"
  "데이터 (DB 스키마 / 페이로드)"
  "보안 · 성능 · 비용"
  "일정 (Phase / 의존)"
  "결정 · 권고 · 리스크"
  "성공 지표 / 향후 확장"
  "합의 / 참조"
)

MISSING_IDX=()
i=0
while [ $i -lt ${#REQUIRED_SECTIONS[@]} ]; do
  pattern="${REQUIRED_SECTIONS[$i]}"
  if ! echo "$CONTENT" | grep -qE "$pattern"; then
    MISSING_IDX+=("$i")
  fi
  i=$((i + 1))
done

if [ ${#MISSING_IDX[@]} -gt 0 ]; then
  echo "[BLOCKED] 공유용 단일 통합 문서 양식 위반 — 필수 12 섹션 중 ${#MISSING_IDX[@]}개 누락" >&2
  echo "  파일: $FILE_PATH" >&2
  echo "  누락 섹션:" >&2
  for idx in "${MISSING_IDX[@]}"; do
    echo "    [$((idx + 1))] ${SECTION_NAMES[$idx]}" >&2
  done
  echo "" >&2
  echo "  강제 12 섹션 (## 헤더 필수):" >&2
  echo "    1. 한 줄 요약" >&2
  echo "    2. 왜 / 배경 / 문제 / 도입 효과" >&2
  echo "    3. 무엇" >&2
  echo "    4. 어떻게" >&2
  echo "    5. 사용 시나리오" >&2
  echo "    6. 인터페이스" >&2
  echo "    7. 데이터" >&2
  echo "    8. 보안 / 성능 / 비용" >&2
  echo "    9. 일정" >&2
  echo "   10. 결정 / 권고 / 리스크" >&2
  echo "   11. 성공 지표 / 향후 확장" >&2
  echo "   12. 합의 / 참조" >&2
  echo "" >&2
  echo "  근거: ~/.claude/CLAUDE.md §File Paths '공유용 단일 통합 문서' 룰 (2026-05-12 시행)" >&2
  echo "  목적: 외부 공유 시 1 파일만으로 자족적 이해 가능 (multi-file 분산 = 의사결정 사이클 지연)" >&2
  command -v log_event >/dev/null 2>&1 && log_event "output-report-share-guard" "block" "reason=share-12section"
  exit 2
fi

exit 0
