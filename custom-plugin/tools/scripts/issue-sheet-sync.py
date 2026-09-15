# -*- coding: utf-8 -*-
"""이슈 파일 ↔ 구글 시트 `ISS` 원장 탭 양방향 동기화.

열별 SSOT — 간트(`docs/wbs/tools/sheet-sync.py`)와 같은 경계를 쓴다.

    이슈 정의(제목·심각도·발견일·보고자·관련 태스크)   issue/**/*.md frontmatter
    상태                                              구글 시트
    폴더 위치(pending/progress/resolved)              **파생물** — 시트 상태가 정한다

`폴더가 곧 상태` (issue/README.md) 는 그대로 유지된다. 달라지는 건 그 상태를 누가
정하느냐 하나다 — 전에는 사람이 파일을 옮겼고, 이제 시트에서 내리면 여기가 옮긴다.
frontmatter `상태` 와 폴더를 **항상 같이** 바꾸므로 README 의 "하나만 바꾸면 그때부터
이 디렉토리는 믿을 수 없다" 는 경고가 그대로 지켜진다.

방향이 둘로 갈린다 — 섞으면 서로 덮어쓴다.

    push  레포 → 시트   신규 이슈 append + 기존 행의 **정의 열만** 갱신 (상태 열은 안 건드린다)
    pull  시트 → 레포   시트 상태 ≠ 파일 상태면 frontmatter 갱신 + `git mv`

상태 어휘는 폴더명 3종이 그대로다 (pending·progress·resolved). 간트처럼 대문자
드롭다운을 따로 두지 않는다 — 폴더명과 어휘가 1:1 이면 매핑 테이블이 필요 없고,
매핑이 없으면 갈릴 것도 없다. 실측 238건이 전부 이 3종이었다 (2026-09-02).

탭은 이름이 아니라 **gid** 로 잡는다. 2026-09-02 하루에 탭 이름이 세 번 바뀌었고
(`요약`→`WBS요약`→`요약`, `개발ISS`→`ISS`), 이름으로 잡은 스크립트만 그때마다 깨졌다.
gid 는 탭 생성 시 고정되고 rename·순서 변경에 불변이다.

`git mv` 만 하고 커밋은 하지 않는다 — 무엇이 옮겨졌는지 사람이 보고 커밋한다.

**하니스에 둔 이유** (2026-09-02 이전, 레포 `docs/wbs/tools/` 에 있었다): 구글 연동
스크립트(`gsheet-*.py`)가 전부 여기 있고, 레포 쪽은 순수 생성기가 산다. 레포 소스는
worktree 안에서만 고칠 수 있어(CLAUDE.md §4.3) 시트 스키마가 바뀔 때마다 분기를
파야 했다 — 시트 쪽 변경 빈도를 생각하면 그 마찰이 값보다 컸다.

사용법:  python issue-sheet-sync.py [push|pull|both] [레포경로]
"""
import io, os, re, csv, sys, glob, subprocess
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

# 시트 열. `상태` 만 시트가 정본이고 나머지는 전부 레포가 정본이다.
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
    out = {}
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
            out[tid] = rec
    if not out:
        sys.exit('[ERR] 이슈를 한 건도 못 읽었다 — 경로 확인: %s' % os.path.join(repo, REL))
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
    """레포 → 시트. 신규는 append, 기존은 정의 열만 갱신 — 상태 열은 절대 안 건드린다."""
    ws = open_tab()
    body = [HDR] + [[issues[t].get(c, '') if c != '상태'
                     else (sheet.get(t) or issues[t].get('상태', ''))
                     for c in HDR]
                    for t in sorted(issues, key=lambda x: int(x[4:]))]
    ws.clear()
    ws.update(body, 'A1', value_input_option='RAW')
    new = [t for t in issues if t not in sheet]
    print('[%s] ← 이슈 %d건 (신규 %d · 기존 상태 보존 %d)'
          % (ws.title, len(issues), len(new), len(issues) - len(new)))
    return new


def move(repo, rec, target):
    """frontmatter `상태` 갱신 + `git mv`. 둘을 같이 해야 폴더가 정본으로 남는다."""
    with io.open(rec['_abs'], encoding='utf-8', newline='') as f:
        text = f.read()
    # 값만 바꾸고 뒤 주석은 그대로 둔다 — 템플릿 안내라 지울 이유가 없다.
    new_text, n = re.subn(r'(?m)^(상태: *)([a-z]+)', r'\g<1>' + target, text, count=1)
    if n != 1:
        sys.exit('[ERR] 상태 줄을 못 찾았다: %s' % rec['_rel'])
    with io.open(rec['_abs'], 'w', encoding='utf-8', newline='') as f:
        f.write(new_text)
    dest = '%s/%s/%s' % (REL.replace('\\', '/'), target, os.path.basename(rec['_rel']))
    r = subprocess.run(['git', 'mv', rec['_rel'], dest],
                       cwd=repo, capture_output=True, text=True)
    if r.returncode:
        sys.exit('[ERR] git mv 실패: %s → %s\n      %s' % (rec['_rel'], dest, r.stderr.strip()))
    return dest


def pull(repo, issues, sheet):
    """시트 → 레포. 시트 상태가 파일과 다르면 옮긴다."""
    moved, unknown, ghost = [], [], []
    for tid, want in sheet.items():
        if tid not in issues:
            ghost.append(tid)
            continue
        if want not in STATES:
            unknown.append((tid, want))
            continue
        rec = issues[tid]
        if want != rec['_dir']:
            moved.append((tid, rec['_dir'], want, move(repo, rec, want)))
    if unknown:
        sys.exit('[ERR] 알 수 없는 상태값 %d건 — 시트를 고쳐라 (허용: %s)\n      %s'
                 % (len(unknown), ' · '.join(STATES),
                    ', '.join('%s=%r' % u for u in unknown[:8])))
    if ghost:
        print('[경고] 시트에만 있는 ID %d건 — 파일이 없다: %s'
              % (len(ghost), ', '.join(sorted(ghost)[:8])), file=sys.stderr)
    for tid, src, dst, path in moved:
        print('  %s  %s → %s' % (tid, src, dst))
    print('폴더 이동 %d건 (git mv 만 — 커밋은 사람이 한다)' % len(moved))
    return moved


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

    # pull 이 먼저다 — 시트에서 내린 상태를 파일에 반영한 뒤 그 결과를 올려야
    # push 가 방금 읽은 낡은 상태로 되돌리지 않는다.
    if mode in ('pull', 'both') and sheet:
        pull(repo, issues, sheet)
        issues = scan(repo)
    if mode in ('push', 'both'):
        push(issues, sheet)


if __name__ == '__main__':
    main()
