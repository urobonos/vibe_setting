# payment 모듈 API ↔ IEEE 대조 리포트

> payment 모듈 API 문서(SSOT)와 IEEE 산출물(SRS/SDD/IDD/STD) 간 불일치를 대조하여 IEEE 업데이트 필요 항목을 식별한다.

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-21 |
| 유형 | report |
| 상태 | 초안 |
| SSOT 방향 | API → IEEE |
| 대상 API | `api-docs/payment/payment-api.md`, `api-docs/payment/payment-api.yaml` |
| 대상 IEEE | `docs/specs/payment-srs.md`, `payment-sdd.md`, `payment-idd.md`, `payment-std.md` |

## 내용

### 요약

| 항목 | 값 |
|------|-----|
| API 문서 EP 수 | 11개 (`payment-api.md` / `payment-api.yaml`) |
| SRS 엔드포인트 인덱스 EP 수 | 11개 (SRS §6) |
| SDD 컨트롤러별 EP 수 | 11개 (SDD §3) |
| IDD EP 수 (헤더 기재) | 11개 (IDD §1.1: "StripeController 2 + PayController 6 + PaybackController 3" → 합산 11) |
| Routes.php 등록 EP 수 | 11개 |
| 총 이슈 수 | **10건** |
| 이슈 분류 | [A] IEEE 업데이트 필요 8건 / [B] API 내부 불일치 2건 |
| 항목별 판정 | 양호(OK) 4 / 불일치(MISMATCH) 4 / 누락(MISSING) 1 / 경미(MINOR) 1 |

---

### 항목별 판정표

| # | 대조 항목 | 판정 | 이슈 ID |
|---|-----------|------|---------|
| 1 | EP 목록 일치 (md↔yaml↔Routes↔SRS FR-PAY-*) | MISMATCH | PAYMENT-DEF-001, PAYMENT-DEF-002 |
| 2 | EP-SRS 매핑 | MISMATCH | PAYMENT-DEF-003 |
| 3 | 인증/CSRF (웹훅·viewSimplepayPassword 면제 포함) | MISMATCH | PAYMENT-DEF-004 |
| 4 | X-Forwarded-Proto | OK | — |
| 5 | 응답 스키마 (camelCase 변환, data 래핑) | MINOR | PAYMENT-DEF-005 |
| 6 | 환경별 URL | OK | — |
| 7 | 비즈니스 규칙 (멱등키, Rate-limit, 트랜잭션 범위) | MISSING | PAYMENT-DEF-006, PAYMENT-DEF-007 |
| 8 | IDD 매핑 | MISMATCH | PAYMENT-DEF-008 |
| 9 | STD TC 커버리지 | OK | — |

---

### 이슈 상세

#### PAYMENT-DEF-001 [A] SRS/SDD EP 목록과 API EP 목록 불일치 — camelCase vs kebab-case URL

**분류**: IEEE 업데이트 필요 (SRS §6, SDD §3)
**발견 위치**: SRS §6 엔드포인트 목록, SDD §3 컴포지션 뷰포인트
**심각도**: High

**내용**:
SRS §6과 SDD §3은 **camelCase + 단수형** URL을 사용한다.
API 문서(`payment-api.md`)와 Routes.php는 **kebab-case + 복수형/현행형** URL을 사용한다.
프로젝트 라우트 정책(CLAUDE.md): "kebab-case + 복수형".

