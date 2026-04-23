# Frontend Functional Spec — 회원가입
> Source: 화면설계서 PPTX Slides S22~S47 + as-built 코드 + 감사 문서(2026-04-16)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

> **참조 버전**: backend `member-api.yaml` v2026-04-16 (변경 예정). 최종 확정 후 별도 정합성 맞춤 패스 진행.

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | 회원가입 (Join / Sign Up) |
| 사용자 목표 | 신규 사용자가 SNS(Google/Apple/Facebook/LINE/Kakao/Naver) 또는 이메일을 통해 회원가입을 완료한다 |
| 퍼블리싱 상태 | 퍼블리싱 완료 (방법선택, SNS 가입폼, 이메일 가입폼, SNS 가입완료, 이메일 가입완료) |
| 기능 연동 상태 | **부분 연동** — SMS 본인인증/유효성검사/reCAPTCHA Enterprise/약관 모달/OAuth 콜백 자동로그인 구현 완료. **이메일 소유 검증(send-mail-cert/confirm-mail-cert) 미구현** |
| i18n 네임스페이스 | `join`, `joinSns`, `joinSnsComplete`, `joinEmail`, `joinEmailComplete` |
| 지원 로케일 | `en`, `ja` (KR은 프로젝트 범위 밖 — 기존 홍카페K 유지) |
| 뷰포트 기준 | 모바일 390x844 (Figma 핸드오프 360px 시안, 구현 PC 최대 430px — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]`) |

### 도메인 흐름 요약

```
방법 선택 (/join)
  ├── Google → SNS 가입폼 (/join/google) → 완료 (/join/google/complete)
  ├── Apple  → SNS 가입폼 (/join/apple)  → 완료 (/join/apple/complete)
  └── Email  → 이메일 가입폼 (/join/email) → 완료 (/join/email/complete)

  ※ 기가입 → 기가입 안내 화면 (미구현)
  ※ 재가입 → 재가입 불가/가능 분기 화면 (미구현)
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/join` | `app/[locale]/join/page.js` | JoinMethods | Server → Client | `join` |
| `/[locale]/join/google` | `app/[locale]/join/[provider]/page.js` | SnsJoinForm | Server → Client | `joinSns` |
| `/[locale]/join/apple` | `app/[locale]/join/[provider]/page.js` | SnsJoinForm | Server → Client | `joinSns` |
| `/[locale]/join/email` | `app/[locale]/join/[provider]/page.js` | EmailJoinForm | Server → Client | `joinEmail` |
| `/[locale]/join/google/complete` | `app/[locale]/join/[provider]/complete/page.js` | SnsJoinComplete | Server → Client | `joinSnsComplete` |
| `/[locale]/join/apple/complete` | `app/[locale]/join/[provider]/complete/page.js` | SnsJoinComplete | Server → Client | `joinSnsComplete` |
| `/[locale]/join/email/complete` | `app/[locale]/join/[provider]/complete/page.js` | EmailJoinComplete | Server → Client | `joinEmailComplete` |

### generateStaticParams

- `[provider]` 가입폼: `apple`, `google`, `email`
- `[provider]/complete` 완료: `apple`, `google` (이메일 완료는 별도 분기로 EmailJoinComplete 렌더링)

---

## 3. 페이지 정의

### 3-1. 방법 선택 화면

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/join` |
| Server Component | `app/[locale]/join/page.js` — 메타데이터 생성, labels 객체 구성 |
| Client Component | `app/[locale]/join/_components/JoinMethods.js` |
| 화면설계서 | S23, S25 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — 보라색 배경, 뒤로가기 + "Sign in" + Home 버튼 |
| 1 | 페이지 타이틀 | "Select Joining method" — text-center, font-bold, 2.4rem |
| 2 | 방법 버튼 리스트 | Google / Apple / Email 3개 버튼 (locale별 상이) |

#### 상태 관리

- 없음. 정적 렌더링 페이지.

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


- 없음. 순수 네비게이션 페이지.

#### 인터랙션

| 액션 | 동작 |
|------|------|
| Google 버튼 클릭 | `/{locale}/join/google`로 이동 |
| Apple 버튼 클릭 | `/{locale}/join/apple`로 이동 |
| Email 버튼 클릭 | `/{locale}/join/email`로 이동 |
| 뒤로가기 버튼 | `router.back()` |
| Home 버튼 | `/{locale}`로 이동 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 로케일별 방법 구성 | KR: 이메일+카카오+네이버+Apple+Google, JP: 이메일+LINE+Apple+Google, US: 이메일+Apple+Google |
| 현재 구현 상태 | US 기준 3개 버튼(Google, Apple, Email)만 구현. 로케일별 분기 미구현 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 이미 로그인된 사용자가 접근 | 미구현 — 향후 로그인 상태 체크 후 메인으로 리다이렉트 필요 |
| 지원하지 않는 provider 접근 | generateStaticParams로 apple/google/email만 허용, 나머지는 404 |

#### i18n

| 키 | en 값 |
|----|-------|
| `join.signIn` | Sign in |
| `join.home` | Home |
| `join.selectJoiningMethod` | Select Joining method |
| `join.signInWithGooglePrefix` | Sign in with  |
| `join.signInWithGoogleBold` | Google |
| `join.signInWithApplePrefix` | Sign in with  |
| `join.signInWithAppleBold` | Apple |
| `join.joinWithEmailPrefix` | Join with  |
| `join.joinWithEmailBold` | Email |

#### 의존성

| 의존성 | 용도 |
|--------|------|
| `PageNavBar` | 상단 네비게이션 공유 컴포넌트 |
| `next/link` | 방법 버튼 Link 컴포넌트 |
| `next/image` | 방법별 아이콘 (icon_google.svg, icon_apple.svg, icon_email.svg) |

---

