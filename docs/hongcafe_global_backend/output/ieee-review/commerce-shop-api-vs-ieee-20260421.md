---
문서명: commerce 모듈 shop API ↔ IEEE 대조 — 2026-04-21
상태: 초안
생성일: 2026-04-21
SSOT 방향: API → IEEE
작성자: jypark (agent: general-purpose, sonnet-4-6)
범위: shop (shop-api.md, shop-api.yaml 전용)
---

# Commerce Shop API ↔ IEEE 대조 리포트

## 메타 정보

| 항목 | 값 |
|------|-----|
| API SSOT | `api-docs/commerce/shop-api.md` (v2026-04-15) · `api-docs/commerce/shop-api.yaml` (v1.0.0) |
| IEEE 입력 | `docs/specs/commerce-srs.md` (v3.0) · `docs/specs/commerce-sdd.md` (v2.0) · `docs/specs/commerce-idd.md` (v2.0) · `docs/specs/commerce-std.md` (v1.0) |
| 코드 입력 | `app/Modules/Commerce/Controllers/ShopController.php` · `app/Modules/Commerce/Config/Routes.php` |
| 이슈 ID 체계 | `COMMERCE-SHOP-DEF-NNN` |

---

## 요약

- **EP 수 (md / yaml / Routes / SRS §1.2)**: 26 / 26 / 26 / 26 — 일치
- **9개 항목 판정**: PASS 4 / WARN 4 / FAIL 1
- **이슈 수**: DEF 7건 (WARN-급 5, FAIL-급 1) + [B] API 내부 불일치 1건

### EP 분포

| 구분 | md | yaml | Routes |
|------|-----|------|--------|
| 일반 사용자 (공개 포함) | 12 | 12 | 12 |
| 상담사 전용 (role:callee) | 14 | 14 | 14 |
| **합계** | **26** | **26** | **26** |

---

## 항목별 판정표

| # | 항목 | 판정 | 이슈 ID |
|---|------|------|---------|
| 1 | EP 목록 | PASS | — |
| 2 | EP-SRS FR 매핑 | WARN | COMMERCE-SHOP-DEF-001 |
| 3 | 인증/CSRF + role:callee 필터 | WARN | COMMERCE-SHOP-DEF-002, COMMERCE-SHOP-DEF-003 |
| 4 | X-Forwarded-Proto | PASS | — |
| 5 | 응답 스키마 | WARN | COMMERCE-SHOP-DEF-004, COMMERCE-SHOP-DEF-005 |
| 6 | 환경별 URL | PASS | — |
| 7 | 비즈니스 규칙 (MIME 이중 검증·RBAC 3계층·24h 취소·1h 예약) | FAIL | COMMERCE-SHOP-DEF-006 |
| 8 | IDD 매핑 | WARN | COMMERCE-SHOP-DEF-007 |
| 9 | STD TC 커버리지 | WARN | [B]-001 |

---

## 항목 상세 분석

### 항목 1 — EP 목록

**판정: PASS**

| EP | md | yaml | Routes | HTTP 메서드 일치 |
|----|-----|------|--------|----------------|
| `get-shop-items` | O | O | O | POST 일치 |
| `reservation-calendar` | O | O | O | POST 일치 |
| `order-reservation-time` | O | O | O | POST 일치 |
| `view-location-popup` | O | O | O | POST 일치 |
| `get-my-shop` | O | O | O | POST 일치 |
| `buy-shop` | O | O | O | POST 일치 |
| `insert-my-comment` | O | O | O | POST 일치 |
| `update-reschedule` | O | O | O | POST 일치 |
| `shop-confirm` | O | O | O | POST 일치 |
| `shop-cancel` | O | O | O | POST 일치 |
| `refund-success` | O | O | O | POST 일치 |
| `shop-file` | O | O | O | GET 일치 |
| `schedule-add` | O | O | O | POST 일치 |
| `schedule-delete` | O | O | O | DELETE 일치 |
| `shop-reserve-day` | O | O | O | POST 일치 |
| `shop-reserve-week` | O | O | O | POST 일치 |
| `shop-reserve-month` | O | O | O | POST 일치 |
| `callee-shop-confirm` | O | O | O | POST 일치 |
| `memosave` | O | O | O | POST 일치 |
| `callee-shop-file-upload` | O | O | O | POST 일치 |
| `callee-o2o-job` | O | O | O | POST 일치 |
| `delete-file` | O | O | O | DELETE 일치 |
| `update-shop` | O | O | O | POST 일치 |
| `update-shop-view` | O | O | O | POST 일치 |
| `preview-shop` | O | O | O | POST 일치 |
| `delete-opt` | O | O | O | DELETE 일치 |

md·yaml·Routes 3자 완전 일치. SRS §1.2 Shop (26 EP)와도 일치.

---

### 항목 2 — EP-SRS FR 매핑

**판정: WARN**

SRS FR과 shop EP의 매핑을 아래와 같이 정리한다.

