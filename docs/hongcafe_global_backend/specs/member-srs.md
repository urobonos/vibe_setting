---
문서명: Member 모듈 소프트웨어 요구사항 명세서 (SRS)
문서ID: SRS-MEMBER-001
버전: v2.1
상태: 승인됨
적용 표준: IEEE 29148:2018 (Systems and software engineering — Life cycle processes — Requirements engineering)
생성일: 2026-04-15
최종수정일: 2026-04-17
작성자: jypark
검토자: —
승인자: —
대상 시스템: HongCafe Global Backend — Member Module
관련 문서:
  - member-sdd.md (SDD-MEMBER-001)
  - member-idd.md (IDD-MEMBER-001)
  - docs/api-specification.md
  - api-docs/member/member-api.md
  - api-docs/member/mypage-api.md
  - api-docs/member/profile-api.md
---

# Member 모듈 소프트웨어 요구사항 명세서 (SRS)
# Software Requirements Specification — Member Module

**문서 번호 (Document Number):** SRS-MEMBER-001  
**버전 (Version):** v2.1  
**적용 표준 (Applicable Standard):** IEEE 29148:2018  
**상태 (Status):** 승인됨 (Approved)  
**변경 로그 요약:** v2.1 — 비프로덕션 환경 분기(NFR-009), RBAC Layer 2 보강(NFR-007-1), 비밀번호 이중 해싱 버그 수정(FR-003-8), JWT fallback 세션 복원(FR-002-10), logout 인증 필터(FR-002-11) 반영. 3-Round Review PASS.

---

## 목차 (Table of Contents)

1. 목적 및 범위 (Purpose and Scope)
2. 참조 문서 (References)
3. 용어 및 약어 (Terms, Definitions, and Abbreviations)
4. 이해관계자 요구사항 (Stakeholder Requirements)
5. 시스템 맥락 (System Context)
6. 기능 요구사항 (Functional Requirements)
7. 비기능 요구사항 (Non-Functional Requirements)
8. 외부 인터페이스 요구사항 (External Interface Requirements)
9. 제약사항 (Constraints)
10. 유스케이스 (Use Cases)
11. 데이터 사전 (Data Dictionary)
12. 요구사항 검증 매트릭스 (Requirements Verification Matrix)
13. 타당성 검토 (Feasibility Review)
14. 변경 로그 (Change Log)

---

## 1. 목적 및 범위 (Purpose and Scope)

### 1.1 목적 (Purpose)

본 문서는 IEEE 29148:2018 표준에 따라 HongCafe Global Backend의 **Member 모듈**에 대한 소프트웨어 요구사항을 명세한다. 본 문서는 회원 생애주기(가입, 인증, 프로필 관리, 마이페이지 이력, SNS 연동, 탈퇴) 전 영역의 기능 요구사항(FR)과 비기능 요구사항(NFR)을 정의하며, 설계 및 구현의 기준 문서로 사용된다.

This document specifies software requirements for the Member module of HongCafe Global Backend per IEEE 29148:2018. It covers the full member lifecycle: registration, authentication, profile management, mypage history, SNS integration, and withdrawal.

### 1.2 범위 (Scope)

**시스템 이름 (System Name):** HongCafe Global Backend — Member Module  
**약어 (Abbreviation):** MBR  

| 항목 | 내용 |
|------|------|
| 모듈 경로 | `app/Modules/Member/` |
| API 그룹 | Member API (21 EP), Mypage API (20 EP), Profile API (8 EP) |
| 총 엔드포인트 | 49개 |
| 연관 테이블 | tb_account, tb_call_result, tb_coin, tb_order, tb_goods_order, tb_chat_rooms, tb_alarm, tb_sms_auth, tb_mail_cert, tb_interphone_auth, tb_coupon, tb_coupon_user, tb_account_history, tb_regist_phone, tb_sns_info |
| 의존 외부 서비스 | SMS Link API, Kakao AlimTalk, TemplateMail, AWS S3, SNS OAuth (Google/Kakao/Naver/Facebook/Apple/Line) |

**범위 제외 (Out of Scope):**
- 결제 게이트웨이(PG) 내부 처리 로직 (Commerce 모듈 담당)
- 상담사(Callee) 전용 기능 (Callee 모듈 담당)
- 관리자(Admin) 계정 관리 (Admin 모듈 담당)

### 1.3 개요 (Overview)

Member 모듈은 HongCafe 글로벌 서비스의 회원 기반 인프라를 담당한다. 49개 엔드포인트를 통해 회원 가입부터 탈퇴까지의 전체 생애주기를 관리하며, 6개 SNS 제공자(Google, Kakao, Naver, Facebook, Apple, Line)를 통한 OAuth 연동, JWT 기반 무상태(stateless) 인증, CSRF 이중 검증 보안을 제공한다.

---

## 2. 참조 문서 (References)

| ID | 문서명 | 버전 | 출처 |
|----|--------|------|------|
| REF-001 | IEEE 29148:2018 — Systems and software engineering — Life cycle processes — Requirements engineering | 2018 | IEEE |
| REF-002 | OWASP Top 10 2021 | 2021 | OWASP Foundation |
| REF-003 | OWASP Authentication Cheat Sheet | Current | OWASP Foundation |
| REF-004 | OWASP File Upload Cheat Sheet | Current | OWASP Foundation |
| REF-005 | CWE-204: Observable Response Discrepancy | Current | MITRE |
| REF-006 | RFC 6819 — OAuth 2.0 Threat Model and Security Considerations | 2013 | IETF |
| REF-007 | RFC 7231 — Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content | 2014 | IETF |
| REF-008 | RFC 3339 — Date and Time on the Internet: Timestamps | 2002 | IETF |
| REF-009 | PHP 8.4 password_hash() Documentation | Current | php.net |
| REF-010 | CodeIgniter 4.7 Documentation | 4.7+ | codeigniter.com |
| REF-011 | docs/api-specification.md | Current | 내부 |
| REF-012 | docs/infrastructure.md | Current | 내부 |

---

## 3. 용어 및 약어 (Terms, Definitions, and Abbreviations)

### 3.1 용어 정의 (Definitions)

| 용어 | 정의 (한국어) | Definition (English) |
|------|--------------|----------------------|
| Caller | 일반 사용자. `tb_account.ce_code` 없음. `UserRole::Caller` | Standard user without counselor code |
| Callee | 상담사. `tb_account.ce_code` 보유. `UserRole::Callee` | Counselor user possessing a counselor code |
| SMS 인증 | 휴대폰 번호로 6자리 OTP를 발송하고 검증하는 절차 | Process of sending and verifying a 6-digit OTP via SMS |
| 닉네임 쿨다운 | 닉네임 변경 후 7일(168시간)간 재변경이 금지되는 정책 | 7-day restriction on nickname changes after the last change |
| Token Family | Refresh Token 갱신 계보. 재사용 감지 시 계보 전체 무효화 | Lineage of Refresh Tokens; entire family revoked on reuse detection |
| SNS 연동 | Google, Kakao, Naver, Facebook, Apple, Line OAuth 2.0 계정 연결 | OAuth 2.0 account linkage with SNS providers |
| 회원 생애주기 | 가입 → 인증 → 활동 → 탈퇴의 전체 흐름 | Full member lifecycle from registration to withdrawal |
| 더미 연산 | CWE-204 방지를 위해 계정 미존재 시 실행하는 `password_hash()` 연산 | Dummy `password_hash()` call to prevent timing-based user enumeration |

### 3.2 약어 (Abbreviations)

| 약어 | 전체 표기 |
|------|----------|
| EP | 엔드포인트 (Endpoint) |
| FR | 기능 요구사항 (Functional Requirement) |
| NFR | 비기능 요구사항 (Non-Functional Requirement) |
| JWT | JSON Web Token |
| OTP | One-Time Password |
| CSRF | Cross-Site Request Forgery |
| RBAC | Role-Based Access Control |
| PG | Payment Gateway |
| BC | Bounded Context |
| SRS | Software Requirements Specification |
| SDD | Software Design Description |
| IDD | Interface Design Description |
| CWE | Common Weakness Enumeration |
| OWASP | Open Web Application Security Project |

---

## 4. 이해관계자 요구사항 (Stakeholder Requirements)

### 4.1 이해관계자 식별 (Stakeholder Identification)

| ID | 이해관계자 | 역할 | 주요 관심사 |
|----|-----------|------|------------|
| STK-001 | 서비스 사용자 (Caller) | 시스템 최종 사용자 | 간편한 가입/로그인, 마이페이지 이력 조회, 개인정보 보호 |
| STK-002 | 상담사 (Callee) | 시스템 최종 사용자 | 프로필 관리, SNS 연동 관리 |
| STK-003 | 운영팀 | 시스템 관리자 | 계정 상태 관리, 보안 감사, 탈퇴 처리 |
| STK-004 | 개발팀 | 시스템 개발자 | 모듈 아키텍처 일관성, 코드 품질, 테스트 가능성 |
| STK-005 | 보안팀 | 보안 검토자 | CWE/OWASP 준수, 개인정보 보호, 인증 보안 |

