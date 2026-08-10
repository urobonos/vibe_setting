#!/bin/bash
# run-guard-tests.sh — hooks 가드 회귀 매트릭스 (2026-08-03 신설)
#
# 실행:  bash ~/.claude/hooks/tests/run-guard-tests.sh
#        bash ~/.claude/hooks/tests/run-guard-tests.sh -v     # 실패 상세
#
# 무엇을 지키는가:
#   A. git 명령 백스톱이 **python 이 죽은 상태(degraded)에서도** git-guard.py 와 같은 판정을 내는가.
#      - degraded 판정이 python 판정보다 느슨하면(FN) 가드가 뚫린다.
#      - degraded 판정이 python 판정보다 조이면(FP) 정상 작업이 멈춘다. 둘 다 실패로 센다.
#   B. 공유문서 게이트가 Write 전문만 검사하고 Edit/MultiEdit·역소급 문서를 오차단하지 않는가.
#   C. 커밋 게이트가 한글 제목 길이를 문자 단위로 세는가 (바이트로 세면 정상 커밋이 막힌다).
#
# Why 이 파일이 필요한가: 2026-08-03 리뷰에서 "32/32 통과" 라고 보고한 매트릭스가
#   `git checkout "main"` · `VAR=1 git merge main` · `git checkout -- main` 류를 담고 있지 않아
#   FN 6건 + FP 2건을 놓쳤다. 손으로 만든 임시 매트릭스는 다음 사람에게 남지 않는다.

set -u
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD_PY="$HOOKS_DIR/lib/git-guard.py"
TMP="${TMPDIR:-/tmp}/claude_guardtests_$$"
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

mkdir -p "$TMP/shim" "$TMP/repo_master" "$TMP/repo_feature"
# 임시 트리 전체 회수 (테스트 저장소 2개 포함). `rm -r` 계열은 dangerous-ops-guard 차단 대상이라
# find -delete + rmdir 로 지운다 — 이 스크립트를 Claude 가 실행해도 가드에 걸리지 않는다.
cleanup() {
  [ -n "${TMP:-}" ] || return 0
  case "$TMP" in */claude_guardtests_*) ;; *) return 0 ;; esac   # 경로 오인 삭제 방지
  find "$TMP" -type f -delete 2>/dev/null
  find "$TMP" -depth -type d -exec rmdir {} + 2>/dev/null
  rm "/tmp/claude_gate_guardtests$$" "/tmp/claude_gate_guardtests0$$" 2>/dev/null  # §H gate 파일 (중단 시 잔류 방지)
}
trap 'cleanup' EXIT

PASS=0; FAIL=0; SKIP=0
fail_lines=()
# skip_lines (2026-08-10 M4) — SKIP 은 라벨도 메시지도 없이 카운터 한 칸만 올려서, 환경 한계 SKIP 과
# 데이터 부재 SKIP 이 같은 숫자에 섞였다. 실 landmark 데이터가 사라지는 순간의 신호가 `SKIP=2 → 3`
# 뿐이라 "무엇이 검증되지 않았는가" 를 아무도 못 읽는다. fail_lines 와 같은 방식으로 수집·출력한다.
skip_lines=()

# ── python 실행 실패 shim (Windows Store 별칭 재현: command -v 통과 / 실행 exit 9) ──
printf '#!/bin/sh\nexit 9\n' > "$TMP/shim/python3"
printf '#!/bin/sh\nexit 9\n' > "$TMP/shim/python"
printf '#!/bin/sh\nexit 9\n' > "$TMP/shim/py"
chmod +x "$TMP/shim/python3" "$TMP/shim/python" "$TMP/shim/py"

PY=""
for c in python3 python py; do command -v "$c" >/dev/null 2>&1 && "$c" -c pass >/dev/null 2>&1 && { PY="$c"; break; }; done

# ── 테스트용 git 저장소 2개 (HEAD=master / HEAD=feature/x) ──
init_repo() {
  local dir="$1" branch="$2" t c
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || git -C "$dir" init -q . 2>/dev/null
  git -C "$dir" symbolic-ref HEAD "refs/heads/$branch"
  t=$(git -C "$dir" hash-object -w -t tree /dev/null 2>/dev/null)
  c=$(git -C "$dir" -c user.email=t@t -c user.name=t commit-tree "$t" -m init 2>/dev/null)
  [ -n "$c" ] && git -C "$dir" update-ref "refs/heads/$branch" "$c"
}
init_repo "$TMP/repo_master" master
init_repo "$TMP/repo_feature" feature/x

# ── payload 생성 (python 없이도 동작하도록 bash 로 JSON escape) ──
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}
bash_payload() {  # $1=command  $2=cwd
  printf '{"session_id":"guardtests","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' \
    "$(json_escape "$2")" "$(json_escape "$1")" > "$TMP/p.json"
}
doc_payload() {   # $1=tool_name $2=file_path $3=body
  case "$1" in
    Write) printf '{"session_id":"guardtests","cwd":"C:/Users/PV/.claude","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' \
             "$(json_escape "$2")" "$(json_escape "$3")" > "$TMP/p.json" ;;
    Edit)  printf '{"session_id":"guardtests","cwd":"C:/Users/PV/.claude","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"%s"}}' \
             "$(json_escape "$2")" "$(json_escape "$3")" > "$TMP/p.json" ;;
    MultiEdit) printf '{"session_id":"guardtests","cwd":"C:/Users/PV/.claude","tool_name":"MultiEdit","tool_input":{"file_path":"%s","edits":[{"old_string":"a","new_string":"x"},{"old_string":"b","new_string":"%s"}]}}' \
             "$(json_escape "$2")" "$(json_escape "$3")" > "$TMP/p.json" ;;
  esac
}
run_hook() {      # $1=hook $2=mode(normal|degraded) $3=cwd → 종료코드 반환, 출력은 $LAST_OUT
  local hook="$1" mode="$2" cwd="$3" rc
  if [ "$mode" = degraded ]; then
    LAST_OUT=$(cd "$cwd" && PATH="$TMP/shim:$PATH" bash "$HOOKS_DIR/$hook" < "$TMP/p.json" 2>&1); rc=$?
  else
    LAST_OUT=$(cd "$cwd" && bash "$HOOKS_DIR/$hook" < "$TMP/p.json" 2>&1); rc=$?
  fi
  return $rc
}
check() {         # $1=라벨 $2=기대 $3=실제
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); fail_lines+=("$1 — 기대 exit=$2 실제 exit=$3")
    [ $VERBOSE -eq 1 ] && printf '    %s\n' "$(printf '%s' "${LAST_OUT:-}" | head -2)"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# A. branch-enforce 백스톱 ↔ git-guard.py 판정 일치
#    각 케이스: 명령 / HEAD 분기 / 기대 exit. 기대값은 git-guard.py 의 정의를 따른다.
# ═══════════════════════════════════════════════════════════════════
# 형식: "exit|repo|명령"   repo = m(master) | f(feature/x)
CASES=(
  # ── §1.5 master/main 머지·체크아웃·switch = 차단 ──
  "2|f|git merge main"
  "2|f|git merge master"
  "2|f|git merge origin/main"
  "2|f|git merge upstream/master"
  "2|f|git merge refs/heads/main"
  "2|f|git merge --no-ff main"
  "2|f|git checkout main"
  "2|f|git switch master"
  "2|f|git switch -- master"
  "2|f|git checkout main -- app/file.php"
  "2|f|cd /tmp && git checkout main && git merge feature/x"
  "2|f|git -C /tmp/x checkout main"
  "2|f|git --git-dir=/tmp/x/.git merge main"
  # F4 ①~⑥ (리뷰 실측 FN)
  "2|f|git checkout \"main\""
  "2|f|git checkout 'main'"
  "2|f|git -c core.editor=true merge main"
  "2|f|VAR=1 git merge main"
  "2|f|nice git merge main"
  "2|f|if true; then git merge main; fi"
  "2|f|sudo git merge main"
  "2|f|timeout 5 git merge main"
  "2|f|xargs git merge main"
  "2|f|env GIT_TRACE=1 git merge main"
  # ── §1 push 전면 금지 ──
  "2|f|git push"
  "2|f|git push origin feature/x"
  "2|f|git push --force-with-lease"
  "2|f|VAR=1 git push"
  "2|f|nice git push origin main"
  "2|f|cd /tmp && git push"
  # ── §1.6 cherry-pick (HEAD=master 에서만 차단) ──
  "2|m|git cherry-pick abc1234"
  "2|m|git cherry-pick abc1234 def5678"
  "2|m|git cherry-pick abc && git cherry-pick --abort"
  "0|m|git cherry-pick --abort"
  "0|m|git cherry-pick --quit"
  "0|f|git cherry-pick abc1234"
  # ── 통과해야 하는 것 (오탐 검사) ──
  "0|f|git status --porcelain"
  "0|f|git merge feature/login --no-ff"
  "0|f|git merge mainline"
  "0|f|git checkout -b feature/main-fix"
  "0|f|git checkout -- main"
  "0|f|git log --oneline main..HEAD"
  "0|f|git diff main"
  "0|f|git branch --set-upstream-to=origin/main"
  "0|f|git fetch origin main"
  "0|f|echo \"git merge main\""
  "0|f|echo \"git push\""
  "0|f|grep -rn 'git checkout main' docs/"
  "0|f|git commit -m \"docs: merge main 절차 문서화\""
  "0|f|git rebase feature/x"
  "0|f|git worktree add /tmp/w -b wip/x"
  "0|f|git stash list"
  # ── F-B: 괄호도 절 경계다 (git-guard.py:48 _OPS 에 '(' ')' 포함) ──
  "2|f|( git merge main )"
  "2|f|(git merge main)"
  "2|f|if true; then ( git push ); fi"
  "2|f|echo \$(git push)"
  "2|m|( git cherry-pick abc )"
  # ── F-C: heredoc **뒤에 오는 절**도 검사 대상 ──
  "2|f|cat <<EOF > /tmp/f
hello
EOF
git push origin feature/x"
  "2|f|cat <<'EOF' > /tmp/f
policy text
EOF
git merge main"
  # heredoc 도입부 줄 자체는 검사 대상 (본문만 건너뛴다)
  "2|f|git merge main <<EOF
body
EOF"
)

printf '=== A. branch-enforce 백스톱 ↔ git-guard.py (%d 케이스 × normal/degraded) ===\n' "${#CASES[@]}"
for row in "${CASES[@]}"; do
  want="${row%%|*}"; rest="${row#*|}"; repo="${rest%%|*}"; cmd="${rest#*|}"
  [ "$repo" = m ] && cwd="$TMP/repo_master" || cwd="$TMP/repo_feature"
  bash_payload "$cmd" "$cwd"
  run_hook branch-enforce.sh normal "$cwd"; got_n=$?
  check "[normal  ] $cmd" "$want" "$got_n"
  run_hook branch-enforce.sh degraded "$cwd"; got_d=$?
  check "[degraded] $cmd" "$want" "$got_d"
done

# ═══════════════════════════════════════════════════════════════════
# B. output-report-share-guard — Write 전문만 검사 / 역소급 면제 / Edit·MultiEdit 무간섭
# ═══════════════════════════════════════════════════════════════════
SHARE_DIR="/c/Users/PV/.claude/docs/claude-harness/output/report/2026-08-03-guardtest"
META7=$'> **문서 ID**: T-1\n> **버전**: 1.0\n> **상태**: 초안\n> **작성자**: jypark\n> **작성일**: 2026-08-03\n> **대상 독자**: BE\n> **개발언어/기술스택**: Bash\n'
META6=$'> **문서 ID**: T-1\n> **버전**: 1.0\n> **상태**: 초안\n> **작성자**: jypark\n> **작성일**: 2026-05-13\n> **대상 독자**: BE\n'
META6_NEW=$'> **문서 ID**: T-1\n> **버전**: 1.0\n> **상태**: 초안\n> **작성자**: jypark\n> **작성일**: 2026-08-03\n> **대상 독자**: BE\n'
SEC12=$'\n## 한 줄 요약\nx\n## 왜 필요한가\nx\n## 무엇을 만드는가\nx\n## 어떻게 동작하는가\nx\n## 사용 시나리오\nx\n## 인터페이스\nx\n## 데이터 모델\nx\n## 보안 · 성능 · 비용\nx\n## 일정\nx\n## 결정 · 권고 · 리스크\nx\n## 성공 지표\nx\n## 참조\nx\n'

printf '\n=== B. output-report-share-guard (Write 전문 / Edit 무간섭 / 역소급) ===\n'
for mode in normal degraded; do
  doc_payload Write "$SHARE_DIR/2026-08-03-guardtest-share.md" "${META7}${SEC12}"
  run_hook output-report-share-guard.sh "$mode" "$TMP"; check "[$mode] 완전한 신규 share Write" 0 $?

  doc_payload Write "$SHARE_DIR/2026-08-03-guardtest-share.md" $'# 제목만\n\n## 한 줄 요약\nx\n'
  run_hook output-report-share-guard.sh "$mode" "$TMP"; check "[$mode] 메타 누락 신규 share Write" 2 $?

  # 역소급: 2026-06-01 이전 문서는 '개발언어/기술스택' 면제 (CLAUDE.md §4 역소급 면제)
  doc_payload Write "$SHARE_DIR/2026-05-13-guardtest-share.md" "${META6}${SEC12}"
  run_hook output-report-share-guard.sh "$mode" "$TMP"; check "[$mode] 2026-05-13 문서(개발언어 없음) Write" 0 $?

  doc_payload Write "$SHARE_DIR/2026-08-03-guardtest-share.md" "${META6_NEW}${SEC12}"
  run_hook output-report-share-guard.sh "$mode" "$TMP"; check "[$mode] 2026-08-03 문서(개발언어 없음) Write" 2 $?

  # Edit/MultiEdit = 조각이므로 검사 대상 아님 (전문 기준을 조각에 적용하면 오타 수정도 차단)
  doc_payload Edit "$SHARE_DIR/2026-08-03-guardtest-share.md" "오타 수정"
  run_hook output-report-share-guard.sh "$mode" "$TMP"; check "[$mode] share 문서 오타 Edit" 0 $?

  doc_payload MultiEdit "$SHARE_DIR/2026-08-03-guardtest-share.md" "오타 수정"
  run_hook output-report-share-guard.sh "$mode" "$TMP"; check "[$mode] share 문서 MultiEdit" 0 $?

  # 대상 경로 밖은 무간섭
  doc_payload Write "/c/Users/PV/.claude/docs/claude-harness/output/report/2026-08-03-x/2026-08-03-x-report.md" $'# 일반 문서\n'
  run_hook output-report-share-guard.sh "$mode" "$TMP"; check "[$mode] 비-share 문서 Write" 0 $?
done

# ═══════════════════════════════════════════════════════════════════
# C. git-quality-gate — 형식 위반 차단 / 정상 통과 / 한글 길이(문자 단위)
# ═══════════════════════════════════════════════════════════════════
printf '\n=== C. git-quality-gate (Conventional Commits · 한글 제목 길이) ===\n'
LONG_KO="feat(taskflow): watch G2 사전조사 + status drift 보수 채택 + orphan lock 정리"   # 67자 / 87바이트
OVER_KO="feat(taskflow): 이 제목은 일부러 일흔두 글자를 넘기기 위해 한글을 계속 이어 붙인 아주 긴 제목입니다 정말로 아주 많이 길어요"
GC="git commit"
for mode in normal degraded; do
  bash_payload "$GC -m \"zzz no prefix\"" "$TMP/repo_master"
  run_hook git-quality-gate.sh "$mode" "$TMP/repo_master"; check "[$mode] 규격 위반 커밋" 2 $?

  bash_payload "$GC -m \"feat(hooks): 정상 커밋\"" "$TMP/repo_master"
  run_hook git-quality-gate.sh "$mode" "$TMP/repo_master"; check "[$mode] 정상 커밋" 0 $?

  bash_payload "$GC -m \"$LONG_KO\"" "$TMP/repo_master"
  run_hook git-quality-gate.sh "$mode" "$TMP/repo_master"; check "[$mode] 한글 67자 제목(72자 이내)" 0 $?

  bash_payload "$GC -m \"$OVER_KO\"" "$TMP/repo_master"
  run_hook git-quality-gate.sh "$mode" "$TMP/repo_master"; check "[$mode] 한글 72자 초과 제목" 2 $?

  # heredoc 커밋 (F9: lib 은 개행을 보존한다 — 제목 줄만 형식 검사 대상)
  bash_payload "$GC -F- <<'EOF'
