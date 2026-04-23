---
문서명: Auth — Software Design Document
문서 ID: auth-sdd
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-17
작성자: jypark
대상 시스템: Auth Module
관련 문서: auth-srs.md (v2.1), auth-idd.md (v2.1), auth-std.md (v1.1), member-sdd.md (v2.1)
적용 표준: IEEE 1016-2009
---

# Auth — Software Design Document (SDD)

> IEEE 1016-2009 | version: 2.1 | lastUpdated: 2026-04-17 | module: Auth

---

## 1. Introduction

### 1.1 Purpose

본 Software Design Document(SDD)는 HongCafe Global Backend Auth 모듈의 소프트웨어 설계를 IEEE 1016-2009 표준의 8개 Viewpoint로 기술한다. 본 문서는 auth-srs.md v2.0의 기능 요구사항을 구현 가능한 설계 명세로 변환한다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 모듈(BC) | Auth |
| 기반 SRS | `auth-srs.md` v2.1 |
| 관련 IDD | `auth-idd.md` v2.1 |
| 설계 범위 | AuthController, GateController, WhoamiController, JwtService, GeoRoutingService, JwtTokenRepository 및 관련 Config/Interface |

### 1.3 References

| 문서 | 경로/출처 |
|------|---------|
| 요구사항 문서 | `docs/specs/auth-srs.md` v2.1 |
| 인터페이스 문서 | `docs/specs/auth-idd.md` v2.1 |
| 프로젝트 지침 | `CLAUDE.md` |
| IEEE 1016-2009 | IEEE Std 1016-2009 — Standard for Information Technology—Systems Design—Software Design Descriptions |

---

## 2. Stakeholders and Design Concerns

| 이해관계자 | 역할 | 주요 관심사 |
|-----------|------|-----------|
| Backend Developer | Auth 모듈 구현 | 클래스 구조, 메서드 시그니처, 데이터 흐름 |
| Security Reviewer | 보안 감사 | JWT 구현, CSRF 방어, 쿠키 속성, Reuse Detection |
| DevOps | 배포/운영 | DB 스키마, 인덱스 전략, 환경변수 의존성 |
| Frontend Developer | API 소비 | 쿠키 설정 방식, 에러 코드, 응답 포맷 |
| Other Module Developer | JwtService 소비 | Interface 계약, DI 등록 방식 |

---

## 3. Design Viewpoints

### VP-1: Context Viewpoint (시스템 맥락)

Auth 모듈은 HongCafe Global Backend의 인증 기반 인프라다. 외부 시스템과의 경계를 정의한다.

```
                        ┌─────────────────────────────────────────┐
                        │         HongCafe Global Backend          │
                        │                                          │
  [Browser/Client]──── HTTP/HTTPS ────► [Nginx] ──► [PHP-FPM]    │
        │                                                  │       │
        │ Cookie: hc_access, hc_refresh, hc_csrf           │       │
        │ Header: X-CSRF-TOKEN, X-Forwarded-For             │       │
        │                                            [Auth Module] │
        │                                            JwtService    │
        │                                            GeoRouting    │
        │                                                  │       │
        │                                          ┌───────▼────┐  │
        │                                          │ Aurora MySQL│  │
        │                                          │ tb_refresh_ │  │
        │                                          │ token       │  │
        │                                          └────────────┘  │
  [MaxMind GeoLite2] ◄── local file I/O ─── GeoRoutingService     │
  (writable/geoip/                                                 │
   GeoLite2-City.mmdb)                                             │
                        └─────────────────────────────────────────┘
```

**외부 경계**:
- MaxMind GeoLite2: 로컬 파일 I/O (네트워크 호출 없음)
- Aurora MySQL: RDS Proxy IAM Auth 경유

### VP-2: Composition Viewpoint (구성 요소)

```text
app/Modules/Auth/
├── Controllers/
│   ├── AuthController.php          로그아웃(logout), 토큰 갱신(refresh)
│   ├── GateController.php          지역 라우팅(index)
│   └── WhoamiController.php        요청 컨텍스트(index)
├── Services/
│   ├── JwtService.php              JWT 생성/검증, Token Rotation, Family 관리
│   └── GeoRoutingService.php       IP 지오로케이션, Haversine 거리 계산, 서버 매핑
├── Repositories/
│   └── JwtTokenRepository.php      Refresh Token CRUD (tb_refresh_token)
├── Interfaces/
│   ├── JwtServiceInterface.php     Auth 모듈 외부 노출 계약
│   ├── JwtTokenRepositoryInterface.php
│   └── GeoRoutingServiceInterface.php
└── Config/
    ├── Routes.php                  4개 EP 명시적 등록
    └── Services.php                DI 바인딩 (JwtService, GeoRoutingService, JwtTokenRepository)
```

