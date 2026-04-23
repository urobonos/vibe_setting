---
문서명: Notification — Software Design Document
문서 ID: notification-sdd
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Notification Module (HongCafe Global Backend)
관련 문서: notification-srs.md, notification-idd.md
적용 표준: IEEE 1016-2009 (Software Design Description)
---

# Notification — Software Design Document (SDD)

> IEEE 1016-2009 | version: 2.1 | lastUpdated: 2026-04-21 | module: Notification

---

## 1. Introduction / 소개

### 1.1 Purpose

This Software Design Document (SDD) describes the software design of the Notification Module of HongCafe Global Backend in conformance with IEEE 1016-2009. It covers design decisions, module decomposition, data structures, interface contracts, and architectural rationale derived from the Software Requirements Specification `notification-srs.md` v2.1.

### 1.2 Scope

This SDD covers all components within `app/Modules/Notification/`: one controller (`FcmController`, 57 lines), one service (`FcmNotificationService`, 135 lines), one repository (`AlarmRepository`), two interfaces, and configuration files. It addresses 2 endpoints.

### 1.3 Definitions, Acronyms, and Abbreviations / 용어 정의

| Term | Definition |
|------|------------|
| SDD | Software Design Document |
| BC | Bounded Context |
| ADR | Architecture Decision Record |
| DI | Dependency Injection |
| FCM | Firebase Cloud Messaging |
| GoF | Gang of Four (Design Patterns, Gamma et al., 1994) |
| ce_code | 상담사 식별 코드 (Callee code) |
| item_flag | 아이템 유형 플래그 (`call` 또는 `chat`) |

### 1.4 References / 참조 문서

| Document | Location |
|----------|----------|
| IEEE 1016-2009 — Software Design Description | IEEE Standards |
| notification-srs.md v2.1 | `docs/specs/notification-srs.md` |
| notification-idd.md v2.1 | `docs/specs/notification-idd.md` |
| Firebase FCM 공식 문서 | https://firebase.google.com/docs/cloud-messaging |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| HongCafe Global Backend CLAUDE.md | Project root `CLAUDE.md` |

### 1.5 Overview / 개요

This document is organized using the eight design viewpoints defined in IEEE 1016-2009.

| Section | IEEE 1016 Viewpoint | Content |
|---------|---------------------|---------|
| §2 | Context Viewpoint | 모듈 경계 및 외부 시스템 관계 |
| §3 | Composition Viewpoint | 디렉토리 구조 및 컴포넌트 분해 |
| §4 | Logical Viewpoint | 클래스 설계 — Controller, Service, Repository |
| §5 | Dependency Viewpoint | DI 등록 및 필터 체인 |
| §6 | Information Viewpoint | DB 스키마 및 데이터 흐름 |
| §7 | Patterns Viewpoint | 설계 패턴 및 ADR |
| §8 | Interface Viewpoint | 인터페이스 계약 |
| §9 | Interaction Viewpoint | 주요 흐름 시퀀스 |
| §10 | Design Overlay | 보안/에러/로깅/트랜잭션 횡단 관심사 |
| §11 | Traceability Matrix | FR↔SDD 추적성 |
| §12 | 타당성 검토 |  |
| §13 | 변경 영향 기록 |  |
| §14 | Document History |  |

---

## 2. Context Viewpoint / 컨텍스트 관점

### 2.1 Module Boundaries / 모듈 경계

Notification 모듈은 HongCafe Global Backend Modular Monolith 내의 독립적인 Bounded Context이다. 두 개의 진입점(사용자 직접 호출 [필터 미설정], 서버-서버 호출 [API Key])을 가지며, 레거시 FCM 라이브러리를 통해 외부 FCM 서비스에 단방향으로 의존한다.

