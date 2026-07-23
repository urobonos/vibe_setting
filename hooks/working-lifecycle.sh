#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "working-lifecycle" "enter" "pid=$$"
# working-lifecycle.sh — working/ 단일 통합 문서 자동 이동 (2026-05-12 시행)
#
# SSOT: CLAUDE.md §File Paths "working/ 단일 통합 문서" + skills/task-docs/SKILL.md §"working/ 단일 통합 워크플로우"
#
# 진입점 (PostToolUse + UserPromptSubmit 양쪽 등록):
#   1. PostToolUse:Edit|Write — working/ 파일 저장 직후 완료 마커 자동 감지
#      - 마커: ^Status:\s*Done (시작 라인) + ## Self-Critique 섹션 동시 존재
#   2. UserPromptSubmit — 사용자 명시 키워드 매칭 시 working/ 전체 스캔
#      - 키워드: "작업 완료" / "tasks 이동" / "working 정리" / "/taskflow:done" / "done" / "완료 저장"
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
# stdin JSON 파싱 lib (bash-primary + python/grep fallback + CR 제거) — FILE_PATH/PROMPT 추출용
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/hook-input.sh" 2>/dev/null || true

STDIN_DATA=$(cat)

# hook_event_name — bash 내장 (python 起動 제거)
HOOK_EVENT=""
[[ "$STDIN_DATA" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && HOOK_EVENT="${BASH_REMATCH[1]}"
# fallback (2026-07-08): hook_event_name 필드 부재/형태불일치 시 payload 필드로 이벤트 판별.
#   근본원인 = perf 커밋(20d9c84) python→bash 전환 후 이 필드 의존 hook 만 PostToolUse 스킵.
#   post-action-tracker(hook_event_name 미사용)는 정상 → 대조로 확정.
#   동일 클래스 잔존이던 FILE_PATH/PROMPT bare python3 추출도 hook-input.sh 경유로 전환 (2026-07-14).
if [ -z "$HOOK_EVENT" ]; then
  if [[ "$STDIN_DATA" =~ \"tool_name\"[[:space:]]*: ]] || [[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*: ]] || [[ "$STDIN_DATA" =~ \"filePath\"[[:space:]]*: ]]; then
    HOOK_EVENT="PostToolUse"
  elif [[ "$STDIN_DATA" =~ \"prompt\"[[:space:]]*: ]]; then
    HOOK_EVENT="UserPromptSubmit"
  fi
fi

# ============= 헬퍼: 완료 마커 검사 =============
# 정규식 SSOT = lib/template-patterns.sh (2026-05-13 도입, audit S-3/H-2/H-3 묶음).
# 본 hook 의 has_completion_markers 는 lib 함수 wrapper 로 단순화.
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/template-patterns.sh" 2>/dev/null || {
  # lib 로드 실패 fallback — 인라인 정규식 보존 (회귀 안전성)
  # 정규식은 lib/template-patterns.sh has_status_done 과 동일 유지 (종결 키워드 4종, 단독 라인 엄격 — 2026-07-22)
  has_status_done() { [ -f "$1" ] && grep -qE '^(Status|상태):[[:space:]]*(Done|완료|폐기|Abandoned)[[:space:]]*$' "$1"; }
  has_self_critique_h2() { [ -f "$1" ] && grep -qE '^##[[:space:]]+.*Self-Critique' "$1"; }
  detect_self_critique_wrong_heading() { [ -f "$1" ] && grep -nE '^#{3,}[[:space:]]+.*Self-Critique|^#{1}[[:space:]]+.*Self-Critique' "$1" 2>/dev/null | head -1; }
  # 잔여 섹션 미체크박스 가드 (2026-07-23) — lib/template-patterns.sh has_residual_unchecked 와 동일 유지
  has_residual_unchecked() { [ -f "$1" ] && awk '/^##[[:space:]]+(잔여|TODO|Follow-up)/{inres=1;next} /^##[[:space:]]/{inres=0} inres && /^[[:space:]]*-[[:space:]]\[[[:space:]]\]/{found=1} END{exit(found?0:1)}' "$1"; }
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
  local force="$2"   # "force" = 잔여 가드 우회 (save now = /taskflow:done 슬래시 명시 이동, 2026-07-23 결정 1-B)
  [ -f "$working_file" ] || return 1

  # [게이트] 잔여 섹션 미체크박스 차단 (2026-07-23) — Status: Done 무검증 이동 방지.
  # ## 잔여/TODO/Follow-up 섹션에 - [ ] 잔존 시 이동 스킵. force 경로는 명시 강제라 우회(결정 1-B).
  # SSOT: docs/working/20260723/2026-07-23-claude-harness-done-gate-residual-block.md
  if [ "$force" != "force" ] && has_residual_unchecked "$working_file"; then
    echo "[working-lifecycle] $(basename "$working_file") — ## 잔여/TODO/Follow-up 섹션에 미체크박스(- [ ]) 잔존 → 이동 차단 (완료 아님). 강제 이동은 /taskflow:save now" >&2
    return 1
  fi

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

  # [전파] 작업분석 backlink 캡처 (mv 전 — 이동되면 working_file 이 사라져 grep 불가)
  #  Phase 4 권고 블록의 '출처: ...작업분석-*.md' 라인을 역추적 키로 사용 (custom-plugin/taskflow/commands/survey.md §전파)
  #  중복 제거 후 전건 보존 — 재실행 누적 시 여러 작업분석 문서를 모두 갱신 (silent cap 금지)
  local meta_docs_raw=""
  meta_docs_raw=$(grep -oE '[~/][^ `)]*작업분석[^ `)]*\.md' "$working_file" 2>/dev/null | sort -u)

  # 이동
  mv "$working_file" "$target_file" 2>/dev/null || {
    echo "[working-lifecycle] $filename — 이동 실패: $working_file → $target_file" >&2
    return 1
  }

  # step 평면 파일 → steps/ 분배 이동 (보완형 step 정책, 2026-05-29)
  # working/YYYYMMDD/{date}-{product}-{task}-step-NN-{slug}.md → tasks/.../{task}/steps/NN-{slug}.md
  # (mv 는 PreToolUse hook 미경유 → tasks/ prefix 강제 우회. 사용자 preview 구조 steps/NN-slug.md 정합)
  local working_dir
  working_dir=$(dirname "$working_file")
  local step_prefix="${date_part}-${product}-${task_name}-step-"
  local moved_steps=0
  for step_file in "$working_dir/${step_prefix}"*.md; do
    [ -f "$step_file" ] || continue
    local step_rest
    step_rest=$(basename "$step_file")
    step_rest=${step_rest#"$step_prefix"}   # NN-{slug}.md
    mkdir -p "$target_dir/steps" 2>/dev/null
    if mv "$step_file" "$target_dir/steps/$step_rest" 2>/dev/null; then
      moved_steps=$((moved_steps + 1))
    fi
  done
  [ "$moved_steps" -gt 0 ] && echo "[working-lifecycle] ✓ step 분배: ${moved_steps}건 → tasks/$yyyymmdd/$task_name/steps/" >&2

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

  # [전파] 작업분석 인덱스 역갱신 (best-effort 비차단, 2026-06-09)
  #  - Phase 4 backlink 가 plan 문서에 심긴 작업만 추적 (없으면 meta_doc_raw 공백 → skip)
  #  - 작업분석 문서의 | {task_name} | 행: 상태 ⏳ Plan → ✓ Done + working 링크 → tasks 링크
  #  - 직접 파일 쓰기(도구 아님) → PostToolUse 재귀 없음. 실패해도 위 이동(기존 동작)엔 무영향.
  #  SSOT: custom-plugin/taskflow/commands/survey.md §전파
  if [ -n "$meta_docs_raw" ]; then
    local tasks_link_home="~/.claude/docs/${product}/tasks/${yyyymmdd}/${task_name}/${date_part}-${task_name}-unified.md"
    # python 스크립트를 임시 파일로 1회 작성 (2026-06-09 수정):
    #   heredoc-in-$()-in-`while...done <<<` 중첩은 일부 bash 파서에서 syntax error(near `fi`)를
    #   유발해 hook 전체 파싱이 실패한다(핵심 working→tasks 이동까지 마비). heredoc 을 루프·$() 밖
    #   파일 리다이렉트(`cat > file <<EOF`, 가장 portable 한 형태)로 분리해 회피.
    local prop_py_file
    prop_py_file=$(mktemp 2>/dev/null) || prop_py_file="${TMPDIR:-/tmp}/wl-prop-$$-${RANDOM}.py"
    cat > "$prop_py_file" <<'PYEOF'
import sys, re
doc, task, tasks_link, link_text = sys.argv[1:5]
try:
    with open(doc, encoding='utf-8') as f:
        lines = f.read().split('\n')
except Exception:
    sys.exit(0)
new_link_md = f'[{link_text}]({tasks_link})'
row_key = re.compile(r'\|\s*`?' + re.escape(task) + r'`?\s*\|')        # | {작업명} | 셀 정확 매칭 (백틱 옵션)
work_link = re.compile(r'\[[^\]]*\]\((?:~|/|[A-Za-z]:)[^)]*?/working/[^)]*?\.md\)')  # working/ 가리키는 md 링크
status_pat = re.compile(r'⏳\s*Plan(?:\s*Complete)?')
changed = False
for i, l in enumerate(lines):
    if not l.lstrip().startswith('|'):
        continue
    if not row_key.search(l):
        continue
    nl = work_link.sub(new_link_md, l)
    nl = status_pat.sub('✓ Done', nl)
    if nl != l:
        lines[i] = nl
        changed = True
if changed:
    with open(doc, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print('updated')
PYEOF
    while IFS= read -r meta_doc_raw; do
      [ -n "$meta_doc_raw" ] || continue
      local meta_doc="${meta_doc_raw/#\~/$HOME}"
      [ -f "$meta_doc" ] || meta_doc=$(echo "$meta_doc" | sed 's|^C:|/c|')
      [ -f "$meta_doc" ] || continue
      local prop_result
      prop_result=$(python3 "$prop_py_file" "$meta_doc" "$task_name" "$tasks_link_home" "${date_part}-${task_name}-unified.md")
      if [ "$prop_result" = "updated" ]; then
        echo "[working-lifecycle] ✓ 전파: $(basename "$meta_doc") 인덱스 '$task_name' 행 → ✓ Done + tasks 링크" >&2
      fi
    done <<< "$meta_docs_raw"
    rm -f "$prop_py_file" 2>/dev/null
  fi

  echo "[working-lifecycle] ✓ 이동: $filename → tasks/$yyyymmdd/$task_name/${date_part}-${task_name}-unified.md" >&2
  return 0
}

# ============= PostToolUse 진입 =============
if [ "$HOOK_EVENT" = "PostToolUse" ]; then
  # FILE_PATH 추출 = hook-input.sh (tool_input.file_path 우선 / filePath fallback — Edit·Write 양 필드 동일 경로).
  # lib 부재 시 기존 침묵 exit 0 유지 (fail-open 정책 보존).
  type -t hook_parse_file_path >/dev/null 2>&1 || exit 0
  hook_parse_file_path

  [ -z "$FILE_PATH" ] && exit 0

  # Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
  FILE_PATH_NORM=$(normalize_path "$FILE_PATH")

  echo "$FILE_PATH_NORM" | grep -qE '/docs/working/[0-9]{8}/[^/]+\.md$' || exit 0

  # step 평면 파일은 마스터 이동 트리거 대상 아님 (보완형 step 정책, 2026-05-29)
  # {date}-{product}-{작업}-step-NN-{slug}.md — '-step-숫자-' 패턴. step frontmatter '상태: Done'
  # 이 마스터 완료 마커를 오트리거하는 것을 차단 (step 파일엔 ## Self-Critique 도 없지만 이중 가드)
  if echo "$FILE_PATH_NORM" | grep -qE -- '-step-[0-9]+-[^/]*\.md$'; then exit 0; fi

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
  # PROMPT 추출 = hook-input.sh (키워드 grep 용도 — bash-primary 의 escape 따옴표 절단은 허용 한계로 기록).
  PROMPT=""
  type -t hook_parse_field >/dev/null 2>&1 && PROMPT=$(hook_parse_field "prompt")

  # 명시 키워드 매칭 (case-insensitive 일부 + Korean)
  if echo "$PROMPT" | grep -qE '(작업[[:space:]]*완료|tasks[[:space:]]*이동|working[[:space:]]*정리|/taskflow:done|완료[[:space:]]*저장)' \
     || echo "$PROMPT" | grep -qiE '(^|[[:space:]])done([[:space:]]|$|\.|,|!)' ; then

    # ===== 경로 판별: 슬래시 명시(/taskflow:done·/done) vs 자연어 키워드 (오발동 가드, 2026-07-14) =====
    # 슬래시 명시 호출과 본문 마커 자동(PostToolUse)은 기존대로 확인 없이 즉시 이동. 자연어 경로에만 가드 적용.
    IS_SLASH_DONE=0
    echo "$PROMPT" | grep -qE '/(taskflow:)?done' && IS_SLASH_DONE=1

    if [ "$IS_SLASH_DONE" -eq 0 ]; then
      # [가드 1] 부정문 동반 시 발동 안 함 — "아직 done 처리 하지 마" 류 오발동 차단
      if echo "$PROMPT" | grep -qE '(하지[[:space:]]*마|말고|아직|안[[:space:]]|않|금지|보류)'; then
        echo "[working-lifecycle] done 키워드 매칭 but 부정 표현 동반 → 자동 이동 발동 안 함 (오발동 가드)" >&2
        exit 0
      fi
      # [가드 2] 확인 스텝 — 자연어 경로는 즉시 이동하지 않고 대상 개수만 계산해 확인을 요청한다.
      #   실제 이동은 사용자 확인 후 /taskflow:done (슬래시 경로) 로 수행. stdout = UserPromptSubmit 컨텍스트 주입.
      working_root="$HOME/.claude/docs/working"
      [ -d "$working_root" ] || exit 0
      pending_count=0
      pending_names=""
      for dir in "$working_root"/*/; do
        [ -d "$dir" ] || continue
        for f in "$dir"*.md; do
          [ -f "$f" ] || continue
          basename "$f" | grep -qE -- '-step-[0-9]+-' && continue   # step 평면 파일 제외
          if has_completion_markers "$f"; then
            pending_count=$((pending_count + 1))
            pending_names="${pending_names}${pending_names:+, }$(basename "$f")"
          fi
        done
      done
      if [ "$pending_count" -gt 0 ]; then
        echo "[working-lifecycle 확인 요청] 자연어 'done' 키워드 감지 — working/ → tasks/ 이동 대상 ${pending_count}건: ${pending_names}. 사용자에게 \"working/ 문서를 tasks/ 로 이동할까요? (대상 ${pending_count}건)\" 을 1회 확인한 뒤 승인 시 /taskflow:done 을 실행하라. 미승인 시 이동하지 말 것."
      else
        echo "[working-lifecycle] 자연어 'done' 키워드 감지 but 완료 마커(Status:Done + ## Self-Critique) 충족 파일 0건 — 이동 대상 없음" >&2
      fi
      exit 0
    fi

    # ===== 슬래시 명시 경로(/taskflow:done) — 기존대로 확인 없이 즉시 이동 (변경 금지) =====
    moved_count=0
    working_root="$HOME/.claude/docs/working"
    [ -d "$working_root" ] || exit 0

    skipped_count=0
    for dir in "$working_root"/*/; do
      [ -d "$dir" ] || continue
      for f in "$dir"*.md; do
        [ -f "$f" ] || continue
        if ! has_completion_markers "$f"; then
          # 미충족 사유를 조건별로 분리 출력 (2026-07-22) — 구 통합 메시지는 어느 조건이
          # 깨졌는지 알려주지 않아 "hook 고장" 오진을 유발했다 (실측 1회).
          if ! has_status_done "$f"; then
            skip_reason="종결 마커 부재 — 'Status: Done'(또는 완료/폐기/Abandoned) **단독 라인** 필요. 요약·사유는 '> 완료 요약: ...' 인용문으로 분리"
          else
            skip_reason="'## Self-Critique' (h2) 부재"
          fi
          echo "[working-lifecycle] $(basename "$f") — $skip_reason → 스킵" >&2
          skipped_count=$((skipped_count + 1))
          continue
        fi
        if move_working_to_tasks "$f" force; then   # 슬래시 /taskflow:done = save now → 잔여 가드 우회(결정 1-B)
          moved_count=$((moved_count + 1))
        fi
      done
    done

    if [ "$moved_count" -gt 0 ] || [ "$skipped_count" -gt 0 ]; then
      echo "[working-lifecycle] 명시 키워드 트리거 — 이동 ${moved_count}건 / 스킵 ${skipped_count}건 (Partial 보존)" >&2
    fi

    # dispatch done 문서 정리 (2026-06-15 — /taskflow:done 통합)
    #  working/ 이동과 대칭: 완료된 분배 문서를 {product}/tasks/{today}/dispatch-archive/ 로 이동.
    #  dispatch_purge_done 이 lock 안 원자 처리 → 다중 세션 race 차단. 미가용 시 비차단 skip.
    #  SSOT: hooks/lib/dispatch-utils.sh::dispatch_purge_done
    if source "$(dirname "${BASH_SOURCE[0]}")/lib/dispatch-utils.sh" 2>/dev/null; then
      purge_result="$(dispatch_purge_done 2>/dev/null)"
      [ -n "$purge_result" ] && echo "[working-lifecycle] $purge_result" >&2

      # 본 세션 점유 release (2026-06-15 — /taskflow:done 세션 마무리 시 orphan 방지)
      #  session_id 가용 시 본 sid 의 DISPATCH claim(available 복귀) + REGISTRY entry(paused) 를
      #  함께 release. Stop hook(working-release.sh) 안전망과 중복이나, 슬래시 명시 시 즉시 정리.
      WL_SID=$(echo "$STDIN_DATA" | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('session_id',''))
except: print('')
" 2>/dev/null)
      if [ -n "$WL_SID" ]; then
        WL_SID8="${WL_SID:0:8}"
        rel_d="$(dispatch_release_session "$WL_SID8" 2>/dev/null)"
        [ -n "$rel_d" ] && echo "[working-lifecycle] $rel_d" >&2
        rel_r="$(registry_release_session "$WL_SID8" paused 2>/dev/null)"
        [ -n "$rel_r" ] && echo "[working-lifecycle] $rel_r" >&2
      fi
    fi
  fi

  exit 0
fi

exit 0
