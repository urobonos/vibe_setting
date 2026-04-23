---
문서명: Notification — Interface Design Document
문서 ID: notification-idd
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Notification Module (HongCafe Global Backend)
관련 문서: notification-sdd.md, notification-srs.md
적용 표준: MIL-STD-498 (Interface Design Description)
---

# Notification — Interface Design Document (IDD)

> MIL-STD-498 | version: 2.1 | lastUpdated: 2026-04-21 | module: Notification

---

## 1. Scope / 적용 범위

### 1.1 Identification / 식별

본 Interface Design Document(IDD)는 HongCafe Global Backend의 Notification Bounded Context에 대한 내부 및 외부 인터페이스를 MIL-STD-498 표준에 따라 정의한다. 문서 ID: `notification-idd`, 기반 SDD: `notification-sdd.md` v2.1.

### 1.2 System Overview / 시스템 개요

Notification 모듈은 FCM 기반 푸시 알림 발송 Bounded Context이다. 내부 인터페이스는 2개(Service 1, Repository 1), 외부 인터페이스는 1개(Firebase Cloud Messaging API — 레거시 Fcm 라이브러리 경유)이다. 모듈의 역방향 의존성(타 모듈이 Notification 내부 인터페이스를 DI로 소비)은 없다 — 모든 진입점은 HTTP 호출이다.

| Interface Type | Count | Description |
|---------------|-------|-------------|
| 내부 인터페이스 (Internal IF) | 2 | `FcmNotificationServiceInterface`, `AlarmRepositoryInterface` |
| 외부 인터페이스 (External IF) | 1 | Firebase Cloud Messaging API (레거시 Fcm 라이브러리 경유) |

### 1.3 Document Overview / 문서 구성

| Section | Content |
|---------|---------|
| §2 | References — 참조 문서 |
| §3 | Internal Interfaces — 내부 인터페이스 (5-subsection 형식) |
| §4 | External Interfaces — 외부 인터페이스 (5-subsection 형식) |
| §5 | Events — 이벤트 계약 |
| §6 | Error Contract — 에러 처리 계약 |
| §7 | Data Formats — 데이터 포맷 및 JSON 예시 |
| §8 | 타당성 검토 |
| §9 | 변경 영향 기록 |
| §10 | Requirements Traceability Matrix |
| §11 | 변경 로그 |

---

## 2. References / 참조 문서

| Document | Location |
|----------|----------|
| MIL-STD-498 — Software Development and Documentation | US DoD Standard |
| notification-srs.md v2.1 | `docs/specs/notification-srs.md` |
| notification-sdd.md v2.1 | `docs/specs/notification-sdd.md` |
| Firebase FCM 공식 문서 | https://firebase.google.com/docs/cloud-messaging |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| RFC 7807 — Problem Details for HTTP APIs | https://tools.ietf.org/html/rfc7807 |
| HongCafe Global Backend CLAUDE.md | Project root `CLAUDE.md` |

---

## 3. Internal Interfaces / 내부 인터페이스

### IF-INT-001: FcmNotificationServiceInterface

#### 3.1.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | `FcmNotificationServiceInterface` |
| 파일 경로 | `app/Modules/Notification/Interfaces/FcmNotificationServiceInterface.php` |
| 구현체 | `FcmNotificationService` |
| 제공 모듈 | Notification |
| 소비 모듈 | Notification (`FcmController`) |
| DI 등록 | `app/Modules/Notification/Config/Services.php` |

#### 3.1.2 Data Elements / 데이터 요소

```php
<?php
declare(strict_types=1);

namespace App\Modules\Notification\Interfaces;

interface FcmNotificationServiceInterface
{
    /**
     * 한국 상담사에게 FCM 푸시 알림 발송.
     *
     * 내부적으로 ItemCode 조회 → 알람 목록 조회 → FCM 발송 → 알람 완료 처리 → 이력 저장 순으로 실행.
     * 알람 목록이 없으면 false를 반환하고 예외를 던지지 않는다.
     * FCM 발송은 레거시 Fcm 라이브러리(app/Libraries/Fcm)에 위임한다.
     *
     * @param  string $calleeCode 상담사 코드 (ce_code)
     * @param  string $itemFlag   아이템 유형 플래그 (call/chat)
     * @return bool   true = 발송 성공, false = 알람 목록 없음
     */
    public function sendKoreaCalleeNotification(string $calleeCode, string $itemFlag): bool;
}
```

