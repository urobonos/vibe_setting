#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# working-lifecycle.sh — working/ 단일 통합 문서 자동 이동 (2026-05-12 시행)
#
# SSOT: CLAUDE.md §File Paths "working/ 단일 통합 문서" + skills/task-docs/SKILL.md §"working/ 단일 통합 워크플로우"
#
# 진입점 (PostToolUse + UserPromptSubmit 양쪽 등록):
#   1. PostToolUse:Edit|Write — working/ 파일 저장 직후 완료 마커 자동 감지
#      - 마커: ^Status:\s*Done (시작 라인) + ## Self-Critique 섹션 동시 존재
#   2. UserPromptSubmit — 사용자 명시 키워드 매칭 시 working/ 전체 스캔
#      - 키워드: "작업 완료" / "tasks 이동" / "working 정리" / "/working-done" / "done" / "완료 저장"
#
# 이동 절차:
#   1. 파일명 파싱 — {yyyy-mm-dd}-{product}-{작업명}.md → date / product / 작업명 추출
#      - product 매칭 = ~/.claude/docs/{product}/ 디렉토리 prefix 일치 탐색 (working / references 제외)
#   2. 대상 경로 = ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md
#   3. mkdir -p 대상 폴더
#   4. 동일 파일 존재 시 .bak-{timestamp} 백업 후 덮어쓰기
#   5. mv (working → tasks)
#   6. tasks/history.md + tasks/YYYYMMDD/summary.md 자동 갱신
#   7. stderr 로 이동 결과 1줄 보고

STDIN_DATA=$(cat)

HOOK_EVENT=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('hook_event_name', ''))
except:
    print('')
" 2>/dev/null)

# ============= 헬퍼: 완료 마커 검사 =============
has_completion_markers() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qE '^Status:[[:space:]]*Done[[:space:]]*$' "$file" || return 1
  grep -qE '^##[[:space:]]+.*Self-Critique' "$file" || return 1
  return 0
}

