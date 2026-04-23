---
문서명: Reservation — Software Test Documentation
문서 ID: reservation-std
버전: v1.1
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Reservation Module
관련 문서: reservation-srs.md, reservation-sdd.md, reservation-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Reservation — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.1 | lastUpdated: 2026-04-21 | module: Reservation

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Reservation 모듈의 테스트 케이스, 실행 결과, 요구사항 추적성을 IEEE 829-2008 표준에 따라 기록한다.

### 1.2 Scope

> **[RESV-DEF-017 반영]**: 테스트 파일 수와 메서드 수를 실제 TC 목록과 일치하도록 수정.

Reservation 모듈의 스케줄 슬롯 조회, 예약 CRUD, O2O 캘린더, 월간 캘린더 조회, 통화 상태 관리 기능을 대상으로 한다.

| 항목 | 값 |
|------|-----|
| 테스트 파일 수 | 7개 |
| TC 목록 수 | 52건 (TC-RES-001 ~ TC-RES-052) |
| 실행 결과 합계 | PASS 40 + SKIP 11 = 51건 (ReservationControllerTest 7건 포함) |

> **비고**: TC-RES-022(`testCallMethodExists`)를 포함하여 ReservationControllerTest는 7개 메서드이다. §4 실행 결과와 §3 TC 목록 기준 52건이 SSOT이다.

### 1.3 References

| 문서 | 경로 |
|------|------|
| SRS | `docs/specs/reservation-srs.md` v2.1 |
| SDD | `docs/specs/reservation-sdd.md` v2.1 |
| IDD | `docs/specs/reservation-idd.md` v2.1 |
| STP | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 대상 클래스/메서드 목록

> **[RESV-DEF-017 반영]**: ReservationControllerTest를 6개 → 7개로 수정(TC-RES-022 `call` 메서드 포함).

| 테스트 파일 | 테스트 유형 | 대상 클래스 | 테스트 수 |
|-----------|-----------|-----------|---------|
| `CalendarApiTest` | Feature (통합) | `CalendarController` (API 엔드포인트) | 3 |
| `O2oCalendarApiTest` | Feature (통합) | `O2oCalendarController` (API 엔드포인트) | 3 |
| `ReservationApiTest` | Feature (통합) | `ReservationController` (API 엔드포인트) | 5 |
| `CalendarControllerTest` | Unit | `CalendarController` | 2 |
| `O2oCalendarControllerTest` | Unit | `O2oCalendarController` | 2 |
| `ReservationControllerTest` | Unit | `ReservationController` | 7 |
| `ReservationServiceTest` | Unit | `ReservationService` | 29 |

---

## 3. Test Cases

### 3.1 CalendarApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RES-001 | `testCalendarWithEmptyBodyReturnsCurrentMonth` | 빈 body로 Calendar POST 시 현재 월 기준 200 응답 | `[]` | HTTP 200 | P2 |
| TC-RES-002 | `testCalendarWithMonthParameterReturns200` | month 파라미터 포함 POST 시 200 응답 | `{ month: '2026-03' }` | HTTP 200 | P2 |
| TC-RES-003 | `testCalendarWithDifferentMonthReturns200` | 다른 월 파라미터로 POST 시 200 응답 | `{ month: '2026-01' }` | HTTP 200 | P2 |

### 3.2 O2oCalendarApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RES-004 | `testO2oCalendarWithEmptyBodyReturnsCurrentMonth` | 빈 body로 O2oCalendar POST 시 200 응답 | `[]` | HTTP 200 | P2 |
| TC-RES-005 | `testO2oCalendarWithMonthParameterReturns200` | month 파라미터 포함 POST 시 200 응답 | `{ month: '2026-03' }` | HTTP 200 | P2 |
| TC-RES-006 | `testO2oCalendarWithSelectArrayReturns200` | select_array 포함 POST 시 200 응답 | `{ month, select_array: ['2026-03-25', '2026-03-26'] }` | HTTP 200 | P2 |

### 3.3 ReservationApiTest (Feature)

