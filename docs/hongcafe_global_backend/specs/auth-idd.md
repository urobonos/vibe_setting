---
문서명: Auth — Interface Design Document
문서 ID: auth-idd
버전: v2.1
적용 표준: MIL-STD-498 (Interface Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-17
작성자: jypark
대상 시스템: Auth Module (HongCafe Global Backend)
관련 문서: auth-sdd.md, auth-srs.md
---

# Auth — Interface Design Document

> version: 2.1 | standard: MIL-STD-498 IDD | lastUpdated: 2026-04-17 | module: Auth

---

## 1. Scope (범위)

### 1.1 Identification (식별)

본 문서는 HongCafe Global Backend Auth 모듈의 인터페이스 설계를 MIL-STD-498 Interface Design Description (IDD) 표준에 따라 명세한다.

| 항목 | 내용 |
|------|------|
| 문서 ID | auth-idd |
| 대상 시스템 | Auth Module — HongCafe Global Backend |
| 기반 SDD | `auth-sdd.md` v2.0 |
| 인터페이스 총수 | 내부 4개 / 외부 1개 |
| EP 총수 | 4개 (`POST /api/auth/logout`, `POST /api/auth/refresh`, `GET /api/gate`, `GET /api/whoami`) |

### 1.2 System Overview (시스템 개요)

Auth 모듈은 HongCafe Global Backend Modular Monolith 아키텍처의 인증 기반 인프라다. JWT HttpOnly 쿠키 기반 인증(HMAC-SHA256, pure PHP), Token Rotation + Reuse Detection, Signed Double Submit Cookie CSRF 방어, MaxMind GeoLite2 기반 지역 서버 라우팅을 담당한다. AuthFilter를 통해 전체 모듈의 인증 상태를 검증하며, Member 모듈이 로그인 완료 후 `JwtService::createTokenPair()`를 호출한다.

### 1.3 Document Overview (문서 개요)

본 IDD는 MIL-STD-498 §DI-IPSC-81436 기준에 따라 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 기술한다.

| 섹션 | 내용 |
|------|------|
| §2 | 참조 문서 |
| §3 | 내부 인터페이스 4개 (IF-INT-001~004) — PHP 시그니처 포함 |
| §4 | 외부 인터페이스 1개 (IF-EXT-001) — 프로토콜/인증/파일 I/O 명세 |
| §5 | 이벤트 계약 (Events and Signals) |
| §6 | 에러 처리 계약 (Error Handling Contract) |
| §7 | 데이터 포맷 및 인코딩 (Data Formats and Encoding) |
| §8 | 타당성 검토 |
| §9 | 변경 영향 기록 |
| §10 | 요구사항 추적성 매트릭스 |

---

## 2. References (참조 문서)

| 문서 | 위치 / 출처 |
|------|-----------|
| MIL-STD-498 — Software Development and Documentation | US DoD Standards |
| DI-IPSC-81436 — Interface Design Description (IDD) | MIL-STD-498 Data Item |
| auth-srs.md v2.0 | `docs/specs/auth-srs.md` |
| auth-sdd.md v2.0 | `docs/specs/auth-sdd.md` |
| RFC 7519 — JSON Web Token (JWT) | IETF |
| RFC 7231 — HTTP/1.1 Semantics and Content | IETF |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| OWASP CSRF Prevention Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html |
| MaxMind GeoLite2 Database Documentation | https://dev.maxmind.com/geoip/docs/databases/city-and-country |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |

---

## 3. Internal Interfaces (내부 인터페이스)

MIL-STD-498 IDD §3 — 각 내부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-INT-001: JwtServiceInterface

#### 3.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | JwtServiceInterface |
| 파일 경로 | `app/Modules/Auth/Interfaces/JwtServiceInterface.php` |
| 제공 컴포넌트 | `JwtService` |
| 소비 컴포넌트 | `AuthController`, `AuthFilter` (전역 필터), Member 모듈 (로그인 처리) |

#### 3.1.2 Data Elements (데이터 요소)

**`encode(array $payload, int $expSeconds): string`**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$payload` | array | Y | JWT 페이로드. Access Token: `ac_id`, `cr_code`, `ac_nick`, `type`. Refresh Token: `ac_id`, `type`, `jti`, `family` |
| `$expSeconds` | int | Y | 만료까지 남은 초 (Access: 900, Refresh: 604800) |
| 반환 | string | — | Base64URL 인코딩된 JWT 문자열 (`header.payload.signature`) |

**`decode(string $token): ?array`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$token` | string | JWT 문자열 |
| 반환 | `?array` | 검증 성공 시 페이로드 배열. 서명 불일치 또는 `exp` 만료 시 `null` |

**`createTokenPair(array $userInfo): array`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$userInfo` | array | `ac_id`, `cr_code`, `ac_nick`, `ce_code`(선택) |
| 반환 | array | `['accessToken' => string, 'refreshToken' => string]` |

**`refreshTokenPair(string $refreshToken): ?array`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$refreshToken` | string | `hc_refresh` 쿠키 값 |
| 반환 | `?array` | 성공 시 `['accessToken' => string, 'refreshToken' => string]`. 만료/Reuse Detection 시 `null` |

**`revokeFamily(string $family): void`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$family` | string | Token Family UUID. 로그아웃 시 family 전체 무효화 |

#### 3.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Auth/Config/Services.php` |
| 헬퍼 | `service('jwtService')` |
| 알고리즘 | HMAC-SHA256 (`hash_hmac('sha256', ...)` PHP 내장). 외부 라이브러리 미사용 |

#### 3.1.4 Error Handling (에러 처리)

| 에러 조건 | 반환값 | 소비자 처리 |
|---------|-------|-----------|
| JWT 서명 불일치 | `null` | 401 `UNAUTHORIZED` 응답 |
| JWT `exp` 만료 | `null` | 401 `UNAUTHORIZED` 응답. 클라이언트 → `/api/auth/refresh` 호출 |
| Refresh Token `is_used=1` (Reuse Detection) | `null` (+ `deleteByFamily` 실행) | 401 `UNAUTHORIZED`. 전체 세션 무효화. 재로그인 필요 |
| jti+family 미존재 (변조) | `null` | 401 `UNAUTHORIZED` |

#### 3.1.5 Data Flow (데이터 흐름)

```
[Member 모듈 — 로그인]
  └─ JwtService::createTokenPair($userInfo)
        ├─ encode(accessPayload, 900) → accessToken
        ├─ encode(refreshPayload, 604800) → refreshToken
        └─ JwtTokenRepository::insertToken({ac_id, jti, family, expires_at})

[AuthController::refresh()]
  └─ JwtService::refreshTokenPair($refreshToken)
        ├─ decode($refreshToken) → payload {jti, family, ac_id, exp}
        ├─ JwtTokenRepository::findByJtiAndFamily(jti, family)
        │       → null → 401
        │       → is_used=1 → Reuse Detection → deleteByFamily(family) → null
        │       → is_used=0 → 정상 진행
        ├─ markUsed(jti)
        └─ createTokenPair(userInfo) → insertToken(newJti, family)

[AuthFilter — 전역]
  └─ JwtService::decode($_COOKIE['hc_access']) → payload or null
```

**PHP 시그니처:**

```php
interface JwtServiceInterface
{
    /**
     * JWT 토큰 생성 (Base64URL encode + HMAC-SHA256 서명).
     * @param array $payload 토큰 페이로드
     * @param int   $expSeconds 만료 시간 (초)
     * @return string JWT 문자열
     */
    public function encode(array $payload, int $expSeconds): string;

    /**
     * JWT 서명 검증 및 페이로드 반환.
     * @param string $token JWT 문자열
     * @return ?array 검증 성공 시 페이로드 배열. 실패 시 null
     */
    public function decode(string $token): ?array;

    /**
     * Access + Refresh Token Pair 생성 및 DB INSERT.
     * @param array $userInfo ac_id, cr_code, ac_nick 포함
     * @return array ['accessToken' => string, 'refreshToken' => string]
     */
    public function createTokenPair(array $userInfo): array;

    /**
     * Refresh Token 검증 → Reuse Detection → 새 Token Pair 발급.
     * @param string $refreshToken hc_refresh 쿠키 값
     * @return ?array 성공: ['accessToken' => string, 'refreshToken' => string]. 실패: null
     */
    public function refreshTokenPair(string $refreshToken): ?array;

    /**
     * Refresh Token family 전체 무효화 (로그아웃, Reuse Detection).
     * @param string $family Token Family UUID
     */
    public function revokeFamily(string $family): void;
}
```

---

### IF-INT-002: GeoRoutingServiceInterface

#### 3.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | GeoRoutingServiceInterface |
| 파일 경로 | `app/Modules/Auth/Interfaces/GeoRoutingServiceInterface.php` |
| 제공 컴포넌트 | `GeoRoutingService` |
| 소비 컴포넌트 | `GateController`, `WhoamiController` |

#### 3.2.2 Data Elements (데이터 요소)

**`resolveClientIp(): string`**

| 항목 | 내용 |
|------|------|
| 입력 | 없음 (내부에서 `X-Forwarded-For` 헤더 파싱) |
| 반환 | string — 실제 클라이언트 IP 주소 |

**`lookupIp(string $ip): array`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$ip` | string | 클라이언트 IP 주소 |
| 반환 | array | `['country' => string, 'lat' => ?float, 'lon' => ?float, 'timezone' => string]` |

GeoLite2 파일 미존재 또는 조회 실패 시 빈 배열(`[]`) 반환.

**`findNearestServer(?float $lat, ?float $lon, string $countryCode): array`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$lat` | `?float` | 클라이언트 위도 (null 허용) |
| `$lon` | `?float` | 클라이언트 경도 (null 허용) |
| `$countryCode` | string | ISO 국가 코드 (예: `KR`, `JP`, `US`) |
| 반환 | array | `['code' => string, 'url' => string, 'distanceKm' => float]` |

**`getServers(): array`**

| 반환 | 내용 |
|------|------|
| array | KR/JP/US 서버 목록. 각 서버: `{'code', 'url', 'lat', 'lon'}` |

**`getServerUrl(string $code): ?string`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$code` | string | 서버 코드 (`kr`, `jp`, `us`) |
| 반환 | `?string` | 서버 URL. 미존재 시 `null` |

#### 3.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Auth/Config/Services.php` (싱글턴) |
| 헬퍼 | `service('geoRoutingService')` |
| 외부 의존 | GeoLite2-City.mmdb 로컬 파일 (네트워크 호출 없음) |
| 파일 경로 | `writable/geoip/GeoLite2-City.mmdb` |

#### 3.2.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| GeoLite2 파일 없음 | `lookupIp()` → 빈 배열 반환. `findNearestServer()` → 기본 서버(KR) 폴백 |
| IP 조회 실패 (프라이빗 IP 등) | 빈 배열 반환. GateController에서 KR 서버 폴백 처리 |
| 잘못된 서버 코드 | `getServerUrl()` → `null` 반환 |

#### 3.2.5 Data Flow (데이터 흐름)

```
GateController::index()
  ├─ GeoRoutingService::resolveClientIp()
  │       └─ X-Forwarded-For 첫 번째 IP 파싱
  ├─ GeoRoutingService::lookupIp($ip)
  │       └─ GeoLite2-City.mmdb → {country, lat, lon, timezone}
  └─ GeoRoutingService::findNearestServer($lat, $lon, $country)
          └─ foreach servers: Haversine($lat, $lon, $svLat, $svLon)
                → min distance 서버 선택 → {code, url, distanceKm}

WhoamiController::index()
  └─ 동일 흐름 → 200 JSON 응답 (302 리다이렉트 없음)
```

**PHP 시그니처:**

```php
interface GeoRoutingServiceInterface
{
    /**
     * X-Forwarded-For 헤더에서 실제 클라이언트 IP 파싱.
     * @return string 클라이언트 IP
     */
    public function resolveClientIp(): string;

    /**
     * GeoLite2 mmdb에서 IP 지리정보 조회.
     * @param string $ip 클라이언트 IP
     * @return array ['country' => string, 'lat' => ?float, 'lon' => ?float, 'timezone' => string]
     *               파일 없음 또는 조회 실패 시 []
     */
    public function lookupIp(string $ip): array;

    /**
     * Haversine 거리 계산으로 최근접 서버 결정.
     * @param ?float  $lat         클라이언트 위도
     * @param ?float  $lon         클라이언트 경도
     * @param string  $countryCode ISO 국가 코드
     * @return array ['code' => string, 'url' => string, 'distanceKm' => float]
     */
    public function findNearestServer(?float $lat, ?float $lon, string $countryCode): array;

    /**
     * 전체 서버 목록 반환 (KR/JP/US).
     * @return array 각 서버: ['code', 'url', 'lat', 'lon']
     */
    public function getServers(): array;

    /**
     * 서버 코드 → URL 매핑.
     * @param string $code 서버 코드 (kr, jp, us)
     * @return ?string 서버 URL. 미존재 시 null
     */
    public function getServerUrl(string $code): ?string;
}
```

---

### IF-INT-003: JwtTokenRepositoryInterface

#### 3.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-003 |
| 인터페이스명 | JwtTokenRepositoryInterface |
| 파일 경로 | `app/Modules/Auth/Interfaces/JwtTokenRepositoryInterface.php` |
| 제공 컴포넌트 | `JwtTokenRepository` |
| 소비 컴포넌트 | `JwtService` (생성자 주입) |

#### 3.3.2 Data Elements (데이터 요소)

**`insertToken(array $data): int|string|bool`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$data` | array | `{ac_id: string, jti: string, family: string, expires_at: string(UTC datetime)}` |
| 반환 | `int\|string\|bool` | INSERT ID 또는 성공 여부 |

**`findByJtiAndFamily(string $jti, string $family): ?array`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$jti` | string | JWT ID (UUID v4) |
| `$family` | string | Token Family UUID |
| 반환 | `?array` | 레코드 배열 (`id`, `ac_id`, `jti`, `family`, `is_used`, `expires_at`). 미존재 시 `null` |

**`markUsed(string $jti): void`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$jti` | string | JWT ID. `is_used = 1` 설정 |

**`deleteByFamily(string $family): void`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$family` | string | Token Family UUID. family 전체 레코드 삭제 |

**`deleteByAccountId(int $accountId): void`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$accountId` | int | 계정 ID. 회원 탈퇴 시 해당 계정의 모든 Refresh Token 삭제 |

#### 3.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Auth/Config/Services.php` (생성자 주입) |
| DB 접근 | CI4 Query Builder. Aurora MySQL (RDS Proxy IAM Auth) |
| 대상 테이블 | `tb_refresh_token` |

#### 3.3.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| DB 쿼리 실패 | CI4 Database Exception 전파 → Controller 500 `INTERNAL` 응답 |
| `insertToken` 중복 jti | UNIQUE KEY 제약 위반 → Exception 전파 |
| `findByJtiAndFamily` 미존재 | `null` 반환 (예외 없음). JwtService에서 401 처리 |

**트랜잭션 범위 — `refreshTokenPair()`:**

```php
// markUsed + insertToken 원자 처리 (READ COMMITTED)
$db->transStart();
$repository->markUsed($jti);
$repository->insertToken(['jti' => $newJti, 'family' => $family, ...]);
$db->transComplete();
```

#### 3.3.5 Data Flow (데이터 흐름)

```
JwtService::createTokenPair()
  └─ JwtTokenRepository::insertToken({ac_id, jti, family, expires_at})
        └─ INSERT INTO tb_refresh_token (ac_id, jti, family, expires_at)

JwtService::refreshTokenPair()
  ├─ JwtTokenRepository::findByJtiAndFamily(jti, family)
  │       └─ SELECT * FROM tb_refresh_token WHERE jti=? AND family=?
  ├─ JwtTokenRepository::markUsed(jti)
  │       └─ UPDATE tb_refresh_token SET is_used=1 WHERE jti=?
  └─ JwtTokenRepository::insertToken({newJti, family, ...})
        └─ INSERT INTO tb_refresh_token ...

JwtService::revokeFamily()
  └─ JwtTokenRepository::deleteByFamily(family)
        └─ DELETE FROM tb_refresh_token WHERE family=?
```

**PHP 시그니처:**

```php
interface JwtTokenRepositoryInterface
{
    /**
     * Refresh Token 레코드 저장.
     * @param array $data {ac_id, jti, family, expires_at}
     * @return int|string|bool INSERT ID 또는 성공 여부
     */
    public function insertToken(array $data): int|string|bool;

    /**
     * jti + family 복합 조회 (Reuse Detection 핵심).
     * @param string $jti    JWT ID (UUID v4)
     * @param string $family Token Family UUID
     * @return ?array 레코드 배열. 미존재 시 null
     */
    public function findByJtiAndFamily(string $jti, string $family): ?array;

    /**
     * jti 사용 완료 처리 (is_used = 1).
     * @param string $jti JWT ID
     */
    public function markUsed(string $jti): void;

    /**
     * family 전체 Refresh Token 삭제 (로그아웃, Reuse Detection).
     * @param string $family Token Family UUID
     */
    public function deleteByFamily(string $family): void;

    /**
     * 특정 계정의 모든 Refresh Token 삭제 (회원 탈퇴).
     * @param int $accountId 계정 ID
     */
    public function deleteByAccountId(int $accountId): void;
}
```

---

### IF-INT-005: AuthFilter 컨텍스트 주입 계약 (v2.1 신규)

MIL-STD-498 IDD §3.5 — AuthFilter가 인증 성공 시 컨트롤러/후속 필터에 사용자 컨텍스트를 노출하는 계약.

#### 3.5.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-005 |
| 인터페이스명 | AuthFilter Context Injection Contract |
| 파일 경로 | `app/Filters/AuthFilter.php` |
| 제공 컴포넌트 | `AuthFilter::before()` |
| 소비 컴포넌트 | `RoleFilter`, `AuthController`, `MemberController` 등 모든 인증 필요 Controller. `BaseController::initController()` (JWT fallback 경로) |

#### 3.5.2 Data Elements (데이터 요소)

**저장소:** `$_SERVER['AUTH_USER']` (v2.1 — 기존 `$request->authUser` 동적 프로퍼티에서 전환)

**페이로드 구조:**

```php
$_SERVER['AUTH_USER'] = [
    'ac_id'   => string,  // 계정 식별자 (이메일)
    'cr_code' => string,  // 사용자 고유 코드
    'ac_nick' => string,  // 닉네임
    // 인증 방식에 따라 추가 필드 가능 (jwt/apikey/session)
];
```

**전환 이력 (v2.1):** PHP 8.4에서 `RequestInterface` 동적 프로퍼티 지정이 Deprecated 처리되어, 경고 제거 목적으로 `$_SERVER` 슈퍼글로벌로 이전. `$_SERVER`는 CI4 `Request` 수명주기와 독립되어 Filter → Controller → BaseController 전 구간에서 안정적으로 참조 가능하다.

#### 3.5.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 (필터 체인 선행 후 컨트롤러/후속 필터로 단방향 주입) |
| 수명주기 | 요청 단위. `$_SERVER`는 요청 종료 시 PHP가 자동 해제 |
| 쓰기 권한 | `AuthFilter::before()`에서만 1회 쓰기 |
| 읽기 권한 | 컨트롤러 / 후속 필터 읽기 전용 |

#### 3.5.4 Error Handling (에러 처리)

| 조건 | 처리 |
|------|------|
| 인증 실패 | `$_SERVER['AUTH_USER']` 미설정 상태로 401 UNAUTHORIZED 응답 후 체인 종료 |
| 동일 요청 내 재인증 시도 | AuthFilter가 한 번만 실행되므로 덮어쓰기 없음 |
| `$_SERVER['AUTH_USER']` 참조 시 미설정 | Controller는 `isset()` 확인 후 401 반환 (Member 모듈 `checkNeedLogin(true)` Layer 2 방어) |

#### 3.5.5 Flow Control / Sequencing

```
HTTP Request
  │
  ▼
[AuthFilter::before()]
  ├─ EXCLUDED_PATHS 매칭 확인 → 매칭 시 return null (공개 EP)
  ├─ 인증 방법별 시도 (jwt → apikey → session 순)
  │     └─ 성공 시: $_SERVER['AUTH_USER'] = $user; return null;
  │     └─ 실패 시: return 401 UNAUTHORIZED;
  │
  ▼
[RoleFilter::before()] (선택 — 'role:callee' 적용 라우트)
  └─ isset($_SERVER['AUTH_USER']['ac_id']) 확인 후 ce_code 검증
  │
  ▼
[Controller::method()]
  ├─ BaseController::initController — $_SERVER['AUTH_USER']['ac_id']로 $this->member fallback 로드
  └─ 비즈니스 로직 수행
```

#### 3.5.6 PHP 시그니처

```php
class AuthFilter implements FilterInterface
{
    public function before(RequestInterface $request, $arguments = null)
    {
        // ... 인증 시도 ...
        if ($user !== null) {
            // v2.1 — 동적 프로퍼티 대신 $_SERVER 사용
            $_SERVER['AUTH_USER'] = $user;
            return null;
        }
        // ... 401 반환 ...
    }
}
```

---

### IF-INT-004: CsrfTokenService (Cross-Cutting)

#### 3.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-004 |
| 인터페이스명 | CsrfTokenService (Cross-Cutting Concern) |
| 파일 경로 | `app/Modules/Shared/Services/CsrfTokenService.php` |
| 제공 모듈 | Shared 모듈 |
| 소비 컴포넌트 | `AuthController` (발급/삭제), `CsrfTokenFilter` (검증) |

#### 3.4.2 Data Elements (데이터 요소)

**`generate(): string`**

| 반환 | 내용 |
|------|------|
| string | HMAC-SHA256 서명이 포함된 CSRF 토큰. 형식: `{timestamp}.{nonce}.{hmac}` |

**`validate(string $token): bool`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$token` | string | `X-CSRF-TOKEN` 헤더 값 |
| 반환 | bool | 유효 시 `true`. HMAC 불일치, TTL 만료 시 `false` |

검증 흐름: `hash_equals(cookieValue, headerValue)` → HMAC-SHA256 서명 검증 → TTL(7200초) 만료 확인.

**`getCookieName(): string`**

반환: `'hc_csrf'`

**`getHeaderName(): string`**

반환: `'X-CSRF-TOKEN'`

**`getTtl(): int`**

반환: `7200` (초, 2시간)

#### 3.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | Shared 모듈 `Services.php` |
| 헬퍼 | `service('csrfTokenService')` |
| 알고리즘 | HMAC-SHA256 (`hash_hmac('sha256', ...)`) |
| 쿠키 속성 | `HttpOnly=false` (JS 읽기 필요), `Secure=true`, `SameSite=Lax`, `Max-Age=7200` |
| 비교 방식 | `hash_equals()` (타이밍 공격 방지) |

#### 3.4.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| `X-CSRF-TOKEN` 헤더 누락 | `CsrfTokenFilter` → 403 `CSRF_VALIDATION_FAILED` |
| 쿠키와 헤더 불일치 | `validate()` → `false` → 403 `CSRF_VALIDATION_FAILED` |
| HMAC 서명 불일치 | `validate()` → `false` → 403 `CSRF_VALIDATION_FAILED` |
| TTL 7200초 만료 | `validate()` → `false` → 403 `CSRF_TOKEN_EXPIRED` |

**CSRF 면제 경로** (`CsrfTokenFilter` EXCLUDED_PATHS):
- `api/auth/refresh` (토큰 갱신 — 쿠키 전용 흐름)
- `api/stripe/webhook` (서버-서버 통신)
- `api/pay/viewSimplepayPassword` (간편결제)
- FCM 관련 EP (서버-서버 통신)

#### 3.4.5 Data Flow (데이터 흐름)

```
[발급 — 로그인/Refresh 성공 시]
AuthController::refresh()
  └─ CsrfTokenService::generate() → token
        └─ Set-Cookie: hc_csrf={token}; HttpOnly=false; Secure; SameSite=Lax; Max-Age=7200

[검증 — POST/PUT/DELETE 요청 시]
CsrfTokenFilter::before()
  ├─ $_COOKIE['hc_csrf'] 읽기
  ├─ $_SERVER['HTTP_X_CSRF_TOKEN'] 읽기
  ├─ hash_equals(cookieValue, headerValue) 비교
  ├─ CsrfTokenService::validate(headerValue)
  │       ├─ HMAC 서명 검증
  │       └─ TTL 만료 확인
  └─ 실패 시 → 403 조기 반환

[삭제 — 로그아웃 시]
AuthController::logout()
  └─ Set-Cookie: hc_csrf=; Max-Age=0
```

**PHP 시그니처:**

```php
// CsrfTokenService (Shared 모듈 — 인터페이스 없음, 직접 서비스 등록)
class CsrfTokenService
{
    /** CSRF 토큰 생성 (HMAC-SHA256 서명 포함). */
    public function generate(): string;

    /**
     * CSRF 토큰 검증 (hash_equals + HMAC + TTL).
     * @param string $token X-CSRF-TOKEN 헤더 값
     * @return bool 유효 시 true
     */
    public function validate(string $token): bool;

    public function getCookieName(): string;  // 'hc_csrf'
    public function getHeaderName(): string;  // 'X-CSRF-TOKEN'
    public function getTtl(): int;            // 7200
}
```

---

## 4. External Interfaces (외부 인터페이스)

MIL-STD-498 IDD §4 — 각 외부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-EXT-001: MaxMind GeoLite2

#### 4.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | MaxMind GeoLite2-City 데이터베이스 |
| 대상 시스템 | GeoLite2-City.mmdb (로컬 파일) |
| 연동 컴포넌트 | `GeoRoutingService` |
| 용도 | IP 주소 → 국가/위도/경도/타임존 조회 |

#### 4.1.2 Data Elements (데이터 요소)

**조회 입력:**

| 항목 | 내용 |
|------|------|
| 파일 경로 | `writable/geoip/GeoLite2-City.mmdb` |
| 입력 데이터 | 클라이언트 IP 주소 (string) |
| mmdb 형식 | MaxMind DB 바이너리 형식 (PHP `geoip2/geoip2` 패키지 또는 내장 파서) |

**조회 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `country` | string | ISO 국가 코드 (예: `KR`, `JP`, `US`) |
| `lat` | ?float | 위도 (조회 실패 시 null) |
| `lon` | ?float | 경도 (조회 실패 시 null) |
| `timezone` | string | 타임존 (예: `Asia/Seoul`) |

#### 4.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | 로컬 파일 I/O (mmdb 바이너리 읽기) |
| 네트워크 호출 | 없음 (완전 오프라인) |
| 인증 방식 | 없음 (로컬 파일 접근 권한) |
| 타임아웃 | 해당 없음 (파일 I/O — 1ms 이내) |
| 재시도 정책 | 없음 (파일 I/O 실패 → 빈 배열 반환 즉시) |
| 인스턴스 전략 | CI4 Services.php 싱글턴 등록 — 요청당 1회 파일 핸들 오픈 보장 |

#### 4.1.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 | 소비자 대응 |
|---------|---------|-----------|
| mmdb 파일 미존재 (`writable/geoip/GeoLite2-City.mmdb` 없음) | `lookupIp()` → 빈 배열 반환 + WARNING 로그 | GateController → 기본 서버(KR) 폴백 302 |
| 프라이빗/루프백 IP (조회 불가) | 빈 배열 반환 | GateController → 기본 서버(KR) 폴백 302 |
| mmdb 형식 오류 (파일 손상) | 빈 배열 반환 + ERROR 로그 | GateController → 기본 서버(KR) 폴백 302 |

#### 4.1.5 Data Flow (데이터 흐름)

```
GeoRoutingService::lookupIp($ip)
  ├─ GeoLite2-City.mmdb 파일 존재 확인
  │       └─ 없음 → [] 반환 + WARNING 로그
  ├─ mmdb Reader::city($ip)
  │       └─ 성공: {country, lat, lon, timezone}
  │       └─ 실패: [] 반환
  └─ 반환: ['country' => 'KR', 'lat' => 37.5665, 'lon' => 126.9780, 'timezone' => 'Asia/Seoul']

GeoRoutingService::findNearestServer($lat, $lon, $countryCode)
  ├─ getServers() → [{code:'kr', url:'https://prd.gl.hongcafe.com', lat:37.5665, lon:126.9780}, ...]
  ├─ foreach server: Haversine($lat, $lon, $svLat, $svLon) → distanceKm
  └─ argmin(distanceKm) → {code:'kr', url:'https://prd.gl.hongcafe.com', distanceKm: 0.0}
```

**Haversine 공식 (지구 반경 R=6371km):**

```php
// 두 좌표 간 대원 거리 계산
$deltaLat = deg2rad($lat2 - $lat1);
$deltaLon = deg2rad($lon2 - $lon1);
$a = sin($deltaLat / 2) ** 2
   + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($deltaLon / 2) ** 2;
$distanceKm = 2 * 6371 * asin(sqrt($a));
```

---

## 5. Events and Signals (이벤트 계약)

MIL-STD-498 IDD §5 — Auth 모듈의 이벤트 발행/구독 계약.

| 이벤트명 | 발행 모듈 | 구독 모듈 | 페이로드 | 설명 |
|---------|----------|----------|---------|------|
| — | — | — | — | Auth 모듈은 외부 이벤트(Outbox/SNS/SQS)를 발행하지 않음 |

**설명:** Auth 모듈은 인증 기반 인프라로서 이벤트 발행 책임을 갖지 않는다. 로그아웃, 토큰 갱신, Reuse Detection 발동은 동기 DB 트랜잭션으로 처리되며, 비동기 이벤트 브로커(Outbox 패턴)를 통하지 않는다. 회원 탈퇴 시 `deleteByAccountId()` 호출은 Member 모듈이 JwtService 인터페이스를 통해 직접 호출하는 동기 방식이다.

---

## 6. Error Handling Contract (에러 처리 계약)

MIL-STD-498 IDD §6 — Auth 모듈 전체 에러 처리 테이블.

| 에러 조건 | HTTP 코드 | 에러 코드 | 발생 위치 | 소비자 대응 |
|---------|---------|---------|---------|-----------|
| JWT 누락 (`hc_access` 쿠키 없음) | 401 | `UNAUTHORIZED` | `AuthFilter` | 클라이언트 → `POST /api/auth/refresh` 호출 |
| JWT 서명 불일치 / `exp` 만료 | 401 | `UNAUTHORIZED` | `AuthFilter` / `JwtService::decode()` | 클라이언트 → `POST /api/auth/refresh` 호출 |
| Refresh Token 만료 | 401 | `UNAUTHORIZED` | `AuthController::refresh()` | 재로그인 필요 |
| Refresh Token 미존재 (jti 변조) | 401 | `UNAUTHORIZED` | `JwtService::refreshTokenPair()` | 재로그인 필요 |
| Reuse Detection 발동 | 401 | `UNAUTHORIZED` | `JwtService::refreshTokenPair()` | family 전체 세션 무효화. 재로그인 필요 |
| CSRF 토큰 헤더 누락 | 403 | `CSRF_VALIDATION_FAILED` | `CsrfTokenFilter` | 페이지 새로고침 후 재시도 (hc_csrf 쿠키 재취득) |
| CSRF 쿠키-헤더 불일치 | 403 | `CSRF_VALIDATION_FAILED` | `CsrfTokenFilter` | 쿠키/헤더 값 확인 |
| CSRF HMAC 서명 불일치 | 403 | `CSRF_VALIDATION_FAILED` | `CsrfTokenFilter` | 토큰 위변조 의심. 재로그인 권장 |
| CSRF 토큰 TTL 만료 (7200초) | 403 | `CSRF_TOKEN_EXPIRED` | `CsrfTokenFilter` | 토큰 갱신 (`/api/auth/refresh`) 후 재시도 |
| Rate Limit 초과 (60 req/60s) | 429 | `TOO_MANY_REQUESTS` | `ratelimit` 필터 | `Retry-After` 헤더 참조 후 재시도 |
| 허용되지 않은 역할 (RoleFilter) | 403 | `FORBIDDEN` | `RoleFilter` | 권한 확인. 상담사(ce_code) 전용 EP 접근 차단 |
| `?country=` 파라미터 whitelist 위반 | 302 폴백 | — | `GateController` | KR 서버로 폴백 리다이렉트 |
| GeoLite2 파일 없음 | 302 폴백 | — | `GeoRoutingService` | KR 서버로 폴백 리다이렉트 |
| DB 쿼리 실패 | 500 | `INTERNAL` | Repository | 서버 로그 확인 |

---

## 7. Data Formats and Encoding (데이터 포맷 및 인코딩)

MIL-STD-498 IDD §7 — 인터페이스 데이터 포맷, DTO, 인코딩 규칙을 명세한다.

### 7.1 공통 인코딩 규칙

| 항목 | 규칙 |
|------|------|
| 문자 인코딩 | UTF-8 (utf8mb4) 전 레벨 통일 |
| 날짜/시각 | UTC 기준. DB: `DATETIME`. API 응답: ISO 8601 (`YYYY-MM-DD HH:MM:SS`) |
| API 응답 키 | DB `snake_case` → API `camelCase` 변환 필수 (`created_at` → `createdAt`) |
| 성공 응답 | `{ "data": {...} }` (HTTP 200/201) |
| 에러 응답 | `{ "error": { "code": "...", "message": "..." } }` (HTTP 4xx/5xx) |

### 7.2 JWT Access Token Payload

| 필드 | 타입 | 설명 |
|------|------|------|
| `ac_id` | string | 사용자 이메일 주소 (계정 식별자) |
| `cr_code` | string | 사용자 고유 코드 (`CR-YYYYMMDDHHmmss-XXX`) |
| `ac_nick` | string | 닉네임 |
| `type` | string | `"access"` (고정값) |
| `iat` | int | 발급 시각 (Unix timestamp, UTC) |
| `exp` | int | 만료 시각 (`iat + 900`) |

```json
{
    "ac_id": "user@example.com",
    "cr_code": "CR-20260415143022-A7B",
    "ac_nick": "홍길동",
    "type": "access",
    "iat": 1744704000,
    "exp": 1744704900
}
```

### 7.3 JWT Refresh Token Payload

| 필드 | 타입 | 설명 |
|------|------|------|
| `ac_id` | string | 사용자 이메일 주소 |
| `type` | string | `"refresh"` (고정값) |
| `jti` | string | 토큰 고유 ID (UUID v4) |
| `family` | string | Token Rotation 체인 ID (UUID v4) |
| `iat` | int | 발급 시각 (Unix timestamp, UTC) |
| `exp` | int | 만료 시각 (`iat + 604800`) |

```json
{
    "ac_id": "user@example.com",
    "type": "refresh",
    "jti": "550e8400-e29b-41d4-a716-446655440000",
    "family": "c73bcdcc-2669-4bf6-81d3-e4a2d0ec2e96",
    "iat": 1744704000,
    "exp": 1745308800
}
```

### 7.4 쿠키 명세

| 쿠키명 | Max-Age | Path | HttpOnly | Secure | SameSite | 설명 |
|--------|---------|------|----------|--------|----------|------|
| `hc_access` | 900 | `/` | true | true | Lax | Access Token (15분) |
| `hc_refresh` | 604800 | `/api/auth/refresh` | true | true | Lax | Refresh Token (7일). Refresh EP에만 전송 |
| `hc_csrf` | 7200 | `/` | false | true | Lax | CSRF 토큰 (2시간). JS 읽기 필요 |
| `hc_region` | 2592000 | `/` | false | false | Lax | 지역 라우팅 캐시 (30일) |

### 7.5 API 응답 예시

**POST /api/auth/refresh — 성공 (HTTP 200):**

```json
// Set-Cookie: hc_access={jwt}; Max-Age=900; Path=/; HttpOnly; Secure; SameSite=Lax
// Set-Cookie: hc_refresh={jwt}; Max-Age=604800; Path=/api/auth/refresh; HttpOnly; Secure; SameSite=Lax
// Set-Cookie: hc_csrf={csrf_token}; Max-Age=7200; Path=/; Secure; SameSite=Lax
{
    "data": {}
}
```

**POST /api/auth/logout — 성공 (HTTP 200):**

```json
// Set-Cookie: hc_access=; Max-Age=0; Path=/
// Set-Cookie: hc_refresh=; Max-Age=0; Path=/api/auth/refresh
// Set-Cookie: hc_csrf=; Max-Age=0; Path=/
{
    "data": {}
}
```

**POST /api/auth/refresh — Reuse Detection (HTTP 401):**

```json
{
    "error": {
        "code": "UNAUTHORIZED",
        "message": "Invalid or expired refresh token."
    }
}
```

**GET /api/gate — 정상 (HTTP 302):**

```
Location: https://prd.gl.hongcafe.com
Set-Cookie: hc_region=kr; Max-Age=2592000; Path=/; SameSite=Lax
```

**GET /api/whoami — 정상 (HTTP 200):**

```json
{
    "data": {
        "ip": "211.49.0.1",
        "method": "GET",
        "uri": "/api/whoami",
        "geo": {
            "country": "KR",
            "lat": 37.5665,
            "lon": 126.9780,
            "timezone": "Asia/Seoul"
        },
        "server": {
            "code": "kr",
            "url": "https://prd.gl.hongcafe.com",
            "distanceKm": 12.5
        },
        "headers": {
            "X-Forwarded-For": "211.49.0.1",
            "X-Forwarded-Proto": "https"
        },
        "timestamp": "2026-04-15 14:30:00"
    }
}
```

### 7.6 tb_refresh_token 스키마 (IF-INT-003 참조)

```sql
CREATE TABLE tb_refresh_token (
    id          BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    ac_id       VARCHAR(256)        NOT NULL            COMMENT '사용자 이메일 (계정 식별자)',
    jti         VARCHAR(36)         NOT NULL            COMMENT 'UUID v4 — JWT ID (고유 식별자)',
    family      VARCHAR(36)         NOT NULL            COMMENT 'UUID v4 — Token Rotation 체인 ID',
    is_used     TINYINT(1)          NOT NULL DEFAULT 0  COMMENT '0=미사용, 1=사용완료 (Reuse Detection)',
    expires_at  DATETIME            NOT NULL            COMMENT 'UTC 만료 시각 (iat + 604800초)',
    created_at  DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_jti (jti),
    INDEX idx_family (family),
    INDEX idx_ac_id  (ac_id),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='JWT Refresh Token 저장. Token Rotation + Reuse Detection 지원';
```

---

## 8. Feasibility Review (타당성 검토)

> 근거: RFC 7519 (JWT), OWASP API Security Top 10 2023, OWASP CSRF Prevention Cheat Sheet, MaxMind GeoLite2 공식 문서, MIL-STD-498

| 검토 ID | 검토 항목 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|----------|------|------|------|------------|
| FEA-001 | **Pure PHP JWT (외부 라이브러리 미사용)** | 타당 | RFC 7519 HS256 명세 — `HMAC(SHA-256, base64url(header) + "." + base64url(payload), secret)`. PHP 내장 `hash_hmac('sha256', ...)` + `base64_encode()`로 완전 구현 가능. 의존성 최소화 (OWASP A06:2021 Vulnerable Components 대응) | `firebase/php-jwt` (RS256 포함) | 내장 구현: 의존성 없음↑, 알고리즘 선택 제한. 외부 라이브러리: RS256/ES256 지원, 의존성 추가 — 현행 HMAC-SHA256 충분 |
| FEA-002 | **Token Family Rotation + Reuse Detection** | 타당 | OWASP JSON Web Token Cheat Sheet — "Refresh Token Rotation: issue a new refresh token every time one is used. If a token is used twice, consider it compromised." RFC 6819 §5.2.2 — "Refresh Token Rotation" 보안 권고 | 단순 만료 기반 Refresh Token | Rotation: 탈취 감지↑, DB 조회 추가. 단순 만료: 구현 단순, 탈취된 토큰이 만료 전까지 사용 가능 |
| FEA-003 | **Signed Double Submit Cookie CSRF** | 타당 | OWASP CSRF Prevention Cheat Sheet — "Signed Double Submit Cookie: a variation where the CSRF token is signed with a secret to prevent forgery." `hash_equals()`로 타이밍 공격 방지. SameSite=Lax 병행 (Defense in Depth) | CI4 내장 CSRF (Session 기반) | Signed Double Submit: Stateless JWT 완전 호환. CI4 내장: Session 의존 → stateless JWT와 불일치 → 현행 커스텀 구현 필수 |
| FEA-004 | **GeoLite2 로컬 mmdb 파일 I/O** | 타당 | MaxMind GeoLite2 공식 문서 — mmdb 바이너리 형식은 `O(1)` 조회 성능. PHP Reader 인스턴스 싱글턴 등록 시 요청당 파일 핸들 재사용. 파일 I/O 지연 1ms 이내 (SRS NFR-009) | MaxMind GeoIP2 API (유료, 네트워크) | 로컬 파일: 응답 속도↑ (< 1ms), 네트워크 의존 없음. API: 항상 최신 DB, 유료 + 네트워크 지연 → 현행 로컬 적합 |
| FEA-005 | **`hc_refresh` Path=/api/auth/refresh 제한** | 타당 | RFC 6265 Cookie Path 명세 — Path 속성으로 쿠키 전송 범위 제한. Refresh Token을 갱신 EP에만 전송하여 XSS 등으로 인한 불필요한 토큰 노출 최소화. OWASP API2:2023 Broken Authentication 대응 | Path=/ (전체 경로) | Path 제한: 공격 표면 감소↑. Path=/: 모든 요청에 전송 → 불필요한 노출 증가 |

**타당성 검토 결론**: JWT Pure PHP 구현, Token Family Rotation, Signed Double Submit Cookie CSRF, GeoLite2 로컬 파일 전략 모두 RFC 7519, OWASP 공식 가이드라인 및 MaxMind 공식 문서 기반으로 타당성 검증 완료.

---

## 9. Change Impact Log (변경 영향 기록)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|----------|----------|--------|----------|
| MIL-STD-498 IDD 표준 전면 전환 (v1.0 → v2.0) | 전체 문서 구조 재편 | Scope(§1), References(§2), 인터페이스별 5-subsection(식별자/데이터/통신/에러/흐름) 완전 적용. Events(§5), Error Handling Contract(§6), DataFormats(§7), Feasibility Review(§8), Requirements Traceability(§10) 신설 | 글로벌 지침 IDD 형식 요구사항 준수. v1.0은 테이블 나열 수준으로 MIL-STD-498 §DI-IPSC-81436 미충족 |
| 인터페이스별 5-subsection 구조화 | IF-INT-001~004, IF-EXT-001 전체 | 식별자/데이터/통신속성/에러처리/데이터흐름 5항목 완전 기술. PHP 시그니처 전체 추가. 구현자 단독 참조 가능한 완결성 확보 | MIL-STD-498 DI-IPSC-81436 IDD 요건 준수. 기존 v1.0은 메서드 계약만 1줄 나열 |
| Error Handling Contract 전체 테이블 신설 (§6) | 신규 섹션 | 에러 조건 12건 전체 HTTP 코드/에러 코드/발생 위치/소비자 대응 명세. v1.0의 단편적 에러 기술 통합 | 에러 처리 단일 참조점 제공. 소비자(Frontend, 타 모듈)의 에러 대응 명확화 |
| Data Formats 확장 (§7) | 기존 §6 데이터 포맷 확장 | 공통 인코딩 규칙, JWT Payload JSON 예시, 쿠키 명세 전체(4종), API 응답 JSON 예시 5종, tb_refresh_token DDL 추가 | 구현자 코딩 표준 단일 참조 가능. 기존 v1.0은 payload 필드 표 수준 |
| Feasibility Review 신설 (§8) | 신규 섹션 | Pure PHP JWT, Token Rotation, CSRF, GeoLite2 설계 결정 5건에 대한 공식 문서 근거 제시 | 글로벌 지침 — "타당성 검토" 섹션 모든 설계 산출물에 필수. 근거 없는 주장은 지침 위반 |
| Requirements Traceability Matrix 신설 (§10) | 신규 섹션 | SRS FR/NFR → IDD 인터페이스 매핑 10건. 인터페이스 누락 방지 | MIL-STD-498 DI-IPSC-81436 추적성 요건 준수 |

### 9.2 v2.1 반영 (2026-04-17)

| # | 변경 항목 | 영향 범위 | 개선점 | 수행 이유 (Why) |
|---|----------|----------|--------|----------------|
| 1 | IF-INT-005 신규 — AuthFilter Context Injection Contract | 내부 인터페이스 | `$_SERVER['AUTH_USER']` 저장소 계약을 5-subsection으로 명문화. 소비 컴포넌트(RoleFilter, Controller, BaseController) 전수 기술 | 커밋 `fbbf0a9` — BaseController JWT fallback이 의존하는 계약. 모듈 간 암묵적 연결을 IDD에 정식 기술 필요 |
| 2 | IF-INT-005 §3.5.2 — `$request->authUser` → `$_SERVER['AUTH_USER']` 전환 명시 | 데이터 요소 | PHP 8.4 동적 프로퍼티 Deprecated 회피 이력 + 전환 근거 기록 | 커밋 `fbbf0a9` — AuthFilter/RoleFilter 동시 수정. 향후 리팩터링 시 정황 보존 |
| 3 | FR-001 Traceability 보강 — logout 라우트 필터 `auth` 추가 | §10 추적성 매트릭스 | 로그아웃의 필터 체인 진입점을 인터페이스 계약에 명시 | 커밋 `c6b8a5e` — logout 라우트 등록 변경(`['filter' => 'auth']`) 추적성 반영 |
| 4 | Requirements Traceability Matrix — NFR-011, NFR-012 추가 | §10 | NFR-011(AUTH_USER 저장소) ↔ IF-INT-005, NFR-012(필터 체인 2계층) ↔ IF-INT-005 + Member 컨트롤러 연계 기술 | SRS v2.1 신규 NFR을 IDD 추적성에 동기화 |

---

## 10. Requirements Traceability Matrix (요구사항 추적성 매트릭스)

MIL-STD-498 DI-IPSC-81436 §10 — SRS FR/NFR과 IDD 인터페이스 간 추적성.

| SRS 요구사항 ID | 요구사항명 | 연관 인터페이스 | 인터페이스 타입 |
|---------------|---------|-------------|-------------|
| FR-001 | 로그아웃 | IF-INT-001 (`JwtService::revokeFamily`), IF-INT-003 (`deleteByFamily`), IF-INT-004 (`CsrfTokenService` — 쿠키 삭제), **IF-INT-005 (v2.1 — 라우트 필터 `auth` 통과 후 AUTH_USER 주입)** | 내부 |
| FR-002 | Access Token 갱신 | IF-INT-001 (`JwtService::refreshTokenPair`), IF-INT-003 (`findByJtiAndFamily`, `markUsed`, `insertToken`), IF-INT-004 (`CsrfTokenService::generate`) | 내부 |
| FR-003 | Token Rotation 및 Reuse Detection | IF-INT-001 (`JwtService::refreshTokenPair` 내부), IF-INT-003 (`findByJtiAndFamily`, `deleteByFamily`) | 내부 |
| FR-004 | 지역 기반 서버 라우팅 (Geo Routing) | IF-INT-002 (`GeoRoutingService::resolveClientIp`, `lookupIp`, `findNearestServer`), IF-EXT-001 (GeoLite2 mmdb) | 내부+외부 |
| FR-005 | 요청 컨텍스트 반환 (Whoami) | IF-INT-002 (`GeoRoutingService::resolveClientIp`, `lookupIp`, `findNearestServer`, `getServers`) | 내부 |
| FR-006 | CSRF Token 관리 | IF-INT-004 (`CsrfTokenService::generate`, `validate`, `getCookieName`) | 내부 |
| NFR-002 | Access Token 만료 시간 (900초) | IF-INT-001 (`encode(payload, 900)`) | 내부 |
| NFR-003 | Refresh Token 만료 시간 (604800초) | IF-INT-001 (`encode(payload, 604800)`), IF-INT-003 (`insertToken` — `expires_at`) | 내부 |
| NFR-004 | CSRF Token TTL (7200초) | IF-INT-004 (`getTtl(): 7200`) | 내부 |
| NFR-005 | JWT 서명 알고리즘 (HMAC-SHA256) | IF-INT-001 (`encode`/`decode` — `hash_hmac('sha256', ...)`) | 내부 |
| NFR-006 | 쿠키 보안 속성 | IF-INT-001 (Token Pair 반환 후 Controller가 Set-Cookie 설정), IF-INT-004 (hc_csrf 쿠키 속성) | 내부 |
| NFR-009 | GeoLite2 DB 조회 1ms 이내 | IF-EXT-001 (로컬 파일 I/O, 싱글턴 인스턴스) | 외부 |
| NFR-010 | Reuse Detection 즉시 대응 | IF-INT-001 (`refreshTokenPair` — 동일 트랜잭션 내 `deleteByFamily`), IF-INT-003 (`deleteByFamily`) | 내부 |
| **NFR-011** (v2.1) | **`$_SERVER['AUTH_USER']` 저장소** | **IF-INT-005 (AuthFilter Context Injection Contract)** | **내부** |
| **NFR-012** (v2.1) | **인증 필요 EP 필터 체인 2계층 방어** | **IF-INT-005 + Member 컨트롤러 `checkNeedLogin(true)`** | **내부** |

---

## 11. Document History (변경 로그)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | 1.0.0 | 초기 작성 | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 IDD 표준 전면 전환. Scope/References/인터페이스별 5-subsection(IF-INT 4개/IF-EXT 1개)/Events/Error Handling Contract/Data Formats(JWT Payload JSON 예시+쿠키 명세+API 응답 예시)/Feasibility Review(5건)/Requirements Traceability Matrix(13건) 신설 | jypark |
| 2026-04-17 | 2.1.0 | IF-INT-005 AuthFilter Context Injection Contract 신규 추가 (`$_SERVER['AUTH_USER']` 저장소 계약). Requirements Traceability Matrix에 NFR-011/NFR-012 추가 및 FR-001 라우트 필터 `auth` 반영. Change Impact Log §9.2 신설(4건). 커밋 `c6b8a5e`, `fbbf0a9`, `7e04106` 반영. 3-Round IEEE Review PASS | jypark |
