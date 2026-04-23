# 홍카페 글로벌 통합 프로젝트 — 마스터 플랜

> 작성일: 2026-03-24
> 목적: as-is 코드베이스 + 기획서 FFS/QSS + V4.5 퍼블리싱 파이프라인을 통합한 전체 구현 계획
> 원칙: 100% 무결성 — 추정 금지, 검증된 사실만 기반

---

## 0. 현재 상태 진단

### 보유 자산

| 자산 | 위치 | 역할 |
|------|------|------|
| as-is 코드 분석 | `docs/specs/hongcafe-japan-analysis.md` | 실제 API 200+개, 비즈니스 로직, 외부 SDK 정보 |
| 기획서 FFS/QSS | `docs/specs/{domain}/` × 15개 도메인 | 화면 단위 기능 정의 + QA 시나리오 1,880개 |
| V4.5 파이프라인 | CLAUDE.md §21~23 | Figma → 픽셀 퍼펙트 UI 코드 자동 생성 |
| 퍼블리싱 완료 | 7페이지 (intro~join/email/complete) | UI only, API 미연동 |

### 문제점 (솔직한 진단)

| 문제 | 상세 |
|------|------|
| **FFS의 API 추정이 부정확** | FFS가 `/api/call/getList` 등으로 추정했으나 as-is 실제는 `/api/items/getListMobile`. 15개 도메인 FFS의 API 섹션 전체 재매핑 필요 |
| **검증 로직 가정 오류** | FFS가 클라이언트 검증을 상세히 기술했으나, as-is는 서버가 검증하고 `data.msg`를 반환하는 패턴. 클라이언트는 msg를 표시만 함 |
| **V4.5 파이프라인은 UI만 커버** | Figma → 코드 생성은 완벽하나, API 연동·상태관리·비즈니스 로직은 별도 작업 |
| **기획서와 as-is 간 갭** | 기획서는 "통합버전 신규 개발"이나, 실제로는 as-is 백엔드 API를 그대로 사용. 신규 API는 극소수 |

---

## 1. 통합 워크플로우

### 도메인 1개를 처리하는 전체 흐름

```
┌─────────────────────────────────────────────────────┐
│ Phase 0: 사전 준비 (1회성, Sprint 1에서 수행)          │
│                                                      │
│ ① 공유 컴포넌트 Figma 수령 → V4.5 파이프라인           │
│ ② Zustand 스토어 정의 (useAuthStore 등)               │
│ ③ API 프록시 레이어 뼈대 구축                          │
│ ④ lib/nativeBridge.js + hooks/useDeviceRole.js       │
│ ⑤ lib/validators.js (as-is 검증 규칙 이식)            │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ Phase 1: UI 퍼블리싱 (V4.5 파이프라인 — 기존 그대로)    │
│                                                      │
│ Figma URL 수신                                       │
│   → design-normalizer (SDD 추출)                     │
│   → publisher (SDD 기반 마크업 생성)                    │
│   → qa-engineer Phase 2-B (Playwright 테스트 선작성)   │
│   → static_audit.py (Phase 2.5 검증)                 │
│   → Visual Regression (Phase 3)                      │
│                                                      │
│ 산출물: 픽셀 퍼펙트 UI 컴포넌트 (API 미연동)             │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ Phase 2: 로직 연동 (NEW — frontend-developer 역할)    │
│                                                      │
│ 입력:                                                │
│   ① Phase 1 산출물 (퍼블리싱된 UI 컴포넌트)              │
│   ② FFS (기능 정의서 — 화면 플로우, 비즈니스 규칙)        │
│   ③ as-is API 매핑 (실제 엔드포인트 + 요청/응답 형식)    │
│                                                      │
│ 작업:                                                │
│   ⓐ API 프록시 route.js 작성 (as-is 엔드포인트 연결)    │
│   ⓑ Server Component에서 초기 데이터 fetch             │
│   ⓒ Client Component에 상태 관리 + 이벤트 핸들러 주입    │
│   ⓓ 검증: as-is 서버 msg 표시 패턴 적용                │
│   ⓔ 외부 SDK 연동 (SendBird, Stripe 등)              │
│                                                      │
│ 산출물: 완전 동작하는 페이지 (UI + API + 로직)           │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│ Phase 3: 기능 QA (QSS 기반 — qa-engineer 역할)        │
│                                                      │
│ 입력: QSS 시나리오 시트 + 동작하는 페이지                │
│                                                      │
│ 작업:                                                │
│   ⓐ QSS → Playwright .spec.js 변환                  │
│   ⓑ API mock 서버 구성 (as-is 응답 형식 기반)          │
│   ⓒ E2E 테스트 실행                                  │
│   ⓓ 결함 발견 → Phase 2 재진입 (최대 5회)              │
│                                                      │
│ 산출물: 전체 테스트 PASS + FINAL_REPORT               │
└─────────────────────────────────────────────────────┘
```

