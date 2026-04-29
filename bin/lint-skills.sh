#!/bin/bash
# lint-skills.sh
# 글로벌 스킬 정적 검증 — skill-validator 의 4 sub-agent 검증을 30초 bash 스크립트로 자동화.
#
# 검증 항목:
#   L1. SKILL.md 줄 수 (< 500 권장, ≥ 800 경고)
#   L2. frontmatter 필수 필드: name / description
#   L3. frontmatter 권장 필드: version / user-invocable / depends_on / conflicts_with / min_claude_md_version / triggers
#   L4. references/ 매핑: 본문 참조 references/{file}.md 가 실제 존재
#   L5. Why: 라인 짝지움 — 강제 어휘 빈도 vs Why: 라인 빈도 (목표 30% 이상)
#   L6. depends_on 의 모든 스킬 실재 (글로벌 스킬 폴더 기준)
#
# 사용법:
#   bash ~/.claude/bin/lint-skills.sh                    # 글로벌 모든 스킬 검증
#   bash ~/.claude/bin/lint-skills.sh --skill aws        # 특정 스킬만
#   bash ~/.claude/bin/lint-skills.sh --strict           # 경고도 FAIL 처리 (CI 모드)
#   bash ~/.claude/bin/lint-skills.sh --json             # JSON 출력 (스크립트 통합용)

SKILLS_DIR="${HOME}/.claude/skills"
TARGET_SKILL=""
STRICT=0
JSON=0
EXIT_CODE=0
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
RESULTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) TARGET_SKILL="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --json) JSON=1; shift ;;
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | head -25
      exit 0
      ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
  esac
done

if [ "$JSON" = "0" ]; then
  echo "━━━ Skill Lint — $(date '+%Y-%m-%d %H:%M') ━━━"
  echo "스킬 디렉토리: $SKILLS_DIR"
  [ -n "$TARGET_SKILL" ] && echo "대상: $TARGET_SKILL"
  [ "$STRICT" = "1" ] && echo "모드: strict (경고도 FAIL)"
  echo ""
fi

ALL_SKILLS=$(ls -1 "$SKILLS_DIR" 2>/dev/null | sort)

