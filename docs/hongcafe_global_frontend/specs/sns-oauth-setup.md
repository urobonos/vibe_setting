# SNS OAuth Setup Guide — 로컬 환경에서 6종 SNS 로그인 테스트

| 항목 | 내용 |
|------|------|
| 작성자 | 명우현 |
| 작성일 | 2026-04-17 |
| 버전 | v1.1 |
| 상태 | Draft |

## 1. 개요

통합 프로젝트(hongcafe_global_frontend, Next.js 16)에서 Google / Apple / Kakao / Naver / LINE / Facebook 6종 SNS 로그인을 로컬에서 테스트하기 위한 Provider Console 등록 절차와 환경변수 설정 가이드.

- **프론트 구현**: `lib/oauth/providers.js`, `lib/oauth/client.js`, `lib/oauth/session.js`, `app/api/auth/[provider]/route.js`, `app/api/auth/[provider]/callback/route.js`
- **CSP**: `proxy.js` (Phase 4에서 provider 도메인 등록 완료)
- **환경변수 템플릿**: `.env.example` (OAuth 블록 참조)

## 2. 사전 준비

### 2.1 로컬 테스트 도메인 채널 정리 (v1.1)

2026-04-17 로컬 전용 도메인 `http://pub1.hongcafe.com/` 발급됨(HTTP only, SSL 미발급). Provider별 Redirect URI 프로토콜 정책과 교차 검증한 결과, **로컬 테스트는 3개 채널로 분리 운영**한다:

| 채널 | 용도 | 커버 가능 Provider | 제약 |
|------|------|-------------------|------|
| **`http://localhost:3000`** | 1차 기본 채널 | Google / LINE / Facebook / Kakao / Naver (5종) | Google·LINE·Facebook은 `localhost` 특례로 http 허용. Apple 불가. |
| **`http://pub1.hongcafe.com`** | 실 도메인 쿠키/리다이렉트 검증 | Kakao / Naver (2종) | HTTPS 미발급으로 Google/Apple/LINE/Facebook 전부 거부. 실 hostname 기반 쿠키(SameSite/Secure) 검증 용도. |
| **Cloudflare Tunnel / ngrok** | Apple 전용 | Apple (1종) | HTTPS 공개 URL 필수. 테스트 후 Return URL에서 제거. |

