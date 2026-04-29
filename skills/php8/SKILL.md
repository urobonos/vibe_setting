---
name: php8
description: >
  PHP 8.4+ / CI 4.7+ Mono-repo Modular Monolith API 스킬.
  아키텍처: Modular Monolith. 레거시 코드(app/Libraries/ 등)는 마이그레이션 완료까지 유지.
  레이어: Controller → Service → Repository → Model + Entity/VO.
  모듈 간 직접 클래스 참조 금지(Interface 통신만), service() DI 강제,
  CI 4.7 Service Discovery 활용. QB 우선, raw query는 Repository에서만 named binding.
  신규 모듈은 부분 구현 절대 금지 — 9가지 산출물이 항상 함께 생성되어야 한다.
triggers:
  - "API 만들어줘", "엔드포인트 추가", "CRUD 만들어줘"
  - "CI4 컨트롤러 만들어줘", "PHP 모델 만들어줘", "서비스 만들어줘"
  - app/Modules/ 하위 PHP 파일 생성/수정 시
  - app/Libraries/, app/Controllers/Api/, app/Models/ 하위 PHP 파일 수정 시 (Legacy 모드)
version: 3.1.0
user-invocable: true
depends_on: [mysql8, security-audit]
conflicts_with: []
min_claude_md_version: "4.0"
---

# PHP 8.4+ / CI 4.7+ Modular Monolith API Architect Skill

Mono-repo + **Modular Monolith** 아키텍처. 레거시 코드는 마이그레이션 완료까지 유지하되, 신규 개발은 모듈 구조 강제.

---

## 듀얼 모드 판별

| 구분 | **Legacy** | **New (Modular Monolith)** |
|------|-----------|---------------------------|
| **적용 대상** | 기존 코드 수정 / 버그픽스 | 새 기능, 새 도메인 |
| **경로** | `app/Controllers/Api/`, `app/Libraries/`, `app/Models/` | `app/Modules/{BC}/` |
| **레이어** | Controller → Library/Service → Model (Repository 겸임) | Controller → Service → Repository → Model + Entity/VO |
| **DI** | `new Service()` 또는 기존 방식 허용 | `service()` 함수 강제 |
| **모듈 간 통신** | 직접 참조 허용 | **Interface Only** |
| **DB 접근** | Model에서 직접 | Repository에서 QB 우선 |

### 판별 기준
- `app/Libraries/`, `app/Models/`, `app/Controllers/Api/` 수정 → **Legacy 모드** 적용
- `app/Modules/` 하위 신규 생성/수정 → **New 모드** 적용
- 새 도메인(기존에 없던 기능) 개발 요청 → **New 모드**로 `app/Modules/{BC}/` 생성

---

## Legacy 모드 (기존 코드 유지)

기존 코드는 CI4 기본 플랫 MVC 구조를 유지한다. 레이어 구조를 강제로 변경하지 않는다.

| 레이어 | 경로 | 역할 |
|--------|------|------|
| **Controller** | `app/Controllers/Api/` | HTTP 처리, 입력 검증 |
| **Library/Service** | `app/Libraries/` | 비즈니스 로직 |
| **Model** | `app/Models/` | DB CRUD (Repository 겸임) |

**Legacy 수정 시 규칙:**
- 기존 패턴(네이밍, DI 방식, 디렉토리 위치)을 따른다
- 새 파일 추가가 아닌 기존 파일 수정일 경우, 해당 파일의 기존 스타일을 유지한다
- PSR-12, 보안 규칙, 주석 규칙은 Legacy에도 동일하게 적용

---

## 아키텍처 원칙 (New 모드)

| 원칙 | 설명 |
|------|------|
| **Mono-repo** | 단일 저장소에 모든 모듈(Bounded Context)을 포함 |
| **Modular Monolith** | 배포는 단일 애플리케이션, 내부는 모듈 경계로 분리 |
| **레이어 강제** | Controller → Service → Repository. 레이어 건너뛰기 금지 |
| **모듈 경계** | 모듈 간 직접 클래스 참조 금지. **Interface로만 통신** |
| **DI 강제** | `service()` 함수 사용. `new Service()`, `new Model()` 직접 호출 금지 |
| **Query Builder 우선** | QB 사용이 기본. CTE/Window Function 등 미지원 구문만 `$db->query()` + named binding 허용 (Repository에서만) |

### 레이어별 책임 / 금지

| 레이어 | 책임 | 금지 |
|--------|------|------|
| **Controller** | Request 파싱, 입력 검증, 응답 반환 | DB 접근, 비즈니스 로직 |
| **Service** | 비즈니스 로직, 트랜잭션 관리 | 직접 `$this->response` 반환, DB 직접 접근 |
| **Repository** | Query Builder 쿼리, 데이터 접근 전담 | 비즈니스 판단, 응답 포맷팅 |
| **Entity/VO** | 도메인 규칙, 유효성 검증 | 외부 의존성 (DB, HTTP, Framework) |
| **Model** | 테이블 매핑, 필드 정의, 모델 레벨 검증 | 비즈니스 로직 (Repository에서만 사용) |

