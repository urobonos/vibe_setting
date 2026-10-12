#!/usr/bin/env bash
# code-loop.sh 루프 제어 흐름 드라이런
#
# claude 를 stub 으로 가로채고 HOME 을 임시 디렉토리로 격리해서, API 를 한 번도
# 부르지 않고 루프 제어만 검증한다. 검증 대상은 셸이 책임지는 것 전부 —
# 캡 · VERDICT 분기 · 크기 게이트 · fail-closed · 재시도 · 재개.
# 모델 판단 품질은 여기 대상이 아니다 (그건 실제 run 의 라운드 수가 말한다).
#
# 사용: bash custom-plugin/taskflow/bin/tests/code-loop-dryrun.sh
set -uo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/code-loop.sh"
[ -f "$SUT" ] || { echo "code-loop.sh 를 못 찾았다: $SUT"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
export PATH="$TMP/bin:$PATH"
# 러너 기본 캡은 5 다(무제한은 0 명시). 시나리오 C 처럼 지적이 영원히 남는 경우 캡을 안 주면
# 루프가 끝나지 않고 드라이런이 좀비로 남아 하위 프로세스를 띄운다.
# 이 테스트의 기대값(캡 5)을 명시하고, 실행마다 상한을 건다
export CODE_LOOP_DEV_CAP=5 CODE_LOOP_ADV_CAP=2
RUN_TIMEOUT=900   # 무한 루프만 끊으면 된다 — 동시 code-loop 부하에서 7왕복 시나리오가 300초를 넘는다
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
tools=""; strict=0; model=""; effort=""
while [ $# -gt 0 ]; do
  case "$1" in
    --allowed-tools) tools="${2:-}"; shift 2 ;;
    --model) model="${2:-}"; shift 2 ;;
    --effort) effort="${2:-}"; shift 2 ;;
    --strict-mcp-config) strict=1; shift ;;
    *) shift ;;
  esac
done
prompt=$(cat)
out=$(printf '%s' "$prompt" | grep -E '쓴다|쓰고' | grep -oE '/[^ ]*\.md' | tail -1)
[ -n "$out" ] || { echo "stub: 산출 경로 못 찾음" >&2; exit 0; }
base=$(basename "$out")
# 멈춘 스텝 흉내 — 자식까지 띄워 두고 기다린다. 시간 상한이 트리째 끊는지 본다
if [ -n "${T_HANG:-}" ] && [ "$base" = "$T_HANG" ]; then
  sleep 611 & echo "$!" > "${T_HANG_PID:?}"; wait; exit 0
fi
if [ -n "${T_NOWRITE:-}" ] && printf '%s' "$base" | grep -q "$T_NOWRITE"; then
  echo "stub: $base 안 씀 (실패 경로)"; exit 0
fi
# 사용량 한도 흉내 — 실제 CLI 문구(run 20260917-132300)로 끝난다. T_LIMITMSG 가 있으면 그 문구만 내고 정상 진행(대조군)
if [ -n "${T_LIMIT:-}" ] && [ "$base" = "$T_LIMIT" ]; then
  limit_msg="You've hit your session limit · resets 1:40pm (Asia/Seoul)"
  echo "${T_LIMITMSG:-$limit_msg}"
  [ -n "${T_LIMITMSG:-}" ] || exit 1
fi
pick() { printf '%s' "$1" | cut -d, -f"$2"; }
last() { printf '%s' "$1" | rev | cut -d, -f1 | rev; }
case "$base" in
  00-spec.md)
    # 착수 불가 반환 — 00-spec.md 없이 RESULT.md 판정 줄만 (T_SPEC_DECLINE_RC 로 exit 코드 지정)
    if [ -n "${T_SPEC_DECLINE:-}" ]; then
      printf '# 결과\n\n## 판정: 미착수 (stub)\n\n재진입 조건: 없음\n' > "$(dirname "$out")/RESULT.md"
      exit "${T_SPEC_DECLINE_RC:-0}"
    fi
    [ -n "${T_SPEC_NOOUT:-}" ] && exit 0
    # T_GATE_LINE 이 설정돼 있으면(빈 값 포함) 판정 줄을 원문 그대로 쓴다 — 표기 변형·줄 없음 검사용
    if [ -n "${T_GATE_LINE+x}" ]; then printf 'spec\n\n%s\n' "$T_GATE_LINE" > "$out"
    else printf 'spec\n\nGATE: %s\n' "${T_GATE:-OK}" > "$out"; fi
    [ -n "${T_WT:-}" ] && printf 'WORKTREE: %s\n' "$T_WT" >> "$out"
    [ -n "${T_SPECNOTE:-}" ] && printf '%b\n' "$T_SPECNOTE" >> "$out" ;;
  rev-*-correctness.md)
    # T_RC/T_RD 가 있으면 반환 양식을 갖춘 리뷰어 문서 — 셸 합본 경로 검사용
    printf '%b' "${T_RC:-reviewer (stub)\n}" > "$out" ;;
  rev-*-design.md)
    printf '%b' "${T_RD:-reviewer (stub)\n}" > "$out" ;;
  rev-*.md)
    if [ -n "${T_NOVERDICT:-}" ]; then printf '합본인데 VERDICT 없음\n' > "$out"
    else
      n=$(printf '%s' "$base" | sed 's/rev-0*\([0-9]*\)\.md/\1/')
      v=$(pick "${T_REV:-CLEAN}" "$n"); [ -n "$v" ] || v=$(last "${T_REV:-CLEAN}")
      printf "합본 (stub)\n\n${T_VFMT:-VERDICT: %s}\n" "$v" > "$out"
    fi ;;
  adv-*.md)
    m=$(printf '%s' "$base" | sed 's/adv-0*\([0-9]*\)\.md/\1/')
    v=$(pick "${T_ADV:-UPHELD}" "$m"); [ -n "$v" ] || v=$(last "${T_ADV:-UPHELD}")
    printf "adversary (stub)\n%b\n${T_VFMT:-VERDICT: %s}\n" "${T_ADVNOTE:-}" "$v" > "$out" ;;
  dev-*.md)
    # 코드를 바꾼 dev 흉내 — worktree 의 파일 내용을 매번 바꿔 라운드 diff 가 0 이 아니게 한다
    [ -n "${T_DEVTOUCH:-}" ] && echo "$base" >> "$T_DEVTOUCH"
    printf 'FILES:\n%b\nTESTS: y\nBASELINE: %b\nWHY: stub\n%b\n' "${T_DEVFILES:-- x}" "${T_BASELINE:-z}" "${T_DEVNOTE:-}" > "$out" ;;
  *)
    printf 'stub\n' > "$out" ;;
esac
# 스텝마다 실제로 넘어온 도구 제한과 프롬프트 첫 줄을 남긴다 — 리뷰어에게 Edit/Write 가
# 새는지, frontmatter 가 프롬프트에 섞이는지를 테스트가 검사할 수 있게
# 프롬프트 전문 — 러너가 조립한 문자열이 잘리지 않았는지 검사용 (2026-09-28 따옴표 절단 사고)
[ -n "${T_PROMPTDIR:-}" ] && printf '%s' "$prompt" > "$T_PROMPTDIR/$base.prompt"
if [ -n "${T_TOOLSLOG:-}" ]; then
  printf '%s|%s|%s|%s\n' "$base" "$tools" "$(printf '%s' "$prompt" | head -1)" "$strict" >> "$T_TOOLSLOG"
fi
[ -n "${T_MODELLOG:-}" ] && printf '%s|%s|%s\n' "$base" "$model" "${effort:--}" >> "$T_MODELLOG"
echo "stub: wrote $base"
STUB
chmod +x "$TMP/bin/claude"

# ── vendor-pool.sh stub — 러너가 넘긴 인자만 남긴다 ─────────────────────────
mkdir -p "$HOME/.claude/bin"
cat > "$HOME/.claude/bin/vendor-pool.sh" <<'VPOOL'
#!/usr/bin/env bash
echo "$*" >> "$HOME/vendor-pool.calls"
VPOOL

# ── 하네스 ────────────────────────────────────────────────────────────────
pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then printf '   PASS %s (%s)\n' "$1" "$3"; pass=$((pass + 1))
  else printf '   FAIL %s — 기대 [%s] 실제 [%s]\n' "$1" "$2" "$3"; fail=$((fail + 1)); fi
}
reset() { find "$ST" -mindepth 1 -maxdepth 1 -type d -exec rm -r {} + 2>/dev/null; mkdir -p "$ST"; }
runit() { env "$@" timeout "$RUN_TIMEOUT" bash "$SUT" "드라이런 요청" > "$TMP/out.txt" 2>&1; local rc=$?; cat "$TMP/out.txt" >> "$TMP/all-out.txt"; echo $rc; }
d()     { find "$ST" -mindepth 1 -maxdepth 1 -type d | head -1; }
cnt()   { find "$(d)" -name "$1" 2>/dev/null | wc -l | tr -d ' '; }
merged(){ find "$(d)" -name 'rev-0*.md' -not -name '*-correctness.md' -not -name '*-design.md' 2>/dev/null | wc -l | tr -d ' '; }

echo "== A. 1라운드 클린 → UPHELD =="
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD)
check "exit" 0 "$rc"
check "dev 라운드수" 1 "$(cnt 'dev-*.md')"
check "adv 회차" 1 "$(cnt 'adv-*.md')"
check "RESULT 생성" 1 "$([ -s "$(d)/RESULT.md" ] && echo 1 || echo 0)"

