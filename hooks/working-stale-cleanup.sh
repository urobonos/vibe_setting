#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# working-stale-cleanup.sh — SessionStart hook 진입 시 24h 초과 stale lock + REGISTRY entry 정리
#
# SSOT: ~/.claude/docs/working/20260515/2026-05-15-claude-harness-active-task-registry.md
#
# 동작:
#   1. state/sessions/**/*.lock 중 mtime > 24h 인 lock 파일 추출
#   2. 해당 lock 의 slug+sid 매칭 REGISTRY entry → status=stale 변경 (제거 X — 사용자 확인 후 결정)
#   3. lock 파일 자체는 제거 (slug 폴더 비면 rmdir)
#   4. 정리 결과 stderr 1줄 보고

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/registry-utils.sh" 2>/dev/null || exit 0

STALE_HOURS="${STALE_HOURS:-24}"

[ -d "$SESSIONS_DIR" ] || exit 0

CLEANED=0
STALE_LOCKS=$(session_lock_list_stale 2>/dev/null)
[ -z "$STALE_LOCKS" ] && exit 0

while IFS= read -r lock_file; do
  [ -z "$lock_file" ] && continue
  [ -f "$lock_file" ] || continue

  # path: $SESSIONS_DIR/{slug}/{sid}.lock
  base=$(basename "$lock_file" .lock)
  slug_dir=$(dirname "$lock_file")
  slug=$(basename "$slug_dir")

  registry_mark_stale "$slug" "$base" 2>/dev/null
  rm -f "$lock_file" 2>/dev/null
  rmdir "$slug_dir" 2>/dev/null || true
  CLEANED=$((CLEANED + 1))
done <<<"$STALE_LOCKS"

if [ "$CLEANED" -gt 0 ]; then
  echo "[working-stale-cleanup] ${CLEANED}건 stale lock 정리 (>${STALE_HOURS}h) — REGISTRY status=stale" >&2
fi

exit 0
