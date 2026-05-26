#!/bin/bash
# auto-iterate-stop-guard.sh
# Stop Hook: 묶음 승인 활성 + 작업 미완료 상태에서 Stop event 발생 시 차단 → 자동 재진입
#
# 사용자 명시 승인: 2026-05-13 "자동 진행으로 내가 요청시 완료가 안된상태로 출력이 종료될경우
#   자동으로 재진입하게 하고 해당 경우가 오기전에 자동으로 차단하여 재진입시킨다"
#   + 옵션 A (Stop hook 신설) 묶음 승인 2회 채택.
#
# 동작:
#   1. 사용자 명시 중단 마커 확인 (/tmp/claude_stop_requested_${SESSION_ID}) → 있으면 통과
#   2. 묶음 승인 활성 확인 (/tmp/claude_gate_${SESSION_ID} = 2, mtime 60분 이내)
#   3. 미충족 시 즉시 통과 (exit 0) — 카운터 리셋
#   4. 재진입 카운터 (/tmp/claude_iterate_count_${SESSION_ID}) 확인
#      - 5회 초과 시 카운터 리셋 + exit 0 (무한 루프 방지)
#      - 5회 이내 시 카운터 +1 + exit 2 + stderr 메시지 (재진입 지시)
#
# SSOT: 본 hook + 글로벌 CLAUDE.md §4 "자동 위임 정책 (Autonomous Iteration)"
# 짝 hook: gate-approve.sh (묶음 승인 키워드 + 중단 마커 생성) / auto-iterate-reminder.sh (PostToolUse reminder)
#
# CLAUDE.md §3 Checkpoint 우선 적용 — 본 hook 는 §3 보호 우회 통로가 아니다.
# §3 매칭 시 dangerous-ops-guard.sh / sensitive-file-guard.sh / branch-enforce.sh 가 별도 차단한다.

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/hook-input.sh" 2>/dev/null || true

if declare -f hook_init >/dev/null 2>&1; then
    hook_init
    hook_read_stdin
    hook_parse_session_id
else
    STDIN_DATA=$(cat)
    SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    SESSION_ID=${SESSION_ID:-default}
fi

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"
COUNTER_FILE="/tmp/claude_iterate_count_${SESSION_ID}"
STOP_MARKER="/tmp/claude_stop_requested_${SESSION_ID}"

# 2026-05-13 telemetry lib 마이그레이션
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null || {
  LOG_FILE="$HOME/.claude/auto-iterate-stop-guard.log"
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
  log_event "auto-iterate-stop-guard" "$event" "$*"
}

# 사용자 명시 중단 마커 — gate-approve.sh 가 "중단"/"보류"/"멈춰" 감지 시 생성
if [ -f "$STOP_MARKER" ]; then
    rm -f "$STOP_MARKER" "$COUNTER_FILE" 2>/dev/null
    log "stop marker detected — pass through"
    exit 0
fi

