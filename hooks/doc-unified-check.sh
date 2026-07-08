#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# doc-unified-check.sh
# PostToolUse:Edit|Write Hook — doc 검증 8-hook 통합 (2026-07-08)
#
# 통합 대상 (settings.json L131-178 8 블록 → 본 1 블록):
#   doc-template-guard / reference-location-check / change-impact-section-check /
#   checklist-count-check / verify-e2e-check / feasibility-section-check /
#   ieee-specs-round-check / checklist-inheritance-check
# 통합 제외: doc-quality.sh (R1 — .php/CLAUDE.md 비-doc 이상치, 별 hook 유지)
#
# 구조 (설계 SSOT: output/analysis/2026-07-08-doc-hook-consolidation-design):
#   파싱 1회 → 스코프 게이트/파일 1회 read → 단일 created_date → 8 validator(순수함수) → 집계 exit 1회
#
# 리스크 준수:
#   R2 역소급 임계 5종(05-07 섹션·체크리스트 / 05-15 e2e / 06-01 techstack "미상=신규차단" / 06-02 참조·증거)
#       = validator별 개별 보존 (전역 단일 날짜 금지, created_date 값만 공유).
#   R3 short-circuit 금지 — 전 validator 실행 후 집계 (차단이 경고 삼키면 안 됨).
#   R5 스코프 경계 — output/ template blocking 면제 / research/ reference 완화 / working/=verify-e2e /
#       feasibility result 제외 / inheritance analyze 제외 / specs 접미사6.
#   R7 reference-location 차단 시 형식·예시 전량 stderr 보존.
#   R8 체크리스트 검증 1곳만(checklist-count SSOT).
#
# 정책: blocking≥1 → 차단+경고 모두 stderr 후 exit 2 / 아니면 경고 후 exit 0.

source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "doc-unified-check" "enter" "pid=$$"
source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"

hook_read_stdin
hook_parse_file_path                        # R6: 단일 파싱 SSOT (file_path 우선, filePath fallback)
FP=$(normalize_path "$FILE_PATH")

# ── 전역 early-exit (파싱 1회 후) ──────────────────────────────
[ -z "$FP" ] && exit 0
[[ "$FP" != *.md ]] && exit 0                # 8 validator 전부 .md 전용
case "$FP" in *docs*) ;; *) exit 0 ;; esac    # 8 validator 전부 경로에 docs 필요

BN="${FP##*/}"
LOWER_BN=$(echo "$BN" | tr '[:upper:]' '[:lower:]')

# 파일 1회 read (grep fork 최소화 — 인메모리 재사용). doc-template-guard/verify-e2e 의 ^C:→/c fallback 보존.
RP="$FP"
[ -f "$RP" ] || RP=$(echo "$FP" | sed 's|^C:|/c|')
[ -f "$RP" ] || exit 0                        # 원본 전부 파일 미존재 시 skip(exit 0)
CONTENT=$(cat "$RP")

# ── grep 헬퍼 (CONTENT 인메모리 대상) ─────────────────────────
_g()   { grep -q  "$1" <<< "$CONTENT"; }      # BRE/literal -q
_ge()  { grep -qE "$1" <<< "$CONTENT"; }      # ERE -q
_gie() { grep -qiE "$1" <<< "$CONTENT"; }     # ERE -qi
_cntE(){ grep -oE "$1" <<< "$CONTENT" | wc -l | tr -d ' '; }

