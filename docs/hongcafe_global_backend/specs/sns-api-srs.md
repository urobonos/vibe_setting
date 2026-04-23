---
문서명: SNS Auth API — Software Requirements Specification
문서 ID: sns-api-srs
버전: v1.0
상태: 승인됨
생성일: 2026-04-22
최종 수정일: 2026-04-22
작성자: jypark
대상 시스템: SNS Auth (Auth 모듈 내 `/api/sns/*` 네임스페이스)
관련 문서: sns-api-sdd.md (v1.0), sns-api-idd.md (v1.0), sns-api-std.md (v1.0), auth-srs.md (v2.1), member-srs.md (v2.1)
적용 표준: IEEE 29148:2018
---

# SNS Auth API — Software Requirements Specification (SRS)

> IEEE 29148:2018 | version: 1.0 | lastUpdated: 2026-04-22 | module: Auth (SNS 서브도메인)

---

## 1. Introduction

### 1.1 Purpose

본 Software Requirements Specification(SRS)은 HongCafe Global Backend의 SNS Auth API(`POST /api/sns/receive`)에 대한 기능/비기능 요구사항을 IEEE 29148:2018 표준에 따라 정의한다. 본 문서는 설계(sns-api-sdd.md), 인터페이스(sns-api-idd.md), 테스트 케이스(sns-api-std.md) 작성의 기준이 된다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 모듈(BC) | Auth 모듈 내 `/api/sns/*` 네임스페이스 (SNS 로그인/가입 통합 서브도메인) |
| 목적 | 단일 엔드포인트로 7종 SNS(hongcafe/kakao/naver/apple/facebook/google/line) 로그인·가입을 `sns_type` + `action_type` 조합으로 통합 처리. v1 레거시 `data` 경로 하위 호환 |
| 이해관계자 | 프론트엔드(Next.js, 모바일 앱), Member 모듈(MemberRegistrationService 소비), Auth 모듈(JwtService 소비), SnsConnector 라이브러리(6종) |
| 포함 EP | `POST /api/sns/receive` (공개 EP — AuthFilter / CsrfTokenFilter 면제) |
| 제외 범위 | 일반 회원가입(`/api/members/join-user` — 별개 체계), 일반 로그인(`/api/members/login-user`), Apple id_token 독자 검증(프론트 위임), 상담사 온보딩 후속 플로우(`meta.isCalleeOnboardingRequired` 반환 후 프론트 책임) |

### 1.3 Definitions, Acronyms, and Abbreviations

| 용어 | 정의 |
|------|------|
| SNS | Social Network Service — 7종: `hongcafe`(자체) / `kakao` / `naver` / `apple` / `facebook` / `google` / `line` |
| OAuth code | SNS 제공자가 프론트엔드 리다이렉트로 전달하는 authorization code (RFC 6749 §4.1) |
| SnsConnector | OAuth token 교환 + 프로필 조회 라이브러리 (`app/Libraries/SnsConnector/*`). 6종 구현(`hongcafe` 제외) |
| encryptedSns | `custom_encrypt()` 로 암호화된 SNS payload base64 문자열. 404 응답 시 `details.encryptedSns` 로 반환, 재로그인/가입 시 `data` 필드로 재제출 |
| existFlag | 가입 분기 결과 플래그. `0`(완전 신규) / `2`(060 전환) / `3`(재가입) / `4`(이메일 중복) / `6`(강제탈퇴 히스토리) |
| action_type | 요청 의도 구분. `login`(기본) / `join` |
| suggestedAcNick | `snsCheckNick` 으로 자동 생성된 사용 가능 닉(최대 12자). 404 응답 시 프론트에 제안 |
| linkForm | 409 MISMATCH / EXISTING_USER 응답의 기존 회원 링킹 정보 (`acId`, `acNo`, `newRegPath`, `crCode`, `crPhone`) |
| Replay Attack | 탈취된 payload 를 재사용하는 공격. `issued_at` ±5분 검증으로 방지 (data 경로 한정) |
| AES-256-CBC | `data` 필드 암호화 알고리즘 (IV + ciphertext base64). `app/Helpers/crypto_helper.php` |
| PAYLOAD_MAX_AGE | `issued_at` 과거 허용 범위 300초 (5분). 미래 허용 60초(clock skew 허용) |

### 1.4 References

| 문서 | 경로/출처 |
|------|---------|
| API 명세 (Markdown) | `api-docs/auth/sns-api.md` v2 |
| API 명세 (OpenAPI 3.0.3) | `api-docs/auth/sns-api.yaml` v2.0.0 |
| 설계 문서 | `docs/specs/sns-api-sdd.md` v1.0 |
| 인터페이스 문서 | `docs/specs/sns-api-idd.md` v1.0 |
| 테스트 문서 | `docs/specs/sns-api-std.md` v1.0 |
| 관련 Auth SRS | `docs/specs/auth-srs.md` v2.1 (JwtService / CSRF 연계) |
| 관련 Member SRS | `docs/specs/member-srs.md` v2.1 (MemberRegistrationService 연계) |
| 작업 이력 | `docs/tasks/20260422/sns-api-unify/` (analyze.md, plan.md), 세션 2/6 |
| RFC 6749 | OAuth 2.0 Authorization Framework |
| RFC 7519 | JSON Web Token (JWT) |
| RFC 7231 | HTTP/1.1 Semantics and Content |
| OWASP API1:2023 | Broken Object Level Authorization |
| OWASP API2:2023 | Broken Authentication |
| IEEE 29148:2018 | ISO/IEC/IEEE — Systems and software engineering: Requirements engineering |

### 1.5 Overview

본 SRS는 다음 섹션으로 구성된다.

