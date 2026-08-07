#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "backlog-lifecycle" "enter" "pid=$$"
# backlog-lifecycle.sh — working backlog 완료 시 tasks/ 자동 이동 (2026-05-13 시행, 2026-08-06 경로 이관)
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
# 경로 이관 (2026-08-06): 본문 저장처가 `memory/backlog_{slug}.md` → `docs/working/backlog/{yyyy-mm-dd}-{slug}.md`
#   로 바뀌었다 (사용자 직접 열람 경로 통일). 신 경로만 지원(진입 게이트 기준) — 구 경로는 처리 대상 아님.
#   frontmatter 구조(`metadata:` 하위 `status: pending|done`)는 불변.
#   **MEMORY.md/BACKLOG.md 인덱스 entry 제거 판정 (콜드리뷰 R5 M2, 3라운드 만에 정정 — always-on 헤더가
#   구현과 반대로 적혀 다음 라운드를 또 뒤집게 만들었었다):** href 토큰 합집합(구 `backlog_{slug}.md`
#   ∪ 신 `backlog/{yyyy-mm-dd}-{slug}.md`)을 **1차 매칭 키**로 쓴다. 링크 텍스트(`[{slug}]`) 단독
#   매칭은 실 MEMORY.md 링크 37건 중 9건(24%)이 표시 목적으로 34자 절단돼 있어(예:
#   `[api-keys-unset-all-envs-pbx-blocke]` vs slug `...-blocked`) 못 쓴다 — href 는 축약되지 않고
#   항상 slug 전문을 담는다. 링크 텍스트는 href 가 전혀 없을 때만 "noref"(보류 신호)로 격하한다.
#   상세 근거·판별식은 `move_backlog_to_tasks()` 본문 주석 SSOT.
#   `verify_index_sync()` 는 이것과 **비대칭이다** — "인덱스에 있는데 본문 없음"(죽은 링크) 축만 본다.
#   "본문 있는데 인덱스 없음" 축은 없다: MEMORY.md 는 큐레이션 인덱스(자기 헤더가 "완전종결·비차단
#   backlog는 인덱스 제거" 라고 명시)라 미등재가 정상 상태이지 drift 가 아니다(콜드리뷰 R5 High).
#
# 진입점 (PostToolUse + UserPromptSubmit 양쪽 등록):
#   1. PostToolUse:Edit|Write — $BACKLOG_SRC_DIR(홈 경로 앵커, 콜드리뷰 Medium-5) 하위 *.md 저장 직후
#      status: done 마커 자동 감지. 날짜 형식 검증은 게이트에서 하지 않는다(콜드리뷰 Medium-4 — 게이트에서
#      날짜를 요구하면 이관 중인 구 경로 잔존분이 이 경로를 완전 침묵 스킵한다). 날짜 검증·스킵 사유 stderr 는
#      move_backlog_to_tasks() 의 case 문이 담당.
#      - 마커: frontmatter `status:[[:space:]]*done` (한 줄, frontmatter 안 위치)
#   2. UserPromptSubmit — 사용자 명시 키워드 매칭 시 docs/working/backlog/ 디렉토리 전체 스캔
#      - 키워드: "backlog 완료" / "backlog 정리" / "backlog 이동" / "/backlog-done"
#
# 이동 절차:
#   1. 파일명 파싱 — {yyyy-mm-dd}-{slug}.md → slug 추출 (파일명 자체는 생성일 prefix 유지한 채 그대로 이동)
#   2. frontmatter `product:` 필드 추출 (없으면 "claude-harness" 기본)
#   3. frontmatter `completed:` 필드 = 오늘(완료일) 자동 채움 (없을 시)
#   4. 대상 경로 = ~/.claude/docs/{product}/tasks/{YYYYMMDD(완료일=오늘)}/backlog/{yyyy-mm-dd}-{slug}.md.
#      **폴더는 완료일**(콜드리뷰 High-3) — backlog 는 생성~완료 간극이 수개월인 사례가 실측돼(2026-05·07
#      생성분), working-lifecycle.sh 처럼 파일명 날짜를 폴더로 쓰면 history.md/오늘 summary.md 가 엉뚱한
#      과거 날짜 폴더를 갱신하게 된다. 파일명만 생성일 prefix 를 유지한다(사용자 확정 규약).
#   5. mkdir -p + mv (docs/working/backlog → tasks)
#   6. MEMORY.md·BACKLOG.md 에서 slug 기준 entry 제거 — 제거 0건이면 stderr 안내(콜드리뷰 Medium-6)
#   7. tasks/history.md + tasks/{완료일}/summary.md 자동 갱신
#   8. stderr 로 이동 결과 1줄 보고 (+ 구 경로에 동일 slug 잔존 시 고아 경고, 콜드리뷰 Medium-7)

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/path-utils.sh" 2>/dev/null || true

STDIN_DATA=$(cat)
DOCS_ROOT="$HOME/.claude/docs"
# normalize_path 필수(콜드리뷰 R3 Medium-2) — $HOME 이 백슬래시(C:\Users\PV) 나 trailing slash
# (/c/Users/PV/) 로 오면 앵커 문자열이 정규화된 file_path_win 과 영원히 불일치해 전체 이동이
# 조용히 실패한다. path-utils.sh 는 위에서 이미 source 됨.
BACKLOG_SRC_DIR=$(normalize_path "$DOCS_ROOT/working/backlog")

# MEMORY.md/BACKLOG.md read-modify-write lock (콜드리뷰 M4) — mkdir 원자적 lock + TTL stale 회수.
# dispatch-utils.sh::dispatch_lock_acquire/release(hooks/lib/dispatch-utils.sh)와 동일 패턴 재사용
# (새 lock 메커니즘 작성 금지). DISPATCH_LOCK 과 별도 경로 — backlog index 갱신이 DISPATCH.md CRUD 를
# 불필요하게 막지 않도록 전용 lock 파일을 쓴다.
# 동일 mkdir+TTL 패턴 3곳 복제(dispatch-utils.sh:55 / registry-utils.sh:24 / 여기) — 공용 lib 승격은
# 지적대로 타당하나, 지금 여러 세션이 실사용 중인 REGISTRY·DISPATCH 동시성 코드를 건드리는 별건이라
# 이번 backlog 경로 이관 범위 밖으로 남긴다(콜드리뷰 R4, 승격 시 회귀 피해가 이 작업보다 크다).
BACKLOG_INDEX_LOCK="${BACKLOG_INDEX_LOCK:-/tmp/claude-backlog-index.lock.d}"
BACKLOG_INDEX_LOCK_RETRIES="${BACKLOG_INDEX_LOCK_RETRIES:-50}"
BACKLOG_INDEX_LOCK_SLEEP="${BACKLOG_INDEX_LOCK_SLEEP:-0.1}"
BACKLOG_INDEX_LOCK_TTL_MIN="${BACKLOG_INDEX_LOCK_TTL_MIN:-2}"

