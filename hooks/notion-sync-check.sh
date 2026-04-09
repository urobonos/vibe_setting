#!/bin/bash
# Stop Hook: Notion 동기화 미완료 시 세션 종료 차단
# notion-sync-reminder.sh에서 설정한 플래그 기반 검증

STDIN_DATA=$(cat)

SESSION_ID=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('session_id', 'default'))
except:
    print('default')
" 2>/dev/null)

SYNC_FLAG="/tmp/claude_notion_sync_${SESSION_ID}"

# 동기화 플래그 없으면 통과 (수정 없었음)
if [ ! -f "$SYNC_FLAG" ]; then
  exit 0
fi

# 동기화 완료 마커 확인
DONE_FLAG="/tmp/claude_notion_done_${SESSION_ID}"
if [ -f "$DONE_FLAG" ]; then
  exit 0
fi

# 미완료 항목 수집
PENDING=$(sort -u "$SYNC_FLAG" 2>/dev/null)
if [ -n "$PENDING" ]; then
  echo "" >&2
  echo "━━━ Notion Sync 미완료 — 종료 차단 ━━━" >&2
  echo "[BLOCKED] 이번 세션에서 지침/스킬 파일을 수정했지만 Notion 동기화가 완료되지 않았습니다." >&2
  echo "" >&2
  echo "$PENDING" | while read -r item; do
    case "$item" in
      global_claude_md) echo "  - 글로벌 CLAUDE.md → Notion 글로벌 지침 페이지 갱신 필요" >&2 ;;
      project_claude_md) echo "  - 프로젝트 CLAUDE.md → Notion \"홍카페_글로벌_백엔드\" 갱신 필요" >&2 ;;
      skill_md) ;; # 클로드코드_문서 페이지 제거됨 — skip
    esac
  done
  echo "" >&2
  echo "Notion 동기화 완료 후 다시 종료하세요." >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  exit 2
fi

exit 0