#### 3.1.3 Communication Protocol / 통신 프로토콜

PHP DI (CodeIgniter `service()` 함수). 동기 메서드 호출. 내부 FCM 발송은 레거시 `Fcm::sendFcm()` 라이브러리를 통해 cURL HTTPS 실행.

#### 3.1.4 Error Handling / 에러 처리

| Error Condition | Handling |
|----------------|---------|
| 알람 목록 없음 (`getReturnAlarm()` = false) | 예외 없음. `false` 반환 |
| `ItemCodeSelect()` 실패 | PHP 오류 또는 예외 발생 가능 (현재 별도 처리 없음) |
| FCM 발송 실패 | 레거시 `Fcm` 라이브러리 내부 처리 |

#### 3.1.5 Data Flow / 데이터 흐름

```
[FCM 발송 흐름]
FcmController::koreaCalleeFcm() → FcmNotificationServiceInterface::sendKoreaCalleeNotification(
    string $calleeCode,  -- ce_code (요청 바디 ce_code)
    string $itemFlag     -- item_flag (요청 바디 item_flag)
)
  → MemberRepository::ItemCodeSelect($calleeCode, $itemFlag) → item_code
  → AlarmRepository::getReturnAlarm($calleeCode, $itemCodeValue, ST_CODE, $itemFlag) → array|false
  → [알람 있음] sendFcmToAlarmList(...) → Fcm::sendFcm(list, title, msg, passUrl)
  → AlarmRepository::updateReturnAlarmDone(...)
  → MypageRepository::SetAlarm({ type, ac_id, cr_code, subject, content, link })
  → true 반환

[알람 없음 흐름]
  → AlarmRepository::getReturnAlarm(...) → false
  → false 반환
```

---

### IF-INT-002: AlarmRepositoryInterface

#### 3.2.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | `AlarmRepositoryInterface` |
| 파일 경로 | `app/Modules/Notification/Interfaces/AlarmRepositoryInterface.php` |
| 구현체 | `AlarmRepository` |
| 제공 모듈 | Notification |
| 소비 모듈 | Notification (`FcmNotificationService`) |
| DI 등록 | `app/Modules/Notification/Config/Services.php` |

#### 3.2.2 Data Elements / 데이터 요소

```php
<?php
declare(strict_types=1);

namespace App\Modules\Notification\Interfaces;

interface AlarmRepositoryInterface
{
    /**
     * 상담사 코드 기반 리턴 알람 목록 조회.
     *
     * FCM 발송 대상 알람 목록을 반환한다.
     * 알람 없으면 false 반환.
     *
     * @param  string $calleeCode    상담사 코드 (ce_code)
     * @param  string $itemCodeValue 아이템 코드 (ItemCodeSelect로 획득)
     * @param  string $stCode        스토어 코드 (ST_CODE 상수)
     * @param  string $itemFlag      아이템 유형 플래그 (call/chat)
     * @return array|false 알람 목록. 각 행: { fcm_type, fcm_app_token, it_nick, it_category_name, ... }
     *                     false = 알람 없음
     */
    public function getReturnAlarm(
        string $calleeCode,
        string $itemCodeValue,
        string $stCode,
        string $itemFlag
    ): array|false;

    /**
     * 알람 발송 완료 상태 갱신.
     *
     * FCM 발송 완료 후 알람 상태를 'complete'로 업데이트.
     *
     * @param  string $calleeCode    상담사 코드
     * @param  string $itemCodeValue 아이템 코드
     * @param  string $stCode        스토어 코드
     * @param  string $raStatus      갱신할 상태값 ('complete')
     * @param  string $itemFlag      아이템 유형 플래그
     * @return bool   true = 갱신 성공
     */
    public function updateReturnAlarmDone(
        string $calleeCode,
        string $itemCodeValue,
        string $stCode,
        string $raStatus,
        string $itemFlag
    ): bool;
}
```

> **이전 버전(v2.0)에서 변경된 사항**: `findFcmTokenByAccountId`, `upsertFcmToken`, `insertAlarmHistory`, `deleteFcmToken` 4개 메서드는 실제 `FcmNotificationService` 코드에서 사용하지 않으므로 인터페이스에서 제거. 실제 사용 메서드인 `getReturnAlarm`, `updateReturnAlarmDone`으로 교체 (NOTIF-DEF-003).

