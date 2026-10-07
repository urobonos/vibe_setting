# -*- coding: utf-8 -*-
"""구글 시트 `소통` 탭 — B1 요청 → `claude -p` → B2 답변.

**1회 실행 = 1틱.** 주기는 이 스크립트가 정하지 않는다 — Task Scheduler·cron·
`/loop` 어느 쪽에서 몇 분 간격으로 부를지는 호출하는 쪽 몫이다.

B1 이 마지막으로 답한 요청과 같으면 시트 읽기 1회로 끝난다. 같은지는 요청
본문의 sha256 을 로컬 상태 파일과 비교해 가린다 — 시트에 표식 셀을 더 만들지
않는다. 같은 문장을 다시 묻고 싶으면 상태 파일을 지우거나 문장을 바꾼다.

실패해도 해시를 기록한다. 기록하지 않으면 매 틱 같은 요청으로 `claude -p` 를
다시 띄워 비용이 샌다. 재시도는 B1 을 고쳐 쓰면 된다.

요청은 argv 가 아니라 **stdin** 으로 넘긴다. Windows 에서 `claude` 는 `.cmd`
shim 이라 argv 가 cmd.exe 를 거치고, 요청 속 `&` `|` 가 명령으로 해석된다.
같은 shim 때문에 timeout 은 cmd.exe 만 죽이고 node 자식을 남긴다 — 트리째 끈다.

틱이 겹치면(답변이 주기보다 오래 걸리면) 같은 요청에 두 번 답한다. lock 파일로
막고, 시간 제한보다 오래된 lock 은 죽은 프로세스의 잔재로 보고 걷어낸다. lock 을
잡은 뒤 해시를 한 번 더 본다 — 앞 틱이 비교와 lock 사이에 끝났을 수 있다.

사용법:  python gsheet-chat-reply.py
"""
import os, sys, json, time, shutil, hashlib, subprocess, tempfile

import gspread
from google.oauth2.service_account import Credentials

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, 'reconfigure'):
        _s.reconfigure(encoding='utf-8', errors='replace')

KEY = os.path.expanduser('~/.claude/custom-plugin/tools/.token/gsheet.token')
DOC = '1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ'
GID = 568626710               # `소통` 탭. 탭 이름은 바뀌므로 gid 로 잡는다.
REQ, ANS = 'B1', 'B2'
TIMEOUT = 600                 # claude -p 상한(초)
CELL_MAX = 49000              # 시트 셀 상한 50000자 — 여유를 둔다
STATE_DIR = os.path.expanduser('~/.cache/gsheet-chat')
STATE = os.path.join(STATE_DIR, f'{GID}.json')
LOCK = os.path.join(STATE_DIR, f'{GID}.lock')


def worksheet():
    cred = Credentials.from_service_account_file(
        KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
    return gspread.authorize(cred).open_by_key(DOC).get_worksheet_by_id(GID)


def last_hash():
    try:
        with open(STATE, encoding='utf-8') as f:
            return json.load(f).get('hash')
    except FileNotFoundError:
        return None


def save_hash(h):
    with open(STATE, 'w', encoding='utf-8') as f:
        json.dump({'hash': h, 'at': time.strftime('%Y-%m-%d %H:%M:%S')}, f)


def acquire_lock():
    try:
        if time.time() - os.path.getmtime(LOCK) > TIMEOUT + 60:
            os.remove(LOCK)
    except FileNotFoundError:
        pass
    try:
        os.close(os.open(LOCK, os.O_CREAT | os.O_EXCL))
        return True
    except FileExistsError:
        return False


def ask_claude(prompt):
    exe = shutil.which('claude')
    if not exe:
        raise RuntimeError('claude CLI 를 PATH 에서 찾지 못했다')
    p = subprocess.Popen([exe, '-p', '--output-format', 'text'],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         text=True, encoding='utf-8', cwd=tempfile.gettempdir())
    try:
        out, err = p.communicate(prompt, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        if os.name == 'nt':
            subprocess.run(['taskkill', '/T', '/F', '/PID', str(p.pid)], capture_output=True)
        else:
            p.kill()
        p.communicate()
        raise RuntimeError(f'claude {TIMEOUT}초 초과')
    if p.returncode != 0:
        raise RuntimeError(f'claude exit {p.returncode}: {err.strip()[:500]}')
    return out.strip()


def main():
    os.makedirs(STATE_DIR, exist_ok=True)
    ws = worksheet()
    req = (ws.acell(REQ).value or '').strip()
    if not req:
        print('요청 없음')
        return
    h = hashlib.sha256(req.encode('utf-8')).hexdigest()
    if h == last_hash():
        print('무변경')
        return
    if not acquire_lock():
        print('이전 틱 진행 중 — 건너뜀')
        return
    try:
        if h == last_hash():
            print('무변경')
            return
        ws.update_acell(ANS, '답변 생성 중…')
        try:
            ans = ask_claude(req)
        except Exception as e:
            ans = f'[오류] {e}'
        ws.update_acell(ANS, ans[:CELL_MAX])
        save_hash(h)
        print(f'답변 기록 ({len(ans)}자)')
    finally:
        os.remove(LOCK)


if __name__ == '__main__':
    main()