### 3-2. SNS 가입폼 (Apple / Google)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/join/apple`, `/[locale]/join/google` |
| Server Component | `app/[locale]/join/[provider]/page.js` — provider 분기, labels 구성 |
| Client Component | `app/[locale]/join/[provider]/_components/SnsJoinForm.js` |
| 화면설계서 | S24, S26, S27~S29 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "Join" + Home |
| 1 | provider 아이콘 + 타이틀 | provider별 로고(google/apple/kakao/naver/line/facebook 6종) + `joinWithXxxAccount` 타이틀 |
| 2 | ID (Email) 필드 | OAuth 콜백 prefill로 초기값 주입. **as-built는 controlled input(수정 가능)** — 화면설계서의 readOnly와 차이 (유형 D — 백엔드 정책 확정 필요) |
| 3 | Nickname 필드 | OAuth 콜백 prefill로 초기값 주입. **as-built는 controlled input(수정 가능)** — Apple은 닉네임 미제공이라 사용자 입력 필수 |
| 4 | Date of Birth | Year/Month/Date 3개 select 드롭다운 |
| 5 | Mobile Number | Globe 아이콘 + 국가 선택 + Chevron 아이콘 |
| 6 | reCAPTCHA Enterprise | `components/ReCaptchaEnterprise.js` (action=`signup_sns`) — env 미설정 시 placeholder |
| 7 | 구분선 | 0.8rem 높이 회색 디바이더 |
| 8 | 약관 동의 | `TermsFullModal` + 전체 동의 + 개별 3항목 (19세, 이용약관, 개인정보) |
| 9 | Sign Up 버튼 | 전체 동의 + 유효성 검증 + SMS 인증 완료 시 활성 |

> **Note (유형 A — as-built)**: SNS 가입폼은 `crMailCert: 'Y'` 하드코딩으로 join-user body에 전송. SNS OAuth가 이메일 소유를 이미 검증한 것으로 간주.
> **유의 (유형 D — 정책 확정 필요)**: 화면설계서는 ID/Nickname을 readOnly로 명시했으나 as-built는 사용자 수정 가능. 보안/UX 정책 확정 후 readOnly 전환 여부 결정 필요.

#### 상태 관리

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `emailError` | string | `''` | 이메일 에러 메시지 |
| `nicknameError` | string | `''` | 닉네임 에러 메시지 |
| `dobError` | string | `''` | 생년월일 에러 메시지 |
| `mobileError` | string | `''` | 휴대전화 에러 메시지 |
| `dobYear` | string | `''` | 생년 선택값 |
| `dobMonth` | string | `''` | 생월 선택값 |
| `dobDate` | string | `''` | 생일 선택값 |
| `recaptchaToken` | string | `''` | reCAPTCHA Enterprise 토큰 |
| `agreeAll` | boolean | `false` | 전체 동의 체크 |
| `agree19` | boolean | `false` | 19세 이상 동의 |
| `agreeTerms` | boolean | `false` | 이용약관 동의 |
| `agreePrivacy` | boolean | `false` | 개인정보 동의 |
| (ref) `recaptchaRef` | RefObject | — | reCAPTCHA 리셋 제어 |
| (zustand) `useAuthStore.setAuth` | — | — | 가입 성공 시 로그인 상태 세팅 |

**공용 컴포넌트 활용** (유형 A — as-built):
- `PhoneCertField` (`app/[locale]/_components/PhoneCertField.js`) — 휴대폰 + SMS OTP 입력 공용
- `TermsFullModal` (`app/[locale]/join/_components/TermsFullModal.js`) — 약관 전문 모달 (콘텐츠는 `lib/mock/termsContent.js`에서 주입, CMS 교체 가능 구조)

#### API 연동 (as-built + backend yaml v2026-04-16 기준)

| 엔드포인트 | 메서드 | 용도 | 구현 상태 |
|-----------|--------|------|----------|
| `GET /api/auth/{provider}` → `GET /api/auth/{provider}/callback` | GET | SNS OAuth 진입 + 콜백 — `lib/oauth/client.js`, `app/api/auth/[provider]/callback/route.js` | **구현 완료** (커밋 `b168d51`) |
| `POST /api/members/check-id` | POST | `{ acId }` — 이메일 중복 확인 | 구현 |
| `POST /api/members/check-nick` | POST | `{ acNick }` — 닉네임 중복 확인 | 구현 |
| `POST /api/members/send-global-cert` | POST | `{ crPhone, acCountry }` — SMS OTP 발송 (`PhoneCertField`) | 구현 |
| `POST /api/members/confirm-global-cert` | POST | `{ crPhone, acCountry, acCertNum }` — SMS OTP 검증 | 구현 |
| `POST /api/members/join-user` | POST | 전체 가입 정보 제출 — 성공 시 `hc_access`/`hc_refresh`/`hc_csrf` 쿠키 자동 발급 → **홈 직행** (`setAuth(true, data.data)`) | 구현 |

**SNS OAuth 자동 로그인 분기** (커밋 `b168d51`, `lib/oauth/session.js`):
- 콜백 응답의 `exist_flag=4`(기존 사용자) → `tryAutoLogin` → 기존 세션 자동 복구 + `/` 홈 직행
- 미가입자 → `SnsJoinForm`으로 분기하여 추가 정보(휴대폰·생년월일·약관) 수집

**⚠️ 감사 권고 미반영 (유형 B, CRITICAL)**: reCAPTCHA 서버 사이드 검증을 위해 **`captchaToken`을 `secureFetch` body에 포함**해야 함 (audit: `2026-04-16-recaptcha-signup-flow-us-jp-requirement.md`). 현재 `SnsJoinForm.js`/`EmailJoinForm.js` 모두 프론트 토큰 생성만 있고 백엔드 `createAssessment` 호출 없음.

#### 인터랙션

| 액션 | 동작 (as-built) |
|------|----------------|
| 이메일/닉네임 입력 | controlled input — 사용자 수정 가능 (prefill 값 위에 덮어쓰기 가능) |
| 휴대폰 번호 입력 → "인증받기" | `PhoneCertField` → `POST /api/members/send-global-cert` (`{ acCountry, acPhoneNo }`) |
| SMS OTP 입력 → "확인" | `POST /api/members/confirm-global-cert` → `isPhoneVerified=true` |
| reCAPTCHA Enterprise 토큰 발급 | `ReCaptchaEnterprise` (action=`signup_sns`) — `captchaToken` 상태 갱신 |
| 약관 그룹 토글 | `AgreementGroup` 컴포넌트 — agreeAll ↔ 개별 4패턴 동기화 (V4.9 §22-22) |
| 이용약관/개인정보 텍스트 클릭 | `TermsFullModal` 모달 오픈 (`lib/mock/termsContent.js`에서 콘텐츠 주입) |
| Sign Up 클릭 (전체 검증 통과) | `validateEmail/Nickname/Dob/Phone/Captcha/AllAgreed` → `POST /api/members/join-user` → 성공 시 `setAuth(true, data)` + **`router.push('/')` 홈 직행** (가입완료 페이지 미경유) |
| Sign Up 클릭 (미통과) | 각 필드 에러 메시지 표시 + return early |
| Sign Up 실패 응답 | `submitError`에 `escapeHtml(data.msg)` 표시 (XSS 방어) |
| 생년월일 select 변경 | 해당 필드 상태 업데이트 |

