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

# JSON 추출 — bash 내장 정규식 (fork 제거: echo|grep|head|sed 8개 → 0개, grep -o|head -1 첫 매치 취득과 동일)
TOOL_NAME=""; FILE=""
[[ "$STDIN_DATA" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && TOOL_NAME="${BASH_REMATCH[1]}"
[[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && FILE="${BASH_REMATCH[1]}"

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
FILE="${FILE#"${FILE%%[![:space:]]*}"}"; FILE="${FILE%"${FILE##*[![:space:]]}"}"
BASENAME="${FILE##*/}"
LOWER_BASENAME="${BASENAME,,}"
LOWER_FILE="${FILE,,}"; LOWER_FILE="${LOWER_FILE//\\//}"
while [[ "$LOWER_FILE" == *//* ]]; do LOWER_FILE="${LOWER_FILE//\/\///}"; done

# 프로젝트별 예외 경로는 하드코딩하지 않고 면제 목록 파일에 위임한다.
# 글로벌 훅은 공통 정책만 유지 (프로젝트 특정 bypass 하드코딩 금지).
#
# 면제 목록: ~/.claude/hooks/sensitive-exempt.txt (1줄 1패턴, `#` 주석·빈 줄 무시)
#   - 대상은 아래 "1. 프론트엔드 파일" 카테고리 한정.
#     .env·잠금·인증서/키·인증정보·서버설정(2~6번)은 면제 불가 — fail-safe.
#   - 매칭은 정규화된 소문자 절대경로에 bash glob. `*` 는 `/` 도 매칭한다.
#   - 목록을 프로젝트 로컬 .claude/ 에 두지 않는 이유: 로컬 .claude/ 는 worktree checkout 에서
#     빠지므로(skip-worktree) 같은 파일이 메인에서는 통과하고 worktree 에서는 차단된다.
FE_EXEMPT=0
EXEMPT_LIST="$(dirname "${BASH_SOURCE[0]}")/sensitive-exempt.txt"
if [ -f "$EXEMPT_LIST" ]; then
  while IFS= read -r EXEMPT_PAT || [ -n "$EXEMPT_PAT" ]; do
    EXEMPT_PAT="${EXEMPT_PAT%%#*}"
    EXEMPT_PAT="${EXEMPT_PAT#"${EXEMPT_PAT%%[![:space:]]*}"}"
    EXEMPT_PAT="${EXEMPT_PAT%"${EXEMPT_PAT##*[![:space:]]}"}"
    [ -z "$EXEMPT_PAT" ] && continue
    EXEMPT_PAT="${EXEMPT_PAT,,}"; EXEMPT_PAT="${EXEMPT_PAT//\\//}"
    if [[ "$LOWER_FILE" == $EXEMPT_PAT ]]; then
      FE_EXEMPT=1
      command -v log_event >/dev/null 2>&1 && log_event "sensitive-file-guard" "fe-exempt" "pattern=$EXEMPT_PAT"
      break
    fi
  done < "$EXEMPT_LIST"
fi

# 1. 프론트엔드 파일 차단 — Read만 허용, Edit/Write 차단
#    이 정책이 부적절한 경로는 위 면제 목록으로 통과시킨다.
if [ "$FE_EXEMPT" = "0" ]; then
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
fi   # FE_EXEMPT — 면제는 1번 카테고리에서 끝난다. 아래 2~6번은 면제 무관 항상 검사.

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