- §2 Overall Description — 시스템 관점, 기능 개요, 사용자 분류, 제약사항, 가정
- §3 Functional Requirements — FR별 선행조건/후행조건/입력검증/우선순위/관련API/검증방법
- §4 Non-Functional Requirements — 정량 기준 및 검증 방법
- §5 External Interface Requirements — 외부 시스템 인터페이스 (OAuth, SnsConnector, JwtService, MemberRegistrationService)
- §6 Use Cases — 정상/대안/에러 흐름
- §7 Verification Matrix — FR↔UC↔Test↔SDD 4-way 매핑
- §8 Data Dictionary — 핵심 데이터 요소 정의
- §9 타당성 검토
- §10 변경 영향 기록
- §11 체크리스트
- §12 변경 로그

---

## 2. Overall Description

### 2.1 System Perspective

SNS Auth API는 단일 EP(`POST /api/sns/receive`)로 7종 SNS 제공자의 로그인/가입을 통합 처리한다. Controller 는 Auth 모듈(`SnsController`) 소유이나 비즈니스 로직은 Member 모듈(`SnsAuthService`) 이 수행하여 회원 계정 처리(가입·계정 상태 판단·링킹)를 담당한다.

```
[Client / Next.js]
    │  POST /api/sns/receive { sns_type, action_type, code | data, ... }
    ▼
[Nginx rewrite: /__hongcafe_api__/api/sns/receive → /api/sns/receive]
    ▼
[ratelimit:10,60 filter]
    ▼
[App\Modules\Auth\Controllers\SnsController::receive]
    │  getJsonInput() → 화이트리스트 필드 → payload + clientMeta
    ▼
[App\Modules\Member\Services\SnsAuthService::handleCallback]
    │
    ├──► sns_type whitelist 검증 (SnsConnectorFactory::isSupported)
    ├──► action_type in ['login','join'] 검증
    ├──► payload 획득 분기:
    │       • OAuth 경로: SnsConnector* → GetAccessToken + GetProfile
    │       • data 경로 : custom_decrypt + issued_at 검증 + ac_id/sns_id 검증
    │
    ├──► action=login → handleLoginAction
    │       • resolveAccount → checkAccountStatus → handleSnsLinkage
    │       • ACTIVE + linked → issueTokens(JwtService) + insertLoginHistory → 200
    │       • 미가입(userInfo=null) → buildEncryptedSnsPayload + calculateExistFlag + trySuggestNick → 404
    │       • MISMATCH / EXISTING_USER → 409 + linkForm
    │       • ACCOUNT_* → 403
    │
    └──► action=join → handleJoinAction
            • 필수 필드(cr_phone/country_code/agree_*) 검증 → 400 MISSING_JOIN_FIELDS
            • snsCheckNick(baseNick) → 닉 확정 또는 NICK_GENERATION_FAILED
            • registrationService->register(data) → exist_flag
            • 4006 → 403 ACCOUNT_BANNED / 4009 → 409 PHONE_EXISTS
            • exist_flag=4 → 409 EMAIL_EXISTS
            • 성공 → issueTokens + joinSuccessResult → 200
```

### 2.2 Functions

| 기능 그룹 | 설명 |
|----------|------|
| Request 분기 | `sns_type` + `action_type` + `code`/`data` 유무로 OAuth 경로 vs data 경로 결정 |
| Payload 획득 (OAuth) | 6종 SnsConnector 중 적절한 구현 선택 → `getAccessToken($code)` + `getProfile()` (Apple은 `getProfile($code)` 단일 호출) |
| Payload 획득 (data) | AES-256-CBC `custom_decrypt()` → `ac_id`/`sns_id`/`sns_type` 유효성 + `issued_at` ±5분 검증 |
| 계정 조회 | `ac_id` 로 `accountInfo` 조회, `cr_phone` 로 보조 조회 (gear 경로) |
| 계정 상태 판단 | `checkAccountStatus()` — ACTIVE/SUSPENDED/DELETED/BANNED/UNDER_AGE/REJOIN_BLOCKED 중 하나 |
| SNS 링킹 판단 | `handleSnsLinkage()` — MATCH/MISMATCH/EXISTING_USER. `tb_sns_meta.{sns_type}_sync` 유무 기반 |
| 토큰 발급 | `JwtService::createTokenPair()` + `CsrfTokenService::issue()` → hc_access / hc_refresh / hc_csrf 3개 쿠키 생성 |
| 404 encrypted 반환 | 미가입 + login 시 payload 재암호화하여 `details.encryptedSns` 로 프론트에 반환. `suggestedAcNick` 동봉 |
| 닉 자동 증가 | `snsCheckNick()` — base 닉 중복 시 `{base}1`..`{base}9999` 탐색, 12자 초과 시 truncate |
| 가입 처리 | `MemberRegistrationService::register()` 호출 → `existFlag` 기반 분기 (0/2/3/4) |
| 이력 기록 | 성공 시 `insertLoginHistory()` → IP/User-Agent 저장 |

### 2.3 User Classes and Characteristics

| 사용자 분류 | 설명 | 인증 수준 |
|-----------|------|----------|
| 신규 SNS 가입자 | OAuth 최초 진입. login → 404 로 가입 유도 | 무인증 공개 EP 진입 |
| 재로그인 SNS 사용자 | 기존 회원 연동 완료. login → 200 + JWT 발급 | 무인증 공개 EP 진입 |
| 060 전환 가입자 | cr_phone 로 `060-*` 레거시 계정 매칭. join → existFlag=2 | 무인증 공개 EP 진입 |
| 재가입자 | 탈퇴 후 7일 경과. join → existFlag=3 | 무인증 공개 EP 진입 |
| 연동 필요 사용자 | 다른 SNS/자체 가입자가 새 SNS 시도. login → 409 EXISTING_USER + linkForm | 무인증 공개 EP 진입 |
| 상담사 (Callee) | 가입/로그인 성공 후 `ce_code` 존재. `meta.isCalleeOnboardingRequired` 로 프론트가 분기 | 후속: JWT 인증 |
| 일반 사용자 (Caller) | `ce_code` 없음. 메인 페이지로 이동 | 후속: JWT 인증 |

