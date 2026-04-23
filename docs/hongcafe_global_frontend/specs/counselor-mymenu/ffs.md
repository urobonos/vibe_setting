# Frontend Functional Spec — 상담사 마이메뉴

> Source: 화면설계서 PPTX Slides S361~S438 (78 슬라이드)
> Status: DRAFT
> Updated: 2026-03-24

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 상담사 마이메뉴 (Counselor My Menu) |
| 사용자 목표 | 상담사가 자신의 상담 상태를 관리하고, 상담 내역/단골/차단을 관리하며, 통계/정산을 확인한다 |
| 퍼블리싱 상태 | ❌ 미구현 |
| 기능 연동 상태 | 미연동 |
| i18n 네임스페이스 | `counselorMyMenu`, `counselorInfo`, `counselorProduct`, `counselorSchedule`, `counselorCallHistory`, `counselorChatHistory`, `counselorStats`, `counselorSettlement` |
| 지원 로케일 | `en`, `ko`, `ja` |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |
| 슬라이드 수 | 78장 — 프로젝트 내 최대 규모 도메인 중 하나 |

### 비즈니스 모델 핵심

- 상담사 마이메뉴는 **상담사 전용** 관리 패널이다. 일반 회원은 접근 불가.
- 회원/상담사 역할 전환 기능이 존재하여, 동일 계정으로 회원 마이메뉴와 상담사 마이메뉴를 오갈 수 있다.
- 상담사 단계(화이트→옐로우→그린→블루)에 따라 접근 가능 기능이 상이할 수 있다.
- 전화상담/채팅상담 상태 ON/OFF를 직접 제어하여 내담자에게 "상담가능" 상태를 노출한다.

### 도메인 흐름 요약

```
상담사 마이메뉴 홈 (/counselor)
  ├── 회원/상담사 전환 (역할 토글)
  ├── 전화상담 상태 ON/OFF
  ├── 채팅상담 상태 ON/OFF
  ├── 공지 배너
  ├── 상담사 정보 (/counselor/info)
  │     ├── 기본정보 (닉네임, 연결전화번호, 입금계좌)
  │     ├── 상담사 단계 상세
  │     └── 전속계약 신청
  ├── 상담관리
  │     ├── 상담 상품 관리 (/counselor/product)
  │     │     ├── 상담코인 설정 (전화/채팅)
  │     │     └── FAQ 관리 (순서/질문/상태)
  │     ├── 주 상담시간 (/counselor/schedule)
  │     │     └── 최대 2개 등록, 노출 ON/OFF
  │     ├── 전화상담 관리 (/counselor/call-history)
  │     │     ├── 상담내역 (기간검색, 리스트, 상세)
  │     │     ├── 차단내역 (리스트, 상세, 해제)
  │     │     ├── 단골관리 (리스트, 해제)
  │     │     └── 상담중 (현재 상담 정보)
  │     └── 채팅상담 관리 (/counselor/chat-history)
  │           ├── 상담내역 (기간검색, 리스트, 상세)
  │           ├── 차단내역 (리스트, 상세, 해제)
  │           ├── 단골관리 (리스트, 해제)
  │           └── 상담중 (현재 상담 정보)
  ├── 상담 통계 (/counselor/stats)
  │     └── 기간별 상담 건수, 수익, 만족도
  └── 정산 관리 (/counselor/settlement)
        ├── 정산내역 (월별 리스트)
        ├── 수익 현황 (총수익, 정산완료, 정산예정)
        └── 정산 상세 (기간별 상세 내역)
```

### 회원 마이메뉴 대비 핵심 차이점