### 4.2 이해관계자 요구 (Stakeholder Needs)

| ID | 이해관계자 | 요구 내용 |
|----|-----------|----------|
| SN-001 | STK-001 | 이메일 또는 SNS 계정으로 간단하게 가입하고 로그인할 수 있어야 한다 |
| SN-002 | STK-001 | 내 통화 이력, 코인 이력, 주문 내역을 한 곳에서 조회할 수 있어야 한다 |
| SN-003 | STK-001 | 비밀번호를 분실했을 때 이메일로 재설정할 수 있어야 한다 |
| SN-004 | STK-001 | 내 개인정보(전화번호, 닉네임, 프로필 이미지)를 직접 변경할 수 있어야 한다 |
| SN-005 | STK-001 | 서비스를 탈퇴할 수 있어야 하며, 탈퇴 후 개인정보가 안전하게 처리되어야 한다 |
| SN-006 | STK-002 | 상담사 프로필을 관리하고 SNS 계정을 연동/해제할 수 있어야 한다 |
| SN-007 | STK-003 | 계정 상태(활성/정지/탈퇴)를 관리할 수 있어야 한다 |
| SN-008 | STK-005 | 로그인 실패 시 계정 존재 여부가 노출되지 않아야 한다 (CWE-204) |
| SN-009 | STK-005 | 비밀번호는 반드시 bcrypt 해시로 저장되어야 한다 |

---

## 5. 시스템 맥락 (System Context)

### 5.1 시스템 경계 (System Boundary)

```
┌─────────────────────────────────────────────────────────────┐
│                HongCafe Global Backend                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  Member Module                       │   │
│  │  ┌──────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│  │  │ MemberCtrl   │  │ MypageCtrl  │  │ProfileCtrl│  │   │
│  │  └──────┬───────┘  └──────┬──────┘  └─────┬─────┘  │   │
│  │         │                 │                │        │   │
│  │  ┌──────▼───────┐  ┌──────▼──────┐        │        │   │
│  │  │Registration  │  │Profile      │        │        │   │
│  │  │Service       │  │Service      │        │        │   │
│  │  └──────┬───────┘  └──────┬──────┘        │        │   │
│  │         │                 │                │        │   │
│  │  ┌──────▼──────────────────▼──────────────┘        │   │
│  │  │   MemberRepo / MypageRepo / SnsRepo              │   │
│  │  └──────────────────────────────────────────────────┘   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│              Aurora MySQL (RDS Proxy)                       │
└──────────────────────────────────────────────────────────── ┘
         │                │              │              │
    SMS Link API    Kakao AlimTalk  TemplateMail    AWS S3
```

### 5.2 외부 행위자 (External Actors)

| 행위자 | 유형 | 상호작용 |
|--------|------|---------|
| 서비스 사용자 (Caller) | Human Actor | 49개 API EP를 통해 회원 기능 사용 |
| 상담사 (Callee) | Human Actor | 프로필 관리, SNS 연동 관리 |
| Next.js 프론트엔드 | External System | HTTP/HTTPS REST API 호출 |
| SMS Link API | External Service | OTP 문자 발송 |
| Kakao AlimTalk | External Service | 카카오 알림톡 발송 |
| TemplateMail | External Service | 이메일 발송 |
| AWS S3 | External Service | 프로필 이미지 저장 |
| SNS OAuth Providers | External Service | Google/Kakao/Naver/Facebook/Apple/Line 인증 |

---

## 6. 기능 요구사항 (Functional Requirements)

> **표기 규칙:** 각 FR은 `FR-{그룹번호}-{세부번호}` 형식으로 식별된다. 검증 방법(Verification Method)은 4가지 유형을 사용한다: **T** = Test (단위/통합 테스트), **A** = Analysis (코드 분석), **I** = Inspection (코드 검사), **D** = Demonstration (시연).

---

### FR-001 회원가입 (Member Registration)

**요약:** 신규 사용자가 이메일 + 비밀번호 또는 SNS OAuth로 회원 계정을 생성한다.  
**우선순위 (Priority):** Critical  
**관련 EP:** `POST /api/members/join`, `GET /api/members/check-id`, `GET /api/members/check-nickname`, `POST /api/members/send-join-cert-mail`, `POST /api/members/verify-join-cert-mail`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-001-1 | 이메일 + 비밀번호 가입: 이메일 형식(RFC 5321) 검증 후 중복 확인, 통과 시 계정 생성 | T | 완료 |
| FR-001-2 | 이메일 인증: 가입 완료 전 인증 메일 발송 및 링크 클릭 확인 (`tb_mail_cert` 토큰 저장, TTL 1시간) | T | 완료 |
| FR-001-3 | 비밀번호는 bcrypt (cost ≥ 12) 해시 저장. 평문 저장 절대 금지 (`password_hash()`, `PASSWORD_BCRYPT`) | I | 완료 |
| FR-001-4 | 닉네임은 필수 입력. 중복 확인 API 제공 (`check-nickname`). 2~20자, 특수문자 금지(언더스코어 허용) | T | 완료 |
| FR-001-5 | 아이디(이메일) 중복 확인 API 제공 (`check-id`). 중복 시 HTTP 409 + `EMAIL_ALREADY_EXISTS` | T | 완료 |
| FR-001-6 | 가입 완료 시 JWT Access Token + Refresh Token + CSRF 쿠키 3종 발급 | T | 완료 |
| FR-001-7 | SNS 가입 시 OAuth Provider 인가 코드 수신 → 사용자 정보 조회 → 계정 생성 또는 기존 계정 연동 | T | 완료 |
| FR-001-8 | 새 비밀번호는 최소 8자 이상, 영문 + 숫자 + 특수문자 조합 필수 | T | 완료 |

---

### FR-002 로그인 (Authentication)

**요약:** 이메일/비밀번호 또는 SNS OAuth로 인증하고 JWT 토큰을 발급한다.  
**우선순위 (Priority):** Critical  
**관련 EP:** `POST /api/members/login`, `POST /api/members/sns-login`, `POST /api/members/logout`, `POST /api/auth/refresh`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-002-1 | 이메일 + 비밀번호 로그인: `password_verify()` 사용. 실패 시 HTTP 401 반환 | T | 완료 |
| FR-002-2 | 로그인 성공 시 `hc_access` (15분, HttpOnly) + `hc_refresh` (7일, HttpOnly) 쿠키 발급 | T | 완료 |
| FR-002-3 | 로그인 성공 시 `hc_csrf` CSRF 토큰 쿠키 발급 (HttpOnly=false, TTL=7200초) | T | 완료 |
| FR-002-4 | CWE-204 방지: 이메일 미존재와 비밀번호 불일치 시 동일 에러 메시지 `INVALID_CREDENTIALS` 반환 | A | 완료 |
| FR-002-5 | CWE-204 방지: 계정 미존재 시에도 `password_hash()` 더미 연산 수행으로 응답 시간 균일화 | I | 완료 |
| FR-002-6 | SNS 로그인: 6개 Provider별 OAuth 처리 후 기존 계정 조회 또는 신규 생성 | T | 완료 |
| FR-002-7 | 자동 로그인(로그인 상태 유지) 옵션 지원 | D | 완료 |
| FR-002-8 | 로그아웃 시 `hc_access`, `hc_refresh`, `hc_csrf` 쿠키 모두 만료 처리 | T | 완료 |
| FR-002-9 | Token Refresh: `hc_refresh` 쿠키 기반. 동일 `family` + 새 `jti` 발급. 사용 완료된 `jti` 재제출 시 family 전체 무효화 | T | 완료 |
| FR-002-10 | BaseController는 `hdata` 쿠키가 없거나 복호화 실패 시 JWT AuthFilter가 주입한 `$_SERVER['AUTH_USER']['ac_id']`를 fallback으로 사용하여 `$this->member` 세션을 복원한다 | I + T | 완료 |
| FR-002-11 | logout 라우트는 `auth` 필터를 통과한 인증된 세션에서만 호출 가능하다 (미인증 접근 시 401 UNAUTHORIZED) | I | 완료 |
| FR-002-12 | BaseController는 API 요청(URI가 `/api/`로 시작) 인증 실패 시 `redirect()` / `exit` 호출을 금지한다. `$this->member = null` 및 쿠키 만료만 수행 후 initController 진행. 인증 필요 EP는 컨트롤러에서 `checkNeedLogin(true)`로 401 응답을 생성한다 | I | 완료 |
| FR-002-13 | BaseController는 `hdata` 복호화 결과가 배열이 아니거나 `ac_id` 키가 없을 때 쿠키를 즉시 만료시키고 세션을 파기한다 (`custom_decrypt` null 방어) | I | 완료 |

