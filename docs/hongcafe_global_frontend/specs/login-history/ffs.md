# Frontend Functional Spec — Login History (로그인 이력)

> Source: 화면설계서 미정의(신규 도메인) + 보안 모범 사례(OWASP ASVS V3.2.4 / GDPR Art. 32 / Korea PIPA §29) + 감사 문서(`2026-04-16-auth-member-api-spec-review.md`)
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | Login History (로그인 이력 + 활성 세션 관리) |
| 사용자 목표 | 회원이 자신의 로그인 이력(시각/IP/디바이스/지역)을 조회하고, 활성 세션을 원격 종료(force logout)한다 |
| 퍼블리싱 상태 | **미구현** — UI 페이지 + 백엔드 EP 모두 미존재 |
| 기능 연동 상태 | **미연동** — 신규 도메인 |
| i18n 네임스페이스 | `loginHistory` (제안) |
| 지원 로케일 | `en`, `ja` |
| 인증 요구 | 모든 라우트 인증 필수 |

### 비즈니스 가치 / 보안

- **OWASP ASVS V3.2.4** — 사용자가 자신의 활성 세션 + 마지막 로그인 시각을 확인 가능해야 함.
- **GDPR Art. 32 (Security of processing)** — 비정상 접근 탐지를 위한 사용자 가시성 제공.
- **계정 탈취 탐지**: 사용자가 본인이 모르는 로그인을 발견 시 즉시 비번 변경 + 강제 로그아웃 가능.
- **국가/디바이스 변경 알림**: 새로운 디바이스/국가에서 로그인 시 이메일/푸시 알림 (별도 스코프).

---

## 2. 라우트 구조 (제안 — 미구현)

| 라우트 | 파일 경로 (제안) | 컴포넌트 (제안) | 인증 | 설명 |
|--------|----------------|---------------|------|------|
| `/[locale]/mypage/login-history` | `app/[locale]/mypage/login-history/page.js` | LoginHistoryList | 필수 | 로그인 이력 목록 |
| `/[locale]/mypage/login-history/sessions` | `app/[locale]/mypage/login-history/sessions/page.js` | ActiveSessionsList | 필수 | 활성 세션 관리 (원격 종료) |

> 라우트 패턴 미확정 — member-mymenu §8 #25 결정 후 동일 적용.

---

## 3. 페이지 정의

### 3-1. LoginHistoryList — 로그인 이력 목록

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/login-history` |
| 화면설계서 | (없음 — 신규 제안) |

#### UI 섹션 (제안)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | PageNavBar | "Login History" + Home |
| 1 | 안내 문구 | "If you see unfamiliar login attempts, change your password immediately." |
| 2 | 이력 리스트 | 최근 30일/100건 — 시각(상대) + IP + 디바이스(UA) + 국가(GeoIP) + 결과(success/fail) + 로그인 방법(Email/Google/Apple/Line/Facebook) |
| 3 | 비번 변경 CTA | 의심 시 즉시 진입 — `/mypage/info/password` |
| 4 | 활성 세션 보기 | `/mypage/login-history/sessions` |
| 5 | 페이지네이션 | 무한 스크롤 또는 "더보기" |

#### 상태 관리 (제안)

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `entries` | array | [] | 로그인 이력 |
| `cursor` | string \| null | null | 페이지네이션 커서 |
| `isLoading` | boolean | false | fetch 상태 |
| `error` | string | '' | 에러 메시지 |

#### API 연동 (제안 — 백엔드 신설 필요)

| 엔드포인트 | 메서드 | Request Body | Response | 구현 상태 |
|-----------|--------|-------------|----------|----------|
| `GET /api/members/login-history` | GET | query: `?cursor=X&limit=20` | `{ entries: [...], nextCursor }` | **미구현 (유형 C)** |
| `POST /api/members/login-history/report-suspicious` (제안) | POST | `{ entryId }` | 의심 보고 → 자동 비번 강제 변경 | 미구현 |

#### 인터랙션 (제안)

| 액션 | 동작 |
|------|------|
| 페이지 진입 | `secureFetch('/api/members/login-history', GET)` → 첫 20건 표시 |
| 무한 스크롤 | nextCursor로 다음 20건 추가 |
| "Suspicious 보고" 클릭 | 모달 → 확인 → API 호출 → 비번 강제 변경 페이지 이동 |
| "Change Password" 클릭 | `/mypage/info/password` 이동 |

---

### 3-2. ActiveSessionsList — 활성 세션 관리

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/login-history/sessions` |
| 화면설계서 | (없음 — 신규 제안) |

