---
문서명: SNS Auth API — Software Design Description
문서 ID: sns-api-sdd
버전: v1.0
상태: 승인됨
생성일: 2026-04-22
최종 수정일: 2026-04-22
작성자: jypark
대상 시스템: SNS Auth (Auth 모듈 내 `/api/sns/*` 서브도메인)
관련 문서: sns-api-srs.md (v1.0), sns-api-idd.md (v1.0), sns-api-std.md (v1.0)
적용 표준: IEEE 1016:2009
---

# SNS Auth API — Software Design Description (SDD)

> IEEE 1016:2009 | version: 1.0 | lastUpdated: 2026-04-22

---

## 1. Introduction

### 1.1 Purpose

본 Software Design Description(SDD)은 `sns-api-srs.md` 에서 정의한 요구사항을 구현하는 설계를 IEEE 1016:2009 에 따라 기술한다. 아키텍처, 컴포넌트 분해, 시퀀스, 데이터 모델, 설계 원칙 및 설계 선택 정당화를 포함한다.

### 1.2 Scope

- `POST /api/sns/receive` EP 의 내부 설계 전체
- Controller(`SnsController`) + Service(`SnsAuthService`) + 외부 의존성(SnsConnector 6종, JwtService, MemberRegistrationService, Repository 3종) 관계
- AES-256-CBC 암호화 / JWT 발급 / CSRF 쿠키 발급 흐름
- 에러 매핑 전략 (SRS §3 FR → HTTP status + details.reason)

### 1.3 References

| 문서 | 경로 |
|------|------|
| SRS | `docs/specs/sns-api-srs.md` v1.0 |
| IDD | `docs/specs/sns-api-idd.md` v1.0 |
| STD | `docs/specs/sns-api-std.md` v1.0 |
| 관련 Auth SDD | `docs/specs/auth-sdd.md` v2.1 (JwtService / CsrfTokenService 설계) |
| 관련 Member SDD | `docs/specs/member-sdd.md` v2.1 (MemberRegistrationService 설계) |
| 구현 파일 | `app/Modules/Auth/Controllers/SnsController.php`, `app/Modules/Member/Services/SnsAuthService.php` (834 라인) |

---

## 2. Architectural Design

### 2.1 High-level Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                        Client (Next.js / Mobile)                    │
└───────────────────────────────────┬────────────────────────────────┘
                                    │ HTTPS
                                    ▼
┌────────────────────────────────────────────────────────────────────┐
│  Nginx (rewrite: /__hongcafe_api__/ → /)                           │
└───────────────────────────────────┬────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────┐
│  CI4 Filter Chain:  ratelimit:10,60                                 │
│                     (AuthFilter, CsrfTokenFilter 면제 — 공개 EP)    │
└───────────────────────────────────┬────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────┐
│  App\Modules\Auth\Controllers\SnsController                         │
│    receive():                                                       │
│      • getJsonInput() → 화이트리스트 13 필드                        │
│      • clientMeta (ip, user_agent)                                  │
│      • snsAuthService->handleCallback(payload, clientMeta)          │
│      • 성공: applyCookies + respondSuccessWithMeta                  │
│      • 실패: respondError (code, message, http_code, details)       │
└───────────────────────────────────┬────────────────────────────────┘
                                    │ (DI: service('snsAuthService'))
                                    ▼
┌────────────────────────────────────────────────────────────────────┐
│  App\Modules\Member\Services\SnsAuthService                         │
│                                                                     │
│   handleCallback()  ─── action_type 분기                            │
│     ├─► handleLoginAction()                                         │
│     └─► handleJoinAction()                                          │
│                                                                     │
│   Helpers:                                                          │
│     obtainPayload()       ── OAuth 경로 vs data 경로 선택            │
│     resolveFromOAuthCode()── SnsConnector 호출                       │
│     decryptCallbackData() ── custom_decrypt + replay 검증            │
│     resolveAccount()      ── accountInfo + phone 보조 조회           │
│     checkAccountStatus()  ── ACTIVE/SUSPENDED/…/UNDER_AGE            │
│     handleSnsLinkage()    ── MATCH/MISMATCH/EXISTING_USER            │
│     issueTokens()         ── JwtService + CsrfTokenService           │
│     snsCheckNick()        ── 닉 자동 증가                            │
│     buildEncryptedSnsPayload() ── 404 응답용 재암호화                 │
└───────────────────┬──────────────────┬─────────────────┬──────────┘
                    │                  │                 │
                    ▼                  ▼                 ▼
         ┌──────────────────┐ ┌───────────────┐ ┌───────────────────┐
         │ SnsConnector-    │ │ Jwt/Csrf      │ │ MemberRegistration│
         │  Factory          │ │  Service      │ │  Service          │
         │   (6 Connector)   │ │ (Auth 모듈)    │ │  (Member 모듈)     │
         └──────────────────┘ └───────────────┘ └───────────────────┘
                    │                              │
                    ▼                              ▼
          [kakao/naver/apple/                [Member Repository
           facebook/google/line                + SnsMeta
           외부 OAuth 서버]                    + Country Repo]
