#!/usr/bin/env bash
# worktree-prompt-detect.sh — UserPromptSubmit hook (2026-05-20 도입)
#
# 작업 키워드 매칭 시 worktree 자동 생성 안내 stderr 주입 (차단 X, exit 0)
# Why: PreToolUse worktree-enforce.sh 가 mutation 차단 → 사용자가 worktree 진입까지 도달 못 함.
#      본 hook 가 사용자 발화 시점에 키워드 매칭 → Claude 본체 인지 → worktree 자동 생성.
#
# 차단 X — 안내만. 차단 책임 = worktree-enforce.sh (PreToolUse)
# SSOT: CLAUDE.md §4.3 + worktree-enforce.sh

set -uo pipefail

PAYLOAD=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "worktree-prompt-detect" "enter" "pid=$$"
PROMPT=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('prompt',''))" 2>/dev/null)

if [ -z "$PROMPT" ]; then exit 0; fi

# cwd 가 이미 worktree 안이면 안내 안 함 (중복 회피)
CWD=$(pwd 2>/dev/null | sed 's|\\|/|g')
case "$CWD" in
  */worktrees/*) exit 0 ;;
esac

# 작업 키워드 + 코드/소스 단어 결합 매칭 (false-positive 회피)
WORK_KW=0
case "$PROMPT" in
  *만들*|*구현*|*추가*|*수정*|*리팩*|*디버그*|*픽스*|*생성*|*삭제*|*변경*|*제거*|*통합*|*분리*|*적용*|*연결*|*리네임*|*개선*|*최적화*|*fix*|*add*|*remove*|*update*|*refactor*|*implement*|*create*|*delete*|*modify*)
    WORK_KW=1
    ;;
esac
[ "$WORK_KW" = "0" ] && exit 0

CODE_KW=0
case "$PROMPT" in
  *코드*|*소스*|*파일*|*hook*|*skill*|*command*|*함수*|*모듈*|*테스트*|*config*|*설정*|*.sh*|*.md*|*.json*|*.py*|*.ts*|*.js*|*.php*|*function*|*module*|*test*)
    CODE_KW=1
    ;;
esac
[ "$CODE_KW" = "0" ] && exit 0

cat >&2 <<'EOF'
[WORKTREE-PROMPT-DETECT] 작업 키워드 감지 — worktree 진입 안내 (정책 2026-05-20)
  본 정책: 모든 소스 작업은 worktree 안에서 수행. feature 분기는 사용자 요청 시 생성.
  Claude 본체 실행 명령:
    SLUG="{작업 슬러그}"
    SID="${CLAUDE_SESSION_ID:0:8}"
    git worktree add ~/.claude/worktrees/${SID}-${SLUG} -b wip/${SID}-${SLUG}
  기존 feature 수정 시: feature/X 를 base 로 worktree 분기
    git worktree add ~/.claude/worktrees/${SID}-${SLUG} feature/X
  완료 시 진입점:
    /git:create  (신규 feature 정착)
    /git:merge   (기존 feature 머지)
  SSOT: CLAUDE.md §4.3 "worktree 항상 강제"
EOF

exit 0
