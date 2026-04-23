# 화면설계서 기반 FFS/QSS 심층 분석 보고서

> 분석일: 2026-03-24
> 대상: 15개 도메인 × (FFS + QSS) = 33개 파일, 11,517줄, ~1,880개 시나리오
> 분석 관점: 크로스도메인 정합성 / 핵심 매출 도메인 품질 / 대시보드 도메인 완전성

---

## 종합 평가

| 도메인 | 점수 | 상태 | 핵심 이슈 |
|--------|------|------|----------|
| intro | 9/10 | ✅ Ready | — |
| login | 9/10 | ✅ Ready | SNS 국가별 분기 미구현 |
| join | 8/10 | ✅ Ready | 기가입/재가입 플로우 미구현 상태 |
| find-account | 8/10 | ✅ Ready | reCAPTCHA 조건부 렌더링 상세 보완 필요 |
| layout | 7/10 | ⚠️ 보완 필요 | green 컬러값 미확정, 로케일별 탭 분기 로직 미명시 |
| **phone-consultation** | **8.6/10** | **✅ Ready** | 코인 차감 로직 phone 고유 명세 부족 |
| **chat-consultation** | **7.0/10** | **🔴 보완 필수** | WebSocket 아키텍처 비현실적, 상담사 화면 UI 미명세 |
| **coin-charging** | **9.0/10** | **✅ Ready (PG 의존)** | PG사 미선정이 블로커 |
| category | 8/10 | ✅ Ready | — |
| search | 8/10 | ✅ Ready | — |
| reviews | 8/10 | ✅ Ready | — |
| favorites | 8/10 | ✅ Ready | 로그인 리다이렉트 vs 인페이지 유도 불일치 |
| **member-mymenu** | **8.5/10** | **✅ Ready** | 자동충전 실패 복구 플로우 누락 |
| **counselor-mymenu** | **6.5/10** | **🔴 보완 필수** | 상담사 단계 승급/강등 규칙 완전 누락, QSS 밀도 부족 |
| counselor-registration | 8.5/10 | ✅ Ready | 반려 사유 UI 미명세 |

---

## CRITICAL 이슈 (구현 전 반드시 해결)

### 1. 채팅상담 — WebSocket 아키텍처 비현실적
- **문제**: FFS가 WebSocket 기반 실시간 채팅을 명시하나, Next.js App Router에서 WebSocket 연결을 페이지 전환 간 유지하는 방법이 미명시
- **영향**: 채팅방 구현 자체가 불가능
- **해결 방향**: (1) 외부 WebSocket 서비스(Socket.io) + 클라이언트 전용 Provider, 또는 (2) Polling 기반 fallback 명시 필요
- **파일**: `chat-consultation/ffs.md` §11

### 2. 상담사 단계 승급/강등 규칙 완전 누락
- **문제**: 화이트→옐로우→그린→블루 4단계 존재는 기술되었으나, 승급 조건(월 상담 횟수? 매출 금액?), 강등 조건, 전속계약 비즈니스 규칙이 전무
- **영향**: 상담사 마이메뉴 핵심 기능 구현 불가
- **해결 방향**: 기획자에게 승급/강등 기준표 요청
- **파일**: `counselor-mymenu/ffs.md` §3-2-1

### 3. API 응답 형식 불일치
- **문제**: 도메인별로 2가지 성공 표시 방식 혼재
  - `{ response: 'success', items }` — phone, chat, category, search
  - `{ success: boolean, data }` — reviews, favorites, coin-charging
- **영향**: 클라이언트 파싱 로직이 도메인마다 달라져 유지보수 비용 증가
- **해결 방향**: 전역 표준 정의 → `{ success: boolean, data: T, message?: string }`
- **파일**: 전체 15개 FFS

### 4. 자동충전 실패 복구 플로우 없음
- **문제**: coin-charging과 member-mymenu 모두 "자동충전 실패 시" 동작을 정의하지 않음
- **영향**: 실제 결제 실패 시 사용자가 인지할 방법 없음
- **해결 방향**: 재시도 스케줄 + 실패 알림(푸시+인앱) + 카드 재등록 유도 UX 명시
- **파일**: `coin-charging/ffs.md`, `member-mymenu/ffs.md` §3-11

---

## HIGH 이슈 (QA 전까지 해결)

### 5. Zustand 스토어 아키텍처 미정의
- `useFilterStore` — 글로벌? 도메인별? phone/chat/search 모두 참조하나 범위 불명
- `useAuthStore` — 4개 도메인에서 참조하나 정의 없음
- `useCoinStore` — coin-charging과 member-mymenu 모두 사용하나 단일 출처 미명시

### 6. CounselorCard 공유 컴포넌트 Props 불일치
- phone: `[번호]` 표시, chat: 번호 미표시 — 조건부 렌더링 Props 미정의
- 8개 이상 도메인에서 참조하나 통합 인터페이스 없음

### 7. 로그인 필요 페이지 — 리다이렉트 vs 인페이지 유도 불일치
- layout/ffs.md: 단골 클릭 → "로그인 페이지 리다이렉트"
- favorites/ffs.md: "리다이렉트 아닌 인페이지 유도"
- 전역 패턴 결정 필요

