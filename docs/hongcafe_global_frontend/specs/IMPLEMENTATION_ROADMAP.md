# 구현 로드맵 — HongCafe Global Frontend

> 생성일: 2026-03-24
> 기반: 화면설계서 FFS/QSS 15개 도메인 + ANALYSIS_REPORT + as-is 백엔드 분석
> 목적: 다음 스프린트부터 즉시 사용 가능한 구현 우선순위 + 의존성 그래프

---

## 1. as-is 백엔드 반영 — CRITICAL 이슈 해소

ANALYSIS_REPORT의 CRITICAL 4건 중 3건이 as-is 분석으로 해소됨:

| CRITICAL | 이슈 | as-is 해소 |
|----------|------|-----------|
| ~~#1~~ | 채팅 WebSocket 비현실적 | ✅ **SendBird SDK** 사용 (as-is 동일). WebSocket 직접 구현 불필요 |
| #2 | 상담사 단계 규칙 누락 | ❌ 기획자 확인 필요 (as-is에도 단계 로직은 어드민 서버 측) |
| ~~#3~~ | API 응답 형식 불일치 | ✅ as-is 표준: `{ response: "success\|error", msg, data, is_login }` — 전체 FFS 통일 |
| ~~#4~~ | 자동충전 실패 복구 없음 | ✅ as-is AutoPay: min_coin 이하 → Stripe PM으로 자동 PaymentIntent, 실패 시 FCM 알림 |

### 기술 스택 확정 (as-is 기반)

| 항목 | as-is | to-be (Next.js) |
|------|-------|-----------------|
| 채팅 | SendBird V1+V2 | **SendBird JS SDK** (동일 appId 재사용) |
| 결제 | Stripe + NicePay + NaverPay | **Stripe** (글로벌), NicePay (KR 선택) |
| 과금 타이머 | Hermes 서버 | **Hermes 동일** (API 프록시) |
| SMS 인증 | SMSLINK | **SMSLINK 동일** (API 프록시) |
| 푸시 알림 | FCM 듀얼 | **FCM 동일** |
| API 응답 | `{ response, msg, data }` | **동일 형식 유지** |

---

## 2. 의존성 그래프 (DAG)

```
Level 0 — 기반 (의존성 없음)
  ├── layout (GNB, Header, Footer, 테마 시스템)
  ├── 공유 컴포넌트 (CounselorCard, FilterBottomSheet, ReviewCard, ProfileTabs)
  └── 공유 스토어 (useAuthStore, useCoinStore, useCateStore, useFilterStore)

Level 1 — layout 의존
  ├── find-account (PageNavBar + reCAPTCHA)
  ├── phone-consultation 메인+카테고리 (GNB + Tab + CounselorCard + Filter)
  ├── chat-consultation 메인+카테고리 (GNB + Tab + CounselorCard + Filter)
  ├── category (GNB + 카테고리 메뉴)
  ├── search (GNB + CounselorCard + ReviewCard)
  ├── reviews (GNB + ReviewCard)
  ├── favorites (GNB + CounselorCard)
  └── coin-charging (GNB + useCoinStore)

Level 2 — phone/chat + coin 의존
  ├── phone-consultation 프로필 (ProfileTabs + ReviewCard + 상담하기 CTA)
  ├── chat-consultation 프로필+채팅방 (ProfileTabs + SendBird + Hermes)
  ├── member-mymenu (useAuthStore + useCoinStore + 코인내역/결제내역/채팅)
  └── counselor-registration (useAuthStore)

Level 3 — member-mymenu 의존
  └── counselor-mymenu (역할 전환 + 상담관리 + Hermes 정산)
```

---

## 3. 스프린트 계획

### Sprint 1: 기반 + 공유 컴포넌트 (Level 0)

| 작업 | 산출물 | Figma 필요 | 예상 규모 |
|------|--------|-----------|----------|
| layout 구현 | Header, Footer(GNB), Tab 영역 | ✅ 필요 | 대 |
| CounselorCard 공유 컴포넌트 | `components/CounselorCard.js` | ✅ 필요 | 중 |
| FilterBottomSheet 공유 컴포넌트 | `components/FilterBottomSheet.js` | ✅ 필요 | 중 |
| ReviewCard 공유 컴포넌트 | `components/ReviewCard.js` | ✅ 필요 | 소 |
| ProfileTabs 공유 컴포넌트 | `components/ProfileTabs.js` | ✅ 필요 | 중 |
| Zustand 스토어 정의 | useAuthStore, useCoinStore, useFilterStore | 불필요 | 소 |
| globals.css 테마 확장 | `--green-1: #00af79` 추가 | 불필요 | 소 |

