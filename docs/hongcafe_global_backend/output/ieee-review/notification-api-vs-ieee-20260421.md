---
문서명: notification 모듈 API ↔ IEEE 대조 — 2026-04-21
상태: 초안
생성일: 2026-04-21
SSOT 방향: API → IEEE
작성자: jypark (agent: general-purpose, sonnet)
---

# notification 모듈 API ↔ IEEE 대조 리포트

## 요약

- EP 수 (md / yaml / Routes / SRS FR): 2 / 2 / 2 / 2
- 9개 항목 판정: ✅ 3 / ⚠ 5 / ❌ 1
- 발견 이슈: 총 13건 (Critical 1 / High 4 / Medium 5 / Low 3)
- 분류: [A] IEEE 수정 11건 / [B] API 내부 2건

---

## 항목별 판정표

| # | 항목 | 판정 | 주요 근거 |
|---|------|------|----------|
| 1 | EP 목록 (md↔yaml↔Routes↔SRS FR) | ⚠ | Routes URL은 `/api/fcm/*`이나 SRS/SDD/IDD가 `/api/notifications/*`로 잘못 기술 |
| 2 | EP-SRS 매핑 | ⚠ | SRS FR-001은 `POST /api/notifications/fcm-token` 매핑 → 실제 코드는 `POST /api/fcm/index`. SRS/SDD/IDD 전반 EP URL 불일치 |
| 3 | 인증/CSRF 표기 | ⚠ | md·yaml은 `POST /api/fcm/index`에 JWT 인증 표기하나 Routes에 `auth` 필터 미설정. 코드 내 `checkNeedLogin()` 미호출. 인증 실제 적용 여부 불확실 |
| 4 | X-Forwarded-Proto 전역 헤더 | ✅ | md 헤더 테이블 포함. yaml `components.parameters.XForwardedProto` 정의 후 모든 EP `$ref` 참조. 정책 준수 |
| 5 | 응답 스키마 (data/meta/error) | ❌ | 실제 코드 `index()`는 `respondSuccess()` → `{"data":{}}` 반환. md/yaml 일치. 그러나 `koreaCalleeFcm()`은 Service 반환값을 그대로 통과(`return $this->fcmNotificationService->sendKoreaCalleeNotification(...)`)하여 `{"data":{"success":bool,"messageId":"..."}}` 보장 불가. SRS/SDD/IDD가 기술하는 `sent/alarmHistoryId/reason` 구조와 실제 코드 불일치 |
| 6 | 환경별 URL (prd/stg/dev) | ✅ | md·yaml 모두 prd/stg/dev 3개 URL 명시. 정책 준수 |
| 7 | 비즈니스 규칙 (멱등/RBAC/Rate-limit) | ⚠ | SRS/SDD가 기술하는 `registerFcmToken(int $accountId, string $fcmToken, string $deviceId)` 시그니처와 실제 Service 메서드 `sendKoreaCalleeNotification(string $calleeCode, string $itemFlag)` 불일치. 실제 구현은 설계와 전혀 다른 비즈니스 로직 수행 |
| 8 | IDD 매핑 (camelCase↔snake_case) | ⚠ | IDD §7.1 DB→API 매핑 정의 존재. 그러나 실제 코드 `FcmController::index()`가 `cr_code`, `st_code` (snake_case)로 입력 받으나 md·yaml은 `crCode`, `stCode` (camelCase)로 문서화. API 내부 불일치 [B] |
| 9 | STD TC 커버리지 | ⚠ | STD 20 TC 중 FR-002c(FCM 토큰 만료 처리) 전용 TC 미구현(DEF-NTF-002). FR-001 커버리지가 실제 `index()` 파라미터(cr_code/st_code/token/type)로 작성됐으나 SRS는 `fcmToken/deviceId` 로 기술하는 설계-구현 괴리를 반영. TC-NTF-015가 검증하는 파라미터(`calleeCode`, `itemFlag`)는 실제 Service 구현과 일치하나 SDD 설계(`calleeId`, `callerId`, `callerName`)와 불일치 |

---

## 이슈 상세

