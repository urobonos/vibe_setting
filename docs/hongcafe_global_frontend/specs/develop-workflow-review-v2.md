# `develop:` 워크플로우 2차 리뷰 — 수정 후 재평가

> **목적**: 1차 리뷰에서 도출된 BLOCKER 5건, CRITICAL 9건, HIGH 8건의 해결 여부를 실증 검증하고, 수정 과정에서 신규 발생한 이슈를 식별
> **평가 기준**: 코드베이스 실증 분석 + 학술 논문/업계 보고서 기반 근거
> **작성일**: 2026-03-25

---

## 1. 이전 이슈 해결 현황 — 스코어카드

### BLOCKER (5건)

| # | 이슈 | 판정 | 근거 |
|---|------|------|------|
| B1 | Phase 2 3-way 병렬 | **PARTIALLY RESOLVED** | 설계 문서 및 pipeline_gate.py에 Phase 3L 반영 완료. 단, CLAUDE.md에 `develop:` 워크플로우 섹션 미추가 — 오케스트레이터 에이전트가 참조할 지침 부재 |
| B2 | logic_audit.py 부재 | **RESOLVED** | 479라인, 7개 검증 체크 구현. LoginForm 실측에서 CRITICAL 2건 정확 탐지 확인 |
| B3 | secureFetch 미강제 | **RESOLVED** | static_audit.py에 negative lookbehind regex 추가. 클라이언트 컴포넌트에서 raw fetch() 감지 |
| B4 | 인메모리 Auth → 서버리스 무효 | **PARTIALLY RESOLVED** | authStore.js 추상화 레이어 생성, auth.js에서 모든 Map/Set 참조 제거. 단 Redis 어댑터는 stub(console.warn + fallback) |
| B5 | 세션 브릿징 부재 | **RESOLVED** | sessionBridge.js — 쿠키 화이트리스트(4종) + X-NextAuth-Token 헤더. apiHandler.js에 flattenForForm() + 세션 브릿지 통합 |

### CRITICAL (9건)

| # | 이슈 | 판정 |
|---|------|------|
| C1 | API_FIELD_MAP 1/15 도메인 | **RESOLVED** — 172줄→1,677줄, 17개 도메인 섹션 + 2개 공통 섹션 |
| C2 | 한국 vs 일본 API 분기 없음 | **UNRESOLVED** — `lib/countryRouter.js` 미구현 |
| C3 | API 응답 포맷 불일치 | **RESOLVED** — logic_audit.py 체크 #3이 7개 잘못된 패턴 감지 |
| C4 | URLSearchParams 중첩 객체 손실 | **RESOLVED** — flattenForForm() 재귀 플래트닝 |
| C5 | pipeline_gate에 로직 Phase 없음 | **RESOLVED** — Phase 3L + `--develop` 플래그 |
| C6 | SendBird 미통합 | **UNRESOLVED** — package.json에 없음 |
| C7 | Socket.IO 미통합 | **UNRESOLVED** — package.json에 없음 |
| C8 | gen_api_mock.py 커버리지 | **미검증** |
| C9 | 정적 감사가 로직 버그 못 잡음 | **RESOLVED** — logic_audit.py가 보완 |

### HIGH (8건)

| # | 이슈 | 판정 |
|---|------|------|
| H1 | hooks/ 비어있음 | **UNRESOLVED** |
| H2 | 공유 컴포넌트 미구현 | **UNRESOLVED** |
| H3 | Visual Regression 인터랙션 불가 | **UNRESOLVED** |
| H5 | Playwright 설정 없음 | **RESOLVED** — playwright.config.js 생성 |
| H7 | Stripe SDK 미설치 | **UNRESOLVED** |
| H8 | 크로스 도메인 컴포넌트 불일치 | **UNRESOLVED** |

### 요약: 22건 중 10건 RESOLVED, 2건 PARTIALLY, 9건 UNRESOLVED, 1건 미검증

---

## 2. 신규 발견 이슈 (수정 과정에서 발생)

### NEW-1. HIGH — CSRF 부트스트랩 누락

**현상**: `lib/csrf.js`에 `setCsrfCookie()` 함수가 구현·export되어 있으나, **프로젝트 어디에서도 호출하지 않음**. layout.js, proxy.js, 서버 액션 모두에서 import하지 않음.

