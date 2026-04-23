# QA Scenario Sheet — Intro / 권한설정 + GeoIP 라우팅

> Source: ffs.md v1.1 + as-built 코드(`IntroScreen.js`/`proxy.js`/`lib/geoip.js`) + 감사 문서(`2026-04-15-geoip-country-routing-scenario-matrix.md`)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390×844 (모바일 우선) |
| 로케일/호스트 | EN: `en.hongcafe.com` / JP: `jp.hongcafe.com` (hostname 기반 i18n) |
| 베이스 URL (개발) | `http://en.localhost:3000`, `http://jp.localhost:3000` |
| 테스트 도구 | Playwright (E2E) + Vitest (`__tests__/lib/geoip.test.js`) |
| 빌드 검증 | `npm run build` 성공 + `npm run test` PASS |
| GeoIP DB | geoip-lite 번들 (MaxMind GeoLite2) — `npm install`로 동봉 |

---

## 2. proxy.js Middleware — GeoIP 라우팅 시나리오

### 2-1. GeoIP 자동 라우팅

| # | 시나리오 | 사전조건 (요청 IP) | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-----------------|---------|---------|---------|
| GIP-01 | JP IP → ja locale | x-forwarded-for=`126.0.0.1` (JP), 쿠키 없음 | `hongcafe.com` 접근 | `lookupCountryLocal=JP` → `mapCountryToLocale=ja` → next-intl이 ja 라우팅 + `__Host-hc_country` (또는 dev `hc_country`) 24h TTL 쿠키 발급 | P0 |
| GIP-02 | US IP → en locale | x-forwarded-for=`8.8.8.8` (US), 쿠키 없음 | `hongcafe.com` 접근 | `lookupCountryLocal=US` → `mapCountryToLocale=en` + 쿠키 발급 | P0 |
| GIP-03 | KR IP → defaultLocale fallback | x-forwarded-for=`1.1.1.1` (KR), 쿠키 없음 | `hongcafe.com` 접근 | `lookupCountryLocal=KR` → `mapCountryToLocale=defaultLocale=en` (KR locale 미포함) — **유형 D #9 정책 결정 필요** | P0 |
| GIP-04 | 알 수 없는 IP | x-forwarded-for=`192.0.2.1` (RFC 5737 reserved), 쿠키 없음 | 요청 진입 | `lookupCountryLocal=null` → `success=false` → en fallback + `__err__` flag 쿠키 (5분 TTL) | P0 |
| GIP-05 | 쿠키 cache hit (성공) | `hc_country=JP`, x-forwarded-for=`8.8.8.8` (US) | 요청 진입 | 쿠키 우선 → `mapCountryToLocale=ja` (lookup skip — fromCache=true) | P0 |
| GIP-06 | 쿠키 cache hit (실패 flag) | `hc_country=__err__`, x-forwarded-for=`126.0.0.1` (JP) | 요청 진입 | 쿠키 우선 → `defaultLocale=en` (5분간 lookup 재시도 안함) | P1 |
| GIP-07 | 쿠키 만료 후 재 lookup | hc_country 쿠키 24h 경과 | 요청 진입 | 쿠키 미존재 → 새 lookup 수행 → 새 쿠키 발급 | P1 |
| GIP-08 | 사용자 IP 추출 우선순위 | x-forwarded-for=`A,B,C` + x-real-ip=`D` | 요청 진입 | `extractClientIp` (RFC 7239 trusted proxy allowlist 기반) → trusted proxy 통과 후 첫 client IP 추출 | P1 |

### 2-2. 봇 감지

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| GIP-09 | Googlebot 진입 | User-Agent: `Mozilla/5.0 (compatible; Googlebot/2.1)` | 요청 진입 | `userAgent.isBot=true` → `applyCountryCookie` skip (쿠키 미발급, Google SEO 권고) | P0 |
| GIP-10 | Bingbot 진입 | User-Agent: `Mozilla/5.0 (compatible; bingbot/2.0)` | 요청 진입 | 동일 — 쿠키 미발급 | P0 |
| GIP-11 | 일반 사용자 (Chrome) | User-Agent: Chrome 모바일 | 요청 진입 | `isBot=false` → 쿠키 발급 | P0 |

### 2-3. Hostname allowlist (Host Header Injection 방어)

| # | 시나리오 | 사전조건 (production만) | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-----------------------|---------|---------|---------|
| GIP-12 | 정상 hostname | Host: `en.hongcafe.com` | 요청 진입 | `isAllowedHost=true` → 정상 처리 | P0 |
| GIP-13 | 변조된 hostname | Host: `evil.com` | 요청 진입 | `isAllowedHost=false` → 400 Bad Request | P0 |
| GIP-14 | x-forwarded-host 우선 | x-forwarded-host=`en.hongcafe.com`, Host=`internal-lb` | 요청 진입 | x-forwarded-host로 검증 → 정상 처리 (CDN/Proxy 환경) | P1 |
| GIP-15 | 개발 환경 bypass | NODE_ENV=development, Host=`evil.com` | 요청 진입 | allowlist 검증 skip (`process.env.NODE_ENV === 'production'` 가드) | P2 |

