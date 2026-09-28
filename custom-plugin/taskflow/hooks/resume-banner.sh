#!/bin/bash
# 공유 lib 는 하니스 hooks/lib 에 있다. 스크립트 위치 기준으로 찾아 $HOME 을 바꾼 테스트에서도
# 같은 파일을 쓰고, 플러그인이 캐시 사본으로 로드돼 상대경로가 없으면 $HOME 으로 되돌아간다
HARNESS_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/lib" 2>/dev/null && pwd)"
[ -f "$HARNESS_LIB/hook-input.sh" ] || HARNESS_LIB="$HOME/.claude/hooks/lib"
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$HARNESS_LIB/log-helper.sh" 2>/dev/null && log_event "resume-banner" "enter" "pid=$$"
# SessionStart Hook (taskflow 플러그인): cwd product 의 working/ 잔존 작업 재개 추천.
# 2026-09-28 hooks/agent-first-banner.sh 에서 분리 — 하니스 공통 배너와 플러그인 기능을 가른다.

# ===== cwd 작업 재개 추천 (2026-07-23) =====
# 현재 cwd product 의 working/ 대기 큐를 working-scan 으로 훑어 우선순위(판단>머지 준비>진행)로 1블록 추천.
# ReadyToMerge 는 step 단위(working 문서)라 REGISTRY 가 아닌 working_scan 이 SSOT — /taskflow:control 의 요약판.
# 잔존 0건이면 아무것도 출력하지 않는다 (노이즈 0 — §4.4 "가역은 사후 가시화").
# SSOT: hooks/lib/working-scan.sh (하니스 공유 lib)
{
  HOOK_DIR="$HARNESS_LIB"   # 하니스 공유 lib
  # shellcheck disable=SC1091
  if source "$HOOK_DIR/product-resolver.sh" 2>/dev/null \
     && source "$HOOK_DIR/working-scan.sh" 2>/dev/null; then
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
            ND) echo "  ⚠️ 판단 필요: $list → /taskflow:load (판단사항 확인 후 결정)" ;;
            RM) echo "  ✅ 머지 준비 step: $list → /taskflow:save (step 머지)" ;;
            IP) echo "  ▶ 진행 중: $list → /taskflow:load latest (이어서)" ;;
          esac
        done
        echo "  (신규 = /taskflow:analyze {작업})"
      fi
    fi
  fi
} 2>/dev/null

exit 0
