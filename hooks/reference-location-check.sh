#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "reference-location-check" "enter" "pid=$$"
# reference-location-check.sh
# PostToolUse:Edit|Write|MultiEdit hook — 문서 생성 시 "참조 출처(참조위치/Provenance)" 강제
#
# 정책 (2026-06-02 신설, 사용자 명시 결정):
#   문서를 생성할 때 작성 내용의 출처 위치를 무조건 기록한다.
#     - 기획서면 페이지(p.N), docs 파일이면 파일:줄 위치.
#   기존 "## 타당성 검토"([Source: §id], 공식 기술표준 근거) 와 별개의 신규 provenance 필드.
#
# 강제 규칙 (Q&A 확정 — escape valve 허용):
#   1. "## 참조 출처" / "Reference Location" / "Provenance" 섹션 헤더가 항상 존재해야 함.
#   2. [참조: ...] (또는 [Ref: ...]) 인용 패턴 ≥ 1건.
#      - 순수 원본(차용 없음) 문서는 [참조: 없음 — 신규 분석] 1행으로 충족 (작성 가능 보장).
#   누락 시 exit 2 차단 → stderr 가 형식·예시 전량 출력 (CLAUDE.md §4.4 재팽창 관습 정합).
#
# 한계 (사용자 인지): hook 은 "섹션 존재 + 인용 형식"만 검사. "모든 차용 내용에 실제로
#   출처를 달았는가"(semantic completeness)는 기계적으로 보장 불가 — 정밀 인용 의무는
#   작성자 책임, hook 은 최소 골격만 강제.
#
# 대상 경로: docs/{product}/{tasks,output,specs}/ 하위 .md (doc-template-guard 범위 정합)
# 역소급 면제: 생성일 < 2026-06-02 → 차단을 hint 로 강등 (강화 hook 도입 이전 산출물 보호)
#
# SSOT: CLAUDE.md §4.3 "참조 출처(참조위치) 필수" + 본 hook + 4 템플릿 §참조 출처

input=$(cat)

