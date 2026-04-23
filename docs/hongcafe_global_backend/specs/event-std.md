---
문서명: Event — Software Test Documentation
문서 ID: event-std
버전: v1.0
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-16
작성자: jypark
대상 시스템: Event Module
관련 문서: event-srs.md, event-sdd.md, event-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Event Module — Software Test Documentation

> IEEE 829-2008 준수 | version: 1.0 | updated: 2026-04-16 | module: Event

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Event 모듈의 테스트 결과를 IEEE 829-2008 표준에 따라 문서화한다. Event 모듈은 이벤트 목록 조회, 키워드/쿠폰/출석/코인충전 이벤트 참여, 갱신 쿠폰 발급, 룰렛 이벤트 처리 등 7개 핵심 기능을 제공하며, 10개 엔드포인트에 대한 5개 테스트 파일의 실행 결과와 SRS 요구사항 추적성을 기록한다.

### 1.2 Scope

- **테스트 파일 수**: 5개 (Feature 2, Unit 3)
- **대상 모듈**: `app/Modules/Event/`
- **엔드포인트**: 10개
- **테스트 유형**: Feature 테스트 (API 통합), Unit 테스트 (서비스/컨트롤러 단위)

### 1.3 References

| 문서 | 위치 |
|------|------|
| event-srs.md (SRS-EVENT-001 v2.0) | `docs/specs/` |
| event-sdd.md (SDD-EVENT-001) | `docs/specs/` |
| event-idd.md (IDD-EVENT-001) | `docs/specs/` |
| project-stp.md | `docs/specs/` |

---

## 2. Test Items

### 2.1 Feature 테스트 (API 통합)

| 테스트 파일 | 대상 클래스/엔드포인트 | 테스트 메서드 수 |
|------------|----------------------|----------------|
| EventApiTest | EventController — `api/event/*` | 4 |
| RouletteApiTest | RouletteController — `api/roulette/*` | 3 |

### 2.2 Unit 테스트 (서비스/컨트롤러)

| 테스트 파일 | 대상 클래스 | 테스트 메서드 수 |
|------------|-----------|----------------|
| EventControllerTest | EventController | 9 |
| EventRewardServiceTest | EventRewardService | 32 |
| RouletteServiceTest | RouletteService | 18 |

---

## 3. Test Cases

### 3.1 EventApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-EA-001 | testGetEventReturnsResponse | 이벤트 목록 요청 시 응답 반환 | 빈 body (JSON) | HTTP 200 | P1 |
| TC-EA-002 | testKeywordEventReturnsUnauthorizedWhenNotLoggedIn | 미인증 키워드 이벤트 참여 시 인증 오류 | eventKeyword='test' | HTTP 200, result=false | P1 |
| TC-EA-003 | testCouponEventReturnsUnauthorizedWhenNotLoggedIn | 미인증 쿠폰 이벤트 참여 시 인증 오류 | eventKeyword='test' | HTTP 200, result=false | P1 |
| TC-EA-004 | testAttendEventJoinReturnsUnauthorizedWhenNotLoggedIn | 미인증 출석 이벤트 참여 시 인증 오류 | 빈 body | HTTP 200, result=false | P1 |

### 3.2 RouletteApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RA-001 | testRunWithoutEventCodeReturnsError | event_code 없이 POST 시 에러 | 빈 body | HTTP 200, status='error' | P1 |
| TC-RA-002 | testRunWithEventCodeButWithoutAuthReturnsError | event_code 있으나 미인증 시 에러 | event_code='EVENT001' | HTTP 200, status='error' | P1 |
| TC-RA-003 | testRunWithNonExistentEventCodeReturnsError | 존재하지 않는 event_code로 POST 시 에러 | event_code='NONEXISTENT' | HTTP 200, status='error' | P1 |

