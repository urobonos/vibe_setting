---
문서명: Payment — Software Design Document
문서ID: SDD-PAY-001
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
적용 표준: IEEE 1016:2009
대상 시스템: HongCafe Global Backend — Payment Module
관련 문서:
  - payment-srs.md (SRS-PAY-001)
  - payment-idd.md (IDD-PAY-001)
  - docs/api-specification.md
---

# Payment — Software Design Document

> IEEE 1016:2009 준수 | version: 2.1 | lastUpdated: 2026-04-21 | module: Payment

---

## 1. 설계 개요 (Design Overview)

### 1.1 목적 (Purpose)

본 문서는 HongCafe Global Backend Payment 모듈의 소프트웨어 설계를 IEEE 1016:2009(8개 설계 뷰포인트) 표준에 따라 명세한다. 컴포넌트 구조, 클래스 설계, DB 스키마, 시퀀스 다이어그램, 아키텍처 결정 기록(ADR)을 포함한다.

### 1.2 설계 범위

| 항목 | 내용 |
|------|------|
| 모듈(BC) | Payment |
| 아키텍처 패턴 | Modular Monolith — Layered (Controller → Service → Repository → Model) |
| 기반 SRS | `payment-srs.md` (SRS-PAY-001) v2.0 |
| 컨트롤러 수 | 3개 (PayController, StripeController, PaybackController) |
| 서비스 수 | 4개 (PaymentService, AutopayService, StripePaymentService, PaymentNotifier) |
| Repository 수 | 7개 |
| 외부 PG | Stripe, NaverPay, TossPay, NiceAutopay |
| 알림 채널 | Email, Kakao AlimTalk |

---

## 2. 뷰포인트 1 — 컨텍스트 (Context Viewpoint)

Payment 모듈은 `app/Modules/Payment/` 경로에 위치한 Modular Monolith 구조를 따른다. 외부 PG(Stripe, NiceAutopay, Naver Pay, Toss Pay)와 내부 알림 시스템(AlimTalk, 이메일)을 연동한다.

```
app/Modules/Payment/
├── Config/
│   ├── Routes.php
│   └── Services.php
├── Controllers/
│   ├── PaybackController.php
│   ├── PayController.php
│   └── StripeController.php
├── Services/
│   ├── PaymentService.php
│   ├── AutopayService.php
│   ├── StripePaymentService.php
│   └── PaymentNotifier.php
├── Repositories/
│   ├── OrderRepository.php
│   ├── ProductRepository.php
│   ├── CoinRepository.php
│   ├── SimplepayRepository.php
│   ├── AutopayRepository.php
│   ├── PaybackRepository.php
│   └── PaymentLogRepository.php
├── Models/
│   ├── OrderModel.php
│   ├── ProductModel.php
│   ├── CoinModel.php
│   ├── SimplepayModel.php
│   └── AutopayModel.php
├── Entities/
│   ├── OrderEntity.php
│   └── CoinEntity.php
└── Interfaces/
    ├── PaymentServiceInterface.php
    ├── AutopayServiceInterface.php
    ├── StripePaymentServiceInterface.php
    └── PaymentNotifierInterface.php
```

---

## 3. 뷰포인트 2 — 컴포지션 (Composition Viewpoint)

> **SSOT 기준**: `app/Modules/Payment/Config/Routes.php` — 아래 메서드 테이블은 실제 등록 EP(kebab-case) 기준으로 작성되었다.

### 3.1 PayController

**책임**: 카드 조회, 간편결제 등록/결제, 간편결제 삭제, 자동결제 삭제, PG별 주문 생성.

| 메서드 | HTTP | 경로 | 설명 |
|--------|------|------|------|
| `getMyCard()` | POST | /api/pay/get-my-card | 등록 카드 조회 |
| `saveSimplepay()` | POST | /api/pay/save-simplepay | 간편결제 등록/결제 (act 파라미터 분기) |
| `deleteSimplepay()` | DELETE | /api/pay/delete-simplepay | 간편결제 카드 삭제 |
| `delAutoPayCard()` | DELETE | /api/pay/del-auto-pay-card | 자동결제 카드 삭제 |
| `naverpayorder()` | POST | /api/pay/naverpay-order | Naver Pay 주문 |
| `tosspayorder()` | POST | /api/pay/tosspay-order | Toss Pay 주문 |
| `insertInAppCoinOrder()` | POST | /api/pay/insert-in-app-coin-order | 인앱 코인 충전 주문 |

