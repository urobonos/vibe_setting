---
문서명: Reservation 모듈 소프트웨어 설계 명세서 (SDD)
문서ID: SDD-RES-001
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
적용 표준: IEEE Std 1016-2009 / ISO/IEC/IEEE 42010:2011
대상 시스템: HongCafe Global Backend — Reservation Module
관련 문서:
  - reservation-srs.md (SRS-RES-001)
  - reservation-idd.md (IDD-RES-001)
  - docs/api-specification.md
---

# Reservation 모듈 소프트웨어 설계 명세서 (SDD)
# Software Design Description — Reservation Module

---

## 1. 개요 (Introduction)

### 1.1 목적 (Purpose)

본 문서는 HongCafe Global Backend Reservation 모듈의 내부 설계를 IEEE Std 1016-2009 / ISO/IEC/IEEE 42010:2011 표준에 따라 명세한다. 3개 컨트롤러, `ReservationService`(4 메서드), `CalendarHelper`(static), `ReservationRepository`(28 메서드)의 구조와 책임, DB 스키마, 시퀀스 다이어그램, 아키텍처 결정 기록(ADR)을 포함한다.

### 1.2 범위 (Scope)

Reservation 모듈은 `app/Modules/Reservation/` 경로에 위치한다. 외부 서비스 의존성 없이 자체 완결(Self-contained)로 동작하며, Aurora MySQL DB 내부 테이블만 사용한다.

### 1.3 용어 정의 (Definitions)

| 용어 | 정의 |
|------|------|
| ADR | Architecture Decision Record — 아키텍처 결정 기록 |
| DI | Dependency Injection — 의존성 주입 |
| Slot | 예약 가능한 20분 단위 시간 구간 |
| RPC-style EP | RESTful 자원 중심이 아닌 동사 포함 URL 패턴 (예: `/insert-reservation`) |
| Open Question | 구현 완성 여부를 담당자가 결정해야 하는 미완성 기능 항목 |

### 1.4 참고 문서 (References)

| 문서 | 경로 |
|------|------|
| 요구사항 명세서 | `docs/specs/reservation-srs.md` (SRS-RES-001) |
| 인터페이스 설계 명세서 | `docs/specs/reservation-idd.md` (IDD-RES-001) |
| API 명세서 | `api-docs/reservation/reservation-api.md` |
| 프로젝트 지침 | `CLAUDE.md` |
| API ↔ IEEE 대조 리포트 | `docs/output/ieee-review/reservation-api-vs-ieee-20260421.md` |

---

## 2. 모듈 구조 (Module Architecture)

### 2.1 디렉토리 구조

```
app/Modules/Reservation/
├── Config/
│   ├── Routes.php                    # 8개 EP 명시적 등록 (RPC-style)
│   └── Services.php                  # DI 바인딩 (모듈 분산)
├── Controllers/
│   ├── ReservationController.php     # 스케줄 조회, 예약 CRUD, 통화 연결
│   ├── O2oCalendarController.php     # O2O 캘린더 조회 (상담사 전용)
│   └── CalendarController.php        # 월간 캘린더 조회
├── Services/
│   └── ReservationService.php        # 4 메서드: 슬롯 생성, 검증, 포맷, 상태 해석
├── Helpers/
│   └── CalendarHelper.php            # static 메서드: 월간 캘린더 데이터 생성
├── Repositories/
│   └── ReservationRepository.php     # 28 메서드: DB 접근 전담
├── Models/
│   └── ReservationModel.php
├── Entities/
│   └── ReservationEntity.php
└── Interfaces/
    ├── ReservationServiceInterface.php       # 4 메서드 계약
    └── ReservationRepositoryInterface.php    # 28 메서드 계약
```

### 2.2 의존성 그래프

> **[RESV-DEF-009 반영]**: `O2oCalendarController`는 `ReservationServiceInterface` 대신 `shopRepository`를 직접 주입한다.

