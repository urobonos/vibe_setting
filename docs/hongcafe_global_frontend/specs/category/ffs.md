# Frontend Functional Spec — 카테고리

> Source: 화면설계서 PPTX Slides S279~S287 (9 슬라이드)
> Status: DRAFT
> Updated: 2026-03-24

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 카테고리 (Category) |
| 사용자 목표 | 서비스 카테고리별 메인 화면에서 전화상담/채팅상담/이벤트를 탐색하고, 상담사가 올린 포스팅 콘텐츠를 열람/공유/댓글 작성한다 |
| 퍼블리싱 상태 | ❌ 미구현 |
| 기능 연동 상태 | 미연동 |
| i18n 네임스페이스 | `category`, `posting` |
| 지원 로케일 | `en`, `ko`, `ja` |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |
| 슬라이드 수 | 9장 |

### 도메인 흐름 요약

```
카테고리 메인 (/category)
  ├── 전화상담 바로가기 → /call
  ├── 채팅상담 바로가기 → /chat
  ├── 이벤트 바로가기 → /event (또는 이벤트 섹션)
  └── 포스팅 홈 (/category/posting)
        └── 포스팅 상세 (/category/posting/[id])
              ├── 공유 바텀시트
              └── 댓글 (작성/답글/삭제)
```

---

## 2. 라우트 구조

| 라우트 | page.js 위치 | 동적 파라미터 | 인증 필요 | 슬라이드 |
|--------|-------------|-------------|---------|---------|
| `/[locale]/category` | `app/[locale]/category/page.js` | locale | 아니오 | S280 |
| `/[locale]/category/posting` | `app/[locale]/category/posting/page.js` | locale | 아니오 | S281~S283 |
| `/[locale]/category/posting/[id]` | `app/[locale]/category/posting/[id]/page.js` | locale, id | 아니오 | S284~S287 |

### 라우트 상세

- `[id]` 파라미터: 포스팅 고유 ID (숫자)
- 비로그인 사용자도 포스팅 열람 가능, 댓글 작성 시 로그인 필요

---

## 3. 페이지 정의

### 3-1. 카테고리 메인 (슬라이드 S280)

- **라우트**: `/[locale]/category`
- **Server/Client 분리**: `page.js`(Server) → `CategoryMain.js`(Client)
- **UI 섹션** (상→하 순서):
  1. **Header**: 공유 Header 컴포넌트 (로고 + 검색)
  2. **이벤트 배너**: "매일 홍카페에서 열리는 다양한" 이벤트 안내 배너 / Swiper 슬라이드
  3. **전화상담 카드**: 카테고리 카드 — "누구에게도 말할 수 없는 당신의 고민을 전화상담에서 상담사에게 알려주세요" 설명 텍스트 + 아이콘/이미지. 클릭 시 `/[locale]/call`로 이동
  4. **채팅상담 카드**: 카테고리 카드 — "상담을 받으면서 메모는 불필요! 채팅 종료 후 1주일, 감정 내용을 확인하실 수 있습니다" 설명 텍스트 + 아이콘/이미지. 클릭 시 `/[locale]/chat`로 이동
  5. **이벤트 카드**: 카테고리 카드 — "매일 홍카페에서 열리는 다양한" 이벤트 안내. 클릭 시 이벤트 섹션 이동
  6. **하단 GNB**: 공유 Footer 컴포넌트

- **상태 관리**:
  - 로컬 상태: 배너 Swiper 인덱스
  - Zustand 스토어: 사용하지 않음

- **API 연동**:
  | 엔드포인트 | Method | Request Body | Response |
  |-----------|--------|-------------|----------|
  | `/api/category/getBanners` | POST | `{ locale }` | `{ banners: Banner[] }` |

- **사용자 인터랙션**:
  - 이벤트 배너 스와이프/자동 재생
  - 전화상담 카드 클릭 → `/[locale]/call`
  - 채팅상담 카드 클릭 → `/[locale]/chat`
  - 이벤트 카드 클릭 → 이벤트 페이지/섹션
- **i18n 네임스페이스**: `category`
  - 주요 키: `phoneTitle`, `phoneDesc`, `chatTitle`, `chatDesc`, `eventTitle`, `eventDesc`
- **외부 의존성**: Swiper v12 (이벤트 배너)

---

### 3-2. 포스팅 홈 (슬라이드 S281~S283)

