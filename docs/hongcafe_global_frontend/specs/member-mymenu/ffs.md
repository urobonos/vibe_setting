# Frontend Functional Spec — 회원 마이메뉴

> Source: 화면설계서 PPTX Slides S294~S360 (67 슬라이드) + as-built 스캐폴드(`app/[locale]/mypage/`, 커밋 `bd5d4ce`)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

> ⚠️ **라우트 패턴 미확정 (유형 D — 정책 결정 필요)**: 화면설계서 기반 v1.0 스펙은 `/my-menu/*`로 정의되었으나 as-built 스캐폴드는 `/mypage/*`로 구현됨 (커밋 `bd5d4ce`). 두 패턴 중 정식 명칭/URL을 §8 미확정 사항 #25에서 결정 필요. 본 문서는 §3-0(as-built 스캐폴드)와 §3-1~13(화면설계서 기반)을 **공존 표기**한다.

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 회원 마이메뉴 (Member My Menu) |
| 사용자 목표 | 회원이 자신의 계정 정보, 상담 이력, 코인/결제 내역, VIP 혜택, 쿠폰, 알림, 고객센터 등을 한곳에서 관리한다 |
| 퍼블리싱 상태 | ❌ 미구현 |
| 기능 연동 상태 | 미연동 |
| i18n 네임스페이스 | `myMenu`, `memberInfo`, `vip`, `coupon`, `consultHistory`, `coinHistory`, `paymentHistory`, `chatConsult`, `myReview`, `myInquiry`, `autoCharge`, `notification`, `customerService`, `event` |
| 지원 로케일 | `en`, `ko`, `ja` |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |
| 슬라이드 수 | 67장 — 프로젝트 내 두 번째 대규모 도메인 (상담사 마이메뉴 78장 다음) |

### 비즈니스 모델 핵심

- 회원 마이메뉴는 **일반 회원(내담자) 전용** 관리 패널이다.
- 비로그인 상태에서도 마이메뉴 홈에 접근 가능하지만, 대부분의 하위 기능은 로그인 필수이다.
- 비로그인 시 마이메뉴 홈에 "로그인하세요" 안내와 로그인/회원가입 버튼이 노출된다.
- 상담사 등록 완료 회원은 "회원/상담사 전환" 기능으로 상담사 마이메뉴로 이동할 수 있다.
- VIP 등급은 월 결제 금액 기준으로 자동 산정되며, 리워드 코인이 매월 1일 지급된다.

### 도메인 흐름 요약

```
마이메뉴 홈 (/my-menu)
  ├── [비로그인] 로그인하세요 + 로그인/회원가입 버튼
  ├── [로그인] 닉네임 + 나의코인 + 코인충전 링크 + 회원정보 링크
  ├── 공지 배너
  ├── VIP 혜택 카운트 + 쿠폰 카운트
  ├── 회원정보 (/my-menu/info)
  │     ├── 닉네임 변경 (/my-menu/info/nickname)
  │     ├── 휴대폰번호 변경 (/my-menu/info/phone)
  │     ├── 비밀번호 변경 (/my-menu/info/password)
  │     ├── 알림 수신 설정 (/my-menu/info/notification-settings)
  │     └── 회원탈퇴 (/my-menu/info/withdraw)
  ├── VIP 혜택 (/my-menu/vip)
  ├── 쿠폰함 (/my-menu/coupon)
  ├── 상담내역 (/my-menu/consult-history)
  │     └── 상담내역 상세 (/my-menu/consult-history/[id])
  ├── 코인충전/사용내역 (/my-menu/coin-history)
  ├── 결제내역 (/my-menu/payment-history)
  │     └── 결제 상세 (/my-menu/payment-history/[id])
  ├── 채팅상담 (/my-menu/chat-consult)
  ├── 나의 후기 (/my-menu/my-review)
  │     └── 후기 작성 (/my-menu/my-review/write/[counselorId])
  ├── 나의 1:1 문의 (/my-menu/my-inquiry)
  ├── 코인 자동충전 (/my-menu/auto-charge)
  │     ├── 카드 등록 (/my-menu/auto-charge/card-register)
  │     └── 자동충전 관리 (/my-menu/auto-charge/manage)
  ├── 알림내역 (/my-menu/notification)
  ├── 고객센터 (/my-menu/customer-service)
  │     ├── FAQ (/my-menu/customer-service/faq)
  │     ├── 1:1 문의 작성 (/my-menu/customer-service/inquiry/write)
  │     ├── 공지사항 (/my-menu/customer-service/notice)
  │     └── 공지사항 상세 (/my-menu/customer-service/notice/[id])
  └── 이벤트 (/my-menu/event)
```

### 상담사 마이메뉴 대비 핵심 차이점

| 항목 | 회원 마이메뉴 | 상담사 마이메뉴 |
|------|------------|---------------|
| 접근 조건 | 비로그인도 홈 접근 가능 (하위 기능은 로그인 필수) | 상담사 등록 완료 필수 |
| 역할 | 내담자 (상담 받는 자) | 상담사 (상담 제공자) |
| 상담 상태 제어 | 없음 | 전화/채팅 ON/OFF 토글 |
| 상담 내역 | 내가 받은 상담 | 내가 제공한 상담 |
| 코인 | 충전/사용 내역 확인 | 없음 (정산 관리) |
| 결제 | 결제/환불 내역 확인 | 없음 (정산 관리) |
| VIP/쿠폰 | VIP 혜택 + 쿠폰함 | 없음 |
| 후기 | 내가 작성한 후기 | 없음 (받은 후기는 프로필에서 확인) |
| 자동충전 | 카드 등록 + 자동충전 설정 | 없음 |
| 고객센터 | FAQ + 1:1문의 + 공지사항 | 없음 (별도 채널) |

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/my-menu` | `app/[locale]/my-menu/page.js` | MyMenuHome | Server → Client | `myMenu` |
| `/[locale]/my-menu/info` | `app/[locale]/my-menu/info/page.js` | MemberInfo | Server → Client | `memberInfo` |
| `/[locale]/my-menu/info/nickname` | `app/[locale]/my-menu/info/nickname/page.js` | NicknameChange | Server → Client | `memberInfo` |
| `/[locale]/my-menu/info/phone` | `app/[locale]/my-menu/info/phone/page.js` | PhoneChange | Server → Client | `memberInfo` |
| `/[locale]/my-menu/info/password` | `app/[locale]/my-menu/info/password/page.js` | PasswordChange | Server → Client | `memberInfo` |
| `/[locale]/my-menu/info/notification-settings` | `app/[locale]/my-menu/info/notification-settings/page.js` | NotificationSettings | Server → Client | `memberInfo` |
| `/[locale]/my-menu/info/withdraw` | `app/[locale]/my-menu/info/withdraw/page.js` | MemberWithdraw | Server → Client | `memberInfo` |
| `/[locale]/my-menu/vip` | `app/[locale]/my-menu/vip/page.js` | VipBenefits | Server → Client | `vip` |
| `/[locale]/my-menu/coupon` | `app/[locale]/my-menu/coupon/page.js` | CouponBox | Server → Client | `coupon` |
| `/[locale]/my-menu/consult-history` | `app/[locale]/my-menu/consult-history/page.js` | ConsultHistory | Server → Client | `consultHistory` |
| `/[locale]/my-menu/consult-history/[id]` | `app/[locale]/my-menu/consult-history/[id]/page.js` | ConsultHistoryDetail | Server → Client | `consultHistory` |
| `/[locale]/my-menu/coin-history` | `app/[locale]/my-menu/coin-history/page.js` | CoinHistory | Server → Client | `coinHistory` |
| `/[locale]/my-menu/payment-history` | `app/[locale]/my-menu/payment-history/page.js` | PaymentHistory | Server → Client | `paymentHistory` |
| `/[locale]/my-menu/payment-history/[id]` | `app/[locale]/my-menu/payment-history/[id]/page.js` | PaymentHistoryDetail | Server → Client | `paymentHistory` |
| `/[locale]/my-menu/chat-consult` | `app/[locale]/my-menu/chat-consult/page.js` | ChatConsult | Server → Client | `chatConsult` |
| `/[locale]/my-menu/my-review` | `app/[locale]/my-menu/my-review/page.js` | MyReview | Server → Client | `myReview` |
| `/[locale]/my-menu/my-review/write/[counselorId]` | `app/[locale]/my-menu/my-review/write/[counselorId]/page.js` | ReviewWrite | Server → Client | `myReview` |
| `/[locale]/my-menu/my-inquiry` | `app/[locale]/my-menu/my-inquiry/page.js` | MyInquiry | Server → Client | `myInquiry` |
| `/[locale]/my-menu/auto-charge` | `app/[locale]/my-menu/auto-charge/page.js` | AutoCharge | Server → Client | `autoCharge` |
| `/[locale]/my-menu/auto-charge/card-register` | `app/[locale]/my-menu/auto-charge/card-register/page.js` | CardRegister | Server → Client | `autoCharge` |
| `/[locale]/my-menu/auto-charge/manage` | `app/[locale]/my-menu/auto-charge/manage/page.js` | AutoChargeManage | Server → Client | `autoCharge` |
| `/[locale]/my-menu/notification` | `app/[locale]/my-menu/notification/page.js` | NotificationHistory | Server → Client | `notification` |
| `/[locale]/my-menu/customer-service` | `app/[locale]/my-menu/customer-service/page.js` | CustomerService | Server → Client | `customerService` |
| `/[locale]/my-menu/customer-service/faq` | `app/[locale]/my-menu/customer-service/faq/page.js` | Faq | Server → Client | `customerService` |
| `/[locale]/my-menu/customer-service/inquiry/write` | `app/[locale]/my-menu/customer-service/inquiry/write/page.js` | InquiryWrite | Server → Client | `customerService` |
| `/[locale]/my-menu/customer-service/notice` | `app/[locale]/my-menu/customer-service/notice/page.js` | NoticeList | Server → Client | `customerService` |
| `/[locale]/my-menu/customer-service/notice/[id]` | `app/[locale]/my-menu/customer-service/notice/[id]/page.js` | NoticeDetail | Server → Client | `customerService` |
| `/[locale]/my-menu/event` | `app/[locale]/my-menu/event/page.js` | EventList | Server → Client | `event` |

### 인증 요구

| 라우트 | 인증 요구 |
|--------|----------|
| `/my-menu` (홈) | 비로그인 접근 가능 (로그인 안내 UI 표시) |
| 나머지 모든 하위 라우트 | **로그인 필수** — 비로그인 시 `/[locale]/login`으로 리다이렉트 |

- 리다이렉트 시 `returnUrl` 쿼리파라미터를 전달하여 로그인 후 복귀할 수 있도록 한다.

---

## 3. 페이지 정의

### 3-0. as-built 마이페이지 스캐폴드 (`/[locale]/mypage`) — v1.1 신규

> 커밋 `bd5d4ce`로 추가된 최소 동작 가능 스캐폴드. 화면설계서 §3-1과 동일한 의도(마이메뉴 홈)이나 라우트와 라벨 네이밍이 다르다. 라우트 통일 결정(§8 미확정 #25) 전까지 별도 섹션으로 명시한다.

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage` |
| Server Component | `app/[locale]/mypage/page.js` — `getAuthFromCookies()`로 인증 확인, 비로그인 시 `redirect(\`/\${locale}/login\`)` |
| Client Component | `app/[locale]/mypage/_components/MyPageContent.js` |
| i18n 네임스페이스 | `myPage` (+ BottomNav는 `main` 네임스페이스 재사용) |
| 화면설계서 매핑 | S295 (마이메뉴 홈에 해당) |

