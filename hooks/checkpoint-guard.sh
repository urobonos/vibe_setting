#!/bin/bash
# PreToolUse Hook: 비가역적 작업 Checkpoint 경고
# 경고(exit 0, stdout 주입) — 차단하지 않지만 Claude에게 Checkpoint 발동 의무 전달
#
# 감지 대상:
#   1. DB 마이그레이션 파일 생성/수정 (Write/Edit → app/Database/Migrations/)
#   2. 프로덕션 SSM 명령 (Bash → aws ssm send-command)
#   3. 마이그레이션 실행 (Bash → php spark migrate)

STDIN_DATA=$(cat)

TOOL_NAME=$(echo "$STDIN_DATA" | grep -o '"tool_name" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# --- Write/Edit 도구: 마이그레이션 파일 감지 ---
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
  FILE=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

  if echo "$FILE" | grep -qE 'app/Database/Migrations/'; then
    echo ""
    echo "━━━ CHECKPOINT: DB 마이그레이션 파일 감지 ━━━"
    echo "파일: $FILE"
    echo ""
    echo "DB 스키마 변경은 비가역적 작업입니다."
    echo "반드시 사용자에게 다음을 확인받으세요:"
    echo "  1. 변경할 테이블/컬럼 목록"
    echo "  2. 기존 데이터 영향 범위"
    echo "  3. 롤백 전략"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  exit 0
fi

# --- Bash 도구: SSM 명령 / 마이그레이션 실행 감지 ---
if [[ "$TOOL_NAME" == "Bash" ]]; then
  COMMAND=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

  if [ -z "$COMMAND" ]; then
    exit 0
  fi

  # 프로덕션 SSM send-command 감지
  if echo "$COMMAND" | grep -qE 'aws\s+ssm\s+send-command'; then
    echo ""
    echo "━━━ CHECKPOINT: 프로덕션 서버 원격 명령 감지 ━━━"
    echo "명령: $COMMAND"
    echo ""
    echo "프로덕션 서버에 명령을 전송합니다."
    echo "반드시 사용자에게 다음을 확인받으세요:"
    echo "  1. 실행할 명령의 정확한 내용"
    echo "  2. 서비스 영향 범위"
    echo "  3. 롤백 방법"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  # 마이그레이션 실행 감지
  if echo "$COMMAND" | grep -qE 'php\s+spark\s+migrate'; then
    echo ""
    echo "━━━ CHECKPOINT: DB 마이그레이션 실행 감지 ━━━"
    echo "명령: $COMMAND"
    echo ""
    echo "DB 마이그레이션은 비가역적 작업입니다."
    echo "반드시 사용자에게 실행 승인을 받으세요."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  exit 0
fi

exit 0
