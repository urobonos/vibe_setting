#!/usr/bin/env bash
# 개발자·리뷰어 모델 전환 — 에이전트 정의 frontmatter 의 model: 줄을 바꾼다.
# code-loop(custom-plugin/taskflow/bin/code-loop.sh)와 tick(Agent spawn)이 모두 이 줄을 읽으므로 여기 한 곳만 바꾸면 된다.
#
# 사용: set-models.sh                    현재 값 표시
#       set-models.sh dev=opus rev=opus  역할별 전환 (opus | sonnet | haiku)
set -euo pipefail

AGENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../agents" && pwd)"

# 역할 → 정의 파일. cold-reviewer 는 두 리뷰어를 합친 하위 호환 정의라 리뷰어와 같이 움직인다
role_files() {
  case "$1" in
    dev) echo "step-developer.md" ;;
    rev) echo "reviewer-correctness.md reviewer-design.md cold-reviewer.md" ;;
    *) return 1 ;;
  esac
}

current() {
  sed -n '1,/^---$/{/^model:[[:space:]]*/{s///;p;q;}}' "$AGENTS/$1"
}

show() {
  for role in dev rev; do
    for f in $(role_files "$role"); do
      printf '%-4s %-26s %s\n' "$role" "$f" "$(current "$f")"
    done
  done
}

if [ $# -eq 0 ]; then
  show
  exit 0
fi

for arg in "$@"; do
  role="${arg%%=*}" model="${arg#*=}"
  files=$(role_files "$role") || { echo "알 수 없는 역할: $role (dev | rev)" >&2; exit 1; }
  case "$model" in
    opus|sonnet|haiku) ;;
    *) echo "알 수 없는 모델: $model (opus | sonnet | haiku)" >&2; exit 1 ;;
  esac
  for f in $files; do
    # frontmatter 범위(첫 줄 --- ~ 닫는 ---) 안의 model: 줄만 바꾼다 — 본문의 같은 문자열은 건드리지 않는다
    sed -i "1,/^---\$/{s/^model:.*/model: $model/}" "$AGENTS/$f"
  done
done
show
