# HongCafe Global Backend — 프로젝트 전체 스펙

> 이 문서는 `CLAUDE.md`(프로젝트), `CLAUDE.md`(글로벌), `php8` 스킬, `mysql8` 스킬을 통합하여 작성한 단일 참조 문서이다.

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-06 |
| 유형 | report |
| 상태 | 승인됨 |

> 최종 업데이트: 2026-04-06

---

## 1. 기술 스택 & 환경

### 런타임 버전

| 항목 | 버전 | 비고 |
|------|------|------|
| PHP | 8.4+ | Constructor Promotion, Named Arguments, Enums, `readonly`, Union Types 활용 |
| CodeIgniter | 4.7+ | CI 4.7 Service Discovery 지원 |
| MySQL | 8.0.4 | Functional Index, CTE, Window Function 활용 |
| Next.js | 16 | App Router, Server Actions 사용 (프론트엔드, 별도 담당) |
| Nginx | 1.28.2 | 리버스 프록시 (Next.js + PHP-FPM 동시 서빙) |
| PHP-FPM | 8.5.3 | `/run/php-fpm/www.sock` 소켓 방식 |
| Node.js | v24.14.0 | nvm 관리, `develop` 유저 |
| PM2 | v6.0.14 | Next.js 프로세스 관리 (`/home/develop/.pm2`) |

### 코딩 원칙

- 코드 작성, 쿼리 최적화, 라이브러리 사용 시 위 버전 기준의 최신 기능을 적극 활용한다.
- PHP 8.4+ 전용 문법 예시: Constructor Promotion, `readonly` 프로퍼티, Union Types, Named Arguments, Enums.
- MySQL 8.x 전용 기능 예시: Functional Index, CTE(`WITH`), Window Function(`RANK()`, `ROW_NUMBER()`).

### 개발 명령어

```bash
# 의존성 설치
composer install

# 개발 서버 시작
php spark serve

# 전체 테스트 실행
php vendor/bin/phpunit

# 단일 테스트 파일 실행
php vendor/bin/phpunit tests/Unit/Libraries/SomeServiceTest.php

# 단일 테스트 메서드 실행
php vendor/bin/phpunit --filter testMethodName tests/Feature/SomeApiTest.php

# 데이터베이스 마이그레이션
php spark migrate
php spark migrate:rollback

# 마이그레이션 파일 생성
php spark make:migration CreateUsersTable

# 캐시 클리어
php spark cache:clear
```

---

## 2. 아키텍처 (Dual Mode)

### 개요

HongCafe Global Backend는 **Dual Mode (Legacy + Modular Monolith)** 아키텍처를 채택한다.

| 구분 | Legacy | New (Modular Monolith) |
|------|--------|------------------------|
| **적용 대상** | 기존 코드 수정 / 버그픽스 | 새 기능, 새 도메인 |
| **경로** | `app/Controllers/Api/`, `app/Libraries/`, `app/Models/` | `app/Modules/{BC}/` |
| **레이어** | Controller → Library/Service → Model (Repository 겸임) | Controller → Service → Repository → Model + Entity/VO |
| **DI 방식** | `new Service()` 또는 기존 방식 허용 | `service()` 함수 강제 |
| **모듈 간 통신** | 직접 참조 허용 | Interface Only |
| **DB 접근** | Model에서 직접 | Repository에서 QB 우선 |

### 판별 기준

- `app/Libraries/`, `app/Models/`, `app/Controllers/Api/` 수정 → **Legacy 모드** 적용
- `app/Modules/` 하위 신규 생성/수정 → **New 모드** 적용
- 새 도메인(기존에 없던 기능) 개발 요청 → **New 모드**로 `app/Modules/{BC}/` 생성

### 아키텍처 원칙 (New 모드)

| 원칙 | 설명 |
|------|------|
| **Mono-repo** | 단일 저장소에 모든 모듈(Bounded Context)을 포함 |
| **Modular Monolith** | 배포는 단일 애플리케이션, 내부는 모듈 경계로 분리 |
| **레이어 강제** | Controller → Service → Repository. 레이어 건너뛰기 금지 |
| **모듈 경계** | 모듈 간 직접 클래스 참조 금지. Interface로만 통신 |
| **DI 강제** | `service()` 함수 사용. `new Service()`, `new Model()` 직접 호출 금지 |
| **Query Builder 우선** | QB 사용이 기본. CTE/Window Function 등 미지원 구문만 `$db->query()` + named binding 허용 (Repository에서만) |

### 레이어별 책임 및 금지 사항

| 레이어 | 책임 | 금지 |
|--------|------|------|
| **Controller** | Request 파싱, 입력 검증, 응답 반환 | DB 접근, 비즈니스 로직 |
| **Service** | 비즈니스 로직, 트랜잭션 관리 | 직접 `$this->response` 반환, DB 직접 접근 |
| **Repository** | Query Builder 쿼리, 데이터 접근 전담 | 비즈니스 판단, 응답 포맷팅 |
| **Entity/VO** | 도메인 규칙, 유효성 검증 | 외부 의존성 (DB, HTTP, Framework) |
| **Model** | 테이블 매핑, 필드 정의, 모델 레벨 검증 | 비즈니스 로직 (Repository에서만 사용) |

---

## 3. 모듈 구조 & Namespace

### 기존 14개 BC 모듈

Auth, Board, Call, Chat, Commerce, Content, Event, Member, Notification, Payment, Promotion, Reservation, Service, Social

### 디렉토리 구조 전체