```
ReservationController
  └──→ ReservationService (via ReservationServiceInterface)
          └──→ ReservationRepository (via ReservationRepositoryInterface)

O2oCalendarController
  └──→ shopRepository (직접 주입 — ReservationServiceInterface 미사용)
  └──→ CalendarHelper (static, 직접 호출)

CalendarController
  └──→ CalendarHelper (static, 직접 호출)
  └──→ ReservationRepository (via ReservationRepositoryInterface)
```

**설계 원칙**:
- Controller는 Service 인터페이스만 참조한다.
- Service는 Repository 인터페이스만 참조한다.
- `CalendarHelper`는 상태를 보유하지 않는 유틸리티이므로 DI 없이 Controller에서 직접 정적 호출한다.
- `O2oCalendarController`의 `shopRepository` 직접 주입은 현재 구현 상태를 반영한다 (Open Question OQ-001).

---

## 3. Controllers 설계

### 3.1 ReservationController

**파일**: `app/Modules/Reservation/Controllers/ReservationController.php`

**책임**: 스케줄 슬롯 조회, 예약 등록/목록/상세 조회, 상담사 예약 조회, 통화 연결.

#### 메서드 목록

> **[RESV-DEF-001, RESV-DEF-002 반영]**: RPC-style URL + 실제 HTTP 메서드로 전면 교체.

| 번호 | 메서드명 | HTTP | 경로 | 인증 | 역할 필터 | CSRF |
|------|----------|------|------|------|----------|------|
| 1 | `getSchedule()` | GET | `/api/reservations/get-schedule` | — (공개) | — | — |
| 2 | `insertReservation()` | POST | `/api/reservations/insert-reservation` | JWT | — | 필요 |
| 3 | `getMyReservation()` | POST | `/api/reservations/get-my-reservation` | JWT | — | 필요 |
| 4 | `getMyReservationList()` | POST | `/api/reservations/get-my-reservation-list` | JWT | — | 필요 |
| 5 | `getCalleeReservationList()` | POST | `/api/reservations/get-callee-reservation-list` | JWT | callee | 필요 |
| 6 | `call()` | POST | `/api/reservations/call` | JWT | — | 필요 |

**의존성**: `ReservationServiceInterface`

**필터 체인**: `ratelimit` → `csrftoken`(POST만) → `auth`(JWT 필요 EP만) → `role:callee`(상담사 EP만) → Controller

---

### 3.2 O2oCalendarController

**파일**: `app/Modules/Reservation/Controllers/O2oCalendarController.php`

**책임**: 상담사 전용 O2O 캘린더 조회. `RoleFilter:callee`로 접근 제어.

> **[RESV-DEF-009 반영]**: 현재 구현은 조회 전용이다. SDD v2.0이 설계한 `createO2oEvent()` 기반 O2O 일정 등록 기능은 미구현이다.
>
> **Open Question (OQ-001)**: `O2oCalendarController`가 조회 전용으로 유지될 것인지, 또는 SDD 설계대로 O2O 일정 등록 기능을 완성할 것인지 담당자(jypark) 결정 필요.

#### 메서드 목록

> **[RESV-DEF-001, RESV-DEF-002 반영]**: 실제 Routes.php 기준 URL 반영.

| 번호 | 메서드명 | HTTP | 경로 | 인증 | 역할 필터 | CSRF |
|------|----------|------|------|------|----------|------|
| 1 | `o2oCalendar()` | POST | `/api/o2o-calendars/o2o-calendar` | JWT | callee | 필요 |

**현재 구현 의존성**:
- `shopRepository` — 직접 주입 (`calendarSchedule()`, `standbyCalendarSchedule()` 호출)
- `CalendarHelper` — static 직접 호출 (`buildMonthData($month)`)

**미구현 기능 (설계 목표 vs 현황)**:

| 항목 | SDD v2.0 설계 | 현재 구현 상태 |
|------|-------------|-------------|
| O2O 일정 등록 | `ReservationService::createO2oEvent()` 호출 → `tb_o2o_calendar` 삽입 | 미구현 |
| ReservationServiceInterface 사용 | 의존성 주입 | `shopRepository` 직접 주입으로 대체 |

---

### 3.3 CalendarController

**파일**: `app/Modules/Reservation/Controllers/CalendarController.php`

