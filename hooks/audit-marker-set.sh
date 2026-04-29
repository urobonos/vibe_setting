#!/bin/bash
# UserPromptSubmit Hook: 사용자 프롬프트에서 audit 키워드 감지 시 마커 생성
#
# 동작:
#   1. SKIP_HOOKS=1 → 즉시 통과
#   2. 프롬프트에 audit 키워드 (/audit-config, /audit, audit, "보안 감사", "감사") 감지
#   3. /tmp/claude_audit_marker_${SESSION_ID} touch — audit-no-autofix-guard.sh 가 5분간 참조
#
# 짝 hook: audit-no-autofix-guard.sh (PreToolUse Edit/Write — 마커 존재 시 Checkpoint 경고)

source "$(dirname "$0")/lib/hook-input.sh"

hook_init
hook_read_stdin
hook_parse_session_id

# --- 사용자 프롬프트 추출 ---
PROMPT=$(hook_parse_field "prompt")

if [ -z "$PROMPT" ]; then
  exit 0
fi

# --- audit 키워드 감지 (대소문자 무시) ---
LOWER_PROMPT=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

if echo "$LOWER_PROMPT" | grep -qE '(/audit|audit-config|보안 감사|^감사$|보안감사|취약점 점검|security audit)'; then
  AUDIT_MARKER="/tmp/claude_audit_marker_${SESSION_ID}"
  touch "$AUDIT_MARKER"
  echo "[audit-marker] 마커 생성: $AUDIT_MARKER (5분간 유효)" >&2
fi

exit 0
