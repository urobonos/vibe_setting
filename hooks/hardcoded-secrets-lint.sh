#!/bin/bash
# PostToolUse Hook: 하드코딩 시크릿/키 감지
# 경고(exit 0) — 감지 시 Claude에게 수정 유도 메시지 주입
#
# 감지 대상:
#   1. API 키 패턴 (sk-, pk_, AKIA 등)
#   2. 비밀번호 할당 (password = "...", secret = "...")
#   3. JWT/토큰 하드코딩
#   4. 연결 문자열 (mysql://, postgresql://)

STDIN_DATA=$(cat)

FILE=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# 파일 경로 없으면 통과
if [ -z "$FILE" ]; then
  exit 0
fi

# 파일 존재 확인
if [ ! -f "$FILE" ]; then
  exit 0
fi

# 검사 제외 대상
# - .env 파일 (sensitive-file-guard에서 이미 차단)
# - 테스트 파일 (mock 데이터 허용)
# - 설정 예제 (.example, .sample, .dist)
# - hook 스크립트 자체
# - 문서 파일
if echo "$FILE" | grep -qE '(\.env|\.example|\.sample|\.dist|tests/|Tests/|\.claude/hooks/|\.md$|\.txt$)'; then
  exit 0
fi

WARNINGS=""
COUNT=0

# 1. AWS 키 패턴 (AKIA로 시작하는 20자)
AWS_KEY=$(grep -nE 'AKIA[0-9A-Z]{16}' "$FILE" 2>/dev/null)
if [ -n "$AWS_KEY" ]; then
  WARNINGS="${WARNINGS}\n[AWS 키 하드코딩] AKIA... 패턴 감지 → 환경변수 또는 AWS Secrets Manager 사용:\n${AWS_KEY}\n"
  ((COUNT++))
fi

# 2. Stripe 키 패턴 (sk_live_, pk_live_, sk_test_, pk_test_)
STRIPE_KEY=$(grep -nE "(sk|pk)_(live|test)_[A-Za-z0-9]{20,}" "$FILE" 2>/dev/null)
if [ -n "$STRIPE_KEY" ]; then
  WARNINGS="${WARNINGS}\n[Stripe 키 하드코딩] sk_/pk_ 패턴 감지 → .env로 이동:\n${STRIPE_KEY}\n"
  ((COUNT++))
fi

# 3. 비밀번호/시크릿 할당 (따옴표 안에 실제 값)
# 패턴: password/secret/api_key/token = "실제값" (빈 문자열, env(), getenv, placeholder 제외)
SECRET_ASSIGN=$(grep -nEi "(password|secret|api_key|apikey|private_key|access_token)\s*[=:]\s*['\"][^'\"]{8,}['\"]" "$FILE" 2>/dev/null \
  | grep -viE '(env\(|getenv|XXXX|example|placeholder|your_|changeme|password_here|TODO|config\(|\.env)' 2>/dev/null)
if [ -n "$SECRET_ASSIGN" ]; then
  WARNINGS="${WARNINGS}\n[시크릿 하드코딩 의심] 비밀번호/키 직접 할당 감지 → .env 또는 Secrets Manager 사용:\n${SECRET_ASSIGN}\n"
  ((COUNT++))
fi

# 4. JWT 하드코딩 (eyJ로 시작하는 긴 문자열)
JWT_HARD=$(grep -nE 'eyJ[A-Za-z0-9_-]{20,}\.' "$FILE" 2>/dev/null)
if [ -n "$JWT_HARD" ]; then
  WARNINGS="${WARNINGS}\n[JWT 하드코딩] eyJ... 토큰 감지 → 동적 발급 또는 환경변수 사용:\n${JWT_HARD}\n"
  ((COUNT++))
fi

# 5. DB 연결 문자열 하드코딩
DB_CONN=$(grep -nE '(mysql|postgresql|mongodb|redis)://[^$\{]+@' "$FILE" 2>/dev/null \
  | grep -viE '(example|localhost|127\.0\.0\.1|placeholder|your_)' 2>/dev/null)
if [ -n "$DB_CONN" ]; then
  WARNINGS="${WARNINGS}\n[DB 연결 문자열 하드코딩] 접속 정보 감지 → .env로 이동:\n${DB_CONN}\n"
  ((COUNT++))
fi

# 경고 출력
if [ "$COUNT" -gt 0 ]; then
  echo ""
  echo "━━━ Secrets Lint: ${COUNT}건 하드코딩 시크릿 감지 (${FILE}) ━━━"
  echo -e "$WARNINGS"
  echo "시크릿을 코드에 직접 포함하지 마세요. .env 또는 Secrets Manager를 사용하세요."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
