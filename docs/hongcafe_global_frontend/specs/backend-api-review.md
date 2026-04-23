# Backend API 리뷰 — auth-api.yaml + member-api.yaml

| 항목 | 내용 |
|------|------|
| 작성자 | 명우현 |
| 작성일 | 2026-04-13 |
| 버전 | v2.2 |
| 상태 | Review (백엔드 회신 대기) |
| 대상 독자 | 백엔드 (API 설계자) |
| 대상 스펙 | `auth-api.yaml` v1.0.0 (8 EP) + `member-api.yaml` v1.0.0 (44 EP) — 2026-04-13 2차 수령 |
| 비교축 | FFS 15 도메인, as-is (`hongcafe-japan` CI4), 현 프론트 구현(`lib/auth.js`), v2.0 초안 + v2.1 1차 업데이트 검토 |
| 근거 기준 | OpenAPI Specification 3.0.3, RFC 3986 (URI), RFC 6265bis (Cookies), RFC 6750 (Bearer Token), RFC 6819 (OAuth Threat Model), RFC 8725 (JWT BCP), OWASP API Security Top 10 (2023), OWASP ASVS 4.0.3, OWASP Authentication Cheat Sheet, OWASP CSRF Prevention Cheat Sheet, NIST SP 800-63B, CWE, Google AIP-121/122/135 |

---

## 0. 2026-04-13 2차 업데이트 반영 현황

v2.1 리뷰 이후 백엔드가 두 스펙을 재갱신. 이번 업데이트의 주요 변화:

- **auth-api.yaml**: servers URL을 `http://dev.gl.hongcafe.com` → `https://gl.hongcafe.com`(Production)로 전환. 보안 스키마를 `cookieAuth` → `bearerAuth`로 변경. `X-CSRF-TOKEN` 헤더를 모든 write EP에 정식 요구. `/api/gate`, `/api/whoami` 2개 GET EP 추가.
- **member-api.yaml**: `X-CSRF-TOKEN` 헤더를 모든 POST EP에 정식 요구. 그 외 무변경.

### 0-1. 반영 완료 — 누적 7건

<table>

| v2.0/v2.1 지적 | 반영 내용 | 반영 시점 |
|---|---|---|
| §3-1 SMS confirm | `/api/member/ConfirmGlobalCert` | v2.1 |
| §3-2 Email confirm | `/api/member/confirmMailCert` | v2.1 |
| §3-3 이메일 중복 확인 | `/api/member/CheckId` | v2.1 |
| §3-4 닉네임 중복 확인 | `/api/member/CheckNick` | v2.1 |
| §3-5 아이디 찾기 | `/api/member/FindIdCert` + `ConfirmIdCert` | v2.1 |
| §8-6 servers URL 불일치 | auth-api가 `https://gl.hongcafe.com` 로 전환 — 양쪽 일치 | **v2.2** |
| (v2.0/v2.1 미지적) CSRF 보호 | 양쪽 스펙에 `X-CSRF-TOKEN` 헤더 파라미터 정식 추가 | **v2.2** (선제적 개선) |

</table>

### 0-2. 부분 반영 (2건)

- **§3-6 비밀번호 재설정**: `FindPasswordCert`(인증번호 발송)는 있으나 실제 재설정 엔드포인트 없음.
- **§4-1 생년월일·약관**: `JoinUser`에 `birthYear/birthMonth/birthDay` (string) 있음 / `agree_service/agree_privacy/agree_age` **여전히 누락**.

### 0-3. 미반영 (11건)

- §4-2 verify_token 토큰 기반 인증 핸드오프
- §4-3 `/api/auth/refresh` security scheme (여전히 `security` 미선언)
- §4-4 refresh token rotation 정책
- §4-5 쿠키 이름 표준 — **§8-1로 변형**: auth-api가 `bearerAuth`로 명칭만 변경되어 이원화 외관은 해소됐으나, description이 "HttpOnly 쿠키 hc_access"로 기재되고 X-CSRF-TOKEN을 요구하므로 실제는 여전히 쿠키 기반. 프론트 `hc_token` ↔ 스펙 `hc_access` 불일치 그대로.
- §5-1 로그인 계정 열거 공격 (401/404 분기 그대로)
- §5-2 SMS/Email 엔드포인트 rate-limit + CAPTCHA (OTP 발송 EP 6종 전부 여전)
- §5-3 쿠키 속성 정의 (HttpOnly 외 Secure/SameSite/Max-Age/Domain 미정의)
- §5-4 OTP 응답 본문 노출 금지 명시 (member-api는 여전히 응답 스키마 자체가 없음)
- §5-5 비밀번호 정책 (`ChangePasswd`에도 길이 제약 전무)
- §5-6 에러 응답 스키마 (member-api 44 EP 전부 `"200: 성공"`만 정의)
- §5-7 탈퇴 실패 사유 구조화 (`DeleteUser` 응답 전무)
- §6-1 `operationId` (14 → 52 EP 전수 누락)
- §6-3 전화번호 필드명 3종 혼재

