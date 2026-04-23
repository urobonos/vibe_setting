# QA Scenario Sheet — Account Management

> Source: ffs.md v1.0 + 화면설계서 S296~S304 + as-built API 라우트 + 감사 문서(`2026-04-16-auth-member-api-spec-review.md`)
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

> ⚠️ **현재 UI 미구현 상태** — 본 시나리오는 향후 구현 시 검증 항목 정의용. 백엔드 API 라우트 동작은 즉시 검증 가능.

---

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390×844 (모바일) |
| 로케일/호스트 | EN: `en.hongcafe.com/mypage/info` / JP: `jp.hongcafe.com/mypage/info` |
| 테스트 도구 | Playwright (UI 구현 후) + Vitest (`__tests__/lib/*.test.js`) |
| 보안 검증 | CSRF Signed Double Submit + brute-force rate limit (5/60s for change-passwd, 3/60s for delete-user) |
| 인증 | 모든 라우트 JWT 필수 (`hc_access` 쿠키) |

---

## 2. AccountInfoMenu (`/mypage/info`) — 미구현

### 2-1. 렌더링 (제안)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| AM-R-01 | 인증 사용자 진입 | 로그인 | `/mypage/info` 접근 | HTTP 200, AccountInfoMenu 렌더 | P0 |
| AM-R-02 | 비인증 진입 | 비로그인 | `/mypage/info` 접근 | `getAuthFromCookies` 미인증 → `/login` 리다이렉트 (returnUrl 미전달 — Phase A-4 #27) | P0 |
| AM-R-03 | 사용자 요약 | 인증 | 영역 확인 | 닉네임 + 이메일 + 가입 방법(Email/Google/Apple/Line/Facebook 표시) | P0 |
| AM-R-04 | 메뉴 리스트 5항목 | 인증 | 메뉴 확인 | Nickname / Phone / Password / Notification Settings / Withdrawal | P0 |
| AM-R-05 | 각 항목 chevron | 인증 | 메뉴 행 확인 | chevron_right + (해당 시) 현재 값 표시 | P1 |

### 2-2. 인터랙션

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| AM-A-01 | Nickname 메뉴 클릭 | 인증 | 메뉴 클릭 | `/mypage/info/nickname` 이동 | P0 |
| AM-A-02 | Phone 메뉴 클릭 | 인증 | 메뉴 클릭 | `/mypage/info/phone` | P0 |
| AM-A-03 | Password 메뉴 클릭 | 인증 | 메뉴 클릭 | `/mypage/info/password` | P0 |
| AM-A-04 | Notification Settings 메뉴 | 인증 | 메뉴 클릭 | `/mypage/info/notification-settings` (Phase B-4) | P0 |
| AM-A-05 | Withdrawal 메뉴 | 인증 | 메뉴 클릭 | `/mypage/info/withdraw` | P0 |

---

## 3. NicknameChangeForm (`/mypage/info/nickname`) — 미구현

### 3-1. 렌더링 / 인터랙션

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| NC-R-01 | 페이지 진입 | 인증 | `/mypage/info/nickname` | 현재 닉네임 표시 + 새 닉네임 입력 + 중복 확인/변경 버튼 | P0 |
| NC-A-01 | 새 닉네임 입력 | 없음 | input | controlled 갱신 + `validateNickname` 형식 검증 | P0 |
| NC-A-02 | 중복 확인 | 닉네임 입력 후 | 중복 확인 클릭 | `secureFetch('/api/members/check-nick', POST, {acNick})` → success 시 `nickAvailable=true`, 409 시 `nickAvailable=false` | P0 |
| NC-A-03 | 변경 제출 | nickAvailable=true | 변경 클릭 | `secureFetch('/api/members/change-nick', POST, {newNick \| acNick})` — **필드명 미확정 (감사 권고안 3 — 유형 B CRITICAL)** | P0 |
| NC-A-04 | 변경 성공 | API success | 응답 후 | 토스트/모달 노출 + mypage 또는 info로 복귀 + zustand 사용자 store 갱신 | P0 |
| NC-A-05 | 형식 오류 | 한글/영문/숫자 외 | 변경 클릭 | `validateNickname` 실패 → 에러 표시 + return early | P0 |
| NC-A-06 | 길이 초과 | 13자 이상 | 변경 클릭 | 에러 표시 (2~12자 제한) | P0 |

---

## 4. PhoneChangeForm (`/mypage/info/phone`) — 미구현

### 4-1. 렌더링 / 인터랙션

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| PC-R-01 | 페이지 진입 | 인증 | `/mypage/info/phone` | 현재 휴대폰 표시 + PhoneCertField + 변경 버튼 | P0 |
| PC-A-01 | OTP 발송 | 새 휴대폰 입력 후 | 인증받기 클릭 | `secureFetch('/api/members/send-global-cert', POST, {acCountry, acPhoneNo})` (PhoneCertField 재사용) | P0 |
| PC-A-02 | OTP 검증 | OTP 입력 후 | 확인 클릭 | `secureFetch('/api/members/confirm-global-cert', POST)` → `isPhoneVerified=true` | P0 |
| PC-A-03 | 휴대폰 변경 제출 | OTP 검증 완료 | 변경 클릭 | `secureFetch('/api/members/update-phone', POST, {acCountry, acPhoneNo, acCertNum})` — 필드명 백엔드 확인 필요 | P0 |
| PC-A-04 | 변경 성공 | API success | 응답 후 | 토스트 + info 복귀 + (가능 시) OAuth 자동로그인 매핑 갱신 | P0 |
| PC-A-05 | OTP 미검증 상태 제출 | isPhoneVerified=false | 변경 클릭 | 에러 메시지 + return early | P0 |

---

## 5. PasswordChangeForm (`/mypage/info/password`) — 미구현

### 5-1. 렌더링 / 인터랙션

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| PW-R-01 | 페이지 진입 | 인증 | `/mypage/info/password` | 3개 입력 필드 (현재/새/확인) + 변경 버튼 | P0 |
| PW-A-01 | 현재 비번 입력 | 없음 | input | controlled (OWASP §4.04 — 재인증 필수) | P0 |
| PW-A-02 | 새 비번 입력 | 없음 | input | `validatePassword` 형식 검증 (6~16자 + 영문+숫자+특수문자) | P0 |
| PW-A-03 | 새 비번 확인 | 새 비번 입력 후 | input | 일치 검증 | P0 |
| PW-A-04 | 변경 제출 | 모든 필드 통과 | 변경 클릭 | `secureFetch('/api/members/change-passwd', POST, {acPasswordOld, acPasswordNew, acPasswordReNew})` (JWT + rate 5/60s) | P0 |
| PW-A-05 | 기존 비번 불일치 | mock 401 응답 | 응답 후 | 에러 메시지 노출 (재인증 실패) | P0 |
| PW-A-06 | 변경 성공 후 세션 처리 | API success | 응답 후 | (a) 현재 세션 유지 / (b) 강제 로그아웃 — **정책 미확정 (member-mymenu §8 #24)** | P0 |
| PW-A-07 | SNS 가입자 차단 | SNS 가입 사용자 | 페이지 진입 | (정책 #13) — 비활성화 또는 "비밀번호 설정" 플로우 진입 | P1 |
| PW-A-08 | brute-force 차단 | 5회 실패 후 6번째 | 변경 클릭 | 429 응답 → 에러 메시지 (`Too many attempts. Try again in N seconds.`) | P0 |

---

## 6. WithdrawFlow (`/mypage/info/withdraw`) — 미구현

### 6-1. 단계별 시나리오

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| WD-R-01 | 단계 1: 탈퇴 안내 | 인증 진입 | `/mypage/info/withdraw` | 보유 코인 삭제 / 데이터 복구 불가 / 7일 재가입 제한 안내 + "다음" 버튼 | P0 |
| WD-A-01 | 단계 2: 사유 선택 | 단계 1 통과 | 라디오 선택 + 기타 입력 | 사유 코드 매핑 (`withdrawReason` 필드) | P0 |
| WD-A-02 | 단계 3: 재인증 (이메일 가입자) | 사유 선택 후 | 비밀번호 입력 + 확인 | OWASP §4.04 — `acPassword` 검증 | P0 |
| WD-A-03 | 단계 3: 재인증 (SNS 가입자) | 사유 선택 후 | SMS OTP 발송/검증 (PhoneCertField) | 비밀번호 미설정 사용자 위한 대체 인증 | P0 |
| WD-A-04 | 단계 4: 최종 확인 모달 | 재인증 통과 | 모달 노출 | "정말 탈퇴하시겠습니까?" + 취소/확인 버튼 | P0 |
| WD-A-05 | 단계 5: 탈퇴 처리 | 모달 확인 클릭 | DELETE 호출 | `secureFetch('/api/members/delete-user', DELETE, {acPassword? \| acCertNum?, withdrawReason})` (JWT + rate 3/60s) | P0 |
| WD-A-06 | 탈퇴 성공 | API success | 응답 후 | 백엔드 Set-Cookie로 hc_access/hc_refresh 즉시 만료 → 프론트 `setAuth(false, null)` → `/intro` 또는 `/` 이동 | P0 |
| WD-A-07 | 탈퇴 후 재진입 차단 | 탈퇴 직후 즉시 새 가입 시도 | 동일 이메일/SNS ID로 가입 | 백엔드가 7일 제한 응답 → 재가입 불가 안내 (join 도메인 §S43~S47) | P0 |
| WD-A-08 | 탈퇴 취소 (모달에서) | 단계 4 모달 노출 | 취소 클릭 | 모달 닫힘 + WithdrawFlow 단계 1로 복귀 | P1 |
| WD-A-09 | 재인증 실패 | mock 401 | 단계 3 제출 | 에러 메시지 + 단계 3에 머무름 | P0 |
| WD-A-10 | brute-force 차단 (delete-user) | 3회 실패 후 4번째 | 탈퇴 시도 | 429 응답 → 에러 메시지 | P0 |

---

## 7. 보안 검증 시나리오

### 7-1. CSRF + JWT

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AM-SEC-01 | change-passwd CSRF 첨부 | 비번 변경 시도 | network 캡처 | `secureFetch`가 `x-csrf-token` 헤더 자동 첨부 | P0 |
| AM-SEC-02 | change-passwd JWT 필수 | hc_access 만료 | 비번 변경 시도 | 백엔드 401 → 프론트 `/login` 리다이렉트 | P0 |
| AM-SEC-03 | delete-user CSRF 첨부 | 탈퇴 시도 | network 캡처 | `x-csrf-token` 자동 첨부 | P0 |
| AM-SEC-04 | delete-user JWT 필수 | hc_access 만료 | 탈퇴 시도 | 401 → `/login` 리다이렉트 | P0 |

### 7-2. OWASP §4.04 재인증

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AM-SEC-05 | 비번 변경 시 재인증 | 새 비번만 입력 + 기존 비번 누락 | 변경 클릭 | 클라이언트 검증 → `acPasswordOld` 누락 에러 + return early | P0 |
| AM-SEC-06 | 탈퇴 시 재인증 | 재인증 우회 시도 | DELETE 직접 호출 | 백엔드 검증 실패 → 401/403 응답 | P0 |
| AM-SEC-07 | 미인증 세션으로 unattended 보호 | 잠시 자리 비운 사이 공격자 | 비번 변경 시도 | OWASP §4.04 — 기존 비번 재인증 불가 → 차단 | P0 |

### 7-3. brute-force / rate limit

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AM-SEC-08 | change-passwd 5/60s | 5회 시도 후 6번째 | 변경 클릭 | 429 응답 + Retry-After 헤더 | P0 |
| AM-SEC-09 | delete-user 3/60s | 3회 시도 후 4번째 | 탈퇴 시도 | 429 응답 | P0 |
| AM-SEC-10 | check-nick rate limit | 다수 호출 | 빠른 연속 호출 | 백엔드 rate limit 적용 (구체적 정책 확인 필요) | P1 |

### 7-4. XSS + apiHandler 200 래핑

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AM-SEC-11 | XSS via 사용자 입력 | nickname=`<svg onload=...>` | 미리보기 또는 다른 페이지 표시 | `escapeHtml` 또는 React 자동 escape — 미실행 | P0 |
| AM-SEC-12 | apiHandler 200+`response='fail'` | mock 응답 | 변경 클릭 | `data.response==='success'` 체크로 fail 분기 진입 | P0 |
| AM-SEC-13 | data.msg XSS | mock `data.msg=<script>` | 에러 표시 | `escapeHtml(data.msg)` 적용 — 텍스트로만 노출 | P0 |

---

## 8. 단위 테스트 게이트 (Vitest)

| # | 시나리오 | 대상 파일 | 검증 |
|---|---------|----------|------|
| UT-AM-01 | `validatePassword` 6~16자 + 조합 | `lib/validators/joinEmail.js` | 재사용 |
| UT-AM-02 | `validateNickname` 형식/길이 | `lib/validators/joinEmail.js` | 재사용 |
| UT-AM-03 | `validatePasswordMatch` (신설 권고) | (신설) `lib/validators/passwordChange.js` | new !== old, new === confirm |
| UT-AM-04 | (신설) `withdrawReasonCodes` | (신설) `lib/withdrawReasons.js` | 사유 코드 매핑 |

---

## 9. 크로스 페이지 플로우 (E2E)

| # | 플로우명 | 관련 페이지 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-----------|---------|---------|---------|
| AM-CF-01 | mypage → info → nickname → 변경 | mypage / info / nickname | mypage 메뉴 클릭 → info → nickname → 입력 → 변경 → mypage 복귀 | 닉네임 변경 + zustand 갱신 + 화면 반영 | P0 |
| AM-CF-02 | mypage → info → phone → OTP 변경 | mypage / info / phone | OTP 발송 → 검증 → 변경 → 복귀 | 휴대폰 변경 + (가능 시) OAuth 자동로그인 매핑 갱신 | P0 |
| AM-CF-03 | mypage → info → password → 재인증 변경 | mypage / info / password | 기존+새+확인 입력 → 변경 → (정책에 따라) 강제 로그아웃 또는 머무름 | 정책 #12에 따른 처리 | P0 |
| AM-CF-04 | mypage → info → withdraw → 탈퇴 → intro | mypage / info / withdraw / intro | 탈퇴 안내 → 사유 → 재인증 → 확인 → DELETE → 쿠키 만료 → /intro | 자동 로그아웃 + 7일 재가입 제한 활성화 | P0 |
| AM-CF-05 | 탈퇴 후 즉시 재가입 시도 | withdraw → join | 탈퇴 후 동일 이메일로 join | 재가입 불가 안내 (join §S43~S47) | P0 |

---

## 10. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | 신규 도메인 시나리오 작성 — 5개 페이지(`/mypage/info`, `/nickname`, `/phone`, `/password`, `/withdraw`) 모두 미구현 상태 + 백엔드 API 라우트만 존재. 렌더링/인터랙션/보안(CSRF/JWT/OWASP §4.04 재인증/brute-force 5-3/60s/XSS/apiHandler 200래핑)/단위 테스트/E2E 크로스 플로우 시나리오. 감사 문서 권고(change-nick 필드명 불일치, 비번 변경 재인증, 탈퇴 재인증) 반영. 7일 재가입 제한 join 도메인 의존성 명시 | 명우현 |
