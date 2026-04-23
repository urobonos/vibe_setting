# QA Scenario Sheet — 아이디/비밀번호 찾기

> Source: 화면설계서 PPTX Slides S48~S54 + as-built 코드 + 감사 문서(2026-04-16)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

## 1. 테스트 환경

- Viewport: 390x844 (모바일 우선)
- Hostnames: `en.hongcafe.com`, `jp.hongcafe.com` (hostname 기반 locale, URL prefix 없음)
- Base URL (dev): `http://localhost:3000`
- 사전 설정: `NEXT_PUBLIC_RECAPTCHA_SITE_KEY`, `NEXT_PUBLIC_API_URL`

## 2. 아이디 찾기 (`/find-account` — 기본 탭)

### 2-1. 렌더링 테스트

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| R01 | 페이지 기본 렌더링 | 비로그인 | `/find-account` 접속 | PageNavBar + 탭 메뉴 + 모바일 번호 섹션 + reCAPTCHA + 고객센터 안내 표시 | P0 |
| R02 | PageNavBar 표시 | 없음 | 페이지 확인 | 뒤로가기 + 타이틀(`Find your ID or Password`) + Home 버튼 표시 | P0 |
| R03 | 탭 메뉴 기본 상태 | 없음 | 탭 영역 확인 | `Find ID` 활성(디폴트), `Find Password` 비활성, `role="tablist"`/`role="tab"` 부여 | P0 |
| R04 | 국가 선택 버튼 | 없음 | 모바일 섹션 확인 | Globe 아이콘 + "Unites States +1" + Chevron 표시, 클릭 시 `showCountryPicker=true` | P0 |
| R05 | reCAPTCHA Enterprise 위젯 | `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` 설정됨 | reCAPTCHA 영역 확인 | Enterprise 위젯 정상 렌더 (action=`find_account`) | P0 |
| R06 | reCAPTCHA placeholder | env 미설정 | reCAPTCHA 영역 확인 | 점선 테두리 + "reCAPTCHA placeholder ..." 표시 (빌드 에러 없음) | P1 |
| R07 | 고객센터 안내 텍스트 | 없음 | 안내 텍스트 확인 | "If you cannot remember... 1644-8190" 표시 | P0 |
| R08 | 휴대폰 번호 입력 영역 | 없음 | 입력 영역 확인 | 번호 입력 필드 + "Verification" 버튼, 보라색 하단 테두리 | P0 |
| R09 | 인증번호 입력 영역 (숨김) | 발송 전 | 페이지 로드 직후 | OTP 입력 영역 미표시 (`isCodeSent=false` 조건부) | P0 |
| R10 | 인증번호 입력 영역 (표시) | 발송 완료 | "Verification" 클릭 후 | OTP 필드 + 타이머 `02:59` 표시 | P0 |
| R11 | 에러 메시지 비표시(기본) | 없음 | 페이지 로드 직후 | 에러 영역 공간 미예약 (조건부) | P1 |
| R12 | Confirm 버튼 비활성(기본) | OTP 미입력 | Confirm 버튼 확인 | `disabled` + 회색 `bg-[#dddddd]` | P0 |
| R13 | Confirm 버튼 활성 | OTP 입력 + 타이머>0 | OTP 입력 | 보라 `bg-[#6335b4]` + 활성화 | P0 |

### 2-2. i18n 테스트

| # | 시나리오 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| I01 | 영어(EN) 로케일 | `en.hongcafe.com/find-account` 접속 | 모든 텍스트 영어 (Find ID, Mobile Number 등) | P0 |
| I02 | 일본어(JP) 로케일 | `jp.hongcafe.com/find-account` 접속 | 모든 텍스트 일본어 | P0 |
| I03 | 탭 텍스트 | 두 로케일 | `findAccount.tabFindId`/`tabFindPassword` 번역 정확 | P0 |
| I04 | 에러 메시지 로케일 | 각 로케일에서 유효성 트리거 | `phoneError`/`verificationCodeError`/`verificationExpired`/`errorMemberNotFound` 번역 | P0 |
| I05 | 고객센터 안내 로케일 | 두 로케일 확인 | `customerServiceNotice` 번역 | P0 |

