#!/bin/bash
# parallel-reminder.sh
# PreToolUse Hook (matcher: Task): parallel marker 존재 시 병렬 spawn reminder 주입
#
# 동작:
#   1. SKIP_HOOKS 체크
#   2. stdin 에서 session_id 파싱
#   3. /tmp/claude_parallel_${SESSION_ID} 존재 + mtime 60분 이내 확인
#   4. 미충족 시 즉시 exit 0
#   5. 충족 시 stdout 으로 system-reminder 주입 → 다음 Claude Task 호출 시 병렬 spawn 강제 의식
#
# SSOT: 본 hook + commands/병렬.md
# 짝 hook: parallel-mode-marker.sh (UserPromptSubmit, `/병렬` 키워드 시 marker 생성)

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/hook-input.sh" 2>/dev/null || true

if declare -f hook_init >/dev/null 2>&1; then
    hook_init
    hook_read_stdin
    hook_parse_session_id
else
    # fallback
    STDIN_DATA=$(cat)
    SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    SESSION_ID=${SESSION_ID:-default}
fi

MARKER_FILE="/tmp/claude_parallel_${SESSION_ID}"

# 디버그 로그
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null || {
  LOG_FILE="$HOME/.claude/parallel-reminder.log"
  log_event() {
    local hook="$1" event="$2"; shift 2
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$event] $*" >> "$LOG_FILE" 2>/dev/null
  }
}
log() { log_event "parallel-reminder" "info" "$*"; }

# marker 미존재 시 통과
if [ ! -f "$MARKER_FILE" ]; then
    exit 0
fi

# mtime 60분 이내 확인 (활성 기간)
MARKER_MTIME=$(stat -c %Y "$MARKER_FILE" 2>/dev/null || stat -f %m "$MARKER_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
DIFF=$((NOW - MARKER_MTIME))

if [ "$DIFF" -gt 3600 ]; then
    # 만료된 marker 자동 정리
    rm -f "$MARKER_FILE"
    log "MARKER expired and removed sid=$SESSION_ID elapsed=${DIFF}s"
    exit 0
fi

REMAINING=$((3600 - DIFF))

# system reminder 주입 (stdout) — Task 도구 호출 직전
cat <<EOF
<system-reminder>
[병렬 spawn 모드 활성] `/병렬` modifier marker 활성 중 (${DIFF}초 경과 / ${REMAINING}초 잔여).
  - 독립 Agent 작업은 multi tool_use 블록 1개에 묶어 동시 spawn 한다 (직렬 spawn 금지).
  - 동일 파일 mutation 가능성이 있는 작업은 race 회피 — stderr 경고 후 직렬 fallback.
  - 순서 의존 시퀀스 (계획→실행→검증) 는 병렬 X, 직렬 fallback.
  - §3 Checkpoint 5조건 매칭 작업은 병렬 무관 사용자 명시 승인 우선.
  - SSOT: commands/병렬.md + CLAUDE.md §4.4 자동 위임 정책 우선순위 매트릭스.
</system-reminder>
EOF

log "REMINDER injected sid=$SESSION_ID elapsed=${DIFF}s remaining=${REMAINING}s"

exit 0