| SRS/SDD URL (잘못됨) | API/Routes URL (SSOT) | 비고 |
|---------------------|----------------------|------|
| `/api/stripe/createPaymentIntent` | `/api/stripe/create-payment-intent` | FR-PAY-001 관련 EP |
| `/api/stripe/confirmPayment` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| `/api/stripe/webhook` | `/api/stripe/webhook` | 일치 |
| `/api/pay/createOrder` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| `/api/pay/viewSimplepayPassword` | 해당 없음 (Routes.php 미등록) | 레거시 추정 → DEF-002 |
| `/api/pay/simplepayCharge` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| `/api/pay/cancelOrder` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| `/api/pay/getOrderList` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| `/api/pay/getOrderDetail` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| `/api/payback/getPaybackList` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| `/api/payback/requestPayback` | 해당 없음 (API에 미존재) | SRS에만 있음 → DEF-002 |
| (없음) | `/api/pay/get-my-card` | SRS 인덱스 미등재 |
| (없음) | `/api/pay/save-simplepay` | SRS 인덱스 미등재 |
| (없음) | `/api/pay/delete-simplepay` | SRS 인덱스 미등재 |
| (없음) | `/api/pay/del-auto-pay-card` | SRS 인덱스 미등재 |
| (없음) | `/api/pay/naverpay-order` | SRS 인덱스 미등재 |
| (없음) | `/api/pay/tosspay-order` | SRS 인덱스 미등재 |
| (없음) | `/api/pay/insert-in-app-coin-order` | SRS 인덱스 미등재 |
| (없음) | `/api/payback/get-list` | SRS 인덱스 미등재 |

**수정 지시**: SRS §6 엔드포인트 인덱스 전체를 API 문서(SSOT) 기준 11개 EP로 교체.
SDD §3.1~3.3 각 컨트롤러 메서드 테이블의 경로를 kebab-case로 교체.

---

#### PAYMENT-DEF-002 [A] SRS/SDD 설계 EP가 실제 구현 EP와 구조적으로 다름 (의미론적 불일치)

**분류**: IEEE 업데이트 필요 (SRS §3, §6, SDD §3)
**발견 위치**: SRS FR-PAY-001~008 관련 EP, SDD §3
**심각도**: High

**내용**:
SRS와 SDD에 기재된 EP는 이상적인 설계(createOrder, confirmPayment 등)를 반영하지만, 실제 구현된 Routes.php와 API 문서는 다른 EP 집합으로 구성되어 있다.

- SRS/SDD의 `POST /api/pay/createOrder`는 Routes.php에 없다. 실제로는 `POST /api/pay/naverpay-order`, `POST /api/pay/tosspay-order`, `POST /api/pay/insert-in-app-coin-order`로 PG별 분리 구현됨.
- SRS/SDD의 `POST /api/stripe/confirmPayment`는 Routes.php에 없다.
- SRS/SDD의 `POST /api/pay/simplepayCharge`는 없고, 실제로는 `POST /api/pay/save-simplepay` (act 파라미터 분기)로 통합됨.
- SRS §3의 FR-PAY-003 관련 EP `POST /api/pay/viewSimplepayPassword`가 언급되나 Routes.php에 없고 CsrfTokenFilter 면제 경로에는 존재함 (레거시 경로로 추정).

**수정 지시**:
- SRS §6 인덱스를 Routes.php(SSOT) 기반 11개 실제 EP로 재작성.
- SRS FR-PAY-001 "관련 EP" → `/api/stripe/create-payment-intent`, `/api/stripe/webhook`으로 수정.
- SRS FR-PAY-003 "관련 EP" → `/api/pay/save-simplepay` (act 분기)로 수정.
- SRS FR-PAY-005 "관련 EP" → `/api/pay/naverpay-order`로 수정.
- SRS FR-PAY-006 "관련 EP" → `/api/pay/tosspay-order`로 수정.
- SRS FR-PAY-007 "관련 EP" → `/api/pay/insert-in-app-coin-order`로 수정.
- SRS FR-PAY-008 "관련 EP" → `/api/payback/get-list`로 수정.
- SDD §3.1~3.3 메서드 테이블을 실제 구현 기준으로 재작성.

---

#### PAYMENT-DEF-003 [A] IDD §10 추적성 매트릭스 FR 번호가 SRS FR 번호와 불일치

**분류**: IEEE 업데이트 필요 (IDD §10 추적성 매트릭스)
**발견 위치**: SRS §3, IDD §10
**심각도**: Medium