#### 비즈니스 규칙

| 규칙 | 설명 | 화면설계서 |
|------|------|----------|
| SNS 이메일/이름 수정 불가 | Apple/Google에서 가져온 이메일, 이름은 readOnly 표시 | S27 |
| 국가 선택 필수 | 국가 코드 + 휴대전화 번호 입력 필수 | S28 |
| reCAPTCHA 필수 | 봇 방지 reCAPTCHA 인증 완료 후 인증번호 발송 | S28 |
| 인증번호 검증 | 휴대전화 인증번호 입력 및 검증 | S28 |
| 생년월일 필수 | 년/월/일 모두 선택해야 함 | S29 |
| 미성년자 체크 | 만 19세 미만 가입 불가 | S24 |
| 기가입 체크 | 이메일+휴대폰 둘 다 일치 시 기가입 안내 | S24 |
| 약관 전체 동의 필수 | 19세 이상 + 이용약관 + 개인정보 3개 모두 동의해야 가입 가능 | S29 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| SNS OAuth 실패 | 미구현 — 에러 처리 및 재시도 UI 필요 |
| reCAPTCHA 로딩 실패 | 환경변수 미설정 시 placeholder 렌더링 (현재 구현) |
| 기가입 회원 (이메일+휴대폰 둘 다 일치) | 기가입 안내 화면 이동 — 미구현 |
| 기가입 의심 (하나만 일치) | 고객센터 안내 화면 이동 — 미구현 |
| 탈퇴 후 7일 이내 재가입 | 재가입 불가 안내 화면 이동 — 미구현 |
| 탈퇴 후 7일 경과 재가입 | 정상 가입 프로세스 진행 — 미구현 |

#### i18n

| 키 | en 값 |
|----|-------|
| `joinSns.join` | Join |
| `joinSns.home` | Home |
| `joinSns.joinWithAppleAccount` | Join with Apple account |
| `joinSns.idEmail` | ID (Email) |
| `joinSns.nickname` | Nickname |
| `joinSns.dateOfBirth` | Date of Birth |
| `joinSns.mobileNumber` | Mobile Number |
| `joinSns.signUp` | Sign Up |

#### 의존성 (as-built)

| 의존성 | 용도 |
|--------|------|
| `PageNavBar` | 상단 네비게이션 |
| `PhoneCertField` (`app/[locale]/_components/PhoneCertField.js`) | 국가코드 + 휴대폰 + SMS OTP 통합 컴포넌트 |
| `AgreementGroup` (`app/[locale]/join/_components/AgreementGroup.js`) | 약관 동의 그룹 + agreeAll 4패턴 동기화 |
| `TermsFullModal` (`app/[locale]/join/_components/TermsFullModal.js`) | 약관 전문 모달 (콘텐츠 `lib/mock/termsContent.js`) |
| `ReCaptchaEnterprise` (`components/ReCaptchaEnterprise.js`) | reCAPTCHA Enterprise 위젯 (action=`signup_sns`) |
| `lib/recaptcha.js` | Enterprise 싱글톤 로더 + `RECAPTCHA_ENTERPRISE_SITE_KEY` |
| `lib/validators/joinEmail.js` | Pure 유효성 검사 (이메일/닉네임/DOB/전화/captcha/agreement) |
| `lib/fetchWithAuth.js` (`secureFetch`) | CSRF Signed Double Submit 토큰 자동 첨부 (커밋 `58152a1`) |
| `lib/sanitizeHtml.js` (`escapeHtml`) | API 응답 `data.msg` XSS 방어 |
| `store/useAuthStore.js` (`setAuth`) | 가입 성공 시 로그인 상태 전환 |
| `useRouter` | Sign Up 성공 후 `/` 홈 직행 |
| `next/link`, `next/image` | 네비게이션 + 이미지 |

---

