# Hostname 기반 i18n 라우팅 마이그레이션 계획서

| 항목 | 내용 |
|------|------|
| 작성자 | 명우현 |
| 작성일 | 2026-04-13 |
| 버전 | v1.0 (Draft) |
| 상태 | Draft — 이해관계자 결정 대기 |
| 선행 작업 | GeoIP 기반 로케일 자동 라우팅 (proxy.js 통합) — 완료 |
| 선행 작업 | GeoIP 로컬 lookup 전환 (`geoip-lite`) — 완료 (2026-04-14, PHP API 의존 제거) |
| 후속 작업 | 본 문서 |

---

## 1. 개요

### 1-1. 배경

`hongcafe_global_frontend`는 통합 프로젝트로 일본·영어권 사용자를 받는 것이 목표(KR은 레거시 홍카페K 유지). CLAUDE.md §라우팅의 최종 목표는 **hostname 기반 i18n** (`en.hongcafe.com`, `jp.hongcafe.com`)이지만, 현재 구현은 URL prefix 기반(`/en/login`, `/ja/login`)이다.

### 1-2. 목표

| 현재 (As-Is) | 목표 (To-Be) |
|---|---|
| `localePrefix: 'always'` | `localePrefix: 'never'` + `domains` 설정 |
| `hongcafe.com/en/login` | `en.hongcafe.com/login` |
| `app/page.js` → `redirect('/en')` | hostname → locale 매핑 |
| `i18n/request.js` 단일 locales 배열 | `defineRouting()` + domains 배열 |
| middleware GeoIP → URL prefix redirect | middleware GeoIP → hostname redirect |
| hreflang 태그 0개 | 모든 페이지에 hreflang + canonical |

### 1-3. ABSOLUTE 제약 (사용자 명시)

> **에이전트 오케스트레이션 성능저하 및 영향이 절대 가면 안 됨**

이 문서는 이 제약을 만족시키기 위한 두 가지 전략을 제시한다:
1. 파이프라인 **로직** 변경 0 — 검증 알고리즘은 동일
2. 파이프라인 **구성 데이터(URL 템플릿)** 변경은 단일 원자적 커밋 + 사전/사후 baseline 비교로 0 회귀 보장

---

## 2. 권위 있는 출처 검토

### 2-1. Google Search Central — Multi-Regional Sites
출처: <https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites>

**핵심 경고 (인용)**:
- *"Avoid automatically redirecting users from one language version of a site to a different language version."*
- *"Don't use IP analysis to adapt your content. IP analysis is difficult and generally not reliable."*
- *"Use `hreflang` annotations to help Google Search results link to the correct language version."*

**URL 구조 비교**:
| 구조 | 장점 | 단점 |
|---|---|---|
| ccTLD | 명확한 지오타게팅 | 비싸고 단일 국가만 |
| **Subdomains** | 쉬운 셋업, 서버 위치 자유 | URL만 보고 지오타게팅 의도 파악 어려움 |
| Subdirectories | 낮은 유지보수 | 단일 서버, 분리 어려움 |
| URL 파라미터 | — | **권장하지 않음** |

**결론**: subdomain과 subdirectory 모두 viable. SEO authority 관점의 명시적 우열 없음. 본 프로젝트는 `hongcafe.com`을 레거시가 점유하므로 **subdomain 강제**.

### 2-2. MDN — HTTP Cookies
출처: <https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies>

**핵심 인용**:
- *"If the Set-Cookie header does not specify a Domain attribute, the cookies are available on the server that sets it but **not on its subdomains**."*
- *"If specified, cookies are available on the specified server **and its subdomains**. For example, if you set Domain=mozilla.org from mozilla.org, cookies are available on that domain and subdomains like developer.mozilla.org."*
- *"a server with domain `foo.example.com` could set the attribute to `example.com` or `foo.example.com`, but not `bar.foo.example.com` or `elsewhere.com`"*
- `__Host-` prefix: *"must not have a Domain attribute specified... guarantees that such cookies are only sent to the host that set them"*

**결정적 함의**: `Domain=.hongcafe.com` 설정 시 쿠키가 `hongcafe.com`(레거시 홍카페K)에도 전송됨 → **레거시 PHP 백엔드와 쿠키 이름 충돌 가능성**.

### 2-3. next-intl 공식 문서 — Routing Middleware
출처: <https://next-intl.dev/docs/routing/middleware>

**locale 감지 우선순위 (인용)**:
1. *"A locale prefix is present in the pathname (e.g. `ca.example.com/fr`)"*
2. *"A locale is stored in a cookie and is supported on the domain"*
3. *"A locale that the domain supports is matched based on the accept-language header"*
4. *"As a fallback, the defaultLocale of the domain is used"*

**호스트 추출 방식**: *"the host is read from the `x-forwarded-host` header, with a fallback to `host`"*