#### 3.2.3 Communication Protocol / 통신 프로토콜

PHP DI. CI4 Query Builder (`$this->db->table(...)`). DB charset: `utf8mb4`. UTC 타임존 기반 `DateTimeImmutable` 사용.

#### 3.2.4 Error Handling / 에러 처리

| Error Condition | Handling |
|----------------|---------|
| `getReturnAlarm()` 결과 없음 | `false` 반환. Service에서 분기 처리 |
| `updateReturnAlarmDone()` DB 오류 | `false` 반환 |

#### 3.2.5 Data Flow / 데이터 흐름

```
[알람 목록 조회]
FcmNotificationService → AlarmRepository::getReturnAlarm($calleeCode, $itemCodeValue, $stCode, $itemFlag)
  → SELECT 쿼리 (레거시 Repository 구현 참조)
  → array|false

[알람 완료 갱신]
FcmNotificationService → AlarmRepository::updateReturnAlarmDone($calleeCode, $itemCodeValue, $stCode, 'complete', $itemFlag)
  → UPDATE 쿼리
  → bool
```

---

## 4. External Interfaces / 외부 인터페이스

### IF-EXT-001: Firebase Cloud Messaging API (레거시 Fcm 라이브러리 경유)

#### 4.1.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | Firebase Cloud Messaging (레거시 Fcm 라이브러리) |
| 연동 모듈 | Notification (`FcmNotificationService::sendFcmToAlarmList()` → `Fcm::sendFcm()`) |
| 프로토콜 | HTTPS REST (cURL) — 레거시 `app/Libraries/Fcm` 내부 구현 |
| 기본 URL | `https://fcm.googleapis.com/fcm/send` (레거시 라이브러리 내부) |
| 인증 | 레거시 `Fcm` 라이브러리 내부에서 FCM 서버 키 관리 |
| 타임아웃 | 레거시 `Fcm` 라이브러리 내부 설정 |

#### 4.1.2 Data Elements / 데이터 요소

**`Fcm::sendFcm()` 호출 인터페이스:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `$list` | array | FCM 발송 대상 목록. 각 항목: `{ fcm_type, fcm_app_token }` |
| `$title` | string | 알림 제목 (일본어). 예: `ホンカフェ [占い] 占い師名` |
| `$msg` | string | 알림 내용 (일본어). 고정: `今、鑑定可能です。` |
| `$passUrl` | string | 딥링크 URL. 예: `{site_url}/items-kr/profile/{itemCode}` |

**FCM 요청 페이로드 (레거시 라이브러리 내부 구성):**

```json
{
  "to": "{fcm_app_token}",
  "notification": {
    "title": "ホンカフェ [占い] 占い師名",
    "body": "今、鑑定可能です。",
    "sound": "default"
  },
  "data": {
    "passUrl": "{site_url}/items-kr/profile/{itemCode}"
  },
  "priority": "high"
}
```

#### 4.1.3 Communication Protocol / 통신 프로토콜

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS POST (cURL) — 레거시 라이브러리 내부 |
| 인증 헤더 | 레거시 `Fcm` 라이브러리 내부에서 `Authorization: key=...` 처리 |
| 타임아웃 | 레거시 라이브러리 내부 설정 (별도 확인 필요) |
| 재시도 정책 | 레거시 라이브러리 내부 처리 |

#### 4.1.4 Error Handling / 에러 처리

| FCM Error | Handling |
|-----------|---------|
| FCM 발송 실패 | 레거시 `Fcm` 라이브러리 내부 처리. Service 레벨에서 별도 실패 감지 없음 |
| `NotRegistered` | 레거시 라이브러리 내부 처리 (현재 Service에서 `deleteFcmToken()` 호출 없음) |
| 타임아웃 | 레거시 라이브러리 내부 처리 |

#### 4.1.5 Data Flow / 데이터 흐름