```text
+--------------------------------------------------------------+
|                   HongCafe Global Backend                    |
|  +---------------------------------------------------------+ |
|  |                  Notification Module                    | |
|  |  FcmController (2 EP)                                  | |
|  |  +--------------------------------------------+       | |
|  |  | FcmNotificationService                     |       | |
|  |  |   sendKoreaCalleeNotification(             |       | |
|  |  |       string $calleeCode,                  |       | |
|  |  |       string $itemFlag): bool              |       | |
|  |  |   sendFcmToAlarmList() [protected]         |       | |
|  |  |   saveCalleeAlarmHistory() [protected]     |       | |
|  |  +--------------------+-----------------------+       | |
|  |                       |                               | |
|  |  +-MemberRepository---v-----------------------+       | |
|  |  |   ItemCodeSelect($calleeCode, $itemFlag)   |       | |
|  |  |   UpdateFcmToken($crCode, $token, $type)   |       | |
|  |  +--------------------+-----------------------+       | |
|  |                       |                               | |
|  |  +-AlarmRepository----v-----------------------+       | |
|  |  |   getReturnAlarm(...)                      |       | |
|  |  |   updateReturnAlarmDone(...)               |       | |
|  |  +--------------------+-----------------------+       | |
|  |                       |                               | |
|  |  +-MypageRepository---v-----------------------+       | |
|  |  |   SetAlarm($alarmData)                     |       | |
|  |  +--------------------------------------------+       | |
|  +--------------------------+------------------------------+ |
|                             | Aurora MySQL                   |
+---------------------+-------+-----------------------------+  |
                       |                   | cURL (레거시 Fcm)  |
             +---------v-------+   +-------v-----------+       |
             |  Mobile App     |   |  FCM API           |       |
             |  (필터 미설정)   |   |  fcm.googleapis.com|       |
             +-----------------+   +-------------------+       |
                                          |
                                   Callee Mobile Device

[Internal Call Service] ─── API Key (auth:apikey) ───► FcmController::koreaCalleeFcm()
```

### 2.2 External System Relationships / 외부 시스템 관계

| External System | Protocol | Purpose | Failure Mode |
|-----------------|----------|---------|-------------|
| Firebase Cloud Messaging API (레거시 Fcm 라이브러리) | HTTPS REST (cURL) | 모바일 푸시 알림 발송 | 레거시 라이브러리 내부 처리 |
| Mobile App (사용자 디바이스) | FCM 채널 | 최종 알림 수신 | — |
| Internal Call Service | HTTPS + API Key | `korea-callee-fcm` EP 호출 | 호출 실패는 통화 서비스 책임 |

---

## 3. Composition Viewpoint / 구성 관점

### 3.1 Directory Structure / 디렉토리 구조

```text
app/Modules/Notification/
├── Config/
│   ├── Routes.php              -- 2 라우트 명시적 등록
│   └── Services.php            -- DI 등록 (2개 바인딩)
├── Controllers/
│   └── FcmController.php       -- 57 lines, 2 endpoints
├── Services/
│   └── FcmNotificationService.php   -- 135 lines
├── Repositories/
│   └── AlarmRepository.php
├── Interfaces/
│   ├── FcmNotificationServiceInterface.php
│   └── AlarmRepositoryInterface.php
└── Entities/
    └── Alarm.php               -- (실제 존재하는 Entity 파일)
```

### 3.2 Endpoint Distribution / 엔드포인트 분포

| Controller | Method | HTTP | URL | Auth | CSRF |
|------------|--------|------|-----|------|------|
| `FcmController` | `index()` | POST | `/api/fcm/index` | 없음 (필터 미설정) | 미적용 |
| `FcmController` | `koreaCalleeFcm()` | POST | `/api/fcm/korea-callee-fcm` | API Key (`auth:apikey`) | 면제 |

---

## 4. Logical Viewpoint / 논리 관점

### 4.1 Controller Layer / 컨트롤러 계층

`FcmController`는 경량 컨트롤러로, 입력 값 체크 후 Repository 또는 Service로 위임한다 (총 57 lines).

**`index()` 입력 검증 — 실제 구현:**

```php
// index() 실제 검증 로직 (CI4 Validation 미사용 — 직접 isset/빈값 체크)
$post = $this->getJsonInput();
if (!isset($post['cr_code']) || $post['cr_code'] == '') {
    return $this->respondError('INTERNAL', "CR_CODE NOT EXIST", 500);
}
if (!isset($post['st_code']) || $post['st_code'] == '') {
    return $this->respondError('INTERNAL', "ST_CODE NOT EXIST", 500);
}
if (!isset($post['token']) || $post['token'] == '') {
    return $this->respondError('INTERNAL', "TOKEN NOT EXIST", 500);
}
if (!isset($post['type']) || $post['type'] == '') {
    return $this->respondError('INTERNAL', "TYPE NOT EXIST", 500);
}
// 검증 통과 후 MemberRepository::UpdateFcmToken() 호출
if (!$this->memberRepository->UpdateFcmToken($post['cr_code'], $post['token'], $post['type'])) {
    return $this->respondError('INTERNAL', $this->memberRepository->err_msg, 500);
}
return $this->respondSuccess();  // {"data":{}} 반환
```

**`koreaCalleeFcm()` — 입력 검증 없이 Service 위임:**

```php
// koreaCalleeFcm() 실제 구현 (입력 검증 없음)
$post = $this->getJsonInput();
return $this->fcmNotificationService->sendKoreaCalleeNotification(
    $post['ce_code'],
    $post['item_flag']
);
// Service bool 반환값을 Controller가 그대로 return — CI4가 응답으로 직렬화
```

