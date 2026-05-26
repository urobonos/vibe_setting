#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# SessionStart Hook: 워크플로우 Gate 상태 초기화
# Phase 3 Harness — 세션 시작 시 gate를 0(잠금)으로 리셋
#
# Gate 레벨:
#   0 = LOCKED   — Edit/Write 차단, 분석 필요
#   1 = GATE1    — 분석 승인됨, 계획 단계
#   2 = GATE2    — 계획 승인됨, Edit/Write 허용

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_session_id

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"

# 자동 순차 진행 정책 (2026-05-12): 세션 시작 시 gate = 2 (EXECUTE) 초기화
# 단계별 차단 폐기 — §3 Checkpoint 5조건 보호는 별 hook (dangerous-ops-guard / branch-enforce / git-quality-gate 등)
# SSOT: ~/.claude/CLAUDE.md §"자동 순차 진행 정책"
echo "2" > "$GATE_FILE"

# stale claude_* 마커 정리 (7일 이상 미수정 — 활성 세션 마커는 mtime 갱신되어 보존)
# 대상: claude_gate_* / claude_edit_flag_* / claude_selfcheck_done_* / claude_completeness_warned_*
#       claude_statusline_branch_* / claude_echo_pending_* / claude_iterate_count_* 등 전 패턴
# SSOT: backlog_harness-audit-followup F1 (2026-05-20 GC 범위 확장)
find /tmp -maxdepth 1 -name 'claude_*' -mtime +7 -delete 2>/dev/null

# skill-creator 락 파일 잔여 정리 (이전 세션에서 미삭제 가능성 차단, 2026-05-26 경로 이전 — gate-init L26 GC 와 별도 즉시 정리)
rm -f "/tmp/claude_skill_creator_active.lock" 2>/dev/null

exit 0
