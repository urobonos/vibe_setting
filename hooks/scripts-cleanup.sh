#!/usr/bin/env bash
# scripts-cleanup.sh — SessionStart hook (2026-05-20 도입)
#
# 정책: 사용자 직접 실행 명령 스크립트화 (CLAUDE.md §4.2) 의 GC.
#   `~/.claude/docs/scripts/*.sh` 중 mtime > 7일 자동 삭제.
#
# Why: §3 비가역 명령마다 스크립트 파일 누적 → 무한 증가 방지.
#   본 hook = 차단 X (exit 0), GC 전용. SessionStart 발동.
#
# SSOT: CLAUDE.md §4.2 "사용자 직접 실행 명령 스크립트화"

set -uo pipefail

SCRIPTS_DIR="$HOME/.claude/docs/scripts"

# 폴더 미실재 시 SKIP (최초 호출 전 정상)
[ -d "$SCRIPTS_DIR" ] || exit 0

DELETED=$(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name '*.sh' -mtime +7 -print -delete 2>/dev/null | wc -l)

if [ "$DELETED" -gt 0 ]; then
  echo "[scripts-cleanup] $DELETED 개 명령 스크립트 GC (mtime > 7일)" >&2
fi

exit 0