---

## 모듈 디렉토리 구조

각 모듈은 하나의 **Bounded Context(BC)** 를 담당한다.

```
app/
├── Controllers/Api/          ← Legacy (기존 유지)
│   └── Traits/
├── Libraries/                ← Legacy (Service 역할)
├── Models/                   ← Legacy (Repository 겸임)
│
├── Modules/                  ← New (글로벌 신규 개발)
│   ├── Order/                          ← BC: 주문
│   │   ├── Controllers/OrderController.php
│   │   ├── Services/OrderService.php
│   │   ├── Repositories/OrderRepository.php
│   │   ├── Models/OrderModel.php
│   │   ├── Entities/Order.php          ← Domain Object. 순수 PHP 클래스
│   │   ├── ValueObjects/Money.php      ← Immutable 값 객체 (선택)
│   │   ├── Interfaces/                ← 외부 노출 계약
│   │   │   ├── OrderServiceInterface.php
│   │   │   └── OrderRepositoryInterface.php
│   │   ├── Exceptions/                ← 모듈 전용 예외
│   │   └── Config/
│   │       ├── Routes.php
│   │       └── Services.php            ← CI 4.7 자동 발견
│   ├── Menu/                           ← BC: 메뉴
│   │   ├── Controllers/
│   │   ├── Services/
│   │   ├── Repositories/
│   │   ├── Models/
│   │   ├── Interfaces/
│   │   ├── Exceptions/
│   │   └── Config/
│   └── Shared/                         ← 공유 (2+ 모듈 공통)
│       ├── Models/
│       ├── Entities/
│       ├── ValueObjects/               ← Money, Email, Address 등
│       └── Interfaces/
│
├── Config/
│   ├── Autoload.php                    ← PSR-4 네임스페이스 매핑
│   ├── Routes.php                      ← 모듈 라우트 자동 로드
│   └── Services.php                    ← Legacy DI (기존 유지)
├── Database/
│   ├── Migrations/
│   └── Seeds/
├── Filters/
├── Helpers/
└── ThirdParty/
```

### 네임스페이스 매핑

`app/Config/Autoload.php`의 `$psr4`에 **BC별 개별 등록**한다 (CI4 auto-discovery 필수):

```php
public $psr4 = [
    APP_NAMESPACE                => APPPATH,
    'App\\Modules\\Order'        => APPPATH . 'Modules/Order',
    'App\\Modules\\Menu'         => APPPATH . 'Modules/Menu',
    // ... BC별 추가
];
```

각 모듈 네임스페이스 형태:
- `App\Modules\Order\Controllers`
- `App\Modules\Order\Services`
- `App\Modules\Order\Repositories`
- `App\Modules\Order\Models`
- `App\Modules\Order\Entities`
- `App\Modules\Order\ValueObjects`
- `App\Modules\Order\Interfaces`
- `App\Modules\Order\Exceptions`

---

## 모듈 경계 규칙

### 모듈 간 통신: Interface Only

```
┌─────────────┐         Interface         ┌─────────────┐
│  Order 모듈  │ ──── OrderServiceIF ────▶ │  Payment 모듈│
│             │ ◀── PaymentServiceIF ──── │             │
└─────────────┘                           └─────────────┘
```

**금지:**
```php
// ✗ 다른 모듈의 구체 클래스를 직접 참조
use App\Modules\Payment\Services\PaymentService;
```

**허용:**
```php
// ✓ 다른 모듈의 Interface를 참조
use App\Modules\Payment\Interfaces\PaymentServiceInterface;
```

### 모듈 공개 API

각 모듈은 `Interfaces/` 디렉토리에 **다른 모듈이 참조할 수 있는 Interface만** 공개한다.
모듈 내부 클래스(Service 구체 클래스, Repository, Model)는 외부에서 직접 참조할 수 없다.

### Shared 모듈

2개 이상 모듈에서 공통으로 필요한 Model/Interface는 `Modules/Shared/`에 배치한다.
전용 모델이 2번째 모듈에서 참조되는 시점에 `Shared/`로 이동을 제안한다.

---

## 의존성 주입 (DI)

### CI 4.7 Service Discovery

CI 4.7.0+에서는 모듈별 `Config/Services.php`가 **자동 발견**된다.
메인 `app/Config/Services.php`에 수동 등록할 필요 없다.

### 모듈별 DI 등록 (`Modules/{BC}/Config/Services.php`)

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

### DI 사용 규칙

