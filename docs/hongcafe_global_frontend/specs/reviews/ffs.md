# Frontend Functional Spec — 전체후기

> Source: 화면설계서 PPTX Slides S247~S258
> Status: DRAFT
> Updated: 2026-03-24

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 전체후기 (Reviews) |
| 사용자 목표 | 상담 후기를 탐색(전체/베스트/손글씨), 분야별 태그로 필터링하며, 신고 기능을 통해 부적절한 후기나 회원을 제보한다 |
| 퍼블리싱 상태 | 미구현 |
| 기능 연동 상태 | 미연동 |
| i18n 네임스페이스 | `reviews` |
| 지원 로케일 | `en`, `ko`, `ja` |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |

### 비즈니스 모델 핵심

- 후기는 상담 서비스의 신뢰도를 입증하는 핵심 UGC 콘텐츠다.
- 사용자는 후기를 작성하면 코인을 보상으로 받는다 ("후기 작성시 코인을 선물로 드립니다").
- 전체 후기 수, 별점 평균, 만족도(%)를 상단에 집계하여 서비스 신뢰 지표로 노출한다.
- 손글씨 후기는 차별화된 UGC로 별도 탭과 더보기 영역을 제공한다.
- 신고 기능(회원신고/후기신고)을 통해 부적절한 콘텐츠를 관리한다.

### 도메인 흐름 요약

```
전체후기 메인 (/reviews)
  ├── 상단 통계 영역: "후기 5,870건 ★5점 만족도 96%"
  ├── 후기검색 링크 → /[locale]/search (후기 탭)
  ├── 상담후기 운영정책 링크
  ├── 후기쓰기 링크
  ├── 손글씨 후기 더보기 (가로 스크롤 프리뷰)
  ├── 분야 태그 필터 (#애정 #진로 #인간관계 #시험 #속마음)
  ├── 탭: 전체 / 베스트 / 손글씨
  │     ├── 전체 탭: 정렬(최근작성순/도움이돼요) + 후기 카드 리스트
  │     ├── 베스트 탭: 베스트 후기 리스트 (빈 상태 처리)
  │     └── 손글씨 탭: 손글씨 이미지 후기 리스트 (빈 상태 처리)
  ├── 후기 카드 → 회원 닉네임 클릭 → 회원신고
  └── 후기 카드 → 신고 버튼 클릭 → 후기신고
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/reviews` | `app/[locale]/reviews/page.js` | ReviewsPage | Server → Client | `reviews` |

### 인증 요구

- 후기 열람: **로그인 불필요** (비로그인 상태에서도 후기 리스트 조회 가능)
- 후기쓰기: **로그인 필수** — 비로그인 시 `/[locale]/login?returnUrl=/[locale]/reviews`로 리다이렉트
- 신고하기: **로그인 필수** — 비로그인 시 로그인 페이지로 리다이렉트

---

## 3. 페이지 정의

### 3-1. 전체후기 메인 (슬라이드 S248~S254)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/reviews` |
| Server Component | `app/[locale]/reviews/page.js` — 메타데이터 생성, labels 객체 구성, 후기 통계+초기 리스트 SSR 조회 |
| Client Component | `app/[locale]/reviews/_components/ReviewsMain.js` |
| 화면설계서 | S248, S250, S251, S252, S253, S254 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, 뒤로가기 + "Reviews" + Home 버튼 |
| 1 | 후기검색 링크 | 돋보기 아이콘 + "후기검색" 텍스트 → /[locale]/search (후기 탭) |
| 2 | 통계 영역 | "후기 {N}건", 별점 ★{N}점, 만족도 {N}% — 집계 데이터 표시. 만족도 옆 (i) 아이콘 → 툴팁(S249) |
| 3 | 운영정책+후기쓰기 | 상담후기 운영정책 링크 + "후기쓰기" 링크 (로그인 필수) |
| 4 | 코인 보상 안내 | "후기 작성시 코인을 선물로 드립니다" 배너 |
| 5 | 손글씨 후기 프리뷰 | "손글씨 후기({N})" 타이틀 + 더보기 링크. 가로 스크롤 이미지 카드 (Swiper 또는 overflow-x-scroll) |
| 6 | 분야 태그 필터 | 가로 스크롤 태그 칩: #애정, #진로, #인간관계, #시험, #속마음 등. 선택 시 해당 분야 필터링 |
| 7 | 탭 영역 | 전체(기본) / 베스트 / 손글씨 — 3개 탭 전환 |
| 8 | 정렬 드롭다운 | 전체 탭: "최근작성순" / "도움이돼요순" 정렬 옵션 |
| 9 | 후기 카드 리스트 | ReviewCard 컴포넌트 반복 렌더링. 무한 스크롤 또는 더보기 방식 |

#### 상태 관리

