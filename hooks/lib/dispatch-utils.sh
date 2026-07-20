#!/usr/bin/env bash
# dispatch-utils.sh — 작업 분배 풀(DISPATCH) CRUD + 배타적 claim lib
# SSOT: plan.md §"병렬 그룹 다세션 분배"(dispatch_add) + load.md §"#tag claim"(dispatch_claim/done) — 2026-07-16 워커풀 흡수
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
# stale lock 회수 임계 (분): 정상 lock 은 ms~초 단위 보유 → TTL 초과 = 소유 프로세스 즉사 후 미해제 orphan.
# registry-utils REGISTRY_LOCK_TTL_MIN 과 정합 (backlog dispatch-lock-stale-leak, 2026-06-16 16세션 11분 동결 재발 차단).
DISPATCH_LOCK_TTL_MIN="${DISPATCH_LOCK_TTL_MIN:-2}"

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
    # stale steal (backlog dispatch-lock-stale-leak, 2026-06-16): acquire 후 rmdir 전 프로세스 즉사 시
    #   lock 영구 잔존 → 전 세션 DISPATCH CRUD 동결하던 문제 차단. mtime TTL 회수 (registry-utils 와 동일 패턴,
    #   Git Bash kill -0 PID liveness 불확실 → mtime 방식). mkdir atomic 으로 회수 race 안전.
    if [ -d "$DISPATCH_LOCK" ] && find "$DISPATCH_LOCK" -maxdepth 0 -mmin "+$DISPATCH_LOCK_TTL_MIN" 2>/dev/null | grep -q .; then
      rmdir "$DISPATCH_LOCK" 2>/dev/null
      echo "[dispatch-utils] stale lock 회수 (>${DISPATCH_LOCK_TTL_MIN}min orphan): $DISPATCH_LOCK" >&2
      continue
    fi
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

