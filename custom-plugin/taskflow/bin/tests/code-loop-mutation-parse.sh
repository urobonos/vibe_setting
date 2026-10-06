#!/usr/bin/env bash
# MUTATION 줄 분리(mutation_split)·phpunit/pytest 명령 검증·변이 판정 단위 테스트 — 러너 전체를 돌리지 않는다.
# 실행: bash ~/.claude/custom-plugin/taskflow/bin/tests/code-loop-mutation-parse.sh
SUT="$(cd "$(dirname "$0")/.." && pwd)/code-loop.sh"
eval "$(sed -n '/^PHPUNIT_PREFIX_RE=/p;/^PYTEST_PREFIX_RE=/p;/^MUTATION_RED_RE=/p;/^MUTATION_VACUOUS_RE=/p;/^safe_cmd_with_prefix()/,/^}/p;/^is_phpunit_cmd()/,/^}/p;/^is_pytest_cmd()/,/^}/p;/^mutation_runner()/,/^}/p;/^mutation_control_verdict()/,/^}/p;/^mutation_mutant_verdict()/,/^}/p;/^mutation_split()/,/^}/p' "$SUT")"
pass=0 fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "   PASS $1"; else fail=$((fail + 1)); echo "   FAIL $1 — 기대 [$2] 실제 [$3]"; fi; }
ok() { is_phpunit_cmd "$1" && echo 1 || echo 0; }
P=vendor/bin/phpunit

echo "== is_phpunit_cmd — 작은따옴표 안 메타문자 허용, 그 밖은 거부 =="
check "작은따옴표 안 | 통과"            1 "$(ok "$P --filter 'SendBird|ChatView' tests/unit")"
check "작은따옴표 밖 파이프 거부"        0 "$(ok "$P --filter 'A' | rm x")"
check "큰따옴표 안 | 거부"               0 "$(ok "$P --filter \"A|B\"")"
check "큰따옴표 안 \$( 거부"             0 "$(ok "$P --filter \"\$(id)\"")"
check "작은따옴표 안 \$( 는 리터럴 — 통과" 1 "$(ok "$P --filter '\$(id)'")"
check "\\' 는 따옴표가 아님 — 숨은 ; 거부" 0 "$(ok "$P \\' ; rm x ; \\'")"
check "큰따옴표 안 ' 는 리터럴 — 숨은 ; 거부" 0 "$(ok "$P \"'\" ; rm x ; \"'\"")"
check "닫히지 않은 작은따옴표 거부"      0 "$(ok "$P --filter 'A|B")"
check "생략 표기는 따옴표 안이어도 거부" 0 "$(ok "$P --filter '...'")"
check "php 접두 명령 통과"               1 "$(ok "php $P --filter 'A|B'")"
check "phpunit 아닌 명령 거부"           0 "$(ok "ls 'A|B'")"
check "기존 단순 명령 통과"              1 "$(ok "$P tests/unit/FooTest.php")"

echo "== mutation_split — 명령은 첫 '| phpunit 접두' 부터 =="
mutation_split "app/A.php | return \$a; ==> return \$b; | $P --filter 'SendBird|ChatView' tests/unit"
check "필터 안 | — cmd 보존" "$P --filter 'SendBird|ChatView' tests/unit" "$cmd"
check "필터 안 | — file"     "app/A.php"   "$file"
check "필터 안 | — from"     'return $a;'  "$from"
check "필터 안 | — to"       'return $b;'  "$to"
mutation_split "app/B.php | \$x || \$y ==> \$x && \$y | php $P --filter Foo"
check "조각 안 || — from"   '$x || $y'                 "$from"
check "조각 안 || — to"     '$x && $y'                 "$to"
check "조각 안 || — cmd"    "php $P --filter Foo"      "$cmd"
mutation_split "app/C.php | a ==> b | $P"
check "옵션 없는 명령"      "$P"   "$cmd"
check "옵션 없는 명령 from" "a"    "$from"
mutation_split "app/D.php | a ==> b | ls -la"
check "phpunit 접두 없음 — cmd 비움" "" "$cmd"

echo "== pytest — 변이 경로에서만 'python … -m pytest' 접두를 받는다 =="
okpy() { is_pytest_cmd "$1" && echo 1 || echo 0; }
check "python -m pytest 통과"                1 "$(okpy "python -m pytest tools/regression/tests/test_x.py -q")"
check "python3 -I -m pytest 통과"            1 "$(okpy "python3 -I -m pytest tests -k 'a or b'")"
check "경로 붙은 python.exe 통과"            1 "$(okpy "C:/Python313/python.exe -m pytest tests")"
check "pytest 단독 실행 거부(접두 고정)"     0 "$(okpy "pytest tests")"
check "따옴표 밖 ; 거부"                     0 "$(okpy "python -m pytest tests ; rm x")"
check "생략 표기 거부"                       0 "$(okpy "python -m pytest -k '...'")"
check "phpunit 명령은 pytest 아님"           0 "$(okpy "$P tests")"
check "runner phpunit"                       phpunit "$(mutation_runner "$P tests")"
check "runner pytest"                        pytest  "$(mutation_runner "python -m pytest tests")"
check "runner 그 밖 = 빈 값"                 ""      "$(mutation_runner "ls -la")"
mutation_split "tools/a.py | return x ==> return y | python -m pytest tools/regression/tests -k 'a|b'"
check "pytest 분리 — cmd"  "python -m pytest tools/regression/tests -k 'a|b'" "$cmd"
check "pytest 분리 — file" "tools/a.py" "$file"
check "pytest 분리 — to"   "return y"   "$to"

echo "== 판정 — pytest: red = rc 1 + 'N failed' · rc 2 수집 오류 = 무효 · rc 5 = vacuous =="
check "대조군 rc0 passed → ok"          ok      "$(mutation_control_verdict pytest 0 '3 passed in 0.1s')"
check "대조군 rc5 → vacuous"            vacuous "$(mutation_control_verdict pytest 5 'no tests ran in 0.01s')"
check "대조군 skip 만 → vacuous"        vacuous "$(mutation_control_verdict pytest 0 '2 skipped in 0.1s')"
check "대조군 rc1 → red(무효)"          red     "$(mutation_control_verdict pytest 1 '1 failed, 2 passed')"
check "대조군 rc2 수집 오류 → red(무효)" red    "$(mutation_control_verdict pytest 2 '1 error in 0.2s')"
check "변이 rc1 failed → red"           red     "$(mutation_mutant_verdict pytest 1 '1 failed, 2 passed in 0.1s')"
check "변이 rc2 수집 오류 → crash"       crash  "$(mutation_mutant_verdict pytest 2 'ERROR collecting tests/test_x.py')"
check "변이 rc5 → crash"                crash   "$(mutation_mutant_verdict pytest 5 'no tests ran')"
check "변이 rc0 → green"                green   "$(mutation_mutant_verdict pytest 0 '3 passed')"
check "phpunit 변이 FAILURES → red(불변)" red   "$(mutation_mutant_verdict phpunit 1 'FAILURES! Tests: 3, Assertions: 4, Failures: 1.')"
check "phpunit 변이 Fatal → crash(불변)"  crash "$(mutation_mutant_verdict phpunit 255 'PHP Parse error')"
check "phpunit 대조군 Assertions 0 → vacuous(불변)" vacuous "$(mutation_control_verdict phpunit 0 'OK, but incomplete. Tests: 1, Assertions: 0')"

echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
