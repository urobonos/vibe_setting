#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# Stop Hook: 대기 진입 전 자가점검 프롬프트 주입
#
# 목적: Claude가 "모든 작업이 끝났다"고 판단하고 사용자 응답 대기로 들어가기 직전,
#       실제로 모든 작업이 완결됐는지 스스로 점검하게 만든다.
#
# 동작:
#   1. stop_hook_active=true (이미 Stop hook 재진입 상태) → 즉시 통과 (무한루프 방지)
#   2. EDIT_FLAG 없음 (코드 수정 없던 단순 대화 세션) → 통과 (오버헤드 방지)
#   3. SELFCHECK_DONE 플래그 있음 (세션당 1회 제한) → 통과
#   4. 위 모두 미해당 → 플래그 세팅 + stderr에 자가점검 체크리스트 주입 + exit 2

STDIN_DATA=$(cat)

# --- JSON 파싱: python3 우선 + grep fallback (Windows 환경 호환) ---
PARSED=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', '')
    stop_active = data.get('stop_hook_active', False)
    if not sid:
        sys.exit(1)
    print(f'SESSION_ID=\"{sid}\"')
    print(f'STOP_HOOK_ACTIVE={str(stop_active).lower()}')
except Exception:
    sys.exit(1)
" 2>/dev/null)
if [ -n "$PARSED" ]; then
  eval "$PARSED"
else
  SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  STOP_HOOK_ACTIVE=$(echo "$STDIN_DATA" | grep -o '"stop_hook_active"[[:space:]]*:[[:space:]]*[a-z]*' | head -1 | sed 's/.*:[[:space:]]*\([a-z]*\).*/\1/')
  SESSION_ID=${SESSION_ID:-default}
  STOP_HOOK_ACTIVE=${STOP_HOOK_ACTIVE:-false}
fi

# --- 1. 무한루프 방지: Stop hook 재진입 상태면 통과 ---
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# --- 2. 코드 수정 없던 세션 면제 ---
EDIT_FLAG="/tmp/claude_edit_flag_${SESSION_ID}"
if [ ! -f "$EDIT_FLAG" ]; then
  exit 0
fi

# --- 3. 세션당 1회 제한 ---
SELFCHECK_DONE="/tmp/claude_selfcheck_done_${SESSION_ID}"
if [ -f "$SELFCHECK_DONE" ]; then
  exit 0
fi

# --- 4. 자가점검 프롬프트 주입 ---
touch "$SELFCHECK_DONE"

echo "" >&2
echo "━━━ 대기 진입 전 자가점검 ━━━" >&2
echo "다음을 자가 검증하고, 미충족 시 보완 후 응답 종료하라." >&2
echo "" >&2
echo "1. [원 요구사항] 사용자 최초 요청을 빠짐없이 처리했는가?" >&2
echo "2. [Checkpoint] §3 승인 대기 항목이 남아있지 않은가?" >&2
echo "3. [Before/After] 제안 반영 세션이라면 최초안 vs 제안안 대조 보고(표/diff)를 응답에 포함했는가? 제안 0건이라면 \"제안 추가: 없음\" 명시 필요." >&2
echo "4. [TodoWrite] in_progress/pending 항목이 남아있지 않은가?" >&2
echo "5. [Team 3] M/L급 작업이면 Reviewer/Tester 검증이 끝났는가?" >&2
echo "6. [산출물] history.md + YYYYMMDD/summary.md 기록했는가?" >&2
echo "7. [Direct Execution] 사용자에게 \"! 명령 실행해 주세요\"·\"다음을 실행해 주세요\" 형태로 명령을 떠넘기는 응답을 했는가? 했다면 Claude 가 직접 Bash 도구로 실행해야 한다 (CLAUDE.md §4 Direct Execution)." >&2
echo "8. [Audit Auto-fix] /audit-config 등 진단 명령 직후 사용자 명시 수정 요청 없이 fix 에 진입했는가? 진단 직후 fix 는 지침 위반 (CLAUDE.md §4 audit 결과 자동 수정 금지)." >&2
echo "" >&2
echo "모두 충족 → \"자가점검 완료: 모두 충족\" 한 줄로 종료." >&2
echo "미충족 → 즉시 보완 작업 수행." >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━" >&2

# 정책 (2026-05-06): exit 0 (정보성 stderr 알림만, 차단 없음)
# Why: Stop hook 매 응답 종료마다 호출 + exit 2 차단 시 reroll 강제로 토큰·응답 시간 폭증.
# SELFCHECK_DONE 가드(세션당 1회) 가 발동 빈도 제어 + stderr 알림으로 자가복구 신뢰.
# 진짜 산출물 차단 필요는 session-completeness-check.sh 분담.
exit 0
