#!/bin/bash
# PreToolUse Hook: 보호 대상 파일 Edit/Write 물리적 차단
# Phase 1 Harness — exit 2로 도구 호출 자체를 차단
#
# 차단 카테고리:
#   1. 프론트엔드 파일 (.tsx, .ts, .jsx, .js, .css, .scss, next.config.*, tailwind.config.*, postcss.config.*, middleware.ts)
#   2. 환경변수 파일 (.env, .env.*)
#   3. 잠금 파일 (composer.lock, package-lock.json)
#   4. 인증서/키 파일 (.pem, .key, .p12, .pfx)
#   5. 인증 정보 파일 (credentials, secrets.json, service-account.json)
#   6. 서버 설정 파일 (.htpasswd, .htaccess)
#
# Read는 모든 파일에 허용. Edit/Write만 차단.

STDIN_DATA=$(cat)

TOOL_NAME=$(echo "$STDIN_DATA" | grep -o '"tool_name" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
FILE=$(echo "$STDIN_DATA" | grep -o '"file_path" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# file_path가 없으면 통과
if [ -z "$FILE" ]; then
  exit 0
fi

# Read는 모든 파일 허용
if [[ "$TOOL_NAME" == "Read" ]]; then
  exit 0
fi

# --- 이하 Edit/Write 차단 ---

BASENAME=$(basename "$FILE")
LOWER_BASENAME=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]')

# 1. 프론트엔드 파일 차단 (frontend-guard)
case "$LOWER_BASENAME" in
  *.tsx|*.jsx)
    echo "[BLOCKED] 프론트엔드 파일 수정 차단: $BASENAME — frontend-guard 정책. 프론트엔드 담당자에게 요청하세요." >&2
    exit 2 ;;
  *.ts)
    echo "[BLOCKED] TypeScript 파일 수정 차단: $BASENAME — frontend-guard 정책." >&2
    exit 2 ;;
  *.js)
    echo "[BLOCKED] JavaScript 파일 수정 차단: $BASENAME — frontend-guard 정책." >&2
    exit 2 ;;
  *.css|*.scss)
    echo "[BLOCKED] 스타일 파일 수정 차단: $BASENAME — frontend-guard 정책." >&2
    exit 2 ;;
  next.config.*|tailwind.config.*|postcss.config.*|middleware.ts)
    echo "[BLOCKED] 프론트엔드 설정 파일 수정 차단: $BASENAME — frontend-guard 정책." >&2
    exit 2 ;;
esac

# 2. 환경변수 파일 차단
if [[ "$LOWER_BASENAME" == ".env" || "$LOWER_BASENAME" == .env.* ]]; then
  echo "[BLOCKED] 환경변수 파일 수정 차단: $BASENAME — 수동으로 편집하세요." >&2
  exit 2
fi

# 3. 잠금 파일 차단
if [[ "$LOWER_BASENAME" == "composer.lock" || "$LOWER_BASENAME" == "package-lock.json" ]]; then
  echo "[BLOCKED] 잠금 파일 수정 차단: $BASENAME — composer/npm 명령으로 관리하세요." >&2
  exit 2
fi

# 4. 인증서/키 파일 차단
case "$LOWER_BASENAME" in
  *.pem|*.key|*.p12|*.pfx)
    echo "[BLOCKED] 인증서/키 파일 수정 차단: $BASENAME — Read만 허용됩니다." >&2
    exit 2 ;;
esac

# 5. 인증 정보 파일 차단
case "$LOWER_BASENAME" in
  credentials|credentials.json|secrets.json|service-account.json)
    echo "[BLOCKED] 인증 정보 파일 수정 차단: $BASENAME — Read만 허용됩니다." >&2
    exit 2 ;;
esac

# 6. 서버 설정 파일 차단
case "$LOWER_BASENAME" in
  .htpasswd|.htaccess)
    echo "[BLOCKED] 서버 설정 파일 수정 차단: $BASENAME — Read만 허용됩니다." >&2
    exit 2 ;;
esac

# 차단 대상 아님 — 통과
exit 0