```
FcmNotificationService::sendFcmToAlarmList($alarmList, $stCode, $itemCodeValue, $itemFlag, $cpCode)
  1. FCM 라이브러리 초기화: $fcm = new Fcm($stCode)
  2. 발송 대상 목록 구성:
     foreach ($alarmList as $value) {
         $sendSite[$stCode]['list'][] = [
             'fcm_type'      => $value->fcm_type,
             'fcm_app_token' => $value->fcm_app_token,
         ];
     }
  3. 메시지 구성:
     $setFlag = $itemFlag === 'call' ? 'items' : 'chat'
     $subItemFlag = $cpCode === 'PVK' ? '-kr' : ''
     title = 'ホンカフェ [' . $it_category_name . '] ' . $it_nick
     msg   = '今、鑑定可能です。'
     passUrl = site_url($setFlag . $subItemFlag . '/profile/' . $itemCodeValue)
  4. FCM 발송:
     $fcm->sendFcm($list, $title, $msg, $passUrl)  // 레거시 라이브러리 호출
```

---

## 5. Events / 이벤트 계약

| Event | Trigger | Target | Description |
|-------|---------|--------|-------------|
| FCM 토큰 등록 | `FcmController::index()` → `MemberRepository::UpdateFcmToken()` | Member 모듈 FCM 토큰 저장소 | cr_code, token, type 기반 토큰 갱신 |
| FCM 발송 성공 | `sendKoreaCalleeNotification()` — 알람 목록 있음 + FCM 발송 완료 | 알람 상태 갱신 + 이력 저장 | `updateReturnAlarmDone()` + `MypageRepository::SetAlarm()` 호출 |
| 알람 완료 처리 | `sendKoreaCalleeNotification()` — FCM 발송 후 | 알람 레코드 상태 'complete' | `AlarmRepository::updateReturnAlarmDone()` |
| 이력 저장 | `saveCalleeAlarmHistory()` | Mypage 모듈 | `MypageRepository::SetAlarm({ type, ac_id, cr_code, subject, content, link })` |
| 알람 없음 (발송 건너뜀) | `getReturnAlarm()` → false | — | `false` 반환. 이력 미기록 |

---

## 6. Error Contract / 에러 처리 계약

### 6.1 Standard Error Response / 표준 에러 응답 형식

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "에러 메시지"
  }
}
```

### 6.2 Error Code Table / 에러 코드 목록

| HTTP Status | Error Code | Endpoint | Trigger Condition | Consumer Action |
|-------------|------------|----------|------------------|----------------|
| 500 | `INTERNAL` | `fcm/index` | `cr_code`, `st_code`, `token`, `type` 중 누락 또는 빈 값 | 필수 파라미터 포함 후 재요청 |
| 500 | `INTERNAL` | `fcm/index` | `MemberRepository::UpdateFcmToken()` 실패 | 서버 에러 처리 또는 재시도 |
| 403 | `FORBIDDEN` | `fcm/korea-callee-fcm` | API Key 인증 실패 (`X-Api-Key` 누락 또는 유효하지 않음) | 유효한 API Key 사용 |
| 500 | `INTERNAL` | 공통 | DB 접근 실패 등 서버 내부 오류 | 재시도 또는 고객 지원 |

> **이전 버전(v2.0) 변경**: `fcm/index` 400 `INVALID_INPUT` 제거 (실제 Controller는 파라미터 누락 시 500 `INTERNAL` 반환). `korea-callee-fcm` 400 `INVALID_INPUT` 제거 (Controller에 입력 검증 없음). 404 `NOT_FOUND` 제거 (calleeId 검증 로직 없음, NOTIF-DEF-008).

### 6.3 FCM 발송 실패는 HTTP 에러 반환하지 않음

FCM 발송 자체의 성공/실패는 HTTP 응답 상태코드에 반영하지 않는다. `sendKoreaCalleeNotification()` Service 메서드는 `bool`을 반환하고, Controller는 이를 직접 `return`한다.

---

## 7. Data Formats / 데이터 포맷

### 7.1 DB → API 필드 매핑 (camelCase 변환)

| DB Column (snake_case) | API Response Key (camelCase) | 비고 |
|------------------------|------------------------------|------|
| `alarm_id` | `alarmId` | 설계 목표 |
| `callee_id` | `calleeId` | 설계 목표 |
| `caller_id` | `callerId` | 설계 목표 |
| `alarm_type` | `alarmType` | 설계 목표 |
| `created_at` | `createdAt` | 설계 목표 |
| `updated_at` | `updatedAt` | 설계 목표 |

> **요청 파라미터**: `fcm/index` EP 요청은 `cr_code`, `st_code`, `token`, `type` (snake_case). `korea-callee-fcm` EP 요청은 `ce_code`, `item_flag` (snake_case). Controller가 snake_case 키를 직접 읽음 — camelCase 자동 변환 없음.

### 7.2 Request / Response JSON Examples / 요청/응답 JSON 예시

#### POST /api/fcm/index (FCM 토큰 등록)

**요청**
```json
{
  "cr_code": "CR-001",
  "st_code": "ST-001",
  "token": "dGhpcyBpcyBhIGZha2UgdG9rZW4x...",
  "type": "android"
}
```

**요청 헤더**
```
X-Forwarded-Proto: https
Content-Type: application/json
```

> **참고**: 현재 Routes.php에 인증 필터 미설정. JWT/CSRF 헤더 불필요 (보안 리스크 — NOTIF-DEF-005).

**응답 200 OK**
```json
{
  "data": {}
}
```

**응답 500 Internal Server Error** — 파라미터 누락 또는 빈 값
```json
{
  "error": {
    "code": "INTERNAL",
    "message": "CR_CODE NOT EXIST"
  }
}
```

---

#### POST /api/fcm/korea-callee-fcm (한국 상담사 FCM 발송)

**요청** (서버-서버, API Key 인증)
```json
{
  "ce_code": "CE-001",
  "item_flag": "call"
}
```

**요청 헤더**
```
X-Api-Key: {api_key}
Content-Type: application/json
X-Forwarded-Proto: https
```

**응답 — FCM 발송 성공 (알람 목록 있음)**

Service `true` 반환 → Controller `return true` → CI4 직렬화 (응답 포맷 CI4 버전에 의존)

**응답 — 알람 목록 없음**

Service `false` 반환 → Controller `return false` → CI4 직렬화 (응답 포맷 CI4 버전에 의존)

**응답 403 Forbidden** — API Key 인증 실패
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "유효하지 않은 API Key입니다."
  }
}
```

