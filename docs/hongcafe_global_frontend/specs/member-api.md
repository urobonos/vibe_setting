# Member API

> Member API

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-10 |
| 유형 | report |
| 상태 | 승인됨 |

Base URL: `/api/members`
인증: JWT HttpOnly 쿠키 (`hc_access`)
응답: `{ "data": {...} }` (성공) / `{ "error": { "code": "...", "message": "..." } }` (실패)

---

## 필수 요청 헤더

| 헤더 | 값 | 비고 |
|------|-----|------|
| `X-Forwarded-Proto` | `https` | 모든 요청에 필수. ALB/Nginx 뒤에서 CI4 프로토콜 식별용 |
| `Content-Type` | `application/json` | POST/PUT/DELETE 요청 |
| `X-CSRF-TOKEN` | `{csrfToken}` | POST/PUT/DELETE 요청 (`hc_csrf` 쿠키 값) |

> **CSRF 면제**: 인증이 불필요한 공개 EP(인증 `—`)는 `X-CSRF-TOKEN` 헤더가 불필요합니다.

## JWT 인증

| 항목 | Access Token | Refresh Token |
|------|-------------|--------------|
| 쿠키명 | `hc_access` | `hc_refresh` |
| Max-Age | 900초 (15분) | 604800초 (7일) |
| Path | `/` | `/api/auth/refresh` |
| HttpOnly | `true` | `true` |
| Secure | `true` | `true` |
| SameSite | `Lax` | `Lax` |

- 알고리즘: HMAC-SHA256
- Access Token Payload: `acId`, `crCode`, `acNick`, `type("access")`, `iat`, `exp`
- 인증 우선순위: JWT(`hc_access` 쿠키 전용, Bearer 폴백 없음) → API Key(`X-Api-Key`) → Session(`hdata`, 레거시)

## CSRF 토큰

| 항목 | 값 |
|------|----|
| 방식 | Signed Double Submit Cookie (HMAC-SHA256) |
| 쿠키명 | `hc_csrf` |
| 헤더명 | `X-CSRF-TOKEN` |
| TTL | 7200초 (2시간) |
| HttpOnly | `false` (JS에서 읽어 헤더로 전송) |
| Secure | `true` |
| SameSite | `Lax` |

- 적용 대상: POST, PUT, DELETE (상태 변경 요청)
- 발급 시점: 로그인 성공, Token Refresh 성공

## 환경별 URL

| 환경 | URL |
|------|-----|
| Production | `https://prd.gl.hongcafe.com` |
| Staging | `https://stg.gl.hongcafe.com` |
| Development | `https://dev.gl.hongcafe.com` |

## 비프로덕션 고정 인증번호

| 용도 | 코드 | 비고 |
|------|------|------|
| 회원가입 SMS | `111111` | send-global-cert → confirm-global-cert |
| 아이디/비밀번호 찾기, 번호 변경 SMS | `222222` | find-id-cert, verify-phone |
| 이메일 인증 | `333333` | send-mail-cert → confirm-mail-cert |

> 비프로덕션 환경에서는 외부 SMS/메일 발송을 스킵하고, 위 고정 인증번호를 DB에 저장합니다.

## 필드 검증 정규식

