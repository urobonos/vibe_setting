# QA Scenario Sheet — 로그인

> Source: ffs.md v1.1 + as-built 코드(`LoginForm.js`/`LoginModal.js`/`/api/members/login-user/route.js`/`/api/auth/[provider]/callback/route.js`) + 감사 문서(`2026-04-16-auth-member-api-spec-review.md`)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390 x 844 (iPhone 14 기준) |
| 브라우저 | Chrome, Safari (모바일 에뮬레이션) |
| 로케일/호스트 | EN: `http://en.localhost:3000/login` / JP: `http://jp.localhost:3000/login` (hostname 기반 i18n, URL prefix 없음) |
| 테스트 도구 | Playwright (E2E) + Vitest (단위) |
| 빌드 검증 | `npm run build` 성공 + `npm run test` PASS (prebuild 게이트, 커밋 `81ab80a`) |
| 보안 검증 | CSRF Signed Double Submit (`hc_csrf_meta` 우선, `hc_csrf` fallback) + `escapeHtml(data.msg)` XSS 방어 + brute-force 5회/60초 |

---

## 2. 로그인 홈 (`/[locale]/login`)

### 2-1. 렌더링 테스트

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| R-01 | 페이지 정상 로딩 | 비로그인 | `en.localhost:3000/login` 접근 | HTTP 200, LoginForm 정상 렌더링 | P0 |
| R-02 | PageNavBar 렌더링 | 없음 | NavBar 확인 | 보라색(#6335b4) 배경 + 뒤로가기 + "Sign in" + Home 버튼 | P0 |
| R-03 | 페이지 타이틀 | 없음 | 타이틀 확인 | "Sign in" — h1, text-[2.4rem], font-bold | P0 |
| R-04 | 이메일 입력 필드 | 없음 | 필드 확인 | label "Email" 보라색(#6335b4) + `<input type="text" inputMode="email" autoComplete="email">` + placeholder + border-bottom 보라색 | P0 |
| R-05 | 비밀번호 입력 필드 | 없음 | 필드 확인 | label "Password" + `<input type="password">` + placeholder + border-bottom 보라색 | P0 |
| R-06 | Sign in 버튼 | 없음 | 버튼 확인 | bg-[#6335b4] 풀폭 버튼, text-[#ffffff] "Sign in", `disabled` false (초기) | P0 |
| R-07 | "Stay signed in" 체크박스 | 없음 | 체크박스 확인 | native `<input type="checkbox" sr-only>` + 조건부 아이콘(`icon_checkbox_checked.svg`/`unchecked.svg`) (V4.9 §22-22). 기본: 미체크 | P0 |
| R-08 | "I forgot my ID/Password" 링크 | 없음 | 링크 확인 | `<Link href="/find-account">` 텍스트 + chevron_right_circle 아이콘 (커밋 `80c6529` 활성화) | P0 |
| R-09 | 구분선 | 없음 | 디바이더 확인 | h-[0.1rem] bg-[#eeeeee] | P2 |
| R-10 | "Join" 버튼 | 없음 | 버튼 확인 | bg-[#1ab8be] 청록색 풀폭, `<Link href="/${locale}/join">` (locale prefix 포함) | P0 |
| R-11 | SNS 6종 버튼 렌더링 | 없음 | 영역 확인 | Google → Apple → Kakao → Naver → Line → Facebook 순서 (모두 prefix+bold mixed font) | P0 |
| R-12 | SNS 버튼 아이콘 | 없음 | 각 버튼 확인 | `/img/icon/icon_{provider}.svg` 24x24 우측 정렬 | P1 |
| R-13 | 에러 메시지 비표시 (기본) | 없음 | 페이지 로드 직후 | 에러 `<p>` 미존재 (조건부 렌더링, 고정 높이 미예약) | P1 |
| R-14 | LoginModal 비표시 (기본) | 없음 | 페이지 로드 직후 | `showModal=false`, AlertModal DOM 미마운트 또는 hidden | P1 |
| R-15 | 메타데이터 title | 없음 | `document.title` 확인 | "Sign in — Hong Cafe" 또는 i18n 번역 | P1 |

### 2-2. i18n 테스트 (hostname 기반)

| # | 시나리오 | 실행 단계 | 기대 결과 |
|---|---------|---------|---------|
| I-01 | EN 호스트 | `en.hongcafe.com/login` | 모든 텍스트 영어 (Sign in, Email, Password, Stay signed in 등) |
| I-02 | JP 호스트 | `jp.hongcafe.com/login` | 모든 텍스트 일본어 |
| I-03 | KR 호스트 | `hongcafe.com/login` | 본 프로젝트 범위 밖 (홍카페K) |
| I-04 | SNS 버튼 mixed font | EN/JP 각각 확인 | "Sign in with **Google**" 형태 — prefix(font-normal) + bold(font-bold) 세그먼트 분리 (§22-8) |
| I-05 | LoginModal 메시지 i18n | EN: 로그인 실패 | "The ID(Email) is not registered or the ID(Email) and password do not match." 노출 |

### 2-3. 인터랙션 테스트 (as-built)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| A-01 | 이메일 입력 | 없음 | Email 필드에 텍스트 입력 | controlled — 입력값 반영, `errors.email` 자동 클리어 | P0 |
| A-02 | 비밀번호 입력 | 없음 | Password 필드에 텍스트 입력 | controlled — 마스킹(●) 표시, `errors.password` 자동 클리어 | P0 |
| A-03 | "Stay signed in" 토글 | 없음 | 체크박스 클릭 | `staySignedIn` 토글 — native `<input>` checked 상태 + 아이콘 교체 | P1 |
| A-04 | Sign in 클릭 (성공) | 유효 이메일+비번 | Sign in 클릭 | `secureFetch('/api/members/login-user', POST)` body=`{ acId, acPassword, saveId:'n' }` → 성공 응답 → `setAuth(true, data.data)` → `router.push(\`/\${locale}/\`)` 홈 직행 | P0 |
| A-04b | saveId='y' 전송 | "Stay signed in" 체크 | Sign in 클릭 | body의 `saveId: 'y'` 검증 (network 캡처) | P1 |
| A-04c | Set-Cookie 포워딩 | 로그인 성공 응답 | network 캡처 | `Set-Cookie` 헤더에 `hc_access`/`hc_refresh`/`hc_csrf`/`hdata` 모두 포함 (`apiHandler.forwardSetCookie`) | P0 |
| A-04d | setAuth 호출 | 로그인 성공 | Zustand store 확인 | `useAuthStore.getState().isAuth === true`, `user` 값에 `data.data` 주입 | P0 |
| A-05 | Sign in 클릭 (실패) | 미등록/오류 비번 | Sign in 클릭 | `data.response='error'` 또는 `!data.data` → `setModalMessage(escapeHtml(data.msg))` + `setShowModal(true)` → 홈 이동 차단 | P0 |
| A-05b | LoginModal 표시 | 실패 응답 | LoginModal 확인 | AlertModal 기반 — 보라색 OK 버튼 + 메시지 (escape 처리됨) | P0 |
| A-05c | Modal 확인 클릭 | LoginModal 표시 | OK 버튼 클릭 | `setShowModal(false)` + `setModalMessage('')` — form은 유지 | P0 |
| A-06 | "I forgot my ID/Password" 클릭 | 없음 | 링크 클릭 | `/find-account` 페이지로 이동 (locale prefix 없음, hostname 라우팅) | P0 |
| A-07 | "Join" 클릭 | 없음 | 버튼 클릭 | `/${locale}/join` 페이지로 이동 (locale prefix 포함 — 정책 검토 필요) | P0 |
| A-08 | SNS Google 클릭 | 없음 | Google 버튼 클릭 | `window.location.href = '/api/auth/google'` → 백엔드 `lib/oauth/client.js` → state/PKCE 쿠키 세팅 → Google authorize URL 리다이렉트 | P0 |
| A-09 | SNS Apple 클릭 | 없음 | Apple 버튼 클릭 | `window.location.href = '/api/auth/apple'` → Apple authorize (`response_mode=form_post`) | P0 |
| A-10 | SNS Kakao 클릭 | 없음 | Kakao 버튼 클릭 | `window.location.href = '/api/auth/kakao'` (※ EN/JP 호스트에서는 표시 자체가 정책 미확정 — 유형 D) | P1 |
| A-11 | SNS Naver 클릭 | 없음 | Naver 버튼 클릭 | `/api/auth/naver` 진입 (※ KR 외 표시 정책 미확정) | P1 |
| A-12 | SNS Line 클릭 | 없음 | Line 버튼 클릭 | `/api/auth/line` 진입 (JP 주요 SNS) | P0 |
| A-13 | SNS Facebook 클릭 | 없음 | Facebook 버튼 클릭 | `/api/auth/facebook` 진입 | P1 |
| A-14 | Home 버튼 클릭 | 없음 | NavBar Home 클릭 | `/${locale}/` 메인으로 이동 | P1 |
| A-15 | 뒤로가기 클릭 | intro에서 진입 | NavBar < 클릭 | `router.back()` — intro로 이동 | P1 |
| A-16 | 중복 제출 방지 | 정상 입력 후 빠른 재클릭 | Sign in 두 번 클릭 | 첫 호출만 처리 (`disabled={isLoading}` 가드) | P1 |
| A-17 | 입력 후 에러 자동 클리어 | `errors.email=true` 상태 | Email 필드에 한 글자 입력 | `errors.email=false`로 자동 갱신 + 에러 메시지 사라짐 | P1 |

### 2-4. 유효성검사 / 비즈니스 로직 테스트

| # | 시나리오 | 입력값 | 기대 결과 | 우선순위 |
|---|---------|-------|---------|---------|
| V-01 | 이메일 미입력 | email="" | `errors.email=true` + `labels.idEmailError` 표시 + return early (모달 X) | P0 |
| V-02 | 비밀번호 미입력 | password="" | `errors.password=true` + `labels.passwordError` 표시 + return early (모달 X) | P0 |
| V-03 | 둘 다 미입력 | 둘 다 빈값 | 두 에러 모두 표시 + return early | P0 |
| V-04 | 공백만 입력 | email=" " | trim() 후 빈값 처리 → V-01 동일 | P1 |
| V-05 | 이메일 형식 오류 (as-built) | email="abc" | **as-built 미검증** — 백엔드 호출 후 통일 응답("not registered or do not match")으로 처리 (유형 C) | P0 |
| V-06 | 로그인 실패 (계정 미존재 / 비번 불일치) | 미등록 또는 오류 | `data.response='error'` → AlertModal: "The ID(Email) is not registered or the ID(Email) and password do not match." (CWE-204 통일 응답) | P0 |
| V-07 | brute-force 차단 (429) | 6회 연속 실패 후 7번째 시도 | 백엔드 429 응답 → `data.msg` "Too many attempts. Try again in N seconds." → AlertModal 노출 | P0 |
| V-08 | rate limit reset | 60초 경과 후 재시도 | 정상 처리 (`clearLoginAttempts` 또는 sliding window 만료) | P1 |

### 2-5. 엣지 케이스 테스트

| # | 시나리오 | 조건 | 기대 결과 | 우선순위 |
|---|---------|-----|---------|---------|
| E-01 | 네트워크 오프라인 | offline 모드 | catch → `labels.modalMessage` 기본 메시지로 AlertModal 노출 + `isLoading=false` | P0 |
| E-02 | 백엔드 500 응답 | mock 500 | catch → AlertModal 노출 (메시지는 기본값) | P1 |
| E-03 | 백엔드 200 + `response='fail'` 래핑 (apiHandler 함정) | mock 200 + fail | `data.response==='success' && data.data` 동시 검증 → 실패 분기 진입, AlertModal 노출 | P0 |
| E-04 | 긴 이메일 입력 (200자) | email=200자 | 입력 필드 UI 깨짐 없음 + 백엔드 호출 (백엔드에서 길이 검증) | P2 |
| E-05 | XSS 시도 (data.msg) | mock 응답 `data.msg = "<script>alert(1)</script>"` | escape된 텍스트로 노출 (`&lt;script&gt;...`) — 스크립트 미실행 | P0 |
| E-06 | data.msg 누락 | mock `data.msg=undefined` | `labels.modalMessage` 기본 메시지로 fallback | P1 |
| E-07 | 이미 로그인된 사용자 진입 | `isAuth=true` 상태 | **as-built 미차단** — 페이지 렌더 (유형 C — 향후 홈 리다이렉트 필요) | P1 |
| E-08 | 로그인 후 뒤로가기 | 홈 이동 후 브라우저 뒤로가기 | `/login` 재진입 가능 (이중 로그인 방지 미구현 — E-07과 동일) | P2 |

### 2-6. 접근성 테스트

| # | 시나리오 | 검증 항목 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| AC-01 | label-input 연결 | label 클릭 시 input 포커스 | `<label>` 클릭 시 해당 input 포커스 (currently inferred — `htmlFor` 권장) | P1 |
| AC-02 | 비밀번호 토글 aria-label | 눈 아이콘 버튼 | 토글 버튼에 의미 있는 aria-label 또는 alt (※ as-built 토글은 LoginForm에 없음 — Password 자체는 type=password 고정) | P2 |
| AC-03 | 키보드 Tab 순서 | Tab 키 순차 이동 | Email → Password → Sign in → Stay signed in → Forgot link → Join → SNS 6종 순서 | P1 |
| AC-04 | Enter 키 제출 | password 필드에서 Enter | form submit 동작 (`<form onSubmit>`) | P1 |
| AC-05 | SNS 버튼 aria-label | 각 SNS 버튼 | "Sign in with Google" 등 명시적 aria-label | P1 |
| AC-06 | form method="post" | form 검사 | `<form method="post">` (V4.9 §22-24, GET fallback 방지) | P2 |
| AC-07 | 체크박스 native input | 체크박스 검사 | `<input type="checkbox">` + sr-only + 조건부 아이콘 (V4.9 §22-22) | P1 |

---

## 3. SNS OAuth 콜백 시나리오 (`/api/auth/{provider}/callback`)

### 3-1. 정상 분기

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| OA-01 | Google 콜백 — 미가입자 | OAuth 진입 후 정상 callback | provider redirect → `/api/auth/google/callback?code=X&state=Y` | `code/state` 검증 → `exchangeCodeForToken` → `fetchUserInfo` → `tryAutoLogin` 실패(`exist_flag≠4`) → `signPendingSnsPayload` → `PENDING_SNS_COOKIE` 발급 → `/${locale}/join/google` 리다이렉트 | P0 |
| OA-02 | Google 콜백 — 기존 사용자 (`exist_flag=4`) | 기가입 사용자가 OAuth 시도 | callback 진입 | `tryAutoLogin` 성공 → 백엔드 join-user 응답의 Set-Cookie 포워딩 → `/${locale}/` 홈 직행 (SnsJoinForm 미진입) | P0 |
| OA-03 | Apple 콜백 — POST form_post | Apple OAuth `response_mode=form_post` | callback POST 진입 | `formData.get('code')` + `state` 추출 → 동일 분기 처리 | P0 |
| OA-04 | Kakao 콜백 (KR 정책) | Kakao OAuth | callback 진입 | 동일 분기 (※ EN/JP 호스트 표시 정책 미확정 — 유형 D) | P1 |
| OA-05 | Naver 콜백 (KR 정책) | Naver OAuth | callback 진입 | 동일 분기 | P1 |
| OA-06 | Line 콜백 (JP 주요) | Line OAuth | callback 진입 | 동일 분기 — JP 핵심 플로우 | P0 |
| OA-07 | Facebook 콜백 | Facebook OAuth | callback 진입 | 동일 분기 | P1 |
| OA-08 | SnsJoinForm prefill 검증 | OA-01 미가입자 분기 | `/${locale}/join/google` 진입 | `PENDING_SNS_COOKIE` JWT decode → `prefill={ email, nickname, providerUserId }` 주입 | P0 |

### 3-2. 비정상 분기

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| OA-09 | state 불일치 (CSRF 시도) | 쿠키 state ≠ query state | callback 진입 | `state_mismatch` → `/${locale}/login?error=oauth_{provider}_state_mismatch` 리다이렉트 + `hc_oauth_*` 쿠키 모두 삭제 | P0 |
| OA-10 | provider mismatch | 쿠키 provider ≠ URL provider | callback 진입 | 동일 — `state_mismatch` 코드 (보안 동치) | P0 |
| OA-11 | 잘못된 provider | 화이트리스트 외 provider | `/api/auth/foobar/callback` 직접 진입 | `isValidProvider=false` → `invalid_provider` 코드 리다이렉트 | P0 |
| OA-12 | provider error 응답 | `?error=access_denied` | callback 진입 | `oauth_{provider}_access_denied` 코드로 `/login` 리다이렉트 + 쿠키 삭제 | P0 |
| OA-13 | code/state 누락 | URL에 code 없음 | callback 진입 | `state_mismatch` 코드 (NOT a CSRF, but treated as malformed) | P1 |
| OA-14 | exchangeCodeForToken 실패 | provider API 500 | callback 진입 | catch → `oauth_{provider}_token_exchange_failed` 코드 리다이렉트 + 쿠키 삭제 | P1 |
| OA-15 | OAuth error UX (유형 C — 미구현) | `?error=oauth_google_access_denied`로 `/login` 진입 | login 페이지 렌더 | **현재**: query만 노출 / **권고**: 친화적 에러 토스트/모달 | P2 |

### 3-3. tryAutoLogin 분기 (OAuth 콜백 내부)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| OA-16 | check-id 200 (계정 존재 안함, 신규) | 신규 이메일 | callback 내부 | `checkRes.ok=true` → `tryAutoLogin` 반환 null → 미가입 분기 진입 | P0 |
| OA-17 | check-id 409 (이메일 기등록) | 기등록 이메일 | callback 내부 | `checkRes.status=409` → `join-user` 시도 → 응답 `exist_flag=0/3/4` → setCookies 추출 후 자동로그인 | P0 |
| OA-18 | check-id 4xx 외 | check-id 500 | callback 내부 | `tryAutoLogin` 반환 null → 미가입 분기 진입 (안전 fallback) | P1 |
| OA-19 | join-user 응답에 setCookie 없음 | 비정상 응답 | callback 내부 | `extractSetCookies` 빈 배열 → 자동로그인 시도하나 인증 미설정 (홈 진입 후 비로그인 상태) | P2 |
| OA-20 | hc_region 쿠키로 region 결정 | `hc_region=JP` | callback 내부 | `region='JP'` 사용 → join-user body에 `acCountry: 'JP'` | P1 |
| OA-21 | hc_region 미설정 + locale=ja | 쿠키 없음, locale=ja | callback 내부 | `region='JP'` fallback | P1 |
| OA-22 | hc_region 미설정 + locale=en | 쿠키 없음, locale=en | callback 내부 | `region='US'` fallback | P1 |

---

## 4. 보안 검증 시나리오

### 4-1. CSRF Signed Double Submit (커밋 `58152a1`)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-01 | hc_csrf_meta 우선 적용 | meta 토큰 발급됨 | Sign in 클릭 → network 캡처 | `secureFetch`가 `x-csrf-token` 헤더에 `hc_csrf_meta` 값 첨부 | P0 |
| SEC-02 | hc_csrf fallback | meta 없음, 백엔드 hc_csrf만 존재 | Sign in 클릭 → network 캡처 | `hc_csrf` 값으로 fallback | P0 |
| SEC-03 | 토큰 변조 | DevTools로 hc_csrf_meta 임의 변경 | Sign in 클릭 | 백엔드 검증 실패 → 에러 응답 + AlertModal 노출 | P1 |
| SEC-04 | useAuthStore.logout() CSRF 누락 (감사 권고 미반영) | 로그아웃 시도 | `useAuthStore.logout()` 호출 → network 캡처 | **현재**: `X-CSRF-TOKEN` 헤더 없음 → 백엔드 CSRF 검증 강화 시 실패. **유형 B CRITICAL** (감사 권고안 2) | P0 |
| SEC-05 | csrf.js sameSite 정책 | 쿠키 설정 검사 | LoginForm 진입 후 쿠키 검사 | **현재**: `sameSite: strict` (`lib/csrf.js:68,76`). **권고**: `lax` (감사 권고안 5 — OAuth 6종 호환) | P1 |

### 4-2. XSS 방어 (`escapeHtml`)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-06 | API 응답 msg에 HTML 태그 | mock `data.msg = "<img src=x onerror=alert(1)>"` | 로그인 실패 → AlertModal 노출 | escape된 텍스트만 노출, 스크립트 미실행 | P0 |
| SEC-07 | 사용자 입력 reflect | email=`<svg onload=alert(1)>` | Sign in 클릭 | 입력값은 form value에만 사용, DOM에 dangerouslySetInnerHTML 미사용 | P0 |
| SEC-08 | placeholder XSS | placeholder를 i18n 키로 주입 | 텍스트 검사 | next-intl이 자동 escape — 직접 HTML 주입 불가 | P1 |

### 4-3. Brute-force 보호 (`lib/auth.js`)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-09 | 5회 이내 실패 | 잘못된 비번 4회 | 5번째 시도 | 정상 처리 (rate limit 미도달) | P1 |
| SEC-10 | 6회 초과 시도 | 잘못된 비번 5회 후 6번째 | 6번째 시도 | `checkBruteForce.allowed=false` → 429 응답 + `Retry-After` 헤더 | P0 |
| SEC-11 | rate limit Reset (성공) | 4회 실패 후 정상 로그인 | 5번째 정상 시도 | `clearLoginAttempts` 호출 → 카운터 리셋 | P0 |
| SEC-12 | sliding window 만료 | 60초 경과 후 재시도 | 새 윈도우 진입 | 정상 처리 | P1 |
| SEC-13 | identifier=unknown | acId 누락 | body 없이 호출 | identifier="unknown" → IP 단위 카운트 (예상) | P2 |

### 4-4. CWE-204 계정 열거 방어

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-14 | 미존재 계정 응답 | email=신규주소, password=임의 | Sign in 클릭 | 통일 응답 메시지 ("not registered or do not match") | P0 |
| SEC-15 | 등록 계정 + 비번 불일치 응답 | email=등록주소, password=잘못된 값 | Sign in 클릭 | **동일** 통일 응답 메시지 — 응답 시간 차이도 측정 (timing attack 방지 책임은 백엔드) | P0 |
| SEC-16 | 응답 시간 차이 | SEC-14, SEC-15 응답 시간 비교 | 1000회 측정 | timing 차이 < 50ms (정책) — 백엔드 책임 영역 | P2 |

### 4-5. apiHandler 200 래핑 함정 (메모리 `feedback_verify_backend_before_claim.md`)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-17 | 백엔드 200 + `response:'fail'` 응답 | mock 백엔드 응답 | Sign in 클릭 | curl HTTP 200이라도 `data.response==='success' && data.data` 체크로 실패 분기 진입 → AlertModal 노출 | P0 |
| SEC-18 | devProxy 실제 상태코드 | E2E 디버깅 | Sign in 후 devProxy 로그 확인 | 백엔드 실제 상태코드(401/403/500) 로그 — 200 래핑에 속지 않음 | P1 |

### 4-6. OAuth state/PKCE 검증

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-19 | state 쿠키 발급 | OAuth 진입 | 쿠키 검사 | `hc_oauth_state`/`hc_oauth_verifier`/`hc_oauth_provider`/`hc_oauth_return_to` 4개 발급 | P0 |
| SEC-20 | callback state 검증 | 정상 콜백 | callback 진입 | 쿠키 state ↔ query state 일치 검증 후 진행 | P0 |
| SEC-21 | state 변조 시도 | DevTools로 query state 변경 | callback 진입 | state_mismatch → `/login?error=oauth_*_state_mismatch` 리다이렉트 + 쿠키 삭제 | P0 |
| SEC-22 | PKCE code_verifier 사용 | callback 진입 | network 캡처 | `exchangeCodeForToken` 호출 시 `codeVerifier` 동봉 (provider별 PKCE 지원 확인) | P1 |

---

## 5. 단위 테스트 게이트 (Vitest)

| # | 시나리오 | 대상 파일 | 검증 |
|---|---------|----------|------|
| UT-01 | `secureFetch` CSRF 토큰 첨부 | `__tests__/client/fetchWithAuth.test.js` | `x-csrf-token` 헤더 자동 첨부 (meta 우선, fallback) |
| UT-02 | `lib/csrf.js` Signed Double Submit | `__tests__/lib/csrf.test.js` | HMAC 서명 검증 + 만료 |
| UT-03 | `apiHandler` 응답 정규화 | `__tests__/lib/apiHandler.test.js` | 백엔드 응답 → 프론트 success/fail 분기, 200 래핑 함정 검증 |
| UT-04 | `escapeHtml` HTML 엔티티 변환 | `lib/sanitizeHtml.js` 단위 | `<`, `>`, `&`, `"`, `'` 변환 |
| UT-05 | `lib/auth.js` brute-force 카운터 | (신설 권고) | `checkBruteForce`/`recordFailedLogin`/`clearLoginAttempts` sliding window |
| UT-06 | `useAuthStore.setAuth/logout` | (신설 권고) | 상태 전환 + logout secureFetch 사용 검증 (감사 권고안 2 반영 후) |

> 빌드 게이트: `npm run prebuild` → 위 단위 테스트 실행 → 실패 시 빌드 차단 (커밋 `81ab80a`).

---

## 6. 크로스 페이지 플로우 테스트

| # | 플로우명 | 관련 페이지 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-----------|---------|---------|---------|
| CF-01 | intro → login | intro, login | intro에서 GeoIP 결과 비로그인 → login 진입 | LoginForm 정상 렌더 | P0 |
| CF-02 | login → join | login, join | "Join" 클릭 | `/${locale}/join` 표시 | P0 |
| CF-03 | login → find-account | login, find-account | "I forgot my ID/Password" 클릭 | `/find-account` 표시 (locale prefix 없음) | P0 |
| CF-04 | login(이메일) → 홈 | login → / | 정상 로그인 후 | `setAuth(true, data.data)` + `router.push(\`/\${locale}/\`)` | P0 |
| CF-05 | login(SNS Google) → 홈 (자동로그인) | login → callback → / | Google 클릭 → OAuth → 기존 사용자 콜백 | `tryAutoLogin` → 홈 직행 | P0 |
| CF-06 | login(SNS Google) → 가입 | login → callback → join | Google 클릭 → OAuth → 미가입 콜백 | `PENDING_SNS_COOKIE` 발급 → `/${locale}/join/google`로 리다이렉트, prefill 주입 | P0 |
| CF-07 | login(SNS Apple form_post) → 홈 | login → callback POST → / | Apple 클릭 → OAuth → 기존 사용자 | callback POST 핸들러 → 홈 직행 | P0 |
| CF-08 | login(SNS Line) → 가입 (JP) | login → callback → join | JP 호스트에서 Line OAuth → 미가입 | `/${locale}/join/line` 리다이렉트 | P0 |
| CF-09 | login → 5회 실패 → lock | login | 잘못된 비번 5회 후 6번째 | 429 응답 → AlertModal 노출 | P0 |
| CF-10 | login lock → 60초 후 재시도 | login | 60초 대기 후 정상 입력 | 정상 처리 | P1 |

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 화면설계서 PPTX 기반 최초 작성 | 명우현 |
| v1.1 | 2026-04-17 | as-built 기준 전면 갱신: hostname i18n(EN/JP), SNS 6종 OAuth 시나리오(§3 OA-01~22), 보안 검증(§4 SEC-01~22 — CSRF/XSS/brute-force/CWE-204/apiHandler 200래핑/OAuth state-PKCE), 단위 테스트 게이트(§5), 감사 문서(`2026-04-16-auth-member-api-spec-review.md`) 권고 미반영 항목(SEC-04 useAuthStore.logout CSRF 누락, SEC-05 csrf sameSite) CRITICAL/HIGH 표기, "Stay signed in" `saveId:'y'/'n'` 변환 명시, find-account 링크 활성화(커밋 `80c6529`), AlertModal 기반 LoginModal 시나리오, OAuth state/PKCE/region 분기 시나리오 추가 | 명우현 |
