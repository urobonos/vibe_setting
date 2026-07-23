#!/usr/bin/env bash
# working-scan.sh — working/ 태스크 문서 훑기 단일 SSOT (2026-07-23)
#
# 목적: working/ 스캔을 tick·control·load 에서 매번 인라인 grep 으로 재작성하던 drift 제거.
#       한 함수가 working/ 모든 문서(unified + step 평면)를 파싱해 구조화 TSV 로 반환.
#
# 2026-07-23 재작성: bash 이중 루프(파일마다 grep/echo/basename/sed 서브셸 + docs/*/ 이중 루프
#   = Windows Git Bash fork 수백~천 프로세스, 100초+) → find + awk 단일 패스(프로세스 2~3개).
#   + status 파싱을 '첫 상태 키워드'만 추출 — 실제 문서의 '상태: Partial (긴 부연 설명…)' 을
#     통째로 잡아 tick 의 정확 매칭(Pending/ReadyToMerge)이 실패하던 버그 수정.
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/working-scan.sh"   # hooks/ 기준
#   working_scan [product|all]
#
# 출력 (TSV, 문서 1개당 1줄):
#   파일경로 \t date(YYYY-MM-DD) \t product \t 작업명 \t status \t is_step(0|1)
#   - status  = 문서 첫 '^Status:'(unified) / '^상태:'(step frontmatter) 라인의 **첫 상태 키워드**
#               (Plan Complete/In Progress/ReadyToMerge/NeedsDecision/Pending/Partial/Done/초안 등).
#               '상태: Partial (부연…)' → 'Partial'. 없으면 '-'.
#   - is_step = 1(파일명 '-step-NN-') / 0(unified)
#   - product = docs/{product}/ 디렉토리 prefix 매칭(가장 긴 것 우선). filter 지정 시 그 product 만.

WORKING_ROOT="${WORKING_ROOT:-$HOME/.claude/docs/working}"
WORKING_SCAN_DOCS_ROOT="${WORKING_SCAN_DOCS_ROOT:-$HOME/.claude/docs}"

working_scan() {
  local filter="${1:-all}"
  [ -d "$WORKING_ROOT" ] || return 0

  # product 목록 1회 산출 (docs/*/ basename, working·references 제외) — 파일마다 순회 안 함
  local prod_list
  prod_list=$(cd "$WORKING_SCAN_DOCS_ROOT" 2>/dev/null && ls -d */ 2>/dev/null \
    | sed 's:/$::' | grep -vxE 'working|references' | tr '\n' ' ')

  # find(1) + awk(1) 단일 패스 — 파일명 파싱·product 매칭·status 첫 키워드 전부 awk 내부
  find "$WORKING_ROOT" -mindepth 2 -maxdepth 2 -name '*.md' -print0 2>/dev/null | xargs -0 -r awk \
    -v filter="$filter" -v products="$prod_list" '
    function emit() {
      if (path=="" || product=="") return
      if (filter!="all" && product!=filter) return
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", path, date, product, task, status, is_step
    }
    BEGIN {
      np=split(products, P, " ")
      # 상태 키워드 — 실제 status 값이 부연보다 앞서 매칭되도록 두 단어형·특이형을 앞에 둔다
      nk=split("Plan Complete|Analysis Complete|In Progress|ReadyToMerge|NeedsDecision|Pending|Partial|Done|초안|완료|폐기|Abandoned", KW, "|")
    }
    FILENAME != seen {
      emit()
      seen=FILENAME; path=FILENAME
      n=split(FILENAME, pp, "/"); fname=pp[n]
      if (fname ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { date=substr(fname,1,10) } else { path=""; next }
      rest=substr(fname,12); sub(/\.md$/,"",rest)
      is_step=(fname ~ /-step-[0-9]+-/)?1:0
      product=""; task=""; best=0
      for (i=1;i<=np;i++) {
        pfx=P[i]"-"
        if (substr(rest,1,length(pfx))==pfx && length(P[i])>best) { product=P[i]; task=substr(rest,length(pfx)+1); best=length(P[i]) }
      }
      if (is_step) sub(/-step-[0-9]+-.*$/,"",task)
      status="-"; got=0
    }
    !got && /^(Status|상태):/ {
      line=$0; sub(/^(Status|상태):[[:space:]]*/,"",line)
      for (i=1;i<=nk;i++) if (index(line,KW[i])) { status=KW[i]; break }
      got=1
    }
    END { emit() }
  '
}

# task 완료 게이트 — 특정 task 의 unified + 모든 step 을 스캔해 미해결건을 라인별로 출력.
# 출력이 있으면(=미해결 존재) 완료(Done) 차단. 출력 0줄 = 게이트 통과.
#   working_gate_blockers <product> <작업명>
# 검사: 미머지 step(ReadyToMerge/Done 외) / step NeedsDecision / unified NeedsDecision / 미체크박스 / 잔여 섹션
working_gate_blockers() {
  local product="$1" taskname="$2"
  [ -n "$product" ] && [ -n "$taskname" ] || return 0
  local path date prod task st is_step
  working_scan "$product" | while IFS=$'\t' read -r path date prod task st is_step; do
    [ "$task" = "$taskname" ] || continue
    if [ "$is_step" = 1 ]; then
      case "$st" in
        ReadyToMerge|Done|완료) : ;;
        NeedsDecision) echo "판단 대기 step: $(basename "$path")" ;;
        *) echo "미처리 step: $(basename "$path") (상태=$st)" ;;
      esac
    else
      [ "$st" = "NeedsDecision" ] && echo "판단 미해결: NeedsDecision"
      grep -qE '^\s*- \[ \]' "$path" 2>/dev/null && echo "미체크박스 잔존: $(grep -cE '^\s*- \[ \]' "$path")건"
      grep -qE '^##[[:space:]]+(잔여|TODO|Follow-up)' "$path" 2>/dev/null && echo "잔여 섹션 존재"
    fi
  done
}