feat(hooks): heredoc 커밋 제목

본문에서 git checkout main 정책을 서술한다.
EOF" "$TMP/repo_master"
  run_hook git-quality-gate.sh "$mode" "$TMP/repo_master"; check "[$mode] heredoc 커밋(본문에 정책 서술)" 0 $?

  bash_payload "git status" "$TMP/repo_master"
  run_hook git-quality-gate.sh "$mode" "$TMP/repo_master"; check "[$mode] 비커밋 명령" 0 $?
done

# ═══════════════════════════════════════════════════════════════════
# D. lib/hook-input.sh — degraded 파싱 정확도
# ═══════════════════════════════════════════════════════════════════
printf '\n=== D. lib/hook-input.sh degraded 파싱 ===\n'
# shellcheck disable=SC1090
source "$HOOKS_DIR/lib/hook-input.sh"
(
  HOOK_PY=""; HOOK_PY_RESOLVED=1
  STDIN_DATA='{"tool_input":{"command":"git commit -m \"feat: 따옴표 \\\"중첩\\\" 포함\""}}'
  hook_parse_command
  case "$COMMAND" in *'따옴표 \"중첩\" 포함'*) exit 0 ;; *) exit 1 ;; esac
) && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); fail_lines+=("[degraded] 이스케이프 따옴표 명령 복원"); }
(
  HOOK_PY=""; HOOK_PY_RESOLVED=1
  STDIN_DATA='{"tool_input":{"edits":[{"new_string":"첫째"},{"new_string":"작성자: Claude Code"}]}}'
  hook_parse_content
  case "$CONTENT" in *"작성자: Claude Code"*) exit 0 ;; *) exit 1 ;; esac
) && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); fail_lines+=("[degraded] MultiEdit edits[*] 전건 수집"); }
(
  HOOK_PY=""; HOOK_PY_RESOLVED=1
  STDIN_DATA='{"tool_input":{"content":"emoji \ud83d\ude00"}}'
  hook_parse_content
  [ "${CONTENT_UNDECODED:-0}" = "1" ]
) && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); fail_lines+=("[degraded] surrogate pair → 판정불가 신고"); }

# ═══════════════════════════════════════════════════════════════════
# E. normal ↔ degraded 의도적 비대칭 (같은 값이 아니어야 정상인 케이스)
#    heredoc **본문** 안 정책 서술: 주 경로(git-guard.py)는 본문도 토큰화해 차단한다(기존 FP,
#    본 작업 범위 밖). 백스톱은 본문을 건너뛰므로 통과한다. 이 비대칭을 고정해 두지 않으면
#    F5② 픽스를 되돌려도 매트릭스가 초록으로 남는다 (2026-08-03 리뷰 지적).
# ═══════════════════════════════════════════════════════════════════
printf '\n=== E. heredoc 본문 비대칭 (normal=2 / degraded=0 이 정상) ===\n'
bash_payload "git commit -F- <<'EOF'
fix(hooks): 가드 정책 문서화

git checkout main 은 §4.3(e) 로 금지된다.
EOF" "$TMP/repo_feature"
run_hook branch-enforce.sh normal   "$TMP/repo_feature"; check "[normal  ] heredoc 본문의 정책 서술(주 경로 FP 잔존)" 2 $?
run_hook branch-enforce.sh degraded "$TMP/repo_feature"; check "[degraded] heredoc 본문의 정책 서술(백스톱 완화)" 0 $?

# ═══════════════════════════════════════════════════════════════════
# F. 절 수 성능 — hook timeout(settings.json: branch-enforce=5초) 안에 끝나야 한다.
#    절마다 fork 하던 구조는 40절 6.7초 / 300절 59초로 kill → 차단 신호 소멸(fail-open)이었다.
# ═══════════════════════════════════════════════════════════════════
printf '\n=== F. 절 수 대비 실행시간 (5초 timeout) ===\n'
for n in 40 300; do
  long=""
  i=0
  while [ $i -lt $n ]; do long="${long}echo c$i | "; i=$((i+1)); done
  for suffix in "git status" "git merge main"; do
    want=0; [ "$suffix" = "git merge main" ] && want=2
    bash_payload "${long}${suffix}" "$TMP/repo_feature"
    t0=$(date +%s%N)
    run_hook branch-enforce.sh degraded "$TMP/repo_feature"; got=$?
    t1=$(date +%s%N); ms=$(( (t1-t0)/1000000 ))
    check "[degraded] 절 ${n}개 + ${suffix} (판정)" "$want" "$got"
    if [ "$ms" -lt 5000 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[degraded] 절 ${n}개 실행시간 ${ms}ms — 5초 timeout 초과"); fi
    printf '  절 %-4s %-16s %sms\n' "$n" "$suffix" "$ms"
  done
done

# ═══════════════════════════════════════════════════════════════════
# G. python 은 살아 있는데 git-guard.py 만 실패하는 분기 (HOOK_PY 채워짐 + GG_ALL 공백)
#    hook 자체 timeout kill · HOOK_PY_TIMEOUT 만료 · 스크립트 크래시가 이 상태를 만든다.
#    `[ -n "$HOOK_PY" ]` 로만 게이트하면 여기서 조용히 통과한다 (= C2 원래 결함).
# ═══════════════════════════════════════════════════════════════════
printf '\n=== G. git-guard.py 단독 실패 (python 정상) ===\n'
mkdir -p "$TMP/shim2"
# 실제 python 의 **절대경로**를 박아 넣는다. `env python3` 로 쓰면 PATH 앞의 이 shim 자신을
# 다시 찾아 무한 재귀한다 (2026-08-03 자체 실행 중 실측 — 테스트가 10분 넘게 멈췄다).
REAL_PY=$(command -v "${PY:-python3}" 2>/dev/null)
{
  printf '#!/bin/sh\n'
  printf '# -c(인라인)만 정상 · 스크립트 실행은 실패 → HOOK_PY 채워짐 + GG_ALL 공백 재현\n'
  printf 'case "$1" in\n'
  printf '  -c) exec "%s" "$@" ;;\n' "$REAL_PY"
  printf '  *)  exit 9 ;;\n'
  printf 'esac\n'
} > "$TMP/shim2/python3"
cp "$TMP/shim2/python3" "$TMP/shim2/python"
chmod +x "$TMP/shim2/python3" "$TMP/shim2/python"
for row in "2|f|git merge main" "2|f|git push" "0|f|git status" "2|m|git cherry-pick abc"; do
  want="${row%%|*}"; rest="${row#*|}"; repo="${rest%%|*}"; cmd="${rest#*|}"
  [ "$repo" = m ] && cwd="$TMP/repo_master" || cwd="$TMP/repo_feature"
  bash_payload "$cmd" "$cwd"
  LAST_OUT=$(cd "$cwd" && PATH="$TMP/shim2:$PATH" bash "$HOOKS_DIR/branch-enforce.sh" < "$TMP/p.json" 2>&1)
  check "[guard-py실패] $cmd" "$want" "$?"
done

# ═══════════════════════════════════════════════════════════════════
# H. tasks/{작업명}/steps/ 면제 (2026-08-03) — output-naming-check + gate-enforce
#    working-lifecycle.sh 의 `step 평면 파일 → steps/ 분배 이동` 루프가 working/ → tasks/ 이동 시
#    step 평면 파일을 `steps/NN-{slug}.md` 로 mv 한다. mv 는 PreToolUse 를 안 타므로 이 파일들은 날짜 prefix 가 없고,
#    두 hook 이 그 배치를 모르면 이동이 끝난 step 문서는 **어떤 편집도 영구 차단**된다 (실측 667/667).
#    반대로 면제가 넓어지면 경로 규칙 자체가 무의미해진다 — 임의 깊이 / generic 이름 /
#    '..' 세그먼트 / 환경변수 주입 / 도구명 교체(MultiEdit) 가 전부 우회 통로였다.
#    그래서 "열려야 하는 것" 과 "닫혀 있어야 하는 것" 을 같이 고정한다. 한쪽만 있으면
#    되돌림(revert)이 초록으로 통과한다.
# ═══════════════════════════════════════════════════════════════════
printf '\n=== H. steps/ 면제 + 과확장 가드 (naming · gate · MultiEdit · cwd · env) ===\n'
H_CWD="C:/works/hongcafe_global_backend"    # 레포 cwd — .claude cwd 면제 분기를 안 타는 정상 경로
H_CWD_CLAUDE="C:/Users/PV/.claude"          # .claude cwd 면제 분기를 **타는** 경로 (별도 커버 필요)
H_TASKS="C:/Users/PV/.claude/docs/api-spec-reviews/tasks"
# 세션 id·gate 파일에 $$ 부착 — 고정 이름이면 스위트 2개가 동시에 돌 때 서로의 gate 파일을 지우고,
# gate 파일이 사라지면 gate-enforce 가 즉시 exit 0 이라 "차단 기대" 케이스가 통째로 거짓 FAIL 이 된다.
H_SID="guardtests$$"        # gate=2 (EXECUTE)
H_SID0="guardtests0$$"      # gate=0 (LOCKED) — .claude cwd 화이트리스트 미매칭 fall-through 검증용
H_GATE="/tmp/claude_gate_${H_SID}"
H_GATE0="/tmp/claude_gate_${H_SID0}"
echo 2 > "$H_GATE"
echo 0 > "$H_GATE0"

# 판정 원재료 부재를 조용히 '차단' 으로 세지 않는다 — 없으면 그 사실 자체를 FAIL 로 올린다.
for h in output-naming-check.sh gate-enforce.sh; do
  [ -f "$HOOKS_DIR/$h" ] || { FAIL=$((FAIL+1)); fail_lines+=("[H] $h 부재 — 판정 불가(차단으로 집계 금지)"); }
done

path_payload() {  # $1=tool_name $2=file_path $3=cwd $4=session_id(선택)
  # hook_event_name 필수 — 누락 시 일부 hook 이 조용히 미실행돼 "통과" 로 오집계된다.
  printf '{"session_id":"%s","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"%s","tool_input":{"file_path":"%s","old_string":"a","new_string":"b","edits":[{"old_string":"a","new_string":"b"}]}}' \
    "${4:-$H_SID}" "$(json_escape "$3")" "$1" "$(json_escape "$2")" > "$TMP/p.json"
}
check_reason() {  # $1=라벨 $2=기대exit $3=실제exit $4=기대 사유 substring(빈 값이면 생략)
  # exit code 만 보면 **차단 사유가 뒤바뀌어도 초록**이다 (예: '..' 가드가 죽어도 else 분기가 2 를 낸다).
  check "$1" "$2" "$3"
  # exit 이 이미 어긋났으면 사유 검사를 더 하지 않는다 — 계속하면 같은 케이스가
  # FAIL+1 과 PASS+1 을 동시에 올려 헤드라인 PASS 가 실제 성공 건수를 부풀린다.
  [ "$2" = "$3" ] || return 1
  [ -z "${4:-}" ] && return 0
  case "${LAST_OUT:-}" in
    *"$4"*) PASS=$((PASS+1)) ;;
    *) FAIL=$((FAIL+1)); fail_lines+=("$1 — 차단 사유 불일치: stderr 에 '$4' 없음") ;;
  esac
}

# 형식: "exit|hook|tool|경로|사유substring|라벨"
H_CASES=(
  # ── 열려야 하는 것: step 평면 파일 (날짜 prefix 없음) ──
  "0|output-naming-check.sh|Edit|$H_TASKS/20260727/t/steps/02-repository.md||steps/ 무날짜 파일 naming"
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/02-repository.md||steps/ 무날짜 파일 경로규칙"
  "0|gate-enforce.sh|MultiEdit|$H_TASKS/20260727/t/steps/02-repository.md||steps/ 정상 + MultiEdit"
  "0|output-naming-check.sh|Edit|$H_TASKS/20260727/t/steps/2026-08-03-x.md||steps/ 날짜 있는 파일"
  # ── 닫혀 있어야 하는 것: 과확장 방지 (사유까지 고정) ──
  "2|output-naming-check.sh|Edit|$H_TASKS/20260727/t/steps/summary.md|[TASK-NAMING] 제네릭|steps/ generic 이름은 계속 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/sub/x.md|tasks/ 경로 규칙 위반 — 허용 패턴|steps/ 하위 4단계 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/sub/2026-08-03-x.md|tasks/ 경로 규칙 위반 — 허용 패턴|steps/sub 는 날짜 있어도 차단"
  "2|output-naming-check.sh|Edit|$H_TASKS/20260727/t/x.md|[TASK-NAMING] 날짜 prefix|steps/ 아닌 무날짜 파일은 종전대로 차단"
  # 면제 대상은 'steps/' **리터럴 1단계** 다. 아래 2건이 없으면 다음 변경이 자유롭다:
  #   (a) gate-enforce 정규식을 '(steps/|other/)?' 로 넓히기 — 깊이만 고정돼 있어 리터럴이 안 잠긴다
  #   (b) naming 정규식을 '^[^/]+/steps/' prefix-only 로 바꾸기 — 깊이 제한이 사라진다
  #       (b) 는 gate-enforce 가 backstop 이라 런타임 영향은 없지만 defense-in-depth 한 겹이 조용히 사라진다
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/t/other/x.md|tasks/ 경로 규칙 위반 — 허용 패턴|'other/' 는 면제 아님(리터럴 동일성)"
  "2|output-naming-check.sh|Edit|$H_TASKS/20260727/t/steps/sub/x.md|[TASK-NAMING] 날짜 prefix|naming: steps/ 하위 4단계는 면제 아님"
  # ── '..' 가드: tasks/ 안 · tasks/ 앞 · naming hook 쪽 모두 ──
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/../summary.md|'..' 세그먼트를 쓸 수 없습니다|'..' 세그먼트 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/t/../steps/x.md|'..' 세그먼트를 쓸 수 없습니다|'..' + steps 조합 차단"
  "2|gate-enforce.sh|Edit|C:/Users/PV/.claude/docs/api-spec-reviews/specs/../tasks/20260727/t/steps/sub/deep/x.md|'..' 세그먼트를 쓸 수 없습니다|'..' 이 tasks/ **앞**에 온 우회"
  "2|gate-enforce.sh|Edit|C:/Users/PV/.claude/docs/api-spec-reviews/output/../tasks/badpath.md|'..' 세그먼트를 쓸 수 없습니다|면제경로 경유 '..' 우회"
  "2|output-naming-check.sh|Edit|$H_TASKS/20260727/../steps/x.md|[TASK-NAMING] 날짜 prefix|naming: '..'+steps 는 면제 대상 아님"
  # ── '..' 판정: hook 단독 기대값 ≠ 체인 최종 기대값 (둘 다 고정한다) ──
  #    gate-enforce(이번 신설) = **세그먼트** 판정 `(^|/)\.\.(/|$)` → 'foo..bar' · '..foo' 는 통과.
  #    worktree-enforce:43(기존) = **부분문자열** 판정 `*..*` → 같은 이름을 exit 2 로 막는다.
  #    그래서 이 2건은 "차단 대상 아님" 이 아니라 "gate-enforce 단독으로만 통과" 가 맞다.
  #    ('..' 판정을 lib/ 단일 SSOT 로 모으는 것은 별 트랙 — 여기서는 현 동작을 사실대로 고정만 한다)
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/foo..bar.md||'foo..bar.md' gate-enforce 단독 통과(세그먼트 아님)"
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/..foo.md||'..foo.md' gate-enforce 단독 통과(세그먼트 아님)"
  "2|worktree-enforce.sh|Edit|$H_TASKS/20260727/t/steps/foo..bar.md|WORKTREE-ENFORCE|'foo..bar.md' 체인 최종 = 차단"
  "2|worktree-enforce.sh|Edit|$H_TASKS/20260727/t/steps/..foo.md|WORKTREE-ENFORCE|'..foo.md' 체인 최종 = 차단"
  "0|worktree-enforce.sh|Edit|$H_TASKS/20260727/t/steps/02-repository.md||정상 step 파일은 체인에서도 통과"
  # ── 도구명 교체 우회 (matcher 는 MultiEdit 포함인데 hook 조건에서 빠져 있었다) ──
  "2|gate-enforce.sh|MultiEdit|$H_TASKS/badpath.md|tasks/ 경로 규칙 위반 — 허용 패턴|MultiEdit + 규칙위반 경로 차단"
  "2|gate-enforce.sh|MultiEdit|$H_TASKS/20260727/t/../2026-08-03-x.md|'..' 세그먼트를 쓸 수 없습니다|MultiEdit + '..' 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/badpath.md|tasks/ 경로 규칙 위반 — 허용 패턴|Edit + 규칙위반 경로 차단(회귀)"
  # ── 기존 허용 경로 회귀 ──
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/summary.md||YYYYMMDD/summary.md 유지"
  "0|gate-enforce.sh|Edit|$H_TASKS/history.md||history.md 유지"
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/t/2026-08-03-t-plan.md||평면 2단계 유지"
)
for row in "${H_CASES[@]}"; do
  want="${row%%|*}"; rest="${row#*|}"
  hook="${rest%%|*}"; rest="${rest#*|}"
  tool="${rest%%|*}"; rest="${rest#*|}"
  fp="${rest%%|*}";   rest="${rest#*|}"
  reason="${rest%%|*}"; label="${rest#*|}"
  path_payload "$tool" "$fp" "$H_CWD"
  # worktree-enforce 는 **pwd 가 git work-tree 안일 때만** 판정한다 (git 미연동 cwd = 면제).
  # $TMP 는 git 저장소가 아니라 여기서 돌리면 전건 통과 → 체인 기대값 검증이 무의미해진다.
  case "$hook" in
    worktree-enforce.sh) h_cwd="$TMP/repo_feature" ;;
    *)                   h_cwd="$TMP" ;;
  esac
  run_hook "$hook" normal "$h_cwd"
  check_reason "[H][$tool] $label" "$want" "$?" "$reason"
