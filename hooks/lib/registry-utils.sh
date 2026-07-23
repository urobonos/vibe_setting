#!/usr/bin/env bash
# registry-utils.sh — Active Task Registry CRUD lib
# SSOT: ~/.claude/docs/claude-harness/tasks/20260515/active-task-registry/2026-05-15-active-task-registry-unified.md
#
# 사용:
#   source "$(dirname "$0")/lib/registry-utils.sh"
#   registry_init_if_missing
#   registry_add "slug" "product" "session_id" "cwd" "working_file"
#   registry_update "slug" "session_id" [status]
#   registry_remove "slug" "session_id"
#   registry_find "slug"                # 다른 sid 점유 감지용
#   registry_list_active                  # status=active 전체
#   registry_mark_stale "slug" "session_id"
#
# Lock: mkdir lock (POSIX atomic, Git Bash on Windows 동작 검증 완료 — flock 부재 대안)

REGISTRY_PATH="${REGISTRY_PATH:-$HOME/.claude/docs/working/REGISTRY.md}"
REGISTRY_LOCK="${REGISTRY_LOCK:-/tmp/claude-registry.lock.d}"
REGISTRY_LOCK_RETRIES="${REGISTRY_LOCK_RETRIES:-50}"
REGISTRY_LOCK_SLEEP="${REGISTRY_LOCK_SLEEP:-0.1}"
# stale lock 회수 임계 (분): 정상 lock 은 ms~초 단위 보유 → TTL 초과 = 소유 프로세스 즉사 후 미해제 orphan.
REGISTRY_LOCK_TTL_MIN="${REGISTRY_LOCK_TTL_MIN:-2}"

registry_lock_acquire() {
  local i=0
  while ! mkdir "$REGISTRY_LOCK" 2>/dev/null; do
    # stale steal (M/§3 2026-06-16, backlog registry-lock-stale-leak): acquire 후 rmdir 전 프로세스 즉사 시
    #   lock 영구 잔존 → 모든 CRUD 가 retry 소진 후 silent 실패(REGISTRY 동결)하던 문제 차단. mtime 기반 회수
    #   (Git Bash kill -0 PID liveness 불확실 → dispatch-utils 의 TTL 방식과 정합). mkdir atomic 으로 회수 race 안전.
    if [ -d "$REGISTRY_LOCK" ] && find "$REGISTRY_LOCK" -maxdepth 0 -mmin "+$REGISTRY_LOCK_TTL_MIN" 2>/dev/null | grep -q .; then
      rmdir "$REGISTRY_LOCK" 2>/dev/null
      echo "[registry-utils] stale lock 회수 (>${REGISTRY_LOCK_TTL_MIN}min orphan): $REGISTRY_LOCK" >&2
      continue
    fi
    i=$((i + 1))
    if [ "$i" -ge "$REGISTRY_LOCK_RETRIES" ]; then
      echo "[registry-utils] lock timeout: $REGISTRY_LOCK" >&2
      return 1
    fi
    sleep "$REGISTRY_LOCK_SLEEP"
  done
  return 0
}

registry_lock_release() {
  rmdir "$REGISTRY_LOCK" 2>/dev/null || true
}

registry_sanitize() {
  printf '%s' "$1" | tr -cd '[:alnum:]/_:.-' | tr -s ' '
}

registry_init_if_missing() {
  if [ ! -f "$REGISTRY_PATH" ]; then
    mkdir -p "$(dirname "$REGISTRY_PATH")"
    cat >"$REGISTRY_PATH" <<'EOF'
# Active Work Registry

> SSOT: working/ 진행 중 작업의 글로벌 인덱스. hook 자동 갱신.
> 갱신 주체: working-{register,heartbeat,release,stale-cleanup}.sh + working-lifecycle.sh
> 형식: 마크다운 표 1개. 직접 편집 금지 (race 보호 — registry-utils.sh 경유).

| slug | product | session_id | started | last_update | status | cwd | working_file |
|------|---------|-----------|---------|-------------|--------|-----|-------------|
EOF
  fi
}

# 데이터 라인 식별: `|` 시작 + 첫 컬럼이 slug 헤더 / 구분자 아닌 것
# 마크다운 표 컬럼 = ` | ` 구분 (pipe + space)
# awk -F ' \\| ' 시 라인 = `| s | p | sid | ... |`
#   → $1 = "|", $2 = "s", $3 = "p", $4 = "sid", ...

# awk FS = `[[:space:]]*\|[[:space:]]*` — 마크다운 표 ` | ` 분리 + 라인 시작/끝 pipe 처리
# 결과 인덱스: $1 = "" (라인 시작 |), $2 = slug, $3 = product, $4 = sid, $5 = started,
#              $6 = last_update, $7 = status, $8 = cwd, $9 = working_file, $10 = "" (라인 끝 |)
REGISTRY_FS='[[:space:]]*\\|[[:space:]]*'

