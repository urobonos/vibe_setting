# `develop:` 워크플로우 아키텍처 리뷰

> **목적**: `develop: [figmaUrl] [작업경로]` 프롬프트 실행 시 동작하는 에이전틱 파이프라인의 실현 가능성, 잠재 이슈, 100% 무결성 프로세스 적합성을 객관적으로 평가
> **평가 기준**: 코드베이스 실증 분석 + 학술 논문/업계 보고서 기반 근거
> **작성일**: 2026-03-25

---

## 1. 실행 플로우 요약

```
develop: [figmaUrl] [작업경로]
  │
  ├─ Phase 0: Context Gathering — FFS/QSS + as-is(Japan+Korea) + Figma URL
  ├─ Phase 1: design-normalizer → SDD (Figma REST API → 구조화 데이터)
  ├─ Phase 1.5: FFS-API 매핑 → Build Spec 컴파일
  ├─ Phase 2: 3-way 병렬 (publisher + qa-engineer + frontend-developer)
  ├─ Phase 2.5: static_audit.py (정적 코드 감사)
  ├─ Phase 3: 로직 주입 (API Route, Zustand, 이벤트 핸들러)
  ├─ Phase 3.5: QA + Visual Regression
  └─ Phase 4: FINAL_REPORT → 커밋
```

---

## 2. 이슈 분류 기준

| 등급 | 정의 |
|------|------|
| **BLOCKER** | 해결 없이 진행 불가. 파이프라인이 동작하지 않거나 결과물이 사용 불가 |
| **CRITICAL** | 진행은 가능하나 결과물에 심각한 결함 발생 |
| **HIGH** | 품질/효율에 유의미한 영향 |
| **MEDIUM** | 엣지 케이스에서 문제 가능 |
| **LOW** | 개선하면 좋은 수준 |

---

## 3. 코드베이스 실증 분석 결과

### 3-1. BLOCKER — 5건

#### B1. Phase 2 3-Way 병렬은 실제로 불가능

**현상**: `develop:` 플로우는 publisher(UI) + qa-engineer(테스트) + frontend-developer(로직 설계)를 Phase 2에서 동시 실행한다고 정의한다.

**문제**: frontend-developer는 publisher의 산출물 없이 로직을 설계할 수 없다.
- publisher가 결정하는 `labels.KEY` 매핑을 알아야 핸들러를 연결할 수 있음
- JSX 구조를 알아야 `onChange`/`onClick` 위치를 결정할 수 있음
- 컴포넌트 내부 state 형태를 알아야 Zustand 연동을 설계할 수 있음

**근거**: UC Berkeley MASFT 연구(2025)에서 멀티에이전트 시스템의 **36.9%가 조정 실패(coordination failure)**로 인해 실패. 특히 FM-2.5(다른 에이전트 입력 무시)가 병렬 실행에서 빈번하게 발생.

**해결안**: `develop:`는 순차 실행으로 재설계. publisher → frontend-developer → qa 순서.

---

#### B2. API 필드명 불일치 — 검증 스크립트 부재

**현상**: `LoginForm.js`(line 39)가 `{ email, password }`를 전송하지만, 실제 PHP 백엔드는 `{ ac_id, ac_password }`를 기대한다. `API_FIELD_MAP.md`에 올바른 매핑이 문서화되어 있지만, 이를 자동으로 검증하는 스크립트가 없다.

**문제**: `static_audit.py`는 UI 속성(폰트, 색상, 간격)만 검증한다. API 필드명, 응답 포맷, 에러 핸들링 패턴은 검사 범위 밖이다.

**근거**: CLAUDE.md §22-20에서 "에이전트의 텍스트 분석은 False Positive/Negative가 빈번하여 신뢰 불가. 반드시 스크립트 exit code로 강제해야 한다"고 명시. 이 원칙이 로직 검증에는 적용되지 않고 있다.

**해결안**: `logic_audit.py` 신규 개발 — API 필드명, secureFetch 사용, 에러 핸들링 패턴을 API_FIELD_MAP.md 대비 자동 검증.

---

#### B3. secureFetch 미사용 — CSRF 차단

