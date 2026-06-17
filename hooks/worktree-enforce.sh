#!/usr/bin/env bash
# worktree-enforce.sh — PreToolUse hook (2026-05-20 도입)
#
# 정책: 모든 소스 mutation 작업은 worktree 안에서 수행되어야 한다.
#   cwd 또는 FILE_PATH 가 worktree (`*/worktrees/*`) 가 아니고
#   functional exemption 12건 매칭 안 됨 → exit 2 차단.
#   단, cwd 가 git work-tree 가 아니면 (git 미연동 프로젝트) 면제 — worktree 생성 자체가
#   불가능하므로 강제 차단이 작업을 막는다 (path-pattern 면제와 별개인 state-condition 면제).
#
# Why: branch-enforce.sh (protected 분기 자동 강제) retire. worktree-first 단일 정책 전환.
#   - 모든 소스 작업 = worktree 격리 (사고 영구 차단)
#   - feature 분기 = 사용자 요청 시 생성 (자동 강제 폐기)
#
# Functional exemption 12건:
#   1. */worktrees/*                  (worktree 자체)
#   2. */state/sessions/*.lock        (session lock)
#   3. */projects/*/memory/*          (auto memory)
#   4. /tmp/claude_*                  (gate / stop / echo marker)
#   5. */.claude/docs/*               (산출물 - Gate-0 직행 정합, working/REGISTRY.md 포함)
#   6. */.claude/settings.json        (git untracked, worktree 동기화 불가능)
#   7. */.claude/settings.local.json  (git untracked)
#   8. C:/Works/infra/*               (dev-team 인프라 영역, git 미추적, 2026-05-20)
#   9. */.claude/hooks/*             (프로젝트 로컬 hook, git 미추적, 2026-05-27)
#   10. git check-ignore 매칭         (untracked+ignored 로컬 전용 파일, 2026-05-29)
#   11. */.claude/CLAUDE.md          (루트/프로젝트 글로벌 지침 — 추적 파일이나 정책 변경마다 라이브 발효 필요 = 명시 path 면제, 2026-06-04)
#   12. */.claude/commands/*         (슬래시 커맨드 정의 — 추적 파일이나 슬래시 호출 시 라이브 발효 필요 = hooks(#9)/CLAUDE.md(#11) 동질 path 면제, 2026-06-04)
#
# SSOT: CLAUDE.md §4.3 "worktree 항상 강제" + 본 hook
# 짝 hook: worktree-prompt-detect.sh (UserPromptSubmit 안내) + commands/feature-{create,merge}.md

set -uo pipefail

PAYLOAD=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "worktree-enforce" "enter" "pid=$$"

