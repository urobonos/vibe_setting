#!/bin/bash
# why-line-coverage.sh
# Why 라인 커버리지 정확 측정 — references/ 합산. lint-skills.sh L5 의 보완.
#
# 동작:
#   - 각 스킬에 대해 SKILL.md + references/*.md 모두 합산
#   - 강제 어휘(필수|금지|반드시|절대|Checkpoint) 빈도 vs Why 라인 빈도 비율 측정
#   - 50% 이상: GOOD / 30~50%: FAIR / 30% 미만: POOR
#
# 사용법:
#   bash ~/.claude/bin/why-line-coverage.sh
#   bash ~/.claude/bin/why-line-coverage.sh --skill aws
#   bash ~/.claude/bin/why-line-coverage.sh --json

SKILLS_DIR="${HOME}/.claude/skills"
TARGET_SKILL=""
JSON=0
RESULTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) TARGET_SKILL="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | head -15
      exit 0
      ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
  esac
done

if [ "$JSON" = "0" ]; then
  echo "━━━ Why 라인 커버리지 (SKILL.md + references/ 합산) — $(date '+%Y-%m-%d %H:%M') ━━━"
  echo ""
  printf "%-22s %8s %8s %8s   %s\n" "스킬" "강제어휘" "Why" "비율" "등급"
  echo "──────────────────────────────────────────────────────────────────"
fi

ALL_SKILLS=$(ls -1 "$SKILLS_DIR" 2>/dev/null | sort)

cover_skill() {
  local skill_name="$1"
  local skill_path="$SKILLS_DIR/$skill_name"
  local skill_md="$skill_path/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    return 0
  fi

  # SKILL.md + references/*.md 모두 카운트
  local target_files=("$skill_md")
  if [ -d "$skill_path/references" ]; then
    while IFS= read -r f; do
      target_files+=("$f")
    done < <(find "$skill_path/references" -maxdepth 1 -name '*.md' 2>/dev/null)
  fi

  local strong_count=0
  local why_count=0
  for f in "${target_files[@]}"; do
    local sc wc
    sc=$(grep -cE '필수|금지|반드시|절대|Checkpoint' "$f" 2>/dev/null)
    wc=$(grep -cE '\*\*Why\b' "$f" 2>/dev/null)
    strong_count=$((strong_count + sc))
    why_count=$((why_count + wc))
  done

  # 강제 어휘 < 5 면 측정 의미 없음 (작은 스킬)
  if [ "$strong_count" -lt 5 ]; then
    if [ "$JSON" = "0" ]; then
      printf "%-22s %8d %8d %8s   %s\n" "$skill_name" "$strong_count" "$why_count" "-" "N/A (어휘 < 5)"
    fi
    return 0
  fi

  local ratio
  if [ "$why_count" -eq 0 ]; then
    ratio=0
  else
    ratio=$((why_count * 100 / strong_count))
  fi

  local grade
  if [ "$ratio" -ge 50 ]; then
    grade="GOOD"
  elif [ "$ratio" -ge 30 ]; then
    grade="FAIR"
  else
    grade="POOR"
  fi

  if [ "$JSON" = "1" ]; then
    RESULTS+=("{\"skill\":\"$skill_name\",\"strong\":$strong_count,\"why\":$why_count,\"ratio\":$ratio,\"grade\":\"$grade\"}")
  else
    printf "%-22s %8d %8d %7d%%   %s\n" "$skill_name" "$strong_count" "$why_count" "$ratio" "$grade"
  fi
}

if [ -n "$TARGET_SKILL" ]; then
  cover_skill "$TARGET_SKILL"
else
  for skill in $ALL_SKILLS; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
      cover_skill "$skill"
    fi
  done
fi

if [ "$JSON" = "1" ]; then
  joined=$(IFS=,; echo "${RESULTS[*]}")
  echo "{\"results\":[$joined]}"
else
  echo ""
  echo "━━━ 등급 기준 ━━━"
  echo "  GOOD: 비율 ≥ 50%"
  echo "  FAIR: 비율 30~50%"
  echo "  POOR: 비율 < 30%"
fi

exit 0