```

### 2.2 Module Decomposition

| 컴포넌트 | 파일 | 책임 |
|---------|------|------|
| Controller | `app/Modules/Auth/Controllers/SnsController.php` | HTTP 진입점. 요청 파싱, 응답 직렬화, 쿠키 설정 |
| Orchestrator Service | `app/Modules/Member/Services/SnsAuthService.php` | 비즈니스 로직 전체. 5대 책임(payload/resolve/status/linkage/token) 분해 |
| Interface | `app/Modules/Member/Interfaces/SnsAuthServiceInterface.php` | DI 계약 — 모듈 간 결합 완화 |
| Factory | `app/Libraries/SnsConnector/SnsConnectorFactory.php` | SNS 타입 → Connector 인스턴스 매핑. 화이트리스트 검증 |
| Connectors | `app/Libraries/SnsConnector/{Apple,Facebook,Google,Kakao,Naver,Line}.php` | OAuth token 교환 + 프로필 조회 |
| Repositories | `SnsRepository.php`, `SnsMetaRepository.php`, `MemberRepository.php` | DB 접근 (QB) |
| Entity | `app/Modules/Member/Entities/Sns.php` | Sns 도메인 객체 (현재 얇은 래퍼) |

### 2.3 Design Rationale

| 설계 결정 | 근거 |
|---------|------|
| **Controller 는 Auth 모듈 + Service 는 Member 모듈** | 라우트 네임스페이스(`/api/sns/*`)는 인증 서브도메인이지만, 실제 비즈니스 로직은 회원 계정 조작이 주. CI4 모듈 소유권 일치 원칙보다 **라우트 prefix 대응성** 우선 |
| **단일 Service 클래스 (834 lines)** | 처음엔 5 클래스로 분해 고려했으나 호출 그래프가 선형(handleCallback → 5단계)이라 분리 시 오히려 파편화. 대신 private 헬퍼로 책임 분해 |
| **Interface 경유 DI** | `SnsAuthServiceInterface` 로 Controller ↔ Service 결합 완화. 테스트에서 Mock 주입 용이 (Unit 테스트 26케이스 구현 근거) |
| **Service Locator (`service()`) 사용** | Controller 는 `service('snsAuthService')` 로 조회. `app/Modules/Member/Config/Services.php` 에 등록 |
| **404 에 payload 포함** | "가입 유도" 플로우에서 프론트가 다시 OAuth 하지 않도록 재활용 가능한 `encryptedSns` 전달. REST 원칙 상 404 body 허용 (RFC 7231 §6.5.4 "MAY be included") |
| **snsCheckNick 1~9999 상한** | 실 운영 중 닉 중복 패턴 분석 — 상위 1% 닉도 20개 미만 충돌 관찰. 상한은 충분. 소진 시 명시적 예외로 무한루프 방지 |
| **Apple 특화 — 단일 getProfile(code)** | Apple id_token 이 response body 내 포함되어 token 교환과 프로필 조회가 1회 호출로 끝남. 타 SNS 는 2회 호출 필수 |

---

## 3. Detailed Design

### 3.1 `handleCallback` 메인 분기

```php
public function handleCallback(array $get, array $clientMeta = []): array
{
    // ① sns_type 화이트리스트
    if ($snsType !== '' && !$connectorFactory->isSupported($snsType))
        return invalidInputResult('INVALID_SNS_TYPE');

    // ② action_type 검증
    if (!in_array($actionType, ['login', 'join'], true))
        return invalidInputResult('INVALID_ACTION_TYPE');

    // ③ payload 획득 (OAuth 또는 data)
    $payload = obtainPayload($get, $snsType, $reason);
    if ($payload === null)
        return invalidInputResult($reason ?? 'MISSING_FIELD');

    // ④ action 별 분기
    return $actionType === 'join'
        ? handleJoinAction($payload, joinFields, $clientMeta)
        : handleLoginAction($payload, $clientMeta);
}
```

**분기 매트릭스**:

| sns_type | action_type | code | data | → |
|----------|-------------|------|------|---|
| 7종 중 1 (≠hongcafe) | 'login'/'join' | 필수 | — | OAuth 경로 |
| `hongcafe` | 'login'/'join' | — | 필수 | data 경로 |
| `''` (미지정) | default 'login' | — | 필수 | v1 호환 경로 |
| 7종 외 | * | * | * | 400 INVALID_SNS_TYPE |
| * | ≠login/join | * | * | 400 INVALID_ACTION_TYPE |

### 3.2 `handleLoginAction` 상세

```
resolveAccount(payload) → userInfo (nullable)
        │
        ▼
checkAccountStatus(userInfo, payload, userInfoByPhone)
        │
        ├── ACTIVE         ──► handleSnsLinkage
        │                        │
        │                        ├── MATCH            ──► issueTokens → 200
        │                        ├── MISMATCH         ──► 409 MISMATCH + linkForm
        │                        └── EXISTING_USER    ──► 409 EXISTING_USER + linkForm
        │
        ├── SUSPENDED/DELETED/BANNED/UNDER_AGE/REJOIN_BLOCKED  ──► 403
        │
        └── null userInfo (미가입)
                                 │
                                 ▼
                        buildEncryptedSnsPayload → calculateExistFlag → trySuggestNick
                                 │
                                 ▼
                        404 + { encryptedSns, existFlag, suggestedAcNick }
```

### 3.3 `handleJoinAction` 상세

```
validate joinFields (cr_phone, country_code, agree_service=1, agree_privacy=1, agree_age=1)
        │
        ├── 누락 있음 ──► 400 MISSING_JOIN_FIELDS + { missing: [...] }
        │
        ▼
baseNick = joinFields['ac_nick'] || extractBaseNick(payload)
        │
        ▼
snsCheckNick(baseNick)
        │
        ├── throws RuntimeException ──► 400 NICK_GENERATION_FAILED
        │
        ▼
MemberRegistrationService::register({ ac_id, ac_nick, ac_sns_id, ac_reg_path, cr_phone, country_code, ac_country? })
        │
        ├── catch code=4006 ──► 403 ACCOUNT_BANNED (existFlag=6)
        ├── catch code=4009 ──► 409 PHONE_EXISTS (existFlag=0)
        ├── other Exception ──► 400 REGISTRATION_FAILED
        │
        ▼
existFlag ∈ {0, 2, 3, 4}
        │
        ├── 4 ──► 409 EMAIL_EXISTS (existFlag=4)
        │
        ▼
userInfo = accountInfo(ac_id)  (이제 존재)
        │
        ▼
issueTokens + insertLoginHistory ──► 200 { acNick, existFlag } + 쿠키 3개
```

### 3.4 `decryptCallbackData` (data 경로 & v1 호환)

입력이 `{ data: base64 }` 또는 평문 `{ ac_id, sns_id, sns_type, issued_at }` 이면 처리:

1. `data` 필드 존재 시 `custom_decrypt()` 호출
   - throws → log + `DECRYPT_FAILED` 반환
   - returns null → log + `DECRYPT_FAILED` 반환
2. `ac_id`, `sns_id` 존재 확인 → 누락 시 `MISSING_FIELD`
3. `sns_type` 화이트리스트 검증 → 불일치 시 `INVALID_SNS_TYPE`
4. `issued_at` numeric 검증 → 결여 시 `PAYLOAD_EXPIRED`
5. 시간 창 검증: `(now - issued_at) ≤ 300` AND `(issued_at - now) ≤ 60`

### 3.5 `snsCheckNick` 알고리즘

```php
function snsCheckNick(baseNick):
    base = sanitizeNick(baseNick)  # strip non-letter/number, trunc 12, fallback 'user'

    if (!isNickTaken(base)):
        return base

    for suffix in 1..9999:
        candidate = base + suffix
        if len(candidate) > 12:
            maxBase = 12 - len(suffix)
            if maxBase < 2: continue
            candidate = base[0..maxBase] + suffix
        if (!isNickTaken(candidate)):
            return candidate

    throw RuntimeException("1~9999 소진")
```

**경계 케이스**:

| base | suffix 시도 | 결과 |
|------|----------|------|
| `user` (4자) | 1~9999 | `user1`, `user2`, …, `user9999` |
| `verylongnick` (12자) | 1 | maxBase=11 → `verylongnic1` |
| `a` (1자 입력) | `sanitizeNick` → `user` | `user1`, `user2`, … |
| `!@#$` (특수문자만) | `sanitizeNick` → `user` | 동일 |
| `철수` (Unicode) | 1 | `철수1` (mb_strlen 으로 Unicode 2자) |

### 3.6 `checkAccountStatus` 의사 코드

```python
if userInfo is None and userInfoByPhone is not None:
    # 060 전환 경로 / 재가입 후보 감지
    ac_status = userInfoByPhone.ac_status
else if userInfo is not None:
    ac_status = userInfo.ac_status
else:
    # 미가입 — ACTIVE 로 통과 (404 처리는 후속 단계)
    return 'ACTIVE'

# Birth 검증 (kakao/naver 한정)
if sns_type in ['kakao', 'naver'] and birthyear + birthday 제공:
    age = calculate_age(birthyear, birthday)
    if age < 19: return 'UNDER_AGE'

match ac_status:
    case 3, 4: return 'ACCOUNT_SUSPENDED'
    case 5:
        if delete_date and (now - delete_date) < 7_days:
            return 'REJOIN_BLOCKED'
        return 'ACCOUNT_DELETED'
    case 6: return 'ACCOUNT_BANNED'
    default: return 'ACTIVE'
```

### 3.7 `handleSnsLinkage` 판단

| userInfo.ac_reg_path | provided sns_type | tb_sns_meta sync | 결과 |
|---------------------|-------------------|------------------|------|
| 동일 (예: kakao → kakao) | 동일 | ok 또는 부재 | MATCH (자동 통과) |
| apple | apple | — | MATCH (Private Relay 예외 — ac_id 불일치 허용) |
| 다름 (예: naver → kakao) | 다름 | `tb_sns_meta.kakao_sync='ok'` | MATCH (이미 동기화된 추가 SNS) |
| 다름 | 다름 | sync 레코드 부재 | EXISTING_USER (연동 동의 필요) |
| 동일 | 동일 | — + ac_id 불일치 | MISMATCH (사용자가 다른 SNS 계정으로 로그인) |

### 3.8 `issueTokens` → Set-Cookie 3개

```
JwtService::createTokenPair(ac_id, cr_code, ac_nick) → { access, refresh, family, jti }
CsrfTokenService::issue() → csrfValue

result = {
  cookies: {
    hc_access:  { value: access,     maxAge: 900,    httpOnly: true },
    hc_refresh: { value: refresh,    maxAge: 604800, httpOnly: true },
    hc_csrf:    { value: csrfValue,  maxAge: 7200,   httpOnly: false },
  },
  flags: {
    isCalleeOnboardingRequired: (userInfo.ce_code is set)
                                 AND (userInfo.ce_status = 0)
                                 AND (userInfo.ce_status0_first_login_date is empty)
  }
}
```

Controller 의 `applyCookies()` 가 각 쿠키를 `Secure=true, SameSite=Lax, path='/'` 로 Set-Cookie 헤더에 직렬화.

### 3.9 Rate Limit 필터 배치

```php
// app/Modules/Auth/Config/Routes.php
$routes->post(
    'sns/receive',
    'SnsController::receive',
    ['filter' => 'ratelimit:10,60'],
);
```

- CI4 내장 `ratelimit` 필터. IP 당 60초 10회.
- 초과 시 필터 레벨에서 429 + `Retry-After` 헤더 설정 → Controller 미진입.

---

## 4. Data Design

### 4.1 주요 테이블

| 테이블 | 용도 |
|--------|------|
| `tb_account` | 회원 기본 정보. `ac_id` PK, `ac_nick` UNIQUE INDEX, `ac_status` ENUM, `delete_date` DATETIME NULL, `ac_reg_path` ENUM(sns_types) |
| `tb_sns_meta` | SNS 동기화 이력. `ac_no` FK + `{sns_type}_sync`, `{sns_type}_sync_date` 컬럼 6쌍 |
| `tb_login_history` | 로그인 이력. `ac_id`, `ac_no`, `sns_type`, `ip`, `user_agent`, `created_at` |
| `tb_account_history` | 계정 상태 변경 이력 (소유권 이전 등) |
| `tb_refresh_token` | JWT Refresh family/jti 관리 (Auth 모듈 소유) |
| `tb_global_country` | country_code 정규화 (D-23 마이그레이션) |

### 4.2 중요 컬럼 제약

- `tb_account.ac_nick` — **UNIQUE INDEX** 필수 (snsCheckNick race 방지)
- `tb_account.delete_date` — D-28 마이그레이션 추가. 탈퇴 시 NOW() 세팅
- `tb_account.ac_reg_path` — ENUM('hongcafe','kakao','naver','apple','facebook','google','line'), default 'hongcafe'

### 4.3 Payload 암호화 포맷

`custom_encrypt(array)` / `custom_decrypt(string)` (`app/Helpers/crypto_helper.php`):

```
plaintext = json_encode({ ac_id, sns_id, sns_type, issued_at, ... })
iv = random_bytes(16)
ciphertext = openssl_encrypt(plaintext, 'AES-256-CBC', $key, OPENSSL_RAW_DATA, $iv)
output = base64_encode(iv || ciphertext)
```

- 키: `$_ENV['encryption.key']` (32 bytes)
- IV: 매 호출마다 새로 생성 (엔트로피 NFR-SNS-004)

---

## 5. Error Mapping Strategy

### 5.1 HTTP Status → Error Code 테이블

| HTTP | 에러 코드 | details.reason | 발생 경로 |
|------|----------|---------------|---------|
| 400 | INVALID_INPUT | INVALID_SNS_TYPE / INVALID_ACTION_TYPE / MISSING_FIELD / DECRYPT_FAILED / PAYLOAD_EXPIRED / OAUTH_EXCHANGE_FAILED / PROFILE_FETCH_FAILED / MISSING_JOIN_FIELDS / NICK_GENERATION_FAILED / REGISTRATION_FAILED / ENCRYPT_FAILED / HONGCAFE_OAUTH_NOT_SUPPORTED | 입력/payload 검증 |
| 403 | FORBIDDEN | ACCOUNT_SUSPENDED / ACCOUNT_DELETED / ACCOUNT_BANNED / UNDER_AGE / REJOIN_BLOCKED | 계정 상태 |
| 404 | NOT_FOUND | (없음. details: encryptedSns, existFlag, suggestedAcNick) | 미가입 — login 전용 |
| 409 | CONFLICT | MISMATCH / EXISTING_USER / EMAIL_EXISTS / PHONE_EXISTS | 링킹 / 중복 |
| 429 | TOO_MANY_REQUESTS | (없음) | Rate Limit |
| 500 | INTERNAL | (없음) | 예기치 않은 예외 |

### 5.2 에러 응답 포맷 (camelCase 통일)

```json
{
  "error": {
    "code": "CONFLICT",
    "message": "...",
    "details": {
      "reason": "MISMATCH",
      "linkForm": { "acId": "user@example.com", "acNo": 100 }
    }
  }
}
```

`BaseApiController::respondError` 가 `toCamelKeys()` 를 `details` 에 자동 적용.

---

## 6. Security Design

### 6.1 Replay Attack 방지

- `issued_at` ±5분 윈도우 (data 경로 전용)
- OAuth 경로는 SNS 제공자의 authorization code 1회성 보장에 위임 (표준 10분 유효)

### 6.2 Rate Limiting

- IP 당 60초 10회. ALB `X-Forwarded-For` 기반 실 클라이언트 IP 식별
- 429 + `Retry-After` 헤더로 자동 재시도 안내

### 6.3 공개 EP 보호

- `AuthFilter EXCLUDED_PATHS` 에 `api/sns/receive` 등록
- `CsrfTokenFilter` 면제 경로 (로그인 전이므로 CSRF 쿠키 없음)
- `ratelimit:10,60` 필터만 적용

### 6.4 민감정보 로깅 금지

- `data` 전문 / `code` 전문 / JWT 토큰 로그 금지
- 디버그 로그에는 `substr($get['data'], 0, 50)` 등 일부만 허용

### 6.5 Apple Private Relay 대응

- Apple 은 앱별 random email 제공 → 재로그인 시 ac_id 변경 가능
- MISMATCH 검증에서 `ac_reg_path === 'apple' && sns_type === 'apple'` 조합 예외 허용 (ac_id 불일치해도 통과)

---

## 7. Performance Design

### 7.1 경로별 응답 시간 설계 목표

| 경로 | 목표 P95 | 주요 지연 요소 |
|------|---------|--------------|
| data 경로 (v1 호환) | 200ms | DB 쿼리 3~4회 + custom_decrypt |
| OAuth 경로 (6종) | 2000ms | SNS 제공자 외부 호출 2회 + DB + 암호화 |

### 7.2 DB 쿼리 최적화

- `accountInfo('ac_id', $email)` — ac_id UNIQUE INDEX 활용
- `isNickTaken($nick)` — ac_nick UNIQUE INDEX 활용 (EXPLAIN 시 ref)
- `SnsMetaRepository::find($acNo)` — ac_no INDEX 활용
- `insertLoginHistory` — 비동기화 여지 (Outbox Pattern 으로 후속 개선 가능)

---

## 8. Verification Matrix (SDD → SRS)

| SDD 섹션 | SRS FR |
|---------|--------|
| §3.1 handleCallback | FR-SNS-001, 002, 011 |
| §3.2 handleLoginAction | FR-SNS-001, 006, 007, 008 |
| §3.3 handleJoinAction | FR-SNS-002 |
| §3.4 decryptCallbackData | FR-SNS-004, 011 |
| §3.5 snsCheckNick | FR-SNS-005 |
| §3.6 checkAccountStatus | FR-SNS-007 |
| §3.7 handleSnsLinkage | FR-SNS-008 |
| §3.8 issueTokens | FR-SNS-009, 012 |
| §3.9 Rate Limit 필터 | FR-SNS-010 |
| §6 Security Design | NFR-SNS-003, 004, 005, 010, 013 |
| §7 Performance Design | NFR-SNS-001, 002 |

---

## 9. 타당성 검토

### 9.1 설계 패턴 근거

- **Strategy Pattern (SnsConnectorFactory)**: GoF "Design Patterns" §3.8. SNS 제공자별 다형성
- **Facade Pattern (SnsAuthService)**: 7단계 내부 로직을 `handleCallback` 하나로 노출
- **Template Method**: OAuth 경로 / data 경로가 `obtainPayload` 에서 통합되고 이후 단계 공유
- **CI4 7.x Services 등록**: 공식 문서 `User_Guide/concepts/services.html` 준수

### 9.2 설계 위험 평가

| 위험 | 완화 |
|------|------|
| SnsAuthService 파일 크기 (834 lines) | private 헬퍼로 분해 완료. 세션 6 에서 5개 책임 세분화 검토됨 |
| `registrationService` nullable | `null` 이면 `REGISTRATION_FAILED` 반환. Services.php 에서 항상 주입되도록 고정 |
| 외부 OAuth 타임아웃 | SnsConnector 내부 cURL timeout 설정. Controller 까지 전파되어 400 변환 |

---

## 10. 변경 영향 기록

### 10.1 변경 사항

- 신규 SDD 문서 v1.0 작성 (SRS 에 대응)

### 10.2 개선 효과

1. 834라인 구현을 6개 내부 단계로 가시화 → 유지보수자가 해당 FR 수정 시 영향 범위 즉시 확인
2. 설계 결정 근거(Design Rationale) 명시 → 향후 재설계 시 맥락 보존
3. 에러 매핑 테이블 단일화 → sns-api.yaml 과 cross-verifiable

### 10.3 수행 이유

1. SRS 만으로는 "어떻게" 가 누락. 실 구현 근거 자료화
2. 세션 7 phpunit 100회 실증 커버리지와 SDD 섹션을 매핑하기 위함

---

## 11. 체크리스트

- [x] IEEE 1016:2009 아키텍처/컴포넌트/상세 설계/데이터 설계/보안/성능/검증 섹션 포함
- [x] SDD → SRS Verification Matrix
- [x] 실 구현 파일 라인 참조 가능 구조
- [x] 설계 결정 근거(Design Rationale) 명시
- [x] 공식 문서 근거 (RFC/GoF/CI4 공식) 제시

---

## 12. 변경 로그

| 날짜 | 버전 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| 2026-04-22 | v1.0 | jypark | 최초 작성 — sns-api v2 SDD |
