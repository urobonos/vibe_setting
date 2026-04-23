---
문서명: Event — Interface Design Document
문서 ID: event-idd
버전: v2.0
적용 표준: MIL-STD-498 (Interface Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Event Module (HongCafe Global Backend)
관련 문서: event-sdd.md, event-srs.md
---

# Event — Interface Design Document

> version: 2.0 | standard: MIL-STD-498 IDD | lastUpdated: 2026-04-15 | module: Event

---

## 1. Scope (범위)

### 1.1 Identification (식별)

본 문서는 HongCafe Global Backend Event 모듈의 인터페이스 설계를 MIL-STD-498 Interface Design Description (IDD) 표준에 따라 명세한다.

| 항목 | 내용 |
|------|------|
| 문서 ID | event-idd |
| 대상 시스템 | Event Module — HongCafe Global Backend |
| 기반 SDD | `event-sdd.md` v2.0 |
| 내부 인터페이스 수 | 4개 (IF-INT-001~004) |
| 외부 인터페이스 수 | 2개 (IF-EXT-001~002) |
| EP 총수 | 10개 (EventController 7 + RouletteController 3) |

### 1.2 System Overview (시스템 개요)

Event 모듈은 HongCafe Global Backend Modular Monolith 아키텍처 내에서 이벤트 목록 조회, 키워드/쿠폰/출석/코인충전 이벤트 참여, 갱신 쿠폰 발급, 룰렛 이벤트 처리(VIP 등급별 확률 가중치)를 담당한다. 외부 SaaS(SendBird, FCM 등)에 직접 의존하지 않으며, Shared 모듈의 `CoinServiceInterface` / `CouponServiceInterface`를 DI로 주입받아 보상을 지급한다.

### 1.3 Document Overview (문서 개요)

본 IDD는 MIL-STD-498 §DI-IPSC-81436 기준에 따라 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 기술한다.

| 섹션 | 내용 |
|------|------|
| §2 | 참조 문서 |
| §3 | 내부 인터페이스 4개 (IF-INT-001~004) — PHP 시그니처 포함 |
| §4 | 외부 인터페이스 2개 (IF-EXT-001~002) — Shared 모듈 DI 의존성 명세 |
| §5 | 이벤트 계약 (Events and Signals) |
| §6 | 에러 처리 계약 (Error Handling Contract) |
| §7 | 데이터 포맷 (Data Formats and Encoding) |
| §8 | 타당성 검토 |
| §9 | 변경 영향 기록 |
| §10 | 요구사항 추적성 매트릭스 |

---

## 2. References (참조 문서)

| 문서 | 위치 / 출처 |
|------|-----------|
| MIL-STD-498 — Software Development and Documentation | US DoD Standards |
| DI-IPSC-81436 — Interface Design Description (IDD) | MIL-STD-498 Data Item |
| event-srs.md v2.0 | `docs/specs/event-srs.md` |
| event-sdd.md v2.0 | `docs/specs/event-sdd.md` |
| RFC 7231 — HTTP/1.1 Semantics and Content | IETF |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| OWASP Top 10 A07:2021 — Identification and Authentication Failures | https://owasp.org/Top10/A07_2021/ |
| PHP Manual — random_int() | https://www.php.net/manual/en/function.random-int.php |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |

---

## 3. Internal Interfaces (내부 인터페이스)

MIL-STD-498 IDD §3 — 각 내부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-INT-001: EventRewardServiceInterface

#### 3.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | EventRewardServiceInterface |
| 파일 경로 | `app/Modules/Event/Interfaces/EventRewardServiceInterface.php` |
| 제공 컴포넌트 | `EventRewardService` |
| 소비 컴포넌트 | `EventController` |

#### 3.1.2 Data Elements (데이터 요소)

**`getEventList()` — 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `eventId` | int | 이벤트 ID |
| `eventName` | string | 이벤트명 |
| `eventType` | string | `keyword\|coupon\|attendance\|charge\|roulette` |
| `startDate` | string | 시작일 (UTC ISO 8601) |
| `endDate` | string | 종료일 (UTC ISO 8601) |
| `status` | string | `active\|inactive` |

**`validateAndRewardKeyword()` — 입력:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$accountId` | int | Y | 계정 ID (JWT 추출) |
| `$eventId` | int | Y | 이벤트 ID |
| `$keyword` | string | Y | 입력 키워드 (case-insensitive 검증) |

**`validateAndRewardKeyword()` — 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `rewardType` | string | `coin\|coupon` |
| `rewardAmount` | int | 보상 수량 |
| `couponCode` | string\|null | 쿠폰 보상 시 코드, 코인 보상 시 null |

**`processChargeEvent()` — 입력:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$accountId` | int | Y | 계정 ID |
| `$eventId` | int | Y | 이벤트 ID |
| `$chargeAmount` | int | Y | 충전 금액 (원화, > 0) |
| `$idempotencyKey` | string | Y | 멱등키 (min 16, max 128 chars) |

**`processChargeEvent()` — 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `tier` | int | 적용 티어 (1~7) |
| `rewardType` | string | `coin\|coupon` |
| `rewardAmount` | int | 코인 지급 수량 |
| `couponCode` | string\|null | 쿠폰 코드 (해당 티어만) |

**`issueRenewalCoupon()` — 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `couponCode` | string | 발급된 갱신 쿠폰 코드 |
| `expiresAt` | string | 만료일 (발급일 + 30일, UTC ISO 8601) |

**`processAttendance()` — 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `consecutiveDays` | int | 연속 출석일 수 |
| `rewardType` | string | `coin` |
| `rewardAmount` | int | 보상 코인 수량 |

#### 3.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Event/Config/Services.php` |
| 패턴 | Repository + Transaction (원자적 참여 이력 기록 + 보상 지급) |

#### 3.1.4 Error Handling (에러 처리)

| 에러 조건 | 예외 유형 | Controller 응답 |
|---------|---------|--------------|
| 중복 참여 (DB UNIQUE 위반) | `ConflictException` | HTTP 409 `CONFLICT` |
| 유효하지 않은 키워드/쿠폰 | `InvalidInputException` | HTTP 400 `INVALID_INPUT` |
| 이벤트 기간 외 참여 | `InvalidInputException` | HTTP 400 `INVALID_INPUT` |
| 멱등키 중복 (충전 이벤트) | `ConflictException` | HTTP 409 `CONFLICT` |
| 당일 출석 완료 | `ConflictException` | HTTP 409 `CONFLICT` |
| 이미 유효한 갱신 쿠폰 보유 | `ConflictException` | HTTP 409 `CONFLICT` |
| DB 오류 | CI4 Database Exception 전파 | HTTP 500 `INTERNAL` |

#### 3.1.5 Data Flow (데이터 흐름)

```
EventController
  └─ EventRewardService::validateAndRewardKeyword($accountId, $eventId, $keyword)
        ├─ EventRepository::findEventById($eventId)          [이벤트 활성 확인]
        ├─ EventRepository::findKeywordByEventAndKeyword()   [키워드 유효성]
        ├─ EventRepository::findParticipation()              [중복 확인]
        ├─ DB::beginTransaction()
        ├─ EventRepository::insertParticipation($data)
        ├─ CoinService::addCoin() / CouponService::issueCoupon()
        └─ DB::commit()
```

**PHP 시그니처:**

```php
<?php

declare(strict_types=1);

namespace App\Modules\Event\Interfaces;

interface EventRewardServiceInterface
{
    /**
     * 활성 이벤트 목록을 반환한다.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getEventList(): array;

    /**
     * 키워드 이벤트 참여 유효성 검증 및 보상 지급.
     *
     * @param  int    $accountId 계정 ID
     * @param  int    $eventId   이벤트 ID
     * @param  string $keyword   입력 키워드
     * @return array{rewardType: string, rewardAmount: int, couponCode: string|null}
     * @throws ConflictException     중복 참여 시
     * @throws InvalidInputException 유효하지 않은 키워드 시
     */
    public function validateAndRewardKeyword(int $accountId, int $eventId, string $keyword): array;

    /**
     * 쿠폰 이벤트 참여 유효성 검증 및 보상 지급.
     *
     * @param  int    $accountId  계정 ID
     * @param  int    $eventId    이벤트 ID
     * @param  string $couponCode 쿠폰 코드
     * @return array{rewardType: string, rewardAmount: int}
     * @throws ConflictException     이미 사용된 쿠폰 시
     * @throws InvalidInputException 유효하지 않은 쿠폰 시
     */
    public function validateAndRewardCoupon(int $accountId, int $eventId, string $couponCode): array;

    /**
     * 출석 이벤트 처리 및 연속 출석 보상 지급.
     *
     * @param  int $accountId 계정 ID
     * @param  int $eventId   이벤트 ID
     * @return array{consecutiveDays: int, rewardType: string, rewardAmount: int}
     * @throws ConflictException 당일 출석 완료 시
     */
    public function processAttendance(int $accountId, int $eventId): array;

    /**
     * 코인 충전 이벤트 보상 처리 (7 tier GRADE_THRESHOLDS 기반).
     *
     * @param  int    $accountId      계정 ID
     * @param  int    $eventId        이벤트 ID
     * @param  int    $chargeAmount   충전 금액
     * @param  string $idempotencyKey 멱등키 (min 16, max 128 chars)
     * @return array{tier: int, rewardType: string, rewardAmount: int, couponCode: string|null}
     * @throws ConflictException 멱등키 중복 시
     */
    public function processChargeEvent(
        int    $accountId,
        int    $eventId,
        int    $chargeAmount,
        string $idempotencyKey
    ): array;

    /**
     * 갱신 쿠폰 발급 (만료일 발급일 + 30일).
     *
     * @param  int $accountId 계정 ID
     * @param  int $eventId   이벤트 ID
     * @return array{couponCode: string, expiresAt: string}
     * @throws ConflictException 이미 유효한 갱신 쿠폰 보유 시
     */
    public function issueRenewalCoupon(int $accountId, int $eventId): array;

    /**
     * 사용자 이벤트 참여 이력 조회.
     *
     * @param  int $accountId 계정 ID
     * @return array<int, array<string, mixed>>
     */
    public function getEventHistory(int $accountId): array;
}
```

---

### IF-INT-002: RouletteServiceInterface

#### 3.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | RouletteServiceInterface |
| 파일 경로 | `app/Modules/Event/Interfaces/RouletteServiceInterface.php` |
| 제공 컴포넌트 | `RouletteService` |
| 소비 컴포넌트 | `RouletteController` |

#### 3.2.2 Data Elements (데이터 요소)

**`spin()` — 입력:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$accountId` | int | Y | 계정 ID (JWT 추출) |
| `$eventId` | int | Y | 이벤트 ID |

**`spin()` — 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `segmentIndex` | int | 당첨 세그먼트 인덱스 (0~4) |
| `rewardType` | string\|null | `coin\|coupon\|null` (꽝=null) |
| `rewardAmount` | int | 보상 수량 (꽝=0) |
| `vipGrade` | string | 적용 VIP 등급 (`A`~`E`) |

**세그먼트 정의 (SEGMENTS 상수):**

| 인덱스 | 이름 | rewardType | rewardAmount |
|--------|------|-----------|-------------|
| 0 | 꽝 | null | 0 |
| 1 | 코인 소량 | coin | 50 |
| 2 | 코인 중량 | coin | 200 |
| 3 | 쿠폰 | coupon | 1 |
| 4 | 대박 | coin | 1000 |

**VIP 등급별 가중치 (VIP_PROBABILITIES):**

| VIP | 꽝(0) | 코인소량(1) | 코인중량(2) | 쿠폰(3) | 대박(4) | 합계 |
|-----|------|-----------|-----------|--------|--------|------|
| A | 10 | 30 | 30 | 20 | 10 | 100 |
| B | 20 | 30 | 25 | 15 | 10 | 100 |
| C | 30 | 30 | 20 | 15 | 5 | 100 |
| D | 40 | 30 | 15 | 10 | 5 | 100 |
| E | 50 | 30 | 10 | 8 | 2 | 100 |

**`getRouletteInfo()` — 입력/출력:**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$vipGrade` | string | VIP 등급 (`A`~`E`) |

반환: `array{segments: array, probabilities: array}` — 해당 VIP 등급의 세그먼트 정보 + 확률 배열

#### 3.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Event/Config/Services.php` |
| 확률 계산 | 서버 측 `random_int()` CSPRNG 전용 (클라이언트 입력 사용 금지) |
| 패턴 | 누적 합산(cumulative sum) + CSPRNG (GoF Strategy 변형) |

#### 3.2.4 Error Handling (에러 처리)

| 에러 조건 | 예외 유형 | Controller 응답 |
|---------|---------|--------------|
| 일일 스핀 횟수 초과 | `ConflictException` | HTTP 429 `CONFLICT` |
| 유효하지 않은 VIP 등급 | `InvalidInputException` | HTTP 500 `INTERNAL` |
| DB 오류 (이력 삽입 실패) | CI4 Database Exception | HTTP 500 `INTERNAL` |
| 보상 지급 실패 | 트랜잭션 롤백 + Exception 전파 | HTTP 500 `INTERNAL` |

#### 3.2.5 Data Flow (데이터 흐름)

```
RouletteController
  └─ RouletteService::spin($accountId, $eventId)
        ├─ RouletteRepository::findUserVipGrade($accountId)
        │    └─ SELECT vip_grade FROM tb_account WHERE ac_id = ?
        ├─ RouletteRepository::countTodaySpins($accountId, $eventId)
        │    └─ [초과] → ConflictException
        ├─ VIP_PROBABILITIES[$vipGrade] 로드
        ├─ getWeightedRandomSegment(weights)
        │    └─ 누적 합산 + random_int(1, 100) → segmentIndex
        ├─ DB::beginTransaction()
        ├─ RouletteRepository::insertRouletteHistory($data)
        ├─ CoinService::addCoin() / CouponService::issueCoupon()
        └─ DB::commit()
```

**PHP 시그니처:**

```php
<?php

declare(strict_types=1);

namespace App\Modules\Event\Interfaces;

interface RouletteServiceInterface
{
    /**
     * 룰렛 스핀 실행 — VIP 등급 기반 확률 계산 후 세그먼트 선택 및 보상 지급.
     *
     * @param  int $accountId 계정 ID
     * @param  int $eventId   이벤트 ID
     * @return array{
     *     segmentIndex: int,
     *     rewardType: string|null,
     *     rewardAmount: int,
     *     vipGrade: string
     * }
     * @throws ConflictException 일일 참여 횟수 초과 시
     */
    public function spin(int $accountId, int $eventId): array;

    /**
     * 룰렛 당첨 이력 조회.
     *
     * @param  int $accountId 계정 ID
     * @return array<int, array<string, mixed>>
     */
    public function getRouletteHistory(int $accountId): array;

    /**
     * 룰렛 세그먼트 및 VIP 등급별 확률 정보 반환.
     *
     * @param  string $vipGrade VIP 등급 (A~E)
     * @return array{segments: array, probabilities: array}
     */
    public function getRouletteInfo(string $vipGrade): array;
}
```

---

### IF-INT-003: EventRepositoryInterface

#### 3.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-003 |
| 인터페이스명 | EventRepositoryInterface |
| 파일 경로 | `app/Modules/Event/Interfaces/EventRepositoryInterface.php` |
| 제공 컴포넌트 | `EventRepository` |
| 소비 컴포넌트 | `EventRewardService` |

#### 3.3.2 Data Elements (데이터 요소)

**메서드 카테고리별 분류 (총 10 메서드):**

| 카테고리 | 메서드 수 | 대표 메서드 |
|---------|--------|----------|
| 이벤트 조회 | 2 | `findActiveEvents()`, `findEventById()` |
| 키워드 검증 | 1 | `findKeywordByEventAndKeyword()` |
| 참여 이력 | 3 | `insertParticipation()`, `findParticipation()`, `findParticipationHistory()` |
| 쿠폰 처리 | 2 | `findCouponByCode()`, `updateCouponStatus()` |
| 출석 처리 | 2 | `findAttendanceToday()`, `getConsecutiveAttendanceDays()` |

**소유권 검증 패턴 (OWASP API1:2023 BOLA 대응):**

```sql
-- 참여 이력 조회 시 소유권 조건 내장
WHERE account_id = :account_id AND event_id = :event_id
```

#### 3.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder 우선. 연속 출석일 수 계산은 `$db->query()` + named binding (CTE/Window Function) |
| DB 연결 | Aurora MySQL (RDS Proxy, IAM Auth) |
| charset | utf8mb4 (서버/DB/테이블 전 레벨) |

#### 3.3.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| 레코드 미존재 | `null` 반환 (예외 없음) |
| DB UNIQUE 제약 위반 | CI4 Database Exception 전파 → Service에서 `ConflictException`으로 변환 |
| 쿼리 실패 | CI4 Database Exception 전파 → Controller에서 500 `INTERNAL` 응답 |

#### 3.3.5 Data Flow (데이터 흐름)

```
EventRewardService
  └─ EventRepository::findKeywordByEventAndKeyword($eventId, $keyword)
        └─ $db->table('tb_event_keyword')
              ->where('event_id', $eventId)
              ->where('LOWER(keyword) =', strtolower($keyword))  [case-insensitive]
              ->get()->getRowArray()

EventRewardService
  └─ EventRepository::getConsecutiveAttendanceDays($accountId, $eventId)
        └─ $db->query("WITH consecutive AS (...) SELECT COUNT(*) ...", [$accountId, $eventId])
```

**PHP 시그니처:**

```php
<?php

declare(strict_types=1);

namespace App\Modules\Event\Interfaces;

interface EventRepositoryInterface
{
    /**
     * 현재 활성 이벤트 목록 조회 (종료된 이벤트 제외).
     *
     * @return array<int, array<string, mixed>>
     */
    public function findActiveEvents(): array;

    /**
     * 이벤트 ID로 단건 조회.
     *
     * @param  int $eventId 이벤트 ID
     * @return array<string, mixed>|null
     */
    public function findEventById(int $eventId): array|null;

    /**
     * 이벤트 ID와 키워드로 키워드 레코드 조회 (case-insensitive).
     *
     * @param  int    $eventId 이벤트 ID
     * @param  string $keyword 입력 키워드
     * @return array<string, mixed>|null
     */
    public function findKeywordByEventAndKeyword(int $eventId, string $keyword): array|null;

    /**
     * 이벤트 참여 이력 삽입.
     *
     * @param  array<string, mixed> $data 참여 데이터 (account_id, event_id, keyword, idempotency_key 등)
     * @return bool
     */
    public function insertParticipation(array $data): bool;

    /**
     * 계정 ID와 이벤트 ID로 참여 여부 조회.
     *
     * @param  int $accountId 계정 ID
     * @param  int $eventId   이벤트 ID
     * @return array<string, mixed>|null
     */
    public function findParticipation(int $accountId, int $eventId): array|null;

    /**
     * 계정 ID의 전체 이벤트 참여 이력 조회.
     *
     * @param  int $accountId 계정 ID
     * @return array<int, array<string, mixed>>
     */
    public function findParticipationHistory(int $accountId): array;

    /**
     * 쿠폰 코드로 쿠폰 레코드 조회.
     *
     * @param  string $couponCode 쿠폰 코드
     * @return array<string, mixed>|null
     */
    public function findCouponByCode(string $couponCode): array|null;

    /**
     * 쿠폰 상태 변경.
     *
     * @param  int    $couponId 쿠폰 ID
     * @param  string $status   변경할 상태 ('used', 'expired' 등)
     * @return bool
     */
    public function updateCouponStatus(int $couponId, string $status): bool;

    /**
     * 당일 출석 여부 조회 (UTC 기준 00:00~23:59).
     *
     * @param  int $accountId 계정 ID
     * @param  int $eventId   이벤트 ID
     * @return array<string, mixed>|null
     */
    public function findAttendanceToday(int $accountId, int $eventId): array|null;

    /**
     * 연속 출석일 수 계산 (CTE 또는 Window Function 사용).
     *
     * @param  int $accountId 계정 ID
     * @param  int $eventId   이벤트 ID
     * @return int 연속 출석일 수
     */
    public function getConsecutiveAttendanceDays(int $accountId, int $eventId): int;
}
```

---

### IF-INT-004: RouletteRepositoryInterface

#### 3.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-004 |
| 인터페이스명 | RouletteRepositoryInterface |
| 파일 경로 | `app/Modules/Event/Interfaces/RouletteRepositoryInterface.php` |
| 제공 컴포넌트 | `RouletteRepository` |
| 소비 컴포넌트 | `RouletteService` |

#### 3.4.2 Data Elements (데이터 요소)

**메서드 목록 (총 4 메서드):**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `findUserVipGrade($accountId)` | int | string | VIP 등급 조회 (`A`~`E`). `tb_account.vip_grade` 참조 |
| `countTodaySpins($accountId, $eventId)` | int, int | int | 당일 스핀 횟수 조회 (UTC 기준) |
| `insertRouletteHistory(array $data)` | array | bool | 룰렛 당첨 이력 삽입 |
| `findRouletteHistory($accountId)` | int | array | 룰렛 당첨 이력 조회 |

**`insertRouletteHistory()` — 입력 데이터 구조:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `account_id` | int | 계정 ID |
| `event_id` | int | 이벤트 ID |
| `segment_index` | int | 당첨 세그먼트 (0~4) |
| `vip_grade` | string | 적용 VIP 등급 (`A`~`E`) |
| `reward_type` | string\|null | 보상 유형 |
| `reward_amount` | int | 보상 수량 |
| `regist_date` | string | UTC DateTimeImmutable 문자열 |

#### 3.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder. 집계 쿼리는 `$db->query()` + named binding |
| DB 연결 | Aurora MySQL (RDS Proxy, IAM Auth) |

#### 3.4.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| VIP 등급 미존재 (신규 회원 등) | 기본값 `'E'` 반환 |
| 이력 삽입 실패 | CI4 Database Exception 전파 → 트랜잭션 롤백 |
| 이력 조회 결과 없음 | 빈 배열 반환 |

#### 3.4.5 Data Flow (데이터 흐름)

```
RouletteService
  └─ RouletteRepository::findUserVipGrade($accountId)
        └─ $db->table('tb_account')
              ->select('vip_grade')
              ->where('ac_id', $accountId)
              ->get()->getRow()?->vip_grade ?? 'E'

RouletteService
  └─ RouletteRepository::countTodaySpins($accountId, $eventId)
        └─ $db->query(
              "SELECT COUNT(*) AS cnt FROM tb_roulette_history
               WHERE account_id = :account_id:
               AND event_id = :event_id:
               AND DATE(regist_date) = DATE(UTC_TIMESTAMP())",
              ['account_id' => $accountId, 'event_id' => $eventId]
           )
```

**PHP 시그니처:**

```php
<?php

declare(strict_types=1);

namespace App\Modules\Event\Interfaces;

interface RouletteRepositoryInterface
{
    /**
     * 사용자 VIP 등급 조회 (A~E). 미존재 시 'E' 반환.
     *
     * @param  int $accountId 계정 ID
     * @return string VIP 등급 문자열 ('A'|'B'|'C'|'D'|'E')
     */
    public function findUserVipGrade(int $accountId): string;

    /**
     * 당일 스핀 횟수 조회 (UTC 기준).
     *
     * @param  int $accountId 계정 ID
     * @param  int $eventId   이벤트 ID
     * @return int 당일 스핀 횟수
     */
    public function countTodaySpins(int $accountId, int $eventId): int;

    /**
     * 룰렛 당첨 이력 삽입.
     *
     * @param  array<string, mixed> $data 이력 데이터 (account_id, event_id, segment_index, vip_grade 등)
     * @return bool
     */
    public function insertRouletteHistory(array $data): bool;

    /**
     * 계정 ID의 룰렛 당첨 이력 조회 (최신순).
     *
     * @param  int $accountId 계정 ID
     * @return array<int, array<string, mixed>>
     */
    public function findRouletteHistory(int $accountId): array;
}
```

---

## 4. External Interfaces (외부 인터페이스)

MIL-STD-498 IDD §4 — Event 모듈의 외부 의존성은 Shared 모듈 DI 인터페이스로만 구성된다. 직접 외부 API(HTTP) 호출 없음.

---

### IF-EXT-001: CoinServiceInterface (Shared 모듈)

#### 4.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | CoinServiceInterface |
| 파일 경로 | `app/Modules/Shared/Interfaces/CoinServiceInterface.php` |
| 제공 컴포넌트 | Shared/CoinService |
| 소비 컴포넌트 | `EventRewardService`, `RouletteService` |

#### 4.1.2 Data Elements (데이터 요소)

**`addCoin()` — 입력:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$accountId` | int | Y | 코인을 지급받을 계정 ID |
| `$amount` | int | Y | 지급 코인 수량 (> 0) |
| `$reason` | string | N | 지급 사유 (로그용, 예: `'event_reward'`) |

**`addCoin()` — 출력:**

- 성공: `true`
- 실패: `false` 또는 Exception 전파

#### 4.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | Shared 모듈 `Config/Services.php` |
| 트랜잭션 | 호출자(EventRewardService)의 트랜잭션 컨텍스트 내에서 실행 |

#### 4.1.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| 코인 지급 실패 | Exception 전파 → 호출자 트랜잭션 롤백 |
| 잔액 조회 실패 | Exception 전파 |

#### 4.1.5 Data Flow (데이터 흐름)

```
EventRewardService (transaction context)
  └─ CoinService::addCoin($accountId, $rewardAmount, 'event_reward')
        └─ UPDATE tb_account SET coin_balance = coin_balance + :amount WHERE ac_id = :accountId
```

---

### IF-EXT-002: CouponServiceInterface (Shared 모듈)

#### 4.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-002 |
| 인터페이스명 | CouponServiceInterface |
| 파일 경로 | `app/Modules/Shared/Interfaces/CouponServiceInterface.php` |
| 제공 컴포넌트 | Shared/CouponService |
| 소비 컴포넌트 | `EventRewardService` |

#### 4.2.2 Data Elements (데이터 요소)

**`issueCoupon()` — 입력:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$accountId` | int | Y | 쿠폰을 발급받을 계정 ID |
| `$couponCode` | string | Y | 쿠폰 코드 (RENEWAL_COUPON_CODES 또는 TIER*) |
| `$expiresAt` | string\|null | N | 만료일 (UTC ISO 8601). null이면 이벤트 기본 설정 적용 |

**`issueCoupon()` — 출력:**

- 성공: `array{couponId: int, couponCode: string, expiresAt: string}`
- 실패: Exception 전파

#### 4.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | Shared 모듈 `Config/Services.php` |
| 트랜잭션 | 호출자(EventRewardService)의 트랜잭션 컨텍스트 내에서 실행 |

#### 4.2.4 Error Handling (에러 처리)

| 에러 조건 | 처리 방식 |
|---------|---------|
| 쿠폰 발급 실패 | Exception 전파 → 호출자 트랜잭션 롤백 |
| 이미 사용된 쿠폰 코드 | Exception 전파 → Controller 409 `CONFLICT` |

#### 4.2.5 Data Flow (데이터 흐름)

```
EventRewardService (transaction context, 갱신 쿠폰 예시)
  └─ CouponService::issueCoupon(
         $accountId,
         $couponCode,      // RENEWAL_COUPON_CODES에서 선택
         $expiresAt        // DateTimeImmutable::modify('+30 days')
     )
        └─ INSERT INTO tb_coupon (account_id, coupon_code, expires_at, status='unused')
```

---

## 5. Events and Signals (이벤트 및 신호 계약)

### 5.1 Event Participation Events (이벤트 참여 신호)

| 이벤트 | 발생 조건 | 처리 방식 | 수신자 |
|--------|---------|---------|--------|
| 키워드 이벤트 참여 성공 | `insertParticipation()` 성공 + 보상 지급 완료 | 참여 이력 DB 기록 (tb_event_participation) | 없음 (동기 처리) |
| 쿠폰 이벤트 참여 성공 | `updateCouponStatus('used')` + 보상 지급 | 쿠폰 상태 변경 + 참여 이력 | 없음 |
| 출석 이벤트 완료 | `insertParticipation()` + 연속일 계산 완료 | 출석 이력 + 보상 지급 | 없음 |
| 충전 이벤트 완료 | 멱등키 기록 + tier 보상 지급 | 참여 이력 + 멱등키 기록 | 없음 |
| 룰렛 스핀 완료 | `insertRouletteHistory()` + 보상 지급 | 룰렛 이력 + 보상 지급 | 없음 |

### 5.2 Signal: DateTimeImmutable 사용 강제

모든 날짜/시간 생성은 `DateTimeImmutable`를 사용한다. `date()`, `time()` 사용 금지.

```php
// 갱신 쿠폰 만료일 생성 예시
$expiresAt = (new DateTimeImmutable())->modify('+30 days')->format('Y-m-d H:i:s');

// 룰렛 이력 등록일 예시
$registDate = (new DateTimeImmutable())->format('Y-m-d H:i:s');
```

### 5.3 Signal: Outbox Pattern (해당 없음)

Event 모듈은 크로스 도메인 이벤트를 발행하지 않으므로 Outbox 패턴(`global_sync_pub_log`)을 사용하지 않는다. 보상 지급은 Shared 모듈 DI 호출로 동기 처리된다.

---

## 6. Error Handling Contract (에러 처리 계약)

### 6.1 표준 에러 응답 형식

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "에러 메시지"
  }
}
```

### 6.2 Event 모듈 에러 코드 전체 목록

| HTTP 상태 | 에러 코드 | 발생 인터페이스 | 발생 상황 |
|---------|---------|-------------|---------|
| 400 | `INVALID_INPUT` | IF-INT-001, IF-INT-002 | 입력값 유효성 검증 실패, 유효하지 않은 키워드/쿠폰, 이벤트 기간 외 참여 |
| 401 | `UNAUTHORIZED` | AuthFilter | JWT 인증 실패 |
| 403 | `FORBIDDEN` | AuthFilter | 접근 권한 없음 |
| 404 | `NOT_FOUND` | IF-INT-001 | 이벤트 또는 리소스 미존재 |
| 409 | `CONFLICT` | IF-INT-001, IF-INT-002 | 중복 참여, 이미 사용된 쿠폰, 당일 출석 완료, 멱등키 중복, 이미 유효한 갱신 쿠폰 보유 |
| 429 | `CONFLICT` | IF-INT-002 | 일일 룰렛 참여 횟수 초과 |
| 500 | `INTERNAL` | 전체 | DB 오류, 예상치 못한 서버 내부 오류 |

> **참고**: HTTP 429 응답에 에러 코드 `CONFLICT`를 사용하는 것은 레거시 호환성 유지 결정 (event-srs.md v2.0 §3, FR-EVT-007 참조).

### 6.3 Error Propagation Chain (에러 전파 체인)

```
EventRepository (DB Exception)
  -> EventRewardService (ConflictException / InvalidInputException 으로 변환)
  -> EventController (HTTP 응답 코드로 변환)
  -> Client (JSON 에러 응답)
