#!/bin/bash
# audit-references.sh
# 스킬·플러그인 커맨드 간 § 참조 무결성 검증 — lint-skills.sh L4 (자기 폴더 references/) 의 보완.
#
# 스캔 대상 (출처):
#   - 글로벌 스킬                 ~/.claude/skills/{skill}/SKILL.md
#   - 플러그인 스킬               ~/.claude/custom-plugin/{plugin}/skills/{skill}/SKILL.md
#   - 플러그인 커맨드·에이전트    ~/.claude/custom-plugin/{plugin}/{commands,agents}/*.md
#
# 참조 형식 (2종):
#   - 숫자형  `{target} §4.3`     → 대상 파일에 `^#{1,6} §?4.3` 헤더 존재 검증
#   - 인용형  `{target} §"이름"`  → 대상 파일 `^#{1,6}` 헤더 중 "이름" 을 축자 포함하는 것 존재 검증
#
# {target} 해석 순서: (1) 이름 레지스트리 exact 매칭 (2) 하니스 루트 기준 경로.
#   레지스트리 키 = 글로벌 스킬명 / {plugin}:{skill} / {skill} / {plugin}:{cmd} / /{plugin}:{cmd}
#                   / {cmd}.md / CLAUDE.md   (동일 키 충돌 시 첫 매칭 — 현재 충돌 0건)
#   해석 실패 = 자연어 § 이므로 skip (참조 카운트 제외).
#
# 사용법:
#   bash ~/.claude/bin/audit-references.sh                    # 전체
#   bash ~/.claude/bin/audit-references.sh --skill aws        # 단일 출처 (스킬명 또는 경로 조각)
#   bash ~/.claude/bin/audit-references.sh --strict           # WARN 도 FAIL
#   bash ~/.claude/bin/audit-references.sh --json             # JSON 출력

HARNESS_ROOT="${HOME}/.claude"
SKILLS_DIR="${HARNESS_ROOT}/skills"
PLUGINS_DIR="${HARNESS_ROOT}/custom-plugin"
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
    --plugins-dir) PLUGINS_DIR="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | head -25
      exit 0
      ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
  esac
done

if [ "$JSON" = "0" ]; then
  echo "━━━ Skill/Plugin § 참조 무결성 — $(date '+%Y-%m-%d %H:%M') ━━━"
  echo "스캔 루트: $SKILLS_DIR + $PLUGINS_DIR"
  [ -n "$TARGET_SKILL" ] && echo "대상: $TARGET_SKILL (출처 기준)"
  echo ""
fi

rel_label() {
  echo "${1#$HARNESS_ROOT/}"
}

