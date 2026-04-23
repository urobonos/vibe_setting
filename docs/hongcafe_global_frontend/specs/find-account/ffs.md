# Frontend Functional Spec — 아이디/비밀번호 찾기

> Source: 화면설계서 PPTX Slides S48~S54 + as-built 코드 + 감사 문서(2026-04-16)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: 통합 프로젝트 EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

> **참조 버전**: backend `member-api.yaml` v2026-04-16 (변경 예정). 최종 확정 후 별도 정합성 맞춤 패스 진행.

## 1. 개요

- **도메인 목적**: 사용자가 로그인 자격 정보를 분실했을 때 복구 경로 제공
  - **아이디 찾기**: 가입 시 사용한 휴대전화번호(+국가) 인증 → 마스킹된 이메일 + 가입 채널 반환
  - **비밀번호 찾기**: 이메일 + 휴대전화번호 검증 → **해외(EN/JP)는 이메일 OTP** 발송 → OTP 입력 → 새 비밀번호 설정
- **사용자 목표**: 분실한 아이디(이메일) 확인 또는 비밀번호 재설정으로 로그인 가능 상태 복귀
- **구현 상태**:
  - 아이디 찾기: ✅ 구현 완료 (`app/[locale]/find-account/_components/FindAccountForm.js`)
  - 비밀번호 찾기: ⚠️ UI 탭 분기만 구현, 본 플로우(이메일 OTP) 미구현 — Backend `find-password-cert` + `change-passwd` 연동 예정

## 2. 라우트 구조

| 라우트 | page.js 위치 | 동적 파라미터 | 인증 필요 | 슬라이드 |
|--------|-------------|-------------|---------|---------|
| `/find-account` | `app/[locale]/find-account/page.js` | — (hostname 기반 locale) | 아니오 | S48~S54 |

> hostname 기반 i18n — URL에 locale prefix 없음 (`jp.hongcafe.com/find-account`, `en.hongcafe.com/find-account`).

## 3. 페이지 정의

### 3-1. 아이디 찾기 (슬라이드 S49~S51, 구현 완료)

- **라우트**: `/find-account` (기본 탭: 아이디 찾기)
- **Server/Client 분리**: `page.js`(Server) → `FindAccountForm.js`(Client, `'use client'`)
- **UI 섹션** (상→하 순서):
  1. **PageNavBar**: 보라색 상단바 (뒤로가기 + 타이틀 + Home 버튼) — 공용 `PageNavBar` 컴포넌트
  2. **탭 메뉴**: `아이디 찾기 | 비밀번호 찾기` (`role="tablist"` + `role="tab"` + `aria-selected`)
  3. **모바일 번호 섹션** (label + 국가 선택 버튼)
     - 국가 선택 버튼: Globe 아이콘 + `labels.countryDefault` ("Unites States +1") + Chevron 아이콘
     - 현재 구현: 버튼 클릭 시 `showCountryPicker` true로 전환 (국가 모달 UI는 §8 미확정 — 1차 기본값 +1 고정)
  4. **reCAPTCHA Enterprise 위젯** (`components/ReCaptchaEnterprise.js`, action=`find_account`) — `RECAPTCHA_ENTERPRISE_SITE_KEY` 미설정 시 placeholder 렌더
  5. **휴대폰 번호 입력 + 인증받기 버튼** (인라인, 보라색 하단 테두리)
     - `onChange`는 `/[^0-9+\-\s]/g` 필터링
     - `disabled={isCodeSent}` — 발송 후 잠금
     - 버튼 활성 조건: `phoneNumber && recaptchaToken && !isSending && !isCodeSent`
  6. **인증번호 입력 + 타이머** (발송 후에만 표시, 조건부 렌더링)
     - 6자리 숫자 제한, `autoComplete="one-time-code"`, `inputMode="numeric"`
     - 타이머: `VERIFICATION_TIMEOUT_SECONDS = 180` (3분) → `MM:SS` 포맷
  7. **확인 버튼** (`confirmEnabled = isCodeSent && timerSeconds>0 && !!verificationCode && !isVerifying`)
  8. **고객센터 안내 텍스트** (`labels.customerServiceNotice`)