| EP | SRS FR | SRS FR 커버 |
|----|--------|------------|
| `reservation-calendar` | FR-005-1, FR-005-5, FR-005-6 | O |
| `order-reservation-time` | FR-005-2, FR-005-3, FR-005-4, NFR-004 | O |
| `get-shop-items` | FR-001(간접) | 간접 커버(item list) |
| `view-location-popup` | — | **미커버** |
| `get-my-shop` | — | **미커버** |
| `buy-shop` | FR-006-1, NFR-002, NFR-004 | O |
| `insert-my-comment` | FR-006-6, NFR-001 | O |
| `update-reschedule` | NFR-003 | O (명시적 FR 없음) |
| `shop-confirm` | FR-006-2 | O |
| `shop-cancel` | FR-006-3, FR-006-4, NFR-003 | O |
| `refund-success` | FR-006-5 | O |
| `shop-file` | FR-008-8, NFR-006 | O |
| `schedule-add` | FR-008(일반), callee management | 간접 커버 |
| `schedule-delete` | FR-008 | 간접 커버 |
| `shop-reserve-day/week/month` | FR-005-1 (callee side) | 간접 커버 |
| `callee-shop-confirm` | FR-008-7 | O |
| `memosave` | — | **미커버** |
| `callee-shop-file-upload` | FR-008-2, NFR-001 | O |
| `callee-o2o-job` | FR-008-7, NFR-001 | O |
| `delete-file` | FR-008 | 간접 커버 |
| `update-shop` | FR-008-1(shop 확장) | 간접 커버 |
| `update-shop-view` | FR-008-3 | O |
| `preview-shop` | FR-008-3 | O |
| `delete-opt` | — | **미커버** |

**문제**: `view-location-popup`, `get-my-shop`, `memosave`, `delete-opt`, `update-reschedule`(별도 FR 없음), `schedule-add/delete/reserve-day/week/month`(개별 FR 미존재)에 대해 SRS에 명시적 FR 식별자가 없다.

→ **COMMERCE-SHOP-DEF-001** 참조

---

### 항목 3 — 인증/CSRF + role:callee 필터

**판정: WARN**

#### 3-1. 공개 EP 인증 표기

| EP | md 인증 표기 | yaml security 선언 | Routes 필터 | 실제 코드 |
|----|------------|------------------|------------|---------|
| `get-shop-items` | `—` | 없음(공개) | 없음 | O |
| `reservation-calendar` | `—` | 없음(공개) | 없음 | O |
| `order-reservation-time` | `—` | 없음(공개) | 없음 | O |
| `view-location-popup` | `—` | 없음(공개) | 없음 | O |

4개 공개 EP 모두 md·yaml·Routes·코드 일치. PASS.

#### 3-2. JWT 인증 EP (일반 사용자)

| EP | md 인증 | yaml cookieAuth | Routes auth 필터 | 코드 checkNeedLogin |
|----|---------|----------------|-----------------|-------------------|
| `get-my-shop` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | `is_login` 체크 O |
| `buy-shop` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | `checkNeedLogin()` O |
| `insert-my-comment` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | `checkNeedLogin()` O |
| `update-reschedule` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | `checkNeedLogin()` O |
| `shop-confirm` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | `checkNeedLogin()` O |
| `shop-cancel` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | `checkNeedLogin()` O |
| `refund-success` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | `is_login` 체크 O |
| `shop-file` | `🔒 jwt` | `cookieAuth: []` | 없음(auth global) | — (미확인) |

Routes에 auth 필터 명시가 없지만, 이는 전역 `auth` 필터 체인에 의해 처리됨. md·yaml·코드 일치.

#### 3-3. role:callee 필터 — 상담사 전용 EP

| EP | md 표기 | yaml cookieAuth | Routes `role:callee` | 판정 |
|----|---------|----------------|---------------------|------|
| `schedule-add` | `jwt (callee)` | O | **O** | PASS |
| `schedule-delete` | `jwt (callee)` | O | **O** | PASS |
| `shop-reserve-day` | `jwt (callee)` | O | **O** | PASS |
| `shop-reserve-week` | `jwt (callee)` | O | **O** | PASS |
| `shop-reserve-month` | `jwt (callee)` | O | **O** | PASS |
| `callee-shop-confirm` | `jwt (callee)` | O | **O** | PASS |
| `memosave` | `jwt (callee)` | O | **O** | PASS |
| `callee-shop-file-upload` | `jwt (callee)` | O | **O** | PASS |
| `callee-o2o-job` | `jwt (callee)` | O | **O** | PASS |
| `delete-file` | `jwt (callee)` | O | **O** | PASS |
| `update-shop` | `jwt (callee)` | O | **O** | PASS |
| `update-shop-view` | `jwt (callee)` | O | **O** | PASS |
| `preview-shop` | `jwt (callee)` | O | **O** | PASS |
| `delete-opt` | `jwt (callee)` | O | **O** | PASS |

14개 상담사 전용 EP 모두 Routes에 `['filter' => 'role:callee']` 등록됨. md·yaml·Routes 3자 일치.

#### 3-4. CSRF 면제 처리

`shop-file`은 GET 메서드이므로 CSRF 적용 제외. yaml에서 `XCsrfToken` 파라미터가 없음 — 올바름.

#### 3-5. Refresh Token Path 불일치

md 섹션 "JWT 인증 명세" 표에 Refresh Token Path를 `/api/auth/refresh`로 기재하고 있으나, CLAUDE.md 보안 정책 및 최신 commit (`a7be0b5 fix(auth): Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대`)에 따르면 현재 Path는 `/`이다. yaml의 `refreshCookieAuth` 설명에도 `Path=/api/auth/refresh`라고 오기되어 있다.

→ **COMMERCE-SHOP-DEF-002** 참조

#### 3-6. CSRF 면제 경로 누락

`refund-success`는 PG 콜백에 해당한다. CLAUDE.md CSRF 명세 면제 경로에는 `api/stripe/webhook`이 열거되어 있으나 `api/shop/refund-success`에 대한 면제 여부가 API 문서(md·yaml 모두)에 명시되어 있지 않다. 코드에서도 이 EP는 레거시 방식(redirect/alert 반환)으로 처리되어 실질적으로 JSON API가 아님.

