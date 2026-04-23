# hongcafe-japan 코드베이스 완전 분석 보고서

## Critical Constraint (ABSOLUTE)
**V4.5 에이전틱 파이프라인에 영향을 주는 어떠한 수정도 금지한다.**

---

## 1. 프로젝트 정체

| 항목 | 실제 |
|------|------|
| Framework | CodeIgniter 4.1.1 (PHP 7.4+) 풀스택 모놀리스 |
| Frontend | PHP View 템플릿 + jQuery 3.x + Handlebars.js + 일부 React (채팅 위젯만) |
| DB | MySQL Master-Slave (NTRUSS) |
| 서비스 유형 | 한국/일본 점술·상담 플랫폼 (전화/채팅/영상 상담 + 디지털상품 + 예약) |
| 사용자 역할 | Caller (소비자) / Callee (상담사·서비스 제공자) |

**이식 대상**: 프론트엔드 코드 직접 이식 불가. **패턴·로직 설계·API 호출 규약** 참조.

---

## 2. 네이티브 브릿지 통신 — 완전 분석

### 2-1. 플랫폼별 브릿지 인터페이스

#### Android — `window.AppConnector`

| 메서드 | 파라미터 | 방향 | 용도 |
|--------|---------|------|------|
| `appConnectChat(url)` | URL 문자열 | Web → Native | 채팅/통화 인터페이스 열기 |
| `chatClose(url_or_close)` | URL 또는 "close" | Web → Native | 채팅 종료, 선택적 네비게이션 |
| `appOutLink(link)` | URL 문자열 | Web → Native | 외부 링크를 Chrome에서 열기 |
| `getAppVersion()` | 없음 | Web → Native | 현재 앱 버전 조회 |

```javascript
// as-is 구현 (common.js:638-652)
function appOutLink(devicerole, link) {
    if (link === '' || !link) return false;
    if (devicerole === '' || !devicerole) return false;
    try {
        if (devicerole === 'android') {
            window.AppConnector.appOutLink(link);
        } else if (devicerole === 'ios') {
            window.webkit.messageHandlers.appOutLink.postMessage(link);
        }
    } catch (e) {
        console.log('appOutLink error', e);
    }
}
```

#### iOS — `window.webkit.messageHandlers`

| 핸들러 | 파라미터 | 방향 | 용도 |
|--------|---------|------|------|
| `appOutLink.postMessage(link)` | URL 문자열 | Web → Native | 외부 링크를 Safari에서 열기 |

#### iOS Adjust SDK — WVJBridge (레거시)

```javascript
// iframe 트릭으로 브릿지 로드 (adjust_init.js)
function setupWebViewJavascriptBridge(callback) {
    if (window.WebViewJavascriptBridge) return callback(WebViewJavascriptBridge);
    if (window.WVJBCallbacks) return window.WVJBCallbacks.push(callback);
    window.WVJBCallbacks = [callback];
    var WVJBIframe = document.createElement('iframe');
    WVJBIframe.style.display = 'none';
    WVJBIframe.src = 'https://__bridge_loaded__';
    document.documentElement.appendChild(WVJBIframe);
    setTimeout(function() { document.documentElement.removeChild(WVJBIframe); }, 0);
}
```

### 2-2. 앱/웹 판별 메커니즘

**as-is**: 서버 사이드에서 `$devicerole` 파싱 → PHP View에 JS 전역변수 주입

```javascript
// 전역 플래그 (HeaderOutline.php에서 주입)
var A_IS_APP = true/false;   // 네이티브 앱 WebView 여부
var IS_AOS = true/false;     // Android
var IS_IOS = true/false;     // iOS
var IS_LOGIN = true/false;   // 로그인 상태
var IS_MOBILE = true/false;  // 모바일 기기
var A_URL = 'https://...';   // 베이스 URL
```

**판별 소스**: `devicerole` GET 파라미터 + 쿠키 저장 (세션 유지)

### 2-3. 인앱브라우저 탈출 로직

**as-is**: `direct.js` (20줄) — IIFE로 즉시 실행

```javascript
(function(d, l, a) {
    // 비활성화 속성 체크
    if (d.body.getAttribute('__donot_urlopenlink')) return;
    // 모바일 아닌 경우 무시
    if (!/mobile/i.test(a)) return;
    // 인앱브라우저가 아닌 경우 무시
    if (!/inapp|KAKAOTALK|Line\/|FB_IAB\/FB4A|FBAN\/FBIOS|Instagram|DaumDevice\/mobile\/[^1]/i.test(a)) return;

    var varUA = a.toLowerCase();
    var domain = l.href.replace("https://","");

    if (varUA.indexOf('android') > -1) {
        // Android: Chrome Intent 프로토콜
        location.href = 'intent://' + domain + '#Intent;scheme=http;package=com.android.chrome;end';
    } else if (varUA.indexOf("iphone") > -1 || varUA.indexOf("ipad") > -1 || varUA.indexOf("ipod") > -1) {
        // iOS: googlechrome:// scheme
        location.href = l.href.replace(/^http/, 'googlechrome');
    }
})(document, location, navigator.userAgent);
```

**감지 대상 인앱브라우저**: KakaoTalk, LINE, Facebook (Android/iOS), Instagram, Daum

### 2-4. Adjust 이벤트 트래킹

| 이벤트 | 토큰 | 트리거 | 추가 데이터 |
|--------|------|--------|------------|
| 회원가입 완료 | `v42j6a` | Join completion | ac_id (콜백) |
| 결제 완료 | `cddp06` | Payment | revenue + currency(KRW) + ac_id |
| 운세 조회 (7개) | `v2afp1`, `d2tfkk`, `p8z4gf`, `dwgjzx`, `wkefff`, `4z2s85`, `i05lov` | Page click | ac_id |
| 상담사 검색 | `xsvikp` | Search | ac_id |
| 060 상담 | `yr5s0t` | Consultation | ac_id |
| 코인 상담 (KR) | `yv0gs3` | Consultation | ac_id |
| 코인 상담 (Global) | `m0845l` | Consultation | ac_id |
| 리뷰 작성 | `sfmj5a` | Review submit | ac_id |

**이벤트 바인딩 방식**: `addEventListener('click')` + jQuery 위임 `$(document).on('click', '#selector')`

### 2-5. 전화 연결 (Tel Protocol)

```javascript
// 상담 전화 연결 (common.js:529-635)
function CallConnect(it_code, country_code) {
    var api = new AppCsrfAjax();
    api.url = "/api/call/callconnect";
    api.sendAjax({sendData: {country_code, it_code}}, function(data) {
        if (data.response == "success") {
            location.href = "tel:" + data.connect_number;  // 네이티브 전화 앱 호출
        } else {
            if (data.is_login == "false") {
                document.location.href = A_URL + "member/login";
            } else {
                alert(data.msg);
            }
        }
    });
}
```

### 2-6. 소셜 공유

| 플랫폼 | SDK | 메서드 | 데이터 |
|--------|-----|--------|--------|
| Kakao | Kakao.Link.sendDefault | Feed 공유 | title, description, imageUrl, webUrl, mobileWebUrl |
| Facebook | FB.ui | Share dialog | webUrl |
| LINE | URL redirect | window.open | social-plugins.line.me/lineit/share |

### 2-7. 앱스토어 딥링크

```javascript
// Android
location.href = 'market://details?id=kr.co.hongcafe.mobile';
// 또는
location.href = 'https://play.google.com/store/apps/details?id=kr.co.hongcafe.mobile';

// iOS
location.href = 'itms-apps://itunes.apple.com/app/1463346817';
```

---

## 3. AJAX 통신 래퍼 — AppCsrfAjax 완전 분석