backlog_index_lock_acquire() {
  local i=0
  while ! mkdir "$BACKLOG_INDEX_LOCK" 2>/dev/null; do
    if [ -d "$BACKLOG_INDEX_LOCK" ] && find "$BACKLOG_INDEX_LOCK" -maxdepth 0 -mmin "+$BACKLOG_INDEX_LOCK_TTL_MIN" 2>/dev/null | grep -q .; then
      rmdir "$BACKLOG_INDEX_LOCK" 2>/dev/null
      echo "[backlog-lifecycle] stale index lock 회수 (>${BACKLOG_INDEX_LOCK_TTL_MIN}min orphan): $BACKLOG_INDEX_LOCK" >&2
      continue
    fi
    i=$((i + 1))
    if [ "$i" -ge "$BACKLOG_INDEX_LOCK_RETRIES" ]; then
      echo "[backlog-lifecycle] index lock timeout: $BACKLOG_INDEX_LOCK" >&2
      return 1
    fi
    sleep "$BACKLOG_INDEX_LOCK_SLEEP"
  done
  return 0
}

backlog_index_lock_release() {
  rmdir "$BACKLOG_INDEX_LOCK" 2>/dev/null || true
}

# Git Bash path (/c/Users/...) ↔ Windows path (C:/Users/...) 변환 — Python (Windows native) 가 인식 가능하도록.
# 소문자 드라이브 표기(c:/Users/...)도 대문자로 통일한다(콜드리뷰 R2 Medium-4) — 안 하면 페이로드가
# 소문자 드라이브로 오는 케이스에서 $BACKLOG_SRC_DIR 앵커 비교가 대소문자 불일치로 침묵 실패한다.
to_win_path() {
  local p="$1"
  case "$p" in
    /c/*) echo "C:/${p#/c/}" ;;
    /C/*) echo "C:/${p#/C/}" ;;
    c:/*) echo "C:/${p#c:/}" ;;
    *)    echo "$p" ;;
  esac
}

# hook_event_name — bash 내장 (python 起動 제거)
HOOK_EVENT=""
[[ "$STDIN_DATA" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && HOOK_EVENT="${BASH_REMATCH[1]}"
# fallback (2026-07-08): hook_event_name 필드 부재/형태불일치 시 payload 필드로 이벤트 판별.
#   근본원인 = perf 커밋(20d9c84) python→bash 전환 후 이 필드 의존 hook 만 PostToolUse 스킵.
#   post-action-tracker(hook_event_name 미사용)는 정상 → 대조로 확정.
if [ -z "$HOOK_EVENT" ]; then
  if [[ "$STDIN_DATA" =~ \"tool_name\"[[:space:]]*: ]] || [[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*: ]] || [[ "$STDIN_DATA" =~ \"filePath\"[[:space:]]*: ]]; then
    HOOK_EVENT="PostToolUse"
  elif [[ "$STDIN_DATA" =~ \"prompt\"[[:space:]]*: ]]; then
    HOOK_EVENT="UserPromptSubmit"
  fi
fi

# ============= 헬퍼: 전 프로젝트 memory 디렉토리 목록 (콜드리뷰 H1, R4 에서 all_index_files 분리) =============
# backlog 본문 저장처는 product 무분리(docs/working/backlog/, 단일 경로)로 통합됐지만, MEMORY.md/
# BACKLOG.md 인덱스 entry·구 경로 backlog_*.md 본문은 그 backlog 를 만든 세션의 project 별 memory 에
# 흩어져 있다 — 이전엔 소스도 인덱스도 harness home(projects/C--Users-PV--claude/memory) 하나였지만
# 지금은 소스만 단일화됐다. 실측(2026-08-06): harness home 외 다른 project 별 memory 에도 상당수가
# 별도로 존재한다(구체적 건수는 여기 적지 않는다 — 매 실측마다 값이 바뀌어 stale 되므로, 콜드리뷰
# R6 L2). product 값에서 project 디렉토리명을 역산하는
# 규칙은 harness 에 없다(product-resolver.sh 는 cwd→product 단방향뿐) — 게다가 실제 project
# 디렉토리명은 세션이 그 cwd 를 최초로 어떻게 표기했는지에 따라 대소문자·구분자가 갈린다
# (`C--Works-hongcafe-global-backend` vs `c--Works-hongcafe3` 등 실측 혼재). 그래서 product→디렉토리
# 역산을 시도하는 대신 전 project memory 를 훑어 안전하게 처리한다. warn_old_location()·
# move_backlog_to_tasks() 의 구/신 동시 존재 고아 감지 블록·verify_index_sync() 가 모두 이 목록을
# 공유해야 "전 project 훑기"가 실제로 전부에 적용된다(콜드리뷰 R4 H3/M1/M2 — all_index_files() 만
# 고치고 이 세 곳을 안 고쳐 재발했었다). 라인번호가 아니라 함수명으로 참조한다(콜드리뷰 R5 L1 —
# 라인번호 참조는 편집마다 stale 된다, 실측: has_done_marker(:111)→167 등 3곳 모두 어긋나 있었다).
all_memory_dirs() {
  local d
  for d in "$HOME/.claude/projects"/*/memory; do
    [ -d "$d" ] && echo "$d"
  done
}

# ============= 헬퍼: 전 프로젝트 index 파일(MEMORY.md/BACKLOG.md) 목록 =============
all_index_files() {
  local d
  while IFS= read -r d; do
    [ -f "$d/MEMORY.md" ] && echo "$d/MEMORY.md"
    [ -f "$d/BACKLOG.md" ] && echo "$d/BACKLOG.md"
  done < <(all_memory_dirs)
}