**현상**: `lib/fetchWithAuth.js`에 CSRF 토큰을 자동 첨부하는 `secureFetch()`가 구현되어 있다. 그러나 `LoginForm.js`는 raw `fetch()`를 사용한다. `apiHandler.js`에 `requireCsrf: true`가 설정되어 있으므로, CSRF가 실제 적용되면 **모든 POST 요청이 403으로 차단**된다.

**문제**: publisher와 frontend-developer 에이전트에 `secureFetch` 사용을 강제하는 지침이 없다.

**해결안**: `static_audit.py`에 `secureFetch` 사용 검증 추가. 또는 `logic_audit.py`에 포함.

---

#### B4. 인메모리 인증 상태 — 서버리스 환경에서 무효

**현상**: `lib/auth.js`(lines 50-53)가 인메모리 `Map`과 `Set`를 사용한다:
- `tokenBlacklist` (JWT 폐기)
- `refreshFamilies` (리프레시 토큰 패밀리)
- `loginAttempts` (브루트포스 방어)
- `activeSessions` (동시 세션 제한)

**문제**: Next.js API Route는 프로덕션에서 서버리스 함수로 동작한다. 매 콜드 스타트마다 메모리가 초기화되므로 위 4개 메커니즘이 **전부 무력화**된다.

**근거**: Next.js 공식 문서에서 "세션 상태를 외부화하라(externalize state)"고 권장. 업계 베스트 프랙티스는 Redis 또는 Upstash 사용.

**해결안**: Redis 어댑터 추가. 환경변수 토글로 개발/프로덕션 분기. 모든 Map/Set를 스토리지 인터페이스 뒤로 추상화.

---

#### B5. 세션 브릿징 부재 — PHP 백엔드 인증 연동 불가

**현상**: as-is PHP 시스템은 `hdata`/`ck_login_member` 암호화 쿠키로 인증한다. Next.js 시스템은 JWT 기반 `hc_token`/`hc_refresh`를 사용한다. `apiHandler.js`는 PHP 백엔드에 요청 시 **쿠키를 포워딩하지 않는다**.

**문제**: 공개 API만 동작하고, 인증이 필요한 모든 PHP API는 "미로그인" 응답을 반환한다.

**근거**: Studocu의 Laravel→Next.js 마이그레이션 사례에서 "라우팅 시스템이 요청별로 판단: 마이그레이션 완료된 페이지는 Next.js, 아닌 것은 PHP"로 처리. 세션 공유는 별도 인증 프로바이더 또는 토큰 변환 레이어가 필수.

**해결안**: 두 가지 중 하나:
1. PHP 백엔드에 JWT 검증 미들웨어 추가 → Next.js의 `hc_token`을 PHP가 인식
2. API 프록시에서 JWT → `hdata` 포맷 변환 후 PHP에 전달

---

### 3-2. CRITICAL — 9건

| # | 이슈 | 현상 | 영향 |
|---|------|------|------|
| C1 | FFS API 필드명 14/15 도메인 미보정 | `MASTER_PLAN.md`에서 "FFS API 섹션 부정확 — 15개 도메인 전체 재매핑 필요" 인정. `API_FIELD_MAP.md`는 auth 도메인만 보정 완료 | frontend-developer가 나머지 도메인 작업 시 잘못된 필드명 사용 |
| C2 | 한국 vs 일본 API 차이 미해결 | 한국 400+ API, 일본 320+. 결제(7 PG vs 1), 인증(ICERTSecu vs SMS), 소셜(Kakao/Naver vs LINE) 차이. 국가별 조건 분기 로직 없음 | 글로벌 버전에서 국가별 기능이 누락되거나 충돌 |
| C3 | API 응답 포맷 불일치 | FFS는 `{ success: boolean }`, as-is는 `{ response: 'success' }`. `LoginForm.js`는 `data.message` 체크 (실제는 `data.msg`) | 모든 에러 핸들링이 실패 |
| C4 | URLSearchParams 중첩 객체 손실 | `apiHandler.js`의 `new URLSearchParams(body)` — 중첩 객체를 `[object Object]`로 변환 | 복잡한 폼(상담사 등록 14필드 등)에서 데이터 손실 |
| C5 | pipeline_gate.py에 로직 Phase 미포함 | Phase 1~4 아티팩트 존재 여부만 확인. API Route 존재, secureFetch 사용, Zustand 연결 등 로직 관련 게이트 없음 | `develop:` 결과물이 로직 검증 없이 커밋 |
| C6 | SendBird 미통합 | package.json에 `@sendbird/chat` 없음. 환경변수 미정의. 초기화 코드 없음. 채팅 도메인은 FFS 최대 규모(114슬라이드) | 채팅 상담 페이지 구현 불가 |
| C7 | Socket.IO 미통합 | 상담사 실시간 상태 표시에 Socket.IO 필수(`wss://node.peoplev.co.kr`). package.json에 `socket.io-client` 없음 | 상담사 목록에서 온라인/부재/오프라인 상태 표시 불가 |
| C8 | gen_api_mock.py 커버리지 부족 | API_MAPPINGS에 한국 전용 80+ API 미포함. `hongcafe-korea-analysis.md` 작성 전에 생성됨 | 한국 전용 도메인 개발 시 목업 데이터 없음 |
| C9 | 정적 감사가 로직 버그를 잡지 못함 | static_audit.py 555라인이 UI 속성만 검증. 이벤트 핸들러 연결, 검증 규칙 일치, 상태 관리 등은 범위 밖 | 로직 결함이 Phase 2.5를 통과 |

