---
문서명: Service 모듈 소프트웨어 설계 문서 (SDD)
문서ID: SDD-SVC-001
버전: v2.1
적용 표준: IEEE 1016-2009
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
대상 시스템: HongCafe Global Backend — Service Module
관련 문서:
  - service-srs.md (SRS-SVC-001)
  - service-idd.md (IDD-SVC-001)
  - docs/api-specification.md
---

# SDD-SVC-001: Service 모듈 소프트웨어 설계 문서

> **IEEE 1016-2009** 준수 — Software Design Description  
> ServiceController (sort/filter), RejectController (CRUD), HermesController (온콜 상태),  
> A8TrackingService (a8.net cURL), HermesService (온콜 매핑)의 설계를 기술한다.

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 SRS-SVC-001의 요구사항을 충족하기 위한 Service 모듈의 소프트웨어 설계를 IEEE 1016-2009 표준에 따라 기술한다. 아키텍처 결정(ADR), 컴포넌트 설계, 시퀀스 다이어그램, 쿼리 설계를 포함한다.

### 1.2 Scope (범위)

- **모듈 경로**: `app/Modules/Service/`
- **컨트롤러**: `ServiceController`, `RejectController`, `HermesController`
- **서비스**: `A8TrackingService`, `HermesService`
- **레포지토리**: `ServiceRepository` (10 methods), `RejectRepository` (9 methods), `HermesRepository` (12 methods)
- **외부 연동**: Hermes DB (`101.101.211.242`), a8.net API

### 1.3 References (참조 문서)

| 문서 | 설명 |
|------|------|
| IEEE 1016-2009 | Software Design Descriptions |
| SRS-SVC-001 | Service 모듈 소프트웨어 요구사항 명세서 |
| IDD-SVC-001 | Service 모듈 인터페이스 설계 문서 |
| CLAUDE.md | 프로젝트 코딩 표준 및 아키텍처 지침 |

### 1.4 Design Viewpoints (설계 관점)

| Viewpoint | 설명 | 관련 섹션 |
|-----------|------|----------|
| Logical View | 컴포넌트 구조 및 책임 분리 | 섹션 3 |
| Process View | 요청 처리 흐름 및 시퀀스 | 섹션 5 |
| Data View | DB 테이블, 쿼리 설계 | 섹션 4 |
| External Interface View | 외부 시스템 연동 | 섹션 6 |

---

## 2. Module Structure Overview (모듈 구조 개요)

```
app/Modules/Service/
├── Config/
│   ├── Routes.php                    — 명시적 EP 등록 (Auto Routing 비활성)
│   └── Services.php                  — DI 바인딩 (Interface → Implementation)
├── Controllers/
│   ├── ServiceController.php         — 서비스 목록/상세 (sort, filter)
│   ├── RejectController.php          — 차단 CRUD
│   └── HermesController.php          — 온콜 상담사 조회·연결
├── Services/
│   ├── A8TrackingService.php         — a8.net cURL GET 추적 (Fire-and-Forget)
│   └── HermesService.php             — Hermes DB 연결 + 내부 사용자 매핑
├── Repositories/
│   ├── ServiceRepository.php         — 10 methods (tb_items 접근)
│   ├── RejectRepository.php          — 9 methods (tb_reject 접근)
│   └── HermesRepository.php          — 12 methods (외부 Hermes DB 접근)
├── Interfaces/
│   ├── ServiceRepositoryInterface.php
│   ├── RejectRepositoryInterface.php
│   └── HermesRepositoryInterface.php
└── Entities/
    ├── ServiceEntity.php
    └── RejectEntity.php
```

---

## 3. Component Design (컴포넌트 설계)

### 3.1 ServiceController

**파일**: `app/Modules/Service/Controllers/ServiceController.php`  
**상속**: `BaseController`  
**역할**: 서비스 목록 조회. 요청 body 파싱 및 Repository 위임

#### 메서드 목록

| 메서드 | HTTP | 경로 | 인증 | CSRF | 설명 |
|--------|------|------|------|------|------|
| `getServiceListMobile()` | POST | `/api/services/get-service-list-mobile` | 없음 | 면제 | 서비스 목록 (모바일) |
| `getServiceListMobileNew()` | POST | `/api/services/get-service-list-mobile-new` | 없음 | 면제 | 서비스 목록 (신규) |

