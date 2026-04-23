---
문서명: SNS Auth API — Interface Design Description
문서 ID: sns-api-idd
버전: v1.0
상태: 승인됨
생성일: 2026-04-22
최종 수정일: 2026-04-22
작성자: jypark
대상 시스템: SNS Auth (`/api/sns/*`)
관련 문서: sns-api-srs.md (v1.0), sns-api-sdd.md (v1.0), sns-api-std.md (v1.0)
적용 표준: IEEE 1016:2009 (Interface Design)
---

# SNS Auth API — Interface Design Description (IDD)

> IEEE 1016:2009 | version: 1.0 | lastUpdated: 2026-04-22

---

## 1. Introduction

### 1.1 Purpose

본 Interface Design Description(IDD)은 `/api/sns/receive` 의 외부(Client) 및 내부(Service 간) 인터페이스 계약을 IEEE 1016:2009 에 따라 기술한다. HTTP API 스펙, Request/Response 스키마, 에러 코드, 쿠키, 외부 SNS 제공자 인터페이스를 포함한다.

### 1.2 Scope

- 외부 HTTP API (Client ↔ HongCafe Backend)
- 내부 서비스 인터페이스 (Controller ↔ Service ↔ Repository)
- 외부 SNS 제공자 인터페이스 (SnsConnector ↔ OAuth 서버)
- 쿠키 계약 (hc_access / hc_refresh / hc_csrf)

### 1.3 References

- OpenAPI 3.0.3 명세: `api-docs/auth/sns-api.yaml` v2.0.0
- 사람이 읽는 명세: `api-docs/auth/sns-api.md`
- SRS: `sns-api-srs.md` v1.0
- SDD: `sns-api-sdd.md` v1.0

---

## 2. External Interface — HTTP API

### 2.1 Endpoint

```
POST /api/sns/receive
External URL (prd):  https://prd.gl.hongcafe.com/__hongcafe_api__/api/sns/receive
External URL (stg):  https://stg.gl.hongcafe.com/__hongcafe_api__/api/sns/receive
External URL (dev):  https://dev.gl.hongcafe.com/__hongcafe_api__/api/sns/receive
Internal URL:        /api/sns/receive (prefix 없이)
```

### 2.2 Required Headers

| 헤더 | 값 | 필수 | 비고 |
|------|-----|------|------|
| `X-Forwarded-Proto` | `https` | ✅ | 모든 환경 필수 — Secure 쿠키 플래그 판단 |
| `Content-Type` | `application/json` | ✅ | POST body 포맷 |
| `X-CSRF-TOKEN` | - | ❌ | 본 EP 는 공개 EP (CSRF 면제) |
| `Authorization` | - | ❌ | 공개 EP (Bearer 폴백 없음) |

### 2.3 Request Body Schema

```yaml
SnsReceiveRequest:
  type: object
  properties:
    sns_type:
      type: string
      enum: [hongcafe, kakao, naver, apple, facebook, google, line]
      description: SNS 제공자. 미지정 시 v1 호환 경로
    action_type:
      type: string
      enum: [login, join]
      default: login
    code:
      type: string
      description: OAuth authorization code (sns_type != hongcafe 시 필수)
    state:
      type: string
      description: CSRF state (선택)
    data:
      type: string
      description: AES-256-CBC 암호화 payload (base64). hongcafe / v1 경로
    cr_phone:
      type: string
      description: 국가번호 포함 (예 '821012345678'). action=join 필수
    country_code:
      type: string
      description: ISO 3166-1 alpha-2. action=join 필수. NULL 시 'US'
    ac_nick:
      type: string
      minLength: 2
      maxLength: 12
    ac_country:
      type: string
    agree_service:
      type: integer
      enum: [0, 1]
      description: action=join 필수 (1=동의)
    agree_privacy:
      type: integer
      enum: [0, 1]
    agree_age:
      type: integer
      enum: [0, 1]
```

