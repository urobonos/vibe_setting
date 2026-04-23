# Frontend Functional Spec — 전화상담

> Source: 화면설계서 PPTX Slides S62~S132
> Status: DRAFT
> Updated: 2026-03-24

---

## 1. 개요

- **도메인 목적**: 코인 기반 전화 상담 서비스의 핵심 매출 기능. 상담사 탐색(메인/카테고리), 상담사 프로필 확인, 전화상담 연결까지의 전체 플로우를 담당한다.
- **사용자 목표**: 원하는 분야/스타일의 상담사를 탐색하고, 프로필/후기를 확인한 뒤, 전화상담을 신청한다.
- **구현 상태**: 미구현
- **테마 컬러**: GREEN (`--green-1: #00af79`, `--green-2: #00af79`) — 채팅상담(PURPLE)과 시각적으로 구분
- **서브 도메인**: 메인(상담사 리스트), 카테고리 리스트(필터 시스템), 프로필 상세(5개 탭 + 상담하기 CTA)
- **슬라이드 범위**: S62~S132 (71장) — 전체 화면설계서에서 최대 규모 도메인 중 하나

---

## 2. 라우트 구조

| 라우트 | page.js 위치 | 동적 파라미터 | 인증 필요 | 슬라이드 |
|--------|-------------|-------------|---------|---------|
| `/[locale]/call` | `app/[locale]/call/page.js` | locale | 아니오 | S63~S69 |
| `/[locale]/call/category/[cate]` | `app/[locale]/call/category/[cate]/page.js` | locale, cate | 아니오 | S70~S91 |
| `/[locale]/call/profile/[id]` | `app/[locale]/call/profile/[id]/page.js` | locale, id | 아니오 | S92~S132 |

### 라우트 상세

- `[cate]` 파라미터: 카테고리 슬러그 (`all`, `tarot`, `saju`, `spiritual`, `event`, `review`)
- `[id]` 파라미터: 상담사 고유 ID (숫자)
- 비로그인 사용자도 리스트/프로필 열람 가능, 상담하기 버튼 클릭 시 로그인 페이지로 리다이렉트

---

## 3. 페이지 정의

### 3-1. 전화상담 메인 (슬라이드 S63~S69)

- **라우트**: `/[locale]/call`
- **Server/Client 분리**: `page.js`(Server) → `CallMain.js`(Server, fetch) → `CallMainItems.js`(Client, 인터랙션)
- **UI 섹션** (상→하 순서):
  1. **TOP 영역**: 홍카페 로고 + 검색 아이콘 (공유 Header 컴포넌트)
  2. **Tab 영역**: 전화상담(green, 활성) / 채팅상담(purple, 비활성) 탭 전환
  3. **메인 배너**: Swiper 슬라이드 배너 (프로모션/이벤트)
  4. **리스트보기 토글**: 그리드 뷰(기본) / 리스트 뷰 전환 아이콘
  5. **카테고리 탭**: 가로 스크롤 — 전체, 타로, 사주성명, 영감영시, 이벤트, 후기
  6. **상담사 리스트 탭**: 추천 / 신규 / 급상승 / 상담중 4개 서브탭
  7. **상담사 카드 리스트**: CounselorCard 그리드/리스트 뷰
  8. **하단 GNB**: 공유 Footer 컴포넌트

- **상담사 리스트 서브탭 정의 (S68~S69)**:
  | 서브탭 | 정렬 기준 | 설명 |
  |-------|---------|------|
  | 추천 | 홍카페 추천 로직 | 운영팀 큐레이션 + 알고리즘 |
  | 신규 | 최근 등록순 | 최근 데뷔한 상담사 |
  | 급상승 | 감정시간 급상승 | 최근 상담 시간 증가율 기준 |
  | 상담중 | 현재 상담 진행 중 | 실시간 상담 중인 상담사만 표시 |

- **비로그인 상태 (S66)**:
  - 배너: "회원가입 시 30,000 코인 선물!" 프로모션 배너 노출
  - 하단 GNB: "로그인" 텍스트 표시 (마이메뉴 대신)
  - 상담사 리스트: 정상 노출 (열람 가능)
  - 상담하기 버튼 클릭 시: 로그인 페이지 리다이렉트