**컴포넌트 책임 분리**:

| 컴포넌트 | 책임 | 의존 대상 |
|---------|------|---------|
| AuthController | HTTP 요청/응답 처리. 비즈니스 로직 위임 | JwtService, CsrfTokenService |
| GateController | Geo Routing 흐름 조율 | GeoRoutingService |
| WhoamiController | 컨텍스트 수집 + 직렬화 | GeoRoutingService |
| JwtService | JWT 생성/검증/Rotation. 보안 핵심 | JwtTokenRepository |
| GeoRoutingService | GeoLite2 조회, Haversine 계산, 서버 선택 | 없음 (외부 파일) |
| JwtTokenRepository | tb_refresh_token CRUD. DB 접근 단일 책임 | Aurora MySQL |

### VP-3: Logical Viewpoint (논리 설계)

#### 3-1. Controller Layer

| 클래스 | 메서드 | HTTP | URL | 인증 | 설명 |
|--------|--------|------|-----|------|------|
| `AuthController` | `logout()` | POST | `/api/auth/logout` | JWT 필수 | family 삭제 + 쿠키 무효화 + CSRF 삭제 + 세션 클리어 |
| `AuthController` | `refresh()` | POST | `/api/auth/refresh` | 공개 (CSRF 면제) | Refresh Token 검증 → 새 Token Pair + CSRF 발급 |
| `GateController` | `index()` | GET | `/api/gate` | 공개 | 수동→캐시→IP 순서 지역 판별, 302 리다이렉트 |
| `WhoamiController` | `index()` | GET | `/api/whoami` | 공개 | IP, headers, geo, server, timestamp 반환 |

#### 3-2. Service Layer

| 클래스 | 메서드 시그니처 | 설명 |
|--------|--------------|------|
| `JwtService` | `encode(array $payload, int $expSeconds): string` | JWT 생성 (base64url + HMAC-SHA256 서명) |
| `JwtService` | `decode(string $token): ?array` | JWT 검증 (서명 + exp). 실패 시 null |
| `JwtService` | `createTokenPair(array $userInfo): array` | Access(900s) + Refresh(604800s) 쌍 생성 + DB INSERT |
| `JwtService` | `refreshTokenPair(string $refreshToken): ?array` | Reuse Detection + 새 Token Pair (FR-002, FR-003) |
| `JwtService` | `revokeFamily(string $family): void` | family 전체 삭제 (로그아웃, FR-001) |
| `GeoRoutingService` | `resolveClientIp(): string` | X-Forwarded-For 파싱 → 실제 클라이언트 IP |
| `GeoRoutingService` | `lookupIp(string $ip): array` | GeoLite2 mmdb 조회 → `{country, lat, lon, timezone}` |
| `GeoRoutingService` | `findNearestServer(?float $lat, ?float $lon, string $countryCode): array` | Haversine 거리 계산 → 최근접 서버 `{code, url, distanceKm}` |
| `GeoRoutingService` | `getServers(): array` | KR/JP/US 서버 목록 + 좌표 반환 |
| `GeoRoutingService` | `getServerUrl(string $code): ?string` | 서버 코드 → URL 매핑 |

#### 3-3. Repository Layer

| 클래스 | 메서드 시그니처 | 쿼리 유형 | 설명 |
|--------|--------------|----------|------|
| `JwtTokenRepository` | `insertToken(array $data): int\|string\|bool` | INSERT | Refresh Token 저장 (ac_id, jti, family, expires_at) |
| `JwtTokenRepository` | `findByJtiAndFamily(string $jti, string $family): ?array` | SELECT | jti + family 복합 조회 (Reuse Detection 핵심) |
| `JwtTokenRepository` | `markUsed(string $jti): void` | UPDATE | `is_used = 1` 설정 (사용 완료 처리) |
| `JwtTokenRepository` | `deleteByFamily(string $family): void` | DELETE | family 전체 삭제 (로그아웃, Reuse Detection) |
| `JwtTokenRepository` | `deleteByAccountId(int $accountId): void` | DELETE | 계정의 모든 Refresh Token 삭제 (회원 탈퇴) |