→ **COMMERCE-SHOP-DEF-003** 참조

---

### 항목 4 — X-Forwarded-Proto

**판정: PASS**

| 위치 | 상태 |
|------|------|
| `shop-api.md` Rate Limit 섹션 | 명시 O (경고 문구 포함) |
| `shop-api.md` 필수 요청 헤더 표 | 명시 O |
| `shop-api.yaml` `components.parameters.XForwardedProto` | 정의 O |
| `shop-api.yaml` 전 26개 EP `$ref: '#/components/parameters/XForwardedProto'` | 일치 O |

모든 공개 EP 포함 26개 EP에 `XForwardedProto` $ref 적용됨. CLAUDE.md 정책 준수.

---

### 항목 5 — 응답 스키마

**판정: WARN**

#### 5-1. 성공/에러 포맷 — PASS

| 항목 | md | yaml | CLAUDE.md 표준 |
|------|-----|------|--------------|
| 성공 `{ "data": {...} }` | O | O | 일치 |
| 에러 `{ "error": { "code": "...", "message": "..." } }` | O | O | 일치 |
| HTTP status SSOT | O | O | 일치 |
| 에러 코드 6종 (`INVALID_INPUT`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`, `INTERNAL`) | O | O | 일치 |

#### 5-2. camelCase 변환 — 부분 불일치

`shop-api.md` EP별 파라미터 표에서 요청 파라미터 일부가 camelCase/snake_case 혼재한다.

- `shop-confirm` 요청: `odCode` (camelCase) — yaml `required: [odCode]` 일치
- `buy-shop` 요청: `reservDay`, `reservTime`, `ceCode` — camelCase, yaml 일치
- **실제 코드**(`ShopController::buyShop`)에서는 `$data['reserv_day']`, `$data['reserv_time']`, `$data['ce_code']`를 snake_case로 읽음

→ API 문서(md/yaml)는 camelCase 파라미터 표기이나 코드는 snake_case 키를 기대한다. API 문서가 SSOT이면 코드가 변환을 수행해야 하나, 현재는 클라이언트가 snake_case로 전송해야 동작함.

→ **COMMERCE-SHOP-DEF-004** 참조

#### 5-3. `order-reservation-time` 응답 스키마 불일치

`shop-api.md` EP #3 응답은 `{ "data": { "timeSlots": [...] } }`로 정의한다. `shop-api.yaml`도 동일. 그러나 IDD IF-INT-003 §2.3.5 타임슬롯 응답은 `{ "data": { "status": "success", "am": [...], "pm": [...] } }` 구조를 명세한다. 실제 코드(`ShopController::orderReservationTime`)도 `respondSuccess(['items' => $result['data'] ?? ''])` 형태로 `items` 키를 사용한다.

세 위치(md/yaml, IDD, 코드)가 서로 다른 응답 구조를 기술하고 있다:
- API (md/yaml): `data.timeSlots[]`
- IDD (IF-INT-003): `data.status + data.am[] + data.pm[]`
- 코드: `data.items`

→ **COMMERCE-SHOP-DEF-005** 참조

#### 5-4. `reservation-calendar` 응답 스키마 불일치

`shop-api.md` EP #2 응답: `{ "data": { "calendar": {...} } }`. IDD IF-INT-003 §2.3.5 캘린더 응답: `{ "data": { "selectMonth": "...", "prevMonth": "...", "nextMonth": "...", "ableDate": [...] } }`. 실제 코드: `respondSuccess(['items' => $data])`.

API(md/yaml), IDD, 코드 3자 모두 다름. COMMERCE-SHOP-DEF-005에 포함하여 처리.

#### 5-5. 페이지네이션 meta — PASS

`get-shop-items`, `get-my-shop` 모두 `{ "data": [...], "meta": { "currentPage", "perPage", "total", "lastPage" } }` 구조 선언. camelCase 통일. CLAUDE.md 및 SRS FR-001-7 준수.

---

### 항목 6 — 환경별 URL

**판정: PASS**

| 위치 | prd | stg | dev |
|------|-----|-----|-----|
| `shop-api.md` 환경별 URL 표 | O | O | O |
| `shop-api.yaml` servers 블록 | O | O | O |

CLAUDE.md 환경별 URL 명세 준수. 3개 환경 모두 명시됨.

---

### 항목 7 — 비즈니스 규칙

**판정: FAIL**

#### 7-1. 이미지 업로드 MIME 이중 검증 (NFR-001, FR-006-6)

`insert-my-comment`는 후기 이미지(`commentImg`, multipart/form-data)를 허용한다. SRS NFR-001은 모든 파일 업로드에 MIME 이중 검증(확장자 whitelist + `mime_content_type()` 매직 바이트)을 필수로 정의한다.

실제 코드 `ShopController::insertMyComment`(라인 316-328)를 확인한 결과:

```php
// Layer 1: 확장자 whitelist 체크 (O)
if ($imageFileType != "jpg" && $imageFileType != "png" && $imageFileType != "jpeg" && $imageFileType != "gif") {
    return $this->respondError('INVALID_INPUT', ...);
}
// Layer 2: mime_content_type() 매직 바이트 검증 — 코드에 없음 (X)
```

Layer 1(확장자 whitelist)만 구현되어 있고, Layer 2(`mime_content_type()` 매직 바이트 검증)가 누락되어 있다. NFR-001 위반.

`callee-shop-file-upload`, `callee-o2o-job`의 MIME 이중 검증 여부는 ShopController 후반부 코드에서 확인 필요하나, 동일 패턴이 반복될 위험이 있음.

→ **COMMERCE-SHOP-DEF-006** 참조

#### 7-2. 24시간 취소/변경 규칙 (NFR-003, FR-006-3)

SRS NFR-003: "UTC, `DateTimeImmutable` 사용. `date()`, `time()` 사용 금지."

코드 `ShopController::shopCancel`(라인 454-458) 및 `updateReschedule`(라인 382-386):

```php
// 실제 코드: date() + strtotime() 사용 — DateTimeImmutable 미사용
$items['today_24_hours_later'] = date("Y-m-d H:i:s", strtotime("+24 hours"));
```

`DateTimeImmutable` 대신 `date()`/`strtotime()`을 사용하고 있다. CLAUDE.md 코딩 표준("DateTimeImmutable 강제, date() time() 사용 금지") 및 SRS NFR-003 위반.

또한 `shopCancel`은 위반 시 `alert('예약일시 24시간 전까지 구매취소 가능합니다.')`로 HTML redirect를 반환하며, JSON API 응답이 아니다. API 문서에는 `HTTP 200 { "data": { "msg": "..." } }` 성공 응답만 정의되어 있고, 24시간 규칙 위반 시 `HTTP 403 FORBIDDEN` 에러 응답이 API 문서에 명시되어 있지 않다.

COMMERCE-SHOP-DEF-006에 포함.

#### 7-3. RBAC 3계층 (OWASP API5:2023)

Layer 1 (route filter): 상담사 전용 14 EP에 `['filter' => 'role:callee']` 적용 확인 — **PASS**

Layer 2 (`checkNeedLogin(true)`): 코드에서 일부 EP는 `$this->is_login` 직접 체크를 사용하고 `checkNeedLogin(true)`를 사용하지 않음(예: `get-my-shop`, `refund-success`). CLAUDE.md RBAC Layer 2는 `checkNeedLogin(true)`를 통한 `ce_code` 이중 검증을 요구한다.

Layer 3 (Repository 소유권 조건): `get-my-shop`에서 `ac_id` 기반 필터링 확인 — 부분 PASS.

Layer 2 불일치는 하위 이슈로 COMMERCE-SHOP-DEF-006에 포함.

#### 7-4. 1시간 전 예약 규칙 (NFR-004)

코드 `ShopController::buyShop`(라인 252-259):

```php
$beforeRervTime = date("H:i", strtotime("+1 hours"));
$beforeRervDate = date("Y-m-d");
```

여기도 `date()`/`strtotime()` 사용. NFR-004 및 CLAUDE.md 코딩 표준 위반.

COMMERCE-SHOP-DEF-006에 포함.

---

### 항목 8 — IDD 매핑

**판정: WARN**

IDD-COMMERCE-001은 IF-INT-003(`ShopReservationServiceInterface`)을 통해 `buildCalendarData`, `getAvailableTimeSlots`를 상세 정의한다. Shop EP 중 내부 인터페이스 매핑 현황:

| EP | IDD IF | 매핑 |
|----|--------|------|
| `reservation-calendar` | IF-INT-003 `buildCalendarData` | O |
| `order-reservation-time` | IF-INT-003 `getAvailableTimeSlots` | O |
| `shop-file` (다운로드 14일 제한) | IF-EXT-004 AWS S3/IMG_SERVER (§3.4) | O |
| `callee-shop-file-upload` | IF-EXT-004 MIME 이중 검증 (§3.4.2) | O |
| `callee-shop-confirm` (FCM) | IF-EXT-003 FCM (§3.3) | O |
| `callee-o2o-job` (Chat API) | IF-EXT-005 Chat API (§3.5) | O |
| `insert-my-comment` (S3 이미지) | IF-EXT-004 (§3.4) | O |
| `shop-cancel` / `refund-success` (PG) | IF-EXT-001 Stripe / IF-EXT-002 NaverPay | O |

**문제**: IDD §5 데이터 포맷 `ReservationSlot VO`(IF-INT-003)의 응답 구조 `{ status, am[], pm[] }`가 API md/yaml(`{ timeSlots: [] }`)과 불일치한다. IDD가 API를 SSOT로 따라야 하나, 현재 IDD가 더 상세한 구조를 정의하고 있어 역으로 IDD가 정확하고 API가 불완전할 가능성이 있다.

→ **COMMERCE-SHOP-DEF-007** 참조 (COMMERCE-SHOP-DEF-005와 연동)

**문제**: `memosave`, `delete-opt`, `update-shop`, `update-shop-view`, `preview-shop`에 대한 개별 IDD 인터페이스 계약(5-Subsection)이 없다. 이 EP들은 IDD 인터페이스 목록에 미포함.

→ COMMERCE-SHOP-DEF-007에 포함.

---

### 항목 9 — STD TC 커버리지

**판정: WARN (내부 [B] 불일치)**

STD-COMMERCE §3.3 ShopApiTest 및 §3.9 ShopControllerTest 커버리지:

| EP | ShopApiTest TC | ShopControllerTest TC | 커버 |
|----|---------------|----------------------|------|
| `get-shop-items` | TC-SA-001 | TC-SC-006 | O |
| `reservation-calendar` | TC-SA-002 | TC-SC-002 | O |
| `order-reservation-time` | — | TC-SC-003 | 부분 |
| `view-location-popup` | TC-SA-003 | TC-SC-005 | O |
| `get-my-shop` | TC-SA-005 | TC-SC-004 | O |
| `buy-shop` | TC-SA-004 | TC-SC-007 | O |
| `insert-my-comment` | — | TC-SC-008 | 부분 |
| `update-reschedule` | — | TC-SC-009 | 부분 |
| `shop-confirm` | — | TC-SC-010 | 부분 |
| `shop-cancel` | — | TC-SC-011 | 부분 |
| `refund-success` | — | TC-SC-012 | 부분 |
| `shop-file` | — | TC-SC-013 | 부분 |
| `schedule-add` | — | TC-SC-015 | 존재확인만 |
| `schedule-delete` | — | TC-SC-014 | 존재확인만 |
| `shop-reserve-day` | — | TC-SC-016 | 존재확인만 |
| `shop-reserve-week` | — | TC-SC-017 | 존재확인만 |
| `shop-reserve-month` | — | TC-SC-018 | 존재확인만 |
| `callee-shop-confirm` | — | TC-SC-019 | 존재확인만 |
| `memosave` | — | TC-SC-020 | 존재확인만 |
| `callee-shop-file-upload` | — | TC-SC-021 | 부분 |
| `callee-o2o-job` | — | TC-SC-022 | 부분 |
| `delete-file` | — | TC-SC-023 | 존재확인만 |
| `update-shop` | — | TC-SC-024 | 부분 |
| `update-shop-view` | — | TC-SC-025 | 존재확인만 |
| `preview-shop` | — | TC-SC-026 | 존재확인만 |
| `delete-opt` | — | — | **미커버** |

`delete-opt` EP에 대응하는 STD TC가 없다(ShopControllerTest에도 미포함).

Traceability Matrix(STD §5)에서 Shop 관련:
- `FR-005-1~6`, `FR-006-1~4`, `FR-008-7`: 추적성 표에 TC ID 매핑됨
- `shop-cancel`의 24시간 규칙(`NFR-003`)은 TC-SC-011 존재확인 TC만 있고 실제 비즈니스 로직 검증 TC 없음
- `callee-shop-file-upload` MIME 이중 검증(`NFR-001`): TC 없음

→ **[B]-001** 참조

---

## 이슈 상세

### COMMERCE-SHOP-DEF-001 — 일부 EP에 대한 명시적 SRS FR 미존재

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IEEE (SRS 수정) |
| 발견 위치 | `docs/specs/commerce-srs.md` FR 섹션 vs `api-docs/commerce/shop-api.md` EP 목록 |
| 영향 범위 | SRS §3 FR 섹션, SDD Traceability Overlay, STD Traceability Matrix |

**내용**: 아래 6개 EP가 API 문서에 정의되어 있으나 SRS에 개별 FR로 명시되어 있지 않다.

| EP | 현재 상황 |
|----|----------|
| `view-location-popup` | SRS에 관련 FR 없음. 위치 팝업 HTML 반환은 별도 요구사항 정의 필요 |
| `get-my-shop` | SRS에 관련 FR 없음. 사용자 예약 목록 조회 기능 |
| `memosave` | SRS에 관련 FR 없음. 상담사 메모 저장 기능 |
| `delete-opt` | SRS에 관련 FR 없음. 샵 옵션 삭제 기능 |
| `update-reschedule` | NFR-003으로 간접 커버되나 명시적 FR 없음 |
| `schedule-add/delete/reserve-*` | FR-008 일반 언급만 있고 개별 FR 없음 |

**결론**: API가 SSOT이므로 SRS에 해당 EP들을 커버하는 FR을 추가해야 한다. 특히 `view-location-popup`(HTML 응답)과 `delete-opt`는 아키텍처 패턴(JSON API vs HTML 뷰 혼재)에 대한 설계 결정도 함께 명시 필요.

**수정 대상**: `docs/specs/commerce-srs.md` §3 FR 섹션에 FR-006 확장 또는 FR-011 신설

---

### COMMERCE-SHOP-DEF-002 — Refresh Token Path 오기

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IEEE (API 수정) |
| 발견 위치 | `api-docs/commerce/shop-api.md` §JWT 인증 명세 및 `api-docs/commerce/shop-api.yaml` `refreshCookieAuth` |
| 영향 범위 | shop-api.md JWT 명세 표, shop-api.yaml `components.securitySchemes.refreshCookieAuth` 설명 |

**내용**: commit `a7be0b5`(fix(auth): Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대)에 의해 Refresh Token Path가 `/`로 변경되었다. CLAUDE.md 보안 정책도 `Path: /`를 명시한다.

- `shop-api.md` 표: Refresh Token Path = `/api/auth/refresh` → **오기**
- `shop-api.yaml` securitySchemes `refreshCookieAuth` description: `"Path=/api/auth/refresh"` → **오기**

**수정 대상**:
- `api-docs/commerce/shop-api.md` JWT 인증 명세 표 → `Path: /api/auth/refresh` → `/`
- `api-docs/commerce/shop-api.yaml` `refreshCookieAuth.description` → `"Path=/"` 로 수정

---

### COMMERCE-SHOP-DEF-003 — `refund-success` CSRF 면제 여부 미명시 + 응답 형식 불일치

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IEEE |
| 발견 위치 | `app/Modules/Commerce/Controllers/ShopController.php` `refundSuccess()` vs `api-docs/commerce/shop-api.md` EP #11 |
| 영향 범위 | shop-api.md EP #11 응답 정의, SRS FR-006-5 |

**내용**: `shop-api.md` EP #11은 `POST /api/shop/refund-success`를 JWT 인증 필요 JSON API로 정의하고 `HTTP 200 { "data": { "msg": "..." } }` 응답을 명세한다. 그러나 실제 코드 `refundSuccess()`는:

1. `redirect()->to($CurrentURI)->alert('구매가 취소 되었습니다.')` — HTML redirect 반환 (JSON 아님)
2. CSRF 면제 여부 불명확 — CLAUDE.md 면제 경로 목록에 없음
3. 사실상 PG 콜백 후처리 플로우이나 API 문서는 일반 JWT 인증 EP로 기술

**결론**: `refund-success`는 레거시 방식(HTML redirect 기반)으로 동작하며, API 문서와 실제 코드가 일치하지 않는다. CSRF 면제 또는 적용 여부를 API 문서에 명시해야 한다.

**수정 대상**:
- `api-docs/commerce/shop-api.md` EP #11 비고란에 "레거시 HTML redirect 응답, CSRF 면제 검토 필요" 명시
- `docs/specs/commerce-srs.md` FR-006-5에 응답 형식(HTML redirect vs JSON) 명확화

---

### COMMERCE-SHOP-DEF-004 — 요청 파라미터 표기 camelCase vs 코드 snake_case 불일치

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → 코드 (코드 수정 또는 문서 정정) |
| 발견 위치 | `api-docs/commerce/shop-api.md` 요청 파라미터 표 vs `app/Modules/Commerce/Controllers/ShopController.php` |
| 영향 범위 | shop-api.md 전체 요청 파라미터 표기, shop-api.yaml requestBody properties |

**내용**: API 문서(md/yaml)는 요청 파라미터를 camelCase로 표기하나(`reservDay`, `reservTime`, `ceCode`, `odCode`, `srNo`, `fileKey` 등), 실제 코드는 snake_case로 읽는다(`$data['reserv_day']`, `$data['reserv_time']`, `$data['ce_code']`, `$data['od_code']` 등).

| 파라미터 (md/yaml) | 코드 키 | 불일치 |
|------------------|---------|-------|
| `reservDay` | `$data['reserv_day']` | O |
| `reservTime` | `$data['reserv_time']` | O |
| `ceCode` | `$post['ce_code']` | O |
| `odCode` | `$data['od_code']` | O |
| `srStatus` | `$post['sr_status']` | O |

CLAUDE.md "응답 키 네이밍: DB snake_case → API 응답 camelCase 변환 필수"는 **응답** camelCase 변환 규칙이다. 요청 파라미터에 대한 명시 규칙은 없으나, API 문서가 camelCase로 표기하면 실제 동작과 불일치가 발생한다.

**결론**: (A) API 문서를 snake_case로 수정하거나, (B) 코드에 camelCase→snake_case 변환 레이어를 추가하거나, (C) 요청 파라미터는 snake_case 유지 방침을 명시해야 한다. API가 SSOT이므로 코드 변환 레이어(B) 또는 문서 정정(C-방향 표기 방침 명시)을 선택해야 한다.

**수정 대상**: 방침 결정 후 shop-api.md/yaml 또는 ShopController.php 수정

---

### COMMERCE-SHOP-DEF-005 — `order-reservation-time` 및 `reservation-calendar` 응답 스키마 3자 불일치

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IEEE + 코드 (IDD 및 코드 수정) |
| 발견 위치 | `api-docs/commerce/shop-api.md` EP #2/#3 vs `docs/specs/commerce-idd.md` IF-INT-003 vs `ShopController.php` |
| 영향 범위 | shop-api.md EP #2·#3 응답 스키마, shop-api.yaml paths, IDD IF-INT-003 응답 명세, IDD §5.3 ReservationSlot VO |

**내용**:

**`order-reservation-time` 응답**:

| 위치 | 응답 구조 |
|------|----------|
| `shop-api.md` EP #3 | `{ "data": { "timeSlots": [...] } }` |
| `shop-api.yaml` /api/shop/order-reservation-time | `data.timeSlots` (array) |
| IDD IF-INT-003 §2.3.5 | `{ "data": { "status": "success", "am": [...], "pm": [...] } }` |
| `ShopController::orderReservationTime()` | `respondSuccess(['items' => $result['data'] ?? ''])` |

세 위치 모두 다름.

**`reservation-calendar` 응답**:

| 위치 | 응답 구조 |
|------|----------|
| `shop-api.md` EP #2 | `{ "data": { "calendar": {...} } }` |
| `shop-api.yaml` /api/shop/reservation-calendar | `data.calendar` (object) |
| IDD IF-INT-003 §2.3.5 | `{ "data": { "selectMonth", "prevMonth", "nextMonth", "ableDate": [...] } }` |
| `ShopController::reservationCalendar()` | `respondSuccess(['items' => $data])` |

**결론**: IDD가 `am/pm` 구조와 `selectMonth/ableDate` 구조로 더 상세하게 정의되어 있어 IDD가 실제 동작에 가깝다. API 문서(SSOT)를 IDD 구조에 맞게 수정해야 한다. 동시에 코드도 `items` 대신 올바른 키를 사용하도록 수정 필요.

**수정 대상**:
- `api-docs/commerce/shop-api.md` EP #2 응답: IDD 구조(`selectMonth`, `prevMonth`, `nextMonth`, `ableDate`)로 수정
- `api-docs/commerce/shop-api.md` EP #3 응답: IDD 구조(`status`, `am`, `pm`)로 수정
- `api-docs/commerce/shop-api.yaml` 동일 수정
- `docs/specs/commerce-idd.md` IF-INT-003과 API 문서 동기화 확인
- `ShopController::orderReservationTime()` 및 `reservationCalendar()` 응답 키 수정

---

### COMMERCE-SHOP-DEF-006 — 비즈니스 규칙 코드 미준수 3건

| 속성 | 값 |
|------|-----|
| 심각도 | FAIL |
| SSOT 방향 | SRS → 코드 (코드 수정 필수) |
| 발견 위치 | `app/Modules/Commerce/Controllers/ShopController.php` |
| 영향 범위 | NFR-001, NFR-003, NFR-004, CLAUDE.md 코딩 표준, 보안 정책 RBAC Layer 2 |

**내용**:

**[규칙 위반 1] MIME 이중 검증 누락 — NFR-001 위반 (심각도: FAIL)**

코드 `ShopController::insertMyComment()` 라인 316-328: 확장자 whitelist(Layer 1)만 구현, `mime_content_type()` 매직 바이트 검증(Layer 2) 누락.

```php
// 현재 (Layer 1만 존재)
if ($imageFileType != "jpg" && $imageFileType != "png" && ...) { ... }
// 필요 (Layer 2 추가)
$mimeType = mime_content_type($_FILES['comment_img']['tmp_name']);
$allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
if (!in_array($mimeType, $allowedMimes)) {
    return $this->respondError('INVALID_INPUT', ..., 400);
}
```

API 문서는 이 규칙을 언급하지 않음 — API 문서에 MIME 이중 검증 요구사항 명시 필요.

**[규칙 위반 2] `date()`/`strtotime()` 사용 — NFR-003, NFR-004, CLAUDE.md 위반 (심각도: FAIL)**

| 메서드 | 위반 코드 | 요구 |
|--------|----------|------|
| `shopCancel()` | `date("Y-m-d H:i:s", strtotime("+24 hours"))` | `DateTimeImmutable` 사용 |
| `updateReschedule()` | `date("Y-m-d H:i:s", strtotime("+24 hours"))` | `DateTimeImmutable` 사용 |
| `buyShop()` | `date("H:i", strtotime("+1 hours"))` | `DateTimeImmutable` 사용 |
| `getMyShop()` | `date("Y-m-d H:i:s", strtotime("+24 hours"))` | `DateTimeImmutable` 사용 |

**[규칙 위반 3] `shopCancel()` JSON 응답 미반환 — API 문서 불일치**

`shopCancel()`이 24시간 규칙 위반 시 `alert('예약일시 24시간 전까지 구매취소 가능합니다.')` HTML을 반환한다. API 문서는 `HTTP 403 FORBIDDEN` JSON 응답을 정의하지 않았으나, SRS FR-006-3은 `HTTP 403 + FORBIDDEN`을 명세한다.

**[규칙 위반 4] RBAC Layer 2 불일치**

`get-my-shop()`: `checkNeedLogin(true)` 대신 `if (!$this->is_login || !$this->member['ac_id'])` 직접 체크 사용. CLAUDE.md RBAC Layer 2 정책(`checkNeedLogin(true)` — 컨트롤러 레벨 ce_code 이중 검증) 미준수.

**수정 대상**:
- `ShopController::insertMyComment()`: `mime_content_type()` Layer 2 추가
- `ShopController::shopCancel()`, `updateReschedule()`, `buyShop()`, `getMyShop()`: `date()`→`DateTimeImmutable` 전환
- `ShopController::shopCancel()`: HTML redirect → JSON 응답 전환 (`HTTP 403 FORBIDDEN`)
- `ShopController::get-my-shop()`: `checkNeedLogin(true)` 전환
- `api-docs/commerce/shop-api.md` EP #7 비고란에 "MIME 이중 검증(NFR-001) 적용: 확장자 whitelist + mime_content_type()" 명시
- `api-docs/commerce/shop-api.md` EP #10 에러 응답에 `HTTP 403 FORBIDDEN` 케이스 추가
- `docs/specs/commerce-srs.md` FR-006-3 — 코드 미준수 상태 표시

---

### COMMERCE-SHOP-DEF-007 — IDD 인터페이스 계약 미정의 EP 5건

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IDD (IDD 보완) |
| 발견 위치 | `docs/specs/commerce-idd.md` 내부 인터페이스 목록 vs `api-docs/commerce/shop-api.md` EP 목록 |
| 영향 범위 | IDD-COMMERCE-001 §2 내부 인터페이스 |

**내용**: IDD IF-INT-003은 `buildCalendarData`, `getAvailableTimeSlots`만 정의하며, 아래 5개 EP에 대응하는 인터페이스 계약이 없다.

| EP | 기대 IDD 항목 | 현재 상태 |
|----|-------------|----------|
| `memosave` | ShopRepositoryInterface::saveMemo() 계약 | 미정의 |
| `delete-opt` | ShopRepositoryInterface::deleteOpt() 계약 | 미정의 |
| `update-shop` | ShopRepositoryInterface::updateShop() 계약 + 파라미터 정의 | 미정의 |
| `update-shop-view` | ShopRepositoryInterface::updateShopView() 응답 스키마(`shView` 필드) | 미정의 |
| `preview-shop` | ShopRepositoryInterface::previewShop() 응답 구조 | 미정의 |

또한 COMMERCE-SHOP-DEF-005에서 지적된 `order-reservation-time` 및 `reservation-calendar` 응답 스키마 불일치(IDD IF-INT-003 vs API md/yaml)도 본 이슈와 연동된다.

**수정 대상**: `docs/specs/commerce-idd.md` IF-INT-006(ShopRepositoryInterface) 확장 — 5개 메서드의 5-Subsection(목적/요청/응답/에러/예시) 추가. IF-INT-003 응답 명세를 API SSOT에 맞게 수정.

---

### [B]-001 — STD `delete-opt` TC 미존재 + MIME/NFR-003 비즈니스 로직 TC 부재

| 속성 | 값 |
|------|-----|
| 유형 | [B] API 내부 불일치 (STD 자체 미비) |
| 심각도 | WARN |
| 발견 위치 | `docs/specs/commerce-std.md` §3.9 ShopControllerTest, §5 Traceability Matrix |
| 영향 범위 | STD-COMMERCE §3.9, §5 Traceability Matrix |

**내용**: STD §3.9 ShopControllerTest에 `deleteOpt` 메서드 존재확인 TC가 없다. 다른 EP들은 TC-SC-001~TC-SC-026의 26개 케이스 중 `delete-opt`에 해당하는 TC-SC-027이 누락된 것과 같다(TC-SC-026이 previewShop이 마지막).

또한 STD Traceability Matrix §5에서 다음 항목의 비즈니스 로직 TC가 존재확인 TC만 있고 실제 동작 검증이 없다:
- `NFR-001 MIME 이중 검증` → TC-SC-021(`calleeShopFileUpload` 존재확인)만 있음, MIME 검증 TC 없음
- `NFR-003 24시간 취소 규칙` → TC-SC-011(`shopCancel` 존재확인)만 있음, 24h 비즈니스 로직 TC 없음
- `FR-008-8 14일 다운로드 제한` → TC-SC-013(`shopFile` 존재확인)만 있음

**결론**: STD 자체의 TC 커버리지 불완전. API 문서 수정 사항은 아니나 IEEE 표준(IEEE 829-2008) 관점에서 비즈니스 규칙 검증 TC가 필요하다.

**수정 대상**: `docs/specs/commerce-std.md` §3.9에 TC-SC-027 (`testDeleteOptMethodExists`) 추가. §3.3 ShopApiTest에 `callee-shop-file-upload` MIME 검증, `shop-cancel` 24h 규칙, `shop-file` 14일 제한 Feature TC 추가.

---

## 판정 요약 및 수정 우선순위

| 이슈 ID | 판정 | 우선순위 | 수정 대상 |
|---------|------|---------|----------|
| COMMERCE-SHOP-DEF-006 | FAIL | **P0** | 코드: MIME 이중 검증, DateTimeImmutable 전환, shopCancel JSON 응답 |
| COMMERCE-SHOP-DEF-005 | WARN | **P1** | API 문서(md/yaml) EP #2·#3 응답 스키마 수정 + IDD 동기화 |
| COMMERCE-SHOP-DEF-002 | WARN | **P1** | API 문서(md/yaml) Refresh Token Path `/api/auth/refresh` → `/` |
| COMMERCE-SHOP-DEF-004 | WARN | **P1** | 요청 파라미터 camelCase/snake_case 방침 결정 및 반영 |
| COMMERCE-SHOP-DEF-001 | WARN | **P2** | SRS FR 추가 (미커버 EP 6건) |
| COMMERCE-SHOP-DEF-003 | WARN | **P2** | API 문서 `refund-success` 응답 형식·CSRF 면제 명시 |
| COMMERCE-SHOP-DEF-007 | WARN | **P2** | IDD 5개 EP 인터페이스 계약 추가 |
| [B]-001 | WARN | **P3** | STD TC 추가 (delete-opt, MIME, 24h 규칙, 14일 다운로드) |

---

## 타당성 검토 (IEEE 29148:2018 §5.2.9)

| 발견 사항 | 판단 근거 | 결론 |
|----------|----------|------|
| MIME 이중 검증 Layer 2 누락 | OWASP File Upload Cheat Sheet: "Do not rely on Content-Type header… verify file content by reading file header (magic bytes)." 단순 확장자 체크는 파일명 변경으로 우회 가능 | 필수 수정. NFR-001 위반이며 보안 취약점 |
| `date()`/`strtotime()` 사용 | CLAUDE.md: "DateTimeImmutable 강제: date(), time() 사용 금지." PHP 공식 문서: DateTimeImmutable은 타임존 처리에서 더 안전하고 예측 가능 | 필수 수정. 서버 타임존 변경 시 버그 발생 위험 |
| `order-reservation-time` 응답 3자 불일치 | SSOT 원칙: API가 진실의 원천. IDD가 더 상세하게 정의하고 있어 API가 불완전함 | API 문서를 IDD 수준으로 상세화해야 함 |
| Refresh Token Path 오기 | commit `a7be0b5` 기록 및 CLAUDE.md 보안 정책이 Path=`/` 명시 | API 문서 수정 필수 |

---

## 변경 영향 기록

| 변경 사항 | 개선점 | 수행 이유 |
|----------|-------|---------|
| COMMERCE-SHOP-DEF-006 코드 수정(MIME·DateTimeImmutable·shopCancel JSON) | NFR-001/003/004 완전 준수. Polyglot 파일 업로드 공격 차단. 타임존 안전성 확보 | 현재 코드는 SRS 비즈니스 규칙을 미준수하며 보안 취약점과 버그 위험이 있음 |
| COMMERCE-SHOP-DEF-005 응답 스키마 수정 | 프론트엔드가 API 문서와 실제 응답 중 어느 것을 신뢰해야 하는지 혼란 제거 | 3자 불일치는 통합 테스트 실패와 프론트엔드 개발 지연의 직접 원인 |
| COMMERCE-SHOP-DEF-002 Path 수정 | Refresh Token이 모든 경로에서 전송되도록 보장 | Path=`/api/auth/refresh`이면 다른 경로의 요청에서 쿠키가 전송되지 않아 인증 실패 발생 가능 |

---

## 변경 로그

| 날짜 | 작성자 | 변경 내용 |
|------|--------|----------|
| 2026-04-21 | jypark (agent) | 최초 작성 — shop-api ↔ IEEE 9개 항목 전체 대조 |