**내용**:
IDD §10 추적성 매트릭스의 FR 번호 및 제목이 SRS §3과 불일치한다.

| IDD §10 기재 (잘못됨) | SRS §3 실제 FR (SSOT) | 불일치 내용 |
|-----------------------|----------------------|------------|
| FR-PAY-001 "주문 생성 + 코인 충전" | FR-PAY-001 "Stripe 신용카드 결제" | 제목 불일치 |
| FR-PAY-002 "Stripe PaymentIntent 결제" | FR-PAY-002 "Stripe 웹훅 처리" | 번호 밀림 |
| FR-PAY-003 "Stripe 웹훅 처리" | FR-PAY-003 "간편결제(Simplepay)" | 번호 밀림 |
| FR-PAY-004 "Naver Pay 결제" | FR-PAY-004 "자동결제(Autopay)" | 번호 밀림 |
| FR-PAY-005 "Toss Pay 결제" | FR-PAY-005 "Naver Pay 연동" | 번호 밀림 |
| FR-PAY-006 "자동결제(Autopay)" | FR-PAY-006 "Toss Pay 연동" | 번호 밀림 |
| FR-PAY-007 "페이백(Payback)" | FR-PAY-007 "인앱 구매(코인 충전)" | 번호 밀림 |
| FR-PAY-008 "코인백(CoinBack)" | FR-PAY-008 "페이백(Payback)" | 번호 밀림 |
| FR-PAY-009 "결제 알림" | FR-PAY-009 "코인백(Coin Back)" | SRS에 "결제 알림" FR 없음 |

SRS에는 "결제 알림"이 독립 FR로 존재하지 않는다(알림은 PaymentNotifier 구현 내부 관심사).

**수정 지시**: IDD §10 추적성 매트릭스 FR-PAY-001~009 전체를 SRS §3 기준으로 재정렬. SDD §2 다이어그램 내 FR 참조도 동기화.

---

#### PAYMENT-DEF-004 [A] SRS CSRF 면제 목록과 CsrfTokenFilter 실제 면제 목록 불일치

**분류**: IEEE 업데이트 필요 (SRS §2.4 제약사항)
**발견 위치**: SRS §2.4, `app/Filters/CsrfTokenFilter.php` EXCLUDED_PATHS
**심각도**: Medium

**내용**:
SRS §2.4는 CSRF 면제 EP를 다음 두 가지로 기술한다:
```
`api/stripe/webhook`, `api/pay/viewSimplepayPassword`는 서버-서버 통신으로 CSRF 면제
```

실제 `CsrfTokenFilter.php` EXCLUDED_PATHS에는 다음이 등재되어 있다:
```php
'api/stripe/webhook',
'api/pay/viewSimplepayPassword',
'api/pay/ViewSimplepayPassword',   // 대소문자 변형 추가
'api/payback/get-list',            // 공개 조회 EP
```

차이점:
1. `api/pay/ViewSimplepayPassword` (대소문자 변형)가 SRS에 누락.
2. `api/payback/get-list`가 SRS CSRF 면제 목록에 누락.
3. `api/pay/viewSimplepayPassword`는 Routes.php에 미등록(레거시 경로 추정). SRS에서 신규 EP처럼 기술되어 혼동 유발.

**수정 지시**:
- SRS §2.4 CSRF 면제 목록을 CsrfTokenFilter EXCLUDED_PATHS 기준으로 갱신.
- `api/pay/viewSimplepayPassword` 경로의 레거시 여부를 명시하거나 Routes.php에 추가 (Open Question Q-01 참조).

---

#### PAYMENT-DEF-005 [B] API Markdown의 Refresh Token Path 표기 오류

**분류**: API 내부 불일치 (`payment-api.md`)
**발견 위치**: `api-docs/payment/payment-api.md` L39 JWT 인증 테이블
**심각도**: Low