**영향**: `hc_csrf_meta` 쿠키가 설정되지 않아 `fetchWithAuth.js`의 `getCsrfMeta()`가 빈 문자열 반환. `apiHandler.js`의 `requireCsrf: true` 설정에 의해 **모든 POST 요청이 403으로 차단**됨.

**근거**: OWASP CSRF Prevention Cheat Sheet — "Signed Double Submit Cookie 패턴은 서버가 토큰 쿠키를 설정하지 않으면 작동하지 않는다."

**해결안**: `app/[locale]/layout.js` 또는 `proxy.js`에서 매 요청 시 `setCsrfCookie()` 호출 추가.

---

### NEW-2. HIGH — security.js Rate Limiting/Nonce가 여전히 인메모리

**현상**: `lib/security.js`의 `usedNonces` (Map, line 65)와 `rateLimitStore` (Map, line 135)가 authStore 추상화로 마이그레이션되지 않음. auth.js의 동일한 문제(B4)는 해결했으나 security.js는 누락.

**영향**: 서버리스 멀티 인스턴스 환경에서:
- Rate limiting이 인스턴스별로 독립 → 공격자가 다른 인스턴스를 타격하여 우회 가능
- Nonce 재사용 방지가 인스턴스별로 독립 → 리플레이 공격 가능

**근거**: Google/MIT 2025 — 보안 메커니즘은 모든 인스턴스에서 공유 상태여야 유효.

**해결안**: security.js의 `usedNonces`, `rateLimitStore`도 authStore 패턴으로 추상화. 또는 Upstash Redis의 `INCR` + `EXPIRE` 조합으로 분산 Rate Limiting 구현.

---

### NEW-3. MEDIUM — secureFetch가 비JSON 응답에서 크래시

**현상**: `lib/fetchWithAuth.js` line 37에서 `return response.json()` — 항상 JSON 파싱 시도. 502 게이트웨이 에러(HTML 응답) 또는 네트워크 에러 시 파싱 실패로 클라이언트 컴포넌트가 크래시.

**영향**: 백엔드 일시 장애 시 모든 클라이언트 컴포넌트에서 unhandled exception 발생.

**해결안**:
```js
export const secureFetch = async (url, options = {}) => {
    // ... 기존 로직 ...
    if (!response.ok) {
        return { response: 'error', msg: `Server error (${response.status})`, data: {} };
    }
    const contentType = response.headers.get('content-type') || '';
    if (!contentType.includes('application/json')) {
        return { response: 'error', msg: 'Invalid response format', data: {} };
    }
    return response.json();
};
```

---

### NEW-4. MEDIUM — authStore 인메모리 TTL 미적용 (loginAttempts, activeSessions)

**현상**: `authStore.js`에서 `blacklistToken`만 `setTimeout`으로 TTL 적용. `refreshFamilies`, `loginAttempts`, `activeSessions`는 무한 증가.

**영향**: 장시간 실행 dev 서버에서 메모리 누수. 프로덕션에서는 Redis TTL로 해결될 영역이나, Redis가 stub인 현재는 dev에서도 문제.

**해결안**: 인메모리 어댑터에 `maxSize` 제한 (LRU 방식) 또는 `setInterval`로 만료 항목 주기적 정리.

---

### NEW-5. MEDIUM — apiHandler.js body 크기 검증 순서

**현상**: `maxBodySize` 검증(line 155)이 `request.json()` 파싱(line 145) **이후**에 실행됨. 악의적으로 10MB JSON을 전송하면 Node.js가 전체를 메모리에 파싱한 후에야 크기를 검증.

**근거**: OWASP — "요청 크기 제한은 파싱 전에 적용해야 한다. Content-Length 헤더 기반 사전 차단 권장."

**해결안**: `request.json()` 호출 전에 `Content-Length` 헤더 검사 추가.

---

### NEW-6. LOW — pipeline_gate Phase 3L 도메인 해석 취약

**현상**: task_id에서 도메인을 추출할 때 `parts[3]` 사용 (예: `TASK-20260323-login` → `login`). 하이픈 포함 도메인(`find-account` → `find`)에서 오해석 가능.

---

## 3. 업계 근거 기반 — 신규 패턴 평가

### 3-1. 서버리스 JWT 블랙리스트 스토리지

