# -*- coding: utf-8 -*-
"""이슈 파일 → 구글 시트 `요약` 탭 **하단**.

`개발ISS` 탭이 238행 원장이라면 여기는 그걸 읽는 사람이 먼저 보는 한 화면이다.
비개발자가 시트만 열어도 "지금 뭐가 얼마나 밀려 있나" 를 알 수 있게 만든다.

**탭을 따로 두지 않고 WBS 요약 아래에 이어 붙인다** (2026-09-02, 사용자 판단).
읽는 사람이 같은데 탭을 오가야 하는 것이 비용이고, 진척(WBS)과 리스크(ISS)는
같은 화면에서 볼 때 의미가 산다.

이어 붙이려면 시작 행을 알아야 하는데 **행 번호를 박지 않는다** — WBS 요약은
단계가 늘면 길어지고, 그때마다 이 블록이 위 표를 덮어쓴다. 대신 `개발 이슈 요약`
마커 행을 찾고, 없으면(첫 회차 또는 5단계의 `clear()` 직후) 마지막 데이터 행 + 2
에서 시작한다.

같은 탭을 5단계(`gsheet-push-summary.py`)와 나눠 쓰므로 **순서가 계약이다** —
러너가 5 → 7 로 부른다. 5단계는 변경 회차에만 돌면서 탭을 `clear()` 하고, 그
회차에는 7단계가 뒤따라 다시 쓴다. 무변경 회차에는 `clear()` 가 없으니 7단계가
자기 블록만 갱신한다. 어느 쪽이든 이 블록은 매 회차 정확해진다.

열 폭은 건드리지 않는다 — 위 WBS 표가 13열 폭을 이미 잡고 있어서 여기서 다시
걸면 그 표가 망가진다.

블록 둘.

    심각도 × 상태   교차표 + 미해결률 — **이 표가 본체다**
    최근 등재       발견일 내림차순 8건

담당자별 집계는 뺐다 (2026-09-02, 사용자 지시). frontmatter `담당자` 값이 `재영` ·
`jypark` · `JY Park` · `미확인` · `미정 — JPA-01-17(상미) 소관` 처럼 19종으로 갈려
있어, 세면 같은 사람이 여러 줄로 흩어진다. 이름 표기를 먼저 정리하지 않으면
집계 자체가 사실을 왜곡한다.

미해결률을 굳이 넣는 이유는 총량이 판단을 흐리기 때문이다. Low 가 100건 쌓여도
Critical 3건이 안 닫힌 쪽이 급하다 — 심각도 축과 진행 축을 한 표에서 같이 봐야
그 역전이 보인다.

원장(`개발ISS`)과 달리 이 탭은 **완전한 파생물**이라 매 회차 통째로 덮어쓴다.
사람이 여기 뭘 적으면 다음 회차에 사라진다.

집계 대상은 시트가 아니라 **이슈 파일**이다 — 시트를 읽으면 `issue-sheet-sync.py`
의 push 가 끝나기 전 낡은 값을 집계할 수 있다. 파일은 그 순서에 영향받지 않는다.

사용법:  python gsheet-push-issue-summary.py [레포경로]
"""
import io, os, re, sys, glob, collections
from datetime import datetime

import gspread
from google.oauth2.service_account import Credentials

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, 'reconfigure'):
        _s.reconfigure(encoding='utf-8', errors='replace')

KEY = os.path.expanduser('~/.claude/custom-plugin/tools/.token/gsheet.token')
DOC = '1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ'
GID = 58416954                # `요약` 탭. 이름이 아니라 gid 로 잡는다 — 2026-09-02 하루에 탭 이름이 세 번 바뀌었다.
MARKER = '개발 이슈 요약'     # 이 블록의 시작 표식. 바꾸면 매 회차 아래로 쌓인다.
WIPE = 40                     # 재작성 전 비울 행수 — 블록이 짧아졌을 때 잔재를 남기지 않는다.
DEFAULT_REPO = r'C:\Works\hongcafe_local_athena'

STATES = ['pending', 'progress', 'resolved']

# 폴더명 → 화면 표기. 폴더는 규약(`issue/README.md` "폴더가 곧 상태")이라 못 바꾸고,
# 시트만 사람 말로 낸다. `issue-sheet-sync.py` 의 `ISS` 원장은 폴더명 그대로 쓴다 —
# 그쪽은 드롭다운이 폴더명과 1:1 이어야 pull 이 도로 파일을 옮길 수 있기 때문이다.
LABEL = {'pending': '대기', 'progress': '진행중', 'resolved': '완료'}
SEVERITY = ['Critical', 'High', 'Medium', 'Low']   # 급한 순 — 정렬이 곧 읽는 순서다
NCOL = 7

HEAD_BG = {'red': 0.122, 'green': 0.220, 'blue': 0.392}   # 1F3864 (WBS요약과 동일)
SUB_BG = {'red': 0.851, 'green': 0.882, 'blue': 0.949}    # D9E1F2
WHITE = {'red': 1, 'green': 1, 'blue': 1}

KEYS = ('이슈', '제목', '상태', '심각도', '담당자', '보고자', '발견일')