### VP-4: Dependency Viewpoint (의존성)

```
AuthController
    ├── service('jwtService') ──────► JwtService (JwtServiceInterface)
    │                                     └── JwtTokenRepository (JwtTokenRepositoryInterface)
    │                                              └── Aurora MySQL (tb_refresh_token)
    └── service('csrfTokenService') ──► CsrfTokenService (Shared 모듈)

GateController
    └── service('geoRoutingService') ── GeoRoutingService (GeoRoutingServiceInterface)
                                            └── GeoLite2-City.mmdb (로컬 파일)

WhoamiController
    └── service('geoRoutingService') ── GeoRoutingService

AuthFilter (전역 필터)
    └── service('jwtService') ──────► JwtService::decode()

CsrfTokenFilter (상태 변경 요청 필터)
    └── service('csrfTokenService') ── CsrfTokenService::validate()

RoleFilter (상담사 EP 필터)
    └── JWT payload.ce_code 확인
```

**DI 등록** (`app/Modules/Auth/Config/Services.php`):
```php
// JwtTokenRepository → JwtService → AuthController 순서로 등록
$services->bind(JwtTokenRepositoryInterface::class, JwtTokenRepository::class);
$services->bind(JwtServiceInterface::class, JwtService::class);
$services->bind(GeoRoutingServiceInterface::class, GeoRoutingService::class);
```

### VP-5: Information Viewpoint (정보 모델) — SQL DDL

#### tb_refresh_token

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

**ERD**:
```text
[tb_account] 1──N [tb_refresh_token]
  ac_id (VARCHAR 256) ◄─── ac_id (VARCHAR 256)
```

**인덱스 전략**:

| 인덱스명 | 컬럼 | 유형 | 카디널리티 | 사유 |
|---------|------|------|----------|------|
| `PK` | `id` | PRIMARY | HIGH | 자동 증가 PK |
| `uq_jti` | `jti` | UNIQUE | HIGH | jti 중복 방지 + `findByJtiAndFamily` 조회 최적화 |
| `idx_family` | `family` | BTREE | MEDIUM | `deleteByFamily`, `markUsed` 조회 최적화 |
| `idx_ac_id` | `ac_id` | BTREE | MEDIUM | `deleteByAccountId` 조회 최적화 |
| `idx_expires_at` | `expires_at` | BTREE | LOW | 만료 토큰 일괄 삭제 배치 최적화 |

### VP-6: Interface Viewpoint (인터페이스)

상세 인터페이스 명세는 `auth-idd.md` §3 참조. 주요 공개 계약 요약:

| 인터페이스 ID | 인터페이스명 | 제공 | 소비 | 핵심 메서드 |
|------------|------------|------|------|-----------|
| IF-INT-001 | JwtServiceInterface | Auth | Member, AuthFilter | `encode`, `decode`, `createTokenPair`, `refreshTokenPair`, `revokeFamily` |
| IF-INT-002 | GeoRoutingServiceInterface | Auth | GateController, WhoamiController | `lookupIp`, `findNearestServer`, `resolveClientIp` |
| IF-INT-003 | JwtTokenRepositoryInterface | Auth | JwtService | `insertToken`, `findByJtiAndFamily`, `markUsed`, `deleteByFamily`, `deleteByAccountId` |
| IF-INT-004 | CsrfTokenService | Shared | Auth, CsrfTokenFilter | `generate`, `validate`, `getCookieName` |
| IF-EXT-001 | MaxMind GeoLite2 | External | GeoRoutingService | 로컬 mmdb 파일 I/O |

### VP-7: Interaction Viewpoint (상호작용 시퀀스)

#### 시퀀스 1: 토큰 갱신 (정상 흐름 — FR-002, FR-003)

