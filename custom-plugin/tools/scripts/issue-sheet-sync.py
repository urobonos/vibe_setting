# -*- coding: utf-8 -*-
"""이슈 파일 → 구글 시트 `ISS` 원장 탭 동기화. 문서가 정본이고 시트는 거울이다.

열별 SSOT — 상태를 포함해 **전 열이 이슈 문서**다.

    이슈 정의(제목·심각도·발견일·보고자·관련 태스크)   issue/**/*.md frontmatter
    상태                                              issue/<폴더>/ — `폴더가 곧 상태` (issue/README.md)

2026-09-14 까지는 상태만 시트가 정본이었다. pull 이 시트 값으로 frontmatter 를 고치고
`git mv` 했고, push 는 기존 행의 상태 열을 보존했다 — 그래서 문서에서 종결한 이슈가 시트에
끝내 안 올라가고, 다음 회차 pull 이 파일을 낡은 시트 상태로 되돌렸다(실측 resolved 156 → 129).
사용자 확인으로 원본이 문서로 정해져(레포 `806af87b`) 방향을 뒤집었다.

    push  레포 → 시트   전 열(상태 포함)을 문서 기준으로 덮어쓴다
    pull  시트 → 보고   시트 상태 ≠ 문서 상태인 건만 센다 — 파일은 안 건드린다

폴더와 frontmatter `상태` 가 다르면 어느 쪽을 올릴지 정할 수 없으므로 크게 실패한다.
README 의 "하나만 바꾸면 그때부터 이 디렉토리는 믿을 수 없다" 를 여기서 강제한다.

상태 어휘는 폴더명 3종이 그대로다 (pending·progress·resolved). 간트처럼 대문자
드롭다운을 따로 두지 않는다 — 폴더명과 어휘가 1:1 이면 매핑 테이블이 필요 없고,
매핑이 없으면 갈릴 것도 없다. 실측 238건이 전부 이 3종이었다 (2026-09-02).

탭은 이름이 아니라 **gid** 로 잡는다. 2026-09-02 하루에 탭 이름이 세 번 바뀌었고
(`요약`→`WBS요약`→`요약`, `개발ISS`→`ISS`), 이름으로 잡은 스크립트만 그때마다 깨졌다.
gid 는 탭 생성 시 고정되고 rename·순서 변경에 불변이다.

**하니스에 둔 이유** (2026-09-02 이전, 레포 `docs/wbs/tools/` 에 있었다): 구글 연동
스크립트(`gsheet-*.py`)가 전부 여기 있고, 레포 쪽은 순수 생성기가 산다. 레포 소스는
worktree 안에서만 고칠 수 있어(CLAUDE.md §4.3) 시트 스키마가 바뀔 때마다 분기를
파야 했다 — 시트 쪽 변경 빈도를 생각하면 그 마찰이 값보다 컸다.

사용법:  python issue-sheet-sync.py [push|pull|both] [레포경로]
"""
import io, os, re, csv, sys, glob
from urllib.request import urlopen
from urllib.error import HTTPError, URLError

import gspread
from google.oauth2.service_account import Credentials

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, 'reconfigure'):
        _s.reconfigure(encoding='utf-8', errors='replace')

SHEET_ID = '1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ'
GID = 1638058386          # `ISS` 원장 탭. 이름이 아니라 gid (rename 내성)
URL = ('https://docs.google.com/spreadsheets/d/%s/export?format=csv&gid=%d'
       % (SHEET_ID, GID))
KEY = os.path.expanduser('~/.claude/custom-plugin/tools/.token/gsheet.token')
DEFAULT_REPO = r'C:\Works\hongcafe_local_athena'

REL = os.path.join('docs', 'wbs', 'issue')
STATES = ('pending', 'progress', 'resolved')

# 시트 열. `상태` 를 포함해 전부 레포가 정본이다 — 시트는 받아 적기만 한다.
HDR = ['ID', '제목', '상태', '심각도', '담당자', '보고자', '발견일', '종결일', '관련 태스크']
FM_KEY = {'ID': '이슈', '제목': '제목', '상태': '상태', '심각도': '심각도',
          '담당자': '담당자', '보고자': '보고자', '발견일': '발견일',
          '종결일': '종결일', '관련 태스크': '관련 태스크'}

ISS_RE = re.compile(r'^ISS-\d{3}$')


def fm_value(line):
    """`키: 값  # 주석` → 값. 템플릿 주석이 값에 붙어 있다 (실측 238건 중 132건)."""
    return line.split(':', 1)[1].split('#')[0].strip()


def scan(repo):
    """issue/**/*.md → {ID: {열: 값, '_rel': 레포기준 경로, '_dir': 폴더}}."""
    out, mismatch = {}, []
    for d in STATES:
        for path in sorted(glob.glob(os.path.join(repo, REL, d, '*.md'))):
            rec = {}
            with io.open(path, encoding='utf-8') as f:
                for line in f:
                    if line.rstrip('\n') == '---' and rec:
                        break
                    for col, key in FM_KEY.items():
                        if line.startswith(key + ':'):
                            rec[col] = fm_value(line)
                            break
            tid = rec.get('ID', '')
            if not ISS_RE.match(tid):
                sys.exit('[ERR] 이슈 번호가 없거나 형식이 아니다: %s (읽은 값 %r)' % (path, tid))
            if tid in out:
                sys.exit('[ERR] 이슈 번호 중복: %s\n      %s\n      %s'
                         % (tid, out[tid]['_rel'], os.path.relpath(path, repo)))
            rec['_abs'] = path
            rec['_rel'] = os.path.relpath(path, repo).replace('\\', '/')
            rec['_dir'] = d
            if rec.get('상태', '') != d:
                mismatch.append('%s (폴더 %s · 상태 %s)' % (tid, d, rec.get('상태') or '(빈칸)'))
            out[tid] = rec
    if not out:
        sys.exit('[ERR] 이슈를 한 건도 못 읽었다 — 경로 확인: %s' % os.path.join(repo, REL))
    # 전건을 모아 한 번에 낸다 — 첫 건에서 멈추면 고칠 때마다 다음 건이 나와 형제가 남는다.
    if mismatch:
        sys.exit('[ERR] 폴더와 frontmatter 상태가 다르다 %d건 — 어느 쪽을 올릴지 정할 수 없다. 둘을 맞춘 뒤 다시 돌려라\n      %s'
                 % (len(mismatch), '\n      '.join(mismatch[:8])))
    return out