# ============= 헬퍼: 구 경로(memory/backlog_*.md) 잔존 안내 =============
# 신 경로만 지원(설계 결정) — 구 경로 파일은 처리 대상이 아니다. 잔존분이 별도 step 으로
# 이관될 때까지 공백이 생기므로, 잔존 건수만 stderr 1줄로 안내한다 (개별 파일 나열은 노이즈라 금지).
# 전 project 합산(콜드리뷰 R4 M1) — 이전엔 harness home 프로젝트 디렉토리 하나만 세어 실제보다
# 훨씬 적게 보고했다(구체적 건수는 여기 적지 않는다 — 실측할 때마다 값이 바뀌어 매번 stale 됐다,
# 콜드리뷰 R6 L2). all_memory_dirs() 로 전 project 를 순회해야 S2 "구 경로 잔존분 안내" 가 실제로
# 충족된다.
warn_old_location() {
  local old_count=0 f d
  while IFS= read -r d; do
    for f in "$d"/backlog_*.md; do
      [ -f "$f" ] && old_count=$((old_count + 1))
    done
  done < <(all_memory_dirs)
  [ "$old_count" -gt 0 ] && echo "[backlog-lifecycle] 구 경로(memory/backlog_*.md) 잔존 ${old_count}건(전 project 합산) — 신 경로(docs/working/backlog/) 미지원, 별도 이관 필요" >&2
  return 0
}

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
    # `[ \t]*` (콜드리뷰 L2) — `\s*` 는 개행도 삼켜 frontmatter 종료 `---` 뒤 공백 줄까지 매치에
    # 포함시킨다. 쓰기 경로(completed: 삽입)가 그 매치 전체를 치환하면 원본에 있던 빈 줄이 사라진다.
    # `[ \t]*` 는 `---` 줄 자체의 trailing 공백/탭만 허용하고 다음 줄로는 넘어가지 않는다.
    m = re.match(r'^---[ \t]*\n(.*?)\n---[ \t]*\n', content, re.DOTALL)
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

  # {yyyy-mm-dd}-{slug}.md 파일명 패턴 (2026-08-06 경로 이관 — 구 backlog_{slug}.md 지원 안 함)
  case "$filename" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;
    *) echo "[backlog-lifecycle] $filename — 파일명 패턴 불일치 ({yyyy-mm-dd}-{slug}.md 필요), 스킵" >&2; return 1 ;;
  esac

  local slug
  slug="${filename:11}"
  slug="${slug%.md}"

  # 경계값: {yyyy-mm-dd}-.md (slug 없이 날짜+대시만) 도 위 case 가드를 통과한다 — `*.md` 가 빈 문자열도
  # 매칭하기 때문. slug 가 비면 MEMORY.md/BACKLOG.md 인덱스 제거 매칭 키가 `[]`(빈 대괄호)가 되어
  # 무관한 라인과 우연히 충돌할 위험이 생긴다. 여기서 명시 차단한다 (실측: 2026-08-06 e2e 검증).
  if [ -z "$slug" ]; then
    echo "[backlog-lifecycle] $filename — slug 없음 ({yyyy-mm-dd}-{slug}.md 의 slug 부분이 비어있음), 스킵" >&2
    return 1
  fi

  # frontmatter 에서 product 추출 (기본값 = claude-harness)
  local product win_backlog
  win_backlog=$(to_win_path "$backlog_file")
  product=$(python3 - "$win_backlog" <<'PYEOF' 2>/dev/null
import sys, re
file_path = sys.argv[1]
try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read(4096)
    # `[ \t]*` (콜드리뷰 L2) — `\s*` 는 개행도 삼켜 frontmatter 종료 `---` 뒤 공백 줄까지 매치에
    # 포함시킨다. 쓰기 경로(completed: 삽입)가 그 매치 전체를 치환하면 원본에 있던 빈 줄이 사라진다.
    # `[ \t]*` 는 `---` 줄 자체의 trailing 공백/탭만 허용하고 다음 줄로는 넘어가지 않는다.
    m = re.match(r'^---[ \t]*\n(.*?)\n---[ \t]*\n', content, re.DOTALL)
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
  # 보안: frontmatter `product:` 화이트리스트 검증(콜드리뷰 M2) — 이 값은 검증 없이 mkdir -p/mv 의
  # 대상 경로(target_dir/history/summary)에 그대로 들어간다. `product: ../../../pwned` 처럼 경로
  # 구분자·traversal 세그먼트가 섞이면 $DOCS_ROOT 바깥으로 파일이 반출된다. PostToolUse 게이트는
  # 소스 파일 경로의 traversal 만 막고(위 anchor 검사) frontmatter 값 경유는 막지 않는다 — 소스가
  # "Claude 내부 memory" 에서 "사용자가 직접 편집하는 docs 트리" 로 옮겨져 노출면이 커졌으므로 여기서
  # 별도 화이트리스트(영숫자/언더스코어/하이픈만)로 차단한다.
  case "$product" in
    *[!A-Za-z0-9_-]*)
      echo "[backlog-lifecycle] $filename — product 값이 허용 문자(영숫자/_/-) 밖: '$product', claude-harness 로 대체" >&2
      product="claude-harness"
      ;;
  esac

  # yyyymmdd = 완료일(오늘, 폴더 결정용) — 파일명 자체는 생성일 prefix 를 그대로 유지한다.
  # (콜드리뷰 High-3: backlog 생성~완료 간극이 수개월인 사례가 실측돼, 파일명 날짜를 폴더로 쓰면
  #  history.md/오늘 summary.md 가 엉뚱한 과거 날짜 폴더를 갱신하게 된다.)
  local yyyymmdd today_dot today_date
  yyyymmdd=$(date +%Y%m%d)
  today_dot=$(date +%Y.%m.%d)
  today_date=$(date +%Y-%m-%d)

  # 대상 경로 = ~/.claude/docs/{product}/tasks/{완료일 YYYYMMDD}/backlog/{filename} (파일명은 생성일 prefix 유지)
  local target_dir="$DOCS_ROOT/$product/tasks/$yyyymmdd/backlog"
  local target_file="$target_dir/${filename}"

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

  # completed 필드 자동 채움 (없을 시, 실제 완료일 = today_date)
  # metadata: 하위 status: 라인과 같은 들여쓰기로 그 바로 뒤에 삽입한다 — 최상위(컬럼 0)에 붙이면
  # frontmatter 계약(`metadata:` 하위에 status/product/created/completed 통일)이 깨진다(콜드리뷰 R2 Medium-5).
  python3 - "$win_backlog" "$today_date" <<'PYEOF' 2>/dev/null