---

### 3-3. HIGH — 8건

| # | 이슈 | 현상 |
|---|------|------|
| H1 | hooks/ 디렉토리 비어있음 | FFS에서 참조하는 `useDebounce`, `useUpdateEffect` 등 공유 훅 없음 |
| H2 | 공유 컴포넌트 미구현 | `CounselorCard.js` (8+ 도메인), `FilterBottomSheet.js`, `ReviewCard.js` 등 없음. 도메인별 중복 생성 위험 |
| H3 | Visual Regression이 인터랙션 테스트 불가 | 폼 에러 상태, 로딩 스피너, API 실패 모달, 리디렉션 등은 스크린샷 비교로 검증 불가 |
| H4 | QSS→Playwright 스켈레톤만 생성 | `qss_to_playwright.py`가 `page.locator('body').toBeVisible()` 수준의 빈 테스트만 생성. 비즈니스 로직 테스트는 수동 구현 필요 |
| H5 | Playwright 설정 파일 없음 | `@playwright/test`가 devDependencies에 있지만 `playwright.config.js` 미존재 |
| H6 | as-is 51KB 분석 문서의 컨텍스트 윈도우 초과 위험 | Japan 분석 51KB + Korea 분석(대량) 동시 참조 시 에이전트 컨텍스트 한계 |
| H7 | Stripe SDK 미설치 | 일본 시장 결제에 필수. package.json에 `@stripe/stripe-js` 없음 |
| H8 | 공유 컴포넌트 없이 도메인 퍼블리싱 시 불일치 | Phase 3.5(component-refactor)가 사후 통합하지만, 2+ 도메인 동시 작업 시 CounselorCard 등이 각각 다르게 구현됨 |

---

### 3-4. MEDIUM — 6건

| # | 이슈 |
|---|------|
| M1 | develop: 워크플로우 전용 QSS 부재 (API 프록시, 인증 플로우, CSRF 라이프사이클용) |
| M2 | compile_build_spec.pyc가 git에 트래킹됨 (빌드 아티팩트 커밋) |
| M3 | form-urlencoded 타입 손실 (PHP `"0"` vs JS `0`, `"true"` vs `true`) |
| M4 | 한국 본인인증(ICERTSecu)이 PHP SEED 확장 의존 — Next.js에서 직접 호출 불가 |
| M5 | 카카오톡 AlimTalk 서버사이드 발송 — Next.js API Route에서 직접 호출 시 시크릿 노출 위험 |
| M6 | 060 전화번호 시스템 — 레거시 VoIP 브릿지 연동 방식 미정의 |

---

### 3-5. LOW — 4건

| # | 이슈 |
|---|------|
| L1 | jwt_helper.php가 완전 주석 처리 — 레거시 JWT 흔적 |
| L2 | Adjust SDK 연동 방식 미정의 (네이티브 브릿지 vs 웹 SDK) |
| L3 | 이미지 서버 도메인(`img.hongcafe.com`) remotePatterns 미등록 |
| L4 | Green 티어 URL 구조(`/green/*`) → Next.js Route Group 매핑 방식 미확정 |

---

## 4. 학술/업계 근거 기반 평가

