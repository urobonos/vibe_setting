#!/usr/bin/env bash
# watch-snapshot.sh — working/ 태스크 문서 변경 감지 SSOT (2026-07-27)
#
# 용도: /taskflow:watch 가 "지난번 이후 무엇이 바뀌었나"를 상수 비용으로 판정한다.
#       전체를 매번 재검증하면 77건×매 5분 = 낭비 → 변경분만 검증한다.
#
# 스냅샷 위치: ~/.claude/state/watch/{scope}.tsv  (scratchpad 아님 — 세션이 죽어도 남아야
#   다음 세션의 loop 가 이어서 diff 할 수 있다. 2026-07-27 실측: 기존 세션은 scratchpad 에
#   두고 있어 세션 교체 시 전건이 '신규'로 잡히는 상태였다.)
#
# 형식(TSV 4열): path \t mtime \t size \t status
#
# 성능: fork 최소화 — find/xargs stat/awk 로 프로세스 ~6개 (파일마다 stat 서브셸 금지.
#   working-scan.sh 가 같은 이유로 재작성된 전례를 따른다).
#
# 신선도 필터 (WATCH_MIN_AGE_SEC, 기본 300 = 5분): 최종 수정된 지 이 시간 안인 문서는
#   "아직 무르익지 않음"으로 보고 이전 확정 스냅샷 값을 그대로 낸다 (신규면 이번 라운드는
#   아예 스킵). 방금 다른 세션이 저장한 문서를 바로 diff/검증 대상으로 잡지 않기 위함.
#   find -mmin 으로 자르지 않는 이유 — 그러면 이번 스캔 결과에서 그 파일이 통째로 빠져
#   watch_diff 의 D(삭제) 판정("스냅샷엔 있는데 지금 안 보임")이 오판한다. 값을 old 로
#   유지하면 diff 도 안 뜨고, watch_commit 이 그 값을 그대로 재저장해 다음 라운드까지
#   "미확정"이 이어지다가 시간이 지나면 자연히 실제 값으로 갱신된다.
#
# 사용:
#   source ~/.claude/hooks/lib/watch-snapshot.sh
#   watch_diff [scope]      # 변경분 출력 (A/M/D \t path \t 상세) — 스냅샷은 갱신 안 함
#   watch_commit [scope]    # 현재 상태를 스냅샷으로 확정 (검증 완료 후 호출)

WATCH_STATE_DIR="${WATCH_STATE_DIR:-$HOME/.claude/state/watch}"
WATCH_MIN_AGE_SEC="${WATCH_MIN_AGE_SEC:-300}"
_WATCH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -z "${WORKING_ROOT:-}" ] && . "$_WATCH_LIB_DIR/working-scan.sh"

_watch_snap_path() { echo "$WATCH_STATE_DIR/${1:-all}.tsv"; }
_watch_repos_file() { echo "$WATCH_STATE_DIR/repos.txt"; }

# 감시 repo 목록 — 자동 탐색이 아니라 **편집 가능한 목록 파일**.
# 최초 1회만 '최근 REPO_SEED_DAYS 일 내 커밋' repo 로 시딩하고, 이후엔 사용자가 소유한다.
# (전 repo 자동 감시는 노이즈다 — 2026-07-27 실측: 잠든 레거시 hongcafe3_upgrade 가 dirty 35972건.)
WATCH_REPO_SEED_DAYS="${WATCH_REPO_SEED_DAYS:-14}"
WATCH_REPO_SEED_GLOBS="${WATCH_REPO_SEED_GLOBS:-/c/Works/* /c/works/* $HOME/.claude}"

watch_repos_init() {
  local f d cutoff last
  f=$(_watch_repos_file)
  [ -f "$f" ] && return 0
  mkdir -p "$WATCH_STATE_DIR"
  cutoff=$(( $(date +%s) - WATCH_REPO_SEED_DAYS * 86400 ))
  {
    echo "# /taskflow:watch 감시 repo 목록 — 1줄 1경로. '#' 주석. 자유 편집 (자동 갱신 안 함)."
    echo "# 최초 시딩 기준: 최근 ${WATCH_REPO_SEED_DAYS}일 내 커밋."
    for d in $WATCH_REPO_SEED_GLOBS; do
      [ -d "$d/.git" ] || continue
      last=$(git -C "$d" log -1 --format=%ct 2>/dev/null) || continue
      [ -n "$last" ] && [ "$last" -ge "$cutoff" ] && echo "$d"
    done | awk '{ k = tolower($0); if (k in seen) next; seen[k] = 1; print }'
  } > "$f"
  echo "repo 목록 시딩: $f ($(grep -cvE '^\s*(#|$)' "$f")건) — 불필요한 repo 는 직접 지우세요"
}