### 2-3. 인터랙션 테스트

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| A01 | 탭 전환 → Find Password | Find ID 활성 | 탭 클릭 | `activeTab='findPassword'` + 비밀번호 찾기 UI (현재 placeholder) | P0 |
| A02 | 탭 전환 → Find ID 복귀 | findPassword 활성 | Find ID 탭 클릭 | Find ID UI 복귀 | P0 |
| A03 | 국가 선택 버튼 클릭 | 없음 | 버튼 클릭 | `showCountryPicker=true` (모달 미구현이면 effect만 확인) | P1 |
| A04 | reCAPTCHA Enterprise 토큰 획득 | env 설정됨 | reCAPTCHA 체크 | `recaptchaToken` state 세팅 | P0 |
| A05 | 휴대폰 번호 입력 | 없음 | 번호 입력 | 입력값 필터링(`/[^0-9+\-\s]/g`) 후 반영 | P0 |
| A06 | Verification 클릭(정상) | 번호+토큰 완료 | 버튼 클릭 | `/api/members/find-id-cert` 호출 → `response='success'` → `isCodeSent=true` + 타이머 시작 | P0 |
| A07 | Verification 클릭(번호 미입력) | 토큰만 있음 | 버튼 클릭 | `setPhoneError(labels.phoneError)` 표시, API 미호출 | P0 |
| A08 | Verification 클릭(토큰 없음) | 번호만 있음 | 버튼 클릭 | `setPhoneError(labels.errorNetwork)` 표시, API 미호출 | P0 |
| A09 | Verification 클릭(API 실패) | 정상 입력 | 버튼 클릭 → 500 응답 | `data.msg`를 `escapeHtml` 후 phoneError에 표시, `resetRecaptcha()` 호출 | P0 |
| A10 | 타이머 카운트다운 | 발송 완료 | 타이머 관찰 | 180초 → 0초 1초 간격 감소 | P0 |
| A11 | 타이머 만료 | 180초 경과 | 자동 | `setCodeError(labels.verificationExpired)` + `timerSeconds=0` | P0 |
| A12 | OTP 입력 | 발송 후 | OTP 입력 | 6자리 숫자 제한, 비숫자 필터링 | P0 |
| A13 | Confirm 클릭(성공) | 올바른 OTP | 버튼 클릭 | `/api/members/confirm-id-cert` 호출 → `data.acId`/`data.acNick` 받아 `FindAccountResultModal` 오픈 | P0 |
| A14 | Confirm 클릭(OTP 불일치) | 틀린 OTP | 버튼 클릭 | `codeError=escapeHtml(msg)` 또는 `labels.errorMemberNotFound` | P0 |
| A15 | Modal 닫기 | Modal 표시됨 | onClose 트리거 | `modalOpen=false`, `modalEmail=''`, `modalChannel=''` | P0 |
| A16 | Modal backdrop 클릭 닫기 | Modal 열림 | 오버레이 클릭 | Modal 닫힘 (§22-40 Backdrop 상호작용) | P0 |
| A17 | PageNavBar Home 클릭 | 없음 | Home 클릭 | `/` (hostname 기반 locale의 메인) 이동 | P1 |
| A18 | PageNavBar 뒤로가기 | login에서 진입 | < 클릭 | login 페이지 복귀 | P1 |
| A19 | Verification 재클릭 방지 | 발송 중 | 빠른 클릭 | `isSending=true`이면 무시 (`if (isSending) return`) | P1 |
| A20 | Confirm 재클릭 방지 | 검증 중 | 빠른 클릭 | `isVerifying=true`이면 무시 | P1 |

### 2-4. 유효성검사 테스트

| # | 시나리오 | 입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-------|---------|---------|---------|
| V01 | 휴대폰 번호 미입력 | `phoneNumber=''` | Verification 클릭 | `phoneError=labels.phoneError` 표시 | P0 |
| V02 | OTP 미입력 | `verificationCode=''` | Confirm 클릭 | `codeError=labels.verificationCodeError` | P0 |
| V03 | 미등록 계정 | 미등록 번호 + 올바른 OTP | Confirm | `response!='success'` → `errorMemberNotFound` Alert | P0 |
| V04 | OTP 불일치 | 틀린 OTP | Confirm | `errorVerificationMismatch` 또는 백엔드 msg 표시 | P0 |
| V05 | reCAPTCHA 미체크 | 토큰 없음 | Verification | 버튼 disabled (sendDisabled 조건) | P0 |
| V06 | 에러 복원 | 에러 표시 상태 | 올바른 값 재입력 | `phoneError=''` 자동 클리어(onChange 로직) | P1 |

### 2-5. 엣지 케이스 테스트