| 규칙 | 설명 |
|------|------|
| **`service()` 함수 필수** | `service('orderService')`로 인스턴스를 가져온다 |
| **`new` 직접 호출 금지** | Controller/Service에서 `new Service()`, `new Repository()`, `new Model()` 금지 |
| **Controller → Service** | Controller 생성자에서 `service()`로 Service를 주입받는다 |
| **Service → Repository** | Service 생성자에서 `service()`로 Repository를 주입받는다 |
| **Repository → Model** | Repository 생성자에서 `model()` 헬퍼로 Model을 주입받는다 |
| **모듈 간 의존** | `service()`로 상대 모듈의 Interface 타입을 받는다 |
| **getShared 패턴** | 기본 싱글턴(`true`), 테스트 시 `false`로 새 인스턴스 |

---

## 의존성 관리

- **Composer 버전**: 2.x
- **버전 고정 정책**: exact 또는 caret(`^`) 사용. `composer.lock` 파일 반드시 커밋
- **PSR-4 Autoload**: `App\` 단일 루트 매핑으로 `app/` 하위 전체 자동 해석

## 미적용 DDD 요소

아래 DDD 요소는 현재 프로젝트에서 **의도적으로 미적용**:

| 요소 | 미적용 사유 |
|------|-----------|
| Aggregate Root | CI4 Model/Entity 구조에서 Aggregate 경계 강제가 과도한 복잡성 유발 |
| CQRS | 단일 DB(Aurora MySQL) 사용, 읽기/쓰기 분리 불필요 |
| Event Sourcing | 이벤트 저장소 인프라 미구축, 현 규모에서 오버엔지니어링 |
| Domain Event Bus | 모듈 간 통신은 Interface 기반 동기 호출로 충분. 비동기 필요 시 SNS/SQS 사용 |

---

## PHP / CI4 코딩 표준

### 1. PSR 준수

- **PSR-1**: `<?php` 태그, UTF-8(BOM 없음), 오토로딩 표준
- **PSR-4**: 네임스페이스 = 디렉토리 구조. `Modules\{BC}\{Layer}`
- **PSR-12**: 인덴트 **4칸 스페이스**, 여는 중괄호 같은 줄(메서드/클래스는 다음 줄)
- **Strict Types**: 모든 PHP 파일에 `declare(strict_types=1);` 선언 필수
- **mixed 반환 타입 금지**: 함수/메서드 반환 타입에 `mixed` 사용 금지. 구체적 타입(`string`, `int`, `array`, `?Type` 등)을 명시

```php
<?php

declare(strict_types=1);

namespace App\Modules\Commerce\Services;
```

> `declare(strict_types=1)`은 `<?php` 바로 다음, namespace 선언 전에 위치한다.
> 해당 파일 내에서 호출하는 함수의 파라미터/반환값에 대해 자동 타입 캐스팅을 차단한다.

#### 파일명 규칙

| 대상 | 스타일 | 예시 |
|------|------|------|
| 클래스 파일 | `PascalCase.php` | `CallService.php`, `CounselorRepository.php` |
| CI4 설정 파일 | `PascalCase.php` (프레임워크 표준) | `Routes.php`, `Services.php`, `Filters.php` |
| 국가별 Config | `lowercase.php` | `jp.php`, `us.php`, `kr.php` |
| 언어 파일 | `lowercase.php` | `messages.php`, `validation.php` |
| 테스트 파일 | `{TargetClass}Test.php` | `CallServiceTest.php` |

- 국가 Config 파일명은 **lowercase** — CI4 Config 로더가 대소문자 구분 환경(Linux)에서도 일관 동작 보장
- 클래스 파일명 = 클래스명. PSR-4 autoload 준수

### 2. 추상화 / 구체화 범위

인터페이스는 해당 모듈의 `Interfaces/` 디렉토리에 배치한다.

#### 추상화 필수 (Interface 선행)

| 조건 | 예시 |
|------|------|
| **다른 모듈에서 참조하는 Service** | 모든 공개 Service (모듈 경계 규칙) |
| 2개 이상 구현체가 예상되는 경우 | 결제 수단별 PaymentService |
| 외부 시스템 연동 | SMS, 이메일, 결제 게이트웨이 |
| Repository | 모든 Repository는 Interface 필수 |

#### 구체화 허용

| 조건 | 예시 |
|------|------|
| 모듈 내부에서만 사용하는 단일 구현 Service | 단순 내부 헬퍼 |
| 유틸리티/헬퍼 성격 | 날짜 포맷터, 문자열 처리 |

추상화 시 인터페이스 상단에 **추상화 사유 주석 필수**.

### 3. 보안 검증 필수

모든 코드는 `security-audit` 스킬의 보안 규칙을 준수. SQL Injection, XSS, CSRF, Mass Assignment 등.

### 4. 사이드 이펙트 방지

파일 수정 전 모듈 내부 및 모듈 간 영향 범위를 확인한다.

- **Repository 변경 시**: 해당 Repository를 사용하는 Service 확인
- **Service 변경 시**: Controller + 다른 모듈에서 Interface로 참조하는 곳 확인
- **Model 변경 시**: Repository → Service → Controller 전체 확인
- **Interface 변경 시**: 해당 Interface를 참조하는 **모든 모듈** 확인 (가장 위험)
- **Migration 변경 시**: Model `$allowedFields`, `$validationRules` 동기화

### 5. 주석 규칙

#### PHPDoc 표준 양식

```php
/**
 * 목적 한 줄 설명. (한국어, 동사형 `~한다`)
 *
 * @param  string      $token       파라미터 설명
 * @param  int         $expSeconds  파라미터 설명
 * @return array|null  반환값 설명
 * @throws \RuntimeException 예외 조건
 */
