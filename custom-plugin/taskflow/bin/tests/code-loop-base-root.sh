#!/usr/bin/env bash
# 요청 상대경로 기준 루트(request_base_root) 단위 테스트 — 러너 전체를 돌리지 않는다.
# 실행: bash ~/.claude/custom-plugin/taskflow/bin/tests/code-loop-base-root.sh
SUT="$(cd "$(dirname "$0")/.." && pwd)/code-loop.sh"
eval "$(sed -n '/^REQUEST_REL_RE=/p;/^request_base_root()/,/^}/p' "$SUT")"
pass=0 fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "   PASS $1"; else fail=$((fail + 1)); echo "   FAIL $1 — 기대 [$2] 실제 [$3]"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# 메인 트리 = .git 디렉토리 + request 폴더 / worktree 흉내 = .git 파일 + request 폴더 / 무관 레포 = request 폴더 없음
mkdir -p "$TMP/works/aaa_other/.git" "$TMP/works/athena/.git" "$TMP/works/athena/docs/wbs/issue/request" \
         "$TMP/works/aa_wt/docs/wbs/issue/request"
: > "$TMP/works/aa_wt/.git"
export CODE_LOOP_WORKS_DIR="$TMP/works"
unset CODE_LOOP_BASE_ROOT
want="$TMP/works/athena"
command -v cygpath >/dev/null 2>&1 && want=$(cygpath -m "$want")

echo "== request_base_root — 요청이 request 폴더를 가리킬 때만 메인 트리 루트를 낸다 =="
check "역슬래시 상대경로 → 메인 트리" "$want" "$(request_base_root 'census = docs\wbs\issue\request\ref\claude_767_census_oct06.md 참조')"
check "슬래시 상대경로 → 메인 트리"   "$want" "$(request_base_root '요청서 docs/wbs/issue/request/claude_req1.txt')"
check "request 경로 언급 없음 → 빈 값" ""      "$(request_base_root 'ISS-1 R1: 가드를 건다 (docs/wbs/issue/progress/x.md)')"
check ".git 파일(worktree)은 기준이 아니다" "$want" "$(request_base_root 'docs/wbs/issue/request/x')"
check "CODE_LOOP_BASE_ROOT 가 우선"   "C:/fixed" "$(CODE_LOOP_BASE_ROOT=C:/fixed request_base_root '아무 요청')"
check "메인 트리가 없으면 빈 값"      ""      "$(CODE_LOOP_WORKS_DIR="$TMP/none" request_base_root 'docs/wbs/issue/request/x')"

echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