done

# ── cwd=~/.claude 분기 (하니스 자기수정 부트스트랩 면제) ──
#    위 케이스는 전부 레포 cwd 라 이 분기를 한 번도 실행하지 않는다. 그래서 면제 조건에서
#    MultiEdit 을 빼는 변경이 매트릭스에 잡히지 않았다. 화이트리스트 안/밖을 같이 고정한다.
#    gate=0 세션을 쓰는 이유: 화이트리스트 미매칭 시 fall-through 해서 **실제로 차단되는지**를
#    봐야 하는데, gate=2 면 비코드 파일이 그냥 통과해 분기 도달 여부를 구분할 수 없다.
for row in \
  "2|Edit|$H_CWD_CLAUDE/custom-plugin/taskflow/commands/x.md|비코드 파일 수정 차단|화이트리스트 밖(custom-plugin) Edit" \
  "2|MultiEdit|$H_CWD_CLAUDE/custom-plugin/taskflow/commands/x.md|비코드 파일 수정 차단|화이트리스트 밖(custom-plugin) MultiEdit" \
  "0|Edit|$H_CWD_CLAUDE/hooks/x.sh||화이트리스트 안(hooks/) Edit 면제 유지" \
  "0|MultiEdit|$H_CWD_CLAUDE/hooks/x.sh||화이트리스트 안(hooks/) MultiEdit 면제 유지" \
  ; do
  want="${row%%|*}"; rest="${row#*|}"
  tool="${rest%%|*}"; rest="${rest#*|}"
  fp="${rest%%|*}";   rest="${rest#*|}"
  reason="${rest%%|*}"; label="${rest#*|}"
  path_payload "$tool" "$fp" "$H_CWD_CLAUDE" "$H_SID0"
  run_hook gate-enforce.sh normal "$TMP"
  check_reason "[H][cwd=.claude][$tool] $label" "$want" "$?" "$reason"
done

# ── 환경변수 주입: IS_STEP_FILE 은 hook 내부 판정 결과여야 하고 외부에서 켤 수 없어야 한다.
#    KIND 분기 안에서만 초기화하면 output//working/ 는 대입을 안 거쳐 환경값을 그대로 읽는다.
for row in \
  "C:/Users/PV/.claude/docs/claude-harness/output/analysis/2026-08-03-guardtest/notes-x.md|output/ 무날짜" \
  "C:/Users/PV/.claude/docs/working/20260803/x.md|working/ 무날짜" \
  "$H_TASKS/20260727/t/x.md|tasks/ 비-step 무날짜" \
  ; do
  fp="${row%%|*}"; label="${row#*|}"
  path_payload Edit "$fp" "$H_CWD"
  LAST_OUT=$(cd "$TMP" && IS_STEP_FILE=true bash "$HOOKS_DIR/output-naming-check.sh" < "$TMP/p.json" 2>&1)
  check_reason "[H][env주입] IS_STEP_FILE=true + $label" 2 "$?" "날짜 prefix 누락 차단"
done
rm "$H_GATE" "$H_GATE0" 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
# I. working_scan — 날짜 폴더(YYYYMMDD) 판정 회귀 (2026-08-06, backlog/ 경로 이관 부수 검증)
#    hooks/lib/working-scan.sh 는 `pp[n-1] !~ /^[0-9]{8}$/` 로 root 직속 폴더가 8자리 숫자인지만
#    본다(문자열 "backlog" 매칭이 아니다). 이 방식이 실제로 (a) working/backlog/ 를 배제하고
#    (b) 정상 날짜폴더 파일명에 우연히 '-backlog-' 토큰이 섞여도 안 죽고 (c) WORKING_ROOT 자신의
#    경로에 'backlog' 세그먼트가 있어도 오배제하지 않는지를 고정한다. (b)(c) 가 없으면 "backlog
#    문자열을 path 에서 grep 으로 거른" 구현으로 되돌아가도 (a) 만 보는 매트릭스는 초록으로 남는다.
# ═══════════════════════════════════════════════════════════════════
printf '\n=== I. working_scan 날짜 폴더 판정 (backlog/ 배제 · 경계값) ===\n'
# shellcheck disable=SC1091
source "$HOOKS_DIR/lib/working-scan.sh"

WSCAN_ROOT="$TMP/wscan_root"
mkdir -p "$WSCAN_ROOT/working/20260805" "$WSCAN_ROOT/working/backlog" "$WSCAN_ROOT/wsp"
printf 'Status: In Progress\n' > "$WSCAN_ROOT/working/20260805/2026-08-05-wsp-normal-task.md"
printf 'Status: In Progress\n' > "$WSCAN_ROOT/working/20260805/2026-08-05-wsp-my-backlog-cleanup.md"
printf 'status: pending\n' > "$WSCAN_ROOT/working/backlog/2026-08-05-some-backlog-item.md"

OUT=$(WORKING_ROOT="$WSCAN_ROOT/working" WORKING_SCAN_DOCS_ROOT="$WSCAN_ROOT" working_scan all)

