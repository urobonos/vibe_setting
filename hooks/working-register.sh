#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# working-register.sh — PreToolUse Edit/Write working/*.md 진입 시 REGISTRY entry 등록 + lock 생성
#
# SSOT: ~/.claude/docs/working/20260515/2026-05-15-claude-harness-active-task-registry.md
# 짝 hook: working-heartbeat.sh (PostToolUse) / working-release.sh (Stop) / working-stale-cleanup.sh (SessionStart)
#
# 충돌 정책: 동일 slug 다른 session_id 점유 시 stderr 경고 (exit 0, 차단 X — 사용자 결정 우선)

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/registry-utils.sh" 2>/dev/null || exit 0
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null || exit 0

STDIN_DATA=$(cat)

PARSED=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('hook_event_name', '') != 'PreToolUse':
        sys.exit(0)
    tool = d.get('tool_name', '')
    if tool not in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'):
        sys.exit(0)
    fp = d.get('tool_input', {}).get('file_path', '')
    sid = d.get('session_id', '')
    cwd = d.get('cwd', '')
    print(fp + '|' + sid + '|' + cwd)
except SystemExit:
    raise
except:
    pass
" 2>/dev/null)

[ -z "$PARSED" ] && exit 0

FILE_PATH="${PARSED%%|*}"
REST="${PARSED#*|}"
SESSION_ID="${REST%%|*}"
CWD="${REST#*|}"

[ -z "$FILE_PATH" ] && exit 0
[ -z "$SESSION_ID" ] && exit 0

# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH_NORM=$(normalize_path "$FILE_PATH")
echo "$FILE_PATH_NORM" | grep -qE '/docs/working/[0-9]{8}/[^/]+\.md$' || exit 0

FILENAME=$(basename "$FILE_PATH_NORM")
DATE_PART=$(echo "$FILENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
[ -z "$DATE_PART" ] && exit 0

REST_NAME=${FILENAME#${DATE_PART}-}
REST_NAME=${REST_NAME%.md}

# product 매칭 (working-lifecycle.sh 와 동일 로직)
PRODUCT=""
SLUG=""
DOCS_ROOT="$HOME/.claude/docs"
for candidate in "$DOCS_ROOT"/*/; do
  [ -d "$candidate" ] || continue
  CAND_NAME=$(basename "$candidate")
  case "$CAND_NAME" in
    working|references) continue ;;
  esac
  if [[ "$REST_NAME" == "${CAND_NAME}-"* ]]; then
    if [ -z "$PRODUCT" ] || [ ${#CAND_NAME} -gt ${#PRODUCT} ]; then
      PRODUCT="$CAND_NAME"
      SLUG=${REST_NAME#${CAND_NAME}-}
    fi
  fi
done

[ -z "$SLUG" ] && exit 0
[ -z "$PRODUCT" ] && PRODUCT="claude-harness"

SID8="${SESSION_ID:0:8}"

# 충돌 감지 — 동일 slug 다른 sid 점유 시 경고
EXISTING=$(registry_find "$SLUG")
if [ -n "$EXISTING" ]; then
  while IFS= read -r line; do
    OTHER_SID=$(echo "$line" | awk -F"$REGISTRY_FS" '{print $4}')
    OTHER_STATUS=$(echo "$line" | awk -F"$REGISTRY_FS" '{print $7}')
    if [ -n "$OTHER_SID" ] && [ "$OTHER_SID" != "$SID8" ] && [ "$OTHER_STATUS" = "active" ]; then
      echo "[working-register] ⚠ 동일 slug '$SLUG' 다른 세션 점유: $OTHER_SID (status=$OTHER_STATUS)" >&2
      echo "                  본 세션 ($SID8) 도 active 등록 — 동시 편집 충돌 주의" >&2
    fi
  done <<<"$EXISTING"
fi

registry_add "$SLUG" "$PRODUCT" "$SID8" "$CWD" "$FILE_PATH_NORM" 2>/dev/null
session_lock_create "$SLUG" "$SID8" 2>/dev/null

exit 0