### 핵심 차이: 기존 V4.5 vs 통합 워크플로우

| 항목 | V4.5 (기존) | 통합 워크플로우 |
|------|------------|---------------|
| 범위 | UI 퍼블리싱만 | UI + API 연동 + 비즈니스 로직 + QA |
| 입력 | Figma 디자인만 | Figma + FFS + as-is API |
| 산출물 | 정적 UI 컴포넌트 | 완전 동작하는 페이지 |
| 검증 | Visual Regression | Visual + 기능 E2E + API 통합 |
| 에이전트 | design-normalizer → publisher → qa-engineer | + **frontend-developer** 추가 |

---

## 2. as-is → to-be API 매핑 (확정판)

FFS가 추정한 API를 as-is 실제 엔드포인트로 교정:

### 인증/회원

| FFS 추정 | as-is 실제 | Next.js 프록시 |
|---------|-----------|---------------|
| `/api/auth/login` | `/api/member/loginuser` | `app/api/auth/login/route.js` |
| `/api/auth/checkAccount` | `/api/member/checkid` + `/api/member/CheckAccount` | `app/api/auth/check-account/route.js` |
| `/api/auth/register` | `/api/member/joinuser` | `app/api/auth/register/route.js` |
| `/api/auth/sendSms` | `/api/member/sendglobalcert` | `app/api/auth/send-sms/route.js` |
| `/api/auth/verifySms` | `/api/member/confirmglobalcert` | `app/api/auth/verify-sms/route.js` |
| `/api/auth/findId` | `/api/member/findidcert` → `confirmidcert` | `app/api/auth/find-id/route.js` |
| `/api/auth/resetPassword` | `/api/member/findpasswordcert` | `app/api/auth/reset-password/route.js` |

### 상품/상담사

| FFS 추정 | as-is 실제 | Next.js 프록시 | 비고 |
|---------|-----------|---------------|------|
| `/api/call/getList` | `/api/items/getListMobile` | `app/api/items/get-list-mobile/route.js` | phone/chat 공통 |
| `/api/call/getProfile` | `/api/items/getItem` | `app/api/items/get-item/route.js` | |
| `/api/call/getReviews` | `/api/items/getcomment` | `app/api/items/get-comment/route.js` | |
| `/api/search/counselor` | `/api/items/getSearchListItems` | `app/api/items/search/route.js` | |

### 채팅

| FFS 추정 | as-is 실제 | 비고 |
|---------|-----------|------|
| WebSocket 직접 구현 | **SendBird SDK** | SDK가 WebSocket 관리 |
| `/api/chat/startSession` | `/api/chat/chatConnect` → `chatStart` | 2단계 |
| `/api/chat/sendMessage` | SendBird `channel.sendUserMessage()` | SDK 메서드 |
| `/api/chat/endSession` | `/api/chat/chatClosed` | |
| 과금 타이머 | `/api/chat/chatTimer` (Hermes 서버) | 백그라운드 매분 폴링 |

### 결제

| FFS 추정 | as-is 실제 | 비고 |
|---------|-----------|------|
| PG 미정 | **Stripe** (글로벌) | SetupIntent + PaymentIntent |
| `/api/coin/createPayment` | `/api/stripe/createPaymentIntent` | |
| 카드 등록 | `/api/stripe/createSetupIntent` → `confirmCardSetup` | |
| 자동충전 | `/api/mypage/AutopayRuleSave` + `AutopayCardSave` + `AutopayUsechange` | |

### 마이페이지

