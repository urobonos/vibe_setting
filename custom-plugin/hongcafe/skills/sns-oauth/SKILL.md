---
name: sns-oauth
description: >
  SNS OAuth(kakao/naver/google/apple) 표준 패턴 스킬 — provider 신규 추가, 기존 flow 검증, 콜백/토큰/회원가입 연계 디버깅.
  4-provider 매트릭스(필수 필드·scope·callback·식별 키)를 SSOT 로 보유하고, encrypted payload 규약(AES-256-CBC + 매번 랜덤 IV, security-audit §7-6 준수)·이메일 충돌 처리·계정 연결(account-link) 흐름을 표준화한다.
  3개 모드 — `add` (provider 신규 추가 체크리스트), `verify` (기존 provider flow 5축 정합성 검증), `debug` (콜백 실패·토큰 만료·식별 키 불일치 가설 우선순위).
  자동 트리거 (SNS/소셜 로그인·OAuth provider 키워드) + `/sns-oauth` 슬래시 커맨드. 호출 주체 = Claude 본체. 산출물 = `output/sns-oauth/` 단일 마크다운.
triggers:
  - "SNS 로그인"
  - "SNS 가입"
  - "SNS 연동"
  - "소셜 로그인"
  - "소셜 가입"
  - "소셜 연동"
  - "OAuth 추가"
  - "OAuth 검증"
  - "OAuth 디버그"
  - "OAuth 콜백"
  - "OAuth provider"
  - "카카오 로그인"
  - "네이버 로그인"
  - "구글 로그인"
  - "애플 로그인"
  - "kakao oauth"
  - "naver oauth"
  - "google oauth"
  - "apple oauth"
  - "kakao login"
  - "naver login"
  - "google login"
  - "apple login"
  - "account link"
  - "계정 연결"
  - "이메일 힌트"
  - "email hint"
  - "/sns-oauth"
version: 1.0.0
user-invocable: true
depends_on: [security-audit, php8, mysql8, global-context, task-docs]
conflicts_with: []
min_claude_md_version: "4.0"
---

# SNS OAuth Skill

SNS OAuth provider(kakao / naver / google / apple) 의 **신규 추가**, **기존 flow 검증**, **콜백/토큰/식별 키 디버깅** 을 표준 절차로 수행한다.

> **[용도 한정]** SNS OAuth provider · email-hint · encrypted payload · account-link 흐름이 명시적으로 등장한 경우에만 호출. 일반 인증/세션/JWT 단독 작업(쿠키 prefix·CSRF·refresh token rotation) 은 본 스킬 대상이 아니다 — `security-audit` §7-3·§7-4 사용.
> **Why:** SNS OAuth 는 provider 별 응답 스키마·식별 키·토큰 만료가 모두 달라 매번 cold context 로 재구성하면 (1) 식별 키 혼동(Kakao `id` vs Apple `sub`) 으로 동일 사용자 중복 가입, (2) email-hint 누락으로 회원가입 흐름 분기 실패, (3) encrypted payload IV 재사용 같은 보안 결함이 반복 발생한다. 본 스킬은 이 4 provider 의 차이를 SSOT 표로 고정해 동일 결함의 재발을 차단한다.

> **[실행 주체]** Claude 본체 단독. 본 스킬은 *분석·체크리스트 도구* 이지 멀티 Agent 오케스트레이션이 아니다. 풀스택 영향 분석이 별도로 필요하면 `api-team` 을 병행 호출.

---

## 1. 호출 방식

### 1.1. 자동 트리거

frontmatter `triggers` 매칭 시 즉시 호출. 모호한 경우 한 줄 확인 후 진행.

**트리거 예시 (호출됨):**
- "카카오 로그인 추가하려는데 회원가입 흐름 정리"
- "애플 OAuth 콜백이 invalid_client 떨어지는데 디버그"
- "네이버 식별 키랑 이메일 힌트 처리 검증"

**트리거 안 됨 (의도된 차단):**
- "JWT refresh token 갱신 주기 어떻게 해야 함?" → security-audit §7-4
- "쿠키 prefix 바꿔야 함" → security-audit §7-3
- "로그인 API 라우트 추가" → api-team (provider 정보 없으면 일반 API)

### 1.2. 슬래시 커맨드

```
/sns-oauth add {provider}                — provider 신규 추가 체크리스트
/sns-oauth verify {provider} [flow]      — 기존 flow 5축 정합성 검증
/sns-oauth debug {provider} [에러 코드]  — 콜백/토큰/식별 키 가설 우선순위
```