**내용**:
`payment-api.md` JWT 인증 테이블에서 Refresh Token의 `Path` 값이 `/api/auth/refresh`로 기재되어 있다.
커밋 `a7be0b5`(fix: Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대) 및 CLAUDE.md 지침 기준으로
Refresh Token Path는 `/`로 확대되었다.

`payment-api.yaml`에는 해당 섹션이 없으므로 md만 해당.

**수정 지시**: `payment-api.md` JWT 인증 테이블 Refresh Token Path를 `/api/auth/refresh` → `/`로 수정.

---

#### PAYMENT-DEF-006 [A] SRS/IDD에 멱등키 생성 주체 명세 누락

**분류**: IEEE 업데이트 필요 (SRS FR-PAY-001-4, IDD §7.2)
**발견 위치**: SRS FR-PAY-001-4, IDD §7.2 주문 생성 요청/응답 예시
**심각도**: Medium

**내용**:
SRS NFR-PAY-001에서 "모든 결제 생성 요청에 멱등키를 포함해야 한다"고 요구하지만,
API 문서 EP 명세에는 멱등키 관련 요청 파라미터나 헤더가 기재되어 있지 않다.

IDD §7.2 주문 생성 요청 예시에는 `idempotency_key`가 응답에만 포함되어 있고,
클라이언트 전달 여부(서버 자동 생성 vs 클라이언트 제공)가 불명확하다.

SDD §4.1의 `generateIdempotencyKey(acId, productId)` 설계상 서버가 자동 생성하지만,
이 사실이 API 문서와 SRS에 명시되지 않았다.

**수정 지시**:
- SRS FR-PAY-001-4에 "멱등키는 서버(`PaymentService.generateIdempotencyKey`)가 자동 생성. 클라이언트 별도 전달 불필요"를 명시.
- IDD §7.2 주문 생성 요청 예시에 멱등키 생성 주체와 형식 주석 추가.
- API 문서 각 결제 EP 설명란에 "멱등키 서버 자동 생성" 안내 추가 권장.

---

#### PAYMENT-DEF-007 [A] SRS §4에 Rate-limit 비기능 요구사항 누락

**분류**: IEEE 업데이트 필요 (SRS §4 NFR)
**발견 위치**: `payment-api.md` Rate Limit 섹션, SRS §4
**심각도**: Low

**내용**:
API 문서에는 다음과 같이 Rate Limit 명세가 있다:
- 기본 제한: 60회 / 60초 (IP 기반)
- 초과 시: HTTP 429 + `Retry-After` 헤더
- 필터 체인: `ratelimit` → `csrftoken` → `auth` → Controller

그러나 SRS §4 비기능 요구사항(NFR-PAY-001~005)에 Rate Limit 관련 NFR이 없다.

**수정 지시**: SRS §4에 NFR-PAY-006 신설:
- 60회/60초 IP 기반 제한
- HTTP 429 응답 + `Retry-After` 헤더
- 필터 체인 내 `ratelimit` 최우선 적용

---

#### PAYMENT-DEF-008 [A] IDD §1.1 컨트롤러별 EP 수 기재 오류

**분류**: IEEE 업데이트 필요 (IDD §1.1)
**발견 위치**: IDD §1.1 Identification 테이블
**심각도**: Low

**내용**:
IDD §1.1 기재: "EP 총수: 11개 (PayController 6 + StripeController 2 + PaybackController 3)"

Routes.php 실제 분포:
- `PayController`: 7개 (get-my-card, save-simplepay, delete-simplepay, del-auto-pay-card, naverpay-order, tosspay-order, insert-in-app-coin-order)
- `StripeController`: 3개 (create-payment-intent, create-setup-intent, webhook)
- `PaybackController`: 1개 (get-list)

IDD의 분류는 SRS 설계 기준이며 실제 구현과 다르다. 총 11개는 동일하나 컨트롤러별 분포가 불일치.

