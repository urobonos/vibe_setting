---
문서명: Reservation 모듈 소프트웨어 요구사항 명세서 (SRS)
문서ID: SRS-RES-001
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
적용 표준: IEEE Std 830-1998 / ISO/IEC/IEEE 29148:2018
대상 시스템: HongCafe Global Backend — Reservation Module
관련 문서:
  - reservation-sdd.md (SDD-RES-001)
  - reservation-idd.md (IDD-RES-001)
  - docs/api-specification.md
---

# Reservation 모듈 소프트웨어 요구사항 명세서 (SRS)
# Software Requirements Specification — Reservation Module

---

## 1. 개요 (Introduction)

### 1.1 목적 (Purpose)

본 문서는 HongCafe Global Backend Reservation 모듈의 기능 요구사항(FR) 및 비기능 요구사항(NFR)을 IEEE Std 830-1998 / ISO/IEC/IEEE 29148:2018 표준에 따라 명세한다.

Reservation 모듈은 20분 간격 슬롯 기반 예약 시스템, O2O(Offline-to-Online) 캘린더, 월간 캘린더 조회를 포함한 상담 예약 생애주기 전반을 담당한다. 총 8개 엔드포인트를 제공하며 외부 서비스 의존성 없이 자체 완결(Self-contained)로 동작한다.

### 1.2 범위 (Scope)

| 항목 | 내용 |
|------|------|
| 모듈 경로 | `app/Modules/Reservation/` |
| 컨트롤러 | `ReservationController`, `O2oCalendarController`, `CalendarController` |
| 총 엔드포인트 | 8개 |
| 연관 테이블 | `tb_reservation`, `tb_o2o_calendar`, `tb_account` (참조) |
| 의존 외부 서비스 | 없음 (Self-contained) |
| 슬롯 단위 | 20분 (시간당 3슬롯: 0분, 20분, 40분) |

### 1.3 용어 정의 (Definitions, Acronyms, Abbreviations)

| 용어 | 정의 |
|------|------|
| Slot | 예약 가능한 20분 단위 시간 구간 |
| Schedule | 상담사의 예약 가능 시간표. 운영 시간 내 슬롯 집합 |
| O2O | Offline-to-Online. 오프라인 일정을 온라인 캘린더에 등록하여 해당 슬롯 예약을 차단하는 기능 |
| CallStatus | 상담 통화 상태. `reserved` → `calling` → `completed` / `cancelled` 순으로 전이 |
| CalendarHelper | 월간 캘린더 데이터를 정적 메서드로 생성하는 유틸리티 클래스 |
| Callee | 상담사. `tb_account.ce_code`를 보유한 계정 (`UserRole::Callee`) |
| Caller | 일반 사용자. `ce_code` 없는 계정 (`UserRole::Caller`) |
| RPC-style EP | RESTful 자원 중심이 아닌 동사 포함 URL 패턴. 예: `/insert-reservation`, `/get-schedule` |

### 1.4 참고 문서 (References)

| 문서 | 경로 |
|------|------|
| API 명세서 | `api-docs/reservation/reservation-api.md` |
| 소프트웨어 설계 명세서 | `docs/specs/reservation-sdd.md` (SDD-RES-001) |
| 인터페이스 설계 명세서 | `docs/specs/reservation-idd.md` (IDD-RES-001) |
| 인프라 구성 | `docs/infrastructure.md` |
| 프로젝트 지침 | `CLAUDE.md` |
| API ↔ IEEE 대조 리포트 | `docs/output/ieee-review/reservation-api-vs-ieee-20260421.md` |

### 1.5 문서 개요 (Document Overview)

| 섹션 | 내용 |
|------|------|
| 섹션 2 | 전체 시스템 설명 (컨텍스트, 기능 요약, 사용자 특성, 제약사항) |
| 섹션 3 | 기능 요구사항 (FR-RES-001 ~ FR-RES-008) |
| 섹션 4 | 비기능 요구사항 (NFR-RES-001 ~ NFR-RES-005) |
| 섹션 5 | 유스케이스 (UC-RES-001 ~ UC-RES-003) |
| 섹션 6 | 엔드포인트 목록 |
| 섹션 7 | 타당성 검토 |

---

## 2. 전체 시스템 설명 (Overall Description)

### 2.1 제품 관점 (Product Perspective)