> **주의 (NOTIF-DEF-010)**: `korea-callee-fcm` EP의 정확한 성공 응답 포맷은 CI4가 `bool`을 어떻게 직렬화하는지에 의존. 명시적 래핑이 없어 `{"data":{"sent":bool,"alarmHistoryId":int}}` 구조 보장 불가. 향후 명시적 응답 래핑 개선 권장.

---

### 7.3 DI 등록 코드 / DI Registration

```php
// app/Modules/Notification/Config/Services.php

$services->bind(
    \App\Modules\Notification\Interfaces\FcmNotificationServiceInterface::class,
    \App\Modules\Notification\Services\FcmNotificationService::class
);

$services->bind(
    \App\Modules\Notification\Interfaces\AlarmRepositoryInterface::class,
    \App\Modules\Notification\Repositories\AlarmRepository::class
);
```

---

## 8. 타당성 검토 (Feasibility Review)

> 근거: Firebase FCM 공식 문서, OWASP API Security Top 10 2023, RFC 7807, PHP 공식 문서

| Interface Decision | Adopted Approach | Basis | Conclusion |
|-------------------|-----------------|-------|------------|
| 레거시 `Fcm` 라이브러리 래핑 | `Fcm::sendFcm()` 직접 호출. 내부 FCM 로직은 레거시 라이브러리에 위임 | CLAUDE.md — 레거시 코드는 마이그레이션 완료 전까지 유지. 현재 단계에서 신규 구현 대비 리스크 낮음 | **타당 (단기)** — 레거시 라이브러리 유지. 향후 신규 FCM HTTP v1 구현으로 교체 시 `sendFcmToAlarmList()` 메서드만 수정 |
| API Key 인증 + CSRF 면제 (`korea-callee-fcm` EP) | `X-Api-Key` 헤더 + `auth:apikey` 필터. CSRF 면제 | OWASP API2:2023 — 서버-서버 통신에서 API Key는 표준 인증 방식. CSRF는 브라우저 기반 공격으로 서버-서버 호출에 부적용. CLAUDE.md — "API Key 인증 시 CSRF 검증 생략" 정책 일치 | **타당** — CSRF 면제가 보안 정책과 일치 |
| `fcm/index` EP 인증 필터 미설정 | Routes.php에 필터 없음 | 현재 코드 상태. OWASP API1:2023 — 인증 없는 FCM 토큰 덮어쓰기 가능. 보안 리스크 | **비타당** — 인증 필터 추가 Checkpoint 권장. 현재 API 현실 기준으로 문서화 |
| Service `bool` 반환 → Controller 직접 `return` | `return $this->fcmNotificationService->sendKoreaCalleeNotification(...)` | 현재 구현 상태. RFC 7231 — HTTP 응답은 명확한 상태코드 + body 구조 권장. CI4 `bool` 직렬화는 명세 불투명 | **부분 타당** — 현재 동작은 하나 명시적 `respondSuccess($result)` 래핑이 RFC 7231 관점에서 더 타당 |
| `getReturnAlarm()` false 반환 처리 | `if (!$alarmList) return false` | 알람 없음 = 발송 불필요. false 반환으로 Controller에 위임 | **타당** — 예외 없음. 호출자가 false 응답을 처리. 발송 건너뜀을 에러로 취급하지 않는 설계 |

