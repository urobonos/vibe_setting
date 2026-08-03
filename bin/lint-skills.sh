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
#   L6. depends_on 의 모든 스킬 실재 (글로벌 스킬 폴더 + `{plugin}:{skill}` 네임스페이스)
#   L7. conflicts_with 의 모든 스킬 실재 + 자기 참조 경고 (L6 과 동일 네임스페이스 해석)
#   L8. depends_on 순환 의존 감지 (DAG 그래프 + DFS, 2026-05-13 신규, CLAUDE.md §5.4)
#   L9. version semver 형식 검증 (^\d+\.\d+\.\d+$, 2026-05-13 신규, CLAUDE.md §5.4)
#   L10. min_claude_md_version 호환성 검증 (CLAUDE.md 현재 버전과 대조, 2026-05-13 신규)
#
# 사용법:
#   bash ~/.claude/bin/lint-skills.sh                    # 글로벌 모든 스킬 검증
#   bash ~/.claude/bin/lint-skills.sh --skill aws        # 특정 스킬만
#   bash ~/.claude/bin/lint-skills.sh --strict           # 경고도 FAIL 처리 (CI 모드)
#   bash ~/.claude/bin/lint-skills.sh --json             # JSON 출력 (스크립트 통합용)

SKILLS_DIR="${HOME}/.claude/skills"
PLUGINS_DIR="${HOME}/.claude/custom-plugin"
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
    --plugins-dir) PLUGINS_DIR="$2"; shift 2 ;;
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

