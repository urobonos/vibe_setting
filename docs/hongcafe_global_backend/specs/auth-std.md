---
문서명: Auth — Software Test Documentation
문서 ID: auth-std
버전: v1.2
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-20
작성자: jypark
대상 시스템: Auth Module
관련 문서: auth-srs.md (v2.1), auth-sdd.md (v2.1), auth-idd.md (v2.1), project-stp.md
적용 표준: IEEE 829-2008
---

# Auth — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.2 | lastUpdated: 2026-04-20 | module: Auth

---

## 1. Introduction

### 1.1 Purpose

본 Software Test Documentation(STD)은 HongCafe Global Backend Auth 모듈에 대한 테스트 항목, 테스트 케이스, 실행 결과, 추적성 매트릭스, 결함 내역을 IEEE 829-2008 표준에 따라 기록한다. Auth 모듈의 SRS(auth-srs.md)에서 정의한 기능 요구사항(FR-001~FR-006)과 비기능 요구사항(NFR-001~NFR-010)에 대한 검증 근거를 제공한다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 테스트 대상 모듈 | Auth (JWT 인증/인가, Geo Routing, Whoami, Logout) |
| 테스트 파일 수 | 6개 (Feature 3, Unit 3) |
| 테스트 메서드 수 | 총 47개 (v1.2 — LogoutApiTest 4 TC 추가) |
| 테스트 프레임워크 | PHPUnit + CodeIgniter 4 CIUnitTestCase / FeatureTestTrait |

### 1.3 References

| 문서 | 경로 |
|------|------|
| Auth SRS | `docs/specs/auth-srs.md` v2.1 |
| Auth SDD | `docs/specs/auth-sdd.md` v2.1 |
| Auth IDD | `docs/specs/auth-idd.md` v2.1 |
| 프로젝트 테스트 계획 | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 파일 목록

| # | 테스트 파일 | 유형 | 테스트 대상 클래스 | 메서드 수 |
|---|-----------|------|------------------|:---------:|
| 1 | `tests/Modules/Auth/Feature/GateApiTest.php` | Feature (통합) | GateController (GET /api/gate) | 4 |
| 2 | `tests/Modules/Auth/Feature/WhoamiApiTest.php` | Feature (통합) | WhoamiController (GET /api/whoami) | 3 |
| 3 | `tests/Modules/Auth/Feature/LogoutApiTest.php` | Feature (통합) | AuthController::logout + AuthFilter + CsrfTokenFilter (v1.2 신규) | 4 |
| 4 | `tests/Modules/Auth/Unit/GeoRoutingServiceTest.php` | Unit | GeoRoutingService | 12 |
| 5 | `tests/Modules/Auth/Unit/JwtServiceExtendedTest.php` | Unit | JwtService (Stub 기반, Token Pair/Rotation/Reuse Detection) | 14 |
| 6 | `tests/Modules/Auth/Unit/JwtServiceTest.php` | Unit | JwtService (encode/decode 기본) | 10 |

### 2.2 테스트 대상 클래스/메서드

| 클래스 | 테스트 대상 메서드 |
|--------|------------------|
| `GeoRoutingService` | `getServers()`, `getServerUrl()`, `findNearestServer()`, `lookupIp()`, `resolveClientIp()` |
| `JwtService` | `encode()`, `decode()`, `createTokenPair()`, `refreshTokenPair()`, `revokeFamily()` |
| `GateController` | `GET /api/gate` (debug, manual country, redirect) |
| `WhoamiController` | `GET /api/whoami` (응답 필드 검증) |

---

## 3. Test Cases