```
Client ──POST /api/auth/refresh──► AuthController::refresh()
                                        │
                                        ├─ $_COOKIE['hc_refresh'] 추출
                                        │
                                        ├─ JwtService::refreshTokenPair(token)
                                        │       │
                                        │       ├─ decode(token) → payload {jti, family, ac_id, exp}
                                        │       ├─ exp 만료 확인 → 만료 시 null 반환 → 401
                                        │       │
                                        │       ├─ JwtTokenRepository::findByJtiAndFamily(jti, family)
                                        │       │       → null: 401 (invalid jti)
                                        │       │       → is_used=1: Reuse Detection!
                                        │       │              deleteByFamily(family) → 401
                                        │       │       → is_used=0: 정상 진행 ↓
                                        │       │
                                        │       ├─ markUsed(jti)          [UPDATE is_used=1]
                                        │       ├─ createTokenPair(userInfo)
                                        │       │       insertToken(newJti, family)  [INSERT]
                                        │       └─ return [accessToken, refreshToken]
                                        │
                                        ├─ Set-Cookie: hc_access (Max-Age=900, HttpOnly)
                                        ├─ Set-Cookie: hc_refresh (Max-Age=604800, HttpOnly)
                                        ├─ CsrfTokenService::generate() → Set-Cookie: hc_csrf
                                        └─ 200 OK { "data": {} }
```

#### 시퀀스 2: 로그아웃 (정상 흐름 — FR-001)

```
Client ──POST /api/auth/logout──► [라우트 필터 'auth' 적용, v2.1]
                                   └─ AuthFilter::before()
                                         ├─ JWT 검증
                                         └─ 성공 시 $_SERVER['AUTH_USER'] = {ac_id, cr_code, ...} (v2.1)
                                              │
                                              ▼
                                   AuthController::logout()
                                       ├─ JWT payload에서 family 추출
                                       ├─ JwtTokenRepository::deleteByFamily(family)
                                       ├─ Set-Cookie: hc_access Max-Age=0
                                       ├─ Set-Cookie: hc_refresh Max-Age=0
                                       ├─ Set-Cookie: hc_csrf Max-Age=0
                                       ├─ session()->destroy() [레거시]
                                       └─ 200 OK { "data": {} }

[미인증 요청 — v2.1 신규 경로]
Client ──POST /api/auth/logout──► [라우트 필터 'auth' 적용]
                                   └─ AuthFilter::before()
                                         └─ JWT 부재/무효 → 401 UNAUTHORIZED 즉시 반환
                                              (컨트롤러 진입 차단)
```

#### 시퀀스 3: Geo Routing (정상 흐름 — FR-004)

```
Client ──GET /api/gate──► GateController::index()
                                │
                                ├─ ?country= 파라미터 확인 (수동 선택)
                                │     └─ whitelist ['kr','jp','us'] 검증 후 서버 URL 즉시 결정
                                │
                                ├─ hc_region 쿠키 확인 (캐시)
                                │     └─ 유효 시 캐시된 서버 URL 사용
                                │
                                ├─ GeoRoutingService::resolveClientIp()
                                │     └─ X-Forwarded-For 첫 번째 IP 파싱
                                │
                                ├─ GeoRoutingService::lookupIp(ip)
                                │     └─ GeoLite2-City.mmdb 조회 → {country, lat, lon, timezone}
                                │
                                ├─ GeoRoutingService::findNearestServer(lat, lon, country)
                                │     └─ foreach servers: Haversine(lat, lon, svLat, svLon)
                                │           → min distance 서버 선택 → {code, url, distanceKm}
                                │
                                ├─ Set-Cookie: hc_region (Max-Age=2592000, HttpOnly=false)
                                └─ 302 Location: {serverUrl}
```

#### 시퀀스 4: Reuse Detection 에러 흐름 (FR-003)

```
Client (탈취된 Refresh Token 재사용 시도)
    ──POST /api/auth/refresh──► AuthController::refresh()
                                        │
                                        ├─ JwtService::refreshTokenPair(stolenToken)
                                        │       ├─ decode() → payload {jti: "uuid-old", family: "fam-uuid"}
                                        │       ├─ findByJtiAndFamily("uuid-old", "fam-uuid")
                                        │       │       → is_used = 1  ← Reuse Detection!
                                        │       ├─ deleteByFamily("fam-uuid")  ← 전체 family 무효화
                                        │       └─ return null
                                        │
                                        └─ 401 Unauthorized { "error": { "code": "UNAUTHORIZED" } }

[정상 사용자도 동시에 세션 종료됨 — 보안상 의도적 동작]
```

