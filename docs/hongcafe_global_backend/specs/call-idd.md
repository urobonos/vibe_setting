---
문서명: Call — Interface Design Document
문서 ID: call-idd
버전: v2.0
적용 표준: MIL-STD-498 (Interface Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Call Module (HongCafe Global Backend)
관련 문서: call-sdd.md, call-srs.md
---

# Call — Interface Design Document

> version: 2.0 | standard: MIL-STD-498 IDD | lastUpdated: 2026-04-15 | module: Call

---

## 1. Scope (범위)

### 1.1 Identification (식별)

본 문서는 HongCafe Global Backend Call 모듈의 인터페이스 설계를 MIL-STD-498 Interface Design Description (IDD) 표준에 따라 명세한다.

| 항목 | 내용 |
|------|------|
| 문서 ID | call-idd |
| 대상 시스템 | Call Module — HongCafe Global Backend |
| 기반 SDD | `call-sdd.md` v2.0 |
| 인터페이스 총수 | 내부 10개 / 외부 2개 |
| EP 총수 | 66개 (Call 14 + Callee 39 + PBX 13) |

### 1.2 System Overview (시스템 개요)

Call 모듈은 HongCafe Global Backend Modular Monolith 아키텍처 내에서 통화 연결·종료·정산, PBX 연동, 상담사 대시보드·컨텐츠·알람·즐겨찾기, 채팅·견적 처리를 담당한다. Hermes PBX(060 전화), FCM(푸시 알림) 외부 시스템과 연동하며, Outbox 패턴으로 Coin/Member/Analytics 모듈에 크로스 도메인 이벤트를 발행한다.

### 1.3 Document Overview (문서 개요)

본 IDD는 MIL-STD-498 §DI-IPSC-81436 기준에 따라 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 기술한다.

| 섹션 | 내용 |
|------|------|
| §3 | 내부 인터페이스 10개 (IF-INT-001~010) — PHP 시그니처 포함 |
| §4 | 외부 인터페이스 2개 (IF-EXT-001~002) — 프로토콜/인증/타임아웃/재시도 명세 |
| §5 | 이벤트 계약 (Events and Signals) — Outbox Payload 포함 |
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
| call-srs.md v2.0 | `docs/specs/call-srs.md` |
| call-sdd.md v2.0 | `docs/specs/call-sdd.md` |
| RFC 7231 — HTTP/1.1 Semantics and Content | IETF |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |

---

## 3. Internal Interfaces (내부 인터페이스)

MIL-STD-498 IDD §3 — 각 내부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-INT-001: ICallConnectionServiceInterface

#### 3.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | ICallConnectionServiceInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICallConnectionServiceInterface.php` |
| 제공 컴포넌트 | `CallConnectionService` |
| 소비 컴포넌트 | `CallController` |

#### 3.1.2 Data Elements (데이터 요소)

**checkEligibility 입력:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$callerId` | int | Y | Caller 계정 ID |
| `$calleeId` | int | Y | Callee 계정 ID |

**checkEligibility 출력 — `EligibilityResult` VO:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `isEligible` | bool | 통화 가능 여부 |
| `reason` | ?string | 불가 사유: `INSUFFICIENT_COIN` / `CALLEE_UNAVAILABLE` / `null` |

**initiate 입력:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `$callerId` | int | Y | Caller 계정 ID |
| `$calleeId` | int | Y | Callee 계정 ID |
| `$idempotencyKey` | string | Y | 멱등키 (`X-Idempotency-Key` 헤더) |

**initiate 출력 — `CallInitResult` VO:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `callId` | int | 생성된 `tb_call_result.cr_code` |
| `pbxCallId` | string | Hermes PBX 통화 ID |

#### 3.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Call/Config/Services.php` |
| 패턴 | Service Layer — Controller → Service |

#### 3.1.4 Error Handling (에러 처리)

| 예외 클래스 | HTTP | 에러 코드 | 발생 조건 |
|-----------|------|---------|---------|
| `InsufficientCoinException` | 400 | `INSUFFICIENT_COIN` | 코인 잔액 < `CALL_MIN_COIN`(5,000) |
| `CalleeUnavailableException` | 409 | `CALLEE_UNAVAILABLE` | 상담사 오프라인/통화중 |
| `DuplicateCallException` | 409 | `CONFLICT` | 동일 멱등키 재요청 |
| `PbxConnectionException` | 503 | `PBX_UNAVAILABLE` | Hermes API 오류/타임아웃 |

#### 3.1.5 Data Flow (데이터 흐름)

```
CallController::callStart()
  └─ CallConnectionService::checkEligibility(callerId, calleeId)
        ├─ CallRepository::getCoinBalance(callerId)        → CALL_MIN_COIN 검증
        └─ PbxService::getCalleeAvailability(calleeId)    → Hermes 상태 조회

CallController::callStart()
  └─ CallConnectionService::initiate(callerId, calleeId, idempotencyKey)
        ├─ CallRepository::existsByIdempotencyKey(key)    → 중복 확인
        ├─ CallRepository::insert(data)                   → tb_call_result INSERT
        └─ PbxService::requestConnection(calleeId, callerNumber)
              └─ Hermes API: POST /api/v1/calls/connect
```

**PHP 시그니처:**

```php
interface ICallConnectionServiceInterface
{
    /**
     * 통화 연결 전 Caller/Callee 적격성 검증.
     * @throws InsufficientCoinException  코인 잔액 < CALL_MIN_COIN(5000)
     * @throws CalleeUnavailableException 상담사 오프라인/통화중
     */
    public function checkEligibility(int $callerId, int $calleeId): EligibilityResult;

    /**
     * 통화 시작 처리 — tb_call_result Insert + Hermes 연결 트리거.
     * @throws DuplicateCallException    동일 멱등키 재요청
     * @throws PbxConnectionException    Hermes API 호출 실패
     */
    public function initiate(int $callerId, int $calleeId, string $idempotencyKey): CallInitResult;

    /** Hermes Callback 수신 후 통화 상태 On으로 갱신. */
    public function confirmConnection(int $callId, string $pbxCallId): void;

    /** 통화 연결 실패 처리 — 상태 Miss 전환. */
    public function markMissed(int $callId, string $reason): void;
}

final class EligibilityResult
{
    public function __construct(
        public readonly bool    $isEligible,
        public readonly ?string $reason = null
    ) {}
}

final class CallInitResult
{
    public function __construct(
        public readonly int    $callId,
        public readonly string $pbxCallId
    ) {}
}
```

---

### IF-INT-002: ICallCloseServiceInterface

#### 3.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | ICallCloseServiceInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICallCloseServiceInterface.php` |
| 제공 컴포넌트 | `CallCloseService` |
| 소비 컴포넌트 | `PbxController` (Hermes Callback 수신 시) |

#### 3.2.2 Data Elements (데이터 요소)

**close 입력:**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$callId` | int | 통화 기록 ID (`tb_call_result.cr_code`) |
| `$endTime` | DateTimeImmutable | 통화 종료 시각 (UTC) |

**close 출력 — `CloseResult` VO:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `callId` | int | 통화 기록 ID |
| `status` | string | `'closed'` / `'under30'` |
| `durationSeconds` | int | 총 통화 시간(초) |
| `coinDeducted` | int | 차감 코인 수 (30초 이하 시 0) |
| `eventsProcessed` | bool | 이벤트 처리(Outbox 발행) 완료 여부 |

**calculateCoinDeduction 입력:**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$durationSeconds` | int | 총 통화 시간(초) |
| `$ratePerTerm` | int | 30초당 코인 요금 |

**calculateCoinDeduction 출력:** `int` — 차감 코인 수 (FREE_DURATION 이하이면 0)

**코인 차감 공식:** `ceil((durationSeconds - 30) / 30) × ratePerTerm`

#### 3.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| 트랜잭션 경계 | `close()` 내부에서 DB 트랜잭션 시작. 코인 차감 + Outbox INSERT + 상태 갱신을 원자적 수행 |
| DI 등록 | `app/Modules/Call/Config/Services.php` |

#### 3.2.4 Error Handling (에러 처리)

| 예외 클래스 | HTTP | 에러 코드 | 발생 조건 |
|-----------|------|---------|---------|
| `CallNotFoundException` | 404 | `NOT_FOUND` | 존재하지 않는 통화 기록 |
| `InvalidCallStatusException` | 400 | `INVALID_CALL_STATUS` | 이미 종료된 통화 재종료 시도 |

#### 3.2.5 Data Flow (데이터 흐름)

```
PbxController::callEnd() [Hermes Callback]
  └─ CallCloseService::close(callId, endTime)
        ├─ CallRepository::findById(callId)              → 존재·상태 검증
        ├─ CallCloseService::calculateCoinDeduction(...)
        ├─ [DB 트랜잭션 시작]
        │     ├─ CallCloseRepository::deductCoin(callerId, amount, callId)
        │     ├─ CallCloseRepository::publishOutboxEvent('call.closed', payload)
        │     └─ CallRepository::updateStatus(callId, 'closed', {end_time, duration_sec, coin_deducted})
        └─ [트랜잭션 커밋] → CloseResult 반환
```

**PHP 시그니처:**

```php
interface ICallCloseServiceInterface
{
    /**
     * 통화 종료 처리 — 정산, Outbox 발행, 이벤트 처리.
     * @throws CallNotFoundException      존재하지 않는 통화 기록
     * @throws InvalidCallStatusException 이미 종료된 통화
     */
    public function close(int $callId, DateTimeImmutable $endTime): CloseResult;

    /** 코인 차감량 계산 (순수 함수). */
    public function calculateCoinDeduction(int $durationSeconds, int $ratePerTerm): int;

    /** 이벤트 처리 — Payback, Special Price, Roulette, First-call Coupon Outbox 발행. */
    public function processEvents(int $callId, int $callerId, int $calleeId): void;

    /** 30초 미만 종료 처리 — Under30 상태 전환 (코인 차감 없음). */
    public function markUnder30(int $callId): void;
}

final class CloseResult
{
    public function __construct(
        public readonly int    $callId,
        public readonly string $status,
        public readonly int    $durationSeconds,
        public readonly int    $coinDeducted,
        public readonly bool   $eventsProcessed
    ) {}
}
```

---

### IF-INT-003: ICalleeActivityServiceInterface

#### 3.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-003 |
| 인터페이스명 | ICalleeActivityServiceInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICalleeActivityServiceInterface.php` |
| 제공 컴포넌트 | `CalleeActivityService` |
| 소비 컴포넌트 | `CalleeController` |

#### 3.3.2 Data Elements (데이터 요소)

**getDashboard 출력 — `DashboardData` VO:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `today` | array | `{callCount, totalDurationSeconds, totalRevenue}` |
| `week` | array | 주간 집계 |
| `month` | array | 월간 집계 |

**getActivityStats / getRevenueStats 입력:**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$calleeId` | int | Callee 계정 ID |
| `$period` | string | `'today'` / `'week'` / `'month'` |

**getCallHistory 출력 — `PaginatedResult`:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `data` | array | 통화 이력 항목 배열 |
| `meta` | array | `{currentPage, perPage, total, lastPage}` |

#### 3.3.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). DI 등록: `Call/Config/Services.php`.

#### 3.3.4 Error Handling (에러 처리)

DB 쿼리 실패 시 CI4 Database Exception 전파. Controller에서 500 `INTERNAL` 응답.

#### 3.3.5 Data Flow (데이터 흐름)

```
CalleeController::getDashboard()
  └─ CalleeActivityService::getDashboard(calleeId)
        ├─ CalleeRepository::getCallCountByPeriod(calleeId, startDate, endDate)
        ├─ CalleeRepository::getTotalDurationByPeriod(calleeId, startDate, endDate)
        └─ CalleeRepository::getRevenueByPeriod(calleeId, startDate, endDate)
```

**PHP 시그니처:**

```php
interface ICalleeActivityServiceInterface
{
    public function getDashboard(int $calleeId): DashboardData;
    public function getActivityStats(int $calleeId, string $period): ActivityStats;
    public function getRevenueStats(int $calleeId, string $period): RevenueStats;
    public function getCallHistory(int $calleeId, int $page, int $perPage): PaginatedResult;
}
```

---

### IF-INT-004: ICalleeManageServiceInterface

#### 3.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-004 |
| 인터페이스명 | ICalleeManageServiceInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICalleeManageServiceInterface.php` |
| 제공 컴포넌트 | `CalleeManageService` |
| 소비 컴포넌트 | `CalleeController` |

#### 3.4.2 Data Elements (데이터 요소)

| 메서드 | 핵심 입력 | 출력 | 예외 |
|-------|---------|------|------|
| `updatePassword` | `$calleeId`, `$currentPassword`, `$newPassword` | void | `InvalidPasswordException` (현재 비밀번호 불일치) |
| `updateOnlineStatus` | `$calleeId`, `$isOnline: bool` | void | — |
| `updateAlarmSettings` | `$calleeId`, `AlarmSettings $settings` | void | — |
| `updateFcmToken` | `$calleeId`, `$fcmToken` | void | — |

#### 3.4.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). DI 등록: `Call/Config/Services.php`.

#### 3.4.4 Error Handling (에러 처리)

| 예외 클래스 | HTTP | 에러 코드 | 발생 조건 |
|-----------|------|---------|---------|
| `InvalidPasswordException` | 400 | `INVALID_INPUT` | 현재 비밀번호 불일치 |

#### 3.4.5 Data Flow (데이터 흐름)

```
CalleeController::changePassword()
  └─ CalleeManageService::updatePassword(calleeId, currentPw, newPw)
        ├─ CalleeManageRepository::findPasswordHash(calleeId)
        ├─ password_verify(currentPw, hash)   → 불일치 시 InvalidPasswordException
        └─ CalleeManageRepository::updatePasswordHash(calleeId, password_hash(newPw))
```

**PHP 시그니처:**

```php
interface ICalleeManageServiceInterface
{
    /** @throws InvalidPasswordException 현재 비밀번호 불일치 */
    public function updatePassword(int $calleeId, string $currentPassword, string $newPassword): void;
    public function updateOnlineStatus(int $calleeId, bool $isOnline): void;
    public function updateAlarmSettings(int $calleeId, AlarmSettings $settings): void;
    public function updateFcmToken(int $calleeId, string $fcmToken): void;
}
```

---

### IF-INT-005: IPbxServiceInterface

#### 3.5.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-005 |
| 인터페이스명 | IPbxServiceInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/IPbxServiceInterface.php` |
| 제공 컴포넌트 | `PbxService` |
| 소비 컴포넌트 | `CallConnectionService`, `PbxController` |

#### 3.5.2 Data Elements (데이터 요소)

**requestConnection 출력 — `PbxConnectionResult` VO:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `pbxCallId` | string | Hermes PBX 통화 ID (`HMZ-YYYYMMDD-XXXXX`) |
| `callNumber` | string | 060 전화 번호 |

**syncCallRecord 출력 — `PbxCallRecord`:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `pbxCallId` | string | Hermes PBX 통화 ID |
| `startTime` | string | 통화 시작 시각 (ISO 8601 UTC) |
| `endTime` | string | 통화 종료 시각 |
| `durationSeconds` | int | 통화 시간(초) |
| `status` | string | `'connecting'` / `'completed'` / `'missed'` |

#### 3.5.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출. 내부에서 Hermes REST API 호출 |
| 재시도 정책 | 최대 3회 재시도. 최종 실패 시 `PbxConnectionException` |
| 타임아웃 | 연결 3초, 응답 10초 |

#### 3.5.4 Error Handling (에러 처리)

| 예외 클래스 | HTTP | 에러 코드 | 발생 조건 |
|-----------|------|---------|---------|
| `PbxConnectionException` | 503 | `PBX_UNAVAILABLE` | Hermes API 타임아웃/불가 (3회 재시도 후) |

#### 3.5.5 Data Flow (데이터 흐름)

```
CallConnectionService::initiate()
  └─ PbxService::requestConnection(calleeId, callerNumber)
        └─ Hermes API: POST /api/v1/calls/connect
              ├─ [성공] PbxConnectionResult { pbxCallId, callNumber }
              └─ [실패 × 3] PbxConnectionException
```

**PHP 시그니처:**

```php
interface IPbxServiceInterface
{
    /** @throws PbxConnectionException Hermes API 오류 (타임아웃 포함) */
    public function requestConnection(int $calleeId, string $callerNumber): PbxConnectionResult;
    public function notifyCallEnd(string $pbxCallId): void;
    public function getCalleeAvailability(int $calleeId): bool;
    public function syncCallRecord(string $pbxCallId): PbxCallRecord;
}
```

---

### IF-INT-006: ICallRepositoryInterface

#### 3.6.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-006 |
| 인터페이스명 | ICallRepositoryInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICallRepositoryInterface.php` |
| 제공 컴포넌트 | `CallRepository` |
| 소비 컴포넌트 | `CallConnectionService`, `CallController` |

#### 3.6.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `insert(array $data)` | `{caller_ac_id, callee_ac_id, callee_ce_code, idempotency_key}` | `int` (cr_code PK) | `tb_call_result` 신규 레코드 삽입 |
| `findById(int $callId)` | cr_code | `?array` | 통화 기록 단건 조회 (미존재 시 null) |
| `updateStatus(int $callId, string $status, array $extra)` | status: `'insert'/'on'/'closed'/'miss'/'under30'` | `bool` | 상태 갱신 |
| `findByCallerId(int $callerId, int $page, int $perPage)` | — | `{data: array, total: int}` | Caller 통화 이력 페이지네이션 |
| `findByCalleeId(int $calleeId, int $page, int $perPage)` | — | `{data: array, total: int}` | Callee 통화 이력 페이지네이션 |
| `existsByIdempotencyKey(string $key)` | 멱등키 | `bool` | 중복 확인 (INSERT 전 선검증) |

#### 3.6.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder 우선. CTE/Window Function은 `$db->query()` + named binding |
| DB 연결 | Aurora MySQL (RDS Proxy, IAM Auth) |

#### 3.6.4 Error Handling (에러 처리)

DB 쿼리 실패 시 CI4 Database Exception 전파. Controller에서 500 `INTERNAL` 응답. 멱등키 DB unique 제약으로 중복 INSERT 원천 차단.

#### 3.6.5 Data Flow (데이터 흐름)

```
CallConnectionService / CallController
  └─ CallRepository::method()
        └─ CI4 Query Builder / $db->query()
              └─ Aurora MySQL (RDS Proxy)
```

**PHP 시그니처:**

```php
interface ICallRepositoryInterface
{
    public function insert(array $data): int;
    public function findById(int $callId): ?array;
    public function updateStatus(int $callId, string $status, array $extra = []): bool;
    public function findByCallerId(int $callerId, int $page, int $perPage): array;
    public function findByCalleeId(int $calleeId, int $page, int $perPage): array;
    public function existsByIdempotencyKey(string $key): bool;
}
```

---

### IF-INT-007: ICallCloseRepositoryInterface

#### 3.7.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-007 |
| 인터페이스명 | ICallCloseRepositoryInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICallCloseRepositoryInterface.php` |
| 제공 컴포넌트 | `CallCloseRepository` |
| 소비 컴포넌트 | `CallCloseService` |

#### 3.7.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `deductCoin(int $callerId, int $amount, int $callId)` | — | `bool` | `tb_coin` INSERT. `coin_type='deduct'`, `ref_type='call'`. DB unique 제약으로 중복 차감 방지 |
| `publishOutboxEvent(string $eventType, array $payload)` | eventType: `'call.closed'` 등 | `bool` | `global_sync_pub_log` INSERT. `status='pending'` |
| `getCoinBalance(int $callerId)` | — | `int` | `SELECT SUM(amount) FROM tb_coin WHERE caller_ac_id = ?` |
| `getCallDuration(int $callId)` | — | `?int` | `TIMESTAMPDIFF(SECOND, start_time, end_time)` from `tb_call_result` |

#### 3.7.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). `deductCoin` + `publishOutboxEvent` + `CallRepository::updateStatus`는 동일 DB 트랜잭션 내 실행 (Outbox 패턴).

#### 3.7.4 Error Handling (에러 처리)

`deductCoin` — DB unique 제약 위반 시 예외 전파 (중복 정산 방지). `publishOutboxEvent` — INSERT 실패 시 트랜잭션 롤백.

#### 3.7.5 Data Flow (데이터 흐름)

```php
interface ICallCloseRepositoryInterface
{
    public function deductCoin(int $callerId, int $amount, int $callId): bool;
    public function publishOutboxEvent(string $eventType, array $payload): bool;
    public function getCoinBalance(int $callerId): int;
    public function getCallDuration(int $callId): ?int;
}
```

---

### IF-INT-008: ICalleeRepositoryInterface

#### 3.8.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-008 |
| 인터페이스명 | ICalleeRepositoryInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICalleeRepositoryInterface.php` |
| 제공 컴포넌트 | `CalleeRepository` |
| 소비 컴포넌트 | `CalleeController`, `CalleeActivityService` |

#### 3.8.2 Data Elements (데이터 요소)

**메서드 카테고리별 분류 (총 22+ 메서드):**

| 카테고리 | 메서드 수 | 대표 메서드 |
|---------|--------|----------|
| 프로필 | 3 | `findById()`, `updateProfile()`, `updateStatus()` |
| 통계 | 3 | `getCallCountByPeriod()`, `getTotalDurationByPeriod()`, `getRevenueByPeriod()` |
| 즐겨찾기 | 3 | `addFavorite()`, `removeFavorite()`, `getFavorites()` |
| 컨텐츠 | 6 | `getPostings()`, `insertPosting()`, `updatePosting()`, `deletePosting()`, `getComments()`, `deleteComment()` |
| 알람 | 3 | `getAlarms()`, `markAlarmRead()`, `insertAlarm()` |
| FCM | 2 | `updateFcmToken()`, `getFcmToken()` |
| 채팅/견적 | 4 | `getChatList()`, `insertChatReply()`, `getEstimates()`, `updateEstimateStatus()` |

#### 3.8.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder. Aurora MySQL (RDS Proxy) |
| 소유권 보장 | 모든 조회/수정/삭제에 `callee_ac_id` 조건 내장 (OWASP API1:2023 BOLA 대응) |

#### 3.8.4 Error Handling (에러 처리)

`findById()` — 미존재 시 `null` 반환. `addFavorite()` — 중복 시 DB unique 제약 위반 예외 전파 (Controller에서 409 `CONFLICT`). 컨텐츠 수정/삭제 — 소유권 위반 시 0 행 반환 → Controller 403.

**소유권 검증 패턴 (OWASP API1:2023 BOLA 대응):**
```sql
-- 게시물 수정 시 소유권 조건 내장
WHERE posting_id = :posting_id AND callee_ac_id = :callee_ac_id
```

#### 3.8.5 Data Flow (데이터 흐름)

```
CalleeController / CalleeActivityService
  └─ CalleeRepository::method()
        └─ CI4 Query Builder / $db->query()
              └─ Aurora MySQL (RDS Proxy)
```

**PHP 시그니처 (핵심):**

```php
interface ICalleeRepositoryInterface
{
    // 프로필
    public function findById(int $calleeId): ?array;
    public function updateProfile(int $calleeId, array $data): bool;
    public function updateStatus(int $calleeId, string $status): bool;

    // 통계
    public function getCallCountByPeriod(int $calleeId, string $startDate, string $endDate): int;
    public function getTotalDurationByPeriod(int $calleeId, string $startDate, string $endDate): int;
    public function getRevenueByPeriod(int $calleeId, string $startDate, string $endDate): int;

    // 즐겨찾기
    public function addFavorite(int $callerId, int $calleeId): bool;
    public function removeFavorite(int $callerId, int $calleeId): bool;
    public function getFavorites(int $callerId, int $page, int $perPage): array;

    // 컨텐츠
    public function getPostings(int $calleeId, int $page, int $perPage): array;
    public function insertPosting(array $data): int;
    public function updatePosting(int $postingId, int $calleeId, array $data): bool;
    public function deletePosting(int $postingId, int $calleeId): bool;
    public function getComments(int $calleeId, int $page, int $perPage): array;
    public function deleteComment(int $commentId, int $calleeId): bool;

    // 알람
    public function getAlarms(int $calleeId, int $page, int $perPage): array;
    public function markAlarmRead(int $alarmId, int $calleeId): bool;
    public function insertAlarm(array $data): int;

    // FCM
    public function updateFcmToken(int $calleeId, string $token): bool;
    public function getFcmToken(int $calleeId): ?string;

    // 채팅/견적
    public function getChatList(int $calleeId, int $page, int $perPage): array;
    public function insertChatReply(array $data): int;
    public function getEstimates(int $calleeId, int $page, int $perPage): array;
    public function updateEstimateStatus(int $estimateId, int $calleeId, string $status): bool;
}
```

---

### IF-INT-009: ICalleeManageRepositoryInterface

#### 3.9.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-009 |
| 인터페이스명 | ICalleeManageRepositoryInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/ICalleeManageRepositoryInterface.php` |
| 제공 컴포넌트 | `CalleeManageRepository` |
| 소비 컴포넌트 | `CalleeManageService` |

#### 3.9.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `findPasswordHash(int $calleeId)` | calleeId | `?string` | `tb_account.ac_password` bcrypt 해시 (미존재 시 null) |
| `updatePasswordHash(int $calleeId, string $hash)` | — | `bool` | 비밀번호 해시 갱신 |
| `updateOnlineStatus(int $calleeId, bool $isOnline)` | — | `bool` | 온라인 상태 갱신 |
| `getAlarmConfig(int $calleeId)` | — | `array` | 알람 설정 배열 (`call`, `event`, `system`) |
| `updateAlarmConfig(int $calleeId, array $config)` | — | `bool` | 알람 설정 갱신 |

#### 3.9.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). CI4 Query Builder. Aurora MySQL.

#### 3.9.4 Error Handling (에러 처리)

`findPasswordHash()` — 미존재 시 `null` 반환. `updatePasswordHash()` — 0 행 반환 시 호출측에서 404 처리.

#### 3.9.5 Data Flow (데이터 흐름)

```php
interface ICalleeManageRepositoryInterface
{
    public function findPasswordHash(int $calleeId): ?string;
    public function updatePasswordHash(int $calleeId, string $hash): bool;
    public function updateOnlineStatus(int $calleeId, bool $isOnline): bool;
    public function getAlarmConfig(int $calleeId): array;
    public function updateAlarmConfig(int $calleeId, array $config): bool;
}
```

---

### IF-INT-010: IPbxRepositoryInterface

#### 3.10.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-010 |
| 인터페이스명 | IPbxRepositoryInterface |
| 파일 경로 | `app/Modules/Call/Interfaces/IPbxRepositoryInterface.php` |
| 제공 컴포넌트 | `PbxRepository` |
| 소비 컴포넌트 | `PbxService`, `PbxController` |

#### 3.10.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `insertPbxRecord(array $data)` | `{pbx_call_id, callee_ac_id, call_number, raw_payload(JSON)}` | `int` (PK) | Hermes 원본 데이터 저장 |
| `findByPbxCallId(string $pbxCallId)` | Hermes PBX ID | `?array` | 단건 조회 |
| `updatePbxRecord(string $pbxCallId, array $data)` | — | `bool` | 상태/시간 갱신 |
| `syncFromHermes(array $hermesData)` | Hermes 원본 | `bool` | `pbx_call_id` 기준 upsert |

#### 3.10.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). CI4 Query Builder. Aurora MySQL.

#### 3.10.4 Error Handling (에러 처리)

`findByPbxCallId()` — 미존재 시 `null` 반환. `syncFromHermes()` — upsert 실패 시 DB Exception 전파.

#### 3.10.5 Data Flow (데이터 흐름)

```php
interface IPbxRepositoryInterface
{
    public function insertPbxRecord(array $data): int;
    public function findByPbxCallId(string $pbxCallId): ?array;
    public function updatePbxRecord(string $pbxCallId, array $data): bool;
    public function syncFromHermes(array $hermesData): bool;
}
```

---

## 4. External Interfaces (외부 인터페이스)

MIL-STD-498 IDD §4 — 각 외부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-EXT-001: Hermes PBX REST API

#### 4.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | Hermes PBX REST API |
| 대상 시스템 | Hermes 통화 관리 서버 |
| 연동 컴포넌트 | `PbxService` |
| 기본 URL | `http://hermes.peoplev.co.kr` |
| 환경변수 | `HERMES_API_URL`, `HERMES_API_KEY` |

#### 4.1.2 Data Elements (데이터 요소)

**EP-1: 통화 연결 요청**

```
HTTP Method : POST
URL         : /api/v1/calls/connect
```

요청 페이로드:
```json
{
    "callee_id": 123,
    "caller_number": "01012345678",
    "call_ref_id": "456",
    "callback_url": "https://prd.gl.hongcafe.com/api/pbx/call-start"
}
```

응답 (HTTP 200):
```json
{
    "pbx_call_id": "HMZ-20260415-00123",
    "call_number": "0601234567",
    "status": "connecting"
}
```

에러 응답:
```json
{
    "error_code": "CALLEE_BUSY",
    "message": "상담사가 통화 중입니다"
}
```

**EP-2: 통화 종료 통보**

```
HTTP Method : POST
URL         : /api/v1/calls/{pbxCallId}/end
```

요청 페이로드:
```json
{
    "end_reason": "normal",
    "duration_sec": 120
}
```

응답 (HTTP 200):
```json
{
    "pbx_call_id": "HMZ-20260415-00123",
    "acknowledged": true
}
```

**EP-3: 상담사 상태 조회**

```
HTTP Method : GET
URL         : /api/v1/callees/{calleeId}/status
```

응답 (HTTP 200):
```json
{
    "callee_id": 123,
    "is_available": true,
    "current_status": "online"
}
```

**EP-4: 통화 기록 조회 (동기화)**

```
HTTP Method : GET
URL         : /api/v1/calls/{pbxCallId}/record
```

응답 (HTTP 200):
```json
{
    "pbx_call_id": "HMZ-20260415-00123",
    "start_time": "2026-04-15T10:00:00Z",
    "end_time": "2026-04-15T10:02:00Z",
    "duration_sec": 120,
    "call_number": "0601234567",
    "status": "completed"
}
```

**Hermes → 시스템 Callback (수신 EP):**

| Callback 유형 | 수신 EP | 이벤트 |
|-------------|--------|-------|
| 통화 시작 | `POST /api/pbx/call-start` | `call_connected` |
| 통화 종료 | `POST /api/pbx/call-end` | `call_ended` |
| 부재 | `POST /api/pbx/call-miss` | `call_missed` |

통화 종료 Callback 페이로드:
```json
{
    "pbx_call_id": "HMZ-20260415-00123",
    "call_ref_id": "456",
    "event": "call_ended",
    "end_reason": "normal",
    "ended_at": "2026-04-15T10:02:00Z",
    "duration_sec": 120
}
```

#### 4.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTP REST (내부 VPC 통신) |
| 인증 방식 | `X-Hermes-Api-Key: {HERMES_API_KEY}` 요청 헤더 |
| Content-Type | `application/json` |
| 구현 방법 | PHP cURL |
| 타임아웃 | 연결 3초, 응답 10초 |
| 재시도 | 최대 3회 (PbxService 내부 처리) |

#### 4.1.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| HTTP 4xx 응답 | `PbxConnectionException` 발생 (3회 재시도 후) |
| HTTP 5xx 응답 | `PbxConnectionException` 발생 (3회 재시도 후) |
| cURL 타임아웃 (3초/10초) | `PbxConnectionException` 발생 (3회 재시도 후) |
| Callback 수신 실패 | `PbxController`에서 500 로그. Hermes 재전송 대기 |

**재시도 정책:** `PbxService` 내 최대 3회. 최종 실패 시 `PbxConnectionException` → Controller에서 503 `PBX_UNAVAILABLE` 응답.

#### 4.1.5 Data Flow (데이터 흐름)

```
PbxService::requestConnection(calleeId, callerNumber)
  └─ cURL POST /api/v1/calls/connect
        ├─ [성공] PbxConnectionResult { pbxCallId, callNumber }
        └─ [실패 × 3] PbxConnectionException

PbxController::callEnd() [Hermes Callback 수신]
  ├─ 요청 파라미터 검증 (X-Api-Key)
  └─ CallCloseService::close(callId, endTime)
```

---

### IF-EXT-002: Firebase Cloud Messaging (FCM)

#### 4.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-002 |
| 인터페이스명 | Firebase Cloud Messaging (FCM) |
| 대상 시스템 | FCM 푸시 알림 서비스 |
| 연동 컴포넌트 | `Fcm` 클래스 (stCode별 인스턴스) |
| SDK | Google Firebase Admin SDK 또는 HTTP v1 API |
| 인증 | Service Account JSON (서버 환경변수) |
| 용도 | 통화 요청/연결/종료/부재 Push 알림 |

#### 4.2.2 Data Elements (데이터 요소)

**FCM 이벤트 유형:**

| 이벤트 유형 | 발송 시점 | 대상 |
|-----------|---------|------|
| `call_request` | 통화 요청 수신 시 | Callee |
| `call_connected` | 통화 연결 완료 시 | Caller + Callee |
| `call_closed` | 통화 종료 정산 완료 시 | Caller + Callee |
| `call_missed` | 통화 부재 처리 시 | Caller + Callee |

**call_request Payload:**
```json
{
    "token": "{callee_fcm_token}",
    "notification": {
        "title": "통화 요청",
        "body": "{caller_nick}님이 통화를 요청했습니다"
    },
    "data": {
        "event_type": "call_request",
        "call_id": "456",
        "caller_id": "789",
        "caller_nick": "홍길동"
    },
    "android": { "priority": "high" },
    "apns": { "headers": { "apns-priority": "10" } }
}
```

**call_closed Payload:**
```json
{
    "tokens": ["{caller_fcm_token}", "{callee_fcm_token}"],
    "notification": {
        "title": "통화 종료",
        "body": "통화가 종료되었습니다. 총 {duration}분 {coin_deducted}코인 차감"
    },
    "data": {
        "event_type": "call_closed",
        "call_id": "456",
        "duration_sec": "120",
        "coin_deducted": "1000",
        "status": "closed"
    }
}
```

#### 4.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 인스턴스 전략 | `stCode`별 FCM 인스턴스 생성 (다중 브랜드 지원) |
| 인증 | Service Account JSON (환경변수, stCode별 분리) |
| 프로토콜 | FCM REST API (HTTP v1) |

#### 4.2.4 Error Handling (에러 처리)

FCM 전송 실패 시 에러 로그 기록. 알림 전송 실패는 비즈니스 로직(통화/정산)에 영향 없음 (Graceful Degradation). FCM 토큰 만료 시 `CalleeManageService::updateFcmToken()` 자동 갱신.

#### 4.2.5 Data Flow (데이터 흐름)

```
CallConnectionService::initiate() [통화 시작]
  └─ Fcm::getInstance($stCode)->send($calleeToken, '통화 요청', body, data)
        └─ FCM REST API → 상담사 디바이스 Push

CallCloseService::close() [통화 종료 정산 완료]
  └─ Fcm::getInstance($stCode)->sendMulti([$callerToken, $calleeToken], '통화 종료', body, data)
        └─ FCM REST API → 양측 디바이스 Push
```

---

## 5. Events and Signals (이벤트 계약)

MIL-STD-498 IDD §5 — Outbox 패턴 이벤트 트리거, 대상, Payload를 명세한다.

모든 이벤트는 `global_sync_pub_log` 테이블에 INSERT 후 Lambda/Cron이 폴링하여 SNS/SQS로 발행.

**공통 Outbox 레코드 구조:**
```json
{
    "event_type": "call.{event_name}",
    "aggregate_type": "call_result",
    "aggregate_id": "{cr_code}",
    "payload": { ... },
    "status": "pending",
    "created_at": "2026-04-15T10:02:00Z"
}
```

| 이벤트 ID | 이벤트명 | 트리거 조건 | 발신 컴포넌트 | 수신 모듈 | 처리 내용 |
|---------|--------|---------|------------|---------|---------|
| EVT-001 | `call.closed` | 통화 상태 → Closed (30초 초과) | `CallCloseRepository` | Coin, Member, Analytics | 코인 차감 확정, 수익 통계 갱신 |
| EVT-002 | `call.payback` | 종료 후 Payback 이벤트 조건 충족 | `CallCloseRepository` | Coin | Payback 코인 환급 |
| EVT-003 | `call.special_price` | 특별 할인 요금 적용 통화 종료 | `CallCloseRepository` | Coin, Analytics | 할인 적용 통계 기록 |
| EVT-004 | `call.roulette` | 이벤트 통화 종료, 룰렛 조건 충족 | `CallCloseRepository` | Coin, Member | 룰렛 경품 발행 |
| EVT-005 | `call.first_coupon` | Caller 첫 번째 통화(Closed) 완료 | `CallCloseRepository` | Coin, Member | 첫 통화 쿠폰 발급 |
| EVT-006 | FCM: `call_request` | 통화 연결 요청 시 | `CallConnectionService` | FCM | Callee Push 알림 |
| EVT-007 | FCM: `call_closed` | 정산 완료 시 | `CallCloseService` | FCM | 양측 Push 알림 + 코인 정보 |
| EVT-008 | FCM: `call_missed` | 부재 처리 확정 시 | `PbxController` | FCM | 양측 부재 알림 |

**call.payback Payload 예시:**
```json
{
    "event_type": "call.payback",
    "aggregate_type": "call_result",
    "aggregate_id": "456",
    "payload": {
        "callId": 456,
        "callerId": 789,
        "paybackCoin": 200,
        "paybackRatio": 0.2,
        "reason": "payback_event",
        "issuedAt": "2026-04-15T10:02:01Z"
    }
}
```

**call.first_coupon Payload 예시:**
```json
{
    "event_type": "call.first_coupon",
    "aggregate_type": "call_result",
    "aggregate_id": "456",
    "payload": {
        "callId": 456,
        "callerId": 789,
        "couponCode": "FIRST-CALL-XXXXXXXX",
        "couponCoin": 1000,
        "expiredAt": "2026-05-15T00:00:00Z",
        "issuedAt": "2026-04-15T10:02:03Z"
    }
}
```

---

## 6. Error Handling Contract (에러 처리 계약)

MIL-STD-498 IDD §6 — HTTP 에러 코드 계약 및 PHP 예외 계층.

### 6.1 표준 에러 응답 형식

```json
{
    "error": {
        "code": "ERROR_CODE_UPPERCASE",
        "message": "에러 설명 (lang() 키 기반 다국어)"
    }
}
```

### 6.2 Call 모듈 에러 코드

| HTTP | 에러 코드 | 발생 위치 | 설명 |
|------|---------|---------|------|
| 400 | `INVALID_INPUT` | Controller | 요청 파라미터 유효성 검증 실패 |
| 400 | `INSUFFICIENT_COIN` | `CallConnectionService` | 코인 잔액 < `CALL_MIN_COIN`(5,000) |
| 400 | `INVALID_CALL_STATUS` | `CallCloseService` | 이미 종료된 통화 재종료 시도 |
| 401 | `UNAUTHORIZED` | `AuthFilter` | JWT 토큰 없음/만료 |
| 403 | `FORBIDDEN` | `RoleFilter` | `role:callee` 권한 없음 |
| 403 | `FORBIDDEN` | `ApiKeyFilter` | `X-Api-Key` 불일치 |
| 404 | `NOT_FOUND` | Repository | 존재하지 않는 통화 기록 |
| 409 | `CONFLICT` | `CallConnectionService` | 멱등키 중복 (동일 요청 재시도) |
| 409 | `CALLEE_UNAVAILABLE` | `CallConnectionService` | 상담사 오프라인/통화중 |
| 500 | `INTERNAL` | Service/Repository | DB 오류, Hermes API 장애 등 |
| 503 | `PBX_UNAVAILABLE` | `PbxService` | Hermes API 타임아웃/불가 |

### 6.3 PHP 예외 계층

```php
// 기반 예외
class CallModuleException extends \RuntimeException {}

// 구체 예외 (HTTP 상태코드 매핑)
class InsufficientCoinException     extends CallModuleException {} // HTTP 400
class InvalidCallStatusException    extends CallModuleException {} // HTTP 400
class InvalidPasswordException      extends CallModuleException {} // HTTP 400
class CallNotFoundException         extends CallModuleException {} // HTTP 404
class CalleeUnavailableException    extends CallModuleException {} // HTTP 409
class DuplicateCallException        extends CallModuleException {} // HTTP 409
class PbxConnectionException        extends CallModuleException {} // HTTP 503
```

---

## 7. Data Formats and Encoding (데이터 포맷 및 인코딩)

MIL-STD-498 IDD §7 — 인터페이스 데이터 포맷, DTO 정의, 인코딩 규칙을 명세한다.

### 7.1 공통 인코딩 규칙

| 항목 | 규칙 |
|------|------|
| 문자 인코딩 | UTF-8 (utf8mb4) 전 레벨 통일 |
| 날짜/시각 | ISO 8601 형식 (`YYYY-MM-DDTHH:MM:SSZ`). UTC 기준 |
| DB 저장 포맷 | `YYYY-MM-DD HH:MM:SS` (UTC) |
| PHP 내부 | `DateTimeImmutable` 사용. `date()` / `time()` 사용 금지 |
| API 응답 키 | DB `snake_case` → API `camelCase` 변환 필수 (`created_at` → `createdAt`) |
| 코인 | 정수형 (`int`). 소수점 없음 |
| 통화 시간 | 정수형 `int` (초). 소수점 없음 |
| 성공 응답 | `{ "data": {...} }` (HTTP 200/201) |
| 에러 응답 | `{ "error": { "code": "...", "message": "..." } }` (HTTP 4xx/5xx) |

### 7.2 통화 기록 DTO (CallResult)

| 필드명 (API) | 필드명 (DB) | 타입 | 설명 |
|-------------|-----------|------|------|
| `callId` | `cr_code` | int | 통화 기록 PK |
| `callerId` | `caller_ac_id` | int | Caller 계정 ID |
| `calleeId` | `callee_ac_id` | int | Callee 계정 ID |
| `calleeCeCode` | `callee_ce_code` | string | Callee 상담사 코드 |
| `status` | `cr_status` | string | `insert` / `on` / `closed` / `miss` / `under30` |
| `pbxCallId` | `pbx_call_id` | string | Hermes PBX 통화 ID |
| `callNumber` | `call_number` | string | 060 전화 번호 |
| `startTime` | `start_time` | datetime | 통화 시작 시각 (UTC) |
| `endTime` | `end_time` | datetime | 통화 종료 시각 (UTC) |
| `durationSeconds` | `duration_sec` | int | 총 통화 시간(초) |
| `coinDeducted` | `coin_deducted` | int | 차감 코인 수 |
| `coinRate` | `coin_rate` | int | 30초당 코인 요금 |
| `createdAt` | `created_at` | datetime | 레코드 생성 시각 (UTC) |

### 7.3 단건 통화 기록 응답 예시

```json
// GET /api/calls/{id}
{
    "data": {
        "callId": 456,
        "callerId": 789,
        "calleeId": 123,
        "calleeCeCode": "CE001",
        "status": "closed",
        "pbxCallId": "HMZ-20260415-00123",
        "callNumber": "0601234567",
        "startTime": "2026-04-15T10:00:00Z",
        "endTime": "2026-04-15T10:02:00Z",
        "durationSeconds": 120,
        "coinDeducted": 1000,
        "coinRate": 500,
        "createdAt": "2026-04-15T10:00:00Z"
    }
}
```

### 7.4 대시보드 응답 예시

```json
// GET /api/callees/dashboard
{
    "data": {
        "today": {
            "callCount": 5,
            "totalDurationSeconds": 1800,
            "totalRevenue": 5000
        },
        "week": {
            "callCount": 32,
            "totalDurationSeconds": 12600,
            "totalRevenue": 35000
        },
        "month": {
            "callCount": 128,
            "totalDurationSeconds": 50400,
            "totalRevenue": 140000
        }
    }
}
```

### 7.5 페이지네이션 응답 포맷

```json
// GET /api/callees/alarms
{
    "data": [
        {
            "alarmId": 101,
            "type": "call_request",
            "title": "통화 요청",
            "body": "홍길동님이 통화를 요청했습니다",
            "isRead": false,
            "createdAt": "2026-04-15T10:00:00Z"
        }
    ],
    "meta": {
        "currentPage": 1,
        "perPage": 20,
        "total": 50,
        "lastPage": 3
    }
}
```

### 7.6 통화 연결 요청 응답 예시

```json
// POST /api/calls/call-start (성공)
{
    "data": {
        "callId": 456,
        "pbxCallId": "HMZ-20260415-00123",
        "callNumber": "0601234567",
        "status": "connecting"
    }
}

// POST /api/calls/call-start (코인 부족)
// HTTP 400
{
    "error": {
        "code": "INSUFFICIENT_COIN",
        "message": "통화를 위한 코인이 부족합니다"
    }
}
```

---

## 8. Feasibility Review (타당성 검토)

> 근거: OWASP API Security Top 10 2023, RFC 7231, RFC 3339, MIL-STD-498

| 검토 ID | 검토 항목 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|----------|------|------|------|------------|
| FEA-001 | **Hermes X-Api-Key 헤더 인증 (PBX Callback)** | 서버-서버 통신 표준 패턴. 환경변수 관리로 적절 | OWASP API8:2023(Security Misconfiguration) 준수. PBX Callback은 내부 VPC 통신으로 TLS 보호. JWT/CSRF 면제(서버-서버). EXCLUDED_PATHS 등록 필수 | mTLS 상호 인증 | X-Api-Key: 구현 단순, 환경변수 관리 필요. mTLS: 보안 강화, 인증서 관리 복잡 |
| FEA-002 | **멱등키(idempotency_key) DB 중복 방지** | DB unique 제약으로 원자적 중복 방지. 적절 | DB 수준 unique 제약이 애플리케이션 수준 중복 확인보다 race condition에 강함. `existsByIdempotencyKey` 사전 확인은 UX 응답 개선용 | 애플리케이션 레벨 중복 확인만 | DB 제약: 원자적 보장, 예외 처리 필요. 앱 레벨: 단순, race condition 취약 |
| FEA-003 | **코인 차감·Outbox·상태 갱신 단일 트랜잭션** | Outbox 패턴 + 트랜잭션 원자성. 정산 무결성 보장 | MySQL 8.0 InnoDB Transactions 공식 문서(https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-model.html) — ACID 트랜잭션으로 코인 차감과 이벤트 발행을 원자적 처리. Transactional Outbox 패턴(Chris Richardson, Microservices Patterns, Ch.3)으로 외부 시스템 장애와 독립. 멱등키(coin_type, ref_type, ref_id) DB unique 제약으로 중복 차감 방지 | 비동기 이벤트 발행 (Kafka/SQS 직접) | 트랜잭션 Outbox: 정합성↑, Lambda 폴링 필요. 직접 발행: 실시간성↑, 장애 시 데이터 불일치 위험 |
| FEA-004 | **PbxService 3회 재시도 정책** | Hermes 일시 장애 대응. 적절 | FR-003-05 요구사항 직접 반영. 통화 연결은 UX에 직접 영향. 10초 타임아웃 × 3회 = 최대 30초 대기. 503 응답 후 클라이언트 재시도 가능 | 1회 시도 후 실패 반환 | 재시도: 성공률↑, 응답 지연. 단일 시도: 빠른 실패, 성공률↓ |
| FEA-005 | **FREE_DURATION(30초) + COIN_TERM(30초) 코인 계산** | 순수 함수로 단위 테스트 가능. 타당 | `calculateCoinDeduction`을 부수 효과 없는 순수 함수로 구현. FR-002-08 직접 준수. 공식 `ceil((duration - 30) / 30) × rate`로 30초 단위 청구. 30초 이하 무료(FREE_DURATION) 정책 명확 | 1초 단위 청구 | 30초 단위: 사용자 이해 용이, 소수점 없음. 1초 단위: 정밀, 계산 복잡 |

---

## 9. Change Impact Log (변경 영향 기록)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|----------|----------|--------|----------|
| MIL-STD-498 IDD 표준 전면 전환 | 전체 문서 구조 재편 | Scope(§1), References(§2), 인터페이스별 5-subsection(식별자/데이터/통신/에러/흐름), Events(§5), ErrorContract(§6), DataFormats(§7), Requirements Traceability(§10) 신설 | 3-Round Review PASS 요건 충족. MIL-STD-498 기준 인터페이스 문서로 완전성 확보 |
| 버전 v1.0 → v2.0 | 문서 헤더, 변경 로그 | MIL-STD-498 전환 반영하는 메이저 버전 갱신 | 문서 이력 명확화 |
| 인터페이스별 5-subsection 구조화 | IF-INT-001~010, IF-EXT-001~002 전체 | 식별자/데이터/통신속성/에러처리/데이터흐름 5항목 완전 기술. 구현자 단독 참조 가능한 완결성 확보 | MIL-STD-498 DI-IPSC-81436 IDD 요건 준수 |
| Events and Signals 신설 (§5) | 신규 섹션 | Outbox 이벤트 5건(call.closed/payback/special_price/roulette/first_coupon) + FCM 이벤트 3건 전체 트리거-발신-수신-처리 명세 | MIL-STD-498 IDD 이벤트 계약 요건 준수 |
| Error Handling Contract 신설 (§6) | 기존 §7 에러 계약 재편 | PHP 예외 계층 7개 + HTTP 에러 코드 11개 완전 명세. 발생 위치까지 특정 | 구현자 에러 처리 단일 참조 가능 |
| Data Formats 확장 (§7) | 기존 §8 데이터 포맷 확장 | 공통 인코딩 규칙, camelCase 변환 규칙, CallResult DTO 표, 단건/대시보드/페이지네이션/연결 응답 JSON 예시 추가 | 구현자 코딩 표준 단일 참조 가능 |
| Requirements Traceability Matrix 신설 (§10) | 신규 섹션 | SRS FR/NFR → IDD 인터페이스 매핑. 인터페이스 누락 방지 | MIL-STD-498 DI-IPSC-81436 추적성 요건 준수 |

---

## 10. Requirements Traceability Matrix (요구사항 추적성 매트릭스)

MIL-STD-498 DI-IPSC-81436 §10 — SRS FR/NFR과 IDD 인터페이스 간 추적성.

| SRS 요구사항 ID | 요구사항명 | 연관 인터페이스 | 인터페이스 타입 |
|---------------|---------|-------------|-------------|
| FR-001 | 통화 연결 | IF-INT-001 (`ICallConnectionService`), IF-INT-006 (`ICallRepository`), IF-EXT-001 (Hermes `requestConnection`) | 내부+외부 |
| FR-002 | 통화 종료 및 정산 | IF-INT-002 (`ICallCloseService`), IF-INT-007 (`ICallCloseRepository`), IF-EXT-002 (FCM `call_closed`) | 내부+외부 |
| FR-003 | PBX 연동 | IF-INT-005 (`IPbxService`), IF-INT-010 (`IPbxRepository`), IF-EXT-001 (Hermes Callback) | 내부+외부 |
| FR-004 | 상담사 대시보드 | IF-INT-003 (`ICalleeActivityService`), IF-INT-008 (`ICalleeRepository`) | 내부 |
| FR-005 | 상담사 알람 | IF-INT-008 (`ICalleeRepository::insertAlarm`), IF-EXT-002 (FCM `call_request`) | 내부+외부 |
| FR-006 | 즐겨찾기 | IF-INT-008 (`ICalleeRepository::addFavorite/removeFavorite/getFavorites`) | 내부 |
| FR-007 | 컨텐츠 관리 | IF-INT-008 (`ICalleeRepository` 컨텐츠 메서드) | 내부 |
| FR-008 | 채팅 및 견적 | IF-INT-008 (`ICalleeRepository` 채팅/견적 메서드) | 내부 |
| FR-009 | 코인 정산 | IF-INT-002 (`calculateCoinDeduction`), IF-INT-007 (`deductCoin`) | 내부 |
| FR-010 | PBX Callback 처리 | IF-EXT-001 (Hermes Callback EP), IF-INT-005 (`confirmConnection`/`notifyCallEnd`) | 외부+내부 |
| NFR-001 | 멱등성 (정산 중복 방지) | IF-INT-006 (`existsByIdempotencyKey`), IF-INT-007 (DB unique 제약 `deductCoin`) | 내부 |
| NFR-002 | PBX 재시도 (가용성) | IF-EXT-001 (Hermes 3회 재시도 정책), IF-INT-005 (`PbxConnectionException`) | 외부+내부 |
| NFR-003 | 통화 접근 보안 (BOLA) | IF-INT-008 (소유권 조건 쿼리 `callee_ac_id`), IF-INT-006 (소유권 쿼리) | 내부 |
| NFR-004 | role:callee 인가 (BFLA) | IF-INT-003, IF-INT-004, IF-INT-008 (Callee 전용 메서드) | 내부 |
| NFR-005 | FCM Graceful Degradation | IF-EXT-002 (FCM 실패 시 에러 로그, 비즈니스 로직 무영향) | 외부 |
| CON-001 | API Key 환경변수 관리 | IF-EXT-001 (`HERMES_API_KEY` 환경변수), IF-EXT-002 (Service Account JSON 환경변수) | 외부 |

---

## 11. Document History (변경 로그)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | 1.0.0 | 초기 작성 — 내부 Service Interface 5개, Repository Interface 5개, 외부 Hermes/FCM, Outbox 이벤트 4종, 에러 계약, 데이터 포맷 | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 IDD 표준 전면 전환. 3-Round Review PASS. Scope, References, 인터페이스별 5-subsection 구조화(IF-INT 10개/IF-EXT 2개), Events(8건), Error Contract(§6 신설), DataFormats(인코딩 규칙+DTO+JSON 예시), Requirements Traceability Matrix(16건) 신설 | jypark |