# I-0. 기준선 — 정상 날짜폴더 태스크는 스캔된다 (아래 배제 결과가 "전부 0건" 착시가 아님을 보장)
BASE_MATCH=$(printf '%s\n' "$OUT" | grep -c "wsp-normal-task" || true)
if [ "$BASE_MATCH" -eq 1 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[I-0] 기준 정상 태스크 미스캔 — 매치=${BASE_MATCH}"); fi

# I-1. 배제 방향 — working/backlog/*.md 는 working_scan all 결과에 0건
BACKLOG_MATCH=$(printf '%s\n' "$OUT" | grep -c "some-backlog-item" || true)
if [ "$BACKLOG_MATCH" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[I-1] working/backlog/*.md 배제 실패 — ${BACKLOG_MATCH}건 노출"); fi

# I-2. 보존 방향 — 날짜폴더 안 파일명에 '-backlog-' 토큰이 있어도 문자열 매칭이 아니라 폴더 판정이므로 생존
NORMAL_MATCH=$(printf '%s\n' "$OUT" | grep -c "wsp-my-backlog-cleanup" || true)
if [ "$NORMAL_MATCH" -eq 1 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[I-2] 날짜폴더 내 '-backlog-' 토큰 파일이 문자열매칭식 구현으로 되돌아가 배제됨 — 매치=${NORMAL_MATCH}"); fi

# I-3. 경계 — WORKING_ROOT 끝 슬래시 0/1/2개 무관 동일 결과
for suf in "" "/" "//"; do
  CNT=$(WORKING_ROOT="${WSCAN_ROOT}/working${suf}" WORKING_SCAN_DOCS_ROOT="$WSCAN_ROOT" working_scan all | grep -c "wsp-normal-task" || true)
  if [ "$CNT" -eq 1 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[I-3] WORKING_ROOT trailing-slash '${suf}'(길이 ${#suf}) 판정 실패 — 매치=${CNT}"); fi
done

# I-4. 경계 — WORKING_ROOT 경로 자신의 조상 세그먼트에 'backlog' 가 있어도 root 직속 날짜폴더는 정상 스캔
#   (working-scan.sh 헤더 주석이 `find -not -path` 대신 pp[n-1] 직접 판정을 쓰는 이유로 든 케이스)
WSCAN_ROOT2="$TMP/backlog/wscan_root2"
mkdir -p "$WSCAN_ROOT2/working/20260805" "$WSCAN_ROOT2/wsp2"
printf 'Status: In Progress\n' > "$WSCAN_ROOT2/working/20260805/2026-08-05-wsp2-task-in-backlog-ancestor.md"
CNT2=$(WORKING_ROOT="$WSCAN_ROOT2/working" WORKING_SCAN_DOCS_ROOT="$WSCAN_ROOT2" working_scan all | grep -c "task-in-backlog-ancestor" || true)
if [ "$CNT2" -eq 1 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[I-4] WORKING_ROOT 조상 경로 'backlog' 세그먼트로 오배제 — 매치=${CNT2}"); fi

# ═══════════════════════════════════════════════════════════════════
# J. backlog-lifecycle.sh — mv + 인덱스 삭제 회귀 (콜드리뷰 M5, 2026-08-06 · R4 라운드 H1~H3 실데이터 픽스처 보강)
#    섹션 I 는 working_scan 판정만 고정한다. 실제 파괴적 경로(파일 mv + MEMORY.md/BACKLOG.md 라인
#    삭제)는 지금까지 수동 실측에만 의존했다 — 최소한 앵커 우회(상대경로·하위폴더)와 인덱스 오삭제
#    (동명 slug 의 무관 Project entry 보존)를 payload 주입으로 고정한다. H1(href 합집합 매칭 — 실
#    MEMORY.md 34자 절단 링크 텍스트 픽스처)·H2(`·` 병합 라인 형제 entry 보존)·H3(verify_index_sync
#    전 project 합산)·M2(product 경로 traversal 차단) 수정분도 덮는다.
#    HOME 을 fakehome 으로 override 해 실제 projects/*/memory 를 절대 건드리지 않는다(규율).
#    fakehome 은 $TMP(TMPDIR 경유 /c/... 루트) 하위라 python(native) 이 경로를 읽을 수 있다.
#    BACKLOG_INDEX_LOCK 도 $TMP 하위로 override(콜드리뷰 R4 M5) — 기본값(/tmp/claude-backlog-index.lock.d)
#    은 실세션과 공유되는 프로덕션 lock 경로라, override 안 하면 테스트가 실세션과 최대 5초
#    상호 대기하거나 중단 시 lock 잔류로 실세션이 TTL 2분까지 stale 경고를 문다. $TMP 하위라 트랩의
#    generic find-delete 가 자동으로 회수한다(별도 cleanup 등재 불요).
# ═══════════════════════════════════════════════════════════════════
printf '\n=== J. backlog-lifecycle.sh 회귀 (앵커 우회 · 인덱스 오삭제 · H1 · H2 · H3 · M2) ===\n'
export BACKLOG_INDEX_LOCK="$TMP/bl.lock.d"
to_win_test() {
  local v="$1"
  case "$v" in
    /c/*) v="C:/${v#/c/}" ;;
  esac
  echo "${v//\//\\}"
}
backlog_payload() {  # $1=posix file path → $TMP/p.json (PostToolUse Write, file_path=Windows 경로)
  local win
  win=$(to_win_test "$1")
  printf '{"session_id":"blt","hook_event_name":"PostToolUse","cwd":"C:\\\\x","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"},"tool_response":{"filePath":"%s"}}' \
    "$(json_escape "$win")" "$(json_escape "$win")" > "$TMP/p.json"
}

FH="$TMP/backlog_fakehome"
mkdir -p "$FH/.claude/docs/working/backlog" "$FH/.claude/projects"
# S2(2026-08-07) product 실재 검증 신설 이후 — 이 스위트가 쓰는 product 값(testprod/testprodj8) 과
# 화이트리스트 fallback 대상(claude-harness) 은 실 환경에선 이미 존재하는 트리라고 가정한다. 신 가드가
# "실재하지 않는 product = 이동 스킵" 이므로, 테스트 픽스처도 실 환경처럼 대상 디렉토리를 미리 갖고
# 있어야 한다(안 그러면 모든 기존 J 테스트가 "이동 스킵"으로 새로 실패한다 — 가드 자체 회귀가 아니라
# 픽스처가 신 전제를 안 갖춘 것).
mkdir -p "$FH/.claude/docs/claude-harness" "$FH/.claude/docs/testprod" "$FH/.claude/docs/testprodj8"

# J-1. 앵커 우회 — 하위폴더 파일은 이동되면 안 된다
mkdir -p "$FH/.claude/docs/working/backlog/sub"
cat > "$FH/.claude/docs/working/backlog/sub/2026-08-01-subfoldertest.md" <<'EOF'
---
name: subfoldertest
metadata:
  status: done
  product: testprod
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/sub/2026-08-01-subfoldertest.md"
HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" >/dev/null 2>&1
if [ -f "$FH/.claude/docs/working/backlog/sub/2026-08-01-subfoldertest.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-1] 하위폴더 파일이 이동됨(앵커 우회)"); fi

# J-2. 앵커 우회 — '..' 상위경로 traversal 로 표기된 경로는 이동되면 안 된다
mkdir -p "$FH/.claude/docs/working/elsewhere"
cat > "$FH/.claude/docs/working/elsewhere/2026-08-01-traversaltest.md" <<'EOF'
---
name: traversaltest
metadata:
  status: done
  product: testprod
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/../elsewhere/2026-08-01-traversaltest.md"
HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" >/dev/null 2>&1
if [ -f "$FH/.claude/docs/working/elsewhere/2026-08-01-traversaltest.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-2] '..' traversal 경로 파일이 이동됨(앵커 우회)"); fi

# J-3. 인덱스 오삭제 방지 — 실제 backlog entry 는 지우고 (a) 같은 slug 텍스트를 우연히 공유하는
#   무관 Project entry(backlog_/backlog/ 참조 없음, AND 조건 판정, 콜드리뷰 R2 High-1) 와 (b) Backlog
#   섹션 **밖**에서 우연히 같은 href 를 인용하는 교차참조(콜드리뷰 R6 H2, 섹션 스코핑) 는 보존해야 한다.
#   **헤더는 실 production 표기를 그대로 사본으로 사용한다** — 손으로 "## Backlog" 단순형만 쓰면 실
#   표기(제목 뒤 부연 `## Backlog (게이트·§3·…)`) 를 재현 못 해 스코핑 회귀를 못 잡는다(R3~R6 4라운드
#   연속 지적 — 표기 차이를 실 파일에서 그대로 떠서 픽스처에 자동 반영시킨다).
mkdir -p "$FH/.claude/projects/projA/memory"
REAL_BACKLOG_HEADER=$(grep -m1 -E '^## Backlog\b' "$HOME/.claude/projects/C--Works-hongcafe-global-backend/memory/MEMORY.md" 2>/dev/null)
[ -z "$REAL_BACKLOG_HEADER" ] && REAL_BACKLOG_HEADER='## Backlog (게이트·§3·P0/P1·harness만 / 상세=각 파일 / 전량=`Glob backlog_*.md`)'
{
  echo "# Memory"
  echo "$REAL_BACKLOG_HEADER"
  echo "- [samenameslug](backlog/2026-08-01-samenameslug.md) — real backlog entry (should be removed)"
  echo "## Project"
  echo "- [samenameslug](project_namespace_collision.md) — unrelated project doc, no href (should be preserved)"
  echo "## Reference"
  echo "- [crossref](backlog_samenameslug.md) — 섹션 밖 교차참조, 실 href 보유 (섹션 스코핑으로 보존돼야 함)"
} > "$FH/.claude/projects/projA/memory/MEMORY.md"
cat > "$FH/.claude/docs/working/backlog/2026-08-01-samenameslug.md" <<'EOF'
---
name: samenameslug
metadata:
  status: done
  product: testprod
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-01-samenameslug.md"
HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" >/dev/null 2>&1
MEM_J3="$FH/.claude/projects/projA/memory/MEMORY.md"
if ! grep -qF 'backlog/2026-08-01-samenameslug.md' "$MEM_J3"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3a] 실제 backlog entry 가 제거되지 않음"); fi
if grep -qF 'project_namespace_collision.md' "$MEM_J3"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3b] 동명 슬러그의 무관 Project entry 가 함께 삭제됨(오삭제)"); fi
if grep -qF 'backlog_samenameslug.md' "$MEM_J3" && grep -qF '## Reference' "$MEM_J3"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3c] Backlog 섹션 밖 교차참조가 삭제됨(H2 섹션 스코핑 회귀) — 실 헤더 표기: $REAL_BACKLOG_HEADER"); fi

# J-4. H1 — index entry 가 harness-home 이 아닌 별도 project(projB)에만 있어도 제거돼야 한다
mkdir -p "$FH/.claude/projects/projB/memory"
cat > "$FH/.claude/projects/projB/memory/MEMORY.md" <<'EOF'
# Memory
## Backlog
- [multiprojslug](backlog/2026-08-01-multiprojslug.md) — entry only in projB
EOF
cat > "$FH/.claude/docs/working/backlog/2026-08-01-multiprojslug.md" <<'EOF'
---
name: multiprojslug
metadata:
  status: done
  product: testprod
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-01-multiprojslug.md"
J4_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if ! grep -qF 'multiprojslug' "$FH/.claude/projects/projB/memory/MEMORY.md"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-4] harness-home 아닌 별도 project(projB) index entry 가 제거 안 됨"); fi
if ! echo "$J4_OUT" | grep -qF '전 project index'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-4] 정상 제거됐는데 aggregate notfound 경고가 오탐으로 뜸"); fi

# J-3b. H1(R4) — 실 MEMORY.md 표기 재현: 링크 텍스트가 34자로 절단돼 slug 와 다른 항목도 href 로 제거돼야 한다
#   (실측 사례: `[api-keys-unset-all-envs-pbx-blocke](backlog_api-keys-unset-all-envs-pbx-blocked.md)`)
mkdir -p "$FH/.claude/projects/projTrunc/memory"
cat > "$FH/.claude/projects/projTrunc/memory/MEMORY.md" <<'EOF'
# Memory
## Backlog
- [truncatedlinktextexampleslugnam](backlog_truncatedlinktextexampleslugname.md) — link text truncated, slug has trailing 'e'
EOF
cat > "$FH/.claude/docs/working/backlog/2026-08-01-truncatedlinktextexampleslugname.md" <<'EOF'
---
name: truncatedlinktextexampleslugname
metadata:
  status: done
  product: testprod
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-01-truncatedlinktextexampleslugname.md"
J3B_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if ! grep -qF 'truncatedlinktextexampleslugname' "$FH/.claude/projects/projTrunc/memory/MEMORY.md"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3b] 링크 텍스트 절단된 entry 가 href 매칭으로 제거되지 않음(H1 회귀)"); fi
if echo "$J3B_OUT" | grep -qF '✓ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3b] 정상 제거됐는데 ✓ 마커가 안 뜸(M7)"); fi

# J-3c. H2(R4) — 실 MEMORY.md 표기 재현: `·` 로 병합된 2개 bullet 라인은 형제 entry 를 보존해야 한다
#   (실측: img-server-const-undefined-fatal done 처리 시 같은 줄의 naver-api-const-undefined-fatal 소실)
mkdir -p "$FH/.claude/projects/projMerge/memory"
cat > "$FH/.claude/projects/projMerge/memory/MEMORY.md" <<'EOF'
# Memory
## Backlog
- [img-server-const-undefined-fatal](backlog_img-server-const-undefined-fatal.md)·[naver-api-const-undefined-fatal](backlog_naver-api-const-undefined-fatal.md) — merged bullet line
EOF
cat > "$FH/.claude/docs/working/backlog/2026-08-01-img-server-const-undefined-fatal.md" <<'EOF'
---
name: img-server-const-undefined-fatal
metadata:
  status: done
  product: testprod
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-01-img-server-const-undefined-fatal.md"
J3C_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
MEM_J3C="$FH/.claude/projects/projMerge/memory/MEMORY.md"
if grep -qF 'naver-api-const-undefined-fatal' "$MEM_J3C"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3c] '·' 병합 라인에서 형제 entry(naver-api) 가 침묵 소실됨(H2 회귀)"); fi
if grep -qF 'img-server-const-undefined-fatal' "$MEM_J3C"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3c] 병합 라인 자체가 사라짐(manual 보류 실패)"); fi
if echo "$J3C_OUT" | grep -qF '△ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-3c] 인덱스 미정리인데 △ 마커가 안 뜸(M7)"); fi

# J-6. High(R5) — verify_index_sync 는 "인덱스에 있는데 본문 없음"(죽은 링크) 축만 봐야 한다.
#   실 조건 3개(BACKLOG.md 는 11 project 중 1곳에만 존재 · 본문이 index 없는 project 에도 흩어짐 ·
#   MEMORY.md 는 큐레이션 인덱스라 미등재가 정상) 를 비대칭으로 재현한다.
mkdir -p "$FH/.claude/projects/projMemOnlyA/memory" "$FH/.claude/projects/projMemOnlyB/memory" "$FH/.claude/projects/projBodyOnly/memory"
# projMemOnlyA/B — MEMORY.md 만 있고 BACKLOG.md 없음(실측 11 project 중 10곳 형태). 본문 참조 없음
# (큐레이션 정상 상태 = index 에서 완전히 빠짐, 그래서 이 두 MEMORY.md 는 Backlog 섹션이 비어 있다).
# projMemOnlyA 는 j6athenashaped 를 참조하는 entry 도 하나 갖는다(M2 픽스처).
cat > "$FH/.claude/projects/projMemOnlyA/memory/MEMORY.md" <<'EOF'
# Memory
## Backlog
- [j6athenashaped](backlog_j6athenashaped.md) — 본문이 index 없는 다른 project 에 있음(M2)
EOF
cat > "$FH/.claude/projects/projMemOnlyB/memory/MEMORY.md" <<'EOF'
# Memory
## Backlog
EOF
# 본문은 있는데 어느 index 에도 참조가 없는 경우(정상, 미등재 축 삭제로 오탐 없어야 함)
cat > "$FH/.claude/projects/projMemOnlyB/memory/backlog_j6bodyonlynoindex.md" <<'EOF'
legacy body with no index reference anywhere — normal state after H1 fix
EOF
cat > "$FH/.claude/docs/working/backlog/2026-08-01-j6bodyonlynoindex2.md" <<'EOF'
---
name: j6bodyonlynoindex2
metadata:
  status: pending
  product: testprod
---
new-path body with no index reference anywhere — also normal
EOF
# projBodyOnly — MEMORY.md/BACKLOG.md 가 **아예 없이** 본문만 있는 memory 디렉토리(콜드리뷰 R6 M2,
# 실측 C--Works-hongcafe-global-athena 형태). all_index_files() 로는 이 디렉토리가 절대 안 잡힌다 —
# all_memory_dirs() 로 직접 조회해야만 이 본문이 "존재하는 파일" 로 카운트돼, projMemOnlyA 의 참조가
# 죽은 링크로 오탐되지 않는다.
cat > "$FH/.claude/projects/projBodyOnly/memory/backlog_j6athenashaped.md" <<'EOF'
legacy body in a memory dir with no MEMORY.md/BACKLOG.md at all (athena-shaped, M2)
EOF
# 진짜 죽은 링크 — index 에 참조가 있는데 본문이 어디에도 없음(실제 drift, 잡혀야 함)
cat > "$FH/.claude/projects/projMemOnlyA/memory/BACKLOG.md" <<'EOF'
# Backlog detail (harness-home 형태로 1곳에만 존재)
- [j6genuinedeadlink](backlog_j6genuinedeadlink.md) — 본문 파일이 실제로 없음
- 코드블록 예시: `Glob backlog_*.md` 같은 허수 slug 도 여기서 같이 검증
EOF
# 아무 pending 파일 저장으로 verify_index_sync 트리거 (전역 스캔이라 특정 파일과 무관)
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-01-j6bodyonlynoindex2.md"
J6_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if ! echo "$J6_OUT" | grep -qF '미등재'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-6a] '미등재' 축이 부활함(High 회귀) — 출력: $J6_OUT"); fi
if ! echo "$J6_OUT" | grep -qF 'j6bodyonlynoindex'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-6c] 인덱스 없는 정상 본문(j6bodyonlynoindex, 큐레이션 정상 상태)이 오탐으로 뜸"); fi
if echo "$J6_OUT" | grep -qF 'j6genuinedeadlink'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-6d] 진짜 죽은 링크(j6genuinedeadlink)가 감지되지 않음(검증 무력화)"); fi
if ! echo "$J6_OUT" | grep -qE '(^|[^A-Za-z0-9_-])\*([^A-Za-z0-9_-]|$)'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-6e] 코드블록 glob 예시(*)가 허수 slug 로 죽은 링크에 섞여 나옴 — 출력: $J6_OUT"); fi
if ! echo "$J6_OUT" | grep -qF 'j6athenashaped'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-6f] index 파일이 없는 memory 디렉토리(athena 형태)의 본문이 죽은 링크로 오탐됨(M1 회귀) — 출력: $J6_OUT"); fi

# J-5. M2 — frontmatter product: 값의 경로 traversal 은 차단되고 claude-harness 로 대체돼야 한다
cat > "$FH/.claude/docs/working/backlog/2026-08-01-travproducttest.md" <<'EOF'
---
name: travproducttest
metadata:
  status: done
  product: ../../../pwned
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-01-travproducttest.md"
J5_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ ! -d "$FH/pwned" ] && [ ! -d "$TMP/pwned" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-5] product traversal 로 fakehome/docs 바깥에 폴더 생성됨"); fi
if compgen -G "$FH/.claude/docs/claude-harness/tasks/*/backlog/2026-08-01-travproducttest.md" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-5] 무효 product 대체(claude-harness) 후 정상 위치 이동 실패"); fi
if echo "$J5_OUT" | grep -qF '허용 문자'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-5] product 대체 경고가 stderr 에 없음"); fi

# J-7. M6(R5) — UserPromptSubmit 일괄 경로 무테스트였다: 키워드 트리거 → done 만 이동, pending 은
#   스킵, moved_count 정확히 계상돼야 한다.
uprompt_payload() {  # $1=prompt text → $TMP/p.json
  printf '{"session_id":"blt-uprompt","hook_event_name":"UserPromptSubmit","prompt":"%s"}' \
    "$(json_escape "$1")" > "$TMP/p.json"
}
cat > "$FH/.claude/docs/working/backlog/2026-08-02-j7donefile.md" <<'EOF'
---
name: j7donefile
metadata:
  status: done
  product: testprod
---
x
EOF
cat > "$FH/.claude/docs/working/backlog/2026-08-02-j7pendingfile.md" <<'EOF'
---
name: j7pendingfile
metadata:
  status: pending
  product: testprod
---
x
EOF
uprompt_payload "backlog 완료 처리해줘"
J7_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ ! -f "$FH/.claude/docs/working/backlog/2026-08-02-j7donefile.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-7a] UserPromptSubmit 키워드에도 done 파일이 이동 안 됨"); fi
if [ -f "$FH/.claude/docs/working/backlog/2026-08-02-j7pendingfile.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-7b] pending 파일이 배치 처리 중 잘못 이동됨"); fi
if echo "$J7_OUT" | grep -qE '1건 working/backlog'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-7c] moved_count 가 1건으로 정확히 보고되지 않음 — 출력: $J7_OUT"); fi

# J-8. M6(R5) — completed: 삽입이 metadata: 하위 들여쓰기를 유지하는지, history.md/summary.md 가
#   실제로 갱신되는지(전부 무테스트였다) 고정.
cat > "$FH/.claude/docs/working/backlog/2026-08-02-j8writeeffects.md" <<'EOF'
---
name: j8writeeffects
metadata:
  status: done
  product: testprodj8
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-02-j8writeeffects.md"
HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" >/dev/null 2>&1
TODAY8=$(date +%Y%m%d)
J8_MOVED="$FH/.claude/docs/testprodj8/tasks/$TODAY8/backlog/2026-08-02-j8writeeffects.md"
if grep -qE '^  completed: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$J8_MOVED" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-8a] completed: 필드가 metadata: 들여쓰기(2칸)를 유지하지 않음"); fi
if grep -qF 'j8writeeffects' "$FH/.claude/docs/testprodj8/tasks/history.md" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-8b] history.md 가 갱신되지 않음"); fi
if grep -qF 'j8writeeffects' "$FH/.claude/docs/testprodj8/tasks/$TODAY8/summary.md" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-8c] summary.md 가 갱신되지 않음"); fi

# J-9. M4(R6) — index lock 획득 실패 시에도 index_incomplete 가 세워져 △ 마커가 떠야 한다
# (이전엔 lock 실패로 무보호 강행했는데 최종 마커는 ✓ 였다 — △/✓ 를 가르는 목적과 어긋났다).
mkdir -p "$FH/.claude/projects/projJ9/memory"
cat > "$FH/.claude/projects/projJ9/memory/MEMORY.md" <<'EOF'
# Memory
## Backlog
- [j9locktest](backlog/2026-08-02-j9locktest.md) — lock failure marker test
EOF
cat > "$FH/.claude/docs/working/backlog/2026-08-02-j9locktest.md" <<'EOF'
---
name: j9locktest
metadata:
  status: done
  product: testprod
