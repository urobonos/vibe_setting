#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "working-heartbeat" "enter" "pid=$$"
# working-heartbeat.sh — PostToolUse Edit/Write working/*.md 직후 last_update 갱신 + lock mtime touch
#
# SSOT: ~/.claude/docs/claude-harness/tasks/20260515/active-task-registry/2026-05-15-active-task-registry-unified.md
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

# step 평면 파일은 마스터 작업의 파생 실행 단위 — 별도 last_update/lock touch 금지 (보완형 step 정책, 2026-05-29)
# (register.sh 와 동일 가드 — step 은 registry 미등록이므로 heartbeat 도 대상 아님)
echo "$FILE_PATH_NORM" | grep -qE -- '-step-[0-9]+-[^/]*\.md$' && exit 0

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

# 작성 정보 박스 점유 세션(sid)·점유 시작 자동 주입 (2026-06-09 사용자 결정)
# working/ unified 문서 작성 정보 표의 placeholder/기존값을 REGISTRY 의 sid8·started 로 치환.
# idempotent — 현재값과 동일하면 미기입 (Claude file-tracking 마찰 회피).
# 행 없는 구 문서는 skip (역소급 면제). SSOT: unified-template.md 작성 정보 placeholder + CLAUDE.md.
TARGET="$FILE_PATH_NORM"; [ -f "$TARGET" ] || TARGET="$FILE_PATH"
if [ -f "$TARGET" ] && grep -qE '^\|[[:space:]]*점유 세션' "$TARGET"; then
  STARTED=$(registry_find "$SLUG" | awk -F"$REGISTRY_FS" -v sid="$SID8" '$4==sid {print $5; exit}')
  if [ -n "$STARTED" ]; then
    CUR_SID=$(awk -F'\\|' '/^\|[[:space:]]*점유 세션/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3);print $3;exit}' "$TARGET")
    CUR_ST=$(awk -F'\\|' '/^\|[[:space:]]*점유 시작/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3);print $3;exit}' "$TARGET")
    if [ "$CUR_SID" != "$SID8" ] || [ "$CUR_ST" != "$STARTED" ]; then
      sed -i -E \
        -e "s#^(\|[[:space:]]*점유 세션[^|]*\|)[^|]*\|[[:space:]]*\$#\1 ${SID8} |#" \
        -e "s#^(\|[[:space:]]*점유 시작[^|]*\|)[^|]*\|[[:space:]]*\$#\1 ${STARTED} |#" \
        "$TARGET" 2>/dev/null
    fi
  fi
fi

exit 0
