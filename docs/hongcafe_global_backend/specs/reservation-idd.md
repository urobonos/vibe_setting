---
문서명: Reservation — Interface Design Document
문서 ID: reservation-idd
버전: v2.1
적용 표준: MIL-STD-498 (Interface Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Reservation Module (HongCafe Global Backend)
관련 문서: reservation-sdd.md, reservation-srs.md
---

# Reservation — Interface Design Document

> version: 2.1 | standard: MIL-STD-498 IDD | lastUpdated: 2026-04-21 | module: Reservation

---

## 1. Scope (범위)

### 1.1 Identification (식별)

본 문서는 HongCafe Global Backend Reservation 모듈의 인터페이스 설계를 MIL-STD-498 Interface Design Description (IDD) 표준에 따라 명세한다.

> **[RESV-DEF-011 반영]**: EP 수 및 컨트롤러별 EP 분포를 Routes.php 실제 코드 기준으로 수정.

| 항목 | 내용 |
|------|------|
| 문서 ID | reservation-idd |
| 대상 시스템 | Reservation Module — HongCafe Global Backend |
| 기반 SDD | `reservation-sdd.md` v2.1 |
| 기반 SRS | `reservation-srs.md` v2.1 |
| 인터페이스 총수 | 내부 2개 / 외부 0개 |
| EP 총수 | 8개 (ReservationController 6 + O2oCalendarController 1 + CalendarController 1) |

### 1.2 System Overview (시스템 개요)

Reservation 모듈은 HongCafe Global Backend Modular Monolith 아키텍처 내에서 20분 간격 슬롯 기반 상담 예약 생애주기 전반을 담당한다. O2O(Offline-to-Online) 캘린더 조회와 월간 캘린더 조회를 포함하며, 외부 서비스 의존성 없이 자체 완결(Self-contained)로 동작한다. 모든 데이터 접근은 내부 Aurora MySQL DB를 통해 이루어진다.

**EP 분포** (Routes.php 기준):

| 컨트롤러 | EP 수 | 메서드명 |
|---------|-------|---------|
| ReservationController | 6 | `getSchedule`, `insertReservation`, `getMyReservation`, `getMyReservationList`, `getCalleeReservationList`, `call` |
| O2oCalendarController | 1 | `o2oCalendar` |
| CalendarController | 1 | `calendar` |

### 1.3 Document Overview (문서 개요)

본 IDD는 MIL-STD-498 §DI-IPSC-81436 기준에 따라 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 기술한다.

| 섹션 | 내용 |
|------|------|
| §2 | 참조 문서 |
| §3 | 내부 인터페이스 2개 (IF-INT-001~002) — PHP 시그니처 포함 |
| §4 | 외부 인터페이스 — 없음 (Self-contained) |
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
| reservation-srs.md v2.1 | `docs/specs/reservation-srs.md` |
| reservation-sdd.md v2.1 | `docs/specs/reservation-sdd.md` |
| RFC 7231 — HTTP/1.1 Semantics and Content | IETF |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |
| API ↔ IEEE 대조 리포트 | `docs/output/ieee-review/reservation-api-vs-ieee-20260421.md` |

---

## 3. Internal Interfaces (내부 인터페이스)

MIL-STD-498 IDD §3 — 각 내부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-INT-001: ReservationServiceInterface

#### 3.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | ReservationServiceInterface |
| 파일 경로 | `app/Modules/Reservation/Interfaces/ReservationServiceInterface.php` |
| 제공 컴포넌트 | `ReservationService` |
| 소비 컴포넌트 | `ReservationController` |
| 메서드 수 | 4개 (createO2oEvent 미구현 — Open Question OQ-001) |

#### 3.1.2 Data Elements (데이터 요소)

**메서드별 입출력:**

**`buildScheduleSlots(string $itCode, string $weekDay, string $date): array`**

> **[RESV-DEF-005 반영]**: 슬롯 출력 구조를 API/코드 기준으로 수정. `available: bool` 폐기 → `status: string` 사용.

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$itCode` | string | 아이템 코드 |
| `$weekDay` | string | 요일 문자열 |
| `$date` | string | 조회 날짜 (YYYY-MM-DD) |

출력: `array{dayCnt: int, todayCheck: bool, today: string, weekDay: string, items: array[]}`

슬롯 항목 구조 (`items[]` 내 각 시간대):

| 필드 | 타입 | 설명 |
|------|------|------|
| `date` | string | 슬롯 날짜 (YYYY-MM-DD) |
| `weekDay` | string | 요일 |
| `time` | string | 시간대 ('H' 형식, 예: `"10"`) |
| `min` | int | 시작 분 (0, 20, 40) |
| `start` | string | 슬롯 시작 시각 ('H:i' 형식, 예: `"10:00"`) |
| `status` | string | 슬롯 상태: `'able'`(가용), `'com'`(예약됨), `'end'`(과거) |

---

**`validateReservationRows(array $revRows): void`**

> **[RESV-DEF-007 반영]**: SELECT FOR UPDATE 방식 폐기 → 카운트 기반 3단계 검증.

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$revRows` | array | 예약 슬롯 배열. 각 항목은 `['date', 'time', 'min']` |

검증 항목:
- `checkReservation`: 동일 예약 존재 여부 → 중복 시 예외
- `checkReservationDateTimeCnt`: 동일 날짜+시간 슬롯당 건수 → 1건 초과 시 예외
- `checkReservationDateCnt`: 동일 날짜 건수 → 2건 초과(cnt > 2) 시 예외

출력: 없음. 유효하지 않을 경우 예외 발생 (`CONFLICT` / HTTP 409).

---

**`format(array $reservationData): array`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$reservationData` | array | DB 조회 결과 배열 (snake_case 키) |

출력: 포맷된 배열 (API 응답용)

| DB 필드 | API 필드 | 타입 | 설명 |
|---------|---------|------|------|
| `rv_no` | `rvNo` | int | 예약 번호 |
| `rv_date` | `rvDate` | string | 예약 날짜 (점 구분자 변환) |
| `rs_time` | `rvTime` | string | 예약 시간 ('H:i') |
| `rv_min` | `rvMin` | int | 예약 시간(분) |
| `ce_code` | `ceCode` | string | 상담사 코드 |
| `rev_full_date` | `revFullDate` | string | 전체 날짜+시간 문자열 |
| — | `callStatus` | string | 통화 상태 (resolveCallStatus 결과) |
| — | `refundCheck` | bool | 환불 가능 여부 (23시간 기준) |
| `pd_price` | `payPrice` | float | 결제 금액 (pd_price * 1.1) |

---

**`resolveCallStatus(array $row): string`**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$row` | array | 예약 행 데이터 (`ca_id`, 시간 범위 포함) |

출력: 통화 상태 문자열

| 반환값 | 의미 |
|--------|------|
| `'standby'` | 통화 예약 대기 (시작 전) |
| `'on'` | 통화 중 (시간 윈도우 내) |
| `'closed'` | 통화 종료 (시간 윈도우 후) |

---

**미구현 메서드 — `createO2oEvent(array $params): void` (Open Question OQ-001)**

| 항목 | 내용 |
|------|------|
| 상태 | 미구현 (Open Question) |
| 설계 의도 | O2O 일정 삽입 + 해당 슬롯 예약 불가 처리 |
| 현재 상황 | `O2oCalendarController`가 `shopRepository`를 직접 사용하여 우회 중 |
| 결정 필요 | OQ-001: 등록 기능 구현 여부 담당자(jypark) 확정 필요 |

#### 3.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Reservation/Config/Services.php` |
| 슬롯 단위 | 20분 (시간당 3슬롯: 0분, 20분, 40분) |

#### 3.1.4 Error Handling (에러 처리)

| 예외 클래스 | 발생 조건 | HTTP 상태코드 | 에러 코드 |
|------------|---------|------------|---------|
| `InvalidSlotException` | 필수 파라미터 누락 / 잘못된 날짜 | 400 | `INVALID_INPUT` |
| `SlotConflictException` | 중복 예약 / 슬롯당/날짜당 건수 초과 | 409 | `CONFLICT` |
| `ReservationNotFoundException` | 예약 미존재 또는 소유권 없음 | 404 | `NOT_FOUND` |
| DB Exception | 예약 등록 실패 | 500 | `INTERNAL` |

예외 클래스 경로: `app/Modules/Reservation/Exceptions/`

#### 3.1.5 Data Flow (데이터 흐름)

```
ReservationController::getSchedule()
  └─ ReservationService::buildScheduleSlots(itCode, weekDay, date)
        ├─ ReservationRepository::getAvailableTimes(itCode, weekDay)
        ├─ ReservationRepository::getReservedTimes(itCode, date)
        └─ [20분 단위 슬롯 생성 루프, status: able/com/end]

ReservationController::insertReservation()
  └─ ReservationService::validateReservationRows(revRows)
        ├─ [checkReservation] → SlotConflictException 가능
        ├─ [checkReservationDateTimeCnt] → SlotConflictException 가능
        └─ [checkReservationDateCnt] → SlotConflictException 가능
  └─ ReservationRepository::insert(data)
  └─ ReservationService::format(reservationData)

ReservationController::call()
  └─ ReservationService::resolveCallStatus(row)
        └─ [시간 윈도우 검증: standby/on/closed]
  └─ [통화 연결 처리]

O2oCalendarController::o2oCalendar()
  └─ shopRepository::calendarSchedule(month, ...)
  └─ shopRepository::standbyCalendarSchedule(month, ...)
  └─ CalendarHelper::buildMonthData(month)
```

**PHP 시그니처:**

```php
interface ReservationServiceInterface
{
    /**
     * 아이템/요일/날짜 기반으로 20분 간격 슬롯 목록을 생성한다.
     * @param string $itCode   아이템 코드
     * @param string $weekDay  요일 문자열
     * @param string $date     조회 날짜 (YYYY-MM-DD)
     * @return array{dayCnt: int, todayCheck: bool, today: string, weekDay: string, items: array[]}
     */
    public function buildScheduleSlots(string $itCode, string $weekDay, string $date): array;

    /**
     * 예약 슬롯 배열의 유효성을 카운트 기반으로 검증한다.
     * @param array $revRows [['date', 'time', 'min'], ...]
     * @throws \App\Modules\Reservation\Exceptions\SlotConflictException
     */
    public function validateReservationRows(array $revRows): void;

    /**
     * DB 예약 데이터를 API 응답 포맷으로 변환한다.
     * @param array $reservationData DB 조회 결과 배열
     * @return array 포맷된 배열
     */
    public function format(array $reservationData): array;

    /**
     * 예약 행의 시간 윈도우를 분석하여 통화 상태를 반환한다.
     * @param array $row 예약 행 데이터
     * @return string 'standby' | 'on' | 'closed'
     */
    public function resolveCallStatus(array $row): string;

    // createO2oEvent — 미구현 (Open Question OQ-001)
    // public function createO2oEvent(array $params): void;
}
```

---

### IF-INT-002: ReservationRepositoryInterface

#### 3.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | ReservationRepositoryInterface |
| 파일 경로 | `app/Modules/Reservation/Interfaces/ReservationRepositoryInterface.php` |
| 제공 컴포넌트 | `ReservationRepository` |
| 소비 컴포넌트 | `ReservationService`, `ReservationController`, `CalendarController` |
| 메서드 수 | 28개 |

#### 3.2.2 Data Elements (데이터 요소)

**카테고리별 메서드 분류:**

**예약 기본 CRUD (5메서드)**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `insert(array $data)` | `['ac_id', 'callee_code', 'slot_time', 'memo']` | `int` | 예약 레코드 삽입, 삽입 ID 반환 |
| `findById(int $id)` | `int $id` | `?array` | ID로 예약 조회. 미존재 시 `null` |
| `findByIdAndAcId(int $id, int $acId)` | `id`, `acId` | `?array` | ID + 소유권(ac_id) 조건 조회. OWASP API1:2023 BOLA 대응 |
| `updateStatus(int $id, string $status)` | `id`, `status` | `bool` | 예약 상태 갱신 |
| `delete(int $id)` | `int $id` | `bool` | 논리 삭제 (`deleted_at` 설정) |

**사용자 예약 조회 (4메서드)**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `findByAcId(int $acId, int $page, int $perPage)` | `acId`, `page`, `perPage` | `array{data: array[], total: int}` | 페이지네이션 예약 목록 |
| `countByAcId(int $acId)` | `int $acId` | `int` | 전체 예약 건수 |
| `findUpcomingByAcId(int $acId)` | `int $acId` | `array[]` | 예정 예약 (`slot_time > NOW()`, `status = reserved`) |
| `findCompletedByAcId(int $acId)` | `int $acId` | `array[]` | 완료 예약 (`status = completed`) |

**상담사 예약 조회 (4메서드)**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `findByCalleeCode(string $calleeCode, int $page, int $perPage)` | `calleeCode`, `page`, `perPage` | `array{data: array[], total: int}` | 페이지네이션 예약 목록 |
| `countByCalleeCode(string $calleeCode)` | `string $calleeCode` | `int` | 전체 예약 건수 |
| `findByCalleeCodeAndDate(string $calleeCode, string $date)` | `calleeCode`, `date` (YYYY-MM-DD) | `array[]` | 특정 날짜 예약 목록 |
| `findUpcomingByCalleeCode(string $calleeCode)` | `string $calleeCode` | `array[]` | 예정 예약 목록 |

**슬롯 관리 (5메서드)**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `getReservedSlots(string $calleeCode, string $date)` | `calleeCode`, `date` | `string[]` | 예약된 슬롯 시간 목록 (형식: `H:i`) |
| `isSlotAvailable(string $calleeCode, string $slotTime)` | `calleeCode`, `slotTime` | `bool` | 특정 슬롯 예약 가능 여부 |
| `lockSlot(string $calleeCode, string $slotTime)` | `calleeCode`, `slotTime` | `bool` | `SELECT FOR UPDATE` 행 잠금 (현재 미사용 — ADR-RES-001 참고) |
| `getOperatingHours(string $calleeCode)` | `string $calleeCode` | `array{startTime: string, endTime: string}` | 운영 시간 조회 (형식: `H:i`) |
| `countReservationsInSlot(string $calleeCode, string $slotTime)` | `calleeCode`, `slotTime` | `int` | 슬롯 내 예약 건수 |

**O2O 캘린더 (4메서드)**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `insertO2oEvent(array $data)` | `['callee_code', 'event_start', 'event_end', 'memo']` | `int` | O2O 일정 삽입, 삽입 ID 반환 |
| `findO2oEventById(int $id)` | `int $id` | `?array` | ID로 O2O 일정 조회 |
| `getO2oEvents(string $calleeCode, string $date)` | `calleeCode`, `date` | `array[]` | 특정 날짜 O2O 일정 목록 (`event_start`, `event_end` 포함) |
| `deleteO2oEvent(int $id)` | `int $id` | `bool` | O2O 일정 삭제 |

**월간 캘린더 (3메서드)**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `getMonthlyReservationCounts(string $calleeCode, int $year, int $month)` | `calleeCode`, `year`, `month` | `array<string, int>` (`'YYYY-MM-DD' => count`) | 날짜별 예약 건수 |
| `getMonthlyAvailableSlotFlags(string $calleeCode, int $year, int $month)` | `calleeCode`, `year`, `month` | `array<string, bool>` (`'YYYY-MM-DD' => hasAvailableSlot`) | 날짜별 예약 가능 슬롯 존재 여부 |
| `getMonthlyO2oEventDates(string $calleeCode, int $year, int $month)` | `calleeCode`, `year`, `month` | `string[]` | O2O 일정이 있는 날짜 목록 (`YYYY-MM-DD`) |

**통화 상태 (3메서드)**

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `updateCallStatus(int $id, string $status)` | `id`, `status` | `bool` | CallStatus 갱신 |
| `getCallStatus(int $id)` | `int $id` | `string` | 현재 CallStatus 조회 |
| `findByCallStatus(string $calleeCode, string $status)` | `calleeCode`, `status` | `array[]` | 특정 CallStatus 예약 목록 |

#### 3.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder 우선. 월간 캘린더 집계 쿼리는 `$db->query()` + named binding |
| DB 연결 | Aurora MySQL (RDS Proxy, IAM Auth) |
| 소유권 검증 | `findByIdAndAcId()` — Repository 레벨에서 `ac_id` 조건 내장 (OWASP API1:2023 BOLA 대응) |

#### 3.2.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| DB 쿼리 실패 | CI4 Database Exception 전파 → Controller에서 `respondError('INTERNAL', ..., 500)` 응답 |
| `findById()` 미존재 | `null` 반환 (예외 없음). Controller에서 404 `NOT_FOUND` 처리 |
| `updateStatus()` 실패 | `false` 반환 → Controller에서 500 `INTERNAL` 처리 |

**소유권 검증 쿼리 패턴 (OWASP API1:2023 BOLA 대응):**
```sql
-- findByIdAndAcId: 자신의 예약만 접근 허용
SELECT * FROM tb_reservation
WHERE id = :id AND ac_id = :ac_id AND deleted_at IS NULL
```

#### 3.2.5 Data Flow (데이터 흐름)

```
ReservationController::insertReservation()
  └─ ReservationService::validateReservationRows(revRows)
        ├─ [checkReservation] → Exception 가능
        ├─ [checkReservationDateTimeCnt] → Exception 가능
        └─ [checkReservationDateCnt] → Exception 가능
  └─ ReservationRepository::insert(data)

CalendarController::calendar()
  └─ CalendarHelper::buildMonthData(month)

O2oCalendarController::o2oCalendar()
  └─ shopRepository::calendarSchedule(month, ...)
  └─ shopRepository::standbyCalendarSchedule(month, ...)
  └─ CalendarHelper::buildMonthData(month)
```

**PHP 시그니처:**

```php
interface ReservationRepositoryInterface
{
    // 예약 기본 CRUD
    public function insert(array $data): int;
    public function findById(int $id): ?array;
    public function findByIdAndAcId(int $id, int $acId): ?array;
    public function updateStatus(int $id, string $status): bool;
    public function delete(int $id): bool;

    // 사용자 예약 조회
    public function findByAcId(int $acId, int $page, int $perPage): array;
    public function countByAcId(int $acId): int;
    public function findUpcomingByAcId(int $acId): array;
    public function findCompletedByAcId(int $acId): array;

    // 상담사 예약 조회
    public function findByCalleeCode(string $calleeCode, int $page, int $perPage): array;
    public function countByCalleeCode(string $calleeCode): int;
    public function findByCalleeCodeAndDate(string $calleeCode, string $date): array;
    public function findUpcomingByCalleeCode(string $calleeCode): array;

    // 슬롯 관리
    public function getReservedSlots(string $calleeCode, string $date): array;
    public function isSlotAvailable(string $calleeCode, string $slotTime): bool;
    public function lockSlot(string $calleeCode, string $slotTime): bool;
    public function getOperatingHours(string $calleeCode): array;
    public function countReservationsInSlot(string $calleeCode, string $slotTime): int;

    // O2O 캘린더
    public function insertO2oEvent(array $data): int;
    public function findO2oEventById(int $id): ?array;
    public function getO2oEvents(string $calleeCode, string $date): array;
    public function deleteO2oEvent(int $id): bool;

    // 월간 캘린더
    public function getMonthlyReservationCounts(string $calleeCode, int $year, int $month): array;
    public function getMonthlyAvailableSlotFlags(string $calleeCode, int $year, int $month): array;
    public function getMonthlyO2oEventDates(string $calleeCode, int $year, int $month): array;

    // 통화 상태
    public function updateCallStatus(int $id, string $status): bool;
    public function getCallStatus(int $id): string;
    public function findByCallStatus(string $calleeCode, string $status): array;
}
```

---

## 4. External Interfaces (외부 인터페이스)

Reservation 모듈은 외부 서비스 연동이 없다. 모든 데이터 접근은 내부 Aurora MySQL DB를 통해 이루어진다.

| 구분 | 내용 |
|------|------|
| 외부 API 연동 | 없음 |
| 외부 DB 연동 | 없음 |
| 메시지 큐 연동 | 없음 |
| 파일 스토리지 연동 | 없음 |
| 푸시 알림 연동 | 없음 |

**모듈 간 통신 원칙**: 다른 모듈이 예약 데이터를 필요로 하는 경우, `ReservationServiceInterface`를 `service()` DI를 통해 주입받아 사용한다. 직접 DB 테이블 접근은 허용하지 않는다.

---

## 5. Events and Signals (이벤트 계약)

> **[RESV-DEF-012 반영]**: 이벤트 트리거 URL을 Routes.php 실제 코드 기준으로 전면 수정. EVT-RES-006(O2O 삭제)은 미구현 상태로 표기.

MIL-STD-498 IDD §5 — Reservation 모듈은 외부 메시지/이벤트 연동이 없는 Self-contained 모듈이다. 아래 내부 상태 전이 이벤트만 존재한다.

| 이벤트 ID | 이벤트명 | 트리거 | 발신 컴포넌트 | 처리 내용 |
|---------|--------|--------|------------|---------|
| EVT-RES-001 | 예약 생성 | `POST /api/reservations/insert-reservation` | `ReservationController` | `validateReservationRows()` → `insert()` → 슬롯 예약 완료 |
| EVT-RES-002 | 통화 상태 전이 (대기→통화중) | `POST /api/reservations/call` (`status→on`) | `ReservationController` | `resolveCallStatus(row)` → 통화 연결 처리 |
| EVT-RES-003 | 통화 상태 전이 (통화중→종료) | `POST /api/reservations/call` (`status→closed`) | `ReservationController` | `resolveCallStatus(row)` → 통화 종료 처리 |
| EVT-RES-004 | 예약 취소 | `POST /api/reservations/call` (cancellation flow) | `ReservationController` | 상태 갱신 처리 |
| EVT-RES-005 | O2O 캘린더 조회 | `POST /api/o2o-calendars/o2o-calendar` | `O2oCalendarController` | `calendarSchedule()` + `standbyCalendarSchedule()` + `buildMonthData()` |
| EVT-RES-006 | O2O 일정 삭제 | 미구현 (라우트 없음) | — | **미구현**: O2O 일정 삭제 EP가 존재하지 않는다. Routes.php에 등록된 라우트 없음 |

**외부 이벤트 발행**: Reservation 모듈은 외부 이벤트(SNS/SQS)를 발행하지 않는다. 크로스 도메인 연동이 필요한 경우 향후 Outbox Pattern 도입을 검토한다.

---

## 6. Error Handling Contract (에러 처리 계약)

> **[RESV-DEF-015 관련]**: 에러 응답은 HTTP 상태코드가 SSOT. `respondError()` 호출 기준으로 4xx/5xx + JSON 포맷 반환. `HTTP 200 + status='error'` 레거시 패턴은 사용하지 않는다.

MIL-STD-498 IDD §6 — Reservation 모듈 전체 에러 처리 원칙 및 예외 타입을 명세한다.

### 6.1 에러 응답 표준

모든 에러는 CLAUDE.md API 응답 표준에 따라 아래 포맷을 준수한다:

```json
{
    "error": {
        "code": "CONFLICT",
        "message": "해당 슬롯은 이미 예약되었습니다."
    }
}
```

**HTTP 상태코드 매핑**:

| HTTP 상태코드 | 에러 코드 | 사용 조건 |
|------------|---------|---------|
| 400 | `INVALID_INPUT` | 필수 파라미터 누락, 잘못된 형식 |
| 403 | `FORBIDDEN` | 차단 상태, 권한 없음, 시간 윈도우 외 통화 시도 |
| 404 | `NOT_FOUND` | 예약/아이템/상담사 미존재 |
| 409 | `CONFLICT` | 중복 예약, 슬롯 건수 초과 |
| 500 | `INTERNAL` | DB 오류, 예약 등록 실패, 캘린더 조회 실패 |

### 6.2 예외 클래스 정의

| 예외 클래스 | 경로 | 발생 조건 | HTTP 상태코드 | 에러 코드 |
|------------|------|---------|------------|---------|
| `InvalidSlotException` | `Exceptions/InvalidSlotException.php` | 필수 파라미터 누락 / 잘못된 날짜 | 400 | `INVALID_INPUT` |
| `SlotConflictException` | `Exceptions/SlotConflictException.php` | 중복 예약 / 건수 초과 | 409 | `CONFLICT` |
| `ReservationNotFoundException` | `Exceptions/ReservationNotFoundException.php` | 존재하지 않거나 소유하지 않은 예약 접근 | 404 | `NOT_FOUND` |

### 6.3 에러 응답 코드 예시

```php
// ReservationController — 실제 respondError 호출 패턴
return $this->respondError('INVALID_INPUT', lang('Error.items.empty'), 400);
return $this->respondError('CONFLICT', lang('Error.reservation.duplicate'), 409);
return $this->respondError('NOT_FOUND', lang('Error.reservation.notFound'), 404);
return $this->respondError('INTERNAL', lang('Error.items.list.empty'), 500);
return $this->respondError('FORBIDDEN', lang('Error.reservation.blocked'), 403);
```

---

## 7. Data Formats and Encoding (데이터 포맷 및 인코딩)

MIL-STD-498 IDD §7 — Reservation 모듈의 인터페이스 데이터 포맷, DTO 정의, 인코딩 규칙을 명세한다.

### 7.1 공통 인코딩 규칙

| 항목 | 규칙 |
|------|------|
| 문자 인코딩 | UTF-8 (utf8mb4) 전 레벨 통일 |
| 성공 응답 | `{ "data": {...} }` (HTTP 200) |
| 에러 응답 | `{ "error": { "code": "...", "message": "..." } }` (HTTP 4xx/5xx) |
| API 응답 키 | DB `snake_case` → API `camelCase` 변환 필수 |

> **날짜/시각 현황**: 현재 코드는 `H:i` 형식을 슬롯 시각으로 사용한다. ISO 8601 UTC(`YYYY-MM-DDTHH:MM:SSZ`) 형식으로의 전환은 페이즈 2 개선 대상(RESV-DEF-010).

### 7.2 슬롯 목록 응답

> **[RESV-DEF-005 반영]**: 코드 실제 반환 구조(`time: H, min: int, status: string`)로 수정.

```json
// GET /api/reservations/get-schedule?itCode=IT001&weekDay=Tue&date=2026-04-15
{
    "data": {
        "dayCnt": 7,
        "todayCheck": true,
        "today": "2026-04-15",
        "weekDay": "Tue",
        "items": [
            {
                "date": "2026-04-15",
                "weekDay": "Tue",
                "time": "10",
                "min": 0,
                "start": "10:00",
                "status": "able"
            },
            {
                "date": "2026-04-15",
                "weekDay": "Tue",
                "time": "10",
                "min": 20,
                "start": "10:20",
                "status": "com"
            },
            {
                "date": "2026-04-15",
                "weekDay": "Tue",
                "time": "10",
                "min": 40,
                "start": "10:40",
                "status": "end"
            }
        ]
    }
}
```

### 7.3 예약 생성 요청/응답

> **[RESV-DEF-006, RESV-DEF-014 반영]**: 요청 필드명(`revRow`, `ceCode`)과 응답 필드(`rvNo`만 반환)를 API 문서 기준으로 수정. 확장 응답(id, acId, calleeCode, slotTime) 불필요.

```json
// 요청: POST /api/reservations/insert-reservation
// Header: X-CSRF-TOKEN: {csrf_token}, X-Forwarded-Proto: https
// Cookie: hc_access={jwt_token}
{
    "itCode": "IT001",
    "ceCode": "CE001",
    "stCode": "ST001",
    "revRow": [
        {
            "date": "2026-04-15",
            "time": "10:00",
            "min": 30
        }
    ]
}

// 응답: HTTP 200
{
    "data": {
        "rvNo": 12345
    }
}
```

**에러 응답 예시**:

```json
// HTTP 409 — 중복 예약
{
    "error": {
        "code": "CONFLICT",
        "message": "해당 슬롯은 이미 예약되었습니다."
    }
}

// HTTP 403 — 차단 상태
{
    "error": {
        "code": "FORBIDDEN",
        "message": "차단 상태로 예약이 불가합니다."
    }
}

// HTTP 500 — 등록 실패
{
    "error": {
        "code": "INTERNAL",
        "message": "예약 등록에 실패하였습니다."
    }
}
```

### 7.4 예약 목록 응답

```json
// POST /api/reservations/get-my-reservation-list
{
    "data": [
        {
            "rvNo": 12345,
            "rvDate": "2026.04.15",
            "rvTime": "10:00",
            "rvMin": 30,
            "ceCode": "CE001",
            "ceNick": "상담사닉네임",
            "revFullDate": "2026.04.15 10:00",
            "callStatus": "standby",
            "refundCheck": true,
            "payPrice": 11000.0
        }
    ],
    "meta": {
        "currentPage": 1,
        "perPage": 10,
        "total": 35,
        "lastPage": 4
    }
}
```

### 7.5 월간 캘린더 응답

```json
// POST /api/calendars/calendar
// Body: { "month": "2026-04" }
{
    "data": {
        "items": {
            "calendar": {}
        }
    }
}
```

### 7.6 O2O 캘린더 응답

```json
// POST /api/o2o-calendars/o2o-calendar
// Body: { "month": "2026-04", "selectArray": [] }
{
    "data": {
        "items": {
            "calendar": {},
            "schedule": [],
            "people": [],
            "standby": []
        }
    }
}
```

### 7.7 예약 DTO (Reservation)

> **[RESV-DEF-014 반영]**: insert-reservation 응답은 `rvNo`만 반환. `id`, `acId`, `calleeCode`, `slotTime` 등 확장 응답은 현재 미구현.

**예약 등록 응답 DTO** (단순화 기준):

| 필드명 (API) | 타입 | 설명 |
|-------------|------|------|
| `rvNo` | int | 예약 번호 (DB `rv_no` 또는 삽입 ID) |

**예약 목록 항목 DTO** (format() 결과 기준):

| 필드명 (API) | 필드명 (DB) | 타입 | 설명 |
|-------------|-----------|------|------|
| `rvNo` | `rv_no` | int | 예약 번호 |
| `rvDate` | `rv_date` | string | 예약 날짜 (점 구분자) |
| `rvTime` | `rs_time` | string | 예약 시간 ('H:i') |
| `rvMin` | `rv_min` | int | 예약 시간(분) |
| `ceCode` | `ce_code` | string | 상담사 코드 |
| `ceNick` | `ce_nick` | string | 상담사 닉네임 |
| `revFullDate` | — | string | 전체 날짜+시간 문자열 |
| `callStatus` | — | string | `standby`/`on`/`closed` (resolveCallStatus 결과) |
| `refundCheck` | — | bool | 환불 가능 여부 (23시간 기준) |
| `payPrice` | `pd_price` | float | 결제 금액 (pd_price * 1.1) |

---

## 8. 타당성 검토 (Feasibility Review)

> 근거: OWASP API Security Top 10 2023, MIL-STD-498

| 검토 ID | 검토 항목 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|----------|------|------|------|------------|
| FEA-RES-001 | **카운트 기반 중복 예약 차단** | 현행 유지 | 3단계 카운트 검증으로 동일 예약/슬롯 초과/날짜 초과를 방지. 현재 트래픽 수준에서 TOCTOU 위험 낮음 | SELECT FOR UPDATE (향후 전환 검토) | 카운트 기반: 단순, TOCTOU 이론적 가능. SELECT FOR UPDATE: 강력, 잠금 경합 가능 |
| FEA-RES-002 | **ReservationRepository::findByIdAndAcId 소유권 내장** | 필수 유지 | Repository 레벨에서 `ac_id` 조건을 쿼리에 직접 내장하여 BOLA(Broken Object Level Authorization) 방지. OWASP API1:2023 요건 | Controller에서 별도 소유권 검증 | Repository 내장: 인가 누락 불가. Controller 검증: 구현 단순, 누락 위험 |
| FEA-RES-003 | **Self-contained (외부 서비스 미연동)** | 적절 | 예약 데이터는 Aurora MySQL 내부 테이블만 사용. 외부 의존성 없어 장애 격리 자연 달성 | FCM/AlimTalk 알림 즉시 연동 | Self-contained: 복잡도↓. 알림 연동: UX↑, 외부 의존성 추가 |
| FEA-RES-004 | **RPC-style EP URL 유지** | 현행 유지 | 레거시 코드베이스 패턴 일관성. 프론트엔드 연동 변경 없이 유지 가능 | RESTful URL 전환 | RPC-style: 레거시 호환, RESTful 불일치. RESTful: 표준, 마이그레이션 비용 |
| FEA-RES-005 | **공개 EP 인증 면제** | 적절 | get-schedule, calendars/calendar는 사용자 미로그인 상태에서도 필요한 조회 기능. JWT 없이 동작하여 UX 향상 | 모든 EP JWT 필수 | 공개 EP: UX↑, 데이터 노출 최소. 전체 JWT: 보안↑, UX↓ |

---

## 9. 변경 영향 기록 (Change Impact Log)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|----------|----------|--------|----------|
| §1.1 EP 총수 수정: RC5+O2C2+CC1 → RC6+O2C1+CC1 (RESV-DEF-011) | §1.1 식별 테이블 | Routes.php 코드와 일치. ReservationController 6개 EP 정확히 반영 | Routes.php에는 RC 6개, O2C 1개이나 IDD가 RC 5개, O2C 2개로 잘못 기술 |
| §3.1.2 buildScheduleSlots 출력: ISO 8601 UTC → H:i 형식 + status:string (RESV-DEF-005) | IF-INT-001 데이터 요소 | 실제 코드 반환 구조와 일치. TC-RES-042~047 테스트 케이스 기준 정합 | 코드는 H:i + status 반환, IDD는 ISO 8601 UTC + available:bool 명세 불일치 |
| §3.1.2 validateReservationRows: SELECT FOR UPDATE → 카운트 기반 (RESV-DEF-007) | IF-INT-001 데이터 요소 | 실제 validateReservationRows() 구현 방식 반영 | 코드는 카운트 검증 사용, IDD는 SELECT FOR UPDATE 슬롯 잠금 기술 불일치 |
| §3.1.2 createO2oEvent: 미구현 Open Question으로 표기 (RESV-DEF-009) | IF-INT-001 메서드 계약 | 미구현 사실 명시. 구현자가 이미 구현된 것으로 오해 방지 | O2oCalendarController가 실제로 createO2oEvent() 미호출 |
| §3.1.2 format() 출력 필드: IDD 설계 → 코드 실제 반환 필드로 현행화 (RESV-DEF-006) | IF-INT-001 format 메서드 | 실제 formatReservationList()/formatReservationItem() 반환 필드 반영 | IDD의 format() 출력이 실제 코드 반환 필드와 불일치 |
| §5 이벤트 트리거 URL: 설계 URL → Routes.php 실제 URL (RESV-DEF-012) | Events and Signals 표 | 실제 라우트와 일치하는 트리거 URL 명세 | EVT-RES-001~005의 트리거 URL이 실제 Routes.php와 전면 불일치 |
| §5 EVT-RES-006: O2O 삭제 이벤트 미구현 표기 (RESV-DEF-012) | Events and Signals 표 | 미구현 라우트 명확화 | Routes.php에 O2O 삭제 라우트 없음. 이벤트 계약에서 미구현으로 표기 |
| §7.2 슬롯 응답 예시: ISO 8601 UTC → H:i 형식 (RESV-DEF-005) | Data Formats §7.2 | 실제 API 응답과 일치하는 예시 | IDD 응답 예시가 실제 반환 구조와 다름 |
| §7.3 예약 생성 응답: 확장 응답 → rvNo 단순화 (RESV-DEF-006, RESV-DEF-014) | Data Formats §7.3 | API 문서 기준 최소 응답 반영 | 실제 코드는 rv_no만 반환. IDD의 확장 응답(id, acId 등) 현행과 불일치 |
| §10 FR 번호 교정 (RESV-DEF-013) | Requirements Traceability Matrix | SRS §3 FR-RES 번호와 일치 | IDD §10의 FR-RES-004~007이 SRS의 FR-RES-005~008을 1씩 오프셋으로 참조 |

---

## 10. Requirements Traceability Matrix (요구사항 추적성 매트릭스)

> **[RESV-DEF-013 반영]**: FR 번호를 SRS v2.1 §3 기준으로 교정. 이전 IDD의 FR-RES-004(상담사 조회)~FR-RES-007(월간 캘린더)이 실제로 FR-RES-005~FR-RES-008임을 수정.

MIL-STD-498 DI-IPSC-81436 §10 — SRS FR/NFR과 IDD 인터페이스 간 추적성.

| SRS 요구사항 ID | 요구사항명 | 연관 인터페이스 | 인터페이스 타입 |
|---------------|---------|-------------|-------------|
| FR-RES-001 | 슬롯 목록 조회 (공개 EP) | IF-INT-001 (`buildScheduleSlots`), IF-INT-002 (`getReservedSlots`, `getOperatingHours`) | 내부 |
| FR-RES-002 | 예약 생성 | IF-INT-001 (`validateReservationRows`), IF-INT-002 (`insert`) | 내부 |
| FR-RES-003 | 예약 목록 조회 (사용자) | IF-INT-002 (`findByAcId`, `countByAcId`, `findUpcomingByAcId`) | 내부 |
| FR-RES-004 | 예약 상세 조회 | IF-INT-002 (`findByIdAndAcId`) | 내부 |
| FR-RES-005 | 상담사 예약 조회 (role:callee) | IF-INT-002 (`findByCalleeCode`, `countByCalleeCode`, `findByCalleeCodeAndDate`) | 내부 |
| FR-RES-006 | 예약 통화 연결 | IF-INT-001 (`resolveCallStatus`) | 내부 |
| FR-RES-007 | O2O 캘린더 조회 (조회 전용, Open Question OQ-001) | `shopRepository` (직접 주입), `CalendarHelper::buildMonthData` | 내부 |
| FR-RES-008 | 월간 캘린더 조회 (공개 EP) | `CalendarHelper::buildMonthData` | 내부 |
| NFR-RES-001 | 슬롯 생성 정확성 (20분 간격) | IF-INT-001 (`buildScheduleSlots`) | 내부 |
| NFR-RES-002 | 중복 예약 방지 (카운트 기반) | IF-INT-001 (`validateReservationRows` — 3단계 카운트 검증) | 내부 |
| NFR-RES-003 | BOLA 방지 (소유권 검증) | IF-INT-002 (`findByIdAndAcId` — ac_id 조건 내장) | 내부 |
| NFR-RES-004 | Self-contained (외부 의존 없음) | §4 External Interfaces — 외부 IF 없음 명시 | 해당 없음 |
| NFR-RES-005 | 에러 응답 표준 (HTTP 4xx/5xx SSOT) | §6.1 에러 응답 표준, `respondError()` 패턴 | 내부 |

---

## 11. Document History (변경 로그)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | 1.0.0 | 최초 작성 (내부 IF 2개, 예외 4종, 응답 포맷 3종) | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 IDD 표준 전면 전환. Scope, References, 인터페이스별 5-subsection 구조화(IF-INT 2개), External IF 없음 명시, Events(6건), ErrorHandlingContract(예외 4종+동시성 원칙), DataFormats(7종 JSON 예시+DTO), Feasibility Review(5건), Requirements Traceability Matrix(13건) 신설 | jypark |
| 2026-04-21 | 2.1.0 | API ↔ IEEE 대조 리포트 [A] 이슈 반영. EP 수 수정(RC6+O2C1+CC1), buildScheduleSlots 출력 구조 수정(H:i+status), validateReservationRows 카운트 기반 전환, createO2oEvent 미구현 표기, format() 필드 현행화, 이벤트 트리거 URL 전면 수정, DTO 단순화(rvNo), FR 추적성 번호 교정 | jypark |
