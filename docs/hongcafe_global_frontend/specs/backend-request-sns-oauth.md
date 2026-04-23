# Backend Request — SNS OAuth API 추가/수정 요청 스펙

| 항목 | 내용 |
|------|------|
| 작성자 | 명우현 |
| 요청자 | 명우현 |
| 작성일 | 2026-04-20 |
| 버전 | v1.0 |
| 상태 | Draft |
| 유형 | code / tech |

---

## 1. 개요

프론트엔드(`hongcafe_global_frontend`, Next.js 16)는 Google / Apple / Kakao / Naver / LINE / Facebook 6개 SNS OAuth를 이미 프록시 라우트(`app/api/auth/[provider]/route.js`, `app/api/auth/[provider]/callback/route.js`)로 구현해 두었다. 그러나 현재 **백엔드 API 명세(`docs/specs/auth-api.yaml`, `docs/specs/member-api.yaml`)에는 SNS OAuth 관련 엔드포인트 / 필드 / 쿠키 포맷이 전혀 정의되어 있지 않다.** 본 문서는 프론트 구현과 이미 합의된 암묵적 계약을 백엔드 명세로 명문화하기 위한 요청 스펙이다.

**범위**: 프론트가 자체 처리할 수 있는 부분은 별도 PR에서 이미 반영. 본 문서는 **백엔드가 응답·검증·저장해야 하는 부분**에 한정.

**근거 자료**:
- FFS: `docs/specs/login/ffs.md` (v1.1), `docs/specs/join/ffs.md` (v1.1)
- AS-IS: `docs/specs/hongcafe-japan-analysis.md`, `docs/specs/hongcafe-korea-analysis.md`
- 레거시 상세: `c:/Users/peoplev/Desktop/에이전트 팀 검증/레거시 sns 환경.txt`
- 프론트 OAuth 구현: `lib/oauth/providers.js`, `lib/oauth/client.js`, `lib/oauth/session.js`, `app/api/auth/[provider]/route.js`, `app/api/auth/[provider]/callback/route.js`
- 필드 매핑 기준: `docs/specs/API_FIELD_MAP.md`

---

## 2. 요청 섹션 요약

| # | 요청 제목 | 우선순위 | 유형 |
|---|---|---|---|
| 1 | `/api/auth/{provider}` 진입 엔드포인트 명세 추가 | HIGH | 명세 추가 |
| 2 | `/api/auth/{provider}/callback` 콜백 엔드포인트 명세 추가 | CRITICAL | 명세 추가 |
| 3 | `existFlag` 값 정의 명문화 (0 / 3 / 4) | CRITICAL | 명세 추가 |
| 4 | `hc_sns_pending` 쿠키 포맷 명세 | HIGH | 명세 추가 |
| 5 | `/api/members/join-user` body에 `captchaToken` 필드 추가 | CRITICAL | 필드 추가 + 검증 로직 |
| 6 | 국가별 OAuth redirect URI 분기 (en.hongcafe.com / jp.hongcafe.com) | HIGH | 구현 추가 |
| 7 | Apple Private Relay 처리 정책 확정 | MEDIUM | 정책 확정 |
| 8 | SNS 이메일 재검증 정책 확정 | MEDIUM | 정책 확정 |

---

## 3. §1. `/api/auth/{provider}` — 진입 엔드포인트 명세 추가 [HIGH]

### 현재 상태
- 프론트는 `GET /api/auth/{provider}`를 Next.js Route Handler로 자체 처리하여 외부 provider authorize URL로 302 redirect.
- 백엔드 API 명세(`auth-api.yaml`)에 존재하지 않음 → 프론트-백엔드 계약이 문서화되지 않음.

### 요청 내용
`docs/specs/auth-api.yaml`에 다음 엔드포인트를 추가해 달라. **실제 구현은 프론트 Next.js Route Handler가 담당하므로 백엔드 서버에서 새로 만들 필요는 없다.** 명세 합의만 필요.