### VP-8: Pattern Viewpoint (패턴)

| 패턴 | 적용 위치 | 설명 |
|------|---------|------|
| Repository Pattern | JwtTokenRepository | DB 접근 캡슐화. 쿼리 변경 시 Repository만 수정 |
| Strategy Pattern | GeoRoutingService::findNearestServer | Haversine 거리 계산 알고리즘 분리. 향후 Vincenty 등으로 교체 가능 |
| Interface Segregation | JwtServiceInterface / GeoRoutingServiceInterface | 소비 모듈이 필요한 메서드만 노출. 불필요한 의존 방지 |
| DI Container | Services.php + `service()` 헬퍼 | 생성자 주입. 테스트 시 Mock 교체 용이 |
| Token Family Rotation | JwtService::refreshTokenPair | OWASP 권장 Refresh Token 보안 패턴 |
| Signed Double Submit Cookie | CsrfTokenFilter + CsrfTokenService | Stateless CSRF 방어 패턴 (Session 불필요) |
| Defense in Depth | AuthFilter → checkNeedLogin → Repository 소유권 | OWASP API5:2023 Broken Object Level Authorization 대응 |

---

## 4. Design Overlay (횡단 관심사)

### 4.1 보안 설계

| 관심사 | 설계 결정 |
|--------|---------|
| XSS 방어 | JWT를 HttpOnly 쿠키에만 저장. JavaScript DOM 접근 불가 |
| CSRF 방어 | Signed Double Submit Cookie (HMAC-SHA256). SameSite=Lax 병행 |
| 토큰 탈취 감지 | Family Rotation + Reuse Detection. 탈취 감지 시 세션 전체 무효화 |
| 쿠키 속성 | `hc_access`: HttpOnly=true, Secure=true, SameSite=Lax. `hc_csrf`: HttpOnly=false (JS 읽기 필요) |
| JWT 서명 | HMAC-SHA256 pure PHP. 외부 라이브러리 의존 없음 |

### 4.2 에러 처리 설계

| 에러 상황 | HTTP 코드 | 에러 코드 | 처리 방식 |
|---------|---------|---------|---------|
| JWT 누락/만료 | 401 | `UNAUTHORIZED` | AuthFilter에서 조기 반환. 컨트롤러 진입 차단 |
| Refresh Token 만료 | 401 | `UNAUTHORIZED` | JwtService::decode() null 반환 → Controller 401 처리 |
| Reuse Detection | 401 | `UNAUTHORIZED` | deleteByFamily 후 null 반환 → 401. 보안 이벤트 로그 |
| CSRF 검증 실패 | 403 | `CSRF_VALIDATION_FAILED` | CsrfTokenFilter 조기 반환 |
| CSRF 만료 | 403 | `CSRF_TOKEN_EXPIRED` | TTL 만료 분기 처리 |
| Rate Limit 초과 | 429 | `TOO_MANY_REQUESTS` | ratelimit 필터 Retry-After 헤더 포함 |

### 4.3 로깅 설계

| 이벤트 | 로그 레벨 | 포함 정보 |
|--------|---------|---------|
| 토큰 갱신 성공 | INFO | ac_id, new_jti, family (마스킹된 형태) |
| Reuse Detection 발동 | WARNING | ac_id, jti, family, client_ip |
| 로그아웃 | INFO | ac_id, family |
| CSRF 검증 실패 | WARNING | client_ip, uri, X-CSRF-TOKEN (처음 8자) |
| JWT 검증 실패 | INFO | client_ip, uri (ac_id 없음 — 미인증) |

### 4.4 트랜잭션 설계

| 작업 | 트랜잭션 범위 | 격리 수준 |
|------|------------|---------|
| `refreshTokenPair()` | `markUsed()` + `insertToken()` 원자 처리 | READ COMMITTED |
| `revokeFamily()` | `deleteByFamily()` 단일 쿼리 (묵시적 트랜잭션) | READ COMMITTED |
| `createTokenPair()` | `insertToken()` 단일 INSERT | READ COMMITTED |

---

## 5. Design Rationale (설계 근거)