| 항목 | 회원 마이메뉴 | 상담사 마이메뉴 |
|------|------------|---------------|
| 접근 조건 | 로그인 회원 | 상담사 등록 완료 |
| 역할 | 내담자 (상담 받는 자) | 상담사 (상담 제공자) |
| 상담 상태 제어 | 없음 | 전화/채팅 ON/OFF 토글 |
| 상품 관리 | 없음 | 상담코인 설정, FAQ 관리 |
| 상담 내역 | 내가 받은 상담 | 내가 제공한 상담 |
| 단골 | 내가 즐겨찾기한 상담사 | 나를 즐겨찾기한 내담자 |
| 차단 | 없음 (신고만 가능) | 내담자 차단/해제 |
| 통계/정산 | 없음 | 상담 통계 + 수익 정산 |
| 상담사 단계 | 없음 | 화이트→옐로우→그린→블루 |

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/counselor` | `app/[locale]/counselor/page.js` | CounselorMyMenu | Server → Client | `counselorMyMenu` |
| `/[locale]/counselor/info` | `app/[locale]/counselor/info/page.js` | CounselorInfo | Server → Client | `counselorInfo` |
| `/[locale]/counselor/info/tier-detail` | `app/[locale]/counselor/info/tier-detail/page.js` | CounselorTierDetail | Server → Client | `counselorInfo` |
| `/[locale]/counselor/info/contract` | `app/[locale]/counselor/info/contract/page.js` | CounselorContract | Server → Client | `counselorInfo` |
| `/[locale]/counselor/product` | `app/[locale]/counselor/product/page.js` | CounselorProduct | Server → Client | `counselorProduct` |
| `/[locale]/counselor/product/faq` | `app/[locale]/counselor/product/faq/page.js` | CounselorFaq | Server → Client | `counselorProduct` |
| `/[locale]/counselor/schedule` | `app/[locale]/counselor/schedule/page.js` | CounselorSchedule | Server → Client | `counselorSchedule` |
| `/[locale]/counselor/call-history` | `app/[locale]/counselor/call-history/page.js` | CounselorCallHistory | Server → Client | `counselorCallHistory` |
| `/[locale]/counselor/call-history/block` | `app/[locale]/counselor/call-history/block/page.js` | CounselorCallBlock | Server → Client | `counselorCallHistory` |
| `/[locale]/counselor/call-history/regulars` | `app/[locale]/counselor/call-history/regulars/page.js` | CounselorCallRegulars | Server → Client | `counselorCallHistory` |
| `/[locale]/counselor/call-history/in-session` | `app/[locale]/counselor/call-history/in-session/page.js` | CounselorCallInSession | Server → Client | `counselorCallHistory` |
| `/[locale]/counselor/chat-history` | `app/[locale]/counselor/chat-history/page.js` | CounselorChatHistory | Server → Client | `counselorChatHistory` |
| `/[locale]/counselor/chat-history/block` | `app/[locale]/counselor/chat-history/block/page.js` | CounselorChatBlock | Server → Client | `counselorChatHistory` |
| `/[locale]/counselor/chat-history/regulars` | `app/[locale]/counselor/chat-history/regulars/page.js` | CounselorChatRegulars | Server → Client | `counselorChatHistory` |
| `/[locale]/counselor/chat-history/in-session` | `app/[locale]/counselor/chat-history/in-session/page.js` | CounselorChatInSession | Server → Client | `counselorChatHistory` |
| `/[locale]/counselor/stats` | `app/[locale]/counselor/stats/page.js` | CounselorStats | Server → Client | `counselorStats` |
| `/[locale]/counselor/settlement` | `app/[locale]/counselor/settlement/page.js` | CounselorSettlement | Server → Client | `counselorSettlement` |
| `/[locale]/counselor/settlement/detail` | `app/[locale]/counselor/settlement/detail/page.js` | CounselorSettlementDetail | Server → Client | `counselorSettlement` |

### 인증 요구

- 모든 상담사 마이메뉴 라우트는 **상담사 인증 필수**이다.
- 비로그인 상태 → `/[locale]/login` 리다이렉트.
- 로그인했으나 상담사 미등록 → `/[locale]/counselor-registration` 리다이렉트 (또는 안내 알럿).
- 리다이렉트 시 `returnUrl` 쿼리파라미터를 전달한다.

---

## 3. 페이지 정의

### 3-1. 상담사 마이메뉴 홈 (슬라이드 S362)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor` |
| Server Component | `app/[locale]/counselor/page.js` — 메타데이터 생성, labels 구성, 상담사 기본정보 초기 조회 |
| Client Component | `app/[locale]/counselor/_components/CounselorMyMenuMain.js` |
| 화면설계서 | S362 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, "상담사 마이메뉴" 타이틀 + Home 버튼 |
| 1 | 역할 전환 | "회원/상담사" 전환 토글 또는 버튼 — 클릭 시 회원 마이메뉴로 이동 |
| 2 | 상담사 프로필 요약 | 프로필 이미지 + 닉네임 + 상담사 단계 배지 |
| 3 | 상담 상태 제어 | 전화상담 ON/OFF 토글 + 채팅상담 ON/OFF 토글 |
| 4 | 공지 배너 | 운영 공지사항 배너 (선택적 노출) |
| 5 | 상담관리 메뉴 | 그리드/리스트 형태 메뉴 아이콘 — 상담상품관리, 주 상담시간, 전화상담 관리, 채팅상담 관리 |
| 6 | 기타 메뉴 | 상담사 정보, 상담 통계, 정산 관리 |
| 7 | 하단 GNB | 공유 Footer 컴포넌트 |

#### 상담 상태 토글 동작

| 상태 | 설명 | 내담자 화면 효과 |
|------|------|----------------|
| 전화상담 ON | 전화상담 접수 가능 | 프로필에 "상담가능" 뱃지 표시 |
| 전화상담 OFF | 전화상담 접수 불가 | 프로필에 "부재중" 뱃지 표시 |
| 채팅상담 ON | 채팅상담 접수 가능 | 프로필에 "상담가능" 뱃지 표시 |
| 채팅상담 OFF | 채팅상담 접수 불가 | 프로필에 "부재중" 뱃지 표시 |

