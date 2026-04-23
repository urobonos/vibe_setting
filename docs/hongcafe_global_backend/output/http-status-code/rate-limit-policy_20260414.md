# Rate Limit 정책 제안서

> Rate Limit 정책 제안서

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-14 |
| 유형 | report |
| 상태 | 승인됨 |

- **작성일:** 2026.04.14
- **대상:** hongcafe_global_backend API 전체 (~311개 엔드포인트)
- **현행:** 전체 API 일괄 IP당 60회/60초
- **제안:** 7개 등급 분류, 그룹별 차등 적용

---

## 1. 현행 분석

| 항목 | 현행 설정 |
|------|-----------|
| 제한 방식 | IP 기반 (클라이언트 IP md5 해시) |
| 저장소 | 파일 캐시 (writable/cache) |
| 기본값 | 60회 / 60초 |
| 적용 범위 | api/* 전체 일괄 |
| 개별 설정 | 없음 |

**현행 문제점:**

| 문제 | 설명 |
|------|------|
| 일괄 적용 | 로그인과 채팅 타이머가 같은 한도 |
| SMS/이메일 미분리 | 발송 비용이 드는 API에 별도 제한 없음 |
| Webhook 제한 | Stripe webhook이 rate limit에 걸릴 수 있음 |
| PBX 내부 API | 서버 간 통신에 불필요한 제한 적용 |
| 파일 캐시 한계 | 고트래픽 시 I/O 병목, 다중 서버 시 카운터 분산 |

---

## 2. 등급 분류 기준

| 등급 | 한도 | 윈도우 | 대상 | 설계 근거 |
|------|------|--------|------|-----------|
| **S** Critical | 5회 | 60초 | 인증, SMS/이메일 | OWASP: 분당 3-5회. NIST SP 800-63B: 지수적 지연 |
| **A** Strict | 10회 | 60초 | 결제, 회원변경 | PCI DSS v4.0 Req 8.3.4. OWASP API4:2023 |
| **B** Write | 30회 | 60초 | 일반 POST 쓰기 | Cloudflare: 쓰기=읽기의 1/3-1/5. GitHub: 30회/분 |
| **C** Standard | 60회 | 60초 | 인증 사용자 조회 | RFC 6585. GitHub: 인증 60회/분 |
| **D** Public | 120회 | 60초 | 비인증 공개 조회 | Cloudflare: 공개 읽기 분당 100-200회 |
| **E** Realtime | 300회 | 60초 | 채팅/통화 실시간 | Twilio Chat: 분당 200-300회 |
| **X** Exempt | 없음 | -- | Webhook, PBX | Stripe: webhook rate limit 제외 권장 |

---

## 3. 그룹별 정책

### S등급 -- Critical (5회/60초)

> **근거:** OWASP Authentication Cheat Sheet -- Implement rate limiting after 3-5 failed attempts
> NIST SP 800-63B Section 5.2.2 -- Throttle accounts after repeated failed authentication

| 그룹 | API 경로 | 사유 |
|------|----------|------|
| 로그인 | POST /api/members/login-user | Credential stuffing, brute force 방지 |
| SMS 인증 | POST /api/members/send-global-cert | 발송 비용 + 스미싱 악용 방지 |
| 이메일 인증 | POST /api/members/send-mail-cert | 발송 비용 + 스팸 방지 |
| 비밀번호 찾기 인증 | POST /api/members/find-password-cert | 계정 탈취 시도 방지 |
| 아이디 찾기 인증 | POST /api/members/find-id-cert | 계정 열거 방지 |

---

### A등급 -- Strict (10회/60초)

> **근거:** PCI DSS v4.0 Requirement 8.3.4 -- Limit repeated access attempts
> OWASP API4:2023 -- Set rate limits for sensitive operations

| 그룹 | API 경로 | 사유 |
|------|----------|------|
| 회원가입 | POST /api/members/join-user | 대량 계정 생성 방지 |
| 비밀번호 변경 | POST /api/members/change-passwd | 무차별 시도 방지 |
| 비밀번호 초기화 | POST /api/members/reset-password | 동일 사유 |
| 회원 탈퇴 | DELETE /api/members/delete-user | 비가역 작업 보호 |
| 전화번호 변경 | POST /api/members/update-phone | 계정 탈취 수단 |
| 카드 저장 | POST /api/mypage/autopay-card-save | 결제 정보 보호 |
| 쿠폰 등록 | POST /api/mypage/regist-coupon | 쿠폰 어뷰징 방지 |
| 코인 충전 (쿠폰) | POST /api/mypage/insert-coin-by-coupon | 동일 사유 |
| 룰렛 | POST /api/roulettes/run | 리워드 어뷰징 방지 |
| 결제 생성 | POST /api/stripe/create-payment-intent | 결제 금액 조작 방지 |
| 결제 수단 등록 | POST /api/stripe/create-setup-intent | 카드 정보 보호 |
| 간편결제 등록 | POST /api/pay/save-simplepay | 결제 정보 보호 |
| 간편결제 삭제 | DELETE /api/pay/delete-simplepay | 비가역 작업 보호 |
| 자동결제 카드 삭제 | DELETE /api/pay/del-auto-pay-card | 비가역 작업 보호 |
| 네이버페이 주문 | POST /api/pay/naverpay-order | 결제 어뷰징 방지 |
| 토스페이 주문 | POST /api/pay/tosspay-order | 결제 어뷰징 방지 |
| 인앱 코인 주문 | POST /api/pay/insert-in-app-coin-order | 결제 어뷰징 방지 |

---

### B등급 -- Write (30회/60초)

> **근거:** Cloudflare -- Write endpoints should be 3-5x stricter than read
> GitHub REST API -- 30 requests per minute for content creation

| 그룹 | API 경로 패턴 | 사유 |
|------|---------------|------|
| 댓글/후기 작성 | insert-column-comment, insert-my-comment, insert-comment-reply | 스팸 방지 |
| 신고 | comment-report, comment-report-notify | 대량 신고 방지 |
| 알림 등록/삭제 | insert-alarm, delete-alarm | 리소스 남용 방지 |
| 문의 등록 | insert-inquiry, insert-recruit | 스팸 방지 |
| 좋아요 | caller-add-like, chat-add-like, posting-like | 어뷰징 방지 |
| 메모 저장 | memo-save, goods-greeting-update | 빈도 제한 |
| 예약 등록 | insert-reservation | 중복 예약 방지 |
| 차단 관리 | save-reject, delete-reject | 남용 방지 |
| 파일 업로드 | file-upload, upload-chat-file | 서버 부하 + 저장 비용 |
| 닉네임 변경 | change-nick | 빈도 제한 |
| QnA 작성 | insert-item-qna, update-item-qna-reply | 스팸 방지 |
| 이벤트 참여 | attend-event-join, keyword-event, coupon-event | 어뷰징 방지 |
| 자동결제 설정 | autopay-rule-save, autopay-usechange | 빈도 제한 |
| 상태 변경 (Callee) | update-call-status, update-chat-status, update-partner | 빈도 제한 |
| 포스팅 CRUD (Callee) | post-insert, post-modify, post-delete | 스팸 방지 |
| Content CRUD | POST/PUT/DELETE notices, faqs, banners | 관리자 API |
| 상품 구매/확인 | goods/buy-item, goods/buy-confirm, shop/buy-shop | 중복 주문 방지 |
| 주문 취소/환불 | goods/buy-cancel, goods/refund-success, shop/shop-cancel, shop/refund-success | 남용 방지 |
| 상품 관리 (상담사) | goods/update-goods, shop/update-shop, goods/callee-goods-file-upload | 빈도 제한 |

---

### C등급 -- Standard (60회/60초) [현행 기본값]

> **근거:** GitHub REST API -- Authenticated requests: 60 per minute
> RFC 6585 Section 4 -- 합리적 임계값은 서비스 특성에 따라 결정

| 그룹 | API 경로 패턴 | 사유 |
|------|---------------|------|
| 마이페이지 조회 | get-counsel-list, get-coin-list, get-pay-list, get-my-* | 인증 사용자 일반 조회 |
| 상담사 정보 조회 | get-activity-info, get-call-status, get-reply-*-cnt | 인증 사용자 조회 |
| 상담사 목록 조회 | get-callee-like-list, get-callee-ing-list | 인증 사용자 조회 |
| 채팅 목록 | get-list-pc, get-list-mobile, get-chat-list | 인증 사용자 조회 |
| 예약 조회 | get-my-reservation, get-callee-reservation-list | 인증 사용자 조회 |
| 결제 이력 | payback/getList | 인증 사용자 조회 |
| ID/닉네임 중복 확인 | check-id, check-login-id, check-nick | 회원가입 폼 검증 |
| 인증코드 확인 | confirm-global-cert, confirm-id-cert, confirm-mail-cert | 입력 검증 |
| 토큰 갱신/로그아웃 | POST /api/auth/refresh, /api/auth/logout | 세션 관리 |
| FCM 토큰 | POST /api/fcm/* | 앱 시작 시 1회 |

> 별도 설정 불필요 -- Filters.php 글로벌 기본값(60/60) 적용

---

### D등급 -- Public Read (120회/60초)

> **근거:** Cloudflare -- Public read endpoints tolerate 2-3x higher limits

| 그룹 | API 경로 패턴 | 사유 |
|------|---------------|------|
| 상품 목록/댓글 | items/get-list, items/get-comment | 비인증 메인 화면 |
| 채팅 상품 조회 | chats/get-item, get-like-list, get-item-qna-list | 비인증 상세 |
| 포스팅 조회 | get-posting-list, posting-detail, get-posting-comments | 비인증 커뮤니티 |
| 공지/FAQ/배너 | GET /api/notices, faqs, banners | 비인증 컨텐츠 |
| 서비스 목록 | get-service-list-mobile* | 비인증 메인 |
| 이벤트 조회 | get-event, show-event-contents | 비인증 이벤트 |
| 게시판 조회 | get-inquiry, get-notice, get-posting | 비인증 게시판 |
| SNS 공유/기타 | profile-sns, board-sns, get-list-group, get-theme-list | 비인증 조회 |
| Gate/Whoami | GET /api/gate, /api/whoami | 서버 라우팅/진단 |

---

### E등급 -- Realtime (300회/60초)

> **근거:** 실시간 상담 서비스 특성상 HTTP 폴링 빈도 높음 (초당 2~5회)
> Twilio Chat API: 분당 200~300회 허용

| 그룹 | API 경로 패턴 | 사유 |
|------|---------------|------|
| 통화 연결/종료 | call-connect, classcall-connect, shopcall-connect | 실시간 상담 |
| 통화 상태 | callee-online-call, get-call-connect-able-list | 실시간 폴링 |
| 채팅 연결/종료 | chat-connect, chat-start, chat-closed, chat-cancel, chat-reject | 실시간 채팅 |
| 채팅 타이머 | chat-timer, time-alert, close-alert | 초 단위 폴링 |
| 채팅 메시지 | message-log, message-log-v2, mark-as-read | 실시간 메시지 |
| 연결 상태 확인 | connect-check, disconnect-check, absence-check | 하트비트 |
| 코인/시간 잔량 | get-remain-coin, get-remain-time, chat-time-add | 실시간 잔량 |
| 상담사 상태 | get-callee-status, chat-fail, chat-connect-fail | 실시간 상태 |
| 채팅 푸시 | send-goods-chat-push, send-shop-chat-push, chat-notify | 실시간 알림 |
| 상품채팅/숍채팅 | goods-chats/*, shop-chats/* 전체 | 실시간 상담 |
| 팝업/파일 | get-popup-info, chat-file-down | 통화/채팅 중 |

---

### X등급 -- Exempt (제한 없음)

> **근거:** Stripe Webhook Integration Guide -- Do not rate limit webhook endpoints
> 내부 서버 간 통신(PBX)은 API Key 인증 신뢰 구간

| 그룹 | API 경로 패턴 | 사유 |
|------|---------------|------|
| Stripe Webhook | POST /api/stripe/webhook | 결제 알림 유실 방지 |
| PBX 내부 API | POST /api/pbx/* (13개) | API Key 인증 서버 간 통신 |
| Hermes 내부 API | POST /api/hermes/* (2개) | 내부 서비스 연동, 서버 간 통신 |
| 앱 쿠키 설정 | POST /api/events/set-app-cookie | 단순 쿠키, 부작용 없음 |

---

## 4. 적용 방법

### 4-1. RateLimitFilter 내부 제외 경로 추가

CI4 `$filters` 배열은 `except` 키를 지원하지 않는다 (`$globals` 전용).
기존 AuthFilter, CsrfTokenFilter와 동일하게 **EXCLUDED_PATHS 상수 패턴**을 사용한다.

```php
// RateLimitFilter.php에 추가
private const EXCLUDED_PATHS = [
    'api/stripe/webhook',
    'api/pbx/',          // prefix match
    'api/events/set-app-cookie',
    'api/hermes/',       // 내부 서비스 연동
];

public function before(RequestInterface $request, $arguments = null)
{
    $uri = trim($request->getUri()->getPath(), '/');
    foreach (self::EXCLUDED_PATHS as $path) {
        if (str_starts_with($uri, $path)) {
            return null; // X등급 — 제한 없음
        }
    }
    // ... 기존 로직
}
```

Filters.php는 현행 유지:
```php
"ratelimit" => ["before" => ["api/*"]],
```

### 4-2. 모듈 Routes.php에서 등급 오버라이드

라우트 레벨 필터가 글로벌 필터보다 우선 적용된다.

```php
// S등급 (5/60) — Member 모듈
$routes->post('members/login-user', ..., ['filter' => 'ratelimit:5,60']);
$routes->post('members/send-global-cert', ..., ['filter' => 'ratelimit:5,60']);
$routes->post('members/send-mail-cert', ..., ['filter' => 'ratelimit:5,60']);

// A등급 (10/60) — Member 모듈
$routes->post('members/join-user', ..., ['filter' => 'ratelimit:10,60']);
$routes->delete('members/delete-user', ..., ['filter' => 'ratelimit:10,60']);

// B등급 (30/60) — Board 모듈 (그룹 레벨)
$routes->group('api/boards', ['filter' => 'ratelimit:30,60'], ...);

// D등급 (120/60) — Commerce 모듈 (공개 조회)
$routes->group('api/items', ['filter' => 'ratelimit:120,60'], ...);

// E등급 (300/60) — Chat 모듈 (실시간)
$routes->group('api/chats', ['filter' => 'ratelimit:300,60'], ...);
```

---

## 5. 등급별 요약

| 등급 | 한도 | 대상 API 수 | 키워드 |
|------|------|-------------|--------|
| **S** Critical | 5/60초 | ~5개 | 로그인, SMS, 이메일 인증 |
| **A** Strict | 10/60초 | ~18개 | 회원가입, 결제, 비밀번호, 탈퇴 |
| **B** Write | 30/60초 | ~55개 | 댓글, 신고, 알림, 파일업로드, 구매, 이벤트 |
| **C** Standard | 60/60초 | ~100개 | 인증 사용자 조회 (기본값) |
| **D** Public | 120/60초 | ~30개 | 비인증 공개 조회 |
| **E** Realtime | 300/60초 | ~40개 | 채팅, 통화, 실시간 폴링 |
| **X** Exempt | 없음 | ~17개 | Webhook, PBX, Hermes, 헬스체크 |

---

## 6. 참고 자료

| 출처 | 내용 | 문서 |
|------|------|------|
| OWASP | Authentication Cheat Sheet -- Brute Force Prevention | cheatsheets/Authentication_Cheat_Sheet |
| OWASP | API Security Top 10 (2023) -- API4 Unrestricted Resource Consumption | owasp.org/API-Security/editions/2023 |
| NIST | SP 800-63B -- Throttling Mechanisms | pages.nist.gov/800-63-3 |
| PCI DSS | v4.0 Req 8.3.4 -- Authentication attempt limiting | pcisecuritystandards.org |
| RFC 6585 | Section 4 -- 429 Too Many Requests | tools.ietf.org/html/rfc6585 |
| GitHub | REST API Rate Limiting -- 60 req/min | docs.github.com/rest/rate-limit |
| Stripe | API Rate Limits + Webhook best practices | stripe.com/docs/rate-limits |
| Cloudflare | Rate Limiting Best Practices | developers.cloudflare.com/waf/rate-limiting-rules |
| Twilio | Chat API Limits -- 200-300 req/min | twilio.com/docs/chat |
| AWS | API Gateway Throttling | docs.aws.amazon.com/apigateway |

## 체크리스트

- [x] 문서 작성 완료

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-14 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
