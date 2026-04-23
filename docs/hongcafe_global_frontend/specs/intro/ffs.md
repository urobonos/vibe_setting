# Frontend Functional Spec — Intro / 권한설정 + GeoIP 라우팅

> Source: 화면설계서 PPTX Slides S14~S16 + as-built 코드(`IntroScreen.js` / `proxy.js` middleware / `lib/geoip.js`) + GeoLite2 attribution(커밋 `bd5d4ce`) + 감사 문서(`2026-04-15-geoip-country-routing-scenario-matrix.md`, `2026-04-15-geolite2-attribution-relocation.md`)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | Intro / 권한 설정 + 진입 시 GeoIP 라우팅 |
| 사용자 목표 | (1) 글로벌 도메인 진입 시 사용자 국가에 맞는 hostname으로 자동 라우팅 (2) 앱 첫 실행 시 권한 안내 후 로그인 진입 |
| 퍼블리싱 상태 | 퍼블리싱 완료 |
| 기능 연동 상태 | **부분 연동** — `proxy.js` GeoIP 라우팅(geoip-lite 로컬 lookup, 봇 감지, hostname allowlist, CSP 헤더, CSRF 부트스트랩) 모두 구현 완료. **3초 타이머 + 바텀시트 권한 안내 UI도 구현 완료**. 다만 IntroScreen 자체는 GeoIP 라우팅 결과와 무관하게 동작 (별도 흐름) |
| i18n 네임스페이스 | `intro` |
| 지원 로케일 | `en`, `ja` (KR은 프로젝트 범위 밖) |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |

### GeoIP 라우팅 흐름 (proxy.js + lib/geoip.js, 커밋 `aa40830`)

```
요청 진입 (모든 비-API 경로)
  │
  ├── API 경로(/api/*) → 보안 헤더만 적용 후 next()
  │
  ├── Hostname allowlist 검증 (production만, isAllowedHost)
  │   └── 실패 → 400 Bad Request (Host Header Injection 방어)
  │
  ├── User-Agent 봇 감지 (next/server.userAgent)
  │   └── 봇 → GeoIP 쿠키 적용 skip (Google SEO 권고)
  │
  ├── GeoIP resolveCountryLocale(request)
  │   ├── hc_country 쿠키 = 유효 국가코드 → 즉시 매핑 (cache hit)
  │   ├── hc_country 쿠키 = "__err__" → en fallback (cache hit, 5분 TTL)
  │   └── 쿠키 없음 → extractClientIp → geoip-lite lookup
  │       ├── 성공 → 국가코드 → COUNTRY_LOCALE_MAP 매핑 → 24h TTL 쿠키 저장
  │       └── 실패 → en fallback + "__err__" 5분 TTL 쿠키 저장
  │
  ├── intlMiddleware (next-intl domains 모드 — hostname → locale)
  ├── applyCountryCookie (봇 제외)
  ├── CSRF 부트스트랩 (hc_csrf 쿠키 없으면 setCsrfCookie)
  └── 보안 헤더 적용 (CSP, HSTS, COOP, X-Frame-Options 등)
```

### 권한 설정 화면 흐름 (IntroScreen, 화면설계서 S15~S16)

