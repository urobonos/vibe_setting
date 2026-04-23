# 리전 내부 아키텍처 + 글로벌 라우팅 — 최종 분석 및 권고

## 목차

- [1. 이 문서의 목적](#1-이-문서의-목적)
- [2. 경위: 왜 3개 보고서가 나왔는가](#2-경위)
- [3. 현재 상태 — 코드 기준 팩트](#3-현재-상태)
- [4. v1 오류 정정](#4-v1-오류-정정)
- [5. 3자 합의 사항](#5-3자-합의-사항)
- [6. 쟁점별 팩트 검증](#6-쟁점별-팩트-검증)
- [7. 최종 권고: 선택적 Pattern A + Nginx GeoIP2](#7-최종-권고)
- [8. 결정 사항 체크리스트](#8-결정-사항-체크리스트)
- [부록 A: 코드 검증 상세](#부록-a-코드-검증-상세)

---

## 1. 이 문서의 목적

4명(성민/우현/재영/상미)이 각자 다른 시각에서 작성한 보고서를 **실제 코드 6개 소스와 대조 검증**한 뒤, 표준성·비용·신뢰성·유지보수 관점에서 **최선의 방안 1가지를 제안**한다.

결론: **선택적 Pattern A + Nginx GeoIP2** — 85%의 API를 nginx 직접 라우팅으로 전환하고, 나머지 15%(OAuth/브루트포스/legacyMode)는 이동 준비가 될 때까지 BFF에 유지한다. 세부 근거는 §7, 우현 Hybrid와의 차이는 §7.2, 라우트별 분류는 §7.3, 실행 단계는 §7.5, 협의가 필요한 항목은 §8에 정리했다.

---

## 2. 경위: 왜 3개 보고서가 나왔는가

### 2.1 소통 부재에서 파생된 정합성 문제

| 시점 | 사건 |
| --- | --- |
| 글로벌 프로젝트 시작 | 우현이 프론트엔드 설계 시 **BFF를 처음부터 의도적으로 신설**. KR/JP 서비스에는 없던 구조 |
| 2026-04-06 | 백엔드/인프라 쪽에서 Pattern A(Reverse Proxy)를 논의. PND-007 RESOLVED 처리 |
| 이후 | "Pattern A 확정"이 문서에 전파. 프론트 관점(BFF 필요성)은 반영되지 않음 |
| 2026-04-22 | 3자 보고서 비교 과정에서 불일치 발견 |

**핵심**: 기술 논쟁이 아니라 **각자 작업하면서 생긴 소통 오류**의 파생이다. 우현은 BFF가 필요하다고 판단하여 만들었고, 백엔드/인프라는 Pattern A가 맞다고 논의했고, 이 두 결정이 조율되지 않았다.

### 2.2 "Pattern A 확정" 근거 추적 결과

| 문서 | 실체 |
| --- | --- |
| `INFRASTRUCTURE_GUIDE.md` §3.1 | "2026-04-06 회의, 재영+성민 합의" — **회의 내용/논의 과정 기록 없음** |
| `MTG-024_infra_briefing_20260406.md` | 제목은 회의록이나 실체는 "Claude 분석 결과 — 재영 공유용" **브리핑 문서** |
| `pending_decisions.tsv` PND-007 | 상태만 RESOLVED. **결정 근거/논의 내용/대안 기각 사유 없음** |
| `nextjs_ci4_api_architecture_patterns.md` | 5패턴 객관 분석. **Pattern A를 추천하지 않음** |

**결론**: "Pattern A 확정"은 PND-007 상태 업데이트가 여러 문서에 "확정"으로 전파된 것이다. 실제 회의 녹취록/참석자 서명/결정 논리는 존재하지 않는다. **3개 보고서 모두 이것을 기정사실로 인용한 것이 오류.**

### 2.3 KR/JP vs 글로벌 — BFF는 신설된 것

| 서비스 | 아키텍처 | BFF | 프론트엔드 |
| --- | --- | --- | --- |
| KR (hc3) | CI3 모놀리스 | 없음 | jQuery + 서버 렌더링 |
| JP (hongcafe-japan) | CI4 모놀리스 | 없음 | Vanilla JS + PHP 뷰 |
| **글로벌 (신규)** | CI4 + Next.js 16 | **있음 (신설)** | React 19 + Next.js SSR (별도 리포) |

BFF는 "레거시에서 물려받은 것"이 아니라 **글로벌 버전에서 프론트엔드 담당자가 의도적으로 설계한 것**이다.

---

## 3. 현재 상태 — 코드 기준 팩트

아래는 문서가 아닌 **실제 코드/설정**에서 확인한 현재 상태이다.

### 3.1 Nginx 실설정 (aws_nginx/conf.d/)

```
Client → Nginx (HTTPS:443)
  /api/*                    → proxy_pass → Next.js BFF (:3000)
  /__hongcafe_api__/api/*   → fastcgi_pass → PHP-FPM (:9080)   ← 외부 webhook/연동용
  /tools/                   → static alias (prd만)
  /*                        → proxy_pass → Next.js (:3000)
```

- **/api/*가 PHP가 아닌 Next.js로 라우팅됨** — Pattern A가 아닌 BFF 패턴
- `__hongcafe_api__`: Stripe webhook 등 외부 연동이 BFF를 우회하여 PHP 직접 접근
- X-Country-Code: **어디에도 없음** (Nginx, Next.js 양쪽)
- GeoIP2 모듈: **미설치**
- set_real_ip_from: **미설정**

### 3.2 프론트엔드 BFF 구성 (hongcafe_global_frontend/)

| 파일 | 역할 | 코드 검증 |
| --- | --- | --- |
| proxy.js | 미들웨어: GeoIP → hc_country 쿠키, Host allowlist, Bot 감지, 보안 헤더 | line 47: "CSRF는 백엔드가 단일 관리" |
| lib/geoip.js | geoip-lite로 MaxMind GeoLite2 로컬 lookup (~1ms) | line 15: `import geoip from 'geoip-lite'` |
| lib/clientIp.js | X-Forwarded-For에서 TRUSTED_PROXIES CIDR 기반 real IP 추출 | 자체 구현 IPv4 CIDR 파서 |
| lib/sessionBridge.js | 백엔드 프록시 헤더 구성 (Cookie, CSRF, X-Forwarded-For 포워딩) | X-Country-Code 미전달 |
| lib/apiHandler.js | API Route 프록시 핸들러 (4xx/5xx→200 래핑, legacyMode, rate limit) | line 205-209: 200 래핑 확인 |
| lib/errorMapper.js | 백엔드 에러 코드 → 사용자 안전 메시지 변환 (CWE-204) | line 74-110: normalizeBackendResponse |
| lib/security.js | 세션 기반 rate limit + exponential backoff | line 131-158: rateLimit() |

### 3.3 API Route Handler 실측

| 유형 | 건수 | 상세 |
| --- | --- | --- |
| **전체** | **68개** | (성민 보고서 67, 우현 75 — 양쪽 모두 부정확) |
| 순수 프록시 (createApiHandler만) | **58개** | 추가 로직 없이 PHP로 중계만 |
| SNS OAuth | **2개** | `auth/[provider]/route.js` (authorize URL + state/verifier 쿠키), `auth/[provider]/callback/route.js` (토큰 교환 + 자동 로그인) |
| 브루트포스 보호 | **2개** | `auth/login/route.js`, `members/login-user/route.js` (5회/15분 잠금, exponential backoff) |
| 커스텀 프록시 | **1개** | `members/notification-settings/route.js` (미구현 백엔드 EP 대비 mock fallback) |
| legacyMode 사용 | **확인 필요** | 68개 중 legacyMode: true 설정된 건수 식별 필요 |

### 3.4 백엔드 보안 필터 체인 (hongcafe_global_backend/app/)

| 필터 | 파일 | 상태 | 핵심 구현 |
| --- | --- | --- | --- |
| RateLimitFilter | app/Filters/RateLimitFilter.php | **구현** | IP 기반 60req/60s, api/* 전체 적용 |
| CsrfTokenFilter | app/Filters/CsrfTokenFilter.php | **구현** | HMAC-SHA256 Signed Double Submit, `hash_equals()`, TTL 2시간 |
| AuthFilter | app/Filters/AuthFilter.php | **구현** | JWT HttpOnly 쿠키 전용 (`hc_access`), Bearer 폴백 없음, API Key/Session 지원 |
| RoleFilter | app/Filters/RoleFilter.php | **구현** | ce_code 기반 callee 판별 |
| GeoRoutingService | app/Modules/Auth/Services/ | **구현** | MaxMind GeoLite2-City.mmdb, Haversine 거리 계산 |
| CountryResolverFilter | — | **미구현** | 설계(07-country-context.md)만 존재 |
| CountryResolver 서비스 | — | **미구현** |  |
| CountryConfigService | — | **미구현** |  |
| Config/Countries/ | app/Config/Countries/{KR,JP,US}.php | **구현** | 통화, 타임존, 로케일, 세율 |

**Filters.php 등록 순서**: `ratelimit` → `csrftoken` → `auth` (api/* 전체)

---

## 4. v1 오류 정정

| # | v1 내용 | 사실 | 심각도 |
| --- | --- | --- | --- |
| 1 | "Pattern A 확정(2026-04-06)" 기정사실 취급 | 회의록/결정근거 부재. 상태값 전파일 뿐 | **치명적** |
| 2 | "이 프로젝트는 OAuth 미사용" 단정 | SNS 로그인(Google, Line 등)이 OAuth 플로우. callback에서 토큰 교환 수행 | **높음** |
| 3 | BFF 신설 맥락 누락 | 우현이 처음부터 의도적으로 설계. KR/JP에 없던 구조 | **높음** |
| 4 | Route handler 67개 | 실측 **68개** (58 순수 + 2 OAuth + 2 브루트포스 + 1 커스텀 + 5 legacyMode 미확인) | 중간 |
| 5 | "~60개 순수 프록시" | 실측 **58개** | 낮음 |
| 6 | lib/rateLimit.js, lib/csrf.js 존재 전제 | 별도 파일 없음 (security.js 통합 / 백엔드 위임) | 낮음 |

---

## 5. 3자 합의 사항

아래는 **3자 모두 이견 없는 사항**이다. 아키텍처 결정과 무관하게 실행할 수 있다.

| 항목 | 성민 | 우현 | 재영 |
| --- | --- | --- | --- |
| geoip-lite npm 번들 제거 | O | O | O |
| GeoIP → Nginx 또는 CDN edge 이관 | O | O | O |
| 200 래핑(4xx/5xx→200) 폐기 | O | O (권고안 1) | — |
| 58개 순수 프록시가 BFF를 정당화하지 않음 | O | O (Azure 경고 인용) | O (0/5) |
| proxy.js는 페이지 미들웨어로 존속 | O | O (권고안 6) | — |

---

## 6. 쟁점별 팩트 검증

### 6.1 BFF 유지 논거 — 우현

### (a) OAuth confidential client (IETF/Auth0/Duende)

**v1 판정**: "이 프로젝트는 OAuth 미사용" → 부적용

**v2 수정**: SNS 로그인이 OAuth 플로우다. 기각은 성급했다.

**코드 확인 결과**:

- `auth/[provider]/route.js`: OAuth authorize URL 생성, PKCE state/verifier 쿠키 설정
- `auth/[provider]/callback/route.js`: provider로부터 authorization code 수신 → **토큰 교환** → 자동 로그인

**그러나**: 이 OAuth 플로우는 SNS 로그인(소셜 로그인) 한정이며, **서비스 자체 인증은 JWT 자체 발급**이다. OAuth가 서비스 전체 인증 체계는 아니다.

**수정 판정**: OAuth는 SNS 로그인 2개 라우트에 **한정적으로 존재**한다. 이 2건은 BFF 제거 시 이동 대상이지, BFF 전체를 유지해야 하는 근거는 아니다. callback의 client_secret 사용 여부는 추가 확인 필요.

### (b) CSRF 앱 레이어 필요 (OWASP)

**코드 확인 결과**:

- PHP `CsrfTokenFilter.php`: HMAC-SHA256 서명 + `hash_equals()` + TTL 2시간 — **완전 구현**
- `CsrfTokenService.php`: `hash_hmac('sha256', $encodedPayload, $this->secret, true)` — line 34
- `proxy.js` line 47-48: "CSRF는 백엔드(member-api)가 단일 관리" — **프론트 자체도 백엔드 위임을 명시**
- `sessionBridge.js` line 98-100: 클라이언트의 `X-CSRF-TOKEN` 헤더를 그대로 포워딩만

**판정: 부적용 유지.** CSRF는 PHP에서 처리하며, BFF는 헤더를 포워딩할 뿐이다. Pattern A에서 브라우저가 PHP에 직접 헤더를 보내면 동일하게 동작한다.

### (c) Strangler Fig — legacyMode

**코드 확인 결과**:

- `apiHandler.js` line 77: `legacyMode = false` (기본값)
- true 설정 시 line 149-157: JSON → `application/x-www-form-urlencoded` 변환
- `flattenForForm()` (line 37-52): 중첩 객체를 PHP 호환 form 인코딩으로 변환

**판정: 유효.** legacyMode: true인 라우트는 마이그레이션 완료까지 BFF 경유가 필요하다. **단, 해당 건수 식별이 선행되어야 한다.**

### 6.2 Pattern A 우위 논거 — 성민

| # | 논거 | "확정" 제거 후 유효성 | 코드 검증 |
| --- | --- | --- | --- |
| 1 | SPOF 제거: Next.js 죽어도 API 생존 | **유효** | 현재 /api/* 전부 Next.js 경유 — Next.js 장애 = API 전멸 |
| 2 | 독립 배포: FE 배포가 API에 영향 없음 | **유효** | pm2 restart = BFF 순단 = API 순단 |
| 3 | 성능: 2홉 vs 3홉, 4GB RAM 최적 | **유효** | 5패턴 비교표에서 A가 성능/인프라 ★★★★★ |
| 4 | 단순성: Nginx 설정 vs 프론트 코드 | **부분 유효** | OAuth 2건 + legacyMode N건은 이동 비용 존재 |
| 5 | 신뢰성: Nginx 표준 모듈 vs 자체 CIDR 파서 | **유효** | clientIp.js IPv4 전용 자체 구현 확인 |
| 6 | 확장성: 모든 downstream에 국가코드 전달 | **유효** | 현재 X-Country-Code 어디에도 없음 |
| 7 | 아키텍처 확정 사항 정합성 | **무효** | "확정" 근거 부재 |

### 6.3 글로벌 라우팅 — 재영

재영 보고서는 Layer 0(글로벌 라우팅)에 집중하며, 리전 내부와 독립된 문제다.

| 대안 | 학점 | 월비용 | 코드 검증 |
| --- | --- | --- | --- |
| ① nginx geoip + 302 | B- (80) | ~$4 | 실현 가능. edge-ec2 SPOF + DDoS 무방비가 한계 |
| ⑥ CF Worker (Free) | A (94) | $0 | DDoS 흡수 + origin 은닉. 단, AWS→CF 벤더 다각화 결정 필요 |

### 6.4 GeoIP 3패턴 비교 — 상미

상미는 GeoIP 구현 방식에 집중하여 3패턴을 비교했다.

| 패턴 | 방식 | 레이턴시 | 권고 순위 |
| --- | --- | --- | --- |
| Pattern 1 | Nginx GeoIP2 (로컬 mmdb) | <1ms (현재 geoip-lite 동등) | **1순위** |
| Pattern 2 | Next.js middleware → PHP whoami HTTP | 10~30ms (TTFB 합산) | 2순위 |
| Pattern 3 | Next.js FE → Next.js BE → PHP whoami | >15ms + 홉 추가 | 3순위 (성능 퇴보) |

**핵심 근거**: geoip-lite(<1ms)에서 whoami HTTP 왕복(10~30ms)으로의 교체는 명백한 퇴보다. Pattern 1은 처리 위치만 Node.js→Nginx C 모듈로 이동하므로 아무것도 잃지 않는다. hc_country 쿠키 캐시(TTL 24h)도 Pattern 1에서 그대로 유지된다.

**Pattern 2 유일한 장점**: PHP에서 JWT.country > GeoIP > Accept-Language 우선순위를 단일화하려는 경우. 단, §7.2 목표 아키텍처에서 Nginx가 X-Country-Code를 PHP에 전달하므로 PHP가 이 우선순위 로직을 구현할 수 있어 Pattern 2의 장점은 소멸한다.

**상미도 동일하게 범한 오류**: "Pattern A(2026-04-06 확정)"을 기정사실로 인용 — §2.2에서 이미 정정.

---

## 7. 최종 권고: 선택적 Pattern A + Nginx GeoIP2

### 7.1 왜 이것이 최선인가

| 기준 | 현재 (Full BFF) | Pattern A 전면 전환 | **선택적 Pattern A (권고)** |
| --- | --- | --- | --- |
| **표준 준수** | BFF 정당화 0/5 (Sam Newman) | 표준 Reverse Proxy | 표준 RP + 필요한 곳만 BFF 유지 |
| **비용** | 3홉 전체, RAM 추가 소비 | 2홉, RAM 최적 | 2홉 기본, 예외만 3홉 |
| **신뢰성** | Next.js SPOF (API 전멸) | SPOF 없음 | **58/68 라우트 SPOF 제거** |
| **유지보수** | 68개 route handler 관리 | 이동 비용 발생 | 58개 제거, 10개만 관리 |
| **현실성** | 이미 동작 중 | OAuth/legacyMode 이동 선행 | **즉시 착수 가능** |
| **배포 독립** | FE 배포 = API 순단 | 완전 독립 | 85% 독립 |

**핵심 판단**: 68개 중 58개(85%)가 순수 프록시다. 이 58개를 BFF에 통과시키는 것은 표준(Azure "동일 요청만 반복하면 BFF 부적합")에도, 비용에도, 신뢰성에도 불합리하다. 나머지 10개(OAuth 2 + 브루트포스 2 + legacyMode N + 커스텀 1 + 기타)는 **이동 준비가 될 때까지 BFF에 유지**한다.

### 7.2 "Hybrid"의 의미 — 우현 Hybrid와의 차이

이 권고도 Hybrid다. 다만 우현이 제안한 Hybrid와 **기본값과 방향이 반대**다.

|  | 우현의 Hybrid | **이 권고의 Hybrid** |
| --- | --- | --- |
| **기본값** | BFF 유지가 기본. 일부를 nginx로 이관 | **nginx 직접이 기본**. 필요한 곳만 BFF 유지 |
| **BFF 유지 근거** | OAuth confidential client + CSRF 일관성 (업계 표준 인용) | **legacyMode + OAuth 2건 + 브루트포스 2건** (실코드에서 확인된 것만) |
| **BFF 유지 범위** | 68개 중 대부분 유지, Pure Passthrough만 이관 | **58개(85%) 이관**, 10개만 유지 |
| **종착점** | BFF 상시 존속 (아키텍처적 선택) | **마이그레이션 완료 시 BFF 코어 소멸** (전환 기간의 잔여 부채) |
| **라우트별 판단 기준** | 4개 조건 충족 시 이관 | **BFF가 필요한 이유가 있는 것만 유지** |

**왜 이 방향이 더 나은가**:

1. **근거 차이**: 우현의 핵심 논거(OAuth confidential client, CSRF 앱 레이어)는 §6.1에서 이 프로젝트에 부적용으로 검증되었다. 이 권고의 BFF 유지 근거(legacyMode, OAuth 2건, 브루트포스 2건)는 실제 코드에서 확인된 것이다.
2. **비용 차이**: BFF 기본 유지 = 68개 route handler 관리 + 3홉 전체 + SPOF 존속. nginx 기본 = 10개만 관리 + 85% SPOF 제거.
3. **종착점 차이**: 우현의 Hybrid는 BFF가 아키텍처의 영구 구성 요소다. 이 권고에서 BFF는 전환이 끝나면 소멸한다. 최종 상태는 Pattern A에 수렴한다.

### 7.3 라우트별 분류 — BFF 유지/이관 기준

| 구분 | 라우팅 | 건수 | 근거 |
| --- | --- | --- | --- |
| 대부분 API | nginx → PHP 직접 | 58개 (85%) | 순수 프록시 — BFF 통과 이유 없음 |
| OAuth (SNS 로그인) | nginx → BFF → PHP | 2개 | authorize URL 생성 + 토큰 교환 로직 |
| 브루트포스 보호 (로그인) | nginx → BFF → PHP | 2개 | 계정별 5회/15분 잠금 + exponential backoff |
| legacyMode (마이그레이션 중) | nginx → BFF → PHP | N개 (식별 필요) | form-urlencoded 변환 필요 |
| 커스텀 (mock fallback) | nginx → BFF → PHP | 1개 | notification-settings 미구현 EP 대비 |
| 페이지 렌더링 | nginx → Next.js | 전체 | 변경 없음 |
| GeoIP | Nginx GeoIP2 모듈 | 전체 | <1ms 로컬 mmdb, X-Country-Code 헤더 전달 |

### 7.4 아키텍처 목표 상태

```
Client → Nginx
  ├─ /api/*  (대부분)     → fastcgi_pass PHP-FPM     ← 58개 직접 라우팅
  ├─ /api/auth/sns/*      → proxy_pass Next.js BFF   ← OAuth 2개 (이동 전까지)
  ├─ /api/auth/login      → proxy_pass Next.js BFF   ← 브루트포스 (이동 전까지)
  ├─ /api/members/login-* → proxy_pass Next.js BFF   ← 브루트포스 (이동 전까지)
  ├─ /api/legacy/*        → proxy_pass Next.js BFF   ← legacyMode (마이그레이션 전까지)
  └─ /*                   → proxy_pass Next.js        ← 페이지 렌더링 (변경 없음)

Nginx GeoIP2:
  $geoip2_country_code → X-Country-Code 헤더 → PHP + Next.js 양쪽 전달
```

### 7.5 실행 단계

### Phase 0: 즉시 (아키텍처 무관, 3자 합의)

| 작업 | 담당 | 내용 |
| --- | --- | --- |
| 200 래핑 폐기 | 프론트 | apiHandler.js line 205-209 제거. feature flag 점진 전환 |
| GeoIP Nginx 이관 | 인프라 | ngx_http_geoip2_module 설치 + X-Country-Code 헤더 추가 |
| geoip-lite 제거 | 프론트 | proxy.js → X-Country-Code 헤더 읽기로 변경, npm 의존성 삭제 |

### Phase 1: 선택적 Pattern A 전환 (핵심)

| 작업 | 담당 | 내용 |
| --- | --- | --- |
| 68개 라우트 전수 감사 | 공동 | legacyMode/커스텀 로직 유무 분류 → 이관 대상 확정 |
| 58개 순수 프록시 nginx 이관 | 인프라 | /api/* → fastcgi_pass (대상 라우트), BFF 유지 라우트는 location 분리 |
| set_real_ip_from 추가 | 인프라 | ALB 환경 대비 IP 추출 표준화 |
| secureFetch 수정 | 프론트 | PHP 직접 통신 시 응답 처리 (apiHandler 경유 제거) |

### Phase 2: 잔여 BFF 로직 PHP 이동

| 작업 | 담당 | 트리거 |
| --- | --- | --- |
| 브루트포스 보호 | 백엔드 | LoginAttemptService 구현 시 |
| legacyMode 제거 | 프론트+백엔드 | 해당 EP 마이그레이션 완료 시 |
| OAuth callback | 백엔드 | SNS 로그인 PHP 구현 완료 시 (client_secret 처리 포함) |

### Phase 3: BFF 코어 소멸

- Phase 2 완료 시 apiHandler.js, sessionBridge.js, errorMapper.js, security.js **모두 제거 가능**
- 잔존: proxy.js (페이지 미들웨어) + secureFetch (클라이언트 API 호출)

### 7.6 Layer 0: 글로벌 라우팅 (독립 결정)

| 단계 | 방안 | 비용 | 근거 |
| --- | --- | --- | --- |
| 즉시 | ① nginx geoip + 302 (edge-ec2 t4g.nano) | ~$4/월 | AWS 단독 스택 유지, 최소 비용 |
| MAU 3,000+ 또는 DDoS 시 | ⑥ CF Worker 전환 | $0 | 팀 합의 후 벤더 다각화 |

### 7.7 proxy.js 존속 범위

proxy.js는 **페이지 렌더링 미들웨어**로 존속한다. BFF와 무관.

| 역할 | 유지 | 변경 사항 |
| --- | --- | --- |
| i18n locale 라우팅 | O | 변경 없음 |
| Bot detection (SEO) | O | 변경 없음 |
| Host allowlist | O | 변경 없음 |
| 보안 헤더 (HSTS, CSP) | O | 네트워크 헤더는 Nginx 이관 검토 |
| hc_country 쿠키 | O → 수정 | geoip-lite 대신 X-Country-Code 헤더 읽기 |
| API 프록시 (/api/*) | **Phase 1에서 제거** | 58개 직접 라우팅 전환 시 |

---

## 8. 결정 사항 체크리스트

팀 협의 시 아래 항목을 하나씩 확인하면 된다.

### 즉시 실행 (합의 완료)

- [ ]  GeoIP → Nginx GeoIP2 이관 (geoip-lite 제거)
- [ ]  200 래핑(4xx/5xx→200) 폐기
- [ ]  X-Country-Code 헤더 Nginx에서 PHP + Next.js 양쪽 전달

### 협의 필요

- [ ]  **선택적 Pattern A 채택**: 58개 순수 프록시를 nginx → PHP 직접 라우팅으로 전환
- [ ]  **BFF 유지 대상 확정**: OAuth, 브루트포스, legacyMode 라우트 목록 확정
- [ ]  **글로벌 라우팅**: nginx geoip+302 (edge-ec2) 우선, CF Worker는 트리거 기반
- [ ]  **OAuth callback client_secret 확인**: confidential client 여부에 따라 PHP 이동 난이도 변동

### 후속 (Phase 2-3)

- [ ]  브루트포스 PHP 이동 (LoginAttemptService)
- [ ]  legacyMode EP 마이그레이션 완료 시 BFF 제거
- [ ]  SNS OAuth PHP 구현
- [ ]  BFF 코어 (apiHandler, sessionBridge, errorMapper) 최종 제거

---

## 부록 A: 코드 검증 상세

### A.1 검증 소스

| 소스 | 경로 | 확인 항목 |
| --- | --- | --- |
| Nginx 실설정 | aws_nginx/conf.d/{prd,stg,dev}.conf | 라우팅, 헤더, upstream |
| 프론트엔드 소스 | hongcafe_global_frontend/ | proxy.js, apiHandler.js, geoip.js 등 |
| 백엔드 소스 | hongcafe_global_backend/app/ | Filters, Services, Config |
| 백엔드 가이드 | docs/ | INFRASTRUCTURE_GUIDE, 5패턴 비교 등 |
| KR 레거시 | hc3/ | CI3 모놀리스 아키텍처 확인 |
| JP 서비스 | hongcafe-japan/ | CI4 모놀리스, BFF 없음 확인 |

### A.2 Nginx 상세

| 항목 | PRD | STG | DEV |
| --- | --- | --- | --- |
| Next.js 포트 | 3000 | 3001 | 3002 |
| PHP-FPM 포트 | 9080 | 9081 | 9082 |
| BFF keepalive | 32 | 16 | 8 |
| PHP keepalive | 16 | 8 | 4 |
| `__hongcafe_api__` CORS | $http_origin | "*" | "*" |
| /tools/ | 있음 | 없음 | 없음 |

### A.3 백엔드 필터 체인

```
요청 → ratelimit (IP 60/60s) → csrftoken (HMAC-SHA256) → auth (JWT/ApiKey/Session) → Controller
                                                                                     ↓
                                                                              role:callee (해당 시)
```

- CI4 내장 CSRF: 의도적 비활성 (`// 'csrf'` — REST API이므로)
- CI4 내장 CORS: 비활성 (`// 'cors'` — Same-Origin 아키텍처)

### A.4 프론트엔드 API Route 분류 (68개)

| 경로 패턴 | 건수 | 유형 |
| --- | --- | --- |
| auth/login | 1 | 브루트포스 래퍼 |
| auth/[provider]/* | 2 | OAuth (authorize + callback) |
| members/login-user | 1 | 브루트포스 래퍼 |
| members/notification-settings | 1 | 커스텀 (mock fallback) |
| 나머지 (chat/*, coin/*, favorites/*, items/*, member/*, members/*, mypage/*, profile/*, reviews/*, stripe/*) | 63 | createApiHandler 순수 프록시 중 58개 + legacyMode 확인 필요 5개 |

---

## 참고 문서

| 문서 | 경로 |
| --- | --- |
| 성민 보고서 | docs/reference/global/GeoIP_아키텍처_분석_PatternA_vs_BFF_20260422.md |
| 우현 보고서 (로컬) | docs/reference/global/아키텍처_우현_프론트검수_20260422.md |
| 재영 보고서 (로컬) | docs/reference/global/아키텍처_재영_인프라검수_20260422.md |
| 상미 보고서 (로컬) | docs/reference/global/아키텍처_상미_3패턴검수_20260422.md |
| 인프라 가이드 | docs/infra/INFRASTRUCTURE_GUIDE.md |
| 5패턴 비교 | docs/architecture/nextjs_ci4_api_architecture_patterns.md |
| IP 시나리오 GAP | docs/reference/global/IP_시나리오_GAP분석_20260414.md |
| MTG-024 브리핑 | docs/plans/MTG-024_infra_briefing_20260406.md |
| PND-007 | docs/pending_decisions.tsv (line 11) |