- **상태 관리** (as-built):
  - 로컬: `activeTab`/`phoneNumber`/`verificationCode`/`phoneError`/`codeError`/`isCodeSent`/`isSending`/`isVerifying`/`timerSeconds`/`recaptchaToken`/`modalOpen`/`modalEmail`/`modalChannel`/`showCountryPicker`
  - Refs: `timerRef`(setInterval), `recaptchaRef`(리셋 제어)
  - Zustand 스토어: 사용하지 않음
- **API 연동** (as-built):

  | 엔드포인트 | Method | Request Body | Response (성공) | 비고 |
  |-----------|--------|-------------|-----------------|------|
  | `POST /api/members/find-id-cert` | POST | `{ crPhone, acCountry }` | `{ response: "success", ... }` | secureFetch 사용 (CSRF 자동) |
  | `POST /api/members/confirm-id-cert` | POST | `{ crPhone, acCountry, acCertNum }` | `{ response: "success", data: { acId, acNick } }` | 마스킹된 이메일(`acId`) + 가입채널(`acNick`) |

  **⚠️ 감사 권고 미반영 (유형 B)**: reCAPTCHA 서버 사이드 검증을 위해 **`captchaToken`을 body에 포함**해야 함 (audit: `2026-04-16-recaptcha-signup-flow-us-jp-requirement.md`). 현재 코드는 프론트 검증만 수행.

- **사용자 인터랙션**:
  - 탭 전환(아이디 찾기 ↔ 비밀번호 찾기)
  - 국가 선택(§8 미확정 — 1차 구현은 기본값 +1 고정, 모달 열기만 지원)
  - reCAPTCHA Enterprise 체크(토큰 `recaptchaToken` 자동 세팅)
  - 휴대폰 번호 입력 → "Verification" 클릭 → API 호출 → 인증번호 입력 영역 + 타이머 시작
  - 인증번호 입력 → "Confirm" 클릭 → API 호출 → `FindAccountResultModal`로 결과 표시
- **비즈니스 규칙**:
  - 유효성 검사:
    - 휴대폰 번호 미입력 → `labels.phoneError` ("Please enter your mobile number")
    - reCAPTCHA 토큰 없음 → `labels.errorNetwork`
    - 인증번호 미입력 → `labels.verificationCodeError` ("Please enter the verification code")
    - 타이머 만료(0초) → `labels.verificationExpired`
  - API 응답 처리:
    - 성공 → `FindAccountResultModal` 열기(이메일 + 채널 `escapeHtml`로 XSS 방어, **필수**)
    - 실패 메시지 → `data.msg`를 `escapeHtml` 통과 후 에러 표시
  - 타이머: 180초 카운트다운, 만료 시 인증 불가 → 재발송 필요
- **엣지 케이스**:
  - 더블 클릭 방지: `isSending` / `isVerifying` 플래그로 API 호출 중 버튼 잠금
  - reCAPTCHA 토큰 만료: 실패 시 `resetRecaptcha()` 호출 + 재인증 유도
  - 페이지 unmount: `timerRef` cleanup (메모리 릭 방지)

### 3-2. 비밀번호 찾기 (슬라이드 S52~S54, 미구현 — 이메일 OTP 분기)

- **라우트**: `/find-account` (비밀번호 찾기 탭 선택)
- **Server/Client 분리**: 3-1과 동일 컴포넌트 내 탭 분기(현재 `findPasswordTodo` placeholder 상태)
- **인증 채널 — 국가별 분기 (backend `find-password-cert` description 기반)**:
  | 국가 | 채널 | 근거 |
  |------|------|------|
  | EN (en.hongcafe.com) | **이메일 OTP** | member-api.yaml L464: "KR=알림톡, 해외=이메일" |
  | JP (jp.hongcafe.com) | **이메일 OTP** | 동일 |
  | KR | 알림톡 (본 프로젝트 범위 밖) | 기존 홍카페K 별도 운영 |
