---
문서명: Notification — Software Requirements Specification
문서 ID: notification-srs
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Notification Module (HongCafe Global Backend)
관련 문서: notification-sdd.md, notification-idd.md
적용 표준: IEEE 29148:2018
---

# Notification — Software Requirements Specification (SRS)

> IEEE 29148:2018 | version: 2.1 | lastUpdated: 2026-04-21 | module: Notification

---

## 1. Introduction / 소개

### 1.1 Purpose / 목적

본 Software Requirements Specification(SRS)은 HongCafe Global Backend의 Notification Bounded Context에 대한 기능/비기능 요구사항을 IEEE 29148:2018 표준에 따라 정의한다. 본 문서는 설계(notification-sdd.md), 인터페이스(notification-idd.md), 테스트 케이스 작성의 기준이 된다.

### 1.2 Scope / 범위

| 항목 | 내용 |
|------|------|
| 모듈(BC) | Notification |
| 목적 | FCM(Firebase Cloud Messaging) 기반 푸시 알림 발송. 한국 상담사 대상 통화 요청 알림에 특화 |
| 이해관계자 | 인증된 사용자(Caller/Callee), 내부 통화 서비스 |
| 포함 EP | `POST /api/fcm/index`, `POST /api/fcm/korea-callee-fcm` |
| EP 총수 | 2개 |
| 특이사항 | 알림 메시지는 일본어(Japanese)로 작성됨. `korea-callee-fcm` EP는 서버 간 호출 전용(API Key 인증) |

### 1.3 Definitions, Acronyms, and Abbreviations / 용어 정의

| 용어 | 정의 |
|------|------|
| SRS | Software Requirements Specification |
| FR | Functional Requirement — 기능 요구사항 |
| NFR | Non-Functional Requirement — 비기능 요구사항 |
| FCM | Firebase Cloud Messaging — Google의 크로스 플랫폼 메시지 서비스 |
| FCM Token | 디바이스별 FCM 푸시 수신 토큰 (VARCHAR(512)) |
| cr_code | 사용자(Caller) 식별 코드. FCM 토큰 등록 시 필수 입력 |
| st_code | 스토어(Store) 식별 코드. FCM 토큰 등록 시 필수 입력 |
| ce_code | 상담사(Callee) 식별 코드 |
| Callee | 한국 상담사 (`ce_code` 보유 계정) |
| item_flag | 아이템 유형 플래그 (`call` 또는 `chat`) |
| NotRegistered | FCM 토큰 만료 시 FCM 서버가 반환하는 에러 코드 |
| API Key | 서버 간 인증에 사용하는 정적 키 (`X-Api-Key` 헤더) |

### 1.4 References / 참조 문서

| 문서 | 경로/출처 |
|------|---------|
| 설계 문서 | `docs/specs/notification-sdd.md` v2.1 |
| 인터페이스 문서 | `docs/specs/notification-idd.md` v2.1 |
| 프로젝트 지침 | `CLAUDE.md` |
| IEEE 29148:2018 | ISO/IEC/IEEE 29148:2018 — Requirements Engineering |
| Firebase FCM 공식 문서 | https://firebase.google.com/docs/cloud-messaging |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| RFC 7231 | HTTP/1.1 Semantics and Content |

### 1.5 Overview / 개요

본 SRS는 다음 섹션으로 구성된다.

- §2 Overall Description — 시스템 관점, 기능 개요, 사용자 분류, 제약사항, 가정
- §3 Functional Requirements — FR별 선행조건/후행조건/입력검증/우선순위/관련 API/검증방법
- §4 Non-Functional Requirements — 정량 기준 및 검증 방법
- §5 External Interface Requirements — 외부 시스템 인터페이스
- §6 Use Cases — 주요 유스케이스 정상/대안/에러 흐름
- §7 Verification Matrix — FR↔UC↔Test↔SDD 4-way 매핑
- §8 Data Dictionary — 핵심 데이터 요소 정의
- §9 타당성 검토
- §10 변경 영향 기록
- §11 변경 로그

