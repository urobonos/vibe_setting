#!/bin/bash
# auto-iterate-reminder.sh
# PostToolUse Hook: 묶음 승인 활성 시 자동 위임 정책 system reminder 주입
#
# 동작:
#   1. 묶음 승인 활성 상태 확인 (/tmp/claude_gate_${SESSION_ID} = 2, mtime 60분 이내)
#   2. 미충족 시 즉시 통과 (exit 0)
#   3. 충족 시 stdout 으로 system reminder 출력 → 다음 Claude 응답에서 자동 위임 정책 의식
#
# SSOT: 본 hook + 글로벌 CLAUDE.md §4 "자동 위임 정책 (Autonomous Iteration)"
# 짝 hook: gate-approve.sh (UserPromptSubmit, 묶음 승인 키워드 감지 → gate=2 + mtime 갱신)

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/hook-input.sh" 2>/dev/null || true

if declare -f hook_init >/dev/null 2>&1; then
    hook_init
    hook_read_stdin
    hook_parse_session_id
else
    # fallback: stdin 에서 직접 session_id 파싱
    STDIN_DATA=$(cat)
    SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    SESSION_ID=${SESSION_ID:-default}
fi

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"

# 디버그 로그 (2026-05-13 telemetry lib 마이그레이션)
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null || {
  LOG_FILE="$HOME/.claude/auto-iterate-reminder.log"
  log_event() {
    local hook="$1" event="$2"; shift 2
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$event] $*" >> "$LOG_FILE" 2>/dev/null
  }
}
log() {
  local event="info"
  if [[ "${1:-}" =~ ^(enter|approve|block|skip|error|info)$ ]]; then
    event="$1"; shift
  fi
  log_event "auto-iterate-reminder" "$event" "$*"
}

# gate 파일 미존재 시 통과
if [ ! -f "$GATE_FILE" ]; then
    exit 0
fi

GATE_VALUE=$(cat "$GATE_FILE" 2>/dev/null || echo "0")
if [ "$GATE_VALUE" != "2" ]; then
    exit 0
fi

# mtime 60분 이내 확인 (자동 위임 정책 활성 기간)
GATE_MTIME=$(stat -c %Y "$GATE_FILE" 2>/dev/null || stat -f %m "$GATE_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
DIFF=$((NOW - GATE_MTIME))

if [ "$DIFF" -gt 3600 ]; then
    exit 0
fi

REMAINING=$((3600 - DIFF))

# system reminder 주입 (stdout)
cat <<EOF
<system-reminder>
[자동 위임 정책 활성] 묶음 승인 후 ${DIFF}초 경과 (60분 면제 중, ${REMAINING}초 잔여).
  - 후속 권고·잔여 액션 = 기본 옵션으로 자동 채택, 끝까지 진행 (다시 묻지 않음)
  - self-critique 루프 = 각 단계 완료 후 산출물·hook 결과·실행 출력 직접 검증, FAIL/WARN 0건까지 자동 반복 (최대 5회)
  - 종료 조건 = (a) self-critique 0건 + 후속 권고 잔여 0건, (b) 사용자 '중단/보류/멈춰', (c) §3 Checkpoint 5조건 매칭, (d) self-critique 재시도 5회 초과
  - §3 Checkpoint 우선 적용 — 비가역(삭제·force push·DB 변경)·광범위(3파일+ 아키텍처)·외부 시스템 변경은 사용자 명시 승인 필수
  - SSOT: CLAUDE.md §4 "자동 위임 정책 (Autonomous Iteration)"
</system-reminder>
EOF

log "enter" "REMINDER injected sid=$SESSION_ID elapsed=${DIFF}s remaining=${REMAINING}s"

exit 0
