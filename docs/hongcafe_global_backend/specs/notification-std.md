---
문서명: Notification — Software Test Documentation
문서 ID: notification-std
버전: v1.1
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Notification Module
관련 문서: notification-srs.md, notification-sdd.md, notification-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Notification — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.1 | lastUpdated: 2026-04-21 | module: Notification

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Notification 모듈의 테스트 케이스, 실행 결과, 요구사항 추적성을 IEEE 829-2008 표준에 따라 기록한다. 테스트 설계 및 검증의 기준 문서로 활용된다.

### 1.2 Scope

Notification 모듈의 FCM 토큰 등록, 한국 상담사 FCM 알림 발송, 알람 이력 기록 기능을 대상으로 한다. 3개 테스트 파일(FcmApiTest, FcmControllerTest, FcmNotificationServiceTest)에 포함된 총 20개 테스트 메서드를 검증 범위로 한다.

### 1.3 References

| 문서 | 경로 |
|------|------|
| SRS | `docs/specs/notification-srs.md` v2.1 |
| SDD | `docs/specs/notification-sdd.md` v2.1 |
| IDD | `docs/specs/notification-idd.md` v2.1 |
| STP | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 대상 클래스/메서드 목록

| 테스트 파일 | 테스트 유형 | 대상 클래스 | 테스트 수 |
|-----------|-----------|-----------|---------|
| `FcmApiTest` | Feature (통합) | `FcmController` (API 엔드포인트) | 5 |
| `FcmControllerTest` | Unit | `FcmController` | 3 |
| `FcmNotificationServiceTest` | Unit | `FcmNotificationService` | 12 |

---

## 3. Test Cases

### 3.1 FcmApiTest (Feature)

> **URL 기준**: 실제 Routes.php 기준 `POST /api/fcm/index`. 파라미터: `cr_code`, `st_code`, `token`, `type` (snake_case).
> **기대 결과 기준**: `FcmController::index()` 실제 동작 — 파라미터 누락/빈값 시 HTTP 500 + `{"error":{"code":"INTERNAL",...}}` 반환 (400 아님, NOTIF-DEF-009).

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-NTF-001 | `testIndexWithoutCrCodeReturnsError` | cr_code 없이 POST /api/fcm/index 요청 시 에러 응답 반환 | `{ st_code, token, type }` (cr_code 누락) | HTTP 500 + `{"error":{"code":"INTERNAL","message":"CR_CODE NOT EXIST"}}` | P1 |
| TC-NTF-002 | `testIndexWithoutTokenReturnsError` | token 없이 POST /api/fcm/index 요청 시 에러 응답 반환 | `{ cr_code, st_code, type }` (token 누락) | HTTP 500 + `{"error":{"code":"INTERNAL","message":"TOKEN NOT EXIST"}}` | P1 |
| TC-NTF-003 | `testIndexWithoutStCodeReturnsError` | st_code 없이 POST /api/fcm/index 요청 시 에러 응답 반환 | `{ cr_code, token, type }` (st_code 누락) | HTTP 500 + `{"error":{"code":"INTERNAL","message":"ST_CODE NOT EXIST"}}` | P1 |
| TC-NTF-004 | `testIndexWithoutTypeReturnsError` | type 없이 POST /api/fcm/index 요청 시 에러 응답 반환 | `{ cr_code, st_code, token }` (type 누락) | HTTP 500 + `{"error":{"code":"INTERNAL","message":"TYPE NOT EXIST"}}` | P1 |
| TC-NTF-005 | `testIndexWithEmptyPayloadReturnsError` | 빈 페이로드로 POST /api/fcm/index 요청 시 에러 응답 반환 | `{}` | HTTP 500 + `{"error":{"code":"INTERNAL","message":"CR_CODE NOT EXIST"}}` | P1 |

