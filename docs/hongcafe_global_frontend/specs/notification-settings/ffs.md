# Frontend Functional Spec — Notification Settings (알림 수신 설정)

> Source: 화면설계서 PPTX Slide S300 (member-mymenu §3-2 회원정보 — 알림 수신 설정) + as-built API 라우트(`/api/members/setting-alarm`) + 감사 문서(`2026-04-16-auth-member-api-spec-review.md`)
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | Notification Settings (알림 수신 설정) |
| 사용자 목표 | 회원이 푸시/이메일/SMS 등 채널별 알림 수신 여부를 자율적으로 설정한다 |
| 퍼블리싱 상태 | **미구현** — UI 페이지 없음. mypage 메뉴 항목으로 진입점만 노출 |
| 기능 연동 상태 | **백엔드 API 일부 구현** — `/api/members/setting-alarm` 프록시 라우트 존재 (토글 단일 EP) |
| i18n 네임스페이스 | `notificationSettings` (제안) |
| 지원 로케일 | `en`, `ja` |
| 인증 요구 | 모든 라우트 인증 필수 |

### 비즈니스 가치 / 법적 준수

- **PIPA / GDPR / CASL** 준수 — 사용자가 마케팅성 알림 수신을 명시적으로 동의/철회 가능해야 함.
- 회원가입 시 동의(joinSns/joinEmail의 약관 동의)와 별개로 **상시 변경 가능**해야 함.
- **거래성 알림(필수)**과 **마케팅 알림(선택)** 분리 필수 (PIPA 제22조의2 — 마케팅 정보 수신 동의 별도 분리).

---

## 2. 라우트 구조 (제안 — 미구현)

| 라우트 | 파일 경로 (제안) | 컴포넌트 (제안) | 인증 | 화면설계서 |
|--------|----------------|---------------|------|----------|
| `/[locale]/mypage/info/notification-settings` | `app/[locale]/mypage/info/notification-settings/page.js` | NotificationSettingsForm | 필수 | S300 |

> ⚠️ **라우트 패턴 미확정**: member-mymenu §8 #25 — `/my-menu` vs `/mypage` 결정 후 동일 적용.

---

## 3. 페이지 정의

### 3-1. NotificationSettingsForm — 알림 수신 설정

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/info/notification-settings` |
| 화면설계서 | S300 |

#### UI 섹션 (제안)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | PageNavBar | "Notification Settings" + Home |
| 1 | 거래성 알림 그룹 (필수, readOnly 표시) | 결제 완료 / 상담 매칭 / 보안 알림 — 토글 비활성화 |
| 2 | 마케팅 알림 그룹 (선택) | 푸시 / 이메일 / SMS — 각 토글 + 동의 일자 표시 |
| 3 | 야간 알림 차단 시간대 | 21:00~08:00 등 설정 (제안) |
| 4 | "전체 동의" 토글 | 마케팅 그룹 일괄 토글 |

#### 상태 관리 (제안)

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `pushEnabled` | boolean | (server) | 푸시 알림 |
| `emailEnabled` | boolean | (server) | 이메일 마케팅 |
| `smsEnabled` | boolean | (server) | SMS 마케팅 |
| `nightBlockStart`/`End` | string | `'21:00'`/`'08:00'` | 야간 차단 시간대 |
| `agreedAt` | object | (server) | 채널별 동의 일자 |
| `isSubmitting` | boolean | `false` | 중복 제출 방지 |

#### API 연동

| 엔드포인트 | 메서드 | Request Body | 용도 | 구현 상태 |
|-----------|--------|-------------|------|----------|
| `GET /api/members/notification-settings` (제안) | GET | — | 현재 설정 조회 | **백엔드 EP 신설 필요 (유형 C)** |
| `POST /api/members/setting-alarm` | POST | `{ alarmType?, value }` (`"true" → "N"`, 그 외 → `"Y"` 변환) — 백엔드 스펙 확인 필요 | 단일 토글 변경 | **구현** (rate 20/60s, JWT 필수) |
| `POST /api/members/notification-settings` (제안) | POST | `{ push, email, sms, nightBlockStart, nightBlockEnd }` | 다채널 일괄 변경 | **백엔드 EP 신설 필요** |

> as-built `setting-alarm`은 단일 토글 EP — 다채널/시간대 설정을 위해서는 신규 EP 필요. 또는 `alarmType` 파라미터를 채널별로 호출.

#### 인터랙션 (제안)

| 액션 | 동작 |
|------|------|
| 채널별 토글 클릭 | `secureFetch('/api/members/setting-alarm', POST, {alarmType, value})` → optimistic UI 갱신 → 실패 시 rollback |
| 전체 동의 토글 | 푸시/이메일/SMS 일괄 호출 (다중 호출 또는 신규 일괄 EP) |
| 야간 시간대 변경 | (신규 EP 필요) |

#### 비즈니스 규칙

| 규칙 | 설명 / 근거 |
|------|------------|
| **거래성 알림 강제** | 결제/보안/상담 매칭은 사용자 동의 무관 발송 — UI에서 readOnly로 표시 (CASL 면제 사유) |
| **마케팅 알림 명시 동의** | PIPA 제22조의2 — 별도 분리 동의, 상시 철회 가능 |
| **동의 일자 기록** | GDPR Art. 7(1) — 동의 입증 책임. 채널별 동의 일자 저장 |
| **야간 알림 차단** | 정보통신망법 제50조 — 21~08시 사전 동의 없이 영리 목적 광고성 정보 전송 금지 |
| **성공 시 토스트** | 변경 즉시 반영 + "Settings saved" 토스트 |

---

## 4. 미확정 사항 (v1.0)

| # | 우선순위 | 유형 | 항목 | 설명 |
|---|---------|------|------|------|
| 1 | **[CRITICAL]** | C | UI 페이지 미구현 | NotificationSettingsForm 페이지 + 컴포넌트 신설 필요 |
| 2 | **[CRITICAL]** | C | 다채널 일괄 EP | as-built `setting-alarm`은 단일 토글 — 채널별 일괄 조회/저장 EP 신설 또는 `alarmType` 파라미터 매핑 정의 |
| 3 | **[HIGH]** | C | 야간 알림 차단 시간대 | 정보통신망법 §50 준수 — 시간대 설정 EP + UI 신설 |
| 4 | **[HIGH]** | C | 동의 일자 기록 (GDPR Art. 7) | 채널별 동의/철회 일자 저장 정책 — 백엔드 스펙 확정 |
| 5 | **[HIGH]** | D | 거래성 vs 마케팅 분리 | 채널별 분류 정책 (예: 푸시는 양쪽 다, 이메일은 마케팅만 등) |
| 6 | **[HIGH]** | D | 라우트 패턴 통일 | member-mymenu §8 #25 |
| 7 | **[MEDIUM]** | C | 푸시 알림 기기 등록 | FCM 토큰 등록/해제 정책 (네이티브 앱 의존) |
| 8 | **[MEDIUM]** | D | 디자인 시안 | Figma 발급 필요 |
| 9 | **[LOW]** | C | 동의 이력 표시 | 사용자가 자신의 동의 변경 이력 조회 가능 (감사 추적) |

---

## 5. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | 신규 도메인 분리 작성 — member-mymenu §3-2 회원정보 영역의 "알림 수신 설정" 분리. as-built `/api/members/setting-alarm` 단일 토글 EP 매핑. PIPA §22조의2 / GDPR Art. 7 / 정보통신망법 §50(야간 알림) 준수 의무 명시. UI 미구현 + 다채널 EP 신설 필요 CRITICAL 표기 | 명우현 |