---

## 2. Overall Description / 전체 설명

### 2.1 System Perspective / 시스템 관점

Notification 모듈은 HongCafe Global Backend의 알림 발송 Bounded Context이다. 외부 FCM 서비스와 연동하여 모바일 푸시 알림을 발송하며, 한국 상담사 대상 통화 요청 알림에 특화되어 있다. 내부 통화 서비스(Call 모듈 또는 Hermes 서버)가 API Key로 호출한다.

```
[Mobile App] ─── (필터 미설정) ───► [FcmController::index()]
                                           │
                                  [MemberRepository::UpdateFcmToken()]
                                           │
                                        Aurora MySQL (tb_account 등)

[Internal Call Service] ─── API Key ───► [FcmController::koreaCalleeFcm()]
                                                    │
                                          [FcmNotificationService::sendKoreaCalleeNotification(
                                              string $calleeCode, string $itemFlag)]
                                                    │
                                          [MemberRepository::ItemCodeSelect()]
                                          [AlarmRepository::getReturnAlarm()]
                                                    │
                                          [Fcm::sendFcm()] ──► Callee's Mobile Device
                                          (레거시 FCM 라이브러리)
```

### 2.2 Functions / 기능 개요

| 기능 그룹 | 설명 |
|----------|------|
| FCM 토큰 등록 | `cr_code`, `st_code`, `token`, `type` 기반 FCM 토큰 갱신 (`MemberRepository::UpdateFcmToken()` 위임) |
| 푸시 알림 발송 | 한국 상담사에게 일본어 통화 요청 알림 FCM 발송. 알람 목록 조회 → FCM 발송 → 알람 완료 처리 → 이력 저장 |
| 알람 완료 처리 | `AlarmRepository::updateReturnAlarmDone()` — 발송 완료 상태 갱신 |

### 2.3 User Classes and Characteristics / 사용자 분류

| 사용자 분류 | 설명 | 인증 수준 |
|-----------|------|----------|
| Caller (일반 사용자) | 모바일 앱에서 FCM 토큰 등록 | 필터 미설정 (현재 미인증 허용 상태) |
| Callee (상담사) | 통화 요청 알림 수신 대상 | 통화 요청 알림 수신 대상 (직접 EP 호출 없음) |
| 내부 서버 (통화 서비스) | `korea-callee-fcm` EP 호출로 알림 발송 트리거 | API Key 인증 필수 |

### 2.4 Constraints / 제약사항

- FCM 발송은 레거시 `Fcm` 라이브러리(`app/Libraries/Fcm`)를 통해 수행한다.
- `korea-callee-fcm` EP는 CSRF 검증 면제 (API Key 인증 서버-서버 통신).
- Auto Routing 비활성화 (`setAutoRoute(false)`). 모든 EP는 `Routes.php`에 명시적 등록 필수.
- `DateTimeImmutable` 강제 (`date()`, `time()` 사용 금지).
- `fcm/index` EP는 현재 Routes.php에 필터가 미설정 상태이다. (NOTIF-DEF-005 — 보안 리스크, Checkpoint 필요)

### 2.5 Assumptions and Dependencies / 가정 및 의존성

| 항목 | 내용 |
|------|------|
| 가정-1 | 레거시 FCM 라이브러리(`app/Libraries/Fcm`)가 정상 동작함 |
| 가정-2 | 내부 통화 서비스가 유효한 API Key를 보유하고 있음 |
| 가정-3 | 대상 상담사가 알람 목록에 등록되어 있음 (`alarmRepository::getReturnAlarm()`) |
| 의존성-1 | `MemberRepository::UpdateFcmToken()` (Member 모듈 소유) |
| 의존성-2 | `MemberRepository::ItemCodeSelect()` (Member 모듈 소유) |
| 의존성-3 | `AlarmRepository::getReturnAlarm()`, `updateReturnAlarmDone()` |
| 의존성-4 | `MypageRepository::SetAlarm()` — 알림 이력 저장 |
| 의존성-5 | 레거시 FCM 라이브러리 (`app/Libraries/Fcm`) |