---

### FR-003 비밀번호 관리 (Password Management)

**요약:** 비밀번호 변경, 분실 시 재설정, 현재 비밀번호 확인 기능을 제공한다.  
**우선순위 (Priority):** High  
**관련 EP:** `POST /api/members/change-password`, `POST /api/members/find-password`, `POST /api/members/reset-password`, `POST /api/members/find-id`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-003-1 | 비밀번호 변경: 현재 비밀번호 확인 후 새 비밀번호 bcrypt 해시 저장 | T | 완료 |
| FR-003-2 | 비밀번호 분실: 이메일로 재설정 링크 발송 (`tb_mail_cert` 토큰 저장, TTL 1시간) | T | 완료 |
| FR-003-3 | 비밀번호 재설정 링크 클릭 시 토큰 유효성 검증 후 새 비밀번호 저장 | T | 완료 |
| FR-003-4 | 비밀번호 변경/재설정 완료 시 해당 계정의 모든 Refresh Token Family 즉시 무효화 | T | 완료 |
| FR-003-5 | 간편결제 비밀번호(4자리 PIN): 별도 컬럼 저장. 변경/확인 API 제공 | T | 완료 |
| FR-003-6 | 비밀번호 재해시: `password_needs_rehash()` 결과 true 시 로그인 시점 자동 재해시 | I | 완료 |
| FR-003-7 | 아이디 찾기: 전화번호 또는 이메일 인증을 통해 마스킹된 이메일 반환 | T | 완료 |
| FR-003-8 | 비밀번호 해싱은 Service/Repository 중 **한 곳에서만** 수행한다. 이중 해싱(`password_hash(password_hash(...))`)은 절대 금지. 변경/재설정 플로우의 Service 계층이 해싱을 전담하며, Repository는 전달받은 해시를 평문 상태 변경 없이 저장한다 | I + T | 완료 |

---

### FR-004 닉네임 변경 (Nickname Change)

**요약:** 회원이 닉네임을 변경하되, 변경 후 7일간 재변경을 금지한다.  
**우선순위 (Priority):** Medium  
**관련 EP:** `PUT /api/mypage/change-nickname`, `GET /api/members/check-nickname`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-004-1 | 닉네임 변경 요청 시 마지막 닉네임 변경 후 7일(168시간, UTC 기준) 이내인지 확인 | T | 완료 |
| FR-004-2 | 7일 이내 변경 이력 존재 시 HTTP 409 + `NICKNAME_CHANGE_COOLDOWN` + `availableAt` 반환 | T | 완료 |
| FR-004-3 | 닉네임 중복 확인 후 변경 허용. 중복 시 HTTP 409 + `NICKNAME_ALREADY_EXISTS` | T | 완료 |
| FR-004-4 | 닉네임 변경 이력을 `tb_account_history`에 변경 전/후 값으로 기록 | I | 완료 |
| FR-004-5 | 닉네임은 2~20자, 특수문자 금지(언더스코어 허용), 비속어 필터링 적용 | T | 완료 |
| FR-004-6 | 닉네임 변경 요청 필드는 `ac_nick` (요청/응답 camelCase: `acNick`, `newNick`)으로 단일화한다. 과거 `new_nick` 혼용은 금지 | I | 완료 |

---

### FR-005 전화번호 변경 (Phone Number Change)

**요약:** SMS OTP 인증을 통해 등록된 휴대폰 번호를 변경한다.  
**우선순위 (Priority):** Medium  
**관련 EP:** `POST /api/mypage/send-sms`, `POST /api/mypage/verify-sms`, `PUT /api/mypage/change-phone`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-005-1 | 새 전화번호로 SMS OTP 발송 (`SmsVerificationService` 경유, SMS Link API 호출) | T | 완료 |
| FR-005-2 | OTP 발송은 동일 번호 기준 10회/일 제한 (`tb_sms_auth` 일별 카운트) | T | 완료 |
| FR-005-3 | OTP는 `random_int(100000, 999999)` 6자리 숫자. TTL 5분 (300초) | I | 완료 |
| FR-005-4 | OTP 검증 성공 시 `tb_account.ac_phone` 업데이트 | T | 완료 |
| FR-005-5 | 이미 가입된 전화번호로 변경 시 HTTP 409 + `PHONE_ALREADY_EXISTS` 반환 | T | 완료 |
| FR-005-6 | SMS 재발송 최소 대기: 동일 번호 재발송 60초 간격 | T | 완료 |
| FR-005-7 | 인터폰 인증 (`tb_interphone_auth`): 별도 인증 흐름 지원 | T | 완료 |
| FR-005-8 | 비프로덕션(`ENVIRONMENT !== 'production'`) 환경에서 전화번호 변경(`verify-phone`) 및 아이디 찾기(`find-id`) SMS/AlimTalk 발송은 스킵하고 인증번호를 **`222222`로 고정** 처리한다. 운영 환경은 정상 SMS 발송 플로우 유지 | I + T | 완료 |
| FR-005-9 | 회원가입(`join-user`) 플로우에서 Hermes DB 참조는 비프로덕션 환경에서 스킵한다 (외부 시스템 의존성 격리) | I | 완료 |

---

### FR-006 SNS 연동 (SNS Integration)

**요약:** 기존 계정에 SNS OAuth Provider를 추가 연결하거나 해제한다.  
**우선순위 (Priority):** High  
**관련 EP:** `POST /api/members/sns-connect`, `DELETE /api/members/sns-disconnect`, `GET /api/mypage/sns-list`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-006-1 | 지원 Provider: Google, Kakao, Naver, Facebook, Apple, Line (총 6종) | I | 완료 |
| FR-006-2 | Provider별 OAuth 인가 코드 수신 후 사용자 고유 ID 조회 → `tb_account`에 Provider ID 저장 | T | 완료 |
| FR-006-3 | 이미 다른 계정에 연결된 SNS ID는 연동 불가. HTTP 409 + `SNS_ALREADY_LINKED` | T | 완료 |
| FR-006-4 | SNS 연동 해제: 비밀번호 없는 계정에서 마지막 Provider 해제 시도 시 비밀번호 설정 요구 | T | 완료 |
| FR-006-5 | 연동된 Provider 목록 조회 API 제공 (`GET /api/mypage/sns-list`) | T | 완료 |
| FR-006-6 | Apple 로그인: `identity_token` JWT 검증 (Apple Public Key JWKS 기반) | T | 완료 |

---

### FR-007 회원 탈퇴 (Member Withdrawal)

**요약:** 회원이 계정을 탈퇴하면 개인정보를 마스킹하고 일정 기간 보관 후 영구 삭제한다.  
**우선순위 (Priority):** High  
**관련 EP:** `DELETE /api/members/withdraw`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-007-1 | 탈퇴 요청 시 현재 비밀번호 확인 (SNS 전용 계정은 생략 가능) | T | 완료 |
| FR-007-2 | 탈퇴 처리: `tb_account.ac_status = 'D'` (Deleted), 탈퇴 일시 기록 (`deleted_at`) | T | 완료 |
| FR-007-3 | 탈퇴 완료 시 모든 JWT Refresh Token Family 즉시 무효화 | T | 완료 |
| FR-007-4 | 탈퇴 완료 시 `hc_access`, `hc_refresh`, `hc_csrf` 쿠키 만료 처리 | T | 완료 |
| FR-007-5 | 개인정보 마스킹: 이메일, 전화번호, 이름은 탈퇴 30일 후 익명화 처리 (별도 배치 Job) | I | 완료 |
| FR-007-6 | 진행 중인 결제/예약 건 존재 시 탈퇴 불가. HTTP 409 + `PENDING_TRANSACTION_EXISTS` | T | 완료 |
| FR-007-7 | 탈퇴 후 동일 이메일 재가입은 탈퇴 30일 이후 허용 | T | 완료 |
| FR-007-8 | 탈퇴·삭제 계정의 `hdata` 쿠키가 클라이언트에 잔존한 상태로 재접근 시, BaseController는 `$this->member` null 방어 후 쿠키를 즉시 만료시킨다. null 멤버로 인한 후속 `['ac_status']` 접근 TypeError를 차단 | I | 완료 |

---

### FR-008 마이페이지 이력 (Mypage History)