### 4.2 Service Layer / 서비스 계층

**`FcmNotificationService`** (135 lines)

| Method | Visibility | Return Type | Description |
|--------|-----------|-------------|-------------|
| `sendKoreaCalleeNotification(string $calleeCode, string $itemFlag)` | public | `bool` | FCM 발송 오케스트레이션. ItemCode 조회 → 알람 목록 조회 → FCM 발송 → 알람 완료 처리 → 이력 저장 |
| `sendFcmToAlarmList(array $alarmList, string $stCode, string $itemCodeValue, string $itemFlag, string $cpCode)` | protected | `void` | 알람 목록에 FCM 발송. 레거시 `Fcm::sendFcm()` 호출 |
| `saveCalleeAlarmHistory(array $alarmList, string $itemCodeValue, string $itemFlag, string $cpCode)` | protected | `void` | `MypageRepository::SetAlarm()` 호출로 알림 이력 저장 |

**`sendKoreaCalleeNotification()` 내부 흐름 — 실제 코드:**

```php
public function sendKoreaCalleeNotification(string $calleeCode, string $itemFlag): bool
{
    $itemCode = $this->memberRepository->ItemCodeSelect($calleeCode, $itemFlag);
    $itemCodeValue = $itemCode['item_code'];

    $stCode   = ST_CODE;
    $raStatus = 'complete';
    $cpCode   = 'PVK';

    $alarmList = $this->alarmRepository->getReturnAlarm($calleeCode, $itemCodeValue, $stCode, $itemFlag);

    if (!$alarmList) {
        return false;
    }

    $this->sendFcmToAlarmList($alarmList, $stCode, $itemCodeValue, $itemFlag, $cpCode);
    $this->alarmRepository->updateReturnAlarmDone($calleeCode, $itemCodeValue, $stCode, $raStatus, $itemFlag);
    $this->saveCalleeAlarmHistory($alarmList, $itemCodeValue, $itemFlag, $cpCode);

    return true;
}
```

**일본어 메시지 구성 — `sendFcmToAlarmList()` 내부:**

```php
$sendSite[$stCode]['title'] = 'ホンカフェ [' . $alarmList[0]->it_category_name . '] ' . $alarmList[0]->it_nick;
$sendSite[$stCode]['msg']   = '今、鑑定可能です。';
$sendSite[$stCode]['passUrl'] = site_url($setFlag . $subItemFlag . '/profile/' . $itemCodeValue);

$fcm->sendFcm(
    $sendSite[$stCode]['list'],
    $sendSite[$stCode]['title'],
    $sendSite[$stCode]['msg'],
    $sendSite[$stCode]['passUrl']
);
```

**생성자 파라미터 — 3개 nullable:**

```php
public function __construct(
    ?AlarmRepositoryInterface   $alarmRepository   = null,
    ?MemberRepositoryInterface  $memberRepository  = null,
    ?MypageRepositoryInterface  $mypageRepository  = null
)
```

### 4.3 Repository Layer / 저장소 계층

**`AlarmRepository`** — 실제 사용 메서드

| Method | Return Type | Description |
|--------|-------------|-------------|
| `getReturnAlarm(string $calleeCode, string $itemCodeValue, string $stCode, string $itemFlag)` | `array\|false` | 알람 목록 조회. 없으면 `false` |
| `updateReturnAlarmDone(string $calleeCode, string $itemCodeValue, string $stCode, string $raStatus, string $itemFlag)` | `bool` | 알람 완료 상태 갱신 |

> **주의**: SDD v2.0이 명세한 `findFcmTokenByAccountId`, `upsertFcmToken`, `insertAlarmHistory`, `deleteFcmToken` 메서드는 현재 Service 코드에서 사용하지 않음. Service는 레거시 패턴(`getReturnAlarm`, `updateReturnAlarmDone`)을 사용한다.

---

## 5. Dependency Viewpoint / 의존성 관점

### 5.1 DI Registration / DI 등록

모든 DI 바인딩은 `app/Modules/Notification/Config/Services.php`에 등록한다. 중앙 `app/Config/Services.php` 바인딩 금지.

```php
$services->bind(
    \App\Modules\Notification\Interfaces\FcmNotificationServiceInterface::class,
    \App\Modules\Notification\Services\FcmNotificationService::class
);

$services->bind(
    \App\Modules\Notification\Interfaces\AlarmRepositoryInterface::class,
    \App\Modules\Notification\Repositories\AlarmRepository::class
);
```

| Interface | Concrete Class | Scope |
|-----------|---------------|-------|
| `FcmNotificationServiceInterface` | `FcmNotificationService` | Shared (singleton) |
| `AlarmRepositoryInterface` | `AlarmRepository` | Shared (singleton) |

