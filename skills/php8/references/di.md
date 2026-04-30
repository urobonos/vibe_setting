# 의존성 주입 (DI)

## CI 4.7 Service Discovery

CI 4.7.0+에서는 모듈별 `Config/Services.php`가 **자동 발견**된다.
메인 `app/Config/Services.php`에 수동 등록할 필요 없다.

## 모듈별 DI 등록 (`Modules/{BC}/Config/Services.php`)

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

## DI 사용 규칙

| 규칙 | 설명 |
|------|------|
| **`service()` 함수 필수** | `service('orderService')`로 인스턴스를 가져온다 |
| **`new` 직접 호출 금지** | Controller/Service에서 `new Service()`, `new Repository()`, `new Model()` 금지 |
| **Controller → Service** | Controller 생성자에서 `service()`로 Service를 주입받는다 |
| **Service → Repository** | Service 생성자에서 `service()`로 Repository를 주입받는다 |
| **Repository → Model** | Repository 생성자에서 `model()` 헬퍼로 Model을 주입받는다 |
| **모듈 간 의존** | `service()`로 상대 모듈의 Interface 타입을 받는다 |
| **getShared 패턴** | 기본 싱글턴(`true`), 테스트 시 `false`로 새 인스턴스 |
