#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "post-action-tracker" "enter" "pid=$$"
# PostToolUse Hook: 수정 이력 기록 + 시크릿 감지 + 테스트 감지
# 통합: edit-write-flag.sh + hardcoded-secrets-lint.sh + test-run-flag.sh
#
# Edit|Write context: 수정 플래그 기록 + 하드코딩 시크릿 검사
# Bash context: 테스트 실행 명령 감지 + 테스트 플래그 기록

STDIN_DATA=$(cat)

# 파싱 — bash 내장 (기존 fast-path grep 다수 + python eval fork 제거). file_path/session_id/tool_name 은 escape 드묾.
FILE_PATH=""; [[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && FILE_PATH="${BASH_REMATCH[1]}"
SESSION_ID=""; [[ "$STDIN_DATA" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && SESSION_ID="${BASH_REMATCH[1]}"
TOOL_NAME=""; [[ "$STDIN_DATA" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && TOOL_NAME="${BASH_REMATCH[1]}"

# fast-path: docs 계열 파일이면 edit_flag 만 기록 후 즉시 종료 (기존 로직 보존)
if [ -n "$FILE_PATH" ] && [[ "${FILE_PATH,,}" =~ \.(md|txt|json|yaml|yml)$ ]]; then
  if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]] && [ -n "$SESSION_ID" ]; then
    touch "/tmp/claude_edit_flag_${SESSION_ID}"
  fi
  exit 0
fi

# 비-docs: SESSION_ID 기본값 + COMMAND 추출 (escape 된 따옴표 있으면 python fallback — secrets/test 감지 정확도)
[ -z "$SESSION_ID" ] && SESSION_ID="default"
COMMAND=""; [[ "$STDIN_DATA" =~ \"command\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && COMMAND="${BASH_REMATCH[1]}"
if [[ "$STDIN_DATA" == *'\"'* ]] && command -v python3 >/dev/null 2>&1; then
  _pc=$(echo "$STDIN_DATA" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('tool_input',{}).get('command','') or '')
except: print('')" 2>/dev/null)
  [ -n "$_pc" ] && COMMAND="$_pc"
fi
COMMAND="${COMMAND//$'\r'/}"; COMMAND="${COMMAND//$'\n'/ }"

# === Edit/Write context: 수정 플래그 + 시크릿 감지 ===
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
  # 수정 이력 플래그 기록
  touch "/tmp/claude_edit_flag_${SESSION_ID}"

  # 시크릿 감지 (file_path 기반)
  if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
    # 검사 제외 대상
    if ! echo "$FILE_PATH" | grep -qE '(\.env|\.example|\.sample|\.dist|tests/|Tests/|\.claude/hooks/|\.md$|\.txt$)'; then
      WARNINGS=""
      COUNT=0

      # 1. AWS 키 패턴 (AKIA로 시작하는 20자)
      AWS_KEY=$(grep -nE 'AKIA[0-9A-Z]{16}' "$FILE_PATH" 2>/dev/null)
      if [ -n "$AWS_KEY" ]; then
        WARNINGS="${WARNINGS}\n[AWS 키 하드코딩] AKIA... 패턴 감지 → 환경변수 또는 AWS Secrets Manager 사용:\n${AWS_KEY}\n"
        ((COUNT++))
      fi

      # 2. Stripe 키 패턴
      STRIPE_KEY=$(grep -nE "(sk|pk)_(live|test)_[A-Za-z0-9]{20,}" "$FILE_PATH" 2>/dev/null)
      if [ -n "$STRIPE_KEY" ]; then
        WARNINGS="${WARNINGS}\n[Stripe 키 하드코딩] sk_/pk_ 패턴 감지 → .env로 이동:\n${STRIPE_KEY}\n"
        ((COUNT++))
      fi

      # 3. 비밀번호/시크릿 할당
      SECRET_ASSIGN=$(grep -nEi "(password|secret|api_key|apikey|private_key|access_token)\s*[=:]\s*['\"][^'\"]{8,}['\"]" "$FILE_PATH" 2>/dev/null \
        | grep -viE '(env\(|getenv|XXXX|example|placeholder|your_|changeme|password_here|TODO|config\(|\.env)' 2>/dev/null)
      if [ -n "$SECRET_ASSIGN" ]; then
        WARNINGS="${WARNINGS}\n[시크릿 하드코딩 의심] 비밀번호/키 직접 할당 감지 → .env 또는 Secrets Manager 사용:\n${SECRET_ASSIGN}\n"
        ((COUNT++))
      fi

      # 4. JWT 하드코딩
      JWT_HARD=$(grep -nE 'eyJ[A-Za-z0-9_-]{20,}\.' "$FILE_PATH" 2>/dev/null)
      if [ -n "$JWT_HARD" ]; then
        WARNINGS="${WARNINGS}\n[JWT 하드코딩] eyJ... 토큰 감지 → 동적 발급 또는 환경변수 사용:\n${JWT_HARD}\n"
        ((COUNT++))
      fi

      # 5. DB 연결 문자열 하드코딩
      DB_CONN=$(grep -nE '(mysql|postgresql|mongodb|redis)://[^$\{]+@' "$FILE_PATH" 2>/dev/null \
        | grep -viE '(example|localhost|127\.0\.0\.1|placeholder|your_)' 2>/dev/null)
      if [ -n "$DB_CONN" ]; then
        WARNINGS="${WARNINGS}\n[DB 연결 문자열 하드코딩] 접속 정보 감지 → .env로 이동:\n${DB_CONN}\n"
        ((COUNT++))
      fi

      # 경고 출력
      if [ "$COUNT" -gt 0 ]; then
        echo ""
        echo "━━━ Secrets Lint: ${COUNT}건 하드코딩 시크릿 감지 (${FILE_PATH}) ━━━"
        echo -e "$WARNINGS"
        echo "시크릿을 코드에 직접 포함하지 마세요. .env 또는 Secrets Manager를 사용하세요."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      fi
    fi
  fi
fi

# === Bash context: 테스트 실행 감지 ===
if [[ "$TOOL_NAME" == "Bash" ]]; then
  if echo "$COMMAND" | grep -qiE '(phpunit|composer\s+test|npm\s+test|npx\s+jest|npx\s+vitest|pytest|php\s+artisan\s+test)'; then
    touch "/tmp/claude_test_run_${SESSION_ID}"
  fi
fi

exit 0
