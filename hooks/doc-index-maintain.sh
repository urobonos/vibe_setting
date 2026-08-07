#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "doc-index-maintain" "enter" "pid=$$"
# doc-index-maintain.sh — PostToolUse Edit/Write
#   ~/.claude/docs/{product}/ 하위 *.md 가 생성·수정되면 해당 product 의
#   ~/.claude/docs/indexing/{product}.md (docs 전역 추적 인덱스) 를 자동 재생성한다.
#
# 설계 (output-index-maintain.sh 후신 — 2026-05-29 재설계):
#   - 범위: output/ 한정 → docs 전역 (output / tasks / specs / working / 참조문서 등 전 영역).
#   - 출력: product 별 인덱스를 ~/.claude/docs/indexing/{product}.md 한 폴더에 집결.
#   - 내용: 영역(product 루트 첫 디렉토리) / 타이틀(파일 내 첫 '# ' 헤더) / 경로 / 수정일 표.
#   - 강제점 1개(본 hook). docs 에 .md 를 쓰는 모든 스킬·커맨드·훅이 자동 인덱싱됨 (드리프트 0).
#   - 자기 제외: indexing/ + references/(docset) write 는 즉시 exit (무한루프·바이너리 차단).
#   - 비차단(PostToolUse) exit 0 / product 별 mkdir lock (race 보호).
#
# SSOT: CLAUDE.md §File Paths "indexing/{product}.md 전역 인덱스" + skills/task-docs/SKILL.md

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null || exit 0

STDIN_DATA=$(cat)