### 2.4 Constraints

- **공개 EP**: `AuthFilter EXCLUDED_PATHS` 등록 + `CsrfTokenFilter` 면제 (로그인 전이므로 CSRF 쿠키 없음). 단, `ratelimit:10,60` 필수 적용
- **레거시 쿠키 배제**: `hdata`, `ck_login_member`, `ambassador_login` 미발급. 발급 쿠키는 `hc_access`(15분) / `hc_refresh`(7일) / `hc_csrf`(2시간) 3개만
- **Apple id_token 직접 검증 금지**: Apple 은 `SnsConnector::Apple::getProfile($code)` 단일 호출로 내부 처리. `next-auth` 프론트 검증 결과를 서버가 재검증하는 로직 금지
- **SnsConnector 화이트리스트**: `SnsConnectorFactory::SUPPORTED_SNS_TYPES` 외 값 전달 시 400 INVALID_SNS_TYPE
- **Replay 방지 (data 경로)**: `issued_at` 과거 300초 / 미래 60초 범위 검증. OAuth 경로는 SNS 제공자의 code 유효기간(통상 10분)에 위임
- **country_code 폴백**: NULL/빈값 시 `DEFAULT_COUNTRY_CODE = 'US'`
- **ac_nick 제약**: 2~12자, 특수문자 제거 (`preg_replace('/[^\p{L}\p{N}]/u', '', $raw)`), DB 레벨 UNIQUE INDEX 로 race 방지
- **REJOIN_BLOCKED 쿨다운**: `ac_status=5` + `delete_date` NOW() 기준 7일 미경과 시 403
- **UNDER_AGE 검증 한정**: kakao/naver 에서 `birthyear + birthday` 제공 시만 수행. 기타 SNS 는 연령 미검증
- **맘카페/앰배서더 배제**: 한국 지역 커뮤니티 전용. 글로벌 서비스에 포함 금지 (session 2 결정)
- **details 네이밍**: camelCase (`encryptedSns`, `suggestedAcNick`, `linkForm.acId`). `BaseApiController::respondError` 가 `toCamelKeys()` 자동 변환

### 2.5 Assumptions and Dependencies

| 항목 | 내용 |
|------|------|
| 가정-1 | 프론트엔드가 OAuth authorization code 를 정상적으로 SNS 제공자로부터 획득해 전달 |
| 가정-2 | SnsConnector 6종이 각 SNS 제공자의 OAuth/Profile API 변경에 대응됨 (Apple secret JWT, Facebook Graph API 버전 등) |
| 가정-3 | `encryption.key` 가 `.env` 에 설정되어 있고 환경 간 동일 |
| 가정-4 | `tb_account.ac_nick` UNIQUE INDEX 존재 (세션 2 완료) |
| 가정-5 | `tb_account.delete_date` 컬럼 존재 (D-28 마이그레이션 반영) |
| 의존성-1 | Member 모듈: `MemberRepository`, `MemberRegistrationService`, `CountryRepository` |
| 의존성-2 | Auth 모듈: `JwtService`, `CsrfTokenService` |
| 의존성-3 | 외부 라이브러리: `SnsConnectorFactory`, `SnsConnector\{Apple,Facebook,Google,Kakao,Naver,Line}` |
| 의존성-4 | Helpers: `custom_encrypt()` / `custom_decrypt()` (`app/Helpers/crypto_helper.php`) |

---

## 3. Functional Requirements

### FR-SNS-001: SNS 로그인 (action_type=login)

| 항목 | 내용 |
|------|------|
| 설명 | OAuth code 또는 암호화 data 로 기존 SNS 회원 로그인 처리. 성공 시 JWT Token Pair + CSRF 쿠키 발급 |
| 선행 조건 | `sns_type` 화이트리스트 통과 + `action_type` in ['login',''(기본)] + OAuth code 또는 data payload 유효 |
| 후행 조건 | `hc_access` / `hc_refresh` / `hc_csrf` Set-Cookie 3개 + `data: null` + `meta.isCalleeOnboardingRequired` 반환. `tb_account.ac_lastlogin` 갱신. `tb_login_history` INSERT |
| 입력 검증 | (OAuth) code 유효 → SnsConnector 성공. (data) `ac_id`/`sns_id` 존재 + `issued_at` ±5분 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` (action_type=login) |
| 검증 방법 | Unit: `SnsAuthServiceTest::testDecryptAcceptsFreshIssuedAt` · Feature: `SnsReceiveApiActionTypeTest` |

### FR-SNS-002: SNS 가입 (action_type=join)

| 항목 | 내용 |
|------|------|
| 설명 | 신규·060전환·재가입 통합 처리. existFlag 로 분기된 결과 + JWT 발급 |
| 선행 조건 | payload 유효 + 필수 가입 필드(`cr_phone`, `country_code`, `agree_service=1`, `agree_privacy=1`, `agree_age=1`) 전부 충족 |
| 후행 조건 | 200 + `data: { acNick, existFlag }` + JWT 쿠키. `tb_account` INSERT 또는 UPDATE (existFlag 별 상이). `tb_login_history` INSERT |
| 입력 검증 | `cr_phone` non-empty, `country_code` non-empty, `agree_*` 모두 1. 누락 시 400 MISSING_JOIN_FIELDS (+ `missing: string[]`) |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` (action_type=join) |
| 검증 방법 | Unit: `SnsAuthServiceJoinActionTest` 11케이스 |

### FR-SNS-003: OAuth 토큰 교환 + 프로필 조회

