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
# dummy 정의도 frontmatter 를 갖춰야 한다 — agent_tools 가 거기서 도구 목록을 뽑고,
# agent_body 가 거기까지를 잘라낸다. 실제 정의와 같은 도구 배치를 쓴다
# (개발자만 Edit/Write 보유, 리뷰어·adversary 는 읽기 전용)
for a in reviewer-correctness reviewer-design adversary; do
  cat > "$HOME/.claude/custom-plugin/taskflow/agents/$a.md" <<AGENT
---
name: $a
tools: Read, Glob, Grep, Bash
model: sonnet
---

$a 본문 (dryrun dummy)
AGENT
done
cat > "$HOME/.claude/custom-plugin/taskflow/agents/step-developer.md" <<'AGENT'
---
name: step-developer
tools: Read, Glob, Grep, Edit, Write, Bash
model: sonnet
---

step-developer 본문 (dryrun dummy)
AGENT
for c in code code-loop watch; do
  echo "# $c (dryrun dummy)" > "$HOME/.claude/custom-plugin/taskflow/commands/$c.md"
done

# ── claude stub ───────────────────────────────────────────────────────────
# 프롬프트에서 산출 경로를 뽑아 그 파일을 만든다. VERDICT 는 시나리오가 정한다.
# 주의: 이 환경의 `grep -oE` 는 한글 리터럴 추출이 실패한다 (C.UTF-8 + -o).
#       그래서 줄 필터는 한글로, 경로 추출은 ASCII 패턴으로 2단 분리한다.
cat > "$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
# 실제 CLI 와 같은 계약으로 받는다 — 프롬프트는 stdin, 도구 제한은 --allowed-tools.
# (인자로 받던 예전 stub 은 프롬프트가 --- 로 시작할 때 CLI 가 옵션으로 파싱하는
#  실제 결함을 못 잡았다. 2026-09-16 실사용에서 처음 드러났다)
tools=""; strict=0
while [ $# -gt 0 ]; do
  case "$1" in
    --allowed-tools) tools="${2:-}"; shift 2 ;;
    --strict-mcp-config) strict=1; shift ;;
    *) shift ;;
  esac
done
prompt=$(cat)
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
    # T_GATE_LINE 이 설정돼 있으면(빈 값 포함) 판정 줄을 원문 그대로 쓴다 — 표기 변형·줄 없음 검사용
    if [ -n "${T_GATE_LINE+x}" ]; then printf 'spec\n\n%s\n' "$T_GATE_LINE" > "$out"
    else printf 'spec\n\nGATE: %s\n' "${T_GATE:-OK}" > "$out"; fi ;;
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
# 스텝마다 실제로 넘어온 도구 제한과 프롬프트 첫 줄을 남긴다 — 리뷰어에게 Edit/Write 가
# 새는지, frontmatter 가 프롬프트에 섞이는지를 테스트가 검사할 수 있게
if [ -n "${T_TOOLSLOG:-}" ]; then
  printf '%s|%s|%s|%s\n' "$base" "$tools" "$(printf '%s' "$prompt" | head -1)" "$strict" >> "$T_TOOLSLOG"
fi
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

echo "== D. adv BROKEN → dev 재진입 + 리뷰 1라운드(정규 캡 계상) =="
# 2026-09-16 ISS-570 실전 회귀: BROKEN 뒤 dev 수정분이 리뷰 없이 다음 게이트로 갔다.
# adversary 는 깨는 역할이지 판정 역할이 아니라 그 수정은 아무도 안 본 변경이 된다
reset; rc=$(runit T_REV=CLEAN T_ADV='BROKEN,UPHELD')
check "dev 라운드수(1+재진입)" 2 "$(cnt 'dev-*.md')"
check "재진입 메시지" 1 "$(grep -c 'dev-loop 재진입' "$TMP/out.txt")"
check "adv 수정분 리뷰 실행" 1 "$([ -s "$(d)/rev-02.md" ] && echo 1 || echo 0)"
check "합본 라운드수" 2 "$(merged)"
check "adv 2회차 진입" 2 "$(cnt 'adv-*.md')"

echo "== M. adv 수정분에 지적이 남으면 게이트를 닫는다 =="
# 정규 루프로 되돌리지 않는다 — 게이트 캡이 정규 캡을 늘리는 통로가 되면
# 클린 직전에 라운드가 무한히 열린다
reset; rc=$(runit T_REV='CLEAN,FINDINGS C=0 H=1 M=0' T_ADV='BROKEN,UPHELD')
check "adv 2회차 미실행" 1 "$(cnt 'adv-*.md')"
check "게이트 닫힘 메시지" 1 "$(grep -c '지적 잔존' "$TMP/out.txt")"
check "RESULT 는 생성" 1 "$([ -s "$(d)/RESULT.md" ] && echo 1 || echo 0)"

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