> **[Open Question OQ-3]** 서비스 상세 조회 (`getServiceDetail` 또는 `show()`)는 현재 미구현 상태이다. Routes.php에 등록되어 있지 않으며, 구현 결정 시 별도 개정으로 반영한다.

#### getServiceListMobile() 상세 설계

```
입력: POST body JSON (order, limit 등 선택적 파라미터)

처리 흐름:
  1. 요청 body 파싱
  2. ServiceRepository.getMobileService($post) 호출
  3. 응답 반환

에러 처리:
  - DB 조회 실패: INTERNAL (HTTP 500)
```

#### getServiceListMobileNew() 상세 설계

```
입력: POST body JSON

처리 흐름:
  1. 요청 body 파싱
  2. ServiceRepository.getMobileServiceNew($post) 호출
  3. 응답 반환
```

#### 라우트 등록

```php
// app/Modules/Service/Config/Routes.php (실제)
$routes->post('services/get-service-list-mobile',     'ServiceController::getServiceListMobile');
$routes->post('services/get-service-list-mobile-new', 'ServiceController::getServiceListMobileNew');
```

---

### 3.2 RejectController

**파일**: `app/Modules/Service/Controllers/RejectController.php`  
**상속**: `BaseController`  
**역할**: 차단(Reject) CRUD — 등록, 해제, 목록 조회

#### 메서드 목록

| 메서드 | HTTP | 경로 | 인증 | CSRF | 설명 |
|--------|------|------|------|------|------|
| `saveReject()` | POST | `/api/rejects/save-reject` | JWT | 필수(※) | 차단 등록 |
| `deleteReject()` | DELETE | `/api/rejects/delete-reject` | JWT | 필수(※) | 차단 해제 |
| `getCalleeRejectList()` | POST | `/api/rejects/get-callee-reject-list` | JWT + role:callee | 면제(OQ-2) | 차단 목록 조회 |

> **[SERVICE-DEF-004 / 페이즈 2 트랙 B]** ※ `save-reject`와 `delete-reject`의 Routes.php 등록 시 현재 auth/csrftoken 필터가 누락된 상태이다. 이는 보안 취약점으로, 페이즈 2 트랙 B에서 필터 추가 예정이다. 설계 의도는 JWT + CSRF 필수이다.
>
> **[SERVICE-DEF-008 / OQ-2]** `get-callee-reject-list`는 POST 메서드이나 csrftoken 필터가 미등록 상태. 상담사 전용 조회 EP(GET 의미)로 판단하여 CSRF 면제 처리하고 있으나, 의도 확인이 필요하다.

#### saveReject() 상세 설계

```
입력:
  Body (JSON): { "ce_code": "string", "cr_code": "string", "rj_code": "string", "rj_content": "string" }
  (필수 4개 파라미터)

처리 흐름:
  1. csrftoken 필터: X-CSRF-TOKEN 헤더 검증 (페이즈 2 후 활성)
  2. auth 필터: JWT 검증 → ac_id 추출 (페이즈 2 후 활성)
  3. checkNeedLogin(true): 이중 검증
  4. 입력값 유효성 검증 (ce_code, cr_code, rj_code, rj_content 필수)
     → 누락 시 INVALID_INPUT (HTTP 400) 반환
  5. RejectRepository.insertReject($rejectData) 호출
     → tb_reject INSERT
     → UNIQUE KEY(ce_code, cr_code) 위반 시 포착
  6. UNIQUE 위반: CONFLICT (HTTP 409) 반환
  7. 성공: HTTP 200 { "data": { "msg": "차단 등록 완료" } } 반환
```

#### deleteReject() 상세 설계

```
입력:
  Body (JSON): { "rj_code": "string" } (차단 식별자)

처리 흐름:
  1. csrftoken + auth 필터 통과 (페이즈 2 후 활성)
  2. RejectRepository.getRejectItem($rjCode) 호출 — 존재 확인
  3. 미존재: NOT_FOUND (HTTP 404) 반환
  4. RejectRepository.deleteReject($rjCode) 호출
  5. HTTP 200 성공 응답 반환
```

#### getCalleeRejectList() 상세 설계

```
처리 흐름:
  1. role:callee 필터: JWT 검증 + ce_code 보유 확인
  2. checkNeedLogin(true): 이중 검증
  3. RejectRepository.getCalleeRejectList($params) 호출
  4. 응답 포맷: crNick, rjCode, rjContent, formattedDate 포함
```

