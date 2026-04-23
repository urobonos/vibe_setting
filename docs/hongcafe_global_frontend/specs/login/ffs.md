# Frontend Functional Spec — 로그인

> Source: 화면설계서 PPTX Slides S17~S21 + as-built 코드(`LoginForm.js`/`LoginModal.js`/`/api/members/login-user/route.js`/`/api/auth/[provider]/callback/route.js`) + 감사 문서(2026-04-16)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

> **참조 버전**: backend `member-api.yaml`/`auth-api.yaml` v2026-04-16. 최종 확정 후 별도 정합성 패스 진행.

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 로그인 (Login / Sign in) |
| 사용자 목표 | 기존 계정으로 로그인하거나 회원가입/계정찾기로 분기, 또는 SNS 6종(Google/Apple/Kakao/Naver/Line/Facebook) OAuth로 자동 로그인 |
| 퍼블리싱 상태 | 퍼블리싱 완료 |
| 기능 연동 상태 | **부분 연동** — 이메일/비번 로그인(login-user), CSRF Signed Double Submit, brute-force rate limit, CWE-204 통일 응답, OAuth 6종 자동로그인(`exist_flag=4` 분기), find-account 링크 활성화 모두 구현 완료. **국가별 SNS 버튼 분기·로그인 유지 기간·whoami 노출 제한** 미반영 |
| i18n 네임스페이스 | `login` |
| 지원 로케일 | `en`, `ja` (KR은 프로젝트 범위 밖) |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |

### 도메인 흐름 요약

```
Login (/login)
  ├── 이메일+비번 → /api/members/login-user → 성공 → setAuth → / 홈 직행
  ├── SNS 6종 → /api/auth/{provider} → OAuth 콜백
  │                                   ├── exist_flag=4 (기존 사용자)  → tryAutoLogin → / 홈 직행
  │                                   └── 미가입자                  → /join/{provider} (prefill 주입)
  ├── "I forgot my ID/Password" → /find-account
  └── "Join" → /{locale}/join

  ※ rate limit: 5회/60초 (lib/auth.js — IP/acId 기준)
  ※ brute-force 분리 카운터: 별도 prefix로 sliding window
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/login` | `app/[locale]/login/page.js` | LoginForm | Server → Client | `login` |

### API Route (프론트 프록시)

| 라우트 | 메서드 | 용도 | as-is 매핑 | 비고 |
|--------|--------|------|-----------|------|
| `/api/members/login-user` | POST | 이메일/비번 로그인 (정식 v3.0 EP) | `/api/members/login-user` | `createApiHandler` + `checkBruteForce`/`recordFailedLogin`/`clearLoginAttempts` |
| `/api/auth/login` | POST | **레거시 shim** (구 LoginForm 호환) — 신규 호출 금지, 마이그레이션 후 제거 예정 | `/api/members/login-user` | mockData 포함, brute-force 동일 적용 |
| `/api/auth/{provider}` | GET | OAuth 진입 (state/PKCE 발급, hc_oauth_* 쿠키 세팅 후 provider authorize URL 리다이렉트) | — | `lib/oauth/client.js`, `lib/oauth/providers.js` |
| `/api/auth/{provider}/callback` | GET/POST | OAuth 콜백 — code 교환 → profile 조회 → `tryAutoLogin` → 가입 여부 분기 | `/api/members/check-id`, `/api/members/join-user` | Apple `response_mode=form_post` 대응 POST 핸들러 (`route.js:155`) |

---

## 3. 페이지 정의

### 3-1. 로그인 홈 (S21)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/login` |
| Server Component | `app/[locale]/login/page.js` — 메타데이터/labels 구성 |
| Client Component | `app/[locale]/login/_components/LoginForm.js` |
| 화면설계서 | S17~S21 |

#### UI 섹션 (위→아래)

