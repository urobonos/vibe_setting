#!/usr/bin/env bash
# gate-enforce.sh plan-before 게이트의 code-loop 인정 경로 검증.
# 핵심 질문 = "환경변수만 세우면 열리는가" — 열리면 그건 우회 통로다.
set -uo pipefail

HOOK="${1:-$(cd "$(dirname "$0")/../.." && pwd)/hooks/gate-enforce.sh}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
CODE="$TMP/target.py"; : > "$CODE"

pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then printf '   PASS %s (exit=%s)\n' "$1" "$3"; pass=$((pass+1))
  else printf '   FAIL %s — 기대 exit=%s 실제 exit=%s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

# HOME 은 바꾸지 않는다 — 바꾸면 hook 이 lib/ 를 못 찾아 is_hard_code_file 이 미정의가
# 되고 plan-before 블록 전체를 건너뛴다(= 차단 조건이 재현 안 됨, 첫 시도에서 확인).
# 대신 실제 REGISTRY 에 없을 SID 를 써서 매칭 실패를 만든다.
run_hook() { # $1 sid
  # gate 파일이 없으면 hook 이 맨 앞에서 exit 0 한다 — 그러면 검사 자체가 안 돌아
  # 모든 케이스가 "통과" 로 보인다 (첫 시도에서 이것 때문에 4건이 거짓 통과했다)
  : > "/tmp/claude_gate_$1"
  printf '{"session_id":"%s","tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s"}}' \
    "$1" "$TMP" "$CODE" \
  | bash "$HOOK" > "$TMP/o.txt" 2>&1
  local rc=$?
  rm -f "/tmp/claude_gate_$1" "/tmp/claude_code_touched_$1"
  echo $rc
}

mkspec() { printf '## 성공 기준\n\n1. 뭔가\n\nGATE: %s\n' "$1" > "$TMP/00-spec.md"; }
# 판정 줄을 원문 그대로 쓴다 — 표기 변형 검사용
mkraw()  { printf '## 성공 기준\n\n1. 뭔가\n\n%s\n' "$1" > "$TMP/00-spec.md"; }

echo "== 1. CODE_LOOP_SPEC 없음 → 차단 (기존 동작 보존) =="
unset CODE_LOOP_SPEC
check "미설정" 2 "$(run_hook aaaaaaaa-1)"

echo "== 2. GATE: OK 인 spec → 통과 =="
mkspec OK
export CODE_LOOP_SPEC="$TMP/00-spec.md"
check "spec 인정" 0 "$(run_hook aaaaaaaa-2)"

echo "== 3. 변수만 있고 파일 없음 → 차단 (변수는 통과 사유가 아니다) =="
export CODE_LOOP_SPEC="$TMP/does-not-exist.md"
check "파일 부재" 2 "$(run_hook aaaaaaaa-3)"

echo "== 4. GATE: TOO-LARGE → 차단 (크기 게이트 탈락은 계획이 선 게 아니다) =="
mkspec TOO-LARGE
export CODE_LOOP_SPEC="$TMP/00-spec.md"
check "TOO-LARGE" 2 "$(run_hook aaaaaaaa-4)"

echo "== 5. GATE 줄 자체가 없는 파일 → 차단 (아무 파일이나 가리키면 안 된다) =="
printf '아무 내용\n' > "$TMP/00-spec.md"
check "GATE 줄 부재" 2 "$(run_hook aaaaaaaa-5)"

echo "== 6~9. 판정 줄 표기 — spec 스텝(모델)이 마크다운으로 쓰는 경우 =="
# 2026-09-17 실측: 전 run spec 25건 중 2건이 `## GATE: OK` 였고, 그중 하나는 개발자가
# 5라운드 내내 이 게이트에 막혀 코드 0줄로 끝났다. 판정 SSOT = lib/code-loop-gate.sh
export CODE_LOOP_SPEC="$TMP/00-spec.md"
mkraw '## GATE: OK'
check "## GATE: OK 인정" 0 "$(run_hook aaaaaaaa-6)"
mkraw '**GATE: OK**'
check "**GATE: OK** 인정" 0 "$(run_hook aaaaaaaa-7)"
mkraw '## GATE: TOO-LARGE'
check "## GATE: TOO-LARGE 차단" 2 "$(run_hook aaaaaaaa-8)"
mkraw '- 이전엔 GATE: OK 였다'
check "본문 중간 언급은 판정 아님" 2 "$(run_hook aaaaaaaa-9)"

echo
echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
