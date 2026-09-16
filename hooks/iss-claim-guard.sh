#!/bin/bash
# PostToolUse: working 통합 문서를 쓸 때, 이 세션이 **후착인 ISS** 가 있으면 알린다.
#
# 차단하지 않는다 (exit 0). 선점 세션이 죽으면 그 번호가 영구 동결되는 사고가 이미 있었고
# (`env_registry-stale-lock-freezes-gate`), "그 ISS 의 파일이 어느 것인가" 는 판정이 안 선다
# — `BaseModel.php` 하나를 12개 ISS 가 공유한다. 그래서 파일 경로로 막는 대신 **선언 축**으로
# 알리고, 건너뛸지는 Claude 본체가 그 step 의 맥락을 보고 정한다.
#
# 발화 지점 = working 문서 Edit/Write. 그때가 step 진입 마킹 시점이라 착수 직전이다.
# SSOT: hooks/lib/iss-claim.sh + docs/claude-harness/tasks/20260916/iss-claim-arbitration/
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HOOK_DIR/lib/hook-input.sh" 2>/dev/null || exit 0
hook_read_stdin
hook_parse_session_id
hook_parse_file_path
[ -n "$FILE_PATH" ] || exit 0

# working/ 통합 문서만. step 평면 파일은 마스터의 부분집합이라 따로 보지 않는다.
case "${FILE_PATH//\\//}" in
  */.claude/docs/working/*) ;;
  *) exit 0 ;;
esac
case "${FILE_PATH##*/}" in
  *-step-*) exit 0 ;;
esac

SID8="${SESSION_ID:0:8}"
[ -n "$SID8" ] && [ "$SID8" != "default" ] || exit 0

# shellcheck source=/dev/null
source "$HOOK_DIR/lib/iss-claim.sh" 2>/dev/null || exit 0

OUT=$(iss_claim_conflicts_live "$SID8" all 2>/dev/null)
[ -n "$OUT" ] || exit 0

{
  echo "[ISS-CLAIM] 이 세션이 **후착**인 ISS 가 있습니다 — 선착 세션이 우선권을 갖습니다."
  while IFS=$'\t' read -r iss first started slug _others; do
    [ -n "$iss" ] || continue
    echo "  · $iss — 선착 $first ($slug) $started"
  done <<< "$OUT"
  echo "  조치: 해당 step 은 건너뜁니다 (상태 마킹하지 말고 Pending 유지). 선착이 끝내면 /taskflow:load 로 재진입."
  echo "  내 것이 맞다면 프론트매터 ISS: 에서 그 번호를 빼거나, 선착 세션과 범위를 나눈 뒤 다시 적습니다."
  echo "  SSOT: hooks/lib/iss-claim.sh (선언 축 = 프론트매터 ISS: · 선착 = REGISTRY started)"
} >&2

exit 0
