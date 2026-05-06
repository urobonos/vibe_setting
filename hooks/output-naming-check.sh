#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PreToolUse:Edit|Write Hook — 산출물 파일명 규칙 검증 (tasks/ + output/)
#
# 대상:
#   - ~/.claude/docs/{product}/output/{topic-slug}/{파일명}.md
#   - ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{파일명}.md
#
# 규칙 (task-docs SKILL.md §산출물 네이밍 규칙):
#   - output/ 허용:  {yyyy-mm-dd}-{topic-slug}-{type}.md
#   - tasks/ 허용:   {yyyy-mm-dd}-{작업명}-{analyze|plan|result}.md
#   - 공통 필수:     파일명은 ^[0-9]{4}-[0-9]{2}-[0-9]{2}- 날짜 prefix 로 시작
#   - 공통 금지:     generic 단독 이름 (analysis.md, result.md, report.md, recommendation.md, comparison.md, guide.md, proposal.md, summary.md, doc.md, notes.md, readme.md, analyze.md)
#
# 예외:
#   - tasks/YYYYMMDD/summary.md (일일 요약)
#   - tasks/history.md (전체 이력 인덱스)
#   - specs/ 경로 (IEEE 공식 산출물 — 별도 규칙)

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path
# Windows backslash → forward slash 정규화 (기존 동작 보존)
FILE_PATH=$(echo "$FILE_PATH" | tr '\\' '/')

# 검증 대상 경로 판정 (output/ 또는 tasks/)
if echo "$FILE_PATH" | grep -qE '/docs/[^/]+/output/'; then
  KIND="output"
elif echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/'; then
  KIND="tasks"
else
  exit 0
fi

FILE_NAME=$(basename "$FILE_PATH")

# .md 외 파일은 검증 제외 (이미지, 첨부 등 허용)
if ! echo "$FILE_NAME" | grep -qE '\.md$'; then
  exit 0
fi

# tasks/ 의 단일 고정 파일은 예외 (summary.md, history.md)
if [ "$KIND" = "tasks" ]; then
  REL_FROM_DATE=$(echo "$FILE_PATH" | sed -E 's|.*/docs/[^/]+/tasks/[0-9]{8}/||')
  DEPTH=$(echo "$REL_FROM_DATE" | awk -F/ '{print NF}')
  # YYYYMMDD/summary.md 는 1-depth
  if [ "$DEPTH" -eq 1 ] && [ "$FILE_NAME" = "summary.md" ]; then
    exit 0
  fi
  # YYYYMMDD/{작업명}/ 하위가 아니면 검증 제외
  if [ "$DEPTH" -lt 2 ]; then
    echo "[TASK-NAMING] tasks/YYYYMMDD/{작업명}/ 하위에 파일을 배치하세요. 현재: tasks/.../$REL_FROM_DATE" >&2
    exit 2
  fi
  WORK_NAME=$(echo "$REL_FROM_DATE" | awk -F/ '{print $1}')
  CONTEXT_SLUG="$WORK_NAME"
fi

# tasks/history.md 예외
if echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/history\.md$'; then
  exit 0
fi

# output/ 구조 검증
if [ "$KIND" = "output" ]; then
  REL_FROM_OUTPUT=$(echo "$FILE_PATH" | sed -E 's|.*/docs/[^/]+/output/||')
  DEPTH=$(echo "$REL_FROM_OUTPUT" | awk -F/ '{print NF}')
  if [ "$DEPTH" -lt 3 ]; then
    echo "[OUTPUT-NAMING] output/{category}/{topic-slug}/ 하위에 파일을 배치하세요. 현재: output/$REL_FROM_OUTPUT" >&2
    echo "  카테고리: audit | verification | research | analysis | report | guide | archive" >&2
    exit 2
  fi
  CATEGORY=$(echo "$REL_FROM_OUTPUT" | awk -F/ '{print $1}')
  case "$CATEGORY" in
    audit|verification|research|analysis|report|guide|archive) ;;
    *)
      echo "[OUTPUT-NAMING] 알 수 없는 카테고리: '$CATEGORY' — audit | verification | research | analysis | report | guide | archive 중 하나를 사용하세요." >&2
      exit 2
      ;;
  esac
  TOPIC_SLUG=$(echo "$REL_FROM_OUTPUT" | awk -F/ '{print $2}')
  # 폴더명 -YYYYMMDD suffix 차단 (날짜는 YYYY-MM-DD- prefix 형식만 허용)
  if echo "$TOPIC_SLUG" | grep -qE -- '-[0-9]{8}$'; then
    SUGGEST_DATE=$(echo "$TOPIC_SLUG" | sed -E 's/.*-([0-9]{4})([0-9]{2})([0-9]{2})$/\1-\2-\3/')
    SUGGEST_BASE=$(echo "$TOPIC_SLUG" | sed -E 's/-[0-9]{8}$//')
    echo "[OUTPUT-NAMING] 폴더명 suffix 형식 '-YYYYMMDD' 금지: '$TOPIC_SLUG'. ISO-8601 prefix 'YYYY-MM-DD-' 형식만 허용." >&2
    echo "  예시: $SUGGEST_DATE-$SUGGEST_BASE" >&2
    exit 2
  fi
  CONTEXT_SLUG="$TOPIC_SLUG"
