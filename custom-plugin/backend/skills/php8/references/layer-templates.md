---
type: reference
for: php8/SKILL.md
section: 아키텍처 레이어 (Controller / Service / Repository / Model / Interfaces / Entity / ValueObject)
---

## 아키텍처 레이어

### Layer 1: Controller (`Modules/{BC}/Controllers/`)

**책임**: HTTP 요청 수신 → 입력 검증 → HTTP 응답 반환
**`service()` 함수로 Service를 주입받는다** — `new` 금지

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

    /**
     * 주문 목록을 조회한다 (페이지네이션 적용).
     *
     * @return \CodeIgniter\HTTP\ResponseInterface
     */
    public function index()
    {
        try {
            $page = (int)($this->request->getGet('page') ?? 1);
            $perPage = (int)($this->request->getGet('perPage') ?? 20);
            $result = $this->orderService->getList($page, $perPage);
            return $this->respond([
                'status' => 'success',
                'data' => $result['data'],
                'meta' => $result['meta'],
            ]);
        } catch (Exception $e) {
            log_message('error', 'order index error: ' . $e->getMessage());
            return $this->failServerError('서버 오류가 발생했습니다.');
        }
    }

    /**
     * 주문 단건을 조회한다.
     *
     * @param int|string|null $id 리소스 ID
     * @return \CodeIgniter\HTTP\ResponseInterface
     */
    public function show($id = null)
    {
        try {
            $data = $this->orderService->getById((int)$id);
            return $this->respond(['status' => 'success', 'data' => $data]);
        } catch (Exception $e) {
            return $this->failNotFound('요청하신 데이터를 찾을 수 없습니다.');
        }
    }

    /**
     * 새 주문을 생성한다.
     *
     * @return \CodeIgniter\HTTP\ResponseInterface
     */
    public function create()
    {
        $rules = [/* 요청별 규칙 */];
        if (!$this->validate($rules)) {
            return $this->failValidationErrors($this->validator->getErrors());
        }
        try {
            $result = $this->orderService->create($this->request->getJSON(true));
            return $this->respondCreated(['status' => 'success', 'data' => $result]);
        } catch (Exception $e) {
            log_message('error', 'order create error: ' . $e->getMessage());
            return $this->failServerError('서버 오류가 발생했습니다.');
        }
    }

    /**
     * 주문을 수정한다.
     *
     * @param int|string|null $id 리소스 ID
     * @return \CodeIgniter\HTTP\ResponseInterface
     */
    public function update($id = null)
    {
        $rules = [/* 요청별 규칙 */];
        if (!$this->validate($rules)) {
            return $this->failValidationErrors($this->validator->getErrors());
        }
        try {
            $result = $this->orderService->update((int)$id, $this->request->getJSON(true));
            return $this->respond(['status' => 'success', 'data' => $result]);
        } catch (Exception $e) {
            log_message('error', 'order update error: ' . $e->getMessage());
            return $this->failServerError('서버 오류가 발생했습니다.');
        }
    }

    /**
     * 주문을 삭제한다.
     *
     * @param int|string|null $id 리소스 ID
     * @return \CodeIgniter\HTTP\ResponseInterface
     */
    public function delete($id = null)
    {
        try {
            $this->orderService->delete((int)$id);
            return $this->respondDeleted(['status' => 'success', 'message' => '삭제되었습니다.']);
        } catch (Exception $e) {
            return $this->failNotFound('요청하신 데이터를 찾을 수 없습니다.');
        }
    }
}
```

**예외 → HTTP 상태 코드 매핑**:
- 일반 `Exception` → `failServerError()` (500) — `$e->getMessage()` 대신 안전한 메시지 반환, 내부 에러는 `log_message()`
- 리소스 없음 → `failNotFound()` (404)
- 권한 없음 → `failForbidden()` (403)
- 중복/충돌 → `fail('message', 409)`

---

### Layer 2: Service (`Modules/{BC}/Services/`)

**책임**: 비즈니스 로직, 데이터 변환, Repository 오케스트레이션
**DB 직접 접근 금지** — 반드시 Repository를 통해서만 데이터에 접근
**다른 모듈 참조 시 Interface 타입만 사용**

```php
namespace App\Modules\Order\Services;