| 필드 | 규칙명 | 정규식 | 설명 |
|------|--------|--------|------|
| acId | `custom_valid_email` | `([0-9a-zA-Z_-]+)@([0-9a-zA-Z_-]+)\.([0-9a-zA-Z_-]+)` | 이메일 형식 (영숫자, _, -) |
| acNick | `japanese_alpha_dash` | `[^\x{30A0}-\x{30FF}\x{3040}-\x{309F}\x{4E00}-\x{9FBF}0-9a-zA-Z_-]` | 일본어(가타카나/히라가나/한자) + 영숫자 + `_` `-` 만 허용. 매칭 시 거부 |
| acNick | `min_length/max_length` | — | 2~12자 |
| acNick | `banned_word` | — (DB 조회) | `tb_ban_word` 테이블 금지어 매칭 시 거부 |
| acNick, acId | `custom_unique` | — (DB 조회) | `tb_account` 테이블 중복 검사 |
| acPassword | `valid_password` | 아래 4개 중 1개 이상 매칭 시 통과 | 8~128자, 2종 이상 조합 필수 |
| | | `^.*(?=^.{8,128}$)(?=.*\d)(?=.*[a-zA-Z]).*$` | 숫자 + 영문 |
| | | `^.*(?=^.{8,128}$)(?=.*\d)(?=.*[!@#$%^&+=]).*$` | 숫자 + 특수문자 |
| | | `^.*(?=^.{8,128}$)(?=.*[a-zA-Z])(?=.*[!@#$%^&+=]).*$` | 영문 + 특수문자 |
| | | `^.*(?=^.{8,128}$)(?=.*\d)(?=.*[a-zA-Z])(?=.*[!@#$%^&+=]).*$` | 숫자 + 영문 + 특수문자 |
| acPhoneNo, crPhone, newPhone | `numeric` | `^\d+$` | 숫자만 허용 |
| acCountry | — | `US`, `JP`, `KR` | 국가 코드 (ISO 3166-1 alpha-2) |
| agreeService, agreePrivacy, agreeAge | `in_list[0,1]` | `^[01]$` | 0 또는 1 |
| birthYear | — | `^\d{4}$` | 4자리 연도 (예: `1992`) |
| birthMonth | — | `^(0[1-9]\|1[0-2])$` | 01~12 |
| birthDay | — | `^(0[1-9]\|[12]\d\|3[01])$` | 01~31 |
| acCertNum | — | `^\d{6}$` | 6자리 숫자 인증번호 |
| mailCertNo | — | `^\d+$` | 숫자 인증번호 |

> **특수문자 허용 범위** (valid_password): `!@#$%^&+=`

## Rate Limit

| 항목 | 값 |
|------|----|
| 적용 범위 | 모든 API 엔드포인트 (`api/*`) |
| 기본 제한 | 60회 / 60초 (IP 기반) |
| 초과 시 | HTTP 429 + `Retry-After` 헤더 |

- 필터 체인: `ratelimit` → `csrftoken` → `auth` → Controller
- 초과 응답: `{ "error": { "code": "TOO_MANY_REQUESTS", "message": "..." } }`

---

## 엔드포인트 목록 (21건)

| # | Method | URL | 인증 | 설명 |
|---|--------|-----|------|------|
| 1 | POST | /api/members/check-id | — | 이메일 ID 중복 확인 |
| 2 | POST | /api/members/check-login-id | — | 이메일 형식 유효성 검사 |
| 3 | POST | /api/members/check-nick | — | 닉네임 유효성+중복 확인 |
| 4 | POST | /api/members/send-global-cert | — | SMS 인증번호 발송 |
| 5 | POST | /api/members/confirm-global-cert | — | SMS 인증번호 검증 |
| 6 | POST | /api/members/join-user | — | 회원가입 |
| 7 | POST | /api/members/login-user | — | 로그인 (JWT+CSRF 쿠키 발급) |
| 8 | POST | /api/members/find-id-cert | — | 아이디 찾기 인증번호 발송 |
| 9 | POST | /api/members/confirm-id-cert | — | 아이디 찾기 인증번호 확인 |
| 10 | POST | /api/members/find-password-cert | — | 비밀번호 찾기 임시 비밀번호 발급 |
| 11 | POST | /api/members/change-passwd | 🔒 jwt | 비밀번호 변경 (현재 비밀번호 검증) |
| 12 | POST | /api/members/reset-password | — | 비밀번호 재설정 |
| 13 | POST | /api/members/setting-alarm | 🔒 jwt | 알람 설정 변경 |
| 14 | POST | /api/members/verify-phone | 🔒 jwt | 번호 변경 인증 발송 |
| 15 | POST | /api/members/update-phone | 🔒 jwt | 번호 변경 실행 |
| 16 | POST | /api/members/change-nick | 🔒 jwt | 닉네임 변경 (7일 제한) |
| 17 | DELETE | /api/members/delete-user | 🔒 jwt | 회원 탈퇴 |
| 18 | POST | /api/members/get-app-version | — | 앱 버전 조회 |
| 19 | POST | /api/members/update-home-set | 🔒 jwt | 홈 화면 설정 |
| 20 | POST | /api/members/send-mail-cert | — | 이메일 인증번호 발송 |
| 21 | POST | /api/members/confirm-mail-cert | — | 이메일 인증번호 확인 |