---
x
EOF
mkdir -p "$TMP/j9held.lock.d"  # 미리 점유된(fresh, stale 아님) lock — TTL 을 길게 줘서 회수 안 되게 함
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-02-j9locktest.md"
J9_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/j9held.lock.d" BACKLOG_INDEX_LOCK_TTL_MIN=60 BACKLOG_INDEX_LOCK_RETRIES=2 BACKLOG_INDEX_LOCK_SLEEP=0.05 \
  bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if echo "$J9_OUT" | grep -qF '△ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-9] lock 획득 실패인데 △ 대신 다른 마커가 뜸 — 출력: $J9_OUT"); fi
if ! echo "$J9_OUT" | grep -qF '✓ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-9] lock 획득 실패인데 ✓ 이동으로 성공 보고됨(M4 회귀)"); fi
rmdir "$TMP/j9held.lock.d" 2>/dev/null

# J-10. M5(R6) — 앵커 비교가 드라이브 문자 뒤 세그먼트의 대소문자 불일치에도 통과해야 한다
# (to_win_path 는 드라이브 문자만 통일, 나머지 세그먼트는 원본 그대로라 완전일치 비교면 스킵됐다).
cat > "$FH/.claude/docs/working/backlog/2026-08-02-j10casetest.md" <<'EOF'
---
name: j10casetest
metadata:
  status: done
  product: testprod
---
x
EOF
J10_SRC="$FH/.claude/docs/working/backlog/2026-08-02-j10casetest.md"
J10_WIN_LC=$(echo "$J10_SRC" | sed 's|^/c/|C:/|' | tr '[:upper:]' '[:lower:]' | sed 's|^c:|C:|')
printf '{"session_id":"blt-j10","hook_event_name":"PostToolUse","cwd":"C:\\\\x","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"},"tool_response":{"filePath":"%s"}}' \
  "$(json_escape "$J10_WIN_LC")" "$(json_escape "$J10_WIN_LC")" > "$TMP/p.json"
HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" >/dev/null 2>&1
if [ ! -f "$J10_SRC" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-10] 소문자 세그먼트 페이로드가 앵커 불일치로 스킵됨(M5 회귀) — 파일이 원 위치에 그대로 남음"); fi

# J-11. High(2026-08-07) — "href 개수" 가 아니라 "href 의 markdown 링크 뒤에 자기 요약(`—`)이
#   있는가" 로 판별해야 한다. 그룹라벨 대표줄(href 는 1개, 뒤에 요약 없이 `…`만) 은 manual 보류돼야
#   하고, 상태배지 라인(href 뒤에 정상 요약 있음) 은 배지 유무와 무관하게 정상 제거돼야 한다(오탐 방지).
#   픽스처는 손으로 재현하지 않고 실 production MEMORY.md 에서 **형태를 정규식으로 동적 선택**한다
#   (2026-08-07 콜드리뷰 R2 M2 — R1 에서 특정 slug(infra-local-copy-stale/step-developer-sonnet-measure)
#   에 grep 을 하드 결합했더니, 그 slug 들이 인덱스에서 사라지는 것(이 hook 자신이 만드는 정상
#   수명주기 — done 완료 시 지워진다)만으로 스위트가 영구 red 가 됐다. "실 인덱스에서 grep 으로
#   뜬다"의 의도는 표기 추격을 끊는 것이지 특정 인스턴스에 결합하는 것이 아니다 — **형태를 잡고
#   인스턴스는 잡지 않는다.** 11개 실 index 파일을 전수 스캔해 조건에 맞는 첫 라인을 매번 새로 찾는다.
#   grep 패턴은 href 포맷에 의존하지 않는다(구 `backlog_slug.md` / 신 `.../backlog/date-slug.md` 공통).
#   네이티브 Windows python3 는 POSIX 형(`/c/Users/...`) 경로를 이해 못 한다(`os.path.isdir` False) —
#   `to_win_test()` 로 `C:/...` 로 변환해 넘긴다(2026-08-07 R2 자체발견 — extraction 이 항상 빈 값을
#   반환해 J-11 이 setup-FAIL 조차 없이 조용히 아무 라인도 못 만드는 상태였다).
J11_HOME_WIN=$(to_win_test "$HOME/.claude")
J11_SCAN=$(python3 - "$J11_HOME_WIN" <<'PYEOF'
import re, os, glob, sys
home = sys.argv[1]
index_files = sorted(glob.glob(os.path.join(home, "projects", "*", "memory", "MEMORY.md"))) + \
              sorted(glob.glob(os.path.join(home, "projects", "*", "memory", "BACKLOG.md")))
any_link_re = re.compile(r'backlog_[^\s\]\)]+\.md|backlog/\d{4}-\d{2}-\d{2}-[^\s\]\)]+\.md')
backlog_header_re = re.compile(r'^##\s+Backlog\b')
section_header_re = re.compile(r'^##\s')
own_summary_re = re.compile(r'^\s*—')
# `[^)]*` prefix 필수(2026-08-07 R2 자체발견) — 이관 후 실 href 는 전부
# `](../../../docs/working/backlog/{date}-{slug}.md)` 처럼 상대경로 prefix 를 달고 있다. prefix
# 없이 `\(` 바로 뒤에 backlog_/backlog/ 를 요구하면 이 extraction 자체가 항상 0건을 반환해
# (Critical 패치와 정확히 같은 버그를 이 테스트 스크립트가 스스로 재현하고 있었다) J-11-setup 이
# 매번 FAIL 하거나(다행히 M1 가드 덕에 조용히 안 넘어가고 실제로 FAIL 했다) 픽스처가 안 만들어졌다.
link_re = re.compile(r'\[([^\]]*)\]\([^)]*(backlog_[^\s\]\)]+\.md|backlog/\d{4}-\d{2}-\d{2}-[^\s\]\)]+\.md)\)')
badge_prefix_re = re.compile(r'^\s*-\s*`\[[^\]]+\]`\s*\[')
# 날짜 포함 형태만 후보로 채택한다(2026-08-07 코디네이터 지적) — 구 `backlog_{slug}.md` 형태는 날짜가
# 없어 본문 파일명(`{date}-{slug}.md`)을 만들 "정답 날짜" 가 없다. 이전엔 slug_a_re(구형)/slug_b_re(신형)
# 를 or 로 묶어 아무 href 나 후보로 받고, 본문 파일명엔 **날짜와 무관하게 하드코딩한 `2026-08-02`** 를
# 썼다 — 실 href 의 날짜(예: 08-06)와 픽스처 본문 파일명 날짜(08-02)가 어긋나 S1 수정(날짜 정확 매칭)
# 이후 noref 로 떨어졌다(신 인덱스 line 자체가 애초에 틀린 날짜를 참조하는 상태를 픽스처가 만든 것 —
# J-14 가 검증하려는 "날짜 불일치" 상태와 우연히 같아져 J-11 이 원래 검증해야 할 "날짜 일치 정상 경로"
# 를 더 이상 검증하지 못했다). 신형(날짜 포함) href 만 후보로 삼고, 날짜 추출에 실패하면 그 라인은
# 후보에서 제외한다(다음 라인으로 계속 탐색) — 전 11파일에서 날짜 포함 후보를 하나도 못 찾으면
# group_ex/badge_ex 가 None 으로 남아 아래 J11_SETUP_OK 가드가 FAIL 로 떨어뜨린다(fallback 임의 날짜 금지).
slug_b_re = re.compile(r'backlog/(\d{4}-\d{2}-\d{2})-([A-Za-z0-9_-]+)\.md')

group_ex = None
badge_ex = None
for idx_path in index_files:
    try:
        with open(idx_path, encoding='utf-8') as f:
            lines = f.readlines()
    except Exception:
        continue
    has_hdr = any(backlog_header_re.match(l) for l in lines)
    in_sec = not has_hdr
    for l in lines:
        if has_hdr and section_header_re.match(l):
            in_sec = bool(backlog_header_re.match(l)); continue
        if has_hdr and not in_sec:
            continue
        links = any_link_re.findall(l)
        if len(set(links)) != 1:
            continue
        m = link_re.search(l)
        if not m:
            continue
        href = m.group(2)
        dm = slug_b_re.search(href)
        if not dm:
            continue  # 구 경로(날짜 없음) — 이 테스트의 후보 자격 없음, 다음 라인 계속 탐색
        date, slug = dm.group(1), dm.group(2)
        has_summary = bool(own_summary_re.match(l[m.end():]))
        line = l.rstrip('\n')
        if not has_summary and group_ex is None:
            group_ex = (slug, date, href, line)
        if has_summary and badge_ex is None and badge_prefix_re.match(l):
            badge_ex = (slug, date, href, line)
        if group_ex and badge_ex:
            break
    if group_ex and badge_ex:
        break

if group_ex:
    print("GROUP\t%s\t%s\t%s\t%s" % group_ex)
if badge_ex:
    print("BADGE\t%s\t%s\t%s\t%s" % badge_ex)
PYEOF
)
GROUP_SLUG=$(echo "$J11_SCAN" | awk -F'\t' '$1=="GROUP"{print $2}')
GROUP_DATE=$(echo "$J11_SCAN" | awk -F'\t' '$1=="GROUP"{print $3}')
GROUP_HREF=$(echo "$J11_SCAN" | awk -F'\t' '$1=="GROUP"{print $4}')
REAL_GROUP_LABEL_LINE=$(echo "$J11_SCAN" | awk -F'\t' '$1=="GROUP"{print $5}')
BADGE_SLUG=$(echo "$J11_SCAN" | awk -F'\t' '$1=="BADGE"{print $2}')
BADGE_DATE=$(echo "$J11_SCAN" | awk -F'\t' '$1=="BADGE"{print $3}')
BADGE_HREF=$(echo "$J11_SCAN" | awk -F'\t' '$1=="BADGE"{print $4}')
REAL_BADGE_LINE=$(echo "$J11_SCAN" | awk -F'\t' '$1=="BADGE"{print $5}')

# M1(2026-08-07 콜드리뷰 R2) — line 뿐 아니라 **HREF·SLUG·DATE 도 개별로 빈값 가드**한다. 이전엔
# `grep -qF "$GROUP_HREF" "$MEM_J11"` 에서 GROUP_HREF 가 빈 문자열이면 `grep -qF ""` 는 항상 참이라
# J-11a 가 무조건 PASS 했다 — line 이 비지 않았어도 정규식 추출이 실패해 href 만 빌 수 있어서
# line 단독 가드로는 안 잡힌다. line·href·slug·date 4개 전부를 개별로 확인한다. DATE 가 비면(=날짜
# 포함 href 후보를 전 11파일에서 하나도 못 찾음) fallback 임의 날짜를 쓰지 않고 FAIL 로 떨어뜨린다
# (2026-08-07 코디네이터 지적 — 이게 이번 사고의 형태였다).
J11_SETUP_OK=1
if [ -z "$REAL_GROUP_LABEL_LINE" ] || [ -z "$GROUP_HREF" ] || [ -z "$GROUP_SLUG" ] || [ -z "$GROUP_DATE" ]; then
  FAIL=$((FAIL+1)); fail_lines+=("[J-11-setup] 그룹라벨 형태(단일 href, 요약 없음, 날짜 포함) 라인을 실 인덱스 11파일 전체에서 못 찾음 — line='$REAL_GROUP_LABEL_LINE' href='$GROUP_HREF' slug='$GROUP_SLUG' date='$GROUP_DATE'")
  J11_SETUP_OK=0
fi
if [ -z "$REAL_BADGE_LINE" ] || [ -z "$BADGE_HREF" ] || [ -z "$BADGE_SLUG" ] || [ -z "$BADGE_DATE" ]; then
  FAIL=$((FAIL+1)); fail_lines+=("[J-11-setup] 배지 형태(백틱대괄호 태그 접두 + 단일 href + 요약 있음, 날짜 포함) 라인을 실 인덱스 11파일 전체에서 못 찾음 — line='$REAL_BADGE_LINE' href='$BADGE_HREF' slug='$BADGE_SLUG' date='$BADGE_DATE'")
  J11_SETUP_OK=0
fi

if [ "$J11_SETUP_OK" -eq 1 ]; then
  mkdir -p "$FH/.claude/projects/projLabel/memory"
  {
    echo "# Memory"
    echo "## Backlog"
    echo "$REAL_GROUP_LABEL_LINE"
    echo "$REAL_BADGE_LINE"
  } > "$FH/.claude/projects/projLabel/memory/MEMORY.md"
  MEM_J11="$FH/.claude/projects/projLabel/memory/MEMORY.md"

  # J-11a. 그룹라벨 형태 — done 처리해도 라인이 그대로 남아야 한다(manual 보류)
  #   본문 파일명 날짜 = href 에서 추출한 실제 날짜(GROUP_DATE) — 임의 날짜 하드코딩 금지. 날짜가
  #   어긋나면 href_b_re 가 애초에 매칭하지 않아 noref 로 떨어지고, 이는 J-14(날짜 불일치 케이스)가
  #   검증하는 상태와 겹쳐 J-11 자신이 검증해야 할 "날짜 일치 정상 경로"를 못 보게 된다.
  printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$GROUP_SLUG" \
    > "$FH/.claude/docs/working/backlog/${GROUP_DATE}-${GROUP_SLUG}.md"
  backlog_payload "$FH/.claude/docs/working/backlog/${GROUP_DATE}-${GROUP_SLUG}.md"
  J11A_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if grep -qF "$GROUP_HREF" "$MEM_J11"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11a] 그룹라벨 대표줄이 오삭제됨(Critical 회귀) — 실 표기: $REAL_GROUP_LABEL_LINE"); fi
  if echo "$J11A_OUT" | grep -qF '△ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11a] manual 보류인데 △ 마커가 안 뜸 — 출력: $J11A_OUT"); fi
  # J-11c(2026-08-07 콜드리뷰 R2 M3) — `manual_grouplabel` 신설 상태값·bash case arm 전용 단언.
  # `△ 이동` 은 manual·noref·removed_partial·lock 실패·any_found=0 이 전부 내는 공용 마커라
  # 이 신규 분기를 식별 못 한다. python 출력 문자열과 bash case 리터럴이 어긋나면 `*)` catch-all
  # 로 떨어져 "인덱스 처리 실패(읽기/인코딩 오류 가능)" 라는 엉뚱한 진단이 나오는데 △ 마커만 보면
  # green 이다 — 전용 메시지 문자열을 직접 grep 해 이 회귀를 막는다.
  if echo "$J11A_OUT" | grep -qF '그룹라벨 대표항목'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11c] manual_grouplabel 전용 메시지가 안 뜸(case 리터럴 불일치로 catch-all 격하 가능성) — 출력: $J11A_OUT"); fi

  # J-11b. 배지 형태 — href 뒤 정상 요약이 있으므로 배지 유무와 무관하게 정상 제거돼야 한다.
  #   본문 파일명 날짜 = href 에서 추출한 실제 날짜(BADGE_DATE) — 임의 날짜 하드코딩 금지(J-11a 와 동일 사유).
  printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$BADGE_SLUG" \
    > "$FH/.claude/docs/working/backlog/${BADGE_DATE}-${BADGE_SLUG}.md"
  backlog_payload "$FH/.claude/docs/working/backlog/${BADGE_DATE}-${BADGE_SLUG}.md"
  J11B_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if ! grep -qF "$BADGE_HREF" "$MEM_J11"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11b] 배지 라인이 정상 제거되지 않음(오탐 차단 회귀) — 실 표기: $REAL_BADGE_LINE"); fi
  if echo "$J11B_OUT" | grep -qF '✓ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11b] 정상 제거됐는데 ✓ 마커가 안 뜸 — 출력: $J11B_OUT"); fi
fi