**책임**: 월간 캘린더 데이터 조회. `CalendarHelper.buildMonthData()` static 메서드 활용.

#### 메서드 목록

> **[RESV-DEF-001, RESV-DEF-002 반영]**: 실제 Routes.php 기준 URL 반영.

| 번호 | 메서드명 | HTTP | 경로 | 인증 | 역할 필터 | CSRF |
|------|----------|------|------|------|----------|------|
| 1 | `calendar()` | POST | `/api/calendars/calendar` | — (공개) | — | — |

**의존성**: `CalendarHelper` (static)

---

## 4. Services 설계

### 4.1 ReservationService (4 메서드)

**파일**: `app/Modules/Reservation/Services/ReservationService.php`

**책임**: 슬롯 생성, 예약 유효성 검증, 응답 포맷팅, CallStatus 전이 해석.

> **[RESV-DEF-009 반영]**: `createO2oEvent()` 메서드는 현재 미구현 상태이므로 메서드 수를 5 → 4로 수정한다.

#### 메서드 상세

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `buildScheduleSlots(string $itCode, string $weekDay, string $date): array` | itCode, weekDay, date(YYYY-MM-DD) | `array{time: string, min: int, status: string}[]` | 운영 시간을 20분 단위 슬롯으로 분할. 상태는 `able`(가용), `com`(예약됨), `end`(과거) |
| `validateReservationRows(array $revRows): void` | `[['date', 'time', 'min'], ...]` | `void` (실패 시 예외) | 예약 슬롯 유효성 검증: 중복 여부, 슬롯당 건수, 날짜당 건수 |
| `format(array $reservationData): array` | DB 조회 결과 배열 | `array` | DB snake_case → API camelCase 변환 |
| `resolveCallStatus(array $row): string` | 예약 row (ca_id, 시간 범위 포함) | `string` (`standby`/`on`/`closed`) | 예약 통화 상태를 시간 윈도우 기반으로 해석 |

> **미구현 메서드 (Open Question OQ-001)**:
> - `createO2oEvent(array $params): void` — O2O 일정 삽입 기능. 현재 `O2oCalendarController`가 직접 `shopRepository`를 호출하여 우회하고 있다.

---

### 4.2 buildScheduleSlots 알고리즘

> **[RESV-DEF-005 반영]**: 슬롯 상태를 `available: bool` 대신 `status: string('able'/'com'/'end')`으로 기술. `time`은 ISO 8601 UTC가 아닌 `H:i` 형식.

```
buildScheduleSlots(itCode: string, weekDay: string, date: string): array

입력:
  - itCode:   아이템 코드
  - weekDay:  요일 문자열
  - date:     조회 날짜 (YYYY-MM-DD)

처리:
  1. availableTimes = repository.getAvailableTimes(itCode, weekDay)
     → string[] (가용 시간 목록, 'H' 형식)
  2. reservedTimes = repository.getReservedTimes(itCode, date)
     → string[] (예약된 시간 목록, 'H:i' 형식)
  3. today = date('Y-m-d', time())   // ※ DateTimeImmutable 전환 필요 (RESV-DEF-010)
  4. for each hour in availableTimes:
       for each min in ['00', '20', '40']:
         slotKey = hour + ':' + min
         if date < today: status = 'end'
         elif slotKey IN reservedTimes: status = 'com'
         else: status = 'able'
         slots[] = {
           date: date,
           weekDay: weekDay,
           time: hour,           // 'H' 형식
           min: int(min),        // 0, 20, 40
           start: slotKey,       // 'H:i' 형식
           status: status        // 'able' | 'com' | 'end'
         }
  5. return { dayCnt, todayCheck, today, weekDay, items: slots }

상수: SLOT_INTERVAL_MINUTES = 20
```

---

### 4.3 validateReservationRows 검증 로직

> **[RESV-DEF-007 반영]**: SDD v2.0의 `SELECT FOR UPDATE` 기반 설계를 실제 카운트 기반 검증으로 현행화.

