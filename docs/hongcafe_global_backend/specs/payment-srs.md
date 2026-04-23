---
문서명: Payment — Software Requirements Specification
문서ID: SRS-PAY-001
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
적용 표준: IEEE 29148:2018
대상 시스템: HongCafe Global Backend — Payment Module
관련 문서:
  - payment-sdd.md (SDD-PAY-001)
  - payment-idd.md (IDD-PAY-001)
  - docs/api-specification.md
---

# Payment — Software Requirements Specification

> IEEE 29148:2018 준수 | version: 2.1 | lastUpdated: 2026-04-21 | module: Payment

---

## 1. 문서 개요 (Document Overview)

### 1.1 목적 (Purpose)

본 문서는 HongCafe Global Backend Payment 모듈의 기능 요구사항(FR) 및 비기능 요구사항(NFR)을 ISO/IEC/IEEE 29148:2018 표준에 따라 명세한다.

Payment 모듈은 Stripe 신용카드 결제, 간편결제(NiceAutopay Simplepay), 외부 PG 연동(Naver Pay, Toss Pay), 인앱 구매(코인 충전), 페이백(Payback), 코인백(Coin Back), 자동결제(Autopay) 기능을 포함한다. 총 11개 엔드포인트에 걸쳐 결제 생애주기 전반을 담당한다.

This document specifies functional requirements (FR) and non-functional requirements (NFR) for the Payment module of HongCafe Global Backend, conforming to ISO/IEC/IEEE 29148:2018. The module covers the full payment lifecycle across 11 endpoints.

### 1.2 범위 (Scope)

| 항목 | 내용 |
|------|------|
| 모듈 경로 | `app/Modules/Payment/` |
| 컨트롤러 | `PaybackController`, `PayController`, `StripeController` |
| 총 엔드포인트 | 11개 |
| 연관 테이블 | `tb_order`, `tb_product`, `tb_coin`, `tb_simplepay`, `tb_autopay` |
| 의존 외부 서비스 | Stripe PHP SDK, NaverPay API, TossPay API, NiceAutopay API, Kakao AlimTalk |
| 이해관계자 | 일반 사용자(Caller), 시스템(Cron/Lambda), Stripe Webhook, PG 시스템 |

### 1.3 용어 정의 (Definitions, Acronyms, Abbreviations)

| 용어 | 정의 |
|------|------|
| PG | Payment Gateway — 결제 대행사 |
| Idempotency Key | 멱등키. 동일 요청 중복 처리를 방지하는 고유 식별자 |
| Autopay | 자동결제. 저장된 카드로 주기적 또는 조건 충족 시 실행되는 반복 결제 |
| Payback | 페이백. 결제 금액의 일정 비율을 포인트로 환급하는 보상 기능 |
| Coin | 코인. 서비스 내 가상 화폐 단위 |
| Simplepay | 간편결제. 카드 빌링키를 저장하여 비밀번호(PIN)만으로 결제하는 방식 |
| Webhook | 웹훅. 외부 PG가 결제 결과를 서버로 비동기 전송하는 HTTP 콜백 |
| Billing Key | 카드 정보를 토큰화한 값. PCI DSS 준수를 위해 카드 원본 데이터 대신 저장 |
| CSRF | Cross-Site Request Forgery — 요청 위변조 공격. Signed Double Submit Cookie 방식으로 방어 |
| AlimTalk | Kakao 비즈니스 메시지 API를 통한 카카오톡 알림 발송 서비스 |
| FR | Functional Requirement — 기능 요구사항 |
| NFR | Non-Functional Requirement — 비기능 요구사항 |
| PCI DSS | Payment Card Industry Data Security Standard |

### 1.4 참고 문서 (References)

| 문서 | 경로 |
|------|------|
| ISO/IEC/IEEE 29148:2018 | Systems and software engineering — Life cycle processes — Requirements engineering |
| API 명세서 | `docs/api-specification.md` |
| 소프트웨어 설계 명세서 | `docs/specs/payment-sdd.md` (SDD-PAY-001) |
| 인터페이스 설계 명세서 | `docs/specs/payment-idd.md` (IDD-PAY-001) |
| 인프라 구성 | `docs/infrastructure.md` |
| 프로젝트 지침 | `CLAUDE.md` |

