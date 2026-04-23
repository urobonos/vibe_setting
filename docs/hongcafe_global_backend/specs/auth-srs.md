---
문서명: Auth — Software Requirements Specification
문서 ID: auth-srs
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-17
작성자: jypark
대상 시스템: Auth Module
관련 문서: auth-sdd.md (v2.1), auth-idd.md (v2.1), auth-std.md (v1.1), member-srs.md (v2.1)
적용 표준: IEEE 29148:2018
---

# Auth — Software Requirements Specification (SRS)

> IEEE 29148:2018 | version: 2.1 | lastUpdated: 2026-04-17 | module: Auth

---

## 1. Introduction

### 1.1 Purpose

본 Software Requirements Specification(SRS)은 HongCafe Global Backend의 Auth Bounded Context에 대한 기능/비기능 요구사항을 IEEE 29148:2018 표준에 따라 정의한다. 본 문서는 설계(auth-sdd.md), 인터페이스(auth-idd.md), 테스트 케이스 작성의 기준이 된다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 모듈(BC) | Auth |
| 목적 | JWT HttpOnly 쿠키 기반 인증/인가, Refresh Token Rotation, CSRF 방어, 지역 기반 서버 라우팅 |
| 이해관계자 | 전체 모듈 (Auth는 인증 기반 인프라. AuthFilter가 전역 적용됨) |
| 포함 EP | `POST /api/auth/logout`, `POST /api/auth/refresh`, `GET /api/gate`, `GET /api/whoami` |
| 포함 필터 | `AuthFilter` (전역), `CsrfTokenFilter` (상태 변경 요청), `RoleFilter` (역할 기반 접근) |

### 1.3 Definitions, Acronyms, and Abbreviations

| 용어 | 정의 |
|------|------|
| JWT | JSON Web Token — HMAC-SHA256 서명 기반 stateless 인증 토큰 (RFC 7519) |
| JTI | JWT ID — Refresh Token의 UUID 고유 식별자 (RFC 7519 §4.1.7) |
| Family | Token Rotation에서 동일 세션 토큰 체인을 묶는 UUID. 탈취 감지 시 전체 무효화 단위 |
| Reuse Detection | 사용 완료된 jti 재제출 감지 → 탈취 간주, family 전체 무효화 |
| GeoLite2 | MaxMind의 무료 IP 지오로케이션 데이터베이스 (mmdb 바이너리 형식) |
| Haversine | 두 지점 간 대원 거리(great-circle distance) 계산 공식 (지구 반경 R=6371km) |
| Signed Double Submit Cookie | HMAC-SHA256 서명이 포함된 CSRF 방어 기법. 쿠키 값과 요청 헤더 값을 `hash_equals()`로 비교 |
| RBAC | Role-Based Access Control — 역할 기반 접근 제어 |
| AC_ID | 사용자 이메일 주소 (계정 식별자) |
| CR_CODE | 사용자 고유 코드 (CR-YYYYMMDDHHmmss-XXX 형식) |
| CE_CODE | 상담사 고유 코드. 존재 여부로 `UserRole::Callee` / `UserRole::Caller` 판별 |

### 1.4 References

| 문서 | 경로/출처 |
|------|---------|
| 설계 문서 | `docs/specs/auth-sdd.md` v2.1 |
| 인터페이스 문서 | `docs/specs/auth-idd.md` v2.1 |
| 프로젝트 지침 | `CLAUDE.md` |
| RFC 7519 | JSON Web Token (JWT) |
| RFC 7231 | HTTP/1.1 Semantics and Content |
| OWASP CSRF Prevention | OWASP Cross-Site Request Forgery Cheat Sheet |
| OWASP JWT Security | OWASP JSON Web Token Cheat Sheet |
| IEEE 29148:2018 | ISO/IEC/IEEE 29148:2018 — Systems and software engineering: Life cycle processes — Requirements engineering |

### 1.5 Overview

본 SRS는 다음 섹션으로 구성된다.

- §2 Overall Description — 시스템 관점, 기능 개요, 사용자 분류, 제약사항, 가정
- §3 Functional Requirements — FR별 선행조건/후행조건/입력검증/우선순위/관련API/검증방법
- §4 Non-Functional Requirements — 정량 기준 및 검증 방법
- §5 External Interface Requirements — 외부 시스템 인터페이스
- §6 Use Cases — 주요 유스케이스 정상/대안/에러 흐름
- §7 Verification Matrix — FR↔UC↔Test↔SDD 4-way 매핑
- §8 Data Dictionary — 핵심 데이터 요소 정의
- §9 타당성 검토
- §10 변경 영향 기록
- §11 체크리스트
- §12 변경 로그

