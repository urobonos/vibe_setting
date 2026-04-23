# Frontend Functional Spec — 단골

> Source: 화면설계서 PPTX Slides S288~S293
> Status: DRAFT
> Updated: 2026-03-24

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 단골 (Favorites) |
| 사용자 목표 | 단골 등록한 상담사와 최근 방문한 상담사를 조회하고, 필터링(전체/전화/채팅, 상담가능만보기)과 개별/전체 삭제를 수행한다 |
| 퍼블리싱 상태 | 미구현 |
| 기능 연동 상태 | 미연동 |
| i18n 네임스페이스 | `favorites` |
| 지원 로케일 | `en`, `ko`, `ja` |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |

### 비즈니스 모델 핵심

- 단골은 사용자가 관심 있는 상담사를 즐겨찾기하여 빠르게 재방문할 수 있는 기능이다.
- "단골상담사" 탭은 사용자가 명시적으로 단골 등록한 상담사 목록이다.
- "최근방문" 탭은 프로필을 조회한 상담사 목록으로 자동 기록된다.
- 비로그인 상태에서는 데이터를 조회할 수 없으며, 로그인 유도 UI를 표시한다.
- 상담가능만보기 토글로 현재 상담 가능한 상담사만 필터링할 수 있다.

### 도메인 흐름 요약

```
단골 (/favorites)
  ├── 비로그인 상태
  │     └── "로그인 후 나의 단골 상담사 조회가 가능합니다" + 로그인 버튼
  ├── 로그인 상태
  │     ├── 탭: 단골상담사 (기본) / 최근방문
  │     ├── 단골상담사 탭
  │     │     ├── 필터: 전체 / 전화상담 / 채팅상담
  │     │     ├── 상담가능만보기 토글
  │     │     ├── 전체삭제 버튼
  │     │     ├── 상담사 카드 리스트 (CounselorCard)
  │     │     └── 개별 삭제 (X 버튼)
  │     └── 최근방문 탭
  │           ├── 상담가능만보기 토글
  │           ├── 전체삭제 버튼
  │           ├── 최근 방문 상담사 리스트 (CounselorCard)
  │           └── 개별 삭제 (X 버튼)
  └── 삭제 확인 모달 (전체삭제 시)
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/favorites` | `app/[locale]/favorites/page.js` | FavoritesPage | Server → Client | `favorites` |

### 인증 요구

- **로그인 필수 도메인**: 비로그인 시 페이지 자체는 렌더링되나, 로그인 유도 UI를 표시한다 (리다이렉트 아닌 인페이지 유도).
- 로그인 버튼 클릭 시 `/[locale]/login?returnUrl=/[locale]/favorites`로 이동한다.

---

## 3. 페이지 정의

### 3-1. 비로그인 상태 (슬라이드 S289)

| 항목 | 내용 |
|------|------|
| 조건 | 인증 쿠키 없음 (비로그인) |
| 화면설계서 | S289 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, 뒤로가기 + "Favorites" + Home 버튼 |
| 1 | 탭 영역 | 단골상담사 (기본) / 최근방문 — 2개 탭 표시 (비활성 상태) |
| 2 | 로그인 유도 | 중앙 영역에 아이콘 + "로그인 후 나의 단골 상담사 조회가 가능합니다" 텍스트 |
| 3 | 로그인 버튼 | 보라색 버튼 → `/[locale]/login?returnUrl=/[locale]/favorites` |

---

### 3-2. 단골상담사 탭 (슬라이드 S290~S291)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/favorites` (기본 탭) |
| Server Component | `app/[locale]/favorites/page.js` — 메타데이터, labels, 인증 상태 확인, 초기 단골 목록 SSR 조회 |
| Client Component | `app/[locale]/favorites/_components/FavoritesMain.js` |
| 화면설계서 | S290 (리스트), S291 (삭제) |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, 뒤로가기 + "Favorites" + Home 버튼 |
| 1 | 탭 영역 | 단골상담사 (활성) / 최근방문 — 2개 탭 |
| 2 | 필터 칩 | 전체(기본) / 전화상담 / 채팅상담 — 3개 필터 칩 |
| 3 | 토글+전체삭제 | 좌측: "상담가능만보기" 토글 스위치, 우측: "전체삭제" 텍스트 버튼 |
| 4 | 상담사 카드 리스트 | CounselorCard 반복 렌더링. 각 카드 우측 상단에 X(삭제) 버튼 |
| 5 | 빈 상태 | 단골 등록 0건 시 ListEmpty 컴포넌트 |