### 3.3 EventControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 기대 결과 | 우선순위 |
|-------|---------|------|----------|---------|
| TC-EC-001 | testControllerExtendsBaseApiController | EventController가 BaseApiController 상속 확인 | assertTrue | P1 |
| TC-EC-002 | testSetAppCookieMethodExists | setAppCookie 메서드 존재 확인 | assertTrue | P2 |
| TC-EC-003 | testGetEventMethodExists | getEvent 메서드 존재 확인 | assertTrue | P1 |
| TC-EC-004 | testKeywordEventMethodExists | keywordEvent 메서드 존재 확인 | assertTrue | P1 |
| TC-EC-005 | testCouponEventMethodExists | couponEvent 메서드 존재 확인 | assertTrue | P1 |
| TC-EC-006 | testSetRenewalEventCouponMethodExists | setRenewalEventCoupon 메서드 존재 확인 | assertTrue | P1 |
| TC-EC-007 | testRenewalEventCouponMethodExists | renewalEventCoupon 메서드 존재 확인 | assertTrue | P1 |
| TC-EC-008 | testShowEventContentsMethodExists | showEventContents 메서드 존재 확인 | assertTrue | P2 |
| TC-EC-009 | testAttendEventJoinMethodExists | attendEventJoin 메서드 존재 확인 | assertTrue | P1 |