---

## 2. Overall Description

### 2.1 System Perspective

Auth 모듈은 HongCafe Global Backend의 인증 기반 인프라 역할을 한다. Member 모듈의 로그인/회원가입 처리 후 JWT Token Pair를 발급하며, AuthFilter를 통해 전체 모듈의 인증 상태를 검증한다. GeoRoutingService는 사용자의 지리적 위치에 따라 최근접 서버로 라우팅하는 역할을 한다.

```
[Client] ─── JWT/CSRF 쿠키 ───► [AuthFilter] ─── 검증 ───► [각 모듈 Controller]
                                      │
                                 [Auth Module]
                                 JwtService ──► JwtTokenRepository ──► tb_refresh_token
                                 GeoRoutingService ──► GeoLite2 mmdb
```

### 2.2 Functions

| 기능 그룹 | 설명 |
|----------|------|
| 토큰 관리 | JWT Access/Refresh Token 생성, 검증, Rotation, 폐기 |
| CSRF 방어 | Signed Double Submit Cookie 기반 CSRF 토큰 발급/검증/삭제 |
| 지역 라우팅 | MaxMind GeoLite2 IP 조회 + Haversine 거리 계산으로 최근접 서버(KR/JP/US) 302 리다이렉트 |
| 요청 컨텍스트 | 현재 요청의 IP, 지리정보, 추천 서버, 헤더 전체 반환 |
| 세션 관리 | 로그아웃 시 Refresh Token family 전체 무효화 + 레거시 세션 클리어 |

### 2.3 User Classes and Characteristics

| 사용자 분류 | 설명 | 인증 수준 |
|-----------|------|----------|
| Caller (일반 사용자) | 상담 서비스 이용자 | JWT 인증 필수 |
| Callee (상담사) | `ce_code` 보유. 상담사 전용 EP 접근 가능 | JWT + RoleFilter 인증 |
| 미인증 사용자 | `/api/gate`, `/api/whoami` 접근 가능 | 인증 불필요 |
| 레거시 세션 사용자 | `hdata` 쿠키 보유. 마이그레이션 완료까지 유지 | Session + JWT Dual |

### 2.4 Constraints

- JWT는 반드시 HttpOnly 쿠키(`hc_access`)에만 저장. localStorage 저장 금지.
- Bearer 헤더 폴백 없음 — 쿠키 전용 아키텍처.
- 외부 JWT 라이브러리 미사용 — pure PHP HMAC-SHA256 구현.
- CSRF_SECRET과 JWT_SECRET은 별도 독립 키.
- GeoLite2 DB는 로컬 파일 (`writable/geoip/GeoLite2-City.mmdb`). 네트워크 호출 금지.
- CI4 내장 CSRF 필터 미사용 (stateless JWT 아키텍처와 불일치).
- Auto Routing 비활성화 (`setAutoRoute(false)`). 모든 EP 명시적 등록 필수.

### 2.5 Assumptions and Dependencies

| 항목 | 내용 |
|------|------|
| 가정-1 | GeoLite2-City.mmdb 파일이 `writable/geoip/` 경로에 존재함 |
| 가정-2 | Member 모듈이 `JwtService::createTokenPair()`를 호출하여 로그인 완료 처리 |
| 가정-3 | X-Forwarded-For 헤더가 ALB/Nginx에서 신뢰 가능하게 전달됨 |
| 의존성-1 | `tb_account` 테이블 (Member 모듈 소유) — `ac_id`, `ce_code` 참조 |
| 의존성-2 | `tb_refresh_token` 테이블 (Auth 모듈 소유) |
| 의존성-3 | CsrfTokenService (Shared 모듈) |

---

## 3. Functional Requirements

### FR-001: 로그아웃 (Logout)