def scan(repo):
    """issue/**/*.md → frontmatter dict 목록. 값의 템플릿 주석(`# ...`)을 잘라낸다."""
    out = []
    for d in STATES:
        for path in glob.glob(os.path.join(repo, 'docs', 'wbs', 'issue', d, '*.md')):
            rec = {'_dir': d}
            with io.open(path, encoding='utf-8') as f:
                for line in f:
                    if line.rstrip('\n') == '---' and len(rec) > 1:
                        break
                    for k in KEYS:
                        if line.startswith(k + ':'):
                            rec[k] = line.split(':', 1)[1].split('#')[0].strip()
                            break
            if rec.get('이슈'):
                out.append(rec)
    if not out:
        sys.exit('[ERR] 이슈를 한 건도 못 읽었다 — 경로 확인: %s' % repo)
    return out


def build(recs):
    now = datetime.now().strftime('%Y-%m-%d %H:%M')
    rows = [['개발 이슈 요약', '', '', '', '', '', now]]
    rows.append([''] * NCOL)

    # --- 심각도 × 상태 ---
    # 폴더명(pending/progress/resolved)이 아니라 사람이 읽는 말로 낸다 — 이 표를 보는 쪽은
    # 비개발자다. `완료` 와 `해결` 은 같은 값이라 열을 둘로 나누지 않고, 대신 그 여집합인
    # `미해결` 을 남겨 두 축이 서로를 검산하게 한다 (전체 = 완료 + 미해결).
    rows.append(['심각도', '전체', '대기', '진행중', '완료', '미해결', '해결률'])
    cnt = collections.Counter((r.get('심각도', ''), r['_dir']) for r in recs)
    seen = set(r.get('심각도', '') for r in recs)
    order = SEVERITY + sorted(seen - set(SEVERITY) - {''})   # 목록 밖 값도 빠뜨리지 않는다
    tot = [0] * 4
    for sev in order:
        c = [cnt[(sev, s)] for s in STATES]
        n = sum(c)
        if not n:
            continue
        open_ = c[0] + c[1]
        rows.append([sev, n] + c + [open_, '%.0f%%' % (100.0 * c[2] / n)])
        tot = [tot[0] + n] + [tot[i + 1] + c[i] for i in range(3)]
    all_open = tot[1] + tot[2]
    rows.append(['합계', tot[0], tot[1], tot[2], tot[3], all_open,
                 '%.0f%%' % (100.0 * tot[3] / tot[0]) if tot[0] else '0%'])
    rows.append([''] * NCOL)

    # --- 최근 등재 ---
    rows.append(['최근 등재', '심각도', '상태', '담당자', '제목', '', ''])
    for r in sorted(recs, key=lambda x: x.get('발견일', ''), reverse=True)[:8]:
        title = r.get('제목', '')
        rows.append([r['이슈'], r.get('심각도', ''), LABEL.get(r['_dir'], r['_dir']), r.get('담당자', ''),
                     title[:70] + ('…' if len(title) > 70 else ''), '', ''])

    return [list(r) + [''] * (NCOL - len(r)) for r in rows]


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPO
    recs = scan(repo)
    rows = build(recs)

    if not os.path.exists(KEY):
        sys.exit('[ERR] 서비스 계정 토큰 없음: %s' % KEY)
    cred = Credentials.from_service_account_file(
        KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
    sh = gspread.authorize(cred).open_by_key(DOC)
    ws = sh.get_worksheet_by_id(GID)

    # 시작 행 — 마커가 있으면 거기, 없으면 마지막 데이터 행 + 2 (한 줄 띄운다).
    vals = ws.get_all_values()
    start = next((i for i, r in enumerate(vals, start=1) if r and r[0].strip() == MARKER), None)
    if start is None:
        last = max((i for i, r in enumerate(vals, start=1) if any(x.strip() for x in r)), default=0)
        start = last + 2

    # 이전 블록이 더 길었으면 잔재가 남는다 — 쓰기 전에 넉넉히 비운다 (WBS 13열까지).
    ws.batch_clear(['A%d:M%d' % (start, start + WIPE)])
    ws.update(rows, 'A%d' % start, value_input_option='RAW')

    # 블록 머리를 찾아 서식을 건다 — 행 번호를 박으면 블록 길이가 바뀔 때마다 어긋난다.
    ws.format('A%d:G%d' % (start, start), {
        'backgroundColor': HEAD_BG,
        'textFormat': {'bold': True, 'fontSize': 12, 'foregroundColor': WHITE}})
    for off, r in enumerate(rows):
        if r[0] in ('심각도', '최근 등재'):
            i = start + off
            ws.format('A%d:G%d' % (i, i), {'backgroundColor': SUB_BG, 'textFormat': {'bold': True}})

    print('[%s] ← 이슈 블록 %d행 @ %d행부터 (이슈 %d건 · 심각도 %d종 · 미해결 %d건)'
          % (ws.title, len(rows), start, len(recs),
             len(set(r.get('심각도', '') for r in recs)),
             sum(1 for r in recs if r['_dir'] != 'resolved')))


if __name__ == '__main__':
    main()