- 로컬 상태:
  - `activeTab` — 'all' | 'best' | 'handwritten' (현재 활성 탭)
  - `sortOrder` — 'recent' | 'helpful' (정렬 기준, 전체 탭에서만 사용)
  - `selectedTag` — null | string (선택된 분야 태그, null이면 전체)
  - `items` — 후기 카드 배열
  - `stats` — { totalCount, avgRating, satisfactionPct } 통계 데이터
  - `isLoading` — API 호출 중 로딩 상태
  - `hasMore` — 추가 데이터 존재 여부 (무한 스크롤용)
  - `offset` — 페이징 오프셋
  - `showTooltip` — 만족도 툴팁 표시 여부 (boolean)
- Zustand 스토어: 없음 (도메인 내부 상태만 사용)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/reviews/getStats` | POST | `{}` | `{ success, totalCount, avgRating, satisfactionPct }` | 페이지 초기 로드 (Server) |
| `/api/reviews/getList` | POST | `{ tab, sort, tag, offset, limit }` | `{ success, items: ReviewCard[], hasMore }` | 페이지 초기 로드 + 탭/정렬/태그 변경 + 무한 스크롤 |
| `/api/reviews/getHandwrittenPreview` | POST | `{ limit: 10 }` | `{ success, items: HandwrittenCard[], totalCount }` | 페이지 초기 로드 (손글씨 프리뷰) |

#### ReviewCard 데이터 구조

```js
{
    reviewId: number,         // 후기 고유 ID
    nickname: string,         // 작성자 닉네임
    rating: number,           // 별점 (1~5)
    content: string,          // 후기 텍스트
    createdAt: string,        // 작성일 (ISO 8601)
    helpfulCount: number,     // "도움이돼요" 카운트
    isHelpful: boolean,       // 현재 사용자가 도움이돼요 눌렀는지
    counselorName: string,    // 상담사 닉네임
    counselorId: number,      // 상담사 ID
    counselorCategory: string,// 상담사 분야
    imageUrl: string | null,  // 손글씨 이미지 URL (없으면 null)
    tags: string[],           // 분야 태그 배열
}
```

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 후기검색 링크 클릭 | `/[locale]/search` (후기 탭 포커스)로 이동 |
| 만족도 (i) 아이콘 클릭 | 만족도 퍼센트 설명 툴팁 팝오버 표시/숨김 토글 (S249) |
| 상담후기 운영정책 클릭 | 운영정책 페이지로 이동 (경로 미확정 → href="#") |
| 후기쓰기 클릭 | 로그인 확인 → 후기 작성 페이지 이동 (경로 미확정) |
| 손글씨 더보기 클릭 | 손글씨 탭으로 전환 (activeTab='handwritten') |
| 분야 태그 칩 클릭 | 해당 태그 필터 적용. 이미 선택된 태그 재클릭 시 해제 (전체 보기) |
| 탭 전환 (전체/베스트/손글씨) | activeTab 변경, offset 초기화, API 재조회 |
| 정렬 드롭다운 변경 | sortOrder 변경, offset 초기화, API 재조회 (전체 탭에서만 표시) |
| 후기 카드 스크롤 끝 도달 | hasMore=true이면 offset 증가, 추가 후기 로드 (무한 스크롤) |
| 상담사 이름 클릭 | `/[locale]/call/profile/{counselorId}` 또는 `/[locale]/chat/profile/{counselorId}`로 이동 |
| 뒤로가기 버튼 | `router.back()` |
| Home 버튼 | `/{locale}`로 이동 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 탭별 데이터 분리 | 전체/베스트/손글씨 각각 독립 API 호출. 탭 전환 시 기존 데이터 초기화 |
| 정렬은 전체 탭만 | 베스트/손글씨 탭에서는 정렬 드롭다운 미표시 |
| 태그 필터 적용 범위 | 현재 활성 탭에만 적용. 탭 전환 시 태그 필터 유지 |
| 빈 상태 처리 | 후기가 없을 때 "등록된 후기가 없습니다" ListEmpty 컴포넌트 렌더링 (S253, S254) |
| 손글씨 프리뷰 | 메인 화면 상단에 최대 10개 가로 스크롤. 이미지 포함 후기만 표시 |
| 만족도 퍼센트 | 별점 4점 이상 후기 비율 (서버에서 계산된 값 사용) |
| 통계 캐싱 | 통계 데이터(totalCount, avgRating, satisfactionPct)는 Server Component에서 1회 조회 후 Client에 props로 전달 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 후기 0건 | 통계 영역: "후기 0건 ★0점 만족도 0%", 리스트 영역: ListEmpty 컴포넌트 |
| 손글씨 후기 0건 | 손글씨 프리뷰 섹션 자체를 숨김 (조건부 렌더링) |
| 태그 필터 결과 0건 | "해당 분야의 후기가 없습니다" 빈 상태 표시 |
| 통계 API 실패 | 통계 영역에 "-" 표시 또는 스켈레톤 유지 |
| 리스트 API 실패 | 에러 메시지 표시 + 재시도 버튼 |
| 긴 후기 텍스트 | 최대 3줄 표시 후 "더보기" 링크로 전체 텍스트 펼침 |
| 이미지 로드 실패 | 손글씨 이미지 fallback placeholder 표시 |

---

### 3-2. 만족도 툴팁 (슬라이드 S249)

| 항목 | 내용 |
|------|------|
| 트리거 | 만족도 퍼센트 옆 (i) 아이콘 클릭 |
| UI 형태 | 팝오버(tooltip) — 말풍선 형태, 위/아래 화살표 |
| 내용 | 만족도 퍼센트 계산 기준 설명 텍스트 |
| 닫기 | 팝오버 외부 클릭 시 닫힘, (i) 아이콘 재클릭 시 닫힘 |

---

### 3-3. 회원신고 모달 (슬라이드 S255~S256)

| 항목 | 내용 |
|------|------|
| 트리거 | 후기 카드 내 회원 닉네임 영역 신고 버튼 클릭 |
| UI 형태 | 바텀시트 또는 모달 |
| 화면설계서 | S255 (사유 선택), S256 (확인) |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 모달 타이틀 | "회원신고" |
| 1 | 신고 사유 라디오 | 스팸/광고, 음란/유해, 욕설/비방, 허위후기, 기타 (5개 라디오 옵션) |
| 2 | 기타 사유 입력 | "기타" 선택 시 textarea 노출 |
| 3 | 확인 버튼 | 신고 제출. 사유 미선택 시 비활성 |
| 4 | 취소 버튼 | 모달 닫기 |

#### 상태 관리

- 로컬 상태:
  - `reportReason` — 선택된 신고 사유 (null | string)
  - `reportDetail` — 기타 사유 텍스트 (string)
  - `targetUserId` — 신고 대상 회원 ID
  - `isSubmitting` — 제출 중 로딩

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/reviews/reportUser` | POST | `{ targetUserId, reason, detail }` | `{ response: "success"|"error", msg: "" }` | 확인 버튼 클릭 |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 신고 사유 라디오 선택 | reportReason 업데이트, "기타" 선택 시 textarea 노출 |
| 확인 버튼 클릭 | API 호출 → 성공 시 "신고가 접수되었습니다" 알럿 → 모달 닫기 |
| 취소 버튼 / 외부 클릭 | 모달 닫기 (입력값 초기화) |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 사유 필수 선택 | 라디오 미선택 시 확인 버튼 비활성 |
| 기타 사유 | "기타" 선택 시 텍스트 입력 선택사항 (빈 값 허용) |
| 중복 신고 | 동일 회원 대상 중복 신고 서버에서 처리 (프론트에서는 제한 없이 전송) |
| 로그인 필수 | 비로그인 시 모달 미노출, 로그인 페이지 리다이렉트 |

