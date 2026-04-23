---
문서명: Event — Software Design Document
문서 ID: event-sdd
버전: v2.0
적용 표준: IEEE 1016-2009 (Software Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Event Module (HongCafe Global Backend)
관련 문서: event-srs.md, event-idd.md
---

# Event — Software Design Document

> version: 2.0 | standard: IEEE 1016-2009 | lastUpdated: 2026-04-15 | module: Event

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 SDD(Software Design Document)는 HongCafe Global Backend Event 모듈의 소프트웨어 설계를 IEEE 1016-2009 표준에 따라 기술한다. `event-srs.md` v2.0에서 도출된 설계 결정, 모듈 분해, 데이터 구조, 인터페이스 계약, 아키텍처 근거를 포함한다.

### 1.2 Scope (범위)

본 SDD는 `app/Modules/Event/` 내 모든 컴포넌트의 설계를 다룬다: 2개 Controller, 2개 Service, 2개 Repository, 4개 Interface, 2개 Config 파일. 총 10개 엔드포인트(EventController 7EP, RouletteController 3EP)를 대상으로 한다.

### 1.3 Definitions, Acronyms, and Abbreviations (정의 및 약어)

| 용어 / Term | 정의 / Definition |
|------------|-----------------|
| SDD | Software Design Document |
| BC | Bounded Context |
| ADR | Architecture Decision Record |
| DI | Dependency Injection |
| CSPRNG | Cryptographically Secure Pseudo-Random Number Generator |
| VO | Value Object |
| GoF | Gang of Four (Design Patterns, Gamma et al., 1994) |
| DDL | Data Definition Language |
| VIP 등급 | A~E 5단계 등급 체계 (RouletteService 기준) |
| 룰렛 세그먼트 | 룰렛 회전 결과 구역 (5개 고정 세그먼트) |
| 멱등키 | Idempotency Key — 중복 요청 방지 고유 식별자 |
| GRADE_THRESHOLDS | 코인 충전 이벤트 보상 7 티어 상수 |

### 1.4 References (참조 문서)

| 문서 | 위치 / 출처 |
|------|-----------|
| IEEE 1016-2009 — IEEE Standard for Information Technology — Systems Design — Software Design Descriptions | IEEE Standards |
| event-srs.md v2.0 | `docs/specs/event-srs.md` |
| event-idd.md v2.0 | `docs/specs/event-idd.md` |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| OWASP Top 10 A07:2021 — Identification and Authentication Failures | https://owasp.org/Top10/A07_2021/ |
| GoF Design Patterns | Gamma et al., 1994 |
| PHP Manual — random_int() | https://www.php.net/manual/en/function.random-int.php |
| MySQL 8.0 Reference Manual | https://dev.mysql.com/doc/refman/8.0/en/ |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |

### 1.5 Overview (문서 구조)

본 문서는 IEEE 1016-2009에서 정의한 8개 설계 뷰포인트로 구성된다.

| 섹션 | IEEE 1016 Viewpoint | 내용 |
|------|---------------------|------|
| §2 | Context Viewpoint | 모듈 경계와 외부 시스템 관계 |
| §3 | Composition Viewpoint | 디렉토리 구조와 컴포넌트 분해 |
| §4 | Logical Viewpoint | 클래스 설계 — Controller, Service, Repository, Entity/VO |
| §5 | Dependency Viewpoint | 모듈 간 의존성과 DI 등록 |
| §6 | Information Viewpoint | DB 스키마와 데이터 흐름 |
| §7 | Patterns Viewpoint | 적용된 디자인 패턴과 ADR |
| §8 | Interface Viewpoint | 컴포넌트 인터페이스 계약 |
| §9 | Interaction Viewpoint | 주요 및 에러 흐름 시퀀스 다이어그램 |
| §10 | Design Overlay | 보안 / 에러 처리 / 로깅 / 트랜잭션 |
| §11 | Traceability Matrix | SRS 요구사항 ↔ 설계 요소 매핑 |
| §12 | Feasibility Review | 설계 결정 타당성 검토 |
| §13 | Change Impact Log | 변경 영향 기록 |
| §14 | Document History | 개정 이력 |

---

## 2. Context Viewpoint (컨텍스트 뷰포인트)

### 2.1 Module Boundaries (모듈 경계)

Event 모듈은 HongCafe Global Backend Modular Monolith 내 독립 Bounded Context이다. 인접 모듈과의 통신은 선언된 인터페이스를 통해서만 이루어진다(직접 크로스 모듈 Repository 접근 금지).

```text
+---------------------------------------------------------------+
|                   HongCafe Global Backend                     |
|  +----------------------------------------------------------+ |
|  |                   Event Module                           | |
|  |  EventController (7EP) / RouletteController (3EP)        | |
|  |  +---------------------+  +-------------------------+   | |
|  |  | EventRewardService  |  | RouletteService         |   | |
|  |  | (563 lines)         |  | (254 lines)             |   | |
|  |  +----------+----------+  +----------+--------------+   | |
|  |             |                        |                   | |
|  |  +----------v------------------------v--------------+   | |
|  |  |  EventRepository (10)  |  RouletteRepository (4) |   | |
|  |  +---------------------------+---------------------+    | |
|  +---------------------------+--------------------------+   | |
|                              | Aurora MySQL              |   |
|  +--------------------+  +--v--------------------------+    | |
|  | Shared/Coin Module |  | Shared/Coupon Module        |    | |
|  | (CoinService DI)   |  | (CouponService DI)          |    | |
|  +--------------------+  +-----------------------------+    | |
+----------+----------------------------------------------------+
           | REST HTTPS
   +-------v-------+
   |  Next.js 16   |
   |  Frontend     |
   +---------------+
```

### 2.2 External System Relationships (외부 시스템 관계)

| 외부 시스템 | 프로토콜 | 목적 | 장애 모드 |
|-----------|---------|------|---------|
| Aurora MySQL (via RDS Proxy) | TCP/MySQL | 이벤트/참여 이력/룰렛 이력 저장 | DB Exception 전파 → 500 `INTERNAL` |
| Shared/CoinServiceInterface | In-Process DI | 코인 보상 지급 | 트랜잭션 롤백 |
| Shared/CouponServiceInterface | In-Process DI | 쿠폰 보상 지급 | 트랜잭션 롤백 |

> Event 모듈은 SendBird, FCM, S3 등 외부 SaaS에 직접 의존하지 않는다.

---

## 3. Composition Viewpoint (구성 뷰포인트)

### 3.1 Directory Structure (디렉토리 구조)

```text
app/Modules/Event/
├── Controllers/
│   ├── EventController.php           332 lines — 7 endpoints
│   └── RouletteController.php         65 lines — 3 endpoints
├── Services/
│   ├── EventRewardService.php         563 lines — 7 public methods, 7 GRADE_THRESHOLDS tiers
│   └── RouletteService.php            254 lines — VIP A-E 5 segments
├── Repositories/
│   ├── EventRepository.php            10 methods
│   └── RouletteRepository.php          4 methods
├── Interfaces/
│   ├── EventRewardServiceInterface.php
│   ├── RouletteServiceInterface.php
│   ├── EventRepositoryInterface.php
│   └── RouletteRepositoryInterface.php
├── Entities/                          (마이그레이션 예정)
├── ValueObjects/                      (마이그레이션 예정)
└── Config/
    ├── Routes.php                     10 routes
    └── Services.php                   4 DI bindings
```

### 3.2 Endpoint Distribution (엔드포인트 분포)

| Controller | EP 수 | 인증 | 역할 |
|-----------|------|------|------|
| `EventController` | 7 | JWT (전체) | 이벤트 목록, 키워드/쿠폰/출석/충전 이벤트 참여, 갱신 쿠폰, 이력 |
| `RouletteController` | 3 | JWT (전체) | 룰렛 스핀, 이력 조회, 정보 조회 |

---

## 4. Logical Viewpoint (논리 뷰포인트)

### 4.1 Controller Layer (컨트롤러 계층)

모든 Controller는 `BaseController`를 상속하며, JWT 검증에 `checkNeedLogin(true)`를 사용한다.

#### 4.1.1 EventController

| 메서드 | HTTP | 경로 | 인증 | CSRF | 설명 |
|--------|------|------|------|------|------|
| `getEventList()` | GET | `/api/events` | JWT | 면제 | 활성 이벤트 목록 반환 |
| `participateKeyword()` | POST | `/api/events/keyword` | JWT | 필수 | 키워드 이벤트 참여 |
| `participateCoupon()` | POST | `/api/events/coupon` | JWT | 필수 | 쿠폰 이벤트 참여 |
| `participateAttendance()` | POST | `/api/events/attendance` | JWT | 필수 | 출석 이벤트 처리 |
| `participateChargeEvent()` | POST | `/api/events/charge` | JWT | 필수 | 코인 충전 이벤트 처리 |
| `issueRenewalCoupon()` | POST | `/api/events/renewal-coupon` | JWT | 필수 | 갱신 쿠폰 발급 |
| `getEventHistory()` | GET | `/api/events/history` | JWT | 면제 | 이벤트 참여 이력 조회 |

**설계 원칙**: Controller는 입력 검증(validation)과 응답 포맷 변환만 담당. 비즈니스 로직은 `EventRewardService`에 위임.

**입력 검증 예시:**

```php
// participateKeyword() 입력 검증
$rules = [
    'eventId' => 'required|integer|greater_than[0]',
    'keyword'  => 'required|string|min_length[1]|max_length[100]',
];

// participateCoupon() 입력 검증
$rules = [
    'eventId'    => 'required|integer|greater_than[0]',
    'couponCode' => 'required|string|min_length[6]|max_length[50]',
];

// participateChargeEvent() 입력 검증
$rules = [
    'eventId'        => 'required|integer|greater_than[0]',
    'chargeAmount'   => 'required|integer|greater_than[0]',
    'idempotencyKey' => 'required|string|min_length[16]|max_length[128]',
];
```

#### 4.1.2 RouletteController

| 메서드 | HTTP | 경로 | 인증 | CSRF | 설명 |
|--------|------|------|------|------|------|
| `spin()` | POST | `/api/events/roulette/spin` | JWT | 필수 | 룰렛 스핀 실행 |
| `getRouletteHistory()` | GET | `/api/events/roulette/history` | JWT | 면제 | 룰렛 당첨 이력 조회 |
| `getRouletteInfo()` | GET | `/api/events/roulette/info` | JWT | 면제 | 룰렛 세그먼트/확률 정보 조회 |

**설계 원칙**: RouletteController는 경량 Controller. 스핀 요청 수신 후 즉시 `RouletteService`로 위임. 확률 계산 로직 Controller 내 포함 금지.

---

### 4.2 Service Layer (서비스 계층)

#### 4.2.1 EventRewardService

**파일**: `app/Modules/Event/Services/EventRewardService.php` (563 lines)  
**인터페이스**: `EventRewardServiceInterface`

| 메서드 | 역할 |
|--------|------|
| `getEventList(): array` | 활성 이벤트 목록 조회 및 camelCase 변환 |
| `validateAndRewardKeyword(int $accountId, int $eventId, string $keyword): array` | 키워드 이벤트 참여 전체 처리 (검증 + 보상) |
| `validateAndRewardCoupon(int $accountId, int $eventId, string $couponCode): array` | 쿠폰 이벤트 참여 전체 처리 |
| `processAttendance(int $accountId, int $eventId): array` | 출석 이벤트 처리 및 연속 출석 보상 산정 |
| `processChargeEvent(int $accountId, int $eventId, int $chargeAmount, string $idempotencyKey): array` | 코인 충전 이벤트 보상 처리 (7 tier GRADE_THRESHOLDS) |
| `issueRenewalCoupon(int $accountId, int $eventId): array` | 갱신 쿠폰 발급 (만료일 30일) |
| `getEventHistory(int $accountId): array` | 사용자 이벤트 참여 이력 조회 |

**GRADE_THRESHOLDS 상수 (7 Tiers):**

```php
private const GRADE_THRESHOLDS = [
    1 => ['min' => 1000,   'max' => 4999,        'coin' => 50,   'coupon' => null],
    2 => ['min' => 5000,   'max' => 9999,        'coin' => 150,  'coupon' => null],
    3 => ['min' => 10000,  'max' => 29999,       'coin' => 300,  'coupon' => 'TIER3'],
    4 => ['min' => 30000,  'max' => 49999,       'coin' => 500,  'coupon' => 'TIER4'],
    5 => ['min' => 50000,  'max' => 99999,       'coin' => 1000, 'coupon' => 'TIER5_PREMIUM'],
    6 => ['min' => 100000, 'max' => 199999,      'coin' => 2000, 'coupon' => 'TIER6_VIP'],
    7 => ['min' => 200000, 'max' => PHP_INT_MAX, 'coin' => 5000, 'coupon' => 'TIER7_SPECIAL'],
];
```

#### 4.2.2 RouletteService

**파일**: `app/Modules/Event/Services/RouletteService.php` (254 lines)  
**인터페이스**: `RouletteServiceInterface`

| 메서드 | 역할 |
|--------|------|
| `spin(int $accountId, int $eventId): array` | VIP 등급 조회 → 가중 랜덤 세그먼트 선택 → 보상 지급 |
| `getWeightedRandomSegment(array $weights): int` | 누적 합산 + `random_int()` CSPRNG로 세그먼트 인덱스 반환 |
| `getRouletteHistory(int $accountId): array` | 룰렛 당첨 이력 조회 |
| `getRouletteInfo(string $vipGrade): array` | 세그먼트 및 VIP 등급별 확률 정보 반환 |

**세그먼트 구조 (5개 고정):**

```php
private const SEGMENTS = [
    0 => ['name' => '꽝',        'rewardType' => null,     'rewardAmount' => 0],
    1 => ['name' => '코인 소량', 'rewardType' => 'coin',   'rewardAmount' => 50],
    2 => ['name' => '코인 중량', 'rewardType' => 'coin',   'rewardAmount' => 200],
    3 => ['name' => '쿠폰',      'rewardType' => 'coupon', 'rewardAmount' => 1],
    4 => ['name' => '대박',      'rewardType' => 'coin',   'rewardAmount' => 1000],
];
```

**VIP 등급별 확률 가중치 (VIP_PROBABILITIES):**

```php
private const VIP_PROBABILITIES = [
    'A' => [0 => 10, 1 => 30, 2 => 30, 3 => 20, 4 => 10], // 총합 100
    'B' => [0 => 20, 1 => 30, 2 => 25, 3 => 15, 4 => 10],
    'C' => [0 => 30, 1 => 30, 2 => 20, 3 => 15, 4 => 5],
    'D' => [0 => 40, 1 => 30, 2 => 15, 3 => 10, 4 => 5],
    'E' => [0 => 50, 1 => 30, 2 => 10, 3 => 8,  4 => 2],
];
```

---

### 4.3 Repository Layer (레포지토리 계층)

#### 4.3.1 EventRepository

**파일**: `app/Modules/Event/Repositories/EventRepository.php`

| 메서드 | 반환형 | 설명 |
|--------|--------|------|
| `findActiveEvents(): array` | `array` | 현재 활성 이벤트 목록 조회 |
| `findEventById(int $eventId): array\|null` | `array\|null` | 이벤트 단건 조회 |
| `findKeywordByEventAndKeyword(int $eventId, string $keyword): array\|null` | `array\|null` | 키워드 유효성 조회 (case-insensitive) |
| `insertParticipation(array $data): bool` | `bool` | 이벤트 참여 이력 삽입 |
| `findParticipation(int $accountId, int $eventId): array\|null` | `array\|null` | 참여 여부 조회 |
| `findParticipationHistory(int $accountId): array` | `array` | 참여 이력 전체 조회 |
| `findCouponByCode(string $couponCode): array\|null` | `array\|null` | 쿠폰 코드 조회 |
| `updateCouponStatus(int $couponId, string $status): bool` | `bool` | 쿠폰 상태 변경 |
| `findAttendanceToday(int $accountId, int $eventId): array\|null` | `array\|null` | 당일 출석 여부 조회 (UTC 기준) |
| `getConsecutiveAttendanceDays(int $accountId, int $eventId): int` | `int` | 연속 출석일 수 조회 |

**DB 접근 방식**: 단순 CRUD는 Query Builder 사용. 연속 출석일 수 계산은 `$db->query()` + named binding (CTE 또는 Window Function).

#### 4.3.2 RouletteRepository

**파일**: `app/Modules/Event/Repositories/RouletteRepository.php`

| 메서드 | 반환형 | 설명 |
|--------|--------|------|
| `findUserVipGrade(int $accountId): string` | `string` | 사용자 VIP 등급 조회 (`A`~`E`) |
| `countTodaySpins(int $accountId, int $eventId): int` | `int` | 당일 스핀 횟수 조회 (UTC 기준) |
| `insertRouletteHistory(array $data): bool` | `bool` | 룰렛 당첨 이력 삽입 |
| `findRouletteHistory(int $accountId): array` | `array` | 룰렛 당첨 이력 조회 |

---

### 4.4 Entity and Value Object (엔티티 및 값 객체)

Event 모듈은 현재 데이터 전달에 레거시 PHP 배열을 사용한다. Entity 클래스와 Value Object로의 마이그레이션이 `dev/migration` 브랜치에서 점진적으로 계획된다.

| 대상 | 현재 상태 | 마이그레이션 목표 | 브랜치 |
|------|---------|---------------|--------|
| 이벤트 참여 데이터 | PHP `array` | `EventParticipation` Entity | `dev/migration` |
| 룰렛 당첨 데이터 | PHP `array` | `RouletteResult` VO | `dev/migration` |
| 보상 데이터 | PHP `array` | `RewardResult` VO | `dev/migration` |

---

## 5. Dependency Viewpoint (의존성 뷰포인트)

### 5.1 DI Registration (DI 등록)

Event 모듈의 모든 DI 바인딩은 `app/Modules/Event/Config/Services.php`에 등록한다. 중앙 `app/Config/Services.php`에 바인딩 금지.

| Interface | Concrete Class | Scope |
|-----------|---------------|-------|
| `EventRewardServiceInterface` | `EventRewardService` | Shared (singleton) |
| `RouletteServiceInterface` | `RouletteService` | Shared (singleton) |
| `EventRepositoryInterface` | `EventRepository` | Shared (singleton) |
| `RouletteRepositoryInterface` | `RouletteRepository` | Shared (singleton) |

**DI 바인딩 예시:**

```php
$services->bind(
    \App\Modules\Event\Interfaces\EventRewardServiceInterface::class,
    \App\Modules\Event\Services\EventRewardService::class
);
$services->bind(
    \App\Modules\Event\Interfaces\RouletteServiceInterface::class,
    \App\Modules\Event\Services\RouletteService::class
);
```

### 5.2 Cross-Module Dependencies (크로스 모듈 의존성)

| 의존 방향 | 방법 | 설명 |
|---------|------|------|
| Event → Shared/Coin | `service('coinService')` | 코인 보상 지급 (`CoinServiceInterface`) |
| Event → Shared/Coupon | `service('couponService')` | 쿠폰 보상 지급 (`CouponServiceInterface`) |
| Event → Shared/Account | `RouletteRepository` 경유 | VIP 등급 조회 (`tb_account.vip_grade`) |

**의존성 방향도:**

```
EventController
  └─> EventRewardServiceInterface (DI)
        ├─> EventRepositoryInterface (DI)
        ├─> CoinServiceInterface (Shared, DI)
        └─> CouponServiceInterface (Shared, DI)

RouletteController
  └─> RouletteServiceInterface (DI)
        ├─> RouletteRepositoryInterface (DI)
        ├─> CoinServiceInterface (Shared, DI)
        └─> CouponServiceInterface (Shared, DI)
```

### 5.3 Filter Chain (필터 체인)

모든 상태 변경 요청은 다음 순서로 필터 체인을 통과한다:

```
ratelimit -> csrftoken -> auth -> Controller
```

> Event 모듈은 상담사 전용 EP가 없으므로 `role:callee` 필터 미적용.

---

## 6. Information Viewpoint (정보 뷰포인트)

### 6.1 Core Tables (핵심 테이블)

| 테이블 | 설명 | 핵심 제약 |
|--------|------|---------|
| `tb_event` | 이벤트 마스터 | `event_id` PK, `start_date`, `end_date`, `status` |
| `tb_event_participation` | 이벤트 참여 이력 | `UNIQUE(account_id, event_id, keyword)` |
| `tb_event_keyword` | 유효 키워드 목록 | `event_id` + `keyword` (case-insensitive) |
| `tb_roulette_history` | 룰렛 당첨 이력 | `account_id`, `event_id`, `segment_index`, `vip_grade` |

### 6.2 Core Tables DDL (핵심 테이블 DDL)

```sql
-- 이벤트 마스터
CREATE TABLE tb_event (
    event_id     INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    event_name   VARCHAR(200)    NOT NULL,
    event_type   ENUM('keyword','coupon','attendance','charge','roulette') NOT NULL,
    start_date   DATETIME        NOT NULL,
    end_date     DATETIME        NOT NULL,
    status       VARCHAR(20)     DEFAULT 'active',
    regist_date  DATETIME        DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_status_date (status, start_date, end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 이벤트 참여 이력
CREATE TABLE tb_event_participation (
    participation_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_id        INT UNSIGNED NOT NULL,
    event_id          INT UNSIGNED NOT NULL,
    keyword           VARCHAR(100) DEFAULT NULL,
    idempotency_key   VARCHAR(128) DEFAULT NULL,
    reward_type       VARCHAR(20)  DEFAULT NULL,
    reward_amount     INT          DEFAULT 0,
    regist_date       DATETIME     DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_participation (account_id, event_id, keyword),
    UNIQUE KEY uq_idempotency (account_id, idempotency_key),
    INDEX idx_account_id (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 룰렛 당첨 이력
CREATE TABLE tb_roulette_history (
    history_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_id      INT UNSIGNED NOT NULL,
    event_id        INT UNSIGNED NOT NULL,
    segment_index   TINYINT      NOT NULL COMMENT '0=꽝,1=코인소량,2=코인중량,3=쿠폰,4=대박',
    vip_grade       CHAR(1)      NOT NULL COMMENT 'A|B|C|D|E',
    reward_type     VARCHAR(20)  DEFAULT NULL,
    reward_amount   INT          DEFAULT 0,
    regist_date     DATETIME     DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_account_event (account_id, event_id),
    INDEX idx_regist_date (regist_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 6.3 Data Flow (데이터 흐름)

```
Client (JSON camelCase)
  -> EventController (validation, camelCase → snake_case)
  -> EventRewardService (business logic)
  -> EventRepository (Query Builder)
  -> Aurora MySQL (utf8mb4, UTC)
  -> Response (snake_case → camelCase 변환)
  -> Client
```

### 6.4 DB → API camelCase Mapping (필드 매핑)

| DB 컬럼 (snake_case) | API 응답 키 (camelCase) |
|---------------------|----------------------|
| `event_id` | `eventId` |
| `event_name` | `eventName` |
| `event_type` | `eventType` |
| `start_date` | `startDate` |
| `end_date` | `endDate` |
| `reward_type` | `rewardType` |
| `reward_amount` | `rewardAmount` |
| `coupon_code` | `couponCode` |
| `consecutive_days` | `consecutiveDays` |
| `segment_index` | `segmentIndex` |
| `vip_grade` | `vipGrade` |
| `expires_at` | `expiresAt` |
| `created_at` | `createdAt` |

---

## 7. Patterns Viewpoint (패턴 뷰포인트)

### 7.1 Applied Design Patterns (적용된 디자인 패턴)

| 패턴 | 위치 | 근거 |
|------|------|------|
| Strategy (GoF) | `RouletteService::getWeightedRandomSegment()` | VIP 등급별 확률 가중치 배열을 전달하여 세그먼트 선택 알고리즘을 독립적으로 테스트 가능. Mock 가중치 배열 주입으로 단위 테스트 용이 |
| Repository | `EventRepository`, `RouletteRepository` | DB 접근을 비즈니스 로직에서 격리. Service 계층의 독립적 단위 테스트 활성화 (mock repository 주입) |
| Template Method (계획) | `EventRewardService` 이벤트 유형별 처리 | 현재 switch/match 분기 → 각 이벤트 유형별 Strategy 클래스로 점진적 분리 예정 (`dev/migration`) |
| Idempotency Key | `processChargeEvent()` | DB UNIQUE 제약 + 멱등키로 결제 콜백 중복 처리 방지. CLAUDE.md 보안 정책 준수 |

### 7.2 Architecture Decision Records (아키텍처 결정 기록)

| ADR | 결정 | 근거 | 대안 |
|-----|------|------|------|
| ADR-EVT-001 | 룰렛 확률 계산 서버 측 전용 | 클라이언트 측 확률 계산은 조작 가능. `random_int()`는 PHP CSPRNG 사용 — 예측 불가 (OWASP A07:2021). 클라이언트 입력값으로 세그먼트 인덱스 결정 금지 | 클라이언트 측 계산 (보안 취약점) |
| ADR-EVT-002 | 이벤트 참여 + 보상 지급 단일 트랜잭션 | 참여 이력 기록 성공 후 보상 지급 실패 시 데이터 불일치 발생. 원자성 보장을 위해 단일 트랜잭션으로 묶음. 롤백 시 이력도 함께 롤백 | 별도 트랜잭션 (데이터 불일치 위험) |
| ADR-EVT-003 | 코인 충전 이벤트 멱등키 필수 | 결제 콜백 재시도 등 외부 시스템의 중복 요청 대비. DB UNIQUE 제약 `(account_id, idempotency_key)`으로 최종 방어. CLAUDE.md — "정산/결제는 멱등키 필수" | 멱등키 없음 (중복 보상 위험) |
| ADR-EVT-004 | VIP 확률 가중치 서비스 내 상수 관리 | 확률값은 게임 설계 시점에 확정, 런타임 변경 불필요. DB 저장 시 조회 오버헤드 + 무결성 검증 부담 증가. 변경 빈도 낮아 코드 상수 관리가 현실적 | DB 저장 동적 관리 (오버헤드 증가) |
| ADR-EVT-005 | EventRepository 10 메서드 단일 파일 | 이벤트 유형별 분리(5개 Repository)는 즉각 분리 시 10개 EP 동시 수정 필요 — 허용 불가한 운영 리스크. `dev/migration`에서 점진적 분리 | 즉각 이벤트 유형별 Repository 분리 |

---

## 8. Interface Viewpoint (인터페이스 뷰포인트)

### 8.1 Internal Interface Contracts (내부 인터페이스 계약)

**EventRewardServiceInterface**

```php
interface EventRewardServiceInterface
{
    public function getEventList(): array;
    public function validateAndRewardKeyword(int $accountId, int $eventId, string $keyword): array;
    public function validateAndRewardCoupon(int $accountId, int $eventId, string $couponCode): array;
    public function processAttendance(int $accountId, int $eventId): array;
    public function processChargeEvent(
        int    $accountId,
        int    $eventId,
        int    $chargeAmount,
        string $idempotencyKey
    ): array;
    public function issueRenewalCoupon(int $accountId, int $eventId): array;
    public function getEventHistory(int $accountId): array;
}
```

**RouletteServiceInterface**

```php
interface RouletteServiceInterface
{
    public function spin(int $accountId, int $eventId): array;
    public function getRouletteHistory(int $accountId): array;
    public function getRouletteInfo(string $vipGrade): array;
}
```

**EventRepositoryInterface** — 10 메서드: `findActiveEvents()`, `findEventById()`, `findKeywordByEventAndKeyword()`, `insertParticipation()`, `findParticipation()`, `findParticipationHistory()`, `findCouponByCode()`, `updateCouponStatus()`, `findAttendanceToday()`, `getConsecutiveAttendanceDays()`. 전체 시그니처는 `event-idd.md` §3에 명세.

**RouletteRepositoryInterface** — 4 메서드: `findUserVipGrade()`, `countTodaySpins()`, `insertRouletteHistory()`, `findRouletteHistory()`. 전체 시그니처는 `event-idd.md` §3에 명세.

### 8.2 API Response Contracts (API 응답 계약)

모든 EP는 프로젝트 전역 API 응답 표준을 준수한다.

| 조건 | HTTP 상태 | 응답 본문 |
|------|---------|---------|
| 성공 (조회) | 200 | `{ "data": { ... } }` |
| 성공 (생성/참여) | 200 | `{ "data": { "rewardType": "...", "rewardAmount": int } }` |
| 에러 | 4xx / 5xx | `{ "error": { "code": "...", "message": "..." } }` |

DB `snake_case` 필드는 모든 응답에서 API `camelCase`로 변환된다.

**보상 응답 예시:**

```json
{
  "data": {
    "rewardType": "coin",
    "rewardAmount": 300,
    "couponCode": null
  }
}
```

**룰렛 결과 응답 예시:**

```json
{
  "data": {
    "segmentIndex": 2,
    "rewardType": "coin",
    "rewardAmount": 200,
    "vipGrade": "B"
  }
}
```

---

## 9. Interaction Viewpoint (인터랙션 뷰포인트)

### 9.1 Keyword Event — Normal Flow (키워드 이벤트 정상 흐름)

```text
Client -> EventController::participateKeyword()
           |- 입력 검증 (eventId, keyword)
           |- checkNeedLogin(true) → JWT 검증
           |- EventRewardService::validateAndRewardKeyword($accountId, $eventId, $keyword)
           |    |- EventRepository::findEventById($eventId)      [이벤트 활성 여부]
           |    |- EventRepository::findKeywordByEventAndKeyword($eventId, $keyword)
           |    |- EventRepository::findParticipation($accountId, $eventId)
           |    |- DB::beginTransaction()
           |    |- EventRepository::insertParticipation($data)
           |    |- CoinService::addCoin($accountId, $amount)    [또는 CouponService]
           |    |- DB::commit()
           |    +- return ['rewardType' => 'coin', 'rewardAmount' => 300, ...]
           +- HTTP 200 { "data": { "rewardType": "coin", "rewardAmount": 300 } }
```

### 9.2 Keyword Event — Error Flows (키워드 이벤트 에러 흐름)

```text
Client -> EventController::participateKeyword()
           |- [중복 참여] EventRepository::findParticipation() → 이미 존재
           |    +- ConflictException → HTTP 409 { "error": { "code": "CONFLICT" } }
           |
           |- [유효하지 않은 키워드] findKeywordByEventAndKeyword() → null
           |    +- InvalidInputException → HTTP 400 { "error": { "code": "INVALID_INPUT" } }
           |
           |- [이벤트 기간 외] findEventById() → 종료됨
                +- InvalidInputException → HTTP 400 { "error": { "code": "INVALID_INPUT" } }
```

### 9.3 Roulette Spin — Full Flow (룰렛 스핀 전체 흐름)

```text
Client -> RouletteController::spin()
           |- checkNeedLogin(true) → JWT 검증
           |- RouletteService::spin($accountId, $eventId)
           |    |- RouletteRepository::findUserVipGrade($accountId)
           |    |    +- SELECT vip_grade FROM tb_account WHERE ac_id = ?
           |    |- RouletteRepository::countTodaySpins($accountId, $eventId)
           |    |    +- [초과 시] → HTTP 429 { "error": { "code": "CONFLICT" } }
           |    |- VIP_PROBABILITIES[$vipGrade] 로드
           |    |- getWeightedRandomSegment(weights)
           |    |    +- 누적 합산 + random_int(1, 100) → 세그먼트 인덱스 선택
           |    |- DB::beginTransaction()
           |    |- RouletteRepository::insertRouletteHistory($data)
           |    |- CoinService::addCoin() / CouponService::issueCoupon()  [세그먼트별]
           |    |- DB::commit()
           |    +- return ['segmentIndex' => 2, 'rewardType' => 'coin', 'rewardAmount' => 200, 'vipGrade' => 'B']
           +- HTTP 200 { "data": { "segmentIndex": 2, "rewardType": "coin", "rewardAmount": 200, "vipGrade": "B" } }
```

### 9.4 Charge Event — Idempotency Flow (충전 이벤트 멱등성 흐름)

```text
Client (1st request) -> EventController::participateChargeEvent()
                         |- EventRewardService::processChargeEvent($accountId, $eventId, 10000, 'KEY-001')
                         |    |- DB unique 제약 확인: (account_id, 'KEY-001') → 없음
                         |    |- GRADE_THRESHOLDS: chargeAmount=10000 → tier 3
                         |    |- DB::beginTransaction()
                         |    |- insertParticipation(['idempotency_key' => 'KEY-001', ...])
                         |    |- CoinService::addCoin($accountId, 300)
                         |    +- DB::commit()
                         +- HTTP 200 { "data": { "tier": 3, "rewardAmount": 300 } }

Client (2nd request, same KEY-001) -> EventController::participateChargeEvent()
                         |- EventRewardService::processChargeEvent($accountId, $eventId, 10000, 'KEY-001')
                         |    |- DB unique 제약 위반: (account_id, 'KEY-001') → 이미 존재
                         +- HTTP 409 { "error": { "code": "CONFLICT" } }
```

### 9.5 Attendance Event — Consecutive Days Flow (출석 이벤트 연속 출석 흐름)

```text
Client -> EventController::participateAttendance()
           |- EventRewardService::processAttendance($accountId, $eventId)
           |    |- EventRepository::findAttendanceToday($accountId, $eventId)
           |    |    +- [당일 출석 완료] → HTTP 409 CONFLICT
           |    |- EventRepository::getConsecutiveAttendanceDays($accountId, $eventId)
           |    |    +- $db->query() + CTE/Window Function → consecutiveDays = 5
           |    |- 연속 출석 보상 산정 (5일 기준 보상 테이블)
           |    |- DB::beginTransaction()
           |    |- EventRepository::insertParticipation($attendanceData)
           |    |- CoinService::addCoin($accountId, $rewardAmount)
           |    +- DB::commit()
           +- HTTP 200 { "data": { "consecutiveDays": 5, "rewardType": "coin", "rewardAmount": 100 } }
```

---

## 10. Design Overlay (설계 오버레이)

### 10.1 Security Design (보안 설계)

| 항목 | 설계 결정 | 적용 표준 |
|------|---------|---------|
| 인증 | 모든 EP — `checkNeedLogin(true)` + `hc_access` JWT 쿠키 | OWASP API2:2023 |
| CSRF | POST EP — `X-CSRF-TOKEN` 헤더 검증 (Signed Double Submit Cookie) | CLAUDE.md |
| 룰렛 확률 조작 방지 | 서버 측 `random_int()` CSPRNG 전용. 클라이언트 입력 기반 세그먼트 결정 금지 | OWASP A07:2021 |
| 멱등키 | 충전 이벤트 — DB UNIQUE 제약 `(account_id, idempotency_key)` 이중 방어 | CLAUDE.md |
| 소유권 검증 | Repository 쿼리에 `account_id` 조건 내장 | OWASP API1:2023 (BOLA) |

### 10.2 Error Handling Design (에러 처리 설계)

| HTTP 상태 | 에러 코드 | 발생 상황 |
|---------|---------|---------|
| 400 | `INVALID_INPUT` | 입력값 유효성 검증 실패, 유효하지 않은 키워드/쿠폰 |
| 401 | `UNAUTHORIZED` | JWT 인증 실패 |
| 403 | `FORBIDDEN` | 접근 권한 없음 |
| 404 | `NOT_FOUND` | 이벤트 또는 리소스 미존재 |
| 409 | `CONFLICT` | 중복 참여, 이미 사용된 쿠폰, 당일 출석 완료, 멱등키 중복 |
| 429 | `CONFLICT` | 일일 룰렛 참여 횟수 초과 |
| 500 | `INTERNAL` | DB 오류, 예상치 못한 서버 내부 오류 |

### 10.3 Logging Design (로깅 설계)

| 이벤트 | 로그 레벨 | 기록 항목 |
|--------|---------|---------|
| 이벤트 참여 성공 | INFO | `account_id`, `event_id`, `reward_type`, `reward_amount` |
| 이벤트 참여 실패 (CONFLICT) | WARNING | `account_id`, `event_id`, 에러 코드 |
| DB 트랜잭션 롤백 | ERROR | 예외 메시지, 스택 트레이스 |
| 룰렛 스핀 결과 | INFO | `account_id`, `vip_grade`, `segment_index`, `reward_amount` |

### 10.4 Transaction Design (트랜잭션 설계)

| 작업 | 트랜잭션 범위 | 실패 시 |
|------|------------|--------|
| 키워드/쿠폰/출석/충전 이벤트 참여 | 참여 이력 기록 + 보상 지급 (단일 트랜잭션) | 전체 롤백 (이력 포함) |
| 룰렛 스핀 | 당첨 이력 기록 + 보상 지급 (단일 트랜잭션) | 전체 롤백 |
| 갱신 쿠폰 발급 | 쿠폰 DB 저장 단독 | 롤백 (쿠폰 미발급) |

---

## 11. Traceability Matrix (추적성 매트릭스)

SRS 요구사항 ↔ 설계 요소 매핑:

| SRS 요구사항 ID | 설명 | 설계 요소 (SDD) | 섹션 |
|--------------|------|--------------|------|
| FR-EVT-001 | 이벤트 목록 조회 | `EventController::getEventList()`, `EventRewardService::getEventList()`, `EventRepository::findActiveEvents()` | §4.1.1, §4.2.1, §4.3.1 |
| FR-EVT-002 | 키워드 이벤트 참여 | `EventController::participateKeyword()`, `EventRewardService::validateAndRewardKeyword()`, `EventRepository::insertParticipation()`, DB UNIQUE 제약 | §4.1.1, §4.2.1, §6.2 |
| FR-EVT-003 | 쿠폰 이벤트 참여 | `EventRewardService::validateAndRewardCoupon()`, `EventRepository::findCouponByCode()`, `updateCouponStatus()` | §4.2.1, §4.3.1 |
| FR-EVT-004 | 출석 이벤트 처리 | `EventRewardService::processAttendance()`, `EventRepository::getConsecutiveAttendanceDays()` (CTE/Window Function) | §4.2.1, §4.3.1, §9.5 |
| FR-EVT-005 | 코인 충전 이벤트 (7 tier) | `EventRewardService::processChargeEvent()`, `GRADE_THRESHOLDS` 상수, 멱등키 DB UNIQUE 제약 | §4.2.1, §6.2, §9.4 |
| FR-EVT-006 | 갱신 쿠폰 발급 | `EventRewardService::issueRenewalCoupon()`, `RENEWAL_COUPON_CODES`, `DateTimeImmutable::modify('+30 days')` | §4.2.1 |
| FR-EVT-007 | 룰렛 이벤트 (VIP 확률) | `RouletteService::spin()`, `getWeightedRandomSegment()`, `VIP_PROBABILITIES`, `random_int()` | §4.2.2, §9.3 |
| NFR-EVT-001 | 중복 참여 방지 | DB UNIQUE 제약, 멱등키 (ADR-EVT-002, ADR-EVT-003) | §6.2, §7.2 |
| NFR-EVT-002 | 보상 한도 제어 | `EventRewardService` 한도 검증 로직 | §4.2.1 |
| NFR-EVT-003 | 응답 성능 p95 | Repository Query Builder 우선, CTE는 `$db->query()` 사용 | §4.3.1 |
| NFR-EVT-004 | 보안/확률 조작 방지 | ADR-EVT-001 (server-side `random_int()`), CSRF 필터 체인 | §7.2, §10.1, §5.3 |
| NFR-EVT-005 | 감사 로그 | `tb_event_participation`, `tb_roulette_history` 영구 보존 | §6.1, §6.2 |

---

## 12. Feasibility Review (타당성 검토)

> 근거: PHP 공식 문서 (`random_int()`), OWASP API Security Top 10 2023, CLAUDE.md 보안 정책, MySQL 8.0 Reference Manual

| 검토 ID | 주제 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|------|------|------|------|-----------|
| FEA-EVT-001 | 룰렛 확률 — PHP `random_int()` CSPRNG | 채택 | PHP 공식 문서 — `random_int()`는 CSPRNG 사용. `rand()`, `mt_rand()`와 달리 예측 불가. 룰렛 확률 조작 방지 필수 (OWASP A07:2021 — 불충분한 엔트로피). 클라이언트 입력값 기반 결정 시 조작 가능 | `mt_rand()` (비암호학적) | `random_int()`: 보안, 약간 느림. `mt_rand()`: 빠르지만 예측 가능 |
| FEA-EVT-002 | 멱등키 + DB UNIQUE 이중 방어 (충전 이벤트) | 채택 | CLAUDE.md — "정산/결제는 멱등키 필수. 트랜잭션은 DB unique 제약으로 중복 방지". 결제 콜백 재시도, 네트워크 오류 시 동일 요청 중복 발생 가능. DB UNIQUE `(account_id, idempotency_key)`으로 race condition 방어 | 애플리케이션 레벨 중복 체크만 | 이중 방어: 안전하지만 구현 복잡. 단일: 간단하지만 race condition 취약 |
| FEA-EVT-003 | 이벤트 참여 + 보상 지급 단일 트랜잭션 | 채택 | 참여 이력 기록 성공 후 보상 지급 실패 시 데이터 불일치 발생. InnoDB 트랜잭션 원자성 보장 (Aurora MySQL). 롤백 시 이력도 함께 롤백 | 별도 트랜잭션 분리 | 단일 트랜잭션: 원자성 보장, 트랜잭션 시간 증가. 분리: 성능 유리, 불일치 위험 |
| FEA-EVT-004 | VIP 확률 가중치 서비스 내 상수 | 채택 | 확률값은 게임 설계 시점에 확정, 런타임 변경 불필요. DB 저장 시 조회 오버헤드 + 무결성 검증 부담 증가. 변경 빈도 낮아 코드 상수 관리 현실적. 변경 시 배포 프로세스로 통제 | DB 동적 관리 | 상수: 성능 우수, 배포 필요. DB: 유연성, 조회 오버헤드 |
| FEA-EVT-005 | `tb_event_participation` UNIQUE 제약 구조 | 채택 | `(account_id, event_id, keyword)` 복합 UNIQUE — 동일 키워드 중복 참여 DB 레벨 방어. `(account_id, idempotency_key)` 별도 UNIQUE — 충전 이벤트 멱등키 방어. 두 제약의 역할 분리로 각 이벤트 유형 커버 | 단일 UNIQUE 또는 애플리케이션 레벨만 | 복합 UNIQUE: 강력한 DB 방어, 스키마 복잡도 증가 |

---

## 13. Change Impact Log (변경 영향 기록)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|---------|---------|--------|---------|
| IEEE 1016-2009 8-Viewpoint 구조로 전환 | 문서 전체 재구성 | Context, Composition, Logical, Dependency, Information, Patterns, Interface, Interaction 뷰포인트로 설계의 모든 차원 명시적 커버 | IEEE 1016-2009 준수: 8 뷰포인트 요구 |
| Dependency Viewpoint 신설 (§5) | 신규 섹션 | DI 등록 테이블, 필터 체인, 크로스 모듈 의존성 방향 명시. 아키텍처 가시성 향상 | IEEE 1016-2009 Dependency Viewpoint 요구 |
| Patterns Viewpoint 신설 (§7) | 신규 섹션 | 디자인 패턴(Strategy, Repository, Idempotency Key) 및 ADR 5건 공식 문서화 — 결정 근거와 대안 명시 | IEEE 1016-2009 Patterns Viewpoint 요구 |
| Interaction Viewpoint 확장 (§9) | 신규 섹션 | 5개 시퀀스 흐름(키워드 정상/에러, 룰렛, 충전 멱등성, 출석 연속) 텍스트 시퀀스 표기로 명세 | IEEE 1016-2009 Interaction Viewpoint 요구 |
| Design Overlay 신설 (§10) | 신규 섹션 | 보안(CSRF/JWT/CSPRNG/멱등키/BOLA), 에러 처리, 로깅, 트랜잭션 설계를 횡단 관심사로 명시 | IEEE 1016-2009 Design Overlay 요구 |
| Core Tables DDL 추가 (§6.2) | Information Viewpoint | 실제 DDL 명세로 개발자·DBA가 단일 문서 참조 가능 | 스키마 마이그레이션 지침 준수 |
| Entity/VO 마이그레이션 계획 (§4.4) | Logical Viewpoint | 현재 배열 기반 상태 및 마이그레이션 계획 문서화 — `dev/migration` 작업 방향 공유 | 아키텍처 투명성 |
| Traceability Matrix 신설 (§11) | 신규 섹션 | SRS FR/NFR 12건 ↔ SDD 설계 요소 1:1 매핑. QA 추적성 확보 | IEEE 1016-2009 추적성 요구 |
| 영문+한국어 병기 | 전체 섹션 | 섹션 제목 영문+한글 병기. 국제 표준 준수 + 내부 팀 가독성 확보 | 프로젝트 지침 — IEEE 표준 전환 |
| v1.0 → v2.0 | 문서 헤더 및 개정 로그 | IEEE 1016-2009 전환 및 8-Viewpoint 재구성 메이저 버전 반영 | 문서 이력 명확화 |

---

## 14. Document History (문서 이력)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|---------|--------|
| 2026-04-15 | 1.0.0 | 최초 작성 — Event Module SDD | jypark |
| 2026-04-15 | 2.0.0 | IEEE 1016-2009 8-Viewpoint 전환. Context, Composition, Logical, Dependency, Information, Patterns, Interface, Interaction, Design Overlay, Traceability Matrix 신설. ADR 5건, DDL 추가, 한국어+영문 병기 | jypark |