# J-12. High + S1(2026-08-07, 콜드리뷰 R1 M1·M2 재설계) — href_b_re/target_link_re 가 날짜를
#   와일드카드로 받으면, 같은 slug 가 날짜만 다르게 2번 존재할 때(중복 slug 8쌍 실측 — 4쌍은 날짜만
#   다름) 한쪽을 done 처리하면서 살아있는 형제 entry 까지 함께 지운다. **형태를 합성 픽스처로
#   고정한다(콜드리뷰 M2)** — 세 라운드 연속 실 데이터 grep 에 픽스처 본체를 결합했다가 그 실
#   backlog 가 done 처리(=인덱스에서 사라짐)되며 자기무효화가 났다(실측: ratelimit-… 은 `[진행]` P1
#   이라 완료되는 순간 DUP 풀이 0 이 되어 코드 무관하게 FAIL). **형제는 별도 index 파일에 둔다
#   (콜드리뷰 M1)** — 실 분포가 그렇고(idx_1·idx_11 vs idx_6), 한 파일에 같이 두면 그 파일 자체가
#   changed=True(target 제거) 로 끝나 sibling 신호가 파일 단위 상태에서 가려진다(직전 라운드의 High
#   가 이렇게 초록으로 통과했다).
J12_SLUG="j12syntheticdup"
J12_DATE_TARGET="2026-07-30"
J12_DATE_SIBLING="2026-07-29"
mkdir -p "$FH/.claude/projects/projJ12Target/memory" "$FH/.claude/projects/projJ12Sibling/memory"
cat > "$FH/.claude/projects/projJ12Target/memory/MEMORY.md" <<EOF
# Memory
## Backlog
- [${J12_SLUG}](../../../docs/working/backlog/${J12_DATE_TARGET}-${J12_SLUG}.md) — target entry, done 처리 대상
EOF
cat > "$FH/.claude/projects/projJ12Sibling/memory/MEMORY.md" <<EOF
# Memory
## Backlog
- [${J12_SLUG}](../../../docs/working/backlog/${J12_DATE_SIBLING}-${J12_SLUG}.md) — sibling entry, 다른 파일·다른 날짜, 생존해야 함
EOF
MEM_J12_TARGET="$FH/.claude/projects/projJ12Target/memory/MEMORY.md"
MEM_J12_SIBLING="$FH/.claude/projects/projJ12Sibling/memory/MEMORY.md"
# sibling 본문 파일도 만든다(2026-08-07 콜드리뷰 M3 재정정) — sibling 판정이 "그 날짜에 실제 파일이
# 있는가" 를 근거로 검증하도록 바뀌어서(J-14 와의 상태 충돌 해소), 파일이 없으면 이 라인도 noref 로
# 떨어진다. pending 상태로 둬 자기 자신은 이번 실행에서 처리되지 않게 한다.
printf -- '---\nname: %s\nmetadata:\n  status: pending\n  product: testprod\n---\nsibling body, still pending\n' "$J12_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12_DATE_SIBLING}-${J12_SLUG}.md"
printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$J12_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12_DATE_TARGET}-${J12_SLUG}.md"
backlog_payload "$FH/.claude/docs/working/backlog/${J12_DATE_TARGET}-${J12_SLUG}.md"
# BACKLOG_INDEX_LOCK 명시(2026-08-07 콜드리뷰 R3 L1) — 이미 §J 최상단(`export BACKLOG_INDEX_LOCK=
# "$TMP/bl.lock.d"`, :485)이 자식 프로세스로 상속돼 실측상 이미 이 경로를 쓴다(락 경합 강제 재현으로
# 확인 — 기본 공유 경로가 아니라 `$TMP/bl.lock.d` 타임아웃이 정확히 찍힘). 그래도 향후 리팩터(함수화
# 등)로 export 스코프가 깨질 가능성에 대비해 인라인으로도 명시한다(방어적, 현재는 no-op).
J12_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if ! grep -qF "backlog/${J12_DATE_TARGET}-${J12_SLUG}.md" "$MEM_J12_TARGET"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12a] 처리 대상 entry 가 제거되지 않음"); fi
if grep -qF "backlog/${J12_DATE_SIBLING}-${J12_SLUG}.md" "$MEM_J12_SIBLING"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12b] 별도 파일의 형제(다른 날짜) entry 가 함께 삭제됨(S1 회귀)"); fi
# J-12c~f(High) — 형제가 살아남는 것만으로는 부족하다. "href 를 정정하라" 로 잘못 안내되고(정정하면
# 형제가 방금 이동된 파일을 가리키게 되어 데이터 손실이 재현된다) △(인덱스 미정리) 로 오보고되는
# 것까지 잡아야 High 가 실제로 닫힌다.
if echo "$J12_OUT" | grep -qF '형제 backlog entry'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12c] sibling 전용 메시지가 안 뜸(noref 오분류 가능성, High 회귀) — 출력: $J12_OUT"); fi
if ! echo "$J12_OUT" | grep -qF 'href 를 신 경로로 정정 필요'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12d] 형제 라인이 noref(정정 필요) 로 오분류됨(High 회귀 — 정정 유도 시 데이터 손실 재현) — 출력: $J12_OUT"); fi
if echo "$J12_OUT" | grep -qF '✓ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12e] 인덱스가 정확히 정리됐는데 ✓ 대신 다른 마커가 뜸(High 회귀) — 출력: $J12_OUT"); fi
if ! echo "$J12_OUT" | grep -qF '△ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12f] 형제 보존인데 △(인덱스 미정리) 로 오보고됨(High 회귀) — 출력: $J12_OUT"); fi

# J-12-landmark(콜드리뷰 M2, R2 M6 재정정 — 술어를 인덱스가 아닌 본문 파일로 변경) — "형태를 합성
#   픽스처로 고정하고, 실 데이터에 대해서는 그 형태가 아직 존재하는가 만 별도로 단언하라." 위 J-12
#   본체는 실 데이터와 완전히 독립이라 실 backlog 가 resolve 돼도 절대 무효화되지 않는다.
#   **술어를 인덱스 href 가 아니라 `docs/working/backlog/` 본문 파일명으로 바꾼다(R2 M6)** — 이전
#   버전은 "인덱스에 같은 slug 2 날짜" 를 찾았는데, sibling 이 실제로 발화하는 라이브 3쌍(tick-claim-
#   slug-collision·mod15-multidevice-token-track·p0-runtime-security-deploy) 은 인덱스엔 최신 날짜
#   1개만 남아있어(구 날짜 entry 는 이미 정리됨) 이 술어로는 안 잡힌다. 게다가 유일하게 통과시키던
#   ratelimit-… 항목도 BE 측 링크 텍스트가 34자 절단(`[ratelimit-double-count-explicit-ro]`)돼 있어
#   marker 불일치로 sibling 분기를 아예 안 탄다 — 랜드마크가 "형태가 존재한다" 고 보고해도 정작 그
#   형태가 sibling 분기를 발화시키는지는 별개였다. **진짜 필요한 관찰 대상은 sibling 판정의 전제
#   그 자체 — `docs/working/backlog/` 에 같은 slug 가 날짜만 다르게 2개 이상 실재하는가**(현재 4건:
#   위 3쌍 + ratelimit) 이다. 이걸로 바꾸면 인덱스 표기(절단·최신화 여부)와 무관하게 관찰된다.
#   **이 항목이 미래에 FAIL 하는 건 실 dup 쌍이 전부 해소됐다는 뜻이라 오히려 좋은 신호이지 코드
#   회귀가 아니다**(위 핵심 회귀 검증 J-12a~f 와 분리돼 있어 그 실패가 스위트 전체를 무효화하지 않는다).
J12_LANDMARK_HOME_WIN=$(to_win_test "$HOME/.claude")
J12_LANDMARK=$(python3 - "$J12_LANDMARK_HOME_WIN" <<'PYEOF'
import re, os, sys
home = sys.argv[1]
backlog_dir = os.path.join(home, "docs", "working", "backlog")
by_slug = {}
if os.path.isdir(backlog_dir):
    for f in os.listdir(backlog_dir):
        m = re.match(r'^(\d{4}-\d{2}-\d{2})-(.+)\.md$', f)
        if m:
            by_slug.setdefault(m.group(2), set()).add(m.group(1))
found = any(len(dates) >= 2 for dates in by_slug.values())
print("FOUND" if found else "NONE")
PYEOF
)
# FAIL 이 아니라 SKIP(2026-08-07 콜드리뷰 R3 M6) — 이 술어가 잡는 4쌍은 ① 중복 slug rename 으로
# 해소되거나 ② 그냥 그 중 하나가 done 처리되는 **정상 수명주기**만으로도 카운트가 0 이 될 수 있다.
# 둘 다 코드 회귀가 아닌데 FAIL 로 세면 "건강한 상태에서 스위트가 red 가 된다" — 바로 그 자기무효화가
# 형태만 바뀌어 재발한 것이다(이전엔 FAIL 로 세면서 주석에 "이건 좋은 신호" 라고 자인했다 — 좋은
# 신호인데 스위트를 red 로 만드는 건 모순). PASS/SKIP 두 값만 쓴다(핵심 회귀 테스트 J-12a~f 는 이와
# 무관하게 항상 유효하므로 SKIP 이 스위트 신뢰도를 낮추지 않는다).
if [ "$J12_LANDMARK" = "FOUND" ]; then PASS=$((PASS+1)); else SKIP=$((SKIP+1)); skip_lines+=("[J-12 landmark] 실 dup slug 쌍이 라이브 데이터에 없어 미검증(데이터 부재 — 코드 회귀 아님)"); fi

# J-12g. M1(2026-08-07 콜드리뷰 R3) — `sibling_re.search()` 는 첫 매치만 본다. 한 라인에 같은 slug 의
#   다른 날짜 href 가 2개 있고 첫 번째 파일이 없고 두 번째가 있으면 noref 로 잘못 떨어진다(R1 High 가
#   지목한 오안내 재발). **되돌리면(search 로 되돌리면) 이 테스트가 FAIL 해야 한다** — 합성 픽스처라
#   실 데이터 변화와 무관하게 항상 유효하다.
J12G_SLUG="j12gfinditer"
J12G_TARGET_DATE="2026-07-30"
J12G_NOFILE_DATE="2026-01-01"
J12G_HASFILE_DATE="2026-07-29"
mkdir -p "$FH/.claude/projects/projJ12g/memory"
cat > "$FH/.claude/projects/projJ12g/memory/MEMORY.md" <<EOF
# Memory
## Backlog
- [${J12G_SLUG}](../../../docs/working/backlog/${J12G_NOFILE_DATE}-${J12G_SLUG}.md)·[${J12G_SLUG}](../../../docs/working/backlog/${J12G_HASFILE_DATE}-${J12G_SLUG}.md) — multi-href line, first date has no file, second does
EOF
MEM_J12G="$FH/.claude/projects/projJ12g/memory/MEMORY.md"
# ${J12G_NOFILE_DATE}-${J12G_SLUG}.md 는 만들지 않는다(그 날짜엔 파일이 없어야 함) — 두 번째 날짜만 실재시킨다.
printf -- '---\nname: %s\nmetadata:\n  status: pending\n  product: testprod\n---\nsibling body\n' "$J12G_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12G_HASFILE_DATE}-${J12G_SLUG}.md"
printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$J12G_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12G_TARGET_DATE}-${J12G_SLUG}.md"
backlog_payload "$FH/.claude/docs/working/backlog/${J12G_TARGET_DATE}-${J12G_SLUG}.md"
J12G_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if grep -qF "$J12G_HASFILE_DATE" "$MEM_J12G"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12g-a] 멀티href 라인 자체가 사라짐(오삭제) — 출력: $J12G_OUT"); fi
if echo "$J12G_OUT" | grep -qF '형제 backlog entry'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12g-b] 두번째 매치(파일 실재)를 못 찾고 noref 로 떨어짐(M1 회귀 — search 의 첫 매치만 보는 버그 재발) — 출력: $J12G_OUT"); fi
if ! echo "$J12G_OUT" | grep -qF 'href 를 신 경로로 정정 필요'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12g-c] noref(정정 필요) 오안내가 뜸(M1 회귀) — 출력: $J12G_OUT"); fi

# J-12h. M2(2026-08-07 콜드리뷰 R3) — sibling 이 `any_found` 를 세우면, "자기 entry 는 인덱스 어디에도
#   없고 형제만 있는" 실제 시나리오(실측: mod15-multidevice-token-track 07-22 / tick-claim-slug-
#   collision 07-27, 둘 다 인덱스엔 최신 날짜 entry 만 남아있음)에서 미발견 경고가 조용히 삼켜지고
#   ✓ 로 오보고된다. 이 실 시나리오를 그대로 합성 픽스처로 고정한다 — **되돌리면(sibling 도 any_found
#   를 세우게 하면) 이 테스트가 FAIL 해야 한다.**
J12H_SLUG="j12hselfmissing"
J12H_TARGET_DATE="2026-07-22"
J12H_SIBLING_DATE="2026-07-27"
mkdir -p "$FH/.claude/projects/projJ12hSibling/memory"
cat > "$FH/.claude/projects/projJ12hSibling/memory/MEMORY.md" <<EOF
# Memory
## Backlog
- [${J12H_SLUG}](../../../docs/working/backlog/${J12H_SIBLING_DATE}-${J12H_SLUG}.md) — 이 slug 를 참조하는 유일한 인덱스 entry(자기 날짜 entry 는 어디에도 없음)
EOF
printf -- '---\nname: %s\nmetadata:\n  status: pending\n  product: testprod\n---\nsibling body\n' "$J12H_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12H_SIBLING_DATE}-${J12H_SLUG}.md"
printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$J12H_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12H_TARGET_DATE}-${J12H_SLUG}.md"
backlog_payload "$FH/.claude/docs/working/backlog/${J12H_TARGET_DATE}-${J12H_SLUG}.md"
J12H_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ ! -f "$FH/.claude/docs/working/backlog/${J12H_TARGET_DATE}-${J12H_SLUG}.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12h-a] 자기 entry 못 찾는 케이스인데 파일이 이동 안 됨(mv 는 인덱스 상태 무관하게 일어나야 함)"); fi
if echo "$J12H_OUT" | grep -qF '미발견'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12h-b] 자기 entry 가 어디에도 없는데 '미발견' 경고가 안 뜸(M2 회귀 — sibling 이 any_found 를 조용히 세움) — 출력: $J12H_OUT"); fi
if echo "$J12H_OUT" | grep -qF '△ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12h-c] 자기 entry 미발견인데 △ 대신 다른 마커가 뜸(M2 회귀) — 출력: $J12H_OUT"); fi
if ! echo "$J12H_OUT" | grep -qF '✓ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12h-d] 자기 entry 미발견인데 조용히 ✓ 로 보고됨(M2 회귀, High 가 막으려던 바로 그 오보고) — 출력: $J12H_OUT"); fi
if echo "$J12H_OUT" | grep -qF '형제 backlog entry'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12h-e] 형제 entry 발견 메시지가 안 뜸 — 출력: $J12H_OUT"); fi

# J-12i. M8(2026-08-07 콜드리뷰 R3) — 자기 entry 와 형제 entry 가 **같은 index 파일의 다른 줄**에
#   있으면(가장 흔한 실제 경로 — 자기 entry 는 지워지고 형제는 같은 파일에 남는다) 그 파일의 최종
#   status 가 "removed" 로만 찍혀 sibling 보고가 사라졌었다(elif 배타값). **되돌리면(sibling 을 다시
#   배타 status 로 만들면) 이 테스트가 FAIL 해야 한다.**
J12I_SLUG="j12isamefile"
J12I_TARGET_DATE="2026-07-30"
J12I_SIBLING_DATE="2026-07-29"
mkdir -p "$FH/.claude/projects/projJ12i/memory"
cat > "$FH/.claude/projects/projJ12i/memory/MEMORY.md" <<EOF
# Memory
## Backlog
- [${J12I_SLUG}](../../../docs/working/backlog/${J12I_TARGET_DATE}-${J12I_SLUG}.md) — target entry, same file
- [${J12I_SLUG}](../../../docs/working/backlog/${J12I_SIBLING_DATE}-${J12I_SLUG}.md) — sibling entry, same file, different line
EOF
MEM_J12I="$FH/.claude/projects/projJ12i/memory/MEMORY.md"
printf -- '---\nname: %s\nmetadata:\n  status: pending\n  product: testprod\n---\nsibling body\n' "$J12I_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12I_SIBLING_DATE}-${J12I_SLUG}.md"
printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$J12I_SLUG" \
  > "$FH/.claude/docs/working/backlog/${J12I_TARGET_DATE}-${J12I_SLUG}.md"