- 상담 중일 때 OFF로 변경해도 현재 진행 중인 상담은 영향 없음 (종료 시점부터 OFF 적용).
- 토글 변경 시 API 즉시 호출, 실패 시 이전 상태로 롤백 + 에러 알럿.

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getMyInfo` | POST | `{ locale }` | `{ response, profile, tier, callStatus, chatStatus }` |
| `/api/counselor/updateCallStatus` | POST | `{ status: 'on'|'off' }` | `{ response, callStatus }` |
| `/api/counselor/updateChatStatus` | POST | `{ status: 'on'|'off' }` | `{ response, chatStatus }` |
| `/api/counselor/getNotice` | POST | `{ locale }` | `{ response, notices: Notice[] }` |

#### 상태 관리

- `useAuthStore`: 로그인 상태, 사용자 역할(member/counselor)
- 로컬 상태: 전화상담 토글, 채팅상담 토글, 공지 배너 접힘 여부

---

### 3-2. 상담사 정보 (슬라이드 S363~S370)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/info` |
| Server Component | `app/[locale]/counselor/info/page.js` |
| Client Component | `app/[locale]/counselor/info/_components/CounselorInfoMain.js` |
| 화면설계서 | S363~S365 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "상담사 정보" |
| 1 | 닉네임 | 닉네임 표시 + 가타카나 표기 (ja 로케일) |
| 2 | 연결 전화번호 | 상담 수신 전화번호 표시 (마스킹 처리) |
| 3 | 상담사 단계 | 현재 단계 배지 + "상세보기" 링크 |
| 4 | 입금 계좌번호 | 정산 입금 계좌 표시 (마스킹 처리) |
| 5 | 전속계약 | 전속계약 상태 표시 + "신청하기" 버튼 |

#### 유효성 메시지

| 필드 | 조건 | 메시지 |
|------|------|--------|
| 연결 전화번호 | 미등록 | "연결 전화번호를 등록해주세요." |
| 입금 계좌번호 | 미등록 | "입금 계좌번호를 등록해주세요." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getInfo` | POST | `{ locale }` | `{ response, nickname, katakana, phone, tier, bankAccount, contractStatus }` |

---

### 3-2-1. 상담사 단계 상세 (슬라이드 S366~S370)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/info/tier-detail` |
| Client Component | `app/[locale]/counselor/info/tier-detail/_components/CounselorTierDetailMain.js` |
| 화면설계서 | S366~S370 |

#### 상담사 단계 체계

| 단계 | 이름 | 레벨 | 컬러 |
|------|------|------|------|
| 0 | 화이트 (White) | 신규 등록 | `#cccccc` (회색) |
| 1 | 옐로우 (Yellow) | 초급 | `#f5a623` (노랑) |
| 2 | 그린 (Green) | 중급 | `#00af79` (녹색) |
| 3 | 블루 (Blue) | 고급 | `#4a90d9` (파랑) |

#### 상승 조건

| 대상 단계 | 조건 1: 상담수익 금액 | 조건 2: 연속 개월 | 비고 |
|----------|-------------------|----------------|------|
| 화이트 → 옐로우 | 월 수익 기준 A 이상 | N개월 연속 달성 | 관리자 설정값 |
| 옐로우 → 그린 | 월 수익 기준 B 이상 | N개월 연속 달성 | 관리자 설정값 |
| 그린 → 블루 | 월 수익 기준 C 이상 | N개월 연속 달성 | 관리자 설정값 |

#### 강등 조건

- 연속 N개월 동안 기준 수익 미달 시 한 단계 강등.
- 강등 시 알림(Push + 알림내역) 발송.
- 강등 후에도 재상승 가능.

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "상담사 단계" |
| 1 | 현재 단계 | 현재 단계 뱃지 + 단계명 + 프로그레스 바 |
| 2 | 단계 안내 | 화이트→옐로우→그린→블루 시각적 진행 표시 |
| 3 | 상승 조건표 | 각 단계별 상승 조건 테이블 (수익 금액 + 연속 개월) |
| 4 | 강등 조건 | 강등 조건 안내 텍스트 |
| 5 | 나의 현황 | 현재 월 수익, 연속 달성 개월 수 |

---

### 3-2-2. 전속계약 신청 (슬라이드 S370 추정)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/info/contract` |
| 화면설계서 | S370 |

#### 전속계약 상태

| 상태 | 설명 | UI 표시 |
|------|------|---------|
| 미신청 | 전속계약 미신청 | "전속계약 신청하기" 버튼 활성 |
| 심사중 | 신청 후 관리자 검토 중 | "심사 진행 중입니다" 안내 |
| 승인 | 전속계약 체결 | "전속계약 상담사" 배지 |
| 반려 | 신청 반려 | "반려 사유" 표시 + 재신청 버튼 |