### 엔드포인트 스펙
```yaml
/api/auth/{provider}:
  get:
    summary: SNS OAuth 진입 (authorize URL 리다이렉트)
    parameters:
      - in: path
        name: provider
        required: true
        schema:
          type: string
          enum: [google, apple, kakao, naver, line, facebook]
    responses:
      '302':
        description: provider의 authorize URL로 리다이렉트
        headers:
          Location:
            schema: { type: string, format: uri }
          Set-Cookie:
            description: |
              다음 4개 쿠키를 각각 Set-Cookie 헤더로 발급.
              모두 HttpOnly=true, SameSite=Lax, Path=/, Max-Age=600.
              production 환경에서는 Secure=true.
              - hc_oauth_state: CSRF 방어용 랜덤 값 (32바이트 base64url)
              - hc_oauth_verifier: PKCE code verifier (Google/LINE만 발급, Apple/Kakao/Naver/Facebook은 생략)
              - hc_oauth_provider: providerId (기대 콜백과 일치 검증)
              - hc_oauth_return_to: locale (en/ja/ko)
      '400':
        description: invalid_provider
      '500':
        description: oauth_start_failed
```

### 기대 응답 스키마
302 redirect만 반환. body 없음.

---

## 4. §2. `/api/auth/{provider}/callback` — 콜백 엔드포인트 명세 추가 [CRITICAL]

### 현재 상태
- 프론트는 `GET /api/auth/{provider}/callback` (모든 provider) + `POST /api/auth/{provider}/callback` (Apple `response_mode=form_post`) 핸들러를 자체 구현.
- 콜백 내부에서 **백엔드 API를 직접 호출**:
  - `POST ${NEXT_PUBLIC_API_URL}/api/members/check-id` `{ acId: <email> }` — 이메일 존재 여부 조회 (OK=미존재, 409=존재)
  - `POST ${NEXT_PUBLIC_API_URL}/api/members/join-user` `{ acId, acNick, snsType, acSnsId, acCountry, agreeService/Privacy/Age }` — 기가입자 자동 로그인 or 신규 가입
- 백엔드 명세에 콜백 엔드포인트와 그 내부 백엔드 호출 계약이 명문화되어 있지 않음.

### 요청 내용
1. `docs/specs/auth-api.yaml`에 콜백 엔드포인트를 **"프론트 owns, 백엔드 내부 호출 계약만 명시"** 형식으로 추가.
2. 콜백이 호출하는 백엔드 엔드포인트 2종 (`check-id`, `join-user`의 SNS 자동가입 플로우)을 `member-api.yaml`에 명시.

### 엔드포인트 스펙
```yaml
/api/auth/{provider}/callback:
  get:
    summary: SNS OAuth 콜백 (GET — Apple 제외 모든 provider)
    parameters:
      - in: path
        name: provider
        required: true
        schema: { type: string, enum: [google, kakao, naver, line, facebook] }
      - in: query
        name: code
        schema: { type: string }
      - in: query
        name: state
        schema: { type: string }
      - in: query
        name: error
        schema: { type: string }
    responses:
      '302':
        description: |
          - 기가입자 자동 로그인 성공 → /{locale}/ (홈)
            Set-Cookie: hc_access, hc_refresh, hc_csrf, hdata (백엔드 join-user 응답을 프론트가 포워딩)
          - 신규 가입 대상 → /{locale}/join/{provider}
            Set-Cookie: hc_sns_pending (JWT, 10분)
          - 실패/에러 → /{locale}/login?error=oauth_{providerId}_{reason}
  post:
    summary: SNS OAuth 콜백 (POST — Apple response_mode=form_post 전용)
    parameters:
      - in: path
        name: provider
        required: true
        schema: { type: string, enum: [apple] }
    requestBody:
      content:
        application/x-www-form-urlencoded:
          schema:
            type: object
            properties:
              code: { type: string }
              state: { type: string }
              error: { type: string }
              user:
                description: Apple 최초 로그인 시에만 제공되는 name/email JSON 문자열
                type: string
```

