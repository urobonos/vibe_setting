# 모듈 Routes 설정

## API URL 규격

```
/{module}/{resource}
```

| 모듈 | URL 예시 | 설명 |
|------|----------|------|
| Call | `/phone-consult/calls` | 전화 상담 |
| Commerce | `/commerce/payments` | 결제 |
| Member | `/member/profile` | 회원 프로필 |

- **API 버전 prefix 금지**: URL에 `/v1/`, `/v2/` 등 버전 prefix 사용 금지 (폐기 확정)
  **Why:** URL 버전 분기는 라우트·컨트롤러·문서가 N배로 늘어나며 폐기 시 클라이언트 마이그레이션 비용이 누적된다 — 헤더/필드 기반 협상으로 단일 URL 운영.
- **module**: BC명의 kebab-case (비즈니스 도메인 표현)
- **resource**: 복수형 snake_case 또는 단수형 (리소스 성격에 따라)
- BC 디렉토리명과 URL module명은 다를 수 있다 (예: `Call` BC → `/phone-consult/`)

## 모듈 라우트 (`Modules/{BC}/Config/Routes.php`)

```php
// Modules/Order/Config/Routes.php
$routes->group('api/commerce', ['namespace' => 'App\Modules\Order\Controllers'], function ($routes) {
    $routes->resource('orders', ['controller' => 'OrderController']);
});
// → /api/commerce/orders
```

## 메인 Routes에서 모듈 자동 로드 (`app/Config/Routes.php`)

```php
$moduleRoutes = glob(APPPATH . 'Modules/*/Config/Routes.php');
foreach ($moduleRoutes as $routeFile) {
    require $routeFile;
}
```
