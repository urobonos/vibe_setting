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

STDIN_DATA=$(cat)

eval "$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    tn = data.get('tool_name', '')
    ti = data.get('tool_input', {})
    cmd = ti.get('command', '')
    cwd = data.get('cwd', '')
    safe_cmd = cmd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"').replace('\n', ' ')
    safe_cwd = cwd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    print(f'TOOL_NAME=\"{tn}\"')
    print(f'COMMAND=\"{safe_cmd}\"')
    print(f'CWD=\"{safe_cwd}\"')
except:
    print('TOOL_NAME=\"\"')
    print('COMMAND=\"\"')
    print('CWD=\"\"')
" 2>/dev/null)"

# Bash 외 도구 무시
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# phpunit 명령 아니면 무시 (단어 경계 매칭)
if ! echo "$COMMAND" | grep -qE '(^|[[:space:]/;&|])phpunit($|[[:space:];&|])'; then
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
  exit 2
fi

exit 0