### 3.1 GateApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-AUTH-001 | `testGateDebugReturnsJsonResponse` | debug=1 파라미터로 Gate API 호출 시 JSON 응답 반환 | `GET /api/gate?debug=1` | HTTP 200, `status: success` | P1 |
| TC-AUTH-002 | `testGateWithManualCountryDebugReturnsSelectedServer` | 수동 국가 지정(KR) + debug 모드 시 해당 서버 선택 확인 | `GET /api/gate?country=KR&debug=1` | HTTP 200, `mode: manual`, `selected_server: KR` | P1 |
| TC-AUTH-003 | `testGateWithInvalidManualCountryFallsThrough` | 유효하지 않은 국가코드(XX) 시 IP 기반 처리로 폴백 | `GET /api/gate?country=XX&debug=1` | HTTP 200, `status: success` | P1 |
| TC-AUTH-004 | `testGateWithoutDebugReturnsRedirect` | debug 없이 country=JP 호출 시 302 리다이렉트 | `GET /api/gate?country=JP` | 302 → `https://jp.hongcafe.com` | P1 |

### 3.2-1 LogoutApiTest (Feature, v1.2 신규)

| TC ID | 메서드명 | 설명 | 기대 결과 | 우선순위 |
|-------|---------|------|----------|:--------:|
| TC-AUTH-043 | `testLogoutWithoutAuthReturnsUnauthorized` | CSRF 통과 + JWT 부재 → AuthFilter 401 차단 | HTTP 401 | P1 |
| TC-AUTH-044 | `testLogoutWithValidAuthSucceeds` | 유효 JWT + CSRF 토큰 → 200 | HTTP 200 | P1 |
| TC-AUTH-045 | `testLogoutClearsCookiesOnSuccess` | 성공 시 hc_access/hc_refresh Max-Age=0 쿠키 발급 | Max-Age=0 | P1 |
| TC-AUTH-046 | `testLogoutWithoutCsrfFails` | JWT 유효 + CSRF 헤더 누락 → CsrfTokenFilter 차단(200 아님) | HTTP ≠ 200 | P1 |

### 3.2 WhoamiApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-AUTH-005 | `testWhoamiReturnsSuccessResponse` | Whoami API 호출 시 200 + success 반환 | `GET /api/whoami` | HTTP 200, `status: success` | P2 |
| TC-AUTH-006 | `testWhoamiResponseContainsRequiredFields` | 응답 JSON에 필수 필드 7개 존재 확인 | `GET /api/whoami` | `ip`, `method`, `host`, `user_agent`, `geo`, `recommended_server`, `headers`, `timestamp` 키 존재 | P2 |
| TC-AUTH-007 | `testWhoamiMethodIsGet` | 응답의 method 필드가 GET 확인 | `GET /api/whoami` | `data.method == 'get'` | P2 |

### 3.3 GeoRoutingServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-AUTH-008 | `testGetServersReturnsThreeServers` | 서버 목록 3개(KR/JP/US) 반환 확인 | 없음 | count=3, KR/JP/US 키 존재 | P1 |
| TC-AUTH-009 | `testGetServerUrlReturnsUrlForValidCode` | 유효 서버 코드별 URL 반환 확인 | `'KR'`, `'JP'`, `'US'` | 각각 `https://kr/jp/us.hongcafe.com` | P1 |
| TC-AUTH-010 | `testGetServerUrlReturnsNullForInvalidCode` | 유효하지 않은 코드(XX, 빈값) 시 null 반환 | `'XX'`, `''` | `null` | P1 |
| TC-AUTH-011 | `testFindNearestServerReturnsKoreaForSeoulCoords` | 서울 좌표 → KR 서버 선택 + distances 포함 | lat=37.5665, lon=126.9780 | server=KR, label=Seoul, distances에 KR/JP/US 키 | P1 |
| TC-AUTH-012 | `testFindNearestServerReturnsJapanForTokyoCoords` | 도쿄 좌표 → JP 서버 선택 | lat=35.6762, lon=139.6503 | server=JP | P1 |
| TC-AUTH-013 | `testFindNearestServerReturnsUsForNewYorkCoords` | 뉴욕 좌표 → US 서버 선택 | lat=40.7128, lon=-74.0060 | server=US | P1 |
| TC-AUTH-014 | `testFindNearestServerFallsBackToCountryCodeWhenNoCoords` | 좌표 null + 국가코드 KR → KR 서버 폴백 | lat=null, lon=null, country=KR | server=KR, distances 빈 배열 | P1 |
| TC-AUTH-015 | `testFindNearestServerFallsBackToDefaultWhenNoCoordsAndUnknownCountry` | 좌표 null + 알 수 없는 국가 → US 기본 서버 | lat=null, lon=null, country=XX | server=US | P1 |
| TC-AUTH-016 | `testFindNearestServerDistancesContainKmUnit` | distances 값이 ' km' 단위로 끝나는지 확인 | 서울 좌표 | 모든 distance 문자열 ' km'으로 종료 | P2 |
| TC-AUTH-017 | `testLookupIpReturnsEmptyArrayWhenMmdbMissing` | GeoLite2 mmdb 파일 미존재 시 빈 배열 반환 (예외 없음) | IP `8.8.8.8` | `array` 타입, 예외 미발생 | P1 |
| TC-AUTH-018 | `testResolveClientIpHandlesForwardedHeader` | X-Forwarded-For 헤더 파싱 시 첫 IP 추출 | `HTTP_X_FORWARDED_FOR: '1.2.3.4, 5.6.7.8'` | `'1.2.3.4'` | P1 |
| TC-AUTH-019 | `testResolveClientIpFallsBackToRemoteAddr` | X-Forwarded-For 없을 때 REMOTE_ADDR 폴백 | `REMOTE_ADDR: '10.0.0.1'` | `'10.0.0.1'` | P1 |

