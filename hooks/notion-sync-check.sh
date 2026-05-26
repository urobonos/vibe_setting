#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "notion-sync-check" "enter" "pid=$$"
# Stop Hook: Notion 동기화 검증 (요청 기반, 2026-04-22~)
#
# 정책: 사용자가 명시적으로 Notion 동기화를 요청한 경우에만 REQUEST_FLAG가 세팅된다.
# 자동 세팅되던 SYNC_FLAG는 doc-quality.sh에서 제거됨.
# REQUEST_FLAG가 없으면 항상 통과.

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_session_id

REQUEST_FLAG="/tmp/claude_notion_request_${SESSION_ID}"
DONE_FLAG="/tmp/claude_notion_done_${SESSION_ID}"

# 사용자 명시 요청이 없으면 통과
if [ ! -f "$REQUEST_FLAG" ]; then
  exit 0
fi

# 요청된 동기화 완료 마커 있으면 통과
if [ -f "$DONE_FLAG" ]; then
  exit 0
fi

# 사용자 요청 Notion 동기화가 미완료인 경우에만 차단
PENDING=$(sort -u "$REQUEST_FLAG" 2>/dev/null)
if [ -n "$PENDING" ]; then
  echo "" >&2
  echo "━━━ Notion Sync 요청 미완료 — 종료 차단 ━━━" >&2
  echo "[BLOCKED] 사용자가 요청한 Notion 동기화가 완료되지 않았습니다." >&2
  echo "" >&2
  echo "$PENDING" | while read -r item; do
    echo "  - $item" >&2
  done
  echo "" >&2
  echo "동기화 완료 후 /tmp/claude_notion_done_${SESSION_ID} 마커 파일을 생성하거나" >&2
  echo "/tmp/claude_notion_request_${SESSION_ID} 를 삭제하세요." >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  exit 2
fi

exit 0