---

## 3. Functional Requirements / 기능 요구사항

### FR-001: FCM 토큰 등록 (FCM Token Registration)

| 항목 | 내용 |
|------|------|
| 설명 | 디바이스의 FCM 토큰을 `cr_code`, `st_code`, `token`, `type` 4개 파라미터로 수신하여 `MemberRepository::UpdateFcmToken()`에 위임한다 |
| 선행 조건 | 모바일 앱에서 FCM 토큰 발급 완료. (현재 JWT 필터 미설정 — 비인증 요청 허용 상태) |
| 후행 조건 | `MemberRepository::UpdateFcmToken()` 호출 성공 시 200 OK + `{ "data": {} }`. 실패 시 HTTP 500 + `{"error":{"code":"INTERNAL","message":"..."}}` |
| 입력 검증 | `cr_code`: 필수, 빈 값 거부. `st_code`: 필수, 빈 값 거부. `token`: 필수, 빈 값 거부. `type`: 필수, 빈 값 거부. 검증 실패 시 HTTP 500 + `{"error":{"code":"INTERNAL","message":"..."}}` 반환 (400 아님) |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/fcm/index` |
| 검증 방법 | 4개 파라미터 모두 존재 → 200 + `{"data":{}}` 확인. 파라미터 누락 → 500 + `{"error":{"code":"INTERNAL",...}}` 확인 |

### FR-002: 한국 상담사 FCM 발송 (Korea Callee FCM Notification)

| 항목 | 내용 |
|------|------|
| 설명 | 특정 한국 상담사(`ce_code`)에게 FCM 푸시 알림을 발송하고, 알람 완료 처리 및 알림 이력을 저장한다. `item_flag`로 유형(call/chat)을 구분 |
| 선행 조건 | API Key 인증 완료 (`X-Api-Key` 헤더 유효). 대상 상담사의 알람 목록(`getReturnAlarm()`) 존재 |
| 후행 조건 | 알람 목록 있는 경우: FCM 발송 → `updateReturnAlarmDone()` 호출 → `MypageRepository::SetAlarm()` 호출. Service `bool` 반환값을 Controller가 그대로 `return`하여 CI4가 HTTP 응답으로 직렬화 |
| 입력 검증 | `ce_code` (camelCase 요청 시 `ceCode`): 필수, 문자열. `item_flag` (camelCase 요청 시 `itemFlag`): 필수, 문자열. Controller 내 별도 검증 없음 — 미입력 시 PHP TypeError 발생 가능 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/fcm/korea-callee-fcm` |
| 검증 방법 | 알람 목록 있는 상담사 → Service `true` 반환 → CI4 직렬화 응답. 알람 목록 없음 → `false` 반환 |

### FR-002a: 일본어 메시지 발송 (Japanese Message)

| 항목 | 내용 |
|------|------|
| 설명 | FCM 알림 메시지는 일본어로 구성. 레거시 `Fcm` 라이브러리에서 상담사 카테고리명·닉네임 기반으로 메시지 구성 |
| 선행 조건 | FR-002 처리 중 (알람 목록 존재 확인 후) |
| 후행 조건 | FCM 페이로드에 일본어 메시지 포함 |
| 입력 검증 | 알람 목록(`alarmList[0]`)의 `it_category_name`, `it_nick` 필드 사용 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | FR-002와 동일 (`POST /api/fcm/korea-callee-fcm`) |
| 검증 방법 | FCM 페이로드 `title` = `ホンカフェ [{카테고리명}] {닉네임}`. `msg` = `今、鑑定可能です。` 확인 |

### FR-002b: 알람 이력 기록 (Alarm History)

