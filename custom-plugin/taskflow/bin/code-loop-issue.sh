#!/usr/bin/env bash
# code-loop 시작·종료 때 이슈 문서 상태를 전이하고 시트에 동기화한다.
#
#   code-loop-issue.sh start {결과문서 dir} {요청}   요청의 첫 ISS-N 문서를 착수 상태로
#   code-loop-issue.sh end   {결과문서 dir} {결과}   결과를 로그로 남기고 시트 동기화
#
# 이슈 상태 원본은 레포 문서다(폴더 + frontmatter 상태, 시트 ISS 탭은 거울 — athena
# docs/wbs/issue/README.md §1). 둘을 같이 바꾸지 않으면 시트 동기화가 [ERR] 로 멈추므로
# 폴더 이동과 frontmatter 를 한 번에 바꾼다.
#
# 전이는 pending → progress 하나뿐이다. 종료는 결과와 상관없이 progress 를 유지한다 — R 으로
# 나뉜 이슈는 run 1개 끝이 종결이 아니고, resolved 는 정착·검증하는 쪽(허브)이 옮긴다.
# 이력 표는 쓰지 않는다 — 허브가 커밋한다. 러너가 메인 트리에 미커밋 행을 남기면 정착 ff 를
# 막으므로, 이미 progress 인 재run 은 문서를 전혀 건드리지 않는다 (2026-10-12 사용자 결정).
#
# 이슈와 무관한 요청이거나 문서·기준 레포를 못 찾으면 아무것도 하지 않고 0 으로 끝난다.
# 동기화 실패도 run 을 막지 않는다 — 다음 동기화가 문서 기준으로 다시 덮는다.
#
# 환경변수: CODE_LOOP_ISSUE_SYNC_CMD — 동기화 명령(뒤에 레포 루트가 붙는다). 테스트가 stub 으로 바꾼다.
set -uo pipefail

SYNC_CMD="${CODE_LOOP_ISSUE_SYNC_CMD:-bash $HOME/.claude/custom-plugin/tools/scripts/wbs-sheet-sync.sh}"
ISS_SUB="docs/wbs/issue"

log() { echo "--- [issue] $*"; }

# frontmatter(첫 --- 블록) 안에서만 바꾼다 — 본문 표의 '상태:' 문구를 건드리지 않게
mark_progress() {
  local f="$1" today="$2" tmp="$1.tmp.$$"
  TODAY="$today" awk '
    /^---$/ { fm++ }
    fm == 1 && /^상태:/ { sub(/pending/, "progress") }
    fm == 1 && /^착수일:[[:space:]]*없음[[:space:]]*$/ { $0 = "착수일: " ENVIRON["TODAY"] }
    { print }' "$f" > "$tmp" && mv -f "$tmp" "$f"
}

sync_sheet() {
  local root="$1"
  if eval "$SYNC_CMD \"\$root\"" > /dev/null 2>&1; then
    log "시트 동기화 완료"
  else
    log "시트 동기화 실패 — run 은 계속한다. 다음 동기화가 문서 기준으로 덮는다"
  fi
}

cmd_start() {
  local dir="$1" request="$2" root id f folder today
  root=$(cat "$dir/BASE_ROOT" 2>/dev/null)
  [ -n "$root" ] && [ -d "$root/$ISS_SUB" ] || return 0
  id=$(printf '%s' "$request" | grep -oE 'ISS-[0-9]+' | head -1)
  [ -n "$id" ] || return 0
  f=$(ls "$root/$ISS_SUB"/{pending,progress,resolved}/*-"$id"-*.md 2>/dev/null | head -1)
  if [ -z "$f" ]; then log "$id 문서 없음 — 전이 안 함"; return 0; fi
  folder=$(basename "$(dirname "$f")")
  today=$(date '+%Y-%m-%d')
  case "$folder" in
    resolved)
      log "$id 는 resolved — 전이 안 함 (재run 이면 허브가 상태를 판단한다)"
      return 0 ;;
    pending)
      local dst="$root/$ISS_SUB/progress/$(basename "$f")"
      git -C "$root" mv "$f" "$dst" 2>/dev/null || mv "$f" "$dst" || { log "$id 이동 실패 — 전이 안 함"; return 0; }
      f="$dst"
      mark_progress "$f" "$today"
      printf '%s\n' "$f" > "$dir/ISSUE"
      log "$id pending → progress"
      sync_sheet "$root" ;;
    progress)
      printf '%s\n' "$f" > "$dir/ISSUE"
      log "$id 이미 progress — 문서 무변경" ;;
  esac
}

cmd_end() {
  local dir="$1" outcome="$2" f root
  f=$(cat "$dir/ISSUE" 2>/dev/null)
  [ -n "$f" ] || return 0
  root=$(cat "$dir/BASE_ROOT" 2>/dev/null)
  log "$(basename "$f") 종료 — $outcome"
  [ -n "$root" ] && sync_sheet "$root"
  return 0
}

case "${1:-}" in
  start) cmd_start "${2:?dir}" "${3:-}" ;;
  end)   cmd_end "${2:?dir}" "${3:-종료}" ;;
  *)     sed -n '2,5p' "$0" | sed 's/^# \?//'; exit 1 ;;
esac