---

### 3-3. 상담 상품 관리 (슬라이드 S371~S377)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/product` |
| Server Component | `app/[locale]/counselor/product/page.js` |
| Client Component | `app/[locale]/counselor/product/_components/CounselorProductMain.js` |
| 화면설계서 | S371~S374 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "상담 상품 관리" |
| 1 | 전화상담 코인 설정 | 현재 설정된 코인/30초 표시 + 변경 버튼 |
| 2 | 채팅상담 코인 설정 | 현재 설정된 코인/30초 표시 + 변경 버튼 |
| 3 | FAQ 관리 | FAQ 리스트 바로가기 |

#### 상담코인 설정 규칙

| 항목 | 규칙 |
|------|------|
| 변경 가능 주체 | 일반 상담사: 직접 변경 가능. CP(전속계약) 상담사: 관리자만 변경 가능 |
| 변경 범위 | 최소 N코인 ~ 최대 M코인 (관리자 설정값) |
| 변경 제한 | 1일 1회 변경 가능. 변경 후 24시간 내 재변경 불가 |
| 변경 효과 | 변경 즉시 반영 — 진행 중 상담은 기존 코인으로 과금, 새 상담부터 변경된 코인 적용 |

#### 코인 변경 유효성 메시지

| 조건 | 메시지 |
|------|--------|
| 최소값 미만 | "최소 {min}코인 이상 설정해주세요." |
| 최대값 초과 | "최대 {max}코인까지 설정 가능합니다." |
| 24시간 내 재변경 | "코인 변경은 24시간에 1회만 가능합니다. {remainTime} 후 변경 가능합니다." |
| CP 상담사 변경 시도 | "전속계약 상담사는 관리자를 통해 변경할 수 있습니다." |
| 변경 성공 | "상담코인이 변경되었습니다." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getProductInfo` | POST | `{ locale }` | `{ response, callCoin, chatCoin, isCP, coinRange, lastChanged }` |
| `/api/counselor/updateCoin` | POST | `{ type: 'call'|'chat', coin }` | `{ response, message }` |

---

### 3-3-1. 상담 상품 FAQ 관리 (슬라이드 S375~S377)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/product/faq` |
| Client Component | `app/[locale]/counselor/product/faq/_components/CounselorFaqMain.js` |
| 화면설계서 | S375~S377 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "FAQ 관리" |
| 1 | FAQ 리스트 | 드래그 정렬 가능 리스트 — 순번, 질문, 답변, 노출상태 |
| 2 | FAQ 추가 버튼 | "FAQ 추가" 버튼 — 하단 고정 |

#### FAQ 항목 구조

| 필드 | 설명 | 제한 |
|------|------|------|
| 순서 | 드래그로 변경 가능 | 1~N |
| 질문 | FAQ 질문 텍스트 | 최대 100자 |
| 답변 | FAQ 답변 텍스트 | 최대 500자 |
| 상태 | 노출/미노출/삭제 | 토글 또는 셀렉트 |

#### FAQ 노출 상태

| 상태 | 설명 | 내담자 프로필 효과 |
|------|------|-------------------|
| 노출 | 내담자에게 표시 | 프로필 > 상세정보 > FAQ 아코디언에 표시 |
| 미노출 | 숨김 처리 | 내담자 화면에서 비노출, 상담사만 확인 가능 |
| 삭제 | 영구 삭제 | 복구 불가, 삭제 확인 알럿 필수 |

#### 유효성 메시지

| 조건 | 메시지 |
|------|--------|
| 질문 미입력 | "질문을 입력해주세요." |
| 답변 미입력 | "답변을 입력해주세요." |
| 질문 100자 초과 | "질문은 최대 100자까지 입력할 수 있습니다." |
| 답변 500자 초과 | "답변은 최대 500자까지 입력할 수 있습니다." |
| 삭제 확인 | "FAQ를 삭제하시겠습니까? 삭제 후 복구할 수 없습니다." |
| 순서 변경 성공 | "FAQ 순서가 변경되었습니다." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getFaqList` | POST | `{ locale }` | `{ response, faqs: FAQ[] }` |
| `/api/counselor/updateFaq` | POST | `{ faqId, question, answer, status }` | `{ response }` |
| `/api/counselor/addFaq` | POST | `{ question, answer }` | `{ response, faqId }` |
| `/api/counselor/deleteFaq` | POST | `{ faqId }` | `{ response }` |
| `/api/counselor/reorderFaq` | POST | `{ orderedIds: number[] }` | `{ response }` |

---

### 3-4. 주 상담시간 (슬라이드 S378~S380)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/schedule` |
| Client Component | `app/[locale]/counselor/schedule/_components/CounselorScheduleMain.js` |
| 화면설계서 | S378~S380 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "주 상담시간" |
| 1 | 상담시간 리스트 | 최대 2개 시간대 카드 — 시작시간~종료시간, 노출 ON/OFF |
| 2 | 추가 버튼 | "상담시간 추가" 버튼 (2개 미만일 때만 활성) |

