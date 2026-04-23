---
문서명: Member — Interface Design Document
문서 ID: member-idd
버전: v2.1
적용 표준: MIL-STD-498 (Interface Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-17
작성자: jypark
대상 시스템: Member Module (HongCafe Global Backend)
관련 문서: member-sdd.md, member-srs.md
---

# Member — Interface Design Document

> version: 2.1 | standard: MIL-STD-498 IDD | lastUpdated: 2026-04-17 | module: Member

---

## 1. Scope (범위)

### 1.1 Identification (식별)

본 문서는 HongCafe Global Backend Member 모듈의 인터페이스 설계를 MIL-STD-498 Interface Design Description (IDD) 표준에 따라 명세한다.

| 항목 | 내용 |
|------|------|
| 문서 ID | member-idd |
| 대상 시스템 | Member Module — HongCafe Global Backend |
| 기반 SDD | `member-sdd.md` v2.0 |
| 인터페이스 총수 | 내부 6개 / 외부 4개 |
| 모듈 범위 | 회원가입, 인증(JWT), 마이페이지, 프로필, SNS 연동 |

### 1.2 System Overview (시스템 개요)

Member 모듈은 HongCafe Global Backend Modular Monolith 아키텍처 내에서 회원가입, 로그인, JWT 발급·갱신, 마이페이지 이력 조회, 닉네임/전화번호/비밀번호 변경, 프로필 이미지 업로드, SNS 연동/해제, 회원 탈퇴를 담당한다. SMS Link API(OTP), Kakao AlimTalk(알림), TemplateMail(이메일 인증), AWS S3(프로필 이미지) 외부 시스템과 연동한다.

### 1.3 Document Overview (문서 개요)

본 IDD는 MIL-STD-498 §DI-IPSC-81436 기준에 따라 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 기술한다.

| 섹션 | 내용 |
|------|------|
| §3 | 내부 인터페이스 6개 (IF-INT-001~006) — PHP 시그니처 포함 |
| §4 | 외부 인터페이스 4개 (IF-EXT-001~004) — 프로토콜/인증/타임아웃/재시도 명세 |
| §5 | 이벤트 계약 (Events and Signals) |
| §6 | 에러 처리 계약 (Error Handling Contract) |
| §7 | 데이터 포맷 (Data Formats and Encoding) |
| §8 | 타당성 검토 |
| §9 | 변경 영향 기록 |
| §10 | 요구사항 추적성 매트릭스 |

---

## 2. References (참조 문서)

| 문서 | 위치 / 출처 |
|------|-----------|
| MIL-STD-498 — Software Development and Documentation | US DoD Standards |
| DI-IPSC-81436 — Interface Design Description (IDD) | MIL-STD-498 Data Item |
| member-srs.md v2.0 | `docs/specs/member-srs.md` |
| member-sdd.md v2.0 | `docs/specs/member-sdd.md` |
| RFC 7231 — HTTP/1.1 Semantics and Content | IETF |
| RFC 3339 — Date and Time on the Internet | IETF |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| OWASP Authentication Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html |
| OWASP File Upload Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |

---

## 3. Internal Interfaces (내부 인터페이스)

MIL-STD-498 IDD §3 — 각 내부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-INT-001: MemberRegistrationServiceInterface

#### 3.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | MemberRegistrationServiceInterface |
| 파일 경로 | `app/Modules/Member/Interfaces/MemberRegistrationServiceInterface.php` |
| 제공 컴포넌트 | `MemberRegistrationService` |
| 소비 컴포넌트 | `MemberController` |

#### 3.1.2 Data Elements (데이터 요소)

**register() 입력 스키마:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `email` | string | Y | 이메일 형식 (RFC 5321) |
| `password` | string | Y | 8자 이상, 영문+숫자+특수문자 조합 |
| `nickname` | string | Y | 2~20자, 특수문자 금지(언더스코어 허용) |
| `name` | ?string | N | 실명 |
| `phone` | ?string | N | 전화번호 (하이픈 제외) |

**issueJwtTokens() 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `accessToken` | string | JWT Access Token (15분 만료) |
| `refreshToken` | string | JWT Refresh Token (7일 만료) |
| `csrfToken` | string | HMAC-SHA256 서명 CSRF 토큰 (2시간 만료) |
| `expiresIn` | int | Access Token 만료까지 초 (900) |

**메서드 계약 요약:**

| 메서드 시그니처 | 입력 | 출력 | 예외 |
|----------------|------|------|------|
| `register(array $data): array` | 회원가입 데이터 | 토큰 세트 배열 | `ConflictException` (중복 이메일/닉네임) |
| `login(string $email, string $password): array` | 이메일, 비밀번호 | 토큰 세트 배열 | `UnauthorizedException` (`INVALID_CREDENTIALS`) |
| `loginWithSns(string $provider, string $authCode): array` | Provider명, OAuth 코드 | 토큰 세트 배열 | `InvalidArgumentException` (지원 안 되는 Provider) |
| `logout(int $accountId): void` | 회원 ID | void | — |
| `changePassword(int $accountId, string $currentPw, string $newPw): void` | — | void | `UnauthorizedException` (현재 비밀번호 불일치) |
| `resetPassword(string $token, string $newPw): void` | 재설정 토큰, 새 비밀번호 | void | `BadRequestException` (토큰 만료/무효) |
| `withdraw(int $accountId, ?string $password): void` | 회원 ID, 비밀번호 (선택) | void | `ConflictException` (진행 중 거래 존재) |
| `issueJwtTokens(array $payload): array` | JWT payload 배열 | 토큰+쿠키 세트 | — |

#### 3.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Member/Config/Services.php` |
| 쿠키 발급 | `issueJwtTokens()` 내부에서 `hc_access`, `hc_refresh`, `hc_csrf` 3종 쿠키 Set-Cookie |

#### 3.1.4 Error Handling (에러 처리)

| 예외 클래스 | HTTP | 에러 코드 | 발생 조건 |
|-----------|------|---------|---------|
| `ConflictException` | 409 | `EMAIL_ALREADY_EXISTS` | 이미 등록된 이메일 |
| `ConflictException` | 409 | `NICKNAME_ALREADY_EXISTS` | 이미 사용 중인 닉네임 |
| `UnauthorizedException` | 401 | `INVALID_CREDENTIALS` | 이메일 미존재 또는 비밀번호 불일치 (CWE-204: 동일 메시지) |
| `BadRequestException` | 400 | `INVALID_CERT_TOKEN` | 이메일 인증 토큰 만료/무효 |
| `ConflictException` | 409 | `PENDING_TRANSACTION_EXISTS` | 진행 중 결제/예약으로 탈퇴 불가 |

**CWE-204 대응:** 이메일 미존재 시에도 `password_hash()` 더미 연산 수행으로 응답 시간 균일화.

#### 3.1.5 Data Flow (데이터 흐름)

```
MemberController::join()
  └─ MemberRegistrationService::register($data)
        ├─ MemberRepository::findByEmail(email)     → 중복 확인
        ├─ MemberRepository::findByNickname(nick)   → 중복 확인
        ├─ password_hash(password, PASSWORD_BCRYPT) → 해시 생성
        ├─ MemberRepository::insert(data)            → tb_account INSERT
        ├─ TemplateMail::send(to, 'member.join.cert', vars) → 인증 메일
        └─ issueJwtTokens(payload)                  → 쿠키 3종 Set-Cookie

MemberController::login()
  └─ MemberRegistrationService::login(email, password)
        ├─ MemberRepository::findByEmail(email)     → null 시 더미 hash 연산
        ├─ password_verify(password, hash)
        └─ issueJwtTokens(payload)                  → 쿠키 3종 발급
```

**PHP 시그니처:**

```php
interface MemberRegistrationServiceInterface
{
    /** @throws ConflictException EMAIL_ALREADY_EXISTS / NICKNAME_ALREADY_EXISTS */
    public function register(array $data): array;

    /** @throws UnauthorizedException INVALID_CREDENTIALS (CWE-204: 동일 메시지) */
    public function login(string $email, string $password): array;

    /** @throws InvalidArgumentException 지원 안 되는 Provider */
    public function loginWithSns(string $provider, string $authCode): array;

    public function logout(int $accountId): void;

    /** @throws UnauthorizedException 현재 비밀번호 불일치 */
    public function changePassword(int $accountId, string $currentPw, string $newPw): void;

    /** @throws BadRequestException INVALID_CERT_TOKEN (토큰 만료/무효) */
    public function resetPassword(string $token, string $newPw): void;

    /** @throws ConflictException PENDING_TRANSACTION_EXISTS */
    public function withdraw(int $accountId, ?string $password): void;

    /** JWT 발급 + 쿠키 Set-Cookie (hc_access, hc_refresh, hc_csrf). */
    public function issueJwtTokens(array $payload): array;
}
```

---

### IF-INT-002: MemberProfileServiceInterface

#### 3.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | MemberProfileServiceInterface |
| 파일 경로 | `app/Modules/Member/Interfaces/MemberProfileServiceInterface.php` |
| 제공 컴포넌트 | `MemberProfileService` |
| 소비 컴포넌트 | `MypageController`, `ProfileController` |

#### 3.2.2 Data Elements (데이터 요소)

**uploadProfileImage() 파일 입력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | string | 원본 파일명 |
| `type` | string | 클라이언트 선언 MIME 타입 |
| `tmp_name` | string | 임시 파일 경로 |
| `error` | int | PHP 업로드 에러 코드 |
| `size` | int | 파일 크기 (bytes) |

MIME 이중 검증: 확장자 확인 + `mime_content_type($tmp_name)` 서버 측 확인. 허용 형식: `image/jpeg`, `image/png`, `image/webp`. 최대 크기: 5MB (5,242,880 bytes).

**메서드 계약 요약:**

| 메서드 시그니처 | 입력 | 출력 | 예외 |
|----------------|------|------|------|
| `changeNickname(int $accountId, string $nickname): void` | 회원 ID, 새 닉네임 | void | `ConflictException` (쿨다운 또는 중복) |
| `uploadProfileImage(int $accountId, array $file): string` | 회원 ID, 업로드 파일 | S3 이미지 URL | `BadRequestException` (MIME 검증 실패) |
| `deleteProfileImage(int $accountId): void` | 회원 ID | void | — |
| `updateProfile(int $accountId, array $data): array` | 회원 ID, 변경 데이터 | 업데이트된 프로필 camelCase 배열 | `ValidationException` |
| `connectSns(int $accountId, string $provider, string $authCode): void` | 회원 ID, Provider명, 인가 코드 | void | `ConflictException` (이미 연동된 SNS ID) |
| `disconnectSns(int $accountId, string $provider): void` | 회원 ID, Provider명 | void | `BadRequestException` (마지막 Provider + 비밀번호 없음) |

#### 3.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Member/Config/Services.php` |
| 외부 연동 | `uploadProfileImage()` → AWS S3 Pre-signed URL 또는 직접 업로드 |

#### 3.2.4 Error Handling (에러 처리)

| 예외 클래스 | HTTP | 에러 코드 | 발생 조건 |
|-----------|------|---------|---------|
| `ConflictException` | 409 | `NICKNAME_CHANGE_COOLDOWN` | 닉네임 변경 7일 쿨다운 미충족 |
| `ConflictException` | 409 | `NICKNAME_ALREADY_EXISTS` | 닉네임 중복 |
| `BadRequestException` | 400 | `INVALID_FILE_TYPE` | 허용되지 않는 MIME 타입 |
| `BadRequestException` | 400 | `FILE_TOO_LARGE` | 파일 5MB 초과 |
| `ConflictException` | 409 | `SNS_ALREADY_LINKED` | 다른 계정에 이미 연동된 SNS ID |
| `BadRequestException` | 400 | — | SNS 해제 불가 (마지막 Provider + 비밀번호 없음) |

#### 3.2.5 Data Flow (데이터 흐름)

```
MypageController::changeNickname()
  └─ MemberProfileService::changeNickname(accountId, nickname)
        ├─ MypageRepository::getLastNicknameChangeDate(accountId) → 7일 쿨다운 확인
        ├─ MemberRepository::findByNickname(nickname)             → 중복 확인
        └─ MypageRepository::updateNickname(accountId, nickname, now)

MypageController::uploadProfileImage()
  └─ MemberProfileService::uploadProfileImage(accountId, file)
        ├─ [1차] 확장자 검증 (jpg/jpeg/png/webp)
        ├─ [2차] mime_content_type($tmp_name) 서버 측 MIME 검증
        ├─ Awss3::upload(file, "profiles/{accountId}/{uuid}.{ext}")
        ├─ MypageRepository::deleteOldProfileImage(accountId) → S3 이전 객체 삭제
        └─ MypageRepository::updateProfileImage(accountId, newUrl) → S3 URL 저장
```

**PHP 시그니처:**

```php
interface MemberProfileServiceInterface
{
    /** @throws ConflictException NICKNAME_CHANGE_COOLDOWN / NICKNAME_ALREADY_EXISTS */
    public function changeNickname(int $accountId, string $nickname): void;

    /**
     * @throws BadRequestException INVALID_FILE_TYPE / FILE_TOO_LARGE
     * @return string S3 이미지 URL
     */
    public function uploadProfileImage(int $accountId, array $file): string;

    public function deleteProfileImage(int $accountId): void;

    /** @return array 업데이트된 프로필 (camelCase) */
    public function updateProfile(int $accountId, array $data): array;

    /** @throws ConflictException SNS_ALREADY_LINKED */
    public function connectSns(int $accountId, string $provider, string $authCode): void;

    /** @throws BadRequestException SNS 해제 불가 (마지막 Provider + 비밀번호 없음) */
    public function disconnectSns(int $accountId, string $provider): void;
}
```

---

### IF-INT-003: SmsVerificationServiceInterface

#### 3.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-003 |
| 인터페이스명 | SmsVerificationServiceInterface |
| 파일 경로 | `app/Modules/Member/Interfaces/SmsVerificationServiceInterface.php` |
| 제공 컴포넌트 | `SmsVerificationService` |
| 소비 컴포넌트 | `MemberRegistrationService`, `MypageController` |

#### 3.3.2 Data Elements (데이터 요소)

| 메서드 시그니처 | 입력 | 출력 | 예외 |
|----------------|------|------|------|
| `sendOtp(string $phone, int $accountId): void` | 전화번호, 회원 ID | void | `TooManyRequestsException` (10회/일 초과 또는 60초 대기) |
| `verifyOtp(string $phone, string $otp): bool` | 전화번호, OTP | 검증 성공 여부 | `BadRequestException` (만료/불일치) |
| `getDailyCount(string $phone): int` | 전화번호 | 오늘 발송 횟수 | — |
| `generateOtp(): string` | — | 6자리 OTP 문자열 (`random_int` 기반) | — |

**OTP TTL:** 5분 (300초). `tb_sms_auth` 저장.

#### 3.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process). 내부에서 SMS Link API HTTP 호출 |
| 외부 연동 | IF-EXT-001 (SMS Link API) |
| Rate Limit | 10회/일 (전화번호 기준), 재발송 대기 60초 |

#### 3.3.4 Error Handling (에러 처리)

| 예외 클래스 | HTTP | 에러 코드 | 발생 조건 |
|-----------|------|---------|---------|
| `TooManyRequestsException` | 429 | `SMS_LIMIT_EXCEEDED` | SMS 발송 10회/일 초과 |
| `TooManyRequestsException` | 429 | `SMS_RESEND_TOO_FAST` | 재발송 60초 대기 미충족 |
| `BadRequestException` | 400 | `OTP_EXPIRED` | SMS OTP 5분 만료 |
| `BadRequestException` | 400 | `OTP_MISMATCH` | SMS OTP 번호 불일치 |

#### 3.3.5 Data Flow (데이터 흐름)

```
SmsVerificationService::sendOtp(phone, accountId)
  ├─ getDailyCount(phone) → count ≥ 10 → TooManyRequestsException (SMS_LIMIT_EXCEEDED)
  ├─ 재발송 대기 확인 (마지막 발송 + 60초 이내) → TooManyRequestsException (SMS_RESEND_TOO_FAST)
  ├─ generateOtp() → 6자리 random_int
  ├─ SMS Link API POST /v1/send → OTP 문자 발송
  └─ saveSmsAuth({phone, otp, expiry: now+5min, accountId}) → tb_sms_auth INSERT
```

**PHP 시그니처:**

```php
interface SmsVerificationServiceInterface
{
    /** @throws TooManyRequestsException SMS_LIMIT_EXCEEDED / SMS_RESEND_TOO_FAST */
    public function sendOtp(string $phone, int $accountId): void;

    /**
     * @throws BadRequestException OTP_EXPIRED / OTP_MISMATCH
     * @return bool 검증 성공 여부
     */
    public function verifyOtp(string $phone, string $otp): bool;

    public function getDailyCount(string $phone): int;
    public function generateOtp(): string;
}
```

---

### IF-INT-004: MemberRepositoryInterface

#### 3.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-004 |
| 인터페이스명 | MemberRepositoryInterface |
| 파일 경로 | `app/Modules/Member/Interfaces/MemberRepositoryInterface.php` |
| 제공 컴포넌트 | `MemberRepository` (777 lines, 23 methods) |
| 소비 컴포넌트 | `MemberRegistrationService`, `MemberProfileService` |

#### 3.4.2 Data Elements (데이터 요소)

**데이터 반환 계약:**

| 메서드 | 반환 타입 | null 조건 |
|--------|----------|----------|
| `findById(int $acId)` | `MemberEntity\|null` | ac_id 미존재 시 |
| `findByEmail(string $email)` | `MemberEntity\|null` | 이메일 미존재 시 |
| `findByPhone(string $phone)` | `MemberEntity\|null` | 전화번호 미존재 시 |
| `findBySnsId(string $provider, string $snsId)` | `MemberEntity\|null` | SNS ID 미존재 시 |
| `findMailCert(string $token)` | `array\|null` | 토큰 미존재 또는 만료 시 |
| `findRefreshToken(string $jti)` | `array\|null` | jti 미존재 또는 무효화 시 |

**MemberEntity 구조:**

```php
namespace App\Modules\Member\Entities;

class MemberEntity
{
    public int $ac_id;
    public string $ac_email;
    public ?string $ac_password;
    public string $ac_nick;
    public ?string $ac_phone;
    public ?string $ac_name;
    public string $ac_status;          // A|D|B|S
    public ?string $ac_profile_img;
    public ?string $ce_code;           // null=Caller, 값=Callee
    public ?string $ac_google_id;
    public ?string $ac_kakao_id;
    public ?string $ac_naver_id;
    public ?string $ac_facebook_id;
    public ?string $ac_apple_id;
    public ?string $ac_line_id;
    public ?DateTimeImmutable $ac_nick_changed_at;
    public DateTimeImmutable $created_at;
    public DateTimeImmutable $updated_at;
    public ?DateTimeImmutable $deleted_at;

    public function toPayload(): array;   // JWT payload 변환
    public function toCamelCase(): array; // API 응답 변환
    public function isActive(): bool;     // ac_status === 'A'
    public function isCaller(): bool;     // ce_code === null
    public function isCallee(): bool;     // ce_code !== null
}
```

#### 3.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder 우선. CTE/Window Function은 `$db->query()` + named binding |
| DB 연결 | Aurora MySQL (RDS Proxy, IAM Auth) |

#### 3.4.4 Error Handling (에러 처리)

DB 쿼리 실패 시 CI4 Database Exception 전파. Controller에서 500 `INTERNAL` 응답. `findMailCert()` — 만료된 토큰(`expires_at < NOW()`) 또는 이미 사용된 토큰(`used_at IS NOT NULL`) 시 `null` 반환.

#### 3.4.5 Data Flow (데이터 흐름)

```
MemberRegistrationService / MemberProfileService
  └─ MemberRepository::method()
        └─ CI4 Query Builder / $db->query()
              └─ Aurora MySQL (RDS Proxy)
```

---

### IF-INT-005: MypageRepositoryInterface

#### 3.5.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-005 |
| 인터페이스명 | MypageRepositoryInterface |
| 파일 경로 | `app/Modules/Member/Interfaces/MypageRepositoryInterface.php` |
| 제공 컴포넌트 | `MypageRepository` (1187 lines, 22 methods) |
| 소비 컴포넌트 | `MemberProfileService`, `MypageController` |

#### 3.5.2 Data Elements (데이터 요소)

**페이지네이션 반환 계약:**

모든 페이지네이션 메서드는 CI4 빌트인 Pager와 호환되는 구조를 반환한다.

```php
// 표준 페이지네이션 반환 구조
[
    'data' => [
        // 각 항목은 camelCase 변환 완료 상태
        ['callId' => 1, 'createdAt' => '2026-04-15T00:00:00Z', ...],
    ],
    'meta' => [
        'currentPage' => 1,
        'perPage'     => 10,
        'total'       => 100,
        'lastPage'    => 10,
    ]
]
```

**소유권 보장 계약:**

MypageRepository의 모든 조회/수정/삭제 메서드는 `ac_id` 조건을 쿼리에 내장한다. 소유권 조건 없이 전체 레코드를 반환하는 메서드는 존재하지 않는다.

```sql
-- 모든 Repository 메서드 WHERE 절 필수 패턴 (OWASP API5:2023 BOLA 대응)
WHERE ac_id = :ac_id AND id = :id
```

#### 3.5.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder. Aurora MySQL (RDS Proxy) |
| 소유권 보장 | 모든 쿼리에 `ac_id` 조건 내장 (OWASP API1:2023 BOLA 대응) |

#### 3.5.4 Error Handling (에러 처리)

DB 쿼리 실패 시 CI4 Database Exception 전파. 조회 결과 없음(빈 배열) 반환은 예외 없음. 수정/삭제 0 행 반환 시 호출측 Controller에서 404 `NOT_FOUND` 처리.

#### 3.5.5 Data Flow (데이터 흐름)

```
MypageController / MemberProfileService
  └─ MypageRepository::method($accountId, ...)
        └─ CI4 Query Builder (WHERE ac_id = :accountId 포함)
              └─ Aurora MySQL (RDS Proxy)
```

---

### IF-INT-006: SnsRepositoryInterface

#### 3.6.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-006 |
| 인터페이스명 | SnsRepositoryInterface |
| 파일 경로 | `app/Modules/Member/Interfaces/SnsRepositoryInterface.php` |
| 제공 컴포넌트 | `SnsRepository` (65 lines) |
| 소비 컴포넌트 | `MemberProfileService` |

#### 3.6.2 Data Elements (데이터 요소)

**Provider 상수 계약:**

```php
// 허용 Provider 값 (string)
const PROVIDER_GOOGLE   = 'google';
const PROVIDER_KAKAO    = 'kakao';
const PROVIDER_NAVER    = 'naver';
const PROVIDER_FACEBOOK = 'facebook';
const PROVIDER_APPLE    = 'apple';
const PROVIDER_LINE     = 'line';
```

**saveSnsConnection() 입력 검증 선행 조건:**

1. `provider` 값이 허용 목록에 포함되는지 확인
2. `findBySnsId(provider, snsId)`로 다른 계정 중복 연동 확인
3. 위 조건 통과 후 INSERT

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `findBySnsId(string $provider, string $snsId)` | Provider명, SNS 고유 ID | `?MemberEntity` | 다른 계정 중복 확인용 |
| `saveSnsConnection(int $accountId, string $provider, string $snsId)` | — | `bool` | `tb_account` SNS 컬럼 갱신 |
| `removeSnsConnection(int $accountId, string $provider)` | — | `bool` | SNS 연동 해제 |

#### 3.6.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). CI4 Query Builder. Aurora MySQL.

#### 3.6.4 Error Handling (에러 처리)

`findBySnsId()` — 미존재 시 `null` 반환. `saveSnsConnection()` — DB unique 제약 위반 시 예외 전파 (중복 연동 방지).

#### 3.6.5 Data Flow (데이터 흐름)

```
MemberProfileService::connectSns(accountId, provider, authCode)
  ├─ [OAuth] Provider API에서 snsId, email 조회
  ├─ SnsRepository::findBySnsId(provider, snsId) → 타 계정 중복 확인
  └─ SnsRepository::saveSnsConnection(accountId, provider, snsId)
```

**PHP 시그니처:**

```php
interface SnsRepositoryInterface
{
    public function findBySnsId(string $provider, string $snsId): ?MemberEntity;
    public function saveSnsConnection(int $accountId, string $provider, string $snsId): bool;
    public function removeSnsConnection(int $accountId, string $provider): bool;
}
```

---

## 4. External Interfaces (외부 인터페이스)

MIL-STD-498 IDD §4 — 각 외부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-EXT-001: SMS Link API

#### 4.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | SMS Link API |
| 대상 시스템 | SMS Link 문자 발송 게이트웨이 (SaaS) |
| 연동 컴포넌트 | `SmsVerificationService` |
| 환경변수 | `SMS_LINK_API_KEY` |

#### 4.1.2 Data Elements (데이터 요소)

**OTP 발송 요청:**

```
HTTP Method : POST
URL         : https://api.smslink.kr/v1/send
```

요청 페이로드:
```json
{
    "to":      "01012345678",
    "from":    "0215551234",
    "message": "[HongCafe] 인증번호 [123456]를 입력해주세요. 유효시간 5분."
}
```

응답 (성공, HTTP 200):
```json
{
    "resultCode": "00",
    "resultMessage": "성공",
    "messageId": "MSG_2026041500001"
}
```

응답 (실패, HTTP 4xx/5xx):
```json
{
    "resultCode": "99",
    "resultMessage": "발송 실패",
    "messageId": null
}
```

**resultCode 처리 계약:**

| resultCode | 처리 |
|-----------|------|
| `00` | 발송 성공 → `tb_sms_auth` 저장 |
| `10` | 수신 번호 오류 → `BadRequestException` (`INVALID_PHONE_NUMBER`) |
| `20` | API Key 오류 → `InternalException` + 운영 알림 |
| `99` | 일반 실패 → 1회 재시도 후 `InternalException` |

#### 4.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS REST |
| 인증 방식 | `X-Api-Key: {SMS_LINK_API_KEY}` 요청 헤더 |
| Content-Type | `application/json` |
| 구현 방법 | PHP cURL 또는 HTTP 클라이언트 |
| 타임아웃 | 응답 10초 |
| 재시도 | 1회 (resultCode=99 한정) |
| **환경 분기** | `ENVIRONMENT === 'production'` 에서만 실제 cURL 호출. 비프로덕션은 스킵 후 고정값 `111111` 반환 (커밋 `64aedf7`, `d29efc0`, `b4845e4`) |
| **검증 API 제거** | SMSLINK `/v1/verify` 엔드포인트는 **전 환경 제거**. OTP 검증은 `tb_interphone_auth` DB 5분 TTL 직접 매칭으로 전환 (커밋 `64aedf7`) |
| **로그 분기** | 비프로덕션은 `saveSmsLog()` 미호출 (로그 테이블 폴루션 방지, 커밋 `d532349`) |

#### 4.1.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| `resultCode=10` (수신 번호 오류) | `BadRequestException` → 400 `INVALID_PHONE_NUMBER` |
| `resultCode=20` (API Key 오류) | 500 `INTERNAL` + 운영 알림 |
| `resultCode=99` (일반 실패) | 1회 재시도 → 최종 실패 시 500 `SMS_SEND_FAILED` |
| cURL 타임아웃 | 500 `SMS_SEND_FAILED` |

**재시도 정책:** `resultCode=99` 한정 1회 재시도. 최종 실패 시 운영 알림 발송.

#### 4.1.5 Data Flow (데이터 흐름)

```
SmsVerificationService::sendOtp(phone, accountId)
  └─ cURL POST https://api.smslink.kr/v1/send
        ├─ [resultCode=00] tb_sms_auth INSERT (otp, expiry=now+5min)
        ├─ [resultCode=10] BadRequestException (INVALID_PHONE_NUMBER)
        └─ [resultCode=99] 재시도 1회 → InternalException (SMS_SEND_FAILED)
```

---

### IF-EXT-002: Kakao AlimTalk

#### 4.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-002 |
| 인터페이스명 | Kakao AlimTalk |
| 대상 시스템 | Kakao AlimTalk 메시지 발송 API |
| 연동 컴포넌트 | `MemberRegistrationService` |
| 환경변수 | `KAKAO_REST_API_KEY` |
| 폴백 | 실패 시 IF-EXT-003 (TemplateMail) 자동 폴백 |

#### 4.2.2 Data Elements (데이터 요소)

**AlimTalk 발송 요청:**

```
HTTP Method : POST
URL         : https://kapi.kakao.com/v1/api/talk/friends/message/send
Authorization: KakaoAK {KAKAO_REST_API_KEY}
```

요청 페이로드:
```json
{
    "receiver_uuids": ["uuid..."],
    "template_object": {
        "object_type": "text",
        "text": "안녕하세요 #{nickname}님,\nHongCafe 가입을 환영합니다.",
        "link": {
            "web_url": "https://prd.gl.hongcafe.com",
            "mobile_web_url": "https://prd.gl.hongcafe.com"
        },
        "button_title": "서비스 이용하기"
    }
}
```

**발송 유형별 템플릿:**

| 발송 유형 | 템플릿 ID | 변수 |
|----------|----------|------|
| 회원가입 완료 | `HONGCAFE_JOIN_COMPLETE` | `#{nickname}` |
| 비밀번호 재설정 | `HONGCAFE_PW_RESET` | `#{nickname}`, `#{resetLink}`, `#{expiry}` |
| 탈퇴 완료 | `HONGCAFE_WITHDRAW_DONE` | `#{nickname}` |

#### 4.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS REST |
| 인증 방식 | `Authorization: KakaoAK {KAKAO_REST_API_KEY}` |
| Content-Type | `application/json` |
| 구현 방법 | PHP cURL |
| **환경 분기** | `ENVIRONMENT === 'production'` 에서만 실제 호출. 비프로덕션은 `verify-phone`/`find-id` AlimTalk 스킵 (커밋 `25f2285`, `a064453`) |
| **비프로덕션 인증번호** | 고정값 `222222` 반환. 클라이언트는 SMS 수신 없이 해당 값으로 검증 통과 |

#### 4.2.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| HTTP 4xx/5xx 응답 | TemplateMail 이메일 발송으로 자동 폴백 |
| cURL 타임아웃 | TemplateMail 이메일 발송으로 자동 폴백 |
| 폴백도 실패 | 운영 알림 발송 (SNS/SQS Outbox 패턴) |

**폴백 정책:** Kakao AlimTalk 발송 실패 시 IF-EXT-003 (TemplateMail) 자동 폴백. 단일 채널 의존 제거.

#### 4.2.5 Data Flow (데이터 흐름)

```
MemberRegistrationService::register()
  ├─ [1] Kakao AlimTalk → HONGCAFE_JOIN_COMPLETE 발송
  │         ├─ [성공] 완료
  │         └─ [실패] TemplateMail::send(to, 'member.join.cert', vars) 폴백
  │                     └─ [폴백 실패] 운영 알림 발송
  └─ issueJwtTokens() → 쿠키 3종 발급
```

---

### IF-EXT-003: TemplateMail

#### 4.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-003 |
| 인터페이스명 | TemplateMail |
| 대상 시스템 | 이메일 발송 서비스 (SMTP 또는 내부 메일 API) |
| 연동 컴포넌트 | `MemberRegistrationService` |
| 인터페이스 | `TemplateMailInterface` (Shared 모듈) |

#### 4.3.2 Data Elements (데이터 요소)

**TemplateMailInterface 발송 메서드:**

```php
interface TemplateMailInterface
{
    public function send(
        string $to,
        string $templateId,
        array  $variables,
        string $locale = 'ko'
    ): bool;
}
```

**메일 템플릿 목록:**

| 템플릿 ID | 용도 | 필수 변수 |
|----------|------|---------|
| `member.join.cert` | 가입 이메일 인증 | `nickname`, `certLink`, `expiry` |
| `member.find.password` | 비밀번호 재설정 | `nickname`, `resetLink`, `expiry` |
| `member.find.id` | 아이디 찾기 결과 | `nickname`, `maskedEmail` |
| `member.withdraw.done` | 탈퇴 완료 알림 | `nickname` |

**인증 링크 생성 계약:**

```php
// 이메일 인증 링크 구조
// 경로: /verify-email?token={tb_mail_cert.cert_token}
// TTL: 1시간 (3600초)
// 토큰 생성: bin2hex(random_bytes(32)) → 64자 hex 문자열
// 저장: tb_mail_cert (cert_token UNIQUE, cert_type, ac_id, expires_at, used_at)

// 비밀번호 재설정 링크 구조
// 경로: /reset-password?token={tb_mail_cert.cert_token}
// TTL: 1시간 (3600초)
```

#### 4.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS REST (내부 메일 서비스) 또는 SMTP |
| 인증 | SMTP 자격증명 또는 내부 API Key (환경변수) |
| 구현 방법 | 인터페이스 기반 DI (Shared 모듈) |
| **환경 분기** | `ENVIRONMENT === 'production'` 에서만 실제 발송. 비프로덕션은 `send-mail-cert`, `findPasswordCert` 플로우에서 메일 발송 스킵 (커밋 `0731339`, `ade84ab`) |
| **비프로덕션 대체** | `tb_mail_cert`에 인증 토큰은 정상 INSERT. 검증은 DB 직접 조회로 통과 가능 |

#### 4.3.4 Error Handling (에러 처리)

메일 발송 실패 시 500 `MAIL_SEND_FAILED` 응답. 운영 알림 발송. Kakao AlimTalk 폴백으로 수신한 요청도 실패 시 동일 처리.

#### 4.3.5 Data Flow (데이터 흐름)

```
MemberRegistrationService::register() [회원가입]
  └─ TemplateMailInterface::send(email, 'member.join.cert', {nickname, certLink, expiry})
        └─ SMTP / 내부 메일 API → 이메일 발송

MemberRegistrationService::resetPassword() [비밀번호 재설정]
  └─ TemplateMailInterface::send(email, 'member.find.password', {nickname, resetLink, expiry})
```

---

### IF-EXT-004: AWS S3 (프로필 이미지)

#### 4.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-004 |
| 인터페이스명 | AWS S3 (프로필 이미지 스토리지) |
| 대상 시스템 | AWS S3 / CloudFront |
| 연동 컴포넌트 | `MemberProfileService` |
| SDK | AWS SDK for PHP v3 |
| 인증 | IAM Role (EC2 인스턴스 프로파일, 키 하드코딩 금지) |
| 환경변수 | `AWS_S3_BUCKET`, `CLOUDFRONT_URL` |

#### 4.4.2 Data Elements (데이터 요소)

**업로드 Pre-signed URL 발급:**

```php
$presignedUrl = $s3Client->createPresignedRequest(
    $s3Client->getCommand('PutObject', [
        'Bucket'      => env('AWS_S3_BUCKET'),
        'Key'         => "profiles/{$accountId}/{$filename}",
        'ContentType' => $mimeType,
        'ACL'         => 'private',
    ]),
    '+15 minutes'
)->getUri();

// 서빙 URL (CloudFront 경유)
$publicUrl = env('CLOUDFRONT_URL') . "/profiles/{$accountId}/{$filename}";
```

**S3 경로 규칙:**

```
profiles/{ac_id}/{uuid}.{ext}

예시: profiles/12345/a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg
```

**MIME 이중 검증 계약:**

```php
// 1차 검증: 확장자 기반
$allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

// 2차 검증: 서버 측 MIME 타입 확인 (확장자 스푸핑 방지)
$serverMime = mime_content_type($file->getTempName());
$allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];

if (!in_array($serverMime, $allowedMimes, true)) {
    throw new BadRequestException(lang('Member.invalidFileType'));
}
```

**파일 제한:**

| 항목 | 제한 |
|------|------|
| 최대 파일 크기 | 5MB (5,242,880 bytes) |
| 허용 MIME 타입 | `image/jpeg`, `image/png`, `image/webp` |
| 파일명 | UUID v4 + 원본 확장자 (원본 파일명 미사용) |
| 이전 이미지 | 새 이미지 업로드 시 S3 이전 객체 삭제 |

#### 4.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| SDK | PHP AWS SDK v3 |
| 인증 | IAM Role (EC2 인스턴스 프로파일). 키 하드코딩 절대 금지 |
| 보안 | MIME 이중 검증 필수 (OWASP File Upload Cheat Sheet) |
| Pre-signed URL TTL | 15분 |

#### 4.4.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| MIME 검증 실패 | `BadRequestException` → 400 `INVALID_FILE_TYPE` |
| 파일 크기 초과 | `BadRequestException` → 400 `FILE_TOO_LARGE` |
| S3 업로드 실패 | 500 `S3_UPLOAD_FAILED` + 임시 파일 정리 + 운영 알림 |

#### 4.4.5 Data Flow (데이터 흐름)

```
MemberProfileService::uploadProfileImage(accountId, file)
  ├─ [1] 확장자 검증 (jpg/jpeg/png/webp)
  ├─ [2] mime_content_type($tmp_name) 서버 측 MIME 검증
  ├─ [3] Awss3::upload(file, "profiles/{accountId}/{uuid}.{ext}")
  │         └─ AWS S3 PutObject API
  ├─ [4] MypageRepository::deleteOldProfileImage(accountId) → 이전 S3 객체 삭제
  ├─ [5] MypageRepository::updateProfileImage(accountId, cloudFrontUrl)
  └─ [6] 200 { "data": { "profileImageUrl": "https://cdn.example.com/profiles/..." } }
```

---

## 5. Events and Signals (이벤트 계약)

MIL-STD-498 IDD §5 — 시스템 이벤트 트리거, 대상, 처리 흐름을 명세한다.

| 이벤트 ID | 이벤트명 | 트리거 EP | 발신 컴포넌트 | 수신 시스템 | 처리 내용 |
|---------|--------|---------|------------|-----------|---------|
| EVT-001 | 가입 인증 메일 | `POST /api/members/send-join-cert-mail` | `MemberRegistrationService` | TemplateMail | 이메일 인증 링크 발송 (TTL 1시간) |
| EVT-002 | 가입 완료 알림 | `POST /api/members/join` (인증 후) | `MemberRegistrationService` | Kakao AlimTalk → TemplateMail 폴백 | 가입 환영 메시지 (`HONGCAFE_JOIN_COMPLETE`) |
| EVT-003 | 비밀번호 재설정 메일 | `POST /api/members/find-password` | `MemberRegistrationService` | TemplateMail | 비밀번호 재설정 링크 발송 (TTL 1시간) |
| EVT-004 | SMS OTP 발송 | `POST /api/mypage/send-sms` | `SmsVerificationService` | SMS Link API | 6자리 OTP 문자 발송 |
| EVT-005 | 탈퇴 완료 알림 | `POST /api/members/withdraw` | `MemberRegistrationService` | Kakao AlimTalk → TemplateMail 폴백 | 탈퇴 완료 메시지 (`HONGCAFE_WITHDRAW_DONE`) |
| EVT-006 | JWT 토큰 발급 | 로그인/회원가입/Token Refresh 완료 시 | `MemberRegistrationService` | 클라이언트 쿠키 | `hc_access`, `hc_refresh`, `hc_csrf` 3종 Set-Cookie |
| EVT-007 | Token Family 무효화 | Refresh Token Reuse 감지 시 | `MemberRegistrationService` | `tb_refresh_token` | 동일 `family` 모든 jti 무효화 (보안 대응) |

---

## 6. Error Handling Contract (에러 처리 계약)

MIL-STD-498 IDD §6 — HTTP 에러 코드 계약.

### 6.1 표준 에러 응답 형식

```json
{
    "error": {
        "code":    "ERROR_CODE_UPPERCASE",
        "message": "사람이 읽을 수 있는 에러 설명 (lang() 키 기반)"
    }
}
```

- `code`: SCREAMING_SNAKE_CASE, 현상 서술형, suffix 없음
- `message`: `lang()` 키 기반 다국어 지원
- HTTP 상태코드가 성공/실패의 SSOT (RFC 7231)

### 6.2 HTTP 400 — Bad Request

| 에러 코드 | 발생 조건 | 발생 EP |
|----------|----------|--------|
| `INVALID_INPUT` | 요청 파라미터 유효성 검사 실패 | 모든 EP |
| `OTP_EXPIRED` | SMS OTP 5분 만료 | `/api/mypage/verify-sms` |
| `OTP_MISMATCH` | SMS OTP 번호 불일치 | `/api/mypage/verify-sms` |
| `EXPIRED_CERT` | 이메일 인증 링크 만료 (1시간) | `/api/members/verify-join-cert-mail` |
| `INVALID_CERT_TOKEN` | 이메일 인증 토큰 무효 또는 사용됨 | `/api/members/verify-cert-mail`, `/api/members/reset-password` |
| `INVALID_FILE_TYPE` | 허용되지 않는 이미지 MIME 타입 | `/api/mypage/upload-profile-image` |
| `FILE_TOO_LARGE` | 업로드 파일 5MB 초과 | `/api/mypage/upload-profile-image` |
| `WEAK_PASSWORD` | 비밀번호 복잡도 미충족 | `/api/members/join`, `/api/members/change-password`, `/api/members/reset-password` |

### 6.3 HTTP 401 — Unauthorized

| 에러 코드 | 발생 조건 | 발생 EP |
|----------|----------|--------|
| `INVALID_CREDENTIALS` | 이메일 미존재 또는 비밀번호 불일치 (CWE-204: 동일 메시지) | `/api/members/login` |
| `TOKEN_EXPIRED` | JWT Access Token 만료 (15분) | 인증 필요 모든 EP |
| `TOKEN_INVALID` | JWT 서명 검증 실패 또는 변조 | 인증 필요 모든 EP |
| `REFRESH_TOKEN_REUSED` | 이미 사용된 Refresh Token jti 재제출 | `/api/auth/refresh` |
| `SESSION_REVOKED` | Token Family 무효화 (비밀번호 변경/탈퇴/재사용 감지) | `/api/auth/refresh` |
| `CSRF_INVALID` | CSRF 토큰 불일치 또는 만료 (2시간) | POST/PUT/DELETE 모든 EP |

### 6.4 HTTP 403 — Forbidden

| 에러 코드 | 발생 조건 | 발생 EP |
|----------|----------|--------|
| `FORBIDDEN` | 권한 없는 리소스 접근 (소유권 위반) | 마이페이지 조회/수정/삭제 EP |
| `CALLEE_ONLY` | Caller가 Callee 전용 EP 접근 시도 | `callees/*`, `goods/callee-*`, `shop/callee-*` |
| `EMAIL_NOT_VERIFIED` | 이메일 미인증 계정 로그인 시도 | `/api/members/login` |
| `ACCOUNT_BANNED` | 관리자 제재 계정 (`ac_status='B'`) | `/api/members/login` |
| `ACCOUNT_SUSPENDED` | 일시 정지 계정 (`ac_status='S'`) | `/api/members/login` |

### 6.5 HTTP 404 — Not Found

| 에러 코드 | 발생 조건 | 발생 EP |
|----------|----------|--------|
| `NOT_FOUND` | 요청한 리소스 미존재 | 조회 EP 전반 |
| `MEMBER_NOT_FOUND` | ac_id에 해당하는 회원 미존재 | `/api/profile/{ac_id}`, `/api/profile/{ac_id}/stats` |
| `REVIEW_NOT_FOUND` | 수정/삭제 대상 리뷰 미존재 | `/api/mypage/modify-review`, `/api/mypage/delete-review` |

### 6.6 HTTP 409 — Conflict

| 에러 코드 | 발생 조건 | 추가 데이터 | 발생 EP |
|----------|----------|------------|--------|
| `EMAIL_ALREADY_EXISTS` | 이미 등록된 이메일 | — | `/api/members/join`, `/api/members/check-id` |
| `NICKNAME_ALREADY_EXISTS` | 이미 사용 중인 닉네임 | — | `/api/members/join`, `/api/members/check-nickname`, `/api/mypage/change-nickname` |
| `NICKNAME_CHANGE_COOLDOWN` | 닉네임 변경 7일 쿨다운 미충족 | `{ "availableAt": "2026-04-22T00:00:00Z" }` | `/api/mypage/change-nickname` |
| `PHONE_ALREADY_EXISTS` | 이미 등록된 전화번호 | — | `/api/mypage/change-phone` |
| `SNS_ALREADY_LINKED` | 다른 계정에 이미 연동된 SNS ID | — | `/api/members/sns-connect` |
| `REVIEW_ALREADY_EXISTS` | 동일 통화에 리뷰 이미 작성됨 | — | `/api/mypage/write-review` |
| `PENDING_TRANSACTION_EXISTS` | 진행 중 결제/예약으로 탈퇴 불가 | — | `/api/members/withdraw` |

### 6.7 HTTP 429 — Too Many Requests

| 에러 코드 | 발생 조건 | 추가 데이터 | 발생 EP |
|----------|----------|------------|--------|
| `SMS_LIMIT_EXCEEDED` | SMS 발송 10회/일 초과 | `{ "resetAt": "2026-04-16T00:00:00Z" }` | `/api/mypage/send-sms` |
| `SMS_RESEND_TOO_FAST` | SMS 재발송 60초 대기 미충족 | `{ "retryAfter": 45 }` | `/api/mypage/send-sms` |
| `RATE_LIMIT_EXCEEDED` | 전역 Rate Limit 초과 | — | 모든 EP |

### 6.8 HTTP 500 — Internal Server Error

| 에러 코드 | 발생 조건 | 처리 |
|----------|----------|------|
| `INTERNAL` | 예상치 못한 서버 오류 | 스택 트레이스 로그 기록. 클라이언트에 상세 노출 금지 |
| `SMS_SEND_FAILED` | SMS Link API 발송 실패 (재시도 후) | 운영 알림 발송 |
| `MAIL_SEND_FAILED` | 메일 발송 실패 | 운영 알림 발송 |
| `S3_UPLOAD_FAILED` | S3 업로드 실패 | 운영 알림 발송 |

---

## 7. Data Formats and Encoding (데이터 포맷 및 인코딩)

MIL-STD-498 IDD §7 — 인터페이스 데이터 포맷, DTO 정의, 인코딩 규칙을 명세한다.

### 7.1 공통 인코딩 규칙

| 항목 | 규칙 |
|------|------|
| 문자 인코딩 | UTF-8 (utf8mb4) 전 레벨 통일 |
| 날짜/시각 — API 응답 | ISO 8601 UTC (`"2026-04-15T09:00:00Z"`) |
| 날짜/시각 — DB 저장 | MySQL DATETIME UTC (`2026-04-15 09:00:00`) |
| 날짜/시각 — PHP 내부 | `DateTimeImmutable`. `date()` / `time()` 사용 금지 |
| API 응답 키 | DB `snake_case` → API `camelCase` 변환 필수 (`created_at` → `createdAt`) |
| 성공 응답 | `{ "data": {...} }` (HTTP 200/201) |
| 에러 응답 | `{ "error": { "code": "...", "message": "..." } }` (HTTP 4xx/5xx) |

### 7.2 API 응답 camelCase 변환 규칙

| DB 컬럼 (snake_case) | API 응답 (camelCase) |
|---------------------|---------------------|
| `ac_id` | `acId` |
| `ac_email` | `acEmail` |
| `ac_nick` | `acNick` |
| `ac_profile_img` | `acProfileImg` |
| `ce_code` | `ceCode` |
| `created_at` | `createdAt` |
| `updated_at` | `updatedAt` |
| `deleted_at` | `deletedAt` |

### 7.3 JWT 토큰 페이로드 DTO

**Access Token Payload:**

```json
{
    "ac_id":    12345,
    "cr_code":  null,
    "ac_nick":  "홍길동",
    "type":     "access",
    "iat":      1713171600,
    "exp":      1713172500
}
```

**Refresh Token Payload:**

```json
{
    "ac_id":   12345,
    "type":    "refresh",
    "jti":     "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "family":  "f1e2d3c4-b5a6-7890-abcd-ef1234567890",
    "iat":     1713171600,
    "exp":     1713776400
}
```

### 7.4 쿠키 발급 명세

| 쿠키명 | 값 | Max-Age | Path | HttpOnly | Secure | SameSite |
|--------|----|---------|------|---------|--------|---------|
| `hc_access` | JWT Access Token | 900 | `/` | true | true | Lax |
| `hc_refresh` | JWT Refresh Token | 604800 | `/api/auth/refresh` | true | true | Lax |
| `hc_csrf` | HMAC-SHA256 서명 토큰 | 7200 | `/` | false | true | Lax |

### 7.5 회원 가입 응답 예시

```json
// POST /api/members/join (성공)
// HTTP 201
// Set-Cookie: hc_access=...; hc_refresh=...; hc_csrf=...
{
    "data": {
        "acId": 12345,
        "acEmail": "user@example.com",
        "acNick": "홍길동",
        "ceCode": null,
        "createdAt": "2026-04-15T09:00:00Z"
    }
}
```

### 7.6 페이지네이션 응답 포맷

```json
// GET /api/mypage/call-list
{
    "data": [
        {
            "callId":    1001,
            "ceCode":    "CE_HONG_001",
            "duration":  300,
            "createdAt": "2026-04-15T09:00:00Z"
        }
    ],
    "meta": {
        "currentPage": 1,
        "perPage":     10,
        "total":       100,
        "lastPage":    10
    }
}
```

### 7.7 SNS Provider 응답 매핑

| Provider | 고유 ID 필드 | 이메일 필드 | API 엔드포인트 |
|---------|------------|------------|--------------|
| Google | `sub` | `email` | `https://www.googleapis.com/oauth2/v3/userinfo` |
| Kakao | `id` | `kakao_account.email` | `https://kapi.kakao.com/v2/user/me` |
| Naver | `response.id` | `response.email` | `https://openapi.naver.com/v1/nid/me` |
| Facebook | `id` | `email` | `https://graph.facebook.com/me?fields=id,email,name` |
| Apple | JWT `sub` | JWT `email` | Apple Public Key JWKS 검증 |
| Line | `userId` | `email` | `https://api.line.me/v2/profile` |

### 7.8 NICKNAME_CHANGE_COOLDOWN 응답 예시

```json
// HTTP 409
{
    "error": {
        "code": "NICKNAME_CHANGE_COOLDOWN",
        "message": "닉네임은 변경 후 7일 이내에는 다시 변경할 수 없습니다"
    },
    "data": {
        "availableAt": "2026-04-22T09:00:00Z"
    }
}
```

---

## 8. Feasibility Review (타당성 검토)

> 근거: OWASP API Security Top 10 2023, OWASP Authentication Cheat Sheet, OWASP File Upload Cheat Sheet, RFC 3339, AWS SDK for PHP 공식 문서

| 검토 ID | 검토 항목 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|----------|------|------|------|------------|
| FEA-001 | **Pre-signed URL (S3 프로필 업로드)** | 서버 메모리 부담 없는 표준 패턴. 적절 | AWS SDK for PHP 공식 지원. 서버 직접 스트리밍 대신 클라이언트가 S3에 직접 업로드. EC2 인스턴스 메모리 보호. IAM Role 기반 인증으로 키 하드코딩 불필요 (OWASP API8:2023) | 서버 직접 스트리밍 업로드 | Pre-signed URL: 서버 부담↓, Pre-signed URL TTL 관리 필요. 직접 스트리밍: 접근 제어↑, 서버 메모리 사용↑ |
| FEA-002 | **MIME 이중 검증 (확장자 + mime_content_type())** | OWASP 권고 준수. 적절 | OWASP File Upload Cheat Sheet 직접 권고. 확장자 검증 단독으로는 MIME 스푸핑 공격 차단 불가. `mime_content_type()` 서버 측 바이너리 검증으로 보완. NFR 보안 요건 충족 | 확장자 검증만 | 이중 검증: 보안↑, 처리 시간 소폭 증가. 단일 검증: 구현 단순, 스푸핑 취약 |
| FEA-003 | **Kakao AlimTalk → TemplateMail 폴백** | 단일 채널 의존 제거. 서비스 연속성 보장 | AlimTalk 장애 시 이메일로 자동 폴백. NFR 가용성 요건 직접 대응. 알림 미전달 방지. 운영 알림까지 3단계 안전망 구성 | 단일 채널(AlimTalk만) | 폴백: 가용성↑, 구현 복잡도 증가. 단일: 구현 단순, 장애 시 알림 누락 |
| FEA-004 | **CWE-204 단일 에러 코드 (`INVALID_CREDENTIALS`)** | OWASP Authentication Cheat Sheet 직접 적용. 적절 | "Use generic error messages. Avoid providing a specific reason for login failures." 이메일 미존재와 비밀번호 불일치 시 동일 `INVALID_CREDENTIALS` 반환. 더미 `password_hash()` 연산으로 응답 시간 균일화 (타이밍 공격 방지) | 에러 코드 분리 (`EMAIL_NOT_FOUND`, `WRONG_PASSWORD`) | 단일 코드: 사용자 열거 방지↑, UX 불편. 분리: UX 향상, 계정 존재 노출 |
| FEA-005 | **Token Rotation + Reuse Detection (Refresh Token Family)** | JWT 탈취 감지 표준 패턴. 적절 | 사용 완료된 `jti` 재제출 시 `family` 전체 무효화. 탈취된 토큰 재사용 시 정상 사용자도 영향받아 즉시 감지 가능. `tb_refresh_token` 테이블의 `family` + `jti` DB unique 제약으로 원자적 보장 | 단순 만료 기반 토큰 | Rotation+감지: 보안↑, 단일 기기 환경에서만 완벽 작동. 단순 만료: 구현 단순, 탈취 감지 불가 |

---

## 9. Change Impact Log (변경 영향 기록)

### 9.1 v2.0 반영 (2026-04-15)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|----------|----------|--------|----------|
| MIL-STD-498 IDD 표준 전면 전환 | 전체 문서 구조 재편 | Scope(§1), References(§2), 인터페이스별 5-subsection(식별자/데이터/통신/에러/흐름), Events(§5), ErrorContract(§6), DataFormats(§7), Requirements Traceability(§10) 신설 | 3-Round Review PASS 요건 충족. MIL-STD-498 기준 인터페이스 문서로 완전성 확보 |
| 버전 v1.0 → v2.0 | 문서 헤더, 변경 로그 | MIL-STD-498 전환 반영하는 메이저 버전 갱신 | 문서 이력 명확화 |
| 인터페이스별 5-subsection 구조화 | IF-INT-001~006, IF-EXT-001~004 전체 | 식별자/데이터/통신속성/에러처리/데이터흐름 5항목 완전 기술. 구현자 단독 참조 가능한 완결성 확보 | MIL-STD-498 DI-IPSC-81436 IDD 요건 준수 |
| Events and Signals 신설 (§5) | 신규 섹션 | 이벤트 7건 전체 트리거-발신-수신-처리 명세 (Kakao AlimTalk 폴백 흐름 포함) | MIL-STD-498 IDD 이벤트 계약 요건 준수 |
| Error Handling Contract 신설 (§6) | 기존 §4 에러 계약 재편 | HTTP 400~500 에러 코드 전수 명세. CWE-204, NICKNAME_CHANGE_COOLDOWN `availableAt`, SMS_LIMIT_EXCEEDED `resetAt` 추가 데이터 포함 | 구현자 에러 처리 단일 참조 가능 |
| Data Formats 확장 (§7) | 기존 §5 데이터 포맷 확장 | 공통 인코딩 규칙, camelCase 변환 규칙 표, JWT payload DTO, 쿠키 명세, 가입/페이지네이션/409 응답 JSON 예시, SNS Provider 매핑 추가 | 구현자 코딩 표준 단일 참조 가능 |
| Requirements Traceability Matrix 신설 (§10) | 신규 섹션 | SRS FR/NFR → IDD 인터페이스 매핑. 인터페이스 누락 방지 | MIL-STD-498 DI-IPSC-81436 추적성 요건 준수 |

### 9.2 v2.1 반영 (2026-04-17) — 2026-04-16 18:00 KST 이후 29건 커밋

| # | 변경 항목 | 영향 범위 | 개선점 | 수행 이유 (Why) |
|---|----------|----------|--------|----------------|
| 1 | IF-EXT-001 SMS Link API §4.1.3 — **환경 분기 명세** 추가 | 통신 속성 | 비프로덕션에서 cURL 미전송, `111111` 고정값 반환, `saveSmsLog()` 미호출 규칙 명문화 | 커밋 `64aedf7`, `d532349`, `b4845e4` — 개발 환경에서 외부 API 의존 제거, 테스트 결정성 확보, 환경 상수 일관화 |
| 2 | IF-EXT-001 §4.1.3 — **SMSLINK verify API 전 환경 제거** | 통신 속성 | OTP 검증은 `tb_interphone_auth` DB 5분 TTL 직접 매칭으로 일원화 | 커밋 `64aedf7` — 외부 API 장애가 인증 플로우를 중단시키던 리스크 차단, 단일 검증 소스 확보 |
| 3 | IF-EXT-002 Kakao AlimTalk §4.2.3 — **환경 분기 명세** 추가 | 통신 속성 | `verify-phone`/`find-id` 비프로덕션 스킵 + 인증번호 `222222` 고정 | 커밋 `25f2285`, `a064453` — 외부 AlimTalk 의존 제거로 전화번호/아이디 찾기 플로우 개발 환경 가능 |
| 4 | IF-EXT-003 TemplateMail §4.3.3 — **환경 분기 명세** 추가 | 통신 속성 | `send-mail-cert`, `findPasswordCert` 비프로덕션 스킵 + 인증 토큰만 DB 저장 | 커밋 `0731339`, `ade84ab` — 개발 환경 메일 발송 제거, `tb_mail_cert` DB 직접 검증 허용 |
| 5 | IF-INT-001 MemberRegistrationService — **JWT Fallback / ProfileService 단일 해싱** 행동 변경 | 내부 인터페이스 계약 | BaseController JWT fallback 경유 세션 복원 지원. `changePassword` 해싱 Service 전담 | 커밋 `fbbf0a9`, `021a314` — JWT 인증 단독 경로 지원, 이중 해싱으로 인한 로그인 영구 실패 차단 |
| 6 | IF-INT-002 MemberProfileService — **`changeNickname` 필드명 통일** | 데이터 요소 | 입력 필드 `ac_nick`(camelCase: `acNick`, `newNick`) 단일화. `new_nick` 제거 | 커밋 `372277b` — 프론트-백엔드 계약 일관성 확보 |
| 7 | EVT-002/005 — Kakao AlimTalk 이벤트에 **환경 분기 주석** 추가 필요 | 이벤트 계약 §5 | 비프로덕션 발송 스킵 동작을 계약에 기술 | NFR-009 SRS와 정합 |
| 8 | 에러 계약 §6.3 — **`REDIRECT_ON_API_PATH` 제거** (신규 원칙) | 에러 처리 | API 경로(`/api/*`)에서 HTTP redirect 응답 금지. 세션 불일치 시 401 `UNAUTHORIZED`로 통일 | 커밋 `8be5005` — JSON 클라이언트 파싱 실패 회귀 차단 |
| 9 | IF-INT-004 MemberRepository — **`checkCertNum` 네임스페이스 교정** | 논리 구조 | `\App\Libraries` → `\App\Modules\Member\Services` 모듈 소속 정상화 | 커밋 `64aedf7` — 마이그레이션 중 모듈 경계 불일치 해소 |
| 10 | CORS 허용 Origin — **`localhost:5500`/`127.0.0.1:5500` 전 환경 추가** | 통신 속성 | Flow Tester 등 로컬 HTML 도구의 전 환경(PRD 포함) 개발자 접근 허용 | 커밋 `a446d00`, `783699a` — 개발자가 프로덕션 상태를 직접 검증할 단일 도구 제공 |

---

## 10. Requirements Traceability Matrix (요구사항 추적성 매트릭스)

MIL-STD-498 DI-IPSC-81436 §10 — SRS FR/NFR과 IDD 인터페이스 간 추적성.

| SRS 요구사항 ID | 요구사항명 | 연관 인터페이스 | 인터페이스 타입 |
|---------------|---------|-------------|-------------|
| FR-001 | 회원가입 | IF-INT-001 (`register`), IF-INT-004 (`MemberRepository`), IF-EXT-002 (Kakao AlimTalk), IF-EXT-003 (TemplateMail 인증 메일) | 내부+외부 |
| FR-002 | 로그인 | IF-INT-001 (`login`, `loginWithSns`, `issueJwtTokens`), IF-INT-004 (`findByEmail`) | 내부 |
| FR-003 | 비밀번호 관리 | IF-INT-001 (`changePassword`, `resetPassword`), IF-INT-004 (`findMailCert`), IF-EXT-003 (재설정 메일) | 내부+외부 |
| FR-004 | 닉네임 변경 | IF-INT-002 (`changeNickname`), IF-INT-005 (`MypageRepository` 쿨다운 확인) | 내부 |
| FR-005 | 전화번호 변경 | IF-INT-003 (`SmsVerificationService`), IF-EXT-001 (SMS Link API) | 내부+외부 |
| FR-006 | SNS 연동 | IF-INT-002 (`connectSns`, `disconnectSns`), IF-INT-006 (`SnsRepository`) | 내부 |
| FR-007 | 회원 탈퇴 | IF-INT-001 (`withdraw`), IF-EXT-002 (탈퇴 완료 AlimTalk), IF-EXT-003 (탈퇴 완료 메일 폴백) | 내부+외부 |
| FR-008 | 마이페이지 이력 | IF-INT-005 (`MypageRepository` 이력 조회 메서드) | 내부 |
| FR-009 | 자동결제 | IF-INT-005 (`MypageRepository` 결제 관련 메서드) | 내부 |
| FR-010 | 리뷰 | IF-INT-005 (`MypageRepository` 리뷰 메서드) | 내부 |
| FR-011 | 프로필 관리 | IF-INT-002 (`uploadProfileImage`, `updateProfile`), IF-EXT-004 (AWS S3) | 내부+외부 |
| NFR-001 | CWE-204 타이밍 공격 방지 | IF-INT-001 (`login` 더미 hash 연산, 단일 `INVALID_CREDENTIALS` 코드) | 내부 |
| NFR-002 | 비밀번호 bcrypt 해시 | IF-INT-001 (`register`, `changePassword`), IF-INT-009 (`updatePasswordHash`) | 내부 |
| NFR-003 | SMS 발송 제한 | IF-INT-003 (`getDailyCount`, `sendOtp` Rate Limit), IF-EXT-001 (SMS Link API) | 내부+외부 |
| NFR-004 | 닉네임 변경 쿨다운 | IF-INT-002 (`changeNickname` 쿨다운 확인), IF-INT-005 (`getLastNicknameChangeDate`) | 내부 |
| NFR-005 | 성능 (파일 업로드) | IF-EXT-004 (AWS S3 Pre-signed URL + CloudFront 서빙) | 외부 |
| NFR-006 | 가용성 및 멱등성 | IF-EXT-002 → IF-EXT-003 폴백 (AlimTalk→Mail), IF-INT-001 (`issueJwtTokens` Token Rotation) | 내부+외부 |
| NFR-007 | 인가 (RBAC) | IF-INT-005 (소유권 쿼리 `ac_id`), IF-INT-006 (`SnsRepository` 소유권) | 내부 |
| NFR-008 | 데이터 형식 | IF-INT-004 (`MemberEntity` ISO 8601 UTC, camelCase 변환) | 내부 |

---

## 11. Document History (변경 로그)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | 1.0.0 | 초기 작성 — 내부 Interface 6개, 외부 시스템 4개 (SMS Link/Kakao/TemplateMail/S3), 에러 계약 HTTP 400~500, 데이터 형식, 체크리스트 | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 IDD 표준 전면 전환. 3-Round Review PASS. Scope, References, 인터페이스별 5-subsection 구조화(IF-INT 6개/IF-EXT 4개), Events(7건), Error Contract(§6 재편), DataFormats(§7 확장), Requirements Traceability Matrix(18건) 신설 | jypark |
| 2026-04-17 | 2.1.0 | 2026-04-16 18:00 KST 이후 29건 커밋 반영. IF-EXT-001~003에 환경 분기 명세 추가(SMS/AlimTalk/Mail 비프로덕션 스킵, SMSLINK verify API 전환 제거 + DB 직접 매칭, `222222`/`111111` 고정값). IF-INT-001 JWT Fallback + 단일 해싱 반영. IF-INT-002 `acNick` 필드 통일. `checkCertNum` 네임스페이스 교정. CORS `localhost:5500` 전 환경 허용. 3-Round IEEE Review PASS | jypark |
