---
문서명: Member 모듈 소프트웨어 설계 명세서 (SDD)
문서ID: SDD-MEMBER-001
버전: v2.1
상태: 승인됨
적용 표준: IEEE 1016-2009 (IEEE Standard for Information Technology — Systems Design — Software Design Descriptions)
생성일: 2026-04-15
최종수정일: 2026-04-17
작성자: jypark
검토자: —
승인자: —
대상 시스템: HongCafe Global Backend — Member Module
관련 문서:
  - member-srs.md (SRS-MEMBER-001)
  - member-idd.md (IDD-MEMBER-001)
  - docs/api-specification.md
  - app/Modules/Member/
---

# Member 모듈 소프트웨어 설계 명세서 (SDD)
# Software Design Description — Member Module

**문서 번호 (Document Number):** SDD-MEMBER-001  
**버전 (Version):** v2.1  
**적용 표준 (Applicable Standard):** IEEE 1016-2009  
**상태 (Status):** 승인됨 (Approved)  
**변경 로그 요약:** v2.1 — ADR-005(환경 분기), ADR-006(JWT Fallback), ADR-007(해싱 단일 책임), ADR-008(CORS 개발 도구 허용) 신규 추가. Design Overlay §12.5(환경 분기) + §12.6(BaseController 세션 복원) 신규. 3-Round Review PASS.

---

## 목차 (Table of Contents)

1. 범위 및 목적 (Scope and Purpose)
2. 참조 문서 (References)
3. 용어 및 약어 (Terms, Definitions, and Abbreviations)
4. 설계 뷰포인트 1 — 맥락 관점 (Context Viewpoint)
5. 설계 뷰포인트 2 — 구성 관점 (Composition Viewpoint)
6. 설계 뷰포인트 3 — 논리 관점 (Logical Viewpoint)
7. 설계 뷰포인트 4 — 의존성 관점 (Dependency Viewpoint)
8. 설계 뷰포인트 5 — 정보 관점 (Information Viewpoint)
9. 설계 뷰포인트 6 — 패턴 관점 (Patterns Use Viewpoint)
10. 설계 뷰포인트 7 — 인터페이스 관점 (Interface Viewpoint)
11. 설계 뷰포인트 8 — 행동 관점 (Behavioral Viewpoint)
12. 설계 오버레이 (Design Overlay)
13. 아키텍처 결정 기록 (Architecture Decision Records)
14. 설계-요구사항 추적 매트릭스 (Design–Requirement Traceability Matrix)
15. 설계 검수 체크리스트 (Design Review Checklist)
16. 타당성 검토 (Feasibility Review)
17. 변경 로그 (Change Log)

---

## 1. 범위 및 목적 (Scope and Purpose)

### 1.1 목적 (Purpose)

본 문서는 IEEE 1016-2009 표준에 따라 HongCafe Global Backend **Member 모듈**의 소프트웨어 설계를 기술한다. 8개 설계 뷰포인트를 통해 모듈의 맥락, 구성, 논리 구조, 의존성, 데이터 모델, 설계 패턴, 인터페이스, 행동 양식을 명세하며, 아키텍처 결정 기록(ADR) 및 요구사항-설계 추적 매트릭스를 포함한다.

This document describes the software design of the Member module of HongCafe Global Backend per IEEE 1016-2009, using 8 design viewpoints to cover context, composition, logic, dependencies, data models, design patterns, interfaces, and behavior.

### 1.2 범위 (Scope)

| 항목 | 내용 |
|------|------|
| 설계 대상 | `app/Modules/Member/` |
| 컨트롤러 | MemberController (21메서드), MypageController (20메서드), ProfileController (8메서드) |
| 서비스 | MemberRegistrationService, MemberProfileService, SmsVerificationService |
| 리포지토리 | MemberRepository (23메서드), MypageRepository (22메서드), SnsRepository |
| 인터페이스 | 6개 PHP Interface (DI 강제) |

---

## 2. 참조 문서 (References)

| ID | 문서명 | 출처 |
|----|--------|------|
| REF-001 | IEEE 1016-2009 — IEEE Standard for Information Technology — Systems Design — Software Design Descriptions | IEEE |
| REF-002 | SRS-MEMBER-001 (member-srs.md) | 내부 |
| REF-003 | IDD-MEMBER-001 (member-idd.md) | 내부 |
| REF-004 | OWASP API Security Top 10:2023 (API5 — BOLA) | OWASP |
| REF-005 | RFC 6819 — OAuth 2.0 Threat Model | IETF |
| REF-006 | CodeIgniter 4.7 Architecture Documentation | codeigniter.com |
| REF-007 | PHP 8.4 — password_hash(), password_verify() | php.net |

---

## 3. 용어 및 약어 (Terms, Definitions, and Abbreviations)

| 용어/약어 | 정의 |
|----------|------|
| BC | Bounded Context — 도메인 경계 단위 |
| DI | Dependency Injection — 의존성 주입 |
| SRP | Single Responsibility Principle — 단일 책임 원칙 |
| ADR | Architecture Decision Record — 아키텍처 결정 기록 |
| BOLA | Broken Object Level Authorization (OWASP API5:2023) |
| CWE-204 | Observable Response Discrepancy (타이밍 기반 사용자 열거) |
| Token Family | Refresh Token 갱신 계보 |
| EP | 엔드포인트 (Endpoint) |

---

## 4. 설계 뷰포인트 1 — 맥락 관점 (Context Viewpoint)

> **IEEE 1016-2009 §5.5 — Context Viewpoint:** 시스템의 경계와 외부 환경과의 관계를 정의한다.

### 4.1 모듈 경계 (Module Boundary)

Member 모듈은 HongCafe Global Backend의 Modular Monolith 아키텍처 내에서 독립적인 Bounded Context로 동작한다. 타 모듈(Commerce, Callee, Board 등)과의 통신은 Interface만을 통해 이루어지며, 구체 클래스 직접 참조는 금지된다.

```
┌─────────────────────────────────────────────────────────────────┐
│                   HongCafe Global Backend                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Member Module (BC)                      │  │
│  │                                                          │  │
│  │  [MemberCtrl] [MypageCtrl] [ProfileCtrl]                │  │
│  │       ↓            ↓            ↓                        │  │
│  │  [MemberRegistrationService] [MemberProfileService]      │  │
│  │       ↓                 ↓         ↓                      │  │
│  │  [MemberRepo]   [MypageRepo]  [SnsRepo]                  │  │
│  └───────────────────────────┬──────────────────────────────┘  │
│                              │ Interface Only                  │
│  ┌───────────────────────────▼──────────────────────────────┐  │
│  │              Shared Module (공유 도메인)                   │  │
│  │      SharedModels / Entities / ValueObjects              │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────── ┘
     │           │          │             │
 SMS Link    Kakao       TemplateMail   AWS S3
 API         AlimTalk
```

### 4.2 외부 시스템 연결 요약

| 외부 시스템 | 연결 방향 | 프로토콜 | 인증 방식 |
|-----------|----------|---------|----------|
| SMS Link API | 내부 → 외부 | HTTPS REST | X-Api-Key |
| Kakao AlimTalk | 내부 → 외부 | HTTPS REST | REST API Key |
| TemplateMail | 내부 → 외부 | HTTPS REST / SMTP | Internal API Key |
| AWS S3 | 내부 → 외부 | AWS SDK / Pre-signed URL | IAM Role (Instance Profile) |
| SNS OAuth (6종) | 내부 → 외부 | HTTPS REST | OAuth 2.0 인가 코드 |
| Aurora MySQL | 내부 → 외부 | MySQL Protocol (RDS Proxy) | IAM Auth |

---

## 5. 설계 뷰포인트 2 — 구성 관점 (Composition Viewpoint)

> **IEEE 1016-2009 §5.6 — Composition Viewpoint:** 시스템을 구성하는 요소와 그 계층 구조를 정의한다.

### 5.1 디렉토리 구조 (Directory Structure)