#### 상담시간 항목 구조

| 필드 | 설명 | 제한 |
|------|------|------|
| 시작시간 | HH:MM 형식 | 타임피커 또는 셀렉트 |
| 종료시간 | HH:MM 형식 | 시작시간 이후만 선택 가능 |
| 노출여부 | ON/OFF 토글 | ON: 내담자 프로필에 표시 |

#### 유효성 메시지

| 조건 | 메시지 |
|------|--------|
| 2개 초과 등록 시도 | "주 상담시간은 최대 2개까지 등록할 수 있습니다." |
| 시작시간 미입력 | "시작 시간을 선택해주세요." |
| 종료시간 미입력 | "종료 시간을 선택해주세요." |
| 종료시간 <= 시작시간 | "종료 시간은 시작 시간 이후로 설정해주세요." |
| 시간대 중복 | "기존 등록된 시간과 겹칩니다. 시간을 조정해주세요." |
| 저장 성공 | "주 상담시간이 저장되었습니다." |
| 삭제 확인 | "상담시간을 삭제하시겠습니까?" |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getSchedule` | POST | `{ locale }` | `{ response, schedules: Schedule[] }` |
| `/api/counselor/updateSchedule` | POST | `{ scheduleId, startTime, endTime, isVisible }` | `{ response }` |
| `/api/counselor/addSchedule` | POST | `{ startTime, endTime }` | `{ response, scheduleId }` |
| `/api/counselor/deleteSchedule` | POST | `{ scheduleId }` | `{ response }` |

---

### 3-5. 전화상담 관리 (슬라이드 S381~S394)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/call-history` |
| Server Component | `app/[locale]/counselor/call-history/page.js` |
| Client Component | `app/[locale]/counselor/call-history/_components/CounselorCallHistoryMain.js` |
| 화면설계서 | S381~S394 |

#### UI 섹션 — 상담내역 탭 (S381~S386)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "전화상담 관리" |
| 1 | 서브 탭 | 상담내역 / 차단내역 / 단골관리 / 상담중 (4개 탭) |
| 2 | 기간 검색 | PeriodFilter — 1개월 / 3개월 / 6개월 + 커스텀 기간 |
| 3 | 닉네임 검색 | 내담자 닉네임 검색 input |
| 4 | 상담내역 리스트 | 카드 리스트 — 회원닉네임, 상담유형, 상담시간, 코인, 날짜, 단골 여부 |

#### 상담내역 카드 항목

| 필드 | 설명 |
|------|------|
| 회원 닉네임 | 내담자 닉네임 (탭 시 상세보기 이동) |
| 상담 유형 | 전화상담 |
| 상담 시간 | MM:SS 형식 |
| 과금 코인 | 총 과금된 코인 수 |
| 상담 일시 | YYYY.MM.DD HH:MM |
| 단골 여부 | 단골 아이콘 (설정/미설정) |

#### 상담내역 상세보기 (S385~S386)

| 항목 | 설명 |
|------|------|
| 진입 | 상담내역 카드 클릭 → 바텀시트 또는 상세 페이지 |
| 회원 정보 | 닉네임, 프로필 이미지 |
| 상담 상세 | 유형, 시작/종료시간, 총 시간, 과금 코인 |
| 메모 작성 | textarea — 최대 500자. 상담 후 메모 기록 용도 |
| 단골 설정/해제 | 토글 버튼 |
| 차단하기 | 차단 버튼 → 차단 사유 입력 플로우 |

#### 단골 설정/해제

| 동작 | 설명 |
|------|------|
| 단골 설정 | 내담자를 단골로 등록 → 단골관리 탭에서 확인 가능 |
| 단골 해제 | 단골 해제 확인 알럿 → 해제 |
| 알럿 메시지 | "단골을 해제하시겠습니까?" |

#### 메모 작성

| 필드 | 제한 |
|------|------|
| 메모 내용 | 최대 500자, textarea |
| 저장 | "저장" 버튼 클릭 시 API 호출 |

#### 유효성 메시지

