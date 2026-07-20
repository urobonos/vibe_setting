# 테스트 코드

## 테스트 디렉토리 구조

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

## Unit Test (Service 검증 — Repository Mock 주입)

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

## Feature Test (HTTP 엔드포인트 검증)

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