- **그리드 뷰 vs 리스트 뷰 (S65, S67)**:
  | 항목 | 그리드 뷰 (기본) | 리스트 뷰 |
  |------|----------------|---------|
  | 레이아웃 | 2열 그리드 (grid-cols-2) | 1열 리스트 |
  | 프로필 이미지 | 상단 배치, 대형 | 좌측 배치, 소형 |
  | 정보 노출 | 닉네임, 카테고리, 코인, 상태 | 닉네임, 카테고리, 스타일태그, 후기통계, 코인, 상태 |
  | 상태 보존 | 뷰 전환 시 스크롤 위치 유지 | 뷰 전환 시 스크롤 위치 유지 |

- **상태 관리**:
  - `useCateStore`: 현재 활성 카테고리 (전체/타로/사주/영감영시/이벤트/후기)
  - `useViewStore` (신규): 그리드/리스트 뷰 토글 상태
  - 로컬 상태: 활성 서브탭 (추천/신규/급상승/상담중), 배너 인덱스, 스크롤 위치

- **API 연동**:
  | 엔드포인트 | Method | Request Body | Response |
  |-----------|--------|-------------|----------|
  | `/api/call/getListMobile` | POST | `{ offset, limit, cate, subTab, locale }` | `{ response, items: CounselorCard[], total }` |
  | `/api/call/getBanners` | POST | `{ locale, type: 'call' }` | `{ banners: Banner[] }` |

- **무한 스크롤**: 상담사 리스트는 IntersectionObserver 기반 무한 스크롤. `offset` 증분으로 다음 페이지 fetch.
- **i18n 네임스페이스**: `call`
- **외부 의존성**: Swiper v12 (메인 배너)

---

### 3-2. 카테고리 리스트 (슬라이드 S70~S91)

- **라우트**: `/[locale]/call/category/[cate]`
- **Server/Client 분리**: `page.js`(Server) → `CategoryList.js`(Server, fetch) → `CategoryListItems.js`(Client, 필터/정렬/무한스크롤)
- **UI 섹션** (상→하 순서):
  1. **카테고리 TOP**: 카테고리명 표시 + 뒤로가기 아이콘 (green 테마)
  2. **하위 카테고리 탭**: 전체, 영감영시, 타로, 사주성명 (S71~S72)
  3. **필터 바**: 정렬 + 스타일 + 분야 + 상담코인 필터 칩 / "상담가능만 보기" 토글
  4. **활성 필터 표시**: 선택된 필터 칩 나열 (제거 가능)
  5. **상담사 리스트**: CounselorCard 리스트 (필터 적용 결과)
  6. **하단 GNB**: 공유 Footer 컴포넌트

- **필터 시스템 상세**:

  #### 3-2-1. 정렬 필터 (S73~S74)
  바텀시트로 표시. 단일 선택 (라디오).

  | 정렬 옵션 | 정렬 로직 |
  |---------|---------|
  | 홍카페순 (기본) | 상담중 > 가능 > 부재중, 동일 상태 내 점수순 > 시간순 |
  | 최근등록순 | 등록일 내림차순 |
  | 만점많은순 (3개월) | 최근 3개월 만점(5점) 후기 수 내림차순 |
  | 만점많은순 (누적) | 전체 기간 만점 후기 수 내림차순 |
  | 후기많은순 (3개월) | 최근 3개월 후기 총 수 내림차순 |
  | 후기많은순 (누적) | 전체 기간 후기 총 수 내림차순 |
  | 상담많은순 (3개월) | 최근 3개월 상담 건수 내림차순 |
  | 상담많은순 (누적) | 전체 기간 상담 건수 내림차순 |

  #### 3-2-2. 스타일 필터 (S75~S77)
  바텀시트로 표시. 최대 3개 다중 선택. 4개 이상 선택 시 경고 알럿("최대 3개까지 선택할 수 있습니다").

  | 스타일 태그 (9개) |
  |----------------|
  | 정확해요, 편안해요, 깊이있어요, 친절해요, 공감해요, 솔직해요, 쉽게설명해요, 답변이빨라요, 목소리가좋아요 |

  #### 3-2-3. 분야 필터 (S78~S80)
  바텀시트로 표시. 최대 3개 다중 선택. 4개 이상 선택 시 경고 알럿.

  | 분야 태그 (25개) |
  |----------------|
  | 연애운, 가족, 짝사랑, 건강, 궁합, 고민, 이별, 이사, 재회, 꿈해몽, 원거리, 인간관계, 삼각관계, 재물, 바람, 사업, 속마음, 취업, 불륜, 진로, 결혼, 시험, 이혼, 합격, 재혼 |

  #### 3-2-4. 상담코인 필터 (S81)
  코인 범위 필터. 최소/최대 코인 입력 또는 슬라이더.

  #### 3-2-5. 상담가능만 보기 토글 (S83)
  ON: 상담가능 상태인 상담사만 표시 (상담중/부재중 제외).
  OFF: 모든 상태 표시 (기본값).

