# 2026.04.10 일일 작업 요약

## <PROJECT_BE> — 전체 API 검증 + CSRF 방어 구현 (34 커밋)

### 세션 1: 전체 API 컨트롤러 검증 + 핫픽스

- **전체 API 감사** (Member 제외, 12개 모듈 병렬 검증)
  - Critical 6건: Event 라우트-메서드 불일치 2, Event 보상 로직 반전 2, Commerce Items 라우트 없는 메서드 2
  - High 14건: (:any) 와일드카드 보안 노출, 인증 누락 다수, Fatal Error (Call shopCallConnect, Goods orderInfo), Stripe webhook 타입 오류
  - Medium 30건+: 응답 표준 위반, 검증 누락, dead code, mixed 객체/배열 접근
- **SDD 문서 19개 생성** (api-docs/, ~268개 엔드포인트):
  - auth(8), board(12), call(14), callee(38), pbx(13), chat(44), goodschat(6), shopchat(2)
  - items(18), goods(29), shop(26), content(16), event(10), payment(10), fcm(2)
  - reservation(10), service(7), social(3)
- **핫픽스 커밋 체인:**
  - Auth: setCookie 정규화 + SameSite=Lax + hdata 호환
  - Event: 라우트 불일치 + 보상 로직 반전 수정
  - Commerce: 라우트 수정 + Shop 인증 추가
  - Board: BoardService import + isset 버그 + SQL escape
  - Call: shopCallConnect Fatal + 인증 추가 + named binding
  - Chat: saveItemPrice 인증 추가
  - Payment: Stripe typo + webhook fix + Pay 타입 캐스팅

### 세션 2: CSRF Signed Double Submit Cookie 방어 구현

- CSRF 정책 재검토: CLAUDE.md 정책 vs 실제 구현 불일치 발견 (SameSite 단일 방어층)
- OWASP 근거 조사: CSRF Prevention Cheat Sheet, SameSite 커버리지 95.6%
- **구현 완료:**
  - `CsrfTokenService.php` 신규 (HMAC-SHA256 토큰 생성/검증)
  - `CsrfTokenFilter.php` 신규 (Double Submit 검증 필터)
  - `AuthController.php` 수정 (login/refresh/logout CSRF 쿠키 통합)
  - `Filters.php`, `Cors.php`, `CLAUDE.md` 수정
- 단위 테스트 12건, 전체 테스트 2,269건 통과

### 세션 3: 리팩토링 + 추가 수정

- **respondLegacy → 표준 응답 전환** (10개 모듈): Board, Call, Chat, Commerce, Content, Event, Notification, Payment, Reservation, Social
- Content: 응답 body status 필드 제거 (HTTP SSOT)
- Reservation: payCoin + refund dead code 제거
- Chat: missing return 5건 + reConnect dead code 제거
- (:any) 와일드카드 → 명시적 라우트 전환 (Call, Chat, Member)
- Service: 5개 라우트 등록 — 프로덕션 404 해소
- Content: Service use import 추가 — 프로덕션 500 해소
- Swagger YAML 17개 생성 + api-docs 경로 통합
- Auth: crypto_helper + register 핫픽스
- CsrfTokenFilter getPath() 수정 + 테스트 갱신
- Member: Mypage CouponIssueService use import 추가

### 잔여 작업

- `.env` + 프로덕션에 `CSRF_SECRET` 환경변수 수동 추가 필요
- AuthController::login() hdata 쿠키 누락 — 레거시 BaseController 호환 필요 (승인 대기)