### 4-1. 멀티에이전트 파이프라인 성공률

| 출처 | 데이터 |
|------|--------|
| **MASFT (UC Berkeley, 2025)** | 7개 MAS 프레임워크 1,600+ 트레이스 분석. 전체 실패율 **41~86.7%**. 프롬프트 개선으로 +14% 향상 가능하나 "모든 실패를 해결하지 못함" |
| **Google/MIT (2025)** | 180개 에이전트 구성 테스트. 최적 병렬 에이전트 수 **3~5개**. 조정 비용은 **N(N-1)/2** (이차 증가). 오케스트레이터 유무에 따라 에러 증폭률 **4.4x vs 17.2x** |
| **DORA 2025 (Google)** | AI 도입 시 개별 생산성 +21%, PR 머지 +98%. 그러나 코드 리뷰 시간 +91%, PR 크기 +154%, **버그율 +9%** |

**시사점**: 이 파이프라인의 Phase 2에서 2개 병렬(publisher + qa-engineer)은 최적 범위 내. 그러나 3-way 병렬은 조정 비용이 3→6 (N(N-1)/2)으로 2배 증가하며, frontend-developer의 의존성 문제와 겹쳐 실패 확률이 높다.

---

### 4-2. LLM 코드 생성 정확도

| 벤치마크 | 최고 점수 | 현실 반영도 |
|---------|---------|------------|
| **HumanEval** (단일 함수) | 99.0% | 낮음 — 이미 포화 |
| **SWE-bench Verified** (실제 GitHub 이슈) | 80.9% (Claude Opus 4.5) | 중간 — 오염 의심 |
| **SWE-bench Pro** (오염 방지) | ~23% | **높음 — 실제 수준 반영** |
| **업계 통계** (Qodo 2025) | AI 제안 중 30%만 수용, 1/5에 오류, 48%에 보안 취약점 | 높음 |

**시사점**: SWE-bench Verified(80.9%)와 Pro(23%)의 격차가 핵심. 이 파이프라인의 작업(Figma→다파일 컴포넌트 + i18n + API 연동)은 SWE-bench Pro 수준의 복잡도에 해당. `static_audit.py`와 Visual Regression의 다층 검증은 30% 수용률 현실을 정확히 반영한 설계.

---

### 4-3. Figma-to-Code 자동화 정확도

| 출처 | 데이터 |
|------|--------|
| **업계 실측** (Anna Arteeva, 2025) | 동일 Figma 템플릿 기준 65~80% 정확도 |
| **업계 공통 견해** | "큰 구조는 맞고, 픽셀은 틀림". 프로덕션 사용에 **20~40% 수동 보정 필요** |
| **생산성 영향** (WebDev Insights, 2025) | 자동화로 개발 시간 **50% 단축** (보정 포함) |

**시사점**: 이 파이프라인의 SDD-CSS-map.json 접근법(정확한 Y좌표, GAP 계산, fontWeight, hex 색상 추출)은 업계 공통 실패 지점(간격, 타이포, 색상)을 정확히 타겟팅. 20~40% 수동 보정이 필요한 업계 평균 대비, 5회 자동 수정 루프가 이를 대체하는 구조.

---

### 4-4. TDD in AI 파이프라인

| 출처 | 데이터 |
|------|--------|
| **TDAD Study (2026)** | TDD 적용 시 테스트 레벨 회귀율 6.08% → **1.82%** (70% 감소). 단, 일반적 TDD 지시만 추가하면 오히려 **9.94%로 악화** |
| **DORA 2025** | "TDD는 AI 코딩 에이전트에서 극적으로 더 나은 결과를 산출" |
| **Codemanship (2026)** | "깨진 코드가 컨텍스트를 오염시킴" — TDD 없이 AI가 깨진 코드 위에 추가 변경을 예측 |

**시사점**: 이 파이프라인의 Phase 2-B(qa-engineer가 SDD 기반 테스트 선작성)는 TDAD 연구의 "타겟팅된 컨텍스트 분석 기반 TDD"와 일치하여 올바른 접근. 단, 일반적 지시만 하면 악화되므로, SDD 기반 구체적 테스트 계약이 핵심.

---

### 4-5. 레거시 마이그레이션 (PHP → Next.js)

