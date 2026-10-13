---
name: cli-figma
description: >
  Figma REST API curl 기반 CLI 스킬. 피그마 URL·파일 키를 받으면 파일 구조·노드 속성(크기·색·폰트·간격)
  조회, 노드 이미지 export, 코멘트 조회, 팀 프로젝트·파일·버전 목록을 수행한다. 피그마 시안을 보고 구현하거나
  디자인 값을 확인할 때 쓴다.
triggers:
  - "피그마"
  - "figma"
  - "figma.com/design"
  - "figma.com/file"
  - "시안 확인"
  - "피그마 노드"
  - "피그마 export"
  - "/tools:cli-figma"
version: 1.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Figma CLI Skill

## 실행 조건

- **조회는 요청 맥락이 있으면 바로 실행한다** — 사용자가 피그마 URL·파일 키를 주거나 시안 확인을 요청한 경우.
- **쓰기(코멘트 작성·삭제)는 사용자가 명시적으로 요청할 때만** 실행한다 (CLAUDE.md §3 외부 시스템). 다른 사람이 보는 파일에 남기 때문이다.

## 인증

- **방식:** Personal Access Token, 헤더 `X-Figma-Token`
- **토큰 파일:** `${CLAUDE_PLUGIN_ROOT}/.token/cli-figma.token` (`.gitignore` `custom-plugin/**/*.token` 로 무시됨)
- 토큰 소유 계정의 권한으로 보이는 파일만 조회된다. 403/404 면 그 계정에 공유가 안 된 파일이다.

### 단축 변수
```bash
TOKEN=$(cat ${CLAUDE_PLUGIN_ROOT}/.token/cli-figma.token)
BASE="https://api.figma.com/v1"
AUTH="X-Figma-Token: $TOKEN"
```

연결 확인: `curl -s -H "$AUTH" "$BASE/me"` → `handle`·`email` 이 나오면 정상.

## URL 에서 키 추출

`https://www.figma.com/design/{FILE_KEY}/{이름}?node-id=12-345` (구형 `/file/` 도 같다)

- `FILE_KEY` = `/design/` 또는 `/file/` 다음 경로 조각
- `NODE_ID` = `node-id` 쿼리값의 `-` 를 `:` 로 바꾼 값 (`12-345` → `12:345`). API 는 `:` 형만 받는다. URL 쿼리에 넣을 땐 `12%3A345` 또는 그대로 `12:345`.
- 브랜치 URL `/design/{KEY}/branch/{BRANCH_KEY}/…` 는 `BRANCH_KEY` 를 파일 키로 쓴다.

```bash
URL='https://www.figma.com/design/AbC123/Name?node-id=12-345'
FILE_KEY=$(printf '%s' "$URL" | sed -nE 's#.*/branch/([^/?]+).*#\1#p')
[ -n "$FILE_KEY" ] || FILE_KEY=$(printf '%s' "$URL" | sed -nE 's#.*/(design|file)/([^/?]+).*#\2#p')
NODE_ID=$(printf '%s' "$URL" | sed -nE 's#.*node-id=([^&]+).*#\1#p' | tr '-' ':')
```

## 명령 템플릿

응답 JSON 은 크다 (파일 전체는 수 MB). **항상 `depth`·`ids` 로 좁히고, python 으로 필요한 필드만 뽑는다.**

### 1. 파일 개요 (페이지·최상위 프레임)
```bash
curl -s -H "$AUTH" "$BASE/files/$FILE_KEY?depth=2" | python -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('name'), '| 수정', d.get('lastModified'))
for p in d['document']['children']:
    print('PAGE', p['id'], p['name'])
    for f in p.get('children',[]):
        print('   ', f['type'], f['id'], f['name'])
"
```

