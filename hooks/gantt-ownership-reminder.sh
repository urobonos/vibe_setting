#!/usr/bin/env bash
# gantt-ownership-reminder.sh
# PostToolUse Hook (matcher: Edit|Write)
#
# 목적: 코드 mutation 첫 감지(세션당 1회) 시, 이 작업이 사용자(JY Park) 담당인지
#       간트차트(jypark-gant.md)로 대조하도록 환기 reminder 주입. 비차단(exit 0).
#
# 발동 2경로:
#   ① 작업 진입 시 — §4.3 "참조 범위 전수 조사" (1) 참조문서 sweep 에 간트 대조 포함 (Claude 본체 절차).
#   ② 코드 mutation 첫 감지 시 — 본 hook 이 세션당 1회 백업 환기 (PostToolUse, 비차단).
#
# 설계 (reminder 주입형, 비차단 — decision-record-reminder.sh 와 동형):
#   - 강제 차단 아님: 작업↔WBS 매핑은 의미적 → hook 정규식 강제 부적합(오탐/미탐).
#     판정은 Claude 본체 책임, hook 은 환기만 (CLAUDE.md §2 / §0 "중복 hook 신설 금지").
#   - 간트 파일 비파싱: 변동성 높은 내용을 hook 이 읽지 않음 → 포맷·내용 변경에 무관.
#   - 세션당 1회 마커(/tmp/claude_gantt_reminded_${SID}): 노이즈 억제.
#   - 간트 파일 부재 시 no-op (대조 대상 없음).
#
# SSOT: 본 hook + CLAUDE.md §2 "작업 소유권 확인 (간트 대조)"

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/hook-input.sh" 2>/dev/null || true
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null || true

if declare -f hook_init >/dev/null 2>&1; then
  hook_init
  hook_read_stdin
  hook_parse_session_id
else
  STDIN_DATA=$(cat 2>/dev/null || true)
  SESSION_ID=$(printf '%s' "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  SESSION_ID=${SESSION_ID:-default}
fi

log() {
  if declare -f log_event >/dev/null 2>&1; then
    log_event "gantt-ownership-reminder" "${1:-info}" "${2:-}"
  fi
}

MARKER="/tmp/claude_gantt_reminded_${SESSION_ID}"
[ -f "$MARKER" ] && exit 0   # 세션당 1회

GANTT="$HOME/.claude/docs/참조문서/간트/jypark-gant.md"
[ -f "$GANTT" ] || { log "skip" "gantt absent sid=$SESSION_ID"; exit 0; }   # 간트 부재 시 환기 안 함

touch "$MARKER" 2>/dev/null || true

cat <<'EOF'
<system-reminder>
[작업 소유권 확인 — 간트 대조 (CLAUDE.md §2, 세션당 1회 환기)]
이 작업이 사용자(JY Park) 담당 작업인지 간트차트로 대조하세요:
  SSOT: ~/.claude/docs/참조문서/간트/jypark-gant.md (담당자: JY Park=사용자 / ahn=타 담당자)
판정 — 작업의 WBS ID(MOD-XX-XXX) 또는 작업명/모듈을 간트에서 조회:
  · 담당자 JY Park       → 진행
  · 담당자 ahn 등 타인   → "이 작업은 {담당자} 담당입니다. 진행할까요?" 동의 후 진행
  · 간트에 없음(범위 외) → 사용자 확인
비차단 환기입니다 (exit 0). 판정·동의 흐름은 Claude 본체 책임.
</system-reminder>
EOF

log "enter" "reminded sid=$SESSION_ID"
exit 0