### 0-4. 2차 업데이트에서 새로 드러난 이슈 (3건)

1. **N-8 (Critical) — auth-api.yaml YAML 중복 키 버그**: `components.parameters:` 키가 L285와 L295에 두 번 정의되어 YAML 파싱 시 `XForwardedProto` 정의가 소실. 모든 `$ref: "#/components/parameters/XForwardedProto"` 참조가 깨짐. Spectral이 `invalid-ref` + `parser` error 보고.
2. **N-9 (High) — `bearerAuth` 선언과 쿠키 기반 구현의 모순**: auth-api `securitySchemes.bearerAuth`가 `type: http, scheme: bearer`로 선언되었으나 description은 "JWT Access Token (HttpOnly 쿠키 hc_access)". **OpenAPI 스펙 위반** — `type: http + scheme: bearer`는 `Authorization: Bearer` 헤더 방식을 의미하며 쿠키와 무관.
3. **N-10 (High) — X-CSRF-TOKEN 요구와 `bearerAuth`의 의미론적 불일치**: Bearer Token 헤더 방식은 CSRF에 자동 면역이므로 `X-CSRF-TOKEN` 헤더가 불필요. CSRF 토큰을 요구한다는 것 자체가 **실제로는 쿠키 기반 세션**임을 증명. `bearerAuth` 표기는 잘못된 선언이고, 정확한 표기는 `cookieAuth` (type: apiKey, in: cookie, name: hc_access).

§8-1 (보안 스키마 이원화)는 **형태가 변형되었으나 본질적으로 해소되지 않음**. 이원화 외관은 사라졌지만, 스펙 선언과 실제 구현의 모순이 그 자리를 대체.

---

## 1. 요약

| 분류 | 개수 | 비고 |
|------|------|------|
| 작업 가능 엔드포인트 | 3 / 52 | `/api/auth/logout`, `/api/gate`, `/api/whoami` — 나머지는 §4-5/§5-*/§8-1 해소 전까지 차단 |
| v2.0/v2.1 요청 반영 완료 | 7건 (누적) | §0-1 |
| v2.0/v2.1 요청 부분 반영 | 2건 | §0-2 |
| v2.0/v2.1 요청 미반영 | 11건 | §0-3 |
| 신규 이슈 (Critical) | 2건 | §8-1 (변형), §8-8 (YAML 중복 키 버그) |
| 신규 이슈 (High) | 4건 | §8-2 EP 중복, §8-4 응답 누락, §8-5 불필요 서버 검증 API, §8-9 bearerAuth/쿠키 모순, §8-10 CSRF/Bearer 불일치 |
| 신규 이슈 (Medium) | 2건 | §8-3 URL 컨벤션, §8-7 필드명 3종 |
| Spectral 린트 | **810건** | error 602 / warning 208 (v2.1 787건 → +23) |

**핵심**: 이번 업데이트에서 servers URL 통일(§8-6)과 CSRF 보호 추가는 긍정적 개선이다. 그러나 §8-1 보안 스키마 이원화 문제에 대한 해결 시도가 **스펙 표기만 `bearerAuth`로 바꾸고 실제 구현은 여전히 쿠키 기반**으로 남기는 방식으로 진행되어, 스펙 선언이 OpenAPI 3.0.3 규격과 실제 동작 모두에 모순된다 (§8-9, §8-10). 추가로 auth-api에 YAML 중복 키 버그가 발생하여 스펙 자체가 파싱되지 않는 상태 (§8-8). 이 3건이 해소되기 전까지 member-api 44 EP 호출은 여전히 차단된다.