Reservation 모듈은 HongCafe Global Backend의 Modular Monolith 아키텍처 내 독립 Bounded Context(BC)이다. 외부 서비스 연동 없이 내부 Aurora MySQL DB만을 사용한다.

```
[클라이언트 (Next.js / 상담사 앱)]
             │
             ▼
[Reservation Module]
   ReservationController  ──→ [ReservationService]
   O2oCalendarController  ──→    buildScheduleSlots()
   CalendarController     ──→    validate()
                          ──→    format()
                          ──→    resolveCallStatus()
                                     │
                          [ReservationRepository] ──→ [Aurora MySQL]
                          [CalendarHelper (static)]      tb_reservation
                                                         tb_o2o_calendar
```

> **NOTE (RESV-DEF-009)**: `O2oCalendarController`는 현재 조회 전용으로 구현되어 있으며 `createO2oEvent()` 기반의 O2O 일정 등록 기능은 미구현 상태이다. 해당 기능의 구현 여부는 Open Question(OQ-001)으로 별도 결정 필요.

**모듈 간 통신**: 다른 모듈이 예약 데이터를 필요로 하는 경우, `ReservationServiceInterface`를 `service()` DI를 통해 주입받아 사용한다. 직접 DB 테이블 접근은 허용하지 않는다.

### 2.2 제품 기능 요약 (Product Functions)

| 기능 그룹 | 기능 |
|----------|------|
| 스케줄 관리 | 20분 간격 슬롯 생성, 예약 가능 여부 표시 |
| 예약 CRUD | 예약 등록, 목록 조회, 상세 조회 |
| 상담사 기능 | 상담사 전용 예약 조회 (RoleFilter:callee 적용) |
| 통화 연결 | 예약 시간 윈도우 내 통화 연결 |
| O2O 캘린더 | 상담사 전용 월별 캘린더/스케줄/인원 조회 |
| 월간 캘린더 | 월별 캘린더 데이터 조회 |

### 2.3 사용자 특성 (User Characteristics)

| 사용자 유형 | 특성 |
|------------|------|
| 일반 사용자 (Caller) | 스케줄 조회(공개), 예약 등록/상세/목록, 통화 연결 |
| 상담사 (Callee) | 본인 예약 목록 조회, O2O 캘린더 조회 |
| 비인증 사용자 | 스케줄 조회(`get-schedule`), 캘린더 조회(`calendars/calendar`) 가능 |

### 2.4 제약사항 (Constraints)

> **[RESV-DEF-003 반영]**: 모든 EP가 JWT를 필요로 하지 않는다. 공개 EP는 인증 없이 접근 가능하다.

| 제약 유형 | 내용 |
|----------|------|
| 슬롯 단위 | 20분 고정 (런타임 변경 불가. 변경 시 코드 수정 + 재배포 필요) |
| 인증 | **JWT 필수 EP**: `insert-reservation`, `get-my-reservation`, `get-my-reservation-list`, `get-callee-reservation-list`, `call`, `o2o-calendars/o2o-calendar` |
| 공개 EP (인증 불필요) | `GET /api/reservations/get-schedule`, `POST /api/calendars/calendar` — JWT 및 CSRF 검증 생략 |
| 역할 제어 | 상담사 전용 EP(`get-callee-reservation-list`, `o2o-calendars/o2o-calendar`)에 `RoleFilter:callee` 필터 필수 |
| 동시성 | 동일 슬롯 동시 예약은 카운트 기반 검증(`validateReservationRows`)으로 방지. 슬롯당 1건, 날짜당 2건 초과 거부 |
| 시간 | 모든 날짜/시간은 UTC 기준이어야 한다. 현재 코드에서 `date()`/`time()` 함수 사용이 잔존하며 `DateTimeImmutable` 전환이 필요하다 (NFR 개선 대상) |
| 외부 의존 | 모듈 내 외부 서비스(PG, 외부 DB, 메시지 큐) 의존성 없음 |
| 언어 | 에러 메시지는 `lang()` 키 사용. 하드코딩 문자열 금지 |
| EP URL 패턴 | RPC-style kebab-case URL 사용 (`/get-schedule`, `/insert-reservation` 등). RESTful 자원 URL 미사용 |

### 2.5 가정 및 의존성 (Assumptions and Dependencies)