use App\Modules\Order\Interfaces\OrderServiceInterface;
use App\Modules\Order\Interfaces\OrderRepositoryInterface;
use Exception;

class OrderService implements OrderServiceInterface
{
    public function __construct(
        protected OrderRepositoryInterface $repository
    ) {}

    /**
     * 페이지네이션이 적용된 주문 목록을 반환한다.
     *
     * @param int $page    현재 페이지 번호
     * @param int $perPage 페이지당 항목 수
     * @return array{data: array, meta: array}
     */
    public function getList(int $page = 1, int $perPage = 20): array
    {
        return $this->repository->paginate($page, $perPage);
    }

    /**
     * ID로 주문을 조회한다.
     *
     * @param int $id 주문 ID
     * @return array 주문 데이터
     * @throws Exception 데이터 없을 경우
     */
    public function getById(int $id): array
    {
        $item = $this->repository->findById($id);
        if (!$item) {
            throw new Exception("ID {$id}에 해당하는 데이터가 없습니다.");
        }
        return $item;
    }

    /**
     * 새 주문을 생성한다.
     *
     * @param array $data 생성할 데이터
     * @return array 생성된 주문
     * @throws Exception 생성 실패 시
     */
    public function create(array $data): array
    {
        $id = $this->repository->insert($data);
        if (!$id) {
            throw new Exception('데이터 생성에 실패했습니다.');
        }
        return $this->repository->findById($id);
    }

    /**
     * 주문을 수정한다.
     *
     * @param int   $id   주문 ID
     * @param array $data 수정할 데이터
     * @return array 수정된 주문
     * @throws Exception 수정 실패 시
     */
    public function update(int $id, array $data): array
    {
        $this->getById($id);
        if (!$this->repository->update($id, $data)) {
            throw new Exception('데이터 수정에 실패했습니다.');
        }
        return $this->repository->findById($id);
    }

    /**
     * 주문을 삭제한다.
     *
     * @param int $id 주문 ID
     * @return void
     * @throws Exception 삭제 실패 시
     */
    public function delete(int $id): void
    {
        $this->getById($id);
        if (!$this->repository->delete($id)) {
            throw new Exception('데이터 삭제에 실패했습니다.');
        }
    }
}
```

**다른 모듈 Service가 필요한 경우** — Interface로 주입:
```php
use App\Modules\Payment\Interfaces\PaymentServiceInterface;

class OrderService implements OrderServiceInterface
{
    public function __construct(
        protected OrderRepositoryInterface $repository,
        protected PaymentServiceInterface $paymentService  // Interface만 참조
    ) {}
}
```

**멀티 스텝 작업**은 Service에서 트랜잭션 관리:
```php
$db = \Config\Database::connect();
$db->transStart();
$this->repository->insert($orderData);
$this->repository->updateStock($itemId, $qty);
$db->transComplete();
if (!$db->transStatus()) {
    throw new Exception('트랜잭션 처리 중 오류가 발생했습니다.');
}
```

---

### Layer 3: Repository (`Modules/{BC}/Repositories/`)

**책임**: 데이터 접근 전담. Query Builder 우선, raw query는 named binding 필수.
**Service와 Controller는 Repository 없이 DB에 접근할 수 없다.**

```php
namespace App\Modules\Order\Repositories;

use App\Modules\Order\Interfaces\OrderRepositoryInterface;
use App\Modules\Order\Models\OrderModel;

class OrderRepository implements OrderRepositoryInterface
{
    public function __construct(
        protected OrderModel $model
    ) {}

    /**
     * ID로 주문을 조회한다.
     *
     * @param int $id 주문 ID
     * @return array|null
     */
    public function findById(int $id): ?array
    {
        return $this->model->find($id);
    }

    /**
     * 페이지네이션 목록을 반환한다.
     *
     * @param int $page    페이지 번호
     * @param int $perPage 페이지당 항목 수
     * @return array{data: array, meta: array}
     */
    public function paginate(int $page = 1, int $perPage = 20): array
    {
        $total = $this->model->countAllResults(false);
        $lastPage = (int)ceil($total / $perPage);
        $data = $this->model->paginate($perPage, 'default', $page);

        return [
            'data' => $data ?: [],
            'meta' => [
                'page'     => $page,
                'perPage'  => $perPage,
                'total'    => $total,
                'lastPage' => $lastPage,
            ],
        ];
    }