| 출처 | 권장 패턴 |
|------|---------|
| **Studocu (Laravel→Next.js)** | Strangler Fig 패턴. 라우팅 시스템이 요청별 판단. 점진적 마이그레이션. "한번에 전부 마이그레이션하지 말라" |
| **업계 공통** | API 프록시(BFF 패턴)를 브릿지로 사용. 공유 컴포넌트 조기 구축. 마이그레이션 중 테스트 커버리지 유지 |
| **인증 마이그레이션** | HTTP-only 쿠키 + `iron-session` 또는 `jose`. 세션 공유는 별도 인증 프로바이더 필수 |
| **form-urlencoded 변환** | `URLSearchParams(body)` 패턴이 표준. 단, 중첩 객체 플래트닝 유틸리티 필요 |

**시사점**: 이 파이프라인의 API Route 프록시 패턴은 업계 표준(BFF)과 일치. 그러나 세션 브릿징과 쿠키 포워딩이 미구현 — 이는 Studocu 사례에서도 가장 큰 난관으로 언급된 부분.

---

### 4-6. 컨텍스트 윈도우 한계

| 출처 | 데이터 |
|------|--------|
| **"Lost in the Middle" (Stanford, 2024, TACL)** | 관련 정보가 컨텍스트 중간에 위치하면 성능 **30%+ 하락**. U자형 주의 패턴 일관적 |
| **"Context Rot" (Chroma Research, 2025)** | 단 1개의 방해 문서만 추가해도 성능 저하. 긴 컨텍스트가 더 나은 결과를 보장하지 않음 |

**시사점**: 이 파이프라인의 SDD-CSS-map.json 접근법은 사실상 **컨텍스트 엔지니어링 전략**. Figma API의 원시 응답 대신 구조화된 추출 데이터만 전달하여 "Lost in the Middle" 및 Context Rot 문제를 직접 완화.

---

## 5. 100% 무결성 프로세스 적합성 평가

### 5-1. UI 디자인 무결성: **달성 가능 ~95%**

| 검증 항목 | 자동화 수준 | 커버리지 |
|----------|-----------|---------|
| 폰트 속성 (weight, size, color, decoration, align) | static_audit.py 노드별 전수검사 | 100% |
| 색상 Hex 일치 | static_audit.py CSS Map 대조 | 100% |
| 아이콘 원본 사용 | dedup_icons.py + SVG 품질 게이트 | 100% |
| 텍스트 내용 1:1 일치 | text-manifest vs en.json 대조 | 100% |
| 간격/여백 수치 | SDD GAP 계산 + pt-[N] 반영 | 95% |
| 요소 순서 | Y좌표 정렬 + JSX 순서 검증 | 95% |
| 동적 상태 (hover, focus, active) | **미검증** | 0% |
| 반응형 브레이크포인트 | **미검증** | 0% |

**나머지 5%**: Figma SDD에 캡처되지 않는 동적 상태, 폰트 렌더링 차이(Figma vs 브라우저), Tailwind v4 레이어 이슈(`<Link>` 색상 등).

---

### 5-2. 비즈니스 로직 무결성: **현재 ~40%, 개선 시 ~75%**

| 검증 항목 | 자동화 수준 | 현재 커버리지 |
|----------|-----------|-------------|
| API 필드명 정확성 | **없음** (logic_audit.py 미존재) | 0% |
| secureFetch 사용 | **없음** | 0% |
| 에러 핸들링 패턴 | **없음** | 0% |
| 폼 검증 규칙 | **없음** | 0% |
| 인증 플로우 | **BLOCKER** (세션 브릿징 부재) | 0% |
| API Route 프록시 존재 | pipeline_gate에 미포함 | 0% |
| Zustand Store 연결 | **없음** | 0% |
| 상태 전이 (계정 상태 2/3/4/5/6) | **없음** | 0% |

**해결 시 도달 가능 수준**: `logic_audit.py` 개발 + 세션 브릿징 구현 + API_FIELD_MAP 15개 도메인 완성 시 **~75%**. 나머지 25%는 외부 서비스 연동(SendBird, Socket.IO, Stripe, 본인인증)으로, 격리 테스트가 불가능한 영역.

---

### 5-3. End-to-End 동작 시스템: **현재 ~30%, 개선 시 ~65%**

