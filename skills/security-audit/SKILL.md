---
name: security-audit
description: >
  6개 도메인(공통/PHP·CI4/MySQL 8.x/AWS Lambda/CI·CD·공급망/프로세스) 통합 보안 감사 스킬.
  OWASP Top 10, CWE Top 25, OWASP ASVS L1, CIS MySQL Benchmark, OWASP Serverless Top 10,
  SLSA L1, OWASP SAMM, STRIDE 위협 모델링 등 13개 보안 프레임워크를 도메인별로 적용한다.
  코드 작성/수정/리뷰 시 보안 취약점을 감지하고 보고한다.
  보안 이슈 발견 시 즉시 Checkpoint를 발동하여 사용자에게 보고한다.
triggers:
  - 파일 수정/생성 시 자동 (CLAUDE.md §7 Proactive Security Detection과 연동)
  - "보안 감사", "보안 점검", "security audit", "취약점 점검"
severity_levels:
  Critical: 즉시 Checkpoint 발동, 사용자 보고 후 수정
  High: Post-Audit [Security] 항목에 보고
  Medium: Post-Audit [Security] 항목에 참고 기록
  Low: 권고사항으로 기록, 수정 선택적
compatibility: >
  CLAUDE.md §7 3등급 보안 감지 체계(Critical/High/Medium)와 호환.
  본 스킬은 §7의 상세 구현이며 패턴을 확장한다.
  §7의 3등급에 Low 등급을 추가하여 4등급 체계로 확장 운용한다
  (Low는 권고사항으로, §7의 Checkpoint/Post-Audit 프로세스에는 영향 없음).
domain_triggers:
  공통: 모든 코드 변경 시 항상 적용
  PHP/CI4: app/ 하위 PHP 파일, composer.json 변경 시
  MySQL: 마이그레이션 파일, DB 스키마/쿼리 작업 시
  Lambda: Lambda 함수(Python), serverless.yml, IAM 정책 변경 시
  CI/CD: 파이프라인 설정, 의존성 파일 변경 시
  프로세스: 아키텍처 변경, 설계 리뷰 시
version: 1.0.0
depends_on: []
conflicts_with: []
min_claude_md_version: "3.2"
---

# Security Audit Skill

6개 도메인 통합 보안 감사 스킬. 작업 컨텍스트에 따라 해당 도메인 섹션이 선택 적용된다.

---

## Part A: PHP/CI4 + OWASP Top 10 (기존)

### 1. OWASP Top 10 — CI4 매핑 체크리스트

### A01: Broken Access Control (접근 제어 취약)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| `setAutoRoute(true)` 활성화 여부 | **Critical** | `Routes.php`에서 `setAutoRoute(false)` 필수. 모든 라우트를 명시적으로 정의 |
| 인증 필터 미적용 엔드포인트 | **High** | `Filters.php`에서 API 라우트에 인증 필터 적용 |
| 수평적 권한 상승 (타인 데이터 접근) | **High** | `$id` 파라미터로 조회 시 소유권 검증 필수 |
| 디버그/테스트 컨트롤러 프로덕션 노출 | **High** | `FakeLogin`, `Test` 등 개발용 컨트롤러는 환경 제한 또는 제거 |

```php
// 위험: AutoRoute가 켜져 있으면 모든 public 메서드가 URL로 접근 가능
$routes->setAutoRoute(true);  // CRITICAL: false로 변경 필수

// 안전: 명시적 라우트 + 인증 필터
$routes->group('api', ['filter' => 'auth'], function ($routes) {
    $routes->resource('orders', ['controller' => 'Api\OrderController']);
});
```

### A02: Cryptographic Failures (암호화 실패)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| 하드코딩된 시크릿 (API 키, IP, 비밀번호) | **Critical** | `.env` 파일로 이동, `env()` 함수로 참조 |
| 평문 비밀번호 저장 | **Critical** | `password_hash()` + `PASSWORD_BCRYPT` 사용 |
| HTTPS 미강제 | **High** | `Filters.php`에서 `forcehttps` 필터 활성화 |
| 취약한 암호화 알고리즘 | **Medium** | CI4 `Encryption` 서비스는 AES-256-CTR 기본값 확인 |

