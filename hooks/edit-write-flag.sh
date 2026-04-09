#!/bin/bash
# PostToolUse:Edit|Write Hook: 세션에서 파일 수정 발생 시 플래그 기록
# session-completeness-check.sh에서 work-history 기록 강제에 사용

STDIN_DATA=$(cat)

SESSION_ID=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('session_id', 'default'))
except:
    print('default')
" 2>/dev/null)

EDIT_FLAG="/tmp/claude_edit_flag_${SESSION_ID}"
touch "$EDIT_FLAG"

exit 0
