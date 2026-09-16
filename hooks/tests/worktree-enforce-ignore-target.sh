#!/usr/bin/env bash
# worktree-enforce.sh #10(gitignore 면제) 의 판정 기준이 cwd 가 아니라 target 인지 검증.
#
# 2026-09-17 정정 전에는 `git -C "$(pwd)" check-ignore` 였다. cwd 와 target 이 서로 다른
# 레포면 check-ignore 가 "outside repository" 로 조회 자체를 실패해, 실제로는 ignored 인
# 파일이 비면제로 떨어져 차단됐다 (code-loop 결과문서가 worktree cwd 에서 4회 차단).
#
# 핵심 질문 = "면제가 넓어지기만 한 건 아닌가" — 추적 파일은 여전히 차단돼야 한다.
set -uo pipefail

HOOK="${1:-$(cd "$(dirname "$0")/.." && pwd)/worktree-enforce.sh}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() {
  if [ "$2" = "$3" ]; then printf '   PASS %s (exit=%s)\n' "$1" "$3"; pass=$((pass+1))
  else printf '   FAIL %s — 기대 exit=%s 실제 exit=%s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

# 레포 A = target 이 사는 곳. ignored 디렉토리와 추적 파일을 함께 둔다
A="$TMP/repo-a"; mkdir -p "$A/state" "$A/src"
git -C "$A" init -q 2>/dev/null
printf 'state/\n' > "$A/.gitignore"
printf 'x\n' > "$A/src/tracked.txt"
git -C "$A" add .gitignore src/tracked.txt 2>/dev/null
git -C "$A" -c user.email=t@t -c user.name=t commit -qm init 2>/dev/null
printf 'x\n' > "$A/state/ignored.md"

# 레포 B = cwd 로 쓸 다른 레포 (크로스 레포 상황 재현)
B="$TMP/repo-b"; mkdir -p "$B"
git -C "$B" init -q 2>/dev/null
printf 'y\n' > "$B/f.txt"
git -C "$B" add f.txt 2>/dev/null
git -C "$B" -c user.email=t@t -c user.name=t commit -qm init 2>/dev/null

run_hook() { # $1 cwd  $2 target
  printf '{"session_id":"wtig-1","tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" \
  | (cd "$1" && bash "$HOOK") > "$TMP/o.txt" 2>&1
  echo $?
}

echo "== 1. cwd=다른 레포, target=ignored → 면제 (이번 정정의 목적) =="
check "크로스 레포 ignored" 0 "$(run_hook "$B" "$A/state/ignored.md")"

echo "== 2. cwd=같은 레포, target=ignored → 면제 (기존 동작 보존) =="
check "동일 레포 ignored" 0 "$(run_hook "$A" "$A/state/ignored.md")"

echo "== 3. cwd=다른 레포, target=추적 파일 → 차단 (면제가 넓어지지 않았나) =="
check "크로스 레포 추적" 2 "$(run_hook "$B" "$A/src/tracked.txt")"

echo "== 4. cwd=같은 레포, target=추적 파일 → 차단 (기존 동작 보존) =="
check "동일 레포 추적" 2 "$(run_hook "$A" "$A/src/tracked.txt")"

echo "== 5. ignored 디렉토리 밑 신규 파일(아직 없음) → 면제 =="
# dirname 이 존재하므로 최근접 조상 = state/ 자체
check "ignored 신규 파일" 0 "$(run_hook "$B" "$A/state/new-file.md")"

echo "== 6. target 이 git 밖 → 통과 (기존 동작 보존) =="
mkdir -p "$TMP/plain"
check "git 밖" 0 "$(run_hook "$B" "$TMP/plain/x.txt")"

echo
echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