---

## 2. 작업 가능 — 호출 구조가 완결된 엔드포인트

| # | Method | Path | 비고 |
|---|--------|------|------|
| 1 | POST | `/api/auth/logout` | auth-api. `§4-5 쿠키명 합의 (hc_token ↔ hc_access)` 전제 조건. 서버측 JTI/세션 무효화 구현 확인 필요. |
| 2 | GET | `/api/gate` | 2차 업데이트 신규. GeoRouting 리다이렉트. 공개. |
| 3 | GET | `/api/whoami` | 2차 업데이트 신규. IP 기반 국가코드 반환. 공개. |

**member-api 44 EP 전체**는 §8-1 변형·§8-9 스펙 모순·§4-5 쿠키명·§8-4 응답 정의 전무로 인해 **현 상태에서 로직 주입 불가**.

**auth-api 나머지 5 EP** (login, refresh, register, verify/sms, verify/email)는 v2.0에서 지적한 §4-3/§4-4/§4-5/§5-1~§5-6 이슈가 여전히 해결되지 않아 조건부 작업 가능 상태.

---

## 3. Missing Endpoints — 현황

### 3-1. SMS 인증번호 확인 — ✓ 반영

- 엔드포인트: `POST /api/member/ConfirmGlobalCert`
- required: `[ac_phone_no, ac_country, ac_cert_num]`
- **잔여 이슈**: 검증 성공 시 verify_token 반환 없음(§4-2). 응답 스키마 정의 없음(§5-6). rate-limit 없음(§5-2).

### 3-2. 이메일 인증번호 확인 — ✓ 반영

- 엔드포인트: `POST /api/member/confirmMailCert`
- required: `[ac_id, mail_cert_no]`
- **잔여 이슈**: 3-1과 동일.

### 3-3. 이메일 중복 확인 — ✓ 반영

- 엔드포인트: `POST /api/member/CheckId`
- **잔여 이슈**: 응답 시간 균일화·per-IP rate-limit 여전히 미정의. CWE-204 위험 상존. 유사 엔드포인트 `CheckLoginId`가 별도로 존재 — 중복 여부 확인 필요 (§8-2 연계).

### 3-4. 닉네임 중복 확인 — ✓ 반영

- 엔드포인트: `POST /api/member/CheckNick`
- **잔여 이슈**: 3-3과 동일.

### 3-5. 아이디 찾기 — ✓ 반영

- 엔드포인트 쌍: `POST /api/member/FindIdCert` + `POST /api/member/ConfirmIdCert`
- **잔여 이슈**: `ConfirmIdCert` 응답 스키마 없음. 실제 이메일 반환 구조 불명.

### 3-6. 비밀번호 재설정 — △ 부분 반영 (미완)

- 반영된 것: `POST /api/member/FindPasswordCert` (인증번호 발송)
- **누락된 것**: 인증 후 실제 비밀번호를 재설정하는 엔드포인트 없음.
- **요청**: `POST /api/member/ResetPassword` 또는 유사 엔드포인트 신설.

---

## 4. Schema Defects — 현황

### 4-1. 회원가입 필드 — △ 부분 반영

**반영된 것** (`/api/member/JoinUser`): `birthYear`, `birthMonth`, `birthDay` (string), `cr_name`, `cr_gender`, `ac_phone_cert`, `ac_id_cert`, `cr_mail_cert`, `re_join`.

**누락된 것**:

| 필드 | 상태 |
|------|------|
| `agree_service` | 여전히 없음 |
| `agree_privacy` | 여전히 없음 |
| `agree_age` | 여전히 없음 |

**추가 지적** (v2.1에서 이어서):

1. **생년월일 타입**: string이 아닌 integer + minimum/maximum 권장 (Spectral integer-format/integer-limit-legacy 22건 error).
2. **PII 수집 증가**: `cr_name`, `cr_gender` — GDPR Art. 5(1)(c) data minimisation 원칙 재검토 필요.
3. **인증 상태 플래그 문제**: `ac_phone_cert`/`ac_id_cert`/`cr_mail_cert`는 클라이언트 입력으로 받으면 **인증 우회 가능** (CWE-807 Reliance on Untrusted Inputs). 서버측 verify_token/세션으로 추적 필요.
4. **중복**: 동일 목적의 `/api/auth/register`가 여전히 존재 → §8-2 참조.

