# Backend API — 작업 불가능 이슈 결정 요청표

| 항목 | 내용 |
|------|------|
| 작성자 | 명우현 |
| 작성일 | 2026-04-13 |
| 버전 | v1.0 |
| 상태 | Decision Pending |
| 대상 독자 | 백엔드 (API 설계자) |
| 대상 스펙 | `auth-api.yaml` v1.0.0 (8 EP) + `member-api.yaml` v1.0.0 (44 EP) — 2026-04-13 2차 수령 |
| 연관 문서 | `backend-api-review.md` v2.2 (상세 리뷰) |
| 양식 | `as-is 문서(홍카페 Japan)` \| `현재 API 명세` \| `권고안` \| `결정안` |
| 목적 | v2.2 엄격 기준에서 "작업 불가능"으로 분류된 22건의 근본 이슈에 대해 백엔드 의사결정을 받기 위함 |

## 사용법

1. 각 행의 **결정안** 칼럼에 `☐ 권고안 수용` / `☐ 대안 제시` / `☐ 유지 (이유 기재)` 중 하나를 선택
2. 대안 제시 또는 유지의 경우 결정 사유를 함께 기재
3. 의존 관계가 있는 항목(예: §8-1 → §4-5, §5-3)은 상위 결정이 하위 결정을 자동 결정
4. 전체 결정이 확정되면 `backend-api-review.md` v3.0으로 반영하여 프론트 `develop:` 워크플로우 진입

---

## Priority 1 — Critical (호출 구조 자체가 막힌 항목)

### D-01. auth-api.yaml YAML 중복 키 버그 (§8-8)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | 해당 없음 (as-is는 CI4 PHP 모놀리스로 OpenAPI 스펙 미작성) |
| **현재 API 명세** | `auth-api.yaml` L284~302: `components.parameters:` 키가 **두 번 정의됨** (L285, L295). YAML 파서가 뒤의 `XCsrfToken` 블록으로 덮어써서 `XForwardedProto` 정의 소실. `paths.*` 의 `$ref: "#/components/parameters/XForwardedProto"` 참조가 전부 깨짐 |
| **권고안** | L295의 중복 `parameters:` 키를 제거하고 `XForwardedProto`와 `XCsrfToken`을 동일 `parameters:` 블록 내에 나란히 정의. 수정 후 Spectral `invalid-ref` + `parser` error 2건 해소됨. **작업 소요: 5분** |
| **결정안** | ☐ |

### D-02. 보안 스키마: bearerAuth vs 쿠키 기반 구현 모순 (§8-1 / §8-9 / §8-10 통합)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | `hongcafe-japan` CI4의 native session 사용. `ci_session` 쿠키 자동 발급 (HttpOnly, CI4 기본 설정). OpenAPI 스펙 없음. CSRF는 CI4 `Security::csrfVerify()` + 폼 hidden input 방식 |
| **현재 API 명세** | `auth-api.yaml` L304~309: `bearerAuth` (`type: http, scheme: bearer, bearerFormat: JWT`) 선언. description은 "JWT Access Token (HttpOnly 쿠키 hc_access)"로 기재. 모든 write EP에 `X-CSRF-TOKEN` 헤더 required. → 선언(`bearer` 헤더)과 description(`쿠키`) 불일치. Bearer Token은 CSRF 면역인데 CSRF 토큰 요구 → 실제는 쿠키 기반임을 증명 |
| **권고안** | 실제 구현을 쿠키 기반으로 확정하고 스키마를 교체: <br>```yaml<br>securitySchemes:<br>  cookieAuth:<br>    type: apiKey<br>    in: cookie<br>    name: hc_access<br>    description: JWT Access Token (HttpOnly, Secure, SameSite=Lax)<br>```<br>`X-CSRF-TOKEN` 헤더는 유지 (쿠키 세션과 정합). `bearerAuth` 선언 제거. **근거**: RFC 6750 §2 (Bearer는 Authorization 헤더 전용), OWASP CSRF Prevention Cheat Sheet ("Bearer tokens are inherently immune to CSRF"), 프론트 `lib/auth.js`가 이미 HttpOnly 쿠키 기반 구현 |
| **결정안** | ☐ |

