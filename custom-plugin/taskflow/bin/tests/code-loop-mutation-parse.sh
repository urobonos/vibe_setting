#!/usr/bin/env bash
# MUTATION 줄 분리(mutation_split)·phpunit 명령 검증(is_phpunit_cmd) 단위 테스트 — 러너 전체를 돌리지 않는다.
# 실행: bash ~/.claude/custom-plugin/taskflow/bin/tests/code-loop-mutation-parse.sh
SUT="$(cd "$(dirname "$0")/.." && pwd)/code-loop.sh"
eval "$(sed -n '/^is_phpunit_cmd()/,/^}/p;/^mutation_split()/,/^}/p' "$SUT")"
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

echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
