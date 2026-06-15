#!/usr/bin/env bash
# dispatch-utils.sh — 작업 분배 풀(DISPATCH) CRUD + 배타적 claim lib
# SSOT: ~/.claude/commands/작업분배.md + ~/.claude/commands/작업시작.md
#
# 사용:
#   source "$(dirname "$0")/lib/dispatch-utils.sh"
#   dispatch_init_if_missing
#   dispatch_add   "tag" "작업명" "product" "dispatch_doc"   # status=available 등록
#   dispatch_list  [available|claimed|done]                  # 필터 또는 전체
#   dispatch_find  "tag"
#   dispatch_claim "tag" "sid"     # 배타적 claim (race-safe, stale steal) → "RESULT|doc"
#   dispatch_done  "tag" "sid"     # status=done + claim lock 정리
#   dispatch_release "tag" "sid"   # claim 취소 → available 복귀
#
# Lock: mkdir lock (POSIX atomic — registry-utils.sh 와 동일 검증 패턴, 별도 경로).
# 범용 함수 재사용: registry-utils.sh 를 source 해 REGISTRY_FS 정렬 (sanitize 는 dispatch 전용 — 한글/# 보존 차이).

DISPATCH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DISPATCH_LIB_DIR/registry-utils.sh" 2>/dev/null || true

DISPATCH_PATH="${DISPATCH_PATH:-$HOME/.claude/docs/working/DISPATCH.md}"
DISPATCH_LOCK="${DISPATCH_LOCK:-/tmp/claude-dispatch.lock.d}"
DISPATCH_CLAIMS_DIR="${DISPATCH_CLAIMS_DIR:-$HOME/.claude/state/dispatch}"
DISPATCH_LOCK_RETRIES="${DISPATCH_LOCK_RETRIES:-50}"
DISPATCH_LOCK_SLEEP="${DISPATCH_LOCK_SLEEP:-0.1}"
DISPATCH_STALE_HOURS="${DISPATCH_STALE_HOURS:-24}"

# 마크다운 표 FS — registry-utils.sh REGISTRY_FS 와 동일 (미로드 fallback 포함)
DISPATCH_FS="${REGISTRY_FS:-[[:space:]]*\\|[[:space:]]*}"

# tag = 파일경로·lock 디렉토리명에 쓰이므로 엄격 sanitize (영숫자 + - _, '#' 제거)
dispatch_tag_sanitize() {
  printf '%s' "$1" | tr -cd '[:alnum:]_-'
}

# 본문(작업명·경로) = 마크다운 표 인젝션 방지로 '|' 와 개행만 제거, 한글·공백 보존 + 양끝 trim
dispatch_sanitize() {
  printf '%s' "$1" | tr -d '\n\r|' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# claimed_at(YYYY-MM-DD HH:MM) 이 DISPATCH_STALE_HOURS 초과 경과 시 0(true) — 점유 세션 즉사 self-heal
dispatch_is_stale() {
  local claimed_at="$1" now_epoch claimed_epoch threshold
  [ -z "$claimed_at" ] || [ "$claimed_at" = "-" ] && return 1
  now_epoch=$(date +%s 2>/dev/null) || return 1
  claimed_epoch=$(date -d "$claimed_at" +%s 2>/dev/null) || return 1
  threshold=$((DISPATCH_STALE_HOURS * 3600))
  [ $((now_epoch - claimed_epoch)) -ge "$threshold" ]
}

dispatch_lock_acquire() {
  local i=0
  while ! mkdir "$DISPATCH_LOCK" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge "$DISPATCH_LOCK_RETRIES" ]; then
      echo "[dispatch-utils] lock timeout: $DISPATCH_LOCK" >&2
      return 1
    fi
    sleep "$DISPATCH_LOCK_SLEEP"
  done
  return 0
}

dispatch_lock_release() {
  rmdir "$DISPATCH_LOCK" 2>/dev/null || true
}

