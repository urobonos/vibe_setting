#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "doc-template-guard" "enter" "pid=$$"
# doc-template-guard.sh
# PostToolUse hook: 문서 파일이 표준 양식을 따르는지 검증

input=$(cat)

# 파일 경로 추출 (PostToolUse: tool_response.filePath 우선, fallback tool_input.file_path)
file_path=$(echo "$input" | python3 -c "
import sys, json
data = json.load(sys.stdin)
fp = data.get('tool_response', {}).get('filePath', '') if isinstance(data.get('tool_response'), dict) else ''
if not fp:
    fp = data.get('tool_input', {}).get('file_path', '')
print(fp)
" 2>/dev/null)

# .md 파일만 검증
[[ "$file_path" != *.md ]] && exit 0

basename=$(basename "$file_path")

# 제외 대상: 시스템/설정/요약 파일
case "$basename" in
    summary.md|history.md|MEMORY.md|CLAUDE.md|README.md|SKILL.md|CHANGELOG.md)
        exit 0
        ;;
esac

# 제외 대상: memory, templates, skills, api-docs yaml 관련
case "$file_path" in
    */memory/*|*/templates/*|*/skills/*|*/.claude/hooks/*|*/.claude/commands/*|*/.claude/settings*.json|*/.claude/CLAUDE.md|*/.claude/keybindings.json)
        exit 0
        ;;
esac

