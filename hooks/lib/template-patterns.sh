#!/usr/bin/env bash
# template-patterns.sh — unified template 양식 검사 정규식 SSOT
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/template-patterns.sh"
#   has_status_done "$file" && has_self_critique_h2 "$file" && echo "양식 충족"
#
# SSOT 정합:
#   - skills/task-docs/references/unified-template.md L10 / L301 / L360 — `## Self-Critique` (h2) 엄격
#   - skills/task-docs/references/unified-template.md L10 — `^Status:\s*Done` (시작 라인) 엄격
#
# 본 lib 는 동일 정규식이 hook 본문에 박혀 N곳 동시 갱신을 요구하던 SSOT 분기를
# 단일 함수 호출 SSOT 로 통일한다 (audit S-3 / H-2 / H-3 묶음, 2026-05-13 도입).

# ─────────────────────────────────────────────────────────
# Status / 상태 = Done / 완료 — 시작 라인 또는 YAML frontmatter 안 필드
# ─────────────────────────────────────────────────────────
has_status_done() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qE '^(Status|상태):[[:space:]]*(Done|완료)[[:space:]]*$' "$file"
}

# ─────────────────────────────────────────────────────────
# ## Self-Critique (h2) — 엄격 매칭. h1/h3+ 매칭 안 됨.
# Why: unified-template.md L10 / L301 / L360 = h2 엄격 정의. SSOT.
# ─────────────────────────────────────────────────────────
has_self_critique_h2() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qE '^##[[:space:]]+.*Self-Critique' "$file"
}

# 양식 위반 헤딩 레벨 감지 — h1 / h3+ 형식의 Self-Critique 찾기 (사용자 경고용)
detect_self_critique_wrong_heading() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -nE '^#{3,}[[:space:]]+.*Self-Critique|^#{1}[[:space:]]+.*Self-Critique' "$file" 2>/dev/null | head -1
}

# ─────────────────────────────────────────────────────────
# 일반 섹션 h2 헤더 매칭 — has_section_h2 <file> <section_name>
# 예: has_section_h2 file.md "타당성 검토"
# Why: 정규식 분기를 줄이고 모든 양식 검사를 동일 함수로 통일.
# ─────────────────────────────────────────────────────────
has_section_h2() {
  local file="$1"
  local section="$2"
  [ -f "$file" ] && [ -n "$section" ] || return 1
  grep -qE "^##[[:space:]]+.*${section}" "$file"
}

# 양식 위반 헤딩 레벨 감지 일반화 — h1 / h3+ 형식의 임의 섹션
detect_section_wrong_heading() {
  local file="$1"
  local section="$2"
  [ -f "$file" ] && [ -n "$section" ] || return 1
  grep -nE "^#{3,}[[:space:]]+.*${section}|^#{1}[[:space:]]+.*${section}" "$file" 2>/dev/null | head -1
}

# ─────────────────────────────────────────────────────────
# unified 통합 완료 마커 검사 — Status: Done + ## Self-Critique 동시 충족
# Why: working-lifecycle.sh 자동 이동 트리거 SSOT.
# ─────────────────────────────────────────────────────────
has_unified_completion_markers() {
  local file="$1"
  has_status_done "$file" && has_self_critique_h2 "$file"
}