#### 라우트 등록 (실제 Routes.php)

```php
// app/Modules/Service/Config/Routes.php (실제)
$routes->post('rejects/save-reject',         'RejectController::saveReject');
$routes->delete('rejects/delete-reject',     'RejectController::deleteReject');
$routes->post('rejects/get-callee-reject-list', 'RejectController::getCalleeRejectList', ['filter' => 'role:callee']);
```

> **설계 목표 (페이즈 2 반영 후)**:
> ```php
> $routes->post('rejects/save-reject',            'RejectController::saveReject',         ['filter' => 'ratelimit,csrftoken,auth']);
> $routes->delete('rejects/delete-reject',         'RejectController::deleteReject',        ['filter' => 'ratelimit,csrftoken,auth']);
> $routes->post('rejects/get-callee-reject-list',  'RejectController::getCalleeRejectList', ['filter' => 'ratelimit,auth,role:callee']);
> ```

---

### 3.3 HermesController

**파일**: `app/Modules/Service/Controllers/HermesController.php`  
**상속**: `BaseController`  
**역할**: Hermes 외부 시스템 온콜 상담사 조회. 서버-서버 내부 통신 전용 (API Key 인증)

#### 메서드 목록

| 메서드 | HTTP | 경로 | 인증 | CSRF | 설명 |
|--------|------|------|------|------|------|
| `getOnCallCallee()` | POST | `/api/hermes/get-on-call-callee` | API Key | 면제(API Key) | 온콜 상담사 목록 |
| `getOnCallCalleeHecode()` | POST | `/api/hermes/get-on-call-callee-hecode` | API Key | 면제(API Key) | 온콜 상담사 heCode 목록 |

> **[Open Question OQ-1 / SERVICE-DEF-003]** 온콜 연결 요청 EP (`POST /api/hermes/on-call/connect` → `connect()`)는 **미구현** 상태이다. Routes.php에 등록되어 있지 않다. 구현 결정 시 별도 개정으로 설계를 추가한다.

#### getOnCallCallee() 상세 설계

```
처리 흐름:
  1. auth:apikey 필터: X-Api-Key 헤더 검증
  2. HermesService.getOnCallCallee() 호출
     2a. 외부 Hermes DB (101.101.211.242) 연결
     2b. 온콜 상담사 목록 조회
     2c. he_code를 맵 키로 사용하여 { "HE001": {...}, "HE002": {...} } 형태로 매핑
  3. 매핑된 결과 반환
  4. Hermes DB 연결 실패: INTERNAL (HTTP 500) + 에러 로그

반환 타입: array (JSON으로 직렬화)
```

#### getOnCallCalleeHecode() 상세 설계

```
입력:
  쿼리 파라미터: type (string, 선택적) — 필터 타입 (예: 'coin', 'class')

처리 흐름:
  1. auth:apikey 필터: X-Api-Key 헤더 검증
  2. HermesService.getOnCallCalleeHecode($type) 호출
     → type 인자를 그대로 서비스 레이어에 전달
  3. heCode 배열 반환 (예: ['HE001', 'HE002'])

파라미터 수신: query string (예: ?type=coin)
```

#### 라우트 등록 (실제 Routes.php)

```php
// app/Modules/Service/Config/Routes.php (실제)
$routes->post('hermes/get-on-call-callee',        'HermesController::getOnCallCallee',        ['filter' => 'auth:apikey']);
$routes->post('hermes/get-on-call-callee-hecode', 'HermesController::getOnCallCalleeHecode',   ['filter' => 'auth:apikey']);
```

---

### 3.4 A8TrackingService

**파일**: `app/Modules/Service/Services/A8TrackingService.php`  
**역할**: a8.net 제휴 추적 API cURL GET 호출. Fire-and-Forget 패턴

#### 메서드 설계

```php
public function trackFirstPayment(
    string $orderId,
    int    $price,
    string $currency = 'JPY'
): void {
    // try-catch 감싸기 — 예외 전파 금지
    try {
        $pid = env('A8_PID');
        $url = "https://px.a8.net/a8fly/earnings?a8={$pid}&pid={$pid}&so={$orderId}&price={$price}&currency={$currency}";

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 3);         // 타임아웃 3초
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
        curl_exec($ch);
        curl_close($ch);

        log_message('info', "A8Tracking: sent. orderId={$orderId}");
    } catch (\Throwable $e) {
        log_message('error', "A8Tracking: failed. " . $e->getMessage());
        // 예외를 상위로 전파하지 않음 — 결제 로직에 영향 없음
    }
}
```