### 2.4 Response — 200 Success

**action_type=login 성공**:

```json
{
  "data": null,
  "meta": {
    "isCalleeOnboardingRequired": false
  }
}
```

**action_type=join 성공**:

```json
{
  "data": {
    "acNick": "kakaoUser7",
    "existFlag": 0
  },
  "meta": {
    "isCalleeOnboardingRequired": false
  }
}
```

### 2.5 Response — 400 INVALID_INPUT

| details.reason | 트리거 | message |
|--------------|--------|---------|
| `INVALID_SNS_TYPE` | sns_type 화이트리스트 외 | "지원되지 않는 SNS 유형입니다." |
| `INVALID_ACTION_TYPE` | action_type ≠ login/join | "요청이 올바르지 않습니다." |
| `MISSING_FIELD` | ac_id/sns_id 누락 | "SNS 로그인 정보를 확인할 수 없습니다..." |
| `DECRYPT_FAILED` | `data` 복호화 실패 | 동일 |
| `PAYLOAD_EXPIRED` | issued_at ±5분 초과 | "SNS 로그인 정보가 만료되었습니다..." |
| `OAUTH_EXCHANGE_FAILED` | SnsConnector token 교환 실패 | "요청이 올바르지 않습니다." |
| `PROFILE_FETCH_FAILED` | SnsConnector profile 조회 실패 | 동일 |
| `MISSING_JOIN_FIELDS` | 가입 필수 필드 누락 | "가입에 필요한 정보가 누락되었습니다." (+ `missing: string[]`) |
| `NICK_GENERATION_FAILED` | snsCheckNick 1~9999 소진 | "사용 가능한 닉네임 생성에 실패했습니다." |
| `REGISTRATION_FAILED` | register 내부 예외 | "가입 처리에 실패했습니다." |
| `ENCRYPT_FAILED` | 404 payload 암호화 실패 | 로그 전용 |
| `HONGCAFE_OAUTH_NOT_SUPPORTED` | hongcafe 에 code 전달 | "요청이 올바르지 않습니다." |

### 2.6 Response — 403 FORBIDDEN

| details.reason | ac_status | message |
|--------------|-----------|---------|
| `ACCOUNT_SUSPENDED` | 3, 4 | "현재 이용중지된 회원입니다.\n고객센터로 문의 주세요." |
| `ACCOUNT_DELETED` | 5 (+ delete_date > 7일) | "탈퇴한 회원입니다." |
| `ACCOUNT_BANNED` | 6 | "강제 탈퇴 처리된 회원입니다.\n고객센터로 문의 주세요." (+ `existFlag: 6` — join 시) |
| `UNDER_AGE` | — | "만 19세 미만은 가입할 수 없습니다." |
| `REJOIN_BLOCKED` | 5 (+ delete_date ≤ 7일) | "탈퇴한 회원입니다. 회원탈퇴 후 7일 뒤 회원가입 가능합니다." |