# ── 단일 created_date 산정 (tasks·working·YYYYMMDD 전부. 임계는 validator별 개별) ──
CREATED=""
resolve_created_date() {
  if grep -qE "^---" <<< "$CONTENT"; then
    CREATED=$(awk '/^---/{c++; next} c==1 && /^생성일:/ {sub(/^생성일:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' <<< "$CONTENT")
  fi
  [ -z "$CREATED" ] && CREATED=$(echo "$BN" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  if [ -z "$CREATED" ]; then
    local fd
    fd=$(echo "$FP" | grep -oE '/(tasks|working)?/?[0-9]{8}/' | grep -oE '[0-9]{8}' | head -1)
    [ -n "$fd" ] && CREATED="${fd:0:4}-${fd:4:2}-${fd:6:2}"
  fi
}
resolve_created_date

# 집계 버퍼 (R3: 전 validator 채운 뒤 1회 집계)
BLOCK_MSGS=()
WARN_MSGS=()
add_block() { BLOCK_MSGS+=("$1"); }
add_warn()  { WARN_MSGS+=("$1"); }

# ══════════════════════════════════════════════════════════════
# V1: doc-template-guard  (Scope A 광역doc, output blocking 면제, 05-07·06-01 임계)
# ══════════════════════════════════════════════════════════════
v_template_guard() {
  case "$BN" in
    summary.md|history.md|MEMORY.md|CLAUDE.md|README.md|SKILL.md|CHANGELOG.md) return 0 ;;
  esac
  case "$FP" in
    */memory/*|*/templates/*|*/skills/*|*/.claude/hooks/*|*/.claude/commands/*|*/.claude/settings*.json|*/.claude/CLAUDE.md|*/.claude/keybindings.json) return 0 ;;
  esac
  case "$FP" in */docs/working/*) return 0 ;; esac
  case "$FP" in
    */docs/tasks/*|*/docs/output/*|*/docs/specs/*|*/docs/*/tasks/*|*/docs/*/output/*|*/docs/*/specs/*) ;;
    *) return 0 ;;
  esac

  local IS_OUTPUT=0
  case "$FP" in */docs/output/*|*/docs/*/output/*) IS_OUTPUT=1 ;; esac

  local tgb=() tgh=()
  _g '^# '   || tgh+=("제목(# heading)")
  _g '^>'    || tgh+=("간단 요약(> blockquote)")
  _g '## 작성 정보' || tgh+=("## 작성 정보")
  _ge '## (내용|분석|계획|실행|결과|분석 결과|실행 계획|실행 결과)' || tgh+=("## 내용 (본문 섹션)")
  _g '## 체크리스트' || tgh+=("## 체크리스트")
  _g '## 변경 기록'  || tgh+=("## 변경 기록")

  local MISSING_TECHSTACK=0
  if [ "$IS_OUTPUT" = "0" ]; then
    case "$LOWER_BN" in
      *-unified.md|*_unified.md)
        _ge '^##[[:space:]]+.*(타당성 검토|Feasibility Review)' || tgb+=("타당성 검토 (§4 필수, unified §분석)")
        _ge '^##[[:space:]]+.*(변경 영향|Change Impact)'        || tgb+=("변경 영향 기록 (§4 필수, unified)")
        _ge '^##[[:space:]]+.*(분석 관점별|관점별 요약|Perspective Summary)' || tgb+=("분석 관점별 요약 (unified §분석)")
        _ge '^##[[:space:]]+.*Critical[[:space:]]*이슈' || tgb+=("Critical 이슈 분류 (unified §분석)")
        _ge '^##[[:space:]]+.*High[[:space:]]*이슈'     || tgb+=("High 이슈 분류 (unified §분석)")
        _ge '^##[[:space:]]+.*Medium[[:space:]]*이슈'   || tgb+=("Medium 이슈 분류 (unified §분석)")
        _ge '^##[[:space:]]+.*Low[[:space:]]*이슈'      || tgb+=("Low 이슈 분류 (unified §분석)")
        _ge '^##[[:space:]]+.*우선순위[[:space:]]*권고' || tgb+=("우선순위 권고 (unified §분석)")
        _ge '^##[[:space:]]+.*(장기 영향|Long-term Impact)'    || tgb+=("장기 영향 (CLAUDE.md §4.1 강제, unified)")
        _ge '^##[[:space:]]+.*(재발 방지|Regression Prevention)' || tgb+=("재발 방지 (CLAUDE.md §4.1 강제, unified)")
        _ge '^##[[:space:]]+.*(SSOT 일관성|SSOT Consistency)'  || tgb+=("SSOT 일관성 (CLAUDE.md §4.1 강제, unified)")
        _ge '(^##[[:space:]]+.*작업 등급|작업 등급[[:space:]]*[::])' || tgb+=("작업 등급 S/M/L (unified §계획)")
        _ge '^##[[:space:]]+.*Blueprint'   || tgb+=("Blueprint (unified §계획)")
        _ge '^##[[:space:]]+.*수정 대상'   || tgb+=("수정 대상 (unified §계획)")
        _ge '^##[[:space:]]+.*실행 계획'   || tgb+=("실행 계획 (unified §계획)")
        _ge '^##[[:space:]]+.*(작업 분해|WBS|Work Breakdown)' || tgb+=("작업 분해 WBS (unified §계획)")
        _ge '^##[[:space:]]+.*실행 요약'   || tgb+=("실행 요약 (unified §실행)")
        _ge '^##[[:space:]]+.*Self-Critique' || tgb+=("Self-Critique 체크리스트 (unified §실행)")
        _ge '^##[[:space:]]+.*테스트 결과' || tgb+=("테스트 결과 (unified §실행)")
        _ge '^##[[:space:]]+.*잔여 이슈'   || tgb+=("잔여 이슈 (unified §실행)")
        _ge 'Status[[:space:]]*[::][[:space:]]*(Done|Partial)' || tgb+=("Status: Done/Partial (unified §실행)")
        _ge '^##[[:space:]]+.*(Before.?/.?After|최초 실행안|최초안|제안.?반영)' || tgh+=("## Before/After 대조 (§4 필수, unified §실행)")
        _ge '^##[[:space:]]+.*(롤백|Rollback)' || tgh+=("## 롤백 (§4 필수, unified §실행)")
        _ge '^#[[:space:]]+§[[:space:]]*타당성 검토' || tgh+=("# § 타당성 검토 (선택, /taskflow:feasibility 진입 시)")
        _ge '^#[[:space:]]+§[[:space:]]*검증' || tgh+=("# § 검증 (선택, /taskflow:verify 진입 시)")
        _ge '^#[[:space:]]+§[[:space:]]*리뷰' || tgh+=("# § 리뷰 (선택, /taskflow:review 진입 시)")
        _ge '^#[[:space:]]+§[[:space:]]*회고' || tgh+=("# § 회고 (선택, /taskflow:retro 진입 시)")
        if [[ "$FP" == */hongcafe_global_backend/* ]]; then
          _ge '^##[[:space:]]+.*(참조 문서 검토 결과|Reference Doc Review)' || tgb+=("참조 문서 검토 결과 (be 한정, unified §분석)")
        fi
        ;;
      *analyze*.md)
        _ge '^##[[:space:]]+.*(타당성 검토|Feasibility Review)' || tgb+=("타당성 검토 (§4 필수)")
        _ge '^##[[:space:]]+.*(변경 영향|Change Impact)'        || tgb+=("변경 영향 기록 (§4 필수)")
        _ge '^##[[:space:]]+.*(분석 관점별|관점별 요약|Perspective Summary)' || tgb+=("분석 관점별 요약 (analyze 템플릿 §관점별 요약)")
        _ge '^##[[:space:]]+.*Critical[[:space:]]*이슈' || tgb+=("Critical 이슈 분류 (analyze 템플릿 §1)")
        _ge '^##[[:space:]]+.*High[[:space:]]*이슈'     || tgb+=("High 이슈 분류 (analyze 템플릿 §2)")
        _ge '^##[[:space:]]+.*Medium[[:space:]]*이슈'   || tgb+=("Medium 이슈 분류 (analyze 템플릿 §3)")
        _ge '^##[[:space:]]+.*Low[[:space:]]*이슈'      || tgb+=("Low 이슈 분류 (analyze 템플릿 §4)")
        _ge '^##[[:space:]]+.*우선순위[[:space:]]*권고' || tgb+=("우선순위 권고 (analyze 템플릿 §9)")
        _ge '^##[[:space:]]+.*(장기 영향|Long-term Impact)'    || tgb+=("장기 영향 (CLAUDE.md §4.1 강제)")
        _ge '^##[[:space:]]+.*(재발 방지|Regression Prevention)' || tgb+=("재발 방지 (CLAUDE.md §4.1 강제)")
        _ge '^##[[:space:]]+.*(SSOT 일관성|SSOT Consistency)'  || tgb+=("SSOT 일관성 (CLAUDE.md §4.1 강제)")
        if [[ "$FP" == */hongcafe_global_backend/* ]]; then
          _ge '^##[[:space:]]+.*(참조 문서 검토 결과|Reference Doc Review)' || tgb+=("참조 문서 검토 결과 (hongcafe_global_backend CLAUDE.md §\"분석·계획 시 참조 강제 룰\" 6항목)")
        fi
        ;;
      *plan*.md)
        _ge '^##[[:space:]]+.*(타당성 검토|Feasibility Review)' || tgb+=("타당성 검토 (§4 필수)")
        _ge '^##[[:space:]]+.*(변경 영향|Change Impact)'        || tgb+=("변경 영향 기록 (§4 필수)")
        _ge '(^##[[:space:]]+.*작업 등급|작업 등급[[:space:]]*[::])' || tgb+=("작업 등급 S/M/L (plan 템플릿)")
        _ge '^##[[:space:]]+.*Blueprint' || tgb+=("Blueprint (plan 템플릿)")
        _ge '^##[[:space:]]+.*수정 대상' || tgb+=("수정 대상 (plan 템플릿 §수정 대상)")
        _ge '^##[[:space:]]+.*실행 계획' || tgb+=("실행 계획 (plan 템플릿 §실행 계획)")
        _ge '^##[[:space:]]+.*(작업 분해|WBS|Work Breakdown)' || tgb+=("작업 분해 WBS (plan 템플릿)")
        _ge '^##[[:space:]]+.*(장기 영향|Long-term Impact)'    || tgb+=("장기 영향 (CLAUDE.md §4.1 강제)")
        _ge '^##[[:space:]]+.*(재발 방지|Regression Prevention)' || tgb+=("재발 방지 (CLAUDE.md §4.1 강제)")
        _ge '^##[[:space:]]+.*(SSOT 일관성|SSOT Consistency)'  || tgb+=("SSOT 일관성 (CLAUDE.md §4.1 강제)")
        _ge 'Status[[:space:]]*[::][[:space:]]*Plan Complete' || tgb+=("Status: Plan Complete (plan 템플릿)")
        if [[ "$FP" == */hongcafe_global_backend/* ]]; then
          _ge '^##[[:space:]]+.*(참조 문서 검토 결과|Reference Doc Review)' || tgb+=("참조 문서 검토 결과 (hongcafe_global_backend CLAUDE.md §\"분석·계획 시 참조 강제 룰\" 6항목)")
        fi
        ;;
      *result*.md)
        _ge '^##[[:space:]]+.*(변경 영향|Change Impact)' || tgb+=("변경 영향 기록 (§4 필수)")
        _ge '^##[[:space:]]+.*실행 요약'   || tgb+=("실행 요약 (result 템플릿)")
        _ge '^##[[:space:]]+.*Self-Critique' || tgb+=("Self-Critique 체크리스트 (result 템플릿)")
        _ge '^##[[:space:]]+.*테스트 결과' || tgb+=("테스트 결과 (result 템플릿)")
        _ge '^##[[:space:]]+.*잔여 이슈'   || tgb+=("잔여 이슈 (result 템플릿)")
        _ge 'Status[[:space:]]*[::][[:space:]]*(Done|Partial)' || tgb+=("Status: Done/Partial (result 템플릿)")
        _ge '^##[[:space:]]+.*(Before.?/.?After|최초 실행안|최초안|제안.?반영)' || tgh+=("## Before/After 대조 (§4 필수)")
        _ge '^##[[:space:]]+.*(롤백|Rollback)' || tgh+=("## 롤백 (§4 필수)")
        ;;
    esac

    case "$FP" in
      */docs/specs/*|*/docs/*/specs/*)
        _ge '^##[[:space:]]+.*(타당성 검토|Feasibility Review)' || tgb+=("타당성 검토 (§4 필수)")
        ;;
    esac

    case "$FP" in
      */docs/specs/*|*/docs/*/specs/*) ;;
      *)
        if _g '## 작성 정보' && ! _ge '(^\|[[:space:]]*개발언어|^개발언어[[:space:]]*:)'; then
          MISSING_TECHSTACK=1
        fi
        ;;
    esac
  fi

  # 역소급 게이트 1 (2026-05-07): 섹션 blocking 강등
  if [ -n "$CREATED" ] && [[ "$CREATED" < "2026-05-07" ]]; then
    if [ ${#tgb[@]} -gt 0 ]; then
      tgh+=("[역소급 면제 — 생성일 ${CREATED}] ${tgb[*]}")
      tgb=()
    fi
  fi
  # 역소급 게이트 2 (techstack 2026-06-01, 독립 임계. 미상=신규=차단)
  if [ "$MISSING_TECHSTACK" = "1" ]; then
    if [ -n "$CREATED" ] && [[ "$CREATED" < "2026-06-01" ]]; then
      tgh+=("[역소급 면제 — 생성일 ${CREATED}] 개발언어/기술스택 (작성 정보 행)")
    else
      tgb+=("개발언어/기술스택 (작성 정보 필수 행, 2026-06-01~)")
    fi
  fi

  if [ ${#tgb[@]} -gt 0 ]; then
    local s; s=$(IFS=", "; echo "${tgb[*]}")
    add_block "[BLOCKED] ${s} 섹션 누락 — ${FP} 보완 후 재작성하세요."
  fi
  if [ ${#tgh[@]} -gt 0 ]; then
    local h; h=$(IFS=", "; echo "${tgh[*]}")
    add_warn "[doc-template-guard] 문서 양식 불일치 — 누락: ${h}. ~/.claude/templates/doc-template.md 양식 + CLAUDE.md §4 필수 섹션에 따라 즉시 수정하세요."
  fi
}

# ══════════════════════════════════════════════════════════════
# V2: reference-location-check  (Scope A, research/ 완화, 06-02 임계, R7 형식 전량)
# ══════════════════════════════════════════════════════════════
v_reference_location() {
  case "$BN" in
    summary.md|history.md|MEMORY.md|CLAUDE.md|README.md|SKILL.md|CHANGELOG.md|changelog.md|REGISTRY.md) return 0 ;;
  esac
  case "$FP" in
    */memory/*|*/templates/*|*/skills/*|*/.claude/hooks/*|*/.claude/commands/*|*/.claude/settings*.json|*/.claude/CLAUDE.md|*/.claude/keybindings.json) return 0 ;;
    */docs/indexing/*|*/docs/references/*) return 0 ;;
  esac
  case "$FP" in */docs/working/*) return 0 ;; esac
  case "$FP" in
    */docs/tasks/*|*/docs/output/*|*/docs/specs/*|*/docs/*/tasks/*|*/docs/*/output/*|*/docs/*/specs/*) ;;
    *) return 0 ;;
  esac

  local blocking=()
  local HAS_SECTION=0
  _ge '^##[[:space:]]+.*(참조 출처|Reference Location|Provenance)' && HAS_SECTION=1
  local REF_COUNT
  REF_COUNT=$(_cntE '\[(참조|Ref):[^]]+\]'); REF_COUNT=${REF_COUNT:-0}

  case "$FP" in
    */output/research/*|*/docs/*/output/research/*)
      if [ "$HAS_SECTION" -eq 0 ] && _ge '^##[[:space:]]+.*(출처|References|참고 자료|참고자료)'; then
        HAS_SECTION=1
      fi
      if [ "$REF_COUNT" -lt 1 ]; then
        local WEBREF; WEBREF=$(_cntE '(https?://[^ )]+|\[[0-9]+\])'); [ "${WEBREF:-0}" -ge 1 ] && REF_COUNT=1
      fi
      ;;
  esac

  [ "$HAS_SECTION" -eq 0 ] && blocking+=("## 참조 출처 (Reference Location) 섹션")
  [ "$REF_COUNT" -lt 1 ]   && blocking+=("[참조: ...] 인용 ≥ 1건")
  [ ${#blocking[@]} -eq 0 ] && return 0

  local bstr; bstr=$(IFS=", "; echo "${blocking[*]}")
  # 역소급 면제 (생성일 < 2026-06-02 → hint). 미상(빈값)=차단 유지.
  if [ -n "$CREATED" ] && [[ "$CREATED" < "2026-06-02" ]]; then
    add_warn "[reference-location-check] 역소급 면제(생성일 ${CREATED}) — 참조 출처 누락(${bstr})은 권고. 신규 산출물은 ## 참조 출처 섹션 + [참조: ...] 필수."
    return 0
  fi
  # 차단 — R7: 형식·예시 전량 보존
  add_block "$(cat <<REFBLK
[BLOCKED] 참조 출처(Reference Location/참조위치) 누락 — ${bstr}
  파일: ${FP}

  문서 생성 시 작성 내용의 출처 위치를 무조건 기록해야 합니다 (CLAUDE.md §4.3).
  필수: (1) '## 참조 출처' 섹션  (2) [참조: ...] 인용 ≥ 1건

  ── 참조위치 형식 (출처 유형별) ──
    기획서 PDF   : [참조: 화면설계서_v0.2.0 p.12]   (슬라이드형 = 슬라이드 #12)
    기획/협의 md : [참조: 기획협의통합문서.md L120]  또는  §"헤딩명"
    권고 tsv     : [참조: 기획검수안권고사항정리_v2.tsv #34]
    docs 내부    : [참조: docs/{product}/output/analysis/foo.md L40]
    코드         : [참조: app/Modules/.../Foo.php:88]
    웹(조사)     : [참조: 제목 — https://example.com/page (접속 2026-06-02)]
    원본(차용없음): [참조: 없음 — 신규 분석]

  ── 집계 표 (필수) ──
    ## 참조 출처 (Reference Location)
    | # | 내용/섹션 | 출처 유형 | 참조위치 |
    |---|----------|----------|---------|
    | 1 | {차용 내용 요약} | 기획서/docs/코드/없음 | [참조: ...] |

  ── 인라인 (권장) ──
    본문 차용 문장 옆 [참조: ...] 태그 직접 부착

  근거: CLAUDE.md §4.3 "참조 출처(참조위치) 필수" + hooks/doc-unified-check.sh
REFBLK
)"
}

# ══════════════════════════════════════════════════════════════
# V3: change-impact-section-check  (Scope B, warn-only, "제안 추가: 없음" 예외)
# ══════════════════════════════════════════════════════════════
v_change_impact() {
  echo "$FP" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || return 0
  [ "$BN" = "summary.md" ] && return 0
  [ "$BN" = "history.md" ] && return 0
  echo "$BN" | grep -qE '\-(analyze|plan|result|unified)\.md$' || return 0

  _ge '제안 추가:?\s*없음' && return 0

  if ! _ge '^##\s+.*(변경 영향|Change Impact)'; then
    add_warn "[CHANGE-IMPACT] $FP: '## ... 변경 영향' (또는 '## ... Change Impact') 섹션 누락
                CLAUDE.md §4 — analyze/plan/result 모든 단계 필수, 이유 생략 금지.
                예외: 본문에 '제안 추가: 없음' 명시 시 통과."
    return 0
  fi
  local HEADER_PATTERN='\|.*(변경|Change)[^|]*\|.*(개선|Improvement)[^|]*\|.*(이유|Why|Reason)[^|]*\|'
  if ! _ge "$HEADER_PATTERN"; then
    add_warn "[CHANGE-IMPACT] $FP: '변경 영향' 섹션은 존재하나 3열 표(변경/개선/이유) 헤더 누락
                예시: | 변경 사항 | 개선점 | 수행 이유 |"
    return 0
  fi
  local DATA_ROWS
  DATA_ROWS=$(awk '
    /^##\s+.*(변경 영향|Change Impact)/ { in_section=1; next }
    in_section && /^##\s+/ { in_section=0 }
    in_section && /^\|.*(변경|Change).*\|.*(개선|Improvement).*\|.*(이유|Why|Reason).*\|/ { in_table=1; next }
    in_table && /^\|[\s\-:|]+\|$/ { next }
    in_table && /^\|/ { count++; next }
    in_table && !/^\|/ { in_table=0 }
    END { print count+0 }
  ' <<< "$CONTENT")
  if [ "${DATA_ROWS:-0}" -lt 1 ]; then
    add_warn "[CHANGE-IMPACT] $FP: 3열 표 헤더는 존재하나 데이터 행 0개
                최소 1건 이상의 변경/개선/이유 행을 작성하세요."
  fi
}

# ══════════════════════════════════════════════════════════════
# V4: checklist-count-check  (Scope B, R8 체크리스트 SSOT, 05-07 임계, 차단)
# ══════════════════════════════════════════════════════════════
v_checklist_count() {
  echo "$FP" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || return 0
  [ "$BN" = "summary.md" ] && return 0
  [ "$BN" = "history.md" ] && return 0
  local STAGE
  STAGE=$(echo "$BN" | grep -oE '\-(analyze|plan|result|unified)\.md$' | sed -E 's/^-//;s/\.md$//')
  [ -z "$STAGE" ] && return 0

  local MIN
  case "$STAGE" in
    analyze) MIN=30 ;;
    plan)    MIN=20 ;;
    result)  MIN=20 ;;
    unified) MIN=30 ;;
    *)       return 0 ;;
  esac
  local COUNT
  COUNT=$(grep -cE '^[[:space:]]*-[[:space:]]+\[[[:space:]xX]\]' <<< "$CONTENT"); COUNT=${COUNT:-0}
  [ "$COUNT" -ge "$MIN" ] && return 0

  if [ -n "$CREATED" ] && [[ "$CREATED" < "2026-05-07" ]]; then
    add_warn "[CHECKLIST hint — 역소급 면제 ${CREATED}] $FP: 체크리스트 ${COUNT}개 (필요: ${MIN}개)
                  task-docs §TD-4 — analyze≥30 / plan≥20 / result≥20."
    return 0
  fi
  add_block "[BLOCKED] $FP: 체크리스트 ${COUNT}개 부족 (필요: ${MIN}개)
          task-docs §TD-4 — analyze≥30 / plan≥20 / result≥20 / unified≥30.
          references/{analyze,plan,result,unified}-template.md SSOT 골격 prepend 후 보강하세요."
}

# ══════════════════════════════════════════════════════════════
# V5: verify-e2e-check  (Scope C working+unified, 05-15 임계, 06-02 capture hint, 차단)
# ══════════════════════════════════════════════════════════════
v_verify_e2e() {
  case "$BN" in
    summary.md|history.md|MEMORY.md|CLAUDE.md|README.md|SKILL.md|CHANGELOG.md) return 0 ;;
  esac
  case "$FP" in
    */docs/working/*|*/docs/*/tasks/*-unified.md|*/docs/*/tasks/*/*-unified.md) ;;
    *) return 0 ;;
  esac

  local GRANDFATHER=0
  [ -n "$CREATED" ] && [[ "$CREATED" < "2026-05-15" ]] && GRANDFATHER=1

  local fail_points=()
  _gie '(env\(|\.env|DOTENV|APP_ENV|환경 ?변수|환경 ?설정)' || fail_points+=("1. env/설정 키워드 누락 (env\\(|.env|DOTENV|APP_ENV|환경 변수)")
  _gie '(\bfunction\b|\bclass\b|public function|메서드|시그니처|signature)' || fail_points+=("2. 함수/클래스 시그니처 누락 (function|class|메서드)")
  _gie '(\bschema\b|\bmigration\b|\btable\b|ALTER|CREATE TABLE|DDL|스키마|마이그레이션|해당 없음)' || fail_points+=("3. DB 스키마 키워드 누락 (schema|migration|table|ALTER|스키마)")
  _gie '(\bcurl\b|\bhttp\b|fetch|production|프로덕션|엔드포인트|endpoint)' || fail_points+=("4. 프로덕션 curl 키워드 누락 (curl|http|fetch|production|엔드포인트)")
  _gie '(\bmock\b|\bstub\b|\bfake\b|모의|검증 모드)' || fail_points+=("5. mock 검증 분리 키워드 누락 (mock|stub|fake|모의)")
  local FAIL_COUNT=${#fail_points[@]}

  # capture hint (06-02, 비차단) — 테스트 통과 주장 ↔ 사용자-체크 가능 증거
  local capture_in_scope=1
  [ -n "$CREATED" ] && [[ "$CREATED" < "2026-06-02" ]] && capture_in_scope=0
  if [ "$capture_in_scope" = "1" ] \
     && _gie 'OK \([0-9]+ tests|[0-9]+ tests?,? [0-9]+ assertion|[0-9]+/[0-9]+ ?(통과|passed)|[0-9]+ passed|pipeline ?#?[0-9]+' \
     && ! _ge '```|\.xml|https?://|junit'; then
    add_warn "[hint] verify-e2e-check: 테스트 통과를 주장하나 사용자-체크 가능 증거 미동반 — pipeline URL+빌드번호 / junit .xml 경로 / 러너 원문 코드블록 권장 (산문 단언은 재현 불가, audit 2026-06-02). 비차단(hint)."
  fi

  [ "$FAIL_COUNT" -eq 0 ] && return 0

  if [ "$GRANDFATHER" = "1" ]; then
    local msg="[hint] verify-e2e-check: e2e 5점 중 $FAIL_COUNT 점 누락 (역소급 면제 — 생성일 $CREATED)"
    local p; for p in "${fail_points[@]}"; do msg+=$'\n'"  · $p"; done
    add_warn "$msg"
    return 0
  fi
  local bmsg="[BLOCKED] verify-e2e-check: e2e 5점 중 $FAIL_COUNT 점 누락"$'\n'"  파일: $FP"
  local p; for p in "${fail_points[@]}"; do bmsg+=$'\n'"  · $p"; done
  bmsg+=$'\n\n'"SSOT: php8 §\"e2e 검증\" + CLAUDE.md §4.3 \"e2e 검증 (필수)\""$'\n'"진입점: /taskflow:verify  (~/.claude/custom-plugin/taskflow/commands/verify.md)"
  add_block "$bmsg"
}