**요약:** 회원의 거래 이력, 코인 이력, 쿠폰, 알림 등 마이페이지 데이터를 조회한다.  
**우선순위 (Priority):** High  
**관련 EP:** `GET /api/mypage/call-history`, `GET /api/mypage/coin-history`, `GET /api/mypage/order-list`, `GET /api/mypage/coupon-list`, `GET /api/mypage/alarm-list`, `GET /api/mypage/chat-list`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-008-1 | 통화/상담 이력 조회: `tb_call_result` 페이지네이션 (CI4 빌트인 Pager) | T | 완료 |
| FR-008-2 | 코인 충전/사용 이력 조회: `tb_coin` 페이지네이션 | T | 완료 |
| FR-008-3 | 주문 이력 조회: `tb_order`, `tb_goods_order` 조인 쿼리, 페이지네이션 | T | 완료 |
| FR-008-4 | 쿠폰 목록 조회: `tb_coupon`, `tb_coupon_user` 유효기간 필터링 (유효/만료/사용 구분) | T | 완료 |
| FR-008-5 | 알림 목록 조회: `tb_alarm` 미읽음/전체 구분, 페이지네이션 | T | 완료 |
| FR-008-6 | 채팅방 이력 조회: `tb_chat_rooms` 페이지네이션 | T | 완료 |
| FR-008-7 | 페이지네이션 응답: `{ "data": [], "meta": { "currentPage", "perPage", "total", "lastPage" } }` camelCase 통일 | I | 완료 |
| FR-008-8 | 모든 이력 조회는 소유권 조건 필수: Repository 쿼리에 `ac_id` WHERE 절 내장 (OWASP API5:2023) | A | 완료 |

---

### FR-009 자동결제 (Automatic Payment)

**요약:** 등록된 결제 수단으로 자동 결제를 처리하고 결제 비밀번호로 보호한다.  
**우선순위 (Priority):** Medium  
**관련 EP:** `POST /api/mypage/register-payment`, `DELETE /api/mypage/cancel-payment`, `GET /api/mypage/payment-info`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-009-1 | 간편결제 비밀번호(4자리 PIN) 설정/변경/확인 | T | 완료 |
| FR-009-2 | 결제 수단 등록: 카드 정보를 PG사 토큰으로만 저장. 카드 원본 정보 서버 미보관 | I | 완료 |
| FR-009-3 | 자동결제 실행 전 멱등키 확인 (`tb_order.idempotency_key` UNIQUE 제약) | A | 완료 |
| FR-009-4 | 결제 실패 시 재시도 정책: 최대 3회, 지수 백오프 적용 | T | 완료 |
| FR-009-5 | 결제 성공/실패 이력 `tb_order` 저장 | T | 완료 |
| FR-009-6 | 자동결제 해지 API 제공 (`DELETE /api/mypage/cancel-payment`) | T | 완료 |

---

### FR-010 리뷰 (Review)

**요약:** 상담 완료 후 회원이 상담사에 대한 리뷰를 작성하거나 수정/삭제한다.  
**우선순위 (Priority):** Medium  
**관련 EP:** `POST /api/mypage/write-review`, `PUT /api/mypage/modify-review`, `DELETE /api/mypage/delete-review`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-010-1 | 리뷰 작성: 상담 완료(`tb_call_result.status = 'done'`) 건에 한해 작성 가능 | T | 완료 |
| FR-010-2 | 리뷰 작성 권한: 해당 통화의 Caller만 가능 (소유권 검증 필수) | T | 완료 |
| FR-010-3 | 리뷰는 1건당 1개만 허용. 중복 작성 시 HTTP 409 + `REVIEW_ALREADY_EXISTS` | T | 완료 |
| FR-010-4 | 리뷰 수정/삭제: 작성자 본인만 가능 (Repository 소유권 조건 내장) | T | 완료 |
| FR-010-5 | 리뷰 평점: 1~5점 정수. 소수점 허용 안 함 | T | 완료 |
| FR-010-6 | 리뷰 내용: 최소 10자, 최대 500자 | T | 완료 |

---

### FR-011 프로필 관리 (Profile Management)

**요약:** 회원의 공개 프로필을 조회하거나, 인증된 회원이 본인 프로필을 수정한다.  
**우선순위 (Priority):** Medium  
**관련 EP:** `GET /api/profile/{ac_id}`, `GET /api/profile/me`, `PUT /api/profile/me`, `GET /api/profile/interests`, `PUT /api/profile/interests`, `GET /api/profile/languages`, `PUT /api/profile/languages`, `GET /api/profile/{ac_id}/stats`

| ID | 요구사항 내용 | 검증 방법 | 상태 |
|----|--------------|-----------|------|
| FR-011-1 | 공개 프로필 조회: `ac_id`로 타 회원 프로필 조회 (비인증 허용, 민감정보 제외) | T | 완료 |
| FR-011-2 | 내 프로필 조회: JWT 인증 필요. 민감 정보 포함 반환 | T | 완료 |
| FR-011-3 | 프로필 수정: 닉네임, 소개글 등 수정 가능. 닉네임은 FR-004 쿨다운 정책 적용 | T | 완료 |
| FR-011-4 | 관심사(Interests) 조회/수정 API 제공 | T | 완료 |
| FR-011-5 | 언어(Languages) 조회/수정 API 제공 | T | 완료 |
| FR-011-6 | 프로필 이미지: Pre-signed URL 방식 업로드. MIME 이중 검증 필수. 최대 5MB | T | 완료 |
| FR-011-7 | 프로필 통계(`stats`): 총 통화 수, 평균 평점 등 집계 데이터 조회 | T | 완료 |

---

## 7. 비기능 요구사항 (Non-Functional Requirements)

### NFR-001 보안 — CWE-204 타이밍 공격 방지

**분류:** Security  
**우선순위:** Critical  
**참조:** CWE-204, OWASP Authentication Cheat Sheet (REF-003)

| 항목 | 명세 |
|------|------|
| 위협 | CWE-204: Observable Response Discrepancy — 응답 시간 차이로 계정 존재 여부 열거 가능 |
| 대응 | 계정 미존재 시 더미 `password_hash()` 연산으로 응답 시간 균일화 |
| 에러 메시지 | 이메일 미존재/비밀번호 불일치 모두 `INVALID_CREDENTIALS` 단일 메시지 (HTTP 401) |
| 적용 범위 | `POST /api/members/login`, `POST /api/members/find-password` |
| 검증 방법 | A (코드 분석) + T (응답 시간 측정 테스트) |

### NFR-002 보안 — 비밀번호 해시

**분류:** Security  
**우선순위:** Critical  
**참조:** OWASP Password Storage Cheat Sheet, PHP password_hash() (REF-009)

| 항목 | 명세 |
|------|------|
| 알고리즘 | bcrypt (PHP `PASSWORD_BCRYPT`) |
| Cost Factor | 최소 12 이상 |
| 저장 위치 | `tb_account.ac_password` |
| 검증 | `password_verify()` 사용. 직접 해시 비교 금지 |
| 재해시 | `password_needs_rehash()` true 시 로그인 시점 자동 재해시 |
| 검증 방법 | I (코드 검사) |

### NFR-003 SMS 발송 제한 (Rate Limit)

**분류:** Reliability / Security  
**우선순위:** High

| 항목 | 명세 |
|------|------|
| 제한 | 동일 전화번호 기준 10회/일 (UTC 자정 초기화) |
| 저장 | `tb_sms_auth` 발송 로그 + 일별 카운트 |
| 초과 시 | HTTP 429 + `SMS_LIMIT_EXCEEDED` + `{ "resetAt": "YYYY-MM-DDT00:00:00Z" }` |
| OTP TTL | 5분 (300초) |
| 재발송 대기 | 동일 번호 재발송 최소 60초 간격 |
| 검증 방법 | T |

### NFR-004 닉네임 변경 쿨다운

**분류:** Business Rule  
**우선순위:** Medium

| 항목 | 명세 |
|------|------|
| 쿨다운 기간 | 7일 (168시간) |
| 기준 시각 | UTC 기준 마지막 닉네임 변경 일시 (`tb_account_history`) |
| 초과 시 | HTTP 409 + `NICKNAME_CHANGE_COOLDOWN` + `{ "availableAt": "ISO8601" }` |
| 이력 저장 | `tb_account_history` 변경 전/후 닉네임 기록 |
| 검증 방법 | T |

### NFR-005 성능 (Performance)

**분류:** Performance  
**우선순위:** High

| 항목 | 목표 | 측정 조건 |
|------|------|----------|
| 로그인 응답 시간 | p95 < 300ms | bcrypt 포함, DB 조회 포함 |
| 마이페이지 조회 | p95 < 200ms | 페이지네이션 10건 기준 |
| SMS 발송 API | API 응답 < 100ms | 비동기 큐 처리 기준 |
| 이미지 업로드 | Pre-signed URL 발급 < 200ms | S3 직접 업로드, 서버 스트리밍 금지 |
| 검증 방법 | T (부하 테스트) |  |

