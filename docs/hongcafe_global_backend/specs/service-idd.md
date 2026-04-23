---
문서명: Service 모듈 인터페이스 설계 문서 (IDD)
문서ID: IDD-SVC-001
버전: v2.1
적용 표준: MIL-STD-498
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
대상 시스템: HongCafe Global Backend — Service Module
관련 문서:
  - service-srs.md (SRS-SVC-001)
  - service-sdd.md (SDD-SVC-001)
  - docs/api-specification.md
---

# IDD-SVC-001: Service 모듈 인터페이스 설계 문서

> **MIL-STD-498** 준수 — Interface Design Description  
> Service 모듈의 내부 인터페이스(Repository Interface), 외부 시스템 인터페이스  
> (Hermes DB, a8.net), 데이터 포맷, 에러 코드를 정의한다.

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 MIL-STD-498 IDD(Interface Design Description) 표준에 따라 Service 모듈의 모든 인터페이스를 명세한다. 내부 PHP 인터페이스, 외부 시스템 연동 프로토콜, 데이터 계약을 포함한다.

### 1.2 Scope (범위)

| 인터페이스 유형 | 항목 | 방향 |
|--------------|------|------|
| 내부 (PHP Interface) | `ServiceRepositoryInterface` | ServiceController → Repository |
| 내부 (PHP Interface) | `RejectRepositoryInterface` | RejectController → Repository |
| 내부 (PHP Interface) | `HermesRepositoryInterface` | HermesService → Repository |
| 외부 (TCP/MySQL) | Hermes DB (`101.101.211.242`) | HermesRepository → Hermes DB |
| 외부 (HTTPS/cURL) | a8.net Affiliate API | A8TrackingService → a8.net |

### 1.3 References (참조 문서)

| 문서 | 설명 |
|------|------|
| MIL-STD-498 | Software Development and Documentation |
| SRS-SVC-001 | Service 모듈 소프트웨어 요구사항 명세서 |
| SDD-SVC-001 | Service 모듈 소프트웨어 설계 문서 |
| CLAUDE.md | 프로젝트 보안 정책 및 DI 등록 규칙 |

---

## 2. Internal Interface Definitions (내부 인터페이스 정의)

### 2.1 ServiceRepositoryInterface

**파일**: `app/Modules/Service/Interfaces/ServiceRepositoryInterface.php`  
**구현체**: `ServiceRepository`  
**DI 등록**: `app/Modules/Service/Config/Services.php`

```php
<?php

declare(strict_types=1);

namespace App\Modules\Service\Interfaces;

interface ServiceRepositoryInterface
{
    /**
     * 활성 서비스 목록 조회 (정렬 및 카테고리 필터 지원).
     *
     * @param  array<string, mixed> $filters ['category' => string|null]
     * @param  string|null          $sortField 정렬 기준 필드 (화이트리스트 검증 후 전달)
     * @return array<int, array<string, mixed>> 서비스 목록
     */
    public function findActiveServices(array $filters = [], ?string $sortField = null): array;

    /**
     * 서비스 ID로 단건 조회.
     *
     * @param  int $id 서비스 ID
     * @return array<string, mixed>|null 서비스 레코드 또는 null
     */
    public function findById(int $id): ?array;

    /**
     * 상담사 ID 목록으로 프로필 정보 일괄 조회 (Hermes 매핑용).
     *
     * @param  array<int> $calleeIds 상담사 계정 ID 목록
     * @return array<int, array<string, mixed>> 상담사 프로필 배열
     */
    public function getCalleeProfiles(array $calleeIds): array;
}
```

**메서드 계약 (총 10개 메서드 중 주요 3개 명세)**:

| 메서드 | 반환형 | 예외 |
|--------|--------|------|
| `findActiveServices()` | `array` | `DatabaseException` — DB 오류 |
| `findById()` | `array\|null` | `DatabaseException` — DB 오류 |
| `getCalleeProfiles()` | `array` | `DatabaseException` — DB 오류 |

---

### 2.2 RejectRepositoryInterface

