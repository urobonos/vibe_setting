# 모듈 경계 규칙

## 모듈 간 통신: Interface Only

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

## 모듈 공개 API

각 모듈은 `Interfaces/` 디렉토리에 **다른 모듈이 참조할 수 있는 Interface만** 공개한다.
모듈 내부 클래스(Service 구체 클래스, Repository, Model)는 외부에서 직접 참조할 수 없다.

## Shared 모듈

2개 이상 모듈에서 공통으로 필요한 Model/Interface는 `Modules/Shared/`에 배치한다.
전용 모델이 2번째 모듈에서 참조되는 시점에 `Shared/`로 이동을 제안한다.
