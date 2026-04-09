#!/bin/bash
# PreToolUse Hook: 파괴적 Bash 명령 물리적 차단
# Phase 2 Harness — command 패턴 매칭으로 위험 명령 exit 2 차단
#
# 차단 카테고리:
#   1. 파일 삭제 (rm -rf, rm -r, rm -f)
#   2. Git 파괴 (push --force, reset --hard, clean -f, branch -D, checkout .)
#   3. DB 파괴 (DROP TABLE, DROP DATABASE, TRUNCATE)
#   4. 프로세스 종료 (kill -9, pkill, killall)
#   5. 권한 변경 (chmod 777, chown)

STDIN_DATA=$(cat)

TOOL_NAME=$(echo "$STDIN_DATA" | grep -o '"tool_name" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# Bash 도구만 검사
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Python으로 정확한 JSON 파싱 (이스케이프 따옴표 처리)
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

# 소문자 변환
LOWER_CMD=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

# 1. 파일 삭제 — rm -rf, rm -r, rm -f (단순 rm file.txt는 허용)
if echo "$COMMAND" | grep -qE '^\s*rm\s+-(r|f|rf|fr)\b'; then
  echo "[BLOCKED] 파괴적 삭제 명령 차단: rm with -r/-f 플래그 — 삭제 대상을 확인하고 사용자에게 승인을 요청하세요." >&2
  exit 2
fi

# 2. Git 파괴적 명령
# 2a. force push
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force'; then
  echo "[BLOCKED] force push 차단 — 원격 히스토리가 파괴됩니다. 사용자 명시 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 2b. reset --hard
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo "[BLOCKED] git reset --hard 차단 — 커밋되지 않은 변경이 모두 손실됩니다. 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 2c. clean -f
if echo "$COMMAND" | grep -qE 'git\s+clean\s+.*-f'; then
  echo "[BLOCKED] git clean -f 차단 — 추적되지 않는 파일이 삭제됩니다. 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 2d. branch -D (강제 삭제)
if echo "$COMMAND" | grep -qE 'git\s+branch\s+.*-D\b'; then
  echo "[BLOCKED] git branch -D 차단 — 머지되지 않은 브랜치가 삭제됩니다. git branch -d 또는 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 2e. checkout . (전체 되돌리기)
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+\.\s*$'; then
  echo "[BLOCKED] git checkout . 차단 — 모든 수정사항이 되돌려집니다. 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 2f. restore . (전체 되돌리기)
if echo "$COMMAND" | grep -qE 'git\s+restore\s+\.\s*$'; then
  echo "[BLOCKED] git restore . 차단 — 모든 수정사항이 되돌려집니다. 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 3. DB 파괴적 명령 (mysql, php spark 등에서 실행 가능)
if echo "$LOWER_CMD" | grep -qE 'drop[[:space:]]+(table|database)|truncate[[:space:]]+table'; then
  echo "[BLOCKED] DB 파괴 명령 차단: DROP/TRUNCATE 감지 — 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 4. 프로세스 강제 종료
if echo "$COMMAND" | grep -qE '(kill\s+-9|pkill\s|killall\s)'; then
  echo "[BLOCKED] 프로세스 강제 종료 차단 — 서비스 중단 위험. 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 5. 위험한 권한 변경
if echo "$COMMAND" | grep -qE 'chmod\s+777'; then
  echo "[BLOCKED] chmod 777 차단 — 보안 취약점. 최소 권한 원칙에 따라 적절한 권한을 설정하세요." >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '^\s*chown\s'; then
  echo "[BLOCKED] chown 차단 — 파일 소유권 변경은 사용자 승인 후 수동 실행하세요." >&2
  exit 2
fi

# 6. Co-Authored-By 차단 (git commit 메시지에 포함 금지)
if echo "$LOWER_CMD" | grep -qE 'co-authored-by'; then
  echo "[BLOCKED] Co-Authored-By 차단 — 커밋 메시지에 Co-Authored-By 라인을 포함하지 마세요." >&2
  exit 2
fi

# 차단 대상 아님 — 통과
exit 0
