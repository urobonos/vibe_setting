#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "branch-enforce" "enter" "pid=$$"
# PreToolUse:Edit|Write|Bash Hook — push 차단 + master/main 머지 금지 (잔존 영역, 2026-05-20 retire 후)
#
# 정책 (2026-04-30 / 2026-05-07 / 2026-05-13 / 2026-05-20 부분 retire):
#   - §(1) git push 차단 (모든 분기) — 유지
#   - §(1.5) master/main 머지·checkout·switch 절대 금지 — 유지
#   - §(2) Protected 브랜치 자동 강제 + Edit/Write 차단 = **retire (2026-05-20)**
#     → `worktree-enforce.sh` 로 의미 이관 (worktree 항상 강제 + feature 분기 요청 시 생성)
#
# 산출물 SSOT: ~/.claude/docs/claude-harness/tasks/20260520/worktree-always-policy/2026-05-20-worktree-always-policy-unified.md
#             + ~/.claude/docs/claude-harness/output/guide/2026-04-30-branch-workflow/ (구 정책 참조)

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_init
hook_read_stdin

# 현재 브랜치 — git repo 가 아니면 통과
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

# tool_name 추출 (Edit / Write / Bash 분기) — hook_parse_field 3단 백스톱 사용 (2026-07-30)
#   구 코드는 python 단독이라 python 실행이 실패하면(hook 자체 timeout kill·크래시)
#   TOOL_NAME="" 이 되고, L58 `[ "$TOOL_NAME" = "Bash" ]` 가 거짓이 되어 **push 검사 전체를
#   건너뛰고 exit 0** 했다 — §4.3(d) 전면 금지가 조용히 fail-open. 2026-07-30 실증(HOOK_PY
#   주입으로 python 실패 재현 → exit 0).
#   `worktree-enforce.sh` L69-76 은 같은 구멍을 2026-06-16 에 grep 백스톱으로 막았는데 본
#   hook 만 남아 있었다. 백스톱을 여기 복붙하지 않고 lib 함수(bash 정규식 primary → python →
#   grep+sed)로 수렴시켜 drift 를 없앤다.
#   부수 효과: bash 정규식이 primary 라 정상 경로에서 python 起動이 사라진다 (고아 원인 제거).
TOOL_NAME=$(hook_parse_field tool_name)

# ─────────────────────────────────────────────────────────
# 기한부 push 예외 (2026-05-29 사용자 결정 / 전 프로젝트 / ~2026-07-31 자동 만료)
#   출시 전 파이프라인 자동배포 기간 — Claude 가 push + worktree→production 머지 + 배포를 자율 수행 허용.
#   2026-08-01 0시부터 TODAY(YYYYMMDD) > 20260731 → 예외 자동 비활성 → §(1) push 전면 금지 복귀.
#   유지(예외 무관 그대로 차단): force push(dangerous-ops-guard L82) / master·main 머지·checkout(§1.5) /
#     rm -rf / reset --hard / DB 마이그 등 §3 절대 차단. phpunit 그린-before-push 게이트도 정책상 유지.
#   SSOT: 글로벌 CLAUDE.md §4.3 (d) "기한부 push 예외" + C:\Works\hongcafe_global_backend\CLAUDE.md "배포 자동화".
# ─────────────────────────────────────────────────────────
PUSH_EXCEPTION_UNTIL="20260731"
PUSH_EXCEPTION_ACTIVE="0"
_TODAY="$(date +%Y%m%d 2>/dev/null)"
if [ -n "$_TODAY" ] && [ "$_TODAY" -le "$PUSH_EXCEPTION_UNTIL" ]; then
  PUSH_EXCEPTION_ACTIVE="1"
fi

