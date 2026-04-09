# CI4 Security 라이브러리 공식 문서

> 출처: https://codeigniter4.github.io/userguide/libraries/security.html
> 최종 갱신: 2026-04-08

## CSRF 보호

### 보호 방식

| 방식 | 패턴 | 설정값 |
|------|------|--------|
| **Cookie-Based** (기본) | Double Submit Cookie | `$csrfProtection = 'cookie'` |
| **Session-Based** (권장) | Synchronizer Token | `$csrfProtection = 'session'` |

> **경고 (CI4 공식)**: Cookie-Based는 Same-site 공격을 방어하지 못한다. 세션 사용 시 반드시 Session-Based 사용.

### Config/Security.php

```php
<?php
namespace Config;

use CodeIgniter\Config\BaseConfig;

class Security extends BaseConfig
{
    public $csrfProtection  = 'session';  // 'cookie' or 'session'
    public $tokenRandomize  = true;       // BREACH 공격 방어
    public $regenerate      = true;       // 매 요청마다 토큰 재생성
    public bool $redirect   = true;       // 실패 시 이전 페이지로 리다이렉트 (v4.5.0+)
}
```

### 활성화: Config/Filters.php

```php
public $globals = [
    'before' => [
        'csrf',
    ],
];
```

### URI 예외 설정

```php
public $globals = [
    'before' => [
        'csrf' => ['except' => ['api/record/save']],
        // 정규식 지원
        'csrf' => ['except' => ['api/record/[0-9]+']],
    ],
];
```

### 토큰 처리

**HTML 폼:**
```php
<?= form_open('submit') ?>  <!-- 자동 CSRF 필드 삽입 -->
<?= csrf_field() ?>         <!-- 수동 삽입 -->
```

**AJAX/JSON:**
```php
<?= csrf_meta() ?>  <!-- meta 태그로 JS에서 접근 -->
```

### 토큰 검증 순서
1. `$_POST` 배열
2. HTTP 헤더
3. `php://input` (JSON)
4. `php://input` (PUT/PATCH/DELETE raw body)

### AJAX 요청 시 CSRF 실패
- 리다이렉트 대신 `SecurityException` 발생

## sanitizeFilename()

디렉토리 트래버설 방지:
```php
$path = $security->sanitizeFilename($request->getVar('filepath'));
```