### 3-3. 이메일 가입폼

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/join/email` |
| Server Component | `app/[locale]/join/[provider]/page.js` — `isEmail` 분기 |
| Client Component | `app/[locale]/join/[provider]/_components/EmailJoinForm.js` |
| 화면설계서 | S30~S35 |

#### UI 섹션

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "Join" + Home |
| 1 | 배너 | 노란 배경 "10,000 Gift coin for a New Member" |
| 2 | 페이지 타이틀 | "Join with Email" — text-center, font-bold, 2.4rem |
| 3 | ID (Email) 입력 + **인증받기 버튼** | 이메일 입력 + `POST /api/members/send-mail-cert` 발송 트리거, placeholder "Please enter your ID (email)", Clear 아이콘 |
| 3a | **이메일 OTP 입력 영역** (발송 후 표시) | 이메일 수신함 OTP 입력 + 타이머(3분) + 재발송. 성공 시 `crMailCert:"Y"` 획득하여 join-user에 포함 (**유형 C — 미구현**) |
| 4 | Password 입력 | 비밀번호 입력, 눈 아이콘 토글, placeholder "Password (6 to 12 characters)" |
| 5 | Confirm Password | 비밀번호 확인, 눈 아이콘 토글, placeholder "Retype Password" |
| 6 | Nickname 입력 | 닉네임 입력, placeholder "Nickname (6 to 12 characters)", Clear 아이콘 |
| 7 | Date of Birth | Year/Month/Date 3개 select 드롭다운 |
| 8 | Mobile Number | Globe 아이콘 + 국가 선택 + Chevron 아이콘 |
| 9 | reCAPTCHA 영역 | 현재 placeholder ("Apple Sign In Banner" 텍스트) |
| 10 | 구분선 | 0.8rem 높이 회색 디바이더 |
| 11 | 약관 동의 | 전체 동의 + 개별 3항목 (19세, 이용약관, 개인정보) |
| 12 | Sign Up 버튼 | 전체 동의 시 보라색 활성, 미동의 시 회색 비활성 |

#### 상태 관리

| 상태 | 타입 | 초기값 | 용도 |
|------|------|--------|------|
| `email` | string | `''` | 이메일 입력값 |
| `password` | string | `''` | 비밀번호 입력값 |
| `confirmPassword` | string | `''` | 비밀번호 확인 입력값 |
| `nickname` | string | `''` | 닉네임 입력값 |
| `dobYear` | string | `''` | 생년 선택값 |
| `dobMonth` | string | `''` | 생월 선택값 |
| `dobDay` | string | `''` | 생일 선택값 |
| `mobile` | string | `''` | 휴대전화 번호 |
| `showPassword` | boolean | `false` | 비밀번호 표시/숨김 |
| `showConfirmPassword` | boolean | `false` | 비밀번호 확인 표시/숨김 |
| `mailCertCode` | string | `''` | 이메일 OTP 입력값 (유형 C 신규) |
| `mailCertSent` | boolean | `false` | 이메일 OTP 발송 완료 여부 |
| `mailCertVerified` | boolean | `false` | 이메일 OTP 검증 완료 여부 (= `crMailCert:"Y"` 획득) |
| `mailCertTimer` | number | `0` | 이메일 OTP 타이머 (초) |
| `recaptchaToken` | string | `''` | reCAPTCHA Enterprise 토큰 (유형 A) |
| `emailError` | string | `''` | 이메일 에러 메시지 |
| `passwordError` | string | `''` | 비밀번호 에러 메시지 |
| `confirmPasswordError` | string | `''` | 비밀번호 확인 에러 메시지 |
| `nicknameError` | string | `''` | 닉네임 에러 메시지 |
| `dobError` | string | `''` | 생년월일 에러 메시지 |
| `mobileError` | string | `''` | 휴대전화 에러 메시지 |
| `agreeAll` | boolean | `false` | 전체 동의 체크 |
| `agreeAge` | boolean | `false` | 19세 이상 동의 |
| `agreeTerms` | boolean | `false` | 이용약관 동의 |
| `agreePrivacy` | boolean | `false` | 개인정보 동의 |

#### API 연동 (as-built + 유형 C 신규)

| 엔드포인트 | 메서드 | Request Body | 용도 | 구현 상태 |
|-----------|--------|-------------|------|----------|
| `POST /api/members/check-id` | POST | `{ acId }` | 이메일 중복 체크 | 구현 (EmailJoinForm blur 검증) |
| `POST /api/members/check-nick` | POST | `{ acNick }` | 닉네임 중복 체크 | 구현 |
| `POST /api/members/send-mail-cert` | POST | `{ acId }` (rate 3회/60초) | **이메일 소유 검증 OTP 발송** (유형 C — TempleteMail 라이브러리) | **미구현** (프록시 route.js만 존재) |
| `POST /api/members/confirm-mail-cert` | POST | `{ acId, mailCertNo }` | 이메일 OTP 검증 → 응답 `{ certMailAddress, crMailCert: "Y" }` | **미구현** |
| `POST /api/members/send-global-cert` | POST | `{ crPhone, acCountry }` | SMS OTP 발송 (`PhoneCertField`) | 구현 |
| `POST /api/members/confirm-global-cert` | POST | `{ crPhone, acCountry, acCertNum }` | SMS OTP 검증 | 구현 |
| `POST /api/members/join-user` | POST | `{ acId, acPassword, acPasswordRe, acNick, crPhone, acCountry, birthYear, birthMonth, birthDay, crMailCert?, captchaToken, ... }` | 최종 가입 제출 → 쿠키 자동발급 + `setAuth` + 홈 직행 | 구현 (crMailCert 필드 연결 미완) |

**이메일 소유 검증 플로우 (유형 C 신규 설계)**:
```
1. 사용자가 이메일 입력 → blur 시 check-id (중복 확인)
2. "인증받기" 버튼 클릭 → send-mail-cert → 이메일 수신함에 OTP 발송 (409: 이미 등록된 이메일, 500: 발송 실패)
3. OTP 입력 → confirm-mail-cert → 응답의 crMailCert="Y" 저장 (mailCertVerified=true)
4. Sign Up 제출 시 join-user body에 crMailCert:"Y" 포함
```

**⚠️ 감사 권고 미반영 (유형 B, CRITICAL)**: `captchaToken` body 포함 + 백엔드 `createAssessment` 검증 필요 (reCAPTCHA Enterprise).

#### 인터랙션

| 액션 | 동작 (as-built) |
|------|----------------|
| 이메일 입력 | 실시간 상태 업데이트 (제출 시 `validateEmail`로 형식 검사) |
| 비밀번호 입력 | 실시간 상태 업데이트, Eye 아이콘으로 표시/숨김 토글 |
| 비밀번호 확인 입력 | 실시간 상태 업데이트, 제출 시 `validateConfirm`으로 일치 검사 |
| 닉네임 입력 | 실시간 상태 업데이트 (제출 시 `validateNickname`로 형식·길이 검사) |
| 생년월일 select 변경 | 해당 필드 상태 업데이트 |
| **인증받기 버튼 클릭** (유형 C — 미구현) | `POST /api/members/send-mail-cert` (`{ acId }`) → 성공 시 `mailCertSent=true`, 3분 타이머 시작, OTP 입력 영역 노출 |
| **OTP 확인 버튼 클릭** (유형 C — 미구현) | `POST /api/members/confirm-mail-cert` (`{ acId, mailCertNo }`) → 성공 시 `mailCertVerified=true` |
| **재발송 버튼 클릭** (유형 C — 미구현) | 타이머 만료 후 활성화 — `POST /api/members/send-mail-cert` 재호출 |
| 국가 선택 클릭 | `PhoneCertField` 내부 국가코드 선택기 (바텀시트 — 미구현 시 기본 `'US'`) |
| 휴대폰 인증 | `PhoneCertField` → `send-global-cert`/`confirm-global-cert` → `isPhoneVerified=true` |
| reCAPTCHA Enterprise | `ReCaptchaEnterprise` (action=`signup_email`) → `captchaToken` 상태 갱신 |
| 약관 동의 그룹 | `AgreementGroup` 컴포넌트 (전체 동의 ↔ 개별 4패턴) |
| 이용약관/개인정보 텍스트 클릭 | `TermsFullModal` 모달 오픈 |
| Sign Up 클릭 (전체 검증 통과) | `validateAll` → `POST /api/members/join-user` (현재 `crMailCert` 미포함 — **유형 C 적용 시 추가 필요**) → 성공 시 `setAuth(true, data)` + **`router.push('/')` 홈 직행** |
| Sign Up 클릭 (미통과) | 각 필드 에러 메시지 표시 + return early |
| Sign Up 실패 응답 | `submitError`에 `escapeHtml(data.msg)` 표시 (XSS 방어) |

#### 비즈니스 규칙 — 유효성검사 (S32)

| 필드 | 규칙 | 에러 메시지 (한국어 기준) |
|------|------|------------------------|
| 이메일 — 미입력 | 빈 값 제출 시 | 이메일을 입력해주세요 |
| 이메일 — 형식 오류 | 이메일 형식 불일치 | 올바른 이메일 형식을 입력해주세요 |
| 이메일 — 중복 | 서버 응답: 이미 가입된 이메일 | 이미 가입된 이메일입니다 |
| 비밀번호 — 미입력 | 빈 값 제출 시 | 비밀번호를 입력해주세요 |
| 비밀번호 — 길이 미달 | 6자 미만 | 비밀번호는 6~16자여야 합니다 |
| 비밀번호 — 조합 미달 | 영문+숫자+특수문자 미포함 | 영문, 숫자, 특수문자를 조합해주세요 |
| 비밀번호 확인 — 불일치 | password !== confirmPassword | 비밀번호가 일치하지 않습니다 |
| 닉네임 — 미입력 | 빈 값 제출 시 | 닉네임을 입력해주세요 |
| 닉네임 — 길이 미달/초과 | 2자 미만 또는 12자 초과 | 닉네임은 2~12자여야 합니다 |
| 닉네임 — 형식 오류 | 한글/영문/숫자 외 문자 포함 | 한글, 영문, 숫자만 사용 가능합니다 |
| 닉네임 — 중복 | 서버 응답: 이미 사용 중인 닉네임 | 이미 사용 중인 닉네임입니다 |
| 생년월일 — 미선택 | Year/Month/Date 중 하나라도 미선택 | 생년월일을 선택해주세요 |
| 휴대전화 — 미입력 | 빈 값 제출 시 | 휴대전화 번호를 입력해주세요 |
| 휴대전화 — 인증번호 오류 | 인증번호 불일치 | 인증번호가 일치하지 않습니다 |
| 약관 — 미동의 | 필수 약관 미체크 시 | 필수 약관에 동의해주세요 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 비밀번호 6~16자 범위 | 클라이언트 사이드 실시간 검증 — 미구현 |
| 닉네임 한글 2~12자 / 영문 2~12자 | 바이트가 아닌 글자 수 기준 카운트 — 미구현 |
| 이메일 중복이면서 SNS 가입 회원 | 기가입 안내 화면 분기 — 미구현 |
| reCAPTCHA 토큰 만료 | 재인증 요청 — 미구현 |
| 인증번호 재발송 | 재발송 버튼 및 쿨다운 타이머 — 미구현 |
| 네트워크 에러 시 제출 | try/catch 에러 처리 — 미구현 |
| 중복 제출 방지 | isLoading 상태로 버튼 비활성화 — 미구현 |

#### i18n

| 키 | en 값 |
|----|-------|
| `joinEmail.join` | Join |
| `joinEmail.home` | Home |
| `joinEmail.10000GiftCoinForANewMember` | 10,000 Gift coin for a New Member |
| `joinEmail.joinWithEmail` | Join with Email |
| `joinEmail.idEmail` | ID (Email) |
| `joinEmail.pleaseEnterYourIdEmail` | Please enter your ID (email) |
| `joinEmail.password` | Password |
| `joinEmail.password6To12Characters` | Password (6 to 12 characters) |
| `joinEmail.confirmPassword` | Confirm Password |
| `joinEmail.retypePassword` | Retype Password |
| `joinEmail.nickname` | Nickname |
| `joinEmail.nickname6To12Characters` | Nickname (6 to 12 characters) |
| `joinEmail.dateOfBirth` | Date of Birth |
| `joinEmail.mobileNumber` | Mobile Number |
| `joinEmail.unitesStates1` | Unites States +1 |
| `joinEmail.iAgreeToAllOfTheFollowings` | I agree to all of the followings |
| `joinEmail.signUp` | Sign Up |

#### 의존성

| 의존성 | 용도 |
|--------|------|
| `PageNavBar` | 상단 네비게이션 (navClassName 커스텀 전달) |
| `PhoneCertField` | 휴대폰 + SMS OTP 공용 컴포넌트 (`app/[locale]/_components/PhoneCertField.js`) |
| `TermsFullModal` | 약관 전문 모달 (`app/[locale]/join/_components/TermsFullModal.js` + `lib/mock/termsContent.js`) |
| `ReCaptchaEnterprise` | reCAPTCHA Enterprise 위젯 (`components/ReCaptchaEnterprise.js`, action=`signup_email`) |
| `lib/recaptcha.js` | Enterprise 싱글톤 로더 + `RECAPTCHA_ENTERPRISE_SITE_KEY` export |
| `lib/validators/joinEmail.js` | Pure function 유효성 검증 (이메일/비밀번호/닉네임/생년월일) |
| `lib/fetchWithAuth.js` | `secureFetch` — CSRF 토큰 자동 첨부 (커밋 `58152a1` Signed Double Submit) |
| `lib/sanitizeHtml.js` | `escapeHtml` — API 응답 msg XSS 방어 |
| `store/useAuthStore.js` | `setAuth(true, data)` — 가입 성공 시 로그인 상태 전환 |
| `next/link`, `next/image`, `useRouter` | 네비게이션 + 이미지 |

---

### 3-4. 가입 완료 화면

> ⚠️ **as-built 미사용 (유형 D — 정책 확정 필요)**: 현재 SnsJoinForm/EmailJoinForm 모두 `join-user` 성공 시 `setAuth(true, data)` 후 **`router.push('/')` 홈으로 직행**한다. `/join/{provider}/complete` 라우트는 정적 파일은 존재하지만 정상 플로우로는 도달하지 않는 dead code. 화면설계서(S26/S36)의 "Welcome 화면 + 10,000 코인 안내" 노출 시점/방식 재정의 필요. 후보:
> - (a) 가입 직후 홈에 토스트/모달로 코인 안내
> - (b) 가입 직후 `/welcome` 인터스티셜 페이지 1회 노출 후 홈
> - (c) 현재처럼 직홈 (코인 안내는 마이페이지 내)

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/join/{provider}/complete` (현재 dead route) |
| Server Component | `app/[locale]/join/[provider]/complete/page.js` |
| Client Component (SNS) | `app/[locale]/join/[provider]/complete/_components/SnsJoinComplete.js` |
| Client Component (Email) | `app/[locale]/join/[provider]/complete/_components/EmailJoinComplete.js` |
| 화면설계서 | S26, S36 |