```

### 6.4 Transaction Rollback Contract (트랜잭션 롤백 계약)

| 작업 | 롤백 트리거 | 롤백 범위 |
|------|---------|---------|
| 키워드/쿠폰/출석/충전 이벤트 참여 | 보상 지급 실패, DB 오류 | 참여 이력 기록 + 보상 지급 전체 |
| 룰렛 스핀 | 이력 삽입 실패, 보상 지급 실패 | 룰렛 이력 + 보상 지급 전체 |
| 갱신 쿠폰 발급 | 쿠폰 DB 저장 실패 | 쿠폰 발급 전체 |

---

## 7. Data Formats and Encoding (데이터 포맷 및 인코딩)

### 7.1 API 요청 포맷

| 항목 | 명세 |
|------|------|
| Content-Type | `application/json; charset=utf-8` |
| 인증 | `hc_access` 쿠키 (HttpOnly, JWT) |
| CSRF | `X-CSRF-TOKEN` 헤더 (POST EP 필수) |
| 프로토콜 | `X-Forwarded-Proto: https` (모든 요청 필수) |

### 7.2 이벤트 목록 응답 포맷

```json
{
  "data": [
    {
      "eventId": 1,
      "eventName": "봄맞이 키워드 이벤트",
      "eventType": "keyword",
      "startDate": "2026-04-01T00:00:00Z",
      "endDate": "2026-04-30T23:59:59Z",
      "status": "active",
      "createdAt": "2026-03-25T10:00:00Z"
    }
  ]
}
```

### 7.3 보상 응답 포맷

```json
{
  "data": {
    "rewardType": "coin",
    "rewardAmount": 300,
    "couponCode": null
  }
}
```

### 7.4 출석 이벤트 응답 포맷

```json
{
  "data": {
    "consecutiveDays": 5,
    "rewardType": "coin",
    "rewardAmount": 100
  }
}
```

### 7.5 충전 이벤트 응답 포맷

```json
{
  "data": {
    "tier": 3,
    "rewardType": "coin",
    "rewardAmount": 300,
    "couponCode": "TIER3"
  }
}
```

### 7.6 룰렛 결과 응답 포맷

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

### 7.7 갱신 쿠폰 응답 포맷

```json
{
  "data": {
    "couponCode": "RENEW-ABCD1234",
    "expiresAt": "2026-05-15T00:00:00Z"
  }
}
```

### 7.8 DB → API camelCase 필드 매핑

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
| `updated_at` | `updatedAt` |

### 7.9 DI 등록 코드

```php
// app/Modules/Event/Config/Services.php
$services->bind(
    \App\Modules\Event\Interfaces\EventRewardServiceInterface::class,
    \App\Modules\Event\Services\EventRewardService::class
);