- 예약 중복 방지는 `validateReservationRows()`의 카운트 기반 검증으로 처리된다.
- 상담사 운영 시간은 `tb_account` 또는 별도 설정 테이블에서 조회 가능하다.
- 다른 모듈(예: 알림 모듈)이 예약 완료 이벤트를 필요로 하는 경우, Outbox Pattern 또는 Interface DI를 통해 연동한다.

---

## 3. 기능 요구사항 (Functional Requirements)

### FR-RES-001: 스케줄 슬롯 조회

**요약**: 사용자가 특정 아이템의 예약 가능한 20분 간격 슬롯 목록을 조회할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-RES-001-1 | `ReservationService.buildScheduleSlots(itCode, weekDay, date)`를 호출하여 슬롯 목록을 생성한다 |
| FR-RES-001-2 | 슬롯은 20분 간격(0분, 20분, 40분)으로 생성하며, 시간당 정확히 3개의 슬롯이 생성된다 |
| FR-RES-001-3 | 이미 예약된 슬롯은 `status: 'com'`으로, 과거 슬롯은 `status: 'end'`으로, 가용 슬롯은 `status: 'able'`로 표시한다 |
| FR-RES-001-4 | 조회 대상 날짜는 `date` 파라미터로 전달받는다 (YYYY-MM-DD 형식) |
| FR-RES-001-5 | 요청 파라미터 `itCode`, `weekDay`, `date`는 필수이다. 누락 시 `INVALID_INPUT` (HTTP 400) 반환 |
| FR-RES-001-6 | 본 EP는 공개 EP이다. JWT 인증 및 CSRF 검증 없이 접근 가능하다 |

**선행 조건**: 없음 (공개 EP)

**후행 조건**: 슬롯 목록이 `time` (`H:i` 형식), `min` (int), `status` (string) 포함 JSON 배열로 반환.

**우선순위**: P1 (필수)

**관련 EP**: `GET /api/reservations/get-schedule`

---

### FR-RES-002: 예약 등록

**요약**: 사용자가 특정 상담사의 슬롯을 선택하여 예약을 등록할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-RES-002-1 | `ReservationService.validateReservationRows(revRows)`로 예약 슬롯 유효성을 검증한다 |
| FR-RES-002-2 | 동일 예약 존재 여부를 `checkReservation`으로 확인한다. 중복 시 `CONFLICT` (HTTP 409) 반환 |
| FR-RES-002-3 | 동일 날짜+시간 슬롯당 예약 건수를 `checkReservationDateTimeCnt`로 확인한다. 1건 초과 시 거부 |
| FR-RES-002-4 | 동일 날짜 최대 예약 건수를 `checkReservationDateCnt`로 확인한다. 2건 초과(cnt > 2) 시 거부 |
| FR-RES-002-5 | 차단(reject) 상태인 경우 `FORBIDDEN` (HTTP 403) 반환 |
| FR-RES-002-6 | 유효성 검증 통과 후 `tb_reservation`에 예약 레코드를 삽입하고 `rvNo`를 반환한다 |

**선행 조건**: 사용자가 로그인 상태(`hc_access` JWT 쿠키 유효).

**후행 조건**: `tb_reservation`에 레코드 삽입 완료. 응답: `{ "data": { "rvNo": int } }` (HTTP 200).

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/reservations/insert-reservation`

---

### FR-RES-003: 예약 목록 조회 (사용자)

**요약**: 로그인 사용자가 본인의 예약 목록을 조회할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-RES-003-1 | 로그인 사용자의 예약 목록을 조회한다 |
| FR-RES-003-2 | `limit`, `offset` 파라미터로 페이지네이션을 지원한다 (기본값: limit=10, offset=0) |
| FR-RES-003-3 | 응답 메타 구조: `{ currentPage, perPage, total, lastPage }` (camelCase) |

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/reservations/get-my-reservation-list`

---

### FR-RES-004: 예약 상세 조회

