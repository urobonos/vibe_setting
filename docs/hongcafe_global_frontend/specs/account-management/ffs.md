# Frontend Functional Spec — Account Management (계정 관리)

> Source: 화면설계서 PPTX Slides S296~S304 (회원정보 영역, member-mymenu 도메인 §3-2 기반) + as-built API 라우트(`/api/members/change-passwd`, `/api/members/change-nick`, `/api/members/update-phone`, `/api/members/delete-user`, `/api/members/update-home-set`) + member-mymenu/MyPageContent.js 메뉴 진입점 + 감사 문서(`2026-04-16-auth-member-api-spec-review.md`)
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | Account Management (계정 관리 — 닉네임/휴대폰/비밀번호/탈퇴) |
| 사용자 목표 | 로그인된 회원이 자신의 계정 정보를 변경하거나 탈퇴한다 |
| 퍼블리싱 상태 | **미구현** — UI 페이지 없음. mypage 스캐폴드의 `<Link href="/${locale}/mypage/info">` 메뉴 항목만 존재 |
| 기능 연동 상태 | **백엔드 API 일부 구현** — change-passwd / change-nick / update-phone / delete-user / update-home-set 프록시 라우트 존재. 클라이언트 UI 미구현 |
| i18n 네임스페이스 | `accountManagement`, `accountInfo`, `nicknameChange`, `phoneChange`, `passwordChange`, `notificationSettings`, `withdraw` |
| 지원 로케일 | `en`, `ja` |
| 뷰포트 기준 | 모바일 390x844 |
| 인증 요구 | **모든 라우트 인증 필수** — 비로그인 시 `/login`으로 리다이렉트 |

### 비즈니스 가치

- 회원이 자신의 식별 정보(닉네임/휴대폰/비밀번호)를 자율적으로 변경 가능.
- 탈퇴 절차 — GDPR/PIPA 등 개인정보 권리 행사 의무.
- 기존 화면설계서의 회원정보 영역(member-mymenu §3-2)을 별도 도메인으로 분리하여 관리.

### 도메인 흐름 요약

```
mypage 진입 (인증 필수)
  └── 메뉴 그룹 → "Account Info" Link
       ↓
/mypage/info (계정정보 메인 — 미구현)
  ├── 닉네임 (Change)        → /mypage/info/nickname
  ├── 휴대폰번호 (Change)    → /mypage/info/phone
  ├── 비밀번호 (Change)      → /mypage/info/password
  ├── 알림 수신 설정         → /mypage/info/notification-settings (Phase B-4)
  └── 회원탈퇴 (CTA)         → /mypage/info/withdraw

각 변경 페이지:
  ├── PageNavBar (뒤로가기 + 제목 + Home)
  ├── 입력 폼
  ├── (필요 시) 본인 인증 (SMS OTP / 비밀번호 재인증)
  ├── 제출 버튼
  └── 성공 시: 토스트/모달 → mypage 또는 info로 복귀
```

---

## 2. 라우트 구조 (제안 — 미구현)

| 라우트 | 파일 경로 (제안) | 컴포넌트 (제안) | 인증 | 화면설계서 |
|--------|----------------|---------------|------|----------|
| `/[locale]/mypage/info` | `app/[locale]/mypage/info/page.js` | AccountInfoMenu | 필수 | S296 |
| `/[locale]/mypage/info/nickname` | `app/[locale]/mypage/info/nickname/page.js` | NicknameChangeForm | 필수 | S297 |
| `/[locale]/mypage/info/phone` | `app/[locale]/mypage/info/phone/page.js` | PhoneChangeForm | 필수 | S298 |
| `/[locale]/mypage/info/password` | `app/[locale]/mypage/info/password/page.js` | PasswordChangeForm | 필수 | S299 |
| `/[locale]/mypage/info/notification-settings` | (Phase B-4 참조) | NotificationSettings | 필수 | S300 |
| `/[locale]/mypage/info/withdraw` | `app/[locale]/mypage/info/withdraw/page.js` | WithdrawFlow | 필수 | S301~S304 |

> ⚠️ **라우트 패턴 미확정**: member-mymenu §8 #25에서 `/my-menu` vs `/mypage` 결정 후 본 도메인도 동일 패턴 적용.

### 진입 가드