### 3.2 FcmControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-NTF-006 | `testControllerExtendsBaseApiController` | FcmController가 BaseApiController를 상속하는지 검증 | Reflection | `isSubclassOf(BaseApiController::class)` = true | P1 |
| TC-NTF-007 | `testIndexMethodExists` | FcmController에 index 메서드 존재 여부 검증 | Reflection | `method_exists` = true | P1 |
| TC-NTF-008 | `testKoreaCalleeFcmMethodExists` | FcmController에 koreaCalleeFcm 메서드 존재 여부 검증 | Reflection | `method_exists` = true | P1 |

### 3.3 FcmNotificationServiceTest (Unit)

> **파라미터 기준**: `sendKoreaCalleeNotification(string $calleeCode, string $itemFlag): bool` 실제 구현 기준. `calleeCode`와 `itemFlag` 2개 파라미터.

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-NTF-009 | `testSendKoreaCalleeNotificationReturnsFalseWhenNoAlarmExists` | 알람 없는 경우 false 반환 | calleeCode='CE-001', itemFlag='call', getReturnAlarm=[] | `assertFalse($result)` | P1 |
| TC-NTF-010 | `testSendKoreaCalleeNotificationReturnsFalseWhenAlarmRepositoryReturnsEmptyArray` | AlarmRepository 빈 배열 반환 시 false | calleeCode='CE-002', itemFlag='chat', getReturnAlarm=[] | `assertFalse($result)` | P1 |
| TC-NTF-011 | `testSendKoreaCalleeNotificationReturnsTrueWhenAlarmListExists` | 알람 목록 존재 시 true 반환 (레거시 Fcm 외부 의존으로 SKIP) | - | `markTestSkipped` | P1 |
| TC-NTF-012 | `testFcmNotificationServiceClassExists` | FcmNotificationService 클래스 존재 확인 | Reflection | `class_exists` = true | P2 |
| TC-NTF-013 | `testSendKoreaCalleeNotificationMethodExists` | sendKoreaCalleeNotification 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-NTF-014 | `testConstructorAcceptsThreeNullableRepositoryParameters` | 생성자 파라미터 3개, 모두 nullable | Reflection | 파라미터 수 3, 이름 일치 (`alarmRepository`, `memberRepository`, `mypageRepository`), allowsNull = true | P2 |
| TC-NTF-015 | `testSendKoreaCalleeNotificationAcceptsTwoStringParameters` | sendKoreaCalleeNotification 파라미터 2개 (calleeCode, itemFlag) | Reflection | 파라미터 수 2, 이름 `calleeCode`·`itemFlag` 일치, 타입 `string` | P2 |
| TC-NTF-016 | `testSendKoreaCalleeNotificationReturnTypeIsBool` | 반환 타입이 bool인지 검증 | Reflection | `getReturnType()->getName()` = 'bool' | P2 |
| TC-NTF-017 | `testServiceCanBeInstantiatedWithMockedRepositories` | Mock Repository 주입 후 인스턴스화 가능 | Mock 3개 주입 (AlarmRepository, MemberRepository, MypageRepository) | `assertInstanceOf(FcmNotificationService::class)` | P1 |
| TC-NTF-018 | `testMemberRepositoryItemCodeSelectIsCalledWithCorrectArguments` | MemberRepository.ItemCodeSelect 호출 인자 검증 | calleeCode='CE-010', itemFlag='call' | `expects(once())->method('ItemCodeSelect')->with('CE-010', 'call')` | P1 |
| TC-NTF-019 | `testAlarmRepositoryGetReturnAlarmIsCalledAfterItemCodeSelect` | AlarmRepository.getReturnAlarm 호출 순서 검증 | calleeCode='CE-020', itemFlag='chat' | `expects(once())->method('getReturnAlarm')` | P1 |

---

## 4. Test Execution Results