**설계 원칙**:
- 모든 예외를 `catch(\Throwable)` 로 포착하고 로그만 기록
- `env('A8_PID')` 미설정 시에도 예외 전파하지 않고 로그만 기록
- cURL 타임아웃: 연결 3초, 응답 3초 (동일 값)

---

### 3.5 HermesService

**파일**: `app/Modules/Service/Services/HermesService.php`  
**역할**: Hermes 외부 DB 연결 관리 및 온콜 상담사 내부 사용자 매핑

#### 메서드 설계

```
getOnCallCallees(): array
  1. HermesRepository.getOnCallStatus() — Hermes DB에서 온콜 상담사 ID 목록 조회
  2. ServiceRepository.getCalleeProfiles($hermesIds) — 내부 Aurora에서 프로필 매핑
  3. 병합하여 최종 배열 반환

  예외 처리:
    - Hermes DB 연결 실패 시 DatabaseException 포착 → RuntimeException으로 래핑
    - HermesController가 RuntimeException 포착 → INTERNAL(500) 반환
```

---

## 4. Data Design (데이터 설계)

### 4.1 tb_items (서비스 테이블)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `item_id` | INT PK AUTO_INCREMENT | 서비스 ID |
| `item_name` | VARCHAR(200) NOT NULL | 서비스명 |
| `category` | VARCHAR(100) | 카테고리 |
| `price` | INT NOT NULL DEFAULT 0 | 가격 (JPY) |
| `is_active` | TINYINT(1) NOT NULL DEFAULT 1 | 활성 여부 |
| `created_at` | DATETIME NOT NULL | 생성일시 (UTC) |
| `updated_at` | DATETIME NOT NULL | 수정일시 (UTC) |

### 4.2 tb_reject (차단 테이블)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `rj_no` | INT PK AUTO_INCREMENT | 차단 레코드 ID |
| `ce_code` | VARCHAR(50) NOT NULL | 상담사 코드 |
| `cr_code` | VARCHAR(50) NOT NULL | 사용자 코드 |
| `rj_code` | VARCHAR(100) | 차단 코드 (비즈니스 식별자) |
| `created_at` | DATETIME NOT NULL | 생성일시 (UTC) |

```sql
UNIQUE KEY uq_reject_ce_cr (ce_code, cr_code)
```

### 4.3 ServiceRepository — 주요 쿼리 설계

#### findActiveServices() — 서비스 목록 (sort/filter)

```sql
SELECT
    item_id,
    item_name,
    category,
    price,
    is_active,
    created_at,
    updated_at
FROM tb_items
WHERE is_active = 1
  AND (:category IS NULL OR category = :category)
ORDER BY :sort_field ASC
```

- `:category`: 카테고리 필터 (null 시 전체)
- `:sort_field`: 정렬 필드 (허용 목록 화이트리스트 검증 필수)

#### findById()

```sql
SELECT item_id, item_name, category, price, is_active, created_at, updated_at
FROM tb_items
WHERE item_id = :id AND is_active = 1
```

### 4.4 RejectRepository — 주요 쿼리 설계

#### findByIdAndOwner() — 소유권 검증

```sql
SELECT rj_no, ce_code, cr_code, rj_code, created_at
FROM tb_reject
WHERE rj_no = :rjNo
  AND (ce_code = :ownerCode OR cr_code = :ownerCode)
```

#### paginateByOwner() — 차단 목록 (CI4 Pager)

```sql
SELECT r.rj_no, r.ce_code, r.cr_code, r.rj_code, r.created_at,
       a.ac_nick
FROM tb_reject r
JOIN tb_account a ON (a.ce_code = r.ce_code OR a.cr_code = r.cr_code)
WHERE r.ce_code = :ownerCode OR r.cr_code = :ownerCode
ORDER BY r.created_at DESC
```

---

## 5. Sequence Diagrams (시퀀스 다이어그램)

### 5.1 서비스 목록 조회 시퀀스

