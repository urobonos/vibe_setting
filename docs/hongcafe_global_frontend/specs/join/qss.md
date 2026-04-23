# QA Scenario Sheet — 회원가입
> Source: ffs.md v1.1 + as-built 코드(`SnsJoinForm.js`/`EmailJoinForm.js`/`PhoneCertField.js`/`TermsFullModal.js`/`AgreementGroup.js`) + 감사 문서(2026-04-16)
> Status: Draft (v1.1)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390 x 844 (iPhone 14 기준) |
| 브라우저 | Chrome, Safari (모바일 에뮬레이션) |
| 로케일/호스트 | EN: `http://en.localhost:3000/join` / JP: `http://jp.localhost:3000/join` (hostname 기반 i18n, URL prefix 없음) |
| 테스트 도구 | Playwright + Vitest 단위 테스트 (`__tests__/`) |
| 빌드 검증 | `npm run build` 성공 필수 + `npm run test` PASS |
| 단위 테스트 게이트 | `lib/validators/joinEmail.js`, `lib/fetchWithAuth.js`, `lib/csrf.js` (커밋 `58152a1`) |
| 보안 검증 | CSRF Signed Double Submit 토큰(`hc_csrf_meta` 우선, `hc_csrf` fallback) 자동 첨부 + `escapeHtml(data.msg)` XSS 방어 |

---

## 2. 방법 선택 화면 (`/[locale]/join`)

