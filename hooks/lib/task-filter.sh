#!/usr/bin/env bash
# task-filter.sh — 산출물 경로 분류 공용 판정 함수 (2026-05-13 도입)
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/task-filter.sh"
#   is_task_doc "$FILE_PATH" && echo "tasks 산출물"
#   is_special_summary "$(basename "$FILE_PATH")" && return 0  # skip
#
# SSOT: hook 들이 source 후 호출. CLAUDE.md §4.3 / Full Harness Audit (2026-05-13) 우선순위 1 결과물.
#
# Why:
# - 기존 = 7+ hook 가 동일한 정규식 패턴 (`/docs/[^/]+/tasks/[0-9]{8}/`) 을 본문에 박아 산재.
# - 신규 = 6개 분류 함수 SSOT 로 통일, bash `[[ =~ ]]` 우선 (외부 grep 호출 0).
# - 마이그레이션 = 기존 hook 본문의 인라인 정규식 매칭을 본 함수 호출로 점진 전환 (별 작업).
#
# 함수 일람:
#   is_task_doc <path>          — tasks/YYYYMMDD/{작업명}/ 하위 .md
#   is_output_doc <path>        — output/{category}/{topic}/ 하위 .md
#   is_working_doc <path>       — working/YYYYMMDD/ 하위 .md
#   is_special_summary <name>   — summary.md / history.md 식별 (basename 기준)
#   is_unified_doc <path>       — -unified.md suffix
#   is_3split_doc <path>        — -analyze.md / -plan.md / -result.md suffix

# ─────────────────────────────────────────────────────────
# is_task_doc <path> — tasks 산출물 경로 매칭
# ─────────────────────────────────────────────────────────
# 패턴: /docs/{product}/tasks/{YYYYMMDD}/{작업명}/{file}.md
is_task_doc() {
  local path="$1"
  [ -n "$path" ] || return 1
  [[ "$path" =~ /docs/[^/]+/tasks/[0-9]{8}/[^/]+/.+\.md$ ]]
}

# ─────────────────────────────────────────────────────────
# is_output_doc <path> — output 산출물 경로 매칭
# ─────────────────────────────────────────────────────────
# 패턴: /docs/{product}/output/{category}/{topic}/{file}.md
is_output_doc() {
  local path="$1"
  [ -n "$path" ] || return 1
  [[ "$path" =~ /docs/[^/]+/output/[^/]+/[^/]+/.+\.md$ ]]
}

# ─────────────────────────────────────────────────────────
# is_working_doc <path> — working 단일 통합 문서 경로 매칭
# ─────────────────────────────────────────────────────────
# 패턴: /docs/working/{YYYYMMDD}/{file}.md  (product 분리 없음, 글로벌 통합)
is_working_doc() {
  local path="$1"
  [ -n "$path" ] || return 1
  [[ "$path" =~ /docs/working/[0-9]{8}/.+\.md$ ]]
}

# ─────────────────────────────────────────────────────────
# is_special_summary <filename> — 누적 인덱스 파일 식별 (skip 표식용)
# ─────────────────────────────────────────────────────────
# 입력: basename (전체 경로 아님)
# 매칭: summary.md / history.md — 일반 산출물 양식 검사에서 제외 대상
is_special_summary() {
  local name="$1"
  [ -n "$name" ] || return 1
  [[ "$name" == "summary.md" || "$name" == "history.md" ]]
}

# ─────────────────────────────────────────────────────────
# is_unified_doc <path> — 단일 통합 문서 suffix 식별
# ─────────────────────────────────────────────────────────
# 패턴: ...-unified.md  (2026-05-12~ 신규 정책)
is_unified_doc() {
  local path="$1"
  [ -n "$path" ] || return 1
  [[ "$path" =~ -unified\.md$ ]]
}

# ─────────────────────────────────────────────────────────
# is_3split_doc <path> — 3종 분리 산출물 suffix 식별 (역소급 면제, < 2026-05-12)
# ─────────────────────────────────────────────────────────
# 패턴: ...-analyze.md / ...-plan.md / ...-result.md
is_3split_doc() {
  local path="$1"
  [ -n "$path" ] || return 1
  [[ "$path" =~ -(analyze|plan|result)\.md$ ]]
}