### 5.2 Cross-Module Dependencies / 모듈 간 의존성

| Dependency Direction | Method | Description |
|---------------------|--------|-------------|
| Notification → Member | `MemberRepository::UpdateFcmToken()` (DI) | FCM 토큰 갱신 |
| Notification → Member | `MemberRepository::ItemCodeSelect()` (DI) | 아이템 코드 조회 |
| Notification → Mypage | `MypageRepository::SetAlarm()` (DI) | 알림 이력 저장 |
| Notification → FCM API | 레거시 `Fcm::sendFcm()` | FCM 발송 (단방향 외부 의존성) |
| Notification ← Internal Call Service | HTTP API Key | `korea-callee-fcm` EP 호출 (역방향 없음) |

### 5.3 Filter Chain / 필터 체인

```php
// Routes.php 실제 코드
$routes->group('api', ['namespace' => 'App\Modules\Notification\Controllers'], function ($routes) {
    // FCM 토큰 등록 EP — 필터 미설정 (비인증 허용 상태, 보안 리스크 NOTIF-DEF-005)
    $routes->post('fcm/index', 'FcmController::index');

    // API Key 인증 EP (서버-서버, CSRF 면제)
    $routes->post('fcm/korea-callee-fcm', 'FcmController::koreaCalleeFcm', ['filter' => 'auth:apikey']);
});
```

---

## 6. Information Viewpoint / 정보 관점

### 6.1 Core Tables / 핵심 테이블

| Table | Description | Key Columns |
|-------|-------------|-------------|
| (레거시 Member/Alarm 테이블) | FCM 토큰 및 알람 데이터. 실제 테이블명은 `MemberRepository`, `AlarmRepository` 구현 참조 | `ce_code`, `item_code`, `fcm_app_token`, `fcm_type` 등 |

> **주의**: SDD v2.0이 명세한 `tb_fcm_token`, `tb_alarm_history` DDL은 현재 Service 코드에서 직접 사용하지 않는다. 레거시 Repository 구현을 통해 간접 접근.

### 6.2 DDL / 스키마 (설계 목표 — 실제 사용 여부 별도 확인 필요)

> NOTIF-DEF-011: `tb_fcm_token`, `tb_alarm_history` 테이블의 실제 Aurora 스키마 존재 여부는 `hongcafe-schema.db` 조회 후 별도 Checkpoint 권장.

#### tb_fcm_token (설계 목표)

```sql
CREATE TABLE tb_fcm_token (
    fcm_id      INT UNSIGNED     AUTO_INCREMENT PRIMARY KEY,
    ac_id       INT              NOT NULL                    COMMENT '계정 ID (FK → tb_account)',
    device_id   VARCHAR(200)     NOT NULL                    COMMENT '디바이스 식별자',
    fcm_token   VARCHAR(512)     NOT NULL                    COMMENT 'FCM 푸시 수신 토큰',
    created_at  DATETIME         NOT NULL                    COMMENT '등록일시 (UTC)',
    updated_at  DATETIME         NOT NULL                    COMMENT '갱신일시 (UTC)',
    UNIQUE KEY uq_fcm_token_account_device (ac_id, device_id),
    INDEX idx_ac_id (ac_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 6.3 UPSERT Pattern / UPSERT 구현 패턴 (설계 목표)

```sql
-- upsertFcmToken() 설계 목표
INSERT INTO tb_fcm_token (ac_id, device_id, fcm_token, created_at, updated_at)
VALUES (?, ?, ?, NOW(), NOW())
ON DUPLICATE KEY UPDATE
    fcm_token  = VALUES(fcm_token),
    updated_at = NOW();