# ─────────────────────────────────────────────────────────
# (1) git push — 모든 분기에서 차단 (자동 원격 push 전면 금지, 2026-05-07 / 2026-05-08 정밀화)
# 매칭: 명령을 ;/&&/|| 로 분리한 각 절을 shlex 토큰화 → 첫 두 토큰이 ['git','push'] 인 절만 차단.
# Why: substring 매칭은 commit 메시지·heredoc 본문·grep 인자 안의 'git push' 문자열까지 false-positive 차단함.
# 2026-05-29~ : PUSH_EXCEPTION_ACTIVE=1 (≤2026-07-31) 이면 차단 스킵 (force push 는 dangerous-ops-guard 가 별도 차단).
# ─────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────
# grep 백스톱 공용부 (2026-08-03) — python 부재·실행실패(GG_ALL 공백) 시에만 쓰인다.
#   §1 push / §1.5 master-merge / §1.6 cherry-pick 이 **같은 절-머리 정의를 공유**한다.
#   (구조상 §1 은 인라인 리터럴, §1.5/§1.6 은 변수로 갈려 있어 한쪽만 고치면 드리프트 — F11)
#
#   판정 기준의 SSOT 는 lib/git-guard.py 다. 아래 목록은 그 파일에서 그대로 옮겨왔다:
#     _KEYWORDS(then·do·else·elif·fi·done·{·}·!) / _WRAP(14종) /
#     _GLOBAL_VAL(-C·-c·--namespace·--git-dir·--work-tree·--config-env·--attr-source) /
#     MASTER_TARGETS(main·master × origin/·upstream/·refs/heads/)
#   git-guard.py 의 목록을 고치면 여기도 같이 고쳐야 한다 (백스톱은 정규식 근사치 — 토큰화가 아니다).
# ─────────────────────────────────────────────────────────

# 절 분리 (awk 1회 — fork 상수). 결과는 `_BE_CLAUSES` 에 1절 1줄로 캐시한다.
#   경계 문자 `; | & ( )` = git-guard.py:48 `_OPS` 와 동일 집합. **괄호를 빼면**
#   `( git merge main )` · `echo $(git push)` 가 절머리에 도달하지 못해 통과한다 (F-B 실측 5형태).
#   `||` `&&` `|&` 는 같은 문자가 2번 치환돼 빈 절이 하나 더 생길 뿐 경계는 동일하다.
#
#   heredoc 은 **본문 구간만** 건너뛴다 (F-C). 구현 초안은 `${COMMAND%%<<*}` 로 첫 `<<` 이후를
#   통째로 버려서 heredoc **뒤에 오는** 절이 3개 백스톱 전부에서 사라졌다
#   (실측: `cat <<EOF … EOF` + `git push origin feature/x` → normal 2 / degraded 0).
#   새 lib 이 개행을 복원해 준 정보를 백스톱이 스스로 버리는 구조였다.
#
#   본문을 건너뛰는 이유 (F5②): 이 레포 표준 커밋은 heredoc 본문에 가드 정책을 서술하는 일이 잦아
#   본문 줄 "git checkout main" 이 절 시작으로 오인된다. **주의: 이 완화는 백스톱 한정이다** —
#   주 경로 git-guard.py 는 heredoc 본문도 토큰화하므로 같은 FP 가 그대로 남아 있다
#   (실측: `printf 'cat <<EOF > /tmp/f\nhello\nEOF\ngit push …' | python git-guard.py push` → 1).
#   즉 degraded 가 normal 보다 이 형태에서만 의도적으로 느슨하다 (tests §E 에 비대칭으로 고정).
_BE_CLAUSES=""
_be_build_clauses() {
  [ -n "$_BE_CLAUSES" ] && return 0
  _BE_CLAUSES=$(printf '%s\n' "$COMMAND" | awk '
    BEGIN { delim = "" }
    {
      line = $0
      if (delim != "") {                       # heredoc 본문 — 종료 델리미터 줄까지 skip
        t = line
        sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t)
        if (t == delim) delim = ""
        next
      }
      if (match(line, /<<-?[ \t]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*["'"'"']?/)) {
        d = substr(line, RSTART, RLENGTH)
        sub(/^<<-?[ \t]*/, "", d)
        gsub(/["'"'"']/, "", d)
        delim = d                              # 도입부 줄 자체는 검사 대상으로 남긴다
      }
      n = split(line, parts, /[;|&()]/)
      for (i = 1; i <= n; i++) if (parts[i] != "") print parts[i]
    }
  ')
}