# 제외 대상: docs/working/ — 진행 중 단일 통합 문서 (자유 양식 허용, 이동 후 tasks/ 에서 unified 양식 검증)
# CLAUDE.md §File Paths "working/ 단일 통합 문서" 룰 정합 (2026-05-12 시행)
case "$file_path" in
    */docs/working/*)
        exit 0
        ;;
esac

# docs/ 또는 docs 관련 경로의 문서만 검증 (글로벌 ~/.claude/docs/{product}/ 및 구 프로젝트 로컬 호환)
case "$file_path" in
    */docs/tasks/*|*/docs/output/*|*/docs/specs/*|*/docs/*/tasks/*|*/docs/*/output/*|*/docs/*/specs/*)
        ;; # 검증 대상
    *)
        exit 0 # 그 외는 스킵
        ;;
esac

# 윈도우 경로 → unix 경로 변환
unix_path=$(echo "$file_path" | sed 's|\\|/|g' | sed 's|^C:|/c|')

# 파일 존재 확인
if [[ ! -f "$unix_path" ]]; then
    # 원본 경로로 재시도
    [[ ! -f "$file_path" ]] && exit 0
    unix_path="$file_path"
fi

# output/ 하위는 Gate-0 직행 정책에 따라 항상 exit 0 (단순 분석 리포트 차단 면제)
case "$file_path" in
    */docs/output/*|*/docs/*/output/*)
        IS_OUTPUT=1
        ;;
    *)
        IS_OUTPUT=0
        ;;
esac

# 필수 섹션 검증
missing=()             # hint 수준 (exit 0 + additionalContext)
blocking_missing=()    # 차단 수준 (exit 2)

grep -q "^# " "$unix_path" || missing+=("제목(# heading)")
grep -q "^>" "$unix_path" || missing+=("간단 요약(> blockquote)")
grep -q "## 작성 정보" "$unix_path" || missing+=("## 작성 정보")
grep -qE "## (내용|분석|계획|실행|결과|분석 결과|실행 계획|실행 결과)" "$unix_path" || missing+=("## 내용 (본문 섹션)")
grep -q "## 체크리스트" "$unix_path" || missing+=("## 체크리스트")
grep -q "## 변경 기록" "$unix_path" || missing+=("## 변경 기록")

# CLAUDE.md §4 Guardrails 필수 항목 — 문서 유형별 섹션 검증
# output/ 면제: 단순 분석 리포트는 doc-quality 면제 정책과 정합
lower_base=$(echo "$basename" | tr '[:upper:]' '[:lower:]')
if [[ "$IS_OUTPUT" == "0" ]]; then
    case "$lower_base" in
        *-unified.md|*_unified.md)
            # 단일 통합 문서 (2026-05-12 시행) — analyze + plan + result 필수 섹션 합집합 검증
            # SSOT: CLAUDE.md §File Paths "working/ 단일 통합 문서" + skills/task-docs/references/unified-template.md
            # working/ → tasks/ 이동 후 검증 (working/ 경로 자체는 위 case 에서 면제)
            # === analyze 필수 ===
            grep -qE "^##[[:space:]]+.*(타당성 검토|Feasibility Review)" "$unix_path" \
                || blocking_missing+=("타당성 검토 (§4 필수, unified §분석)")
            grep -qE "^##[[:space:]]+.*(변경 영향|Change Impact)" "$unix_path" \
                || blocking_missing+=("변경 영향 기록 (§4 필수, unified)")
            grep -qE "^##[[:space:]]+.*(분석 관점별|관점별 요약|Perspective Summary)" "$unix_path" \
                || blocking_missing+=("분석 관점별 요약 (unified §분석)")
            grep -qE "^##[[:space:]]+.*Critical[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("Critical 이슈 분류 (unified §분석)")
            grep -qE "^##[[:space:]]+.*High[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("High 이슈 분류 (unified §분석)")
            grep -qE "^##[[:space:]]+.*Medium[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("Medium 이슈 분류 (unified §분석)")
            grep -qE "^##[[:space:]]+.*Low[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("Low 이슈 분류 (unified §분석)")
            grep -qE "^##[[:space:]]+.*우선순위[[:space:]]*권고" "$unix_path" \
                || blocking_missing+=("우선순위 권고 (unified §분석)")
            grep -qE "^##[[:space:]]+.*(장기 영향|Long-term Impact)" "$unix_path" \
                || blocking_missing+=("장기 영향 (CLAUDE.md §4.1 강제, unified)")
            grep -qE "^##[[:space:]]+.*(재발 방지|Regression Prevention)" "$unix_path" \
                || blocking_missing+=("재발 방지 (CLAUDE.md §4.1 강제, unified)")
            grep -qE "^##[[:space:]]+.*(SSOT 일관성|SSOT Consistency)" "$unix_path" \
                || blocking_missing+=("SSOT 일관성 (CLAUDE.md §4.1 강제, unified)")
            # === plan 필수 ===
            grep -qE "(^##[[:space:]]+.*작업 등급|작업 등급[[:space:]]*[::])" "$unix_path" \
                || blocking_missing+=("작업 등급 S/M/L (unified §계획)")
            grep -qE "^##[[:space:]]+.*Blueprint" "$unix_path" \
                || blocking_missing+=("Blueprint (unified §계획)")
            grep -qE "^##[[:space:]]+.*수정 대상" "$unix_path" \
                || blocking_missing+=("수정 대상 (unified §계획)")
            grep -qE "^##[[:space:]]+.*실행 계획" "$unix_path" \
                || blocking_missing+=("실행 계획 (unified §계획)")
            grep -qE "^##[[:space:]]+.*(작업 분해|WBS|Work Breakdown)" "$unix_path" \
                || blocking_missing+=("작업 분해 WBS (unified §계획)")
            # === result 필수 ===
            grep -qE "^##[[:space:]]+.*실행 요약" "$unix_path" \
                || blocking_missing+=("실행 요약 (unified §실행)")
            grep -qE "^##[[:space:]]+.*Self-Critique" "$unix_path" \
                || blocking_missing+=("Self-Critique 체크리스트 (unified §실행)")
            grep -qE "^##[[:space:]]+.*테스트 결과" "$unix_path" \
                || blocking_missing+=("테스트 결과 (unified §실행)")
            grep -qE "^##[[:space:]]+.*잔여 이슈" "$unix_path" \
                || blocking_missing+=("잔여 이슈 (unified §실행)")
            grep -qE "Status[[:space:]]*[::][[:space:]]*(Done|Partial)" "$unix_path" \
                || blocking_missing+=("Status: Done/Partial (unified §실행)")
            # hint: Before/After + 롤백
            grep -qE "^##[[:space:]]+.*(Before.?/.?After|최초 실행안|최초안|제안.?반영)" "$unix_path" \
                || missing+=("## Before/After 대조 (§4 필수, unified §실행)")
            grep -qE "^##[[:space:]]+.*(롤백|Rollback)" "$unix_path" \
                || missing+=("## 롤백 (§4 필수, unified §실행)")
            # /타당성·/검증·/리뷰·/회고 선택 진입 — hint 수준 (2026-05-15 신설 8 슬래시 정합)
            # 선택 섹션이므로 blocking 아님, 진입 시 권장
            grep -qE "^#[[:space:]]+§[[:space:]]*타당성 검토" "$unix_path" \
                || missing+=("# § 타당성 검토 (선택, /타당성 진입 시)")
            grep -qE "^#[[:space:]]+§[[:space:]]*검증" "$unix_path" \
                || missing+=("# § 검증 (선택, /검증 진입 시)")
            grep -qE "^#[[:space:]]+§[[:space:]]*리뷰" "$unix_path" \
                || missing+=("# § 리뷰 (선택, /리뷰 진입 시)")
            grep -qE "^#[[:space:]]+§[[:space:]]*회고" "$unix_path" \
                || missing+=("# § 회고 (선택, /회고 진입 시)")
            # hongcafe_global_backend 한정 — 참조 문서 검토 결과
            if echo "$file_path" | grep -q "/hongcafe_global_backend/"; then
                grep -qE "^##[[:space:]]+.*(참조 문서 검토 결과|Reference Doc Review)" "$unix_path" \
                    || blocking_missing+=("참조 문서 검토 결과 (be 한정, unified §분석)")
            fi
            ;;
        *analyze*.md)
            # 차단: 타당성 검토 + 변경 영향 기록 + 분석 관점별 요약 + Critical/High/Medium/Low 4분류 + 우선순위 권고 + 장기영향 + 재발방지 + SSOT 일관성
            # references/analyze-template.md SSOT (2026-05-07 강화 — 사용자 지시 "훅으로 템플릿 출력 할때 강제")
            grep -qE "^##[[:space:]]+.*(타당성 검토|Feasibility Review)" "$unix_path" \
                || blocking_missing+=("타당성 검토 (§4 필수)")
            grep -qE "^##[[:space:]]+.*(변경 영향|Change Impact)" "$unix_path" \
                || blocking_missing+=("변경 영향 기록 (§4 필수)")
            grep -qE "^##[[:space:]]+.*(분석 관점별|관점별 요약|Perspective Summary)" "$unix_path" \
                || blocking_missing+=("분석 관점별 요약 (analyze 템플릿 §관점별 요약)")
            grep -qE "^##[[:space:]]+.*Critical[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("Critical 이슈 분류 (analyze 템플릿 §1)")
            grep -qE "^##[[:space:]]+.*High[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("High 이슈 분류 (analyze 템플릿 §2)")
            grep -qE "^##[[:space:]]+.*Medium[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("Medium 이슈 분류 (analyze 템플릿 §3)")
            grep -qE "^##[[:space:]]+.*Low[[:space:]]*이슈" "$unix_path" \
                || blocking_missing+=("Low 이슈 분류 (analyze 템플릿 §4)")
            grep -qE "^##[[:space:]]+.*우선순위[[:space:]]*권고" "$unix_path" \
                || blocking_missing+=("우선순위 권고 (analyze 템플릿 §9)")
            grep -qE "^##[[:space:]]+.*(장기 영향|Long-term Impact)" "$unix_path" \
                || blocking_missing+=("장기 영향 (CLAUDE.md §4.1 강제)")
            grep -qE "^##[[:space:]]+.*(재발 방지|Regression Prevention)" "$unix_path" \
                || blocking_missing+=("재발 방지 (CLAUDE.md §4.1 강제)")
            grep -qE "^##[[:space:]]+.*(SSOT 일관성|SSOT Consistency)" "$unix_path" \
                || blocking_missing+=("SSOT 일관성 (CLAUDE.md §4.1 강제)")
            # hongcafe_global_backend product 한정 — 참조 문서 검토 결과 섹션 강제
            # SSOT: 프로젝트 CLAUDE.md §"분석·계획 시 참조 강제 룰" (6항목 매트릭스)
            if echo "$file_path" | grep -q "/hongcafe_global_backend/"; then
                grep -qE "^##[[:space:]]+.*(참조 문서 검토 결과|Reference Doc Review)" "$unix_path" \
                    || blocking_missing+=("참조 문서 검토 결과 (hongcafe_global_backend CLAUDE.md §\"분석·계획 시 참조 강제 룰\" 6항목)")
            fi
            ;;
        *plan*.md)
            # 차단: 타당성 검토 + 변경 영향 기록 + 작업 등급 + Blueprint + WBS + 장기영향 + 재발방지 + SSOT 일관성 + Status
            grep -qE "^##[[:space:]]+.*(타당성 검토|Feasibility Review)" "$unix_path" \
                || blocking_missing+=("타당성 검토 (§4 필수)")
            grep -qE "^##[[:space:]]+.*(변경 영향|Change Impact)" "$unix_path" \
                || blocking_missing+=("변경 영향 기록 (§4 필수)")
            grep -qE "(^##[[:space:]]+.*작업 등급|작업 등급[[:space:]]*[::])" "$unix_path" \
                || blocking_missing+=("작업 등급 S/M/L (plan 템플릿)")
            grep -qE "^##[[:space:]]+.*Blueprint" "$unix_path" \
                || blocking_missing+=("Blueprint (plan 템플릿)")
            grep -qE "^##[[:space:]]+.*수정 대상" "$unix_path" \
                || blocking_missing+=("수정 대상 (plan 템플릿 §수정 대상)")
            grep -qE "^##[[:space:]]+.*실행 계획" "$unix_path" \
                || blocking_missing+=("실행 계획 (plan 템플릿 §실행 계획)")
            grep -qE "^##[[:space:]]+.*(작업 분해|WBS|Work Breakdown)" "$unix_path" \
                || blocking_missing+=("작업 분해 WBS (plan 템플릿)")
            grep -qE "^##[[:space:]]+.*(장기 영향|Long-term Impact)" "$unix_path" \
                || blocking_missing+=("장기 영향 (CLAUDE.md §4.1 강제)")
            grep -qE "^##[[:space:]]+.*(재발 방지|Regression Prevention)" "$unix_path" \
                || blocking_missing+=("재발 방지 (CLAUDE.md §4.1 강제)")
            grep -qE "^##[[:space:]]+.*(SSOT 일관성|SSOT Consistency)" "$unix_path" \
                || blocking_missing+=("SSOT 일관성 (CLAUDE.md §4.1 강제)")
            grep -qE "Status[[:space:]]*[::][[:space:]]*Plan Complete" "$unix_path" \
                || blocking_missing+=("Status: Plan Complete (plan 템플릿)")
            # hongcafe_global_backend product 한정 — 참조 문서 검토 결과 섹션 강제
            # SSOT: 프로젝트 CLAUDE.md §"분석·계획 시 참조 강제 룰" (6항목 매트릭스)
            if echo "$file_path" | grep -q "/hongcafe_global_backend/"; then
                grep -qE "^##[[:space:]]+.*(참조 문서 검토 결과|Reference Doc Review)" "$unix_path" \
                    || blocking_missing+=("참조 문서 검토 결과 (hongcafe_global_backend CLAUDE.md §\"분석·계획 시 참조 강제 룰\" 6항목)")
            fi
            ;;
        *result*.md)
            # 차단: 변경 영향 기록 + 실행 요약 + Self-Critique + 테스트 결과 + 잔여 이슈 + Status
            grep -qE "^##[[:space:]]+.*(변경 영향|Change Impact)" "$unix_path" \
                || blocking_missing+=("변경 영향 기록 (§4 필수)")
            grep -qE "^##[[:space:]]+.*실행 요약" "$unix_path" \
                || blocking_missing+=("실행 요약 (result 템플릿)")
            grep -qE "^##[[:space:]]+.*Self-Critique" "$unix_path" \
                || blocking_missing+=("Self-Critique 체크리스트 (result 템플릿)")
            grep -qE "^##[[:space:]]+.*테스트 결과" "$unix_path" \
                || blocking_missing+=("테스트 결과 (result 템플릿)")
            grep -qE "^##[[:space:]]+.*잔여 이슈" "$unix_path" \
                || blocking_missing+=("잔여 이슈 (result 템플릿)")
            grep -qE "Status[[:space:]]*[::][[:space:]]*(Done|Partial)" "$unix_path" \
                || blocking_missing+=("Status: Done/Partial (result 템플릿)")
            # hint: Before/After, 롤백은 hint 수준 유지
            grep -qE "^##[[:space:]]+.*(Before.?/.?After|최초 실행안|최초안|제안.?반영)" "$unix_path" \
                || missing+=("## Before/After 대조 (§4 필수)")
            grep -qE "^##[[:space:]]+.*(롤백|Rollback)" "$unix_path" \
                || missing+=("## 롤백 (§4 필수)")
            ;;
    esac

    # specs 문서(SDP/SRS/SDD/IDD/STP/STD)는 타당성 검토 누락 시 차단
    case "$file_path" in
        */docs/specs/*|*/docs/*/specs/*)
            grep -qE "^##[[:space:]]+.*(타당성 검토|Feasibility Review)" "$unix_path" \
                || blocking_missing+=("타당성 검토 (§4 필수)")
            ;;
    esac

    # 개발언어/기술스택 필드 (2026-06-01 신설) — 작성 정보 박스 보유 문서 한정 (specs IEEE 제외)
    # SSOT: unified-template.md / doc-template.md 작성 정보 표 + CLAUDE.md §File Paths "개발언어·기술스택 메타"
    # 차단/hint 판정은 created_date 산정 후(아래 역소급 게이트) 수행
    MISSING_TECHSTACK=0
    case "$file_path" in
        */docs/specs/*|*/docs/*/specs/*) ;; # IEEE specs 제외
        *)
            if grep -q "## 작성 정보" "$unix_path" \
                && ! grep -qE '(^\|[[:space:]]*개발언어|^개발언어[[:space:]]*:)' "$unix_path"; then
                MISSING_TECHSTACK=1
            fi
            ;;
    esac
fi

# 역소급 면제 (CLAUDE.md §"역소급 면제 2026-05-06 시행" 정합)
# 생성일 < 2026-05-07 산출물은 차단 항목을 hint 로 강등 (강화 hook 도입 이전 작성분 보호)
# Why: hook 강화로 인해 기존 산출물 수정 시 흐름 차단되면 회귀 위험. 신규 산출물부터 강제.
#
# 날짜 결정 우선순위 (가장 신뢰도 높은 순):
#  1) frontmatter `생성일: YYYY-MM-DD`
#  2) 파일명 prefix `YYYY-MM-DD-...`
#  3) 폴더 경로 `tasks/YYYYMMDD/...`
created_date=""
if grep -qE "^---" "$unix_path"; then
    created_date=$(awk '/^---/{c++; next} c==1 && /^생성일:/ {sub(/^생성일:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$unix_path")
fi
if [[ -z "$created_date" ]]; then
    created_date=$(echo "$basename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
fi
if [[ -z "$created_date" ]]; then
    folder_date=$(echo "$file_path" | grep -oE '/tasks/[0-9]{8}/' | grep -oE '[0-9]{8}' | head -1)
    if [[ -n "$folder_date" ]]; then
        created_date="${folder_date:0:4}-${folder_date:4:2}-${folder_date:6:2}"
    fi
fi
TEMPLATE_STRICT_FROM="2026-05-07"
if [[ -n "$created_date" && "$created_date" < "$TEMPLATE_STRICT_FROM" ]]; then
    if [[ ${#blocking_missing[@]} -gt 0 ]]; then
        missing+=("[역소급 면제 — 생성일 ${created_date}] ${blocking_missing[*]}")
        blocking_missing=()
    fi
fi

# 개발언어/기술스택 역소급 게이트 (2026-06-01 신설, 독립 임계 — 위 2026-05-07 강등과 별개)
# 생성일 미상(빈 값) = 신규로 간주해 차단. 생성일 < 2026-06-01 = hint 강등(역소급 면제).
TECHSTACK_STRICT_FROM="2026-06-01"
if [[ "${MISSING_TECHSTACK:-0}" == "1" ]]; then
    if [[ -n "$created_date" && "$created_date" < "$TECHSTACK_STRICT_FROM" ]]; then
        missing+=("[역소급 면제 — 생성일 ${created_date}] 개발언어/기술스택 (작성 정보 행)")
    else
        blocking_missing+=("개발언어/기술스택 (작성 정보 필수 행, 2026-06-01~)")
    fi
fi

# 차단 항목 우선 처리 (exit 2 — PostToolUse turn 재진입 강제)
if [[ ${#blocking_missing[@]} -gt 0 ]]; then
    blocking_str=$(IFS=", "; echo "${blocking_missing[*]}")
    command -v log_event >/dev/null 2>&1 && log_event "doc-template-guard" "block" "missing=${blocking_str}"
    echo "[BLOCKED] ${blocking_str} 섹션 누락 — ${file_path} 보완 후 재작성하세요." >&2
    exit 2
fi

# hint 수준 누락 (additionalContext 주입, exit 0)
if [[ ${#missing[@]} -gt 0 ]]; then
    missing_str=$(IFS=", "; echo "${missing[*]}")
    cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[doc-template-guard] 문서 양식 불일치 — 누락: ${missing_str}. ~/.claude/templates/doc-template.md 양식 + CLAUDE.md §4 필수 섹션에 따라 즉시 수정하세요."}}
HOOK_JSON
    exit 0
fi

exit 0