**의존성**: `PaymentService`, `AutopayService`

**필터 체인**: `ratelimit` → `csrftoken` → `auth` → Controller

**미구현 / Open Question**:

| 구 설계 메서드 | 구 경로 | 현황 |
|----------------|---------|------|
| `createOrder()` | /api/pay/createOrder | 미구현 (PG별 별도 EP로 분리) — Q-03 |
| `viewSimplepayPassword()` | /api/pay/viewSimplepayPassword | 레거시 추정, Routes.php 미등록 — Q-01 |
| `simplepayCharge()` | /api/pay/simplepayCharge | 미구현 (`save-simplepay` act 분기로 통합) — Q-03 |
| `cancelOrder()` | /api/pay/cancelOrder | 미구현 — Q-03 |
| `getOrderList()` | /api/pay/getOrderList | 미구현 — Q-03 |
| `getOrderDetail()` | /api/pay/getOrderDetail | 미구현 — Q-03 |

### 3.2 StripeController

**책임**: Stripe PaymentIntent/SetupIntent 생성, 웹훅 이벤트 처리.

| 메서드 | HTTP | 경로 | 설명 |
|--------|------|------|------|
| `createPaymentIntent()` | POST | /api/stripe/create-payment-intent | PaymentIntent 생성 |
| `createSetupIntent()` | POST | /api/stripe/create-setup-intent | SetupIntent 생성 |
| `webhook()` | POST | /api/stripe/webhook | 웹훅 수신 (인증 없음, CSRF 면제) |

**의존성**: `StripePaymentService`, `PaymentService`, `PaymentNotifier`

**미구현 / Open Question**:

| 구 설계 메서드 | 구 경로 | 현황 |
|----------------|---------|------|
| `confirmPayment()` | /api/stripe/confirmPayment | 미구현 — Q-03 |

### 3.3 PaybackController

**책임**: 페이백 목록 조회.

| 메서드 | HTTP | 경로 | 설명 |
|--------|------|------|------|
| `getList()` | POST | /api/payback/get-list | 페이백 목록 조회 (인증 없음, CSRF 면제) |

**의존성**: `PaymentService`, `PaybackRepository`

**미구현 / Open Question**:

| 구 설계 메서드 | 구 경로 | 현황 |
|----------------|---------|------|
| `getPaybackList()` | /api/payback/getPaybackList | 미구현 (`get-list`로 통합 추정) — Q-03 |
| `requestPayback()` | /api/payback/requestPayback | 미구현 — Q-03 |

---

## 4. 뷰포인트 3 — 논리 (Logical Viewpoint)

### 4.1 PaymentService

**책임**: 주문 생성, 코인 충전, 쿠폰 적용, PG 선택 라우팅, `cancelOldReadyOrders` 처리.

| 메서드 | 반환 타입 | 설명 |
|--------|-----------|------|
| `createOrder(array $params)` | `OrderEntity` | 주문 생성 및 tb_order 삽입 |
| `cancelOldReadyOrders(int $acId)` | `void` | 기존 ready 상태 주문 취소 |
| `chargeComplete(int $orderId, string $pgResponse)` | `void` | 결제 완료 처리 (상태 갱신 + 코인 적립) |
| `cancelOrder(int $orderId)` | `void` | 주문 취소 처리 |
| `applyCoupon(int $orderId, string $couponCode)` | `void` | 쿠폰 적용 |
| `getOrderList(int $acId, int $page)` | `array` | 주문 목록 조회 |
| `getOrderDetail(int $orderId)` | `OrderEntity` | 주문 상세 조회 |
| `generateIdempotencyKey(int $acId, int $productId)` | `string` | 멱등키 생성 |

**트랜잭션**: `chargeComplete()` 내에서 `tb_order` 상태 갱신과 `tb_coin` 적립을 단일 트랜잭션으로 처리한다.

### 4.2 AutopayService

**책임**: 자동결제 대상 조회, Stripe 자동결제, NiceAutopay 자동결제.

| 메서드 | 반환 타입 | 설명 |
|--------|-----------|------|
| `getPendingAutopays()` | `array` | 결제 예정 자동결제 대상 조회 |
| `executeAutopay(int $autopayId)` | `void` | 자동결제 실행 (PG 분기) |
| `chargeViaStripe(int $autopayId)` | `void` | Stripe Charge API 호출 |
| `chargeViaNiceAutopay(int $autopayId)` | `void` | NiceAutopay 자동결제 API 호출 |
| `handleFailure(int $autopayId, string $reason)` | `void` | 실패 처리 및 재시도 횟수 증가 |
| `deactivateAutopay(int $autopayId)` | `void` | 최대 재시도 초과 시 비활성화 |
| `generateIdempotencyKey(int $autopayId, string $cycle)` | `string` | 사이클 기반 멱등키 생성 |

