# -*- coding: utf-8 -*-
"""구글 시트 `채팅` 탭 — B1 요청을 꺼내고, 답변을 B2 에 쓴다.

답변은 이 스크립트가 만들지 않는다. **대화 중인 Claude 세션이 자기 맥락 그대로**
답한다 — 새로 뜬 헤드리스 세션은 지금 하던 작업을 몰라 "무엇이 잘됐는지 근거가
없다" 같은 답을 낸다. 그래서 스크립트는 시트 입출력만 맡는다.

    peek          B1 이 마지막으로 답한 요청과 다르면 본문을 출력, 같으면 아무것도 안 낸다
    reply <파일>  파일 내용을 B2 에 쓰고 그 시점의 B1 을 답한 요청으로 기록한다

같은지는 요청 본문의 sha256 을 로컬 상태 파일과 비교해 가린다 — 시트에 표식 셀을
더 만들지 않는다. 답변은 argv 가 아니라 파일로 받는다 — 여러 줄·따옴표가 셸을
거치며 깨지지 않게.

사용법:  python gsheet-chat-reply.py peek
         python gsheet-chat-reply.py reply answer.txt
"""
import os, sys, json, time, hashlib

import gspread
from google.oauth2.service_account import Credentials

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, 'reconfigure'):
        _s.reconfigure(encoding='utf-8', errors='replace')

KEY = os.path.expanduser('~/.claude/custom-plugin/tools/.token/gsheet.token')
DOC = '1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ'
GID = 568626710               # `채팅` 탭. 탭 이름은 바뀌므로 gid 로 잡는다.
REQ, ANS = 'B1', 'B2'
CELL_MAX = 49000              # 시트 셀 상한 50000자 — 여유를 둔다
STATE_DIR = os.path.expanduser('~/.cache/gsheet-chat')
STATE = os.path.join(STATE_DIR, f'{GID}.json')


def worksheet():
    cred = Credentials.from_service_account_file(
        KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
    return gspread.authorize(cred).open_by_key(DOC).get_worksheet_by_id(GID)


def request_of(ws):
    return (ws.acell(REQ).value or '').strip()


def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def last_hash():
    try:
        with open(STATE, encoding='utf-8') as f:
            return json.load(f).get('hash')
    except FileNotFoundError:
        return None


def save_hash(h):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE, 'w', encoding='utf-8') as f:
        json.dump({'hash': h, 'at': time.strftime('%Y-%m-%d %H:%M:%S')}, f)


def peek():
    req = request_of(worksheet())
    if req and digest(req) != last_hash():
        print(req)


def reply(path):
    with open(path, encoding='utf-8') as f:
        ans = f.read().strip()
    ws = worksheet()
    ws.update_acell(ANS, ans[:CELL_MAX])
    save_hash(digest(request_of(ws)))
    print(f'답변 기록 ({len(ans)}자)')


if __name__ == '__main__':
    if sys.argv[1:2] == ['peek']:
        peek()
    elif sys.argv[1:2] == ['reply'] and len(sys.argv) == 3:
        reply(sys.argv[2])
    else:
        sys.exit(__doc__)
