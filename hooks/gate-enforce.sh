#!/bin/bash
# PreToolUse Hook: Gate 미통과 시 Edit/Write 차단 + Agent 검증
# Phase 3 Harness — v2 (비코드 경로 완화)
#
# Gate 레벨:
#   0 = LOCKED    — Read/Search만 허용
#   1 = ANALYSIS  — 비코드 파일 Edit/Write 허용
#   2 = EXECUTE   — 모든 Edit/Write 허용 (코드 포함)
#
# 비코드 경로 (gate >= 1):
#   docs/**              작업 문서, 분석, 계획
#   .claude/**           스킬, 훅, 메모리, 규칙, 설정
#   .agent-logs/**       에이전트 파이프라인 산출물
#   CLAUDE.md            프로젝트 지침서
#   scripts/pipeline/**  파이프라인 도구 스크립트
#   memory/**            글로벌 메모리
#
# 코드 경로 (gate >= 2):
#   그 외 모든 파일 (app, components, store, hooks, lib, public, messages 등)

STDIN_DATA=$(cat)

# 기본 필드 일괄 추출
eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', 'default')
    tn = data.get('tool_name', '')
    ti = data.get('tool_input', {})
    model = ti.get('model', '')
    sat = ti.get('subagent_type', '')
    iso = ti.get('isolation', '')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'TOOL_NAME=\"{tn}\"')
    print(f'MODEL=\"{model}\"')
    print(f'SUBAGENT_TYPE=\"{sat}\"')
    print(f'ISOLATION=\"{iso}\"')
except:
    print('SESSION_ID=\"default\"')
    print('TOOL_NAME=\"\"')
    print('MODEL=\"\"')
    print('SUBAGENT_TYPE=\"\"')
    print('ISOLATION=\"\"')
" 2>/dev/null)"

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"

# gate 파일 미존재 = 기존 세션 또는 SessionStart 미실행 → 차단 안 함
if [ ! -f "$GATE_FILE" ]; then
  exit 0
fi

CURRENT=$(cat "$GATE_FILE" 2>/dev/null || echo "0")

# --- .claude 레포 CWD 면제 (하니스 자기수정 부트스트랩) ---
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
  # file_path 추출 + 경로 정규화 (Windows 역슬래시 → 슬래시)
  FILE_PATH=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    print(fp.replace(chr(92), '/'))
except:
    print('')
" 2>/dev/null)

  # 비코드 경로 판별
  IS_NON_CODE=false

  # docs/ — 작업 문서
  if echo "$FILE_PATH" | grep -qE '(^|/)(docs|\.claude|\.agent-logs)/'; then
    IS_NON_CODE=true
  fi
  # CLAUDE.md — 프로젝트 지침
  if echo "$FILE_PATH" | grep -qE '(^|/)CLAUDE\.md$'; then
    IS_NON_CODE=true
  fi
  # scripts/pipeline/ — 파이프라인 도구
  if echo "$FILE_PATH" | grep -qE '(^|/)scripts/pipeline/'; then
    IS_NON_CODE=true
  fi
  # memory/ — 글로벌 메모리
  if echo "$FILE_PATH" | grep -qE '/memory/'; then
    IS_NON_CODE=true
  fi

  # --- Gate 레벨 검증 ---
  if [ "$IS_NON_CODE" = true ]; then
    # 비코드: gate >= 1 (분석 방향 승인 후 수정 가능)
    if [ "$CURRENT" -lt 1 ]; then
      echo "[GATE BLOCKED] 비코드 파일 수정 차단 — 분석 방향을 먼저 제시하고 사용자 승인을 받으세요. (현재 gate=$CURRENT, 필요 gate>=1)" >&2
      exit 2
    fi
  else
    # 코드: gate >= 2 (실행 계획 승인 후 수정 가능)
    if [ "$CURRENT" -lt 2 ]; then
      if [ "$CURRENT" -eq 0 ]; then
        echo "[GATE BLOCKED] 코드 수정 차단 — 분석 체크리스트를 먼저 제시하고 사용자 승인을 받으세요. (현재 gate=$CURRENT, 필요 gate>=2)" >&2
      else
        echo "[GATE BLOCKED] 코드 수정 차단 — 실행 계획(plan)을 제시하고 사용자 승인을 받으세요. (현재 gate=$CURRENT, 필요 gate>=2)" >&2
      fi
      exit 2
    fi
  fi

  # --- docs/tasks/ 경로 패턴 검증 ---
  if echo "$FILE_PATH" | grep -qE 'docs/tasks/'; then
    REL_PATH=$(echo "$FILE_PATH" | sed 's|.*/docs/tasks/||')
    # history.md (전체 이력 인덱스) 허용
    if echo "$REL_PATH" | grep -qE '^history\.md$'; then
      : # 통과
    # YYYYMMDD/summary.md (일일 작업 요약) 허용
    elif echo "$REL_PATH" | grep -qE '^[0-9]{8}/summary\.md$'; then
      : # 통과
    # YYYYMMDD/{작업명}/{단계}.md (워크플로우 산출물) 허용
    elif echo "$REL_PATH" | grep -qE '^[0-9]{8}/[^/]+/[^/]+\.md$'; then
      : # 통과
    else
      echo "[GATE BLOCKED] docs/tasks/ 경로 규칙 위반 — 허용 패턴: history.md | YYYYMMDD/summary.md | YYYYMMDD/{작업명}/{단계}.md (현재: docs/tasks/$REL_PATH)" >&2
      exit 2
    fi
  fi
fi

# --- Agent Validation ---
if [[ "$TOOL_NAME" == "Agent" ]]; then
  # Explore, Plan, claude-code-guide, statusline-setup → model 검증 제외
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