**Provider 프로토콜 요구사항 근거**:
- Google: non-localhost redirect URI는 `https://` 필수 ([OAuth 2.0 Web Server](https://developers.google.com/identity/protocols/oauth2/web-server#creatingcred))
- Apple: Return URL은 HTTPS + public domain 필수, `http://` 및 `localhost` 전면 거부
- LINE: Callback URL은 HTTPS 필수 (커스텀 스킴 제외)
- Facebook: Strict Mode 기본 활성화, HTTPS 강제 (localhost만 예외)
- Kakao / Naver: 개발 단계에서 http 허용

### 2.2 `.env.local` 생성

프로젝트 루트에 `.env.local` 파일 생성 후 `.env.example`의 OAuth 블록을 복사. 채널별로 `OAUTH_REDIRECT_BASE`를 스위칭하여 사용.

```bash
# 필수 공통
OAUTH_COOKIE_SECRET=<32바이트 이상 랜덤 문자열, 예: openssl rand -base64 48>

# 채널별 (택1 또는 시나리오별 스위칭)
OAUTH_REDIRECT_BASE=http://localhost:3000        # 기본 (Google/LINE/Facebook/Kakao/Naver)
# OAUTH_REDIRECT_BASE=http://pub1.hongcafe.com   # 실 도메인 검증 (Kakao/Naver만)
# OAUTH_REDIRECT_BASE=https://<cloudflared-url>  # Apple 전용
```

**hosts 파일 / DNS**: `pub1.hongcafe.com`이 개발 PC의 `127.0.0.1`을 가리키도록 DNS 또는 `/etc/hosts`(Windows: `C:\Windows\System32\drivers\etc\hosts`)에 매핑되어 있어야 한다. 개발 서버는 `npm run dev -- -H 0.0.0.0 -p 3000`로 기동하거나 별도 nginx 프록시로 80 → 3000 포워딩.

**next-intl 설정 반영** (`i18n/routing.js`): `pub1.hongcafe.com` → `en` locale로 매핑 완료 (v1.1). `lib/redirectGuard.js`의 dev-only ALLOWED_HOSTS에도 등록.

### 2.2 레거시 자격증명 확보 (Kakao/Naver/Apple/Facebook)

레거시(hongcafe-korea, `d:\web-home\hongcafe3`)의 `tb_sns_info` DB 테이블에서 4종 Client ID/Secret 추출:

```sql
SELECT sns_type, client_id, secret_key FROM tb_sns_info WHERE st_code = '<ST_CODE>';
```

- `sns_type='apple'`: `client_id` = Key ID (JWT header `kid`)
- `sns_type='kakao'/'naver'/'facebook'`: `client_id` = REST API Key/Client ID, `secret_key` = Secret

Apple Private Key 파일은 레거시 `app/apple_hongcafe_service_key.pem`(또는 `.p8`)을 **안전한 로컬 경로**에 복사. 예: `~/.secrets/apple_hongcafe.pem`. 절대 git에 커밋 금지.

```bash
APPLE_PRIVATE_KEY_PATH=/Users/<username>/.secrets/apple_hongcafe.pem
```

---

## 3. Provider별 등록 절차

### 3.1 Google (신규 발급)

1. [Google Cloud Console](https://console.cloud.google.com/) 접속 → 프로젝트 생성 또는 선택
2. **APIs & Services → OAuth consent screen**
   - User Type: External
   - App name: `HONG CAFE (Dev)`, Support email 입력
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   - Application type: Web application
   - Authorized redirect URIs:
     - `http://localhost:3000/api/auth/google/callback`
     - `https://en.hongcafe.com/api/auth/google/callback` (prod)
     - `https://jp.hongcafe.com/api/auth/google/callback` (prod)
   - **`http://pub1.hongcafe.com/...` 등록 불가**: Google은 non-localhost URI에 `http://` 스킴을 거부한다. pub1 도메인으로 Google 테스트는 불가능 → `localhost:3000` 채널만 사용.
4. Client ID / Client Secret 복사 → `.env.local`

```
GOOGLE_CLIENT_ID=...apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=...
```

### 3.2 Apple (레거시 Service ID 재사용 + Return URL 추가)

1. [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list/serviceId) 로그인 (기존 Team `4CT53W9W9R`)
2. Identifiers → **Services IDs** → `HongCafe.peopleventures.com` 선택
3. **Sign in with Apple → Configure** → Return URLs에 추가:
   - `https://<Cloudflare Tunnel URL>/api/auth/apple/callback` (로컬 테스트용 임시)
   - `https://en.hongcafe.com/api/auth/apple/callback` (prod)
   - `https://jp.hongcafe.com/api/auth/apple/callback` (prod)
4. `.env.local`에 입력:

```
APPLE_CLIENT_ID=HongCafe.peopleventures.com
APPLE_TEAM_ID=4CT53W9W9R
APPLE_KEY_ID=<레거시 tb_sns_info sns_type='apple' client_id 값>
APPLE_PRIVATE_KEY_PATH=/절대/경로/apple_hongcafe.pem
```

**Apple localhost 제약**: Apple은 `http://localhost` 및 `http://` 프로토콜 자체를 허용하지 않는다. Return URL은 HTTPS + 공개 도메인 필수.

**로컬 테스트 옵션**:
- **Cloudflare Tunnel** (권장): `cloudflared tunnel --url http://localhost:3000` → 발급된 HTTPS URL을 Apple Return URL에 일시 등록 → 테스트 후 Return URL에서 제거.
- **ngrok**: `ngrok http 3000` → 동일 방식.
- **스테이징 전용**: Apple은 스테이징(`https://staging.hongcafe.com`)에서만 검증하고 로컬은 Google/Kakao/Naver/LINE/Facebook 5종으로 제한.

### 3.3 Kakao (레거시 앱 재사용)

1. [Kakao Developers](https://developers.kakao.com/console/app) 로그인 → 기존 앱 선택
2. **앱 설정 → 플랫폼 → Web 플랫폼 등록**
   - 사이트 도메인: `http://localhost:3000`, `http://pub1.hongcafe.com`, `https://en.hongcafe.com`, `https://jp.hongcafe.com`
3. **제품 설정 → 카카오 로그인 → 활성화**
4. **제품 설정 → 카카오 로그인 → Redirect URI**
   - `http://localhost:3000/api/auth/kakao/callback`
   - `http://pub1.hongcafe.com/api/auth/kakao/callback` (v1.1 추가 — Kakao는 http redirect URI 허용)
   - 레거시 `{SITEURL}plugins/kakao/authcallback`는 **그대로 유지**
5. **제품 설정 → 카카오 로그인 → 동의 항목**
   - 카카오계정(이메일): 필수 동의
   - 프로필 정보(닉네임): 필수 동의
   - (레거시 광범위 scope와 달리, 통합 프로젝트는 **최소 권한** — 나머지는 `/join/kakao` 폼에서 직접 수집)
6. `.env.local`에 입력:

```
KAKAO_REST_API_KEY=<레거시 tb_sns_info sns_type='kakao' client_id>
KAKAO_CLIENT_SECRET=<레거시 secret_key>
```

### 3.4 Naver (레거시 애플리케이션 재사용)

1. [Naver Developers](https://developers.naver.com/apps/) 로그인 → 기존 애플리케이션 선택
2. **API 설정**
   - 서비스 URL: `http://localhost:3000`, `http://pub1.hongcafe.com`, `https://en.hongcafe.com`, `https://jp.hongcafe.com`
   - Callback URL:
     - `http://localhost:3000/api/auth/naver/callback`
     - `http://pub1.hongcafe.com/api/auth/naver/callback` (v1.1 추가 — Naver는 http callback 허용)
   - 레거시 `{SITEURL}plugins/naver/authcallback?type=join`는 그대로 유지
3. `.env.local`에 입력:

```
NAVER_CLIENT_ID=<레거시 tb_sns_info sns_type='naver' client_id>
NAVER_CLIENT_SECRET=<레거시 secret_key>
```

### 3.5 LINE (신규 발급)

상세 절차는 `docs/audits/2026-04-15-line-developers-console-callback-url.md` 권고안 1~3 참조.

1. [LINE Developers Console](https://developers.line.biz/console/) 로그인
2. Provider 선택 → Channels 탭 → **LINE Login** 채널 생성 (또는 기존 채널 재사용)
3. **Basic settings** → App types에 `Web app` 포함 확인
4. **LINE Login** 탭 (2번째 탭) → **Callback URL** 멀티라인 입력:
   ```
   http://localhost:3000/api/auth/line/callback
   https://en.hongcafe.com/api/auth/line/callback
   https://jp.hongcafe.com/api/auth/line/callback
   ```
   - **`http://pub1.hongcafe.com/...` 등록 불가**: LINE은 Callback URL에 HTTPS를 요구한다(커스텀 스킴 제외). pub1 도메인 테스트 불가 → `localhost:3000` 채널만 사용.
5. **OpenID Connect** 활성화 → Email address permission 신청 및 승인
6. `.env.local`:

```
LINE_CHANNEL_ID=<Channel ID>
LINE_CHANNEL_SECRET=<Channel secret>
```

### 3.6 Facebook (레거시 App 재사용)

1. [Meta for Developers](https://developers.facebook.com/apps/) 로그인 → 기존 App 선택
2. **Facebook Login → Settings**
   - Valid OAuth Redirect URIs:
     - `http://localhost:3000/api/auth/facebook/callback`
     - `https://en.hongcafe.com/api/auth/facebook/callback`
     - `https://jp.hongcafe.com/api/auth/facebook/callback`
   - **`http://pub1.hongcafe.com/...` 등록 불가**: Facebook Login은 Strict Mode 기본 활성화로 Redirect URI에 HTTPS를 요구한다(localhost만 예외). pub1 도메인 테스트 불가 → `localhost:3000` 채널만 사용.
3. **App Settings → Basic** → App Domains에 `localhost` 추가 (dev만)
4. `.env.local`:

```
FACEBOOK_APP_ID=<레거시 tb_sns_info sns_type='facebook' client_id>
FACEBOOK_APP_SECRET=<레거시 secret_key>
```

---

## 4. 로컬 테스트 체크리스트

### 4.1 기동 전

- [ ] `.env.local` 최소 1개 provider의 Client ID/Secret 입력 (Google 권장)
- [ ] `OAUTH_REDIRECT_BASE` = 사용할 채널에 맞게 세팅 (§2.1 채널 매트릭스 참조)
- [ ] `OAUTH_COOKIE_SECRET=` 32바이트 이상
- [ ] Provider Console에 사용 채널의 `.../api/auth/{provider}/callback` 등록 확인
- [ ] pub1 채널 사용 시: `pub1.hongcafe.com` → `127.0.0.1` DNS/hosts 매핑 + 80 포트 접근(또는 nginx 프록시) 확인

### 4.2 실행

```bash
npm run dev
```

채널별 접속 URL:
- localhost 채널: `http://localhost:3000/` (locale은 `hc_country` 쿠키 또는 GeoIP 기반)
- pub1 채널: `http://pub1.hongcafe.com/` (next-intl domains로 en locale 자동 매핑)

### 4.3 플로우 검증 (Google 예시)

1. **SNS 버튼 클릭** → `GET /api/auth/google` → Google 동의 화면 노출
2. **Google 동의** → `GET /api/auth/google/callback?code=...&state=...`
3. **DevTools → Application → Cookies** 확인:
   - `hc_oauth_state` / `hc_oauth_verifier` / `hc_oauth_provider` / `hc_oauth_return_to` — 콜백 후 삭제됨
   - `hc_sns_pending` — 새로 세팅됨 (JWT httpOnly)
4. **자동 리다이렉트** → `http://localhost:3000/en/join/google`
5. **SnsJoinForm** → email / nickname prefill 확인

### 4.4 에러 케이스

| 증상 | 원인 | 확인 |
|------|------|------|
| `error=oauth_google_state_mismatch` | state 쿠키 유실 또는 위변조 | 쿠키 만료 10분, 브라우저 시크릿 모드 다중 탭 충돌 가능 |
| `error=oauth_google_access_denied` | 사용자가 동의 거부 | 정상 동작 |
| `error=oauth_google_token_...` | token exchange 실패 | `.env.local` Client Secret 오타, redirect_uri mismatch |
| CSP violation 콘솔 로그 | `proxy.js` CSP 누락 | §22-4-C, `proxy.js:84-99` connect-src 도메인 확인 |
| `OAUTH_COOKIE_SECRET must be at least 32 bytes` | env 미설정 또는 짧음 | `openssl rand -base64 48` |
| `missing env: GOOGLE_CLIENT_ID` | `.env.local` 미입력 | 입력 후 `npm run dev` 재기동 |

### 4.5 정적 검사

```bash
npm run build  # 빌드 성공 확인
```

---

## 5. 미완 항목 / 백엔드 확정 후 추가

현재 구현은 **프론트 OAuth 어댑터 + `hc_sns_pending` 쿠키 전달**까지만 완성. 실제 회원가입/로그인 연결은 백엔드 스펙 확정 후 추가:

| 항목 | 파일 | 설명 |
|------|------|------|
| B1 SNS 기존 사용자 판별 | `app/api/auth/[provider]/callback/route.js` | 백엔드 `/api/auth/register` 호출 → 409면 별도 처리 |
| B2 register 필드 확장 | `SnsJoinForm.js` `handleSubmit` | `ac_birth_*`, `agree_*`, `sns_type`, `ac_sns_id` 필드 제출 |
| B3 SMS verify | `verify-sms` | 백엔드 confirm 엔드포인트 확정 후 |
| B4 access_token 재검증 | callback route.js | 필요 시 백엔드에 `access_token` 함께 전송 |
| B5 세션 체계 | callback route.js | `hc_access`/`hc_refresh` vs `hdata` 단일 쿠키 결정 |

## 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-15 | 최초 작성 — 6종 Provider Console 등록 가이드 + 로컬 테스트 체크리스트 | 명우현 |
| v1.1 | 2026-04-17 | 로컬 도메인 `http://pub1.hongcafe.com` 발급 반영 — 3채널 분리 매트릭스(localhost / pub1 / Cloudflare Tunnel), Provider별 HTTPS 정책 교차검증, Kakao/Naver는 pub1 추가, Google/LINE/Facebook은 http 거부로 pub1 불가 명시. 코드 반영: `i18n/routing.js` domains + `lib/redirectGuard.js` dev ALLOWED_HOSTS + `.env.example` 주석 | 명우현 |
