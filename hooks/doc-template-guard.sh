#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
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
        *analyze*.md|*plan*.md)
            # 차단: 타당성 검토 + 변경 영향 기록 누락 시 exit 2
            grep -qE "^#{1,3}[[:space:]]+.*(타당성 검토|Feasibility Review)" "$unix_path" \
                || blocking_missing+=("타당성 검토 (§4 필수)")
            grep -qE "^#{1,3}[[:space:]]+.*(변경 영향|Change Impact)" "$unix_path" \
                || blocking_missing+=("변경 영향 기록 (§4 필수)")
            ;;
        *result*.md)
            # 차단: result 는 변경 영향 기록 누락만 차단 (타당성 검토는 result 필수 아님)
            grep -qE "^#{1,3}[[:space:]]+.*(변경 영향|Change Impact)" "$unix_path" \
                || blocking_missing+=("변경 영향 기록 (§4 필수)")
            # hint: Before/After, 롤백은 기존 hint 수준 유지
            grep -qE "^#{1,3}[[:space:]]+.*(Before.?/.?After|최초 실행안|최초안|제안.?반영)" "$unix_path" \
                || missing+=("## Before/After 대조 (§4 필수)")
            grep -qE "^#{1,3}[[:space:]]+.*(롤백|Rollback)" "$unix_path" \
                || missing+=("## 롤백 (§4 필수)")
            ;;
    esac

    # specs 문서(SDP/SRS/SDD/IDD/STP/STD)는 타당성 검토 누락 시 차단
    case "$file_path" in
        */docs/specs/*|*/docs/*/specs/*)
            grep -qE "^#{1,3}[[:space:]]+.*(타당성 검토|Feasibility Review)" "$unix_path" \
                || blocking_missing+=("타당성 검토 (§4 필수)")
            ;;
    esac
fi

# 차단 항목 우선 처리 (exit 2 — PostToolUse turn 재진입 강제)
if [[ ${#blocking_missing[@]} -gt 0 ]]; then
    blocking_str=$(IFS=", "; echo "${blocking_missing[*]}")
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