### 3-1. 클래스 구조

```javascript
var AppCsrfAjax = function() {
    this.url = "";
    this.csrfType = "header";    // "header" | "post"
    this.tokenUse = false;
    this.ajaxCheck = false;       // 중복 요청 방지 플래그
    this.customLoading = false;
    this.customLoadingRemove = false;
};
```

### 3-2. CSRF 토큰 생성

```javascript
generateCsrfToken: function() {
    function generateRandomString(length) {
        var text = "";
        var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        for (var i = 0; i < length; i++) {
            text += possible.charAt(Math.floor(Math.random() * possible.length));
        }
        return text;
    }
    return btoa(generateRandomString(32));
}
```

### 3-3. 요청 패턴

- **Content-Type**: `application/x-www-form-urlencoded` (기본)
- **CSRF**: `Authorization` 헤더에 Base64 인코딩된 토큰
- **중복 방지**: `ajaxCheck` 플래그로 동시 요청 차단
- **로딩 UI**: GIF 스피너 오버레이 (`#full-loading-wrap`)
- **데이터 직렬화**: jQuery `$(form).serialize()` → URL-encoded

### 3-4. 상속 패턴

```javascript
// Items, Roulette 등이 AppCsrfAjax를 프로토타입 상속
Items.prototype = Object.create(AppCsrfAjax.prototype);
Roulette.prototype = Object.create(AppCsrfAjax.prototype);
```

---

## 4. 도메인별 프론트엔드 로직 — 완전 분석

### 4-1. 인증 (Authentication)

#### 회원가입 플로우

```
1. 이메일 입력 → /api/member/checkid (유니크 체크)
   ↓
2. 이메일 인증 → /api/member/sendMailCert → 코드 입력 → /api/member/confirmMailCert
   ↓
3. 비밀번호 입력 → /api/member/checkpassword (형식 검증)
   ↓
4. 비밀번호 확인 → /api/member/checkpasswordre (일치 검증)
   ↓
5. 닉네임 → /api/member/checknick (유니크 + 금칙어)
   ↓
6. 전화인증 (국가별 분기)
   ├── JP: /api/member/sendglobalcert → 300초 타이머 → /api/member/confirmglobalcert
   └── KR: cert_start() 팝업 → /plugins/certificate/ 윈도우
   ↓
7. 생년월일 (YYYY + MM + DD 드롭다운)
   ↓
8. 약관 동의 (3개 필수: 19세 이상, 서비스, 개인정보)
   ↓
9. /api/member/joinuser (POST, form serialize)
   ↓
10. /member/join/result?exist_flag={flag} 리다이렉트
```

#### SNS 회원가입 분기
- 비밀번호 단계 건너뜀 (SNS 제공자에서 설정)
- `ac_sns_id` 존재 시 `snsSubmitCheckSuccess()` 경로
- 나머지 플로우 동일 (닉네임, 전화인증, 생년월일, 약관)

#### 로그인 플로우

```
1. 이메일 입력 → /api/member/checkloginid (존재 확인)
   ↓
2. 비밀번호 입력 → /api/member/checkloginpassword (형식 확인)
   ↓
3. /api/member/loginuser (POST, form serialize)
   ↓
4. 성공: data.ac_home_set 또는 지정 URL로 리다이렉트
   실패: .popup01 모달에 data.msg 표시
```

#### 계정 찾기

```
ID 찾기:
  /api/member/findidcert (POST: ac_country, cr_phone) → 180초 타이머
  → /api/member/confirmidcert (POST: ac_country, cr_phone, ac_cert_num)
  → 팝업에 ID 표시

비밀번호 찾기:
  /api/member/findpasswordcert (POST: ac_id, cr_phone)
  → 성공 시 /member/login 리다이렉트
```

#### 프로필 수정

| 기능 | 엔드포인트 | 입력 | 결과 |
|------|-----------|------|------|
| 닉네임 변경 | /api/member/changenick | ac_nick | 페이지 리로드 |
| 비밀번호 변경 | /api/member/changepasswd | current + new + confirm | /mypage/info 리다이렉트 |
| 전화번호 변경 | /api/member/verifyphone → updatephone | new_phone + cert_num | 오버레이 닫기 |
| 회원 탈퇴 | /api/member/deleteuser | 체크박스 확인 | 홈으로 리다이렉트 |
| 알림 설정 | /api/member/settingalarm | target element ID | 토글 |

#### SMS 인증 카운트다운 타이머

```javascript
var viewCountdown = function(elementId, seconds) {
    var element = document.getElementById(elementId);
    var endTime = +new Date() + 1000 * seconds;
    function updateTimer() {
        var msLeft = endTime - +new Date();
        if (msLeft < 0) {
            alert("認証コードの有効期限が切れています。\n再度お試しください。");
            location.reload();
        } else {
            var time = new Date(msLeft);
            element.innerHTML = time.getUTCMinutes() + " : " + ("0" + time.getUTCSeconds()).slice(-2);
            if (!CertSuccess) setTimeout(updateTimer, time.getUTCMilliseconds());
        }
    }
    updateTimer();
};
// 사용: viewCountdown('smsCertTimer', 300) → 5분
// 사용: viewCountdown('smsCertTimer', 180) → 3분
```

### 4-2. 결제 (Payment)

#### SimplePay (간편결제 — 카드 등록)

```
1. /api/pay/getmycard → 저장된 카드 조회 (끝 4자리)
   ↓
2. 카드 정보 입력
   - 카드번호: 16자리 (하이픈 제거)
   - 생년월일: 8자리 YYYYMMDD
   - 카드 비밀번호: 앞 2자리만
   - 동의 체크박스
   ↓
3. 6자리 결제 비밀번호 설정
   - 숫자만 허용 (정규식: /[^0-9]*/g)
   - 6자리 초과 시 자동 절단
   - 연속 동일 숫자 3개 이상 불가
   - 마스킹: 입력 시 점(●)으로 표시
   ↓
4. /api/pay/savesimplepay (POST) → 성공 시 /pay/coin.php 리다이렉트
```

#### Stripe 결제

```
카드 등록 (SetupIntent):
  1. /api/stripe/createSetupIntent (POST: { type }) → clientSecret
  2. Stripe.js: confirmCardSetup(clientSecret) → setupIntent.id
  3. #setupIntentId hidden 필드에 저장 → 비밀번호 UI 전환

결제 (PaymentIntent):
  1. 금액 계산 (세금 포함: calculateTaxprice)
  2. 쿠폰 적용: cu_code, cui_code 파라미터
  3. confirmPayment() with return_url:
     - goods → /pay/stripe/PaysuccessGoods
     - shop → /pay/stripe/paysuccessShop
     - coin → /pay/stripe/paysuccess
  4. receipt_email: 사용자 이메일
```

**에러 처리**: generic_decline, insufficient_funds, lost_card, stolen_card → `#payment-message` 4초 표시

#### AutoPay (자동 충전)

```
설정:
  - pd_code (충전 금액 선택)
  - min_coin (잔액 기준값 — 이 이하로 떨어지면 자동 충전)
  - /api/mypage/autopayrulesave (POST)

카드 등록:
  - Stripe SetupIntent 플로우 동일
  - /api/mypage/autopaycardsave (POST)

ON/OFF 토글:
  - /api/mypage/autopayusechange (POST: { ap_use: 'Y'|'N' })
  - data-status 속성으로 UI 상태 관리
```

### 4-3. 채팅 (Chat — SendBird)

```javascript
// 듀얼 SDK 초기화
const appId = '0481526C-B785-423D-9C3B-74D5D477BB9E';
const sb = new SendBird({ appId });          // V1
const sbV2 = SendbirdChat.init({             // V2
    appId, modules: [new GroupChannelModule()]
});
```