```

#### 대상별 규칙

| 대상 | 필수 여부 | 주석 내용 |
|------|-----------|-----------|
| **클래스** | 필수 | 클래스명 + 역할 설명 (여러 줄 허용) |
| **public/protected 메서드** | 필수 | 목적 한 줄 + `@param` + `@return` + `@throws` |
| **private 메서드** | 필수 | 목적 한 줄 + `@param` + `@return` |
| **Interface** | 필수 | 추상화 사유 + 메서드별 `@param`/`@return` |
| **복잡한 비즈니스 로직** | 필수 | 단계별 인라인 설명 |
| **raw query** | 필수 | QB로 불가능한 사유 명시 |

#### 작성 규칙

- 첫 줄: 목적 한 줄 (한국어, `~한다` 종결)
- 빈 줄: 설명과 태그 사이 1줄
- `@param`: 타입 + 변수명 + 설명 (타입 정렬)
- `@return`: 타입 + 설명 (void 생략 가능)
- `@throws`: 예외 클래스 + 발생 조건
- 제네릭 반환: `@return array{key: type}` 형태로 구조 명시

### 6. 날짜/시간 처리

- `date()`, `time()` **사용 금지**. `DateTimeImmutable` 필수.
- 타임스탬프 필요 시 `(new DateTimeImmutable())->getTimestamp()` 사용
- DB/서버 타임존: UTC 통일

```php
// 금지
$now = date('Y-m-d H:i:s');
$timestamp = time();

// 올바른 사용
$now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
$timestamp = $now->getTimestamp();
$formatted = $now->format('Y-m-d H:i:s');
```

---

## 핵심 규칙

### New 모드 산출물

새 API 엔드포인트나 기능 요청 시 아래 **9가지를 반드시 동시에 생성**한다:

1. **Controller** (`Modules/{BC}/Controllers/`)
2. **Service + Interface** (`Modules/{BC}/Services/`, `Modules/{BC}/Interfaces/`)
3. **Repository + Interface** (`Modules/{BC}/Repositories/`, `Modules/{BC}/Interfaces/`)
4. **Model** (`Modules/{BC}/Models/`)
5. **Entity/VO** (`Modules/{BC}/Entities/`, `Modules/{BC}/ValueObjects/`) — 도메인 규칙이 필요한 경우
6. **모듈 DI 등록** (`Modules/{BC}/Config/Services.php`)
7. **PHPUnit 테스트** (Unit + Feature)
8. **모듈 Routes** (`Modules/{BC}/Config/Routes.php`)
9. **API 명세서** (`api-docs/{module}/{apiname}.md`)

부분 구현은 허용되지 않는다. (Entity/VO는 도메인 규칙이 단순 CRUD 수준이면 생략 가능)

### Legacy 모드 산출물

기존 코드 수정 시 기존 패턴을 따르되, 최소한 아래를 확인한다:
- 수정된 Controller/Library/Model의 사이드 이펙트 확인
- 테스트 코드 갱신 (있는 경우)
- PSR-12, 보안 규칙 준수

---

## 아키텍처 레이어

> **상세 코드 템플릿:** 각 레이어(Controller/Service/Repository/Entity) 의 풀 코드 예시는 `references/layer-templates.md` 참조.

---

## 검증 표준

Controller에서 1차 검증, Model 검증은 2차 안전망:

| 필드 유형 | 검증 규칙 |
|-----------|-----------|
| 필수 문자열 | `required\|min_length[2]\|max_length[100]` |
| 이메일 | `required\|valid_email` |
| 양의 정수 | `required\|integer\|greater_than[0]` |
| 열거형 | `required\|in_list[active,inactive]` |
| 선택적 필드 | `permit_empty\|...` |

---

## 테스트 코드

### 테스트 디렉토리 구조

```
tests/
├── Unit/
│   └── Modules/
│       ├── Order/
│       │   └── OrderServiceTest.php
│       └── Auth/
│           └── AuthServiceTest.php
├── Feature/
│   └── Modules/
│       ├── Order/
│       │   └── OrderApiTest.php
│       └── Auth/
│           └── AuthApiTest.php
└── _support/
```

- **타입별(Unit/Feature) 1차 분류**, 모듈별 2차 분류
- 네임스페이스: `Tests\Unit\Modules\{BC}\`, `Tests\Feature\Modules\{BC}\`

### Unit Test (Service 검증 — Repository Mock 주입)
```php
namespace Tests\Unit\Modules\Order;

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
        $this->service = new OrderService($this->mockRepo);
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