### 2.7 Response — 404 NOT_FOUND (login 전용)

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "SNS 계정에 해당하는 회원이 없습니다. 가입을 진행해 주세요.",
    "details": {
      "encryptedSns": "base64-encrypted-sns-payload",
      "existFlag": 0,
      "suggestedAcNick": "kakaoUser7"
    }
  }
}
```

### 2.8 Response — 409 CONFLICT

| details.reason | 트리거 | details 추가 필드 |
|--------------|--------|-------------------|
| `MISMATCH` | 기존 회원 ac_id 불일치 (Apple 재로그인 제외) | `linkForm: { acId, acNo }` |
| `EXISTING_USER` | 다른 SNS/자체 가입자 + sync 미설정 | `linkForm: { acId, acNo, newRegPath, crCode, crPhone }` |
| `EMAIL_EXISTS` | join 시 email 중복 | `existFlag: 4` |
| `PHONE_EXISTS` | join 시 phone 중복 | `existFlag: 0` |

### 2.9 Response — 429 TOO_MANY_REQUESTS

```json
{
  "error": {
    "code": "TOO_MANY_REQUESTS",
    "message": "요청 한도를 초과하였습니다. 잠시 후 다시 시도해 주세요."
  }
}
```

Headers: `Retry-After: <seconds>`

### 2.10 Response — 500 INTERNAL

```json
{
  "error": {
    "code": "INTERNAL",
    "message": "서버 오류가 발생했습니다."
  }
}
```

### 2.11 Set-Cookie (200 성공 시 3개)

| Cookie | Value | Max-Age | HttpOnly | Secure | SameSite | Path |
|--------|-------|---------|----------|--------|----------|------|
| `hc_access` | JWT Access (HMAC-SHA256) | 900 | ✅ | ✅ | Lax | `/` |
| `hc_refresh` | JWT Refresh (family+jti) | 604800 | ✅ | ✅ | Lax | `/` |
| `hc_csrf` | HMAC-SHA256 서명 값 | 7200 | ❌ | ✅ | Lax | `/` |

### 2.12 Response 네이밍 정책

- `data.*` → **camelCase** (`respondSuccessWithMeta` 자동 변환)
- `meta.*` → **camelCase**
- `error.code` → **UPPER_SNAKE_CASE** (표준 에러 코드)
- `error.details.*` → **camelCase** (`BaseApiController::respondError` + `toCamelKeys` 자동)

---

## 3. Internal Interface — SnsAuthServiceInterface

### 3.1 Interface 정의

```php
namespace App\Modules\Member\Interfaces;

interface SnsAuthServiceInterface
{
    /**
     * SNS 콜백 메인 진입점.
     *
     * @param array $get { sns_type, action_type, code, state, data, cr_phone, country_code, ac_nick, ac_country, agree_service, agree_privacy, agree_age }
     * @param array $clientMeta { ip, user_agent }
     * @return array {
     *   status: 'success' | 'error',
     *   http_code?: int,        // error only
     *   error_code?: string,    // error only
     *   message?: string,       // error only
     *   details?: array,        // error only
     *   cookies?: array,        // success only
     *   data?: array | null,    // success only
     *   meta?: array,           // success only
     * }
     */
    public function handleCallback(array $get, array $clientMeta = []): array;

    // data 경로 복호화 진입점 (v1 호환 테스트용)
    public function decryptCallbackData(array $get, ?string &$reason = null): ?array;

    // 계정 조회 + snsPhone 해석
    public function resolveAccount(array $data): array;

    // 계정 상태 판단 ('ACTIVE' | 'ACCOUNT_*' | 'UNDER_AGE' | 'REJOIN_BLOCKED')
    public function checkAccountStatus(?array $userInfo, array $data, ?array $userInfoByPhone = null): string;

    // 링킹 판단 ('MATCH' | 'MISMATCH' | 'EXISTING_USER')
    public function handleSnsLinkage(array $userInfo, array $data): array;

    // JWT 발급 + CSRF 발급 + cookies/flags 반환
    public function issueTokens(array $userInfo): array;

    // OAuth 경로 — SnsConnector 호출 + profile 반환 or reason 설정
    public function resolveFromOAuthCode(string $snsType, string $code, ?string &$reason = null): ?array;

    // 닉 자동 증가 (or throws RuntimeException)
    public function snsCheckNick(string $baseNick): string;

    // action=login 흐름 진입 (내부 재사용)
    public function handleLoginAction(array $payload, array $clientMeta = []): array;

