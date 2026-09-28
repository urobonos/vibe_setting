# -*- coding: utf-8 -*-
"""구글 시트 `개발ISS` 탭 서식 — 1회성.

`issue-sheet-sync.py` 는 값만 밀어 넣는다. gspread `clear()` 는 값만 지우고 서식은
남기므로 서식을 매 회차 다시 칠 이유가 없다 — 30분 루프에 넣으면 하루 48번 같은
서식 API 를 헛되이 때린다. 그래서 이 파일은 러너에 붙이지 않는다. 열 구성이 바뀌거나
서식이 깨졌을 때만 손으로 한 번 돌린다.

거는 것 다섯.

    헤더        요약 탭과 같은 남색(1F3864) + 흰 굵은 글씨, 1행 고정
    드롭다운    상태 3종 · 심각도 4종 — 자유 입력을 막는다
    심각도 색   Critical 빨강 · High 주황 · Medium 노랑 · Low 회색
    resolved    끝난 이슈는 글씨를 흐리게 (배경을 칠하면 심각도 색과 싸운다)
    폭·필터     제목 열을 넓게 + CLIP · 자동 필터

**드롭다운이 이 파일의 실질이다.** 간트 상태 열은 자유 입력이던 시절 오타 `CANCLED`
가 취소 75건 중 72건을 차지했고, 드롭다운으로 잠근 뒤 사라졌다 (sheet-sync.py 주석).
같은 사고를 이슈 쪽에서 되풀이하지 않으려고 미리 잠근다 — 여기서 어휘가 갈리면
`issue-sheet-sync.py` 의 `pull` 이 "알 수 없는 상태값" 으로 크게 실패한다.

사용법:  python gsheet-format-issues.py
"""
import os, sys

import gspread
from google.oauth2.service_account import Credentials

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, 'reconfigure'):
        _s.reconfigure(encoding='utf-8', errors='replace')

KEY = os.path.expanduser('~/.claude/custom-plugin/tools/.token/gsheet.token')
DOC = '1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ'
GID = 1638058386   # `ISS` 원장 탭. 이름이 아니라 gid 로 잡는다 (rename 내성)

# A=ID B=제목 C=상태 D=심각도 E=담당자 F=보고자 G=발견일 H=종결일 I=관련 태스크
NCOL = 9
WIDTH = [90, 520, 100, 90, 90, 90, 110, 110, 130]

STATES = ['pending', 'progress', 'resolved']
SEVERITY = ['Critical', 'High', 'Medium', 'Low']

# 심각도 셀 배경. 연한 톤만 쓴다 — 진하면 글씨가 죽고 resolved 흐림과 겹쳐 읽기 나빠진다.
SEV_BG = [
    ('Critical', (0.957, 0.800, 0.800)),   # F4CCCC
    ('High',     (0.988, 0.898, 0.804)),   # FCE5CD
    ('Medium',   (1.000, 0.949, 0.800)),   # FFF2CC
    ('Low',      (0.937, 0.937, 0.937)),   # EFEFEF
]
HEAD_BG = {'red': 0.122, 'green': 0.220, 'blue': 0.392}   # 1F3864 (요약 탭과 동일)


def rgb(t):
    return {'red': t[0], 'green': t[1], 'blue': t[2]}