### 1.5 문서 개요 (Document Overview)

| 섹션 | 내용 |
|------|------|
| 섹션 1 | 목적, 범위, 용어 정의, 참고 문서 |
| 섹션 2 | 전체 시스템 설명 — 컨텍스트, 기능 요약, 사용자 특성, 제약사항, 가정 |
| 섹션 3 | 기능 요구사항 (FR-PAY-001 ~ FR-PAY-009) |
| 섹션 4 | 비기능 요구사항 (NFR-PAY-001 ~ NFR-PAY-006) |
| 섹션 5 | 유스케이스 (UC-PAY-001 ~ UC-PAY-003) |
| 섹션 6 | 엔드포인트 목록 |
| 섹션 7 | 타당성 검토 |
| 섹션 8 | 변경 기록 |

---

## 2. 전체 시스템 설명 (Overall Description)

### 2.1 제품 관점 (Product Perspective)

Payment 모듈은 HongCafe Global Backend의 Modular Monolith 아키텍처 내 독립 Bounded Context(BC)이다. 다음 시스템들과 상호작용한다.

```
[클라이언트 (Next.js)]
        │
        ▼
[Payment Module]  ──────────────────────────────────────────────────────────┐
   PayController                                                             │
   StripeController ──→ [Stripe API]  (PaymentIntent, Charge, Webhook)       │
   PaybackController                                                         │
        │                                                                    │
        ├──→ [NaverPay API]   (Reserve, Approve, Cancel)                     │
        ├──→ [TossPay API]    (Confirm, Cancel)                              │
        ├──→ [NiceAutopay]    (BillingKey, Charge)                           │
        ├──→ [Kakao AlimTalk] (결제 완료/실패/포인트 알림)                    │
        └──→ [Aurora MySQL]   (tb_order, tb_product, tb_coin,                │
                               tb_simplepay, tb_autopay)                     │
```

**모듈 간 통신**: 다른 모듈이 결제 데이터를 필요로 하는 경우 `PaymentServiceInterface`를 `service()` DI를 통해 주입받아 사용한다. 직접 DB 테이블 접근은 허용하지 않는다.

### 2.2 제품 기능 요약 (Product Functions)

| 기능 그룹 | 기능 |
|----------|------|
| Stripe 결제 | PaymentIntent 생성, 결제 확정, 웹훅 비동기 처리 |
| 간편결제 | 카드 빌링키 등록, PIN 기반 결제 실행 |
| 외부 PG | Naver Pay Reserve/Approve, Toss Pay Confirm |
| 자동결제 | Stripe Charge / NiceAutopay 반복 결제, 재시도 관리 |
| 코인 충전 | 코인 패키지 구매, tb_coin 잔액 갱신 |
| 페이백 | 결제 금액의 일정 비율 포인트 환급, 이력 기록 |
| 코인백 | 조건 충족 시 코인 환급, 알림 발송 |
| 알림 | 결제 성공/실패 이메일 + AlimTalk 발송 |

### 2.3 사용자 특성 (User Characteristics)

| 사용자 유형 | 특성 |
|------------|------|
| 일반 사용자 (Caller) | 코인 구매, 간편결제, 페이백 조회 수행 |
| 상담사 (Callee) | Payment 기능 직접 사용 없음. 코인 사용은 상담 완료 후 자동 차감 |
| 시스템 (Cron/Lambda) | 자동결제(`AutopayService`) 트리거 |
| Stripe (Webhook) | 결제 결과를 비동기로 서버에 전송 |

### 2.4 제약사항 (Constraints)