```
app/
├── Controllers/Api/          ← Legacy (기존 유지)
│   └── Traits/
├── Libraries/                ← Legacy (Service 역할)
├── Models/                   ← Legacy (Repository 겸임)
│
├── Modules/                  ← New (글로벌 신규 개발)
│   ├── {BC}/                          ← 예: Order, Menu, Auth 등
│   │   ├── Controllers/               ← HTTP 처리
│   │   ├── Services/                  ← 비즈니스 로직
│   │   ├── Repositories/              ← 데이터 접근
│   │   ├── Models/                    ← 테이블 매핑
│   │   ├── Entities/                  ← Domain Object (순수 PHP)
│   │   ├── ValueObjects/              ← Immutable 값 객체 (선택)
│   │   ├── Interfaces/                ← 외부 노출 계약
│   │   │   ├── {BC}ServiceInterface.php
│   │   │   └── {BC}RepositoryInterface.php
│   │   ├── Exceptions/                ← 모듈 전용 예외
│   │   └── Config/
│   │       ├── Routes.php             ← 모듈 라우트 정의
│   │       └── Services.php           ← CI 4.7 자동 발견 DI 등록
│   └── Shared/                        ← 공유 (2+ 모듈 공통)
│       ├── Models/
│       ├── Entities/
│       ├── ValueObjects/              ← Money, Email, Address 등
│       └── Interfaces/
│
├── Config/
│   ├── Autoload.php                   ← PSR-4 네임스페이스 매핑
│   ├── Routes.php                     ← 모듈 라우트 자동 로드
│   └── Services.php                   ← Legacy DI (기존 유지)
├── Database/
│   ├── Migrations/
│   └── Seeds/
├── Filters/
├── Helpers/
└── ThirdParty/
```

### Namespace 규칙

- **디렉토리명**: 복수형 사용 (`Controllers/`, `Services/`, `Repositories/`, `Models/`, `Entities/`)
- **Namespace 형태**: `App\Modules\{BC}\{Layer}`

```php
// app/Config/Autoload.php에 BC별 PSR-4 개별 등록 (CI4 auto-discovery 필수)
public $psr4 = [
    APP_NAMESPACE                => APPPATH,
    'App\\Modules\\Order'        => APPPATH . 'Modules/Order',
    'App\\Modules\\Menu'         => APPPATH . 'Modules/Menu',
    // ... BC별 추가
];
```

### 모듈 간 통신: Interface Only

```
┌─────────────┐         Interface         ┌─────────────┐
│  Order 모듈  │ ──── OrderServiceIF ────▶ │  Payment 모듈│
│             │ ◀── PaymentServiceIF ──── │             │
└─────────────┘                           └─────────────┘
```

- 다른 모듈의 구체 클래스 직접 참조 금지
- 다른 모듈의 Interface 참조만 허용
- 각 모듈은 `Interfaces/` 디렉토리에 다른 모듈이 참조할 수 있는 Interface만 공개
- 모듈 내부 클래스(Service 구체 클래스, Repository, Model)는 외부 직접 참조 불가
- 2개 이상 모듈에서 공통으로 필요한 Model/Interface는 `Modules/Shared/`에 배치

### New 모드 산출물 (9가지 필수)

새 API 엔드포인트나 기능 요청 시 아래 9가지를 반드시 동시에 생성한다. 부분 구현 금지.

1. **Controller** (`Modules/{BC}/Controllers/`)
2. **Service + Interface** (`Modules/{BC}/Services/`, `Modules/{BC}/Interfaces/`)
3. **Repository + Interface** (`Modules/{BC}/Repositories/`, `Modules/{BC}/Interfaces/`)
4. **Model** (`Modules/{BC}/Models/`)
5. **Entity/VO** (`Modules/{BC}/Entities/`, `Modules/{BC}/ValueObjects/`) — 도메인 규칙이 필요한 경우
6. **모듈 DI 등록** (`Modules/{BC}/Config/Services.php`)
7. **PHPUnit 테스트** (Unit + Feature)
8. **모듈 Routes** (`Modules/{BC}/Config/Routes.php`)
9. **API 명세서** (`api-docs/{module}/{apiname}.md`) — Markdown + OpenAPI YAML 2종

> Entity/VO는 도메인 규칙이 단순 CRUD 수준이면 생략 가능.

---

## 4. 코딩 컨벤션 (PHP 8.4+, CI4)

### PSR 준수

- **PSR-1**: `<?php` 태그, UTF-8(BOM 없음), 오토로딩 표준
- **PSR-4**: 네임스페이스 = 디렉토리 구조. `Modules\{BC}\{Layer}`
- **PSR-12**: 인덴트 4칸 스페이스, 여는 중괄호 메서드/클래스는 다음 줄

### 가독성 원칙

- 주석 없이 읽히는 명시적 코드 작성
- 전체 단어 사용 (`fullName`, `index` 등 — 약어 사용 금지)

### 주석 규칙

| 대상 | 주석 내용 |
|------|-----------|
| 모든 함수/메서드 | `@param`, `@return`, 목적 한 줄 |
| 복잡한 비즈니스 로직 | 단계별 설명 |
| Interface | 추상화 사유 |
| raw query | QB로 불가능한 사유 명시 |

### PHP 8.4+ 권장 기능

- Constructor Promotion
- Named Arguments
- Enums
- `readonly` 프로퍼티
- Union Types
- 소프트 딜리트: `$useSoftDeletes = true` + 스키마에 `deleted_at` 포함

### 의존성 주입 (DI) 규칙

CI 4.7.0+에서는 모듈별 `Config/Services.php`가 **자동 발견**된다. 메인 `app/Config/Services.php`에 수동 등록 불필요.

