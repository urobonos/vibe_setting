# Frontend Functional Spec — 채팅상담

> Source: 화면설계서 PPTX Slides S133~S246 (114 슬라이드)
> Status: DRAFT
> Updated: 2026-03-24

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 채팅상담 (Chat Consultation) |
| 사용자 목표 | 내담자가 실시간 채팅으로 상담사와 1:1 상담을 진행한다 |
| 퍼블리싱 상태 | ❌ 미구현 |
| 기능 연동 상태 | 미연동 (API, WebSocket 미구현) |
| i18n 네임스페이스 | `chat`, `chatCategory`, `chatProfile`, `chatRoom` |
| 지원 로케일 | `en`, `ko`, `ja` |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |
| 테마 컬러 | purple (`#6335b4`, `var(--purple-1)`) |
| 슬라이드 수 | 114장 — 프로젝트 내 최대 규모 도메인 |

### 도메인 흐름 요약

```
채팅상담 메인 (/chat)
  ├── 카테고리 리스트 (/chat/category/[cate])
  │     └── 필터 (정렬/스타일/분야/상담코인/상담가능)
  └── 상담사 프로필 (/chat/profile/[id])
        ├── 상세정보 탭
        ├── 판매상품 탭
        ├── 후기 탭 (전체/베스트/손글씨)
        ├── 1:1문의 탭
        ├── 포스팅 탭
        └── 채팅 상담하기 → 연결 플로우 → 채팅방 (/chat/room/[sessionId])
              ├── 내담자 화면 (메시지, 파일전송, 답장)
              ├── 상담사 화면 (메시지, 내담자정보, 파일전송)
              ├── 자리비움/재입장
              └── 상담 종료 (수동/자동)

※ 전화상담(S62~S132)과 구조 대부분 동일. 이 문서는 채팅 고유 차이점을 중심으로 기술한다.
```

### 전화상담 대비 핵심 차이점

| 항목 | 전화상담 | 채팅상담 |
|------|---------|---------|
| 테마 | green (`#00af79`) | purple (`#6335b4`) |
| 과금 단위 | 코인/1분 | 코인/30초 |
| 상담 수단 | VoIP 통화 | 실시간 텍스트 채팅 |
| 채팅방 | 없음 | 채팅방 UI (메시지, 파일전송, 답장) |
| 자리비움 | 없음 | 채팅방 닫기 → 배너 알림 → 재입장 |
| 파일전송 | 없음 | 이미지/파일 전송 가능 |
| 답장하기 | 없음 | 롱프레스 → 원본 인용 답장 |
| 프로필 [번호] | 전화번호 표시 | 번호 미표시 |
| 상담사 측 화면 | 별도 명세 없음 | 상담사 전용 채팅 UI (내담자 정보 패널) |

---

## 2. 라우트 구조

| 라우트 | page.js 위치 | 동적 파라미터 | 인증 필요 | 슬라이드 |
|--------|-------------|-------------|---------|---------|
| `/[locale]/chat` | `app/[locale]/chat/page.js` | locale | 아니오 | S134~S140 |
| `/[locale]/chat/category/[cate]` | `app/[locale]/chat/category/[cate]/page.js` | locale, cate | 아니오 | S141~S154 |
| `/[locale]/chat/profile/[id]` | `app/[locale]/chat/profile/[id]/page.js` | locale, id | 아니오 | S155~S194 |
| `/[locale]/chat/room/[sessionId]` | `app/[locale]/chat/room/[sessionId]/page.js` | locale, sessionId | 예 | S195~S242 |

### generateStaticParams

- `[cate]` 카테고리: `all`, `spiritual`, `tarot`, `four-pillars`, `event`
- `[id]` 프로필: 동적 (SSR 또는 ISR)
- `[sessionId]` 채팅방: 동적 (완전 SSR, 인증 필수)

---

## 3. 페이지 정의

### 3-1. 채팅상담 메인 (슬라이드 S134~S140)

- **라우트**: `/[locale]/chat`
- **Server/Client 분리**: `page.js`(Server) → `ChatMain.js`(Client)
- **성격**: 전화상담 메인(S63~S69)과 거의 동일한 레이아웃. 테마만 purple.
- **UI 섹션** (상→하 순서):
  1. **TOP 영역 (Header)**: 홍카페 로고 + 검색 아이콘 (공유 컴포넌트)
  2. **메인 배너**: Swiper 슬라이드 배너 (이벤트/프로모션)
  3. **Tab 메뉴**: 전화상담(green) / **채팅상담(purple, 활성)** 2탭 전환
  4. **하위 카테고리 탭**: 전체 / 영감영시 / 타로 / 사주성명 / 이벤트 (가로 스크롤)
  5. **콘텐츠 영역**: 상담사 카드 그리드 + 리스트보기 토글
     - 추천 / 신규 / 급상승 / 상담중 섹션
  6. **하단 GNB (Footer)**: 5개 메뉴 고정

#### 상담사 카드 구성

| 필드 | 설명 |
|------|------|
| 프로필 이미지 | 상담사 대표 이미지 |
| 닉네임 | 상담사명 (JP: 카타카나 표기 병행) |
| 카테고리 | 영감영시/타로/사주성명 뱃지 |
| 상담 스타일 태그 | 최대 3개 (정확해요, 편안해요 등) |
| 후기 통계 | ★ 별점 + 후기 수 |
| **채팅 코인/30초** | "N코인/30초" — 전화상담은 "코인/1분" |
| 상담 상태 | 상담가능(초록) / 상담중(회색) / 부재중(회색) |
| 페이백 | 페이백 이벤트 배지 (해당 시) |

#### 리스트보기 전환

- 기본: 그리드 뷰 (2열)
- 토글: 리스트 뷰 (1열, 상세 정보 표시)
- 상태: `useViewStore.viewMode` (grid/list)

#### 인터랙션

