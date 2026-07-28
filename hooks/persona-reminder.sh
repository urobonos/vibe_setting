#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "persona-reminder" "enter" "pid=$$"
# UserPromptSubmit Hook: 매 턴 페르소나 + 운영 5원칙 주입.
# 페이로드 SSOT = ~/.claude/PERSONA.md (CLAUDE.md 에서 분리 — 주입 문구 수정은 그 파일만 편집).
# 훅은 파일을 그대로 cat (파싱 없음 = 견고). stdout → 해당 턴 컨텍스트 최상단 주입.
# 본 훅은 리마인더(soft), 강제 아님.

PERSONA_FILE="$(dirname "${BASH_SOURCE[0]}")/../PERSONA.md"

if [ -f "$PERSONA_FILE" ]; then
  cat "$PERSONA_FILE"
else
  # fallback: PERSONA.md 미탐 시 정적 넛지
  echo "[이번 응답 = 카파시 페르소나] 결론 먼저 · 도입/사족 0 · 단락 1~3줄 · 표는 실제 대조 때만 · 존댓말 유지."
fi

exit 0