backlog_payload "$FH/.claude/docs/working/backlog/${J12I_TARGET_DATE}-${J12I_SLUG}.md"
J12I_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if ! grep -qF "$J12I_TARGET_DATE-$J12I_SLUG" "$MEM_J12I"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12i-a] 같은 파일 안 target entry 가 제거되지 않음"); fi
if grep -qF "$J12I_SIBLING_DATE-$J12I_SLUG" "$MEM_J12I"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12i-b] 같은 파일 안 sibling entry 가 함께 삭제됨"); fi
if echo "$J12I_OUT" | grep -qF '형제 backlog entry'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-12i-c] 같은 파일의 다른 줄에 형제가 남았는데 보고가 안 됨(M8 회귀 — sibling 이 배타 status 라 removed 에 가려짐) — 출력: $J12I_OUT"); fi

# J-13. 통제군(2026-08-07 콜드리뷰 M4) — `--{product}` suffix 쌍은 slug 문자열 자체가 완전히 다르므로
#   **S1(날짜 와일드카드→정확 매칭) 을 되돌려도 이 테스트는 계속 PASS 한다(실측, S1 회귀 검출력 0)**.
#   이 테스트가 실제로 확인하는 건 "같은 날짜라도 slug(suffix 포함) 가 다르면 정확히 분리 매칭되는가"
#   (기존 slug 유일성 매칭의 정상 동작)뿐이다 — S1 회귀 가드로 오인하지 말 것. 형태도 합성으로
#   고정한다(콜드리뷰 M2, J-12 와 동일 사유).
J13_BASE="j13syntheticbase"
J13_DATE="2026-07-30"
J13_SLUG_A="${J13_BASE}--producta"
J13_SLUG_B="${J13_BASE}--productb"
mkdir -p "$FH/.claude/projects/projJ13Target/memory" "$FH/.claude/projects/projJ13Sibling/memory"
cat > "$FH/.claude/projects/projJ13Target/memory/MEMORY.md" <<EOF
# Memory
## Backlog
- [${J13_SLUG_A}](../../../docs/working/backlog/${J13_DATE}-${J13_SLUG_A}.md) — target entry, done 처리 대상
EOF
cat > "$FH/.claude/projects/projJ13Sibling/memory/MEMORY.md" <<EOF
# Memory
## Backlog
- [${J13_SLUG_B}](../../../docs/working/backlog/${J13_DATE}-${J13_SLUG_B}.md) — 같은 날짜·다른 suffix, 생존해야 함
EOF
MEM_J13_TARGET="$FH/.claude/projects/projJ13Target/memory/MEMORY.md"
MEM_J13_SIBLING="$FH/.claude/projects/projJ13Sibling/memory/MEMORY.md"
printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$J13_SLUG_A" \
  > "$FH/.claude/docs/working/backlog/${J13_DATE}-${J13_SLUG_A}.md"
backlog_payload "$FH/.claude/docs/working/backlog/${J13_DATE}-${J13_SLUG_A}.md"
J13_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if ! grep -qF "backlog/${J13_DATE}-${J13_SLUG_A}.md" "$MEM_J13_TARGET"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-13a] 처리 대상 entry 가 제거되지 않음"); fi
if grep -qF "backlog/${J13_DATE}-${J13_SLUG_B}.md" "$MEM_J13_SIBLING"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-13b] 같은 날짜·다른 suffix 형제 entry 가 함께 삭제됨"); fi

# J-13-landmark(콜드리뷰 M2, R2 M6 과 동일 사유로 본문 파일 술어로 통일) — SFX 형태 실존 여부만
#   별도 관찰. J-12-landmark 와 같은 이유(인덱스 href 는 절단·최신화로 stale 할 수 있다)로 인덱스가
#   아니라 `docs/working/backlog/` 본문 파일명을 술어로 쓴다.
J13_LANDMARK=$(python3 - "$J12_LANDMARK_HOME_WIN" <<'PYEOF'
import re, os, sys
home = sys.argv[1]
backlog_dir = os.path.join(home, "docs", "working", "backlog")
suffix_re = re.compile(r'^(\d{4}-\d{2}-\d{2})-([A-Za-z0-9_-]+?)--([A-Za-z0-9_-]+)\.md$')
by_base = {}
if os.path.isdir(backlog_dir):
    for f in os.listdir(backlog_dir):
        m = suffix_re.match(f)
        if m:
            date, base, suffix = m.groups()
            by_base.setdefault((date, base), set()).add(suffix)
found = any(len(suffixes) >= 2 for suffixes in by_base.values())
print("FOUND" if found else "NONE")
PYEOF
)
# FAIL 이 아니라 SKIP(콜드리뷰 R3 M6, J-12-landmark 와 동일 사유). **메시지도 갱신(R3 M7)** —
# 이전엔 실패 메시지가 "실 11 인덱스파일에 …" 였는데, M6(R2) 로 술어를 인덱스가 아니라
# `docs/working/backlog/` 본문 파일명 스캔으로 이미 바꿔놨었다 — 조사자를 없는 데이터(인덱스)로
# 보내는 stale 메시지였다. SKIP 은 메시지 없이도 원인이 코드가 아니라 데이터 부재임이 명확하므로
# 별도 fail_lines 자체가 불필요해졌다(SKIP 은 실패 상세에 나열되지 않는다).
if [ "$J13_LANDMARK" = "FOUND" ]; then PASS=$((PASS+1)); else SKIP=$((SKIP+1)); skip_lines+=("[J-13 landmark] docs/working/backlog/ 에 해당 파일명 패턴이 없어 미검증(데이터 부재 — 코드 회귀 아님)"); fi

# J-14. S1 결함면 — 인덱스 href 의 날짜가 실제 파일명 날짜와 어긋나면(수동 편집·이관 오차) 매칭이
#   실패해 entry 가 잔존해야 하고, 그게 조용한 성공(✓)이 아니라 경고(△ + noref stderr)로 나와야 한다.
#   **J-12(sibling) 와의 상태 분리(2026-08-07 콜드리뷰 M3 재정정)** — High 수정으로 sibling 판정이
#   생기면서, 이 케이스도 텍스트만 보면 "다른 날짜의 backlog href 가 있다" 는 sibling 과 똑같은 모양이
#   된다. 다른 점은 **08-01 날짜의 파일이 실재하지 않는다** 는 것 — sibling_re 매칭에 파일 실재
#   검증을 추가해(backlog-lifecycle.sh) 이 케이스는 여전히 noref 로 남는다. 아래 J-14e 가 noref
#   전용 메시지를 직접 assert 해 sibling 으로 오분류되지 않았음을 고정한다(J-11c 와 동일 이유 — 공용
#   마커 △/✓ 만으론 sibling/noref/manual/removed_partial 4개 분기를 구분 못 한다).
mkdir -p "$FH/.claude/projects/projJ14/memory"
cat > "$FH/.claude/projects/projJ14/memory/MEMORY.md" <<'EOF'
# Memory
## Backlog
- [j14datemismatch](../../../docs/working/backlog/2026-08-01-j14datemismatch.md) — index 날짜(08-01)와 실제 파일명 날짜(08-03)가 어긋남, 08-01 파일은 존재하지 않음
EOF
cat > "$FH/.claude/docs/working/backlog/2026-08-03-j14datemismatch.md" <<'EOF'
---
name: j14datemismatch
metadata:
  status: done
  product: testprod
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-03-j14datemismatch.md"
J14_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
MEM_J14="$FH/.claude/projects/projJ14/memory/MEMORY.md"
if grep -qF 'j14datemismatch' "$MEM_J14"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-14a] 날짜 불일치인데 entry 가 제거됨(엉뚱한 라인 오삭제 가능성)"); fi
if ! echo "$J14_OUT" | grep -qF '✓ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-14b] 날짜 불일치가 조용한 성공(✓)으로 보고됨 — 출력: $J14_OUT"); fi
if echo "$J14_OUT" | grep -qF '△ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-14c] 날짜 불일치인데 △ 경고 마커가 안 뜸 — 출력: $J14_OUT"); fi
if [ ! -f "$FH/.claude/docs/working/backlog/2026-08-03-j14datemismatch.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-14d] 인덱스 미정리와 무관하게 파일 자체는 이동됐어야 함"); fi
if echo "$J14_OUT" | grep -qF 'href 를 신 경로로 정정 필요'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-14e] noref 전용 메시지가 안 뜸(sibling 으로 오분류돼 △ 만 우연히 다른 사유로 떴을 가능성, M3 회귀) — 출력: $J14_OUT"); fi
if ! echo "$J14_OUT" | grep -qF '형제 backlog entry'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-14f] 파일이 실재하지 않는데 sibling(형제 보존) 으로 오분류됨(High 재정정 회귀 — 파일존재 검증 누락)"); fi

# J-15. S2(2026-08-07) — 화이트리스트(유효 문자)는 통과하지만 실재하지 않는 product 값은 유령
#   docs/{product}/ 트리를 만들지 않고 이동을 스킵해야 한다(실측 오염: hongcafe-global-docs 하이픈
#   오표기 등). fallback 으로 claude-harness 에 조용히 합류시키지도 않는다 — 원본 위치에 그대로
#   남아야 사용자가 frontmatter 를 정정할 수 있다.
cat > "$FH/.claude/docs/working/backlog/2026-08-04-j15ghostproduct.md" <<'EOF'
---
name: j15ghostproduct
metadata:
  status: done
  product: ghostproducttest
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-04-j15ghostproduct.md"
J15_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ -f "$FH/.claude/docs/working/backlog/2026-08-04-j15ghostproduct.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-15a] 실재하지 않는 product 인데 파일이 이동됨(유령 트리 생성 가능성) — 출력: $J15_OUT"); fi
if [ ! -d "$FH/.claude/docs/ghostproducttest" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-15b] 유령 product 디렉토리(docs/ghostproducttest)가 새로 생성됨"); fi
# `-name '*j15ghostproduct*'`(2026-08-07 콜드리뷰 R3 M2) — 이전엔 `j15ghostproduct*`(선두 고정)라
# 실제 파일명 `2026-08-04-j15ghostproduct.md` 의 날짜 prefix 때문에 절대 매칭이 안 됐다(검출력 0,
# claude-harness fallback 회귀를 영원히 못 잡는 상태였다 — 예약 가드를 통째로 제거해도 이 assertion
# 은 계속 PASS 했을 것). 부분매칭으로 고친다.
if [ ! -d "$FH/.claude/docs/claude-harness/tasks" ] || ! find "$FH/.claude/docs/claude-harness/tasks" -name '*j15ghostproduct*' 2>/dev/null | grep -q .; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-15c] 유령 product 가 claude-harness 로 조용히 fallback 됨(원 product 정보 소실)"); fi
if echo "$J15_OUT" | grep -qF '실재하지 않음'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-15d] 실재하지 않는 product 경고 stderr 가 없음 — 출력: $J15_OUT"); fi
# J-15e. M6(2026-08-07 콜드리뷰) — "정정 필요" 는 오탈자를 전제한다. docs/{product}/ 는 지연 생성
#   (코드 편집이 있었던 세션에서만 만들어짐)이라, 코드 편집 없이 backlog 부터 만든 신규 repo 는
#   product 값이 맞아도 트리가 아직 없을 수 있다 — 메시지에 두 원인을 모두 남겨야 한다.
if echo "$J15_OUT" | grep -qF '아직 생성되지 않음'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-15e] '아직 생성되지 않음' 대안 설명이 메시지에 없음(M6 회귀, 오탈자로만 오판 유도) — 출력: $J15_OUT"); fi

# J-16. M5(2026-08-07 콜드리뷰) — `~/.claude/docs/` 는 git 추적 밖(gitignore)이라 새 설치·복구
#   환경엔 `docs/claude-harness/` 가 아직 없을 수 있다. 그 상태에서도 product 필드 부재(기본값
#   claude-harness, 40건 실측)로 떨어지는 backlog 는 스킵되면 안 된다 — claude-harness 는 실재
#   검사에서 면제되고 기존 mkdir -p 로직이 자기부트스트랩해야 한다. 공유 $FH 는 §전역 부트스트랩에서
#   이미 docs/claude-harness 를 만들어놔 이 시나리오를 재현 못 하므로 전용 fakehome 을 쓴다.
FH_M5="$TMP/backlog_fakehome_m5"
mkdir -p "$FH_M5/.claude/docs/working/backlog" "$FH_M5/.claude/projects"
cat > "$FH_M5/.claude/docs/working/backlog/2026-08-04-j16noharnessdir.md" <<'EOF'
---
name: j16noharnessdir
metadata:
  status: done
---
x
EOF
backlog_payload "$FH_M5/.claude/docs/working/backlog/2026-08-04-j16noharnessdir.md"
J16_OUT=$(HOME="$FH_M5" BACKLOG_INDEX_LOCK="$TMP/bl-j16.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ ! -f "$FH_M5/.claude/docs/working/backlog/2026-08-04-j16noharnessdir.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-16a] claude-harness 트리 미실재 새 환경에서 product 부재 backlog 가 스킵됨(M5 회귀) — 출력: $J16_OUT"); fi
if compgen -G "$FH_M5/.claude/docs/claude-harness/tasks/*/backlog/2026-08-04-j16noharnessdir.md" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-16b] claude-harness 자기부트스트랩 이동 실패(M5 회귀) — 출력: $J16_OUT"); fi

