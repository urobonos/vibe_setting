#!/bin/bash
# 공유 lib 는 하니스 hooks/lib 에 있다. 스크립트 위치 기준으로 찾아 $HOME 을 바꾼 테스트에서도
# 같은 파일을 쓰고, 플러그인이 캐시 사본으로 로드돼 상대경로가 없으면 $HOME 으로 되돌아간다
HARNESS_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/lib" 2>/dev/null && pwd)"
[ -f "$HARNESS_LIB/hook-input.sh" ] || HARNESS_LIB="$HOME/.claude/hooks/lib"
# auto-iterate-reminder.sh
# PostToolUse Hook: 묶음 승인 활성 시 자동 위임 정책 system reminder 주입
#
# 동작:
#   1. 묶음 승인 활성 상태 확인 (/tmp/claude_autoiter_${SESSION_ID} 존재, mtime 60분 이내)
#   2. 미충족 시 즉시 통과 (exit 0)
#   3. 충족 시 stdout 으로 system reminder 출력 → 다음 Claude 응답에서 자동 위임 정책 의식
#
# SSOT: 본 hook + 글로벌 CLAUDE.md §4 "자동 위임 정책 (Autonomous Iteration)"
# 짝 hook: gate-approve.sh (UserPromptSubmit, 묶음 승인 키워드 감지 → autoiter 마커 생성·mtime 갱신)

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# shellcheck disable=SC1091
source "$HARNESS_LIB/hook-input.sh" 2>/dev/null || true

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

AUTOITER_FILE="/tmp/claude_autoiter_${SESSION_ID}"

# 디버그 로그 (2026-05-13 telemetry lib 마이그레이션)
# shellcheck disable=SC1091
source "$HARNESS_LIB/log-helper.sh" 2>/dev/null || {
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

# 자동 반복 마커 미존재 시 통과 (gate=2 는 판정에 쓰지 않는다 — gate-approve.sh 참조)
if [ ! -f "$AUTOITER_FILE" ]; then
    exit 0
fi

# mtime 60분 이내 확인 (자동 위임 정책 활성 기간)
MARKER_MTIME=$(stat -c %Y "$AUTOITER_FILE" 2>/dev/null || stat -f %m "$AUTOITER_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
DIFF=$((NOW - MARKER_MTIME))

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
  - 결정 escalation ladder = USER-DECISION 부착 전 분류 필수 — 권한형(P1~P4)·불확실 = 즉시 사용자 / 정보 부족형(I1~I3) = bounded 재진입. SSOT = execute.md §"결정 escalation ladder"
  - 단계 전이 = analyze 완료 + 수정 대상 ≥1건 + 본 마커 활성 → plan 자동 진입 / 진단성(수정 0건) = 전이 금지. SSOT = analyze.md §"단계 전이"
  - §3 Checkpoint 우선 적용 — 비가역(삭제·force push·DB 변경)·광범위(3파일+ 아키텍처)·외부 시스템 변경은 사용자 명시 승인 필수
  - SSOT: CLAUDE.md §4 "자동 위임 정책 (Autonomous Iteration)"
</system-reminder>
EOF

log "enter" "REMINDER injected sid=$SESSION_ID elapsed=${DIFF}s remaining=${REMAINING}s"

exit 0