# ══════════════════════════════════════════════════════════════
# V6: feasibility-section-check  (Scope B, result 제외, warn-only)
# ══════════════════════════════════════════════════════════════
v_feasibility() {
  echo "$FP" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || return 0
  [ "$BN" = "summary.md" ] && return 0
  [ "$BN" = "history.md" ] && return 0
  echo "$BN" | grep -qE '\-(analyze|plan|unified)\.md$' || return 0

  local HAS_HEADER=0
  _ge '^##\s+.*(타당성 검토|Feasibility Review)' && HAS_HEADER=1
  local SOURCE_COUNT
  SOURCE_COUNT=$(_cntE '\[Source:[^]]+§[^]]+\]'); SOURCE_COUNT=${SOURCE_COUNT:-0}

  if [ "$HAS_HEADER" -eq 1 ]; then
    if [ "$SOURCE_COUNT" -lt 1 ]; then
      add_warn "[FEASIBILITY] $FP: '타당성 검토' 섹션은 존재하나 엄격 인용 [Source: <name> §<id>] 누락
              예시: [Source: claude-code §hooks], [Source: rfc-7231 §4.3]
              CLAUDE.md §4 — 5영역 작업 공식 문서 근거 필수."
    fi
    return 0
  fi
  local KEYWORD_PATTERN='(라이브러리|프레임워크|아키텍처|DB 스키마|통신 패턴|계층 구조|API 설계|엔드포인트|API 계약|인증 방식|보안 패턴|OWASP|RFC|권한 모델|SDD|SRS|IDD)'
  local KEYWORD_HITS
  KEYWORD_HITS=$(grep -oE "$KEYWORD_PATTERN" <<< "$CONTENT" | sort -u | wc -l); KEYWORD_HITS=${KEYWORD_HITS:-0}
  if [ "$KEYWORD_HITS" -ge 2 ]; then
    add_warn "[FEASIBILITY] $FP: 5영역 키워드 ${KEYWORD_HITS}종 등장 — '## 타당성 검토' 섹션 + [Source: ...] 인용 권고
              CLAUDE.md §4 — 라이브러리/아키텍처/API/보안/설계 작업 근거 필수."
  fi
}