#### UI 섹션 (SNS 완료 — SnsJoinComplete)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "Join" + Home |
| 1 | Welcome 헤더 | "Welcome!" — 4.8rem font-bold, 컨페티 배경 영역 (h-[17.2rem]) |
| 2 | 축하 메시지 | 사용자명(보라색 3.2rem) + "Congratulations on joining!" |
| 3 | 코인 이미지 | img_coins.png (27.4rem x 15.2rem) |
| 4 | 선물 안내 | "10,000 coins" + "Gift has been granted" + 부가 설명(Mixed FontWeight) |
| 5 | 구분선 | 0.8rem 디바이더 |
| 6 | ID (Email) 필드 | 읽기 전용 + Change 버튼 |
| 7 | Nickname 필드 | 읽기 전용 + Change 버튼 |
| 8 | Contact Number 필드 | 읽기 전용 + 안내 문구 |
| 9 | Sign-up Method 필드 | 읽기 전용 |
| 10 | Go to Home 버튼 | 보라색 버튼, 홈으로 이동 |

#### UI 섹션 (이메일 완료 — EmailJoinComplete)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar — "Join" + Home (커스텀 className) |
| 1 | Welcome 헤더 | "Welcome!" — 4.8rem font-bold |
| 2 | 축하 메시지 | 사용자명(보라색 3.2rem) + "Congratulations on joining!" |
| 3 | 코인 이미지 | img_coins.png |
| 4 | 선물 안내 | "10,000 coins" + "Gift has been granted" + 부가 설명(Mixed FontWeight) |
| 5 | 구분선 | 0.8rem 디바이더 |
| 6 | ID (Email) 필드 | 읽기 전용 |
| 7 | Nickname 필드 | 읽기 전용 |
| 8 | Contact Number 필드 | 읽기 전용 + 안내 문구 |
| 9 | Sign-up Method 필드 | 읽기 전용, defaultValue "Join with Email" |
| 10 | Go to Home 버튼 | 보라색 버튼, 홈으로 이동 |