**요약**: 사용자가 특정 예약의 상세 정보를 조회할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-RES-004-1 | 예약 번호(`rvNo`)로 단일 예약 레코드를 조회한다 |
| FR-RES-004-2 | Repository 레벨에서 소유권을 검증하여 타인 예약 접근을 방지한다 (OWASP BOLA 대응) |
| FR-RES-004-3 | 소유하지 않은 예약 접근 시 `NOT_FOUND` (HTTP 404)를 반환한다 |
| FR-RES-004-4 | 응답에 예약 날짜, 예약 시간, 상담사 코드/닉네임, 예약 상태를 포함한다 |

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/reservations/get-my-reservation`

---

### FR-RES-005: 상담사 예약 조회

**요약**: 상담사가 본인에게 등록된 예약 목록을 조회할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-RES-005-1 | `ce_code` 기반으로 상담사에게 연결된 예약만 조회한다 |
| FR-RES-005-2 | `RoleFilter:callee` 필터를 통해 상담사 계정(`UserRole::Callee`)만 접근 가능하도록 제한한다 |
| FR-RES-005-3 | `limit`, `offset` 파라미터로 페이지네이션을 지원한다 (기본값: limit=10, offset=0) |
| FR-RES-005-4 | 응답에 예약자(회원) 정보 및 포맷된 날짜/시간을 포함한다 |

**선행 조건**: 요청자가 `UserRole::Callee`(상담사)이고 `RoleFilter:callee`를 통과한다.

**우선순위**: P1 (필수)

**관련 EP**: `POST /api/reservations/get-callee-reservation-list`

---

### FR-RES-006: 예약 통화 연결

**요약**: 예약된 상담 통화를 예약 시간 윈도우 내에서 연결할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-RES-006-1 | `ReservationService.resolveCallStatus()`를 통해 통화 연결 가능 여부(시간 윈도우)를 검증한다 |
| FR-RES-006-2 | 예약 시간 윈도우 외 통화 시도 시 `FORBIDDEN` (HTTP 403)으로 거부한다 |
| FR-RES-006-3 | 예약 번호(`rvNo`) 미존재 시 `NOT_FOUND` (HTTP 404)를 반환한다 |
| FR-RES-006-4 | 성공 시 통화 연결 번호(`connectNumber`)를 응답으로 반환한다 |

**우선순위**: P2 (중요)

**관련 EP**: `POST /api/reservations/call`

---

### FR-RES-007: O2O 캘린더 조회

**요약**: 상담사가 월별 O2O 캘린더/스케줄/인원/대기 현황을 조회할 수 있어야 한다.

> **[RESV-DEF-009 반영]**: 본 기능은 현재 조회 전용으로 구현되어 있다. SDD v2.0이 설계한 "오프라인 일정 등록(`createO2oEvent`)" 기능은 미구현(Open Question OQ-001)이다.

| ID | 요구사항 |
|----|----------|
| FR-RES-007-1 | `O2oCalendarController.o2oCalendar()`가 O2O 캘린더 조회 엔드포인트를 제공한다 |
| FR-RES-007-2 | `shopRepository.calendarSchedule()` + `shopRepository.standbyCalendarSchedule()`를 통해 월별 스케줄/대기 데이터를 조회한다 |
| FR-RES-007-3 | `RoleFilter:callee` 필터를 통해 상담사만 접근할 수 있다 |
| FR-RES-007-4 | `month` (YYYY-MM) 파라미터로 조회 월을 지정한다. 미지정 시 현재 월 기본값 적용 |
| FR-RES-007-5 | 응답에 calendar, schedule, people, standby 데이터를 포함한다 |

**선행 조건**: 요청자가 `UserRole::Callee`(상담사)이고 `RoleFilter:callee`를 통과한다.

**우선순위**: P2 (중요)

**관련 EP**: `POST /api/o2o-calendars/o2o-calendar`

---

### FR-RES-008: 월간 캘린더 조회

**요약**: 사용자 또는 비인증 사용자가 월별 캘린더 데이터를 조회할 수 있어야 한다.

| ID | 요구사항 |
|----|----------|
| FR-RES-008-1 | `CalendarController.calendar()`가 월간 캘린더 조회 엔드포인트를 제공한다 |
| FR-RES-008-2 | `CalendarHelper.buildMonthData(month)` static 메서드를 통해 월간 데이터를 구성한다 |
| FR-RES-008-3 | `month` (YYYY-MM) 파라미터로 조회 월을 지정한다. 미지정 시 현재 월 기본값 적용 |
| FR-RES-008-4 | 응답에 calendar 데이터를 포함한다 |
| FR-RES-008-5 | 본 EP는 공개 EP이다. JWT 인증 및 CSRF 검증 없이 접근 가능하다 |

**우선순위**: P2 (중요)

**관련 EP**: `POST /api/calendars/calendar`

---

## 4. 비기능 요구사항 (Non-Functional Requirements)

### NFR-RES-001: 20분 간격 슬롯 생성 정확성

| ID | 요구사항 |
|----|----------|
| NFR-RES-001-1 | `buildScheduleSlots()`는 운영 시간을 20분 단위로 분할하여 슬롯을 생성한다 |
| NFR-RES-001-2 | 시간당 정확히 3개의 슬롯(0분, 20분, 40분)이 생성되어야 한다 |
| NFR-RES-001-3 | 슬롯 간격은 상수(`SLOT_INTERVAL_MINUTES = 20`)로 정의하고 런타임 변경을 허용하지 않는다 |

### NFR-RES-002: 예약 중복 방지

| ID | 요구사항 |
|----|----------|
| NFR-RES-002-1 | `validateReservationRows()`의 3단계 카운트 기반 검증으로 중복 예약을 방지한다 |
| NFR-RES-002-2 | 중복 감지 시 `CONFLICT` 에러 코드와 HTTP 409를 반환한다 |
| NFR-RES-002-3 | 날짜당 2건 초과 예약 시 `CONFLICT` 처리한다 |

### NFR-RES-003: 자체 완결성 (Self-contained)

| ID | 요구사항 |
|----|----------|
| NFR-RES-003-1 | Reservation 모듈은 외부 서비스(PG, 외부 DB, 메시지 큐, 파일 스토리지) 의존성이 없다 |
| NFR-RES-003-2 | 모듈 간 통신이 필요한 경우 `ReservationServiceInterface`를 통한 DI만 허용한다 |

### NFR-RES-004: 성능

| ID | 요구사항 |
|----|----------|
| NFR-RES-004-1 | 슬롯 목록 조회 응답 시간: 200ms 이내 |
| NFR-RES-004-2 | 월간 캘린더 조회 응답 시간: 300ms 이내 |
| NFR-RES-004-3 | 페이지네이션 기본값: 10건/페이지 |

### NFR-RES-005: 타임존 일관성 (개선 필요)

| ID | 요구사항 |
|----|----------|
| NFR-RES-005-1 | 모든 날짜/시간은 DB 및 서버에서 UTC로 저장 및 처리해야 한다 |
| NFR-RES-005-2 | `date()`, `time()` PHP 함수 사용을 금지하고 `DateTimeImmutable`만 사용해야 한다 |
| NFR-RES-005-3 | **현황**: 현재 코드(`ReservationController.php`, `CalendarController.php`, `O2oCalendarController.php`)에서 `date()`, `time()`, `strtotime()` 함수가 사용되고 있어 NFR 위반 상태이다 (RESV-DEF-010, 페이즈 2 개선 대상) |
| NFR-RES-005-4 | 클라이언트는 UTC 응답을 수신 후 프론트엔드에서 로컬 타임존으로 변환한다 |

---

## 5. 유스케이스 (Use Cases)

### UC-RES-001: 사용자가 스케줄을 조회하고 예약한다

```
Actor: 로그인 사용자 (Caller)
Precondition: 유효한 JWT 쿠키(hc_access) 보유 (스케줄 조회는 공개)
Main Flow:
  1. 사용자가 itCode, weekDay, date를 포함하여 스케줄 조회를 요청한다 (인증 불필요).
  2. 시스템이 buildScheduleSlots()로 운영 시간 내 20분 간격 슬롯 목록을 생성한다.
  3. 시스템이 status(able/com/end), time(H:i), min 포함 슬롯 목록을 반환한다.
  4. 사용자가 원하는 슬롯을 선택하여 예약을 요청한다 (JWT 필요).
  5. 시스템이 validateReservationRows()로 슬롯 유효성(중복 여부, 슬롯당 건수, 날짜당 건수)을 검증한다.
  6. 시스템이 tb_reservation에 예약 레코드를 삽입한다.
  7. 시스템이 HTTP 200과 rvNo를 응답한다.
