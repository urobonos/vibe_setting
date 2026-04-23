# Profile API

> Profile API

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-10 |
| 유형 | report |
| 상태 | 승인됨 |

Base URL: `/api/profile`
인증: 모든 EP JWT 필수 (`hc_access` 쿠키)
응답: `{ "data": {...} }` (성공) / `{ "error": { "code": "...", "message": "..." } }` (실패)

---

## 필수 요청 헤더

| 헤더 | 값 | 비고 |
|------|-----|------|
| `X-Forwarded-Proto` | `https` | 모든 요청에 필수. ALB/Nginx 뒤에서 CI4 프로토콜 식별용 |
| `Content-Type` | `application/json` | POST/PUT/DELETE 요청 |
| `X-CSRF-TOKEN` | `{csrfToken}` | POST/PUT/DELETE 요청 (`hc_csrf` 쿠키 값) |

> GET 요청은 CSRF 검증 생략

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

## 환경별 URL

| 환경 | URL |
|------|-----|
| Production | `https://prd.gl.hongcafe.com` |
| Staging | `https://stg.gl.hongcafe.com` |
| Development | `https://dev.gl.hongcafe.com` |

## 필드 검증 정규식

| 필드 | 규칙명 | 정규식 | 설명 |
|------|--------|--------|------|
| acNick | `min_length/max_length` | — | 2~12자 |
| currentPassword | `required` | — | 필수 |
| newPassword | `min_length/max_length` | — | 8~128자 |
| newPasswordRe | `matches[newPassword]` | — | newPassword와 일치 |
| snsType | `in_list` | `^(google\|kakao\|naver\|facebook\|apple\|line)$` | 6종 SNS 유형 |
| acSnsId | `required` | — | 필수 |
| type (history) | — | `^(counsel\|coin\|payment)$` | 내역 유형 |
| limit (history) | — | `^\d+$` | 페이지당 항목 수 (기본 20) |

## Rate Limit

| 항목 | 값 |
|------|----|
| 적용 범위 | 모든 API 엔드포인트 (`api/*`) |
| 기본 제한 | 60회 / 60초 (IP 기반) |
| 초과 시 | HTTP 429 + `Retry-After` 헤더 |

- 필터 체인: `ratelimit` → `csrftoken` → `auth` → Controller
- 초과 응답: `{ "error": { "code": "TOO_MANY_REQUESTS", "message": "..." } }`

---

## 엔드포인트 목록 (8건)

| # | Method | URL | 인증 | 설명 |
|---|--------|-----|------|------|
| 1 | GET | /api/profile | 🔒 jwt | 내 프로필 조회 |
| 2 | PUT | /api/profile | 🔒 jwt | 프로필 수정 |
| 3 | PUT | /api/profile/password | 🔒 jwt | 비밀번호 변경 |
| 4 | DELETE | /api/profile | 🔒 jwt | 회원 탈퇴 |
| 5 | GET | /api/profile/coin | 🔒 jwt | 코인 잔액 요약 |
| 6 | POST | /api/profile/link-sns | 🔒 jwt | SNS 연동 |
| 7 | POST | /api/profile/unlink-sns | 🔒 jwt | SNS 연동 해제 |
| 8 | GET | /api/profile/history | 🔒 jwt | 이용 내역 |

---

### 1. GET /api/profile
> 인증: 🔒 jwt

JWT 토큰 기반 내 프로필 정보 조회

**파라미터**: 없음 (JWT의 `acId` 사용)

**성공**: HTTP 200