| 항목 | 내용 |
|------|------|
| 설명 | `sns_type != hongcafe` + `code` 존재 시 각 SnsConnector 가 access_token 교환 후 프로필 조회하여 `email` / `sns_id` 포함 표준 payload 반환 |
| 선행 조건 | SnsConnectorFactory::createByType 가 valid 인스턴스 반환 |
| 후행 조건 | `['ac_id'=>email, 'sns_id'=>id, 'sns_type'=>type, 'issued_at'=>now]` 표준 payload. `sns_type` 특화 프로필 필드(예: `kakao_nick_name`) 추가 보존 |
| 입력 검증 | Apple: `getProfile($code)` 단일. 기타 6종: `GetAccessToken($code)` 성공 → `GetProfile()` 성공 → `email`/`sns_id` 존재 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` 내부 (`resolveFromOAuthCode`) |
| 검증 방법 | Unit: `SnsAuthServiceResolveOAuthTest` 10케이스 |

### FR-SNS-004: 암호화 Payload 복호화 (data 경로 / v1 호환)

| 항목 | 내용 |
|------|------|
| 설명 | `data` 필드 AES-256-CBC 복호화 + Replay 방지 검증 |
| 선행 조건 | `data` 필드 non-empty string |
| 후행 조건 | `ac_id`/`sns_id`/`sns_type`/`issued_at` 포함 payload 반환 |
| 입력 검증 | (1) `custom_decrypt` 성공 (2) `ac_id`, `sns_id` non-empty (3) `sns_type` 화이트리스트 (4) `issued_at` 과거 300초 / 미래 60초 범위 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` 내부 (`decryptCallbackData`) |
| 검증 방법 | Unit: `SnsAuthServiceTest` decrypt 7케이스 (missing, rejectUnknown, rejectStale, acceptFresh, tampered 등) |

### FR-SNS-005: 닉네임 자동 생성 (snsCheckNick)

| 항목 | 내용 |
|------|------|
| 설명 | 사용자 입력 닉 또는 base 닉(프로필/이메일/`{snsType}User` 순) 을 UNIQUE 제약 만족하도록 자동 증가 |
| 선행 조건 | action_type=join 플로우 진입 |
| 후행 조건 | DB 중복 없는 최종 `acNick` 반환 또는 NICK_GENERATION_FAILED 예외 |
| 입력 검증 | (1) `sanitizeNick` — 특수문자 제거 + 2~12자 보정 (빈/1자 → `user`) (2) 중복 시 `{base}1`..`{base}9999` (3) 12자 초과 시 base truncate (4) 1~9999 소진 → throw RuntimeException |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` 내부 (`snsCheckNick`) |
| 검증 방법 | Unit: `SnsAuthServiceSnsCheckNickTest` 10케이스 |

### FR-SNS-006: 404 미가입 응답 — encryptedSns + existFlag + suggestedAcNick

| 항목 | 내용 |
|------|------|
| 설명 | login 시 SNS 회원 미존재 → payload 재암호화 + existFlag 계산 + base닉 자동제안하여 프론트에 반환 |
| 선행 조건 | action_type=login + `resolveAccount` 결과 `userInfo=null` + 계정 상태 `ACCOUNT_*` 아님 |
| 후행 조건 | 404 + `details: { encryptedSns, existFlag, suggestedAcNick }`. Set-Cookie 없음 |
| 입력 검증 | `buildEncryptedSnsPayload` 성공. 실패 시 400 ENCRYPT_FAILED |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` 내부 (`notFoundResultExtended`) |
| 검증 방법 | Unit: 404 생성 경로 단위 테스트 / Feature: HTTP 404 status + details camelCase 검증 |

### FR-SNS-007: 계정 상태 검증 (403 분기)

| 항목 | 내용 |
|------|------|
| 설명 | 기존 회원 발견 시 `ac_status` + `delete_date` + birthyear 로 접근 가능 여부 판단 |
| 선행 조건 | `userInfo !== null` |
| 후행 조건 | ACTIVE 시 다음 단계 진입. 이외 상태는 403 + `details.reason` |
| 입력 검증 | `ac_status`: 3/4 → SUSPENDED, 5 + delete_date>7일 → DELETED, 5 + delete_date≤7일 → REJOIN_BLOCKED, 6 → BANNED. kakao/naver + birthyear/birthday 존재 + 계산 만19세 미만 → UNDER_AGE |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` 내부 (`checkAccountStatus`) |
| 검증 방법 | Unit: `SnsAuthServiceTest` checkAccount 분기 케이스 |

### FR-SNS-008: SNS 링킹 판단 (409 분기)

| 항목 | 내용 |
|------|------|
| 설명 | 기존 회원 발견 시 제공된 `ac_id` 와 DB `ac_id` 비교 및 `tb_sns_meta.{sns_type}_sync` 동기화 여부 판단 |
| 선행 조건 | `userInfo !== null` + 계정 ACTIVE |
| 후행 조건 | MATCH → 통과 (토큰 발급). MISMATCH → 409 + linkForm(acId, acNo). EXISTING_USER → 409 + linkForm(acId, acNo, newRegPath, crCode, crPhone) |
| 입력 검증 | `ac_reg_path === 'apple' && sns_type === 'apple'` 조합은 MISMATCH 예외(Apple Private Relay 이메일 변경 허용). tb_sns_meta 에 동기화 레코드 존재 시 자동 MATCH |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/sns/receive` 내부 (`handleSnsLinkage`) |
| 검증 방법 | Unit: linkage 매트릭스 단위 테스트 |

### FR-SNS-009: JWT 발급 + CSRF 토큰 발급

| 항목 | 내용 |
|------|------|
| 설명 | 로그인/가입 성공 시 JwtService::createTokenPair() + CsrfTokenService::issue() 호출하여 3개 쿠키 값 생성 |
| 선행 조건 | 로그인/가입 경로 성공 직전 (userInfo 확정) |
| 후행 조건 | `cookies: { hc_access, hc_refresh, hc_csrf }` 배열 반환. SnsController 가 Set-Cookie 헤더로 출력. hc_access/hc_refresh HttpOnly=true, hc_csrf HttpOnly=false |
| 입력 검증 | `userInfo['ac_id']` + `userInfo['cr_code']` + `userInfo['ac_nick']` 존재 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `issueTokens()` 내부 → `JwtService` (auth-srs FR-007 참조) |
| 검증 방법 | Unit: token 발급 결과 Set-Cookie 3개 포함 검증 |