| 규칙 | 설명 |
|------|------|
| `service()` 함수 필수 | `service('orderService')`로 인스턴스 취득 |
| `new` 직접 호출 금지 | Controller/Service에서 `new Service()`, `new Repository()`, `new Model()` 금지 |
| Controller → Service | Controller 생성자에서 `service()`로 Service 주입 |
| Service → Repository | Service 생성자에서 `service()`로 Repository 주입 |
| Repository → Model | Repository 생성자에서 `model()` 헬퍼로 Model 주입 |
| 모듈 간 의존 | `service()`로 상대 모듈의 Interface 타입 수령 |
| getShared 패턴 | 기본 싱글턴(`true`), 테스트 시 `false`로 새 인스턴스 |

### 모듈 DI 등록 패턴 (`Modules/{BC}/Config/Services.php`)

```php
namespace App\Modules\Order\Config;

use CodeIgniter\Config\BaseService;
use App\Modules\Order\Interfaces\OrderServiceInterface;
use App\Modules\Order\Interfaces\OrderRepositoryInterface;
use App\Modules\Order\Services\OrderService;
use App\Modules\Order\Repositories\OrderRepository;
use App\Modules\Order\Models\OrderModel;

class Services extends BaseService
{
    /**
     * OrderRepository DI 바인딩.
     *
     * @param bool $getShared 싱글턴 여부 (기본: true)
     * @return OrderRepositoryInterface
     */
    public static function orderRepository(bool $getShared = true): OrderRepositoryInterface
    {
        if ($getShared) {
            return static::getSharedInstance('orderRepository');
        }
        return new OrderRepository(model(OrderModel::class));
    }

    /**
     * OrderService DI 바인딩.
     *
     * @param bool $getShared 싱글턴 여부 (기본: true)
     * @return OrderServiceInterface
     */
    public static function orderService(bool $getShared = true): OrderServiceInterface
    {
        if ($getShared) {
            return static::getSharedInstance('orderService');
        }
        return new OrderService(service('orderRepository'));
    }
}
```

### 레이어별 코드 패턴

#### Controller 패턴

```php
namespace App\Modules\Order\Controllers;

use CodeIgniter\RESTful\ResourceController;
use App\Modules\Order\Interfaces\OrderServiceInterface;
use Exception;

class OrderController extends ResourceController
{
    protected string $format = 'json';
    protected OrderServiceInterface $orderService;

    public function __construct()
    {
        $this->orderService = service('orderService');
    }

    public function index()
    {
        try {
            $page    = (int)($this->request->getGet('page') ?? 1);
            $perPage = (int)($this->request->getGet('perPage') ?? 20);
            $result  = $this->orderService->getList($page, $perPage);
            return $this->respond([
                'status' => 'success',
                'data'   => $result['data'],
                'meta'   => $result['meta'],
            ]);
        } catch (Exception $e) {
            log_message('error', 'order index error: ' . $e->getMessage());
            return $this->failServerError('서버 오류가 발생했습니다.');
        }
    }
}
```

**예외 → HTTP 상태 코드 매핑:**
- 일반 `Exception` → `failServerError()` (500) — `$e->getMessage()` 대신 안전한 메시지 반환
- 리소스 없음 → `failNotFound()` (404)
- 권한 없음 → `failForbidden()` (403)
- 중복/충돌 → `fail('message', 409)`

#### Service 패턴

- DB 직접 접근 금지 — 반드시 Repository를 통해서만 데이터 접근
- 다른 모듈 참조 시 Interface 타입만 사용
- 멀티 스텝 작업은 Service에서 트랜잭션 관리

```php
// 트랜잭션 관리 패턴
$db = \Config\Database::connect();
$db->transStart();
$this->repository->insert($orderData);
$this->repository->updateStock($itemId, $qty);
$db->transComplete();
if (!$db->transStatus()) {
    throw new Exception('트랜잭션 처리 중 오류가 발생했습니다.');
}
```

#### Repository 패턴

- Query Builder 우선 사용
- raw query는 CTE, Window Function 등 QB 미지원 구문일 때만 허용 (Repository에서만)
- raw query 사용 시 named binding 필수 + 사유 주석 필수

```php
// QB 우선 패턴
public function findActiveByUser(int $userId): array
{
    return $this->model
        ->where('user_id', $userId)
        ->where('status', 'active')
        ->orderBy('created_at', 'DESC')
        ->findAll();
}

// raw query 허용 패턴 (QB 미지원 구문만)
/**
 * [raw query 사유] Window Function(RANK)은 CI4 Query Builder 미지원.
 */
public function getSalesRanking(string $startDate, string $endDate): array
{
    $db  = \Config\Database::connect();
    $sql = <<<SQL
        WITH category_sales AS (
            SELECT category_id, SUM(amount) AS total_sales
            FROM orders
            WHERE created_at BETWEEN :startDate: AND :endDate:
            GROUP BY category_id
        )
        SELECT cs.*, RANK() OVER (ORDER BY cs.total_sales DESC) AS sales_rank
        FROM category_sales cs
    SQL;
    return $db->query($sql, [
        'startDate' => $startDate,
        'endDate'   => $endDate,
    ])->getResultArray();
}
```

**금지 패턴:**
```php
// Service/Controller에서 직접 DB 접근 금지
$db = \Config\Database::connect();
$db->table('orders')->where(...)->get();

// Repository에서 positional binding 금지
$db->query("SELECT * FROM orders WHERE id = ?", [$id]);

// raw query에 사유 주석 누락 금지
```

#### Model 패턴