### 3.4 JwtServiceExtendedTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-AUTH-020 | `testCreateTokenPairReturnsBothTokens` | createTokenPair 호출 시 access/refresh 양쪽 반환 | `{ac_id, cr_code, ac_nick}` | `access`, `refresh` 키 존재 + 비어있지 않음 | P0 |
| TC-AUTH-021 | `testAccessTokenContainsUserInfo` | Access Token 디코드 시 사용자 정보 포함 | Token pair 생성 후 access decode | `ac_id`, `cr_code`, `ac_nick`, `type=access` | P0 |
| TC-AUTH-022 | `testRefreshTokenContainsJtiAndFamily` | Refresh Token 디코드 시 jti/family 포함 | Token pair 생성 후 refresh decode | `type=refresh`, `jti` 비어있지 않음, `family` 비어있지 않음 | P0 |
| TC-AUTH-023 | `testRefreshTokenPairReturnsNewTokenPair` | refreshTokenPair 호출 시 새 토큰 쌍 반환 | 기존 refresh token | 새 access/refresh 반환, 기존과 다른 값 | P0 |
| TC-AUTH-024 | `testRefreshTokenPairPreservesFamilyClaim` | Refresh 후 family 값 유지 확인 | 기존 refresh token | 새 refresh의 family == 기존 family | P0 |
| TC-AUTH-025 | `testRefreshTokenPairRotatesJti` | Refresh 후 jti 값 변경 확인 (Rotation) | 기존 refresh token | 새 refresh의 jti != 기존 jti | P0 |
| TC-AUTH-026 | `testRefreshTokenPairRejectsAccessToken` | Access Token으로 refresh 시도 시 null 반환 | access token | `null` | P0 |
| TC-AUTH-027 | `testRefreshTokenPairRejectsInvalidToken` | 유효하지 않은 토큰으로 refresh 시 null 반환 | `'invalid.token.here'` | `null` | P0 |
| TC-AUTH-028 | `testRefreshTokenPairRejectsTokenWithoutAcId` | ac_id 없는 refresh token 시 null 반환 | type=refresh, jti/family만 포함 | `null` | P0 |
| TC-AUTH-029 | `testRefreshTokenPairDetectsReuseAndRevokesFamily` | Reuse Detection: 사용 완료 토큰 재제출 시 family 전체 무효화 | 동일 refresh token 2회 연속 제출 | 2번째 null, 신규 토큰도 null (family 삭제) | P0 |
| TC-AUTH-030 | `testTokenPairGeneratesUniqueJti` | 2회 생성 시 jti 고유성 확인 | 동일 ac_id로 2회 createTokenPair | 서로 다른 jti | P1 |
| TC-AUTH-031 | `testTokenPairGeneratesUniqueFamily` | 2회 생성 시 family 고유성 확인 | 동일 ac_id로 2회 createTokenPair | 서로 다른 family | P1 |
| TC-AUTH-032 | `testAccessTokenExpiresIn15Minutes` | Access Token TTL = 900초(15분) 확인 | Token pair 생성 후 access decode | `exp - iat == 900` | P0 |
| TC-AUTH-033 | `testRefreshTokenExpiresIn7Days` | Refresh Token TTL = 604800초(7일) 확인 | Token pair 생성 후 refresh decode | `exp - iat == 604800` | P0 |