**수정 지시**: IDD §1.1을 "11개 (PayController 7 + StripeController 3 + PaybackController 1)"로 수정.

---

#### PAYMENT-DEF-009 [B] API Markdown CSRF 면제 설명이 불완전

**분류**: API 내부 불일치 (`payment-api.md`)
**발견 위치**: `api-docs/payment/payment-api.md` L28 CSRF 섹션
**심각도**: Low

**내용**:
`payment-api.md` CSRF 섹션의 현재 기술:
```
> **CSRF 면제**: 인증이 불필요한 공개 EP(인증 `—`)는 `X-CSRF-TOKEN` 헤더가 불필요합니다.
```
이 설명은 "인증 없음 = CSRF 면제"로 오해할 수 있다. 실제 면제 기준은 CsrfTokenFilter EXCLUDED_PATHS 등재 여부다.

`api/payback/get-list`는 POST 메서드이고 EXCLUDED_PATHS에 등재되어 CSRF 면제이지만, API 문서에 이 사실이 명시되지 않았다.

**수정 지시**: `payment-api.md` CSRF 섹션에 면제 EP 목록 명시:
- `POST /api/stripe/webhook`: 서버-서버 통신 면제
- `POST /api/payback/get-list`: CsrfTokenFilter EXCLUDED_PATHS 등재로 면제

---

#### PAYMENT-DEF-010 [A] STD에 SRS 범위 외 PaypalTest 포함

**분류**: IEEE 업데이트 필요 (STD §2.1, SRS §1.2)
**발견 위치**: STD §2.1 테스트 대상 목록
**심각도**: Low

**내용**:
STD §2.1에 `PaypalTest (Unit)` 7건(TC-PAY-103~109)이 포함되어 있으나,
SRS §1.2 의존 외부 서비스 목록("Stripe PHP SDK, NaverPay API, TossPay API, NiceAutopay API, Kakao AlimTalk")에 PayPal이 없다.
API 문서에도 PayPal 관련 EP가 없다.

**수정 지시**:
- PayPal이 실제 지원 PG라면: SRS §1.2 의존 외부 서비스에 추가 + FR-PAY-XXX 신설.
- PayPal이 레거시/미사용 코드라면: STD §2.1에서 "범위 외 (레거시)" 별도 섹션으로 이동.

---

### 엔드포인트 매트릭스

| # | Method | API URL (SSOT) | Routes.php | SRS §6 | SDD §3 | IDD 추적 | STD TC |
|---|--------|----------------|-----------|--------|---------|---------|---------|
| 1 | POST | `/api/payback/get-list` | O | X (getPaybackList로 기재) | X | IF-INT-001 getPaybackList | TC-PAY-006~008 |
| 2 | POST | `/api/stripe/create-payment-intent` | O | X (createPaymentIntent로 기재) | X (createPaymentIntent로 기재) | IF-INT-003, IF-EXT-001 | TC-PAY-009, TC-PAY-136, TC-PAY-142 |
| 3 | POST | `/api/stripe/create-setup-intent` | O | X (미등재) | X (미등재) | IF-INT-003 createSetupIntent | TC-PAY-010, TC-PAY-137, TC-PAY-143 |
| 4 | POST | `/api/stripe/webhook` | O | O | O | IF-INT-003 constructWebhookEvent | TC-PAY-011~013, TC-PAY-138 |
| 5 | POST | `/api/pay/get-my-card` | O | X (미등재) | X (미등재) | — | TC-PAY-043 |
| 6 | POST | `/api/pay/save-simplepay` | O | X (simplepayCharge 등 분리 기재) | X (simplepayCharge 등 분리 기재) | IF-INT-001 | TC-PAY-001~002, TC-PAY-048, TC-PAY-110~134 |
| 7 | DELETE | `/api/pay/delete-simplepay` | O | X (미등재) | X (미등재) | IF-INT-001 | TC-PAY-003, TC-PAY-049 |
| 8 | DELETE | `/api/pay/del-auto-pay-card` | O | X (미등재) | X (미등재) | IF-INT-002 | TC-PAY-005, TC-PAY-050 |
| 9 | POST | `/api/pay/naverpay-order` | O | X (createOrder pg=naver로 기재) | X (createOrder로 기재) | IF-EXT-002 | TC-PAY-051 |
| 10 | POST | `/api/pay/tosspay-order` | O | X (createOrder pg=toss로 기재) | X (createOrder로 기재) | IF-EXT-003 | TC-PAY-052 |
| 11 | POST | `/api/pay/insert-in-app-coin-order` | O | X (미등재) | X (미등재) | IF-INT-001 insertCoinOrder | TC-PAY-004, TC-PAY-093 |