| 라우트 | 가드 |
|--------|------|
| 모든 `/mypage/info/*` | Server `getAuthFromCookies()` 미인증 시 `redirect(\`/\${locale}/login\`)` (returnUrl 미전달 — Phase A-4 #27 동일 이슈) |

---

## 3. 페이지 정의

### 3-1. AccountInfoMenu (`/mypage/info`) — 회원정보 메뉴

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/info` |
| 화면설계서 | S296 |

#### UI 섹션 (제안)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | PageNavBar | "Account Info" + Home |
| 1 | 사용자 요약 | 닉네임 + 이메일 + 가입 방법 (Email/Google/Apple/Line/Facebook 표시) |
| 2 | 메뉴 리스트 | Nickname / Phone / Password / Notification Settings / Withdrawal |
| 3 | 각 항목 우측 | chevron_right + (해당 시) 현재 값 표시 |

#### API 연동

| 엔드포인트 | 메서드 | 용도 | 구현 상태 |
|-----------|--------|------|----------|
| `GET /api/members/me` (또는 동등 EP) | GET | 현재 사용자 정보 조회 | **백엔드 EP 검토 필요** |

### 3-2. NicknameChangeForm (`/mypage/info/nickname`)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/info/nickname` |
| 화면설계서 | S297 |

#### UI 섹션 (제안)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | PageNavBar | "Nickname" + Home |
| 1 | 현재 닉네임 표시 | readOnly |
| 2 | 새 닉네임 입력 | controlled input (`validateNickname` 재사용) |
| 3 | 중복 확인 버튼 | `POST /api/members/check-nick` |
| 4 | 변경 버튼 | `POST /api/members/change-nick` |
| 5 | 에러 메시지 | 조건부 |

#### 상태 관리

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `currentNick` | string | `user.acNick` | 현재 닉네임 |
| `newNick` | string | `''` | 새 닉네임 입력 |
| `nickError` | string | `''` | 에러 메시지 |
| `nickAvailable` | boolean \| null | `null` | 중복 확인 결과 |
| `isSubmitting` | boolean | `false` | 중복 제출 방지 |

#### API 연동

| 엔드포인트 | 메서드 | Request Body | 용도 | 구현 상태 |
|-----------|--------|-------------|------|----------|
| `POST /api/members/check-nick` | POST | `{ acNick }` | 중복 확인 | **구현** (라우트 존재) |
| `POST /api/members/change-nick` | POST | **필드명 미확정 (`newNick` vs `acNick`)** — 감사 권고안 3 (MD/YAML 불일치) | 변경 제출 | **구현** (라우트 존재) — 필드명 확정 후 연결 |

> ⚠️ **감사 권고 미반영 (유형 B HIGH)**: change-nick MD-YAML 필드명 불일치 (감사 권고안 3) 백엔드 확정 필요.

### 3-3. PhoneChangeForm (`/mypage/info/phone`)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/info/phone` |
| 화면설계서 | S298 |

#### UI 섹션 (제안)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | PageNavBar | "Phone Number" + Home |
| 1 | 현재 휴대폰 표시 | readOnly |
| 2 | PhoneCertField | 새 휴대폰 + SMS OTP (재사용 — `app/[locale]/_components/PhoneCertField.js`) |
| 3 | 변경 버튼 | `POST /api/members/update-phone` |

#### API 연동

| 엔드포인트 | 메서드 | Request Body | 용도 | 구현 상태 |
|-----------|--------|-------------|------|----------|
| `POST /api/members/send-global-cert` | POST | `{ acCountry, acPhoneNo }` | SMS OTP 발송 | 구현 (PhoneCertField) |
| `POST /api/members/confirm-global-cert` | POST | `{ acCountry, acPhoneNo, acCertNum }` | OTP 검증 | 구현 |
| `POST /api/members/update-phone` | POST | `{ acCountry, acPhoneNo, acCertNum }` (or 인증 토큰) | 휴대폰 변경 | **구현** (라우트 존재) — 백엔드 스펙 확정 필요 |

### 3-4. PasswordChangeForm (`/mypage/info/password`)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/info/password` |
| 화면설계서 | S299 |

#### UI 섹션 (제안)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | PageNavBar | "Change Password" + Home |
| 1 | 현재 비밀번호 입력 | OWASP 권고 — 재인증 필수 (감사 §3.1 #3) |
| 2 | 새 비밀번호 입력 | `validatePassword` 재사용 |
| 3 | 새 비밀번호 확인 입력 | 일치 검증 |
| 4 | 변경 버튼 | `POST /api/members/change-passwd` (인증 필수) |

#### 상태 관리

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `currentPassword` | string | `''` | 기존 비번 (재인증) |
| `newPassword` | string | `''` | 새 비번 |
| `confirmPassword` | string | `''` | 새 비번 확인 |
| `showPassword`/`showNewPassword`/`showConfirm` | boolean × 3 | `false` | 토글 |
| `isSubmitting` | boolean | `false` | 중복 방지 |

#### API 연동

| 엔드포인트 | 메서드 | Request Body | 용도 | 구현 상태 |
|-----------|--------|-------------|------|----------|
| `POST /api/members/change-passwd` | POST | `{ acPasswordOld, acPasswordNew, acPasswordReNew }` (제안) — 백엔드 필드명 확인 필요 | 비번 변경 (JWT 인증 + 기존 비번 재인증) | **구현** (라우트 존재, requireAuth: true, rate 5/60s) |

### 3-5. WithdrawFlow (`/mypage/info/withdraw`)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/mypage/info/withdraw` |
| 화면설계서 | S301~S304 (회원탈퇴 다단계 플로우) |

#### UI 단계 (제안)

| 단계 | 설명 |
|------|------|
| 1 | 탈퇴 안내 (보유 코인 삭제, 데이터 복구 불가, 7일 재가입 제한) |
| 2 | 탈퇴 사유 선택 (라디오 옵션 + 기타 입력) |
| 3 | 비밀번호 재인증 (OWASP §4.04 — 재인증 필수) 또는 SMS OTP (SNS 가입자) |
| 4 | 최종 확인 모달 |
| 5 | 탈퇴 처리 → `setAuth(false, null)` + 쿠키 즉시 만료 (백엔드 Set-Cookie) → `/intro` 또는 `/` 이동 |

#### API 연동

| 엔드포인트 | 메서드 | Request Body | 용도 | 구현 상태 |
|-----------|--------|-------------|------|----------|
| `DELETE /api/members/delete-user` | DELETE | `{ acPassword? \| acCertNum?, withdrawReason }` | 탈퇴 처리 — JWT 필수, rate 3/60s | **구현** (라우트 존재) |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 보유 코인 처리 | 탈퇴 시 보유 코인은 환불 불가 (정책 — 비즈니스 확정 필요) |
| 7일 재가입 제한 | 탈퇴 후 7일 동안 동일 이메일/SNS ID 재가입 차단 (백엔드 책임 — 화면설계서 §S43~S47 join 도메인) |
| 재인증 필수 | OWASP §4.04 — 비번 또는 SMS OTP 재인증 후에만 탈퇴 처리 |
| 데이터 복구 불가 | 채팅 이력/리뷰/구매 내역 모두 삭제 (또는 익명화) — GDPR/PIPA 준수 |
| 탈퇴 후 자동 로그아웃 | 백엔드가 hc_access/hc_refresh 즉시 만료 — 프론트는 `setAuth(false, null)` |

---

## 4. 도메인 내 공유 컴포넌트 (제안)

| 컴포넌트 | 파일 경로 (제안) | 사용 페이지 | 비고 |
|---------|----------------|-----------|------|
| AccountInfoMenuItem | `app/[locale]/mypage/info/_components/AccountInfoMenuItem.js` | info 메인 | 메뉴 행 |
| (재사용) `PhoneCertField` | 기존 | phone | 휴대폰 + OTP |
| (재사용) `validateNickname`/`validatePassword` | `lib/validators/joinEmail.js` | nickname/password | Pure 검증 |
| (재사용) `secureFetch`/`escapeHtml`/`useAuthStore` | 기존 | 전체 | 보안/상태 |
| WithdrawConfirmModal | `app/[locale]/mypage/info/withdraw/_components/WithdrawConfirmModal.js` | withdraw | AlertModal wrapper |

---

## 5. 크로스 도메인 의존성

| 의존 도메인 | 의존 방향 | 설명 |
|-----------|----------|------|
| member-mymenu | mypage → account-management | mypage 메뉴에서 진입 |
| login | account-management → login | 미인증/탈퇴 후 |
| join | (간접) account-management → join | 7일 재가입 제한 정책 공유 |
| `lib/validators/joinEmail.js` | account-management → lib | nickname/password 검증 재사용 |
| `lib/auth.js` (`getAuthFromCookies`) | account-management → lib | 인증 가드 |
| `app/[locale]/_components/PhoneCertField.js` | account-management → 공유 | 휴대폰 OTP 재사용 |

---

## 6. 미확정 사항 (v1.0)

> 분류: **유형 A** = as-built 구현 완료 / **유형 B** = 감사 권고 미반영 / **유형 C** = 추가 구현 필요 / **유형 D** = 정책·디자인 확정 필요

| # | 우선순위 | 유형 | 항목 | 설명 | 근거 |
|---|---------|------|------|------|------|
| 1 | **[CRITICAL]** | C | 5개 페이지 UI 전체 미구현 | `/mypage/info`, `/nickname`, `/phone`, `/password`, `/withdraw` 모두 페이지 생성 필요 | as-built 미구현 |
| 2 | **[CRITICAL]** | B | change-nick 필드명 불일치 | MD: `newNick` / YAML: `acNick` — 백엔드 확정 후 클라이언트 body 구성 | 감사 권고안 3 |
| 3 | **[HIGH]** | C | 비번 변경 시 재인증 필수 | OWASP §4.04 — `change-passwd` body에 `acPasswordOld` 포함 + 백엔드 검증 | 감사 §3.1 #3 |
| 4 | **[HIGH]** | C | 탈퇴 시 재인증 필수 | 비번 또는 SMS OTP 재인증 후 `delete-user` 호출 | OWASP §4.04 |
| 5 | **[HIGH]** | C | 탈퇴 후 자동 로그아웃 | `setAuth(false, null)` + 백엔드 쿠키 만료 포워딩 검증 | as-built API route |
| 6 | **[HIGH]** | D | 7일 재가입 제한 백엔드 정책 | join 도메인과 공유 — 탈퇴 기록 DB 정책 | 비즈니스 |
| 7 | **[HIGH]** | D | 보유 코인 환불 정책 | 탈퇴 시 보유 코인 처리 — 환불 / 소멸 / 양도 | 비즈니스 |
| 8 | **[HIGH]** | D | 라우트 패턴 통일 | member-mymenu §8 #25 — `/my-menu` vs `/mypage` 결정 후 동일 적용 | member-mymenu 의존 |
| 9 | **[HIGH]** | C | returnUrl 전달 | 비로그인 진입 시 `/login?returnUrl=/mypage/info`로 리다이렉트, 로그인 후 복귀 | UX |
| 10 | **[MEDIUM]** | C | 닉네임 중복 확인 UX | check-nick 호출 후 결과 표시 — debounce vs 명시적 버튼 | UX |
| 11 | **[MEDIUM]** | C | 휴대폰 변경 후 SNS 자동로그인 분기 | OAuth 콜백의 `tryAutoLogin` `exist_flag=4` 분기에 영향 — 변경된 휴대폰으로 매핑 갱신 | as-built OAuth 의존 |
| 12 | **[MEDIUM]** | C | 비번 변경 후 세션 처리 | 변경 후 (a) 현재 세션 유지, (b) 모든 세션 강제 로그아웃 — 정책 결정 (member-mymenu §8 #24) | 보안 정책 |
| 13 | **[MEDIUM]** | D | SNS 가입자의 비번 변경 정책 | SNS 가입자(비번 미설정)는 `change-passwd` 비활성 또는 "비밀번호 설정" 신규 플로우 | 비즈니스 |
| 14 | **[MEDIUM]** | D | 탈퇴 사유 옵션 정의 | 화면설계서 S301 — 옵션 항목 + 수치 분석용 코드 매핑 | 비즈니스/디자인 |
| 15 | **[MEDIUM]** | D | 디자인 시안 발급 | Figma 시안 → design-normalizer SDD → publisher | 디자인 |
| 16 | **[LOW]** | C | 비밀번호 강도 표시 (zxcvbn 등) | 새 비밀번호 입력 시 강도 시각 피드백 | UX |
| 17 | **[LOW]** | C | 닉네임 변경 횟수 제한 | 월 N회 제한 등 정책 결정 시 클라이언트 카운터 표시 | 비즈니스 |
| 18 | **[LOW]** | C | 탈퇴 취소 (Cooling-off) | 탈퇴 후 N일 내 복구 가능 여부 — GDPR/PIPA 준수 | 법무 |

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | 신규 도메인 분리 작성 — member-mymenu §3-2 회원정보 영역에서 분리. as-built 백엔드 API 라우트(change-passwd/change-nick/update-phone/delete-user/update-home-set) 매핑. UI 페이지 5개(`/mypage/info`/`nickname`/`phone`/`password`/`withdraw`) 모두 미구현 표기. 감사 문서(`2026-04-16-auth-member-api-spec-review.md`) 권고 반영: change-nick 필드명 불일치(미확정 #2 CRITICAL B), 비번 변경 시 재인증 필수(#3 HIGH C). 미확정 사항 18건 도출 | 명우현 |
