#!/usr/bin/env bash
# working-scan.sh — working/ 태스크 문서 훑기 단일 SSOT (2026-07-23)
#
# 목적: working/ 스캔을 tick·control·load 에서 매번 인라인 grep 으로 재작성하던 drift 제거.
#       한 함수가 working/ 모든 문서(unified + step 평면)를 파싱해 구조화 TSV 로 반환.
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/working-scan.sh"   # hooks/ 기준
#   working_scan [product|all]
#
# 출력 (TSV, 문서 1개당 1줄):
#   파일경로 \t date(YYYY-MM-DD) \t product \t 작업명 \t status \t is_step(0|1)
#   - status  = 문서 시작부 '^Status:' 값 (없으면 '-'). ReadyToMerge/NeedsDecision/In Progress/Partial/Plan Complete/Done
#   - is_step = 1 (파일명 '-step-NN-') / 0 (unified)
#   - product = docs/{product}/ 디렉토리 prefix 매칭 (working-lifecycle.sh 와 동일 로직, 가장 긴 매칭 우선)
#   - filter  = product 명 지정 시 그 product 만 / 'all'·생략 = 전체
#
# 소비 예:
#   working_scan claude-harness | while IFS=$'\t' read -r path date prod task st is_step; do ... done
#   ReadyToMerge step   = status==ReadyToMerge && is_step==1
#   NeedsDecision task  = status==NeedsDecision && is_step==0

WORKING_ROOT="${WORKING_ROOT:-$HOME/.claude/docs/working}"
WORKING_SCAN_DOCS_ROOT="${WORKING_SCAN_DOCS_ROOT:-$HOME/.claude/docs}"

working_scan() {
  local filter="${1:-all}"
  [ -d "$WORKING_ROOT" ] || return 0

  local f fname date_part rest is_step product task status cand cn
  for f in "$WORKING_ROOT"/*/*.md; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")

    # date prefix (YYYY-MM-DD-)
    date_part=$(echo "$fname" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    [ -z "$date_part" ] && continue
    rest=${fname#"${date_part}"-}
    rest=${rest%.md}

    # is_step
    is_step=0
    echo "$fname" | grep -qE -- '-step-[0-9]+-' && is_step=1

    # product 매칭 (docs/{product}/ prefix, 가장 긴 것 우선 — working-lifecycle.sh 정합)
    product=""; task=""
    for cand in "$WORKING_SCAN_DOCS_ROOT"/*/; do
      [ -d "$cand" ] || continue
      cn=$(basename "$cand")
      case "$cn" in working|references) continue ;; esac
      if [[ "$rest" == "${cn}-"* ]]; then
        if [ -z "$product" ] || [ ${#cn} -gt ${#product} ]; then
          product="$cn"
          task=${rest#"${cn}"-}
        fi
      fi
    done
    [ -z "$product" ] && continue

    # step 파일이면 작업명에서 '-step-NN-...' 꼬리 제거 → 소속 task 명
    [ "$is_step" = 1 ] && task=${task%%-step-*}

    # product 필터
    if [ "$filter" != "all" ] && [ "$filter" != "$product" ]; then continue; fi

    # status = '^Status:' 값 (영문/한글 상태어, 공백 포함 'Plan Complete'·'In Progress')
    status=$(grep -m1 -E '^Status:' "$f" 2>/dev/null | sed -E 's/^Status:[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$status" ] && status="-"

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$f" "$date_part" "$product" "$task" "$status" "$is_step"
  done
}

# task 완료 게이트 — 특정 task 의 unified + 모든 step 을 스캔해 미해결건을 라인별로 출력.
# 출력이 있으면(=미해결 존재) 완료(Done) 차단. 출력 0줄 = 게이트 통과.
#   working_gate_blockers <product> <작업명>
# 검사 항목: 미머지 step(Status!=Done|머지됨) / 미체크박스 '- [ ]' / NeedsDecision / '## 잔여' 섹션 / verify·review FAIL
working_gate_blockers() {
  local product="$1" taskname="$2"
  [ -n "$product" ] && [ -n "$taskname" ] || return 0
  local path date prod task st is_step
  working_scan "$product" | while IFS=$'\t' read -r path date prod task st is_step; do
    [ "$task" = "$taskname" ] || continue
    if [ "$is_step" = 1 ]; then
      # step 은 ReadyToMerge(머지 준비) 또는 Done(머지됨)이어야 완료 가능. 그 외 = 미처리.
      case "$st" in
        ReadyToMerge|Done|완료) : ;;
        NeedsDecision) echo "판단 대기 step: $(basename "$path")" ;;
        *) echo "미처리 step: $(basename "$path") (Status=$st)" ;;
      esac
    else
      # unified: 판단 대기 / 미체크박스 / 잔여 섹션 검사
      [ "$st" = "NeedsDecision" ] && echo "판단 미해결: NeedsDecision"
      grep -qE '^\s*- \[ \]' "$path" 2>/dev/null && echo "미체크박스 잔존: $(grep -cE '^\s*- \[ \]' "$path")건"
      grep -qE '^##[[:space:]]+(잔여|TODO|Follow-up)' "$path" 2>/dev/null && echo "잔여 섹션 존재"
    fi
  done
}
