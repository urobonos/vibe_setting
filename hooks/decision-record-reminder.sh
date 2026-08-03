#!/usr/bin/env bash
# decision-record-reminder.sh
# PostToolUse Hook (matcher: AskUserQuestion)
#
# 목적: Claude 가 AskUserQuestion 으로 사용자에게 결정을 요구하고 그 결정이
#       완료(사용자 선택)되면, 결정 내용(질문→선택)을 진행 중 working/ 문서의
#       §공통 "변경 영향 기록" 표에 기록하도록 system reminder 를 주입한다.
#
# 설계 (reminder 주입형, self-critique 루프와 동형):
#   - hook 은 stateless → 결정 "내용"은 tool_response.answers 에서 직접 추출하되,
#     실제 문서 기록은 맥락을 가진 Claude 본체가 수행 (reminder 가 지시).
#   - "명시적 결정 지점만" 정책 (사용자 선택 2026-06-08) → AskUserQuestion 도구
#     호출만 1차 트리거. 단순 실행 승인("진행")은 대상 아님.
#   - 기록 위치 = 기존 §공통 "변경 영향 기록" 표 재사용 (unified-template.md /
#     doc-template-guard 무수정, SSOT 표면 불변 — CLAUDE.md §4.4 장기 관점 정합).
#
# 동작:
#   1. tool_response.answers ({질문:답변}) 추출 — 비면 no-op
#   2. registry 에서 현재 sid 의 active working_file 조회 — 없으면 no-op (잔소리 회피)
#   3. working_file 있으면 결정 내용 포함 reminder stdout 주입 (exit 0)
#
# SSOT: 본 hook + CLAUDE.md §4.1 "결정 기록" + skills/task-docs (기록 양식)
# 짝: AskUserQuestion (트리거 도구) / sentinel [AUTO-ITERATE-USER-DECISION] 경로는
#     별도 CLAUDE.md 룰 (Stop hook exit 0 으로 reminder 합성 불가 — hook 아님).

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/hook-input.sh" 2>/dev/null || true
# shellcheck disable=SC1091
source "$(dirname "$0")/lib/registry-utils.sh" 2>/dev/null || true
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null || true

# stdin 파싱 (lib 우선, fallback 직접)
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
    log_event "decision-record-reminder" "${1:-info}" "${2:-}"
  fi
}

# ── 1. tool_response.answers 추출 ────────────────────────────────────────────
DECISIONS=""
if declare -f resolve_python >/dev/null 2>&1; then
  resolve_python
fi
if [ -n "${HOOK_PY:-}" ]; then
  DECISIONS=$(printf '%s' "$STDIN_DATA" | "$HOOK_PY" -c '
import json, sys, re
try:
    data = json.load(sys.stdin)
    tr = data.get("tool_response", {})
    answers = {}
    if isinstance(tr, dict):
        answers = tr.get("answers", {}) or {}
        # tool_response 가 dict 이나 answers 부재 시 content 문자열 fallback
        if not answers and isinstance(tr.get("content"), str):
            for m in re.finditer(r"\"([^\"]+)\"\s*=\s*\"([^\"]+)\"", tr["content"]):
                answers[m.group(1)] = m.group(2)
    elif isinstance(tr, str):
        for m in re.finditer(r"\"([^\"]+)\"\s*=\s*\"([^\"]+)\"", tr):
            answers[m.group(1)] = m.group(2)
    lines = []
    for q, a in answers.items():
        q1 = " ".join(str(q).split())
        a1 = " ".join(str(a).split())
        if q1 and a1:
            lines.append("- " + q1 + " → " + a1)
    print("\n".join(lines))
except Exception:
    print("")
' 2>/dev/null)
fi

if [ -z "$DECISIONS" ]; then
  log "skip" "no answers parsed sid=$SESSION_ID"
  exit 0
fi

# ── 2. 현재 sid 의 active working_file 조회 (registry) ────────────────────────
# registry 는 working-register.sh 가 SID8="${SESSION_ID:0:8}" 로 8자 truncate 저장 →
# hook 이 받는 full UUID 를 동일하게 8자로 잘라 매칭해야 한다 (정확 매칭 시 영원히 no-op).
SID8="${SESSION_ID:0:8}"
WORKING_FILE=""
if [ -n "${REGISTRY_PATH:-}" ] && [ -f "$REGISTRY_PATH" ] && [ -n "${REGISTRY_FS:-}" ]; then
  WORKING_FILE=$(awk -v sid="$SID8" -F"$REGISTRY_FS" '
    /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $4 == sid && $7 == "active" { print $9; exit }
  ' "$REGISTRY_PATH" 2>/dev/null)
fi

if [ -z "$WORKING_FILE" ] || [ "$WORKING_FILE" = "-" ]; then
  log "skip" "no active working_file sid=$SESSION_ID (decision not recorded)"
  exit 0
fi

# ── 3. reminder 주입 ─────────────────────────────────────────────────────────
cat <<EOF
<system-reminder>
[결정 기록] 방금 AskUserQuestion 으로 사용자가 다음을 결정했습니다:
${DECISIONS}

→ 이 결정을 진행 중 working 문서의 §공통 "변경 영향 기록" 표에 기록하세요.
   대상 문서: ${WORKING_FILE}
   양식: 각 결정 1행 — | 변경 사항=결정 내용(질문→선택) | 개선점=선택 효과 | 수행 이유(Why)=선택 근거 |
   (표가 없으면 §공통 섹션에 "변경 영향 기록" 표를 만들어 추가. 신규 섹션/헤더 신설 금지 — 기존 표 재사용.)
   이 기록은 다음 작업과 함께 진행하면 됩니다 (별도 승인 불필요). §3 매칭 결정이면 사용자 승인 흐름은 그대로 유지.
</system-reminder>
EOF

log "enter" "reminder injected sid=$SESSION_ID wfile=$WORKING_FILE"
exit 0