**요청**: agree_service/agree_privacy/agree_age 3개 필드 추가 (boolean, required). 생년월일 integer 전환. 인증 상태 플래그 4개를 request body에서 제거.

### 4-2. verify_token 요구 — ✗ 미반영

v2.0/v2.1 §4-2 내용 그대로 유효.

### 4-3. `/api/auth/refresh` security scheme 누락 — ✗ 미반영

auth-api의 `/api/auth/refresh`에 여전히 `security:` 필드 없음. `bearerAuth`라면 security를 선언해야 하고, 쿠키 기반이라면 별도 refreshCookieAuth 스키마가 필요.

### 4-4. Refresh Rotation 정책 미정의 — ✗ 미반영

auth-api 무변경. v2.0 §4-4 내용 유지.

### 4-5. 쿠키 이름 / 보안 스키마 — ✗ 변형된 형태로 유지

- **이전 (v2.1)**: auth-api `cookieAuth (hc_access)` vs member-api `bearerAuth` — 이원화.
- **현재 (v2.2)**: 양쪽 모두 `bearerAuth`로 명칭 통일. **그러나**:
  - auth-api `securitySchemes.bearerAuth.description`이 "JWT Access Token (**HttpOnly 쿠키 hc_access**)"로 기재.
  - 양쪽 스펙이 `X-CSRF-TOKEN` 헤더를 모든 write EP에 required로 요구.
- **결과**: 스펙은 `bearerAuth`(Authorization 헤더)로 선언되었으나 실제는 쿠키 기반 구현 → §8-9, §8-10 모순.
- 프론트 구현(`lib/auth.js`)은 `hc_token` 쿠키 사용 → 스펙의 `hc_access`와 여전히 불일치.

---

## 5. Security — 현황

### 5-1. 계정 열거 공격 (CWE-204) — ✗ 미반영

auth-api `/api/auth/login` 401/404 분기 그대로. v2.0 §5-1 내용 유지.

### 5-2. SMS/Email DoS 리스크 — ✗ 미반영

OTP 발송 엔드포인트 6종(auth-api 2개 + member-api 4개) 전부 rate-limit/CAPTCHA 정의 없음. Spectral `owasp:api4:2023-rate-limit` 60건, `rate-limit-responses-429` 103건.

### 5-3. 쿠키 속성 미정의 — ✗ 미반영

auth-api의 `bearerAuth.description`이 "HttpOnly 쿠키"를 언급하므로 실제는 쿠키 기반. 그러나 Secure/SameSite/Path/Domain/Max-Age 등 속성은 정의되지 않음. `__Host-` prefix 언급 없음.

### 5-4. OTP 응답 본문 노출 가능성 — ✗ 악화 유지

member-api의 6개 OTP 엔드포인트가 응답 스키마 자체를 정의하지 않음 → 응답 본문에 OTP 포함 여부 판단 불가.

### 5-5. 비밀번호 정책 (CWE-521) — ✗ 미반영

- auth-api `register`: `minLength: 6, maxLength: 16` 그대로.
- member-api `ChangePasswd`, `JoinUser`: **길이 제약 전무**.

### 5-6. 에러 응답 스키마 — ✗ 미반영

- auth-api 5곳 schema 미연결 그대로.
- member-api **44 EP 전체**가 `"200: 성공"`만 정의. 4xx/5xx 전무.
- Spectral: `define-error-responses-401` 98건, `define-error-responses-500` 104건.

### 5-7. 탈퇴 실패 사유 구조화 — ✗ 미반영

`/api/member/DeleteUser` 응답 전무. v2.0 §5-7 내용 유지.

---

## 6. Quality — 현황

### 6-1. operationId 전체 누락 — ✗ 악화

52 EP 전수 누락 (v2.1 45 EP → v2.2 52 EP, `/api/gate`/`/api/whoami` 추가). Spectral operation-operationId 52건 error.

### 6-2. 이력 조회 파라미터·페이지네이션 — △ 부분 반영

`getCounselList`/`getCoinList`/`getPayList` 분할 그대로. `term: string`·`limit`/`offset` integer 제약 없음·meta 없음 — 여전.

### 6-3. 필드명 일관성 — ✗ 유지