### 콜백 내부에서 호출되는 백엔드 API (CRITICAL — 명세화 필요)

#### (a) `POST /api/members/check-id`
```yaml
/api/members/check-id:
  post:
    summary: 이메일 존재 여부 조회 (SNS 자동 로그인 분기용)
    requestBody:
      content:
        application/json:
          schema:
            type: object
            required: [acId]
            properties:
              acId: { type: string, format: email }
    responses:
      '200': { description: 이메일 미존재 (신규 가입 대상) }
      '409': { description: 이메일 존재 (SNS 자동 로그인 분기) }
      '400': { description: 이메일 형식 오류 }
```

#### (b) `POST /api/members/join-user` — SNS 자동 로그인 분기
기존 `member-api.yaml` §6의 join-user 스펙은 그대로이되 **응답의 `existFlag`와 Set-Cookie를 반드시 내려줘야** 함 (§5 참조).

---

## 5. §3. `existFlag` 값 정의 명문화 [CRITICAL]

### 현재 상태
- `member-api.yaml` / `member-api.md`에 `existFlag` 필드가 존재하나 **값의 의미가 정의되어 있지 않음**.
- 프론트는 현재 다음 값으로 분기하고 있음 (`app/api/auth/[provider]/callback/route.js:68-71`):
  ```js
  const flag = joinData?.data?.exist_flag;
  if (flag === 0 || flag === 3 || flag === 4) {
      return { setCookies: extractSetCookies(joinRes) };
  }
  ```

### 요청 내용
다음 값 의미를 `member-api.yaml`의 `join-user` 응답 스키마에 명문화.

| existFlag | 의미 | 프론트 분기 |
|-----------|------|-------------|
| `0` | 신규 가입 완료 (최초 호출) | Set-Cookie 포워딩 → 자동 로그인 → 홈 |
| `1` | (정의 필요) | — |
| `2` | (정의 필요) | — |
| `3` | 재가입 (탈퇴 후 복구) | Set-Cookie 포워딩 → 자동 로그인 → 홈 |
| `4` | 기가입 (이메일 존재, SNS 연동 완료) | Set-Cookie 포워딩 → 자동 로그인 → 홈 |
| 그 외 | 예외 (신규 가입 실패 등) | `hc_sns_pending` 발급 → `/join/{provider}` prefill 폼 |

**백엔드에 요청**:
1. `1`, `2`의 의미를 정의하거나, 미사용이면 명시적으로 "미사용"임을 기록.
2. `existFlag === 0|3|4` 시 반드시 Set-Cookie로 `hc_access`, `hc_refresh`, `hc_csrf`, `hdata`를 발급해야 함을 명시.
3. `existFlag`가 위 값 외이면 Set-Cookie를 발급하지 않아야 함 (프론트가 잘못된 상태로 로그인 처리하는 것 방지).

### 관련 응답 필드 (확정 필요)
```yaml
JoinUserResponse:
  type: object
  properties:
    data:
      type: object
      properties:
        exist_flag:
          type: integer
          enum: [0, 1, 2, 3, 4]
          description: |
            0: 신규 가입 완료
            1: (미정 — 확정 필요)
            2: (미정 — 확정 필요)
            3: 재가입 (탈퇴 복구)
            4: 기가입 (SNS 자동 로그인)
```

---

## 6. §4. `hc_sns_pending` 쿠키 포맷 명세 [HIGH]

### 현재 상태
프론트가 `lib/oauth/session.js`에서 HS256 JWT를 서명하여 10분 TTL 쿠키로 발급. 백엔드는 이 쿠키를 **읽지 않아도 됨** (프론트 전용). 하지만 명세에 기록되어 있지 않아 devops/백엔드가 쿠키 설정 변경 시 인지 불가.

