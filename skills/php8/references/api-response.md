# API 응답 표준

## 원칙

- **HTTP 상태코드가 성공/실패의 SSOT** (Google API Design Guide, RFC 7231)
- CI4 ResponseTrait의 `respond()`, `failNotFound()` 등이 HTTP 코드를 자동 설정
- body 내 `status` 필드는 프론트엔드 편의를 위해 유지하되, HTTP 코드와 항상 일치
- **응답 키 네이밍**: DB `snake_case` → API 응답 `camelCase` 변환 필수 (`created_at` → `createdAt`, `ac_nick` → `acNick`)

## 에러 코드 (현상 서술형, suffix 없음)

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

## 페이지네이션 메타 키

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

## Swagger OpenAPI YAML

> **Swagger 스펙 template:** OpenAPI/Swagger YAML 템플릿은 `references/swagger-template.md` 참조.