| 액션 | 동작 |
|------|------|
| 전화상담 탭 클릭 | 전화상담 메인으로 전환 (테마 green, `useCateStore.setCate('green')`) |
| 하위 카테고리 탭 클릭 | 해당 카테고리 리스트 필터링 또는 `/chat/category/[cate]`로 이동 |
| 상담사 카드 클릭 | `/chat/profile/[id]`로 이동 |
| 리스트보기 토글 | 그리드/리스트 뷰 전환 |
| 더보기 / 무한스크롤 | 추가 상담사 데이터 fetch |

#### 상태 관리

| 스토어/상태 | 용도 |
|------------|------|
| `useCateStore.cate` | 'purple' (채팅상담 활성) |
| `useViewStore.viewMode` | 'grid' / 'list' |
| 로컬: `activeSubCate` | 활성 하위 카테고리 |
| 로컬: `items[]` | 상담사 리스트 데이터 |
| 로컬: `isMount` | SSR 하이드레이션 방지 (Swiper) |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | 용도 |
|-----------|--------|------|
| `/api/items/getListMobile` | POST | 상담사 리스트 조회 (cate='chat', subCate, offset, limit) |
| `/api/banner/list` | GET | 메인 배너 데이터 |

---

### 3-2. 카테고리 리스트 (슬라이드 S141~S154)

- **라우트**: `/[locale]/chat/category/[cate]`
- **Server/Client 분리**: `page.js`(Server) → `ChatCategoryList.js`(Client)
- **성격**: 전화상담 카테고리(S70~S83)와 동일 구조, 테마 purple.
- **UI 섹션** (상→하 순서):
  1. **카테고리 TOP**: 카테고리명 + 뒤로가기 + Home 버튼
  2. **하위 카테고리 Tab**: 가로 스크롤 탭
  3. **필터 바**: 정렬 / 스타일(최대3) / 분야(최대3) / 상담코인 / 상담가능만보기
  4. **리스트보기 토글**: 그리드/리스트 전환
  5. **상담사 리스트**: 카드형 또는 리스트형
  6. **하단 GNB (Footer)**

#### 필터 시스템

| 필터 | 타입 | UI | 옵션 |
|------|------|-----|------|
| 정렬 | 단일 선택 | 드롭다운 | 추천순, 후기순, 상담순, 단골순, 코인낮은순, 코인높은순 |
| 스타일 | 다중 선택 (최대3) | 바텀시트 | 정확해요, 편안해요, 깊이있어요, 친절해요, 공감해요, 솔직해요, 쉽게설명해요, 답변이빨라요, 목소리가좋아요 |
| 분야 | 다중 선택 (최대3) | 바텀시트 | 연애운, 가족, 짝사랑, 건강, 궁합, 고민, 이별, 이사, 재회, 꿈해몽, 원거리, 인간관계, 삼각관계, 재물, 바람, 사업, 속마음, 취업, 불륜, 진로, 결혼, 시험, 이혼, 합격, 재혼 |
| 상담코인 | 범위 선택 | 슬라이더 또는 입력 | 코인 범위 (30초당) |
| 상담가능만보기 | 토글 | 스위치 | ON/OFF |

#### 비즈니스 규칙

- 스타일/분야 필터 3개 초과 선택 시 경고 알럿 표시
- 필터 적용 시 리스트 재조회 (offset 리셋)
- 상담가능만보기 ON 시 접속 중 상담사만 표시
- 페이백 이벤트 상담사에게 페이백 뱃지 표시
- 100코인 특가 상담사 별도 표시

#### 상태 관리

| 스토어/상태 | 용도 |
|------------|------|
| `useFilterStore.sort` | 정렬 기준 |
| `useFilterStore.styles[]` | 선택된 스타일 태그 (최대 3) |
| `useFilterStore.fields[]` | 선택된 분야 태그 (최대 3) |
| `useFilterStore.coinRange` | 코인 범위 |
| `useFilterStore.onlineOnly` | 상담가능만보기 |
| 로컬: `filterOpen` | 바텀시트 열림/닫힘 |
| 로컬: `items[]` | 상담사 리스트 |

---

### 3-3. 상담사 프로필 (슬라이드 S155~S194)

- **라우트**: `/[locale]/chat/profile/[id]`
- **Server/Client 분리**: `page.js`(Server) → `ChatProfile.js`(Client)
- **성격**: 전화상담 프로필과 대부분 동일. 전화번호 미표시, "채팅 타로" 레이블.
- **UI 섹션** (상→하 순서):
  1. **프로필 TOP**: [카테고리] 상담사명 + 뒤로가기 + Home
  2. **프로필 정보 영역**: 이미지 + 닉네임 + 카테고리 + 등급 배지 + 소개글
  3. **프로필 Tab**: 5개 탭 전환
  4. **하단 CTA 바**: 단골 버튼 + 채팅상담 버튼 (Footer 대체)

#### 프로필 탭 구성

| 탭 | 슬라이드 | 내용 |
|----|---------|------|
| 판매상품 | S165 | 상담 상품 목록 (코인 가격, 설명) |
| 상세정보 | S156~S164 | 경력, 소개, 스타일 태그, 분야 태그, **번호 미표시** |
| 후기 | S166~S179 | 전체/베스트/손글씨 3탭, 별점 차트, 후기 리스트, 신고, 블라인드 |
| 1:1문의 | S180~S182 | 문의 작성 폼, 문의 리스트 |
| 포스팅 | S183~S186 | 상담사 블로그형 게시글 리스트 |

#### 후기 탭 상세

| 하위 탭 | 설명 |
|---------|------|
| 전체 | 모든 후기 리스트 (별점 + 텍스트 + 날짜) |
| 베스트 | 추천 수 기준 상위 후기 |
| 손글씨 | 손글씨 이미지 후기 (이미지 갤러리형) |

