#!/bin/bash
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

# ===== 1. 문서 체크리스트 검증 (exit 2) =====
if echo "$FILE_PATH_UNIX" | grep -qiE '(docs/tasks/|docs/output/).*\.md$'; then
  if [ -f "$FILE_PATH_UNIX" ]; then
    UNCHECKED=$(grep -c '\- \[ \]' "$FILE_PATH_UNIX" 2>/dev/null || echo "0")
    CHECKED=$(grep -c '\- \[x\]' "$FILE_PATH_UNIX" 2>/dev/null || echo "0")
    TOTAL=$((UNCHECKED + CHECKED))

    MIN_COUNT=0
    DOC_TYPE=""

    if echo "$BASENAME" | grep -qiE '[-_]?analyze\.md$'; then
      MIN_COUNT=30; DOC_TYPE="analyze"
    elif echo "$BASENAME" | grep -qiE '[-_]?plan\.md$'; then
      MIN_COUNT=20; DOC_TYPE="plan"
    elif echo "$BASENAME" | grep -qiE '[-_]?result\.md$'; then
      MIN_COUNT=20; DOC_TYPE="result"
    elif echo "$BASENAME" | grep -qiE '[-_]?(srs|sdd|idd|sdp)\.md$'; then
      MIN_COUNT=8
      DOC_TYPE="specs ($(echo "$BASENAME" | grep -oiE '(srs|sdd|idd|sdp)' | tr '[:lower:]' '[:upper:]'))"
    fi

    if [ "$MIN_COUNT" -gt 0 ] && [ "$TOTAL" -lt "$MIN_COUNT" ]; then
      echo "" >&2
      echo "━━━ Doc Checklist Guard: 체크리스트 부족 — 수정 차단 ━━━" >&2
      echo "[BLOCKED] $DOC_TYPE 문서의 체크리스트가 부족합니다." >&2
      echo "  파일: $BASENAME" >&2
      echo "  현재: ${TOTAL}개 (미체크: ${UNCHECKED}, 완료: ${CHECKED})" >&2
      echo "  최소: ${MIN_COUNT}개" >&2
      echo "  부족: $((MIN_COUNT - TOTAL))개" >&2
      echo "" >&2
      echo "task-docs 스킬의 체크리스트 템플릿을 참조하여 누락 항목을 추가하세요." >&2
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
      exit 2
    fi
  fi
fi

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

# ===== 3. Notion 동기화 알림 (flag) =====
if [[ "$LOWER_BASENAME" == "claude.md" ]]; then
  SYNC_FLAG="/tmp/claude_notion_sync_${SESSION_ID}"

  if echo "$FILE_PATH" | grep -qE '\.claude/CLAUDE\.md|Users.*\.claude.*CLAUDE'; then
    echo "global_claude_md" >> "$SYNC_FLAG"
  else
    echo "project_claude_md" >> "$SYNC_FLAG"
  fi

  echo ""
  echo "━━━ Notion Sync Required ━━━"
  echo "[SYNC] CLAUDE.md가 수정되었습니다. 반드시 다음을 수행하세요:"
  if echo "$FILE_PATH" | grep -qE '\.claude/CLAUDE\.md|Users.*\.claude.*CLAUDE'; then
    echo "  → Notion 글로벌 지침 페이지 갱신"
  else
    echo "  → Notion \"홍카페_글로벌_백엔드\" (프로젝트 지침) 갱신"
  fi
  echo "  → docs/output/instructions-and-skills/ 요약 문서 갱신"
  echo "  절차: notion-fetch → 갱신 → replace_content 전체 교체"
  echo ""
  echo "  이 작업을 수행하지 않으면 세션 종료가 차단됩니다."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