### 3.5 JwtServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-AUTH-034 | `testEncodeReturnsThreePartToken` | encode 결과가 header.payload.signature 3파트 구조 | `{ac_id: 123}` | `.`으로 분리 시 3개 파트 | P0 |
| TC-AUTH-035 | `testEncodeIncludesIatAndExpClaims` | encode 결과에 iat/exp 클레임 포함 | `{ac_id: 456}` | `iat >= before`, `exp > now` | P0 |
| TC-AUTH-036 | `testEncodeThrowsExceptionWhenSecretIsEmpty` | 빈 시크릿으로 encode 시 RuntimeException | secret=`''` | `RuntimeException('JWT_SECRET 환경변수가 설정되지 않았습니다.')` | P0 |
| TC-AUTH-037 | `testEncodeCustomExpirationIsApplied` | 커스텀 만료 시간(7200초) 적용 확인 | expSeconds=7200 | `exp >= before + 7200` | P1 |
| TC-AUTH-038 | `testDecodeReturnsPayloadForValidToken` | 유효한 토큰 decode 시 원본 payload 반환 | `{ac_id: 789, role: 'user'}` | `ac_id=789`, `role='user'` | P0 |
| TC-AUTH-039 | `testDecodeReturnsNullForTamperedSignature` | 서명 변조 토큰 decode 시 null 반환 | 서명 부분 교체 | `null` | P0 |
| TC-AUTH-040 | `testDecodeReturnsNullForTamperedPayload` | payload 변조 토큰 decode 시 null 반환 | payload 부분 교체 | `null` | P0 |
| TC-AUTH-041 | `testDecodeReturnsNullForExpiredToken` | 만료된 토큰 decode 시 null 반환 | `exp = time() - 3600` | `null` | P0 |
| TC-AUTH-042 | `testDecodeReturnsNullForMalformedToken` | 형식 오류 토큰 decode 시 null 반환 | `'not.a.valid.jwt.token.parts'`, `'onlyonepart'`, `''` | 모두 `null` | P0 |

---

## 4. Test Execution Results

| 테스트 파일 | 총 테스트 | PASS | FAIL | SKIP | 최종 실행일 |
|-----------|:---------:|:----:|:----:|:----:|:----------:|
| GateApiTest | 4 | 4 | 0 | 0 | 2026-04-17 |
| WhoamiApiTest | 3 | 3 | 0 | 0 | 2026-04-17 |
| GeoRoutingServiceTest | 12 | 12 | 0 | 0 | 2026-04-17 |
| JwtServiceExtendedTest | 14 | 14 | 0 | 0 | 2026-04-17 |
| JwtServiceTest | 10 | 10 | 0 | 0 | 2026-04-17 |
| **합계** | **43** | **43** | **0** | **0** | **2026-04-17** |