$services->bind(
    \App\Modules\Event\Interfaces\RouletteServiceInterface::class,
    \App\Modules\Event\Services\RouletteService::class
);

$services->bind(
    \App\Modules\Event\Interfaces\EventRepositoryInterface::class,
    \App\Modules\Event\Repositories\EventRepository::class
);

$services->bind(
    \App\Modules\Event\Interfaces\RouletteRepositoryInterface::class,
    \App\Modules\Event\Repositories\RouletteRepository::class
);
```

---

## 8. 타당성 검토 (Feasibility Review)

> 근거: PHP 공식 문서 (`random_int()`), OWASP API Security Top 10 2023, CLAUDE.md 보안 정책, MIL-STD-498 §DI-IPSC-81436

| 검토 ID | 주제 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|------|------|------|------|-----------|
| FEA-IDD-001 | PHP 시그니처에 Union Type + PHPDoc `@throws` 강제 | 채택 | PHP 8.0+ Union Type(`array\|null`)과 `declare(strict_types=1)` 조합으로 컴파일 타임 타입 안전성 확보. `@throws` 문서화로 호출자가 예외 처리 로직 명시 가능 — OWASP API9:2023 (부적절한 인벤토리 관리) 대응 | PHPDoc 전용 타입 힌트 | Union Type: 엄격한 타입 검사. PHPDoc: 런타임 검사 없음 |
| FEA-IDD-002 | Shared 모듈 DI 인터페이스 경유 보상 지급 | 채택 | Event 모듈이 Shared 모듈 구체 클래스를 직접 참조하면 모듈 간 결합도 증가. Interface Only 원칙(CLAUDE.md) — `service()` DI 강제로 테스트 시 Mock 주입 가능 | 직접 클래스 참조 | DI: 느슨한 결합, 테스트 용이. 직접 참조: 간단하지만 결합도 높음 |
| FEA-IDD-003 | 내부 4 + 외부 2 인터페이스 구성 | 채택 | Event 모듈은 외부 SaaS API(SendBird, FCM 등)에 직접 의존하지 않음. Shared CoinService/CouponService를 외부 인터페이스로 분류 — 경계 명확화. 인터페이스 수 최소화로 복잡성 억제 | Chat 모듈 수준의 6 내부 + 4 외부 | 최소 인터페이스: 낮은 복잡성, 낮은 결합. 세분화: 테스트 용이, 인터페이스 수 증가 |
| FEA-IDD-004 | 429 응답에 `CONFLICT` 에러 코드 사용 | 레거시 호환 유지 | 일일 룰렛 횟수 초과는 의미상 `TOO_MANY_REQUESTS`가 정확하나, 기존 프론트엔드 클라이언트가 `CONFLICT`로 처리하도록 구현되어 있음. 변경 시 클라이언트 수정 필요 — 허용 가능한 트레이드오프 | `TOO_MANY_REQUESTS` 코드 | 레거시 호환: 안정, 의미 불일치. 변경: 정확하지만 클라이언트 수정 필요 |

---

## 9. 변경 영향 기록 (Change Impact Log)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|---------|---------|--------|---------|
| MIL-STD-498 IDD 구조 전환 (v1.0 → v2.0) | 문서 전체 재구성 | 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 구조화. 인터페이스 계약이 단일 관점으로 기술되어 소비자·제공자 모두 참조 가능 | MIL-STD-498 §DI-IPSC-81436 표준 준수 |
| 내부 인터페이스 4개 5-subsection 명세 (§3) | 신규 구성 | IF-INT-001~004 각각 식별자/데이터/통신/에러/흐름 명시. PHP 시그니처 + PHPDoc `@throws` 포함. 구현자와 테스터의 계약 명확화 | MIL-STD-498 내부 인터페이스 명세 요구 |
| 외부 인터페이스 Shared 모듈 DI 2개 명세 (§4) | 신규 섹션 | CoinServiceInterface, CouponServiceInterface 데이터/통신/에러/흐름 명시. Event 모듈의 의존성 경계 가시화 | MIL-STD-498 외부 인터페이스 명세 요구 |
| 이벤트 및 신호 계약 (§5) | 신규 섹션 | DateTimeImmutable 강제, Outbox Pattern 해당 없음 명시. 프로젝트 지침 준수 사항 IDD 레벨에서 계약화 | MIL-STD-498 Events and Signals 요구 |
| 에러 처리 계약 전체 목록 (§6) | 신규 섹션 | HTTP 상태코드 ↔ 에러 코드 ↔ 발생 인터페이스 3-way 매핑. 트랜잭션 롤백 계약 명시. 429/CONFLICT 레거시 이유 문서화 | 에러 처리 일관성 및 추적성 강화 |
| 데이터 포맷 섹션 확장 (§7) | 기존 §4 확장 | 7개 응답 포맷 JSON 예시 추가 (이벤트 목록/보상/출석/충전/룰렛/갱신쿠폰). DI 등록 코드 포함 | 구현자의 계약 참조 편의성 향상 |
| Feasibility Review 4건 (§8) | 신규 섹션 | PHP Union Type, DI 원칙, 인터페이스 수 결정, 레거시 에러 코드 근거 명시. 설계 결정에 공식 문서 근거 제공 | 프로젝트 지침 — 타당성 검토 섹션 필수 |
| Traceability Matrix (§10) | 신규 섹션 | SRS FR/NFR 12건 ↔ IDD 인터페이스 1:1 매핑. QA 추적성 확보 | 프로젝트 지침 — 추적성 매트릭스 필수 |
| 한국어+영문 병기 | 전체 섹션 제목 | 섹션 제목 영문+한글 병기. 국제 표준 준수 + 내부 팀 가독성 확보 | 프로젝트 지침 — IEEE 표준 전환 |

---

## 10. 요구사항 추적성 매트릭스 (Traceability Matrix)

SRS 요구사항 ↔ IDD 인터페이스 매핑:

| SRS 요구사항 ID | 설명 | 인터페이스 (IDD) | 섹션 |
|--------------|------|--------------|------|
| FR-EVT-001 | 이벤트 목록 조회 | IF-INT-001 `getEventList()`, IF-INT-003 `findActiveEvents()` | §3.1, §3.3 |
| FR-EVT-002 | 키워드 이벤트 참여 | IF-INT-001 `validateAndRewardKeyword()`, IF-INT-003 `findKeywordByEventAndKeyword()`, `insertParticipation()` | §3.1, §3.3 |
| FR-EVT-003 | 쿠폰 이벤트 참여 | IF-INT-001 `validateAndRewardCoupon()`, IF-INT-003 `findCouponByCode()`, `updateCouponStatus()` | §3.1, §3.3 |
| FR-EVT-004 | 출석 이벤트 처리 | IF-INT-001 `processAttendance()`, IF-INT-003 `findAttendanceToday()`, `getConsecutiveAttendanceDays()` | §3.1, §3.3 |
| FR-EVT-005 | 코인 충전 이벤트 (7 tier) | IF-INT-001 `processChargeEvent()`, IF-EXT-001 `addCoin()` | §3.1, §4.1 |
| FR-EVT-006 | 갱신 쿠폰 발급 | IF-INT-001 `issueRenewalCoupon()`, IF-EXT-002 `issueCoupon()` | §3.1, §4.2 |
| FR-EVT-007 | 룰렛 이벤트 (VIP 확률) | IF-INT-002 `spin()`, `getWeightedRandomSegment()`, IF-INT-004 `findUserVipGrade()`, `insertRouletteHistory()` | §3.2, §3.4 |
| NFR-EVT-001 | 중복 참여 방지 | IF-INT-003 UNIQUE 제약 + IF-INT-001 멱등키 계약 (§6.4 트랜잭션 롤백) | §3.3, §6.4 |
| NFR-EVT-002 | 보상 한도 제어 | IF-INT-001 `processChargeEvent()` 한도 검증 | §3.1 |
| NFR-EVT-003 | 응답 성능 p95 | IF-INT-003 Query Builder 우선, `$db->query()` CTE 사용 (§3.3.3) | §3.3 |
| NFR-EVT-004 | 보안/확률 조작 방지 | IF-INT-002 `getWeightedRandomSegment()` — `random_int()` CSPRNG (§3.2.3), CSRF 필터 체인 | §3.2 |
| NFR-EVT-005 | 감사 로그 | IF-INT-003 `insertParticipation()`, IF-INT-004 `insertRouletteHistory()` 영구 보존 | §3.3, §3.4 |

---

## 11. Document History (문서 이력)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|---------|--------|
| 2026-04-15 | 1.0.0 | 최초 작성 — Event Module IDD | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 IDD 전환. 내부 인터페이스 4개(IF-INT-001~004) 5-subsection 명세. 외부 인터페이스 2개(IF-EXT-001~002) 신설. 이벤트 계약, 에러 처리 계약, 데이터 포맷 확장, Feasibility Review 4건, Traceability Matrix 12건 추가. 한국어+영문 병기 | jypark |