import sys, re
file_path = sys.argv[1]
date_str = sys.argv[2]
try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    # `[ \t]*` (콜드리뷰 L2) — `\s*` 는 개행도 삼켜 frontmatter 종료 `---` 뒤 공백 줄까지 매치에
    # 포함시킨다. 쓰기 경로(completed: 삽입)가 그 매치 전체를 치환하면 원본에 있던 빈 줄이 사라진다.
    # `[ \t]*` 는 `---` 줄 자체의 trailing 공백/탭만 허용하고 다음 줄로는 넘어가지 않는다.
    m = re.match(r'^---[ \t]*\n(.*?)\n---[ \t]*\n', content, re.DOTALL)
    if m:
        fm = m.group(1)
        # has_done_marker() 는 re.IGNORECASE 로 `Status: Done` 도 done 으로 인정한다 — 여기 두
        # re.search 가 case-sensitive 로 남으면 status: 매칭이 실패해 completed: 가 metadata: 밖
        # (컬럼 0)으로 새 나가고, Completed: 기존 존재 검사도 놓쳐 중복 삽입된다(콜드리뷰 R3 Medium-4).
        if not re.search(r'^\s*completed:', fm, re.MULTILINE | re.IGNORECASE):
            sm = re.search(r'^([ \t]*)status:.*$', fm, re.MULTILINE | re.IGNORECASE)
            if sm:
                indent = sm.group(1)
                new_fm = fm[:sm.end()] + f"\n{indent}completed: {date_str}" + fm[sm.end():]
            else:
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

  # MEMORY.md 인덱스 + BACKLOG.md 상세 양쪽에서 entry 제거 (2026-07-31 분리 이후 2파일)
  # **매칭 키 = href 토큰 합집합(콜드리뷰 R4 High-1 — 링크 텍스트 단독 매칭에서 되돌림)** — 이전
  # 라운드가 링크 텍스트(`[{slug}]`) 를 매칭 키로 바꿨는데, 실 MEMORY.md 링크 37건 중 9건(24%)이
  # 표시 목적으로 34자 절단돼 있어(`[api-keys-unset-all-envs-pbx-blocke]` vs slug
  # `api-keys-unset-all-envs-pbx-blocked`) 링크 텍스트만으로는 매칭이 안 되고, 링크 없이 본문에
  # bare 로 언급된 13건도 동일하게 놓쳤다(실측). 반대로 href(`backlog_{slug}.md` 구 포맷 /
  # `backlog/{yyyy-mm-dd}-{slug}.md` 신 포맷) 는 축약되지 않고 항상 slug 전문을 담는다 — 그래서
  # href 합집합을 1차 매칭 키로 쓰고, 링크 텍스트(`[{slug}]`) 는 href 가 전혀 없을 때만 "noref"
  # (보류 신호)로 격하한다. 이렇게 하면 href 회귀(24% 누락)와 링크텍스트 단독 매칭의 오삭제
  # 위험(무관 Project entry, 콜드리뷰 R2 High-1) 둘 다 닫힌다 — **다시 뒤집지 말 것.**
  # **판별식 = 라인 안 서로 다른 backlog href 개수(콜드리뷰 R4 High-2, R3 Medium-6 재정정)** —
  # "- [" 시작 개수는 실제 MEMORY.md 병합 표기 `- [a](…)·[b](…)` 에서 1로 세어(두 번째 항목엔 `-`
  # 가 없다) 형제 entry 를 경고 없이 통째로 지웠다(실측 `img-server-const-undefined-fatal` done
  # 처리 시 같은 줄의 `naver-api-const-undefined-fatal` 소실). href 토큰을 직접 세면 병합 라인은
  # 정확히 2 로 잡혀 manual 보류된다. **대가**: 한 entry 안에 다른 backlog 로의 단순 참조 링크가
  # 섞인 경우(구 R2 Medium-2 가 막으려던 case)도 이제는 manual 로 보류된다 — 오탐(과소삭제)이
  # 오삭제(형제 entry 소실)보다 훨씬 싸므로 보수적인 쪽을 택한다.
  # **파일 1개당 python 1회가 아니라 slug 1개당 python 1회(콜드리뷰 R4 M6)** — 이전엔 index 파일마다
  # 별도 python3 프로세스를 띄워 파일 1건 이동에 프로세스 ≈15개(실측 python3 11회, 0.59초)가 들었다.
  # 소스가 harness 26건 전용에서 전 product 공용으로 커지며 index 파일 수(project 별 MEMORY.md/
  # BACKLOG.md)가 늘어 UserPromptSubmit 일괄 처리 시 수십 초 블로킹 위험이 생겼다 — index 파일
  # 목록을 argv 로 한 번에 넘겨 파이썬 내부에서 순회한다.
  local index_files_arr=()
  local index_file
  while IFS= read -r index_file; do
    [ -n "$index_file" ] && index_files_arr+=("$index_file")
  done < <(all_index_files)

  # **동시성 lock(콜드리뷰 M4)** — backlog 소스가 세션·product 공용이 되며 두 세션이 서로 다른
  # backlog 를 동시에 done 처리할 가능성이 현실화됐다. lock 없이 read-modify-write 가 겹치면 뒤
  # 쓰기가 앞 제거를 덮어 entry 가 조용히 되살아난다. lock 획득 실패는 비차단(최선 노력) — 이 시점엔
  # 이미 파일이 물리 이동됐으므로 인덱스 정리를 포기해도 롤백할 게 없다, 경고만 남기고 계속한다.
  local any_found=0 index_incomplete=0
  local index_locked=0
  backlog_index_lock_acquire && index_locked=1
  if [ "$index_locked" -ne 1 ]; then
    # index_incomplete 도 세운다(콜드리뷰 R6 M4) — 이전엔 lock 실패로 read-modify-write 를 무보호로
    # 강행했는데(주석이 스스로 지목한 "뒤 쓰기가 앞 제거를 덮어 entry 가 되살아난다" 실패 모드) 최종
    # 마커는 `✓ 이동` 이었다. △/✓ 를 가르는 목적("훑어만 봐도 인덱스 정리 여부가 보인다")과 어긋난다.
    echo "[backlog-lifecycle] index lock 획득 실패 — 동시 편집 위험 감수하고 계속 진행" >&2
    index_incomplete=1
  fi

  if [ "${#index_files_arr[@]}" -gt 0 ]; then
    local win_index_files=()
    local wf
    for wf in "${index_files_arr[@]}"; do
      win_index_files+=("$(to_win_path "$wf")")
    done
    local idx_out
    idx_out=$(python3 - "$slug" "${win_index_files[@]}" <<'PYEOF' 2>/dev/null
import re, sys
slug = sys.argv[1]
index_paths = sys.argv[2:]

href_a_token = f"backlog_{slug}.md"
href_b_re = re.compile(r'backlog/\d{4}-\d{2}-\d{2}-' + re.escape(slug) + r'\.md')
marker = f"[{slug}]"
# 슬러그 무관 전 backlog href 토큰 — 라인에 몇 개의 서로 다른 backlog entry 가 섞였는지 판별용(High-2)
any_link_re = re.compile(r'backlog_[^\s\]\)]+\.md|backlog/\d{4}-\d{2}-\d{2}-[^\s\]\)]+\.md')
# 그룹라벨 대표줄 판별(2026-08-07 High) — href 개수만으로는 "- 🟠 인프라·메시징·위생군 — [slug](href)…"
# 같은 표기를 못 잡는다. 이 줄은 href 가 1개뿐이라 link_count>1 분기를 안 타고 그대로 삭제됐다(오삭제).
# 실제 문제는 개수가 아니라 "이 href 의 markdown 링크 뒤에 자기 요약(`—`)이 붙어 있는가" — 그룹라벨줄은
# 링크 뒤에 개별 요약 없이 `…`만 남아 있다. 상태배지 라인(`` `[조건부]` [slug](href) — 요약 ``)은 href
# 뒤에 정상 요약이 붙어 있어 이 판별식으로는 영향받지 않는다(라벨 자체를 기준으로 삼으면 이 26건이
# 오탐으로 막혔을 것 — 그래서 "링크 앞 라벨" 이 아니라 "링크 뒤 요약 유무" 를 본다).
target_link_re = re.compile(
    r'\[[^\]]*\]\(' + re.escape(href_a_token) + r'\)'
    r'|\[[^\]]*\]\(backlog/\d{4}-\d{2}-\d{2}-' + re.escape(slug) + r'\.md\)'
)
own_summary_re = re.compile(r'^\s*—')

# `\b`(콜드리뷰 R6 H1) — `\s*$` 는 헤더가 정확히 "## Backlog" 로 끝날 때만 매칭한다. 실 production
# 인덱스(C--Works-hongcafe-global-backend/memory/MEMORY.md:45)는
# "## Backlog (게이트·§3·P0/P1·harness만 / 상세=각 파일 / 전량=`Glob backlog_*.md`)" 처럼 제목 뒤에
# 부연이 붙어 있어 `\s*$` 로는 안 걸렸다 — has_backlog_header=False 로 떨어져 스코핑이 통째로
# no-op 이 되고 **파일 전체가 삭제 범위**가 됐다(스코핑이 실제로 필요한, Backlog 가 중간 섹션인
# 유일한 파일에서 정확히 이 mis-branch 를 탔다). `\b` 로 완화해 제목 뒤 부연을 허용한다.
backlog_header_re = re.compile(r'^##\s+Backlog\b')
section_header_re = re.compile(r'^##\s')

results = []
for index_path in index_paths:
    status = "error"
    try:
        with open(index_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        # 삭제 범위를 `## Backlog` 섹션으로 제한(콜드리뷰 R5 M4) — 이전엔 href 1개만 있으면 파일 어느
        # 섹션·어느 줄이든 통째로 지웠다. MEMORY.md 는 Backlog 외 Project/Reference/Feedback 섹션도
        # 같이 담고 있어, 그런 섹션에 우연히 backlog href 를 인용하는 교차참조가 생기면 무경고 삭제된다.
        # `## Backlog` 헤더가 있는 파일(MEMORY.md)만 그 섹션~다음 `## ` 로 범위를 좁힌다. BACKLOG.md 는
        # 그런 헤더가 없고(하위 카테고리 헤더만 있음, 전체가 backlog 상세라 처음부터 제한 불필요) —
        # has_backlog_header 가 False 면 파일 전체를 그대로 대상으로 삼아 기존 동작을 유지한다.
        has_backlog_header = any(backlog_header_re.match(l) for l in lines)
        in_backlog_section = not has_backlog_header
        out = []
        changed = False
        manual = False
        noref = False
        for l in lines:
            if has_backlog_header and section_header_re.match(l):
                in_backlog_section = bool(backlog_header_re.match(l))
                out.append(l)
                continue
            if has_backlog_header and not in_backlog_section:
                out.append(l)
                continue
            has_href = (href_a_token in l) or bool(href_b_re.search(l))
            has_marker = marker in l
            if not has_href and not has_marker:
                out.append(l)
                continue
            if not has_href:
                noref = True
                out.append(l)
                continue
            # set() 필수(콜드리뷰 R5 M3) — findall() 는 등장 횟수를 센다. 한 entry 가 자기 href 를
            # 실수로 두 번 적으면(같은 slug 반복) 서로 다른 entry 가 아닌데도 2 로 잡혀 manual 오판된다.
            # "서로 다른 backlog entry 개수" 라는 판별 의도를 정확히 구현하려면 distinct 카운트다.
            link_count = len(set(any_link_re.findall(l)))
            if link_count > 1:
                manual = True
                out.append(l)
                continue
            # 그룹라벨 대표줄 보류 — href 는 1개(위 link_count 판정 통과)지만 그 href 의 markdown
            # 링크 뒤에 자기 요약(`—`)이 없으면 이 slug 만의 entry 가 아니라 그룹 대표 예시일 가능성이
            # 높다. 오탐(과소삭제)이 오삭제(그룹라벨 소실)보다 싸다는 기존 방침과 동일하게 manual 로 민다.
            tm = target_link_re.search(l)
            if not tm or not own_summary_re.match(l[tm.end():]):
                manual = True
                out.append(l)
                continue
            changed = True
        if changed:
            with open(index_path, 'w', encoding='utf-8') as f:
                f.writelines(out)
        if manual and changed:
            status = "removed_partial"
        elif manual:
            status = "manual"
        elif changed:
            status = "removed"
        elif noref:
            status = "noref"
        else:
            status = "notfound"
    except Exception:
        status = "error"
    results.append(index_path + "\t" + status)

print("\n".join(results))
PYEOF
)
    # 제거 0건 침묵 실패 방지(콜드리뷰 R1 Medium-6) — 이동은 "✓" 로 성공 보고되는데 인덱스만 남으면
    # 사용자에겐 성공으로만 보인다. error 및 미인식 값(python 미기동·빈 문자열 포함) 은 `*)` catch-all
    # 이 받는다(콜드리뷰 R3 Medium-3). notfound 는 다수 project 중 하나만 매칭되는 게 정상이라
    # per-project 침묵 — 전체 스캔 후 any_found 로만 집계한다.
    # **`✓ 이동` vs `△ 이동`(콜드리뷰 R4 M7)** — mv 는 이미 성공했는데 인덱스 정리가 실패/보류되면
    # index_incomplete 를 세워 맨 아래 최종 보고 줄의 마커를 갈라 훑어보기만 해도 구분되게 한다.
    local out_index_file idx_result
    while IFS=$'\t' read -r out_index_file idx_result; do
      [ -n "$out_index_file" ] || continue
      # 실측 발견(2026-08-06, 다중 index 파일 통합 python 호출 검증 중, 콜드리뷰 R6 L2 설명 정정) —
      # Windows 네이티브 python3 의 print() 는 매 줄에 \r\n 을 쓴다(text-mode 개행 변환) — 이 \r\n 은
      # 각 줄 경계에 실제로 남아 있는 원본 바이트다. 여러 줄 출력을 `$(...)` 로 캡처할 때 bash 가 벗기는
      # 건 **텍스트 전체의 맨 끝에 있는 딱 한 번의 트레일링 \r\n 뿐**이고, 그 앞의 각 줄 경계에 있는
      # \r\n 은 캡처 전 과정에서 손대지 않는다(실측: `printf 'a\r\nb\r\nc\r\n' | od -c` 를 `$(...)` 로
      # 캡처하면 `a\r\nb\r\nc` 로 마지막 \r\n 만 사라짐, 재현 확인). 그 결과 idx_out 의 마지막 줄이
      # 아닌 idx_result 값마다 보이지 않는 trailing \r 이 남아 `case` 리터럴 매칭이 전부 `*)`
      # catch-all(에러)로 떨어졌다 — index 파일이 2개 이상이면 항상 재현된다(단일 파일 테스트로는
      # 절대 안 잡힌다, M6 통합 이전엔 파일당 단일 호출이라 은폐돼 있었다).
      idx_result="${idx_result%$'\r'}"
      case "$idx_result" in
        removed) any_found=1 ;;
        removed_partial) any_found=1; index_incomplete=1; echo "[backlog-lifecycle] $out_index_file — slug '$slug' 일부 라인 제거됨, 나머지는 다른 backlog entry 와 같은 라인이라 보류 — 수동 분리 필요" >&2 ;;
        manual) any_found=1; index_incomplete=1; echo "[backlog-lifecycle] $out_index_file — slug '$slug' 라인에 다른 backlog entry 공존, 자동 삭제 안 함 — 수동 분리 필요" >&2 ;;
        noref) any_found=1; index_incomplete=1; echo "[backlog-lifecycle] $out_index_file — slug '$slug' 라인은 있으나 backlog 참조(backlog_ 또는 backlog/)가 없어 미삭제 — href 를 신 경로로 정정 필요" >&2 ;;
        notfound) ;;
        *) index_incomplete=1; echo "[backlog-lifecycle] $out_index_file — slug '$slug' 인덱스 처리 실패(읽기/인코딩 오류 가능) — 수동 확인 필요" >&2 ;;
      esac
    done <<< "$idx_out"
  fi
  [ "$index_locked" -eq 1 ] && backlog_index_lock_release
  if [ "$any_found" -eq 0 ]; then
    index_incomplete=1
    echo "[backlog-lifecycle] slug '$slug' — 전 project index(MEMORY.md/BACKLOG.md 전수)에서 entry 미발견, 수동 정리 필요" >&2
  fi

  # 구/신 동시 존재 고아 감지 — 전 project 순회(콜드리뷰 R4 M2) — 이전엔 harness home 프로젝트
  # 디렉토리 하나만 봐서 비-harness 고아를 전부 놓쳤다. all_memory_dirs() 로 전 project 순회.
  # 이관 중 복사만 하고 원본을 안 지우면, 신 파일이 이동되며 인덱스 entry 는 지워지는데 구 본문만
  # 인덱스 없는 고아로 남는다. 삭제는 하지 않는다(§3) — 지목만.
  local orphan_dir
  while IFS= read -r orphan_dir; do
    if [ -f "$orphan_dir/backlog_${slug}.md" ]; then
      echo "[backlog-lifecycle] $filename — 구 경로에 동일 slug 잔존: $orphan_dir/backlog_${slug}.md (인덱스 entry 는 제거됨, 수동 확인 필요)" >&2
    fi
  done < <(all_memory_dirs)

  # history.md 갱신 (product 기준) — reverse chronological insert (최신 위)
  # 버그 정정 (2026-05-14): 기존 코드는 today 헤더 매칭만 검사 후 entry 를 파일 끝 append →
  # 다른 날짜 섹션 안에 entry 가 들어가는 버그 (working-lifecycle.sh 와 동일 패턴).
  local history="$DOCS_ROOT/$product/tasks/history.md"
  if [ ! -f "$history" ]; then
    printf "# %s tasks 이력\n\n" "$product" > "$history"
  fi

  local entry_line
  entry_line=$(printf -- "- [backlog/%s](%s/backlog/%s) — working backlog 완료 → tasks/ 자동 이동" \
    "$slug" "$yyyymmdd" "$filename")

  python3 - "$history" "$today_dot" "$entry_line" "$filename" <<'PYEOF'
