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
# 왜 병렬이 안전한가:
#   tick 은 `registry_claim`(lock 안 확인+add 원자)으로 step 을 배타 점유한다.
#   여러 인스턴스가 동시에 돌아도 같은 step 을 중복 작업하지 않는다 — 못 잡은 쪽은
#   TAKEN 을 받고 다음 후보로 넘어간다. 슬롯마다 완전히 독립된 프로세스라
#   하나가 죽어도 나머지는 무관하다 (subagent 워커와 다른 점).
#
# 사용:
#   tick-loop.sh [간격] [N]   기동 (detach). 간격 기본 1800(60/30m/1h), N 기본 1
#   tick-loop.sh --once       1회만 실행 (검증용 — detach 안 하고 출력을 그대로 보여준다)
#   tick-loop.sh stop [슬롯]  정지. 슬롯 생략 시 전체
#   tick-loop.sh status       전 슬롯 상태 조회
#
# 환경변수 override: TICK_LOOP_MODEL(기본 sonnet) / TICK_LOOP_PERM(기본 acceptEdits)
# SSOT: custom-plugin/taskflow/commands/tick-loop.md
set -uo pipefail

STATE_DIR="$HOME/.claude/state"
SLOT_DIR="$STATE_DIR/tick-loop"
MODEL="${TICK_LOOP_MODEL:-sonnet}"
PERM="${TICK_LOOP_PERM:-acceptEdits}"

mkdir -p "$SLOT_DIR"

slot_pid() { echo "$SLOT_DIR/$1.pid"; }
slot_log() { echo "$SLOT_DIR/$1.log"; }
slot_alive() {
  local f; f=$(slot_pid "$1")
  [ -f "$f" ] && kill -0 "$(cat "$f" 2>/dev/null)" 2>/dev/null
}

# 동시 슬롯 상한 — §4.2 병렬 fan-out 과 같은 식 min(16, cores-2)
max_slots() {
  local cores m
  cores=$(nproc 2>/dev/null || echo 4)
  m=$(( cores - 2 ))
  [ "$m" -gt 16 ] && m=16
  [ "$m" -lt 1 ] && m=1
  echo "$m"
}

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

run_once() {
  local rc tag="${1:-}"
  echo "=== $(date '+%F %T')${tag:+ [slot $tag]} tick 시작 (model=$MODEL perm=$PERM)"
  # stdin 을 끊는다 — headless 라 프롬프트를 읽을 곳이 없다
  claude -p --model "$MODEL" --permission-mode "$PERM" "/taskflow:tick" < /dev/null 2>&1
  rc=$?
  echo "=== $(date '+%F %T')${tag:+ [slot $tag]} tick 종료 (exit=$rc)"
  return $rc
}

stop_slot() {
  local n="$1" f pid child
  f=$(slot_pid "$n")
  if slot_alive "$n"; then
    pid=$(cat "$f")
    # 자식(claude) 을 먼저 죽인다 — 부모만 죽이면 claude 가 고아로 남아 계속 파일을 만진다
    for child in $(ps -ef 2>/dev/null | awk -v p="$pid" '$3==p {print $2}'); do
      kill "$child" 2>/dev/null && echo "  [slot $n] 자식 종료: PID $child"
    done
    kill "$pid" 2>/dev/null && echo "[slot $n] 정지: PID $pid"
  fi
  rm -f "$f"
}

case "${1:-}" in
  # nohup 재진입 전용 — 사용자가 직접 호출하지 않는다. $2=간격 $3=슬롯
  __run)
    trap 'echo "=== $(date "+%F %T") [slot '"${3:-?}"'] 루프 정지 (시그널 수신)"; exit 0' INT TERM
    while :; do
      run_once "${3:-}"
      rc=$?
      # 자식 claude 가 시그널로 죽었다(128+N) = 사용자가 개입했다는 뜻이다.
      # 이때 루프까지 멈추지 않으면 "다 껐다"고 믿는 사이 다음 iteration 이 뜬다
      # (2026-07-28 실측 사고 — claude 만 kill 했는데 부모 루프가 살아남았다).
      if [ "$rc" -ge 128 ]; then
        echo "=== claude 가 시그널로 종료 (exit=$rc) — 루프를 멈춘다"
        break
      fi
      echo "--- $2s 대기"
      sleep "$2"
    done
    ;;

  --once)
    run_once | tee -a "$SLOT_DIR/once.log"
    ;;

  stop)
    if [ -n "${2:-}" ]; then
      stop_slot "$2"
    else
      FOUND=0
      for f in "$SLOT_DIR"/*.pid; do
        [ -e "$f" ] || continue
        n=$(basename "$f" .pid)
        slot_alive "$n" && FOUND=$((FOUND+1))
        stop_slot "$n"
      done
      [ "$FOUND" -eq 0 ] && echo "실행 중 아님"
    fi
    exit 0
    ;;

  status)
    RUNNING=0
    for f in "$SLOT_DIR"/*.pid; do
      [ -e "$f" ] || continue
      n=$(basename "$f" .pid)
      if slot_alive "$n"; then
        RUNNING=$((RUNNING+1))
        echo "[slot $n] 실행 중: PID $(cat "$f")"
        tail -1 "$(slot_log "$n")" 2>/dev/null | sed 's/^/    /'
      else
        echo "[slot $n] PID 파일 잔존 = 비정상 종료. 'stop $n' 으로 정리"
      fi
    done
    [ "$RUNNING" -eq 0 ] && echo "실행 중인 슬롯 없음 (상한 $(max_slots))"
    exit 0
    ;;

  *)
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

    WANT="${2:-1}"
    if [ -z "${WANT//[0-9]/}" ] && [ -n "$WANT" ] && [ "$WANT" -ge 1 ]; then :; else
      echo "슬롯 수 오류: '${2}' (1 이상 정수)" >&2
      exit 1
    fi
    MAX=$(max_slots)
    if [ "$WANT" -gt "$MAX" ]; then
      echo "요청 $WANT 개는 상한을 넘는다 — $MAX 개로 줄인다 (min(16, cores-2))" >&2
      WANT="$MAX"
    fi

    STARTED=0
    for n in $(seq 1 "$MAX"); do
      [ "$STARTED" -ge "$WANT" ] && break
      slot_alive "$n" && continue          # 이미 쓰는 슬롯은 건너뛴다
      nohup "$0" __run "$INTERVAL" "$n" >> "$(slot_log "$n")" 2>&1 &
      echo $! > "$(slot_pid "$n")"
      echo "[slot $n] 기동: PID $(cat "$(slot_pid "$n")") / 간격 ${INTERVAL}s / model=$MODEL"
      STARTED=$((STARTED+1))
    done

    if [ "$STARTED" -eq 0 ]; then
      echo "빈 슬롯이 없다 — 이미 $MAX 개가 돌고 있다. 'status' 로 확인." >&2
      exit 1
    fi
    [ "$STARTED" -lt "$WANT" ] && echo "요청 $WANT 개 중 $STARTED 개만 기동 (나머지는 슬롯 사용 중)" >&2
    echo "로그: $SLOT_DIR/{슬롯}.log"
    echo "정지: bash ~/.claude/bin/tick-loop.sh stop"
    ;;
esac
