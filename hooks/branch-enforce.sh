#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PreToolUse:Edit|Write|Bash Hook — push 차단 + master/main 머지 금지 (잔존 영역, 2026-05-20 retire 후)
#
# 정책 (2026-04-30 / 2026-05-07 / 2026-05-13 / 2026-05-20 부분 retire):
#   - §(1) git push 차단 (모든 분기) — 유지
#   - §(1.5) master/main 머지·checkout·switch 절대 금지 — 유지
#   - §(2) Protected 브랜치 자동 강제 + Edit/Write 차단 = **retire (2026-05-20)**
#     → `worktree-enforce.sh` 로 의미 이관 (worktree 항상 강제 + feature 분기 요청 시 생성)
#
# 산출물 SSOT: ~/.claude/docs/working/20260520/2026-05-20-claude-harness-worktree-always-policy.md
#             + ~/.claude/docs/claude-harness/output/guide/2026-04-30-branch-workflow/ (구 정책 참조)

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_init
hook_read_stdin

# 현재 브랜치 — git repo 가 아니면 통과
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

# tool_name 추출 (Edit / Write / Bash 분기)
TOOL_NAME=""
if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
  hook_python
  TOOL_NAME=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null)
fi

# ─────────────────────────────────────────────────────────
# (1) git push — 모든 분기에서 차단 (자동 원격 push 전면 금지, 2026-05-07 / 2026-05-08 정밀화)
# 매칭: 명령을 ;/&&/|| 로 분리한 각 절을 shlex 토큰화 → 첫 두 토큰이 ['git','push'] 인 절만 차단.
# Why: substring 매칭은 commit 메시지·heredoc 본문·grep 인자 안의 'git push' 문자열까지 false-positive 차단함.
# ─────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ]; then
  hook_parse_command
  PUSH_DETECTED="0"
  hook_python
  if [ -n "$HOOK_PY" ]; then
    PUSH_DETECTED=$(printf '%s' "$COMMAND" | "$HOOK_PY" -c "
import sys, shlex, re
cmd = sys.stdin.read()
for part in re.split(r'(?:&&|\|\||;)', cmd):
    try:
        tokens = shlex.split(part, posix=True)
    except ValueError:
        tokens = part.strip().split()
    if len(tokens) >= 2 and tokens[0] == 'git' and tokens[1] == 'push':
        print('1'); sys.exit(0)
print('0')
" 2>/dev/null)
  fi
  if [ "$PUSH_DETECTED" = "1" ]; then
    echo "[BRANCH-GUARD] 차단: 자동 원격 push 전면 금지 (현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: Claude 는 Bash 도구로 git push 를 직접 호출하지 않습니다 (모든 분기 / 모든 옵션 예외 0)." >&2
    echo "              조치: 사용자가 직접 \`! git push ...\` (Bash prefix) 또는 PowerShell 셸에서 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §\"자동 원격 push 전면 금지\" + skills/git-push/SKILL.md" >&2
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
  hook_python
  if [ -n "$HOOK_PY" ]; then
    MASTER_MERGE_DETECTED=$(printf '%s' "$COMMAND" | "$HOOK_PY" -c "
import sys, shlex, re
TARGETS = {'main', 'master', 'origin/main', 'origin/master',
           'refs/heads/main', 'refs/heads/master',
           'upstream/main', 'upstream/master'}
cmd = sys.stdin.read()
for part in re.split(r'(?:&&|\|\||;)', cmd):
    try:
        tokens = shlex.split(part, posix=True)
    except ValueError:
        tokens = part.strip().split()
    if len(tokens) < 2 or tokens[0] != 'git':
        continue
    if tokens[1] == 'merge':
        for t in tokens[2:]:
            if t in TARGETS:
                print('merge-target'); sys.exit(0)
    elif tokens[1] == 'checkout':
        for t in tokens[2:]:
            if t in TARGETS:
                print('checkout-master'); sys.exit(0)
    elif tokens[1] == 'switch':
        for t in tokens[2:]:
            if t in TARGETS:
                print('switch-master'); sys.exit(0)
print('0')
" 2>/dev/null)
  fi
  if [ "$MASTER_MERGE_DETECTED" != "0" ]; then
    echo "[BRANCH-GUARD] 차단: master/main 머지 절대 금지 (감지 패턴 '$MASTER_MERGE_DETECTED', 현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: Claude 는 Bash 도구로 master/main 으로의 머지·checkout·switch 를 직접 호출하지 않습니다 (모든 분기 / 모든 옵션 예외 0)." >&2
    echo "              조치: 사용자가 직접 \`! git merge ...\` / \`! git checkout main\` (Bash prefix) 또는 PowerShell 셸에서 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §4.3 \"master/main 머지 절대 금지\" + 본 hook (1.5)" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (2) [retired 2026-05-20] Protected 브랜치 자동 강제 + Edit/Write 차단 영역.
#     worktree-enforce.sh 로 의미 이관. 본 hook 는 §(1) push 차단 + §(1.5) master/main 금지만 잔존.
# ─────────────────────────────────────────────────────────
exit 0