- **상담 스타일 차트**: 가장 많이 받은 스타일 태그 시각화 (가로 바 차트)
- **상담 분야 차트**: 가장 많이 받은 분야 태그 시각화
- **신고 기능**: 후기 항목 신고 버튼 → 신고 모달 (사유 선택 → 제출)
- **블라인드 후기**: 신고 누적으로 블라인드 처리된 후기 표시 ("블라인드 처리된 후기입니다")

#### 1:1문의 탭

- 문의 작성: 제목 + 내용 + 비공개 여부 + 등록 버튼
- 문의 리스트: 제목 + 작성자(닉네임 일부 마스킹) + 날짜 + 답변 여부
- 비공개 문의: 작성자 본인만 내용 열람 가능
- 답변: 상담사 답변 토글 표시

#### 포스팅 탭

- 포스팅 카드: 제목 + 대표 이미지 + 조회수 + 추천수 + 날짜
- 포스팅 상세: 카드 클릭 시 전체 내용 표시 (별도 페이지 또는 모달)
- 추천 기능: 추천 버튼 클릭 시 추천수 증가

#### 하단 CTA 바 — 상태별 분기

| 상담사 상태 | 단골 버튼 | 채팅상담 버튼 | 비고 |
|-----------|----------|------------|------|
| 상담가능 | 하트 아이콘 (토글) | 활성 보라색 "채팅상담" | 클릭 → 채팅 연결 플로우 |
| 상담중 | 하트 아이콘 (토글) | 비활성 + "접속알림 신청" | 현재 다른 내담자와 상담 중 |
| 부재중 | 하트 아이콘 (토글) | 비활성 + "접속알림 신청" | 상담사 미접속 |

#### 비즈니스 규칙

- 비로그인 시 단골/채팅상담 클릭 → 로그인 페이지 리다이렉트
- 프로필 페이지에서는 하단 GNB(Footer) 미표시 → 전용 하단 CTA 바 사용
- 전화상담 프로필과 달리 전화번호([번호]) 미표시
- "채팅 타로" 등 채팅 전용 상담 상품 레이블 표시
- 접속알림 신청 시 상담사 접속 시 푸시알림 발송

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | 용도 |
|-----------|--------|------|
| `/api/counselor/profile` | POST | 상담사 프로필 조회 |
| `/api/counselor/reviews` | POST | 후기 리스트 조회 (전체/베스트/손글씨, pagination) |
| `/api/counselor/inquiry` | POST | 1:1문의 리스트/작성/답변 |
| `/api/counselor/posting` | POST | 포스팅 리스트/상세 |
| `/api/favorite/toggle` | POST | 단골 등록/해제 |
| `/api/notification/subscribe` | POST | 접속알림 신청 |

---

### 3-4. 채팅 연결 플로우 (슬라이드 S187~S200)

채팅상담 프로필에서 "채팅상담" 버튼 클릭 시 시작되는 연결 프로세스.

#### 연결 프로세스 전체 흐름

```
[내담자] 채팅상담 버튼 클릭
  ├── [분기 A] 비로그인 → 로그인 페이지 리다이렉트
  ├── [분기 B] 코인 부족 → 코인부족 팝업 (코인충전 유도)
  └── [분기 C] 정상
        ↓
      "채팅상담 시작하기" 확인 팝업
        ↓ 확인 클릭
      채팅상담 연결중 (60초 타이머)
        ├── [상담사] 푸시알림 수신 → 수락/거절 선택
        ├── 수락 → 채팅방 입장 (/chat/room/[sessionId])
        ├── 거절 → 상담사 거절 메시지
        ├── 타임아웃(60초) → 연결 실패 메시지
        ├── 동시콜 실패 → 다른 상담 중 메시지
        ├── 내담자 취소 → 연결 취소
        └── 차단된 회원 → 차단 안내 메시지
```

#### 3-4-1. 사전 검증 팝업

| 팝업 | 조건 | UI |
|------|------|-----|
| 로그인 필요 팝업 | 비로그인 상태 | "로그인이 필요합니다" + 로그인 버튼 + 취소 버튼 |
| 코인 부족 팝업 | 보유코인 < 상담사 1회 코인 | "코인이 부족합니다" + 보유코인 표시 + 충전하기 버튼 + 취소 버튼 |

#### 3-4-2. 채팅상담 시작하기 팝업

- **UI**: 모달 다이얼로그
- **내용**: "채팅상담을 시작하시겠습니까?" + 상담사 정보(닉네임, 코인/30초) + 보유코인
- **버튼**: 확인 / 취소
- **확인 클릭 시**: 채팅 연결 요청 API 호출 → 연결중 화면 전환

#### 3-4-3. 채팅상담 연결중 화면

- **UI**: 전체화면 오버레이
- **구성**:
  - 상담사 프로필 이미지 (애니메이션)
  - "채팅상담 연결중..." 텍스트
  - 60초 카운트다운 타이머 (원형 프로그레스 또는 숫자)
  - 취소 버튼
- **타이머 동작**:
  - 60초부터 0초까지 1초 간격 감소
  - 0초 도달 시 자동으로 연결 실패(타임아웃) 처리
- **API 폴링 또는 WebSocket**: 상담사 수락/거절 상태 실시간 감지

#### 3-4-4. 연결 결과 분기

| 결과 | 메시지 | 후속 동작 |
|------|--------|----------|
| 연결 성공 (수락) | "연결되었습니다" | 자동으로 채팅방 입장 (`/chat/room/[sessionId]`) |
| 타임아웃 (60초) | "상담사가 응답하지 않습니다" | 프로필 페이지로 복귀 또는 재시도 |
| 동시콜 실패 | "상담사가 다른 상담 중입니다" | 프로필 페이지로 복귀 |
| 상담사 거절 | "상담사가 요청을 거절했습니다" | 프로필 페이지로 복귀 |
| 내담자 취소 | — | 연결중 화면 닫힘, 프로필로 복귀 |
| 차단된 회원 | "이용이 제한된 회원입니다" | 프로필 페이지로 복귀 |

#### 3-4-5. 상담사 측 수락/거절 (슬라이드 S195~S200)