### 2. 노드 상세 (구현용 값)
```bash
curl -s -H "$AUTH" "$BASE/files/$FILE_KEY/nodes?ids=$NODE_ID&depth=3" | python -c "
import json,sys
d=json.load(sys.stdin)
def walk(n,ind=0):
    bb=n.get('absoluteBoundingBox') or {}
    s=n.get('style') or {}
    fills=[f.get('color') for f in n.get('fills',[]) if f.get('type')=='SOLID']
    line=f\"{' '*ind}{n['type']} {n['id']} {n.get('name')} {int(bb.get('width',0))}x{int(bb.get('height',0))}\"
    if s: line+=f\" font={s.get('fontFamily')} {s.get('fontSize')}/{s.get('fontWeight')}\"
    if fills: c=fills[0]; line+=' #%02X%02X%02X' % (round(c['r']*255),round(c['g']*255),round(c['b']*255))
    if n.get('itemSpacing') is not None: line+=f\" gap={n['itemSpacing']} pad={n.get('paddingTop')},{n.get('paddingRight')},{n.get('paddingBottom')},{n.get('paddingLeft')}\"
    if n.get('characters'): line+=f\" text={n['characters'][:40]!r}\"
    print(line)
    for c in n.get('children',[]): walk(c,ind+2)
for k,v in d['nodes'].items():
    walk(v['document'])
"
```
노드 여러 개 = `ids=1:2,3:4`. 원본 JSON 이 필요하면 python 없이 파일로 저장해 읽는다.

### 3. 이미지 export
```bash
curl -s -H "$AUTH" "$BASE/images/$FILE_KEY?ids=$NODE_ID&format=png&scale=2" \
  | python -c "import json,sys; [print(k,v) for k,v in json.load(sys.stdin)['images'].items()]"
# 받은 URL 을 내려받는다 (URL 은 일정 시간 뒤 만료)
curl -s -o node.png "{위 출력의 URL}"
```
`format` = `png`·`jpg`·`svg`·`pdf`, `scale` = 0.01~4. 받은 png 는 Read 도구로 직접 볼 수 있다.

### 4. 코멘트
```bash
# 조회
curl -s -H "$AUTH" "$BASE/files/$FILE_KEY/comments" | python -c "
import json,sys
for c in json.load(sys.stdin)['comments']:
    print(c['created_at'][:16], c['user']['handle'], '|', c['message'][:80])
"
# 작성 (명시 요청 시만) — 특정 노드에 달려면 client_meta 에 node_id
curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" "$BASE/files/$FILE_KEY/comments" \
  -d '{"message":"내용","client_meta":{"node_id":"12:345","node_offset":{"x":0,"y":0}}}'
```

### 5. 팀 프로젝트 · 파일 목록
팀 ID 는 팀 페이지 URL `figma.com/files/team/{TEAM_ID}/…` 에서 얻는다 (API 로 팀 목록은 조회 불가).
```bash
curl -s -H "$AUTH" "$BASE/teams/$TEAM_ID/projects" | python -c "import json,sys; [print(p['id'],p['name']) for p in json.load(sys.stdin)['projects']]"
curl -s -H "$AUTH" "$BASE/projects/$PROJECT_ID/files" | python -c "import json,sys; [print(f['key'],f['last_modified'][:10],f['name']) for f in json.load(sys.stdin)['files']]"
```

### 6. 버전 목록
```bash
curl -s -H "$AUTH" "$BASE/files/$FILE_KEY/versions" | python -c "
import json,sys
for v in json.load(sys.stdin)['versions'][:20]:
    print(v['id'], v['created_at'][:16], v['user']['handle'], v.get('label') or '')
"
```
특정 버전 조회 = 파일·노드 요청에 `&version={id}`.

## 실패했을 때

| 응답 | 원인 | 조치 |
|---|---|---|
| `403 Invalid token` | 토큰 만료·폐기 | 피그마 Settings → Security → Personal access tokens 에서 재발급 후 토큰 파일 교체 |
| `403`/`404` (토큰 정상) | 토큰 계정에 파일 공유 안 됨 | 파일 소유자에게 공유 요청 |
| `400 node not found` | node-id `-`→`:` 미변환 또는 오타 | 키 추출 규칙 재확인 |
| `429` | rate limit | 잠시 뒤 재시도, `ids` 를 묶어 호출 수를 줄인다 |
| 응답이 너무 큼·느림 | `depth`·`ids` 없이 파일 전체 조회 | 1번으로 구조를 보고 2번으로 좁힌다 |