| 제약 유형 | 내용 |
|----------|------|
| 보안 | 카드번호, CVC는 서버에서 직접 처리하지 않는다 (PCI DSS Level 4 준수) |
| 인증 | 모든 결제 EP는 JWT (`hc_access` 쿠키) 필수. 웹훅 EP만 예외 |
| CSRF | 아래 경로는 `CsrfTokenFilter` EXCLUDED_PATHS에 등재되어 CSRF 검증을 면제한다: `api/stripe/webhook` (서버-서버 통신), `api/pay/viewSimplepayPassword` (레거시 — Routes.php 미등록, 면제 경로 유지 중. Q-01 참조), `api/pay/ViewSimplepayPassword` (대소문자 변형, 동일 면제), `api/payback/get-list` (공개 조회 EP, 면제 의도 확인 필요. Q-04 참조) |
| 멱등성 | 모든 결제 생성 요청에 멱등키 필수 (DB UNIQUE + PG Idempotency-Key 이중 적용) |
| 언어 | 에러 메시지는 `lang()` 키 사용. 하드코딩 문자열 금지 |
| 시간 | 모든 날짜/시간은 UTC 기준. `date()`, `time()` 사용 금지. `DateTimeImmutable` 강제 |
| 타입 | 모든 PHP 파일에 `declare(strict_types=1)` 필수 |

### 2.5 가정 및 의존성 (Assumptions and Dependencies)

- Stripe PHP SDK(`stripe/stripe-php`)가 Composer로 설치되어 있다.
- 환경변수 `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `NAVERPAY_CHAIN_ID`, `NAVERPAY_CLIENT_SECRET`, `TOSS_CLIENT_KEY`, `TOSS_SECRET_KEY`, `NICE_MERCHANT_ID`, `NICE_MERCHANT_KEY`, `ALIMTALK_API_KEY`, `ALIMTALK_SENDER_KEY`가 설정되어 있다.
- Aurora MySQL의 `tb_order.idempotency_key` 컬럼에 UNIQUE 제약이 적용되어 있다.
- Stripe 웹훅 엔드포인트가 Stripe Dashboard에 등록되어 있다.
- 모든 PG API는 HTTPS(TLS 1.2+)를 통해 통신한다.

---

## 3. 기능 요구사항 (Functional Requirements)

### FR-PAY-001: Stripe 신용카드 결제

**요약**: 사용자가 Stripe SDK를 통해 신용카드 결제를 진행할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-001-1 | `StripeController.createPaymentIntent()`가 PaymentIntent 객체를 생성하고 클라이언트에 `client_secret`을 반환한다 |
| FR-PAY-001-2 | 결제 전 `PaymentService.cancelOldReadyOrders()`를 호출하여 동일 사용자의 기존 `ready` 상태 주문을 일괄 취소한다 |
| FR-PAY-001-3 | 주문 생성 시 `tb_order`에 레코드를 삽입하고 `status = 'ready'`로 초기화한다 |
| FR-PAY-001-4 | 멱등키(`idempotency_key`)는 **서버(`PaymentService.generateIdempotencyKey`)가 자동 생성**한다. 클라이언트가 별도로 멱등키를 전달할 필요 없다. 생성된 멱등키를 Stripe API 호출 시 `Idempotency-Key` 헤더로 전달한다 |
| FR-PAY-001-5 | `payment_intent.succeeded` 웹훅 수신 후 `tb_order.status`를 `'paid'`로 갱신하고 `tb_coin`에 구매 코인을 적립한다 |

**선행 조건**: 사용자가 로그인 상태이고 유효한 JWT 쿠키(`hc_access`)를 보유한다.

**후행 조건**: `tb_order.status = 'paid'`, `tb_coin`에 구매 코인 적립 완료.

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/stripe/create-payment-intent`, `POST /api/stripe/webhook`

---

### FR-PAY-002: Stripe 웹훅 처리

**요약**: Stripe가 발송하는 웹훅 이벤트를 수신하여 결제 결과를 비동기로 처리한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-002-1 | `POST /api/stripe/webhook` 전용 엔드포인트에서 Stripe 웹훅 페이로드를 수신한다 |
| FR-PAY-002-2 | `Stripe-Signature` 헤더를 HMAC-SHA256으로 검증하여 위변조된 요청을 즉시 거부한다 |
| FR-PAY-002-3 | 처리 대상 이벤트: `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded` |
| FR-PAY-002-4 | 이벤트 처리는 멱등적으로 수행한다 — 동일 이벤트 ID 재수신 시 중복 처리를 실행하지 않는다 |
| FR-PAY-002-5 | 처리 중 내부 오류 발생 시 HTTP 200을 반환하여 Stripe의 불필요한 재시도를 방지하고, 에러는 내부 로그로 기록한다 |
| FR-PAY-002-6 | 서명 검증 실패 시 HTTP 400을 반환하고 보안 로그를 기록한다 |

