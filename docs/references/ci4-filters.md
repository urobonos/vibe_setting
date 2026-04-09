# CI4 Filters 공식 문서

> 출처: https://codeigniter4.github.io/userguide/incoming/filters.html
> 최종 갱신: 2026-04-08

## 필터 생성

`CodeIgniter\Filters\FilterInterface` 구현. `before()` + `after()` 메서드 필수.

```php
<?php
namespace App\Filters;

use CodeIgniter\Filters\FilterInterface;
use CodeIgniter\HTTP\RequestInterface;
use CodeIgniter\HTTP\ResponseInterface;

class MyFilter implements FilterInterface
{
    public function before(RequestInterface $request, $arguments = null)
    {
        // 컨트롤러 실행 전
    }

    public function after(RequestInterface $request, ResponseInterface $response, $arguments = null)
    {
        // 컨트롤러 실행 후
    }
}
```

### before 필터
- `$request` 반환: 요청 객체 교체
- `Response` 반환: 컨트롤러 바이패스 (인증 실패 시 리다이렉트 등)
- 비어있지 않은 값 반환: 후속 필터 중단

### after 필터
- `$response` 반환만 가능. 실행 중단 불가
- 헤더 추가, 응답 캐싱 등에 사용

## 설정: app/Config/Filters.php

### 별칭 (aliases)
```php
public array $aliases = [
    'csrf' => \CodeIgniter\Filters\CSRF::class,
    'api-prep' => [
        \App\Filters\Negotiate::class,
        \App\Filters\ApiAuth::class,
    ],
];
```

### Required 필터 (v4.5.0+)
모든 요청에 항상 실행:
```php
public array $required = [
    'before' => ['forcehttps', 'pagecache'],
    'after'  => ['pagecache', 'performance', 'toolbar'],
];
```

### 글로벌 필터
```php
public array $globals = [
    'before' => [
        'csrf',
        'csrf' => ['except' => 'api/*'],  // URI 예외
    ],
    'after' => [],
];
```

### HTTP 메서드 필터
```php
public array $methods = [
    'POST' => ['invalidchars', 'csrf'],
    'GET'  => ['csrf'],
];
```

### 라우트별 필터
```php
public array $filters = [
    'auth'  => ['before' => ['admin/*']],
    'group:admin,superadmin' => ['before' => ['admin/*']],  // 인자 전달
];
```

## 실행 순서

**Before**: required → globals → methods → filters → route
**After**: route → filters → globals → required

## 내장 필터

| 필터 | 용도 |
|------|------|
| `csrf` | CSRF 보호 |
| `secureheaders` | 보안 헤더 추가 |
| `cors` | CORS |
| `forcehttps` | HTTPS 강제 |
| `invalidchars` | 잘못된 UTF-8/제어 문자 차단 |
| `honeypot` | 허니팟 방어 |
| `toolbar` | 디버그 툴바 |
| `pagecache` | 페이지 캐시 |
| `performance` | 성능 메트릭 |

## 필터 확인 명령
```bash
php spark filter:check get /
```