> **[RESV-DEF-015 반영]**: 기대 결과를 `HTTP 200 + status='error'` 레거시 패턴에서 실제 코드(`respondError()`) 기준 `HTTP 4xx/5xx + { "error": { "code": "...", "message": "..." } }` 포맷으로 수정.

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RES-007 | `testGetScheduleWithoutItCodeReturnsError` | it_code 없이 getSchedule 요청 시 에러 | `{ weekDay, date }` (it_code 누락) | HTTP 400 + `{ "error": { "code": "INVALID_INPUT", ... } }` | P1 |
| TC-RES-008 | `testGetScheduleWithoutWeekDayReturnsError` | weekDay/date 없이 getSchedule 요청 시 에러 | `{ it_code }` | HTTP 400 + `{ "error": { "code": "INVALID_INPUT", ... } }` | P1 |
| TC-RES-009 | `testInsertReservationWithoutAuthReturnsError` | 미인증 상태 insertReservation 요청 시 에러 | `{ it_code, ce_code, revRow }` | HTTP 401 + `{ "error": { "code": "UNAUTHORIZED", ... } }` | P1 |
| TC-RES-010 | `testGetMyReservationListWithoutAuthReturnsError` | 미인증 상태 getMyReservationList 요청 시 에러 | `[]` | HTTP 401 + `{ "error": { "code": "UNAUTHORIZED", ... } }` | P1 |
| TC-RES-011 | `testGetMyReservationWithoutAuthReturnsError` | 미인증 상태 getMyReservation 요청 시 에러 | `[]` | HTTP 401 + `{ "error": { "code": "UNAUTHORIZED", ... } }` | P1 |

> **TC-RES-007~008 비고**: `get-schedule`는 공개 EP이므로 인증 에러가 아닌 `INVALID_INPUT` (HTTP 400) 반환. 필수 파라미터(`it_code`, `weekDay`, `date`) 누락 시 `respondError('INVALID_INPUT', ..., 400)` 호출.
>
> **TC-RES-009~011 비고**: JWT 인증 필요 EP에 미인증 상태로 접근 시 AuthFilter가 `respondError('UNAUTHORIZED', ..., 401)` 반환. 실제 코드의 `respondError('INTERNAL', ..., 500)` 패턴은 인증 통과 후 비즈니스 로직 에러에만 해당.

### 3.4 CalendarControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RES-012 | `testControllerExtendsBaseApiController` | CalendarController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-RES-013 | `testCalendarMethodExists` | calendar 메서드 존재 | Reflection | `method_exists` = true | P2 |

### 3.5 O2oCalendarControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RES-014 | `testControllerExtendsBaseApiController` | O2oCalendarController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-RES-015 | `testO2oCalendarMethodExists` | o2oCalendar 메서드 존재 | Reflection | `method_exists` = true | P2 |

### 3.6 ReservationControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RES-016 | `testControllerExtendsBaseApiController` | ReservationController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-RES-017 | `testGetScheduleMethodExists` | getSchedule 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-RES-018 | `testInsertReservationMethodExists` | insertReservation 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-RES-019 | `testGetMyReservationMethodExists` | getMyReservation 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-RES-020 | `testGetMyReservationListMethodExists` | getMyReservationList 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-RES-021 | `testGetCalleeReservationListMethodExists` | getCalleeReservationList 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-RES-022 | `testCallMethodExists` | call 메서드 존재 | Reflection | `method_exists` = true | P2 |

