---
문서명: Call — Software Test Documentation
문서 ID: call-std
버전: v1.0
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-16
작성자: jypark
대상 시스템: Call Module
관련 문서: call-srs.md, call-sdd.md, call-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Call — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.0 | lastUpdated: 2026-04-16 | module: Call

---

## 1. Introduction

### 1.1 Purpose

본 Software Test Documentation(STD)은 HongCafe Global Backend Call 모듈에 대한 테스트 항목, 테스트 케이스, 실행 결과, 추적성 매트릭스, 결함 내역을 IEEE 829-2008 표준에 따라 기록한다. Call 모듈의 SRS(call-srs.md)에서 정의한 기능 요구사항(FR-001~FR-010)에 대한 검증 근거를 제공한다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 테스트 대상 모듈 | Call (통화 연결, 종료 정산, PBX 연동, 상담사 대시보드, 알람, 즐겨찾기, 컨텐츠, 코인) |
| 테스트 파일 수 | 11개 (Feature 3, Unit 8) |
| 테스트 메서드 수 | 총 124개 |
| 테스트 프레임워크 | PHPUnit + CodeIgniter 4 CIUnitTestCase / FeatureTestTrait |

### 1.3 References

| 문서 | 경로 |
|------|------|
| Call SRS | `docs/specs/call-srs.md` v2.0 |
| Call SDD | `docs/specs/call-sdd.md` v2.0 |
| Call IDD | `docs/specs/call-idd.md` v2.0 |
| 프로젝트 테스트 계획 | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 파일 목록

| # | 테스트 파일 | 유형 | 테스트 대상 클래스 | 메서드 수 |
|---|-----------|------|------------------|:---------:|
| 1 | `tests/Modules/Call/Feature/CallApiTest.php` | Feature (통합) | CallController API 엔드포인트 | 5 |
| 2 | `tests/Modules/Call/Feature/CalleeApiTest.php` | Feature (통합) | CalleeController API 엔드포인트 | 5 |
| 3 | `tests/Modules/Call/Feature/PbxApiTest.php` | Feature (통합) | PbxController API 엔드포인트 | 5 |
| 4 | `tests/Modules/Call/Unit/CallCloseServiceTest.php` | Unit | CallCloseService (getDurationToCoin 순수 로직) | 16 |
| 5 | `tests/Modules/Call/Unit/CallConnectionServiceTest.php` | Unit | CallConnectionService (유효성 검증, 이벤트, 통화 개시) | 43 |
| 6 | `tests/Modules/Call/Unit/CallControllerTest.php` | Unit | CallController (메서드 존재/상속 확인) | 15 |
| 7 | `tests/Modules/Call/Unit/CalleeActivityServiceTest.php` | Unit | CalleeActivityService (대시보드 데이터) | 12 |
| 8 | `tests/Modules/Call/Unit/CalleeControllerTest.php` | Unit | CalleeController (메서드 존재/상속 확인) | 39 |
| 9 | `tests/Modules/Call/Unit/CalleeManageServiceTest.php` | Unit | CalleeManageService (알람, 상태 변경, item_flag 정규화) | 18 |
| 10 | `tests/Modules/Call/Unit/PbxControllerTest.php` | Unit | PbxController (메서드 존재/상속 확인) | 14 |
| 11 | `tests/Modules/Call/Unit/PbxServiceTest.php` | Unit | PbxService (메서드 존재, makeCrcode, 초기 상태) | 18 |

### 2.2 테스트 대상 클래스/메서드

