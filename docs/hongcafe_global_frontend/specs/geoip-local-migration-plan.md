# GeoIP 로컬 lookup 전환 실행 플랜 (PHP API 제거)

| 항목 | 내용 |
|---|---|
| 작성자 | 명우현 |
| 작성일 | 2026-04-14 |
| 버전 | v1.1 (Executed) |
| 상태 | 실행 완료 (2026-04-14) |
| 선행 작업 | GeoIP 라우팅 PHP 기반 구현 (완료, `lib/geoip.js` 존재) |
| 목표 | PHP GeoIP API 호출을 `geoip-lite` npm 패키지 기반 로컬 lookup으로 교체 |
| 실제 경로 | 경로 B (geoip-lite + 5건 보완). @maxmind/geoip2-node 이주는 미채택. |
| 실행 환경 | Git pull + `npm install` on server (Dockerfile/docker-compose/ci-cd.yml은 레거시) |

---

## 0. 이 문서 사용법 (새 세션 복원용)

이 문서는 `/clear` 이후 새 대화 세션이 이전 context 없이도 작업을 이어받을 수 있도록 자체 포함으로 작성되었다. 실행 시:

1. 이 파일만 Read하면 배경 + 실행 단계 전부 파악 가능
2. 연관 파일들은 §4에 명시됨
3. §5 단계별 순서대로 진행
4. §7 검증 체크리스트로 완료 확인
5. 의문점 발생 시 사용자 재확인 (Next.js 16 Node middleware 지원 상태는 빌드 시 판명)

---

## 1. 배경 및 결정 사항

### 1-1. 왜 PHP API를 제거하는가

이전 세션에서 구현된 PHP GeoIP API 호출 방식(`lib/geoip.js:fetchCountryFromPhp`)은 다음 문제를 가진다:

- **네트워크 홉 추가**: Next.js → PHP 1.5s timeout 구간 존재
- **백엔드 의존성**: PHP `/api/member/getGeoIp` 엔드포인트 신규 구현 필요 (미착수)
- **X-Forwarded-For trust chain 복잡도**: PHP 측 upstream 화이트리스트 설정 필요
- **GAP 분석서 권고 불일치**: Notion `플랫폼 IP 기반 노출 기준` GAP-3은 *"Next.js SSR에서 서버사이드 판별"*을 권고. MaxMind GeoLite2 언급.

IP → country 변환은 DB/API가 필요하지만, 반드시 PHP일 필요는 없다. `geoip-lite` npm 패키지가 MaxMind GeoLite2 DB를 번들링하므로 Next.js 내부에서 ~1ms lookup 가능.

### 1-2. 확정된 결정 사항 (사용자 승인)

| # | 결정 항목 | 확정 값 |
|---|---|---|
| 1 | GeoIP 조회 방식 | `geoip-lite` npm 패키지 로컬 lookup |
| 2 | Middleware runtime | `runtime: 'nodejs'` (Edge → Node 전환) |
| 3 | DB 갱신 전략 | **Dependabot 자동 PR** (월 1회) + `npm install` 시 자동 반영 |
| 4 | 테스트 전략 | 실제 lookup + 에러 케이스만 mock (hybrid) |
| 5 | 백엔드 PHP API | **취소** (사용자가 인프라팀에 공지 예정) |
| 6 | 노션 결정요청표 | B-03/B-05 항목 상태 갱신 (cancelled) |
| 7 | 롤백 전략 | Feature flag 미도입, 단순 git revert |
| 8 | 배포 환경 | **Docker 미사용** (Git pull + npm install on server) |
| 9 | Next.js 16.1.6 Node middleware 지원 | 빌드 시 자체 판명 (§5-B 참조) |

### 1-3. 인프라 전제 조건 (사용자가 별도 처리 중)

- **nginx `X-Forwarded-For` 헤더 전파**: 인프라팀에 요청 완료 (본 작업 시점에는 완료 가정)
- **Next.js 프로세스는 Git pull + npm install + npm run build + 재시작 플로우**로 배포됨
- `Dockerfile`, `docker-compose.yml`은 레거시로 간주 (본 작업에서 건드리지 않음)

---

## 2. 아키텍처 변경

### Before (현재 구현 상태)