```php
// 위험: 소스코드에 시크릿 하드코딩
define('HERMES', '10.41.82.142');
define('KAKAO_APP_KEY', '3d9c4c950f418d791c089f9c3ef8e26a');

// 안전: .env에서 로드
define('HERMES', env('HERMES_HOST'));
define('KAKAO_APP_KEY', env('KAKAO_APP_KEY'));
```

### A03: Injection (인젝션)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| raw 쿼리에 변수 직접 삽입 | **Critical** | 쿼리빌더 바인딩 또는 `$db->query($sql, $bindings)` 사용 |
| `$this->request->getPost()` 미검증 사용 | **High** | `$this->validate()` 후 사용 |
| `like()` 조건에 사용자 입력 직접 사용 | **Medium** | 와일드카드 이스케이프 처리 |

```php
// 위험: 변수 직접 삽입
$builder->where("bn_starttime <= '$today'");

// 안전: 바인딩 사용
$builder->where('bn_starttime <=', $today);
```

### A04: Insecure Design (불안전한 설계)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| 비즈니스 로직이 Controller에 존재 | **Medium** | 3계층 아키텍처 적용 (Controller → Library → Model) |
| Rate Limiting 미적용 | **High** | CI4 `Throttler` 라이브러리 사용 |
| 결제/인증 등 민감 작업의 트랜잭션 미사용 | **High** | `$db->transStart()` / `$db->transComplete()` 필수 |

### A05: Security Misconfiguration (보안 설정 오류)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| CSRF 필터 비활성화 | **High** | `Filters.php`의 `$globals['before']`에 `'csrf'` 추가 (API 토큰 인증 시 별도 처리) |
| CORS 무제한 허용 | **High** | `Cors.php`에서 허용 도메인 명시 |
| 에러 상세 노출 (`CI_ENVIRONMENT=development`) | **High** | 프로덕션에서 `production` 설정 확인 |
| `SecureHeaders` 필터 비활성화 | **Medium** | `$globals['after']`에 `'secureheaders'` 추가 |
| 디버그 툴바 프로덕션 노출 | **Medium** | `Toolbar` 필터가 `development`에서만 활성화 확인 |

```php
// 권장 Filters.php 설정
public array $globals = [
    'before' => [
        'csrf',
        'invalidchars',
    ],
    'after' => [
        'secureheaders',
    ],
];
```

### A06: Vulnerable & Outdated Components (취약한 컴포넌트)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| Composer 패키지 취약점 | **High** | `composer audit` 정기 실행 |
| CI4 프레임워크 버전 | **Medium** | `composer show codeigniter4/framework` 확인 |
| PHP 버전 EOL 여부 | **Medium** | PHP 8.1 이상 권장 |

### A07: Identification & Authentication Failures (인증 실패)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| 비밀번호 복잡도 미검증 | **Medium** | 최소 8자, 대소문자+숫자+특수문자 |
| 세션 고정 공격 | **Medium** | 로그인 성공 시 `session()->regenerate()` 호출 |
| 브루트포스 미방어 | **High** | 로그인 실패 횟수 제한 + Throttler |
| 쿠키 기반 인증의 SameSite 미설정 | **Medium** | `Config\Cookie`에서 `SameSite=Lax` 또는 `Strict` |

### A08: Software & Data Integrity Failures (무결성 실패)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| Webhook 서명 미검증 | **High** | Stripe, 결제사 등 webhook은 서명 검증 필수 |
| 파일 업로드 무결성 | **High** | MIME 타입 + 매직 바이트 검증 (확장자만 체크 금지) |
| Composer lock 파일 미커밋 | **Medium** | `composer.lock`을 Git에 포함 |

```php
// 위험: 확장자만 체크
$imageFileType = pathinfo($files["name"], PATHINFO_EXTENSION);
if ($imageFileType != "jpg" && $imageFileType != "png") { ... }

// 안전: MIME 타입 + 매직 바이트 검증
$finfo = new \finfo(FILEINFO_MIME_TYPE);
$mimeType = $finfo->file($files['tmp_name']);
$allowedMimes = ['image/jpeg', 'image/png', 'image/gif'];
if (!in_array($mimeType, $allowedMimes, true)) {
    throw new \Exception('허용되지 않는 파일 형식입니다.');
}
```