#### 상태 관리

- 없음. 서버에서 전달받은 데이터를 읽기 전용으로 표시하는 정적 페이지.

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | 메서드 | 용도 | 구현 상태 |
|-----------|--------|------|----------|
| 가입 완료 정보 조회 | GET/POST | 가입 완료된 사용자 정보 표시 | 미구현 (하드코딩 상태) |
| 닉네임 변경 | POST | Change 버튼으로 닉네임 수정 | 미구현 |

#### 인터랙션

| 액션 | 동작 |
|------|------|
| Go to Home 클릭 | `/{locale}`로 이동 (Link 컴포넌트) |
| Change 버튼 클릭 (SNS) | 닉네임 변경 기능 — 미구현 |
| 뒤로가기 버튼 | `router.back()` |
| Home 버튼 | `/{locale}`로 이동 |

#### 비즈니스 규칙

| 규칙 | 설명 | 화면설계서 |
|------|------|----------|
| 10,000 코인 선물 | 신규 가입 시 10,000 코인 자동 지급 | S36 |
| 닉네임 변경 가능 | SNS 완료 화면에서 닉네임 Change 버튼으로 수정 가능 | S26 |
| 연락처 안내 | "This number will be connected while Phone call service or Chat Service" 문구 표시 | S26, S36 |

#### 엣지 케이스

| 케이스 | 처리 방안 |
|--------|----------|
| 완료 페이지 직접 접근 (가입 미완료) | 미구현 — 가입 완료 상태 검증 후 리다이렉트 필요 |
| 코인 지급 실패 | 미구현 — 재시도 또는 고객센터 안내 필요 |
| 새로고침 시 데이터 유지 | 미구현 — 서버 사이드에서 가입 정보 조회 필요 |

#### i18n (SNS 완료)

| 키 | en 값 |
|----|-------|
| `joinSnsComplete.join` | Join |
| `joinSnsComplete.home` | Home |
| `joinSnsComplete.welcome` | Welcome! |
| `joinSnsComplete.giantpony` | giantpony |
| `joinSnsComplete.congratulationsOnJoining` | Congratulations on joining! |
| `joinSnsComplete.10000Coins` | 10,000 coins |
| `joinSnsComplete.giftHasBeenGranted` | Gift has been granted |
| `joinSnsComplete.tryAFreeSessionWithYourGiftCoinYouWouldFPrefix` | Try a FREE session with your gift coin (You would find the gift coin from  |
| `joinSnsComplete.tryAFreeSessionWithYourGiftCoinYouWouldFBold` | My Menu -> Coin History) |
| `joinSnsComplete.idEmail` | ID (Email) |
| `joinSnsComplete.nickname` | Nickname |
| `joinSnsComplete.nicknameUnnamed` | Nickname |
| `joinSnsComplete.thisNumberWillBeConnectedWhilePhoneCallS` | This number will be connected while Phone call service or Chat Service |
| `joinSnsComplete.signUpMethod` | Sign-up Method |
| `joinSnsComplete.goToHome` | Go to Home |

#### i18n (이메일 완료)

| 키 | en 값 |
|----|-------|
| `joinEmailComplete.join` | Join |
| `joinEmailComplete.home` | Home |
| `joinEmailComplete.welcome` | Welcome! |
| `joinEmailComplete.giantpony` | giantpony |
| `joinEmailComplete.congratulationsOnJoining` | Congratulations on joining! |
| `joinEmailComplete.10000Coins` | 10,000 coins |
| `joinEmailComplete.giftHasBeenGranted` | Gift has been granted |
| `joinEmailComplete.tryAFreeSessionWithYourGiftCoinYouWouldFPrefix` | Try a FREE session with your gift coin (You would find the gift coin from  |
| `joinEmailComplete.tryAFreeSessionWithYourGiftCoinYouWouldFBold` | My Menu -> Coin History) |
| `joinEmailComplete.idEmail` | ID (Email) |
| `joinEmailComplete.nickname` | Nickname |
| `joinEmailComplete.nicknameUnnamed` | Nickname |
| `joinEmailComplete.thisNumberWillBeConnectedWhilePhoneCallS` | This number will be connected while Phone call service or Chat Service |
| `joinEmailComplete.signUpMethod` | Sign-up Method |
| `joinEmailComplete.goToHome` | Go to Home |