- **필터 적용 동작 (S82)**:
  - 필터 바텀시트 하단 "적용" 버튼 클릭 시 필터 반영
  - 상단 필터 칩 영역에 선택된 필터 표시 (예: "편안해요 x", "연애운 x")
  - 개별 칩 x 버튼으로 필터 해제 가능
  - "전체 초기화" 버튼으로 모든 필터 리셋

- **페이백/100코인특가 이벤트 카테고리 (S84~S91)**:
  - 이벤트 카테고리 진입 시 별도 UI
  - 탭: 참여가능 / 참여완료
  - 페이백: 상담 후 코인 환급 이벤트 상담사 리스트
  - 100코인특가: 특가 상담 상담사 리스트
  - 카테고리 필터 적용 가능

- **상태 관리**:
  - `useFilterStore` (신규): 정렬, 스타일(배열, 최대3), 분야(배열, 최대3), 코인 범위, 상담가능만 토글
  - 로컬 상태: 활성 하위 카테고리, 바텀시트 열림/닫힘, 이벤트 탭(참여가능/참여완료)

- **API 연동**:
  | 엔드포인트 | Method | Request Body | Response |
  |-----------|--------|-------------|----------|
  | `/api/call/getCategoryList` | POST | `{ cate, subCate, sort, styles[], fields[], coinMin, coinMax, availableOnly, offset, limit, locale }` | `{ response, items: CounselorCard[], total, filters }` |
  | `/api/call/getEventList` | POST | `{ eventType, status, cate, offset, limit, locale }` | `{ response, items: EventCounselorCard[], total }` |

- **무한 스크롤**: 카테고리 리스트도 IntersectionObserver 기반.
- **i18n 네임스페이스**: `callCategory`
- **외부 의존성**: 없음

---

### 3-3. 프로필 상세 (슬라이드 S92~S132)

- **라우트**: `/[locale]/call/profile/[id]`
- **Server/Client 분리**: `page.js`(Server, 상담사 데이터 fetch) → `ProfileDetail.js`(Client, 5개 탭 전환 + 인터랙션)
- **UI 섹션** (상→하 순서):
  1. **프로필 TOP**: [카테고리] 상담사명 [번호] + Home 버튼 (green 테마)
  2. **배너 이미지**: 상담사 개인 배너 (없으면 기본 배너)
  3. **상담사 기본 정보**: 프로필 이미지 + 닉네임 + 카테고리 + 코인/30초 + 파트너/신규 배지 (S95)
  4. **탭 네비게이션**: 판매상품 / 상세정보 / 후기 / 1:1문의 / 포스팅 (5개 탭)
  5. **탭 콘텐츠 영역**: 선택된 탭에 따라 동적 렌더링
  6. **하단 상담 네비게이션**: 단골 토글 + 상담하기 버튼 (3가지 상태)

- **프로필 헤더 상세 (S93~S95)**:
  - 상단: `[카테고리] 상담사명 [번호]` 형식 (예: `[타로] 미즈키 선생님 [1234]`)
  - 배지: 파트너(제휴 상담사), 신규(최근 등록) — 닉네임 옆 표시
  - 공유 버튼: 오른쪽 상단, 클릭 시 ShareBottomSheet (S96)
  - 인사말: 상담사 자기소개 텍스트
  - 후기 통계: 최근 3개월 기준 — 총 후기 수, 평균 별점
  - 스타일 태그: 최대 3개 태그 표시 (chip 형태)
  - 분야 태그: 해당 상담사 전문 분야 표시