`cr_phone`/`ac_phone_no`/`new_phone` 3종 혼재 그대로. v2.1 §6-3 내용 유지.

---

## 7. 결정 필요 사항 (백엔드 결정)

v2.0/v2.1 §7 4건 그대로 유효.

### 7-1. 보안 스키마 확정 (§8-1/§8-9/§8-10과 통합)

~~~쿠키 도메인 정책~~~ → 이번 업데이트에서 `bearerAuth`로 표기됐지만 실제는 쿠키 기반으로 보이는 상태이므로, **보안 스키마 자체의 재확정**이 선행되어야 한다. 쿠키 기반 확정 시 도메인 정책(JP/EN/KR 세션 공유 여부)도 함께 결정.

### 7-2. 비밀번호 최소 길이 — 8 vs 12

- **옵션 A**: `minLength: 8` (NIST SP 800-63B 최소)
- **옵션 B**: `minLength: 12` (OWASP ASVS 권장)

### 7-3. verify_token TTL

5분 / 10분 / 15분. 권고 10분.

### 7-4. SMS 쿼터 상한

월 예산 합의. §5-2는 상한 예시값.

---

## 8. 신규 이슈 (N-1 ~ N-10)

### 8-1. 보안 스키마 이원화 → 스펙/구현 모순으로 변형 — Critical (형태 변경)

- **v2.1 상태**: auth-api `cookieAuth` vs member-api `bearerAuth` 이원화.
- **v2.2 상태**: 양쪽 모두 `bearerAuth`로 명칭 통일. 그러나 `bearerAuth.description`이 "HttpOnly 쿠키 hc_access"라 기재되고 `X-CSRF-TOKEN`을 요구 → **스펙 선언과 실제 구현이 서로 다른 방식을 가리킴**.
- **상세는 §8-9, §8-10 참조**.
- **본질**: 프론트가 두 API를 통합 연동하려면 토큰이 어디서(쿠키 vs Authorization 헤더) 전달되는지 명확해야 한다. 현재 스펙은 두 가지 방식이 섞여 있어 어느 쪽도 완성된 구현이 아님.

### 8-2. 로그인·회원가입·OTP 엔드포인트 중복 — High (유지)

| 기능 | auth-api | member-api |
|------|----------|-----------|
| 로그인 | `POST /api/auth/login` | `POST /api/member/LoginUser` |
| 회원가입 | `POST /api/auth/register` | `POST /api/member/JoinUser` |
| SMS OTP 발송 | `POST /api/verify/sms` | `POST /api/member/SendGlobalCert` |
| 이메일 OTP 발송 | `POST /api/verify/email` | `POST /api/member/sendMailCert` |

v2.1 §8-2 내용 그대로 유효. 4개 기능 각각에 canonical 엔드포인트 1개 확정 필요.

### 8-3. URL 경로 컨벤션 혼재 — Medium (유지)

v2.1 §8-3 내용 그대로. auth-api kebab-case + resource-oriented vs member-api PascalCase + RPC + camelCase + mypage prefix 혼재.

### 8-4. member-api 전 EP의 4xx/5xx 응답 정의 전무 — High (유지)

44 EP 전부 `"200: 성공"`만 정의. Spectral `define-error-responses-401` 98건, `define-error-responses-500` 104건. v2.1 §8-4 내용 그대로.

### 8-5. 불필요한 서버 검증 API (CWE-200 / CWE-209) — High (유지)

`CheckLoginPassword`, `CheckLoginCrphone`, `CheckPassword`, `CheckPasswordRe` 4개 엔드포인트 폐기 요청. v2.1 §8-5 내용 그대로.

### 8-6. servers URL 불일치 — ✓ 해결

- **v2.1 상태**: auth-api `http://dev.gl.hongcafe.com` vs member-api `https://gl.hongcafe.com`.
- **v2.2 상태**: 양쪽 모두 `https://gl.hongcafe.com` (Production). HTTPS 통일.
- **잔여 개선 권고**: 두 스펙 모두 production server 1개만 명시. staging/development 2단계 추가 권고.

```yaml
servers:
  - url: https://api.hongcafe.com
    description: Production
  - url: https://stg.api.hongcafe.com
    description: Staging
  - url: https://dev.gl.hongcafe.com
    description: Development
```

### 8-7. 전화번호 필드명 3종 혼재 — Medium (유지)