Alternate Flow (중복 예약):
  5a. 동일 예약 존재 또는 건수 초과 시 CONFLICT (HTTP 409)를 반환한다.
Alternate Flow (차단 상태):
  5b. 차단(reject) 상태인 경우 FORBIDDEN (HTTP 403)을 반환한다.
```

### UC-RES-002: 상담사가 O2O 캘린더를 조회한다

```
Actor: 상담사 (UserRole::Callee)
Precondition: 상담사 로그인 상태, RoleFilter:callee 통과
Main Flow:
  1. 상담사가 month(YYYY-MM) 파라미터를 포함하여 O2O 캘린더를 요청한다.
  2. 시스템이 shopRepository.calendarSchedule() + standbyCalendarSchedule()로 데이터를 조회한다.
  3. 시스템이 CalendarHelper.buildMonthData(month)로 월간 캘린더 데이터를 구성한다.
  4. 시스템이 calendar, schedule, people, standby 데이터를 포함하여 응답한다.
Alternate Flow (상담사 아닌 사용자 접근):
  RoleFilter:callee가 FORBIDDEN (HTTP 403)을 반환한다.
```

### UC-RES-003: 사용자가 월간 캘린더를 조회한다

```
Actor: 사용자 또는 비인증 사용자
Precondition: 없음 (공개 EP)
Main Flow:
  1. 사용자가 month 파라미터를 포함하여 월간 캘린더를 요청한다 (인증 불필요).
  2. 시스템이 CalendarHelper.buildMonthData(month)로 월간 캘린더 데이터를 구성한다.
  3. 시스템이 calendar 데이터를 포함하여 응답한다.
