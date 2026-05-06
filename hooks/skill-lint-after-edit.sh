#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
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

  # 1. lint-skills.sh
  if [ -x "$BIN_DIR/lint-skills.sh" ]; then
    OUT=$(bash "$BIN_DIR/lint-skills.sh" --skill "$SKILL_NAME" 2>&1)
    if [ "$?" -ne 0 ]; then
      HAS_WARNING=1
      AGGREGATE_OUTPUT="${AGGREGATE_OUTPUT}\n--- lint-skills ---\n$(echo "$OUT" | tail -8)"
    fi
  fi

  # 2. audit-references.sh (§N cross-skill 참조 검증)
  if [ -x "$BIN_DIR/audit-references.sh" ]; then
    OUT=$(bash "$BIN_DIR/audit-references.sh" --skill "$SKILL_NAME" 2>&1)
    if [ "$?" -ne 0 ]; then
      HAS_WARNING=1
      AGGREGATE_OUTPUT="${AGGREGATE_OUTPUT}\n--- audit-references ---\n$(echo "$OUT" | tail -8)"
    fi
  fi

  # 3. why-line-coverage.sh (강제어휘 ↔ Why 라인 커버리지)
  if [ -x "$BIN_DIR/why-line-coverage.sh" ]; then
    OUT=$(bash "$BIN_DIR/why-line-coverage.sh" --skill "$SKILL_NAME" 2>&1)
    # why-line-coverage 는 등급(GOOD/FAIR/POOR) 만 출력 — POOR 일 때만 경고
    if echo "$OUT" | grep -q "POOR"; then
      HAS_WARNING=1
      AGGREGATE_OUTPUT="${AGGREGATE_OUTPUT}\n--- why-line-coverage ---\n$(echo "$OUT" | tail -5)"
    fi
  fi

  if [ "$HAS_WARNING" -eq 1 ]; then
    echo "" >&2
    echo "[skill-lint] $SKILL_NAME — 검증 경고 (작업 차단 없음):" >&2
    echo -e "$AGGREGATE_OUTPUT" >&2
  fi
fi

exit 0
