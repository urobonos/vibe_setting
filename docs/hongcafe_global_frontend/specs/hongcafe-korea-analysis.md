# hongcafe-korea (hongcafe3) 코드베이스 전수분석 보고서

> **분석 대상**: `d:/web-home/hongcafe3/` (master branch, commit e37ab9e3c)
> **분석 일자**: 2026-03-25
> **목적**: 일본 버전(hongcafe-japan) 분석 기반 위에 한국 버전의 Delta(차이점)를 식별하여 글로벌 통합 프로젝트에 필요한 전체 기능을 커버

---

## 1. 프로젝트 정체

| 항목 | 실제 |
|------|------|
| Framework | CodeIgniter 4.1.1 (PHP 7.4+) 풀스택 모놀리스 |
| Frontend | PHP View 템플릿 + jQuery 3.x + Handlebars.js + Socket.IO (실시간) |
| DB | MySQL Master-Slave (NTRUSS) — 6개 커넥션 |
| 서비스 유형 | 한국/일본 점술·상담 플랫폼 (전화/채팅/영상 상담 + 디지털상품 + 예약 + 오프라인) |
| 사용자 역할 | Caller (소비자) / Callee (상담사·서비스 제공자) |

**이식 대상**: 프론트엔드 코드 직접 이식 불가. **패턴·로직 설계·API 호출 규약** 참조.

---

## 2. 규모 비교 — 한국 vs 일본

| 항목 | 한국 (hongcafe3) | 일본 (hongcafe-japan) | Delta |
|------|-----------------|---------------------|-------|
| Controller 디렉토리 | 34개 | 30개 | **+12 한국전용, -5 일본전용** |
| Controller 파일 | 171개 | ~130개 | +41 |
| API 컨트롤러 | 43개 | 36개 | +7 |
| API 메서드 | ~400+ | ~320+ | +80+ |
| Model 파일 | 52개 | ~40개 | +12 |
| View 템플릿 (Mobile) | ~350개 | ~250개 | +100 |
| View 템플릿 (PC) | ~100개 | ~80개 | +20 |
| JS 파일 | 80+개 | ~60개 | +20 |
| DB 커넥션 | 6개 | 4개 | +2 (summai_db, old_athena) |

---

## 3. 한국 전용 도메인 (12개) — 일본에 없는 기능

### 3-1. Ambassador (앰배서더 프로그램) — 복잡도: HIGH

**개요**: 브랜드 앰배서더 인플루언서 리퍼럴 시스템. 자격 조건을 갖춘 사용자가 5개 소셜 채널(네이버카페, 네이버블로그, 인스타, 쓰레드, 유튜브)을 통해 홍카페를 홍보하고 코인 보너스를 수령.

**핵심 테이블**:
- `tb_ambassador` — 핵심 앰배서더 레코드
- `tb_ambassador_links` — 소셜 미디어 채널 링크 (활성/비활성)
- `tb_ambassador_posts` — 포스팅 추적 (pending/rejected/approved)
- `tb_ambassador_connection` — 리퍼럴 연결 (부모-자식)
- `tb_ambassador_call_result` — 추천 사용자 통화 수익 추적
- `tb_ambassador_callee_history` — 대표 상담사 변경 이력 (1개월 쿨다운)
- `tb_ambassador_finance_info` — 정산 정보

**비즈니스 로직**:
- 자격 조건: 3개월 내 300만원 이상 코인 사용
- 채널별 보너스: 100건 승인 시 — 네이버카페 3만, 네이버블로그 7만, 인스타/쓰레드 5만, 유튜브 15만
- 추천 사용자 1인당 수익 상한: 100만원
- 대표 상담사 변경: 1개월 쿨다운
- 가입 시 20,000 코인 보너스

**외부 연동**:
- NICE API — 계좌 실명인증 (OTP 기반)
- QR 코드 생성

**컨트롤러**: `Ambassador/Join.php` (7개 메서드), `Ambassador/Main.php` (12개 메서드)
**API**: `Api/Ambassador.php` (17개 메서드)

---

### 3-2. Partner (파트너십 프로그램) — 복잡도: VERY HIGH