    /**
     * 새 레코드를 삽입한다.
     *
     * @param array $data 삽입할 데이터
     * @return int|false 삽입된 ID 또는 실패 시 false
     */
    public function insert(array $data): int|false
    {
        return $this->model->insert($data, true);
    }

    /**
     * 레코드를 수정한다.
     *
     * @param int   $id   레코드 ID
     * @param array $data 수정할 데이터
     * @return bool
     */
    public function update(int $id, array $data): bool
    {
        return $this->model->update($id, $data);
    }

    /**
     * 레코드를 삭제한다.
     *
     * @param int $id 레코드 ID
     * @return bool
     */
    public function delete(int $id): bool
    {
        return $this->model->delete($id);
    }
}
```

### Query Builder vs Raw Query 규칙

**Query Builder 우선 (기본):**
```php
// ✓ QB 사용
public function findActiveByUser(int $userId): array
{
    return $this->model
        ->where('user_id', $userId)
        ->where('status', 'active')
        ->orderBy('created_at', 'DESC')
        ->findAll();
}
```

**Raw Query 허용 조건: CTE, Window Function 등 QB 미지원 구문 (Repository에서만):**
```php
// ✓ QB 미지원 → $db->query() + named binding (사유 주석 필수)
/**
 * 카테고리별 매출 순위를 조회한다.
 *
 * [raw query 사유] Window Function(RANK)은 CI4 Query Builder 미지원.
 *
 * @param string $startDate 시작일
 * @param string $endDate   종료일
 * @return array
 */