**보안 면제**: CSRF 검증 면제 (서버-서버 통신), AuthFilter 제외 경로에 등록.

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/stripe/webhook`

---

### FR-PAY-003: 간편결제 (Simplepay)

**요약**: 사용자가 카드를 등록하고 PIN만으로 간편하게 결제할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-003-1 | NiceAutopay JavaScript SDK를 통해 카드 빌링키를 발급받고 `tb_simplepay`에 저장한다 |
| FR-PAY-003-2 | 카드번호, 유효기간, CVC를 서버에서 직접 수신하지 않는다 (PCI DSS 준수) |
| FR-PAY-003-3 | 간편결제 PIN은 AES-256-CBC + 고유 IV로 암호화하여 저장한다 |
| FR-PAY-003-4 | 결제 시 저장된 빌링키와 PIN 검증 후 NiceAutopay 자동결제 API를 호출한다 |
| FR-PAY-003-5 | 간편결제 PIN 검증 EP(`POST /api/pay/viewSimplepayPassword`)는 CSRF 면제 처리한다 |

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/pay/save-simplepay` (act 파라미터로 등록/결제 분기. `simplepayCharge`는 미구현 — Q-03 참조). `POST /api/pay/viewSimplepayPassword`는 Routes.php 미등록 (레거시 추정 — Q-01 참조)

---

### FR-PAY-004: 자동결제 (Autopay)

**요약**: 주기적으로 또는 트리거 조건 충족 시 저장된 카드로 자동 결제가 실행되어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-004-1 | `AutopayService`가 `tb_autopay` 테이블을 조회하여 결제 예정일이 도래한 활성 대상을 선정한다 |
| FR-PAY-004-2 | PG 타입에 따라 Stripe Charge API 또는 NiceAutopay API를 통해 결제를 실행한다 |
| FR-PAY-004-3 | 결제 성공 시 `tb_autopay`의 상태와 다음 결제일을 갱신하고, `tb_order`에 결제 레코드를 삽입한다 |
| FR-PAY-004-4 | 결제 실패 시 재시도 횟수를 증가시키고, 최대 재시도(3회) 초과 시 `tb_autopay.status`를 `'inactive'`로 변경한다 |
| FR-PAY-004-5 | 사이클 기반 멱등키를 생성하여 동일 사이클에서 중복 청구를 방지한다 |

**우선순위**: P1 (필수)

---

### FR-PAY-005: Naver Pay 연동

**요약**: 사용자가 Naver Pay를 통해 결제할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-005-1 | Naver Pay Reserve API를 호출하여 결제 URL을 발급받고 클라이언트에 반환한다 |
| FR-PAY-005-2 | 결제 완료 후 Approve API를 호출하여 최종 결제를 확정하고 `tb_order`를 `'paid'`로 갱신한다 |
| FR-PAY-005-3 | 취소 요청 시 Naver Pay 취소 API를 호출하고 `tb_order`를 `'cancelled'` 상태로 갱신한다 |
| FR-PAY-005-4 | `X-NaverPay-Idempotency-Key` 헤더를 포함하여 동일 주문에 대한 중복 승인을 방지한다 |

**우선순위**: P2 (중요)

**관련 EP**: `POST /api/pay/naverpay-order`

---

### FR-PAY-006: Toss Pay 연동

**요약**: 사용자가 Toss Pay를 통해 결제할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-006-1 | Toss Pay 결제 승인 API를 호출하여 최종 결제를 확정한다 |
| FR-PAY-006-2 | 결제 성공/실패 콜백을 처리하는 전용 엔드포인트를 제공한다 |
| FR-PAY-006-3 | 영수증 데이터(`paymentKey`, `orderId`, `amount`)를 `tb_order.pg_response`에 저장한다 |
| FR-PAY-006-4 | 취소 요청 시 Toss Pay 취소 API를 호출하고 `tb_order`를 `'cancelled'` 상태로 갱신한다 |

**우선순위**: P2 (중요)

**관련 EP**: `POST /api/pay/tosspay-order`