**개요**: 3단계 멀티레벨 파트너십 시스템. GMP(일반) → MP(멤버십) → MMP(매니저). 추천 사용자의 통화 수익에서 수수료를 수령.

**핵심 테이블**:
- `tb_partnership` — 핵심 파트너 레코드 (GMP/MP/MMP/USER 타입)
- `tb_partnership_connection` — 부모-자식 관계
- `tb_partnership_finance_info` — 정산 정보 감사 이력
- `tb_partnership_call_result` — 추천 사용자 통화 수익
- `tb_partnership_log` — 상태 변경 로그

**비즈니스 로직 — 수수료 구조**:
```
GMP (General Membership Partner)
  ├── 직접 추천 User → GMP 직접 수익 (최대 100만원/인)
  ├── MP (Membership Partner) → GMP가 MP 리퍼럴 수익의 1% 수령
  │   └── MP의 추천 User → MP 직접 수익, GMP 1%
  └── MMP (Manager Partner) → GMP가 MMP 리퍼럴 수익의 0.5% 수령
      └── MMP의 추천 User → MMP 직접 수익, GMP 0.5%
```
- 수익 상한: 추천 사용자 1인당 100만원
- 약관 동의 유효기간: 초대 후 7일 (미동의 시 자동 해제)
- 초대 코드: SHA256(cr_code) 앞 12자
- 코인 선물: 파트너가 추천 사용자에게 코인 전송 가능

**외부 연동**: NICE API 계좌 실명인증, QR 코드

**컨트롤러**: `Partner/Join.php` (7개 메서드), `Partner/Main.php` (25개 메서드)
**API**: `Api/Partner.php` (17개 메서드)

---

### 3-3. PGMainBase (퍼플/그린 듀얼 티어 아키텍처) — 복잡도: HIGH

**개요**: 홍카페의 핵심 이중 티어 시스템을 구현하는 추상 베이스 컨트롤러. 퍼플(기본)과 그린(별도 URL) 두 개의 독립 서비스 티어를 운영.

**핵심 기능**:
- 듀얼 티어: Purple(기본) vs Green(`/green/*` 별도 URL 공간)
- MomCafe 코드 활성화 (육아 커뮤니티 파트너십)
- 홈 설정 선호도 (call/chat/goods 기본 홈 설정)
- 파트너 약관 동의 팝업 (7일 만료)
- 캠페인 배너 (파이프 구분 이미지 랜덤 선택)
- 온보딩 팝업 (최초 실행)

---

### 3-4. Green (그린 티어) — 복잡도: HIGH

**개요**: 퍼플과 완전히 병렬인 독립 서비스 티어. 자체 메인페이지, 베네핏, 룰렛, 특가 이벤트 보유.

**컨트롤러**: `Green/Main/Main.php`, `Green/Main/Hot.php`, `Green/Benefit/Payback.php`, `Green/Benefit/Roulette.php`, `Green/Benefit/SpecialPrice.php`

**비즈니스 로직**:
- 페이백 이벤트: 예산 한도 내 코인 캐시백
- 특가 이벤트: 100원 특가 (페이백과 상호 배타적)
- 룰렛: 일일 무료 1회 + 유료 추가 회전

---

### 3-5. Cafe (홍대 오프라인 카페) — 복잡도: MEDIUM

**개요**: 홍대 오프라인 지점의 카페 클래스, 대면 상담, 카페 뉴스, 상품을 통합 운영.

**핵심 테이블**: `tb_cafenews`, `tb_cafe_cards`

**하위 도메인**:
- **Cafeclass** — 요일별 주간 오프라인 수업 스케줄
- **Cafeshop** — 요일별 주간 대면 상담 스케줄
- **CafeGoods** — 통화 시간 기반 상품 이벤트 (100분 달성 시 상품 지급, 50명 제한, 배송 주소 수집)

---

### 3-6. Campaign (캠페인) — 복잡도: LOW

**개요**: "실제 인증" 프로모션 캠페인. 캠페인 배너의 상담사 사진 로테이션.

---

### 3-7. ThemeBanner (테마 배너) — 복잡도: LOW

**개요**: 테마별 인기 상담사 랭킹. 5개 카테고리(재방문, 효과적, 단골, 정확, 인기). 퍼플/그린 별도 뷰.

---