`cr_phone` / `ac_phone_no` / `new_phone`. v2.1 §6-3 / §8-7 내용 그대로. `cr_phone` 단일화 요청.

### 8-8. auth-api.yaml YAML 중복 키 버그 — **Critical (2차 업데이트 신규)**

**현 스펙** (`auth-api.yaml` L284~302):

```yaml
components:
  parameters:
    XForwardedProto:      # ← 첫 번째 parameters 블록
      name: X-Forwarded-Proto
      in: header
      required: true
      description: 개발 환경 필수. 프로덕션에서는 ALB/CloudFront가 자동 추가.
      schema:
        type: string
        default: https

  parameters:             # ← 두 번째 parameters 블록 (L295) — YAML 중복 키
    XCsrfToken:
      name: X-CSRF-TOKEN
      in: header
      required: true
      schema:
        type: string
      description: CSRF 토큰 (hc_csrf 쿠키 값).
```

**근거**:
- **YAML 1.2 spec §3.2.1.3 "Nodes"**: "The content of a mapping node is an unordered set of key: node pairs, with the restriction that each of the keys is unique." 그러나 대다수 파서(Spectral, swagger-parser 등)는 중복 키를 에러로 처리하지 않고 **뒤의 값이 앞의 값을 덮어쓰도록** 구현됨.
- 결과: `XForwardedProto` 정의가 `XCsrfToken`으로 덮어써져 소실. 그러나 `paths.*` 에서 여전히 `$ref: "#/components/parameters/XForwardedProto"` 참조.
- **Spectral 보고**: `invalid-ref` error 1건 + `parser` error 1건.

**결과**: auth-api.yaml 전체가 **파서 수준에서 깨진 상태**. OpenAPI 도구(swagger-ui, openapi-generator 등)는 이 파일을 로드하지 못하거나 경고를 출력한다.

**요청**: L295의 중복 `parameters:` 키를 제거하고 `XForwardedProto`와 `XCsrfToken`을 동일 `parameters:` 블록 내에 정의:

```yaml
components:
  parameters:
    XForwardedProto:
      name: X-Forwarded-Proto
      in: header
      required: true
      description: ...
      schema:
        type: string
        default: https
    XCsrfToken:
      name: X-CSRF-TOKEN
      in: header
      required: true
      schema:
        type: string
      description: CSRF 토큰 (hc_csrf 쿠키 값).
```

### 8-9. `bearerAuth` 선언과 쿠키 기반 구현의 모순 — **High (2차 업데이트 신규)**

**현 스펙** (`auth-api.yaml` L304~309):

```yaml
securitySchemes:
  bearerAuth:
    type: http
    scheme: bearer
    bearerFormat: JWT
    description: JWT Access Token (HttpOnly 쿠키 hc_access)
```

**모순**:

1. **OpenAPI 3.0.3 사양 위반**: `type: http` + `scheme: bearer`는 **RFC 6750 Bearer Token Usage**를 따르는 `Authorization: Bearer {token}` 헤더 방식을 명시한다. 쿠키와 무관하다.
2. **Description과의 불일치**: description에 "HttpOnly 쿠키 hc_access"라고 기재되어 있으나, 이는 `type: apiKey, in: cookie, name: hc_access` 스키마에 해당.
3. **클라이언트 도구 혼란**: OpenAPI 기반 SDK 자동 생성 도구(openapi-generator, orval 등)는 `bearerAuth`를 읽고 `Authorization: Bearer` 헤더를 자동 주입하려 함. 그러나 실제 백엔드가 쿠키를 기대한다면 요청이 401로 거부됨.

**근거**:
- **OpenAPI Specification 3.0.3 — Security Scheme Object**: `type: http`는 RFC 7235 HTTP Authentication을, `scheme: bearer`는 RFC 6750를 참조. 쿠키 기반 인증은 `type: apiKey, in: cookie`로 표기해야 함.
- **RFC 6750 §2.1~2.3**: Bearer Token은 Authorization Request Header Field(§2.1), Form-Encoded Body Parameter(§2.2), URI Query Parameter(§2.3)의 3가지 방식만 정의. 쿠키는 포함되지 않음.

**요청**: 실제 구현이 쿠키 기반이라면 스키마를 `cookieAuth`로 변경:

```yaml
securitySchemes:
  cookieAuth:
    type: apiKey
    in: cookie
    name: hc_access
    description: JWT Access Token (HttpOnly, Secure, SameSite=Lax)
```

실제 구현이 Bearer 헤더 방식이라면 description에서 "쿠키" 표현을 제거하고 프론트는 토큰을 `Authorization` 헤더로 전달. 양자택일.

### 8-10. X-CSRF-TOKEN 요구와 `bearerAuth`의 의미론적 불일치 — **High (2차 업데이트 신규)**

**현 스펙**: 양쪽 YAML의 모든 write EP에 `X-CSRF-TOKEN` 헤더가 required. `bearerAuth` 보안 스키마와 병행.

**불일치**:

1. **Bearer Token은 CSRF에 자동 면역**: `Authorization: Bearer` 헤더는 브라우저가 크로스 오리진 요청에 자동 포함하지 않으므로, 공격자 사이트가 헤더를 위조할 수 없음 → CSRF 공격 불가능 → CSRF 토큰 불필요.
2. **CSRF 토큰이 필요한 이유**: 쿠키는 브라우저가 **크로스 오리진 요청에도 자동 포함**하므로, 공격자 사이트가 피해자의 쿠키로 요청을 위조할 수 있음. 이를 방어하기 위해 Double Submit Cookie 패턴(CSRF 토큰)이 필요.
3. **현 스펙의 상태**: CSRF 토큰을 요구한다는 것 자체가 **실제 구현이 쿠키 기반임을 증명**. §8-9와 함께 `bearerAuth` 선언이 잘못된 것임을 재확인.

**근거**:
- **OWASP CSRF Prevention Cheat Sheet** — "When to Use CSRF Protection": "If you are using cookies or HTTP basic authentication for session management, you need CSRF protection. Token-based authentication using bearer tokens in the Authorization header is not vulnerable to CSRF."
- **MDN Web Docs — CSRF**: "Because bearer tokens are not sent automatically by the browser, they are inherently immune to CSRF."

**요청**: §8-9 해결과 함께 정리.

- 쿠키 기반 채택 시 → `cookieAuth` 스키마 + `X-CSRF-TOKEN` 헤더 유지 (올바른 조합)
- Bearer 기반 채택 시 → `bearerAuth` 스키마 유지 + `X-CSRF-TOKEN` 헤더 **제거** (불필요한 복잡도)

---

## 9. 엔드포인트 총량 추이

