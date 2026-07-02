#!/usr/bin/env bash
# hook-input.sh
# Claude Code hook 들의 stdin/JSON 파싱 공통 헬퍼.
# python3/python fallback + grep+sed graceful degrade 로 환경 차이 흡수한다.
#
# 사용 패턴:
#   #!/bin/bash
#   source "$(dirname "$0")/lib/hook-input.sh"
#   hook_init                    # SKIP_HOOKS=1 즉시 처리
#   hook_read_stdin              # STDIN_DATA 채움
#   hook_parse_session_id        # SESSION_ID 채움
#   hook_parse_command           # COMMAND 채움 (Bash 도구 hook)
#   # 이후 본 hook 의 로직 실행
#
# 규칙:
#   - 모든 함수는 부수효과로 전역 변수에 결과 채움 (return 값 사용 X)
#   - python 검출 결과는 HOOK_PY 변수에 캐시 (반복 호출 비용 0)
#   - python 실패 시 grep+sed fallback 으로 graceful degrade
#   - `set -e` 사용 금지 (호출하는 hook 마다 정책 다를 수 있음)

# ---------------------------------------------------------------------------
# hook_init
# ---------------------------------------------------------------------------
# SKIP_HOOKS=1 환경변수 검사 후 즉시 우회. stderr 에 1줄 기록.
hook_init() {
  if [ "${SKIP_HOOKS:-0}" = "1" ]; then
    echo "[SKIP] $0 SKIP_HOOKS=1" >&2
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# hook_python
# ---------------------------------------------------------------------------
# python3 우선 검출, 없으면 python fallback. HOOK_PY 변수 캐시.
hook_python() {
  if [ -n "$HOOK_PY" ]; then
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    HOOK_PY="python3"
  elif command -v python >/dev/null 2>&1; then
    HOOK_PY="python"
  else
    HOOK_PY=""
  fi
}

# ---------------------------------------------------------------------------
# hook_read_stdin
# ---------------------------------------------------------------------------
# stdin 데이터를 STDIN_DATA 전역 변수에 저장. 빈 문자열이면 ""로 둠.
hook_read_stdin() {
  STDIN_DATA=$(cat 2>/dev/null || true)
  if [ -z "$STDIN_DATA" ]; then
    STDIN_DATA=""
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_field "<field_name>"
# ---------------------------------------------------------------------------
# STDIN_DATA JSON 에서 특정 필드값 1개 추출. 결과는 stdout 으로 출력.
# python3/python → grep+sed fallback. 빈 값이면 빈 문자열 출력.
hook_parse_field() {
  local field="$1"
  local result=""
  if [ -z "$STDIN_DATA" ] || [ -z "$field" ]; then
    echo ""
    return 0
  fi
  # bash 내장 정규식 primary (fork/python 0) — 문자열 필드, 대부분 세션에서 python 起動(~367ms) 회피
  if [[ "$STDIN_DATA" =~ \"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    result="${BASH_REMATCH[1]}"
  fi
  # bash 로 안 잡히면(비문자열 bool·중첩·escape) python → grep fallback
  if [ -z "$result" ]; then
    hook_python
    if [ -n "$HOOK_PY" ]; then
      result=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    val = data.get('$field', '')
    if isinstance(val, bool):
        print('true' if val else 'false')
    elif val is None:
        print('')
    else:
        print(val)
except Exception:
    print('')
" 2>/dev/null)
    fi
  fi
  if [ -z "$result" ]; then
    result=$(echo "$STDIN_DATA" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
  fi
  echo "$result"
}

# ---------------------------------------------------------------------------
# hook_parse_session_id
# ---------------------------------------------------------------------------
# session_id 추출 + 빈 값 시 "default" fallback. SESSION_ID 전역 변수.
hook_parse_session_id() {
  SESSION_ID=$(hook_parse_field "session_id")
  if [ -z "$SESSION_ID" ]; then
    SESSION_ID="default"
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_cwd
# ---------------------------------------------------------------------------
# cwd 추출 + 빈 값 시 `pwd` fallback. CWD 전역 변수.
hook_parse_cwd() {
  CWD=$(hook_parse_field "cwd")
  if [ -z "$CWD" ]; then
    CWD=$(pwd)
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_command
# ---------------------------------------------------------------------------
# tool_input.command 추출 (Bash 도구 hook 용). COMMAND 전역 변수.
hook_parse_command() {
  COMMAND=""
  if [ -z "$STDIN_DATA" ]; then
    return 0
  fi
  # bash 내장 primary. command 는 escape 된 따옴표 가능 → STDIN 에 \" 흔적 있으면 python 재파싱(정확성 우선)
  if [[ "$STDIN_DATA" =~ \"command\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    COMMAND="${BASH_REMATCH[1]}"
  fi
  if [ -z "$COMMAND" ] || [[ "$STDIN_DATA" == *'\"'* ]]; then
    hook_python
    if [ -n "$HOOK_PY" ]; then
      local _pycmd
      _pycmd=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    cmd = data.get('tool_input', {}).get('command', '')
    print(cmd if cmd is not None else '')
except Exception:
    print('')
" 2>/dev/null)
      [ -n "$_pycmd" ] && COMMAND="$_pycmd"
    fi
  fi
  if [ -z "$COMMAND" ]; then
    COMMAND=$(echo "$STDIN_DATA" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_file_path
# ---------------------------------------------------------------------------
# tool_input.file_path 추출 (없으면 tool_response.filePath fallback). FILE_PATH 전역 변수.
hook_parse_file_path() {
  FILE_PATH=""
  if [ -z "$STDIN_DATA" ]; then
    return 0
  fi
  # bash 내장 정규식 primary (fork/python 0) — file_path 는 escape 드묾, 대부분 python 起動 회피
  if [[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    FILE_PATH="${BASH_REMATCH[1]}"
  elif [[ "$STDIN_DATA" =~ \"filePath\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    FILE_PATH="${BASH_REMATCH[1]}"
  fi
  if [ -z "$FILE_PATH" ]; then
    hook_python
    if [ -n "$HOOK_PY" ]; then
      FILE_PATH=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    if not fp:
        fp = data.get('tool_response', {}).get('filePath', '')
    print(fp if fp is not None else '')
except Exception:
    print('')
" 2>/dev/null)
    fi
  fi
  if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$STDIN_DATA" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
    if [ -z "$FILE_PATH" ]; then
      FILE_PATH=$(echo "$STDIN_DATA" | grep -o '"filePath"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
    fi
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_stop_active
# ---------------------------------------------------------------------------
# stop_hook_active boolean 추출. STOP_HOOK_ACTIVE 전역 변수 ("true"/"false").
hook_parse_stop_active() {
  STOP_HOOK_ACTIVE="false"
  if [ -z "$STDIN_DATA" ]; then
    return 0
  fi
  # bash 내장 primary (bool 단순 패턴 — python 불필요, 원본 fallback 도 grep 이었음)
  if [[ "$STDIN_DATA" =~ \"stop_hook_active\"[[:space:]]*:[[:space:]]*true ]]; then
    STOP_HOOK_ACTIVE="true"
  fi
}