### NOTIF-DEF-001 (Critical / [A] IEEE 수정)

- 위치: SRS §1.2, §3 FR-001/FR-002; SDD §3.2, §5.3, §4.1~4.3; IDD §3.1.2, §3.2.2, §7.2; 대조: `docs/specs/notification-srs.md:33-35`, `docs/specs/notification-sdd.md:154-158`, `docs/specs/notification-idd.md:488-530`
- 현상: SRS, SDD, IDD 전반에 걸쳐 EP URL이 `/api/notifications/fcm-token`, `/api/notifications/korea-callee`로 기술되어 있으나 **실제 Routes.php의 URL은 `/api/fcm/index`, `/api/fcm/korea-callee-fcm`**이다. 경로 불일치가 SRS Scope 테이블, FR 관련 API 컬럼, SDD Endpoint Distribution 표, IDD JSON 예시, STD FcmApiTest에 이르기까지 전 문서에 연쇄 전파되어 있다.
- [A] IEEE 업데이트 대상:
  - SRS §1.2 포함 EP 행: `POST /api/fcm/index`, `POST /api/fcm/korea-callee-fcm`으로 수정
  - SRS §3 FR-001 관련 API: `POST /api/fcm/index`
  - SRS §3 FR-002 관련 API: `POST /api/fcm/korea-callee-fcm`
  - SRS §6 UC-001 정상 흐름 1번: URL 수정
  - SRS §6 UC-002 정상 흐름 1번: URL 수정
  - SDD §3.2 Endpoint Distribution 표: URL 열 수정
  - SDD §5.3 Filter Chain 코드 블록: URL 수정
  - SDD §9.1, §9.2 시퀀스 다이어그램: URL 수정
  - IDD §7.2 요청/응답 예시 헤더 URL 수정
  - STD §3.1 FcmApiTest TC URL 수정 (TC-NTF-001~005)

---

### NOTIF-DEF-002 (High / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:148-171` (FR-001, FR-002), `docs/specs/notification-sdd.md:165-192` (§4.1, §4.2), `docs/specs/notification-idd.md:83-128` (IF-INT-001)
- 현상: SRS FR-001은 입력 파라미터를 `fcmToken` (필수, 10~512자), `deviceId` (필수, 1~200자)로 정의하고, SDD §4.1은 Controller 입력 검증 규칙을 `'fcmToken' => 'required|...'`, `'deviceId' => 'required|...'`로 명세한다. 그러나 **실제 `FcmController::index()`는 `cr_code`, `st_code`, `token`, `type` 4개 snake_case 파라미터를 입력 받으며**, `deviceId`는 존재하지 않고 `st_code`가 추가로 필요하다. SRS/SDD가 기술하는 설계와 구현이 근본적으로 다르다.
- [A] IEEE 업데이트 대상:
  - SRS §3 FR-001 입력 검증: `crCode` (필수), `stCode` (필수), `token` (필수), `type` (필수)로 수정. `deviceId`, `fcmToken` 키명 제거
  - SRS §3 FR-001 후행 조건: 실제 `respondSuccess()` → `{"data":{}}` 기반으로 수정. `"registered": true` 제거
  - SRS §6 UC-001 정상 흐름: 실제 입력 JSON 반영
  - SDD §4.1 입력 검증 규칙 코드 블록: 실제 파라미터로 전체 교체
  - IDD §3.1.2 `registerFcmToken()` PHP 시그니처: 실제 코드 기반으로 재작성 필요
  - IDD §7.2 `POST /api/fcm/index` 요청 JSON 예시: `cr_code`, `st_code`, `token`, `type`으로 수정

---

### NOTIF-DEF-003 (High / [A] IEEE 수정)