### D-03. 쿠키 이름 불일치 (§4-5)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | `ci_session` (CI4 기본) |
| **현재 API 명세** | 스펙: `hc_access` (description에만 기재, 실제 스키마 필드에 미반영) / 프론트 구현(`lib/auth.js` L45): `hc_token` |
| **권고안** | D-02 결정과 함께 확정. **`hc_access` 채택 권고** (스펙 description과 일치). 확정 후 프론트 `lib/auth.js` `TOKEN_NAME` 상수를 `hc_token` → `hc_access`로 리팩터. 추가로 `hc_refresh`(refresh), `hc_fp`(device fingerprint)도 백엔드가 사용할지 결정 필요 |
| **결정안** | ☐ |

### D-04. 회원가입 약관 동의 필드 부재 (§4-1)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | `/api/member/joinuser` 에서 `agree_service`, `agree_privacy`, `agree_age` 3개 필드를 **저장 중** (hongcafe-japan 분석 결과 확인) |
| **현재 API 명세** | `member-api.yaml` L200 `/api/member/JoinUser` required: `[ac_id, ac_nick, cr_phone, ac_country]`. 약관 동의 필드 3종 **전부 누락** |
| **권고안** | 3개 필드를 `properties`에 추가 + `required`에 포함:<br>```yaml<br>agree_service: { type: boolean }<br>agree_privacy: { type: boolean }<br>agree_age:     { type: boolean }<br>required: [..., agree_service, agree_privacy, agree_age]<br>```<br>추가로 백엔드가 동의 시각(timestamp) + 약관 버전(version)도 DB에 기록. **근거**: GDPR Art. 7(1) 동의 증적 보관 의무, 韓 개인정보 보호법 §22-2 만 14세 미만 법정대리인 동의, 日 PPC 가이드라인 미성년자 동의 권고. **법적 리스크이므로 미반영 시 프로덕션 배포 불가** |
| **결정안** | ☐ |

### D-05. 비밀번호 재설정 엔드포인트 부재 (§3-6)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | `/api/member/findpw` + 후속 비밀번호 재설정 엔드포인트로 플로우 구성 (정확한 재설정 EP 이름은 as-is 코드 재확인 필요) |
| **현재 API 명세** | `/api/member/FindPasswordCert` (L342, 인증번호 발송)만 존재. **인증 확인 + 새 비밀번호 설정 엔드포인트 없음** → 비밀번호 찾기 플로우 종결 불가 |
| **권고안** | `POST /api/member/ResetPassword` 또는 유사 엔드포인트 신설: <br>```yaml<br>required: [ac_id, ac_cert_num, new_password, new_password_re]<br>```<br>성공 시 해당 계정의 기존 refresh token 패밀리 전체 invalidate (RFC 6819 §5.2.2.3). 응답에 재설정 성공 + 강제 재로그인 유도 |
| **결정안** | ☐ |

---

## Priority 2 — High (프론트 구현 저해)

### D-06. verify_token 메커니즘 부재 (§4-2)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is는 **CI4 session**에 인증 상태(`session->set('phone_verified', true)`)를 저장하여 JoinUser가 서버측에서 조회. 클라이언트 플래그 미사용 |
| **현재 API 명세** | `JoinUser` request body에 `ac_phone_cert`, `ac_id_cert`, `cr_mail_cert` 플래그가 **클라이언트 입력**으로 정의됨. 공격자가 `curl -d '{"ac_phone_cert":"Y"}'` 직송하면 인증 우회 → CWE-807 Reliance on Untrusted Inputs |
| **권고안** | 3가지 방식 중 택1: <br>**(A) verify_token 방식** — `ConfirmGlobalCert`/`confirmMailCert` 성공 시 서버가 랜덤 토큰(10분 TTL) 발급 → `JoinUser`에 전달해 검증 <br>**(B) 서버 세션 방식** — 쿠키 기반 익명 세션에 인증 상태 저장 → `JoinUser`가 세션에서 조회 (as-is 방식) <br>**(C) Redis lookup** — 서버가 `verified:{phone_no}=true` 10분 TTL 저장 → `JoinUser`가 cr_phone으로 조회 <br>어느 방식이든 **`ac_phone_cert`/`ac_id_cert`/`cr_mail_cert` 플래그는 request body에서 제거**. 권고: **(B) 서버 세션 방식** (as-is 연속성, 추가 구현 부담 최소) |
| **결정안** | ☐ |