---

### FR-PAY-007: 인앱 구매 (코인 충전)

**요약**: 사용자가 서비스 내 가상 화폐(코인)를 구매하여 잔액에 적립할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-007-1 | `tb_product`에 등록된 활성 코인 패키지 목록을 조회하여 사용자에게 제공한다 |
| FR-PAY-007-2 | 결제 성공 시 구매한 코인량을 `tb_coin`의 잔액에 원자적으로(단일 트랜잭션) 추가한다 |
| FR-PAY-007-3 | 코인 충전 내역(type = `'charge'`)을 `tb_coin` 트랜잭션 테이블에 기록한다 |
| FR-PAY-007-4 | 충전 완료 후 `PaymentNotifier`를 통해 이메일 및 AlimTalk 알림을 발송한다 |

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/pay/insert-in-app-coin-order`

---

### FR-PAY-008: 페이백 (Payback)

**요약**: 결제 금액의 일정 비율을 포인트로 환급하는 보상 기능을 제공한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-008-1 | `PaybackController`가 페이백 목록 조회 및 페이백 신청 엔드포인트를 제공한다 |
| FR-PAY-008-2 | 페이백 지급 시 멱등키를 사용하여 동일 주문에 대한 중복 지급을 방지한다 |
| FR-PAY-008-3 | 페이백 지급 내역은 별도 이력 테이블에 기록한다 |
| FR-PAY-008-4 | 취소 요청 처리 시 이미 지급된 페이백 포인트를 회수하는 로직을 포함한다 |

**우선순위**: P2 (중요)

**관련 EP**: `POST /api/payback/get-list` (`getPaybackList`, `requestPayback`은 Routes.php 미등록 — Q-03 참조)

---

### FR-PAY-009: 코인백 (Coin Back)

**요약**: 특정 조건 충족 시 결제 금액의 일부를 코인으로 환급하는 기능을 제공한다.

| ID | 요구사항 |
|----|----------|
| FR-PAY-009-1 | 코인백 지급 조건은 `tb_product.coin_back_amount` 필드에서 조회한다 |
| FR-PAY-009-2 | 코인백 지급은 결제 완료 이벤트(`chargeComplete`) 후 `PaymentNotifier`를 통해 처리한다 |
| FR-PAY-009-3 | 지급 시 멱등키를 사용하여 중복 지급을 방지한다 |
| FR-PAY-009-4 | 코인백 지급 결과를 사용자에게 이메일 또는 AlimTalk으로 알린다 |
| FR-PAY-009-5 | 코인백 트랜잭션은 type = `'coinback'`으로 `tb_coin`에 기록한다 |

**우선순위**: P3 (선택)

---

## 4. 비기능 요구사항 (Non-Functional Requirements)

### NFR-PAY-001: 멱등성 (Idempotency)

| ID | 요구사항 |
|----|----------|
| NFR-PAY-001-1 | 모든 결제 생성 요청은 멱등키를 포함해야 한다 |
| NFR-PAY-001-2 | 동일 멱등키로 중복 요청 수신 시 동일한 응답을 반환하되, 결제 동작은 한 번만 실행한다 |
| NFR-PAY-001-3 | `tb_order.idempotency_key`에 UNIQUE 제약을 적용하여 DB 레벨 중복 삽입을 방지한다 |
| NFR-PAY-001-4 | Stripe API 호출 시 `Idempotency-Key` 헤더를 전달하여 PG 레벨 중복 방지를 보장한다 |

### NFR-PAY-002: PG 안정성 및 가용성

| ID | 요구사항 |
|----|----------|
| NFR-PAY-002-1 | Stripe, Naver Pay, Toss Pay, NiceAutopay 각 PG API 타임아웃은 30초 이내로 설정한다 |
| NFR-PAY-002-2 | PG API 호출 실패 시 최대 3회 재시도한다 (Exponential Backoff 적용) |
| NFR-PAY-002-3 | PG 장애 시 사용자에게 명확한 에러 메시지를 반환하고 `tb_order`를 `'failed'` 상태로 기록한다 |
| NFR-PAY-002-4 | 알림 시스템(AlimTalk, 이메일) 장애는 결제 상태 갱신에 영향을 주지 않는다 (격리 처리) |

### NFR-PAY-003: 보안

| ID | 요구사항 |
|----|----------|
| NFR-PAY-003-1 | 카드 정보(번호, CVC)는 서버에서 직접 처리하지 않는다 (PCI DSS Level 4 준수) |
| NFR-PAY-003-2 | 결제 관련 민감 정보는 로그에 마스킹 처리한다 |
| NFR-PAY-003-3 | 웹훅 서명 검증 실패 시 즉시 요청을 거부(HTTP 400)하고 보안 로그를 기록한다 |
| NFR-PAY-003-4 | 모든 결제 EP는 JWT 인증 필수 (웹훅 EP 제외) |
| NFR-PAY-003-5 | 간편결제 PIN은 AES-256-CBC + 고유 IV로 암호화하여 저장한다 |

### NFR-PAY-004: 성능

| ID | 요구사항 |
|----|----------|
| NFR-PAY-004-1 | 결제 요청 처리 응답 시간: 외부 PG API 호출 제외 시 500ms 이내 |
| NFR-PAY-004-2 | 동시 결제 요청 100건 처리 시 DB 트랜잭션 격리 및 데이터 정합성을 보장한다 |

### NFR-PAY-005: 감사 추적 (Audit Trail)

| ID | 요구사항 |
|----|----------|
| NFR-PAY-005-1 | 모든 결제 생성, 성공, 실패, 취소 이벤트를 `tb_order`에 상태 이력으로 기록한다 |
| NFR-PAY-005-2 | 페이백, 코인백 지급 이벤트는 별도 이력 테이블에 기록한다 |
| NFR-PAY-005-3 | Stripe 웹훅 이벤트 ID를 `PaymentLogRepository`에 기록하여 중복 처리 방지 이력을 유지한다 |

### NFR-PAY-006: Rate Limit (요청 속도 제한)

| ID | 요구사항 |
|----|----------|
| NFR-PAY-006-1 | 모든 Payment EP에 IP 기반 Rate Limit을 적용한다: 60회 / 60초 초과 시 HTTP 429를 반환한다 |
| NFR-PAY-006-2 | HTTP 429 응답 시 `Retry-After` 헤더를 포함하여 클라이언트에게 재시도 가능 시각을 안내한다 |
| NFR-PAY-006-3 | 필터 체인에서 `ratelimit`을 최우선으로 적용한다: `ratelimit` → `csrftoken` → `auth` → Controller |

---

## 5. 유스케이스 (Use Cases)

### UC-PAY-001: 사용자가 코인을 Stripe로 구매한다

| 항목 | 내용 |
|------|------|
| Actor | 로그인 사용자 (Caller) |
| 선행 조건 | 유효한 JWT 쿠키(`hc_access`) 보유 |

**기본 흐름**:

```
1. 사용자가 코인 패키지를 선택한다.
2. 시스템이 cancelOldReadyOrders()로 기존 ready 상태 주문을 정리한다.
3. 시스템이 tb_order에 status = 'ready'로 주문을 생성하고 멱등키를 기록한다.
4. 시스템이 Stripe PaymentIntent를 생성하고 client_secret을 반환한다.
5. 클라이언트가 Stripe.js로 결제를 완료한다.
6. Stripe가 payment_intent.succeeded 웹훅을 서버에 전송한다.
7. 서버가 Stripe-Signature를 검증한다.
8. 서버가 tb_order.status를 'paid'로 갱신하고 tb_coin에 코인을 원자적으로 적립한다.
9. 서버가 이메일과 AlimTalk 알림을 발송한다.
```

**대안 흐름 — 결제 실패**:
```
6a. Stripe가 payment_intent.payment_failed 웹훅을 전송한다.
6b. 서버가 tb_order.status를 'failed'로 갱신하고 실패 알림을 발송한다.
```

**대안 흐름 — 서명 검증 실패**:
```
7a. HTTP 400 반환 및 보안 로그 기록.
```

---

### UC-PAY-002: 사용자가 간편결제로 코인을 구매한다

| 항목 | 내용 |
|------|------|
| Actor | 로그인 사용자 (Caller, 카드 등록 완료) |
| 선행 조건 | `tb_simplepay`에 카드 등록 완료 |

**기본 흐름**:

```
1. 사용자가 코인 패키지를 선택하고 간편결제를 선택한다.
2. 사용자가 간편결제 PIN을 입력한다.
3. 시스템이 AES-256-CBC 복호화로 PIN을 검증한다.
4. 시스템이 NiceAutopay 빌링키로 결제를 실행한다.
5. 결제 성공 시 tb_order를 'paid'로 갱신하고 코인을 적립한다.
```

**대안 흐름 — PIN 불일치**: HTTP 401 UNAUTHORIZED 에러를 반환한다.

**대안 흐름 — NiceAutopay 실패**: 최대 3회 재시도 후 `tb_order`를 `'failed'`로 갱신하고 실패 알림 발송.

---

### UC-PAY-003: 자동결제가 실행된다

| 항목 | 내용 |
|------|------|
| Actor | 시스템 (Cron/Lambda 트리거) |
| 선행 조건 | `tb_autopay.status = 'active'`, 결제 예정일 도래 |

**기본 흐름**:

```
1. Cron/Lambda가 AutopayService.getPendingAutopays()를 호출한다.
2. 시스템이 사이클 기반 멱등키를 생성한다.
3. 시스템이 PG 타입에 따라 Stripe 또는 NiceAutopay로 결제를 실행한다.
4. 결제 성공 시 tb_autopay 다음 결제일을 갱신하고 tb_order에 레코드를 삽입한다.
5. 시스템이 자동결제 성공 알림을 발송한다.
```

**대안 흐름 — 결제 실패**: 재시도 횟수를 증가시키고, 3회 초과 시 `tb_autopay.status`를 `'inactive'`로 변경한다.

---

## 6. 엔드포인트 목록 (Endpoint Index)

> **SSOT 기준**: `app/Modules/Payment/Config/Routes.php` — 실제 등록된 11개 EP (kebab-case).
> 아래 목록은 Routes.php와 `api-docs/payment/payment-api.md`를 기준으로 작성되었다.

| # | 컨트롤러 | HTTP | 경로 | 설명 | 인증 | CSRF |
|---|----------|------|------|------|------|------|
| 1 | PaybackController | POST | /api/payback/get-list | 페이백 목록 조회 | 없음 | 면제 (EXCLUDED_PATHS 등재, Q-04) |
| 2 | StripeController | POST | /api/stripe/create-payment-intent | PaymentIntent 생성 | JWT | 필수 |
| 3 | StripeController | POST | /api/stripe/create-setup-intent | SetupIntent 생성 | JWT | 필수 |
| 4 | StripeController | POST | /api/stripe/webhook | 웹훅 수신 | 없음 | 면제 (서버-서버 통신) |
| 5 | PayController | POST | /api/pay/get-my-card | 등록 카드 조회 | JWT | 필수 |
| 6 | PayController | POST | /api/pay/save-simplepay | 간편결제 등록/결제 (act 분기) | JWT | 필수 |
| 7 | PayController | DELETE | /api/pay/delete-simplepay | 간편결제 카드 삭제 | JWT | 필수 |
| 8 | PayController | DELETE | /api/pay/del-auto-pay-card | 자동결제 카드 삭제 | JWT | 필수 |
| 9 | PayController | POST | /api/pay/naverpay-order | Naver Pay 주문 | JWT | 필수 |
| 10 | PayController | POST | /api/pay/tosspay-order | Toss Pay 주문 | JWT | 필수 |
| 11 | PayController | POST | /api/pay/insert-in-app-coin-order | 인앱 코인 충전 주문 | JWT | 필수 |

**미구현 EP (Open Questions)**:

| 구 SRS/SDD 경로 | 현황 | Open Question |
|----------------|------|---------------|
| `POST /api/stripe/confirmPayment` | Routes.php 미등록 | Q-03 |
| `POST /api/pay/createOrder` | Routes.php 미등록 (PG별 분리 구현됨) | Q-03 |
| `POST /api/pay/cancelOrder` | Routes.php 미등록 | Q-03 |
| `GET /api/pay/getOrderList` | Routes.php 미등록 | Q-03 |
| `GET /api/pay/getOrderDetail` | Routes.php 미등록 | Q-03 |
| `POST /api/pay/viewSimplepayPassword` | Routes.php 미등록, CSRF EXCLUDED_PATHS 등재 | Q-01 |

---

## 6.1 Open Questions

아래 미결 사항은 사용자(제품 오너/개발 담당자) 승인 후 반영한다.

| ID | 질문 | 관련 이슈 |
|----|------|-----------|
| Q-01 | `api/pay/viewSimplepayPassword`는 Routes.php 미등록이지만 CsrfTokenFilter EXCLUDED_PATHS에 존재한다. 레거시 제거 예정인가, Routes.php에 추가해야 하는가? FR-PAY-003-5 설계 의도와 구현 현황이 불일치한다. | PAYMENT-DEF-004 |
| Q-02 | STD의 `PaypalTest` 7건(TC-PAY-103~109)은 SRS/API 범위 외다. PayPal 지원 여부를 확인하여 SRS §1.2 범위 추가 또는 STD 레거시 분리가 필요하다. | PAYMENT-DEF-010 |
| Q-03 | 구 SRS/SDD에 기재된 `POST /api/stripe/confirmPayment`, `POST /api/pay/cancelOrder`, `GET /api/pay/getOrderList`, `GET /api/pay/getOrderDetail`은 Routes.php에 없다. 미구현 상태인가, 레거시 경로를 사용하는가? | PAYMENT-DEF-002 |
| Q-04 | `api/payback/get-list`는 POST 메서드이나 CSRF 면제다. POST 공개 EP에 CSRF를 적용하지 않는 것이 보안 정책상 의도적인지 확인이 필요하다. | PAYMENT-DEF-004 |

---

## 7. 타당성 검토 (Feasibility Review)

### 7.1 기술적 타당성

| 항목 | 판단 | 근거 |
|------|------|------|
| Stripe PHP SDK 사용 | 타당 | Stripe 공식 PHP SDK(stripe/stripe-php)가 성숙하고 CI4와 통합 가능 |
| 멱등키 이중 적용 | 타당 | DB UNIQUE 제약 + PG Idempotency-Key는 업계 표준 패턴 |
| PCI DSS Level 4 준수 | 타당 | PG SDK를 통한 토큰화로 카드 데이터를 서버에서 처리하지 않음 |
| AES-256-CBC PIN 암호화 | 타당 | PHP 내장 `openssl_encrypt()` 사용 가능, 고유 IV 필수 |
| AlimTalk 격리 처리 | 타당 | try-catch 격리로 알림 실패가 결제 상태에 영향 없음 |

### 7.2 운영 타당성

- Stripe Dashboard 웹훅 등록 및 `STRIPE_WEBHOOK_SECRET` 환경변수 관리가 선결 조건이다.
- Autopay Cron/Lambda 트리거의 실행 주기와 타임아웃 설정이 `tb_autopay` 결제 예정일 정밀도와 일치해야 한다.
- PG별 API 타임아웃(30초) 대비 PHP-FPM `request_terminate_timeout` 설정 확인이 필요하다.

---

## 8. 변경 기록 (Revision History)

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| v1.0 | 2026-04-15 | 최초 작성 | jypark |
| v2.0 | 2026-04-15 | IEEE 29148:2018 표준 재작성 — 섹션 구조 정비, 타당성 검토 추가, 엔드포인트 인덱스 확장 | jypark |
| v2.1 | 2026-04-21 | API ↔ IEEE 대조 리포트 반영 — [A] 이슈 8건 수정: §6 EP 인덱스 전체를 Routes.php(SSOT) 기준 kebab-case 11 EP로 재작성(DEF-001), FR-PAY-001/003/005/006/008 관련 EP 실제 구현 기준으로 교정(DEF-002), FR-PAY-001-4 멱등키 서버 자동 생성 명시(DEF-006), §2.4 CSRF 면제 목록에 `api/pay/ViewSimplepayPassword` · `api/payback/get-list` 추가(DEF-004), NFR-PAY-006 Rate Limit 신설(DEF-007), §6.1 Open Questions(Q-01~Q-04) 신설 | jypark |