dispatch_init_if_missing() {
  if [ ! -f "$DISPATCH_PATH" ]; then
    mkdir -p "$(dirname "$DISPATCH_PATH")"
    cat >"$DISPATCH_PATH" <<'EOF'
# Dispatch Pool (작업 분배 풀)

> SSOT: `/작업분배` 가 등록, `/작업시작 #tag` 가 배타적 claim 하는 분배 작업 인덱스.
> 갱신 주체: dispatch-utils.sh (commands/작업분배.md + 작업시작.md 경유). 직접 편집 금지 (race 보호 — mkdir lock).
> status: available (대기) / claimed (점유 중) / done (완료)

| tag | 작업명 | product | status | claimed_by | claimed_at | dispatched_at | dispatch_doc |
|-----|--------|---------|--------|-----------|-----------|---------------|--------------|
EOF
  fi
}

# claim 디렉토리의 기존 lock 파일 정리 (rm -rf 회피 — .lock 파일만 개별 삭제)
dispatch_claim_dir_reset() {
  local tag="$1"
  if [ -d "$DISPATCH_CLAIMS_DIR/$tag" ]; then
    find "$DISPATCH_CLAIMS_DIR/$tag" -maxdepth 1 -name '*.lock' -type f -delete 2>/dev/null
  fi
}

dispatch_find() {
  local tag
  tag="$(dispatch_tag_sanitize "$1")"
  dispatch_init_if_missing
  awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ && $2 == t { print }
  ' "$DISPATCH_PATH" 2>/dev/null
}

dispatch_list() {
  local filter="${1:-}"
  dispatch_init_if_missing
  awk -v f="$filter" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ {
      if (f == "" || $5 == f) print
    }
  ' "$DISPATCH_PATH" 2>/dev/null
}

dispatch_add() {
  local tag work product doc now existing_status
  tag="$(dispatch_tag_sanitize "$1")"
  work="$(dispatch_sanitize "$2")"
  product="$(dispatch_sanitize "$3")"
  doc="$(dispatch_sanitize "$4")"
  now="$(date +'%Y-%m-%d %H:%M')"

  [ -z "$tag" ] && { echo "[dispatch-utils] tag empty" >&2; return 1; }

  dispatch_init_if_missing
  dispatch_lock_acquire || return 1

  # 진행 중(claimed) 또는 완료(done) 태그 재분배 거부 — available 또는 신규만 등록/갱신
  existing_status="$(awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ && $2 == t { print $5; exit }
  ' "$DISPATCH_PATH" 2>/dev/null)"
  if [ "$existing_status" = "claimed" ] || [ "$existing_status" = "done" ]; then
    dispatch_lock_release
    echo "[dispatch-utils] tag '$tag' already $existing_status — 재분배 거부" >&2
    return 2
  fi

  awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ && $2 == t { next }
    { print }
  ' "$DISPATCH_PATH" >"$DISPATCH_PATH.tmp"
  printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' \
    "$tag" "$work" "$product" "available" "-" "-" "$now" "$doc" \
    >>"$DISPATCH_PATH.tmp"
  mv "$DISPATCH_PATH.tmp" "$DISPATCH_PATH"

  dispatch_lock_release
  return 0
}

