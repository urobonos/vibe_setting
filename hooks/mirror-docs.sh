#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PostToolUse:Edit|Write Hook — api-docs 3-way 미러링
#
# 대상:
#   ~/.claude/docs/{product}/api-docs/**  → C:/Works/hongcafe_global_backend/api-docs/**
#                                          + C:/Works/hongcafe_global_docs/be/api-docs/**
#
# 정책:
#   - 자동 cp (3회 재시도, 200ms 간격)
#   - 실패 시 stderr 보고 + exit 0 (PostToolUse 차단 회피)
#   - 미러링 루트 디렉토리(be/docs 프로젝트) 미존재 시 SKIP
#   - specs/ 미러링은 2026-05-04 사용자 결정으로 제거 (글로벌 specs/ SSOT 단일화)

source "$(dirname "$0")/lib/hook-input.sh"
hook_init
hook_read_stdin
hook_parse_file_path

FILE_PATH=$(echo "$FILE_PATH" | tr '\\' '/')

# api-docs/ 하위가 아니면 통과
echo "$FILE_PATH" | grep -qiE '/\.claude/docs/[^/]+/api-docs/' || exit 0

[ -f "$FILE_PATH" ] || exit 0

# 상대경로 추출 (bash parameter expansion)
AFTER_DOCS="${FILE_PATH#*/.claude/docs/}"        # hongcafe_global_backend/api-docs/auth/login.md
PRODUCT="${AFTER_DOCS%%/*}"                       # hongcafe_global_backend
AFTER_PRODUCT="${AFTER_DOCS#*/}"                  # api-docs/auth/login.md
CATEGORY="${AFTER_PRODUCT%%/*}"                   # api-docs
REL_PATH="${AFTER_PRODUCT#*/}"                    # auth/login.md

if [ "$CATEGORY" != "api-docs" ]; then
  exit 0
fi

if [ -z "$REL_PATH" ] || [ "$REL_PATH" = "$AFTER_PRODUCT" ]; then
  echo "[MIRROR] $FILE_PATH: 상대경로 추출 실패 — skip" >&2
  exit 0
fi

BE_BASE="C:/Works/hongcafe_global_backend"
DOCS_BASE="C:/Works/hongcafe_global_docs"

BE_DEST="$BE_BASE/api-docs/$REL_PATH"
DOCS_DEST="$DOCS_BASE/be/api-docs/$REL_PATH"

mirror_one() {
  local src="$1"
  local dest="$2"
  local label="$3"
  local root_base="$4"

  if [ ! -d "$root_base" ]; then
    echo "[MIRROR] SKIP $label: $root_base 디렉토리 없음 (프로젝트 미클론)" >&2
    return 0
  fi

  local target_dir
  target_dir=$(dirname "$dest")

  for attempt in 1 2 3; do
    mkdir -p "$target_dir" 2>/dev/null
    # 2초 timeout — 네트워크 드라이브 hang 방지 (timeout coreutils Git Bash 포함)
    if timeout 2 cp -f "$src" "$dest" 2>/dev/null; then
      if [ "$attempt" -gt 1 ]; then
        echo "[MIRROR] OK ($attempt/3) $label: $dest" >&2
      fi
      return 0
    fi
    sleep 0.2
  done
  echo "[MIRROR] FAIL $label after 3 retries: $src → $dest" >&2
  return 1
}

mirror_one "$FILE_PATH" "$BE_DEST" "BE" "$BE_BASE"
mirror_one "$FILE_PATH" "$DOCS_DEST" "DOCS" "$DOCS_BASE"

exit 0