### 3-8. Applink (딥링크) — 복잡도: LOW

**개요**: 모바일/데스크톱 UA 감지 → 앱(`hongcafe://`), 앱스토어, 웹 폴백 분기.

---

### 3-9. Hongmentor — 존재하지 않음

Git 브랜치 참조만 존재 (`hongmentor-QA`). 미머지 또는 삭제된 기능.

---

## 4. 결제 시스템 — 한국 vs 일본 완전 비교

### 4-1. 결제 게이트웨이

| 게이트웨이 | PG 코드 | 한국 | 일본 | 비고 |
|-----------|---------|------|------|------|
| **NicePay** | `nice_bis` | O | X | 한국 주력 PG (카드, 가상계좌, 휴대폰) |
| **KakaoPay** | `kakao_pay` | O | X | 한국 모바일 월렛 |
| **NaverPay** | `naver_pay` | O | X | 한국 모바일 월렛 |
| **TossPay** | `toss_pay` | O | X | 한국 모바일 월렛 |
| **Mcash** | `mo_card`/`mcash` | O | X | 휴대폰 소액결제 + 모바일카드 |
| **Stripe** | — | X | O | 일본 주력 PG |
| **PayLetter** | `payletter` | O | X | 해외 사용자 국제결제 |
| **PayPal** | `paypal` | O | O | USD 결제 |

**한국 7개 PG vs 일본 1개(Stripe)**

### 4-2. 간편결제 (SimplePay) — 한국 전용

- NicePay autopay 인프라 기반 카드 등록/결제
- `tb_simplepay` 테이블 — 등록 카드 관리
- 비밀번호 보호 결제 (bcrypt, 5회 실패 시 24시간 잠금)
- `country_code == 'KR'` + 생년월일 인증 사용자만 이용 가능

### 4-3. 자동충전 (AutoPay) — 한국 전용

- 코인 잔액 0일 때 등록 카드로 자동 충전
- `tb_autopay` 테이블 — NicePay billing key 저장
- `Mypage/Autopay` 컨트롤러 — 자동충전 규칙 관리

### 4-4. 상품 유형

| 유형 | 테이블 | 한국 | 일본 | 설명 |
|------|--------|------|------|------|
| `coin` | `tb_order` | O | O | 코인 충전 |
| `goods` | `tb_goods_order` + `tb_goods_sell` | O | O | 상담사 상품 (재고 차감) |
| `shop` | `tb_shop_order` + `tb_shop_reservation` | O | X | 대면 상담 예약 (네이버 예약 API 연동) |
| `reserve` | `tb_order` | O | O | 전화 예약 결제 |

### 4-5. 부가세(VAT)

- 한국: 국내 `pd_price * 1.1` (10%). 해외(PayPal/PayLetter)는 VAT 없음, `pd_usd_price / 1000`
- 일본: Stripe에서 처리

### 4-6. 쿠폰 시스템

- `CouponModel` — 결제 플로우에 통합
- `cu_code`, `coupon_code` 주문 생성 시 전달
- `CheckCoupon()`, `GetCouponPrice()`, `UseCoupon()`
- `payreward` 쿠폰: 결제 시 보너스 코인 지급

### 4-7. 복귀 사용자 특가

- 1년 이상 미이용 사용자: `GetLeaveProduct()` 특가 상품
- `ac_last_calldate` 기준 1년 비교

---

## 5. 인증 시스템 — 한국 vs 일본 완전 비교

### 5-1. 세션/인증 아키텍처

- 쿠키 기반 (서버 세션 없음)
- `hdata` — 암호화 JSON (ac_id, cr_code, login_date, is_momcafe, mom_code)
- `ck_login_member` — 암호화 JSON (cr_code)
- `custom_encrypt()` / `custom_decrypt()` — CI4 Encryption 라이브러리
- 60일(기억하기) / 7일(기본) 만료

### 5-2. 소셜 로그인

| 프로바이더 | 한국 | 일본 | 한국 전용 데이터 |
|-----------|------|------|----------------|
| **Kakao** | O | X | birthyear, birthday, phone, gender, nick, country_phone |
| **Naver** | O | X | name, birthyear, birthday, phone, gender, nick, country_phone |
| **Apple** | O | O | apple_name only |
| **Google** | O | O | email + sns_id only |
| **Facebook** | O | X | email + sns_id only |
| **LINE** | X | O | — |