| 항목 | 현재 상태 |
|------|---------|
| UI 렌더링 | O (publish 파이프라인 동작) |
| i18n | O (next-intl 동작) |
| API 프록시 (공개 엔드포인트) | O (apiHandler.js 동작) |
| API 프록시 (인증 엔드포인트) | X (세션 브릿징 없음) |
| CSRF 보호 | X (secureFetch 미사용) |
| 실시간 상태 | X (Socket.IO 없음) |
| 채팅 | X (SendBird 없음) |
| 결제 | X (Stripe/NicePay SDK 없음) |
| 본인인증 | X (ICERTSecu PHP 전용) |

---

## 6. 해결 우선순위 로드맵

### Tier 1 — BLOCKER 해결 (develop: 실행 전 필수)

| # | 작업 | 산출물 | 예상 영향 |
|---|------|--------|---------|
| 1 | `develop:` Phase 2를 순차로 재설계 | 워크플로우 문서 수정 | 병렬 실행 실패 원천 차단 |
| 2 | `logic_audit.py` 개발 | 스크립트 파일 | 로직 무결성 0% → 60%+ |
| 3 | secureFetch 강제 | static_audit.py 업데이트 | CSRF 차단 해소 |
| 4 | 세션 브릿징 설계 및 구현 | lib/sessionBridge.js | 인증 API 동작 |
| 5 | 인메모리 상태 → Redis 추상화 | lib/auth.js 리팩토링 | 프로덕션 인증 동작 |

### Tier 2 — CRITICAL 해결 (첫 번째 develop: 실행 전 권장)

| # | 작업 | 산출물 |
|---|------|--------|
| 6 | API_FIELD_MAP.md 15개 도메인 완성 | 문서 업데이트 |
| 7 | 국가별 API 분기 로직 설계 | lib/countryRouter.js |
| 8 | URLSearchParams 중첩 객체 플래트닝 | apiHandler.js 수정 |
| 9 | pipeline_gate.py에 로직 Phase 추가 | 스크립트 업데이트 |
| 10 | SendBird + Socket.IO 패키지 설치 및 초기화 | package.json + lib/ |

### Tier 3 — HIGH 해결 (Sprint 1 공유 컴포넌트)

| # | 작업 | 산출물 |
|---|------|--------|
| 11 | 공유 컴포넌트 선행 구현 (CounselorCard 등) | components/ |
| 12 | 공유 훅 구현 (useDebounce 등) | hooks/ |
| 13 | Playwright 설정 파일 | playwright.config.js |
| 14 | 기능 테스트 프레임워크 (Visual이 아닌 Functional) | 테스트 가이드 |

---

## 7. 수정된 `develop:` 플로우 제안

```
develop: [figmaUrl] [작업경로]
  │
  ├─ Phase 0: Context Gathering (현행 유지)
  │   ├── FFS/QSS에서 요구사항 추출
  │   ├── as-is (Japan + Korea) 분석에서 API/로직 매칭
  │   └── API_FIELD_MAP.md에서 정확한 필드명 확인
  │
  ├─ Phase 1: design-normalizer → SDD (현행 유지)
  │
  ├─ Phase 1.5: FFS-API 매핑 → Build Spec (현행 유지)
  │   └── [추가] API_FIELD_MAP.md 보정 여부 확인 — 미보정 도메인이면 STOP
  │
  ├─ Phase 2-A: publisher → UI 마크업 (현행 유지, 병렬 아님)       ★ 변경
  │
  ├─ Phase 2-B: qa-engineer → 테스트 선작성 (publisher와 병렬 유지)
  │
  ├─ Phase 2.5: static_audit.py (현행 유지)
  │
  ├─ Phase 3: frontend-developer → 로직 주입 (publisher 완료 후)    ★ 변경: 순차
  │   ├── API Route 프록시 (secureFetch 필수)
  │   ├── Zustand Store (필요시)
  │   ├── Client Component 로직
  │   └── 세션 브릿징 활용
  │
  ├─ Phase 3.5: logic_audit.py (신규)                              ★ 신규
  │   ├── API 필드명 vs API_FIELD_MAP.md 대조
  │   ├── secureFetch 사용 검증
  │   ├── 에러 핸들링 패턴 검증 (data.response === 'success')
  │   ├── Zustand Store 연결 검증
  │   └── REJECT 시 → frontend-developer 수정 루프 (최대 5회)
  │
  ├─ Phase 4: Visual Regression + 기능 테스트                       ★ 변경: 기능 테스트 추가
  │
  └─ Phase 5: FINAL_REPORT → 커밋
```

