#!/usr/bin/env bash
# tick-loop.sh — /taskflow:tick 을 매번 새 프로세스로 반복 실행 (2026-07-28)
#
# 왜 새 프로세스인가:
#   harness `/loop` 은 한 세션에 iteration 을 누적해 컨텍스트가 선형 증가한다.
#   2026-07-28 실측 — 세션 746244a3 이 step 7개를 530턴에 담으면서 턴당 컨텍스트가
#   116K → 595K (5.1배) 로 늘었고, 그날 전체 토큰의 97% 가 cache_read 였다.
#   프로세스를 끊으면 매 iteration 이 시작값으로 리셋된다 (headless 실측 첫 턴 76.8K).
#   tick 은 설계상 stateless (상태 = working/ 문서 + REGISTRY) 라 잃는 컨텍스트가 없다.
#
# 사용:
#   tick-loop.sh [간격]   기동 (detach). 기본 1800. 형식: 60 / 30m / 1h
#   tick-loop.sh --once   1회만 실행 (검증용 — detach 안 하고 출력을 그대로 보여준다)
#   tick-loop.sh stop     정지
#   tick-loop.sh status   상태 조회
#
# 환경변수 override: TICK_LOOP_MODEL(기본 sonnet) / TICK_LOOP_PERM(기본 acceptEdits)
# SSOT: custom-plugin/taskflow/commands/tick-loop.md
set -uo pipefail

STATE_DIR="$HOME/.claude/state"
PID_FILE="$STATE_DIR/tick-loop.pid"
LOG_FILE="$STATE_DIR/tick-loop.log"
MODEL="${TICK_LOOP_MODEL:-sonnet}"
PERM="${TICK_LOOP_PERM:-acceptEdits}"

mkdir -p "$STATE_DIR"

# 60 / 30m / 1h → 초. 형식 오류는 ERR (숫자부가 비었거나 숫자가 아니면).
parse_interval() {
  local raw="$1" num
  case "$raw" in
    *h) num="${raw%h}"; [ -n "$num" ] && [ -z "${num//[0-9]/}" ] && echo $(( num * 3600 )) || echo ERR ;;
    *m) num="${raw%m}"; [ -n "$num" ] && [ -z "${num//[0-9]/}" ] && echo $(( num * 60 ))   || echo ERR ;;
    *s) num="${raw%s}"; [ -n "$num" ] && [ -z "${num//[0-9]/}" ] && echo "$num"            || echo ERR ;;
    *)  [ -n "$raw" ] && [ -z "${raw//[0-9]/}" ] && echo "$raw" || echo ERR ;;
  esac
}

alive() { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; }

run_once() {
  local rc
  echo "=== $(date '+%F %T') tick 시작 (model=$MODEL perm=$PERM)"
  # stdin 을 끊는다 — headless 라 프롬프트를 읽을 곳이 없다
  claude -p --model "$MODEL" --permission-mode "$PERM" "/taskflow:tick" < /dev/null 2>&1
  rc=$?
  echo "=== $(date '+%F %T') tick 종료 (exit=$rc)"
  return $rc
}

case "${1:-}" in
  # nohup 재진입 전용 — 사용자가 직접 호출하지 않는다
  __run)
    while :; do
      run_once
      echo "--- $2s 대기"
      sleep "$2"
    done
    ;;

  --once)
    run_once | tee -a "$LOG_FILE"
    ;;

  stop)
    if alive; then
      PID=$(cat "$PID_FILE")
      kill "$PID" 2>/dev/null && echo "정지: PID $PID"
    else
      echo "실행 중 아님"
    fi
    rm -f "$PID_FILE"
    ;;

  status)
    if alive; then
      echo "실행 중: PID $(cat "$PID_FILE")"
      echo "로그 마지막 5줄 ($LOG_FILE):"
      tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
    else
      echo "정지 상태"
      [ -f "$PID_FILE" ] && echo "  (PID 파일 잔존 = 비정상 종료. 'stop' 으로 정리)"
    fi
    ;;

  *)
    if alive; then
      echo "이미 실행 중 (PID $(cat "$PID_FILE")). 먼저 'tick-loop.sh stop'." >&2
      exit 1
    fi
    INTERVAL=$(parse_interval "${1:-1800}")
    if [ "$INTERVAL" = ERR ]; then
      echo "간격 형식 오류: '${1}' (예: 60, 30m, 1h)" >&2
      exit 1
    fi
    # 하한 10초 — 0 이나 1 을 넣으면 tick 이 끝나자마자 재기동해 폭주한다
    if [ "$INTERVAL" -lt 10 ]; then
      echo "간격이 너무 짧다: ${INTERVAL}s (최소 10s)" >&2
      exit 1
    fi
    nohup "$0" __run "$INTERVAL" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "기동: PID $(cat "$PID_FILE") / 간격 ${INTERVAL}s / model=$MODEL"
    echo "로그: $LOG_FILE"
    echo "정지: bash ~/.claude/bin/tick-loop.sh stop"
    ;;
esac
