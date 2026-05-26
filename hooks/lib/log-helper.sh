#!/usr/bin/env bash
# log-helper.sh — telemetry 인프라 공용 로거 (2026-05-13 도입)
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh"
#   log_event "hook-name" "event-type" "detail message"
#   log_event "gate-approve" "approve" "sid=abc current=1 new=2 bundled=true"
#
# 표준 출력 위치: ~/.claude/logs/{hook-name}.log
# 표준 출력 포맷: ndjson (1 line 1 event, jq 호환)
#   {"ts": "2026-05-13T15:00:00Z", "hook": "gate-approve", "event": "approve", "detail": "sid=..."}
#
# Why:
# - 기존 = 각 hook 가 ~/.claude/{name}.log 산재 작성, 포맷 제각각 (timestamp + free text)
# - 신규 = ~/.claude/logs/{name}.log 표준 위치 + ndjson 포맷 → 집계 스크립트 (jq) 일관 처리
# - 마이그레이션 = 기존 hook 의 log() 함수를 본 lib 의 log_event 로 점진 전환 (별 작업)
#
# SSOT: 본 lib + ~/.claude/bin/aggregate-hook-stats.sh (집계 스크립트)

# 로그 루트 보장
LOG_HELPER_ROOT="${HOME}/.claude/logs"
mkdir -p "$LOG_HELPER_ROOT" 2>/dev/null

# ─────────────────────────────────────────────────────────
# log_event <hook-name> <event-type> [detail...]
# ─────────────────────────────────────────────────────────
# hook-name: 'gate-approve' / 'working-lifecycle' 등 — 파일 분리 키
# event-type: 6 분류 표준 (2026-05-19 debate 결정, 2026-05-26 정렬)
#   enter   — hook 진입 시작점
#   approve — 승인/통과 (성공 분기)
#   block   — 차단/exit 2 (강제 차단 분기)
#   skip    — 면제/스킵 (조건 미충족 통과)
#   error   — 오류 발생 (예외 흐름)
#   info    — 기타 디버그 (fallback)
# 예약어: 'move' = work-lifecycle hook 향 별 차원 (6 분류와 독립). event-type 자체는 자유 텍스트 유지, 6 분류는 권장 표준.
# detail: 자유 텍스트 (1줄, newline 제거)
log_event() {
  local hook_name="${1:-unknown}"
  local event_type="${2:-info}"
  shift 2 2>/dev/null
  local detail="$*"
  detail="${detail//$'\n'/ }"
  # JSON 안전 escape — backslash / double-quote 만 처리 (control char 거의 없음)
  detail="${detail//\\/\\\\}"
  detail="${detail//\"/\\\"}"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local log_file="$LOG_HELPER_ROOT/${hook_name}.log"
  # ndjson 1 line append (atomic 보장 안 됨 — 단일 process per hook 가정)
  printf '{"ts":"%s","hook":"%s","event":"%s","detail":"%s"}\n' \
    "$ts" "$hook_name" "$event_type" "$detail" >> "$log_file" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────
# log_session_event <hook-name> <event-type> <session_id> [detail...]
# session_id 명시 — 세션별 집계 가능
# ─────────────────────────────────────────────────────────
log_session_event() {
  local hook_name="${1:-unknown}"
  local event_type="${2:-info}"
  local sid="${3:-default}"
  shift 3 2>/dev/null
  local detail="$*"
  detail="${detail//$'\n'/ }"
  detail="${detail//\\/\\\\}"
  detail="${detail//\"/\\\"}"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local log_file="$LOG_HELPER_ROOT/${hook_name}.log"
  printf '{"ts":"%s","hook":"%s","event":"%s","sid":"%s","detail":"%s"}\n' \
    "$ts" "$hook_name" "$event_type" "$sid" "$detail" >> "$log_file" 2>/dev/null || true
}
