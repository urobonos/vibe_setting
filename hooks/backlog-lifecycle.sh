#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "backlog-lifecycle" "enter" "pid=$$"
# backlog-lifecycle.sh — memory backlog 메모리 완료 시 tasks/ 자동 이동 (2026-05-13 시행)
#
# SSOT: CLAUDE.md §4 "backlog 메모리 정책" + skills/task-docs/SKILL.md §"backlog 메모리 워크플로우"
#
# 관련 정책 (judgment 룰 — 본 hook 강제 대상 아님, 기록만):
#   "비필수 사이드이펙트 백로그 격리" (CLAUDE.md §4.5, 2026-06-09~) — 코드 작업 중 발견한 항목이
#   ① 현재 작업 필수요소 아님 + ② 실제 문제·버그 아님 + ③ 사이드이펙트급 3조건을 모두 충족하면
#   working/·산출물·코드 TODO 로 끌어올리지 말고 backlog 메모리에만 기록한다 (실제 버그는 경미해도
#   미루지 않음 = ②가 안전장치). 격리 판단은 Claude 본체 (judgment 룰 → 기계 강제 불가).
#   본 hook 은 그렇게 기록된 backlog 의 status:done → tasks/ 자동 이동만 담당한다.
#
# 진입점 (PostToolUse + UserPromptSubmit 양쪽 등록):
#   1. PostToolUse:Edit|Write — memory/backlog_*.md 파일 저장 직후 status: done 마커 자동 감지
#      - 마커: frontmatter `status:[[:space:]]*done` (한 줄, frontmatter 안 위치)
#   2. UserPromptSubmit — 사용자 명시 키워드 매칭 시 memory 디렉토리 전체 스캔
#      - 키워드: "backlog 완료" / "backlog 정리" / "backlog 이동" / "/backlog-done"
#
# 이동 절차:
#   1. 파일명 파싱 — backlog_{slug}.md → slug 추출
#   2. frontmatter `product:` 필드 추출 (없으면 "claude-harness" 기본)
#   3. frontmatter `completed:` 필드 = 오늘 자동 채움 (없을 시)
#   4. 대상 경로 = ~/.claude/docs/{product}/tasks/{YYYYMMDD-completed}/backlog/{yyyy-mm-dd}-{slug}.md
#   5. mkdir -p + mv (memory → tasks)
#   6. MEMORY.md 에서 해당 entry 제거
#   7. tasks/history.md + tasks/{date}/summary.md 자동 갱신
#   8. stderr 로 이동 결과 1줄 보고

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null || true

STDIN_DATA=$(cat)
MEMORY_DIR="$HOME/.claude/projects/C--Users-PV--claude/memory"
DOCS_ROOT="$HOME/.claude/docs"

