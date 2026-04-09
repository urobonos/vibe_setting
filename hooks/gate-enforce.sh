#!/bin/bash
# PreToolUse Hook: Gate 미통과 시 Edit/Write 차단 + Agent 검증
# Phase 3 Harness
#
# 규칙:
#   1. Edit/Write → gate >= 2 필요 (분석 + 계획 2회 승인)
#   2. Agent spawn → model 파라미터 필수 (Explore/Plan 제외)

STDIN_DATA=$(cat)

# session_id, tool_name 추출
eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', 'default')
    tn = data.get('tool_name', '')
    ti = data.get('tool_input', {})
    model = ti.get('model', '')
    sat = ti.get('subagent_type', '')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'TOOL_NAME=\"{tn}\"')
    print(f'MODEL=\"{model}\"')
    print(f'SUBAGENT_TYPE=\"{sat}\"')
except:
    print('SESSION_ID=\"default\"')
    print('TOOL_NAME=\"\"')
    print('MODEL=\"\"')
    print('SUBAGENT_TYPE=\"\"')
" 2>/dev/null)"

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"

# gate 파일 미존재 = 기존 세션 또는 SessionStart 미실행 → 차단 안 함
if [ ! -f "$GATE_FILE" ]; then
  exit 0
fi

CURRENT=$(cat "$GATE_FILE" 2>/dev/null || echo "0")

# --- .claude 레포 면제 (하니스 자기수정 부트스트랩 문제 방지) ---
CWD=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('cwd', ''))
except:
    print('')
" 2>/dev/null)

if echo "$CWD" | grep -qE '[\\/]\.claude$'; then
  exit 0
fi

# --- Edit/Write Gate ---
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
  if [ "$CURRENT" -lt 2 ]; then
    if [ "$CURRENT" -eq 0 ]; then
      echo "[GATE BLOCKED] Edit/Write 차단 — 분석 체크리스트를 먼저 제시하고 사용자 승인을 받으세요. (현재 gate=$CURRENT, 필요 gate>=2)" >&2
    else
      echo "[GATE BLOCKED] Edit/Write 차단 — 실행 계획(plan)을 제시하고 사용자 승인을 받으세요. (현재 gate=$CURRENT, 필요 gate>=2)" >&2
    fi
    exit 2
  fi

  # --- docs/tasks/ 경로 패턴 검증 ---
  FILE_PATH=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

  if echo "$FILE_PATH" | grep -qE 'docs/tasks/'; then
    REL_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g' | sed 's|.*/docs/tasks/||')
    if ! echo "$REL_PATH" | grep -qE '^[0-9]{8}/[^/]+/[^/]+\.md$'; then
      echo "[GATE BLOCKED] docs/tasks/ 경로 규칙 위반 — 올바른 패턴: docs/tasks/YYYYMMDD/{작업명}/{단계}.md (현재: docs/tasks/$REL_PATH)" >&2
      exit 2
    fi
  fi
fi

# --- Agent Validation ---
if [[ "$TOOL_NAME" == "Agent" ]]; then
  # Explore, Plan 에이전트는 시스템 기본값 사용 → model 검증 제외
  if [[ "$SUBAGENT_TYPE" != "Explore" && "$SUBAGENT_TYPE" != "Plan" && "$SUBAGENT_TYPE" != "claude-code-guide" && "$SUBAGENT_TYPE" != "statusline-setup" ]]; then
    if [ -z "$MODEL" ]; then
      echo "[GATE BLOCKED] Agent spawn 차단 — model 파라미터(opus/sonnet/haiku)를 반드시 지정하세요. (orchestration 스킬 §1.1 Effort 할당)" >&2
      exit 2
    fi
  fi

  # --- Team 3 Worktree 격리 강제 ---
  PROMPT_TEXT=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('prompt', ''))
except:
    print('')
" 2>/dev/null)
  ISOLATION=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('isolation', ''))
except:
    print('')
" 2>/dev/null)

  # prompt에 Team 3 / Execute / Worker Lead 키워드 + isolation 미지정 → 차단
  if echo "$PROMPT_TEXT" | grep -qiE '(team\s*3|execute|worker\s*lead)'; then
    if [[ "$ISOLATION" != "worktree" ]]; then
      echo "[GATE BLOCKED] Team 3 Agent spawn 차단 — isolation: \"worktree\" 필수. (orchestration §4.3 Worktree Isolation)" >&2
      exit 2
    fi
  fi
fi

# 통과
exit 0