### Feature Test (HTTP 엔드포인트 검증)
```php
namespace Tests\Feature\Modules\Order;

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

## 모듈 Routes 설정

### API URL 규격

```
/{module}/{resource}
```

| 모듈 | URL 예시 | 설명 |
|------|----------|------|
| Call | `/phone-consult/calls` | 전화 상담 |
| Commerce | `/commerce/payments` | 결제 |
| Member | `/member/profile` | 회원 프로필 |

- **API 버전 prefix 금지**: URL에 `/v1/`, `/v2/` 등 버전 prefix 사용 금지 (폐기 확정)
- **module**: BC명의 kebab-case (비즈니스 도메인 표현)
- **resource**: 복수형 snake_case 또는 단수형 (리소스 성격에 따라)
- BC 디렉토리명과 URL module명은 다를 수 있다 (예: `Call` BC → `/phone-consult/`)

### 모듈 라우트 (`Modules/{BC}/Config/Routes.php`)
```php
// Modules/Order/Config/Routes.php
$routes->group('api/commerce', ['namespace' => 'App\Modules\Order\Controllers'], function ($routes) {
    $routes->resource('orders', ['controller' => 'OrderController']);
});
// → /api/commerce/orders
```

### 메인 Routes에서 모듈 자동 로드 (`app/Config/Routes.php`)
```php
$moduleRoutes = glob(APPPATH . 'Modules/*/Config/Routes.php');
foreach ($moduleRoutes as $routeFile) {
    require $routeFile;
}
```

---

## Filter 패턴 + 인증/인가 구현

요청 처리 파이프라인은 다음 Filter 체인을 순차 적용한다. **정책/알고리즘/TTL 등 규격은 `security-audit` §7-2(CORS 정책)/§7-3(Cookie 보안)/§7-4(CSRF + JWT 인증 정책, JWT 저장 7-1 포함)/§7-6(암호화 규격)/§7-9(SecureHeaders 필터)/§7-10(외부 노출 API 보안 Phase 2) 를 SSOT** 로 따르고, **쿠키명·면제 EP 등 프로젝트 고유값은 프로젝트 `CLAUDE.md`** 를 참조한다. 본 섹션은 **코드 구현 패턴**만 다룬다.

### Filter 체인 순서 (고정)

```
Request
  ↓
[ratelimit] → [csrftoken] → [auth] → [role:{name}] (해당 EP) → [CountryResolver] → Controller
  ↓                                                                                 ↓
Response  ← [SecureHeaders] ← ─────────────────────── Controller ← Service ← Repository ← DB
```

| # | Filter | 역할 | 등록 |
|---|--------|------|------|
| 1 | `ratelimit` | IP/사용자별 rate limit | globals `before` |
| 2 | `csrftoken` (`CsrfTokenFilter`) | CSRF 토큰 검증 — POST/PUT/PATCH/DELETE 만 | globals `before` |
| 3 | `auth` (`AuthFilter`) | JWT 쿠키 → API Key → Session(레거시) 우선순위 | globals `before` |
| 4 | `role:{name}` (`RoleFilter`) | RBAC Layer 1 — 역할 차단 | 라우트 단위 `before` |
| 5 | `CountryResolverFilter` | 국가 컨텍스트 해석 (`X-Country-Code` 주입) | globals `before` |
| 6 | `SecureHeadersFilter` | 응답 보안 헤더 주입 | globals `after` |

`app/Config/Filters.php` 에 globals 등록. 모듈별 라우트에는 `['filter' => 'role:{name}']` 개별 지정.

### CsrfTokenFilter 구현 패턴

CI4 내장 CSRF 필터는 **사용하지 않는다** (stateless JWT 아키텍처와 불일치). Signed Double Submit Cookie (HMAC-SHA256) 방식으로 커스텀 구현.

```php
<?php

declare(strict_types=1);

namespace App\Filters;

use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;

class CsrfTokenFilter implements FilterInterface
{
    private const STATE_CHANGING_METHODS = ['POST', 'PUT', 'PATCH', 'DELETE'];

