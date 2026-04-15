---
name: notion_cli
description: >
  Notion API curl 기반 CLI 스킬.
  페이지 조회/생성/수정, 데이터베이스 검색, 블록 조작을 수행한다.
triggers:
  - "노션"
  - "notion"
  - "노션 페이지"
  - "노션 검색"
version: 1.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Notion CLI Skill

## 인증

- **방식:** Bearer Token
- **토큰 파일:** `~/.claude/skills/notion_cli/.token`
- **토큰 읽기:** `TOKEN=$(cat ~/.claude/skills/notion_cli/.token)`

### 인증 헤더 구성
```bash
TOKEN=$(cat ~/.claude/skills/notion_cli/.token)
```

## 기본 설정

| 항목 | 값 |
|------|-----|
| API Base URL | `https://api.notion.com/v1` |
| API Version | 2022-06-28 |

### 단축 변수
```bash
TOKEN=$(cat ~/.claude/skills/notion_cli/.token)
BASE="https://api.notion.com/v1"
AUTH="Authorization: Bearer $TOKEN"
VER="Notion-Version: 2022-06-28"
CT="Content-Type: application/json"
```

## API 명령 템플릿

### 1. 검색

#### 전체 검색
```bash
curl -s -X POST "$BASE/search" \
  -H "$AUTH" -H "$VER" -H "$CT" \
  -d '{"query": "검색어", "page_size": 10}' | python3 -c "
import json,sys
data=json.load(sys.stdin)
for r in data.get('results',[]):
    obj=r.get('object','')
    title=''
    if obj=='page':
        props=r.get('properties',{})
        for k,v in props.items():
            if v.get('type')=='title':
                title=''.join([t.get('plain_text','') for t in v.get('title',[])])
                break
    elif obj=='database':
        title=''.join([t.get('plain_text','') for t in r.get('title',[])])
    print(f'[{obj}] {r[\"id\"]}  {title}')
"
```

#### 데이터베이스 필터 검색
```bash
curl -s -X POST "$BASE/databases/{database_id}/query" \
  -H "$AUTH" -H "$VER" -H "$CT" \
  -d '{"page_size": 10}' | python3 -c "
import json,sys
data=json.load(sys.stdin)
for r in data.get('results',[]):
    props=r.get('properties',{})
    title=''
    for k,v in props.items():
        if v.get('type')=='title':
            title=''.join([t.get('plain_text','') for t in v.get('title',[])])
            break
    print(f'{r[\"id\"]}  {title}')
"
```

### 2. 페이지

#### 페이지 조회
```bash
curl -s "$BASE/pages/{page_id}" \
  -H "$AUTH" -H "$VER" | python3 -c "
import json,sys
data=json.load(sys.stdin)
props=data.get('properties',{})
for k,v in props.items():
    vtype=v.get('type','')
    if vtype=='title':
        val=''.join([t.get('plain_text','') for t in v.get('title',[])])
    elif vtype=='rich_text':
        val=''.join([t.get('plain_text','') for t in v.get('rich_text',[])])
    elif vtype in ('number','checkbox','url','email','phone_number'):
        val=str(v.get(vtype,''))
    elif vtype=='select':
        val=v.get('select',{}).get('name','') if v.get('select') else ''
    elif vtype=='multi_select':
        val=', '.join([s.get('name','') for s in v.get('multi_select',[])])
    elif vtype=='date':
        val=str(v.get('date',{}).get('start','')) if v.get('date') else ''
    elif vtype=='status':
        val=v.get('status',{}).get('name','') if v.get('status') else ''
    else:
        val=f'({vtype})'
    print(f'{k}: {val}')
"
```

#### 페이지 블록 내용 조회
```bash
curl -s "$BASE/blocks/{page_id}/children?page_size=100" \
  -H "$AUTH" -H "$VER" | python3 -c "
import json,sys
data=json.load(sys.stdin)
for b in data.get('results',[]):
    btype=b.get('type','')
    content=b.get(btype,{})
    if 'rich_text' in content:
        text=''.join([t.get('plain_text','') for t in content.get('rich_text',[])])
        print(f'[{btype}] {text}')
    elif btype=='child_database':
        print(f'[{btype}] {content.get(\"title\",\"\")}')
    else:
        print(f'[{btype}]')
"
```

#### 페이지 생성
```bash
curl -s -X POST "$BASE/pages" \
  -H "$AUTH" -H "$VER" -H "$CT" \
  -d '{
    "parent": {"page_id": "부모페이지ID"},
    "properties": {
      "title": {"title": [{"text": {"content": "페이지 제목"}}]}
    },
    "children": [
      {
        "object": "block",
        "type": "paragraph",
        "paragraph": {
          "rich_text": [{"type": "text", "text": {"content": "본문 내용"}}]
        }
      }
    ]
  }'
```

#### 페이지 내용 덮어쓰기 (replace_content)
```bash
# 1단계: 기존 블록 삭제
curl -s "$BASE/blocks/{page_id}/children?page_size=100" \
  -H "$AUTH" -H "$VER" | python3 -c "
import json,sys
data=json.load(sys.stdin)
for b in data.get('results',[]):
    print(b['id'])
" | while read block_id; do
  curl -s -X DELETE "$BASE/blocks/$block_id" -H "$AUTH" -H "$VER" > /dev/null
done

# 2단계: 새 블록 추가
curl -s -X PATCH "$BASE/blocks/{page_id}/children" \
  -H "$AUTH" -H "$VER" -H "$CT" \
  -d '{
    "children": [
      {
        "object": "block",
        "type": "paragraph",
        "paragraph": {
          "rich_text": [{"type": "text", "text": {"content": "새 내용"}}]
        }
      }
    ]
  }'
```

### 3. 블록

#### 블록 추가 (append)
```bash
curl -s -X PATCH "$BASE/blocks/{page_id}/children" \
  -H "$AUTH" -H "$VER" -H "$CT" \
  -d '{
    "children": [
      {
        "object": "block",
        "type": "paragraph",
        "paragraph": {
          "rich_text": [{"type": "text", "text": {"content": "추가할 내용"}}]
        }
      }
    ]
  }'
```

#### 블록 삭제
```bash
curl -s -X DELETE "$BASE/blocks/{block_id}" \
  -H "$AUTH" -H "$VER"
```

### 4. 데이터베이스

#### 데이터베이스 조회
```bash
curl -s "$BASE/databases/{database_id}" \
  -H "$AUTH" -H "$VER" | python3 -c "
import json,sys
d=json.load(sys.stdin)
title=''.join([t.get('plain_text','') for t in d.get('title',[])])
print(f'Title: {title}')
print(f'Properties:')
for k,v in d.get('properties',{}).items():
    print(f'  {k}: {v[\"type\"]}')
"
```

### 5. 유저

#### 현재 봇 정보
```bash
curl -s "$BASE/users/me" \
  -H "$AUTH" -H "$VER" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'Name: {d.get(\"name\",\"?\")}')
print(f'Type: {d.get(\"type\",\"?\")}')
print(f'ID: {d.get(\"id\",\"?\")}')
"
```

## 주의사항

- **블록 제한:** children append 시 한 번에 최대 100개 블록
- **페이지 사이즈:** 기본 100, 최대 100 (page_size 파라미터)
- **페이지네이션:** 응답에 `has_more: true`와 `next_cursor`가 있으면 `start_cursor` 파라미터로 다음 페이지 요청
- **Rich Text 제한:** 단일 rich_text 블록 최대 2000자
- **Rate Limit:** 초당 3요청 (Integration 기본)
- **ID 형식:** UUID (하이픈 포함/미포함 모두 가능)
