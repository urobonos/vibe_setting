#!/bin/bash
# 공유 lib 는 하니스 hooks/lib 에 있다. 스크립트 위치 기준으로 찾아 $HOME 을 바꾼 테스트에서도
# 같은 파일을 쓰고, 플러그인이 캐시 사본으로 로드돼 상대경로가 없으면 $HOME 으로 되돌아간다
HARNESS_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/lib" 2>/dev/null && pwd)"
[ -f "$HARNESS_LIB/hook-input.sh" ] || HARNESS_LIB="$HOME/.claude/hooks/lib"
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$HARNESS_LIB/log-helper.sh" 2>/dev/null && log_event "memory-inject" "enter" "pid=$$"
# ─────────────────────────────────────────────────────────
# SessionStart Hook: dream 이 선별한 top-N 사실을 세션 컨텍스트에 강제 주입
# ─────────────────────────────────────────────────────────
# Why: 네이티브 autoMemoryEnabled 가 자동 주입하는 것은 MEMORY.md 한 개뿐이고,
#   개별 memory/*.md 는 recall 이 MEMORY.md 의 hook 한 줄만 보고 열지 말지 정한다.
#   MEMORY.md 가 200줄에서 잘리면(2026-09-07 실측: 210줄·10줄 조용한 절단) 잘린 줄에
#   걸린 파일은 단서를 잃는다. INJECT.md 는 그 운에 맡기지 않는 확정 주입 경로다.
#
# 입력: ~/.claude/projects/{slug}/memory/INJECT.md  (생성 = /taskflow:dream Phase 4)
# 규약: 파일 부재·슬러그 해석 실패 = 조용히 통과 (fail-open — 세션 시작을 막지 않는다)
# 상한: MAX_LINES / MAX_CHARS. 초과분은 잘라내고 잘렸음을 명시한다.
# SSOT: custom-plugin/taskflow/commands/dream.md §④ PRUNE & INDEX
# ─────────────────────────────────────────────────────────

MAX_LINES=40
MAX_CHARS=4000
STALE_DAYS=45

source "$HARNESS_LIB/hook-input.sh" 2>/dev/null || exit 0
hook_read_stdin

CWD=$(hook_parse_field "cwd")
[ -z "$CWD" ] && exit 0

# projects/ 슬러그 = cwd 의 비영숫자를 '-' 로 치환 (C:\Users\PV\.claude → C--Users-PV--claude)
SLUG=$(printf '%s' "$CWD" | sed 's#[^A-Za-z0-9]#-#g')
INJECT="$HOME/.claude/projects/$SLUG/memory/INJECT.md"
[ -f "$INJECT" ] || exit 0
[ -s "$INJECT" ] || exit 0

BODY=$(head -n "$MAX_LINES" "$INJECT" | cut -c1-400)
TRUNC=""
[ "$(wc -l < "$INJECT")" -gt "$MAX_LINES" ] && TRUNC=" (상위 ${MAX_LINES}줄만 — 초과분은 MEMORY.md 참조)"
if [ "${#BODY}" -gt "$MAX_CHARS" ]; then
  BODY="${BODY:0:$MAX_CHARS}"
  TRUNC=" (${MAX_CHARS}자에서 절단)"
fi

echo "[메모리 주입 — ${SLUG}]${TRUNC}"
printf '%s\n' "$BODY"

# 오래된 INJECT = dream 미실행 신호. 차단하지 않고 1줄만 남긴다.
if [ -n "$(find "$INJECT" -mtime "+${STALE_DAYS}" 2>/dev/null)" ]; then
  echo "  ⚠️ INJECT.md 가 ${STALE_DAYS}일 이상 갱신되지 않았습니다 → /taskflow:dream 재실행 권장"
fi

exit 0
