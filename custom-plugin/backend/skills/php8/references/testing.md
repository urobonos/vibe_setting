# 테스트 코드 (CI 4.7 / PHPUnit 10.5)

공식 문서는 **"배치 규칙에는 정답이 없다. 다만 미리 정해두라"** 고만 말한다 (`testing/overview.html` — *"There are no rules for how test files must be placed. However, we recommend that you establish placement rules in advance"*). 그래서 정답을 여기서 확정한다. 본 문서의 배치 규칙과 작성 규칙은 **신규 테스트에 강제**다.

**Why 강제인가:** 2026-09-11 `hongcafe_global_backend` 실측 — 테스트 594개가 `tests/unit/Modules/` 181 · `tests/Modules/{BC}/{Unit,Feature}/` 256 · `tests/Feature/Modules/` 75 세 컨벤션으로 갈라져 있었다. 규칙이 문서에만 있고 강제되지 않으면 각 작업자가 그때그때 정하고, 나중에 "이 도메인 테스트가 어디 있나" 를 매번 전수 grep 으로 찾게 된다.

**역소급 면제:** 2026-09-11 이전 작성분은 그대로 둔다. 기존 파일을 수정할 때도 이동시키지 않는다 — 일괄 이관은 네임스페이스 594건 동시 변경이라 별도 트랙이다.

---

## 1. 배치 규칙 (강제)

### 3축 판정 — DB 와 HTTP 만 보면 정해진다

| 축 | 판정 기준 | 트레이트 | 대상 |
|----|----------|---------|------|
| `tests/unit/` | **DB 연결 없음** | 없음 | Service, Entity/VO, Helper, 순수 Library |
| `tests/database/` | **DB 연결 있음** | `DatabaseTestTrait` | Repository, Model, 마이그레이션·시더 |
| `tests/feature/` | **HTTP 요청으로 진입** | `FeatureTestTrait` | API 엔드포인트, Filter 체인, 라우팅 |

판정은 **무엇을 테스트하려 했는가**가 아니라 **무엇에 실제로 붙는가**로 한다. Service 테스트라도 Repository 를 mock 하지 않고 실 DB 에 붙었다면 그건 `unit/` 이 아니라 `database/` 다 — 축을 속이면 `unit/` 스위트가 DB 없이는 안 도는 상태가 되고, 그 시점부터 빠른 피드백 루프가 사라진다.

### 디렉토리 트리

```
tests/
├── _support/                  # Mock·Seeder·Fixture·테스트 전용 Entity. 테스트 케이스를 두지 않는다
│   ├── Database/Seeds/
│   └── Mocks/
│
├── unit/                      # DB 연결 X
│   ├── Modules/{BC}/          # Service·Entity·VO (Repository Interface mock 주입)
│   ├── Libraries/             # 레거시 app/Libraries/ 순수 로직
│   └── Helpers/               # 커스텀 헬퍼 함수
│
├── database/                  # DB 연결 O (DatabaseTestTrait)
│   └── Modules/{BC}/          # Repository 쿼리·Model 검증
│
└── feature/                   # HTTP 진입 (FeatureTestTrait)
    ├── Modules/{BC}/          # API 엔드포인트
    └── Filters/               # 인증·권한 Filter 체인
```

- **1차 = 축(unit/database/feature), 2차 = `Modules/{BC}/`.** 축이 먼저인 이유는 CI 에서 축 단위로 스위트를 나눠 돌리기 때문이다 — 모듈이 1차면 "DB 없이 도는 것만" 을 경로로 고를 수 없다.
- 디렉토리명은 **공식 기본값 그대로 소문자** (`unit`/`database`/`feature`), 하위 분류는 PSR-4 대응이라 **PascalCase** (`Modules/Commerce/`).
- 파일명 = `{대상클래스}Test.php`. 네임스페이스 = `Tests\Unit\Modules\{BC}`, `Tests\Database\Modules\{BC}`, `Tests\Feature\Modules\{BC}`.

---

## 2. 모든 테스트 공통 (강제)

```php
final class OrderServiceTest extends CIUnitTestCase   // ① CIUnitTestCase 상속
{
    protected function setUp(): void
    {
        parent::setUp();                              // ② parent 호출 필수
        // ...
    }
}
```

① **`CodeIgniter\Test\CIUnitTestCase` 상속** — PHPUnit `TestCase` 를 직접 상속하면 서비스 리셋·mock 주입·추가 assertion 이 전부 동작하지 않는다.

