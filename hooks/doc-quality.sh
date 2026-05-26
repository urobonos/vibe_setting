#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "doc-quality" "enter" "pid=$$"
# PostToolUse Hook: 문서 품질 + 테스트 동반 + Notion 동기화
# 통합: doc-checklist-guard.sh + test-coexistence-check.sh + notion-sync-reminder.sh
#
# Fail-fast 순서:
#   1. 문서 체크리스트 최소 개수 검증 (exit 2)
#   2. Service 수정 시 테스트 파일 존재 확인 (warning)
#   3. CLAUDE.md 수정 시 Notion 동기화 플래그 (warning + flag)

STDIN_DATA=$(cat)

eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', {})
    fp = ti.get('file_path', '')
    sid = data.get('session_id', 'default')
    cwd = data.get('cwd', '.')
    safe_fp = fp.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    safe_cwd = cwd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    print(f'FILE_PATH=\"{safe_fp}\"')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'CWD=\"{safe_cwd}\"')
except:
    print('FILE_PATH=\"\"')
    print('SESSION_ID=\"default\"')
    print('CWD=\".\"')
" 2>/dev/null)"

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Windows 백슬래시 → 슬래시
FILE_PATH_UNIX=$(echo "$FILE_PATH" | sed 's|\\|/|g')
BASENAME=$(basename "$FILE_PATH_UNIX")
LOWER_BASENAME=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]')

# ===== 1. 문서 체크리스트 검증 — checklist-count-check.sh 로 위임 (SSOT 일원화) =====
# 정합성 정책: 동일 검증을 doc-quality(exit 2) + checklist-count-check(exit 0) 두 hook 이 중복 수행해
# checklist-count-check 의 stderr 경고가 doc-quality 차단으로 무력화되던 비대칭 해소.
# 체크리스트 개수 검증은 checklist-count-check.sh SSOT (PostToolUse Edit|Write 매처 동일).

# ===== 2. 테스트 동반 확인 (warning) =====
if [[ "$FILE_PATH" == *.php ]] && echo "$FILE_PATH" | grep -qE 'app/Modules/[A-Za-z]+/Services/[A-Za-z]+\.php'; then
  BC_NAME=$(echo "$FILE_PATH" | grep -oE 'Modules/[A-Za-z]+' | sed 's|Modules/||')
  SERVICE_NAME=$(basename "$FILE_PATH" .php)

  if [ -n "$BC_NAME" ] && [ -n "$SERVICE_NAME" ]; then
    TEST_DIR="$CWD/tests/Modules/$BC_NAME/Unit"
    TEST_FILE="${TEST_DIR}/${SERVICE_NAME}Test.php"

    if [ ! -f "$TEST_FILE" ]; then
      FOUND=$(find "$TEST_DIR" -name "*${SERVICE_NAME}*Test.php" -type f 2>/dev/null | head -1)
      if [ -z "$FOUND" ]; then
        echo ""
        echo "━━━ No Test, No Merge ━━━"
        echo "[TEST 누락] ${BC_NAME}/${SERVICE_NAME} 수정 감지 — 대응 테스트 파일이 없습니다."
        echo "  기대 경로: tests/Modules/${BC_NAME}/Unit/${SERVICE_NAME}Test.php"
        echo "  테스트 파일을 생성하거나, 기존 테스트를 업데이트하세요."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
      fi
    fi
  fi
fi

# ===== 3. Notion 동기화 알림 (요청 기반, 2026-04-22~) =====
# 정책: 사용자 명시 요청 시에만 Notion 연동. CLAUDE.md 수정 시 자동 플래그 세팅 제거.
# 사용자가 "노션에 반영"/"Notion 동기화" 등 명시 요청 시, 별도 경로에서 플래그를 세팅한다.
if [[ "$LOWER_BASENAME" == "claude.md" ]]; then
  echo ""
  echo "━━━ CLAUDE.md Modified ━━━"
  echo "[INFO] CLAUDE.md가 수정되었습니다."
  echo "  Notion 동기화는 사용자가 명시적으로 요청할 때만 수행합니다 (요청 기반 정책)."
  echo "  자동 동기화는 비활성화되어 있습니다."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