### A09: Security Logging & Monitoring Failures (로깅 실패)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| 로그인 실패 미기록 | **Medium** | `log_message('warning', ...)` 사용 |
| 권한 없는 접근 시도 미기록 | **Medium** | Filter에서 거부 시 로깅 |
| 민감 데이터 로그 기록 | **High** | 비밀번호, 토큰, 카드번호 등 로그에 기록 금지 |

### A10: Server-Side Request Forgery (SSRF)

| 점검 항목 | 위험 수준 | CI4 적용 방법 |
|-----------|-----------|---------------|
| 사용자 입력 URL로 서버 측 HTTP 요청 | **High** | 허용된 도메인/IP 화이트리스트 검증 |
| 내부 네트워크 접근 가능 | **High** | 로컬/프라이빗 IP 대역 차단 (`10.x`, `172.16.x`, `192.168.x`) |
| `curl_exec`에 사용자 입력 URL 직접 사용 | **Critical** | URL 검증 후 허용 목록 대조 |

---

### 2. 코드 패턴 감지 규칙

파일을 읽거나 수정할 때 아래 패턴이 발견되면 **즉시 보고**한다.

### Critical (즉시 Checkpoint)

| 패턴 | 감지 방법 | 조치 |
|------|-----------|------|
| 하드코딩된 IP/도메인 | `\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}` 패턴 | `.env`로 이동 제안 |
| 하드코딩된 API 키/시크릿 | `define('.*KEY', '.*')`, `$apiKey = '.*'` 패턴 | `.env`로 이동 제안 |
| raw 쿼리 변수 직접 삽입 | `"$variable"` 또는 `'$variable'` in SQL 문자열 | 바인딩으로 변경 제안 |
| `setAutoRoute(true)` | Routes.php 내 해당 설정 | `false`로 변경 제안 |
| 프로덕션 부적합 코드 | `FakeLogin`, `TestController`, `var_dump`, `die(` | 환경 제한 또는 제거 제안 |

### High (보고 후 수정 권고)

| 패턴 | 감지 방법 | 조치 |
|------|-----------|------|
| 확장자만 체크하는 파일 검증 | `pathinfo(.*PATHINFO_EXTENSION)` 단독 사용 | MIME 타입 검증 추가 권고 |
| CSRF 필터 주석 처리 | `// 'csrf'` in Filters.php | 활성화 권고 |
| `SELECT *` 사용 | `select('*')` 또는 `->get()` without `select()` | 필요 컬럼만 명시 권고 |
| 에러 메시지에 내부 정보 노출 | `$e->getMessage()` 직접 반환 | 사용자용 메시지로 래핑 권고 |

### Medium (참고 보고)

| 패턴 | 감지 방법 | 조치 |
|------|-----------|------|
| `@` 에러 억제 연산자 | `@mkdir`, `@setcookie` 등 | 명시적 에러 처리로 변경 권고 |
| `exit` / `die` 사용 | Controller 내 `exit;`, `die(` | CI4 응답 객체 사용 권고 |
| HTTP 200으로 에러 반환 | `responseJsonStatus(200, errorData)` | 적절한 HTTP 상태코드 사용 권고 |

---

### 3. CI4 보안 설정 권장 구성

### Filters.php 권장 설정

```php
public array $globals = [
    'before' => [
        'csrf',          // CSRF 보호 (API 토큰 인증 시 except 설정)
        'invalidchars',  // 유효하지 않은 문자 필터링
    ],
    'after' => [
        'secureheaders', // 보안 헤더 (X-Frame-Options, X-Content-Type-Options 등)
    ],
];

// API 엔드포인트에 인증 필터 적용
public array $filters = [
    'auth' => ['before' => ['api/*']],
    'csrf' => ['before' => ['api/*' => 'except']],  // API는 토큰 인증으로 CSRF 대체
];
```

### Security.php 권장 설정

```php
public string $csrfProtection = 'session';  // cookie보다 session 권장
public bool $csrfRegenerate = true;          // 매 요청마다 토큰 재생성
public int $csrfExpire = 7200;               // 토큰 유효기간
```

### Cors.php 권장 설정

```php
public array $allowedOrigins = ['https://www.hongcafe.com'];  // 와일드카드(*) 금지
public array $allowedMethods = ['GET', 'POST', 'PUT', 'DELETE'];
public bool $allowCredentials = true;
```

---

### 4. 보안 네거티브 테스트 템플릿