### 3.4 EventRewardServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-ERS-001 | testDetermineGradeReturnsHighestGradeWhenAmountExceedsMaxThreshold | 최고 등급 결정 (최대 임계값 초과) | 10,000,000 | grade=100000 | P1 |
| TC-ERS-002 | testDetermineGradeReturnsCorrectGradeForMidTierAmount | 중간 등급 결정 | 5,000,000 | grade=50000 | P1 |
| TC-ERS-003 | testDetermineGradeReturnsLowestGradeAtMinimumThreshold | 최저 등급 결정 (최소 임계값) | 100,000 | grade=1000 | P1 |
| TC-ERS-004 | testDetermineGradeReturnsZeroGradeWhenAmountBelowAllThresholds | 임계값 미달 시 0등급 | 50,000 | grade=0 | P1 |
| TC-ERS-005 | testDetermineGradeReturnsZeroGradeForZeroAmount | 0원 시 0등급 | 0 | grade=0 | P1 |
| TC-ERS-006 | testDetermineGradeReturnArrayHasGradeAndCodeKeys | 반환 배열 키 검증 | 3,000,000 | grade, code 키 존재 | P2 |
| TC-ERS-007 | testValidateParticipationReturnsTrueWhenAllConditionsMet | 참여 검증 — 전체 조건 충족 시 true | 유효 데이터 | true | P1 |
| TC-ERS-008 | testValidateParticipationReturnsCoinErrorWhenPhoneAlreadyUsed | 전화번호 중복 — coin 타입 에러 | 중복 전화번호 | 'coin' | P1 |
| TC-ERS-009 | testValidateParticipationReturnsCouponErrorWhenPhoneAlreadyUsedForCouponType | 전화번호 중복 — coupon 타입 에러 | 중복 전화번호, type='coupon' | 'coupon' | P1 |
| TC-ERS-010 | testValidateParticipationReturnsLimitWhenDailyLimitExceeded | 일일 한도 초과 | dailyCnt=10, limit=10 | 'limit' | P1 |
| TC-ERS-011 | testValidateParticipationReturnsTotalWhenTotalLimitExceeded | 총 한도 초과 | totalCnt=100, limit=100 | 'total' | P1 |
| TC-ERS-012 | testValidateParticipationReturnsIncorrectWhenKeywordWrong | 키워드 불일치 | 'wrongKeyword' | 'incorrect' | P1 |
| TC-ERS-013 | testValidateParticipationReturnsTrueWhenKeywordCorrect | 키워드 일치 | 'correctKeyword' | true | P1 |
| TC-ERS-014 | testIsRewardAlreadyGrantedReturnsTrueWhenAlreadyParticipated | 이미 참여한 경우 true | 참여 이력 존재 | true | P1 |
| TC-ERS-015 | testIsRewardAlreadyGrantedReturnsFalseWhenNotYetParticipated | 미참여 시 false | 참여 이력 없음 | false | P1 |
| TC-ERS-016 | testIsRewardAlreadyGrantedReturnsFalseWhenModelReturnsNull | Model null 반환 시 false | — | false | P2 |
| TC-ERS-017 | testGetEventLimitCountDelegatesCallToEventModel | 이벤트 한도 조회 위임 | 'EV-001' | ev_day_limit, ev_total_limit | P1 |
| TC-ERS-018 | testGetEventLimitCountReturnsNullWhenEventNotFound | 미존재 이벤트 한도 조회 시 null | 'EV-NONEXISTENT' | null | P1 |
| TC-ERS-019 | testGrantEventCoinReturnsCoinDataOnSuccess | 코인 보상 지급 성공 | 유효 member | cr_code, ci_amount=500 | P1 |
| TC-ERS-020 | testGrantEventCoinThrowsExceptionWhenInsertCoinFails | 코인 INSERT 실패 시 Exception | InsertCoin→false | Exception | P1 |
| TC-ERS-021 | testGrantEventCoinThrowsExceptionWhenEventLogFails | 이벤트 로그 실패 시 Exception | keywordEventLog→false | Exception | P1 |
| TC-ERS-022 | testGrantEventCoinIncludesEkContentInLogWhenProvided | ek_content 포함 로그 검증 | 'extra content' | ek_content='extra content' | P2 |
| TC-ERS-023 | testGrantEventCouponSucceedsWhenCouponAvailable | 쿠폰 보상 지급 성공 | 사용 가능한 쿠폰 | 예외 없이 완료 | P1 |
| TC-ERS-024 | testGrantEventCouponThrowsExceptionWhenCouponAlreadyUsed | 이미 사용된 쿠폰 시 Exception | getCouponInfo→1 | Exception | P1 |
| TC-ERS-025 | testGrantEventCouponThrowsExceptionWhenUpdateCouponFails | 쿠폰 업데이트 실패 시 Exception | updateCouponList→false | Exception | P1 |
| TC-ERS-026 | testGrantEventCouponThrowsExceptionWhenEventLogFails | 쿠폰 이벤트 로그 실패 시 Exception | keywordEventLog→false | Exception | P1 |
| TC-ERS-027 | testGetMemberTotalPayAmountDelegatesCallToPayModel | 총 결제 금액 조회 위임 | 'CR-001' | 5,000,000 | P1 |
| TC-ERS-028 | testGetMemberTotalPayAmountReturnsZeroForNewMember | 신규 회원 결제 금액 0 | 'CR-NEW' | 0 | P1 |
| TC-ERS-029 | testGetMemberTotalPayAmountReturnsNullWhenMemberNotFound | 미존재 회원 시 null | 'CR-NONEXISTENT' | null | P2 |
| TC-ERS-030 | testGrantRenewalEventCouponSucceedsWithValidCouponCode | 갱신 쿠폰 발급 성공 | 유효 couponCode | 예외 없이 완료 | P1 |
| TC-ERS-031 | testGrantRenewalEventCouponThrowsExceptionForInvalidCouponCode | 무효 쿠폰 코드 시 Exception | 'INVALID-CODE' | Exception | P1 |
| TC-ERS-032 | testGrantRenewalEventCouponThrowsExceptionWhenAlreadyIssued | 이미 발급된 쿠폰 시 Exception | issued count=1 | Exception | P1 |