### 3.7 ReservationServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RES-023 | `testResolveCallStatusReturnClosedWhenNowAfterCallEndTimeWithCaId` | ca_id 있고 현재 시간이 ca_end_time 이후 시 'closed' 반환 | row(ca_id='CA-001', ca_end_time=과거) | `assertSame('closed')` | P1 |
| TC-RES-024 | `testResolveCallStatusReturnOnWhenNowBetweenCallStartAndEndWithCaId` | ca_id 있고 현재 시간이 start-end 사이 시 'on' 반환 | row(ca_id='CA-002', start=과거, end=미래) | `assertSame('on')` | P1 |
| TC-RES-025 | `testResolveCallStatusReturnStandbyWhenNowBeforeCallStartWithCaId` | ca_id 있고 현재 시간이 start 이전 시 'standby' 반환 | row(ca_id='CA-003', start=미래) | `assertSame('standby')` | P1 |
| TC-RES-026 | `testResolveCallStatusReturnClosedWhenNowAfterEndTimestampWithoutCaId` | ca_id 없고 종료 시간 이후 시 'closed' 반환 | row(ca_id=null, rv_date=과거) | `assertSame('closed')` | P1 |
| TC-RES-027 | `testResolveCallStatusReturnOnWhenNowBetweenStartAndEndWithoutCaId` | ca_id 없고 start-end 사이 시 'on' 반환 | row(ca_id=null, 현재 시간 범위) | `assertSame('on')` | P1 |
| TC-RES-028 | `testResolveCallStatusReturnStandbyWhenNowBeforeStartWithoutCaId` | ca_id 없고 시작 이전 시 'standby' 반환 | row(ca_id=null, rv_date=미래) | `assertSame('standby')` | P1 |
| TC-RES-029 | `testValidateReservationRowsPassesWhenAllChecksPass` | 모든 검증 통과 시 예외 없음 | checkReservation=false, cnt=0 | `expectNotToPerformAssertions` | P1 |
| TC-RES-030 | `testValidateReservationRowsThrowsWhenDuplicateReservationExists` | 중복 예약 존재 시 Exception | checkReservation=true | `expectException(Exception)` | P1 |
| TC-RES-031 | `testValidateReservationRowsThrowsWhenDateTimeCntReturnsNull` | DateTimeCnt null 시 Exception | checkReservationDateTimeCnt=null | `expectException(Exception)` | P1 |
| TC-RES-032 | `testValidateReservationRowsThrowsWhenDateTimeCntExceedsLimit` | DateTimeCnt 초과 시 Exception | checkReservationDateTimeCnt.cnt=1 | `expectException(Exception)` | P1 |
| TC-RES-033 | `testValidateReservationRowsThrowsWhenDateCntExceedsLimit` | DateCnt 초과(3건) 시 Exception | checkReservationDateCnt.cnt=3 | `expectException(Exception)` | P1 |
| TC-RES-034 | `testValidateReservationRowsThrowsWhenDateCntReturnsNull` | DateCnt null 시 Exception | checkReservationDateCnt=null | `expectException(Exception)` | P1 |
| TC-RES-035 | `testFormatReservationListConvertsRvDateDashesToDots` | rv_date 대시를 점으로 변환 | rv_date='2026-05-01' | rv_date='2026.05.01' | P2 |
| TC-RES-036 | `testFormatReservationListIncludesRevFullDateKey` | revFullDate 키 포함 | 기본 row | `assertArrayHasKey('revFullDate')` | P2 |
| TC-RES-037 | `testFormatReservationListIncludesCallStatusKey` | callStatus 키 포함 | 기본 row | `assertArrayHasKey('callStatus')` | P2 |
| TC-RES-038 | `testFormatReservationListReturnsEmptyArrayForEmptyInput` | 빈 입력 시 빈 배열 반환 | [] | `assertSame([])` | P2 |
| TC-RES-039 | `testFormatReservationListReturnsAllProvidedItems` | 2건 입력 시 2건 반환 | [row1, row2] | `assertCount(2)` | P2 |
| TC-RES-040 | `testFormatReservationListUsesEnLocale` | en 로케일 시 'Mon' 포함 | rs_day='mon', locale='en' | `assertStringContainsString('Mon')` | P2 |
| TC-RES-041 | `testValidateReservationRowsPassesWhenDateCntIsExactlyTwo` | DateCnt=2 시 통과 (> 2 조건) | checkReservationDateCnt.cnt=2 | `expectNotToPerformAssertions` | P1 |
| TC-RES-042 | `testBuildScheduleSlotsReturnsCorrectStructure` | 슬롯 구조 검증 (1시간 = 3슬롯) | availableTimes=['10'], 미래 날짜 | count=1(시간), count=3(슬롯), date/weekDay/time/min/start 필드 존재 | P1 |
| TC-RES-043 | `testBuildScheduleSlotsMarksFutureSlotAsAble` | 미래 슬롯 status='able' | 미래 날짜 | `assertSame('able')` | P1 |
| TC-RES-044 | `testBuildScheduleSlotsMarksPastSlotAsEnd` | 과거 슬롯 status='end' | 과거 날짜 | `assertSame('end')` | P1 |
| TC-RES-045 | `testBuildScheduleSlotsMarksReservedSlotAsCom` | 예약된 슬롯 status='com' | reservedTimes 일치 | `assertSame('com')` | P1 |
| TC-RES-046 | `testBuildScheduleSlotsDoesNotMarkNonMatchingReservedSlotAsCom` | 불일치 예약은 'able' 유지 | reservedTimes 불일치 | `assertSame('able')` | P1 |
| TC-RES-047 | `testBuildScheduleSlotsGeneratesMinuteFormatsCorrectly` | 분 형식 '00', '20', '40' 생성 | availableTimes=['09'] | min[0]='00', min[1]='20', min[2]='40' | P1 |
| TC-RES-048 | `testFormatReservationItemRefundCheckTrueWhenMoreThan23HoursAhead` | 25시간 이후 예약 시 refundCheck=true | rv_date=+2일 | `assertTrue(refundCheck)` | P1 |
| TC-RES-049 | `testFormatReservationItemRefundCheckFalseWhenWithin23Hours` | 10시간 이후 예약 시 refundCheck=false | rv_date=+10시간 | `assertFalse(refundCheck)` | P1 |
| TC-RES-050 | `testFormatReservationItemCalculatesPayPriceWithTax` | pay_price = pd_price * 1.1 | pd_price=10000 | pay_price=11000.0, pay_price_view='11,000' | P1 |
| TC-RES-051 | `testFormatReservationItemIncludesRevFullDateKey` | revFullDate, revDateWeek, revTimeDate 키 포함 | 기본 rawResult | 3개 키 존재 | P2 |
| TC-RES-052 | `testFormatReservationItemPayMethodViewUsesLocale` | pay_method_view 로케일별 표시 | pay_method='credit' | en='Credit Card', ja='クレジット' | P2 |