- 위치: `docs/specs/notification-sdd.md:186-221` (§4.2 sendKoreaCalleeNotification), `docs/specs/notification-idd.md:103-128` (IF-INT-001), `app/Modules/Notification/Services/FcmNotificationService.php:40`
- 현상: SDD §4.2가 정의하는 `sendKoreaCalleeNotification(int $calleeId, int $callerId, string $callerName): array` 시그니처와 실제 구현 `sendKoreaCalleeNotification(string $calleeCode, string $itemFlag): bool`이 **완전히 다르다**. 파라미터 타입(int vs string), 개수(3개 vs 2개), 반환 타입(array vs bool), 파라미터명(calleeId/callerId/callerName vs calleeCode/itemFlag) 모두 불일치. 실제 Service는 `memberRepository->ItemCodeSelect()`, `alarmRepository->getReturnAlarm()`, 레거시 `Fcm::sendFcm()`을 사용하여 SDD가 기술하는 `AlarmRepository::findFcmTokenByAccountId()`, `insertAlarmHistory()` 기반 설계와 전혀 다른 로직을 수행한다.
- [A] IEEE 업데이트 대상:
  - SDD §4.2 Service Layer 시그니처 표 및 PHP 코드 블록: 실제 구현 반영
  - SDD §4.3 Repository 메서드 목록: 실제 사용 메서드(`getReturnAlarm`, `updateReturnAlarmDone`)로 수정
  - SDD §9.2, §9.3 시퀀스 다이어그램: 실제 호출 흐름 반영
  - IDD §3.1.2 `sendKoreaCalleeNotification()` PHP 시그니처: `(string $calleeCode, string $itemFlag): bool`로 교체
  - IDD §3.2.2 `AlarmRepositoryInterface`: 실제 사용 메서드 반영 (현재 인터페이스 정의가 실제 구현체와 불일치)
  - IDD §7.2 `POST /api/fcm/korea-callee-fcm` 요청 JSON: `ceCode`, `itemFlag`로 수정

---

### NOTIF-DEF-004 (High / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:155` (FR-001 후행 조건), `docs/specs/notification-sdd.md:492-496` (§8.2), `docs/specs/notification-idd.md:499-505`
- 현상: SRS FR-001 후행 조건은 `200 OK + { "data": { "registered": true } }`를 정의한다. SDD §8.2, IDD §7.2도 동일하게 `"registered": true` 응답을 명세한다. 그러나 **실제 `FcmController::index()`는 `respondSuccess()`를 호출하며, `respondSuccess()`는 `{"data":{}}` (빈 data 객체)를 반환**한다. `registered` 키가 응답에 없다.
- [A] IEEE 업데이트 대상:
  - SRS §3 FR-001 후행 조건: `{ "data": {} }` 로 수정
  - SDD §8.2 API Response Contracts 표 첫 행: `{ "data": {} }` 로 수정
  - IDD §7.2 `POST /api/fcm/index` 응답 200 OK JSON: `{ "data": {} }` 로 수정

---

### NOTIF-DEF-005 (High / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:217` (NFR-003), `docs/specs/notification-sdd.md:302-312` (§5.3), `app/Modules/Notification/Config/Routes.php:11`
- 현상: SRS NFR-003은 `fcm-token` EP에 `ratelimit,csrftoken,auth` 필터 체인을 요구한다. SDD §5.3은 `$routes->post('notifications/fcm-token', ..., ['filter' => 'ratelimit,csrftoken,auth'])` 코드를 명세한다. 그러나 **실제 Routes.php의 `post('fcm/index', ...)`에는 필터 옵션이 전혀 설정되지 않았다**. API Key 전용 EP인 `fcm/korea-callee-fcm`에는 `['filter' => 'auth:apikey']`가 설정되어 있으나, JWT EP인 `fcm/index`는 필터 미설정 상태다. md·yaml이 `🔒 jwt` 인증으로 표기하는 것과 실제 코드가 불일치한다.
- [A] IEEE 업데이트 대상:
  - SRS NFR-003: 현재 상태 반영. `fcm/index`의 실제 필터 체인 미설정 현황 기록 또는 필터 추가 후 문서 업데이트
  - SDD §5.3 Filter Chain: 실제 Routes 코드 반영
  - (별도 코드 수정 Checkpoint 필요 — 인증 필터 추가는 비가역적 보안 변경)

---

### NOTIF-DEF-006 (Medium / [B] API 내부)

