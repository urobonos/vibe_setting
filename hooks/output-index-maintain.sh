#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "output-index-maintain" "enter" "pid=$$"
# output-index-maintain.sh — PostToolUse Edit/Write
#   ~/.claude/docs/{product}/output/ 하위 *.md 가 생성·수정되면 해당 product 의
#   output/index.md (전수 추적 매니페스트) 를 자동 재생성한다.
#
# 설계 (working-register.sh + registry-utils.sh 패턴 복제):
#   - 강제점 1개(본 hook). 문서를 output/ 에 쓰는 모든 스킬·커맨드·훅이 자동 인덱싱됨.
#     → 개별 본문에 index 갱신 지시를 박지 않는다 (드리프트 0, CLAUDE.md §4.4 장기 관점).
#   - index.md 자기 제외 (무한루프 차단) — basename index.md write 는 즉시 exit.
#   - 비차단 (PostToolUse) — 항상 exit 0. 실패해도 본 작업 흐름을 막지 않는다.
#   - product 별 mkdir lock (POSIX atomic, registry-utils.sh 동일 방식) — race 보호.
#
# SSOT: CLAUDE.md §File Paths "output/ index.md 자동 인덱스" + skills/task-docs/SKILL.md

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null || exit 0

STDIN_DATA=$(cat)

PARSED=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('hook_event_name', '') != 'PostToolUse':
        sys.exit(0)
    tool = d.get('tool_name', '')
    if tool not in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'):
        sys.exit(0)
    fp = d.get('tool_input', {}).get('file_path', '')
    print(fp)
except SystemExit:
    raise
except:
    pass
" 2>/dev/null)

[ -z "$PARSED" ] && exit 0
FILE_PATH="$PARSED"

# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH_NORM=$(normalize_path "$FILE_PATH")

# output/ 하위 .md 만 대상: .../.claude/docs/{product}/output/....md
echo "$FILE_PATH_NORM" | grep -qE '/\.claude/docs/[^/]+/output/.*\.md$' || exit 0

# index.md 자기 제외 (무한루프 차단)
[ "$(basename "$FILE_PATH_NORM")" = "index.md" ] && exit 0

# output 루트 추출: .../.claude/docs/{product}/output
OUTPUT_DIR=$(echo "$FILE_PATH_NORM" | sed -E 's#(/.+/\.claude/docs/[^/]+/output)/.*#\1#')
[ -d "$OUTPUT_DIR" ] || exit 0
INDEX_FILE="$OUTPUT_DIR/index.md"

PRODUCT=$(echo "$OUTPUT_DIR" | sed -E 's#.*/\.claude/docs/([^/]+)/output#\1#')

# product 별 lock (race 보호 — registry-utils.sh mkdir 패턴)
LOCK_DIR="/tmp/claude-output-index-${PRODUCT}.lock.d"
i=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  i=$((i + 1))
  [ "$i" -ge 50 ] && exit 0
  sleep 0.1
done
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

TMP="$INDEX_FILE.tmp.$$"
GEN_TS=$(date +'%Y-%m-%d %H:%M')

{
  echo "# Output Index — ${PRODUCT}"
  echo ""
  echo "> \`~/.claude/docs/${PRODUCT}/output/\` 전체 문서 자동 추적 매니페스트."
  echo "> 갱신 주체: \`output-index-maintain.sh\` (PostToolUse). **직접 편집 금지** — output/ 하위 .md write 시 자동 재생성."
  echo "> 용도: \`/분석\`·\`/계획\` 등 워크플로우의 \"참조 범위 전수 조사\" 진입점 (index 전수 스캔 → 관련 항목 선택 정독)."
  echo "> 마지막 갱신: ${GEN_TS}"
  echo ""
  echo "| 카테고리 | 제목 | 경로 | 수정일 |"
  echo "|----------|------|------|--------|"

  # output/ 하위 모든 .md (index.md 제외) — 카테고리 → 경로 순 정렬
  find "$OUTPUT_DIR" -type f -name '*.md' ! -name 'index.md' 2>/dev/null \
    | LC_ALL=C sort \
    | while IFS= read -r f; do
        REL="${f#$OUTPUT_DIR/}"
        # 카테고리 = output 직속 첫 디렉토리 (audit/verification/research/analysis/report/guide/archive)
        CATEGORY="${REL%%/*}"
        [ "$CATEGORY" = "$REL" ] && CATEGORY="(root)"
        # 제목 = 첫 '# ' 헤더, 없으면 파일명
        TITLE=$(grep -m1 -E '^#[[:space:]]+' "$f" 2>/dev/null | sed -E 's/^#+[[:space:]]+//')
        [ -z "$TITLE" ] && TITLE=$(basename "$f")
        # 표 셀 안전화 (pipe → 전각, 개행 제거)
        TITLE=$(printf '%s' "$TITLE" | tr '|' '｜' | tr -d '\r\n')
        MTIME=$(date -r "$f" +'%Y-%m-%d' 2>/dev/null || echo '-')
        printf '| %s | %s | `%s` | %s |\n' "$CATEGORY" "$TITLE" "$REL" "$MTIME"
      done
} > "$TMP" 2>/dev/null

if [ -s "$TMP" ]; then
  mv "$TMP" "$INDEX_FILE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
else
  rm -f "$TMP" 2>/dev/null
fi

exit 0