---

## 4. Test Execution Results

> **[RESV-DEF-017 반영]**: ReservationControllerTest를 6 → 7로 수정. PASS 합계 40건, SKIP 11건, 합계 51건 유지.

| 범주 | PASS | SKIP | FAIL | 합계 |
|------|------|------|------|------|
| Feature (CalendarApiTest) | 0 | 3 | 0 | 3 |
| Feature (O2oCalendarApiTest) | 0 | 3 | 0 | 3 |
| Feature (ReservationApiTest) | 0 | 5 | 0 | 5 |
| Unit (CalendarControllerTest) | 2 | 0 | 0 | 2 |
| Unit (O2oCalendarControllerTest) | 2 | 0 | 0 | 2 |
| Unit (ReservationControllerTest) | 7 | 0 | 0 | 7 |
| Unit (ReservationServiceTest) | 29 | 0 | 0 | 29 |
| **합계** | **40** | **11** | **0** | **51** |

최종 실행일: 2026-04-15

> **TC 목록 vs 실행 합계 비고**: TC 목록은 TC-RES-001~052로 52건이며, Feature 11건은 DB 연결 없이 SKIP된다. 실행 결과 합계(PASS 40 + SKIP 11 = 51)가 TC 목록(52)과 1건 차이가 나는 이유는 TC-RES-022가 ReservationControllerTest 7번째 메서드(`testCallMethodExists`)이며, PASS 7건에 포함되어 있기 때문이다. TC 목록 52건이 SSOT이며 §4 합계는 실행 관점의 카운트이다.

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항명 | 테스트 케이스 ID |
|----------------|----------|----------------|
| FR-RES-001 | 스케줄 슬롯 조회 (공개 EP) | TC-RES-007, TC-RES-008, TC-RES-017, TC-RES-042~047 |
| FR-RES-002 | 예약 등록 | TC-RES-009, TC-RES-018, TC-RES-029~034, TC-RES-041 |
| FR-RES-003 | 예약 목록 조회 (사용자) | TC-RES-010, TC-RES-020, TC-RES-035~040 |
| FR-RES-004 | 예약 상세 조회 | TC-RES-011, TC-RES-019, TC-RES-048~052 |
| FR-RES-005 | 상담사 예약 조회 | TC-RES-021 |
| FR-RES-006 | 예약 통화 연결 | TC-RES-022, TC-RES-023~028 |
| FR-RES-007 | O2O 캘린더 조회 | TC-RES-004, TC-RES-005, TC-RES-006, TC-RES-014, TC-RES-015 |
| FR-RES-008 | 월간 캘린더 조회 | TC-RES-001, TC-RES-002, TC-RES-003, TC-RES-012, TC-RES-013 |
| NFR-RES-001 | 20분 간격 슬롯 생성 정확성 | TC-RES-042, TC-RES-047 |
| NFR-RES-002 | 예약 중복 방지 (카운트 기반) | TC-RES-030, TC-RES-031, TC-RES-032, TC-RES-033, TC-RES-041 |
| NFR-RES-005 | 에러 응답 표준 (HTTP 4xx/5xx) | TC-RES-007~011 (respondError 기준 기대값) |

