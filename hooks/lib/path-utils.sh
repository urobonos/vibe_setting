#!/usr/bin/env bash
# path-utils.sh — 경로 정규화 공용 함수 (2026-05-13 도입)
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh"
#   FILE_PATH=$(normalize_path "$FILE_PATH")
#
# SSOT: hook 들이 source 후 호출. CLAUDE.md §4.3 / Full Harness Audit (2026-05-13) 우선순위 1 결과물.
#
# Why:
# - 기존 = 11+ hook 가 `tr '\\\\' '/'` + `${FILE_PATH%/}` 2단계 변환을 본문에 박아두고 있음.
# - 신규 = 단일 함수 SSOT 로 통일, Windows(\\) ↔ POSIX(/) 경로 + trailing slash 일관 처리.
# - 마이그레이션 = 기존 hook 본문의 인라인 정규화 코드를 본 함수 호출로 점진 전환 (별 작업).

# ─────────────────────────────────────────────────────────
# normalize_path [path] — 경로 정규화 (백슬래시→슬래시 + trailing slash 제거)
# ─────────────────────────────────────────────────────────
# 입력: 1번째 인자 또는 stdin (인자 없을 시)
# 출력: stdout (정규화된 경로 1줄)
# Windows 경로 (C:\Users\PV) → C:/Users/PV / 양쪽 안전.
normalize_path() {
  local input
  if [ $# -gt 0 ]; then
    input="$1"
  else
    IFS= read -r input
  fi
  # 백슬래시 → 슬래시
  input="${input//\\//}"
  # 중복 슬래시 붕괴 — JSON-escaped 백슬래시(\\)가 bash 정규식 추출 경로에서 //(더블슬래시)로 남는 문제 정합
  # (working-lifecycle 는 python json.load 로 회피, 본 SSOT 는 fork-free bash 붕괴로 전 hook 정합, 2026-07-09).
  while [[ "$input" == *//* ]]; do input="${input//\/\//\/}"; done
  # trailing slash 제거 (단 단일 '/' 루트는 보존)
  if [ "${#input}" -gt 1 ]; then
    input="${input%/}"
  fi
  printf '%s\n' "$input"
}

# ─────────────────────────────────────────────────────────
# is_hard_code_file [path] — hard-code 파일 판정 (2026-07-08, plan-before 게이트용)
# ─────────────────────────────────────────────────────────
# 반환: 0 = hard-code (계획 게이트 대상) / 1 = 아님(면제)
# 대상 확장자: .php .js .ts .py .sql (대소문자 무시)
# 면제(확장자 무관): 하니스 운영 영역(.claude/hooks·docs·commands·skills·agents·lib·memory·bin)·
#   CLAUDE.md/README.md/MEMORY.md·문서(docs/). worktree(~/.claude/worktrees/)는 제품 코드
#   작업공간이라 면제 아님 — 확장자만으로 판정.
# SSOT: 코드 라이프사이클 게이트 (docs/claude-harness/output/analysis/2026-07-08-code-lifecycle-enforcement).
is_hard_code_file() {
  local path lower
  path=$(normalize_path "$1")
  # worktree = 제품 코드 작업공간 → 하니스 면제 로직 건너뛰고 확장자만 판정
  case "$path" in
    */.claude/worktrees/*)
      lower="${path,,}"
      case "$lower" in *.php|*.js|*.ts|*.py|*.sql) return 0 ;; esac
      return 1
      ;;
  esac
  # 하니스 운영 영역·문서 면제 (확장자 무관)
  case "$path" in
    */.claude/hooks/*|*/.claude/docs/*|*/.claude/commands/*|*/.claude/skills/*|*/.claude/agents/*|*/.claude/lib/*|*/.claude/memory/*|*/.claude/bin/*) return 1 ;;
    */CLAUDE.md|*/README.md|*/MEMORY.md) return 1 ;;
    */docs/*) return 1 ;;
  esac
  # 확장자 allowlist
  lower="${path,,}"
  case "$lower" in
    *.php|*.js|*.ts|*.py|*.sql) return 0 ;;
  esac
  return 1
}
