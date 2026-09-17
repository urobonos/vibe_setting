#!/usr/bin/env bash
# code-loop-usage.py 검증. 격리 HOME 에 가짜 run·jsonl 을 깔고 돌린다.
#
# 이 도구의 값은 매핑 하나다 — 귀속이 틀리면 남의 비용을 남의 run 에 붙인다.
# 그래서 "세는가" 만큼 "안 세야 할 것을 안 세는가" 를 같이 본다.
set -uo pipefail

HELPER="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/code-loop-usage.py}"
PY=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
[ -n "$PY" ] || { echo "python 없음 — 테스트 불가"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export CLAUDE_HOME="$TMP/.claude"
STATE="$CLAUDE_HOME/state/code-loop"
PROJ="$CLAUDE_HOME/projects/p1"
mkdir -p "$STATE" "$PROJ"

pass=0; fail=0
check() { # $1 이름 / $2 기대 패턴 / $3 실제
  if printf '%s' "$3" | grep -qE "$2"; then
    printf '   PASS %s\n' "$1"; pass=$((pass+1))
  else
    printf '   FAIL %s — 기대 /%s/ 없음\n실제:\n%s\n' "$1" "$2" "$3"; fail=$((fail+1))
  fi
}
run() { "$PY" "$HELPER" 2>&1; }

mkrun() { # $1 run / $2... run.log 줄들
  local r="$1"; shift; mkdir -p "$STATE/$r"
  printf '%s\n' "$@" > "$STATE/$r/run.log"
}
mkjsonl() { # $1 sid / $2 run / $3 model / $4 in / $5 cr / $6 cw / $7 out
  {
    printf '{"type":"user","content":"산출 %s/state/code-loop/%s/dev-01.md 를 쓴다"}\n' \
      "$CLAUDE_HOME" "$2"
    printf '{"type":"assistant","message":{"model":"%s","usage":{"input_tokens":%s,"cache_read_input_tokens":%s,"cache_creation_input_tokens":%s,"output_tokens":%s}}}\n' \
      "$3" "$4" "$5" "$6" "$7"
  } > "$PROJ/$1.jsonl"
}

echo "== A. run 없음 =="
check "빈 상태" 'run 없음' "$(run)"

echo "== B. 상태 판정 =="
mkrun r-done '--- 10:00:00 [spec] model=sonnet try=1' '--- [spec] ok'
: > "$STATE/r-done/RESULT.md"
mkrun r-abort '--- 10:00:00 [dev-01] model=sonnet try=1' '!!! 리뷰어 실패 — 중단'
mkrun r-live '--- 10:00:00 [dev-01] model=sonnet try=1' '--- 10:05:00 [rev-01-design] model=sonnet try=1'
out=$(run)
check "RESULT 있으면 완료"   'r-done +완료'            "$out"
check "!!! 이면 중단"        'r-abort +중단'           "$out"
check "마지막 스텝이 진행"   'r-live +rev-01-design 진행' "$out"

echo "== C. !!! 뒤에 스텝이 또 뜨면 이어받은 것 (중단 아님) =="
mkrun r-resume '--- 10:00:00 [dev-01] model=sonnet try=1' '!!! 산출 없음' '--- 10:09:00 [dev-01] model=sonnet try=2'
check "재시도는 진행" 'r-resume +dev-01 진행' "$(run)"

echo "== D. 비용 환산 (sonnet base 2/out 10, cr=x0.1, cw=x2) =="
# in 1M + cr 1M + cw 1M + out 1M = 2 + 0.2 + 4 + 10 = $16.20
mkrun r-cost '--- 10:00:00 [dev-01] model=sonnet try=1'
mkjsonl s-cost r-cost claude-sonnet-5 1000000 1000000 1000000 1000000
check "sonnet 환산" 'r-cost +.*\$16\.20' "$(run)"

echo "== E. opus 단가는 다르다 (5/25) =="
# 2 + 0.5*... → in 1M*5 + cr 1M*0.5 + cw 1M*10 + out 1M*25 = $40.50
mkrun r-opus '--- 10:00:00 [adv-01] model=opus try=1'
mkjsonl s-opus r-opus claude-opus-5 1000000 1000000 1000000 1000000
check "opus 환산" 'r-opus +.*\$40\.50' "$(run)"

echo "== F. 무관한 jsonl 은 귀속되지 않는다 =="
printf '{"type":"user","content":"그냥 대화"}\n{"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":9000000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":0}}}\n' \
  > "$PROJ/s-unrelated.jsonl"
check "남의 비용 안 붙음" 'r-opus +.*\$40\.50' "$(run)"

echo "== G. 존재하지 않는 run 을 가리키는 jsonl 도 제외 =="
mkjsonl s-ghost r-nonexistent claude-opus-5 9000000 0 0 0
out=$(run)
check "유령 run 미표시" 'r-opus +.*\$40\.50' "$out"
[ "$(printf '%s' "$out" | grep -c 'r-nonexistent')" = "0" ] \
  && { echo '   PASS 유령 run 행이 없다'; pass=$((pass+1)); } \
  || { echo '   FAIL 유령 run 이 표에 떴다'; fail=$((fail+1)); }

echo "== H. 스텝 대조 열 (jsonl/run.log) =="
# r-cost 는 run.log 스텝 1 · jsonl 1 → 1/1
check "대조 열" 'r-cost +.*1/1' "$(run)"

echo "== J. 접두 충돌 — 짧은 run 이 긴 run 의 비용을 가져가면 안 된다 =="
# 실데이터에 있는 모양이다 (…-hello-world 와 …-hello-world2)
mkrun p-base  '--- 10:00:00 [dev-01] model=sonnet try=1'
mkrun p-base2 '--- 10:00:00 [dev-01] model=sonnet try=1'
mkjsonl s-p2 p-base2 claude-sonnet-5 1000000 0 0 0   # $2.00 은 p-base2 것이다
out=$(run)
check "긴 쪽에 붙는다"  'p-base2 +.*1/1 +.*\$2\.00' "$out"
check "짧은 쪽은 0"     '^p-base +[^ ]+ +[^ ]+ +0/1' "$out"

echo "== K. 컨텍스트 열 — 평균과 최대는 누적이 아니라 호출 1회의 무게다 =="
mkrun r-ctx '--- 10:00:00 [dev-01] model=sonnet try=1'
# 두 번의 모델 호출: ctx = in+read+write = 100,000 과 300,000 -> 평균 200K · 최대 300K
{
  printf '{"type":"user","content":"%s/state/code-loop/r-ctx/dev-01.md"}
' "$CLAUDE_HOME"
  printf '{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":0,"cache_read_input_tokens":90000,"cache_creation_input_tokens":10000,"output_tokens":500}}}
'
  printf '{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":0,"cache_read_input_tokens":300000,"cache_creation_input_tokens":0,"output_tokens":500}}}
'
} > "$PROJ/s-ctx.jsonl"
out=$(run)
check "평균 200K" '^r-ctx .*200\.0K' "$out"
check "최대 300K" '^r-ctx .*200\.0K +300\.0K' "$out"
# output_tokens 는 컨텍스트가 아니다 — 1,000 이 섞여 들어가면 위 수치가 어긋난다
check "출력토큰 미포함" '^r-ctx .*200\.0K +300\.0K' "$out"

echo "== L. 호출이 하나도 안 잡힌 run 은 '-' 로 낸다 (0 으로 위장하지 않는다) =="
mkrun r-empty '--- 10:00:00 [spec] model=sonnet try=1'
check "빈 run" '^r-empty .*[0-9]/[0-9] +- +-' "$(run)"

echo "== I. run.log 없는 디렉토리는 run 이 아니다 =="
mkdir -p "$STATE/not-a-run"
[ "$(run | grep -c 'not-a-run')" = "0" ] \
  && { echo '   PASS run.log 없으면 제외'; pass=$((pass+1)); } \
  || { echo '   FAIL run.log 없는 디렉토리가 떴다'; fail=$((fail+1)); }

echo
echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