# 프롬프트 조립 무결성 — 프롬프트 본문의 큰따옴표가 bash 문자열을 끊으면 `local` 이 조각을 변수명으로
# 받아 오류를 내고 나머지(요청·GATE 지시)가 조용히 잘린다. stub 은 경로만 보고 파일을 써서 이걸 못 봤다
check "셸 오류 0" 0 "$(grep -cE 'not a valid identifier|command not found|syntax error|unexpected EOF' "$TMP/out.txt")"
reset; export T_PROMPTDIR="$TMP/prompts"; rm -rf "$T_PROMPTDIR"; mkdir -p "$T_PROMPTDIR"
rc=$(runit T_REV=CLEAN T_ADV=UPHELD)
check "spec 프롬프트에 요청 본문" 1 "$(grep -c '드라이런 요청' "$T_PROMPTDIR/00-spec.md.prompt")"
check "spec 프롬프트에 GATE 지시" 1 "$(grep -c 'GATE: TOO-LARGE' "$T_PROMPTDIR/00-spec.md.prompt")"
check "dev 프롬프트가 spec 을 가리킴" 1 "$([ "$(grep -c '00-spec.md' "$T_PROMPTDIR/dev-01.md.prompt")" -ge 1 ] && echo 1 || echo 0)"
unset T_PROMPTDIR

echo "== B. 3라운드 후 클린 =="
reset; rc=$(runit T_REV='FINDINGS C=0 H=1 M=0,FINDINGS C=0 H=0 M=2,CLEAN' T_ADV=UPHELD)
check "exit" 0 "$rc"
check "dev 라운드수" 3 "$(cnt 'dev-*.md')"
check "합본 라운드수" 3 "$(merged)"

echo "== C. 캡 5 소진 — adv 안 돈다 =="
# 판정 문자열을 번갈아 준다 — 같은 FINDINGS 가 4라운드 연속이면 캡 전에 정체 정지로 끝난다(AK)
reset; rc=$(runit T_REV='FINDINGS C=1 H=0 M=0,FINDINGS C=0 H=1 M=0,FINDINGS C=1 H=0 M=0,FINDINGS C=0 H=1 M=0,FINDINGS C=1 H=0 M=0' T_ADV=UPHELD)
check "dev 라운드수(캡)" 5 "$(cnt 'dev-*.md')"
check "adv 미실행" 0 "$(cnt 'adv-*.md')"
check "캡 메시지" 1 "$(grep -c '캡 5 소진' "$TMP/out.txt")"

echo "== D. adv BROKEN → dev 재진입 + 리뷰 1라운드(정규 캡 계상) =="
# BROKEN 뒤 dev 수정분이 리뷰 없이 다음 게이트로 가면 안 된다.
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
env T_REV='FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD timeout "$RUN_TIMEOUT" bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "기존 산출물 보존" "$before" "$(md5sum "$ST/$RUN/dev-01.md" | cut -d' ' -f1)"

echo "== I. stdout 이 끊겨도 루프는 완주한다 (SIGPIPE 내성) =="
# tee 로 미러링하면 호출자가 head 로 파이프를 닫을 때 tee 가 SIGPIPE 로 죽고
# 루프까지 죽을 수 있다
reset
env T_REV=CLEAN T_ADV=UPHELD timeout "$RUN_TIMEOUT" bash "$SUT" "드라이런 요청" 2>&1 | head -3 > /dev/null
check "완주" 1 "$(grep -c 'code-loop 종료' "$(d)/run.log" 2>/dev/null || echo 0)"
check "RESULT 생성" 1 "$([ -s "$(d)/RESULT.md" ] && echo 1 || echo 0)"

echo "== J. run.log 에 진행이 남는다 =="
reset; runit T_REV='FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD > /dev/null
check "라운드 로그" 2 "$(grep -c 'dev-loop 라운드' "$(d)/run.log")"
check "스텝 로그" 1 "$([ "$(grep -c '^--- .*\[' "$(d)/run.log")" -ge 8 ] && echo 1 || echo 0)"

echo "== K. 도구 제한이 스텝별로 전달된다 =="
# 정의의 tools 는 Agent 도구로 spawn 할 때만 적용된다. claude -p 로 띄우면 제한이
# 없어 리뷰어·adversary 가 Edit/Write 를 쓸 수 있다 — 짠 쪽과 본 쪽을 가르는 것이
# 이 루프의 값 전부라 여기가 비면 루프가 무의미해진다
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
# adv BROKEN 뒤 dev 수정은 "FILES: 없음"(고칠 코드가 없다)으로 끝나는 경우가 있다.
# 그 판정이 재실행으로 덮이면 왜 안 고쳤는지가 함께 사라진다
reset; runit T_REV=CLEAN T_ADV='BROKEN,UPHELD' > /dev/null
RUN=$(basename "$(d)")
printf '판정: FILES 없음 — 고칠 코드가 없다\n' > "$ST/$RUN/dev-02.md"
before=$(md5sum "$ST/$RUN/dev-02.md" | cut -d' ' -f1)
env T_REV=CLEAN T_ADV='BROKEN,UPHELD' timeout "$RUN_TIMEOUT" bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "adv 수정분 판정 보존" "$before" "$(md5sum "$ST/$RUN/dev-02.md" | cut -d' ' -f1)"
check "재사용 로그" 1 "$(grep -c '기존 산출물 재사용' "$TMP/out.txt")"

echo "== W. GATE 판정 줄 — 헤더·강조 표기는 인정, 줄 없음·본문 언급은 중단 (fail-closed) =="
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

echo "== X. VERDICT 판정 줄 — 헤더·강조 표기는 인정, 본문 언급은 중단 (fail-closed) =="
# 합본 스텝이 `## VERDICT: …` 로 쓰면 헤더 표기를 인정해야 한다 — GATE 줄(W)은 헤더
# 표기를 인정하는데 VERDICT 줄만 못 읽는 비대칭을 막는다
reset; rc=$(runit T_VFMT='## VERDICT: %s' T_REV=CLEAN T_ADV=UPHELD)
check "헤더 표기 — 완주" 0 "$rc"
check "헤더 표기 — adv 도달" 1 "$(cnt 'adv-*.md')"
reset; rc=$(runit T_VFMT='**VERDICT: %s**' T_REV=CLEAN T_ADV='BROKEN,UPHELD')
check "강조 표기 — adv 수정분 리뷰 통과 후 2회차" 2 "$(cnt 'adv-*.md')"
check "강조 표기 — 판정 값에 ** 안 남음" 0 "$(grep -c 'UPHELD\*\*' "$TMP/out.txt")"
reset; rc=$(runit T_VFMT='- 이전 판정은 VERDICT: %s 였다' T_REV=CLEAN T_ADV=UPHELD)
check "본문 언급만 있으면 중단" 1 "$rc"
check "본문 언급 — adv 미실행" 0 "$(cnt 'adv-*.md')"

echo "== Y. 러너가 WORKTREE 의 vendor 를 직접 채운다 (ISS-285 후속) =="
# 에이전트 재량에 두면 원본 vendor 로 junction 을 건다 — 그 worktree 를 --force 로 지우면
# 원본 vendor 가 따라 지워진다. 그래서 러너가 WORKTREE: 줄을 읽고 ensure 를 부른다
WT_PHP="$TMP/wt-php"; WT_NOLOCK="$TMP/wt-nolock"
mkdir -p "$WT_PHP" "$WT_NOLOCK"; : > "$WT_PHP/composer.lock"
reset; : > "$HOME/vendor-pool.calls"
rc=$(runit T_WT="$WT_PHP" T_REV=CLEAN T_ADV=UPHELD)
check "exit" 0 "$rc"
check "ensure 1회 · 인자 = WORKTREE" "ensure $WT_PHP" "$(cat "$HOME/vendor-pool.calls")"
vendor_line=$(grep -n '\[vendor\] ensure' "$(d)/run.log" | head -1 | cut -d: -f1)
dev_line=$(grep -n '\[dev-01\]' "$(d)/run.log" | head -1 | cut -d: -f1)
check "ensure 가 dev 보다 먼저" 1 "$([ -n "$vendor_line" ] && [ -n "$dev_line" ] && [ "$vendor_line" -lt "$dev_line" ] && echo 1 || echo 0)"
check "spec 프롬프트에 링크 금지" 1 "$(grep -c 'junction·symlink 로 링크하지 않는다' "$SUT")"
reset; : > "$HOME/vendor-pool.calls"
runit T_WT="$WT_NOLOCK" T_REV=CLEAN T_ADV=UPHELD > /dev/null
check "composer.lock 없으면 호출 안 함" 0 "$(wc -l < "$HOME/vendor-pool.calls" | tr -d ' ')"
reset; : > "$HOME/vendor-pool.calls"
runit T_REV=CLEAN T_ADV=UPHELD > /dev/null
check "WORKTREE 줄 없으면 호출 안 함" 0 "$(wc -l < "$HOME/vendor-pool.calls" | tr -d ' ')"
reset; runit T_WT="$WT_PHP" T_GATE=TOO-LARGE > /dev/null
check "TOO-LARGE 면 호출 안 함" 0 "$(wc -l < "$HOME/vendor-pool.calls" | tr -d ' ')"