_BE_NOISE='(then|do|else|elif|fi|done|\{|\}|!|sudo|xargs|command|exec|nohup|env|timeout|nice|stdbuf|ionice|setsid|time|doas|chrt|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|-[^[:space:]]+|[0-9]+)[[:space:]]+'
_BE_GITOPT='((-C|-c|--namespace|--git-dir|--work-tree|--config-env|--attr-source)[[:space:]]+[^[:space:]]+|-[^[:space:]]+)[[:space:]]+'
_BE_HEAD="^[[:space:]]*(${_BE_NOISE})*git[[:space:]]+(${_BE_GITOPT})*"
_BE_REFCORE='((origin|upstream)/|refs/heads/)?(main|master)'
_BE_REF="(\"${_BE_REFCORE}\"|'${_BE_REFCORE}'|${_BE_REFCORE})([[:space:]]|\$)"
# checkout 전용 gap: 단독 `--` 를 소비하지 못하게 한다 — git-guard.py::detect_master_merge 가
#   checkout 에 한해 `--` 뒤를 pathspec 으로 보고 면제하는 분기를 그대로 반영 (F5①).
_BE_GAP_NODD='((--[^[:space:]]+|-?[^-[:space:]][^[:space:]]*|-)[[:space:]]+)*'

# 어느 절이든 "절머리 + 패턴" 이 맞으면 0.
#   절 목록을 **통째로 grep 1회에 파이프**한다 (절마다 fork 하던 구조 = F-A 회귀):
#   절당 fork 2개면 40절 6,751ms / 300절 59,093ms 로 hook timeout(5초)을 넘겨 차단 신호가 사라진다.
#   패턴이 `^` 앵커라 grep 은 줄(=절) 단위로 독립 판정하므로 의미는 동일하고 비용만 상수가 된다.
_be_match() {
  _be_build_clauses
  grep -qE "${_BE_HEAD}$1" <<< "$_BE_CLAUSES"
}

if [ "$TOOL_NAME" = "Bash" ]; then
  hook_parse_command
  # H-2 wire-in point: push 검출 단일점 — 향후 PUSH_EXCEPTION_ACTIVE 정책 분기를 여기서 (현 behavior 불변)
  PUSH_DETECTED="0"
  resolve_python
  # 배칭: git detector 를 all 모드로 1회 호출 후 캐시 (push/master-merge/cherry-pick python 3회→1회).
  GG_ALL=""
  # shellcheck disable=SC2086  # HOOK_PY_TIMEOUT 은 "timeout 2" 두 토큰으로 분리돼야 한다 (hook-input.sh SSOT)
  [ -n "$HOOK_PY" ] && GG_ALL=$(printf '%s' "$COMMAND" | $HOOK_PY_TIMEOUT "$HOOK_PY" "$(dirname "$0")/lib/git-guard.py" all 2>/dev/null)
  GG_ALL="${GG_ALL//$'\r'/}"   # Windows python CRLF 제거 (라인 매칭 정확성)
  gg() {
    local w=$'\n'"$GG_ALL"$'\n' r
    case "$w" in
      *$'\n'"$1="*) r="${w##*$'\n'"$1="}"; printf '%s' "${r%%$'\n'*}" ;;
      *) printf '0' ;;
    esac
  }
  if [ -n "$HOOK_PY" ]; then
    PUSH_DETECTED=$(gg push)
  fi
  # python 부재·**결과 부재** 시 grep 백스톱 (fail-open → fail-closed, H1 2026-06-16): 절(;/&&/||/|/&) 분리 후
  #   첫 git 토큰이 push 인 절 차단. GG_ALL 이 채워졌을 때만 git-guard.py(정확) 단독 — FP(commit 메시지 등) 회귀 0.
  #
  # 조건이 `-z "$HOOK_PY"` 가 아니라 `-z "$GG_ALL"` 인 이유 (2026-07-30):
  #   python 이 **존재하는데 실행이 실패**하는 경로가 실재한다 — hook 자체 timeout kill,
  #   HOOK_PY_TIMEOUT 만료, python 크래시. 그 경우 HOOK_PY 는 채워진 채 GG_ALL 만 비고,
  #   `gg push` 가 '0' 을 반환한다. 구 조건은 백스톱을 건너뛰어 **git push 가 통과**했다
  #   (§4.3(d) 전면 금지가 fail-open 으로 뒤집힘). `dangerous-ops-guard.sh` 는 처음부터
  #   `-z "$GG_ALL"` 기준이었고, 같은 배칭 패턴에서 폴백 기준만 갈라져 있었다.
  if [ -z "$GG_ALL" ] && [ "$PUSH_DETECTED" != "1" ]; then
    # 2026-08-03: 인라인 리터럴 → 공용 _be_match (F11). wrapper 6종→14종·env-prefix·shell 키워드·
    #   git 전역옵션(-c k=v 2토큰)까지 흡수하므로 구 패턴이 놓치던 형태도 잡힌다.
    if _be_match 'push([[:space:]]|$)'; then
      PUSH_DETECTED="1"
    fi
  fi
  if [ "$PUSH_DETECTED" = "1" ]; then
    command -v log_event >/dev/null 2>&1 && log_event "branch-enforce" "block" "reason=auto-push branch=$BRANCH"
    echo "[BRANCH-GUARD] 차단: 자동 원격 push 전면 금지 (현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: Claude 는 Bash 도구로 git push 를 직접 호출하지 않습니다 (모든 분기 / 모든 옵션 예외 0)." >&2
    echo "              조치: 사용자가 직접 \`! git push ...\` (Bash prefix) 또는 PowerShell 셸에서 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §4.3(d) \"git push 전면 금지\" + custom-plugin/git/skills/push/SKILL.md" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (1.5) master/main 머지 절대 금지 (모든 분기에서, 2026-05-13 신규)
