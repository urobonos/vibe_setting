#!/bin/bash
# SessionStart Hook: 워크플로우 Gate 상태 초기화
# Phase 3 Harness — 세션 시작 시 gate를 0(잠금)으로 리셋
#
# Gate 레벨:
#   0 = LOCKED   — Edit/Write 차단, 분석 필요
#   1 = GATE1    — 분석 승인됨, 계획 단계
#   2 = GATE2    — 계획 승인됨, Edit/Write 허용

STDIN_DATA=$(cat)

SESSION_ID=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('session_id', 'default'))
except:
    print('default')
" 2>/dev/null)

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"

# 세션 시작 시 gate 리셋
echo "0" > "$GATE_FILE"

exit 0