    public function before(RequestInterface $request, $arguments = null)
    {
        if (! in_array($request->getMethod(true), self::STATE_CHANGING_METHODS, true)) {
            return null;
        }

        if ($this->isApiKeyAuthenticated($request)) {
            return null;
        }

        $cookieToken = $request->getCookie(config('App')->cookiePrefix . 'csrf');
        $headerToken = $request->getHeaderLine('X-CSRF-TOKEN');

        if ($cookieToken === '' || $headerToken === '' || ! hash_equals($cookieToken, $headerToken)) {
            return service('response')
                ->setStatusCode(403)
                ->setJSON(['error' => ['code' => 'FORBIDDEN', 'message' => lang('Auth.csrfMismatch')]]);
        }

        if (! service('csrfTokenService')->verify($cookieToken)) {
            return service('response')
                ->setStatusCode(403)
                ->setJSON(['error' => ['code' => 'FORBIDDEN', 'message' => lang('Auth.csrfInvalid')]]);
        }

        return null;
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
    }

    private function isApiKeyAuthenticated(RequestInterface $request): bool
    {
        return $request->getHeaderLine('X-Api-Key') !== '';
    }
}
```

**규칙**:
- HMAC 서명 생성·검증은 `CsrfTokenService` 에 위임 — Filter 는 오케스트레이션만
- 쿠키 ↔ 헤더 비교에는 **반드시 `hash_equals()`** — 타이밍 공격 방어
- API Key 인증 요청(서버-서버)은 CSRF 면제
- 면제 EP 경로는 `AuthFilter::EXCLUDED_PATHS` 와 별도 목록 관리 — `CsrfTokenFilter::EXCLUDED_PATHS` 권장

### AuthFilter (JWT 쿠키 검증)

```php
<?php

declare(strict_types=1);

namespace App\Filters;

use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;

class AuthFilter implements FilterInterface
{
    public const EXCLUDED_PATHS = [
        'api/auth/login',
        'api/auth/refresh',
        // 프로젝트별 공개 EP 는 프로젝트 CLAUDE.md 참조
    ];

    public function before(RequestInterface $request, $arguments = null)
    {
        if ($this->isExcluded($request)) {
            return null;
        }

        $identity = service('authService')->resolveIdentity($request);

        if ($identity === null) {
            return service('response')
                ->setStatusCode(401)
                ->setJSON(['error' => ['code' => 'UNAUTHORIZED', 'message' => lang('Auth.unauthorized')]]);
        }

        $request->setAttribute('identity', $identity);
        return null;
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
    }

    private function isExcluded(RequestInterface $request): bool
    {
        $uri = trim($request->getUri()->getPath(), '/');
        foreach (self::EXCLUDED_PATHS as $path) {
            if ($uri === $path) {
                return true;
            }
        }
        return false;
    }
}
```

**인증 우선순위** (`AuthService::resolveIdentity` 내부):
1. JWT 쿠키 (프로젝트 지정 쿠키명, 예: `{prefix}_access`)
2. API Key (`X-Api-Key` 헤더)
3. Session (레거시 호환 — 신규 EP 사용 금지)

**금지**: `Authorization: Bearer` 헤더 폴백 — XSS 시 토큰 탈취 위험

### RoleFilter (RBAC Layer 1)

```php
<?php

declare(strict_types=1);

namespace App\Filters;

use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;