| FFS 추정 | as-is 실제 |
|---------|-----------|
| `/api/member/getInfo` | `/api/mypage/getMyInfo` (추정 — 직접 확인 필요) |
| `/api/member/updateNickname` | `/api/member/changenick` |
| `/api/member/updatePhone` | `/api/member/verifyphone` → `updatephone` |
| `/api/member/withdraw` | `/api/member/deleteuser` |
| `/api/coin/getHistory` | `/api/mypage/getCoinList` |
| `/api/reviews/write` | `/api/mypage/insertMyComment` |
| `/api/coupon/register` | `/api/mypage/Registcoupon` |

**응답 형식 통일** (as-is 표준):
```json
{ "response": "success|error", "msg": "", "data": {}, "is_login": "true|false" }
```

---

## 3. 검증 패턴 교정

### as-is: 서버 검증 중심

```
사용자 입력 → 클라이언트 최소 검증 (빈값, 형식) → API 호출 → 서버 검증 → data.msg 표시
```

### to-be: 동일 패턴 유지 (as-is 호환)

```js
// ✅ 올바른 패턴 (as-is 호환)
const handleSubmit = async () => {
    // 클라이언트 최소 검증 (UX용, 서버 호출 방지)
    if (!email) return setError('이메일을 입력해 주세요.');

    const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ac_id: email, ac_password: password })
    });
    const data = await res.json();

    if (data.response === 'success') {
        router.push(`/${locale}`);
    } else {
        setModalMessage(data.msg); // 서버가 반환한 에러 메시지 그대로 표시
    }
};

// ❌ FFS가 가정한 잘못된 패턴
// 클라이언트에서 모든 검증을 수행하고 서버는 저장만
```

### lib/validators.js (as-is 규칙 이식 — 클라이언트 최소 검증용)

```js
// as-is에서 확인된 실제 규칙
export const validators = {
    email: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v),
    password: (v) => v.length >= 6 && v.length <= 16,
    nickname: (v) => v.length >= 2 && v.length <= 12,
    phone: (v) => /^[0-9]+$/.test(v),
    pin: (v) => /^[0-9]{6}$/.test(v) && !/(.)\1\1/.test(v), // 연속 3개 불가
    cardNumber: (v) => /^[0-9]{16}$/.test(v),
    birthDate: (v) => /^[0-9]{8}$/.test(v),
};
```

---

## 4. 외부 SDK 통합 계획

| SDK | 용도 | 설치 | 초기화 위치 | as-is 참조 |
|-----|------|------|-----------|-----------|
| **SendBird** | 채팅 메시징 | `@sendbird/chat` | `hooks/useSendBird.js` | appId: `0481526C-...` |
| **Stripe.js** | 결제 | `@stripe/stripe-js` | `hooks/useStripe.js` | SetupIntent + PaymentIntent 패턴 |
| **Adjust** | 앱 이벤트 트래킹 | `adjust-sdk` | `lib/adjustTracker.js` | 이벤트 토큰 11개 |
| **FCM** | 푸시 알림 | `firebase/messaging` | `lib/firebase.js` | 듀얼 프로젝트 |
| **SMSLINK** | SMS 인증 | 서버 사이드만 | API 프록시 경유 | `/api/member/sendglobalcert` |
| **DOMPurify** | XSS 방어 | `dompurify` | 포스팅/FAQ 등 HTML 렌더링 시 | as-is: `escapeHtml()` |

---

## 5. 스프린트 계획 (교정판)

### Sprint 0: 인프라 (Figma 불필요, 즉시 시작 가능)

| # | 작업 | 산출물 | 의존성 |
|---|------|--------|--------|
| 0-1 | Zustand 스토어 4개 정의 | `store/useAuthStore.js`, `useCoinStore.js`, `useCateStore.js`(확장), `useDeviceStore.js` | 없음 |
| 0-2 | lib/validators.js | as-is 검증 규칙 이식 | 없음 |
| 0-3 | lib/nativeBridge.js | 앱/웹 판별 + 네이티브 통신 | 없음 |
| 0-4 | lib/adjustTracker.js | Adjust 이벤트 상수 + trackEvent | 없음 |
| 0-5 | API 프록시 뼈대 | `app/api/auth/*/route.js` (login, register, find-id 등) | 없음 |
| 0-6 | globals.css 테마 확장 | `--green-1: #00af79` | 없음 |
| 0-7 | 기존 7페이지 API 연동 | login → loginuser, join → joinuser 실제 연결 | 0-5 |

### Sprint 1: 레이아웃 + 공유 컴포넌트 (Figma 필요)

