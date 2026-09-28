# -*- coding: utf-8 -*-
"""간트 tsv 에만 있고 구글 시트 `WBS` 탭에 없는 태스크를 append.

**왜 필요한가.** WBS 는 이슈와 배선이 다르다 — `sheet-sync.py` 는 시트를 **읽기만**
하므로, `phases/*.md` 에 태스크가 새로 채번돼도 시트에는 행이 생기지 않는다. 행이
없으면 덮을 상태·담당자가 없어 그 태스크는 간트에서 영영 `Pending` · 담당자 공란으로
남는다 (2026-09-03 실측: `JPA-07-148`~`150` 금칙어 관리 3건이 이 상태였다).

**상태·담당자 열은 시트가 정본이다.** 그래서 여기서는 **신규 행만 append** 하고
기존 행은 손대지 않는다 — 기존 행을 갱신하면 사람이 시트에서 내린 상태를 되돌린다.
신규 행의 상태·담당자는 `phases/*.md` 값(대개 `Pending` · 공란)으로 시작하고,
그 뒤로는 시트가 정본이 된다.

러너에 붙이지 않는다. 태스크 채번은 드물고(주 단위), 매 회차 570행을 대조하느니
채번한 사람이 한 번 돌리는 편이 낫다. 무엇이 등재되는지 눈으로 보고 넘기는 값도 있다.

사용법:  python gsheet-push-wbs-new.py [레포경로] [--dry]
"""
import io, os, csv, sys

import gspread
from google.oauth2.service_account import Credentials

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, 'reconfigure'):
        _s.reconfigure(encoding='utf-8', errors='replace')

KEY = os.path.expanduser('~/.claude/custom-plugin/tools/.token/gsheet.token')
DOC = '1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ'
GID = 0                     # `WBS` 원장 탭. 이름이 아니라 gid (rename 내성)
DEFAULT_REPO = r'C:\Works\hongcafe_local_athena'
TSV = os.path.join('docs', 'wbs', '2026-08-11-wbs-gantt.tsv')


# 시트 상태 열은 드롭다운으로 잠겨 있다 (대문자 4종). `phases/*.md` 는 `Pending` 처럼
# 섞어 쓰므로 그대로 넣으면 목록 밖 값이 되어 셀에 경고가 뜬다 — 넣는 쪽에서 맞춘다.
def norm(col, val):
    return val.strip().upper().replace(' ', '') if col == '상태' else val


def load_tsv(repo):
    """간트 tsv → [{열: 값}]. 1행은 엑셀용 `sep=` 지시자라 건너뛴다."""
    path = os.path.join(repo, TSV)
    if not os.path.exists(path):
        sys.exit('[ERR] 간트 tsv 없음: %s' % path)
    with io.open(path, encoding='utf-8-sig') as f:
        first = f.readline()
        if not first.startswith('sep='):
            f.seek(0)
        rows = list(csv.DictReader(f, delimiter='\t'))
    if not rows:
        sys.exit('[ERR] 간트 tsv 가 비었다 — 먼저 wbs-sheet-sync.sh 를 돌려라')
    return rows


def main():
    args = [a for a in sys.argv[1:]]
    dry = '--dry' in args
    args = [a for a in args if a != '--dry']
    repo = args[0] if args else DEFAULT_REPO

    rows = load_tsv(repo)

    if not os.path.exists(KEY):
        sys.exit('[ERR] 서비스 계정 토큰 없음: %s' % KEY)
    cred = Credentials.from_service_account_file(
        KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
    ws = gspread.authorize(cred).open_by_key(DOC).get_worksheet_by_id(GID)

    vals = ws.get_all_values()
    if not vals:
        sys.exit('[ERR] 시트가 비었다 — gid=%d 가 맞는지 확인해라' % GID)
    hdr = vals[0]
    if 'ID' not in hdr:
        sys.exit('[ERR] 시트 헤더에 ID 가 없다 (실제: %s)' % ' | '.join(hdr))
    i_id = hdr.index('ID')
    have = set(r[i_id].strip() for r in vals[1:] if len(r) > i_id and r[i_id].strip())

    # 열은 **이름으로** 맞춘다 — 시트(Phase·ID…)와 tsv(ID·Phase…)는 순서가 다르다.
    new = [r for r in rows if (r.get('ID') or '').strip() and (r.get('ID') or '').strip() not in have]
    if not new:
        print('[%s] 신규 없음 — 시트 %d행 · tsv %d건' % (ws.title, len(have), len(rows)))
        return

    body = [[norm(c, r.get(c) or '') for c in hdr] for r in new]
    print('[%s] 신규 %d건 (시트 %d행 · tsv %d건)' % (ws.title, len(new), len(have), len(rows)))

    # 삽입 위치 — ID 오름차순 자리를 찾는다. 맨 끝 append 는 안 된다:
    # 시트는 ID 순으로 읽는 원장이라 JPA-07 이 JPA-11 뒤에 붙으면 사람이 못 찾는다
    # (2026-09-03 실측 — 그렇게 붙였다가 되돌렸다).
    plan = []
    for r in new:
        tid = (r.get('ID') or '').strip()
        prev = [n for n, v in enumerate(vals[1:], start=2)
                if len(v) > i_id and v[i_id].strip() and v[i_id].strip() < tid]
        plan.append((tid, (max(prev) if prev else 1) + 1))
    for (tid, at), r in zip(plan, new):
        print('  %-12s → %d행  %s · %s' % (tid, at, r.get('메뉴·영역') or r.get('Phase명'),
                                          r.get('작업단계') or ''))
    if dry:
        print('  (--dry — 쓰지 않았다)')
        return

    # 연속 블록이면 한 번에 넣는다. `inheritFromBefore` 로 위 행 서식을 그대로 물려받는다.
    at = plan[0][1]
    ncol = len(hdr)
    ws.spreadsheet.batch_update({'requests': [{'insertDimension': {
        'range': {'sheetId': ws.id, 'dimension': 'ROWS',
                  'startIndex': at - 1, 'endIndex': at - 1 + len(body)},
        'inheritFromBefore': True}}]})
    ws.update(body, 'A%d:%s%d' % (at, chr(ord('A') + ncol - 1), at + len(body) - 1),
              value_input_option='RAW')
    print('  %d~%d행 삽입 완료 — 상태·담당자는 이제 시트가 정본이다'
          % (at, at + len(body) - 1))


if __name__ == '__main__':
    main()