# 매칭: 명령을 ;/&&/|| 로 분리한 각 절을 shlex 토큰화 →
#   (a) tokens=[git, merge, ...] AND any(t in MASTER_TARGETS for t in tokens[2:])  → target=main/master 머지 차단
#   (b) tokens=[git, checkout, ...] AND any(t in MASTER_TARGETS for t in tokens[2:]) → chained `checkout main && merge` 우회 차단
#   (c) 현재 분기 = master/main 이면 변경계 git 명령 (commit/merge/rebase) 차단 — 기존 (2) 룰로 처리
# Why: 사용자 명시 (2026-05-13) "master 머지 진행 절대금지" — 기존 hook 는 "현재 분기 protected" 만 검사로
#      chained 명령 `git checkout main && git merge feature/x` 우회 가능했음. shlex 토큰화로 false-positive 방지.
# MASTER_TARGETS = main / master / origin/main / origin/master / refs/heads/main / refs/heads/master / upstream/main / upstream/master
# ─────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ]; then
  MASTER_MERGE_DETECTED="0"
  # 배칭 GG_ALL 재사용 (push 섹션에서 1회 계산) — master-merge 값은 패턴명 또는 '0'
  if [ -n "$HOOK_PY" ]; then
    MASTER_MERGE_DETECTED=$(gg master-merge)
  fi
  # python 부재·**결과 부재** 시 grep 백스톱 (fail-open → fail-closed, C2 2026-08-03).
  #   §1 push 는 2026-07-30 에 `-z "$GG_ALL"` 백스톱을 얻었는데 §1.5/§1.6 만 `[ -n "$HOOK_PY" ]`
  #   단독 게이트로 남아 있었다 — python 이 검출되고 실행만 실패하면(Store 별칭 exit 9 · timeout kill)
  #   GG_ALL 이 비고 `gg master-merge` 가 '0' 을 돌려줘 §4.3(e) "절대 금지" 3명령이 통과했다
  #   (2026-08-03 감사 C2 실측: merge main / checkout main / switch master 3건 모두 exit 0).
  #   판정은 MASTER_TARGETS(lib/git-guard.py) 8 ref 기준, 애매하면 차단(fail-closed)이 기본값.
  if [ -z "$GG_ALL" ] && [ "$MASTER_MERGE_DETECTED" = "0" ]; then
    # merge/switch = ref 인자 전체 스캔 / checkout = `--` 이후를 pathspec 으로 보고 제외 (git-guard.py 동형)
    if _be_match "(merge|switch)[[:space:]]+([^[:space:]]+[[:space:]]+)*${_BE_REF}"; then
      MASTER_MERGE_DETECTED="grep-backstop"
    elif _be_match "checkout[[:space:]]+${_BE_GAP_NODD}${_BE_REF}"; then
      MASTER_MERGE_DETECTED="grep-backstop"
    fi
  fi
  if [ "$MASTER_MERGE_DETECTED" != "0" ]; then
    command -v log_event >/dev/null 2>&1 && log_event "branch-enforce" "block" "reason=master-merge pattern=$MASTER_MERGE_DETECTED branch=$BRANCH"
    echo "[BRANCH-GUARD] 차단: master/main 머지 절대 금지 (감지 패턴 '$MASTER_MERGE_DETECTED', 현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: Claude 는 Bash 도구로 master/main 으로의 머지·checkout·switch 를 직접 호출하지 않습니다 (모든 분기 / 모든 옵션 예외 0)." >&2
    echo "              조치: 사용자가 직접 \`! git merge ...\` / \`! git checkout main\` (Bash prefix) 또는 PowerShell 셸에서 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §4.3 \"master/main 머지 절대 금지\" + 본 hook (1.5)" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (1.6) master/main HEAD 에서 git cherry-pick 차단 (2026-06-04 신규)
