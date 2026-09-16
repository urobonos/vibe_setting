#!/usr/bin/env bash
# code-loop.sh 루프 제어 흐름 드라이런 (2026-09-16)
#
# claude 를 stub 으로 가로채고 HOME 을 임시 디렉토리로 격리해서, API 를 한 번도
# 부르지 않고 루프 제어만 검증한다. 검증 대상은 셸이 책임지는 것 전부 —
# 캡 · VERDICT 분기 · 크기 게이트 · fail-closed · 재시도 · 재개.
# 모델 판단 품질은 여기 대상이 아니다 (그건 실제 run 의 라운드 수가 말한다).
#
# 사용: bash bin/tests/code-loop-dryrun.sh
set -uo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/code-loop.sh"
[ -f "$SUT" ] || { echo "code-loop.sh 를 못 찾았다: $SUT"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
export PATH="$TMP/bin:$PATH"
ST="$HOME/.claude/state/code-loop"
mkdir -p "$TMP/bin" "$ST" \
         "$HOME/.claude/custom-plugin/taskflow/agents" \
         "$HOME/.claude/custom-plugin/taskflow/commands"
for a in step-developer reviewer-correctness reviewer-design adversary; do
  echo "# $a (dryrun dummy)" > "$HOME/.claude/custom-plugin/taskflow/agents/$a.md"
done
for c in code code-loop watch; do
  echo "# $c (dryrun dummy)" > "$HOME/.claude/custom-plugin/taskflow/commands/$c.md"
done

# ── claude stub ───────────────────────────────────────────────────────────
# 프롬프트에서 산출 경로를 뽑아 그 파일을 만든다. VERDICT 는 시나리오가 정한다.
# 주의: 이 환경의 `grep -oE` 는 한글 리터럴 추출이 실패한다 (C.UTF-8 + -o).
#       그래서 줄 필터는 한글로, 경로 추출은 ASCII 패턴으로 2단 분리한다.
cat > "$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
prompt=""; for a in "$@"; do prompt="$prompt $a"; done
out=$(printf '%s' "$prompt" | grep -E '쓴다|쓰고' | grep -oE '/[^ ]*\.md' | tail -1)
[ -n "$out" ] || { echo "stub: 산출 경로 못 찾음" >&2; exit 0; }
base=$(basename "$out")
if [ -n "${T_NOWRITE:-}" ] && printf '%s' "$base" | grep -q "$T_NOWRITE"; then
  echo "stub: $base 안 씀 (실패 경로)"; exit 0
fi
pick() { printf '%s' "$1" | cut -d, -f"$2"; }
last() { printf '%s' "$1" | rev | cut -d, -f1 | rev; }
case "$base" in
  00-spec.md)
    printf 'spec\n\nGATE: %s\n' "${T_GATE:-OK}" > "$out" ;;
  rev-*-correctness.md|rev-*-design.md)
    printf 'reviewer (stub)\n' > "$out" ;;
  rev-*.md)
    if [ -n "${T_NOVERDICT:-}" ]; then printf '합본인데 VERDICT 없음\n' > "$out"
    else
      n=$(printf '%s' "$base" | sed 's/rev-0*\([0-9]*\)\.md/\1/')
      v=$(pick "${T_REV:-CLEAN}" "$n"); [ -n "$v" ] || v=$(last "${T_REV:-CLEAN}")
      printf '합본 (stub)\n\nVERDICT: %s\n' "$v" > "$out"
    fi ;;
  adv-*.md)
    m=$(printf '%s' "$base" | sed 's/adv-0*\([0-9]*\)\.md/\1/')
    v=$(pick "${T_ADV:-UPHELD}" "$m"); [ -n "$v" ] || v=$(last "${T_ADV:-UPHELD}")
    printf 'adversary (stub)\n\nVERDICT: %s\n' "$v" > "$out" ;;
  dev-*.md)
    printf 'FILES: x\nTESTS: y\nBASELINE: z\nWHY: stub\n' > "$out" ;;
  *)
    printf 'stub\n' > "$out" ;;
esac
echo "stub: wrote $base"
STUB
chmod +x "$TMP/bin/claude"

# ── 하네스 ────────────────────────────────────────────────────────────────
pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then printf '   PASS %s (%s)\n' "$1" "$3"; pass=$((pass + 1))
  else printf '   FAIL %s — 기대 [%s] 실제 [%s]\n' "$1" "$2" "$3"; fail=$((fail + 1)); fi
}
reset() { find "$ST" -mindepth 1 -maxdepth 1 -type d -exec rm -r {} + 2>/dev/null; mkdir -p "$ST"; }
runit() { env "$@" bash "$SUT" "드라이런 요청" > "$TMP/out.txt" 2>&1; echo $?; }
d()     { find "$ST" -mindepth 1 -maxdepth 1 -type d | head -1; }
cnt()   { find "$(d)" -name "$1" 2>/dev/null | wc -l | tr -d ' '; }
merged(){ find "$(d)" -name 'rev-0*.md' -not -name '*-correctness.md' -not -name '*-design.md' 2>/dev/null | wc -l | tr -d ' '; }