모든 API 엔드포인트에 대해 아래 보안 테스트를 포함해야 한다.

```php
namespace Tests\Security;

use CodeIgniter\Test\CIUnitTestCase;
use CodeIgniter\Test\FeatureTestTrait;

/**
 * 보안 네거티브 테스트: 인증/인가/입력 검증 실패 케이스.
 */
class {Feature}SecurityTest extends CIUnitTestCase
{
    use FeatureTestTrait;

    /**
     * 미인증 사용자의 보호된 엔드포인트 접근을 거부한다.
     */
    public function testUnauthenticatedAccessDenied()
    {
        $result = $this->get('api/{features}');
        $result->assertStatus(401);
    }

    /**
     * 타인의 리소스에 대한 접근을 거부한다 (수평적 권한 상승 방지).
     */
    public function testHorizontalPrivilegeEscalation()
    {
        // 사용자 A로 인증 후 사용자 B의 데이터 접근 시도
        $result = $this->withHeaders(['Authorization' => 'Bearer {userA_token}'])
                       ->get('api/{features}/{userB_resource_id}');
        $result->assertStatus(403);
    }

    /**
     * SQL Injection 패턴 입력을 안전하게 처리한다.
     */
    public function testSqlInjectionPrevention()
    {
        $result = $this->withBodyFormat('json')
                       ->post('api/{features}', [
                           'name' => "'; DROP TABLE users; --",
                       ]);
        // 서버 에러가 아닌 검증 실패로 처리되어야 함
        $this->assertTrue(in_array($result->response()->getStatusCode(), [400, 422]));
    }

    /**
     * XSS 페이로드 입력을 안전하게 처리한다.
     */
    public function testXssPrevention()
    {
        $result = $this->withBodyFormat('json')
                       ->post('api/{features}', [
                           'name' => '<script>alert("xss")</script>',
                       ]);
        if ($result->response()->getStatusCode() === 201) {
            $body = json_decode($result->response()->getBody(), true);
            $this->assertStringNotContainsString('<script>', $body['data']['name'] ?? '');
        }
    }

    /**
     * 허용되지 않은 파일 형식 업로드를 거부한다.
     */
    public function testMaliciousFileUploadRejected()
    {
        // PHP 파일을 이미지 확장자로 업로드 시도
        $result = $this->withBodyFormat('json')
                       ->post('api/{features}/upload', [
                           'file' => 'malicious.php.jpg',
                       ]);
        $result->assertStatus(400);
    }

    /**
     * Rate Limiting이 적용되어 과도한 요청을 차단한다.
     */
    public function testRateLimitingApplied()
    {
        for ($i = 0; $i < 100; $i++) {
            $result = $this->get('api/{features}');
        }
        $result->assertStatus(429);
    }
}
```

---

### 5. 출력 형식

보안 감사 수행 시 아래 순서로 보고한다:

1. **감사 범위** — 대상 파일/기능
2. **발견 사항** — Critical / High / Medium 등급별 정리
3. **권고 조치** — 각 발견 사항별 구체적 수정 방법
4. **CI4 설정 변경** — Filters, Security, Cors 등 설정 파일 수정 사항
5. **보안 테스트** — 추가해야 할 테스트 케이스

---

### 6. 자가 검증 체크리스트 (PHP/CI4)

코드 작성/수정/리뷰 시 반드시 확인:
- [ ] AutoRoute가 비활성화되어 있는가
- [ ] 하드코딩된 시크릿(IP, API 키, 비밀번호)이 없는가
- [ ] raw 쿼리에 변수가 직접 삽입되지 않았는가
- [ ] CSRF 필터가 활성화되어 있는가 (API 토큰 인증 시 별도 처리)
- [ ] 파일 업로드 시 MIME 타입 검증이 포함되어 있는가
- [ ] 인증 필요 엔드포인트에 인증 필터가 적용되어 있는가
- [ ] 에러 메시지에 내부 시스템 정보가 노출되지 않는가
- [ ] 프로덕션 부적합 코드(FakeLogin, var_dump, die)가 없는가
- [ ] 보안 네거티브 테스트 케이스가 포함되어 있는가
- [ ] CORS 설정에 와일드카드(*)가 사용되지 않았는가

---

## Part B: CWE Top 25 + OWASP ASVS + 비즈니스 로직 (공통)

