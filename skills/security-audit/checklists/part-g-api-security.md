# Part G: API 보안 체크리스트

**적용 시점:** API 엔드포인트 생성/수정, 인증/인가 로직 변경, 외부 API 연동 시

| 기반 표준 | URL |
|----------|-----|
| OWASP API Security Top 10 (2023) | https://owasp.org/API-Security/editions/2023/en/0x11-t10/ |
| OWASP REST Security Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html |
| OWASP Authentication Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html |

---

## G1. Broken Object Level Authorization — API1

- [ ] 모든 API 엔드포인트에서 요청자가 해당 리소스의 소유자/접근 권한자인지 검증하는가
- [ ] 리소스 ID(숫자, UUID)를 URL에 포함할 때 소유권 검증 로직이 Service 계층에 존재하는가
- [ ] 다른 사용자의 리소스를 ID만 바꿔서 접근할 수 없는가 (IDOR 방지)
- [ ] 리스트 API에서 현재 사용자의 리소스만 반환되는가 (전체 조회 차단)
- [ ] 예측 가능한 ID(auto_increment) 대신 UUID 사용을 고려했는가
- [ ] 관계형 데이터 접근 시에도 부모 리소스의 소유권이 검증되는가

## G2. Broken Authentication — API2

- [ ] 모든 인증 엔드포인트에 Rate Limiting이 적용되어 있는가
- [ ] 토큰 만료 시간이 적절히 설정되어 있는가 (Access Token: 짧게, Refresh Token: 길게)
- [ ] 비밀번호 재설정 토큰이 1회용이며 짧은 유효기간을 가지는가
- [ ] 인증 실패 응답이 "이메일 또는 비밀번호가 올바르지 않습니다" 같은 일반 메시지를 반환하는가 (계정 열거 방지)
- [ ] API 키가 URL 쿼리 파라미터가 아닌 헤더로 전송되는가
- [ ] JWT `alg: none` 공격이 차단되어 있는가
- [ ] JWT 서명 검증이 서버 측에서 수행되는가

## G3. Broken Object Property Level Authorization — API3

- [ ] API 응답에서 클라이언트가 필요하지 않은 속성이 제외되어 있는가 (과도한 데이터 노출 방지)
- [ ] 사용자가 수정 불가한 속성(role, is_admin, created_at)이 Mass Assignment로 변경 불가능한가
- [ ] CI4 Model의 `$allowedFields`에 수정 가능한 필드만 명시되어 있는가
- [ ] API 응답 직렬화 시 민감 필드(password_hash, internal_id, 결제 정보)가 제외되는가
- [ ] 사용자 역할에 따라 반환되는 속성이 다르게 제어되는가 (관리자 vs 일반 사용자)
- [ ] `$this->request->getJSON()` 또는 `getPost()`로 받은 데이터에서 허용된 필드만 추출하는가
- [ ] 중첩 객체의 속성도 접근 제어가 적용되는가

## G4. Unrestricted Resource Consumption — API4

- [ ] API별 요청 속도 제한(Rate Limiting)이 적용되어 있는가
- [ ] 페이지네이션의 `per_page` 최대값이 서버에서 강제되는가 (클라이언트가 per_page=999999 요청 불가)
- [ ] 파일 업로드 크기 제한이 서버에서 강제되는가
- [ ] 배치/벌크 API의 처리 건수 상한이 설정되어 있는가
- [ ] 복잡한 쿼리(다중 JOIN, 서브쿼리)에 실행 시간 제한이 적용되는가
- [ ] 응답 크기(Content-Length)에 상한이 설정되어 있는가
- [ ] SMS/이메일 발송 API에 발송 횟수 제한이 적용되어 있는가

## G5. Broken Function Level Authorization — API5

- [ ] 관리자 전용 API 엔드포인트에 역할 기반 접근 제어(RBAC)가 적용되어 있는가
- [ ] 일반 사용자가 관리자 API URL을 직접 호출할 수 없는가 (예: `/api/admin/users`)
- [ ] HTTP 메서드별 권한이 분리되어 있는가 (GET은 허용하되 DELETE는 관리자만)
- [ ] 사용자 역할 변경 API가 관리자만 호출 가능한가
- [ ] 디버그/내부용 엔드포인트가 프로덕션에서 접근 차단되어 있는가
- [ ] Routes.php에서 관리자 라우트 그룹에 별도 필터(admin_auth)가 적용되어 있는가
- [ ] 권한 검사가 Controller가 아닌 Filter/Middleware 레벨에서 일관되게 수행되는가