---

### 1. POST /api/members/check-id
> 인증: 불필요

이메일 형식 계정 ID 사용 가능 여부 확인 (중복 검사 포함)

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acId | `string` | Y | `required\|custom_valid_email\|custom_unique[tb_account.ac_id]` | 이메일 형식 계정 ID |

**예시**:
```json
{ "acId": "test_mo28mgt9_sl4d@example.com" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | acId 누락, 이메일 형식 불일치, 공백 포함 |
| 400 | INVALID_INPUT | 이미 등록된 이메일 (`custom_unique` 위반) |

---

### 2. POST /api/members/check-login-id
> 인증: 불필요

이메일 형식 유효성만 검사 (중복 확인 없음)

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acId | `string` | Y | `required\|custom_valid_email` | 이메일 형식 계정 ID |

**예시**:
```json
{ "acId": "user@example.com" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | acId 누락 또는 이메일 형식 불일치 |

---

### 3. POST /api/members/check-nick
> 인증: 불필요

닉네임 유효성 및 중복 확인

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acNick | `string` | Y | `required\|min_length[2]\|max_length[12]\|japanese_alpha_dash\|banned_word\|custom_unique[tb_account.ac_nick]` | 닉네임 (2~12자, 일본어/영숫자/대시 허용) |
| acId | `string` | N | — | 본인 제외 중복 검사 시 사용 |

**예시**:
```json
{ "acNick": "tstmgt9sl4" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 길이 부족/초과, 허용 문자 위반, 금지어 포함 |
| 400 | INVALID_INPUT | 이미 사용 중인 닉네임 (`custom_unique` 위반) |

---

### 4. POST /api/members/send-global-cert
> 인증: 불필요

SMS 인증번호 발송. 비프로덕션 환경에서는 SMS 미발송, 인증번호 `111111` 고정 저장.

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acCountry | `string` | Y | 국가 코드 (`US`, `JP`, `KR`) |
| acPhoneNo | `string` | Y | 휴대폰 번호 (숫자만, 기본 자릿수+2) |

**예시**:
```json
{ "acCountry": "JP", "acPhoneNo": "0807012345678" }
```

**성공**: HTTP 204 (본문 없음)

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 |
| 409 | CONFLICT | 이미 등록된 번호 |
| 500 | INTERNAL | SMS 발송 실패 |

---

### 5. POST /api/members/confirm-global-cert
> 인증: 불필요

SMS 인증번호 검증 (DB `tb_interphone_auth` 직접 매칭, 5분 TTL)

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acCountry | `string` | Y | 국가 코드 |
| acPhoneNo | `string` | Y | 휴대폰 번호 |
| acCertNum | `string` | Y | 인증번호 (비프로덕션: `111111`) |

**예시**:
```json
{ "acCountry": "JP", "acPhoneNo": "0807012345678", "acCertNum": "111111" }
```

**성공**: HTTP 200

```json
{
  "data": {
    "msg": "Verification successful",
    "crPhone": "0807012345678",
    "crName": "",
    "crIdCert": "Y",
    "crPhoneCert": "Y"
  }
}
```

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 또는 인증번호 불일치 |

---

### 6. POST /api/members/join-user
> 인증: 불필요

신규 회원가입. 국가코드 미전달 시 기본값 `US`.

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acId | `string` | Y | `required\|custom_valid_email\|custom_unique[tb_account.ac_id]` | 이메일 |
| acNick | `string` | Y | `required\|min_length[2]\|max_length[12]\|japanese_alpha_dash\|banned_word\|custom_unique[tb_account.ac_nick]` | 닉네임 |
| crPhone | `string` | Y | `required\|numeric` | 인증 완료된 전화번호 |
| acPassword | `string` | 조건부 | `required\|min_length[8]\|max_length[128]\|valid_password` | 비밀번호 (SNS 가입 시 불필요) |
| acPasswordRe | `string` | 조건부 | `required\|matches[acPassword]` | 비밀번호 확인 |
| agreeService | `int` | Y | `required\|in_list[0,1]` | 서비스 약관 동의 (1=동의) |
| agreePrivacy | `int` | Y | `required\|in_list[0,1]` | 개인정보 처리 동의 (1=동의) |
| agreeAge | `int` | Y | `required\|in_list[0,1]` | 연령 확인 동의 (1=동의) |
| acCountry | `string` | N | — | 국가 코드 (기본값: `US`) |
| birthYear | `string` | N | — | 생년 (4자리) |
| birthMonth | `string` | N | — | 생월 (2자리, 01~12) |
| birthDay | `string` | N | — | 생일 (2자리, 01~31) |
| acRegPath | `string` | N | — | 가입 경로 (기본값: `hongcafe`) |
| acSnsId | `string` | N | — | SNS 계정 ID (SNS 가입 시) |
| snsType | `string` | N | — | SNS 유형 (`google`/`kakao`/`naver`/`facebook`/`apple`/`line`) |

**예시**:
```json
{
  "acId": "test_mo28mgt9_sl4d@example.com",
  "acNick": "tstmgt9sl4",
  "crPhone": "0807012345678",
  "acPassword": "TestPass1234!@",
  "acPasswordRe": "TestPass1234!@",
  "acCountry": "JP",
  "birthYear": "1992",
  "birthMonth": "08",
  "birthDay": "14",
  "agreeService": 1,
  "agreePrivacy": 1,
  "agreeAge": 1,
  "acRegPath": "hongcafe"
}
```

**성공**: HTTP 200

```json
{ "data": { "existFlag": 0 } }
```

| existFlag | 의미 |
|-----------|------|
| 0 | 신규 가입 |
| 3 | 탈퇴 후 재가입 |
| 4 | 이미 등록된 이메일 (SNS 연동) |

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 입력 검증 실패 (이메일/닉네임/비밀번호/약관) |
| 403 | FORBIDDEN | 전화번호 인증 미완료 |
| 403 | FORBIDDEN | 가입 거부된 계정 (`acStatus = 6`) |
| 500 | INTERNAL | 계정 생성 실패 |

---

### 7. POST /api/members/login-user
> 인증: 불필요

로그인. CWE-204 방어 적용 (계정 미존재/비밀번호 불일치 동일 응답)

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acId | `string` | Y | 이메일 |
| acPassword | `string` | Y | 비밀번호 |
| saveId | `string` | N | `"y"` 전달 시 쿠키 30일 유지 (기본 7일) |

**예시**:
```json
{ "acId": "test_mo28mgt9_sl4d@example.com", "acPassword": "TestPass1234!@" }
```

**성공**: HTTP 200

```json
{ "data": { "acHomeSet": "hongcafe" } }
```

**쿠키 발급**: `hdata`(레거시), `hc_access`(15분), `hc_refresh`(7일), `hc_csrf`(2시간)

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 |
| 401 | UNAUTHORIZED | 계정 미존재 또는 비밀번호 불일치 (CWE-204: 동일 응답) |
| 403 | FORBIDDEN | 계정 정지/탈퇴/거부 (`acStatus = 3/5/6`) |

---

### 8. POST /api/members/find-id-cert
> 인증: 불필요

아이디 찾기 인증번호 발송 (KR=카카오 알림톡, 해외=SMS). 비프로덕션: 인증번호 `222222` 고정.

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acCountry | `string` | Y | 국가 코드 (`US`, `JP`, `KR`) |
| crPhone | `string` | Y | 등록된 전화번호 |

**예시**:
```json
{ "acCountry": "US", "crPhone": "1523456789012" }
```

**성공**: HTTP 204 (본문 없음)

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 |
| 403 | FORBIDDEN | 인증 시도 횟수 초과 |
| 404 | NOT_FOUND | 등록된 계정 없음 |
| 500 | INTERNAL | 발송 실패 |

---

### 9. POST /api/members/confirm-id-cert
> 인증: 불필요

아이디 찾기 인증번호 확인 후 마스킹된 ID 반환

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acCountry | `string` | Y | 국가 코드 |
| crPhone | `string` | Y | 전화번호 |
| acCertNum | `string` | Y | 인증번호 (비프로덕션: `222222`) |

**예시**:
```json
{ "acCountry": "US", "crPhone": "1523456789012", "acCertNum": "222222" }
```

**성공**: HTTP 200

```json
{
  "data": {
    "acRegPath": "hongcafe",
    "acId": "te**@example.com",
    "msg": "..."
  }
}
```

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 인증번호 불일치 |
| 403 | FORBIDDEN | 비정상 계정 (`acStatus != 2`) |
| 404 | NOT_FOUND | 등록된 계정 없음 |

---

### 10. POST /api/members/find-password-cert
> 인증: 불필요

비밀번호 찾기 — 임시 비밀번호 발급 (KR=알림톡, 해외=이메일)

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acCountry | `string` | Y | 국가 코드 |
| crPhone | `string` | Y | 등록된 전화번호 |
| acId | `string` | Y | 이메일 |

**예시**:
```json
{ "acCountry": "JP", "crPhone": "0807012345678", "acId": "test@example.com" }
```

**성공**: HTTP 204 (본문 없음). 임시 비밀번호가 SMS 또는 이메일로 발송됨.

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 |
| 403 | FORBIDDEN | 비정상 계정 |
| 404 | NOT_FOUND | 이메일+전화번호 일치 계정 없음 |
| 500 | INTERNAL | 발송 실패 |

---

### 11. POST /api/members/change-passwd
> 인증: 🔒 jwt

현재 비밀번호 검증 후 비밀번호 변경

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acPassword | `string` | Y | `required` | 현재 비밀번호 |
| newPassword | `string` | Y | `required\|min_length[8]\|max_length[128]\|valid_password` | 새 비밀번호 |
| newPasswordRe | `string` | Y | `required\|matches[newPassword]` | 새 비밀번호 확인 |

**예시**:
```json
{ "acPassword": "TestPass1234!@", "newPassword": "NewPass5678!@", "newPasswordRe": "NewPass5678!@" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 입력 검증 실패 |
| 401 | UNAUTHORIZED | 현재 비밀번호 불일치 |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 500 | INTERNAL | 비밀번호 변경 실패 |

---

### 12. POST /api/members/reset-password
> 인증: 불필요

임시 비밀번호로 로그인 후 신규 비밀번호 재설정

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acId | `string` | Y | `required` | 이메일 |
| newPassword | `string` | Y | `required\|min_length[8]\|max_length[128]\|valid_password` | 새 비밀번호 |
| newPasswordRe | `string` | Y | `required\|matches[newPassword]` | 새 비밀번호 확인 |

**예시**:
```json
{ "acId": "test@example.com", "newPassword": "NewPass5678!@", "newPasswordRe": "NewPass5678!@" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 입력 검증 실패 |
| 401 | UNAUTHORIZED | 계정 확인 실패 |
| 500 | INTERNAL | 비밀번호 변경 실패 |

---

### 13. POST /api/members/setting-alarm
> 인증: 🔒 jwt

알람 설정 토글. `"true"` 전달 시 `"N"`, 그 외 `"Y"` 설정

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| type | `string` | Y | 알람 유형 (`sms`, `email`, `noti`) |
| value | `string` | Y | 설정 값 (`"true"` → OFF, 그 외 → ON) |

**예시**:
```json
{ "type": "sms", "value": "false" }
```

**성공**: HTTP 200

```json
{ "data": { "type": "sms", "value": "Y" } }
```

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 500 | INTERNAL | 설정 변경 실패 |

---

### 14. POST /api/members/verify-phone
> 인증: 🔒 jwt

번호 변경 인증 발송. 중복번호/횟수 제한 체크 포함. 비프로덕션: 인증번호 `222222` 고정.

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acCountry | `string` | Y | 국가 코드 (`US`, `JP`, `KR`) |
| newPhone | `string` | Y | 변경할 전화번호 (숫자만) |

**예시**:
```json
{ "acCountry": "KR", "newPhone": "0103306884989" }
```

**성공**: HTTP 204 (본문 없음)

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 403 | FORBIDDEN | 인증 시도 횟수 초과 |
| 409 | CONFLICT | 이미 사용 중인 번호 |
| 500 | INTERNAL | 인증 처리 실패 |

---

### 15. POST /api/members/update-phone
> 인증: 🔒 jwt

인증번호 확인 후 전화번호 변경 실행

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acCountry | `string` | Y | 국가 코드 |
| newPhone | `string` | Y | 변경할 전화번호 |
| acCertNum | `string` | Y | 인증번호 (비프로덕션: `222222`) |

**예시**:
```json
{ "acCountry": "KR", "newPhone": "0103306884989", "acCertNum": "222222" }
```

**성공**: HTTP 204 (본문 없음)

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 또는 인증번호 불일치 |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 403 | FORBIDDEN | 인증 시도 횟수 초과 |
| 409 | CONFLICT | 이미 사용 중인 번호 |
| 500 | INTERNAL | 번호 변경 실패 |

---

### 16. POST /api/members/change-nick
> 인증: 🔒 jwt

닉네임 변경 (마지막 변경 후 7일 경과 필요)

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acNick | `string` | Y | `required\|min_length[2]\|max_length[12]\|japanese_alpha_dash\|banned_word\|custom_unique[tb_account.ac_nick]` | 새 닉네임 |
| acId | `string` | N | — | 본인 제외 중복 검사 시 사용 |

**예시**:
```json
{ "acNick": "newnick2026" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 길이/형식/금지어/중복 위반 |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 403 | FORBIDDEN | 변경 후 7일 미경과 |
| 500 | INTERNAL | 닉네임 변경 실패 |

---

### 17. DELETE /api/members/delete-user
> 인증: 🔒 jwt

회원 탈퇴.

**요청 본문**: 없음

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 401 | UNAUTHORIZED | 로그인 필요 |
| 404 | NOT_FOUND | 계정 미존재 |
| 500 | INTERNAL | 탈퇴 처리 실패 |

---

### 18. POST /api/members/get-app-version
> 인증: 불필요

현재 앱 버전 정보 반환

**요청 본문**: 없음

**성공**: HTTP 200

```json
{ "data": { "appVersion": "1.0.0", "devicerole": "caller" } }
```

---

### 19. POST /api/members/update-home-set
> 인증: 🔒 jwt

홈 화면 설정 변경

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| newHome | `string` | Y | 홈 화면 설정 값 (`hongcafe`, `call` 등) |

**예시**:
```json
{ "newHome": "hongcafe" }
```

**성공**: HTTP 200

```json
{ "data": { "newHomeUrl": "https://..." } }
```

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | newHome 누락 |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 500 | INTERNAL | 설정 변경 실패 |

---

### 20. POST /api/members/send-mail-cert
> 인증: 불필요

이메일 인증번호 발송. 비프로덕션: 메일 미발송, 인증번호 `333333` 고정 저장.

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acId | `string` | Y | 이메일 주소 (미등록 이메일만 허용) |

**예시**:
```json
{ "acId": "test_mo28mgt9_sl4d@example.com" }
```

**성공**: HTTP 204 (본문 없음)

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 이메일 형식 불일치 |
| 400 | INVALID_INPUT | 이미 등록된 이메일 (`custom_unique` 위반) |
| 500 | INTERNAL | 인증번호 저장 실패 |

---

### 21. POST /api/members/confirm-mail-cert
> 인증: 불필요

이메일 인증번호 확인 (TTL 3분)

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| acId | `string` | Y | 이메일 주소 |
| mailCertNo | `string` | Y | 인증번호 (비프로덕션: `333333`) |

**예시**:
```json
{ "acId": "test_mo28mgt9_sl4d@example.com", "mailCertNo": "333333" }
```

**성공**: HTTP 200

```json
{
  "data": {
    "msg": "인증이 완료되었습니다.",
    "certMailAddress": "test_mo28mgt9_sl4d@example.com",
    "crMailCert": "Y"
  }
}
```

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 인증번호 불일치 |
| 400 | INVALID_INPUT | 인증번호 만료 (3분 초과) |

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-10 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
| 2026-04-17 | 테스트 도구 데이터 규칙 반영, 타입 명시, 예시 데이터 추가, 비프로덕션 인증번호 섹션, 이중 해싱 수정 반영 | jypark |