`{provider}` ∈ `kakao | naver | google | apple`. `[flow]` ∈ `login | signup | link` (생략 시 전체).

예: `/sns-oauth add line` / `/sns-oauth verify kakao signup` / `/sns-oauth debug apple invalid_client`

---

## 2. 4-Provider 매트릭스 (SSOT)

| 항목 | Kakao | Naver | Google | Apple |
|------|-------|-------|--------|-------|
| **OAuth 프로토콜** | OAuth 2.0 (Authorization Code) | OAuth 2.0 (Authorization Code) | OAuth 2.0 + OIDC | OAuth 2.0 + OIDC (form_post) |
| **Authorization URL** | `kauth.kakao.com/oauth/authorize` | `nid.naver.com/oauth2.0/authorize` | `accounts.google.com/o/oauth2/v2/auth` | `appleid.apple.com/auth/authorize` |
| **Token URL** | `kauth.kakao.com/oauth/token` | `nid.naver.com/oauth2.0/token` | `oauth2.googleapis.com/token` | `appleid.apple.com/auth/token` |
| **Userinfo URL** | `kapi.kakao.com/v2/user/me` | `openapi.naver.com/v1/nid/me` | `openidconnect.googleapis.com/v1/userinfo` | (id_token JWT 디코드 — userinfo EP 없음) |
| **식별 키 (sub)** | `id` (Long, provider 고유) | `response.id` (String) | `sub` (String) | `sub` (String, 앱당 고유) |
| **이메일 필드** | `kakao_account.email` (선택 동의) | `response.email` | `email` | `email` (id_token claim, 첫 동의 후 응답에서 제거) |
| **이메일 검증 여부** | `kakao_account.is_email_verified` | (응답 없음 — 가입 시점 검증된 것으로 간주) | `email_verified` | `email_verified` (id_token claim) |
| **이름 필드** | `kakao_account.profile.nickname` | `response.name` / `response.nickname` | `name` / `given_name` / `family_name` | `name.firstName` + `name.lastName` (첫 동의 시만) |
| **scope 필수** | `account_email` (선택 동의 시 별도 처리) | `name,email` | `openid email profile` | `name email` (response_mode=form_post 강제) |
| **Callback HTTP Method** | GET | GET | GET | **POST** (form_post) ⚠️ |
| **토큰 만료 (Access)** | 21,600초 (6시간) | 3,600초 (1시간) | 3,600초 (1시간) | 3,600초 (1시간) |
| **Refresh Token 만료** | 5,184,000초 (60일) | 365일 | 무제한 (revoke 시까지) | 5,184,000초 (60일) |
| **client_secret 형식** | 평문 문자열 | 평문 문자열 | 평문 문자열 | **JWT (ES256, kid 헤더, 6개월 만료 권장)** ⚠️ |
| **PKCE 지원** | 지원 | 미지원 | 권장 | 지원 |
| **공식 문서** | developers.kakao.com/docs/latest/ko/kakaologin | developers.naver.com/docs/login/api | developers.google.com/identity/openid-connect/openid-connect | developer.apple.com/documentation/sign_in_with_apple |

**⚠️ Apple 특이사항:**
- `client_secret` 은 매번 ES256 JWT 로 동적 생성 (Team ID, Key ID, Private Key `.p8` 필요). 6개월 만료 — 자동 갱신 로직 필수.
  **Why:** 정적 client_secret 운용 시 6개월 만료 시점에 모든 Apple 로그인이 일제히 `invalid_client` 로 실패하며, 운영 중 장애 신호 없이 사용자 로그인만 막혀 발견·복구 지연이 매출·신뢰 손실로 직결된다.
- callback 이 **POST form_post** 이므로 라우트는 `POST` 로 등록, CSRF 면제 처리 필요 (state 파라미터 검증으로 대체).
  **Why:** Apple 만 `response_mode=form_post` 를 강제해 callback 이 POST 로 도달 — GET 라우트만 등록하면 405 Method Not Allowed 로 모든 Apple 콜백이 실패하고, CSRF 필터를 그대로 적용하면 외부 provider POST 가 토큰 부재로 거부된다.
- `name`/`email` 은 **최초 동의 1회만** 응답 — 재동의 시 누락. 가입 시점에 반드시 DB 저장.
  **Why:** Apple 은 사용자 프라이버시 정책상 두 번째 동의부터 name/email 을 응답 페이로드에서 제거하므로, 첫 응답을 저장하지 않으면 재로그인·재가입 시 사용자 정보 영구 소실 (DB 에 식별 키만 남고 이메일·이름 없음).

