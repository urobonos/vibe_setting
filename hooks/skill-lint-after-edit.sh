#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "skill-lint-after-edit" "enter" "pid=$$"
# PostToolUse Hook: skills/{name}/SKILL.md 변경 시 bin/ 검증 도구 3종 자동 실행
#
# 정책: skill-creator/skill-validator 가 SKILL.md 편집한 직후 자동 검증 작동.
#       hook 미연결 시 검증 누락된 채 커밋되는 구조 차단.
# exit 0 정책 — 검증 FAIL 도 stderr 알림만, 작업 차단 없음.
#
# 호출 도구 (단일 wrapper 통합 — settings.json matcher 변경 회피):
#   1. lint-skills.sh   — 정적 lint (description / triggers / 길이)
#   2. audit-references.sh — 스킬 간 §N 참조 무결성
#   3. why-line-coverage.sh — Why 라인 커버리지 (강제어휘 ↔ Why 비율)

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path
FILE="$FILE_PATH"

[ -z "$FILE" ] && exit 0

# .claude/skills/{name}/SKILL.md 패턴만 매칭
if echo "$FILE" | grep -qiE '\.claude/skills/[^/]+/SKILL\.md$'; then
  SKILL_NAME=$(echo "$FILE" | sed -nE 's|.*/skills/([^/]+)/SKILL\.md$|\1|p')
  if [ -z "$SKILL_NAME" ]; then
    exit 0
  fi

  BIN_DIR="$HOME/.claude/bin"
  HAS_WARNING=0
  AGGREGATE_OUTPUT=""

  # 2026-05-20 F3-P2: 3 도구 직렬 → background 병렬 spawn + wait
  #   기존 = lint + audit + why 직렬 (worst-case 누적)
  #   변경 = max(lint, audit, why) wall-clock (≈ 3배 절감)
  TMP_DIR=$(mktemp -d "/tmp/claude_skill_lint_XXXXXX" 2>/dev/null) || TMP_DIR="/tmp/claude_skill_lint_$$"
  mkdir -p "$TMP_DIR"

  if [ -x "$BIN_DIR/lint-skills.sh" ]; then
    ( bash "$BIN_DIR/lint-skills.sh" --skill "$SKILL_NAME" >"$TMP_DIR/lint.out" 2>&1; echo "$?" >"$TMP_DIR/lint.rc" ) &
  fi
  if [ -x "$BIN_DIR/audit-references.sh" ]; then
    ( bash "$BIN_DIR/audit-references.sh" --skill "$SKILL_NAME" >"$TMP_DIR/audit.out" 2>&1; echo "$?" >"$TMP_DIR/audit.rc" ) &
  fi
  if [ -x "$BIN_DIR/why-line-coverage.sh" ]; then
    ( bash "$BIN_DIR/why-line-coverage.sh" --skill "$SKILL_NAME" >"$TMP_DIR/why.out" 2>&1; echo "$?" >"$TMP_DIR/why.rc" ) &
  fi

  wait

  # 결과 수집 — 동일 stderr 출력 형식 유지
  if [ -f "$TMP_DIR/lint.rc" ] && [ "$(cat "$TMP_DIR/lint.rc")" != "0" ]; then
    HAS_WARNING=1
    AGGREGATE_OUTPUT="${AGGREGATE_OUTPUT}\n--- lint-skills ---\n$(tail -8 "$TMP_DIR/lint.out" 2>/dev/null)"
  fi
  if [ -f "$TMP_DIR/audit.rc" ] && [ "$(cat "$TMP_DIR/audit.rc")" != "0" ]; then
    HAS_WARNING=1
    AGGREGATE_OUTPUT="${AGGREGATE_OUTPUT}\n--- audit-references ---\n$(tail -8 "$TMP_DIR/audit.out" 2>/dev/null)"
  fi
  if [ -f "$TMP_DIR/why.out" ] && grep -q "POOR" "$TMP_DIR/why.out" 2>/dev/null; then
    HAS_WARNING=1
    AGGREGATE_OUTPUT="${AGGREGATE_OUTPUT}\n--- why-line-coverage ---\n$(tail -5 "$TMP_DIR/why.out" 2>/dev/null)"
  fi

  rm -rf "$TMP_DIR" 2>/dev/null

  if [ "$HAS_WARNING" -eq 1 ]; then
    echo "" >&2
    echo "[skill-lint] $SKILL_NAME — 검증 경고 (작업 차단 없음):" >&2
    echo -e "$AGGREGATE_OUTPUT" >&2
  fi
fi

exit 0
