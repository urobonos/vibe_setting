#!/bin/bash
# 공유 lib 는 하니스 hooks/lib 에 있다. 스크립트 위치 기준으로 찾아 $HOME 을 바꾼 테스트에서도
# 같은 파일을 쓰고, 플러그인이 캐시 사본으로 로드돼 상대경로가 없으면 $HOME 으로 되돌아간다
HARNESS_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/lib" 2>/dev/null && pwd)"
[ -f "$HARNESS_LIB/hook-input.sh" ] || HARNESS_LIB="$HOME/.claude/hooks/lib"
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$HARNESS_LIB/log-helper.sh" 2>/dev/null && log_event "gate-init" "enter" "pid=$$"
# SessionStart Hook: 워크플로우 Gate 상태 초기화
# 세션 시작 시 gate 를 2(Edit 허용)로 초기화 — 아래 "자동 순차 진행 정책" 참조.
# gate=2 는 묶음 승인 신호가 아니다 (자동진행 활성 = /tmp/claude_autoiter_{sid} 마커, gate-approve.sh).
#
# Gate 레벨:
#   0 = LOCKED   — Edit/Write 차단, 분석 필요
#   1 = GATE1    — 분석 승인됨, 계획 단계
#   2 = GATE2    — 계획 승인됨, Edit/Write 허용

source "$HARNESS_LIB/hook-input.sh"
hook_read_stdin
hook_parse_session_id

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"

# 자동 순차 진행 정책 (2026-05-12): 세션 시작 시 gate = 2 (EXECUTE) 초기화
# 단계별 차단 폐기 — §3 Checkpoint 5조건 보호는 별 hook (dangerous-ops-guard / branch-enforce / git-quality-gate 등)
# SSOT: ~/.claude/CLAUDE.md §4.3 "묶음 승인 Fast-Track (Gate 0→2)"
echo "2" > "$GATE_FILE"

# stale claude_* 마커 정리 (7일 이상 미수정 — 활성 세션 마커는 mtime 갱신되어 보존)
# 대상: claude_gate_* / claude_edit_flag_* / claude_selfcheck_done_* / claude_completeness_warned_*
#       claude_statusline_branch_* / claude_echo_pending_* / claude_iterate_count_* 등 전 패턴
# SSOT: backlog_harness-audit-followup F1 (2026-05-20 GC 범위 확장)
find /tmp -maxdepth 1 -name 'claude_*' -mtime +7 -delete 2>/dev/null

# skill-creator 락 파일 잔여 정리 (이전 세션에서 미삭제 가능성 차단, 2026-05-26 경로 이전 — gate-init L26 GC 와 별도 즉시 정리)
rm -f "/tmp/claude_skill_creator_active.lock" 2>/dev/null

exit 0
