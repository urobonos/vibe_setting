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
# Status / 상태 = 종결 마커 — 시작 라인 또는 YAML frontmatter 안 필드
#
# 종결 키워드 (2026-07-22 확장): Done / 완료 / 폐기 / Abandoned
#   Why: 폐기도 Done 과 동일한 종결 상태인데 구 정규식이 Done|완료 만 받아
#        폐기 문서가 working/ 에 영구 잔류했다 (실측: contact-channel-gap 이
#        2026-07-15 폐기 확정 후 7일간 잔류하며 /taskflow:load 목록을 오염).
#
# ⛔ 후행 사유(설명 부기)는 계속 불허 — 줄끝 앵커 `[[:space:]]*$` 유지.
#   backlog `working-lifecycle-posttooluse-misfire` 3사례(06-24·07-03·07-20)
#   해소 2택에서 **사용자 결정 = ① 문서 측 규약화(hook 무변경)**, ② 정규식
#   완화는 `Done — 아직 아님` 류 **오탐 여지**로 기각됐다 (2026-07-21).
#   2026-07-22 에 ②를 재도입했다가 오탐 4케이스 실측으로 확인 후 철회.
#   → 요약·사유는 `> 완료 요약: ...` 인용문으로 분리하고 마커는 단독 라인.
#   규약 SSOT = skills/task-docs/references/unified-template.md L11/L436/L450.
# ─────────────────────────────────────────────────────────
has_status_done() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qE '^(Status|상태):[[:space:]]*(Done|완료|폐기|Abandoned)[[:space:]]*$' "$file"
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

# ─────────────────────────────────────────────────────────
# 잔여 섹션(## 잔여 / ## TODO / ## Follow-up) 내부의 미체크박스(- [ ]) 존재 여부.
# Why: Status: Done 부착 시 잔여가 남았는데 tasks/ 로 이동하는 무검증 이동 방지
#      (working-lifecycle.sh move_working_to_tasks 가드, 2026-07-23 도입).
#      Self-Critique 등 다른 섹션의 위험기록 체크박스는 제외 — 섹션 스코프 한정(결정 2-A).
#      save now(/taskflow:done 슬래시 명시 이동)는 호출측 force 인자로 우회(결정 1-B).
# 반환: 0 = 잔여 섹션 미체크박스 존재(이동 차단) / 1 = 없음(이동 허용)
# 산출물 SSOT: docs/working/20260723/2026-07-23-claude-harness-done-gate-residual-block.md
# ─────────────────────────────────────────────────────────
has_residual_unchecked() {
  local file="$1"
  [ -f "$file" ] || return 1
  awk '
    /^##[[:space:]]+(잔여|TODO|Follow-up)/ { inres=1; next }
    /^##[[:space:]]/                        { inres=0 }
    inres && /^[[:space:]]*-[[:space:]]\[[[:space:]]\]/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}