---

## 9. 변경 영향 기록 (Change Impact Log)

| Change Item | Impact Scope | Improvement | Rationale |
|-------------|-------------|-------------|-----------|
| MIL-STD-498 5-subsection 형식 전면 적용 (v2.0) | 문서 전체 재구성 | 내부 IF 2개 + 외부 IF 1개를 각각 Identifier/Data/Communication/Error/Flow 5개 subsection으로 구조화 | MIL-STD-498 표준 준수 |
| Requirements Traceability Matrix 신설 (§10) (v2.0) | 신규 섹션 | FR 5건 + NFR 3건 ↔ IDD 인터페이스 추적성 확보 | MIL-STD-498 추적성 요구 |
| v2.0 → v2.1: [A] 이슈 11건 반영 (2026-04-21) | 다수 섹션 | API SSOT 기준으로 전면 정합성 수정 | notification-api-vs-ieee-20260421.md 대조 리포트 기반 재작성 |
| NOTIF-DEF-001: §7.2 요청/응답 예시 URL 수정 | §7.2 Data Formats | `POST /api/notifications/fcm-token` → `POST /api/fcm/index`. `POST /api/notifications/korea-callee` → `POST /api/fcm/korea-callee-fcm` | Routes.php 실제 URL 기준 |
| NOTIF-DEF-002: §7.2 요청 JSON 예시 수정 | §7.2 Data Formats | `{"fcmToken":"...","deviceId":"..."}` → `{"cr_code":"...","st_code":"...","token":"...","type":"..."}` | `FcmController::index()` 실제 파라미터 기준 |
| NOTIF-DEF-003: §3.1.2 Service 시그니처 전면 교체 | §3.1.2 Internal IF | `registerFcmToken(int, string, string): bool` 제거. `sendKoreaCalleeNotification(string $calleeCode, string $itemFlag): bool` 실제 구현 반영 | 실제 `FcmNotificationService::sendKoreaCalleeNotification()` 코드 기준 |
| NOTIF-DEF-003: §3.2.2 Repository 인터페이스 전면 교체 | §3.2.2 Internal IF | `findFcmTokenByAccountId`, `upsertFcmToken`, `insertAlarmHistory`, `deleteFcmToken` 제거. `getReturnAlarm`, `updateReturnAlarmDone` 반영 | 실제 `FcmNotificationService` 코드에서 사용하는 메서드 기준 |
| NOTIF-DEF-004: §7.2 응답 JSON 수정 | §7.2 Data Formats | `{"data":{"registered":true}}` → `{"data":{}}` | `FcmController::index()` `respondSuccess()` 인자 없음 = `{"data":{}}` |
| NOTIF-DEF-005: §7.2 요청 헤더 설명 수정 | §7.2 Data Formats | `fcm/index` EP 인증 헤더 미필요 현황 명시. 보안 리스크 NOTIF-DEF-005 주석 추가 | 실제 Routes.php 필터 미설정 상태 반영 |
| NOTIF-DEF-008: §6.2 에러 코드 테이블 수정 | §6.2 Error Contract | `korea-callee` 400 `INVALID_INPUT` (`calleeId/callerId` 누락) 제거. `fcm/index` 400 제거. 실제 Controller 검증 로직 없음 반영 | Controller 실제 코드 기준. 입력 검증 없는 EP의 400 에러 코드 명세 오류 수정 |
| NOTIF-DEF-010: §7.2 `korea-callee-fcm` 응답 설명 수정 | §7.2 Data Formats | `{"data":{"sent":true,"alarmHistoryId":789}}` 형식 보장 불가 명시. CI4 bool 직렬화 의존 주의사항 추가 | `FcmController::koreaCalleeFcm()` 실제 코드: Service bool 반환값 직접 return |
| NOTIF-DEF-003 / §3.1.5: Data Flow 수정 | §3.1.5 Internal IF | FCM 발송 흐름을 실제 구현 기준으로 재작성 (ItemCodeSelect → getReturnAlarm → Fcm::sendFcm → updateReturnAlarmDone → SetAlarm) | 설계 목표 흐름(findFcmTokenByAccountId → insertAlarmHistory)이 실제 코드와 전혀 다름 |