# Why: §4.3(f) 정착 fallback 으로 cherry-pick 을 Claude 자동 실행 어휘에 편입 → merge 는 §1.5 가 차단하나
#   cherry-pick 은 통과하는 비대칭 발생. cherry-pick 은 target arg 가 아닌 "현재 HEAD 분기"에 적용되므로
#   §1.5 (target 토큰 검사) 패턴이 아닌 현재 BRANCH 검사. §(2) retire(2026-05-20)로 "현재 분기 master/main
#   변경계 차단" 구멍이 열려 있었음 — 본 가드가 cherry-pick 한정으로 그 구멍을 닫는다 (자동 루프 §3 hard-block 계약 정합).
# 매칭: 현재 BRANCH ∈ {main,master} AND 명령 절 토큰이 [git, cherry-pick, ...]. --abort/--quit/--skip 복구계는 면제
#   (진행 중 cherry-pick 상태 정리는 master/main 에서도 허용). 정착 happy-path 는 feature/* 체크아웃 후라 무영향.
# ─────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ] && { [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; }; then
  CHERRY_DETECTED="0"
  # 배칭 GG_ALL 재사용 (push 섹션에서 1회 계산)
  if [ -n "$HOOK_PY" ]; then
    CHERRY_DETECTED=$(gg cherry-pick)
  fi
  # grep 백스톱 (C2 2026-08-03, §1.5 와 동일 사유). --abort/--quit/--skip 복구계는 git-guard.py
  #   detect_cherry_pick 와 같은 기준으로 면제 — 진행 중 cherry-pick 정리는 master/main 에서도 허용.
  #   면제 판정은 **같은 절 안에서만** 본다 (F6): 명령 전체를 보면
  #   `git cherry-pick abc && git cherry-pick --abort` 처럼 뒤 절의 복구 플래그가 앞 절까지 면제한다.
  if [ -z "$GG_ALL" ] && [ "$CHERRY_DETECTED" != "1" ]; then
    _be_build_clauses
    # cherry-pick 절만 뽑고(1) 그 중 복구 플래그가 **같은 절에** 없는 것이 남으면 차단(2).
    #   절 루프 대신 grep 2회 — F-A 와 같은 이유로 fork 를 절 수와 무관하게 만든다.
    if grep -E "${_BE_HEAD}cherry-pick([[:space:]]|\$)" <<< "$_BE_CLAUSES" \
       | grep -qvE '(^|[[:space:]])(--abort|--quit|--skip)([[:space:]]|$)'; then
      CHERRY_DETECTED="1"
    fi
  fi
  if [ "$CHERRY_DETECTED" = "1" ]; then
    command -v log_event >/dev/null 2>&1 && log_event "branch-enforce" "block" "reason=master-cherry-pick branch=$BRANCH"
    echo "[BRANCH-GUARD] 차단: master/main HEAD 에서 git cherry-pick 금지 (현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: cherry-pick 자동 실행은 정착(feature/* 체크아웃) 한정. master/main 위 적용은 merge 와 동일 차단 (§1.5 미러)." >&2
    echo "              조치: feature 분기 체크아웃 후 정착하거나, 사용자가 직접 \`! git cherry-pick ...\` 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §4.3(f) + 본 hook (1.6)" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (2) [retired 2026-05-20] Protected 브랜치 자동 강제 + Edit/Write 차단 영역.
#     worktree-enforce.sh 로 의미 이관. 본 hook 는 §(1) push 차단 + §(1.5) master/main 금지만 잔존.
# ─────────────────────────────────────────────────────────
exit 0
