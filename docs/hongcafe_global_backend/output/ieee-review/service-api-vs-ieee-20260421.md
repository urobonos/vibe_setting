---
문서명: service 모듈 API ↔ IEEE 대조 — 2026-04-21
상태: 초안
생성일: 2026-04-21
SSOT 방향: API → IEEE
작성자: jypark (agent: general-purpose, sonnet)
---

# service 모듈 API ↔ IEEE 대조 리포트

## 요약

- **EP 수 (md / yaml / Routes / SRS FR)**: 7 / 7 / 7 / 7(SRS 정의) — 수 일치, 단 URL·메서드·인증 불일치 다수
- **9개 항목 판정**: 통과 2 / 경고 4 / 불일치 3
- **이슈**: Critical 2 / High 4 / Medium 3 / Low 2
- **분류**: [A] IEEE 업데이트 필요 7건 / [B] API 내부 불일치 4건

---

## 항목별 판정표

| # | 항목 | 판정 | 심각도 | 이슈 ID | 비고 |
|---|------|------|--------|---------|------|
| 1 | EP 목록 (md↔yaml↔Routes↔SRS FR) | 불일치 | High | SERVICE-DEF-001, 002 | SRS URL/메서드 실제 코드와 불일치 |
| 2 | EP-SRS 매핑 | 불일치 | High | SERVICE-DEF-003 | SRS FR 메서드 시그니처 코드와 불일치 |
| 3 | 인증/CSRF | 불일치 | Critical | SERVICE-DEF-004, 005 | saveReject·deleteReject auth 필터 누락 |
| 4 | X-Forwarded-Proto | 통과 | — | — | md·yaml 모두 명세. components.parameters.$ref 사용 확인 |
| 5 | 응답 스키마 | 불일치 | High | SERVICE-DEF-006, 007 | 에러 코드 표준 위반, 응답 키 불일치 |
| 6 | 환경별 URL | 통과 | — | — | md·yaml servers 블록 3개 환경 완비 |
| 7 | 비즈니스 규칙 (멱등/RBAC/Rate-limit, 보안 필터) | 불일치 | Critical | SERVICE-DEF-004, 008 | saveReject/deleteReject 보안 필터 미등록 |
| 8 | IDD 매핑 | 경고 | Medium | SERVICE-DEF-009 | IDD 데이터 포맷이 실제 응답 구조와 불일치 |
| 9 | STD TC 커버리지 | 경고 | Medium | SERVICE-DEF-010, 011 | Feature TC SKIP 9건, CONFLICT/NFR 테스트 미구현 |

---

## 이슈 상세

### SERVICE-DEF-001 [A] High — SRS EP URL/메서드 코드 불일치

**항목**: 1 (EP 목록)  
**분류**: [A] IEEE → API 방향 업데이트 필요  
**심각도**: High

**현황**:

SRS-SVC-001 섹션 6의 EP 목록이 실제 코드(Routes.php) 및 API 문서(md/yaml)와 불일치한다.

| SRS 정의 | Routes.php / API md 실제 |
|---------|------------------------|
| `GET /api/services` | `POST /api/services/get-service-list-mobile` |
| `GET /api/services/{id}` | `POST /api/services/get-service-list-mobile-new` |
| `POST /api/rejects` | `POST /api/rejects/save-reject` |
| `DELETE /api/rejects/{id}` | `DELETE /api/rejects/delete-reject` |
| `GET /api/rejects` | `POST /api/rejects/get-callee-reject-list` |
| `GET /api/hermes/on-call` | `POST /api/hermes/get-on-call-callee` |
| `POST /api/hermes/on-call/connect` | `POST /api/hermes/get-on-call-callee-hecode` |

**SSOT(API) 기준**: Routes.php + API md/yaml가 실제 동작 EP.

**IEEE 수정 필요**: SRS 섹션 6 EP 목록을 아래로 교체.

