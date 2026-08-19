#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "gate-enforce" "enter" "pid=$$"
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null  # is_hard_code_file (plan-before 게이트, 2026-07-08)
# PreToolUse Hook: Gate 미통과 시 Edit/Write/MultiEdit 차단 + Agent 검증
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

# 기본 필드 일괄 추출 (eval 제거 — tool_input 값이 셸로 재해석되는 코드 인젝션 차단, C1 2026-06-16)
#   python 이 5개 값을 개행 구분 1줄씩 출력 → mapfile 로 배열에 데이터로만 적재 (eval 경유 X).
#   값 내 개행/CR 은 python 단에서 공백 치환 (배열 인덱스 어긋남 방지). python 부재 시 빈 배열 → 기본값.
_GATE_PY=""
command -v python3 >/dev/null 2>&1 && _GATE_PY=python3
[ -z "$_GATE_PY" ] && command -v python >/dev/null 2>&1 && _GATE_PY=python
_GF=()
if [ -n "$_GATE_PY" ]; then
  # 배칭: 필요한 8개 값을 python 1회로 일괄 추출.
  #   기존엔 cwd(.claude CWD 면제 분기)·file_path(면제 분기 / Edit·Write·MultiEdit Gate)·prompt(Team 3 worktree 검사)를
  #   지점마다 python 재기동(최대 4회) → 콜드 스타트 시 수 초 손실.
  #   file_path 는 여기서 역슬래시→슬래시 정규화 (기존 각 지점 replace(chr(92),'/') 와 동일 동작 보존).
  mapfile -t _GF < <(printf '%s' "$STDIN_DATA" | "$_GATE_PY" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', {}) or {}
    out = [
        data.get('session_id', 'default') or 'default',
        data.get('tool_name', '') or '',
        ti.get('model', '') or '',
        ti.get('subagent_type', '') or '',
        ti.get('isolation', '') or '',
        data.get('cwd', '') or '',
        (ti.get('file_path', '') or '').replace(chr(92), '/'),
        ti.get('prompt', '') or '',
    ]
except Exception:
    out = ['default', '', '', '', '', '', '', '']
print('\n'.join(str(x).replace('\n', ' ').replace('\r', ' ') for x in out))
" 2>/dev/null | tr -d '\r')
fi
# Windows python stdout 은 \n→\r\n 변환 → mapfile -t 가 줄끝 \r 잔류 → TOOL_NAME='Edit\r' 등 값 오염(gate 무력화).
# 파이프 단계 tr -d 로 CR 제거 (bash 5.2 의 배열 ${arr[@]//$'\r'/} 치환은 CR 미제거 확인됨 — 단일 문자열용 문법이 배열엔 무효).
SESSION_ID="${_GF[0]:-default}"
TOOL_NAME="${_GF[1]:-}"
MODEL="${_GF[2]:-}"
SUBAGENT_TYPE="${_GF[3]:-}"
ISOLATION="${_GF[4]:-}"
CWD="${_GF[5]:-}"
FILE_PATH="${_GF[6]:-}"
PROMPT_TEXT="${_GF[7]:-}"
[ -z "$SESSION_ID" ] && SESSION_ID="default"

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
# (CWD 는 상단 배치 추출에서 이미 확보 — python 재기동 제거)
if echo "$CWD" | grep -qE '[\\/]\.claude$'; then
  # 파일 변경 도구(Edit/Write/MultiEdit)만 아래 화이트리스트 검사를 받는다.
  #
  # ⚠ 미해소 (정합 아님): settings.json matcher 는 `Edit|Write|MultiEdit|Task|SubagentSpawn` 5종인데
  #   이 조건이 닫은 것은 파일 도구 3종뿐이다. Task/SubagentSpawn 은 여기서 exit 0 으로 조기 탈출하므로
  #   cwd 가 ~/.claude 일 때 **파일 하단 Subagent Spawn Validation(model 파라미터 강제 +
  #   isolation:worktree 강제)에 도달하지 못한다** = 그 검증이 사문화된다.
  #   실측: 같은 spawn 이 cwd=레포면 exit 2, cwd=~/.claude 면 exit 0.
  #   여기를 "비-mutating 도구만 면제" 로 뒤집으면 하니스 자기수정 흐름 전반에 영향이 가므로
  #   구조 변경은 별도 §3 결정으로 다룬다. 이 줄을 "닫혔다" 로 읽지 말 것.
  if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "MultiEdit" ]]; then
    exit 0
  fi

  # Edit/Write — file_path 화이트리스트 검사 (file_path 는 상단 배치에서 정규화 완료)
  CLAUDE_FILE_PATH="$FILE_PATH"

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