| 조건 | 메시지 |
|------|--------|
| 메모 500자 초과 | "메모는 최대 500자까지 입력할 수 있습니다." |
| 메모 저장 성공 | "메모가 저장되었습니다." |
| 검색 결과 없음 | "검색 결과가 없습니다." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getCallHistory` | POST | `{ period, nickname, offset, limit, locale }` | `{ response, items: CallHistory[], total }` |
| `/api/counselor/getCallDetail` | POST | `{ historyId }` | `{ response, detail: CallDetail }` |
| `/api/counselor/saveMemo` | POST | `{ historyId, memo }` | `{ response }` |
| `/api/counselor/setRegular` | POST | `{ memberId, isRegular }` | `{ response }` |

---

### 3-5-1. 차단하기 (슬라이드 S387~S389)

차단하기 플로우는 상담내역 상세에서 진입한다.

#### 차단 사유 구조

| 필드 | 설명 | 제한 |
|------|------|------|
| 차단사유 구분 | 드롭다운 셀렉트 | 필수 선택 |
| 상세사유 | textarea | 최대 500자, 필수 입력 |

#### 차단사유 구분 옵션

| 코드 | 사유 |
|------|------|
| ABUSE | 욕설/비방 |
| HARASSMENT | 성희롱/부적절 언행 |
| FALSE_INFO | 허위정보 제공 |
| REPEAT_CANCEL | 반복 취소/장난 전화 |
| OTHER | 기타 |

#### 유효성 메시지

| 조건 | 메시지 |
|------|--------|
| 사유 구분 미선택 | "차단 사유를 선택해주세요." |
| 상세사유 미입력 | "상세 사유를 입력해주세요." |
| 상세사유 500자 초과 | "상세 사유는 최대 500자까지 입력할 수 있습니다." |
| 차단 확인 | "해당 회원을 차단하시겠습니까? 차단 후 해당 회원의 상담 요청을 받을 수 없습니다." |
| 차단 성공 | "회원이 차단되었습니다." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/blockMember` | POST | `{ memberId, reasonCode, reasonDetail }` | `{ response }` |

---

### 3-5-2. 차단내역 탭 (슬라이드 S390~S391)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/call-history/block` (또는 탭 전환) |
| 화면설계서 | S390~S391 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 1 | 차단 리스트 | 차단된 회원 카드 리스트 — 닉네임, 차단사유, 차단일시 |
| 2 | 상세보기 | 카드 클릭 → 차단 상세 (사유 구분 + 상세사유 + 차단일) |
| 3 | 차단해제 | 상세보기에서 "차단 해제" 버튼 |

#### 유효성 메시지

| 조건 | 메시지 |
|------|--------|
| 차단 해제 확인 | "차단을 해제하시겠습니까? 해제 후 해당 회원이 상담을 요청할 수 있습니다." |
| 차단 해제 성공 | "차단이 해제되었습니다." |
| 차단 내역 없음 | "차단 내역이 없습니다." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getBlockList` | POST | `{ type: 'call', offset, limit }` | `{ response, items: BlockItem[], total }` |
| `/api/counselor/getBlockDetail` | POST | `{ blockId }` | `{ response, detail: BlockDetail }` |
| `/api/counselor/unblockMember` | POST | `{ blockId }` | `{ response }` |

---

### 3-5-3. 단골관리 탭 (슬라이드 S392~S393)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/call-history/regulars` (또는 탭 전환) |
| 화면설계서 | S392~S393 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 1 | 단골 리스트 | 단골 설정된 회원 카드 리스트 — 닉네임, 프로필이미지, 최근상담일, 총상담횟수 |
| 2 | 단골 해제 | 카드 스와이프 또는 버튼으로 단골 해제 |

#### 유효성 메시지