echo "== A. 1라운드 클린 → UPHELD =="
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD)
check "exit" 0 "$rc"
check "dev 라운드수" 1 "$(cnt 'dev-*.md')"
check "adv 회차" 1 "$(cnt 'adv-*.md')"
check "RESULT 생성" 1 "$([ -s "$(d)/RESULT.md" ] && echo 1 || echo 0)"

echo "== B. 3라운드 후 클린 =="
reset; rc=$(runit T_REV='FINDINGS C=0 H=1 M=0,FINDINGS C=0 H=0 M=2,CLEAN' T_ADV=UPHELD)
check "exit" 0 "$rc"
check "dev 라운드수" 3 "$(cnt 'dev-*.md')"
check "합본 라운드수" 3 "$(merged)"

echo "== C. 캡 5 소진 — adv 안 돈다 =="
reset; rc=$(runit T_REV='FINDINGS C=1 H=0 M=0' T_ADV=UPHELD)
check "dev 라운드수(캡)" 5 "$(cnt 'dev-*.md')"
check "adv 미실행" 0 "$(cnt 'adv-*.md')"
check "캡 메시지" 1 "$(grep -c '캡 5 소진' "$TMP/out.txt")"

echo "== D. adv BROKEN → dev 재진입(정규 캡 계상) =="
reset; rc=$(runit T_REV=CLEAN T_ADV='BROKEN,UPHELD')
check "dev 라운드수(1+재진입)" 2 "$(cnt 'dev-*.md')"
check "재진입 메시지" 1 "$(grep -c 'dev-loop 재진입' "$TMP/out.txt")"

echo "== E. 크기 게이트 TOO-LARGE → 정지 =="
reset; rc=$(runit T_GATE=TOO-LARGE)
check "exit" 2 "$rc"
check "dev 미실행" 0 "$(cnt 'dev-*.md')"

echo "== F. VERDICT 줄 없음 → fail-closed 중단 =="
reset; rc=$(runit T_NOVERDICT=1 T_REV=CLEAN T_ADV=UPHELD)
check "exit(fail-closed)" 1 "$rc"
check "중단 메시지" 1 "$(grep -c 'VERDICT 줄이 없다' "$TMP/out.txt")"
check "adv 미실행" 0 "$(cnt 'adv-*.md')"

echo "== G. 산출 파일 미생성 → 재시도 2회 후 중단 =="
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD T_NOWRITE=dev-01)
check "exit" 1 "$rc"
check "재시도 2회" 2 "$(grep -c 'dev-01\] model=.* try=' "$TMP/out.txt")"

echo "== H. --resume — 기존 산출물 재실행 안 함 =="
reset; runit T_REV='FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD > /dev/null
RUN=$(basename "$(d)"); before=$(md5sum "$(d)/dev-01.md" | cut -d' ' -f1)
env T_REV='FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "기존 산출물 보존" "$before" "$(md5sum "$ST/$RUN/dev-01.md" | cut -d' ' -f1)"

echo "== I. stdout 이 끊겨도 루프는 완주한다 (SIGPIPE 내성) =="
# 2026-09-16 회귀: tee 로 미러링하던 때는 호출자가 head 로 파이프를 닫으면 tee 가
# SIGPIPE 로 죽고 루프까지 죽었다 (run.log 205 bytes 에서 중단, RESULT.md 미생성)
reset
env T_REV=CLEAN T_ADV=UPHELD bash "$SUT" "드라이런 요청" 2>&1 | head -3 > /dev/null
check "완주" 1 "$(grep -c 'code-loop 종료' "$(d)/run.log" 2>/dev/null || echo 0)"
check "RESULT 생성" 1 "$([ -s "$(d)/RESULT.md" ] && echo 1 || echo 0)"

echo "== J. run.log 에 진행이 남는다 =="
reset; runit T_REV='FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD > /dev/null
check "라운드 로그" 2 "$(grep -c 'dev-loop 라운드' "$(d)/run.log")"
check "스텝 로그" 1 "$([ "$(grep -c '^--- .*\[' "$(d)/run.log")" -ge 8 ] && echo 1 || echo 0)"

echo
echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
