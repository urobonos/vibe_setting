#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "claude-settings-sync" "enter" "pid=$$"
# PostToolUse Hook: .claude/ 설정 파일 변경 시 git 자동 커밋+푸시

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path
FILE="$FILE_PATH"

if [ -z "$FILE" ]; then exit 0; fi

# .claude/CLAUDE.md 또는 .claude/skills/ 변경 시 — stderr 안내만 출력 (자동 commit 제거)
# 정책 (2026-05-06): 자동 git commit 제거. 매 Edit 마다 의도하지 않은 다중 commit 누적 +
# 사용자 staging 흐름 가로채 + branch-enforce.sh protected 브랜치 차단과 충돌 위험.
# Claude 는 Direct Execution 룰 (CLAUDE.md §4) 에 따라 사용자 승인 시 직접 git commit 실행.
if echo "$FILE" | grep -qiE '\.claude/(CLAUDE\.md|skills/)'; then
  echo "[claude-settings-sync] $(basename "$FILE") 변경 감지 — 사용자 승인 후 git commit 필요." >&2
fi

exit 0