**SNS 인증 플로우**:
1. `Plugins/{Provider}::index()` → OAuth URL 생성, 팝업 렌더
2. OAuth 콜백 → `AuthCallback()` → 프로필 취득
3. `BaseHomeController::handleSnsAuth($sns_data)` → SNS 데이터 암호화 → 리디렉트
4. `SnsReceive()` → 기존 사용자 확인:
   - 기존 사용자: 쿠키 로그인, 상태 체크 (정지/탈퇴/강제탈퇴)
   - 다른 SNS 기존 사용자: `ExistingUser` 페이지 (SNS 연결 플로우)
   - 이메일 불일치: `MissMatchUser` 페이지
   - 신규: 가입 페이지 리디렉트

### 5-3. 본인인증

| 항목 | 한국 | 일본 |
|------|------|------|
| **인증 방식** | ICERTSecu (국가 공인 본인인증) | SMS OTP만 |
| **인증 서비스** | SEED 암호화 기반 통신사 인증 | SMS 발송 |
| **추출 데이터** | CI, DI, phoneNo, phoneCorp, birthDay, gender, nation, name | 전화번호만 |
| **인증 종류** | JOIN_CERT (가입용), PAY_CERT (결제용) | 가입용 SMS만 |
| **연령 확인** | ICERTSecu 생년월일 → 만 19세 확인 | 자기신고 |

### 5-4. 계정 상태

| 상태 | 의미 | 한국 | 일본 |
|------|------|------|------|
| `2` | 활성 | O | O |
| `3` | 이용중지 | O | O |
| `4` | 이용중지 | O | O |
| `5` | 탈퇴 (7일 재가입 제한) | O | O |
| `6` | 강제 탈퇴 | O | O |

### 5-5. 가입 검증 규칙

- `ac_id`: 필수, 유효 이메일, 유니크 (탈퇴자 제외)
- `ac_nick`: 필수, 2-12자, `korean_alpha_dash`, 금칙어, 유니크
- `cr_phone`: 필수, 숫자
- `ac_password`: 필수, 6-16자, `valid_password` (이메일 가입만)
- 만 19세 이상 필수 (미성년자 차단)

---

## 6. 공통 도메인 — 한국이 더 풍부한 기능

### 6-1. Chat (채팅 상담)

한국 추가 메서드 4개:
- `sendQnaChatAlimTalk()` — 카카오톡 알림톡 Q&A 알림
- `sendAbsenceAlimTalk()` — 카카오톡 부재중 알림
- `disconnectClosed()` — 별도 연결 종료 핸들러
- `getPopupInfo()` — 채팅 팝업 정보

### 6-2. Board (게시판/콘텐츠)

한국 추가 메서드 14개 + 전용 뷰 컨트롤러 9개:
- 좋아요 4종: `consultLike`, `instaToonCommentLike`, `postingtLike`, `insideLike`
- 오프라인 갤러리: `getOfflineGalleray`, `OfflineInsert`
- 카페 뉴스: `getCafeNews`
- 성공 스토리 CRUD: 6개 메서드
- 채용 공고: `insertRecruit` (14필드 폼)
- 인스타툰: `instaToonCheckLogin`

**한국 전용 게시판**: 카페뉴스, 운세, 홍툰, 인사이드, 인스타툰, LuckAi, 오프라인, 채용, 성공스토리

### 6-3. Callee (상담사 관리)

한국 추가 메서드 6개:
- `updateCallerPopupStatus()` — 발신자 팝업 관리
- `updateCafeShopCallStatus()` — 카페숍 전용 통화 상태
- `counselTimeUpdate()` — 상담 시간 설정
- `goodsGreetingUpdate()` — 상품 인사말
- `checkConnectNumber()` — 연결 번호 확인
- `updateCalleeFinanceAndTaxInfo()` — 정산/세금 정보

일본에만 있는 메서드: `getPointCalleeList`, `getCalleePointList`, `CalleeBuyGiftCard` (포인트/기프트카드)

### 6-4. Goods (상품)

