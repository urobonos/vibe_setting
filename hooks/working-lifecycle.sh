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

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null || true

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
# 정규식 SSOT = lib/template-patterns.sh (2026-05-13 도입, audit S-3/H-2/H-3 묶음).
# 본 hook 의 has_completion_markers 는 lib 함수 wrapper 로 단순화.
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/template-patterns.sh" 2>/dev/null || {
  # lib 로드 실패 fallback — 인라인 정규식 보존 (회귀 안전성)
  has_status_done() { [ -f "$1" ] && grep -qE '^(Status|상태):[[:space:]]*(Done|완료)[[:space:]]*$' "$1"; }
  has_self_critique_h2() { [ -f "$1" ] && grep -qE '^##[[:space:]]+.*Self-Critique' "$1"; }
  detect_self_critique_wrong_heading() { [ -f "$1" ] && grep -nE '^#{3,}[[:space:]]+.*Self-Critique|^#{1}[[:space:]]+.*Self-Critique' "$1" 2>/dev/null | head -1; }
}

# Active Task Registry entry/lock 정리 함수 (lib 가용 시에만, 2026-05-15)
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/registry-utils.sh" 2>/dev/null || true

has_completion_markers() {
  has_status_done "$1" && has_self_critique_h2 "$1"
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

  # Active Task Registry — 동일 slug 모든 entry + lock 일괄 정리 (작업 완료 신호, 2026-05-15)
  if [ -n "${REGISTRY_PATH:-}" ] && [ -f "$REGISTRY_PATH" ]; then
    awk -v slug="$task_name" -F"${REGISTRY_FS:-[[:space:]]*\\|[[:space:]]*}" '
      /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $2 == slug { next }
      { print }
    ' "$REGISTRY_PATH" >"$REGISTRY_PATH.tmp" 2>/dev/null && mv "$REGISTRY_PATH.tmp" "$REGISTRY_PATH" 2>/dev/null
  fi
  if [ -n "${SESSIONS_DIR:-}" ] && [ -d "$SESSIONS_DIR/$task_name" ]; then
    rm -f "$SESSIONS_DIR/$task_name"/*.lock 2>/dev/null
    rmdir "$SESSIONS_DIR/$task_name" 2>/dev/null || true
  fi

  # history.md 갱신 — reverse chronological insert (최신 위)
  # 버그 정정 (2026-05-14): 기존 코드는 today 헤더 매칭만 검사 후 entry 를 파일 끝 append →
  # 다른 날짜 섹션 안에 entry 가 들어가는 버그. 본 정정 = today 섹션 안 정확 insert + 미존재 시 파일 상단 신규 섹션.
  local history="$docs_root/$product/tasks/history.md"
  local today_dot
  today_dot=$(date +%Y.%m.%d)
  if [ ! -f "$history" ]; then
    printf "# %s tasks 이력\n\n" "$product" > "$history"
  fi

  local entry_line
  entry_line=$(printf -- "- [%s](%s/%s/%s-%s-unified.md) — working/ → tasks/ 자동 이동 (unified)" \
    "$task_name" "$yyyymmdd" "$task_name" "$date_part" "$task_name")

  python3 - "$history" "$today_dot" "$entry_line" "$date_part" "$task_name" <<'PYEOF'
import sys
history_path, today_dot, entry_line, date_part, task_name = sys.argv[1:6]
with open(history_path, 'r', encoding='utf-8') as f:
    content = f.read()

marker = f"{date_part}-{task_name}-unified"
if marker in content:
    sys.exit(0)

header = f"## {today_dot}"
lines = content.split('\n')

header_idx = -1
for idx, line in enumerate(lines):
    if line.startswith(header):
        header_idx = idx
        break

if header_idx >= 0:
    insert_pos = header_idx + 1
    if insert_pos < len(lines) and lines[insert_pos] == '':
        insert_pos += 1
    to_insert = [entry_line]
    if insert_pos < len(lines) and lines[insert_pos] != '':
        to_insert.append('')
    new_lines = lines[:insert_pos] + to_insert + lines[insert_pos:]
else:
    h1_idx = -1
    for idx, line in enumerate(lines):
        if line.startswith('# '):
            h1_idx = idx
            break
    if h1_idx >= 0:
        insert_pos = h1_idx + 1
        if insert_pos < len(lines) and lines[insert_pos] == '':
            insert_pos += 1
        new_lines = lines[:insert_pos] + [header, '', entry_line, ''] + lines[insert_pos:]
    else:
        new_lines = [header, '', entry_line, ''] + lines

with open(history_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(new_lines))
PYEOF

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

  # Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
  FILE_PATH_NORM=$(normalize_path "$FILE_PATH")

  echo "$FILE_PATH_NORM" | grep -qE '/docs/working/[0-9]{8}/[^/]+\.md$' || exit 0

  # Windows 경로 변환
  unix_path=$(echo "$FILE_PATH_NORM" | sed 's|^C:|/c|')
  [ -f "$unix_path" ] || unix_path="$FILE_PATH_NORM"
  [ -f "$unix_path" ] || exit 0

  if has_completion_markers "$unix_path"; then
    move_working_to_tasks "$unix_path"
  else
    # 양식 위반 침묵 실패 방지 (2026-05-13) — Status: Done 매칭 + ## Self-Critique 미매칭 시 stderr 경고
    # 정규식 SSOT: lib/template-patterns.sh (audit S-3/H-2/H-3 묶음으로 lib 통합)
    if has_status_done "$unix_path" && ! has_self_critique_h2 "$unix_path"; then
      LOOSE_MATCH=$(detect_self_critique_wrong_heading "$unix_path")
      echo "[working-lifecycle] $(basename "$unix_path") — Status: Done 매칭 but '## Self-Critique' (h2) 미매칭 → 자동 이동 스킵" >&2
      if [ -n "$LOOSE_MATCH" ]; then
        echo "                    감지: $LOOSE_MATCH (헤딩 레벨 불일치 — h2 '## ' 로 수정 필요)" >&2
      fi
      echo "                    SSOT: skills/task-docs/references/unified-template.md L10" >&2
    fi
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

    skipped_count=0
    for dir in "$working_root"/*/; do
      [ -d "$dir" ] || continue
      for f in "$dir"*.md; do
        [ -f "$f" ] || continue
        if ! has_completion_markers "$f"; then
          echo "[working-lifecycle] $(basename "$f") — Status:Done + Self-Critique 미충족, 스킵" >&2
          skipped_count=$((skipped_count + 1))
          continue
        fi
        if move_working_to_tasks "$f"; then
          moved_count=$((moved_count + 1))
        fi
      done
    done

    if [ "$moved_count" -gt 0 ] || [ "$skipped_count" -gt 0 ]; then
      echo "[working-lifecycle] 명시 키워드 트리거 — 이동 ${moved_count}건 / 스킵 ${skipped_count}건 (Partial 보존)" >&2
    fi
  fi

  exit 0
fi

exit 0
