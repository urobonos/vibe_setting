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
#   - Windows 경로(\\) 는 UNIX(/) 로 정규화

resolve_product() {
  local cwd="${1:-$PWD}"
  cwd="${cwd//\\//}"
  cwd="${cwd%/}"
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