**핵심 기능**:
- 메시지 로깅: /api/chat/messageLog (V1), /api/chat/messageLogV2 (V2)
- 읽음 처리: groupChannel.markAsRead() + /api/chat/markAsRead
- 비속어 필터: filterMessage() — 한국어/일본어/영어 패턴 → `**` 치환
- 파일 업로드: /api/chat/fileUpload
- 시스템 공지: custom_type='announcements'
- 시간 표시: getRemainTime(sec) → "HH : MM : SS"
- XSS 방어: escapeHtml(text)

**UI**: Enter(keyCode 13) → 메시지 전송, textarea `#msgId`

### 4-4. 상품 목록 (Items)

**무한 스크롤 패턴**:
- `Items.prototype = Object.create(AppCsrfAjax.prototype)` — AJAX 상속
- `#next-block` 버튼으로 다음 페이지 로드
- PC/모바일 분기 렌더링 (mobileListHtml / pcListHtml)

**상담사 상태별 버튼**:
| ca_status | 표시 | 동작 |
|-----------|------|------|
| `on` | 상담중 (비활성) | 클릭 불가 |
| `standby` | 대기중 (활성) | Call.popup(it_code) |
| `reserv` | 예약 상담중 | 프로필 링크 |
| `away` | 부재중 | 알림 신청 링크 |

**데이터 필드**:
```
it_code, it_nick, it_060_code, it_category_name, it_category_code,
it_main_pic, it_subject, ca_status, view_like_cnt, view_win_comment,
item_label{}, it_win_point (3개월 평점), it_cmt_cnt, it_comment[],
it_notice_string_cnt, it_notice_new, it_tag[]
```

### 4-5. 룰렛 이벤트

```
초기화:
  - 5개 섹터 (72° 간격)
  - duration: 6.8s (cubic-bezier 이징)
  - winType: 'fixed' | 'random'

스핀 플로우:
  1. #rouletteStart 클릭
  2. POST /api/event { event_code }
  3. 서버 응답: win_coin (당첨 인덱스), remain_event (잔여 횟수)
  4. CSS transform: rotate(N도) — 18~23바퀴 + 당첨 섹터
  5. transitionend 이벤트 → 결과 팝업

결과 팝업:
  - 'exhaustion': 이미 참여함 → 홈 + 코인 이력 링크
  - 'win': 당첨! → 상품 표시
  - 'error': 에러 → 재시도 버튼
  - 'login': 미로그인 → 로그인 리다이렉트
```

### 4-6. 프로필 스와이퍼

3개 Swiper 인스턴스:
1. **Banner** (.swiper-banner) — loop, centeredSlides, 네비게이션, YouTube 자동 정지
2. **Profile** (.swiper-profile) — spaceBetween:16px, observer:true
3. **Popup** (.swiper-popup) — touchRatio:0 (고정)

YouTube iframe 제어: `postMessage('{"event":"command","func":"stopVideo","args":""}', '*')`

---

## 5. API 엔드포인트 전체 매핑 (200+개)

### 5-1. 응답 표준 포맷

```json
{
    "response": "success|error",
    "msg": "에러 메시지 또는 빈 문자열",
    "data": { ... },
    "is_login": "true|false"
}
```

**특이사항**: 모든 응답 HTTP 200. 성공/실패는 `response` 필드로 분기.

### 5-2. 인증/회원 (22개)

| 엔드포인트 | 인증 | 용도 |
|-----------|------|------|
| `/api/member/checkid` | X | 이메일 유니크 체크 |
| `/api/member/checknick` | X | 닉네임 유니크 체크 |
| `/api/member/checkpassword` | X | 비밀번호 형식 검증 |
| `/api/member/checkpasswordre` | X | 비밀번호 확인 일치 |
| `/api/member/checkloginid` | X | 로그인 ID 존재 확인 |
| `/api/member/checkloginpassword` | X | 로그인 PW 형식 확인 |
| `/api/member/sendglobalcert` | X | 글로벌 SMS 발송 |
| `/api/member/confirmglobalcert` | X | SMS 인증코드 확인 |
| `/api/member/sendMailCert` | X | 이메일 인증 발송 |
| `/api/member/confirmMailCert` | X | 이메일 인증 확인 |
| `/api/member/joinuser` | X | 회원가입 |
| `/api/member/loginuser` | X | 로그인 |
| `/api/member/findidcert` | X | ID 찾기 인증 발송 |
| `/api/member/confirmidcert` | X | ID 찾기 인증 확인 |
| `/api/member/findpasswordcert` | X | PW 찾기 인증 |
| `/api/member/changenick` | O | 닉네임 변경 |
| `/api/member/changepasswd` | O | 비밀번호 변경 |
| `/api/member/settingalarm` | O | 알림 설정 토글 |
| `/api/member/verifyphone` | O | 전화번호 인증 |
| `/api/member/updatephone` | O | 전화번호 변경 |
| `/api/member/deleteuser` | O | 회원 탈퇴 |
| `/api/member/getappversion` | X | 앱 버전 조회 |

### 5-3. 상품/상담사 목록 (16개)

| 엔드포인트 | 인증 | 용도 |
|-----------|------|------|
| `/api/items/getlist` | X | 상품 목록 (PC) |
| `/api/items/getListMobile` | X | 상품 목록 (모바일) |
| `/api/items/getItem` | X | 상품 상세 |
| `/api/items/getSearchListItems` | X | 검색 |
| `/api/items/getcomment` | X | 댓글 조회 |
| `/api/items/getListComment` | X | 댓글 목록 |
| `/api/items/getItemQnaList` | X | Q&A 목록 |
| `/api/items/getPostingList` | X | 게시글 목록 |
| `/api/items/postingDetail` | X | 게시글 상세 |
| `/api/items/getPostingComments` | X | 게시글 댓글 |
| `/api/items/getLikeList` | O | 좋아요 목록 |
| `/api/items/itemAddLike` | O | 좋아요 추가 |
| `/api/items/itemDeleteLike` | O | 좋아요 삭제 |
| `/api/items/itemAllDeleteLike` | O | 좋아요 전체 삭제 |
| `/api/items/insertItemQna` | O | Q&A 작성 |
| `/api/items/saveItemPrice` | O(Callee) | 가격 수정 |

### 5-4. 채팅 (35+개)

| 엔드포인트 | 인증 | 용도 |
|-----------|------|------|
| `/api/chat/getListMobile` | O | 채팅 목록 |
| `/api/chat/getItem` | X | 채팅 프로필 |
| `/api/chat/chatConnect` | O | 채팅 연결 시작 |
| `/api/chat/chatStart` | O | 채팅 세션 시작 |
| `/api/chat/chatTimer` | O | 과금 타이머 |
| `/api/chat/getRemainCoin` | O | 잔액 확인 |
| `/api/chat/getRemainTime` | O | 잔여 시간 |
| `/api/chat/chatRequestTimeAdd` | O | 시간 연장 요청 |
| `/api/chat/chatTimeAdd` | O(Callee) | 시간 연장 승인 |
| `/api/chat/sendMessage` | O | 메시지 전송 |
| `/api/chat/messageLog` | O | 메시지 로깅 |
| `/api/chat/messageLogV2` | O | 메시지 로깅 V2 |
| `/api/chat/markAsRead` | O | 읽음 처리 |
| `/api/chat/fileUpload` | O | 파일 업로드 |
| `/api/chat/chatFileDown` | O | 파일 다운로드 |
| `/api/chat/chatFail` | O | 채팅 실패 |
| `/api/chat/chatCancel` | O | 채팅 취소 |
| `/api/chat/chatReject` | O(Callee) | 채팅 거절 |
| `/api/chat/chatClosed` | O | 채팅 종료 |
| `/api/chat/chatNotify` | O | 알림 전송 |
| `/api/chat/getCalleeStatus` | X | 상담사 상태 |
| `/api/chat/absenceCheck` | X | 부재 확인 |
| `/api/chat/disconnectCheck` | O | 연결 확인 |
| `/api/chat/reConnect` | O | 재연결 |
| `/api/chat/connectCheck` | O | 연결 헬스체크 |
| `/api/chat/timeAlert` | O | 시간 경고 |
| `/api/chat/closeAlert` | O | 경고 닫기 |
| `/api/chat/getLikeList` | O | 좋아요 목록 |
| `/api/chat/chatAddLike` | O | 좋아요 |
| `/api/chat/chatDeleteLike` | O | 좋아요 취소 |
| `/api/chat/updateGreeting` | O(Callee) | 인사말 수정 |
| `/api/chat/sendGoodsChatPush` | O | 상품 채팅 푸시 |
| `/api/chat/sendShopChatPush` | O | 샵 채팅 푸시 |