| # | 작업 | V4.5 파이프라인 | Phase 2 로직 |
|---|------|---------------|-------------|
| 1-1 | layout (GNB/Header/Footer) | ✅ Figma → SDD → publisher | Tab 전환 + 로그인 상태 분기 |
| 1-2 | CounselorCard | ✅ Figma → publisher | `/api/items/getListMobile` 연동 |
| 1-3 | FilterBottomSheet | ✅ Figma → publisher | 필터 상태 관리 (useFilterStore) |
| 1-4 | ReviewCard | ✅ Figma → publisher | `/api/items/getcomment` 연동 |

### Sprint 2: 핵심 매출 (Figma 필요)

| # | 작업 | V4.5 퍼블리싱 | Phase 2 로직 | as-is API |
|---|------|-------------|-------------|-----------|
| 2-1 | phone 메인 | ✅ | 상담사 목록 fetch + 무한스크롤 | `getListMobile` |
| 2-2 | phone 카테고리 | ✅ | 필터 조합 + 정렬 | `getListMobile` + 필터 파라미터 |
| 2-3 | phone 프로필 | ✅ | 5개 탭 데이터 + 상담하기 CTA | `getItem`, `getcomment`, `getItemQnaList` |
| 2-4 | chat 메인+카테고리 | ✅ (phone 재사용 80%) | 동일 API, 테마만 purple | `getListMobile` |
| 2-5 | find-account | ✅ | SMS 인증 플로우 | `findidcert`, `findpasswordcert` |
| 2-6 | coin-charging | ✅ | Stripe PaymentIntent | `createPaymentIntent` |

### Sprint 3: 채팅방 + 프로필 (Figma + SDK 필요)

| # | 작업 | 외부 SDK | as-is API |
|---|------|---------|-----------|
| 3-1 | chat 프로필 | — | phone 재사용 + chat 차이 |
| 3-2 | chat 연결 플로우 | — | `chatConnect` → `chatStart` |
| 3-3 | chat 채팅방 | **SendBird** | `chatTimer`, `sendMessage`, `fileUpload` |
| 3-4 | chat 종료/자리비움 | SendBird | `chatClosed`, `reConnect` |
| 3-5 | phone 전화 연결 | — | `callconnect` → `tel:` 프로토콜 |

### Sprint 4: 보조 기능 (Figma 필요)

| # | 작업 | as-is API |
|---|------|-----------|
| 4-1 | category + posting | `getPostingList`, `postingDetail`, `getPostingComments` |
| 4-2 | search | `getSearchListItems` |
| 4-3 | reviews | `getcomment` (전체), `insertMyComment` (작성) |
| 4-4 | favorites | `getLikeList`, `itemAddLike`, `itemDeleteLike` |
| 4-5 | counselor-registration | 신규 API 필요 (as-is에 미존재) |

### Sprint 5: 대시보드 (Figma 필요, 최대 규모)

| # | 작업 | as-is API |
|---|------|-----------|
| 5-1 | member-mymenu 회원정보 | `changenick`, `changepasswd`, `updatephone`, `settingalarm`, `deleteuser` |
| 5-2 | member-mymenu VIP/쿠폰 | `getRewardHistory`, `Registcoupon`, `getMyCouponList` |
| 5-3 | member-mymenu 상담/코인/결제 내역 | `getCounselList`, `getCoinList`, `getPayList` |
| 5-4 | member-mymenu 후기/문의 | `insertMyComment`, `getMyQuestion` |
| 5-5 | member-mymenu 자동충전 | `AutopayRuleSave`, `AutopayCardSave`, `AutopayUsechange` (Stripe) |
| 5-6 | counselor-mymenu | Callee 전용 API 30+개 |

---

## 6. 에이전트 역할 분담 (통합)

| 에이전트 | Phase | 역할 | 입력 | 산출물 |
|---------|-------|------|------|--------|
| **design-normalizer** | 1 | Figma SDD 추출 | Figma URL | SDD-CSS-map.json |
| **publisher** | 1 | SDD 기반 UI 마크업 | SDD | .js 컴포넌트 (UI only) |
| **qa-engineer** | 1, 3 | 테스트 선작성 + 실행 | SDD, QSS | Playwright .spec.js |
| **frontend-developer** | 2 | API 연동 + 로직 주입 | FFS + as-is API 매핑 + Phase 1 UI | 완전 동작 페이지 |
| **component-refactor** | 1.5 | 공유 컴포넌트 추출 | 복수 페이지 완료 후 | 공유 컴포넌트 |
| **project-orchestrator** | 전체 | 공정 관리 | 전체 | 커밋, 보고서 |