- **라우트**: `/[locale]/category/posting`
- **Server/Client 분리**: `page.js`(Server) → `PostingList.js`(Server, fetch) → `PostingListItems.js`(Client, 인터랙션)
- **UI 섹션** (상→하 순서):
  1. **PageNavBar**: 상단바 (뒤로가기 + 타이틀 "포스팅" + Home 버튼)
  2. **페이지 설명**: "홍카페 선생님이 올리는 콘텐츠" 설명 텍스트
  3. **검색 입력 영역**: 포스팅 검색 input (키워드 기반)
  4. **베스트 포스팅만 보기 토글**: 베스트 포스팅 필터 on/off 토글
  5. **포스팅 카드 리스트**: 포스팅 카드 목록 (썸네일, 제목, 상담사 정보, 날짜, 조회수, 추천수)
  6. **하단 GNB**: 공유 Footer 컴포넌트

- **포스팅 카드 구성**:
  | 필드 | 설명 |
  |------|------|
  | 썸네일 이미지 | 포스팅 대표 이미지 |
  | 제목 | 포스팅 타이틀 |
  | 상담사 정보 | 프로필 이미지 + 닉네임 |
  | 작성일 | YYYY.MM.DD 형식 |
  | 조회수 | 누적 조회수 |
  | 추천수 | 좋아요/추천 카운트 |

- **상태 관리**:
  - 로컬 상태: 검색 키워드, 베스트 포스팅 필터 활성 여부, 포스팅 목록, offset
  - Zustand 스토어: 사용하지 않음

- **API 연동**:
  | 엔드포인트 | Method | Request Body | Response |
  |-----------|--------|-------------|----------|
  | `/api/category/getPostingList` | POST | `{ offset, limit, keyword, bestOnly, locale }` | `{ response, items: Posting[], total }` |

- **사용자 인터랙션**:
  - 검색어 입력 → 포스팅 필터링 (debounce 적용)
  - 베스트 포스팅만 보기 토글 클릭 → 베스트 포스팅만 필터링
  - 포스팅 카드 클릭 → `/[locale]/category/posting/[id]` 상세 이동
  - 무한 스크롤: IntersectionObserver 기반 offset 증분 fetch
- **i18n 네임스페이스**: `posting`
  - 주요 키: `navTitle`, `homeBtn`, `description`, `searchPlaceholder`, `bestOnly`, `viewCount`, `likeCount`
- **외부 의존성**: 없음

---

### 3-3. 포스팅 상세 (슬라이드 S284~S287)

- **라우트**: `/[locale]/category/posting/[id]`
- **Server/Client 분리**: `page.js`(Server) → `PostingDetail.js`(Server, fetch) → `PostingDetailContent.js`(Client, 인터랙션)
- **UI 섹션** (상→하 순서):
  1. **PageNavBar**: 상단바 (뒤로가기 + 타이틀 + 공유 아이콘)
  2. **포스팅 헤더**: 제목 (h1), 작성일, 조회수, 추천수
  3. **상담사 정보 영역**: 프로필 이미지 + 닉네임 + 카테고리 뱃지. 클릭 시 상담사 프로필로 이동
  4. **포스팅 본문 이미지**: 본문 첨부 이미지 (next/image)
  5. **포스팅 본문 텍스트**: HTML 본문 콘텐츠 (DOMPurify XSS 방어)
  6. **추천 버튼**: 좋아요/추천 CTA 버튼
  7. **판매상품 더보기**: 해당 상담사의 판매 상품 링크 영역
  8. **댓글 영역**: 댓글 리스트 + 댓글 작성 input
  9. **공유 바텀시트** (조건부): 공유 아이콘 클릭 시 바텀시트 오픈 (카카오톡, 라인, URL 복사 등)

- **댓글 시스템 상세 (S286~S287)**:
  | 기능 | 설명 |
  |------|------|
  | 댓글 작성 | 하단 고정 input bar, 로그인 필수 |
  | 답글 작성 | 댓글에 답글 달기, 들여쓰기로 구분 |
  | 댓글 삭제 | 본인 댓글만 삭제 가능, 확인 다이얼로그 |
  | 댓글 정렬 | 최신순 기본 |
  | 댓글 페이징 | "이전 댓글 더보기" 버튼 |

- **공유 바텀시트 (S285)**:
  | 공유 채널 | 설명 |
  |----------|------|
  | 카카오톡 | 카카오 SDK 공유 |
  | 라인 | LINE 앱 공유 |
  | URL 복사 | 클립보드 복사 + "복사되었습니다" 토스트 |
  | 더보기 | Web Share API (navigator.share) |

- **상태 관리**:
  - 로컬 상태: 포스팅 데이터, 댓글 목록, 댓글 입력값, 답글 대상, 공유 바텀시트 열림 여부, 추천 상태
  - Zustand 스토어: 사용하지 않음