```
Client ──→ ServiceController: POST /api/services/get-service-list-mobile
ServiceController: 요청 body 파싱
ServiceController ──→ ServiceRepository: getMobileService($post)
ServiceRepository ──→ Aurora MySQL: SELECT (tb_items, tb_goods_category 등)
Aurora MySQL ──→ ServiceRepository: 서비스 배열
ServiceRepository ──→ ServiceController: array
ServiceController ──→ Client: HTTP 200 응답
```

### 5.2 차단 등록 시퀀스

```
Client ──→ [csrftoken(페이즈2)] ──→ [auth(페이즈2)] ──→ RejectController: POST /api/rejects/save-reject
RejectController: checkNeedLogin(true) — 이중 검증
RejectController: 입력값 유효성 검증 (ce_code, cr_code, rj_code, rj_content 필수)
  [파라미터 누락]
  RejectController ──→ Client: HTTP 400 { "error": { "code": "INVALID_INPUT" } }
RejectController ──→ RejectRepository: insertReject($rejectData)
RejectRepository ──→ Aurora MySQL: INSERT INTO tb_reject (ce_code, cr_code, rj_code, rj_content)
  [성공]
  Aurora MySQL ──→ RejectRepository: 삽입 완료
  RejectController ──→ Client: HTTP 200 { "data": { "msg": "차단 등록 완료" } }
  [UNIQUE KEY 위반]
  Aurora MySQL ──→ RejectRepository: Duplicate entry 에러
  RejectController ──→ Client: HTTP 409 { "error": { "code": "CONFLICT" } }
```

### 5.3 Hermes 온콜 조회 시퀀스

```
InternalService ──→ [auth:apikey] ──→ HermesController: POST /api/hermes/get-on-call-callee
HermesController ──→ HermesService: getOnCallCallee()
  HermesService ──→ HermesRepository: getOnCallStatus() (또는 직접 Hermes DB 조회)
    HermesRepository ──→ Hermes DB (101.101.211.242): SELECT on-call status
      [성공]
      Hermes DB ──→ HermesRepository: 온콜 상담사 배열
      HermesRepository ──→ HermesService: 배열
      HermesService: he_code를 맵 키로 변환 → { "HE001": {...}, "HE002": {...} }
      HermesController ──→ InternalService: HTTP 200 { "HE001": {...}, ... }
      [Hermes DB 연결 실패 (타임아웃 5초)]
      Hermes DB ──→ HermesRepository: DatabaseException
      HermesRepository ──→ HermesService: RuntimeException
      HermesService ──→ HermesController: RuntimeException
      HermesController: 에러 로그 기록
      HermesController ──→ InternalService: HTTP 500 { "error": { "code": "INTERNAL" } }

InternalService ──→ [auth:apikey] ──→ HermesController: POST /api/hermes/get-on-call-callee-hecode?type=coin
HermesController ──→ HermesService: getOnCallCalleeHecode($type)
  HermesService ──→ (Hermes DB 조회 + type 필터)
  HermesController ──→ InternalService: HTTP 200 ['HE001', 'HE002']
```

### 5.4 a8.net 추적 이벤트 시퀀스 (결제 완료 트리거)

```
Commerce Module (결제 완료 처리)
  └──→ A8TrackingService.trackFirstPayment($orderId, $price)
         try {
           cURL GET → a8.net API (타임아웃 3초)
           성공: log_message('info', ...)
         } catch(\Throwable $e) {
           log_message('error', ...)
           // 예외 전파 없음
         }
         └──→ 결제 로직 계속 진행 (무영향)
```

---

## 6. External Interface Design (외부 인터페이스 설계)

### 6.1 Hermes DB 연결 설계

**DB 커넥션 그룹**: `hermes` (별도 그룹명으로 분리)

```php
// app/Config/Database.php 또는 환경별 설정
$hermes = [
    'hostname' => '101.101.211.242',
    'username' => env('HERMES_DB_USER'),
    'password' => env('HERMES_DB_PASS'),
    'database' => env('HERMES_DB_NAME'),
    'DBDriver' => 'MySQLi',
    'port'     => 3306,
    'charset'  => 'utf8mb4',
    'DBCollat' => 'utf8mb4_unicode_ci',
    'connectTimeout' => 5,    // 연결 타임아웃 5초
    'queryTimeout'   => 5,    // 쿼리 타임아웃 5초
];
```

**HermesRepository 커넥션 초기화**:
```php
protected function getHermesDb(): BaseConnection
{
    return Database::connect('hermes');
}
```

