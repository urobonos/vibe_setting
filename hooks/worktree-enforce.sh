#!/usr/bin/env bash
# worktree-enforce.sh — PreToolUse hook
#
# 정책: 모든 소스 mutation 작업은 worktree 안에서 수행되어야 한다.
#   cwd 또는 FILE_PATH 가 worktree (`*/worktrees/*`) 가 아니고
#   functional exemption 16건 매칭 안 됨 → exit 2 차단.
#   단, cwd 가 git work-tree 가 아니면 (git 미연동 프로젝트) 면제 — worktree 생성 자체가
#   불가능하므로 강제 차단이 작업을 막는다 (path-pattern 면제와 별개인 state-condition 면제).
#
# Why: worktree 격리가 사고를 원천 차단한다 — protected 분기 자동 강제 대신
#   모든 소스 작업을 worktree 안에 두고, feature 분기는 요청 시에만 만든다.
#
# Functional exemption 16건:
#   1. */worktrees/*                  (worktree 자체)
#   2. */state/sessions/*.lock        (session lock)
#   3. */projects/*/memory/*          (auto memory)
#   4. /tmp/claude_*                  (gate / stop / echo marker)
#   5. */.claude/docs/*               (산출물 - Gate-0 직행 정합, working/REGISTRY.md 포함)
#   6. */.claude/settings.json        (git untracked, worktree 동기화 불가능)
#   7. */.claude/settings.local.json  (git untracked)
#   8. C:/Works/infra/*               (hongcafe:dev-team 인프라 영역, git 미추적)
#   9. */.claude/hooks/*             (프로젝트 로컬 hook, git 미추적)
#   10. git check-ignore 매칭         (untracked+ignored 로컬 전용 파일)
#   11. */.claude/CLAUDE.md          (루트/프로젝트 글로벌 지침 — 추적 파일이나 정책 변경마다 라이브 발효 필요 = 명시 path 면제)
#   12. */.claude/commands/*         (슬래시 커맨드 정의 — 추적 파일이나 슬래시 호출 시 라이브 발효 필요 = hooks(#9)/CLAUDE.md(#11) 동질 path 면제)
#   13. */.claude/skills/*           (스킬 정의 — commands(#12) 동질 path 면제)
#   14. */.claude/README.md          (하니스 카탈로그 문서 — CLAUDE.md(#11) 동질, 라이브/문서 성격)
#   15. */.claude/custom-plugin/*    (플러그인 commands/skills — hooks(#9)/commands(#12)/skills(#13) 동질 라이브 발효, git 추적 대상이라 명시 path 면제)
#
# SSOT: CLAUDE.md §4.3 "worktree 항상 강제" + 본 hook
# 짝 hook: worktree-prompt-detect.sh (UserPromptSubmit 안내) + custom-plugin/git/commands/{create,merge}.md

set -uo pipefail

PAYLOAD=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "worktree-enforce" "enter" "pid=$$"