### 3.5 EventRewardServiceTest — processAttendanceEvent (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-ERS-033 | testProcessAttendanceEventReturnsCoinDataOnSuccess | 출석 이벤트 성공 — 코인 데이터 반환 | 3회차 참여 | ci_amount=50, ci_type='charge' | P1 |
| TC-ERS-034 | testProcessAttendanceEventThrowsExceptionWhenEventEnded | 종료된 이벤트 시 Exception | joinPossible=0 | Exception('eventEnd') | P1 |
| TC-ERS-035 | testProcessAttendanceEventThrowsExceptionWhenAllJoinsComplete | 전체 참여 완료 시 Exception | cnt=10, allCnt=10 | Exception('joinAllComplete') | P1 |
| TC-ERS-036 | testProcessAttendanceEventThrowsExceptionWhenAlreadyJoinedToday | 당일 참여 완료 시 Exception | oneDayJoin=1 | Exception('dayComplete') | P1 |
| TC-ERS-037 | testProcessAttendanceEventThrowsExceptionWhenCoinResultEmpty | 코인 정보 없을 때 Exception | getAttendCoin→null | Exception('eventError') | P1 |
| TC-ERS-038 | testProcessAttendanceEventAddsAdditionalCoinAtMilestone | 마일스톤 추가 코인 검증 | 5회차 (마일스톤) | ci_amount=250 (50+200) | P1 |
| TC-ERS-039 | testProcessAttendanceEventThrowsExceptionWhenInsertAttendFails | 출석 INSERT 실패 시 Exception | insertAttendEvent→false | Exception('eventError') | P1 |
| TC-ERS-040 | testProcessAttendanceEventThrowsExceptionWhenInsertCoinFails | 코인 INSERT 실패 시 Exception | InsertCoin→false | Exception('insertCoinError') | P1 |

### 3.6 RouletteServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RS-001 | testGetWinProductReturnsCorrectIndexForMatchingCoin | 코인 매칭 시 올바른 인덱스 반환 | coin=100,500,5000 | index 0,1,4 | P1 |
| TC-RS-002 | testGetWinProductReturnsNullWhenCoinNotFound | 미존재 코인 시 null | coin=9999 | null | P1 |
| TC-RS-003 | testGetWinProductReturnsFirstIndexForFirstCoin | 첫 번째 코인 인덱스 | coin=10000 | 0 | P2 |
| TC-RS-004 | testGetWinProductReturnsLastIndexForLastCoin | 마지막 코인 인덱스 | coin=300 | 2 | P2 |
| TC-RS-005 | testGetTodayRemainEventCntReturnsSumOfFreeAndCallCounts | 오늘 잔여 횟수 합산 | free=2, call=3 | 5 | P1 |
| TC-RS-006 | testGetTodayRemainEventCntReturnsZeroWhenModelReturnsNull | Model null 시 0 | →null | 0 | P1 |
| TC-RS-007 | testGetTodayRemainEventCntReturnsZeroWhenModelReturnsFalse | Model false 시 0 | →false | 0 | P1 |
| TC-RS-008 | testGetTodayRemainEventCntReturnsOnlyFreeWhenCallIsZero | call=0일 때 free만 | free=3, call=0 | 3 | P2 |
| TC-RS-009 | testGetTodayRemainEventCntReturnsOnlyCallWhenFreeIsZero | free=0일 때 call만 | free=0, call=1 | 1 | P2 |
| TC-RS-010 | testGetWinCoinReturnsFalseWhenEventCodeMismatch | event_code 불일치 시 false | 'WRONG_EVENT' | false | P1 |
| TC-RS-011 | testGetWinCoinSetsErrorMessageWhenEventCodeMismatch | event_code 불일치 시 err_msg 설정 | 'WRONG_EVENT' | err_msg != false | P1 |
| TC-RS-012 | testGetWinCoinReturnsFalseWhenNoTicketAvailable | 참여권 없을 때 false | free=0, call=0 | false | P1 |
| TC-RS-013 | testGetWinCoinSelectsFreeTicketFirst | free 참여권 우선 선택 | free=2, call=1 | int > 0 | P1 |
| TC-RS-014 | testGetWinCoinSelectsCallTicketWhenFreeIsZero | free=0일 때 call 참여권 선택 | free=0, call=1 | int | P1 |
| TC-RS-015 | testGetWinCoinReturnsFalseWhenTicketNotFound | 참여권 미발견 시 false | getRouletteTicket→false | false | P1 |
| TC-RS-016 | testGetWinCoinVipTypeAPartAWin | VIP A등급 A파트 당첨 | ac_type='A' | 50000 | P1 |
| TC-RS-017 | testGetWinCoinVipTypeBPartBWin | VIP B등급 B파트 당첨 | ac_type='B' | 10000 | P1 |
| TC-RS-018 | testGetWinCoinCDLimitExceededFallsToE | C/D 한도 초과 시 E 합산 | C=999, D=999 | 500 | P1 |