### 5-5. 영상통화 (30+개)

채팅과 거의 동일한 구조. `/api/video/*` 경로. Agora SDK 연동.

### 5-6. 결제 (11개)

| 엔드포인트 | 인증 | 용도 |
|-----------|------|------|
| `/api/pay/GetMyCard` | O | 저장 카드 조회 |
| `/api/pay/SaveSimplepay` | O | 카드 저장/수정 |
| `/api/pay/DeleteSimplepay` | O | 카드 삭제 |
| `/api/pay/delAutoPayCard` | O | 자동결제 카드 삭제 |
| `/api/stripe/createSetupIntent` | O | Stripe 카드 등록 |
| `/api/stripe/createPaymentIntent` | O | Stripe 결제 |
| `/api/pay/Naverpayorder` | O | 네이버페이 |
| `/api/pay/Tosspayorder` | O | 토스페이 |
| `/api/pay/insertInAppCoinOrder` | O | 인앱 코인 구매 |

### 5-7. 마이페이지 (22개)

| 엔드포인트 | 용도 |
|-----------|------|
| `/api/mypage/getCounselList` | 상담 이력 |
| `/api/mypage/getCoinList` | 코인 거래 이력 |
| `/api/mypage/getPayList` | 결제 이력 |
| `/api/mypage/getMyQuestion` | 내 Q&A |
| `/api/mypage/getMyCommentList` | 내 댓글 |
| `/api/mypage/getMyCommentAbleList` | 댓글 가능 목록 |
| `/api/mypage/insertMyComment` | 리뷰 작성 |
| `/api/mypage/couponIssueByFirstCommentWrite` | 첫 리뷰 쿠폰 |
| `/api/mypage/getMyAlarm` | 알림 목록 |
| `/api/mypage/AutopayRuleSave` | 자동충전 규칙 |
| `/api/mypage/AutopayCardSave` | 자동충전 카드 |
| `/api/mypage/AutopayUsechange` | 자동충전 토글 |
| `/api/mypage/Registcoupon` | 쿠폰 등록 |
| `/api/mypage/insertCoinByCoupon` | 쿠폰 사용 |
| `/api/mypage/getMyCouponList` | 내 쿠폰 목록 |
| `/api/mypage/getRewardHistory` | 리워드 이력 |
| `/api/mypage/getChatList` | 채팅 이력 |
| `/api/mypage/getVideoList` | 영상통화 이력 |

### 5-8. 상담사 관리 (35+개), 상품 (30+개), 샵 (25+개)

상담사(Callee) 전용 대시보드, 디지털 상품(Goods) CRUD, 오프라인 샵(Shop) 예약 관리.
모두 Callee 인증 필수.

### 5-9. 이벤트 (19개), 게시판 (10개), 예약 (8개), 기타

이벤트 참여, 게시판 CRUD, 예약 관리, 테마, 특가, 클래스 등.

---

## 6. 상태 관리 패턴

### as-is

```
전역 변수: A_IS_APP, IS_AOS, IS_IOS, IS_LOGIN, IS_MOBILE, A_URL, CertSuccess
jQuery: data-* 속성, hidden input, $(form).serialize()
쿠키: CSRF_TOKEN, main_event, isReversed, viewMode
세션스토리지: History.store (브라우저 히스토리)
```

### to-be 매핑

| as-is | to-be | 위치 |
|-------|-------|------|
| A_IS_APP, IS_AOS, IS_IOS | `useDeviceStore` | store/useDeviceStore.js |
| IS_LOGIN + member 데이터 | `useAuthStore` | store/useAuthStore.js |
| CertSuccess + 타이머 | `useCertStore` 또는 컴포넌트 local state | useState |
| jQuery form serialize | React 제어 컴포넌트 | useState per field |
| 쿠키 관리 | `lib/cookies.js` 서버 액션 | 이미 구축됨 |

---

## 7. 폼 검증 규칙 상세

| 필드 | 규칙 | 에러 메시지 패턴 |
|------|------|-----------------|
| 이메일 (ac_id) | required, email 형식, 서버 유니크 체크 | 서버 응답 msg |
| 비밀번호 (ac_password) | 6~16자, 복합 문자 | 서버 응답 msg |
| 닉네임 (ac_nick) | 2~12자, 일본어+영숫자+대시, 금칙어, 유니크 | 서버 응답 msg |
| 전화번호 (cr_phone) | required, 숫자만 | — |
| 카드번호 | 16자리 숫자 (하이픈 제거) | .length != 16 |
| 생년월일 | 8자리 YYYYMMDD | !/^[0-9]{8}$/ |
| 카드 PW | 앞 2자리 숫자 | !/^[0-9]{2}$/ |
| 결제 PIN | 6자리 숫자, 연속 동일 3개 불가 | !/^[0-9]{6}$/ |

**특이사항**: 대부분의 검증이 서버에서 수행되고 클라이언트는 서버 응답 `data.msg`를 표시하는 패턴. 클라이언트 검증은 최소한.

---

## 8. UI 인터랙션 패턴

### 팝업/모달

| 타입 | 클래스 | 용도 |
|------|--------|------|
| 중앙 모달 | `.popup01` | 에러/확인 메시지 |
| 슬라이드 팝업 | `SlidePopup` | SNS 공유, 상세정보 |
| 오버레이 | `.simplepay-wrap` | 결제 UI |
| 결과 팝업 | `.roulette-result-popup` | 이벤트 결과 |
| 변경 완료 | `.pop_change_complete` | 정보 변경 성공 |

### 로딩 패턴

```javascript
// GIF 스피너 오버레이
loadingEvent() → #full-loading-wrap에 GIF 추가
defaultLoadingRemove() → 300ms 페이드아웃 후 제거

// 커스텀 로딩 (콜백 지원)
this.customLoading = function() { ... };
this.customLoadingRemove = function() { ... };
```

### 네비게이션

```javascript
// 페이지 이동
document.location.href = url;
location.href = url;

// 전화 프로토콜
location.href = "tel:" + number;

// 앱스토어
location.href = 'market://details?id=...' (Android)
location.href = 'itms-apps://itunes.apple.com/app/...' (iOS)

// 브라우저 히스토리
History.pushState / History.replaceState (jquery.history.js)
```

---

## 9. 보안 패턴