- **5개 탭 콘텐츠**:

  #### 3-3-1. 판매상품 탭 (S99)
  - 전화상담 / 채팅상담 상품 카드 리스트
  - 상품 카드: 상품명 + 설명 + 코인/단위 + 구매 버튼
  - 전화상담 상품과 채팅상담 상품을 구분하여 표시

  #### 3-3-2. 상세정보 탭 (S93~S101)
  - 기본 정보: 경력, 자격, 상담 가능 시간 등
  - 서비스 소개: 긴 텍스트 영역, "전체보기" / "닫기" 토글 (S100~S101)
  - FAQ: 아코디언(Accordion) 형태, 질문 클릭 시 답변 펼침/접기
  - 별점 통계: 바(bar) 그래프 형태 — 5점~1점 분포 (S97~S98)
  - 별점 없는 경우: "아직 후기가 없습니다" 안내 (S98)

  #### 3-3-3. 후기 탭 (S103~S116)
  - 서브탭: 전체 / 베스트 / 손글씨 (3개)
  - 만족도 퍼센트: 전체 만족도 % 표시
  - 후기 카드: ReviewCard (닉네임 + 별점 + 텍스트 + 날짜 + 신고 버튼)
  - 손글씨 후기: 이미지 카드, 클릭 시 확대 보기 (S109~S110)
  - 회원 신고 (S111~S112): 사유 선택 (욕설/비방, 허위사실, 부적절 내용, 기타) → 확인 버튼
  - 후기 신고 (S113~S114): 사유 선택 → 확인 버튼
  - 블라인드 처리 (S115~S116): 신고 접수된 후기는 블라인드 표시 ("관리자에 의해 블라인드 처리된 후기입니다")
  - 무한 스크롤: 후기 리스트 IntersectionObserver 기반

  #### 3-3-4. 1:1문의 탭 (S117~S119)
  - 상단 안내: "알려드립니다" 박스 — 개인정보 금지 안내, 문의 작성 가이드
  - 문의 리스트: 제목 + 작성일 + 답변 상태(대기/완료) + 내용 펼치기
  - "나의 문의 보기" 토글 ON: 내가 작성한 문의만 필터링 (로그인 필수)
  - 문의 쓰기 버튼: 클릭 시 문의 작성 폼 — 제목 + 내용 입력 (개인정보 금지 안내 표시)
  - 문의 작성 시 로그인 필수

  #### 3-3-5. 포스팅 탭 (S120~S123)
  - 포스팅 카드: PostingCard (제목 + 썸네일 + 조회수 + 추천수 + 작성일)
  - 공유 기능: 개별 포스팅 공유 버튼
  - 댓글: 포스팅 하단 댓글 리스트 + 댓글 작성 (로그인 필수)

- **공유 바텀시트 (S96)**:
  - 트리거: 프로필 헤더 공유 버튼, 포스팅 공유 버튼
  - 옵션: 카카오톡, LINE, 링크 복사 (국가별 상이)

- **상태 관리**:
  - 로컬 상태: 활성 탭 인덱스, 서비스 소개 펼침 여부, FAQ 아코디언 상태, 후기 서브탭, 나의 문의 보기 토글, 공유 바텀시트 열림/닫힘
  - `useAuthStore` (추정): 로그인 상태 확인 (문의 쓰기, 댓글, 단골, 상담하기)
  - `useCoinStore` (추정): 보유 코인 잔액 (상담하기 시 잔액 체크)

- **API 연동**:
  | 엔드포인트 | Method | Request Body | Response |
  |-----------|--------|-------------|----------|
  | `/api/call/getProfile` | POST | `{ counselorId, locale }` | `{ response, profile: CounselorProfile }` |
  | `/api/call/getProducts` | POST | `{ counselorId, locale }` | `{ response, products: Product[] }` |
  | `/api/call/getReviews` | POST | `{ counselorId, tab, offset, limit }` | `{ response, reviews: Review[], total, satisfaction }` |
  | `/api/call/getInquiries` | POST | `{ counselorId, myOnly, offset, limit }` | `{ response, inquiries: Inquiry[] }` |
  | `/api/call/postInquiry` | POST | `{ counselorId, title, content }` | `{ response, inquiryId }` |
  | `/api/call/getPostings` | POST | `{ counselorId, offset, limit }` | `{ response, postings: Posting[] }` |
  | `/api/call/postComment` | POST | `{ postingId, content }` | `{ response, commentId }` |
  | `/api/call/reportMember` | POST | `{ targetId, reason }` | `{ response }` |
  | `/api/call/reportReview` | POST | `{ reviewId, reason }` | `{ response }` |
  | `/api/call/toggleFavorite` | POST | `{ counselorId }` | `{ response, isFavorite }` |
  | `/api/call/getStats` | POST | `{ counselorId }` | `{ response, ratings: RatingDist, totalReviews }` |