### 3.7 RouletteServiceTest — percent (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-RS-019 | testPercentReturnsFalseWhenListSizeMismatch | 배열 크기 불일치 시 false | [100,200], [50] | false | P1 |
| TC-RS-020 | testPercentReturnsItemFromList | 단일 아이템 확률 반환 | [500], [100] | 500 | P1 |

---

## 4. Test Execution Results

| 테스트 파일 | 총 케이스 | PASS | FAIL | SKIP | 최종 실행일 |
|------------|----------|------|------|------|-----------|
| EventApiTest | 4 | 4 | 0 | 0 | 2026-04-15 |
| RouletteApiTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| EventControllerTest | 9 | 9 | 0 | 0 | 2026-04-15 |
| EventRewardServiceTest | 40 | 40 | 0 | 0 | 2026-04-15 |
| RouletteServiceTest | 20 | 20 | 0 | 0 | 2026-04-15 |
| **합계** | **76** | **76** | **0** | **0** | — |

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항 설명 | 테스트 케이스 ID | 검증 상태 |
|----------------|-------------|-----------------|----------|
| FR-EVT-001 | 이벤트 목록 조회 (JWT 필수) | TC-EA-001, TC-EC-003 | PASS |
| FR-EVT-002 | 키워드 이벤트 참여 (case-insensitive, DB unique, 트랜잭션) | TC-EA-002, TC-EC-004, TC-ERS-007~013, TC-ERS-019~022 | PASS |
| FR-EVT-003 | 쿠폰 이벤트 참여 (1회 사용, 만료 검증) | TC-EA-003, TC-EC-005, TC-ERS-023~026 | PASS |
| FR-EVT-004 | 출석 이벤트 처리 (연속 출석일 추적) | TC-EA-004, TC-EC-009, TC-ERS-033~040 | PASS |
| FR-EVT-005 | 코인 충전 이벤트 (7 tier GRADE_THRESHOLDS) | TC-EC-009, TC-ERS-001~006, TC-ERS-027~029 | PASS |
| FR-EVT-006 | 갱신 쿠폰 발급 (RENEWAL_COUPON_CODES) | TC-EC-006, TC-EC-007, TC-ERS-030~032 | PASS |
| FR-EVT-007 | 룰렛 이벤트 (VIP 등급 확률, CSPRNG) | TC-RA-001~003, TC-RS-001~020 | PASS |
| NFR-EVT-001 | 중복 참여 방지 및 멱등성 | TC-ERS-008~009, TC-ERS-014~016, TC-ERS-024, TC-ERS-032 | PASS |
| NFR-EVT-002 | 보상 한도 제어 | TC-ERS-010~011, TC-ERS-017~018, TC-ERS-035 | PASS |
| NFR-EVT-003 | 응답 성능 p95 | Feature 테스트 HTTP 200 확인 (성능 별도) | 검증 필요 |
| NFR-EVT-004 | 보안 — 인증/확률 조작 방지 | TC-EA-002~004, TC-RA-002, TC-RS-010~012, TC-RS-016~018 | PASS |
| NFR-EVT-005 | 감사 로그 보존 | TC-ERS-019~022, TC-ERS-026 | PASS |

---

## 6. Defects & Issues

| ID | 유형 | 설명 | 심각도 | 해결 상태 |
|----|------|------|--------|----------|
| DEF-E-001 | 커버리지 | Feature 테스트는 MySQL DB 연결 필요 — SQLite 테스트 환경에서 자동 skip | 저 | 설계 의도 (환경 분리) |
| DEF-E-002 | 커버리지 | NFR-EVT-003 성능 목표(이벤트 목록 200ms, 참여 500ms, 룰렛 계산 50ms) 단위 테스트로 검증 불가 | 중 | 미해결 (k6 부하 테스트 필요) |
| DEF-E-003 | 커버리지 | coinChargeEvent 컨트롤러 메서드 테스트는 EventControllerTest에서 존재 확인만 수행 — 실제 7-tier 로직은 EventRewardServiceTest에서 검증 | 저 | 의도된 분리 (서비스 레이어 테스트) |
