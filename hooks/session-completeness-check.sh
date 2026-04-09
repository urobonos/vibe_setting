#!/bin/bash
# Stop Hook: 세션 종료 시 산출물 누락 검증
# exit 2 차단 — 산출물 미완성 시 세션 종료 차단
#
# 검증 항목:
#   1. Edit/Write 이력 있는 세션 → history.md + YYYYMMDD.md 기록 필수
#   2. gate>=2(실행 단계) → analyze.md 존재 필수
#   3. gate>=2 + analyze.md 있으면 → result.md 존재 필수

STDIN_DATA=$(cat)

eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', 'default')
    cwd = data.get('cwd', '.')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'CWD=\"{cwd}\"')
except:
    print('SESSION_ID=\"default\"')
    print('CWD=\".\"')
" 2>/dev/null)"

TODAY=$(date +%Y%m%d)
TODAY_DOT=$(date +%Y.%m.%d)
BLOCKED=false
WARNINGS=""

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"
CURRENT=$(cat "$GATE_FILE" 2>/dev/null || echo "0")
EDIT_FLAG="/tmp/claude_edit_flag_${SESSION_ID}"

# --- 1. work-history 기록 여부 (Edit/Write 이력 + work-history 디렉토리 있는 프로젝트만) ---
if [ -f "$EDIT_FLAG" ]; then
  HISTORY_DIR="$CWD/docs/work-history"
  if [ -d "$HISTORY_DIR" ]; then
    HISTORY_FILE="$HISTORY_DIR/history.md"
    DAILY_FILE="$HISTORY_DIR/${TODAY}.md"

    # history.md 오늘 날짜 항목 검사
    if [ ! -f "$HISTORY_FILE" ] || ! grep -q "$TODAY_DOT" "$HISTORY_FILE" 2>/dev/null; then
      WARNINGS="${WARNINGS}\n[BLOCKED] docs/work-history/history.md에 오늘($TODAY_DOT) 항목이 없습니다."
      BLOCKED=true
    fi

    # YYYYMMDD.md 존재 검사
    if [ ! -f "$DAILY_FILE" ]; then
      WARNINGS="${WARNINGS}\n[BLOCKED] docs/work-history/${TODAY}.md 파일이 없습니다."
      BLOCKED=true
    fi
  fi
fi

# --- .claude 레포 면제 (설정 레포는 task-docs 불필요) ---
IS_CLAUDE_REPO=false
if echo "$CWD" | grep -qE '[\\/]\.claude$'; then
  IS_CLAUDE_REPO=true
fi

# --- 2. analyze.md 존재 여부 (gate>=2 + 프로젝트 레포만) ---
if [ "$CURRENT" -ge 2 ] && [ "$IS_CLAUDE_REPO" = false ]; then
  TASK_DIR="$CWD/docs/tasks/$TODAY"
  if [ ! -d "$TASK_DIR" ] || [ -z "$(find "$TASK_DIR" -name '*analyze*' -type f 2>/dev/null | head -1)" ]; then
    WARNINGS="${WARNINGS}\n[BLOCKED] docs/tasks/$TODAY/ 에 analyze 파일이 없습니다."
    BLOCKED=true
  fi
fi

# --- 3. result.md 누락 여부 (gate>=2 + 프로젝트 레포만) ---
if [ "$CURRENT" -ge 2 ] && [ "$IS_CLAUDE_REPO" = false ]; then
  TASK_DIR="$CWD/docs/tasks/$TODAY"
  if [ -d "$TASK_DIR" ]; then
    for dir in "$TASK_DIR"/*/; do
      if [ -d "$dir" ]; then
        HAS_ANALYZE=$(find "$dir" -name "*analyze.md" -type f 2>/dev/null | head -1)
        HAS_RESULT=$(find "$dir" -name "*result.md" -type f 2>/dev/null | head -1)
        if [ -n "$HAS_ANALYZE" ] && [ -z "$HAS_RESULT" ]; then
          DIRNAME=$(basename "$dir")
          WARNINGS="${WARNINGS}\n[BLOCKED] docs/tasks/$TODAY/$DIRNAME/ — analyze.md는 있지만 result.md가 없습니다."
          BLOCKED=true
        fi
      fi
    done
  fi
fi

# 차단 또는 통과
if [ "$BLOCKED" = true ]; then
  echo "" >&2
  echo "━━━ Session Completeness: 산출물 누락 — 종료 차단 ━━━" >&2
  echo -e "$WARNINGS" >&2
  echo "" >&2
  echo "work-history 누락 시: history.md에 오늘 날짜 항목 + ${TODAY}.md 파일 생성 필요" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  exit 2
fi

# 세션 종료 시 플래그 정리
echo "0" > "$GATE_FILE" 2>/dev/null
rm -f "$EDIT_FLAG" 2>/dev/null
rm -f "/tmp/claude_test_run_${SESSION_ID}" 2>/dev/null

exit 0