#### UI 섹션 (as-built 위→아래)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | `PageNavBar` — `labels.navTitle` + Home 버튼 |
| 1 | 프로필 영역 | bg-[#f4f2f8] + `labelNickname` + `nickname`(`user?.acNick \|\| serverUser?.acNick`) + `labelMyCoins` + `formattedCoin`(Intl.NumberFormat by locale) |
| 2 | 계정 정보 / 코인 충전 버튼 | `<Link href="/${locale}/mypage/info">` + `<Link href="/${locale}/getcoins">` (각각 flex-1, 사이 1px 디바이더) |
| 3 | 공지 배너 | `MOCK_NOTICES` 비어있지 않을 때만 노출. Swiper(direction=vertical, autoplay 3s, Autoplay 모듈) + chevron_right_circle 아이콘 |
| 4 | VIP/쿠폰 카드 | bg-[#f5f5f5] border 카드 (h-[5.6rem]) — `labelVipBenefits` 섹션(`-` 표시) + 디바이더 + `labelCoupon` 섹션(`0` 표시, 보라색) |
| 5 | 메뉴 그룹 1 (8개) | 흰색 카드 + 8개 `<MenuItem>`: `menuSessionHistory`, `menuCoinHistory`, `menuPaymentHistory`, `menuChat`, `menuMyReviews`, `menuMyInquiries`, `menuAutoRecharge`, `menuNotifications` |
| 6 | 디바이더 | h-[0.8rem] bg-[#f5f5f5] |
| 7 | 메뉴 그룹 2 (2개) | 흰색 카드 + `menuCustomerService`, `menuPromotions` |
| 8 | Sign Out 버튼 | bg-[#6335b4] full-width — `handleSignOut` → `useAuthStore.logout()` + `setCoin(0,0)` + `router.push(\`/\${locale}/login\`)` |
| 9 | BottomNav | `<BottomNav labels={labels} locale={locale} />` — Home/Browse/Favourites/MyPage/GetCoins 5개 탭 (§Phase C-1 layout 참조) |

#### 상태 관리

| 상태 | 출처 | 용도 |
|------|------|------|
| `isLoggedIn`/`user`/`setAuth`/`logout` | `useAuthStore` | 인증 상태 + 액션 |
| `coin`/`setCoin` | `useCoinStore` | 잔액 상태 |
| `isSigningOut` | `useState(false)` | 로그아웃 중복 클릭 차단 |
| `serverUser` | props | SSR `getAuthFromCookies()` 결과 — 첫 렌더 시 `setAuth(true, serverUser)`로 클라이언트 store 동기화 |

#### API 연동 (as-built)

| 엔드포인트 | 메서드 | 용도 | 구현 상태 |
|-----------|--------|------|----------|
| `POST /api/coin/get-balance` | POST | 진입 시 + 로그인 변경 시 잔액 조회 — `secureFetch` | **구현 (스캐폴드)** — 응답 `data.data.{coin, free_coin}` 사용 |
| `useAuthStore.logout()` | — | Sign Out 클릭 시 호출 → 백엔드 logout EP (logout 액션 내부) | 부분 — **secureFetch 미사용 (감사 권고 미반영, 유형 B)** |

#### 인터랙션

| 액션 | 동작 (as-built) |
|------|----------------|
| 페이지 진입 (인증 미확인) | Server에서 `redirect(\`/\${locale}/login\`)` |
| 페이지 진입 (인증) | `serverUser` props로 클라이언트 store 동기화 + `get-balance` 호출 |
| 잔액 조회 실패 | catch → `setCoin(0,0)` (graceful) |
| 계정 정보 클릭 | `/${locale}/mypage/info` 이동 (라우트 미구현) |
| 코인 충전 클릭 | `/${locale}/getcoins` 이동 (라우트 미구현) |
| 메뉴 항목 클릭 | 각 `/${locale}/mypage/{slug}` 이동 — 모두 미구현 라우트 (chevron_right_sm 아이콘) |
| Sign Out 클릭 | `isSigningOut=true` → `logout()` → `setCoin(0,0)` → `/${locale}/login` 리다이렉트 → `isSigningOut=false` |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| **인증 필수** | Server `getAuthFromCookies()` 미인증 시 즉시 `/login` 리다이렉트 (returnUrl 미전달 — 유형 C 개선) |
| **클라이언트 store 동기화** | `serverUser`(SSR) → `setAuth(true, serverUser)`로 zustand 동기화 (RSC ↔ CSC 인증 일관성) |
| **잔액 fallback** | `get-balance` 실패 시 `setCoin(0,0)` — UI는 0으로 graceful |
| **Intl.NumberFormat by locale** | `ko`→`ko-KR`, `ja`→`ja-JP`, 그 외→`en-US` (KR 제외 정책에서는 ja/en 두 케이스만 활성) |

#### 엣지 케이스 (as-built)

| 케이스 | 처리 |
|--------|------|
| serverUser는 있으나 isLoggedIn=false (race) | useEffect로 `setAuth(true, serverUser)` 동기화 |
| 잔액 조회 네트워크 에러 | catch → `setCoin(0,0)`, UI는 "0"으로 표시 |
| Sign Out 중복 클릭 | `isSigningOut` 가드로 차단 |
| Sign Out 후 logout 실패 | finally 블록에서 `isSigningOut=false`로 복구 — 사용자에게 에러 표시 미구현 (유형 C) |
| `/login`으로 리다이렉트 시 returnUrl | **as-built는 미전달** (유형 C — 향후 `?returnUrl=/mypage`) |
| 비공개 라우트 직접 접근 | `getAuthFromCookies` 결과 미인증 → 즉시 redirect (returnUrl 미전달 동일 이슈) |

#### 의존성 (as-built)

| 의존성 | 용도 |
|--------|------|
| `PageNavBar` | 상단 네비게이션 |
| `BottomNav` (`components/BottomNav.js`) | 하단 5탭 네비게이션 (§Phase C-1) |
| `useAuthStore` | 인증 상태 + `setAuth`/`logout` |
| `useCoinStore` | 잔액 상태 + `setCoin` |
| `lib/auth.js` (`getAuthFromCookies`) | Server에서 인증 확인 |
| `lib/fetchWithAuth.js` (`secureFetch`) | CSRF 자동 첨부 잔액 조회 |
| `lib/mockNotices.js` (`MOCK_NOTICES`) | 공지 배너 mock 데이터 (CMS 교체 예정 — 유형 C) |
| `swiper/react` (Autoplay 모듈) | 공지 vertical 슬라이더 |
| `next/link`, `next/image`, `useRouter` | 네비게이션 + 이미지 |

#### i18n 키 (myPage 네임스페이스)

| 키 (as-built) | 용도 |
|--------------|------|
| `navTitle`, `home` | 상단 네비게이션 |
| `labelNickname`, `labelMyCoins` | 프로필 영역 |
| `btnAccountInfo`, `btnCoinPurchase` | 프로필 액션 버튼 |
| `noticePrefix` | 공지 배너 prefix ("공지" 등) |
| `labelVipBenefits`, `labelCoupon` | VIP/쿠폰 카드 |
| `menuSessionHistory`, `menuCoinHistory`, `menuPaymentHistory`, `menuChat`, `menuMyReviews`, `menuMyInquiries`, `menuAutoRecharge`, `menuNotifications`, `menuCustomerService`, `menuPromotions` | 메뉴 항목 라벨 |
| `signOut` | Sign Out 버튼 |

> ※ `main` 네임스페이스 재사용: `navHome`, `navBrowse`, `navFavourites`, `navMyPage`, `navGetCoins` (BottomNav)

---

### 3-1. 마이메뉴 홈 (슬라이드 S295)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu` |
| Server Component | `app/[locale]/my-menu/page.js` — 메타데이터 생성, labels 구성, 로그인 상태 확인, 초기 데이터 조회 |
| Client Component | `app/[locale]/my-menu/_components/MyMenuHome.js` |
| 화면설계서 | S295 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, "My Menu" + Home 버튼 |
| 1-A | 비로그인 프로필 영역 | "로그인하세요" 텍스트 + 로그인 버튼 + 회원가입 버튼 |
| 1-B | 로그인 프로필 영역 | 닉네임 + 나의코인(숫자, Intl.NumberFormat) + "코인충전" 링크 + "회원정보" 링크 |
| 2 | 공지 배너 | 운영 공지사항 배너 (Swiper 슬라이드 또는 단일 배너) |
| 3 | VIP/쿠폰 카운트 | VIP 혜택 카운트 + 코인쿠폰 카운트 (각각 링크) |
| 4 | 메뉴 리스트 | 10개 메뉴 항목 리스트 (아이콘 + 텍스트 + 화살표) |

#### 메뉴 리스트 항목

| 순서 | 메뉴명 | 이동 경로 | 아이콘 |
|------|--------|----------|--------|
| 1 | 상담내역 | `/my-menu/consult-history` | 상담내역 아이콘 |
| 2 | 코인충전/사용내역 | `/my-menu/coin-history` | 코인 아이콘 |
| 3 | 결제내역 | `/my-menu/payment-history` | 결제 아이콘 |
| 4 | 채팅상담 | `/my-menu/chat-consult` | 채팅 아이콘 |
| 5 | 나의 후기 | `/my-menu/my-review` | 후기 아이콘 |
| 6 | 나의 1:1 문의 | `/my-menu/my-inquiry` | 문의 아이콘 |
| 7 | 코인 자동충전 | `/my-menu/auto-charge` | 자동충전 아이콘 |
| 8 | 알림내역 | `/my-menu/notification` | 알림 아이콘 |
| 9 | 고객센터 | `/my-menu/customer-service` | 고객센터 아이콘 |
| 10 | 이벤트 | `/my-menu/event` | 이벤트 아이콘 |

#### 상태 관리

- `useAuthStore`: 로그인 상태, 사용자 닉네임, 역할(member/counselor)
- `useCoinStore`: 보유코인 잔액 (전역 공유)
- 로컬 상태: 공지 배너 접힘 여부

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/member/getMyMenuInfo` | POST | `{ locale }` | `{ response, nickname, balance, vipCount, couponCount, notices }` | 페이지 초기 로드 (Server) |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 로그인 버튼 클릭 (비로그인) | `/[locale]/login?returnUrl=/[locale]/my-menu`로 이동 |
| 회원가입 버튼 클릭 (비로그인) | `/[locale]/join`으로 이동 |
| 코인충전 링크 클릭 | `/[locale]/coin-charging`으로 이동 |
| 회원정보 링크 클릭 | `/[locale]/my-menu/info`로 이동 |
| VIP 혜택 카운트 클릭 | `/[locale]/my-menu/vip`로 이동 |
| 쿠폰 카운트 클릭 | `/[locale]/my-menu/coupon`으로 이동 |
| 메뉴 항목 클릭 | 해당 메뉴 라우트로 이동 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 비로그인 홈 접근 | 마이메뉴 홈은 비로그인도 접근 가능. 프로필 영역만 "로그인하세요"로 대체 |
| 보유코인 포맷 | `Intl.NumberFormat('ko', { currency: 'KRW' })` 사용, 천단위 콤마 |
| VIP/쿠폰 카운트 | 0건이면 숫자 "0" 표시 (숨기지 않음) |
| 메뉴 리스트 진입 | 비로그인 상태에서 메뉴 항목 클릭 시 로그인 페이지로 리다이렉트 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 보유코인 조회 실패 | "0" 표시 + 재시도 안내 |
| 공지 배너 없음 | 배너 영역 자체 비노출 |
| 상담사 등록 완료 회원 | "상담사 마이메뉴" 전환 버튼 노출 가능 (추정) |

---

### 3-2. 회원정보 (슬라이드 S296~S306)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/info` |
| Server Component | `app/[locale]/my-menu/info/page.js` |
| Client Component | `app/[locale]/my-menu/info/_components/MemberInfoMain.js` |
| 화면설계서 | S296 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "회원정보" |
| 1 | 닉네임 | 닉네임 표시 + "변경" 버튼 |
| 2 | 이메일 (ID) | 이메일 표시 (읽기 전용, 변경 불가) |
| 3 | 휴대폰번호 | 휴대폰번호 표시 (마스킹) + "변경" 버튼 |
| 4 | 본인확인 | 본인인증 상태 표시 |
| 5 | 알림 수신 설정 | "설정" 링크 → 알림 수신 설정 페이지 이동 |
| 6 | 회원탈퇴 | "회원탈퇴" 링크 → 회원탈퇴 페이지 이동 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/getInfo` | POST | `{ locale }` | `{ response, nickname, email, phone, identityVerified, lastNicknameChanged }` |

---

### 3-2-1. 닉네임 변경 (슬라이드 S297~S299)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/info/nickname` |
| Client Component | `app/[locale]/my-menu/info/nickname/_components/NicknameChangeForm.js` |
| 화면설계서 | S297~S299 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "닉네임 변경" |
| 1 | 현재 닉네임 | 현재 닉네임 표시 (읽기 전용) |
| 2 | 새 닉네임 입력 | input 필드 + Clear 버튼 + 중복확인 버튼 |
| 3 | 유효성 메시지 영역 | 에러/성공 메시지 조건부 렌더링 |
| 4 | 변경 버튼 | 보라색 풀폭 버튼 — 중복확인 통과 시 활성 |

#### 유효성 규칙

| 규칙 | 조건 |
|------|------|
| 길이 | 2~12자 |
| 형식 | 한글, 영문, 숫자만 허용 (특수문자 금지) |
| 중복 | 서버 중복확인 통과 필수 |
| 재변경 제한 | 마지막 변경일로부터 1주일(7일) 이후에만 변경 가능 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 미입력 상태에서 변경 시도 | "닉네임을 입력해주세요." | 에러 |
| 2자 미만 또는 12자 초과 | "닉네임을 2~12자로 입력해 주세요." | 에러 |
| 특수문자 포함 | "한글,영문,숫자만 입력해 주세요." | 에러 |
| 중복된 닉네임 | "입력하신 닉네임은 이미 사용중인 닉네임입니다." | 에러 |
| 1주일 미경과 | "닉네임 재변경은 1주일 이후에 가능합니다." | 에러 |
| 중복확인 통과 | "사용 가능한 닉네임입니다." | 성공 |
| 변경 완료 | "닉네임이 변경되었습니다." | 성공 (알럿) |

#### 상태 관리

- 로컬 상태:
  - `newNickname` — 새 닉네임 입력값 (string)
  - `isDuplicateChecked` — 중복확인 통과 여부 (boolean)
  - `errorMessage` — 유효성 에러 메시지 (string | null)
  - `isSubmitting` — 변경 API 호출 중 (boolean)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/checkNickname` | POST | `{ nickname }` | `{ response, available: boolean, message }` |
| `/api/member/updateNickname` | POST | `{ nickname }` | `{ response, message }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 닉네임 입력 | 입력할 때마다 클라이언트 유효성(길이, 형식) 즉시 검사 |
| 중복확인 버튼 | 클라이언트 유효성 통과 시 서버 중복확인 API 호출 |
| Clear 버튼 | 입력값 초기화, `isDuplicateChecked` false로 리셋 |
| 변경 버튼 | `isDuplicateChecked === true`일 때만 활성. 클릭 시 변경 API 호출 |
| 닉네임 재입력 (중복확인 후) | `isDuplicateChecked` false로 리셋 → 변경 버튼 비활성화 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 중복확인 필수 | 중복확인을 거치지 않으면 변경 버튼 비활성 유지 |
| 중복확인 후 수정 시 재확인 필요 | 중복확인 통과 후 닉네임을 수정하면 중복확인 상태가 리셋됨 |
| 1주일 제한 | 마지막 변경일 + 7일 이전이면 페이지 진입 시 안내 메시지 표시 + 입력 비활성 |

---

### 3-2-2. 휴대폰번호 변경 (슬라이드 S300~S302)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/info/phone` |
| Client Component | `app/[locale]/my-menu/info/phone/_components/PhoneChangeForm.js` |
| 화면설계서 | S300~S302 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "휴대폰번호 변경" |
| 1 | 현재 번호 | 현재 등록된 휴대폰번호 (마스킹) 표시 |
| 2 | 국가 선택 | Globe 아이콘 + 국가 드롭다운 (국기 + 국가코드) |
| 3 | 새 번호 입력 | input 필드 (숫자만) + 인증번호 발송 버튼 |
| 4 | 인증번호 입력 | input 필드 + 타이머(3분) + 재발송 링크 |
| 5 | 변경 버튼 | 보라색 풀폭 버튼 — 인증 완료 시 활성 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 휴대폰번호 미입력 | "휴대폰번호를 입력해주세요." | 에러 |
| 인증번호 미입력 | "인증번호를 입력해주세요." | 에러 |
| 인증번호 불일치 | "인증번호가 일치하지 않습니다." | 에러 |
| 인증시간 만료 | "인증시간이 만료되었습니다. 다시 시도해주세요." | 에러 |
| 인증 성공 | "인증이 완료되었습니다." | 성공 |
| 변경 완료 | "휴대폰번호가 변경되었습니다." | 성공 (알럿) |

#### 상태 관리

- 로컬 상태:
  - `countryCode` — 선택된 국가코드 (string, 기본값: locale 기반)
  - `phoneNumber` — 새 휴대폰번호 입력값 (string)
  - `verificationCode` — 인증번호 입력값 (string)
  - `isCodeSent` — 인증번호 발송 여부 (boolean)
  - `isVerified` — 인증 완료 여부 (boolean)
  - `timer` — 인증번호 유효시간 카운트다운 (number, 초)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/sendPhoneCode` | POST | `{ countryCode, phone }` | `{ response, message }` |
| `/api/member/verifyPhoneCode` | POST | `{ countryCode, phone, code }` | `{ response, verified: boolean, message }` |
| `/api/member/updatePhone` | POST | `{ countryCode, phone, code }` | `{ response, message }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 국가 선택 | 국가코드 변경, 번호 입력 리셋 |
| 인증번호 발송 | API 호출 → 성공 시 인증번호 입력 필드 활성화 + 3분 타이머 시작 |
| 재발송 | 기존 타이머 리셋 + 새 인증번호 발송 |
| 인증 확인 | 인증번호 검증 API → 성공 시 변경 버튼 활성화 |
| 타이머 만료 | 인증번호 입력 비활성화 + 재발송 안내 |

---

### 3-2-3. 비밀번호 변경 (슬라이드 S303~S304)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/info/password` |
| Client Component | `app/[locale]/my-menu/info/password/_components/PasswordChangeForm.js` |
| 화면설계서 | S303~S304 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "비밀번호 변경" |
| 1 | 기존 비밀번호 | input (type=password) + Eye 토글 아이콘 |
| 2 | 새 비밀번호 | input (type=password) + Eye 토글 아이콘 + 안내 텍스트 |
| 3 | 비밀번호 확인 | input (type=password) + Eye 토글 아이콘 |
| 4 | 변경 버튼 | 보라색 풀폭 버튼 |

#### 유효성 규칙

| 규칙 | 조건 |
|------|------|
| 길이 | 6~16자 |
| 복잡도 | 영문, 숫자, 특수문자 중 2가지 이상 조합 |
| 확인 일치 | 새 비밀번호와 확인 비밀번호가 동일해야 함 |
| 기존 비밀번호 | 서버에서 기존 비밀번호 일치 여부 확인 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 기존 비밀번호 미입력 | "비밀번호를 입력해 주세요." | 에러 |
| 새 비밀번호 미입력 | "비밀번호를 입력해 주세요." | 에러 |
| 길이/복잡도 미충족 | "비밀번호는 영문,숫자,특수문자 2가지 이상 6~16자로 입력해 주세요." | 에러 |
| 확인 비밀번호 불일치 | "비밀번호가 일치하지 않습니다." | 에러 |
| 기존 비밀번호 오류 (서버 응답) | "기존 비밀번호가 올바르지 않습니다." | 에러 |
| 변경 완료 | "비밀번호가 변경되었습니다." | 성공 (알럿) |

#### 상태 관리

- 로컬 상태:
  - `currentPassword` — 기존 비밀번호 (string)
  - `newPassword` — 새 비밀번호 (string)
  - `confirmPassword` — 비밀번호 확인 (string)
  - `showCurrentPw` / `showNewPw` / `showConfirmPw` — Eye 토글 상태 (boolean)
  - `errors` — 필드별 에러 메시지 객체

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/updatePassword` | POST | `{ currentPassword, newPassword }` | `{ response, message }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| Eye 아이콘 클릭 | password/text 타입 토글 (비밀번호 표시/숨김) |
| 변경 버튼 클릭 | 클라이언트 유효성 → 서버 비밀번호 변경 API 호출 |
| 변경 성공 | 성공 알럿 → 회원정보 페이지로 이동 |

---

### 3-2-4. 알림 수신 설정 (슬라이드 S305)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/info/notification-settings` |
| Client Component | `app/[locale]/my-menu/info/notification-settings/_components/NotificationSettingsMain.js` |
| 화면설계서 | S305 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "알림 수신 설정" |
| 1 | 푸시 알림 | "푸시 알림" 라벨 + ON/OFF 토글 |
| 2 | 마케팅 알림 | "마케팅 정보 수신" 라벨 + ON/OFF 토글 + 동의 안내 텍스트 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/getNotificationSettings` | POST | `{}` | `{ response, pushEnabled, marketingEnabled }` |
| `/api/member/updateNotificationSettings` | POST | `{ pushEnabled, marketingEnabled }` | `{ response, message }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 토글 변경 | 즉시 API 호출 (낙관적 업데이트). 실패 시 이전 상태로 롤백 + 에러 알럿 |

---

### 3-2-5. 회원탈퇴 (슬라이드 S306)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/info/withdraw` |
| Client Component | `app/[locale]/my-menu/info/withdraw/_components/MemberWithdrawForm.js` |
| 화면설계서 | S306 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "회원탈퇴" |
| 1 | 유의사항 | 탈퇴 시 유의사항 리스트 (코인 소멸, 거래정보 보관 등) |
| 2 | 비밀번호 확인 | 본인 확인용 비밀번호 입력 + Eye 토글 |
| 3 | 탈퇴 사유 선택 | 라디오 버튼 또는 드롭다운 (복수 선택 불가) |
| 4 | 탈퇴하기 버튼 | 빨간색 또는 회색 풀폭 버튼 |

#### 탈퇴 유의사항

| # | 유의사항 |
|---|---------|
| 1 | 보유 중인 코인은 전액 소멸되며 복구할 수 없습니다. |
| 2 | 거래 관련 정보는 관련 법령에 따라 일정 기간 보관됩니다. |
| 3 | 탈퇴 후 동일 이메일로 재가입이 제한될 수 있습니다. |
| 4 | 작성한 후기, 문의 내역은 삭제되지 않을 수 있습니다. |

#### 탈퇴 사유 옵션

| 코드 | 사유 |
|------|------|
| `not_using` | 서비스를 이용하지 않아서 |
| `not_satisfied` | 서비스에 만족하지 못해서 |
| `privacy` | 개인정보 보호를 위해 |
| `re_register` | 다른 계정으로 재가입하려고 |
| `other` | 기타 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 비밀번호 미입력 | "비밀번호를 입력해주세요." | 에러 |
| 비밀번호 불일치 | "비밀번호가 올바르지 않습니다." | 에러 |
| 탈퇴 사유 미선택 | "탈퇴 사유를 선택해주세요." | 에러 |
| 탈퇴 최종 확인 | "정말 탈퇴하시겠습니까? 보유 코인이 모두 소멸됩니다." | Alert (확인/취소) |
| 탈퇴 완료 | "회원 탈퇴가 완료되었습니다." | Alert → 로그인 페이지 이동 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/withdraw` | POST | `{ password, reason }` | `{ response, message }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 탈퇴하기 클릭 | 클라이언트 유효성 → "정말 탈퇴하시겠습니까?" Alert 표시 |
| Alert 확인 | 탈퇴 API 호출 → 성공 시 로그인 상태 초기화 + 로그인 페이지 이동 |
| Alert 취소 | Alert 닫기, 탈퇴 미진행 |

---

### 3-3. VIP 혜택 (슬라이드 S307~S309)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/vip` |
| Server Component | `app/[locale]/my-menu/vip/page.js` |
| Client Component | `app/[locale]/my-menu/vip/_components/VipBenefitsMain.js` |
| 화면설계서 | S307~S309 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "VIP 혜택" |
| 1 | 탭 | VIP혜택 / 쿠폰함 (2개 탭) |
| 2 | 월별 혜택 | 기준 기간 표시 + 현재 등급 배지 |
| 3 | 리워드 코인 | 다음 달 1일 지급 예정 코인 수량 표시 |
| 4 | 지급 내역 | 과거 VIP 리워드 코인 지급 이력 리스트 |
| 5 | VIP 혜택 안내 | 월 결제 금액 기준 등급 산정 테이블 |

#### VIP 등급 체계

| 등급 | 월 결제 기준 (추정) | 리워드 코인 (추정) |
|------|-------------------|-------------------|
| 일반 | 기준 미달 | 없음 |
| VIP | 월 N만원 이상 | 월 X코인 |
| VVIP | 월 M만원 이상 | 월 Y코인 |

- 등급 산정 기준: 전월 결제 금액 합산 기준, 매월 1일 자동 재산정.
- 리워드 코인: 매월 1일 자동 지급, 지급 코인은 유효기간 있음.

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/getVipInfo` | POST | `{ locale }` | `{ response, grade, period, rewardCoin, rewardDate, history, gradeTable }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| VIP혜택 탭 클릭 | VIP 혜택 내용 표시 |
| 쿠폰함 탭 클릭 | `/[locale]/my-menu/coupon`으로 이동 (또는 탭 내 전환) |

---

### 3-4. 쿠폰함 (슬라이드 S310~S313)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/coupon` |
| Server Component | `app/[locale]/my-menu/coupon/page.js` |
| Client Component | `app/[locale]/my-menu/coupon/_components/CouponBoxMain.js` |
| 화면설계서 | S310~S313 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "쿠폰함" |
| 1 | 쿠폰코드 등록 | input 필드 + "등록" 버튼 (코드 형식: NXHXE-INM4U-10368-250922) |
| 2 | 탭 | 사용가능 / 지난쿠폰 (2개 탭) |
| 3 | 쿠폰 리스트 | 쿠폰 카드 리스트 — 쿠폰명, 할인내용, 유효기간, 사용조건 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 쿠폰코드 미입력 | "쿠폰 코드를 입력해주세요." | 에러 |
| 유효하지 않은 코드 | "유효하지 않은 쿠폰 코드입니다." | 에러 |
| 만료된 쿠폰 | "사용기간이 만료된 쿠폰입니다." | 에러 |
| 이미 사용한 쿠폰 | "이미 사용한 쿠폰입니다." | 에러 |
| 이미 등록된 쿠폰 | "이미 등록된 쿠폰입니다." | 에러 |
| 등록 성공 | "쿠폰이 등록되었습니다." | 성공 (알럿) |

#### 상태 관리

- 로컬 상태:
  - `couponCode` — 쿠폰코드 입력값 (string)
  - `activeTab` — 'available' | 'expired'
  - `coupons` — 쿠폰 리스트 (array)
  - `isSubmitting` — 등록 API 호출 중 (boolean)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/coupon/getCoupons` | POST | `{ type: 'available' \| 'expired', offset, limit }` | `{ response, coupons, total }` |
| `/api/coupon/register` | POST | `{ code }` | `{ response, message, coupon? }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 쿠폰코드 등록 버튼 | 클라이언트 미입력 확인 → 서버 API 호출 → 결과 메시지 |
| 사용가능 탭 | 사용 가능한 쿠폰 리스트 조회 |
| 지난쿠폰 탭 | 만료/사용 완료 쿠폰 리스트 조회 |

#### 쿠폰 카드 구성

| 필드 | 설명 |
|------|------|
| 쿠폰명 | 쿠폰 이름 |
| 할인 내용 | 할인 금액 또는 할인율 |
| 유효기간 | YYYY.MM.DD ~ YYYY.MM.DD |
| 사용 조건 | 최소 결제 금액 등 |
| 사용 상태 | 사용가능 / 사용완료 / 만료 |

---

### 3-5. 상담내역 (슬라이드 S314~S315)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/consult-history` |
| Server Component | `app/[locale]/my-menu/consult-history/page.js` |
| Client Component | `app/[locale]/my-menu/consult-history/_components/ConsultHistoryMain.js` |
| 화면설계서 | S314~S315 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "상담내역" |
| 1 | 기간 필터 | PeriodFilter — 1개월 / 3개월 / 6개월 탭 |
| 2 | 상담내역 리스트 | 카드 리스트 — 상담사 닉네임, 상담유형(전화/채팅), 상담시간, 상담일시 |
| 3 | 빈 상태 | 내역이 없을 때 ListEmpty 컴포넌트 |

#### 상담내역 카드 구성

| 필드 | 설명 |
|------|------|
| 상담사 닉네임 | 상담사 이름 (카타카나 표기 포함 — ja 로케일) |
| 상담 유형 | 전화상담 / 채팅상담 |
| 상담 시간 | MM:SS 또는 HH:MM:SS |
| 상담 일시 | YYYY.MM.DD HH:MM |
| 상세보기 | 코인상담에만 상세보기 링크 표시 |

#### 상담내역 상세 (S315)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/consult-history/[id]` |
| 진입 조건 | 코인상담 항목만 상세보기 가능 |

#### 상세보기 항목

| 필드 | 설명 |
|------|------|
| 상담사 정보 | 닉네임, 프로필 이미지 |
| 상담 유형 | 전화상담 / 채팅상담 |
| 상담 일시 | 시작시간 ~ 종료시간 |
| 상담 시간 | 총 상담 시간 |
| 사용 코인 | 과금된 코인 수 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/member/getConsultHistory` | POST | `{ period: '1m' \| '3m' \| '6m', offset, limit }` | `{ response, items, total }` |
| `/api/member/getConsultDetail` | POST | `{ historyId }` | `{ response, detail }` |

---

### 3-6. 코인충전/사용내역 (슬라이드 S316~S320)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/coin-history` |
| Server Component | `app/[locale]/my-menu/coin-history/page.js` |
| Client Component | `app/[locale]/my-menu/coin-history/_components/CoinHistoryMain.js` |
| 화면설계서 | S316~S320 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "코인충전/사용내역" |
| 1 | 나의 코인 | 현재 보유코인 표시 + "코인충전" 링크 |
| 2 | 기간 필터 | PeriodFilter — 1개월 / 3개월 / 6개월 탭 |
| 3 | 코인내역 리스트 | 카드 리스트 — 구분(충전/지급/사용), 코인 수량(+/-), 잔액, 일시, 설명 |
| 4 | 빈 상태 | 내역이 없을 때 ListEmpty 컴포넌트 |

#### 코인내역 구분

| 구분 | 부호 | 설명 | 예시 |
|------|------|------|------|
| 충전 | + | 결제로 충전한 코인 | +10,000 코인 |
| 지급 | + | VIP 리워드, 이벤트 등으로 지급된 코인 | +500 코인 (VIP 리워드) |
| 사용 | - | 상담 이용으로 사용된 코인 | -3,000 코인 (전화상담) |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/coin/getHistory` | POST | `{ period, offset, limit }` | `{ response, balance, items, total }` |
| `/api/coin/getHistoryDetail` | POST | `{ historyId }` | `{ response, detail }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 기간 필터 변경 | 해당 기간 내역 재조회 |
| 코인충전 링크 | `/[locale]/coin-charging`으로 이동 |
| 상세내역 항목 클릭 | 바텀시트 또는 상세 표시 (충전: 결제정보, 사용: 상담정보) |

---

### 3-7. 결제내역 (슬라이드 S321~S324)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/payment-history` |
| Server Component | `app/[locale]/my-menu/payment-history/page.js` |
| Client Component | `app/[locale]/my-menu/payment-history/_components/PaymentHistoryMain.js` |
| 화면설계서 | S321~S324 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "결제내역" |
| 1 | 기간 필터 | PeriodFilter — 1개월 / 3개월 / 6개월 탭 |
| 2 | 결제내역 리스트 | 카드 리스트 — 구분(코인충전/환불), 결제금액, 결제일시 |
| 3 | 빈 상태 | 내역이 없을 때 ListEmpty 컴포넌트 |

#### 결제내역 카드 구성

| 필드 | 설명 |
|------|------|
| 구분 | 코인충전 / 환불 |
| 결제 상품 | 충전코인 수량 |
| 결제 금액 | 국가별 통화 표시 |
| 결제 일시 | YYYY.MM.DD HH:MM |
| 결제 상태 | 완료 / 취소 / 환불 |

#### 결제 상세 (S323~S324)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/payment-history/[id]` |

| 필드 | 설명 |
|------|------|
| 결제 상품 | 충전코인 수량 |
| 결제 일시 | YYYY.MM.DD HH:MM:SS |
| 결제 방법 | 신용카드, 네이버페이 등 |
| 결제 금액 | 국가별 통화 표시 |
| 결제 상태 | 완료 / 취소 / 환불 |
| 환불 가능 여부 | 환불 버튼 또는 "환불 불가" 안내 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/payment/getHistory` | POST | `{ period, offset, limit }` | `{ response, items, total }` |
| `/api/payment/getDetail` | POST | `{ paymentId }` | `{ response, detail }` |

---

### 3-8. 채팅상담 (슬라이드 S325~S326)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/chat-consult` |
| Server Component | `app/[locale]/my-menu/chat-consult/page.js` |
| Client Component | `app/[locale]/my-menu/chat-consult/_components/ChatConsultMain.js` |
| 화면설계서 | S325~S326 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "채팅상담" |
| 1 | 안내 텍스트 | "상담내용은 1주일 후 자동 삭제됩니다." |
| 2 | 채팅방 리스트 | 채팅방 카드 리스트 — 상담사 프로필 이미지, 닉네임, 마지막 메시지, 시간 |
| 3 | 빈 상태 | 채팅 내역이 없을 때 ListEmpty 컴포넌트 |

#### 채팅방 카드 구성

| 필드 | 설명 |
|------|------|
| 상담사 프로필 이미지 | 원형 썸네일 |
| 상담사 닉네임 | 닉네임 (카타카나 표기 — ja 로케일) |
| 마지막 메시지 | 최근 메시지 프리뷰 (1줄 말줄임) |
| 시간 | 마지막 메시지 시간 (오늘이면 HH:MM, 이전이면 MM.DD) |
| 읽지 않은 메시지 | 안읽음 뱃지 (숫자) |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 자동 삭제 | 상담 완료 후 1주일(7일)이 지나면 채팅 내용이 자동 삭제됨 |
| 채팅방 진입 | 채팅방 카드 클릭 시 채팅상담 도메인(`/chat-consultation`)의 채팅방으로 이동 |
| 정렬 | 최신 메시지 순 내림차순 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/chat/getRoomList` | POST | `{ offset, limit }` | `{ response, rooms, total }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 채팅방 클릭 | `/[locale]/chat-consultation/room/[roomId]`로 이동 (채팅상담 도메인) |

---

### 3-9. 나의 후기 (슬라이드 S327~S335)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/my-review` |
| Server Component | `app/[locale]/my-menu/my-review/page.js` |
| Client Component | `app/[locale]/my-menu/my-review/_components/MyReviewMain.js` |
| 화면설계서 | S327~S335 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "나의 후기" |
| 1 | 탭 | 작성가능 / 작성완료 (2개 탭) |
| 2-A | 작성가능 리스트 | 후기 작성 가능한 상담 건 리스트 — 상담사 닉네임, 상담일시, "후기쓰기" 버튼 |
| 2-B | 작성완료 리스트 | 작성 완료된 후기 리스트 — 상담사 닉네임, 별점, 후기 텍스트, 작성일 |
| 3 | 후기 코인 안내 | 후기 작성 시 지급되는 코인 안내 |
| 4 | 빈 상태 | 해당 탭에 내역이 없을 때 ListEmpty |

#### 후기 코인 지급 기준

| 후기 유형 | 지급 코인 |
|----------|----------|
| 일반 후기 (텍스트) | 500 코인 |
| 손글씨 후기 (이미지) | 1,000 코인 |
| 베스트 후기 (운영 선정) | 5,000 코인 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/review/getWritable` | POST | `{ offset, limit }` | `{ response, items, total }` |
| `/api/review/getMyReviews` | POST | `{ offset, limit }` | `{ response, items, total }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 작성가능 탭 | 후기 작성 가능 목록 조회 |
| 작성완료 탭 | 작성 완료 후기 목록 조회 |
| 후기쓰기 버튼 | `/[locale]/my-menu/my-review/write/[counselorId]`로 이동 |

---

### 3-9-1. 후기 작성 (슬라이드 S328~S335)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/my-review/write/[counselorId]` |
| Client Component | `app/[locale]/my-menu/my-review/write/[counselorId]/_components/ReviewWriteForm.js` |
| 화면설계서 | S328~S335 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "후기 작성" |
| 1 | 상담사 정보 | 상담사 프로필 이미지 + 닉네임 |
| 2 | 만족도 별점 | 1~5 별점 선택 (탭 또는 스와이프) |
| 3 | 상담 분야 추천 | 분야 태그 다중 선택 (연애운, 가족, 건강 등) |
| 4 | 상담 스타일 평가 | 스타일 태그 다중 선택 (정확해요, 편안해요, 친절해요 등) |
| 5 | 후기 텍스트 | textarea — 10자 이상 필수, 글자 수 카운터 |
| 6 | 이미지 첨부 | 이미지 업로드 버튼 + 미리보기 (최대 3개) |
| 7 | 운영 정책 동의 | 체크박스 — "후기 운영 정책에 동의합니다" |
| 8 | 등록 버튼 | 보라색 풀폭 버튼 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 별점 미선택 | "만족도를 선택해주세요." | Alert |
| 상담 분야 미선택 | "상담 분야를 선택해주세요." | Alert |
| 상담 스타일 미선택 | "상담 스타일을 선택해주세요." | Alert |
| 후기 미입력 | "후기를 입력해주세요." | Alert |
| 후기 10자 미만 | "후기는 10자 이상 입력해주세요." | Alert |
| 이미지 3개 초과 | "이미지는 최대 3개까지 첨부할 수 있습니다." | Alert |
| 운영 정책 미동의 | "후기 운영 정책에 동의해주세요." | Alert |
| 등록 성공 | "후기가 등록되었습니다. {코인}코인이 지급되었습니다." | Alert → 목록 이동 |

#### 상태 관리

- 로컬 상태:
  - `rating` — 별점 (1~5, number | null)
  - `selectedFields` — 선택된 상담 분야 배열 (string[])
  - `selectedStyles` — 선택된 상담 스타일 배열 (string[])
  - `reviewText` — 후기 텍스트 (string)
  - `images` — 첨부 이미지 파일 배열 (File[], 최대 3개)
  - `imagePreviews` — 이미지 미리보기 URL 배열 (string[])
  - `agreePolicy` — 운영 정책 동의 (boolean)
  - `isSubmitting` — 등록 API 호출 중 (boolean)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/review/getCounselorInfo` | POST | `{ counselorId }` | `{ response, counselor }` |
| `/api/review/submit` | POST | FormData: `{ counselorId, historyId, rating, fields, styles, text, images[] }` | `{ response, rewardCoin, message }` |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 이미지 제한 | 최대 3개, 파일별 크기 제한 (추정 5MB) |
| 이미지 형식 | JPG, PNG, GIF (추정) |
| 후기 수정 | 작성 후 수정 불가 (추정 — 미확정) |
| 코인 지급 | 등록 성공 시 후기 유형에 따라 즉시 또는 관리자 확인 후 지급 |

---

### 3-10. 나의 1:1 문의 (슬라이드 S336~S337)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/my-inquiry` |
| Server Component | `app/[locale]/my-menu/my-inquiry/page.js` |
| Client Component | `app/[locale]/my-menu/my-inquiry/_components/MyInquiryMain.js` |
| 화면설계서 | S336~S337 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "나의 1:1 문의" |
| 1 | 탭 | 답변대기 / 답변완료 (2개 탭) |
| 2 | 문의 리스트 | 문의 카드 리스트 — 유형, 제목, 작성일, 답변상태 |
| 3 | 빈 상태 | 문의 내역이 없을 때 ListEmpty |

#### 문의 카드 구성

| 필드 | 설명 |
|------|------|
| 문의 유형 | 일반 / 환불 / 개선 / 불량상담 신고 |
| 제목 | 문의 제목 (1줄 말줄임) |
| 작성일 | YYYY.MM.DD |
| 답변 상태 | 답변대기 / 답변완료 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/inquiry/getMyInquiries` | POST | `{ type: 'waiting' \| 'answered', offset, limit }` | `{ response, items, total }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 답변대기 탭 | 답변대기 목록 조회 |
| 답변완료 탭 | 답변완료 목록 조회 |
| 문의 카드 클릭 | 문의 상세 바텀시트 또는 페이지 표시 (제목, 내용, 이미지, 답변) |

---

### 3-11. 코인 자동충전 (슬라이드 S338~S345)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/auto-charge` |
| Server Component | `app/[locale]/my-menu/auto-charge/page.js` |
| Client Component | `app/[locale]/my-menu/auto-charge/_components/AutoChargeMain.js` |
| 화면설계서 | S338~S345 |

#### UI 섹션 — 자동충전 설정 (S338~S339)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "코인 자동충전" |
| 1 | 자동충전 안내 | 자동충전 서비스 설명 텍스트 |
| 2 | 결제 금액 선택 | 라디오 버튼 그룹 — 자동충전 시 결제할 금액 옵션 |
| 3 | 기준 잔액 설정 | 보유코인이 이 금액 이하가 되면 자동충전 실행 |
| 4 | VIP 혜택 안내 | VIP 혜택 간략 안내 + 상세 링크 |
| 5 | 카드 등록 버튼 | 보라색 풀폭 버튼 → 카드 등록 페이지 이동 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/autocharge/getSettings` | POST | `{}` | `{ response, isEnabled, chargeAmount, thresholdBalance, registeredCard }` |
| `/api/autocharge/updateSettings` | POST | `{ chargeAmount, thresholdBalance }` | `{ response, message }` |
| `/api/autocharge/toggleStatus` | POST | `{ isEnabled }` | `{ response, message }` |

---

### 3-11-1. 결제카드 등록 (슬라이드 S340~S342)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/auto-charge/card-register` |
| Client Component | `app/[locale]/my-menu/auto-charge/card-register/_components/CardRegisterForm.js` |
| 화면설계서 | S340~S342 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "결제카드 등록" |
| 1 | 카드 유형 선택 | 개인 / 법인 (2개 탭 또는 라디오) |
| 2 | 카드번호 | input (16자리, 4자리씩 분리 또는 자동 하이픈) |
| 3 | 유효기간 | MM / YY 2개 input |
| 4 | CVC | input (3~4자리, type=password) |
| 5-A | 생년월일 (개인) | YYMMDD input (개인 선택 시 표시) |
| 5-B | 사업자번호 (법인) | 사업자등록번호 input (법인 선택 시 표시) |
| 6 | 등록 버튼 | 보라색 풀폭 버튼 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 카드번호 미입력 | "카드번호를 입력해주세요." | 에러 |
| 카드번호 형식 오류 | "올바른 카드번호를 입력해주세요." | 에러 |
| 유효기간 미입력 | "유효기간을 입력해주세요." | 에러 |
| 유효기간 만료 | "유효기간이 만료된 카드입니다." | 에러 |
| CVC 미입력 | "CVC를 입력해주세요." | 에러 |
| CVC 형식 오류 | "올바른 CVC를 입력해주세요." | 에러 |
| 생년월일 미입력 (개인) | "생년월일을 입력해주세요." | 에러 |
| 생년월일 형식 오류 | "올바른 생년월일을 입력해주세요." | 에러 |
| 사업자번호 미입력 (법인) | "사업자번호를 입력해주세요." | 에러 |
| 사업자번호 형식 오류 | "올바른 사업자번호를 입력해주세요." | 에러 |
| 카드 등록 실패 | "카드 등록에 실패했습니다. 카드 정보를 확인해주세요." | 에러 (알럿) |
| 카드 등록 성공 | "카드가 등록되었습니다." | 성공 (알럿) |

#### 상태 관리

- 로컬 상태:
  - `cardType` — 'personal' | 'business'
  - `cardNumber` — 카드번호 (string)
  - `expiryMonth` — 유효기간 월 (string)
  - `expiryYear` — 유효기간 년 (string)
  - `cvc` — CVC (string)
  - `birthDate` — 생년월일 (string, 개인)
  - `businessNumber` — 사업자번호 (string, 법인)
  - `errors` — 필드별 에러 메시지 객체

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/autocharge/registerCard` | POST | `{ cardType, cardNumber, expiryMonth, expiryYear, cvc, birthDate?, businessNumber? }` | `{ response, message, cardId }` |

---

### 3-11-2. 자동충전 관리 (슬라이드 S343~S345)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/auto-charge/manage` |
| Client Component | `app/[locale]/my-menu/auto-charge/manage/_components/AutoChargeManageMain.js` |
| 화면설계서 | S343~S345 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "자동충전 관리" |
| 1 | 자동충전 상태 | ON/OFF 토글 |
| 2 | 등록된 카드 정보 | 카드번호 마스킹 (****-****-****-1234) + 카드사명 |
| 3 | 충전 설정 | 결제 금액 + 기준 잔액 표시 |
| 4 | 카드 변경 버튼 | 다른 카드로 변경 → 카드 등록 페이지 |
| 5 | 카드 삭제 버튼 | 등록 카드 삭제 (삭제 시 자동충전 OFF) |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 카드 삭제 확인 | "등록된 카드를 삭제하시겠습니까? 자동충전이 해제됩니다." | Alert (확인/취소) |
| 카드 삭제 완료 | "카드가 삭제되었습니다." | 성공 |
| 자동충전 ON | "자동충전이 설정되었습니다." | 성공 |
| 자동충전 OFF | "자동충전이 해제되었습니다." | 성공 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/autocharge/getManageInfo` | POST | `{}` | `{ response, isEnabled, card, chargeAmount, thresholdBalance }` |
| `/api/autocharge/deleteCard` | POST | `{ cardId }` | `{ response, message }` |
| `/api/autocharge/toggleStatus` | POST | `{ isEnabled }` | `{ response, message }` |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 카드 삭제 시 자동충전 OFF | 등록 카드 삭제 시 자동충전이 자동으로 OFF됨 |
| 카드 미등록 시 ON 불가 | 등록된 카드가 없으면 자동충전 ON 토글 비활성 |
| 카드 변경 | 기존 카드 삭제 + 새 카드 등록 흐름 |

---

### 3-12. 알림내역 (슬라이드 S346~S350)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/notification` |
| Server Component | `app/[locale]/my-menu/notification/page.js` |
| Client Component | `app/[locale]/my-menu/notification/_components/NotificationHistoryMain.js` |
| 화면설계서 | S346~S350 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "알림내역" |
| 1 | 탭 | 전체 / 공지사항 / 활동알림 / 이벤트 (4개 탭) |
| 2 | 알림 리스트 | 알림 카드 리스트 — 아이콘, 제목, 내용(프리뷰), 시간 |
| 3 | 빈 상태 | 알림이 없을 때 ListEmpty |

#### 알림 메시지 유형

| 유형 | 카테고리 | 메시지 예시 |
|------|---------|-----------|
| 1:1 문의 답변 | 활동알림 | "1:1 문의에 답변이 등록되었습니다." |
| 후기 등록 안내 | 활동알림 | "후기를 작성하고 코인을 받아보세요." |
| 후기 답변 | 활동알림 | "작성하신 후기에 상담사가 답변했습니다." |
| 접속 알림 | 활동알림 | "{상담사닉네임}님이 접속하였습니다." |
| 카카오 플러스친구 | 공지사항 | 카카오 플러스친구 추가 안내 |
| 이벤트 알림 | 이벤트 | 진행 중 이벤트 안내 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/notification/getList` | POST | `{ category: 'all' \| 'notice' \| 'activity' \| 'event', offset, limit }` | `{ response, items, total, unreadCount }` |
| `/api/notification/markRead` | POST | `{ notificationIds: number[] }` | `{ response }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 탭 전환 | 해당 카테고리 알림 재조회 |
| 알림 카드 클릭 | 읽음 처리 + 연결된 페이지로 이동 (1:1 문의 답변 → 문의 상세, 접속 알림 → 상담사 프로필 등) |
| 스크롤 | 무한 스크롤 또는 "더보기" 버튼으로 페이지네이션 |

---

### 3-13. 고객센터 (슬라이드 S351~S359)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/customer-service` |
| Server Component | `app/[locale]/my-menu/customer-service/page.js` |
| Client Component | `app/[locale]/my-menu/customer-service/_components/CustomerServiceMain.js` |
| 화면설계서 | S351~S359 |

#### UI 섹션 — 고객센터 메인 (S351~S352)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "고객센터" |
| 1 | 전화상담 이용안내 | 상담 가능 시간, 전화번호 안내 |
| 2 | 채팅상담 이용안내 | 채팅 상담 가능 시간 안내 |
| 3 | 메뉴 리스트 | FAQ, 1:1 문의, 공지사항 링크 |

---

### 3-13-1. FAQ (슬라이드 S353~S355)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/customer-service/faq` |
| Client Component | `app/[locale]/my-menu/customer-service/faq/_components/FaqMain.js` |
| 화면설계서 | S353~S355 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "FAQ" |
| 1 | 카테고리 탭 | 회원가입 / 결제환불 / 전화상담 / 채팅상담 (4개 탭) |
| 2 | FAQ 리스트 | 아코디언 방식 — 질문 클릭 시 답변 펼침/접힘 |
| 3 | 빈 상태 | 해당 카테고리에 FAQ가 없을 때 안내 |

#### FAQ 카테고리

| 코드 | 카테고리명 |
|------|----------|
| `join` | 회원가입 |
| `payment` | 결제환불 |
| `call` | 전화상담 |
| `chat` | 채팅상담 |

#### 아코디언 동작

| 동작 | 설명 |
|------|------|
| 질문 클릭 | 해당 답변 펼침. 이전 열린 답변은 자동 접힘 (단일 열림) 또는 유지 (다중 열림) — 미확정 |
| 열린 질문 재클릭 | 답변 접힘 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/customer/getFaqList` | POST | `{ category, locale }` | `{ response, faqs }` |

---

### 3-13-2. 1:1 문의 작성 (슬라이드 S356~S357)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/customer-service/inquiry/write` |
| Client Component | `app/[locale]/my-menu/customer-service/inquiry/write/_components/InquiryWriteForm.js` |
| 화면설계서 | S356~S357 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "1:1 문의" |
| 1 | 문의 유형 | 드롭다운 셀렉트 (일반/환불/개선/불량상담 신고) |
| 2 | 제목 | input 필드 |
| 3 | 내용 | textarea (최대 글자 수 제한 — 추정 1,000자) |
| 4 | 이미지 첨부 | 이미지 업로드 버튼 + 미리보기 (최대 3개) |
| 5 | 답변 이메일 전달 | "답변을 이메일로도 전달받겠습니다" 체크박스 |
| 6 | 등록 버튼 | 보라색 풀폭 버튼 |

#### 문의 유형 옵션

| 코드 | 유형명 |
|------|--------|
| `general` | 일반 문의 |
| `refund` | 환불 문의 |
| `improvement` | 서비스 개선 제안 |
| `report` | 불량 상담 신고 |

#### 유효성 메시지

| 조건 | 메시지 | 타입 |
|------|--------|------|
| 문의 유형 미선택 | "문의 유형을 선택해주세요." | 에러 |
| 제목 미입력 | "제목을 입력해주세요." | 에러 |
| 내용 미입력 | "내용을 입력해주세요." | 에러 |
| 이미지 3개 초과 | "이미지는 최대 3개까지 첨부할 수 있습니다." | Alert |
| 등록 성공 | "문의가 등록되었습니다." | Alert → 목록 이동 |

#### 상태 관리

- 로컬 상태:
  - `inquiryType` — 선택된 문의 유형 (string | null)
  - `title` — 제목 (string)
  - `content` — 내용 (string)
  - `images` — 첨부 이미지 파일 배열 (File[], 최대 3개)
  - `imagePreviews` — 이미지 미리보기 URL 배열 (string[])
  - `sendEmail` — 이메일 전달 여부 (boolean)
  - `isSubmitting` — 등록 API 호출 중 (boolean)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/inquiry/submit` | POST | FormData: `{ type, title, content, images[], sendEmail }` | `{ response, message, inquiryId }` |

---

### 3-13-3. 공지사항 (슬라이드 S358~S359)

| 항목 | 내용 |
|------|------|
| 라우트(리스트) | `/[locale]/my-menu/customer-service/notice` |
| 라우트(상세) | `/[locale]/my-menu/customer-service/notice/[id]` |
| Client Component (리스트) | `app/[locale]/my-menu/customer-service/notice/_components/NoticeListMain.js` |
| Client Component (상세) | `app/[locale]/my-menu/customer-service/notice/[id]/_components/NoticeDetailMain.js` |
| 화면설계서 | S358~S359 |

#### UI 섹션 — 공지사항 리스트

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "공지사항" |
| 1 | 공지사항 리스트 | 카드 리스트 — 제목, 작성일, 조회수 |
| 2 | 빈 상태 | 공지사항이 없을 때 ListEmpty |

#### UI 섹션 — 공지사항 상세

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "공지사항" |
| 1 | 제목 | 공지사항 제목 |
| 2 | 메타 정보 | 작성일 + 조회수 |
| 3 | 본문 | HTML 본문 (DOMPurify XSS 방어 필수) |
| 4 | 이전/다음 | 이전글, 다음글 네비게이션 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/customer/getNoticeList` | POST | `{ offset, limit, locale }` | `{ response, notices, total }` |
| `/api/customer/getNoticeDetail` | POST | `{ noticeId }` | `{ response, notice, prevId, nextId }` |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| HTML 본문 XSS 방어 | 서버에서 받은 HTML 본문은 반드시 DOMPurify로 sanitize 후 렌더링 |
| 조회수 카운트 | 상세 페이지 진입 시 서버에서 자동 증가 (프론트 별도 호출 불필요) |

---

### 3-14. 이벤트 (슬라이드 S360)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/my-menu/event` |
| Server Component | `app/[locale]/my-menu/event/page.js` |
| Client Component | `app/[locale]/my-menu/event/_components/EventListMain.js` |
| 화면설계서 | S360 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "이벤트" |
| 1 | 이벤트 배너 리스트 | 이벤트 배너 이미지 리스트 (세로 나열) |
| 2 | 빈 상태 | 진행 중 이벤트가 없을 때 ListEmpty |

#### 이벤트 카드 구성

| 필드 | 설명 |
|------|------|
| 배너 이미지 | 이벤트 배너 이미지 (풀폭) |
| 이벤트명 | 이벤트 제목 |
| 기간 | 시작일 ~ 종료일 |
| 상태 | 진행중 / 종료 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/event/getList` | POST | `{ offset, limit, locale }` | `{ response, events, total }` |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 이벤트 배너 클릭 | 이벤트 상세 페이지 또는 외부 URL로 이동 |

---

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 사용 페이지 | Props |
|---------|-----------|-------|
| `PageNavBar` | 전체 | `locale`, `title`, `homeLabel`, `showBack` |
| `PeriodFilter` | 상담내역, 코인내역, 결제내역 | `selected`, `onSelect`, `labels` |
| `ListEmpty` | 내역 페이지 전체 | `message` |
| `TabBar` | VIP/쿠폰, 나의후기, 나의문의, 알림내역, FAQ | `tabs`, `activeTab`, `onTabChange` |
| `AlertModal` | 회원탈퇴, 카드삭제 등 | `title`, `message`, `onConfirm`, `onCancel` |
| `ImageUploader` | 후기 작성, 1:1 문의 작성 | `images`, `onAdd`, `onRemove`, `maxCount` |
| `EyeToggle` | 비밀번호 변경, 회원탈퇴 | `isVisible`, `onToggle` |
| `StarRating` | 후기 작성 | `rating`, `onRate`, `size` |
| `CoinDisplay` | 마이메뉴 홈, 코인내역 | `balance`, `locale` |

---

## 5. API 연동 상세

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


### 5-1. API Route (프록시 레이어)

| 프론트 경로 | 외부 API 경로 (추정) | 설명 |
|-----------|-------------------|------|
| `/api/member/getMyMenuInfo` | `/api/member/getMyMenuInfo` | 마이메뉴 홈 데이터 |
| `/api/member/getInfo` | `/api/member/getInfo` | 회원정보 조회 |
| `/api/member/checkNickname` | `/api/member/checkNickname` | 닉네임 중복확인 |
| `/api/member/updateNickname` | `/api/member/updateNickname` | 닉네임 변경 |
| `/api/member/sendPhoneCode` | `/api/member/sendPhoneCode` | 인증번호 발송 |
| `/api/member/verifyPhoneCode` | `/api/member/verifyPhoneCode` | 인증번호 확인 |
| `/api/member/updatePhone` | `/api/member/updatePhone` | 휴대폰번호 변경 |
| `/api/member/updatePassword` | `/api/member/updatePassword` | 비밀번호 변경 |
| `/api/member/getNotificationSettings` | `/api/member/getNotificationSettings` | 알림 설정 조회 |
| `/api/member/updateNotificationSettings` | `/api/member/updateNotificationSettings` | 알림 설정 변경 |
| `/api/member/withdraw` | `/api/member/withdraw` | 회원탈퇴 |
| `/api/member/getVipInfo` | `/api/member/getVipInfo` | VIP 정보 조회 |
| `/api/member/getConsultHistory` | `/api/member/getConsultHistory` | 상담내역 조회 |
| `/api/member/getConsultDetail` | `/api/member/getConsultDetail` | 상담 상세 |
| `/api/coin/getHistory` | `/api/coin/getHistory` | 코인내역 조회 |
| `/api/coin/getHistoryDetail` | `/api/coin/getHistoryDetail` | 코인내역 상세 |
| `/api/payment/getHistory` | `/api/payment/getHistory` | 결제내역 조회 |
| `/api/payment/getDetail` | `/api/payment/getDetail` | 결제 상세 |
| `/api/chat/getRoomList` | `/api/chat/getRoomList` | 채팅방 목록 |
| `/api/review/getWritable` | `/api/review/getWritable` | 작성 가능 후기 |
| `/api/review/getMyReviews` | `/api/review/getMyReviews` | 내 후기 목록 |
| `/api/review/getCounselorInfo` | `/api/review/getCounselorInfo` | 후기 작성 대상 상담사 |
| `/api/review/submit` | `/api/review/submit` | 후기 등록 |
| `/api/inquiry/getMyInquiries` | `/api/inquiry/getMyInquiries` | 내 문의 목록 |
| `/api/inquiry/submit` | `/api/inquiry/submit` | 문의 등록 |
| `/api/coupon/getCoupons` | `/api/coupon/getCoupons` | 쿠폰 목록 |
| `/api/coupon/register` | `/api/coupon/register` | 쿠폰 등록 |
| `/api/autocharge/getSettings` | `/api/autocharge/getSettings` | 자동충전 설정 조회 |
| `/api/autocharge/updateSettings` | `/api/autocharge/updateSettings` | 자동충전 설정 변경 |
| `/api/autocharge/toggleStatus` | `/api/autocharge/toggleStatus` | 자동충전 ON/OFF |
| `/api/autocharge/registerCard` | `/api/autocharge/registerCard` | 카드 등록 |
| `/api/autocharge/getManageInfo` | `/api/autocharge/getManageInfo` | 자동충전 관리 정보 |
| `/api/autocharge/deleteCard` | `/api/autocharge/deleteCard` | 카드 삭제 |
| `/api/notification/getList` | `/api/notification/getList` | 알림 목록 |
| `/api/notification/markRead` | `/api/notification/markRead` | 읽음 처리 |
| `/api/customer/getFaqList` | `/api/customer/getFaqList` | FAQ 목록 |
| `/api/customer/getNoticeList` | `/api/customer/getNoticeList` | 공지사항 목록 |
| `/api/customer/getNoticeDetail` | `/api/customer/getNoticeDetail` | 공지사항 상세 |
| `/api/event/getList` | `/api/event/getList` | 이벤트 목록 |

### 5-2. 인증 흐름

모든 API(마이메뉴 홈 제외)는 인증 쿠키를 자동으로 전송한다.
서버에서 401 응답 시 프론트에서 `/[locale]/login`으로 리다이렉트한다.

---

## 6. 상태 관리

### 6-1. Zustand 전역 스토어

| 스토어 | 사용 위치 | 상태 |
|--------|---------|------|
| `useAuthStore` | 마이메뉴 홈 (로그인 상태 판별), 회원탈퇴 (로그인 상태 초기화) | `isLoggedIn`, `nickname`, `role` |
| `useCoinStore` | 마이메뉴 홈 (보유코인 표시), 코인내역 (잔액 표시) | `balance`, `setBalance` |

### 6-2. 로컬 상태 요약

대부분의 하위 페이지는 로컬 상태(useState)로 충분하다. 페이지 간 상태 공유가 필요한 경우:

| 상태 | 관리 방법 | 이유 |
|------|---------|------|
| 로그인 여부 | `useAuthStore` | 마이메뉴 홈 + 하위 페이지 전체에서 참조 |
| 보유코인 | `useCoinStore` | 마이메뉴 홈, 코인내역, 코인충전 도메인에서 참조 |
| 각 폼 입력값 | 로컬 `useState` | 페이지 간 공유 불필요 |
| 탭 선택 상태 | 로컬 `useState` | 페이지 내부에서만 사용 |
| 기간 필터 | 로컬 `useState` | 페이지 내부에서만 사용 |

---

## 7. 크로스 도메인 의존성

### 7-1. 의존하는 도메인

| 도메인 | 의존 내용 |
|--------|---------|
| `login` | 비로그인 시 리다이렉트 + returnUrl |
| `join` | 비로그인 시 회원가입 링크 |
| `layout` | PageNavBar, Footer 공유 컴포넌트 |
| `coin-charging` | 코인충전 링크 (마이메뉴 홈, 코인내역) |
| `chat-consultation` | 채팅방 진입 시 채팅상담 도메인으로 이동 |

### 7-2. 피의존 도메인

| 도메인 | 피의존 내용 |
|--------|-----------|
| `phone-consultation` | 상담 완료 후 "나의 후기"에서 후기 작성 유도 |
| `chat-consultation` | 상담 완료 후 "나의 후기"에서 후기 작성 유도, 채팅방 리스트에서 진입 |
| `coin-charging` | 결제 완료 후 결제내역에 반영, VIP 등급 산정에 결제 금액 반영 |

### 7-3. 전역 공유

| 공유 자원 | 사용 도메인 |
|----------|-----------|
| `useAuthStore` | login, join, member-mymenu, counselor-mymenu |
| `useCoinStore` | coin-charging, phone-consultation, chat-consultation, member-mymenu |
| `PeriodFilter` 컴포넌트 | member-mymenu (상담내역/코인내역/결제내역), counselor-mymenu (상담내역) |

---

## 8. 미확정 사항

- [ ] VIP 등급 체계 상세: 등급별 월 결제 기준 금액, 리워드 코인 수량 미확정
- [ ] VIP 등급 수: 일반/VIP/VVIP 3단계인지, 추가 등급이 있는지 미확정
- [ ] 리워드 코인 유효기간: 지급된 리워드 코인의 만료 기간 미확정
- [ ] 쿠폰코드 형식: NXHXE-INM4U-10368-250922 형식이 고정인지, 다른 형식도 있는지 미확정
- [ ] 쿠폰 사용 조건: 최소 결제 금액, 특정 상담 유형 제한 등 상세 조건 미확정
- [ ] 상담내역 상세보기 범위: 코인상담만 상세보기 가능한지, 전체 상담 가능한지 미확정
- [ ] 후기 수정/삭제: 작성 완료 후 수정 또는 삭제가 가능한지 미확정
- [ ] 후기 이미지 파일 제한: 파일당 최대 크기(추정 5MB), 허용 형식(JPG, PNG, GIF) 확정 필요
- [ ] 손글씨 후기 판별 기준: 이미지 첨부 시 자동 판별인지, 사용자가 손글씨 여부를 선택하는지 미확정
- [ ] 베스트 후기 선정 기준: 운영자 수동 선정인지, 자동 선정인지 미확정
- [ ] 1:1 문의 내용 글자수 제한: 추정 1,000자이나 확정 필요
- [ ] 1:1 문의 이미지 파일 제한: 파일당 최대 크기, 허용 형식 확정 필요
- [ ] 자동충전 결제금액 옵션: 코인충전 메인과 동일한 5개 옵션인지, 별도 옵션인지 미확정
- [ ] 자동충전 기준잔액 옵션: 자유 입력인지, 고정 옵션 선택인지 미확정
- [ ] 카드 등록 PG 연동: 어떤 PG사를 통해 카드 등록하는지 미확정
- [ ] 개인/법인 카드 구분 UI: 탭 형태인지 라디오 형태인지 미확정
- [ ] FAQ 아코디언 동작: 단일 열림(하나만 열림)인지 다중 열림(여러 개 동시 열림)인지 미확정
- [ ] 공지사항 HTML 본문 형식: 서버에서 내려주는 HTML 구조 확정 필요 (DOMPurify 적용 범위)
- [ ] 이벤트 상세 페이지: 별도 상세 페이지가 있는지, 외부 URL로만 이동하는지 미확정
- [ ] 알림 실시간 수신: WebSocket/SSE 기반 실시간 알림인지, 페이지 새로고침 시에만 갱신되는지 미확정
- [ ] 알림 읽음 처리 시점: 카드 클릭 시인지, 목록 진입 시 전체 읽음인지 미확정
- [ ] 마이메뉴 홈에서 상담사 마이메뉴 전환 버튼: 상담사 등록 완료 회원에게만 노출되는지, 전체에게 노출되는지 미확정
- [ ] 회원탈퇴 재가입 제한 기간: 탈퇴 후 동일 이메일 재가입까지의 제한 기간 미확정
- [ ] 휴대폰 인증번호 유효시간: 추정 3분이나 확정 필요
- [ ] 비밀번호 변경 시 기존 세션 처리: 변경 후 현재 세션 유지인지, 전체 로그아웃인지 미확정

### v1.1 추가 미확정 (as-built 반영)

- [ ] **#25 [MUST/D] 라우트 패턴 통일**: 화면설계서 v1.0은 `/my-menu/*`, as-built 스캐폴드는 `/mypage/*`. 정식 명칭/URL 결정 후 한쪽으로 통일 필요. (영향: 모든 §3-1~13 라우트, BottomNav 링크, 백엔드 redirect URL)
- [ ] **#26 [HIGH/B] useAuthStore.logout() secureFetch 미사용**: `MyPageContent.handleSignOut`이 호출하는 `logout()`이 직접 `fetch` 사용 → CSRF 토큰 누락. (감사: `2026-04-16-auth-member-api-spec-review.md` 권고안 2)
- [ ] **#27 [HIGH/C] returnUrl 전달**: 비로그인 사용자가 마이페이지 진입 시 `/login?returnUrl=/mypage`로 리다이렉트, 로그인 후 원래 페이지로 복귀
- [ ] **#28 [HIGH/C] 메뉴 하위 라우트 구현**: `/mypage/info`, `/mypage/consult-history`, `/mypage/coin-history`, `/mypage/payment-history`, `/mypage/chat-consult`, `/mypage/my-review`, `/mypage/my-inquiry`, `/mypage/auto-charge`, `/mypage/notification`, `/mypage/customer-service`, `/mypage/event` 모두 페이지 생성 필요
- [ ] **#29 [MEDIUM/C] MOCK_NOTICES → CMS 연동**: `lib/mockNotices.js` 하드코딩 → 공지사항 백엔드 EP 연동 (예: `/api/community/notices`)
- [ ] **#30 [MEDIUM/C] VIP/쿠폰 카드 실데이터**: 현재 `-`/`0` 하드코딩 → `/api/members/vip-status`, `/api/members/coupon-count` 신설 또는 통합 EP 활용
- [ ] **#31 [MEDIUM/D] 비로그인 마이페이지 진입 정책**: as-built는 즉시 `/login` 리다이렉트, 화면설계서 §3-1은 비로그인 안내 UI 노출 — 정책 통일 필요
- [ ] **#32 [LOW/C] 잔액 조회 실시간 갱신**: `get-balance`는 진입 시 1회만 호출. 코인 사용/충전 후 실시간 반영 정책 확정 필요 (Polling/SSE/메인 페이지 복귀 시 재조회)

## 9. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 화면설계서 PPTX(S294~S360) 기반 67 슬라이드 전수 작성 | 명우현 |
| v1.1 | 2026-04-17 | as-built 마이페이지 스캐폴드(`/mypage`, 커밋 `bd5d4ce`) 신규 §3-0 추가. 라우트 패턴 미확정(`/my-menu` vs `/mypage`) 명시 + 미확정 사항 8건 추가(#25~#32 — 라우트 통일/logout secureFetch/returnUrl/메뉴 하위 라우트 구현/MOCK_NOTICES CMS/VIP·쿠폰 실데이터/비로그인 정책/잔액 실시간 갱신). 감사 문서(`2026-04-16-auth-member-api-spec-review.md`) 권고 미반영(#26) HIGH 표기 | 명우현 |