### 2-4. API 경로 단축

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| GIP-16 | API 경로 GeoIP skip | `/api/members/login-user` 호출 | 미들웨어 진입 | i18n + GeoIP 모두 skip + 보안 헤더만 적용 후 next() | P0 |
| GIP-17 | API에 HSTS 적용 (prod) | NODE_ENV=production, `/api/...` 호출 | 응답 헤더 확인 | `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` | P1 |

### 2-5. CSRF 부트스트랩

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| GIP-18 | hc_csrf 미존재 시 발급 | hc_csrf 쿠키 없음 | 페이지 진입 | `setCsrfCookie()` 호출 → hc_csrf + hc_csrf_meta 쿠키 발급 (커밋 `58152a1`) | P0 |
| GIP-19 | hc_csrf 존재 시 skip | hc_csrf 쿠키 있음 | 페이지 진입 | setCsrfCookie 미호출 | P1 |
| GIP-20 | setCsrfCookie 실패 시 graceful | mock 실패 | 페이지 진입 | catch 후 페이지 렌더링 계속 (proxy.js:51-55) | P1 |

### 2-6. 보안 헤더

| # | 시나리오 | 검증 항목 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| GIP-21 | CSP 적용 | response 헤더 | `Content-Security-Policy` 헤더에 SNS 6종(google/apple/kakao/naver/line/facebook) + Stripe + SendBird + GoogleFonts 도메인 포함 | P0 |
| GIP-22 | X-Frame-Options DENY | response 헤더 | `X-Frame-Options: DENY` | P0 |
| GIP-23 | X-Content-Type-Options | response 헤더 | `X-Content-Type-Options: nosniff` | P0 |
| GIP-24 | Referrer-Policy | response 헤더 | `Referrer-Policy: strict-origin-when-cross-origin` | P1 |
| GIP-25 | Permissions-Policy | response 헤더 | `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(self)` | P1 |
| GIP-26 | COOP same-origin-allow-popups | response 헤더 | `Cross-Origin-Opener-Policy: same-origin-allow-popups` (Stripe/SendBird 팝업 호환) | P1 |
| GIP-27 | HSTS production | NODE_ENV=production | `Strict-Transport-Security` 헤더 | P0 |
| GIP-28 | HSTS development skip | NODE_ENV=development | HSTS 헤더 미설정 | P2 |
| GIP-29 | frame-ancestors none | CSP 검사 | `frame-ancestors 'none'` (clickjacking 방어) | P1 |

### 2-7. lib/geoip.js 단위 검증 (`__tests__/lib/geoip.test.js`)

| # | 시나리오 | 대상 | 검증 |
|---|---------|------|------|
| UT-GIP-01 | `lookupCountryLocal` JP IP | `lib/geoip.js` | `JP` 반환 |
| UT-GIP-02 | `lookupCountryLocal` 잘못된 IP | `lib/geoip.js` | `null` 반환 (graceful) |
| UT-GIP-03 | `lookupCountryLocal` 빈 입력 | `lib/geoip.js` | `null` 반환 |
| UT-GIP-04 | `mapCountryToLocale` 매핑 | `lib/geoip.js` | JP→ja, KR→defaultLocale(ko 미포함), US→en |
| UT-GIP-05 | `resolveCountryLocale` 캐시 hit | `lib/geoip.js` | hc_country 쿠키 우선, lookup skip |
| UT-GIP-06 | `applyCountryCookie` TTL | `lib/geoip.js` | 성공 24h, 실패 5분 |
| UT-GIP-07 | `extractClientIp` trusted proxy | `lib/clientIp.js` | RFC 7239 allowlist 기반 추출 |

---

## 3. IntroScreen — 권한 설정 바텀시트 (`/[locale]/intro`)