```
Browser → nginx → Next.js proxy.js (Edge runtime)
                    │ extractClientIp (x-forwarded-for)
                    │ fetchCountryFromPhp (1.5s timeout, AbortController)
                    ▼
                  PHP GeoIP API (미구현)
                    │
                    ▼
                  redirect(/{locale}/...) + hc_country 쿠키
```

### After (전환 목표)

```
Browser → nginx → Next.js proxy.js (Node runtime)
                    │ extractClientIp (동일)
                    │ lookupCountryLocal (~1ms, in-memory geoip-lite)
                    ▼
                  redirect(/{locale}/...) + hc_country 쿠키
```

**핵심 단순화**:
- PHP API 호출 제거 → 네트워크 홉 0
- `AbortController`/timeout 로직 제거
- `__err__` error flag 쿠키 메커니즘 제거 (failure mode 거의 없음)
- 쿠키 24h 캐시는 유지 (매 요청 lookup 회피)

---

## 3. 기술적 제약 및 결정

### 3-1. Edge runtime → Node runtime 전환 필요

`geoip-lite`는 Node.js `fs` 동기 API로 `.dat` 바이너리 DB 파일을 로드한다. Edge runtime(V8 isolate)은 `fs` 미지원.

**proxy.js 설정**:
```js
export const config = {
    matcher: ['/((?!_next|_vercel|.*\\..*).*)'],
    runtime: 'nodejs',  // 추가
};
```

**Next.js 16.1.6 지원 상태 확인 분기**:
- **시나리오 A** (stable): 그대로 동작
- **시나리오 B** (experimental flag 필요): `next.config.mjs`에 `experimental: { nodeMiddleware: true }` 추가
- **시나리오 C** (미지원): 대체 전략 — `app/[locale]/layout.js`의 Server Component에서 `headers()` + `redirect()` 사용. 단, middleware보다 늦은 시점에 동작 → 페이지 shell 일부 생성 후 redirect 발생. 비교적 덜 이상적이지만 기능적으로 동등.

### 3-2. `serverExternalPackages` 설정

Next.js 번들러가 `geoip-lite`의 `.dat` 파일을 누락하지 않도록 외부 패키지로 선언.

```js
// next.config.mjs
const nextConfig = {
    serverExternalPackages: ['geoip-lite'],
    // 기존 설정 유지
};
```

**근거**: `node_modules/geoip-lite/data/*.dat`은 Webpack/Turbopack 기본 추적 대상이 아님. `serverExternalPackages`로 지정하면 번들링 제외 + 런타임에 `node_modules`에서 직접 require.

### 3-3. Docker 미사용 환경의 함의

- `node_modules/`가 서버에 직접 존재 (Git pull + `npm install`)
- `geoip-lite/data/*.dat` 파일이 자연스럽게 접근 가능
- `output: 'standalone'` 여부와 무관하게 동작 (이번 작업 스코프 외)
- DB 갱신: Dependabot PR 머지 → 서버 deploy 시 `npm install`이 최신 버전 설치

### 3-4. DB 갱신 자동화 (Dependabot)

**파일**: `.github/dependabot.yml` (신규)

```yaml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: monthly
    groups:
      geoip:
        patterns:
          - "geoip-lite"
    commit-message:
      prefix: "chore(deps)"
      include: "scope"
    labels:
      - "dependencies"
      - "geoip-db-update"
```

**동작**: 매월 1회 dependabot이 `geoip-lite` 최신 버전 확인 → PR 생성 → 리뷰 후 머지 → 다음 deploy에 반영.

**대안 (Dependabot 미사용 시)**:
- Renovate Bot 동일 기능
- 또는 수동으로 `npm update geoip-lite` 분기 실행

### 3-5. 로컬 개발 환경 IP 처리

로컬 dev 서버는 `x-forwarded-for`를 `::1` 또는 `127.0.0.1`로 받는다. `geoip.lookup('127.0.0.1')` → `null` 반환.

**동작 결과**: `lookupCountryLocal` → null → `mapCountryToLocale(null)` → `defaultLocale('en')` → `/en`으로 라우팅. 자연스러운 fallback. 추가 코드 불필요.

**개발자 JP 테스트**:
```bash
curl -I http://localhost:3000/login -H "X-Forwarded-For: 133.242.0.1"
# 기대: 302 Location: /ja/login
```

