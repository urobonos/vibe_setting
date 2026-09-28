#!/usr/bin/env bash
# /taskflow:load ① 잔존 작업 스캔 — load.md 본문 bash 블록을 실행물로 옮긴 것 (2026-09-28).
# 모델이 매번 본문을 옮겨 적으며 글롭·치환을 다시 조립하던 절차라 결정적 부분만 여기 둔다.
#
#   bash load-scan.sh [인자]     인자 = "" | all | latest | {작업명} | {product}  ($ARGUMENTS 그대로)
#
# 출력 태그: [대상] 경로 · [잔여 섹션 없음] · [step 잔여] · [타 product 잔존] · [CLEAN] ·
#           [backlog 잔존…] · [분배 available] · [타 product 분배] · [분배 풀] · [REGISTRY] · MODE:
# 부작용 = 금일 이전 빈 날짜 폴더 rmdir 뿐이다.
HARNESS_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/lib" 2>/dev/null && pwd)"
[ -f "$HARNESS_LIB/product-resolver.sh" ] || HARNESS_LIB="$HOME/.claude/hooks/lib"
PLUGIN_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks/lib" && pwd)"

WORKING_DIR="$HOME/.claude/docs/working"
# 스캔 루트 — 날짜 폴더(YYYYMMDD)만. working/dispatch/ 등 비-날짜 폴더는 잔여 스캔 대상이 아니다
WORKING_GLOB="$WORKING_DIR/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"
BACKLOG_DIR="$WORKING_DIR/backlog"
DATE_RE='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'

# product 식별 — cwd 기준 (worktree 안 호출 시 원본 repo 역해석)
source "$HARNESS_LIB/product-resolver.sh"
CURRENT_PRODUCT=$(resolve_product "$PWD")

ARG="$1"
case "$ARG" in
  ""|"all") TARGET_PRODUCT=""; MODE=all ;;      # 인자 없음 = 전체 (2026-06-18 cwd 필터 기본 해제)
  "latest") TARGET_PRODUCT="$CURRENT_PRODUCT"; MODE=latest ;;
  *)
    # 작업명 모드 판정 — 날짜 폴더 파일 또는 backlog slug 가 인자와 **전문 일치**할 때만.
    # backlog glob 은 slug 를 날짜 바로 뒤에 앵커링한다: `*-${ARG}.md` 는 ARG 가 slug 접미사에만
    # 걸려도 매칭돼 product 명 `infra` 가 `{date}-ses-email-infra.md` 에 먹혔다(콜드리뷰 R5 M1).
    # `--*` 형은 이관 때 slug 충돌로 `{date}-{slug}--{product}.md` 를 받은 8건용이다(2026-08-07 H3).
    if compgen -G "$WORKING_GLOB/*-${ARG}.md" >/dev/null 2>&1 \
      || compgen -G "$BACKLOG_DIR/${DATE_RE}-${ARG}.md" >/dev/null 2>&1 \
      || compgen -G "$BACKLOG_DIR/${DATE_RE}-${ARG}--*.md" >/dev/null 2>&1; then
      TARGET_PRODUCT=""; MODE=task
    else
      TARGET_PRODUCT="$ARG"; MODE=product
    fi
    ;;
esac
echo "MODE:$MODE product=${TARGET_PRODUCT:-*} current=$CURRENT_PRODUCT"

# REGISTRY — status=active 전체 (본인 sid 가 아니면 다른 세션 점유)
source "$HARNESS_LIB/registry-utils.sh"
registry_list_active | sed 's/^/[REGISTRY] /'

in_product() {   # $1 = 파일 경로, $2 = product (빈 값 = 전체)
  [ -z "$2" ] && return 0
  basename "$1" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-$2-"
}
residual_in_section() {   # ## 잔여 작업 섹션 안 미체크 수
  awk '/^## 잔여 작업/{fl=1;next} /^## /{fl=0} fl&&/^- \[ \]/{c++} END{print c+0}' "$1"
}

# 그룹 A = `## 잔여 작업` 섹션 보유 + 그 안에 미체크 ≥1 → 상세 대상
# 그룹 B = 섹션 미보유 + 문서 전체 미체크 ≥1 → 잔여인지 모르는 상태라 보강 권고만 (2026-09-07 결정).
#   B 의 step 평면 파일(`-step-`)은 대개 step 자체 체크리스트라 건수로 접는다 (실측 B 61건 중 43건)
other_count=0; b_step=0; b_rows=0
for f in $WORKING_GLOB/*.md; do
  [ -f "$f" ] || continue
  if grep -qE '^## 잔여 작업' "$f"; then
    n=$(residual_in_section "$f"); [ "$n" -gt 0 ] || continue
    if in_product "$f" "$TARGET_PRODUCT"; then
      echo "[대상] $f | 잔여 $n | $(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    elif [ "$MODE" = latest ]; then
      other_count=$((other_count+1))
    fi
  else
    in_product "$f" "$TARGET_PRODUCT" || continue
    n=$(grep -cE '^- \[ \]' "$f"); [ "$n" -gt 0 ] || continue
    case "$(basename "$f")" in
      *-step-*) b_step=$((b_step+1)) ;;
      *) b_rows=$((b_rows+1))
         [ "$b_rows" -le 8 ] && echo "[잔여 섹션 없음] $(basename "$f") — 미체크 ${n}건 · \`## 잔여 작업\` 섹션 보강 후 재확인 권장" ;;
    esac
  fi
done
[ "$b_rows" -gt 8 ] && echo "[잔여 섹션 없음] 그 외 $((b_rows-8))건"
[ "$b_step" -gt 0 ] && echo "[step 잔여] step 파일 ${b_step}건 — 대부분 step 체크리스트, 필요 시 개별 확인"
[ "$MODE" = latest ] && echo "[타 product 잔존] ${other_count} 건 — '/taskflow:load all' 또는 '/taskflow:load {product}' 로 조회"

# 금일 이전 빈 날짜 폴더 정리 (working/ → tasks/ 이동 후 남은 빈 껍데기)
TODAY=$(date +%Y%m%d)
for dir in "$WORKING_DIR"/*/; do
  base=$(basename "$dir")
  [[ "$base" =~ ^[0-9]{8}$ ]] || continue
  [ "$base" -ge "$TODAY" ] && continue
  compgen -G "$dir*.md" >/dev/null 2>&1 && continue
  rmdir "$dir" 2>/dev/null && echo "[CLEAN] removed empty working folder: $base"