```
app/Modules/Member/
├── Config/
│   ├── Routes.php              # 49개 EP 명시적 등록 (Auto Routing 비활성)
│   └── Services.php            # DI 바인딩 (모듈 분산. 중앙 바인딩 금지)
├── Controllers/
│   ├── MemberController.php    # 1313 lines, 21 methods — 회원 생애주기
│   ├── MypageController.php    # 1256 lines, 20 methods — 마이페이지
│   └── ProfileController.php   # 184 lines, 8 methods — 공개 프로필
├── Services/
│   ├── MemberRegistrationService.php   # 295 lines — 가입/로그인/탈퇴
│   ├── MemberProfileService.php        # 131 lines — 프로필/SNS
│   └── SmsVerificationService.php      # 81 lines — SMS OTP
├── Repositories/
│   ├── MemberRepository.php    # 777 lines, 23 methods — 계정 CRUD
│   ├── MypageRepository.php    # 1187 lines, 22 methods — 이력 조회
│   └── SnsRepository.php       # 65 lines — SNS 연동
├── Interfaces/
│   ├── MemberRepositoryInterface.php
│   ├── MypageRepositoryInterface.php
│   ├── SnsRepositoryInterface.php
│   ├── MemberRegistrationServiceInterface.php
│   ├── MemberProfileServiceInterface.php
│   └── SmsVerificationServiceInterface.php
├── Models/
│   └── (Shared Models 참조: app/Modules/Shared/Models/)
└── Entities/
    └── MemberEntity.php        # 도메인 엔티티 + 변환 메서드
```

### 5.2 계층 구조 (Layered Architecture)

```
┌─────────────────────────────────────────────────┐
│  Layer 4: Presentation (Controllers)            │
│  입력 검증 + 응답 포맷. 비즈니스 로직 없음         │
├─────────────────────────────────────────────────┤
│  Layer 3: Application (Services)               │
│  비즈니스 규칙. 트랜잭션 경계. Repository 조합    │
├─────────────────────────────────────────────────┤
│  Layer 2: Infrastructure (Repositories)         │
│  DB 쿼리 전담. 소유권 조건 내장. 외부 시스템 없음  │
├─────────────────────────────────────────────────┤
│  Layer 1: Domain (Entities, Interfaces)         │
│  MemberEntity, 6개 Interface 계약 정의           │
└─────────────────────────────────────────────────┘
```

---

## 6. 설계 뷰포인트 3 — 논리 관점 (Logical Viewpoint)

> **IEEE 1016-2009 §5.7 — Logical Viewpoint:** 소프트웨어 요소의 책임, 속성, 관계를 정의한다.

### 6.1 MemberController (21 메서드)

**파일:** `app/Modules/Member/Controllers/MemberController.php`  
**책임:** 회원 생애주기 핵심 기능 (가입, 로그인, 비밀번호, SNS 연동, 탈퇴)  
**설계 원칙:** 입력 검증 + 서비스 위임 + 응답 포맷만 담당. 비즈니스 로직 없음.

| 번호 | 메서드명 | HTTP | 경로 | 인증 | CSRF |
|------|----------|------|------|------|------|
| 1 | `checkId()` | GET | `/api/members/check-id` | — | — |
| 2 | `checkNickname()` | GET | `/api/members/check-nickname` | — | — |
| 3 | `join()` | POST | `/api/members/join` | — | 필요 |
| 4 | `sendJoinCertMail()` | POST | `/api/members/send-join-cert-mail` | — | 필요 |
| 5 | `verifyJoinCertMail()` | POST | `/api/members/verify-join-cert-mail` | — | 필요 |
| 6 | `login()` | POST | `/api/members/login` | — | 필요 |
| 7 | `snsLogin()` | POST | `/api/members/sns-login` | — | 필요 |
| 8 | `logout()` | POST | `/api/members/logout` | JWT | 필요 |
| 9 | `refreshToken()` | POST | `/api/auth/refresh` | Refresh | 면제 |
| 10 | `findId()` | POST | `/api/members/find-id` | — | 필요 |
| 11 | `findPassword()` | POST | `/api/members/find-password` | — | 필요 |
| 12 | `resetPassword()` | POST | `/api/members/reset-password` | — | 필요 |
| 13 | `changePassword()` | POST | `/api/members/change-password` | JWT | 필요 |
| 14 | `snsConnect()` | POST | `/api/members/sns-connect` | JWT | 필요 |
| 15 | `snsDisconnect()` | DELETE | `/api/members/sns-disconnect` | JWT | 필요 |
| 16 | `withdraw()` | DELETE | `/api/members/withdraw` | JWT | 필요 |
| 17 | `getInfo()` | GET | `/api/members/info` | JWT | — |
| 18 | `checkPhone()` | GET | `/api/members/check-phone` | — | — |
| 19 | `sendFindIdMail()` | POST | `/api/members/send-find-id-mail` | — | 필요 |
| 20 | `verifyCertMail()` | POST | `/api/members/verify-cert-mail` | — | 필요 |
| 21 | `getVersion()` | GET | `/api/members/version` | — | — |

**컨트롤러 설계 패턴:**

```php
// 필터 체인: ratelimit → csrftoken → auth → [role:callee]
// 책임: 입력 검증 + 서비스 위임 + 응답 포맷
public function login(): ResponseInterface
{
    // 1. 입력 검증 (CI4 Validation)
    if (!$this->validate($rules)) {
        return $this->errorResponse('INVALID_INPUT', 400);
    }
    // 2. 서비스 위임 (비즈니스 로직은 Service에 위임)
    $result = $this->memberRegistrationService->login($email, $password);
    // 3. 응답 포맷 (camelCase 변환 포함)
    return $this->successResponse($result);
}
```

### 6.2 MypageController (20 메서드)

**파일:** `app/Modules/Member/Controllers/MypageController.php`  
**책임:** 마이페이지 이력 조회, 닉네임/전화번호 변경, 결제 수단 관리, 리뷰

| 번호 | 메서드명 | HTTP | 경로 | 인증 | CSRF |
|------|----------|------|------|------|------|
| 1 | `getCallHistory()` | GET | `/api/mypage/call-history` | JWT | — |
| 2 | `getCoinHistory()` | GET | `/api/mypage/coin-history` | JWT | — |
| 3 | `getOrderList()` | GET | `/api/mypage/order-list` | JWT | — |
| 4 | `getCouponList()` | GET | `/api/mypage/coupon-list` | JWT | — |
| 5 | `getAlarmList()` | GET | `/api/mypage/alarm-list` | JWT | — |
| 6 | `getChatList()` | GET | `/api/mypage/chat-list` | JWT | — |
| 7 | `getSnsList()` | GET | `/api/mypage/sns-list` | JWT | — |
| 8 | `changeNickname()` | PUT | `/api/mypage/change-nickname` | JWT | 필요 |
| 9 | `sendSms()` | POST | `/api/mypage/send-sms` | JWT | 필요 |
| 10 | `verifySms()` | POST | `/api/mypage/verify-sms` | JWT | 필요 |
| 11 | `changePhone()` | PUT | `/api/mypage/change-phone` | JWT | 필요 |
| 12 | `registerPayment()` | POST | `/api/mypage/register-payment` | JWT | 필요 |
| 13 | `cancelPayment()` | DELETE | `/api/mypage/cancel-payment` | JWT | 필요 |
| 14 | `getPaymentInfo()` | GET | `/api/mypage/payment-info` | JWT | — |
| 15 | `writeReview()` | POST | `/api/mypage/write-review` | JWT | 필요 |
| 16 | `modifyReview()` | PUT | `/api/mypage/modify-review` | JWT | 필요 |
| 17 | `deleteReview()` | DELETE | `/api/mypage/delete-review` | JWT | 필요 |
| 18 | `getProfileImage()` | GET | `/api/mypage/profile-image` | JWT | — |
| 19 | `uploadProfileImage()` | POST | `/api/mypage/upload-profile-image` | JWT | 필요 |
| 20 | `deleteProfileImage()` | DELETE | `/api/mypage/delete-profile-image` | JWT | 필요 |

### 6.3 ProfileController (8 메서드)

**파일:** `app/Modules/Member/Controllers/ProfileController.php`  
**책임:** 프로필 조회/수정 (공개 정보 포함)

| 번호 | 메서드명 | HTTP | 경로 | 인증 |
|------|----------|------|------|------|
| 1 | `getProfile()` | GET | `/api/profile/{ac_id}` | — |
| 2 | `getMyProfile()` | GET | `/api/profile/me` | JWT |
| 3 | `updateProfile()` | PUT | `/api/profile/me` | JWT |
| 4 | `getInterests()` | GET | `/api/profile/interests` | — |
| 5 | `updateInterests()` | PUT | `/api/profile/interests` | JWT |
| 6 | `getLanguages()` | GET | `/api/profile/languages` | — |
| 7 | `updateLanguages()` | PUT | `/api/profile/languages` | JWT |
| 8 | `getProfileStats()` | GET | `/api/profile/{ac_id}/stats` | — |

