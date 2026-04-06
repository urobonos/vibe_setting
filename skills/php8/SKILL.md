---
name: php8
description: >
  PHP 8.x + CodeIgniter 4.x 환경에서 RESTful API를 설계하고 구현할 때 반드시 사용하는 스킬.
  Controller → Library → Model의 3계층 아키텍처를 따르는 PHP 파일 생성, PHPUnit 테스트 코드,
  Routes.php 설정까지 한 번에 생성한다. 사용자가 "API 만들어줘", "CI4 컨트롤러 만들어줘",
  "CRUD 엔드포인트 추가해줘", "PHP 모델/서비스 만들어줘" 등의 요청을 하면 반드시 이 스킬을 사용한다.
  부분 구현은 절대 금지 — 5가지 산출물(Controller, Library, Model, 테스트, Routes)이 항상 함께 생성되어야 한다.
triggers:
  - "API 만들어줘", "엔드포인트 추가", "CRUD 만들어줘"
  - "CI4 컨트롤러 만들어줘", "PHP 모델 만들어줘", "서비스 만들어줘"
  - app/Controllers/, app/Libraries/, app/Models/ 하위 PHP 파일 생성/수정 시
version: 1.1.0
depends_on: [mysql8, security-audit]
conflicts_with: []
min_claude_md_version: "3.2"
---

# PHP 8.x + CI4.x API Architect Skill

PHP 8.x + CodeIgniter 4.x RESTful API를 **3계층 아키텍처**로 완전하게 구현하는 스킬.

---

## PHP / CI4 코딩 표준

### 1. PSR 준수

- **PSR-1** (Basic Coding Standard): 파일은 `<?php` 또는 `<?=` 태그만 사용, UTF-8(BOM 없음), 네임스페이스와 클래스는 오토로딩 표준을 따른다.
- **PSR-4** (Autoloading): 네임스페이스와 디렉토리 구조가 1:1로 일치해야 한다.
- **PSR-12** (Extended Coding Style): 인덴트 **4칸 스페이스**, 줄 끝 공백 없음, 여는 중괄호는 같은 줄(메서드/클래스는 다음 줄).

```php
// PSR-12 준수 예시
namespace App\Libraries;

use App\Contracts\ServiceInterface;
use Exception;

class OrderService implements ServiceInterface
{
    public function getById(int $id): array
    {
        // 인덴트 4칸 스페이스
        if ($id <= 0) {
            throw new Exception('유효하지 않은 ID입니다.');
        }

        return $this->model->find($id);
    }
}
```

### 2. 추상화 / 구체화 범위 설계

인터페이스는 `app/Contracts/` 디렉토리에 배치한다.

#### 추상화 필수 (인터페이스/추상 클래스 선행)

| 조건 | 예시 |
|------|------|
| 2개 이상 구현체가 예상되는 경우 | 결제 수단별 PaymentService |
| 외부 시스템 연동 | SMS, 이메일, 결제 게이트웨이 |
| 교체 가능성이 있는 경우 | 캐시 드라이버, 파일 스토리지 |
| 공통 행위를 여러 클래스가 공유하는 경우 | 기본 CRUD Service |

#### 구체화 허용 (인터페이스 없이 직접 구현)

| 조건 | 예시 |
|------|------|
| 단일 구현이 명확하고 교체 가능성이 없는 경우 | 단순 CRUD Service |
| 유틸리티/헬퍼 성격의 클래스 | 날짜 포맷터, 문자열 처리 |

#### 추상화 시 주석 필수

추상화가 진행된 경우 **인터페이스/추상 클래스 상단에 추상화 사유를 반드시 주석으로 명시**한다.

```php
// Step 1: 인터페이스 정의 (app/Contracts/PaymentGatewayInterface.php)
namespace App\Contracts;

/**
 * [추상화 사유] 결제 게이트웨이가 복수(Stripe, Toss, KakaoPay)로 존재하며,
 * 향후 게이트웨이 추가/교체가 예상되므로 인터페이스로 분리한다.
 */
interface PaymentGatewayInterface
{
    public function charge(int $amount, array $options): array;
    public function refund(string $transactionId): bool;
}

// Step 2: 구체 클래스 구현 (app/Libraries/TossPaymentService.php)
namespace App\Libraries;

use App\Contracts\PaymentGatewayInterface;

/**
 * Toss Payments 결제 게이트웨이 구현체.
 */
class TossPaymentService implements PaymentGatewayInterface
{
    /**
     * Toss API를 통해 결제를 요청한다.
     *
     * @param int   $amount  결제 금액 (원 단위)
     * @param array $options 결제 옵션 (orderId, orderName 등)
     * @return array 결제 결과 (transactionId, status 등)
     */
    public function charge(int $amount, array $options): array
    {
        // 구현...
    }

    /**
     * 기존 결제 건을 환불 처리한다.
     *
     * @param string $transactionId 원 결제의 트랜잭션 ID
     * @return bool 환불 성공 여부
     */
    public function refund(string $transactionId): bool
    {
        // 구현...
    }
}
```

