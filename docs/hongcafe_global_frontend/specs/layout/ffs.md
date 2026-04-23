# Frontend Functional Spec — 레이아웃 구성

> Source: 화면설계서 PPTX Slides S55~S61 + as-built 코드(`app/[locale]/layout.js`, `components/BottomNav.js`, 커밋 `bd5d4ce`) + 감사 문서(`2026-04-15-geolite2-attribution-relocation.md`)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

## 1. 개요

- **도메인 목적**: 모든 페이지에 공통 적용되는 레이아웃 시스템(상단 GNB, 탭, 하단 GNB, 카테고리/프로필 레이아웃) 정의
- **사용자 목표**: 일관된 내비게이션으로 전화상담/채팅상담 간 전환, 주요 기능(홈, 마이메뉴, 코인충전, 단골, 카테고리)에 빠르게 접근
- **구현 상태**: **부분 구현** — `app/[locale]/layout.js`(NextIntlClientProvider + 푸터 Licenses 링크 — 커밋 `bd5d4ce`), `components/BottomNav.js`(5탭 GNB, MyPage 등에서 직접 호출), `app/[locale]/_components/PageNavBar.js`(하위 페이지 보라색 상단바). 메인 페이지 GNB(상단 헤더/검색/Tab 영역) 미구현
- **성격**: 단일 페이지가 아닌 전역 레이아웃 시스템. `app/[locale]/layout.js`와 전역 공유 컴포넌트(`components/`)에 반영.

## 2. 라우트 구조

레이아웃 시스템은 특정 라우트가 아니라 **모든 라우트에 공통 적용**된다. 레이아웃별 적용 범위는 아래와 같다.

| 레이아웃 영역 | 적용 범위 | 컴포넌트 위치 | 비고 |
|-------------|---------|-------------|------|
| 상단 GNB (TOP 영역) | 메인 페이지 (`/[locale]`) | `components/Header.js` | 로고 + 검색 |
| Tab 영역 | 메인 페이지 (`/[locale]`) | `app/[locale]/_components/MainTab.js` (신규) | 전화상담/채팅상담 전환 |
| 하단 GNB (Footer) | 전체 페이지 (프로필 제외) | `components/Footer.js` | 5개 메뉴 고정 |
| 카테고리 TOP | `/[locale]/category/[slug]` | 해당 도메인 `_components/` | 카테고리명 + 뒤로가기 |
| 프로필 TOP | `/[locale]/phone-consultation/[id]` 등 | 해당 도메인 `_components/` | [카테고리] 상담사명 + Home |
| PageNavBar | 하위 페이지 (login, join 등) | `app/[locale]/_components/PageNavBar.js` | 보라색 상단바 (기구현) |

### 레이아웃 적용 매트릭스

| 페이지 유형 | 상단 GNB | Tab | 하단 GNB | PageNavBar |
|-----------|---------|-----|---------|-----------|
| 메인 홈 (`/[locale]`) | O | O | O | X |
| 카테고리 리스트 | 카테고리 TOP | 하위 카테고리 탭 | O | X |
| 상담사 프로필 | 프로필 TOP | 프로필 탭 | X (전용 하단바) | X |
| 로그인/회원가입 등 | X | X | X | O |
| 검색 | 검색 전용 TOP | X | O | X |

## 3. 컴포넌트 정의

### 3-0. as-built LocaleLayout — `app/[locale]/layout.js` (v1.1 신규)

> 커밋 `bd5d4ce`로 푸터 Licenses 링크가 추가된 최소 동작 레이아웃.

| 항목 | 내용 |
|------|------|
| 파일 경로 | `app/[locale]/layout.js` |
| 적용 범위 | 모든 `[locale]/*` 페이지 |
| Server Component | `LocaleLayout` async — `getMessages` + `getTranslations`(legal) + locale validation |

#### 구조 (as-built)

```jsx
<html lang={locale}>
  <head />
  <body>
    <NextIntlClientProvider messages={messages}>
      {children}
      <footer className="w-[100%] py-[1.2rem] text-center">
        <Link href="/legal/notices" rel="license"
              className="text-[1rem] text-[#999999] underline">
          {tLegal('noticesLinkLabel')}  // "Licenses"
        </Link>
      </footer>
    </NextIntlClientProvider>
  </body>
</html>
```