# 배타적 claim — race-safe. stdout = "RESULT|doc" (TAKEN/DONE 도 doc 포함, NOTFOUND 만 단독)
#   CLAIMED|doc        (return 0) — available → 점유 성공
#   ALREADY_YOURS|doc  (return 0) — 본인이 이미 점유 중
#   STOLEN:<old>|doc   (return 0) — stale(24h+) steal
#   TAKEN:<sid>|doc    (return 3) — 타 세션 점유 중 (거부)
#   DONE|doc           (return 4) — 이미 완료 (거부)
#   NOTFOUND           (return 2) — 태그 없음
#   LOCKFAIL           (return 1) — lock timeout
dispatch_claim() {
  local tag sid now line status claimed_by claimed_at doc result
  tag="$(dispatch_tag_sanitize "$1")"
  sid="$(dispatch_sanitize "$2")"
  now="$(date +'%Y-%m-%d %H:%M')"

  [ -z "$tag" ] && { echo "NOTFOUND"; return 2; }

  dispatch_init_if_missing
  dispatch_lock_acquire || { echo "LOCKFAIL"; return 1; }

  line="$(awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ && $2 == t { print; exit }
  ' "$DISPATCH_PATH" 2>/dev/null)"
  if [ -z "$line" ]; then
    dispatch_lock_release
    echo "NOTFOUND"
    return 2
  fi
  status="$(echo "$line" | awk -F"$DISPATCH_FS" '{print $5}')"
  claimed_by="$(echo "$line" | awk -F"$DISPATCH_FS" '{print $6}')"
  claimed_at="$(echo "$line" | awk -F"$DISPATCH_FS" '{print $7}')"
  doc="$(echo "$line" | awk -F"$DISPATCH_FS" '{print $9}')"

  case "$status" in
    available)
      result="CLAIMED"
      ;;
    claimed)
      if [ "$claimed_by" = "$sid" ]; then
        result="ALREADY_YOURS"
      elif dispatch_is_stale "$claimed_at"; then
        result="STOLEN:$claimed_by"
      else
        dispatch_lock_release
        echo "TAKEN:$claimed_by|$doc"
        return 3
      fi
      ;;
    done)
      dispatch_lock_release
      echo "DONE|$doc"
      return 4
      ;;
    *)
      dispatch_lock_release
      echo "UNKNOWN:$status|$doc"
      return 5
      ;;
  esac

  # claim 기록 (status=claimed, claimed_by=sid, claimed_at=now / 작업명·product·dispatched_at·doc 보존)
  awk -v t="$tag" -v sid="$sid" -v now="$now" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ && $2 == t {
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $2, $3, $4, "claimed", sid, now, $8, $9
      next
    }
    { print }
  ' "$DISPATCH_PATH" >"$DISPATCH_PATH.tmp" && mv "$DISPATCH_PATH.tmp" "$DISPATCH_PATH"

  # claim lock 갱신 (steal 시 이전 sid lock 정리 후 본인 lock 생성)
  dispatch_claim_dir_reset "$tag"
  mkdir -p "$DISPATCH_CLAIMS_DIR/$tag"
  : >"$DISPATCH_CLAIMS_DIR/$tag/$sid.lock"

  dispatch_lock_release
  echo "$result|$doc"
  return 0
}

dispatch_done() {
  local tag sid
  tag="$(dispatch_tag_sanitize "$1")"
  sid="$(dispatch_sanitize "$2")"

  dispatch_init_if_missing
  dispatch_lock_acquire || return 1

  awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ && $2 == t {
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $2, $3, $4, "done", $6, $7, $8, $9
      next
    }
    { print }
  ' "$DISPATCH_PATH" >"$DISPATCH_PATH.tmp" && mv "$DISPATCH_PATH.tmp" "$DISPATCH_PATH"

  rm -f "$DISPATCH_CLAIMS_DIR/$tag/$sid.lock" 2>/dev/null
  rmdir "$DISPATCH_CLAIMS_DIR/$tag" 2>/dev/null || true

  dispatch_lock_release
  return 0
}

dispatch_release() {
  local tag sid
  tag="$(dispatch_tag_sanitize "$1")"
  sid="$(dispatch_sanitize "$2")"

  dispatch_init_if_missing
  dispatch_lock_acquire || return 1

  awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2 != "tag" && $2 !~ /^-+$/ && $2 == t {
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $2, $3, $4, "available", "-", "-", $8, $9
      next
    }
    { print }
  ' "$DISPATCH_PATH" >"$DISPATCH_PATH.tmp" && mv "$DISPATCH_PATH.tmp" "$DISPATCH_PATH"

  rm -f "$DISPATCH_CLAIMS_DIR/$tag/$sid.lock" 2>/dev/null
  rmdir "$DISPATCH_CLAIMS_DIR/$tag" 2>/dev/null || true

  dispatch_lock_release
  return 0
}
