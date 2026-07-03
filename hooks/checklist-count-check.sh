#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse:Edit|Write Hook — 체크리스트 최소 개수 검증 (G6)
#
# 대상:
#   ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-{analyze|plan|result|unified}.md
#
# 검증:
#   - analyze.md → `- [ ]` + `- [x]` 카운트 ≥ 30
#   - plan.md    → ≥ 20
#   - result.md  → ≥ 20
#   - unified.md → ≥ 30 (analyze+plan+result 통합, 2026-05-12 시행 / 2026-05-13 ≥ 50→30 완화)
#
# 예외:
#   - summary.md, history.md → 검증 비활성
#   - 단계 식별 불가 파일 → 검증 비활성
#   - 역소급 면제 (생성일 < 2026-05-07) → hint 강등 (exit 0 + stderr)
#
# 정책: hard 차단 (exit 2 — PostToolUse turn 재진입 강제).
#   2026-05-11 강화 — 이전 exit 0 (경고) 수준에서는 체크리스트 0건 plan 22건 누적 발생
#   (~/.claude/docs/claude-harness/tasks/20260511/template-enforcement/2026-05-11-template-enforcement-plan.md audit 결과).
#   역소급 면제 (CLAUDE.md §4.1) — 생성일 < 2026-05-07 산출물은 hint 강등.
#
# 출처: task-docs §TD-4

# early-exit 최적화 (2026-07-03): docs/ 경로 여부를 lib source 전 bash 내장으로 판정.
#   본 hook 은 tasks/YYYYMMDD/ (전부 /docs/ 하위) 전용 → docs 무관 편집은 즉시 exit.
#   lib 2개 source + normalize fork 세금을 대부분 편집에서 회피.
STDIN_DATA=$(cat 2>/dev/null)
_fp=""
[[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && _fp="${BASH_REMATCH[1]}"
[ -z "$_fp" ] && [[ "$STDIN_DATA" =~ \"filePath\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && _fp="${BASH_REMATCH[1]}"
case "$_fp" in
  *docs*) ;;
  "") ;;          # file_path 추출 실패(드묾) → early-exit 하지 않고 lib 재파싱에 위임 (원본 견고성 보존)
  *) exit 0 ;;
esac

# docs 포함/미상 (드문 경로) → lib source + telemetry + 정밀 판정
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "checklist-count-check" "enter" "pid=$$"
source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
# 추출 성공분은 재사용, 실패분만 python fallback 포함 lib 로 재파싱
[ -n "$_fp" ] && FILE_PATH="$_fp" || hook_parse_file_path
# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

# tasks/YYYYMMDD/{작업명}/ 하위만 검증
echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || exit 0

FILE_NAME=$(basename "$FILE_PATH")
[ "$FILE_NAME" = "summary.md" ] && exit 0
[ "$FILE_NAME" = "history.md" ] && exit 0

# 단계 추출 (analyze|plan|result|unified)
STAGE=$(echo "$FILE_NAME" | grep -oE '\-(analyze|plan|result|unified)\.md$' | sed -E 's/^-//;s/\.md$//')
[ -z "$STAGE" ] && exit 0

# 파일 미존재 시 스킵
[ -f "$FILE_PATH" ] || exit 0

# 윈도우 경로 → unix 경로 변환
unix_path=$(echo "$FILE_PATH" | sed 's|\\|/|g' | sed 's|^C:|/c|')
[ -f "$unix_path" ] || unix_path="$FILE_PATH"

# 임계 결정
case "$STAGE" in
  analyze) MIN=30 ;;
  plan)    MIN=20 ;;
  result)  MIN=20 ;;
  unified) MIN=30 ;;  # 단일 통합 — P 단계별 working 자연 분량 정합 (2026-05-12 완화, 기존 50)
  *)       exit 0 ;;
esac

# `- [ ]` + `- [x]` + `- [X]` 카운트
COUNT=$(grep -cE '^[[:space:]]*-[[:space:]]+\[[[:space:]xX]\]' "$unix_path")
COUNT=${COUNT:-0}

[ "$COUNT" -ge "$MIN" ] && exit 0

# 역소급 면제 (CLAUDE.md §"역소급 면제 2026-05-06 시행" 정합)
# 생성일 < 2026-05-07 산출물은 hint 강등 (hook 강화 도입 이전 작성분 보호)
# 날짜 결정 우선순위: frontmatter `생성일:` → 파일명 prefix → 폴더 `YYYYMMDD`
created_date=""
if grep -qE "^---" "$unix_path"; then
    created_date=$(awk '/^---/{c++; next} c==1 && /^생성일:/ {sub(/^생성일:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$unix_path")
fi
if [ -z "$created_date" ]; then
    created_date=$(echo "$FILE_NAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
fi
if [ -z "$created_date" ]; then
    folder_date=$(echo "$FILE_PATH" | grep -oE '/tasks/[0-9]{8}/' | grep -oE '[0-9]{8}' | head -1)
    if [ -n "$folder_date" ]; then
        created_date="${folder_date:0:4}-${folder_date:4:2}-${folder_date:6:2}"
    fi
fi
TEMPLATE_STRICT_FROM="2026-05-07"
if [ -n "$created_date" ] && [ "$created_date" \< "$TEMPLATE_STRICT_FROM" ]; then
    echo "[CHECKLIST hint — 역소급 면제 ${created_date}] $FILE_PATH: 체크리스트 ${COUNT}개 (필요: ${MIN}개)" >&2
    echo "                  task-docs §TD-4 — analyze≥30 / plan≥20 / result≥20." >&2
    exit 0
fi

echo "[BLOCKED] $FILE_PATH: 체크리스트 ${COUNT}개 부족 (필요: ${MIN}개)" >&2
echo "          task-docs §TD-4 — analyze≥30 / plan≥20 / result≥20 / unified≥30." >&2
echo "          references/{analyze,plan,result,unified}-template.md SSOT 골격 prepend 후 보강하세요." >&2
command -v log_event >/dev/null 2>&1 && log_event "checklist-count-check" "block" "reason=checklist-short"
exit 2