| TC ID | 상태 | 최종 실행일 | 비고 |
|-------|------|-----------|------|
| TC-NTF-001 | SKIP | 2026-04-15 | MySQL DB 연결 필요 (Feature 테스트) |
| TC-NTF-002 | SKIP | 2026-04-15 | MySQL DB 연결 필요 (Feature 테스트) |
| TC-NTF-003 | SKIP | 2026-04-15 | MySQL DB 연결 필요 (Feature 테스트) |
| TC-NTF-004 | SKIP | 2026-04-15 | MySQL DB 연결 필요 (Feature 테스트) |
| TC-NTF-005 | SKIP | 2026-04-15 | MySQL DB 연결 필요 (Feature 테스트) |
| TC-NTF-006 | PASS | 2026-04-15 | |
| TC-NTF-007 | PASS | 2026-04-15 | |
| TC-NTF-008 | PASS | 2026-04-15 | |
| TC-NTF-009 | PASS | 2026-04-15 | |
| TC-NTF-010 | PASS | 2026-04-15 | |
| TC-NTF-011 | SKIP | 2026-04-15 | 레거시 Fcm::sendFcm() 외부 라이브러리 의존 |
| TC-NTF-012 | PASS | 2026-04-15 | |
| TC-NTF-013 | PASS | 2026-04-15 | |
| TC-NTF-014 | PASS | 2026-04-15 | |
| TC-NTF-015 | PASS | 2026-04-15 | |
| TC-NTF-016 | PASS | 2026-04-15 | |
| TC-NTF-017 | PASS | 2026-04-15 | |
| TC-NTF-018 | PASS | 2026-04-15 | |
| TC-NTF-019 | PASS | 2026-04-15 | |

**요약**: 총 20개 중 PASS 14개, SKIP 6개 (외부 의존/DB 연결 필요), FAIL 0개

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항명 | 테스트 케이스 ID |
|----------------|----------|----------------|
| FR-001 | FCM 토큰 등록 | TC-NTF-001, TC-NTF-002, TC-NTF-003, TC-NTF-004, TC-NTF-005, TC-NTF-006, TC-NTF-007 |
| FR-002 | 한국 상담사 FCM 발송 | TC-NTF-008, TC-NTF-009, TC-NTF-010, TC-NTF-011, TC-NTF-017, TC-NTF-018, TC-NTF-019 |
| FR-002a | 일본어 메시지 발송 | TC-NTF-011 (SKIP - 레거시 Fcm 외부 의존) |
| FR-002b | 알람 이력 기록 | TC-NTF-019 |
| FR-002c | FCM 토큰 만료 처리 | TC 미구현 — 외부 FCM 의존. 레거시 라이브러리 Mock 기반 TC 추가 예정 |
| NFR-001 | FCM 발송 결과 알람 상태 갱신 | TC-NTF-009, TC-NTF-010 |
| NFR-003 | FCM 토큰 EP 인증 | TC-NTF-001 ~ TC-NTF-005 (파라미터 검증. 필터 미설정으로 인증 TC는 현재 불가) |

> **FR-002c 주의 (NOTIF-DEF-013)**: SRS v2.0 Verification Matrix에 기재되었던 TC명 `test_expired_token_deleted_on_not_registered`는 STD에 존재하지 않는 TC이다. v2.1에서 삭제. FR-002c는 현재 TC 미구현 상태이며 레거시 `Fcm` 라이브러리 Mock 기반 TC 추가가 권장된다.

---

## 6. Defects & Issues

| ID | 설명 | 심각도 | 상태 | 비고 |
|----|------|--------|------|------|
| DEF-NTF-001 | FR-002a 일본어 메시지 발송 테스트가 레거시 Fcm::sendFcm() 외부 라이브러리 의존으로 단위 테스트 불가 | 낮음 | 허용 | 통합 테스트 환경에서 검증 필요 |
| DEF-NTF-002 | FR-002c FCM 토큰 만료 처리(NotRegistered) 전용 테스트 케이스 미구현 | 중간 | 미해결 | 레거시 Fcm 라이브러리 Mock 기반 TC 추가 권장 |
| DEF-NTF-003 | Feature 테스트(TC-NTF-001~005)가 MySQL DB 연결 없이 실행 불가 | 낮음 | 허용 | 테스트 환경 구성 후 실행 가능 |