| 항목 | as-is | 평가 | to-be 권장 |
|------|-------|------|-----------|
| CSRF | 랜덤 32자 → Base64 → Authorization 헤더 | 비표준이지만 동작 | Next.js CSRF 미들웨어 또는 SameSite 쿠키 |
| 세션 | 커스텀 쿠키 암호화 (URL 인코딩일 뿐) | 취약 | iron-session 또는 서버 JWT |
| XSS | escapeHtml() 수동 적용 | 부분적 | React 자동 이스케이프 + DOMPurify (PHP HTML) |
| 비속어 | 클라이언트 정규식 필터 | 우회 가능 | 서버 사이드 필터 + 클라이언트 보조 |
| 결제 PIN | 6자리 숫자, 연속 동일 3개 제한 | 적절 | 동일 규칙 유지 |

---

## 10. to-be 아키텍처 이식 매핑

### Tier 1 — 즉시 이식 (프론트엔드 핵심 유틸)

| 모듈 | as-is 소스 | to-be 파일 | 설명 |
|------|-----------|-----------|------|
| 네이티브 브릿지 | common.js:638-652 | `lib/nativeBridge.js` | AppConnector + webkit 통합 |
| 앱/웹 판별 | HeaderOutline.php | `hooks/useDeviceRole.js` | UA 파싱 + devicerole 쿠키 |
| 인앱 탈출 | direct.js | `hooks/useInAppEscape.js` | 마운트 시 자동 실행 |
| Adjust 트래킹 | adjust_init.js + adjust_event.js | `lib/adjustTracker.js` | 이벤트 상수 + 트래킹 유틸 |
| API 클라이언트 | AppCsrfAjax.js | `lib/apiClient.js` | fetch 래퍼 (중복 방지, 로딩) |
| SMS 타이머 | member.js viewCountdown | `hooks/useCountdown.js` | 커스텀 훅 |
| 소셜 공유 | sns_share.js | `hooks/useSocialShare.js` | Kakao/FB/LINE |
| 앱스토어 링크 | AppLink.php | `lib/appStoreLink.js` | 플랫폼별 스토어 URL |

### Tier 2 — 기능 구현 시 참조

| 모듈 | 참조 포인트 | 비고 |
|------|-----------|------|
| 회원가입 플로우 | 9단계 순차 검증 | 단계별 서버 검증 패턴 유지 |
| 로그인 플로우 | ID→PW 2단계 | 서버 응답 기반 에러 처리 |
| SimplePay 카드 등록 | 16자리+생년월일+PW2자리+PIN6자리 | 검증 규칙 그대로 |
| Stripe 결제 | SetupIntent → PaymentIntent | Stripe React SDK로 전환 |
| 채팅 | SendBird V1+V2 듀얼 | SendBird JS SDK (React 래퍼) |
| 무한 스크롤 | Items 프로토타입 | IntersectionObserver + useState |
| 룰렛 | CSS transform + transitionend | Framer Motion 또는 CSS 유지 |

### Tier 3 — 참조만 (백엔드에서 RESTful API 명세로 제공 예정)

| 도메인 | 엔드포인트 수 | 비고 |
|--------|-------------|------|
| Member | 22 | 가입/로그인/프로필 |
| Items/Chat/Video | 80+ | 3개 서비스 유형 (거의 동일 구조) |
| Pay | 11 | Stripe + 간편결제 |
| Mypage | 22 | 이력/설정/쿠폰 |
| Callee | 35+ | 상담사 대시보드 |
| Goods | 30+ | 디지털 상품 |
| Shop | 25+ | 오프라인 예약 |
| Event | 19 | 이벤트/프로모션 |
| Board | 10 | 게시판 |
| Reservation | 8 | 예약 |

---

## 11. 핵심 아키텍처 결정 사항 (to-be 설계 시 확정 필요)

| # | 결정 사항 | as-is | to-be 선택지 |
|---|----------|-------|-------------|
| 1 | 인증 방식 | 커스텀 쿠키 (URL 인코딩) | JWT vs iron-session vs 서버 세션 |
| 2 | 네이티브 브릿지 | AppConnector + webkit.messageHandlers | 동일 프로토콜 유지 vs WKScriptMessageHandler |
| 3 | API 프록시 | 직접 호출 | Next.js API Route 프록시 (CLAUDE.md §4-3) |
| 4 | 채팅 SDK | SendBird V1+V2 | SendBird React UIKit vs 커스텀 |
| 5 | 영상통화 | Agora (PHP SDK) | Agora React SDK |
| 6 | 결제 UI | Stripe redirect | Stripe Elements (인라인) |
| 7 | 실시간 상태 | AJAX 폴링 | WebSocket vs SSE vs 폴링 유지 |
| 8 | Caller/Callee 분리 | 동일 앱, 권한 분기 | 동일 구조 유지 vs 앱 분리 |

---

## 12. 객관적 평가 — 강점과 약점

### 강점 (이식 시 유지할 것)
- **도메인 모델 성숙도**: 200+ API가 안정적으로 운영 중 — 비즈니스 로직 검증 완료
- **국가별 분기 설계**: JP/KR 분기가 명확 (전화인증, 결제수단)
- **Caller/Callee 역할 분리**: 깔끔한 권한 체계
- **단계별 서버 검증**: 클라이언트→서버 실시간 검증 패턴 (UX 우수)
- **과금 타이머 시스템**: 채팅/영상통화 시간 기반 과금 로직 성숙

### 약점 (이식 시 개선할 것)
- **.env Git 추적**: DB 비밀번호, API 키 전부 노출 → `.gitignore` 필수
- **커스텀 암호화**: URL 인코딩일 뿐, 실제 암호화 아님 → iron-session 사용
- **jQuery 의존성**: 전체 JS가 jQuery 기반 → React 상태 관리로 전환
- **프로토타입 상속**: `Object.create(AppCsrfAjax.prototype)` → ES6 클래스 또는 훅
- **전역 변수 남용**: `A_IS_APP`, `IS_LOGIN` 등 → Zustand 스토어
- **인라인 이벤트 핸들러**: PHP View에 `onclick="..."` → React 이벤트 시스템
- **에러 처리**: `alert(data.msg)` 일괄 → 토스트/인라인 에러 UI
- **HTTP 200 고정**: 모든 응답 200 → 백엔드 개선 또는 프론트에서 `response` 필드 분기 유지

---

## 13. PHP 코드 레벨 심층 분석 — 인증/회원

### 13-1. 세션 관리 (BaseController.initController)

```
1. 쿠키 'hdata' 존재 확인
2. custom_decrypt() → ac_id, cr_code 추출 (URL 인코딩일 뿐, 진짜 암호화 아님)
3. tb_account에서 ac_id로 회원 조회
4. ac_status 검증: 2(활성) 또는 4(프리미엄)만 허용
5. $this->member 객체에 캐싱 (모든 하위 컨트롤러에서 접근)
6. ce_code 있으면 상담사 정보 추가 로드
7. Hermes 연동: 활성 채팅/영상 세션 확인
8. $this->is_login = true 설정
```

### 13-2. 계정 상태 코드 (CheckAccount 반환값)

| 코드 | 의미 | 처리 |
|------|------|------|
| 0 | 이력 없음 (신규) | 새 계정 생성 |
| 1 | 이미 활성 (KR 전화번호) | 거부 |
| 2 | 구형 060 유저 | 기존 계정에 새 cr_code 발급 |
| 3 | 탈퇴 계정 | 재활성화 + 새 cr_code |
| 4 | 이메일 중복 (다른 전화번호) | 거부 |
| 6 | 강제 차단 | 거부 |

### 13-3. 비밀번호 해싱

```php
// 저장: bcrypt (PASSWORD_DEFAULT)
$data['ac_password'] = password_hash($data['ac_password'], PASSWORD_DEFAULT);

// 검증: password_verify
password_verify($input_pwd, $hashed_pwd);
```