### 4.3 StripePaymentService

**책임**: Stripe PHP SDK 래퍼. Stripe API 호출을 추상화한다.

| 메서드 | 반환 타입 | 설명 |
|--------|-----------|------|
| `createPaymentIntent(int $amount, string $currency, string $idempotencyKey)` | `object` | PaymentIntent 생성 |
| `confirmPaymentIntent(string $paymentIntentId)` | `object` | PaymentIntent 확정 |
| `createCharge(string $customerId, int $amount, string $idempotencyKey)` | `object` | Charge 생성 (Autopay용) |
| `refundCharge(string $chargeId, int $amount)` | `object` | 환불 처리 |
| `constructWebhookEvent(string $payload, string $sigHeader)` | `object` | 웹훅 이벤트 파싱 및 서명 검증 |
| `cancelPaymentIntent(string $paymentIntentId)` | `object` | PaymentIntent 취소 |
| `retrievePaymentIntent(string $paymentIntentId)` | `object` | PaymentIntent 조회 |
| `createCustomer(string $email, string $name)` | `object` | Stripe Customer 생성 |

### 4.4 PaymentNotifier

**책임**: 결제 관련 알림(이메일, AlimTalk, 포인트 지급) 발송.

| 메서드 | 반환 타입 | 설명 |
|--------|-----------|------|
| `notifyPaymentSuccess(int $acId, int $orderId)` | `void` | 결제 성공 알림 (이메일 + AlimTalk) |
| `notifyPaymentFailure(int $acId, int $orderId, string $reason)` | `void` | 결제 실패 알림 |
| `notifyAutopaySuccess(int $acId, int $autopayId)` | `void` | 자동결제 성공 알림 |
| `notifyPointGranted(int $acId, int $point)` | `void` | 포인트 지급 알림 |

---

## 5. 뷰포인트 4 — 의존성 (Dependency Viewpoint)

### 5.1 Repository 목록

| Repository | 대응 테이블 | 주요 메서드 |
|------------|------------|------------|
| `OrderRepository` | `tb_order` | `insert`, `findById`, `findByAcId`, `updateStatus`, `cancelReadyOrders` |
| `ProductRepository` | `tb_product` | `findById`, `findActiveList`, `findByCoinAmount` |
| `CoinRepository` | `tb_coin` | `findByAcId`, `incrementBalance`, `insertTransaction` |
| `SimplepayRepository` | `tb_simplepay` | `findByAcId`, `insert`, `updateBillingKey`, `delete` |
| `AutopayRepository` | `tb_autopay` | `findPending`, `updateStatus`, `updateNextPayDate`, `incrementRetryCount` |
| `PaybackRepository` | (페이백 이력 테이블) | `findByAcId`, `insert`, `findByOrderId` |
| `PaymentLogRepository` | (결제 로그 테이블) | `insert`, `findByOrderId`, `findByIdempotencyKey` |

### 5.2 외부 의존성

| 시스템 | 연동 방식 | 비고 |
|--------|----------|------|
| Stripe | PHP SDK (`stripe/stripe-php`) | PaymentIntent, Charge, Refund, Webhook |
| NaverPay | REST API (cURL) | Reserve, Approve, Cancel |
| TossPay | REST API (Basic Auth) | Confirm, Cancel |
| NiceAutopay | REST API (API Key + Sign) | BillingKey, Charge |
| Kakao AlimTalk | REST API | 결제 알림 발송 |

---

## 6. 뷰포인트 5 — 인터페이스 (Interface Viewpoint)

### 6.1 DI 등록 위치

`app/Modules/Payment/Config/Services.php`에서 바인딩. 중앙 `app/Config/Services.php`에 직접 등록 금지.

```php
// app/Modules/Payment/Config/Services.php
\Config\Services::$serviceBindings = [
    PaymentServiceInterface::class       => PaymentService::class,
    AutopayServiceInterface::class       => AutopayService::class,
    StripePaymentServiceInterface::class => StripePaymentService::class,
    PaymentNotifierInterface::class      => PaymentNotifier::class,
];
```

### 6.2 모듈 간 노출 인터페이스

