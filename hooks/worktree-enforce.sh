#!/usr/bin/env bash
# worktree-enforce.sh — PreToolUse hook (2026-05-20 도입)
#
# 정책: 모든 소스 mutation 작업은 worktree 안에서 수행되어야 한다.
#   cwd 또는 FILE_PATH 가 worktree (`*/worktrees/*`) 가 아니고
#   functional exemption 9건 매칭 안 됨 → exit 2 차단.
#   단, cwd 가 git work-tree 가 아니면 (git 미연동 프로젝트) 면제 — worktree 생성 자체가
#   불가능하므로 강제 차단이 작업을 막는다 (path-pattern 면제와 별개인 state-condition 면제).
#
# Why: branch-enforce.sh (protected 분기 자동 강제) retire. worktree-first 단일 정책 전환.
#   - 모든 소스 작업 = worktree 격리 (사고 영구 차단)
#   - feature 분기 = 사용자 요청 시 생성 (자동 강제 폐기)
#
# Functional exemption 11건:
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
#
# SSOT: CLAUDE.md §4.3 "worktree 항상 강제" + 본 hook
# 짝 hook: worktree-prompt-detect.sh (UserPromptSubmit 안내) + commands/feature-{create,merge}.md

set -uo pipefail

PAYLOAD=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "worktree-enforce" "enter" "pid=$$"
TOOL_NAME=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)

case "$TOOL_NAME" in
  Edit|Write|MultiEdit)
    FILE_PATH=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); ti=d.get('tool_input',{}); print(ti.get('file_path') or ti.get('notebook_path') or '')" 2>/dev/null)
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
    IS_MUTATION=$(printf '%s' "$COMMAND" | python3 -c "
import sys, shlex, re
cmd = sys.stdin.read().replace('\n', ' ; ')   # 따옴표 밖 newline = 절 분리 (따옴표 안은 shlex 보존)
MUT = {'rm','mv','cp','mkdir','touch','tee','dd','truncate'}
OPS = {'|','||','&&',';','&','(',')','|&'}   # |& = 결합 파이프(2>&1|), punctuation_chars 가 단일토큰화
WRAP = {'sudo','xargs','command','exec','nohup','env'}   # 다음 토큰 command-position 유지
REDIR = ('>', '>>', '&>', '&>>', '>|')       # 파일쓰기 redirect (결합형 &>/&>>/>| 포함, >& 는 fd 모호 제외)
try:
    lx = shlex.shlex(cmd, posix=True, punctuation_chars=True); lx.whitespace_split = True
    toks = list(lx)
except ValueError:
    toks = cmd.split()
hit = False; at_cmd = True
for i, t in enumerate(toks):
    if t in REDIR:
        tgt = toks[i+1] if i + 1 < len(toks) else ''
        if tgt.startswith('/dev/') or tgt.startswith('&'):
            continue
        hit = True; break
    if t in OPS:
        at_cmd = True; continue
    if at_cmd:
        if re.match(r'^\w+=', t):
            continue
        if t in MUT:
            hit = True; break
        if t in WRAP:
            continue
        at_cmd = False
print('1' if hit else '0')
" 2>/dev/null)
    if [ "$IS_MUTATION" != "0" ]; then
      FILE_PATH=$(pwd | sed 's|\\|/|g')
    else
      exit 0
    fi
    ;;
  *)
    exit 0
    ;;
esac

# Functional exemption 9건 (FILE_PATH 기준)
case "$FILE_PATH" in
  */worktrees/*)                   exit 0 ;;
  */state/sessions/*.lock)         exit 0 ;;
  */projects/*/memory/*)           exit 0 ;;
  /tmp/claude_*)                   exit 0 ;;
  */.claude/docs/*)                exit 0 ;;
  */.claude/settings.json)         exit 0 ;;
  */.claude/settings.local.json)   exit 0 ;;
  */.claude/hooks/*)               exit 0 ;;  # #9: 프로젝트 로컬 hook (git 미추적, 2026-05-27)
  */.claude/CLAUDE.md)             exit 0 ;;  # #11: 루트/프로젝트 글로벌 지침 (추적 파일이나 라이브 발효 필요 = path 면제, 2026-06-04)
  C:/Works/infra/*|/c/Works/infra/*) exit 0 ;;  # #8: dev-team 인프라 영역 (git 미추적, 2026-05-20 추가)
esac

# Functional exemption #10 (2026-05-29): git untracked+ignored 파일 면제.
# git check-ignore 매칭 = .gitignore 로 추적 제외된 로컬 전용 파일 (settings.json #6/#7 의 일반화).
# worktree 는 git 추적 파일만 체크아웃하므로 untracked+ignored 파일은 worktree 격리 자체가 불가능
# (해당 파일이 worktree 에 존재하지 않아 "worktree 진입" 조치를 따를 수도 없다 = 차단이 작업을 막음).
# 예: 루트 CLAUDE.md (mirror-claude-md.sh 가 글로벌 미러본과 양방향 cp 하는 로컬 전용 지침, .gitignore 등재).
# cwd 가 git work-tree 일 때만 의미 (아니면 아래 git 미연동 cwd 면제가 처리).
if git -C "$(pwd)" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && git -C "$(pwd)" check-ignore -q -- "$FILE_PATH" 2>/dev/null; then
  exit 0
fi

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
echo "              면제 11건: worktrees/* / state/sessions/*.lock / projects/*/memory/* /" >&2
echo "                       /tmp/claude_* / .claude/docs/* / .claude/settings.json / .claude/settings.local.json /" >&2
echo "                       C:/Works/infra/* (dev-team) / .claude/hooks/* / git check-ignore 매칭(untracked+ignored) / .claude/CLAUDE.md" >&2
echo "              SSOT: CLAUDE.md §4.3 \"worktree 항상 강제\"" >&2
command -v log_event >/dev/null 2>&1 && log_event "worktree-enforce" "block" "reason=worktree-required"
exit 2