- **푸시알림 수신**: 내담자 채팅 요청 → 상담사 디바이스에 푸시알림
- **알림 내용**: 내담자 닉네임 + "채팅상담 요청"
- **수락/거절 UI**:
  - 앱 내 배너 형태 또는 전체화면 요청 화면
  - "수락" / "거절" 2개 버튼
  - 1분 이내 미응답 시 자동 타임아웃
- **수락 시**: 상담사도 채팅방 입장 (`/chat/room/[sessionId]`)
- **미연결 케이스**: 내담자 취소, 타임아웃 → "상담이 연결되지 않았습니다" 메시지

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | 용도 |
|-----------|--------|------|
| `/api/chat/request` | POST | 채팅 연결 요청 (내담자 → 서버) |
| `/api/chat/status/[requestId]` | GET | 연결 상태 폴링 (pending/accepted/rejected/timeout) |
| `/api/chat/cancel/[requestId]` | POST | 내담자 연결 취소 |
| `/api/chat/accept/[requestId]` | POST | 상담사 수락 |
| `/api/chat/reject/[requestId]` | POST | 상담사 거절 |

---

### 3-5. 채팅방 — 내담자 화면 (슬라이드 S201~S219)

- **라우트**: `/[locale]/chat/room/[sessionId]`
- **Server/Client 분리**: `page.js`(Server, 인증 검증) → `ChatRoom.js`(Client)
- **인증 필수**: 비로그인 시 로그인 페이지 리다이렉트

#### UI 레이아웃 (3영역)

```
┌─────────────────────────────────┐
│ [TOP 영역]                       │
│ 상담사정보 | 상담시간 | 상담종료   │
├─────────────────────────────────┤
│ [채팅 영역]                      │
│ 자동알림 메시지                   │
│ 상담사 메시지 (왼쪽)              │
│ 내담자 메시지 (오른쪽)            │
│ 시스템 알림                      │
│                                 │
│                                 │
├─────────────────────────────────┤
│ [입력 영역]                      │
│ 파일전송 | 메시지 입력 | 전송     │
└─────────────────────────────────┘
```

#### 3-5-1. TOP 영역 (내담자)

| 요소 | 설명 |
|------|------|
| 상담사 닉네임 | 현재 상담 중인 상담사명 |
| 상담시간 카운터 | `00:00:00` 실시간 증가 (HH:MM:SS) |
| 보유코인 | 현재 남은 코인 표시 (예: "66,900") |
| 상담종료 버튼 | 상담 종료 트리거 |
| 화면닫기 버튼 | 채팅방 닫기 (자리비움 상태 전환) |

#### 3-5-2. 채팅 영역

**메시지 타입별 렌더링**

| 메시지 타입 | 정렬 | 배경색 | 시간 표시 |
|-----------|------|--------|---------|
| 내담자 메시지 | 오른쪽 | 보라색 배경 (`#6335b4`) + 흰색 텍스트 | 메시지 좌측 하단 |
| 상담사 메시지 | 왼쪽 | 회색 배경 (`#f5f5f5`) + 검정 텍스트 | 메시지 우측 하단 |
| 시스템 알림 | 중앙 | 투명 배경 + 회색 텍스트 | 없음 |
| 이미지 메시지 | 발신자 기준 | 이미지 썸네일 | 하단 |
| 답장 메시지 | 발신자 기준 | 원본 인용 영역 + 새 메시지 | 하단 |

**자동알림 메시지 (시스템 자동 발송)**

| 시점 | 알림 내용 |
|------|---------|
| 상담 시작 | "개인정보 보호를 위해 주소, 계좌번호 등 개인정보를 공유하지 마세요" |
| 입장 직후 | "[상담사명] 선생님이 입장하셨습니다" |
| 무료시간 시작 | "무료 1분 상담이 시작됩니다" |
| 무료시간 종료 | "무료 1분 상담이 종료되었습니다. 이후 30초당 N코인이 차감됩니다" |
| 코인 5분전 | "보유 코인이 5분 분량 이하입니다. 충전하시겠습니까?" |
| 코인 소진 | "보유 코인이 모두 소진되었습니다. 상담이 곧 종료됩니다" |

#### 3-5-3. 입력 영역

| 요소 | 설명 |
|------|------|
| 파일전송 버튼 | 클립 아이콘, 클릭 시 파일 선택 |
| 메시지 입력 필드 | 텍스트 입력 (textarea, 자동 높이 확장) |
| 전송 버튼 | 화살표 아이콘, 메시지 전송 |

**파일전송 (슬라이드 S217~S219)**

| 플랫폼 | 동작 |
|--------|------|
| PC | 파일 선택 다이얼로그 (`<input type="file">`) |
| 모바일 | 바텀시트: 카메라 / 갤러리 선택 |

- 지원 파일: 이미지 (jpg, png, gif, webp)
- 최대 크기: 미확정 (추정 10MB)
- 전송 후: 채팅 영역에 이미지 썸네일 표시
- 이미지 클릭: 전체화면 이미지 뷰어

**답장하기 (슬라이드 S212~S216)**

- **트리거**: 메시지 롱프레스 (모바일) 또는 우클릭 (PC)
- **동작**: 컨텍스트 메뉴 → "답장쓰기" 선택
- **UI 변화**: 입력 영역 상단에 원본 메시지 인용 바 표시
  - 인용 바: 원본 발신자명 + 원본 메시지 미리보기 (1줄 말줄임) + X(닫기)
- **전송 시**: 메시지 버블에 원본 인용 영역 + 새 메시지 합쳐서 표시
- **원본 클릭**: 해당 원본 메시지 위치로 스크롤

#### 코인 차감 시스템 (슬라이드 S202)

```
상담 시작
  ↓
무료 1분 (코인 미차감)
  ↓ 1분 경과
유료 구간 (30초당 N코인 차감)
  ↓ 코인 부족 5분전
"코인 부족" 알림 (충전 유도)
  ↓ 코인 0
자동 종료 (내담자 입력 불가 → 5초 후 상담 종료)
```

