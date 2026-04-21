#!/bin/bash
# Stop Hook: 세션 종료 시 산출물 누락 검증
# exit 2 차단 — 산출물 미완성 시 세션 종료 차단
#
# 검증 항목:
#   1. Edit/Write 이력 있는 세션 → history.md + YYYYMMDD/summary.md 기록 필수
#   2. gate>=2(실행 단계) → analyze.md 존재 필수
#   3. gate>=2 + analyze.md 있으면 → result.md 존재 필수

STDIN_DATA=$(cat)

# python3 우선 파싱 + grep fallback (Windows 환경 JSON 이스케이프 호환)
PARSED=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', '')
    cwd = data.get('cwd', '')
    if not sid:
        sys.exit(1)
    safe_cwd = cwd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'CWD=\"{safe_cwd}\"')
except Exception:
    sys.exit(1)
" 2>/dev/null)
if [ -n "$PARSED" ]; then
  eval "$PARSED"
else
  SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  CWD=$(echo "$STDIN_DATA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  # JSON이스케이프된 \\를 실제 \로 복원 (Windows 경로)
  CWD=$(echo "$CWD" | sed 's/\\\\/\\/g')
  SESSION_ID=${SESSION_ID:-default}
  CWD=${CWD:-.}
fi

TODAY=$(date +%Y%m%d)
TODAY_DOT=$(date +%Y.%m.%d)
BLOCKED=false
WARNINGS=""

# CWD가 프로젝트 서브디렉토리일 수 있음 (Bash cd 영속성으로 인함) → 상위 5단계까지 docs/tasks 보유한 조상을 프로젝트 루트로 간주
find_project_root() {
  local dir="$1"
  local i
  for i in 1 2 3 4 5; do
    if [ -d "$dir/docs/tasks" ]; then
      echo "$dir"
      return 0
    fi
    local parent
    parent=$(dirname "$dir")
    [ "$parent" = "$dir" ] && break
    dir="$parent"
  done
  return 1
}
PROJECT_ROOT=$(find_project_root "$CWD")
if [ -n "$PROJECT_ROOT" ]; then
  CWD="$PROJECT_ROOT"
fi

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"
CURRENT=$(cat "$GATE_FILE" 2>/dev/null || echo "0")
EDIT_FLAG="/tmp/claude_edit_flag_${SESSION_ID}"
NONCODE_FLAG="/tmp/claude_noncode_flag_${SESSION_ID}"

# --- .claude 레포 면제 (설정 레포는 task-docs 불필요) ---
IS_CLAUDE_REPO=false
if echo "$CWD" | grep -qE '[\\/]\.claude([\\/].*)?$'; then
  IS_CLAUDE_REPO=true
fi

# --- 비코드 전용 세션 면제 ---
# 코드 수정 없이 비코드만 수정한 세션 → docs/tasks 강제 면제
IS_NONCODE_ONLY=false
if [ ! -f "$EDIT_FLAG" ] && [ -f "$NONCODE_FLAG" ]; then
  IS_NONCODE_ONLY=true
fi

# --- 1. 일일 기록 여부 (코드 Edit/Write 이력 + docs/tasks 디렉토리 있는 프로젝트만) ---
if [ -f "$EDIT_FLAG" ] && [ "$IS_CLAUDE_REPO" = false ] && [ "$IS_NONCODE_ONLY" = false ]; then
  TASKS_DIR="$CWD/docs/tasks"
  if [ -d "$TASKS_DIR" ]; then
    HISTORY_FILE="$TASKS_DIR/history.md"
    DAILY_FILE="$TASKS_DIR/${TODAY}/summary.md"

    # history.md 오늘 날짜 항목 검사
    if [ ! -f "$HISTORY_FILE" ] || ! grep -q "$TODAY_DOT" "$HISTORY_FILE" 2>/dev/null; then
      WARNINGS="${WARNINGS}\n[BLOCKED] docs/tasks/history.md에 오늘($TODAY_DOT) 항목이 없습니다."
      BLOCKED=true
    fi

    # YYYYMMDD/summary.md 존재 검사
    if [ ! -f "$DAILY_FILE" ]; then
      WARNINGS="${WARNINGS}\n[BLOCKED] docs/tasks/${TODAY}/summary.md 파일이 없습니다."
      BLOCKED=true
    fi
  fi
fi

# --- 2. analyze.md 존재 여부 (gate>=2 + 프로젝트 레포 + 코드 수정 세션만) ---
if [ "$CURRENT" -ge 2 ] && [ "$IS_CLAUDE_REPO" = false ] && [ "$IS_NONCODE_ONLY" = false ]; then
  TASK_DIR="$CWD/docs/tasks/$TODAY"
  if [ ! -d "$TASK_DIR" ] || [ -z "$(find "$TASK_DIR" -name '*analyze*' -type f 2>/dev/null | head -1)" ]; then
    WARNINGS="${WARNINGS}\n[BLOCKED] docs/tasks/$TODAY/ 에 analyze 파일이 없습니다."
    BLOCKED=true
  fi
fi

# --- 3. result.md 누락 여부 (gate>=2 + 프로젝트 레포 + 코드 수정 세션만) ---
if [ "$CURRENT" -ge 2 ] && [ "$IS_CLAUDE_REPO" = false ] && [ "$IS_NONCODE_ONLY" = false ]; then
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
  echo "일일 기록 누락 시: docs/tasks/history.md에 오늘 날짜 항목 + docs/tasks/${TODAY}/summary.md 파일 생성 필요" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  exit 2
fi

# 세션 종료 시 플래그 정리
# NOTE: Stop hook은 "매 assistant 응답 종료"마다 호출됨 (실제 세션 종료 이벤트 아님).
#       gate 리셋을 여기서 하면 승인 누적이 무효화되어 매 턴 재승인이 필요해짐.
#       gate는 SessionStart(gate-init.sh)에서만 초기화하고, Stop에서는 건드리지 않는다.
# echo "0" > "$GATE_FILE" 2>/dev/null   # ← 제거: 매턴 리셋 방지
rm -f "$EDIT_FLAG" 2>/dev/null
rm -f "$NONCODE_FLAG" 2>/dev/null
rm -f "/tmp/claude_test_run_${SESSION_ID}" 2>/dev/null

exit 0