```php
namespace App\Modules\Order\Models;

use CodeIgniter\Model;

class OrderModel extends Model
{
    protected $table            = 'orders';   // 복수형 snake_case
    protected $primaryKey       = 'id';
    protected $useAutoIncrement = true;
    protected $returnType       = 'array';
    protected $useSoftDeletes   = false;
    protected $allowedFields    = [/* 필드 목록 */];
    protected $useTimestamps    = true;
    protected $createdField     = 'created_at';
    protected $updatedField     = 'updated_at';

    protected $validationRules  = [
        // 모델 레벨 검증 (2차 안전망)
    ];
}
```

#### Entity 패턴 (Domain Object)

- 외부 의존성 금지 (DB, HTTP, Framework 클래스 import 불가)
- `readonly` 프로퍼티, `DateTimeImmutable` 사용 권장
- 생성자에서 도메인 규칙 검증. 유효하지 않으면 `InvalidArgumentException`

#### ValueObject 패턴 (Immutable 값 객체)

- 외부 의존성 금지 (순수 PHP만 사용)
- `final readonly class` 선언
- `equals()` 메서드로 값 비교 (참조 비교 대신)
- 2+ 모듈 공통 사용 VO는 `Modules/Shared/ValueObjects/`에 배치

### 검증 표준

Controller에서 1차 검증, Model 검증은 2차 안전망.

| 필드 유형 | 검증 규칙 |
|-----------|-----------|
| 필수 문자열 | `required\|min_length[2]\|max_length[100]` |
| 이메일 | `required\|valid_email` |
| 양의 정수 | `required\|integer\|greater_than[0]` |
| 열거형 | `required\|in_list[active,inactive]` |
| 선택적 필드 | `permit_empty\|...` |

### 사이드 이펙트 방지

파일 수정 전 모듈 내부 및 모듈 간 영향 범위를 확인한다.

- **Repository 변경 시**: 해당 Repository를 사용하는 Service 확인
- **Service 변경 시**: Controller + 다른 모듈에서 Interface로 참조하는 곳 확인
- **Model 변경 시**: Repository → Service → Controller 전체 확인
- **Interface 변경 시**: 해당 Interface를 참조하는 모든 모듈 확인 (가장 위험)
- **Migration 변경 시**: Model `$allowedFields`, `$validationRules` 동기화

### CI4 베스트 프랙티스

- JSON 요청 바디: `$this->request->getJSON(true)` 사용
- 폼 데이터: `$this->request->getVar()` 사용
- API 컨트롤러에 `protected string $format = 'json';` 항상 설정
- DI: `service('{name}')` 함수로 Service/Repository 인스턴스 취득
- Model 생성: Repository에서 `model(ClassName::class)` 헬퍼 사용
- 테스트 DI 오버라이드: Mock을 생성자에 직접 주입하여 단위 테스트

---

## 5. API 응답 표준 & 라우팅

### JSON 키 네이밍

모든 API 응답의 JSON 키는 **camelCase**를 사용한다.
(예: `currentPage`, `perPage`, `lastPage`, `createdAt`)

### 성공 응답

```json
// 단건 조회
{ "status": "success", "data": { ... } }

// 목록 조회 (페이지네이션 포함)
{
  "status": "success",
  "data": [ ... ],
  "meta": {
    "currentPage": 1,
    "perPage": 20,
    "total": 150,
    "lastPage": 8
  }
}

// 삭제 등 데이터 없는 성공
{ "status": "success", "message": "삭제되었습니다." }
```

### 에러 응답

```json
// 일반 에러
{
  "status": "error",
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "요청하신 항목을 찾을 수 없습니다."
  }
}

// 유효성 검증 에러
{
  "status": "error",
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "입력값이 유효하지 않습니다.",
    "details": {
      "email": ["이메일 형식이 올바르지 않습니다."],
      "name": ["이름은 필수 항목입니다."]
    }
  }
}
```

### 표준 에러 코드

| 에러 코드 | HTTP 상태 | CI4 헬퍼 | 설명 |
|-----------|-----------|----------|------|
| `VALIDATION_FAILED` | 400 | `failValidationErrors()` | 입력값 유효성 검증 실패 |
| `UNAUTHORIZED` | 401 | `failUnauthorized()` | 인증 실패 |
| `FORBIDDEN` | 403 | `failForbidden()` | 권한 없음 |
| `RESOURCE_NOT_FOUND` | 404 | `failNotFound()` | 리소스를 찾을 수 없음 |
| `CONFLICT` | 409 | `fail('message', 409)` | 중복/충돌 |
| `SERVER_ERROR` | 500 | `failServerError()` | 서버 내부 오류 |

> `$e->getMessage()` 대신 안전한 메시지만 반환. 내부 에러는 `log_message()`로 기록.

### 목록 조회 쿼리 파라미터 표준

| 파라미터 | 설명 | 기본값 | 예시 |
|----------|------|--------|------|
| `page` | 페이지 번호 | 1 | `?page=2` |
| `perPage` | 페이지당 항목 수 | 20 | `?perPage=50` |
| `sort` | 정렬 기준 컬럼 | `createdAt` | `?sort=createdAt` |
| `order` | 정렬 방향 | `desc` | `?order=asc` |
| `search` | 검색 키워드 | — | `?search=홍카페` |

### API URL 규격

```
/{module}/{resource}
```

| 모듈 | URL 예시 | 설명 |
|------|----------|------|
| Call | `/phone-consult/calls` | 전화 상담 |
| Commerce | `/commerce/payments` | 결제 |
| Member | `/member/profile` | 회원 프로필 |

- **module**: BC명의 kebab-case (비즈니스 도메인 표현)
- **resource**: 복수형 또는 단수형 (리소스 성격에 따라)
- BC 디렉토리명과 URL module명은 다를 수 있다 (예: `Call` BC → `/phone-consult/`)