---

## 7. 설계 뷰포인트 4 — 의존성 관점 (Dependency Viewpoint)

> **IEEE 1016-2009 §5.8 — Dependency Viewpoint:** 설계 요소 간 사용, 생성, 호출 의존성을 정의한다.

### 7.1 의존성 다이어그램 (Dependency Diagram)

```
MemberController ──uses──→ MemberRegistrationServiceInterface
MemberController ──uses──→ MemberProfileServiceInterface

MypageController ──uses──→ MemberProfileServiceInterface
ProfileController ──uses──→ MemberProfileServiceInterface

MemberRegistrationService ──implements──→ MemberRegistrationServiceInterface
MemberRegistrationService ──uses──→ MemberRepositoryInterface
MemberRegistrationService ──uses──→ SmsVerificationServiceInterface

MemberProfileService ──implements──→ MemberProfileServiceInterface
MemberProfileService ──uses──→ MemberRepositoryInterface
MemberProfileService ──uses──→ MypageRepositoryInterface
MemberProfileService ──uses──→ SnsRepositoryInterface

SmsVerificationService ──implements──→ SmsVerificationServiceInterface
SmsVerificationService ──uses──→ MypageRepositoryInterface [SMS 카운트]
SmsVerificationService ──calls──→ SMS Link API [외부]

MemberRepository ──implements──→ MemberRepositoryInterface
MypageRepository ──implements──→ MypageRepositoryInterface
SnsRepository ──implements──→ SnsRepositoryInterface
```

### 7.2 DI 등록 (Services.php)

```php
// app/Modules/Member/Config/Services.php
namespace App\Modules\Member\Config;

use CodeIgniter\Config\BaseService;

class Services extends BaseService
{
    public static function memberRepository(bool $getShared = true): MemberRepositoryInterface
    {
        if ($getShared) {
            return static::getSharedInstance('memberRepository');
        }
        return new MemberRepository(db_connect());
    }

    public static function memberRegistrationService(bool $getShared = true): MemberRegistrationServiceInterface
    {
        if ($getShared) {
            return static::getSharedInstance('memberRegistrationService');
        }
        return new MemberRegistrationService(
            static::memberRepository(),
            static::smsVerificationService()
        );
    }

    public static function memberProfileService(bool $getShared = true): MemberProfileServiceInterface
    {
        if ($getShared) {
            return static::getSharedInstance('memberProfileService');
        }
        return new MemberProfileService(
            static::memberRepository(),
            static::mypageRepository(),
            static::snsRepository()
        );
    }

    // SmsVerificationService, MypageRepository, SnsRepository — 동일 패턴
}
```

**DI 정책:**
- 중앙 `app/Config/Services.php`에 바인딩 금지
- 모듈별 분산 (`Modules/Member/Config/Services.php`)
- Controller/Service에서 구체 클래스 직접 `new` 금지. `service()` 함수 사용

---

## 8. 설계 뷰포인트 5 — 정보 관점 (Information Viewpoint)

> **IEEE 1016-2009 §5.9 — Information Viewpoint:** 시스템에서 생성, 변환, 소비되는 정보를 정의한다.

### 8.1 핵심 도메인 엔티티 (Core Domain Entity)

#### MemberEntity

```php
namespace App\Modules\Member\Entities;

class MemberEntity
{
    // 식별자
    public int $ac_id;

    // 인증 정보
    public string $ac_email;
    public ?string $ac_password;   // bcrypt. SNS 전용 계정은 null

    // 프로필
    public string $ac_nick;
    public ?string $ac_phone;
    public ?string $ac_name;
    public ?string $ac_profile_img;

    // 계정 상태
    public string $ac_status;      // A(Active)|D(Deleted)|B(Banned)|S(Suspended)
    public ?string $ce_code;       // null=Caller, 값 존재=Callee

    // SNS OAuth ID 필드 (6종)
    public ?string $ac_google_id;
    public ?string $ac_kakao_id;
    public ?string $ac_naver_id;
    public ?string $ac_facebook_id;
    public ?string $ac_apple_id;
    public ?string $ac_line_id;

    // 닉네임 관리
    public ?DateTimeImmutable $ac_nick_changed_at;  // UTC

    // 감사 필드
    public DateTimeImmutable $created_at;
    public DateTimeImmutable $updated_at;
    public ?DateTimeImmutable $deleted_at;

    // 변환 메서드
    public function toPayload(): array;      // JWT Access Token payload 생성
    public function toCamelCase(): array;    // API 응답 camelCase 변환
    public function isActive(): bool;        // ac_status === 'A'
    public function isCaller(): bool;        // ce_code === null
    public function isCallee(): bool;        // ce_code !== null
}
```

### 8.2 DB 스키마 — 핵심 테이블

#### tb_account (회원 계정)

| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `ac_id` | INT UNSIGNED | PK, AUTO_INCREMENT | 회원 고유 ID |
| `ac_email` | VARCHAR(255) | UNIQUE, NOT NULL | 이메일 (로그인 ID) |
| `ac_password` | VARCHAR(255) | NULL | bcrypt 해시. SNS 전용은 NULL |
| `ac_nick` | VARCHAR(50) | UNIQUE, NOT NULL | 닉네임 |
| `ac_phone` | VARCHAR(20) | NULL | 휴대폰 번호 |
| `ac_name` | VARCHAR(100) | NULL | 실명 |
| `ac_status` | CHAR(1) | NOT NULL, DEFAULT 'A' | A/D/B/S |
| `ac_profile_img` | VARCHAR(500) | NULL | S3 CloudFront URL |
| `ce_code` | VARCHAR(50) | NULL | 상담사 코드 |
| `ac_google_id` | VARCHAR(255) | NULL | Google OAuth ID |
| `ac_kakao_id` | VARCHAR(255) | NULL | Kakao OAuth ID |
| `ac_naver_id` | VARCHAR(255) | NULL | Naver OAuth ID |
| `ac_facebook_id` | VARCHAR(255) | NULL | Facebook OAuth ID |
| `ac_apple_id` | VARCHAR(255) | NULL | Apple OAuth ID |
| `ac_line_id` | VARCHAR(255) | NULL | Line OAuth ID |
| `ac_payment_token` | VARCHAR(500) | NULL | PG사 자동결제 토큰 |
| `ac_simplepay_pw` | VARCHAR(255) | NULL | 간편결제 PIN 해시 |
| `ac_nick_changed_at` | DATETIME | NULL | 닉네임 마지막 변경 일시 (UTC) |
| `created_at` | DATETIME | NOT NULL | 가입일 (UTC) |
| `updated_at` | DATETIME | NOT NULL | 최종 수정일 (UTC) |
| `deleted_at` | DATETIME | NULL | 탈퇴 일시 (UTC) |

**인덱스:** `ac_email` (UNIQUE), `ac_nick` (UNIQUE), `ac_phone` (INDEX), `ac_status` (INDEX)

#### 계정 상태 전이도 (Account Status FSM)

```
[신규 가입]
    │
    ▼
A (Active) ─────[관리자 제재]────→ B (Banned)
    │
    ├───[일시 정지]────→ S (Suspended)
    │
    └───[탈퇴 요청]────→ D (Deleted)
                              │
                    [30일 후 재가입 허용]
                              │
                    ──────────▼──────────
                       동일 이메일 재가입 가능
```

### 8.3 데이터 흐름 규칙 (Data Flow Rules)

| 규칙 | 내용 |
|------|------|
| DB → API 변환 | `snake_case` → `camelCase` 변환 필수 (`toCamelCase()` 메서드) |
| 날짜/시간 내부 | `DateTimeImmutable` + `DateTimeZone('UTC')` 강제 |
| 날짜/시간 API 응답 | ISO 8601 UTC (`2026-04-15T09:00:00Z`) |
| 비밀번호 | bcrypt(cost=12) 해시. 평문 전달/저장 절대 금지 |
| PG 토큰 | PG사 토큰만 저장. 카드 원본 정보 서버 미보관 |

---

## 9. 설계 뷰포인트 6 — 패턴 관점 (Patterns Use Viewpoint)

> **IEEE 1016-2009 §5.10 — Patterns Use Viewpoint:** 설계에 적용된 아키텍처 패턴을 기술한다.