| # | Controller | Method | Path | 설명 | 인증 | CSRF |
|---|-----------|--------|------|------|------|------|
| 1 | ServiceController | POST | `/api/services/get-service-list-mobile` | 서비스 목록 조회 (모바일) | 없음 | 면제 |
| 2 | ServiceController | POST | `/api/services/get-service-list-mobile-new` | 서비스 목록 조회 (신규) | 없음 | 면제 |
| 3 | RejectController | POST | `/api/rejects/save-reject` | 차단 등록 | JWT | 필수 |
| 4 | RejectController | DELETE | `/api/rejects/delete-reject` | 차단 해제 | JWT | 필수 |
| 5 | RejectController | POST | `/api/rejects/get-callee-reject-list` | 차단 목록 조회 (상담사) | JWT + role:callee | 면제(GET 유사) |
| 6 | HermesController | POST | `/api/hermes/get-on-call-callee` | 온콜 상담사 목록 | API Key | CSRF 면제 |
| 7 | HermesController | POST | `/api/hermes/get-on-call-callee-hecode` | 온콜 heCode 목록 | API Key | CSRF 면제 |

---

### SERVICE-DEF-002 [A] High — SRS FR 요건 EP URL 코드 불일치

**항목**: 1 (EP 목록)  
**분류**: [A] IEEE 업데이트 필요  
**심각도**: High

**현황**: SRS 각 FR의 "입력" 절에 기술된 URL이 실제 EP와 불일치.

| FR ID | SRS 기술 URL | 실제 URL |
|-------|------------|---------|
| FR-SVC-001 | `GET /api/services?sort=&category=` | `POST /api/services/get-service-list-mobile` |
| FR-SVC-002 | `GET /api/services/{id}` | (실제 구현 없음 — API 문서에도 미존재) |
| FR-SVC-003 | `POST /api/rejects` | `POST /api/rejects/save-reject` |
| FR-SVC-004 | `DELETE /api/rejects/{id}` | `DELETE /api/rejects/delete-reject` |
| FR-SVC-005 | `GET /api/rejects` | `POST /api/rejects/get-callee-reject-list` |
| FR-SVC-006 | `GET /api/hermes/on-call`, `POST /api/hermes/on-call/connect` | `POST /api/hermes/get-on-call-callee`, `POST /api/hermes/get-on-call-callee-hecode` |

**추가 확인**: FR-SVC-002 (서비스 상세 조회 `GET /api/services/{id}`)는 SRS에는 정의되어 있으나 Routes.php, API md/yaml, 컨트롤러 어디에도 구현이 없다. 미구현 EP로서 SRS에서 삭제하거나 "구현 예정(Pending)" 상태로 명기해야 한다.

**IEEE 수정 필요**: SRS 각 FR의 입력 URL을 실제 EP로 교체. FR-SVC-002는 삭제 또는 상태 표기.

---

### SERVICE-DEF-003 [A] Medium — SDD 라우트 등록 예시 실제 코드 불일치

**항목**: 2 (EP-SRS 매핑), 8 (IDD 매핑)  
**분류**: [A] IEEE 업데이트 필요  
**심각도**: Medium

**현황**: SDD 섹션 3.1~3.3의 "라우트 등록" 코드 예시가 실제 Routes.php와 불일치.

SDD 기술 (설계 의도):
```php
// SDD 3.1
$routes->get('services', 'ServiceController::index');
$routes->get('services/(:num)', 'ServiceController::show/$1');

// SDD 3.2
$routes->post('rejects', 'RejectController::create', ['filter' => 'ratelimit,csrftoken,auth']);
$routes->delete('rejects/(:num)', 'RejectController::delete/$1', ['filter' => 'ratelimit,csrftoken,auth']);
$routes->get('rejects', 'RejectController::index', ['filter' => 'ratelimit,auth']);

// SDD 3.3
$routes->get('hermes/on-call', 'HermesController::getOnCallList', ['filter' => 'ratelimit,auth']);
$routes->post('hermes/on-call/connect', 'HermesController::connect', ['filter' => 'ratelimit,csrftoken,auth']);
```

