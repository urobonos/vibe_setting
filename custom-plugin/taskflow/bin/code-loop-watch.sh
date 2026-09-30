#!/usr/bin/env bash
# code-loop run 감시 — 세션이 Monitor 로 run 을 지켜볼 때 이 스크립트만 건다.
# 맨 `tail -F` 는 스스로 끝나지 않고, Monitor 가 끝나도 Windows(MSYS)에서는 부모 셸만 죽어 고아로 남는다.
# 그래서 run 마다 tail 에 --pid=<러너 PID> 를 붙여 러너가 끝나면 tail·필터가 함께 끝나게 한다.
#
# 사용: code-loop-watch.sh <run>... [-- <grep -E 패턴>]
#   <run> = state/code-loop 아래 run 디렉토리 이름 또는 경로. 러너가 이미 끝난 run 은 건너뛴다.
#   패턴 기본값 = 판정·중단·종료·TOO-LARGE·!!! 줄. 출력 = "<run 태그>: <줄>".

STATE_DIR="${HOME}/.claude/state/code-loop"
pat='^=== .*판정|중단|code-loop 종료|TOO-LARGE|!!!'
runs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --) pat="$2"; shift 2 ;;
    *)  runs+=("$1"); shift ;;
  esac
done
[ ${#runs[@]} -gt 0 ] || { echo "사용: $0 <run>... [-- <grep -E 패턴>]" >&2; exit 2; }

n=0
for r in "${runs[@]}"; do
  d="${r%/}"; [ -d "$d" ] || d="$STATE_DIR/$d"
  name=$(basename "$d")
  pid=$(cat "$d/.lock/pid" 2>/dev/null)
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    echo "$name: 러너 없음(종료됨) — 감시 생략"
    continue
  fi
  tag=$(printf '%s' "$name" | sed -E 's/^[0-9]{8}-[0-9]{6}-//' | cut -c1-22)
  tail -n0 -F --pid="$pid" "$d/run.log" 2>/dev/null \
    | grep --line-buffered -E "$pat" | sed -u "s|^|$tag: |" &
  n=$((n + 1))
done
[ "$n" -gt 0 ] || exit 0
wait
echo "감시 종료 — 대상 러너 모두 종료"