### 요청 내용
`auth-api.yaml`에 다음 쿠키 스펙을 Components/parameters에 추가.

```yaml
components:
  parameters:
    HcSnsPendingCookie:
      in: cookie
      name: hc_sns_pending
      description: |
        OAuth 콜백 성공 후 /join/{provider} 페이지로 SNS 프로필을 안전 전달하는 JWT 쿠키.
        PII(email, nickname)를 URL query로 전달 금지(§22-38) → HttpOnly JWT 쿠키로 전달.
        백엔드는 이 쿠키를 사용하지 않으며, 프론트 Server Component에서만 verifyPendingSnsPayload()로 검증.

        Algorithm: HS256
        Signing key: OAUTH_COOKIE_SECRET (프론트 환경변수, 최소 32바이트)
        Max-Age: 600 (10분)
        HttpOnly: true
        SameSite: Lax
        Path: /
        Secure: production only

        Payload:
          provider: string (google | apple | kakao | naver | line | facebook)
          providerUserId: string (SNS 계정 고유 ID)
          email: string (SNS 프로필 이메일, Apple Private Relay의 경우 @privaterelay.appleid.com)
          nickname: string (SNS 프로필 닉네임)
          iat: integer (발급 타임스탬프)
          exp: integer (만료 타임스탬프, iat + 600)
      schema:
        type: string
```

---

## 7. §5. `/api/members/join-user` `captchaToken` 필드 추가 [CRITICAL]

### 현재 상태
- 프론트 SnsJoinForm.js / EmailJoinForm.js는 `ReCaptchaEnterprise` 컴포넌트로 토큰을 발급만 하고 `captchaToken`을 **`join-user` 요청 body에 포함시키지 않음**.
- 백엔드 `member-api.yaml`의 `join-user` request schema에 `captchaToken` 필드 **부재**.
- 결과: reCAPTCHA 토큰이 발급되지만 실제로 검증되지 않음 → 봇 가입 방어 실효성 없음.

### 요청 내용
1. `member-api.yaml`의 `JoinUserRequest` 스키마에 `captchaToken` 필드를 추가 (optional 아닌 `required`).
2. 백엔드 서버는 join-user 수신 시 Google reCAPTCHA Enterprise `projects.assessments.create` API 호출하여 검증.
3. 검증 실패 시 HTTP 400 반환.

### 스키마 변경 요청
```yaml
JoinUserRequest:
  type: object
  required: [acId, acNick, crPhone, agreeService, agreePrivacy, agreeAge, captchaToken]
  properties:
    # (기존 필드들)
    captchaToken:
      type: string
      description: |
        reCAPTCHA Enterprise site key로 생성된 action 토큰.
        action 값:
          - signup_email (이메일 회원가입)
          - signup_sns (SNS 회원가입)
          - signup_sns_auto (OAuth 콜백 자동 가입)
        백엔드는 createAssessment 호출 후 score ≥ 0.5 일 때만 진행.
```

### 검증 프로세스 (백엔드 구현)
```
POST https://recaptchaenterprise.googleapis.com/v1/projects/{PROJECT_ID}/assessments?key={API_KEY}
Body: {
  "event": {
    "token": "<captchaToken>",
    "siteKey": "<SITE_KEY>",
    "expectedAction": "signup_email" | "signup_sns" | "signup_sns_auto"
  }
}
Response: { tokenProperties: { valid: true, action: "..." }, riskAnalysis: { score: 0.0~1.0 } }

판정 로직:
- tokenProperties.valid === false → 400 INVALID_CAPTCHA
- tokenProperties.action !== expectedAction → 400 CAPTCHA_ACTION_MISMATCH
- riskAnalysis.score < 0.5 → 400 CAPTCHA_LOW_SCORE
- 이외 → 진행
```

