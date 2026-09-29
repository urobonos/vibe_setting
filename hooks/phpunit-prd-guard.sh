#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "phpunit-prd-guard" "enter" "pid=$$"
# PreToolUse Hook: phpunit 실행 전 .env의 database.default.hostname이 prd Aurora를 가리키면 차단
# 2026-04-22 phpunit-prd-db-incident 재발 방지 (Phase 5)
#
# 차단 조건:
#   1) Bash 명령어에 phpunit 포함
#   2) CWD의 .env에서 database.default.hostname 값이 prd 패턴에 매칭
#      (prod-rdsproxy-*, prod-aurora-*, *.rds.amazonaws.com)
#   3) 그리고 phpunit.xml.dist에 CI_ENVIRONMENT=testing 강제 세팅이 없을 때
#
# 통과 조건:
#   - .env 미존재
#   - hostname이 localhost/127.0.0.1/private IP
#   - phpunit.xml.dist가 CI_ENVIRONMENT=testing 를 강제하는 경우 (화이트리스트 방어)
#
# 파싱 (2026-09-29): 구판은 python eval 로 tool_name 을 먼저 뽑고 실패 시 공백 → "Bash 아님" 으로
#   통과했다 = python 장애(WindowsApps 별칭 등)에 조용히 fail-open, 그리고 매 Bash 호출마다 python 1회.
#   → 원문에 phpunit 이 없으면 즉시 통과(파싱 0), 있을 때만 hook-input.sh(bash→python→awk 3단)로 해석.
#   명령을 끝내 못 읽으면 phpunit 후보로 간주하고 .env 검사로 진행한다 (fail-closed).
#   matcher 가 Bash 라 tool_name 검사는 두지 않는다.

STDIN_DATA=$(cat)
case "$STDIN_DATA" in
  *phpunit*) ;;
  *) exit 0 ;;
esac

if ! source "${BASH_SOURCE[0]%/*}/lib/hook-input.sh" 2>/dev/null; then
  echo "[PHPUNIT-PRD-GUARD BLOCKED] hook-input.sh 로드 실패 — phpunit 명령의 DB 대상 판정 불가 (fail-closed)" >&2
  exit 2
fi

hook_parse_command
# cwd 는 escape 해석판으로 — Windows 경로의 `\\` 가 원문 그대로 남으면 .env 를 못 찾아 통과한다
CWD=$(hook_json_string cwd)
[ -z "$CWD" ] && CWD=$(pwd)

# phpunit 명령 아니면 무시 (단어 경계 매칭). 명령을 못 읽었으면(공백) 검사를 계속한다.
if [ -n "$COMMAND" ] && ! echo "$COMMAND" | grep -qE '(^|[[:space:]/;&|])phpunit($|[[:space:];&|])'; then
  exit 0
fi

# .env 파일 확인
ENV_FILE="$CWD/.env"
if [ ! -f "$ENV_FILE" ]; then
  exit 0
fi

# database.default.hostname 추출 (주석 라인 제외, 첫 비주석 매칭만)
DB_HOST=$(grep -E '^[[:space:]]*database\.default\.hostname[[:space:]]*=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | xargs)

if [ -z "$DB_HOST" ]; then
  exit 0
fi

# prd 패턴 매칭 (RDS Proxy / Aurora / AWS RDS 일반)
IS_PRD=false
if echo "$DB_HOST" | grep -qiE '(prod-rdsproxy|prod-aurora|\.rds\.amazonaws\.com)'; then
  IS_PRD=true
fi

if [ "$IS_PRD" = false ]; then
  exit 0
fi

# phpunit.xml.dist 화이트리스트 검사
XML_FILE="$CWD/phpunit.xml.dist"
HAS_OVERRIDE=false
if [ -f "$XML_FILE" ] && grep -qE '<server[[:space:]]+name="CI_ENVIRONMENT"[[:space:]]+value="testing"' "$XML_FILE"; then
  HAS_OVERRIDE=true
fi

if [ "$HAS_OVERRIDE" = false ]; then
  echo "[PHPUNIT-PRD-GUARD BLOCKED] phpunit 실행 차단 — .env의 database.default.hostname이 prd를 가리킵니다: $DB_HOST" >&2
  echo "  → 해결: (1) phpunit.xml.dist 에 <server name=\"CI_ENVIRONMENT\" value=\"testing\" force=\"true\"/> 추가" >&2
  echo "           (2) 또는 .env 의 CI_ENVIRONMENT=testing 전환" >&2
  command -v log_event >/dev/null 2>&1 && log_event "phpunit-prd-guard" "block" "reason=prd-db-host"
  exit 2
fi

exit 0
