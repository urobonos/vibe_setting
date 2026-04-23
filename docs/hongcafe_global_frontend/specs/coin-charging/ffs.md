# Frontend Functional Spec — 코인충전

> Source: 화면설계서 PPTX Slides S439~S445, 기본정책 S11~S12
> Status: DRAFT
> Updated: 2026-03-24

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 코인충전 (Coin Charging / Top-up) |
| 사용자 목표 | 보유 코인 잔액을 확인하고, 원하는 금액을 선택하여 국가별 결제수단으로 코인을 충전한다 |
| 퍼블리싱 상태 | 미구현 |
| 기능 연동 상태 | 미연동 (PG사 연동 미구현) |
| i18n 네임스페이스 | `coinCharging`, `coinChargingConfirm`, `coinChargingResult` |
| 지원 로케일 | `en`, `ko`, `ja` |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |

### 비즈니스 모델 핵심

- 코인은 홍카페 서비스 내 가상 화폐로, 전화상담/채팅상담 이용 시 30초당 N코인이 과금된다.
- 사용자는 5개의 고정 금액 옵션 중 하나를 선택하여 충전한다 (자유 금액 입력 불가).
- 국가(locale)에 따라 표시 통화와 결제수단(PG)이 다르다.
- 자동충전 기능은 회원 마이메뉴(S338~S345)에서 별도로 관리하므로 이 도메인 범위 밖이다.

### 충전코인-통화 환산 테이블 (기본정책 S11)

| 충전코인 | 원화 (KR) | 엔화 (JP) | 달러 (US) |
|---------|----------|----------|----------|
| 10,000 | 10,000원 | 1,100円 | $10.00 |
| 30,000 | 30,000원 | 3,300円 | $30.00 |
| 50,000 | 50,000원 | 5,500円 | $50.00 |
| 100,000 | 100,000원 | 11,000円 | $100.00 |
| 300,000 | 300,000원 | 33,000円 | $300.00 |

### 국가별 결제수단 (기본정책 S12)

| 국가 | 결제수단 |
|------|---------|
| KR | 신용카드, 휴대폰결제, 네이버페이, 가상계좌(무통장) |
| JP | 신용카드, Apple Pay, 은행송금 |
| US | 신용카드, UnionPay, PayPal |

### 도메인 흐름 요약

```
코인충전 메인 (/coin-charging)
  ├── 충전금액 선택 (5개 라디오 옵션)
  ├── 결제수단 선택 (국가별 PG 목록)
  └── 결제하기 클릭
        ├── 결제 확인 화면 (주문 요약 + 약관 동의)
        │     └── 결제 진행 클릭
        │           ├── 결제 처리중 (로딩)
        │           ├── 결제 완료 (성공)
        │           ├── 결제 실패 (에러 + 재시도)
        │           └── 결제 취소 (사용자 취소)
        └── 뒤로가기 → 메인으로 복귀
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/coin-charging` | `app/[locale]/coin-charging/page.js` | CoinChargingMain | Server → Client | `coinCharging` |
| `/[locale]/coin-charging/confirm` | `app/[locale]/coin-charging/confirm/page.js` | CoinChargingConfirm | Server → Client | `coinChargingConfirm` |
| `/[locale]/coin-charging/result` | `app/[locale]/coin-charging/result/page.js` | CoinChargingResult | Server → Client | `coinChargingResult` |

### 인증 요구

- 모든 코인충전 라우트는 **로그인 필수**이다.
- 비로그인 상태에서 접근 시 `/[locale]/login`으로 리다이렉트한다.
- 리다이렉트 시 `returnUrl=/[locale]/coin-charging` 쿼리파라미터를 전달하여 로그인 후 복귀할 수 있도록 한다.

---

## 3. 페이지 정의