- **i18n 네임스페이스**: `callProfile`
- **외부 의존성**: 없음

---

### 3-4. 상담하기 (슬라이드 S124~S132)

- **위치**: 프로필 상세 페이지 하단 고정 영역
- **컴포넌트**: `ConsultationBottomNav.js` (Client Component)
- **UI 구성**:
  - 좌측: 단골(즐겨찾기) 토글 버튼 — 하트/별 아이콘, 클릭 시 단골 등록/해제
  - 우측: "상담하기" CTA 버튼 — 상담사 상태에 따라 3가지 변형

- **상담사 상태별 CTA (3가지)**:
  | 상태 | 버튼 텍스트 | 버튼 스타일 | 클릭 동작 |
  |------|-----------|-----------|---------|
  | 상담가능 | 상담하기 | green 활성 (`bg-[#00af79]`, 풀폭) | 상담하기 팝업 표시 |
  | 상담중 | 상담중 | 비활성 (회색) + "접속알림신청" 보조 버튼 | 접속 알림 신청 API 호출 |
  | 부재중 | 부재중 | 비활성 (회색) + "접속알림신청" 보조 버튼 | 접속 알림 신청 API 호출 |

- **상담하기 팝업 플로우 (S124~S132)**:

  #### 3-4-1. 비로그인 상태
  - 팝업: "로그인이 필요합니다" 안내
  - 확인 버튼 → 로그인 페이지 리다이렉트 (`/[locale]/login`)

  #### 3-4-2. 로그인 + 코인 잔액 5,000 미만
  - 팝업: "코인이 부족합니다. 최소 5,000코인이 필요합니다." 안내
  - 충전하기 버튼 → 코인 충전 페이지 리다이렉트 (`/[locale]/coin`)
  - 취소 버튼 → 팝업 닫기

  #### 3-4-3. 로그인 + 코인 잔액 5,000 이상 (정상)
  - 팝업: 상담사 정보 요약 + 코인/30초 + 예상 소요 코인 안내
  - 상담하기 확인 버튼 → 전화 연결 API 호출
  - 취소 버튼 → 팝업 닫기

  #### 3-4-4. 페이백 상담 (S128~S129)
  - 페이백 이벤트 대상 상담사인 경우 별도 안내
  - 팝업에 "페이백 N코인 환급" 정보 추가 표시

  #### 3-4-5. 100코인 특가 (S130~S131)
  - 100코인 특가 대상 상담사인 경우 별도 안내
  - 팝업에 "100코인 특가" 배지 + 할인 정보 표시

  #### 3-4-6. 접속 알림 신청 (S132)
  - 부재중/상담중 상담사에게 접속 시 알림 요청
  - 로그인 필수
  - 성공 시 토스트: "접속 알림이 신청되었습니다"

- **상태 관리**:
  - 로컬 상태: 팝업 열림/닫힘, 팝업 유형 (비로그인/코인부족/정상/페이백/특가)
  - `useAuthStore`: 로그인 여부 판단
  - `useCoinStore`: 보유 코인 잔액

- **API 연동**:
  | 엔드포인트 | Method | Request Body | Response |
  |-----------|--------|-------------|----------|
  | `/api/call/startConsultation` | POST | `{ counselorId, productId }` | `{ response, sessionId, phoneNumber }` |
  | `/api/call/requestNotification` | POST | `{ counselorId }` | `{ response }` |
  | `/api/coin/getBalance` | POST | `{}` | `{ response, balance }` |

---

## 4. 공유 컴포넌트

### 4-1. 도메인 내부 공유 컴포넌트