한국 추가 메서드 2개:
- `academyRefundCheck()` — 아카데미 클래스 환불 자격 확인
- `academyClassRefundList()` — 아카데미 클래스 환불 목록

### 6-5. Items (상담사 목록)

한국 추가 메서드 3개:
- `itemAllDeleteLike()` — 좋아요 일괄 삭제
- `itemFixed()` — 아이템 고정
- `getSearchListItems/Goods/Class()` — 타입별 검색

### 6-6. Mypage (마이페이지)

한국 추가 페이지: Autopay, Myclass, Myshop, GoodsChat, Reward, Reservation
한국 추가 API: `deleteMyReturnAlarm`, `deleteAllMyReturnAlarm`

### 6-7. Event (이벤트)

한국 추가: 출석체크(`attendEventJoin`), 코인충전 이벤트(`coinChargeEvent`), 복권(`useLotteryEventTicket`), 복권 이벤트 전용 컨트롤러(`Lotteryevent.php`)

### 6-8. Member (회원)

한국 추가 API 10개:
- `SnsCheckNick` — SNS 닉네임 별도 체크
- `FindPwdCert` / `ConfirmPwdCert` — 추가 비밀번호 인증
- `DirectChangePasswd` — 직접 비밀번호 변경
- `verifyConnectPhone` / `getSmsVerifyNumber` / `updateConnectPhone` — 연결 전화 관리
- `DeleteUserNew` — 신규 탈퇴 플로우
- `checkUserIdPassword` / `setSnsLoginSync` / `updateAutoAlarm` / `checkRecaptchaToken`

---

## 7. 일본에만 있는 기능 (한국에 없음)

| 기능 | 컨트롤러 | 설명 |
|------|---------|------|
| **Video (영상통화)** | `Video/` (37개 메서드) | Agora SDK 기반 영상통화 (한국은 별도 Video 컨트롤러 없음) |
| **Calendar** | `Calendar/` | 별도 캘린더 뷰 |
| **Custom** | `Custom/` | 커스텀 기능 |
| **Intro** | `Intro/` | 인트로 페이지 |
| **LINE 로그인** | `Plugins/Line.php` | LINE OAuth (한국은 카카오/네이버) |
| **포인트 시스템** | `Api/Callee` | 상담사 포인트/기프트카드 |
| **Stripe** | `Pay/` | Stripe 결제 (한국은 NicePay/KakaoPay/NaverPay/TossPay) |

---

## 8. AI 기능 — 한국 전용

### 8-1. LuckAi (AI 운세)

- `Api/LuckAiRest.php` — 11개 메서드
- `Board/LuckAi.php` — 8개 서브페이지 (오늘의운세, 대운세, 사랑, 금전, 건강, 궁합, 행운번호, 설명서)
- `Libraries/AiLuckySaju.php` (83KB) — GCP Vertex AI 연동
- `Libraries/AiLuckyToday.php` (40KB) — 오늘의 행운 AI
- DB: `luckai` 별도 데이터베이스

### 8-2. SummAi (AI 상담 요약)

- `Api/SummAiRest.php` — 14개 메서드
- `Callee/SummAi.php` — 11개 메서드 (상담사 대시보드에서 접근)
- `Libraries/AiSummaryReport.php` (49KB) — GCP 기반 통화/채팅 요약
- DB: `ai_summary` 별도 데이터베이스 (`summai_db`)
- SendBird 메시지 분석 기반

---

## 9. 외부 서비스 연동 — 통합 비교