### 3. 보안 검증 필수

모든 코드는 **`security-audit` 스킬**의 보안 규칙을 준수해야 한다. 보안 검증의 Single Source of Truth는 `security-audit` 스킬이며, 이 스킬은 참조만 한다. 주요 점검 항목:

- SQL Injection, XSS, CSRF, 입력값 검증, Mass Assignment
- 상세 규칙, 감지 패턴, CI4 적용 방법은 `security-audit` 스킬을 참조한다.

### 4. MVC 사이드 이펙트 방지

파일 수정/작성 전 **파생되는 MVC 패턴의 영향 범위를 반드시 확인**한다.

- **Model 변경 시**: 해당 Model을 사용하는 모든 Library/Service → Controller 확인
- **Library 변경 시**: 해당 Library를 호출하는 모든 Controller 확인
- **Controller 변경 시**: Routes.php의 라우트 매핑, 필터 설정 확인
- **Migration 변경 시**: Model의 `$allowedFields`, `$validationRules` 동기화 확인

변경으로 인한 사이드 이펙트가 감지되면 **영향받는 모든 파일을 함께 수정**한다.

### 5. 공통 모델 분리

2개 이상의 Service에서 참조하는 모델은 **공통 모델**로 분류하여 관리한다.

| 구분 | 위치 | 기준 |
|------|------|------|
| **전용 모델** | `app/Models/` | 단일 Service에서만 사용 |
| **공통 모델** | `app/Models/Common/` | 2개 이상 Service에서 참조 |

- 공통 모델 변경 시 **해당 모델을 참조하는 모든 Service의 영향 범위를 확인**한다.
- 전용 모델이 2번째 Service에서 참조되는 시점에 `Common/`으로 이동을 제안한다.

```php
// 공통 모델 예시 (app/Models/Common/UserModel.php)
namespace App\Models\Common;

use CodeIgniter\Model;

/**
 * 공통 모델: OrderService, AuthService, ProfileService에서 참조.
 * 변경 시 위 Service 전체 영향 범위 확인 필수.
 */
class UserModel extends Model
{
    protected $table = 'users';
    // ...
}
```

### 6. 주석 규칙

#### 필수 주석 대상

| 대상 | 주석 내용 |
|------|-----------|
| **모든 함수/메서드** | `@param`, `@return`, 함수의 목적을 한 줄로 설명 |
| **복잡한 비즈니스 로직** | 로직의 의도와 흐름을 단계별로 설명 |
| **추상화된 클래스/인터페이스** | 추상화 사유 명시 (§2 참조) |
| **공통 모델** | 참조하는 Service 목록 명시 (§5 참조) |
| **비직관적인 조건/계산** | 왜 이 조건/계산이 필요한지 설명 |

#### 주석 스타일

```php
/**
 * 주문의 총 금액을 계산한다.
 *
 * 할인 적용 순서: 쿠폰 할인 → 등급 할인 → 포인트 차감.
 * 할인 적용 후 최소 결제 금액(100원) 미만이 되지 않도록 보정한다.
 *
 * @param int   $orderId  주문 ID
 * @param array $discounts 적용할 할인 정보
 * @return int 최종 결제 금액 (원 단위)
 */
public function calculateTotal(int $orderId, array $discounts): int
{
    // 1단계: 원가 합산
    $subtotal = $this->getSubtotal($orderId);

    // 2단계: 쿠폰 할인 적용 (정률/정액 구분)
    $afterCoupon = $this->applyCouponDiscount($subtotal, $discounts['coupon'] ?? null);

    // 3단계: 등급 할인 적용
    $afterGrade = $this->applyGradeDiscount($afterCoupon, $discounts['grade'] ?? 0);

    // 4단계: 최소 결제 금액 보정
    return max($afterGrade, 100);
}
```

---

## 핵심 규칙

새 API 엔드포인트나 기능 요청이 오면 아래 **5가지를 반드시 동시에 생성**한다:

1. **Controller** (`app/Controllers/Api/`)
2. **Library/Service** (`app/Libraries/`)
3. **Model** (`app/Models/`)
4. **PHPUnit 테스트** (Unit + Feature)
5. **Routes.php 설정 스니펫**

부분 구현은 허용되지 않는다.

---

## 아키텍처 레이어

### Layer 1: Controller (`app/Controllers/Api/`)

**책임**: HTTP 요청 수신 → 입력 검증 → HTTP 응답 반환  
**금지**: 비즈니스 로직 — 모든 처리는 Library/Service로 위임

```php
namespace App\Controllers\Api;

use CodeIgniter\RESTful\ResourceController;
use App\Libraries\{Feature}Service;
use Exception;

class {Feature}Controller extends ResourceController
{
    protected string $format = 'json';
    protected ${feature}Service;

    public function __construct(?{Feature}Service ${feature}Service = null)
    {
        $this->{feature}Service = ${feature}Service ?? new {Feature}Service();
    }

    public function index()
    {
        try {
            $page = (int)($this->request->getGet('page') ?? 1);
            $perPage = (int)($this->request->getGet('per_page') ?? 20);
            $result = $this->{feature}Service->getList($page, $perPage);
            return $this->respond([
                'status' => 'success',
                'data' => $result['data'],
                'meta' => $result['meta'],
            ]);
        } catch (Exception $e) {
            log_message('error', '{feature} index error: ' . $e->getMessage());
            return $this->failServerError('서버 오류가 발생했습니다.');
        }
    }

    public function show($id = null)
    {
        try {
            $data = $this->{feature}Service->getById((int)$id);
            return $this->respond(['status' => 'success', 'data' => $data]);
        } catch (Exception $e) {
            return $this->failNotFound('요청하신 데이터를 찾을 수 없습니다.');
        }
    }

    public function create()
    {
        $rules = [/* 요청별 규칙 */];
        if (!$this->validate($rules)) {
            return $this->failValidationErrors($this->validator->getErrors());
        }
        try {
            $result = $this->{feature}Service->create($this->request->getJSON(true));
            return $this->respondCreated(['status' => 'success', 'data' => $result]);
        } catch (Exception $e) {
            log_message('error', '{feature} create error: ' . $e->getMessage());
            return $this->failServerError('서버 오류가 발생했습니다.');
        }
    }

    public function update($id = null)
    {
        $rules = [/* 요청별 규칙 */];
        if (!$this->validate($rules)) {
            return $this->failValidationErrors($this->validator->getErrors());
        }
        try {
            $result = $this->{feature}Service->update((int)$id, $this->request->getJSON(true));
            return $this->respond(['status' => 'success', 'data' => $result]);
        } catch (Exception $e) {
            log_message('error', '{feature} update error: ' . $e->getMessage());
            return $this->failServerError('서버 오류가 발생했습니다.');
        }
    }

    public function delete($id = null)
    {
        try {
            $this->{feature}Service->delete((int)$id);
            return $this->respondDeleted(['status' => 'success', 'message' => '삭제되었습니다.']);
        } catch (Exception $e) {
            return $this->failNotFound('요청하신 데이터를 찾을 수 없습니다.');
        }
    }
}
```

**예외 → HTTP 상태 코드 매핑**:
- 일반 `Exception` → `failServerError()` (500) — 내부 메시지 로깅 후 안전한 메시지 반환
- 리소스 없음 → `failNotFound()` (404) — 안전한 메시지 반환
- 권한 없음 → `failForbidden()` (403)
- 중복/충돌 → `fail('message', 409)`
- **주의:** `$e->getMessage()`를 HTTP 응답에 직접 노출하지 않는다. 내부 에러는 `log_message()`로 기록하고, 사용자에게는 안전한 메시지를 반환한다.

---

### Layer 2: Library/Service (`app/Libraries/`)

**책임**: 모든 비즈니스 로직, 데이터 변환, 모델 간 오케스트레이션  
**금지**: HTTP 관련 로직 (응답, 상태코드 등)