| 항목 | 값 |
|------|-----|
| 무료 구간 | 상담 시작 후 1분 |
| 과금 단위 | 30초 |
| 과금 금액 | 상담사별 설정 코인/30초 |
| 차감 시점 | 30초 구간 시작 시 선차감 |
| 코인 부족 알림 | 잔여 코인 5분 분량 이하 시 |
| 코인 소진 | 잔여 코인 0 → 내담자 입력 불가 → 5초 카운트다운 → 자동 종료 |

#### 상태 관리

| 스토어/상태 | 용도 |
|------------|------|
| `useChatStore.sessionId` | 현재 채팅 세션 ID |
| `useChatStore.messages[]` | 채팅 메시지 배열 |
| `useChatStore.status` | 세션 상태 (active/paused/ended) |
| `useCoinStore.balance` | 보유 코인 잔액 |
| 로컬: `inputText` | 메시지 입력 텍스트 |
| 로컬: `replyTarget` | 답장 대상 메시지 (null이면 일반 메시지) |
| 로컬: `elapsedTime` | 상담 경과 시간 (초) |
| 로컬: `isFreeTime` | 무료 1분 구간 여부 |
| 로컬: `isInputDisabled` | 코인 소진 시 입력 비활성화 |

#### API / WebSocket 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 프로토콜 | 엔드포인트 | 용도 |
|---------|-----------|------|
| WebSocket | `wss://.../chat/[sessionId]` | 실시간 메시지 송수신 |
| REST | `/api/chat/send` | 메시지 전송 (WebSocket 불가 시 폴백) |
| REST | `/api/chat/messages/[sessionId]` | 메시지 히스토리 조회 (재입장 시) |
| REST | `/api/chat/upload` | 파일/이미지 업로드 |
| REST | `/api/chat/coin-balance` | 보유코인 실시간 조회 |
| REST | `/api/chat/end/[sessionId]` | 상담 종료 요청 |

---

### 3-6. 채팅방 — 상담사 화면 (슬라이드 S204~S205)

- **성격**: 내담자 화면과 동일한 채팅 인터페이스 + 내담자 정보 패널
- **차이점**:

| 항목 | 내담자 화면 | 상담사 화면 |
|------|-----------|-----------|
| TOP 영역 | 상담사 정보 + 보유코인 | 내담자 닉네임 + 상담시간 |
| 내담자 정보 패널 | 없음 | 내담자 회원정보 (최근상담, 상담횟수) 표시 |
| 상담종료 권한 | 있음 | 있음 |
| 코인 표시 | 보유코인 | 없음 (상담사는 코인 미관여) |
| 메시지 정렬 | 내담자=오른쪽, 상담사=왼쪽 | 상담사=오른쪽, 내담자=왼쪽 |

#### 내담자 정보 패널 (상담사 전용)

| 필드 | 설명 |
|------|------|
| 내담자 닉네임 | 회원 닉네임 |
| 최근 상담 | 최근 상담 날짜 + 상담 유형 |
| 상담 횟수 | 해당 상담사와의 총 상담 횟수 |
| 메모 | 상담사가 작성하는 내담자 메모 (저장됨) |

---

### 3-7. 자리비움 / 재입장 (슬라이드 S220~S227)

상담 중 채팅방을 닫는 경우 (앱 백그라운드, 브라우저 탭 전환 등) 자리비움 상태로 전환된다.

#### 3-7-1. 내담자 자리비움 (슬라이드 S222~S224)

| 단계 | 동작 |
|------|------|
| 1 | 내담자가 채팅방에서 "화면닫기" 클릭 또는 브라우저 이탈 |
| 2 | 상담사 채팅방에 "내담자가 자리를 비웠습니다" 시스템 알림 표시 |
| 3 | 내담자에게 알림 배너 표시: "채팅상담이 진행 중입니다. 재입장하시겠습니까?" |
| 4 | 알림 배너 클릭 시 채팅방 재입장 (세션 유지) |
| 5 | 상담 시간은 자리비움 중에도 계속 카운트 (코인 차감 지속) |

#### 3-7-2. 상담사 자리비움 (슬라이드 S225~S227)

| 단계 | 동작 |
|------|------|
| 1 | 상담사가 채팅방에서 이탈 |
| 2 | 내담자 채팅방에 "상담사가 잠시 자리를 비웠습니다" 시스템 알림 표시 |
| 3 | 상담사에게 알림: "채팅상담이 진행 중입니다. 재입장해 주세요" |
| 4 | 상담사 재입장 시 세션 유지, 이전 메시지 히스토리 로드 |
| 5 | 상담 시간은 자리비움 중에도 계속 카운트 |

#### 비즈니스 규칙

- 자리비움 시 **상담 시간 및 코인 차감은 중단되지 않는다** (중요)
- 양측 모두 자리비움이어도 상담은 종료되지 않음 — 명시적 "상담종료"만 세션 종료
- 재입장 시 이전 메시지 전체 로드 (채팅 히스토리)
- 자리비움 상태에서도 메시지 수신은 계속됨 (재입장 시 미읽은 메시지 표시)

---

### 3-8. 채팅상담 종료 (슬라이드 S228~S242)

#### 3-8-1. 종료 유형

| 유형 | 트리거 | 코인 차감 |
|------|--------|----------|
| 수동 종료 (내담자) | 내담자 "상담종료" 버튼 클릭 | 경과 시간에 따라 차감 |
| 수동 종료 (상담사) | 상담사 "상담종료" 버튼 클릭 | 경과 시간에 따라 차감 |
| 자동 종료 (코인 소진) | 보유코인 0 도달 | 전액 차감 완료 |

#### 3-8-2. 내담자 수동 종료 플로우 (슬라이드 S230~S232)

**종료 확인 팝업**:
- "상담을 종료하시겠습니까?" + 확인 / 취소

**종료 완료 화면 — 경과 시간별 분기**:

| 경과 시간 | 화면 | 코인 차감 | 비고 |
|----------|------|----------|------|
| 1분 미만 | "무료 상담이 종료되었습니다" | 0코인 (무료) | 간단한 완료 화면 |
| 5분 미만 | 상담 요약 + 코인 차감 내역 | 유료 구간분만 차감 | 후기 작성 유도 |
| 5분 이상 | 상담 요약 + 코인 차감 내역 + 후기 작성 폼 | 유료 구간 전체 차감 | 후기 작성 폼 직접 노출 |

**종료 완료 화면 구성**:
- 상담사 프로필 (이미지 + 닉네임)
- 상담 시간: "00:05:32"
- 차감 코인: "150코인"
- 잔여 코인: "66,750코인"
- 후기 작성 버튼 (5분 미만) 또는 후기 작성 폼 (5분 이상)
- 확인 버튼 → 프로필 페이지로 이동

#### 3-8-3. 상담사 수동 종료 (슬라이드 S233)

- 상담사 "상담종료" 클릭 → 확인 팝업 → 종료
- 내담자 화면: "상담사가 상담을 종료했습니다" 시스템 알림
- 내담자에게 종료 완료 화면 표시 (3-8-2와 동일 분기)

#### 3-8-4. 자동 종료 — 코인 소진 (슬라이드 S238~S242)

```
보유 코인 5분 분량 이하
  ↓ 시스템 알림
"보유 코인이 부족합니다. 충전하시겠습니까?" + 충전하기 버튼
  ↓ 미충전 시 계속 차감
보유 코인 0 도달
  ↓
내담자 입력 불가 (입력 필드 비활성화)
  ↓ "코인이 모두 소진되었습니다. 5초 후 상담이 종료됩니다"
5초 카운트다운
  ↓
자동 상담 종료 → 종료 완료 화면
```

- **5분전 알림**: 시스템 알림 메시지 + 충전하기 인라인 버튼
- **충전하기 클릭**: 코인충전 페이지로 이동 (자리비움 상태 전환, 상담 유지)
- **코인 0 도달**: 내담자 메시지 입력 즉시 비활성화
- **5초 카운트다운**: 채팅 영역 상단 배너로 카운트다운 표시
- **자동 종료**: 서버 측에서 세션 종료 처리, 양쪽 화면에 종료 화면 표시

#### API 연동 (종료)

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | Method | 용도 |
|-----------|--------|------|
| `/api/chat/end/[sessionId]` | POST | 상담 종료 (수동) |
| `/api/chat/summary/[sessionId]` | GET | 상담 요약 (시간, 차감코인, 잔여코인) |
| `/api/review/write` | POST | 후기 작성 |

---

### 3-9. 단골/상담중/부재중/접속알림 (슬라이드 S243~S246)

전화상담과 동일한 패턴.

#### 단골 기능

- 프로필 하단 CTA 바의 하트 아이콘 토글
- 단골 등록 시: 하트 아이콘 채워짐 (filled), "단골 등록되었습니다" 토스트
- 단골 해제 시: 하트 아이콘 비워짐 (outlined), "단골 해제되었습니다" 토스트
- 단골 목록: `/[locale]/favorites`에서 확인

#### 접속알림 신청

- 상담중/부재중 상담사에게 접속알림 신청
- 신청 시: "접속 시 알림을 보내드리겠습니다" 토스트
- 상담사 접속 시: 푸시알림 발송 "◯◯ 선생님이 접속했습니다"
- 중복 신청: 이미 신청된 경우 "이미 알림을 신청하셨습니다" 메시지

---

## 4. 상태 관리

### 4-1. 전역 스토어 (Zustand)

| 스토어 | 파일 | 상태값 | 사용처 |
|--------|------|-------|-------|
| `useCateStore` | `store/useCateStore.js` | `cate` ('purple'), `subCate` | 메인, 카테고리 |
| `useViewStore` | `store/useViewStore.js` | `viewMode` ('grid'/'list') | 메인, 카테고리 |
| `useFilterStore` | `store/useFilterStore.js` | `sort`, `styles[]`, `fields[]`, `coinRange`, `onlineOnly` | 카테고리 |
| `useAuthStore` | `store/useAuthStore.js` | `isLoggedIn`, `user` | 프로필 CTA, 채팅방 |
| `useCoinStore` | `store/useCoinStore.js` | `balance` (보유코인) | 채팅방, 연결 플로우 |
| `useChatStore` | `store/useChatStore.js` | `sessionId`, `messages[]`, `status`, `elapsedTime` | 채팅방 |

### 4-2. useChatStore 상세 설계

```js
const useChatStore = create((set, get) => ({
    // 세션
    sessionId: null,
    status: 'idle', // idle | connecting | active | paused | ended
    counselorInfo: null,

    // 메시지
    messages: [],
    unreadCount: 0,

    // 타이머
    elapsedTime: 0, // 초
    isFreeTime: true, // 무료 1분 구간 여부

    // 입력
    isInputDisabled: false, // 코인 소진 시 true
    replyTarget: null, // 답장 대상 메시지

    // 액션
    setSessionId: (id) => set({ sessionId: id }),
    setStatus: (status) => set({ status }),
    addMessage: (msg) => set((s) => ({ messages: [...s.messages, msg] })),
    setMessages: (msgs) => set({ messages: msgs }),
    incrementTime: () => set((s) => {
        const newTime = s.elapsedTime + 1;
        return {
            elapsedTime: newTime,
            isFreeTime: newTime <= 60, // 60초 = 무료 1분
        };
    }),
    setInputDisabled: (disabled) => set({ isInputDisabled: disabled }),
    setReplyTarget: (msg) => set({ replyTarget: msg }),
    clearReplyTarget: () => set({ replyTarget: null }),
    reset: () => set({
        sessionId: null, status: 'idle', counselorInfo: null,
        messages: [], unreadCount: 0, elapsedTime: 0,
        isFreeTime: true, isInputDisabled: false, replyTarget: null,
    }),
}));
```

