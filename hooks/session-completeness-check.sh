#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "session-completeness-check" "enter" "pid=$$"
# Stop Hook: 세션 종료 시 산출물 누락 검증
# exit 2 차단 — 산출물 미완성 시 세션 종료 차단
#
# 검증 항목:
#   1. Edit/Write 이력 있는 세션 → history.md + YYYYMMDD/summary.md 기록 필수
#   2. gate>=2(실행 단계) → 작업 폴더에 최소 1개의 단계 문서(analyze/plan/result 등) 존재 필수
#
# 정책 (v2.0): analyze.md + result.md 쌍 강제 제거.
#   작업 성격에 따라 필요한 단계 문서 하나만 있어도 통과한다.

STDIN_DATA=$(cat)

# python3 우선 파싱 + grep fallback (Windows 환경 JSON 이스케이프 호환)
PARSED=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', '')
    cwd = data.get('cwd', '')
    if not sid:
        sys.exit(1)
    safe_cwd = cwd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'CWD=\"{safe_cwd}\"')
except Exception:
    sys.exit(1)
" 2>/dev/null)
if [ -n "$PARSED" ]; then
  eval "$PARSED"
else
  SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  CWD=$(echo "$STDIN_DATA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  # JSON이스케이프된 \\를 실제 \로 복원 (Windows 경로)
  CWD=$(echo "$CWD" | sed 's/\\\\/\\/g')
  SESSION_ID=${SESSION_ID:-default}
  CWD=${CWD:-.}
fi

TODAY=$(date +%Y%m%d)
TODAY_DOT=$(date +%Y.%m.%d)
BLOCKED=false
WARNINGS=""

# --- product 및 글로벌 경로 해석 ---
# CWD → product (basename $CWD, `.claude`→`claude-harness`)
# 모든 산출물은 ~/.claude/docs/{product}/tasks/ 하위에 생성된다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/product-resolver.sh" 2>/dev/null || {
  echo "[session-completeness-check] product-resolver.sh 로드 실패" >&2
  exit 0
}
PRODUCT=$(resolve_product "$CWD")
TASKS_DIR=$(product_tasks_dir "$CWD")

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"
CURRENT=$(cat "$GATE_FILE" 2>/dev/null || echo "0")
EDIT_FLAG="/tmp/claude_edit_flag_${SESSION_ID}"
NONCODE_FLAG="/tmp/claude_noncode_flag_${SESSION_ID}"

# --- 비코드 전용 세션 면제 ---
# 코드 수정 없이 비코드만 수정한 세션 → tasks 기록 강제 면제
IS_NONCODE_ONLY=false
if [ ! -f "$EDIT_FLAG" ] && [ -f "$NONCODE_FLAG" ]; then
  IS_NONCODE_ONLY=true
fi

# --- 1. 일일 기록 여부 (코드 Edit/Write 이력 있는 세션만) ---
if [ -f "$EDIT_FLAG" ] && [ "$IS_NONCODE_ONLY" = false ]; then
  mkdir -p "$TASKS_DIR" 2>/dev/null
  HISTORY_FILE="$TASKS_DIR/history.md"
  DAILY_FILE="$TASKS_DIR/${TODAY}/summary.md"

  # history.md 오늘 날짜 항목 검사
  if [ ! -f "$HISTORY_FILE" ] || ! grep -q "$TODAY_DOT" "$HISTORY_FILE" 2>/dev/null; then
    WARNINGS="${WARNINGS}\n[BLOCKED] ~/.claude/docs/${PRODUCT}/tasks/history.md 에 오늘($TODAY_DOT) 항목이 없습니다."
    BLOCKED=true
  fi

  # YYYYMMDD/summary.md 존재 검사
  if [ ! -f "$DAILY_FILE" ]; then
    WARNINGS="${WARNINGS}\n[BLOCKED] ~/.claude/docs/${PRODUCT}/tasks/${TODAY}/summary.md 파일이 없습니다."
    BLOCKED=true
  fi
fi