**파일**: `app/Modules/Service/Interfaces/RejectRepositoryInterface.php`  
**구현체**: `RejectRepository`  
**DI 등록**: `app/Modules/Service/Config/Services.php`

```php
<?php

declare(strict_types=1);

namespace App\Modules\Service\Interfaces;

interface RejectRepositoryInterface
{
    /**
     * 차단 레코드 생성.
     *
     * @param  array<string, string> $data ['ce_code' => ..., 'cr_code' => ..., 'rj_code' => ...]
     * @return int 생성된 rj_no (lastInsertId)
     * @throws \CodeIgniter\Database\Exceptions\DataException UNIQUE KEY 위반 시
     */
    public function create(array $data): int;

    /**
     * 차단 ID + 소유자 코드로 차단 레코드 조회 (소유권 검증 포함).
     *
     * Layer 3 Defense: WHERE rj_no = ? AND (ce_code = ? OR cr_code = ?)
     *
     * @param  int    $rejectNo   차단 레코드 ID
     * @param  string $ownerCode  소유자 코드 (ce_code 또는 cr_code)
     * @return array<string, mixed>|null 레코드 또는 null (미존재 또는 소유권 불일치)
     */
    public function findByIdAndOwner(int $rejectNo, string $ownerCode): ?array;

    /**
     * 차단 레코드 삭제.
     *
     * @param  int $rejectNo 차단 레코드 ID
     * @return bool 삭제 성공 여부
     */
    public function delete(int $rejectNo): bool;

    /**
     * 소유자 코드 기반 차단 목록 조회 (CI4 Model.paginate() 사용).
     *
     * @param  string $ownerCode 소유자 코드
     * @param  int    $perPage   페이지당 항목 수 (기본: 20)
     * @return array{items: array<int, array<string, mixed>>, pager: \CodeIgniter\Pager\Pager}
     */
    public function paginateByOwner(string $ownerCode, int $perPage = 20): array;

    /**
     * 두 코드 간 차단 여부 확인.
     *
     * @param  string $ceCode 상담사 코드
     * @param  string $crCode 사용자 코드
     * @return bool 차단 여부
     */
    public function existsByCodes(string $ceCode, string $crCode): bool;
}
```

**메서드 계약 (총 9개 메서드 중 주요 5개 명세)**:

| 메서드 | 반환형 | 예외/에러 조건 |
|--------|--------|--------------|
| `create()` | `int` | `DataException` — UNIQUE KEY `(ce_code, cr_code)` 위반 |
| `findByIdAndOwner()` | `array\|null` | null — 미존재 또는 타인 소유 |
| `delete()` | `bool` | false — 삭제 실패 |
| `paginateByOwner()` | `array` | `DatabaseException` — DB 오류 |
| `existsByCodes()` | `bool` | — |

---

### 2.3 HermesRepositoryInterface

**파일**: `app/Modules/Service/Interfaces/HermesRepositoryInterface.php`  
**구현체**: `HermesRepository`  
**DI 등록**: `app/Modules/Service/Config/Services.php`  
**특이사항**: 내부 Aurora DB가 아닌 외부 Hermes DB (`101.101.211.242`) 전용

```php
<?php

declare(strict_types=1);

namespace App\Modules\Service\Interfaces;

interface HermesRepositoryInterface
{
    /**
     * 현재 온콜(On-Call) 상태인 상담사 목록 조회.
     *
     * Hermes DB (101.101.211.242) 에서 조회.
     * 연결 실패 시 \RuntimeException 발생.
     *
     * @return array<int, array<string, mixed>> 온콜 상담사 정보 목록
     * @throws \RuntimeException Hermes DB 연결 실패 또는 쿼리 오류
     */
    public function getOnCallStatus(): array;

    /**
     * 특정 상담사의 온콜 상태 조회.
     *
     * @param  int $calleeId 상담사 계정 ID
     * @return bool 온콜 여부
     * @throws \RuntimeException Hermes DB 연결 실패
     */
    public function isCalleeOnCall(int $calleeId): bool;

    /**
     * 온콜 연결 요청을 Hermes 시스템에 전달.
     *
     * @param  int $callerId 발신자 계정 ID
     * @param  int $calleeId 수신자 계정 ID
     * @return array<string, mixed> 연결 결과 {'sessionId': string, 'status': string}
     * @throws \RuntimeException Hermes DB 연결 실패 또는 연결 요청 실패
     */
    public function requestConnection(int $callerId, int $calleeId): array;
}
```