- 위치: `api-docs/notification/fcm-api.md:135-136`, `api-docs/notification/fcm-api.yaml:67-72`, `app/Modules/Notification/Controllers/FcmController.php:26-37`
- 현상: md·yaml이 `POST /api/fcm/index` 요청 파라미터를 `crCode`, `stCode` (camelCase)로 문서화하고 있으나 **실제 Controller 코드는 `cr_code`, `st_code` (snake_case)를 읽는다** (`$post['cr_code']`, `$post['st_code']`). CLAUDE.md 정책은 "DB snake_case → API 응답 camelCase 변환 필수"를 명시하지만 이는 응답에 대한 규칙이다. 요청 바디의 camelCase 변환 처리가 있는지 확인이 필요하다. `getJsonInput()` 내부에 자동 변환이 없다면 클라이언트가 snake_case로 전송해야 함에도 문서가 camelCase로 안내하는 오류가 된다.
- [B] API 내부 수정 대상:
  - `api-docs/notification/fcm-api.md` 요청 파라미터 테이블: `cr_code`, `st_code`, `token`, `type`으로 수정 (또는 `getJsonInput()`에 camelCase→snake_case 자동 변환 추가 후 camelCase 유지)
  - `api-docs/notification/fcm-api.yaml` `FcmTokenRequest` schema: `cr_code`, `st_code`로 수정 (또는 변환 처리 추가)

---

### NOTIF-DEF-007 (Medium / [B] API 내부)

- 위치: `api-docs/notification/fcm-api.md:180-185`, `api-docs/notification/fcm-api.yaml:82-89`, `app/Modules/Notification/Controllers/FcmController.php:49-55`
- 현상: md·yaml이 `POST /api/fcm/korea-callee-fcm` 요청 파라미터를 `ceCode`, `itemFlag`로 문서화한다. 실제 Controller 코드는 `$post['ce_code']`, `$post['item_flag']` (snake_case)를 Service에 전달한다. NOTIF-DEF-006과 동일한 camelCase/snake_case 요청 파라미터 불일치 문제.
- [B] API 내부 수정 대상:
  - `api-docs/notification/fcm-api.md` 요청 파라미터: `ce_code`, `item_flag`로 수정
  - `api-docs/notification/fcm-api.yaml` `KoreaCalleeFcmRequest` schema: `ce_code`, `item_flag`로 수정

---

### NOTIF-DEF-008 (Medium / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:165-171` (FR-002), `docs/specs/notification-sdd.md:582-583` (§10.2), `docs/specs/notification-idd.md:450-455` (§6.2)
- 현상: SRS FR-002 입력 검증은 `calleeId` (필수, 정수), `callerId` (필수, 정수), `callerName` (필수, 문자열, 최대 100자)을 정의한다. SDD §10.2 Error Handling, IDD §6.2 Error Code Table은 400 `INVALID_INPUT`을 `calleeId/callerId 누락`, `callerName 100자 초과`로 기술한다. 그러나 실제 `FcmController::koreaCalleeFcm()`은 **입력 검증을 전혀 수행하지 않고** Service로 그대로 전달하며, 실제 입력은 `ce_code` (string), `item_flag` (string) 2개다. 400 에러 응답 가능성 자체가 없다.
- [A] IEEE 업데이트 대상:
  - SRS §3 FR-002 입력 검증: `ceCode`(필수, 문자열), `itemFlag`(필수, 문자열)로 수정. `callerId`, `callerName` 제거
  - SDD §10.2 Error Handling: `korea-callee` 400 조건을 실제 코드 기준으로 수정
  - IDD §6.2 Error Code Table: `korea-callee` 400 행 수정

---