### 적용 시점
모든 코드 변경(신규 작성, 수정, 리뷰), 의존성 추가/업데이트, 배포 전 최종 점검 시 항상 적용.

### 7. CWE Top 25 핵심 패턴

| CWE ID | 취약점 | 심각도 | 자동 감지 패턴 | 위반 시 조치 |
|--------|--------|--------|----------------|--------------|
| CWE-79 | XSS | **Critical** | `echo\s+\$_(GET\|POST\|REQUEST)`, `innerHTML\s*=` | 즉시 Checkpoint. `esc()` 적용 |
| CWE-89 | SQL Injection | **Critical** | `\$db->query\(.+\$`, `"SELECT.*"\s*\.\s*\$` | 즉시 Checkpoint. Prepared Statement |
| CWE-78 | OS Command Injection | **Critical** | `(exec\|system\|passthru\|shell_exec\|popen\|proc_open)\s*\(` | 즉시 Checkpoint |
| CWE-862 | Missing Authorization | **High** | Controller에 인증 필터 미적용 | Post-Audit 보고 |
| CWE-200 | 정보 노출 | **High** | `var_dump\(`, `print_r\(`, `phpinfo\(` | Post-Audit 보고 |
| CWE-502 | 안전하지 않은 역직렬화 | **Critical** | `unserialize\(\$`, `pickle\.loads\(` | 즉시 Checkpoint |
| CWE-918 | SSRF | **High** | `file_get_contents\(\$`, `requests\.get\(\s*\w+\)` | Post-Audit 보고 |

### 8. OWASP ASVS Level 1 핵심 항목

| 영역 | 검사 항목 | 심각도 |
|------|-----------|--------|
| V2 인증 | 비밀번호 최소 8자, bcrypt/argon2 사용 | **High** |
| V3 세션 관리 | 세션 토큰 무작위성, 만료 시간 설정 | **High** |
| V4 접근 제어 | 수직/수평 권한 상승 방지 | **Critical** |
| V5 입력 검증 | 모든 사용자 입력에 서버 측 검증 | **High** |
| V7 에러 처리 | 스택 트레이스/내부 정보 미노출 | **Medium** |
| V8 데이터 보호 | 민감 데이터 전송 시 암호화 | **High** |

### 9. SCA (Software Composition Analysis)

| 검사 | 명령어 | 심각도 | 위반 시 조치 |
|------|--------|--------|--------------|
| PHP 의존성 취약점 | `composer audit` | **High** (CVE 시 Critical) | 취약 패키지 업데이트 |
| Python 의존성 취약점 | `pip-audit` | **High** (CVE 시 Critical) | 취약 패키지 업데이트 |

### 10. 비즈니스 로직 보안

| 검사 항목 | 심각도 | 검사 방법 |
|-----------|--------|-----------|
| 주문 금액 조작 방지 | **Critical** | 서버 DB 가격 vs 클라이언트 가격 비교 로직 |
| 재고 음수 방지 | **High** | 동시성 제어(비관적/낙관적 락) |
| 쿠폰/할인 중복 적용 방지 | **High** | 할인 로직 중복 검증 |
| 결제 상태 전이 무결성 | **Critical** | 상태 머신 패턴으로 유효하지 않은 전이 차단 |
| Rate Limiting | **High** | 민감 API(로그인, 결제)에 요청 제한 |

### 11. CERT PHP 금지 함수

| 심각도 | 금지 함수 | 대안 |
|--------|-----------|------|
| **Critical** | `eval()` | 절대 사용 금지 |
| **Critical** | `exec()`, `system()`, `passthru()`, `shell_exec()` | 사용자 입력 미포함 보장 |
| **Critical** | `unserialize()` (사용자 입력) | `json_decode()` |
| **High** | `extract()` | 명시적 변수 할당 |
| **High** | `assert()` (문자열 인수) | 조건문 대체 |

---

## Part C: MySQL 8.x (CIS Benchmark Level 1)

### 적용 시점
마이그레이션 파일 생성/수정, DB 스키마 변경, 쿼리 최적화 작업 시.

### 12. CIS MySQL 8.0 Benchmark 핵심