# ============= 헬퍼: working 파일 → tasks 이동 =============
move_working_to_tasks() {
  local working_file="$1"
  [ -f "$working_file" ] || return 1

  local filename
  filename=$(basename "$working_file")

  # 파일명 파싱: 2026-05-12-{product}-{작업명}.md
  local date_part
  date_part=$(echo "$filename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  if [ -z "$date_part" ]; then
    echo "[working-lifecycle] $filename — 날짜 prefix 누락, 스킵" >&2
    return 1
  fi

  # date prefix 제거 → {product}-{작업명}.md
  local rest=${filename#${date_part}-}
  rest=${rest%.md}

  # product 매칭: ~/.claude/docs/{product}/ 디렉토리 prefix 탐색
  local product=""
  local task_name=""
  local docs_root="$HOME/.claude/docs"
  for candidate in "$docs_root"/*/; do
    [ -d "$candidate" ] || continue
    local cand_name
    cand_name=$(basename "$candidate")
    case "$cand_name" in
      working|references) continue ;;
    esac
    if [[ "$rest" == "${cand_name}-"* ]]; then
      # 가장 긴 매칭 우선 (product 이름이 겹치는 경우 대비)
      if [ -z "$product" ] || [ ${#cand_name} -gt ${#product} ]; then
        product="$cand_name"
        task_name=${rest#${cand_name}-}
      fi
    fi
  done

  if [ -z "$product" ] || [ -z "$task_name" ]; then
    echo "[working-lifecycle] $filename — product 매칭 실패 (rest='$rest'), 스킵" >&2
    return 1
  fi

  # YYYYMMDD 변환
  local yyyymmdd
  yyyymmdd=$(echo "$date_part" | tr -d '-')

  # 대상 경로
  local target_dir="$docs_root/$product/tasks/$yyyymmdd/$task_name"
  local target_file="$target_dir/${date_part}-${task_name}-unified.md"

  mkdir -p "$target_dir" 2>/dev/null || {
    echo "[working-lifecycle] $filename — 대상 폴더 생성 실패: $target_dir" >&2
    return 1
  }

  # 충돌 시 백업
  if [ -f "$target_file" ]; then
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    cp "$target_file" "${target_file}.bak-${ts}" 2>/dev/null
  fi

  # 이동
  mv "$working_file" "$target_file" 2>/dev/null || {
    echo "[working-lifecycle] $filename — 이동 실패: $working_file → $target_file" >&2
    return 1
  }

  # history.md 갱신
  local history="$docs_root/$product/tasks/history.md"
  local today_dot
  today_dot=$(date +%Y.%m.%d)
  if [ ! -f "$history" ]; then
    printf "# %s tasks 이력\n\n" "$product" > "$history"
  fi
  if ! grep -qE "^## ${today_dot}" "$history" 2>/dev/null; then
    printf "\n## %s\n" "$today_dot" >> "$history"
  fi
  if ! grep -qE "${date_part}-${task_name}-unified" "$history" 2>/dev/null; then
    printf -- "- [%s](%s/%s/%s-%s-unified.md) — working/ → tasks/ 자동 이동 (unified)\n" \
      "$task_name" "$yyyymmdd" "$task_name" "$date_part" "$task_name" >> "$history"
  fi

  # summary.md 갱신
  local summary_dir="$docs_root/$product/tasks/$yyyymmdd"
  local summary="$summary_dir/summary.md"
  if [ ! -f "$summary" ]; then
    printf "# %s 작업 요약 (%s)\n\n## 진행 작업\n\n" "$product" "$today_dot" > "$summary"
  fi
  if ! grep -qE "${task_name}/${date_part}-${task_name}-unified" "$summary" 2>/dev/null; then
    printf -- "- [%s](%s/%s-%s-unified.md) — unified 통합 산출물 (working/ 자동 이동)\n" \
      "$task_name" "$task_name" "$date_part" "$task_name" >> "$summary"
  fi

  echo "[working-lifecycle] ✓ 이동: $filename → tasks/$yyyymmdd/$task_name/${date_part}-${task_name}-unified.md" >&2
  return 0
}

# ============= PostToolUse 진입 =============
if [ "$HOOK_EVENT" = "PostToolUse" ]; then
  FILE_PATH=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_response', {}).get('filePath', '') if isinstance(data.get('tool_response'), dict) else ''
    if not fp:
        fp = data.get('tool_input', {}).get('file_path', '')
    print(fp)
except:
    print('')
" 2>/dev/null)

  [ -z "$FILE_PATH" ] && exit 0

  FILE_PATH_NORM=$(echo "$FILE_PATH" | tr '\\' '/')

  echo "$FILE_PATH_NORM" | grep -qE '/docs/working/[0-9]{8}/[^/]+\.md$' || exit 0

  # Windows 경로 변환
  unix_path=$(echo "$FILE_PATH_NORM" | sed 's|^C:|/c|')
  [ -f "$unix_path" ] || unix_path="$FILE_PATH_NORM"
  [ -f "$unix_path" ] || exit 0

  if has_completion_markers "$unix_path"; then
    move_working_to_tasks "$unix_path"
  fi

  exit 0
fi

# ============= UserPromptSubmit 진입 =============
if [ "$HOOK_EVENT" = "UserPromptSubmit" ]; then
  PROMPT=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('prompt', ''))
except:
    print('')
" 2>/dev/null)

  # 명시 키워드 매칭 (case-insensitive 일부 + Korean)
  if echo "$PROMPT" | grep -qE '(작업[[:space:]]*완료|tasks[[:space:]]*이동|working[[:space:]]*정리|/working-done|완료[[:space:]]*저장)' \
     || echo "$PROMPT" | grep -qiE '(^|[[:space:]])done([[:space:]]|$|\.|,|!)' ; then

    moved_count=0
    working_root="$HOME/.claude/docs/working"
    [ -d "$working_root" ] || exit 0

    for dir in "$working_root"/*/; do
      [ -d "$dir" ] || continue
      for f in "$dir"*.md; do
        [ -f "$f" ] || continue
        if move_working_to_tasks "$f"; then
          moved_count=$((moved_count + 1))
        fi
      done
    done

    if [ "$moved_count" -gt 0 ]; then
      echo "[working-lifecycle] 명시 키워드 트리거 — ${moved_count}건 working/ → tasks/ 이동 완료" >&2
    fi
  fi

  exit 0
fi

exit 0