```

---

## 6. 엔드포인트 목록 (Endpoint Inventory)

> **[RESV-DEF-001, RESV-DEF-002 반영]**: 실제 Routes.php 코드 기준 RPC-style URL 및 HTTP 메서드를 적용한다.

| # | 컨트롤러 | HTTP | 경로 | 설명 | 인증 | 역할 필터 | CSRF |
|---|----------|------|------|------|------|----------|------|
| 1 | ReservationController | GET | `/api/reservations/get-schedule` | 스케줄 슬롯 조회 | — (공개) | — | — |
| 2 | ReservationController | POST | `/api/reservations/insert-reservation` | 예약 등록 | JWT | — | 필요 |
| 3 | ReservationController | POST | `/api/reservations/get-my-reservation` | 예약 상세 조회 | JWT | — | 필요 |
| 4 | ReservationController | POST | `/api/reservations/get-my-reservation-list` | 예약 목록 조회 (사용자) | JWT | — | 필요 |
| 5 | ReservationController | POST | `/api/reservations/get-callee-reservation-list` | 상담사 예약 조회 | JWT | callee | 필요 |
| 6 | ReservationController | POST | `/api/reservations/call` | 예약 통화 연결 | JWT | — | 필요 |
| 7 | O2oCalendarController | POST | `/api/o2o-calendars/o2o-calendar` | O2O 캘린더 조회 | JWT | callee | 필요 |
| 8 | CalendarController | POST | `/api/calendars/calendar` | 월간 캘린더 조회 | — (공개) | — | — |

> **EP URL 설계 노트**: 본 모듈은 RESTful 자원 중심 URL(`/reservations`, `/reservations/{id}`) 대신 RPC-style 동사 포함 URL(`/insert-reservation`, `/get-my-reservation-list`)을 사용한다. 레거시 패턴 유지가 결정된 기존 코드베이스 기준을 그대로 따른다.

---

## 7. 타당성 검토 (Feasibility Review)

### 7.1 기술적 타당성

| 항목 | 근거 |
|------|------|
| 카운트 기반 중복 예약 차단 | 3단계 카운트 검증(`checkReservation`, `checkReservationDateTimeCnt`, `checkReservationDateCnt`)으로 중복을 방지한다. 슬롯당 1건, 날짜당 2건 제한 |
| CalendarHelper static 메서드 | 상태를 보유하지 않는 순수 함수형 로직에 static 사용 — DI 없이 직접 호출 가능하여 컨트롤러 의존 그래프 단순화 |
| CI4 빌트인 Pager | CodeIgniter 4.7+ 내장 Pager: `Model::paginate()` + `Model::pager` 조합으로 일관된 페이지네이션 메타 구성 |
| RPC-style EP | 기존 레거시 코드베이스 패턴 일관성 유지. 프론트엔드 연동 변경 없이 현행 유지 |

### 7.2 운영 타당성

| 항목 | 내용 |
|------|------|
| Self-contained 아키텍처 | 외부 서비스 의존성 없음 → 네트워크 장애나 외부 API 변경의 영향을 받지 않음 |
| 20분 간격 고정 설계 | 비즈니스 요건(시간당 3슬롯)이 명확히 정의되어 있어 런타임 변경 불필요. 상수 정의로 코드 일관성 유지 |
| 공개 EP 설계 | `get-schedule`, `calendars/calendar`은 인증 없이 접근 가능하여 미로그인 사용자도 스케줄/캘린더 확인 가능 |

---

## 8. 검증 체크리스트 (Verification Checklist)

| ID | 검증 항목 | 검증 방법 |
|----|----------|----------|
| FR-RES-001 | get-schedule 공개 EP (인증 없이 접근) | 통합 테스트 |
| FR-RES-001 | buildScheduleSlots() 20분 간격 슬롯 생성 | 단위 테스트 |
| FR-RES-002 | validateReservationRows() 3단계 카운트 검증 | 단위 테스트 |
| FR-RES-003 | 예약 목록 페이지네이션 (limit/offset) | 통합 테스트 |
| FR-RES-004 | 예약 상세 소유권 조건(ac_id) 쿼리 포함 | 단위 테스트 |
| FR-RES-005 | 상담사 예약 조회 RoleFilter:callee 적용 | 통합 테스트 |
| FR-RES-006 | call EP 시간 윈도우 검증 | 단위 테스트 |
| FR-RES-007 | O2O 캘린더 조회 (조회 전용) | 통합 테스트 |
| FR-RES-008 | calendars/calendar 공개 EP (인증 없이 접근) | 통합 테스트 |
| NFR-RES-001 | 슬롯 생성 정확성 (0분, 20분, 40분) | 단위 테스트 |
| NFR-RES-002 | 예약 중복 CONFLICT (HTTP 409) 반환 | 단위 테스트 |
| NFR-RES-003 | 외부 서비스 의존성 없음 확인 | 코드 리뷰 |
| NFR-RES-004 | 슬롯 조회 200ms, 캘린더 조회 300ms 이내 | 부하 테스트 |
| NFR-RES-005 | date()/time() 함수 제거, DateTimeImmutable 전환 | 정적 분석 (페이즈 2) |

---

## 변경 기록 (Change History)

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | v1.0 | 최초 작성 | jypark |
| 2026-04-15 | v2.0 | IEEE 표준 전면 전환. 3-Round Review PASS | jypark |
| 2026-04-21 | v2.1 | API ↔ IEEE 대조 리포트(reservation-api-vs-ieee-20260421.md) [A] 이슈 반영 | jypark |

### v2.1 변경 영향 기록 (Change Impact Log)

| 변경 항목 | 개선점 | 수행 이유 |
|----------|--------|----------|
| §2.4 인증 제약사항: "모든 EP JWT 필수" → 공개 EP 예외 명시 (RESV-DEF-003) | 실제 코드(`checkNeedLogin` 없음)와 일치. 공개 EP 접근 정책 명확화 | Routes.php + 코드 기준 공개 EP 2건(`get-schedule`, `calendars/calendar`)이 JWT 없이 동작하므로 SRS 수정 필수 |
| §6 엔드포인트 목록: RESTful URL → RPC-style URL 전면 교체 (RESV-DEF-001, RESV-DEF-002) | Routes.php 코드와 100% 일치. 구현자/운영자가 잘못된 URL로 테스트하는 혼선 제거 | SSOT = Routes.php 코드. IEEE가 실제 코드와 다른 URL/메서드를 명세하면 운영 혼란 유발 |
| §3 FR: 슬롯 상태 필드 `available: bool` → `status: 'able'/'com'/'end'` 수정 (RESV-DEF-005 반영) | 실제 `buildScheduleSlots()` 반환 구조와 일치 | 코드 반환 값(`status: string`)과 FR 명세(`available: bool`) 불일치 해소 |
| §3 FR-RES-002: SELECT FOR UPDATE 방식 → 카운트 기반 검증 방식으로 현행화 (RESV-DEF-007) | 실제 `validateReservationRows()` 구현 방식 반영 | SRS FR-RES-002-5가 SELECT FOR UPDATE를 명세했으나 실제 구현은 카운트 기반 검증 사용 |
| §3 FR-RES-007: O2O 등록 기능 설계 → 조회 전용 + 미구현 Open Question 표기 (RESV-DEF-009) | 현재 구현 범위(조회 전용)를 정확히 기술 | O2oCalendarController는 shopRepository 조회만 수행. createO2oEvent() 미구현 사실 명시 필요 |
| §2.3 사용자 특성: 비인증 사용자 유형 추가 | 공개 EP 접근 가능 사용자 범위 명확화 | RESV-DEF-003 반영. 스케줄/캘린더 조회는 미로그인 상태에서도 가능 |