# target 경로의 git 판정 기준 디렉토리 = **존재하는 최근접 조상**.
# 신규 파일·신규 디렉토리는 dirname 이 아직 없을 수 있고, 그때 "repo 밖" 으로 오판하면
# 우회 구멍이 된다. #10 면제 판정과 아래 target repo 검증이 같은 기준을 쓰게 하는 SSOT.
_wt_nearest_dir() {
  local d; d=$(dirname "$1")
  while [ ! -d "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ] && [ -n "$d" ]; do
    d=$(dirname "$d")
  done
  printf '%s' "$d"
}

# --- 면제 판정 단일 함수 (14 path-pattern + #10 check-ignore) ---
# Edit/Write 모드와 Bash 모드 target 검사가 공유하는 단일 SSOT.
is_exempt_path() {
  local P="$1"
  case "$P" in *..*) return 1 ;; esac   # traversal (docs/../skills 류) = 무조건 비면제 — Edit/Bash 양 모드 방어
  case "$P" in
    */worktrees/*)                   return 0 ;;
    */state/sessions/*.lock)         return 0 ;;
    */projects/*/memory/*)           return 0 ;;
    /tmp/claude_*)                   return 0 ;;
    */.claude/docs/*)                return 0 ;;
    */.claude/settings.json)         return 0 ;;
    */.claude/settings.local.json)   return 0 ;;
    */.claude/hooks/*)               return 0 ;;  # #9
    */.claude/CLAUDE.md)             return 0 ;;  # #11
    */.claude/commands/*)            return 0 ;;  # #12
    */.claude/skills/*)              return 0 ;;  # #13
    */.claude/README.md)             return 0 ;;  # #14
    */.claude/custom-plugin/*)       return 0 ;;  # #15
    C:/Works/infra/*|/c/Works/infra/*) return 0 ;;  # #8
  esac
  # #10: untracked+ignored 로컬 전용 파일 — worktree 에 존재하지 않아 격리 불가능.
  #
  # 판정 기준은 **target 의 레포**다. cwd 기준으로 돌리면 cwd 와 target 이
  # 서로 다른 레포일 때 `check-ignore` 가 "outside repository" 로 조회 자체를 실패하고,
  # 실제로는 ignored 인 파일이 비면제로 떨어져 차단된다.
  # CLAUDE.md §4.3(c-2) "cwd 위치는 판정에 쓰지 않는다" 기준.
  local _ig_dir; _ig_dir=$(_wt_nearest_dir "$P")
  if [ -d "$_ig_dir" ] \
     && git -C "$_ig_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     && git -C "$_ig_dir" check-ignore -q -- "$P" 2>/dev/null; then
    return 0
  fi
  return 1
}
# tool_name 추출 — python3→python fallback + grep 백스톱 (fail-open 차단).
#   python3 부재·JSON 파싱 실패 시 TOOL_NAME="" → case *) exit 0 으로 모든 mutation 이 무검사 통과하는 구멍을 막는다.
_WT_PY=""
command -v python3 >/dev/null 2>&1 && _WT_PY=python3
[ -z "$_WT_PY" ] && command -v python >/dev/null 2>&1 && _WT_PY=python
# python 호출 timeout prefix — hook 자체 timeout(3초)으로 kill 될 때 파이프 안 python 손자가
#   Windows 에서 고아로 남는 것을 막는다. Why = hooks/lib/hook-input.sh §HOOK_PY_TIMEOUT SSOT.
#   본 hook 의 python 호출 4곳 전부에 적용한다 — 1곳만 감싸면 나머지가 고아를 만든다.
#   unquoted 전개 필수 ("timeout 2" 두 토큰).
_WT_TO=""
command -v timeout >/dev/null 2>&1 && _WT_TO="timeout 2"
TOOL_NAME=""
# bash 정규식 primary — tool_name 은 escape 없는 식별자라 python 기동이 불필요하다.
#   페이로드에서 tool_name 이 tool_input 보다 앞에 오므로 첫 매칭 = 최상위 키 (아래 grep 백스톱과 같은 가정).
[[ "$PAYLOAD" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && TOOL_NAME="${BASH_REMATCH[1]}"
# shellcheck disable=SC2086  # _WT_TO 는 "timeout 2" 두 토큰으로 분리돼야 한다
[ -z "$TOOL_NAME" ] && [ -n "$_WT_PY" ] && TOOL_NAME=$(printf '%s' "$PAYLOAD" | $_WT_TO "$_WT_PY" -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[ -z "$TOOL_NAME" ] && TOOL_NAME=$(printf '%s' "$PAYLOAD" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')

case "$TOOL_NAME" in
  Edit|Write|MultiEdit)
    FILE_PATH=""
    # shellcheck disable=SC2086
    [ -n "$_WT_PY" ] && FILE_PATH=$(printf '%s' "$PAYLOAD" | $_WT_TO "$_WT_PY" -c "import json,sys; d=json.load(sys.stdin); ti=d.get('tool_input',{}); print(ti.get('file_path') or ti.get('notebook_path') or '')" 2>/dev/null)
    # python 파싱 실패 시 grep 백스톱 (fail-open 차단)
    if [ -z "$FILE_PATH" ]; then
      FILE_PATH=$(printf '%s' "$PAYLOAD" | grep -oE '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
    fi
    if [ -z "$FILE_PATH" ]; then exit 0; fi
    FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')
    ;;
  Bash)
    # 파일 시스템 mutation 만 검사 (git 명령은 branch-enforce 잔존 영역).
    # raw glob → shlex 토큰화: 명령 텍스트(echo 문자열·주석) 내 '>'/'rm' false-positive 방지.
    #   - operator(|/||/&&/;/&/()/|&) 뒤 토큰 = 명령 위치 → mutation 명령 감지 (단일 | 누수 방지, re.split 미사용)
    #   - newline = 절 분리(';' 치환), env-prefix(VAR=val) skip, subshell '()' 도 명령 위치 복귀
    #   - wrapper {sudo,xargs,command,exec,nohup,env} = 다음 토큰 command-position 유지 (xargs rm/command rm 차단, command -v rm/which rm 통과)
    #   - redirect REDIR(>/>>/&>/&>>/>|) target 이 /dev·fd(&) 면 무해 skip, 실제 파일이면 차단 (결합형 &> 단일토큰화 대응, >& 는 fd 모호 제외)
    #   - 잔여 누수(문서화, 추적 안 함): >& file·xargs -0/-I rm(옵션개재)·backtick·eval·timeout = Claude 미사용 형태 + 다층 방어(dangerous-ops-guard 등)
    #   - 잔여 FP(문서화): grep ">" 따옴표 단독연산자 = posix shlex 따옴표 제거(재설계 외 해결불가, 마찰·비누수)
    #   - python 실패 시 IS_MUTATION 빈값 != "0" → 보수적 차단 (false negative 회피)
    # mutation 대상 경로를 수집해 **전 대상이 면제 매칭일 때만 통과**.
    #   - 미해석 토큰($VAR/명령치환/backtick)·`..` traversal·대상 미추출(dd·옵션만·trailing redirect)·파서 실패
    #     = __UNRESOLVED__ → pwd 기준 차단 (fail-closed 불변)
    #   - 출력 양식: 1행 = '1'/'0' (mutation 여부), 2행~ = 대상 경로 (또는 __UNRESOLVED__)
    # command 추출도 이 파서 안에서 함께 처리한다 (JSON 파싱 실패 = 출력 공백 = 아래 IS_MUTATION != "0" → 차단, fail-closed 불변).
    # shellcheck disable=SC2086
    PARSE=$(printf '%s' "$PAYLOAD" | $_WT_TO "${_WT_PY:-python3}" -c "
import sys, shlex, re, json
cmd = (json.load(sys.stdin).get('tool_input') or {}).get('command') or ''
cmd = cmd.replace('\n', ' ; ')   # 따옴표 밖 newline = 절 분리 (따옴표 안은 shlex 보존)
MUT = {'rm','mv','cp','mkdir','touch','tee','dd','truncate'}
OPS = {'|','||','&&',';','&','(',')','|&'}   # |& = 결합 파이프(2>&1|), punctuation_chars 가 단일토큰화
WRAP = {'sudo','xargs','command','exec','nohup','env'}   # 다음 토큰 command-position 유지
REDIR = ('>', '>>', '&>', '&>>', '>|')       # 파일쓰기 redirect (결합형 &>/&>>/>| 포함, >& 는 fd 모호 제외)
FDDUP = ('>&', '<&')                         # fd 복제(2>&1) — 대상도 fd, 통째 skip
def out(h, ts, unres):
    print('1' if h else '0')
    if unres: print('__UNRESOLVED__')
    for x in ts: print(x)
    sys.exit(0)
try:
    lx = shlex.shlex(cmd, posix=True, punctuation_chars=True); lx.whitespace_split = True
    toks = list(lx)
except ValueError:
    out(True, [], True)   # 파서 실패 = 보수적 차단
hit = False; at_cmd = True; cur_mut = False; need_tgt = False; unres = False; skip = False
targets = []
for i, t in enumerate(toks):
    if skip:
        skip = False; continue
    if t.isdigit() and i + 1 < len(toks) and (toks[i+1] in REDIR or toks[i+1] in FDDUP):
        continue                    # fd 지정자(2>/dev/null·2>&1 의 '2') — redirect 앞 정수 = fd 번호, 경로 아님
    if t in FDDUP:                  # fd 복제(>&) — 대상(fd 번호) 함께 skip, 파일쓰기 아님
        if i + 1 < len(toks): skip = True
        continue
    if t in REDIR:
        tgt = toks[i+1] if i + 1 < len(toks) else ''
        if tgt.startswith('/dev/') or tgt.startswith('&'):
            skip = True; continue
        hit = True
        if tgt: targets.append(tgt); skip = True
        else: unres = True      # trailing redirect — 대상 미상
        continue
    if t in OPS:
        if need_tgt: unres = True   # MUT 절이 대상 0개로 종료 (rm -f 만 등)
        at_cmd = True; cur_mut = False; need_tgt = False; continue
    if at_cmd:
        if re.match(r'^\w+=', t):
            continue
        if t in MUT:
            hit = True
            if t == 'dd': unres = True; cur_mut = False   # of= 인자 미추출 = 보수적 차단
            else: cur_mut = True; need_tgt = True
            at_cmd = False; continue
        if t in WRAP:
            continue
        at_cmd = False; continue
    if cur_mut:
        if t == '--' or t.startswith('-'):
            continue
        targets.append(t); need_tgt = False
if need_tgt: unres = True
out(hit, targets, unres)
" 2>/dev/null)
    IS_MUTATION=$(printf '%s\n' "$PARSE" | sed -n '1p')
    if [ "$IS_MUTATION" = "0" ]; then exit 0; fi
    TARGETS=$(printf '%s\n' "$PARSE" | sed -n '2,$p')
    FILE_PATH=""
    CWD0=$(pwd | sed 's|\\|/|g')
    if [ -n "$TARGETS" ] && ! printf '%s\n' "$TARGETS" | grep -q '^__UNRESOLVED__$'; then
      ALL_EXEMPT=1
      while IFS= read -r T; do
        [ -z "$T" ] && continue
        case "$T" in
          *'$'*|*'`'*|*..*) ALL_EXEMPT=0; FILE_PATH="$T"; break ;;   # 미해석/traversal = 비면제 (fail-closed)
        esac
        case "$T" in "~") T="$HOME" ;; "~/"*) T="$HOME/${T#\~/}" ;; esac
        T=$(printf '%s' "$T" | sed 's|\\|/|g')
        case "$T" in
          /*|[A-Za-z]:/*) : ;;
          *) T="$CWD0/$T" ;;
        esac
        if ! is_exempt_path "$T"; then ALL_EXEMPT=0; FILE_PATH="$T"; break; fi
      done <<< "$TARGETS"
      if [ "$ALL_EXEMPT" = "1" ]; then
        command -v log_event >/dev/null 2>&1 && log_event "worktree-enforce" "pass" "reason=bash-targets-exempt"
        exit 0
      fi
    fi
    [ -z "$FILE_PATH" ] && FILE_PATH="$CWD0"
    ;;
  *)
    exit 0
    ;;
esac

# Functional exemption 13 path-pattern + #10 check-ignore — is_exempt_path 단일 SSOT
if is_exempt_path "$FILE_PATH"; then exit 0; fi

# target repo 검증: FILE_PATH 의 실제 git 소속 판정.
#   cwd 가 repo 여도 target 이 repo 밖이면 통과 — cwd-only 과잉차단을 피한다. 신규 디렉토리는
#   **존재하는 최근접 조상**으로 판정하여 dirname 미존재 → repo 밖 오판 통과(우회 구멍)를 막는다.
# 대상이 디렉토리면 그 자체로 판정한다: Bash 모드는 대상 미해석 시 FILE_PATH=cwd(디렉토리)인데,
#   dirname 부터 벗기면 cwd=레포 루트에서 부모(레포 밖)를 보고 통과한다 — `dd of=x`·python 장애 시 `rm` 이 exit 0 되는 구멍.
#   #10 check-ignore 는 구 기준(dirname) 을 유지한다 — ignored 중첩 레포 디렉토리를 그 레포 안에서 질의하면 비면제로 뒤집힌다.
if [ -d "$FILE_PATH" ]; then _wt_tdir="$FILE_PATH"; else _wt_tdir=$(_wt_nearest_dir "$FILE_PATH"); fi
if [ -d "$_wt_tdir" ] && ! git -C "$_wt_tdir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# cwd 기준 면제는 두지 않는다 — target 이 cwd 와 다른 repo 안에 있으면 그 repo 에
# worktree 를 만들 수 있으므로 "cwd 가 git 밖이면 면제" 논리가 성립하지 않는다. 판정은 target 기준 하나로 충분하다.
# 결과: target ∉ git work-tree → 위 검증이 면제(git 미연동 프로젝트 작업은 그대로 통과).
#       target ∈ git work-tree → 차단(worktree 강제) — cwd 위치와 무관.
# SSOT: CLAUDE.md §4.3 (c-2)

# Bash 모드: FILE_PATH = pwd 이므로 위 면제로 cwd 가 자동 처리된다.
# (별도 cwd 보조 검사를 추가하면 Edit 모드 우회 통로가 된다 — 추가 금지)

CWD=$(pwd 2>/dev/null | sed 's|\\|/|g')
echo "[WORKTREE-ENFORCE] 차단: worktree 진입 필수 (정책 2026-05-20)" >&2
echo "              파일: $FILE_PATH" >&2
echo "              cwd: $CWD" >&2
echo "              조치:" >&2
echo "                신규 작업 = git worktree add ~/.claude/worktrees/{sid}-{slug} -b wip/{sid}-{slug}" >&2
echo "                기존 feature 수정 = git worktree add ~/.claude/worktrees/{sid}-{slug} feature/X" >&2
echo "                이어서 (PHP 레포) = bash ~/.claude/bin/vendor-pool.sh ensure ~/.claude/worktrees/{sid}-{slug}  — vendor 링크 금지" >&2
echo "              면제 14건: worktrees/* / state/sessions/*.lock / projects/*/memory/* /" >&2
echo "                       /tmp/claude_* / .claude/docs/* / .claude/settings.json / .claude/settings.local.json /" >&2
echo "                       C:/Works/infra/* (dev-team) / .claude/hooks/* / git check-ignore 매칭(untracked+ignored) / .claude/CLAUDE.md / .claude/commands/* / .claude/skills/* / .claude/README.md" >&2
echo "              SSOT: CLAUDE.md §4.3 \"worktree 항상 강제\"" >&2
command -v log_event >/dev/null 2>&1 && log_event "worktree-enforce" "block" "reason=worktree-required"
exit 2