```
validateReservationRows(revRows: array): void

각 revRow에 대해:
  1. checkReservation(ceCode, date, time, min)
     → 동일 예약 존재 시 Exception (CONFLICT / HTTP 409)

  2. checkReservationDateTimeCnt(ceCode, date, time)
     → null 반환 또는 cnt >= 1 시 Exception (CONFLICT / HTTP 409)
     (동일 날짜+시간 슬롯당 1건 초과 거부)

  3. checkReservationDateCnt(ceCode, date)
     → null 반환 또는 cnt > 2 시 Exception (CONFLICT / HTTP 409)
     (동일 날짜 2건 초과 거부. cnt=2는 통과)
```

> **[ADR-RES-001 갱신 참고]**: 현재 구현은 `SELECT FOR UPDATE` 없이 카운트 검증만 사용한다. 고부하 동시성 환경에서 TOCTOU 취약점 가능성이 있으나 현재 사용 패턴에서는 수용 가능 수준으로 판단한다. 향후 트래픽 증가 시 재검토 필요.

---

### 4.4 resolveCallStatus 상태 해석 규칙

| 조건 | 반환값 | 설명 |
|------|--------|------|
| `ca_id` 존재 + `NOW() > ca_end_time` | `'closed'` | 통화 종료 |
| `ca_id` 존재 + `ca_start_time <= NOW() <= ca_end_time` | `'on'` | 통화 중 |
| `ca_id` 존재 + `NOW() < ca_start_time` | `'standby'` | 통화 대기 |
| `ca_id` 없음 + `NOW() > rv_date + rv_min` | `'closed'` | 통화 종료 |
| `ca_id` 없음 + 시작-종료 범위 내 | `'on'` | 통화 중 |
| `ca_id` 없음 + `NOW() < rv_date` | `'standby'` | 통화 대기 |

---

## 5. CalendarHelper 설계

**파일**: `app/Modules/Reservation/Helpers/CalendarHelper.php`

**설계 방식**: 상태를 보유하지 않는 순수 함수형 유틸리티. 모든 메서드를 `static`으로 구현하여 DI 없이 직접 호출 가능.

```php
<?php
declare(strict_types=1);

namespace App\Modules\Reservation\Helpers;

class CalendarHelper
{
    public const int SLOT_INTERVAL_MINUTES = 20;
    public const int SLOTS_PER_HOUR = 3;

    /**
     * 주어진 YYYY-MM 형식 월의 캘린더 데이터를 생성한다.
     *
     * @param string $month  'YYYY-MM' 형식 월 문자열
     * @return array         calendar 배열
     */
    public static function buildMonthData(string $month): array;

    /**
     * 해당 월의 총 일수를 반환한다.
     */
    public static function getDaysInMonth(int $year, int $month): int;

    /**
     * 해당 월의 첫 날 요일을 반환한다 (0=일요일, 6=토요일).
     */
    public static function getFirstDayOfWeek(int $year, int $month): int;
}
```

**응답 구조 예시**:

```json
{
  "data": {
    "items": {
      "calendar": {}
    }
  }
}
```

---

## 6. ReservationRepository 설계 (28 메서드)

**파일**: `app/Modules/Reservation/Repositories/ReservationRepository.php`

### 6.1 예약 기본 CRUD (5 메서드)

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `insert(array $data): int` | `['ac_id', 'callee_code', 'slot_time', 'memo']` | `int` | 예약 삽입, 삽입 ID 반환 |
| `findById(int $id): ?array` | `id` | `?array` | ID로 예약 조회 (없으면 null) |
| `findByIdAndAcId(int $id, int $acId): ?array` | `id`, `acId` | `?array` | ID + 소유권(ac_id) 조건 조회 |
| `updateStatus(int $id, string $status): bool` | `id`, `status` | `bool` | 예약 상태 갱신 |
| `delete(int $id): bool` | `id` | `bool` | 논리 삭제 (deleted_at 설정) |

### 6.2 사용자 예약 조회 (4 메서드)

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `findByAcId(int $acId, int $page, int $perPage): array` | `acId`, `page`, `perPage` | `array{data, total}` | 사용자 예약 목록 페이지네이션 |
| `countByAcId(int $acId): int` | `acId` | `int` | 사용자 예약 총 건수 |
| `findUpcomingByAcId(int $acId): array` | `acId` | `array[]` | slot_time > NOW(), status='reserved' |
| `findCompletedByAcId(int $acId): array` | `acId` | `array[]` | status='completed' 목록 |