```json
{
  "data": {
    "acId": "test_mo28mgt9_sl4d@example.com",
    "acNick": "tstmgt9sl4",
    "crCode": "CR-20260417013914-813",
    "crPhone": "0807012345678",
    "countryCode": "US",
    "acRemainCoin": 500,
    "acRemainFreeCoin": 200,
    "acRemainPayCoin": 300,
    "acHomeSet": "hongcafe",
    "acSmsCf": "Y",
    "acEmailCf": "Y",
    "acNotiCf": "Y",
    "acRegPath": "hongcafe",
    "registDate": "2026-04-17 01:39:14",
    "lastLoginDate": "2026-04-17 02:26:41"
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| acId | `string` | 이메일 |
| acNick | `string` | 닉네임 |
| crCode | `string` | 고객 코드 |
| crPhone | `string` | 전화번호 |
| countryCode | `string` | 국가 코드 (`US`, `JP`, `KR`) |
| acRemainCoin | `integer` | 총 잔여 코인 |
| acRemainFreeCoin | `integer` | 무료 코인 잔액 |
| acRemainPayCoin | `integer` | 유료 코인 잔액 |
| acHomeSet | `string` | 홈 화면 설정 (`hongcafe`, `call` 등) |
| acSmsCf | `string` | SMS 알림 설정 (`Y`/`N`) |
| acEmailCf | `string` | 이메일 알림 설정 (`Y`/`N`) |
| acNotiCf | `string` | 푸시 알림 설정 (`Y`/`N`) |
| acRegPath | `string` | 가입 경로 (`hongcafe`/`google`/`kakao`/`naver`/`facebook`/`apple`/`line`) |
| registDate | `string` | 가입 일시 (UTC) |
| lastLoginDate | `string` | 최근 로그인 일시 (UTC) |

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 401 | UNAUTHORIZED | 로그인 필요 |
| 404 | NOT_FOUND | 계정 미존재 |

---

### 2. PUT /api/profile
> 인증: 🔒 jwt

프로필 정보 수정 (최소 1개 필드 필수). 허용 필드 외 전달 시 무시됨 (화이트리스트 방식).

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| acNick | `string` | N | `min_length[2]\|max_length[12]` | 닉네임 (옵션) |
| acHomeSet | `string` | N | — | 홈 화면 설정 (옵션) |
| acSmsCf | `string` | N | — | SMS 알림 `Y`/`N` (옵션) |
| acEmailCf | `string` | N | — | 이메일 알림 `Y`/`N` (옵션) |
| acNotiCf | `string` | N | — | 푸시 알림 `Y`/`N` (옵션) |

**예시**:
```json
{ "acNick": "newnick2026", "acHomeSet": "call" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 수정 가능한 필드 없음 또는 검증 실패 |
| 401 | UNAUTHORIZED | 로그인 필요 |

---

### 3. PUT /api/profile/password
> 인증: 🔒 jwt

현재 비밀번호 확인 후 새 비밀번호로 변경

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| currentPassword | `string` | Y | `required` | 현재 비밀번호 |
| newPassword | `string` | Y | `required\|min_length[8]\|max_length[128]` | 새 비밀번호 |
| newPasswordRe | `string` | Y | `required\|matches[newPassword]` | 새 비밀번호 확인 |

**예시**:
```json
{ "currentPassword": "TestPass1234!@", "newPassword": "NewPass5678!@", "newPasswordRe": "NewPass5678!@" }
```

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 검증 실패 (길이, 형식, 불일치) |
| 401 | UNAUTHORIZED | 현재 비밀번호 불일치 또는 로그인 필요 |

---

### 4. DELETE /api/profile
> 인증: 🔒 jwt

회원 탈퇴. 성공 시 `hc_access`/`hc_refresh` 쿠키 즉시 만료 처리.

**요청 본문**: 없음

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 401 | UNAUTHORIZED | 로그인 필요 |
| 500 | INTERNAL | 탈퇴 처리 실패 |

---

### 5. GET /api/profile/coin
> 인증: 🔒 jwt

코인 잔액 및 사용 통계 요약

**파라미터**: 없음

**성공**: HTTP 200

```json
{
  "data": {
    "remainCoin": 500,
    "remainFreeCoin": 200,
    "remainPayCoin": 300,
    "totalCharged": 10000,
    "totalUsed": 9500,
    "totalRefunded": 0
  }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| remainCoin | `integer` | 총 잔여 코인 |
| remainFreeCoin | `integer` | 무료 코인 잔액 |
| remainPayCoin | `integer` | 유료 코인 잔액 |
| totalCharged | `integer` | 총 충전 코인 |
| totalUsed | `integer` | 총 사용 코인 |
| totalRefunded | `integer` | 총 환불 코인 |

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 401 | UNAUTHORIZED | 로그인 필요 |
| 404 | NOT_FOUND | 계정 미존재 |

---

### 6. POST /api/profile/link-sns
> 인증: 🔒 jwt

SNS 계정 연동. 이미 다른 SNS가 연동된 경우 불가.

**요청 본문**:

| 필드 | 타입 | 필수 | 검증 규칙 | 설명 |
|------|------|------|-----------|------|
| snsType | `string` | Y | `required\|in_list[google,kakao,naver,facebook,apple,line]` | SNS 유형 |
| acSnsId | `string` | Y | `required` | SNS 계정 ID |

**예시**:
```json
{ "snsType": "google", "acSnsId": "test_sns_mo28mgt9" }
```

**성공**: HTTP 200

```json
{ "data": { "snsType": "google" } }
```

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | 필수 파라미터 누락 또는 유효하지 않은 snsType |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 404 | NOT_FOUND | 계정 미존재 |
| 409 | CONFLICT | 이미 SNS 연동됨 |

---

### 7. POST /api/profile/unlink-sns
> 인증: 🔒 jwt

SNS 연동 해제. 비밀번호 미설정(SNS 전용) 계정은 해제 불가.

**요청 본문**: 없음

**성공**: HTTP 200 `[]`

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 400 | INVALID_INPUT | SNS 연동 없음 |
| 401 | UNAUTHORIZED | 로그인 필요 |
| 403 | FORBIDDEN | SNS 전용 계정 (비밀번호 미설정) |
| 404 | NOT_FOUND | 계정 미존재 |

---

### 8. GET /api/profile/history
> 인증: 🔒 jwt

이용 내역 조회 (상담/코인/결제 유형별)

**Query 파라미터**:

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| type | `string` | N | `counsel` | 내역 유형 (`counsel`/`coin`/`payment`) |
| limit | `integer` | N | `20` | 페이지당 항목 수 |
| offset | `integer` | N | `0` | 시작 오프셋 |
| term | `integer` | N | `3` | 조회 기간 (월 단위) |

**예시**:
```
GET /api/profile/history?type=coin&limit=10&offset=0&term=6
```

**성공**: HTTP 200

```json
{ "data": [ ... ] }
```

**에러**:

| HTTP | 코드 | 조건 |
|------|------|------|
| 401 | UNAUTHORIZED | 로그인 필요 |

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-10 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
| 2026-04-17 | 타입 백틱 표기, 예시 데이터 추가, 정규식 섹션, 401 에러 추가, 코드 기반 검증 | jypark |