---

## 10. Requirements Traceability Matrix / 요구사항 추적성 매트릭스

| FR/NFR ID | 요구사항 명 | IDD Interface | Interface Method |
|-----------|-----------|--------------|-----------------|
| FR-001 | FCM 토큰 등록 | `MemberRepository::UpdateFcmToken()` (외부 모듈 — Member) | `UpdateFcmToken($crCode, $token, $type)` |
| FR-002 | 한국 상담사 FCM 발송 | IF-INT-001 `FcmNotificationServiceInterface`, IF-EXT-001 FCM API | `sendKoreaCalleeNotification($calleeCode, $itemFlag)`, `Fcm::sendFcm()` |
| FR-002a | 일본어 메시지 발송 | IF-EXT-001 FCM API | FCM 페이로드 title/msg 일본어 구성 (`sendFcmToAlarmList()`) |
| FR-002b | 알람 이력 기록 | `MypageRepository::SetAlarm()` (외부 모듈 — Mypage) | `SetAlarm({ type, ac_id, cr_code, subject, content, link })` |
| FR-002c | FCM 토큰 만료 처리 | IF-EXT-001 FCM API | 레거시 `Fcm` 라이브러리 내부 처리 |
| NFR-001 | FCM 발송 결과 알람 상태 갱신 | IF-INT-002 `AlarmRepositoryInterface` | `updateReturnAlarmDone(...)` |
| NFR-003 | fcm/index EP 인증 | IF-INT-001 (미설정) | Routes.php 필터 미설정 현황 (NOTIF-DEF-005) |
| NFR-004 | korea-callee-fcm API Key 인증 | IF-INT-001 `FcmNotificationServiceInterface` | `sendKoreaCalleeNotification()` 필터 체인 (`auth:apikey`) |
| NFR-002 | FCM 응답 시간 P95 3초 | IF-EXT-001 FCM API | 레거시 `Fcm` 라이브러리 타임아웃 설정 |
| NFR-005 | FCM 서버 키 환경변수 관리 | IF-EXT-001 FCM API | 레거시 `Fcm` 라이브러리 내부 환경변수 참조 |
| NFR-007 | 일본어 메시지 | IF-EXT-001 FCM API | `sendFcmToAlarmList()` 일본어 하드코딩 (레거시) |
| NFR-008 | FCM 타임아웃 | IF-EXT-001 FCM API | 레거시 `Fcm` 라이브러리 내부 설정 |

---

## 11. 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-15 | 1.0.0 | 초기 작성 — Notification Module IDD | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 전면 재구성. Scope(3 sub), References, 내부 IF(2개 × 5-subsection: PHP 시그니처·SQL·Data Flow 포함), 외부 IF(FCM API × 5-subsection: 페이로드·cURL 코드·에러 매핑 상세화), Events(5건), Error Contract(6건), Data Formats(요청/응답 예시 2 EP × 4~6 케이스), 타당성(4건), 변경 영향(7건), Requirements Traceability Matrix(9건) 신설 | jypark |
| 2026-04-21 | 2.1.0 | API SSOT 대조 리포트 [A] 이슈 11건 반영. EP URL 전체 수정(DEF-001), 요청 JSON 파라미터 수정(DEF-002), Service 시그니처 전면 교체(DEF-003), Repository 인터페이스 전면 교체(DEF-003), 응답 JSON 수정(DEF-004), 인증 미설정 현황 반영(DEF-005), 에러 코드 테이블 수정(DEF-008), korea-callee-fcm 응답 설명 수정(DEF-010), Data Flow 수정(DEF-003) | jypark |
