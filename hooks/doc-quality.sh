#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "doc-quality" "enter" "pid=$$"
# PostToolUse Hook: Service 수정 시 테스트 동반 확인 (No Test, No Merge)
# 원 통합(doc-checklist/test-coexistence/notion-sync) 중 체크리스트=doc-unified-check.sh V4 이관,
# Notion INFO=요청기반 정책으로 폐기 (2026-07-15). 잔여 = 테스트 동반 확인 단일 책임 (warning, exit 0).

STDIN_DATA=$(cat)

# 파싱 — bash 내장 (python eval fork 제거)
FILE_PATH=""; [[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && FILE_PATH="${BASH_REMATCH[1]}"

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

SESSION_ID="default"; [[ "$STDIN_DATA" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && SESSION_ID="${BASH_REMATCH[1]}"
CWD="."; [[ "$STDIN_DATA" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && CWD="${BASH_REMATCH[1]}"

# ===== 1. 문서 체크리스트 검증 — doc-unified-check.sh V4 (v_checklist_count) 가 수행 =====
# 체크리스트 개수 검증(analyze/unified≥30, plan/result≥20)은 doc-unified-check.sh SSOT.
# (구 checklist-count-check.sh 는 doc-unified 로 통합되어 2026-07-14 삭제됨)

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

exit 0