| # | 섹션 | 설명 (as-built) |
|---|------|----------------|
| 0 | 상단 네비게이션 | `PageNavBar` — 보라색 배경 + 뒤로가기 + "Sign in" 타이틀 + Home 버튼 |
| 1 | 페이지 타이틀 | "Sign in" — h1, text-[2.4rem], font-bold, 보라색(#6335b4) 라벨 통일 |
| 2 | 이메일 입력 | label "Email" (#6335b4 font-bold) + `<input type="text" inputMode="email" autoComplete="email">` + placeholder + border-bottom 보라색 |
| 3 | 이메일 에러 메시지 | 조건부(`errors.email`) — text-[1.4rem] text-[#ff3939] |
| 4 | 비밀번호 입력 | label "Password" + `<input type="password">` + placeholder + border-bottom 보라색 |
| 5 | 비밀번호 에러 메시지 | 조건부(`errors.password`) |
| 6 | Sign in 버튼 | bg-[#6335b4] full-width 버튼, `disabled={isLoading}` (중복 제출 방지) |
| 7 | "Stay signed in" 체크박스 | native `<input type="checkbox" className="peer sr-only">` + 조건부 아이콘 (V4.9 §22-22). `staySignedIn` 상태 → body의 `saveId: 'y'\|'n'` |
| 8 | "I forgot my ID/Password" 링크 | `<Link href="/find-account">` (커밋 `80c6529` 활성화 — locale prefix 없음, hostname 라우팅) |
| 9 | 구분선 | h-[0.1rem] bg-[#eeeeee] |
| 10 | "Join" 버튼 | `<Link href="/${locale}/join">` 청록색 bg-[#1ab8be] full-width — **locale prefix 포함 (CLAUDE.md §11과 차이, 정책 검토 필요)** |
| 11 | SNS 로그인 6종 | Google / Apple / Kakao / Naver / Line / Facebook — `window.location.href = /api/auth/{provider}` |
| 12 | LoginModal | `AlertModal` 기반 — 실패 시 `escapeHtml(data.msg)` 표시 |

#### 상태 관리 (LoginForm.js as-built)

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `email` | string | `''` | 이메일 입력값 (controlled) |
| `password` | string | `''` | 비밀번호 입력값 (controlled) |
| `staySignedIn` | boolean | `false` | "Stay signed in" 체크박스 → `saveId: 'y'\|'n'` 변환 |
| `errors` | object | `{}` | `{ email: bool, password: bool }` — 미입력 표시용 |
| `showModal` | boolean | `false` | LoginModal 표시 여부 |
| `modalMessage` | string | `''` | LoginModal 본문 (escape 처리됨) |
| `isLoading` | boolean | `false` | API 호출 중 버튼 disabled |
| (zustand) `useAuthStore.setAuth` | — | — | 로그인 성공 시 인증 상태 전환 |

#### API 연동 (as-built)

| 엔드포인트 | 메서드 | Request Body | Response | 구현 상태 |
|-----------|--------|-------------|----------|----------|
| `POST /api/members/login-user` | POST | `{ acId, acPassword, saveId: 'y'\|'n' }` | `{ response: 'success'\|'error', msg, data: { acId, acNick, acHomeSet, ... } }` + Set-Cookie `hc_access`/`hc_refresh`/`hc_csrf`/`hdata` | **구현 완료** (`route.js`) — rate limit 5/60s + brute-force |
| `POST /api/auth/login` | POST | 동일 | 동일 | **레거시 shim** (mockData 포함, 마이그레이션 후 제거) |
| `GET /api/auth/{provider}` | GET | — | 302 Redirect → provider authorize URL | **구현 완료** (커밋 `b168d51`) |
| `GET/POST /api/auth/{provider}/callback` | GET/POST | code/state/error (Apple POST) | 분기 결과 따라 302 Redirect (홈 / `/join/{provider}`) | **구현 완료** |

#### 인터랙션 (as-built)

| 액션 | 동작 |
|------|------|
| 이메일 입력 | controlled — onChange 시 `errors.email` 자동 클리어 |
| 비밀번호 입력 | controlled — onChange 시 `errors.password` 자동 클리어 |
| "Stay signed in" 체크 | `staySignedIn` 토글 — 제출 시 `saveId: 'y'\|'n'`로 변환 |
| Sign in 클릭 (정상) | trim 검증 → `secureFetch('/api/members/login-user', POST)` → 성공 시 `setAuth(true, data.data)` + `router.push(\`/\${locale}/\`)` 홈 직행 |
| Sign in 클릭 (필드 누락) | `errors` 상태 갱신 + return early (모달 X) |
| Sign in 실패 응답 | `escapeHtml(data.msg)` → `LoginModal` 노출 (XSS 방어) |
| Sign in 네트워크 에러 | `labels.modalMessage` 기본 메시지로 `LoginModal` 노출 |
| Sign in 중 재클릭 | `disabled={isLoading}`로 차단 (중복 제출 방지) |
| Brute-force 차단 응답 (429) | `Too many attempts. Try again in N seconds.` 메시지 + `LoginModal` 노출 |
| SNS 버튼 클릭 | `window.location.href = /api/auth/{provider}` — OAuth 진입 (state/PKCE 쿠키 세팅 후 provider 리다이렉트) |
| OAuth 콜백 — `exist_flag=4` (기존 사용자) | `tryAutoLogin` → 백엔드 join-user 응답의 Set-Cookie 포워딩 → `/${locale}/` 홈 직행 |
| OAuth 콜백 — 미가입자 | `signPendingSnsPayload` → `PENDING_SNS_COOKIE` 발급 → `/${locale}/join/{provider}`로 리다이렉트 (SnsJoinForm `prefill`로 email/nickname 주입) |
| OAuth 콜백 — state 불일치 / error | `/${locale}/login?error=oauth_{provider}_{code}` 리다이렉트 + `hc_oauth_*` 쿠키 모두 삭제 |
| "I forgot my ID/Password" 클릭 | `<Link href="/find-account">` (locale prefix 없음 — hostname 라우팅) |
| "Join" 클릭 | `<Link href="/${locale}/join">` (locale prefix 포함 — 정책 검토 필요) |
| LoginModal 확인 클릭 | `setShowModal(false)` + `setModalMessage('')` |

#### 비즈니스 규칙

| 규칙 | 설명 (as-built / 정책) | 근거 |
|------|----------------------|------|
| **CSRF Signed Double Submit** | 모든 상태 변경 요청에 `secureFetch`가 `x-csrf-token` 헤더 자동 첨부 (`hc_csrf_meta` 우선, `hc_csrf` fallback) | 커밋 `58152a1`, `lib/csrf.js` |
| **CWE-204 통일 응답** | 계정 미존재/비밀번호 불일치 동일 응답 (계정 열거 방어) | `route.js:2` 주석 + 감사 §3.1 #4 |
| **Brute-force rate limit** | 5회/60초 (`createApiHandler` rateLimit). 별도 `checkBruteForce`/`recordFailedLogin` sliding window 카운터로 lock | `lib/auth.js`, `route.js:18-46` |
| **응답 정규화 (apiHandler 200 래핑)** | 백엔드가 200으로 fail 응답을 래핑할 수 있음 — 프론트는 반드시 `data.response === 'success'` + `data.data` 동시 검증 | 메모리 `feedback_verify_backend_before_claim.md` |
| **Set-Cookie 포워딩** | 백엔드의 `hc_access`/`hc_refresh`/`hc_csrf`/`hdata`를 `apiHandler.forwardSetCookie`가 그대로 전달 → 프론트는 `setAuth(true, data.data)`로 플래그만 저장 | `lib/sessionBridge.js` |
| **XSS 방어** | API 응답 `data.msg`는 반드시 `escapeHtml()` 처리 후 렌더링 | `lib/sanitizeHtml.js` |
| **OAuth state/PKCE** | provider 진입 시 `hc_oauth_state`/`hc_oauth_verifier`/`hc_oauth_provider`/`hc_oauth_return_to` 쿠키 발급, 콜백에서 검증 | `app/api/auth/[provider]/callback/route.js:96-104` |
| **Apple form_post 대응** | Apple는 `response_mode=form_post`로 콜백 → POST 핸들러로 `formData.get(...)` 처리 | `callback/route.js:155-162` |

#### 엣지 케이스 (as-built + 정책 미확정)

| 케이스 | 처리 (as-built / 권고) |
|--------|----------------------|
| 빈 입력으로 Sign in | `errors` 상태로 미입력 표시, return early. **에러 텍스트는 영문 placeholder만** — 화면설계서의 "아이디(이메일)를 입력해 주세요." 같은 i18n 메시지 미연동 (유형 C) |
| 잘못된 이메일 형식 | **as-built 미검증** — 형식 정규식 미적용, 백엔드에서 통일 응답으로 처리 (유형 C — `lib/validators/login.js` 신설 검토) |
| 5회 초과 시도 | 백엔드 429 응답 → `Too many attempts...` 메시지 노출 |
| 네트워크 오프라인 | catch → `labels.modalMessage` 기본 메시지 노출 |
| OAuth state 불일치 (CSRF 시도) | `state_mismatch` 코드로 `/login?error=oauth_{provider}_state_mismatch` 리다이렉트 |
| OAuth provider 응답 error | `error` 파라미터를 그대로 query에 노출 (예: `oauth_google_access_denied`) — **사용자에게 친화적 메시지 변환 미구현** (유형 C) |
| 로그인 후 staySignedIn=false | `saveId: 'n'` 전송 — 실제 쿠키 만료 정책은 백엔드 책임 |
| 이미 로그인된 사용자가 `/login` 진입 | **as-built 미차단** — 로그인 상태 체크 후 홈 리다이렉트 미구현 (유형 C) |
| OAuth 재시도 시 PENDING_SNS_COOKIE 잔존 | callback 진입 시 `clearOauthCookies` 호출되나 `PENDING_SNS_COOKIE`는 별도 — TTL 만료 의존 |

#### i18n 네임스페이스

| 키 (대표) | en 값 (예시) |
|----------|-------------|
| `login.navTitle` | Sign in |
| `login.home` | Home |
| `login.pageTitle` | Sign in |
| `login.idEmailLabel` | ID (Email) |
| `login.idEmailPlaceholder` | Please enter your ID (email) |
| `login.idEmailError` | Please enter your ID (email). |
| `login.passwordLabel` | Password |
| `login.passwordPlaceholder` | Please enter your password |
| `login.passwordError` | Please enter your password. |
| `login.staySignedIn` | Stay signed in |
| `login.signInButton` | Sign in |
| `login.forgotPassword` | I forgot my ID(Email) or Password |
| `login.joinButton` | Join |
| `login.signInWithPrefix` | Sign in with |
| `login.google` / `login.apple` / `login.kakao` / `login.naver` / `login.line` / `login.facebook` | Google / Apple / Kakao / Naver / Line / Facebook |
| `login.modalNotice` | Notice |
| `login.modalMessage` | The ID(Email) is not registered or the ID(Email) and password do not match. |
| `login.modalConfirm` | OK |

#### 의존성 (as-built)

| 의존성 | 용도 |
|--------|------|
| `PageNavBar` (`app/[locale]/_components/PageNavBar.js`) | 상단 네비게이션 (보라색) |
| `LoginModal` (`app/[locale]/login/_components/LoginModal.js`) | 에러 메시지 모달 (`AlertModal` wrapper) |
| `AlertModal` (`components/AlertModal.js`) | 공용 알림 모달 (V5.7 신설) |
| `lib/fetchWithAuth.js` (`secureFetch`) | CSRF Signed Double Submit 토큰 자동 첨부 |
| `lib/sanitizeHtml.js` (`escapeHtml`) | API 응답 `data.msg` XSS 방어 |
| `store/useAuthStore.js` (`setAuth`) | 로그인 성공 시 인증 상태 전환 |
| `lib/auth.js` (`checkBruteForce`/`recordFailedLogin`/`clearLoginAttempts`) | 로그인 시도 분리 카운터 (sliding window) |
| `lib/oauth/client.js` (`exchangeCodeForToken`/`fetchUserInfo`) | OAuth 토큰 교환 + 프로파일 조회 |
| `lib/oauth/providers.js` (`isValidProvider`) | provider 화이트리스트 검증 |
| `lib/oauth/session.js` (`signPendingSnsPayload`/`PENDING_SNS_COOKIE`) | 미가입 SNS 페이로드 JWT 서명 + 쿠키 정책 |
| `lib/sessionBridge.js` (`extractSetCookies`) | 백엔드 Set-Cookie 헤더 포워딩 |
| `next/link`, `next/image`, `useRouter` | 네비게이션 + 이미지 |

---

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 파일 경로 | 사용 페이지 | 타입 | 비고 |
|---------|----------|-----------|------|------|
| LoginForm | `app/[locale]/login/_components/LoginForm.js` | login | Client | 메인 폼 |
| LoginModal | `app/[locale]/login/_components/LoginModal.js` | login | Client | AlertModal wrapper |

> 전역 공용은 `components/AlertModal.js`, `components/ModalOverlay.js`, `components/ReCaptchaEnterprise.js`. login 도메인은 reCAPTCHA 미적용(필요 시 추후 검토).

---

## 5. 크로스 도메인 의존성

| 의존 도메인 | 의존 방향 | 설명 |
|-----------|----------|------|
| intro | intro → login | intro 페이지에서 "허용" 후 GeoIP 라우팅 결과 비로그인 시 login 진입 |
| join | login → join | "Join" 링크 — `/${locale}/join` |
| find-account | login → find-account | "I forgot my ID/Password" — `/find-account` (커밋 `80c6529`) |
| / (메인) | login → / | 로그인 성공 시 `router.push(/${locale}/)` 홈 직행 |
| OAuth provider 6종 | login → external | Google/Apple/Kakao/Naver/Line/Facebook authorize URL 리다이렉트 |
| OAuth callback → join | login(callback) → join | 미가입자: `/${locale}/join/{provider}` 리다이렉트 + `PENDING_SNS_COOKIE`로 prefill 주입 |
| useAuthStore | login → store | 로그인 성공 시 `setAuth(true, data.data)` |

---

## 6. 미확정 사항 (v1.1)

> 분류: **유형 A** = as-built 구현 완료 / **유형 B** = 감사 권고 미반영 / **유형 C** = 추가 구현 필요 / **유형 D** = 정책·디자인 확정 필요

| # | 우선순위 | 유형 | 항목 | 설명 | 근거/결정 필요 시점 |
|---|---------|------|------|------|--------------------|
| 1 | **[CRITICAL]** | B | useAuthStore.logout() secureFetch 미사용 | 직접 `fetch` 호출로 `X-CSRF-TOKEN` 헤더 누락 → 백엔드 CSRF 검증 강화 시 로그아웃 실패 위험 | 감사 권고안 2 (`2026-04-16-auth-member-api-spec-review.md`) |
| 2 | **[HIGH]** | B | csrf.js sameSite 통일 (strict → lax) | OAuth 6종 콜백 호환성 확보 + OWASP CSRF Cheat Sheet 권고 | 감사 권고안 5 |
| 3 | **[HIGH]** | C | 국가별 SNS 버튼 분기 | as-built는 6종 고정. EN: Google+Apple+Facebook / JP: Google+Apple+Line+Facebook (Kakao/Naver 제거) | 화면설계서 S20 + hostname 분기 |
| 4 | **[HIGH]** | C | 클라이언트 이메일 형식 검증 | as-built는 미입력만 검증. `lib/validators/login.js` 신설 (joinEmail.js와 분리) | 사용자 경험 개선 |
| 5 | **[HIGH]** | C | 화면설계서 한글 i18n 메시지 매핑 | "아이디(이메일)를 입력해 주세요." 등 화면설계서 메시지를 `messages/ja.json`에 매핑, 영문은 별도 카피 라이팅 | i18n 카피 검토 |
| 6 | **[MEDIUM]** | C | 이미 로그인된 사용자 진입 차단 | `/login`을 비로그인 사용자에게만 노출 — 로그인 상태 체크 후 홈 리다이렉트 | 사용자 경험 |
| 7 | **[MEDIUM]** | C | OAuth error 코드 사용자 메시지 변환 | `?error=oauth_google_access_denied` → "Google 로그인에 실패했습니다" 등 친화적 메시지 + 재시도 버튼 | UX |
| 8 | **[MEDIUM]** | D | "Join" 링크 locale prefix 정책 | as-built `/${locale}/join`은 CLAUDE.md §11 "locale prefix 금지"와 모순. hostname 라우팅 일관성 정책 확정 | CLAUDE.md 정책 |
| 9 | **[MEDIUM]** | C | 로그인 유지 기간 (saveId='y') | 백엔드의 `hc_refresh` TTL 정책 — 프론트는 플래그만 전달, 실제 만료는 백엔드 책임 | 백엔드 정책 확정 |
| 10 | **[MEDIUM]** | A | OAuth 6종 자동로그인 분기 | `exist_flag=4` 시 `tryAutoLogin` → 백엔드 Set-Cookie 포워딩 → 홈 직행 | 커밋 `b168d51` |
| 11 | **[MEDIUM]** | A | CSRF Signed Double Submit | `secureFetch` 자동 첨부 (meta 우선, fallback 백엔드 hc_csrf) | 커밋 `58152a1` |
| 12 | **[MEDIUM]** | A | brute-force 분리 카운터 | `lib/auth.js` sliding window — 5회/60초 + IP/acId 기준 lock | as-built |
| 13 | **[MEDIUM]** | A | CWE-204 통일 응답 | 백엔드가 계정 미존재/비번 불일치 동일 응답으로 통일 — 프론트는 단일 메시지로 표시 | 감사 §3.1 #4 |
| 14 | **[LOW]** | C | `/api/auth/login` 레거시 shim 제거 | LoginForm은 이미 `/api/members/login-user` 직접 호출. shim은 향후 제거 | route.js 헤더 주석 |
| 15 | **[LOW]** | C | LoginModal Escape/Backdrop 닫기 | AlertModal 기반 — backdrop 클릭/Escape 키 닫기 동작 검증 (§22-40) | UI/UX |
| 16 | **[LOW]** | B | `/api/whoami` 프로덕션 노출 제한 | 환경 분기 또는 인증 필수로 변경 — login과 직접 무관하나 인증 모듈 일관성 | 감사 권고안 4 |
| 17 | **[LOW]** | C | reCAPTCHA Enterprise 적용 검토 | 로그인은 현재 미적용. brute-force만으로 충분한지 정책 결정 | 보안 정책 |

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 화면설계서 PPTX 기반 최초 작성 | 명우현 |
| v1.1 | 2026-04-17 | as-built 코드(`LoginForm.js`/`LoginModal.js`/`/api/members/login-user/route.js`/`/api/auth/[provider]/callback/route.js`) + 감사 문서(`2026-04-16-auth-member-api-spec-review.md`) 역반영. 유형 A/B/C/D 분류 도입. SNS 6종 OAuth 자동로그인 분기, CSRF Signed Double Submit, brute-force rate limit, CWE-204 통일 응답, AlertModal 기반 LoginModal, find-account 링크 활성화(커밋 `80c6529`), legacy `/api/auth/login` shim 명시. 감사 권고 미반영 항목 4건(useAuthStore.logout secureFetch 미사용, csrf sameSite, 국가별 SNS 분기, whoami 노출) CRITICAL/HIGH 표기 | 명우현 |