### FR-SNS-010: Rate Limit (IP 기반)

| 항목 | 내용 |
|------|------|
| 설명 | IP 당 60초 10회 초과 시 429 + `Retry-After` 헤더 |
| 선행 조건 | 요청 진입 시점 |
| 후행 조건 | 초과 시 429 TOO_MANY_REQUESTS. 응답 body 에 Retry-After 값과 동일한 초 단위 재시도 대기 시간 |
| 입력 검증 | CI4 ratelimit 필터 내장 로직 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `ratelimit:10,60` 필터 (Routes.php: `$routes->post('sns/receive', 'SnsController::receive', ['filter' => 'ratelimit:10,60'])`) |
| 검증 방법 | Feature: 11회 연속 호출 시 11번째 응답 429 확인 |

### FR-SNS-011: v1 하위 호환 (sns_type/action_type 미지정)

| 항목 | 내용 |
|------|------|
| 설명 | `sns_type` 미지정 + `data` 제공 시 `action_type=login` 기본값으로 data 경로만 실행 |
| 선행 조건 | 기존 v1 호출자 |
| 후행 조건 | v1 과 동일 응답 shape. 신규 필드(`meta.isCalleeOnboardingRequired`) 는 추가됨 |
| 입력 검증 | sns_type 빈 문자열 시 isSupported 체크 스킵. data 경로 진입 |
| 우선순위 | 필수 (Priority 1, 호환성 유지) |
| 관련 API | `POST /api/sns/receive` (body에 sns_type/action_type 없음) |
| 검증 방법 | Feature: `SnsReceiveApiActionTypeTest::testV1CompatibilityWithOnlyDataFieldFallsBackToLogin` |

### FR-SNS-012: `meta.isCalleeOnboardingRequired` 상담사 분기

| 항목 | 내용 |
|------|------|
| 설명 | 상담사(`ce_code` 보유) + `ce_status=0` + `ce_status0_first_login_date` 비어있음 시 true 반환하여 프론트가 정산계좌 등록 페이지로 라우팅 유도 |
| 선행 조건 | 로그인/가입 성공 + userInfo 최종 확정 |
| 후행 조건 | `meta.isCalleeOnboardingRequired: bool` 필드 응답 |
| 입력 검증 | userInfo 의 ce_code/ce_status/ce_status0_first_login_date 필드 조합 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `successResult()` + `joinSuccessResult()` 내부 (`flags['isCalleeOnboardingRequired']`) |
| 검증 방법 | Unit: 상담사 첫 로그인 케이스 / 일반 로그인 케이스 분기 검증 |

---

## 4. Non-Functional Requirements

| ID | 구분 | 요구사항 | 정량 기준 | 검증 방법 |
|----|------|---------|---------|---------|
| NFR-SNS-001 | 성능 | /api/sns/receive 응답 시간 (data 경로) | 200ms 이내 (P95) | Artillery 부하 테스트 |
| NFR-SNS-002 | 성능 | /api/sns/receive 응답 시간 (OAuth 경로) | 2000ms 이내 (P95, SNS 제공자 응답 포함) | OAuth 모의 환경 응답 로그 분석 |
| NFR-SNS-003 | 보안 | Payload Replay Window | 과거 300초 / 미래 60초 | `SnsAuthServiceTest::testDecryptRejectsStaleIssuedAt` |
| NFR-SNS-004 | 보안 | AES-256-CBC IV 엔트로피 | 매 호출마다 `random_bytes(16)` | custom_encrypt 코드 리뷰 |
| NFR-SNS-005 | 보안 | sns_type 화이트리스트 | 7종 외 거부 | `SnsConnectorFactoryTest::testIsSupportedReturnsFalseForUnknownType` |
| NFR-SNS-006 | 가용성 | Rate Limit | 10 req / 60 sec (IP 기반) | ratelimit 필터 단위 테스트 |
| NFR-SNS-007 | 호환성 | v1 API 하위 호환 | sns_type 미지정 시 data 경로 동작 유지 | `SnsReceiveApiActionTypeTest::testV1Compatibility*` |
| NFR-SNS-008 | 정확성 | 닉 자동 증가 범위 | 1~9999 | `SnsAuthServiceSnsCheckNickTest::testThrowsRuntimeExceptionWhenExhausted` |
| NFR-SNS-009 | 정확성 | 닉 최대 길이 | 12자 (`mb_substr`) | `SnsAuthServiceSnsCheckNickTest::testTruncatesWhenOverflows12Chars` |
| NFR-SNS-010 | 보안 | 로그에 민감정보 노출 금지 | `data` 전문 / `code` 전문 / JWT 로그 금지. 로그는 첫 50바이트 subset 만 | `log_message` 호출부 코드 리뷰 |
| NFR-SNS-011 | 관측성 | 로그인 이력 기록 | 성공 시 `tb_account_history` + `tb_login_history` INSERT (IP/UA/sns_type) | 통합 테스트 (staging) |
| NFR-SNS-012 | 호환성 | 응답 키 네이밍 | data/meta/error.details 모두 camelCase | `SnsReceiveApiActionTypeTest::testErrorDetailsUsesCamelCase` |
| NFR-SNS-013 | 보안 | Apple Private Relay 대응 | `ac_reg_path=apple` + `sns_type=apple` 시 ac_id 불일치 허용 | Unit: MISMATCH 예외 처리 |
| NFR-SNS-014 | 보안 | UNDER_AGE 연령 검증 | kakao/naver 에서 birthyear+birthday 제공 시 만 19세 미만 차단 | Unit: UNDER_AGE 단위 테스트 |
| NFR-SNS-015 | 안정성 | REJOIN_BLOCKED 쿨다운 | 탈퇴 후 7일 (604800초) | Unit: delete_date 7일 미경과 403 검증 |

