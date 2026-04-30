#!/bin/bash
# audit-references.sh
# 스킬 간 §N 참조 무결성 검증 — lint-skills.sh L4 (자기 폴더 references/) 의 보완.
#
# 검출:
#   - 패턴: `{skill-name} §N` 또는 `{skill-name}.md §N` 또는 `{skill-name}-skill §N`
#   - 대상 스킬에서 해당 §N 헤더 (`^## N\.`, `^### N\.`, 또는 `^### .*\(N(-M)?\)`) 존재 검증
#   - 누락 시 FAIL (출처 스킬 / 대상 스킬 / 깨진 §N 라인 출력)
#
# 사용법:
#   bash ~/.claude/bin/audit-references.sh                    # 전체 16 스킬
#   bash ~/.claude/bin/audit-references.sh --skill aws        # 단일 스킬 (출처 기준)
#   bash ~/.claude/bin/audit-references.sh --strict           # WARN 도 FAIL
#   bash ~/.claude/bin/audit-references.sh --json             # JSON 출력

SKILLS_DIR="${HOME}/.claude/skills"
TARGET_SKILL=""
STRICT=0
JSON=0
EXIT_CODE=0
TOTAL_REFS=0
BROKEN_REFS=0
RESULTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) TARGET_SKILL="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --json) JSON=1; shift ;;
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | head -20
      exit 0
      ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
  esac
done

if [ "$JSON" = "0" ]; then
  echo "━━━ Skill §N 참조 무결성 — $(date '+%Y-%m-%d %H:%M') ━━━"
  [ -n "$TARGET_SKILL" ] && echo "대상: $TARGET_SKILL (출처 기준)"
  echo ""
fi

ALL_SKILLS=$(ls -1 "$SKILLS_DIR" 2>/dev/null | sort)

# --- 대상 스킬에서 §N 헤더 존재 확인 ---
# 인자: skill_path, section_number
# 반환: 0 = 존재, 1 = 미존재
section_exists() {
  local skill_md="$1"
  local section="$2"

  if [ ! -f "$skill_md" ]; then
    return 1
  fi

  # 패턴 1: ## N. (top-level)
  # 패턴 2: ### N. (sub-section)
  # 패턴 3: ## N-M. 또는 ### N-M. (dash-section)
  # 패턴 4: ### {제목} (N) 또는 ### {제목} (N-M)  — 라벨 형식
  if grep -qE "^##+[[:space:]]+${section}(\.|-|\b|[[:space:]])" "$skill_md"; then
    return 0
  fi
  if grep -qE "^##+[[:space:]]+.*\(${section}(-[0-9]+)?\)" "$skill_md"; then
    return 0
  fi
  return 1
}

# --- 출처 스킬에서 §N 참조 추출 ---
audit_skill() {
  local source_name="$1"
  local source_md="$SKILLS_DIR/$source_name/SKILL.md"

  if [ ! -f "$source_md" ]; then
    return 0
  fi

  local skill_refs=0
  local skill_broken=0

  # 패턴 매칭: `{name} §N` 또는 `{name}.md §N` 또는 `{name}-skill §N` 또는 `{name} §N-M`
  # 우선 모든 `§\d+` 라인 추출
  local matches
  matches=$(grep -nE '[a-zA-Z][a-zA-Z0-9_+.-]*[`[:space:]]+§[[:space:]]*[0-9]+' "$source_md" 2>/dev/null)

  if [ -z "$matches" ]; then
    return 0
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # 라인 번호 추출
    local lineno=${line%%:*}
    # 본문에서 모든 "{name} §N" 패턴 추출 (라인당 다중 가능)
    # name 은 [a-zA-Z][a-zA-Z0-9_+.-]* 와 매칭 (e.g., security-audit / php8.x+ci4.x-skill)
    local content=${line#*:}
    # 한 라인에서 모든 매칭 추출
    local pairs
    pairs=$(echo "$content" | grep -oE '[a-zA-Z][a-zA-Z0-9_+.-]*[`[:space:]]+§[[:space:]]*[0-9]+(-[0-9]+)?' 2>/dev/null)
    while IFS= read -r pair; do
      [ -z "$pair" ] && continue
      # name 과 section 분리
      local target_raw=$(echo "$pair" | sed -E 's/[`[:space:]].*//')
      local section=$(echo "$pair" | sed -E 's/^.*§[[:space:]]*//; s/-.*//')
      # 자기 자신 참조 무시
      if [ "$target_raw" = "$source_name" ]; then
        continue
      fi
      # ".md" / "-skill" suffix 제거
      local target_name=$(echo "$target_raw" | sed -E 's/\.md$//; s/-skill$//')
      # 글로벌 스킬 폴더 매칭 — 매칭 안 되면 skip (자연어 §N 참조)
      if ! echo "$ALL_SKILLS" | grep -qx "$target_name"; then
        # 부분 매칭 시도 (예: php8.x+ci4.x → php8)
        local match_partial
        match_partial=$(echo "$ALL_SKILLS" | grep -E "^${target_name%%[.+]*}\$" | head -1)
        if [ -n "$match_partial" ]; then
          target_name="$match_partial"
        else
          continue
        fi
      fi

      skill_refs=$((skill_refs + 1))
      TOTAL_REFS=$((TOTAL_REFS + 1))

      local target_md="$SKILLS_DIR/$target_name/SKILL.md"
      if ! section_exists "$target_md" "$section"; then
        skill_broken=$((skill_broken + 1))
        BROKEN_REFS=$((BROKEN_REFS + 1))
        if [ "$JSON" = "1" ]; then
          RESULTS+=("{\"source\":\"$source_name\",\"target\":\"$target_name\",\"section\":\"$section\",\"line\":$lineno}")
        else
          echo "  [BROKEN] $source_name:$lineno  →  $target_name §$section  (대상 헤더 없음)"
        fi
        EXIT_CODE=1
      fi
    done <<< "$pairs"
  done <<< "$matches"

  if [ "$JSON" = "0" ] && [ "$skill_refs" -gt 0 ]; then
    if [ "$skill_broken" -eq 0 ]; then
      printf "[PASS] %-20s — %d refs OK\n" "$source_name" "$skill_refs"
    fi
  fi
}

if [ -n "$TARGET_SKILL" ]; then
  audit_skill "$TARGET_SKILL"
else
  for skill in $ALL_SKILLS; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
      audit_skill "$skill"
    fi
  done
fi

if [ "$JSON" = "1" ]; then
  joined=$(IFS=,; echo "${RESULTS[*]}")
  echo "{\"total_refs\":$TOTAL_REFS,\"broken\":$BROKEN_REFS,\"results\":[$joined]}"
else
  echo ""
  echo "━━━ 요약 ━━━"
  echo "총 §N 참조: $TOTAL_REFS / 깨진 참조: $BROKEN_REFS"
  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "exit code: $EXIT_CODE"
  fi
fi

exit $EXIT_CODE