### 3-1. 렌더링 테스트

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| R-01 | 풀스크린 배경 | 없음 | `en.localhost:3000/intro` 접근 | bg-[#6335b4] 풀스크린 + min-h-[100dvh] + flex center | P0 |
| R-02 | composite 로고 | 없음 | 페이지 로드 | `composite_logo_hongcafe.svg` (160x107, priority — LCP 최적화) | P0 |
| R-03 | 바텀시트 미표시 (초기) | 페이지 로드 직후 | DOM 검사 | 바텀시트는 translate-y-[100%]로 화면 밖, backdrop도 미렌더 | P0 |
| R-04 | 3초 후 바텀시트 표시 | 페이지 로드 후 3초 대기 | DOM 검사 | 바텀시트 translate-y-[0]로 슬라이드업 + backdrop fade-in | P0 |
| R-05 | Phone 아이콘 원형 | 바텀시트 표시 | 아이콘 영역 확인 | bg-[#6335b4] 5.8x5.8 원형 + Phone 아이콘 3.7x3.7 | P0 |
| R-06 | 권한 안내 텍스트 | 바텀시트 표시 | 텍스트 확인 | text-[1.8rem] font-medium leading-[2.7rem] tracking-[-0.018rem] text-center text-[#222222] whitespace-pre-line | P0 |
| R-07 | 거부 / 허용 버튼 | 바텀시트 표시 | 버튼 영역 확인 | gap-[0.9rem] flex 50:50, 거부 bg-[#bbbbbb], 허용 bg-[#6335b4] | P0 |
| R-08 | role="dialog" aria-modal | 바텀시트 표시 | a11y 속성 검사 | `role="dialog" aria-modal="true" aria-label={labels.permissionQuestion}` | P1 |
| R-09 | backdrop 위치 | 바텀시트 표시 | DOM 검사 | `<div className="fixed inset-0 z-[40] bg-[#000000]/50">` (backdrop) + 바텀시트 z-[50] | P1 |
| R-10 | 슬라이드업 transition | 3초 대기 | 애니메이션 검사 | `transition-all duration-[300ms]` — 300ms 내 완료 | P1 |

### 3-2. i18n 테스트 (hostname 기반)

| # | 시나리오 | 실행 단계 | 기대 결과 |
|---|---------|---------|---------|
| I-01 | EN 호스트 | `en.hongcafe.com/intro` → 3초 대기 | permissionQuestion/deny/allow 영어 |
| I-02 | JP 호스트 | `jp.hongcafe.com/intro` → 3초 대기 | permissionQuestion/deny/allow 일본어 |
| I-03 | KR 호스트 | `hongcafe.com/intro` | 본 프로젝트 범위 밖 (홍카페K) |
| I-04 | whitespace-pre-line | EN/JP 각각 | i18n 메시지의 `\n`을 줄바꿈으로 렌더 |

### 3-3. 인터랙션 테스트 (as-built)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| A-01 | 허용 클릭 | 바텀시트 표시 | 허용 버튼 클릭 | `router.push(\`/\${locale}/login\`)` | P0 |
| A-02 | 거부 클릭 | 바텀시트 표시 | 거부 버튼 클릭 | `router.push(\`/\${locale}/login\`)` | P0 |
| A-03 | Backdrop 클릭 (V5.7 §22-40) | 바텀시트 표시 | backdrop 영역 클릭 | handleNavigate → /login 이동 | P0 |
| A-04 | 본문 내부 클릭 → backdrop 미트리거 | 바텀시트 표시 | 바텀시트 본문(흰색) 클릭 | `e.stopPropagation()` → 이동 없음 | P0 |
| A-05 | Escape 키 | 바텀시트 표시 | Escape 키 입력 | handleNavigate → /login 이동 | P1 |
| A-06 | body scroll lock | 바텀시트 표시 후 | DOM 검사 | `document.body.style.overflow === 'hidden'` | P1 |
| A-07 | 언마운트 시 cleanup | 바텀시트 표시 → /login 이동 | login 진입 후 검사 | body overflow 원래대로 복원 + keydown listener 제거 | P1 |
| A-08 | 3초 미만 빠른 네비게이션 | 페이지 진입 후 1초 만에 다른 경로 이동 | clearTimeout 검증 | setTimeout 콜백 실행 안됨 (cleanup 정상) | P2 |
| A-09 | 페이지 새로고침 | 바텀시트 표시 상태에서 F5 | 새로고침 후 | 3초 타이머 재시작, showSheet=false 초기화 | P2 |

### 3-4. 접근성 테스트

| # | 시나리오 | 검증 항목 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| AC-01 | 거부/허용 버튼 type | 버튼 검사 | `<button type="button">` (form 외부, submit 트리거 방지) | P1 |
| AC-02 | 키보드 Tab | 거부 → 허용 순서 | 키보드 Tab 순서 정상 | P1 |
| AC-03 | 거부/허용 visible focus | 키보드 포커스 | outline 또는 focus-visible 스타일 | P2 |
| AC-04 | Escape 닫기 | 바텀시트 표시 | Escape 키로 닫힘 (= /login 이동) | P1 |
| AC-05 | aria-modal | 바텀시트 검사 | `aria-modal="true"` 속성 | P1 |

---

## 4. 크로스 페이지 플로우 테스트

| # | 플로우명 | 관련 페이지 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-----------|---------|---------|---------|
| F-01 | 루트 → GeoIP → intro | `/` → `/intro` | JP IP에서 `hongcafe.com` 접근 | proxy.js GeoIP → ja locale → `app/page.js`가 `/${locale}/intro`로 redirect | P0 |
| F-02 | intro → login (허용) | intro → login | 3초 대기 → 허용 클릭 | `/${locale}/login` 정상 표시 | P0 |
| F-03 | intro → login (거부) | intro → login | 3초 대기 → 거부 클릭 | `/${locale}/login` 정상 표시 | P0 |
| F-04 | intro → login (Escape) | intro → login | 3초 대기 → Escape | `/${locale}/login` 정상 표시 | P1 |
| F-05 | intro → login (Backdrop) | intro → login | 3초 대기 → backdrop 클릭 | `/${locale}/login` 정상 표시 | P1 |
| F-06 | 봇 GeoIP 미적용 | Googlebot로 `hongcafe.com` 접근 | 응답 검사 | 쿠키 미발급, defaultLocale 라우팅 (Google SEO 권고) | P0 |
| F-07 | GeoIP 실패 → en fallback | 알 수 없는 IP | 응답 검사 | en locale + `__err__` flag 쿠키 (5분 TTL) | P0 |
| F-08 | 캐시 hit 빠른 응답 | 두 번째 요청 (쿠키 있음) | 응답 시간 측정 | lookup skip → 첫 요청보다 빠른 응답 | P1 |

---

## 5. 보안 검증 시나리오

### 5-1. CSP 위반 시도

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-01 | 외부 미허용 도메인 fetch | 코드에 `fetch('https://evil.com')` | 페이지 진입 | CSP `connect-src` 위반 → 브라우저 차단 | P0 |
| SEC-02 | 인라인 script 시도 | `<script>alert(1)</script>` 주입 시도 | 페이지 진입 | next-intl/Image 자동 escape — 실행 안됨 | P0 |
| SEC-03 | iframe embed 시도 | 외부 사이트가 hongcafe iframe 시도 | 외부 페이지에서 검증 | `frame-ancestors 'none'` → embed 차단 | P0 |
| SEC-04 | object/embed 시도 | `<object data="evil.swf">` | 페이지 진입 | `object-src 'none'` → 차단 | P1 |

### 5-2. Host Header Injection

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-05 | Host: evil.com (production) | `curl -H "Host: evil.com" en.hongcafe.com` | 응답 확인 | 400 Bad Request (`isAllowedHost` 실패) | P0 |
| SEC-06 | Host: localhost (production) | `curl -H "Host: localhost" en.hongcafe.com` | 응답 확인 | 400 Bad Request | P0 |
| SEC-07 | x-forwarded-host 우선 | x-forwarded-host=`en.hongcafe.com`, Host=`internal-lb` | 응답 확인 | x-forwarded-host로 검증 → 200 | P1 |

### 5-3. CSRF Signed Double Submit

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-08 | hc_csrf 첫 진입 발급 | 쿠키 없는 첫 요청 | proxy.js 진입 | hc_csrf + hc_csrf_meta 발급 | P0 |
| SEC-09 | hc_csrf 재발급 안함 | 두 번째 요청 (쿠키 있음) | proxy.js 진입 | setCsrfCookie 미호출 | P1 |

### 5-4. 백드롭 인터랙션 (V5.7 §22-40)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| SEC-10 | Backdrop 클릭 시 navigate | 바텀시트 표시 | backdrop 영역 클릭 | handleNavigate 호출 (bubbling 정상) | P0 |
| SEC-11 | 본문 클릭 stopPropagation | 바텀시트 표시 | 흰색 본문 클릭 | `e.stopPropagation()`으로 backdrop 미트리거 | P0 |

---

## 6. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 화면설계서 PPTX(S14~S16) 기반 최초 작성 (5 시나리오) | 명우현 |
| v1.1 | 2026-04-17 | as-built 기준 전면 갱신: hostname i18n(EN/JP), **§2 proxy.js Middleware GeoIP 시나리오 신규**(GIP-01~29 — GeoIP 자동 라우팅/봇감지/Hostname allowlist/API 경로/CSRF 부트스트랩/보안 헤더 + 단위 테스트 UT-GIP-01~07), §3 IntroScreen as-built 인터랙션 보강(Backdrop/Escape/scroll lock/V5.7 §22-40 모달 표준), §5 보안 검증 신규(CSP/Host Header Injection/CSRF/Backdrop). 커밋 `aa40830` PHP API 의존 제거(geoip-lite 로컬 lookup 전환) 반영, 봇 감지 SEO 권고(F-06) 추가 | 명우현 |