# --- 출처 파일 수집 ---
collect_sources() {
  local d p sd f
  for d in "$SKILLS_DIR"/*/; do
    [ -f "${d}SKILL.md" ] && echo "${d}SKILL.md"
  done
  for p in "$PLUGINS_DIR"/*/; do
    for sd in "${p}skills"/*/; do
      [ -f "${sd}SKILL.md" ] && echo "${sd}SKILL.md"
    done
    for f in "${p}commands"/*.md "${p}agents"/*.md; do
      [ -f "$f" ] && echo "$f"
    done
  done
}

# --- 참조 대상 이름 레지스트리 ("키<TAB>경로") ---
build_target_map() {
  local d p sd cf n s c
  for d in "$SKILLS_DIR"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    n=$(basename "$d")
    printf '%s\t%s\n' "$n" "${d}SKILL.md"
  done
  for p in "$PLUGINS_DIR"/*/; do
    n=$(basename "$p")
    for sd in "${p}skills"/*/; do
      [ -f "${sd}SKILL.md" ] || continue
      s=$(basename "$sd")
      printf '%s\t%s\n' "$n:$s" "${sd}SKILL.md"
      printf '%s\t%s\n' "$s" "${sd}SKILL.md"
    done
    for cf in "${p}commands"/*.md; do
      [ -f "$cf" ] || continue
      c=$(basename "$cf" .md)
      printf '%s\t%s\n' "$n:$c" "$cf"
      printf '%s\t%s\n' "/$n:$c" "$cf"
      printf '%s\t%s\n' "$c.md" "$cf"
    done
  done
  [ -f "$HARNESS_ROOT/CLAUDE.md" ] && printf '%s\t%s\n' "CLAUDE.md" "$HARNESS_ROOT/CLAUDE.md"
}

SOURCE_FILES=$(collect_sources)
TARGET_MAP=$(build_target_map)

# --- 참조 대상 → 실제 파일 경로 (exit 1 = 해석 불가 = 자연어 §) ---
resolve_target() {
  local raw="$1" hit rel
  hit=$(printf '%s\n' "$TARGET_MAP" | awk -F'\t' -v k="$raw" '$1==k {print $2; exit}')
  if [ -n "$hit" ]; then
    echo "$hit"
    return 0
  fi
  case "$raw" in
    */*)
      rel="${raw#\~}"
      rel="${rel##*/.claude/}"
      rel="${rel#/}"
      if [ -n "$rel" ] && [ -f "$HARNESS_ROOT/$rel" ]; then
        echo "$HARNESS_ROOT/$rel"
        return 0
      fi
      ;;
  esac
  return 1
}

# --- 숫자형 §N 헤더 존재 확인 ---
section_exists() {
  local file="$1" section="$2" section_re
  [ -f "$file" ] || return 1
  section_re=$(printf '%s' "$section" | sed 's/\./\\./g')
  # 패턴 1: ## N. / ## N-M / ## §N.M  (§ 접두 = CLAUDE.md §4.x 형)
  #   '§' 는 2바이트 UTF-8 — `§?` 로 쓰면 C locale 에서 뒷바이트만 optional 이 되어
  #   앞바이트가 필수로 남고 전 숫자형 매칭이 통째로 실패한다. 반드시 `(§)?` 로 그룹화한다.
  grep -qE "^#{1,6}[[:space:]]+(§)?${section_re}(\.|-|\b|[[:space:]])" "$file" && return 0
  # 패턴 2: ### {제목} (N) / (N-M) — 라벨 형식
  grep -qE "^#{1,6}[[:space:]]+.*\(${section_re}(-[0-9]+)?\)" "$file" && return 0
  return 1
}

# --- 인용형 §"이름" 앵커 존재 확인 (축자 부분일치) ---
# 앵커 2종: (1) `^#{1,6}` 헤더  (2) 줄머리 굵은글씨 런 `**...**`
#   (2) 를 넣는 이유 = 본 하니스의 절 앵커가 실제로 굵은글씨 불릿이다
#   (CLAUDE.md `- **룰명:**` / aws `> **[실행 주체]**` / auto.md `**재토론 금지 원칙 (...):**`).
#   헤더만 인정하면 살아있는 포인터 3건이 FAIL 로 잡혀 신호가 죽는다 (lint L6 상시 FAIL 과 같은 실패형).
#   축자 부분일치라 `verify+review` vs `verify + review` 같은 표기 불일치는 그대로 잡힌다.
section_named_exists() {
  local file="$1" name="$2"
  [ -f "$file" ] || return 1
  awk -v needle="$name" '
    function bold_run(l,   p, q, rest) {
      if (l !~ /^[ \t]*([>*+-][ \t]+)*\*\*/) return ""
      p = index(l, "**")
      rest = substr(l, p + 2)
      q = index(rest, "**")
      if (q == 0) return ""
      return substr(rest, 1, q - 1)
    }
    substr($0,1,1) == "#" && index($0, needle) > 0 { found = 1; exit }
    { b = bold_run($0); if (b != "" && index(b, needle) > 0) { found = 1; exit } }
    END { exit found ? 0 : 1 }
  ' "$file"
}

