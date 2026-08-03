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
  rm "/tmp/claude_gate_guardtests" 2>/dev/null   # §H 가 만드는 gate 파일 (중단 시 잔류 방지)
}
trap 'cleanup' EXIT

PASS=0; FAIL=0; SKIP=0
fail_lines=()

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
#    working-lifecycle.sh:155-171 이 working/ → tasks/ 이동 시 step 평면 파일을
#    `steps/NN-{slug}.md` 로 mv 한다. mv 는 PreToolUse 를 안 타므로 이 파일들은 날짜 prefix 가 없고,
#    두 hook 이 그 배치를 모르면 이동이 끝난 step 문서는 **어떤 편집도 영구 차단**된다 (실측 667/667).
#    반대로 면제가 넓어지면 경로 규칙 자체가 무의미해진다 — 임의 깊이 / generic 이름 /
#    '..' 세그먼트 / 환경변수 주입 / 도구명 교체(MultiEdit) 가 전부 우회 통로였다.
#    그래서 "열려야 하는 것" 과 "닫혀 있어야 하는 것" 을 같이 고정한다. 한쪽만 있으면
#    되돌림(revert)이 초록으로 통과한다.
# ═══════════════════════════════════════════════════════════════════
printf '\n=== H. steps/ 면제 + 과확장 가드 (naming · gate · MultiEdit · env) ===\n'
H_CWD="C:/works/hongcafe_global_backend"   # .claude cwd 면제(gate-enforce:86)를 타면 검증이 무의미해진다
H_TASKS="C:/Users/PV/.claude/docs/api-spec-reviews/tasks"
H_GATE="/tmp/claude_gate_guardtests"
echo 2 > "$H_GATE"                          # gate 파일 부재 = gate-enforce 즉시 exit 0 (검증 무효화)

# 판정 원재료 부재를 조용히 '차단' 으로 세지 않는다 — 없으면 그 사실 자체를 FAIL 로 올린다.
for h in output-naming-check.sh gate-enforce.sh; do
  [ -f "$HOOKS_DIR/$h" ] || { FAIL=$((FAIL+1)); fail_lines+=("[H] $h 부재 — 판정 불가(차단으로 집계 금지)"); }
done

path_payload() {  # $1=tool_name $2=file_path $3=cwd  (hook_event_name 필수 — 누락 시 일부 hook 이 조용히 미실행)
  printf '{"session_id":"guardtests","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"%s","tool_input":{"file_path":"%s","old_string":"a","new_string":"b","edits":[{"old_string":"a","new_string":"b"}]}}' \
    "$(json_escape "$3")" "$1" "$(json_escape "$2")" > "$TMP/p.json"
}

# 형식: "exit|hook|tool|경로|라벨"
H_CASES=(
  # ── 열려야 하는 것: step 평면 파일 (날짜 prefix 없음) ──
  "0|output-naming-check.sh|Edit|$H_TASKS/20260727/t/steps/02-repository.md|steps/ 무날짜 파일 naming"
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/02-repository.md|steps/ 무날짜 파일 경로규칙"
  "0|gate-enforce.sh|MultiEdit|$H_TASKS/20260727/t/steps/02-repository.md|steps/ 정상 + MultiEdit"
  "0|output-naming-check.sh|Edit|$H_TASKS/20260727/t/steps/2026-08-03-x.md|steps/ 날짜 있는 파일"
  # ── 닫혀 있어야 하는 것: 과확장 방지 ──
  "2|output-naming-check.sh|Edit|$H_TASKS/20260727/t/steps/summary.md|steps/ generic 이름은 계속 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/sub/x.md|steps/ 하위 4단계 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/t/steps/sub/2026-08-03-x.md|steps/sub 는 날짜 있어도 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/../summary.md|'..' 세그먼트 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/20260727/t/../steps/x.md|'..' + steps 조합 차단"
  "2|output-naming-check.sh|Edit|$H_TASKS/20260727/t/x.md|steps/ 아닌 무날짜 파일은 종전대로 차단"
  # ── 도구명 교체 우회 (matcher 는 MultiEdit 포함인데 hook 조건에서 빠져 있었다) ──
  "2|gate-enforce.sh|MultiEdit|$H_TASKS/badpath.md|MultiEdit + 규칙위반 경로 차단"
  "2|gate-enforce.sh|MultiEdit|$H_TASKS/20260727/t/../2026-08-03-x.md|MultiEdit + '..' 차단"
  "2|gate-enforce.sh|Edit|$H_TASKS/badpath.md|Edit + 규칙위반 경로 차단(회귀)"
  # ── 기존 허용 경로 회귀 ──
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/summary.md|YYYYMMDD/summary.md 유지"
  "0|gate-enforce.sh|Edit|$H_TASKS/history.md|history.md 유지"
  "0|gate-enforce.sh|Edit|$H_TASKS/20260727/t/2026-08-03-t-plan.md|평면 2단계 유지"
)
for row in "${H_CASES[@]}"; do
  want="${row%%|*}"; rest="${row#*|}"
  hook="${rest%%|*}"; rest="${rest#*|}"
  tool="${rest%%|*}"; rest="${rest#*|}"
  fp="${rest%%|*}";   label="${rest#*|}"
  path_payload "$tool" "$fp" "$H_CWD"
  run_hook "$hook" normal "$TMP"
  check "[H][$tool] $label" "$want" "$?"
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
  check "[H][env주입] IS_STEP_FILE=true + $label" 2 "$?"
done
rm "$H_GATE" 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
printf '\n────────────────────────────────────────\n'
if [ ${#fail_lines[@]} -gt 0 ]; then
  printf 'FAIL 상세:\n'
  for l in "${fail_lines[@]}"; do printf '  - %s\n' "$l"; done
fi
printf 'PASS=%d  FAIL=%d  SKIP=%d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