### NFR-006 가용성 및 멱등성 (Availability & Idempotency)

**분류:** Reliability  
**우선순위:** Critical

| 항목 | 명세 |
|------|------|
| 결제 멱등성 | `tb_order.idempotency_key` UNIQUE 제약으로 중복 결제 방지 |
| Token 갱신 멱등성 | Refresh Token `jti` UNIQUE. 재사용 시 Token Family 전체 무효화 |
| DB 고가용성 | Aurora MySQL Multi-AZ. 읽기 전용 쿼리는 Read Replica 분리 |
| 검증 방법 | A (DB 스키마 분석) |

### NFR-007 인가 (Authorization)

**분류:** Security  
**우선순위:** Critical  
**참조:** OWASP API5:2023 Broken Object Level Authorization

| 계층 | 구현 | 적용 대상 |
|------|------|----------|
| Layer 1 | `RoleFilter:callee` — 라우트 필터 레벨 역할 차단 | 상담사 전용 EP |
| Layer 2 | `checkNeedLogin(true)` — 컨트롤러 레벨 `ce_code` 이중 검증 | 인증 필요 EP |
| Layer 3 | Repository 쿼리에 `ac_id` 소유권 조건 내장 | 모든 마이페이지 EP |
| 검증 방법 | A + T | — |

**NFR-007-1 Layer 2 일괄 보강 (2026-04-17):**

인증이 필요한 Member API 메서드 전수(9개: `settingAlarm`, `updateHomeSet`, `changeNick`, `changePasswd`, `resetPassword`, `verifyPhone`, `updatePhone`, `deleteUser`, `logout`)에 `checkNeedLogin(true)` 방어를 일괄 적용한다. AuthFilter가 통과시켰더라도 컨트롤러 진입 직후 `$this->is_login`을 재확인하여 필터 설정 오류 또는 레이스 컨디션 상황에서도 미인증 요청이 비즈니스 로직에 도달하지 못하도록 보장한다.

### NFR-009 환경 분기 (Environment-Aware Behavior)

**분류:** Operational / Test Friendliness  
**우선순위:** High

| 항목 | 프로덕션 (`ENVIRONMENT='production'`) | 비프로덕션 (dev/staging/test) |
|------|------------------------------------|-----------------------------|
| `Sms::sendCertSms()` SMSLINK cURL | 실제 호출 | **스킵** — 고정값 `111111` 반환, `saveSmsLog()` 미호출 |
| `verify-phone` AlimTalk (Kakao) | Kakao API 실제 호출 | **스킵** (인증번호 `222222` 고정) |
| `find-id` SMS/AlimTalk | 실제 발송 | **스킵** (인증번호 `222222` 고정) |
| `send-mail-cert` TemplateMail | 실제 발송 | **스킵** |
| `findPasswordCert` 임시 비밀번호 메일 | 실제 발송 | **스킵** |
| SMS OTP 검증 | SMSLINK verify API 호출 | **전 환경 DB 직접 매칭**으로 전환 (`tb_interphone_auth`, TTL 5분) |
| Hermes DB 참조 (join-user) | 정상 참조 | **스킵** (join 모드) |
| CORS Origin | `prd.gl.hongcafe.com` 계열 | `localhost:5500`, `127.0.0.1:5500` 추가 허용 (개발 도구 호환) |

**Why:** 개발/테스트 환경에서 외부 서비스 의존성 제거 → 계약 테스트(MemberApiFeatureTest 등)의 결정성 확보, 외부 API 과금 방지, 개발자 환경 진입 장벽 완화. SMSLINK verify API 전 환경 제거는 외부 장애·응답 지연이 로그인/회원가입 플로우를 중단시키는 리스크를 원천 차단하고 DB 단일 소스로 OTP 검증을 일원화한다.

**How to apply:** `ENVIRONMENT` 상수(CI4 표준) 기준으로 Service 레이어에서 분기. `getenv('CI_ENVIRONMENT')` 혼용 금지 (커밋 `b4845e4`로 Sms 라이브러리 일괄 전환).

**검증 방법:** I (소스 코드 분기 확인) + T (MemberApiFeatureTest 19 EP 전체 플로우 통과)

### NFR-008 데이터 형식 (Data Format)

**분류:** Interoperability  
**우선순위:** High

| 항목 | 명세 |
|------|------|
| API 응답 키 | DB `snake_case` → API `camelCase` 변환 필수 (`created_at` → `createdAt`) |
| 날짜/시간 | ISO 8601 UTC (`"2026-04-15T09:00:00Z"`). `date()`, `time()` 사용 금지 |
| PHP 시간 | `DateTimeImmutable` + `DateTimeZone('UTC')` 강제 |
| 검증 방법 | I |

---

## 8. 외부 인터페이스 요구사항 (External Interface Requirements)

### EIF-001 SMS Link API

| 항목 | 명세 |
|------|------|
| 목적 | SMS OTP 발송 |
| 방향 | `SmsVerificationService` → SMS Link API |
| 프로토콜 | HTTPS REST |
| 인증 | `X-Api-Key` 헤더 (`.env SMS_LINK_API_KEY`) |
| 에러 처리 | resultCode 99 시 1회 재시도 후 `SMS_SEND_FAILED` |

### EIF-002 Kakao AlimTalk

| 항목 | 명세 |
|------|------|
| 목적 | 가입 완료/비밀번호 재설정/탈퇴 완료 알림톡 발송 |
| 방향 | `MemberRegistrationService` → Kakao API |
| 프로토콜 | HTTPS REST |
| 폴백 | AlimTalk 실패 시 TemplateMail 자동 폴백 |

### EIF-003 TemplateMail

| 항목 | 명세 |
|------|------|
| 목적 | 이메일 인증/비밀번호 재설정/아이디 찾기 메일 발송 |
| 방향 | `MemberRegistrationService` → TemplateMail |
| 인증 링크 | `bin2hex(random_bytes(32))` → 64자 hex 토큰, TTL 1시간 |

### EIF-004 AWS S3

| 항목 | 명세 |
|------|------|
| 목적 | 회원 프로필 이미지 저장 |
| 방향 | `MemberProfileService` → AWS S3 |
| 인증 | IAM Role (EC2 Instance Profile, 키 하드코딩 금지) |
| 업로드 방식 | Pre-signed URL. 서버 직접 스트리밍 금지 |
| 경로 규칙 | `profiles/{ac_id}/{uuid}.{ext}` |

### EIF-005 SNS OAuth Providers

| Provider | 고유 ID 필드 | 이메일 필드 | API 엔드포인트 |
|---------|------------|------------|--------------|
| Google | `sub` | `email` | `https://www.googleapis.com/oauth2/v3/userinfo` |
| Kakao | `id` | `kakao_account.email` | `https://kapi.kakao.com/v2/user/me` |
| Naver | `response.id` | `response.email` | `https://openapi.naver.com/v1/nid/me` |
| Facebook | `id` | `email` | `https://graph.facebook.com/me?fields=id,email,name` |
| Apple | JWT `sub` | JWT `email` | Apple Public Key JWKS 검증 |
| Line | `userId` | `email` | `https://api.line.me/v2/profile` |

---

## 9. 제약사항 (Constraints)

### 9.1 기술 제약 (Technical Constraints)

| ID | 제약 내용 |
|----|----------|
| CON-001 | PHP 8.4+ `declare(strict_types=1)` 모든 파일 필수 |
| CON-002 | CodeIgniter 4.7+ 프레임워크. Auto Routing 비활성화 (`setAutoRoute(false)`). 모든 EP 명시적 Routes.php 등록 |
| CON-003 | JWT는 `hc_access` HttpOnly 쿠키 전용. localStorage 저장 금지. Bearer 폴백 없음 |
| CON-004 | CSRF: Signed Double Submit Cookie (HMAC-SHA256). CI4 내장 CSRF 필터 미사용 |
| CON-005 | DB charset: `utf8mb4` 전 레벨 통일 |
| CON-006 | `DateTimeImmutable` 강제. `date()`, `time()` 함수 사용 금지 |
| CON-007 | API 응답: DB `snake_case` → `camelCase` 변환 필수 |

### 9.2 운영 제약 (Operational Constraints)

| ID | 제약 내용 |
|----|----------|
| CON-008 | 모든 외부 API 키는 `.env` 파일 참조. 소스코드 하드코딩 금지 |
| CON-009 | AWS S3 인증은 IAM Role 기반. Access Key 하드코딩 금지 |
| CON-010 | DB 타임존: UTC 전용. 사용자 표시는 프론트엔드에서 로컬 변환 |

---

## 10. 유스케이스 (Use Cases)

### UC-001 이메일 회원가입