| 항목 | 내용 |
|------|------|
| 설명 | FCM 발송 후 `MypageRepository::SetAlarm()`을 통해 알림 내역을 저장한다 |
| 선행 조건 | FR-002 FCM 발송 및 `updateReturnAlarmDone()` 호출 완료 |
| 후행 조건 | `MypageRepository::SetAlarm()` 호출 완료 |
| 입력 검증 | — |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | FR-002와 동일 (내부 처리) |
| 검증 방법 | `SetAlarm()` 호출 인자 — `type`, `ac_id`, `cr_code`, `subject`, `content`, `link` 확인 |

### FR-002c: FCM 토큰 만료 처리 (Token Expiry)

| 항목 | 내용 |
|------|------|
| 설명 | FCM 발송 실패(NotRegistered 등) 처리는 레거시 `Fcm` 라이브러리 내부에서 처리된다. 현재 Service 코드에 `AlarmRepository::deleteFcmToken()` 호출 없음 |
| 선행 조건 | FCM API 호출 결과 확인 |
| 후행 조건 | 레거시 `Fcm` 라이브러리 내부 처리. 별도 토큰 삭제 로직 없음 |
| 입력 검증 | — |
| 우선순위 | 권장 (Priority 2) |
| 관련 API | FR-002 내부 처리 |
| 검증 방법 | 현재 TC 미구현 — 외부 FCM 의존. 레거시 라이브러리 Mock 기반 TC 추가 예정 |

---

## 4. Non-Functional Requirements / 비기능 요구사항

| ID | 구분 | 요구사항 | 정량 기준 | 검증 방법 |
|----|------|---------|---------|---------|
| NFR-001 | 신뢰성 | FCM 발송 결과 알람 상태 갱신 | 발송 완료 → `updateReturnAlarmDone()` 호출 필수 | 발송 완료 케이스에서 알람 상태 갱신 확인 |
| NFR-002 | 성능 | FCM 발송 응답 시간 | P95 3초 이하 (FCM 서버 응답 포함) | 부하 테스트 + FCM 목업 서버 응답 시간 측정 |
| NFR-003 | 보안 | FCM 토큰 EP 인증 | `fcm/index` EP: 현재 Routes.php 필터 미설정. 인증 필터 추가 필요 (Checkpoint 권장) | JWT 없이 호출 → 현재 정상 처리됨 (보안 리스크) |
| NFR-004 | 보안 | korea-callee-fcm EP 인증 | API Key 인증 필수 (`auth:apikey` 필터). CSRF 면제 (서버-서버) | API Key 없이 호출 → 403 확인 |
| NFR-005 | 보안 | FCM 서버 키 환경변수 관리 | 레거시 `Fcm` 라이브러리 내부에서 관리. 코드 하드코딩 금지 | 코드 리뷰 |
| NFR-006 | 신뢰성 | 알람 이력 보존 기간 | 최소 90일 보존 | 91일 이상 레코드 존재 여부 또는 삭제 정책 확인 |
| NFR-007 | 다국어 | 일본어 메시지 | 알림 메시지 일본어 하드코딩 또는 `lang()` 키 사용 | 코드 리뷰 — FCM 페이로드 `title`/`msg` 일본어 확인 |
| NFR-008 | 신뢰성 | FCM 타임아웃 설정 | FCM HTTP 요청 타임아웃 설정 (레거시 Fcm 라이브러리 내부 설정) | 레거시 `Fcm` 클래스 설정 확인 |
| NFR-009 | 유지보수성 | DateTimeImmutable 강제 | `date()`, `time()` 사용 금지. `new DateTimeImmutable()` 사용 | 코드 리뷰 |
| NFR-010 | 응답 표준 | API 응답 표준 | `fcm/index` 성공: `{"data":{}}`. `korea-callee-fcm`: Service bool 반환 직렬화 | 응답 JSON 확인 |

---

## 5. External Interface Requirements / 외부 인터페이스 요구사항