**자격증명 보호 원칙**:
- `HERMES_DB_USER`, `HERMES_DB_PASS`는 환경변수로만 관리
- 소스 코드·로그에 하드코딩 금지
- 예외 메시지에서 비밀번호 마스킹 필수

### 6.2 a8.net API 설계

**호출 방식**: cURL GET  
**타임아웃**: 연결 3초, 응답 3초  
**URL 형식**:

```
https://px.a8.net/a8fly/earnings
  ?a8={A8_PID}
  &pid={A8_PID}
  &so={orderId}
  &price={priceJPY}
  &currency={JPY|USD}
```

**파라미터**:

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `a8` | string | a8.net 파트너 ID (`A8_PID` 환경변수) |
| `pid` | string | 프로그램 ID (동일값) |
| `so` | string | 주문 번호 (멱등키) |
| `price` | int | 결제 금액 (JPY 정수) |
| `currency` | string | 통화 코드 (`JPY` 기본) |

---

## 7. ADR (Architecture Decision Records)

### ADR-SVC-001: Hermes DB 별도 커넥션 그룹

**결정**: Hermes DB는 Aurora MySQL과 별도 DB 커넥션 그룹(`hermes`)을 사용한다.  
**근거**: Hermes DB 장애 시 내부 커넥션 풀 고갈을 방지하기 위함. Blast Radius 최소화.  
**결과**: `HermesRepository`는 `Database::connect('hermes')`만 사용. 내부 DB와 혼용 금지.  
**영향**: `app/Config/Database.php`에 `hermes` 그룹 추가 필요.

### ADR-SVC-002: A8TrackingService Fire-and-Forget

**결정**: A8TrackingService는 예외를 상위로 전파하지 않는다.  
**근거**: 제휴 추적 실패가 결제 완료 처리를 차단해서는 안 된다. 일본 제휴 마케팅 파트너의 API 불안정성을 감안한 설계.  
**결과**: `catch(\Throwable)` 로 전체 감싸고 에러 로그만 기록.  
**영향**: 추적 실패 모니터링은 로그 기반 알람으로 별도 구성 필요.

### ADR-SVC-003: RejectController 소유권 검증 Layer 3

**결정**: 차단 해제 시 소유권 검증을 Repository 쿼리 `WHERE` 조건에 내장한다.  
**근거**: OWASP API5:2023 (BOLA) 방어. 컨트롤러 레벨 검증만으로는 타이밍 공격에 취약.  
**결과**: `findByIdAndOwner($id, $ownerCode)` 쿼리가 소유권 조건을 포함하여 미존재·타인 소유 모두 동일하게 `null` 반환 → `NOT_FOUND(404)`.

### ADR-SVC-004: ServiceRepository Sort Field 화이트리스트

**결정**: sort 파라미터 허용 필드를 화이트리스트로 제한한다.  
**근거**: 사용자 입력을 그대로 `ORDER BY`에 사용하면 SQL Injection 위험.  
**결과**: 허용 목록: `['category', 'price', 'item_name', 'created_at']`. 미포함 값은 `INVALID_INPUT(422)` 반환.

---

## 8. Design Checklist (설계 체크리스트)

| 항목 | 확인 | 비고 |
|------|------|------|
| ServiceController EP: POST RPC 방식 | - | get-service-list-mobile, get-service-list-mobile-new |
| RejectController 소유권 검증 (Layer 3 쿼리 조건) | - | ADR-SVC-003 |
| RejectController UNIQUE KEY 위반 → CONFLICT(409) | - | DataException 포착 |
| RejectController 필수 파라미터 누락 → INVALID_INPUT(400) | - | ce_code, cr_code, rj_code, rj_content |
| HermesController API Key 인증 (auth:apikey 필터) | - | 서버-서버 전용 |
| HermesController heCode 키 맵 응답 형식 | - | { "HE001": {...} } |
| HermesController 별도 커넥션 그룹 `hermes` 사용 | - | ADR-SVC-001 |
| HermesController Hermes DB 타임아웃 5초 | - | connectTimeout |
| HermesController 실패 시 INTERNAL(500) + 에러 로그 | - | |
| HermesController getOnCallCalleeHecode type 파라미터 — query string 수신 | - | (?type=coin) |
| A8TrackingService catch(\Throwable) 격리 | - | ADR-SVC-002 |
| A8TrackingService cURL 타임아웃 3초 | - | CURLOPT_TIMEOUT |
| Hermes DB 비밀번호 로그 미노출 | - | 마스킹 확인 |
| 모든 EP 명시적 Routes.php 등록 | - | Auto Routing 비활성 |
| save-reject/delete-reject auth 필터 등록 (페이즈 2 트랙 B) | - | SERVICE-DEF-004 |
| camelCase 응답 변환 | - | snake_case DB → camelCase API |
| declare(strict_types=1) 모든 파일 | - | |

