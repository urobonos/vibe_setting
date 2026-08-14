#!/usr/bin/env bash
# wbs-sheet-sync.sh — 구글 시트 → WBS 간트 동기화 한 방 러너.
#
#   레포 docs/wbs/tools/ 의 4 스크립트 + 구글 푸시를 순서대로 돌리고 결과를 요약한다.
#     1. sheet-sync.py         시트 CSV      → 캐시 CSV
#     2. build-tracker.py      phases+캐시   → tsv/csv
#     3. build-xlsx.py         tsv           → 간트 xlsx
#     4. build-menu-summary.py 간트 xlsx     → 메뉴별 요약 xlsx (보고용)
#     5. gsheet-push-summary.py 요약 xlsx    → 구글 시트 `요약` 탭 (변경 회차에만)
#
#   로직은 전부 레포 쪽 스크립트에 있다. 본 파일은 순서·실패 분기·요약만 담당한다
#   (로직을 여기 복제하면 SSOT 가 둘로 갈라진다).
#
#   4단계는 간트 xlsx 를 소스로 삼으므로 반드시 3단계 뒤에 온다. 스크립트가 없는
#   레포에서는 건너뛴다 — 이 러너를 다른 레포에도 쓰기 위해서다.
#
#   데이터 무변경 회차에 xlsx 만 재생성 타임스탬프로 더러워지는 것을 되돌린다 —
#   5분 루프가 매번 무의미한 바이너리 diff 를 남기지 않게.
#
# 사용법
#   bash wbs-sheet-sync.sh [repo-root]
#   repo-root 생략 시 cwd 의 git toplevel → 없으면 기본 경로.
#
# SSOT: custom-plugin/tools/commands/wbs-sync.md + 레포 docs/wbs/tools/*.py
# ---------------------------------------------------------------------------
set -uo pipefail

FALLBACK_REPO='/c/Works/hongcafe_local_athena'
XLSX='2026-08-11-wbs-gantt.xlsx'
TSV='2026-08-11-wbs-gantt.tsv'
CSV='2026-08-11-wbs-gantt.csv'
CACHE='2026-08-12-sheet-owner-status.csv'
MENU='2026-08-12-wbs-menu-summary.xlsx'

# --- 레포 해석 ---
REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -d "$REPO/docs/wbs" ] || REPO="$FALLBACK_REPO"
fi
WBS="$REPO/docs/wbs"
if [ ! -d "$WBS" ]; then
  echo "[ERR] docs/wbs 를 못 찾았다: $WBS" >&2
  echo "      레포 루트를 인자로 넘겨라 — bash wbs-sheet-sync.sh /path/to/repo" >&2
  exit 1
fi
for f in tools/sheet-sync.py tools/build-tracker.py tools/build-xlsx.py; do
  [ -f "$WBS/$f" ] || { echo "[ERR] 생성기 없음: $WBS/$f" >&2; exit 1; }
done
cd "$WBS" || exit 1

PY=python
command -v python >/dev/null 2>&1 || PY=python3

# --- 직전 회차 스냅샷 ---
# 데이터 3종의 지문과 xlsx 2종의 사본을 뜬다. 회차 끝에서 데이터가 그대로면
# xlsx 를 이 사본으로 되돌려 재생성 타임스탬프 diff 를 지운다.
#
# 구 구현은 이 판정을 `git diff` 로 했다가 사고를 냈다 — develop 이 전진하면
# "HEAD 대비 무변경" 이 엉뚱하게 성립해서 `git checkout` 이 파생물을 옛 커밋
# 상태로 되돌렸다 (Done 12 → Done 5, 2026-08-13 실측). 비교 대상은 커밋이
# 아니라 **직전 회차**여야 한다. 이제 git 을 전혀 보지 않는다.
SNAP="$(mktemp -d 2>/dev/null)"
snap_fingerprint() { md5sum "$TSV" "$CSV" "$CACHE" 2>/dev/null; }
BEFORE="$(snap_fingerprint)"
if [ -n "$SNAP" ] && [ -d "$SNAP" ]; then
  for f in "$XLSX" "$MENU"; do [ -f "$f" ] && cp -p "$f" "$SNAP/" 2>/dev/null; done
fi
cleanup_snap() { [ -n "${SNAP:-}" ] && [ -d "$SNAP" ] && rm -rf "$SNAP"; }
trap cleanup_snap EXIT

# --- 1. 시트 → 캐시 ---
if ! "$PY" tools/sheet-sync.py; then
  echo "[중단] 시트 단계 실패 — 위 원인 메시지를 보라 (대개 공유 설정 또는 헤더 변경)" >&2
  exit 1
fi

# --- 2. 캐시 + phases → tsv/csv ---
if ! "$PY" tools/build-tracker.py; then
  echo "[중단] tsv/csv 생성 실패 — 시트와 phases/*.md 가 어긋났거나 어휘 밖 상태값이다" >&2
  exit 1