class RoleFilter implements FilterInterface
{
    public function before(RequestInterface $request, $arguments = null)
    {
        $requiredRole = $arguments[0] ?? null;
        $identity = $request->getAttribute('identity');

        if ($identity === null || ! $identity->hasRole($requiredRole)) {
            return service('response')
                ->setStatusCode(403)
                ->setJSON(['error' => ['code' => 'FORBIDDEN', 'message' => lang('Auth.insufficientRole')]]);
        }

        return null;
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
    }
}
```

라우트 적용:

```php
$routes->group('api/callees', ['filter' => 'role:callee'], static function ($routes) {
    $routes->get('profile', 'CalleeController::profile');
});
```

**RBAC 3계층 Defense in Depth** (OWASP API5:2023):

| Layer | 위치 | 역할 |
|------|------|------|
| 1 | `RoleFilter:{name}` — 라우트 필터 | 역할 자체 차단 |
| 2 | Controller `checkNeedLogin(true)` 또는 소유권 검증 | 이중 검증 |
| 3 | Repository 쿼리 `WHERE owner_id = :currentUserId:` | 데이터 레벨 소유권 강제 |

단일 Layer 신뢰 금지 — Filter 를 우회하는 경로(예: 내부 Service 호출)가 있어도 Repository 쿼리가 마지막 안전장치.

### JWT 발급/검증 패턴

- **알고리즘**: HMAC-SHA256 — 외부 라이브러리 없이 순수 PHP 구현 권장
- **Access Token**: 짧은 만료(15분 권장). Payload 최소 필드: 사용자 식별자, 역할, `iat`, `exp`
- **Refresh Token**: 별도 HttpOnly 쿠키. `jti` + `family` 필드로 **Token Rotation + Reuse Detection**
- **Reuse Detection**: 사용 완료된 `jti` 재제출 시 `family` 전체 무효화 — 세션 탈취 방어
- **구현 위치**: `AuthService`, `JwtService` 등 Service 레이어. Controller 에서 토큰 조작 금지

### Cookie 발급 규격

`Response::setCookie()` / `setcookie()` 호출 시 다음 속성을 **강제**한다.

| 속성 | 값 | 사유 |
|------|------|------|
| `httponly` | `true` | XSS 방어 (`document.cookie` 접근 차단) |
| `samesite` | `Lax` | CSRF 보조 방어 (`security-audit` §7-3) |
| `secure` | `true` (prod) / `ENVIRONMENT` 분기 | HTTPS 전송 강제 |
| `prefix` | 프로젝트 지정 | 쿠키명 충돌 방지 |

- 기본값은 `app/Config/Cookie.php` 에 등록. 호출처에서 속성을 개별 전달하지 않도록 래퍼 유틸리티 사용 권장
- `samesite=None` **사용 금지** — 크로스사이트 허용으로 CSRF 취약

### 참조

- 정책·알고리즘·TTL 규격: `security-audit` §7-2(CORS 정책)/§7-3(Cookie 보안)/§7-4(CSRF + JWT 인증 정책, JWT 저장 7-1 포함)/§7-6(암호화 규격)/§7-9(SecureHeaders 필터)/§7-10(외부 노출 API 보안 Phase 2)
- 쿠키명·면제 EP 경로 등 프로젝트 고유값: 프로젝트 `CLAUDE.md`
- 국가 컨텍스트 Filter: `global-context` §2 Country Resolver

---

## API 명세서 (API Docs)

> **API 명세 templates:** API Markdown 명세 작성 템플릿은 `references/api-docs-template.md` 참조. 본문 작성 시 그대로 따른다.

---

## API 응답 표준

### 원칙
- **HTTP 상태코드가 성공/실패의 SSOT** (Google API Design Guide, RFC 7231)
- CI4 ResponseTrait의 `respond()`, `failNotFound()` 등이 HTTP 코드를 자동 설정
- body 내 `status` 필드는 프론트엔드 편의를 위해 유지하되, HTTP 코드와 항상 일치
- **응답 키 네이밍**: DB `snake_case` → API 응답 `camelCase` 변환 필수 (`created_at` → `createdAt`, `ac_nick` → `acNick`)

### 에러 코드 (현상 서술형, suffix 없음)

| 에러 코드 | HTTP | 설명 |
|-----------|------|------|
| INVALID_INPUT | 400 | 입력값 유효성 검증 실패 |
| UNAUTHORIZED | 401 | 인증 실패 |
| FORBIDDEN | 403 | 권한 없음 |
| NOT_FOUND | 404 | 리소스를 찾을 수 없음 |
| CONFLICT | 409 | 중복/충돌 |
| INTERNAL | 500 | 서버 내부 오류 |

> 업계 표준(Google Cloud `INVALID_ARGUMENT`, Stripe `card_declined` 등) 참조.
> `_ERROR`/`_FAILED` suffix 대신 현상 서술형 코드 사용.

### 페이지네이션 메타 키

```json
{
  "data": [],
  "meta": {
    "currentPage": 1,
    "perPage": 20,
    "total": 0,
    "lastPage": 1
  }
}
```

- camelCase 통일 (`currentPage`, `perPage`, `lastPage`)
- CI4 Pager 라이브러리는 JSON 키를 정의하지 않으므로 프로젝트 표준으로 확정

### Swagger OpenAPI YAML

> **Swagger 스펙 template:** OpenAPI/Swagger YAML 템플릿은 `references/swagger-template.md` 참조.

---

## 출력 형식

### New 모드 출력 순서

1. **API 설계 요약** — 모듈명(BC), 구현 내용 간략 설명
2. **Controller** — 전체 코드 + 파일 경로
3. **Service + Interface** — 전체 코드 + 파일 경로
4. **Repository + Interface** — 전체 코드 + 파일 경로
5. **Model** — 전체 코드 + 파일 경로
6. **Entity/VO** — 도메인 규칙이 있는 경우 (단순 CRUD는 생략 가능)
7. **모듈 DI 등록** (`Modules/{BC}/Config/Services.php`)
8. **테스트 코드** — Unit + Feature + 파일 경로
9. **모듈 Routes** — 라우트 파일 + 메인 로드 확인
10. **API 명세서** — `api-docs/{module}/{apiname}.md` 생성
11. **Swagger YAML** — `api-docs/{module}/{apiname}.yaml` 생성 (OpenAPI 3.0.3)
12. **추가 참고사항** — 마이그레이션 SQL, 모듈 간 의존 관계, 후속 권고

### Legacy 모드 출력 순서

1. **수정 요약** — 변경 대상 파일, 변경 내용
2. **변경 코드** — diff 또는 전체 코드 + 파일 경로
3. **사이드 이펙트 확인** — 영향받는 파일 목록
4. **테스트** — 갱신 필요한 테스트 (있는 경우)

### 에러 응답 표준

```json
{
  "status": "error",
  "error": {
    "code": "NOT_FOUND",
    "message": "요청하신 항목을 찾을 수 없습니다."
  }
}
```

```json
{
  "status": "error",
  "error": {
    "code": "INVALID_INPUT",
    "message": "입력값이 유효하지 않습니다.",
    "details": {
      "email": ["이메일 형식이 올바르지 않습니다."],
      "name": ["이름은 필수 항목입니다."]
    }
  }
}
```

**표준 에러 코드:** §"API 응답 표준" 의 에러 코드 표(현상 서술형, suffix 없음) 참조. 모든 응답 본문에 동일 코드 사용.

---

## Mental Dry-Run (코드 사전 검증, 필수)

코드 생성·수정 시, **실제 파일에 기록하기 전에** 다음 절차를 반드시 수행한다.

1. **1차 작성** — 응답(메모리) 상에서만 코드를 작성한다. 실제 파일에는 기록하지 않는다.
2. **1차 재검토** — 작성한 코드를 스킬 규칙·자가 검증 체크리스트 기준으로 검토한다.
3. **2차 재검토** — 엣지 케이스, 사이드 이펙트, 기존 코드와의 정합성을 추가 검토한다.
4. **파일 반영** — 2회 검토 후 문제가 없다고 판단될 경우에만 실제 파일에 기록한다.

> 검토 중 문제가 발견되면 메모리 상에서 수정 후 다시 1차 재검토부터 반복한다.

---

## 자가 검증 체크리스트

### 0. 모드 판별 (최우선)
- [ ] Legacy 수정인가, New 모듈 생성인가 판별했는가
- [ ] 판별 결과에 따라 아래 해당 체크리스트를 적용

### New 모드 체크리스트

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

#### 기타
- [ ] Controller의 catch에서 안전한 메시지만 반환하는가
- [ ] Unit 테스트 + Feature 테스트 모두 포함
- [ ] 모듈 Routes.php 제공
- [ ] API 명세서(`api-docs/{module}/{apiname}.md`)가 생성되었는가
- [ ] Swagger YAML(`api-docs/{module}/{apiname}.yaml`)이 생성/갱신되었는가
- [ ] `api-docs/README.md` 인덱스에 항목이 추가되었는가
- [ ] PSR-12 코딩 스타일 준수
- [ ] 모든 PHP 파일에 `declare(strict_types=1)` 선언
- [ ] 보안 검증 통과
- [ ] 에러 응답이 표준 에러 코드 체계를 따르는가
- [ ] `date()`, `time()` 사용 없이 `DateTimeImmutable`만 사용했는가

### Legacy 모드 체크리스트
- [ ] 기존 파일의 네이밍/DI/디렉토리 패턴을 유지했는가
- [ ] 변경으로 인한 사이드 이펙트를 확인했는가
- [ ] PSR-12 코딩 스타일 준수
- [ ] 신규/수정 PHP 파일에 `declare(strict_types=1)` 선언
- [ ] 보안 검증 통과
- [ ] 테스트 코드 갱신 (있는 경우)

---

## CI4 베스트 프랙티스

- JSON 요청 바디: `$this->request->getJSON(true)` 사용
- 폼 데이터: `$this->request->getVar()` 사용
- API 컨트롤러에 `protected string $format = 'json';` 항상 설정
- **DI**: `service('{name}')` 함수로 Service/Repository 인스턴스를 가져온다
- **Model 생성**: Repository에서 `model(ClassName::class)` 헬퍼 사용
- **테스트 DI 오버라이드**: Mock을 생성자에 직접 주입하여 단위 테스트
- **활용 권장 PHP 8.x 기능**:
  - 8.0: Constructor Promotion, Named Arguments, Union Types, match 표현식
  - 8.1: Enums, readonly property, Fibers, Intersection Types
  - 8.2: readonly class, DNF Types
  - 8.3: Typed Constants, json_validate(), #[\Override]
  - 8.4: Property Hooks, new without parentheses, Asymmetric Visibility
- 소프트 딜리트: `$useSoftDeletes = true` + 스키마에 `deleted_at` 포함