### Phase 2 (로직 연동) 상세 — frontend-developer 입력물

```
frontend-developer가 받는 3개 입력:

① Phase 1 산출물 (퍼블리싱된 컴포넌트)
   → app/[locale]/{domain}/_components/{Name}Screen.js
   → labels prop으로 텍스트 주입, API 미연동 상태

② FFS (기능 정의서)
   → 페이지별 인터랙션, 비즈니스 규칙, 상태 관리 설계
   → 주의: API 엔드포인트는 FFS가 아닌 as-is 매핑 사용

③ as-is API 매핑 (이 문서 §2)
   → 실제 엔드포인트 이름, 요청/응답 형식
   → 검증 패턴: 서버 msg 표시
```

---

## 7. FFS/QSS 활용 방법 (교정)

### FFS → 이렇게 사용

| FFS 섹션 | 활용처 | 주의 |
|---------|--------|------|
| UI 섹션 (상→하 순서) | Phase 1 publisher 참조 | Figma SDD가 우선, FFS는 보조 |
| 비즈니스 규칙 | Phase 2 frontend-developer | **검증 메시지는 as-is 서버 msg 우선** |
| 상태 관리 | Phase 2 스토어 설계 | FFS 설계를 기반으로 하되 as-is 패턴 반영 |
| API 연동 | ❌ **사용 금지** | FFS의 API 추정은 무효. §2 매핑표 사용 |
| 엣지 케이스 | Phase 3 QA | 유효 |
| 크로스 도메인 의존성 | 스프린트 순서 결정 | 유효 |

### QSS → 이렇게 사용

| QSS 섹션 | 활용처 | 주의 |
|---------|--------|------|
| 렌더링 테스트 | Phase 1 qa-engineer (Visual) | 유효 |
| i18n 테스트 | Phase 1 + Phase 3 | 유효 |
| 인터랙션 테스트 | Phase 3 Playwright | 유효 |
| 유효성검사 테스트 | Phase 3 | **기대 결과를 as-is 서버 msg로 교정 필요** |
| 크로스 페이지 플로우 | Phase 3 E2E | 유효, API mock 필요 |

---

## 8. 리스크 + 블로커 종합

| 리스크 | 영향 | 상태 | 해결 방안 |
|--------|------|------|----------|
| SendBird 계약/appId 재사용 | Sprint 3 전체 | 🔴 미확인 | 기존 계약 확인 필요 |
| Stripe 테스트 키 | Sprint 2 coin-charging | 🔴 미확인 | .env에 test mode 키 필요 |
| Hermes 서버 접근 | Sprint 3 과금 | 🔴 미확인 | 개발 환경 접근 확인 |
| 상담사 단계 규칙 | Sprint 5 counselor | 🔴 기획 미확정 | 기획자 확인 필요 |
| as-is API 실제 테스트 | Sprint 0부터 | 🟡 부분 가능 | dev 서버 접근 필요 |
| green 컬러값 | Sprint 1 layout | 🟢 Figma 수령 시 확정 | 대기 |

---

## 9. 즉시 실행 가능한 작업 (Sprint 0)

Figma 디자인 대기 없이 지금 바로 시작 가능:

| 작업 | 시간 | 의존성 |
|------|------|--------|
| `store/useAuthStore.js` 정의 | 30분 | 없음 |
| `store/useCoinStore.js` 정의 | 15분 | 없음 |
| `store/useDeviceStore.js` 정의 | 15분 | 없음 |
| `lib/validators.js` (as-is 규칙 이식) | 30분 | 없음 |
| `lib/nativeBridge.js` (플랫폼 통합) | 1시간 | 없음 |
| `lib/adjustTracker.js` (이벤트 상수) | 15분 | 없음 |
| 기존 login 페이지 → `loginuser` API 연동 | 2시간 | dev 서버 접근 |
| API 프록시 뼈대 10개 | 1시간 | 없음 |

**총 예상: ~5시간 — Figma 없이 즉시 실행 가능**