---

## 5. External Interface Requirements

### 5.1 사용자 인터페이스

- HTTP/HTTPS REST API. JSON 응답 전용
- 프론트엔드는 `X-Forwarded-Proto: https` 헤더 필수
- 성공 시 Set-Cookie 3개(`hc_access` / `hc_refresh` / `hc_csrf`) 자동 브라우저 저장

### 5.2 하드웨어 인터페이스

- 해당 없음

### 5.3 소프트웨어 인터페이스

| 외부 시스템 | 프로토콜 | 설명 |
|-----------|---------|------|
| Kakao OAuth | HTTPS REST | `kauth.kakao.com/oauth/token` + `kapi.kakao.com/v2/user/me` |
| Naver OAuth | HTTPS REST | `nid.naver.com/oauth2.0/token` + `openapi.naver.com/v1/nid/me` |
| Apple Sign In | HTTPS REST | `appleid.apple.com/auth/token` + id_token JWT 내부 검증 (`SnsConnector\Apple::generateJWT` → ES256) |
| Facebook Login | HTTPS REST (Graph API) | `graph.facebook.com/v{n}/oauth/access_token` + `graph.facebook.com/me` |
| Google OAuth | HTTPS REST | `oauth2.googleapis.com/token` + `www.googleapis.com/oauth2/v2/userinfo` |
| LINE Login | HTTPS REST | `api.line.me/oauth2/v2.1/token` + `api.line.me/v2/profile` |
| JwtService (Auth 모듈) | 내부 DI | `createTokenPair(ac_id, cr_code, ac_nick)` |
| CsrfTokenService (Shared) | 내부 DI | `issue()` / `revoke()` |
| MemberRegistrationService (Member) | 내부 DI | `register(array): array` — existFlag 반환 |
| MemberRepository (Member) | 내부 DI | `accountInfo()`, `updateLastlogin()`, `insertLoginHistory()` |
| SnsMetaRepository (Member) | 내부 DI | `find()`, `insertOrUpdate()` |
| CountryRepository (Member) | 내부 DI | `findByCode()` — country_code 정규화 |
| custom_encrypt/custom_decrypt | 전역 헬퍼 | AES-256-CBC |

### 5.4 통신 인터페이스

- HTTPS 전용 (ALB → Nginx → PHP-FPM 체인)
- `X-Forwarded-For` 로 client IP 전달 → `ratelimit` 필터 식별자
- `X-Forwarded-Proto: https` 로 Secure 쿠키 플래그 판단

---

## 6. Use Cases

### UC-SNS-01: 신규 카카오 사용자 로그인 → 가입 유도

**전제 조건**: 프론트가 카카오 OAuth authorization code 획득 완료. 해당 계정은 hongcafe 미가입.

**기본 흐름**:
1. `POST /api/sns/receive { sns_type: "kakao", action_type: "login", code: "..." }`
2. SnsAuthService → SnsConnectorFactory → Kakao connector
3. `GetAccessToken(code)` 성공 → `GetProfile()` → `email`, `kakao_user_id` 확보
4. `memberRepository.accountInfo('ac_id', email)` → null
5. `buildEncryptedSnsPayload(payload)` → base64 암호화
6. `calculateExistFlag(payload, snsPhone)` → 0 (완전 신규)
7. `trySuggestNick(payload)` → `snsCheckNick('sanghee123')` → `sanghee123` (사용 가능)
8. 응답: **404** `{ error: { code: "NOT_FOUND", details: { encryptedSns, existFlag: 0, suggestedAcNick: "sanghee123" } } }`

**대안 흐름**: 3 단계에서 `GetProfile()` 실패 → 400 `PROFILE_FETCH_FAILED`

### UC-SNS-02: 기존 카카오 회원 로그인 성공

**전제 조건**: hongcafe 카카오 가입 완료 (`tb_sns_meta.kakao_sync='ok'`). `ac_status=0`.

**기본 흐름**:
1. `POST /api/sns/receive { sns_type: "kakao", action_type: "login", code: "..." }`
2. payload 획득 → `accountInfo` 조회 → userInfo 반환
3. `checkAccountStatus` → ACTIVE
4. `handleSnsLinkage` → MATCH
5. `JwtService::createTokenPair` + `CsrfTokenService::issue` → 3 쿠키
6. `updateLastlogin` + `insertLoginHistory` (IP, UA)
7. 응답: **200** `{ data: null, meta: { isCalleeOnboardingRequired: false } }` + Set-Cookie 3개

### UC-SNS-03: 네이버 신규 가입 성공

**전제 조건**: 프론트가 404 응답 받은 후 가입 폼 작성 완료.

**기본 흐름**:
1. `POST /api/sns/receive { sns_type: "naver", action_type: "join", code: "...", cr_phone: "821012345678", country_code: "KR", ac_nick: "naverUser", agree_service: 1, agree_privacy: 1, agree_age: 1 }`
2. payload 획득 → 필수 필드 검증 통과
3. `snsCheckNick("naverUser")` → DB 중복 없음 → `naverUser`
4. `MemberRegistrationService::register(...)` → existFlag=0, 신규 ac_no 발급
5. `accountInfo` 재조회 → userInfo
6. `issueTokens` + `insertLoginHistory`
7. 응답: **200** `{ data: { acNick: "naverUser", existFlag: 0 }, meta: { isCalleeOnboardingRequired: false } }`

### UC-SNS-04: 계정 차단(ACCOUNT_SUSPENDED) 거부

**전제 조건**: hongcafe 회원 `ac_status=3` (이용중지).

**기본 흐름**:
1. `POST /api/sns/receive { sns_type: "kakao", action_type: "login", code: "..." }`
2. payload 획득 → userInfo 조회 성공
3. `checkAccountStatus` → SUSPENDED
4. 응답: **403** `{ error: { code: "FORBIDDEN", message: "현재 이용중지된...", details: { reason: "ACCOUNT_SUSPENDED" } } }`

