---
name: search-docset
description: >
  Dash docset 기반 오프라인 기술 레퍼런스 검색.
  타당성 검토 시 공식 문서 근거를 docSet.dsidx SQLite 인덱스에서 조회하고 HTML 원문을 추출한다.
triggers:
  - "타당성 검토(Feasibility Review) 수행 시"
  - "공식 문서 근거가 필요할 때"
  - "기술 레퍼런스 요청"
  - "/tools:search-docset"
version: 1.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Docset Reference Skill

## 개요

`~/.claude/docs/references/` 디렉토리의 Dash docset(`.docset`)과 마크다운 캐시(`.md`)를 검색하여 공식 문서 근거를 제공한다.

## 검색 우선순위

1. **Docset SQLite 인덱스** — `docSet.dsidx`의 `searchIndex` 테이블 검색
2. **마크다운 캐시** — 기존 `.md` 파일 (owasp-top10.md 등) Read
3. **WebFetch 후 캐시 추가** — 1, 2에서 미수록 시

---

## 1. Docset 구조

```
~/.claude/docs/references/
├── {Name}.docset/
│   └── Contents/Resources/
│       ├── docSet.dsidx          ← SQLite DB
│       └── Documents/{path}      ← HTML 원문
├── owasp-top10.md                ← 마크다운 캐시
└── README.md
```

**SQLite 스키마:** `searchIndex(id INTEGER PK, name TEXT, type TEXT, path TEXT)`

---

## 2. 검색 명령

### 2-1. 키워드 검색 (단일 docset)

```bash
python -c "
import sqlite3, sys
conn = sqlite3.connect('C:/Users/PV/.claude/docs/references/{DOCSET_NAME}.docset/Contents/Resources/docSet.dsidx')
cur = conn.cursor()
cur.execute(\"SELECT name, type, path FROM searchIndex WHERE name LIKE ? ORDER BY name LIMIT 20\", ('%{KEYWORD}%',))
for r in cur.fetchall(): print(r)
conn.close()
"
```

### 2-2. 전체 docset 검색

```bash
python -c "
import sqlite3, os
base = 'C:/Users/PV/.claude/docs/references'
keyword = '{KEYWORD}'
for d in sorted(os.listdir(base)):
    if not d.endswith('.docset'): continue
    db = os.path.join(base, d, 'Contents/Resources/docSet.dsidx')
    if not os.path.exists(db): continue
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    cur.execute('SELECT name, type, path FROM searchIndex WHERE name LIKE ? ORDER BY name LIMIT 10', (f'%{keyword}%',))
    rows = cur.fetchall()
    if rows:
        print(f'\n=== {d} ===')
        for r in rows: print(r)
    conn.close()
"
```

### 2-3. docset 목록 확인

```bash
python -c "
import sqlite3, os
base = 'C:/Users/PV/.claude/docs/references'
for d in sorted(os.listdir(base)):
    if not d.endswith('.docset'):continue
    db = os.path.join(base, d, 'Contents/Resources/docSet.dsidx')
    if not os.path.exists(db): continue
    conn = sqlite3.connect(db)
    count = conn.execute('SELECT COUNT(*) FROM searchIndex').fetchone()[0]
    types = [r[0] for r in conn.execute('SELECT DISTINCT type FROM searchIndex')]
    print(f'{d}: {count} entries | types: {types}')
    conn.close()
"
```

---

## 3. 문서 읽기

검색 결과의 `path`로 HTML 원문을 텍스트 추출한다.

### 3-1. path 정규화

Dash 앵커가 포함된 path는 정규화가 필요하다:

```python
import re
raw_path = "<dash_entry_titleDescription=...>actual/path.html#//apple_ref/..."
clean = re.sub(r'^<[^>]+>', '', raw_path)   # Dash prefix 제거
clean = re.sub(r'#.*$', '', clean)           # anchor 제거
```

### 3-2. HTML → 텍스트 추출

```bash
python -c "
import re
from html.parser import HTMLParser

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text, self.skip = [], False
    def handle_starttag(self, tag, attrs):
        if tag in ('script','style','nav','header','footer'): self.skip = True
    def handle_endtag(self, tag):
        if tag in ('script','style','nav','header','footer'): self.skip = False
    def handle_data(self, data):
        if not self.skip: self.text.append(data)

raw_path = '{RAW_PATH}'
clean = re.sub(r'^<[^>]+>', '', raw_path)
clean = re.sub(r'#.*$', '', clean)
doc_file = 'C:/Users/PV/.claude/docs/references/{DOCSET_NAME}.docset/Contents/Resources/Documents/' + clean

with open(doc_file, 'r', encoding='utf-8') as f:
    html = f.read()
ext = TextExtractor()
ext.feed(html)
text = re.sub(r'\s+', ' ', ' '.join(ext.text)).strip()
print(text[:3000])
"
```

> **주의:** 문서가 길면 `text[:3000]`으로 앞부분만 추출. 필요 시 구간 지정(`text[3000:6000]`).

---

## 4. 타당성 검토 연동

타당성 검토 수행 시 다음 절차를 따른다:

1. **근거 키워드 도출** — 권고 사항에서 검증할 기술 키워드 추출
2. **docset 검색** — 2-1 또는 2-2로 관련 항목 검색
3. **원문 확인** — 3-2로 해당 문서 텍스트 추출하여 근거 확인
4. **보안 지식베이스 검색** — `docs/references/security/` 하위 문서 Read (OWASP, CWE, JWT, AWS 등)
5. **마크다운 캐시 확인** — docset에 없으면 기존 `.md` 캐시 Read
6. **WebFetch fallback** — 1~5에서 미수록 시 WebFetch로 확보 후 `.md`로 캐시 추가
7. **출처 기재** — 타당성 검토 테이블에 docset명 + 항목명 또는 URL 기재

### 출처 표기 형식

| 출처 유형 | 표기 예시 |
|-----------|-----------|
| Docset | `[PHP.docset] password_hash (func)` |
| Docset 문서 | `[CodeIgniter.docset] Controller Filters (Guide)` |
| 캐시 .md | `~/.claude/docs/references/{name}.md` (예: `owasp-top10.md` — 실제 캐시는 필요 시 생성) |
| 보안 KB | `~/.claude/docs/references/security/{name}.md` (예: `owasp-api-security-top10.md`) |
| WebFetch | 원본 URL |

---

## 5. 주의사항

- `docSet.dsidx`는 **읽기 전용**으로 사용한다. INSERT/UPDATE/DELETE 금지.
- HTML 문서도 수정하지 않는다.
- 새 docset 추가는 사용자에게 Checkpoint 요청 후 진행한다.
- 마크다운 캐시(`.md`) 추가/수정은 기존 README.md 갱신 규칙을 따른다.