### OAuth 자동 가입 (tryAutoLogin)에도 적용?
현재 OAuth 콜백의 자동 가입은 `captchaToken` 없이 진행됨. 두 가지 옵션 중 정책 확정 요청:
- **옵션 A**: 자동 가입 플로우는 captchaToken 생략 허용 (OAuth 자체가 신뢰 기반)
- **옵션 B**: 자동 가입도 captchaToken 필수 (프론트 콜백에서 사전 발급 필요)

**권고**: 옵션 A — OAuth는 이미 state 검증 + provider 측 인증을 거쳤으므로 추가 captcha가 중복. 단 IP 레이트리밋은 백엔드에서 별도 적용.

---

## 8. §6. 국가별 OAuth redirect URI 분기 [HIGH]

### 현재 상태
- 프론트 `lib/oauth/providers.js`는 `OAUTH_REDIRECT_BASE` 환경변수 **단일 값**으로 모든 provider의 redirect URI를 생성.
- hostname 기반 i18n 정책(CLAUDE.md: `en.hongcafe.com` / `jp.hongcafe.com`)에서 호스트별 redirect URI가 달라야 함에도 단일 base로만 동작.
- 결과: 개발 환경(`http://localhost:3000`)은 OK. 운영 환경에서 `en` 접속자가 `jp` redirect URI로 돌아올 위험.

### 요청 내용
1. **Provider 콘솔 등록**: Google / Apple / Kakao / Naver / LINE / Facebook 각 콘솔에 `https://en.hongcafe.com/api/auth/{provider}/callback`과 `https://jp.hongcafe.com/api/auth/{provider}/callback` 두 redirect URI를 모두 등록해 주세요. Kakao/Naver는 한국 전용이므로 운영 로드맵에서 빠질 수 있음(EN/JP만 지원).
2. **프론트 수정**은 별도 태스크로 처리 예정. 백엔드/인프라 측 요청 사항:
   - (운영) Route53 / CloudFront / Nginx 등에서 `en.hongcafe.com`, `jp.hongcafe.com` 두 호스트를 Next.js 서버로 라우팅.
   - (운영) 각 호스트의 OAuth provider app registration에서 redirect URI 중복 등록 완료.
3. **CORS / CSP**: Apple `form_post` POST 콜백이 정상 도달하도록 `Content-Security-Policy`의 `frame-ancestors`, `form-action`에 apple 도메인 허용.

### 운영 점검 체크리스트
- [ ] en.hongcafe.com, jp.hongcafe.com 두 호스트에 SSL 인증서 설치
- [ ] provider 콘솔에 redirect URI 중복 등록
- [ ] Next.js 환경변수: `NEXT_PUBLIC_API_URL`, `OAUTH_REDIRECT_BASE`는 호스트별로 다르게 설정되어야 함 → 같은 Node 프로세스가 두 호스트를 서빙하면 `request.headers.host` 기반 동적 결정 필요

---

## 9. §7. Apple Private Relay 처리 정책 확정 [MEDIUM]

### 현재 상태
- Apple Sign-In은 사용자가 "Hide My Email" 선택 시 `@privaterelay.appleid.com` 이메일을 프로필로 반환.
- 프론트는 해당 이메일을 그대로 `acId`로 받아 `join-user`에 전송.
- 백엔드는 해당 이메일의 처리 방식이 명세에 정의되어 있지 않음.

### 요청 내용
다음 정책 중 하나를 확정하고 `member-api.yaml`에 기록해 주세요.

#### 옵션 A — Private Relay 이메일 수용 (권고)
- `@privaterelay.appleid.com` 이메일을 그대로 저장.
- 로그인 / 알림 이메일 발송 시 Apple이 실제 사용자 이메일로 중계.
- **유의**: 사용자가 추후 Apple ID에서 "Hide My Email" 해제 시 이메일 변경 불가(Apple 정책). 백엔드 `members` 테이블에 `is_private_relay: boolean` 컬럼 추가 고려.