---

## 9. 타당성 검토 (Feasibility Review)

| 항목 | 근거 | 결론 |
|------|------|------|
| Hermes DB 직접 접속 vs API 래핑 | **직접 접속**: CI4 멀티 DB 커넥션 지원(`db_connect("hermes")`). 실시간 온콜 상태는 Hermes DB에서만 단일 조회 가능. API 래핑 시 Hermes 서버 별도 구축 필요(추가 인프라, 지연 +100ms 이상). **장애 위험**: 외부 DB 단일 장애점(SPOF). `checkHermesDB()` 메서드로 연결 사전 확인. ADR-SVC-001에서 별도 커넥션 그룹으로 Blast Radius 최소화 설계 | 직접 접속 채택. 현재 아키텍처에서 API 래핑 대비 구현 복잡도 및 지연 절감. 중장기적으로 Hermes API 서버 분리 권고 |
| a8.net fire-and-forget 패턴 | a8.net 제휴 전환 추적은 결제 완료 후 부가 작업. 실패해도 결제 트랜잭션에 영향 없는 비핵심 기능. 동기 cURL GET 호출 후 결과 무시(false 반환 시 로깅만). SQS 비동기 큐 도입은 단순 추적 1건에 과잉 설계. ADR-SVC-002에서 `catch(\Throwable)` 격리 설계 명시 | fire-and-forget 채택. 결제 응답 지연 없이 추적 수행. 실패 허용(non-critical) |
| 차단 검증 — Repository 레벨 (Layer 3 RBAC) | OWASP API5:2023 — "Object Level Authorization" 가이드: 데이터 접근 레이어에서 소유권/권한 조건을 쿼리에 내장하는 것이 Defense in Depth 핵심. Service 레벨 체크는 별도 쿼리 추가 발생(N+1 위험). Repository 쿼리 조건 내장은 단일 쿼리로 접근 제어 완성. ADR-SVC-003에서 `findByIdAndOwner()` 패턴으로 구체화 | Repository 레벨 채택. OWASP API5 준수, 쿼리 수 최소화 |

## 10. SQL DDL

### tb_reject