# 파싱 — bash 내장 (python 起動 제거). PostToolUse + Edit/Write 계열만 대상 (원본 조건 보존).
[[ "$STDIN_DATA" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"PostToolUse\" ]] || exit 0
TOOL_NAME=""; [[ "$STDIN_DATA" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && TOOL_NAME="${BASH_REMATCH[1]}"
case "$TOOL_NAME" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
FILE_PATH=""
[[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && FILE_PATH="${BASH_REMATCH[1]}"
[ -z "$FILE_PATH" ] && [[ "$STDIN_DATA" =~ \"notebook_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && FILE_PATH="${BASH_REMATCH[1]}"
[ -z "$FILE_PATH" ] && exit 0
FILE_PATH_NORM=$(normalize_path "$FILE_PATH")

# docs/{product}/...md 만 대상
echo "$FILE_PATH_NORM" | grep -qE '/\.claude/docs/[^/]+/.*\.md$' || exit 0

# 자기 제외 (무한루프) + references(docset 바이너리) 제외
case "$FILE_PATH_NORM" in
  */.claude/docs/indexing/*)   exit 0 ;;
  */.claude/docs/references/*) exit 0 ;;
esac

# product = docs 직속 디렉토리명
PRODUCT=$(echo "$FILE_PATH_NORM" | sed -E 's#.*/\.claude/docs/([^/]+)/.*#\1#')
[ -z "$PRODUCT" ] && exit 0
case "$PRODUCT" in indexing|references) exit 0 ;; esac

DOCS_ROOT=$(echo "$FILE_PATH_NORM" | sed -E 's#(.*/\.claude/docs)/.*#\1#')
PRODUCT_DIR="$DOCS_ROOT/$PRODUCT"
[ -d "$PRODUCT_DIR" ] || exit 0
INDEX_DIR="$DOCS_ROOT/indexing"
INDEX_FILE="$INDEX_DIR/$PRODUCT.md"
mkdir -p "$INDEX_DIR" 2>/dev/null || exit 0

# lock 미사용 (2026-05-29 실측 결정): 본 hook 은 전체 재생성(덮어쓰기)이므로 마지막 writer 가
#   항상 최신 상태로 수렴 — race 손상이 없고 `mv`(atomic rename)만으로 일관성이 보장된다.
#   mkdir-lock + trap-EXIT 방식은 Windows PostToolUse 가 hook 을 중도 종료할 때 trap 이 안 돌아
#   stale lock 을 남기고, 이후 모든 갱신을 영구 차단했다 (실측). lock 을 제거해 그 실패 모드를 근절.
# 비정상 종료가 남긴 tmp 만 정리 — 1분+ 묵은 것만 (동시 실행 중인 TMP 는 보존).
find "$INDEX_DIR" -maxdepth 1 -name "$(basename "$INDEX_FILE").tmp.*" -mmin +1 -delete 2>/dev/null || true
TMP="$INDEX_FILE.tmp.$$"
GEN_TS=$(date +'%Y-%m-%d %H:%M')
# working/backlog/ 제외(2026-08-07 콜드리뷰 M3) — backlog 본문 저장처(product 무분리, 2026-08-06 이관)가
# PRODUCT="working" 스캔에 그대로 잡혀 이 인덱스가 298건(89%) 으로 부풀었다. 이 파일은 CLAUDE.md §File
# Paths 가 `/taskflow:analyze`·`plan` 의 "참조 범위 전수 조사" 진입점으로 규정하는 입력이라, 부풀면
# 매 분석 단계 입력이 그만큼 커진다. backlog 는 태스크 문서가 아니라 별도 워크플로우(backlog-lifecycle.sh)
# 전용 저장소이므로 이 인덱스의 스캔 대상이 아니다.
DOC_COUNT=$(find "$PRODUCT_DIR" -type f -name '*.md' -not -path "$PRODUCT_DIR/backlog/*" 2>/dev/null | wc -l | tr -d ' ')

{
  echo "# Document Index — ${PRODUCT}"
  echo ""
  echo "> \`~/.claude/docs/${PRODUCT}/\` 하위 전체 문서 자동 추적 인덱스 (영역 / 타이틀 / 경로 / 수정일)."
  echo "> 갱신 주체: \`doc-index-maintain.sh\` (PostToolUse). **직접 편집 금지** — docs/${PRODUCT}/ 하위 .md write 시 자동 재생성."
  echo "> 용도: \`/taskflow:analyze\`·\`/taskflow:plan\` 등 워크플로우의 \"참조 범위 전수 조사\" 진입점 (index 전수 스캔 → 관련 항목 선택 정독)."
  echo "> 문서 수: ${DOC_COUNT} · 마지막 갱신: ${GEN_TS}"
  echo ""
  echo "| 영역 | 타이틀 | 경로 | 수정일 |"
  echo "|------|--------|------|--------|"

  # 성능: 파일당 grep/date/tr spawn(=O(4n), be 664 시 2분) 제거 →
  #   find -printf 로 mtime 동시 추출 + 단일 gawk 가 getline 으로 각 파일 첫 헤더 읽음.
  #   전체 프로세스 spawn = find + sort + awk = 3개 (파일 수 무관). 15s timeout 내 안착.
  find "$PRODUCT_DIR" -type f -name '*.md' -not -path "$PRODUCT_DIR/backlog/*" -printf '%p\t%TY-%Tm-%Td\n' 2>/dev/null \
    | LC_ALL=C sort \
    | awk -F'\t' -v base="$PRODUCT_DIR/" '
        {
          path=$1; mtime=$2
          rel=substr(path, length(base)+1)
          area=rel; sub(/\/.*/,"",area); if (area==rel) area="(root)"
          title=""
          while ((getline line < path) > 0) {
            if (line ~ /^#[[:space:]]+/) { title=line; sub(/^#+[[:space:]]+/,"",title); break }
          }
          close(path)
          if (title=="") { title=rel; sub(/.*\//,"",title) }
          gsub(/\|/,"｜",title); gsub(/\r/,"",title)
          printf "| %s | %s | `%s` | %s |\n", area, title, rel, mtime
        }
      '
} > "$TMP" 2>/dev/null

if [ -s "$TMP" ]; then
  mv "$TMP" "$INDEX_FILE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
else
  rm -f "$TMP" 2>/dev/null
fi

exit 0