- **API 연동**:
  | 엔드포인트 | Method | Request Body | Response |
  |-----------|--------|-------------|----------|
  | `/api/category/getPostingDetail` | POST | `{ id, locale }` | `{ response, posting: PostingDetail }` |
  | `/api/category/getComments` | POST | `{ postingId, offset, limit }` | `{ response, comments: Comment[], total }` |
  | `/api/category/addComment` | POST | `{ postingId, content, parentId? }` | `{ response, comment: Comment }` |
  | `/api/category/deleteComment` | POST | `{ commentId }` | `{ response }` |
  | `/api/category/likePosting` | POST | `{ postingId }` | `{ response, likeCount }` |

- **사용자 인터랙션**:
  - 상담사 정보 영역 클릭 → 상담사 프로필 페이지 이동
  - 추천 버튼 클릭 → API 호출 → 추천수 갱신 (로그인 필수)
  - 판매상품 더보기 클릭 → 상담사 프로필 판매상품 탭 이동
  - 공유 아이콘 클릭 → 공유 바텀시트 오픈
  - 댓글 작성: 하단 input에 텍스트 입력 → 전송 버튼 클릭 (로그인 필수)
  - 답글 작성: 댓글 "답글" 클릭 → input에 답글 모드 전환 → 전송
  - 댓글 삭제: 본인 댓글 "삭제" 클릭 → 확인 다이얼로그 → 삭제 API 호출
  - 이전 댓글 더보기: offset 증분 fetch
- **비즈니스 규칙**:
  - 비로그인 사용자: 포스팅 열람 가능, 댓글/추천 시 로그인 페이지 리다이렉트
  - 본문 HTML: PHP API에서 원시 HTML 반환 시 DOMPurify로 XSS 방어 필수
  - 추천: 1인 1회 제한 (이미 추천 시 추천 취소)
  - 댓글 삭제: 자식 답글이 있는 경우 "삭제된 댓글입니다" 표시로 대체 (soft delete)
- **i18n 네임스페이스**: `posting`
  - 주요 키: `detailNavTitle`, `viewCount`, `likeCount`, `likeBtn`, `moreProducts`, `commentPlaceholder`, `commentSubmit`, `replyBtn`, `deleteBtn`, `deleteConfirm`, `deletedComment`, `loadMoreComments`, `shareTitle`, `shareKakao`, `shareLine`, `shareCopyUrl`, `shareCopyToast`, `shareMore`
- **외부 의존성**:
  - `dompurify` (본문 HTML XSS 방어)
  - 카카오 SDK (카카오톡 공유)

---

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 사용 페이지 | Props |
|---------|-----------|-------|
| CategoryMain | category 메인 | `labels`, `locale`, `banners` |
| PostingCard | posting 홈 | `posting`, `locale` |
| PostingListItems | posting 홈 | `data`, `labels`, `locale` |
| PostingDetailContent | posting 상세 | `posting`, `comments`, `labels`, `locale` |
| CommentItem | posting 상세 | `comment`, `onReply`, `onDelete`, `isOwner` |
| CommentInput | posting 상세 | `onSubmit`, `replyTarget`, `onCancelReply`, `placeholder` |
| ShareBottomSheet | posting 상세 | `isOpen`, `onClose`, `shareUrl`, `shareTitle`, `labels` |
| PageNavBar | posting 홈/상세 | `locale`, `title`, `homeLabel`, `rightIcon?` |

---

## 5. 크로스 도메인 의존성

| 방향 | 대상 도메인 | 연결 내용 |
|------|-----------|----------|
| 의존 | `call` (전화상담) | 카테고리 메인 → 전화상담 바로가기 |
| 의존 | `chat` (채팅상담) | 카테고리 메인 → 채팅상담 바로가기 |
| 의존 | `login` | 댓글/추천 시 비로그인 사용자 리다이렉트 |
| 피의존 | `call`/`chat` 프로필 | 포스팅 상세 → 상담사 프로필 이동 |
| 피의존 | `layout` | Header/Footer(GNB) 공유 컴포넌트 |

---

## 6. 미확정 사항

- [ ] 이벤트 카드 클릭 시 이동 경로 (별도 이벤트 페이지 존재 여부)
- [ ] 포스팅 검색 — 서버사이드 검색 vs 클라이언트 필터링
- [ ] 포스팅 본문 HTML 포맷 상세 (허용 태그 목록)
- [ ] 카카오 SDK / LINE 공유 연동 설정 상세
- [ ] 댓글 신고 기능 존재 여부
- [ ] 판매상품 더보기 클릭 시 이동 경로 상세 (상담사 프로필 어느 탭)
- [ ] 포스팅 리스트 정렬 기준 (최신순/인기순 선택 가능 여부)
- [ ] 베스트 포스팅 선정 기준 (운영팀 큐레이션 vs 자동 알고리즘)