**메서드 계약 (총 12개 메서드 중 주요 3개 명세)**:

| 메서드 | 반환형 | 예외 |
|--------|--------|------|
| `getOnCallStatus()` | `array` | `RuntimeException` — Hermes DB 연결 실패 |
| `isCalleeOnCall()` | `bool` | `RuntimeException` — Hermes DB 연결 실패 |
| `requestConnection()` | `array` | `RuntimeException` — Hermes DB 연결 실패 |

---

## 3. External Interface Definitions (외부 인터페이스 정의)

### 3.1 Hermes DB Interface (MySQL TCP)

**인터페이스 ID**: EI-SVC-001  
**유형**: 외부 MySQL DB (직접 TCP 연결)  
**호스트**: `101.101.211.242:3306`  
**프로토콜**: MySQL Wire Protocol

#### 연결 설정

| 항목 | 값 | 보안 |
|------|----|----|
| 호스트 | `101.101.211.242` | 방화벽 IP 허용 필요 |
| 포트 | `3306` | EC2 보안그룹 아웃바운드 |
| 사용자명 | `env('HERMES_DB_USER')` | 환경변수 필수 |
| 비밀번호 | `env('HERMES_DB_PASS')` | 환경변수 필수, 로그 노출 금지 |
| DB명 | `env('HERMES_DB_NAME')` | 환경변수 필수 |
| charset | `utf8mb4` | |
| 연결 타임아웃 | 5초 | |
| 쿼리 타임아웃 | 5초 | |

#### 에러 처리 계약

| 에러 조건 | 처리 방법 | 사용자 응답 |
|---------|----------|-----------|
| 연결 타임아웃 (>5초) | `RuntimeException` 발생 | HTTP 500 `INTERNAL` |
| 인증 실패 | `RuntimeException` 발생 | HTTP 500 `INTERNAL` |
| 쿼리 실패 | `RuntimeException` 발생 | HTTP 500 `INTERNAL` |
| DB 비밀번호 | 예외 메시지 마스킹 | 로그에서 제외 |

#### Hermes DB 주요 쿼리 (읽기 전용 접근 예시)

```sql
-- getOnCallStatus(): 온콜 상담사 목록
SELECT callee_id, status, started_at
FROM hermes_oncall_status
WHERE status = 'active'
  AND started_at > NOW() - INTERVAL 1 HOUR

-- isCalleeOnCall(): 특정 상담사 상태 확인
SELECT COUNT(*) AS cnt
FROM hermes_oncall_status
WHERE callee_id = :calleeId AND status = 'active'

-- requestConnection(): 연결 세션 생성
INSERT INTO hermes_sessions (caller_id, callee_id, created_at)
VALUES (:callerId, :calleeId, NOW())
```

---

### 3.2 a8.net Affiliate Tracking API Interface (HTTPS/cURL GET)

**인터페이스 ID**: EI-SVC-002  
**유형**: 외부 REST API (HTTPS GET)  
**엔드포인트**: `https://px.a8.net/a8fly/earnings`  
**호출 방식**: `A8TrackingService.trackFirstPayment()` (Fire-and-Forget)

#### 요청 명세

| 항목 | 값 |
|------|-----|
| 메서드 | GET |
| 프로토콜 | HTTPS |
| 인증 | 파라미터 기반 (`a8`, `pid`) |
| 타임아웃 | 연결 3초, 응답 3초 |
| 재시도 | 없음 |

**요청 파라미터**:

