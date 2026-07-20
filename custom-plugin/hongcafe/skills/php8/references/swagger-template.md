---
type: reference
for: php8/SKILL.md
section: Swagger OpenAPI YAML 템플릿
---

### Swagger OpenAPI YAML

API 생성/수정 시 Markdown 명세서와 함께 `api-docs/{module}/{apiname}.yaml` (OpenAPI 3.0.3)을 생성/갱신한다.

| 항목 | 규칙 |
|------|------|
| **파일명** | Markdown과 동일 경로에 `.yaml` 확장자 (`goods-api.yaml`) |
| **서버** | 3개 환경 필수: `http://prd.gl.hongcafe.com` (Production), `http://stg.gl.hongcafe.com` (Staging), `http://dev.gl.hongcafe.com` (Development) |
| **인증** | Routes.php의 `'filter' => 'auth'` → `security: - cookieAuth: []`, 공개 → security 없음. `bearerAuth` 스키마 사용 금지 (쿠키 기반 아키텍처) |
| **경로** | 반드시 `/api/` prefix 포함 |

```yaml
openapi: 3.0.3
info:
  title: HongCafe Global - {Controller} API
  version: 1.0.0
servers:
  - url: http://prd.gl.hongcafe.com
    description: Production
  - url: http://stg.gl.hongcafe.com
    description: Staging
  - url: http://dev.gl.hongcafe.com
    description: Development
paths:
  /api/{prefix}/{method}:
    post:
      tags: [{Tag}]
      summary: "{설명}"
      security:
        - cookieAuth: []   # auth 필터 적용 라우트만
      parameters:
        - $ref: "#/components/parameters/XForwardedProto"
        - $ref: "#/components/parameters/XCsrfToken"
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                param:
                  type: string
      responses:
        "200":
          description: 성공
components:
  securitySchemes:
    cookieAuth:
      type: apiKey
      in: cookie
      name: hc_access
      description: JWT Access Token (HttpOnly, Secure, SameSite=Lax, 15분 TTL)
    refreshCookieAuth:
      type: apiKey
      in: cookie
      name: hc_refresh
      description: Refresh Token (HttpOnly, Secure, single-use, 7일 TTL)
  parameters:
    XCsrfToken:
      name: X-CSRF-TOKEN
      in: header
      required: true
      schema:
        type: string
      description: CSRF 토큰 (hc_csrf 쿠키 값)
    XForwardedProto:
      name: X-Forwarded-Proto
      in: header
      required: true
      schema:
        type: string
        default: https
      description: 모든 환경 필수
```
