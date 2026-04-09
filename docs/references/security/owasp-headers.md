# OWASP HTTP Security Headers

> 출처: https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html
> 최종 갱신: 2026-04-08

## 권장 보안 헤더

| 헤더 | 권장 값 | 목적 |
|------|---------|------|
| `X-Content-Type-Options` | `nosniff` | MIME 스니핑 방지 |
| `X-Frame-Options` | `DENY` | 클릭재킹 방지 |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | HTTPS 강제 |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | 리퍼러 정보 제한 |
| `X-XSS-Protection` | `0` | 비활성화 권장. CSP로 대체 |
| `Permissions-Policy` | `geolocation=(), camera=(), microphone=()` | 브라우저 기능 제한 |
| `Content-Security-Policy` | 앱별 커스텀 | XSS/데이터 인젝션 방지 |

## 헤더별 상세

### X-Content-Type-Options: nosniff
- MIME 타입 혼동 공격 차단
- Content-Type 헤더를 정확히 설정해야 효과적

### X-Frame-Options: DENY
- 클릭재킹 방지. iframe/embed/object 삽입 차단
- 모던 브라우저: CSP `frame-ancestors` 지시어로 대체 가능

### Strict-Transport-Security
- HTTPS만 허용, HTTP 자동 업그레이드
- `includeSubDomains`: 서브도메인도 적용
- 주의: SSL 인증서 문제 시 max-age 동안 접속 불가

### Referrer-Policy: strict-origin-when-cross-origin
- 같은 오리진: 전체 URL 전송
- 크로스 오리진: 오리진만 전송

### X-XSS-Protection: 0
- 비활성화 필수 (OWASP 권고)
- 레거시 XSS 필터가 오히려 취약점 생성 가능

### Content-Security-Policy
- API 서버: `default-src 'none'; frame-ancestors 'none'`
- 웹 페이지: 앱별 정책 커스텀 필요