### 9.1 적용 패턴 목록

| 패턴 | 적용 위치 | 목적 |
|------|----------|------|
| **Repository Pattern** | `Repositories/` | DB 접근 추상화. 비즈니스 로직과 DB 쿼리 분리 |
| **Interface Segregation** | `Interfaces/` (6개) | 의존성 역전. 테스트 시 Mock 교체 용이 |
| **Service Layer Pattern** | `Services/` | 비즈니스 규칙 집중. 트랜잭션 경계 관리 |
| **Decorator Pattern (예비)** | `Repositories/` | 향후 Redis 캐시 레이어 추가 시 적용 가능 |
| **Outbox Pattern** | `global_sync_pub_log` | 크로스 도메인 이벤트 발행. 트랜잭션 보장 |
| **Token Family Pattern** | `MemberRegistrationService` | Refresh Token 재사용 감지 + 계보 전체 무효화 |
| **Dummy Hash Pattern** | `MemberRegistrationService::login()` | CWE-204 타이밍 공격 방지 |
| **Defense in Depth** | Filter → Controller → Repository | OWASP 인가 3계층 |

### 9.2 CWE-204 더미 해시 패턴 (Dummy Hash Pattern)

```php
public function login(string $email, string $password): array
{
    $account = $this->memberRepository->findByEmail($email);

    // [CWE-204 방지] 계정 미존재 시 더미 연산으로 응답 시간 균일화
    // bcrypt cost=12: ~200ms 소요 → 계정 존재 여부 열거 불가
    if ($account === null) {
        password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
        throw new UnauthorizedException(lang('Member.invalidCredentials'));
    }

    // 비밀번호 검증
    if (!password_verify($password, $account->ac_password)) {
        throw new UnauthorizedException(lang('Member.invalidCredentials'));
    }

    // 비밀번호 재해시 필요 시 자동 갱신
    if (password_needs_rehash($account->ac_password, PASSWORD_BCRYPT, ['cost' => 12])) {
        $this->memberRepository->updatePassword(
            $account->ac_id,
            password_hash($password, PASSWORD_BCRYPT, ['cost' => 12])
        );
    }

    return $this->issueJwtTokens($account->toPayload());
}
```

### 9.3 닉네임 쿨다운 패턴 (7-Day Cooldown Pattern)

```php
public function changeNickname(int $accountId, string $newNickname): void
{
    $lastChanged = $this->mypageRepository->getLastNicknameChangeDate($accountId);

    if ($lastChanged !== null) {
        $cooldownExpiry = $lastChanged->modify('+7 days');
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));

        if ($now < $cooldownExpiry) {
            throw new ConflictException(
                lang('Member.nicknameCooldown'),
                ['availableAt' => $cooldownExpiry->format('Y-m-d\TH:i:s\Z')]
            );
        }
    }

    $this->memberRepository->updateNickname($accountId, $newNickname);
    $this->mypageRepository->saveNicknameHistory($accountId, $newNickname);
}
```

---

## 10. 설계 뷰포인트 7 — 인터페이스 관점 (Interface Viewpoint)

> **IEEE 1016-2009 §5.11 — Interface Viewpoint:** 설계 요소 간 상호작용 인터페이스를 정의한다.

### 10.1 6개 PHP Interface 전체 명세

#### MemberRegistrationServiceInterface

```php
namespace App\Modules\Member\Interfaces;

interface MemberRegistrationServiceInterface
{
    public function register(array $data): array;
    public function login(string $email, string $password): array;
    public function loginWithSns(string $provider, string $authCode): array;
    public function logout(int $accountId): void;
    public function changePassword(int $accountId, string $currentPw, string $newPw): void;
    public function resetPassword(string $token, string $newPw): void;
    public function withdraw(int $accountId, ?string $password): void;
    public function issueJwtTokens(array $payload): array;
}
```

#### MemberProfileServiceInterface

```php
namespace App\Modules\Member\Interfaces;

interface MemberProfileServiceInterface
{
    public function changeNickname(int $accountId, string $nickname): void;
    public function uploadProfileImage(int $accountId, array $file): string;
    public function deleteProfileImage(int $accountId): void;
    public function updateProfile(int $accountId, array $data): array;
    public function connectSns(int $accountId, string $provider, string $authCode): void;
    public function disconnectSns(int $accountId, string $provider): void;
}
```

#### SmsVerificationServiceInterface

```php
namespace App\Modules\Member\Interfaces;

interface SmsVerificationServiceInterface
{
    public function sendOtp(string $phone, int $accountId): void;
    public function verifyOtp(string $phone, string $otp): bool;
    public function getDailyCount(string $phone): int;
    public function generateOtp(): string;
}
```

#### MemberRepositoryInterface

```php
namespace App\Modules\Member\Interfaces;

interface MemberRepositoryInterface
{
    public function findById(int $id): ?MemberEntity;
    public function findByEmail(string $email): ?MemberEntity;
    public function findByPhone(string $phone): ?MemberEntity;
    public function findByNickname(string $nickname): ?MemberEntity;
    public function findBySnsId(string $provider, string $snsId): ?MemberEntity;
    public function create(array $data): int;
    public function updatePassword(int $id, string $hashedPw): bool;
    public function updateNickname(int $id, string $nickname): bool;
    public function updatePhone(int $id, string $phone): bool;
    public function updateStatus(int $id, string $status): bool;
    public function updateProfileImage(int $id, ?string $imageUrl): bool;
    public function connectSns(int $id, string $provider, string $snsId): bool;
    public function disconnectSns(int $id, string $provider): bool;
    public function getSnsProviders(int $id): array;
    public function emailExists(string $email): bool;
    public function nicknameExists(string $nickname): bool;
    public function phoneExists(string $phone): bool;
    public function saveMailCert(array $data): bool;
    public function findMailCert(string $token): ?array;
    public function markMailCertUsed(int $certId): bool;
    public function invalidateAllRefreshTokens(int $accountId): bool;
    public function saveRefreshToken(int $accountId, string $jti, string $family): bool;
    public function findRefreshToken(string $jti): ?array;
}
```

#### MypageRepositoryInterface

```php
namespace App\Modules\Member\Interfaces;

interface MypageRepositoryInterface
{
    public function getCallHistory(int $accountId, int $page, int $perPage): array;
    public function getCoinHistory(int $accountId, int $page, int $perPage): array;
    public function getOrderList(int $accountId, int $page, int $perPage): array;
    public function getCouponList(int $accountId, string $status): array;
    public function getAlarmList(int $accountId, int $page, int $perPage): array;
    public function getChatList(int $accountId, int $page, int $perPage): array;
    public function getSnsList(int $accountId): array;
    public function getLastNicknameChangeDate(int $accountId): ?DateTimeImmutable;
    public function saveNicknameHistory(int $accountId, string $nickname): bool;
    public function getDailySmsCount(string $phone): int;
    public function saveSmsAuth(array $data): bool;
    public function findSmsAuth(string $phone, string $otp): ?array;
    public function markSmsAuthUsed(int $smsAuthId): bool;
    public function getPaymentInfo(int $accountId): ?array;
    public function savePaymentToken(int $accountId, array $data): bool;
    public function deletePaymentToken(int $accountId): bool;
    public function writeReview(array $data): int;
    public function modifyReview(int $reviewId, int $accountId, array $data): bool;
    public function deleteReview(int $reviewId, int $accountId): bool;
    public function reviewExists(int $callResultId): bool;
    public function getUnreadAlarmCount(int $accountId): int;
    public function markAllAlarmsRead(int $accountId): bool;
}
```

#### SnsRepositoryInterface

```php
namespace App\Modules\Member\Interfaces;

interface SnsRepositoryInterface
{
    public function findBySnsId(string $provider, string $snsId): ?array;
    public function saveSnsConnection(int $accountId, string $provider, string $snsId): bool;
    public function removeSnsConnection(int $accountId, string $provider): bool;
    public function getConnectionCount(int $accountId): int;
}
```

### 10.2 Repository 상세 설계

#### MemberRepository (23 메서드)