실제 Routes.php:
```php
$routes->post('services/get-service-list-mobile', 'ServiceController::getServiceListMobile');
$routes->post('services/get-service-list-mobile-new', 'ServiceController::getServiceListMobileNew');
$routes->post('rejects/save-reject', 'RejectController::saveReject');
$routes->delete('rejects/delete-reject', 'RejectController::deleteReject');
$routes->post('rejects/get-callee-reject-list', 'RejectController::getCalleeRejectList', ['filter' => 'role:callee']);
$routes->post('hermes/get-on-call-callee', 'HermesController::getOnCallCallee', ['filter' => 'auth:apikey']);
$routes->post('hermes/get-on-call-callee-hecode', 'HermesController::getOnCallCalleeHecode', ['filter' => 'auth:apikey']);
```

**IEEE 수정 필요**: SDD 섹션 3.1, 3.2, 3.3 라우트 등록 예시를 실제 Routes.php 내용으로 교체.

---

### SERVICE-DEF-004 [B] Critical — saveReject / deleteReject auth 필터 누락 (보안 취약점)

**항목**: 3 (인증/CSRF), 7 (비즈니스 규칙)  
**분류**: [B] API 내부 불일치 (코드 버그)  
**심각도**: Critical

**현황**: Routes.php에서 `save-reject`와 `delete-reject` 라우트에 `auth` 필터가 등록되어 있지 않다.

```php
// 현재 (취약)
$routes->post('rejects/save-reject', 'RejectController::saveReject');
$routes->delete('rejects/delete-reject', 'RejectController::deleteReject');
$routes->post('rejects/get-callee-reject-list', 'RejectController::getCalleeRejectList', ['filter' => 'role:callee']);
```

**문제**:
- `save-reject`, `delete-reject`는 API 문서(md/yaml)에서 `🔒 jwt` 인증 필수로 명세됨
- SRS FR-SVC-003 요건 3.5: "JWT 인증 필수; 미인증 시 UNAUTHORIZED(401) 반환"
- SRS FR-SVC-004 요건 4.5: "JWT 인증 및 CSRF 토큰 필수"
- SDD NFR-SVC-004: "RejectController 및 HermesController 전체 EP에 JWT 인증 필수"
- 라우트 필터 미등록 상태이므로 인증 없이 차단 등록/해제가 가능한 상태

**추가**: `RejectController::saveReject()` 및 `deleteReject()` 메서드 내부에도 `checkNeedLogin()` 호출이 없다. `getCalleeRejectList()`만 `checkNeedLogin(true)` 호출 존재. 즉, Layer 1(라우트 필터)과 Layer 2(컨트롤러 검증) 모두 누락 — OWASP API5:2023 3계층 중 2계층 완전 미구현.

**수정 필요 (Routes.php)**:
```php
$routes->post('rejects/save-reject', 'RejectController::saveReject', ['filter' => 'ratelimit,csrftoken,auth']);
$routes->delete('rejects/delete-reject', 'RejectController::deleteReject', ['filter' => 'ratelimit,csrftoken,auth']);
```

**코드 수정 필요 (RejectController.php)**: saveReject(), deleteReject() 메서드 상단에 checkNeedLogin(true) 추가.

---

### SERVICE-DEF-005 [B] High — HermesController 반환 타입이 JSON 응답이 아닌 raw array

**항목**: 3 (인증/CSRF), 5 (응답 스키마)  
**분류**: [B] API 내부 불일치  
**심각도**: High

**현황**: `HermesController::getOnCallCallee()`와 `getOnCallCalleeHecode()`가 `respondSuccess()` 등 표준 응답 래퍼를 사용하지 않고 raw `array`를 직접 반환한다.

```php
// 현재
public function getOnCallCallee(): array   // array 반환 — 표준 위반
{
    ...
    return $callee;   // raw array
}

public function getOnCallCalleeHecode($type = '')   // 반환 타입 미선언
{
    ...
    return $callee;   // raw array
}
```

**문제**:
- CLAUDE.md API 응답 표준: `{ "data": {...} }` 래퍼 필수
- API 문서(md/yaml) 응답 스키마: `{ "data": [...] }` 또는 `{ "data": {...} }` 구조
- IDD 섹션 4.5 Hermes 응답 포맷: `{ "data": [...] }` 구조
- 실제 코드는 raw array 반환으로 CI4의 자동 JSON 변환에 의존 — 표준 응답 래퍼(`respondSuccess`)를 우회

