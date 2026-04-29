#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse Hook: .claude/ 설정 파일 변경 시 git 자동 커밋+푸시

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path
FILE="$FILE_PATH"

if [ -z "$FILE" ]; then exit 0; fi

# .claude/CLAUDE.md 또는 .claude/skills/ 변경 시에만 동기화
if echo "$FILE" | grep -qiE '\.claude/(CLAUDE\.md|skills/)'; then
  cd "$HOME/.claude" || exit 0
  git add CLAUDE.md skills/ .gitignore 2>/dev/null
  if ! git diff --cached --quiet 2>/dev/null; then
    # 자동 commit 만 수행. push 는 비활성 — CLAUDE.md §3(공유 상태 변경 사용자 승인) +
    # Direct Execution(승인 후 Claude 가 직접 실행) 룰. 사용자가 push 명시 요청 시
    # Claude 가 직접 `git push` 실행. hook 자동 push 금지.
    git commit -m "chore: auto-sync $(basename "$FILE")"
  fi
fi

exit 0
