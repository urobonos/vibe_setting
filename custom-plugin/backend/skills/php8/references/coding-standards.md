# PHP / CI4 코딩 표준

## 1. PSR 준수

- **PSR-1**: `<?php` 태그, UTF-8(BOM 없음), 오토로딩 표준
- **PSR-4**: 네임스페이스 = 디렉토리 구조. `Modules\{BC}\{Layer}`
- **PSR-12**: 인덴트 **4칸 스페이스**, 여는 중괄호 같은 줄(메서드/클래스는 다음 줄)
- **Strict Types**: 모든 PHP 파일에 `declare(strict_types=1);` 선언 필수
  **Why:** strict_types 미선언 시 PHP 가 `"5"` → `5` 같은 암묵적 캐스팅을 허용해 ID 비교·금액 계산에서 silent 데이터 오염이 발생한다.
- **mixed 반환 타입 금지**: 함수/메서드 반환 타입에 `mixed` 사용 금지. 구체적 타입(`string`, `int`, `array`, `?Type` 등)을 명시
  **Why:** mixed 반환은 호출처에서 모든 타입 분기를 떠안게 되어 정적 분석·IDE 자동완성·Phpstan 검증을 모두 무력화한다.

```php
<?php

declare(strict_types=1);

namespace App\Modules\Commerce\Services;
```

> `declare(strict_types=1)`은 `<?php` 바로 다음, namespace 선언 전에 위치한다.
> 해당 파일 내에서 호출하는 함수의 파라미터/반환값에 대해 자동 타입 캐스팅을 차단한다.

### 파일명 규칙

| 대상 | 스타일 | 예시 |
|------|------|------|
| 클래스 파일 | `PascalCase.php` | `CallService.php`, `CounselorRepository.php` |
| CI4 설정 파일 | `PascalCase.php` (프레임워크 표준) | `Routes.php`, `Services.php`, `Filters.php` |
| 국가별 Config | `lowercase.php` | `jp.php`, `us.php`, `kr.php` |
| 언어 파일 | `lowercase.php` | `messages.php`, `validation.php` |
| 테스트 파일 | `{TargetClass}Test.php` | `CallServiceTest.php` |

- 국가 Config 파일명은 **lowercase** — CI4 Config 로더가 대소문자 구분 환경(Linux)에서도 일관 동작 보장
- 클래스 파일명 = 클래스명. PSR-4 autoload 준수

## 2. 추상화 / 구체화 범위

인터페이스는 해당 모듈의 `Interfaces/` 디렉토리에 배치한다.

### 추상화 필수 (Interface 선행)

| 조건 | 예시 |
|------|------|
| **다른 모듈에서 참조하는 Service** | 모든 공개 Service (모듈 경계 규칙) |
| 2개 이상 구현체가 예상되는 경우 | 결제 수단별 PaymentService |
| 외부 시스템 연동 | SMS, 이메일, 결제 게이트웨이 |
| Repository | 모든 Repository는 Interface 필수 |

### 구체화 허용

| 조건 | 예시 |
|------|------|
| 모듈 내부에서만 사용하는 단일 구현 Service | 단순 내부 헬퍼 |
| 유틸리티/헬퍼 성격 | 날짜 포맷터, 문자열 처리 |

추상화 시 인터페이스 상단에 **추상화 사유 주석 필수**.
**Why:** 사유 주석 없는 Interface 는 시간이 지나면 "왜 추상화했는지" 망각되어 무분별한 메서드 추가로 ISP 원칙이 깨진다.

## 3. 보안 검증 필수

모든 코드는 `security-audit` 스킬의 보안 규칙을 준수. SQL Injection, XSS, CSRF, Mass Assignment 등.
**Why:** 단일 SQLi/XSS 취약점도 다국가 서비스에서는 GDPR·개인정보 유출 사고로 이어져 서비스 중단 + 법적 제재 + 신뢰 손실이 동시에 발생한다.

## 4. 사이드 이펙트 방지

파일 수정 전 모듈 내부 및 모듈 간 영향 범위를 확인한다.

- **Repository 변경 시**: 해당 Repository를 사용하는 Service 확인
- **Service 변경 시**: Controller + 다른 모듈에서 Interface로 참조하는 곳 확인
- **Model 변경 시**: Repository → Service → Controller 전체 확인
- **Interface 변경 시**: 해당 Interface를 참조하는 **모든 모듈** 확인 (가장 위험)
- **Migration 변경 시**: Model `$allowedFields`, `$validationRules` 동기화

## 5. 주석 규칙

### PHPDoc 표준 양식

```php
/**
 * 목적 한 줄 설명. (한국어, 동사형 `~한다`)
 *
 * @param  string      $token       파라미터 설명
 * @param  int         $expSeconds  파라미터 설명
 * @return array|null  반환값 설명
 * @throws \RuntimeException 예외 조건
 */
```

### 대상별 규칙

| 대상 | 필수 여부 | 주석 내용 |
|------|-----------|-----------|
| **클래스** | 필수 | 클래스명 + 역할 설명 (여러 줄 허용) |
| **public/protected 메서드** | 필수 | 목적 한 줄 + `@param` + `@return` + `@throws` |
| **private 메서드** | 필수 | 목적 한 줄 + `@param` + `@return` |
| **Interface** | 필수 | 추상화 사유 + 메서드별 `@param`/`@return` |
| **복잡한 비즈니스 로직** | 필수 | 단계별 인라인 설명 |
| **raw query** | 필수 | QB로 불가능한 사유 명시 |

### 작성 규칙

- 첫 줄: 목적 한 줄 (한국어, `~한다` 종결)
- 빈 줄: 설명과 태그 사이 1줄
- `@param`: 타입 + 변수명 + 설명 (타입 정렬)
- `@return`: 타입 + 설명 (void 생략 가능)
- `@throws`: 예외 클래스 + 발생 조건
- 제네릭 반환: `@return array{key: type}` 형태로 구조 명시

## 6. 날짜/시간 처리

- `date()`, `time()` **사용 금지**. `DateTimeImmutable` 필수.
  **Why:** `date()`/`time()` 은 서버 default timezone 에 묶여 다국가 서비스에서 KR/JP/US 시간대가 뒤섞이고, mutable 객체는 의도치 않은 시점 변경으로 도메인 로직이 오염된다.
- 타임스탬프 필요 시 `(new DateTimeImmutable())->getTimestamp()` 사용
- DB/서버 타임존: UTC 통일

```php
// 금지
$now = date('Y-m-d H:i:s');
$timestamp = time();

// 올바른 사용
$now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
$timestamp = $now->getTimestamp();
$formatted = $now->format('Y-m-d H:i:s');
```