### 6.3 상담사 예약 조회 (4 메서드)

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `findByCalleeCode(string $calleeCode, int $page, int $perPage): array` | `calleeCode`, `page`, `perPage` | `array{data, total}` | 상담사 예약 목록 페이지네이션 |
| `countByCalleeCode(string $calleeCode): int` | `calleeCode` | `int` | 상담사 예약 총 건수 |
| `findByCalleeCodeAndDate(string $calleeCode, string $date): array` | `calleeCode`, `date` | `array[]` | 상담사 특정 날짜 예약 목록 |
| `findUpcomingByCalleeCode(string $calleeCode): array` | `calleeCode` | `array[]` | 상담사 예정 예약 목록 |

### 6.4 슬롯 관리 (5 메서드)

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `getReservedSlots(string $calleeCode, string $date): array` | `calleeCode`, `date` | `string[]` | 특정 날짜 예약된 슬롯 시간 목록 ('H:i') |
| `isSlotAvailable(string $calleeCode, string $slotTime): bool` | `calleeCode`, `slotTime` | `bool` | 슬롯 가용성 확인 |
| `lockSlot(string $calleeCode, string $slotTime): bool` | `calleeCode`, `slotTime` | `bool` | SELECT FOR UPDATE 슬롯 잠금 (미사용 — ADR-RES-001 갱신 참고) |
| `getOperatingHours(string $calleeCode): array` | `calleeCode` | `array{startTime, endTime}` | 상담사 운영 시간 조회 |
| `countReservationsInSlot(string $calleeCode, string $slotTime): int` | `calleeCode`, `slotTime` | `int` | 슬롯 예약 건수 |

### 6.5 O2O 캘린더 (4 메서드)

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `insertO2oEvent(array $data): int` | `['callee_code', 'event_start', 'event_end', 'memo']` | `int` | O2O 일정 삽입, 삽입 ID 반환 |
| `findO2oEventById(int $id): ?array` | `id` | `?array` | O2O 일정 조회 |
| `getO2oEvents(string $calleeCode, string $date): array` | `calleeCode`, `date` | `array[]` | 특정 날짜 O2O 일정 목록 |
| `deleteO2oEvent(int $id): bool` | `id` | `bool` | O2O 일정 삭제 |

### 6.6 월간 캘린더 (3 메서드)

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `getMonthlyReservationCounts(string $calleeCode, int $year, int $month): array` | `calleeCode`, `year`, `month` | `array<string, int>` | `['YYYY-MM-DD' => count]` |
| `getMonthlyAvailableSlotFlags(string $calleeCode, int $year, int $month): array` | `calleeCode`, `year`, `month` | `array<string, bool>` | `['YYYY-MM-DD' => bool]` |
| `getMonthlyO2oEventDates(string $calleeCode, int $year, int $month): array` | `calleeCode`, `year`, `month` | `string[]` | O2O 일정 날짜 목록 ('YYYY-MM-DD') |

### 6.7 통화 상태 (3 메서드)

| 메서드 | 파라미터 | 반환 타입 | 설명 |
|--------|---------|----------|------|
| `updateCallStatus(int $id, string $status): bool` | `id`, `status` | `bool` | CallStatus 갱신 |
| `getCallStatus(int $id): string` | `id` | `string` | 현재 CallStatus 조회 |
| `findByCallStatus(string $calleeCode, string $status): array` | `calleeCode`, `status` | `array[]` | 특정 상태의 예약 목록 |

---

## 7. DB 스키마 설계