registry_find() {
  local slug
  slug="$(registry_sanitize "$1")"
  registry_init_if_missing
  awk -v slug="$slug" -F"$REGISTRY_FS" '
    /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $2 == slug { print }
  ' "$REGISTRY_PATH" 2>/dev/null
}

registry_list_active() {
  registry_init_if_missing
  awk -F"$REGISTRY_FS" '
    /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $7 == "active" { print }
  ' "$REGISTRY_PATH" 2>/dev/null
}

registry_remove() {
  local slug sid
  slug="$(registry_sanitize "$1")"
  sid="$(registry_sanitize "$2")"
  registry_init_if_missing
  registry_lock_acquire || return 1
  awk -v slug="$slug" -v sid="$sid" -F"$REGISTRY_FS" '
    /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $2 == slug && $4 == sid { next }
    { print }
  ' "$REGISTRY_PATH" >"$REGISTRY_PATH.tmp" && mv "$REGISTRY_PATH.tmp" "$REGISTRY_PATH"
  registry_lock_release
  return 0
}

registry_add() {
  local slug product sid cwd_val wfile started now
  slug="$(registry_sanitize "$1")"
  product="$(registry_sanitize "$2")"
  sid="$(registry_sanitize "$3")"
  cwd_val="$(registry_sanitize "$4")"
  wfile="$(registry_sanitize "$5")"
  now="$(date +'%Y-%m-%d %H:%M')"
  started="$now"

  [ -z "$slug" ] && { echo "[registry-utils] slug empty" >&2; return 1; }
  [ -z "$sid" ] && { echo "[registry-utils] sid empty" >&2; return 1; }

  registry_init_if_missing
  registry_lock_acquire || return 1

  # 동일 slug+sid 존재 시 = update (started 보존, last_update 갱신)
  local existing
  existing="$(awk -v slug="$slug" -v sid="$sid" -F"$REGISTRY_FS" '
    /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $2 == slug && $4 == sid { print $5; exit }
  ' "$REGISTRY_PATH" 2>/dev/null)"

  if [ -n "$existing" ]; then
    started="$existing"
  fi

  awk -v slug="$slug" -v sid="$sid" -F"$REGISTRY_FS" '
    /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $2 == slug && $4 == sid { next }
    { print }
  ' "$REGISTRY_PATH" >"$REGISTRY_PATH.tmp"
  printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' \
    "$slug" "$product" "$sid" "$started" "$now" "active" "$cwd_val" "$wfile" \
    >>"$REGISTRY_PATH.tmp"
  mv "$REGISTRY_PATH.tmp" "$REGISTRY_PATH"

  registry_lock_release
  return 0
}