> SSOT: plan §"병렬 그룹 다세션 분배" 가 등록(dispatch_add), `/taskflow:load #tag` 가 배타적 claim 하는 분배 작업 인덱스.
> 갱신 주체: dispatch-utils.sh (plan.md §병렬 그룹 + load.md §#tag claim 경유). 직접 편집 금지 (race 보호 — mkdir lock).
> 정리·release 는 lib 함수만: done 정리=dispatch_purge_done / 세션 점유 해제=dispatch_release_session. 수동 awk·mv 금지 (lock 밖 읽기 = orphan race).
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

# done 상태 태그 일괄 정리 — DISPATCH.md done 행 제거 + dispatch_doc 을
#   {product}/tasks/{today}/dispatch-archive/ 이동 + claim lock 정리.
# race-safe: lock 안에서 추출→이동→제거를 원자 처리한다. (lock 밖에서 done 목록을
#   읽고 lock 안에서 제거하면 그 사이 다른 세션이 claim→done 시 mv 목록 불일치·
#   orphan 문서가 발생 — 본 함수는 추출·이동·제거를 한 lock 구간에 묶어 차단.)
# 정리 기준 = DISPATCH status=done 행만. 행 없는 orphan 문서는 비대상
#   (dispatch_add 직전 '문서 생성 후 행 등록 전' 순간을 오인 정리하지 않기 위함).
# stdout = 처리 결과 1줄. return 0 정상 / 1 lock 실패.
dispatch_purge_done() {
  local today done_rows moved=0 removed=0 tag product doc archive_dir
  today="$(date +%Y%m%d)"

  dispatch_init_if_missing
  dispatch_lock_acquire || { echo "[dispatch-utils] purge: lock timeout"; return 1; }

  # lock 안에서 done 행 추출: tag \t product \t doc
  done_rows="$(awk -F"$DISPATCH_FS" '
    /^\|/ && $2!="tag" && $2!~/^-+$/ && $5=="done" { print $2 "\t" $4 "\t" $9 }
  ' "$DISPATCH_PATH" 2>/dev/null)"

  if [ -z "$done_rows" ]; then
    dispatch_lock_release
    echo "[dispatch-utils] purge: done 0건 (정리 불필요)"
    return 0
  fi

  # 1) dispatch_doc 문서 이동 + claim lock 정리 (행별)
  while IFS=$'\t' read -r tag product doc; do
    [ -n "$tag" ] || continue
    if [ -n "$doc" ] && [ -f "$doc" ]; then
      archive_dir="$HOME/.claude/docs/$product/tasks/$today/dispatch-archive"
      mkdir -p "$archive_dir" 2>/dev/null
      mv "$doc" "$archive_dir/" 2>/dev/null && moved=$((moved + 1))
    fi
    if [ -d "$DISPATCH_CLAIMS_DIR/$tag" ]; then
      find "$DISPATCH_CLAIMS_DIR/$tag" -maxdepth 1 -name '*.lock' -type f -delete 2>/dev/null
      rmdir "$DISPATCH_CLAIMS_DIR/$tag" 2>/dev/null || true
    fi
    removed=$((removed + 1))
  done <<< "$done_rows"

  # 2) DISPATCH.md done 행 제거 (동일 lock 구간)
  awk -F"$DISPATCH_FS" '
    /^\|/ && $2!="tag" && $2!~/^-+$/ && $5=="done" { next }
    { print }
  ' "$DISPATCH_PATH" >"$DISPATCH_PATH.tmp" && mv "$DISPATCH_PATH.tmp" "$DISPATCH_PATH"

  dispatch_lock_release
  echo "[dispatch-utils] purge: done ${removed}건 제거 / 문서 ${moved}건 아카이브 (tasks/${today}/dispatch-archive/)"
  return 0
}

# 본 세션 sid 가 claim 한 모든 태그를 release (available 복귀) + claim lock 정리.
# 세션 종료(working-release.sh Stop / save now / /taskflow:save) 시 orphan claim 방지.
# done 은 비대상 — claimed 로 남은 것 = 미완료이므로 다음·타 세션이 이어받도록 푼다.
#   (완료분은 이미 dispatch_done 으로 빠진 상태.)
# race-safe: lock 안에서 추출→available 갱신→lock 제거 원자. stdout = 결과 1줄. return 0/1.
dispatch_release_session() {
  local sid claimed_tags released=0 tag
  sid="$(dispatch_tag_sanitize "$1")"      # sid 는 영숫자 — tag sanitize 재사용
  [ -z "$sid" ] && { echo "[dispatch-utils] release_session: sid empty"; return 1; }

  dispatch_init_if_missing
  dispatch_lock_acquire || { echo "[dispatch-utils] release_session: lock timeout"; return 1; }

  # 본 sid 가 claimed_by 인 claimed 태그 추출 (claimed_by = $6)
  claimed_tags="$(awk -F"$DISPATCH_FS" -v s="$sid" '
    /^\|/ && $2!="tag" && $2!~/^-+$/ && $5=="claimed" && $6==s { print $2 }
  ' "$DISPATCH_PATH" 2>/dev/null)"

  if [ -z "$claimed_tags" ]; then
    dispatch_lock_release
    echo "[dispatch-utils] release_session: 본 세션($sid) claim 0건"
    return 0
  fi

  # 해당 태그 → available 복귀 (한 awk 패스, claimed_by==sid 만 영향)
  awk -F"$DISPATCH_FS" -v s="$sid" '
    /^\|/ && $2!="tag" && $2!~/^-+$/ && $5=="claimed" && $6==s {
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $2, $3, $4, "available", "-", "-", $8, $9
      next
    }
    { print }
  ' "$DISPATCH_PATH" >"$DISPATCH_PATH.tmp" && mv "$DISPATCH_PATH.tmp" "$DISPATCH_PATH"

  # claim lock 제거 (state/dispatch/{tag}/{sid}.lock)
  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    rm -f "$DISPATCH_CLAIMS_DIR/$tag/$sid.lock" 2>/dev/null
    rmdir "$DISPATCH_CLAIMS_DIR/$tag" 2>/dev/null || true
    released=$((released + 1))
  done <<< "$claimed_tags"

  dispatch_lock_release
  echo "[dispatch-utils] release_session: 본 세션($sid) claim ${released}건 → available"
  return 0
}

# 특정 태그 1건 폐기(discard) — done(완료)과 구분. 진행 안 하기로 한 작업을 풀에서 제거.
#   DISPATCH 행 삭제 + dispatch_doc 을 {product}/tasks/{today}/dispatch-archive/discarded/ 이동
#   (폐기 사유 주석 append) + claim lock 정리. done 마킹을 안 쓰는 이유 = 진행률 0% 작업을
#   "완료"로 오기록하면 진척 통계가 오염되기 때문 (폐기 ≠ 완료).
# race-safe: 추출→이동→행삭제를 한 lock 구간 원자 처리 (dispatch_purge_done 과 동일 패턴).
# stdout = 결과 1줄. return 0 정상 / 1 lock 실패 / 2 태그 없음.
dispatch_discard() {
  local tag reason today line product doc archive_dir
  tag="$(dispatch_tag_sanitize "$1")"
  reason="$(dispatch_sanitize "$2")"
  today="$(date +%Y%m%d)"
  [ -z "$tag" ] && { echo "[dispatch-utils] discard: tag empty" >&2; return 1; }

  dispatch_init_if_missing
  dispatch_lock_acquire || { echo "[dispatch-utils] discard: lock timeout" >&2; return 1; }

  line="$(awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2!="tag" && $2!~/^-+$/ && $2==t { print; exit }
  ' "$DISPATCH_PATH" 2>/dev/null)"
  if [ -z "$line" ]; then
    dispatch_lock_release
    echo "[dispatch-utils] discard: tag '$tag' 없음 (이미 제거/미존재)"
    return 2
  fi
  product="$(echo "$line" | awk -F"$DISPATCH_FS" '{print $4}')"
  doc="$(echo "$line" | awk -F"$DISPATCH_FS" '{print $9}')"

  # 1) 문서 폐기 보관 이동 + 사유 주석 append
  if [ -n "$doc" ] && [ -f "$doc" ]; then
    archive_dir="$HOME/.claude/docs/$product/tasks/$today/dispatch-archive/discarded"
    mkdir -p "$archive_dir" 2>/dev/null
    printf '\n---\n> **폐기(discarded) %s** — 사유: %s\n' "$(date +'%Y-%m-%d %H:%M')" "$reason" >>"$doc"
    mv "$doc" "$archive_dir/" 2>/dev/null
  fi
  # 2) claim lock 정리
  if [ -d "$DISPATCH_CLAIMS_DIR/$tag" ]; then
    find "$DISPATCH_CLAIMS_DIR/$tag" -maxdepth 1 -name '*.lock' -type f -delete 2>/dev/null
    rmdir "$DISPATCH_CLAIMS_DIR/$tag" 2>/dev/null || true
  fi
  # 3) DISPATCH 행 제거 (동일 lock 구간)
  awk -v t="$tag" -F"$DISPATCH_FS" '
    /^\|/ && $2!="tag" && $2!~/^-+$/ && $2==t { next }
    { print }
  ' "$DISPATCH_PATH" >"$DISPATCH_PATH.tmp" && mv "$DISPATCH_PATH.tmp" "$DISPATCH_PATH"

  dispatch_lock_release
  echo "[dispatch-utils] discard: '$tag' 폐기 — 행 제거 + 문서 → dispatch-archive/discarded/ (사유: $reason)"
  return 0
}