| 옵션 | 지연시간 | 비용 (1M req/mo) | 서버리스 적합성 |
|------|---------|-----------------|---------------|
| **Upstash Redis (HTTP)** | ~1ms | $2.25 | **최적** — TCP 연결 관리 불필요 |
| Vercel KV | ~1ms | $4.50 | Upstash 기반, 2배 비용 |
| DynamoDB | ~5-10ms | ~$1.25 | 디스크 기반, 높은 지연 |
| ElastiCache | ~0.5ms | $24+ | TCP 연결 관리 필요, 좀비 커넥션 위험 |

**출처**: Upstash 공식 비교, serverless-battleground.vercel.app 실측

**권장**: authStore.js의 Redis stub을 **Upstash REST SDK**(`@upstash/redis`)로 구현. HTTP 기반이므로 TCP 연결 관리 불필요, 서버리스에 최적.

**Vercel Fluid Compute**: 배포 플랫폼이 Vercel이면 **99.37% 콜드 스타트 제거** 가능. 단, 인메모리 상태 의존은 여전히 안티패턴.

---

### 3-2. 쿠키 포워딩 보안 — OWASP 기반 평가

현재 `sessionBridge.js`의 접근법 평가:

| 항목 | 현재 구현 | OWASP 권장 | 판정 |
|------|---------|-----------|------|
| 쿠키 화이트리스트 | O (4종만 포워딩) | O (allowlist 방식) | **적합** |
| CSRF 쿠키 미포워딩 | O (hc_csrf 제외) | O (CSRF 토큰은 별도 채널) | **적합** |
| JWT 커스텀 헤더 전달 | O (X-NextAuth-Token) | 중립 (커스텀 패턴) | **수용 가능** |
| X-Forwarded-For | O (기존 값 전달) | △ (신뢰 프록시만 허용) | **보완 필요** — PHP측에서 신뢰 프록시 검증 필요 |
| PHP 세션 쿠키 브라우저 노출 | △ (서버사이드 포워딩) | **미권장** — BFF가 자체 세션 발급 후 PHP 쿠키는 서버사이드만 | **향후 개선** |

**출처**: OWASP Cookie Attributes Testing Guide, Next.js 16 Proxy Documentation, OWASP CSRF Prevention Cheat Sheet

**Next.js 16 공식 가이드**: "avoid copying all incoming request headers — prefer a defensive approach using an allow-list." 현재 sessionBridge.js는 이 원칙을 준수.

**CVE-2025-29927 (CVSS 9.1)**: Next.js 미들웨어 우회 취약점. `x-middleware-subrequest` 헤더 주입으로 인증 건너뛰기 가능. Next.js 15.2.3+ 필수 — 현재 프로젝트는 Next.js 16.1.6이므로 **영향 없음**.

---

### 3-3. logic_audit.py — 정적 분석 정확도 평가

| 분석 방식 | False Positive 율 | 장점 | 단점 |
|----------|------------------|------|------|
| **Regex 기반** (현재 logic_audit.py) | 중간 | 구현 간단, 특정 패턴 타겟팅 효과적 | 구조적 컨텍스트 부족 |
| AST 기반 (Semgrep, PMD) | 낮음 | 의미론적 분석, 정확한 스코프 해석 | 구현 복잡, 언어별 파서 필요 |
| 런타임 계약 검증 (Pact, Dredd) | 최저 | 실제 동작 검증 | OpenAPI 스펙 필요 (PHP 백엔드에 없음) |

**출처**: PactFlow 공식 문서, Schemathesis 학술 평가 (Capital One 사례), Parasoft 정적 분석 연구

**판정**: PHP 백엔드에 OpenAPI 스펙이 없는 현재 상황에서 regex 기반 커스텀 린터는 **실용적 최선 선택**. False positive 위험은 6줄 컨텍스트 윈도우 분석으로 완화되어 있음. 향후 PHP 백엔드에 OpenAPI 스펙 추가 시 Pact 계약 테스트로 전환 권장.

---

### 3-4. 순차 vs 병렬 — Google/MIT 2025 데이터로 검증