# ══════════════════════════════════════════════════════════════
# V7: ieee-specs-round-check  (Scope D specs 접미사6, warn-only)
# ══════════════════════════════════════════════════════════════
v_ieee_specs() {
  echo "$FP" | grep -qiE '/docs/[^/]+/specs/.+-(srs|sdd|idd|sdp|stp|std)\.md$' || return 0

  local FRONTMATTER
  FRONTMATTER=$(awk '/^---$/{c++; if(c==1){next} else {exit}} c==1' <<< "$CONTENT")
  if [ -z "$FRONTMATTER" ]; then
    add_warn "[IEEE-SPECS] $FP: YAML frontmatter 누락"
    return 0
  fi

  local ERRORS=()
  local STATUS
  STATUS=$(echo "$FRONTMATTER" | grep -E '^status:' | head -1 | sed -E 's/^status:[[:space:]]*//' | tr -d '"' | tr -d "'")
  if [ -z "$STATUS" ]; then
    ERRORS+=("status 필드 누락 (값: 초안 | 검토중 | 승인됨)")
  elif ! echo "$STATUS" | grep -qE '^(초안|검토중|승인됨)$'; then
    ERRORS+=("status: '$STATUS' 비표준 (허용: 초안 | 검토중 | 승인됨)")
  fi

  declare -A ROUNDS
  local n VAL
  for n in 1 2 3; do
    VAL=$(echo "$FRONTMATTER" | grep -E "^round-$n:" | head -1 | sed -E "s/^round-$n:[[:space:]]*//" | tr -d '"' | tr -d "'")
    if [ -z "$VAL" ]; then
      ERRORS+=("round-$n 필드 누락 (값: pass | fail | pending)")
    elif ! echo "$VAL" | grep -qE '^(pass|fail|pending)$'; then
      ERRORS+=("round-$n: '$VAL' 비표준 (허용: pass | fail | pending)")
    fi
    ROUNDS[$n]=$VAL
  done

  for n in 1 2 3; do
    _ge "^##\s+Round\s+$n" || ERRORS+=("본문 '## Round $n ...' 헤더 누락")
  done

  if [ "$STATUS" = "승인됨" ]; then
    for n in 1 2 3; do
      if [ "${ROUNDS[$n]}" != "pass" ]; then
        ERRORS+=("status: 승인됨 인 경우 round-$n: pass 필수 (현재: '${ROUNDS[$n]}')")
      fi
    done
  fi

  if [ ${#ERRORS[@]} -gt 0 ]; then
    local msg="[IEEE-SPECS] $FP: 3-Round 메타데이터 검증 실패"
    local e; for e in "${ERRORS[@]}"; do msg+=$'\n'"             - $e"; done
    msg+=$'\n'"             task-docs §H — SRS/SDD/IDD/SDP/STP/STD 적합성 재검토 필수."
    add_warn "$msg"
  fi
}

# ══════════════════════════════════════════════════════════════
# V8: checklist-inheritance-check  (Scope B plan|result, 크로스파일 read, warn-only)
# ══════════════════════════════════════════════════════════════
v_checklist_inheritance() {
  echo "$FP" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$' || return 0
  [ "$BN" = "summary.md" ] && return 0
  [ "$BN" = "history.md" ] && return 0
  local STAGE
  STAGE=$(echo "$BN" | grep -oE '\-(plan|result)\.md$' | sed -E 's/^-//;s/\.md$//')
  [ -z "$STAGE" ] && return 0

  local WORK_DIR; WORK_DIR=$(dirname "$FP")
  local PREV_PATTERN
  case "$STAGE" in
    plan)   PREV_PATTERN='*-analyze.md' ;;
    result) PREV_PATTERN='*-plan.md' ;;
  esac
  local PREV_FILE="" f
  for f in "$WORK_DIR"/$PREV_PATTERN; do
    [ -f "$f" ] && PREV_FILE="$f" && break
  done
  [ -z "$PREV_FILE" ] && return 0

  local PREV_ITEMS
  PREV_ITEMS=$(grep -E '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$PREV_FILE" | sed -E 's/^[[:space:]]*-[[:space:]]+\[[[:space:]]\][[:space:]]*//')
  [ -z "$PREV_ITEMS" ] && return 0

  local TOTAL=0 MATCHED=0 MISSING_ITEMS=() item prefix
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    TOTAL=$((TOTAL + 1))
    prefix=$(echo "$item" | cut -c1-30)
    if grep -qF -- "$prefix" <<< "$CONTENT"; then
      MATCHED=$((MATCHED + 1))
    else
      [ ${#MISSING_ITEMS[@]} -lt 3 ] && MISSING_ITEMS+=("$item")
    fi
  done <<< "$PREV_ITEMS"
  [ "$TOTAL" -eq 0 ] && return 0

  local PCT=$((MATCHED * 100 / TOTAL))
  if [ "$PCT" -lt 50 ]; then
    local msg="[CHECKLIST-INHERIT] $FP: 이전 단계 미체크 항목 $TOTAL건 중 ${MATCHED}건만 본문에 언급 (${PCT}%)"
    msg+=$'\n'"                    이전 산출물: $PREV_FILE"
    msg+=$'\n'"                    누락 예시 (최대 3건):"
    local t; for item in "${MISSING_ITEMS[@]}"; do
      t=$(echo "$item" | cut -c1-60); msg+=$'\n'"                      • $t"
    done
    msg+=$'\n'"                    task-docs §TD-5 — Team 2/3 산출물은 이전 체크 항목 검증 후 잔여 이슈 명시."
    add_warn "$msg"
  fi
}

# ── 8 validator 실행 (순수함수, exit 안 함) ────────────────────
v_template_guard
v_reference_location
v_change_impact
v_checklist_count
v_verify_e2e
v_feasibility
v_ieee_specs
v_checklist_inheritance

# ── 집계 exit 1회 ──────────────────────────────────────────────
if [ ${#BLOCK_MSGS[@]} -gt 0 ]; then
  {
    for m in "${BLOCK_MSGS[@]}"; do echo "$m"; done
    if [ ${#WARN_MSGS[@]} -gt 0 ]; then
      echo ""
      echo "── 경고(비차단, 함께 표시) ──"
      for m in "${WARN_MSGS[@]}"; do echo "$m"; done
    fi
  } >&2
  command -v log_event >/dev/null 2>&1 && log_event "doc-unified-check" "block" "blocks=${#BLOCK_MSGS[@]} warns=${#WARN_MSGS[@]}"
  exit 2
fi

if [ ${#WARN_MSGS[@]} -gt 0 ]; then
  for m in "${WARN_MSGS[@]}"; do echo "$m" >&2; done
  # 모델 피드백용 additionalContext (hint-계열 validator 의 model-feedback 보존)
  joined=""
  for m in "${WARN_MSGS[@]}"; do joined+="${m} | "; done
  joined="${joined//\\/\\\\}"
  joined="${joined//\"/\\\"}"
  joined="${joined//$'\n'/ }"
  cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[doc-unified-check] 경고: ${joined}"}}
HOOK_JSON
  exit 0
fi

exit 0