### 7.1 tb_reservation

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | `BIGINT UNSIGNED PK AUTO_INCREMENT` | 예약 ID |
| `ac_id` | `BIGINT UNSIGNED NOT NULL` | 사용자 ID (FK → tb_account) |
| `callee_code` | `VARCHAR(50) NOT NULL` | 상담사 코드 (FK → tb_account.ce_code) |
| `slot_time` | `DATETIME NOT NULL` | 예약 슬롯 시간 (UTC) |
| `call_status` | `ENUM('reserved','calling','completed','cancelled') NOT NULL DEFAULT 'reserved'` | 통화 상태 |
| `memo` | `TEXT` | 예약 메모 (nullable) |
| `deleted_at` | `DATETIME` | 논리 삭제 시각 (UTC, nullable) |
| `created_at` | `DATETIME NOT NULL` | 생성 시각 (UTC) |
| `updated_at` | `DATETIME NOT NULL` | 수정 시각 (UTC) |

**인덱스**:
- `idx_ac_id` (`ac_id`) — 사용자 예약 조회 최적화
- `UNIQUE idx_callee_slot` (`callee_code`, `slot_time`) — 슬롯 중복 예약 DB 레벨 차단

---

### 7.2 tb_o2o_calendar

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | `BIGINT UNSIGNED PK AUTO_INCREMENT` | O2O 일정 ID |
| `callee_code` | `VARCHAR(50) NOT NULL` | 상담사 코드 |
| `event_start` | `DATETIME NOT NULL` | 일정 시작 시각 (UTC) |
| `event_end` | `DATETIME NOT NULL` | 일정 종료 시각 (UTC) |
| `memo` | `VARCHAR(255)` | 일정 메모 (nullable) |
| `created_at` | `DATETIME NOT NULL` | 생성 시각 (UTC) |

**인덱스**: `idx_callee_start` (`callee_code`, `event_start`) — 상담사의 특정 날짜 O2O 일정 조회 최적화

---

## 8. 시퀀스 다이어그램

### 8.1 예약 등록 플로우

> **[RESV-DEF-001, RESV-DEF-007 반영]**: RPC URL 및 카운트 기반 검증 반영.

```
Client       ReservationController  ReservationService  ReservationRepository       DB
  |                 |                      |                    |                    |
  |--POST /reservations/insert-reservation-->                   |                    |
  |                 |--validateReservationRows(revRows)-->      |                    |
  |                 |                      |--checkReservation()->                  |
  |                 |                      |<--존재 없음--------|                    |
  |                 |                      |--checkReservationDateTimeCnt()-->      |
  |                 |                      |<--cnt=0------------|                    |
  |                 |                      |--checkReservationDateCnt()-->          |
  |                 |                      |<--cnt<=2-----------|                    |
  |                 |--insert(data)-------->                    |                    |
  |                 |                      |--insert(data)------>                    |
  |                 |                      |                    |--INSERT tb_reservation-->|
  |                 |                      |                    |<--{rv_no}----------|
  |<--200 {rvNo}----|                      |                    |                    |
Alternate (중복/초과):                      |                    |                    |
  |                 |                      |--Exception         |                    |
  |<--409 CONFLICT--|                      |                    |                    |
```

### 8.2 슬롯 조회 플로우

> **[RESV-DEF-001 반영]**: RPC URL 반영. 공개 EP (인증 없음).

```
Client       ReservationController  ReservationService  ReservationRepository
  |                 |                      |                    |
  |--GET /reservations/get-schedule?itCode=..-->                |
  |                 |--buildScheduleSlots(itCode, weekDay, date)-->
  |                 |                      |--getAvailableTimes(itCode, weekDay)-->
  |                 |                      |<--string[]---------|
  |                 |                      |--getReservedTimes(itCode, date)-->
  |                 |                      |<--string[]---------|
  |                 |                      |--[20분 간격 슬롯 생성 루프]
  |                 |                      |--[각 슬롯: status = able/com/end]
  |<--200 {dayCnt, todayCheck, today, weekDay, items[]}|        |
```

### 8.3 통화 연결 플로우

> **[RESV-DEF-001, RESV-DEF-006 반영]**: RPC URL 및 시간 윈도우 검증 반영.