```php
namespace App\Libraries;

use App\Models\{Feature}Model;
use Exception;

class {Feature}Service
{
    protected $model;

    public function __construct(?{Feature}Model $model = null)
    {
        $this->model = $model ?? new {Feature}Model();
    }

    /**
     * 페이지네이션이 적용된 목록을 반환한다.
     *
     * @param int $page    현재 페이지 번호
     * @param int $perPage 페이지당 항목 수
     * @return array 데이터 배열과 페이지네이션 메타 정보
     */
    public function getList(int $page = 1, int $perPage = 20): array
    {
        $total = $this->model->countAllResults(false);
        $lastPage = (int)ceil($total / $perPage);
        $data = $this->model->paginate($perPage, 'default', $page);

        return [
            'data' => $data ?: [],
            'meta' => [
                'current_page' => $page,
                'per_page'     => $perPage,
                'total'        => $total,
                'last_page'    => $lastPage,
            ],
        ];
    }

    public function getById(int $id): array
    {
        $item = $this->model->find($id);
        if (!$item) {
            throw new Exception("ID {$id}에 해당하는 데이터가 없습니다.");
        }
        return $item;
    }

    public function create(array $data): array
    {
        $id = $this->model->insert($data, true);
        if (!$id) {
            throw new Exception('데이터 생성에 실패했습니다: ' . implode(', ', $this->model->errors()));
        }
        return $this->model->find($id);
    }

    public function update(int $id, array $data): array
    {
        $this->getById($id); // 존재 확인
        if (!$this->model->update($id, $data)) {
            throw new Exception('데이터 수정에 실패했습니다.');
        }
        return $this->model->find($id);
    }

    public function delete(int $id): void
    {
        $this->getById($id); // 존재 확인
        if (!$this->model->delete($id)) {
            throw new Exception('데이터 삭제에 실패했습니다.');
        }
    }
}
```

**멀티 스텝 작업**은 트랜잭션 사용:
```php
$db = \Config\Database::connect();
$db->transStart();
// ... 여러 모델 작업
$db->transComplete();
if (!$db->transStatus()) {
    throw new Exception('트랜잭션 처리 중 오류가 발생했습니다.');
}
```

---

### Layer 3: Model (`app/Models/`)

**책임**: 데이터베이스 CRUD, 데이터 무결성

```php
namespace App\Models;

use CodeIgniter\Model;

class {Feature}Model extends Model
{
    protected $table            = '{features}';       // 복수형 snake_case
    protected $primaryKey       = 'id';
    protected $useAutoIncrement = true;
    protected $returnType       = 'array';
    protected $useSoftDeletes   = false;              // 필요 시 true
    protected $allowedFields    = [/* 필드 목록 */];
    protected $useTimestamps    = true;
    protected $createdField     = 'created_at';
    protected $updatedField     = 'updated_at';
    // soft delete 시 추가: protected $deletedField = 'deleted_at';

    protected $validationRules = [
        // 모델 레벨 검증 (2차 안전망)
    ];
}
```

---

## 검증 표준

Controller에서 먼저 검증, Model 검증은 2차 안전망:

| 필드 유형 | 검증 규칙 |
|-----------|-----------|
| 필수 문자열 | `required\|min_length[2]\|max_length[100]` |
| 이메일 | `required\|valid_email` |
| 양의 정수 | `required\|integer\|greater_than[0]` |
| 열거형 | `required\|in_list[active,inactive]` |
| 선택적 필드 | `permit_empty\|...` |

---

## 테스트 코드

### Unit Test (Library 검증)
```php
namespace Tests\Unit\Libraries;

use App\Libraries\{Feature}Service;
use CodeIgniter\Test\CIUnitTestCase;

class {Feature}ServiceTest extends CIUnitTestCase
{
    protected $service;
    protected $mockModel;

    protected function setUp(): void
    {
        parent::setUp();
        $this->mockModel = $this->createMock({Feature}Model::class);
        $this->service = new {Feature}Service($this->mockModel);
    }

    public function testGetListReturnsArray()
    {
        $this->mockModel->method('countAllResults')->willReturn(0);
        $this->mockModel->method('paginate')->willReturn([]);
        $result = $this->service->getList();
        $this->assertIsArray($result);
        $this->assertArrayHasKey('data', $result);
        $this->assertArrayHasKey('meta', $result);
    }

    public function testCreateReturnsNewRecord()
    {
        $data = [/* 유효한 테스트 데이터 */];
        $result = $this->service->create($data);
        $this->assertArrayHasKey('id', $result);
    }
}
```

### Feature Test (HTTP 엔드포인트 검증)
```php
namespace Tests\Feature;

use CodeIgniter\Test\CIUnitTestCase;
use CodeIgniter\Test\FeatureTestTrait;

class {Feature}ApiTest extends CIUnitTestCase
{
    use FeatureTestTrait;

    public function testIndexReturns200()
    {
        $result = $this->get('api/{features}');
        $result->assertStatus(200);
        $result->assertJSONFragment(['status' => 'success']);
    }

    public function testCreateWithValidData()
    {
        $result = $this->withBodyFormat('json')
                       ->post('api/{features}', [/* 유효한 데이터 */]);
        $result->assertStatus(201);
        $result->assertJSONFragment(['status' => 'success']);
    }

    public function testCreateFailsWithInvalidData()
    {
        $result = $this->withBodyFormat('json')
                       ->post('api/{features}', []);
        $result->assertStatus(400);
    }

    public function testShowNotFound()
    {
        $result = $this->get('api/{features}/99999');
        $result->assertStatus(404);
    }
}
```