echo "== Z. 합본 셸화 — 판단이 필요 없는 라운드만 셸, 나머지는 LLM 합본 =="
RC_CLEAN='VERDICT: CLEAN\nBLOCKERS: 0\nFINDINGS: 없음\n'
RC_HIGH='VERDICT: FINDINGS\nBLOCKERS: 1\nFINDINGS:\n- [High] a.php:3 — x → y | 근거: 실행\n- [Low] a.php:9 — n → m | 근거: 정적\n'
RD_MED='VERDICT: FINDINGS\nBLOCKERS: 0\nFINDINGS:\n- [Medium] b.php:1 — p → q | 근거: 정적\n'
RD_LOW='VERDICT: FINDINGS\nBLOCKERS: 0\nFINDINGS:\n- [Low] b.php:1 — p → q | 근거: 정적\n'
llm_merge() { grep -c "merge-$1\] model=" "$TMP/out.txt"; }
reset; rc=$(runit T_RC="$RC_CLEAN" T_RD="$RC_CLEAN" T_ADV=UPHELD)
check "둘 다 CLEAN — 완주" 0 "$rc"
check "둘 다 CLEAN — 셸 합본" 1 "$(grep -c 'merge-01\] 셸 합본 (CLEAN)' "$TMP/out.txt")"
check "둘 다 CLEAN — LLM 합본 미호출" 0 "$(llm_merge 01)"
check "둘 다 CLEAN — adv 도달" 1 "$(cnt 'adv-*.md')"
reset; rc=$(runit CODE_LOOP_DEV_CAP=1 T_RC="$RC_HIGH" T_RD="$RD_MED")
check "지적 잔존 — 건수 합산" 1 "$(grep -c 'VERDICT: FINDINGS C=0 H=1 M=1' "$(d)/rev-01.md")"
check "지적 잔존 — 원문 지적 줄 보존" 3 "$(grep -c '^- \[' "$(d)/rev-01.md")"
check "지적 잔존 — adv 미실행" 0 "$(cnt 'adv-*.md')"
reset; rc=$(runit T_RC="$RC_CLEAN" T_RD="$RD_LOW" T_ADV=UPHELD)
check "Low 만 — CLEAN 으로 통과" 1 "$(grep -c '셸 합본 (CLEAN)' "$TMP/out.txt")"
reset; rc=$(runit T_RC="$RC_CLEAN" T_RD="$RC_CLEAN" T_DEVNOTE='REBUTTED:\n- [High] a.php:3 — 수정하지 않음. 근거: x\nDEFERRED: 없음' T_ADV=UPHELD)
check "REBUTTED — LLM 합본으로" 1 "$(llm_merge 01)"
check "REBUTTED — 셸 합본 안 함" 0 "$(grep -c '셸 합본' "$TMP/out.txt")"
reset; rc=$(runit T_RC="$RC_CLEAN" T_RD="$RC_CLEAN" T_DEVNOTE='FIXED: 없음\nREBUTTED: 없음\nDEFERRED: 없음' T_ADV=UPHELD)
check "REBUTTED: 없음 필드만 — 셸 합본" 1 "$(grep -c '셸 합본 (CLEAN)' "$TMP/out.txt")"
reset; rc=$(runit T_RC="$RC_CLEAN" T_RD="$RC_CLEAN" T_DEVNOTE='DEFERRED:\n- [Critical] a.php:1 — 잔여로 넘김' T_ADV=UPHELD)
check "Critical DEFERRED — LLM 합본으로" 1 "$(llm_merge 01)"
reset; rc=$(runit T_RC="$RC_CLEAN" T_RD="$RC_CLEAN" T_DEVNOTE='DEFERRED:\n- [Low] a.php:1 — 잔여로 넘김' T_ADV=UPHELD)
check "Low DEFERRED — 셸 합본" 1 "$(grep -c '셸 합본 (CLEAN)' "$TMP/out.txt")"
reset; rc=$(runit T_RC='VERDICT: CLEAN\n- [Medium] a.php:1 — x → y\n' T_RD="$RC_CLEAN" T_ADV=UPHELD)
check "CLEAN 인데 Medium — LLM 합본으로" 1 "$(llm_merge 01)"
reset; rc=$(runit T_RC='VERDICT: FINDINGS\n지적은 본문에 산문으로\n' T_RD="$RC_CLEAN" T_ADV=UPHELD)
check "FINDINGS 인데 지적 줄 없음 — LLM 합본으로" 1 "$(llm_merge 01)"

echo "== AA. UPHELD 인데 재현된 이탈 — 셸이 BROKEN 으로 승격 =="
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD T_ADVNOTE='재현된 이탈: 0년 날짜가 통과 (스크래치 테스트)\n잔여 의심: 없음')
check "재현된 이탈 — 승격 로그" 1 "$([ "$(grep -c '셸 승격' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
check "재현된 이탈 — dev 재진입" 1 "$([ "$(grep -c 'dev-loop 재진입' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD T_ADVNOTE='재현된 이탈: 없음\n잔여 의심: 재현 못한 경합')
check "재현된 이탈 없음 — 승격 안 함" 0 "$(grep -c '셸 승격' "$TMP/out.txt")"
check "재현된 이탈 없음 — adv 1회로 종료" 1 "$(cnt 'adv-*.md')"
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD T_ADVNOTE='재현된 이탈: 없음.')
check "없음. (마침표) — 승격 안 함" 0 "$(grep -c '셸 승격' "$TMP/out.txt")"

