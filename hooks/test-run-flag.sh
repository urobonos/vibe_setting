#!/bin/bash
# PostToolUse:Bash Hook: 테스트 실행 감지 시 플래그 파일 생성
# no-test-no-merge.sh와 연동 — 테스트 실행 이력 기록

STDIN_DATA=$(cat)

eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', 'default')
    cmd = data.get('tool_input', {}).get('command', '')
    print(f'SESSION_ID=\"{sid}\"')
    safe = cmd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"').replace('\n', ' ')
    print(f'COMMAND=\"{safe}\"')
except:
    print('SESSION_ID=\"default\"')
    print('COMMAND=\"\"')
" 2>/dev/null)"

# 테스트 실행 명령 감지
if echo "$COMMAND" | grep -qiE '(phpunit|composer\s+test|npm\s+test|npx\s+jest|npx\s+vitest|pytest|php\s+artisan\s+test)'; then
  TEST_FLAG="/tmp/claude_test_run_${SESSION_ID}"
  touch "$TEST_FLAG"
fi

exit 0