### 5.1 User Interface / 사용자 인터페이스

- HTTP/HTTPS REST API. JSON 응답 전용.
- `fcm/index` EP: 현재 필터 미설정 (인증 없이 접근 가능 — 보안 리스크).
- `korea-callee-fcm` EP: `X-Api-Key` 헤더 기반 API Key 인증. CSRF 헤더 불필요.

### 5.2 Hardware Interface / 하드웨어 인터페이스

- 해당 없음.

### 5.3 Software Interface / 소프트웨어 인터페이스

| 외부 시스템 | 프로토콜 | 설명 |
|-----------|---------|------|
| Firebase Cloud Messaging API (레거시 Fcm 라이브러리) | HTTPS REST (cURL) | FCM 푸시 알림 발송. 레거시 `app/Libraries/Fcm` 래핑 |
| Member 모듈 (`MemberRepository`) | 내부 DI | `UpdateFcmToken()`, `ItemCodeSelect()` 호출 |
| Alarm Repository | 내부 DI | `getReturnAlarm()`, `updateReturnAlarmDone()` 호출 |
| Mypage Repository | 내부 DI | `SetAlarm()` — 알림 이력 저장 |

### 5.4 Communication Interface / 통신 인터페이스

- `fcm/index` EP: HTTPS. 현재 필터 미설정.
- `korea-callee-fcm` EP: HTTPS + API Key 필터. 내부 서버 간 호출 전용.
- FCM API 호출: 레거시 `Fcm` 라이브러리를 통해 HTTPS POST.

---

## 6. Use Cases / 유스케이스

### UC-001: FCM 토큰 등록

- **액터**: 모바일 앱 (Caller / Callee)
- **관련 FR**: FR-001
- **사전조건**: 모바일 앱에서 FCM 토큰 발급 완료. (현재 인증 미요구)
- **정상 흐름**:
  1. 모바일 앱이 `POST /api/fcm/index` `{ "cr_code": "...", "st_code": "...", "token": "...", "type": "..." }` 전송
  2. `FcmController::index()`가 4개 파라미터 isset + 빈값 체크
  3. `MemberRepository::UpdateFcmToken($post['cr_code'], $post['token'], $post['type'])` 호출
  4. 성공 시 200 OK + `{ "data": {} }`
- **에러 흐름 (E1)**: 파라미터 누락 또는 빈 값 → 500 `{"error":{"code":"INTERNAL","message":"...NOT EXIST"}}`
- **에러 흐름 (E2)**: `UpdateFcmToken()` 실패 → 500 `{"error":{"code":"INTERNAL","message":"..."}}`

### UC-002: 한국 상담사에게 통화 요청 알림 발송

- **액터**: 내부 서버 (통화 연결 서비스)
- **관련 FR**: FR-002, FR-002a, FR-002b, FR-002c
- **사전조건**: API Key 인증 완료. 대상 상담사의 알람 목록 존재
- **정상 흐름 (알람 목록 존재)**:
  1. 내부 서버가 `POST /api/fcm/korea-callee-fcm` `{ "ce_code": "CE-001", "item_flag": "call" }` 전송
  2. API Key 검증 통과 (`auth:apikey` 필터)
  3. `FcmNotificationService::sendKoreaCalleeNotification("CE-001", "call")` 호출
  4. `MemberRepository::ItemCodeSelect("CE-001", "call")` → `item_code` 조회
  5. `AlarmRepository::getReturnAlarm(...)` → 알람 목록 조회
  6. `Fcm::sendFcm(...)` — 레거시 라이브러리로 FCM 발송
  7. `AlarmRepository::updateReturnAlarmDone(...)` — 알람 완료 처리
  8. `MypageRepository::SetAlarm(...)` — 알림 이력 저장
  9. Service `true` 반환 → Controller `return true` → CI4 응답 직렬화
