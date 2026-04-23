# QA Scenario Sheet — Login History

> Source: ffs.md v1.0 + OWASP ASVS V3.2.4 / GDPR Art. 32 / PIPA §29
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

> ⚠️ **백엔드 EP + UI 모두 미구현** — 본 시나리오는 향후 구현 시 검증 항목 정의용.

---

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390×844 |
| 인증 | JWT 필수 (`hc_access`) |
| 보안 | CSRF + apiHandler 200 래핑 함정 검증 |
| 보관 기간 | PIPA §29 — 최소 1년 백엔드 보관 |

---

## 2. LoginHistoryList (`/mypage/login-history`) — 미구현

### 2-1. 렌더링 (제안)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| LH-R-01 | 인증 진입 | 로그인 | `/mypage/login-history` | HTTP 200 + 이력 목록 | P0 |
| LH-R-02 | 비인증 진입 | 비로그인 | 동일 URL | `/login` 리다이렉트 | P0 |
| LH-R-03 | 안내 문구 | 인증 | 영역 확인 | "If you see unfamiliar login attempts..." 노출 | P1 |
| LH-R-04 | 이력 항목 | 인증 | 목록 확인 | 시각/IP(마스킹)/디바이스(UA)/국가/결과/방법 표시 | P0 |
| LH-R-05 | 비번 변경 CTA | 인증 | 버튼 확인 | "Change Password" 버튼 노출 | P0 |
| LH-R-06 | 활성 세션 진입 | 인증 | 링크 확인 | "View Active Sessions" → `/mypage/login-history/sessions` | P0 |
| LH-R-07 | 페이지네이션 | 30건 이상 이력 | 무한 스크롤 또는 "더보기" | nextCursor로 추가 fetch | P1 |
| LH-R-08 | 빈 이력 (신규 가입자) | 인증, 이력 0 | 페이지 진입 | "No login history yet" 안내 | P2 |

### 2-2. 인터랙션 (제안)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| LH-A-01 | 이력 fetch | 페이지 진입 | network | (신설) `secureFetch('/api/members/login-history?limit=20', GET)` | P0 |
| LH-A-02 | 무한 스크롤 | 스크롤 끝 도달 | network | nextCursor로 다음 20건 추가 | P1 |
| LH-A-03 | 비번 변경 CTA | 버튼 클릭 | 이동 | `/mypage/info/password` | P0 |
| LH-A-04 | 활성 세션 진입 | 링크 클릭 | 이동 | `/mypage/login-history/sessions` | P0 |
| LH-A-05 | Suspicious 보고 (제안) | 이력 항목의 "Suspicious" 클릭 | 모달 → 확인 | (신설) `POST /api/members/login-history/report-suspicious` → 비번 강제 변경 페이지 | P1 |

---

## 3. ActiveSessionsList (`/mypage/login-history/sessions`) — 미구현

### 3-1. 렌더링 / 인터랙션 (제안)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| AS-R-01 | 인증 진입 | 로그인 | `/mypage/login-history/sessions` | HTTP 200 + 세션 목록 | P0 |
| AS-R-02 | 현재 세션 강조 | 인증 | 첫 항목 | "Current Session" 라벨 + Sign out 버튼 비활성 (자기 자신 종료 불가) | P0 |
| AS-R-03 | 다른 활성 세션 표시 | 다중 디바이스 로그인 상태 | 목록 | 디바이스/국가/마지막 활동 시각 + Sign out 버튼 | P0 |
| AS-A-01 | 세션 fetch | 페이지 진입 | network | (신설) `secureFetch('/api/members/sessions', GET)` | P0 |
| AS-A-02 | 단일 세션 종료 | 다른 세션의 Sign out 클릭 | 확인 모달 → 확인 | (신설) `secureFetch('/api/members/sessions/{id}', DELETE)` → 해당 세션 무효화 | P0 |
| AS-A-03 | 전체 다른 세션 종료 | "Sign out all other sessions" 클릭 | 확인 모달 → 확인 | (신설) `secureFetch('/api/members/sessions?all=true', DELETE)` → 현재 세션 외 모두 무효화 | P0 |
| AS-A-04 | 세션 종료 후 즉시 반영 | 종료 후 | 백엔드 검증 | 해당 세션의 hc_access/hc_refresh 무효화 (Refresh Token Reuse Detection) | P0 |

---

## 4. 보안 검증

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| LH-SEC-01 | CSRF 첨부 | 모든 mutation EP | network 캡처 | `x-csrf-token` 자동 첨부 | P0 |
| LH-SEC-02 | JWT 필수 | hc_access 만료 | API 호출 | 401 → `/login` 리다이렉트 | P0 |
| LH-SEC-03 | PII 마스킹 | IP 노출 검사 | 응답 + 렌더 | 마지막 옥텟 마스킹 (예: `192.168.1.***`) | P0 |
| LH-SEC-04 | 다른 사용자 이력 접근 차단 | sessionId 변조 시도 | DELETE 호출 | 백엔드 ownership 검증 → 403 | P0 |
| LH-SEC-05 | 자기 세션 종료 차단 | currentSessionId DELETE 시도 | API 호출 | 백엔드 거부 → 400/403 | P0 |
| LH-SEC-06 | XSS via UA/디바이스명 | mock UA=`<script>` | 렌더 | React 자동 escape — 미실행 | P0 |
| LH-SEC-07 | Refresh Token Reuse Detection | 종료된 세션의 refresh 시도 | network | 백엔드 — 모든 세션 무효화 (보안 침해 추정) | P0 |
| LH-SEC-08 | apiHandler 200+`fail` 함정 | mock | API 호출 | `data.response==='success'` 체크 | P0 |

---

## 5. 법적 준수 검증

| # | 시나리오 | 검증 | 우선순위 |
|---|---------|------|---------|
| LH-LIC-01 | OWASP ASVS V3.2.4 | 마지막 로그인 시각/IP/디바이스 표시 | P0 |
| LH-LIC-02 | GDPR Art. 32 | 비정상 접근 탐지 가시성 + 알림 채널 | P0 |
| LH-LIC-03 | PIPA §29 보관 기간 | 최소 1년 백엔드 보관 | P0 |
| LH-LIC-04 | GDPR Art. 15 데이터 이동권 | 사용자 이력 익스포트 (CSV/JSON) | P2 (미확정 #14) |
| LH-LIC-05 | 본인 열람권 | 사용자 본인의 이력만 조회 가능 | P0 |

---

## 6. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | 신규 도메인 시나리오 — UI + 백엔드 EP 모두 미구현 상태. 렌더링/인터랙션/보안(CSRF/JWT/PII 마스킹/ownership 검증/자기 세션 종료 차단/Refresh Token Reuse Detection/XSS/200래핑) + §5 법적 준수(OWASP ASVS V3.2.4 / GDPR Art. 32, 15 / PIPA §29) 검증. Suspicious 보고 → 자동 비번 강제 변경 + 전체 세션 종료 플로우 정의 | 명우현 |