def main():
    if not os.path.exists(KEY):
        sys.exit('[ERR] 서비스 계정 토큰 없음: %s' % KEY)
    cred = Credentials.from_service_account_file(
        KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
    sh = gspread.authorize(cred).open_by_key(DOC)
    ws = sh.get_worksheet_by_id(GID)
    sid, nrow = ws.id, ws.row_count

    # 기존 조건부 서식은 먼저 지운다 — 안 지우면 재실행마다 규칙이 쌓이고,
    # 쌓인 규칙은 먼저 등록된 것이 이겨서 나중에 건 것이 안 먹는다.
    meta = sh.fetch_sheet_metadata()
    old = 0
    for s in meta.get('sheets', []):
        if s['properties']['sheetId'] == sid:
            old = len(s.get('conditionalFormats', []))
            break

    req = [{'deleteConditionalFormatRule': {'sheetId': sid, 'index': 0}} for _ in range(old)]

    # 열 너비
    for i, w in enumerate(WIDTH):
        req.append({'updateDimensionProperties': {
            'range': {'sheetId': sid, 'dimension': 'COLUMNS', 'startIndex': i, 'endIndex': i + 1},
            'properties': {'pixelSize': w}, 'fields': 'pixelSize'}})

    # 드롭다운 (2행부터 — 1행은 헤더)
    for col, vals in ((2, STATES), (3, SEVERITY)):
        req.append({'setDataValidation': {
            'range': {'sheetId': sid, 'startRowIndex': 1, 'startColumnIndex': col,
                      'endColumnIndex': col + 1},
            'rule': {'condition': {'type': 'ONE_OF_LIST',
                                   'values': [{'userEnteredValue': v} for v in vals]},
                     'showCustomUi': True, 'strict': True}}})

    body = {'sheetId': sid, 'startRowIndex': 1, 'startColumnIndex': 0, 'endColumnIndex': NCOL}

    # resolved 행 흐리게. 글씨색만 바꾸므로 아래 심각도 배경과 겹쳐도 서로 지우지 않는다.
    req.append({'addConditionalFormatRule': {'index': 0, 'rule': {
        'ranges': [body],
        'booleanRule': {
            'condition': {'type': 'CUSTOM_FORMULA',
                          'values': [{'userEnteredValue': '=$C2="resolved"'}]},
            'format': {'textFormat': {'foregroundColor': rgb((0.60, 0.60, 0.60))}}}}}})

    # 심각도 셀 배경 (D열만)
    sev_range = {'sheetId': sid, 'startRowIndex': 1, 'startColumnIndex': 3, 'endColumnIndex': 4}
    for i, (name, color) in enumerate(SEV_BG):
        req.append({'addConditionalFormatRule': {'index': i + 1, 'rule': {
            'ranges': [sev_range],
            'booleanRule': {
                'condition': {'type': 'TEXT_EQ', 'values': [{'userEnteredValue': name}]},
                'format': {'backgroundColor': rgb(color)}}}}})

    # 제목은 잘라낸다 — 최대 335자라 WRAP 이면 행 하나가 화면을 다 먹는다.
    req.append({'repeatCell': {
        'range': {'sheetId': sid, 'startRowIndex': 1, 'startColumnIndex': 1, 'endColumnIndex': 2},
        'cell': {'userEnteredFormat': {'wrapStrategy': 'CLIP'}},
        'fields': 'userEnteredFormat.wrapStrategy'}})

    # 자동 필터 (기존 것이 있으면 갈아끼운다)
    req.append({'clearBasicFilter': {'sheetId': sid}})
    req.append({'setBasicFilter': {'filter': {'range': {
        'sheetId': sid, 'startRowIndex': 0, 'startColumnIndex': 0, 'endColumnIndex': NCOL}}}})

    sh.batch_update({'requests': req})

    # 헤더·고정은 gspread 헬퍼가 더 짧다.
    ws.format('A1:I1', {
        'backgroundColor': HEAD_BG,
        'horizontalAlignment': 'CENTER',
        'textFormat': {'bold': True, 'foregroundColor': rgb((1, 1, 1))}})
    ws.freeze(rows=1)

    print('[%s] 서식 적용 — 헤더 · 드롭다운(상태 %d · 심각도 %d) · 심각도 색 %d · resolved 흐림 · 열폭 %d · 필터'
          % (ws.title, len(STATES), len(SEVERITY), len(SEV_BG), len(WIDTH)))
    print('       기존 조건부 서식 %d건 제거 후 재등록 · 대상 %d행' % (old, nrow))


if __name__ == '__main__':
    main()