| 서비스 | 한국 | 일본 | 용도 |
|--------|------|------|------|
| **Hermes PBX** | O | O | 실시간 과금 서버 (전화 라우팅) |
| **SendBird** | O | O | 채팅 메시징 (v1 + v2 SDK) |
| **Socket.IO** | O | O | 상담사 상태 실시간 (wss://node.peoplev.co.kr) |
| **FCM** | O | O | 푸시 알림 (듀얼 Firebase) |
| **NicePay** | O | X | 한국 주력 PG |
| **KakaoPay** | O | X | 한국 모바일 결제 |
| **NaverPay** | O | X | 한국 모바일 결제 |
| **TossPay** | O | X | 한국 모바일 결제 |
| **Mcash** | O | X | 한국 휴대폰 소액결제 |
| **InnoPay** | O | X | 간편결제 카드 등록 |
| **Stripe** | X | O | 일본 주력 PG |
| **PayLetter** | O | X | 해외 사용자 국제결제 |
| **PayPal** | O | O | USD 결제 |
| **ICERTSecu** | O | X | 한국 본인인증 (CI/DI) |
| **NICE API** | O | X | 계좌 실명인증 (OTP) |
| **카카오톡 AlimTalk** | O | X | 한국 알림톡 |
| **Aligo SMS** | O | X | 한국 국내 SMS |
| **SMSLINK** | O | O | 국제 SMS |
| **Naver Booking** | O | X | 네이버 예약 API 연동 |
| **Adjust SDK** | O | O | 모바일 어트리뷰션 |
| **AWS S3** | O | O | 파일 스토리지 |
| **GCP Vertex AI** | O | X | AI 운세/상담 요약 |
| **reCAPTCHA** | O | O | 봇 방지 |
| **Agora** | △(주석) | O | 영상통화 |

---

## 10. 데이터베이스 — 한국 전용 테이블

### 10-1. Ambassador 관련 (7개)
- `tb_ambassador`, `tb_ambassador_links`, `tb_ambassador_posts`
- `tb_ambassador_connection`, `tb_ambassador_call_result`
- `tb_ambassador_callee_history`, `tb_ambassador_finance_info`
- `tb_ambassador_popup_history`

### 10-2. Partnership 관련 (5개)
- `tb_partnership`, `tb_partnership_connection`
- `tb_partnership_finance_info`, `tb_partnership_call_result`
- `tb_partnership_log`

### 10-3. CafeGoods 관련 (4개)
- `tb_event_goods`, `tb_event_goods_callee`
- `tb_event_goods_call_result`, `tb_event_goods_delivery_address`

### 10-4. 기타
- `tb_cafenews`, `tb_cafe_cards`
- `tb_bank` (은행/증권사 목록)
- `tb_industries` (업종 목록)
- `tb_momcafe_code` (맘카페 코드)
- `tb_advance_payment` (선지급)
- AI DB: `luckai` (별도), `ai_summary` (별도)

---

## 11. 프론트엔드 JS — 한국 전용

| JS 파일 | 용도 |
|---------|------|
| `simplepay.js` / `simplepay2.js` | 간편결제 카드 관리 UI |
| `autopay.js` | 자동충전 규칙 관리 |
| `direct.js` | 인앱 브라우저 탈출 (카카오톡, 라인, FB, 인스타) |
| `app_roulette.js` | 룰렛 게임 (CSS transform 애니메이션) |
| `lotteryScratch.js` | 복권 스크래치 |
| `adjust_*.js` (4개) | Adjust SDK 연동 |
| `calleeStateManager.js` | Socket.IO 상담사 실시간 상태 |
| `calleeGoodsStateManager.js` | 상품 페이지 실시간 상태 |
| `calleeProfileStateManager.js` | 프로필 페이지 실시간 상태 |
| `sns_share.js` | 카카오/페이스북 SNS 공유 |

---

## 12. 라우트 — 한국 전용 명시적 라우트

```
# Ambassador
GET /ambassador/intro, /settingCallee, /posts, /addPost, /contentsGuide, /guide, /approved, /connection, /connectionDetail, /regist, /update
GET /ambassador/joinselect/:channel/:code

# Partner
GET /partner/joinselect

# Green 티어 (전체 URL 공간)
GET /green, /green/(call|chat), /green/call/hot/*, /green/call/payback/*, /green/chat/*

# Cafe
GET /cafe, /cafe/detail/:gd_code
GET /cafe/category/cafeclass/week/:day
GET /cafe/category/cafeshop/week/:day
GET /cafegoods/main, /cafegoods/event

# ThemeBanner
GET /themebanner/theme/:type, /themebanner/greentheme/:type

# Naver Booking (Webhook)
POST /businesses/:s/biz-items/:s/bookings
PATCH /businesses/:s/biz-items/:s/bookings/:s

# AppLink
GET /applink/:base64path

# Contents (한국 전용 게시판)
GET /contents/fortune/*, /contents/luckai, /contents/success
GET /success/*, /board/fortune/*

# Campaign
GET /campaign/realauth
```

---

## 13. 글로벌 통합 프로젝트 영향도 평가

### 13-1. 필수 반영 (통합 프로젝트에 반드시 포함)

| 기능 | 이유 | 우선순위 |
|------|------|---------|
| 결제 게이트웨이 확장 (NicePay, Kakao, Naver, Toss) | 한국 시장 필수 | P0 |
| 간편결제 (SimplePay) + 자동충전 (AutoPay) | 핵심 결제 편의 기능 | P0 |
| 본인인증 (ICERTSecu) | 한국 법적 요구사항 | P0 |
| 소셜 로그인 (Kakao, Naver, Facebook) | 한국 시장 필수 | P0 |
| 카카오톡 AlimTalk | 한국 알림 채널 | P1 |
| 060 전화 시스템 | 한국 레거시 지원 | P1 |

### 13-2. 선택 반영 (시장별 ON/OFF)

| 기능 | 이유 | 우선순위 |
|------|------|---------|
| Ambassador 프로그램 | 한국 마케팅 전략 | P2 |
| Partner 프로그램 | 한국 영업 전략 | P2 |
| Green 티어 | 서비스 차별화 | P2 |
| Cafe 오프라인 | 홍대 지점 한정 | P3 |
| AI 운세 (LuckAi) | 한국 콘텐츠 | P2 |
| AI 상담 요약 (SummAi) | 부가 기능 | P2 |

### 13-3. 미반영 (레거시/한국 한정)

| 기능 | 이유 |
|------|------|
| MomCafe 코드 | 특정 커뮤니티 파트너십 |
| 060 전화번호 레거시 마이그레이션 | 구시스템 호환 |
| ICERTSecu SEED 암호화 | PHP 전용 확장 |
| InnoPay | NicePay autopay로 대체 가능 |

---

## 14. 핵심 Config/상수 — 한국 전용

### DB 커넥션 (6개)
| 커넥션 | 호스트 | DB | 용도 |
|--------|-------|-----|------|
| `default` | `db-4r7ki.cdb.ntruss.com` | `athena` | 메인 프로덕션 |
| `stage_db` | `stage.hongcafe.com` | `athena` | 스테이징 |
| `db_jp` | `db-fu0jr-jp.cdb.ntruss.com` | `athena` | 일본 DB |
| `hermes_db` | `118.67.143.174` | `hermes` | PBX/콜 라우팅 |
| `old_athena` | `49.247.200.242` | `athena` | 레거시 DB |
| `summai_db` | `db-a51ba.cdb.ntruss.com` | `ai_summary` | AI 요약 DB |

### 비즈니스 상수
- **상담 분야**: 20개 카테고리 (`COUNSEL_FIELD`)
- **리뷰 태그**: 14개 스타일 (`COMMENT_STYLE`)
- **홈 타입**: 16개 (`HOME_TYPE`)
- **지역**: 16개 한국 지역 (`REGIONS`)
- **상품 카테고리**: 15개 (`GD_CATEGORY_CLASS`)

---

## 15. Libraries — 한국 전용

| 라이브러리 | 크기 | 용도 |
|-----------|------|------|
| `AiLuckySaju.php` | 83KB | AI 사주/운세 (GCP Vertex AI) |
| `AiLuckyToday.php` | 40KB | 오늘의 행운 AI |
| `AiSummaryReport.php` | 49KB | AI 상담 요약 (GCP) |
| `AiCalleeMatch.php` | 12KB | AI 상담사 매칭 |
| `Communicator/AlimTalk.php` | 11KB | 카카오 알림톡 발송 |
| `Communicator/Sms.php` | 4KB | Aligo SMS 발송 |
| `SnsConnector/Kakao.php` | — | 카카오 OAuth |
| `SnsConnector/Naver.php` | — | 네이버 OAuth |
| `SnsConnector/Facebook.php` | — | 페이스북 OAuth |
| `Roulette.php` | 10KB | 룰렛 게임 로직 |
| `Suggest.php` | — | 상담사 추천 |

---

*이 문서는 글로벌 통합 프로젝트에서 한국 버전의 기능을 참조할 때 사용합니다.*
*일본 버전 분석: `docs/specs/hongcafe-japan-analysis.md` 참조.*
