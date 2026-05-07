#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse:Edit|Write Hook — be CLAUDE.md ↔ 글로벌 미러본 양방향 동기화
#
# 대상:
#   C:/Works/hongcafe_global_backend/CLAUDE.md  ⇄  ~/.claude/mirrors/hongcafe_global_backend/CLAUDE.md
#
# 정책 (사용자 결정 2026-05-07):
#   - 양방향: 한쪽 Edit/Write 시 반대편 자동 cp
#   - cp 3회 재시도 + 2초 timeout (mirror-docs.sh 패턴)
#   - 미러 루트 미존재 시 SKIP (be 미클론 환경 호환)
#   - 무한 루프 방지: hook 내부 cp 는 도구 호출 아님 → PostToolUse 재발동 없음
#   - 실패 시 stderr 로그 + exit 0 (PostToolUse 차단 회피)
#
# 산출물 SSOT:
#   ~/.claude/docs/claude-harness/tasks/20260507/be-claude-md-mirror/2026-05-07-be-claude-md-mirror-plan.md
#   ~/.claude/skills/mirror-be-claude/SKILL.md (수동 진입점)

source "$(dirname "$0")/lib/hook-input.sh"
hook_init
hook_read_stdin
hook_parse_file_path

# 경로 정규화 — Windows-style (C:/...) 와 Git Bash POSIX-style (/c/...) 양쪽 입력 호환
# Claude Code 도구는 보통 Windows-style 로 file_path 전달, 본 hook 비교군은 POSIX 로 통일.
FILE_PATH=$(echo "$FILE_PATH" | tr '\\' '/' | sed -E 's|^([A-Za-z]):/|/\L\1/|')

BE_CLAUDE="/c/Works/hongcafe_global_backend/CLAUDE.md"          # POSIX (비교용)
BE_CLAUDE_RUN="C:/Works/hongcafe_global_backend/CLAUDE.md"      # Windows (cp 인자용)
MIRROR_DIR="$HOME/.claude/mirrors/hongcafe_global_backend"
MIRROR_CLAUDE="$MIRROR_DIR/CLAUDE.md"                            # POSIX (HOME=/c/Users/PV 가정)

# 트리거 매칭 — 정확히 두 경로만 (POSIX 정규화 후 비교)
case "$FILE_PATH" in
  "$BE_CLAUDE")
    SRC="$BE_CLAUDE_RUN"
    DEST="$MIRROR_CLAUDE"
    LABEL="be→mirror"
    ;;
  "$MIRROR_CLAUDE")
    SRC="$MIRROR_CLAUDE"
    DEST="$BE_CLAUDE_RUN"
    LABEL="mirror→be"
    ;;
  *)
    exit 0
    ;;
esac

[ -f "$SRC" ] || exit 0

# be 프로젝트 루트 미클론 환경 호환 — mirror→be 방향에서만 검증
if [ "$DEST" = "$BE_CLAUDE_RUN" ]; then
  if [ ! -d "/c/Works/hongcafe_global_backend" ]; then
    echo "[MIRROR-CLAUDE] SKIP $LABEL: be 프로젝트 미클론" >&2
    exit 0
  fi
fi

DEST_DIR=$(dirname "$DEST")
mkdir -p "$DEST_DIR" 2>/dev/null

for attempt in 1 2 3; do
  if timeout 2 cp -f "$SRC" "$DEST" 2>/dev/null; then
    [ "$attempt" -gt 1 ] && echo "[MIRROR-CLAUDE] OK ($attempt/3) $LABEL: $DEST" >&2
    exit 0
  fi
  sleep 0.2
done
echo "[MIRROR-CLAUDE] FAIL $LABEL after 3 retries: $SRC → $DEST" >&2
exit 0
