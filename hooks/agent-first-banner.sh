#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "agent-first-banner" "enter" "pid=$$"
# SessionStart Hook: Agent-First Default 배너 출력
# CLAUDE.md §4 "에이전트 우선 위임" + orchestration §0 "Agent-First Default" SSOT.
# 본 세션의 default 동작이 "Agent 도구 우선 위임" 임을 매 세션 시작 시 상기시킨다.

cat <<'BANNER'
[페르소나 — 안드레이 카파시] 사고방식 + 응답 스타일 둘 다 카파시. 사고 = 원리로 되묻기 · 단순성 우선(복잡성=부채) · 재사용 먼저 · "돌려봐야 검증". 응답 = 결론 먼저 · 짧은 단락 1~3줄 · 도입부 0 · 사족 0 · 표/헤더는 실제 대조·열거 때만(1~2줄 설명은 산문으로 끝낸다). 정중(존댓말)만 §4.4 유지 — "카파시식으로" 류 라벨·접두어 일절 금지(0회).
[Agent-First Default] 본 세션 default = Agent 도구·팀 스킬 우선 위임.
  • 탐색 3쿼리+ → Explore / 다파일 분석 → Team 1 / API 작업 → hongcafe:api-team / 의견 갈림 → /taskflow:debate
  • 병렬 spawn = 효율 상한까지 제안 (독립 태스크 min(16,cores−2), SSOT orchestration §2.3)
  • 직접 작업 허용 = 단일 파일 trivial 수정·단발성 조회 1회만 (사유 1줄 보고)
  • 보고 = 결론 + 표/diff 만, 사족 제거 — 상세는 질문 시 (CLAUDE.md §4 "응답 간결")
  • 상세: CLAUDE.md §4 "에이전트 우선 위임", skills/orchestration §0 "Agent-First Default"
BANNER

# ===== cwd 작업 재개 추천 (2026-07-23) =====
# 현재 cwd product 의 working/ 대기 큐를 working-scan 으로 훑어 우선순위(판단>머지 준비>진행)로 1블록 추천.
# ReadyToMerge 는 step 단위(working 문서)라 REGISTRY 가 아닌 working_scan 이 SSOT — /taskflow:control 의 요약판.
# 잔존 0건이면 아무것도 출력하지 않는다 (노이즈 0 — §4.4 "가역은 사후 가시화").
# SSOT: hooks/lib/working-scan.sh + custom-plugin/taskflow/commands/{control,tick}.md
{
  HOOK_DIR="$(dirname "${BASH_SOURCE[0]}")"
  # shellcheck disable=SC1091
  if source "$HOOK_DIR/lib/product-resolver.sh" 2>/dev/null \
     && source "$HOOK_DIR/lib/working-scan.sh" 2>/dev/null; then
    # cwd = SessionStart stdin JSON 우선, 없으면 $PWD
    STDIN_DATA=$(cat 2>/dev/null)
    CWD=""
    [[ "$STDIN_DATA" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && CWD="${BASH_REMATCH[1]}"
    [ -z "$CWD" ] && CWD="$PWD"
    PRODUCT=$(resolve_product "$CWD")
    if [ -n "$PRODUCT" ]; then
      # working_scan TSV(경로·date·product·작업명·status·is_step) → task별 상태 집계
      REC=$(working_scan "$PRODUCT" 2>/dev/null | awk -F'\t' '
        $6==0 && $5=="NeedsDecision"                    { nd[$4]=1 }
        $6==1 && $5=="ReadyToMerge"                     { rm[$4]++ }
        $6==0 && ($5=="In Progress" || $5=="Partial")   { ip[$4]=1 }
        END {
          ndl=""; for (t in nd) ndl=ndl (ndl?", ":"") t
          rml=""; for (t in rm) rml=rml (rml?", ":"") t "(" rm[t] " step)"
          ipl=""; for (t in ip) if (!(t in nd)) ipl=ipl (ipl?", ":"") t
          if (ndl) print "ND\t" ndl
          if (rml) print "RM\t" rml
          if (ipl) print "IP\t" ipl
        }')
      if [ -n "$REC" ]; then
        echo "[작업 재개 — cwd product=$PRODUCT]"
        printf '%s\n' "$REC" | while IFS=$'\t' read -r tag list; do
          case "$tag" in
            ND) echo "  ⚠️ 판단 필요: $list → /taskflow:control (판단사항 확인 후 결정)" ;;
            RM) echo "  ✅ 머지 준비 step: $list → /taskflow:control → /taskflow:save (step 머지)" ;;
            IP) echo "  ▶ 진행 중: $list → /taskflow:load latest (이어서)" ;;
          esac
        done
        echo "  (신규 = /taskflow:analyze {작업} · 무인 = /loop 30m /taskflow:tick · 대기 큐 = /taskflow:control)"
      fi
    fi
  fi
} 2>/dev/null

exit 0
