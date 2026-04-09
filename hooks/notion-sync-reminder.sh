#!/bin/bash
# PostToolUse Hook: CLAUDE.md / SKILL.md 수정 시 Notion 동기화 강제
# exit 2 차단 — 동기화 플래그 설정, Stop hook에서 검증

STDIN_DATA=$(cat)

FILE=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

if [ -z "$FILE" ]; then
  exit 0
fi

SESSION_ID=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('session_id', 'default'))
except:
    print('default')
" 2>/dev/null)

BASENAME=$(basename "$FILE")
LOWER_BASENAME=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]')
SYNC_FLAG="/tmp/claude_notion_sync_${SESSION_ID}"

# CLAUDE.md 수정 감지
if [[ "$LOWER_BASENAME" == "claude.md" ]]; then
  # 동기화 필요 플래그 설정
  if echo "$FILE" | grep -qE '\.claude/CLAUDE\.md|Users.*\.claude.*CLAUDE'; then
    echo "global_claude_md" >> "$SYNC_FLAG"
  else
    echo "project_claude_md" >> "$SYNC_FLAG"
  fi

  echo ""
  echo "━━━ Notion Sync Required ━━━"
  echo "[SYNC] CLAUDE.md가 수정되었습니다. 반드시 다음을 수행하세요:"
  if echo "$FILE" | grep -qE '\.claude/CLAUDE\.md|Users.*\.claude.*CLAUDE'; then
    echo "  → Notion 글로벌 지침 페이지 갱신"
  else
    echo "  → Notion \"홍카페_글로벌_백엔드\" (프로젝트 지침) 갱신"
  fi
  echo "  → docs/output/instructions-and-skills/ 요약 문서 갱신"
  echo "  절차: notion-fetch → 갱신 → replace_content 전체 교체"
  echo ""
  echo "  이 작업을 수행하지 않으면 세션 종료가 차단됩니다."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# SKILL.md 수정 감지 — Notion 동기화 불필요 (클로드코드_문서 페이지 제거됨)

exit 0