**수정 필요**: `respondSuccess($callee)` 또는 `respondSuccessWithMeta($callee, ...)` 사용으로 전환.

---

### SERVICE-DEF-006 [B] High — saveReject/deleteReject 에러 응답 코드 표준 위반

**항목**: 5 (응답 스키마)  
**분류**: [B] API 내부 불일치  
**심각도**: High

**현황**: `RejectController::saveReject()`와 `deleteReject()`의 에러 응답이 CLAUDE.md 에러 코드 표준을 위반한다.

**코드에서 사용 중인 에러 패턴**:
```php
return $this->respondError('INTERNAL', "占い師が指定されていません。", 500);
```

**문제**:
1. 필수 파라미터 누락(`ce_code`, `cr_code`, `rj_code`, `rj_content`)은 `INVALID_INPUT` + HTTP 400이 표준. 현재 코드는 모두 `INTERNAL` + HTTP 500으로 처리.
2. 이미 차단된 사용자(`checkReject` 실패)는 `CONFLICT` + HTTP 409가 표준. 현재 코드는 `INTERNAL` + HTTP 500.
3. 차단 정보 미존재(`deleteReject`에서 getTable 실패)는 `NOT_FOUND` + HTTP 404가 표준. 현재 코드는 `INTERNAL` + HTTP 500.
4. 에러 메시지가 일본어 하드코딩 — CLAUDE.md "에러 메시지는 `lang()` 키 사용, 하드코딩 금지" 위반.

**API 문서 정의 vs 실제 코드 대조**:

| 조건 | API md 명세 | 실제 코드 |
|------|-----------|---------|
| 필수 파라미터 누락 | 400 INVALID_INPUT | 500 INTERNAL |
| 이미 차단된 사용자 | 409 CONFLICT | 500 INTERNAL |
| 차단 정보 미존재(delete) | 404 NOT_FOUND | 500 INTERNAL |

**IEEE 수정 필요**: API 문서가 표준이므로 코드를 API 문서에 맞게 수정 필요. SRS FR-SVC-003 요건 3.3, FR-SVC-004 요건 4.3도 실제 에러 코드와 일치하도록 확인 필요.

---

### SERVICE-DEF-007 [A] Medium — API 문서 Refresh Token Path 오류

**항목**: 3 (인증/CSRF)  
**분류**: [A] IEEE 업데이트 필요  
**심각도**: Medium

**현황**: API 문서(service-api.md) 섹션 "JWT 인증" 테이블에 Refresh Token의 Path가 `/api/auth/refresh`로 기재되어 있다.

```
| Path | `/` | `/api/auth/refresh` |
```

**CLAUDE.md 표준 (최근 수정된 SSOT)**:
```
| Path | `/` | `/` |
```

커밋 `a7be0b5`에서 Refresh Token 쿠키 Path를 `/auth/refresh`에서 `/`로 확대하는 변경이 이미 반영되었다. API 문서가 이를 반영하지 않은 상태.

**IEEE 수정 필요**: service-api.md JWT 인증 테이블의 Refresh Token Path를 `/api/auth/refresh` → `/`로 수정.

---

### SERVICE-DEF-008 [A] High — SDD/SRS에 get-callee-reject-list CSRF 면제 근거 미명세

**항목**: 7 (비즈니스 규칙)  
**분류**: [A] IEEE 업데이트 필요  
**심각도**: High

**현황**: Routes.php에서 `get-callee-reject-list`는 POST 메서드이나 `csrftoken` 필터가 등록되어 있지 않다.

```php
$routes->post('rejects/get-callee-reject-list', 'RejectController::getCalleeRejectList', ['filter' => 'role:callee']);
```

**문제**:
- CLAUDE.md 필터 체인 정책: POST 요청에는 `csrftoken` 필터가 기본 적용되어야 함
- SDD 섹션 3.2 `index()` 설계: "GET이므로 CSRF 면제"라고 기술 — 그러나 실제 구현은 POST
- SRS 섹션 6 EP 목록: `GET /api/rejects` + CSRF "면제" — 역시 GET으로 잘못 기술
- 현재 Routes.php의 필터 체인: `role:callee` 만 있고 `ratelimit`, `csrftoken`, `auth`가 모두 누락