| 파라미터 | 필수 | 타입 | 설명 |
|---------|------|------|------|
| `a8` | 필수 | string | a8.net 파트너 ID (`A8_PID` 환경변수) |
| `pid` | 필수 | string | 프로그램 ID (동일값) |
| `so` | 필수 | string | 주문 번호 (멱등키, 중복 전송 방지) |
| `price` | 필수 | int | 결제 금액 (JPY 정수) |
| `currency` | 선택 | string | 통화 코드 (`JPY` 기본값) |

**요청 예시**:
```
GET https://px.a8.net/a8fly/earnings?a8=A8_PID&pid=A8_PID&so=ORDER-2026041501&price=5000&currency=JPY
```

#### 응답 명세

| 항목 | 값 |
|------|-----|
| 성공 응답 | HTTP 200 (응답 본문 무시) |
| 실패 응답 | 모든 비200 코드 — 에러 로그만 기록 |

**중요**: a8.net API 응답 본문은 파싱하지 않는다. 전송 성공 여부(HTTP 상태코드)만 로그 기록.

#### 실패 격리 계약

```php
// A8TrackingService 구현 계약
try {
    // cURL GET 실행 (타임아웃 3초)
    // 성공: info 로그
} catch (\Throwable $e) {
    log_message('error', 'A8Tracking failed: ' . $e->getMessage());
    // 예외 재발생(re-throw) 금지
    // 호출자(결제 로직)는 이 메서드의 성공/실패를 알 수 없음
}
```

---

## 4. Data Format Definitions (데이터 포맷 정의)

### 4.1 Service 목록 응답 포맷

```json
{
  "data": [
    {
      "serviceId": 1,
      "serviceName": "タロット占い",
      "category": "fortune",
      "price": 3000,
      "isActive": true,
      "createdAt": "2026-01-01T00:00:00Z",
      "updatedAt": "2026-01-15T00:00:00Z"
    }
  ]
}
```

### 4.2 Service 상세 응답 포맷

```json
{
  "data": {
    "serviceId": 1,
    "serviceName": "タロット占い",
    "category": "fortune",
    "price": 3000,
    "isActive": true,
    "description": "タロットカードを使った占いです。",
    "createdAt": "2026-01-01T00:00:00Z",
    "updatedAt": "2026-01-15T00:00:00Z"
  }
}
```

### 4.3 Reject (차단) 등록 요청/응답 포맷

> **EP**: `POST /api/rejects/save-reject`

**요청** (필수 4개 파라미터):
```json
{
  "ce_code": "CE001",
  "cr_code": "CR001",
  "rj_code": "RJ_CE001_CR001",
  "rj_content": "차단 사유 텍스트"
}
```

> 요청 필드 수정 내역: v2.0에서 `ceCode`/`crCode` 2개만 명세하였으나, 실제 코드는 `ce_code`, `cr_code`, `rj_code`, `rj_content` 4개를 필수로 요구한다. DB 컬럼명(`snake_case`)으로 전달하는 레거시 패턴을 반영한다.

**응답 (성공)**:
```json
{
  "data": {
    "msg": "차단 등록 완료"
  }
}
```

> 응답 수정 내역: v2.0에서 `rjNo`, `ceCode`, `crCode`, `createdAt` 4개 필드를 명세하였으나, 실제 응답은 `{ "msg": "..." }` 형태이다.

**응답 (필수 파라미터 누락 — INVALID_INPUT)**:
```json
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "必須パラメータが不足しています。"
  }
}
```

**응답 (중복 차단 — CONFLICT)**:
```json
{
  "error": {
    "code": "CONFLICT",
    "message": "すでにブロック済みです。"
  }
}
```

#### DB → 요청 필드 매핑 (차단 등록 입력)

| 요청 필드 (snake_case) | DB 컬럼 | 설명 |
|----------------------|---------|------|
| `ce_code` | `tb_reject.ce_code` | 상담사 코드 |
| `cr_code` | `tb_reject.cr_code` | 사용자 코드 |
| `rj_code` | `tb_reject.rj_code` | 차단 식별 코드 |
| `rj_content` | `tb_reject.rj_content` | 차단 상세 사유 |

