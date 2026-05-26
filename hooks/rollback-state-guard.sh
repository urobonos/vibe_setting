#!/bin/bash
# PreToolUse Hook (Bash): git commit 시 단일 commit 에 무관한 영역이 섞였는지 휴리스틱 검사
#
# 동작:
#   1. SKIP_HOOKS=1 → 즉시 통과
#   2. command 이 git commit 패턴이 아니면 통과
#   3. staged 파일의 top-level 디렉토리(4 단계 깊이) 다양성 측정
#   4. 4개 이상 영역이 동시에 staged 면 stdout Checkpoint 경고 (exit 0 — 실행 통과)
#
# 위반 시: CLAUDE.md §4 "롤백 가능 상태 유지" 룰
# 차단이 아닌 경고 — Claude 가 의도 검토 후 분리 commit 또는 그대로 진행.

source "$(dirname "$0")/lib/hook-input.sh"

hook_init
hook_read_stdin
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "rollback-state-guard" "enter" "pid=$$"
hook_parse_command

if [ -z "$COMMAND" ]; then
  exit 0
fi

# git commit 매칭 (amend / rebase 등은 별개라 단순 commit 만)
if ! echo "$COMMAND" | grep -qE 'git[[:space:]]+(-C[[:space:]]+\S+[[:space:]]+)?commit\b'; then
  exit 0
fi

# git diff --cached 기반 staged 파일 추출
# CWD 영향 회피 — git -C 로 명령에 명시된 디렉토리가 있으면 그 위치, 없으면 현재 PWD
GIT_DIR_OPT=$(echo "$COMMAND" | grep -oE 'git[[:space:]]+-C[[:space:]]+\S+' | head -1 | sed -E 's/^git[[:space:]]+-C[[:space:]]+//')

if [ -n "$GIT_DIR_OPT" ]; then
  STAGED=$(git -C "$GIT_DIR_OPT" diff --cached --name-only 2>/dev/null)
else
  STAGED=$(git diff --cached --name-only 2>/dev/null)
fi

if [ -z "$STAGED" ]; then
  exit 0
fi

# top-level 디렉토리 카운트 (예: hooks/, skills/, bin/, docs/ 등)
TOP_DIRS=$(echo "$STAGED" | awk -F/ 'NF>1 {print $1}' | sort -u)
DIR_COUNT=$(echo "$TOP_DIRS" | grep -c .)

# 4개 이상이면 경고
if [ "$DIR_COUNT" -lt 4 ]; then
  exit 0
fi

echo ""
echo "━━━ CHECKPOINT: 단일 commit 에 ${DIR_COUNT}개 영역 변경 감지 ━━━"
echo "변경 영역:"
echo "$TOP_DIRS" | head -10 | sed 's/^/  - /'
echo ""
echo "CLAUDE.md §4 \"롤백 가능 상태 유지\" 룰 — 단일 commit 에 무관한 작업이 섞이면 분리 롤백 불가."
echo ""
echo "확인 항목:"
echo "  1. 모든 변경이 단일 의도(이슈/기능/리팩토링)인가?"
echo "  2. 분리 commit 으로 나누는 게 더 명확한가?"
echo "  3. 분리 후 각 commit 이 독립적으로 롤백 가능한가?"
echo ""
echo "단일 의도이면 그대로 진행. 무관한 영역이 섞였으면 staged 파일 일부 unstage 후 별도 commit 권장."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