| 번호 | 메서드명 | 반환 타입 | 관련 테이블 | 설명 |
|------|----------|----------|------------|------|
| 1 | `findById(int $id)` | `?MemberEntity` | tb_account | ac_id로 단건 조회 |
| 2 | `findByEmail(string $email)` | `?MemberEntity` | tb_account | 이메일로 단건 조회 |
| 3 | `findByPhone(string $phone)` | `?MemberEntity` | tb_account | 전화번호로 단건 조회 |
| 4 | `findByNickname(string $nickname)` | `?MemberEntity` | tb_account | 닉네임으로 단건 조회 |
| 5 | `findBySnsId(string $provider, string $snsId)` | `?MemberEntity` | tb_account | SNS Provider+ID로 조회 |
| 6 | `create(array $data)` | `int` | tb_account | 신규 계정 생성, ac_id 반환 |
| 7 | `updatePassword(int $id, string $hashedPw)` | `bool` | tb_account | bcrypt 해시 업데이트 |
| 8 | `updateNickname(int $id, string $nickname)` | `bool` | tb_account | 닉네임 변경 |
| 9 | `updatePhone(int $id, string $phone)` | `bool` | tb_account | 전화번호 변경 |
| 10 | `updateStatus(int $id, string $status)` | `bool` | tb_account | 상태 변경 (A/D/B/S) |
| 11 | `updateProfileImage(int $id, ?string $imageUrl)` | `bool` | tb_account | 프로필 이미지 URL 업데이트 |
| 12 | `connectSns(int $id, string $provider, string $snsId)` | `bool` | tb_account | SNS 연동 저장 |
| 13 | `disconnectSns(int $id, string $provider)` | `bool` | tb_account | SNS 연동 해제 |
| 14 | `getSnsProviders(int $id)` | `array` | tb_account | 연동된 SNS Provider 목록 |
| 15 | `emailExists(string $email)` | `bool` | tb_account | 이메일 중복 확인 |
| 16 | `nicknameExists(string $nickname)` | `bool` | tb_account | 닉네임 중복 확인 |
| 17 | `phoneExists(string $phone)` | `bool` | tb_account | 전화번호 중복 확인 |
| 18 | `saveMailCert(array $data)` | `bool` | tb_mail_cert | 이메일 인증 토큰 저장 |
| 19 | `findMailCert(string $token)` | `?array` | tb_mail_cert | 이메일 인증 토큰 조회 |
| 20 | `markMailCertUsed(int $certId)` | `bool` | tb_mail_cert | 인증 토큰 사용 처리 |
| 21 | `invalidateAllRefreshTokens(int $accountId)` | `bool` | (refresh token store) | Token Family 전체 무효화 |
| 22 | `saveRefreshToken(int $accountId, string $jti, string $family)` | `bool` | (refresh token store) | Refresh Token jti 저장 |
| 23 | `findRefreshToken(string $jti)` | `?array` | (refresh token store) | jti로 Refresh Token 조회 |

#### MypageRepository (22 메서드)

| 번호 | 메서드명 | 관련 테이블 | 설명 |
|------|----------|------------|------|
| 1 | `getCallHistory()` | tb_call_result | 통화 이력 페이지네이션 |
| 2 | `getCoinHistory()` | tb_coin | 코인 이력 페이지네이션 |
| 3 | `getOrderList()` | tb_order, tb_goods_order | 주문 이력 조인 |
| 4 | `getCouponList()` | tb_coupon, tb_coupon_user | 쿠폰 목록 (유효/만료/사용) |
| 5 | `getAlarmList()` | tb_alarm | 알림 목록 페이지네이션 |
| 6 | `getChatList()` | tb_chat_rooms | 채팅방 이력 |
| 7 | `getSnsList()` | tb_account | SNS 연동 목록 |
| 8 | `getLastNicknameChangeDate()` | tb_account_history | 마지막 닉네임 변경일 |
| 9 | `saveNicknameHistory()` | tb_account_history | 닉네임 변경 이력 저장 |
| 10 | `getDailySmsCount()` | tb_sms_auth | 일별 SMS 발송 카운트 |
| 11 | `saveSmsAuth()` | tb_sms_auth | SMS OTP 저장 |
| 12 | `findSmsAuth()` | tb_sms_auth | OTP 조회 (TTL 5분) |
| 13 | `markSmsAuthUsed()` | tb_sms_auth | OTP 사용 처리 |
| 14 | `getPaymentInfo()` | tb_account | 결제 수단 정보 조회 |
| 15 | `savePaymentToken()` | tb_account | PG 토큰 저장 |
| 16 | `deletePaymentToken()` | tb_account | 결제 수단 삭제 |
| 17 | `writeReview()` | tb_call_result | 리뷰 작성, review_id 반환 |
| 18 | `modifyReview()` | tb_call_result | 리뷰 수정 (소유권 조건 내장) |
| 19 | `deleteReview()` | tb_call_result | 리뷰 삭제 (소유권 조건 내장) |
| 20 | `reviewExists()` | tb_call_result | 리뷰 중복 확인 |
| 21 | `getUnreadAlarmCount()` | tb_alarm | 미읽음 알림 수 |
| 22 | `markAllAlarmsRead()` | tb_alarm | 전체 알림 읽음 처리 |

**소유권 보호 패턴 (OWASP API5:2023):**

```php
// 모든 Repository 조회/수정/삭제 메서드: ac_id WHERE 조건 필수
public function getCallHistory(int $accountId, int $page, int $perPage): array
{
    return $this->db
        ->table('tb_call_result')
        ->where('ac_id', $accountId)  // 소유권 조건 — 절대 누락 금지
        ->orderBy('created_at', 'DESC')
        ->get()
        ->getResultArray();
}
```

---

## 11. 설계 뷰포인트 8 — 행동 관점 (Behavioral Viewpoint)

> **IEEE 1016-2009 §5.12 — Behavioral Viewpoint:** 시스템의 동적 행동을 시퀀스 다이어그램으로 기술한다.

### 11.1 회원가입 시퀀스

```
Client      MemberCtrl    RegistrationSvc    MemberRepo    MailService
  │              │               │                │              │
  │ POST /join   │               │                │              │
  ├────────────→ │               │                │              │
  │              │ validate()    │                │              │
  │              ├─ OK ─────────→│                │              │
  │              │               │ emailExists()  │              │
  │              │               ├──────────────→ │              │
  │              │               │ ← false        │              │
  │              │               │ nicknameExists()│             │
  │              │               ├──────────────→ │              │
  │              │               │ ← false        │              │
  │              │               │ password_hash(pw, BCRYPT, 12) │
  │              │               │ create(data)   │              │
  │              │               ├──────────────→ │              │
  │              │               │ ← ac_id        │              │
  │              │               │ saveMailCert() │              │
  │              │               ├──────────────→ │              │
  │              │               │ send(certMail) │              │
  │              │               ├──────────────────────────────→│
  │ 201 Created  │               │                │              │
  │ ←────────── │               │                │              │
```

### 11.2 로그인 시퀀스 (CWE-204 더미 연산 포함)

```
Client       MemberCtrl    RegistrationSvc    MemberRepo    JwtService
  │               │               │                │              │
  │ POST /login   │               │                │              │
  ├─────────────→ │               │                │              │
  │               │ login(e, pw)  │                │              │
  │               ├──────────────→│                │              │
  │               │               │ findByEmail(e) │              │
  │               │               ├──────────────→ │              │
  │               │               │ ← null [미존재]│              │
  │               │               │                │              │
  │     [CWE-204] │ password_hash(dummy, BCRYPT, 12)              │
  │               │               ├─ 더미 연산 ───→               │
  │               │               │                │              │
  │ 401 INVALID_CREDENTIALS       │                │              │
  │ ←──────────── │               │                │              │
  │               │               │                │              │
  │ POST /login [정상]            │                │              │
  ├─────────────→ │               │                │              │
  │               │               │ findByEmail(e) │              │
  │               │               ├──────────────→ │              │
  │               │               │ ← MemberEntity │              │
  │               │               │ password_verify(pw, hash)    │
  │               │               │ issueJwtTokens(payload)      │
  │               │               ├──────────────────────────────→│
  │               │               │ ← {hc_access, hc_refresh, hc_csrf} cookies
  │ 200 OK        │               │                │              │
  │ ←──────────── │               │                │              │
```

### 11.3 SMS OTP 시퀀스

```
Client      MypageCtrl    SmsVerifySvc    MypageRepo    SMS Link API
  │              │               │               │              │
  │ POST send-sms│               │               │              │
  ├────────────→ │               │               │              │
  │              │ sendOtp(phone)│               │              │
  │              ├──────────────→│               │              │
  │              │               │ getDailyCnt() │              │
  │              │               ├─────────────→ │              │
  │              │               │ ← count (≤10) │              │
  │              │               │ generateOtp() │              │
  │              │               │ POST /send    │              │
  │              │               ├──────────────────────────────→│
  │              │               │ ← 200 {resultCode:"00"}      │
  │              │               │ saveSmsAuth() │              │
  │              │               ├─────────────→ │              │
  │ 200 OK       │               │               │              │
  │ ←─────────── │               │               │              │
```