| # | 시나리오 | 조건 | 기대 결과 | 우선순위 |
|---|---------|-----|---------|---------|
| E01 | 타이머 만료 후 Verification 재클릭 | `timerSeconds=0` | 새 OTP 발송 + 타이머 180초 리셋 | P0 |
| E02 | reCAPTCHA 토큰 만료 | 장시간 대기 | `onExpired` → `recaptchaToken=''` + Verification 비활성 | P1 |
| E03 | 페이지 unmount 중 타이머 동작 | 언마운트 | `timerRef.current` cleanup (setInterval 해제) | P1 |
| E04 | 네트워크 에러(Verification) | fetch 실패 | catch → `phoneError=labels.errorNetwork` + `resetRecaptcha()` | P1 |
| E05 | 네트워크 에러(Confirm) | fetch 실패 | catch → `codeError=labels.errorNetwork` | P1 |
| E06 | 긴 전화번호 입력 | 20자리 이상 | 필드 크기 유지, 스크롤 없음 | P2 |
| E07 | 비숫자 입력 필터링 | 문자/특수문자 | 숫자+`+`+`-`+공백만 통과 | P2 |
| E08 | 탭 전환 후 상태 유지 | 번호 입력 후 탭 전환 | 입력값 유지 여부 (기획 미확정 — `activeTab` 변경만, state 초기화 X) | P2 |

### 2-6. Rate Limiting 및 보안 테스트 (신규)

| # | 시나리오 | 조건 | 기대 결과 | 우선순위 |
|---|---------|-----|---------|---------|
| RL01 | 짧은 시간 Verification 반복 | 60초 내 4번 이상 발송 | backend 429 응답 → `phoneError` 에 "Too many attempts" 표시 | P0 |
| RL02 | 403 FORBIDDEN (시도 횟수 초과) | 짧은 시간 OTP 검증 반복 실패 | backend 403 → `codeError` 에 시도 횟수 초과 안내 | P0 |
| SEC01 | XSS 방어 — data.msg | 백엔드가 `<script>alert(1)</script>` 반환 | `escapeHtml` 적용 후 표시, 스크립트 미실행 | P0 |
| SEC02 | XSS 방어 — acId/acNick | 비정상 값 반환 | `FindAccountResultModal`에 `escapeHtml` 적용 | P0 |
| SEC03 | reCAPTCHA 서버 검증 누락 [CRITICAL] | captchaToken body 미전송 | **현재 미반영 — 요구사항**: secureFetch body에 `captchaToken` 포함 + 백엔드 createAssessment 호출 | P0 (미반영) |

## 3. 비밀번호 찾기 (`/find-account` — Find Password 탭, 해외=이메일 OTP)

> ⚠️ 현재 구현 상태: UI 탭 분기만 있고 본 플로우 미구현 (`findPasswordTodo` placeholder). 아래 시나리오는 구현 완료 후 검증용.

### 3-1. 렌더링 테스트

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| PR01 | 비밀번호 찾기 탭 진입 | 없음 | Find Password 탭 클릭 | 이메일 입력 + 모바일 섹션 + reCAPTCHA + OTP 영역 표시 | P0 |
| PR02 | 이메일 입력 필드 | 탭 활성 | 이메일 영역 | `type="text" inputMode="email" autoComplete="email"` (§22-24) | P0 |
| PR03 | OTP 입력 영역(숨김) | 미발송 | 로드 직후 | OTP 입력 필드 미표시 | P0 |
| PR04 | OTP 입력 영역(표시) | find-password-cert 204 응답 후 | 발송 완료 | "Check your email" 안내 + OTP 필드 + 타이머 표시 | P0 |
| PR05 | 비밀번호 설정 영역(숨김) | OTP 검증 전 | 화면 확인 | 새 비밀번호 필드 미표시 | P0 |
| PR06 | 비밀번호 설정 영역(표시) | OTP 검증 완료(`isPasswordStep=true`) | 화면 확인 | 새 비밀번호 + 확인 + Confirm 버튼 표시 | P0 |