- **UI 섹션** (EN/JP 대상):
  1. **PageNavBar + 탭 메뉴**: 아이디 찾기와 동일, 비밀번호 찾기 탭 활성
  2. **ID (Email) 입력 필드**: `type="text" inputMode="email" autoComplete="email"` (§22-24 규칙)
  3. **모바일 번호 섹션**: 아이디 찾기와 동일(Globe + 국가코드 + 휴대폰 입력)
  4. **reCAPTCHA Enterprise** (action=`find_account` 공용) — env 미설정 시 placeholder
  5. **OTP 발송 요청 버튼**("Send verification code to email")
  6. **이메일 수신함 확인 안내** (OTP 발송 후 표시) + **OTP 입력 필드 + 타이머(03:00)**
  7. **(OTP 검증 성공 후) 새 비밀번호 입력** — placeholder: "Password (letters, numbers, special chars 6~16)"
  8. **(OTP 검증 성공 후) 새 비밀번호 확인 입력**
  9. **확인 버튼**: 비밀번호 변경 제출
- **상태 관리** (3-1 공통 + 추가):
  - 추가 로컬: `email`, `emailError`, `otpSent`, `newPassword`, `confirmPassword`, `passwordError`, `confirmPasswordError`, `isPasswordStep`(OTP 검증 완료 후 비밀번호 설정 화면 전환 플래그)
- **API 연동** (backend yaml v2026-04-16 기준):

  | 엔드포인트 | Method | Request Body | Response | 비고 |
  |-----------|--------|-------------|----------|------|
  | `POST /api/members/find-password-cert` | POST | `{ acCountry, crPhone, acId, captchaToken }` | `204` (발송 성공) | acCountry=EN/JP → 이메일 OTP 발송 |
  | `POST /api/members/change-passwd` | POST | `{ acId, acCertNum, newPassword, newPasswordRe }` | `200 { data: null }` | OTP 검증 + 새 비밀번호 설정. 비밀번호 찾기 플로우 후속 (security: cookieAuth), 실제 인증 토큰 없이도 호출 가능한지 백엔드 확정 필요 |
  | (fallback) `POST /api/members/reset-password` | POST | `{ acId, newPassword, newPasswordRe }` | `200 { data: null }` | 관리자/시스템이 임시 비밀번호를 이메일 발송한 후 첫 로그인 시 사용 (인증 미필요) |

  **⚠️ Backend 합의 대기**: `change-passwd` 스펙상 JWT 필요(`security: cookieAuth`)인데 비로그인 상태의 비밀번호 찾기에서 어떻게 호출할지 명확화 필요.

- **사용자 인터랙션**:
  1. 이메일 + 휴대폰 번호 + 국가 + reCAPTCHA → "Send code to email"
  2. 이메일 수신함에서 OTP 확인 → OTP 입력 → "Verify"
  3. OTP 검증 성공 → `isPasswordStep=true` → 비밀번호 입력 화면
  4. 새 비밀번호 + 확인 입력 → "Confirm" → API 호출 → Alert "Password changed" → `/login` 이동
- **비즈니스 규칙**:
  - 유효성(이메일 단계):
    - 이메일 미입력: "Please enter your email"
    - 이메일 형식 오류: "Please enter a valid email"
    - 휴대폰 번호 미입력: 아이디 찾기와 동일
  - API 에러 처리:
    - 404 NOT_FOUND ("이메일+전화번호 일치 계정 없음"): Alert "No matching account found"
    - 403 FORBIDDEN ("인증 시도 횟수 초과"): Alert "Too many attempts. Please try again later"
    - 500 INTERNAL ("발송 실패"): Alert "Failed to send verification code. Please retry"
  - OTP 검증 단계:
    - 불일치 → 에러 표시
    - 만료 → 재발송 유도
  - 비밀번호 설정 규칙: 영문/숫자/특수문자 중 2가지 이상, 6~16자
  - 성공 → Alert + `/login` 이동
