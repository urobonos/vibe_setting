#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# working-stale-cleanup.sh — SessionStart hook 진입 시 잔여 자원 정리 (lock + 빈 worktree 폴더)
#
# SSOT: ~/.claude/docs/working/20260515/2026-05-15-claude-harness-active-task-registry.md
#
# 동작:
#   §A) stale lock 정리 (24h 초과)
#     1. state/sessions/**/*.lock 중 mtime > 24h 인 lock 파일 추출
#     2. 해당 lock 의 slug+sid 매칭 REGISTRY entry → status=stale 변경 (제거 X — 사용자 확인 후 결정)
#     3. lock 파일 자체는 제거 (slug 폴더 비면 rmdir)
#   §B) 빈 worktree 폴더 정리 (비파괴)
#     1. ~/.claude/worktrees/* 디렉토리 스캔
#     2. 비어있는 폴더만 rmdir (비어있지 않으면 자동 실패 = 안전 잠금)
#     3. Windows handle 일시 점유 시 자동 skip (다음 SessionStart 재시도)
#   §C) 정리 결과 stderr 1줄 보고 (각 영역 별)

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/registry-utils.sh" 2>/dev/null

STALE_HOURS="${STALE_HOURS:-24}"

# §A) stale lock 정리
CLEANED=0
if [ -d "${SESSIONS_DIR:-}" ]; then
  STALE_LOCKS=$(session_lock_list_stale 2>/dev/null)
  if [ -n "$STALE_LOCKS" ]; then
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
  fi
fi

if [ "$CLEANED" -gt 0 ]; then
  echo "[working-stale-cleanup] ${CLEANED}건 stale lock 정리 (>${STALE_HOURS}h) — REGISTRY status=stale" >&2
fi

# §B) 빈 worktree 폴더 정리 (비파괴 — 비어있지 않으면 rmdir 자동 실패)
WORKTREES_DIR="${HOME}/.claude/worktrees"
WT_CLEANED=0
if [ -d "$WORKTREES_DIR" ]; then
  for wt_dir in "$WORKTREES_DIR"/*/; do
    [ -d "$wt_dir" ] || continue
    if [ -z "$(ls -A "$wt_dir" 2>/dev/null)" ]; then
      if rmdir "$wt_dir" 2>/dev/null; then
        WT_CLEANED=$((WT_CLEANED + 1))
      fi
    fi
  done
fi

if [ "$WT_CLEANED" -gt 0 ]; then
  echo "[working-stale-cleanup] ${WT_CLEANED}건 빈 worktree 폴더 정리" >&2
fi

exit 0