### 라우트 정의

**Legacy 라우트** (기존 유지):
```php
$routes->group('api', ['namespace' => 'App\Controllers\Api'], function ($routes) {
    $routes->resource('items', ['controller' => 'ItemController']);
});
```

**New 모드 라우트** (모듈별 `Config/Routes.php`에 정의):
```php
// Modules/Order/Config/Routes.php
$routes->group('api/commerce', ['namespace' => 'App\Modules\Order\Controllers'], function ($routes) {
    $routes->resource('orders', ['controller' => 'OrderController']);
});
// → /api/commerce/orders
```

**메인 Routes에서 모듈 자동 로드** (`app/Config/Routes.php`):
```php
$moduleRoutes = glob(APPPATH . 'Modules/*/Config/Routes.php');
foreach ($moduleRoutes as $routeFile) {
    require $routeFile;
}
```

### API 명세서 생성 규칙

New 모드 API 생성 시 `api-docs/{module}/` 디렉토리에 2종을 자동 생성한다.

| 파일 | 용도 |
|------|------|
| `{module}-api.md` | 리뷰/공유용 Markdown 문서 |
| `{module}-api.yaml` | Swagger UI + 코드 자동 생성용 (OpenAPI 3.1) |

두 파일은 항상 동기화 상태를 유지한다.

**명세서 디렉토리/파일명 규칙:**

| 항목 | 규칙 | 예시 |
|------|------|------|
| 디렉토리 | `api-docs/{module}/` | `api-docs/commerce/` |
| module | URL 규격의 kebab-case | `commerce`, `phone-consult`, `member` |
| 파일명 | 리소스명 kebab-case + `.md` | `orders.md`, `calls.md` |

---

## 6. 데이터베이스 (MySQL 8.x)

### 핵심 원칙

#### 표준 ANSI SQL 우선

MySQL 전용 구문(`IFNULL`, `LIMIT ... OFFSET`, `GROUP_CONCAT` 등) 사용 시 ANSI 대안 쿼리를 반드시 병기한다. 타 DB(PostgreSQL, Oracle, SQL Server 등)로 이관 가능성을 항상 고려한다.

```sql
-- MySQL 전용
SELECT IFNULL(column_name, 'default') FROM table_name;

-- ANSI 표준 (병기 필수)
SELECT COALESCE(column_name, 'default') FROM table_name;
```

#### 필요한 컬럼만 SELECT

`SELECT *` 금지. 쿼리빌더 사용 시에도 사용하는 컬럼만 명시적으로 지정한다.

#### N+1 문제 방지

JOIN/서브쿼리로 일괄 조회한다.

```php
// 금지: N+1
$orders = $orderModel->findAll();
foreach ($orders as &$order) {
    $order['items'] = $itemModel->where('order_id', $order['id'])->findAll();
}

// 올바른 사용: JOIN
$builder = $db->table('orders');
$builder->select('orders.id, orders.total, order_items.product_name, order_items.quantity');
$builder->join('order_items', 'order_items.order_id = orders.id', 'left');
$result = $builder->get()->getResultArray();
```

#### Full Scan 지양

- 모든 주요 쿼리는 실행계획을 검증하여 Full Table Scan 방지
- WHERE 절 컬럼에 함수 적용 금지 (인덱스 무효화)

```sql
-- 금지: 인덱스 무효화
WHERE YEAR(created_at) = 2026

-- 올바른 사용: 범위 조건
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01'
```

#### 실행계획 확인

MySQL 8.x에서는 `EXPLAIN FORMAT=TREE`를 사용하여 실행계획을 확인한다.

보고 필수 항목:
- `Table scan` — Full Table Scan 발생
- `Nested loop`에서 inner table이 인덱스 없이 스캔되는 경우
- `Using temporary`, `Using filesort` — 대량 데이터에서 성능 이슈 가능

#### CTE 사용

임시테이블이 필요한 경우 CTE(Common Table Expression)를 사용한다. CTE 미지원 DB를 위해 서브쿼리 기반 ANSI 대안을 병기한다.

```sql
-- CTE 버전 (MySQL 8.x, PostgreSQL, SQL Server 호환)
WITH active_users AS (
    SELECT id, name, email FROM users WHERE status = 'active'
)
SELECT active_users.name, COUNT(orders.id) AS order_count
FROM active_users
JOIN orders ON orders.user_id = active_users.id
GROUP BY active_users.name;

-- ANSI 서브쿼리 대안 (병기 필수)
SELECT sub.name, COUNT(orders.id) AS order_count
FROM (
    SELECT id, name, email FROM users WHERE status = 'active'
) AS sub
JOIN orders ON orders.user_id = sub.id
GROUP BY sub.name;
```

#### 인덱스 변경 — 사용자 승인 필수

인덱스 추가/수정/삭제 시 제안만 하고 사용자 승인 후 적용한다.

```
[Checkpoint: 인덱스 변경 제안]
- 대상 테이블: {table_name}
- 제안 내용: {CREATE INDEX / DROP INDEX / ALTER 등}
- 사유: {Full Scan 방지, 쿼리 성능 개선 등}
- 예상 영향: {쓰기 성능 저하 가능성, 디스크 사용량 등}
```

#### 쿼리 힌트 금지

`FORCE INDEX`, `USE INDEX`, `STRAIGHT_JOIN` 등 쿼리 힌트는 사용하지 않는다. 힌트가 불가피하다고 판단되면 Checkpoint를 발동하여 사용자에게 보고한다.

### CI4 쿼리빌더 미지원 구문 (Raw Query 필수)