| 검사 항목 | 심각도 | 검사 방법 |
|-----------|--------|-----------|
| `root` 계정 원격 접속 비활성화 | **Critical** | `SELECT host FROM mysql.user WHERE user='root'` — `%` 없어야 함 |
| 비밀번호 정책 활성화 | **High** | `SHOW VARIABLES LIKE 'validate_password%'` |
| SSL/TLS 연결 강제 | **High** | `SHOW VARIABLES LIKE 'require_secure_transport'` — `ON` |
| 최소 권한 (앱 전용 계정) | **High** | `GRANT ALL` 미사용, 필요 권한만 부여 |
| `local_infile` 비활성화 | **High** | `SHOW VARIABLES LIKE 'local_infile'` — `OFF` |
| `general_log` 프로덕션 비활성화 | **Medium** | `SHOW VARIABLES LIKE 'general_log'` — `OFF` |
| 감사 로그 활성화 | **Medium** | `SHOW VARIABLES LIKE 'audit_log%'` |

### 13. 마이그레이션 자동 감지

| 패턴 | 심각도 | 위반 시 조치 |
|------|--------|--------------|
| 평문 비밀번호 저장 컬럼 | **Critical** | bcrypt/argon2 적용 확인 |
| 인덱스 없는 외래키 참조 컬럼 | **High** | INDEX 추가 |
| `TEXT`/`BLOB` 과다 사용 (3개+) | **Medium** | 정규화 검토 |

---

## Part D: AWS Lambda / Python (Serverless)

### 적용 시점
Lambda 함수 코드(Python), serverless.yml/SAM 설정, IAM 역할/정책 변경 시.

### 14. OWASP Serverless Top 10

| 항목 | 심각도 | 자동 감지 패턴 | 위반 시 조치 |
|------|--------|----------------|--------------|
| 이벤트 데이터 인젝션 | **Critical** | `event[` 검증 없이 쿼리/명령에 직접 사용 | 즉시 Checkpoint |
| 인증/인가 우회 | **Critical** | `"authorizationType": "NONE"` | 즉시 Checkpoint |
| 안전하지 않은 시크릿 저장 | **Critical** | `os.environ[.*KEY\|SECRET\|PASSWORD]` 직접 사용 | 즉시 Checkpoint. Secrets Manager 사용 |
| 과도한 IAM 권한 | **High** | `"Action": "*"`, `"Resource": "*"` | Post-Audit 보고. 최소 권한 적용 |
| 타임아웃/메모리 미설정 | **Medium** | `timeout` 미정의 | 참고 기록 |
| 에러 정보 노출 | **High** | `traceback.format_exc()` 응답 포함 | Post-Audit 보고 |

### 15. AWS Well-Architected Security Pillar

| 검사 항목 | 심각도 | 위반 시 조치 |
|-----------|--------|--------------|
| VPC 내 Lambda 실행 (DB 접근 시) | **High** | Post-Audit 보고 |
| 전송 중 암호화 (TLS) | **High** | HTTPS 엔드포인트만 호출 |
| 저장 중 암호화 (KMS) | **Medium** | 환경변수 KMS 암호화 |
| GuardDuty Lambda Protection 활성화 | **Medium** | 런타임 위협 탐지 권고 |
| CloudTrail 이벤트 로깅 | **High** | Lambda API 호출 추적 보장 |

---

## Part E: CI/CD 및 공급망 보안 (SLSA Level 1)

### 적용 시점
CI/CD 파이프라인 설정 변경, `composer.json`/`requirements.txt`/`package.json` 변경, Docker 빌드 설정 변경 시.

### 16. SLSA Level 1 준수

| 검사 항목 | 심각도 | 위반 시 조치 |
|-----------|--------|--------------|
| 빌드 스크립트 버전 관리 | **High** | CI/CD 설정 파일 Git 포함 확인 |
| 빌드 프로세스 문서화 | **Medium** | 빌드 절차 문서 존재 확인 |
| 빌드 로그 보존 | **Medium** | 파이프라인 로그 보존 설정 확인 |

### 17. 의존성·공급망 보안