---

## 4. 변경 대상 파일 목록

| # | 파일 | 변경 유형 | 설명 |
|---|---|---|---|
| 1 | `package.json` | 의존성 추가 | `geoip-lite` 추가 |
| 2 | `package-lock.json` | 자동 갱신 | `npm install` 결과 |
| 3 | `lib/geoip.js` | **교체** | `fetchCountryFromPhp` → `lookupCountryLocal` |
| 4 | `proxy.js` | 1줄 추가 | `config`에 `runtime: 'nodejs'` |
| 5 | `next.config.mjs` | 1줄 추가 | `serverExternalPackages: ['geoip-lite']` (+ 필요 시 `experimental.nodeMiddleware`) |
| 6 | `.env.example` | 2줄 삭제 | `GEOIP_API_PATH`, `GEOIP_API_TIMEOUT_MS` 제거 |
| 7 | `__tests__/lib/geoip.test.js` | **재작성** | fetch mock → 실제 lookup + 에러 mock hybrid |
| 8 | `.github/dependabot.yml` | 신규 생성 | DB 자동 갱신 설정 (§3-4 참조) |
| 9 | `docs/specs/hostname-migration-plan.md` | 섹션 갱신 | GeoIP 아키텍처 다이어그램 + PHP 계약 섹션 제거 |
| 10 | `docs/specs/hostname-migration-decisions.md` | 항목 갱신 | B-03/B-05 상태 변경 |

**건드리지 않는 파일**:
- `Dockerfile`, `docker-compose.yml` (레거시로 간주)
- `proxy.js`의 GeoIP 외 로직 (CSRF, 보안 헤더, CSP 등)
- `lib/geoip.js`의 `extractClientIp`, `mapCountryToLocale`, `applyCountryCookie`, `resolveCountryLocale` 인터페이스 (내부 구현만 변경)
- `.claude/` 에이전트 파이프라인 전체

---

## 5. 실행 단계 (순차)

### 5-A. 의존성 설치

```bash
npm install geoip-lite
```

검증: `package.json`의 `dependencies`에 `geoip-lite` 추가 확인.

### 5-B. `lib/geoip.js` 교체

**유지 함수** (인터페이스 변경 없음):
- `extractClientIp(request)` — `x-forwarded-for` 파싱 로직 그대로
- `mapCountryToLocale(countryCode)` — JP→ja, KR→ko, else→en 그대로
- `applyCountryCookie(response, result)` — 쿠키 설정 로직 그대로 (단, `fromCache` 분기 제거 가능)
- `resolveCountryLocale(request)` — 쿠키 캐시 로직 유지, lookup 소스만 교체

**교체 함수**:

```js
// Before
import { locales, defaultLocale } from '@/i18n/request';

const fetchCountryFromPhp = async (clientIp) => {
    const baseUrl = process.env.NEXT_PUBLIC_API_URL;
    const path = process.env.GEOIP_API_PATH;
    if (!baseUrl || !path) return null;

    const timeoutMs = parseInt(process.env.GEOIP_API_TIMEOUT_MS, 10) || 1500;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
        const response = await fetch(`${baseUrl}${path}`, {
            method: 'GET',
            headers: {
                Accept: 'application/json',
                ...(clientIp && { 'X-Forwarded-For': clientIp }),
            },
            signal: controller.signal,
            cache: 'no-store',
        });

        if (!response.ok) return null;

        const data = await response.json();
        const code = data && typeof data.country_code === 'string'
            ? data.country_code.toUpperCase()
            : null;

        if (!code || !/^[A-Z]{2}$/.test(code)) return null;
        return code;
    } catch {
        return null;
    } finally {
        clearTimeout(timeoutId);
    }
};
```

```js
// After
import geoip from 'geoip-lite';
import { locales, defaultLocale } from '@/i18n/request';

const lookupCountryLocal = (clientIp) => {
    if (!clientIp) return null;
    try {
        const result = geoip.lookup(clientIp);
        if (!result || typeof result.country !== 'string') return null;
        const code = result.country.toUpperCase();
        return /^[A-Z]{2}$/.test(code) ? code : null;
    } catch {
        return null;
    }
};
```