| 기능 | 예시 |
|------|------|
| `WITH` (CTE) | `WITH cte AS (SELECT ...)` |
| Window Functions | `RANK() OVER (...)`, `ROW_NUMBER() OVER (...)` |
| `JSON_TABLE()` | `JSON_TABLE(col, '$.path' COLUMNS(...))` |
| `LATERAL JOIN` | `JOIN LATERAL (SELECT ...)` |

위 기능은 CI4 Query Builder로 빌드할 수 없으므로 `$db->query()`로 직접 작성한다.

### 쿼리 작업 응답 순서

1. 요구사항 분석
2. 쿼리 작성 (MySQL 8.x + ANSI 대안)
3. 실행계획 검증 (`EXPLAIN FORMAT=TREE`)
4. 인덱스 제안 (필요 시 Checkpoint 형식)
5. CI4 코드 (쿼리빌더 또는 raw 쿼리)

### DB 자가 검증 체크리스트

- [ ] `SELECT *` 사용하지 않았는가
- [ ] N+1 패턴이 존재하지 않는가
- [ ] WHERE 절 컬럼에 함수를 적용하지 않았는가
- [ ] MySQL 전용 구문 사용 시 ANSI 대안을 병기했는가
- [ ] `EXPLAIN FORMAT=TREE` 확인 쿼리를 제공했는가
- [ ] Full Scan이 발생하지 않는 쿼리인가
- [ ] 인덱스 변경이 필요한 경우 Checkpoint로 보고했는가
- [ ] 쿼리 힌트를 사용하지 않았는가
- [ ] CTE 사용 시 서브쿼리 대안을 병기했는가

---

## 7. 테스트 규칙

### 원칙

**"No Test, No Merge"** — 모든 수정은 유닛 테스트 또는 실행 로그 증빙 동반.

### 테스트 파일 구조

**Legacy:**
- `tests/Unit/Libraries/{Feature}ServiceTest.php` — 서비스 단위 테스트
- `tests/Feature/{Feature}ApiTest.php` — HTTP 엔드포인트 테스트 (`FeatureTestTrait`)

**New (Modular Monolith):**
- `tests/Modules/{BC}/Unit/{Feature}ServiceTest.php` — 서비스 단위 테스트 (Repository Mock 주입)
- `tests/Modules/{BC}/Feature/{Feature}ApiTest.php` — HTTP 엔드포인트 테스트

### Unit Test 패턴 (Service — Repository Mock 주입)

```php
namespace Tests\Modules\Order;

use App\Modules\Order\Services\OrderService;
use App\Modules\Order\Interfaces\OrderRepositoryInterface;
use CodeIgniter\Test\CIUnitTestCase;

class OrderServiceTest extends CIUnitTestCase
{
    protected OrderService $service;
    protected OrderRepositoryInterface $mockRepo;

    protected function setUp(): void
    {
        parent::setUp();
        $this->mockRepo = $this->createMock(OrderRepositoryInterface::class);
        $this->service  = new OrderService($this->mockRepo);
    }

    public function testGetListReturnsArray(): void
    {
        $this->mockRepo->method('paginate')->willReturn([
            'data' => [],
            'meta' => ['page' => 1, 'perPage' => 20, 'total' => 0, 'lastPage' => 0],
        ]);
        $result = $this->service->getList();
        $this->assertIsArray($result);
        $this->assertArrayHasKey('data', $result);
        $this->assertArrayHasKey('meta', $result);
    }

    public function testGetByIdThrowsWhenNotFound(): void
    {
        $this->mockRepo->method('findById')->willReturn(null);
        $this->expectException(\Exception::class);
        $this->service->getById(999);
    }
}
```

### Feature Test 패턴 (HTTP 엔드포인트)

```php
namespace Tests\Modules\Order;

use CodeIgniter\Test\CIUnitTestCase;
use CodeIgniter\Test\FeatureTestTrait;

class OrderApiTest extends CIUnitTestCase
{
    use FeatureTestTrait;

    public function testIndexReturns200(): void
    {
        $result = $this->get('api/commerce/orders');
        $result->assertStatus(200);
        $result->assertJSONFragment(['status' => 'success']);
    }

    public function testCreateWithValidData(): void
    {
        $result = $this->withBodyFormat('json')
                       ->post('api/commerce/orders', [/* 유효한 데이터 */]);
        $result->assertStatus(201);
        $result->assertJSONFragment(['status' => 'success']);
    }

    public function testCreateFailsWithInvalidData(): void
    {
        $result = $this->withBodyFormat('json')
                       ->post('api/commerce/orders', []);
        $result->assertStatus(400);
    }

    public function testShowNotFound(): void
    {
        $result = $this->get('api/commerce/orders/99999');
        $result->assertStatus(404);
    }
}
```

---

## 8. 보안 & 인증

### 인증 방식

- **JWT 기반 인증**: 토큰 발급/검증은 CI4 백엔드에서 처리
- **API Scope**: Next.js에서 API 호출 시 scope 기반 접근 제어. 토큰에 scope를 포함하여 엔드포인트별 권한 구분
- **클라이언트 저장소**: 사용자 정보 및 통신용 토큰(JWT)은 브라우저에 저장 (cookie 또는 localStorage)

### CSRF 보호

CSRF 토큰 보호 적용. 상태 변경 요청(POST/PUT/DELETE)에 CSRF 검증 필수.

### Nginx 하이브리드 구성

Nginx가 리버스 프록시로 Next.js(SSR)와 CI4(API)를 동시에 서빙.
- API 요청(`/api/*`) → PHP-FPM으로 라우팅
- 나머지 요청 → Next.js로 라우팅

### 코드 보안 규칙