# 원자 claim (2026-07-23) — lock 안에서 active 점유 확인 + add 를 한 번에 수행해
# registry_find(확인) → registry_add(점유) 분리로 인한 TOCTOU race 를 차단한다.
# 병렬 워커(tick-team)가 동시에 같은 slug 를 잡는 것을 원천 방지.
#   registry_claim <slug> <product> <sid> <cwd> <working_file>
#   stdout: CLAIMED:<slug> (신규 점유) / ALREADY:<sid> (본인 재claim) / TAKEN:<other_sid> (타 sid 점유) / ERR:<사유>
registry_claim() {
  local slug product sid cwd_val wfile now started other existing_started
  slug="$(registry_sanitize "$1")"
  product="$(registry_sanitize "$2")"
  sid="$(registry_sanitize "$3")"
  cwd_val="$(registry_sanitize "$4")"
  wfile="$(registry_sanitize "$5")"
  now="$(date +'%Y-%m-%d %H:%M')"
  [ -z "$slug" ] && { echo "ERR:slug-empty"; return 1; }
  [ -z "$sid" ]  && { echo "ERR:sid-empty"; return 1; }

  registry_init_if_missing
  registry_lock_acquire || { echo "ERR:lock-timeout"; return 1; }

  # ── lock 구간: 확인 + add 원자 ──
  other=$(awk -v slug="$slug" -F"$REGISTRY_FS" '
    /^\|/ && $2!="slug" && $2!~/^-+$/ && $2==slug && $7=="active" { print $4; exit }
  ' "$REGISTRY_PATH" 2>/dev/null)

  if [ -n "$other" ]; then
    registry_lock_release
    [ "$other" = "$sid" ] && { echo "ALREADY:$sid"; return 0; }
    echo "TAKEN:$other"; return 3
  fi

  # started 보존 (동일 slug+sid 기존 entry 있으면)
  started="$now"
  existing_started=$(awk -v slug="$slug" -v sid="$sid" -F"$REGISTRY_FS" '
    /^\|/ && $2==slug && $4==sid { print $5; exit }
  ' "$REGISTRY_PATH" 2>/dev/null)
  [ -n "$existing_started" ] && started="$existing_started"

  awk -v slug="$slug" -v sid="$sid" -F"$REGISTRY_FS" '
    /^\|/ && $2!="slug" && $2!~/^-+$/ && $2==slug && $4==sid { next }
    { print }
  ' "$REGISTRY_PATH" >"$REGISTRY_PATH.tmp"
  printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' \
    "$slug" "$product" "$sid" "$started" "$now" "active" "$cwd_val" "$wfile" >>"$REGISTRY_PATH.tmp"
  mv "$REGISTRY_PATH.tmp" "$REGISTRY_PATH"

  registry_lock_release
  echo "CLAIMED:$slug"
  return 0
}

registry_update() {
  local slug sid status now
  slug="$(registry_sanitize "$1")"
  sid="$(registry_sanitize "$2")"
  status="${3:-active}"
  status="$(registry_sanitize "$status")"
  now="$(date +'%Y-%m-%d %H:%M')"

  registry_init_if_missing
  registry_lock_acquire || return 1

  # printf 명시 출력 — OFS+빈 $1/$NF 로 인한 라인 양끝 공백 회피
  awk -v slug="$slug" -v sid="$sid" -v status="$status" -v now="$now" -F"$REGISTRY_FS" '
    /^\|/ && $2 != "slug" && $2 !~ /^-+$/ && $2 == slug && $4 == sid {
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $2, $3, $4, $5, now, status, $8, $9
      next
    }
    { print }
  ' "$REGISTRY_PATH" >"$REGISTRY_PATH.tmp" && mv "$REGISTRY_PATH.tmp" "$REGISTRY_PATH"

  registry_lock_release
  return 0
}

registry_mark_stale() {
  registry_update "$1" "$2" "stale"
}

# Lock 파일 (state/sessions/{slug}/{sid}.lock) lifecycle
SESSIONS_DIR="${SESSIONS_DIR:-$HOME/.claude/state/sessions}"

session_lock_create() {
  local slug sid lock_dir lock_file
  slug="$(registry_sanitize "$1")"
  sid="$(registry_sanitize "$2")"
  lock_dir="$SESSIONS_DIR/$slug"
  lock_file="$lock_dir/$sid.lock"
  mkdir -p "$lock_dir"
  : >"$lock_file"
}

session_lock_touch() {
  local slug sid lock_file
  slug="$(registry_sanitize "$1")"
  sid="$(registry_sanitize "$2")"
  lock_file="$SESSIONS_DIR/$slug/$sid.lock"
  [ -f "$lock_file" ] && touch "$lock_file" 2>/dev/null
  return 0
}

session_lock_remove() {
  local slug sid lock_file lock_dir
  slug="$(registry_sanitize "$1")"
  sid="$(registry_sanitize "$2")"
  lock_dir="$SESSIONS_DIR/$slug"
  lock_file="$lock_dir/$sid.lock"
  [ -f "$lock_file" ] && rm -f "$lock_file" 2>/dev/null
  rmdir "$lock_dir" 2>/dev/null || true
  return 0
}

session_lock_list_stale() {
  local stale_hours="${STALE_HOURS:-24}"
  local stale_minutes=$((stale_hours * 60))
  [ -d "$SESSIONS_DIR" ] || return 0
  find "$SESSIONS_DIR" -name '*.lock' -type f -mmin "+$stale_minutes" 2>/dev/null
}

# 본 세션 sid 의 모든 active entry 를 status(기본 paused) 로 변경 + session lock 제거.
# working-release.sh(Stop) 인라인 로직의 함수화 — save now·/taskflow:save 경로
# 에서도 본 세션 점유 entry/lock 을 일괄 release 하기 위한 재사용 진입점.
# 각 registry_update 가 자체 lock acquire/release (slug 추출은 lock 밖). stdout = 결과 1줄.
registry_release_session() {
  local sid status slugs slug released=0
  sid="$(registry_sanitize "$1")"
  status="${2:-paused}"
  status="$(registry_sanitize "$status")"
  [ -z "$sid" ] && { echo "[registry-utils] release_session: sid empty"; return 1; }

  registry_init_if_missing

  # 본 sid 의 active entry slug 목록 (sid = $4, status = $7)
  slugs="$(awk -F"$REGISTRY_FS" -v sid="$sid" '
    /^\|/ && $2!="slug" && $2!~/^-+$/ && $4==sid && $7=="active" { print $2 }
  ' "$REGISTRY_PATH" 2>/dev/null)"

  if [ -z "$slugs" ]; then
    echo "[registry-utils] release_session: 본 세션($sid) active entry 0건"
    return 0
  fi

  while IFS= read -r slug; do
    [ -n "$slug" ] || continue
    registry_update "$slug" "$sid" "$status" 2>/dev/null
    session_lock_remove "$slug" "$sid" 2>/dev/null
    released=$((released + 1))
  done <<< "$slugs"

  echo "[registry-utils] release_session: 본 세션($sid) entry ${released}건 → $status"
  return 0
}