다른 모듈이 결제 데이터를 필요로 하는 경우 `PaymentServiceInterface`만을 `service()` DI로 주입받는다. 직접 Repository/Model 접근은 허용하지 않는다.

---

## 7. 뷰포인트 6 — 데이터 (Data Viewpoint)

### 7.1 tb_order

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | BIGINT UNSIGNED PK AUTO_INCREMENT | 주문 ID |
| `ac_id` | BIGINT UNSIGNED NOT NULL | 사용자 ID (FK → tb_account) |
| `product_id` | INT UNSIGNED NOT NULL | 상품 ID (FK → tb_product) |
| `pg_type` | ENUM('stripe','naver','toss','nice') NOT NULL | PG 구분 |
| `pg_order_id` | VARCHAR(255) | PG 측 주문 ID |
| `idempotency_key` | VARCHAR(255) UNIQUE NOT NULL | 멱등키 |
| `amount` | INT UNSIGNED NOT NULL | 결제 금액 (원 단위) |
| `status` | ENUM('ready','paid','failed','cancelled') DEFAULT 'ready' | 주문 상태 |
| `pg_response` | JSON | PG 응답 원문 |
| `paid_at` | DATETIME | 결제 완료 시각 (UTC) |
| `created_at` | DATETIME NOT NULL | 생성 시각 (UTC) |
| `updated_at` | DATETIME NOT NULL | 수정 시각 (UTC) |

**인덱스**:
- `idx_ac_id_status` (ac_id, status) — 사용자별 상태 필터 조회
- `uk_idempotency_key` UNIQUE (idempotency_key) — 중복 삽입 방지

### 7.2 tb_product

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | INT UNSIGNED PK AUTO_INCREMENT | 상품 ID |
| `name` | VARCHAR(100) NOT NULL | 상품명 |
| `coin_amount` | INT UNSIGNED NOT NULL | 지급 코인 수 |
| `price` | INT UNSIGNED NOT NULL | 판매가 (원 단위) |
| `coin_back_amount` | INT UNSIGNED DEFAULT 0 | 코인백 지급량 |
| `payback_rate` | DECIMAL(5,2) DEFAULT 0.00 | 페이백 비율 (%) |
| `is_active` | TINYINT(1) NOT NULL DEFAULT 1 | 활성 여부 |
| `created_at` | DATETIME NOT NULL | 생성 시각 (UTC) |

### 7.3 tb_coin

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | BIGINT UNSIGNED PK AUTO_INCREMENT | 코인 트랜잭션 ID |
| `ac_id` | BIGINT UNSIGNED NOT NULL | 사용자 ID (FK → tb_account) |
| `order_id` | BIGINT UNSIGNED | 주문 ID (FK → tb_order) |
| `type` | ENUM('charge','use','refund','coinback') NOT NULL | 트랜잭션 유형 |
| `amount` | INT NOT NULL | 코인 수량 (음수: 차감) |
| `balance` | INT UNSIGNED NOT NULL | 처리 후 잔액 |
| `created_at` | DATETIME NOT NULL | 생성 시각 (UTC) |

**인덱스**: `idx_ac_id` (ac_id) — 사용자별 코인 내역 조회

### 7.4 tb_simplepay

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | INT UNSIGNED PK AUTO_INCREMENT | 간편결제 ID |
| `ac_id` | BIGINT UNSIGNED NOT NULL UNIQUE | 사용자 ID (FK → tb_account) |
| `billing_key` | VARCHAR(255) NOT NULL | NiceAutopay 빌링키 |
| `pin_encrypted` | VARCHAR(512) NOT NULL | AES-256-CBC 암호화된 PIN |
| `pin_iv` | VARCHAR(128) NOT NULL | 암호화 IV |
| `created_at` | DATETIME NOT NULL | 생성 시각 (UTC) |
| `updated_at` | DATETIME NOT NULL | 수정 시각 (UTC) |

### 7.5 tb_autopay

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | INT UNSIGNED PK AUTO_INCREMENT | 자동결제 ID |
| `ac_id` | BIGINT UNSIGNED NOT NULL | 사용자 ID (FK → tb_account) |
| `pg_type` | ENUM('stripe','nice') NOT NULL | PG 구분 |
| `status` | ENUM('active','inactive') DEFAULT 'active' | 자동결제 상태 |
| `next_pay_date` | DATE NOT NULL | 다음 결제 예정일 |
| `retry_count` | TINYINT UNSIGNED DEFAULT 0 | 재시도 횟수 |
| `product_id` | INT UNSIGNED NOT NULL | 결제 상품 ID |
| `idempotency_cycle` | VARCHAR(50) | 사이클 기반 멱등 식별자 |
| `created_at` | DATETIME NOT NULL | 생성 시각 (UTC) |
| `updated_at` | DATETIME NOT NULL | 수정 시각 (UTC) |