### UC-SNS-05: 이미 가입된 이메일 (action_type=join, EMAIL_EXISTS)

**전제 조건**: `ac_id="user@example.com"` 이미 가입. 사용자가 네이버 join 시도.

**기본 흐름**:
1. `POST /api/sns/receive { sns_type: "naver", action_type: "join", code: "...", cr_phone: "821022223333", country_code: "KR", agree_*: 1 }`
2. payload 획득 → email=`user@example.com`
3. 필수 필드 검증 통과 + snsCheckNick 통과
4. `MemberRegistrationService::register(...)` → existFlag=4 반환 (email 충돌)
5. 응답: **409** `{ error: { code: "CONFLICT", message: "이미 가입된 이메일입니다.", details: { reason: "EMAIL_EXISTS", existFlag: 4 } } }`

### UC-SNS-06: Rate Limit 초과

**전제 조건**: 동일 IP 에서 60초 내 10회 호출 완료.

**기본 흐름**:
1. 11번째 POST 호출
2. ratelimit 필터 감지 → Controller 진입 전 차단
3. 응답: **429** `{ error: { code: "TOO_MANY_REQUESTS", message: "요청 한도..." } }` + `Retry-After: N` 헤더

### UC-SNS-07: v1 호환 호출

**전제 조건**: 기존 프론트엔드가 `sns_type` 없이 `data` 만 POST.

**기본 흐름**:
1. `POST /api/sns/receive { data: "base64-payload" }`
2. `action_type=login` 기본값 적용. sns_type 빈 문자열 → isSupported 검사 skip
3. data 경로 실행 → payload 획득
4. 이후 UC-SNS-02 와 동일 플로우

---

## 7. Verification Matrix (FR ↔ UC ↔ Test ↔ SDD)

| FR | UC | Test 파일 | SDD 섹션 |
|----|----|----------|---------|
| FR-SNS-001 | UC-SNS-02 | `SnsAuthServiceTest` decrypt 7건 + `SnsReceiveApiActionTypeTest` 8건 | SDD §3.1 handleLoginAction |
| FR-SNS-002 | UC-SNS-03, UC-SNS-05 | `SnsAuthServiceJoinActionTest` 11건 | SDD §3.2 handleJoinAction |
| FR-SNS-003 | UC-SNS-02, UC-SNS-03 | `SnsAuthServiceResolveOAuthTest` 10건 | SDD §3.3 resolveFromOAuthCode |
| FR-SNS-004 | UC-SNS-07 | `SnsAuthServiceTest` decrypt 케이스 | SDD §3.4 decryptCallbackData |
| FR-SNS-005 | UC-SNS-03 | `SnsAuthServiceSnsCheckNickTest` 10건 | SDD §3.5 snsCheckNick |
| FR-SNS-006 | UC-SNS-01 | 404 분기 커버 (Feature) | SDD §3.1 notFoundResultExtended |
| FR-SNS-007 | UC-SNS-04 | checkAccountStatus 매트릭스 단위 테스트 | SDD §3.6 checkAccountStatus |
| FR-SNS-008 | UC-SNS-02 | handleSnsLinkage 매트릭스 | SDD §3.7 handleSnsLinkage |
| FR-SNS-009 | UC-SNS-02, UC-SNS-03 | issueTokens Set-Cookie 검증 | SDD §3.8 issueTokens |
| FR-SNS-010 | UC-SNS-06 | Feature 11회 호출 시 429 | SDD §3.9 Rate Limit 필터 |
| FR-SNS-011 | UC-SNS-07 | `testV1CompatibilityWith*` | SDD §3.1 v1 경로 |
| FR-SNS-012 | UC-SNS-02 | successResult/joinSuccessResult flags | SDD §3.8 상담사 분기 |

---

## 8. Data Dictionary

| 식별자 | 타입 | 범위/제약 | 설명 |
|--------|------|---------|------|
| `sns_type` | string | enum[7] | hongcafe/kakao/naver/apple/facebook/google/line |
| `action_type` | string | enum[2] + '' | login(기본) / join |
| `code` | string | non-empty | OAuth authorization code |
| `data` | string (base64) | ≤ 4096 bytes | AES-256-CBC 암호화 payload |
| `ac_id` | string (email) | RFC 5322 | 계정 식별자. `data` 복호화 후 필수 |
| `sns_id` | string | non-empty | SNS 제공자 고유 ID. `data` 복호화 후 필수 |
| `issued_at` | integer (Unix) | now-300s ≤ x ≤ now+60s | Replay 방지 타임스탬프 |
| `cr_phone` | string | 국가번호+숫자 | `action_type=join` 필수 |
| `country_code` | string | ISO 3166-1 alpha-2 | 기본값 'US' |
| `ac_nick` | string | 2~12자 + Letter/Number only | UNIQUE INDEX 강제 |
| `agree_service`, `agree_privacy`, `agree_age` | integer | `=1` | `action_type=join` 필수 |
| `existFlag` | integer | 0/2/3/4/6 | 가입 분기 결과 (§1.3) |
| `encryptedSns` | string (base64) | - | 404 응답용 재암호화 payload |
| `suggestedAcNick` | string \| null | 2~12자 | 404 응답 시 자동 제안. 실패 시 필드 누락 |
| `linkForm.acId` | string (email) | - | 409 linkForm 내 기존 회원 ac_id |
| `linkForm.acNo` | integer | - | 기존 회원 PK |
| `linkForm.newRegPath` | string | sns_type | EXISTING_USER 시 새 SNS 타입 |
| `linkForm.crCode` | string | CR-* format | 기존 회원 코드 |
| `linkForm.crPhone` | string | - | 기존 회원 전화번호 |
| `isCalleeOnboardingRequired` | boolean | - | 상담사 첫 로그인 여부 |

---

## 9. 타당성 검토 (Feasibility Review)