**⚠️ Kakao 특이사항:**
- `email` 은 비즈 채널 등록·검수 통과 후에만 동의 항목 활성화. 미통과 상태에서 scope 요청 시 에러.
- `is_email_verified` 가 false 인 경우 회원가입 분기에서 **이메일 추가 인증 흐름** 진입 필요.

---

## 3. 표준 흐름 (3-flow)

### 3.1. login flow (기존 회원 로그인)

```
1. FE: provider 인증 페이지 redirect (state 파라미터 포함, CSRF 방어)
2. provider → callback URL 으로 code 반환
3. BE: code → token URL 교환 → userinfo 조회 (Apple 은 id_token JWT 디코드)
4. BE: provider 식별 키 (sub/id) 로 DB 사용자 조회
   ├─ 존재 → JWT 발급 + HttpOnly 쿠키 set + redirect (홈)
   └─ 부재 → 401 + email-hint 응답 (회원가입 유도)
5. FE: 응답에 email-hint 포함 시 회원가입 페이지로 redirect (이메일 prefill)
```

### 3.2. signup flow (신규 회원 가입)

```
1. FE: provider 인증 페이지 (login flow 와 동일)
2. callback → BE token 교환 → userinfo
3. BE: 식별 키로 DB 조회 → 부재 확인
4. BE: 이메일로 기존 회원 조회 (다른 provider 로 가입한 경우)
   ├─ 존재 → "이미 {다른 provider} 로 가입됨" 응답 (account-link 안내)
   └─ 부재 → 신규 가입 처리 (encrypted payload 로 provider 정보 + 이메일 저장)
5. 약관 동의 화면 → 추가 정보 입력 → 회원 생성 → JWT 발급
```

### 3.3. link flow (기존 회원 ↔ 추가 provider 연결)

```
1. 로그인 상태에서 provider 인증 (state 에 user_id HMAC 포함)
2. callback → token 교환 → userinfo → 식별 키 추출
3. BE: 식별 키 중복 확인 (다른 사용자가 이미 연결한 provider 인지)
   ├─ 중복 → 400 + "이미 다른 계정에 연결됨"
   └─ 없음 → user_provider 테이블에 연결 row 추가 (encrypted)
4. 응답: 연결된 provider 목록 갱신
```

---

## 4. Encrypted Payload 규약

provider userinfo · refresh token · 식별 키 등 민감 정보를 DB 저장 시 암호화한다.

| 항목 | 규칙 |
|------|------|
| **알고리즘** | AES-256-CBC (security-audit §7-6 SSOT) |
| **IV** | **매 암호화마다 랜덤 IV 생성** — IV 재사용 금지 |
| **저장 형식** | `base64(IV ‖ ciphertext)` — IV 16바이트 prefix |
| **키 관리** | `.env` `OAUTH_ENCRYPTION_KEY` (256bit hex). 키 로테이션 시 `OAUTH_ENCRYPTION_KEY_PREV` 병행 보유 |
| **CI4 구현** | `Config\Encryption` 명시. `service('encrypter')` DI 사용, `new Encrypter()` 금지 (php8 §DI 룰) |
| **암호화 대상** | `provider_user_id`(= 식별 키), `provider_email`, `refresh_token`, `id_token` (Apple) |
| **암호화 제외** | `provider_name`(kakao/naver/google/apple 평문), `linked_at`(timestamp), `user_id`(FK) |

**Why IV 재사용 금지:** 동일 IV 재사용 시 같은 평문이 같은 암호문을 만들어 패턴 분석으로 키·평문 추론이 가능해진다 (CBC 모드 IV 재사용 = chosen-plaintext 공격 노출 — security-audit §7-6 일치).

---

## 5. 회원가입 연계 (이메일 충돌 처리)

OAuth provider 로 가입 시도 시 동일 이메일로 다른 provider 가입 이력이 있을 수 있다. 4가지 분기를 표준화한다.

| 케이스 | 처리 |
|--------|------|
| **신규 이메일** | 정상 가입 흐름 진행 |
| **동일 provider 식별 키 일치** | 로그인 처리 (signup 이 아니라 login flow 로 전환) |
| **동일 이메일, 다른 provider** | 400 응답 + "이미 {기존 provider} 로 가입됨" + account-link 안내 |
| **이메일 동의 거부 (Kakao)** | 이메일 추가 인증 흐름 진입 (별도 폼) |