```
Client       ReservationController  ReservationService  ReservationRepository
  |                 |                      |                    |
  |--POST /reservations/call-->             |                    |
  |                 |--resolveCallStatus(row)-->                 |
  |                 |                      |--[시간 윈도우 검증: on/standby/closed]
  |                 |                      |<--status: 'on'-----|
  |                 |--[통화 연결 처리]     |                    |
  |<--200 {connectNumber}|                 |                    |
Alternate (시간 윈도우 외):
  |                 |                      |--status: 'standby'/'closed'
  |<--403 FORBIDDEN-|                      |                    |
```

---

## 9. 아키텍처 결정 기록 (Architecture Decision Records)

### ADR-RES-001: 예약 중복 방지 — 카운트 기반 검증 (갱신)

**상태**: 현행 유지 (갱신)

**결정**: 예약 등록 시 슬롯 가용성 검증을 `validateReservationRows()`의 3단계 카운트 기반 검증으로 처리한다.

**맥락**: SDD v2.0은 `SELECT FOR UPDATE` 기반 슬롯 잠금을 설계했으나, 실제 구현은 카운트 기반 검증(`checkReservation`, `checkReservationDateTimeCnt`, `checkReservationDateCnt`)을 사용한다.

**현재 구현 방식**:
- `checkReservation`: 동일 예약 존재 여부 확인
- `checkReservationDateTimeCnt`: 동일 날짜+시간 슬롯당 예약 건수 (1건 초과 거부)
- `checkReservationDateCnt`: 동일 날짜 최대 예약 건수 (cnt > 2 거부)

**이유**: 현재 사용 패턴(단일 예약, 낮은 동시성)에서 카운트 기반 검증으로 충분한 중복 방지 효과를 얻는다.

**주의**: 고부하 동시성 환경에서는 TOCTOU 취약점이 발생할 수 있다. 트래픽 증가 시 `SELECT FOR UPDATE` 전환 재검토 권고.

**기각된 대안**: Redis 분산 락 → 기각 (외부 의존성 추가, Self-contained 원칙 위반)

---

### ADR-RES-002: CalendarHelper를 static 메서드로 구현

**상태**: 채택 (Accepted)

**결정**: `CalendarHelper`의 `buildMonthData()` 등 모든 메서드를 `static`으로 구현한다.

**이유**:
- 상태를 보유하지 않는 순수 함수형 로직에 static이 적합하다.
- DI 없이 Controller에서 직접 호출 가능하여 의존성 그래프가 단순해진다.
- 단위 테스트 시 인스턴스화 없이 `CalendarHelper::buildMonthData()`로 직접 호출 가능하다.

---

### ADR-RES-003: 슬롯 간격 20분 상수 정의 (런타임 변경 불가)

**상태**: 채택 (Accepted)

**결정**: 슬롯 간격을 `CalendarHelper::SLOT_INTERVAL_MINUTES = 20` 상수로 정의하되 DB 설정이나 환경변수로 외부화하지 않는다.

**이유**:
- 비즈니스 정책 변경 수준의 변경 사항이므로 코드 수정 + 재배포로 처리한다.
- 상수 사용으로 모든 관련 로직에서 동일 간격 값을 보장한다.

---

### ADR-RES-004: O2oCalendarController — 조회 전용 현행 유지 (Open Question)

**상태**: Open Question (OQ-001)

**결정**: `O2oCalendarController`는 현재 조회 전용(`shopRepository.calendarSchedule()` + `standbyCalendarSchedule()`)으로 구현되어 있다. O2O 일정 등록 기능(`createO2oEvent`) 구현 여부는 담당자(jypark) 결정 필요.

**두 가지 선택지**:
1. **현행 유지**: IEEE를 현재 조회 전용 구현에 맞게 유지 (본 문서 기준)
2. **기능 완성**: `ReservationService::createO2oEvent()` 구현 + `O2oCalendarController` 등록 기능 추가

**판단 기준**: SDD v2.0의 O2O 등록 기능이 비즈니스 요건으로 확정된 경우에만 (2)를 선택한다.

---

## 10. 타당성 검토 (Feasibility Review)

### 10.1 설계 타당성