# repo 축 — repo:{경로} \t HEAD \t dirty수 \t 브랜치
watch_repo_scan() {
  local f d
  f=$(_watch_repos_file)
  [ -f "$f" ] || return 0
  grep -vE '^\s*(#|$)' "$f" | while IFS= read -r d; do
    [ -d "$d/.git" ] || continue
    # porcelain=v2 --branch 한 번으로 HEAD·브랜치·미커밋 수를 모두 얻는다
    # (rev-parse + status + branch 3회 호출 = repo 13개에 6.7초였다. 2026-07-27 실측)
    git -C "$d" status --porcelain=v2 --branch 2>/dev/null | awk -v d="$d" '
      /^# branch\.oid/  { oid = substr($3, 1, 8) }
      /^# branch\.head/ { br = $3 }
      /^[12u?]/         { n++ }
      END { printf "repo:%s\t%s\t%d\t%s\n", d, (oid == "" ? "-" : oid), n, (br == "" ? "-" : br) }'
  done
}

# 현재 상태 산출 — path \t mtime \t size \t status  (+ repo 행은 HEAD \t dirty \t branch)
watch_scan_now() {
  local scope="${1:-all}" snap
  local statuses
  statuses=$(working_scan "$scope" | cut -f1,5)      # path \t status
  snap=$(_watch_snap_path "$scope")

  find "$WORKING_ROOT" -mindepth 2 -maxdepth 2 -name '*.md' -print0 2>/dev/null \
    | xargs -0 -r stat -c '%n	%Y	%s' 2>/dev/null \
    | awk -F'\t' -v st="$statuses" -v snap="$snap" -v minage="$WATCH_MIN_AGE_SEC" -v now="$(date +%s)" '
      BEGIN {
        n = split(st, L, "\n")
        for (i = 1; i <= n; i++) { split(L[i], P, "\t"); if (P[1] != "") S[P[1]] = P[2] }
        while ((getline line < snap) > 0) {
          split(line, Q, "\t")
          if (Q[1] != "") { OM[Q[1]] = Q[2]; OS[Q[1]] = Q[3]; OST[Q[1]] = Q[4] }
        }
        close(snap)
      }
      {
        # working_scan 대상(날짜 prefix + product 매칭)만 추적한다 — 그 밖은 스캐너가 안 보는 파일
        if (!($1 in S)) next
        mtime = $2; size = $3; status = S[$1]
        if ((now - mtime) < minage) {
          if ($1 in OM) { mtime = OM[$1]; size = OS[$1]; status = OST[$1] }
          else next   # 스냅샷에 없던 신규 + 신선(minage 이내) → 이번 라운드는 스킵, 다음에 재평가
        }
        printf "%s\t%s\t%s\t%s\n", $1, mtime, size, status
      }' \
    | sort

  watch_repo_scan | sort
}

# 이전 스냅샷 대비 변경분 — "A|M|D \t path \t 상세"
watch_diff() {
  local scope="${1:-all}" snap
  snap=$(_watch_snap_path "$scope")
  watch_repos_init >/dev/null

  if [ ! -f "$snap" ]; then
    echo "INIT	$(watch_scan_now "$scope" | wc -l)	최초 실행 — 기준선만 저장 (변경 판정 없음)"
    return 0
  fi

  watch_scan_now "$scope" | awk -F'\t' -v snap="$snap" '
    BEGIN {
      while ((getline line < snap) > 0) {
        split(line, P, "\t")
        if (P[1] == "") continue
        OM[P[1]] = P[2]; OS[P[1]] = P[3]; OST[P[1]] = P[4]
      }
    }
    {
      seen[$1] = 1
      isrepo = ($1 ~ /^repo:/)
      if (!($1 in OM)) { printf "A\t%s\t%s\n", $1, (isrepo ? "감시 목록 추가" : "신규"); next }
      d = ""
      if (isrepo) {
        # repo 축은 열 의미가 다르다: $2=HEAD $3=dirty수 $4=브랜치
        if (OM[$1]  != $2) d = d sprintf("커밋 %s→%s; ", OM[$1], $2)
        if (OST[$1] != $4) d = d sprintf("브랜치 %s→%s; ", OST[$1], $4)
        if (OS[$1]  != $3) d = d sprintf("미커밋 %s→%s건; ", OS[$1], $3)
      } else {
        if (OST[$1] != $4) d = d sprintf("상태 %s→%s; ", OST[$1], $4)
        if (OS[$1]  != $3) d = d sprintf("크기 %s→%s; ", OS[$1], $3)
        else if (OM[$1] != $2) d = d "내용 갱신(크기 동일); "
      }
      if (d != "") printf "M\t%s\t%s\n", $1, d
    }
    END { for (p in OM) if (!(p in seen)) printf "D\t%s\t사라짐(완료 이동/삭제)\n", p }
  '
}

# 검증 끝난 뒤에만 호출 — 확정 전에 갱신하면 그 변경분은 영영 검증 대상에서 빠진다
watch_commit() {
  local scope="${1:-all}" snap
  snap=$(_watch_snap_path "$scope")
  mkdir -p "$WATCH_STATE_DIR"
  watch_scan_now "$scope" > "$snap.tmp" && mv "$snap.tmp" "$snap"
  echo "스냅샷 갱신: $snap ($(wc -l < "$snap")건)"
}