| 컴포넌트 | 사용 위치 | Props | 비고 |
|---------|---------|-------|------|
| `CounselorCard` | 메인, 카테고리 | `counselor`, `viewType`, `locale` | 그리드/리스트 뷰 대응 |
| `FilterBottomSheet` | 카테고리 | `type`, `options`, `selected`, `maxCount`, `onApply`, `onClose` | 정렬/스타일/분야/코인 4종 |
| `FilterChip` | 카테고리 | `label`, `onRemove` | 활성 필터 칩 |
| `ProfileTabs` | 프로필 | `activeTab`, `onTabChange`, `tabs` | 5개 탭 네비게이션 |
| `ReviewCard` | 프로필>후기 | `review`, `onReport` | 후기 카드 |
| `HandwritingViewer` | 프로필>후기>손글씨 | `imageUrl`, `onClose` | 손글씨 확대 보기 |
| `ReportModal` | 프로필>후기 | `type`, `onSubmit`, `onClose` | 회원/후기 신고 |
| `InquiryForm` | 프로필>1:1문의 | `counselorId`, `onSubmit` | 문의 작성 폼 |
| `PostingCard` | 프로필>포스팅 | `posting`, `onShare` | 포스팅 카드 |
| `ShareBottomSheet` | 프로필 | `url`, `title`, `onClose` | 공유 옵션 |
| `ConsultationBottomNav` | 프로필 | `counselor`, `locale`, `labels` | 단골+상담하기 CTA |
| `ConsultationPopup` | 프로필 | `type`, `counselor`, `balance`, `onConfirm`, `onClose` | 상담하기 팝업 |
| `RatingChart` | 프로필>상세정보 | `ratings` | 별점 바 그래프 |
| `AccordionFAQ` | 프로필>상세정보 | `items` | FAQ 아코디언 |

### 4-2. 크로스 도메인 공유 컴포넌트

| 컴포넌트 | 사용 도메인 | 경로 (추정) |
|---------|-----------|-----------|
| `CounselorCard` | 전화상담, 채팅상담, 검색, 단골 | `components/CounselorCard.js` |
| `FilterBottomSheet` | 전화상담, 채팅상담, 검색 | `components/FilterBottomSheet.js` |
| `ReviewCard` | 전화상담, 채팅상담, 전체후기, 검색 | `components/ReviewCard.js` |
| `ReportModal` | 전화상담, 채팅상담, 전체후기 | `components/ReportModal.js` |
| `PostingCard` | 전화상담, 채팅상담, 카테고리 | `components/PostingCard.js` |
| `ShareBottomSheet` | 전화상담, 채팅상담, 포스팅 | `components/ShareBottomSheet.js` |
| `ConsultationBottomNav` | 전화상담, 채팅상담 | `components/ConsultationBottomNav.js` |
| `PageNavBar` | 전화상담, 채팅상담, 로그인, 회원가입 등 | `app/[locale]/_components/PageNavBar.js` (기구현) |

---

## 5. API 연동 추정

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


### 5-1. 전체 엔드포인트 목록

| # | 엔드포인트 | Method | 용도 | 인증 |
|---|-----------|--------|------|------|
| 1 | `/api/call/getListMobile` | POST | 메인 상담사 리스트 | 불필요 |
| 2 | `/api/call/getBanners` | POST | 메인 배너 | 불필요 |
| 3 | `/api/call/getCategoryList` | POST | 카테고리별 상담사 리스트 (필터 포함) | 불필요 |
| 4 | `/api/call/getEventList` | POST | 이벤트(페이백/특가) 상담사 리스트 | 불필요 |
| 5 | `/api/call/getProfile` | POST | 상담사 프로필 상세 | 불필요 |
| 6 | `/api/call/getProducts` | POST | 판매상품 리스트 | 불필요 |
| 7 | `/api/call/getReviews` | POST | 후기 리스트 (전체/베스트/손글씨) | 불필요 |
| 8 | `/api/call/getStats` | POST | 별점 통계 | 불필요 |
| 9 | `/api/call/getInquiries` | POST | 1:1문의 리스트 | 선택 (나의문의) |
| 10 | `/api/call/postInquiry` | POST | 문의 작성 | 필수 |
| 11 | `/api/call/getPostings` | POST | 포스팅 리스트 | 불필요 |
| 12 | `/api/call/postComment` | POST | 댓글 작성 | 필수 |
| 13 | `/api/call/reportMember` | POST | 회원 신고 | 필수 |
| 14 | `/api/call/reportReview` | POST | 후기 신고 | 필수 |
| 15 | `/api/call/toggleFavorite` | POST | 단골 등록/해제 | 필수 |
| 16 | `/api/call/startConsultation` | POST | 상담 시작 | 필수 |
| 17 | `/api/call/requestNotification` | POST | 접속 알림 신청 | 필수 |
| 18 | `/api/coin/getBalance` | POST | 코인 잔액 조회 | 필수 |

### 5-2. 주요 데이터 모델 (추정)