# --- 면제 판정 단일 함수 (12 path-pattern + #10 check-ignore) ---
# Edit/Write 모드와 Bash 모드 target 검사가 공유하는 단일 SSOT (v6, 2026-06-10 — 사용자 승인 오탐 픽스).
is_exempt_path() {
  local P="$1"
  case "$P" in *..*) return 1 ;; esac   # traversal (docs/../skills 류) = 무조건 비면제 — Edit/Bash 양 모드 방어 (v6)
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
    C:/Works/infra/*|/c/Works/infra/*) return 0 ;;  # #8
  esac
  # #10 (2026-05-29): untracked+ignored 로컬 전용 파일 — worktree 에 존재하지 않아 격리 불가능.
  if git -C "$(pwd)" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     && git -C "$(pwd)" check-ignore -q -- "$P" 2>/dev/null; then
    return 0
  fi
  return 1
}
# tool_name 추출 — python3→python fallback + grep 백스톱 (fail-open 차단, H1 2026-06-16)
#   python3 부재·JSON 파싱 실패 시 TOOL_NAME="" → case *) exit 0 으로 모든 mutation 이 무검사 통과하던 구멍 차단.
_WT_PY=""
command -v python3 >/dev/null 2>&1 && _WT_PY=python3
[ -z "$_WT_PY" ] && command -v python >/dev/null 2>&1 && _WT_PY=python
TOOL_NAME=""
[ -n "$_WT_PY" ] && TOOL_NAME=$(printf '%s' "$PAYLOAD" | "$_WT_PY" -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[ -z "$TOOL_NAME" ] && TOOL_NAME=$(printf '%s' "$PAYLOAD" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')

case "$TOOL_NAME" in
  Edit|Write|MultiEdit)
    FILE_PATH=""
    [ -n "$_WT_PY" ] && FILE_PATH=$(printf '%s' "$PAYLOAD" | "$_WT_PY" -c "import json,sys; d=json.load(sys.stdin); ti=d.get('tool_input',{}); print(ti.get('file_path') or ti.get('notebook_path') or '')" 2>/dev/null)
    # python 파싱 실패 시 grep 백스톱 (fail-open 차단, H1 2026-06-16)
    if [ -z "$FILE_PATH" ]; then
      FILE_PATH=$(printf '%s' "$PAYLOAD" | grep -oE '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
    fi
    if [ -z "$FILE_PATH" ]; then exit 0; fi
    FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')
    ;;
  Bash)
    COMMAND=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)
    # 파일 시스템 mutation 만 검사 (git 명령은 branch-enforce 잔존 영역).
    # raw glob → shlex 토큰화 (2026-06-04, v5c): 명령 텍스트(echo 문자열·주석) 내 '>'/'rm' false-positive 방지.
    #   - operator(|/||/&&/;/&/()/|&) 뒤 토큰 = 명령 위치 → mutation 명령 감지 (단일 | 누수 방지, re.split 미사용)
    #   - newline = 절 분리(';' 치환), env-prefix(VAR=val) skip, subshell '()' 도 명령 위치 복귀
    #   - wrapper {sudo,xargs,command,exec,nohup,env} = 다음 토큰 command-position 유지 (xargs rm/command rm 차단, command -v rm/which rm 통과)
    #   - redirect REDIR(>/>>/&>/&>>/>|) target 이 /dev·fd(&) 면 무해 skip, 실제 파일이면 차단 (결합형 &> 단일토큰화 대응, >& 는 fd 모호 제외)
    #   - 잔여 누수(문서화, 추적 안 함): >& file·xargs -0/-I rm(옵션개재)·backtick·eval·timeout = Claude 미사용 형태 + 다층 방어(dangerous-ops-guard 등)
    #   - 잔여 FP(문서화): grep ">" 따옴표 단독연산자 = posix shlex 따옴표 제거(재설계 외 해결불가, 마찰·비누수)
    #   - python 실패 시 IS_MUTATION 빈값 != "0" → 보수적 차단 (false negative 회피)
    # v6 (2026-06-10, 사용자 승인 오탐 픽스): mutation 대상 경로를 수집해 **전 대상이 면제 매칭일 때만 통과**.
    #   - 미해석 토큰($VAR/명령치환/backtick)·`..` traversal·대상 미추출(dd·옵션만·trailing redirect)·파서 실패
    #     = __UNRESOLVED__ → 종전대로 pwd 기준 차단 (fail-closed 불변)
    #   - 출력 양식: 1행 = '1'/'0' (mutation 여부), 2행~ = 대상 경로 (또는 __UNRESOLVED__)
    PARSE=$(printf '%s' "$COMMAND" | python3 -c "
import sys, shlex, re
cmd = sys.stdin.read().replace('\n', ' ; ')   # 따옴표 밖 newline = 절 분리 (따옴표 안은 shlex 보존)
MUT = {'rm','mv','cp','mkdir','touch','tee','dd','truncate'}
OPS = {'|','||','&&',';','&','(',')','|&'}   # |& = 결합 파이프(2>&1|), punctuation_chars 가 단일토큰화
WRAP = {'sudo','xargs','command','exec','nohup','env'}   # 다음 토큰 command-position 유지
REDIR = ('>', '>>', '&>', '&>>', '>|')       # 파일쓰기 redirect (결합형 &>/&>>/>| 포함, >& 는 fd 모호 제외)
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

# Functional exemption 12건 + #10 check-ignore — is_exempt_path 단일 SSOT (v6)
if is_exempt_path "$FILE_PATH"; then exit 0; fi

# git 미연동 cwd 면제 (2026-05-26): worktree 는 git 기능 — cwd 가 git work-tree 가
# 아니면 worktree 생성 자체가 불가능하므로 강제 차단 시 모든 작업이 막힌다. pwd 기준 판정
# (FILE_PATH 기준은 신규 디렉토리 dirname 미존재 → git repo 인데 면제되는 우회 구멍).
if ! git -C "$(pwd)" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Bash 모드: FILE_PATH = pwd 이므로 위 면제로 cwd 자동 처리됨
# (별도 cwd 보조 검사 = Edit 모드 우회 통로 → 제거 2026-05-20 fix)

CWD=$(pwd 2>/dev/null | sed 's|\\|/|g')
echo "[WORKTREE-ENFORCE] 차단: worktree 진입 필수 (정책 2026-05-20)" >&2
echo "              파일: $FILE_PATH" >&2
echo "              cwd: $CWD" >&2
echo "              조치:" >&2
echo "                신규 작업 = git worktree add ~/.claude/worktrees/{sid}-{slug} -b wip/{sid}-{slug}" >&2
echo "                기존 feature 수정 = git worktree add ~/.claude/worktrees/{sid}-{slug} feature/X" >&2
echo "              면제 12건: worktrees/* / state/sessions/*.lock / projects/*/memory/* /" >&2
echo "                       /tmp/claude_* / .claude/docs/* / .claude/settings.json / .claude/settings.local.json /" >&2
echo "                       C:/Works/infra/* (dev-team) / .claude/hooks/* / git check-ignore 매칭(untracked+ignored) / .claude/CLAUDE.md / .claude/commands/*" >&2
echo "              SSOT: CLAUDE.md §4.3 \"worktree 항상 강제\"" >&2
command -v log_event >/dev/null 2>&1 && log_event "worktree-enforce" "block" "reason=worktree-required"
exit 2