### D-07. /api/auth/refresh security scheme 누락 (§4-3)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | 해당 없음 (as-is는 access/refresh 분리 없이 CI4 session 단일 사용) |
| **현재 API 명세** | `auth-api.yaml` L118~146 `/api/auth/refresh`에 `security:` 필드 자체가 없음. description에만 "Refresh Token 쿠키" 언급 |
| **권고안** | refresh 전용 security scheme 신설: <br>```yaml<br>securitySchemes:<br>  cookieAuth:<br>    type: apiKey<br>    in: cookie<br>    name: hc_access<br>  refreshCookieAuth:<br>    type: apiKey<br>    in: cookie<br>    name: hc_refresh<br>    description: Refresh Token (HttpOnly, __Host-, single-use, 7d TTL)<br><br>paths:<br>  /api/auth/refresh:<br>    post:<br>      security:<br>        - refreshCookieAuth: []<br>```<br>D-02 결정과 연동 |
| **결정안** | ☐ |

### D-08. Refresh Token Rotation 정책 미정의 (§4-4)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | 해당 없음 (as-is는 single session cookie로 운영) |
| **현재 API 명세** | `POST /api/auth/refresh` 성공 응답이 "새 `hc_access` 발급"만 언급. **새 `hc_refresh` 동시 발급 여부 불명**. rotation/reuse detection 정책 전무 |
| **권고안** | 스펙 description에 다음을 명시: <br>1. refresh 성공 시 Set-Cookie로 **새 access + 새 refresh 동시 발급** <br>2. 이전 refresh token 즉시 invalidate (single-use) <br>3. 이미 사용된 refresh 재사용 감지 시 해당 사용자의 전 세션 패밀리 revoke <br>4. reuse detection 시 응답: `401` + `ErrorResponse.error.code: REFRESH_REUSE_DETECTED` <br>**근거**: RFC 6819 §5.2.2.3, RFC 8725 §2.1 JWT Best Current Practices |
| **결정안** | ☐ |

### D-09. member-api 전 EP의 4xx/5xx 응답 정의 전무 (§5-6 / §8-4)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is PHP 응답 형식: `{ "response": "success" \| "fail", "msg": "한국어 메시지", "data": {} }`. HTTP status는 대부분 200만 사용 (에러도 200 + fail 플래그) |
| **현재 API 명세** | `member-api.yaml` **44 EP 전체**가 `"200: description: 성공"` 한 줄만 정의. 400/401/403/404/409/429/500 전부 누락. Spectral `define-error-responses-401` 98건 + `-500` 104건 error |
| **권고안** | `member-api.yaml` `components.responses`에 `auth-api.yaml`의 공통 응답 7종 복제 (`Unauthorized`, `NotFound`, `ValidationFailed`, `Forbidden`, `Conflict`, `RateLimited`, `InternalError`). 이후 44 EP 전부에 최소 `400`, `401`, `500` 응답을 `$ref`로 연결. 또한 `ErrorResponse.error.code`를 enum으로 고정 (v2.0 §5-6 참조). **HTTP status 기반 에러 분류는 RESTful 표준 (RFC 9110 §15)** — as-is의 200+fail 플래그 방식은 글로벌 서비스에 부적합 |
| **결정안** | ☐ |

### D-10. 엔드포인트 중복 (§8-2)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | 단일 엔드포인트 유지 (PascalCase RPC 스타일): `/api/member/joinuser`, `/api/member/loginuser`, `/api/member/sendCertNum`(또는 sendglobalcert) 등 |
| **현재 API 명세** | 동일 기능이 두 스펙에 중복: <br>- 로그인: `POST /api/auth/login` vs `POST /api/member/LoginUser` <br>- 회원가입: `POST /api/auth/register` vs `POST /api/member/JoinUser` <br>- SMS 발송: `POST /api/verify/sms` vs `POST /api/member/SendGlobalCert` <br>- 이메일 발송: `POST /api/verify/email` vs `POST /api/member/sendMailCert` |
| **권고안** | 4개 기능 각각에 canonical 1개만 유지, 나머지 삭제. **권고: member-api 쪽 유지** (as-is 연속성 + JoinUser가 생년월일·성별 등 풍부한 필드 지원). auth-api의 login/register/verify/sms/verify/email 4개 EP 삭제. 결정 시 D-02 보안 스키마와 연동 |
| **결정안** | ☐ |