**인덱스**: `idx_status_next_pay_date` (status, next_pay_date) — Autopay 조회 최적화

---

## 8. 뷰포인트 7 — 행위 (Behavior Viewpoint)

### 8.1 Stripe 결제 플로우

```
Client          PayController      PaymentService     StripePaymentService    Stripe
  |                   |                  |                    |                   |
  |--createOrder()-->|                  |                    |                   |
  |                  |--cancelOldReadyOrders()-->|           |                   |
  |                  |                  |--cancelOldOrders-->DB                  |
  |                  |--generateIdempotencyKey()-->|         |                   |
  |                  |--createOrder()-->|           |        |                   |
  |                  |                  |--INSERT tb_order(ready)-->DB           |
  |                  |--createPaymentIntent()-->|   |        |                   |
  |                  |                  |--createPaymentIntent()-->|             |
  |                  |                  |           |--POST /payment_intents-->  |
  |                  |                  |           |<--{client_secret}------   |
  |<--{client_secret}|                  |           |                           |
  |--Stripe.js confirmPayment()---------|-----------|--------|--(Stripe SDK)---> |
  |                  |                  |           |        |                   |
  |                  [webhook: payment_intent.succeeded]     |                   |
  |                  |--constructWebhookEvent()-->|          |                   |
  |                  |--chargeComplete()-->|        |        |                   |
  |                  |                  |--UPDATE tb_order(paid)-->DB            |
  |                  |                  |--incrementBalance()-->tb_coin          |
  |                  |--notifyPaymentSuccess()-->PaymentNotifier                 |
```

### 8.2 자동결제 플로우

```
Cron/Lambda     AutopayService     StripePaymentService    Stripe      DB
     |                |                    |                  |          |
     |--trigger()---> |                    |                  |          |
     |                |--getPendingAutopays()-->              |          |
     |                |                                       |    --SELECT tb_autopay-->|
     |                |--generateIdempotencyKey()             |          |
     |                |--chargeViaStripe()-->  |              |          |
     |                |                |--createCharge()-->   |          |
     |                |                |       |--POST /charges-->       |
     |                |                |       |<--{charge}---           |
     |                |--UPDATE tb_autopay(next_pay_date)-->             |
     |                |--INSERT tb_order(paid)-->                        |
     |                |--notifyAutopaySuccess()-->PaymentNotifier        |
```

---

## 9. 뷰포인트 8 — 자원 (Resource Viewpoint)

### 9.1 환경변수 목록

| 변수 | 용도 |
|------|------|
| `STRIPE_SECRET_KEY` | Stripe API 인증 |
| `STRIPE_WEBHOOK_SECRET` | 웹훅 서명 검증 |
| `NAVERPAY_CHAIN_ID` | Naver Pay Chain ID |
| `NAVERPAY_CLIENT_SECRET` | Naver Pay 인증 |
| `TOSS_CLIENT_KEY` | Toss Pay 클라이언트 키 |
| `TOSS_SECRET_KEY` | Toss Pay 서버 인증 |
| `NICE_MERCHANT_ID` | NiceAutopay 가맹점 ID |
| `NICE_MERCHANT_KEY` | NiceAutopay 가맹점 키 |
| `ALIMTALK_API_KEY` | Kakao AlimTalk API 인증 |
| `ALIMTALK_SENDER_KEY` | AlimTalk 발신 채널 |

### 9.2 외부 API 타임아웃 설정

| PG | 타임아웃 | 재시도 횟수 |
|----|----------|------------|
| Stripe | 30초 | 3회 (Exponential Backoff) |
| NaverPay | 30초 | 3회 |
| TossPay | 30초 | 3회 |
| NiceAutopay | 30초 | 3회 |

---

## 10. 아키텍처 결정 기록 (Architecture Decision Records)

### ADR-PAY-001: Stripe PHP SDK 직접 사용 대신 StripePaymentService 래퍼 도입

**상태**: 채택됨

**컨텍스트**: Stripe PHP SDK를 Controller/Service에서 직접 호출할 경우 PG 교체 시 다수 파일 수정이 필요하고 단위 테스트에서 외부 API 의존성을 제거할 수 없다.