# 파일 경로 추출 (PostToolUse: tool_response.filePath 우선, fallback tool_input.file_path)
# 파일 경로 추출 — bash 내장 (python 起動 제거). tool_response.filePath 우선.
file_path=""
[[ "$input" =~ \"filePath\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && file_path="${BASH_REMATCH[1]}"
[ -z "$file_path" ] && [[ "$input" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && file_path="${BASH_REMATCH[1]}"

# .md 파일만 검증
[[ "$file_path" != *.md ]] && exit 0

basename="${file_path##*/}"

# 제외 대상: 시스템/설정/요약/인덱스 파일 (provenance 무의미 — 집계·자동생성)
case "$basename" in
    summary.md|history.md|MEMORY.md|CLAUDE.md|README.md|SKILL.md|CHANGELOG.md|changelog.md|REGISTRY.md)
        exit 0
        ;;
esac

# 제외 대상: memory / templates / skills / hooks / commands / settings / 자동생성 index
case "$file_path" in
    */memory/*|*/templates/*|*/skills/*|*/.claude/hooks/*|*/.claude/commands/*|*/.claude/settings*.json|*/.claude/CLAUDE.md|*/.claude/keybindings.json)
        exit 0
        ;;
    */docs/indexing/*|*/docs/references/*)
        exit 0  # 자동생성 index + 글로벌 공용 docset (synthesis 문서 아님)
        ;;
esac

# 제외 대상: docs/working/ — 진행 중 단일 통합 문서 (이동 후 tasks/ 에서 검증)
case "$file_path" in
    */docs/working/*)
        exit 0
        ;;
esac

# 검증 대상: tasks / output / specs 하위만 (글로벌 ~/.claude/docs/{product}/ 및 구 로컬 호환)
case "$file_path" in
    */docs/tasks/*|*/docs/output/*|*/docs/specs/*|*/docs/*/tasks/*|*/docs/*/output/*|*/docs/*/specs/*)
        ;; # 검증 대상
    *)
        exit 0 # 그 외 스킵
        ;;
esac

# 윈도우 경로 → unix 경로 변환
unix_path=$(echo "$file_path" | sed 's|\\|/|g' | sed 's|^C:|/c|')
if [[ ! -f "$unix_path" ]]; then
    [[ ! -f "$file_path" ]] && exit 0
    unix_path="$file_path"
fi

# === 참조 출처(provenance) 검증 ===
blocking_missing=()

# 1. 섹션 헤더 존재
HAS_SECTION=0
if grep -qE "^##[[:space:]]+.*(참조 출처|Reference Location|Provenance)" "$unix_path"; then
    HAS_SECTION=1
fi

# 2. 인용 패턴 [참조: ...] / [Ref: ...] 카운트
REF_COUNT=$(grep -oE '\[(참조|Ref):[^]]+\]' "$unix_path" | wc -l)
REF_COUNT=${REF_COUNT:-0}

# output/research/ 완화 — 조사(research) 커맨드 산출물은 자체 인용 체계(## 출처 + [N]→URL) 보유.
# 면제가 아니라 네이티브 형식 허용 (출처 섹션 + 웹 인용 강제 유지). SSOT: custom-plugin/taskflow/commands/research.md.
case "$file_path" in
    */output/research/*|*/docs/*/output/research/*)
        if [[ "$HAS_SECTION" -eq 0 ]] && grep -qE "^##[[:space:]]+.*(출처|References|참고 자료|참고자료)" "$unix_path"; then
            HAS_SECTION=1
        fi
        if [[ "$REF_COUNT" -lt 1 ]]; then
            WEBREF=$(grep -oE '(https?://[^ )]+|\[[0-9]+\])' "$unix_path" | wc -l)
            [[ "${WEBREF:-0}" -ge 1 ]] && REF_COUNT=1
        fi
        ;;
esac

if [[ "$HAS_SECTION" -eq 0 ]]; then
    blocking_missing+=("## 참조 출처 (Reference Location) 섹션")
fi
if [[ "$REF_COUNT" -lt 1 ]]; then
    blocking_missing+=("[참조: ...] 인용 ≥ 1건")
fi

# 누락 없으면 통과
if [[ ${#blocking_missing[@]} -eq 0 ]]; then
    exit 0
fi

# === 역소급 면제 (생성일 < 2026-06-02 → hint 강등) ===
# 날짜 결정 우선순위: frontmatter 생성일 → 파일명 prefix → 폴더 tasks/YYYYMMDD/
created_date=""
if grep -qE "^---" "$unix_path"; then
    created_date=$(awk '/^---/{c++; next} c==1 && /^생성일:/ {sub(/^생성일:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$unix_path")
fi
if [[ -z "$created_date" ]]; then
    created_date=$(echo "$basename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
fi
if [[ -z "$created_date" ]]; then
    folder_date=$(echo "$file_path" | grep -oE '/(tasks|YYYYMMDD)?/?[0-9]{8}/' | grep -oE '[0-9]{8}' | head -1)
    if [[ -n "$folder_date" ]]; then
        created_date="${folder_date:0:4}-${folder_date:4:2}-${folder_date:6:2}"
    fi
fi
REF_STRICT_FROM="2026-06-02"
if [[ -n "$created_date" && "$created_date" < "$REF_STRICT_FROM" ]]; then
    # 역소급 면제 — hint 만 주입 (exit 0)
    missing_str=$(IFS=", "; echo "${blocking_missing[*]}")
    command -v log_event >/dev/null 2>&1 && log_event "reference-location-check" "exempt" "date=${created_date}"
    cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[reference-location-check] 역소급 면제(생성일 ${created_date}) — 참조 출처 누락(${missing_str})은 권고. 신규 산출물은 ## 참조 출처 섹션 + [참조: ...] 필수."}}
HOOK_JSON
    exit 0
fi

# === 차단 (exit 2) — 형식·예시 전량 stderr 출력 ===
blocking_str=$(IFS=", "; echo "${blocking_missing[*]}")
command -v log_event >/dev/null 2>&1 && log_event "reference-location-check" "block" "missing=${blocking_str}"
{
echo "[BLOCKED] 참조 출처(Reference Location/참조위치) 누락 — ${blocking_str}"
echo "  파일: ${file_path}"
echo ""
echo "  문서 생성 시 작성 내용의 출처 위치를 무조건 기록해야 합니다 (CLAUDE.md §4.3)."
echo "  필수: (1) '## 참조 출처' 섹션  (2) [참조: ...] 인용 ≥ 1건"
echo ""
echo "  ── 참조위치 형식 (출처 유형별) ──"
echo "    기획서 PDF   : [참조: 화면설계서_v0.2.0 p.12]   (슬라이드형 = 슬라이드 #12)"
echo "    기획/협의 md : [참조: 기획협의통합문서.md L120]  또는  §\"헤딩명\""
echo "    권고 tsv     : [참조: 기획검수안권고사항정리_v2.tsv #34]"
echo "    docs 내부    : [참조: docs/{product}/output/analysis/foo.md L40]"
echo "    코드         : [참조: app/Modules/.../Foo.php:88]"
echo "    웹(조사)     : [참조: 제목 — https://example.com/page (접속 2026-06-02)]"
echo "    원본(차용없음): [참조: 없음 — 신규 분석]"
echo ""
echo "  ── 집계 표 (필수) ──"
echo "    ## 참조 출처 (Reference Location)"
echo "    | # | 내용/섹션 | 출처 유형 | 참조위치 |"
echo "    |---|----------|----------|---------|"
echo "    | 1 | {차용 내용 요약} | 기획서/docs/코드/없음 | [참조: ...] |"
echo ""
echo "  ── 인라인 (권장) ──"
echo "    본문 차용 문장 옆 [참조: ...] 태그 직접 부착"
echo ""
echo "  근거: CLAUDE.md §4.3 \"참조 출처(참조위치) 필수\" + hooks/reference-location-check.sh"
} >&2
exit 2