**email-hint 응답 형식:**

```json
{
  "code": "OAUTH_USER_NOT_FOUND",
  "data": {
    "provider": "kakao",
    "email_hint": "u****@gmail.com",
    "signup_token": "{HMAC-signed JWT, 5min TTL}"
  }
}
```

- `email_hint` 는 마스킹 (앞 1자 + `****` + 도메인). 전체 이메일 노출 금지.
- `signup_token` 은 BE 가 발급한 단기 JWT — 회원가입 호출 시 검증해 OAuth → signup 흐름 연속성 보장 + state 위조 차단.

---

## 6. 모드별 산출물

### 6.1. add 모드 — `{date}-{provider}-add.md`

**입력:** provider 이름 (예: `line`)
**산출물:** 신규 provider 추가 체크리스트 (BE + FE + 인프라 + DB + 보안 + 테스트)

체크리스트 표 항목 (≥40 개):
- 환경변수 (`.env.example`): `{PROVIDER}_CLIENT_ID`, `{PROVIDER}_CLIENT_SECRET`, `{PROVIDER}_REDIRECT_URI`
- 라우트: `GET /v1/auth/oauth/{provider}/authorize`, `GET|POST /v1/auth/oauth/{provider}/callback`
- Service: token 교환 / userinfo 조회 / id_token 검증 (OIDC 인 경우)
- Repository: `user_provider` row CRUD (encrypted)
- DB 마이그레이션: `provider` enum 확장
- 보안: state 파라미터 HMAC 서명, code → token 교환 시 PKCE (가능한 provider 만), client_secret 동적 생성 (Apple 식)
- FE: provider 버튼 추가, redirect 처리, email-hint 응답 핸들링
- i18n: provider 이름 번역 키 (`auth.provider.{name}`)
- phpunit: token 교환 mock, userinfo 디코드, 식별 키 충돌, 이메일 충돌, encrypted payload 라운드트립
- 인프라: provider 도메인 outbound SG 허용, redirect_uri 콘솔 등록

### 6.2. verify 모드 — `{date}-{provider}-verify.md`

**입력:** provider + 선택적 flow (login/signup/link/all)
**산출물:** 5축 정합성 검증표

| 축 | 검증 항목 |
|----|----------|
| **scope** | 코드의 scope 파라미터 vs §2 매트릭스 vs provider 콘솔 등록 scope 3-way 일치 |
| **식별 키** | DB `user_provider.provider_user_id` 사용 위치가 §2 매트릭스 sub 키와 일치 (Kakao `id`, Apple `sub` 등) |
| **이메일 처리** | `email_verified` 체크 유무, 미동의 케이스 분기, 마스킹 형식 |
| **encrypted payload** | §4 규약 (AES-256-CBC, 매번 랜덤 IV, base64 IV ‖ ct) 준수 |
| **token 만료 처리** | refresh token 갱신 주기 vs §2 매트릭스 만료, rotation + reuse detection |

각 축 PASS / WARN / FAIL 등급 + 근거 파일·라인.

### 6.3. debug 모드 — `{date}-{provider}-debug.md`

**입력:** provider + 에러 코드/메시지 (예: `invalid_client`, `invalid_grant`, `email_not_provided`, `state_mismatch`)
**산출물:** 가설 우선순위 표 (P0/P1/P2)

| 우선순위 | 의심 영역 | 근거 | 검증 방법 |
|---------|----------|------|----------|
| P0 | (예) Apple client_secret JWT 만료 | 6개월 만료 후 재생성 로직 부재 | client_secret JWT `exp` claim 디코드 |
| P0 | (예) state 파라미터 HMAC 서명 검증 누락 | callback handler 의 state 검증 코드 부재 | `auth/oauth/{provider}/callback` 라우트 진입점 read |
| P1 | ... | ... | ... |

**provider 별 자주 발생하는 에러 매핑** (debug 모드 진입 시 §2 매트릭스 + 본 표를 자동 참조):