| 항목 | 근거 |
|------|------|
| Self-contained 설계 | 외부 서비스 의존성 없음 → 모듈 테스트 독립성 보장, 외부 장애 영향 없음 |
| 28 메서드 단일 Repository | 예약 도메인의 데이터 접근 전체를 1개 Repository에 응집 → 쿼리 최적화와 트랜잭션 관리 일원화 |
| Interface 기반 설계 | `ReservationServiceInterface`, `ReservationRepositoryInterface` Mock 대체로 단위 테스트 격리 가능 |
| 카운트 기반 중복 방지 | 현재 사용 패턴에 적합. 고부하 시 SELECT FOR UPDATE 전환 재검토 |

---

## 11. 검증 체크리스트 (Verification Checklist)

| 항목 | 검증 방법 |
|------|----------|
| ReservationController 6개 메서드 Routes.php 등록 (RPC-style URL) | 코드 리뷰 |
| O2oCalendarController role:callee 필터 적용 | 라우트 설정 검토 |
| CalendarController Routes.php 등록 (공개 EP) | 코드 리뷰 |
| buildScheduleSlots() 슬롯 상태 able/com/end 반환 | 단위 테스트 |
| validateReservationRows() 3단계 카운트 검증 | 단위 테스트 |
| resolveCallStatus() 시간 윈도우 기반 상태 해석 | 단위 테스트 |
| CalendarHelper.buildMonthData() static 메서드 | 단위 테스트 |
| ReservationRepository 28개 메서드 Interface 일치 | 정적 분석 |
| get-schedule / calendars/calendar 공개 EP 동작 | 통합 테스트 |

---

## 변경 기록 (Change History)

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | v1.0 | 최초 작성 | jypark |
| 2026-04-15 | v2.0 | IEEE 표준 전면 전환. 3-Round Review PASS | jypark |
| 2026-04-21 | v2.1 | API ↔ IEEE 대조 리포트 [A] 이슈 반영 | jypark |

### v2.1 변경 영향 기록 (Change Impact Log)

| 변경 항목 | 개선점 | 수행 이유 |
|----------|--------|----------|
| §3.1 ReservationController 메서드 목록: RESTful URL/메서드 → RPC-style URL + 실제 HTTP 메서드 (RESV-DEF-001, RESV-DEF-002) | Routes.php와 100% 일치. 구현자 혼선 제거 | SSOT = Routes.php 코드. 잘못된 URL이 IEEE에 명세되면 운영 혼란 유발 |
| §3.2 O2oCalendarController: create() → o2oCalendar(), 조회 전용 + Open Question 표기 (RESV-DEF-009) | 현재 구현 상태(조회 전용)를 정확히 반영. 미구현 기능 명확화 | O2oCalendarController가 실제로 shopRepository를 직접 사용하는 사실을 IEEE에 기록 |
| §3.3 CalendarController: getMonthly() → calendar(), GET → POST (RESV-DEF-001, RESV-DEF-002) | Routes.php 기준 일치 | 메서드명과 HTTP 메서드 불일치 해소 |
| §4.1 ReservationService 메서드 수 5 → 4, createO2oEvent() 미구현 표기 (RESV-DEF-009) | 실제 구현된 메서드 수만 계약에 포함 | 미구현 메서드를 계약에 포함하면 구현자가 이미 구현된 것으로 오해할 위험 |
| §4.2 buildScheduleSlots 알고리즘: ISO 8601 UTC → H:i 형식, available:bool → status:string (RESV-DEF-005) | TC-RES-042~047 테스트 케이스와 일치하는 알고리즘 명세 | 실제 코드가 H:i 형식과 able/com/end 상태를 반환하므로 IEEE 설계도 동일하게 기술 |
| §4.2 알고리즘: SELECT FOR UPDATE → 카운트 기반 검증으로 현행화 (RESV-DEF-007) | 실제 validateReservationRows() 구현 방식 반영 | SDD v2.0의 SELECT FOR UPDATE 설계와 실제 구현 불일치 해소 |
| §2.2 의존성 그래프: O2oCalendarController 의존성 현행화 (RESV-DEF-009) | shopRepository 직접 주입 사실 명시 | 구현자가 잘못된 의존성 그래프를 참조하지 않도록 수정 |