```
유스케이스 ID: UC-001
행위자: 비로그인 사용자
사전 조건: 해당 이메일이 시스템에 미등록 상태
관련 FR: FR-001

주 흐름 (Main Flow):
  1. 사용자가 이메일/비밀번호/닉네임 입력 제출
  2. 시스템이 이메일 중복 확인 (check-id API) — 통과
  3. 시스템이 닉네임 중복 확인 (check-nickname API) — 통과
  4. 시스템이 bcrypt(cost=12)로 비밀번호 해시 생성
  5. 시스템이 tb_account 레코드 생성 (ac_status='A')
  6. 시스템이 tb_mail_cert에 인증 토큰 저장 후 인증 메일 발송
  7. 사용자가 메일 링크 클릭 → 이메일 인증 완료
  8. 시스템이 JWT 3쿠키 발급 (hc_access, hc_refresh, hc_csrf)

사후 조건: 신규 회원 계정 생성, 로그인 상태

예외 흐름 (Exception Flows):
  2a. 이메일 중복 → HTTP 409 EMAIL_ALREADY_EXISTS
  3a. 닉네임 중복 → HTTP 409 NICKNAME_ALREADY_EXISTS
  4a. 비밀번호 복잡도 미충족 → HTTP 400 WEAK_PASSWORD
  6a. 메일 링크 만료(1시간) → HTTP 400 EXPIRED_CERT
```

### UC-002 로그인 (CWE-204 보호 포함)

```
유스케이스 ID: UC-002
행위자: 미인증 사용자
사전 조건: 가입 완료 계정 보유
관련 FR: FR-002, NFR-001

주 흐름 (Main Flow):
  1. 사용자가 이메일/비밀번호 입력
  2. 시스템이 tb_account에서 이메일로 레코드 조회
  3. 시스템이 password_verify()로 비밀번호 검증
  4. 시스템이 hc_access + hc_refresh + hc_csrf 쿠키 발급
  5. HTTP 200 OK + 빈 data 반환 (토큰은 쿠키로만 전달)

사후 조건: 로그인 상태, 3개 쿠키 발급

예외 흐름 (Exception Flows):
  2a. 이메일 미존재 → [CWE-204] 더미 password_hash() 실행 → HTTP 401 INVALID_CREDENTIALS
  3a. 비밀번호 불일치 → HTTP 401 INVALID_CREDENTIALS
  [보안] 2a/3a 모두 동일 응답 시간 + 동일 메시지 보장 (타이밍 공격 방지)
```

### UC-003 SMS OTP 전화번호 변경

```
유스케이스 ID: UC-003
행위자: 로그인한 사용자
사전 조건: 유효한 JWT 토큰 보유 (hc_access 쿠키)
관련 FR: FR-005, NFR-003

주 흐름 (Main Flow):
  1. 사용자가 새 전화번호 입력 후 OTP 발송 요청
  2. 시스템이 tb_sms_auth 일별 카운트 확인 (≤ 10)
  3. 시스템이 60초 재발송 대기 확인
  4. 시스템이 random_int(100000,999999) OTP 생성
  5. 시스템이 SMS Link API로 OTP 발송
  6. 시스템이 tb_sms_auth에 OTP + 만료시각(now+5분) 저장
  7. 사용자가 수신된 OTP 입력
  8. 시스템이 OTP 유효성 검증 (TTL 5분, 번호 일치)
  9. 시스템이 tb_account.ac_phone 업데이트

사후 조건: 전화번호 변경 완료

예외 흐름 (Exception Flows):
  2a. 10회 초과 → HTTP 429 SMS_LIMIT_EXCEEDED + resetAt
  3a. 60초 미충족 → HTTP 429 SMS_RESEND_TOO_FAST + retryAfter
  8a. OTP 만료 → HTTP 400 OTP_EXPIRED
  8b. OTP 불일치 → HTTP 400 OTP_MISMATCH
  9a. 이미 등록된 번호 → HTTP 409 PHONE_ALREADY_EXISTS
```

### UC-004 SNS 계정 연동

```
유스케이스 ID: UC-004
행위자: 로그인한 사용자
사전 조건: 유효한 JWT 토큰, 연동할 SNS 계정 보유
관련 FR: FR-006

주 흐름 (Main Flow):
  1. 사용자가 SNS Provider 선택 (google/kakao/naver/facebook/apple/line)
  2. 프론트엔드가 Provider 인가 페이지로 리다이렉트
  3. Provider가 인가 코드 반환
  4. 시스템이 인가 코드로 Provider API 호출 → 사용자 고유 ID 획득
  5. 시스템이 기존 연동 여부 확인 (다른 계정에 동일 SNS ID 없음 확인)
  6. 시스템이 tb_account에 Provider ID 컬럼 업데이트

사후 조건: SNS 연동 완료

예외 흐름 (Exception Flows):
  5a. 다른 계정에 이미 연동된 SNS ID → HTTP 409 SNS_ALREADY_LINKED
```

### UC-005 비밀번호 재설정 (Token Family 무효화 포함)

```
유스케이스 ID: UC-005
행위자: 비밀번호 분실 사용자
사전 조건: 가입된 이메일 계정 보유
관련 FR: FR-003

주 흐름 (Main Flow):
  1. 사용자가 이메일 입력 후 비밀번호 재설정 요청
  2. [CWE-204] 이메일 미존재 시에도 성공 응답 반환 (정보 노출 방지)
  3. 시스템이 tb_mail_cert에 재설정 토큰(64자 hex) 저장 (TTL 1시간)
  4. 시스템이 재설정 링크 포함 이메일 발송
  5. 사용자가 이메일 링크 클릭 → 새 비밀번호 입력
  6. 시스템이 토큰 유효성 검증 (TTL, 미사용 여부)
  7. 시스템이 새 비밀번호 bcrypt 해시 저장
  8. 시스템이 해당 계정의 모든 Refresh Token Family 즉시 무효화

사후 조건: 비밀번호 재설정 완료, 모든 기존 세션 강제 종료

예외 흐름 (Exception Flows):
  6a. 토큰 만료 → HTTP 400 EXPIRED_CERT
  6b. 토큰 이미 사용됨 → HTTP 400 INVALID_CERT_TOKEN
  5a. 비밀번호 복잡도 미충족 → HTTP 400 WEAK_PASSWORD
```

---

## 11. 데이터 사전 (Data Dictionary)

### 11.1 tb_account (회원 계정)

| 컬럼명 | 타입 | 제약 | 설명 | FR 연관 |
|--------|------|------|------|---------|
| `ac_id` | INT UNSIGNED | PK, AUTO_INCREMENT | 회원 고유 ID | 전체 |
| `ac_email` | VARCHAR(255) | UNIQUE, NOT NULL | 이메일 (로그인 ID) | FR-001, FR-002 |
| `ac_password` | VARCHAR(255) | NULL | bcrypt 해시. SNS 전용 계정은 NULL | FR-001, FR-002, FR-003 |
| `ac_nick` | VARCHAR(50) | UNIQUE, NOT NULL | 닉네임 | FR-001, FR-004 |
| `ac_phone` | VARCHAR(20) | NULL | 휴대폰 번호 | FR-005 |
| `ac_name` | VARCHAR(100) | NULL | 실명 | FR-001 |
| `ac_status` | CHAR(1) | NOT NULL, DEFAULT 'A' | A(Active), D(Deleted), B(Banned), S(Suspended) | FR-007 |
| `ac_profile_img` | VARCHAR(500) | NULL | S3 CloudFront URL | FR-011 |
| `ce_code` | VARCHAR(50) | NULL | 상담사 코드. NULL=Caller, 값=Callee | NFR-007 |
| `ac_google_id` | VARCHAR(255) | NULL | Google OAuth 고유 ID | FR-006 |
| `ac_kakao_id` | VARCHAR(255) | NULL | Kakao OAuth 고유 ID | FR-006 |
| `ac_naver_id` | VARCHAR(255) | NULL | Naver OAuth 고유 ID | FR-006 |
| `ac_facebook_id` | VARCHAR(255) | NULL | Facebook OAuth 고유 ID | FR-006 |
| `ac_apple_id` | VARCHAR(255) | NULL | Apple OAuth 고유 ID | FR-006 |
| `ac_line_id` | VARCHAR(255) | NULL | Line OAuth 고유 ID | FR-006 |
| `ac_payment_token` | VARCHAR(500) | NULL | PG사 자동결제 토큰 | FR-009 |
| `ac_simplepay_pw` | VARCHAR(255) | NULL | 간편결제 PIN 해시 | FR-009 |
| `ac_nick_changed_at` | DATETIME | NULL | 닉네임 마지막 변경 일시 (UTC) | FR-004, NFR-004 |
| `created_at` | DATETIME | NOT NULL | 가입일 (UTC) | FR-001 |
| `updated_at` | DATETIME | NOT NULL | 최종 수정일 (UTC) | 전체 |
| `deleted_at` | DATETIME | NULL | 탈퇴 일시 (UTC) | FR-007 |