```js
// CounselorCard
{
    counselorId: Number,
    nickname: String,           // "미즈키 선생님"
    nicknameKana: String,       // "ミヅキ" (JP 전용, 가타카나)
    category: String,           // "tarot" | "saju" | "spiritual"
    categoryLabel: String,      // "타로" | "사주성명" | "영감영시"
    profileImage: String,       // URL
    styleTags: String[],        // ["정확해요", "편안해요"]
    fieldTags: String[],        // ["연애운", "궁합"]
    coinPer30s: Number,         // 코인/30초
    status: String,             // "available" | "busy" | "away"
    rating: Number,             // 평균 별점 (0~5)
    reviewCount3m: Number,      // 최근 3개월 후기 수
    reviewCountTotal: Number,   // 누적 후기 수
    isPartner: Boolean,         // 파트너 배지
    isNew: Boolean,             // 신규 배지
    number: Number,             // 상담사 번호
}

// CounselorProfile (상세)
{
    ...CounselorCard,
    bannerImage: String,        // 배너 URL
    greeting: String,           // 인사말
    career: String,             // 경력
    qualifications: String[],   // 자격 사항
    availableHours: String,     // 상담 가능 시간
    serviceIntro: String,       // 서비스 소개 (긴 텍스트)
    faq: { question: String, answer: String }[],
    satisfaction: Number,       // 만족도 %
    ratingDistribution: { star5: N, star4: N, star3: N, star2: N, star1: N },
}

// Review
{
    reviewId: Number,
    authorNickname: String,
    rating: Number,             // 1~5
    content: String,
    date: String,               // "2026-03-24"
    isHandwritten: Boolean,     // 손글씨 여부
    handwrittenImage: String,   // 손글씨 이미지 URL
    isBlinded: Boolean,         // 블라인드 처리 여부
}

// Inquiry
{
    inquiryId: Number,
    title: String,
    content: String,
    date: String,
    status: String,             // "waiting" | "answered"
    answer: String,             // 답변 내용 (status=answered일 때)
    authorId: Number,
}

// Posting
{
    postingId: Number,
    title: String,
    thumbnail: String,
    viewCount: Number,
    likeCount: Number,
    date: String,
    comments: Comment[],
}

// Product
{
    productId: Number,
    name: String,
    description: String,
    type: String,               // "call" | "chat"
    coinPerUnit: Number,
    unit: String,               // "30초" | "1건"
}
```

---

## 6. 상태 관리

### 6-1. Zustand 스토어

| 스토어 | 파일명 (추정) | 상태 | 사용 위치 |
|--------|-------------|------|---------|
| `useCateStore` | `store/useCateStore.js` | `cate` (활성 카테고리) | 메인, 카테고리 |
| `useViewStore` | `store/useViewStore.js` | `viewType` (grid/list) | 메인, 카테고리 |
| `useFilterStore` | `store/useFilterStore.js` | `sort`, `styles[]`, `fields[]`, `coinRange`, `availableOnly` | 카테고리 |
| `useAuthStore` | `store/useAuthStore.js` | `isLoggedIn`, `user` | 프로필 (상담하기, 문의, 댓글, 단골) |
| `useCoinStore` | `store/useCoinStore.js` | `balance` | 프로필 (상담하기 팝업) |

### 6-2. 로컬 상태 (각 Client Component 내부)

| 페이지 | 상태 | 설명 |
|--------|------|------|
| 메인 | `activeSubTab` | 추천/신규/급상승/상담중 |
| 메인 | `items`, `offset`, `isLoading` | 무한 스크롤 제어 |
| 카테고리 | `activeSubCate` | 하위 카테고리 활성 탭 |
| 카테고리 | `isFilterOpen`, `filterType` | 바텀시트 제어 |
| 카테고리 | `activeChips` | 적용된 필터 칩 목록 |
| 프로필 | `activeTab` | 5개 탭 인덱스 (0~4) |
| 프로필 | `isServiceExpanded` | 서비스 소개 전체보기 토글 |
| 프로필 | `faqOpenIndex` | FAQ 아코디언 열린 인덱스 |
| 프로필 | `reviewSubTab` | 전체/베스트/손글씨 |
| 프로필 | `myInquiryOnly` | 나의 문의 보기 토글 |
| 프로필 | `isShareOpen` | 공유 바텀시트 |
| 프로필 | `popupType` | 상담하기 팝업 유형 |
| 프로필 | `isFavorite` | 단골 등록 상태 |

