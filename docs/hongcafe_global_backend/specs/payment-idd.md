---
문서명: Payment — Interface Design Document
문서 ID: payment-idd
버전: v2.1
적용 표준: MIL-STD-498 (Interface Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Payment Module (HongCafe Global Backend)
관련 문서: payment-sdd.md, payment-srs.md
---

# Payment — Interface Design Document

> version: 2.1 | standard: MIL-STD-498 IDD | lastUpdated: 2026-04-21 | module: Payment

---

## 1. Scope (범위)

### 1.1 Identification (식별)

본 문서는 HongCafe Global Backend Payment 모듈의 인터페이스 설계를 MIL-STD-498 Interface Design Description (IDD) 표준에 따라 명세한다.

| 항목 | 내용 |
|------|------|
| 문서 ID | payment-idd |
| 대상 시스템 | Payment Module — HongCafe Global Backend |
| 기반 SDD | `payment-sdd.md` v2.0 |
| 기반 SRS | `payment-srs.md` v2.0 |
| 인터페이스 총수 | 내부 4개 / 외부 5개 |
| EP 총수 | 11개 (PayController 7 + StripeController 3 + PaybackController 1) — Routes.php 기준 |

### 1.2 System Overview (시스템 개요)

Payment 모듈은 HongCafe Global Backend Modular Monolith 아키텍처 내에서 결제 생애주기 전반을 담당한다. 코인 충전, 간편결제(Simplepay), 페이백(Payback), 코인백(CoinBack), 자동결제(Autopay)를 처리하며, Stripe, NaverPay, TossPay, NiceAutopay 외부 PG 및 Kakao AlimTalk 알림 서비스와 연동한다. 모든 결제는 멱등키(Idempotency Key) 기반으로 중복 처리를 방지한다.

### 1.3 Document Overview (문서 개요)

본 IDD는 MIL-STD-498 §DI-IPSC-81436 기준에 따라 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 기술한다.

| 섹션 | 내용 |
|------|------|
| §2 | 참조 문서 |
| §3 | 내부 인터페이스 4개 (IF-INT-001~004) — PHP 시그니처 포함 |
| §4 | 외부 인터페이스 5개 (IF-EXT-001~005) — 프로토콜/인증/타임아웃/재시도 명세 |
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
| payment-srs.md v2.0 | `docs/specs/payment-srs.md` |
| payment-sdd.md v2.0 | `docs/specs/payment-sdd.md` |
| Stripe API Reference | https://stripe.com/docs/api |
| Naver Pay Partner API v2.2 | https://developer.pay.naver.com/docs/v2/payments |
| Toss Payments API v1 | https://developers.tosspayments.com/reference |
| Kakao AlimTalk API | https://developers.kakao.com/docs/latest/ko/message/message-template |
| RFC 7231 — HTTP/1.1 Semantics and Content | IETF |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| PCI DSS v4.0 | https://www.pcisecuritystandards.org/ |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |

---

## 3. Internal Interfaces (내부 인터페이스)

MIL-STD-498 IDD §3 — 각 내부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-INT-001: PaymentServiceInterface

#### 3.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | PaymentServiceInterface |
| 파일 경로 | `app/Modules/Payment/Interfaces/PaymentServiceInterface.php` |
| 제공 컴포넌트 | `PaymentService` |
| 소비 컴포넌트 | `PayController`, `StripeController`, `PaybackController` |
| 메서드 수 | 14개 |

#### 3.1.2 Data Elements (데이터 요소)

**주요 메서드 입출력:**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `createOrder(array $params)` | `['ac_id', 'product_id', 'pg_type', 'idempotency_key']` | `OrderEntity` | 주문 생성, `tb_order` `ready` 상태 삽입 |
| `cancelOldReadyOrders(int $acId)` | `int $acId` | `void` | 기존 `ready` 상태 주문 일괄 취소 |
| `chargeComplete(int $orderId, string $pgResponse)` | `orderId`, PG 응답 JSON 원문 | `void` | `paid` 상태 갱신 + `tb_coin` 적립 |
| `cancelOrder(int $orderId)` | `int $orderId` | `void` | `cancelled` 상태 갱신 |
| `applyCoupon(int $orderId, string $couponCode)` | `orderId`, `couponCode` | `void` | 쿠폰 검증 + 주문 적용 |
| `getOrderList(int $acId, int $page)` | `acId`, `page` | `array{data: OrderEntity[], meta: array}` | 페이지네이션 주문 목록 |
| `getOrderDetail(int $orderId)` | `int $orderId` | `OrderEntity` | 주문 상세 조회 |
| `generateIdempotencyKey(int $acId, int $productId)` | `acId`, `productId` | `string` | 멱등키 생성 |
| `getPaybackList(int $acId, int $page)` | `acId`, `page` | `array{data: array[], meta: array}` | 페이백 목록 |
| `requestPayback(int $orderId)` | `int $orderId` | `void` | 페이백 신청 (멱등키 중복 방지) |
| `grantCoinBack(int $orderId)` | `int $orderId` | `void` | 코인백 지급 + `tb_coin` 기록 |
| `updateOrderStatus(int $orderId, string $status)` | `orderId`, `status` | `void` | 내부용 상태 직접 갱신 |
| `handlePaymentFailure(int $orderId, string $reason)` | `orderId`, `reason` | `void` | `failed` 상태 갱신 |
| `processRefund(int $orderId, int $amount)` | `orderId`, `amount` | `void` | PG 환불 후 `cancelled` 갱신 |

**OrderEntity 구조:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `orderId` | int | 주문 ID (PK) |
| `acId` | int | 사용자 ID |
| `productId` | int | 상품 ID |
| `pgType` | string | PG 타입 (`stripe`, `naverpay`, `tosspay`, `niceautopay`) |
| `status` | string | 주문 상태 (`ready`, `paid`, `failed`, `cancelled`) |
| `amount` | int | 결제 금액 |
| `idempotencyKey` | string | 멱등키 |
| `pgResponse` | string\|null | PG 응답 JSON 원문 |
| `createdAt` | DateTimeImmutable | 생성 시각 (UTC) |

#### 3.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Payment/Config/Services.php` |
| 트랜잭션 | `chargeComplete()`, `processRefund()` — DB 트랜잭션 필수. 비즈니스 데이터 + `global_sync_pub_log` Outbox 동시 커밋 |

#### 3.1.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 | HTTP 응답 |
|---------|---------|---------|
| 중복 멱등키 | DB unique 제약 위반 → `CONFLICT` | 409 |
| 주문 미존재 | `null` 반환 → Controller에서 `NOT_FOUND` | 404 |
| PG 환불 실패 | 예외 전파 → Controller에서 `INTERNAL` | 500 |
| 이미 취소된 주문 | 비즈니스 예외 → `CONFLICT` | 409 |

#### 3.1.5 Data Flow (데이터 흐름)

```
PayController::createOrder()
  └─ PaymentService::cancelOldReadyOrders(acId)
  └─ PaymentService::generateIdempotencyKey(acId, productId)
  └─ PaymentService::createOrder(['ac_id', 'product_id', 'pg_type', 'idempotency_key'])
        ├─ PaymentRepository::insert(orderData)
        └─ OrderEntity 반환

StripeController::webhookHandler()
  └─ PaymentService::chargeComplete(orderId, pgResponse)
        ├─ PaymentRepository::updateStatus(orderId, 'paid')
        ├─ CoinRepository::credit(acId, coinAmount)
        └─ global_sync_pub_log INSERT (Outbox)
```

**PHP 시그니처:**

```php
interface PaymentServiceInterface
{
    public function createOrder(array $params): OrderEntity;
    public function cancelOldReadyOrders(int $acId): void;
    public function chargeComplete(int $orderId, string $pgResponse): void;
    public function cancelOrder(int $orderId): void;
    public function applyCoupon(int $orderId, string $couponCode): void;
    public function getOrderList(int $acId, int $page): array;
    public function getOrderDetail(int $orderId): OrderEntity;
    public function generateIdempotencyKey(int $acId, int $productId): string;
    public function getPaybackList(int $acId, int $page): array;
    public function requestPayback(int $orderId): void;
    public function grantCoinBack(int $orderId): void;
    public function updateOrderStatus(int $orderId, string $status): void;
    public function handlePaymentFailure(int $orderId, string $reason): void;
    public function processRefund(int $orderId, int $amount): void;
}
```

---

### IF-INT-002: AutopayServiceInterface

#### 3.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | AutopayServiceInterface |
| 파일 경로 | `app/Modules/Payment/Interfaces/AutopayServiceInterface.php` |
| 제공 컴포넌트 | `AutopayService` |
| 소비 컴포넌트 | Lambda Cron (외부 트리거), `PayController` |
| 메서드 수 | 7개 |

#### 3.2.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `getPendingAutopays()` | — | `array[]` | 결제 예정일 도래한 활성 자동결제 목록 (`tb_autopay` 레코드 배열) |
| `executeAutopay(int $autopayId)` | `int $autopayId` | `void` | PG 타입에 따라 Stripe 또는 NiceAutopay로 분기 실행 |
| `chargeViaStripe(int $autopayId)` | `int $autopayId` | `void` | Stripe Charge API 호출하여 자동결제 실행 |
| `chargeViaNiceAutopay(int $autopayId)` | `int $autopayId` | `void` | NiceAutopay 빌링키로 자동결제 실행 |
| `handleFailure(int $autopayId, string $reason)` | `autopayId`, `reason` | `void` | 실패 기록 + 재시도 횟수 증가 |
| `deactivateAutopay(int $autopayId)` | `int $autopayId` | `void` | 최대 재시도 초과 시 비활성화 |
| `generateIdempotencyKey(int $autopayId, string $cycle)` | `autopayId`, `cycle` | `string` | 결제 사이클 기반 멱등키 생성 (예: `'2026-04'`) |

**`tb_autopay` 주요 필드:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `autopay_id` | int | 자동결제 ID (PK) |
| `ac_id` | int | 사용자 ID |
| `pg_type` | string | PG 타입 (`stripe`, `niceautopay`) |
| `billing_key` | string | 빌링키 (NiceAutopay) 또는 Customer ID (Stripe) |
| `next_charge_date` | date | 다음 결제 예정일 |
| `retry_count` | int | 재시도 횟수 |
| `is_active` | tinyint | 활성 여부 |

#### 3.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| 호출 트리거 | Lambda Cron (정기 실행) 또는 `PayController` (수동 실행) |
| 멱등성 | `generateIdempotencyKey(autopayId, cycle)`로 동일 사이클 중복 실행 방지 |

#### 3.2.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| Stripe 결제 실패 | `handleFailure()` 호출 → 재시도 횟수 증가 |
| NiceAutopay 결제 실패 | `handleFailure()` 호출 → 재시도 횟수 증가 |
| 최대 재시도(3회) 초과 | `deactivateAutopay()` → `is_active = 0` |
| 중복 멱등키 | DB unique 제약으로 자동 차단 |

#### 3.2.5 Data Flow (데이터 흐름)

```
Lambda Cron (매일 실행)
  └─ AutopayService::getPendingAutopays()
        └─ AutopayRepository::findPending() → tb_autopay WHERE next_charge_date <= NOW()
  └─ (각 autopayId에 대해)
        AutopayService::executeAutopay(autopayId)
          ├─ [pg_type = 'stripe']      → chargeViaStripe(autopayId)
          │       └─ StripePaymentService::createCharge(customerId, amount, idempotencyKey)
          └─ [pg_type = 'niceautopay'] → chargeViaNiceAutopay(autopayId)
                  └─ NiceAutopay API 호출 (IF-EXT-004)
```

**PHP 시그니처:**

```php
interface AutopayServiceInterface
{
    public function getPendingAutopays(): array;
    public function executeAutopay(int $autopayId): void;
    public function chargeViaStripe(int $autopayId): void;
    public function chargeViaNiceAutopay(int $autopayId): void;
    public function handleFailure(int $autopayId, string $reason): void;
    public function deactivateAutopay(int $autopayId): void;
    public function generateIdempotencyKey(int $autopayId, string $cycle): string;
}
```

---

### IF-INT-003: StripePaymentServiceInterface

#### 3.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-003 |
| 인터페이스명 | StripePaymentServiceInterface |
| 파일 경로 | `app/Modules/Payment/Interfaces/StripePaymentServiceInterface.php` |
| 제공 컴포넌트 | `StripePaymentService` (Stripe PHP SDK 래퍼) |
| 소비 컴포넌트 | `PayController`, `StripeController`, `AutopayService` |
| 메서드 수 | 8개 |

#### 3.3.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `createPaymentIntent(int $amount, string $currency, string $idempotencyKey)` | 금액, ISO 4217 통화, 멱등키 | `object Stripe\PaymentIntent` | PaymentIntent 생성 |
| `confirmPaymentIntent(string $paymentIntentId)` | PaymentIntent ID | `object Stripe\PaymentIntent` | PaymentIntent 확정 |
| `createCharge(string $customerId, int $amount, string $idempotencyKey)` | Customer ID, 금액, 멱등키 | `object Stripe\Charge` | Charge 생성 (자동결제) |
| `refundCharge(string $chargeId, int $amount)` | Charge ID, 환불 금액 (0=전액) | `object Stripe\Refund` | Charge 환불 |
| `constructWebhookEvent(string $payload, string $sigHeader)` | 웹훅 페이로드, `Stripe-Signature` 헤더 | `object Stripe\Event` | 웹훅 이벤트 검증 + 파싱. 서명 불일치 시 예외 발생 |
| `cancelPaymentIntent(string $paymentIntentId)` | PaymentIntent ID | `object Stripe\PaymentIntent` | PaymentIntent 취소 |
| `retrievePaymentIntent(string $paymentIntentId)` | PaymentIntent ID | `object Stripe\PaymentIntent` | PaymentIntent 조회 |
| `createCustomer(string $email, string $name)` | 이메일, 이름 | `object Stripe\Customer` | Stripe Customer 생성 |

#### 3.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process). 내부에서 Stripe PHP SDK를 통해 Stripe REST API 호출 |
| SDK | `stripe/stripe-php` (Composer) |
| 인증 | `STRIPE_SECRET_KEY` 환경변수 (Stripe Secret Key) |
| 멱등키 | 모든 POST 요청에 `Idempotency-Key` 헤더 포함 |
| 타임아웃 | Stripe SDK 기본 30초 |
| 재시도 | Stripe SDK 내장 Exponential Backoff (최대 3회) |

#### 3.3.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 | HTTP 응답 |
|---------|---------|---------|
| `Stripe\Exception\CardException` | 카드 거부. Controller에서 `PAYMENT_DECLINED` | 400 |
| `Stripe\Exception\InvalidRequestException` | 잘못된 요청. Controller에서 `INVALID_INPUT` | 400 |
| `Stripe\Exception\AuthenticationException` | API 키 오류. ERROR 로그 + `INTERNAL` | 500 |
| `Stripe\Exception\ApiConnectionException` | 연결 실패. ERROR 로그 + `INTERNAL` | 500 |
| `Stripe\Exception\SignatureVerificationException` | 웹훅 서명 불일치. 400 반환 | 400 |

#### 3.3.5 Data Flow (데이터 흐름)

```
PayController::chargeStripe()
  └─ StripePaymentService::createPaymentIntent(amount, currency, idempotencyKey)
        └─ Stripe PHP SDK → POST https://api.stripe.com/v1/payment_intents
              └─ [성공] Stripe\PaymentIntent { id, status, ... }
              └─ [실패] Stripe\Exception 전파

StripeController::webhookHandler()
  └─ StripePaymentService::constructWebhookEvent(payload, sigHeader)
        └─ Stripe PHP SDK 서명 검증 (HMAC-SHA256, STRIPE_WEBHOOK_SECRET)
              └─ [성공] Stripe\Event { type, data.object, ... }
              └─ [실패] SignatureVerificationException → HTTP 400
```

**PHP 시그니처:**

```php
interface StripePaymentServiceInterface
{
    public function createPaymentIntent(int $amount, string $currency, string $idempotencyKey): object;
    public function confirmPaymentIntent(string $paymentIntentId): object;
    public function createCharge(string $customerId, int $amount, string $idempotencyKey): object;
    public function refundCharge(string $chargeId, int $amount): object;
    public function constructWebhookEvent(string $payload, string $sigHeader): object;
    public function cancelPaymentIntent(string $paymentIntentId): object;
    public function retrievePaymentIntent(string $paymentIntentId): object;
    public function createCustomer(string $email, string $name): object;
}
```

---

### IF-INT-004: PaymentNotifierInterface

#### 3.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-004 |
| 인터페이스명 | PaymentNotifierInterface |
| 파일 경로 | `app/Modules/Payment/Interfaces/PaymentNotifierInterface.php` |
| 제공 컴포넌트 | `PaymentNotifier` |
| 소비 컴포넌트 | `StripeController`, `PayController`, `AutopayService` |
| 메서드 수 | 4개 |

#### 3.4.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `notifyPaymentSuccess(int $acId, int $orderId)` | `acId`, `orderId` | `void` | 결제 성공 알림 (이메일 + AlimTalk) |
| `notifyPaymentFailure(int $acId, int $orderId, string $reason)` | `acId`, `orderId`, PG 응답 실패 사유 | `void` | 결제 실패 알림 발송 |
| `notifyAutopaySuccess(int $acId, int $autopayId)` | `acId`, `autopayId` | `void` | 자동결제 성공 알림 |
| `notifyPointGranted(int $acId, int $point)` | `acId`, 지급 포인트/코인 수량 | `void` | 포인트(페이백/코인백) 지급 알림 |

#### 3.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process). 내부에서 AlimTalk API (IF-EXT-005) HTTP 호출 |
| 채널 | 이메일(SMTP/SES), Kakao AlimTalk |
| 발송 순서 | 이메일 → AlimTalk (순차 발송) |

#### 3.4.4 Error Handling (에러 처리)

AlimTalk 또는 이메일 발송 실패 시 에러 로그 기록. 알림 실패는 결제 처리 성공/실패에 영향 없음 (Graceful Degradation). 예외 전파 없음.

#### 3.4.5 Data Flow (데이터 흐름)

```
StripeController::webhookHandler() [payment_intent.succeeded 수신]
  └─ PaymentService::chargeComplete(orderId, pgResponse)
  └─ PaymentNotifier::notifyPaymentSuccess(acId, orderId)
        ├─ 이메일 발송 (SMTP/SES)
        └─ AlimTalk API 호출 (IF-EXT-005)
              └─ POST {ALIMTALK_API_URL} + 결제 완료 안내 템플릿
```

**PHP 시그니처:**

```php
interface PaymentNotifierInterface
{
    public function notifyPaymentSuccess(int $acId, int $orderId): void;
    public function notifyPaymentFailure(int $acId, int $orderId, string $reason): void;
    public function notifyAutopaySuccess(int $acId, int $autopayId): void;
    public function notifyPointGranted(int $acId, int $point): void;
}
```

---

## 4. External Interfaces (외부 인터페이스)

MIL-STD-498 IDD §4 — 각 외부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-EXT-001: Stripe API

#### 4.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | Stripe API |
| 대상 시스템 | Stripe, Inc. 결제 플랫폼 |
| 연동 컴포넌트 | `StripePaymentService` (IF-INT-003 구현체) |
| 환경변수 | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` |

#### 4.1.2 Data Elements (데이터 요소)

**EP-1: PaymentIntent 생성**

```
HTTP Method : POST
URL         : https://api.stripe.com/v1/payment_intents
Header      : Idempotency-Key: {idempotency_key}
```

요청 페이로드:
```json
{
    "amount": 10000,
    "currency": "usd",
    "payment_method_types": ["card"]
}
```

응답 페이로드 (HTTP 200):
```json
{
    "id": "pi_3OxABC1234567890",
    "status": "requires_payment_method",
    "amount": 10000,
    "currency": "usd",
    "client_secret": "pi_3OxABC1234567890_secret_XXXX"
}
```

**EP-2: Charge 생성 (자동결제)**

```
HTTP Method : POST
URL         : https://api.stripe.com/v1/charges
Header      : Idempotency-Key: {idempotency_key}
```

요청 페이로드:
```json
{
    "amount": 10000,
    "currency": "usd",
    "customer": "cus_XXXXXXXXXXXXXXXX"
}
```

**EP-3: Refund 생성**

```
HTTP Method : POST
URL         : https://api.stripe.com/v1/refunds
```

요청 페이로드:
```json
{
    "charge": "ch_XXXXXXXXXXXXXXXX",
    "amount": 10000
}
```

**EP-4: Customer 생성**

```
HTTP Method : POST
URL         : https://api.stripe.com/v1/customers
```

요청 페이로드:
```json
{
    "email": "user@example.com",
    "name": "홍길동"
}
```

응답 (HTTP 200):
```json
{
    "id": "cus_XXXXXXXXXXXXXXXX",
    "email": "user@example.com"
}
```

#### 4.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS (REST) |
| SDK | `stripe/stripe-php` (Composer) |
| 인증 방식 | HTTP Basic Auth (`STRIPE_SECRET_KEY:` — 콜론 포함 Base64 인코딩) |
| 멱등키 헤더 | `Idempotency-Key: {key}` — 모든 POST 요청 필수 |
| 타임아웃 | 30초 (SDK 기본값) |
| 재시도 | Exponential Backoff, 최대 3회 (SDK 내장) |

#### 4.1.4 Error Handling (에러 처리)

| HTTP 상태 | Stripe 에러 타입 | 처리 방식 |
|---------|-------------|---------|
| 402 | `CardException` | 카드 거부 — 400 `PAYMENT_DECLINED` 반환 |
| 400 | `InvalidRequestException` | 잘못된 파라미터 — 400 `INVALID_INPUT` 반환 |
| 401 | `AuthenticationException` | API 키 오류 — ERROR 로그 + 500 `INTERNAL` |
| 500/503 | `ApiConnectionException` | Stripe 서버 오류 — ERROR 로그 + 500 `INTERNAL` |
| 409 (웹훅) | 서명 불일치 | `SignatureVerificationException` → HTTP 400 반환 |

**재시도 정책**: Stripe SDK가 5xx 응답에 대해 Exponential Backoff으로 최대 3회 재시도.

#### 4.1.5 Data Flow (데이터 흐름)

```
PayController::chargeStripe()
  └─ StripePaymentService::createPaymentIntent(amount, 'usd', idempotencyKey)
        └─ Stripe PHP SDK
              └─ POST https://api.stripe.com/v1/payment_intents
                    └─ [성공] PaymentIntent { id, client_secret }
                    └─ [실패] Stripe\Exception 전파

StripeController::webhookHandler() [POST /api/stripe/webhook]
  └─ StripePaymentService::constructWebhookEvent(payload, stripe-signature)
        └─ Stripe SDK 서명 검증 (HMAC-SHA256, STRIPE_WEBHOOK_SECRET)
  └─ [payment_intent.succeeded] → PaymentService::chargeComplete()
  └─ [payment_intent.payment_failed] → PaymentService::handlePaymentFailure()
  └─ [charge.refunded] → PaymentService::cancelOrder()
```

---

### IF-EXT-002: Naver Pay API

#### 4.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-002 |
| 인터페이스명 | Naver Pay Partner API |
| 대상 시스템 | Naver Financial Corp. 간편결제 플랫폼 |
| 연동 컴포넌트 | `PayController` (NaverPay 분기 처리) |
| 환경변수 | `NAVERPAY_CHAIN_ID`, `NAVERPAY_CLIENT_SECRET` |

#### 4.2.2 Data Elements (데이터 요소)

**EP-1: 결제 준비 (Reserve)**

```
HTTP Method : POST
URL         : https://dev.apis.naver.com/naverpay-partner/naverpay/payments/v2.2/reserve
Headers     : X-NaverPay-Chain-Id: {NAVERPAY_CHAIN_ID}
              X-NaverPay-Idempotency-Key: {idempotency_key}
              Content-Type: application/json
```

요청 페이로드:
```json
{
    "merchantPayKey": "ORDER_123",
    "productName": "코인 100개",
    "totalPayAmount": 10000,
    "taxScopeAmount": 10000,
    "taxExScopeAmount": 0,
    "returnUrl": "https://prd.gl.hongcafe.com/api/pay/naverPayReturn"
}
```

응답 (HTTP 200):
```json
{
    "resultCode": "Success",
    "paymentId": "NP_PAYMENT_ID",
    "reserveId": "RESERVE_ID"
}
```

**EP-2: 결제 승인 (Approve)**

```
HTTP Method : POST
URL         : https://dev.apis.naver.com/naverpay-partner/naverpay/payments/v2.2/apply/naverpay
```

요청 페이로드:
```json
{
    "paymentId": "NP_PAYMENT_ID"
}
```

**EP-3: 결제 취소**

```
HTTP Method : POST
URL         : https://dev.apis.naver.com/naverpay-partner/naverpay/payments/v2.2/cancel
```

요청 페이로드:
```json
{
    "paymentId": "NP_PAYMENT_ID",
    "cancelAmount": 10000,
    "cancelReason": "고객 요청 취소"
}
```

#### 4.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS (REST) |
| 인증 방식 | `X-NaverPay-Chain-Id` + `X-NaverPay-Idempotency-Key` 헤더 |
| 콜백 EP | `GET /api/pay/naverPayReturn?paymentId={id}&resultCode={code}` |
| 타임아웃 | 30초 |
| 재시도 | 없음 (콜백 방식으로 PG가 재시도 관리) |

#### 4.2.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| `resultCode != 'Success'` (Reserve) | 주문 취소 → 400 `PAYMENT_DECLINED` |
| 콜백 `resultCode != 'Success'` | Approve 미호출 → 주문 `failed` 상태 갱신 |
| Approve API 오류 | ERROR 로그 + 500 `INTERNAL` |
| 취소 API 오류 | ERROR 로그. 수동 처리 대기열 등록 |

**재시도 정책**: 현재 재시도 없음. 콜백 실패 건은 운영팀 수동 처리.

#### 4.2.5 Data Flow (데이터 흐름)

```
PayController::reserveNaverPay()
  └─ NaverPay API: POST /payments/v2.2/reserve
        └─ [성공] { paymentId, reserveId } → 302 Redirect to Naver Pay 결제 페이지

GET /api/pay/naverPayReturn?paymentId={id}&resultCode=Success
  └─ NaverPay API: POST /payments/v2.2/apply/naverpay { paymentId }
  └─ PaymentService::chargeComplete(orderId, pgResponse)
```

---

### IF-EXT-003: Toss Pay API

#### 4.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-003 |
| 인터페이스명 | Toss Payments API |
| 대상 시스템 | Toss Payments Corp. 결제 플랫폼 |
| 연동 컴포넌트 | `PayController` (TossPay 분기 처리) |
| 환경변수 | `TOSS_CLIENT_KEY`, `TOSS_SECRET_KEY` |

#### 4.3.2 Data Elements (데이터 요소)

**EP-1: 결제 승인**

```
HTTP Method : POST
URL         : https://api.tosspayments.com/v1/payments/confirm
Authorization: Basic {Base64(TOSS_SECRET_KEY:)}
Content-Type: application/json
```

요청 페이로드:
```json
{
    "paymentKey": "TOSS_PAYMENT_KEY",
    "orderId": "ORDER_123",
    "amount": 10000
}
```

응답 (HTTP 200):
```json
{
    "paymentKey": "TOSS_PAYMENT_KEY",
    "orderId": "ORDER_123",
    "status": "DONE",
    "totalAmount": 10000,
    "approvedAt": "2026-04-15T10:00:00+09:00"
}
```

**EP-2: 결제 취소**

```
HTTP Method : POST
URL         : https://api.tosspayments.com/v1/payments/{paymentKey}/cancel
```

요청 페이로드:
```json
{
    "cancelReason": "고객 요청 취소",
    "cancelAmount": 10000
}
```

**EP-3: 결제 조회**

```
HTTP Method : GET
URL         : https://api.tosspayments.com/v1/payments/{paymentKey}
```

#### 4.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS (REST) |
| 인증 방식 | HTTP Basic Auth (`TOSS_SECRET_KEY:` — 콜론 포함 Base64 인코딩) |
| 기본 URL | `https://api.tosspayments.com/v1` |
| 타임아웃 | 30초 |
| 재시도 | 없음 (서버 측 재시도 불필요 — 클라이언트 SDK가 관리) |

#### 4.3.4 Error Handling (에러 처리)

| HTTP 상태 | 처리 방식 |
|---------|---------|
| 400 | 잘못된 파라미터 — 400 `INVALID_INPUT` 반환 |
| 401 | 인증 실패 — ERROR 로그 + 500 `INTERNAL` |
| 404 | 결제건 미존재 — 404 `NOT_FOUND` |
| 500 | Toss 서버 오류 — ERROR 로그 + 500 `INTERNAL` |

**재시도 정책**: 현재 재시도 없음. 5xx 오류 건은 운영팀 수동 처리.

#### 4.3.5 Data Flow (데이터 흐름)

```
PayController::confirmTossPay()
  [프론트에서 paymentKey, orderId, amount 전달]
  └─ Toss API: POST /v1/payments/confirm { paymentKey, orderId, amount }
        └─ [status = 'DONE'] → PaymentService::chargeComplete(orderId, pgResponse)
        └─ [status != 'DONE'] → PaymentService::handlePaymentFailure(orderId, reason)
```

---

### IF-EXT-004: NiceAutopay API

#### 4.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-004 |
| 인터페이스명 | NiceAutopay (NICE Payments) API |
| 대상 시스템 | NICEPay Corp. 자동결제 플랫폼 |
| 연동 컴포넌트 | `AutopayService::chargeViaNiceAutopay()` |
| 환경변수 | `NICE_MERCHANT_ID`, `NICE_MERCHANT_KEY` |

#### 4.4.2 Data Elements (데이터 요소)

**EP-1: 빌링키 자동결제 실행**

```
HTTP Method : POST
URL         : NiceAutopay 자동결제 API (환경변수로 관리)
```

요청 페이로드:
```json
{
    "merchantId": "{NICE_MERCHANT_ID}",
    "billingKey": "{billing_key}",
    "amount": 10000,
    "orderId": "AUTOPAY_2026-04_001",
    "productName": "월 정기 결제"
}
```

응답:
```json
{
    "resultCode": "0000",
    "resultMsg": "정상처리",
    "tid": "NICE_TID_XXXXXXXXXXXX",
    "amount": 10000
}
```

**보안 주의사항**: 카드번호, CVC, 유효기간은 NiceAutopay JavaScript SDK를 통해 클라이언트에서 직접 수집. 서버는 빌링키(`billing_key`)만 수신. 카드 원본 데이터는 서버에 전달되지 않음 (PCI DSS 준수).

#### 4.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS (서버-서버 REST) |
| 인증 방식 | API Key + 서명 (`NICE_MERCHANT_ID` + `NICE_MERCHANT_KEY` HMAC 서명) |
| 연동 방식 | 서버-서버 직접 호출 (클라이언트 비개입) |
| 타임아웃 | 30초 |
| 재시도 | `AutopayService::handleFailure()` + `deactivateAutopay()` (최대 3회) |

#### 4.4.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| `resultCode != '0000'` | `AutopayService::handleFailure(autopayId, reason)` |
| 연결 타임아웃 | 동일. 재시도 횟수 증가 |
| 재시도 3회 초과 | `AutopayService::deactivateAutopay(autopayId)` |
| 빌링키 만료 | 사용자 재등록 필요 — 알림 발송 후 `is_active = 0` |

#### 4.4.5 Data Flow (데이터 흐름)

```
AutopayService::chargeViaNiceAutopay(autopayId)
  └─ AutopayRepository::findById(autopayId) → billingKey, amount, acId
  └─ NiceAutopay API: POST 자동결제 { merchantId, billingKey, amount, orderId }
        └─ [resultCode = '0000'] → PaymentService::chargeComplete(orderId, pgResponse)
        └─ [resultCode != '0000'] → AutopayService::handleFailure(autopayId, resultMsg)
              └─ [retry_count >= 3] → deactivateAutopay(autopayId)
```

---

### IF-EXT-005: Kakao AlimTalk API

#### 4.5.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-005 |
| 인터페이스명 | Kakao AlimTalk API |
| 대상 시스템 | Kakao Business 메시지 API |
| 연동 컴포넌트 | `PaymentNotifier` (IF-INT-004 구현체) |
| 환경변수 | `ALIMTALK_API_KEY`, `ALIMTALK_SENDER_KEY` |

#### 4.5.2 Data Elements (데이터 요소)

**알림 템플릿 목록:**

| 이벤트 | 템플릿 코드 | 전달 변수 | 내용 |
|--------|-----------|---------|------|
| 결제 성공 | `PAY_SUCCESS` | `orderId`, `amount`, `coinAmount` | 결제 완료 안내 (금액, 코인 수량) |
| 결제 실패 | `PAY_FAILED` | `orderId`, `reason` | 결제 실패 안내 (실패 사유) |
| 자동결제 성공 | `AUTOPAY_SUCCESS` | `autopayId`, `amount` | 자동결제 완료 안내 |
| 포인트 지급 | `POINT_GRANTED` | `acId`, `point` | 페이백/코인백 지급 안내 |

**API 요청 예시 (결제 성공):**

```
HTTP Method : POST
URL         : {ALIMTALK_API_URL}/send
Headers     : X-Api-Key: {ALIMTALK_API_KEY}
              Content-Type: application/json
```

```json
{
    "senderKey": "{ALIMTALK_SENDER_KEY}",
    "templateCode": "PAY_SUCCESS",
    "to": "01012345678",
    "variables": {
        "orderId": "ORDER_123",
        "amount": "10,000원",
        "coinAmount": "100코인"
    }
}
```

응답:
```json
{
    "resultCode": "200",
    "resultMsg": "success"
}
```

#### 4.5.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS (REST) |
| 인증 방식 | `X-Api-Key: {ALIMTALK_API_KEY}` 헤더 |
| 타임아웃 | 10초 |
| 재시도 | 없음 (비필수 알림 채널) |

#### 4.5.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| HTTP 4xx/5xx | ERROR 로그 기록. 결제 처리에 영향 없음 (Graceful Degradation) |
| 연결 타임아웃 | ERROR 로그. 알림 누락 허용 (비즈니스 크리티컬 아님) |
| 수신자 번호 오류 | WARN 로그. 발송 실패 허용 |

**재시도 정책**: 재시도 없음. AlimTalk 발송 실패는 결제 트랜잭션에 영향 없음.

#### 4.5.5 Data Flow (데이터 흐름)

```
PaymentNotifier::notifyPaymentSuccess(acId, orderId)
  └─ [1] 주문 정보 조회 (orderId → amount, coinAmount)
  └─ [2] 사용자 전화번호 조회 (acId → phone)
  └─ [3] AlimTalk API: POST /send
              { senderKey, templateCode: 'PAY_SUCCESS', to: phone, variables: {...} }
        └─ [성공] 발송 완료 로그
        └─ [실패] ERROR 로그 (결제 처리 계속 진행)
```

---

## 5. Events and Signals (이벤트 계약)

MIL-STD-498 IDD §5 — Payment 모듈 이벤트 트리거, 발신 컴포넌트, 수신 시스템, 처리 내용을 명세한다.

| 이벤트 ID | 이벤트명 | 트리거 | 발신 컴포넌트 | 수신 시스템 | 처리 내용 |
|---------|--------|--------|------------|-----------|---------|
| EVT-PAY-001 | 결제 성공 알림 | `payment_intent.succeeded` Stripe 웹훅 | `StripeController` | `PaymentNotifier` | `tb_order` `paid` 갱신 + `tb_coin` 적립 + AlimTalk/이메일 발송 |
| EVT-PAY-002 | 결제 실패 알림 | `payment_intent.payment_failed` Stripe 웹훅 | `StripeController` | `PaymentNotifier` | `tb_order` `failed` 갱신 + 실패 알림 발송 |
| EVT-PAY-003 | 환불 완료 알림 | `charge.refunded` Stripe 웹훅 | `StripeController` | `PaymentNotifier` | `tb_order` `cancelled` 갱신 + 환불 알림 발송 |
| EVT-PAY-004 | NaverPay 결제 완료 | `GET /api/pay/naverPayReturn?resultCode=Success` | `PayController` | `PaymentService` | NaverPay Approve API 호출 + `chargeComplete()` |
| EVT-PAY-005 | TossPay 결제 완료 | `POST /api/pay/confirmTossPay` | `PayController` | `PaymentService` | Toss `/payments/confirm` 호출 + `chargeComplete()` |
| EVT-PAY-006 | 자동결제 실행 | Lambda Cron 스케줄 | `AutopayService` | `StripePaymentService` / NiceAutopay API | PG별 자동결제 + 성공 알림 발송 |
| EVT-PAY-007 | 페이백 지급 알림 | `POST /api/payback/request` | `PaybackController` | `PaymentNotifier` | 페이백 신청 처리 + `notifyPointGranted()` |
| EVT-PAY-008 | 코인백 지급 알림 | 결제 완료 후 자동 | `PaymentService` | `PaymentNotifier` | `grantCoinBack()` + `notifyPointGranted()` |

---

## 6. Error Handling Contract (에러 처리 계약)

MIL-STD-498 IDD §6 — Payment 모듈 전체 에러 처리 원칙 및 예외 타입을 명세한다.

### 6.1 에러 응답 표준

모든 에러는 CLAUDE.md API 응답 표준에 따라 아래 포맷을 준수한다:

```json
{
    "error": {
        "code": "PAYMENT_DECLINED",
        "message": "카드 결제가 거부되었습니다."
    }
}
```

### 6.2 에러 코드 매핑

| 에러 코드 | HTTP 상태 | 발생 조건 |
|---------|---------|---------|
| `INVALID_INPUT` | 400 | 잘못된 요청 파라미터, 멱등키 형식 오류 |
| `PAYMENT_DECLINED` | 400 | PG 카드 거부, 잔액 부족 |
| `UNAUTHORIZED` | 401 | JWT 인증 실패 |
| `FORBIDDEN` | 403 | 타인 주문 접근 시도 |
| `NOT_FOUND` | 404 | 주문/상품 미존재 |
| `CONFLICT` | 409 | 멱등키 중복, 이미 결제 완료된 주문 |
| `INTERNAL` | 500 | PG API 연결 실패, DB 오류 |

### 6.3 Stripe 웹훅 처리 규칙

- **서명 검증 성공 + 처리 성공**: HTTP 200 `{"received": true}`
- **서명 검증 실패**: HTTP 400 (Stripe가 재발송하지 않도록)
- **처리 중 예외 발생**: HTTP 200 반환 (Stripe 재시도 방지), 내부 에러 로그 기록
- **멱등성**: `event.id`를 `PaymentLogRepository`에서 조회하여 중복 처리 방지

### 6.4 알림 실패 격리 원칙

AlimTalk, 이메일 발송 실패는 결제 트랜잭션에 영향을 주지 않는다. `PaymentNotifier`의 모든 메서드는 내부 예외를 로그로 기록하고 예외를 전파하지 않는다.

---

## 7. Data Formats and Encoding (데이터 포맷 및 인코딩)

MIL-STD-498 IDD §7 — Payment 모듈의 인터페이스 데이터 포맷, DTO 정의, 인코딩 규칙을 명세한다.

### 7.1 공통 인코딩 규칙

| 항목 | 규칙 |
|------|------|
| 문자 인코딩 | UTF-8 (utf8mb4) 전 레벨 통일 |
| 날짜/시각 | ISO 8601 형식 (`YYYY-MM-DDTHH:MM:SSZ`). UTC 기준 |
| 금액 | 정수형 최소 단위 (원화: 원, 달러: 센트) |
| API 응답 키 | DB `snake_case` → API `camelCase` 변환 필수 |
| 성공 응답 | `{ "data": {...} }` (HTTP 200/201) |
| 에러 응답 | `{ "error": { "code": "...", "message": "..." } }` (HTTP 4xx/5xx) |

### 7.2 주문 생성 요청/응답

> **멱등키 생성 주체**: `idempotencyKey`는 **서버(`PaymentService.generateIdempotencyKey(acId, productId)`)가 자동 생성**한다.
> 클라이언트가 요청 본문에 멱등키를 포함할 필요 없다. 형식: `{acId}-prod{productId}-{timestamp}` (예: `1-prod10-1744704000`).

```json
// 요청: POST /api/pay/insert-in-app-coin-order  (인앱 코인 충전 — Routes.php 기준)
// Header: X-CSRF-TOKEN: {csrf_token}
// Cookie: hc_access={jwt_token}
// 주의: idempotencyKey는 클라이언트가 전달하지 않는다. 서버가 자동 생성.
{
    "productId": 10,
    "pgType": "stripe"
}

// 응답: HTTP 201
{
    "data": {
        "orderId": 1001,
        "productId": 10,
        "amount": 10000,
        "currency": "usd",
        "status": "ready",
        "idempotencyKey": "ac1-prod10-1744704000",
        "stripeClientSecret": "pi_3OxABC1234567890_secret_XXXX",
        "createdAt": "2026-04-15T10:00:00Z"
    }
}
```

### 7.3 주문 목록 응답

```json
// GET /api/pay/orderList
{
    "data": [
        {
            "orderId": 1001,
            "productId": 10,
            "pgType": "stripe",
            "status": "paid",
            "amount": 10000,
            "createdAt": "2026-04-15T10:00:00Z"
        }
    ],
    "meta": {
        "currentPage": 1,
        "perPage": 20,
        "total": 35,
        "lastPage": 2
    }
}
```

### 7.4 Stripe 웹훅 이벤트 처리 응답

```json
// 요청 (Stripe → 서버): POST /api/stripe/webhook
// Header: Stripe-Signature: t=...,v1=...
// Body: Stripe 이벤트 JSON 원문

// 성공 응답: HTTP 200
{
    "received": true
}

// 서명 검증 실패 응답: HTTP 400
{
    "error": "Invalid signature"
}
```

### 7.5 페이백 요청/응답

```json
// 요청: POST /api/payback/request
{
    "orderId": 1001
}

// 응답: HTTP 200
{
    "data": {
        "orderId": 1001,
        "paybackAmount": 500,
        "status": "processed"
    }
}
```

### 7.6 멱등키 생성 규칙

```
형식: {acId}-prod{productId}-{timestamp}
예시: 1-prod10-1744704000

자동결제 형식: autopay-{autopayId}-{cycle}
예시: autopay-5-2026-04
```

---

## 8. 타당성 검토 (Feasibility Review)

> 근거: Stripe API 공식 문서, PCI DSS v4.0, OWASP API Security Top 10 2023, MIL-STD-498

| 검토 ID | 검토 항목 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|----------|------|------|------|------------|
| FEA-PAY-001 | **멱등키(Idempotency Key) 필수 적용** | 필수 유지 | 결제/정산은 중복 처리 시 금전적 손실 직결. Stripe는 `Idempotency-Key` 헤더를 24시간 캐시 (Stripe 공식 문서). DB unique 제약으로 이중 보호. OWASP API4:2023 Business Logic 위반 방지 | 멱등키 없이 요청별 새 거래 생성 | 멱등키: 안전↑, 구현 복잡. 미적용: 구현 단순, 중복 결제 위험 |
| FEA-PAY-002 | **Stripe SDK vs 직접 HTTP 호출** | SDK 유지 | `stripe/stripe-php`는 Exponential Backoff, 타입 안전성, 웹훅 서명 검증 내장. 직접 HTTP 호출 대비 보안 코드 재구현 비용 절감. Stripe 공식 권장 방식 | 직접 cURL HTTP 호출 | SDK: 의존성 추가, 버전 관리 필요. 직접 호출: 의존성 없음, 보안 코드 자체 유지 |
| FEA-PAY-003 | **NiceAutopay 빌링키 서버 수신만 허용 (PCI DSS)** | 필수 유지 | 카드번호/CVC는 NiceAutopay JS SDK에서 직접 처리. 서버는 빌링키만 수신. PCI DSS SAQ A-EP 수준 충족. 카드번호 서버 경유 시 PCI DSS SAQ D 요건 적용 → 감사 비용 10배↑ | 카드번호 서버 경유 (PCI DSS SAQ D) | 빌링키: PCI DSS 비용 절감, 카드 정보 서버 무보관. 서버 경유: 직접 처리 가능, 감사 비용 폭증 |
| FEA-PAY-004 | **Stripe 웹훅 처리 실패 시 HTTP 200 반환** | 필수 유지 | Stripe는 HTTP 200 외 응답 수신 시 최대 72시간, 최대 36회 재시도. 처리 실패를 200으로 응답하면 재시도 방지 가능. 내부 에러는 로그 기록 + 수동 처리. OWASP API8:2023(Security Misconfiguration) 완화 | 처리 실패 시 5xx 반환 | 200 반환: 재시도 없음, 수동 처리 필요. 5xx 반환: Stripe가 재시도, 중복 처리 위험 |
| FEA-PAY-005 | **AlimTalk 발송 실패 Graceful Degradation** | 적절 | AlimTalk는 알림 채널. 발송 실패가 결제 성공/실패에 영향 없어야 함. Graceful Degradation으로 결제 신뢰성 우선. 발송 실패는 ERROR 로그로 추적 | AlimTalk 실패 시 결제 롤백 | Graceful Degradation: 결제 신뢰성↑, 알림 누락 허용. 롤백: 알림 보장, 결제 실패율↑ |

---

## 9. 변경 영향 기록 (Change Impact Log)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|----------|----------|--------|----------|
| MIL-STD-498 IDD 표준 전면 전환 (v1.0 → v2.0) | 전체 문서 구조 재편 | Scope(§1), References(§2), 인터페이스별 5-subsection(식별자/데이터/통신/에러/흐름), Events(§5), ErrorHandlingContract(§6), DataFormats(§7), Requirements Traceability(§10) 신설 | MIL-STD-498 IDD 기준 완전성 확보. 구현자 단독 참조 가능한 인터페이스 문서 완성 |
| 버전 v1.0 → v2.0 | 문서 헤더, 변경 로그 | 프론트매터 MIL-STD-498 표준 준수 형식으로 전환 | 다른 IDD(chat-idd, commerce-idd)와 표준 통일 |
| 내부 IF 4개 5-subsection 구조화 | IF-INT-001~004 전체 | 식별자/데이터요소/통신속성/에러처리/데이터흐름 5항목 완전 기술. PHP 시그니처 포함 | MIL-STD-498 DI-IPSC-81436 IDD 요건 준수 |
| 외부 IF 5개 5-subsection 구조화 | IF-EXT-001~005 (Stripe/NaverPay/TossPay/NiceAutopay/AlimTalk) | 각 PG별 프로토콜/인증/타임아웃/재시도/JSON 예시 완전 기술 | 구현자가 외부 PG 연동 시 문서 단독 참조 가능. PG별 인증 방식 차이(Basic Auth/API Key/서명) 명시 |
| Events and Signals 신설 (§5) | 신규 섹션 | 8개 이벤트 트리거-발신-수신-처리 전체 명세 | MIL-STD-498 IDD 이벤트 계약 요건 준수 |
| Error Handling Contract 신설 (§6) | 신규 섹션 | Stripe 웹훅 처리 규칙, 알림 실패 격리 원칙, 에러 코드 매핑 명시 | 웹훅 처리 정책 단일 참조 지점 제공 |
| Requirements Traceability Matrix 신설 (§10) | 신규 섹션 | SRS FR/NFR → IDD 인터페이스 매핑 14건 | MIL-STD-498 DI-IPSC-81436 추적성 요건 준수 |
| §1.1 EP 분포 교정 (v2.0 → v2.1) | IDD §1.1 Identification 테이블 | PayController 6→7, StripeController 2→3, PaybackController 3→1으로 교정 | Routes.php(SSOT) 기준 실제 구현 분포 반영 (PAYMENT-DEF-008) |
| §7.2 멱등키 생성 주체 명시 (v2.0 → v2.1) | IDD §7.2 주문 생성 요청 예시 | 멱등키 서버 자동 생성(`PaymentService.generateIdempotencyKey`) 명시. EP 경로를 실제 구현(`insert-in-app-coin-order`) 기준으로 교정 | 클라이언트-서버 간 멱등키 계약 명확화 (PAYMENT-DEF-006) |
| §10 추적성 매트릭스 FR 번호 전체 재정렬 (v2.0 → v2.1) | IDD §10 전체 | FR-PAY-001~009를 SRS v2.1 §3 실제 FR 순서(Stripe결제/웹훅/Simplepay/Autopay/NaverPay/TossPay/인앱구매/Payback/CoinBack)로 재정렬. NFR-PAY-001~006 매핑 갱신 | IDD-SRS 간 FR 번호 불일치 해소 (PAYMENT-DEF-003) |

---

## 10. Requirements Traceability Matrix (요구사항 추적성 매트릭스)

MIL-STD-498 DI-IPSC-81436 §10 — SRS FR/NFR과 IDD 인터페이스 간 추적성.

> **FR 번호 기준**: `payment-srs.md` v2.1 §3 기준으로 재정렬 (PAYMENT-DEF-003 반영).

| SRS 요구사항 ID | 요구사항명 | 연관 인터페이스 | 인터페이스 타입 |
|---------------|---------|-------------|-------------|
| FR-PAY-001 | Stripe 신용카드 결제 | IF-INT-001 (`PaymentService::createOrder`, `generateIdempotencyKey`), IF-INT-003 (`createPaymentIntent`), IF-EXT-001 (Stripe API) | 내부+외부 |
| FR-PAY-002 | Stripe 웹훅 처리 | IF-INT-003 (`constructWebhookEvent`), IF-INT-001 (`chargeComplete`) | 내부 |
| FR-PAY-003 | 간편결제 (Simplepay) | IF-INT-001 (`createOrder`), IF-EXT-004 (NiceAutopay 빌링키) | 내부+외부 |
| FR-PAY-004 | 자동결제 (Autopay) | IF-INT-002 (`AutopayService`), IF-EXT-001 (Stripe Charge), IF-EXT-004 (NiceAutopay) | 내부+외부 |
| FR-PAY-005 | Naver Pay 연동 | IF-EXT-002 (NaverPay API) | 외부 |
| FR-PAY-006 | Toss Pay 연동 | IF-EXT-003 (TossPay API) | 외부 |
| FR-PAY-007 | 인앱 구매 (코인 충전) | IF-INT-001 (`chargeComplete`, `generateIdempotencyKey`), IF-EXT-001 (Stripe) | 내부+외부 |
| FR-PAY-008 | 페이백 (Payback) | IF-INT-001 (`requestPayback`, `getPaybackList`) | 내부 |
| FR-PAY-009 | 코인백 (Coin Back) | IF-INT-001 (`grantCoinBack`), IF-INT-004 (`PaymentNotifier`) | 내부 |
| NFR-PAY-001 | 멱등키 기반 중복 결제 방지 (멱등성) | IF-INT-001 (`generateIdempotencyKey`), IF-INT-002 (`generateIdempotencyKey`) | 내부 |
| NFR-PAY-002 | PG 안정성 및 가용성 | IF-EXT-001 (Stripe 재시도), IF-EXT-002 (NaverPay), IF-EXT-003 (TossPay), IF-EXT-004 (NiceAutopay) | 외부 |
| NFR-PAY-003 | 보안 (PCI DSS, 웹훅 서명) | IF-INT-003 (`constructWebhookEvent`), IF-EXT-004 (NiceAutopay 빌링키만 수신) | 내부+외부 |
| NFR-PAY-004 | 성능 | IF-INT-001 (트랜잭션 처리), IF-EXT-001~004 (타임아웃 30초) | 내부+외부 |
| NFR-PAY-005 | 감사 추적 (Audit Trail) | IF-INT-001 (`chargeComplete` DB 트랜잭션 + Outbox), IF-INT-004 (알림 로그) | 내부 |
| NFR-PAY-006 | Rate Limit (요청 속도 제한) | 필터 체인 `ratelimit` → `csrftoken` → `auth` → Controller | 내부 인프라 |

---

## 11. Document History (변경 로그)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | 1.0.0 | 최초 작성 (내부 IF 4개, 외부 IF 5개, 웹훅 계약) | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 IDD 표준 전면 전환. Scope, References, 인터페이스별 5-subsection 구조화(IF-INT 4개/IF-EXT 5개), Events(8건), ErrorHandlingContract, DataFormats(7종 JSON 예시), Feasibility Review(5건), Requirements Traceability Matrix(14건) 신설 | jypark |
| 2026-04-21 | 2.1.0 | API ↔ IEEE 대조 리포트 반영 — §1.1 EP 분포 교정(PayController 7 + StripeController 3 + PaybackController 1, DEF-008), §7.2 멱등키 서버 자동 생성 명시 + EP 경로 실제 기준으로 수정(DEF-006), §10 추적성 매트릭스 FR-PAY-001~009 전체를 SRS v2.1 §3 기준으로 재정렬 + NFR-PAY-001~006 반영(DEF-003) | jypark |