### 9.1 근거 문서 검색 결과 (docset-ref / WebFetch)

- **OAuth 2.0 (RFC 6749 §4.1)**: authorization code flow. 본 API의 `code` 파라미터가 표준 준수
- **RFC 7231 §6.6.1**: HTTP 400 "Bad Request" 의미(의미상 클라이언트 오류). `INVALID_INPUT` 매핑 적합
- **RFC 7231 §6.5.4**: HTTP 404 "Not Found" — 리소스 미발견. 본 API의 "SNS 계정에 매칭되는 회원 미존재" 에 적합
- **RFC 7231 §6.5.8**: HTTP 409 "Conflict" — 리소스 상태 충돌. `MISMATCH/EXISTING_USER/EMAIL_EXISTS/PHONE_EXISTS` 매핑 적합
- **OWASP API2:2023 (Broken Authentication)**: stateless JWT + HttpOnly 쿠키 + SameSite=Lax + Secure 조합은 권고 패턴과 일치
- **CI4 7.x Filter 문서**: `ratelimit:rate,seconds` 포맷 공식. `ratelimit:10,60` 유효

### 9.2 설계 선택 정당화

| 선택 | 근거 |
|------|------|
| 단일 EP + action_type 분기 | v1 의 `data` 경로와 v2 의 OAuth 경로를 하나의 라우트 entry 로 통합하여 프론트 통합 용이. 내부 분기는 Service 레이어에서 처리 |
| action_type 기본값 'login' | v1 호출자가 action_type 미지정이므로 기본값 'login' 으로 하위 호환 보존 |
| 404 + encryptedSns 반환 | 미가입 시 HTTP 404 로 SSOT 준수 + payload 재활용으로 프론트-서버 round trip 최소화 |
| JWT + CSRF 3 쿠키 동시 발급 | Auth 모듈의 표준 (auth-srs §FR-002) 따름. 로그인/가입 경로 통일 |
| SnsConnector 재활용 (v1 에서 계승) | 6종 SNS 제공자 변경 대응 (이미 운영 검증). 다만 Apple 은 단일 호출 특화 필요 |
| `snsCheckNick` 1~9999 한계 | 실제 닉 패턴상 충돌 확률 극히 낮음. 소진 시 명시적 오류 반환으로 무한 루프 방지 |

### 9.3 위험 평가

| 위험 | 확률 | 영향 | 대응 |
|------|-----|------|------|
| SNS 제공자 OAuth API 스펙 변경 | 중 | 높음 | SnsConnector 개별 파일 테스트 커버 + staging 실연동 모니터링 |
| `encryption.key` 로테이션 시 기존 encryptedSns 무효화 | 낮음 | 중 | 로테이션 절차에 24시간 과도기 지정 필요 (별도 세션 과제) |
| SNS 닉 충돌 폭주 (1~9999 소진) | 매우 낮음 | 낮음 | 소진 시 명시적 `NICK_GENERATION_FAILED` 반환. Feature 테스트 커버 |
| Apple Private Relay 이메일 변경 | 중 | 중 | MISMATCH 예외 처리 (`ac_reg_path=apple + sns_type=apple`) |

---

## 10. 변경 영향 기록 (Change Impact Log)

### 10.1 변경 사항

- **신규 생성**: 본 SRS 문서 (v1.0). 기존 `auth-srs.md`, `member-srs.md` 와 별개로 SNS 서브도메인 전용 SRS 신설
- **트리거**: 사용자 요청 — sns-api 문서 점검 + IEEE 산출물 작성
- **반영 범위**: `docs/specs/sns-api-{srs,sdd,idd,std}.md` 4종

### 10.2 개선 효과

1. **SNS 전용 요구사항 식별**: 기존 auth-srs 는 JWT/CSRF/Geo 중심, member-srs 는 일반 가입 중심이라 SNS 통합 EP 의 FR/NFR 이 누락 상태. 본 SRS 로 12 FR + 15 NFR 명시
2. **Verification Matrix 4-way**: FR ↔ UC ↔ Test ↔ SDD 매핑으로 테스트 커버리지 가시화. 세션 7 phpunit 100회 반복에서 실증된 195 테스트 중 sns-api 범위 식별 용이
3. **v1 → v2 호환성 명시**: FR-SNS-011 로 하위 호환 계약 공식화. 프론트 배포 순서 결정 근거

### 10.3 수행 이유 (Why)

1. `api-docs/auth/sns-api.{md,yaml}` 는 API 명세 수준 (계약). IEEE SRS 는 상위 요구사항 수준 (왜 + 정량 기준)
2. 세션 6 drift 점검에서 "테스트 신규 예정" 등 outdated 문구 식별. IEEE 산출물로 요구사항-테스트 매핑 재정비 필요
3. 프로젝트 지침(CLAUDE.md `§참고 문서` docs/specs/{BC}-{srs|sdd|std|idd}.md 규약) 준수

---

## 11. 체크리스트

- [x] IEEE 29148:2018 11개 표준 섹션(§1~§8 + §9~§12 확장) 준수
- [x] FR 12건 명시 + 각 항목에 선행조건/후행조건/입력검증/우선순위/관련API/검증방법 포함
- [x] NFR 15건 정량 기준 + 검증 방법 명시
- [x] UC 7건 (정상/대안/에러 흐름 커버)
- [x] Verification Matrix FR-UC-Test-SDD 4-way 매핑
- [x] Data Dictionary 전 필드 타입/제약 명시
- [x] 타당성 검토 — RFC/OWASP/CI4 공식 문서 근거
- [x] 변경 영향 기록 — 변경/개선/수행이유 3요소

---

## 12. 변경 로그

| 날짜 | 버전 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| 2026-04-22 | v1.0 | jypark | 최초 작성 — sns-api v2 (/api/sns/receive) IEEE SRS. 12 FR + 15 NFR + 7 UC + 13 Data 정의 |