### D-11. 불필요한 서버 검증 API 4개 (§8-5)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | `/api/member/checkpassword`, `/api/member/checknick` 등 존재. 당시 모바일 앱이 이를 호출. 단, 비밀번호 일치 여부(`checkpasswordre`)는 없음 |
| **현재 API 명세** | 4개 불필요 EP: <br>- `CheckLoginPassword` (L52) — 비밀번호 형식 유효성 <br>- `CheckLoginCrphone` (L71) — 전화번호 형식 <br>- `CheckPassword` (L90) — 비밀번호 6~16자 <br>- `CheckPasswordRe` (L109) — 두 비밀번호 일치 여부 (순수 클라이언트 로직) |
| **권고안** | 4개 EP **전부 폐기**. 검증 로직은 프론트엔드에서 수행 (`lib/validation.js` 또는 HTML5 `pattern` 속성). `CheckId`/`CheckNick`(DB 조회 필요)은 유지. **근거**: CWE-200 Sensitive Information Exposure, CWE-209 Error Message Info Exposure, OWASP ASVS V2.1.4 (비밀번호는 로그인/회원가입 제출 시점에만 서버로). 특히 `CheckPasswordRe`는 두 비밀번호를 서버로 전송해 일치 여부를 확인 → **네트워크 로그·WAF 로그에 평문 비밀번호 축적** |
| **결정안** | ☐ |

---

## Priority 3 — High (보안/프로덕션 배포 차단)

### D-12. 계정 열거 공격 — CWE-204 (§5-1)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is는 401/404 구분 반환 (동일 취약점 존재) |
| **현재 API 명세** | `auth-api.yaml` `POST /api/auth/login` 응답: `401` = 비밀번호 틀림, `404` = 계정 없음 구분 반환 |
| **권고안** | 1. `404` 응답 제거, 모든 실패를 `401 UNAUTHORIZED`로 통일 <br>2. 응답 body 동일화: `{ error: { code: "UNAUTHORIZED", message: "인증 정보가 올바르지 않습니다." } }` <br>3. 서버측 응답 시간 균일화 (계정 없음 케이스에도 dummy bcrypt 비교). <br>동일 원칙을 `/api/member/LoginUser`, `/api/member/CheckId`(중복체크), `/api/member/CheckNick` 에도 적용. **근거**: OWASP Authentication Cheat Sheet "Authentication and Error Messages", CWE-204, NIST SP 800-63B 온라인 공격 방어 원칙 |
| **결정안** | ☐ |

### D-13. SMS/Email DoS — OWASP API4:2023 (§5-2)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is PHP에서 per-IP 간단 제한 (session 기반). rate-limit 표준 헤더 없음 |
| **현재 API 명세** | OTP 발송 엔드포인트 6종(auth-api 2개 + member-api 4개) **전부 rate-limit/CAPTCHA 정의 없음**. 비로그인 공용 엔드포인트이므로 봇이 SMS를 무제한 발송 가능 → **SMS 캐리어 수수료 직접 손실** |
| **권고안** | 1. 각 OTP 엔드포인트 requestBody에 `captcha_token: string` required 추가 (reCAPTCHA v3 또는 Turnstile) <br>2. `429` 응답에 `RateLimit-Limit`/`RateLimit-Remaining`/`RateLimit-Reset`/`Retry-After` 헤더 명시 <br>3. 정량 정책: per-IP 5req/min, per-phone 3req/10min, per-24h per-phone 10회 <br>4. 동일 규칙을 `/api/auth/login`, `/api/member/CheckId/CheckNick`에도 적용 <br>**근거**: OWASP API4:2023 Unrestricted Resource Consumption, IETF draft-ietf-httpapi-ratelimit-headers, Twilio Verify API 가이드 |
| **결정안** | ☐ |