- **엣지 케이스**:
  - 이메일 도착 지연 (재발송 쿨다운 필요)
  - 이메일 수신 불가(오타/잘못된 이메일) → 404로 대응하되 UX는 정상 성공처럼(계정 존재 여부 노출 방지 — CWE-204)
  - SMS A2P 제한 국가 사용자의 경우, 이 이메일 채널이 **유일한 복구 경로**. 국가별 채널 분기의 정당성 제공 (audit: `2026-04-16-native-app-global-migration-requirements` 참조)

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 위치 | 사용처 | Props |
|---------|------|-------|-------|
| `FindAccountForm` | `app/[locale]/find-account/_components/FindAccountForm.js` | 도메인 전체 (클라이언트) | `labels`, `locale` |
| `FindAccountResultModal` | `app/[locale]/find-account/_components/FindAccountResultModal.js` | 아이디 찾기 결과 표시 | `labels`, `isOpen`, `email`, `channel`, `onClose` |
| `PageNavBar` | `app/[locale]/_components/PageNavBar.js` | 상단 네비게이션 | `locale`, `title`, `homeLabel` |
| `ReCaptchaEnterprise` | `components/ReCaptchaEnterprise.js` | reCAPTCHA 위젯 | `ref`, `action`, `onChange`, `onExpired`, `onErrored` |
| `AlertModal` | `components/AlertModal.js` | 공용 Alert | `message`, `onClose` |
| `ModalOverlay` | `components/ModalOverlay.js` | 공용 backdrop | `onClose` (§22-40 Backdrop 상호작용) |

### 4-1. 탭 내부 공유 UI 패턴

| UI 패턴 | 아이디 찾기 | 비밀번호 찾기 | 비고 |
|---------|-----------|-------------|------|
| 국가 선택 버튼 | O | O | 동일 구조 (§8 기본값 +1) |
| reCAPTCHA Enterprise | O | O | action=`find_account` 공유 |
| 휴대폰 번호 + 인증 | O | **국가별 채널 분기** | EN/JP=이메일 OTP, KR=알림톡(범위 밖) |
| ID (Email) 입력 | X | O | 비밀번호 찾기 전용 |
| OTP 타이머 | O (SMS/알림톡) | O (이메일) | 3분 공통 |
| 새 비밀번호 설정 | X | O | OTP 검증 후 표시 |

## 5. 크로스 도메인 의존성

- **의존**: `login` (로그인 페이지의 "I forgot my ID/Password" 링크로 진입 — 커밋 `80c6529`에서 LoginForm 링크 활성화)
- **피의존**: `login` (비밀번호 변경 완료 후 `/login` 리다이렉트)
- **간접 의존**: `lib/fetchWithAuth.js`(`secureFetch` — CSRF 자동), `lib/sanitizeHtml.js`(`escapeHtml` — XSS 방어), `lib/recaptcha.js`(Enterprise 싱글톤 로더)

## 6. 외부 의존성

| 패키지 | 용도 | 환경변수 |
|--------|------|---------|
| `lib/recaptcha.js` (자체 Enterprise 싱글톤 로더) | reCAPTCHA Enterprise 위젯 | `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` |

- **⚠️ 변경 확정(유형 A)**: 기존 `react-google-recaptcha`(v2 classic) → **reCAPTCHA Enterprise**로 전환 완료 (커밋 `ecb3295`).
- env 미설정 시 placeholder 렌더링 (§22-4-B 방어).
- CSP 확인 완료: `proxy.js`의 `script-src` + `frame-src`에 `https://www.google.com` + `https://www.gstatic.com` 포함.

## 7. i18n 네임스페이스 (as-built — messages/en.json 기준)

- **네임스페이스**: `findAccount`

