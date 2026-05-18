#!/bin/bash
# parallel-mode-marker.sh
# UserPromptSubmit Hook: `/병렬` 키워드 매칭 시 parallel marker 생성
#
# 동작:
#   1. SKIP_HOOKS 체크
#   2. stdin 에서 prompt 본문 + session_id 파싱
#   3. prompt 본문 `/병렬` (또는 `/parallel`) 정규식 매칭 시 → /tmp/claude_parallel_${SESSION_ID} touch
#   4. `/병렬비활성` (또는 `/parallel-off`) 매칭 시 → marker 제거
#   5. 매칭 없으면 즉시 exit 0
#
# SSOT: 본 hook + commands/병렬.md + CLAUDE.md §4.4 자동 위임 정책 우선순위 매트릭스
# 짝 hook: parallel-reminder.sh (PreToolUse Task matcher, marker 존재 시 reminder 주입)

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/hook-input.sh" 2>/dev/null || true

if declare -f hook_init >/dev/null 2>&1; then
    hook_init
    hook_read_stdin
    hook_parse_session_id
    PROMPT_TEXT=$(hook_get_prompt 2>/dev/null || echo "$STDIN_DATA")
else
    # fallback: stdin 에서 직접 session_id + prompt 파싱
    STDIN_DATA=$(cat)
    SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    SESSION_ID=${SESSION_ID:-default}
    PROMPT_TEXT="$STDIN_DATA"
fi

MARKER_FILE="/tmp/claude_parallel_${SESSION_ID}"

# 디버그 로그
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null || {
  LOG_FILE="$HOME/.claude/parallel-mode-marker.log"
  log_event() {
    local hook="$1" event="$2"; shift 2
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$event] $*" >> "$LOG_FILE" 2>/dev/null
  }
}
log() { log_event "parallel-mode-marker" "info" "$*"; }

# 비활성 키워드 우선 체크 (활성 키워드보다 먼저)
if echo "$PROMPT_TEXT" | grep -qE '(^|[[:space:]/])(병렬비활성|parallel-off)([[:space:]]|$)'; then
    if [ -f "$MARKER_FILE" ]; then
        rm -f "$MARKER_FILE"
        log "MARKER removed (deactivate keyword) sid=$SESSION_ID"
    fi
    exit 0
fi

# `/병렬` 또는 `/parallel` 키워드 매칭 — 슬래시 prefix 필수, 단어 경계
if echo "$PROMPT_TEXT" | grep -qE '(^|[[:space:]])/(병렬|parallel)([[:space:]]|$)'; then
    touch "$MARKER_FILE"
    log "MARKER created sid=$SESSION_ID file=$MARKER_FILE"
fi

exit 0
