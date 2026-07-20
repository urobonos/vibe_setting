# Filter 패턴 + 인증/인가 구현

요청 처리 파이프라인은 다음 Filter 체인을 순차 적용한다. **정책/알고리즘/TTL 등 규격은 `security-audit` §7-2(CORS 정책)/§7-3(Cookie 보안)/§7-4(CSRF + JWT 인증 정책, JWT 저장 7-1 포함)/§7-6(암호화 규격)/§7-9(SecureHeaders 필터)/§7-10(외부 노출 API 보안 Phase 2) 를 SSOT** 로 따르고, **쿠키명·면제 EP 등 프로젝트 고유값은 프로젝트 `CLAUDE.md`** 를 참조한다. 본 섹션은 **코드 구현 패턴**만 다룬다.

## Filter 체인 순서 (고정)

```
Request
  ↓
[ratelimit] → [csrftoken] → [auth] → [role:{name}] (해당 EP) → [CountryResolver] → Controller
  ↓                                                                                 ↓
Response  ← [SecureHeaders] ← ─────────────────────── Controller ← Service ← Repository ← DB
```

| # | Filter | 역할 | 등록 |
|---|--------|------|------|
| 1 | `ratelimit` | IP/사용자별 rate limit | globals `before` |
| 2 | `csrftoken` (`CsrfTokenFilter`) | CSRF 토큰 검증 — POST/PUT/PATCH/DELETE 만 | globals `before` |
| 3 | `auth` (`AuthFilter`) | JWT 쿠키 → API Key → Session(레거시) 우선순위 | globals `before` |
| 4 | `role:{name}` (`RoleFilter`) | RBAC Layer 1 — 역할 차단 | 라우트 단위 `before` |
| 5 | `CountryResolverFilter` | 국가 컨텍스트 해석 (`X-Country-Code` 주입) | globals `before` |
| 6 | `SecureHeadersFilter` | 응답 보안 헤더 주입 | globals `after` |

`app/Config/Filters.php` 에 globals 등록. 모듈별 라우트에는 `['filter' => 'role:{name}']` 개별 지정.

## CsrfTokenFilter 구현 패턴

CI4 내장 CSRF 필터는 **사용하지 않는다** (stateless JWT 아키텍처와 불일치). Signed Double Submit Cookie (HMAC-SHA256) 방식으로 커스텀 구현.

```php
<?php

declare(strict_types=1);

namespace App\Filters;

use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;

class CsrfTokenFilter implements FilterInterface
{
    private const STATE_CHANGING_METHODS = ['POST', 'PUT', 'PATCH', 'DELETE'];

    public function before(RequestInterface $request, $arguments = null)
    {
        if (! in_array($request->getMethod(true), self::STATE_CHANGING_METHODS, true)) {
            return null;
        }

        if ($this->isApiKeyAuthenticated($request)) {
            return null;
        }

        $cookieToken = $request->getCookie(config('App')->cookiePrefix . 'csrf');
        $headerToken = $request->getHeaderLine('X-CSRF-TOKEN');

        if ($cookieToken === '' || $headerToken === '' || ! hash_equals($cookieToken, $headerToken)) {
            return service('response')
                ->setStatusCode(403)
                ->setJSON(['error' => ['code' => 'FORBIDDEN', 'message' => lang('Auth.csrfMismatch')]]);
        }

        if (! service('csrfTokenService')->verify($cookieToken)) {
            return service('response')
                ->setStatusCode(403)
                ->setJSON(['error' => ['code' => 'FORBIDDEN', 'message' => lang('Auth.csrfInvalid')]]);
        }

        return null;
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
    }

    private function isApiKeyAuthenticated(RequestInterface $request): bool
    {
        return $request->getHeaderLine('X-Api-Key') !== '';
    }
}
```

**규칙**:
- HMAC 서명 생성·검증은 `CsrfTokenService` 에 위임 — Filter 는 오케스트레이션만
- 쿠키 ↔ 헤더 비교에는 **반드시 `hash_equals()`** — 타이밍 공격 방어
  **Why:** `===`/`==` 는 첫 불일치 바이트에서 즉시 반환해 응답 시간 차이로 토큰을 추정할 수 있는 사이드채널이 노출되며, `hash_equals()` 는 상수 시간 비교로 이를 차단한다.
- API Key 인증 요청(서버-서버)은 CSRF 면제
- 면제 EP 경로는 `AuthFilter::EXCLUDED_PATHS` 와 별도 목록 관리 — `CsrfTokenFilter::EXCLUDED_PATHS` 권장

## AuthFilter (JWT 쿠키 검증)

