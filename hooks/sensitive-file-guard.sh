#!/bin/bash
# PreToolUse Hook: 민감 파일 접근 차단
# credentials, .htpasswd 등 보안 파일 전면 차단
# .pem/.key 는 Read만 허용, Edit/Write 차단
# .env 는 허용 (개발 중 수정 필요)

STDIN_DATA=$(cat)

# stdin JSON에서 tool_name과 file_path 추출 (python 의존 제거)
TOOL_NAME=$(echo "$STDIN_DATA" | grep -o '"tool_name" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
FILE=$(echo "$STDIN_DATA" | grep -o '"file_path" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

if [ -z "$FILE" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE")
LOWER_BASENAME=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]')

BLOCKED=false
REASON=""

# PEM/키 파일 계열 — Read 허용, Edit/Write 차단
if [[ "$LOWER_BASENAME" == *.pem || "$LOWER_BASENAME" == *.key || "$LOWER_BASENAME" == *.p12 || "$LOWER_BASENAME" == *.pfx ]]; then
  if [[ "$TOOL_NAME" != "Read" ]]; then
    BLOCKED=true
    REASON="인증서/키 파일 수정 차단: $FILE (Read만 허용)"
  fi
fi

# credentials 파일 계열 — Read 허용, Edit/Write 차단
if [[ "$LOWER_BASENAME" == "credentials" || "$LOWER_BASENAME" == "credentials.json" || "$LOWER_BASENAME" == "secrets.json" || "$LOWER_BASENAME" == "service-account.json" ]]; then
  if [[ "$TOOL_NAME" != "Read" ]]; then
    BLOCKED=true
    REASON="인증 정보 파일 수정 차단: $FILE (Read만 허용)"
  fi
fi

# .htpasswd, .htaccess — Read 허용, Edit/Write 차단
if [[ "$LOWER_BASENAME" == ".htpasswd" || "$LOWER_BASENAME" == ".htaccess" ]]; then
  if [[ "$TOOL_NAME" != "Read" ]]; then
    BLOCKED=true
    REASON="서버 설정 파일 수정 차단: $FILE (Read만 허용)"
  fi
fi

if [ "$BLOCKED" = true ]; then
  echo "{\"decision\":\"deny\",\"reason\":\"$REASON — Checkpoint 필요. 사용자 승인 후 수동 접근하세요.\"}"
  exit 0
fi

exit 0
