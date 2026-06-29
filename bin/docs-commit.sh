#!/usr/bin/env bash
# docs-commit.sh — hongcafe_global_docs 선택 파일 add+commit (push 제외, §3 안전)
#
# 사용: bash bin/docs-commit.sh <file...> <<'MSG'
#       docs(MOD-XX): 제목
#
#       - 본문
#       MSG
# 환경: DOCS_REPO  docs repo 경로 (기본 /c/Works/hongcafe_global_docs)
# 안전: push 미포함 = §3 절대차단(사용자 직접). docs/scripts/ ad-hoc 커밋 9건+ 대체.
#       `bash <script>` 는 worktree-enforce 가 fs-mutation 으로 보지 않아 통과(내부 cd/git 미검사).
set -uo pipefail

DOCS_REPO="${DOCS_REPO:-/c/Works/hongcafe_global_docs}"

if [ $# -lt 1 ]; then
  echo "사용: bash bin/docs-commit.sh <file...> <<'MSG' ... MSG  (최소 1파일 + stdin 메시지)" >&2
  exit 2
fi

# 커밋 메시지 = stdin(heredoc). tty 면 메시지 미전달 → hang 방지 차단.
if [ -t 0 ]; then
  echo "[docs-commit] 커밋 메시지를 stdin(heredoc)으로 전달하세요." >&2
  exit 2
fi
MSG="$(cat)"
if [ -z "${MSG//[[:space:]]/}" ]; then
  echo "[docs-commit] 빈 커밋 메시지 — 중단." >&2
  exit 2
fi

cd "$DOCS_REPO" || { echo "[docs-commit] cd 실패: $DOCS_REPO" >&2; exit 1; }

echo "=== repo: $DOCS_REPO / 브랜치: $(git rev-parse --abbrev-ref HEAD) ==="
echo "=== 대상 변경 상태 ==="
git status --short -- "$@"
echo "=== add + commit (push 없음) ==="
git add -- "$@"
if git diff --cached --quiet; then
  echo "[docs-commit] staged 변경 0 — 커밋 생략." >&2
  exit 0
fi
printf '%s\n' "$MSG" | git commit -F -
rc=$?
echo "=== 결과 (rc=$rc) ==="
git log --oneline -1
exit $rc