**인덱스:** `ac_email` (UNIQUE), `ac_nick` (UNIQUE), `ac_phone` (INDEX), `ac_status` (INDEX)

### 11.2 계정 상태 전이도 (Account Status Transition)

```
[신규 가입] ──→ A (Active) ──[관리자 제재]──→ B (Banned)
                     │
                     │──[일시 정지]──→ S (Suspended)
                     │
                     └──[탈퇴 요청]──→ D (Deleted)
                                              │
                                    [30일 후 재가입 허용]
```

### 11.3 주요 연관 테이블 요약

| 테이블명 | 목적 | 관련 FR |
|----------|------|---------|
| `tb_sms_auth` | SMS OTP 발송 로그 및 검증 | FR-005, NFR-003 |
| `tb_mail_cert` | 이메일 인증/비밀번호 재설정 토큰 | FR-001, FR-003 |
| `tb_account_history` | 닉네임 변경 이력 | FR-004, NFR-004 |
| `tb_call_result` | 통화 이력 및 리뷰 | FR-008, FR-010 |
| `tb_coin` | 코인 충전/사용 이력 | FR-008 |
| `tb_order` | 결제 주문 이력 + 멱등키 | FR-008, FR-009, NFR-006 |
| `tb_goods_order` | 상품 주문 이력 | FR-008 |
| `tb_chat_rooms` | 채팅방 이력 | FR-008 |
| `tb_alarm` | 알림 이력 | FR-008 |
| `tb_coupon` | 쿠폰 정의 | FR-008 |
| `tb_coupon_user` | 회원별 쿠폰 현황 | FR-008 |
| `tb_interphone_auth` | 인터폰 인증 이력 | FR-005 |
| `tb_regist_phone` | 등록 전화번호 관리 | FR-005 |
| `tb_sns_info` | SNS 연동 정보 | FR-006 |

---

## 12. 요구사항 검증 매트릭스 (Requirements Verification Matrix)

> **검증 방법 범례:** T = Test, A = Analysis, I = Inspection, D = Demonstration

### 12.1 기능 요구사항 검증 매트릭스

| FR ID | 요구사항 요약 | 검증 방법 | 검증 기준 | 상태 |
|-------|-------------|-----------|----------|------|
| FR-001-1 | 이메일 형식 검증 + 중복 확인 | T | 유효/무효 이메일 각 5종 테스트 | 완료 |
| FR-001-2 | 이메일 인증 메일 발송 및 링크 검증 | T | 인증 링크 만료/사용/정상 시나리오 | 완료 |
| FR-001-3 | bcrypt cost=12 해시 저장 | I | 소스코드에서 PASSWORD_BCRYPT + cost=12 확인 | 완료 |
| FR-001-6 | JWT 3쿠키 발급 | T | 응답 Set-Cookie 헤더 3종 검증 | 완료 |
| FR-002-4 | CWE-204 동일 에러 메시지 | A | 이메일 미존재/비밀번호 불일치 응답 비교 | 완료 |
| FR-002-5 | 더미 bcrypt 연산 | I | login() 메서드 내 더미 연산 코드 확인 | 완료 |
| FR-003-4 | Token Family 무효화 | T | 비밀번호 변경 후 기존 Refresh Token 갱신 시도 | 완료 |
| FR-004-1 | 7일 쿨다운 적용 | T | 변경 직후 재변경 시도 → 409 응답 | 완료 |
| FR-005-2 | 10회/일 SMS 제한 | T | 11회 연속 발송 시도 → 429 응답 | 완료 |
| FR-006-3 | SNS 중복 연동 방지 | T | 타 계정 연동 SNS ID로 연동 시도 → 409 | 완료 |
| FR-007-3 | 탈퇴 시 Token Family 무효화 | T | 탈퇴 후 Refresh Token 갱신 시도 → 401 | 완료 |
| FR-008-8 | Repository 소유권 조건 | A | 모든 조회 메서드 WHERE ac_id 조건 확인 | 완료 |
| FR-009-3 | 결제 멱등키 | T | 동일 멱등키 중복 결제 시도 → 409 | 완료 |
| FR-010-3 | 리뷰 1건 제한 | T | 동일 통화 리뷰 중복 작성 시도 → 409 | 완료 |

### 12.2 비기능 요구사항 검증 매트릭스

| NFR ID | 요구사항 요약 | 검증 방법 | 검증 기준 | 상태 |
|--------|-------------|-----------|----------|------|
| NFR-001 | CWE-204 타이밍 공격 방지 | A + T | 응답 시간 표준편차 < 10ms | 완료 |
| NFR-002 | bcrypt cost≥12 | I | `password_hash()` 파라미터 직접 확인 | 완료 |
| NFR-003 | SMS 10회/일 + 60초 대기 | T | 경계값 테스트 (10회, 11회, 59초, 60초) | 완료 |
| NFR-004 | 닉네임 7일 UTC 쿨다운 | T | UTC 기준 경계값 테스트 | 완료 |
| NFR-005 | p95 성능 목표 | T | 부하 테스트 도구 (k6 또는 동등) 사용 | 검증 필요 |
| NFR-006 | 결제 멱등키 UNIQUE | A | DB 스키마 UNIQUE 제약 확인 | 완료 |
| NFR-007 | 인가 3계층 | A + T | RoleFilter + checkNeedLogin + Repository 각 계층 단독 우회 시도 | 완료 |
| NFR-008 | camelCase 변환 | I | API 응답 JSON 키 전수 검사 | 완료 |

### 12.3 보안 검증 매트릭스

| 항목 | 기준 | 검증 방법 | 상태 |
|------|------|----------|------|
| JWT 쿠키 속성 | HttpOnly=true, Secure=true, SameSite=Lax | I | 완료 |
| CSRF 보호 | Signed Double Submit Cookie, HMAC-SHA256 | T | 완료 |
| 인가 3계층 | Layer 1+2+3 독립 동작 | T | 완료 |
| 입력 검증 | 모든 EP CI4 validation rules 적용 | I | 완료 |
| Auto Routing | `setAutoRoute(false)` 설정 | I | 완료 |
| 외부 API 키 | `.env` 참조, 소스 하드코딩 없음 | I | 완료 |
| S3 IAM Role | Instance Profile 기반, 키 하드코딩 없음 | I | 완료 |

---

## 13. 타당성 검토 (Feasibility Review)

### 13.1 기술적 타당성 (Technical Feasibility)

| 항목 | 근거 | 결론 |
|------|------|------|
| bcrypt (cost=12) | OWASP Password Storage Cheat Sheet: "bcrypt with cost factor 12+ for new systems." PHP 8.4 `password_hash()` 네이티브 지원으로 외부 의존성 없음 | 타당 |
| CWE-204 더미 연산 | OWASP Authentication Cheat Sheet: "Compare hashes even when user not found." PHP 표준 패턴으로 구현 부담 없음. bcrypt cost=12 기준 ~200ms 균일화 | 타당 |
| SMS 10회/일 제한 | SMS Link API 과금 정책 + 국내 이통사 스팸 방지 기준. Aurora MySQL 트랜잭션 안전. Redis 불필요(DB 카운트로 충분) | 타당 |
| 7일 닉네임 쿨다운 | 닉네임 남용(브랜드 사칭, 상담사 사칭) 방지 업계 표준 정책. `tb_account_history` 이력으로 감사 가능 | 타당 |
| Token Family 무효화 | RFC 6819 Section 5.2.2 준수. 탈취 토큰 재사용 감지 즉시 모든 세션 강제 종료. DB UNIQUE 제약으로 race condition 방지 | 타당 |
| Pre-signed URL (S3) | AWS 공식 권장 패턴. 서버 메모리 부담 없이 클라이언트가 S3 직접 업로드. AWS SDK for PHP 공식 지원 | 타당 |

### 13.2 운영 타당성 (Operational Feasibility)

| 항목 | 근거 | 결론 |
|------|------|------|
| 49개 EP 3 Controller 분리 | 단일 책임 원칙(SRP): Member(21), Mypage(20), Profile(8)로 기능별 분리. 유지보수성 향상 | 타당 |
| CI4 빌트인 Pager | CI4 4.7.2 공식 `paginate()` + `pager` 프로퍼티. 커스텀 구현 없이 일관성 보장 | 타당 |
| Aurora MySQL Multi-AZ | 프로덕션 가용성 요건(99.9%+) 충족. RDS Proxy로 연결 풀 관리. 읽기 전용 쿼리 Read Replica 분리 | 타당 |