# J-17. M7(2026-08-07 콜드리뷰, R2 M5 재정정 — 8개 전부 루프) — docs/ 하위 공용 SSOT 예약
#   디렉토리(working/indexing/references/hooks/scripts/share/source_tree/참조문서)는 **실재하더라도**
#   product 값으로 거부돼야 한다. **이전 라운드는 8개 중 `references` 1개만 검증했다** — 하필 유일한
#   비-ASCII 값(`참조문서`)이 "화이트리스트가 예약이름 검사보다 먼저 실행돼 도달 불가"(R2 M3) 결함을
#   갖고 있었는데 그 축을 안 태워 green 으로 통과했다. 8개 전부 루프해 ASCII 7개 + 비-ASCII 1개를
#   같은 방식으로 검증한다. 각 디렉토리를 FH 에도 실재시켜(값 매칭 자체를 검증 — 실재검사가 우연히
#   막는 게 아님을 보장) 검사가 실제로 작동함을 보인다.
J17_RESERVED_NAMES=(working indexing references hooks scripts share source_tree 참조문서)
for J17_NAME in "${J17_RESERVED_NAMES[@]}"; do
  mkdir -p "$FH/.claude/docs/$J17_NAME"
  J17_FILE="2026-08-04-j17reserved-${J17_NAME//[^A-Za-z0-9]/x}.md"
  printf -- '---\nname: j17reserved\nmetadata:\n  status: done\n  product: %s\n---\nx\n' "$J17_NAME" \
    > "$FH/.claude/docs/working/backlog/$J17_FILE"
  backlog_payload "$FH/.claude/docs/working/backlog/$J17_FILE"
  J17_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if [ -f "$FH/.claude/docs/working/backlog/$J17_FILE" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-17-$J17_NAME-a] 예약 이름인데 이동됨(M7 회귀) — 출력: $J17_OUT"); fi
  # `-name '*j17reserved-*'`(2026-08-07 콜드리뷰 R3 M1) — 이전엔 `j17reserved-*`(선두 고정)라 실제
  # 파일명의 날짜 prefix(`2026-08-04-j17reserved-...`) 때문에 절대 매칭이 안 됐다. 실측(예약 가드
  # 통째로 제거): `-a`·`-c` 8건씩 FAIL 하는데 `-b` 는 8건 모두 PASS — "24 assertion" 의 실질이 16
  # 이었다. 부분매칭으로 고쳐 실제 검출력을 갖게 한다.
  # **`$J17_NAME/tasks` 로 한정(자체발견, M1 수정 직후 실행에서 노출)** — `docs/$J17_NAME` 전체를
  # 훑으면 `J17_NAME=working` 일 때 이 백로그 스위트의 SOURCE 디렉토리 자체(`docs/working/backlog/`,
  # 모든 J 테스트 파일이 처리 전 잠깐 머무는 곳)가 걸려 자기 자신의(정상적으로 이동 **안** 된) 원본
  # 파일을 "잘못 써짐" 으로 오탐한다. 잘못 이동됐다면 `{product}/tasks/{date}/backlog/…` 에 떨어지지
  # `{product}/backlog/` 최상위에 남지 않으므로, `tasks` 하위만 본다.
  if ! find "$FH/.claude/docs/$J17_NAME/tasks" -name '*j17reserved-*' 2>/dev/null | grep -q .; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-17-$J17_NAME-b] 예약 SSOT 디렉토리에 backlog 파일이 써짐(M7 회귀)"); fi
  if echo "$J17_OUT" | grep -qF '공용 SSOT 예약'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-17-$J17_NAME-c] 예약 이름 차단 경고가 안 뜸(M7/M3 회귀) — 출력: $J17_OUT"); fi
done

# J-18. H1(2026-08-07 콜드리뷰 R3) — `find "$DOCS_ROOT" -iname "$product"` 가 `-mindepth 1` 없이
#   depth 0(=`$DOCS_ROOT` 자기 자신, basename "docs")까지 매칭한다. `product: docs`(대소문자 무관이라
#   `Docs`/`DOCS` 도)면 `$DOCS_ROOT` 자신이 "실재 확인"을 통과해, 실재하지 않던 `docs/docs/` 트리를
#   만들며 `✓ 이동` 으로 오보고한다. **되돌리면(-mindepth 1 을 빼면) 이 테스트가 FAIL 해야 한다.**
cat > "$FH/.claude/docs/working/backlog/2026-08-05-j18docsroot.md" <<'EOF'
---
name: j18docsroot
metadata:
  status: done
  product: docs
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-05-j18docsroot.md"
J18_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ -f "$FH/.claude/docs/working/backlog/2026-08-05-j18docsroot.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-18a] product=docs 인데 이동됨(H1 회귀 — DOCS_ROOT 자신이 매칭됨) — 출력: $J18_OUT"); fi
if [ ! -d "$FH/.claude/docs/docs" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-18b] docs/docs/ 유령 트리가 생성됨(H1 회귀)"); fi

# J-19. H2(2026-08-07 콜드리뷰 R3) — M4(R2) 가 대소문자 무관 실재검증을 들여오면서, 예약이름 차단이
#   소문자 정확 일치만 보면 `product: Working`/`References`/... 가 예약검사를 통과한 뒤 대소문자
#   무관 실재검증이 실물 소문자 디렉토리로 정규화해 공용 SSOT 안에 써넣는다(M7 이 막던 구멍 재발).
#   **되돌리면(예약검사가 원값 그대로 비교하면) 이 테스트가 FAIL 해야 한다.**
mkdir -p "$FH/.claude/docs/references"
cat > "$FH/.claude/docs/working/backlog/2026-08-05-j19mixedcase.md" <<'EOF'
---
name: j19mixedcase
metadata:
  status: done
  product: References
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-05-j19mixedcase.md"
J19_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ -f "$FH/.claude/docs/working/backlog/2026-08-05-j19mixedcase.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-19a] product=References(대소문자 변형) 인데 이동됨(H2 회귀) — 출력: $J19_OUT"); fi
if ! find "$FH/.claude/docs/references" -name '*j19mixedcase*' 2>/dev/null | grep -q .; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-19b] 예약 SSOT 디렉토리(references)에 대소문자 변형 값으로 파일이 써짐(H2 회귀)"); fi
if echo "$J19_OUT" | grep -qF '공용 SSOT 예약'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-19c] 대소문자 변형 예약이름 차단 경고가 안 뜸(H2 회귀) — 출력: $J19_OUT"); fi

# J-20. M10(2026-08-07 콜드리뷰 R3) — 대소문자 무관 매칭이 2건 이상이면(대소문자 구분 파일시스템에서
#   `docs/TestProd`·`docs/testprod` 공존) 임의 선택 대신 경고 후 스킵해야 한다. 별도로, 대소문자 무관
#   매칭이 여러 개라도 그중 하나가 `$product` 와 완전히 같은 문자열이면(정확 일치) 모호하지 않아야
#   한다는 것도 확인한다(exact-match 우선).
#
#   **fixture 정정(2026-08-10 H2).** 이전 fixture 는 `j20lower` + `J20Upper` 를 만들었는데 이 둘은
#   서로 대소문자 변형이 아니다(소문자화하면 `j20lower` vs `j20upper`). `find -iname 'j20lower'` 는
#   **대소문자 구분 파일시스템에서도 항상 1건**이라 아래 가드가 모든 플랫폼에서 무조건 참이었다 —
#   NTFS 한계가 아니라 fixture 버그였고, 그 결과 `match_count -gt 1` 분기 전체(모호 경고 + exact-match
#   우선)가 **검증 0** 인 채 "환경 한계 SKIP" 으로 위장됐다. `J20Lower` 로 고쳐 진짜 변형을 만든다.
#   이제 대소문자 구분 FS 에서는 2건이 되어 분기가 실제로 돌고, NTFS 에서만 1건으로 합쳐져 SKIP 된다
#   (NTFS 에서는 이 코드 경로 자체가 도달 불가이므로 인위적 주입으로 태우지 않는다).
mkdir -p "$FH/.claude/docs/j20lower" "$FH/.claude/docs/J20Lower"
J20_DISTINCT=$(find -L "$FH/.claude/docs" -mindepth 1 -maxdepth 1 -iname 'j20lower' -type d 2>/dev/null | grep -c .)
if [ "$J20_DISTINCT" -lt 2 ]; then
  SKIP=$((SKIP+1))
  skip_lines+=("[J-20] 대소문자 무관 매칭 2건 공존을 이 파일시스템에서 만들 수 없어 미검증(대소문자 무구분 FS = 이 코드 경로 도달 불가). 대소문자 구분 FS 에서 실행 시 검증됨 — 실측 매칭 ${J20_DISTINCT}건")
else
  cat > "$FH/.claude/docs/working/backlog/2026-08-05-j20tiebreak.md" <<'EOF'
---
name: j20tiebreak
metadata:
  status: done
  product: J20LOWER
---
x
EOF
  backlog_payload "$FH/.claude/docs/working/backlog/2026-08-05-j20tiebreak.md"
  J20_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if [ -f "$FH/.claude/docs/working/backlog/2026-08-05-j20tiebreak.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-20a] 대소문자 무관 매칭 2건 이상인데 임의 선택되어 이동됨(M10 회귀) — 출력: $J20_OUT"); fi
  if echo "$J20_OUT" | grep -qF '2건 이상'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-20b] 대소문자 무관 매칭 2건 이상 경고가 안 뜸(M10 회귀) — 출력: $J20_OUT"); fi
  # J-20c. exact-match 우선(같은 fixture 재사용) — 2건이 실재하는 이 환경에서, product 값이 그중
  # 하나와 문자열까지 완전히 같으면(대소문자 무관 매칭이 2건이어도) 모호하지 않게 그 후보로 결정적
  # 이동돼야 한다(경고 없이).
  cat > "$FH/.claude/docs/working/backlog/2026-08-05-j20exact.md" <<'EOF'
---
name: j20exact
metadata:
  status: done
  product: j20lower
---
x
EOF
  backlog_payload "$FH/.claude/docs/working/backlog/2026-08-05-j20exact.md"
  J20C_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if [ ! -f "$FH/.claude/docs/working/backlog/2026-08-05-j20exact.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-20c] 후보 2건 중 정확 일치가 있는데도 모호 판정(스킵)됨(M10 exact-match 우선 회귀) — 출력: $J20C_OUT"); fi
  if find "$FH/.claude/docs/j20lower" -name '*j20exact*' 2>/dev/null | grep -q .; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-20d] 정확 일치 후보(j20lower)로 이동되지 않음(M10 exact-match 우선 회귀) — 출력: $J20C_OUT"); fi
fi
# 단일 매칭 상황에서의 정규화(원 M4 시나리오)는 J-15/16 등 기존 테스트가 이미 고정하고 있어 별도
# fixture 를 여기 추가하지 않는다(중복 방지) — J-20 은 오직 "2건 이상 공존" 축만 담당한다.

# J-22. M11(2026-08-07 콜드리뷰 R3) — `find -type d`(`-L` 없음) 는 lstat 기준이라 dir 심링크에
#   거짓을 반환한다. `docs/{product}` 를 심링크로 둔 환경에서 정상 product 를 영구 스킵시킬 수 있다.
#   **이 환경(Git Bash/Windows)에서 `ln -s` 로 만든 디렉토리 심링크가 실제로 `find -type d`(비-`-L`)
#   에서 거짓을 내는지 먼저 실측한다** — 재현 안 되면(이 플랫폼의 심링크 구현이 POSIX lstat 의미론과
#   다르면) 코드 결함이 아니라 환경 한계이므로 SKIP(거짓 PASS 방지).
#
#   **junction fallback(2026-08-10 M2).** 이전엔 `ln -s` 하나만 시도하고 실패하면 "환경 한계" 로
#   SKIP 했는데, 그 정당화가 사실과 달랐다. MSYS 기본 설정의 `ln -s` 는 디렉토리를 **복사**해서
#   `find -type d` 가 1건을 내지만(재현 실패), `cmd //c mklink //J`(junction, 관리자 권한 불요)는
#   이 환경에서 그대로 재현된다 — 실측: junction 에 대해 `find -type d` = **0건** / `find -L -type d`
#   = **1건**, 정확히 M11 시나리오다. 재현 가능한 fixture 를 만들 수 있는데 만들지 않아 M11 회귀가
#   무방비였다. `ln -s` 가 심링크를 못 만들면 junction 으로 승격해 분기를 실제로 태운다.
mkdir -p "$FH/.claude/docs/j22realtarget"
ln -s "$FH/.claude/docs/j22realtarget" "$FH/.claude/docs/j22symlinked" 2>/dev/null
J22_NOFOLLOW=$(find "$FH/.claude/docs" -mindepth 1 -maxdepth 1 -iname 'j22symlinked' -type d 2>/dev/null | grep -c .)
if [ "$J22_NOFOLLOW" -ge 1 ] && command -v cygpath >/dev/null 2>&1; then
  # ln -s 가 복사본을 만든 상태 — 걷어내고 junction 으로 재시도
  rm -rf "$FH/.claude/docs/j22symlinked" 2>/dev/null
  cmd //c mklink //J "$(cygpath -w "$FH/.claude/docs/j22symlinked")" "$(cygpath -w "$FH/.claude/docs/j22realtarget")" >/dev/null 2>&1
  J22_NOFOLLOW=$(find "$FH/.claude/docs" -mindepth 1 -maxdepth 1 -iname 'j22symlinked' -type d 2>/dev/null | grep -c .)
fi
if [ "$J22_NOFOLLOW" -ge 1 ]; then
  SKIP=$((SKIP+1))
  skip_lines+=("[J-22] dir 심링크/junction 을 이 환경에서 만들 수 없어 미검증(ln -s 는 복사본, junction 도 실패) — M11(find -type d 가 -L 없이 심링크 거짓 판정) 회귀가 무방비")
else
  cat > "$FH/.claude/docs/working/backlog/2026-08-05-j22symlinktest.md" <<'EOF'
---
name: j22symlinktest
metadata:
  status: done
  product: j22symlinked
---
x
EOF
  backlog_payload "$FH/.claude/docs/working/backlog/2026-08-05-j22symlinktest.md"
  J22_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if [ ! -f "$FH/.claude/docs/working/backlog/2026-08-05-j22symlinktest.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-22] 심링크 product 디렉토리가 영구 스킵됨(M11 회귀 — find -type d 가 -L 없이 심링크를 거짓 판정) — 출력: $J22_OUT"); fi
fi

# J-23. M1(2026-08-08 콜드리뷰 R4, [보안]) — R3 M9 가 실패할 수 없던 인라인 `case` 를 실패 가능한 lib
# 의존으로 바꿨다. `source … || true` + `is_reserved_docs_name … 2>/dev/null` 조합이라 lib 이 없거나
# 못 읽히면 127 이 억제된 채 false 로 평가돼 예약이름 가드가 통째로 사라진다. 실측(lib 만 rename):
# `product: references` 인 done backlog 가 경고 한 줄 없이 `docs/references/tasks/{date}/backlog/` 에
# 써지고 `△ 이동` 으로 성공 보고됐다(본문 + summary.md + history.md 3건 유출). 화이트리스트는 ASCII
# 예약 7개를 전부 통과시키므로 2차 방어가 없다 — 가드를 못 세우면 아무것도 하지 않아야 한다.
J23_HOOKS="$TMP/hooks-nolib"
cp -r "$HOOKS_DIR" "$J23_HOOKS"
mv "$J23_HOOKS/lib/product-resolver.sh" "$J23_HOOKS/lib/product-resolver.sh.disabled"
cat > "$FH/.claude/docs/working/backlog/2026-08-05-j23nolib.md" <<'EOF'
---
name: j23nolib
metadata:
  status: done
  product: references
---
x
EOF
backlog_payload "$FH/.claude/docs/working/backlog/2026-08-05-j23nolib.md"
J23_OUT=$(HOME="$FH" BACKLOG_INDEX_LOCK="$TMP/bl.lock.d" bash "$J23_HOOKS/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
if [ -f "$FH/.claude/docs/working/backlog/2026-08-05-j23nolib.md" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-23a] lib 부재인데 이동됨(M1 회귀 — 예약가드 fail-open) — 출력: $J23_OUT"); fi
if ! find "$FH/.claude/docs/references" -name '*j23nolib*' 2>/dev/null | grep -q .; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-23b] lib 부재 시 예약 SSOT 디렉토리(references)에 파일이 써짐(M1 회귀)"); fi
if echo "$J23_OUT" | grep -qF 'fail-closed'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-23c] lib 부재 경고(fail-closed)가 안 뜸 — 침묵 fail-open(M1 회귀) — 출력: $J23_OUT"); fi

# ═══════════════════════════════════════════════════════════════════
printf '\n────────────────────────────────────────\n'
if [ ${#fail_lines[@]} -gt 0 ]; then
  printf 'FAIL 상세:\n'
  for l in "${fail_lines[@]}"; do printf '  - %s\n' "$l"; done
fi
# SKIP 상세(2026-08-10 M4) — 무엇이 검증되지 않았는지 읽을 수 있어야 한다. SKIP 은 스위트를 red 로
# 만들지 않지만, 라벨 없이 숫자만 늘면 환경 한계와 데이터 부재가 구분되지 않는다.
if [ ${#skip_lines[@]} -gt 0 ]; then
  printf 'SKIP 상세(미검증 항목):\n'
  for l in "${skip_lines[@]}"; do printf '  - %s\n' "$l"; done
fi
printf 'PASS=%d  FAIL=%d  SKIP=%d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