lint_skill() {
  local skill_name="$1"
  local skill_path="$SKILLS_DIR/$skill_name"
  local skill_md="$skill_path/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    return 0
  fi

  local lines
  lines=$(wc -l < "$skill_md" | tr -d ' ')

  local issues=()
  local status="PASS"

  # L1
  if [ "$lines" -ge 800 ]; then
    issues+=("L1-FAIL: SKILL.md ${lines}줄 (≥ 800 — references/ 분리 권고)")
    status="FAIL"
  elif [ "$lines" -ge 500 ]; then
    issues+=("L1-WARN: SKILL.md ${lines}줄 (≥ 500 — references/ 분리 검토)")
    [ "$status" = "PASS" ] && status="WARN"
  fi

  # L2
  local has_name has_desc
  has_name=$(grep -c '^name:' "$skill_md")
  has_desc=$(grep -c '^description:' "$skill_md")
  if [ "$has_name" -eq 0 ]; then
    issues+=("L2-FAIL: frontmatter 'name' 누락")
    status="FAIL"
  fi
  if [ "$has_desc" -eq 0 ]; then
    issues+=("L2-FAIL: frontmatter 'description' 누락")
    status="FAIL"
  fi

  # L3
  local missing_fields=()
  for field in version user-invocable depends_on conflicts_with min_claude_md_version triggers; do
    if ! grep -q "^${field}:" "$skill_md"; then
      missing_fields+=("$field")
    fi
  done
  if [ "${#missing_fields[@]}" -gt 0 ]; then
    issues+=("L3-WARN: frontmatter 권장 필드 누락: ${missing_fields[*]}")
    [ "$status" = "PASS" ] && status="WARN"
  fi

  # L4
  local refs_in_body
  refs_in_body=$(grep -oE 'references/[a-z0-9_-]+\.md' "$skill_md" 2>/dev/null | sort -u)
  local missing_refs=()
  if [ -n "$refs_in_body" ]; then
    while IFS= read -r ref; do
      local ref_path="$skill_path/$ref"
      if [ ! -f "$ref_path" ]; then
        missing_refs+=("$ref")
      fi
    done <<< "$refs_in_body"
  fi
  if [ "${#missing_refs[@]}" -gt 0 ]; then
    issues+=("L4-FAIL: 본문 참조 references 미존재: ${missing_refs[*]}")
    status="FAIL"
  fi

  # L5
  local strong_count why_count ratio
  strong_count=$(grep -cE '필수|금지|반드시|절대|Checkpoint' "$skill_md" 2>/dev/null)
  why_count=$(grep -cE '\*\*Why\b' "$skill_md" 2>/dev/null)
  if [ "$strong_count" -ge 10 ]; then
    if [ "$why_count" -eq 0 ]; then
      ratio=0
    else
      ratio=$((why_count * 100 / strong_count))
    fi
    if [ "$ratio" -lt 30 ]; then
      issues+=("L5-WARN: Why 짝지움 ${ratio}% (강제어휘 ${strong_count}건 vs Why ${why_count}건) — 50% 이상 권장")
      [ "$status" = "PASS" ] && status="WARN"
    fi
  fi

  # L6
  local deps
  deps=$(grep -E '^depends_on:' "$skill_md" | sed 's/^depends_on:[[:space:]]*//; s/[][]//g' | tr ',' '\n' | tr -d ' ')
  local missing_deps=()
  if [ -n "$deps" ]; then
    while IFS= read -r dep; do
      if [ -z "$dep" ]; then
        continue
      fi
      if ! echo "$ALL_SKILLS" | grep -qx "$dep"; then
        missing_deps+=("$dep")
      fi
    done <<< "$deps"
  fi
  if [ "${#missing_deps[@]}" -gt 0 ]; then
    issues+=("L6-FAIL: depends_on 미존재 스킬: ${missing_deps[*]}")
    status="FAIL"
  fi

  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    WARN)
      WARN_COUNT=$((WARN_COUNT + 1))
      [ "$STRICT" = "1" ] && EXIT_CODE=1
      ;;
    FAIL)
      FAIL_COUNT=$((FAIL_COUNT + 1))
      EXIT_CODE=1
      ;;
  esac

  if [ "$JSON" = "1" ]; then
    local issues_json=""
    if [ "${#issues[@]}" -gt 0 ]; then
      issues_json=$(printf '"%s",' "${issues[@]}" | sed 's/,$//')
    fi
    RESULTS+=("{\"skill\":\"$skill_name\",\"lines\":$lines,\"status\":\"$status\",\"issues\":[$issues_json]}")
  else
    printf "[%-4s] %-20s (%4d줄)" "$status" "$skill_name" "$lines"
    if [ "${#issues[@]}" -eq 0 ]; then
      echo " — OK"
    else
      echo ""
      for issue in "${issues[@]}"; do
        echo "        └─ $issue"
      done
    fi
  fi
}

if [ -n "$TARGET_SKILL" ]; then
  lint_skill "$TARGET_SKILL"
else
  for skill in $ALL_SKILLS; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
      lint_skill "$skill"
    fi
  done
fi

if [ "$JSON" = "1" ]; then
  joined=$(IFS=,; echo "${RESULTS[*]}")
  echo "{\"pass\":$PASS_COUNT,\"warn\":$WARN_COUNT,\"fail\":$FAIL_COUNT,\"results\":[$joined]}"
else
  echo ""
  echo "━━━ 요약 ━━━"
  echo "PASS: $PASS_COUNT / WARN: $WARN_COUNT / FAIL: $FAIL_COUNT"
  if [ "$EXIT_CODE" -ne 0 ]; then
    [ "$STRICT" = "1" ] && echo "(strict 모드 — WARN 도 FAIL 처리)"
    echo "exit code: $EXIT_CODE"
  fi
fi

exit $EXIT_CODE