**범례**: O = 일치 / X = 불일치 또는 미등재

---

### Open Questions

| ID | 질문 | 관련 이슈 |
|----|------|-----------|
| Q-01 | `api/pay/viewSimplepayPassword`는 Routes.php 미등록이지만 CsrfTokenFilter EXCLUDED_PATHS에 존재한다. 레거시 제거 예정인가, Routes.php에 추가해야 하는가? SRS FR-PAY-003-5 설계 의도와 구현 현황이 불일치한다. | PAYMENT-DEF-004 |
| Q-02 | STD의 `PaypalTest` 7건은 SRS/API 범위 외다. PayPal 지원 여부를 확인하여 SRS 범위 추가 또는 STD 레거시 분리가 필요하다. | PAYMENT-DEF-010 |
| Q-03 | SRS/SDD에 기재된 `POST /api/stripe/confirmPayment`, `POST /api/pay/cancelOrder`, `GET /api/pay/getOrderList`, `GET /api/pay/getOrderDetail`은 Routes.php에 없다. 미구현 상태인가, 레거시 경로를 사용하는가? | PAYMENT-DEF-002 |
| Q-04 | `api/payback/get-list`는 POST 메서드이나 CSRF 면제다. POST 공개 EP에 CSRF를 적용하지 않는 것이 보안 정책상 의도적인지 확인이 필요하다. | PAYMENT-DEF-009 |

## 체크리스트

- [ ] PAYMENT-DEF-001: SRS §6 엔드포인트 인덱스 전체를 kebab-case 실제 EP 기준으로 교체
- [ ] PAYMENT-DEF-002: SRS FR-PAY-001~008 "관련 EP" 필드를 실제 구현 EP로 수정. SDD §3.1~3.3 메서드 테이블 재작성
- [ ] PAYMENT-DEF-003: IDD §10 추적성 매트릭스 FR-PAY-001~009 SRS §3 기준으로 재정렬
- [ ] PAYMENT-DEF-004: SRS §2.4 CSRF 면제 목록 갱신. Q-01 결정 후 Routes.php 또는 SRS 레거시 표기
- [ ] PAYMENT-DEF-005: `payment-api.md` Refresh Token Path → `/`로 수정
- [ ] PAYMENT-DEF-006: SRS FR-PAY-001-4에 멱등키 서버 자동 생성 명시. IDD §7.2 주석 추가
- [ ] PAYMENT-DEF-007: SRS §4에 NFR-PAY-006 Rate Limit 요구사항 신설
- [ ] PAYMENT-DEF-008: IDD §1.1 컨트롤러별 EP 수 "(PayController 7 + StripeController 3 + PaybackController 1)"로 수정
- [ ] PAYMENT-DEF-009: `payment-api.md` CSRF 섹션에 면제 EP 목록 명시
- [ ] PAYMENT-DEF-010: PayPal 지원 여부 확인 후 SRS 범위 추가 또는 STD 레거시 섹션 이동
- [ ] Q-01~Q-04 Open Questions 사용자 승인 및 처리 결과 반영

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-21 | 최초 작성 — payment 모듈 API ↔ IEEE 대조 10건 이슈 식별 | jypark |