**`resolveCountryLocale` 내부 변경**:
- `const countryCode = await fetchCountryFromPhp(clientIp);` → `const countryCode = lookupCountryLocal(clientIp);`
- `async` 키워드 유지 (인터페이스 호환성)

**상수 정리**:
- `ERROR_FLAG = '__err__'` — **유지** (caching 목적상 필요할 수 있음)
- `ERROR_TTL_SEC = 60 * 5` — **유지**
- 단, 네트워크 실패 시나리오가 사실상 0이므로 error flag 설정 빈도는 극히 낮음

**Export 목록**: 변경 없음 (호출부 호환성 유지).

### 5-C. `proxy.js` runtime 변경

```js
// 변경 전
export const config = {
    matcher: ['/((?!_next|_vercel|.*\\..*).*)'],
};

// 변경 후
export const config = {
    matcher: ['/((?!_next|_vercel|.*\\..*).*)'],
    runtime: 'nodejs',
};
```

**검증**: `npm run build` 실행.
- 성공 → §5-D로 진행
- `experimental.nodeMiddleware` 관련 경고 → §5-D에서 `next.config.mjs`에 플래그 추가
- `runtime: 'nodejs'` 미인식 에러 → **실행 중단, 사용자에게 보고**. 대안은 Server Component redirect 방식 (§3-1 시나리오 C)

### 5-D. `next.config.mjs` 설정

```js
import createNextIntlPlugin from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin('./i18n/request.js');

const nextConfig = {
    output: 'standalone',
    serverExternalPackages: ['geoip-lite'],  // 추가
    // 필요 시 (§5-C 빌드 결과에 따라):
    // experimental: {
    //     nodeMiddleware: true,
    // },
    images: {
        remotePatterns: [
            { protocol: 'https', hostname: 'www.figma.com', pathname: '/api/mcp/asset/**' },
        ],
    },
};

export default withNextIntl(nextConfig);
```

**주의**: 기존 `next.config.mjs`의 설정을 그대로 유지하고 `serverExternalPackages`만 추가. 전체 덮어쓰기 금지.

### 5-E. `.env.example` 정리

제거 대상:
```
GEOIP_API_PATH=/api/member/getGeoIp
GEOIP_API_TIMEOUT_MS=1500
```

`NEXT_PUBLIC_API_URL`은 다른 API 프록시 목적으로 여전히 필요 → **유지**.

### 5-F. `.github/dependabot.yml` 생성

§3-4의 내용 그대로 작성.

### 5-G. 테스트 재작성

**파일**: `__tests__/lib/geoip.test.js` (전체 교체)

**유지 테스트** (10건, 기존 로직 동일):
- `extractClientIp` 5건
- `mapCountryToLocale` 5건

**교체 테스트** (`lookupCountryLocal` 7건 — 실제 geoip-lite 사용):
```js
import geoip from 'geoip-lite';
import { describe, test, expect, vi, beforeEach } from 'vitest';
import { lookupCountryLocal } from '@/lib/geoip';

describe('lookupCountryLocal', () => {
    test('returns country code for known JP IP', () => {
        // 예: Google Japan IP (검증 후 실제 사용 IP로 교체)
        expect(lookupCountryLocal('133.242.0.1')).toBe('JP');
    });

    test('returns country code for known US IP', () => {
        expect(lookupCountryLocal('8.8.8.8')).toBe('US');
    });

    test('returns country code for known KR IP', () => {
        // 예: Naver IP
        expect(lookupCountryLocal('210.89.164.1')).toBe('KR');
    });

    test('returns null for private IPv4', () => {
        expect(lookupCountryLocal('10.0.0.1')).toBeNull();
        expect(lookupCountryLocal('127.0.0.1')).toBeNull();
        expect(lookupCountryLocal('192.168.1.1')).toBeNull();
    });

    test('returns null for private IPv6', () => {
        expect(lookupCountryLocal('::1')).toBeNull();
    });

    test('returns null for empty string', () => {
        expect(lookupCountryLocal('')).toBeNull();
    });

    test('returns null for malformed IP', () => {
        expect(lookupCountryLocal('not-an-ip')).toBeNull();
    });
});
```

**참고**: 테스트용 JP/KR/US IP는 **실행 시점에 geoip-lite로 실제 확인 후 고정**. IP 할당은 변동될 수 있으므로 테스트 실행 전 `node -e "console.log(require('geoip-lite').lookup('133.242.0.1'))"`로 검증 후 사용.

