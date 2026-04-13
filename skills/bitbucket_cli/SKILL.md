---
name: bitbucket_cli
description: >
  Bitbucket Cloud REST API 스킬.
  curl + API 토큰 기반으로 파이프라인, PR, 브랜치, 커밋 등을 조회/관리한다.
triggers:
  - "비트버킷"
  - "bitbucket"
  - "파이프라인"
  - "pipeline"
  - "PR 생성"
  - "PR 목록"
version: 1.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "1.0"
---

# Bitbucket Cloud REST API Skill

## 인증

- **방식:** Basic Auth (`-u "email:token"`)
- **설정 파일:** `~/.claude/.config` (`BITBUCKET_EMAIL`, `BITBUCKET_WORKSPACE`, `BITBUCKET_REPO_BE`, `BITBUCKET_REPO_FE`)
- **토큰 파일:** `~/.claude/skills/bitbucket_cli/.token`

### 인증 헤더 구성
```bash
source ~/.claude/.config
TOKEN=$(cat ~/.claude/skills/bitbucket_cli/.token)
AUTH="$BITBUCKET_EMAIL:$TOKEN"
```

## 기본 설정

| 항목 | 참조 |
|------|------|
| API Base URL | `https://api.bitbucket.org/2.0` |
| Workspace | `.config` → `BITBUCKET_WORKSPACE` |
| Backend Repo | `.config` → `BITBUCKET_REPO_BE` |
| Frontend Repo | `.config` → `BITBUCKET_REPO_FE` |

### 단축 변수
```bash
source ~/.claude/.config
TOKEN=$(cat ~/.claude/skills/bitbucket_cli/.token)
AUTH="$BITBUCKET_EMAIL:$TOKEN"
BASE="https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE"
BE="$BITBUCKET_REPO_BE"
FE="$BITBUCKET_REPO_FE"
```

## API 명령 템플릿

### 1. 파이프라인

#### 목록 조회
```bash
curl -s -u "$AUTH" "$BASE/$BE/pipelines/?sort=-created_on&pagelen=20" | python3 -c "
import json,sys
data=json.load(sys.stdin)
print(f'Total: {data.get(\"size\",\"?\")} pipelines\n')
print(f'{\"#\":<5} {\"상태\":<20} {\"브랜치\":<15} {\"트리거\":<10} {\"생성일\":<20}')
print('-'*75)
for v in data['values']:
    num=v.get('build_number','')
    state=v['state']['name']
    result=v['state'].get('result',{}).get('name','') if state=='COMPLETED' else ''
    status=result if result else state
    branch=v.get('target',{}).get('ref_name','?')
    trigger=v.get('trigger',{}).get('name','?')
    created=v.get('created_on','')[:16].replace('T',' ')
    print(f'{num:<5} {status:<20} {branch:<15} {trigger:<10} {created:<20}')
"
```

#### 특정 파이프라인 스텝 조회
```bash
# {uuid}는 파이프라인 UUID (중괄호 포함, URL 인코딩 필요: { → %7B, } → %7D)
curl -s -u "$AUTH" "$BASE/$BE/pipelines/{uuid}/steps/?pagelen=10"
```

#### 파이프라인 로그 조회
```bash
# {step_uuid}는 스텝 UUID
curl -sL -u "$AUTH" "$BASE/$BE/pipelines/{pipeline_uuid}/steps/{step_uuid}/log" | tr -cd '\11\12\15\40-\176' | tail -80
```

### 2. Pull Requests

#### PR 목록 (OPEN)
```bash
curl -s -u "$AUTH" "$BASE/$BE/pullrequests?state=OPEN&pagelen=20" | python3 -c "
import json,sys
data=json.load(sys.stdin)
for v in data.get('values',[]):
    print(f'#{v[\"id\"]} [{v[\"state\"]}] {v[\"title\"]}')
    print(f'  {v[\"source\"][\"branch\"][\"name\"]} -> {v[\"destination\"][\"branch\"][\"name\"]}')
    print()
"
```

#### PR 생성
```bash
curl -s -u "$AUTH" -X POST -H "Content-Type: application/json" \
  "$BASE/$BE/pullrequests" \
  -d '{
    "title": "PR 제목",
    "description": "PR 설명",
    "source": {"branch": {"name": "소스브랜치"}},
    "destination": {"branch": {"name": "대상브랜치"}},
    "close_source_branch": true
  }'
```

#### PR 머지
```bash
curl -s -u "$AUTH" -X POST -H "Content-Type: application/json" \
  "$BASE/$BE/pullrequests/{id}/merge" \
  -d '{"merge_strategy": "squash"}'
```

### 3. 브랜치

#### 브랜치 목록
```bash
curl -s -u "$AUTH" "$BASE/$BE/refs/branches?pagelen=20" | python3 -c "
import json,sys
data=json.load(sys.stdin)
for v in data.get('values',[]):
    print(f'{v[\"name\"]:<30} {v[\"target\"][\"hash\"][:8]} {v[\"target\"][\"date\"][:16]}')
"
```

### 4. 커밋

#### 최근 커밋 목록
```bash
curl -s -u "$AUTH" "$BASE/$BE/commits?pagelen=10" | python3 -c "
import json,sys
data=json.load(sys.stdin)
for v in data.get('values',[]):
    msg=v['message'].strip().split('\n')[0][:60]
    print(f'{v[\"hash\"][:8]} {v[\"date\"][:16]} {msg}')
"
```

### 5. 리포지토리 정보
```bash
curl -s -u "$AUTH" "$BASE/$BE" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'Name: {d[\"full_name\"]}')
print(f'Language: {d.get(\"language\",\"?\")}')
print(f'Size: {d.get(\"size\",\"?\")} bytes')
print(f'Updated: {d.get(\"updated_on\",\"?\")[:16]}')
"
```

## 주의사항

- **토큰 만료:** 범위 포함 API 토큰은 1년 유효 (2027-04-07 만료 예정). 만료 시 id.atlassian.com에서 재발급.
- **Rate Limit:** Bitbucket API는 시간당 1,000 요청 제한.
- **pagelen:** 최대 100. 기본값 10.
- **파이프라인 UUID:** URL에 사용 시 `{` → `%7B`, `}` → `%7D`로 인코딩 필요.