echo "== K. 도구 제한이 스텝별로 전달된다 =="
# 2026-09-16 실사용 회귀: 정의의 tools 는 Agent 도구로 spawn 할 때만 적용된다.
# claude -p 로 띄우면 제한이 없어 리뷰어·adversary 가 Edit/Write 를 쓸 수 있었다 —
# 짠 쪽과 본 쪽을 가르는 것이 이 루프의 값 전부라 여기가 비면 루프가 무의미해진다
reset; export T_TOOLSLOG="$TMP/tools.log"; : > "$T_TOOLSLOG"
runit T_REV=CLEAN T_ADV=UPHELD > /dev/null
rev_tools=$(grep '^rev-01-correctness.md|' "$T_TOOLSLOG" | cut -d'|' -f2)
adv_tools=$(grep '^adv-01.md|' "$T_TOOLSLOG" | cut -d'|' -f2)
dev_tools=$(grep '^dev-01.md|' "$T_TOOLSLOG" | cut -d'|' -f2)
check "리뷰어에 Edit 안 감" 0 "$(printf '%s' "$rev_tools" | grep -c Edit)"
check "리뷰어에 Write 안 감" 0 "$(printf '%s' "$rev_tools" | grep -c Write)"
check "adversary 에 Edit 안 감" 0 "$(printf '%s' "$adv_tools" | grep -c Edit)"
check "개발자에 Write 감" 1 "$(printf '%s' "$dev_tools" | grep -c Write)"

echo "== L. frontmatter 가 프롬프트에 안 섞인다 =="
# 프롬프트가 --- 로 시작하면 CLI 가 옵션으로 파싱한다 (error: unknown option '---)
check "dev 프롬프트 첫 줄이 --- 아님" 0 "$(grep '^dev-01.md|' "$T_TOOLSLOG" | cut -d'|' -f3 | grep -c '^---')"
check "rev 프롬프트 첫 줄이 --- 아님" 0 "$(grep '^rev-01-design.md|' "$T_TOOLSLOG" | cut -d'|' -f3 | grep -c '^---')"
echo "== U. 모든 스텝이 MCP 서버를 띄우지 않는다 (--strict-mcp-config) =="
# 도구 제한이 있는 스텝(dev·리뷰어·adv)과 없는 스텝(spec·merge·result) 두 분기를
# 다 탄다 — 한쪽에만 붙으면 제한 없는 스텝이 여전히 npx 로 MCP 를 띄운다
check "기록된 스텝 6개 이상"      1 "$([ "$(wc -l < "$T_TOOLSLOG")" -ge 6 ] && echo 1 || echo 0)"
check "strict 누락 스텝 0"        0 "$(cut -d'|' -f4 "$T_TOOLSLOG" | grep -vc '^1$')"
check "제한 없는 spec 도 strict"  1 "$(grep '^00-spec.md|' "$T_TOOLSLOG" | cut -d'|' -f4)"
check "제한 있는 dev 도 strict"   1 "$(grep '^dev-01.md|' "$T_TOOLSLOG" | cut -d'|' -f4)"
unset T_TOOLSLOG

echo "== N. --resume 이 adv 수정분 판정을 덮지 않는다 =="
# adv BROKEN 뒤 dev 수정은 "FILES: 없음"(고칠 코드가 없다)으로 끝나는 경우가 실재한다.
# 그 판정이 재실행으로 덮이면 왜 안 고쳤는지가 함께 사라진다 (ISS-570 dev-02 실측)
reset; runit T_REV=CLEAN T_ADV='BROKEN,UPHELD' > /dev/null
RUN=$(basename "$(d)")
printf '판정: FILES 없음 — 고칠 코드가 없다\n' > "$ST/$RUN/dev-02.md"
before=$(md5sum "$ST/$RUN/dev-02.md" | cut -d' ' -f1)
env T_REV=CLEAN T_ADV='BROKEN,UPHELD' bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "adv 수정분 판정 보존" "$before" "$(md5sum "$ST/$RUN/dev-02.md" | cut -d' ' -f1)"
check "재사용 로그" 1 "$(grep -c '기존 산출물 재사용' "$TMP/out.txt")"

echo "== W. GATE 판정 줄 — 헤더·강조 표기는 인정, 줄 없음·본문 언급은 중단 (fail-closed) =="
# 러너가 TOO-LARGE 로 시작하는 줄만 찾던 시절엔 헤더형 TOO-LARGE 도, 판정 줄 없음도 진행했다
reset; rc=$(runit T_GATE_LINE='## GATE: OK' T_REV=CLEAN T_ADV=UPHELD)
check "## GATE: OK 진행" 0 "$rc"
check "## GATE: OK 개발자 실행" 1 "$(cnt 'dev-*.md')"
reset; rc=$(runit T_GATE_LINE='**GATE: OK**' T_REV=CLEAN T_ADV=UPHELD)
check "**GATE: OK** 진행" 0 "$rc"
reset; rc=$(runit T_GATE_LINE='## GATE: TOO-LARGE')
check "## GATE: TOO-LARGE 정지" 2 "$rc"
check "헤더형 TOO-LARGE 개발자 미실행" 0 "$(cnt 'dev-*.md')"
reset; rc=$(runit T_GATE_LINE=)
check "판정 줄 없음 중단" 1 "$rc"
check "판정 줄 없음 개발자 미실행" 0 "$(cnt 'dev-*.md')"
check "중단 메시지" 1 "$(grep -c 'GATE 판정 줄이 없다' "$TMP/out.txt")"
reset; rc=$(runit T_GATE_LINE='- 이전엔 GATE: OK 였다')
check "본문 언급만 있으면 중단" 1 "$rc"

echo
echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