**교체 테스트** (`resolveCountryLocale` 6건):
- 쿠키 캐시 hit → skip lookup
- 쿠키 없음 + 유효 IP → lookup → country_code 반환
- 쿠키 없음 + private IP → `defaultLocale`
- 쿠키 없음 + IP 헤더 없음 → `defaultLocale`
- 쿠키 `__err__` flag → `defaultLocale` (skip lookup)
- 쿠키 invalid format → 재 lookup

**교체 테스트** (`applyCountryCookie` 5건):
- 성공 시 24h TTL + httpOnly + SameSite=Lax
- `fromCache: true` → 쿠키 미설정
- `countryCode: null` + `success: false` → error flag 쿠키 (5min TTL)
- production 환경 → `secure: true`
- dev 환경 → `secure: false`

**총 28건 예상**. 기존 26건 + 신규 2건.

### 5-H. 빌드 + 회귀 검증

```bash
npm run build
npx eslint proxy.js lib/geoip.js
npx vitest run __tests__/lib/geoip.test.js
npx vitest run  # 전체 회귀
```

**합격 기준**:
- `npm run build` exit 0, middleware 컴파일 성공
- ESLint PASS
- geoip 테스트 28/28 PASS
- 전체 vitest 295+ PASS (회귀 0)

### 5-I. 로컬 E2E 검증

```bash
npm run dev
```

```bash
# 1. 로컬 IP (private) → /en
curl -I http://localhost:3000/login
# 기대: 302 Location: /en/login

# 2. JP IP 시뮬레이션
curl -I http://localhost:3000/login -H "X-Forwarded-For: 133.242.0.1"
# 기대: 302 Location: /ja/login, Set-Cookie: hc_country=JP; Max-Age=86400

# 3. KR IP 시뮬레이션
curl -I http://localhost:3000/login -H "X-Forwarded-For: 210.89.164.1"
# 기대: 302 Location: /ko/login, Set-Cookie: hc_country=KR; Max-Age=86400

# 4. 쿠키 캐시 동작 — JP 쿠키 있으면 lookup skip
curl -I http://localhost:3000/login -H "Cookie: hc_country=JP"
# 기대: 302 Location: /ja/login, Set-Cookie 없음 (캐시 hit)

# 5. 로케일 prefix 있는 경로는 pass-through
curl -I http://localhost:3000/en/login -H "X-Forwarded-For: 133.242.0.1"
# 기대: 200 (redirect 없음, 사용자 의도 존중)
```

### 5-J. 문서 갱신

**`docs/specs/hostname-migration-plan.md`**:
- §3-2 아키텍처 다이어그램에서 PHP 호출 섹션 제거
- "PHP GeoIP 엔드포인트 계약" 섹션 전체 삭제
- "Dependencies / Blockers" 섹션에서 "Backend team: /api/member/getGeoIp 구현" 항목 삭제
- 변경 이력 v1.1 추가

**`docs/specs/hostname-migration-decisions.md`**:
- B-02 (백엔드 발송 이메일 hostname): **유지** (이건 별개 이슈)
- B-03 (OAuth callback URL): **유지** (별개 이슈)
- B-05 (D-14 쿠키 정책 cross-reference): **유지**
- PHP GeoIP 관련 언급 없음 → 변경 없음

### 5-K. 노션 갱신 (선택, 시간 여유 있을 시)

- `Hostname 마이그레이션 결정 요청표` 노션 페이지의 사전 확정 사항에 *"GeoIP는 Next.js 내부 `geoip-lite` 로컬 lookup, PHP API 호출 없음"* 추가
- `notion-update-page` tool 사용

### 5-L. Git 커밋

```bash
# 단일 atomic commit 권장
git add lib/geoip.js proxy.js next.config.mjs package.json package-lock.json \
    .env.example __tests__/lib/geoip.test.js .github/dependabot.yml \
    docs/specs/geoip-local-migration-plan.md docs/specs/hostname-migration-plan.md

git commit  # 메시지: 사용자 승인 후 작성
```