def fetch_sheet():
    """시트 → {ID: 상태}. 빈 탭이면 {} (첫 회차)."""
    try:
        body = urlopen(URL, timeout=20).read().decode('utf-8-sig')
    except HTTPError as e:
        sys.exit('[ERR] 시트 HTTP %d — 공유가 "링크가 있는 모든 사용자 · 뷰어" 인지 확인해라\n      %s'
                 % (e.code, URL))
    except URLError as e:
        sys.exit('[ERR] 시트 접속 실패: %s' % e.reason)
    if body.lstrip()[:9].lower() == '<!doctype':
        sys.exit('[ERR] CSV 대신 로그인 HTML 이 왔다 — 비공개 시트다. 공유 설정을 확인해라')
    rows = list(csv.DictReader(io.StringIO(body)))
    if not rows:
        return {}
    if 'ID' not in rows[0] or '상태' not in rows[0]:
        sys.exit('[ERR] 시트 헤더 누락: ID·상태 (실제 헤더: %s)' % ', '.join(rows[0].keys()))
    return {(r.get('ID') or '').strip(): (r.get('상태') or '').strip()
            for r in rows if (r.get('ID') or '').strip()}


def open_tab():
    if not os.path.exists(KEY):
        sys.exit('[ERR] 서비스 계정 토큰 없음: %s' % KEY)
    cred = Credentials.from_service_account_file(
        KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
    return gspread.authorize(cred).open_by_key(SHEET_ID).get_worksheet_by_id(GID)


def push(issues, sheet):
    """레포 → 시트. 상태를 포함해 전 열을 문서 기준으로 덮어쓴다."""
    ws = open_tab()
    body = [HDR] + [[issues[t]['_dir'] if c == '상태' else issues[t].get(c, '')
                     for c in HDR]
                    for t in sorted(issues, key=lambda x: int(x[4:]))]
    ws.clear()
    ws.update(body, 'A1', value_input_option='RAW')
    new = [t for t in issues if t not in sheet]
    changed = [t for t in issues if t in sheet and sheet[t] != issues[t]['_dir']]
    print('[%s] ← 이슈 %d건 (신규 %d · 상태 갱신 %d)'
          % (ws.title, len(issues), len(new), len(changed)))
    return new


def pull(issues, sheet):
    """시트 → 보고만. 시트 상태가 문서와 다른 건을 센다 — 파일은 건드리지 않는다.

    뒤따르는 push 가 문서 상태로 덮어쓰므로 여기서 고칠 것은 없다. 굳이 세는 이유는
    누군가 시트에서 직접 상태를 바꿨다면 그 입력이 이번 회차에 사라진다는 걸 남기기 위해서다.
    """
    drift, ghost = [], []
    for tid, have in sheet.items():
        if tid not in issues:
            ghost.append(tid)
        elif have != issues[tid]['_dir']:
            drift.append((tid, have, issues[tid]['_dir']))
    if ghost:
        print('[경고] 시트에만 있는 ID %d건 — 파일이 없다: %s'
              % (len(ghost), ', '.join(sorted(ghost)[:8])), file=sys.stderr)
    for tid, have, want in drift[:8]:
        print('  %s  시트 %s ≠ 문서 %s' % (tid, have or '(빈칸)', want))
    print('시트↔문서 상태 불일치 %d건 (문서 기준으로 덮어쓴다)' % len(drift))
    return drift


def main():
    args = [a for a in sys.argv[1:]]
    mode = 'both'
    if args and args[0].lower() in ('push', 'pull', 'both'):
        mode = args.pop(0).lower()
    repo = args[0] if args else DEFAULT_REPO
    if not os.path.isdir(os.path.join(repo, REL)):
        sys.exit('[ERR] 이슈 디렉토리 없음: %s' % os.path.join(repo, REL))

    issues = scan(repo)
    sheet = fetch_sheet()
    print('이슈 %d건 (pending %d · progress %d · resolved %d) · 시트 %d행'
          % (len(issues),
             sum(1 for r in issues.values() if r['_dir'] == 'pending'),
             sum(1 for r in issues.values() if r['_dir'] == 'progress'),
             sum(1 for r in issues.values() if r['_dir'] == 'resolved'),
             len(sheet)))

    # 차이 보고가 먼저다 — push 가 시트를 덮어쓰고 나면 무엇이 달랐는지 더는 안 보인다.
    if mode in ('pull', 'both') and sheet:
        pull(issues, sheet)
    if mode in ('push', 'both'):
        push(issues, sheet)


if __name__ == '__main__':
    main()
