# RFC 9110 — HTTP Semantics

> 출처: https://httpwg.org/specs/rfc9110.html
> 최종 갱신: 2026-04-08

## HTTP 상태 코드

### 2xx 성공

| 코드 | 이름 | 용도 | 규칙 |
|------|------|------|------|
| 200 | OK | 요청 성공 | 가장 일반적. 캐시 가능 |
| 201 | Created | 리소스 생성 성공 | Location 헤더에 새 URI. POST/PUT 응답 |
| 204 | No Content | 성공, 본문 없음 | DELETE 응답. 본문 포함 금지 |

### 3xx 리다이렉션

| 코드 | 이름 | 용도 | 규칙 |
|------|------|------|------|
| 301 | Moved Permanently | 영구 이동 | Location 헤더 필수. 캐시 가능 |
| 302 | Found | 임시 이동 | 원래 URI 유효. 캐시 조건부 |
| 304 | Not Modified | 캐시 유효 | 조건부 GET 응답. 본문 없음 |

### 4xx 클라이언트 오류

| 코드 | 이름 | 용도 | 규칙 |
|------|------|------|------|
| 400 | Bad Request | 요청 형식 오류 | 수정 없이 재시도 금지 |
| 401 | Unauthorized | 인증 필요 | WWW-Authenticate 헤더 필수 |
| 403 | Forbidden | 권한 없음 | 인증됨 but 권한 부족 |
| 404 | Not Found | 리소스 없음 | 캐시 가능 |
| 405 | Method Not Allowed | 메서드 불허 | Allow 헤더에 허용 메서드 명시 |
| 409 | Conflict | 상태 충돌 | 버전 충돌, 중복 등 |
| 422 | Unprocessable Content | 유효성 검증 실패 | 형식 올바르나 의미 오류 |
| 429 | Too Many Requests | 속도 제한 | Retry-After 헤더 권장 |

### 5xx 서버 오류

| 코드 | 이름 | 용도 | 규칙 |
|------|------|------|------|
| 500 | Internal Server Error | 서버 내부 오류 | 재시도 가능 |
| 502 | Bad Gateway | 게이트웨이 오류 | 업스트림 응답 이상 |
| 503 | Service Unavailable | 일시적 불가 | Retry-After 헤더 권장 |

## HTTP 메서드 속성

| 메서드 | Safe | Idempotent | Cacheable | Body |
|--------|------|------------|-----------|------|
| GET | Yes | Yes | Yes | 없음 |
| POST | No | No | 조건부 | 있음 |
| PUT | No | Yes | No | 있음 |
| PATCH | No | No | No | 있음 |
| DELETE | No | Yes | No | 선택 |

- **Safe**: 서버 상태 변경 없음
- **Idempotent**: 동일 요청 반복 시 동일 결과