| # | 결정 | 근거 | 대안 및 기각 이유 |
|---|------|------|----------------|
| DR-001 | Pure PHP JWT (외부 라이브러리 미사용) | 의존성 최소화. `hash_hmac('sha256', ...)` PHP 내장 함수로 HMAC-SHA256 충분 구현 가능 (RFC 7519 HS256) | firebase/php-jwt: RS256 등 불필요 알고리즘 포함, 의존성 추가 |
| DR-002 | Token Family Rotation | OWASP Refresh Token Security 권고. 단순 만료 기반은 탈취 감지 불가 | 단순 만료 기반: 탈취된 토큰이 만료 전까지 사용 가능 |
| DR-003 | GeoLite2 로컬 mmdb | 네트워크 지연 없음 (파일 I/O < 1ms). 서비스 가용성과 무관. 무료 | MaxMind GeoIP2 API: 유료 + 네트워크 의존 → 응답시간 SLA 위협 |
| DR-004 | Haversine 거리 계산 | 서버 3개(KR/JP/US)에 대해 오차 허용 범위 충분 (최대 0.5% 오차). 구현 간단 | Vincenty Formula: 과잉 정밀도 (오차 0.5mm), 구현 복잡도 불필요 |
| DR-005 | Signed Double Submit Cookie CSRF | Stateless JWT 아키텍처와 완전 호환. HMAC 서명으로 쿠키 위변조 방지 추가 | CI4 내장 CSRF: Session 기반 → stateless JWT와 불일치 |
| DR-006 | Interface Only 모듈 간 통신 | 향후 마이크로서비스 분리 준비. 테스트 Mock 주입 용이 | 직접 클래스 참조: 리팩터링 비용 증가, 테스트 격리 어려움 |
| DR-007 (v2.1) | `$_SERVER['AUTH_USER']` 슈퍼글로벌을 인증 사용자 컨텍스트 저장소로 채택 | PHP 8.4 동적 프로퍼티 Deprecation Warning 회피. `$_SERVER`는 CI4 Request 수명주기와 독립되어 Filter → Controller → BaseController 전 구간에서 단일 참조 가능 | (a) `$request->authUser` 동적 프로퍼티: PHP 8.4 Deprecated. (b) 세션 저장: stateless JWT 아키텍처와 불일치. (c) 별도 `ContextService` 싱글턴: DI 부트스트랩 시점에 값이 없어 추가 Lifecycle 관리 비용 발생 |
| DR-008 (v2.1) | logout 라우트 `['filter' => 'auth']` 명시 등록 + 컨트롤러 `checkNeedLogin(true)` 중첩 방어 | 필터 설정 실수 또는 부분 적용 상황에서도 RBAC Layer 2(Controller)가 최종 차단. OWASP API5:2023 Defense in Depth 권고 | (a) 필터 단독 의존: 설정 누락 시 인가 우회. (b) 컨트롤러 단독 검증: 필터 계층 미활용으로 일관성 저하 및 조기 차단 기회 상실 |

---

## 6. Traceability Matrix (FR→Controller→Service→Repo→Table)

| FR ID | FR 명 | Controller | Service 메서드 | Repository 메서드 | DB 테이블 |
|-------|-------|-----------|--------------|----------------|---------|
| FR-001 | 로그아웃 | `AuthController::logout()` (라우트 필터 `auth`, v2.1) | `JwtService::revokeFamily()` | `deleteByFamily()` | `tb_refresh_token` |
| FR-002 | Token Refresh | `AuthController::refresh()` | `JwtService::refreshTokenPair()` | `findByJtiAndFamily()`, `markUsed()`, `insertToken()` | `tb_refresh_token` |
| FR-003 | Reuse Detection | `AuthController::refresh()` (내부) | `JwtService::refreshTokenPair()` | `findByJtiAndFamily()`, `deleteByFamily()` | `tb_refresh_token` |
| FR-004 | Geo Routing | `GateController::index()` | `GeoRoutingService::lookupIp()`, `findNearestServer()`, `resolveClientIp()` | 없음 | GeoLite2 mmdb |
| FR-005 | Whoami | `WhoamiController::index()` | `GeoRoutingService::lookupIp()`, `findNearestServer()`, `resolveClientIp()` | 없음 | GeoLite2 mmdb |
| FR-006 | CSRF 관리 | `AuthController::refresh()`, `AuthController::logout()` | `CsrfTokenService::generate()` (Shared) | 없음 | 없음 (stateless) |

---

## 7. 타당성 검토 (Feasibility Review)

