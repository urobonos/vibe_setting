#!/usr/bin/env bash
# code-loop-issue.sh — code-loop 시작·종료 때 이슈 문서 상태 전이 검증
#
# 임시 git 레포에 athena 이슈 디렉토리 모양(pending/progress/resolved)을 만들고
# 시트 동기화는 stub 으로 바꿔 호출 횟수만 센다. 실 시트는 건드리지 않는다.
#
# 사용: bash custom-plugin/taskflow/bin/tests/code-loop-issue-test.sh
set -uo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/code-loop-issue.sh"
[ -f "$SUT" ] || { echo "code-loop-issue.sh 를 못 찾았다: $SUT"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo" ISS="$TMP/repo/docs/wbs/issue" SYNCLOG="$TMP/sync.log"
TODAY=$(date '+%Y-%m-%d')
export CODE_LOOP_ISSUE_SYNC_CMD="echo sync >> $SYNCLOG; echo"

pass=0 fail=0
check() {
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "   PASS $1"
  else fail=$((fail + 1)); echo "   FAIL $1 — 기대 [$2] 실제 [$3]"; fi
}

mkdoc() { # $1 폴더 $2 번호 $3 상태 $4 착수일
  cat > "$ISS/$1/2026-10-01-ISS-$2-sample.md" <<EOF
---
이슈: ISS-$2
제목: 샘플
상태: $3          # pending | progress | resolved
착수일: $4
종결일: 없음
---

# ISS-$2

## 6. 이력

| 날짜 | 상태 | 누가 | 무엇을 |
|---|---|---|---|
| 2026-10-01 | $3 | 재영 | 등재 |

## 7. 참조

- 없음
EOF
}

reset() {
  rm -rf "$REPO" "$TMP/run" "$SYNCLOG"
  mkdir -p "$ISS/pending" "$ISS/progress" "$ISS/resolved" "$TMP/run"
  git -C "$REPO" init -q
  mkdoc pending 9001 pending 없음
  mkdoc progress 9002 progress 2026-10-05
  mkdoc resolved 9003 resolved 2026-10-02
  git -C "$REPO" add -A
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm init
  printf '%s\n' "$REPO" > "$TMP/run/BASE_ROOT"
}
doc() { ls "$ISS"/*/*-ISS-"$1"-*.md 2>/dev/null; }
syncs() { grep -c sync "$SYNCLOG" 2>/dev/null || echo 0; }

echo "== A. pending → 시작하면 progress 로 옮기고 상태·착수일을 같이 바꾼다. 이력 행은 쓰지 않는다(허브 소관) =="
reset
bash "$SUT" start "$TMP/run" "ISS-9001 R1 — 샘플 요청 (ISS-9002 와 무관)" > "$TMP/out.txt" 2>&1
check "폴더 progress" "progress" "$(basename "$(dirname "$(doc 9001)")")"
check "pending 에서 빠짐" 0 "$(ls "$ISS/pending" | grep -c 9001)"
check "git 이 이동으로 안다" 1 "$(git -C "$REPO" status --short | grep -c '^R.*ISS-9001')"
check "frontmatter 상태" "상태: progress          # pending | progress | resolved" "$(grep '^상태:' "$(doc 9001)")"
check "착수일 기입" "착수일: $TODAY" "$(grep '^착수일:' "$(doc 9001)")"
check "이력 행 안 씀" 0 "$(grep -c 'code-loop' "$(doc 9001)")"
check "§7 은 그대로" 1 "$(grep -c '^## 7. 참조' "$(doc 9001)")"
check "ISSUE 기록" "$(doc 9001)" "$(cat "$TMP/run/ISSUE")"
check "시트 동기화 1회" 1 "$(syncs)"
check "첫 ISS 번호만 본다(9002 무변경)" 1 "$(grep -c '^| ' "$(doc 9002)" | awk '{print ($1==2)}')"

echo "== B. 종료 — 결과와 상관없이 progress 유지, 문서는 건드리지 않고 로그·동기화만 =="
bash "$SUT" end "$TMP/run" "미수렴 — dev=FINDINGS C=0 H=0 M=2" > "$TMP/out.txt" 2>&1
check "폴더 그대로 progress" "progress" "$(basename "$(dirname "$(doc 9001)")")"
check "상태 그대로" 1 "$(grep -c '^상태: progress' "$(doc 9001)")"
check "종료 — 문서 무변경" 0 "$(grep -c 'code-loop' "$(doc 9001)")"
check "종료 — 결과는 로그로" 1 "$(grep -c '종료 — 미수렴 — dev=FINDINGS C=0 H=0 M=2' "$TMP/out.txt")"
check "시트 동기화 2회째" 2 "$(syncs)"

echo "== C. 이미 progress — 문서를 전혀 건드리지 않는다(재run 이 메인 트리를 더럽히지 않게) =="
reset
bash "$SUT" start "$TMP/run" "ISS-9002 R2 — 두 번째 run" > /dev/null 2>&1
check "폴더 progress" "progress" "$(basename "$(dirname "$(doc 9002)")")"
check "착수일 보존" "착수일: 2026-10-05" "$(grep '^착수일:' "$(doc 9002)")"
check "메인 트리 무변경" 0 "$(git -C "$REPO" status --short | grep -c .)"
check "동기화 안 함(바뀐 게 없다)" 0 "$(syncs)"
check "ISSUE 기록(종료 동기화용)" "$(doc 9002)" "$(cat "$TMP/run/ISSUE")"

echo "== D. resolved — 전이하지 않고 이력도 안 쓴다 (정착 쪽 소관) =="
reset
bash "$SUT" start "$TMP/run" "ISS-9003 재run" > "$TMP/out.txt" 2>&1
check "폴더 resolved 그대로" "resolved" "$(basename "$(dirname "$(doc 9003)")")"
check "이력 무변경" 1 "$(grep -c '^| 20' "$(doc 9003)")"
check "로그로 알림" 1 "$(grep -c 'resolved' "$TMP/out.txt")"
check "ISSUE 미기록" 0 "$([ -e "$TMP/run/ISSUE" ] && echo 1 || echo 0)"
bash "$SUT" end "$TMP/run" "완료" > /dev/null 2>&1
check "end 도 무동작" 1 "$(grep -c '^| 20' "$(doc 9003)")"
check "동기화 0회" 0 "$(syncs)"

echo "== E. 이슈가 아닌 요청·문서 없음·기준 레포 없음 — 아무것도 안 한다 =="
reset
bash "$SUT" start "$TMP/run" "hello world 만들어줘" > /dev/null 2>&1; rc=$?
check "ISS 없음 rc 0" 0 "$rc"
check "ISS 없음 ISSUE 미기록" 0 "$([ -e "$TMP/run/ISSUE" ] && echo 1 || echo 0)"
bash "$SUT" start "$TMP/run" "ISS-9999 없는 번호" > /dev/null 2>&1; rc=$?
check "문서 없음 rc 0" 0 "$rc"
rm -f "$TMP/run/BASE_ROOT"
bash "$SUT" start "$TMP/run" "ISS-9001 R1" > /dev/null 2>&1; rc=$?
check "BASE_ROOT 없음 rc 0" 0 "$rc"
check "BASE_ROOT 없음 pending 그대로" "pending" "$(basename "$(dirname "$(doc 9001)")")"
check "동기화 0회" 0 "$(syncs)"

echo "== F. 동기화가 실패해도 run 을 막지 않는다 =="
reset
CODE_LOOP_ISSUE_SYNC_CMD="false" bash "$SUT" start "$TMP/run" "ISS-9001 R1" > "$TMP/out.txt" 2>&1; rc=$?
check "rc 0" 0 "$rc"
check "전이는 됨" "progress" "$(basename "$(dirname "$(doc 9001)")")"
check "실패 로그" 1 "$(grep -c '시트 동기화 실패' "$TMP/out.txt")"

echo "===== PASS $pass / FAIL $fail ====="
[ "$fail" -eq 0 ]