② **`setUp()`/`tearDown()` 재정의 시 `parent::` 호출** — 빠뜨리면 CI4 가 트레이트 staging(`setUp{트레이트명}()`)을 실행하지 못해, DB 리프레시나 mock 리셋이 조용히 건너뛰어진다. 증상은 "혼자 돌리면 통과, 전체 돌리면 실패" 로 나타난다.

③ **`final` 선언** — 테스트 클래스를 상속해 케이스를 재사용하면 실패 지점이 두 파일로 쪼개진다.

---

## 3. `unit/` — Service 검증 (Repository mock 주입)

```php
namespace Tests\Unit\Modules\Order;

use App\Modules\Order\Interfaces\OrderRepositoryInterface;
use App\Modules\Order\Services\OrderService;
use CodeIgniter\Test\CIUnitTestCase;

final class OrderServiceTest extends CIUnitTestCase
{
    private OrderService $service;
    private OrderRepositoryInterface $mockRepo;

    protected function setUp(): void
    {
        parent::setUp();
        $this->mockRepo = $this->createMock(OrderRepositoryInterface::class);
        $this->service  = new OrderService($this->mockRepo);
    }

    public function testGetByIdThrowsWhenNotFound(): void
    {
        $this->mockRepo->method('findById')->willReturn(null);

        $this->expectException(\Exception::class);
        $this->service->getById(999);
    }
}
```

- mock 은 **구체 Repository 가 아니라 Interface** 로 만든다. 구체 클래스를 mock 하면 모듈 경계(Interface Only)가 테스트에서부터 무너진다.
- **`Time::setTestNow()`** 로 시간을 고정한다 — 고정하지 않은 날짜 비교는 자정·월말에만 깨지는 테스트가 된다. `tearDown()` 에서 인자 없이 `Time::setTestNow()` 를 호출해 해제한다.
- 서비스 컨테이너를 갈아끼울 때는 `Services::injectMock('cache', $mock)`, 정리는 `Services::reset()` / `Services::resetSingle('cache')`.

---

## 4. `database/` — Repository·Model 검증

```php
namespace Tests\Database\Modules\Order;

use CodeIgniter\Test\CIUnitTestCase;
use CodeIgniter\Test\DatabaseTestTrait;

final class OrderRepositoryTest extends CIUnitTestCase
{
    use DatabaseTestTrait;

    protected $refresh   = true;              // 각 테스트 전 DB 롤백 후 재마이그레이션
    protected $seed      = 'OrderSeeder';     // tests/_support/Database/Seeds/
    protected $namespace = 'Tests\Support';   // 시더·마이그레이션 탐색 네임스페이스
}
```

| 프로퍼티 | 역할 |
|---------|------|
| `$refresh` | 테스트마다 `regressDatabase()` → `migrateDatabase()`. **기본 `true` 로 둔다** |
| `$seed` | 매 테스트 전 실행할 시더 클래스 |
| `$seedOnce` | `true` 면 클래스당 1회만 시딩 (느린 시더 한정) |
| `$namespace` | 시더·마이그레이션 탐색 네임스페이스 (기본 `Tests\Support`) |
| `$basePath` | 마이그레이션·시더 파일 경로 오버라이드 |

**DB 전용 assertion** — 직접 쿼리해서 `assertEquals` 하지 말고 이걸 쓴다. 실패 메시지에 테이블·조건이 그대로 찍힌다.

```php
$this->hasInDatabase('orders', ['id' => 1, 'status' => 'paid']);  // 픽스처 삽입 (테스트 후 자동 제거)
$this->seeInDatabase('orders', ['status' => 'paid']);
$this->dontSeeInDatabase('orders', ['status' => 'deleted']);
$this->seeNumRecords(2, 'orders', ['member_id' => 10]);
$value = $this->grabFromDatabase('orders', 'status', ['id' => 1]);
```

**테스트 DB 는 반드시 격리한다.** `phpunit.xml.dist` 의 `<server name="CI_ENVIRONMENT" value="testing" force="true"/>` 가 `Config\Database::$tests` 그룹(SQLite3 in-memory)으로 전환시킨다. 이 고정이 풀리면 `.env` 의 `CI_ENVIRONMENT` 값을 따라가 **테스트가 운영 DB 에 직결된다** (2026-04-22 `phpunit-prd-db-incident` 실사례).