public function getSalesRanking(string $startDate, string $endDate): array
{
    $db = \Config\Database::connect();
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
// ✗ Service/Controller에서 직접 DB 접근
$db = \Config\Database::connect();
$db->table('orders')->where(...)->get();

// ✗ Repository에서 positional binding
$db->query("SELECT * FROM orders WHERE id = ?", [$id]);

// ✗ raw query에 사유 주석 없음
```

---

### Model (`Modules/{BC}/Models/`)

**책임**: 테이블 매핑, 필드 정의, 모델 레벨 검증 (2차 안전망)
**Model은 Repository에서만 사용한다** — Service/Controller에서 직접 참조 금지

```php
namespace App\Modules\Order\Models;

use CodeIgniter\Model;

class OrderModel extends Model
{
    protected $table            = 'orders';           // 복수형 snake_case
    protected $primaryKey       = 'id';
    protected $useAutoIncrement = true;
    protected $returnType       = 'array';
    protected $useSoftDeletes   = false;
    protected $allowedFields    = [/* 필드 목록 */];
    protected $useTimestamps    = true;
    protected $createdField     = 'created_at';
    protected $updatedField     = 'updated_at';

    protected $validationRules = [
        // 모델 레벨 검증 (2차 안전망)
    ];
}
```

---

### Interfaces (`Modules/{BC}/Interfaces/`) — 외부 노출 계약

모듈의 공개 Interface. 다른 모듈은 이 Interface만 참조할 수 있다.

```php
// Modules/Order/Interfaces/OrderServiceInterface.php
namespace App\Modules\Order\Interfaces;

/**
 * [추상화 사유] 모듈 경계 통신을 위한 공개 Interface.
 * 다른 모듈(Payment, Delivery 등)에서 주문 기능에 접근할 때 사용한다.
 */
interface OrderServiceInterface
{
    public function getList(int $page = 1, int $perPage = 20): array;
    public function getById(int $id): array;
    public function create(array $data): array;
    public function update(int $id, array $data): array;
    public function delete(int $id): void;
}
```

```php
// Modules/Order/Interfaces/OrderRepositoryInterface.php
namespace App\Modules\Order\Interfaces;

interface OrderRepositoryInterface
{
    public function findById(int $id): ?array;
    public function paginate(int $page, int $perPage): array;
    public function insert(array $data): int|false;
    public function update(int $id, array $data): bool;
    public function delete(int $id): bool;
}
```

---

### Entity (`Modules/{BC}/Entities/`) — Domain Object. 순수 PHP 클래스

**책임**: 도메인 규칙, 상태 관리, 비즈니스 불변식(invariant) 보장
**외부 의존성 금지** — DB, HTTP, Framework 클래스를 import하지 않는다

```php
namespace App\Modules\Order\Entities;

use App\Modules\Order\ValueObjects\Money;
use InvalidArgumentException;

/**
 * 주문 도메인 엔티티.
 * 주문 상태 전이, 금액 계산 등 도메인 규칙을 캡슐화한다.
 */
class Order
{
    public function __construct(
        private readonly int $id,
        private string $status,
        private Money $totalAmount,
        private readonly \DateTimeImmutable $createdAt
    ) {}

    /**
     * 주문을 취소한다.
     *
     * @throws InvalidArgumentException 취소 불가 상태인 경우
     */
    public function cancel(): void
    {
        if (!in_array($this->status, ['pending', 'confirmed'])) {
            throw new InvalidArgumentException(
                "'{$this->status}' 상태의 주문은 취소할 수 없습니다."
            );
        }
        $this->status = 'cancelled';
    }

    /**
     * 주문이 환불 가능한지 확인한다.
     *
     * @return bool
     */
    public function isRefundable(): bool
    {
        return $this->status === 'completed'
            && $this->createdAt > new \DateTimeImmutable('-30 days');
    }

    public function getId(): int { return $this->id; }
    public function getStatus(): string { return $this->status; }
    public function getTotalAmount(): Money { return $this->totalAmount; }
}
```

### ValueObject (`Modules/{BC}/ValueObjects/` 또는 `Modules/Shared/ValueObjects/`) — Immutable 값 객체 (선택)

**책임**: 값의 동등성, 불변성, 자체 유효성 검증
**외부 의존성 금지** — 순수 PHP만 사용

```php
namespace App\Modules\Shared\ValueObjects;

use InvalidArgumentException;

/**
 * 금액을 표현하는 값 객체.
 * 불변이며, 통화 단위와 금액의 유효성을 보장한다.
 */
final readonly class Money
{
    public function __construct(
        private int $amount,
        private string $currency = 'USD'
    ) {
        if ($amount < 0) {
            throw new InvalidArgumentException('금액은 0 이상이어야 합니다.');
        }
        if (!in_array($currency, ['USD', 'KRW', 'JPY'])) {
            throw new InvalidArgumentException("지원하지 않는 통화: {$currency}");
        }
    }

    /**
     * 두 금액을 합산한다.
     *
     * @param Money $other 합산할 금액
     * @return self 합산된 새 Money 인스턴스
     * @throws InvalidArgumentException 통화 불일치 시
     */
    public function add(Money $other): self
    {
        if ($this->currency !== $other->currency) {
            throw new InvalidArgumentException('통화가 일치하지 않습니다.');
        }
        return new self($this->amount + $other->amount, $this->currency);
    }

    public function getAmount(): int { return $this->amount; }
    public function getCurrency(): string { return $this->currency; }

    public function equals(Money $other): bool
    {
        return $this->amount === $other->amount
            && $this->currency === $other->currency;
    }
}
```

### Entity/VO 사용 규칙

| 규칙 | 설명 |
|------|------|
| **외부 의존성 금지** | `use CodeIgniter\...`, `use Config\...` 등 Framework import 불가 |
| **불변 우선** | `readonly` 프로퍼티, `DateTimeImmutable` 필수 (§5.6). `date()`/`time()` 금지 |
| **자체 유효성** | 생성자에서 도메인 규칙 검증. 유효하지 않으면 `InvalidArgumentException` |
| **Service에서 사용** | Service가 Entity를 생성·조작, Repository가 Entity↔DB 변환 |
| **VO 동등성** | `equals()` 메서드로 값 비교 (참조 비교 대신) |
| **Shared VO** | 2+ 모듈에서 공통 사용하는 VO는 `Modules/Shared/ValueObjects/` |
| **생략 가능** | 단순 CRUD로 도메인 규칙이 불필요한 경우 Entity/VO 생략 허용 |