import sys
history_path, today_dot, entry_line, filename = sys.argv[1:5]
with open(history_path, 'r', encoding='utf-8') as f:
    content = f.read()

marker = f"backlog/{filename}"
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
  if ! grep -qF "backlog/${filename}" "$summary" 2>/dev/null; then
    printf -- "- [backlog/%s](backlog/%s) — working backlog 완료 → tasks/ 자동 이동\n" \
      "$slug" "$filename" >> "$summary"
  fi

  if [ "$index_incomplete" -eq 0 ]; then
    echo "[backlog-lifecycle] ✓ 이동: $filename → ${product}/tasks/$yyyymmdd/backlog/${filename}" >&2
  else
    echo "[backlog-lifecycle] △ 이동(인덱스 미정리, 위 경고 참조): $filename → ${product}/tasks/$yyyymmdd/backlog/${filename}" >&2
  fi
  return 0
}

# 인덱스 동기화 검증 — 죽은 링크(인덱스엔 있는데 본문 파일이 없는 slug) 만 본다.
#   **콜드리뷰 R5 High(방향 재정정) — "본문 있는데 인덱스 미등재" 축을 완전히 제거했다.** 직전
#   라운드(R4)가 "제거·검증 두 함수가 같은 합집합을 공유해야 한다"고 지시해 이 축을 전 project 로
#   확대했는데, 전 project index·구 경로 본문 실측 대조 결과 `MEMORY.md 미등재` + `BACKLOG.md 미등재`
#   가 수백 건 단위(정확한 값은 여기 적지 않는다 — 실측할 때마다 바뀌어 stale 됐다, 콜드리뷰 R6 L2)로
#   pending 저장 1회마다 나왔다(확대 전 harness 단독은 거의 0건이었다) — 두 가지 구조적 이유가
#   있었다: ① BACKLOG.md 는 11 project 중 harness home 1곳에만 존재해 `files - blog` 가 항상 대량,
#   ② **MEMORY.md 는 큐레이션 인덱스다** — 자기 헤더가 "✅완전종결·비차단 backlog는 인덱스 제거(파일
#   보존) — 게이트·§3·P0/P1·harness만 등재" 라고 명시한다. 본문이 있는데 인덱스에 없는 것은 **정상
#   상태**이지 drift 가 아니다 — "미등재 = drift" 전제 자체가 틀렸으므로 범위를 좁히는 게 아니라
#   축 자체를 없앤다(그래야 다음 라운드에 또 안 뒤집힌다).
#   **남기는 축 = "인덱스에 있는데 본문 파일이 없음"(죽은 링크)** — 이건 이 hook 자신이 만들 수 있는
#   사고(mv 는 됐는데 인덱스 entry 가 안 지워짐)와 정확히 같은 형태라 실제 drift 다. all_index_files()
#   합집합을 그대로 쓰되, 코드블록 안 `` `backlog_*.md` `` 같은 glob 예시 문자열이 slug="*" 로 오추출
#   되는 허수를 걸러낸다(실 slug 화이트리스트 [A-Za-z0-9_-]+ 만 허용, product 검증과 동일 문자셋).
#   비차단: 경고만 내고 exit 0 (PostToolUse).
verify_index_sync() {
  local index_files_arr=()
  local index_file
  while IFS= read -r index_file; do
    [ -n "$index_file" ] && index_files_arr+=("$(to_win_path "$index_file")")
  done < <(all_index_files)
  # 본문 스캔 디렉토리는 all_memory_dirs() 를 별도 argv 그룹으로 직접 받는다(콜드리뷰 R6 M1) — 이전엔
  # index 파일 경로에서 os.path.dirname() 으로 역산했는데, 파일 헤더가 스스로 선언한 "세 함수(
  # warn_old_location·고아감지·verify_index_sync) 가 all_memory_dirs() 를 공유해야 전 project 훑기가
  # 전부에 적용된다" 원칙을 이 함수만 어기고 있었다. 실측: C--Works-hongcafe-global-athena/memory 는
  # 본문 2건을 갖고 있지만 MEMORY.md/BACKLOG.md 가 없어 index_paths 에서 dirname 역산이 안 되므로
  # `files` 집합에서 통째로 빠진다 — 지금은 그 slug 를 참조하는 인덱스가 없어 오탐 0이지만, athena 에
  # 나중에 MEMORY.md 가 생기면 그 순간부터 죽은 링크 오탐이 된다. 두 목록(index 파일 · memory 디렉토리)
  # 은 정의상 다른 집합(전자 ⊆ 후자)이라 하나에서 다른 하나를 역산하면 안 되고 각각 독립 조회해야 한다.
  local memory_dirs_arr=()
  local mdir
  while IFS= read -r mdir; do
    [ -n "$mdir" ] && memory_dirs_arr+=("$(to_win_path "$mdir")")
  done < <(all_memory_dirs)
  { [ "${#index_files_arr[@]}" -gt 0 ] || [ "${#memory_dirs_arr[@]}" -gt 0 ]; } || return 0
  local win_new
  win_new=$(to_win_path "$BACKLOG_SRC_DIR")
  python3 - "$win_new" "${#index_files_arr[@]}" "${index_files_arr[@]}" "${memory_dirs_arr[@]}" <<'PYEOF'
import os, re, sys
new_dir = sys.argv[1]
n_index = int(sys.argv[2])
rest = sys.argv[3:]
index_paths = rest[:n_index]
mem_dirs = rest[n_index:]
try:
    files = set()
    if os.path.isdir(new_dir):
        for f in os.listdir(new_dir):
            m = re.match(r'^\d{4}-\d{2}-\d{2}-(.+)\.md$', f)
            if m:
                files.add(m.group(1))
    for d in mem_dirs:
        try:
            for f in os.listdir(d):
                if f.startswith('backlog_') and f.endswith('.md'):
                    files.add(f[8:-3])
        except Exception:
            pass

    def refs():
        s = set()
        for p in index_paths:
            try:
                with open(p, encoding='utf-8') as fh:
                    text = fh.read()
            except Exception:
                continue
            s |= set(re.findall(r'backlog_([^\s\]\)]+)\.md', text))
            for _date, tail in re.findall(r'backlog/(\d{4}-\d{2}-\d{2})-([^\s\]\)]+)\.md', text):
                s.add(tail)
        return s

    valid_slug = re.compile(r'^[A-Za-z0-9_-]+$')
    orphan = {s for s in (refs() - files) if valid_slug.match(s)}
    if orphan:
        shown = sorted(orphan)[:20]
        more = f" 외 {len(orphan)-20}건" if len(orphan) > 20 else ""
        print(f"[backlog-lifecycle] 인덱스에만 있고 파일 없음(죽은 링크, 전 project 합산) {len(orphan)}건: {', '.join(shown)}{more}", file=sys.stderr)
except Exception:
    pass
PYEOF
}

