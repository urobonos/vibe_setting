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
  # trailing slash 제거 (단 단일 '/' 루트는 보존)
  if [ "${#input}" -gt 1 ]; then
    input="${input%/}"
  fi
  printf '%s\n' "$input"
}