---

### 3-4. 후기신고 모달 (슬라이드 S257~S258)

| 항목 | 내용 |
|------|------|
| 트리거 | 후기 카드 내 신고 아이콘/버튼 클릭 |
| UI 형태 | 바텀시트 또는 모달 |
| 화면설계서 | S257 (사유 선택), S258 (확인) |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 모달 타이틀 | "후기신고" |
| 1 | 신고 사유 라디오 | 스팸/광고, 음란/유해, 욕설/비방, 허위후기, 기타 (5개 라디오 옵션) |
| 2 | 기타 사유 입력 | "기타" 선택 시 textarea 노출 |
| 3 | 확인 버튼 | 신고 제출. 사유 미선택 시 비활성 |
| 4 | 취소 버튼 | 모달 닫기 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/reviews/reportReview` | POST | `{ reviewId, reason, detail }` | `{ response: "success"|"error", msg: "" }` | 확인 버튼 클릭 |

#### 비즈니스 규칙

회원신고 모달(3-3)과 동일한 규칙 적용. 신고 대상만 reviewId로 변경.

---

## 4. API 연동 상세

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


### 4-1. API Route (프록시 레이어)

| 프론트 경로 | 외부 API 경로 (추정) | 설명 |
|-----------|-------------------|------|
| `/api/reviews/getStats` | `/api/reviews/getStats` | 후기 통계 (건수, 평균별점, 만족도) |
| `/api/reviews/getList` | `/api/reviews/getListMobile` | 후기 리스트 (탭/정렬/태그/페이징) |
| `/api/reviews/getHandwrittenPreview` | `/api/reviews/getHandwrittenPreview` | 손글씨 후기 프리뷰 |
| `/api/reviews/reportUser` | `/api/reviews/reportUser` | 회원 신고 |
| `/api/reviews/reportReview` | `/api/reviews/reportReview` | 후기 신고 |

---

## 5. 상태 관리

### 5-1. 로컬 상태 전용

전체후기 도메인은 Zustand 전역 스토어를 사용하지 않는다. 모든 상태는 ReviewsMain 클라이언트 컴포넌트 내 로컬 상태로 관리한다.

### 5-2. 상태 흐름

```
[Server] page.js: getStats + getList(tab='all', sort='recent', offset=0)
  ↓ props: { labels, locale, initialStats, initialItems }