```
/intro 진입 (hostname 분기 결과 EN/JP)
  ├── 풀스크린 보라색(#6335b4) 배경 + composite 로고
  └── 3초 후 setShowSheet(true)
      ├── 바텀시트 슬라이드업 애니메이션 (translate-y-[100%]→[0])
      ├── body scroll lock + Escape 키 핸들러 등록
      ├── backdrop(fixed inset-0 z-40 검정 50%) — 클릭 시 navigate
      ├── 권한 안내 텍스트 + Phone 아이콘 (S16 — Carrier 권한 등은 웹앱이라 미동작 표시)
      └── 거부(#bbbbbb) / 허용(#6335b4) → 모두 /${locale}/login 이동
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 | 슬라이드 |
|--------|----------|---------|------|-----------------|---------|
| `/[locale]/intro` | `app/[locale]/intro/page.js` | IntroScreen | Server → Client | `intro` | S15~S16 |

### 진입점 (루트 `/` 처리)

| 경로 | 동작 (as-built) |
|------|----------------|
| `/` (루트) | `app/page.js` Server Component — `proxy.js` middleware GeoIP 결과의 `locale`로 redirect (실제 hostname 분기는 next-intl domains가 처리) |
| `/intro` (locale prefix 없음) | hostname 기반 next-intl 라우팅 (en.hongcafe.com → en, jp.hongcafe.com → ja) |

### Middleware 매처

```js
export const config = {
    matcher: ['/((?!_next|_vercel|.*\\..*).*)'],
};
```

`/_next/*`, `/_vercel/*`, 정적 파일(확장자 포함) 제외 모든 경로에 proxy.js 적용.

---

## 3. 페이지 정의

### 3-1. proxy.js Middleware (GeoIP 라우팅 + 보안 헤더 + CSRF 부트스트랩)

| 항목 | 내용 |
|------|------|
| 파일 경로 | `proxy.js` (Next.js 16 미들웨어 — 기존 `middleware.js`에서 rename) |
| 런타임 | Node.js (geoip-lite는 Node 전용) |
| 적용 범위 | 모든 페이지 요청 (`/api/*`은 i18n skip, 보안 헤더만) |
| 주요 의존성 | `next-intl/middleware`, `lib/geoip.js`, `lib/csrf.js`, `lib/redirectGuard.js`, `i18n/routing.js` |

#### 핵심 동작

1. **API 경로 단축**: `/api/*` 요청 → `next()` + 보안 헤더만 적용 (i18n 스킵)
2. **Hostname allowlist** (production): `isAllowedHost(hostname)` 실패 시 400 응답
3. **봇 감지**: `userAgent(request).isBot` → GeoIP 쿠키 적용 skip
4. **GeoIP 라우팅**: `resolveCountryLocale(request)` → `applyCountryCookie(response, result)`
5. **CSRF 부트스트랩**: `hc_csrf` 쿠키 없으면 `setCsrfCookie()`
6. **보안 헤더**: CSP / HSTS(prod) / COOP=`same-origin-allow-popups` / X-Frame-Options=DENY 등

#### CSP 화이트리스트 도메인

| 카테고리 | 허용 도메인 |
|---------|-----------|
| script-src | `'self'`, `'unsafe-inline'`, js.stripe.com, www.google.com, www.gstatic.com, appleid.cdn-apple.com, connect.facebook.net |
| connect-src | `'self'`, sendbird.com / wss, api.stripe.com, www.google.com, oauth2/openidconnect.googleapis.com, appleid.apple.com, kauth/kapi.kakao.com, nid/openapi.naver.com, api/access.line.me, graph.facebook.com |
| frame-src | js.stripe.com, www.google.com, appleid.apple.com, www.facebook.com |
| img-src | `'self'`, data:, blob:, *.hongcafe.com, *.stripe.com, k.kakaocdn.net, ssl.pstatic.net, profile.line-scdn.net, platform-lookaside.fbsbx.com, lh3.googleusercontent.com |
| form-action | `'self'`, appleid.apple.com (Apple form_post 콜백) |
| frame-ancestors | `'none'` (clickjacking 방어) |

> 외부 CDN/스크립트 추가 시 반드시 메모리 `feedback_csp_check_on_external_resource.md` 참조 — proxy.js CSP 사전 갱신 필수.

### 3-2. lib/geoip.js — GeoIP 로컬 lookup (커밋 `aa40830`)

| 항목 | 내용 |
|------|------|
| 라이브러리 | `geoip-lite` (npm) — MaxMind GeoLite2 번들 DB 정기 동기화 |
| 라이선스 | MaxMind GeoLite2 — Creative Commons Attribution-ShareAlike 4.0 (`/legal-notices` 페이지에서 attribution 노출, §Phase B-2 참조) |
| 라이선스 attribution 페이지 | `/legal-notices` (분리 신설, 커밋 `bd5d4ce`) |
| Lookup 성능 | in-memory ~1ms (네트워크 호출 없음) |
| 쿠키명 | production: `__Host-hc_country` / 개발: `hc_country` |
| 성공 TTL | 24시간 (`SUCCESS_TTL_SEC`) |
| 실패 TTL | 5분 (`ERROR_TTL_SEC`) — `__err__` flag |
| 국가→로케일 매핑 | `JP→ja`, `KR→ko`, `US→en` (그 외는 `defaultLocale=en`) |
| Client IP 추출 | `lib/clientIp.js` — RFC 7239 trusted proxy allowlist 기반 |
| 매핑 미존재 시 | `defaultLocale` (`en`) fallback |

#### Public API

| 함수 | 시그니처 | 용도 |
|------|---------|------|
| `lookupCountryLocal(ip)` | `(string) → string\|null` | geoip-lite lookup, ISO alpha-2 반환 |
| `mapCountryToLocale(code)` | `(string\|null) → string` | 국가코드 → locale 매핑 |
| `resolveCountryLocale(request)` | `async (NextRequest) → { locale, countryCode, fromCache, success }` | proxy.js 진입점 |
| `applyCountryCookie(response, result)` | `(NextResponse, result) → void` | 쿠키 설정 (cache hit 시 skip) |
| `extractClientIp(request)` | `(NextRequest) → string\|null` | clientIp.js에서 re-export |

### 3-3. IntroScreen — 권한 설정 바텀시트 (S15~S16)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/intro` |
| Server Component | `app/[locale]/intro/page.js` — labels 구성 |
| Client Component | `app/[locale]/intro/_components/IntroScreen.js` |
| 화면설계서 | S15, S16 |

#### UI 섹션 (위→아래)

| # | 섹션 | 설명 (as-built) |
|---|------|----------------|
| 0 | 풀스크린 배경 | bg-[#6335b4] 보라색 + `min-h-[100dvh]` + `flex justify-center items-center` |
| 1 | composite 로고 | `Image src="/img/icon/composite_logo_hongcafe.svg" width=160 height=107` (priority — LCP 최적화) |
| 2 | Backdrop (showSheet 후) | `<div className="fixed inset-0 z-[40] bg-[#000000]/50" onClick={handleNavigate}>` — V5.7 §22-40 Modal Backdrop 인터랙션 |
| 3 | 바텀시트 컨테이너 | `fixed bottom-[0] left-[0] right-[0] z-[50]` + `transition-all duration-[300ms]` + `translate-y-[0]\|[100%]` 슬라이드업 (V5.8 §22-72 GNB 표준 — `left-[50%] translate-x-[-50%]` 패턴 금지) |
| 4 | 바텀시트 본문 | `max-w-[43rem] w-[100%] mx-[auto]` + `bg-[#ffffff]` + `rounded-t-[1.6rem]` + `pt-[3.2rem] pb-[1.2rem] px-[1.2rem]` + `gap-[3.2rem]` + `onClick={(e) => e.stopPropagation()}` (§22-32 / Fixed BottomSheet 예외로 자체 max-w 유지, 2026-04-20 430px 일원화) |
| 5 | Phone 아이콘 원형 | bg-[#6335b4] 5.8x5.8 원형 + Phone 아이콘 3.7x3.7 |
| 6 | 권한 안내 텍스트 | `text-[1.8rem] font-medium leading-[2.7rem] tracking-[-0.018rem] text-center text-[#222222] whitespace-pre-line` |
| 7 | 거부 / 허용 버튼 | gap-[0.9rem] flex 50:50 — 거부 bg-[#bbbbbb], 허용 bg-[#6335b4] |
| 8 | role="dialog" aria-modal | 바텀시트 컨테이너에 a11y 속성 |

#### 상태 관리 (as-built)

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `showSheet` | boolean | `false` | 3초 타이머 만료 후 `true` |
| (effect) `setTimeout 3000ms` | — | — | 마운트 시 3초 후 `setShowSheet(true)` |
| (effect) `body.style.overflow = 'hidden'` | — | — | showSheet=true 시 스크롤 lock |
| (effect) `keydown` Escape | — | — | Escape 키 → handleNavigate |

#### 인터랙션 (as-built)

| 액션 | 동작 |
|------|------|
| 마운트 | `setTimeout(3000)` → `setShowSheet(true)` |
| 3초 경과 | 바텀시트 슬라이드업 + 백드롭 fade-in + body scroll lock + keydown 등록 |
| 거부 클릭 | `router.push(\`/\${locale}/login\`)` |
| 허용 클릭 | `router.push(\`/\${locale}/login\`)` |
| Backdrop 클릭 | `handleNavigate` → `/login` 이동 (V5.7 §22-40) |
| Escape 키 | `handleNavigate` → `/login` 이동 |
| 본문 내부 클릭 | `e.stopPropagation()` — backdrop 트리거 차단 |
| 언마운트 | scroll overflow 복원 + keydown 해제 |

#### 비즈니스 규칙

| 규칙 | 설명 (as-built) |
|------|----------------|
| 거부/허용 모두 같은 도착지 | 웹앱은 OS 권한 제어 불가, 화면설계서 §S16의 권한 항목(전화/카메라/저장소)은 안내용 |
| 3초 타이머 | 브랜딩 노출 + 첫 진입 LCP 부담 최소화 |
| body scroll lock | 바텀시트 표시 중 배경 스크롤 차단 |
| Escape/Backdrop 닫기 | V5.7 §22-40 모달 인터랙션 표준 — 둘 다 navigate (닫기 후 페이지 머무는 동작이 아님) |

#### 엣지 케이스 (as-built)

| 케이스 | 처리 |
|--------|------|
| 페이지 새로고침 | 3초 타이머 재시작, showSheet=false로 초기화 |
| 빠른 네비게이션 (3초 미만) | clearTimeout으로 cleanup |
| 봇 진입 | proxy.js에서 GeoIP 쿠키 미적용 — IntroScreen 자체 동작은 동일 |
| GeoIP 쿠키 캐시 hit | 매핑 결과의 locale로 페이지 진입 (네트워크 호출 없음) |
| GeoIP lookup 실패 | en fallback + 5분 TTL `__err__` 쿠키 → 5분 후 재시도 |
| `/intro` 직접 진입 (locale 없이) | next-intl이 hostname 기반으로 locale 자동 분기 |

#### i18n (intro 네임스페이스)

| 키 | 용도 |
|----|------|
| `permissionQuestion` | 권한 안내 본문 (whitespace-pre-line으로 줄바꿈) |
| `deny` | 거부 버튼 |
| `allow` | 허용 버튼 |

#### 의존성 (as-built)

| 의존성 | 용도 |
|--------|------|
| `useRouter` | navigate to /login |
| `next/image` | composite 로고 + Phone 아이콘 |
| (proxy.js 의존) `next-intl/middleware` + `i18n/routing` | hostname → locale |
| (proxy.js 의존) `lib/geoip.js` | GeoIP lookup |
| (proxy.js 의존) `lib/csrf.js` | CSRF 부트스트랩 |
| (proxy.js 의존) `lib/redirectGuard.js` (`isAllowedHost`) | Host Header Injection 방어 |

---

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 파일 경로 | 사용 페이지 | 타입 | 비고 |
|---------|----------|-----------|------|------|
| IntroScreen | `app/[locale]/intro/_components/IntroScreen.js` | intro | Client | 풀스크린 — PageNavBar 미사용 |

---

## 5. 크로스 도메인 의존성

| 의존 도메인 | 의존 방향 | 설명 |
|-----------|----------|------|
| login | intro → login | 거부/허용/Escape/Backdrop 모두 `/login` 이동 |
| (전역) `lib/geoip.js` | proxy.js → 모든 도메인 | hostname 분기 + locale 결정 |
| (전역) `lib/csrf.js` | proxy.js → 모든 폼 도메인 | CSRF 토큰 부트스트랩 |
| legal-notices | intro의 GeoLite2 → legal-notices | MaxMind attribution 표시 (§Phase B-2) |
| region-select | intro의 GeoIP fallback → region-select | GeoIP 실패 또는 사용자 수동 변경 시 (§Phase B-1) |

---

## 6. 미확정 사항 (v1.1)

> 분류: **유형 A** = as-built 구현 완료 / **유형 B** = 감사 권고 미반영 / **유형 C** = 추가 구현 필요 / **유형 D** = 정책·디자인 확정 필요

| # | 우선순위 | 유형 | 항목 | 설명 | 근거 |
|---|---------|------|------|------|------|
| 1 | **[MUST]** | A | GeoIP 로컬 lookup | geoip-lite 번들 DB로 in-memory ~1ms — 네트워크 호출 제거 (커밋 `aa40830`) | as-built |
| 2 | **[MUST]** | A | 봇 감지 → GeoIP skip | `userAgent(request).isBot` — Google SEO 권고 (Google이 GeoIP 리다이렉트로 색인 손상 방지) | proxy.js:38-46 |
| 3 | **[MUST]** | A | hostname allowlist | production에서 `isAllowedHost` 통과 검증 — Host Header Injection 방어 (OWASP) | proxy.js:32-36 |
| 4 | **[MUST]** | A | CSRF 부트스트랩 | hc_csrf 쿠키 없으면 setCsrfCookie 호출 (Signed Double Submit, 커밋 `58152a1`) | proxy.js:48-56 |
| 5 | **[MUST]** | A | 보안 헤더 적용 | CSP / HSTS(prod) / COOP / X-Frame-Options / Permissions-Policy | proxy.js:58-94 |
| 6 | **[MUST]** | A | IntroScreen Backdrop/Escape 인터랙션 | V5.7 §22-40 모달 인터랙션 표준 | as-built |
| 7 | **[HIGH]** | C | GeoLite2 attribution 페이지 분리 | `/legal-notices` 신설 (커밋 `bd5d4ce`) — §Phase B-2에서 spec 정의 | 감사 `2026-04-15-geolite2-attribution-relocation.md` |
| 8 | **[HIGH]** | C | region-select 페이지 신규 | GeoIP 실패 또는 사용자 수동 변경용 — §Phase B-1에서 spec 정의 | 감사 `2026-04-15-geoip-country-routing-scenario-matrix.md` |
| 9 | **[HIGH]** | D | KR 사용자가 EN/JP 호스트로 진입 시 정책 | KR은 본 프로젝트 범위 밖이나 `KR → ko` 매핑이 `defaultLocale=en`으로 fallback (locales에 ko 포함 X) — 명시적 안내 또는 hongcafe.com 리다이렉트 결정 필요 | 감사 IP 시나리오 매트릭스 |
| 10 | **[HIGH]** | D | 사용자 수동 locale 전환 UX | 자동 GeoIP 결과를 사용자가 수동으로 변경할 수 있는 region-select 진입점 — 헤더? 푸터? mypage? | 디자인 확정 |
| 11 | **[MEDIUM]** | C | hc_country 쿠키 만료 후 재 lookup | 24h TTL 만료 후 재진입 시 자동 재 lookup (현재 구현됨) — 사용자에게 재 매핑 안내 정책 | UX |
| 12 | **[MEDIUM]** | C | GeoIP DB 정기 동기화 | geoip-lite는 npm 패키지 업데이트 필요 — MaxMind는 매주 화요일 GeoLite2 갱신, CI cron으로 주간 동기화 권고 | DevOps |
| 13 | **[MEDIUM]** | C | 봇 감지 정확도 모니터링 | `next/server.userAgent`의 `isBot`은 User-Agent 기반 — false positive/negative 모니터링 정책 | 운영 |
| 14 | **[MEDIUM]** | A | composite 로고 priority | `<Image priority>` LCP 최적화 (V5.6 §22-51 composite export) | as-built |
| 15 | **[LOW]** | C | 재방문 시 intro 스킵 | 쿠키/로컬스토리지 기반 — 화면설계서에 미정의 | UX 정책 |
| 16 | **[WONT]** | D | 웹앱 OS 권한 요청 | 브라우저는 OS 권한 제어 불가. 안내 UI만 (S16 권한 항목은 네이티브 앱용) | 정책 확정 |

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 화면설계서 PPTX(S14~S16) 기반 최초 작성 | 명우현 |
| v1.1 | 2026-04-17 | as-built 코드(`IntroScreen.js`/`proxy.js`/`lib/geoip.js`) + 감사 문서(`2026-04-15-geoip-country-routing-scenario-matrix.md`, `2026-04-15-geolite2-attribution-relocation.md`) 역반영. 유형 A/B/C/D 분류 도입. **§3-1 proxy.js Middleware 신규**(GeoIP/봇감지/Hostname allowlist/CSRF/보안 헤더/CSP 도메인) + **§3-2 lib/geoip.js geoip-lite 로컬 lookup 신규**(커밋 `aa40830` PHP API 의존 제거) + IntroScreen as-built 갱신(Backdrop/Escape/scroll lock/composite 로고 priority/V5.7 §22-40 모달 표준 적용). 미확정 사항 16건 분류(KR fallback 정책, region-select/legal-notices 신설 의존성, GeoIP DB 동기화 정책 등) | 명우현 |