#### 핵심 동작

| 동작 | 설명 |
|------|------|
| `generateStaticParams` | locales 배열로 정적 파라미터 생성 (`en`/`ja`/`ko`) |
| locale 검증 | `locales.includes(locale)` 미통과 시 `notFound()` |
| `<html lang={locale}>` | a11y/SEO 언어 속성 |
| NextIntlClientProvider | 클라이언트 트리에 i18n 메시지 주입 |
| 푸터 Licenses 링크 | `/legal/notices` (`rel="license"`) — Phase B-2 의존 (감사 권고안 1) |

#### 의존성 (as-built)

| 의존성 | 용도 |
|--------|------|
| `next-intl` (`NextIntlClientProvider`) | i18n 컨텍스트 |
| `next-intl/server` (`getMessages`/`getTranslations`) | SSR i18n |
| `next/link` | 푸터 Licenses 링크 |
| `i18n/routing` (`locales`) | locale 화이트리스트 |

### 3-0B. as-built BottomNav — `components/BottomNav.js` (v1.1 신규)

| 항목 | 내용 |
|------|------|
| 파일 경로 | `components/BottomNav.js` |
| 사용 페이지 | mypage (현재). 향후 main / browse / favourites / getcoins 모두 사용 예정 |
| Client Component | `'use client'` — `usePathname` 사용 |

#### 구조 (as-built)

| 위치 | 내용 |
|------|------|
| `<nav>` 컨테이너 | `fixed bottom-0 left-0 right-0 bg-[#ffffff] border-t border-[#eeeeee] z-[10]` (V5.7 §22-72 GNB 표준 — `left-[50%] translate-x-[-50%]` 패턴 금지) |
| 내부 박스 | `max-w-[43rem] w-[100%] mx-[auto] flex items-center` (2026-04-20 일원화 — Fixed 요소 예외로 자체 max-w 유지) |
| 5탭 (각 flex-1) | Home → Browse → Favourites → MyPage → GetCoins |
| 각 탭 구성 | Image 1.6x1.6 (icon_nav_*.svg) + 라벨 1.1rem |
| 활성 탭 표시 | `usePathname() === \`/\${locale}\`` 검사 (Home만) — 나머지 탭 active 표시 미구현 |

#### Props

| Prop | 타입 | 필수 | 비고 |
|------|------|------|------|
| `labels` | object | Y | `{ navHome, navBrowse, navFavourites, navMyPage, navGetCoins }` (main 네임스페이스) |
| `locale` | string | Y | Link href 생성용 (`/${locale}/browse` 등 — locale prefix 포함) |

#### 라우트 매핑

| 탭 | 링크 | 페이지 구현 상태 |
|----|------|----------------|
| Home (`navHome`) | `/${locale}` | 구현 (메인 — 커밋 `2bcfb5c`) |
| Browse (`navBrowse`) | `/${locale}/browse` | **미구현** — Phase B 또는 별도 도메인 |
| Favourites (`navFavourites`) | `/${locale}/favourites` | **미구현** |
| MyPage (`navMyPage`) | `/${locale}/mypage` | 스캐폴드 구현 (Phase A-4) |
| GetCoins (`navGetCoins`) | `/${locale}/getcoins` | **미구현** |

