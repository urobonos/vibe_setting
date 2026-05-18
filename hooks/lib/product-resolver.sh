#!/usr/bin/env bash
# product-resolver.sh
# CWD 를 {product} 이름으로 변환해 `~/.claude/docs/{product}/` 경로를 산출한다.
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/product-resolver.sh"
#   PRODUCT=$(resolve_product "$CWD")
#   DOCS_ROOT=$(product_docs_root "$CWD")
#
# 규칙:
#   - 기본값: basename $CWD
#   - `.claude` → `claude-harness` (숨김 디렉토리명 회피)
#   - `~/.claude/worktrees/{session_id}-{slug}` → 원본 repo cwd 로 역해석 후 basename (자동진행 worktree-first)
#   - Windows 경로(\\) 는 UNIX(/) 로 정규화

# worktree 안에서 호출 시 원본 repo cwd 역해석.
# `git rev-parse --git-common-dir` = worktree 안에서 원본 repo `.git` 절대 경로 반환.
# 원본 repo 가 아니거나 git repo 자체가 아니면 입력 cwd 그대로 반환.
resolve_origin_cwd() {
  local cwd="${1:-$PWD}"
  cwd="${cwd//\\//}"
  cwd="${cwd%/}"
  # ~/.claude/worktrees/ 경로 패턴이 아니면 즉시 입력 cwd 반환 (성능 보존)
  case "$cwd" in
    */.claude/worktrees/*) ;;
    *) echo "$cwd"; return ;;
  esac
  # git rev-parse --git-common-dir 시도 — 실패 시 입력 cwd fallback
  local git_common
  git_common=$(cd "$cwd" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)
  if [ -z "$git_common" ] || [ "$git_common" = ".git" ]; then
    echo "$cwd"; return
  fi
  # 상대경로 → 절대경로 보정 (Windows 드라이브 절대경로 `C:/...` 도 절대경로로 인식)
  case "$git_common" in
    /*) ;;
    [A-Za-z]:/*) ;;
    [A-Za-z]:\\*) ;;
    *) git_common="$cwd/$git_common" ;;
  esac
  git_common="${git_common//\\//}"
  # /path/to/repo/.git → /path/to/repo
  local origin
  origin=$(dirname "$git_common")
  origin="${origin//\\//}"
  echo "$origin"
}

resolve_product() {
  local cwd="${1:-$PWD}"
  cwd="${cwd//\\//}"
  cwd="${cwd%/}"
  # worktree 안 호출 = 원본 repo cwd 로 역해석 (자동진행 worktree-first 정합)
  case "$cwd" in
    */.claude/worktrees/*)
      cwd=$(resolve_origin_cwd "$cwd")
      cwd="${cwd//\\//}"
      cwd="${cwd%/}"
      ;;
  esac
  local base
  base=$(basename "$cwd")
  case "$base" in
    .claude) echo "claude-harness" ;;
    *)       echo "$base" ;;
  esac
}

product_docs_root() {
  local cwd="${1:-$PWD}"
  local product
  product=$(resolve_product "$cwd")
  local home_unix="${HOME//\\//}"
  echo "$home_unix/.claude/docs/$product"
}

product_tasks_dir() {
  echo "$(product_docs_root "${1:-$PWD}")/tasks"
}

product_output_dir() {
  echo "$(product_docs_root "${1:-$PWD}")/output"
}

product_specs_dir() {
  echo "$(product_docs_root "${1:-$PWD}")/specs"
}