### 3-1. 코인충전 메인 (슬라이드 S439~S440)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/coin-charging` |
| Server Component | `app/[locale]/coin-charging/page.js` — 메타데이터 생성, labels 객체 구성, 보유코인 초기 조회 |
| Client Component | `app/[locale]/coin-charging/_components/CoinChargingMain.js` |
| 화면설계서 | S439, S440 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, 뒤로가기 + "Charge Coins" + Home 버튼 |
| 1 | 보유코인 표시 | 현재 보유코인 수량 표시 (아이콘 + 숫자, Intl.NumberFormat 포맷) |
| 2 | 충전금액 선택 | 5개 라디오 버튼 그룹: 10,000 / 30,000 / 50,000 / 100,000 / 300,000 코인 |
| 3 | 결제금액 표시 | 선택된 충전금액에 대응하는 국가별 실결제 금액 표시 |
| 4 | 결제수단 선택 | 국가별 PG 목록 (라디오 버튼 또는 아코디언) |
| 5 | 결제하기 버튼 | 보라색 풀폭 버튼 — 금액 미선택 또는 결제수단 미선택 시 비활성 |

#### 상태 관리

- 로컬 상태:
  - `selectedCoin` — 선택된 충전코인 옵션 (null | 10000 | 30000 | 50000 | 100000 | 300000)
  - `selectedPayment` — 선택된 결제수단 (null | 'credit_card' | 'phone' | 'naver_pay' | 'bank_transfer' | 'apple_pay' | 'union_pay' | 'paypal')
  - `currentBalance` — 현재 보유코인 (Server Component에서 초기값 전달)
  - `isLoading` — API 호출 중 로딩 상태