### D-14. 쿠키 속성 미정의 (§5-3)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | CI4 기본 session cookie는 `HttpOnly=true`, `Secure=true`(SSL 시), `SameSite=Lax`. `__Host-` prefix 미사용 |
| **현재 API 명세** | `auth-api.yaml` `bearerAuth.description`에 "HttpOnly 쿠키"만 언급. Secure/SameSite/Path/Domain/prefix/Max-Age 전부 **미정의** |
| **권고안** | 스펙 `info.description`에 Security Considerations 블록 추가:<br>```<br>All authentication cookies are issued with:<br>  HttpOnly; Secure; SameSite=Lax; Path=/<br>Production uses __Host- prefix (no Domain attribute).<br>Max-Age:<br>  hc_access  : 900    (15 min)<br>  hc_refresh : 604800 (7d, absolute, non-sliding)<br>Cross-hostname session sharing: DENIED<br>  (jp./en./hongcafe.com 간 재로그인 필요)<br>```<br>**근거**: RFC 6265bis §4.1.2.5~7, §4.1.3.2 `__Host-` prefix, OWASP ASVS V3.4. hostname 분리 정책은 §7-1 연계 |
| **결정안** | ☐ |

### D-15. OTP 응답 본문 노출 금지 명시 (§5-4)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is `confirmCertNum` 응답은 성공/실패 플래그만 반환 (OTP 미노출) |
| **현재 API 명세** | member-api의 6개 OTP 엔드포인트(`SendGlobalCert`, `ConfirmGlobalCert`, `sendMailCert`, `confirmMailCert`, `FindIdCert`, `FindPasswordCert`)가 **응답 스키마 자체를 정의하지 않음** → 응답 본문에 OTP 포함 여부 판단 불가 |
| **권고안** | 6개 OTP EP에 응답 스키마 추가 + description에 **"OTP 코드는 SMS/이메일 out-of-band 채널로만 전달되며, 응답 본문에는 절대 포함되지 않는다 (개발 환경 포함)"** 명시. **근거**: OWASP ASVS V2.8 — OTP는 out-of-band 채널 전용. 응답 본문 반환은 dev 편의성 패턴이 프로덕션으로 유출되는 전형적 사고 경로 |
| **결정안** | ☐ |

### D-16. 비밀번호 정책 — CWE-521 (§5-5)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | `/api/member/checkpassword`: minLength 6, maxLength 16 (NIST SP 800-63B 미달) |
| **현재 API 명세** | `auth-api.yaml register`: `minLength: 6, maxLength: 16` 그대로. `member-api.yaml ChangePasswd`/`JoinUser`의 `ac_password`/`new_password`: **길이 제약 전무** (Spectral string-limit 110건) |
| **권고안** | 전 EP 통일: `minLength: 8` (NIST 최소), `maxLength: 128`, `format: password`. 복잡도 규칙 대신 **HaveIBeenPwned Pwned Passwords API**(k-anonymity 방식) 도입 권장. 기존 회원 중 8자 미만은 다음 로그인 시 강제 변경. **근거**: NIST SP 800-63B §5.1.1.2, OWASP ASVS V2.1.1, CWE-521 |
| **결정안** | ☐ |

### D-17. 탈퇴 실패 사유 구조화 — GDPR Art. 17 (§5-7)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is `/api/member/deleteuser`는 단순 탈퇴 처리. 보류 사유 없음 |
| **현재 API 명세** | `/api/member/DeleteUser` (L540): response `"200: 성공"`만 정의. 실패 경로 전무 |
| **권고안** | `409 Conflict` 응답 추가 + `ErrorResponse.error.code`에 사유 enum 추가: <br>- `HAS_PENDING_SETTLEMENT` (정산 진행 중) <br>- `RETENTION_HOLD` (거래기록 보존 의무) <br>- `LEGAL_HOLD` (법적 보존) <br>예시: <br>```yaml<br>"409":<br>  content:<br>    application/json:<br>      schema: { $ref: "#/components/schemas/ErrorResponse" }<br>      example:<br>        error:<br>          code: HAS_PENDING_SETTLEMENT<br>          message: 정산이 진행 중입니다.<br>```<br>**근거**: GDPR Art. 17(3) 삭제 제한 사유, 韓 전자상거래법 거래기록 5년 보존 의무 |
| **결정안** | ☐ |