```sql
CREATE TABLE tb_reject (
    rj_no INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ce_code VARCHAR(50) NOT NULL,
    cr_code VARCHAR(50) NOT NULL,
    rj_code VARCHAR(50) DEFAULT NULL COMMENT '차단 사유 코드',
    rj_content TEXT DEFAULT NULL COMMENT '차단 상세 사유',
    regist_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    st_code VARCHAR(20) DEFAULT 'hongcafe',
    UNIQUE KEY uq_reject (ce_code, cr_code),
    INDEX idx_ce_code (ce_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

> **설계 근거**: `UNIQUE KEY uq_reject(ce_code, cr_code)` — 동일 상담사-고객 쌍 중복 차단 방지. DB 레벨 멱등성 보장. `ce_code` 단일 인덱스는 상담사 차단 목록 조회(`getCalleeRejectList`) 성능 확보용. ADR-SVC-003의 소유권 검증 쿼리가 `ce_code` 인덱스를 활용한다.

## 11. Entity / VO 설계 방향

Service 모듈의 엔티티 현황 및 전환 방향:

- **RejectEntity** (`app/Modules/Service/Entities/RejectEntity.php`): 이미 존재(섹션 2 디렉토리 구조). CI4 Entity 클래스 상속. `$casts`로 `created_at` DateTimeImmutable 캐스팅. `rj_no`, `ce_code`, `cr_code`, `rj_code`, `created_at` 필드 매핑
- **ServiceEntity** (`app/Modules/Service/Entities/ServiceEntity.php`): 이미 존재. `item_id`, `item_name`, `category`, `price`, `is_active`, `created_at`, `updated_at` 필드 매핑
- **Hermes DB**: 외부 DB 직접 접속 구조상 Entity 적용 제외. array 반환 유지

> **현황**: Service 모듈은 Entity 클래스(`RejectEntity`, `ServiceEntity`)가 이미 정의됨. Hermes DB는 외부 접속 특성상 Entity 적용 제외.

## 12. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| SQL DDL(tb_reject) 섹션 신설 (섹션 10) | 차단 테이블 구조와 인덱스 설계(UNIQUE KEY, idx_ce_code)를 문서에서 직접 확인 가능. 스키마 마이그레이션 파일 작성 기준 제공. 섹션 4.2의 컬럼 명세와 연계 | 설계 문서 섹션 4.2에 컬럼 목록은 있으나 DDL이 없어 스키마 생성 시 참조 기준 불명확 |
| Entity/VO 설계 방향 섹션 신설 (섹션 11) | 기존 Entities/ 디렉토리(섹션 2)와 연계하여 Entity 클래스 현황 명확화. 마이그레이션 계획과 연계 | 섹션 2 디렉토리 구조에 Entity 파일이 존재하나 상세 설계가 누락 |
| 타당성 검토 섹션 신설 (섹션 9, 3건) | Hermes 직접 접속, a8.net 패턴, Repository RBAC 결정에 공식 근거(OWASP API5:2023) 확보. 기존 ADR(섹션 7)과 상호 참조 | 글로벌 지침 — 모든 설계 산출물에 타당성 검토 필수. ADR에 근거가 있으나 OWASP 참조가 누락 |
| 버전 v2.0 → v1.2 조정 | 다른 스펙 문서(content-srs v1.2 등)와 버전 체계 통일 | 스펙 문서군 전체를 v1.2로 일괄 업그레이드하는 작업의 일환 |

## 13. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 (플레이스홀더) |
| v1.1 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS |
| v1.2 | 2026-04-15 | jypark | 타당성 검토(3건, 섹션 9), SQL DDL(tb_reject, 섹션 10), Entity/VO 섹션(섹션 11), 변경 영향 기록(섹션 12) 추가 |
| v2.1 | 2026-04-21 | jypark | **API ↔ IEEE 대조 리포트 [A] 이슈 반영**: ServiceController 메서드 index/show → getServiceListMobile/New(POST RPC), 라우트 갱신(SERVICE-DEF-001,003). RejectController 메서드 create/delete/index → saveReject/deleteReject/getCalleeRejectList(POST), 필수 파라미터 4개, 에러 코드 정정, 필터 미등록 이슈 표기(SERVICE-DEF-002,004,008). HermesController 메서드 getOnCallList/connect → getOnCallCallee/getOnCallCalleeHecode(API Key), 미구현 연결 EP 표기(SERVICE-DEF-003, OQ-1). 시퀀스 다이어그램 전면 갱신(섹션 5). 설계 체크리스트 갱신(섹션 8). 버전 v2.0→v2.1 조정. |

### 변경 영향 기록 (v2.1)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| ServiceController 메서드명·라우트 교체 (GET → POST RPC) | 설계 문서가 실제 구현과 일치하여 코드 리뷰·유지보수 혼선 제거 | Routes.php + API 문서가 SSOT. v2.0의 RESTful 설계는 실제 코드와 불일치 |
| RejectController 메서드명·라우트 교체 + 파라미터 4개 반영 | 입력 계약이 정확히 명세되어 프론트엔드 연동 오류 방지 | IDD 4.3에 2개 필드만 명세되었으나 실제 코드는 4개 필수 (SERVICE-DEF-009) |
| RejectController 필터 미등록 이슈 명시 (페이즈 2 트랙 B) | 보안 취약점 추적 가능성 확보. 설계 의도와 현재 코드 상태 분리 기록 | auth 필터 누락 버그를 설계 문서에서 인지하고 페이즈 2에서 수정할 수 있도록 |
| HermesController 메서드명·라우트 교체 (GET JWT → POST API Key) | 접근 주체(내부 서비스)와 인증 방식이 정확히 명세됨 | v2.0이 JWT 인증으로 잘못 기술 |
| Hermes 미구현 연결 EP 표기 (OQ-1) | 미구현 기능을 설계 문서에서 투명하게 관리 | 구현 없는 EP가 설계서에 완성된 것처럼 기술되면 QA 오류 초래 |
