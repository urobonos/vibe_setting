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

# 검사 대상 = **Write (전문 작성)만** (F1 2026-08-03)
#   본 게이트의 판정 단위는 "문서 전문에 7메타 + 12섹션이 있는가" 다. Edit/MultiEdit 의
#   new_string 은 문서 **조각**이라 전문 기준을 적용하면 오타 1자 수정도 "메타 7개 부재" 로
#   차단된다 (실측: 실존 share 문서 Edit → rc=2). 죽은 게이트를 살리려다 정상 편집을 막는
#   쪽으로 뒤집는 것은 더 나쁜 거래다.
#   Edit 경로까지 강제하려면 doc-unified-check.sh 처럼 **PostToolUse + 디스크 read** 로 가야
#   하는데 그건 settings.json 배선 변경이라 본 hook 단독으로 못 한다 (잔여 과제).
TOOL_NAME=$(hook_parse_field tool_name)
[ "$TOOL_NAME" = "Write" ] || exit 0
# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

# 대상 경로 매칭 — output/report/ 안 share/proposal/sharing 패턴 파일만
echo "$FILE_PATH" | grep -qE '/docs/[^/]+/output/report/.+(share|proposal|sharing)[^/]*\.md$' || exit 0

# Write content / Edit new_string 가져오기 — lib/hook-input.sh::hook_parse_content SSOT
#   2026-08-03 픽스: 구 코드는 `TOOL_INPUT_CONTENT` / `TOOL_INPUT_NEW_STRING` 환경변수를 읽었으나
#   그 이름을 채우는 주체가 hooks/ 전체에 없었다 (출현 = 이 2줄뿐) → CONTENT 항상 공백 →
#   아래 `[ -z "$CONTENT" ] && exit 0` 로 **본 게이트 164줄이 0% 발동**. stdin JSON 을 직접 판다.
hook_parse_content

# 본문 비어 있으면 (file_path 만 입력) skip
[ -z "$CONTENT" ] && exit 0

# degraded 파싱에서 디코드 불가분이 남았으면 판정하지 않고 차단 (fail-closed, F10 2026-08-03)
if [ "${CONTENT_UNDECODED:-0}" = "1" ]; then
  echo "[BLOCKED] 공유용 문서 본문을 완전히 해석하지 못했습니다 (python 미가용 + 디코드 불가 이스케이프)." >&2
  echo "  파일: $FILE_PATH" >&2
  echo "  조치: python 실행 가능 상태를 복구한 뒤 다시 시도하거나, 7메타 + 12섹션을 직접 확인하세요." >&2
  command -v log_event >/dev/null 2>&1 && log_event "output-report-share-guard" "block" "reason=undecoded-content"
  exit 2
fi

# ── 문서 생성일 산정 (역소급 면제용) — doc-unified-check.sh::resolve_created_date 와 같은 우선순위
#    (frontmatter/작성정보 박스 날짜 → 파일명 YYYY-MM-DD prefix)
DOC_DATE=$(printf '%s' "$CONTENT" | grep -oE '^(>[[:space:]]*\*\*(작성일|생성일)\*\*|\|[[:space:]]*(작성일|생성일)[[:space:]]*\||(작성일|생성일)):?[^0-9]*[0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
[ -z "$DOC_DATE" ] && DOC_DATE=$(echo "${FILE_PATH##*/}" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

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
# 역소급 면제 (F2 2026-08-03, CLAUDE.md §4 "신규/강화 강제 룰은 도입 이전 산출물에 역소급 적용 안 함")
#   "개발언어/기술스택"(index 6) 은 2026-06-01 도입 — 그 이전 생성 문서는 이 1건을 면제한다.
#   실측: 레포 실존 share 문서 4건 중 3건(05-12·05-13·05-28)이 이 필드만 없어 전량 차단됐다.
META_LAST=$(( ${#META_PATTERNS[@]} - 1 ))
if [ -n "$DOC_DATE" ] && [ "$DOC_DATE" \< "2026-06-01" ]; then
  META_LAST=$(( META_LAST - 1 ))
fi

# 패턴 N개를 **1회 스캔**으로 판정 (누락 인덱스만 stdout). 구조는 `echo "$CONTENT" | grep -qE` ×19 였는데
#   760KB 문서에서 그 파이프만 2.2초(메타 7회 842ms + 섹션 12회 ≈ 1.4초)로 hook timeout(5초)을
#   위협했다 — awk 1회 = 258ms. 패턴은 ENVIRON 으로 넘긴다 (`-v` 는 `\|` 를 escape 로 해석해
#   gawk 경고를 stderr 에 흘린다). 정규식 문법·판정 결과는 grep -E 와 동일.
_missing_indices() {
  local pats
  pats=$(printf '%s\001' "$@")
  PATS="$pats" awk '
    BEGIN { n = split(ENVIRON["PATS"], P, "\001") }
    { for (i = 1; i < n; i++) if (!seen[i] && $0 ~ P[i]) seen[i] = 1 }
    END { for (i = 1; i < n; i++) if (!seen[i]) printf "%d ", i-1 }
  ' <<< "$CONTENT"
}

META_MISSING=()
for mi in $(_missing_indices "${META_PATTERNS[@]:0:$((META_LAST + 1))}"); do
  META_MISSING+=("$mi")
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
for i in $(_missing_indices "${REQUIRED_SECTIONS[@]}"); do
  MISSING_IDX+=("$i")
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