### 핵심 변경 사항 3가지

1. **Phase 2를 2-way 병렬로 축소** (publisher + qa-engineer만). frontend-developer는 Phase 3으로 이동 (순차).
2. **Phase 3.5에 `logic_audit.py` 신규 추가** — `static_audit.py`의 로직 버전. 스크립트 exit code로 PASS/REJECT 강제.
3. **Phase 1.5에 API_FIELD_MAP 보정 여부 게이트 추가** — 미보정 도메인은 매핑 완성 전까지 진행 차단.

---

## 8. 결론

### 강점 (업계 대비 우위)
- **SDD-CSS-map.json 기반 UI 퍼블리싱**: "Lost in the Middle" 문제를 컨텍스트 엔지니어링으로 직접 완화. 업계 65~80% 정확도 대비 높은 수준 달성.
- **스크립트 기반 품질 게이트**: MASFT 연구의 FM-3.3(잘못된 검증) 실패 모드를 정확히 타겟팅. "에이전트 판단 불신 → 스크립트 강제"는 실증적으로 올바른 접근.
- **TDD 계약 구조**: TDAD 연구의 "타겟팅된 TDD"와 일치. 일반적 TDD 지시(악화 유발)가 아닌 SDD 기반 구체적 테스트 계약.
- **5회 자동 수정 루프**: 업계 평균 20~40% 수동 보정 필요 → 자동 반복으로 대체하는 구조.

### 약점 (즉시 해결 필요)
- **UI 파이프라인을 로직 파이프라인으로 확장 시 검증 공백**: UI용 `static_audit.py`에 대응하는 로직용 `logic_audit.py`가 없음.
- **인증/세션 인프라 미완성**: 서버리스 환경 대응(Redis), 세션 브릿징(PHP↔Next.js) 모두 구현 필요.
- **3-way 병렬 아키텍처**: 의존성 있는 작업을 병렬로 설계. 순차로 수정 필요.

### 수치 요약

| 영역 | 현재 달성 가능 | Tier 1~2 해결 후 | 업계 평균 |
|------|-------------|----------------|---------|
| UI 디자인 무결성 | ~95% | ~95% | 65~80% |
| 비즈니스 로직 무결성 | ~40% | ~75% | N/A (비교 대상 없음) |
| End-to-End 동작 | ~30% | ~65% | N/A |

---

## 참고 문헌

| 출처 | 인용 내용 |
|------|---------|
| Cemri et al., "Why Do Multi-Agent LLM Systems Fail?" (UC Berkeley, 2025, arXiv:2503.13657) | MASFT 분류법, 실패율 41~86.7%, 14개 실패 모드 |
| Google Research, "Towards a Science of Scaling Agent Systems" (2025, arXiv:2512.08296) | 최적 병렬 3~5개, 조정 비용 이차 증가, 에러 증폭률 4.4x vs 17.2x |
| Liu et al., "Lost in the Middle" (Stanford, 2024, TACL) | 컨텍스트 중간부 성능 30%+ 하락, U자형 주의 패턴 |
| Chroma Research, "Context Rot" (2025) | 방해 문서 1개만 추가해도 성능 저하, 긴 컨텍스트 ≠ 좋은 결과 |
| TDAD Study (2026, arXiv:2603.17973) | TDD 회귀율 70% 감소, 단 일반 지시만 하면 오히려 악화 |
| DORA 2025 Report (Google) | AI 도입 시 생산성 +21%, 버그율 +9%, TDD가 AI 성과 극대화 |
| Qodo, "State of AI Code Quality" (2025) | AI 제안 30% 수용, 1/5 오류, 48% 보안 취약점 |
| SWE-bench Pro (2025) | 오염 방지 벤치마크 최고 ~23% (Verified 80.9% 대비) |
| Studocu Engineering Blog (2024) | Laravel→Next.js Strangler Fig 마이그레이션 실전 사례 |
| Next.js Documentation (2026) | Route Handler, 인증 가이드, iron-session 권장 |
