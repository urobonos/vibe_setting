---
type: reference
for: php8/SKILL.md
section: API 명세서 (API Docs) — Markdown 템플릿
---

## API 명세서 (API Docs)

API 생성 시 `api-docs/{module}/{apiname}.md`에 명세서를 자동 생성한다.

### 경로 규칙

| 항목 | 규칙 | 예시 |
|------|------|------|
| **디렉토리** | `api-docs/{module}/` | `api-docs/commerce/` |
| **module** | URL 규격의 kebab-case | `commerce`, `phone-consult`, `member` |
| **파일명** | 리소스명 kebab-case + `.md` | `orders.md`, `calls.md`, `profile.md` |

### 템플릿

```markdown
# {API 이름}

> **모듈**: {BC명} | **Base Path**: `/api/{module}/{resource}`

---

## 엔드포인트 목록

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/{module}/{resource}` | 목록 조회 |
| GET | `/api/{module}/{resource}/{id}` | 단건 조회 |
| POST | `/api/{module}/{resource}` | 생성 |
| PUT | `/api/{module}/{resource}/{id}` | 수정 |
| DELETE | `/api/{module}/{resource}/{id}` | 삭제 |

---

## 공통

### Headers
| Header | 필수 | 값 |
|--------|------|----|
| Content-Type | Y | `application/json` |
| Authorization | Y/N | `Bearer {token}` |

### 공통 쿼리 파라미터 (목록 조회)
| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| page | int | 1 | 페이지 번호 |
| perPage | int | 20 | 페이지당 항목 수 |
| sort | string | createdAt | 정렬 기준 |
| order | string | desc | 정렬 방향 (asc/desc) |
| search | string | — | 검색 키워드 |

---

## 상세

### GET `/api/{module}/{resource}` — 목록 조회

**Response 200**
```json
{
  "status": "success",
  "data": [],
  "meta": {
    "currentPage": 1,
    "perPage": 20,
    "total": 0,
    "lastPage": 1
  }
}
```

### GET `/api/{module}/{resource}/{id}` — 단건 조회

**Path Parameters**
| 파라미터 | 타입 | 설명 |
|----------|------|------|
| id | int | 리소스 ID |

**Response 200**
```json
{
  "status": "success",
  "data": {}
}
```

**Error 404**
```json
{
  "status": "error",
  "error": { "code": "NOT_FOUND", "message": "..." }
}
```

### POST `/api/{module}/{resource}` — 생성

**Request Body**
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| (필드명) | (타입) | Y/N | (설명) |

**Response 201**
```json
{
  "status": "success",
  "data": {}
}
```

**Error 400**
```json
{
  "status": "error",
  "error": {
    "code": "INVALID_INPUT",
    "message": "입력값이 유효하지 않습니다.",
    "details": {}
  }
}
```

### PUT `/api/{module}/{resource}/{id}` — 수정

**Request Body**: POST와 동일 (부분 수정 허용 시 명시)

**Response 200**
```json
{
  "status": "success",
  "data": {}
}
```

### DELETE `/api/{module}/{resource}/{id}` — 삭제

**Response 200**
```json
{
  "status": "success",
  "message": "삭제되었습니다."
}
```

---

## API 응답 표준

### 원칙
- **HTTP 상태코드가 성공/실패의 SSOT** (Google API Design Guide, RFC 7231)
- CI4 ResponseTrait의 `respond()`, `failNotFound()` 등이 HTTP 코드를 자동 설정
- body 내 `status` 필드는 프론트엔드 편의를 위해 유지하되, HTTP 코드와 항상 일치
- **응답 키 네이밍**: DB `snake_case` → API 응답 `camelCase` 변환 필수 (`created_at` → `createdAt`, `ac_nick` → `acNick`)

### 에러 코드 (현상 서술형, suffix 없음)

| 에러 코드 | HTTP | 설명 |
|-----------|------|------|
| INVALID_INPUT | 400 | 입력값 유효성 검증 실패 |
| UNAUTHORIZED | 401 | 인증 실패 |
| FORBIDDEN | 403 | 권한 없음 |
| NOT_FOUND | 404 | 리소스를 찾을 수 없음 |
| CONFLICT | 409 | 중복/충돌 |
| INTERNAL | 500 | 서버 내부 오류 |

> 업계 표준(Google Cloud `INVALID_ARGUMENT`, Stripe `card_declined` 등) 참조.
> `_ERROR`/`_FAILED` suffix 대신 현상 서술형 코드 사용.

### 페이지네이션 메타 키

```json
{
  "data": [],
  "meta": {
    "currentPage": 1,
    "perPage": 20,
    "total": 0,
    "lastPage": 1
  }
}
```

- camelCase 통일 (`currentPage`, `perPage`, `lastPage`)
- CI4 Pager 라이브러리는 JSON 키를 정의하지 않으므로 프로젝트 표준으로 확정

---

## 변경 이력

| 날짜 | 변경 내용 |
|------|----------|
| {YYYY-MM-DD} | 최초 작성 |
```

### 작성 규칙

- CRUD 중 구현하지 않는 엔드포인트는 템플릿에서 제거한다
- 비표준 엔드포인트(예: `POST /api/commerce/orders/{id}/cancel`)는 상세 섹션에 추가한다
- Request Body의 필드는 실제 Model/Entity 기준으로 모두 기재한다
- Response 예시의 `data`는 실제 필드를 포함한 구체적 예시를 작성한다
- 인증 필요 여부(`Authorization` 헤더)는 엔드포인트별로 정확히 표기한다
- 명세서 생성/수정 시 `api-docs/README.md` 인덱스에 해당 항목을 추가/갱신한다