| 항목 | 내용 |
|------|------|
| 설명 | Refresh Token family 전체 무효화 + JWT/CSRF 쿠키 삭제 + 레거시 세션 클리어를 원자적으로 수행 |
| 선행 조건 | JWT 인증 완료 (`hc_access` 쿠키 유효). **라우트 필터 `auth` 통과 필수** (v2.1) |
| 후행 조건 | `hc_access`, `hc_refresh`, `hc_csrf` 쿠키 Max-Age=0 설정. `tb_refresh_token`에서 해당 family 전체 삭제. 레거시 세션 데이터 클리어 |
| 입력 검증 | `hc_refresh` 쿠키에서 family 값 추출. 추출 실패 시도 쿠키 삭제 후 200 반환 (멱등성 보장) |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/auth/logout` |
| 라우트 등록 | `app/Modules/Auth/Config/Routes.php` — `$routes->post('logout', 'AuthController::logout', ['filter' => 'auth'])` — 미인증 요청은 필터 레벨에서 401 (v2.1 신규) |
| 검증 방법 | 로그아웃 후 `/api/auth/refresh` 호출 시 401 반환 확인. Set-Cookie Max-Age=0 헤더 확인. `tb_refresh_token` 레코드 삭제 확인. 미인증 요청 시 401 UNAUTHORIZED 응답 확인 |

### FR-002: Access Token 갱신 (Token Refresh)

| 항목 | 내용 |
|------|------|
| 설명 | `hc_refresh` 쿠키의 Refresh Token 검증 → Reuse Detection 수행 → 새 Token Pair 발급 → CSRF 토큰 재발급 |
| 선행 조건 | 유효한 `hc_refresh` 쿠키 존재 |
| 후행 조건 | 새 `hc_access` + `hc_refresh` + `hc_csrf` 쿠키 Set-Cookie 응답. 이전 jti `is_used=1` 처리. 새 jti INSERT (동일 family) |
| 입력 검증 | `hc_refresh` 쿠키 존재 확인. JWT 서명 검증. `exp` 만료 확인. DB에서 jti+family 매핑 확인 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/auth/refresh` |
| 검증 방법 | 정상: 200 + Set-Cookie 3개 확인. 만료 Refresh: 401 확인. DB `is_used` 갱신 확인 |

### FR-003: Token Rotation 및 Reuse Detection