## G6. Unrestricted Access to Sensitive Business Flows — API6

- [ ] 자동화된 구매/예약/등록을 탐지하고 차단하는 메커니즘이 있는가
- [ ] 봇/스크래핑 방어(CAPTCHA, 디바이스 핑거프린팅)가 민감 비즈니스 플로우에 적용되어 있는가
- [ ] 쿠폰/프로모션 코드의 사용 횟수/사용자 제한이 서버에서 강제되는가
- [ ] 댓글/리뷰 등 사용자 생성 콘텐츠에 속도 제한이 적용되어 있는가
- [ ] 결제 플로우에서 가격 조작 방지를 위해 서버 측 가격 검증이 수행되는가
- [ ] 비즈니스 로직의 단계가 순서를 건너뛸 수 없도록 상태 검증이 수행되는가

## G7. Server Side Request Forgery — API7

- [ ] 사용자 입력 URL로 서버가 HTTP 요청을 보내는 경우 허용 도메인 화이트리스트가 적용되는가
- [ ] 내부 네트워크(127.0.0.1, 10.x, 172.16.x, 192.168.x, 169.254.x) 접근이 차단되는가
- [ ] URL 스킴이 http/https로만 제한되는가 (file://, gopher:// 등 차단)
- [ ] HTTP 리다이렉트 추적이 비활성화되거나 제한되어 있는가
- [ ] 서버 측 HTTP 응답이 클라이언트에게 raw로 전달되지 않는가

## G8. Security Misconfiguration — API8

- [ ] CORS 설정에서 와일드카드(*) 대신 명시적 도메인이 설정되어 있는가
- [ ] 불필요한 HTTP 메서드(TRACE, OPTIONS)가 차단되어 있는가
- [ ] API 에러 응답에 스택 트레이스, 프레임워크 버전, 내부 경로가 노출되지 않는가
- [ ] TLS 1.2+ 가 강제되고 취약한 암호화 스위트가 비활성화되어 있는가
- [ ] 보안 헤더(X-Content-Type-Options, X-Frame-Options, CSP, HSTS)가 설정되어 있는가
- [ ] 기본 크리덴셜(admin/admin)이 변경되거나 비활성화되어 있는가
- [ ] 프로덕션에서 디버그 모드가 비활성화되어 있는가

## G9. Improper Inventory Management — API9

- [ ] 모든 API 엔드포인트의 목록(인벤토리)이 문서화되어 있는가
- [ ] API 버전 관리 전략이 수립되어 있는가 (v1, v2 등)
- [ ] 더 이상 사용하지 않는 API 버전이 폐기(deprecate)되어 접근 차단되어 있는가
- [ ] 개발/스테이징용 API가 프로덕션 데이터에 접근할 수 없는가
- [ ] API 명세서(docs/api-specification.md)가 실제 구현과 일치하는가
- [ ] 모든 API에 대한 인증/인가 정책이 문서화되어 있는가
- [ ] 사용하지 않는 라우트가 Routes.php에서 제거되어 있는가
- [ ] 서드파티에 노출된 API의 데이터 흐름이 파악되어 있는가

## G10. Unsafe Consumption of APIs — API10

- [ ] 서드파티 API 응답을 신뢰하지 않고 입력 검증을 수행하는가
- [ ] 외부 API 호출 시 TLS 인증서 검증이 활성화되어 있는가 (verify_peer=true)
- [ ] 서드파티 API 응답의 Content-Type이 예상과 일치하는지 검증하는가
- [ ] 외부 API 응답에서 받은 URL을 그대로 리다이렉트하지 않는가
- [ ] 서드파티 API 연동 시 Webhook 서명 검증이 수행되는가
- [ ] 외부 API 장애 시 Circuit Breaker 패턴이 적용되어 있는가
- [ ] 서드파티 API 호출에 타임아웃이 설정되어 있는가
- [ ] 외부 API에서 받은 데이터를 DB에 저장하기 전 새니타이즈하는가