# --- Edit/Write/MultiEdit Gate ---
# MultiEdit 은 settings.json matcher(`Edit|Write|MultiEdit|Task|SubagentSpawn`) 에 등록돼 있는데
# 이 조건에서 빠져 있어 gate 레벨·plan-before·tasks/ 경로 규칙을 전부 통과했다 (도구명만 바꾸면 우회).
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "MultiEdit" ]]; then
  # file_path 는 상단 배치에서 추출·정규화 완료 (python 재기동 제거)

  # --- '..' 세그먼트 거부 (이 블록 안의 모든 경로 판정보다 먼저) ---
  # FILE_PATH 는 역슬래시 정규화만 됐고 realpath 해석은 안 된 문자열이다. '..' 이 남아 있으면
  # 이후의 면제 매칭(specs//output//working/)과 tasks/ 규칙이 전부 "쓰여 있는 대로" 판정돼 무력화된다.
  # 이 검사를 tasks/ 블록 **안**에 두면 '..' 이 tasks/ 앞에 올 때
  #   (예: docs/{product}/specs/../tasks/20260727/t/steps/sub/deep/x.md)
  # tasks/ 매칭 자체가 성립해도 규칙을 우회하거나, 면제 경로로 먼저 빠져나간다.
  # 세그먼트 단위로만 판정한다 — '...' · '..foo' · 'foo..bar' 는 정상 파일명이라 차단 대상이 아니다.
  #   (단 실 PreToolUse 체인에서는 worktree-enforce 가 '..' 을 **부분문자열**로 보고 막는다.
  #    체인 기준 최종 판정이 다르다는 뜻 — 회귀 케이스는 tests/run-guard-tests.sh §H 참조)
  #
  # ⚠ 미해소 ("전 경로 공통" 아님): 위쪽 `.claude 레포 CWD 면제` 화이트리스트가 exit 0 으로 **먼저**
  #   탈출하므로 cwd=~/.claude + 화이트리스트 경로(docs/ 등)로 들어온 '..' 은 이 가드에 도달하지 않는다.
  #   실측: gate=0 에서 `~/.claude/docs/../../../works/{repo}/app/**.php` 가 체인 전체 통과(php 쓰기가
  #   gate·plan-before·worktree-enforce 동시 우회). 이 구멍은 HEAD 도 exit 0 = 기존 결함이며,
  #   면제 분기 구조를 바꾸는 것은 하니스 자기수정 흐름에 영향이 가므로 별도 §3 결정으로 다룬다.
  #
  # 신규 차단면: '..' 세그먼트를 실제로 포함한 경로만 새로 막힌다. 실측 표본 6종 확인
  #   (tasks/ 앞뒤 · specs/../specs · output/../output · working/../working · auto-memory memory/../memory ·
  #    인접 레포 repo/../infra/docs) — 전수 상한은 측정하지 않았다.
  #   하니스 정상 호출부가 '..' 포함 경로로 쓰는 흐름은 0건으로 확인했다.
  if echo "$FILE_PATH" | grep -qE '(^|/)\.\.(/|$)'; then
    echo "[GATE BLOCKED] 경로에 '..' 세그먼트를 쓸 수 없습니다 — 정규화된 절대 경로로 지정하세요. (현재: $FILE_PATH)" >&2
    command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=path-traversal"
    exit 2
  fi

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

  # --- plan-before 게이트 (2026-07-08, 독립 검사 / 숫자 게이트 무관) ---
  # hard-code 파일(php/js/ts/py/sql)은 세션 §계획 문서 존재 시에만 수정 허용.
  # 신호 = REGISTRY(SID8) → working_file → `^Status: (Plan Complete|In Progress|Done|Partial)` (execute 단계 In Progress 포함).
  # override 마커(/tmp/claude_trivial_${SESSION_ID}, 핫픽스) 존재 시 통과.
  # 판정 원재료(REGISTRY) 부재 시 fail-open(통과) — 전역 게이트라 미상 시 차단 금지.
  # SSOT: docs/claude-harness/output/analysis/2026-07-08-code-lifecycle-enforcement.
  if command -v is_hard_code_file >/dev/null 2>&1 && is_hard_code_file "$FILE_PATH"; then
    # trivial override 마커 = 30분 시간창 내(find -mmin -30)만 유효 (self-expiry, 스테일 우회 차단).
    _trivial_marker="/tmp/claude_trivial_${SESSION_ID}"
    _trivial_active=0
    [ -f "$_trivial_marker" ] && [ -n "$(find "$_trivial_marker" -mmin -30 2>/dev/null)" ] && _trivial_active=1
    if [ "$_trivial_active" -eq 0 ]; then
      _plan_registry="$HOME/.claude/docs/working/REGISTRY.md"
      if [ -f "$_plan_registry" ]; then
        _plan_sid8="${SESSION_ID:0:8}"
        _plan_ok=0
        while IFS= read -r _plan_wf; do
          [ -z "$_plan_wf" ] && continue
          if [ -f "$_plan_wf" ] && grep -qE '^Status:[[:space:]]*(Plan Complete|In Progress|Done|Partial)' "$_plan_wf" 2>/dev/null; then
            _plan_ok=1; break
          fi
        done < <(awk -F'|' -v s="$_plan_sid8" '{gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$9); if ($4==s) print $9}' "$_plan_registry" 2>/dev/null)
        if [ "$_plan_ok" -ne 1 ]; then
          echo "[GATE BLOCKED] 코드 변경 전 계획 필요 — /taskflow:plan 으로 §계획을 세우고 'Status: Plan Complete' 부착 후 수정하세요. trivial 핫픽스면 '핫픽스' 키워드로 override 하세요. [$FILE_PATH]" >&2
          command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=plan-before"
          exit 2
        fi
      fi
      # REGISTRY 부재 = 판정 원재료 없음 → fail-open (통과)
    fi
    # code-touched 마커 (backlog verify-e2e-check-doc-exempt) — hard-code(php/js/ts/py/sql) 파일이
    # 차단 없이 이 지점에 도달 = 이 세션이 실제 코드를 변경했다. doc-unified-check.sh 의 v_verify_e2e 가
    # 마커 부재 시 문서 e2e 5점을 hint 로 강등(코드 미동반 문서 면제). trivial/plan_ok/fail-open 통과 경로 수렴점.
    touch "/tmp/claude_code_touched_${SESSION_ID}" 2>/dev/null
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
    # ('..' 거부는 이 블록 진입 전 전 경로 공통 가드가 담당한다 — 여기 두면 tasks/ 앞의 '..' 을 못 잡는다)
    # history.md (전체 이력 인덱스) 허용
    if echo "$REL_PATH" | grep -qE '^history\.md$'; then
      : # 통과
    # YYYYMMDD/summary.md (일일 작업 요약) 허용
    elif echo "$REL_PATH" | grep -qE '^[0-9]{8}/summary\.md$'; then
      : # 통과
    # YYYYMMDD/{작업명}/{단계}.md + YYYYMMDD/{작업명}/steps/{단계}.md (워크플로우 산출물) 허용
    # steps/ 1단계는 working-lifecycle.sh 가 working/ → tasks/ 이동 시 실제로 만드는 배치라 허용한다.
    # (임의 깊이로 열지 않는다 — steps/ 외 하위 디렉토리는 종전대로 차단)
    elif echo "$REL_PATH" | grep -qE '^[0-9]{8}/[^/]+/(steps/)?[^/]+\.md$'; then
      : # 통과
    else
      echo "[GATE BLOCKED] tasks/ 경로 규칙 위반 — 허용 패턴: history.md | YYYYMMDD/summary.md | YYYYMMDD/{작업명}/{단계}.md | YYYYMMDD/{작업명}/steps/{단계}.md (현재: tasks/$REL_PATH)" >&2
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
      echo "[GATE BLOCKED] Subagent spawn 차단 — model 파라미터(opus/sonnet/haiku)를 반드시 지정하세요. (orchestration 스킬 §1.1 Model 할당 정책)" >&2
      command -v log_event >/dev/null 2>&1 && log_event "gate-enforce" "block" "reason=subagent-model"
      exit 2
    fi
  fi

  # --- Team 3 Worktree 격리 강제 ---
  # PROMPT_TEXT 는 상단 배치에서 추출 완료 (python 재기동 제거)

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
