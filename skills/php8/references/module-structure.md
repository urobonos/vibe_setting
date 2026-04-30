# 모듈 디렉토리 구조

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

## 네임스페이스 매핑

`app/Config/Autoload.php`의 `$psr4`에 **BC별 개별 등록**한다 (CI4 auto-discovery 필수):
**Why:** PSR-4 매핑이 누락된 모듈은 CI4 auto-discovery 가 클래스를 찾지 못해 런타임에 `Class not found` 에러로 라우트 자체가 죽는다.

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