- Zustand 스토어: `useCoinStore` (보유코인 전역 공유 — 마이메뉴, 상담 화면과 연동)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/coin/getBalance` | POST | `{}` (인증 쿠키 사용) | `{ success: boolean, balance: number }` | 페이지 초기 로드 (Server) |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 충전금액 라디오 선택 | `selectedCoin` 상태 업데이트, 하단 결제금액 표시 갱신 |
| 결제수단 선택 | `selectedPayment` 상태 업데이트 |
| 결제하기 버튼 클릭 | `/[locale]/coin-charging/confirm`으로 이동 (선택값을 query 또는 Zustand로 전달) |
| 뒤로가기 버튼 | `router.back()` |
| Home 버튼 | `/{locale}`로 이동 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 고정 옵션만 허용 | 자유 금액 입력 불가. 5개 고정 옵션 중 택1 |
| 국가별 통화 표시 | KR: "10,000원", JP: "1,100円", US: "$10.00" |
| 국가별 결제수단 필터링 | locale에 따라 표시되는 결제수단 목록이 다름 |
| 결제하기 버튼 활성 조건 | `selectedCoin !== null && selectedPayment !== null` |
| 보유코인 포맷 | Intl.NumberFormat('ko', { currency: 'KRW' }) 사용, 천단위 콤마 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 보유코인 조회 실패 | "0" 표시 + 에러 메시지 또는 재시도 안내 |
| 금액 미선택 상태에서 결제 클릭 | 버튼 비활성 상태 유지 (disabled) |
| 결제수단 미선택 상태에서 결제 클릭 | 버튼 비활성 상태 유지 (disabled) |

---

### 3-2. 결제 확인 (슬라이드 S441)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/coin-charging/confirm` |
| Server Component | `app/[locale]/coin-charging/confirm/page.js` |
| Client Component | `app/[locale]/coin-charging/confirm/_components/CoinChargingConfirm.js` |
| 화면설계서 | S441 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, 뒤로가기 + "Payment Confirmation" + Home 버튼 |
| 1 | 주문정보 요약 | 충전코인 수량 + 결제금액(국가별 통화) + 결제수단명 |
| 2 | 구분선 | h-[0.8rem] bg-[#f5f5f5] 디바이더 |
| 3 | 약관 동의 영역 | 전체 동의 체크박스 + 개별 약관 항목 (구매 약관, 환불 정책) |
| 4 | 결제 진행 버튼 | 보라색 풀폭 버튼 — "Pay {금액}" 텍스트, 약관 미동의 시 비활성 |

#### 상태 관리

- 로컬 상태:
  - `agreeAll` — 전체 동의 체크박스 (boolean)
  - `agreePurchase` — 구매 약관 동의 (boolean)
  - `agreeRefund` — 환불 정책 동의 (boolean)
  - `isSubmitting` — 결제 API 호출 중 (boolean)
- 전달받는 값 (query 또는 Zustand):
  - `selectedCoin` — 선택된 충전코인
  - `selectedPayment` — 선택된 결제수단
  - `paymentAmount` — 국가별 실결제 금액 문자열

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/coin/createPayment` | POST | `{ coinAmount, paymentMethod, locale }` | `{ success: boolean, paymentId: string, pgRedirectUrl?: string }` | 결제 진행 버튼 클릭 |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 전체 동의 체크 | 모든 하위 약관 체크/해제 토글 |
| 개별 약관 체크 | 해당 항목 토글. 모두 체크되면 전체 동의 자동 체크 |
| 개별 약관 해제 | 해당 항목 해제. 전체 동의 자동 해제 |
| 약관 링크 클릭 | 해당 약관 페이지로 이동 (새 탭 또는 내부 이동) |
| 결제 진행 클릭 | API 호출 → PG 결제창 호출 또는 리다이렉트 |
| 뒤로가기 | 코인충전 메인으로 복귀, 선택값 유지 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 약관 전체 동의 필수 | 모든 약관에 동의해야 결제 진행 버튼 활성화 |
| 전체 동의 연동 | 전체 동의 체크 → 하위 전체 체크, 하위 하나라도 해제 → 전체 동의 해제 |
| 결제 진행 시 더블클릭 방지 | `isSubmitting` 상태로 버튼 즉시 비활성화, API 응답 후 해제 |
| PG 결제창 | PG사에 따라 팝업, 리다이렉트, 또는 인앱 결제창 호출 |
| 선택값 유실 방지 | confirm 페이지 진입 시 selectedCoin/selectedPayment가 없으면 메인으로 리다이렉트 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 직접 URL 접근 (선택값 없음) | `/[locale]/coin-charging`으로 리다이렉트 |
| 결제 생성 API 실패 | 에러 모달 표시, 재시도 가능 |
| PG 결제창 호출 실패 | 에러 모달 표시, 메인으로 복귀 안내 |
| 브라우저 뒤로가기 | 코인충전 메인으로 복귀, 선택값 유지 |

---

### 3-3. 결제 처리/완료/실패 (슬라이드 S442~S445)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/coin-charging/result` |
| Server Component | `app/[locale]/coin-charging/result/page.js` |
| Client Component | `app/[locale]/coin-charging/result/_components/CoinChargingResult.js` |
| 화면설계서 | S442 (처리중), S443 (완료), S444 (실패), S445 (취소) |

#### 결제 상태별 UI

**3-3-A. 결제 처리중 (S442)**

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, 타이틀만 표시 (뒤로가기/Home 비활성) |
| 1 | 로딩 인디케이터 | 중앙 스피너 또는 Skeleton 애니메이션 |
| 2 | 안내 텍스트 | "결제를 처리하고 있습니다. 잠시만 기다려주세요." |

- 뒤로가기 버튼 비활성화 (결제 중 이탈 방지)
- 브라우저 뒤로가기/새로고침 시 경고 메시지 (beforeunload)

**3-3-B. 결제 완료 (S443)**

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, "Payment Complete" |
| 1 | 완료 아이콘 | 체크 서클 아이콘 (성공 표시) |
| 2 | 결제 상세 정보 | 충전코인 / 결제금액 / 결제수단 / 결제일시 |
| 3 | 잔여코인 표시 | 충전 후 총 보유코인 (이전 잔액 + 충전 코인) |
| 4 | 확인 버튼 | 보라색 풀폭 버튼 → 메인 또는 이전 페이지로 이동 |

**3-3-C. 결제 실패 (S444)**

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, "Payment Failed" |
| 1 | 실패 아이콘 | X 서클 아이콘 (실패 표시) |
| 2 | 에러 메시지 | PG사에서 전달받은 실패 사유 또는 기본 에러 메시지 |
| 3 | 재시도 버튼 | 보라색 풀폭 버튼 → 코인충전 메인으로 이동 |
| 4 | 메인으로 돌아가기 | 텍스트 링크 → `/[locale]`로 이동 |

**3-3-D. 결제 취소 (S445)**

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, "Payment Cancelled" |
| 1 | 취소 안내 텍스트 | "결제가 취소되었습니다." |
| 2 | 다시 충전하기 버튼 | 보라색 풀폭 버튼 → 코인충전 메인으로 이동 |
| 3 | 메인으로 돌아가기 | 텍스트 링크 → `/[locale]`로 이동 |

#### 상태 관리

- 로컬 상태:
  - `paymentStatus` — 'processing' | 'success' | 'failed' | 'cancelled'
  - `paymentDetail` — 결제 상세 정보 객체 (충전코인, 결제금액, 결제수단, 결제일시, 잔여코인)
  - `errorMessage` — 실패 시 에러 사유
- Zustand: `useCoinStore.setBalance(newBalance)` — 결제 완료 시 보유코인 갱신

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/coin/verifyPayment` | POST | `{ paymentId }` | `{ success: boolean, status: 'success'|'failed'|'cancelled', detail: { chargedCoin, paymentAmount, paymentMethod, paidAt, newBalance }, errorMessage?: string }` | PG 콜백 후 자동 호출 |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 결제 완료 → 확인 버튼 | `useCoinStore.setBalance(newBalance)` 후 메인 또는 이전 페이지 이동 |
| 결제 실패 → 재시도 버튼 | `/[locale]/coin-charging`으로 이동 |
| 결제 취소 → 다시 충전하기 | `/[locale]/coin-charging`으로 이동 |
| 메인으로 돌아가기 링크 | `/[locale]`로 이동 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 결제 처리중 이탈 방지 | beforeunload 이벤트로 경고, 뒤로가기/Home 버튼 비활성 |
| 결제 결과 폴링 | PG 리다이렉트 방식일 경우 결과 페이지에서 paymentId로 결제 상태 확인 |
| 잔여코인 즉시 반영 | 결제 완료 시 useCoinStore 즉시 업데이트 |
| 에러 메시지 국제화 | PG 에러코드를 프론트엔드에서 i18n 메시지로 변환 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| paymentId 없이 직접 접근 | `/[locale]/coin-charging`으로 리다이렉트 |
| 결제 확인 API 타임아웃 | 30초 후 "결제 확인에 실패했습니다. 잠시 후 마이메뉴에서 확인해주세요." 메시지 |
| 결제 완료 후 새로고침 | 동일 paymentId로 재조회, 결과 재표시 (멱등성) |
| PG 콜백 미수신 | 결제 처리중 상태 유지 → 타임아웃 후 안내 |
| 중복 결제 | 서버에서 paymentId 기반 멱등성 보장 (프론트 관여 없음) |

---

## 4. API 연동 상세

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


### 4-1. API Route (프록시 레이어)

| 프론트 경로 | 외부 API 경로 (추정) | 설명 |
|-----------|-------------------|------|
| `/api/coin/getBalance` | `/api/coin/getBalance` | 보유코인 조회 |
| `/api/coin/createPayment` | `/api/coin/createPayment` | 결제 생성 (PG 호출 전) |
| `/api/coin/verifyPayment` | `/api/coin/verifyPayment` | 결제 결과 확인 |
| `/api/coin/getPaymentMethods` | `/api/coin/getPaymentMethods` | 국가별 결제수단 목록 조회 |

### 4-2. PG 연동 흐름

```
1. 프론트 → /api/coin/createPayment (결제 생성 요청)
2. 백엔드 → PG사 결제 세션 생성
3. 백엔드 → 프론트에 pgRedirectUrl 또는 결제창 호출 파라미터 반환
4. 프론트 → PG 결제창 호출 (팝업 또는 리다이렉트)
5. 사용자 → PG 결제 진행 (카드정보 입력, 인증 등)
6. PG → 백엔드 콜백 (결제 결과 전달)
7. PG → 프론트 리다이렉트 (/coin-charging/result?paymentId=xxx)
8. 프론트 → /api/coin/verifyPayment (결제 결과 확인)
9. 프론트 → 결과 화면 렌더링 (성공/실패/취소)
```

### 4-3. PG사별 결제창 호출 방식 (추정)

| 국가 | 결제수단 | 호출 방식 | 비고 |
|------|---------|----------|------|
| KR | 신용카드 | 팝업 또는 리다이렉트 | PG: KG이니시스 / NHN KCP / 토스페이먼츠 (미확정) |
| KR | 휴대폰결제 | 팝업 | |
| KR | 네이버페이 | 리다이렉트 | 네이버페이 SDK |
| KR | 가상계좌 | 팝업 | 발급 후 입금 대기 |
| JP | 신용카드 | 리다이렉트 | PG: Stripe / GMO (미확정) |
| JP | Apple Pay | 인앱 결제창 | Apple Pay JS API |
| JP | 은행송금 | 리다이렉트 | 계좌 정보 표시 후 입금 대기 |
| US | 신용카드 | 리다이렉트 | PG: Stripe (추정) |
| US | UnionPay | 리다이렉트 | |
| US | PayPal | 리다이렉트 | PayPal SDK |

---

## 5. 상태 관리

### 5-1. useCoinStore (Zustand 전역 스토어)

```js
// store/useCoinStore.js
import { create } from 'zustand';

const useCoinStore = create((set) => ({
    balance: 0,
    setBalance: (newBalance) => set({ balance: newBalance }),
    selectedCoin: null,
    setSelectedCoin: (coin) => set({ selectedCoin: coin }),
    selectedPayment: null,
    setSelectedPayment: (method) => set({ selectedPayment: method }),
    resetSelection: () => set({ selectedCoin: null, selectedPayment: null }),
}));

export default useCoinStore;
```

### 5-2. 상태 흐름

```
[메인] balance 초기 로드 (Server → Client props)
  ↓
[메인] selectedCoin, selectedPayment 선택 (로컬 또는 Zustand)
  ↓
[확인] 선택값 전달받아 표시
  ↓
[결과-성공] useCoinStore.setBalance(newBalance) → 전역 반영
  ↓
[마이메뉴/상담] useCoinStore.balance 참조
```

---

## 6. 국가별 분기 로직

### 6-1. 통화 표시 로직

```js
// lib/coinFormatters.js
const COIN_PRICE_MAP = {
    ko: { 10000: '10,000원', 30000: '30,000원', 50000: '50,000원', 100000: '100,000원', 300000: '300,000원' },
    ja: { 10000: '1,100円', 30000: '3,300円', 50000: '5,500円', 100000: '11,000円', 300000: '33,000円' },
    en: { 10000: '$10.00', 30000: '$30.00', 50000: '$50.00', 100000: '$100.00', 300000: '$300.00' },
};

export const getCoinPrice = (locale, coinAmount) => {
    return COIN_PRICE_MAP[locale]?.[coinAmount] ?? '';
};
```

### 6-2. 결제수단 필터 로직

```js
// lib/paymentMethods.js
const PAYMENT_METHODS = {
    ko: [
        { id: 'credit_card', labelKey: 'creditCard', icon: 'icon_credit_card.svg' },
        { id: 'phone', labelKey: 'phonePay', icon: 'icon_phone_pay.svg' },
        { id: 'naver_pay', labelKey: 'naverPay', icon: 'icon_naver_pay.svg' },
        { id: 'bank_transfer', labelKey: 'bankTransfer', icon: 'icon_bank.svg' },
    ],
    ja: [
        { id: 'credit_card', labelKey: 'creditCard', icon: 'icon_credit_card.svg' },
        { id: 'apple_pay', labelKey: 'applePay', icon: 'icon_apple_pay.svg' },
        { id: 'bank_transfer', labelKey: 'bankTransfer', icon: 'icon_bank.svg' },
    ],
    en: [
        { id: 'credit_card', labelKey: 'creditCard', icon: 'icon_credit_card.svg' },
        { id: 'union_pay', labelKey: 'unionPay', icon: 'icon_union_pay.svg' },
        { id: 'paypal', labelKey: 'paypal', icon: 'icon_paypal.svg' },
    ],
};

export const getPaymentMethods = (locale) => {
    return PAYMENT_METHODS[locale] ?? PAYMENT_METHODS['en'];
};
```

---

## 7. 도메인 내 공유 컴포넌트

| 컴포넌트 | 사용 페이지 | Props |
|---------|-----------|-------|
| CoinChargingMain | coin-charging 메인 | `labels`, `locale`, `initialBalance` |
| CoinChargingConfirm | confirm | `labels`, `locale` |
| CoinChargingResult | result | `labels`, `locale` |
| CoinAmountSelector | 메인 (충전금액 선택) | `options`, `selected`, `onSelect`, `locale` |
| PaymentMethodSelector | 메인 (결제수단 선택) | `methods`, `selected`, `onSelect` |
| PaymentSummary | confirm (주문요약) | `coinAmount`, `paymentAmount`, `paymentMethod` |
| AgreementCheckbox | confirm (약관동의) | `items`, `agreeAll`, `onToggle`, `onToggleAll` |
| PageNavBar | 전체 | `locale`, `title`, `homeLabel` |

---

## 8. 크로스 도메인 의존성

- **의존**: login (인증 필수, 비로그인 시 리다이렉트), layout (PageNavBar, Footer)
- **피의존**: member-mymenu (코인내역/결제내역에서 충전 버튼 → 코인충전으로 진입), phone-consultation (잔액 부족 시 충전 안내), chat-consultation (잔액 부족 시 충전 안내)
- **전역 공유**: useCoinStore (보유코인 잔액) — 상담 화면, 마이메뉴에서 참조

---

## 9. 미확정 사항

- [ ] PG사 선정 (국가별): KR/JP/US 각각 어떤 PG를 사용할지 미정
- [ ] PG 결제창 호출 방식: SDK 팝업, 리다이렉트, iframe 중 어느 방식인지 PG사 확정 후 결정
- [ ] 가상계좌(무통장) 입금 대기 UX: 발급 후 입금 전까지의 대기 상태 화면 상세 미정
- [ ] Apple Pay 인앱 결제 연동 방식: Apple Pay JS API 직접 연동인지 PG사 경유인지 미정
- [ ] 환불 정책 약관 URL: 약관 페이지 경로 미정
- [ ] 결제 실패 에러코드 매핑: PG사별 에러코드 → i18n 메시지 매핑 테이블 미정
- [ ] 코인 충전 상한: 1일/1회 충전 한도 존재 여부 미정
- [ ] 가상계좌 입금 기한: 발급 후 입금 마감 시간 (24시간? 72시간?) 미정
- [ ] 결제 확인 화면의 약관 상세 항목: 구매 약관, 환불 정책 외 추가 항목 여부 미정
- [ ] 결제 완료 후 이동 경로: 메인(`/[locale]`) vs 이전 페이지(returnUrl) 중 어디로 이동할지 미정
- [ ] 보유코인 갱신 주기: 결제 완료 후 즉시 반영 외에, 다른 화면에서의 실시간 갱신 필요 여부 미정