**결정**: `StripePaymentService` 래퍼 클래스를 통해서만 Stripe SDK를 호출한다.

**결과**:
- Stripe SDK 의존성을 단일 클래스에 격리하여 PG 교체 시 영향 범위를 최소화한다.
- 테스트 시 `StripePaymentServiceInterface`를 Mock으로 대체하여 외부 API 없이 단위 테스트 가능하다.
- Idempotency Key, 에러 변환, 재시도 로직을 한 곳에서 관리한다.

**기각 대안**: Controller에서 SDK 직접 호출 — 테스트 불가, PG 교체 시 다수 파일 수정 필요.

---

### ADR-PAY-002: 멱등키 DB UNIQUE 제약 + Stripe Idempotency-Key 이중 적용

**상태**: 채택됨

**컨텍스트**: 네트워크 재시도, 클라이언트 재전송 등 예외 상황에서 중복 결제가 발생할 수 있다.

**결정**: `tb_order.idempotency_key`에 UNIQUE 제약을 부여하고, Stripe API 호출 시 동일 키를 `Idempotency-Key` 헤더로 전달한다.

**결과**:
- DB 레벨 UNIQUE 제약으로 중복 주문 삽입 자체를 방지한다.
- Stripe 레벨 멱등키로 PG 측 중복 청구를 방지한다.
- 두 계층에서 모두 방어하여 네트워크 재시도 등 예외 상황을 모두 커버한다.

---

### ADR-PAY-003: 웹훅 처리 후 알림 시스템 장애 격리

**상태**: 채택됨

**컨텍스트**: AlimTalk/이메일 발송 실패 시 결제 상태 갱신이 롤백되면 안 된다.

**결정**: `PaymentNotifier`의 이메일/AlimTalk 발송 실패가 `chargeComplete()` 트랜잭션에 영향을 주지 않도록 try-catch로 격리한다.

**결과**:
- 결제 완료 처리(`tb_order` 상태 갱신, `tb_coin` 적립)는 알림 발송 성공 여부와 독립적으로 완료된다.
- 알림 실패는 로그로만 기록하고 결제 결과를 롤백하지 않는다.

---

## 11. 체크리스트

- [ ] PayController 7개 엔드포인트 Routes.php 명시적 등록 확인 (get-my-card, save-simplepay, delete-simplepay, del-auto-pay-card, naverpay-order, tosspay-order, insert-in-app-coin-order)
- [ ] StripeController 3개 엔드포인트 Routes.php 등록 확인 (create-payment-intent, create-setup-intent, webhook) 및 webhook CSRF 면제 확인
- [ ] PaybackController 1개 엔드포인트 Routes.php 등록 확인 (get-list, CSRF 면제 — Q-04)
- [ ] PaymentService.chargeComplete() 단일 트랜잭션 처리 확인
- [ ] AutopayService 멱등키 생성 로직 및 재시도 3회 확인
- [ ] StripePaymentService Idempotency-Key 헤더 전달 확인
- [ ] PaymentNotifier 알림 실패 격리(try-catch) 확인
- [ ] tb_order.idempotency_key UNIQUE 제약 스키마 반영 확인
- [ ] tb_coin 잔액 갱신 트랜잭션 안전성 확인
- [ ] 7개 Repository 인터페이스 타입 힌트 확인
- [ ] ADR-PAY-001~003 설계 결정 코드 반영 확인
- [ ] 모든 PHP 파일 `declare(strict_types=1)` 선언 확인
- [ ] `DateTimeImmutable` 사용 확인 (`date()`, `time()` 미사용)

---

## 12. 변경 기록 (Revision History)

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| v1.0 | 2026-04-15 | 최초 작성 | jypark |
| v2.0 | 2026-04-15 | IEEE 1016:2009 8개 뷰포인트 구조 재작성 — 데이터 뷰포인트 컬럼 상세화, 자원 뷰포인트 추가, ADR 형식 정비 | jypark |
| v2.1 | 2026-04-21 | API ↔ IEEE 대조 리포트 반영 — §3.1 PayController 메서드 테이블을 실제 구현 7 EP로 재작성(DEF-001, DEF-002), §3.2 StripeController 메서드 테이블을 3 EP(kebab-case)로 재작성(DEF-001, DEF-002), §3.3 PaybackController 메서드 테이블을 1 EP로 재작성(DEF-001, DEF-002), 미구현 EP "미구현 / Open Question" 표기, 체크리스트 실제 EP 수 반영 | jypark |