    // action=join 흐름 진입 (내부 재사용)
    public function handleJoinAction(array $payload, array $joinFields, array $clientMeta = []): array;
}
```

### 3.2 DI 등록

```php
// app/Modules/Member/Config/Services.php
public static function snsAuthService($getShared = true): SnsAuthServiceInterface
{
    if ($getShared) {
        return static::getSharedInstance('snsAuthService');
    }
    return new SnsAuthService(
        service('memberRepository'),
        service('snsMetaRepository'),
        service('countryRepository'),
        service('jwtService'),
        service('csrfTokenService'),
        service('memberRegistrationService'),
        new SnsConnectorFactory(),
    );
}
```

### 3.3 Controller ↔ Service 계약

```php
// SnsController::receive
$result = $this->snsAuthService->handleCallback($payload, $clientMeta);

if ($result['status'] === 'success') {
    $this->applyCookies($result['cookies']);
    return $this->respondSuccessWithMeta($result['data'] ?? null, $result['meta']);
}

return $this->respondError(
    $result['error_code'],
    $result['message'],
    $result['http_code'],
    $result['details'] ?? []
);
```

---

## 4. External Interface — SNS Providers

### 4.1 Kakao

| 단계 | HTTP | URL | 필수 파라미터 |
|------|------|-----|--------------|
| Token 교환 | POST | `https://kauth.kakao.com/oauth/token` | grant_type=authorization_code, client_id, client_secret, code, redirect_uri |
| Profile 조회 | GET | `https://kapi.kakao.com/v2/user/me` | Authorization: Bearer {access_token} |

**프로필 응답 파싱**: `kakao_account.email` → `email`, `id` → `sns_id`, `properties.nickname` → `kakao_nick_name`

### 4.2 Naver

| 단계 | URL |
|------|-----|
| Token 교환 | `https://nid.naver.com/oauth2.0/token` |
| Profile | `https://openapi.naver.com/v1/nid/me` |

**필드**: `response.email` → `email`, `response.id` → `sns_id`, `response.nickname` → `naver_nick_name`, `response.birthyear`/`birthday` (선택)

### 4.3 Apple

| 단계 | URL |
|------|-----|
| Token 교환 + Profile 통합 | `https://appleid.apple.com/auth/token` |
| Client Secret JWT (ES256) | Private Key (`config/certs/AuthKey_{KEY_ID}.p8`) 로 내부 생성 |

**id_token 파싱**: JWT payload `email` + `sub` → `sns_id`

### 4.4 Facebook

| 단계 | URL |
|------|-----|
| Token 교환 | `https://graph.facebook.com/v{N}/oauth/access_token` |
| Profile | `https://graph.facebook.com/me?fields=id,email,name` |

### 4.5 Google

| 단계 | URL |
|------|-----|
| Token 교환 | `https://oauth2.googleapis.com/token` |
| Profile | `https://www.googleapis.com/oauth2/v2/userinfo` |

### 4.6 LINE

| 단계 | URL |
|------|-----|
| Token 교환 | `https://api.line.me/oauth2/v2.1/token` |
| Profile | `https://api.line.me/v2/profile` |

---

## 5. Repository Interfaces (내부)

### 5.1 MemberRepository (소비 메서드)

```php
accountInfo(string $key, string $value): ?array
isNickTaken(string $nick): bool
updateLastlogin(string $acId): bool
insertLoginHistory(string $acId, string $acNo, string $snsType, string $ip, string $ua): bool
```

### 5.2 SnsMetaRepository

```php
find(int $acNo): ?array
insertOrUpdate(int $acNo, string $snsType, array $meta): bool
```

### 5.3 CountryRepository

```php
findByCode(string $code): ?array  // ISO 3166-1 alpha-2
```

### 5.4 MemberRegistrationService

```php
register(array $data): array  // returns { exist_flag: int, ac_no?: int, ... }
                              // throws Exception with code ∈ { 4006, 4009, ... }
```

---

## 6. Cookie Protocol Detail

### 6.1 hc_access

```
Name:     hc_access
Value:    <base64url>.<base64url>.<hmac_sha256>
          (JWT header.payload.signature)
Max-Age:  900
Domain:   (omit → current host)
Path:     /
HttpOnly: true
Secure:   true
SameSite: Lax
```