**분석**: `role:callee` 필터 내부에서 JWT 인증이 수행될 수 있으나, `ratelimit`과 `csrftoken`은 명시적으로 누락. POST에 csrftoken 미적용은 의도인지 버그인지 판단이 필요하다.

**IEEE 수정 필요**: SDD/SRS에서 이 EP를 POST로 명세하고, csrftoken 필터 적용 여부 및 면제 사유를 명시.

---

### SERVICE-DEF-009 [A] Medium — IDD 데이터 포맷이 API 문서/실제 응답과 불일치

**항목**: 8 (IDD 매핑)  
**분류**: [A] IEEE 업데이트 필요  
**심각도**: Medium

**현황**: IDD 섹션 4의 데이터 포맷 정의가 API 문서(md/yaml) 및 실제 코드 응답 필드와 불일치.

**4.3 Reject 등록 요청 포맷 불일치**:

| 항목 | IDD 섹션 4.3 | API md 실제 | 코드 실제 |
|------|------------|-----------|---------|
| 요청 필드 | `ceCode`, `crCode` (2개) | `ceCode`, `crCode`, `rjCode`, `rjContent` (4개 필수) | `ce_code`, `cr_code`, `rj_code`, `rj_content` (4개) |
| 응답 `data` 필드 | `rjNo`, `ceCode`, `crCode`, `createdAt` | `{ "msg": "차단 등록 완료" }` | `respondSuccess([], '메시지')` |

**4.4 Reject 목록 포맷 불일치**:

| 항목 | IDD 섹션 4.4 | API md 실제 | 코드 실제 |
|------|------------|-----------|---------|
| 응답 필드 | `displayName` | `crNick` | `cr_nick`(DB) |
| 날짜 필드 | `createdAt` (ISO 8601) | `formattedDate` ('2026.04.14' 형식) | `regist_date` → `Y.m.d / H:i` 포맷 |
| 추가 필드 | 없음 | `rjCode`, `rjContent` | `rj_code_name`, `from_reject_txt` 등 추가 |

**4.5 Hermes 응답 포맷 불일치**:

| 항목 | IDD 섹션 4.5 | API md 실제 |
|------|------------|-----------|
| 구조 | `data: [ {...} ]` (배열) | `data: { "HE001": {...} }` (heCode 키 맵) |
| 필드 | `calleeId`, `displayName`, `profileImageUrl`, `isOnCall`, `onCallStartedAt` | `ceCode`, `ceNick`, `online`, `heCode` |

**IEEE 수정 필요**: IDD 섹션 4.3, 4.4, 4.5를 API md/yaml 및 실제 코드 응답 기준으로 재작성.

---

### SERVICE-DEF-010 [A] Low — STD Feature TC 9건 SKIP — DB 의존 정책 명기 필요

**항목**: 9 (STD TC 커버리지)  
**분류**: [A] IEEE 업데이트 필요  
**심각도**: Low

**현황**: STD 섹션 4의 실행 결과에서 Feature 테스트 9건이 모두 SKIP 처리되어 있다.

```
Feature (HermesApiTest):  0 PASS / 3 SKIP
Feature (RejectApiTest):  0 PASS / 3 SKIP
Feature (ServiceApiTest): 0 PASS / 3 SKIP
```

STD DEF-SVC-001에서 "테스트 환경(SQLite) 기본 SKIP"으로 기록하고 있으나, SQLite는 이 프로젝트 Aurora MySQL 환경에서 부적합한 설명이다. 실제 이유(MySQL DB 연결 없이 실행 불가)는 별도 환경(스테이징/CI 파이프라인)에서 실행해야 한다.

**IEEE 수정 필요**: STD DEF-SVC-001 설명을 "MySQL 통합 테스트 환경 미구성으로 SKIP. 스테이징 환경에서 실행 필요"로 교체.

---

### SERVICE-DEF-011 [A] Low — STD TC TC-SVC-026 HermesService 타입 불일치

**항목**: 9 (STD TC 커버리지)  
**분류**: [A] IEEE 업데이트 필요  
**심각도**: Low

