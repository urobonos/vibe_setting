# PHP 공식 보안 권장사항

> 출처: https://www.php.net/manual/en/security.php
> 최종 갱신: 2026-04-08

## 1. SQL 인젝션 방지

```php
// 금지: 문자열 연결
$query = "SELECT * FROM users WHERE id = " . $_GET['id'];

// 필수: Prepared Statement
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
$stmt->execute([$_GET['id']]);
```

- 파라미터화된 쿼리/Prepared Statement 필수
- 사용자 입력을 SQL에 직접 연결 금지

## 2. 사용자 입력 처리

- `$_GET`, `$_POST`, `$_COOKIE`, `$_SERVER` 절대 신뢰 금지
- 항상 검증(validate) + 정제(sanitize) 후 사용
- `filter_var()` 함수 활용

```php
$email = filter_var($_POST['email'], FILTER_VALIDATE_EMAIL);
```

## 3. 프로덕션 에러 처리

```php
// 프로덕션 필수 설정
ini_set('display_errors', 0);        // 사용자에게 에러 미표시
error_reporting(E_ALL);               // 모든 에러 감지
ini_set('log_errors', 1);             // 파일로 로깅
ini_set('error_log', '/path/log');    // 웹 루트 외부
```

- 상세 에러 메시지 사용자 노출 금지
- 404 반환 (403 대신) — 파일 존재 여부 노출 방지

## 4. 파일시스템 보안

- include 파일 직접 실행 방지: `defined('APPLICATION') or die()`
- 코드를 웹 루트 외부에 배치
- .htaccess로 라이브러리 디렉토리 차단

## 5. 세션 보안

- 로그인 후 세션 ID 재생성
- 적절한 세션 타임아웃 설정
- 안전한 세션 저장소 사용

## 6. 위험 함수

| 함수 | 위험 | 대안 |
|------|------|------|
| `eval()` | 임의 코드 실행 | 사용 금지 |
| `exec()`, `system()`, `passthru()` | OS 명령 실행 | escapeshellarg() 또는 금지 |
| `shell_exec()`, `popen()`, `proc_open()` | OS 명령 실행 | 금지 |
| `unserialize()` | 객체 인젝션 | json_decode() 사용 |
| `extract()` | 변수 오염 | 직접 할당 |
| `assert()` | 코드 실행 | 사용 금지 |

## 7. 일반 원칙

- **Deny by Default**: 기본 거부, 명시적 허용
- **단일 진입점**: 모든 요청을 index.php로 라우팅
- **PHP 버전 미노출**: `expose_php = Off`
- **파일 업로드 검증**: 확장자만 확인 금지, MIME 타입 + 내용 검증