### 4.4 Reject 목록 응답 포맷

> **EP**: `POST /api/rejects/get-callee-reject-list` (상담사 전용)

```json
{
  "data": [
    {
      "rjNo": 42,
      "ceCode": "CE001",
      "crCode": "CR001",
      "rjCode": "RJ_CE001_CR001",
      "rjContent": "차단 사유 텍스트",
      "crNick": "홍길동",
      "formattedDate": "2026.04.15 / 10:00"
    }
  ]
}
```

> 응답 필드 수정 내역:
> - `displayName` → `crNick`: 실제 코드는 `cr_nick`(DB) → `crNick`(camelCase) 사용
> - `createdAt` (ISO 8601) → `formattedDate` ('Y.m.d / H:i' 형식): 실제 코드가 `regist_date`를 포맷 변환하여 반환
> - `rjContent` 필드 추가: 실제 응답에 포함
> - 페이지네이션 meta 제거: 실제 응답이 meta 없이 data 배열만 반환

#### DB → 응답 필드 매핑 (차단 목록)

| DB 컬럼 (snake_case) | API 응답 키 (camelCase) | 설명 |
|---------------------|----------------------|------|
| `rj_no` | `rjNo` | 차단 레코드 ID |
| `ce_code` | `ceCode` | 상담사 코드 |
| `cr_code` | `crCode` | 사용자 코드 |
| `rj_code` | `rjCode` | 차단 식별 코드 |
| `rj_content` | `rjContent` | 차단 상세 사유 |
| `cr_nick` (JOIN) | `crNick` | 차단 대상 닉네임 |
| `regist_date` (포맷 변환) | `formattedDate` | 등록 날짜 (`Y.m.d / H:i` 형식) |

### 4.5 Hermes 온콜 상담사 목록 응답 포맷

> **EP**: `POST /api/hermes/get-on-call-callee` (API Key 인증)

**getOnCallCallee 응답** (heCode 키 맵 구조):

```json
{
  "HE001": {
    "ceCode": "CE001",
    "ceNick": "상담사닉네임",
    "online": true,
    "heCode": "HE001",
    "callType": "coin"
  },
  "HE002": {
    "ceCode": "CE002",
    "ceNick": "상담사닉네임2",
    "online": true,
    "heCode": "HE002",
    "callType": "class"
  }
}
```

> 응답 구조 수정 내역 (v2.0 → v2.1):
> - **구조 변경**: `{ "data": [...] }` (배열) → `{ "HE001": {...}, "HE002": {...} }` (heCode 키 맵)
> - **필드 변경**: `calleeId`, `displayName`, `profileImageUrl`, `isOnCall`, `onCallStartedAt` → `ceCode`, `ceNick`, `online`, `heCode`, `callType`
> - 응답이 표준 `{ "data": {...} }` 래퍼를 사용하지 않고 heCode 맵을 직접 반환한다. 이는 HermesController의 raw array 반환 패턴에서 비롯된다 (SERVICE-DEF-005, 페이즈 2 트랙 B).

**getOnCallCalleeHecode 응답** (`POST /api/hermes/get-on-call-callee-hecode`):

```json
["HE001", "HE002", "HE003"]
```

> heCode 문자열 배열을 직접 반환. type 쿼리 파라미터로 필터링 가능 (`?type=coin`).

#### Hermes 응답 필드 설명

| 필드 | 타입 | 설명 |
|------|------|------|
| `ceCode` | string | 상담사 코드 (내부 시스템 식별자) |
| `ceNick` | string | 상담사 닉네임 |
| `online` | bool | 현재 온라인(온콜) 여부 |
| `heCode` | string | Hermes 상담사 코드 (헤르메스 시스템 식별자) |
| `callType` | string | 통화 유형 (`coin`, `class` 등) |

### 4.6 DB → API 필드 매핑 (camelCase 변환)

#### tb_items 필드 매핑