| 클래스 | 테스트 대상 메서드 |
|--------|------------------|
| `CallCloseService` | `getDurationToCoin()`, `closeCall()`, `closeAlert()`, `getConnectData()`, `insertCallResult()` |
| `CallConnectionService` | `validateCallEligibility()`, `checkEventMarks()`, `calculateRemainTime()`, `getCalleeInfo()`, `validateClassCallEligibility()`, `checkCallerStatus()`, `initiateCall()`, `initiateClassCall()`, `getPopupItemInfo()`, `getCoinCallNumber()`, `checkPaybackMark()`, `checkSpecialPriceMark()` |
| `CalleeActivityService` | `getActivityData()` |
| `CalleeManageService` | `callCloseAlarm()`, `calleeCallDuration()`, `calleePasswdChange()`, `calleeStatusChange()` |
| `PbxService` | `initConnect()`, `callConnect()`, `reservCallCheck()`, `closeCall()`, `closeAlert()`, `checkLive()`, `coinInfo()`, `calleeInfo()`, `get060User()`, `calleeCallDuration()`, `calleePasswdChange()`, `calleeStatusChange()`, `callCloseAlarm()`, `limt060Amount()`, `makeCrcode()` |
| `CallController` | `insertAlarm()`, `deleteAlarm()`, `getPopupInfo()`, `callConnect()`, `classcallConnect()`, `shopCallConnect()`, `getCalleeLikeList()`, `getCalleeIngList()`, `memosave()`, `callerAddLike()`, `callerDeleteLike()`, `allDeleteLike()`, `calleeOnlineCall()`, `getCallConnectAbleList()` |
| `CalleeController` | 39개 메서드 (대시보드, 댓글, QnA, 포스팅, 채팅, 견적, 포인트 등) |
| `PbxController` | `initConnect()`, `callConnect()`, `closeCall()`, `closeAlert()`, `liveCheck()`, `coinInfo()`, `calleeInfo()`, `user060Info()`, `calleeCallDuration()`, `calleePasswdChange()`, `calleeStatusChange()`, `reservCallCheck()`, `limt060Amount()` |

---

## 3. Test Cases