#### 의존성

| 의존성 | 용도 |
|--------|------|
| `PageNavBar` | 상단 네비게이션 |
| `next/link` | Go to Home 버튼 |
| `next/image` | 코인 이미지, Change 버튼 이미지 |

---

### 3-5. 기가입 안내 화면

| 항목 | 내용 |
|------|------|
| 라우트 | 미확정 (제안: `/[locale]/join/already-member`) |
| 구현 상태 | 미구현 |
| 화면설계서 | S37~S42 |

#### 시나리오 분기

| 조건 | 화면 | 설명 |
|------|------|------|
| 이메일 + 휴대폰 둘 다 일치 | 기가입 안내 (로그인 유도) | "이미 가입된 회원입니다" + 로그인 버튼 표시 |
| 이메일 또는 휴대폰 하나만 일치 | 기가입 회원 불가 (고객센터 유도) | "확인이 필요합니다" + 고객센터 안내 |

#### 기가입 안내 — 로그인 유도 (이메일+휴대폰 둘 다 일치)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar |
| 1 | 안내 메시지 | "이미 가입된 회원입니다" 타이틀 |
| 2 | 가입 정보 표시 | ID(이메일), 가입방법 표시 |
| 3 | 로그인 버튼 | 로그인 페이지로 이동 |

#### 기가입 회원 불가 — 고객센터 유도 (하나만 일치)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar |
| 1 | 안내 메시지 | "확인이 필요합니다" 타이틀 |
| 2 | 설명 텍스트 | 고객센터 연락 안내 |
| 3 | 고객센터 버튼 | 고객센터 페이지 이동 또는 전화 연결 |

#### provider별 기가입 화면 (S38~S42)

| provider | 특이사항 |
|----------|---------|
| LINE | LINE 계정 기가입 안내 |
| Google | Google 계정 기가입 안내 |
| Apple | Apple 계정 기가입 안내 — 이메일 비공개 옵션으로 이메일 불일치 가능 |
| Email | 이메일 가입 기가입 안내 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 이메일+휴대폰 둘 다 일치 | 기존 가입 계정의 로그인 방법을 표시하고 로그인 유도 |
| 이메일 또는 휴대폰 하나만 일치 | 본인 확인이 필요하므로 고객센터 안내 |
| Apple 이메일 비공개 | Apple "이메일 숨기기" 사용 시 릴레이 이메일로 비교해야 함 |

---

### 3-6. 재가입 플로우

| 항목 | 내용 |
|------|------|
| 라우트 | 미확정 (제안: `/[locale]/join/rejoin`) |
| 구현 상태 | 미구현 |
| 화면설계서 | S43~S47 |

#### 시나리오 분기

| 조건 | 화면 | 설명 |
|------|------|------|
| 탈퇴 후 7일 이내 | 재가입 불가 | "탈퇴 후 7일간 재가입이 불가합니다" 안내 |
| 탈퇴 후 7일 경과 | 재가입 가능 | 정상 가입 프로세스 진행 (기존 데이터 초기화) |
| 탈퇴 기록 없음 | 정상 가입 | 신규 가입 프로세스 진행 |

#### 재가입 불가 화면

| # | 섹션 | 설명 |
|---|------|------|
| 0 | 상단 네비게이션 | PageNavBar |
| 1 | 안내 메시지 | "재가입이 불가합니다" 타이틀 |
| 2 | 설명 텍스트 | 탈퇴일 + "7일 후 재가입 가능합니다" |
| 3 | 재가입 가능 날짜 | 탈퇴일 + 7일 계산하여 표시 |
| 4 | 확인 버튼 | 메인 페이지로 이동 |

#### provider별 재가입 화면 (S44~S47)

| provider | 특이사항 |
|----------|---------|
| LINE | LINE 탈퇴 후 재가입 — 동일 LINE 계정으로 재가입 |
| Apple | Apple 탈퇴 후 재가입 — 이메일 비공개 옵션 재선택 가능 |
| Email | 이메일 탈퇴 후 재가입 — 동일 이메일로 재가입 |

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| 7일 재가입 금지 | 탈퇴일로부터 7일(168시간) 미경과 시 가입 차단 |
| 탈퇴일 DB 조회 | 서버에서 탈퇴 기록 조회 후 재가입 가능 여부 판단 |
| 재가입 시 데이터 초기화 | 이전 계정 데이터(코인, 구매 내역 등) 복구 불가 |
| 재가입 시 신규 코인 지급 | 재가입도 신규 가입으로 취급하여 10,000 코인 지급 여부 — 미확정 |

#### API 연동

> **⚠️ 이 섹션의 API 엔드포인트/필드명은 추정값입니다. 실제 값은 `docs/specs/API_FIELD_MAP.md` 참조.**


| 엔드포인트 | 메서드 | 용도 | 구현 상태 |
|-----------|--------|------|----------|
| 탈퇴 기록 조회 | POST | 이메일/SNS ID로 탈퇴 기록 확인 | 미구현 |
| 재가입 가능 여부 | POST | 탈퇴일 + 7일 경과 여부 반환 | 미구현 |

---

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 파일 경로 | 사용 페이지 | 타입 | 설명 |
|---------|----------|-----------|------|------|
| PageNavBar | `app/[locale]/_components/PageNavBar.js` | 전체 | Client | 보라색 상단 네비게이션 (뒤로가기 + 타이틀 + Home 버튼) |

### PageNavBar Props

| Prop | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `locale` | string | Y | - | 현재 로케일 (Home 링크 생성용) |
| `title` | string | Y | - | 네비게이션 타이틀 텍스트 |
| `homeLabel` | string | Y | - | Home 버튼 텍스트 |
| `navClassName` | string | N | `'h-[5.6rem] bg-[#6335b4] text-[#ffffff] flex justify-between items-center px-[1.6rem]'` | nav 태그 className 오버라이드 |
| `homeLinkClassName` | string | N | `'border border-[#ffffff] rounded-[99.9rem] flex justify-center items-center py-[0.7rem] px-[1.2rem] text-[1.2rem] font-bold leading-[1.2rem]'` | Home Link className 오버라이드 |