### 13.3 보안 타당성 (Security Feasibility)

| 항목 | 근거 | 결론 |
|------|------|------|
| OWASP API5:2023 대응 | Repository 레벨 소유권 조건 내장. Layer 1(RoleFilter)+2(checkNeedLogin)+3(Repository) 3계층 방어 | 타당 |
| MIME 이중 검증 | OWASP File Upload Cheat Sheet: 확장자 단독 검증은 MIME 스푸핑에 취약. `mime_content_type()` 서버 측 검증 필수 | 타당 |

---

## 14. 변경 영향 기록 (Change Impact Log)

v2.1 갱신(2026-04-17)에서 반영한 변경 사항·개선점·수행 이유.

| # | 변경 사항 | 개선점 | 수행 이유 (Why) |
|---|----------|--------|----------------|
| 1 | FR-002-10 신규 — BaseController JWT fallback (`$_SERVER['AUTH_USER']['ac_id']`로 `$this->member` 복원) | 레거시 `hdata` 쿠키 의존 계정과 JWT 인증 계정이 동일 BaseController 경유 시 세션 상태 일관성 확보 | 커밋 `fbbf0a9` — hdata 미존재/복호화 실패 계정이 JWT 인증 성공에도 `is_login=false` 처리되어 마이페이지 이력 조회가 401로 실패하던 회귀 수정 |
| 2 | FR-002-11 신규 — logout `auth` 필터 | 미인증 세션의 logout 요청 차단으로 로그 오염·쿠키 삭제 남용 방지 | 커밋 `c6b8a5e` — logout 라우트가 공개 EP로 분류되어 있던 불일치 교정 |
| 3 | FR-003-8 신규 — 이중 해싱 금지 명문화 | Service/Repository 해싱 책임 분리로 로그인 불가 회귀 차단 | 커밋 `021a314` — ProfileService 비밀번호 변경이 Repository에서 재해싱되어 `password_verify` 영구 실패하던 Critical 버그 수정 |
| 4 | FR-004-6 신규 — 닉네임 요청 필드 단일화 (`ac_nick`/`acNick`) | 클라이언트-서버 계약 일관성 확보 | 커밋 `372277b` — `new_nick`, `ac_nick` 혼용으로 프론트엔드가 임의 필드로 전송 시 400 응답 발생하던 회귀 수정 |
| 5 | FR-005-8 신규 — 비프로덕션 verify-phone/find-id 인증번호 `222222` 고정 | 외부 SMS/AlimTalk 호출 제거로 통합 테스트 결정성 확보, 개발자 환경 진입 장벽 완화 | 커밋 `25f2285`, `a064453` — 개발/스테이징에서 SMS 발송 의존으로 테스트 플로우 중단되던 문제 해소 |
| 6 | FR-005-9 신규 — join-user Hermes DB 참조 비프로덕션 스킵 | 외부 DB 의존 제거로 가입 플로우 로컬 테스트 가능 | 커밋 `4fed062` — join 모드에서 Hermes 미연결 시 500 오류 방지 |
| 7 | NFR-007-1 신규 — 인증 필요 Member API 9종 `checkNeedLogin(true)` 일괄 적용 | RBAC Layer 2 방어 누락 회귀 차단, OWASP API5:2023 Defense in Depth 강화 | 커밋 `7e04106` — AuthFilter 단독 의존 구조에서 필터 설정 실수가 곧 인가 우회로 이어지던 리스크 차단 |
| 8 | NFR-009 신규 — 환경 분기 정책 전면 문서화 (SMS/AlimTalk/Email/Hermes) | 프로덕션-비프로덕션 동작 차이의 단일 근거 문서 확보 | 다수 커밋(`25f2285`, `0731339`, `4fed062`, `a064453`, `64aedf7`)이 산발적으로 비프로덕션 분기를 추가 — 통합 정책 기술 필요 |
| 9 | SMS 컨트롤러/서비스 `ENVIRONMENT` 상수 전환 (기록) | `getenv('CI_ENVIRONMENT')` 혼용 제거 | 커밋 `b4845e4` — `env()` 헬퍼 캐싱/프록시 차이로 환경 판정 불일치 발생 방지 |
| 10 | FR-002-12 신규 — BaseController API 경로 redirect/exit 금지 | API 요청이 HTML 리다이렉트 응답을 받아 클라이언트(JSON 파서)가 파싱 실패하던 회귀 차단 | 커밋 `8be5005` — `/api/` 경로에서 세션 불일치 시 404/302 응답 대신 null 멤버로 계속 진행, 컨트롤러가 `checkNeedLogin(true)`로 401 응답 생성 |
| 11 | FR-002-13 신규 — `hdata` 복호화 null 방어 | 손상된 쿠키로 인한 500 TypeError 대신 우아한 세션 파기 | 커밋 `43e3d66` — `custom_decrypt()` 반환값이 배열이 아니거나 `ac_id` 키가 없을 때 쿠키 만료 처리 |
| 12 | FR-007-8 신규 — 탈퇴/삭제 계정 쿠키 잔존 방어 | 탈퇴 후 재접근 시 BaseController 초기화 중 `member['ac_status']` TypeError 차단 | 커밋 `16a9144` — `$this->member` null일 때 후속 상태 체크 조건 수정 |
| 13 | NFR-009 구체화 — SMSLINK verify API 전 환경 제거 + DB 직접 매칭 | 외부 API 장애로 인한 로그인/회원가입 중단 리스크 차단, 검증 로직 단일 소스화 | 커밋 `64aedf7` — SMSLINK는 발송 전용, 검증은 `tb_interphone_auth` DB 5분 TTL 매칭으로 일원화 |
| 14 | NFR-009 구체화 — `saveSmsLog()` 비프로덕션 호출 제거 | 개발 환경에서 불필요한 로그 테이블 폴루션 방지 | 커밋 `d532349` |
| 15 | NFR-009 구체화 — CORS `localhost:5500`/`127.0.0.1:5500` 허용 | Flow Tester 등 로컬 HTML 도구의 전 환경(PRD 포함) 개발자 접근 허용 | 커밋 `a446d00`, `783699a` — 인증 EP는 credentials `include`, 공개 EP는 `omit`으로 쿠키 송신 분리 |
| 16 | 컨트롤러 런타임 버그 7건 수정(기록) | 19 EP 순차 플로우 테스트 통과 (5회 연속) | 커밋 `ade84ab` — `settingAlarm` type→컬럼 매핑, `updateHomeSet` HOME_TYPE 상수, `changeNick` ac_nick_date null, `findPasswordCert` password_hash(int) TypeError, `getMyAlarmCnt` COUNT string→int TypeError, `confirmIdCert/updatePhone` KR/해외 이중호출 제거 |
| 17 | `crypto_helper::id_secret()` 이메일 마스킹 신규(기록) | 아이디 찾기 응답 시 사용자 식별 정보 마스킹 일관 처리 | 커밋 `ade84ab` — `find-id`/`confirm-id-cert` 응답에 마스킹된 이메일 반환 |
| 18 | `MemberRepository::checkCertNum` 네임스페이스 교정(기록) | `\App\Libraries` → `\App\Modules\Member\Services` 모듈 소속 정상화 | 커밋 `64aedf7` — 마이그레이션 중 모듈 경계 불일치 해소 |
| 19 | `confirmGlobalCert` Repository 프록시 제거(기록) | Controller → Service 직접 호출로 레이어 단축 | 커밋 `64aedf7` — SDD 의존성 다이어그램 상 Repository는 DB 전용 계층 유지 |

---

## 15. 변경 로그 (Change Log)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 — FR-001~FR-010, NFR-001~NFR-006, Use Cases 4건, 체크리스트 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS. IEEE 29148:2018 적용. 이해관계자 요구사항(STK/SN), 시스템 맥락, FR-011(프로필) 신규 추가, 4-way 검증 매트릭스(T/A/I/D), 데이터 사전 전체 테이블, 외부 인터페이스 요구사항(EIF-001~005), 제약사항(CON-001~010), UC-005 비밀번호 재설정 신규 추가, 타당성 검토 3-way(기술/운영/보안) 확장 |
| v2.1 | 2026-04-17 | jypark | FR-002-10~13, FR-003-8, FR-004-6, FR-005-8/9, FR-007-8, NFR-007-1, NFR-009 신규 추가. 2026-04-16 18:00 KST 이후 29건 커밋 반영: 비프로덕션 환경 분기(SMS/AlimTalk/Mail/Hermes/CORS), SMSLINK verify 전환, BaseController API 경로 redirect 금지 + null 방어, 이중 해싱 금지, RBAC Layer 2 일괄 보강, 컨트롤러 런타임 버그 7건 수정. 3-Round IEEE Review PASS |