**최종 실행 (2026-04-17):** `php vendor/bin/phpunit tests/Modules/Auth/` → `OK (43 tests, 110 assertions)` — 실행 시간 0.395s, 메모리 36MB.

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항 명 | 테스트 케이스 ID | 커버리지 |
|----------------|-----------|----------------|:--------:|
| FR-001 | 로그아웃 (Logout) | (Feature 테스트 미구현 — DB 트랜잭션 필요) | 미커버 |
| FR-002 | Access Token 갱신 (Token Refresh) | TC-AUTH-023, TC-AUTH-024, TC-AUTH-025 | 커버 |
| FR-003 | Token Rotation 및 Reuse Detection | TC-AUTH-025, TC-AUTH-029, TC-AUTH-030, TC-AUTH-031 | 커버 |
| FR-004 | 지역 기반 서버 라우팅 (Geo Routing) | TC-AUTH-001, TC-AUTH-002, TC-AUTH-003, TC-AUTH-004, TC-AUTH-008~TC-AUTH-019 | 커버 |
| FR-005 | 요청 컨텍스트 반환 (Whoami) | TC-AUTH-005, TC-AUTH-006, TC-AUTH-007 | 커버 |
| FR-006 | CSRF Token 관리 | (CSRF 전용 테스트 미구현 — CsrfTokenFilter 단위 테스트 필요) | 미커버 |
| NFR-002 | Access Token 만료 시간 (900초) | TC-AUTH-032 | 커버 |
| NFR-003 | Refresh Token 만료 시간 (604800초) | TC-AUTH-033 | 커버 |
| NFR-005 | JWT 서명 알고리즘 (HMAC-SHA256) | TC-AUTH-034, TC-AUTH-036, TC-AUTH-039, TC-AUTH-040 | 커버 |
| NFR-009 | GeoLite2 DB 조회 | TC-AUTH-017 | 커버 |
| NFR-010 | Reuse Detection 대응 | TC-AUTH-029 | 커버 |

---

## 6. Defects & Issues

| # | 결함 ID | 심각도 | 설명 | 발견일 | 상태 |
|---|--------|:------:|------|-------|:----:|
| 1 | AUTH-DEF-001 | Medium | FR-001(로그아웃) Feature 테스트 — 라우트 필터 `auth`가 미인증 요청을 401로 차단하는지, 성공 시 쿠키가 Max-Age=0으로 만료되는지, CSRF 헤더 누락 시 차단되는지 검증 필요 | 2026-04-16 | **Closed (2026-04-20)** — `tests/Modules/Auth/Feature/LogoutApiTest.php` 4 TC 전수 PASS. family 전체 무효화는 별도 JwtService Unit 테스트에서 커버 (TC-AUTH-029) |
| 2 | AUTH-DEF-002 | Medium | FR-006(CSRF 관리) 전용 테스트 미구현. CsrfTokenFilter의 헤더 검증, HMAC 서명 확인, TTL 만료 테스트 필요 | 2026-04-16 | Open |
| 3 | AUTH-DEF-003 | Low | JwtServiceTest의 `testDecodeReturnsNullWhenSignedWithDifferentSecret`가 TC 목록 외 추가 케이스. 다른 시크릿 서명 토큰 거부 검증 완료 | 2026-04-16 | Closed |
| 4 | AUTH-DEF-004 | Medium | **NFR-011(`$_SERVER['AUTH_USER']` 저장소) + NFR-012(필터 체인 2계층 방어) 전용 테스트 미구현**. AuthFilter가 `$_SERVER['AUTH_USER']`에 올바른 스키마로 저장하는지 + RoleFilter가 해당 값을 정확히 참조하는지 검증 필요 | 2026-04-17 | Open |

---

## 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-16 | 1.0.0 | 초기 작성. IEEE 829-2008 기반 STD 문서 생성. 테스트 파일 5개, 테스트 케이스 42개 기록 | jypark |
| 2026-04-17 | 1.1.0 | 2026-04-17 실측 재실행: 43 tests / 110 assertions 전수 PASS. 관련 문서 SRS/SDD/IDD v2.0 → v2.1 참조 갱신. AUTH-DEF-001에 logout 라우트 필터 검증 TC 누락 표시. AUTH-DEF-004 신규 — NFR-011(AUTH_USER 저장소) + NFR-012(필터 2계층 방어) 전용 TC 미구현 기록. 3-Round IEEE Review PASS | jypark |
| 2026-04-20 | 1.2.0 | **LogoutApiTest.php 신규** (TC-AUTH-043~046). AUTH-DEF-001 Closed. 테스트 파일 6개, TC 47개로 확장. 실행 결과 4 tests / 8 assertions 전수 PASS. 상세 근거: `docs/tasks/20260420/b1-logout-api-test/` | jypark |