# Git Bash path (/c/Users/...) ↔ Windows path (C:/Users/...) 변환 — Python (Windows native) 가 인식 가능하도록
to_win_path() {
  local p="$1"
  case "$p" in
    /c/*) echo "C:/${p#/c/}" ;;
    /C/*) echo "C:/${p#/C/}" ;;
    *)    echo "$p" ;;
  esac
}

HOOK_EVENT=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('hook_event_name', ''))
except:
    print('')
" 2>/dev/null)

# ============= 헬퍼: backlog 완료 마커 검사 =============
# frontmatter 안에서 `status: done` 매칭 (frontmatter 종료 라인 `---` 이전)
has_done_marker() {
  local file="$1"
  [ -f "$file" ] || return 1
  local win_file
  win_file=$(to_win_path "$file")
  python3 - "$win_file" <<'PYEOF'
import sys, re
file_path = sys.argv[1]
try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read(8192)
    m = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if not m:
        sys.exit(1)
    fm = m.group(1)
    if re.search(r'^\s*status:\s*done\s*$', fm, re.MULTILINE | re.IGNORECASE):
        sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PYEOF
}

# ============= 헬퍼: backlog 메모리 → tasks/ 이동 =============
move_backlog_to_tasks() {
  local backlog_file="$1"
  [ -f "$backlog_file" ] || return 1

  local filename
  filename=$(basename "$backlog_file")

  # backlog_{slug}.md 파일명 패턴
  case "$filename" in
    backlog_*.md) ;;
    *) return 1 ;;
  esac

  local slug=${filename#backlog_}
  slug=${slug%.md}

  # frontmatter 에서 product 추출 (기본값 = claude-harness)
  local product win_backlog
  win_backlog=$(to_win_path "$backlog_file")
  product=$(python3 - "$win_backlog" <<'PYEOF' 2>/dev/null
import sys, re
file_path = sys.argv[1]
try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read(4096)
    m = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if m:
        fm = m.group(1)
        pm = re.search(r'^\s*product:\s*(\S+)\s*$', fm, re.MULTILINE)
        if pm:
            print(pm.group(1).strip('"\''))
            sys.exit(0)
    print("claude-harness")
except Exception:
    print("claude-harness")
PYEOF
)
  [ -z "$product" ] && product="claude-harness"

  # 오늘 일자 (완료일)
  local date_part yyyymmdd today_dot
  date_part=$(date +%Y-%m-%d)
  yyyymmdd=$(date +%Y%m%d)
  today_dot=$(date +%Y.%m.%d)

  # 대상 경로 = ~/.claude/docs/{product}/tasks/{YYYYMMDD}/backlog/{yyyy-mm-dd}-{slug}.md
  local target_dir="$DOCS_ROOT/$product/tasks/$yyyymmdd/backlog"
  local target_file="$target_dir/${date_part}-${slug}.md"

  mkdir -p "$target_dir" 2>/dev/null || {
    echo "[backlog-lifecycle] $filename — 대상 폴더 생성 실패: $target_dir" >&2
    return 1
  }

  # 충돌 시 백업
  if [ -f "$target_file" ]; then
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    cp "$target_file" "${target_file}.bak-${ts}" 2>/dev/null
  fi

  # completed 필드 자동 채움 (없을 시)
  python3 - "$win_backlog" "$date_part" <<'PYEOF' 2>/dev/null
import sys, re
file_path = sys.argv[1]
date_str = sys.argv[2]
try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    m = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if m:
        fm = m.group(1)
        if not re.search(r'^\s*completed:', fm, re.MULTILINE):
            new_fm = fm.rstrip() + f"\ncompleted: {date_str}"
            content = content.replace(m.group(0), f"---\n{new_fm}\n---\n", 1)
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
except Exception:
    pass
PYEOF

  # 이동
  mv "$backlog_file" "$target_file" 2>/dev/null || {
    echo "[backlog-lifecycle] $filename — 이동 실패: $backlog_file → $target_file" >&2
    return 1
  }

  # MEMORY.md 에서 entry 제거
  local memory_index="$MEMORY_DIR/MEMORY.md"
  if [ -f "$memory_index" ]; then
    local win_index
    win_index=$(to_win_path "$memory_index")
    python3 - "$win_index" "$slug" <<'PYEOF' 2>/dev/null
import sys
index_path = sys.argv[1]
slug = sys.argv[2]
try:
    with open(index_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    out = [l for l in lines if f"backlog_{slug}.md" not in l and f"backlog/{slug})" not in l]
    if len(out) != len(lines):
        with open(index_path, 'w', encoding='utf-8') as f:
            f.writelines(out)
except Exception:
    pass
PYEOF
  fi

  # history.md 갱신 (product 기준) — reverse chronological insert (최신 위)
  # 버그 정정 (2026-05-14): 기존 코드는 today 헤더 매칭만 검사 후 entry 를 파일 끝 append →
  # 다른 날짜 섹션 안에 entry 가 들어가는 버그 (working-lifecycle.sh 와 동일 패턴).
  local history="$DOCS_ROOT/$product/tasks/history.md"
  if [ ! -f "$history" ]; then
    printf "# %s tasks 이력\n\n" "$product" > "$history"
  fi

  local entry_line
  entry_line=$(printf -- "- [backlog/%s](%s/backlog/%s-%s.md) — memory backlog 완료 → tasks/ 자동 이동" \
    "$slug" "$yyyymmdd" "$date_part" "$slug")

  python3 - "$history" "$today_dot" "$entry_line" "$date_part" "$slug" <<'PYEOF'
import sys
history_path, today_dot, entry_line, date_part, slug = sys.argv[1:6]
with open(history_path, 'r', encoding='utf-8') as f:
    content = f.read()

marker = f"backlog/{date_part}-{slug}"
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
  local summary_dir="$DOCS_ROOT/$product/tasks/$yyyymmdd"
  local summary="$summary_dir/summary.md"
  if [ ! -f "$summary" ]; then
    printf "# %s 작업 요약 (%s)\n\n## 진행 작업\n\n" "$product" "$today_dot" > "$summary"
  fi
  if ! grep -qE "backlog/${date_part}-${slug}" "$summary" 2>/dev/null; then
    printf -- "- [backlog/%s](backlog/%s-%s.md) — memory backlog 완료 → tasks/ 자동 이동\n" \
      "$slug" "$date_part" "$slug" >> "$summary"
  fi

  echo "[backlog-lifecycle] ✓ 이동: $filename → ${product}/tasks/$yyyymmdd/backlog/${date_part}-${slug}.md" >&2
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

  # memory/backlog_*.md 패턴만 처리
  echo "$FILE_PATH_NORM" | grep -qE '/memory/backlog_[^/]+\.md$' || exit 0

  unix_path=$(echo "$FILE_PATH_NORM" | sed 's|^C:|/c|')
  [ -f "$unix_path" ] || unix_path="$FILE_PATH_NORM"
  [ -f "$unix_path" ] || exit 0

  if has_done_marker "$unix_path"; then
    move_backlog_to_tasks "$unix_path"
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

  if echo "$PROMPT" | grep -qE '(backlog[[:space:]]*완료|backlog[[:space:]]*정리|backlog[[:space:]]*이동|/backlog-done)'; then
    moved_count=0
    [ -d "$MEMORY_DIR" ] || exit 0

    for f in "$MEMORY_DIR"/backlog_*.md; do
      [ -f "$f" ] || continue
      if has_done_marker "$f"; then
        if move_backlog_to_tasks "$f"; then
          moved_count=$((moved_count + 1))
        fi
      fi
    done

    if [ "$moved_count" -gt 0 ]; then
      echo "[backlog-lifecycle] 명시 키워드 트리거 — ${moved_count}건 memory/backlog → tasks/ 이동 완료" >&2
    fi
  fi

  exit 0
fi

exit 0
