#!/bin/bash
# vendor-lock-stamp.sh
# vendor 가 어느 composer.lock 으로 설치됐는지 스탬프하고, 쓰는 쪽 lock 과 대조한다.
#
# 배경: ~/.claude/worktrees/ 에 여러 레포의 worktree 가 섞여 있다. worktree 마다
#   vendor 를 따로 설치하거나 다른 경로의 vendor 를 심링크하는데, 링크가 남의 레포를
#   가리키거나 lock 갱신 후 vendor 가 낡아도 실행 전까지 아무 신호가 없다.
#   composer 는 그 상태로 그냥 부팅되고, 없는 클래스에서야 터진다.
#
# 스탬프 = vendor/.lock-sha (설치에 쓰인 composer.lock 의 sha256).
#   vendor 가 심링크면 스탬프도 링크 대상에 놓인다 — 여러 worktree 가 vendor 하나를
#   공유해도 판정이 저절로 일관된다.
#
# 판정:
#   OK        스탬프 == 자기 composer.lock
#   MISMATCH  어긋남 (vendor 가 낡았거나 남의 레포를 가리킴) → exit 1
#   UNSTAMPED 스탬프 없음 (도입 전 설치분) → stamp-all 로 승인
#   MISSING   vendor 없음
#   SKIP      composer.lock 없음 (PHP 레포 아님)
#
# 사용법:
#   bash ~/.claude/bin/vendor-lock-stamp.sh check             # 전 worktree + 소속 본 레포
#   bash ~/.claude/bin/vendor-lock-stamp.sh check <경로>      # 단일
#   bash ~/.claude/bin/vendor-lock-stamp.sh stamp <경로>      # 현재 lock 으로 스탬프
#   bash ~/.claude/bin/vendor-lock-stamp.sh stamp-all         # UNSTAMPED 전건 일괄 스탬프
#
# composer install 직후 stamp 를 부르면 그 시점 lock 이 박힌다.

WORKTREE_ROOT="${HOME}/.claude/worktrees"
STAMP_NAME=".lock-sha"
MODE="${1:-check}"
TARGET="$2"
MISMATCH=0

lock_sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

# worktree 의 .git 파일에서 소속 본 레포를 역산한다. 디렉토리 이름으로는 알 수 없다.
repo_of() {
  local d="$1"
  if [ -f "$d/.git" ]; then
    sed -n 's/^gitdir: //p' "$d/.git" | sed 's#/\.git/worktrees/.*##'
  elif [ -d "$d/.git" ]; then
    echo "$d"
  fi
}

targets() {
  if [ -n "$TARGET" ]; then echo "$TARGET"; return; fi
  local repos=""
  for d in "$WORKTREE_ROOT"/*/; do
    [ -d "$d" ] || continue
    echo "${d%/}"
    local r; r=$(repo_of "${d%/}")
    [ -n "$r" ] && [ -d "$r" ] && repos="${repos}${r}\n"
  done
  printf "%b" "$repos" | sort -u | grep -v '^$'
}

report() { printf "%-10s %-42s %s\n" "$1" "$2" "$3"; }

check_one() {
  local d="$1" label="$2"
  local lock="$d/composer.lock"
  [ -f "$lock" ] || { report SKIP "$label" "composer.lock 없음"; return; }
  local want; want=$(lock_sha "$lock")

  [ -e "$d/vendor" ] || { report MISSING "$label" "vendor 없음"; return; }

  local stamp="$d/vendor/$STAMP_NAME"
  [ -f "$stamp" ] || { report UNSTAMPED "$label" "lock ${want:0:12}"; return; }

  local have; have=$(tr -d '[:space:]' < "$stamp")
  if [ "$have" = "$want" ]; then
    report OK "$label" "lock ${want:0:12}"
  else
    local via=""
    [ -L "$d/vendor" ] && via=" → $(readlink "$d/vendor")"
    report MISMATCH "$label" "vendor ${have:0:12} != lock ${want:0:12}${via}"
    MISMATCH=$((MISMATCH + 1))
  fi
}

stamp_one() {
  local d="$1"
  local lock="$d/composer.lock"
  [ -f "$lock" ] || { echo "스탬프 불가: $d — composer.lock 없음" >&2; return 1; }
  [ -e "$d/vendor" ] || { echo "스탬프 불가: $d — vendor 없음" >&2; return 1; }
  lock_sha "$lock" > "$d/vendor/$STAMP_NAME" || return 1
  echo "스탬프 완료: $d/vendor/$STAMP_NAME"
}

case "$MODE" in
  check)
    printf "%-10s %-42s %s\n" "판정" "대상" "상세"
    printf -- "----------------------------------------------------------------------------\n"
    while read -r d; do
      [ -n "$d" ] || continue
      local_repo=$(repo_of "$d")
      label="$(basename "$d")"
      [ -n "$local_repo" ] && [ "$local_repo" != "$d" ] && label="$label [$(basename "$local_repo")]"
      check_one "$d" "$label"
    done < <(targets)
    echo
    if [ "$MISMATCH" -gt 0 ]; then
      echo "MISMATCH ${MISMATCH}건 — 해당 worktree 는 composer install 을 다시 하거나 링크를 고쳐야 합니다."
      exit 1
    fi
    echo "MISMATCH 0건"
    ;;
  stamp)
    [ -n "$TARGET" ] || { echo "사용법: $0 stamp <경로>" >&2; exit 2; }
    stamp_one "$TARGET"
    ;;
  stamp-all)
    n=0
    while read -r d; do
      [ -n "$d" ] || continue
      [ -f "$d/composer.lock" ] || continue
      [ -e "$d/vendor" ] || continue
      [ -f "$d/vendor/$STAMP_NAME" ] && continue
      stamp_one "$d" && n=$((n + 1))
    done < <(targets)
    echo "일괄 스탬프 ${n}건"
    ;;
  *)
    sed -n '2,30p' "$0"
    exit 2
    ;;
esac
