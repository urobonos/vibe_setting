# QA Scenario Sheet — Notification Settings

> Source: ffs.md v1.0 + as-built API(`/api/members/setting-alarm`) + 화면설계서 S300
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

> ⚠️ **현재 UI 미구현** — 본 시나리오는 향후 구현 시 검증 항목 정의용. 백엔드 `setting-alarm` EP 동작은 즉시 검증 가능.

---

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390×844 |
| 로케일/호스트 | EN/JP hostname 기반 |
| 인증 | JWT 필수 (`hc_access` 쿠키) |
| Rate limit | `setting-alarm`: 20/60s |
| 보안 | CSRF Signed Double Submit + 200 래핑 함정 검증 |

---

## 2. NotificationSettingsForm (`/mypage/info/notification-settings`) — 미구현

### 2-1. 렌더링 (제안)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| NS-R-01 | 인증 진입 | 로그인 | `/mypage/info/notification-settings` | HTTP 200, 폼 렌더 | P0 |
| NS-R-02 | 비인증 진입 | 비로그인 | 동일 URL | `/login` 리다이렉트 | P0 |
| NS-R-03 | 거래성 그룹 readOnly | 인증 | 영역 확인 | 결제/보안/상담 매칭 토글 비활성 (CASL 면제) | P0 |
| NS-R-04 | 마케팅 그룹 토글 가능 | 인증 | 영역 확인 | 푸시/이메일/SMS 토글 활성 | P0 |
| NS-R-05 | 동의 일자 표시 | 인증 | 각 토글 옆 | "Agreed YYYY-MM-DD" 표시 (GDPR Art. 7) | P1 |
| NS-R-06 | 야간 차단 시간대 | 인증 | 시간대 input | 21:00~08:00 기본값 (정통망법 §50) | P1 |
| NS-R-07 | 전체 동의 토글 | 인증 | 상단 토글 | 마케팅 그룹 일괄 토글 | P1 |
| NS-R-08 | 현재 설정 조회 | 페이지 진입 | network | (신설 EP) `GET /api/members/notification-settings` 호출 → 폼 초기화 | P0 |

### 2-2. 인터랙션 (제안)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| NS-A-01 | 푸시 토글 변경 | 인증 | 토글 클릭 | `secureFetch('/api/members/setting-alarm', POST, {alarmType:'push', value:'Y'\|'N'})` → optimistic UI + 실패 시 rollback | P0 |
| NS-A-02 | 이메일 토글 | 인증 | 토글 클릭 | 동일 패턴 (alarmType: email) | P0 |
| NS-A-03 | SMS 토글 | 인증 | 토글 클릭 | 동일 (alarmType: sms) | P0 |
| NS-A-04 | 토글 변경 시 동의 일자 갱신 | 토글 변경 | 응답 후 | `agreedAt` 갱신 (GDPR Art. 7 입증 책임) | P0 |
| NS-A-05 | 거래성 토글 클릭 차단 | 거래성 그룹 | 토글 클릭 시도 | 비활성화 (UI 차단) | P0 |
| NS-A-06 | 야간 차단 시간 변경 | 인증 | 시간 변경 | (신설 EP) 호출 → 변경 반영 | P1 |
| NS-A-07 | 전체 동의 일괄 토글 | 인증 | 클릭 | 마케팅 채널 다중 호출 또는 (신설) 일괄 EP | P1 |
| NS-A-08 | 변경 실패 rollback | mock 실패 | 토글 클릭 후 | 이전 상태로 복원 + 에러 토스트 | P0 |

---

## 3. 보안 검증

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| NS-SEC-01 | CSRF 첨부 | 토글 클릭 | network 캡처 | `x-csrf-token` 자동 첨부 | P0 |
| NS-SEC-02 | JWT 필수 | hc_access 만료 | 토글 클릭 | 401 → `/login` 리다이렉트 | P0 |
| NS-SEC-03 | rate limit (20/60s) | 21회 빠른 호출 | 21번째 클릭 | 429 응답 + Retry-After | P0 |
| NS-SEC-04 | apiHandler 200+`fail` 함정 | mock | 토글 클릭 | `data.response==='success'` 체크로 fail 분기 | P0 |
| NS-SEC-05 | XSS via 응답 msg | mock `data.msg=<script>` | 에러 표시 | `escapeHtml` 적용 | P0 |

---

## 4. 법적 준수 검증

| # | 시나리오 | 검증 | 우선순위 |
|---|---------|------|---------|
| NS-LIC-01 | PIPA §22조의2 마케팅 분리 동의 | 거래성 vs 마케팅 그룹 별도 분리 + 마케팅 상시 철회 가능 | P0 |
| NS-LIC-02 | GDPR Art. 7 동의 입증 | 채널별 동의 일자 저장 + 사용자에게 표시 | P0 |
| NS-LIC-03 | 정통망법 §50 야간 차단 | 21~08시 사전 동의 없이 마케팅 발송 불가 — 백엔드 스케줄러 책임 | P0 |
| NS-LIC-04 | CASL 거래성 면제 | 거래성 알림은 동의 무관 발송 — UI에서 readOnly 표시 | P1 |
| NS-LIC-05 | 동의 철회 즉시 반영 | 토글 OFF → 백엔드 즉시 반영 (24h 내 발송 중단) | P0 |

---

## 5. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | 신규 도메인 시나리오 — UI 미구현 + 단일 토글 EP만 구현된 상태. 렌더링/인터랙션/보안(CSRF/JWT/rate 20/60s/200래핑/XSS) + §4 법적 준수(PIPA §22조의2/GDPR Art. 7/정통망법 §50/CASL) 검증. 다채널 일괄 EP/조회 EP 신설 필요 CRITICAL 표기 | 명우현 |