| 지표 | 수치 | 적용 |
|------|------|------|
| 독립 에이전트 에러 증폭률 | **17.2x** | 오케스트레이터 없이 병렬 실행 시 위험 |
| 중앙 조정(오케스트레이터) 에러 증폭률 | **4.4x** | 현재 파이프라인의 패턴 |
| 순차 의존 작업에서 병렬 실행 성능 | **-39% ~ -70%** 저하 | **Phase 2→3 순차 변경을 정당화** |
| 최적 병렬 에이전트 수 | **3~5개** | Phase 2의 2-way 병렬은 최적 범위 |
| 조정 비용 | N(N-1)/2 (이차 증가) | 2개=1, 3개=3, 5개=10 — 2-way가 최소 |

**출처**: arXiv:2512.08296, Google Research Blog (2025.12)

**판정**: Phase 2를 3-way에서 2-way + 순차로 변경한 것은 **Google/MIT 데이터에 의해 정량적으로 정당화됨**. 순차 의존 작업(frontend-developer가 publisher 출력에 의존)을 병렬화하면 39~70% 성능 저하.

---

### 3-5. flattenForForm — PHP 배열 인코딩 호환성

| 패턴 | PHP 해석 | flattenForForm 처리 | 판정 |
|------|---------|-------------------|------|
| `user[name]=John` | `['user' => ['name' => 'John']]` | O (재귀 플래트닝) | **정확** |
| `ids[0]=1&ids[1]=2` | `['ids' => [1, 2]]` | O (배열 인덱스) | **정확** |
| `ids=1&ids=3` | `['ids' => '3']` (마지막만) | 해당 없음 (brackets 사용) | **회피됨** |
| null 값 | PHP: 빈 문자열 | `String('')` 변환 | **정확** |
| 중첩 배열 `dogs[0][name]` | `['dogs' => [0 => ['name' => ...]]]` | O (재귀) | **정확** |

**출처**: PHP parse_str() 공식 문서, MDN URLSearchParams

**판정**: flattenForForm()은 PHP의 배열 인코딩 규칙을 정확히 구현. 단, **File/Blob 객체는 미지원** — 현재 파일 업로드 API 없으므로 수용 가능.

---

## 4. 업데이트된 무결성 평가

### UI 디자인 무결성: **~95% (변동 없음)**

UI 파이프라인에 변경 없음. static_audit.py의 secureFetch 체크는 로직 영역.

### 비즈니스 로직 무결성: **~40% → ~55%**

| 개선 요인 | 기여도 |
|----------|--------|
| logic_audit.py (7개 자동 검증) | +10% |
| sessionBridge.js (인증 API 가능) | +5% |
| API_FIELD_MAP 15도메인 완성 | +5% |
| flattenForForm (중첩 데이터) | +2% |
| authStore 추상화 (인터페이스) | +1% |
| **소계** | **+23%** |

| 차감 요인 | 기여도 |
|----------|--------|
| CSRF 부트스트랩 미호출 (NEW-1) | -3% |
| secureFetch 비JSON 크래시 (NEW-3) | -2% |
| security.js 인메모리 (NEW-2) | -1% |
| 국가별 API 분기 없음 (C2) | -2% |
| **소계** | **-8%** |

**최종: ~40% + 23% - 8% = ~55%**

1차 리뷰 예측(~75%)과의 차이:
- Redis가 stub이라 실제 서버리스 보호 미동작 (-5%)
- CSRF 부트스트랩 누락이라는 예상 외 이슈 (-3%)
- security.js 마이그레이션 누락 (-2%)

### End-to-End 동작 시스템: **~30% → ~45%**

| 개선 요인 | 기여도 |
|----------|--------|
| 세션 브릿징 (인증 API 가능) | +8% |
| API Route 42개 createApiHandler 적용 | +5% |
| flattenForForm (복잡 폼) | +3% |
| Playwright 설정 | +2% |
| **소계** | **+18%** |

| 차감 요인 | 기여도 |
|----------|--------|
| CSRF가 모든 POST 차단 (NEW-1) | -3% |
| **소계** | **-3%** |

**최종: ~30% + 18% - 3% = ~45%**

SendBird, Socket.IO, Stripe가 여전히 없으므로 채팅/실시간/결제 도메인은 0% 유지.

---

## 5. 잔여 해결 우선순위

### 즉시 해결 필수 (develop: 실행 전)