| 설계 결정 | 채택 방식 | 근거 (공식 표준/문서) | 결론 |
|----------|----------|----------------------|------|
| Layered Architecture (Controller→Service→Repository) | 레이어별 책임 분리. 각 레이어는 인터페이스를 통해서만 통신 | IEEE 1016-2009 §5.3 — 설계 뷰포인트는 관심사 분리(separation of concerns) 원칙 준수 권고. Martin Fowler "Patterns of Enterprise Application Architecture" — Layered Architecture | **타당** — 각 레이어 독립적 단위 테스트 가능. Repository 교체 시 Service 수정 없음 |
| UNIQUE KEY on jti + Family 복합 조회 | `uq_jti(jti)` + `idx_family(family)` 분리 인덱스 | MySQL 8.0 공식 문서 — 복합 인덱스(jti+family)보다 단일 인덱스 분리가 `deleteByFamily` 쿼리에서 더 유연 | **타당** — jti는 전역 유니크. family 단독 조회(`deleteByFamily`)에 `idx_family` 별도 인덱스 필요 |
| 만료 토큰 인덱스 (`idx_expires_at`) | 배치 삭제를 위한 expires_at 인덱스 | MySQL 8.0 공식 문서 — Range scan for `WHERE expires_at < NOW()`는 인덱스 없이 Full Table Scan 발생 | **타당** — 장기 운영 시 만료 레코드 누적으로 성능 저하 방지. 야간 배치 삭제 쿼리 최적화 |
| GeoRoutingService 무의존 설계 | 외부 DI 없이 생성자에서 GeoLite2 파일 직접 오픈 | PHP GeoIP2 패키지 공식 문서 — `Reader` 인스턴스는 단일 파일 핸들 유지. CI4 Services.php에서 싱글턴으로 등록 시 요청당 1회 파일 오픈 보장 | **타당** — 요청마다 파일 오픈 오버헤드 없음. 메모리 효율적 |

**타당성 검토 결론**: Layered Architecture, DB 인덱스 전략, GeoRoutingService 설계 모두 IEEE 1016-2009 관심사 분리 원칙 및 MySQL 8.0 공식 문서 기반 타당성 검증 완료.

---

## 8. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| IEEE 1016-2009 8개 Viewpoint 구조 전면 적용 (v2.0) | Context/Composition/Logical/Dependency/Information/Interface/Interaction/Pattern 8개 뷰로 설계 전면 기술. 이해관계자별 관심사에 맞는 뷰 제공 | 글로벌 지침 SDD 형식 요구사항 — IEEE 1016-2009 8 Viewpoints 필수. v1.0은 단순 클래스 목록 수준으로 표준 미충족 |
| VP-5 Information Viewpoint SQL DDL 추가 (v2.0) | `tb_refresh_token` 완전한 DDL + 인덱스 전략 표 추가. 개발자가 스키마를 즉시 확인 가능 | 설계 문서가 실제 구현과 일치하도록 구체화. 스키마 마이그레이션 작업 시 단일 참조 |
| VP-7 Interaction Viewpoint 시퀀스 4개 추가 (v2.0) | 정상 흐름(토큰 갱신, 로그아웃, Geo Routing) + 에러 흐름(Reuse Detection) 시퀀스 다이어그램 추가 | 구현자가 실제 코드 작성 전 전체 흐름을 파악하여 구현 오류 방지 |
| §6 Traceability Matrix 신설 (v2.0) | FR→Controller→Service→Repo→Table 5-way 추적성 매트릭스. 요구사항 누락 검증 | IEEE 1016-2009 §5.11 — 설계 근거의 추적성 필수 |
| §4 Design Overlay 신설 (v2.0) | 보안/에러처리/로깅/트랜잭션 횡단 관심사를 단일 섹션으로 통합 | 횡단 관심사가 각 VP에 분산되어 일관성 확인이 어려웠던 문제 해결 |
| DR-007 신규 — `$_SERVER['AUTH_USER']` 전환 (v2.1) | PHP 8.4 동적 프로퍼티 Deprecation Warning 제거. Filter/Controller/BaseController 전 구간 단일 참조. BaseController JWT fallback(member-sdd §12.6)의 소스로 직접 연결 | 커밋 `fbbf0a9` — 동적 프로퍼티 `$request->authUser` 전환이 필요했고, `$_SERVER` 전역은 CI4 Request 수명주기와 독립되어 member 모듈 BaseController가 안정 참조 가능 |
| DR-008 신규 — logout 라우트 `['filter' => 'auth']` + `checkNeedLogin(true)` 중첩 방어 (v2.1) | RBAC Layer 1(필터)+Layer 2(컨트롤러) 2계층 방어. 필터 설정 누락 시에도 인가 우회 차단 | 커밋 `c6b8a5e`, `7e04106` — logout이 공개 EP로 분류된 불일치 교정 + 인증 필요 API 전수 `checkNeedLogin` 일괄 보강 |
| VP-7 시퀀스 2 갱신 (v2.1) | 로그아웃 시퀀스에 필터 `auth` + `$_SERVER['AUTH_USER']` 주입 단계 명시. 미인증 경로 신규 추가 | 실제 필터 동작과 시퀀스 다이어그램 정합성 확보. 신규 미인증 401 경로를 구현자에게 명확히 전달 |