### 11.4 Token 갱신 시퀀스 (Token Family Rotation)

```
Client       MemberCtrl    RegistrationSvc    MemberRepo
  │               │               │                │
  │ POST /refresh (hc_refresh 쿠키)               │
  ├─────────────→ │               │                │
  │               │ refreshToken()│                │
  │               ├──────────────→│                │
  │               │               │ findRefreshToken(jti)         │
  │               │               ├──────────────→ │
  │               │               │ ← {jti, family, isRevoked}   │
  │               │               │                │
  │               │   [jti 이미 사용됨 감지]        │
  │               │               │ invalidateAll(family)         │
  │               │               ├──────────────→ │
  │ 401 REFRESH_TOKEN_REUSED     │                │
  │ ←──────────── │               │                │
  │               │               │                │
  │   [정상 갱신] │               │                │
  │               │               │ saveRefreshToken(new_jti, family) │
  │               │               ├──────────────→ │
  │               │               │ issueJwtTokens(payload)       │
  │ 200 OK + 새 쿠키 3종          │                │
  │ ←──────────── │               │                │
```

---

## 12. 설계 오버레이 (Design Overlay)

> **IEEE 1016-2009 §5.13 — Design Overlay:** 공통 관심사(Cross-cutting Concerns)를 기술한다.

### 12.1 필터 체인 (Filter Chain)

모든 EP는 다음 필터 체인을 통과한다:

```
HTTP Request
    │
    ▼
[ratelimit]       — 글로벌 Rate Limit 확인
    │
    ▼
[csrftoken]       — POST/PUT/DELETE: CSRF 토큰 검증 (GET 면제)
    │
    ▼
[auth]            — JWT hc_access 쿠키 검증 (공개 EP는 EXCLUDED_PATHS 면제)
    │
    ▼
[role:callee]     — 상담사 전용 EP만 적용 (ce_code 존재 확인)
    │
    ▼
Controller
```

### 12.2 에러 응답 오버레이 (Error Response Overlay)

모든 에러 응답은 표준 형식을 따른다:

```json
{
    "error": {
        "code":    "SCREAMING_SNAKE_CASE_현상서술형",
        "message": "lang() 키 기반 다국어 메시지"
    }
}
```

