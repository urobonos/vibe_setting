#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "output-naming-check" "enter" "pid=$$"
# PreToolUse:Edit|Write Hook — 산출물 파일명 규칙 검증 (tasks/ + output/ + working/)
#
# 대상:
#   - ~/.claude/docs/{product}/output/{topic-slug}/{파일명}.md
#   - ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{파일명}.md
#   - ~/.claude/docs/working/YYYYMMDD/{파일명}.md  (2026-05-12 시행, product 분리 없음)
#
# 규칙 (task-docs SKILL.md §산출물 네이밍 규칙):
#   - output/ 허용:  {yyyy-mm-dd}-{topic-slug}-{type}.md
#   - tasks/ 허용:   {yyyy-mm-dd}-{작업명}-{analyze|plan|result|unified}.md (unified 는 2026-05-12~ 신규)
#   - working/ 허용: {yyyy-mm-dd}-{product}-{작업명}.md  (단일 파일, 하위 폴더 금지)
#   - 공통 필수:     파일명은 ^[0-9]{4}-[0-9]{2}-[0-9]{2}- 날짜 prefix 로 시작
#   - 공통 금지:     generic 단독 이름 (analysis.md, result.md, report.md, recommendation.md, comparison.md, guide.md, proposal.md, summary.md, doc.md, notes.md, readme.md, analyze.md, unified.md)
#
# 예외:
#   - tasks/YYYYMMDD/summary.md (일일 요약)
#   - tasks/history.md (전체 이력 인덱스)
#   - specs/ 경로 (IEEE 공식 산출물 — 별도 규칙)

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_read_stdin
hook_parse_file_path
# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

# 검증 대상 경로 판정 (output/ / tasks/ / working/)
if echo "$FILE_PATH" | grep -qE '/docs/[^/]+/output/'; then
  KIND="output"
elif echo "$FILE_PATH" | grep -qE '/docs/[^/]+/tasks/[0-9]{8}/'; then
  KIND="tasks"
elif echo "$FILE_PATH" | grep -qE '/docs/working/[0-9]{8}/'; then
  KIND="working"
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
    command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=tasks-depth"
    exit 2
  fi
  WORK_NAME=$(echo "$REL_FROM_DATE" | awk -F/ '{print $1}')
  CONTEXT_SLUG="$WORK_NAME"
fi

# working/ 구조 검증 — working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md 단일 파일 (2026-05-12 시행)
if [ "$KIND" = "working" ]; then
  REL_FROM_DATE=$(echo "$FILE_PATH" | sed -E 's|.*/docs/working/[0-9]{8}/||')
  DEPTH=$(echo "$REL_FROM_DATE" | awk -F/ '{print NF}')
  if [ "$DEPTH" -ne 1 ]; then
    echo "[WORKING-NAMING] working/YYYYMMDD/ 직속 단일 파일 형식 필수 (하위 폴더 금지). 현재: working/.../$REL_FROM_DATE" >&2
    echo "  형식: working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md" >&2
    echo "  참고: ~/.claude/CLAUDE.md §File Paths 'working/ 단일 통합 문서'" >&2
    command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=working-format"
    exit 2
  fi
  CONTEXT_SLUG=""  # working/ 은 product+작업명 자유 slug, 첫 단어 정합성 검증 면제
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
    command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=output-depth"
    exit 2
  fi
  # DEPTH > 3 = sub-document (단일 산출물의 분할 chapter, 예: {topic-slug}/sections/01-intro.md)
  # 카테고리/topic-slug 정합성만 검증하고 파일명·폴더명 prefix 강제는 면제
  if [ "$DEPTH" -gt 3 ]; then
    CATEGORY=$(echo "$REL_FROM_OUTPUT" | awk -F/ '{print $1}')
    case "$CATEGORY" in
      audit|verification|research|analysis|report|guide|archive) exit 0 ;;
      *)
        echo "[OUTPUT-NAMING] 알 수 없는 카테고리: '$CATEGORY' — audit | verification | research | analysis | report | guide | archive 중 하나를 사용하세요." >&2
        command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=unknown-category-deep"
        exit 2
        ;;
    esac
  fi
  CATEGORY=$(echo "$REL_FROM_OUTPUT" | awk -F/ '{print $1}')
  case "$CATEGORY" in
    audit|verification|research|analysis|report|guide|archive) ;;
    *)
      echo "[OUTPUT-NAMING] 알 수 없는 카테고리: '$CATEGORY' — audit | verification | research | analysis | report | guide | archive 중 하나를 사용하세요." >&2
      command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=unknown-category"
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
    command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=folder-suffix"
    exit 2
  fi
  # 자동 면제: 부모 폴더 직속 자식이 모두 YYYY-MM-DD- prefix 이고 2건 이상이면 누적형
  # Why: 동일 topic 다중 dated 자식 (예: api-spec-audit/2026-05-08-member/) 케이스 자동 처리
  auto_exempt_check() {
    local parent_path="$1"
    [ ! -d "$parent_path" ] && return 1
    local children
    # 직속 자식 디렉토리만 (.) 제외, 숨김 제외
    children=$(find "$parent_path" -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*' 2>/dev/null)
    [ -z "$children" ] && return 1
    local total=0
    local dated=0
    while IFS= read -r child; do
      [ -z "$child" ] && continue
      total=$((total+1))
      local cb
      cb=$(basename "$child")
      if echo "$cb" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-'; then
        dated=$((dated+1))
      fi
    done <<< "$children"
    # 모든 자식이 dated + 2건 이상
    if [ "$total" -ge 2 ] && [ "$total" = "$dated" ]; then
      return 0  # 면제
    fi
    return 1
  }

  # 폴더명 YYYY-MM-DD- prefix 강제 (단발성 작업 필수, ongoing 폴더만 화이트리스트 면제)
  # ongoing 화이트리스트: daily-report / weekly-work-report / monthly-report — 동일 주제로 다회 산출물 누적되는 폴더만
  case "$TOPIC_SLUG" in
    daily-report|weekly-work-report|monthly-report) ;;
    *)
      if ! echo "$TOPIC_SLUG" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-'; then
        # 자동 면제 검사: 부모 폴더 (output/{category}/{topic-slug}/) 절대 경로 추출
        FOLDER_ABS=$(echo "$FILE_PATH" | sed -E 's|(.*/docs/[^/]+/output/[^/]+/[^/]+)/.*|\1|')
        if auto_exempt_check "$FOLDER_ABS"; then
          echo "[OUTPUT-NAMING] 자동 면제 (누적형 — 자식 dated >= 2): $FOLDER_ABS" >&2
        else
          SUGGEST_FOLDER="${TODAY_ISO_FOR_FOLDER:-$(date +%Y-%m-%d)}-${TOPIC_SLUG}"
          echo "[OUTPUT-NAMING] 폴더명 날짜 prefix 누락 차단: '$TOPIC_SLUG' — '{yyyy-mm-dd}-{topic-slug}/' 형식 필수." >&2
          echo "  예시: $SUGGEST_FOLDER" >&2
          echo "  ongoing 면제: daily-report / weekly-work-report / monthly-report (동일 주제 다회 누적 폴더)" >&2
          echo "  자동 면제: 부모 폴더 직속 자식이 모두 YYYY-MM-DD- prefix 이고 2건 이상" >&2
          echo "  참고: ~/.claude/CLAUDE.md §File Paths '폴더·파일명 날짜 표기'" >&2
          command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=folder-prefix"
          exit 2
        fi
      fi
      ;;
  esac
  CONTEXT_SLUG="$TOPIC_SLUG"