---

## 9. 체크리스트 (Review Checklist)

### 완전성 (Completeness)

- [x] §1 Introduction — 목적/범위/참조 완전
- [x] §2 이해관계자 및 관심사 정의 (5개 이해관계자)
- [x] §3 VP-1 Context Viewpoint — 외부 경계 및 컴포넌트 다이어그램
- [x] §3 VP-2 Composition Viewpoint — 디렉토리 구조 + 컴포넌트 책임
- [x] §3 VP-3 Logical Viewpoint — Controller/Service/Repository 전체 메서드 시그니처
- [x] §3 VP-4 Dependency Viewpoint — DI 의존 그래프 + Services.php 코드 스니펫
- [x] §3 VP-5 Information Viewpoint — SQL DDL + ERD + 인덱스 전략 표
- [x] §3 VP-6 Interface Viewpoint — 5개 인터페이스 요약 표 (상세는 IDD 참조)
- [x] §3 VP-7 Interaction Viewpoint — 4개 시퀀스 (정상 3 + 에러 1)
- [x] §3 VP-8 Pattern Viewpoint — 6개 패턴 적용 현황
- [x] §4 Design Overlay — 보안/에러처리/로깅/트랜잭션
- [x] §5 Design Rationale — 6개 설계 결정, 근거 + 대안 기각 이유
- [x] §6 Traceability Matrix — FR→Controller→Service→Repo→Table 5-way
- [x] §7 타당성 검토 — 4건, 공식 표준 근거 연결
- [x] §8 변경 영향 기록 완료

### 일관성 (Consistency)

- [x] SRS FR ↔ Traceability Matrix 매핑 완전 (6개 FR 전체)
- [x] VP-3 메서드 시그니처 ↔ VP-7 시퀀스 일치
- [x] VP-5 DDL ↔ VP-4 DI 의존 일치
- [x] VP-6 인터페이스 ↔ auth-idd.md 정합

### 구현 가능성 (Implementability)

- [x] 클래스 간 의존 관계 단방향 (순환 없음)
- [x] 트랜잭션 경계 명확 (refreshTokenPair: markUsed + insertToken 원자)
- [x] 인덱스 전략 성능 요구사항 충족 (NFR-001: 200ms)
- [x] DI 등록 순서 논리적 (Repository → Service → Controller)

---

## 10. 변경 로그 (Change Log)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-15 | 1.0.0 | 초기 작성 |
| 2026-04-15 | 2.0.0 | IEEE 표준 전면 전환. 3-Round Review PASS (구조/내용/상호참조). IEEE 1016-2009 8개 Viewpoint 전면 적용, §4 Design Overlay 신설, §6 Traceability Matrix 신설, §7 타당성 검토, §8 변경 영향 기록 추가. 적용 표준: IEEE 1016-2009 |
| 2026-04-17 | 2.1.0 | DR-007(`$_SERVER['AUTH_USER']` 전환) + DR-008(logout 필터 + checkNeedLogin 중첩 방어) 신규. VP-7 로그아웃 시퀀스 갱신(필터 적용 단계 + 미인증 경로 추가). Traceability Matrix FR-001 라우트 필터 명시. 커밋 `c6b8a5e`, `fbbf0a9`, `7e04106` 반영. 3-Round IEEE Review PASS |