### 3-2. 인터랙션 테스트

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| PA01 | 이메일 입력 | 탭 활성 | 이메일 입력 | `email` state 반영 | P0 |
| PA02 | Send Email OTP | 이메일+번호+국가+토큰 | Send 클릭 | `POST /api/members/find-password-cert` `{acCountry, crPhone, acId, captchaToken}` → 204 → `otpSent=true` + 타이머 시작 | P0 |
| PA03 | OTP 검증 | 발송 후 OTP 입력 | Verify 클릭 | OTP 검증 엔드포인트 호출 성공 → `isPasswordStep=true` | P0 |
| PA04 | 새 비밀번호 입력 | 검증 후 | password 입력 | 입력값 마스킹 표시 | P0 |
| PA05 | Confirm Password 입력 | 검증 후 | 확인 입력 | 마스킹 표시 + 일치 검증 | P0 |
| PA06 | 비밀번호 변경 제출(성공) | 유효 비밀번호 + 일치 | Confirm 클릭 | `POST /api/members/change-passwd` `{acId, acCertNum, newPassword, newPasswordRe}` → 200 → Alert "Password changed" → `/login` 이동 | P0 |

### 3-3. 유효성검사 테스트 — OTP 단계

| # | 시나리오 | 입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-------|---------|---------|---------|
| PV01 | 이메일 미입력 | `email=''` | Send 클릭 | "Please enter your email" 에러 | P0 |
| PV02 | 이메일 형식 오류 | `email='invalid'` | Send 클릭 | "Please enter a valid email" | P0 |
| PV03 | 휴대폰 미입력 | `phone=''` | Send 클릭 | `phoneError` 표시 | P0 |
| PV04 | 미등록 계정 | 이메일+번호 불일치 | Send 클릭 | backend 404 → Alert "No matching account found" | P0 |
| PV05 | OTP 미입력 | `otp=''` | Verify 클릭 | OTP 에러 | P0 |
| PV06 | OTP 불일치 | 틀린 OTP | Verify 클릭 | "Code does not match" | P0 |
| PV07 | OTP 만료 | 타이머 0 | Verify 클릭 | "Expired, please resend" | P0 |
| PV08 | Rate limit(403) | 과도한 재시도 | Send 클릭 | "Too many attempts" | P0 |
| PV09 | Send 실패(500) | backend 500 | Send 클릭 | "Failed to send. Retry" | P0 |

### 3-4. 유효성검사 테스트 — 비밀번호 설정 단계

| # | 시나리오 | 입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-------|---------|---------|---------|
| PW01 | 새 비밀번호 미입력 | `newPassword=''` | Confirm | "Please enter password" | P0 |
| PW02 | 조합 미충족 | `aaaaaa` (영문만) | Confirm | "Password must contain 2+ of letters/numbers/special 6~16" | P0 |
| PW03 | 길이 미충족(<6) | `ab1` | Confirm | "Password must be 6~16 chars" | P0 |
| PW04 | 길이 초과(>16) | 17자 | Confirm | 동일 | P0 |
| PW05 | 확인 미입력 | `confirmPassword=''` | Confirm | "Please confirm password" | P0 |
| PW06 | 불일치 | `abc123` / `abc456` | Confirm | "Passwords do not match" | P0 |
| PW07 | 영문+숫자 유효 | `abc123` | Confirm | 성공 | P0 |
| PW08 | 영문+특수 | `abc!!!` | Confirm | 성공 | P1 |
| PW09 | 숫자+특수 | `123!!!` | Confirm | 성공 | P1 |
| PW10 | 3종 조합 | `abc12!` | Confirm | 성공 | P1 |
| PW11 | 경계값 정확히 6자 | `ab12!!` | Confirm | 성공 | P1 |
| PW12 | 경계값 정확히 16자 | 16자 | Confirm | 성공 | P1 |

### 3-5. 엣지 케이스 테스트

| # | 시나리오 | 조건 | 기대 결과 | 우선순위 |
|---|---------|-----|---------|---------|
| PE01 | OTP 검증 후 탭 전환 | `isPasswordStep=true` + Find ID 탭 복귀 | 상태 유지 여부 (기획 미확정) | P1 |
| PE02 | 비밀번호 변경 API 실패 | 네트워크 에러 | Alert "Network error" | P1 |
| PE03 | Confirm 더블 클릭 방지 | 없음 | 버튼 disabled 처리 | P1 |
| PE04 | 특수문자만 입력 | `!@#$%^` | 조합 미충족 에러 | P1 |
| PE05 | 한글 비밀번호 | `가나다라마바` | 조합 미충족 또는 필터링 (기획 확인) | P2 |
| PE06 | 공백 포함 | `abc 12!` | 허용 여부 (기획 미확정) | P2 |
| PE07 | 이메일 도착 지연 | 30초 이상 미수신 | 사용자에게 확인 문구 (Junk 폴더 안내) | P1 |
| PE08 | 계정 존재 여부 노출 방지 (CWE-204) | 미등록 vs 등록 | 동일 응답 시간/메시지로 정규화 | P1 |