---

## Priority 4 — Medium (품질/일관성)

### D-18. operationId 전수 누락 (§6-1)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is는 OpenAPI 스펙 미작성 — operationId 개념 자체 없음 |
| **현재 API 명세** | **52 EP 전수 누락** (auth 8 + member 44). Spectral `operation-operationId` 52건 error |
| **권고안** | 모든 EP에 `operationId` 추가. 네이밍 컨벤션: `camelCase`, 동사+명사 형태. 예: `POST /api/member/JoinUser` → `operationId: joinUser`, `POST /api/member/CheckId` → `operationId: checkEmailAvailability`. **근거**: OpenAPI 3.0.3 Operation Object — "The id MUST be unique among all operations described in the API". openapi-generator/orval 등 SDK 자동 생성 도구가 이를 함수명 소스로 사용. 누락 시 `post_api_member_JoinUser` 같은 가독성 낮은 식별자 생성 |
| **결정안** | ☐ |

### D-19. 이력 조회 파라미터·페이지네이션 (§6-2)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is의 이력 EP도 `term`(string), `limit`(int), `offset`(int) 사용. 단위 미명시 |
| **현재 API 명세** | `getCounselList`/`getCoinList`/`getPayList` 3개 EP: <br>- `term: string, default: "3"` — **단위 미명시** (3일? 3개월? 3년?) <br>- `limit`/`offset`은 `type: integer`이나 `minimum`/`maximum`/`format` 전부 없음 (Spectral `integer-format`/`integer-limit-legacy` 22건 error) <br>- 응답 `meta.total`/`hasMore` 등 페이지네이션 메타 없음 |
| **권고안** | 스키마 보강: <br>```yaml<br>term:   { type: integer, default: 90, minimum: 1, maximum: 365 }<br>limit:  { type: integer, default: 20, maximum: 100 }<br>offset: { type: integer, default: 0, minimum: 0 }<br>```<br>응답에 `meta: { total, hasMore }` 추가. `term` 단위를 "일" 로 통일. `st_code` 파라미터는 enum 또는 pattern 정의 추가 |
| **결정안** | ☐ |

### D-20. 전화번호 필드명 3종 혼재 (§6-3 / §8-7)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is는 `cr_phone` 단일 사용 (전화번호 변경 시에도 `cr_phone` 파라미터로 새 번호 전달) |
| **현재 API 명세** | **3종 혼재**: <br>- `cr_phone`: register, JoinUser, CheckLoginCrphone, FindIdCert, ConfirmIdCert, FindPasswordCert <br>- `ac_phone_no`: auth-api verify/sms, SendGlobalCert, ConfirmGlobalCert <br>- `new_phone`: VerifyPhone, UpdatePhone |
| **권고안** | **`cr_phone` 단일화** (as-is 연속성 유지). `new_phone`은 컨텍스트(VerifyPhone/UpdatePhone)로 "새 번호"임을 구분 가능하므로 `cr_phone`으로 통일하고 description에 의미를 명시. 국가코드는 이미 `ac_country`로 통일됨 (유지) |
| **결정안** | ☐ |

### D-21. URL 경로 컨벤션 혼재 (§8-3)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | as-is는 PascalCase + camelCase 혼재 (`/api/member/joinuser`, `/api/member/sendCertNum`). 표준 없음 |
| **현재 API 명세** | **컨벤션 4종 혼재**: <br>- auth-api: kebab-case + resource-oriented (`/api/auth/login`, `/api/auth/reset-password`) <br>- member-api: PascalCase + RPC (`/api/member/JoinUser`, `/api/member/CheckId`) <br>- member-api 내부 camelCase (`/api/member/sendMailCert`, `/api/member/updateHomeSet`) <br>- mypage prefix 추가 (`/api/mypage/getCounselList`) |
| **권고안** | 2가지 옵션: <br>**(A) 전역 kebab-case + resource-oriented** (RESTful 표준) — 전 EP URL 변경. 프론트 fetch 경로 전부 수정. 작업량 큼 <br>**(B) 현 PascalCase + RPC 스타일 유지** — as-is 연속성. operationId(D-18)만 정리하면 SDK 자동 생성에 영향 없음 <br>권고: **(B)** — 작업량 최소화 + as-is 연속성. 단 `/api/member/sendMailCert` / `/api/member/updateHomeSet`(camelCase) → `/api/member/SendMailCert` / `/api/member/UpdateHomeSet` (PascalCase 통일)만 진행. **근거**: Google AIP-122는 kebab-case 권고이나, 내부 일관성이 더 중요 |
| **결정안** | ☐ |

