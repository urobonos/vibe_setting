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
  # self-nesting 가드: 산출물 저장소(`~/.claude/docs`) 내부 cwd → `claude-harness` 폴백.
  # basename 만 쓰면 `docs/참조문서` → product `참조문서` 로 잡혀 `docs/참조문서/tasks/` 빈 껍데기가 생긴다
  # (`session-completeness-check.sh` 가 tasks 를 선생성). `.claude` → `claude-harness` 와 같은 논리.
  case "$cwd" in
    */.claude/docs|*/.claude/docs/*) echo "claude-harness"; return ;;
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

# 예약된 비-product docs/ 하위 디렉토리 이름(2026-08-07 콜드리뷰 R3 M9) — `backlog-lifecycle.sh` 의
# product 예약이름 차단(8개)과 `doc-index-maintain.sh` 의 자기제외(2개)가 같은 사실("docs/ 아래 이
# 이름들은 실제 product 트리가 아니라 공용 SSOT 디렉토리")을 서로 다른 목록으로 인코딩하고 있어
# 하나가 늘어도 다른 쪽이 안 따라가면 곧 갈라진다. 공용 상수 1곳으로 올리고 양쪽이 참조한다.
RESERVED_DOCS_NAMES="working indexing references hooks scripts share source_tree 참조문서"

# 대소문자 무관 비교(참조문서는 대소문자 개념이 없어 영향 없음) — 호출부가 원본 표기를 그대로 넘기면
# 된다. 반환: 0=예약 이름(product 로 쓸 수 없음) / 1=아님.
is_reserved_docs_name() {
  local name="${1,,}" n
  for n in $RESERVED_DOCS_NAMES; do
    [ "$name" = "$n" ] && return 0
  done
  return 1
}
