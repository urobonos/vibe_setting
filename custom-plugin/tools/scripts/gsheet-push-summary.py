# -*- coding: utf-8 -*-
"""메뉴 요약 xlsx 의 `전체 요약` 시트 → 구글 시트 `요약` 탭.

간트 파이프라인 4단계가 만든 보고용 요약을 구글 시트로 올린다. 비개발자가 시트만 보고
진행 현황을 파악하게 하는 것이 목적이라, 값뿐 아니라 헤더 서식·진행률 서식까지 옮긴다.

xlsx 쪽은 수식이 아니라 계산된 값이라 그대로 밀어 넣으면 된다 (간트 xlsx 의 `요약` 시트는
COUNTIFS 수식이라 다르다 — 이건 build-menu-summary.py 산출물이다).

`요약` 탭 전체를 덮어쓴다. 이 탭은 파생물이고 사람이 편집하지 않는다는 전제다 —
편집분이 있으면 사라지므로 실행 전 비어 있거나 파생물인지 확인한다.

사용법:  python gsheet-push-summary.py [xlsx 경로]
"""
import io
import csv
import sys
import os
import openpyxl
import gspread
from google.oauth2.service_account import Credentials

KEY = os.path.expanduser('~/.claude/custom-plugin/tools/.token/gsheet.token')
DOC = '1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ'
TAB = '요약'
DEFAULT_XLSX = r'C:\Works\hongcafe_local_athena\docs\wbs\2026-08-12-wbs-menu-summary.xlsx'

HEAD_BG = {'red': 0.122, 'green': 0.220, 'blue': 0.392}   # 1F3864
TOTAL_BG = {'red': 0.851, 'green': 0.882, 'blue': 0.949}  # D9E1F2


def load(path):
    ws = openpyxl.load_workbook(path, data_only=True).worksheets[0]
    rows = []
    for r in ws.iter_rows(values_only=True):
        rows.append(['' if v is None else v for v in r])
    while rows and not any(str(x).strip() for x in rows[-1]):
        rows.pop()
    return ws.title, rows


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_XLSX
    if not os.path.exists(path):
        sys.exit('[ERR] xlsx 없음: %s' % path)
    title, rows = load(path)
    ncol = max(len(r) for r in rows)
    rows = [list(r) + [''] * (ncol - len(r)) for r in rows]

    cred = Credentials.from_service_account_file(KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
    sh = gspread.authorize(cred).open_by_key(DOC)
    ws = sh.worksheet(TAB)

    # --- 스냅샷 (덮어쓰기 전) ---
    # 레포 밖에 둔다 — 매 회차 생기는 운영 산출물이라 레포에 쌓이면 커밋 노이즈가 된다.
    before = ws.get_all_values()
    filled = sum(1 for r in before if any(x.strip() for x in r))
    snapdir = os.path.expanduser('~/.claude/state/gsheet-snapshots')
    os.makedirs(snapdir, exist_ok=True)
    snap = os.path.join(snapdir, 'summary-before.tsv')
    with io.open(snap, 'w', encoding='utf-8-sig', newline='') as f:
        csv.writer(f, delimiter='\t', lineterminator='\r\n').writerows(before)
    print('스냅샷 %d행(내용 %d행) → %s' % (len(before), filled, snap))

    # --- 값 밀어넣기 ---
    ws.clear()
    ws.update(rows, 'A1', value_input_option='RAW')
    print('[%s] ← %r %d행 x %d열' % (TAB, title, len(rows), ncol))

    # --- 서식: 헤더행(4) · 합계행(마지막) · 진행률 퍼센트 · 소요 소수1 ---
    hdr_i = next((i for i, r in enumerate(rows) if str(r[0]).strip() == '단계'), 3)
    tot_i = len(rows) - 1
    pct_c = next((j for j, v in enumerate(rows[hdr_i]) if str(v).strip() == '진행률'), None)
    hrs_c = next((j for j, v in enumerate(rows[hdr_i]) if str(v).strip().startswith('소요')), None)
    sid = ws.id
    reqs = [
        {'repeatCell': {
            'range': {'sheetId': sid, 'startRowIndex': hdr_i, 'endRowIndex': hdr_i + 1,
                      'startColumnIndex': 0, 'endColumnIndex': ncol},
            'cell': {'userEnteredFormat': {
                'backgroundColor': HEAD_BG,
                'textFormat': {'bold': True, 'foregroundColor': {'red': 1, 'green': 1, 'blue': 1}},
                'horizontalAlignment': 'CENTER'}},
            'fields': 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)'}},
        {'repeatCell': {
            'range': {'sheetId': sid, 'startRowIndex': tot_i, 'endRowIndex': tot_i + 1,
                      'startColumnIndex': 0, 'endColumnIndex': ncol},
            'cell': {'userEnteredFormat': {'backgroundColor': TOTAL_BG,
                                           'textFormat': {'bold': True}}},
            'fields': 'userEnteredFormat(backgroundColor,textFormat)'}},
        {'updateSheetProperties': {
            'properties': {'sheetId': sid, 'gridProperties': {'frozenRowCount': hdr_i + 1}},
            'fields': 'gridProperties.frozenRowCount'}},
    ]
    if pct_c is not None:
        reqs.append({'repeatCell': {
            'range': {'sheetId': sid, 'startRowIndex': hdr_i + 1, 'endRowIndex': len(rows),
                      'startColumnIndex': pct_c, 'endColumnIndex': pct_c + 1},
            'cell': {'userEnteredFormat': {'numberFormat': {'type': 'PERCENT', 'pattern': '0.0%'}}},
            'fields': 'userEnteredFormat.numberFormat'}})
    if hrs_c is not None:
        reqs.append({'repeatCell': {
            'range': {'sheetId': sid, 'startRowIndex': hdr_i + 1, 'endRowIndex': len(rows),
                      'startColumnIndex': hrs_c, 'endColumnIndex': hrs_c + 1},
            'cell': {'userEnteredFormat': {'numberFormat': {'type': 'NUMBER', 'pattern': '0.0'}}},
            'fields': 'userEnteredFormat.numberFormat'}})
    sh.batch_update({'requests': reqs})
    print('서식 적용 — 헤더 행%d · 합계 행%d · 진행률 %s · 소요 %s' % (
        hdr_i + 1, tot_i + 1,
        chr(ord('A') + pct_c) if pct_c is not None else '-',
        chr(ord('A') + hrs_c) if hrs_c is not None else '-'))


if __name__ == '__main__':
    main()