### D-22. servers URL에 staging/development 누락 (§6-2 잔여)

| 구분 | 내용 |
|------|------|
| **as-is 문서** | 단일 production URL 사용 |
| **현재 API 명세** | 양쪽 스펙 모두 `https://gl.hongcafe.com` (Production) 1개만 명시. staging/development 미정의 |
| **권고안** | 3단계 환경 명시: <br>```yaml<br>servers:<br>  - url: https://gl.hongcafe.com<br>    description: Production<br>  - url: https://stg.gl.hongcafe.com<br>    description: Staging<br>  - url: https://dev.gl.hongcafe.com<br>    description: Development<br>```<br>개발 환경 HTTPS 전환 필요. **근거**: Spectral `owasp:api9:2023-inventory-environment` 2건 error. 프론트 개발/테스트 환경 분리를 위해 필수 |
| **결정안** | ☐ |

---

## 의존 관계 그래프

```
D-02 (보안 스키마 확정)
  ├─ D-03 (쿠키 이름 확정)
  ├─ D-07 (refresh security scheme)
  ├─ D-08 (refresh rotation)
  ├─ D-14 (쿠키 속성)
  └─ D-10 (엔드포인트 중복 — canonical 결정)

D-04 (약관 필드) — 독립 (법적 이슈)
D-05 (비번 재설정) — 독립
D-06 (verify_token) → D-04 연계 (회원가입 우회 방어)
D-09 (에러 응답 스키마) — D-17(탈퇴 사유)에 선행
D-11 (불필요 서버 API) — D-12(계정 열거)와 연계
D-13 (rate-limit) — D-12와 함께 처리
D-18 (operationId) — 독립, 일괄 처리
```

**결정 우선순위**:
1. **D-01 (YAML 버그)** → 즉시 수정 (5분)
2. **D-02 (보안 스키마)** → 최상위 결정. 이후 D-03/07/08/14/10 자동 연계
3. **D-04 (약관 필드)** → 법적 리스크, 즉시 처리
4. **D-05 (재설정 EP)** → 신설 필요
5. **D-09 (에러 응답)** → 공통 컴포넌트 복제로 일괄 처리
6. **나머지 15건** → 우선순위 2~4를 개별 결정

---

## 요약

| Priority | 항목 수 | 누적 | 결정 방식 |
|---------|-------|------|----------|
| P1 Critical | 5 (D-01~D-05) | 5 | 수용 전제 (대안 없음) |
| P2 High (구현 저해) | 6 (D-06~D-11) | 11 | 권고안 수용 또는 대안 |
| P3 High (보안) | 6 (D-12~D-17) | 17 | 권고안 수용 또는 대안 |
| P4 Medium (품질) | 5 (D-18~D-22) | 22 | 권고안 수용 또는 유지 사유 |

**총 22건의 결정 요청**. 의존 관계로 인해 **D-01/D-02/D-04/D-05/D-09** 5건만 먼저 확정되면 나머지 17건의 결정 범위가 자동 좁혀집니다.

---

## 회신 요청 양식

각 D-XX 행의 **결정안** 칼럼을 다음 중 하나로 기재:

- ☐ **권고안 수용** — 권고안대로 수정
- ☐ **대안 제시** — 기재 사유와 대안
- ☐ **유지 (미수정)** — 기재 사유 (법적/기술적/일정상 등)

회신 후 본 문서의 모든 결정안이 확정되면 `backend-api-review.md` v3.0으로 반영하고 프론트 `develop:` 워크플로우가 진입합니다.
