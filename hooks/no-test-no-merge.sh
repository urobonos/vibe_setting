#!/bin/bash
# PreToolUse:Bash Hook: git commit 감지 시 테스트 실행 이력 검증
# "No Test, No Merge" — CLAUDE.md §4 Guardrails
#
# 검증 방법: /tmp/claude_test_run_{SESSION_ID} 플래그 파일 존재 여부
# 테스트 실행 감지: php/phpunit/composer test/npm test 등 실행 시 플래그 생성 필요

STDIN_DATA=$(cat)

eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', 'default')
    cmd = data.get('tool_input', {}).get('command', '')
    cwd = data.get('cwd', '.')
    print(f'SESSION_ID=\"{sid}\"')
    safe = cmd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"').replace('\n', ' ')
    print(f'COMMAND=\"{safe}\"')
    safe_cwd = cwd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    print(f'CWD=\"{safe_cwd}\"')
except:
    print('SESSION_ID=\"default\"')
    print('COMMAND=\"\"')
    print('CWD=\".\"')
" 2>/dev/null)"

# git commit 명령이 아니면 통과
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

# --allow-empty 통과 (빈 커밋)
if echo "$COMMAND" | grep -qE '\-\-allow-empty'; then
  exit 0
fi

# 테스트 실행 플래그 확인
TEST_FLAG="/tmp/claude_test_run_${SESSION_ID}"
if [ -f "$TEST_FLAG" ]; then
  exit 0
fi

# 테스트 프레임워크 없는 프로젝트 감지 → 통과
HAS_TEST_FRAMEWORK=false
for marker in "phpunit.xml" "phpunit.xml.dist" "jest.config.js" "jest.config.ts" "pytest.ini" "pyproject.toml" "vitest.config.ts" "vitest.config.js"; do
  if [ -f "$CWD/$marker" ]; then
    HAS_TEST_FRAMEWORK=true
    break
  fi
done

if [ "$HAS_TEST_FRAMEWORK" = false ]; then
  exit 0
fi

echo "[NO TEST, NO MERGE] git commit 차단 — 이번 세션에서 테스트를 실행한 이력이 없습니다." >&2
echo "  phpunit, composer test, npm test 등을 먼저 실행하세요." >&2
echo "  테스트 불필요한 변경이라면 사용자에게 확인 후 진행하세요." >&2
exit 2