### 13-4. 쿠키 설정 패턴

```php
// 로그인 성공: 30일 (save_id=y) 또는 7일
$this->appSetCookie('hdata', custom_encrypt([...]), 86400 * 30);

// SameSite=None, Secure=true, HttpOnly=true
// 도메인: .hongcafe.com (와일드카드)
```

### 13-5. 닉네임 변경 제한

- **7일 쿨다운**: `ac_nick_date` 필드 기준
- 변경 시 `ac_nick_date = NOW()` 업데이트

### 13-6. 회원 탈퇴 (soft delete)

```
1. ac_status = 5 (삭제 플래그)
2. 모든 코인 필드 0으로 초기화
3. ac_nick = '' (닉네임 클리어)
4. tb_account_history에 감사 로그 기록 (old/new 전체 row 백업)
5. 로그인 쿠키 삭제
```

### 13-7. SMS 인증 (SMSLINK)

```
발송: SMSLINK REST API (POST JSON)
  - phone_number, delivery_type=10, character_size=6, valid_period_min=5
  - 테스트 번호: 09001111101 (실제 SMS 미발송)

저장: tb_interphone_auth (ip_ph_num, ip_cert_num, regist_date)

검증: TIMESTAMPDIFF(SECOND, regist_date, NOW()) < 181 (3분)
```

### 13-8. 인증 미들웨어 (checkNeedLogin)

```php
if (!$this->is_login || !$this->member['ac_id']) {
    return { response: 'error', msg: 'need_login', is_login: 'false' };
}
if ($isCallee && !$this->member['ce_code']) {
    return { response: 'error', msg: 'not_registered' };
}
return false;  // 인증 OK
```

### 13-9. DB 스키마 핵심 테이블

```
tb_account: ac_no(PK), ac_id(이메일), ac_password(bcrypt), cr_code(고유코드),
  cr_phone, cr_birth_year(YYYYMMDD), ac_nick, ac_nick_date, ac_status,
  ac_remain_coin/free/pay, country_code, ce_code, ac_home_set, regist_date

tb_sms_auth: sa_no(PK), ac_id, sms_ph_num, sms_cert_num, sms_type, regist_date
  → 만료: 181초

tb_account_history: ah_no(PK), ac_no, target_column, old_value, new_value,
  change_reason, backup_data(JSON 전체 row), regist_date
```

---

## 14. PHP 코드 레벨 심층 분석 — 결제/코인

### 14-1. Stripe 결제 전체 플로우

```
카드 등록 (SetupIntent):
  1. POST /api/stripe/createSetupIntent { type: 'insert'|'update' }
  2. 서버: Stripe 고객 조회/생성 → SetupIntent 생성
  3. 클라이언트: Stripe.js confirmCardSetup(clientSecret) → setupIntent_id 반환
  4. POST /api/pay/SaveSimplepay { act:'registSimeplePay', setupIntent_id, sp_password }
  5. 서버: Stripe PM 조회 → 기존 PM detach → 새 PM attach
  6. DB: tb_simplepay에 sp_bid(PM ID), sp_password(bcrypt), sp_card_name, sp_card_no(끝4자리)

결제 (PaymentIntent):
  1. POST /api/stripe/createPaymentIntent { chk_product, amount, pd_type }
  2. 서버: InsertCoinOrder() → PaymentIntent 생성 (metadata: od_code, pd_type)
  3. 클라이언트: confirmPayment() → return_url로 리다이렉트
  4. Webhook: payment_intent.succeeded → UpdateOrderResult() → InsertCoin()

자동충전 (AutoPay):
  1. 규칙 설정: min_coin(잔액 기준), pd_code(충전 상품)
  2. 트리거: ac_remain_coin < min_coin 시 자동 실행
  3. 실행: stripe.paymentIntents.create(saved PM ID + amount) → confirm
```

### 14-2. SimplePay PIN 보안

```
- 6자리 숫자: bcrypt 해싱 (password_hash/password_verify)
- 5회 실패 → 24시간 잠금 (pass_err_cnt >= 5)
- 잠금 해제: 24시간 경과 후 자동 리셋
- PIN 변경 시 에러 카운터 초기화
```

### 14-3. 코인 시스템 (CoinModel.InsertCoin)

```
ci_type='charge': 코인 추가
  - ci_charge_type='pay' → ac_remain_pay_coin 증가
  - ci_charge_type='free' → ac_remain_free_coin 증가

ci_type='use': 코인 차감
  - 무료 코인 우선 소진 → 부족분은 유료 코인에서 차감
  - ac_remain_coin = free + pay

ci_type='refund': 환불
  - charge 카운터 차감 + refund 카운터 증가
  - 쿠폰 연동 시 쿠폰 상태 복원

중복 방지: CheckCoinInfo(od_code) → 동일 주문 재충전 차단
코인백 이벤트: charge + pay 타입 시 processCoinBackEvent() 자동 실행
```

### 14-4. 결제 게이트웨이 통합 구조

```
InsertCoinOrder(pg_code, pd_code, pay_method, member, ...) → 주문 생성
  ↓
[게이트웨이별 분기]
  - 'stripe' → PaymentIntent
  - 'stripe_auto' → 저장된 PM으로 자동 결제
  - 'nice_bis' → NicePay 폼 POST
  - 'nice_simple' → NicePay 간편결제
  - 'naver_pay' → 네이버페이 리다이렉트
  - 'toss_pay' → 토스페이 API
  - 'paypal' → PayPal Checkout
  ↓
UpdateOrderResult(od_code, od_status='paid', ...) → 코인 지급
```

### 14-5. VAT 계산

```
일본 (Stripe): 금액 × 1.1 (10% 소비세)
한국 (NicePay): 원래 가격 (VAT 포함)
글로벌 (PayPal): USD 변환 (÷1000)
```

---

## 15. PHP 코드 레벨 심층 분석 — 채팅/영상/상품/예약

### 15-1. 채팅 세션 플로우 (chatConnect)

```
1. 검증: 로그인, ce_code 유효, caller≠callee, 상담사 온라인, 차단목록 체크
2. 잔액 확인: ac_remain_coin으로 최대 상담시간 계산
3. Hermes 등록: 외부 과금 서버에 세션 등록 → call_id 반환
4. tb_call_result INSERT (status='insert')
5. SendBird 채팅방 생성 (room_code: CHAT-{timestamp})
6. FCM 푸시: 상담사에게 알림
7. SMS/AlimTalk: 상담사 전화번호로 문자
→ 응답: { response:'success', room_code }
```

### 15-2. 채팅 과금 타이머 (chatTimer)

```
Background Command (매분 실행):
  1. 활성 채팅방 조회 (status='on')
  2. 경과시간 vs enable_time 비교
  3. 초과 시: status='closed', 잔여 코인 차감, 양측에 종료 알림

특이사항: 첫 1분 무료, 이후 초당 과금
```

### 15-3. 영상통화 차이점

```
- 시간 사전 선택: 30/60/90분 중 택1
- 코인 사전 계산: use_coin = it_coin_price × duration / 30
- Agora 토큰 생성 (구현 일부 주석 처리됨)
- SendBird 미사용 (직접 Agora 채널)
```

### 15-4. 상품 구매 (Goods)

```
1. POST /api/goods/buyItem → 상품 정보 + 옵션 조회
2. POST /api/goods/buyConfirm → 결제 처리
3. InsertCoinOrder() + 결제 게이트웨이
4. Webhook 성공 시: UpdateOrderResultGoods() → 재고 차감 (optStockMinus/StockMinus)
5. 구매자/판매자 양측에 이메일 + FCM 발송
```