---

## 5. 도메인 내 컴포넌트 구조

### 5-1. 메인 / 카테고리

| 컴포넌트 | 위치 | 타입 | Props |
|---------|------|------|-------|
| `ChatMain` | `chat/_components/ChatMain.js` | Client | `labels`, `locale`, `initialData` |
| `ChatCategoryList` | `chat/category/_components/ChatCategoryList.js` | Client | `labels`, `locale`, `cate`, `initialData` |
| `FilterBottomSheet` | `chat/category/_components/FilterBottomSheet.js` | Client | `labels`, `onApply`, `onClose` |

### 5-2. 프로필

| 컴포넌트 | 위치 | 타입 | Props |
|---------|------|------|-------|
| `ChatProfile` | `chat/profile/_components/ChatProfile.js` | Client | `labels`, `locale`, `profileData` |
| `ProfileTabs` | `chat/profile/_components/ProfileTabs.js` | Client | `activeTab`, `onTabChange`, `labels` |
| `ReviewTab` | `chat/profile/_components/ReviewTab.js` | Client | `reviews`, `labels` |
| `InquiryTab` | `chat/profile/_components/InquiryTab.js` | Client | `inquiries`, `labels` |
| `PostingTab` | `chat/profile/_components/PostingTab.js` | Client | `postings`, `labels` |
| `ProfileCTA` | `chat/profile/_components/ProfileCTA.js` | Client | `status`, `locale`, `labels` |

### 5-3. 연결 플로우

| 컴포넌트 | 위치 | 타입 | Props |
|---------|------|------|-------|
| `ConnectConfirmModal` | `chat/profile/_components/ConnectConfirmModal.js` | Client | `counselor`, `labels`, `onConfirm`, `onCancel` |
| `ConnectingOverlay` | `chat/profile/_components/ConnectingOverlay.js` | Client | `counselor`, `timeLeft`, `onCancel` |
| `ConnectResultModal` | `chat/profile/_components/ConnectResultModal.js` | Client | `result`, `labels`, `onClose` |

### 5-4. 채팅방

| 컴포넌트 | 위치 | 타입 | Props |
|---------|------|------|-------|
| `ChatRoom` | `chat/room/_components/ChatRoom.js` | Client | `labels`, `locale`, `sessionId` |
| `ChatTopBar` | `chat/room/_components/ChatTopBar.js` | Client | `counselor`, `elapsedTime`, `coinBalance`, `onEnd`, `onClose` |
| `ChatMessages` | `chat/room/_components/ChatMessages.js` | Client | `messages`, `userId` |
| `MessageBubble` | `chat/room/_components/MessageBubble.js` | Client | `message`, `isMine`, `onLongPress` |
| `ReplyBubble` | `chat/room/_components/ReplyBubble.js` | Client | `originalMsg`, `replyMsg`, `isMine` |
| `SystemAlert` | `chat/room/_components/SystemAlert.js` | Client | `text` |
| `ChatInputBar` | `chat/room/_components/ChatInputBar.js` | Client | `onSend`, `onFileUpload`, `isDisabled`, `replyTarget` |
| `FileUploadSheet` | `chat/room/_components/FileUploadSheet.js` | Client | `onSelectCamera`, `onSelectGallery`, `onClose` |
| `ImageViewer` | `chat/room/_components/ImageViewer.js` | Client | `src`, `onClose` |
| `EndConfirmModal` | `chat/room/_components/EndConfirmModal.js` | Client | `labels`, `onConfirm`, `onCancel` |
| `EndSummary` | `chat/room/_components/EndSummary.js` | Client | `summary`, `labels`, `locale` |
| `CoinWarningBanner` | `chat/room/_components/CoinWarningBanner.js` | Client | `remainingMinutes`, `onCharge` |

---

## 6. 크로스 도메인 공유 컴포넌트

| 공유 컴포넌트 | 사용처 | 비고 |
|-------------|-------|------|
| CounselorCard | 메인, 카테고리 리스트, 검색, 단골 | 전화상담과 동일 (코인/30초 레이블만 차이) |
| FilterBottomSheet | 카테고리 리스트 | 전화상담과 동일 구조 |
| ReviewCard | 프로필>후기 | 전화상담과 동일 |
| ReportModal | 프로필>후기>신고 | 전화상담과 동일 |
| ProfileTabs | 프로필 | 전화상담과 동일 ([번호] 유무만 차이) |
| PostingCard | 프로필>포스팅 | 전화상담과 동일 |
| ConsultationBottomNav | 프로필 하단 CTA | 전화상담과 동일 구조 |
| PageNavBar | 하위 페이지 | 기구현 |
| Header | 메인 | 기구현 |
| Footer | 메인, 카테고리 | 기구현 |

---

## 7. 크로스 도메인 의존성

- **의존**: login (인증), coin-charging (코인 충전), layout (Header, Footer, Tab)
- **피의존**: member-mymenu (상담내역), counselor-mymenu (상담사 상담관리)
- **동급**: phone-consultation (전화상담 — Tab 전환으로 연결)

---

## 8. 테마 시스템

- 채팅상담 도메인 전체: purple 테마 (`#6335b4`, `var(--purple-1)`)
- Tab 전환 시 `useCateStore.setCate('purple')` 호출
- 모든 강조색, 활성 인디케이터, 버튼, 뱃지에 purple 테마 적용
- 입력 필드 하단 테두리: `border-b border-[#6335b4]`
- 상담사 카드 내 코인 강조: purple 컬러

---

## 9. i18n 네임스페이스