### 3.1 CallApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-001 | `testInsertAlarmReturnsUnauthorizedWhenNotLoggedIn` | 미인증 insertAlarm 요청 시 인증 오류 | `{item_code, ra_type}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CALL-002 | `testGetPopupInfoReturnsValidationErrorWhenItCodeMissing` | it_code 누락 시 유효성 오류 | `{}` | HTTP 200, `result: false` | P1 |
| TC-CALL-003 | `testCallConnectReturnsUnauthorizedWhenNotLoggedIn` | 미인증 callConnect 요청 시 인증 오류 | `{it_code, country_code}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CALL-004 | `testGetCallConnectAbleListReturnsValidationErrorWhenItemCodeListMissing` | itemCodeList 누락 시 유효성 오류 | `{}` | HTTP 200, `result: false` | P1 |
| TC-CALL-005 | `testDeleteAlarmReturnsUnauthorizedWhenNotLoggedIn` | 미인증 deleteAlarm 요청 시 인증 오류 | `{item_code, ra_type}` (인증 없음) | HTTP 200, `result: false` | P1 |

### 3.2 CalleeApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-006 | `testGetActivityInfoReturnsUnauthorizedWhenNotLoggedIn` | 미인증 getActivityInfo 시 오류 | `{}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CALL-007 | `testGetCallStatusReturnsUnauthorizedWhenNotLoggedIn` | 미인증 getCallStatus 시 오류 | `{}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CALL-008 | `testUpdateCallStatusReturnsUnauthorizedWhenNotLoggedIn` | 미인증 updateCallStatus 시 오류 | `{it_online: 'on'}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CALL-009 | `testGetReplyCommentCntReturnsUnauthorizedWhenNotLoggedIn` | 미인증 getReplyCommentCnt 시 오류 | `{}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CALL-010 | `testGetMyCommentListReturnsUnauthorizedWhenNotLoggedIn` | 미인증 getMyCommentList 시 오류 | `{}` (인증 없음) | HTTP 200, `result: false` | P1 |

### 3.3 PbxApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-011 | `testInitConnectWithoutCrCodeReturnsError` | cr_code 없이 initConnect 시 에러 | `{it_code: 'IT-001'}` | `code: 'NOT_EXIST_AC_DATA'` | P0 |
| TC-CALL-012 | `testCallConnectWithoutCaIdReturnsError` | ca_id 없이 CallConnect 시 에러 | `{ca_request_time, ca_start_time}` | `code: 'NOT_EXIST_CA_ID'` | P0 |
| TC-CALL-013 | `testCloseCallWithoutCaIdReturnsError` | ca_id 없이 CloseCall 시 에러 | `{}` | `code: 'NOT_EXIST_CA_ID'` | P0 |
| TC-CALL-014 | `testCoinInfoWithoutCrPhoneReturnsError` | cr_phone 없이 CoinInfo 시 에러 | `{}` | `code: 'NOT_EXIST_CR_PHONE'` | P0 |
| TC-CALL-015 | `testCalleeInfoWithMissingFieldsReturnsError` | 필수 필드 없이 CalleeInfo 시 에러 | `{}` | `code` 키 존재 | P0 |

### 3.4 CallCloseServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-016 | `testServiceCanBeInstantiated` | 인스턴스 생성 확인 | `new CallCloseService()` | `instanceof CallCloseService` | P1 |
| TC-CALL-017 | `testGetDurationToCoinReturnsCorrectValueForNormalDuration` | 정상: 90초, 100원 → 300코인 | duration=90, price=100 | `300` | P0 |
| TC-CALL-018 | `testGetDurationToCoinFloorsWhenNotExactMultiple` | COIN_TERM 비배수 floor 처리: 100초 → 3단위 | duration=100, price=100 | `300` | P0 |
| TC-CALL-019 | `testGetDurationToCoinReturnsZeroWhenDurationBelowOneTerm` | 29초 → 0코인 | duration=29, price=100 | `0` | P0 |
| TC-CALL-020 | `testGetDurationToCoinReturnsZeroForZeroDuration` | 0초 → 0코인 | duration=0, price=500 | `0` | P0 |
| TC-CALL-021 | `testGetDurationToCoinReturnsOnePeriodCoin` | 정확히 30초 → 1단위 코인 | duration=30, price=200 | `200` | P0 |
| TC-CALL-022 | `testGetDurationToCoinHandlesLargeDuration` | 3600초(1시간) 대량 계산 | duration=3600, price=300 | `36000` | P1 |
| TC-CALL-023 | `testGetDurationToCoinReturnsZeroWhenPriceIsZero` | price=0 → 항상 0 | duration=3600, price=0 | `0` | P1 |
| TC-CALL-024 | `testGetDurationToCoinReturnsInteger` | 반환 타입 int 확인 | duration=90, price=100 | `assertIsInt` | P1 |
| TC-CALL-025~028 | 메서드 존재 확인 4건 | closeCall, closeAlert, getConnectData, insertCallResult | `method_exists` | true | P1 |
| TC-CALL-029 | `testResultPropertyIsInitiallyEmptyArray` | result 프로퍼티 초기값 빈 배열 | 초기 상태 | `[]` | P2 |
| TC-CALL-030 | `testErrMsgPropertyIsInitiallyNull` | err_msg 프로퍼티 초기값 null | 초기 상태 | `null` | P2 |
| TC-CALL-031~034 | DB 의존 메서드 skip 4건 | closeCall, closeAlert, getConnectData, insertCallResult | `markTestSkipped` | Skipped | P2 |

### 3.5 CallConnectionServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-035 | `testValidateCallEligibilityPassesWhenAllConditionsMet` | 모든 조건 충족 시 예외 없음 | 정상 items + member | 예외 미발생 | P0 |
| TC-CALL-036 | `testValidateCallEligibilityThrowsExceptionWhenCallerIsSameAsCallee` | 본인 통화 시도 시 예외 | 동일 전화번호 | `Exception` | P0 |
| TC-CALL-037 | `testValidateCallEligibilityThrowsExceptionWhenMemberIsBlocked` | 차단 회원 시 예외 | checkReject=1 | `Exception` | P0 |
| TC-CALL-038 | `testValidateCallEligibilityThrowsExceptionWhenCalleeIsOffline` | 부재중 상담사 시 예외 | it_online='off' | `Exception` | P0 |
| TC-CALL-039 | `testValidateCallEligibilityThrowsExceptionWhenCalleeOnCall` | 통화중 상담사 시 예외 | getCalleeStatus=true | `Exception` | P0 |
| TC-CALL-040 | `testValidateCallEligibilityThrowsExceptionWhenInsufficientCoins` | 코인 부족 시 예외 | ac_remain_coin=499 | `Exception` | P0 |
| TC-CALL-041~043 | checkEventMarks 3건 | null/빈값 accountId 시 both false, 키 구조 확인 | null, '', null | `paybackMark: false`, `specialPriceMark: false` | P1 |
| TC-CALL-044~048 | calculateRemainTime 5건 | 시간/분/초 포함 여부, 0分 반환, 小 밸런스 | 다양한 coin/price | 시간/분/초 포맷 문자열 | P1 |
| TC-CALL-049~051 | getCalleeInfo 3건 | 정상 반환, null 시 예외, false 시 예외 | 정상/null/false mock | object / Exception | P0 |
| TC-CALL-052~054 | validateClassCallEligibility 3건 | 정상, 오프라인 예외, 통화중 예외 | 다양한 상태 | 예외 미발생 / Exception | P0 |
| TC-CALL-055~058 | checkCallerStatus 4건 | 미통화 null, 재연결 info, 타입 불일치 예외 | 다양한 callConnect 결과 | null / 재연결 배열 / Exception | P1 |
| TC-CALL-059~063 | initiateCall 5건 | 신규 성공, 재연결, Hermes 실패, 로컬 Insert 실패 | 다양한 mock | success/reconnect/Exception | P0 |
| TC-CALL-064~068 | initiateClassCall 5건 | 신규 성공, caid append, Hermes 실패, Insert 실패 | 다양한 mock | success/Exception | P0 |
| TC-CALL-069~070 | getPopupItemInfo 2건 | 정상 반환, 미발견 null | mock 결과 | object / null | P1 |
| TC-CALL-071 | `testGetCoinCallNumberReturnsPhoneNumber` | 코인 전화번호 반환 | mock stn_callno | 전화번호 문자열 | P1 |
| TC-CALL-072~077 | checkPaybackMark 6건 | 이벤트 없음, 시작 전, 종료 후, 총액 초과, 상담사 한도, 기참여 → false. 전 조건 통과 → true | 다양한 payback 데이터 | false×6, true×1 | P1 |
| TC-CALL-078~083 | checkSpecialPriceMark 6건 | 이벤트 없음~기참여 → false, 전 조건 통과 → true | 다양한 specialPrice 데이터 | false×6, true×1 | P1 |
| TC-CALL-084~085 | checkEventMarks (accountId 있는 경우) 2건 | 양쪽 false, 양쪽 true | mock 조합 | 각 마크 false/true | P1 |

### 3.6 CallControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-086 | `testControllerExtendsBaseApiController` | CallController 상속 확인 | Reflection | true | P1 |
| TC-CALL-087~100 | 메서드 존재 확인 14건 | insertAlarm~getCallConnectAbleList | `method_exists` | 모두 true | P1 |

### 3.7 CalleeActivityServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-101 | `testServiceCanBeInstantiated` | 인스턴스 생성 확인 | DI mock | `instanceof CalleeActivityService` | P1 |
| TC-CALL-102 | `testGetActivityDataReturnsAllRequiredKeys` | 필수 키 7개 확인 | 정상 stub | it_online, replyAll, replyDone, replyNeed, qnaAll, qnaStandby, finance | P0 |
| TC-CALL-103 | `testGetActivityDataReturnsOnlineStatusOn` | 온라인 상태 'on' 반환 | getCallStatus → on | `it_online == 'on'` | P0 |
| TC-CALL-104 | `testGetActivityDataReturnsOfflineStatusWhenCallStatusIsNull` | null 시 'off' 반환 | getCallStatus → null | `it_online == 'off'` | P0 |
| TC-CALL-105 | `testGetActivityDataReturnsZeroReplyCountsWhenRepositoryReturnsNull` | null reply → 0 | getReplyCommentCnt → null | replyAll/Done/Need = 0 | P1 |
| TC-CALL-106 | `testGetActivityDataFormatsReplyCountsCorrectly` | 정상 reply 포맷 | replyDone=10, replyNeed=5 | replyAll='15', replyDone='10', replyNeed='5' | P1 |
| TC-CALL-107 | `testGetActivityDataReturnsZeroQnaCountsWhenRepositoryReturnsNull` | null QnA → 0 | getQnaCnt → null | qnaAll/qnaStandby = 0 | P1 |
| TC-CALL-108 | `testGetActivityDataFormatsQnaCountsCorrectly` | 정상 QnA 포맷 | qnaAll=20, qnaStandby=3 | qnaAll='20', qnaStandby='3' | P1 |
| TC-CALL-109 | `testGetActivityDataFinanceSubsectionContainsRequiredKeys` | finance 필수 키 확인 | 정상 stub | fdr_total, fdr_money, onDur | P1 |
| TC-CALL-110 | `testGetActivityDataFinanceReturnsZeroWhenCpCodeIsNotPvkOrPvj` | cpCode OTHER → 0 | cpCode='OTHER', f_duration=0 | fdr_money='0', onDur=0 | P1 |
| TC-CALL-111 | `testGetActivityDataOverridesFdrMoneyWhenCalleeGradeIsPositive` | grade > 0 → 레벨 조정 메시지 | grade=1 | fdr_money='"レベル調整中です。"' | P2 |

### 3.8 CalleeControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-112 | `testControllerExtendsBaseApiController` | CalleeController 상속 확인 | Reflection | true | P1 |
| TC-CALL-113~150 | 메서드 존재 확인 38건 | getActivityInfo~updateCounselTime | `method_exists` | 모두 true | P1 |

### 3.9 CalleeManageServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-151 | `testServiceCanBeInstantiated` | 인스턴스 생성 확인 | `new CalleeManageService()` | `instanceof` | P1 |
| TC-CALL-152 | `testServiceImplementsCalleeManageServiceInterface` | 인터페이스 구현 확인 | `instanceof` | true | P1 |
| TC-CALL-153~154 | 프로퍼티 초기값 2건 | result=[], err_msg=null | 초기 상태 | 각각 `[]`, `null` | P2 |
| TC-CALL-155~158 | 메서드 존재 확인 4건 | calleeCallDuration~callCloseAlarm | `method_exists` | true | P1 |
| TC-CALL-159 | `testCallCloseAlarmDefaultItemFlagIsCall` | item_flag 기본값 'call' 확인 | Reflection | `'call'` | P1 |
| TC-CALL-160 | `testCallCloseAlarmDefaultRaStatusIsComplete` | ra_status 기본값 'complete' 확인 | Reflection | `'complete'` | P1 |
| TC-CALL-161~164 | item_flag 정규화 로직 4건 | 'sms'→'call', 'chat'유지, 'video'유지, ''→'call' | 조건문 직접 평가 | 각 기대값 | P1 |
| TC-CALL-165~167 | Reflection 가시성 2건 + DB skip 1건 | returnError/getItemData private, callCloseAlarm DB skip | Reflection/markTestSkipped | private / Skipped | P2 |

### 3.10 PbxControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-168 | `testControllerExtendsBaseApiController` | PbxController 상속 확인 | Reflection | true | P1 |
| TC-CALL-169~181 | 메서드 존재 확인 13건 | initConnect~limt060Amount | `method_exists` | 모두 true | P1 |

### 3.11 PbxServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CALL-182 | `testServiceCanBeInstantiated` | PbxService 인스턴스 생성 확인 | `new PbxService()` | `instanceof` | P1 |
| TC-CALL-183~196 | 메서드 존재 확인 14건 | initConnect~limt060Amount | `method_exists` | 모두 true | P1 |
| TC-CALL-197 | `testInitialResultIsEmpty` | result 초기값 빈 배열 | Reflection | `[]` | P2 |
| TC-CALL-198 | `testInitialErrMsgIsNull` | err_msg 초기값 null | 프로퍼티 접근 | `null` | P2 |
| TC-CALL-199 | `testMakeCrcodeReturnsCorrectFormat` | makeCrcode 형식 `CR-YYYYMMDDHHmmss-XXX` 확인 | `PbxService::makeCrcode()` | `CR-`로 시작, 정규식 일치 | P1 |
| TC-CALL-200 | `testMakeCrcodeReturnsUniqueValues` | makeCrcode 고유값 생성 확인 | 2회 호출 | 문자열 타입, 고유성 | P1 |

---

## 4. Test Execution Results

| 테스트 파일 | 총 테스트 | PASS | FAIL | SKIP | 최종 실행일 |
|-----------|:---------:|:----:|:----:|:----:|:----------:|
| CallApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| CalleeApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| PbxApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| CallCloseServiceTest | 16 | 12 | 0 | 4 | 2026-04-15 |
| CallConnectionServiceTest | 43 | 43 | 0 | 0 | 2026-04-15 |
| CallControllerTest | 15 | 15 | 0 | 0 | 2026-04-15 |
| CalleeActivityServiceTest | 12 | 12 | 0 | 0 | 2026-04-15 |
| CalleeControllerTest | 39 | 39 | 0 | 0 | 2026-04-15 |
| CalleeManageServiceTest | 18 | 14 | 0 | 4 | 2026-04-15 |
| PbxControllerTest | 14 | 14 | 0 | 0 | 2026-04-15 |
| PbxServiceTest | 18 | 18 | 0 | 0 | 2026-04-15 |
| **합계** | **190** | **182** | **0** | **8** | **2026-04-15** |

> 참고: SKIP 8건은 DB 트랜잭션/Hermes DB 직접 접근 의존으로 Unit 환경에서 실행 불가하여 `markTestSkipped` 처리됨.

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항 명 | 테스트 케이스 ID | 커버리지 |
|----------------|-----------|----------------|:--------:|
| FR-001 (통화 연결) | Call Connection | TC-CALL-003, TC-CALL-035~040, TC-CALL-052~054, TC-CALL-059~068 | 커버 |
| FR-001-01 | 코인 잔액 검증 | TC-CALL-040 | 커버 |
| FR-001-02 | Callee 상태 확인 | TC-CALL-038, TC-CALL-039, TC-CALL-053, TC-CALL-054 | 커버 |
| FR-001-07 | 멱등키 중복 방지 | (전용 테스트 미구현) | 미커버 |
| FR-001-08 | 이벤트 마크 확인 | TC-CALL-041~043, TC-CALL-072~085 | 커버 |
| FR-002 (통화 종료·정산) | Call Close and Coin Settlement | TC-CALL-017~024 | 커버 |
| FR-002-02 | ≤30초 무료 | TC-CALL-019, TC-CALL-020 | 커버 |
| FR-002-03 | COIN_TERM 단위 차감 | TC-CALL-017, TC-CALL-018, TC-CALL-021 | 커버 |
| FR-002-08 | getDurationToCoin 순수 함수 | TC-CALL-017~024 | 커버 |
| FR-003 (PBX 연동) | Hermes PBX Integration | TC-CALL-011~015 | 커버 |
| FR-003-06 | checkLive 헬스체크 | TC-CALL-190 (메서드 존재) | 부분 커버 |
| FR-003-07 | coinInfo 조회 | TC-CALL-014, TC-CALL-191 | 커버 |
| FR-004 (상담사 대시보드) | Callee Dashboard | TC-CALL-006, TC-CALL-101~111 | 커버 |
| FR-005 (상담사 알람) | Callee Alarm | TC-CALL-001, TC-CALL-155~167 | 부분 커버 |
| FR-006 (즐겨찾기) | Favorites | TC-CALL-005 (deleteAlarm 인증) | 부분 커버 |
| FR-009 (코인 관리) | Coin Management | TC-CALL-071 (getCoinCallNumber) | 부분 커버 |
| FR-010 (060 전화 연동) | 060 Phone Integration | TC-CALL-011~015, TC-CALL-199~200 | 커버 |
| NFR-010 | 코인 정확도 | TC-CALL-017~024 (getDurationToCoin 전 케이스) | 커버 |
| NFR-011 | 멱등성 보장 | (전용 테스트 미구현) | 미커버 |
| NFR-030 | role:callee 필터 | TC-CALL-006~010 (미인증 거부 확인) | 부분 커버 |

---

## 6. Defects & Issues

| # | 결함 ID | 심각도 | 설명 | 발견일 | 상태 |
|---|--------|:------:|------|-------|:----:|
| 1 | CALL-DEF-001 | High | FR-001-07(멱등키 중복 방지) 전용 테스트 미구현. `X-Idempotency-Key` 헤더 중복 요청 시 409 반환 검증 필요 | 2026-04-16 | Open |
| 2 | CALL-DEF-002 | Medium | FR-002-04(트랜잭션 원자성) 통합 테스트 미구현. 코인 차감 + Outbox + 상태 갱신 원자적 처리 검증 필요 | 2026-04-16 | Open |
| 3 | CALL-DEF-003 | Medium | CallCloseService의 closeCall, closeAlert, getConnectData, insertCallResult 4개 메서드가 DB 의존으로 Unit 테스트 SKIP. Integration 테스트 전환 필요 | 2026-04-16 | Open |
| 4 | CALL-DEF-004 | Medium | CalleeManageService의 callCloseAlarm, calleeCallDuration, calleePasswdChange, calleeStatusChange 4개 메서드가 DB 의존으로 SKIP. Integration 테스트 전환 필요 | 2026-04-16 | Open |
| 5 | CALL-DEF-005 | Low | NFR-011(멱등성) DB unique 제약 검증 통합 테스트 미구현 | 2026-04-16 | Open |

---

## 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-16 | 1.0.0 | 초기 작성. IEEE 829-2008 기반 STD 문서 생성. 테스트 파일 11개, 테스트 케이스 190개(SKIP 8 포함) 기록 | jypark |