### 15-5. 오프라인 예약 (Shop)

```
예약 슬롯: 20분 간격 (REV_MIN_TERM = 20)
최소 사전 예약: 1시간 전
스케줄 구조: tb_o2o_schedule의 JSON 필드 (sales_time, rest_time, can_reserv_time)
  → 파이프 구분 ("10:00|11:00|14:00|...")
슬롯 상태: able(예약가능), com(예약완료), end(지남)
```

### 15-6. 룰렛 이벤트 (Roulette.php)

```
VIP 사용자: 전용 슬롯 (Part A=고가치, B=중가치)
일반 사용자: Part C, D, E (확률 기반 + 일일 한도)
  - C/D 한도 소진 시 확률이 E로 이관
티켓 시스템: 무료 스핀(일일 허용) + 유료 스핀(코인 소모)
```

### 15-7. FCM 듀얼 프로젝트

```
Android: hongcafejapan (fc314509b804.json)
iOS: hongcafe-bf41c (91dd93d953.json)
→ 플랫폼별 토큰 그룹핑 → 별도 FCM v1 API 호출
→ Android: notification.channel_id = 'HongCafeJapan'
→ iOS: aps.alert + aps.sound = 'default'
```

### 15-8. Hermes 통합 (외부 과금 서버)

```
목적: 실시간 과금 + 통화 관리
프로토콜: HTTP REST
내부 IP: 10.41.82.142(prod), 10.41.172.121(dev)
플로우:
  1. insertCall() → Hermes에 세션 등록 (call_id 반환)
  2. Hermes가 실제 통화시간 모니터링
  3. 종료 시 final_cost 반환 → 홍카페 측에서 코인 차감
```

---

## 16. to-be 모듈 설계 — Tier 1 (즉시 이식)

### 16-1. `lib/nativeBridge.js` — 네이티브 브릿지 통합 모듈

```javascript
// as-is: common.js appOutLink(), AppConnector 4개 메서드, webkit.messageHandlers
// to-be: 플랫폼 자동 감지 + 통합 인터페이스

const NativeBridge = {
    // 외부 링크 열기
    openExternalLink(link) {
        if (!link) return false;
        const role = getDeviceRole();
        try {
            if (role === 'android') window.AppConnector.appOutLink(link);
            else if (role === 'ios') window.webkit.messageHandlers.appOutLink.postMessage(link);
            else window.open(link, '_blank'); // 웹 fallback
        } catch (e) { window.open(link, '_blank'); }
    },

    // 채팅/통화 인터페이스 열기
    openChat(url) {
        const role = getDeviceRole();
        try {
            if (role === 'android') window.AppConnector.appConnectChat(url);
            // iOS는 별도 핸들러 없음 → URL 네비게이션
        } catch (e) { /* fallback */ }
    },

    // 채팅 종료
    closeChat(urlOrClose = 'close') {
        const role = getDeviceRole();
        try {
            if (role === 'android') window.AppConnector.chatClose(urlOrClose);
        } catch (e) { /* fallback */ }
    },

    // 앱 버전 조회
    getAppVersion() {
        try {
            if (getDeviceRole() === 'android') return window.AppConnector.getAppVersion();
        } catch (e) { return null; }
        return null;
    },

    // 전화 연결
    initiateCall(phoneNumber) {
        if (phoneNumber) window.location.href = `tel:${phoneNumber}`;
    }
};
```

### 16-2. `hooks/useDeviceRole.js` — 앱/웹 판별 훅

```javascript
// as-is: 서버 PHP에서 UA 파싱 → JS 전역변수 주입
// to-be: 클라이언트 훅 + Zustand 스토어 연동

// store/useDeviceStore.js
const useDeviceStore = create((set) => ({
    isApp: false,
    isAos: false,
    isIos: false,
    isMobile: false,
    deviceRole: '', // 'android' | 'ios' | ''
    setDevice: (info) => set(info),
}));

// hooks/useDeviceRole.js
const useDeviceRole = () => {
    const setDevice = useDeviceStore((s) => s.setDevice);
    useEffect(() => {
        const ua = navigator.userAgent.toLowerCase();
        const isAos = /android/.test(ua);
        const isIos = /iphone|ipad|ipod/.test(ua);
        const isMobile = /mobile/i.test(ua);

        // devicerole 쿠키 또는 URL 파라미터 확인
        const params = new URLSearchParams(window.location.search);
        const role = params.get('devicerole') || getCookie('devicerole') || '';
        const isApp = role === 'android' || role === 'ios';

        setDevice({ isApp, isAos, isIos, isMobile, deviceRole: role });

        // devicerole 쿠키 저장 (세션 유지)
        if (role) setCookie('devicerole', role, 30);
    }, []);
};
```

### 16-3. `hooks/useInAppEscape.js` — 인앱브라우저 탈출 훅

```javascript
// as-is: direct.js IIFE (20줄)
// to-be: Next.js 클라이언트 컴포넌트에서 마운트 시 실행

const IN_APP_REGEX = /inapp|KAKAOTALK|Line\/|FB_IAB\/FB4A|FBAN\/FBIOS|Instagram|DaumDevice\/mobile\/[^1]/i;

const useInAppEscape = () => {
    useEffect(() => {
        if (typeof window === 'undefined') return;
        const ua = navigator.userAgent;
        const body = document.body;

        // 비활성화 속성 체크
        if (body.getAttribute('__donot_urlopenlink')) return;
        if (!/mobile/i.test(ua)) return;
        if (!IN_APP_REGEX.test(ua)) return;

        const lowerUA = ua.toLowerCase();
        const domain = window.location.href.replace('https://', '');

        if (lowerUA.includes('android')) {
            window.location.href = `intent://${domain}#Intent;scheme=http;package=com.android.chrome;end`;
        } else if (/iphone|ipad|ipod/.test(lowerUA)) {
            window.location.href = window.location.href.replace(/^http/, 'googlechrome');
        }
    }, []);
};
```

### 16-4. `lib/adjustTracker.js` — Adjust 이벤트 트래킹

```javascript
// as-is: adjust_event.js + adjust_init.js (306줄)
// to-be: 이벤트 상수 + 유틸 함수

const ADJUST_EVENTS = {
    JOIN: 'v42j6a',
    PAYMENT: 'cddp06',
    FORTUNE_YEARLY: 'v2afp1',
    FORTUNE_DIVINE: 'd2tfkk',
    FORTUNE_LIFETIME: 'p8z4gf',
    FORTUNE_FEELING: 'dwgjzx',
    FORTUNE_SPOUSE: 'wkefff',
    FORTUNE_LOVE_TIMING: '4z2s85',
    FORTUNE_COMPATIBILITY: 'i05lov',
    COUNSELOR_SEARCH: 'xsvikp',
    CONSULT_060: 'yr5s0t',
    CONSULT_COIN_KR: 'yv0gs3',
    CONSULT_COIN_GLOBAL: 'm0845l',
    REVIEW: 'sfmj5a',
};

const trackEvent = (eventToken, { revenue, currency, callbackParams } = {}) => {
    try {
        if (typeof Adjust === 'undefined') return;
        const event = new AdjustEvent(eventToken);
        if (revenue) event.setRevenue(revenue, currency || 'JPY');
        if (callbackParams) {
            Object.entries(callbackParams).forEach(([k, v]) =>
                event.addCallbackParameter(k, v)
            );
        }
        Adjust.trackEvent(event);
    } catch (e) { /* silent fail */ }
};
```

### 16-5. `lib/apiClient.js` — API 클라이언트 래퍼

```javascript
// as-is: AppCsrfAjax (jQuery AJAX, 152줄)
// to-be: fetch 래퍼 + 중복 방지 + 로딩 상태

