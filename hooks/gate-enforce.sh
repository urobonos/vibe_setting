#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "gate-enforce" "enter" "pid=$$"
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
# 면제 좁히기: 무조건 면제 → 화이트리스트 면제로 전환 (P1-4).
# 면제 대상 (하니스 운영 영역):
#   CLAUDE.md, MEMORY.md, settings*.json, keybindings.json,
#   skills/**, hooks/**, commands/**, docs/**, agents/**, agent-memory/**, lib/**
# 외 파일(예: scripts/*.py, plugins/*.py)은 일반 gate 검증 적용 (공격면 축소).
# Edit/Write 외 도구(Read, Bash 등)는 종전과 동일하게 즉시 면제.
CWD=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('cwd', ''))
except:
    print('')
" 2>/dev/null)

if echo "$CWD" | grep -qE '[\\/]\.claude$'; then
  # Edit/Write 가 아니면 종전대로 면제
  if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
  fi

  # Edit/Write — file_path 화이트리스트 검사
  CLAUDE_FILE_PATH=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    print(fp.replace(chr(92), '/'))
except:
    print('')
" 2>/dev/null)

  # 화이트리스트 매칭: 운영 영역 → 면제
  # 1) 루트 레벨 단일 파일: CLAUDE.md, MEMORY.md, settings*.json, keybindings.json
  # 2) 디렉토리 prefix: skills/, hooks/, commands/, docs/, agents/, agent-memory/, lib/, memory/
  if echo "$CLAUDE_FILE_PATH" | grep -qE '/\.claude/(CLAUDE\.md|MEMORY\.md|settings[^/]*\.json|keybindings\.json)$'; then
    exit 0
  fi
  if echo "$CLAUDE_FILE_PATH" | grep -qE '/\.claude/(skills|hooks|commands|docs|agents|agent-memory|lib|memory|bin)/'; then
    exit 0
  fi
  # auto-memory 경로 (~/.claude/projects/{session}/memory/) 면제
  if echo "$CLAUDE_FILE_PATH" | grep -qE '/\.claude/projects/[^/]+/memory/'; then
    exit 0
  fi

  # 화이트리스트 미매칭 → 정규 gate 검증으로 fall-through
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

  # docs/specs/ — IEEE 산출물 경로 (게이트 면제)
  # 글로벌 `~/.claude/docs/{product}/specs/` 포함, 과거 프로젝트 로컬 `docs/specs/` 도 호환.
  if echo "$FILE_PATH" | grep -qE '(^|/)docs/([^/]+/)?specs/'; then
    exit 0
  fi

  # docs/output/ — 분석·문서 산출물 경로 (게이트 면제, Gate-0 직행)
  # CLAUDE.md §File Paths: output/ = 분석·리서치 전용 경로, 코드 변경 없음.
  # "분석해줘", "리포트 만들어줘" 같은 요청에서 Gate-1 승인 절차 없이 즉시 작성 허용.
  # 글로벌 `~/.claude/docs/{product}/output/` 포함, 과거 프로젝트 로컬 `docs/output/` 도 호환.
  if echo "$FILE_PATH" | grep -qE '(^|/)docs/([^/]+/)?output/'; then
    exit 0
  fi

  # docs/working/ — 진행 중 단일 통합 작업 문서 (게이트 면제, Gate-0 직행, 2026-05-12 시행)
  # CLAUDE.md §File Paths "working/ 단일 통합 문서" 룰 정합.
  # 진행 중 작업은 working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md 단일 파일로 작성하며,
  # 완료 시 working-lifecycle.sh hook 이 tasks/ 폴더로 자동 이동. 작성 시점 Gate 없음.
  if echo "$FILE_PATH" | grep -qE '(^|/)docs/working/'; then
    exit 0
  fi

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
      command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=non-code-gate"
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
      command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=code-gate"
      exit 2
    fi
  fi

  # --- docs/tasks/ 경로 패턴 검증 ---
  # 글로벌: `~/.claude/docs/{product}/tasks/...`, 과거 프로젝트 로컬: `docs/tasks/...`
  if echo "$FILE_PATH" | grep -qE 'docs/([^/]+/)?tasks/'; then
    REL_PATH=$(echo "$FILE_PATH" | sed -E 's|.*docs/([^/]+/)?tasks/||')
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
      echo "[GATE BLOCKED] tasks/ 경로 규칙 위반 — 허용 패턴: history.md | YYYYMMDD/summary.md | YYYYMMDD/{작업명}/{단계}.md (현재: tasks/$REL_PATH)" >&2
      command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=tasks-path"
      exit 2
    fi
  fi
fi

# --- Subagent Spawn Validation ---
# 시스템 tool name: Task / SubagentSpawn 매칭 (Claude Code 도구명 표준)
# (Agent 는 무효 도구명이라 매처/분기에서 제거 — 2026-05-08)
if [[ "$TOOL_NAME" == "Task" || "$TOOL_NAME" == "SubagentSpawn" ]]; then
  # Explore, Plan, claude-code-guide, statusline-setup, general-purpose → model 검증 제외
  if [[ "$SUBAGENT_TYPE" != "Explore" && "$SUBAGENT_TYPE" != "Plan" && "$SUBAGENT_TYPE" != "claude-code-guide" && "$SUBAGENT_TYPE" != "statusline-setup" && "$SUBAGENT_TYPE" != "general-purpose" ]]; then
    if [ -z "$MODEL" ]; then
      echo "[GATE BLOCKED] Subagent spawn 차단 — model 파라미터(fable/opus/sonnet/haiku)를 반드시 지정하세요. (orchestration 스킬 §1.1 Effort 할당)" >&2
      command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=subagent-model"
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
      command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=team3-worktree"
      exit 2
    fi
  fi
fi

# 통과
exit 0