### NOTIF-DEF-009 (Medium / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:156-159` (FR-001 입력 검증), `docs/specs/notification-sdd.md:168-175` (§4.1)
- 현상: SRS FR-001 입력 검증은 `fcmToken` 최소 10자 검증 후 10자 미만 시 400 `INVALID_INPUT` 반환을 명세한다. SDD §4.1도 `'fcmToken' => 'required|string|min_length[10]|max_length[512]'` 규칙을 명시한다. 그러나 **실제 `FcmController::index()`는 `isset()` + 빈값 체크만 수행하고 최소 길이 검증을 하지 않으며**, 검증 실패 시 HTTP 500을 반환한다 (400이 아님). STD TC-NTF-001~005의 기대 결과도 "HTTP 200 + 비어있지 않은 응답 본문"으로 실제 동작(500 반환)과 불일치.
- [A] IEEE 업데이트 대상:
  - SRS §3 FR-001 입력 검증: 실제 검증 로직 반영 (isset + 빈값 체크, 500 반환)
  - SRS §3 FR-001 검증 방법: 실제 에러 코드/HTTP 상태 반영
  - SDD §4.1 입력 검증 코드 블록: 실제 코드 반영
  - STD §3.1 TC-NTF-001~005 기대 결과: 실제 동작(HTTP 500 + `{"error":{"code":"INTERNAL",...}}`) 반영

---

### NOTIF-DEF-010 (Medium / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:167-171` (FR-002 후행 조건), `docs/specs/notification-sdd.md:492-497` (§8.2), `docs/specs/notification-idd.md:547-577` (§7.2)
- 현상: SRS FR-002 후행 조건, SDD §8.2, IDD §7.2는 `POST /api/notifications/korea-callee`의 성공 응답을 `{ "data": { "sent": true, "alarmHistoryId": 789 } }` 로 정의한다. 그러나 **실제 `FcmController::koreaCalleeFcm()`은 `return $this->fcmNotificationService->sendKoreaCalleeNotification(...)` 결과를 그대로 반환**하며, 실제 Service는 `bool`을 반환한다. `data` 래핑 없이 날 `bool` 또는 JSON 직렬화 오류 가능성이 있다. md·yaml이 기술하는 `{"data":{"success":true,"messageId":"..."}}` 구조도 실제 코드와 불일치.
- [A] IEEE 업데이트 대상:
  - SRS §3 FR-002 후행 조건: 실제 응답 구조 반영 (Service `bool` 반환 → Controller 래핑 여부 확인 후 업데이트)
  - SDD §8.2 `POST /api/notifications/korea-callee` 행: 실제 응답 반영
  - IDD §7.2 `POST /api/fcm/korea-callee-fcm` 응답 JSON 예시 전체 수정

---

### NOTIF-DEF-011 (Low / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:47` (용어 정의), `docs/specs/notification-sdd.md:143-149` (§3.1 디렉토리)
- 현상: SRS 용어 정의 테이블의 `FCM Token` 항목이 `VARCHAR(512)`로 정의되어 있다. SDD §6.2 DDL은 `tb_fcm_token` 테이블을 명세하나 실제 DB에 이 테이블이 존재하는지 스키마 DB에서 확인이 필요하다 (hongcafe-schema.db 조회 미수행). SDD §3.1 디렉토리 구조에 `Entities/(reserved for future Entity migration)`으로 기술된 예약 디렉토리가 실제 파일 목록(`app/Modules/Notification/Entities/Alarm.php` 존재)과 불일치.
- [A] IEEE 업데이트 대상:
  - SDD §3.1 디렉토리 구조: `Entities/Alarm.php` 실제 존재 반영
  - (DB 스키마 확인 후 DDL 정합성 검토 필요 — 별도 Checkpoint 권장)

---

### NOTIF-DEF-012 (Low / [A] IEEE 수정)

- 위치: `docs/specs/notification-srs.md:37` (Refresh Token Path), `api-docs/notification/fcm-api.md:38`
- 현상: `fcm-api.md` JWT 인증 표 내 Refresh Token `Path` 항목이 `/api/auth/refresh`로 기재되어 있다. CLAUDE.md 최신 정책(커밋 `a7be0b5`: "Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대")에 따라 Refresh Token `Path`는 `/`여야 한다.
- [A] IEEE 업데이트 대상:
  - `api-docs/notification/fcm-api.md` JWT 인증 표 Refresh Token Path: `/api/auth/refresh` → `/` 로 수정

---

### NOTIF-DEF-013 (Low / [A] IEEE 수정)