| 조건 | 메시지 |
|------|--------|
| 단골 해제 확인 | "단골을 해제하시겠습니까?" |
| 단골 해제 성공 | "단골이 해제되었습니다." |
| 단골 내역 없음 | "단골 회원이 없습니다." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getRegularList` | POST | `{ type: 'call', offset, limit }` | `{ response, items: Regular[], total }` |

---

### 3-5-4. 상담중 탭 (슬라이드 S394)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/call-history/in-session` (또는 탭 전환) |
| 화면설계서 | S394 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 1 | 상담중 정보 | 현재 상담 중인 내담자 정보 — 닉네임, 프로필이미지, 상담유형, 경과시간(실시간 타이머), 과금 코인 |
| 2 | 상담 없음 | 현재 상담 중이 아닐 때 — "현재 진행 중인 상담이 없습니다." |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getCurrentSession` | POST | `{ type: 'call' }` | `{ response, session: CurrentSession | null }` |

---

### 3-6. 채팅상담 관리 (슬라이드 S395~S410 추정)

> 채팅상담 관리는 전화상담 관리(3-5)와 **동일한 구조**를 가진다.
> 차이점만 아래에 기술한다.

| 항목 | 전화상담 관리 | 채팅상담 관리 |
|------|------------|--------------|
| 라우트 | `/counselor/call-history` | `/counselor/chat-history` |
| 상담 유형 | 전화상담 | 채팅상담 |
| 상담 시간 | 통화 시간 (MM:SS) | 채팅 시간 (MM:SS) |
| 과금 단위 | 코인/1분 | 코인/30초 |
| 네비게이션 타이틀 | "전화상담 관리" | "채팅상담 관리" |
| i18n 네임스페이스 | `counselorCallHistory` | `counselorChatHistory` |
| 상담중 추가정보 | 없음 | 마지막 메시지 미리보기 |

- 서브탭 구조 동일: 상담내역 / 차단내역 / 단골관리 / 상담중
- 차단 사유 옵션 동일
- 메모 작성 동일 (최대 500자)
- 단골 설정/해제 동일
- API 엔드포인트만 `call` → `chat`으로 변경

#### API 연동 (채팅 전용)

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getChatHistory` | POST | `{ period, nickname, offset, limit, locale }` | `{ response, items: ChatHistory[], total }` |
| `/api/counselor/getChatDetail` | POST | `{ historyId }` | `{ response, detail: ChatDetail }` |
| `/api/counselor/getBlockList` | POST | `{ type: 'chat', offset, limit }` | `{ response, items: BlockItem[], total }` |
| `/api/counselor/getRegularList` | POST | `{ type: 'chat', offset, limit }` | `{ response, items: Regular[], total }` |
| `/api/counselor/getCurrentSession` | POST | `{ type: 'chat' }` | `{ response, session: CurrentSession | null }` |

---

### 3-7. 상담 통계 (슬라이드 S411~S425 추정)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/stats` |
| Server Component | `app/[locale]/counselor/stats/page.js` |
| Client Component | `app/[locale]/counselor/stats/_components/CounselorStatsMain.js` |
| 화면설계서 | S411~S425 (추정) |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "상담 통계" |
| 1 | 기간 필터 | PeriodFilter — 1개월 / 3개월 / 6개월 / 커스텀 |
| 2 | 요약 카드 | 총 상담 건수, 총 상담 시간, 총 수익 코인, 평균 만족도 |
| 3 | 전화/채팅 구분 | 탭 또는 토글로 전화상담/채팅상담 통계 구분 |
| 4 | 상담 건수 차트 | 일별/주별/월별 상담 건수 바(bar) 차트 |
| 5 | 수익 차트 | 일별/주별/월별 수익 코인 라인 차트 |
| 6 | 만족도 차트 | 별점 분포 바 차트 (5점~1점) |
| 7 | 카테고리별 분포 | 상담 카테고리별 비율 (도넛/파이 차트) |

#### 요약 카드 데이터

| 항목 | 설명 | 포맷 |
|------|------|------|
| 총 상담 건수 | 선택 기간 내 완료된 상담 수 | N건 |
| 총 상담 시간 | 선택 기간 내 누적 상담 시간 | HH시간 MM분 |
| 총 수익 코인 | 선택 기간 내 누적 과금 코인 | N,NNN 코인 (Intl.NumberFormat) |
| 평균 만족도 | 후기 평균 별점 | N.N / 5.0 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getStats` | POST | `{ period, startDate, endDate, type, locale }` | `{ response, summary, dailyData, categoryData }` |

#### 외부 의존성

- 차트 라이브러리 필요: `recharts` (가벼운 React 차트 라이브러리)

---

### 3-8. 정산 관리 (슬라이드 S426~S438 추정)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/settlement` |
| Server Component | `app/[locale]/counselor/settlement/page.js` |
| Client Component | `app/[locale]/counselor/settlement/_components/CounselorSettlementMain.js` |
| 화면설계서 | S426~S438 (추정) |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "정산 관리" |
| 1 | 수익 현황 요약 | 총 수익, 정산 완료 금액, 정산 예정 금액 (3개 카드) |
| 2 | 정산 내역 리스트 | 월별 정산 카드 리스트 — 정산월, 정산금액, 상태(정산완료/정산예정/검토중) |
| 3 | 정산 상세 | 카드 클릭 → 상세 페이지 이동 |

#### 수익 현황 요약

| 항목 | 설명 | 포맷 |
|------|------|------|
| 총 수익 | 누적 총 수익 코인 | N,NNN 코인 |
| 정산 완료 | 계좌 입금 완료된 금액 | N,NNN 원/円/$ |
| 정산 예정 | 다음 정산일에 입금 예정 금액 | N,NNN 원/円/$ |

#### 정산 내역 카드 항목

| 필드 | 설명 |
|------|------|
| 정산월 | YYYY년 MM월 |
| 정산 금액 | 해당 월 정산 금액 (실제 통화) |
| 정산 상태 | 정산완료 / 정산예정 / 검토중 |
| 입금일 | 정산완료 시 실제 입금일 |

#### 정산 상태