fi

# 금지된 generic 이름 목록 (날짜 prefix 검증보다 먼저 안내)
GENERIC_NAMES=(
  "analysis.md"
  "analyze.md"
  "plan.md"
  "result.md"
  "report.md"
  "recommendation.md"
  "comparison.md"
  "guide.md"
  "proposal.md"
  "summary.md"
  "doc.md"
  "docs.md"
  "notes.md"
  "readme.md"
  "README.md"
  "index.md"
)

TODAY_ISO=$(date +%Y-%m-%d)

for g in "${GENERIC_NAMES[@]}"; do
  if [ "$FILE_NAME" = "$g" ]; then
    if [ "$KIND" = "tasks" ]; then
      SUGGEST="${TODAY_ISO}-${CONTEXT_SLUG}-${g%.md}.md"
      echo "[TASK-NAMING] 제네릭/날짜 prefix 누락 차단: '$FILE_NAME' — '{yyyy-mm-dd}-{작업명}-{analyze|plan|result}.md' 형식으로 바꾸세요." >&2
      echo "  예시: $SUGGEST" >&2
    else
      SUGGEST="${TODAY_ISO}-${CONTEXT_SLUG}-${g%.md}.md"
      [ "${g%.md}" = "analyze" ] && SUGGEST="${TODAY_ISO}-${CONTEXT_SLUG}-analysis.md"
      echo "[OUTPUT-NAMING] 제네릭/날짜 prefix 누락 차단: '$FILE_NAME' — '{yyyy-mm-dd}-{topic-slug}-{type}.md' 형식으로 바꾸세요." >&2
      echo "  예시: $SUGGEST" >&2
      echo "  허용 type: analysis | report | recommendation | final-recommendation | comparison | guide | deployment-guide | proposal | reflection | checklist" >&2
    fi
    echo "  참고: ~/.claude/skills/task-docs/SKILL.md §산출물 네이밍 규칙" >&2
    exit 2
  fi
done

# 날짜 prefix 강제: ^YYYY-MM-DD-
if ! echo "$FILE_NAME" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-'; then
  if [ "$KIND" = "tasks" ]; then
    SUGGEST="${TODAY_ISO}-${CONTEXT_SLUG}-${FILE_NAME}"
    echo "[TASK-NAMING] 날짜 prefix 누락 차단: '$FILE_NAME' — 파일명은 '{yyyy-mm-dd}-{작업명}-{type}.md' 형식 필수." >&2
  else
    SUGGEST="${TODAY_ISO}-${FILE_NAME}"
    echo "[OUTPUT-NAMING] 날짜 prefix 누락 차단: '$FILE_NAME' — 파일명은 '{yyyy-mm-dd}-{topic-slug}-{type}.md' 형식 필수." >&2
  fi
  echo "  예시: $SUGGEST" >&2
  echo "  참고: ~/.claude/skills/task-docs/SKILL.md §산출물 네이밍 규칙" >&2
  exit 2
fi

# 컨텍스트 slug 첫 단어 정합성 (경고)
CONTEXT_FIRST_WORD=$(echo "$CONTEXT_SLUG" | cut -d'-' -f1)
if [ -n "$CONTEXT_FIRST_WORD" ] && ! echo "$FILE_NAME" | grep -qi "$CONTEXT_FIRST_WORD"; then
  if [ "$KIND" = "tasks" ]; then
    echo "[TASK-NAMING WARN] 파일명 '$FILE_NAME' 이 작업명 '$CONTEXT_SLUG' 와 연관 없음. '{yyyy-mm-dd}-{작업명}-{type}.md' 권장." >&2
  else
    echo "[OUTPUT-NAMING WARN] 파일명 '$FILE_NAME' 이 topic-slug '$CONTEXT_SLUG' 와 연관 없음. '{yyyy-mm-dd}-{topic-slug}-{type}.md' 권장." >&2
  fi
fi

exit 0