---

## 7. 크로스 도메인 의존성

```
전화상담 메인 ← 레이아웃 (Header, Footer, MainTab)
전화상담 메인 → 카테고리 리스트 (카테고리 탭 클릭 시)
전화상담 메인 → 프로필 상세 (상담사 카드 클릭 시)
전화상담 메인 → 검색 (검색 아이콘 클릭 시)

카테고리 리스트 ← 전화상담 메인 (카테고리 탭에서 진입)
카테고리 리스트 → 프로필 상세 (상담사 카드 클릭 시)

프로필 상세 ← 전화상담 메인, 카테고리, 검색, 단골
프로필 상세 → 로그인 (비로그인 상담하기 시)
프로필 상세 → 코인 충전 (잔액 부족 시)
프로필 상세 → 채팅상담 프로필 (판매상품 탭에서 채팅상품 선택 시)

상담하기 CTA → 로그인 (비로그인 시)
상담하기 CTA → 코인 충전 (잔액 부족 시)
상담하기 CTA ← 코인 잔액 API (잔액 체크)

의존 도메인 목록:
  - 레이아웃 (Header, Footer, MainTab)
  - 로그인 (상담하기 비로그인 리다이렉트)
  - 코인 충전 (잔액 부족 리다이렉트)
  - 검색 (메인에서 검색 아이콘)
  - 채팅상담 (탭 전환, 프로필 판매상품 내 채팅상품)
  - 단골 (단골 등록/해제)
```

---

## 8. 미확정 사항

### 8-1. 비즈니스 규칙 미확정

- [ ] 상담사 추천 로직 상세 (운영팀 큐레이션 vs 알고리즘 비중)
- [ ] 급상승 기준: 감정시간 급상승의 구체적 계산 방식 (기간, 증가율 임계값)
- [ ] 최소 코인 잔액 5,000의 정확한 수치 확인 (국가별 상이 가능성)
- [ ] 페이백 환급 비율/금액 계산 로직
- [ ] 100코인 특가 대상 선정 기준
- [ ] 접속 알림 신청 후 알림 발송 방식 (푸시, SMS, 앱 내)
- [ ] 상담사 번호 체계 ([번호]의 자릿수, 부여 규칙)
- [ ] 블라인드 처리 기준 (신고 N건 이상 자동? 관리자 수동?)
- [ ] 손글씨 후기 업로드 방식 (촬영? 파일 업로드?)

### 8-2. 기술적 미확정

- [ ] 상담사 상태(가능/중/부재) 실시간 갱신 방식 (폴링 vs WebSocket)
- [ ] 전화 연결 기술 스택 (VoIP, PSTN, 중개 서버)
- [ ] 무한 스크롤 페이지 사이즈 (한 번에 가져올 아이템 수)
- [ ] 필터 조합 시 서버사이드 vs 클라이언트사이드 필터링
- [ ] 코인 범위 필터 UI (슬라이더 vs 입력 필드)
- [ ] 공유 기능 국가별 옵션 (KR: 카카오톡, JP: LINE, US: 기타)
- [ ] 이미지 최적화: 상담사 프로필/배너 이미지 CDN 설정
- [ ] FAQ 데이터 출처 (상담사 직접 입력 vs 관리자 설정)

### 8-3. 디자인 미확정

- [ ] 그리드 뷰 상담사 카드 정확한 사이즈/간격 (Figma 시안 필요)
- [ ] 리스트 뷰 상담사 카드 레이아웃 상세 (Figma 시안 필요)
- [ ] 필터 바텀시트 높이/스크롤 동작
- [ ] 별점 바 그래프 색상/크기
- [ ] 상담하기 팝업 디자인 상세 (Figma 시안 필요)
- [ ] 페이백/100코인특가 배지 디자인

### 8-4. i18n 미확정

- [ ] 상담 스타일 태그 영어/일본어 번역 확정 (현재 한국어만 정의)
- [ ] 상담 분야 태그 25개 영어/일본어 번역 확정
- [ ] 상담사 닉네임 표시 규칙: JP는 가타카나, KR은 한글, US는 영문?
- [ ] "선생님" 호칭 국가별 처리 (JP: 先生, KR: 선생님, US: 생략?)
- [ ] 에러/안내 메시지 다국어 확정