- SQL Injection 방지: QB 사용 또는 named binding
- XSS 방지: 출력 시 이스케이프
- CSRF 방지: 상태 변경 요청에 CSRF 검증
- Mass Assignment 방지: `$allowedFields`를 명시적으로 정의
- `$e->getMessage()`를 API 응답에 그대로 반환 금지 — 안전한 메시지만 반환, 내부 에러는 `log_message()`로 기록

---

## 9. 프로덕션 서버 & CI/CD

### AWS EC2 접속 정보

| 항목 | 값 |
|------|-----|
| 인스턴스 ID | `i-0183f9ab360cc9d80` |
| 인스턴스명 | `prod_ec2_hongcafe_usa` |
| 퍼블릭 IP | `54.198.20.157` |
| OS | Amazon Linux 2023 (aarch64) |
| SSH 포트 | `20010` (기본 22 아님) |
| 접속 방식 | **SSM Session Manager** (SSH PEM 키 인증 불가 — 키 불일치) |
| 보안 그룹 | `launch-wizard-1` (80, 443, 20010), `ec2-rds-1` |

### 서버 구성

| 항목 | 값 |
|------|-----|
| 웹서버 | Nginx 1.28.2 + PHP-FPM 8.5.3 |
| Node.js | v24.14.0 (nvm, `develop` 유저) |
| PM2 | v6.0.14 (`/home/develop/.pm2`) |
| 백엔드 경로 | `/works/hongcafe-global/be/` |
| 프론트엔드 경로 | `/works/hongcafe-global/fe/` |
| Nginx 설정 | `/etc/nginx/conf.d/hongcafe.conf` |
| PHP-FPM 소켓 | `/run/php-fpm/www.sock` |

### 리포지토리

| 항목 | 값 |
|------|-----|
| 호스팅 | Bitbucket |
| 백엔드 | 별도 리포지토리 (PHP/CI4) |
| 프론트엔드 | 별도 리포지토리 (Next.js 16) |

### CI/CD 구성 (Bitbucket Pipelines + SSM)

- **트리거**: production 머지 후 수동 승인 스텝
- **배포 방식**: SSM `send-command`로 EC2 원격 실행 (Atomic Deploy)
- **배포 단위**: Deployment environment별 (리전별 병렬 배포)
- **IAM 유저**: `HC-bitbucket-deploy` (정책: `BitbucketDeploySSM`)
- **Bitbucket 설정**: Repository Settings > Deployments에서 리전별 environment 생성
- **환경별 변수**: `AWS_ACCESS_KEY_ID`(Secured), `AWS_SECRET_ACCESS_KEY`(Secured), `AWS_DEFAULT_REGION`, `INSTANCE_ID`
- **상세 설정 가이드**: `docs/infrastructure.md` 참조

**백엔드 배포 흐름 (Atomic Deploy):**
```
production 머지 → 수동 승인 → SSM 배포
  1. /works/hongcafe-global/releases/be_YYYYMMDDHHMMSS에 fresh clone
  2. composer install + PHPUnit 테스트
  3. 테스트 통과 → .env symlink(config/) → migrate → symlink 프로모션 → cache:clear → php-fpm reload
  4. 테스트 실패 → 릴리즈 삭제, 기존 서비스 유지
  5. 최근 5개 릴리즈만 보관
```

**프론트엔드 배포 흐름:**
```
production 머지 → 수동 승인 → SSM 배포
  git pull → npm ci → npm run build → pm2 restart nextjs
```

### SSM 접속 명령

```bash
# SSM 세션 접속
aws ssm start-session --target i-0183f9ab360cc9d80

# 원격 명령 실행
aws ssm send-command \
  --instance-ids i-0183f9ab360cc9d80 \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["명령어"]}'

# 원격 명령 결과 확인
aws ssm get-command-invocation \
  --command-id "커맨드ID" \
  --instance-id i-0183f9ab360cc9d80
```

### 주의사항

- PEM 키 파일(`~/.claude/skills/aws/ec2-user@54.198.20.157.pem`)은 현재 키 불일치로 SSH 접속 불가. **반드시 SSM 경유**.
- 프로덕션 서버이므로 파일 수정·서비스 재시작 등 변경 작업 시 **반드시 Checkpoint 발동**.

---

## 10. 워크플로우 & 도구 설정

### 세션 초기화 (자동 실행)

작업 세션 시작 시 자동으로 수행:
1. 프로젝트 루트 구조 파악 + 현재 브랜치/커밋 확인
2. `docs/work-history/history.md` 로드 (작업 이력 요약)
3. `.claude/skills/` 스킬 목록 확인, 작업 유형에 맞는 스킬 로드

→ 완료 후 반드시 **"Context Loaded."** 보고

### 워크플로우 프로토콜

멀티스텝 작업 시 항상 다음 순서를 따른다:
1. **Team 1 (Analyze)**: 분석 보고 → 사용자 승인 대기
2. **Team 2 (Plan)**: analyze.md 기반 계획 수립 → 사용자 승인 대기
3. **Team 3 (Execute)**: plan.md 기반 실행 + 검증(Reviewer/Tester)

- 멀티스텝 작업 수신 시 `workflow-enforcer` 체크리스트 자동 적용
- 의존관계 없는 에이전트 spawn은 반드시 병렬 실행
- M/L 등급 작업 시 Team 3 내 검증 필수 수행

### Checkpoint 발동 조건

다음 조건 중 하나라도 해당할 경우 작업을 즉시 중단하고 사용자 승인을 요청한다.