REF_RE='[A-Za-z0-9_~][A-Za-z0-9_+.:/~-]*[`)]?[[:space:]]+§[[:space:]]*("[^"]+"|[0-9]+(\.[0-9]+)*(-[0-9]+)?)'

audit_file() {
  local source_md="$1"
  local source_label
  source_label=$(rel_label "$source_md")

  local file_refs=0 file_broken=0
  local matches
  matches=$(grep -nE "$REF_RE" "$source_md" 2>/dev/null)
  [ -z "$matches" ] && return 0

  local line lineno content pairs pair target_raw section sec_kind target_md target_label ok
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    lineno=${line%%:*}
    content=${line#*:}
    pairs=$(printf '%s' "$content" | grep -oE "$REF_RE" 2>/dev/null)
    while IFS= read -r pair; do
      [ -z "$pair" ] && continue
      target_raw=$(printf '%s' "$pair" | sed -E 's/[`)]?[[:space:]]+§[[:space:]]*("|[0-9]).*$//')
      [ -z "$target_raw" ] && continue

      case "$pair" in
        *'§'*'"'*)
          sec_kind="named"
          section=$(printf '%s' "$pair" | sed -E 's/^.*§[[:space:]]*"//; s/"$//')
          ;;
        *)
          sec_kind="num"
          section=$(printf '%s' "$pair" | sed -E 's/^.*§[[:space:]]*//; s/-[0-9]+$//')
          ;;
      esac
      [ -z "$section" ] && continue

      target_md=$(resolve_target "$target_raw") || continue
      [ "$target_md" = "$source_md" ] && continue

      file_refs=$((file_refs + 1))
      TOTAL_REFS=$((TOTAL_REFS + 1))

      ok=0
      if [ "$sec_kind" = "named" ]; then
        section_named_exists "$target_md" "$section" && ok=1
      else
        section_exists "$target_md" "$section" && ok=1
      fi

      if [ "$ok" -eq 0 ]; then
        target_label=$(rel_label "$target_md")
        file_broken=$((file_broken + 1))
        BROKEN_REFS=$((BROKEN_REFS + 1))
        if [ "$JSON" = "1" ]; then
          RESULTS+=("{\"source\":\"$source_label\",\"target\":\"$target_label\",\"section\":\"${section//\"/\\\"}\",\"kind\":\"$sec_kind\",\"line\":$lineno}")
        elif [ "$sec_kind" = "named" ]; then
          echo "  [BROKEN] $source_label:$lineno  →  $target_label §\"$section\"  (대상 앵커 없음 — 축자 불일치 의심)"
        else
          echo "  [BROKEN] $source_label:$lineno  →  $target_label §$section  (대상 헤더 없음)"
        fi
        EXIT_CODE=1
      fi
    done <<< "$pairs"
  done <<< "$matches"

  if [ "$JSON" = "0" ] && [ "$file_refs" -gt 0 ] && [ "$file_broken" -eq 0 ]; then
    printf "[PASS] %-52s — %d refs OK\n" "$source_label" "$file_refs"
  fi
}

while IFS= read -r src; do
  [ -z "$src" ] && continue
  if [ -n "$TARGET_SKILL" ]; then
    case "$src" in
      *"$TARGET_SKILL"*) ;;
      *) continue ;;
    esac
  fi
  audit_file "$src"
done <<< "$SOURCE_FILES"

if [ "$JSON" = "1" ]; then
  joined=$(IFS=,; echo "${RESULTS[*]}")
  echo "{\"total_refs\":$TOTAL_REFS,\"broken\":$BROKEN_REFS,\"results\":[$joined]}"
else
  echo ""
  echo "━━━ 요약 ━━━"
  echo "총 § 참조: $TOTAL_REFS / 깨진 참조: $BROKEN_REFS"
  [ "$EXIT_CODE" -ne 0 ] && echo "exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