| 검사 항목 | 심각도 | 자동 감지 패턴 | 위반 시 조치 |
|-----------|--------|----------------|--------------|
| `composer.lock` 커밋 여부 | **High** | `.gitignore`에 포함 시 | lock 파일 반드시 커밋 |
| `requirements.txt` 버전 고정 | **High** | `==` 없는 패키지 | 정확한 버전 고정 |
| Critical CVE 의존성 | **Critical** | `composer audit` / `pip-audit` | 즉시 Checkpoint |
| 프라이빗 레지스트리 토큰 노출 | **Critical** | `auth.json` 토큰 하드코딩 | 즉시 Checkpoint |
| 서드파티 Action 버전 미고정 | **High** | `uses:.*@master\|@main` | SHA 해시로 고정 |
| 시크릿 환경변수 직접 노출 | **Critical** | `echo \${{ secrets.` | 즉시 Checkpoint |

---

## Part F: 프로세스 및 거버넌스 (OWASP SAMM + STRIDE)

### 적용 시점
신규 기능 설계(Pre-Plan), 아키텍처 변경, 보안 관련 설계 결정, 정기 보안 점검 시.

### 18. OWASP SAMM 핵심 영역

| 영역 | 검사 항목 | 심각도 |
|------|-----------|--------|
| Design | 위협 모델링 수행 여부 | **High** |
| Implementation | 보안 코딩 가이드 준수 | **High** |
| Verification | 보안 테스트 존재 여부 | **High** |
| Operations | 인시던트 대응 절차 정의 | **Medium** |

### 19. STRIDE 위협 모델링 체크리스트

신규 기능 또는 아키텍처 변경 시 적용:

| 위협 | 질문 | 심각도 |
|------|------|--------|
| **S**poofing | 인증되지 않은 사용자가 타인으로 위장 가능한가? | **Critical** |
| **T**ampering | 전송 중/저장 중 데이터가 변조될 수 있는가? | **High** |
| **R**epudiation | 악의적 행위를 부인할 수 있는가? (감사 로그) | **Medium** |
| **I**nformation Disclosure | 민감 정보가 의도치 않게 노출되는가? | **High** |
| **D**enial of Service | 과도한 요청으로 서비스 중단 가능한가? | **High** |
| **E**levation of Privilege | 일반 사용자가 관리자 권한 획득 가능한가? | **Critical** |

### 20. Security as Code (OPA/Cedar 정책 패턴)

| 검사 항목 | 심각도 | 위반 시 조치 |
|-----------|--------|--------------|
| 접근 제어 정책 코드화 | **Medium** | IAM/RBAC 규칙이 코드로 관리되는지 확인 |
| 정책 변경 이력 추적 | **High** | 정책 파일 Git 버전 관리 확인 |
| 배포 전 정책 검증 | **High** | CI/CD에서 정책 검증 단계 포함 확인 |

---

## Quick Reference: 자동 감지 통합 패턴

### Critical (즉시 Checkpoint)

```
# 하드코딩된 시크릿
(?i)(api[_-]?key|secret[_-]?key|password|token|credential)\s*[=:]\s*['"][A-Za-z0-9+/=]{8,}['"]

# SQL Injection
\$db->query\s*\(\s*["'].*\.\s*\$
"SELECT.*"\s*\.\s*\$

# 위험 함수
\beval\s*\(
(exec|system|passthru|shell_exec|popen|proc_open)\s*\(

# 역직렬화
unserialize\s*\(\s*\$
pickle\.loads\s*\(

# CI4 자동 라우팅
setAutoRoute\s*\(\s*true\s*\)

# 프로덕션 부적합 코드
\bFakeLogin\b
\bvar_dump\s*\(

# Lambda 인증 미설정
"authorizationType"\s*:\s*"NONE"

# 공급망 시크릿 노출
echo\s+\$\{\{\s*secrets\.
```

### High (Post-Audit 보고)

```
# CSRF/CORS 비활성화
\$CSRFProtection\s*=\s*false
'allowedOrigins'\s*=>\s*\[\s*'\*'\s*\]

# 확장자만 체크하는 파일 검증
getExtension\(\)

# 인증 필터 미적용
\$routes->(get|post|put|delete|resource)\(

# 에러 내부정보 노출
\$exception->getMessage\(\).*respond

# PHP 위험 함수
\bextract\s*\(
\bassert\s*\(\s*['"]

# IAM 과도한 권한
"Action"\s*:\s*"\*"
"Resource"\s*:\s*"\*"
```

### Medium (참고 기록)

```
# @ 에러 억제
@\$

# exit/die
\b(die|exit)\s*\(

# HTTP 200으로 에러 반환
return\s+\$this->respond\(.*error.*,\s*200\)
```