- 위치: `docs/specs/notification-std.md:127` (§5 Traceability Matrix), `docs/specs/notification-srs.md:169-171` (FR-002 검증 방법)
- 현상: STD Traceability Matrix에서 FR-002c (FCM 토큰 만료 처리)의 TC가 "(미구현 - 외부 FCM 의존)"으로 기재되어 있다. DEF-NTF-002로 이미 Defects에 등록되어 있으나, SRS §7 Verification Matrix는 `test_expired_token_deleted_on_not_registered` TC를 연결한다. SRS가 존재한다고 주장하는 TC가 STD에 없다.
- [A] IEEE 업데이트 대상:
  - SRS §7 Verification Matrix FR-002c 행: STD 실제 상태 "미구현(외부 FCM 의존)" 반영. 존재하지 않는 TC명 삭제
  - STD §5 Traceability Matrix FR-002c 행: 명시적으로 "TC 미구현 — FCM API Mock 기반 TC 추가 예정" 기록

---

## 엔드포인트 매트릭스

| EP | Method | md | yaml | Routes | SRS FR | STD TC | 판정 |
|----|--------|----|------|--------|--------|--------|------|
| `/api/fcm/index` | POST | ✅ (URL 일치) | ✅ (URL 일치) | ✅ `fcm/index` | ⚠ SRS는 `/api/notifications/fcm-token`으로 기재 | TC-NTF-001~007 (URL 불일치 내재) | ⚠ |
| `/api/fcm/korea-callee-fcm` | POST | ✅ (URL 일치) | ✅ (URL 일치) | ✅ `fcm/korea-callee-fcm` + `filter:auth:apikey` | ⚠ SRS는 `/api/notifications/korea-callee`로 기재 | TC-NTF-008~019 | ⚠ |

**EP 수 정합**: md=2, yaml=2, Routes=2, SRS FR=2. 수량은 일치. URL 표현만 SRS/SDD/IDD에서 불일치.

---

## Open Questions

1. **NOTIF-DEF-005 보안 리스크 (Checkpoint 권장)**: `POST /api/fcm/index`에 인증 필터가 설정되지 않아 비인증 요청이 FCM 토큰을 덮어쓸 수 있다. md·yaml이 `🔒 jwt`로 표기하는 인증이 실제 Routes에 미적용 상태다. 필터 추가 여부를 사용자 승인 후 결정해야 한다.

2. **koreaCalleeFcm() 응답 래핑 확인**: `FcmController::koreaCalleeFcm()`이 Service의 `bool` 반환값을 그대로 `return`하면 CI4 응답 직렬화 동작에 따라 예상치 못한 출력이 발생할 수 있다. `BaseApiController::respondSuccess($result)` 래핑 여부 또는 `bool → {"data":...}` 변환 여부를 코드에서 확인 필요.

3. **AlarmRepositoryInterface 실제 구현체 확인**: SDD/IDD가 정의하는 `findFcmTokenByAccountId`, `upsertFcmToken`, `insertAlarmHistory`, `deleteFcmToken` 메서드가 실제 `AlarmRepository.php`에 구현되어 있는지 확인 필요. 현재 분석 범위에서는 Service 구현이 `getReturnAlarm`, `updateReturnAlarmDone`을 사용하는 것이 확인됨.

4. **tb_fcm_token / tb_alarm_history 실제 존재 여부**: SDD §6.2 DDL이 기술하는 두 테이블이 Aurora 실제 스키마(`hongcafe-schema.db`)에 존재하는지 확인 필요. 설계 문서와 실제 DB 스키마 정합성 검토.

5. **FcmNotificationService 설계-구현 괴리 원인**: 현재 Service 구현이 SRS/SDD 설계와 전면 불일치한다. 이는 (a) 신규 설계(SRS/SDD)가 아직 미구현 상태이거나, (b) 레거시 코드를 설계 없이 래핑한 것이거나, (c) 설계 문서가 현재 코드를 반영하지 않고 이상적 미래 상태를 기술한 것일 수 있다. 의도한 상태를 확인하여 IEEE 문서 업데이트 방향을 결정해야 한다.