fi

# 금지된 generic 이름 목록 (날짜 prefix 검증보다 먼저 안내)
GENERIC_NAMES=(
  "analysis.md"
  "analyze.md"
  "plan.md"
  "result.md"
  "unified.md"
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
      echo "[TASK-NAMING] 제네릭/날짜 prefix 누락 차단: '$FILE_NAME' — '{yyyy-mm-dd}-{작업명}-{analyze|plan|result|unified}.md' 형식으로 바꾸세요." >&2
      echo "  예시: $SUGGEST" >&2
    elif [ "$KIND" = "working" ]; then
      SUGGEST="${TODAY_ISO}-{product}-{작업명}.md"
      echo "[WORKING-NAMING] 제네릭/날짜 prefix 누락 차단: '$FILE_NAME' — '{yyyy-mm-dd}-{product}-{작업명}.md' 형식으로 바꾸세요." >&2
      echo "  예시: $SUGGEST" >&2
      echo "  참고: ~/.claude/CLAUDE.md §File Paths 'working/ 단일 통합 문서'" >&2
    else
      SUGGEST="${TODAY_ISO}-${CONTEXT_SLUG}-${g%.md}.md"
      [ "${g%.md}" = "analyze" ] && SUGGEST="${TODAY_ISO}-${CONTEXT_SLUG}-analysis.md"
      echo "[OUTPUT-NAMING] 제네릭/날짜 prefix 누락 차단: '$FILE_NAME' — '{yyyy-mm-dd}-{topic-slug}-{type}.md' 형식으로 바꾸세요." >&2
      echo "  예시: $SUGGEST" >&2
      echo "  허용 type: analysis | report | recommendation | final-recommendation | comparison | guide | deployment-guide | proposal | reflection | checklist" >&2
    fi
    echo "  참고: ~/.claude/skills/task-docs/SKILL.md §산출물 네이밍 규칙" >&2
    command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=generic-name"
    exit 2
  fi
done

# 날짜 prefix 강제: ^YYYY-MM-DD-
if ! echo "$FILE_NAME" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-'; then
  if [ "$KIND" = "tasks" ]; then
    SUGGEST="${TODAY_ISO}-${CONTEXT_SLUG}-${FILE_NAME}"
    echo "[TASK-NAMING] 날짜 prefix 누락 차단: '$FILE_NAME' — 파일명은 '{yyyy-mm-dd}-{작업명}-{type}.md' 형식 필수." >&2
  elif [ "$KIND" = "working" ]; then
    SUGGEST="${TODAY_ISO}-{product}-${FILE_NAME%.md}.md"
    echo "[WORKING-NAMING] 날짜 prefix 누락 차단: '$FILE_NAME' — 파일명은 '{yyyy-mm-dd}-{product}-{작업명}.md' 형식 필수." >&2
  else
    SUGGEST="${TODAY_ISO}-${FILE_NAME}"
    echo "[OUTPUT-NAMING] 날짜 prefix 누락 차단: '$FILE_NAME' — 파일명은 '{yyyy-mm-dd}-{topic-slug}-{type}.md' 형식 필수." >&2
  fi
  echo "  예시: $SUGGEST" >&2
  echo "  참고: ~/.claude/skills/task-docs/SKILL.md §산출물 네이밍 규칙" >&2
  command -v log_event >/dev/null 2>&1 && log_event "output-naming-check" "block" "reason=date-prefix"
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