### 8. 상담사 마이메뉴 QSS 밀도 부족
- 78슬라이드 → 349줄 QSS (~180 시나리오)
- member-mymenu는 67슬라이드 → 665줄 (176 시나리오)
- 특히 채팅상담 관리가 3개 시나리오만으로 심각하게 부족

### 9. 공유 데이터 모델 정의 부재
- CounselorCard, ReviewCard, PostingCard, Banner 등 8+ 도메인에서 사용되는 모델의 필드 정의가 분산되어 있음
- 통합 `_data-models.md` 필요

---

## MEDIUM 이슈 (릴리스 전 해결)

| # | 이슈 | 영향 도메인 |
|---|------|-----------|
| 10 | 라우트 베이스 경로 불일치 (`/call` vs CLAUDE.md kebab-case) | phone, chat, counselor |
| 11 | i18n 네임스페이스 케이싱 불일치 (`myMenu` vs `counselorMyMenu`) | member, counselor |
| 12 | FilterBottomSheet 범위 모호 (글로벌 재사용 vs 도메인 전용) | phone, chat, search |
| 13 | 전화상담 코인 차감 단위 불명확 ("코인/1분" vs "30초당 N코인") | phone |
| 14 | chat 정렬 옵션 6개 vs phone 8개 — 의도적 차이인지 누락인지 불명 | phone, chat |
| 15 | 상담사 등록 반려 사유 표시 UI 미명세 | counselor-registration |
| 16 | 페이백/100코인특가 이벤트 비즈니스 규칙 미확정 | phone, chat |

---

## 도메인별 상세 스코어카드

### 핵심 매출 3도메인

| 기준 | Phone | Chat | Coin |
|------|-------|------|------|
| 기획자 의도 반영 | 8/10 | 6/10 | 9/10 |
| QSS 실행 가능성 | 9/10 | 5/10 | 8/10 |
| 비즈니스 로직 완전성 | 7/10 | 6/10 | 9/10 |
| 누락 항목 | 10/10 | 9/10 | 10/10 |
| **평균** | **8.6** | **7.0** | **9.0** |

### 대시보드 3도메인

| 기준 | Member | Counselor | Registration |
|------|--------|-----------|-------------|
| 페이지 커버리지 | 14/14 (100%) | 8/8 (100%) | 2/2 (100%) |
| 유효성 메시지 | 31/31 (100%) | ~7/12 (60%) | 11/11 (100%) |
| 비즈니스 규칙 | 90% | 60% | 85% |
| QSS 자동화 가능 | 85% | 65% | 90% |

---

## Phone vs Chat 구조 중복 분석

| 항목 | 중복도 | 차이점 |
|------|-------|--------|
| 메인 페이지 | 95% | 테마(green/purple)만 다름 |
| 카테고리 필터 | 90% | chat 정렬 6개 vs phone 8개 |
| 프로필 탭 5개 | 100% | 동일 |
| 상담사 카드 | 95% | phone은 [번호] 표시 |
| 상담사 상태 | 100% | 동일 |
| 접속알림/단골 | 100% | 동일 |
| **상담하기 CTA** | **50%** | **phone=전화연결, chat=채팅방+실시간 메시징** |

→ 구현 시 CounselorCard, FilterBottomSheet, ProfileTabs, ReviewCard를 공유 컴포넌트로 추출하면 **양 도메인의 70%를 1회 구현으로 커버 가능**.

---

## 기획자에게 확인 필요 사항 (미확정 사항 종합)

| 우선순위 | 질문 | 관련 도메인 |
|---------|------|-----------|
| 🔴 P0 | 상담사 단계 승급/강등 조건표 | counselor-mymenu |
| 🔴 P0 | PG사 선정 (KR/JP/US 각각) | coin-charging |
| 🔴 P0 | 채팅 실시간 통신 방식 (WebSocket vs Polling vs 외부 서비스) | chat-consultation |
| 🟡 P1 | 전화상담 코인 차감 단위 (30초? 1분?) | phone-consultation |
| 🟡 P1 | 로그인 필요 페이지 전역 패턴 (리다이렉트 vs 인페이지) | favorites, 전체 |
| 🟡 P1 | 자동충전 실패 재시도 정책 | coin-charging, member-mymenu |
| 🟡 P1 | 페이백/100코인특가 환급 금액/비율 | phone, chat |
| 🟢 P2 | green 테마 정확한 Hex값 (#00af79 확정?) | layout |
| 🟢 P2 | 회원탈퇴 후 재가입 대기기간 (7일 확정?) | join |
| 🟢 P2 | 채팅 정렬 옵션이 6개인 것이 의도적인지 | chat-consultation |

---

## 결론

### 즉시 구현 가능 (11개 도메인)
intro, login, join, find-account, phone-consultation, coin-charging, category, search, reviews, favorites, counselor-registration

### 보완 후 구현 가능 (2개 도메인)
- **layout**: green 컬러값 확정 + 로케일별 탭 분기 로직 추가
- **member-mymenu**: 자동충전 실패 복구 플로우 추가

### 기획자 확인 후 구현 가능 (2개 도메인)
- **chat-consultation**: 실시간 통신 아키텍처 결정 필수
- **counselor-mymenu**: 단계 승급/강등 규칙 수신 필수
