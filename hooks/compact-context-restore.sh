#!/bin/bash
# compact-context-restore.sh
# SessionStart (matcher: compact) — 컨텍스트 압축 직후 **관측 사실**을 모델에 재주입한다.
#
# Why:
#   compact 요약은 Claude 의 서술이라 누락·왜곡될 수 있다 (CLAUDE.md §1 "요약은 근거가 아니다").
#   반면 브랜치·미커밋·worktree·활성 태스크는 **관측**이므로 hook 이 다시 읽어 붙이면 서술과 무관하게 살아남는다.
#   요약이 worktree 경로를 빠뜨리면 압축 후 develop 직접 편집(§4.3 worktree 강제 위반) ·
#   미커밋 변이 유실(메모리 local-athena-mutation-revert-destroys-uncommitted)로 이어진다 — 실발생 축이다.
#
# 스키마 근거 (2026-09-16 `bin/claude.exe` 실측):
#   SessionStart source enum = ["startup","resume","clear","compact","fork"]  + additionalContext 주입 지원
#   PostCompact 는 compact_summary 를 stdin 으로 받지만 hookSpecificOutput 스키마가 없어 **되먹임 불가**
#   PreCompact 는 exit 2 로 압축을 막을 뿐 지시를 바꾸지 못한다
#   → 압축 직후 주입 경로는 SessionStart 가 유일하다.
#
# SSOT: CLAUDE.md §1 "Context Compaction 요약 양식" (본 hook = 그 룰의 기계적 짝)

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "compact-context-restore" "enter" "pid=$$"

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_session_id

# source 방어 — matcher 가 이미 거르지만 오등록 시 startup 오염을 막는다
SOURCE=$(printf '%s' "$STDIN_DATA" | grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ "$SOURCE" != "compact" ] && exit 0

LINES=""
add() { LINES="${LINES}$1"$'\n'; }

# ── 1. git 관측 (cwd 기준) ────────────────────────────────────────────────
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  TOP=$(git rev-parse --show-toplevel 2>/dev/null)
  add "- 작업 트리: ${TOP} (브랜치 ${BRANCH})"

  DIRTY=$(git status --porcelain 2>/dev/null | grep -v '^??' | head -25)
  DIRTY_N=$(git status --porcelain 2>/dev/null | grep -cv '^??')
  if [ "${DIRTY_N:-0}" -gt 0 ]; then
    add "- **미커밋 변경 ${DIRTY_N}건** (압축 요약이 빠뜨렸어도 실재한다 — 커밋 전 소실 주의):"
    while IFS= read -r l; do [ -n "$l" ] && add "    ${l}"; done <<< "$DIRTY"
    [ "$DIRTY_N" -gt 25 ] && add "    ... 외 $((DIRTY_N - 25))건"
  else
    add "- 미커밋 변경: 없음 (tracked 기준)"
  fi

  # worktree 전체 목록은 남의 세션 것까지 끌고 와 노이즈가 된다 — **내가 지금 어디 있는가**만 판정한다
  MAIN=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
  WT_N=$(git worktree list 2>/dev/null | wc -l)
  if [ "$TOP" = "$MAIN" ]; then
    add "- 위치: **메인 트리** (worktree 아님) — 소스 mutation 은 §4.3 상 worktree 안에서만 한다"
  else
    add "- 위치: worktree (메인 = ${MAIN})"
  fi
  add "- 이 레포의 worktree 총 ${WT_N}개 (타 세션 포함 — 남의 것을 건드리지 않는다)"

  add "- 최근 커밋: $(git log --oneline -1 2>/dev/null)"
fi

# ── 2. PreCompact 스냅샷 (compact-snapshot.sh 가 압축 직전에 박제한 원문) ──
SNAP_DIR="$HOME/.claude/docs/snapshot/${SESSION_ID:0:8}"   # sid 8자리 = REGISTRY·dispatch 관습과 동일 (교차 조회)
if [ -n "$SESSION_ID" ] && [ -d "$SNAP_DIR" ]; then
  LATEST=$(ls -1t "$SNAP_DIR"/*.md 2>/dev/null | head -1)
  SNAP_N=$(ls -1 "$SNAP_DIR"/*.md 2>/dev/null | wc -l)
  if [ -n "$LATEST" ]; then
    # MSYS 경로(/c/Users/...)는 Read 도구가 열지 못하고 §4.4 OS 정합에도 어긋난다 — Windows 절대경로로 준다
    LATEST_WIN=$(cygpath -w "$LATEST" 2>/dev/null || echo "$LATEST")
    add "- **압축 직전 스냅샷: \`${LATEST_WIN}\`** (이 세션 누적 ${SNAP_N}회)"
    add "    수정 파일 전수 · 실행 명령어 · **사용자 발화 원문**이 들어 있다."
    add "    요약에서 빠진 맥락이 필요하면 **추측하지 말고 이 파일을 읽는다.**"
  fi
fi

# ── 3. 이 세션이 REGISTRY 에 claim 한 태스크 ──────────────────────────────
REG="$HOME/.claude/docs/working/REGISTRY.md"
if [ -n "$SESSION_ID" ] && [ -f "$REG" ]; then
  MINE=$(grep -F "$SESSION_ID" "$REG" 2>/dev/null | head -5)
  if [ -n "$MINE" ]; then
    add "- 이 세션이 claim 한 작업 (REGISTRY):"
    while IFS= read -r l; do [ -n "$l" ] && add "    ${l}"; done <<< "$MINE"
  fi
fi

[ -z "$LINES" ] && exit 0

HEADER="[compact 직후 관측 사실 — 요약의 서술이 아니라 hook 이 지금 읽은 값이다]"
FOOTER="위 값이 압축 요약과 어긋나면 **이 쪽이 사실이다.** 요약을 근거로 재판정하지 말고 원 출처를 다시 읽는다 (CLAUDE.md §1)."

BODY="${HEADER}"$'\n'"${LINES}"$'\n'"${FOOTER}"

# JSON 인코딩 — python 우선, 실패 시 bash 치환 fallback
if [ -n "$HOOK_PY" ] || resolve_python 2>/dev/null; then
  printf '%s' "$BODY" | "$HOOK_PY" -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))'
else
  esc="${BODY//\\/\\\\}"; esc="${esc//\"/\\\"}"; esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
fi

exit 0