# ─────────────────────────────────────────────────────────
# L8 사전 준비: depends_on 순환 의존 그래프 빌드 + DFS 순환 탐지 (Python)
# 2026-05-13 신규, CLAUDE.md §5.4 "depends_on 방향성"
# ─────────────────────────────────────────────────────────
CIRCULAR_DEPS=$(SKILLS_DIR="$SKILLS_DIR" python3 - <<'PYEOF' 2>/dev/null
import os, re
from collections import defaultdict

skills_dir = os.environ.get('SKILLS_DIR', os.path.expanduser('~/.claude/skills'))
graph = defaultdict(list)
try:
    skill_names = sorted(os.listdir(skills_dir))
except OSError:
    print('')
    raise SystemExit(0)

for skill in skill_names:
    sm = os.path.join(skills_dir, skill, 'SKILL.md')
    if not os.path.isfile(sm):
        continue
    try:
        with open(sm, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read(20000)
    except OSError:
        continue
    # depends_on: [a, b, c] (inline) 또는 depends_on:\n  - a\n  - b (block)
    m = re.search(r'^depends_on:[ \t]*\[([^\]]*)\]', content, re.MULTILINE)
    deps = []
    if m:
        deps = re.findall(r'[a-z][a-z0-9_:-]+', m.group(1))
    else:
        m2 = re.search(r'^depends_on:[ \t]*\n((?:[ \t]+-[ \t]*[^\n]+\n?)+)', content, re.MULTILINE)
        if m2:
            for line in m2.group(1).splitlines():
                t = re.search(r'-[ \t]*"?([a-z][a-z0-9_:-]+)"?', line)
                if t:
                    deps.append(t.group(1))
    graph[skill] = deps

WHITE, GRAY, BLACK = 0, 1, 2
color = defaultdict(lambda: WHITE)
cycles = []

def dfs(node, path):
    color[node] = GRAY
    path.append(node)
    for nb in graph.get(node, []):
        if color[nb] == GRAY:
            idx = path.index(nb) if nb in path else 0
            cycle = path[idx:] + [nb]
            cycles.append(','.join(cycle))
        elif color[nb] == WHITE:
            dfs(nb, list(path))
    color[node] = BLACK

for n in list(graph.keys()):
    if color[n] == WHITE:
        dfs(n, [])

if cycles:
    seen = set()
    for c in cycles:
        # 같은 순환 (회전된 동일 cycle) 정규화
        nodes = c.split(',')
        if len(nodes) < 2:
            continue
        min_idx = nodes.index(min(nodes[:-1]))
        norm = nodes[min_idx:-1] + nodes[:min_idx]
        norm.append(norm[0])
        norm_str = ','.join(norm)
        if norm_str in seen:
            continue
        seen.add(norm_str)
        print(norm_str)
PYEOF
)

# CLAUDE.md 버전 추출 (L10 호환성 검증용)
# 우선순위: (a) Multi-Agent Orchestration: Full Specification (vX.Y) (b) v4.0 류 본문 토큰
CLAUDE_MD_FILE="$HOME/.claude/CLAUDE.md"
CLAUDE_MD_VERSION=""
if [ -f "$CLAUDE_MD_FILE" ]; then
  CLAUDE_MD_VERSION=$(grep -oE '\(v[0-9]+\.[0-9]+(\.[0-9]+)?\)' "$CLAUDE_MD_FILE" 2>/dev/null | head -1 | sed 's/^(v//; s/)$//')
  [ -z "$CLAUDE_MD_VERSION" ] && CLAUDE_MD_VERSION=$(grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' "$CLAUDE_MD_FILE" 2>/dev/null | head -1 | sed 's/^v//')
fi
[ -z "$CLAUDE_MD_VERSION" ] && CLAUDE_MD_VERSION="4.0"
# semver 형식 (X.Y) → X.Y.0 보정 (sort -V 호환성)
echo "$CLAUDE_MD_VERSION" | grep -qE '^[0-9]+\.[0-9]+$' && CLAUDE_MD_VERSION="${CLAUDE_MD_VERSION}.0"

# --- 스킬 참조 해석 (L6/L7 공용) ---
# 글로벌 스킬 폴더 + `{plugin}:{skill}` 네임스페이스 (custom-plugin/{plugin}/skills/{skill}/SKILL.md).
# Why: 플러그인 이동(2026-07-15) 후에도 해석기가 글로벌 폴더만 조회해 `hongcafe:mysql8` 이 상시
#      L6-FAIL -> lint 가 항상 exit 1 = 신호 자체가 죽었다. frontmatter 가 아니라 해석기가 틀렸다.
skill_ref_exists() {
  local ref="$1"
  echo "$ALL_SKILLS" | grep -qx "$ref" && return 0
  case "$ref" in
    *:*)
      [ -f "$PLUGINS_DIR/${ref%%:*}/skills/${ref##*:}/SKILL.md" ] && return 0
      ;;
  esac
  return 1
}

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

  # L4 — 자기 스킬 폴더 내 references 만 매칭. 절대경로(~/.claude/docs/references/...) 제외.
  local refs_in_body
  refs_in_body=$(grep -oE '(^|[^/~.])references/[a-z0-9_-]+\.md' "$skill_md" 2>/dev/null | sed -E 's/^[^a-zA-Z]//' | sort -u)
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
      if ! skill_ref_exists "$dep"; then
        missing_deps+=("$dep")
      fi
    done <<< "$deps"
  fi
  if [ "${#missing_deps[@]}" -gt 0 ]; then
    issues+=("L6-FAIL: depends_on 미존재 스킬: ${missing_deps[*]}")
    status="FAIL"
  fi

  # L7 — conflicts_with 실존 검증 + 자기 참조 경고
  local cwiths
  cwiths=$(grep -E '^conflicts_with:' "$skill_md" | sed 's/^conflicts_with:[[:space:]]*//; s/[][]//g' | tr ',' '\n' | tr -d ' ')
  local missing_cwiths=()
  local self_ref=0
  if [ -n "$cwiths" ]; then
    while IFS= read -r cw; do
      if [ -z "$cw" ]; then
        continue
      fi
      if [ "$cw" = "$skill_name" ]; then
        self_ref=1
        continue
      fi
      if ! skill_ref_exists "$cw"; then
        missing_cwiths+=("$cw")
      fi
    done <<< "$cwiths"
  fi
  if [ "${#missing_cwiths[@]}" -gt 0 ]; then
    issues+=("L7-FAIL: conflicts_with 미존재 스킬: ${missing_cwiths[*]}")
    status="FAIL"
  fi
  if [ "$self_ref" = "1" ]; then
    issues+=("L7-WARN: conflicts_with 자기 참조 — 의도 명시 권고")
    [ "$status" = "PASS" ] && status="WARN"
  fi

  # L8 — depends_on 순환 의존 (CIRCULAR_DEPS 사전 빌드 결과 매칭, 2026-05-13 신규)
  if [ -n "$CIRCULAR_DEPS" ]; then
    while IFS= read -r cyc; do
      [ -z "$cyc" ] && continue
      # cyc = "a,b,c,a" 형식. 본 스킬이 cycle 안 첫 노드인 경우만 보고 (중복 방지)
      local first_node
      first_node=$(echo "$cyc" | cut -d',' -f1)
      if [ "$first_node" = "$skill_name" ]; then
        local cyc_display
        cyc_display=$(echo "$cyc" | tr ',' '→' | sed 's/→/ → /g')
        issues+=("L8-FAIL: depends_on 순환 의존 — $cyc_display (CLAUDE.md §5.4)")
        status="FAIL"
      fi
    done <<< "$CIRCULAR_DEPS"
  fi

  # L9 — version semver 형식 검증 (^\d+\.\d+\.\d+$, 2026-05-13 신규)
  # L8 (depends_on 순환) 은 전체 스킬 그래프 필요 → 본 함수 외부 (lint_circular_deps) 에서 일괄 처리
  # L10 (min_claude_md_version 호환성) 도 CLAUDE.md 버전 read 후 일괄 처리
  local version_raw
  version_raw=$(grep -E '^version:' "$skill_md" | head -1 | sed 's/^version:[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//')
  if [ -n "$version_raw" ]; then
    if ! echo "$version_raw" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      issues+=("L9-WARN: version '$version_raw' semver 형식 불일치 (^\\d+.\\d+.\\d+$) — CLAUDE.md §5.4 (2026-05-13)")
      [ "$status" = "PASS" ] && status="WARN"
    fi
  fi

  # L10 — min_claude_md_version 호환성 (CLAUDE.md 현재 버전 < 스킬 요구 시 FAIL)
  local skill_min_ver skill_min_ver_norm
  skill_min_ver=$(grep -E '^min_claude_md_version:' "$skill_md" | head -1 | sed 's/^min_claude_md_version:[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//')
  if [ -n "$skill_min_ver" ] && [ -n "$CLAUDE_MD_VERSION" ]; then
    # 4.0 → 4.0.0 normalize (CLAUDE_MD_VERSION 도 동일 룰 적용됨)
    skill_min_ver_norm="$skill_min_ver"
    echo "$skill_min_ver_norm" | grep -qE '^[0-9]+\.[0-9]+$' && skill_min_ver_norm="${skill_min_ver_norm}.0"
    # 요구 ≤ 현재 이면 OK (정렬 순서)
    if printf '%s\n%s\n' "$skill_min_ver_norm" "$CLAUDE_MD_VERSION" | sort -V -C; then
      : # 요구 ≤ 현재, OK
    else
      issues+=("L10-FAIL: min_claude_md_version '$skill_min_ver' > CLAUDE.md 현재 '$CLAUDE_MD_VERSION' (미래 요구사항)")
      status="FAIL"
    fi
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
