#!/bin/bash
# PostToolUse Hook: Write/Edit 후 PHP 파일 문법 검증
# 잘못된 PHP 코드가 작성되는 것을 감지

STDIN_DATA=$(cat)
FILE=$(echo "$STDIN_DATA" | grep -o '"file_path" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

if [ -z "$FILE" ]; then
  exit 0
fi

# PHP 파일만 검증
if [[ "$FILE" == *.php ]]; then
  RESULT=$(php -l "$FILE" 2>&1)
  if echo "$RESULT" | grep -q "Parse error\|Fatal error"; then
    echo "PHP 문법 오류 감지: $RESULT — 해당 라인을 확인하고 Edit 도구로 수정하세요."
    exit 1
  fi
fi

exit 0