> **유형 D**: locale prefix 정책 — CLAUDE.md §11은 "locale prefix 금지"이나 BottomNav는 모든 링크에 `/${locale}` 포함. login의 "Join" 버튼과 동일 이슈 (login ffs §6 #8). 정책 통일 필요.

#### 미구현 인터랙션

| 기능 | 설명 |
|------|------|
| 활성 탭 시각 표시 | 현재 path와 매칭되는 탭에 강조 색/굵기 — 미구현 |
| 비로그인 가드 | Favourites/MyPage 클릭 시 비로그인 → 로그인 이동 — 각 페이지에서 처리 (BottomNav 자체는 무가드) |
| 코인 잔액 뱃지 | GetCoins 탭에 잔액 뱃지 — 미구현 |

### 3-1. TOP 영역 / 상단 헤더 (슬라이드 S56~S57)

- **컴포넌트**: `components/Header.js` (기존 파일 리팩토링)
- **Server/Client 분리**: `Header.js`(Server) → `HeaderClient.js`(Client, 검색 인터랙션)
- **적용 범위**: 메인 페이지 (`/[locale]`)
- **UI 섹션** (좌→우 순서):
  1. **로고**: 홍카페 로고 이미지, 클릭 시 전화상담 메인(`/[locale]`)으로 이동, 테마 컬러 적용 (퍼플 링크)
  2. **검색 아이콘**: 돋보기 아이콘, 클릭 시 검색 페이지(`/[locale]/search`)로 이동
- **검색 대상**: 상담사, 상품, 후기 통합 검색
- **메인 배너**: 로고/검색 아래, 슬라이드(Swiper) 형태 배너 영역
- **비즈니스 규칙**:
  - 로고 클릭 = 전화상담 카테고리 메인으로 이동
  - 검색 아이콘은 항상 표시 (로그인 여부 무관)

### 3-2. Tab 영역 (슬라이드 S56~S58)

- **컴포넌트**: `app/[locale]/_components/MainTab.js` (신규 Client Component)
- **적용 범위**: 메인 페이지 (`/[locale]`)
- **UI 구성**:
  1. **1depth 탭 메뉴**:
     - **전화상담**: 테마 컬러 green (`#00af79`, `var(--green-1)` 계열)
     - **채팅상담**: 테마 컬러 purple (`#6335b4`, `var(--purple-1)`)
     - (KR 전용) 클래스, 홍카페홍대, 대면상담, 서비스상품 — **JP/US 미제공**
  2. **하위 카테고리 탭**:
     - 전체, 영감영시, 타로, 사주성명, 이벤트, 후기 (국가별 구성 상이)
  3. **리스트보기 토글**: 그리드 뷰 / 리스트 뷰 전환
  4. **콘텐츠 영역**: 상담사 카드 리스트
- **탭 전환 동작**:
  - 슬라이드 형태 전환 (Swiper 또는 CSS transition)
  - **한 번에 모든 데이터 로딩 방지**: 탭 전환 시 해당 탭 데이터만 fetch
  - 탭 전환 시 하위 카테고리 초기화 (전체로 리셋)
- **테마 변경 연동**: 전화상담 탭 활성 → green 테마, 채팅상담 탭 활성 → purple 테마
- **비즈니스 규칙**:
  - JP/US에서는 전화상담, 채팅상담 2개 탭만 표시
  - KR에서는 클래스, 홍카페홍대, 대면상담, 서비스상품 추가 표시 (추후 확장)
  - 탭 이동 시 이전 탭 스크롤 위치 보존 여부: **미확정**
- **상태 관리**:
  - `useCateStore`: 현재 활성 카테고리 (전화상담/채팅상담)
  - `useViewStore` (신규): 리스트뷰/그리드뷰 토글 상태
  - 로컬 상태: 활성 하위 카테고리, 스크롤 위치

### 3-3. 하단 GNB / 푸터 (슬라이드 S59)

- **컴포넌트**: `components/Footer.js` (기존 파일 리팩토링)
- **Server/Client 분리**: `Footer.js`(Client) — 로그인 상태 감지 필요
- **적용 범위**: 전체 페이지 (프로필 페이지 제외 — 프로필은 전용 하단바 사용)
- **UI 구성**: 하단 고정(fixed) 5개 메뉴
- **메뉴 목록**:

  | # | 메뉴명 | 아이콘 | 링크 | 비로그인 시 | 비고 |
  |---|-------|-------|------|-----------|------|
  | 1 | 홈 | 홈 아이콘 | `/[locale]` | 동일 | 전화상담 카테고리 메인 |
  | 2 | 마이메뉴 | 사람 아이콘 | `/[locale]/member-mymenu` | "로그인" 텍스트로 변경, `/[locale]/login`으로 이동 | 로그인 상태 분기 |
  | 3 | 코인충전 | 코인 아이콘 | `/[locale]/coin-charging` | 로그인 페이지로 리다이렉트 | |
  | 4 | 단골 | 하트 아이콘 | `/[locale]/favorites` | 로그인 페이지로 리다이렉트 | |
  | 5 | 카테고리 | 메뉴 아이콘 | `/[locale]/category` | 동일 | 카테고리 페이지 |

- **활성 상태 표시**: 현재 페이지에 해당하는 메뉴 아이콘/텍스트 강조 (CSS after 가상요소 또는 색상 변경)
- **고정 위치**: `<nav className="fixed bottom-0 left-0 right-0 z-[10]">` + 내부 `<div className="max-w-[43rem] w-[100%] mx-[auto]">` (§22-72 GNB 표준, 2026-04-20 430px 일원화)
- **비즈니스 규칙**:
  - 비로그인 시 마이메뉴 → "로그인" 텍스트 변경 + 링크 변경
  - 비로그인 시 코인충전/단골 클릭 → 로그인 페이지로 리다이렉트
  - 프로필 페이지에서는 하단 GNB 미표시 (전용 상담하기 버튼 사용)
- **상태 관리**:
  - 로그인 상태: `useAuthStore` (신규) 또는 서버 쿠키 기반
  - 활성 메뉴: `usePathname()` 기반 자동 감지

### 3-4. 카테고리 리스트 레이아웃 (슬라이드 S60)

- **적용 범위**: `/[locale]/phone-consultation/[category]`, `/[locale]/chat-consultation/[category]`
- **UI 섹션** (상→하 순서):
  1. **카테고리 TOP**: 카테고리명 + 뒤로가기 버튼 + Home 버튼
  2. **하위 카테고리 Tab**: 국가별 하위 카테고리 메뉴 (가로 스크롤)
  3. **필터 바**: 정렬, 스타일, 분야, 상담코인, 상담가능만보기
  4. **리스트보기 토글**: 그리드/리스트 전환
  5. **상담사 리스트**: 카드형 또는 리스트형 상담사 목록
- **필터 항목**:

  | 필터 | 타입 | 옵션 |
  |------|------|------|
  | 정렬 | 단일 선택 드롭다운 | 추천순, 후기순, 상담순, 단골순, 코인낮은순, 코인높은순 |
  | 스타일 | 다중 선택 (최대 3개) | 정확해요, 편안해요, 깊이있어요, 친절해요, 공감해요, 솔직해요, 쉽게설명해요, 답변이빨라요, 목소리가좋아요 |
  | 분야 | 다중 선택 (최대 3개) | 연애운, 가족, 짝사랑, 건강, 궁합, 고민, 이별 등 |
  | 상담코인 | 범위 선택 | 코인 범위 (30초당) |
  | 상담가능만보기 | 토글 | ON/OFF |

- **필터 UI**: 클릭 시 바텀시트 형태 전개
- **비즈니스 규칙**:
  - 스타일/분야 필터는 최대 3개까지 선택 가능, 초과 시 경고 알럿
  - 필터 적용 시 리스트 재조회 (API 호출)
  - 상담가능만보기 ON 시 접속 중인 상담사만 표시

### 3-5. 프로필 레이아웃 (슬라이드 S61)

- **적용 범위**: `/[locale]/phone-consultation/[id]`, `/[locale]/chat-consultation/[id]`
- **UI 섹션** (상→하 순서):
  1. **프로필 TOP**: [카테고리명] 상담사명 + 뒤로가기 + Home 링크
  2. **프로필 Tab**: 5개 탭 전환
     - 판매상품: 상담사 판매 상품 목록
     - 상세정보: 경력, 소개, 스타일 태그
     - 후기: 별점, 후기 리스트
     - 1:1문의: 문의 작성/목록
     - 포스팅: 상담사 블로그형 게시글
  3. **하단 CTA 바** (하단 GNB 대체):
     - 단골 버튼 (하트 아이콘)
     - 전화상담 / 채팅상담 버튼 (상태별 분기)
- **하단 CTA 상태별 분기**:

  | 상담사 상태 | 전화상담 버튼 | 채팅상담 버튼 |
  |-----------|------------|------------|
  | 상담가능 | 활성 (클릭 → 상담 시작) | 활성 (클릭 → 채팅방 입장) |
  | 상담중 | 비활성 + 접속알림 신청 | 비활성 + 접속알림 신청 |
  | 부재중 | 비활성 + 접속알림 신청 | 비활성 + 접속알림 신청 |

- **비즈니스 규칙**:
  - 프로필 페이지에서는 하단 GNB(Footer) 미표시 → 전용 하단 CTA 바 사용
  - 전화상담 프로필: 전화 번호 표시 (기획서 [번호] 표기)
  - 채팅상담 프로필: 번호 미표시
  - 비로그인 시 단골/상담하기 클릭 → 로그인 페이지 리다이렉트

## 4. 상태 관리

### 4-1. 전역 스토어 (Zustand)

| 스토어 | 파일 | 상태값 | 사용처 |
|--------|------|-------|-------|
| `useCateStore` | `store/useCateStore.js` | `cate` (전화상담/채팅상담), `subCate` (하위 카테고리) | MainTab, 카테고리 리스트, Header |
| `useAuthStore` (신규) | `store/useAuthStore.js` | `isLoggedIn`, `user` (닉네임, 코인 등) | Footer (마이메뉴/로그인 분기), 프로필 CTA |
| `useViewStore` (신규) | `store/useViewStore.js` | `viewMode` (grid/list) | MainTab, 카테고리 리스트 |
| `useFilterStore` (신규) | `store/useFilterStore.js` | `sort`, `styles[]`, `fields[]`, `coinRange`, `onlineOnly` | 카테고리 리스트 필터 바 |

### 4-2. 로컬 상태

| 컴포넌트 | 상태 | 용도 |
|---------|------|------|
| MainTab | `activeTab` (number) | 1depth 탭 인덱스 (전화상담=0, 채팅상담=1) |
| MainTab | `activeSubCate` (string) | 활성 하위 카테고리 |
| Footer | `activeNav` (string) | 현재 활성 메뉴 (usePathname 기반) |
| 카테고리 리스트 | `filterOpen` (boolean) | 필터 바텀시트 열림/닫힘 |
| 프로필 Tab | `activeProfileTab` (number) | 프로필 탭 인덱스 (판매상품=0, ...포스팅=4) |

## 5. 테마 시스템 (green / purple)

### 5-1. 테마 컬러 정의

| 테마 | 용도 | CSS 변수 | Hex 값 |
|------|------|---------|--------|
| green | 전화상담 | `--green-1` (정의 필요) | `#00af79` |
| purple | 채팅상담 | `--purple-1` | `#6335b4` |

> **참고**: 현재 `globals.css`에 `--green-1` 변수가 미정의 상태. `--teal-1: #1ab8be`만 존재. 기획서 S58 기준 전화상담 테마 컬러는 `#00af79`이므로 CSS 변수 추가 필요.

### 5-2. 테마 전환 메커니즘

```text
사용자가 전화상담 탭 클릭
  → useCateStore.setCate('green')
  → Header 로고 테마 변경
  → MainTab 활성 인디케이터 색상 변경
  → 하위 카테고리 태그 색상 변경
  → 상담사 카드 내 강조색 변경

사용자가 채팅상담 탭 클릭
  → useCateStore.setCate('purple')
  → 동일 흐름, purple 테마 적용
```

### 5-3. 테마 클래스 맵

```js
const themeColors = {
    green: {
        text: 'text-[var(--green-1)]',
        bg: 'bg-[var(--green-1)]',
        border: 'border-[var(--green-1)]',
        afterBg: 'after:bg-[var(--green-1)]',
    },
    purple: {
        text: 'text-[var(--purple-1)]',
        bg: 'bg-[var(--purple-1)]',
        border: 'border-[var(--purple-1)]',
        afterBg: 'after:bg-[var(--purple-1)]',
    },
};
```

### 5-4. CSS 변수 추가 필요 항목

```css
/* globals.css :root에 추가 필요 */
--green-1: #00af79;
--green-2: #00af79;  /* 기획서 확인 후 확정 */
```

## 6. 반응형

- **모바일 우선**: 기본 레이아웃은 모바일(390px) 기준. Figma 핸드오프는 360px 모바일 시안 유지.
- **최대 너비 (Layout SSOT, 2026-04-20 일원화)**: `app/[locale]/layout.js`의 공통 wrapper `<div className="max-w-[43rem] w-[100%] mx-[auto]">` 하나로 통일. 개별 페이지는 `max-w` 선언 금지.
- **PC 메인 컨테이너 최대 폭**: 430px (§22-32). 모바일 뷰포트(<430px)에서는 `w-[100%]`로 자연 축소.
- **하단 GNB 고정**: `<nav className="fixed bottom-0 left-0 right-0 z-[10]">` + 내부 `<div className="max-w-[43rem] w-[100%] mx-[auto]">` (§22-72 — `left-[50%] translate-x-[-50%]` 패턴 금지)
- **하단 GNB 여백**: `pb-[7.4rem]` (Footer 높이만큼 본문 하단 패딩)
- **카테고리 탭 가로 스크롤**: 하위 카테고리가 화면 너비 초과 시 `overflow-x-auto scrollbar-hide`
- **필터 바텀시트**: `fixed inset-0 z-[50]` 오버레이 + 하단 슬라이드업

## 7. 외부 의존성

| 의존성 | 용도 | 설치 여부 |
|--------|------|---------|
| Swiper | 메인 배너 슬라이더, 탭 전환 애니메이션 | 기설치 (프로젝트 기본 탑재) |
| next-intl | i18n 라벨 (메뉴명, 카테고리명 등) | 기설치 |
| Zustand | 테마 상태, 인증 상태, 필터 상태 관리 | 기설치 |

## 8. i18n 네임스페이스

| 네임스페이스 | 키 예시 | 사용처 |
|------------|--------|-------|
| `common` (신규) | `home`, `myMenu`, `login`, `coinCharge`, `favorites`, `category` | Footer 메뉴명 |
| `common` | `phoneConsultation`, `chatConsultation` | MainTab 1depth 탭명 |
| `common` | `all`, `spiritual`, `tarot`, `fourPillars`, `event`, `reviews` | 하위 카테고리명 |
| `filter` (신규) | `sort`, `style`, `field`, `coinRange`, `onlineOnly` | 필터 바 레이블 |
| `profile` (신규) | `products`, `details`, `reviews`, `inquiry`, `posting` | 프로필 탭명 |

## 9. API 연동 (예상)

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | 사용처 | 비고 |
|-----------|--------|-------|------|
| `/api/items/getListMobile` | POST | 메인 리스트, 카테고리 리스트 | 카테고리/필터 파라미터 포함 |
| `/api/auth/check` | GET | Footer 로그인 상태 확인 | 쿠키 기반 |
| `/api/counselor/profile` | POST | 프로필 페이지 | 상담사 ID 파라미터 |
| `/api/banner/list` | GET | 메인 배너 | 슬라이더 데이터 |

## 10. 미확정 사항 (v1.1)

> 분류: **유형 A** = as-built 구현 완료 / **유형 B** = 감사 권고 미반영 / **유형 C** = 추가 구현 필요 / **유형 D** = 정책·디자인 확정 필요

### v1.0 잔존 (화면설계서 기반 미구현)

- [ ] **[MEDIUM/D]** `--green-1` CSS 변수 정확한 Hex 값 확정 (`#00af79` vs 다른 값)
- [ ] **[MEDIUM/C]** 탭 전환 시 이전 탭 스크롤 위치 보존 여부
- [ ] **[LOW/D]** KR 전용 탭 (클래스, 홍카페홍대, 대면상담, 서비스상품) — 본 프로젝트 범위 밖 (홍카페K)
- [ ] **[HIGH/C]** 비로그인 시 코인충전/단골 클릭 → 로그인 리다이렉트 방식 (middleware vs 클라이언트 사이드)
- [ ] **[MEDIUM/D]** 프로필 페이지에서 하단 GNB 숨김 처리 방식 (layout 분기 vs 조건부 렌더링)
- [ ] **[LOW/D]** 필터 바텀시트 애니메이션 상세 (slide-up duration, backdrop 투명도)
- [ ] **[HIGH/C]** 메인 배너 데이터 소스 및 API 응답 구조
- [ ] **[HIGH/D]** 상담사 카드 컴포넌트 정확한 필드 구성 (Figma 시안 필요)
- [ ] **[HIGH/D]** 하위 카테고리 국가별 구성표 (JP/US 각각 어떤 카테고리 표시)
- [ ] **[MEDIUM/D]** 검색 아이콘 클릭 시 동작 (검색 페이지 이동 vs 인라인 검색바 토글)
- [ ] **[MEDIUM/C]** 접속알림 신청 API 및 알림 수신 방식 (Push, WebSocket 등)
- [ ] **[MEDIUM/D]** 프로필 TOP에서 [카테고리] 표시 형식 및 테마 컬러 적용 여부

### v1.1 추가 (as-built 반영)

- [ ] **#13 [HIGH/A]** 푸터 Licenses 링크 — `/legal/notices` (`rel="license"`) 구현 완료 (커밋 `bd5d4ce`, 감사 권고안 1)
- [ ] **#14 [HIGH/A]** BottomNav 5탭 구조 — Home/Browse/Favourites/MyPage/GetCoins (V5.7 §22-72 GNB 표준 적용 — `fixed bottom-0 left-0 right-0` + `max-w-[43rem] mx-[auto]` / 2026-04-20 430px 일원화)
- [ ] **#15 [HIGH/C]** BottomNav 활성 탭 표시 — 현재 path와 매칭되는 탭에 강조. 현재 Home만 isHome 변수 추정, 사용 안됨
- [ ] **#16 [HIGH/D]** locale prefix 정책 통일 — CLAUDE.md §11은 "locale prefix 금지", BottomNav/login의 Join은 `/${locale}/...` 포함. hostname 라우팅과 일관성 결정 필요 (login ffs §6 #8 동일)
- [ ] **#17 [HIGH/C]** Browse 페이지 신규 — `/${locale}/browse` 미구현
- [ ] **#18 [HIGH/C]** Favourites 페이지 신규 — `/${locale}/favourites` 미구현
- [ ] **#19 [HIGH/C]** GetCoins 페이지 신규 — `/${locale}/getcoins` 미구현
- [ ] **#20 [MEDIUM/C]** BottomNav 비로그인 가드 — Favourites/MyPage 클릭 시 비로그인 → `/login?returnUrl=...` 리다이렉트
- [ ] **#21 [MEDIUM/C]** GetCoins 잔액 뱃지 — `useCoinStore` 연동
- [ ] **#22 [LOW/D]** 디자인 시안 발급 — BottomNav 디자인 정식 시안 필요
- [ ] **#23 [LOW/A]** locale validation — `notFound()` 처리 (`app/[locale]/layout.js:14-16`)
- [ ] **#24 [LOW/A]** `<html lang={locale}>` — a11y/SEO 언어 속성 적용

---

## 11. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 화면설계서 PPTX(S55~S61) 기반 최초 작성 | 명우현 |
| v1.1 | 2026-04-17 | as-built 코드(`app/[locale]/layout.js` 푸터 Licenses 링크 + `components/BottomNav.js` 5탭 GNB) 역반영. §3-0 LocaleLayout / §3-0B BottomNav 신규 섹션 추가. 감사 권고안 1(레이아웃 전면 노출 제거 + Licenses 링크 단일화) 반영 표기. V5.7 §22-72 GNB 표준 준수 명시. 미확정 사항 12건 추가(Browse/Favourites/GetCoins 신규 페이지/활성 탭 표시/locale prefix 정책 통일/비로그인 가드/잔액 뱃지/디자인 시안) | 명우현 |
