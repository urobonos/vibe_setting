#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse Hook: skills/{name}/SKILL.md 변경 시 lint-skills.sh 자동 실행
#
# 정책: skill-creator/skill-validator 가 SKILL.md 편집한 직후 자동 lint 작동.
#       hook 미연결 시 검증 누락된 채 커밋되는 구조 차단.
# exit 0 정책 — lint FAIL 도 stderr 알림만, 작업 차단 없음.

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path
FILE="$FILE_PATH"

[ -z "$FILE" ] && exit 0

# .claude/skills/{name}/SKILL.md 패턴만 매칭
if echo "$FILE" | grep -qiE '\.claude/skills/[^/]+/SKILL\.md$'; then
  SKILL_NAME=$(echo "$FILE" | sed -nE 's|.*/skills/([^/]+)/SKILL\.md$|\1|p')
  if [ -n "$SKILL_NAME" ] && [ -x "$HOME/.claude/bin/lint-skills.sh" ]; then
    LINT_OUTPUT=$(bash "$HOME/.claude/bin/lint-skills.sh" --skill "$SKILL_NAME" 2>&1)
    LINT_EXIT=$?
    if [ "$LINT_EXIT" -ne 0 ]; then
      echo "" >&2
      echo "[skill-lint] $SKILL_NAME — 검증 경고 (작업 차단 없음):" >&2
      echo "$LINT_OUTPUT" | tail -10 >&2
    fi
  fi
fi

exit 0