#### UI 섹션 (제안)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | PageNavBar | "Active Sessions" + Home |
| 1 | 현재 세션 표시 | 자신의 디바이스 (강조 표시) — 종료 불가 |
| 2 | 다른 활성 세션 리스트 | 디바이스 + 국가 + 마지막 활동 시각 + "Sign out" 버튼 |
| 3 | "Sign out all other sessions" 버튼 | 일괄 종료 |

#### API 연동 (제안 — 백엔드 신설 필요)

| 엔드포인트 | 메서드 | Request Body | Response | 구현 상태 |
|-----------|--------|-------------|----------|----------|
| `GET /api/members/sessions` | GET | — | `{ sessions: [...], current: {sessionId} }` | **미구현 (유형 C)** |
| `DELETE /api/members/sessions/{sessionId}` | DELETE | — | `{ response: 'success' }` | **미구현** |
| `DELETE /api/members/sessions?all=true` | DELETE | — | 전체 다른 세션 종료 | **미구현** |

---

## 4. 비즈니스 규칙 / 보안 정책

| 규칙 | 설명 / 근거 |
|------|------------|
| **OWASP ASVS V3.2.4** | 사용자에게 마지막 로그인 시각/IP/디바이스 표시 |
| **GDPR Art. 32** | 비정상 접근 탐지 — 사용자 가시성 + 알림 채널 |
| **PIPA §29 (안전성 확보 조치)** | 접속 기록 보관 1년 이상, 사용자 본인 열람권 보장 |
| **세션 종료 정책** | 다른 세션 종료 시 백엔드가 해당 hc_access/hc_refresh 즉시 무효화 (Refresh Token Reuse Detection 권고) |
| **PII 마스킹** | IP 마지막 옥텟 마스킹 (예: `192.168.1.***`) — 사용자 본인이라도 |
| **국가/디바이스 변경 알림** | 새 국가/디바이스 로그인 시 이메일 알림 (notification-settings 도메인과 통합) |
| **비번 강제 변경** | "Suspicious 보고" → 모든 세션 강제 종료 + 비번 변경 페이지 강제 진입 |

---

## 5. 미확정 사항 (v1.0)

| # | 우선순위 | 유형 | 항목 | 설명 |
|---|---------|------|------|------|
| 1 | **[CRITICAL]** | C | 백엔드 EP 신설 | `GET /api/members/login-history` + `GET/DELETE /api/members/sessions` 모두 미구현. 백엔드 우선 결정 |
| 2 | **[CRITICAL]** | C | 세션 저장소 | Redis/DB 세션 저장 구조 설계 (현재는 JWT stateless 추정) |
| 3 | **[HIGH]** | C | UI 페이지 미구현 | 2개 페이지 신설 |
| 4 | **[HIGH]** | C | 보관 기간 정책 | PIPA §29 — 최소 1년. 백엔드 보관 기간 + 프론트 노출 기간 결정 |
| 5 | **[HIGH]** | C | PII 마스킹 정책 | IP/디바이스 식별자 마스킹 정책 |
| 6 | **[HIGH]** | C | 알림 통합 | 새 국가/디바이스 로그인 시 이메일/푸시 알림 — notification-settings 도메인 통합 |
| 7 | **[HIGH]** | D | 라우트 패턴 통일 | member-mymenu §8 #25 |
| 8 | **[MEDIUM]** | C | 진입점 (mypage 메뉴) | mypage 메뉴 그룹에 "Login History" 항목 추가 |
| 9 | **[MEDIUM]** | C | Suspicious 보고 처리 | 보고 → 자동 비번 변경 강제 + 모든 세션 종료 |
| 10 | **[MEDIUM]** | D | 디자인 시안 | Figma 발급 필요 |
| 11 | **[MEDIUM]** | C | Refresh Token Reuse Detection | 백엔드 — 한 번 사용된 refresh token 재사용 시 모든 세션 무효화 |
| 12 | **[LOW]** | C | 다국어 시각 표시 | "5분 전" / "어제" 등 상대 시각 i18n |
| 13 | **[LOW]** | C | 디바이스 아이콘 | 모바일/데스크톱/태블릿 아이콘 매핑 (User-Agent 파싱) |
| 14 | **[LOW]** | C | 익스포트 (CSV/JSON) | GDPR Art. 15 (데이터 이동권) — 사용자가 자신의 이력 다운로드 |

---

## 6. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | 신규 도메인 정의 — 화면설계서 미정의 상태에서 OWASP ASVS V3.2.4 / GDPR Art. 32 / Korea PIPA §29 보안 모범 사례 기반 도메인 spec 작성. UI 페이지 2개(이력 목록 + 활성 세션) + 백엔드 EP 4개 신설 필요. PII 마스킹/세션 종료/Suspicious 보고/Refresh Token Reuse Detection 등 보안 정책 명시 | 명우현 |