---

## 5. `feature/` — HTTP 엔드포인트 검증

```php
namespace Tests\Feature\Modules\Order;

use CodeIgniter\Test\CIUnitTestCase;
use CodeIgniter\Test\FeatureTestTrait;

final class OrderApiTest extends CIUnitTestCase
{
    use FeatureTestTrait;

    public function testCreateFailsWithInvalidData(): void
    {
        $result = $this->withBodyFormat('json')
                       ->post('api/commerce/orders', []);

        $result->assertStatus(400);
        $result->assertJSONFragment(['status' => 'error']);
    }
}
```

- 호출: `call($method, $path)` / `get` / `post` / `put` / `patch` / `delete` / `options`. 요청 조립은 `withBodyFormat('json')`, `withHeaders([...])`, `withSession([...])`.
- **EP 하나당 200/201 · 400 · 401/403 · 404 를 전건 쓴다.** 정상 경로만 있는 Feature 테스트는 라우팅이 살아있다는 것만 증명하고 계약은 아무것도 증명하지 않는다.
- Filter 체인 검증은 `ControllerTestTrait` 의 `assertFilter($route, $position, $filter)` / `assertNotFilter()` / `assertHasFilters()` / `assertNotHasFilters()` 를 쓴다 — 인증이 실제로 걸렸는지는 라우트 설정으로 확인해야 하고, 응답 코드만으로는 "우연히 401" 과 구분되지 않는다.

---

## 6. 하지 않는 것

- **통과시키려고 테스트를 약화하지 않는다.** assertion 완화, `markTestSkipped()`, 케이스 삭제, 기대값을 실제 출력에 맞춰 고쳐 쓰기 — 전부 금지다. 테스트가 red 면 **프로덕션 코드가 틀린 것**이 기본 가정이다. 테스트 쪽이 틀렸다고 판단하면 그 근거(계약 문서·호출부 grep)를 함께 남긴다.
- **`exit 0` 을 green 으로 읽지 않는다.** PHPUnit 은 fatal 에도 `0` 을 내는 경로가 있다. 판정은 **테스트·assertion 수**로 한다.
- **전량 스위트를 습관적으로 돌리지 않는다.** 변경 범위를 `--filter` / 경로로 좁힌다. 전량은 느릴 뿐 아니라 무관한 기존 결함을 끌고 와 판정을 흐린다.
- **`_support/` 에 테스트 케이스를 두지 않는다.** 여기는 시더·mock·fixture 전용이다.
- **mock 한 대상이 실존하는지 확인 없이 쓰지 않는다.** 존재하지 않는 메서드를 mock 하면 통과하지만 실환경에서는 즉시 fatal 이다 (`grep` 으로 정의 확인).

---

## 7. 실행

```bash
vendor/bin/phpunit tests/unit/Modules/Order          # 경로로 좁히기
vendor/bin/phpunit --filter testGetByIdThrowsWhenNotFound
vendor/bin/phpunit --group database                  # @group 어노테이션 단위
```

설정은 프로젝트 루트 `phpunit.xml.dist` — `phpunit.xml` 이 있으면 그쪽이 우선한다. 부트스트랩은 `vendor/codeigniter4/framework/system/Test/bootstrap.php`.

---

## 참조 출처

- [참조: https://codeigniter.com/user_guide/testing/overview.html — CIUnitTestCase, 배치 규칙 권고, staging(parent:: 호출), 트레이트 staging 규약]
- [참조: https://codeigniter.com/user_guide/testing/database.html — DatabaseTestTrait, $refresh/$seed/$seedOnce/$namespace/$basePath, seeInDatabase 계열 assertion]
- [참조: https://codeigniter.com/user_guide/testing/feature.html — FeatureTestTrait, call/get/post/put/patch/delete/options]
- [참조: https://codeigniter.com/user_guide/testing/controllers.html — ControllerTestTrait, assertFilter 계열]
- [참조: https://codeigniter.com/user_guide/testing/mocking.html — Services::injectMock/reset/resetSingle, mock 캐시 assertion]
- [참조: C:\Works\hongcafe_global_backend\tests — 594 파일 배치 실측 (2026-09-11), 3 컨벤션 분열 근거]
- [참조: C:\Works\hongcafe_global_backend\phpunit.xml.dist — CI_ENVIRONMENT force 고정, 2026-04-22 prd DB 직결 사고 대응 주석]