```

---

## 7. Patterns Viewpoint / 패턴 관점

### 7.1 Applied Design Patterns / 적용 설계 패턴

| Pattern | Location | Rationale |
|---------|----------|-----------|
| Facade | `FcmNotificationService` | 복잡한 FCM 발송 흐름(ItemCode 조회→알람 목록 조회→FCM 발송→완료처리→이력 저장)을 단일 `sendKoreaCalleeNotification()` 메서드로 캡슐화 |
| Repository | `AlarmRepository` | DB 접근을 서비스 계층에서 격리. Mock Repository로 단위 테스트 가능 |
| Template Method (변형) | `FcmNotificationService::sendKoreaCalleeNotification()` | 알림 발송 흐름을 오케스트레이션. `sendFcmToAlarmList()`, `saveCalleeAlarmHistory()` protected 메서드로 분리 |

### 7.2 Architecture Decision Records / 아키텍처 결정 기록

| ADR | Decision | Rationale | Alternative |
|-----|----------|-----------|-------------|
| ADR-001 | 레거시 `Fcm` 라이브러리 래핑 유지 | 레거시 FCM 발송 로직을 `app/Libraries/Fcm`에서 재사용. 마이그레이션 완료 전까지 레거시 유지 (CLAUDE.md 아키텍처 원칙) | 신규 FCM HTTP v1 구현으로 교체 |
| ADR-002 | Service `bool` 반환 → Controller 직접 `return` | `koreaCalleeFcm()` Controller가 Service 반환값을 그대로 return. CI4가 응답으로 직렬화. 현재 래핑 없음 | `respondSuccess($result)` 명시적 래핑 |
| ADR-003 | `fcm/index` EP 필터 미설정 | Routes.php에 `auth` 필터 미설정. 현재 비인증 요청 허용 상태. 보안 개선 Checkpoint 필요 (NOTIF-DEF-005) | `ratelimit,csrftoken,auth` 필터 체인 추가 |
| ADR-004 | `sendKoreaCalleeNotification()` 파라미터 (string $calleeCode, string $itemFlag) | 상담사 코드와 아이템 유형 플래그 2개만으로 FCM 발송 오케스트레이션 완료. `ce_code`/`item_flag`는 알람 조회에 충분한 식별자 | `(int $calleeId, int $callerId, string $callerName)` (설계 목표 — 실제 미구현) |
| ADR-005 | 일본어 메시지 코드 하드코딩 | `sendFcmToAlarmList()` 내 일본어 문자열 하드코딩. `lang()` 키 미사용. 레거시 구현 그대로 유지 | `lang()` 키 기반 관리 (향후 개선 권장) |

---

## 8. Interface Viewpoint / 인터페이스 관점

### 8.1 Internal Interface Contracts / 내부 인터페이스 계약

**FcmNotificationServiceInterface — 실제 구현 기준**

```php
<?php
declare(strict_types=1);

namespace App\Modules\Notification\Interfaces;

interface FcmNotificationServiceInterface
{
    /**
     * 한국 상담사에게 FCM 푸시 알림 발송.
     *
     * ItemCode 조회 → 알람 목록 조회 → FCM 발송 → 알람 완료 처리 → 이력 저장.
     * 알람 목록 없으면 false 반환 (예외 없음).
     *
     * @param  string $calleeCode 상담사 코드 (ce_code)
     * @param  string $itemFlag   아이템 유형 플래그 (call/chat)
     * @return bool   true = 발송 성공, false = 알람 목록 없음
     */
    public function sendKoreaCalleeNotification(string $calleeCode, string $itemFlag): bool;
}
```

**AlarmRepositoryInterface — 실제 사용 메서드 기준**

```php
<?php
declare(strict_types=1);

namespace App\Modules\Notification\Interfaces;