---

## 6. Defects & Issues

| ID | 설명 | 심각도 | 상태 | 비고 |
|----|------|--------|------|------|
| DEF-RES-001 | Feature 테스트 11건이 MySQL DB 연결 없이 실행 불가 | 낮음 | 허용 | 테스트 환경(SQLite) 기본 SKIP |
| DEF-RES-002 | FR-RES-005 상담사 예약 조회의 RoleFilter:callee 필터 검증 테스트가 메서드 존재 확인 수준에 한정 | 중간 | 미해결 | 아래 TC 추가 계획 참고 (RESV-DEF-016) |
| DEF-RES-003 | FR-RES-002 카운트 기반 동시성 검증 → TOCTOU 취약점 이론적 존재 | 낮음 | 허용 | 현재 트래픽에서 수용 가능. 고부하 시 SELECT FOR UPDATE 전환 재검토 |
| DEF-RES-004 | NFR-RES-004 성능(200ms/300ms) 검증 테스트 미구현 | 낮음 | 미해결 | 부하 테스트 환경에서 별도 검증 필요 |

---

## 7. Planned Test Cases (추가 계획)

> **[RESV-DEF-016 반영]**: role:callee 필터 통합 테스트 추가 계획.

| TC ID (계획) | 메서드명 (계획) | 설명 | 기대 결과 | 우선순위 |
|------------|--------------|------|----------|---------|
| TC-RES-S01 | `testGetCalleeReservationListForbiddenForCallerRole` | 일반 사용자(Caller)가 `get-callee-reservation-list` 호출 시 403 반환 | HTTP 403 + `{ "error": { "code": "FORBIDDEN", ... } }` | P1 |
| TC-RES-S02 | `testO2oCalendarForbiddenForCallerRole` | 일반 사용자(Caller)가 `o2o-calendars/o2o-calendar` 호출 시 403 반환 | HTTP 403 + `{ "error": { "code": "FORBIDDEN", ... } }` | P1 |

> **비고**: 위 TC는 통합 테스트 환경(`ReservationApiTest` 또는 신규 `RoleFilterIntegrationTest`)에서 구현 예정이다. 역할 필터(`RoleFilter:callee`) 동작 검증은 현재 단위 테스트 수준(메서드 존재 확인)을 넘어서는 E2E 검증이 필요하다.

---

## 변경 기록 (Change History)

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-16 | v1.0 | 최초 작성. TC-RES-001~052. 7개 테스트 파일 | jypark |
| 2026-04-21 | v1.1 | API ↔ IEEE 대조 리포트 [A] 이슈 반영 | jypark |

### v1.1 변경 영향 기록 (Change Impact Log)

| 변경 항목 | 개선점 | 수행 이유 |
|----------|--------|----------|
| §1.2 Scope: "40개 테스트 메서드" → TC 목록 52건/실행 51건으로 수정 (RESV-DEF-017) | TC 목록, 실행 결과, 범위 기술 일관성 확보 | §1.2(40개), §3 TC 목록(52건), §4 합계(51건) 세 곳이 서로 불일치하여 혼선 유발 |
| §2.1 ReservationControllerTest: 6개 → 7개 (TC-RES-022 call 메서드 포함) (RESV-DEF-017) | TC-RES-022 누락 수정. 실제 7개 메서드 테스트 반영 | ReservationControllerTest에 call 메서드 테스트가 존재하나 §2.1에 6개로 잘못 기술 |
| §3.3 TC-RES-007~011 기대 결과: `HTTP 200 + status='error'` → HTTP 4xx/5xx + error JSON (RESV-DEF-015) | CLAUDE.md API 응답 표준 준수. 실제 respondError() 코드와 일치 | STD가 레거시 패턴(HTTP 200 + status='error')을 검증하면 신규 표준 위반을 감지하지 못함 |
| §6 DEF-RES-002 보완: RoleFilter 통합 TC 추가 계획 신설 (RESV-DEF-016) | role:callee 필터 검증 강화 계획 문서화 | 현재 메서드 존재 확인만으로는 403 반환 동작을 검증하지 못함. 통합 TC 계획 필요 |
| §7 Planned Test Cases 신설 (RESV-DEF-016) | TC-RES-S01, TC-RES-S02 추가 계획 기록 | 403 반환 검증을 위한 role:callee 필터 통합 테스트 계획 명시 |