# ============= PostToolUse 진입 =============
if [ "$HOOK_EVENT" = "PostToolUse" ]; then
  # file_path 추출 — bash 내장 (python 起動 제거). tool_response.filePath 우선.
  FILE_PATH=""
  [[ "$STDIN_DATA" =~ \"filePath\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && FILE_PATH="${BASH_REMATCH[1]}"
  [ -z "$FILE_PATH" ] && [[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && FILE_PATH="${BASH_REMATCH[1]}"

  [ -z "$FILE_PATH" ] && exit 0

  # Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT — 더블슬래시 붕괴 포함, 2026-07-09)
  FILE_PATH_NORM=$(normalize_path "$FILE_PATH")

  # $BACKLOG_SRC_DIR(홈 경로) 실제 prefix 로 앵커 — 상대경로 문자열 매칭(`/docs/working/backlog/`)은
  # 임의 레포에 동일 상대경로가 있으면 그 레포 파일을 홈으로 반출(mv)하는 사고를 낸다(콜드리뷰 R1 Medium-5).
  # 날짜 형식은 여기서 요구하지 않는다 — 요구하면 날짜 prefix 없는(구 경로 잔존분 이관 시나리오 포함) 파일명이
  # PostToolUse 경로에서 완전 침묵 스킵된다(콜드리뷰 R1 Medium-4). 날짜 검증 + 스킵 stderr 는
  # move_backlog_to_tasks() 의 case 문이 이미 담당한다.
  #
  # 앵커는 파라미터 확장 prefix-strip 으로 판정한다(콜드리뷰 R2 Medium-3) — bash case 글롭의 `*` 는
  # `/` 를 넘어 매칭돼 `"$dir"/*.md` 가 앵커가 아니었다(traversal·하위폴더 파일이 모두 통과).
  # prefix 제거 후 남은 rest 에 `/`(하위폴더) 나 `..`(traversal) 가 있으면 거부 — $BACKLOG_SRC_DIR
  # 바로 아래 평면 파일만 허용한다.
  # 비교 전 FILE_PATH_NORM 도 to_win_path 를 태운다(콜드리뷰 R2 Medium-4) — 안 그러면 페이로드가
  # POSIX(/c/Users/...) 나 소문자 드라이브(c:/Users/...)로 오는 경우 앵커 문자열 형식이 안 맞아
  # 완전 침묵 스킵된다(구 정규식은 두 형태 모두 매칭했으므로 회귀).
  win_backlog_src=$(to_win_path "$BACKLOG_SRC_DIR")
  file_path_win=$(to_win_path "$FILE_PATH_NORM")
  # 비교만 소문자로 정규화한다(콜드리뷰 R6 M5) — to_win_path() 는 드라이브 문자(c:/→C:/)만 통일하고
  # 나머지 세그먼트는 원본 그대로다. Windows 경로는 전체가 대소문자 무관이라 `C:/users/pv/.claude/…`
  # 같은(드라이브 문자는 맞는데 그 뒤 세그먼트가 다른 대소문자인) 유효 페이로드가 문자열 완전일치
  # 비교 때문에 앵커 불일치로 전체 스킵됐다. 비교는 소문자 사본으로, 실제 파일 조회·이동에 쓰는
  # rest/file_path_win 은 원본 대소문자를 그대로 보존한다(파일시스템 표기 훼손 방지).
  win_backlog_src_lc="${win_backlog_src,,}"
  file_path_win_lc="${file_path_win,,}"
  if [[ "$file_path_win_lc" == "$win_backlog_src_lc/"* ]]; then
    rest="${file_path_win:$((${#win_backlog_src} + 1))}"
  else
    rest="$file_path_win"
  fi
  if [ "$rest" = "$file_path_win" ]; then
    # 구 경로(memory/backlog_*.md) 는 완전 침묵이었다(콜드리뷰 R3 High-1) — 앵커 불일치로 그냥 exit 0
    # 되어 warn_old_location() 도 호출 전에 빠져나갔다. 잔존분이 전부 이 경로에 있는 지금 성공기준
    # 5(구 경로 안내)가 문자 그대로 미충족이었다. 여기서 명시적으로 안내한다.
    case "$FILE_PATH_NORM" in
      */memory/backlog_*.md) echo "[backlog-lifecycle] $(basename "$FILE_PATH_NORM") — 구 경로(memory/backlog_*.md) 미지원. docs/working/backlog/{yyyy-mm-dd}-{slug}.md 로 이동 필요" >&2 ;;
      # 메시지에 실제 비교 기준인 $win_backlog_src(Windows 표기, 콜드리뷰 R4 L1) 를 보여준다 — 이전엔
      # $BACKLOG_SRC_DIR(POSIX 표기) 를 보여줘서, 대소문자/구분자 불일치(예: 소문자 드라이브 c:/)
      # 로 인한 실패인데 마치 경로 자체가 틀린 것처럼 오독됐다.
      */working/backlog/*) echo "[backlog-lifecycle] $FILE_PATH_NORM — backlog 경로처럼 보이나 홈 앵커($win_backlog_src) 불일치로 스킵 (경로 표기 확인 필요)" >&2 ;;
    esac
    exit 0
  fi
  # `*..*` 제거(콜드리뷰 R3 Medium-5) — traversal 은 반드시 `/` 를 포함해 앞의 `*/*` 가 이미 잡는다.
  # `*..*` 가 추가로 하는 일은 `2026-08-06-a..b.md` 같은 평면 정상 파일명을 stderr 0줄로 침묵 차단하는
  # 것뿐이었다(실측). `*/*` arm 에는 스킵 사유 stderr 를 낸다 — move_backlog_to_tasks() 의 파일명
  # case 가드(패턴 불일치 시 스킵 사유 stderr)와 일관되게.
  case "$rest" in
    */*) echo "[backlog-lifecycle] $(basename "$FILE_PATH_NORM") — $BACKLOG_SRC_DIR 하위 폴더/상위경로는 지원 안 함(평면 파일만), 스킵" >&2; exit 0 ;;
    *.md) ;;
    *) exit 0 ;;
  esac

  unix_path=$(echo "$FILE_PATH_NORM" | sed 's|^C:|/c|')
  [ -f "$unix_path" ] || unix_path="$FILE_PATH_NORM"
  [ -f "$unix_path" ] || exit 0

  if has_done_marker "$unix_path"; then
    # 콜드리뷰 L3: 이전엔 done 판정 이전에 무조건 호출돼 신 경로에 pending 저장(편집 1회당 상시 발생)
    # 마다도 "구 경로 잔존 N건" 고정 노이즈가 떴다. 실제 이동이 일어나는 done 분기 안으로만 좁힌다.
    warn_old_location
    move_backlog_to_tasks "$unix_path"
  else
    verify_index_sync
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
    warn_old_location

    moved_count=0
    [ -d "$BACKLOG_SRC_DIR" ] || exit 0

    for f in "$BACKLOG_SRC_DIR"/*.md; do
      [ -f "$f" ] || continue
      if has_done_marker "$f"; then
        if move_backlog_to_tasks "$f"; then
          moved_count=$((moved_count + 1))
        fi
      fi
    done

    if [ "$moved_count" -gt 0 ]; then
      echo "[backlog-lifecycle] 명시 키워드 트리거 — ${moved_count}건 working/backlog → tasks/ 이동 완료" >&2
    fi
  fi

  exit 0
fi

exit 0