[Client] ReviewsMain.js
  ├── 탭 전환 → activeTab 변경 → getList(tab, sort, tag, offset=0)
  ├── 정렬 변경 → sortOrder 변경 → getList(tab, sort, tag, offset=0)
  ├── 태그 선택 → selectedTag 변경 → getList(tab, sort, tag, offset=0)
  ├── 무한 스크롤 → offset += limit → getList(tab, sort, tag, offset)
  ├── 회원신고 → ReportUserModal 오픈 → reportUser API
  └── 후기신고 → ReportReviewModal 오픈 → reportReview API
```

---

## 6. 도메인 내 컴포넌트 구조

| 컴포넌트 | 파일 위치 | Props | 역할 |
|---------|----------|-------|------|
| ReviewsMain | `_components/ReviewsMain.js` | `labels`, `locale`, `initialStats`, `initialItems` | 전체후기 메인 클라이언트 컴포넌트 |
| ReviewCard | 공유 후보 (`components/ReviewCard.js` 또는 도메인 내부) | `review`, `labels`, `onReportUser`, `onReportReview` | 개별 후기 카드 렌더링 |
| HandwrittenPreview | `_components/HandwrittenPreview.js` | `items`, `totalCount`, `labels`, `onViewMore` | 손글씨 후기 가로 스크롤 프리뷰 |
| TagFilter | `_components/TagFilter.js` | `tags`, `selectedTag`, `onTagSelect` | 분야 태그 칩 필터 |
| SortDropdown | `_components/SortDropdown.js` | `sortOrder`, `onSortChange`, `labels` | 정렬 드롭다운 |
| SatisfactionTooltip | `_components/SatisfactionTooltip.js` | `isVisible`, `onClose`, `labels` | 만족도 설명 팝오버 |
| ReportUserModal | `_components/ReportUserModal.js` | `isOpen`, `targetUserId`, `labels`, `onClose`, `onSubmit` | 회원신고 바텀시트/모달 |
| ReportReviewModal | `_components/ReportReviewModal.js` | `isOpen`, `reviewId`, `labels`, `onClose`, `onSubmit` | 후기신고 바텀시트/모달 |
| PageNavBar | `app/[locale]/_components/PageNavBar.js` | `locale`, `title`, `homeLabel` | 공유 컴포넌트 |

---

## 7. 크로스 도메인 의존성

- **의존**: layout (PageNavBar, Footer, Header), search (후기검색 링크), login (신고/후기쓰기 시 인증 필수)
- **피의존**: phone-consultation 프로필>후기 탭 (ReviewCard 공유), chat-consultation 프로필>후기 탭 (ReviewCard 공유), search>후기 탭 (ReviewCard 공유)
- **공유 컴포넌트**: ReviewCard — 전체후기, 전화상담 프로필, 채팅상담 프로필, 검색 결과에서 동일 카드 사용
- **공유 컴포넌트**: ReportModal (회원/후기 신고) — 전체후기, 프로필>후기에서 동일 모달 사용

---

## 8. 미확정 사항

- [ ] 후기쓰기 페이지 경로: 별도 페이지인지, 모달/바텀시트인지 미정
- [ ] 후기 작성 보상 코인 수량: 정확한 코인 보상 금액 미정
- [ ] 손글씨 후기 이미지 업로드 방식: 카메라 촬영/갤러리 선택 등 상세 미정
- [ ] 분야 태그 목록: 고정 태그인지 서버에서 동적 로딩인지 미정
- [ ] 만족도 계산 기준: 별점 4점 이상 비율인지 다른 기준인지 서버 로직 미확인
- [ ] "도움이돼요" 기능 상세: 비로그인 시 동작, 중복 클릭 방지 등 미정
- [ ] 상담후기 운영정책 페이지 경로: 약관/정책 페이지 라우트 미정
- [ ] 후기 카드에서 상담사 프로필 이동 시 전화/채팅 구분 로직: counselorType 필드 필요 여부 미확인
- [ ] 무한 스크롤 vs 더보기 버튼: 페이징 UX 방식 미확정
- [ ] 후기 텍스트 최대 표시 줄 수: 3줄인지 다른 기준인지 미확정
- [ ] 신고 사유 목록: 고정 목록인지 서버에서 동적 로딩인지 미정