---

## Routes.php 설정

```php
// app/Config/Routes.php 에 추가
$routes->group('api', ['namespace' => 'App\Controllers\Api'], function ($routes) {
    $routes->resource('{features}', ['controller' => '{Feature}Controller']);
    // 커스텀 라우트 (필요 시):
    // $routes->get('{features}/search', '{Feature}Controller::search');
});
```

---

## 출력 형식

모든 API 요청에 대해 아래 순서로 응답한다:

1. **📋 API 설계 요약** — 구현 내용 간략 설명
2. **📂 Controller** — 전체 코드 + 파일 경로
3. **📂 Library (Service)** — 전체 코드 + 파일 경로
4. **📂 Model** — 전체 코드 + 파일 경로
5. **🧪 테스트 코드** — Unit 테스트 + Feature 테스트 + 파일 경로
6. **🛣️ Routes.php 설정** — 추가할 정확한 스니펫
7. **📌 추가 참고사항** — 마이그레이션 SQL, 환경 고려사항, 후속 권고사항

### 에러 응답 표준

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

**표준 에러 코드:**
| 에러 코드 | HTTP 상태 | 설명 |
|-----------|-----------|------|
| `VALIDATION_FAILED` | 400 | 입력값 유효성 검증 실패 |
| `UNAUTHORIZED` | 401 | 인증 실패 |
| `FORBIDDEN` | 403 | 권한 없음 |
| `RESOURCE_NOT_FOUND` | 404 | 리소스를 찾을 수 없음 |
| `CONFLICT` | 409 | 중복/충돌 |
| `SERVER_ERROR` | 500 | 서버 내부 오류 |

---

## 자가 검증 체크리스트

응답 작성 전 반드시 확인:
- [ ] 3개 레이어(Controller, Library, Model) 모두 존재
- [ ] Controller에 비즈니스 로직 없음
- [ ] Library에 HTTP/응답 로직 없음
- [ ] Controller에서 입력 검증 수행
- [ ] Controller의 모든 Service 호출이 try-catch로 감싸짐
- [ ] Unit 테스트 + Feature 테스트 모두 포함
- [ ] Routes.php 스니펫 제공
- [ ] 파일 경로가 CI4 컨벤션에 맞게 명시
- [ ] Model의 `$allowedFields`가 완전하고 정확함
- [ ] 네임스페이스가 CI4 컨벤션과 일치
- [ ] PSR-12 코딩 스타일 준수 (인덴트 4칸 스페이스)
- [ ] 추상화 대상 판별: 추상화 필수 조건에 해당하면 인터페이스 선행, 아니면 구체화 허용
- [ ] 추상화 진행 시 인터페이스/추상 클래스 상단에 추상화 사유 주석이 있는가
- [ ] 공통 모델(2+ Service 참조)은 `app/Models/Common/`에 배치했는가
- [ ] 모든 함수/메서드에 목적, `@param`, `@return` 주석이 있는가
- [ ] 복잡한 비즈니스 로직에 단계별 설명 주석이 있는가
- [ ] 보안 검증 통과 (SQL Injection, XSS, CSRF, 입력값 검증, Mass Assignment)
- [ ] 변경 파일의 MVC 파생 영향 범위를 확인하고 사이드 이펙트가 없는가
- [ ] Controller/Service 생성자에 선택적 DI가 적용되어 있는가
- [ ] Controller의 catch 블록에서 `$e->getMessage()`를 HTTP 응답에 직접 노출하지 않는가
- [ ] 목록 조회에 페이지네이션이 적용되어 있는가
- [ ] 에러 응답이 표준 에러 코드 체계를 따르는가

---

## CI4 베스트 프랙티스

- JSON 요청 바디: `$this->request->getJSON(true)` 사용
- 폼 데이터: `$this->request->getVar()` 사용
- API 컨트롤러에 `protected string $format = 'json';` 항상 설정
- 모델 검증 에러 조회: `$model->errors()`
- 단순 조회 시 raw 쿼리보다 `$model->find($id)` 선호
- 소프트 딜리트: `$useSoftDeletes = true` + 스키마에 `deleted_at` 포함