- **대안 흐름 (A1)**: 알람 목록 없음 → Service `false` 반환 → Controller `return false` → CI4 응답 직렬화
- **에러 흐름 (E1)**: API Key 인증 실패 → 403 `FORBIDDEN`

---

## 7. Verification Matrix / 검증 매트릭스 (FR↔UC↔Test↔SDD)

| FR ID | FR 명 | UC ID | 테스트 케이스 | SDD 참조 |
|-------|-------|-------|-------------|---------|
| FR-001 | FCM 토큰 등록 | UC-001 | TC-NTF-001~005 (파라미터 누락 → 500 확인) | notification-sdd.md §4 Logical |
| FR-002 | 한국 상담사 FCM 발송 | UC-002 | `testSendKoreaCalleeNotificationReturnsFalseWhenNoAlarmExists`, `testSendKoreaCalleeNotificationReturnsTrueWhenAlarmListExists` | notification-sdd.md §4 Logical |
| FR-002a | 일본어 메시지 발송 | UC-002 | TC-NTF-011 (SKIP - 외부 의존) | notification-sdd.md §4 Service |
| FR-002b | 알람 이력 기록 | UC-002 | TC-NTF-019 (`getReturnAlarm` 호출 순서 검증) | notification-sdd.md §4 Service |
| FR-002c | FCM 토큰 만료 처리 | UC-002 (E2) | 미구현 — 외부 FCM 의존. 레거시 라이브러리 Mock 기반 TC 추가 예정 | notification-sdd.md §4 Service |
| NFR-001 | FCM 발송 결과 알람 상태 갱신 | UC-002 | TC-NTF-019 | notification-sdd.md §4 Repository |
| NFR-002 | FCM 응답 시간 3초 | — | `test_dispatch_timeout` (레거시 라이브러리 타임아웃 설정 확인) | notification-sdd.md §4 Service |
| NFR-005 | FCM 서버 키 환경변수 | — | 코드 리뷰 (레거시 Fcm 라이브러리) | notification-sdd.md §4 Service |

---

## 8. Data Dictionary / 데이터 사전

| 데이터 요소 | 타입 | 크기/형식 | 범위/허용값 | 출처/목적지 |
|-----------|------|---------|-----------|-----------|
| `cr_code` | string | VARCHAR | 빈 값 거부 | 요청 바디 → `MemberRepository::UpdateFcmToken()` |
| `st_code` | string | VARCHAR | 빈 값 거부 | 요청 바디 → 내부 처리 |
| `token` | string | VARCHAR(512) | 빈 값 거부 | 요청 바디 → FCM 토큰 값 |
| `type` | string | VARCHAR | 빈 값 거부 | 요청 바디 → `UpdateFcmToken()` |
| `ce_code` | string | VARCHAR | 상담사 코드 | 요청 바디 → `sendKoreaCalleeNotification()` |
| `item_flag` | string | VARCHAR | `call` 또는 `chat` | 요청 바디 → `sendKoreaCalleeNotification()` |
| `item_code` | string | VARCHAR | MemberRepository 조회값 | `ItemCodeSelect()` 반환 |
| `alarm_id` | int unsigned | INT UNSIGNED AUTO_INCREMENT | 1 이상 자동증가 | `tb_alarm_history.alarm_id` |
| `FCM_SERVER_KEY` | env var | string | Firebase 프로젝트 서버 키 | `.env` → 레거시 Fcm 라이브러리 내부 참조 |

---

## 9. 타당성 검토 (Feasibility Review)

> 근거: Firebase FCM 공식 문서, OWASP API Security Top 10 2023, PHP 공식 문서