---

## 7. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| v1.0 → v1.1: [A] 이슈 반영 (2026-04-21) | API SSOT 기준으로 TC URL 및 기대 결과 수정 | notification-api-vs-ieee-20260421.md 대조 리포트 기반 재작성 |
| NOTIF-DEF-001: §3.1 FcmApiTest TC URL 수정 | TC-NTF-001~005 설명에서 URL 기준을 `/api/fcm/index`로 명시 | Routes.php 실제 URL = `post('fcm/index', ...)`. 이전 SRS URL(`/api/notifications/fcm-token`)이 TC 기준으로 사용되던 것을 수정 |
| NOTIF-DEF-002: §3.1 FcmApiTest 파라미터 수정 | TC 입력 파라미터를 `cr_code`, `st_code`, `token`, `type`으로 수정 (기존 `fcmToken/deviceId` 제거) | `FcmController::index()` 실제 파라미터 기준. 존재하지 않는 파라미터로 TC를 작성하면 통과 기준이 무의미 |
| NOTIF-DEF-009: §3.1 TC-NTF-001~005 기대 결과 수정 | "HTTP 200 + 비어있지 않은 응답 본문" → "HTTP 500 + `{"error":{"code":"INTERNAL",...}}`" | `FcmController::index()` 실제 코드: 파라미터 누락 시 `respondError('INTERNAL', ..., 500)` 반환. 400이 아닌 500. 기대 결과가 실제 동작과 불일치하던 것을 수정 |
| NOTIF-DEF-013: §5 Traceability Matrix FR-002c 수정 | "(미구현 - 외부 FCM 의존)" → "TC 미구현 — 외부 FCM 의존. 레거시 라이브러리 Mock 기반 TC 추가 예정"으로 더 명확하게 기술 | SRS v2.1에서 존재하지 않는 TC명 삭제 결정. STD도 동기화. FR-002c TC 미구현 사실을 명시적으로 기록하여 향후 TC 추가 근거 제공 |
| §3.1 TC 기대 결과 개선 | TC-NTF-001~005의 모호한 "비어있지 않은 응답 본문" 대신 실제 에러 메시지 명세 | 기대 결과가 구체적이어야 TC 재실행 시 Pass/Fail 판정 기준이 명확함. "비어있지 않은 응답 본문"은 어떤 응답이든 Pass 판정되어 검증력 없음 |
| §3.3 TC-NTF-014 파라미터 이름 명시 | 생성자 파라미터 이름 `alarmRepository`, `memberRepository`, `mypageRepository` 명시 | 실제 코드: `__construct(?AlarmRepositoryInterface $alarmRepository = null, ?MemberRepositoryInterface $memberRepository = null, ?MypageRepositoryInterface $mypageRepository = null)`. 이름 일치 검증 기준 명확화 |

---

## 8. 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-16 | 1.0.0 | 초기 작성 — Notification Module STD. FcmApiTest(5 TC), FcmControllerTest(3 TC), FcmNotificationServiceTest(12 TC). 실행 결과 14 PASS / 6 SKIP | jypark |
| 2026-04-21 | 1.1.0 | API SSOT 대조 리포트 [A] 이슈 반영. TC-NTF-001~005 URL 수정(`/api/fcm/index`, DEF-001), 파라미터 수정(`cr_code`/`st_code`/`token`/`type`, DEF-002), 기대 결과 수정(HTTP 500 + INTERNAL, DEF-009). Traceability Matrix FR-002c TC 미구현 명시 강화(DEF-013). 변경 영향 기록 섹션(§7) 신설 | jypark |
