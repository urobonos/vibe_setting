#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "working-release" "enter" "pid=$$"
# working-release.sh — Stop hook 진입 시 본인 세션 active entry 를 status=paused 로 변경 + lock 정리
#
# SSOT: ~/.claude/docs/claude-harness/tasks/20260515/active-task-registry/2026-05-15-active-task-registry-unified.md
# 트리거: 세션 종료 시 (Claude Code Stop event)
#
# 동작:
#   1. REGISTRY 의 본 세션 entry (status=active) 전체 → status=paused
#   2. state/sessions/*/{본 sid}.lock 전체 제거 (slug 폴더 비면 rmdir)
#
# Done 자동 이동은 working-lifecycle.sh 가 별도 처리 — 본 hook 은 lifecycle 보조.

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/registry-utils.sh" 2>/dev/null || exit 0

STDIN_DATA=$(cat)

SESSION_ID=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', ''))
except:
    print('')
" 2>/dev/null)

[ -z "$SESSION_ID" ] && exit 0

SID8="${SESSION_ID:0:8}"

# REGISTRY 에서 본 세션 active entry 전부 → paused
ACTIVE_SLUGS=$(awk -v sid="$SID8" -F"$REGISTRY_FS" '
  /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $4 == sid && $7 == "active" { print $2 }
' "$REGISTRY_PATH" 2>/dev/null)

if [ -n "$ACTIVE_SLUGS" ]; then
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    registry_update "$slug" "$SID8" "paused" 2>/dev/null
    session_lock_remove "$slug" "$SID8" 2>/dev/null
  done <<<"$ACTIVE_SLUGS"
fi

# DISPATCH 본 세션 claim 태그 release (2026-06-15 — orphan claim 원천 차단)
#  기존 working-release 는 REGISTRY/session-lock 만 정리하고 DISPATCH claim 은 잔존시켜
#  세션 종료 후 orphan claim/lock 을 유발했다(다중 세션 race 의 근본 원인). dispatch_release_session
#  으로 본 sid claim 태그를 available 복귀 + dispatch lock 정리. ACTIVE_SLUGS 유무와 무관하게 실행.
source "$(dirname "${BASH_SOURCE[0]}")/lib/dispatch-utils.sh" 2>/dev/null \
  && dispatch_release_session "$SID8" >/dev/null 2>&1

exit 0