## 4. 국가별 분기 테스트 (신규)

| # | 시나리오 | 조건 | 기대 결과 | 우선순위 |
|---|---------|-----|---------|---------|
| CB01 | EN hostname 비번찾기 | `en.hongcafe.com` + find-password-cert 호출 | 이메일 OTP 발송 | P0 |
| CB02 | JP hostname 비번찾기 | `jp.hongcafe.com` 동일 | 이메일 OTP 발송 (JP locale) | P0 |
| CB03 | acCountry=EN 전송 확인 | body 캡처 | `acCountry: 'EN'` 전송 | P0 |
| CB04 | acCountry=JP 전송 확인 | body 캡처 | `acCountry: 'JP'` 전송 | P0 |

## 5. 접근성 테스트

| # | 시나리오 | 검증 항목 | 기대 결과 |
|---|---------|---------|---------|
| AC01 | 탭 메뉴 ARIA | `role="tablist"`, `role="tab"`, `aria-selected` | 적절한 역할 부여 |
| AC02 | 폼 필드 레이블 연결 | `htmlFor`/`id` 또는 `aria-label` | 스크린 리더가 레이블 읽음 |
| AC03 | 에러 메시지 연결 | `aria-invalid`, `aria-describedby` | 에러 메시지 연결됨 |
| AC04 | 키보드 탐색 | Tab 순서 | 탭 → 국가선택 → reCAPTCHA → 번호 → Verification 순서 |
| AC05 | 타이머 접근성 | `aria-live="polite"` 또는 `role="timer"` | 변경 시 전달 |
| AC06 | Modal 접근성 | `role="dialog"`/`alertdialog`, `aria-modal` | 포커스 트랩 + 닫기 후 복귀 (§22-40) |
| AC07 | 버튼 비활성화 | `disabled` + `aria-disabled` | 상태 반영 |

## 6. 크로스 페이지 플로우 테스트

| # | 플로우명 | 관련 페이지 | 실행 단계 | 기대 결과 |
|---|---------|-----------|---------|---------|
| F01 | login → find-account | login, find-account | login에서 "I forgot my ID/Password" 클릭 | `/find-account` Find ID 활성 |
| F02 | 뒤로가기 | find-account, login | PageNavBar < 클릭 | login 복귀 |
| F03 | Home 이동 | find-account, main | Home 클릭 | `/` 메인 이동 |
| F04 | 비밀번호 변경 완료 | find-account, login | 성공 Alert 확인 | `/login` 자동 이동 |
| F05 | 아이디 찾기 결과 → login | find-account, login | Modal 확인 후 뒤로가기 | login에서 찾은 이메일로 로그인 가능 |

## 7. 테스트 시나리오 요약

| 카테고리 | 시나리오 수 | P0 | P1 | P2 |
|---------|-----------|----|----|-----|
| 렌더링(아이디 찾기) | 13 | 12 | 1 | 0 |
| i18n | 5 | 5 | 0 | 0 |
| 인터랙션(아이디 찾기) | 20 | 16 | 4 | 0 |
| 유효성검사(아이디 찾기) | 6 | 5 | 1 | 0 |
| 엣지 케이스(아이디 찾기) | 8 | 1 | 4 | 3 |
| Rate Limit/보안 | 5 | 5 | 0 | 0 |
| 렌더링(비번찾기) | 6 | 6 | 0 | 0 |
| 인터랙션(비번찾기) | 6 | 6 | 0 | 0 |
| 유효성(OTP 단계) | 9 | 9 | 0 | 0 |
| 유효성(비번 단계) | 12 | 7 | 5 | 0 |
| 엣지(비번찾기) | 8 | 0 | 6 | 2 |
| 국가 분기 | 4 | 4 | 0 | 0 |
| 접근성 | 7 | 7 | 0 | 0 |
| 크로스 페이지 | 5 | 5 | 0 | 0 |
| **합계** | **114** | **88** | **21** | **5** |

## 8. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 최초 작성 (92 시나리오) | 명우현 |
| v1.1 | 2026-04-17 | **유형 A**: 실제 API/필드/컴포넌트 반영. **유형 B**: captchaToken 서버 검증 누락 케이스 추가. **유형 C**: 비번찾기를 해외=이메일 OTP로 전면 재설계, Rate Limit 및 국가 분기 섹션 신설. 시나리오 92 → 114. | 명우현 |