| 키 | 영문(en) 실제값 | 용도 |
|----|----------------|------|
| `navTitle` | "Find your ID or Password" | PageNavBar 타이틀 |
| `navHomeBtn` | "Home" | PageNavBar Home |
| `tabFindId` | "Find ID" | 아이디 찾기 탭 |
| `tabFindPassword` | "Find Password" | 비밀번호 찾기 탭 |
| `mobileNumberLabel` | "Mobile Number" | 모바일 섹션 라벨 |
| `countryDefault` | "Unites States +1" | 기본 국가 (§26-8 오타 유지 — 디자이너 확인 필요) |
| `phonePlaceholder` | "Enter your Mobile Number" | 번호 입력 placeholder |
| `verificationBtn` | "Verification" | 인증받기 버튼 |
| `phoneError` | "Please enter your mobile number" | 번호 미입력 에러 |
| `verificationCodePlaceholder` | "Enter Verification Code" | OTP placeholder |
| `verificationCodeError` | "Please enter the verification code" | OTP 미입력 에러 |
| `confirmBtn` | "Confirm" | 확인 버튼 |
| `customerServiceNotice` | "If you cannot remember... 1644-8190" | 고객센터 (§8 국가별 분기 미확정) |
| `modalTitle` | "Notice" | FindAccountResultModal 타이틀 |
| `modalHeading` | "Your ID (email) is as follows" | 결과 헤딩 |
| `modalChannelTemplate` | "(Sign-up channel: {channel})" | 결과 본문 |
| `modalConfirmBtn` | "Confirm" | 결과 확인 |
| `recaptchaPlaceholder` | "reCAPTCHA placeholder (NEXT_PUBLIC_RECAPTCHA_SITE_KEY missing)" | env 미설정 fallback |
| `findPasswordTodo` | "Find Password tab — coming soon." | 비번찾기 placeholder (제거 예정) |
| `verificationExpired` | "Verification time has expired. Please try again." | 타이머 만료 |
| `errorMemberNotFound` | "No matching account found." | 404 |
| `errorVerificationMismatch` | "The verification code does not match." | OTP 불일치 |
| `errorNetwork` | "Network error. Please try again." | 네트워크 에러 |

**추가 필요 키 (비밀번호 찾기 구현 시)**:
- `emailLabel`, `emailPlaceholder`, `emailError`
- `sendEmailOtpBtn`, `emailOtpSentNotice`
- `newPasswordPlaceholder`, `confirmPasswordPlaceholder`
- `passwordRuleError`, `passwordLengthError`, `passwordMismatchError`
- `passwordChangedSuccess`

## 8. 미확정 사항

- [ ] 국가 선택 목록 데이터 소스(하드코딩 vs API 조회)
- [ ] 국가별 휴대폰 번호 형식 검증 규칙(자릿수, 패턴)
- [ ] 인증번호 재발송 횟수 제한 여부 (backend `403 FORBIDDEN — 시도 횟수 초과` 조건 확정 필요)
- [ ] 아이디 찾기 결과 이메일 마스킹 규칙(백엔드 반환값이 이미 마스킹인지, 프론트에서 마스킹할지)
- [ ] 고객센터 전화번호 국가별 분기 여부
- [ ] 비밀번호 찾기 OTP 자릿수(4자리 vs 6자리)
- [ ] 아이디 찾기 결과 모달에서 "로그인하기" 버튼 제공 여부
- [ ] 비밀번호 찾기 `change-passwd` 인증 요구사항 확정 (cookieAuth 대안?)
- [x] reCAPTCHA 타입 → **Enterprise (score-based) 확정** (유형 A)
- [x] 비밀번호 변경 완료 후 리다이렉트 → **`/login` 확정**
- [x] 비밀번호 찾기 탭에서 이메일 입력 필수 여부 → **필수 확정** (backend yaml `required: [acCountry, crPhone, acId]`)

## 9. 감사 연동 및 미반영 요구사항 (유형 B)

| # | 감사 항목 | 문서 | 반영 상태 |
|---|-----------|------|----------|
| 1 | reCAPTCHA 서버 검증 (`captchaToken` body 전송 + `createAssessment`) | `2026-04-16-recaptcha-signup-flow-us-jp-requirement.md` | **미반영 [CRITICAL]** |
| 2 | `hc_csrf_meta` 우선 CSRF 전략 | `58152a1` 커밋 + 자체 구현 | 반영 완료 (`secureFetch` 자동) |
| 3 | `__Host-` prefix 쿠키 | hostname-migration-decisions D-14 | 미반영 |
| 4 | Rate limiting 429 응답 — UI 처리 | `frontend-api-integration-readiness-review` | FFS에 반영, 코드 상 구현 확인 필요 |

## 10. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 최초 작성 (Draft) | 명우현 |
| v1.1 | 2026-04-17 | **유형 A**: API 엔드포인트(/api/auth→/api/members), 필드명(crPhone/acCountry/acCertNum), reCAPTCHA Enterprise, FindAccountResultModal, i18n 키 실제값. **유형 B**: captchaToken 서버 검증, __Host- prefix 요구. **유형 C**: 비밀번호 찾기 해외=이메일 OTP 분기 전면 재설계(find-password-cert + change-passwd + reset-password 3개 API) | 명우현 |