let pendingRequests = new Set();

const apiClient = async (url, data = {}, options = {}) => {
    // 중복 요청 방지
    const requestKey = `${url}:${JSON.stringify(data)}`;
    if (pendingRequests.has(requestKey)) return null;
    pendingRequests.add(requestKey);

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        const result = await response.json();

        // as-is 호환: response 필드 기반 분기
        if (result.is_login === 'false') {
            // 로그인 필요 → 리다이렉트 또는 콜백
            if (options.onAuthRequired) options.onAuthRequired();
        }

        return result;
    } catch (err) {
        if (options.onError) options.onError(err);
        return { response: 'error', msg: err.message };
    } finally {
        pendingRequests.delete(requestKey);
    }
};

// Next.js API Route 프록시 경유
const api = {
    member: {
        checkId: (ac_id) => apiClient('/api/member/checkid', { ac_id }),
        login: (data) => apiClient('/api/member/loginuser', data),
        // ... 도메인별 메서드
    },
};
```

### 16-6. `hooks/useCountdown.js` — SMS 인증 카운트다운

```javascript
// as-is: member.js viewCountdown (전역함수, DOM 직접 조작)
// to-be: React 훅 (상태 기반)

const useCountdown = (initialSeconds = 0) => {
    const [seconds, setSeconds] = useState(initialSeconds);
    const [isActive, setIsActive] = useState(false);
    const intervalRef = useRef(null);

    const start = useCallback((sec) => {
        setSeconds(sec || initialSeconds);
        setIsActive(true);
    }, [initialSeconds]);

    const stop = useCallback(() => {
        setIsActive(false);
        setSeconds(0);
    }, []);

    useEffect(() => {
        if (!isActive || seconds <= 0) {
            if (isActive && seconds <= 0) setIsActive(false);
            return;
        }
        intervalRef.current = setInterval(() => {
            setSeconds((prev) => prev - 1);
        }, 1000);
        return () => clearInterval(intervalRef.current);
    }, [isActive, seconds]);

    const formatted = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

    return { seconds, formatted, isActive, start, stop };
};
// 사용: const { formatted, start } = useCountdown(300); // 5분
```

### 16-7. `hooks/useSocialShare.js` — 소셜 공유

```javascript
// as-is: sns_share.js AppSnsShare 프로토타입
// to-be: React 훅

const useSocialShare = () => {
    const shareKakao = useCallback(({ title, description, imageUrl, webUrl }) => {
        if (!window.Kakao?.Link) return;
        Kakao.Link.sendDefault({
            objectType: 'feed',
            content: { title, description, imageUrl, link: { webUrl, mobileWebUrl: webUrl } },
            buttons: [{ title: '웹으로 보기', link: { webUrl, mobileWebUrl: webUrl } }],
        });
    }, []);

    const shareLine = useCallback(({ title, webUrl }) => {
        const url = `https://social-plugins.line.me/lineit/share?url=${encodeURIComponent(webUrl)}&title=${encodeURIComponent(title)}`;
        window.open(url, '_blank', 'width=500,height=600');
    }, []);

    const shareFacebook = useCallback(({ webUrl }) => {
        if (!window.FB?.ui) return;
        FB.ui({ method: 'share', href: webUrl });
    }, []);

    return { shareKakao, shareLine, shareFacebook };
};
```

### 16-8. `lib/appStoreLink.js` — 앱스토어 링크

```javascript
// as-is: AppLink.php linkMarket()
// to-be: 유틸 함수

const APP_STORE_LINKS = {
    android: {
        market: 'market://details?id=kr.co.hongcafe.mobile',
        web: 'https://play.google.com/store/apps/details?id=kr.co.hongcafe.mobile',
    },
    ios: {
        market: 'itms-apps://itunes.apple.com/app/1463346817',
        web: 'https://itunes.apple.com/us/app/%ED%99%8D%EC%B9%B4%ED%8E%98/id1463346817',
    },
};

const openAppStore = (platform) => {
    const links = APP_STORE_LINKS[platform] || APP_STORE_LINKS.android;
    // 마켓 앱으로 시도 → 실패 시 웹 fallback
    window.location.href = links.market;
    setTimeout(() => { window.location.href = links.web; }, 1000);
};
```

---

## 17. to-be 모듈 설계 — Tier 2 (기능 구현 시 참조)

### 17-1. 인증 스토어 설계

```javascript
// store/useAuthStore.js
const useAuthStore = create((set) => ({
    isLogin: false,
    member: null, // { ac_id, cr_code, cr_phone, ac_nick, ac_status, ac_remain_coin, ce_code, country_code }
    setMember: (member) => set({ isLogin: true, member }),
    clearMember: () => set({ isLogin: false, member: null }),
}));
```

### 17-2. 폼 검증 유틸 설계

```javascript
// lib/validators.js — as-is 검증 규칙 1:1 이식
const validators = {
    email: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v),
    password: (v) => v.length >= 6 && v.length <= 16,
    nickname: (v) => v.length >= 2 && v.length <= 12,
    phone: (v) => /^\d+$/.test(v),
    pin: (v) => /^[0-9]{6}$/.test(v) && !/(.)\1{2,}/.test(v), // 연속 동일 3개 불가
    cardNumber: (v) => v.replace(/-/g, '').length === 16,
    cardPwd: (v) => /^[0-9]{2}$/.test(v),
    birthDate: (v) => /^[0-9]{8}$/.test(v), // YYYYMMDD
};
```

### 17-3. Next.js API Route 프록시 구조

```
app/api/
  ├── member/
  │   ├── checkid/route.js       → POST → PHP /api/member/checkid
  │   ├── login/route.js         → POST → PHP /api/member/loginuser
  │   ├── join/route.js          → POST → PHP /api/member/joinuser
  │   ├── sendcert/route.js      → POST → PHP /api/member/sendglobalcert
  │   └── confirmcert/route.js   → POST → PHP /api/member/confirmglobalcert
  ├── items/
  │   ├── getListMobile/route.js → POST → PHP /api/items/getListMobile
  │   └── getItem/route.js       → POST → PHP /api/items/getItem
  ├── chat/
  │   ├── connect/route.js       → POST → PHP /api/chat/chatConnect
  │   └── status/route.js        → POST → PHP /api/chat/getCalleeStatus
  ├── pay/
  │   ├── stripe/route.js        → POST → PHP /api/stripe/createPaymentIntent
  │   └── mycard/route.js        → POST → PHP /api/pay/GetMyCard
  ├── mypage/
  │   └── coin/route.js          → POST → PHP /api/mypage/getCoinList
  └── fcm/
      └── token/route.js         → POST → PHP /api/fcm/updateUserToken
```

**프록시 패턴 (CLAUDE.md §4-3 준수)**:
```javascript
// app/api/member/login/route.js
export async function POST(request) {
    const body = await request.json();
    const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/member/loginuser`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams(body),
    });
    const data = await response.json();
    return Response.json(data);
}
```

---

## 18. 메모리 저장 계획

플랜 모드 종료 후 아래 항목을 프로젝트 메모리에 저장:

1. **`project_hongcafe_japan_analysis.md`** — as-is 프로젝트 정체, 기술 스택, 아키텍처 요약
2. **`reference_native_bridge.md`** — 네이티브 브릿지 패턴 (AppConnector, webkit, WVJBridge, Adjust)
3. **`reference_api_endpoints.md`** — 200+ API 엔드포인트 매핑 (도메인별)
4. **`reference_business_logic.md`** — 핵심 비즈니스 로직 (인증 플로우, 코인 시스템, 과금 타이머)