**Payload**:
```json
{ "ac_id": "user@example.com", "cr_code": "CR-...", "ac_nick": "hongcafeUser", "type": "access", "iat": 1776845442, "exp": 1776846342 }
```

### 6.2 hc_refresh

```
Max-Age:  604800
Path:     /
HttpOnly: true
```

**Payload**:
```json
{ "ac_id": "...", "type": "refresh", "jti": "<uuid>", "family": "<uuid>", "iat": 1776845442, "exp": 1777450242 }
```

### 6.3 hc_csrf

```
Max-Age:  7200
Path:     /
HttpOnly: false    (JS 가 헤더로 전송해야 함)
Secure:   true
SameSite: Lax
```

**Value format**: `<random-uuid>.<hmac_sha256(random-uuid)>` — Signed Double Submit Cookie

---

## 7. v1 → v2 호환성 계약

### 7.1 하위 호환

| v1 호출 | v2 동작 |
|---------|---------|
| `{ data: "..." }` | `sns_type=''` + `action_type='login'` 기본값 → data 경로 실행 |
| `{ data: "...", sns_type: "kakao" }` | data 경로 실행 (OAuth code 없음) |

### 7.2 신규 기능 (opt-in)

| v2 호출 | 조건 |
|---------|------|
| `{ sns_type, action_type: 'login', code }` | OAuth 경로 (Apple/Kakao/...) |
| `{ sns_type, action_type: 'join', code, cr_phone, country_code, agree_* }` | OAuth + 가입 통합 |

### 7.3 응답 Shape 변화

- v1: `{ data: null }` (meta 없음)
- v2: `{ data: null, meta: { isCalleeOnboardingRequired: bool } }` — meta 추가 (하위 호환 유지)

---

## 8. 타당성 검토

### 8.1 OpenAPI 3.0.3 준수

- 본 IDD 는 `api-docs/auth/sns-api.yaml` 의 모든 스키마/에러/examples 를 커버
- OpenAPI 3.0.3 spec: `https://spec.openapis.org/oas/v3.0.3`
- Tools: Swagger UI 렌더링 확인 + redoc 호환

### 8.2 CI4 7.x API 준수

- `$routes->post()` + `['filter' => 'ratelimit:10,60']` — 공식 문서 `User_Guide/incoming/routing.html`
- `ResourceController::respond` 응답 포맷 준수

---

## 9. 변경 영향 기록

### 9.1 변경 사항

- 신규 IDD v1.0 작성

### 9.2 개선 효과

1. 외부/내부 인터페이스를 단일 문서로 통합 — 프론트/서비스 개발자 진입 장벽 완화
2. OpenAPI YAML 과 IDD 의 차이를 제거 (공식 Interface 계약은 IDD SSOT)
3. 쿠키/헤더 프로토콜 명세 — 보안 감사 용이

### 9.3 수행 이유

1. 프로젝트 지침: `docs/specs/{BC}-idd.md` 필수
2. API 명세(MD/YAML) 와 IEEE IDD 의 포지셔닝 분리 (계약 vs 설계 계약)

---

## 10. 체크리스트

- [x] HTTP 외부 API (Request/Response/Status Code/Cookies)
- [x] Internal Service Interface (Interface + DI 등록)
- [x] External SNS Provider (6종 Connector 상세)
- [x] Repository Interface (MemberRepo/SnsMeta/Country/Registration)
- [x] Cookie Protocol (hc_access/hc_refresh/hc_csrf 필드별)
- [x] v1 → v2 호환성 계약
- [x] OpenAPI 3.0.3 Yaml 과 cross-verifiable

---

## 11. 변경 로그

| 날짜 | 버전 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| 2026-04-22 | v1.0 | jypark | 최초 작성 — sns-api v2 IDD (외부 HTTP + 내부 Interface + 6 SNS Connector + 쿠키) |