**Figma 요청**: layout (GNB/Header/Footer), CounselorCard (그리드+리스트 뷰), FilterBottomSheet

### Sprint 2: 핵심 매출 — 전화상담 + 채팅상담 메인/카테고리 (Level 1)

| 작업 | 산출물 | Figma 필요 | 예상 규모 |
|------|--------|-----------|----------|
| phone-consultation 메인 | `/call` 메인 페이지 | ✅ 필요 | 대 |
| phone-consultation 카테고리 리스트 | `/call/category/[cate]` | ✅ 필요 | 대 |
| chat-consultation 메인 | `/chat` 메인 페이지 | ✅ 필요 | 중 (phone 80% 재사용) |
| chat-consultation 카테고리 리스트 | `/chat/category/[cate]` | ✅ 필요 | 중 (phone 재사용) |
| find-account | `/find-account` | ✅ 필요 | 중 |
| coin-charging | `/coin-charging` | ✅ 필요 | 중 |

**Figma 요청**: phone 메인, phone 카테고리, phone 필터 바텀시트, chat 메인 (phone과 차이점만), find-account, coin-charging

### Sprint 3: 프로필 + 상담하기 (Level 2)

| 작업 | 산출물 | Figma 필요 | 예상 규모 |
|------|--------|-----------|----------|
| phone-consultation 프로필 | `/call/profile/[id]` (5개 탭) | ✅ 필요 | 특대 |
| chat-consultation 프로필 | `/chat/profile/[id]` (5개 탭, phone 재사용) | ✅ 필요 | 대 |
| phone 상담하기 CTA | 하단 버튼 + 팝업 플로우 | ✅ 필요 | 중 |
| chat 상담하기 + 연결 | 연결중 화면 + SendBird 초기화 | ✅ 필요 | 대 |
| chat 채팅방 | `/chat/room/[sessionId]` | ✅ 필요 | 특대 |

**외부 SDK**: SendBird JS SDK 설치, Hermes API 프록시 구축

### Sprint 4: 보조 기능 (Level 1 나머지)

| 작업 | 산출물 | Figma 필요 | 예상 규모 |
|------|--------|-----------|----------|
| category | `/category`, `/category/posting/[id]` | ✅ 필요 | 중 |
| search | `/search` (상담사+후기 탭) | ✅ 필요 | 중 |
| reviews | `/reviews` | ✅ 필요 | 중 |
| favorites | `/favorites` (단골+최근방문) | ✅ 필요 | 소 |
| counselor-registration | `/counselor-registration` | ✅ 필요 | 소 |

### Sprint 5: 대시보드 (Level 2~3)

| 작업 | 산출물 | Figma 필요 | 예상 규모 |
|------|--------|-----------|----------|
| member-mymenu | `/my-menu` + 14개 서브페이지 | ✅ 필요 | 특대 |
| counselor-mymenu | `/counselor` + 8개 서브페이지 | ✅ 필요 | 특대 |

**블로커**: 상담사 단계 승급/강등 규칙 기획자 확인 완료 필수

---

## 4. 공유 컴포넌트 명세 (Sprint 1)

### CounselorCard
```
사용 도메인: phone, chat, search, favorites, category (8+ 곳)
Props:
  - counselor: { id, nickname, kanaName, category, styleTags, rating, reviewCount, coinPer30sec, status, number? }
  - showNumber: boolean (phone=true, chat=false)
  - viewMode: 'grid' | 'list'
  - consultationType: 'call' | 'chat'
  - onFavoriteToggle?: () => void
```

### FilterBottomSheet
```
사용 도메인: phone, chat, search (카테고리 리스트)
Props:
  - visible: boolean
  - onClose: () => void
  - onApply: (filters) => void
  - sortOptions: SortOption[] (phone 8개 / chat 6개)
  - styleOptions: string[] (9개 공통)
  - fieldOptions: string[] (25개 공통)
  - maxStyleCount: 3
  - maxFieldCount: 3
```

### ReviewCard
```
사용 도메인: reviews, phone/chat 프로필>후기, search>후기
Props:
  - review: { nickname, rating, text, date, counselorName, consultationType }
  - onReport: () => void
  - showHandwriting?: boolean
```