#### 상태 관리

- 로컬 상태:
  - `activeTab` — 'favorites' | 'recent' (현재 활성 탭)
  - `filterType` — 'all' | 'call' | 'chat' (상담 유형 필터, 단골상담사 탭에서만 사용)
  - `availableOnly` — boolean (상담가능만보기 토글)
  - `favorites` — 단골 상담사 배열
  - `recentVisits` — 최근 방문 상담사 배열
  - `isLoading` — API 호출 중 로딩 상태
  - `showDeleteConfirm` — 전체삭제 확인 모달 표시 여부
  - `deleteTarget` — 'favorites' | 'recent' (삭제 대상 탭)
- Zustand 스토어: 없음 (도메인 내부 상태만 사용)

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/favorites/getList` | POST | `{ type: 'favorites', filter, availableOnly }` | `{ success, items: CounselorCard[] }` | 페이지 초기 로드 + 필터/토글 변경 |
| `/api/favorites/delete` | POST | `{ counselorId }` | `{ response: "success"|"error", msg: "" }` | 개별 X 버튼 클릭 |
| `/api/favorites/deleteAll` | POST | `{ type: 'favorites' }` | `{ response: "success"|"error", msg: "" }` | 전체삭제 확인 |

#### CounselorCard 데이터 구조

```js
{
    counselorId: number,       // 상담사 고유 ID
    nickname: string,          // 상담사 닉네임
    profileImage: string,      // 프로필 이미지 URL
    category: string,          // 상담 분야 (타로, 사주 등)
    styleTags: string[],       // 스타일 태그 배열
    rating: number,            // 평균 별점
    reviewCount: number,       // 후기 수
    coinPer30sec: number,      // 30초당 코인
    status: 'available' | 'busy' | 'offline',  // 상담 상태
    consultationType: 'call' | 'chat' | 'both', // 상담 유형
    lastVisitedAt: string | null, // 최근 방문일 (최근방문 탭용)
}
```

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 필터 칩 선택 (전체/전화/채팅) | filterType 변경, 리스트 필터링 (로컬 필터 또는 API 재조회) |
| 상담가능만보기 토글 ON | availableOnly=true, status='available'인 상담사만 표시 |
| 상담가능만보기 토글 OFF | availableOnly=false, 전체 상담사 표시 |
| 개별 삭제 (X 버튼) | 해당 상담사 delete API 호출 → 성공 시 목록에서 즉시 제거 (낙관적 UI) |
| 전체삭제 버튼 클릭 | 전체삭제 확인 모달 표시 (S291) |
| 전체삭제 확인 | deleteAll API 호출 → 성공 시 목록 전체 클리어 |
| 전체삭제 취소 | 모달 닫기, 목록 유지 |
| 상담사 카드 클릭 | `/[locale]/call/profile/{counselorId}` 또는 `/[locale]/chat/profile/{counselorId}`로 이동 (consultationType에 따라 분기) |
| 뒤로가기 버튼 | `router.back()` |
| Home 버튼 | `/{locale}`로 이동 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 필터는 단골상담사 탭만 | 최근방문 탭에서는 필터 칩(전체/전화/채팅) 미표시 |
| 상담가능만보기 독립 | 양쪽 탭에서 독립적으로 토글 상태 유지 |
| 낙관적 삭제 | 개별 삭제 시 API 응답 전 UI에서 즉시 제거. API 실패 시 목록 복원 + 에러 메시지 |
| 전체삭제 확인 필수 | 전체삭제는 반드시 확인 모달을 거쳐야 함. 실수 방지 |
| 빈 상태 | 리스트 0건 시 ListEmpty 컴포넌트 표시 |
| 삭제 후 카운트 갱신 | 개별/전체 삭제 후 리스트 카운트 즉시 반영 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 단골 0건 | ListEmpty 컴포넌트 ("단골 등록된 상담사가 없습니다") |
| 필터 결과 0건 | "전화상담 단골 상담사가 없습니다" 등 필터별 빈 상태 메시지 |
| 개별 삭제 API 실패 | 낙관적 제거 롤백, 목록 복원, 에러 토스트 표시 |
| 전체삭제 API 실패 | 에러 메시지 표시, 목록 유지 |
| 상담가능만보기 + 필터 조합 | 두 필터 동시 적용: 예) "전화상담" + "상담가능만보기" → 전화상담이면서 가능 상태인 상담사만 |
| 리스트 조회 API 실패 | 에러 메시지 + 재시도 버튼 |
| 대량 단골 등록 | 100명 이상 단골 시 스크롤 성능 확인 |

---

### 3-3. 최근방문 탭 (슬라이드 S292~S293)

| 항목 | 내용 |
|------|------|
| 활성 조건 | activeTab='recent' |
| 화면설계서 | S292 (리스트), S293 (삭제) |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | (탭 전환이므로 NavBar 동일) |
| 1 | 탭 영역 | 단골상담사 / 최근방문 (활성) |
| 2 | 토글+전체삭제 | "상담가능만보기" 토글 + "전체삭제" 텍스트 버튼 (필터 칩 없음) |
| 3 | 상담사 카드 리스트 | CounselorCard 반복. 각 카드 우측 상단에 X(삭제) 버튼 |
| 4 | 빈 상태 | 최근 방문 0건 시 ListEmpty |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | Request Body | Response | 호출 시점 |
|-----------|--------|-------------|----------|---------|
| `/api/favorites/getList` | POST | `{ type: 'recent', availableOnly }` | `{ success, items: CounselorCard[] }` | 최근방문 탭 전환 + 토글 변경 |
| `/api/favorites/deleteRecent` | POST | `{ counselorId }` | `{ response: "success"|"error", msg: "" }` | 개별 삭제 |
| `/api/favorites/deleteAllRecent` | POST | `{}` | `{ response: "success"|"error", msg: "" }` | 전체삭제 확인 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 필터 칩 미표시 | 최근방문 탭에는 전체/전화/채팅 필터 없음 |
| 정렬 | 최근 방문일(lastVisitedAt) 내림차순 (최근 방문이 상단) |
| 자동 기록 | 상담사 프로필 조회 시 자동으로 최근방문에 추가 (프론트에서 별도 API 호출 불필요, 서버 측에서 처리) |
| 최대 보관 기간 | 서버에서 보관 기간 관리 (프론트에서는 제한 없이 표시) |

---

### 3-4. 전체삭제 확인 모달 (슬라이드 S291, S293)

| 항목 | 내용 |
|------|------|
| 트리거 | 전체삭제 버튼 클릭 |
| UI 형태 | 확인 다이얼로그 모달 (중앙 팝업) |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 타이틀 | "전체삭제" |
| 1 | 안내 텍스트 | "전체 단골상담사를 삭제하시겠습니까?" (또는 "최근방문 전체 삭제") |
| 2 | 확인 버튼 | 삭제 실행 |
| 3 | 취소 버튼 | 모달 닫기 |

---

## 4. API 연동 상세

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


### 4-1. API Route (프록시 레이어)

| 프론트 경로 | 외부 API 경로 (추정) | 설명 |
|-----------|-------------------|------|
| `/api/favorites/getList` | `/api/favorites/getListMobile` | 단골/최근방문 리스트 조회 (type 파라미터로 구분) |
| `/api/favorites/delete` | `/api/favorites/delete` | 단골 개별 삭제 |
| `/api/favorites/deleteAll` | `/api/favorites/deleteAll` | 단골 전체 삭제 |
| `/api/favorites/deleteRecent` | `/api/favorites/deleteRecent` | 최근방문 개별 삭제 |
| `/api/favorites/deleteAllRecent` | `/api/favorites/deleteAllRecent` | 최근방문 전체 삭제 |

---

## 5. 상태 관리

### 5-1. 로컬 상태 전용

단골 도메인은 Zustand 전역 스토어를 사용하지 않는다. 모든 상태는 FavoritesMain 클라이언트 컴포넌트 내 로컬 상태로 관리한다.

### 5-2. 상태 흐름

```
[Server] page.js: 인증 확인 → 로그인 시 getList(type='favorites') SSR 조회
  ↓ props: { labels, locale, isLoggedIn, initialFavorites }
