#!/usr/bin/env bash
# worktree-enforce.sh — PreToolUse hook (2026-05-20 도입)
#
# 정책: 모든 소스 mutation 작업은 worktree 안에서 수행되어야 한다.
#   cwd 또는 FILE_PATH 가 worktree (`*/worktrees/*`) 가 아니고
#   functional exemption 8건 매칭 안 됨 → exit 2 차단.
#   단, cwd 가 git work-tree 가 아니면 (git 미연동 프로젝트) 면제 — worktree 생성 자체가
#   불가능하므로 강제 차단이 작업을 막는다 (path-pattern 면제와 별개인 state-condition 면제).
#
# Why: branch-enforce.sh (protected 분기 자동 강제) retire. worktree-first 단일 정책 전환.
#   - 모든 소스 작업 = worktree 격리 (사고 영구 차단)
#   - feature 분기 = 사용자 요청 시 생성 (자동 강제 폐기)
#
# Functional exemption 8건:
#   1. */worktrees/*                  (worktree 자체)
#   2. */state/sessions/*.lock        (session lock)
#   3. */projects/*/memory/*          (auto memory)
#   4. /tmp/claude_*                  (gate / stop / echo marker)
#   5. */.claude/docs/*               (산출물 - Gate-0 직행 정합, working/REGISTRY.md 포함)
#   6. */.claude/settings.json        (git untracked, worktree 동기화 불가능)
#   7. */.claude/settings.local.json  (git untracked)
#   8. C:/Works/infra/*               (dev-team 인프라 영역, git 미추적, 2026-05-20)
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
    # 파일 시스템 mutation 명령만 검사 (git 명령은 branch-enforce 잔존 영역)
    case "$COMMAND" in
      *"> "*|*">> "*|*"tee "*|*"cp "*|*"mv "*|*"rm "*|*"mkdir "*|*"touch "*)
        FILE_PATH=$(pwd | sed 's|\\|/|g')
        ;;
      *)
        exit 0
        ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac

# Functional exemption 8건 (FILE_PATH 기준)
case "$FILE_PATH" in
  */worktrees/*)                   exit 0 ;;
  */state/sessions/*.lock)         exit 0 ;;
  */projects/*/memory/*)           exit 0 ;;
  /tmp/claude_*)                   exit 0 ;;
  */.claude/docs/*)                exit 0 ;;
  */.claude/settings.json)         exit 0 ;;
  */.claude/settings.local.json)   exit 0 ;;
  C:/Works/infra/*|/c/Works/infra/*) exit 0 ;;  # #8: dev-team 인프라 영역 (git 미추적, 2026-05-20 추가)
esac

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
echo "              면제 8건: worktrees/* / state/sessions/*.lock / projects/*/memory/* /" >&2
echo "                       /tmp/claude_* / .claude/docs/* / .claude/settings.json / .claude/settings.local.json /" >&2
echo "                       C:/Works/infra/* (dev-team)" >&2
echo "              SSOT: CLAUDE.md §4.3 \"worktree 항상 강제\"" >&2
command -v log_event >/dev/null 2>&1 && log_event "worktree-enforce" "block" "reason=worktree-required"
exit 2