interface AlarmRepositoryInterface
{
    /**
     * 상담사 코드 기반 리턴 알람 목록 조회.
     *
     * @param  string $calleeCode    상담사 코드
     * @param  string $itemCodeValue 아이템 코드
     * @param  string $stCode        스토어 코드
     * @param  string $itemFlag      아이템 유형 플래그
     * @return array|false 알람 목록 또는 빈 경우 false
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
     * @param  string $calleeCode    상담사 코드
     * @param  string $itemCodeValue 아이템 코드
     * @param  string $stCode        스토어 코드
     * @param  string $raStatus      갱신할 상태값 ('complete')
     * @param  string $itemFlag      아이템 유형 플래그
     * @return bool
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

### 8.2 API Response Contracts / API 응답 계약

| Endpoint | Success | Failure |
|----------|---------|---------|
| `POST /api/fcm/index` | 200 `{ "data": {} }` | 500 `{ "error": { "code": "INTERNAL", "message": "..." } }` |
| `POST /api/fcm/korea-callee-fcm` | Service `bool` 반환 → CI4 직렬화 | 403 `{ "error": { "code": "FORBIDDEN", "message": "..." } }` (API Key 인증 실패) |

> **주의**: `POST /api/fcm/korea-callee-fcm`의 응답 포맷은 CI4가 `bool`을 직렬화하는 방식에 의존한다. 명시적 래핑 없음 (NOTIF-DEF-010 — 향후 개선 권장).

---

## 9. Interaction Viewpoint / 인터랙션 관점

### 9.1 FCM 토큰 등록 — Normal Flow

```text
Client(Mobile App) → FcmController: POST /api/fcm/index
                                    { cr_code, st_code, token, type }
FcmController: (필터 없음 — 무조건 진행)
FcmController: isset + 빈값 체크 (cr_code, st_code, token, type)
FcmController → MemberRepository: UpdateFcmToken(cr_code, token, type)
MemberRepository → DB: FCM 토큰 갱신 쿼리
MemberRepository → FcmController: true
FcmController → Client: HTTP 200 { "data": {} }
```

### 9.2 한국 상담사 FCM 발송 — Normal Flow (알람 목록 존재)

```text
InternalServer → FcmController: POST /api/fcm/korea-callee-fcm
                                 X-Api-Key: {api_key}
                                 { ce_code: "CE-001", item_flag: "call" }
FcmController → [auth:apikey 필터] 검증 통과
FcmController → FcmNotificationService: sendKoreaCalleeNotification("CE-001", "call")
FcmNotificationService → MemberRepository: ItemCodeSelect("CE-001", "call")
MemberRepository → FcmNotificationService: { item_code: "ITEM-001" }
FcmNotificationService → AlarmRepository: getReturnAlarm("CE-001", "ITEM-001", ST_CODE, "call")
AlarmRepository → DB: 알람 목록 조회
DB → AlarmRepository: [ { fcm_app_token, fcm_type, it_nick, it_category_name, ... } ]
FcmNotificationService → sendFcmToAlarmList(alarmList, ...)
sendFcmToAlarmList → Fcm::sendFcm(list, title, msg, passUrl)  // 레거시 라이브러리
FcmNotificationService → AlarmRepository: updateReturnAlarmDone("CE-001", "ITEM-001", ST_CODE, "complete", "call")
FcmNotificationService → MypageRepository: SetAlarm({ type, ac_id, cr_code, subject, content, link })
FcmNotificationService → FcmController: true
FcmController → InternalServer: (CI4가 bool true를 직렬화)
```

### 9.3 FCM 발송 — Error Flows

```text
[알람 목록 없을 시]
AlarmRepository: getReturnAlarm(...) → false
FcmNotificationService → FcmController: false
FcmController → InternalServer: (CI4가 bool false를 직렬화)

[API Key 인증 실패]
auth:apikey 필터 → 403 FORBIDDEN

[fcm/index 파라미터 누락]
FcmController: isset 체크 실패
FcmController → Client: HTTP 500 { "error": { "code": "INTERNAL", "message": "CR_CODE NOT EXIST" } }
```

---

## 10. Design Overlay / 설계 오버레이

### 10.1 Security Overlay / 보안 횡단 관심사

| Concern | Implementation |
|---------|---------------|
| JWT 인증 (`fcm/index` EP) | **미설정** — 현재 Routes.php에 필터 없음. 보안 리스크 (NOTIF-DEF-005) |
| API Key 인증 (`korea-callee-fcm` EP) | `auth:apikey` 필터. CSRF 면제 (서버-서버) |
| FCM 서버 키 보안 | 레거시 `Fcm` 라이브러리 내부에서 환경변수 참조 |

### 10.2 Error Handling Overlay / 에러 처리 횡단 관심사

| Error Condition | HTTP Code | Error Code | Notes |
|----------------|-----------|------------|-------|
| 입력값 파라미터 누락 (`fcm/index`) | 500 | `INTERNAL` | `isset()` + 빈값 체크 실패. 400이 아닌 500 반환 (현재 구현) |
| `UpdateFcmToken()` 실패 | 500 | `INTERNAL` | Repository err_msg 반환 |
| API Key 인증 실패 | 403 | `FORBIDDEN` | `korea-callee-fcm` EP |
| 알람 목록 없음 | — | — | Service `false` 반환 → CI4 직렬화 |
| 서버 내부 오류 | 500 | `INTERNAL` | DB 접근 실패 등 |

### 10.3 Logging Overlay / 로깅 횡단 관심사

- `FcmController::index()`: `SaveLogData("fcm", "token", $post, [])` 호출 (레거시 로깅)
- `FcmController::koreaCalleeFcm()`: `SaveLogData("koreafcm", "token", $post, [])` 호출 (레거시 로깅)

### 10.4 Transaction Overlay / 트랜잭션 횡단 관심사

| Operation | Transactional Scope |
|-----------|---------------------|
| `UpdateFcmToken()` | Repository 내부 처리 |
| FCM 발송 → `updateReturnAlarmDone()` → `SetAlarm()` | 비트랜잭션 순차 호출 |

---

## 11. Traceability Matrix / 추적성 매트릭스 (FR↔SDD)

| FR ID | FR 명 | SDD Viewpoint | SDD Section |
|-------|-------|---------------|-------------|
| FR-001 | FCM 토큰 등록 | Logical, Interaction | §4.1 Controller (`index()`), §9.1 Normal Flow |
| FR-002 | 한국 상담사 FCM 발송 | Logical, Interaction | §4.2 `sendKoreaCalleeNotification()`, §9.2 Normal Flow |
| FR-002a | 일본어 메시지 발송 | Logical | §4.2 `sendFcmToAlarmList()`, §7.2 ADR-005 |
| FR-002b | 알람 이력 기록 | Logical | §4.2 `saveCalleeAlarmHistory()` |
| FR-002c | FCM 토큰 만료 처리 | Logical | 레거시 `Fcm` 라이브러리 내부 처리 |
| NFR-001 | FCM 발송 결과 알람 상태 갱신 | Logical | §4.3 `updateReturnAlarmDone()` |
| NFR-002 | FCM 응답 시간 3초 | Logical | §4.2 레거시 `Fcm` 라이브러리 타임아웃 설정 |
| NFR-003 | FCM 토큰 EP 인증 | Dependency | §5.3 Filter Chain — 미설정 현황 |
| NFR-004 | korea-callee-fcm API Key 인증 | Dependency | §5.3 Filter Chain (`auth:apikey`) |
| NFR-007 | 일본어 메시지 | Patterns | §7.2 ADR-005 (현재 하드코딩) |
| NFR-008 | FCM 타임아웃 | Logical | 레거시 `Fcm` 라이브러리 내부 설정 |

---

## 12. 타당성 검토 (Feasibility Review)

> 근거: Firebase FCM 공식 문서, OWASP API Security Top 10 2023, MySQL 8.0 Reference Manual, GoF Design Patterns

| Review ID | Topic | Conclusion | Rationale | Alternative | Trade-offs |
|-----------|-------|------------|-----------|-------------|------------|
| FEA-001 | 레거시 Fcm 라이브러리 래핑 유지 | 적합 (단기) | CLAUDE.md — 레거시 코드는 마이그레이션 완료 전까지 유지. 신규 FCM HTTP v1 구현 전환 시 Service 내 `sendFcmToAlarmList()` 메서드만 교체 가능. 단기적으로 빠른 이식성 확보 | 신규 FCM HTTP v1 직접 구현 | 레거시 유지: 빠른 이식. 신규: 표준화·테스트성 향상 |
| FEA-002 | `sendKoreaCalleeNotification(string $calleeCode, string $itemFlag)` 시그니처 | 적합 | 상담사 코드와 아이템 유형 2개 파라미터로 알람 목록 조회에 충분. 내부에서 `ItemCodeSelect()`로 `item_code` 획득. 타입 안전 (strict_types=1) | `(int $calleeId, int $callerId, string $callerName)` | 현재: 실제 구현 기반. 설계 목표: 향후 개선 시 시그니처 변경 가능 |
| FEA-003 | `fcm/index` 필터 미설정 | 비적합 | Routes.php에 `auth` 필터 미설정. 비인증 요청이 FCM 토큰을 덮어쓸 수 있음. OWASP API1:2023 — Broken Object Level Authorization. 인증 필터 추가가 OWASP 권고 방향 | `ratelimit,csrftoken,auth` 필터 추가 | 필터 추가: 보안 강화 + 기존 클라이언트 영향. 유지: 현재 동작 유지 + 보안 리스크 |
| FEA-004 | Service `bool` 반환 → Controller 직접 `return` | 부분 적합 | 현재 `koreaCalleeFcm()` Controller가 Service `bool`을 직접 `return`. CI4 응답 직렬화 동작에 의존. 명시적 래핑(`respondSuccess($result)`) 대비 응답 포맷 보장 약함. 단기적으로 동작은 하나 명세 불투명 | `return $this->respondSuccess($result)` 명시적 래핑 | 직접 return: 현재 동작 유지. 명시적 래핑: 응답 포맷 보장 강화 |
| FEA-005 | 일본어 메시지 하드코딩 | 부분 적합 | 현재 `sendFcmToAlarmList()` 내 일본어 문자열 하드코딩. NFR-007 `lang()` 키 정책 미준수. CLAUDE.md — "에러 메시지는 `lang()` 키 사용. 하드코딩 금지" 정책과 불일치. 레거시 구현으로 현재는 허용 | `lang()` 키 기반 다국어 관리 | 하드코딩: 레거시 유지 편의. `lang()` 키: 정책 준수 + 언어 확장성 |

---

## 13. 변경 영향 기록 (Change Impact Log)

| Change Item | Impact Scope | Improvement | Rationale |
|-------------|-------------|-------------|-----------|
| IEEE 1016-2009 8개 Viewpoint로 전면 재구성 (v2.0) | 문서 전체 | Context, Composition, Logical, Dependency, Information, Patterns, Interface, Interaction 8개 관점으로 모든 설계 차원 명시적 분류 | IEEE 1016-2009 준수 |
| Dependency Viewpoint 신설 (§5) | 신규 섹션 | DI 등록 코드 + 필터 체인 명시. 크로스 모듈 의존성 방향 문서화 | IEEE 1016-2009 Dependency Viewpoint 요구 |
| Design Overlay 신설 (§10) | 신규 섹션 | 보안/에러/로깅/트랜잭션 횡단 관심사 일괄 정의. 보안 정책 단일 섹션에서 확인 가능 | 횡단 관심사 가시화 |
| Traceability Matrix 신설 (§11) | 신규 섹션 | FR 10건 ↔ SDD Viewpoint/섹션 추적성 확보 | IEEE 1016-2009 추적성 요구 |
| v2.0 → v2.1: [A] 이슈 11건 반영 (2026-04-21) | 다수 섹션 | API SSOT 기준으로 전면 정합성 수정 | notification-api-vs-ieee-20260421.md 대조 리포트 기반 재작성 |
| NOTIF-DEF-001: EP URL 전체 수정 | §3.2, §5.3, §8.2, §9.1/9.2/9.3 | `/api/notifications/*` → `/api/fcm/index`, `/api/fcm/korea-callee-fcm` | Routes.php 실제 URL 기준. 잘못된 URL을 SSOT처럼 참조되는 것을 방지 |
| NOTIF-DEF-002: §4.1 Controller 입력 검증 코드 교체 | §4.1 Logical Viewpoint | `fcmToken/deviceId` 규칙 제거. 실제 `isset()` + 빈값 체크 코드로 전체 교체 | `FcmController::index()` 실제 코드 기준. 존재하지 않는 파라미터 명세 오류 수정 |
| NOTIF-DEF-003: §4.2 Service 시그니처 전면 교체 | §4.2 Logical Viewpoint | `(int $calleeId, int $callerId, string $callerName): array` → `(string $calleeCode, string $itemFlag): bool`. 내부 흐름 코드 전체 실제 코드로 교체 | `FcmNotificationService::sendKoreaCalleeNotification()` 실제 구현 코드 기준 |
| NOTIF-DEF-003: §4.3 Repository 메서드 목록 수정 | §4.3 Logical Viewpoint | `findFcmTokenByAccountId`, `upsertFcmToken`, `insertAlarmHistory`, `deleteFcmToken` 제거. 실제 사용 메서드 `getReturnAlarm`, `updateReturnAlarmDone` 반영 | Service 실제 코드에서 사용하는 메서드 기준. 설계 목표 메서드가 실제 구현과 불일치 |
| NOTIF-DEF-003: §8.1 인터페이스 시그니처 교체 | §8.1 Interface Viewpoint | `FcmNotificationServiceInterface` 및 `AlarmRepositoryInterface` PHP 시그니처 실제 코드 기반으로 재작성 | IDD §3.1.2/§3.2.2와 동기화. 실제 구현과 인터페이스 계약 일치 보장 |
| NOTIF-DEF-004: §8.2 응답 계약 수정 | §8.2 Interface Viewpoint | `fcm/index` 성공 응답 `{ "data": { "registered": true } }` → `{ "data": {} }` | `respondSuccess()` 인자 없음 = `{"data":{}}`. `registered` 키 없음 |
| NOTIF-DEF-005: §5.3 필터 체인 코드 수정 | §5.3 Dependency Viewpoint | `ratelimit,csrftoken,auth` 필터 제거. 실제 Routes.php 코드(필터 없음) 반영. 보안 리스크 명시 | 실제 코드와 문서 불일치 수정. 보안 Checkpoint 근거 제공 |
| NOTIF-DEF-011: §3.1 디렉토리 구조 수정 | §3.1 Composition Viewpoint | `Entities/(reserved for future Entity migration)` → `Entities/Alarm.php` | `app/Modules/Notification/Entities/Alarm.php` 실제 파일 존재 확인 |

---

## 14. Document History / 문서 이력

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-04-15 | 1.0.0 | 초기 작성 — Notification Module SDD | jypark |
| 2026-04-15 | 2.0.0 | IEEE 1016-2009 8개 Viewpoint 전면 재구성. Context, Composition, Logical, Dependency, Information(DDL 포함), Patterns(ADR 5건), Interface(PHP 시그니처), Interaction(3개 시퀀스), Design Overlay, Traceability Matrix 신설. PHP 내부 흐름 코드 추가 | jypark |
| 2026-04-21 | 2.1.0 | API SSOT 대조 리포트 [A] 이슈 11건 반영. EP URL 전체 수정(DEF-001), Controller 입력 검증 코드 교체(DEF-002), Service 시그니처/흐름 전면 교체(DEF-003), Repository 메서드 수정(DEF-003), 응답 계약 수정(DEF-004), 필터 체인 코드 수정(DEF-005), 디렉토리 구조 수정(DEF-011), 인터페이스 시그니처 재작성 | jypark |
