#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "working-heartbeat" "enter" "pid=$$"
# working-heartbeat.sh — PostToolUse Edit/Write working/*.md 직후 last_update 갱신 + lock mtime touch
#
# SSOT: ~/.claude/docs/working/20260515/2026-05-15-claude-harness-active-task-registry.md
# 짝 hook: working-register.sh (PreToolUse) / working-release.sh (Stop)

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/registry-utils.sh" 2>/dev/null || exit 0
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null || exit 0

STDIN_DATA=$(cat)

PARSED=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('hook_event_name', '') != 'PostToolUse':
        sys.exit(0)
    tool = d.get('tool_name', '')
    if tool not in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'):
        sys.exit(0)
    fp = d.get('tool_response', {}).get('filePath', '') if isinstance(d.get('tool_response'), dict) else ''
    if not fp:
        fp = d.get('tool_input', {}).get('file_path', '')
    sid = d.get('session_id', '')
    print(fp + '|' + sid)
except SystemExit:
    raise
except:
    pass
" 2>/dev/null)

[ -z "$PARSED" ] && exit 0

FILE_PATH="${PARSED%%|*}"
SESSION_ID="${PARSED#*|}"

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

SLUG=""
DOCS_ROOT="$HOME/.claude/docs"
for candidate in "$DOCS_ROOT"/*/; do
  [ -d "$candidate" ] || continue
  CAND_NAME=$(basename "$candidate")
  case "$CAND_NAME" in
    working|references) continue ;;
  esac
  if [[ "$REST_NAME" == "${CAND_NAME}-"* ]]; then
    if [ -z "$SLUG" ] || [ ${#CAND_NAME} -gt ${#SLUG} ]; then
      SLUG=${REST_NAME#${CAND_NAME}-}
    fi
  fi
done

[ -z "$SLUG" ] && exit 0

SID8="${SESSION_ID:0:8}"

registry_update "$SLUG" "$SID8" "active" 2>/dev/null
session_lock_touch "$SLUG" "$SID8" 2>/dev/null

exit 0