| DB 컬럼 (snake_case) | API 응답 키 (camelCase) |
|---------------------|----------------------|
| `item_id` | `serviceId` |
| `item_name` | `serviceName` |
| `category` | `category` |
| `price` | `price` |
| `is_active` | `isActive` |
| `created_at` | `createdAt` |
| `updated_at` | `updatedAt` |

#### tb_reject 필드 매핑

| DB 컬럼 (snake_case) | API 응답 키 (camelCase) | 비고 |
|---------------------|----------------------|------|
| `rj_no` | `rjNo` | |
| `ce_code` | `ceCode` | |
| `cr_code` | `crCode` | |
| `rj_code` | `rjCode` | |
| `rj_content` | `rjContent` | v2.1 추가 |
| `regist_date` | `formattedDate` | 포맷 변환: `Y.m.d / H:i` |
| `cr_nick` (JOIN) | `crNick` | v2.1 수정 (`displayName` → `crNick`) |

---

## 5. Error Code Definitions (에러 코드 정의)

### 5.1 Service 모듈 에러 코드 목록

| HTTP 상태코드 | 에러 코드 | 발생 상황 | 대상 Controller |
|-------------|---------|---------|----------------|
| 400 | `INVALID_INPUT` | 필수 파라미터 누락, 잘못된 타입 | 전체 |
| 401 | `UNAUTHORIZED` | JWT 인증 실패 또는 미인증 | RejectController, HermesController |
| 403 | `FORBIDDEN` | CSRF 토큰 불일치 | RejectController, HermesController |
| 404 | `NOT_FOUND` | 서비스/차단 레코드 미존재, 소유권 불일치 | ServiceController, RejectController |
| 409 | `CONFLICT` | 차단 UNIQUE KEY 중복 | RejectController |
| 422 | `INVALID_INPUT` | sort 파라미터 화이트리스트 불일치 | ServiceController |
| 500 | `INTERNAL` | Hermes DB 연결 실패, 서버 내부 오류 | HermesController |

### 5.2 에러 응답 포맷

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ (i18n 키 기반)"
  }
}
```

**원칙**:
- 에러 메시지는 `lang()` 키 사용 — 하드코딩 문자열 금지
- HTTP 상태코드가 성공/실패의 SSOT (RFC 7231 준수)
- Hermes DB 예외 메시지에 DB 비밀번호·호스트 정보 포함 금지

---

## 6. DI Registration (의존성 주입 등록)

**파일**: `app/Modules/Service/Config/Services.php`

```php
<?php

declare(strict_types=1);

use CodeIgniter\Config\Services as BaseServices;
use App\Modules\Service\Interfaces\ServiceRepositoryInterface;
use App\Modules\Service\Interfaces\RejectRepositoryInterface;
use App\Modules\Service\Interfaces\HermesRepositoryInterface;
use App\Modules\Service\Repositories\ServiceRepository;
use App\Modules\Service\Repositories\RejectRepository;
use App\Modules\Service\Repositories\HermesRepository;

class Services extends BaseServices
{
    public static function serviceRepository(bool $getShared = true): ServiceRepositoryInterface
    {
        if ($getShared) {
            return static::getSharedInstance('serviceRepository');
        }
        return new ServiceRepository();
    }

    public static function rejectRepository(bool $getShared = true): RejectRepositoryInterface
    {
        if ($getShared) {
            return static::getSharedInstance('rejectRepository');
        }
        return new RejectRepository();
    }