| 항목 | 내용 |
|------|------|
| 설명 | 동일 family 내 `is_used=1`인 jti가 재제출되면 family 전체 삭제 (탈취 감지). 정상 갱신 시 이전 jti `is_used=1`, 새 jti INSERT |
| 선행 조건 | `POST /api/auth/refresh` 요청 처리 중 (`JwtTokenRepository::findByJtiAndFamily()` 조회 결과) |
| 후행 조건 | 재사용 감지 시: `deleteByFamily(family)` → 401 반환. 정상 시: `markUsed(jti)` → `insertToken(newJti, family)` → 200 |
| 입력 검증 | `findByJtiAndFamily()` 결과의 `is_used` 필드 확인. null이면 invalid jti (401). `is_used=1`이면 Reuse Detection 발동 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/auth/refresh` 내부 로직 |
| 검증 방법 | 동일 Refresh Token으로 2회 연속 갱신 시도 → 2번째 요청에서 401 + family 삭제 확인 |

### FR-004: 지역 기반 서버 라우팅 (Geo Routing)

| 항목 | 내용 |
|------|------|
| 설명 | 사용자 IP 기반 최근접 서버(KR/JP/US)로 302 리다이렉트. 우선순위: `?country=` 수동 선택 → `hc_region` 캐시 쿠키 → GeoLite2 IP 조회 |
| 선행 조건 | 없음 (비인증 공개 EP) |
| 후행 조건 | `hc_region` 쿠키 설정 (Max-Age=2592000, 30일). 최근접 서버 URL로 302 Location 헤더 응답 |
| 입력 검증 | `?country=` 값은 `['kr', 'jp', 'us']` whitelist 검증. GeoLite2 조회 실패 시 기본 서버(KR)로 폴백 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `GET /api/gate` |
| 검증 방법 | KR IP → KR 서버 리다이렉트 확인. `?country=us` → US 서버 리다이렉트 확인. `?debug=1` → JSON 응답(리다이렉트 없음) 확인 |

### FR-005: 요청 컨텍스트 반환 (Whoami)

| 항목 | 내용 |
|------|------|
| 설명 | 현재 요청의 클라이언트 IP, HTTP 메서드, URI, GeoLite2 지리정보, 추천 서버, 주요 헤더, UTC 타임스탬프 반환 |
| 선행 조건 | 없음 (비인증 공개 EP) |
| 후행 조건 | 200 OK + JSON 응답 (ip, method, uri, geo, server, headers, timestamp) |
| 입력 검증 | 없음 (조회 전용) |
| 우선순위 | 권장 (Priority 2) |
| 관련 API | `GET /api/whoami` |
| 검증 방법 | 응답 JSON에 `ip`, `geo.country`, `server.url`, `timestamp` 필드 존재 확인 |

### FR-006: CSRF Token 관리

| 항목 | 내용 |
|------|------|
| 설명 | Signed Double Submit Cookie 방식. 로그인/refresh 성공 시 `hc_csrf` 쿠키 발급 (HttpOnly=false). 로그아웃 시 쿠키 삭제. POST/PUT/DELETE 요청 시 `X-CSRF-TOKEN` 헤더와 쿠키 값을 `hash_equals()`로 검증 후 HMAC 서명 확인 |
| 선행 조건 | 로그인 성공 또는 토큰 갱신 성공 (Member 모듈이 JwtService 호출 완료 후) |
| 후행 조건 | `hc_csrf` 쿠키 설정 (HttpOnly=false, Secure=true, SameSite=Lax, Max-Age=7200) |
| 입력 검증 | `X-CSRF-TOKEN` 헤더 값 존재 확인. `hash_equals(cookieValue, headerValue)`. HMAC-SHA256 서명 검증. TTL 만료 확인 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `CsrfTokenFilter` (전역 적용). 면제: `api/auth/refresh`, `api/stripe/webhook`, FCM EP |
| 검증 방법 | POST 요청에 `X-CSRF-TOKEN` 헤더 누락 시 403 + `CSRF_VALIDATION_FAILED` 확인. 유효한 헤더로 200 확인 |

---

## 4. Non-Functional Requirements

| ID | 구분 | 요구사항 | 정량 기준 | 검증 방법 |
|----|------|---------|---------|---------|
| NFR-001 | 성능 | 인증 API 응답 시간 | 200ms 이내 (P95) | Artillery 부하 테스트, 응답 시간 로그 분석 |
| NFR-002 | 보안 | Access Token 만료 시간 | 900초 (15분) | JWT `exp` 필드 확인 단위 테스트 |
| NFR-003 | 보안 | Refresh Token 만료 시간 | 604800초 (7일) | JWT `exp` 필드 확인 단위 테스트 |
| NFR-004 | 보안 | CSRF Token TTL | 7200초 (2시간) | CSRF 토큰 발급 후 7201초 경과 후 요청 → 403 확인 |
| NFR-005 | 보안 | JWT 서명 알고리즘 | HMAC-SHA256 (pure PHP) | 코드 리뷰 + `openssl_verify` 미사용 확인 |
| NFR-006 | 보안 | 쿠키 속성 | HttpOnly=true, Secure=true, SameSite=Lax (hc_access, hc_refresh) | Set-Cookie 헤더 검증 |
| NFR-007 | 가용성 | Rate Limit | 60 req / 60 sec (IP 기반) | ratelimit 필터 단위 테스트 |
| NFR-008 | 보안 | localStorage JWT 저장 | 금지 — 쿠키 전용 | 코드 리뷰 (JavaScript 파일 localStorage.setItem 검색) |
| NFR-009 | 성능 | GeoLite2 DB 조회 | 1ms 이내 (로컬 파일) | 단위 테스트 실행 시간 측정 |
| NFR-010 | 보안 | Reuse Detection 대응 시간 | 감지 즉시 (동일 트랜잭션 내) family 삭제 | DB family 삭제 + 401 응답 단위 테스트 |
| NFR-011 | 보안/호환 | 인증 사용자 컨텍스트 저장소 | `$_SERVER['AUTH_USER']`에 배열로 저장. 동적 프로퍼티(`$request->authUser`) 사용 금지 (PHP 8.4 deprecated 회피) | 코드 리뷰 + `grep "\$request->authUser" app/` 결과 0건 확인 |
| NFR-012 | 보안 | 인증 필요 EP 필터 체인 | 모든 인증 EP는 라우트 레벨 `['filter' => 'auth']` 등록 필수. Member 모듈 연계 EP의 `checkNeedLogin(true)` Layer 2 방어와 병행 | `app/Modules/Auth/Config/Routes.php` + `app/Config/Filters.php` 인스펙션 |

---

## 5. External Interface Requirements

### 5.1 사용자 인터페이스 (User Interface)

- HTTP/HTTPS REST API. JSON 응답 전용.
- 쿠키 기반 인증 (`hc_access`, `hc_refresh`, `hc_csrf`).
- 브라우저는 `X-Forwarded-Proto: https` 헤더를 모든 요청에 포함해야 함.

### 5.2 하드웨어 인터페이스 (Hardware Interface)

- 해당 없음.

### 5.3 소프트웨어 인터페이스 (Software Interface)

| 외부 시스템 | 프로토콜 | 설명 |
|-----------|---------|------|
| MaxMind GeoLite2-City | 로컬 파일 I/O (mmdb 바이너리) | `writable/geoip/GeoLite2-City.mmdb`. 네트워크 의존 없음 |
| Member 모듈 (JwtService 소비) | 내부 DI (`service()`) | 로그인 시 `createTokenPair()` 호출 |
| CsrfTokenService (Shared 모듈) | 내부 DI (`service()`) | CSRF 토큰 생성/검증 |

### 5.4 통신 인터페이스 (Communication Interface)

- HTTPS 전용 (HTTP 리다이렉트). ALB → Nginx → PHP-FPM 체인.
- `X-Forwarded-For` 헤더로 클라이언트 실제 IP 전달.
- `X-Forwarded-Proto: https` 헤더로 원본 프로토콜 전달.

---

## 6. Use Cases

### UC-001: 토큰 갱신 (Token Refresh)

- **액터**: 클라이언트 (브라우저)
- **관련 FR**: FR-002, FR-003, FR-006
- **사전조건**: `hc_refresh` 쿠키 유효
- **정상 흐름**:
  1. Access Token 만료로 401 수신
  2. `POST /api/auth/refresh` 호출 (`hc_refresh` 쿠키 자동 첨부)
  3. 서버: JWT 서명 검증 + `exp` 확인
  4. 서버: `findByJtiAndFamily(jti, family)` → `is_used=0` 확인
  5. 서버: `markUsed(oldJti)` + `insertToken(newJti, family)`
  6. 서버: `createTokenPair()` → 새 Access + Refresh 토큰
  7. 서버: CSRF 토큰 재발급
  8. 응답: `Set-Cookie: hc_access, hc_refresh, hc_csrf` 3개
- **대안 흐름 (A1)**: Refresh Token 만료 → JWT `exp` 검증 실패 → 401 + 재로그인 안내
- **에러 흐름 (E1)**: Reuse Detection 감지 → `deleteByFamily(family)` → 401 + 강제 로그아웃

### UC-002: 로그아웃 (Logout)

- **액터**: 인증된 사용자
- **관련 FR**: FR-001, FR-006
- **사전조건**: JWT 인증 완료 상태
- **정상 흐름**:
  1. `POST /api/auth/logout` 호출
  2. `hc_refresh` 쿠키에서 family 추출
  3. `deleteByFamily(family)` — `tb_refresh_token` family 전체 삭제
  4. `hc_access`, `hc_refresh`, `hc_csrf` 쿠키 Max-Age=0
  5. 레거시 세션 데이터 클리어
  6. 200 OK
- **에러 흐름 (E1)**: 미인증 상태 (`hc_access` 없음) → 401
- **에러 흐름 (E2)**: `hc_refresh` 쿠키 없음 → 쿠키 삭제 후 200 (멱등성)

### UC-003: 지역 기반 서버 라우팅 (Geo Routing)

- **액터**: 미인증 사용자
- **관련 FR**: FR-004
- **사전조건**: 없음 (비인증 공개 EP)
- **정상 흐름**:
  1. `GET /api/gate` 접속
  2. `?country=kr/jp/us` 파라미터 확인 (최우선)
  3. 없으면 `hc_region` 쿠키 확인 (캐시)
  4. 없으면 `resolveClientIp()` → `lookupIp(ip)` → `{country, lat, lon}`
  5. `findNearestServer(lat, lon, country)` → Haversine 거리 계산 → 최근접 서버
  6. `Set-Cookie: hc_region` (30일)
  7. `302 Location: {serverUrl}`
- **대안 흐름 (A1)**: `?debug=1` → 302 대신 JSON 응답 (ip, geo, server, distances)
- **에러 흐름 (E1)**: GeoLite2 파일 없음 → 기본 서버(KR) 폴백 302

### UC-004: 요청 컨텍스트 조회 (Whoami)

- **액터**: 모든 사용자 (비인증 포함)
- **관련 FR**: FR-005
- **사전조건**: 없음
- **정상 흐름**:
  1. `GET /api/whoami` 호출
  2. `resolveClientIp()` → X-Forwarded-For 파싱
  3. `lookupIp(ip)` → GeoLite2 조회
  4. `findNearestServer()` → 추천 서버
  5. 200 OK + JSON (ip, method, uri, geo, server, headers, timestamp)

---

## 7. Verification Matrix (FR↔UC↔Test↔SDD)

| FR ID | FR 명 | UC ID | 테스트 케이스 | SDD 참조 |
|-------|-------|-------|-------------|---------|
| FR-001 | 로그아웃 | UC-002 | `test_logout_clears_cookies_and_family`, `test_logout_without_auth_returns_401` | auth-sdd.md §VP-7 |
| FR-002 | Access Token 갱신 | UC-001 | `test_refresh_issues_new_token_pair`, `test_refresh_expired_returns_401` | auth-sdd.md §VP-7 |
| FR-003 | Reuse Detection | UC-001 (E1) | `test_reuse_detection_deletes_family_and_returns_401` | auth-sdd.md §VP-7 |
| FR-004 | Geo Routing | UC-003 | `test_gate_redirects_by_ip`, `test_gate_manual_country_param`, `test_gate_debug_mode` | auth-sdd.md §VP-4 |
| FR-005 | Whoami | UC-004 | `test_whoami_returns_ip_and_geo`, `test_whoami_returns_server_info` | auth-sdd.md §VP-6 |
| FR-006 | CSRF 관리 | UC-001, UC-002 | `test_csrf_issued_on_refresh`, `test_csrf_deleted_on_logout`, `test_csrf_validation_fails_without_header` | auth-sdd.md §VP-8 |

---

## 8. Data Dictionary

| 데이터 요소 | 타입 | 크기/형식 | 범위/허용값 | 출처/목적지 |
|-----------|------|---------|-----------|-----------|
| `ac_id` | string | VARCHAR(256) | 이메일 형식 | JWT payload → `tb_account` |
| `cr_code` | string | VARCHAR(30) | `CR-YYYYMMDDHHmmss-XXX` | JWT payload → `tb_account` |
| `ac_nick` | string | VARCHAR(100) | 1~100자 | JWT payload → `tb_account` |
| `jti` | string | UUID v4 | RFC 4122 UUID | JWT payload → `tb_refresh_token.jti` |
| `family` | string | UUID v4 | RFC 4122 UUID | JWT payload → `tb_refresh_token.family` |
| `is_used` | tinyint | 0 or 1 | 0=미사용, 1=사용완료 | `tb_refresh_token` |
| `expires_at` | datetime | DATETIME | UTC | `tb_refresh_token` |
| `hc_access` | cookie | JWT string | Max-Age=900, HttpOnly=true | Set-Cookie 헤더 |
| `hc_refresh` | cookie | JWT string | Max-Age=604800, HttpOnly=true, Path=/api/auth/refresh | Set-Cookie 헤더 |
| `hc_csrf` | cookie | HMAC string | Max-Age=7200, HttpOnly=false | Set-Cookie 헤더 |
| `hc_region` | cookie | string | `kr\|jp\|us`, Max-Age=2592000 | Set-Cookie 헤더 |
| `X-CSRF-TOKEN` | header | string | HMAC-SHA256 서명 값 | 요청 헤더 |
| `X-Forwarded-For` | header | IP 목록 | IPv4/IPv6 | ALB/Nginx 주입 |
| `country_code` | string | 2자 | ISO 3166-1 alpha-2 | GeoLite2 조회 결과 |
| `lat`, `lon` | float | double | 위도 -90~90, 경도 -180~180 | GeoLite2 조회 결과 |

---

## 9. 타당성 검토 (Feasibility Review)

| 요구사항 | 채택 방식 | 근거 (공식 표준/문서) | 결론 |
|---------|----------|----------------------|------|
| JWT HttpOnly 쿠키 전용 저장 | localStorage 금지. `hc_access` HttpOnly 쿠키만 사용 | OWASP JWT Cheat Sheet — "Store it in HTTPOnly, Secure cookie". MDN — `HttpOnly` 속성으로 JavaScript 접근 차단 (XSS 탈취 방지) | **타당** — localStorage 저장 시 XSS 공격으로 토큰 탈취 가능. HttpOnly 쿠키로 완전 차단 |
| Token Family Rotation + Reuse Detection | 동일 family 내 사용 완료 jti 재제출 감지 → family 전체 무효화 | OWASP Refresh Token Rotation — "Implement refresh token rotation". RFC 6749 §10.4 — Refresh Token 재사용 방지 권고 | **타당** — 단순 만료 기반 Refresh Token은 탈취 감지 불가. Family Rotation으로 탈취된 토큰 사용 시도를 즉시 감지하여 세션 전체 무효화 |
| Signed Double Submit Cookie CSRF | `hc_csrf` HMAC-SHA256 서명 쿠키. `hash_equals()` 비교 | OWASP CSRF Prevention Cheat Sheet — "Double Submit Cookie Pattern". SameSite=Lax 병행 (Defense in Depth) | **타당** — CI4 내장 CSRF 필터는 Session 기반으로 stateless JWT와 불일치. Signed Double Submit은 서명 검증으로 쿠키 위변조 방지 추가 |
| GeoLite2 로컬 mmdb 파일 | 네트워크 API 호출 없이 로컬 바이너리 조회 | MaxMind 공식 문서 — GeoLite2 binary database는 단일 레코드 조회 1ms 미만 성능. 네트워크 의존 제거로 가용성 향상 | **타당** — 외부 API 의존 시 네트워크 지연 + 장애 리스크 증가. 로컬 파일로 응답시간 SLA(200ms) 안정적 충족 |
| Pure PHP HMAC-SHA256 JWT | 외부 라이브러리 미사용. `hash_hmac('sha256', ...)` 자체 구현 | RFC 7519 §10.1 — HMAC-SHA256 (HS256) 알고리즘 정의. PHP `hash_hmac()` 함수는 FIPS 140-2 준수 환경에서 안전 | **타당** — firebase/php-jwt 등 외부 라이브러리는 RS256/ES256 등 불필요한 알고리즘 포함. 의존성 최소화 + 보안 표면 감소 |

**타당성 검토 결론**: 5개 핵심 요구사항 모두 OWASP, RFC, PHP 공식 문서 대비 타당성 검증 완료. Pure PHP JWT 구현 및 GeoLite2 로컬 방식은 성능 SLA 충족 근거 확보.

---

## 10. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| IEEE 29148:2018 표준 전면 전환 (v2.0) | §1 Introduction 5개 하위 섹션(Purpose/Scope/Definitions/References/Overview) 추가로 문서 목적·범위·용어를 명확화. 국제 표준 준수로 이해관계자 간 공통 언어 확립 | 글로벌 지침 SRS 형식 요구사항 준수. v1.0은 IEEE 29148 구조 미적용 수준으로 표준 재작성 필요 |
| §3 기능 요구사항 강화 (v2.0) | 각 FR에 선행조건/후행조건/입력검증/우선순위/관련API/검증방법 6항목 표준화. 테스트 케이스 도출 가능한 수준으로 구체화 | v1.0은 간략한 설명만 존재. IEEE 29148:2018 §5.2.5 요구사항 품질 기준(Complete, Consistent, Verifiable) 충족 필요 |
| §7 Verification Matrix 신설 (v2.0) | FR↔UC↔Test↔SDD 4-way 추적성 매트릭스 추가. 요구사항이 설계→구현→테스트까지 추적 가능 | IEEE 29148:2018 §5.2.9 — 요구사항 추적성 필수. 기존 문서에 추적성 매트릭스 부재 |
| §8 Data Dictionary 신설 (v2.0) | 핵심 데이터 요소(JWT payload 필드, 쿠키, 헤더)의 타입/크기/범위/출처를 형식화. 개발자가 DB 스키마와 API 계약을 단일 소스에서 확인 가능 | 데이터 요소가 SDD/IDD에 분산되어 있어 단일 SRS 내 Data Dictionary 필요 |
| §9 타당성 검토 섹션 추가 (v2.0) | 5개 핵심 요구사항에 OWASP/RFC/MaxMind 공식 근거 확보 | 글로벌 지침("타당성 검토" 섹션 필수 포함) 준수 |
| FR-001 라우트 필터 명시 추가 (v2.1) | logout 라우트에 `['filter' => 'auth']` 등록 요건을 필수 선행 조건으로 기록. 미인증 요청은 필터 레벨에서 차단 | 커밋 `c6b8a5e` — logout이 공개 EP처럼 호출 가능하던 불일치 교정, 로그 오염·쿠키 삭제 남용 방지 |
| NFR-011 신규 — 인증 사용자 컨텍스트 저장소 (v2.1) | `$request->authUser` 동적 프로퍼티 → `$_SERVER['AUTH_USER']`로 전환. PHP 8.4 Deprecation Warning 제거 | PHP 8.4에서 RequestInterface 동적 프로퍼티 지정이 Deprecated됨. `$_SERVER` 슈퍼글로벌은 CI4 Request 수명주기와 독립되어 컨트롤러에서 안정 참조 가능 |
| NFR-012 신규 — 인증 필요 EP 필터 체인 (v2.1) | 라우트 `['filter' => 'auth']` + 컨트롤러 `checkNeedLogin(true)` 2계층 방어 명문화 | 커밋 `7e04106` — AuthFilter 단독 의존 구조에서 필터 설정 누락이 곧 인가 우회로 이어지던 리스크 차단 (OWASP API5:2023 Defense in Depth 강화) |
| FR-001 BaseController JWT fallback 연계 기술 (v2.1) | Auth 모듈의 `AUTH_USER` 주입이 BaseController의 `$this->member` 세션 복원(member-srs FR-002-10)과 연결되는 계약 명시. AuthFilter가 주입한 ac_id가 BaseController fallback의 단일 소스 | 커밋 `fbbf0a9` — 레거시 `hdata` 쿠키 부재 시에도 JWT 단독 인증으로 BaseController 진입 가능해야 함. Auth ↔ Member 모듈 간 암묵적 계약을 SRS에 명시화 |

---

## 11. 체크리스트 (Review Checklist)

### 완전성 (Completeness)

- [x] §1 Introduction — 5개 하위 섹션 완전 (Purpose/Scope/Definitions/References/Overview)
- [x] §2 Overall Description — 시스템 관점/기능/사용자/제약사항/가정 정의
- [x] §3 기능 요구사항 — 6개 FR 전체 정의 (선행조건/후행조건/입력검증/우선순위/관련API/검증방법)
- [x] §4 비기능 요구사항 — 10개 NFR, 정량 기준 + 검증 방법 전체 정의
- [x] §5 외부 인터페이스 요구사항 — 사용자/하드웨어/소프트웨어/통신 인터페이스 정의
- [x] §6 유스케이스 — 4개 UC, 정상/대안/에러 흐름 전체 정의
- [x] §7 Verification Matrix — FR↔UC↔Test↔SDD 4-way 매핑
- [x] §8 Data Dictionary — 14개 핵심 데이터 요소 타입/크기/범위/출처 정의
- [x] §9 타당성 검토 — 5건, 공식 표준 근거 연결
- [x] §10 변경 영향 기록 완료

### 일관성 (Consistency)

- [x] FR 간 상충 없음 (FR-002와 FR-003의 관계 명확화)
- [x] NFR 측정 기준 정량화 완전
- [x] 유스케이스와 FR 매핑 일관성 (Verification Matrix)
- [x] Data Dictionary와 실제 DB 스키마(`tb_refresh_token`) 일치

### 검증 가능성 (Verifiability)

- [x] 각 FR에 구체적 검증 방법 명시
- [x] 각 NFR에 측정 방법 정의 (Artillery, 단위 테스트, 코드 리뷰)
- [x] Verification Matrix로 모든 FR에 테스트 케이스 대응

### 추적성 (Traceability)

- [x] FR ↔ UC 매핑 (Verification Matrix)
- [x] FR ↔ 테스트 케이스 매핑
- [x] FR ↔ SDD 참조 매핑 (auth-sdd.md Viewpoint 번호)
- [x] Data Dictionary ↔ DB 테이블 컬럼 매핑

---

## 12. 변경 로그 (Change Log)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-15 | 1.0.0 | 초기 작성 |
| 2026-04-17 | 2.1.0 | FR-001 라우트 필터 명시, NFR-011(AUTH_USER 슈퍼글로벌 전환), NFR-012(필터 체인 2계층 방어) 신규. BaseController JWT fallback과의 계약 명시. 2026-04-16 18:00 KST 이후 Auth 관련 커밋 `c6b8a5e`, `fbbf0a9`, `7e04106` 반영. 3-Round IEEE Review PASS |
| 2026-04-15 | 2.0.0 | IEEE 표준 전면 전환. 3-Round Review PASS (구조/내용/상호참조). §1 Introduction 하위 섹션 추가, §3 FR 6항목 강화, §7 Verification Matrix 신설, §8 Data Dictionary 신설, §9 타당성 검토, §10 변경 영향 기록 추가. 적용 표준: IEEE 29148:2018 |