| 요구사항 | 채택 방식 | 근거 (공식 표준/문서) | 결론 |
|---------|----------|----------------------|------|
| FCM 발송 실패를 HTTP 에러로 반환하지 않음 | Service `bool` 반환 + Controller `return`. HTTP 상태는 CI4 직렬화 의존 | Firebase FCM 공식 문서 — FCM 발송 실패는 네트워크/토큰 문제로 API 요청 자체의 유효성과 무관. OWASP API5:2023 — 내부 오류를 클라이언트에 과도 노출 방지 | **타당** — 내부 서버 간 통신에서 FCM 발송 자체의 성공/실패는 부수적 결과. 단, CI4 직렬화 동작에 따른 응답 포맷 불일치 위험 있음 (NOTIF-DEF-010) |
| 일본어 메시지 고정 텍스트 | `FcmNotificationService::sendFcmToAlarmList()` 내 하드코딩 일본어 문자열 | 현재 코드: `ホンカフェ [...]`, `今、鑑定可能です。`. NFR-007 `lang()` 키 정책과 불일치하나 레거시 구현으로 존재 | **부분적 타당** — 향후 `lang()` 키 적용 권장. 현재는 레거시 구현 그대로 명세 |
| API Key 인증 (`X-Api-Key`) for korea-callee-fcm EP | `auth:apikey` 필터 적용. CSRF 면제 | OWASP API2:2023 — 서버-서버 통신에서 API Key는 표준 인증 방식. CSRF는 브라우저 기반 공격으로 서버-서버 통신에 적용 불필요 | **타당** — CSRF 면제는 프로젝트 CLAUDE.md 정책("API Key 인증 시 CSRF 검증 생략")과 일치 |
| `fcm/index` EP 필터 미설정 현황 | Routes.php에 필터 옵션 없음 | 현재 코드: `$routes->post('fcm/index', 'FcmController::index')` (필터 없음). md·yaml은 `🔒 jwt` 표기. 실제 코드와 불일치 | **비타당** — NOTIF-DEF-005 보안 리스크. 인증 필터 추가 여부 Checkpoint 필요 |

**타당성 검토 결론**: 4개 항목 중 3개 타당, 1개(fcm/index 필터 미설정) 비타당으로 확인. 비타당 항목은 Checkpoint 후 코드 수정 또는 현황 유지 결정 필요.

---