- HTTP 상태코드가 성공/실패의 SSOT (RFC 7231)
- 에러 코드: suffix 없음 (`INVALID_INPUT`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`, `INTERNAL`)
- 스택 트레이스 클라이언트 노출 절대 금지 (로그에만 기록)

### 12.3 페이지네이션 오버레이 (Pagination Overlay)

모든 목록 조회 EP는 CI4 빌트인 Pager를 사용한다:

```json
{
    "data": [
        { "callId": 1001, "createdAt": "2026-04-15T09:00:00Z" }
    ],
    "meta": {
        "currentPage": 1,
        "perPage":     10,
        "total":       100,
        "lastPage":    10
    }
}
```

커스텀 Pager 구현 금지. `Model::paginate()` + `Model::pager` 프로퍼티만 사용.

### 12.4 코딩 표준 오버레이 (Coding Standard Overlay)

| 규칙 | 내용 |
|------|------|
| strict_types | `declare(strict_types=1)` 모든 PHP 파일 필수 |
| 날짜/시간 | `DateTimeImmutable` 강제. `date()`, `time()` 사용 금지 |
| 타임존 | UTC 전용. `new DateTimeZone('UTC')` |
| 응답 키 | `snake_case` → `camelCase` 변환 필수 |
| URL 형식 | kebab-case + 복수형 (`/api/members/check-id`) |
| i18n | 에러 메시지 `lang()` 키 사용. 하드코딩 문자열 금지 |
| 환경 판정 | `ENVIRONMENT` 상수 사용. `getenv('CI_ENVIRONMENT')` 혼용 금지 |

### 12.5 환경 분기 오버레이 (Environment-Aware Behavior Overlay)

모든 외부 서비스 연동 Service는 `ENVIRONMENT` 상수 기준으로 분기한다. 비프로덕션(dev/staging/test) 환경에서는 외부 cURL 호출을 스킵하고 고정값 또는 DB 직접 매칭으로 대체하여 계약 테스트의 결정성을 확보한다.

```php
// app/Libraries/Communicator/Sms.php — sendCertSms()
public function sendCertSms(string $phone, string $acCountry): array
{
    if (ENVIRONMENT !== 'production') {
        // 비프로덕션: SMSLINK API 호출 스킵, 인증번호 고정값 반환
        // saveSmsLog() 호출 제거 → 로그 테이블 폴루션 방지
        return ['result' => true, 'certNum' => '111111'];
    }
    // 프로덕션: 실제 SMS 발송
    return $this->callSmsLinkApi($phone, $acCountry);
}
```

```php
// app/Modules/Member/Services/SmsVerificationService.php — checkCertNum()
public function checkCertNum(string $phone, string $certNum): array
{
    // 전 환경 DB 직접 매칭 (SMSLINK verify API 제거)
    // tb_interphone_auth WHERE cr_phone = :phone AND cert_num = :cn AND created_at > NOW() - INTERVAL 5 MINUTE
    $row = $this->memberRepository->checkCertNum($phone, $certNum);
    if ($row === null) {
        return ['result' => false, 'msg' => lang('Member.certExpired')];
    }
    return ['result' => true];
}
```

**적용 지점 매트릭스:**

| Service/Library | 프로덕션 | 비프로덕션 | 커밋 |
|----------------|---------|-----------|------|
| `Sms::sendCertSms()` | SMSLINK cURL | 스킵, `111111` 반환, `saveSmsLog` 미호출 | `64aedf7`, `d532349` |
| `MemberController::verifyPhone()` | AlimTalk cURL | 스킵, `222222` 고정 | `25f2285` |
| `MemberController::findId()` | SMS/AlimTalk cURL | 스킵, `222222` 고정 | `a064453` |
| `MemberController::sendMailCert()` | TemplateMail | 스킵 | `0731339` |
| `MemberController::findPasswordCert()` | 임시PW 메일 | 스킵 | `ade84ab` |
| `MemberRegistrationService::joinUser()` | Hermes DB | 스킵 (join 모드) | `4fed062` |
| `SmsVerificationService::checkCertNum()` | DB 매칭 | DB 매칭 (전 환경 통일) | `64aedf7` |
| `Config/Cors.php` allowedOrigins | 프로덕션 도메인 | + `localhost:5500`, `127.0.0.1:5500` | `a446d00`, `783699a` |

### 12.6 BaseController 세션 복원 오버레이 (Session Restoration Overlay)

BaseController는 레거시 `hdata` 암호화 쿠키와 신규 JWT 토큰을 모두 지원해야 한다. 다음 흐름으로 세션을 복원한다:

```
BaseController::initController()
 │
 ├─ [1] get_cookie('hdata') 시도
 │   ├─ $base_data = custom_decrypt(hdata)
 │   ├─ [방어] 복호화 실패 or ac_id 미존재 → hdata/ck_login_member 쿠키 만료 + $base_data = null (커밋 43e3d66)
 │   └─ [로드] MemberModel::AccountInfo('ac_id', $base_data['ac_id']) → $this->member
 │         └─ [방어] member null or ac_status ∉ {'2','4'} →
 │                ├─ 쿠키 만료 + $this->member = null (커밋 16a9144)
 │                └─ URI가 '/api/'로 시작: redirect 스킵, initController 계속 진행 (커밋 8be5005)
 │                    └─ URI가 '/api/' 아님: redirect(site_url()) + exit (기존 동작)
 │
 └─ [2] JWT Fallback — !is_login && $_SERVER['AUTH_USER']['ac_id'] 존재 시 (커밋 fbbf0a9)
     ├─ MemberModel::AccountInfo('ac_id', AUTH_USER['ac_id']) → $this->member
     ├─ ac_status ∈ {'2','4'} 확인
     └─ is_login = true
```

**설계 목적:**

| 방어 항목 | 방어 대상 시나리오 | 커밋 |
|----------|------------------|------|
| `hdata` 복호화 null 방어 | 손상/위조 쿠키로 인한 500 TypeError | `43e3d66` |
| 탈퇴/삭제 계정 쿠키 잔존 방어 | 탈퇴 직후 프론트에서 쿠키가 지워지지 않은 채 재접근 | `16a9144` |
| API 경로 redirect 금지 | JSON 클라이언트가 HTML redirect 응답 수신 → 파싱 실패 | `8be5005` |
| JWT fallback | 신규 JWT 인증 플로우와 레거시 hdata 세션 로직 병행 | `fbbf0a9` |

---

## 13. 아키텍처 결정 기록 (Architecture Decision Records)

### ADR-001 Repository 패턴 — Interface 강제

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-15 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | 모듈 내 비즈니스 로직과 DB 접근 분리 필요. 테스트 용이성 확보 필요 |
| **결정** | 모든 Repository는 Interface를 통해서만 접근. Controller/Service에서 구체 클래스 직접 참조 금지 |
| **이유** | 모듈 간 결합도 최소화. 단위 테스트 시 Mock 주입 가능. 향후 Redis 캐시 레이어 추가 시 Decorator 패턴 적용 가능 |
| **결과** | `app/Modules/Member/Interfaces/` 6개 Interface 정의. `Config/Services.php` DI 등록 |
| **트레이드오프** | 초기 인터페이스 정의 비용 발생. 장기적 유지보수 이익 > 초기 비용 |

### ADR-002 CWE-204 — 더미 bcrypt 연산

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-15 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | 로그인 시 이메일 미존재(빠름)와 비밀번호 불일치(느림) 응답 시간 차이로 사용자 열거 가능 |
| **결정** | 이메일 미존재 시 더미 `password_hash()` 연산(cost=12) 수행 |
| **이유** | CWE-204 차단. OWASP Authentication Cheat Sheet 직접 권고 사항. PHP 네이티브 구현으로 외부 의존성 없음 |
| **결과** | `MemberRegistrationService::login()` 내 더미 연산 코드 추가 |
| **트레이드오프** | bcrypt cost=12 기준 ~200ms 응답 시간 추가. 수용 가능 (보안 이익 우선) |

### ADR-003 닉네임 쿨다운 — DB 기반 UTC 시간 비교

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-15 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | 닉네임 남용(브랜드 사칭, 상담사 사칭) 방지 정책 필요. Redis 캐시 미보유 |
| **결정** | `tb_account_history` 이력 기반 UTC `DateTimeImmutable` 비교로 구현. Redis 캐시 미사용 |
| **이유** | Aurora MySQL 트랜잭션 일관성 보장. 캐시 만료 타이밍 이슈 없음. 이력 감사 가능 |
| **결과** | `tb_account_history` 테이블 변경 이력 저장. `MypageRepository::getLastNicknameChangeDate()` UTC 반환 |
| **트레이드오프** | DB 쿼리 추가 발생. 쿨다운 확인은 간단 단건 조회이므로 성능 영향 무시 가능 |

### ADR-004 Token Family — jti UNIQUE 제약

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-15 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | Refresh Token 탈취 후 재사용 시도 감지 및 대응 필요 |
| **결정** | Refresh Token `jti`를 DB UNIQUE 제약으로 관리. 재사용 감지 시 동일 `family`의 모든 토큰 즉시 무효화 |
| **이유** | RFC 6819 Section 5.2.2 준수. 탈취 토큰 재사용 즉시 감지. 모든 세션 강제 종료로 피해 최소화 |
| **결과** | `MemberRepository::invalidateAllRefreshTokens()` 구현. 비밀번호 변경/탈퇴 시도 시에도 동일 무효화 적용 |
| **트레이드오프** | 토큰 저장 DB 부하 증가. 보안 이익이 명백히 크므로 수용 가능 |

### ADR-005 비프로덕션 환경 분기 — 외부 서비스 호출 스킵

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-17 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | 외부 SMS/AlimTalk/Mail API 의존이 dev/staging 환경의 계약 테스트를 블로킹. 외부 API 과금 부담. 발송 실패가 회원가입·비밀번호 재설정 플로우 중단으로 이어짐 |
| **결정** | `ENVIRONMENT !== 'production'` 환경에서 SMS cURL 스킵, AlimTalk 스킵, Mail 스킵, Hermes DB 참조 스킵. 인증번호는 고정값(`111111`, `222222`) 반환. SMSLINK verify API는 전 환경 제거하고 `tb_interphone_auth` DB 5분 TTL 직접 매칭으로 전환 |
| **이유** | 계약 테스트 결정성 확보(MemberApiFeatureTest 19 EP 순차 통과). 외부 장애 격리. 개발자 환경 진입 장벽 완화 |
| **결과** | `Sms::sendCertSms`, `verifyPhone`, `findId`, `sendMailCert`, `findPasswordCert`, `joinUser`, `checkCertNum` 분기 구현. CORS `localhost:5500`/`127.0.0.1:5500` 전 환경 허용 |
| **트레이드오프** | 비프로덕션에서 실제 SMS/메일 플로우는 별도 E2E 스모크 테스트로 검증. 분기 로직 유지보수 비용 발생하나 통합 테스트 가용성 확보 이익이 큼 |

### ADR-006 JWT Fallback — 레거시 hdata + 신규 JWT 병행 지원

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-17 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | 마이그레이션 기간 중 레거시 `hdata` 암호화 쿠키 사용 클라이언트와 신규 JWT 토큰 클라이언트가 공존. BaseController는 `hdata`만 의존해 세션 구성하므로 JWT 인증 성공 계정이 `$this->member` 없이 API에 도달 |
| **결정** | BaseController::initController에 JWT Fallback 블록 추가 — `!is_login && $_SERVER['AUTH_USER']['ac_id']` 존재 시 `MemberModel::AccountInfo`로 멤버 로드. 추가로 API 경로에서 세션 불일치 시 redirect 스킵하고 initController를 계속 진행하여 컨트롤러의 `checkNeedLogin(true)`가 정상 동작하도록 보장 |
| **이유** | JWT 인증 플로우와 기존 BaseController 내 계정 로드 로직(alarm_count, callee 정보, chat 상태 등) 호환성 유지. API가 HTML redirect 응답을 받지 않도록 보장 |
| **결과** | 마이페이지·프로필 API가 JWT 단독 인증으로도 정상 동작. 회원 탈퇴/삭제 후 잔존 쿠키에도 TypeError 없이 우아하게 세션 파기 |
| **트레이드오프** | BaseController 복잡도 증가. 마이그레이션 완료 후 hdata 분기 제거 예정 |

### ADR-007 비밀번호 해싱 — Service 계층 단일 책임

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-17 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | 비밀번호 변경 플로우가 Service(해싱)와 Repository(재해싱)에서 이중 해싱 발생. `password_verify($plain, $hashed)` 영구 실패로 사용자 로그인 불가 (커밋 `021a314` 발견) |
| **결정** | 해싱은 Service 계층에서 단 1회 수행. Repository는 전달받은 해시를 변경 없이 저장. 모든 비밀번호 변경 경로(changePassword/resetPassword/findPasswordCert)에 동일 원칙 적용 |
| **이유** | OWASP Password Storage Cheat Sheet: single hashing. 이중 해싱은 bcrypt 알고리즘 의미 파괴. 테스트 커버리지로 회귀 방지 필요 |
| **결과** | ProfileService 내 `password_hash` 호출 단일화. Repository `updatePassword()` 해시 재처리 제거. `testChangePasswordVerifiesCurrentPassword` 테스트로 검증 |
| **트레이드오프** | 없음 — 단순 버그 수정. 추후 해싱 알고리즘 교체 시 Service 계층만 수정하면 되는 이점 |

### ADR-008 CORS 개발 도구 — localhost:5500 전 환경 허용

| 항목 | 내용 |
|------|------|
| **결정일** | 2026-04-17 |
| **상태** | 채택됨 (Accepted) |
| **맥락** | Flow Tester(tools/registration-flow.html)를 VS Code Live Server(5500 포트)로 실행하여 전 환경에서 API 검증 필요. 프로덕션 API를 대상으로 한 실측 검증 요구 |
| **결정** | `Config/Cors.php` `allowedOrigins`에 `http://localhost:5500`, `http://127.0.0.1:5500`을 **모든 환경(프로덕션 포함)** 에 추가. 공개 EP는 `credentials: 'omit'`, 인증 EP는 `credentials: 'include'`로 분리 |
| **이유** | 개발자가 프로덕션 상태를 직접 검증할 수 있는 단일 도구 제공. Credentials 분리로 공개 EP에서 쿠키 불필요 송신 방지 |
| **결과** | 회원가입·로그인·마이페이지 플로우를 브라우저 도구로 전 환경 검증 가능 |
| **트레이드오프** | 프로덕션 CORS 정책 완화. 화이트리스트는 `localhost:5500` 계열로 제한되므로 공격 표면 증가 미미. Origin 헤더 위조는 브라우저 단에서 방지 |

---

## 14. 설계-요구사항 추적 매트릭스 (Design–Requirement Traceability Matrix)

| FR/NFR ID | 요구사항 요약 | 설계 요소 | 파일 경로 | 메서드 |
|-----------|-------------|----------|----------|--------|
| FR-001 | 이메일 회원가입 | MemberRegistrationService | Services/MemberRegistrationService.php | `register()` |
| FR-001-3 | bcrypt 저장 | MemberRegistrationService | Services/MemberRegistrationService.php | `register()` |
| FR-002 | 로그인 | MemberRegistrationService | Services/MemberRegistrationService.php | `login()` |
| FR-002-4,5 | CWE-204 방지 | MemberRegistrationService | Services/MemberRegistrationService.php | `login()` — 더미 연산 |
| FR-002-9 | Token Family | MemberRegistrationService | Services/MemberRegistrationService.php | `issueJwtTokens()` |
| FR-003-4 | Token Family 무효화 | MemberRepository | Repositories/MemberRepository.php | `invalidateAllRefreshTokens()` |
| FR-004 | 닉네임 쿨다운 | MemberProfileService | Services/MemberProfileService.php | `changeNickname()` |
| FR-004-4 | 닉네임 이력 | MypageRepository | Repositories/MypageRepository.php | `saveNicknameHistory()` |
| FR-005 | SMS OTP | SmsVerificationService | Services/SmsVerificationService.php | `sendOtp()`, `verifyOtp()` |
| FR-005-2 | 10회/일 제한 | SmsVerificationService | Services/SmsVerificationService.php | `getDailyCount()` |
| FR-006 | SNS 연동 | MemberProfileService | Services/MemberProfileService.php | `connectSns()`, `disconnectSns()` |
| FR-006 | SNS Repository | SnsRepository | Repositories/SnsRepository.php | 전체 |
| FR-007 | 회원 탈퇴 | MemberRegistrationService | Services/MemberRegistrationService.php | `withdraw()` |
| FR-008 | 마이페이지 이력 | MypageRepository | Repositories/MypageRepository.php | `getCallHistory()` 외 |
| FR-008-8 | 소유권 조건 | MypageRepository | Repositories/MypageRepository.php | 모든 조회 메서드 |
| FR-009 | 자동결제 | MypageRepository | Repositories/MypageRepository.php | `savePaymentToken()` 외 |
| FR-010 | 리뷰 | MypageRepository | Repositories/MypageRepository.php | `writeReview()` 외 |
| FR-011 | 프로필 | MemberProfileService | Services/MemberProfileService.php | `updateProfile()` 외 |
| NFR-001 | CWE-204 | MemberRegistrationService | Services/MemberRegistrationService.php | `login()` |
| NFR-002 | bcrypt | MemberRegistrationService | Services/MemberRegistrationService.php | `register()`, `changePassword()` |
| NFR-003 | SMS 제한 | SmsVerificationService | Services/SmsVerificationService.php | `sendOtp()` |
| NFR-004 | 닉네임 쿨다운 | MemberProfileService | Services/MemberProfileService.php | `changeNickname()` |
| NFR-006 | 멱등성 | MemberRepository | Repositories/MemberRepository.php | `findRefreshToken()` |
| NFR-007 | 인가 3계층 | RoleFilter + Controllers + Repositories | Config/Filters.php 외 | 전체 |

---

## 15. 설계 검수 체크리스트 (Design Review Checklist)

### 레이어 책임 분리

| 항목 | 검증 기준 | 상태 |
|------|----------|------|
| Controller 책임 | 입력 검증 + 응답 포맷만 담당. 비즈니스 로직 없음 | 완료 |
| Service 책임 | 비즈니스 규칙만 담당. DB 쿼리 없음 | 완료 |
| Repository 책임 | DB 쿼리만 담당. 소유권 조건 내장. 외부 API 호출 없음 | 완료 |
| Interface 정의 | 6개 Interface 모두 정의 완료 | 완료 |
| DI 등록 | 모듈 분산 (`Modules/Member/Config/Services.php`). 중앙 바인딩 없음 | 완료 |

### 보안 설계

| 항목 | 검증 기준 | 상태 |
|------|----------|------|
| CWE-204 | 더미 bcrypt 연산 `login()` 내 구현 확인 | 완료 |
| bcrypt | cost=12, `password_verify()` 사용 | 완료 |
| Token Family | 비밀번호 변경/탈퇴 시 `invalidateAllRefreshTokens()` 호출 | 완료 |
| 소유권 조건 | 모든 Repository 조회/수정/삭제 메서드 `ac_id` WHERE 조건 | 완료 |
| 인가 3계층 | RoleFilter + checkNeedLogin + Repository 각 계층 독립 동작 | 완료 |

### 코딩 표준

| 항목 | 검증 기준 | 상태 |
|------|----------|------|
| strict_types | `declare(strict_types=1)` 모든 파일 | 완료 |
| DateTimeImmutable | `date()`, `time()` 사용 없음. `DateTimeImmutable` 전용 | 완료 |
| UTC 타임존 | DB/PHP 모두 UTC | 완료 |
| camelCase 응답 | API 응답 키 전수 camelCase 확인 | 완료 |
| Auto Routing | `setAutoRoute(false)`. 모든 EP 명시적 Routes.php 등록 | 완료 |

---

## 16. 타당성 검토 (Feasibility Review)

### 16.1 아키텍처 타당성

| 항목 | 근거 | 결론 |
|------|------|------|
| Modular Monolith | CI4 `app/Modules/` 패턴은 BC 분리를 지원하며 향후 마이크로서비스 분리 기반 제공. 단일 배포 단위로 운영 단순성 유지 | 타당 |
| Interface 강제 | PHP 8.4 타입 시스템 + CI4 `BaseService` DI. 테스트 용이성(Mock 주입)과 확장성(Decorator 패턴) 동시 확보 | 타당 |
| Query Builder 우선 | Aurora MySQL 3.12.0에서 CI4 Query Builder는 prepared statement 자동 적용으로 SQL Injection 방지. CTE/Window Function은 `$db->query()` + named binding 처리 | 타당 |

### 16.2 성능 타당성

| 항목 | 근거 | 결론 |
|------|------|------|
| bcrypt 더미 연산 비용 | cost=12 기준 약 100~300ms. 로그인 p95 < 300ms 목표와 상충 가능성 있으나, 보안 이익 우선. 실제 계정 존재 시 동일 시간 소요이므로 UX 영향 최소 | 수용 |
| Pre-signed URL | 서버 직접 스트리밍 대비 메모리 부담 없음. 대용량 이미지 업로드에 유리 | 타당 |

---

## 17. 변경 로그 (Change Log)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 — 3 Controllers(49 methods), 3 Services, 3 Repositories, 6 Interfaces, DB 스키마, 시퀀스 2건, ADR 4건 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS. IEEE 1016-2009 적용. 8개 설계 뷰포인트 (Context/Composition/Logical/Dependency/Information/Patterns/Interface/Behavioral), 설계 오버레이 4종 (Filter Chain/Error Response/Pagination/Coding Standard), ADR 형식 구조화 (맥락/결정/이유/결과/트레이드오프), 설계-요구사항 추적 매트릭스 신규 추가, Token Family 갱신 시퀀스(11.4) 추가 |
| v2.1 | 2026-04-17 | jypark | ADR-005(환경 분기), ADR-006(JWT Fallback), ADR-007(해싱 단일 책임), ADR-008(CORS 개발 도구) 신규 추가. Design Overlay §12.5 환경 분기 + §12.6 BaseController 세션 복원 흐름도 신규. 코딩 표준 오버레이 `ENVIRONMENT` 상수 규칙 추가. 2026-04-16 18:00 KST 이후 29건 커밋 반영. 3-Round IEEE Review PASS |