done

# backlog 잔존 — status: done 이 아닌 문서 (product 무분리).
# done 판정은 frontmatter 범위로만 한다 — 본문 예시의 `status: done` 에 반응하면 hook 의
# has_done_marker() 와 갈라져 pending 문서가 조용히 사라진다(콜드리뷰 H2). 전체를 awk 1패스로 도는 건
# 298건 이관 뒤 파일당 6프로세스 스캔이 124초 걸렸기 때문이다. BEGINFILE/ENDFILE 은 0바이트 파일도
# 순회에 넣는다(FNR==1 리셋은 빈 파일을 놓쳤다, R2 M4). name/description 표시만 앞 20줄에서 관대하게
# 찾는다(R2 M5) — done 판정 규칙과는 분리돼 있다.
# 정상 항목만 8건 상한, 이동불가·이동실패는 이상 신호라 전부 낸다.
if [ -d "$BACKLOG_DIR" ] && compgen -G "$BACKLOG_DIR/*.md" >/dev/null 2>&1; then
  BACKLOG_AWK_OUT=$(awk '
    function emit() {
      if (base == "") return
      if (!valid_name) { printf "[backlog 잔존·이동불가] %s — 파일명 형식 불일치({yyyy-mm-dd}-{slug}.md 필요), 자동 이동 안 됨 — 수동 rename 필요\n", base; cnt++; return }
      if (is_done && closed) { printf "[backlog 잔존·이동실패] %s | %s — status:done 인데 아직 working/backlog/ 에 있음(원인: mv 실패·비도구 쓰기·PostToolUse 미발화·product 디렉토리 미실재로 스킵 등), 원인 확인 필요\n", (name!=""?name:base), base; cnt++; return }
      cnt++; normal_cnt++
      if (normal_cnt <= 8) printf "[backlog 잔존] %s | %s | %s\n", (name!=""?name:base), (desc!=""?desc:"(설명 없음)"), base
    }
    BEGINFILE {
      n=split(FILENAME, pp, "/"); base=pp[n]
      valid_name = (base ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-.+\.md$/) ? 1 : 0
      infm=0; closed=0; is_done=0; name=""; desc=""
    }
    $0 ~ /^---[[:space:]]*$/ && FNR==1 { infm=1; next }
    infm && /^---[[:space:]]*$/ { infm=0; closed=1; next }
    infm { l=tolower($0); if (l ~ /^[[:space:]]*status:[[:space:]]*done[[:space:]]*$/) is_done=1 }
    FNR<=20 && name=="" && /^[[:space:]]*name:/ { line=$0; sub(/^[[:space:]]*name:[[:space:]]*/,"",line); name=line; next }
    FNR<=20 && desc=="" && /^[[:space:]]*description:/ { line=$0; sub(/^[[:space:]]*description:[[:space:]]*/,"",line); gsub(/^"/,"",line); gsub(/"$/,"",line); desc=line; next }
    ENDFILE { emit() }
    END {
      if (normal_cnt > 8) printf "[backlog 잔존] 그 외 %d건 더 (상세는 각 파일 직접 열람)\n", normal_cnt-8
      printf "CNT:%d\n", cnt
    }
  ' "$BACKLOG_DIR"/*.md)
  echo "$BACKLOG_AWK_OUT" | grep -v '^CNT:'
  BACKLOG_CNT=$(echo "$BACKLOG_AWK_OUT" | sed -n 's/^CNT://p')
  [ "${BACKLOG_CNT:-0}" -gt 0 ] && echo "[backlog 잔존] 총 ${BACKLOG_CNT}건 (product 무분리 · status: done 제외 + 이동불가/이동실패는 done 무관 항상 포함) — 상세는 각 파일 직접 열람"
fi

# DISPATCH 분배 풀 — 목록 조회만 (claim 은 #tag 분기). product = 표 4번째 컬럼
source "$PLUGIN_LIB/dispatch-utils.sh"
dispatch_list available | awk -F"$DISPATCH_FS" -v p="$TARGET_PRODUCT" '
  $2=="tag" || $2=="" { next }
  (p=="" || $4==p) { printf "[분배 available] #%s | %s | %s\n", $2, $3, $4; next }
  { other++ }
  END { if (other) printf "[타 product 분배] %d 건 — /taskflow:load all 로 조회\n", other }
'
CLAIMED_CNT=$(dispatch_list claimed | grep -cE '^\|')
[ "${CLAIMED_CNT:-0}" -gt 0 ] && echo "[분배 풀] claimed(점유 중) ${CLAIMED_CNT} 건 — 상세는 /taskflow:load #tag"
exit 0