**커밋 메시지 템플릿** (사용자 확인 후 사용):
```
refactor(geoip): replace PHP API call with geoip-lite local lookup

- Remove fetchCountryFromPhp, replace with lookupCountryLocal (~1ms in-memory)
- Switch proxy.js middleware to Node runtime (geoip-lite needs fs sync API)
- Add serverExternalPackages to next.config.mjs for geoip-lite data files
- Set up Dependabot for monthly DB auto-update PRs
- Remove GEOIP_API_PATH / GEOIP_API_TIMEOUT_MS env vars
- Rewrite geoip.test.js with real lookup + error mock hybrid
- No backend PHP dependency, no network hop, no 1.5s timeout risk
```

**주의**: 사용자가 명시적으로 커밋 지시할 때까지 `git commit` 실행하지 말 것. 변경사항만 stage.

---

## 6. Critical 고려사항

### 6-1. Next.js 16.1.6 Node middleware 지원 분기

§5-C 빌드 결과에 따라:

| 빌드 결과 | 상태 | 대응 |
|---|---|---|
| ✅ 성공 | stable | 그대로 진행 |
| ⚠️ `experimental.nodeMiddleware` 경고 | experimental | `next.config.mjs`에 플래그 추가, 다시 빌드 |
| ❌ `runtime: 'nodejs'` 미지원 | 미지원 | **실행 중단, 사용자 보고** |

**미지원 시 대안**:
- `app/layout.js`(root) 또는 `app/[locale]/layout.js`에서 Server Component에 `headers()` + `redirect()` 사용
- middleware(proxy.js)는 Edge runtime 유지, GeoIP 로직은 layout으로 이동
- 단, layout은 middleware보다 늦은 시점 → 페이지 일부 SSR 후 redirect 발생
- 기능적으로는 동등하지만 초기 렌더링 TTFB 소폭 증가

### 6-2. `geoip-lite` 초기 로드 비용

- 프로세스 시작 시 DB 파일 로드 (~100ms, 1회성)
- 이후 모든 lookup은 메모리에서 ~1ms
- Blue/Green 배포에서 이 비용은 healthcheck 통과 전에 발생 → 사용자 노출 0

### 6-3. 백엔드 PHP API 취소 공지

- 사용자가 백엔드팀에 *"PHP GeoIP 엔드포인트 구현 취소"* 공지 필요
- 만약 이미 착수 상태라면 작업물 폐기
- 아직 미착수면 공지만으로 충분

### 6-4. Dependabot 권한

- 본 저장소에 Dependabot 활성화 권한 필요 (GitHub 저장소 설정)
- `.github/dependabot.yml` 파일만 추가하면 자동 활성화되나, 조직 정책에 따라 별도 승인 필요할 수 있음
- Dependabot 사용 불가 시 Renovate Bot 또는 수동 `npm update` 대체

---

## 7. 완료 체크리스트

- [ ] `npm install geoip-lite` 완료
- [ ] `lib/geoip.js` 교체 (fetchCountryFromPhp → lookupCountryLocal)
- [ ] `proxy.js` `runtime: 'nodejs'` 추가
- [ ] `next.config.mjs` `serverExternalPackages: ['geoip-lite']` 추가
- [ ] (조건부) `experimental.nodeMiddleware: true` 추가
- [ ] `.env.example` GeoIP 환경변수 2개 제거
- [ ] `.github/dependabot.yml` 신규 생성
- [ ] `__tests__/lib/geoip.test.js` 재작성 (28건 예상)
- [ ] `npm run build` PASS
- [ ] `npx eslint proxy.js lib/geoip.js` PASS
- [ ] `npx vitest run` 전체 PASS (회귀 0)
- [ ] 로컬 E2E 검증 (5건 curl 시나리오)
- [ ] `docs/specs/hostname-migration-plan.md` GeoIP 섹션 갱신
- [ ] (선택) 노션 결정요청표 업데이트
- [ ] 변경사항 git stage (커밋 대기)
- [ ] 사용자에게 완료 보고 + 커밋 지시 대기

---

## 8. 예상 공수

| 단계 | 소요 |
|---|---|
| §5-A ~ §5-F (코드/설정 변경) | 30분 |
| §5-G (테스트 재작성) | 40분 |
| §5-H ~ §5-I (빌드/회귀/E2E) | 20분 |
| §5-J ~ §5-L (문서/커밋) | 20분 |
| 예외 처리 / 빌드 이슈 해결 여유분 | 20분 |
| **합계** | **약 2시간** |