# 종료 sentinel 검출 — transcript 마지막 assistant 응답에 명시 마커 부착 시 통과
# 마커 형식 (SSOT — CLAUDE.md §4 자동 위임 정책):
#   - [AUTO-ITERATE-DONE] (정식 sentinel)
#   - [AUTO-ITERATE-USER-DECISION] (사용자 결정 영역 명시 — §3 매칭 잔여 항목)
TRANSCRIPT_PATH=$(echo "$STDIN_DATA" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    LAST_ASSISTANT_TEXT=$(tail -200 "$TRANSCRIPT_PATH" 2>/dev/null | python -c "
import sys, json
last_text = ''
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') != 'assistant':
            continue
        msg = d.get('message', {})
        if not isinstance(msg, dict):
            continue
        content = msg.get('content', [])
        if isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get('type') == 'text':
                    last_text = c.get('text', '')
        elif isinstance(content, str):
            last_text = content
    except Exception:
        pass
print(last_text)
" 2>/dev/null)
    # 위치 제약 — 응답 마지막 500바이트 안에서만 sentinel 매칭 (본문 우연 매칭 차단)
    TAIL_TEXT=$(echo "$LAST_ASSISTANT_TEXT" | tail -c 500)
    if echo "$TAIL_TEXT" | grep -qE '\[AUTO-ITERATE-(DONE|USER-DECISION)\]'; then
        rm -f "$COUNTER_FILE" 2>/dev/null
        # worktree-first 정착 안내 (2026-05-13) — sentinel 부착 통과 시 wip/* 분기 위면 정착 절차 reminder
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        case "$CURRENT_BRANCH" in
            wip/*)
                cat >&2 <<EOF
[자동진행 worktree-first 정착 안내]
- 현재 분기 '$CURRENT_BRANCH' = 자동진행 worktree 임시 분기 (wip/*).
- sentinel 부착으로 작업은 완료됐으나 feature/* 분기로의 정착이 남아있습니다.
- 다음 명령을 사용자가 직접 (\`! \` prefix) 실행해 정착 완료:
    SOURCE={원본 source 분기 — production / staging / develop}
    SLUG={작업명 kebab-case}
    ! cd {원본 repo 경로}
    ! git checkout \$SOURCE
    ! git checkout -b feature/\${SOURCE}_\${SLUG}
    ! git merge --ff-only $CURRENT_BRANCH
    ! git worktree remove \$(git rev-parse --show-toplevel)
    ! git branch -D $CURRENT_BRANCH
- 제약: source = main / master 인 경우 정착 금지 (§"master/main 머지 절대 금지"). 별도 PR 절차 사용.
- SSOT: commands/자동진행.md §"정착 절차" + CLAUDE.md §4.3 "자동진행 worktree-first 정책".
EOF
                log "settlement reminder emitted for wip branch=$CURRENT_BRANCH"
                ;;
        esac
        log "completion sentinel detected — pass through"
        exit 0
    fi
fi

# gate 파일 미존재 → 묶음 승인 비활성 → 통과
if [ ! -f "$GATE_FILE" ]; then
    rm -f "$COUNTER_FILE" 2>/dev/null
    exit 0
fi

GATE_VALUE=$(cat "$GATE_FILE" 2>/dev/null || echo "0")
if [ "$GATE_VALUE" != "2" ]; then
    rm -f "$COUNTER_FILE" 2>/dev/null
    exit 0
fi

# mtime 60분 이내 확인
GATE_MTIME=$(stat -c %Y "$GATE_FILE" 2>/dev/null || stat -f %m "$GATE_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
DIFF=$((NOW - GATE_MTIME))

if [ "$DIFF" -gt 3600 ]; then
    rm -f "$COUNTER_FILE" 2>/dev/null
    log "gate mtime expired (${DIFF}s > 3600s) — pass through"
    exit 0
fi

# 카운터 확인 — 5회 초과 시 무한 루프 방지
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 0))

if [ "$COUNT" -ge 5 ]; then
    log "iteration limit reached (${COUNT} >= 5) — pass through, reset counter"
    rm -f "$COUNTER_FILE" 2>/dev/null
    cat >&2 <<'EOF'
[자동 위임 정책 — 재진입 한계 도달]
- 묶음 승인 활성 상태에서 재진입 5회 시도 후 한계 도달.
- 자동 재진입 중단. 작업 미완료 항목 / 실패 원인 / 잔여 권고는 직전 응답을 확인 후 사용자 결정 요청.
- 무한 루프 방지 (CLAUDE.md §4 자동 위임 정책 종료 조건 (d) "재시도 5회 초과").
EOF
    exit 0
fi

# 카운터 증가 + Stop 차단 + 재진입 지시
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"
log "stop blocked, counter=${COUNT}, gate_age=${DIFF}s — request re-entry"

cat >&2 <<EOF
[자동 위임 정책 — Stop 차단 / 재진입 지시 (${COUNT}/5)]
- 묶음 승인 ("자동 진행" 등) 활성 상태 (gate=2, mtime ${DIFF}s).
- 작업 완료 신호 없음 → Stop 자동 차단 후 재진입.
- Claude 는 직전 응답에서 제시한 잔여 권고 / self-critique 미해결 항목 / 후속 액션을 계속 진행한다.
- 작업 완료 시 응답 마지막 줄에 sentinel 부착해 통과:
    * [AUTO-ITERATE-DONE]          — 작업 완전 종료 (잔여 0건)
    * [AUTO-ITERATE-USER-DECISION] — 사용자 결정 영역 잔여 (§3 매칭·옵션 분기·외부 시스템 변경 등)
  sentinel 은 응답 마지막 500바이트 안에 위치할 때만 매칭된다 (본문 우연 매칭 차단).
- 사용자 명시 중단 시 "중단" / "보류" / "멈춰" 입력 → gate-approve.sh 가 stop marker 생성 → 본 hook 통과.
- SSOT: CLAUDE.md §4 자동 위임 정책 / 짝 hook = gate-approve.sh + auto-iterate-reminder.sh.
EOF

exit 2
