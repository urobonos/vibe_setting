#!/bin/bash
# PostToolUse Hook: Service 수정 시 테스트 파일 존재 확인
# 경고(stdout 주입) — "No Test, No Merge" 규칙 강제
#
# 대상: app/Modules/{BC}/Services/*.php 수정 시
# 확인: tests/Modules/{BC}/Unit/*ServiceTest.php 존재 여부

STDIN_DATA=$(cat)

FILE=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# PHP 파일만
if [[ "$FILE" != *.php ]]; then
  exit 0
fi

# Modules Service 파일만 검사
if ! echo "$FILE" | grep -qE 'app/Modules/[A-Za-z]+/Services/[A-Za-z]+\.php'; then
  exit 0
fi

# BC 모듈명과 Service명 추출
BC_NAME=$(echo "$FILE" | grep -oE 'Modules/[A-Za-z]+' | sed 's|Modules/||')
SERVICE_NAME=$(basename "$FILE" .php)

if [ -z "$BC_NAME" ] || [ -z "$SERVICE_NAME" ]; then
  exit 0
fi

# CWD 추출
CWD=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('cwd', '.'))
except:
    print('.')
" 2>/dev/null)

# 테스트 파일 경로 패턴
TEST_DIR="$CWD/tests/Modules/$BC_NAME/Unit"
TEST_FILE="${TEST_DIR}/${SERVICE_NAME}Test.php"

# 테스트 파일 존재 확인
if [ ! -f "$TEST_FILE" ]; then
  # 유사 패턴 검색 (다른 명명 규칙)
  FOUND=$(find "$TEST_DIR" -name "*${SERVICE_NAME}*Test.php" -type f 2>/dev/null | head -1)
  if [ -z "$FOUND" ]; then
    echo ""
    echo "━━━ No Test, No Merge ━━━"
    echo "[TEST 누락] ${BC_NAME}/${SERVICE_NAME} 수정 감지 — 대응 테스트 파일이 없습니다."
    echo "  기대 경로: tests/Modules/${BC_NAME}/Unit/${SERVICE_NAME}Test.php"
    echo "  테스트 파일을 생성하거나, 기존 테스트를 업데이트하세요."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
fi

exit 0
