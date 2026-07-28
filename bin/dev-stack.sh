#!/usr/bin/env bash
# dev-stack.sh — 검증용 dev docker 스택 보장 (2026-07-28)
#
# 왜 필요한가:
#   e2e 5점의 4번이 "실제 엔드포인트 curl 200 확인" 이다 (php8 §e2e 검증).
#   살아 있는 환경이 없으면 tick 의 verify 가 애초에 완결되지 않는다.
#   대상은 로컬 docker 로 고정한다 — EC2 dev 는 공유 자원이라 무인 루프가
#   건드리면 안 된다 (CLAUDE.md §4.3 "서버 우선 디버그" = 사용자 명시 승인 영역).
#
# 왜 up 만 자동인가:
#   `docker compose up -d` 는 idempotent 라 이미 떠 있으면 아무것도 하지 않는다.
#   그래서 병렬 슬롯 N 개가 동시에 불러도 안전하다. 반대로 down 은 자동화하지
#   않는다 — 슬롯 하나가 내리면 같은 스택을 쓰는 다른 슬롯의 검증이 깨진다.
#   down 은 사람이 명시 호출할 때만이다.
#
# 사용:
#   dev-stack.sh up       기동 보장 (이미 떠 있으면 즉시 반환)
#   dev-stack.sh status   헬스체크만 (exit 0 = 응답함)
#   dev-stack.sh down     내림 — 사람 전용. tick 계열은 절대 호출하지 않는다
#
# 환경변수 override:
#   DEV_STACK_REPO (기본 /c/Works/hongcafe_global_backend)
#   DEV_STACK_URL  (기본 http://localhost/)  헬스체크 대상
#   DEV_STACK_WAIT (기본 180)  기동 후 헬스 대기 상한(초). 최초 빌드는 수 분 걸린다
# SSOT: custom-plugin/taskflow/commands/tick.md §"dev 스택 보장"
set -uo pipefail

REPO="${DEV_STACK_REPO:-/c/Works/hongcafe_global_backend}"
URL="${DEV_STACK_URL:-http://localhost/}"
WAIT="${DEV_STACK_WAIT:-180}"
COMPOSE="$REPO/docker-compose.yml"
LOCK_DIR="$HOME/.claude/state/dev-stack.lock"

healthy() { curl -fsS -m 3 -o /dev/null "$URL" 2>/dev/null; }

case "${1:-status}" in
  status)
    if healthy; then
      echo "dev 스택 정상 ($URL)"
      exit 0
    fi
    echo "dev 스택 응답 없음 ($URL)" >&2
    exit 1
    ;;

  up)
    # 이미 떠 있으면 여기서 끝난다 — 병렬 호출의 대부분이 이 경로를 탄다
    if healthy; then
      echo "dev 스택 이미 정상 ($URL)"
      exit 0
    fi

    [ -f "$COMPOSE" ] || { echo "compose 파일 없음: $COMPOSE" >&2; exit 1; }
    docker info >/dev/null 2>&1 || { echo "docker 데몬이 꺼져 있다" >&2; exit 1; }

    # 최초 기동 race 방지 — mkdir 은 원자적이다 (Git Bash 에 flock 이 없다).
    # 락을 못 잡으면 다른 프로세스가 올리는 중이므로 그 결과를 기다린다.
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
      echo "dev 스택 기동 중... (최초 빌드는 수 분 걸린다)"
      docker compose -f "$COMPOSE" up -d 2>&1 | sed 's/^/  /'
    else
      echo "다른 프로세스가 기동 중 — 대기한다"
    fi

    for _ in $(seq 1 "$WAIT"); do
      healthy && { echo "dev 스택 준비됨 ($URL)"; exit 0; }
      sleep 1
    done
    echo "기동은 했으나 ${WAIT}s 안에 응답하지 않는다 ($URL)" >&2
    exit 1
    ;;

  down)
    # 사람 전용. tick 계열이 이걸 부르면 다른 슬롯의 검증이 깨진다.
    [ -f "$COMPOSE" ] || { echo "compose 파일 없음: $COMPOSE" >&2; exit 1; }
    docker compose -f "$COMPOSE" down 2>&1 | sed 's/^/  /'
    ;;

  *)
    echo "사용: dev-stack.sh [up|status|down]" >&2
    exit 1
    ;;
esac