### ProfileTabs
```
사용 도메인: phone 프로필, chat 프로필
Props:
  - counselorId: string
  - tabs: ['products', 'detail', 'reviews', 'inquiry', 'posting']
  - activeTab: string
  - onTabChange: (tab) => void
  - consultationType: 'call' | 'chat'
```

---

## 5. API 프록시 통합 목록 (백엔드 요청)

as-is API를 Next.js 프록시 레이어로 매핑:

| 도메인 | 프록시 경로 | as-is 엔드포인트 | Method |
|--------|-----------|-----------------|--------|
| auth | `/api/auth/login` | `/member/loginuser` | POST |
| auth | `/api/auth/checkAccount` | `/member/CheckAccount` | POST |
| auth | `/api/auth/register` | `/member/setMember` | POST |
| auth | `/api/auth/findId` | `/member/findID` | POST |
| auth | `/api/auth/resetPassword` | `/member/changePW` | POST |
| auth | `/api/auth/sendSms` | `/member/sendAuthPhone` | POST |
| phone | `/api/call/getList` | `/items/getListMobile` | POST |
| phone | `/api/call/getProfile` | `/items/getDetailMobile` | POST |
| phone | `/api/call/getReviews` | `/items/getReviewList` | POST |
| chat | `/api/chat/getList` | `/items/getListMobile` | POST |
| chat | `/api/chat/getProfile` | `/items/getDetailMobile` | POST |
| chat | `/api/chat/startSession` | `/chat/reqChat` | POST |
| coin | `/api/coin/getBalance` | `/mypage/getCoinInfo` | POST |
| coin | `/api/coin/createPayment` | `/pay/insertCoinOrder` | POST |
| coin | `/api/coin/getHistory` | `/mypage/getCoinList` | POST |
| search | `/api/search/counselor` | `/items/getSearchList` | POST |
| search | `/api/search/reviews` | `/items/getSearchReview` | POST |
| favorites | `/api/favorites/getList` | `/mypage/getJjimList` | POST |
| favorites | `/api/favorites/toggle` | `/items/setJjim` | POST |
| reviews | `/api/reviews/getList` | `/items/getReviewAll` | POST |
| reviews | `/api/reviews/write` | `/items/setReview` | POST |
| member | `/api/member/getInfo` | `/mypage/getMyInfo` | POST |
| member | `/api/member/updateNickname` | `/mypage/updateNickname` | POST |
| member | `/api/member/updatePhone` | `/mypage/updatePhone` | POST |
| member | `/api/member/withdraw` | `/member/deleteMember` | POST |

**응답 형식 통일**: `{ response: "success"|"error", msg: string, data: T, is_login: string }`

---

## 6. Figma 디자인 요청 우선순위

V4.5 파이프라인 투입 순서 (Figma 디자인 완료 → design-normalizer → publisher):

| 순위 | 대상 | 슬라이드 참조 | 이유 |
|------|------|-------------|------|
| 1 | layout (GNB + Header + Footer) | S55~S61 | 모든 페이지의 기반 |
| 2 | CounselorCard (그리드/리스트) | S65, S67 | 8+ 도메인 공유 |
| 3 | FilterBottomSheet | S73~S81 | phone/chat/search 공유 |
| 4 | phone-consultation 메인 | S65~S69 | 핵심 매출 |
| 5 | phone-consultation 카테고리 | S71~S91 | 핵심 매출 |
| 6 | find-account | S49~S54 | 인증 완성 |
| 7 | coin-charging | S439~S445 | 결제 연동 |
| 8 | phone-consultation 프로필 | S93~S132 | 프로필 5개 탭 |
| 9 | chat-consultation (phone 차이점만) | S155~S194 | phone 재사용 후 차이만 |
| 10 | 나머지 (category, search, etc.) | S247~ | 보조 기능 |

---

## 7. 리스크 플래그

| 리스크 | 영향 | 완화 방안 |
|--------|------|----------|
| SendBird 라이선스/비용 | chat 도메인 전체 | as-is 계약 확인, 동일 appId 재사용 가능 여부 |
| Hermes 서버 접근 | phone/chat 과금 | 개발 환경에서 Hermes API 접근 가능 여부 확인 |
| Stripe 테스트 환경 | coin-charging | Stripe test mode 키 확보 필요 |
| 상담사 단계 규칙 미확정 | counselor-mymenu | Sprint 5까지 기획자 확인 완료 필요 |
| green 컬러값 미확정 | layout 테마 | Figma 디자인 수령 시 확정 |
