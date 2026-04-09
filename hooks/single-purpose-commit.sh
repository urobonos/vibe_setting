#!/bin/bash
# PreToolUse Hook: 1 커밋 = 1 변경 검증
# exit 2 차단 — staged diff에서 여러 모듈/레이어 혼합 감지
#
# 검사: git commit 시 staged 파일들의 변경 범위 확인
#   - 3개 이상 서로 다른 BC 모듈 동시 변경 → 차단
#   - feat 타입인데 test 외 다른 레이어(docs, config) 혼합 → 경고

STDIN_DATA=$(cat)

TOOL_NAME=$(echo "$STDIN_DATA" | grep -o '"tool_name" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

COMMAND=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# git commit 명령만 검사
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

# --amend, merge 등 제외
if echo "$COMMAND" | grep -qE '(--amend|--allow-empty|--no-edit)'; then
  exit 0
fi

# staged 파일 목록으로 모듈 범위 확인
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# BC 모듈 수 세기 (app/Modules/{BC}/)
MODULE_COUNT=$(echo "$STAGED_FILES" | grep -oE 'app/Modules/[A-Za-z]+' | sort -u | wc -l)

# docs, config 등 인프라 파일 혼합 확인
HAS_DOCS=$(echo "$STAGED_FILES" | grep -cE '^docs/' 2>/dev/null)
HAS_CONFIG=$(echo "$STAGED_FILES" | grep -cE '^app/Config/' 2>/dev/null)
HAS_MODULE=$(echo "$STAGED_FILES" | grep -cE '^app/Modules/' 2>/dev/null)

# 3개 이상 모듈 동시 변경 → 차단
if [ "$MODULE_COUNT" -ge 3 ]; then
  MODULES=$(echo "$STAGED_FILES" | grep -oE 'app/Modules/[A-Za-z]+' | sort -u | sed 's|app/Modules/||')
  echo "[BLOCKED] 1 커밋 1 변경 위반 — ${MODULE_COUNT}개 모듈 동시 변경 감지" >&2
  echo "  모듈: $MODULES" >&2
  echo "  각 모듈별로 커밋을 분리하세요." >&2
  exit 2
fi

# 모듈 코드 + docs/config 혼합 → 경고 (차단은 아님)
if [ "$HAS_MODULE" -gt 0 ] && [ "$HAS_DOCS" -gt 0 ] && [ "$HAS_CONFIG" -gt 0 ]; then
  echo ""
  echo "━━━ 커밋 범위 경고 ━━━"
  echo "[WARNING] 모듈 코드 + docs + config가 혼합되어 있습니다."
  echo "  가능하면 코드/문서/설정을 별도 커밋으로 분리하세요."
  echo "━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