**현황**: STD TC-SVC-026에서 `getOnCallCalleeHecodeReturnsHeCodeArray` 테스트가 `type='coin'` 필터로 `['HE001', 'HE002']` 반환을 기대하고 있다. 그러나 실제 `HermesController::getOnCallCalleeHecode($type = '')` 메서드는 URL path 파라미터로 type을 받도록 설계되어 있고, API 문서는 `type`을 query string 파라미터로 명세하고 있다. 수신 방식이 불일치.

**HermesController 실제 시그니처**:
```php
public function getOnCallCalleeHecode($type = '')  // route parameter로 수신
```

**API md 명세**: `type` — query string 파라미터  
**Routes.php**: `$routes->post('hermes/get-on-call-callee-hecode', ...)` — path parameter 없음

**IEEE 수정 필요**: STD TC-SVC-026~028의 type 전달 방식을 query string 기준으로 수정. API md/yaml도 type 수신 방식을 확인 후 명세.

---

## 엔드포인트 매트릭스

| # | Method | Path | md | yaml | Routes | SRS FR | 인증(md) | 인증(Routes) | CSRF(md) | CSRF(Routes) | 판정 |
|---|--------|------|----|------|--------|--------|----------|-------------|----------|-------------|------|
| 1 | POST | /api/services/get-service-list-mobile | O | O | O | X(FR-SVC-001 URL 불일치) | 없음 | 없음 | 면제 | 없음 | A |
| 2 | POST | /api/services/get-service-list-mobile-new | O | O | O | X(미정의) | 없음 | 없음 | 면제 | 없음 | A |
| 3 | POST | /api/rejects/save-reject | O | O | O | X(FR-SVC-003 URL 불일치) | JWT | **없음** | 필수 | **없음** | **Critical** |
| 4 | DELETE | /api/rejects/delete-reject | O | O | O | X(FR-SVC-004 URL 불일치) | JWT | **없음** | 필수 | **없음** | **Critical** |
| 5 | POST | /api/rejects/get-callee-reject-list | O | O | O | X(FR-SVC-005 URL+메서드 불일치) | JWT+callee | role:callee | POST이므로 csrftoken 대상 | **없음** | A |
| 6 | POST | /api/hermes/get-on-call-callee | O | O | O | X(FR-SVC-006 URL 불일치) | apiKey | auth:apikey | 면제 | 없음 | A |
| 7 | POST | /api/hermes/get-on-call-callee-hecode | O | O | O | X(FR-SVC-006 URL 불일치) | apiKey | auth:apikey | 면제 | 없음 | A |

**범례**: O=존재·일치 / X=불일치 / **없음**=Critical 누락 / A=IEEE 업데이트 필요

---

## Open Questions

| # | 질문 | 관련 이슈 | 우선순위 |
|---|------|----------|---------|
| OQ-1 | `save-reject`/`delete-reject`의 auth 필터 누락은 의도(레거시 공개 EP)인가, 아니면 실수인가? API 문서는 JWT 필수로 명세. 보안 취약점으로 판단되므로 즉시 확인 필요. | SERVICE-DEF-004 | Critical |
| OQ-2 | `get-callee-reject-list`에 POST 메서드임에도 csrftoken 필터가 누락된 것이 의도인가? 상담사 전용 조회 EP이므로 GET 의미이지만 메서드는 POST. | SERVICE-DEF-008 | High |
| OQ-3 | FR-SVC-002 "서비스 상세 조회 GET /api/services/{id}"는 SRS에 정의되어 있으나 Routes, API md/yaml, 컨트롤러에 모두 존재하지 않는다. 구현 계획이 있는가, 삭제 대상인가? | SERVICE-DEF-002 | Medium |
| OQ-4 | `HermesController` 메서드들이 raw array를 반환하는 것이 의도적 설계(CI4 내부 호출용)인가, 아니면 외부 API 응답으로도 사용되는가? Routes에 등록되어 있으므로 외부 응답으로 판단됨. | SERVICE-DEF-005 | High |
| OQ-5 | ServiceController의 `getServiceListMobile`/`getServiceListMobileNew` 응답 필드가 `meta.orderType` 추가 필드를 포함하는데, API 문서에는 미명세. 의도적 추가 필드인가? | — | Low |