**도메인 미스매치 처리**: *"if a domain receives a request for a locale that is not supported (e.g. `en.example.com/fr`), it will redirect to an alternative domain that does support the locale."*

**중요 함의**: next-intl이 자동으로 cross-domain redirect를 수행. 인프라(nginx)가 `x-forwarded-host`를 정확히 전파해야 함.

### 2-4. RFC 6265 — HTTP State Management Mechanism
출처: <https://www.rfc-editor.org/rfc/rfc6265>

§5.1.3 (Domain Matching): "A string `domain-matches` a given domain string if at least one of the following conditions hold: (1) The domain string and the string are identical. (2) All of the following conditions hold: The domain string is a suffix of the string. The last character of the string that is not included in the domain string is a `%x2E` ('.') character. The string is a host name."

→ 쿠키 `Domain=.hongcafe.com`은 `en.hongcafe.com`, `jp.hongcafe.com`, `api.hongcafe.com`, 그리고 **`hongcafe.com` 자체**에 모두 매치.

---

## 3. 코드베이스 영향 분석 (실측)

### 3-1. Frontend 코드 (Phase 2 작업 대상)

| 항목 | 개수 | 위치 |
|---|---|---|
| `<Link href={\`/${locale}/...\`}>` 패턴 | 13 | BottomNav, LoginForm, PageNavBar, MainContent, JoinMethods, Email/SnsJoinComplete |
| 하드코딩 `href="/en/intro"` | 1 | `app/not-found.js:10` |
| `router.push(\`/${locale}/...\`)` | 2 | `IntroScreen.js:19`, `LoginForm.js:48` |
| `redirect('/en')` | 1 | `app/page.js:4` |
| `params.locale` 사용 (Server Component) | 15+ | 모든 `app/[locale]/**/*.js` |
| `useLocale()` 사용 | 0 | (현재 props로 전달) |
| `generateMetadata()` 함수 | 6 | hreflang/canonical **없음** — Google 가이드 미준수 |
| messages/*.json 내 하드코딩 URL | 0 | 안전 |

**총 수정 대상**: 약 17개 라인 + 6개 metadata 함수.

### 3-2. 인증/보안/쿠키 (Phase 3 작업 대상)

| 쿠키 | 파일:라인 | 현재 Domain | sameSite | 마이그레이션 결정 필요 |
|---|---|---|---|---|
| `hc_token` | `lib/auth.js:177` | (없음) | strict | SSO 필요 시 `.hongcafe.com` 또는 host-only 유지 |
| `hc_refresh` | `lib/auth.js:178` | (없음) | strict | 동일 |
| `hc_fp` | `lib/auth.js:179` | (없음) | strict | 동일 |
| `hc_csrf` | `lib/csrf.js:65` | (없음) | strict | host-only 유지 권장 |
| `hc_csrf_meta` | `lib/csrf.js:73` | (없음) | strict | 동일 |
| `hc_country` | `lib/geoip.js:138` | (없음) | lax | host-only 유지 권장 |

**JWT/CSRF/security.js/rate-limit/sessionBridge**: 모두 host-agnostic 설계로 **변경 불필요**.

**CSP `connect-src 'self'`** (`proxy.js:88`): cross-subdomain XHR 차단. `https://*.hongcafe.com` 추가 필요 여부는 cross-subdomain API 호출 설계에 따라 결정.

### 3-3. 인프라 (Phase 4 작업 대상)

| 항목 | 현재 상태 | 마이그레이션 필요사항 |
|---|---|---|
| `infra/nginx/conf.d/nextjs.conf:20` | `server_name yourdomain.com` (placeholder) | `server_name en.hongcafe.com jp.hongcafe.com` |
| Wildcard SSL 인증서 | 미확인 | `*.hongcafe.com` 또는 SAN으로 en/jp 발급 |
| DNS A/AAAA 레코드 | 미확인 | en.hongcafe.com, jp.hongcafe.com → 새 인프라 IP |
| nginx `proxy_set_header X-Forwarded-Host $host` | **확인 필요** | next-intl이 요구. 누락 시 hostname 감지 실패 |
| Public Suffix List 등록 여부 | (해당 없음) | hongcafe.com은 일반 도메인 |

### 3-4. 에이전트 오케스트레이션 (Phase 1 사전 작업 — 가장 민감)

🔴 **URL 패턴 하드코딩 — 업데이트 필요**:

| 파일 | 라인 | 현재 패턴 | 분류 |
|---|---|---|---|
| `.claude/agents/qa-engineer.md` | 39, 43, 50, 56, 67, 97, 113, 127 | `${BASE}/en/{도메인}` | 🔴 **CONFIG** |
| `.claude/agents/component-refactor.md` | 177 | `http://localhost:3000/en/$PAGE` | 🔴 **CONFIG** |
| `.claude/agents/project-orchestrator.md` | 683, 840 | `/en/{도메인}`, `/$LANG/{도메인}` | 🔴 **CONFIG** |
| `scripts/pipeline/static_audit.py` SA-45 | 1014~1037 | regex `[a-z]{2}/` 강제 | 🔴 **LOGIC** |
| `scripts/pipeline/qss_to_playwright.py` | 80, 135, 136 | `/en/{domain}` fallback | 🔴 **LOGIC** |
| `playwright.config.js` | 12 | `baseURL: 'http://localhost:3000'` | 🟡 **TEST CONFIG** |

🟢 **영향 없음 (filesystem-based)**:

| 파일 | 검증 방식 |
|---|---|
| `scripts/pipeline/compile_build_spec.py` | `os.path.join('app', '[locale]')` — filesystem path |
| `scripts/pipeline/cross_reference_audit.py` XR-01 | filesystem 기반 매칭 (locale prefix 제거 후 비교) |
| `scripts/pipeline/meta_gate.py` | i18n parity는 messages/*.json 파일 비교 |
| `scripts/pipeline/pipeline_gate.py` | filesystem 검증 |
| `.claude/rules/section22-rules.md` | URL 인코딩 없는 원칙 기반 |
| `.claude/hooks/*.py` | 분석 결과 URL 의존성 없음 |

**핵심 통찰**:
- `app/[locale]/` 디렉토리 구조는 **유지** (next-intl 내부 라우팅용)
- locale 코드(`en`, `ja`, `ko`) 는 **유지**
- 변경되는 것은 오직 **URL 문자열 패턴** 뿐
- 따라서 파이프라인의 검증 알고리즘은 100% 동일하게 동작
- 변경되는 것은 검증 대상 URL의 **표현 형식**

---

## 4. 의사결정 매트릭스 (이해관계자 결정 필요)

> 본 절의 결정은 인프라팀, 백엔드팀, 도메인 소유자, 마케팅(SEO 담당) 의 합의가 필요하다.

### 4-1. KR 사용자 처리 (DECISION REQUIRED)

| 옵션 | 동작 | 트레이드오프 |
|---|---|---|
| **A. KR 사용자 = 레거시 홍카페K** | `hongcafe.com` 으로 리다이렉트 (별도 인프라) | CLAUDE.md/메모리와 일치. 단, GeoIP에서 KR 감지 시 외부 도메인 redirect — Google 권장사항 충돌 강화. **권장** |
| B. KR 사용자도 통합 프로젝트(ko locale) | `kr.hongcafe.com` 신설 | 레거시와의 정책 충돌. 비추 |

### 4-2. Cross-Subdomain SSO (DECISION REQUIRED — 보안 0순위 직결)

| 옵션 | 쿠키 Domain | 트레이드오프 |
|---|---|---|
| **A. 각 subdomain 독립 세션** | host-only (현재 그대로) | 사용자가 en→jp 이동 시 재로그인 필요. **레거시 hongcafe.com 쿠키와 충돌 없음**. 가장 안전. **권장**. |
| B. SSO with `Domain=.hongcafe.com` | `.hongcafe.com` | 쿠키가 레거시 홍카페K 도메인까지 전송 → 쿠키 이름 충돌 위험. 레거시팀 합의 필수. |
| C. SSO with 신규 parent domain | `.global.hongcafe.com` (or 신설) | DNS 추가 필요. 깨끗하지만 인프라 변경 큼. |

근거: MDN/RFC 6265 §5.1.3, OWASP Session Management Cheat Sheet (parent domain 쿠키는 보안 경계 약화).

### 4-3. GeoIP 자동 리다이렉트 vs 언어 선택 배너 (DECISION REQUIRED — Google 가이드 직결)

| 옵션 | 동작 | Google 가이드 준수 |
|---|---|---|
| **A. 현재 동작 유지 (자동 리다이렉트, 사용자 명시 URL은 존중)** | hc_country 쿠키 + 명시 URL pass-through | 🟡 부분 준수. 사용자 URL 명시 = 존중 → 명시적 override 가능. **현실적 권장**. |
| B. 자동 리다이렉트 제거, 배너로 전환 | 첫 진입 시 "We detected you're in Japan. Switch to ja.hongcafe.com?" 표시 | 🟢 완전 준수. UX 마찰 증가. |
| C. 하이브리드 | 첫 진입 = 배너, 24h 후 자동 적용 | 🟢 준수 + 점진적 채택 |

근거: <https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites>

**모든 옵션 공통 필수**:
- ✅ 모든 페이지에 `hreflang` 태그 (Google 권장)
- ✅ 사용자 visible 언어 스위처 컴포넌트
- ✅ subdomain 별 robots.txt + sitemap.xml + Search Console 등록

### 4-4. 로컬 개발 환경 (DECISION REQUIRED)

| 옵션 | 셋업 | 트레이드오프 |
|---|---|---|
| **A. `lvh.me`** (퍼블릭 도메인, 127.0.0.1로 resolve) | 추가 셋업 0. `en.lvh.me:3000` 접근 | 외부 DNS 의존. 회사 방화벽 차단 가능. |
| **B. hosts 파일** | `127.0.0.1 en.local.hongcafe.test jp.local.hongcafe.test` 추가 | 개발자별 수동 설정. CI 환경 별도. |
| **C. 조건부 middleware** | `process.env.NODE_ENV === 'development'` 시 URL prefix mode 폴백 | 개발/프로덕션 동작 차이 → "works on my machine" 위험. |
| **D. Docker compose hostname mapping** | `extra_hosts` 사용 | 가장 격리된 환경. 셋업 시간 증가. |

권장: **B + D 병행** (개발자는 hosts, CI는 docker-compose extra_hosts).

### 4-5. 배포 전략 (DECISION REQUIRED)

| 옵션 | 동작 |
|---|---|
| **A. Big-bang cutover** | DNS 전환 시점에 즉시 구 URL → 신 URL 308 redirect |
| **B. Dual-mode 병행** (1~2주) | 구 URL 유지 + 신 URL 정상 동작 + 점진적 redirect 강도 상승 |
| **C. Canary** | nginx에서 X% 트래픽만 신 URL로 분기 |

권장: **B (Dual-mode)**. 외부 링크/북마크 보호 + 회귀 발견 시 즉시 롤백 가능.

---

## 5. 위험 등록부 (Risk Register)

| ID | 위험 | 발생 시 영향 | 발생 가능성 | 완화책 |
|---|---|---|---|---|
| **R-1** | 에이전트 파이프라인 회귀 (가장 민감) | Phase 2.5/3 게이트 falsely PASS/REJECT, 산출물 품질 저하 | 중 | (1) Phase 0에서 baseline pipeline run 캡처 (2) Phase 1 후 동일 input으로 재실행하여 byte-level 비교 (3) static_audit.py regex는 backwards-compatible 작성 (구/신 URL 둘 다 인식) |
| **R-2** | 레거시 홍카페K와 쿠키 충돌 | 사용자 인증 실패, 세션 손실, 데이터 노출 | 중~높 | host-only 쿠키 유지 (옵션 4-2-A). Domain 변경 시 레거시팀 사전 합의 + 쿠키 prefix 분리 |
| **R-3** | Google 색인 누락/순위 하락 | 트래픽 손실 | 중 | hreflang 태그 사전 배포, robots.txt + sitemap.xml subdomain별 등록, Search Console 신규 property 등록 |
| **R-4** | 사용자 북마크 깨짐 | UX 마찰, 이탈 | 높 | Dual-mode 1~2주 운영, 구 URL → 신 URL 308 redirect 영구 유지 |
| **R-5** | nginx `x-forwarded-host` 미전파 | next-intl 호스트네임 감지 실패, fallback 로직만 동작 | 중 | 인프라팀 사전 검증, proxy.js에서 헤더 누락 감지 시 명시적 에러 로깅 |
| **R-6** | wildcard SSL 미준비 | 신 subdomain HTTPS 차단, 사용자 차단 | 낮 | 인프라팀에 사전 발급 요청 (LetsEncrypt DNS-01 또는 사내 CA) |
| **R-7** | CSP `connect-src 'self'` 위반 | cross-subdomain XHR 차단 | 낮 | cross-subdomain API 호출 없음을 사전 검증. 있으면 `https://*.hongcafe.com` 추가 |
| **R-8** | 로컬 개발자 환경 셋업 실패 | 개발 속도 저하 | 높 | hosts 파일 자동 설정 스크립트 + Docker 옵션 둘 다 제공 |
| **R-9** | E2E/Visual Regression 회귀 | Phase 3 PASS 판정 신뢰성 저하 | 중 | playwright.config.js와 qa-engineer.md를 동시 atomic update + sample 페이지로 dry-run |
| **R-10** | Edge runtime 호환성 | proxy.js 빌드 실패 | 낮 | next-intl `domains` config는 Edge 호환 (공식 검증). 빌드 검증 게이트로 차단 |

---

## 6. 단계별 마이그레이션 계획 (Phased Plan)

> **각 Phase 종료 시 반드시 baseline 비교 검증을 통과한 후 다음 Phase로 진행한다. 회귀 발견 시 해당 Phase 즉시 롤백.**

### Phase 0 — 사전 준비 및 Baseline 캡처 (마이그레이션 0 영향)

**목적**: 마이그레이션 시작 전 현재 파이프라인 동작을 baseline으로 고정.

**작업**:
1. 인프라팀 확정사항 수집:
   - DNS 권한 (en.hongcafe.com, jp.hongcafe.com 신설 가능 여부)
   - Wildcard SSL 인증서 발급 가능 여부
   - nginx `x-forwarded-host` 헤더 전파 설정
   - 레거시 홍카페K 쿠키 정책
2. 백엔드팀 확정사항 수집:
   - PHP 백엔드 cookie Domain 설정
   - cross-subdomain SSO 필요성
3. 4.1~4.5 결정사항 확정 회의
4. **Baseline pipeline run**:
   ```bash
   # 현재 상태에서 Phase 1~3.5 풀 실행, 산출물 백업
   git rev-parse HEAD > .baseline/sha.txt
   bash scripts/pipeline/run_full_pipeline.sh > .baseline/pipeline.log
   cp -r .agent-logs .baseline/agent-logs
   ```
5. **로컬 개발 hostname 셋업 가이드 작성** (`docs/dev/local-hostname-setup.md`)

**완료 기준**: 모든 결정사항 문서화, baseline 산출물 저장.
**롤백 기준**: 해당 없음 (코드 변경 0).

---

### Phase 1 — 에이전트 오케스트레이션 호환성 확보 (영향 0 보장)

**목적**: 파이프라인 스크립트 + 에이전트 instruction을 신/구 URL 형식 모두 인식하도록 확장. 행동 변화 0.

#### Phase 1-A: 검증 스크립트 backwards-compatible 확장

**대상**: `scripts/pipeline/static_audit.py`, `scripts/pipeline/qss_to_playwright.py`

**`static_audit.py` SA-45 변경 전후**:
```python
# 현재 (line 1014~1037): locale prefix 강제
href_re_v52 = re.compile(r'href=\{?[`"\']/?(?:\$\{[^}]+\}|[a-z]{2})/([^`"\'}\s#]+)')

# 변경 후: locale prefix 선택적 (구/신 둘 다 매칭)
href_re_v60 = re.compile(r'href=\{?[`"\']/?(?:(?:\$\{[^}]+\}|[a-z]{2})/)?([^`"\'}\s#]+)')
```

**검증**: Phase 0 baseline의 모든 코드를 입력으로 두 regex가 동일한 라우트 집합을 추출하는지 확인. **반드시 동일해야 함**.

```bash
python3 scripts/pipeline/static_audit.py --regression-check baseline
# exit 0 = backwards compatible
```

`qss_to_playwright.py:136`의 `f'/en/{domain}'` fallback도 동일하게 옵셔널화.

#### Phase 1-B: 에이전트 instruction URL 템플릿 업데이트

**대상**: `.claude/agents/qa-engineer.md`, `component-refactor.md`, `project-orchestrator.md`

**원칙**:
- **단일 atomic commit**으로 3개 파일 동시 변경
- URL 템플릿에 환경변수 치환 도입:
  ```js
  const BASE = process.env.E2E_BASE_URL || 'http://localhost:3000';
  const LOCALE_PREFIX = process.env.E2E_LOCALE_PREFIX || ''; // 마이그레이션 후 빈 문자열, 마이그레이션 전 '/en'
  await page.goto(`${BASE}${LOCALE_PREFIX}/{도메인}`);
  ```
- 환경변수로 분기하므로 Phase 1 시점에는 `E2E_LOCALE_PREFIX=/en`을 default로 유지 → 동작 변화 0
- Phase 2 시점에 default를 `''`로 전환

**검증**:
1. Phase 0 baseline과 동일한 input(SDD, 예제 도메인)으로 Phase 2-B 테스트 생성 dry-run
2. 생성된 `.spec.js` 파일을 baseline 산출물과 byte-level diff
3. **차이 0 확인**

**완료 기준**:
- ✅ 베이스라인과 byte-level 동일 산출물
- ✅ regression-check exit 0
- ✅ 풀 파이프라인 1회 실행 → 모든 게이트 PASS

**롤백**: git revert 1 commit. 모든 파일이 단일 commit이므로 단순.

---

### Phase 2 — Frontend 코드 마이그레이션 (코드 변경 17개 라인 + 6개 metadata)

**전제**: Phase 1 완료, baseline 0 회귀 확인.

#### Phase 2-A: i18n 라우팅 설정 전환

1. **`i18n/routing.js` 신규 작성** (next-intl 권장 패턴):
   ```js
   import { defineRouting } from 'next-intl/routing';
   export const routing = defineRouting({
       locales: ['en', 'ja', 'ko'],
       defaultLocale: 'en',
       localePrefix: 'never',
       domains: [
           { domain: 'en.hongcafe.com', defaultLocale: 'en' },
           { domain: 'jp.hongcafe.com', defaultLocale: 'ja' },
       ],
   });
   ```
   *근거: next-intl 공식 routing/configuration#domains*
2. **`i18n/request.js` 갱신**: `routing` 객체 사용하도록 변경.
3. **`proxy.js`**:
   - `createMiddleware({ locales, defaultLocale, localePrefix: 'always' })` → `createMiddleware(routing)`
   - `hasLocalePrefix` 헬퍼 제거 (불필요)
   - `lib/geoip.js`의 `applyCountryCookie` 호출 위치 재검토: locale은 이제 hostname에서 결정되므로 GeoIP는 **hostname redirect용**으로 변경
4. **`lib/geoip.js`**: `mapCountryToLocale` → `mapCountryToHostname` 리팩토링:
   ```js
   const COUNTRY_HOSTNAME_MAP = {
       JP: 'jp.hongcafe.com',
       // KR → 옵션 4.1 결정에 따라 'hongcafe.com'(레거시) 또는 미정의
   };
   const DEFAULT_HOSTNAME = 'en.hongcafe.com';
   ```

#### Phase 2-B: Link/Router 호출 locale prefix 제거

| 파일 | 라인 | Before | After |
|---|---|---|---|
| `app/not-found.js` | 10 | `href="/en/intro"` | `href="/intro"` |
| `app/page.js` | 4 | `redirect('/en')` | (제거 또는 `redirect('/')`) |
| `BottomNav.js` | 15, 32, 49, 66, 83 | `href={\`/${locale}/...\`}` | `href="/..."` |
| `LoginForm.js` | 178, 48 | 동일 | 동일 |
| `PageNavBar.js` | 28 | 동일 | 동일 |
| `MainContent.js` | 224, 415, 432 | 동일 | 동일 |
| `JoinMethods.js` | 56 | 동일 | 동일 |
| `Email/SnsJoinComplete.js` | 167, 195 | 동일 | 동일 |
| `IntroScreen.js` | 19 | `router.push(\`/${locale}/login\`)` | `router.push('/login')` |

총 **약 17개 라인** 수정.

#### Phase 2-C: SEO 메타데이터 추가 (Google 가이드 준수)

**6개 `generateMetadata()` 함수에 hreflang + canonical 추가**:
```js
export async function generateMetadata({ params }) {
    const { locale } = await params;
    const t = await getTranslations({ locale, namespace: 'login' });
    const path = '/login';
    return {
        title: `${t('title')} — HONG CAFE`,
        alternates: {
            canonical: `https://${locale === 'ja' ? 'jp' : 'en'}.hongcafe.com${path}`,
            languages: {
                'en': `https://en.hongcafe.com${path}`,
                'ja': `https://jp.hongcafe.com${path}`,
                'x-default': `https://en.hongcafe.com${path}`,
            },
        },
    };
}
```
*근거: Google Search Central — hreflang annotations*

**공통 헬퍼로 추출** (`lib/i18nMeta.js` 신규):
```js
export const buildAlternates = (locale, path) => ({
    canonical: `https://${locale === 'ja' ? 'jp' : 'en'}.hongcafe.com${path}`,
    languages: {
        'en': `https://en.hongcafe.com${path}`,
        'ja': `https://jp.hongcafe.com${path}`,
        'x-default': `https://en.hongcafe.com${path}`,
    },
});
```

#### Phase 2-D: 언어 스위처 컴포넌트 (Google 가이드 — visible language switcher)

`components/LanguageSwitcher.js` 신규 작성. Header 또는 Footer에 배치. 클릭 시 `window.location.assign('https://jp.hongcafe.com' + pathname)`.

#### Phase 2 검증 (회귀 게이트)

```bash
npm run build && npm run lint && npx vitest run
# Phase 0 baseline pipeline 재실행 → 산출물 비교
bash scripts/pipeline/run_full_pipeline.sh > .post-phase2/pipeline.log
diff -r .baseline/agent-logs/ .post-phase2/agent-logs/
# 실질적 차이는 URL 문자열만이어야 함
```

**완료 기준**:
- ✅ npm run build PASS
- ✅ vitest 전체 PASS
- ✅ Phase 1 호환 모드(`E2E_LOCALE_PREFIX=/en`)에서도 풀 파이프라인 PASS
- ✅ 신 모드(`E2E_LOCALE_PREFIX=''`)에서도 풀 파이프라인 PASS

**롤백**: 단일 PR로 격리. revert PR 1회.

---

### Phase 3 — 인증/쿠키 정책 적용 (DECISION 4-2 기반)

**4-2-A 옵션 (host-only 유지) 선택 시**: 코드 변경 0. PHASE 스킵.

**4-2-B/C 옵션 (SSO) 선택 시**:
- 모든 cookie set 호출에 `domain: '.hongcafe.com'` 또는 신설 parent 추가
- 영향 파일: `lib/auth.js:177-179`, `lib/csrf.js:65-79`, `lib/geoip.js:138-144`, `lib/cookies.js:6`
- **반드시 레거시 홍카페K 팀과 cookie name collision 사전 점검**
- CSP `connect-src` 갱신: `'self' https://*.hongcafe.com`
- 사후 인증 흐름 풀 회귀 테스트 (login, refresh, CSRF, fingerprint)

---

### Phase 4 — 인프라 (외부 작업)

**담당**: 인프라팀

1. DNS A/AAAA 레코드: `en.hongcafe.com`, `jp.hongcafe.com` → 신규 인프라 IP
2. Wildcard SSL 발급: `*.hongcafe.com` (LetsEncrypt DNS-01 권장) 또는 SAN 인증서
3. nginx vhost 갱신:
   ```nginx
   server {
       listen 443 ssl;
       server_name en.hongcafe.com jp.hongcafe.com;
       ssl_certificate ...;
       ssl_certificate_key ...;
       location / {
           proxy_pass http://nextjs:3000;
           proxy_set_header Host $host;
           proxy_set_header X-Forwarded-Host $host;  # next-intl 필수
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```
4. 구 URL → 신 URL 308 영구 redirect 룰 (Phase 5 cutover 시점):
   ```nginx
   location ~ ^/en/(.*)$ { return 308 https://en.hongcafe.com/$1; }
   location ~ ^/ja/(.*)$ { return 308 https://jp.hongcafe.com/$1; }
   ```
5. robots.txt + sitemap.xml subdomain별 배포
6. Google Search Console 신규 property 등록 + sitemap 제출 + hreflang 검증

**검증**: nginx config 문법 검사, 사전 staging 환경에서 cross-subdomain navigation flow 테스트.

---

### Phase 5 — Cutover (Dual-mode 1~2주)

1. 신 URL 활성화
2. nginx에서 구 URL 308 redirect ON
3. Search Console에서 hreflang 인덱싱 확인 (1~2주)
4. Google Analytics에서 트래픽 전환률, 에러율 모니터링
5. 안정화 확인 후 dual-mode 종료, 단일 신 URL만 유지

---

## 7. 검증 (Verification & Acceptance Criteria)

### 7-1. 에이전트 오케스트레이션 0 영향 증명

| 항목 | 검증 방법 | 합격 기준 |
|---|---|---|
| Phase 1~3 게이트 동작 | Phase 0 baseline vs Phase 1 후 산출물 byte-level diff | 차이 0 (URL 문자열 외) |
| static_audit.py SA-45 | 동일 input에 신/구 regex 적용, 추출 라우트 집합 비교 | 집합 동등 |
| qa-engineer 생성 .spec.js | 동일 SDD input에 신/구 템플릿으로 생성 | 동작 의미 동등 (URL 외) |
| Visual Regression 결과 | Phase 0 reference 이미지로 신 URL 캡처 → 비교 | 픽셀 차이 < 0.1% |
| 파이프라인 실행 시간 | Phase 0 baseline 시간 측정 | ±10% 이내 |

### 7-2. 기능 회귀

| 항목 | 검증 방법 |
|---|---|
| 빌드 | `npm run build` exit 0 |
| 단위 테스트 | `npx vitest run` 295/295 PASS (현재) + 신규 도메인 테스트 |
| 인증 흐름 | 로그인 → CSRF → API 호출 → 로그아웃 |
| GeoIP 흐름 | Curl `X-Forwarded-For: 133.x.x.x` → 302 jp.hongcafe.com |
| hreflang 검증 | <https://search.google.com/test/rich-results> 또는 hreflang test tool |
| Cross-subdomain 쿠키 격리 | en에서 로그인 → jp 접근 → 4-2 결정에 따라 검증 |

### 7-3. SEO

| 항목 | 검증 방법 |
|---|---|
| 모든 페이지 hreflang | View source에서 `<link rel="alternate" hreflang="...">` 존재 확인 |
| canonical | 각 페이지 canonical = 자기 자신 (다른 도메인 X) |
| robots.txt | `https://en.hongcafe.com/robots.txt`, `https://jp.hongcafe.com/robots.txt` 200 |
| sitemap | 각 sitemap에 hreflang xml 포함 |
| Search Console | 두 property 등록, sitemap 제출, hreflang 인식 확인 |

---

## 8. 개방 질문 (Open Questions)

> 이 질문들은 Phase 0 진입 전에 답변되어야 한다. 답변 전 진행 시 risk register 항목들이 활성화될 수 있다.

1. **DNS 권한**: hongcafe.com DNS는 누가 관리하며, 신규 subdomain 추가가 가능한가?
2. **레거시 홍카페K 팀 합의**: cookie 정책, 도메인 정책, redirect 정책 합의 가능한가?
3. **SSO 필요성**: en/jp 계정 데이터베이스가 통합인가, 분리인가? 사용자가 양쪽을 오갈 수 있는가?
4. **Wildcard SSL 비용/방법**: LetsEncrypt DNS-01 자동화 가능한가, 사내 CA를 사용하는가?
5. **Search Console 권한**: 신규 property 등록 권한 보유자는?
6. **마케팅/UX**: GeoIP 자동 리다이렉트 vs 배너 — 비즈니스 결정?
7. **백엔드 PHP 쿠키 Domain**: 4-2 옵션 결정 시 백엔드도 동시 변경 가능한가?
8. **개발자 환경 표준**: hosts vs lvh.me vs Docker 중 회사 표준은?
9. **Cutover 일정**: 마이그레이션 가능한 freeze window는?

---

## 9. 결론

### 9-1. 핵심 메시지

1. **기술적으로 마이그레이션 가능**: Frontend 코드 변경은 약 17 라인 + 6개 metadata 함수 + 1개 헬퍼. next-intl `domains` 설정으로 깔끔하게 처리 가능.
2. **에이전트 오케스트레이션 0 영향 보장 가능**: 단, Phase 1에서 backwards-compatible regex + 환경변수 기반 URL 템플릿 도입 + baseline byte-level 검증 게이트가 필수.
3. **가장 큰 리스크는 인프라/외부 의존**: DNS, SSL, 레거시팀 합의, Search Console — 이들이 미정인 상태에서 Frontend만 진행하면 무용지물.
4. **Google 가이드 부분 위반은 현실적 타협**: 자동 GeoIP 리다이렉트는 업계 표준이고 사용자 URL 명시는 존중하므로 부분 준수. hreflang + visible 언어 스위처로 보강.
5. **레거시 홍카페K와의 쿠키 충돌이 최대 보안 리스크**: 4-2-A(host-only 유지)가 가장 안전. SSO를 굳이 도입하지 말 것을 권장.

### 9-2. 권장 결정 (객관적 판단)

| 결정 항목 | 권장 옵션 | 근거 |
|---|---|---|
| 4-1 KR 사용자 | A. 레거시 홍카페K | CLAUDE.md/메모리 정합 |
| 4-2 SSO | A. host-only (변경 0) | RFC 6265, MDN, OWASP — 보안 경계 + 레거시 충돌 방지 |
| 4-3 GeoIP 동작 | A. 자동 리다이렉트 + 명시 URL 존중 | 현재 구현 유지, hreflang 보강으로 부분 준수 달성 |
| 4-4 로컬 dev | B+D 병행 | 환경 격리 + CI 호환 |
| 4-5 배포 | B. Dual-mode 1~2주 | 회귀 발견 시 즉시 롤백 |

### 9-3. 작업 순서 (Critical Path)

```
Phase 0 (결정/baseline) ─┐
                          ├── 인프라팀 작업 (DNS/SSL/nginx) ──┐
Phase 1 (파이프라인 호환)─┘                                   │
        ↓                                                     │
Phase 2 (Frontend 코드)                                       │
        ↓                                                     │
Phase 3 (인증/쿠키 — 옵션)                                    │
        ↓                                                     │
        └─────────────────── Phase 4 인프라 완료 대기 ────────┘
                                  ↓
                          Phase 5 Cutover (Dual-mode 1~2주)
                                  ↓
                          단일 신 URL 운영
```

**예상 공수**:
- Frontend 코드: 4~6 시간
- 에이전트 호환성 작업: 3~4 시간 (검증 포함)
- 인증/쿠키 (옵션 4-2-B 선택 시): 2~3 시간 + 풀 회귀 테스트
- 인프라: 외부 의존
- Verification + dual-mode 운영: 1~2주

---

## 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|---|---|---|---|
| v1.0 | 2026-04-13 | 최초 작성. Phase 0~5, 의사결정 매트릭스, 위험 등록부, 권위 출처 검증 포함 | 명우현 |
| v1.1 | 2026-04-14 | GeoIP 선행 작업이 `geoip-lite` 로컬 lookup으로 완료됨을 반영. `lib/geoip.js`는 더 이상 PHP API 의존 없음 — 자세한 내역은 `docs/specs/geoip-local-migration-plan.md` v1.1 참조. 본 문서의 아키텍처·결정 매트릭스는 그대로 유효하며, hostname 전환 단계에서 `lib/geoip.js`의 `mapCountryToLocale`만 `mapCountryToHostname`으로 리팩토링하면 된다. | 명우현 |

## 참고 문헌

1. **Google Search Central — Managing multi-regional and multilingual sites** <https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites>
2. **MDN — HTTP Cookies** <https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies>
3. **RFC 6265 — HTTP State Management Mechanism** <https://www.rfc-editor.org/rfc/rfc6265>
4. **next-intl — Routing Middleware** <https://next-intl.dev/docs/routing/middleware>
5. **next-intl — Routing Configuration** <https://next-intl.dev/docs/routing> (`domains` 옵션)
6. **OWASP — Session Management Cheat Sheet** <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html>
7. **Internal**: `CLAUDE.md` §라우팅, `.claude/rules/section22-rules.md`, `docs/specs/hostname-migration-plan.md` (본 문서)