---

## 9. 롤백 전략

실행 중 이슈 발생 시:

| 이슈 | 대응 |
|---|---|
| §5-C 빌드 실패 (Node middleware 미지원) | §6-1 분기 적용. 대체 불가 시 사용자 보고 + 작업 중단 |
| §5-G 테스트 실패 (geoip-lite lookup 예상과 다름) | 실제 IP로 기대값 재검증 후 테스트 수정. 라이브러리 버그 가능성 검토 |
| §5-I E2E 실패 (쿠키 설정 안 됨) | `applyCountryCookie` 로직 디버깅. Node runtime에서 `response.cookies.set()` API 호환성 확인 |
| 커밋 후 프로덕션 이슈 | `git revert <commit-sha>` 1회로 전체 롤백 |

**미리 백업**: 작업 시작 전 현재 브랜치 상태 커밋 또는 stash로 보존.

---

## 10. 세션 복원 포인트

새 세션이 `/clear` 후 이 작업을 이어받을 때:

1. **이 파일 Read**: `docs/specs/geoip-local-migration-plan.md` 전체 읽기
2. **이전 구현 상태 확인**: 
   - `lib/geoip.js` 현재 상태 (PHP API 버전)
   - `proxy.js` GeoIP 인터셉트 로직 (12줄, 25~49줄 근처)
   - `__tests__/lib/geoip.test.js` 26건 테스트
3. **§5 단계별 실행**
4. **§7 체크리스트로 완료 확인**
5. **사용자에게 완료 보고**

---

## 참고 문헌

1. `geoip-lite` npm: https://www.npmjs.com/package/geoip-lite
2. MaxMind GeoLite2: https://www.maxmind.com/en/geolite2/signup (라이선스 키는 본 프로젝트에서 불필요 — geoip-lite가 번들링)
3. Next.js Node Runtime for Middleware: https://nextjs.org/docs/app/building-your-application/routing/middleware#runtime
4. Next.js `serverExternalPackages`: https://nextjs.org/docs/app/api-reference/next-config-js/serverExternalPackages
5. Dependabot config: https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file
6. 내부: `docs/specs/hostname-migration-plan.md`, `lib/geoip.js` (현재 구현), Notion `플랫폼 IP 기반 노출 기준` GAP-3

---

## 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|---|---|---|---|
| v1.0 | 2026-04-14 | 초안 작성 (PHP → geoip-lite 전환 + Docker 미사용 + Dependabot DB 갱신) | 명우현 |
| v1.1 | 2026-04-14 | 실행 완료 + 플랜 보정. 주요 정정: (1) Next.js 16의 `proxy.js`는 항상 Node.js runtime이며 `runtime: 'nodejs'` 설정 자체가 금지됨 — §3-1/§5-C/§6-1의 시나리오 A/B/C 분기는 모두 불필요. 설정 추가 없이 그대로 동작. (2) MaxMind GeoLite2 EULA 30일 의무 대응 — `.github/dependabot.yml` schedule을 `monthly` → `weekly`로 변경. (3) Attribution 추가 — `messages/{en,ja,ko}.json`에 `legal.maxmindAttribution` 키 추가 후 `app/[locale]/layout.js`에 렌더링. (4) 테스트 건수는 재작성 후 25건(extractClientIp 5 + mapCountryToLocale 5 + lookupCountryLocal 7 + resolveCountryLocale 5 + applyCountryCookie 3). 실측 IP(JP 133.242.0.1, KR 210.89.164.1, US 8.8.8.8)를 `node -e` REPL로 geoip-lite DB에 검증 후 고정. (5) **Pre-existing 블로커**: Tailwind v4.2.1 `markUsedVariable`의 `RangeError: Invalid code point 16707002` 이슈가 `app/globals.css`에서 발생하여 `next build` 및 페이지 렌더링이 차단됨. GeoIP 변경과 무관(stash 후 재현 확인). 별도 태스크로 Tailwind 버전 업데이트 또는 우회 필요. GeoIP 미들웨어 로직 자체는 `next dev` 환경에서 curl E2E 4건(private IP→/en, JP→/ja+쿠키, KR→/ko, 쿠키 캐시 hit)으로 전량 PASS 검증 완료. | 명우현 |