| 조건 | 예시 |
|------|------|
| **비가역적 작업** | 파일 삭제, DB 스키마 변경, 마이그레이션 실행 |
| **광범위한 영향 범위** | 3개 이상의 파일에 걸친 아키텍처 변경 |
| **요구사항 상충** | 성능 vs 가독성, 보안 vs 편의성 등 트레이드오프 발생 |
| **외부 시스템 연동** | 외부 API 호출, 환경변수 변경, 서드파티 설정 수정 |
| **권한 외 파일 접근** | `.env`, 설정 파일, 허가되지 않은 디렉토리 접근 시도 |
| **프로덕션 서버 변경** | 파일 수정, 서비스 재시작 등 |

단순 오타·주석은 Checkpoint 없이 진행 가능. 불확실하면 Checkpoint 발동.

### Guardrails

- **Proactive Correction**: 오타(철자)만 즉시 수정 가능. 문법·컨벤션·로직 수정은 Team 1 분석 후 승인 필요.
- **Readability**: 주석 없이 읽히는 명시적 코드. 전체 단어 사용.
- **No Test, No Merge**: 모든 수정은 유닛 테스트 또는 실행 로그 증빙 동반.
- **Persistence (필수)**: 모든 작업 완료 시 `docs/work-history/history.md`에 `YYYY.MM.DD` 항목으로 처리 내역을 기록. 누락은 지침 위반.

### 파일 경로 규칙

- **글로벌 설정**: `~/.claude/` (`C:\Users\PV\.claude\`)
- **글로벌 스킬**: `~/.claude/skills/{skill-name}/SKILL.md`
- **프로젝트 로컬 스킬**: `./.claude/skills/{skill-name}/SKILL.md`
- 스킬 파일 생성/수정 시 반드시 대상 경로(글로벌 vs 프로젝트 로컬)를 사용자에게 확인 후 작업

### docs/output 동기화 규칙

글로벌 지침(`~/.claude/CLAUDE.md`), 프로젝트 지침(`./CLAUDE.md`), 또는 스킬 파일(`~/.claude/skills/`)을 수정할 때 `docs/output/instructions-and-skills/` 내 해당 요약 문서도 함께 갱신한다.

### Notion 문서 동기화

이 프로젝트의 통합 문서는 Notion **"홍카페_글로벌_백엔드"** 페이지에서 관리한다.

- **메인 페이지**: 홍카페_글로벌_백엔드 — 프로젝트 주요 정보 요약
- **하위 페이지**: Architecture & Conventions / API Response Standard / Production Server / Common Commands / API Specification

**동기화 절차**: `notion-fetch`로 현재 내용 다운로드 → 갱신 내용 작성 → `replace_content`로 전체 덮어쓰기 (부분 패치 금지)

프로젝트 문서 수정 후 Notion 업데이트를 누락하는 것은 지침 위반이다.

### git commit 규칙

- git commit 메시지에 Co-Authored-By 라인 포함 금지

---

## 부록: 자가 검증 체크리스트

### New 모드 전체 체크리스트

#### 아키텍처
- [ ] 모듈 구조(`app/Modules/{BC}/`)로 파일이 배치되었는가
- [ ] Controller → Service → Repository 레이어 모두 존재
- [ ] Controller에 비즈니스 로직 없음
- [ ] Service에 HTTP/응답 로직 없음, DB 직접 접근 없음
- [ ] Repository에서만 DB 접근
- [ ] Model은 Repository에서만 사용

#### Entity/VO
- [ ] 도메인 규칙이 있는 경우 Entity/VO가 생성되었는가
- [ ] Entity/VO에 외부 의존성(DB, HTTP, Framework)이 없는가
- [ ] VO는 불변(`readonly`)이고 자체 유효성 검증이 있는가
- [ ] 공유 VO는 `Modules/Shared/ValueObjects/`에 배치했는가

#### 모듈 경계
- [ ] 모듈 간 직접 클래스 참조 없음 (Interface만 사용)
- [ ] 공개 Interface가 `Interfaces/`에 정의되었는가
- [ ] 공통 리소스(2+ 모듈 참조)는 `Modules/Shared/`에 배치했는가

#### DI
- [ ] `service()` 함수로 의존성을 주입받는가
- [ ] `new Service()`, `new Repository()`, `new Model()` 직접 호출이 없는가
- [ ] 모듈별 `Config/Services.php`에 바인딩이 등록되었는가

#### 데이터 접근
- [ ] Query Builder를 우선 사용했는가
- [ ] raw query 사용 시: Repository에서만 + named binding + 사유 주석이 있는가
- [ ] `SELECT *` 사용하지 않았는가
- [ ] N+1 패턴이 존재하지 않는가
- [ ] WHERE 절 컬럼에 함수를 적용하지 않았는가

#### 기타
- [ ] Controller의 catch에서 안전한 메시지만 반환하는가
- [ ] Unit 테스트 + Feature 테스트 모두 포함
- [ ] 모듈 Routes.php 제공
- [ ] API 명세서(`api-docs/{module}/{apiname}.md` + `.yaml`) 생성되었는가
- [ ] PSR-12 코딩 스타일 준수
- [ ] 보안 검증 통과 (SQL Injection, XSS, CSRF, Mass Assignment)
- [ ] 에러 응답이 표준 에러 코드 체계를 따르는가
- [ ] `docs/work-history/history.md` 작업 이력 기록되었는가

### Legacy 모드 체크리스트
- [ ] 기존 파일의 네이밍/DI/디렉토리 패턴을 유지했는가
- [ ] 변경으로 인한 사이드 이펙트를 확인했는가
- [ ] PSR-12 코딩 스타일 준수
- [ ] 보안 검증 통과
- [ ] 테스트 코드 갱신 (있는 경우)

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-06 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