| 상태 | 설명 | UI 표시 |
|------|------|---------|
| 정산완료 | 계좌 입금 완료 | green 뱃지 |
| 정산예정 | 다음 정산일 입금 예정 | yellow 뱃지 |
| 검토중 | 관리자 검토 중 | gray 뱃지 |

---

### 3-8-1. 정산 상세 (슬라이드 S430~S438 추정)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/counselor/settlement/detail` |
| Client Component | `app/[locale]/counselor/settlement/detail/_components/CounselorSettlementDetailMain.js` |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "정산 상세" |
| 1 | 정산 기본정보 | 정산월, 상태, 입금 계좌, 입금일 |
| 2 | 수익 내역 | 전화상담 수익 + 채팅상담 수익 구분 표시 |
| 3 | 공제 항목 | 수수료, 세금 등 공제 항목 리스트 |
| 4 | 최종 정산 금액 | 총 수익 - 총 공제 = 정산 금액 |
| 5 | 일별 상세 | 일별 상담 건수/시간/수익 테이블 |

#### 수익 내역 구조

| 항목 | 설명 |
|------|------|
| 전화상담 수익 | 해당 월 전화상담 총 과금 코인 → 실제 금액 환산 |
| 채팅상담 수익 | 해당 월 채팅상담 총 과금 코인 → 실제 금액 환산 |
| 총 수익 | 전화 + 채팅 합산 |
| 수수료 | 플랫폼 수수료 (단계별 비율 상이) |
| 세금 | 국가별 세금 (원천징수 등) |
| 정산 금액 | 총 수익 - 수수료 - 세금 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response |
|-----------|--------|-------------|----------|
| `/api/counselor/getSettlement` | POST | `{ locale }` | `{ response, summary, monthlyList: Settlement[] }` |
| `/api/counselor/getSettlementDetail` | POST | `{ settlementId, locale }` | `{ response, detail: SettlementDetail }` |

---

## 4. 공유 컴포넌트 사용

| 컴포넌트 | 사용 위치 | 비고 |
|---------|---------|------|
| `PageNavBar` | 모든 하위 페이지 | 보라색 배경 + 타이틀 + Home 버튼 |
| `Footer` (GNB) | 마이메뉴 홈 | 하단 고정 네비게이션 |
| `ListEmpty` | 리스트 빈 상태 | 상담내역/차단내역/단골/FAQ 등 |
| `PeriodFilter` | 상담내역, 통계 | 1개월/3개월/6개월 탭 |

---

## 5. 상태 관리 (Zustand)

| 스토어 | 사용 위치 | 상태 |
|--------|---------|------|
| `useAuthStore` | 전체 | 로그인 상태, 사용자 역할(member/counselor), 상담사 ID |
| `useCounselorStatusStore` (신규) | 마이메뉴 홈 | 전화상담 ON/OFF, 채팅상담 ON/OFF |

---

## 6. 에러 처리

| 에러 케이스 | 처리 방식 |
|-----------|---------|
| 비로그인 접근 | `/[locale]/login?returnUrl=...` 리다이렉트 |
| 상담사 미등록 접근 | `/[locale]/counselor-registration` 리다이렉트 또는 안내 알럿 |
| API 호출 실패 | 에러 알럿 + 재시도 안내 |
| 토글 변경 실패 | 이전 상태로 롤백 + 에러 알럿 |
| 네트워크 오류 | "네트워크 연결을 확인해주세요." 알럿 |
| 세션 만료 | 로그인 페이지 리다이렉트 |

---

## 7. 접근성 (Accessibility)

| 항목 | 구현 |
|------|------|
| 토글 스위치 | `role="switch"`, `aria-checked`, `aria-label` |
| 탭 네비게이션 | `role="tablist"`, `role="tab"`, `aria-selected` |
| 차단 확인 다이얼로그 | `role="alertdialog"`, `aria-modal="true"` |
| 기간 필터 | `role="radiogroup"`, `role="radio"` |
| FAQ 드래그 리스트 | `aria-grabbed`, `aria-dropeffect` |
| 로딩 상태 | `aria-busy="true"` |
| 폼 에러 | `aria-invalid="true"`, `aria-describedby` |

---

## 8. 성능 고려사항

| 항목 | 전략 |
|------|------|
| 상담내역 리스트 | IntersectionObserver 무한 스크롤, offset 기반 페이징 |
| 통계 차트 | `recharts` lazy import (`dynamic(() => import(...), { ssr: false })`) |
| 실시간 상담 타이머 | `setInterval` + cleanup on unmount, requestAnimationFrame 불필요 |
| 상태 토글 | 낙관적 업데이트(Optimistic Update) — 즉시 UI 반영 후 API 실패 시 롤백 |
| FAQ 드래그 정렬 | 로컬 상태 변경 후 "저장" 버튼으로 일괄 API 호출 (개별 호출 금지) |
