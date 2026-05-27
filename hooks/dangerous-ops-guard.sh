#!/usr/bin/env bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "dangerous-ops-guard" "enter" "pid=$$"

# block telemetry wrapper (Phase 2b) — 정의 실패와 독립: log_event 미정의여도 echo+exit 2 항상 보장 (C1/H1)
block_exit() {
  command -v log_event >/dev/null 2>&1 && log_event "dangerous-ops-guard" "block" "reason=$1"
  echo "$2" >&2
  exit 2
}

# PreToolUse Hook: 파괴적 명령 차단 + 비가역적 작업 Checkpoint 경고
# 통합: dangerous-command-guard.sh + checkpoint-guard.sh
#
# 1단계: 파괴적 Bash 명령 물리적 차단 (exit 2)
#   - rm -rf/-r/-f, git push --force, reset --hard, clean -f, branch -D, checkout/restore .
#   - DROP/TRUNCATE, kill -9/pkill/killall, chmod 777, chown, Co-Authored-By
# 2단계: Checkpoint 경고 (exit 0, stdout 주입)
#   - DB 마이그레이션 파일 생성/수정 (Write/Edit)
#   - 프로덕션 SSM 명령 (Bash)
#   - 마이그레이션 실행 (Bash)

STDIN_DATA=$(cat)

TOOL_NAME=$(echo "$STDIN_DATA" | grep -o '"tool_name" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# --- Write/Edit: DB 마이그레이션 파일 Checkpoint ---
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
    echo "사용자 승인을 받은 뒤 Claude 가 직접 실행합니다. 승인 요청 시 다음을 보고하세요:"
    echo "  1. 변경할 테이블/컬럼 목록"
    echo "  2. 기존 데이터 영향 범위"
    echo "  3. 롤백 전략"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  exit 0
fi

# --- Bash 도구만 검사 ---
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

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

LOWER_CMD=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

# ===== 파괴적 명령 차단 (exit 2) =====

# 1. 파일 삭제 — rm -rf, rm -r, rm -f
if echo "$COMMAND" | grep -qE '^\s*rm\s+-(r|f|rf|fr)\b'; then
  block_exit "rm-rf" "[BLOCKED] 파괴적 삭제 명령 차단: rm with -r/-f 플래그 — 삭제 대상을 확인하고 사용자에게 승인을 요청하세요."
fi

# 2. Git 파괴적 명령
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force'; then
  block_exit "force-push" "[BLOCKED] force push 차단 — 원격 히스토리가 파괴됩니다. 사용자 명시 승인 후 수동 실행하세요."
fi
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  block_exit "reset-hard" "[BLOCKED] git reset --hard 차단 — 커밋되지 않은 변경이 모두 손실됩니다. 사용자 승인 후 수동 실행하세요."
fi
if echo "$COMMAND" | grep -qE 'git\s+clean\s+.*-f'; then
  block_exit "clean-f" "[BLOCKED] git clean -f 차단 — 추적되지 않는 파일이 삭제됩니다. 사용자 승인 후 수동 실행하세요."
fi
if echo "$COMMAND" | grep -qE 'git\s+branch\s+.*-D\b'; then
  block_exit "branch-D" "[BLOCKED] git branch -D 차단 — 머지되지 않은 브랜치가 삭제됩니다. git branch -d 또는 사용자 승인 후 수동 실행하세요."
fi
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+\.\s*$'; then
  block_exit "checkout-dot" "[BLOCKED] git checkout . 차단 — 모든 수정사항이 되돌려집니다. 사용자 승인 후 수동 실행하세요."
fi
if echo "$COMMAND" | grep -qE 'git\s+restore\s+\.\s*$'; then
  block_exit "restore-dot" "[BLOCKED] git restore . 차단 — 모든 수정사항이 되돌려집니다. 사용자 승인 후 수동 실행하세요."
fi

# 3. DB 파괴적 명령
if echo "$LOWER_CMD" | grep -qE 'drop[[:space:]]+(table|database)|truncate[[:space:]]+table'; then
  block_exit "db-drop-truncate" "[BLOCKED] DB 파괴 명령 차단: DROP/TRUNCATE 감지 — 사용자 승인 후 수동 실행하세요."
fi

# 4. 프로세스 강제 종료
if echo "$COMMAND" | grep -qE '(kill\s+-9|pkill\s|killall\s)'; then
  block_exit "kill-process" "[BLOCKED] 프로세스 강제 종료 차단 — 서비스 중단 위험. 사용자 승인 후 수동 실행하세요."
fi

# 5. 위험한 권한 변경
if echo "$COMMAND" | grep -qE 'chmod\s+777'; then
  block_exit "chmod-777" "[BLOCKED] chmod 777 차단 — 보안 취약점. 최소 권한 원칙에 따라 적절한 권한을 설정하세요."
fi
if echo "$COMMAND" | grep -qE '^\s*chown\s'; then
  block_exit "chown" "[BLOCKED] chown 차단 — 파일 소유권 변경은 사용자 승인 후 수동 실행하세요."
fi

# 6. Co-Authored-By trailer 차단 (라인 시작 + 콜론 형식만 매칭, 본문 단어 언급은 허용)
# CLAUDE.md §4 "공동 작성자 trailer 라인 금지" SSOT 룰. trailer 형식(예: "Co-Authored-By: Claude...")만 차단.
# 본문에 "Co-Authored-By 단일화" 같이 설명용 단어 사용은 통과 (이전 차단 false positive 회피).
if echo "$LOWER_CMD" | grep -qE '^[[:space:]]*co-authored-by:'; then
  block_exit "co-authored-by" "[BLOCKED] Co-Authored-By trailer 차단 — 커밋 메시지 끝의 Co-Authored-By: 형식 trailer 라인은 사용하지 마세요. (본문 내 단어 언급은 허용)"
fi

# ===== Checkpoint 경고 (exit 0) =====

# SSM send-command
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

# php spark migrate
if echo "$COMMAND" | grep -qE 'php\s+spark\s+migrate'; then
  echo ""
  echo "━━━ CHECKPOINT: DB 마이그레이션 실행 감지 ━━━"
  echo "명령: $COMMAND"
  echo ""
  echo "DB 마이그레이션은 비가역적 작업입니다."
  echo "사용자 승인을 받은 뒤 Claude 가 직접 실행합니다. 승인 요청 시 명령 내용과 영향 범위를 보고하세요."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