echo "== AB. 변이 기준이 있는데 MUTATION 줄이 없으면 재보고 (verify_gate 배선) =="
reset; rc=$(runit T_SPECNOTE='MUTATIONS: 1' T_REV=CLEAN T_ADV=UPHELD)
check "변이 줄 누락 — 재보고 요청" 1 "$([ "$(grep -c 'MUTATION 줄은 0건' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
check "변이 줄 누락 — 소진 후에도 완주" 0 "$rc"
reset; rc=$(runit T_SPECNOTE='MUTATIONS: 0' T_REV=CLEAN T_ADV=UPHELD)
check "변이 기준 0 — 재보고 없음" 0 "$(grep -c '셸 재검증 불일치' "$TMP/out.txt")"

echo
echo "== AD. phpstan 은 변경 줄 에러만 · 변이는 기계검사와 독립 (run 20260928-230103 ISS-970) =="
# 기존 에러 1건(변경 밖 줄)이 매 라운드 불일치를 내 변이 검증이 0회 돌았다
WT_STAN="$TMP/wt-stan"; mkdir -p "$WT_STAN/vendor/bin"
printf '<?php\n$a = 1;\n$b = 2;\n' > "$WT_STAN/a.php"
git -C "$WT_STAN" init -q; git -C "$WT_STAN" add a.php
git -C "$WT_STAN" -c user.email=t@t -c user.name=t commit -qm init
printf '<?php\n$a = 1;\n$b = 3;\n' > "$WT_STAN/a.php"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WT_STAN/vendor/bin/php-cs-fixer"
chmod +x "$WT_STAN/vendor/bin/php-cs-fixer"
stan() { printf '#!/usr/bin/env bash\necho "C:\\\\wt\\\\a.php:%s:Variable might not be defined."\nexit 1\n' "$1" > "$WT_STAN/vendor/bin/phpstan"; chmod +x "$WT_STAN/vendor/bin/phpstan"; }
stan 2
reset; rc=$(runit T_WT="$WT_STAN" T_DEVFILES='- a.php' T_REV=CLEAN T_ADV=UPHELD)
check "변경 밖 줄 에러 — 불일치 아님" 0 "$(grep -c '기계검사 불일치 — phpstan' "$TMP/out.txt")"
check "변경 밖 줄 에러 — 기존 코드로 표기" 1 "$([ "$(grep -c '변경 밖 줄(기존 코드)' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
stan 3
reset; rc=$(runit T_WT="$WT_STAN" T_DEVFILES='- a.php' T_REV=CLEAN T_ADV=UPHELD)
check "변경 줄 에러 — 불일치" 1 "$([ "$(grep -c '기계검사 불일치 — phpstan (변경 줄)' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
# 기계검사가 매번 막혀도(파일 없음) 변이 줄 누락은 매 시도 드러나야 한다
reset; rc=$(runit T_WT="$WT_STAN" T_DEVFILES='- missing.php' T_SPECNOTE='MUTATIONS: 1' T_REV=CLEAN T_ADV=UPHELD)
check "기계검사 실패 중에도 변이 판정" 1 "$([ "$(grep -c 'MUTATION 줄은 0건' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"

echo "== AE. assertion 0 BASELINE 은 RESULT 맨 위 [미검증] · FILES 의 (삭제) 는 기계검사 제외 (run 20260929-073124 ISS-971) =="
reset; rc=$(runit T_BASELINE='전: OK, but some tests were skipped! Tests: 23, Assertions: 0, Skipped: 23' T_REV=CLEAN T_ADV=UPHELD)
check "미검증 — RESULT 첫 줄" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미검증\]')"
reset; rc=$(runit T_BASELINE='green 23 tests, 57 assertions' T_REV=CLEAN T_ADV=UPHELD)
check "실행 증거 있으면 미검증 없음" 0 "$(grep -c '^> \[미검증\]' "$(d)/RESULT.md")"
reset; rc=$(runit T_WT="$WT_STAN" T_DEVFILES='- (삭제) tests/gone.php' T_REV=CLEAN T_ADV=UPHELD)
check "(삭제) 항목 — 파일 없음 아님" 0 "$(grep -c '파일 없음' "$TMP/out.txt")"

echo "== AF. 스텝 시간 상한 — TIMEOUT 기록 · 재시도 없음 · 자식 종료 (2026-09-29) =="
# 자식 트리 종료 자체는 실 claude.exe 로 확인했다(3/3 잔존 0). stub 은 msys fork 라 트리가 끊겨 자식이
# 남는다 — 그래서 여기서는 "남은 자식이 있어도 러너가 막히지 않는가" 를 본다(출력은 파이프가 아니라 파일)
t0=$(date +%s)
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD T_HANG=adv-01.md T_HANG_PID="$TMP/hang.pid" CODE_LOOP_STEP_TIMEOUT_MIN=0.05)
el=$(( $(date +%s) - t0 ))
check "TIMEOUT.md 기록" 1 "$(grep -c '^TIMEOUT: \[adv-01\]' "$(d)/TIMEOUT.md" 2>/dev/null)"
check "재시도 없음" 1 "$(grep -c '\[adv-01\] model=' "$TMP/out.txt")"
check "중단 표기" 1 "$([ "$(grep -c '!!! \[adv-01\] TIMEOUT' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
check "남은 자식에 막히지 않음(120초 이내)" 1 "$([ "$el" -lt 120 ] && echo 1 || echo 0)"
kill "$(cat "$TMP/hang.pid" 2>/dev/null)" 2>/dev/null

echo "== AG. phpstan 'No files found to analyse'(excludePaths) 는 불일치가 아니라 skip (run 723, 2026-09-29) =="
printf '#!/usr/bin/env bash\necho " [ERROR] No files found to analyse."\nexit 1\n' > "$WT_STAN/vendor/bin/phpstan"
reset; rc=$(runit T_WT="$WT_STAN" T_DEVFILES='- a.php' T_REV=CLEAN T_ADV=UPHELD)
check "excludePaths — 불일치 아님" 0 "$(grep -c '기계검사 불일치 — phpstan' "$TMP/out.txt")"
check "excludePaths — skip 기록" 1 "$([ "$(grep -c 'phpstan skip(excludePaths): a.php' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
# 대조군 — 같은 문구가 있어도 에러 줄이 함께 있으면 skip 이 아니다
printf '#!/usr/bin/env bash\necho " [ERROR] No files found to analyse."\necho "C:\\wt\\a.php:3:Undefined variable."\nexit 1\n' > "$WT_STAN/vendor/bin/phpstan"
reset; rc=$(runit T_WT="$WT_STAN" T_DEVFILES='- a.php' T_REV=CLEAN T_ADV=UPHELD)
check "에러 줄 동반 — skip 아님" 0 "$(grep -c 'phpstan skip(excludePaths)' "$TMP/out.txt")"

echo "== AH. 요청에 WORKTREE 가 있으면 vendor ensure 를 spec 과 겹쳐 돌린다 (2026-09-29) =="
VA="$TMP/wt-va"; VB="$TMP/wt-vb"; mkdir -p "$VA" "$VB"; echo '{}' > "$VA/composer.lock"; echo '{}' > "$VB/composer.lock"
export T_PROMPTDIR="$TMP/prompts-ah"; rm -rf "$T_PROMPTDIR"; mkdir -p "$T_PROMPTDIR"
runreq() { env "$@" timeout "$RUN_TIMEOUT" bash "$SUT" "$REQ" > "$TMP/out.txt" 2>&1; cat "$TMP/out.txt" >> "$TMP/all-out.txt"; }
REQ=$(printf '드라이런 요청\nWORKTREE: %s' "$VA")
reset; : > "$HOME/vendor-pool.calls"; runreq T_WT="$VA" T_REV=CLEAN T_ADV=UPHELD
check "겹침 — bg 시작 기록" 1 "$(grep -c '\[vendor\] ensure (bg): ' "$TMP/out.txt")"
check "겹침 — bg 시작이 spec 보다 먼저" 1 "$(awk '/\[vendor\] ensure \(bg\): /{v=NR} /\[spec\] model=/{s=NR} END{print (v && s && v<s)?1:0}' "$TMP/out.txt")"
check "겹침 — ensure 1회" "ensure $VA" "$(cat "$HOME/vendor-pool.calls")"
check "겹침 — 직렬 ensure 생략" 1 "$(grep -c '이미 채웠다' "$TMP/out.txt")"
check "겹침 — spec 에 vendor 명령 금지 공지" 1 "$(grep -c '러너 공지' "$T_PROMPTDIR/00-spec.md.prompt")"
reset; : > "$HOME/vendor-pool.calls"; runreq T_WT="$VB" T_REV=CLEAN T_ADV=UPHELD
check "폴백 — 다른 worktree 면 직렬 ensure 추가" "$(printf 'ensure %s\nensure %s' "$VA" "$VB")" "$(cat "$HOME/vendor-pool.calls")"
check "폴백 — 폴백 표기" 1 "$(grep -c '직렬 ensure 로 폴백' "$TMP/out.txt")"
REQ='드라이런 요청'
reset; : > "$HOME/vendor-pool.calls"; runreq T_WT="$VB" T_REV=CLEAN T_ADV=UPHELD
check "명시 없음 — bg 없음" 0 "$(grep -c 'ensure (bg)' "$TMP/out.txt")"
check "명시 없음 — 기존 직렬 1회" "ensure $VB" "$(cat "$HOME/vendor-pool.calls")"
unset T_PROMPTDIR

echo "== AI. spec 의 착수 불가 반환은 실패가 아니라 반환(종료 3) (run 20260929-141832 ISS-746) =="
reset; rc=$(runit T_SPEC_DECLINE=1)
check "반환 — 종료 3" 3 "$rc"
check "반환 — spec 재시도 없음" 1 "$(grep -c '\[spec\] model=' "$TMP/out.txt")"
check "반환 — 반환 기록" 1 "$([ "$(grep -c '반환(착수 불가)' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
check "반환 — 실패 기록 없음" 0 "$(grep -c '1단계 실패' "$TMP/out.txt")"
check "반환 — dev 안 돎" 0 "$(cnt 'dev-*.md')"
reset; rc=$(runit T_SPEC_NOOUT=1)
check "산출·RESULT 없음 — 실패(1)" 1 "$rc"
check "산출·RESULT 없음 — 기존대로 재시도" 2 "$(grep -c '\[spec\] model=' "$TMP/out.txt")"
reset; rc=$(runit T_SPEC_DECLINE=1 T_SPEC_DECLINE_RC=1)
check "미착수라도 exit≠0 — 실패(1)" 1 "$rc"

echo "== AJ. 등급 자동 결정 — 시작 = 모델 max(위험영역 최소치, spec TIER) · effort 전원 medium · 라운드·adv 깸으로 승격 =="
ML="$TMP/models.log"
tier_of() { grep "^$1|" "$ML" | tail -1 | cut -d'|' -f2,3; }
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" T_SPECNOTE='TIER: sonnet' T_REV=CLEAN T_ADV=UPHELD)
check "spec 판정 sonnet — dev" "sonnet|medium" "$(tier_of dev-01.md)"
check "spec 판정 sonnet — 리뷰어" "sonnet|medium" "$(tier_of rev-01-correctness.md)"
check "adv 는 opus:medium 시작" "opus|medium" "$(tier_of adv-01.md)"
check "spec 스텝은 opus:medium" "opus|medium" "$(tier_of 00-spec.md)"
check "RESULT 스텝은 sonnet" "sonnet|-" "$(tier_of RESULT.md)"
check "등급 이력 TIER.md" 1 "$(grep -c '^- 시작 dev=sonnet:medium' "$(d)/TIER.md")"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" T_SPECNOTE='TIER: opus\nEFFORT: xhigh' T_REV=CLEAN T_ADV=UPHELD)
check "spec 판정 opus — medium 에서 시작(EFFORT 줄 무시)" "opus|medium" "$(tier_of dev-01.md)"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" T_SPECNOTE='TIER: sonnet\nSCOPE_FILES: app/Database/Migrations/*' T_REV=CLEAN T_ADV=UPHELD)
check "위험영역 — spec 이 sonnet 이어도 opus:medium" "opus|medium" "$(tier_of dev-01.md)"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" T_REV=CLEAN T_ADV=UPHELD)
check "판정 줄 없음 — opus:medium" "opus|medium" "$(tier_of dev-01.md)"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" T_SPECNOTE='TIER: sonnet' T_REV='FINDINGS C=0 H=1 M=0,FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD)
check "리뷰 2라운드까지 유지" "sonnet|medium" "$(tier_of dev-02.md)"
check "3라운드째 승격 — dev" "opus|high" "$(tier_of dev-03.md)"
check "3라운드째 승격 — 리뷰어" "opus|high" "$(tier_of rev-03-design.md)"
check "승격 이력" 1 "$(grep -c '승격 .*리뷰 3라운드째' "$(d)/TIER.md")"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" CODE_LOOP_ADV_CAP=3 T_SPECNOTE='TIER: sonnet' T_REV=CLEAN T_ADV='BROKEN,BROKEN,UPHELD')
check "adv 1회 깸 — 수정 dev opus:high" "opus|high" "$(tier_of dev-02.md)"
check "adv 1회 깸 — 수정분 리뷰어 opus:high" "opus|high" "$(tier_of rev-02-correctness.md)"
check "adv 1회 깸 — adv 는 그대로" "opus|medium" "$(tier_of adv-02.md)"
check "adv 2회 깸 — 수정 dev opus:xhigh" "opus|xhigh" "$(tier_of dev-03.md)"
check "adv 2회 깸 — adv opus:xhigh" "opus|xhigh" "$(tier_of adv-03.md)"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" CODE_LOOP_MODEL_DEV=sonnet T_SPECNOTE='TIER: opus' T_REV='FINDINGS C=0 H=1 M=0,FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD)
check "환경변수 지정 dev — 자동 결정·승격 안 함" "sonnet|-" "$(tier_of dev-03.md)"
check "지정 안 한 리뷰어는 자동" "opus|medium" "$(tier_of rev-01-correctness.md)"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" CODE_LOOP_TIER=off T_SPECNOTE='TIER: opus' T_REV='FINDINGS C=0 H=1 M=0,FINDINGS C=0 H=1 M=0,CLEAN' T_ADV=UPHELD)
check "TIER=off — frontmatter 그대로" "sonnet|-" "$(tier_of dev-03.md)"
check "TIER=off — TIER.md 없음" 0 "$([ -e "$(d)/TIER.md" ] && echo 1 || echo 0)"
check "spec 프롬프트에 TIER 지시" 1 "$(T_PROMPTDIR="$TMP/p2"; mkdir -p "$T_PROMPTDIR"; reset; runit T_PROMPTDIR="$T_PROMPTDIR" T_REV=CLEAN T_ADV=UPHELD >/dev/null; grep -c 'TIER: sonnet | opus' "$T_PROMPTDIR/00-spec.md.prompt")"

echo "== AK. 정체 정지 — 캡 무제한이어도 같은 FINDINGS 4연속 · dev diff 0 2연속이면 [미수렴] 으로 끝낸다 (run 20260924-044841 ISS-915) =="
reset; rc=$(runit CODE_LOOP_DEV_CAP=0 T_REV='FINDINGS C=1 H=0 M=0' T_ADV=UPHELD)
check "같은 FINDINGS — 완주" 0 "$rc"
check "같은 FINDINGS — 4라운드에서 정지" 4 "$(cnt 'dev-*.md')"
check "같은 FINDINGS — 정지 로그" 1 "$(grep -c '=== 정체 정지 — 같은 판정' "$TMP/out.txt")"
check "같은 FINDINGS — adv 미실행" 0 "$(cnt 'adv-*.md')"
check "같은 FINDINGS — RESULT 첫 줄 [미수렴]" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미수렴\]')"
RUN=$(basename "$(d)")
env CODE_LOOP_DEV_CAP=0 T_REV='FINDINGS C=1 H=0 M=0' timeout "$RUN_TIMEOUT" bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "resume — 같은 라운드에서 다시 정지(dev 추가 없음)" 4 "$(find "$ST/$RUN" -name 'dev-*.md' | wc -l | tr -d ' ')"
check "resume — [미수렴] 중복 없음" 1 "$(grep -c '^> \[미수렴\]' "$ST/$RUN/RESULT.md")"
WT_STALL="$TMP/wt-stall"; mkdir -p "$WT_STALL"; echo base > "$WT_STALL/a.txt"
git -C "$WT_STALL" init -q; git -C "$WT_STALL" add a.txt
git -C "$WT_STALL" -c user.email=t@t -c user.name=t commit -qm init
REV_VARY='FINDINGS C=0 H=1 M=0,FINDINGS C=0 H=2 M=0,FINDINGS C=0 H=3 M=0,FINDINGS C=0 H=4 M=0,FINDINGS C=0 H=5 M=0'
reset; rc=$(runit CODE_LOOP_DEV_CAP=0 T_WT="$WT_STALL" T_REV="$REV_VARY" T_ADV=UPHELD)
check "diff 0 — 2라운드에서 정지" 2 "$(cnt 'dev-*.md')"
check "diff 0 — 정지 사유" 1 "$(grep -c '=== 정체 정지 — dev 코드 diff 0줄 2라운드 연속' "$TMP/out.txt")"
check "diff 0 — RESULT 첫 줄 [미수렴]" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미수렴\]')"
reset; rc=$(runit T_WT="$WT_STALL" T_DEVTOUCH="$WT_STALL/touch.txt" T_REV="$REV_VARY" T_ADV=UPHELD)
check "대조군 코드 변경 있음 — 캡까지 감" 5 "$(cnt 'dev-*.md')"
check "대조군 — 정체 정지 없음" 0 "$(grep -c '정체 정지' "$TMP/out.txt")"
check "대조군 — 배너에 정체 정지 없음" 0 "$(grep -c '정체 정지' "$(d)/RESULT.md")"
rm -f "$WT_STALL/touch.txt"
# 기본 캡 — 환경변수를 비우면 러너 기본값(5)이 걸린다. 위 전역 export 가 5 를 주므로 비워야 기본값 자체를 본다.
# 판정이 매번 달라 정체 정지로는 안 끊기는 폭주(21라운드 run)를 캡이 막는지
REV_VARY6="$REV_VARY,FINDINGS C=0 H=6 M=0"
reset; rc=$(runit CODE_LOOP_DEV_CAP= T_WT="$WT_STALL" T_DEVTOUCH="$WT_STALL/touch.txt" T_REV="$REV_VARY6" T_ADV=UPHELD)
check "기본 캡 — 5라운드에서 멈춤" 5 "$(cnt 'dev-*.md')"
check "기본 캡 — 라운드 표기 /5" 1 "$(grep -c '=== dev-loop 라운드 1/5' "$TMP/out.txt")"
rm -f "$WT_STALL/touch.txt"

echo "== AL. 사용량 한도 — 재시도·대기 없이 멈추고 --resume 으로 이어진다 (run 20260917-132300) =="
reset; rc=$(runit T_LIMIT=dev-01.md T_REV=CLEAN T_ADV=UPHELD)
check "한도 — 종료 75" 75 "$rc"
check "한도 — 재시도 없음" 1 "$(grep -c '\[dev-01\] model=' "$TMP/out.txt")"
check "한도 — reset 시각 기록" 1 "$(grep -c '^!!! LIMIT resets=1:40pm (Asia/Seoul)' "$(d)/run.log")"
check "한도 — 산출 없음" 0 "$(cnt 'dev-*.md')"
check "한도 — RESULT 없음" 0 "$([ -e "$(d)/RESULT.md" ] && echo 1 || echo 0)"
RUN=$(basename "$(d)")
env T_REV=CLEAN T_ADV=UPHELD timeout "$RUN_TIMEOUT" bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "한도 — resume 으로 완주" 1 "$([ -s "$ST/$RUN/RESULT.md" ] && echo 1 || echo 0)"
reset; rc=$(runit T_LIMIT=rev-01-design.md T_REV=CLEAN T_ADV=UPHELD)
check "병렬 리뷰어 한도 — 종료 75 전파" 75 "$rc"
check "병렬 리뷰어 한도 — 리뷰어 실패로 안 읽음" 0 "$(grep -c '리뷰어 실패' "$TMP/out.txt")"
reset; rc=$(runit T_LIMIT=dev-01.md T_LIMITMSG='The runner greps for hit your session limit in step output' T_REV=CLEAN T_ADV=UPHELD)
check "문구 인용(줄 머리 아님) — 한도 아님" 0 "$rc"
check "문구 인용 — LIMIT 로그 없음" 0 "$(grep -c '!!! LIMIT' "$TMP/out.txt")"

echo "== AM. 수치 재검증 — 매치 없음은 판정 보류 · Tests:/Assertions: 형식 · 생략 명령 skip · phpstan paths (backlog 2026-09-24) =="
WT_PU="$TMP/wt-pu"; mkdir -p "$WT_PU/vendor/bin"
cat > "$WT_PU/vendor/bin/phpunit" <<'PU'
#!/usr/bin/env bash
echo "$*" >> "$(dirname "$0")/../../pu.calls"
printf '%b\n' "${PU_OUT:-}"
PU
chmod +x "$WT_PU/vendor/bin/phpunit"
RC_CLAIM='VERDICT: CLEAN\n- `vendor/bin/phpunit tests/x` → OK (7 tests, 10 assertions)\n'
reset; rc=$(runit T_WT="$WT_PU" PU_OUT='Error: no config' T_RC="$RC_CLAIM" T_RD='VERDICT: CLEAN\n' T_ADV=UPHELD)
check "매치 없음 — 재검토 요청 안 함" 0 "$(grep -c '리뷰어 재검토 요청' "$TMP/out.txt")"
check "매치 없음 — 리뷰어 1회" 1 "$(grep -c '\[rev-01-correctness\] model=' "$TMP/out.txt")"
check "매치 없음 — 판정 보류 로그" 1 "$(grep -c '판정 보류 — 재실행 요약을 못 읽었다' "$TMP/out.txt")"
check "매치 없음 — RESULT 맨 위 [판정 보류] 배너" 1 "$(grep -c '^> \[판정 보류\]' "$(d)/RESULT.md")"
reset; rc=$(runit T_WT="$WT_PU" PU_OUT='FAILURES!\nTests: 7, Assertions: 10, Failures: 1.' T_RC="$RC_CLAIM" T_RD='VERDICT: CLEAN\n' T_ADV=UPHELD)
check "Tests: 형식 실측 — 일치로 읽음" 0 "$(grep -c '리뷰 주장 재검증 불일치' "$TMP/out.txt")"
check "Tests: 형식 실측 — 판정 보류 아님" 0 "$(grep -c '판정 보류' "$TMP/out.txt")"
reset; rc=$(runit T_WT="$WT_PU" PU_OUT='OK (8 tests, 12 assertions)' T_RC="$RC_CLAIM" T_RD='VERDICT: CLEAN\n' T_ADV=UPHELD)
check "대조군 수치 다름 — 재검토 요청" 1 "$([ "$(grep -c '리뷰어 재검토 요청' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
rm -f "$WT_PU/pu.calls"
reset; rc=$(runit T_WT="$WT_PU" PU_OUT='OK (8 tests, 12 assertions)' T_RC='VERDICT: CLEAN\n- `vendor/bin/phpunit --filter '\''a…'\''` → OK (7 tests, 10 assertions)\n- `vendor/bin/phpunit --filter '\''b...'\''` → OK (7 tests, 10 assertions)\n' T_RD='VERDICT: CLEAN\n' T_ADV=UPHELD)
check "생략 명령 — 실행 안 함" 0 "$([ -s "$WT_PU/pu.calls" ] && echo 1 || echo 0)"
BL_TESTS='\n$ vendor/bin/phpunit tests/x\n후: Tests: 7, Assertions: 10, Failures: 1'
reset; rc=$(runit T_WT="$WT_PU" PU_OUT='OK (8 tests, 12 assertions)' T_BASELINE="$BL_TESTS" T_REV=CLEAN T_ADV=UPHELD)
check "dev BASELINE Tests: 형식 주장 — 대조함(불일치 검출)" 1 "$([ "$(grep -c 'BASELINE 주장 vs 재실행 다름' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
reset; rc=$(runit T_WT="$WT_PU" PU_OUT='FAILURES!\nTests: 7, Assertions: 10, Failures: 1.' T_BASELINE="$BL_TESTS" T_REV=CLEAN T_ADV=UPHELD)
check "dev BASELINE Tests: 형식 — 일치" 0 "$(grep -c 'BASELINE 주장 vs 재실행 다름' "$TMP/out.txt")"
WT_NEON="$TMP/wt-neon"; mkdir -p "$WT_NEON/vendor/bin"
printf '<?php\n$a = 1;\n$b = 2;\n' > "$WT_NEON/a.php"
git -C "$WT_NEON" init -q; git -C "$WT_NEON" add a.php
git -C "$WT_NEON" -c user.email=t@t -c user.name=t commit -qm init
printf '<?php\n$a = 1;\n$b = 3;\n' > "$WT_NEON/a.php"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WT_NEON/vendor/bin/php-cs-fixer"
printf '#!/usr/bin/env bash\necho "C:\\\\wt\\\\a.php:3:Variable might not be defined."\nexit 1\n' > "$WT_NEON/vendor/bin/phpstan"
chmod +x "$WT_NEON/vendor/bin/php-cs-fixer" "$WT_NEON/vendor/bin/phpstan"
printf 'parameters:\n\tlevel: 3\n\tpaths:\n\t\t- app\n\texcludePaths:\n\t\tanalyse:\n\t\t\t- a.php\n' > "$WT_NEON/phpstan.neon"
reset; rc=$(runit T_WT="$WT_NEON" T_DEVFILES='- a.php' T_REV=CLEAN T_ADV=UPHELD)
check "paths 밖 — phpstan skip" 1 "$([ "$(grep -c 'phpstan skip(phpstan.neon paths 밖): a.php' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
check "paths 밖 — 불일치 아님" 0 "$(grep -c '기계검사 불일치 — phpstan' "$TMP/out.txt")"
printf 'parameters:\n\tpaths:\n\t\t- a.php # 단일 파일\n' > "$WT_NEON/phpstan.neon"
reset; rc=$(runit T_WT="$WT_NEON" T_DEVFILES='- a.php' T_REV=CLEAN T_ADV=UPHELD)
check "paths 안 — phpstan 돌아 불일치 검출" 1 "$([ "$(grep -c '기계검사 불일치 — phpstan (변경 줄)' "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"

echo "== AN. 정착 전 점검 — CLEAN+UPHELD 뒤 .env loopback · Docblock/EnvParity phpunit · iss-list [ERR] 를 배너로만 =="
WT_PRE="$TMP/wt-pre"; mkdir -p "$WT_PRE/vendor/bin" "$WT_PRE/tests/unit" "$WT_PRE/docs/wbs/tools" "$WT_PRE/docs/wbs/issue/progress"
echo base > "$WT_PRE/README.md"
git -C "$WT_PRE" init -q; git -C "$WT_PRE" add README.md
git -C "$WT_PRE" -c user.email=t@t -c user.name=t commit -qm init
cat > "$WT_PRE/vendor/bin/phpunit" <<'PU'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$(dirname "$0")/../../pu.calls"
echo 'OK (3 tests, 4 assertions)'
PU
chmod +x "$WT_PRE/vendor/bin/phpunit"
printf 'import sys\nopen("iss.calls", "a").write(" ".join(sys.argv[1:]) + "\\n")\nprint("[ERR] a", file=sys.stderr)\nprint("[ERR] b", file=sys.stderr)\nsys.exit(1)\n' > "$WT_PRE/docs/wbs/tools/iss-list.py"
echo '<?php' > "$WT_PRE/tests/unit/DocblockCitationTest.php"
echo 'x' > "$WT_PRE/docs/wbs/issue/progress/ISS-1.md"
printf 'CI_ENVIRONMENT = development\r\ndatabase.default.hostname = localhost\r\n' > "$WT_PRE/.env"
reset; rc=$(runit T_WT="$WT_PRE" T_REV=CLEAN T_ADV=UPHELD)
check "점검 — RESULT 첫 줄" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[정착 전 점검\]')"
check "점검 — .env loopback" 1 "$(grep -c '^>   - .env DB 호스트: loopback$' "$(d)/RESULT.md")"
check "점검 — phpunit 결과" 1 "$(grep -c 'DocblockCitation·EnvParity: OK (3 tests, 4 assertions)' "$(d)/RESULT.md")"
check "점검 — phpunit 필터" "--no-coverage --filter DocblockCitationTest|EnvParityTest" "$(tail -1 "$WT_PRE/pu.calls")"
check "점검 — iss-list [ERR] 수" 1 "$(grep -c 'iss-list.py --check: \[ERR\] 2건 (이슈 파일 변경 1건)' "$(d)/RESULT.md")"
check "점검 — iss-list 는 --check 로만" "--check" "$(tail -1 "$WT_PRE/iss.calls")"
rm -f "$WT_PRE/iss.calls"
printf 'database.default.hostname = "10.9.8.7" # 원격\n' > "$WT_PRE/.env"
reset; rc=$(runit T_WT="$WT_PRE" T_REV=CLEAN T_ADV=UPHELD)
check "원격 호스트 — loopback 아님 표기" 1 "$(grep -c 'loopback 아님(값 비표시)' "$(d)/RESULT.md")"
check "원격 호스트 — 값 비출력" 0 "$(cat "$(d)/RESULT.md" "$(d)/run.log" | grep -c '10\.9\.8\.7')"
rm -f "$WT_PRE/.env" "$WT_PRE/tests/unit/DocblockCitationTest.php" "$WT_PRE/docs/wbs/issue/progress/ISS-1.md" "$WT_PRE/iss.calls"
reset; rc=$(runit T_WT="$WT_PRE" T_REV=CLEAN T_ADV=UPHELD)
check "해당 없음 — .env 없음만" 1 "$(grep -c '^>   - ' "$(d)/RESULT.md")"
check "해당 없음 — .env 없음 표기" 1 "$(grep -c '.env DB 호스트: .env 없음' "$(d)/RESULT.md")"
check "해당 없음 — iss-list 안 돎" 0 "$([ -e "$WT_PRE/iss.calls" ] && echo 1 || echo 0)"
reset; rc=$(runit T_WT="$WT_PRE" CODE_LOOP_DEV_CAP=1 T_REV='FINDINGS C=0 H=1 M=0')
check "미수렴 run — 점검 배너 없음" 0 "$(grep -c '정착 전 점검' "$(d)/RESULT.md")"

echo "== AO. 종료 — 미수렴 첫 줄 · 중단도 run.log 에 종료 기록 · BROKEN-UNDECIDED 는 회차 밖 3회까지 =="
reset; rc=$(runit CODE_LOOP_DEV_CAP=1 T_REV='FINDINGS C=0 H=1 M=0')
check "캡 소진 — RESULT 첫 줄 [미수렴]" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미수렴\] dev=FINDINGS C=0 H=1 M=0 adv=(skipped)$')"
reset; rc=$(runit T_REV='CLEAN,FINDINGS C=0 H=1 M=0' T_ADV='BROKEN,UPHELD')
check "adv 수정분 지적 잔존 — [미수렴] adv=BROKEN" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미수렴\] dev=FINDINGS C=0 H=1 M=0 adv=BROKEN')"
reset; rc=$(runit T_REV=CLEAN T_ADV=UPHELD)
check "CLEAN+UPHELD — [미수렴] 없음" 0 "$(grep -c '미수렴' "$(d)/RESULT.md")"
check "정상 종료 — abort 기록 없음" 0 "$(grep -c 'abort=' "$(d)/run.log")"
reset; rc=$(runit T_NOVERDICT=1 T_REV=CLEAN T_ADV=UPHELD)
check "return 중단 — abort=1 기록" 1 "$(grep -c 'code-loop 종료 (abort=1)' "$(d)/run.log")"
reset; rc=$(runit T_LIMIT=dev-01.md T_REV=CLEAN T_ADV=UPHELD)
check "한도 exit — abort=75 기록" 1 "$(grep -c 'code-loop 종료 (abort=75)' "$(d)/run.log")"
reset
( env T_REV=CLEAN T_ADV=UPHELD T_HANG=dev-01.md T_HANG_PID="$TMP/hang-term.pid" CODE_LOOP_STEP_TIMEOUT_MIN=0.1 \
    timeout "$RUN_TIMEOUT" bash "$SUT" "드라이런 요청" > "$TMP/out.txt" 2>&1 ) &
bgp=$!
for i in $(seq 1 60); do [ -s "$TMP/hang-term.pid" ] && [ -s "$(d)/.lock/pid" ] && break; sleep 1; done
kill -TERM "$(cat "$(d)/.lock/pid" 2>/dev/null)" 2>/dev/null
wait "$bgp"
check "TERM — abort=143 기록" 1 "$(grep -c 'code-loop 종료 (abort=143)' "$(d)/run.log")"
kill "$(cat "$TMP/hang-term.pid" 2>/dev/null)" 2>/dev/null
reset; rc=$(runit CODE_LOOP_ADV_CAP=1 T_REV=CLEAN T_ADV=BROKEN-UNDECIDED)
check "UNDECIDED — 최초 1 + 재스폰 3" 4 "$(grep -c '\[adv-01\] model=' "$TMP/out.txt")"
check "UNDECIDED — 회차 증가 없음" 0 "$(grep -c 'adv-loop 2/' "$TMP/out.txt")"
check "UNDECIDED — 소진 로그" 1 "$(grep -c 'BROKEN-UNDECIDED 재스폰 3회 소진' "$TMP/out.txt")"
check "UNDECIDED — 마지막 판정 보존" 1 "$(cnt 'adv-*.md')"
check "UNDECIDED — RESULT 첫 줄 [미수렴]" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미수렴\] dev=CLEAN adv=BROKEN-UNDECIDED')"

echo "== AP. adv 캡 기본 2 — 캡 회차에서 BROKEN 이면 dev 재진입 없이 종료(4) · 0 은 무제한 =="
# 빈 값 = 미지정 — 이 테스트 전역의 CODE_LOOP_ADV_CAP=2 를 걷어 기본값을 본다
reset; rc=$(runit CODE_LOOP_ADV_CAP= CODE_LOOP_DEV_CAP=0 T_REV=CLEAN T_ADV='BROKEN,BROKEN')
check "기본 캡 — 종료 4" 4 "$rc"
check "기본 캡 — adv 2회" 2 "$(cnt 'adv-*.md')"
check "기본 캡 — 2회째 BROKEN 뒤 dev 재진입 없음" 2 "$(cnt 'dev-*.md')"
check "기본 캡 — 캡 도달 로그" 1 "$(grep -c '=== adv 캡 도달 (2/2) — dev 재진입 없이 종료' "$TMP/out.txt")"
check "기본 캡 — RESULT 첫 줄" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미수렴\] dev=CLEAN adv=BROKEN (adv 캡 도달 2/2)$')"
check "기본 캡 — status 표기" 1 "$(bash "$SUT" status 2>/dev/null | grep -c 'adv 캡 도달')"
reset; rc=$(runit CODE_LOOP_ADV_CAP=3 T_REV=CLEAN T_ADV='BROKEN,BROKEN,BROKEN')
check "캡 3 — 종료 4" 4 "$rc"
check "캡 3 — adv-03 에서 멈춤" 3 "$(cnt 'adv-*.md')"
check "캡 3 — dev 재진입 2회만" 3 "$(cnt 'dev-*.md')"
reset; rc=$(runit CODE_LOOP_ADV_CAP=0 CODE_LOOP_DEV_CAP=0 T_REV=CLEAN T_ADV='BROKEN,BROKEN,BROKEN,BROKEN,BROKEN,BROKEN,UPHELD')
check "캡 0 — 무제한 완주" 0 "$rc"
check "캡 0 — adv 7회" 7 "$(cnt 'adv-*.md')"
check "캡 0 — 캡 도달 없음" 0 "$(grep -c 'adv 캡 도달' "$TMP/out.txt")"

echo "== AQ. dev 권한 거부 — BLOCKED 줄이면 재보고·리뷰 없이 멈추고(77) --resume 으로 dev 부터 다시 =="
# 재보고로 다시 시키면 dev 가 다른 도구로 같은 변경을 우회 적용한다 — 셸이 멈춰 사람에게 넘겨야 한다
reset; rc=$(runit T_DEVNOTE='BLOCKED: 권한 거부 — Edit · stub' T_REV=CLEAN T_ADV=UPHELD)
check "거부 — 종료 77" 77 "$rc"
check "거부 — 리뷰 미실행" 0 "$(cnt 'rev-*.md')"
check "거부 — 재보고 요청 없음" 0 "$(grep -c '재보고 요청' "$TMP/out.txt")"
check "거부 — dev-01.md 를 옮김(resume 이 dev 를 건너뛰지 않게)" 0 "$(cnt 'dev-01.md')"
check "거부 — 원문 보존" 1 "$(grep -c '^BLOCKED: 권한 거부 — Edit · stub' "$(d)/blocked-dev-01.md")"
check "거부 — BLOCKED.md 사유" 1 "$(grep -c '^BLOCKED: 권한 거부 — Edit · stub' "$(d)/BLOCKED.md")"
check "거부 — RESULT 없음" 0 "$([ -e "$(d)/RESULT.md" ] && echo 1 || echo 0)"
RUN=$(basename "$(d)")
env T_REV=CLEAN T_ADV=UPHELD timeout "$RUN_TIMEOUT" bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "거부 — resume 이 dev 를 다시 태움" 1 "$([ -s "$ST/$RUN/dev-01.md" ] && grep -q '\[dev-01\] model=' "$TMP/out.txt" && echo 1 || echo 0)"
check "거부 — resume 완주" 1 "$([ -s "$ST/$RUN/RESULT.md" ] && echo 1 || echo 0)"
check "거부 — resume 뒤 BLOCKED.md 제거" 0 "$([ -e "$ST/$RUN/BLOCKED.md" ] && echo 1 || echo 0)"
# 대조군 — 줄 머리가 아닌 인용은 거부가 아니다
reset; rc=$(runit T_DEVNOTE='NOTES: 직전 시도의 BLOCKED: 줄은 없음' T_REV=CLEAN T_ADV=UPHELD)
check "인용(줄 머리 아님) — 정상 완주" 0 "$rc"
check "인용 — BLOCKED.md 없음" 0 "$([ -e "$(d)/BLOCKED.md" ] && echo 1 || echo 0)"

echo "== AR. 성공 기준 상한 — CODE_LOOP_CRITERIA_CAP 이 spec 프롬프트·게이트 안내를 바꾼다 (기본 3 · 0 = 상한 없음) =="
export T_PROMPTDIR="$TMP/prompts"
reset; rm -rf "$T_PROMPTDIR"; mkdir -p "$T_PROMPTDIR"; rc=$(runit T_REV=CLEAN T_ADV=UPHELD)
check "기본 — 3개 이하 문구" 1 "$(grep -c '성공 기준 3개 이하' "$T_PROMPTDIR/00-spec.md.prompt")"
check "기본 — 4개 이상 TOO-LARGE" 1 "$(grep -c 'GATE: TOO-LARGE   (4개 이상' "$T_PROMPTDIR/00-spec.md.prompt")"
reset; rm -rf "$T_PROMPTDIR"; mkdir -p "$T_PROMPTDIR"; rc=$(runit CODE_LOOP_CRITERIA_CAP=5 T_GATE=TOO-LARGE)
check "캡 5 — 6개 이상 TOO-LARGE" 1 "$(grep -c 'GATE: TOO-LARGE   (6개 이상' "$T_PROMPTDIR/00-spec.md.prompt")"
check "캡 5 — 게이트 종료 2" 2 "$rc"
check "캡 5 — 안내 문구" 1 "$(grep -c '성공 기준 6개 이상 — 이 커맨드로 받지 않는다. (상한 CODE_LOOP_CRITERIA_CAP=5)' "$TMP/out.txt")"
reset; rm -rf "$T_PROMPTDIR"; mkdir -p "$T_PROMPTDIR"; rc=$(runit CODE_LOOP_CRITERIA_CAP=0 T_REV=CLEAN T_ADV=UPHELD)
check "캡 0 — 상한 없음 문구" 1 "$(grep -c '성공 기준 상한 없음' "$T_PROMPTDIR/00-spec.md.prompt")"
check "캡 0 — TOO-LARGE 판정 줄 지시 없음" 0 "$(grep -c 'GATE: TOO-LARGE' "$T_PROMPTDIR/00-spec.md.prompt")"
check "캡 0 — 완주" 0 "$rc"
unset T_PROMPTDIR

echo "== AS. 이슈 문서 상태 전이 — spec 전에 pending→progress, 어떤 종료든 로그·동기화. 이력 행은 안 쓴다 (2026-10-12) =="
# 전이 규칙 자체는 tests/code-loop-issue-test.sh 가 본다. 여기서는 러너 배선(시작 시점·EXIT trap·resume)만 본다
IREPO="$TMP/issrepo"; ISSD="$IREPO/docs/wbs/issue"
issue_reset() {
  rm -rf "$IREPO"; mkdir -p "$ISSD/pending" "$ISSD/progress" "$ISSD/resolved" "$IREPO/docs/wbs/issue/request"
  printf -- '---\n이슈: ISS-9001\n상태: pending\n착수일: 없음\n---\n\n## 6. 이력\n\n| 날짜 | 상태 | 누가 | 무엇을 |\n|---|---|---|---|\n| 2026-10-01 | pending | t | 등재 |\n' \
    > "$ISSD/pending/2026-10-01-ISS-9001-x.md"
  git -C "$IREPO" init -q; git -C "$IREPO" add -A; git -C "$IREPO" -c user.email=t@t -c user.name=t commit -qm init
}
issue_run() { env CODE_LOOP_BASE_ROOT="$IREPO" CODE_LOOP_ISSUE_SYNC_CMD="echo sync >> $TMP/isync.log; echo" "$@" \
  timeout "$RUN_TIMEOUT" bash "$SUT" "ISS-9001 R1 — 드라이런 이슈 요청" > "$TMP/out.txt" 2>&1; echo $?; }
idoc() { ls "$ISSD"/*/*-ISS-9001-*.md; }
issue_reset; reset; rm -f "$TMP/isync.log"; rc=$(issue_run T_REV=CLEAN T_ADV=UPHELD)
check "이슈 완료 — 완주" 0 "$rc"
check "이슈 완료 — progress 로 이동" progress "$(basename "$(dirname "$(idoc)")")"
check "이슈 완료 — 착수 전이가 spec 보다 먼저" 1 "$(awk '/\[issue\] ISS-9001 pending → progress/{i=NR} /\[spec\] model=/{if(!s)s=NR} END{print (i&&s&&i<s)?1:0}' "$TMP/out.txt")"
check "이슈 완료 — 이력 행 안 씀" 0 "$(grep -c 'code-loop' "$(idoc)")"
check "이슈 완료 — 종료 로그에 판정" 1 "$(grep -c '\[issue\] .* 종료 — 완료 (dev=CLEAN.* adv=UPHELD.*) — 정착 대기' "$TMP/out.txt")"
check "이슈 완료 — 시트 동기화 2회" 2 "$(grep -c sync "$TMP/isync.log")"
issue_reset; reset; rc=$(issue_run T_GATE=TOO-LARGE)
check "이슈 게이트 반려 — 종료 로그가 사유를 단다" 1 "$(grep -c '종료 — 크기 게이트 초과' "$TMP/out.txt")"
issue_reset; reset; rc=$(issue_run T_REV=CLEAN T_ADV=UPHELD)
RUN=$(basename "$(d)"); rm -f "$ST/$RUN/RESULT.md"
env CODE_LOOP_BASE_ROOT="$IREPO" CODE_LOOP_ISSUE_SYNC_CMD=true T_REV=CLEAN T_ADV=UPHELD timeout "$RUN_TIMEOUT" bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "이슈 resume — 착수 전이는 1회(출력은 run.log 누적)" 1 "$(grep -c 'pending → progress' "$TMP/out.txt")"
check "이슈 resume — 종료 로그는 회차마다" 2 "$(grep -c '\[issue\] .* 종료 — ' "$TMP/out.txt")"
check "이슈 resume — 문서에 이력 행 없음" 0 "$(grep -c 'code-loop' "$(idoc)")"
# runit 시나리오 전부(이슈 무관 요청)의 누적 출력 — issue_run 은 all-out 에 붙이지 않는다
check "이슈 무관 요청 — 전이 시도 0" 0 "$(grep -c '\[issue\]' "$TMP/all-out.txt")"

echo "== AT. 셸 회귀 게이트 — REGRESSION 줄을 리뷰 CLEAN 뒤·adv 앞에 셸이 1회 · red 면 dev 재진입 · flaky 1회 재시도 (2026-10-12) =="
WT_REG="$TMP/wt-reg"; mkdir -p "$WT_REG/vendor/bin"
printf '<?php\n$a = 1;\n' > "$WT_REG/a.php"
git -C "$WT_REG" init -q; git -C "$WT_REG" add a.php
git -C "$WT_REG" -c user.email=t@t -c user.name=t commit -qm init
# 호출마다 REG_SEQ 의 다음 값(red·green, 소진 후 마지막 값)을 낸다
cat > "$WT_REG/vendor/bin/phpunit" <<'PU'
#!/usr/bin/env bash
f="$(dirname "$0")/../../reg.calls"; echo "$*" >> "$f"; k=$(wc -l < "$f")
v=$(printf '%s' "${REG_SEQ:-green}" | cut -d, -f"$k"); [ -n "$v" ] || v=$(printf '%s' "${REG_SEQ:-green}" | rev | cut -d, -f1 | rev)
if [ "$v" = red ]; then printf 'FAILURES!\n1) FooTest::testBar\nTests: 5, Assertions: 9, Failures: 1.\n'; exit 1; fi
echo 'OK (5 tests, 9 assertions)'
PU
chmod +x "$WT_REG/vendor/bin/phpunit"
REG_NOTE='REGRESSION: vendor/bin/phpunit tests/unit'
regc() { wc -l < "$WT_REG/reg.calls" 2>/dev/null | tr -d ' ' || echo 0; }
rm -f "$WT_REG/reg.calls"; reset; rc=$(runit T_WT="$WT_REG" T_SPECNOTE="$REG_NOTE" REG_SEQ=green T_REV=CLEAN T_ADV=UPHELD)
check "GREEN — 완주" 0 "$rc"
check "GREEN — 1회 실행" 1 "$(regc)"
check "GREEN — reg-01.md 판정" 1 "$(grep -c '^REGRESSION_RESULT: GREEN' "$(d)/reg-01.md" 2>/dev/null)"
check "GREEN — 회귀가 adv 보다 먼저" 1 "$(awk '/\[reg-01\] 셸 회귀 GREEN/{r=NR} /\[adv-01\] model=/{if(!a)a=NR} END{print (r&&a&&r<a)?1:0}' "$TMP/out.txt")"
check "GREEN — 잠금 해제" 0 "$([ -d "$ST/.regression.lock" ] && echo 1 || echo 0)"
rm -f "$WT_REG/reg.calls"; reset; export T_PROMPTDIR="$TMP/prompts"; rm -rf "$T_PROMPTDIR"; mkdir -p "$T_PROMPTDIR"
rc=$(runit T_WT="$WT_REG" T_SPECNOTE="$REG_NOTE" REG_SEQ=red,red,green T_REV=CLEAN T_ADV=UPHELD)
check "RED — 완주" 0 "$rc"
check "RED — dev 재진입(2라운드)" 2 "$(cnt 'dev-*.md')"
check "RED — 재진입 dev 가 reg-01.md 를 본다" 1 "$([ "$(grep -c 'reg-01.md' "$T_PROMPTDIR/dev-02.md.prompt" 2>/dev/null)" -ge 1 ] && echo 1 || echo 0)"
check "RED — 실패 목록이 reg-01.md 에" 1 "$([ "$(grep -c 'FooTest::testBar' "$(d)/reg-01.md")" -ge 1 ] && echo 1 || echo 0)"
check "RED — 재실행 포함 3회" 3 "$(regc)"
check "RED — adv 1회" 1 "$(cnt 'adv-*.md')"
check "spec 프롬프트 — REGRESSION 줄 안내" 1 "$([ "$(grep -c 'REGRESSION: {vendor/bin/phpunit' "$T_PROMPTDIR/00-spec.md.prompt")" -ge 1 ] && echo 1 || echo 0)"
check "spec 프롬프트 — 삭제는 빈 치환" 1 "$(grep -c '삭제는 `==>` 뒤를 비운다' "$T_PROMPTDIR/00-spec.md.prompt")"
unset T_PROMPTDIR
RUN=$(basename "$(d)"); rm -f "$ST/$RUN/RESULT.md"
env T_WT="$WT_REG" T_SPECNOTE="$REG_NOTE" REG_SEQ=green T_REV=CLEAN T_ADV=UPHELD timeout "$RUN_TIMEOUT" bash "$SUT" --resume "$RUN" > "$TMP/out.txt" 2>&1
check "RED resume — 기록된 판정 재사용(재실행 0)" 3 "$(regc)"
check "RED resume — 라운드 그대로" 2 "$(cnt 'dev-*.md')"
rm -f "$WT_REG/reg.calls"; reset; rc=$(runit T_WT="$WT_REG" T_SPECNOTE="$REG_NOTE" REG_SEQ=red,green T_REV=CLEAN T_ADV=UPHELD)
check "flaky — 1라운드로 통과" 1 "$(cnt 'dev-*.md')"
check "flaky — 기록" 1 "$(grep -c 'flaky' "$(d)/reg-01.md")"
rm -f "$WT_REG/reg.calls"; reset; rc=$(runit CODE_LOOP_DEV_CAP=1 T_WT="$WT_REG" T_SPECNOTE="$REG_NOTE" REG_SEQ=red T_REV=CLEAN T_ADV=UPHELD)
check "캡 소진 RED — adv 없음" 0 "$(cnt 'adv-*.md')"
check "캡 소진 RED — [미수렴]" 1 "$(head -1 "$(d)/RESULT.md" | grep -c '^> \[미수렴\] dev=FINDINGS (셸 회귀 red')"
rm -f "$WT_REG/reg.calls"; reset; rc=$(runit T_WT="$WT_REG" T_SPECNOTE='MUTATIONS: 1\nMUTATION: a.php | $a = 1; ==> (삭제) | vendor/bin/phpunit tests/unit' T_REV=CLEAN T_ADV=UPHELD)
check "변이 설명문 — 해석 불가로 재보고" 1 "$([ "$(grep -c "변이 조각 '(삭제)' 는 설명문이다" "$TMP/out.txt")" -ge 1 ] && echo 1 || echo 0)"
check "REGRESSION 줄 없음 — 게이트 안 돈다" 0 "$(grep -c '\[reg-' "$TMP/out.txt")"

echo "== AU. haiku 는 effort 미지정이면 high — 명시 effort 는 그대로 (2026-10-12) =="
ML="$TMP/models.log"
tier_of() { grep "^$1|" "$ML" | tail -1 | cut -d'|' -f2,3; }
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" CODE_LOOP_MODEL_DEV=haiku CODE_LOOP_MODEL_REV=claude-haiku-5-5 CODE_LOOP_MODEL_SUM=haiku T_REV=CLEAN T_ADV=UPHELD)
check "haiku dev — high" "haiku|high" "$(tier_of dev-01.md)"
check "haiku 전체 ID rev — high" "claude-haiku-5-5|high" "$(tier_of rev-01-correctness.md)"
check "haiku sum — high" "haiku|high" "$(tier_of RESULT.md)"
check "haiku 아닌 spec — 그대로" "opus|medium" "$(tier_of 00-spec.md)"
reset; : > "$ML"; rc=$(runit T_MODELLOG="$ML" CODE_LOOP_MODEL_DEV=haiku CODE_LOOP_EFFORT_DEV=low CODE_LOOP_MODEL_SUM=haiku:medium T_REV=CLEAN T_ADV=UPHELD)
check "명시 effort — dev low 유지" "haiku|low" "$(tier_of dev-01.md)"
check "명시 effort — sum medium 유지" "haiku|medium" "$(tier_of RESULT.md)"

# 전 시나리오 누적 출력에서 셸 오류 — 어느 스텝 프롬프트든 따옴표 절단·오타가 나면 여기서 잡힌다
check "전 시나리오 셸 오류 0" 0 "$(grep -cE 'not a valid identifier|command not found|syntax error|unexpected EOF' "$TMP/all-out.txt")"
echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