| 네임스페이스 | 키 예시 | 사용처 |
|------------|--------|-------|
| `chat` | `banner`, `recommended`, `new`, `rising`, `inSession` | 메인 섹션 레이블 |
| `chatCategory` | `filterTitle`, `sortLabel`, `styleLabel`, `fieldLabel`, `coinRange`, `onlineOnly`, `apply`, `reset` | 카테고리 필터 |
| `chatProfile` | `tabs.products`, `tabs.details`, `tabs.reviews`, `tabs.inquiry`, `tabs.posting`, `favorite`, `startChat`, `notifyOnConnect` | 프로필 페이지 |
| `chatRoom` | `topBar.time`, `topBar.coins`, `topBar.end`, `topBar.close`, `input.placeholder`, `input.send`, `file.camera`, `file.gallery`, `reply.title`, `system.freeStart`, `system.freeEnd`, `system.coinWarning`, `system.coinDepleted`, `system.awayClient`, `system.awayCounselor`, `end.confirm`, `end.summary`, `end.duration`, `end.charged`, `end.remaining`, `end.writeReview` | 채팅방 |
| `chatConnect` | `confirmTitle`, `confirmMsg`, `connecting`, `cancel`, `success`, `timeout`, `rejected`, `blocked`, `concurrent`, `loginRequired`, `insufficientCoins`, `charge` | 연결 플로우 |

---

## 10. 외부 의존성

| 의존성 | 용도 | 설치 여부 |
|--------|------|---------|
| Swiper | 메인 배너 슬라이더 | 기설치 |
| next-intl | i18n 라벨 | 기설치 |
| Zustand | 상태 관리 (cate, filter, auth, coin, chat) | 기설치 |
| WebSocket (네이티브) | 실시간 채팅 메시지 | 브라우저 내장 API |
| DOMPurify | 상담사 소개글 XSS 방어 | 설치 필요 |

---

## 11. 실시간 통신 아키텍처 (WebSocket)

### 11-1. 연결 생명주기

```
채팅방 입장
  → WebSocket 연결 (wss://.../chat/[sessionId])
  → 인증 토큰 전송 (첫 메시지)
  → 연결 확인 응답

메시지 송수신
  → 메시지 전송: { type: 'message', content, replyTo? }
  → 메시지 수신: { type: 'message', from, content, timestamp }
  → 시스템 알림: { type: 'system', content }
  → 상태 변경: { type: 'status', status }
  → 코인 업데이트: { type: 'coin', balance }

자리비움
  → 클라이언트 이탈 감지 (visibilitychange / beforeunload)
  → { type: 'away', userId }

재입장
  → WebSocket 재연결
  → 히스토리 동기화 (REST API 보조)

종료
  → { type: 'end', reason }
  → WebSocket 연결 종료
```

### 11-2. 메시지 객체 구조 (예상)

```js
{
    id: 'msg_001',
    type: 'message', // message | system | image | file
    from: 'user_123', // 발신자 ID
    content: '안녕하세요',
    replyTo: null, // 답장 시 원본 메시지 ID
    timestamp: '2026-03-24T14:30:00Z',
    read: false,
}
```

### 11-3. WebSocket 재연결 전략

- 연결 끊김 감지: `onclose` / `onerror` 이벤트
- 자동 재연결: 지수 백오프 (1초 → 2초 → 4초 → 8초 → 최대 30초)
- 최대 재연결 시도: 10회
- 재연결 실패 시: "연결이 끊어졌습니다. 다시 시도해 주세요" 배너 + 수동 재연결 버튼
- 재연결 성공 시: 마지막 수신 메시지 이후 히스토리 동기화 (REST API)

---

## 12. 반응형

- 모바일 우선: 390px 기준 레이아웃
- 최대 너비: `max-w-[43rem]` (430px), `mx-[auto]` — `app/[locale]/layout.js`의 SSOT wrapper에서 일원화 (2026-04-20)
- 채팅방: 전체화면 (max-w 적용, Footer 미표시)
- 채팅 입력 영역: `fixed bottom-0` (키보드 위)
- 채팅 메시지 영역: `flex-1 overflow-y-auto` (스크롤 가능)
- 이미지 뷰어: `fixed inset-0 z-[50]` 전체화면 오버레이
- 연결중 오버레이: `fixed inset-0 z-[50]` 전체화면

---

## 13. 미확정 사항

- [ ] WebSocket 서버 URL 및 프로토콜 상세 (wss:// 경로, 인증 방식)
- [ ] 파일 업로드 최대 크기 및 허용 파일 형식 (이미지만? 문서도?)
- [ ] 코인 차감 정확한 타이밍 (구간 시작 시 선차감 vs 구간 종료 시 후차감)
- [ ] 자리비움 시 코인 차감 지속 확정 여부 (지속? 일시정지?)
- [ ] 채팅 메시지 최대 글자수 제한
- [ ] 이미지 전송 시 압축 정책 (원본 전송 vs 서버 리사이즈)
- [ ] 답장하기 롱프레스 시간 기준 (500ms? 1000ms?)
- [ ] 상담사 측 내담자 정보 패널 정확한 필드 구성 (Figma 시안 필요)
- [ ] 후기 작성 폼 상세 구성 (별점 + 텍스트 + 스타일 태그 선택?)
- [ ] 5분 미만 종료 시 후기 작성 "유도" 방식 (버튼? 자동 노출?)
- [ ] 코인 충전 후 채팅방 복귀 메커니즘 (자동 복귀? 수동 재입장?)
- [ ] 푸시알림 구현 방식 (FCM? APNs? Web Push?)
- [ ] 상담사 수락/거절 UI 상세 (전체화면? 배너? 바텀시트?)
- [ ] 차단 회원 판별 시점 (연결 요청 시? 사전 차단 목록 캐싱?)
- [ ] 채팅 히스토리 보관 기간 (상담 종료 후 몇 일?)
- [ ] 동시 채팅 세션 제한 (내담자: 1개? 상담사: 여러 개?)
- [ ] KR/JP/US 국가별 차이 사항 (결제 통화 외)
- [ ] 메인 배너 데이터 소스 및 API 응답 구조
- [ ] 상담사 카드 정확한 필드 구성 (Figma 시안 필요)
- [ ] 카테고리 하위 탭 국가별 구성표
