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

# 세션 시작 시 gate 리셋
echo "0" > "$GATE_FILE"

# stale gate 파일 정리 (7일 이상 미수정 — 활성 세션 파일은 mtime 갱신되어 보존)
find /tmp -maxdepth 1 -name 'claude_gate_*' -mtime +7 -delete 2>/dev/null

# skill-creator 락 파일 잔여 정리 (이전 세션에서 미삭제 가능성 차단)
rm -f "$HOME/.claude/.skill-creator-active.lock" 2>/dev/null

exit 0