---

## 5. 크로스 도메인 의존성

| 의존 도메인 | 의존 방향 | 설명 |
|-----------|----------|------|
| login | join → login | 기가입 안내에서 로그인 페이지로 이동 |
| login | login → join | 로그인 페이지의 "Join" 링크에서 가입 방법 선택으로 이동 |
| intro | join → intro | 가입 완료 후 Home(메인)으로 이동 |
| find-account | join ← find-account | 계정 찾기에서 가입 안내 가능 |
| 이용약관 (terms) | join → terms | 약관 동의 항목에서 전문 페이지 이동 (미구현) |
| 개인정보처리방침 (privacy) | join → privacy | 약관 동의 항목에서 전문 페이지 이동 (미구현) |

---

## 6. 미확정 사항 (v1.1 — 2026-04-17 as-built 기준 정리)

> 분류: **유형 A** = as-built 구현 완료 (스펙 갱신 완료) / **유형 B** = 감사 권고 미반영 / **유형 C** = 추가 구현 필요 / **유형 D** = 정책·디자인 확정 필요

| # | 우선순위 | 유형 | 항목 | 설명 | 근거/결정 필요 시점 |
|---|---------|------|------|------|--------------------|
| 1 | **[MUST]** | C | 로케일별 방법 구성 | EN: Email+Apple+Google, JP: Email+LINE+Apple+Google. as-built는 3개 버튼 고정 — hostname 분기 적용 필요 | `app/[locale]/join/page.js` 분기 로직 |
| 2 | **[CRITICAL]** | B | reCAPTCHA Enterprise 백엔드 검증 | 프론트는 `captchaToken` 발급만 하고 `secureFetch` body에 미포함. 백엔드 `createAssessment` 호출 + 점수 검증 미연동 | 감사: `2026-04-16-recaptcha-signup-flow-us-jp-requirement.md` |
| 3 | **[MUST]** | C | 이메일 소유 검증(send/confirm-mail-cert) | EmailJoinForm에 OTP 입력 영역 + 타이머 + 재발송 미구현. join-user body에 `crMailCert` 미주입 | as-is 기능 누락 — 스팸/봇 방어 필수 |
| 4 | **[MUST]** | D | 가입완료 화면 노출 정책 | as-built는 직홈. 화면설계서 S26/S36 Welcome 화면 + 10,000 코인 안내 노출 시점/방식 재정의 — (a)홈 토스트, (b)welcome 인터스티셜, (c)마이페이지 안내 | 디자인+기획 확정 |
| 5 | **[MUST]** | D | SNS Email/Nickname readOnly 정책 | 화면설계서는 readOnly, as-built는 controlled. UX/보안 의사결정 필요 | 디자인+기획 확정 |
| 6 | **[SHOULD]** | D | 기가입 안내 라우트 | `/join/already-member` 또는 모달 방식 — as-built 미구현 | 디자인 확정 |
| 7 | **[SHOULD]** | D | 재가입 플로우 라우트 | `/join/rejoin` 또는 가입폼 내 인라인 처리 — as-built 미구현 | 디자인 확정 |
| 8 | **[MUST]** | C | 국가 선택 바텀시트 | `PhoneCertField` 내부 국가 선택기 미구현 (현재 `'US'` 기본값) — 국가 코드 리스트 + 검색 + 전화번호 국번 | 디자인 확정 |
| 9 | **[MUST]** | C | 약관 전문 콘텐츠 소스 | 현재 `lib/mock/termsContent.js` 하드코딩 — CMS/i18n 키/원문 PDF 등 정식 소스 결정 | 법무 검토 |
| 10 | **[SHOULD]** | C | Apple 이메일 비공개 처리 | 릴레이 이메일(`xxx@privaterelay.appleid.com`) 매핑 로직 미구현 | 백엔드 정책 확정 |
| 11 | **[SHOULD]** | C | 미성년자 판별 기준 | DOB 입력 시 만 19세 미만 차단 미구현. 만 나이 기준(KR법) vs 로케일별 상이 | 비즈니스 정책 |
| 12 | **[MUST]** | A | reCAPTCHA Site Key | `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` 환경변수 — 운영/개발 키 분리 후 인프라 주입 | 인프라 세팅 시 |
| 13 | **[MUST]** | A | SNS OAuth 콜백 처리 | Google/Apple/LINE 콜백 라우트 + 토큰 교환 + 자동로그인 분기 — 커밋 `b168d51`로 구현 완료 | as-built |
| 14 | **[MUST]** | A | 비밀번호/닉네임/이메일 유효성 | `lib/validators/joinEmail.js` Pure function로 구현 완료 (length/pattern/agreement) | as-built |
| 15 | **[MUST]** | A | SMS OTP 발송/검증 API | `send-global-cert`/`confirm-global-cert` 프록시 라우트 + `PhoneCertField` 통합 — 구현 완료 | as-built |
| 16 | **[MUST]** | A | join-user 성공 후 인증 상태 전환 | 백엔드가 `hc_access`/`hc_refresh`/`hc_csrf` 쿠키 자동 발급 → 프론트는 `setAuth(true, data)`로 플래그만 저장 | as-built (커밋 `58152a1` CSRF Signed Double Submit) |
| 17 | **[COULD]** | C | 이용약관/개인정보 전문 라우트 | 모달이 기본. 별도 페이지(`/terms`, `/privacy`) 분리 필요 시 결정 | 디자인 확정 |
| 18 | **[WONT]** | D | 재가입 시 코인 지급 여부 | 현재 스프린트 미구현 | 비즈니스 정책 |

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | 화면설계서 PPTX 기반 최초 작성 | 명우현 |
| v1.1 | 2026-04-17 | as-built 코드 + 감사 문서(2026-04-16) 역반영. 유형 A/B/C/D 분류 도입. SNS 가입폼 OAuth prefill·controlled input 명시, 이메일 OTP 인증 영역(유형 C) 신설, 가입완료 화면 dead-route 표기, captchaToken 백엔드 검증 미반영 표기, PhoneCertField/AgreementGroup/TermsFullModal/ReCaptchaEnterprise 등 as-built 의존성 명시 | 명우현 |
| 14 | **[COULD]** | joinSnsComplete / joinEmailComplete 네임스페이스 통합 | 두 네임스페이스의 키가 거의 동일 — 통합 가능 여부 | 리팩토링 시 |