#### 옵션 B — Private Relay 거부
- `@privaterelay.appleid.com` 감지 시 400 반환.
- 프론트는 에러 메시지로 "Apple 이메일 공개를 선택해 주세요" 안내.
- **유의**: Apple 정책상 사용자 선택권 제한이므로 UX 저하.

### 추가 고려사항
- Apple 최초 로그인 시 `user` form 필드에 `{ name: { firstName, lastName }, email }` JSON이 들어오나, **재로그인 시에는 없음** → 최초 로그인 시 백엔드가 `tb_member_sns_raw` 같은 별도 테이블에 원본 저장 권고.

---

## 10. §8. SNS 이메일 재검증 정책 확정 [MEDIUM]

### 현재 상태
- 프론트는 SNS 제공자가 반환한 이메일을 **신뢰**하여 `join-user`에 그대로 전달.
- Email OTP 검증(`send-mail-cert` / `confirm-mail-cert`)은 `EmailJoinForm` 가입 경로에서만 사용.
- SNS 프로필 이메일의 실제 소유 증명은 provider가 담당하므로 일반적으로 신뢰해도 됨.

### 요청 내용
다음 정책 중 하나를 확정하고 `member-api.yaml`에 기록.

#### 옵션 A — SNS 이메일 신뢰 (권고, 현재 프론트 구현과 일치)
- Google / LINE / Facebook / Naver / Kakao: `email_verified: true` 플래그 반환 시 신뢰.
- Apple: `email_verified: true` 플래그 반환 시 신뢰 (Apple은 항상 true).
- `email_verified: false` 또는 플래그 없음 → 400 반환 or `crMailCert` OTP 재검증 요구.

#### 옵션 B — 항상 OTP 재검증
- SNS 가입 시에도 OTP 검증 강제.
- **유의**: UX 저하, provider 이메일이 이미 검증된 경우 중복 요청.

### 관련 필드
```yaml
JoinUserRequest:
  properties:
    crMailCert:
      type: string
      enum: [Y, N]
      description: |
        이메일 OTP 검증 완료 여부.
        옵션 A 채택 시: SNS 가입은 생략 허용. 이메일 가입은 필수 Y.
        옵션 B 채택 시: 항상 Y 필수.
```

---

## 11. 프론트엔드 현재 동작 요약 (백엔드 담당자 참고용)

| 단계 | 프론트 동작 | 백엔드 호출 | 기대 응답 |
|------|------------|-------------|-----------|
| 1. 버튼 클릭 | `window.location.href = '/api/auth/{provider}'` | — | — |
| 2. 진입 | Next.js Route Handler에서 provider authorize URL로 302 | — | — |
| 3. 사용자 인증 | SNS provider에서 인증 | — | — |
| 4. 콜백 수신 | Next.js Route Handler가 code+state 수신 | — | — |
| 5. state 검증 | 쿠키 state vs query state 비교 | — | — |
| 6. 토큰 교환 | provider token endpoint에 직접 POST | — | access_token 등 |
| 7. 프로필 조회 | provider userinfo API 직접 호출 | — | email, name 등 |
| 8. 이메일 조회 | — | `POST /api/members/check-id {acId}` | 200/409 |
| 9-A. 기가입: 자동 로그인 | 200일 때 null, 409일 때 join-user 호출 | `POST /api/members/join-user {acId, acNick, snsType, acSnsId, acCountry, agreeService=1/Privacy=1/Age=1}` | `{data:{exist_flag: 0|3|4}, Set-Cookie: hc_access/hc_refresh/hc_csrf/hdata}` |
| 9-B. 신규 사용자 | existFlag != 0/3/4 or 위 단계 실패 | — | — |
| 10. 가입 폼 | `hc_sns_pending` JWT 발급 후 `/join/{provider}` 리다이렉트 | — | — |
| 11. 사용자 가입 완료 | SnsJoinForm 제출 | `POST /api/members/join-user {acId, acNick, crPhone, birthYear/Month/Day, snsType, acSnsId, acCountry, agreeService/Privacy/Age, captchaToken}` | `{data:{exist_flag: 0}, Set-Cookie: hc_access/hc_refresh/hc_csrf/hdata}` |