| 구분 | v2.0 | v2.1 | v2.2 |
|------|------|------|------|
| auth-api 엔드포인트 | 6 | 6 | **8** (+/api/gate, /api/whoami) |
| member-api 엔드포인트 | 8 | 39 | **44** |
| 합계 | 14 | 45 | **52** |
| 보안 스키마 선언 | 1 (cookieAuth) | 2 (cookieAuth + bearerAuth) | 1 (bearerAuth) — 단, 실제 구현과 불일치 |
| CSRF 헤더 정의 | 없음 | 없음 | **X-CSRF-TOKEN (양쪽)** |
| servers URL 일치 | — | 불일치 | ✓ 일치 (https://gl.hongcafe.com) |
| 공통 responses 컴포넌트 | 3 | auth 3 / member 0 | auth 3 / member 0 |
| operationId 정의 비율 | 0/14 | 0/45 | 0/52 |
| 응답 4xx/5xx 정의 비율 | auth ~80% / member ~60% | auth ~80% / member 0% | auth ~80% / member 0% |

---

## 10. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|----------|-------|
| v2.0 | 2026-04-13 | 초안 | 명우현 |
| v2.1 | 2026-04-13 | 백엔드 1차 업데이트(member-api 전면 재작성) 검토. 신규 이슈 §8-1~§8-7. | 명우현 |
| v2.2 | 2026-04-13 | 백엔드 2차 업데이트 검토. §8-6 servers URL 해결 ✓. §8-1 변형 (명칭 통일 + 스펙/구현 모순). 신규 이슈 §8-8~§8-10 (YAML 중복 키 버그, bearerAuth/쿠키 모순, CSRF/Bearer 불일치). Spectral 787→810. | 명우현 |

---

## 11. 부록 — Spectral 자동 린트 결과

2026-04-13 2차 업데이트된 두 스펙에 **Spectral 6.15** + **OWASP ruleset 2.0** 적용:

| 심각도 | v2.0 | v2.1 | v2.2 | v2.1→v2.2 증감 |
|--------|------|------|------|------|
| error | 145 | 584 | **602** | +18 |
| warning | 44 | 203 | **208** | +5 |
| **합계** | 189 | 787 | **810** | +23 |

**파일별**:

| 파일 | v2.0 | v2.1 | v2.2 | 증감 |
|------|------|------|------|------|
| auth-api.yaml | ~95 | 95 | **116** | +21 (CSRF 추가 + 신규 EP + YAML 버그) |
| member-api.yaml | ~94 | 692 | **694** | +2 (XCsrfToken 추가) |

**상위 룰 (v2.2 기준)**:

| 건수 | Spectral 룰 | 본 리뷰 연결 |
|-----:|-------------|-------------|
| 110 | `owasp:api4:2023-string-limit` | §5-5, §6-3 |
| 108 | `owasp:api4:2023-string-restricted` | §6-3 |
| 104 | `owasp:api8:2023-define-error-responses-500` | §5-6, §8-4 |
| 103 | `owasp:api4:2023-rate-limit-responses-429` | §5-2 |
| 98 | `owasp:api8:2023-define-error-responses-401` | §5-6, §8-4 |
| 60 | `owasp:api4:2023-rate-limit` | §5-2 |
| 52 | `operation-operationId` | §6-1 |
| 22 | `owasp:api2:2023-write-restricted` | §4-3, §8-1 |
| 22 | `owasp:api4:2023-integer-format` | §6-2, §4-1 |
| 22 | `owasp:api4:2023-integer-limit-legacy` | §6-2, §4-1 |
| 2 | `owasp:api2:2023-jwt-best-practices` | §8-9 |
| 2 | `owasp:api2:2023-read-restricted` | (신규 GET /api/gate, /api/whoami) |
| 2 | `owasp:api8:2023-define-cors-origin` | (범위 밖) |
| **1** | **`invalid-ref`** | **§8-8 (auth-api YAML 중복 키 버그)** |
| **1** | **`parser`** | **§8-8 (auth-api YAML 중복 키 버그)** |

**v2.1 → v2.2 변화 요약**:
- `owasp:api8:2023-no-server-http` 1건 → **0건 (해결)** ✓ §8-6
- `invalid-ref` + `parser` 각 1건 → **신규 발생** §8-8
- `owasp:api2:2023-jwt-best-practices` 1건 → 2건 (bearerAuth 선언으로 체크가 양쪽 모두에 적용)
- `owasp:api2:2023-read-restricted` 2건 → 신규 (신규 GET EP 공개 노출)

---

## 12. 리뷰 범위 밖 (명시적 제외)

- **`/api/mypage/*` 도메인 (20 EP)**: v2.1에서 대량 추가된 autopay·coupon·reward·chat·video·comment 등. 본 리뷰는 회원/인증 계약 검토. §5/§6/§8 원칙은 해당 영역에도 동일 적용 권고.
- **`/api/gate`, `/api/whoami` 세부 설계**: GeoRouting 기능은 v2.2 신규 추가. 프론트 intro 페이지의 IP 기반 국가 판별과 연계 가능성 있음. 본 리뷰에서는 "작업 가능" 분류만 반영하고 상세 설계는 별도.
- **`/api/member/getAppVersion`**: 회원 API 범주가 아닌 common/settings API로 이동 권고. 별도 이슈.
- **`SettingAlarm type/value 패턴`**: 현 스펙은 enum 없는 자유 문자열 쌍. 알림 스키마 설계는 별도 문서.
- **CORS 정책**: Spectral `owasp:api8:2023-define-cors-origin` 2건 보고. 인프라/보안팀 의사결정.
- **네이티브 앱 브릿지와의 세션 공존**: AppConnector와 웹 JWT 쿠키 — 네이티브 팀과 별도 협의.
- **JWT 내부 claim 설계**: 토큰 발급 주체 결정 이후 별도 문서.
- **다른 모듈 스펙 (commerce, call, chat 등 238 EP)**: README.md 기준 총 292개 라우트 중 본 리뷰는 auth(8)+member(44)=52 EP만 검토. 나머지 모듈은 별도 리뷰 대상.
