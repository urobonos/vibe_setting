#!/usr/bin/env bash
# mirror-apidocs.sh — be api-docs SSOT → 글로벌(.claude/docs) + docs repo 3-way 미러
#   sha256-diff(CRLF 정규화) → 내용 다른 파일만 cp. mtime 무관.
#
# 사용: bash bin/mirror-apidocs.sh [상대경로...]   # 무인자 = be api-docs 전체 스캔
#                                                  # 상대경로 = api-docs 기준 (예: call/call-api.md)
# 환경: BE_ROOT   (기본 /c/Works/hongcafe_global_backend)
#       DOCS_ROOT (기본 /c/Works/hongcafe_global_docs)
# 후속: docs repo 변경분 커밋은 bin/docs-commit.sh (합성). docs/scripts/ ad-hoc 미러 10건+ 대체.
#       mirror-sync-from-be.sh 의 범용형 승격. 글로벌은 .claude/docs(비-git, 면제) → 커밋 불요.
set -uo pipefail

BE="${BE_ROOT:-/c/Works/hongcafe_global_backend}/api-docs"
GLOBAL="$HOME/.claude/docs/hongcafe_global_backend/api-docs"
DOCS="${DOCS_ROOT:-/c/Works/hongcafe_global_docs}/be/api-docs"

[ -d "$BE" ] || { echo "[mirror] be api-docs 미존재: $BE" >&2; exit 1; }

declare -a files
if [ $# -gt 0 ]; then
  files=("$@")
else
  mapfile -t files < <(cd "$BE" && find . -type f \( -name '*.md' -o -name '*.yaml' \) | sed 's|^\./||')
fi

sha() { tr -d '\r' < "$1" 2>/dev/null | sha256sum | awk '{print $1}'; }

G_N=0; D_N=0
for f in "${files[@]}"; do
  if [ ! -f "$BE/$f" ]; then echo "  ?? be 미존재: $f" >&2; continue; fi
  bs="$(sha "$BE/$f")"
  if [ "$bs" != "$(sha "$GLOBAL/$f")" ]; then
    mkdir -p "$(dirname "$GLOBAL/$f")"; cp -f "$BE/$f" "$GLOBAL/$f" && { echo "  G+ $f"; G_N=$((G_N+1)); }
  fi
  if [ "$bs" != "$(sha "$DOCS/$f")" ]; then
    mkdir -p "$(dirname "$DOCS/$f")"; cp -f "$BE/$f" "$DOCS/$f" && { echo "  D+ $f"; D_N=$((D_N+1)); }
  fi
done

echo "=== 미러 완료: 글로벌 +$G_N · docs +$D_N (대상 ${#files[@]}) ==="
[ "$D_N" -gt 0 ] && echo "→ docs repo 커밋 필요: bash bin/docs-commit.sh be/api-docs/<...> <<'MSG' ... MSG"
exit 0