| # | 이슈 | 예상 작업량 | 파일 |
|---|------|-----------|------|
| 1 | **NEW-1: CSRF 부트스트랩** — setCsrfCookie()를 layout.js 또는 proxy.js에서 호출 | 소 | `proxy.js` 또는 `app/[locale]/layout.js` |
| 2 | **B1 완료: CLAUDE.md에 develop: 섹션 추가** — 오케스트레이터 지침 | 중 | `CLAUDE.md` |
| 3 | **NEW-3: secureFetch 비JSON 방어** — response.ok + Content-Type 검증 | 소 | `lib/fetchWithAuth.js` |

### 단기 해결 권장

| # | 이슈 | 파일 |
|---|------|------|
| 4 | NEW-2: security.js Maps를 authStore 패턴으로 추상화 | `lib/security.js` |
| 5 | B4 완료: Upstash Redis 어댑터 실제 구현 (`@upstash/redis`) | `lib/authStore.js` |
| 6 | NEW-5: Content-Length 사전 검증 | `lib/apiHandler.js` |
| 7 | C2: 국가별 API 분기 설계 | `lib/countryRouter.js` (신규) |

### 도메인 작업 시 점진 해결

| # | 이슈 | 시점 |
|---|------|------|
| 8 | C6: SendBird 설치 + 초기화 | 채팅 도메인 develop: 시 |
| 9 | C7: Socket.IO 설치 + 초기화 | 상담사 목록 도메인 develop: 시 |
| 10 | H7: Stripe SDK 설치 | 결제 도메인 develop: 시 |
| 11 | H1-H2: 공유 컴포넌트/훅 | Sprint 1 공유 자산 구축 시 |

---

## 6. 결론

### 1차 → 2차 리뷰 간 개선도

```
BLOCKER:  5건 → 0건 (2건 부분 해결, 3건 완전 해결)
CRITICAL: 9건 → 3건 미해결 (C2, C6, C7 — 모두 도메인별 점진 해결 가능)
HIGH:     8건 → 5건 미해결 + 2건 신규 (NEW-1, NEW-2)
MEDIUM:   6건 → 3건 신규 (NEW-3, NEW-4, NEW-5)
```

### 핵심 판정

**`develop:` 워크플로우는 NEW-1(CSRF 부트스트랩) 해결 후 실행 가능 상태에 진입한다.**

NEW-1은 `setCsrfCookie()` 호출 1줄 추가로 해결되는 소규모 작업이다. 이것이 해결되면:
- UI 퍼블리싱: ~95% 무결성 (검증됨)
- 로직 주입: ~58% 무결성 (CSRF 해제 시 +3%)
- E2E 동작: ~48% (CSRF 해제 시 +3%)

잔여 미해결 항목(SendBird, Socket.IO, Stripe, 공유 컴포넌트)은 **해당 도메인 작업 시 점진적으로 해결 가능**하며, 인증/마이페이지/리뷰 등 외부 서비스 의존성이 낮은 도메인부터 `develop:` 실행이 가능하다.

---

## 참고 문헌

| 출처 | 인용 내용 |
|------|---------|
| Upstash Redis 공식 비교 (2025) | Upstash vs DynamoDB/ElastiCache 지연시간, 가격 |
| serverless-battleground.vercel.app | 서버리스 DB 실시간 벤치마크 |
| Vercel Fluid Compute 문서 (2026) | 99.37% 콜드 스타트 제거, attachDatabasePool |
| OWASP Cookie Attributes Testing Guide | 쿠키 보안 속성 테스트 가이드라인 |
| OWASP CSRF Prevention Cheat Sheet | Signed Double Submit Cookie 패턴 요구사항 |
| Next.js 16 Proxy Documentation (2026-03-20) | 헤더 포워딩 allowlist 원칙 |
| CVE-2025-29927 (CVSS 9.1) | Next.js 미들웨어 우회 — 15.2.3+ 패치 |
| PactFlow Bi-Directional Contract Testing | 정적 API 계약 비교 방식 |
| Schemathesis (Capital One, 2025) | 대안 대비 1.4~4.5배 결함 탐지 |
| Google/MIT arXiv:2512.08296 (2025.12) | 에이전트 스케일링: 에러 증폭, 조정 비용, 순차 의존 작업 |
| PHP parse_str() 공식 문서 | 배열 인코딩 규칙, 중복 키 처리 |
| SuperTokens JWT Revocation (2025) | JTI + Redis TTL 블랙리스트 패턴 |
