#!/bin/bash
# PreToolUse Hook: audit 진단 직후 자동 fix 진입 차단 경고
#
# 트리거: Edit / Write 도구 실행 직전
# 동작:
#   1. SKIP_HOOKS=1 → 즉시 통과
#   2. /tmp/claude_audit_marker_${SESSION_ID} 파일 존재 + mtime 5분 이내 → Checkpoint 경고
#   3. 마커 없거나 만료됐으면 통과
#
# 마커 생성: 사용자 프롬프트에 "/audit", "audit-config", "보안 감사" 등 audit 키워드 감지 시 별도 hook (UserPromptSubmit) 또는 본 hook 의 보조 함수에서 생성.
#   현재는 사용자 프롬프트 hook 미구현 → marker 는 수동 또는 후속 작업으로. 본 hook 은 마커 존재 시 동작만 정의.
#
# 차단 vs 경고: exit 0 + stdout Checkpoint 경고 (실행 자체는 통과 — 사용자 명시 수정 요청 받았는지 Claude 자가 확인 후 진행)
# 위반 시: CLAUDE.md §4 "audit 결과 자동 수정 금지" 룰

source "$(dirname "$0")/lib/hook-input.sh"

hook_init
hook_read_stdin
hook_parse_session_id

# --- 도구 이름 추출 ---
TOOL_NAME=$(hook_parse_field "tool_name")

# Edit / Write 만 검사 (Bash 등 다른 도구는 통과)
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

# --- audit 마커 파일 검사 ---
AUDIT_MARKER="/tmp/claude_audit_marker_${SESSION_ID}"

if [ ! -f "$AUDIT_MARKER" ]; then
  exit 0
fi

# 마커 mtime 5분 이내 검사 (300초)
MARKER_AGE=$(($(date +%s) - $(stat -c %Y "$AUDIT_MARKER" 2>/dev/null || stat -f %m "$AUDIT_MARKER" 2>/dev/null || echo 0)))

if [ "$MARKER_AGE" -gt 300 ]; then
  # 만료된 마커 정리
  rm -f "$AUDIT_MARKER"
  exit 0
fi

# --- Checkpoint 경고 (exit 0, stdout) ---
hook_parse_file_path
echo ""
echo "━━━ CHECKPOINT: audit 직후 자동 수정 진입 감지 ━━━"
echo "도구: $TOOL_NAME / 파일: $FILE_PATH"
echo "마커: $AUDIT_MARKER (생성 후 ${MARKER_AGE}초)"
echo ""
echo "최근 5분 내 audit 진단 명령 실행 흔적이 있습니다."
echo "CLAUDE.md §4 룰: audit 결과 자동 수정 금지. 사용자가 특정 항목에 대해 명시적으로 수정을 요청한 경우에만 진행하세요."
echo ""
echo "확인 항목:"
echo "  1. 사용자가 본 수정 항목을 명시적으로 지시했는가?"
echo "  2. 단건 패치가 아닌 영향 범위 전체를 고려한 접근인가?"
echo "  3. 잘 돌아가는 구조에 점수 올리려는 변경은 아닌가?"
echo ""
echo "사용자 명시 수정 요청이 없다면 작업 중단 후 사용자에게 보고하세요."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