---

## 12. 에러 응답 규격 (프론트 사용자 친화 메시지와 매핑됨)

프론트는 콜백 실패 시 `?error=oauth_{providerId}_{reason}` 쿼리로 `/login` 리다이렉트. 다음 reason 값이 현재 프론트가 처리하는 케이스이므로 백엔드가 에러 응답 시 준수해 주세요.

| reason | 의미 | 발생 위치 |
|--------|------|----------|
| `access_denied` | 사용자가 provider 동의 거부 | provider → 콜백 query `error` |
| `state_mismatch` | CSRF state 쿠키와 query 불일치 | 프론트 콜백 |
| `invalid_provider` | 잘못된 providerId | 프론트 진입/콜백 |
| `token_exchange_failed` | provider token endpoint 실패 | 프론트 client.js |
| `user_info_failed` | provider userinfo 실패 | 프론트 client.js |
| `missing_code` | query에 code 누락 | 프론트 콜백 |
| `server_error` | 기타 예외 | 프론트 콜백 |

프론트 `hc_sns_pending` 만료 시에는 `?error=oauth_session_expired`로 처리 (providerId 없음).

---

## 13. 트레이드오프

| # | 트레이드오프 | 선택 |
|---|-------------|------|
| 1 | 프론트-owned OAuth vs 백엔드-owned OAuth | 프론트-owned (Next.js SSR 기반, Apple form_post 대응 용이). 백엔드는 check-id/join-user만 담당. |
| 2 | Private Relay 수용 vs 거부 | 수용 (§7 옵션 A) — Apple 정책상 사용자 선택권 존중 |
| 3 | SNS OTP 재검증 강제 vs 신뢰 | 신뢰 (§8 옵션 A) — UX 및 provider 검증 신뢰성 기반 |
| 4 | captchaToken 자동가입 필수 vs 옵셔널 | 옵셔널 (§5 옵션 A) — OAuth state 검증으로 충분 |
| 5 | existFlag 1/2 정의 강제 vs 미사용 명시 | 백엔드 확정 요청 — 현재 미사용이면 명시적으로 "미사용"으로 기록 |

---

## 14. 실행 계획

프론트 측 작업 (이미 별도 PR에서 반영):
- [x] JoinMethods.js Google/Apple 버튼 onClick 연결
- [x] LoginForm.js에 `?error=oauth_...` 쿼리 수신 · 친화 메시지 표시
- [x] join/[provider]/page.js 에 `hc_sns_pending` 만료 시 `/login?error=oauth_session_expired`로 리다이렉트

백엔드 측 작업 (본 문서에서 요청):
- [ ] §1-4: `auth-api.yaml`에 OAuth 진입/콜백/쿠키 스펙 추가
- [ ] §3: `member-api.yaml` `JoinUserResponse.existFlag` 값 정의 명문화 (1, 2 미사용 명시 or 정의)
- [ ] §2: `member-api.yaml`에 `POST /api/members/check-id` 엔드포인트 추가
- [ ] §5: `JoinUserRequest`에 `captchaToken` 필드 추가 + 백엔드 검증 로직 구현
- [ ] §6: Provider 콘솔 redirect URI 등록 (en.hongcafe.com / jp.hongcafe.com)
- [ ] §7: Apple Private Relay 정책 확정 (권고: 수용)
- [ ] §8: SNS 이메일 재검증 정책 확정 (권고: 신뢰)

---

## 15. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-20 | 최초 작성 | 명우현 |