```php
<?php

declare(strict_types=1);

namespace App\Filters;

use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;

class AuthFilter implements FilterInterface
{
    public const EXCLUDED_PATHS = [
        'api/auth/login',
        'api/auth/refresh',
        // 프로젝트별 공개 EP 는 프로젝트 CLAUDE.md 참조
    ];

    public function before(RequestInterface $request, $arguments = null)
    {
        if ($this->isExcluded($request)) {
            return null;
        }

        $identity = service('authService')->resolveIdentity($request);

        if ($identity === null) {
            return service('response')
                ->setStatusCode(401)
                ->setJSON(['error' => ['code' => 'UNAUTHORIZED', 'message' => lang('Auth.unauthorized')]]);
        }

        $request->setAttribute('identity', $identity);
        return null;
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
    }

    private function isExcluded(RequestInterface $request): bool
    {
        $uri = trim($request->getUri()->getPath(), '/');
        foreach (self::EXCLUDED_PATHS as $path) {
            if ($uri === $path) {
                return true;
            }
        }
        return false;
    }
}
```

**인증 우선순위** (`AuthService::resolveIdentity` 내부):
1. JWT 쿠키 (프로젝트 지정 쿠키명, 예: `{prefix}_access`)
2. API Key (`X-Api-Key` 헤더)
3. Session (레거시 호환 — 신규 EP 사용 금지)

**금지**: `Authorization: Bearer` 헤더 폴백 — XSS 시 토큰 탈취 위험
**Why:** Bearer 헤더는 JS 에서 읽고 쓸 수 있어 XSS 1건만 발생해도 전체 사용자 세션이 탈취되며, HttpOnly 쿠키는 JS 접근이 원천 차단된다.

## RoleFilter (RBAC Layer 1)

```php
<?php

declare(strict_types=1);

namespace App\Filters;

use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;

class RoleFilter implements FilterInterface
{
    public function before(RequestInterface $request, $arguments = null)
    {
        $requiredRole = $arguments[0] ?? null;
        $identity = $request->getAttribute('identity');

        if ($identity === null || ! $identity->hasRole($requiredRole)) {
            return service('response')
                ->setStatusCode(403)
                ->setJSON(['error' => ['code' => 'FORBIDDEN', 'message' => lang('Auth.insufficientRole')]]);
        }

        return null;
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
    }
}
```

라우트 적용:

```php
$routes->group('api/callees', ['filter' => 'role:callee'], static function ($routes) {
    $routes->get('profile', 'CalleeController::profile');
});
```

**RBAC 3계층 Defense in Depth** (OWASP API5:2023):

| Layer | 위치 | 역할 |
|------|------|------|
| 1 | `RoleFilter:{name}` — 라우트 필터 | 역할 자체 차단 |
| 2 | Controller `checkNeedLogin(true)` 또는 소유권 검증 | 이중 검증 |
| 3 | Repository 쿼리 `WHERE owner_id = :currentUserId:` | 데이터 레벨 소유권 강제 |

단일 Layer 신뢰 금지 — Filter 를 우회하는 경로(예: 내부 Service 호출)가 있어도 Repository 쿼리가 마지막 안전장치.

## JWT 발급/검증 패턴

- **알고리즘**: HMAC-SHA256 — 외부 라이브러리 없이 순수 PHP 구현 권장
- **Access Token**: 짧은 만료(15분 권장). Payload 최소 필드: 사용자 식별자, 역할, `iat`, `exp`
- **Refresh Token**: 별도 HttpOnly 쿠키. `jti` + `family` 필드로 **Token Rotation + Reuse Detection**
- **Reuse Detection**: 사용 완료된 `jti` 재제출 시 `family` 전체 무효화 — 세션 탈취 방어
- **구현 위치**: `AuthService`, `JwtService` 등 Service 레이어. Controller 에서 토큰 조작 금지

## Cookie 발급 규격

`Response::setCookie()` / `setcookie()` 호출 시 다음 속성을 **강제**한다.

| 속성 | 값 | 사유 |
|------|------|------|
| `httponly` | `true` | XSS 방어 (`document.cookie` 접근 차단) |
| `samesite` | `Lax` | CSRF 보조 방어 (`security-audit` §7-3) |
| `secure` | `true` (prod) / `ENVIRONMENT` 분기 | HTTPS 전송 강제 |
| `prefix` | 프로젝트 지정 | 쿠키명 충돌 방지 |

- 기본값은 `app/Config/Cookie.php` 에 등록. 호출처에서 속성을 개별 전달하지 않도록 래퍼 유틸리티 사용 권장
- `samesite=None` **사용 금지** — 크로스사이트 허용으로 CSRF 취약
  **Why:** `samesite=None` 은 임의 외부 도메인이 사용자 쿠키를 동반한 요청을 보낼 수 있게 해 CSRF 토큰이 탈취된 단일 시점에 전체 계정 변조가 가능해진다.

## 참조

- 정책·알고리즘·TTL 규격: `security-audit` §7-2(CORS 정책)/§7-3(Cookie 보안)/§7-4(CSRF + JWT 인증 정책, JWT 저장 7-1 포함)/§7-6(암호화 규격)/§7-9(SecureHeaders 필터)/§7-10(외부 노출 API 보안 Phase 2)
- 쿠키명·면제 EP 경로 등 프로젝트 고유값: 프로젝트 `CLAUDE.md`
- 국가 컨텍스트 Filter: `global-context` §2 Country Resolver