    public static function hermesRepository(bool $getShared = true): HermesRepositoryInterface
    {
        if ($getShared) {
            return static::getSharedInstance('hermesRepository');
        }
        return new HermesRepository();
    }
}
```

**원칙**: 중앙 `app/Config/Services.php`에 바인딩 금지. 모듈별 분산 등록 강제.

---

## 7. Module Dependencies (모듈 간 의존성)

### 7.1 Service 모듈 → 타 모듈 의존성

| 의존 방향 | 대상 | 방식 | 용도 |
|---------|------|------|------|
| Service(HermesService) → Shared/Account | `service()` DI | 상담사 프로필 매핑 |
| Service(A8TrackingService) → (없음) | 독립 | a8.net 직접 호출 |

### 7.2 타 모듈 → Service 모듈 의존성

| 의존 방향 | 대상 | 방식 | 용도 |
|---------|------|------|------|
| Commerce → Service | `service()` DI | 결제 완료 후 A8TrackingService 호출 |

### 7.3 의존성 다이어그램

```
Commerce Module
  └──→ A8TrackingService (via service() DI)
         └──→ a8.net API (cURL GET, 외부)

HermesController
  └──→ HermesService
         ├──→ HermesRepository ──→ Hermes DB (101.101.211.242, 외부 MySQL)
         └──→ ServiceRepository ──→ Aurora MySQL (내부, 상담사 프로필)

RejectController
  └──→ RejectRepository ──→ Aurora MySQL (tb_reject)

ServiceController
  └──→ ServiceRepository ──→ Aurora MySQL (tb_items)
```

---

## 8. Interface Checklist (인터페이스 체크리스트)

| 항목 | 확인 | 비고 |
|------|------|------|
| ServiceRepositoryInterface 정의 완료 | - | 10 메서드 계약 |
| RejectRepositoryInterface 정의 완료 | - | 9 메서드 계약 |
| HermesRepositoryInterface 정의 완료 | - | 12 메서드 계약 |
| DI 바인딩 (모듈별 Services.php) | - | 중앙 등록 금지 |
| Hermes DB 연결 설정 환경변수화 | - | HERMES_DB_USER/PASS/NAME |
| Hermes DB 비밀번호 로그 미노출 | - | 마스킹 처리 확인 |
| A8TrackingService catch(\Throwable) 계약 | - | 예외 전파 금지 |
| a8.net cURL 타임아웃 3초 설정 | - | CURLOPT_TIMEOUT |
| UNIQUE KEY(ce_code, cr_code) DataException 포착 | - | CONFLICT(409) 변환 |
| 소유권 검증 쿼리 조건 내장 (Layer 3) | - | findByIdAndOwner |
| camelCase 응답 필드 매핑 정의 완료 | - | snake_case → camelCase |
| 에러 메시지 lang() 키 사용 | - | 하드코딩 금지 |

---

## 9. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 (플레이스홀더 "test idd") |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS |
| v2.1 | 2026-04-21 | jypark | **API ↔ IEEE 대조 리포트 [A] 이슈 반영 (SERVICE-DEF-009)**: 섹션 4.3 Reject 등록 요청 필드 2→4개, 응답 포맷 실제 기준으로 교체. 섹션 4.4 Reject 목록 응답 필드 갱신(`displayName`→`crNick`, `createdAt`→`formattedDate`, `rjContent` 추가, meta 제거). 섹션 4.5 Hermes 응답 구조 배열→heCode 키 맵으로 교체, 필드 갱신. 섹션 4.6 tb_reject 필드 매핑 갱신. |

### 변경 영향 기록 (v2.1)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| 섹션 4.3 Reject 등록 입력 4개 필드로 수정 | 프론트엔드 연동 시 정확한 입력 계약 제공 | 실제 코드는 ce_code, cr_code, rj_code, rj_content 4개 필수이나 IDD에 2개만 명세 |
| 섹션 4.4 응답 필드 실제 기준으로 교체 | API 연동 명세 정확도 향상 | displayName(미존재), createdAt(ISO8601 — 실제는 formattedDate) 오명세로 프론트엔드 연동 오류 가능성 |
| 섹션 4.5 Hermes 응답 배열→heCode 맵 교체 | 실제 응답 구조와 일치하여 클라이언트 연동 오류 방지 | 기존 명세 배열 구조는 실제 { "HE001": {...} } 맵과 불일치 |
| tb_reject 필드 매핑 갱신 | camelCase 변환 계약이 실제 코드와 일치 | rj_content, regist_date 등 실제 사용 컬럼 누락 |