### 2-1. 렌더링 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| R-01 | 페이지 정상 로딩 | 없음 | `/en/join` 접근 | HTTP 200, 페이지 정상 렌더링 | P0 |
| R-02 | 상단 네비게이션 렌더링 | 없음 | 페이지 로딩 완료 | 보라색(#6335b4) NavBar에 뒤로가기 아이콘 + "Sign in" + "Home" 버튼 표시 | P0 |
| R-03 | 페이지 타이틀 렌더링 | 없음 | 페이지 로딩 완료 | "Select Joining method" 텍스트가 중앙 정렬, font-bold, 2.4rem으로 표시 | P0 |
| R-04 | Google 버튼 렌더링 | 없음 | 페이지 로딩 완료 | "Sign in with **Google**" 텍스트 + Google 아이콘(icon_google.svg) 표시, Mixed FontWeight(normal+bold) | P0 |
| R-05 | Apple 버튼 렌더링 | 없음 | 페이지 로딩 완료 | "Sign in with **Apple**" 텍스트 + Apple 아이콘(icon_apple.svg) 표시, Mixed FontWeight(normal+bold) | P0 |
| R-06 | Email 버튼 렌더링 | 없음 | 페이지 로딩 완료 | "Join with **Email**" 텍스트 + Email 아이콘(icon_email.svg) 표시, Mixed FontWeight(normal+bold) | P0 |
| R-07 | 버튼 스타일 | 없음 | 버튼 요소 검사 | 각 버튼: h-[4.8rem], border border-[#dddddd], rounded-[0.6rem], 좌우 정렬(텍스트 왼쪽, 아이콘 오른쪽) | P1 |
| R-08 | 버튼 순서 | 없음 | 페이지 로딩 완료 | 위에서 아래로: Google → Apple → Email 순서 | P0 |
| R-09 | 메타데이터 title | 없음 | `document.title` 확인 | "Select Joining method — Hong Cafe" | P1 |

### 2-2. i18n 테스트 (hostname 기반)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| I-01 | EN 호스트 | 없음 | `en.hongcafe.com/join` 접근 | 모든 텍스트가 영어, URL에 locale prefix 없음 | P0 |
| I-02 | JP 호스트 | 없음 | `jp.hongcafe.com/join` 접근 | 모든 텍스트가 일본어, URL에 locale prefix 없음 | P0 |
| I-03 | KR 호스트 | 없음 | `hongcafe.com/join` 접근 | 기존 홍카페K 라우팅 (본 프로젝트 범위 밖) | P2 |
| I-04 | 잘못된 호스트 | 없음 | `xx.hongcafe.com/join` 접근 | proxy.js GeoIP fallback → en 라우팅 | P1 |

### 2-3. 인터랙션 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| A-01 | Google 버튼 클릭 | 페이지 로딩 완료 | Google 버튼 클릭 | `/en/join/google`로 이동 | P0 |
| A-02 | Apple 버튼 클릭 | 페이지 로딩 완료 | Apple 버튼 클릭 | `/en/join/apple`로 이동 | P0 |
| A-03 | Email 버튼 클릭 | 페이지 로딩 완료 | Email 버튼 클릭 | `/en/join/email`로 이동 | P0 |
| A-04 | 뒤로가기 버튼 | 로그인 페이지에서 진입 | NavBar 뒤로가기 클릭 | 이전 페이지(로그인)로 이동 | P1 |
| A-05 | Home 버튼 | 페이지 로딩 완료 | NavBar Home 클릭 | `/en`(메인)으로 이동 | P1 |

### 2-4. 접근성 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AC-01 | 이미지 alt 속성 | 없음 | 모든 Image 요소 검사 | Google/Apple/Email 아이콘에 의미 있는 alt 텍스트 존재 | P1 |
| AC-02 | Link 접근성 | 없음 | 버튼 요소 검사 | 모든 방법 버튼이 Link 컴포넌트로 구현, href 속성 존재 | P1 |
| AC-03 | main 랜드마크 | 없음 | DOM 구조 검사 | `<main>` 태그로 페이지 콘텐츠 래핑 | P2 |

---

## 3. SNS 가입폼 (`/[locale]/join/apple`, `/[locale]/join/google`)

### 3-1. 렌더링 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SR-01 | Apple 가입폼 정상 로딩 | 없음 | `/en/join/apple` 접근 | HTTP 200, 페이지 정상 렌더링 | P0 |
| SR-02 | Google 가입폼 정상 로딩 | 없음 | `/en/join/google` 접근 | HTTP 200, 페이지 정상 렌더링 | P0 |
| SR-03 | NavBar 렌더링 | 없음 | 페이지 로딩 완료 | "Join" 타이틀 + "Home" 버튼 표시 | P0 |
| SR-04 | provider 아이콘 | Apple 가입폼 | 아이콘 확인 | Apple 로고(icon_apple.svg) 표시, w-[4.3rem] h-[4.3rem] | P0 |
| SR-05 | provider 아이콘 | Google 가입폼 | 아이콘 확인 | Google 로고(icon_google.svg) 표시, w-[4.3rem] h-[4.3rem] | P0 |
| SR-06 | 페이지 타이틀 | Apple 가입폼 | 타이틀 확인 | "Join with Apple account" — text-center, font-bold, 2.4rem | P0 |
| SR-07 | ID(Email) 필드 | OAuth 콜백 진입 (prefill 있음) | 필드 확인 | label "ID (Email)" 보라색(#6335b4) + **controlled input(수정 가능, as-built)** + value=`prefill.email` | P0 |
| SR-08 | Email 직접 진입 (prefill 없음) | `/join/google` 직접 URL | input value 확인 | 빈 값 — `prefill?.email || ''` (정상 플로우 아님 — OAuth 콜백 경유 강제 권고) | P2 |
| SR-09 | Nickname 필드 | OAuth 콜백 진입 (prefill 있음) | 필드 확인 | label "Nickname" 보라색 + **controlled input(수정 가능, as-built)** + value=`prefill.nickname` | P0 |
| SR-10 | Apple 닉네임 미제공 | Apple OAuth 콜백 (prefill.nickname 없음) | input value 확인 | 빈 값 — 사용자 입력 필수 | P0 |
| SR-11 | Date of Birth 필드 | 없음 | 필드 확인 | label "Date of Birth" + Year/Month/Date 3개 select + Chevron 아이콘 | P0 |
| SR-12 | Year select 옵션 | 없음 | Year 드롭다운 열기 | 2010~1950 범위 옵션 표시 | P1 |
| SR-13 | Month select 옵션 | 없음 | Month 드롭다운 열기 | 01~12 옵션 표시 | P1 |
| SR-14 | Date select 옵션 | 없음 | Date 드롭다운 열기 | 01~31 옵션 표시 | P1 |
| SR-15 | Mobile Number 필드 | 없음 | 필드 확인 | `PhoneCertField` 통합 컴포넌트 — Globe 아이콘 + 국가코드(`mobileCountry`, 기본 `'US'`) + Chevron + 숫자 input + "인증받기" 버튼 | P0 |
| SR-16 | Mobile 기본 국가 | 없음 | 텍스트 확인 | hostname 기반 기본값 (EN→US, JP→JP) — as-built는 모두 `'US'` 기본 (유형 C 개선 필요) | P1 |
| SR-17 | reCAPTCHA Enterprise 위젯 | `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` 설정 | 영역 확인 | `<ReCaptchaEnterprise action="signup_sns" />` 위젯 렌더 + 토큰 발급 후 `captchaToken` 갱신 | P0 |
| SR-17b | reCAPTCHA env 미설정 | `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` 미설정 | 영역 확인 | 위젯 미렌더 + placeholder/생략 (env 방어, §22-4-B) | P1 |
| SR-18 | 구분선 | 없음 | 디바이더 확인 | h-[0.8rem] bg-[#f5f5f5] 디바이더 표시 | P2 |
| SR-19 | 약관 동의 영역 | 없음 | 영역 확인 | `<AgreementGroup>` 컴포넌트 — 전체 동의(f5f5f5 배경, font-bold) + 3개 하위 항목(19세/이용약관/개인정보) | P0 |
| SR-20 | 이용약관 텍스트 | 없음 | 텍스트 확인 | "Terms of Service (Required)" underline 세그먼트 분리 (§22-56) — 클릭 시 `TermsFullModal` 오픈 | P1 |
| SR-21 | 개인정보 텍스트 | 없음 | 텍스트 확인 | "Privacy Policy (Required)" underline 세그먼트 — 클릭 시 `TermsFullModal` 오픈 | P1 |
| SR-21b | TermsFullModal 콘텐츠 | 약관 텍스트 클릭 후 | 모달 콘텐츠 확인 | `lib/mock/termsContent.js`의 termsService/privacyPolicy 본문 표시 + 닫기(X) + 배경 클릭 닫기 (§22-40) | P1 |
| SR-22 | Sign Up 버튼 초기 상태 | 약관 미동의 + 휴대폰 미인증 + captcha 없음 | 버튼 색상 확인 | 회색(#dddddd) 비활성 상태 (`disabled` 속성) | P0 |
| SR-23 | 입력 필드 테두리 색상 | 없음 | 모든 input 영역 확인 | border-b border-[#6335b4] (보라색) | P0 |
| SR-24 | label 스타일 | 없음 | 모든 label 확인 | text-[1.4rem] font-bold text-[#6335b4] | P1 |

### 3-1B. SNS provider 다양성 (as-built 6종)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SR-25 | Google 진입 | 없음 | `/join/google` | `icon_google.svg` + "Join with Google account" 타이틀 | P0 |
| SR-26 | Apple 진입 | 없음 | `/join/apple` | `icon_apple.svg` + "Join with Apple account" 타이틀 | P0 |
| SR-27 | LINE 진입 (JP only) | 없음 | `/join/line` | `icon_line.svg` + "Join with LINE account" 타이틀 | P0 |
| SR-28 | Kakao 진입 (KR 외 제외) | 없음 | `/join/kakao` | EN/JP 호스트에서는 404 (generateStaticParams 제한) | P1 |
| SR-29 | Naver 진입 (KR 외 제외) | 없음 | `/join/naver` | EN/JP 호스트에서는 404 | P1 |
| SR-30 | Facebook 진입 | 없음 | `/join/facebook` | `icon_facebook.svg` + "Join with Facebook account" 타이틀 | P1 |

### 3-2. i18n 테스트 (hostname 기반)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SI-01 | EN 호스트 | 없음 | `en.hongcafe.com/join/apple` | joinSns 네임스페이스 영어 텍스트 | P0 |
| SI-02 | JP 호스트 | 없음 | `jp.hongcafe.com/join/line` | joinSns 네임스페이스 일본어 텍스트 | P0 |
| SI-03 | KR 호스트 | 없음 | `hongcafe.com/join/kakao` | 본 프로젝트 범위 밖 — 기존 홍카페K | P2 |

### 3-3. 인터랙션 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SA-01 | 전체 동의 체크 | 모든 항목 미체크 | "I agree to all of the followings" 클릭 | 3개 하위 항목 모두 체크됨 + 전체 동의 체크됨 | P0 |
| SA-02 | 전체 동의 해제 | 모든 항목 체크 | "I agree to all of the followings" 재클릭 | 3개 하위 항목 모두 해제 + 전체 동의 해제 | P0 |
| SA-03 | 개별 항목 체크 — 19세 | 미체크 | "I am 19 years of age or older" 클릭 | 19세 항목만 체크 | P0 |
| SA-04 | 개별 항목 체크 — 이용약관 | 미체크 | "Terms of Service" 클릭 | 이용약관 항목만 체크 | P0 |
| SA-05 | 개별 항목 체크 — 개인정보 | 미체크 | "Privacy Policy" 클릭 | 개인정보 항목만 체크 | P0 |
| SA-06 | 개별 3개 모두 체크 시 전체 동의 자동 체크 | 2개 체크, 1개 미체크 | 마지막 1개 체크 | 전체 동의 자동 체크됨 | P0 |
| SA-07 | 전체 동의 후 1개 해제 시 전체 동의 해제 | 전체 동의 상태 | 하위 1개 해제 | 전체 동의 해제, 나머지 2개는 체크 유지 | P0 |
| SA-08 | Sign Up 버튼 활성화 | DOB+Phone인증+Captcha+전체동의 모두 충족 | 버튼 색상 확인 | 보라색(#6335b4) 활성 상태 (`disabled` false) | P0 |
| SA-09 | Sign Up 클릭 — 정상 가입 | 모든 필드 통과 | Sign Up 버튼 클릭 | `secureFetch('/api/members/join-user', POST)` 호출 → 응답 성공 → `setAuth(true, data.data)` → **`router.push('/')` 홈 직행** (`/join/{provider}/complete` 미경유) | P0 |
| SA-09b | join-user body 필드 검증 | network 캡처 | Sign Up 버튼 클릭 | body에 `{ acId, acNick, crPhone, snsType, acSnsId, agreeService:1, agreePrivacy:1, agreeAge:1, acCountry, birthYear, birthMonth, birthDay, crMailCert:'Y' }` 포함 | P0 |
| SA-09c | join-user 실패 응답 | API mock으로 실패 응답 | Sign Up 버튼 클릭 | `submitError`에 `escapeHtml(data.msg)` 표시 (XSS 방어) + 홈 이동 차단 + `isSubmitting=false` | P0 |
| SA-09d | 중복 제출 방지 | 정상 가입 후 빠른 재클릭 | Sign Up 두 번 클릭 | 첫 호출만 처리 (`isSubmitting` 가드) | P1 |
| SA-09e | reCAPTCHA 검증 (감사 권고 — 미구현) | network 캡처 | Sign Up 버튼 클릭 | body에 `captchaToken` 포함되어야 함 — **현재 누락 (유형 B CRITICAL)** | P0 |
| SA-09f | OAuth 자동로그인 분기 | OAuth 콜백 응답 `exist_flag=4` | OAuth 콜백 진입 | `tryAutoLogin` 호출 → 성공 시 SnsJoinForm 미진입, `/` 홈 직행 (커밋 `b168d51`) | P0 |
| SA-10 | Sign Up 클릭 — 미동의 | agreeAll 미체크 | Sign Up 버튼 클릭 | `agreementError` 표시 + return early | P0 |
| SA-10b | Sign Up 클릭 — 휴대폰 미인증 | 휴대폰만 입력, OTP 미검증 | Sign Up 버튼 클릭 | `mobileError` "verifyFirst" 표시 + return early | P0 |
| SA-10c | Sign Up 클릭 — captcha 없음 | reCAPTCHA 토큰 미발급 | Sign Up 버튼 클릭 | `captchaError` "errCaptchaRequired" 표시 + return early | P0 |
| SA-11 | 생년월일 Year 선택 | 없음 | Year 드롭다운에서 "1998" 선택 | dobYear 상태 "1998"로 업데이트 | P1 |
| SA-12 | 생년월일 Month 선택 | 없음 | Month 드롭다운에서 "04" 선택 | dobMonth 상태 "04"로 업데이트 | P1 |
| SA-13 | 생년월일 Date 선택 | 없음 | Date 드롭다운에서 "22" 선택 | dobDate 상태 "22"로 업데이트 | P1 |
| SA-14 | 뒤로가기 버튼 | 방법 선택에서 진입 | NavBar 뒤로가기 클릭 | `/join`으로 이동 | P1 |
| SA-15 | Home 버튼 | 없음 | NavBar Home 클릭 | `/`으로 이동 | P1 |
| SA-16 | PhoneCertField 발송 | 휴대폰 입력 후 "인증받기" 클릭 | network 캡처 | `secureFetch('/api/members/send-global-cert', POST)` body=`{ acCountry:'US', acPhoneNo:cleanedPhone }` → success 시 OTP 입력 영역 노출 + 타이머 시작 | P0 |
| SA-17 | PhoneCertField 검증 | OTP 입력 후 "확인" 클릭 | network 캡처 | `secureFetch('/api/members/confirm-global-cert', POST)` body=`{ acCountry, acPhoneNo, acCertNum }` → success 시 `isPhoneVerified=true` | P0 |
| SA-18 | PhoneCertField 발송 실패 메시지 | 백엔드 fail 응답 | "인증받기" 클릭 | `escapeHtml(data.msg)` 메시지 표시 (XSS 방어) — `<script>` 등 태그 escape | P0 |
| SA-19 | TermsFullModal 배경 클릭 닫기 | 모달 오픈 | 모달 외부(backdrop) 클릭 | 모달 닫힘 (§22-40 — `onClick={(e)=>e.stopPropagation()}` 내부 dialog) | P1 |
| SA-20 | TermsFullModal Escape 키 | 모달 오픈 | Escape 키 입력 | 모달 닫힘 (권장) | P2 |

### 3-4. 접근성 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SAC-01 | 체크박스 native input | 없음 | 체크박스 검사 | `<input type="checkbox">` + sr-only + 조건부 아이콘 (V4.9 §22-22) | P1 |
| SAC-02 | 아이콘 alt 속성 | 없음 | 모든 Image 검사 | Globe, Clear, Chevron 아이콘에 의미 있는 alt 또는 빈 alt(장식) | P1 |
| SAC-03 | input controlled | 없음 | Email/Nickname input 검사 | **as-built는 readOnly 미적용**, controlled로 사용자 수정 가능 — 화면설계서와 차이 | P1 |
| SAC-04 | select 키보드 접근 | 없음 | Tab 키로 select 포커스 | Year/Month/Date select에 키보드 접근 가능 | P2 |
| SAC-05 | form method="post" 기본동작 | 없음 | form 요소 검사 | `<form method="post">` (V4.9 §22-24 — GET fallback 방지) | P2 |

---

## 4. 이메일 가입폼 (`/[locale]/join/email`)

### 4-1. 렌더링 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| ER-01 | 페이지 정상 로딩 | 없음 | `/en/join/email` 접근 | HTTP 200, 페이지 정상 렌더링 | P0 |
| ER-02 | NavBar 렌더링 | 없음 | 페이지 로딩 완료 | "Join" 타이틀 + "Home" 버튼, 보라색 배경 | P0 |
| ER-03 | 배너 렌더링 | 없음 | 배너 영역 확인 | 노란 배경(#ffdb4a), "10,000 Gift coin for a New Member" 텍스트 (보라색 #6335b4, font-bold) | P0 |
| ER-04 | 페이지 타이틀 | 없음 | 타이틀 확인 | "Join with Email" — text-center, font-bold, 2.4rem | P0 |
| ER-05 | ID(Email) 필드 + 인증받기 버튼 (유형 C — 미구현) | 없음 | 필드 확인 | label "ID (Email)" + input placeholder "Please enter your ID (email)" + Clear 아이콘 + **"인증받기" 버튼 (현재 미구현, send-mail-cert 트리거)** | P0 |
| ER-05b | 이메일 OTP 입력 영역 (유형 C — 미구현) | "인증받기" 클릭 후 | 필드 확인 | OTP 입력란 + 3분 타이머(`mailCertTimer`) + 재발송 버튼 + 확인 버튼 노출 | P0 |
| ER-06 | Password 필드 | 없음 | 필드 확인 | label "Password" + input placeholder "Password (6 to 12 characters)" + Eye 아이콘 | P0 |
| ER-07 | Confirm Password 필드 | 없음 | 필드 확인 | label "Confirm Password" + input placeholder "Retype Password" + Eye 아이콘 | P0 |
| ER-08 | Nickname 필드 | 없음 | 필드 확인 | label "Nickname" + input placeholder "Nickname (6 to 12 characters)" + Clear 아이콘 | P0 |
| ER-09 | Date of Birth 필드 | 없음 | 필드 확인 | label "Date of Birth" + Year/Month/Day 3개 select | P0 |
| ER-10 | Year select 옵션 | 없음 | Year 드롭다운 열기 | 최근 100년 범위 옵션 표시 | P1 |
| ER-11 | Month select 옵션 | 없음 | Month 드롭다운 열기 | 01~12 옵션 표시 | P1 |
| ER-12 | Day select 옵션 | 없음 | Day 드롭다운 열기 | 01~31 옵션 표시 | P1 |
| ER-13 | Mobile Number 필드 | 없음 | 필드 확인 | `PhoneCertField` 통합 컴포넌트 (Globe + 국가코드 + Chevron + input + 인증받기/OTP 입력) | P0 |
| ER-14 | reCAPTCHA Enterprise 위젯 | env 설정 | 영역 확인 | `<ReCaptchaEnterprise action="signup_email" />` 위젯 렌더 + `captchaToken` 갱신 | P0 |
| ER-14b | reCAPTCHA env 미설정 | env 미설정 | 영역 확인 | 위젯 미렌더 (env 방어, §22-4-B) | P1 |
| ER-15 | 구분선 | 없음 | 디바이더 확인 | h-[0.8rem] bg-[#f5f5f5] 디바이더 | P2 |
| ER-16 | 약관 동의 영역 | 없음 | 영역 확인 | `<AgreementGroup>` 전체 동의 + 3개 하위 항목 (이용약관/개인정보/19세) | P0 |
| ER-17 | Sign Up 버튼 초기 | 없음 | 버튼 확인 | 회색(#dddddd) 비활성 상태, "Sign Up" 텍스트, `disabled` 속성 | P0 |
| ER-18 | 필드 순서 (유형 C 적용 후) | 없음 | 위→아래 순서 확인 | NavBar → 배너 → 타이틀 → Email+인증받기 → **OTP 영역(발송 후)** → Password → Confirm → Nickname → DOB → Mobile(PhoneCertField) → reCAPTCHA → 구분선 → 약관 → 버튼 | P0 |
| ER-19 | 입력 필드 테두리 | 없음 | 모든 input 영역 확인 | border-b border-[#6335b4] (보라색) | P0 |
| ER-20 | label 스타일 통일 | 없음 | 모든 label 확인 | text-[1.4rem] font-bold text-[#6335b4] leading-[1.4rem] | P1 |
| ER-21 | 비밀번호 입력 기본 상태 | 없음 | Password input type 확인 | `type="password"` (마스킹 상태) | P0 |
| ER-22 | 메타데이터 title | 없음 | `document.title` 확인 | "Join with Email — Hong Cafe" | P1 |

### 4-2. i18n 테스트 (hostname 기반)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| EI-01 | EN 호스트 | 없음 | `en.hongcafe.com/join/email` | joinEmail 네임스페이스 영어 텍스트 | P0 |
| EI-02 | JP 호스트 | 없음 | `jp.hongcafe.com/join/email` | joinEmail 네임스페이스 일본어 텍스트 | P0 |
| EI-03 | KR 호스트 | 없음 | `hongcafe.com/join/email` | 본 프로젝트 범위 밖 (홍카페K) | P2 |

### 4-3. 인터랙션 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| EA-01 | 이메일 입력 | 없음 | Email input에 "test@example.com" 입력 | input value 실시간 업데이트, placeholder 소멸 | P0 |
| EA-02 | 비밀번호 입력 | 없음 | Password input에 "Abc123!" 입력 | 마스킹(***) 상태로 표시, value 업데이트 | P0 |
| EA-03 | 비밀번호 표시 토글 | 비밀번호 입력 완료 | Eye 아이콘 클릭 | input type "text"로 변경, 비밀번호 평문 표시 | P0 |
| EA-04 | 비밀번호 숨김 토글 | 비밀번호 표시 상태 | Eye 아이콘 재클릭 | input type "password"로 복원, 마스킹 표시 | P0 |
| EA-05 | 비밀번호 확인 입력 | 없음 | Confirm Password input에 "Abc123!" 입력 | 마스킹 상태로 표시 | P0 |
| EA-06 | 비밀번호 확인 표시 토글 | 확인 비밀번호 입력 완료 | Eye 아이콘 클릭 | 평문 표시 | P1 |
| EA-07 | 닉네임 입력 | 없음 | Nickname input에 "testuser" 입력 | input value 실시간 업데이트 | P0 |
| EA-08 | 생년월일 선택 | 없음 | Year "1998", Month "04", Day "22" 선택 | 각 select value 업데이트 | P1 |
| EA-09 | 전체 동의 체크 | 모든 항목 미체크 | 전체 동의 버튼 클릭 | 3개 하위 항목 모두 체크 | P0 |
| EA-10 | 전체 동의 해제 | 모든 항목 체크 | 전체 동의 버튼 재클릭 | 3개 하위 항목 모두 해제 | P0 |
| EA-11 | 개별 3개 체크 시 전체 동의 자동 | 2개 체크 상태 | 마지막 1개 체크 | 전체 동의 자동 체크 | P0 |
| EA-12 | form submit (정상) | 모든 필드 입력 + 휴대폰 인증 + reCAPTCHA + 전체 동의 | Sign Up 버튼 클릭 | `validateAll` 통과 → `secureFetch('/api/members/join-user', POST)` → 성공 시 `setAuth(true, data.data)` → **`router.push('/')` 홈 직행** | P0 |
| EA-12b | join-user body 필드 | network 캡처 | Sign Up 클릭 | body=`{ acId, acNick, crPhone, acPassword, acPasswordRe, agreeService:1, agreePrivacy:1, agreeAge:1, acCountry, birthYear, birthMonth, birthDay }` (현재 `crMailCert` 미포함 — **유형 C 적용 시 추가**) | P0 |
| EA-12c | join-user 실패 응답 처리 | mock 실패 응답 | Sign Up 클릭 | `submitError`에 `escapeHtml(data.msg)` 표시 + 홈 이동 차단 + `isSubmitting=false` | P0 |
| EA-12d | reCAPTCHA 토큰 백엔드 검증 (감사 권고 — 미구현) | network 캡처 | Sign Up 클릭 | body에 `captchaToken` 포함되어야 함 — **현재 누락 (유형 B CRITICAL)** | P0 |
| EA-12e | 이메일 OTP 발송 (유형 C — 미구현) | 이메일 입력 후 "인증받기" 클릭 | network 캡처 | `secureFetch('/api/members/send-mail-cert', POST)` body=`{ acId }` → success 시 `mailCertSent=true` + 3분 타이머 + OTP 입력 영역 노출 | P0 |
| EA-12f | 이메일 OTP 검증 (유형 C — 미구현) | OTP 입력 후 "확인" 클릭 | network 캡처 | `secureFetch('/api/members/confirm-mail-cert', POST)` body=`{ acId, mailCertNo }` → 응답 `{ certMailAddress, crMailCert:'Y' }` → `mailCertVerified=true` | P0 |
| EA-12g | OTP 타이머 만료 후 재발송 (유형 C — 미구현) | 타이머 0초 도달 | "재발송" 클릭 | send-mail-cert 재호출 (rate limit 3회/60초 — `route.js`) | P1 |
| EA-12h | OTP 미검증 상태로 Sign Up (유형 C — 미구현) | mailCertVerified=false | Sign Up 클릭 | 이메일 OTP 미검증 에러 표시 + return early | P0 |
| EA-12i | send-mail-cert rate limit (유형 C — 미구현) | 60초 내 4회 호출 | 4번째 "인증받기" 클릭 | 429 응답 + 사용자 안내 ("잠시 후 다시 시도하세요") | P1 |
| EA-13 | 뒤로가기 | 방법 선택에서 진입 | NavBar 뒤로가기 클릭 | 이전 페이지로 이동 | P1 |
| EA-14 | Home 버튼 | 없음 | NavBar Home 클릭 | `/`로 이동 | P1 |

### 4-4. 유효성검사 테스트 (S32 기반)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| EV-01 | 이메일 미입력 | Email 빈 상태 | Sign Up 클릭 | emailError 표시: 이메일 미입력 에러 메시지 | P0 |
| EV-02 | 이메일 형식 오류 | Email = "notanemail" | Sign Up 클릭 또는 blur | emailError 표시: 형식 오류 에러 메시지 | P0 |
| EV-03 | 이메일 중복 | Email = 기가입 이메일 | Sign Up 클릭 → API 응답 | emailError 표시: 중복 에러 메시지 | P0 |
| EV-04 | 이메일 정상 | Email = "new@example.com" | blur 또는 Sign Up | emailError 없음 | P0 |
| EV-05 | 비밀번호 미입력 | Password 빈 상태 | Sign Up 클릭 | passwordError 표시: 비밀번호 미입력 에러 | P0 |
| EV-06 | 비밀번호 5자 (길이 미달) | Password = "Abc1!" | Sign Up 클릭 | passwordError 표시: 6~16자 미달 에러 | P0 |
| EV-07 | 비밀번호 17자 (길이 초과) | Password = "Abcdefgh12345!@#$" | Sign Up 클릭 | passwordError 표시: 6~16자 초과 에러 | P0 |
| EV-08 | 비밀번호 숫자만 | Password = "123456" | Sign Up 클릭 | passwordError 표시: 영문+숫자+특수문자 조합 미달 에러 | P0 |
| EV-09 | 비밀번호 영문만 | Password = "abcdef" | Sign Up 클릭 | passwordError 표시: 조합 미달 에러 | P0 |
| EV-10 | 비밀번호 영문+숫자 (특수문자 없음) | Password = "Abc123" | Sign Up 클릭 | passwordError 표시: 조합 미달 에러 | P0 |
| EV-11 | 비밀번호 정상 | Password = "Abc123!" | Sign Up 클릭 | passwordError 없음 | P0 |
| EV-12 | 비밀번호 확인 불일치 | Password = "Abc123!", Confirm = "Abc456!" | Sign Up 클릭 | confirmPasswordError 표시: 불일치 에러 | P0 |
| EV-13 | 비밀번호 확인 일치 | Password = "Abc123!", Confirm = "Abc123!" | Sign Up 클릭 | confirmPasswordError 없음 | P0 |
| EV-14 | 닉네임 미입력 | Nickname 빈 상태 | Sign Up 클릭 | nicknameError 표시: 닉네임 미입력 에러 | P0 |
| EV-15 | 닉네임 1자 (길이 미달) | Nickname = "A" | Sign Up 클릭 | nicknameError 표시: 2~12자 미달 에러 | P0 |
| EV-16 | 닉네임 13자 (길이 초과) | Nickname = "ABCDEFGHIJKLM" | Sign Up 클릭 | nicknameError 표시: 2~12자 초과 에러 | P0 |
| EV-17 | 닉네임 특수문자 포함 | Nickname = "test@user" | Sign Up 클릭 | nicknameError 표시: 한글/영문/숫자만 가능 에러 | P0 |
| EV-18 | 닉네임 중복 | Nickname = 기존 닉네임 | Sign Up 클릭 → API 응답 | nicknameError 표시: 중복 에러 | P0 |
| EV-19 | 닉네임 정상 (영문) | Nickname = "testuser" | Sign Up 클릭 | nicknameError 없음 | P0 |
| EV-20 | 닉네임 정상 (한글) | Nickname = "테스트유저" | Sign Up 클릭 | nicknameError 없음 | P0 |
| EV-21 | 닉네임 정상 (숫자 포함) | Nickname = "test123" | Sign Up 클릭 | nicknameError 없음 | P0 |
| EV-22 | 생년월일 미선택 (전체) | Year/Month/Day 모두 미선택 | Sign Up 클릭 | dobError 표시: 생년월일 미선택 에러 | P0 |
| EV-23 | 생년월일 일부 미선택 | Year만 선택, Month/Day 미선택 | Sign Up 클릭 | dobError 표시: 생년월일 미선택 에러 | P0 |
| EV-24 | 생년월일 정상 | Year/Month/Day 모두 선택 | Sign Up 클릭 | dobError 없음 | P0 |
| EV-25 | 휴대전화 미입력 | Mobile 빈 상태 | Sign Up 클릭 | mobileError 표시: 휴대전화 미입력 에러 | P0 |
| EV-26 | 인증번호 불일치 | 인증번호 = 잘못된 값 | 인증 확인 클릭 → API 응답 | mobileError 표시: 인증번호 불일치 에러 | P0 |
| EV-27 | 약관 필수 미동의 | 이용약관 미체크 | Sign Up 클릭 | 가입 불가 (버튼 비활성 또는 에러) | P0 |
| EV-28 | 에러 메시지 스타일 | 에러 상태 | 에러 메시지 표시 확인 | text-[1.4rem] font-normal text-[#ff3a3a] 조건부 렌더링 | P1 |
| EV-29 | 에러 메시지 조건부 렌더링 | 에러 없는 상태 | DOM 검사 | 에러 `<p>` 태그 미존재 (고정 높이 공간 예약 없음) | P1 |

### 4-5. 엣지 케이스 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| EE-01 | 비밀번호 정확히 6자 (최소) | Password = "Abc12!" | Sign Up 클릭 | passwordError 없음 (경계값 통과) | P1 |
| EE-02 | 비밀번호 정확히 16자 (최대) | Password = "Abcdefgh1234!@#$" | Sign Up 클릭 | passwordError 없음 (경계값 통과) | P1 |
| EE-03 | 닉네임 정확히 2자 (최소) | Nickname = "AB" | Sign Up 클릭 | nicknameError 없음 (경계값 통과) | P1 |
| EE-04 | 닉네임 정확히 12자 (최대) | Nickname = "ABCDEFGHIJKL" | Sign Up 클릭 | nicknameError 없음 (경계값 통과) | P1 |
| EE-05 | 닉네임 한글 2자 (최소) | Nickname = "가나" | Sign Up 클릭 | nicknameError 없음 | P1 |
| EE-06 | 닉네임 한글 12자 (최대) | Nickname = "가나다라마바사아자차카타" | Sign Up 클릭 | nicknameError 없음 | P1 |
| EE-07 | 이메일 공백 포함 | Email = " test@example.com " | Sign Up 클릭 | 앞뒤 공백 트림 후 정상 처리 또는 형식 에러 | P2 |
| EE-08 | 닉네임 공백 포함 | Nickname = "test user" | Sign Up 클릭 | nicknameError: 공백 불허 (한글/영문/숫자만) | P2 |
| EE-09 | 이메일 대소문자 | Email = "Test@Example.COM" | Sign Up 클릭 | 대소문자 무관 정상 처리 | P2 |
| EE-10 | 생년월일 2월 31일 | Year=2000, Month=02, Day=31 | Sign Up 클릭 | 유효하지 않은 날짜 에러 (미구현 예상) | P2 |
| EE-11 | 미성년자 생년월일 | Year=현재년도-17, Month=01, Day=01 | Sign Up 클릭 | 미성년자 가입 불가 에러 | P1 |
| EE-12 | XSS 시도 입력 | Email = `<script>alert(1)</script>` | Sign Up 클릭 | 스크립트 실행 없음, 형식 에러 표시 | P1 |
| EE-13 | 중복 제출 | 모든 필드 정상 입력 | Sign Up 빠르게 2회 클릭 | 1회만 API 호출 (isLoading 방지) | P1 |
| EE-14 | 네트워크 에러 | 네트워크 오프라인 | Sign Up 클릭 | 에러 처리, 사용자 알림 | P1 |

### 4-6. 접근성 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| EAC-01 | input placeholder | 없음 | 모든 input 확인 | placeholder 텍스트 존재 (용도 안내) | P1 |
| EAC-02 | label-input 연결 | 없음 | label 요소 확인 | 각 label이 해당 input과 시각적으로 연결 | P1 |
| EAC-03 | 비밀번호 토글 버튼 | 없음 | Eye 버튼 확인 | type="button", alt="Toggle password visibility" | P1 |
| EAC-04 | form 태그 사용 | 없음 | DOM 구조 확인 | `<form>` 태그로 입력 필드 래핑, onSubmit 핸들러 | P1 |
| EAC-05 | 키보드 Tab 순서 | 없음 | Tab 키 순차 이동 | Email → Password → Confirm → Nickname → DOB → Mobile → 약관 → Sign Up 순서 | P2 |
| EAC-06 | Enter 키 제출 | 모든 필드 입력 | 마지막 필드에서 Enter | form submit 동작 | P2 |

---

## 5. SNS 가입 완료 (`/[locale]/join/{provider}/complete`) — **as-built dead-route**

> ⚠️ as-built에서는 `join-user` 성공 시 직홈하므로 정상 플로우로는 도달하지 않음. 아래 시나리오는 페이지 자체의 잔류 동작 검증용 (라우트 살리거나 제거 결정 전까지). 정상 플로우 검증은 §9-1 CF-05~CF-08 참조.



### 5-1. 렌더링 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CR-01 | Apple 완료 정상 로딩 | 없음 | `/en/join/apple/complete` 접근 | HTTP 200, 페이지 정상 렌더링 | P0 |
| CR-02 | Google 완료 정상 로딩 | 없음 | `/en/join/google/complete` 접근 | HTTP 200, 페이지 정상 렌더링 | P0 |
| CR-03 | NavBar 렌더링 | 없음 | 페이지 로딩 완료 | "Join" 타이틀 + "Home" 버튼 | P0 |
| CR-04 | Welcome 헤더 | 없음 | 헤더 영역 확인 | "Welcome!" — 4.8rem font-bold, h-[17.2rem] 영역 | P0 |
| CR-05 | 사용자명 표시 | 없음 | 축하 영역 확인 | "giantpony" — 3.2rem font-bold, 보라색(#6335b4), text-center | P0 |
| CR-06 | 축하 메시지 | 없음 | 텍스트 확인 | "Congratulations on joining!" — 1.6rem font-normal | P0 |
| CR-07 | 코인 이미지 | 없음 | 이미지 확인 | img_coins.png 표시, 27.4rem x 15.2rem | P0 |
| CR-08 | 코인 수량 | 없음 | 텍스트 확인 | "10,000 coins" — 2.4rem font-bold | P0 |
| CR-09 | 선물 안내 | 없음 | 텍스트 확인 | "Gift has been granted" — 1.8rem font-normal | P0 |
| CR-10 | 부가 설명 Mixed FontWeight | 없음 | 텍스트 확인 | "Try a FREE session..." font-normal + "My Menu -> Coin History)" font-bold | P0 |
| CR-11 | 구분선 | 없음 | 디바이더 확인 | h-[0.8rem] bg-[#f5f5f5] | P2 |
| CR-12 | ID(Email) 필드 | 없음 | 필드 확인 | "ID (Email)" label + Change 버튼 이미지 | P0 |
| CR-13 | Nickname 필드 | 없음 | 필드 확인 | "Nickname" label + Change 버튼 이미지 | P0 |
| CR-14 | 연락처 안내 문구 | 없음 | 텍스트 확인 | "This number will be connected while Phone call service or Chat Service" — text-[1.2rem] text-[#777777] | P1 |
| CR-15 | Sign-up Method 필드 | 없음 | 필드 확인 | "Sign-up Method" label, 읽기 전용 | P0 |
| CR-16 | Go to Home 버튼 | 없음 | 버튼 확인 | 보라색(#6335b4) 배경, "Go to Home" 텍스트, 흰색 | P0 |
| CR-17 | 메타데이터 title | 없음 | `document.title` 확인 | "Welcome! — Hong Cafe" | P1 |
| CR-18 | 필드 순서 | 없음 | 위→아래 순서 확인 | NavBar → Welcome → 사용자명+축하 → 코인이미지 → 코인수량+안내 → 구분선 → ID → Nickname → 연락처 → 가입방법 → 버튼 | P0 |

### 5-2. i18n 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CI-01 | 영어 로케일 | 없음 | `/en/join/apple/complete` 접근 | joinSnsComplete 네임스페이스 영어 텍스트 표시 | P0 |
| CI-02 | 한국어 로케일 | 없음 | `/ko/join/apple/complete` 접근 | joinSnsComplete 네임스페이스 한국어 텍스트 표시 | P0 |
| CI-03 | 일본어 로케일 | 없음 | `/ja/join/apple/complete` 접근 | joinSnsComplete 네임스페이스 일본어 텍스트 표시 | P0 |

### 5-3. 인터랙션 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CA-01 | Go to Home 클릭 | 없음 | Go to Home 버튼 클릭 | `/en`(메인)으로 이동 | P0 |
| CA-02 | 뒤로가기 버튼 | 가입폼에서 진입 | NavBar 뒤로가기 클릭 | 이전 페이지(가입폼)로 이동 | P1 |
| CA-03 | Home 버튼 | 없음 | NavBar Home 클릭 | `/en`으로 이동 | P1 |
| CA-04 | Change 버튼 (ID) | 없음 | ID Change 버튼 클릭 | 미구현 — 향후 닉네임 변경 기능 | P2 |
| CA-05 | Change 버튼 (Nickname) | 없음 | Nickname Change 버튼 클릭 | 미구현 — 향후 닉네임 변경 기능 | P2 |

### 5-4. 접근성 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CAC-01 | 코인 이미지 alt | 없음 | Image 검사 | alt="Gift Coins" 또는 "Gift coins" 존재 | P1 |
| CAC-02 | Go to Home Link | 없음 | 버튼 검사 | Link 컴포넌트 사용, href 속성 존재 | P1 |
| CAC-03 | Change 버튼 alt | 없음 | Image 검사 | alt="Change" 존재 | P2 |

---

## 6. 이메일 가입 완료 (`/[locale]/join/email/complete`) — **as-built dead-route**

> ⚠️ §5와 동일하게 정상 플로우 미사용. 코인 안내/Welcome 노출 정책(FFS §3-4 ⚠ 참고) 확정 후 라우트 운명 결정.



### 6-1. 렌더링 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| ECR-01 | 페이지 정상 로딩 | 없음 | `/en/join/email/complete` 접근 | HTTP 200, 페이지 정상 렌더링 | P0 |
| ECR-02 | NavBar 커스텀 스타일 | 없음 | NavBar 확인 | 커스텀 navClassName 적용, 보라색 배경 + 흰색 텍스트 | P0 |
| ECR-03 | Home 버튼 pill 스타일 | 없음 | Home 버튼 확인 | 흰색 테두리 pill (border-[#ffffff] rounded-[99.9rem]) | P0 |
| ECR-04 | Welcome 헤더 | 없음 | 헤더 확인 | "Welcome!" — 4.8rem font-bold, h-[17.2rem] | P0 |
| ECR-05 | 사용자명 | 없음 | 텍스트 확인 | "giantpony" — 3.2rem font-bold 보라색 | P0 |
| ECR-06 | 축하 메시지 | 없음 | 텍스트 확인 | "Congratulations on joining!" | P0 |
| ECR-07 | 코인 이미지 | 없음 | 이미지 확인 | img_coins.png 표시 | P0 |
| ECR-08 | Mixed FontWeight 설명 | 없음 | 텍스트 확인 | "Try a FREE session..." font-normal + "My Menu -> Coin History)" font-bold | P0 |
| ECR-09 | ID(Email) 필드 | 없음 | 필드 확인 | "ID (Email)" label + readOnly input | P0 |
| ECR-10 | Nickname 필드 | 없음 | 필드 확인 | "Nickname" label + readOnly input | P0 |
| ECR-11 | 연락처 필드 | 없음 | 필드 확인 | 연락처 필드 + 안내 문구 표시 | P0 |
| ECR-12 | Sign-up Method | 없음 | 필드 확인 | "Sign-up Method" label + defaultValue "Join with Email" | P0 |
| ECR-13 | Go to Home 버튼 | 없음 | 버튼 확인 | 보라색 배경 + "Go to Home" 흰색 텍스트 | P0 |
| ECR-14 | 연락처 안내 문구 | 없음 | 텍스트 확인 | "This number will be connected..." — text-[1.2rem] text-[#777777] | P1 |

### 6-2. i18n 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| ECI-01 | 영어 로케일 | 없음 | `/en/join/email/complete` 접근 | joinEmailComplete 네임스페이스 영어 텍스트 | P0 |
| ECI-02 | 한국어 로케일 | 없음 | `/ko/join/email/complete` 접근 | joinEmailComplete 네임스페이스 한국어 텍스트 | P0 |
| ECI-03 | 일본어 로케일 | 없음 | `/ja/join/email/complete` 접근 | joinEmailComplete 네임스페이스 일본어 텍스트 | P0 |

### 6-3. 인터랙션 테스트

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| ECA-01 | Go to Home 클릭 | 없음 | Go to Home 버튼 클릭 | `/en`(메인)으로 이동 | P0 |
| ECA-02 | 뒤로가기 | 가입폼에서 진입 | NavBar 뒤로가기 클릭 | 이전 페이지로 이동 | P1 |
| ECA-03 | Home 버튼 | 없음 | NavBar Home 클릭 | `/en`으로 이동 | P1 |

---

## 7. 기가입 안내 화면 (S37~S42, 미구현)

### 7-1. 기가입 — 이메일+휴대폰 둘 다 일치 (로그인 유도)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AM-01 | 기가입 안내 진입 — Apple | Apple 가입 시도, 이메일+휴대폰 둘 다 DB 일치 | 가입 API 응답 분기 | 기가입 안내 화면 렌더링, 기존 가입 방법 표시 | P0 |
| AM-02 | 기가입 안내 진입 — Google | Google 가입 시도, 이메일+휴대폰 둘 다 DB 일치 | 가입 API 응답 분기 | 기가입 안내 화면 렌더링, 기존 가입 방법 표시 | P0 |
| AM-03 | 기가입 안내 진입 — LINE | LINE 가입 시도, 이메일+휴대폰 둘 다 DB 일치 | 가입 API 응답 분기 | 기가입 안내 화면 렌더링, 기존 가입 방법 표시 | P0 |
| AM-04 | 기가입 안내 진입 — Email | 이메일 가입 시도, 이메일+휴대폰 둘 다 DB 일치 | 가입 API 응답 분기 | 기가입 안내 화면 렌더링, 기존 가입 방법 표시 | P0 |
| AM-05 | 로그인 버튼 표시 | 기가입 안내 화면 | 화면 렌더링 | "로그인" 버튼 표시 | P0 |
| AM-06 | 로그인 버튼 클릭 | 기가입 안내 화면 | 로그인 버튼 클릭 | `/[locale]/login` 로그인 페이지로 이동 | P0 |
| AM-07 | 기존 가입 정보 표시 | 기가입 안내 화면 | 가입 정보 확인 | ID(이메일) + 가입 방법(SNS종류 또는 이메일) 표시 | P1 |

### 7-2. 기가입 — 하나만 일치 (고객센터 유도)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AM-08 | 고객센터 안내 — 이메일만 일치 | 가입 시도, 이메일만 DB 일치, 휴대폰 불일치 | 가입 API 응답 분기 | "확인이 필요합니다" 안내 화면, 고객센터 연락 안내 | P0 |
| AM-09 | 고객센터 안내 — 휴대폰만 일치 | 가입 시도, 휴대폰만 DB 일치, 이메일 불일치 | 가입 API 응답 분기 | "확인이 필요합니다" 안내 화면, 고객센터 연락 안내 | P0 |
| AM-10 | Apple 이메일 비공개 케이스 | Apple 가입, "이메일 숨기기" 사용 | 가입 시도 | 릴레이 이메일로 기가입 체크 수행, 결과에 따라 분기 | P1 |
| AM-11 | 고객센터 버튼 표시 | 고객센터 안내 화면 | 화면 렌더링 | 고객센터 연락처 또는 이동 버튼 표시 | P1 |

### 7-3. provider별 기가입 화면

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| AM-12 | LINE 기가입 화면 (S38) | LINE 기가입 확인 | 화면 렌더링 | LINE 계정 기가입 안내, 기존 LINE 계정 정보 표시 | P1 |
| AM-13 | Google 기가입 화면 (S39) | Google 기가입 확인 | 화면 렌더링 | Google 계정 기가입 안내, 기존 Google 계정 정보 표시 | P1 |
| AM-14 | Apple 기가입 화면 (S40) | Apple 기가입 확인 | 화면 렌더링 | Apple 계정 기가입 안내, 기존 Apple 계정 정보 표시 | P1 |
| AM-15 | Email 기가입 화면 (S42) | Email 기가입 확인 | 화면 렌더링 | 이메일 기가입 안내, 기존 이메일 계정 정보 표시 | P1 |

---

## 8. 재가입 플로우 (S43~S47, 미구현)

### 8-1. 재가입 불가 (탈퇴 후 7일 이내)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| RJ-01 | 재가입 불가 — LINE (S43) | LINE 탈퇴 후 3일 경과 | LINE 가입 시도 | "재가입이 불가합니다" 안내, 재가입 가능 날짜 표시 (탈퇴일+7일) | P0 |
| RJ-02 | 재가입 불가 — Apple (S45) | Apple 탈퇴 후 5일 경과 | Apple 가입 시도 | "재가입이 불가합니다" 안내, 재가입 가능 날짜 표시 | P0 |
| RJ-03 | 재가입 불가 — Email (S47) | Email 탈퇴 후 1일 경과 | Email 가입 시도 | "재가입이 불가합니다" 안내, 재가입 가능 날짜 표시 | P0 |
| RJ-04 | 재가입 불가 날짜 정확성 | 탈퇴일 2026-03-20 | 2026-03-24 가입 시도 | 재가입 가능 날짜 = 2026-03-27 표시 | P1 |
| RJ-05 | 재가입 불가 — 정확히 7일째 | 탈퇴일 2026-03-17, 현재 2026-03-24 00:00:00 | 가입 시도 | 7일(168시간) 미경과 시 불가, 경과 시 가능 — 경계값 | P1 |
| RJ-06 | 확인 버튼 클릭 | 재가입 불가 화면 | 확인 버튼 클릭 | 메인 페이지(`/[locale]`)로 이동 | P1 |

### 8-2. 재가입 가능 (탈퇴 후 7일 경과)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| RJ-07 | 재가입 가능 — LINE (S44) | LINE 탈퇴 후 10일 경과 | LINE 가입 시도 | 정상 가입 프로세스 진행 (SNS 가입폼 표시) | P0 |
| RJ-08 | 재가입 가능 — Apple (S46) | Apple 탈퇴 후 8일 경과 | Apple 가입 시도 | 정상 가입 프로세스 진행 | P0 |
| RJ-09 | 재가입 가능 — Email (S47) | Email 탈퇴 후 14일 경과 | Email 가입 시도 | 정상 가입 프로세스 진행 (이메일 가입폼 표시) | P0 |
| RJ-10 | 재가입 시 이전 데이터 | 재가입 가능 상태 | 가입 완료 | 이전 계정 데이터 복구 불가, 신규 계정으로 생성 | P1 |
| RJ-11 | 재가입 시 코인 지급 | 재가입 가능 상태 | 가입 완료 | 10,000 코인 지급 여부 (비즈니스 정책 미확정) | P2 |
| RJ-12 | 탈퇴 기록 없음 | DB에 탈퇴 기록 없음 | 가입 시도 | 정상 신규 가입 프로세스 진행 | P0 |

### 8-3. 재가입 — 로케일별 분기

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| RJ-13 | 재가입 불가 안내 영어 | en 로케일 | 재가입 불가 화면 | 영어 안내 메시지 표시 | P0 |
| RJ-14 | 재가입 불가 안내 한국어 | ko 로케일 | 재가입 불가 화면 | 한국어 안내 메시지 표시 | P0 |
| RJ-15 | 재가입 불가 안내 일본어 | ja 로케일 | 재가입 불가 화면 | 일본어 안내 메시지 표시 | P0 |

---

## 9. 크로스 페이지 플로우

### 9-1. 정상 가입 플로우 (해피 패스)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CF-01 | 로그인 → 방법 선택 | 로그인 페이지 | "Join" 링크 클릭 | `/en/join` 방법 선택 화면 표시 | P0 |
| CF-02 | 방법 선택 → Google 가입폼 | `/en/join` | Google 버튼 클릭 | `/en/join/google` SNS 가입폼 표시 | P0 |
| CF-03 | 방법 선택 → Apple 가입폼 | `/en/join` | Apple 버튼 클릭 | `/en/join/apple` SNS 가입폼 표시 | P0 |
| CF-04 | 방법 선택 → 이메일 가입폼 | `/en/join` | Email 버튼 클릭 | `/en/join/email` 이메일 가입폼 표시 | P0 |
| CF-05 | Apple 가입폼 → 홈 직행 (as-built) | `/join/apple` (OAuth 콜백 경유), 전체 통과 | Sign Up 클릭 | `setAuth(true, data.data)` + `router.push('/')` 메인 페이지 표시 (가입완료 페이지 미경유) | P0 |
| CF-06 | Google 가입폼 → 홈 직행 (as-built) | `/join/google` (OAuth 콜백 경유), 전체 통과 | Sign Up 클릭 | 동일 — 메인 페이지 직행 | P0 |
| CF-07 | 이메일 가입폼 → 홈 직행 (as-built) | `/join/email`, 모든 필드 + 인증 + reCAPTCHA + 동의 | Sign Up 클릭 | `setAuth(true, data.data)` + `router.push('/')` 메인 페이지 직행 | P0 |
| CF-07b | OAuth 콜백 → 자동로그인 분기 (as-built) | OAuth provider 응답 `exist_flag=4` (기존 사용자) | OAuth 콜백 진입 | `tryAutoLogin` → 기존 세션 복구 → `/` 홈 직행 (SnsJoinForm 미진입, 커밋 `b168d51`) | P0 |
| CF-07c | OAuth 콜백 → 미가입 분기 (as-built) | OAuth provider 응답 `exist_flag≠4` | OAuth 콜백 진입 | SnsJoinForm으로 이동, prefill로 email/nickname 주입 | P0 |
| CF-08 | 가입완료 페이지 직접 접근 (deprecated) | 정상 플로우 미경유 | `/join/apple/complete` 직접 URL | 페이지 렌더 (dead-route) — 향후 401/홈 리다이렉트 또는 라우트 제거 결정 | P2 |

### 9-2. hostname별 플로우

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CF-09 | EN 호스트 전체 플로우 | EN | `en.hongcafe.com/join` → `/join/google` → 홈 | 모든 페이지 영어, hostname 유지, 가입 후 홈 직행 | P0 |
| CF-10 | JP 호스트 전체 플로우 | JP | `jp.hongcafe.com/join` → `/join/line` → 홈 | 모든 페이지 일본어, hostname 유지, LINE provider 정상 진입 | P0 |
| CF-11 | 호스트 간 직접 이동 | EN에서 가입 시작 | 도메인 변경 `jp.hongcafe.com/join/google` | JP 로케일로 가입폼 렌더링 (상태 미공유 — 새 호스트로 진입) | P2 |

### 9-3. 비정상 플로우

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CF-12 | 완료 페이지 직접 접근 | 가입 프로세스 미진행 | `/en/join/apple/complete` 직접 URL 입력 | 현재: 페이지 렌더링 (하드코딩 데이터). 향후: 가입 상태 미확인 시 리다이렉트 | P1 |
| CF-13 | 존재하지 않는 provider | 없음 | `/en/join/kakao` 접근 | 404 페이지 (generateStaticParams에 kakao 미포함) | P1 |
| CF-14 | 가입폼 → 뒤로가기 → 재진입 | 가입폼에서 일부 입력 후 뒤로가기 | 뒤로가기 후 재진입 | 이전 입력값 초기화 (클라이언트 상태 리셋) | P2 |
| CF-15 | 가입 완료 후 뒤로가기 | 가입 완료 화면 | 브라우저 뒤로가기 | 가입폼으로 이동 (이중 가입 방지 로직 미구현) | P1 |
| CF-16 | Email 완료 URL에 다른 provider | 없음 | `/en/join/google/complete` (email 가입 후) | provider에 맞는 완료 화면 렌더링 (데이터 정합성 미구현) | P2 |

### 9-4. 기가입/재가입 크로스 플로우 (미구현)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| CF-17 | SNS 가입 → 기가입 확인 → 로그인 이동 | 기가입 회원 | SNS 가입 시도 → 기가입 API 응답 | 기가입 안내 화면 → 로그인 버튼 → `/[locale]/login` | P0 |
| CF-18 | 이메일 가입 → 기가입 확인 → 고객센터 | 이메일만 일치 회원 | 이메일 가입 시도 → 기가입 API 응답 | 고객센터 안내 화면 | P0 |
| CF-19 | 재가입 불가 → 확인 → 메인 | 탈퇴 후 3일 경과 | 가입 시도 → 재가입 불가 API 응답 | 재가입 불가 화면 → 확인 → 메인 이동 | P0 |
| CF-20 | 재가입 가능 → 정상 가입 플로우 | 탈퇴 후 10일 경과 | 가입 시도 → 재가입 가능 API 응답 | 정상 가입 프로세스 진행 → 가입 완료 | P0 |

---

## 10. 보안 검증 시나리오 (v1.1 신규)

### 10-1. CSRF Signed Double Submit (커밋 `58152a1`)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-01 | hc_csrf_meta 우선 적용 | 정상 진입 (meta 토큰 발급됨) | Sign Up 버튼 클릭 → network 캡처 | `secureFetch`가 `x-csrf-token` 헤더에 `hc_csrf_meta` 값 첨부 | P0 |
| SEC-02 | hc_csrf fallback (백엔드 발급 토큰) | meta 토큰 없음, 백엔드 hc_csrf 쿠키만 존재 | Sign Up 클릭 → network 캡처 | `secureFetch`가 `hc_csrf` 값으로 fallback | P0 |
| SEC-03 | CSRF 토큰 누락 | 두 토큰 모두 없음 | Sign Up 클릭 | API 호출 차단 또는 백엔드 403 에러 | P0 |
| SEC-04 | 토큰 변조 | hc_csrf_meta를 Devtools로 임의 변경 | Sign Up 클릭 | 백엔드 검증 실패 → 가입 불가 + 에러 표시 | P1 |

### 10-2. XSS 방어 (`escapeHtml`)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-05 | API 응답 msg에 HTML 태그 | mock 응답 `data.msg = "<img src=x onerror=alert(1)>"` | Sign Up 실패 처리 | `submitError`에 escape된 텍스트 노출, 스크립트 미실행 (XSS 방어) | P0 |
| SEC-06 | PhoneCertField 발송 실패 메시지 XSS | mock `data.msg = "<script>"` | "인증받기" 클릭 후 메시지 표시 | escape된 텍스트만 노출 | P0 |
| SEC-07 | 사용자 입력 reflect | nickname=`<svg onload=alert(1)>` | Sign Up 클릭 | 입력값은 form value에만 사용, DOM에 dangerouslySetInnerHTML 미사용 | P0 |

### 10-3. reCAPTCHA Enterprise (V5.6 §22-4-C)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-08 | enterprise.js 스크립트 로드 | `RECAPTCHA_ENTERPRISE_SITE_KEY` 설정 | 페이지 로딩 | `<script src="https://www.google.com/recaptcha/enterprise.js">` 로드 (`lib/recaptcha.js` 싱글톤) | P0 |
| SEC-09 | classic v2 라이브러리 사용 금지 | grep `react-google-recaptcha` | import 검사 | `import` 발견 시 즉시 REJECT (§22-4-C) — as-built는 자체 `ReCaptchaEnterprise` 사용 | P0 |
| SEC-10 | action 네이밍 | network 캡처 | reCAPTCHA 토큰 발급 | SnsJoinForm: `action="signup_sns"`, EmailJoinForm: `action="signup_email"` | P1 |
| SEC-11 | API 실패 시 reset | join-user 실패 응답 | 가입 시도 → 실패 → 재시도 | `recaptchaRef.current.reset()` 호출 후 재발급된 토큰으로 재시도 (현재 미연결 — 유형 C) | P1 |
| SEC-12 | 백엔드 createAssessment (감사 권고 — 미구현) | 가입 시도 | network 캡처 | 백엔드가 reCAPTCHA Enterprise `projects.assessments.create` API 호출 + score 검증 — **현재 미구현 (유형 B CRITICAL)** | P0 |

### 10-4. apiHandler 200 래핑 함정 (메모리 `feedback_verify_backend_before_claim.md`)

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| SEC-13 | 백엔드 200+`response:'fail'` 응답 | mock 백엔드 응답 | Sign Up 클릭 | curl HTTP 200이라도 `data.response === 'success'` 체크로 실패 분기 진입 | P0 |
| SEC-14 | devProxy 실제 상태코드 확인 | E2E 디버깅 | Sign Up 후 devProxy 로그 확인 | 백엔드 실제 상태코드(401/403/500 등) 로그 기록 — 200 래핑에 속지 않음 | P1 |

---

## 11. 단위 테스트 게이트 (Vitest)

| # | 시나리오 | 대상 파일 | 검증 |
|---|---------|----------|------|
| UT-01 | `validateEmail` 형식 검증 | `lib/validators/joinEmail.js` | 정규식 패턴 매칭 + 빈 값/형식 오류 분기 |
| UT-02 | `validatePassword` 길이/조합 | `lib/validators/joinEmail.js` | 6~16자 + 영문+숫자+특수문자 |
| UT-03 | `validateNickname` 형식 | `lib/validators/joinEmail.js` | 2~12자 + 한글/영문/숫자만 |
| UT-04 | `validateAll` 통합 | `lib/validators/joinEmail.js` | 모든 검증 통과/실패 케이스 |
| UT-05 | `secureFetch` CSRF 토큰 첨부 | `__tests__/client/fetchWithAuth.test.js` | `x-csrf-token` 헤더 자동 첨부 (meta 우선) |
| UT-06 | `escapeHtml` HTML 엔티티 변환 | `lib/sanitizeHtml.js` | `<`, `>`, `&`, `"`, `'` 변환 |
| UT-07 | `lib/csrf.js` Signed Double Submit | `__tests__/lib/csrf.test.js` | HMAC 서명 검증 |
| UT-08 | `apiHandler` 응답 정규화 | `__tests__/lib/apiHandler.test.js` | 백엔드 응답 → 프론트 success/fail 분기 |

> 빌드 게이트: `npm run prebuild` → 위 단위 테스트 실행 → 실패 시 빌드 차단 (커밋 `81ab80a`).

---

## 12. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-03-24 | ffs.md v1.0 + 화면설계서 기반 최초 작성 | 명우현 |
| v1.1 | 2026-04-17 | as-built 기준 전면 갱신: hostname i18n(EN/JP), SNS 6 provider 추가(SR-25~30), OAuth 자동로그인 분기(CF-07b/c), 가입완료 dead-route 표기, PhoneCertField/AgreementGroup/TermsFullModal/ReCaptchaEnterprise 통합 시나리오, 이메일 OTP(유형 C — EA-12e~i) 신규, 보안 검증(§10) 신규(CSRF/XSS/reCAPTCHA Enterprise/apiHandler), 단위 테스트 게이트(§11) 신규. 감사 문서 권고 미반영 항목(SA-09e/EA-12d/SEC-12) CRITICAL 표기 | 명우현 |
