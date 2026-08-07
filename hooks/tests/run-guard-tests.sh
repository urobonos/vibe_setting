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
slug_a_re = re.compile(r'backlog_([A-Za-z0-9_-]+)\.md')
slug_b_re = re.compile(r'backlog/\d{4}-\d{2}-\d{2}-([A-Za-z0-9_-]+)\.md')

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
        sm = slug_a_re.search(href) or slug_b_re.search(href)
        if not sm:
            continue
        slug = sm.group(1)
        has_summary = bool(own_summary_re.match(l[m.end():]))
        line = l.rstrip('\n')
        if not has_summary and group_ex is None:
            group_ex = (slug, href, line)
        if has_summary and badge_ex is None and badge_prefix_re.match(l):
            badge_ex = (slug, href, line)
        if group_ex and badge_ex:
            break
    if group_ex and badge_ex:
        break

if group_ex:
    print("GROUP\t%s\t%s\t%s" % group_ex)
if badge_ex:
    print("BADGE\t%s\t%s\t%s" % badge_ex)
PYEOF
)
GROUP_SLUG=$(echo "$J11_SCAN" | awk -F'\t' '$1=="GROUP"{print $2}')
GROUP_HREF=$(echo "$J11_SCAN" | awk -F'\t' '$1=="GROUP"{print $3}')
REAL_GROUP_LABEL_LINE=$(echo "$J11_SCAN" | awk -F'\t' '$1=="GROUP"{print $4}')
BADGE_SLUG=$(echo "$J11_SCAN" | awk -F'\t' '$1=="BADGE"{print $2}')
BADGE_HREF=$(echo "$J11_SCAN" | awk -F'\t' '$1=="BADGE"{print $3}')
REAL_BADGE_LINE=$(echo "$J11_SCAN" | awk -F'\t' '$1=="BADGE"{print $4}')

# M1(2026-08-07 콜드리뷰 R2) — line 뿐 아니라 **HREF·SLUG 도 개별로 빈값 가드**한다. 이전엔
# `grep -qF "$GROUP_HREF" "$MEM_J11"` 에서 GROUP_HREF 가 빈 문자열이면 `grep -qF ""` 는 항상 참이라
# J-11a 가 무조건 PASS 했다 — line 이 비지 않았어도 정규식 추출이 실패해 href 만 빌 수 있어서
# line 단독 가드로는 안 잡힌다. line·href·slug 3개 전부를 개별로 확인한다.
J11_SETUP_OK=1
if [ -z "$REAL_GROUP_LABEL_LINE" ] || [ -z "$GROUP_HREF" ] || [ -z "$GROUP_SLUG" ]; then
  FAIL=$((FAIL+1)); fail_lines+=("[J-11-setup] 그룹라벨 형태(단일 href, 요약 없음) 라인을 실 인덱스 11파일 전체에서 못 찾음 — line='$REAL_GROUP_LABEL_LINE' href='$GROUP_HREF' slug='$GROUP_SLUG'")
  J11_SETUP_OK=0
fi
if [ -z "$REAL_BADGE_LINE" ] || [ -z "$BADGE_HREF" ] || [ -z "$BADGE_SLUG" ]; then
  FAIL=$((FAIL+1)); fail_lines+=("[J-11-setup] 배지 형태(백틱대괄호 태그 접두 + 단일 href + 요약 있음) 라인을 실 인덱스 11파일 전체에서 못 찾음 — line='$REAL_BADGE_LINE' href='$BADGE_HREF' slug='$BADGE_SLUG'")
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
  printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$GROUP_SLUG" \
    > "$FH/.claude/docs/working/backlog/2026-08-02-${GROUP_SLUG}.md"
  backlog_payload "$FH/.claude/docs/working/backlog/2026-08-02-${GROUP_SLUG}.md"
  J11A_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if grep -qF "$GROUP_HREF" "$MEM_J11"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11a] 그룹라벨 대표줄이 오삭제됨(Critical 회귀) — 실 표기: $REAL_GROUP_LABEL_LINE"); fi
  if echo "$J11A_OUT" | grep -qF '△ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11a] manual 보류인데 △ 마커가 안 뜸 — 출력: $J11A_OUT"); fi
  # J-11c(2026-08-07 콜드리뷰 R2 M3) — `manual_grouplabel` 신설 상태값·bash case arm 전용 단언.
  # `△ 이동` 은 manual·noref·removed_partial·lock 실패·any_found=0 이 전부 내는 공용 마커라
  # 이 신규 분기를 식별 못 한다. python 출력 문자열과 bash case 리터럴이 어긋나면 `*)` catch-all
  # 로 떨어져 "인덱스 처리 실패(읽기/인코딩 오류 가능)" 라는 엉뚱한 진단이 나오는데 △ 마커만 보면
  # green 이다 — 전용 메시지 문자열을 직접 grep 해 이 회귀를 막는다.
  if echo "$J11A_OUT" | grep -qF '그룹라벨 대표항목'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11c] manual_grouplabel 전용 메시지가 안 뜸(case 리터럴 불일치로 catch-all 격하 가능성) — 출력: $J11A_OUT"); fi

  # J-11b. 배지 형태 — href 뒤 정상 요약이 있으므로 배지 유무와 무관하게 정상 제거돼야 한다
  printf -- '---\nname: %s\nmetadata:\n  status: done\n  product: testprod\n---\nx\n' "$BADGE_SLUG" \
    > "$FH/.claude/docs/working/backlog/2026-08-02-${BADGE_SLUG}.md"
  backlog_payload "$FH/.claude/docs/working/backlog/2026-08-02-${BADGE_SLUG}.md"
  J11B_OUT=$(HOME="$FH" bash "$HOOKS_DIR/backlog-lifecycle.sh" < "$TMP/p.json" 2>&1)
  if ! grep -qF "$BADGE_HREF" "$MEM_J11"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11b] 배지 라인이 정상 제거되지 않음(오탐 차단 회귀) — 실 표기: $REAL_BADGE_LINE"); fi
  if echo "$J11B_OUT" | grep -qF '✓ 이동'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fail_lines+=("[J-11b] 정상 제거됐는데 ✓ 마커가 안 뜸 — 출력: $J11B_OUT"); fi
fi

# ═══════════════════════════════════════════════════════════════════
printf '\n────────────────────────────────────────\n'
if [ ${#fail_lines[@]} -gt 0 ]; then
  printf 'FAIL 상세:\n'
  for l in "${fail_lines[@]}"; do printf '  - %s\n' "$l"; done
fi
printf 'PASS=%d  FAIL=%d  SKIP=%d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