# --- 2. 단계 문서 존재 여부 (gate>=2 + 코드 수정 세션만) ---
# CLAUDE.md §File Paths 규칙:
#   tasks/    → 코드 작업 완료 산출물 (analyze/plan/result 3종 또는 unified 단일 통합 — 2026-05-12~)
#   output/   → 분석·문서 생성 프롬프트 ({제목}/*.md 산출물)
#   working/  → 진행 중 단일 통합 작업 문서 (2026-05-12~, 완료 시 tasks/ 로 자동 이동)
# 셋 중 하나라도 오늘자 산출물이 존재하면 통과 (경로 이중화 허용).
if [ "$CURRENT" -ge 2 ] && [ "$IS_NONCODE_ONLY" = false ]; then
  TASK_DIR="$TASKS_DIR/$TODAY"
  OUTPUT_DIR=$(product_output_dir "$CWD")
  WORKING_DIR="$HOME/.claude/docs/working/$TODAY"
  TODAY_ISO=$(date +%Y-%m-%d)
  STAGE_DOC=""
  OUTPUT_DOC=""
  WORKING_DOC=""

  # tasks/ 단계 문서 확인 (코드 작업 세션, unified 단일 통합 포함)
  if [ -d "$TASK_DIR" ]; then
    STAGE_DOC=$(find "$TASK_DIR" \( -name '*analyze*' -o -name '*plan*' -o -name '*result*' -o -name '*unified*' \) -type f 2>/dev/null | head -1)
  fi

  # output/ 오늘 생성·수정된 .md 확인 (분석·문서 세션)
  if [ -d "$OUTPUT_DIR" ]; then
    OUTPUT_DOC=$(find "$OUTPUT_DIR" -name '*.md' -type f -newermt "$TODAY_ISO" 2>/dev/null | head -1)
  fi

  # working/ 진행 중 단일 통합 문서 확인 (2026-05-12 시행)
  # working/ 는 product 분리 없이 글로벌 통합 — 파일명 prefix 로 product 식별
  if [ -d "$WORKING_DIR" ]; then
    WORKING_DOC=$(find "$WORKING_DIR" -name "*${PRODUCT}*" -type f 2>/dev/null | head -1)
  fi

  if [ -z "$STAGE_DOC" ] && [ -z "$OUTPUT_DOC" ] && [ -z "$WORKING_DOC" ]; then
    WARNINGS="${WARNINGS}\n[BLOCKED] 오늘자 산출물이 없습니다. 아래 중 1종 이상 필요:"
    WARNINGS="${WARNINGS}\n  - (코드 작업 신규 2026-05-12~) ~/.claude/docs/working/$TODAY/{yyyy-mm-dd}-${PRODUCT}-{작업명}.md (진행 중)"
    WARNINGS="${WARNINGS}\n    또는 ~/.claude/docs/${PRODUCT}/tasks/$TODAY/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md (완료 후 자동 이동)"
    WARNINGS="${WARNINGS}\n  - (코드 작업 기존 < 2026-05-12) ~/.claude/docs/${PRODUCT}/tasks/$TODAY/{작업명}/{yyyy-mm-dd}-{작업명}-{analyze|plan|result}.md"
    WARNINGS="${WARNINGS}\n  - (분석·문서) ~/.claude/docs/${PRODUCT}/output/{category}/{제목}/{yyyy-mm-dd}-{제목}-{type}.md"
    BLOCKED=true
  fi
fi

# 차단 또는 통과
# 정책: exit 0 (stderr 경고만, 차단 없음)
# Why: Stop hook 매 턴 호출 + exit 2 차단 시 사용자 응답 대기 진입 자체 불가능
# (단일 응답 종료마다 차단되어 무한 reroll). stderr 안내로 Claude 자가 복구
# (CLAUDE.md §4 "Hook 차단 자가 복구" 룰) 신뢰. 산출물 누락은 1회 알림으로 충분.
if [ "$BLOCKED" = true ]; then
  WARN_FLAG="/tmp/claude_completeness_warned_${SESSION_ID}"
  if [ ! -f "$WARN_FLAG" ]; then
    touch "$WARN_FLAG"
    echo "" >&2
    echo "━━━ Session Completeness: 산출물 누락 알림 ━━━" >&2
    echo -e "$WARNINGS" >&2
    echo "" >&2
    echo "일일 기록 누락 시: ~/.claude/docs/${PRODUCT}/tasks/history.md 에 오늘 날짜 항목 + ~/.claude/docs/${PRODUCT}/tasks/${TODAY}/summary.md 파일 생성 권장" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  fi
fi

# 세션 종료 시 플래그 정리
# NOTE: Stop hook은 "매 assistant 응답 종료"마다 호출됨 (실제 세션 종료 이벤트 아님).
#       gate 리셋을 여기서 하면 승인 누적이 무효화되어 매 턴 재승인이 필요해짐.
#       gate는 SessionStart(gate-init.sh)에서만 초기화하고, Stop에서는 건드리지 않는다.
# echo "0" > "$GATE_FILE" 2>/dev/null   # ← 제거: 매턴 리셋 방지
#
# EDIT_FLAG 도 매 턴 정리하면 다음 hook 인 pre-idle-selfcheck.sh 가 §2 면제 분기에 걸려
# 자가점검을 미발화시키는 결함이 발생함. SELFCHECK_DONE 플래그가 selfcheck 의 1회 제한을
# 자체 보장하므로 EDIT_FLAG 는 정리하지 않아도 무해 (SESSION_ID 별 파일 분리).
# rm -f "$EDIT_FLAG" 2>/dev/null   # ← 제거: selfcheck 미발화 결함 방지
rm -f "$NONCODE_FLAG" 2>/dev/null
rm -f "/tmp/claude_test_run_${SESSION_ID}" 2>/dev/null

exit 0
