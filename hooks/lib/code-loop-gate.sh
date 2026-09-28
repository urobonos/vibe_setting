#!/usr/bin/env bash
# code-loop 00-spec.md 의 크기 게이트 판정 줄을 읽는다 — 판정 SSOT (2026-09-17)
#
# 쓰는 곳 두 군데가 같은 답을 내야 한다:
#   hooks/gate-enforce.sh  plan-before 게이트 — OK 일 때만 code-loop 개발자 편집 허용
#   custom-plugin/taskflow/bin/code-loop.sh       크기 게이트 분기 — OK 진행 / TOO-LARGE 정지 / 없음 중단
# 둘이 각자 패턴을 들고 있다가 갈라졌다. hook 은 줄 맨 앞 `GATE:` 만 읽어서 spec 이
# `## GATE: OK` 로 쓰면 개발자가 5라운드 내내 코드를 못 썼고(iss-910 후속 run),
# 러너는 `GATE: TOO-LARGE` 로 시작하는 줄만 봐서 헤더형 TOO-LARGE 와 GATE 줄 없음을
# 전부 "진행" 으로 읽었다. hook 만 넓히면 과대 요청이 게이트를 통과한다 — 그래서 한 곳에서 읽는다.
#
# 인정하는 표기: 줄 전체가 GATE 줄일 때만. 앞의 공백·`#`·`>`·`*`, 값 뒤의 공백·`*` 는 허용.
#   GATE: OK · ## GATE: OK · **GATE: OK** · > GATE: TOO-LARGE
# 인정하지 않는 표기: 본문 중간의 언급 (`- 이전엔 GATE: OK 였다`) — 줄이 GATE 로 시작하지 않는다.
# 여러 줄이면 마지막 줄을 쓴다 (spec 계약상 판정 줄은 마지막 줄이다).

# $1 = spec 파일 → stdout: OK | TOO-LARGE | (빈 문자열 = 판정 줄 없음 또는 파일 없음)
code_loop_gate() {
  [ -f "${1:-}" ] || return 0
  sed -nE 's/^[[:space:]#>*]*GATE:[[:space:]*]*(OK|TOO-LARGE)[[:space:]*]*$/\1/p' "$1" 2>/dev/null | tail -1
}