[Client] FavoritesMain.js
  ├── 비로그인 → 로그인 유도 UI 렌더링
  ├── 탭 전환 (단골→최근방문) → getList(type='recent') 호출
  ├── 필터 변경 (전체/전화/채팅) → filterType 변경 → 로컬 필터 또는 API 재조회
  ├── 토글 변경 → availableOnly 변경 → 필터 적용
  ├── 개별 삭제 → delete API → 낙관적 UI 제거
  └── 전체삭제 → 확인 모달 → deleteAll API → 목록 클리어
```

---

## 6. 도메인 내 컴포넌트 구조

| 컴포넌트 | 파일 위치 | Props | 역할 |
|---------|----------|-------|------|
| FavoritesMain | `_components/FavoritesMain.js` | `labels`, `locale`, `isLoggedIn`, `initialFavorites` | 단골 메인 클라이언트 컴포넌트 |
| LoginPrompt | `_components/LoginPrompt.js` | `labels`, `locale` | 비로그인 상태 로그인 유도 UI |
| FavoritesList | `_components/FavoritesList.js` | `items`, `labels`, `onDelete`, `onCardClick` | 단골상담사 카드 리스트 (삭제 버튼 포함) |
| RecentVisitsList | `_components/RecentVisitsList.js` | `items`, `labels`, `onDelete`, `onCardClick` | 최근방문 카드 리스트 (삭제 버튼 포함) |
| FilterChips | `_components/FilterChips.js` | `filterType`, `onFilterChange`, `labels` | 전체/전화/채팅 필터 칩 |
| AvailableToggle | `_components/AvailableToggle.js` | `checked`, `onChange`, `labels` | 상담가능만보기 토글 스위치 |
| DeleteConfirmModal | `_components/DeleteConfirmModal.js` | `isOpen`, `targetType`, `labels`, `onConfirm`, `onCancel` | 전체삭제 확인 모달 |
| CounselorCard | 공유 컴포넌트 (`components/CounselorCard.js`) | `counselor`, `showDelete`, `onDelete`, `onClick` | 상담사 카드 (전화상담, 채팅상담, 검색, 단골에서 공유) |
| PageNavBar | `app/[locale]/_components/PageNavBar.js` | `locale`, `title`, `homeLabel` | 공유 컴포넌트 |

---

## 7. 크로스 도메인 의존성

- **의존**: layout (PageNavBar, Footer, Header), login (비로그인 시 리다이렉트), phone-consultation (상담사 프로필 이동), chat-consultation (상담사 프로필 이동)
- **피의존**: phone-consultation 프로필 (단골 등록 버튼 → 단골 API 호출), chat-consultation 프로필 (단골 등록 버튼 → 단골 API 호출)
- **공유 컴포넌트**: CounselorCard — 전화상담, 채팅상담, 검색, 단골에서 동일 카드 사용. 단골 도메인에서는 `showDelete=true`로 삭제 버튼 추가

---

## 8. 미확정 사항

- [ ] 단골 최대 등록 수: 상한 존재 여부 미정 (무제한 vs N명 제한)
- [ ] 최근방문 보관 기간: 30일? 90일? 무제한? 서버 정책 미확인
- [ ] 최근방문 최대 수량: 최대 N명까지 저장되는지 미정
- [ ] 필터 동작 방식: 프론트 로컬 필터인지, API 재조회인지 미정
- [ ] 상담사 카드 클릭 시 전화/채팅 분기 기준: consultationType 필드로 판별하는지 미확인
- [ ] 삭제 시 토스트/알럿 표시 여부: 개별 삭제 시 "삭제되었습니다" 토스트 노출 여부 미정
- [ ] 전체삭제 확인 모달 디자인: 바텀시트인지 중앙 팝업인지 미확정
- [ ] 비로그인 UI 탭 활성 여부: 탭이 비활성(클릭 불가)인지, 탭은 전환 가능하되 리스트만 로그인 유도인지 미정
- [ ] 상담가능만보기 토글 상태 탭간 공유 여부: 단골 탭과 최근방문 탭에서 토글 상태가 독립인지 공유인지 미정