| 에러 코드 | provider | 통상 원인 |
|---------|----------|-----------|
| `invalid_client` | Apple | client_secret JWT 만료 / Key ID 불일치 / Team ID 오타 |
| `invalid_client` | Google | client_secret 불일치 / redirect_uri 콘솔 미등록 |
| `invalid_grant` | Kakao/Naver | code 재사용 / code 만료 (10분) / redirect_uri 불일치 |
| `state_mismatch` | 전체 | 세션 state 미저장 / HMAC 서명 키 변경 / cookie SameSite 차단 |
| `email_not_provided` | Kakao | `account_email` scope 미동의 / 비즈 채널 미검수 |
| `email_required` | Apple | 첫 로그인 후 재가입 시 응답에서 email 누락 (DB 저장분 사용 필요) |

---

## 7. 가드레일

- **CLAUDE.md §3 Checkpoint 5조건 우선:** provider 신규 추가는 *외부 시스템 연동* (provider 콘솔 redirect_uri 등록·환경변수 추가) 으로 Checkpoint 자동 발동. 본 스킬 자동 호출도 Checkpoint 우선.
  **Why:** OAuth provider 등록은 provider 콘솔(개발자 사이트) 의 외부 설정 변경을 동반하며, 잘못된 redirect_uri·scope 가 prod 에 배포되면 모든 신규 가입이 실패해 매출·CS 영향이 즉시 발생한다.
- **Apple `.p8` 키 파일 취급:** `.p8` private key 파일은 절대 git 커밋 금지 — `.gitignore` + `.env.example` 에 경로 placeholder 만 명시. 실제 파일은 SSM Parameter Store 또는 secrets manager 경유 주입.
  **Why:** `.p8` 가 git 에 1회라도 커밋되면 Apple Developer 콘솔에서 키를 폐기·재발급해야 하며, 폐기 전까지 history 에 노출된 키로 임의 client_secret JWT 발급이 가능해져 모든 Apple 로그인 세션 탈취·위조가 가능해진다.
- **provider 콘솔 변경 사항은 권고만:** Claude 가 provider 콘솔(developers.kakao.com 등) 에 직접 접근하지 않는다. redirect_uri·scope 등록은 사용자가 콘솔에서 직접 처리하도록 단계별 안내만 제공.
- **PII 로그 금지:** userinfo 응답을 그대로 로그 출력 금지. 식별 키·이메일·이름은 마스킹 또는 hash 만 로그. (`security-audit` 공통 룰 일치)
  **Why:** OAuth userinfo 응답에는 이메일·실명·프로필 이미지 URL 등 PII 가 평문 포함 — 로그에 그대로 적재되면 로그 인덱스 시스템(CloudWatch / Loki / Splunk) 권한자가 사용자 동의 범위를 초과해 PII 를 열람 가능해지며, 개인정보보호법·GDPR 위반 (저장 목적 제한 원칙) 으로 즉시 발전한다.
- **타 프로젝트 적용 시 §2 매트릭스 SSOT 갱신:** 본 스킬은 글로벌 위치에 있지만 §2 4-provider 매트릭스를 기본값으로 한다. 다른 provider (LINE / Facebook / Microsoft 등) 추가 또는 provider 정책 변경 시 §2 표를 갱신해 SSOT 유지.

---

## 8. 산출물 위치 (단일)

```
~/.claude/docs/{product}/output/sns-oauth/
  └─ {YYYY-MM-DD}-{provider}-{add|verify|debug}.md
```

> `{product}` = `basename $CWD` (단 `.claude` → `claude-harness` 예외). 변환 SSOT 는 `hooks/lib/product-resolver.sh` 의 `resolve_product` 함수.

**bash 사용 예:**
```bash
source ~/.claude/hooks/lib/product-resolver.sh
PRODUCT=$(resolve_product "$PWD")
OUTPUT_DIR=~/.claude/docs/$PRODUCT/output/sns-oauth
```

**파일명 규칙:**
- 날짜 prefix `YYYY-MM-DD-` 필수 (CLAUDE.md §File Paths 룰)
- provider 소문자 (`kakao` / `naver` / `google` / `apple`)
- 모드 소문자 (`add` / `verify` / `debug`)
- 예: `2026-05-06-apple-debug.md`, `2026-05-06-line-add.md`

`output-naming-check.sh` hook 호환. category = `sns-oauth` 는 CLAUDE.md §File Paths 7 카테고리 중 `analysis/` 하위로도 분류 가능하나, 본 스킬은 도메인 전용 카테고리로 분리 운영.

---

## 9. 변경 기록

| 버전 | 날짜 | 변경 |
|------|------|------|
| 1.0.0 | 2026-05-06 | 최초 작성 — 4-provider 매트릭스 / 3-flow / encrypted payload 규약 / add·verify·debug 3 모드 |