## 10. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| v1.0 → v2.0: IEEE 29148:2018 표준 재구성 | Introduction(5 sub), Overall Description(5 sub), FR별 선행/후행조건·입력검증·검증방법, NFR 정량 기준, External IF, Use Cases(2건), Verification Matrix, Data Dictionary 전 섹션 완비 | IEEE 29148:2018 표준 준수 — v1.0은 기능/비기능 요구사항 목록과 UC 정도만 포함. SDD/IDD와의 추적성 강화를 위해 Verification Matrix 신설 |
| Verification Matrix 신설 (§7) | FR 7건(FR-001, FR-002, FR-002a~c, NFR 2건) ↔ UC ↔ 테스트케이스 ↔ SDD 4-way 매핑 | v1.0에 없던 핵심 IEEE 섹션. 테스트 케이스 명명 표준화 및 SDD 참조로 설계-요구사항 연결 보장 |
| Data Dictionary 신설 (§8) | 9개 핵심 데이터 요소의 타입·크기·범위·출처 명세 | IEEE 29148:2018 Data Dictionary 요구. 실제 코드 파라미터(`cr_code`, `st_code`, `token`, `type`, `ce_code`, `item_flag`)와 정합 |
| v2.0 → v2.1: [A] 이슈 11건 반영 (2026-04-21) | API SSOT 기준으로 전면 정합성 수정 | notification-api-vs-ieee-20260421.md 대조 리포트 기반 재작성 |
| NOTIF-DEF-001: EP URL 전체 수정 | §1.2, §2.1, §5.1, §5.4, §6 UC-001/UC-002, §3 FR 관련 API 전체에서 `/api/notifications/*` → `/api/fcm/*` 수정 | Routes.php 실제 URL = `/api/fcm/index`, `/api/fcm/korea-callee-fcm`. SRS가 잘못된 URL을 SSOT처럼 참조되는 것을 방지 |
| NOTIF-DEF-002: FR-001 입력 파라미터 수정 | `fcmToken/deviceId` 제거. `cr_code`, `st_code`, `token`, `type` 4개 파라미터로 교체 | `FcmController::index()` 실제 코드: `$post['cr_code']`, `$post['st_code']`, `$post['token']`, `$post['type']` 참조. 설계 문서가 존재하지 않는 파라미터를 명세하는 오류 수정 |
| NOTIF-DEF-004: FR-001 후행 조건 수정 | `{ "data": { "registered": true } }` → `{ "data": {} }` | `FcmController::index()`가 `respondSuccess()`를 인자 없이 호출. `respondSuccess()` = `{"data":{}}`. `registered` 키 없음 |
| NOTIF-DEF-005: NFR-003 필터 미설정 현황 기록 | `fcm/index` EP 인증 필터 미설정 상태 명시 | Routes.php 실제 코드: `$routes->post('fcm/index', 'FcmController::index')` (필터 없음). 보안 리스크 명시로 후속 Checkpoint 근거 제공 |
| NOTIF-DEF-008: FR-002 입력 파라미터 수정 | `calleeId/callerId/callerName` 제거. `ce_code/item_flag`로 교체 | `FcmController::koreaCalleeFcm()` 실제 코드: `$post['ce_code']`, `$post['item_flag']`. Service 시그니처: `(string $calleeCode, string $itemFlag): bool` |
| NOTIF-DEF-009: FR-001 입력 검증 로직 수정 | `min_length[10]` 검증 및 400 응답 제거. 실제 `isset()` + 빈값 체크 + 500 반환으로 교체 | `FcmController::index()` 실제 코드: `if (!isset($post['cr_code']) \|\| $post['cr_code'] == '') return $this->respondError('INTERNAL', ..., 500)` |
| NOTIF-DEF-010: FR-002 후행 조건 수정 | `{ "data": { "sent": bool, "alarmHistoryId": int } }` 제거. Service `bool` 반환 → Controller 직접 `return` 구조 명세 | `FcmController::koreaCalleeFcm()` 실제 코드: `return $this->fcmNotificationService->sendKoreaCalleeNotification(...)` (래핑 없음) |
| NOTIF-DEF-011: §2.1 시스템 다이어그램 수정 | 실제 구현 구조 반영 (레거시 Fcm 라이브러리, MemberRepository, MypageRepository 포함) | Service 실제 코드가 SRS의 설계 다이어그램과 전혀 다른 구조. 실제 코드 기준으로 재작성 |
| NOTIF-DEF-013: Verification Matrix FR-002c 수정 | 존재하지 않는 TC명 `test_expired_token_deleted_on_not_registered` 삭제. "미구현 — 외부 FCM 의존" 명시 | STD에 해당 TC 없음. 존재하지 않는 TC를 참조하는 것은 문서 오류 |

---

## 11. 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-15 | 1.0.0 | 초기 작성 — Notification Module SRS | jypark |
| 2026-04-15 | 2.0.0 | IEEE 29148:2018 전면 재구성. Introduction(5 sub), Overall Description(5 sub), FR 선행/후행/검증 강화(FR-001, FR-002, FR-002a~c), NFR 정량 기준(10건), External IF, Use Cases(2건), Verification Matrix, Data Dictionary(14개 요소), 타당성 검토(5건), 변경 영향 기록 신설 | jypark |
| 2026-04-21 | 2.1.0 | API SSOT 대조 리포트(notification-api-vs-ieee-20260421.md) [A] 이슈 11건 반영. EP URL 전체 수정(DEF-001), FR-001 파라미터/응답/검증 수정(DEF-002/004/009), FR-002 파라미터 수정(DEF-008/010), 필터 미설정 현황 기록(DEF-005), 시스템 다이어그램 실제 구조 반영(DEF-011), Verification Matrix FR-002c TC 수정(DEF-013) | jypark |