fi

# --- 3. tsv → xlsx ---
if ! XOUT="$("$PY" tools/build-xlsx.py 2>&1)"; then
  if printf '%s' "$XOUT" | grep -q 'PermissionError'; then
    echo "[중단] $XLSX 가 잠겨 있다 — Excel 에서 닫고 다시 실행해라" >&2
    echo "       tsv/csv 는 이미 갱신됐다. 파일을 닫으면 xlsx 만 다시 만들면 된다." >&2
  else
    printf '%s\n' "$XOUT" >&2
    echo "[중단] xlsx 생성 실패" >&2
  fi
  exit 1
fi
printf '%s\n' "$XOUT"

# --- 4. 간트 xlsx → 메뉴별 요약 xlsx (보고용) ---
# 간트를 소스로 읽으므로 반드시 3단계 뒤. 없는 레포에서는 건너뛴다.
if [ -f tools/build-menu-summary.py ]; then
  if ! MOUT="$("$PY" tools/build-menu-summary.py 2>&1)"; then
    if printf '%s' "$MOUT" | grep -q 'PermissionError'; then
      echo "[중단] $MENU 가 잠겨 있다 — Excel 에서 닫고 다시 실행해라" >&2
      echo "       간트 xlsx 까지는 갱신됐다. 파일을 닫으면 요약만 다시 만들면 된다." >&2
    else
      printf '%s\n' "$MOUT" >&2
      echo "[중단] 메뉴 요약 생성 실패" >&2
    fi
    exit 1
  fi
  printf '%s\n' "$MOUT"
fi

# --- 무변경 회차의 xlsx 바이너리 noise 되돌리기 ---
# 데이터 3종의 지문이 회차 전후로 같으면 xlsx 는 타임스탬프만 바뀐 것이다.
# 직전 회차 사본으로 덮어 되돌린다. 지문이 하나라도 다르면 손대지 않는다.
CHANGED=1
if [ -n "$BEFORE" ] && [ "$BEFORE" = "$(snap_fingerprint)" ]; then
  CHANGED=0
  if [ -n "${SNAP:-}" ] && [ -d "$SNAP" ]; then
    restored=0
    for f in "$XLSX" "$MENU"; do
      [ -f "$SNAP/$f" ] && cp -p "$SNAP/$f" "$f" 2>/dev/null && restored=$((restored + 1))
    done
    [ "$restored" -gt 0 ] && echo "데이터 무변경 — xlsx ${restored}건 재생성 타임스탬프 diff 되돌림"
  fi
fi

# --- 5. 요약 xlsx → 구글 시트 `요약` 탭 (변경 회차에만) ---
# 무변경 회차까지 밀면 30분 주기 기준 하루 48회를 헛되이 때린다. 위 지문 판정을 그대로 쓴다.
# 자격증명 없으면 조용히 건너뛴다 — 시트 쓰기는 부가 기능이고, 없다고 파이프라인이 실패할 이유가 없다.
PUSH="$HOME/.claude/custom-plugin/tools/scripts/gsheet-push-summary.py"
TOKEN="$HOME/.claude/custom-plugin/tools/.token/gsheet.token"
if [ "$CHANGED" -eq 1 ] && [ -f "$PUSH" ] && [ -f "$TOKEN" ]; then
  if ! GOUT="$("$PY" "$PUSH" "$WBS/$MENU" 2>&1)"; then
    printf '%s\n' "$GOUT" >&2
    echo "[경고] 구글 요약 탭 푸시 실패 — 로컬 산출물은 정상이다" >&2
  else
    printf '%s\n' "$GOUT" | tail -2
  fi
elif [ "$CHANGED" -eq 0 ]; then
  echo '구글 푸시 생략 — 데이터 무변경'
fi

# --- 요약 ---
"$PY" - "$XLSX" <<'PY'
import sys, collections, openpyxl
wb = openpyxl.load_workbook(sys.argv[1])
ws = wb['WBS']
hdr = [c.value for c in ws[1]]
i_st, i_ow = hdr.index('상태'), hdr.index('담당자')
st, ow, n = collections.Counter(), collections.Counter(), 0
for r in ws.iter_rows(min_row=2, values_only=True):
    if not r[0]:
        continue
    n += 1
    st[r[i_st]] += 1
    ow[r[i_ow] or '(공란)'] += 1
join = lambda c: ' · '.join('%s %d' % (k, v) for k, v in c.most_common())
print()
print('간트 %d행' % n)
print('  상태   : %s' % join(st))
print('  담당자 : %s' % join(ow))
tot = sum(st.values())
print('  집계   : %s' % ('정합 (%d = %d)' % (n, tot) if n == tot
                        else '⚠ 불일치 — 전체 %d != 버킷 합 %d' % (n, tot)))
PY
