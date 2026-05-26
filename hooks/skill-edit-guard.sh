#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PreToolUse:Edit|Write Hook — 스킬 디렉토리 직접 수정 차단 (skill-creator 강제)
#
# 정책:
#   - .claude/skills/{skill}/* 하위 파일은 skill-creator 스킬을 통해서만 수정·생성
#   - 락 파일 /tmp/claude_skill_creator_active.lock 존재 시 통과 (skill-creator 진입 시 모델이 생성)
#   - 차단 시 exit 2 + stderr 메시지로 skill-creator 호출 유도
#   - 사용자 결정 (2026-04-30): 스킬 생성·수정·최적화는 전부 skill-creator 경유 강제

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_init
hook_read_stdin
hook_parse_file_path

# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

# .claude/skills/ 하위가 아니면 통과
echo "$FILE_PATH" | grep -qiE '/\.claude/skills/' || exit 0

# 락 파일 escape — skill-creator 진입 시 모델이 touch 로 생성
LOCK_FILE="/tmp/claude_skill_creator_active.lock"
if [ -f "$LOCK_FILE" ]; then
  exit 0
fi

# 차단
echo "[SKILL-GUARD] 차단: $FILE_PATH" >&2
echo "              .claude/skills/ 하위 파일은 skill-creator 스킬을 통해서만 수정·생성합니다." >&2
echo "              조치: '/skill-creator' 또는 '스킬 수정/생성' 트리거로 진입하세요." >&2
echo "              skill-creator 진입 직후 'touch $LOCK_FILE' 으로 락을 만들면 본 hook 을 우회합니다." >&2
echo "              작업 종료 시 'rm $LOCK_FILE' 으로 락을 제거합니다." >&2
exit 2
