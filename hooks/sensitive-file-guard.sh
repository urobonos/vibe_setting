#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "sensitive-file-guard" "enter" "pid=$$"

# block telemetry wrapper (Phase 2b Stage 2) — 정의 실패와 독립: log_event 미정의여도 echo+exit 2 보장 (C1/H1)
block_exit() {
  command -v log_event >/dev/null 2>&1 && log_event "sensitive-file-guard" "block" "reason=$1"
  echo "$2" >&2
  exit 2
}

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

# trailing/leading 공백 strip (Windows 가 쓰기 시 후행 공백 strip → ".env " 우회 차단, M 2026-06-16)
FILE="$(printf '%s' "$FILE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
BASENAME=$(basename "$FILE")
LOWER_BASENAME=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]')
LOWER_FILE=$(echo "$FILE" | tr '[:upper:]' '[:lower:]' | tr '\\' '/' | sed 's|//*|/|g')

# 프로젝트별 예외 경로는 프로젝트 로컬 .claude/hooks/ 에서 처리한다.
# 글로벌 훅은 공통 정책만 유지 (프로젝트 특정 bypass 하드코딩 금지).

# 1. 프론트엔드 파일 차단 — Read만 허용, Edit/Write 차단
#    이 정책이 부적절한 프로젝트는 프로젝트 로컬 hook에서 선처리하여 면제한다.
case "$LOWER_BASENAME" in
  *.tsx|*.jsx)
    block_exit "fe-tsx" "[BLOCKED] 프론트엔드 파일 수정 차단: $BASENAME — 글로벌 정책상 프론트엔드 파일은 Read 전용입니다." ;;
  *.ts)
    block_exit "fe-ts" "[BLOCKED] TypeScript 파일 수정 차단: $BASENAME — 글로벌 정책상 TypeScript 파일은 Read 전용입니다." ;;
  *.js)
    block_exit "fe-js" "[BLOCKED] JavaScript 파일 수정 차단: $BASENAME — 글로벌 정책상 JavaScript 파일은 Read 전용입니다." ;;
  *.css|*.scss)
    block_exit "style" "[BLOCKED] 스타일 파일 수정 차단: $BASENAME — 글로벌 정책상 스타일 파일은 Read 전용입니다." ;;
  next.config.*|tailwind.config.*|postcss.config.*|middleware.ts)
    block_exit "fe-config" "[BLOCKED] 프론트엔드 설정 파일 수정 차단: $BASENAME — 글로벌 정책상 Read 전용입니다." ;;
  package.json|yarn.lock|pnpm-lock.yaml)
    block_exit "fe-pkg" "[BLOCKED] 프론트엔드 패키지 파일 수정 차단: $BASENAME — npm/yarn/pnpm 명령으로 관리하세요." ;;
esac

# 2. 환경변수 파일 차단 (.env 와 환경별 변형만 차단, .env.example/.env.sample 은 허용)
# CLAUDE.md §4 e2e 검증 — "새 env 변수 참조 시 .env.example 추가" 룰을 hook 이 막지 않도록.
if [[ "$LOWER_BASENAME" == ".env" || "$LOWER_BASENAME" == .env.* ]] \
   && [[ "$LOWER_BASENAME" != ".env.example" && "$LOWER_BASENAME" != ".env.sample" && "$LOWER_BASENAME" != .env.example.* && "$LOWER_BASENAME" != .env.sample.* ]]; then
  block_exit "env" "[BLOCKED] 환경변수 파일 수정 차단: $BASENAME — 수동으로 편집하세요. (.env.example/.env.sample 은 허용)"
fi

# 3. 잠금 파일 차단
if [[ "$LOWER_BASENAME" == "composer.lock" || "$LOWER_BASENAME" == "package-lock.json" ]]; then
  block_exit "lock" "[BLOCKED] 잠금 파일 수정 차단: $BASENAME — composer/npm 명령으로 관리하세요."
fi

# 4. 인증서/키 파일 차단
case "$LOWER_BASENAME" in
  *.pem|*.key|*.p12|*.pfx)
    block_exit "cert-key" "[BLOCKED] 인증서/키 파일 수정 차단: $BASENAME — Read만 허용됩니다." ;;
esac

# 5. 인증 정보 파일 차단
case "$LOWER_BASENAME" in
  credentials|credentials.json|secrets.json|service-account.json)
    block_exit "credentials" "[BLOCKED] 인증 정보 파일 수정 차단: $BASENAME — Read만 허용됩니다." ;;
esac

# 6. 서버 설정 파일 차단
case "$LOWER_BASENAME" in
  .htpasswd|.htaccess)
    block_exit "server-config" "[BLOCKED] 서버 설정 파일 수정 차단: $BASENAME — Read만 허용됩니다." ;;
esac

# 차단 대상 아님 — 통과
exit 0
