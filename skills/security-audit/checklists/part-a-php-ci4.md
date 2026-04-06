# Part A: PHP/CI4 보안 체크리스트

**적용 시점:** app/ 하위 PHP 파일, composer.json 변경 시

| 기반 표준 | URL |
|----------|-----|
| OWASP Top 10 (2021) | https://owasp.org/Top10/ |
| OWASP PHP Security Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/PHP_Configuration_Cheat_Sheet.html |
| OWASP Secure Coding Practices | https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/ |
| CI4 Security Guide | https://codeigniter4.github.io/userguide/concepts/security.html |

---

## A1. 접근 제어 (OWASP A01)

- [ ] `setAutoRoute(true)`가 비활성화되어 있는가
- [ ] 인증 필요 엔드포인트에 인증 필터가 적용되어 있는가
- [ ] 수평적 권한 상승 방지를 위해 리소스 소유권 검증이 수행되는가
- [ ] Deny by default 원칙이 적용되어 있는가 (명시적으로 허용된 것만 접근 가능)
- [ ] 디버그/테스트 컨트롤러(FakeLogin, TestController)가 프로덕션에서 접근 불가한가
- [ ] 디렉토리 리스팅이 비활성화되어 있는가
- [ ] Rate Limiting(Throttler)이 민감 API(로그인, 결제)에 적용되어 있는가

## A2. 암호화 (OWASP A02)

- [ ] 하드코딩된 시크릿(IP, API 키, 비밀번호)이 없는가
- [ ] 비밀번호가 `password_hash()` + `PASSWORD_BCRYPT` 또는 argon2로 해싱되는가
- [ ] HTTPS가 강제되어 있는가 (forcehttps 필터)
- [ ] HSTS 헤더가 설정되어 있는가 (`Strict-Transport-Security`)
- [ ] 취약한 암호화 알고리즘(MD5, SHA1)이 사용되지 않는가
- [ ] 민감 데이터가 분류되고 보호 등급이 정의되어 있는가

## A3. 인젝션 (OWASP A03)

- [ ] raw 쿼리에 변수가 직접 삽입되지 않고 바인딩을 사용하는가
- [ ] `$this->request->getPost()` 등 입력값이 `$this->validate()` 후 사용되는가
- [ ] `like()` 조건의 사용자 입력에 와일드카드 이스케이프가 적용되는가
- [ ] `$_GET/$_POST/$_REQUEST` 직접 사용 없이 CI4 Request 객체를 사용하는가
- [ ] ORM에서 동적 쿼리 구성(문자열 연결)을 하지 않는가
- [ ] OS 커맨드 인젝션 방어를 위해 `exec()/system()/passthru()`에 사용자 입력이 없는가
- [ ] LDAP/XML 인젝션 방어가 해당 기능에 적용되어 있는가

## A4. 설계 보안 (OWASP A04)

- [ ] 비즈니스 로직이 Controller가 아닌 Library/Service에 존재하는가 (3계층)
- [ ] 결제/인증 등 민감 작업에 트랜잭션이 사용되는가
- [ ] Threat Modeling이 신규 기능 설계 시 수행되는가
- [ ] 리소스 소비 제한(메모리, 시간, 파일 크기)이 설정되어 있는가
- [ ] Misuse case 테스트가 포함되어 있는가

## A5. 보안 설정 (OWASP A05)

- [ ] CSRF 필터가 활성화되어 있는가 (API 토큰 인증 시 별도 처리)
- [ ] CORS 설정에 와일드카드(*)가 사용되지 않았는가
- [ ] 프로덕션에서 `CI_ENVIRONMENT=production`이 설정되어 있는가
- [ ] `SecureHeaders` 필터가 활성화되어 있는가
- [ ] 디버그 툴바가 `development`에서만 활성화되는가
- [ ] HTTP 보안 헤더(X-Frame-Options, X-Content-Type-Options, CSP)가 설정되어 있는가
- [ ] 기본 계정(admin/admin)이 변경 또는 비활성화되어 있는가
- [ ] 개발/스테이징/프로덕션 환경 간 보안 설정이 일관성 있는가

## A6. 취약한 컴포넌트 (OWASP A06)

- [ ] `composer audit` 결과 알려진 취약점이 없는가
- [ ] CI4 프레임워크 버전이 최신 안정 버전인가
- [ ] PHP 버전이 EOL이 아닌 지원 버전인가
- [ ] 미사용 의존성이 제거되어 있는가
- [ ] 의존성이 공식 소스(Packagist)에서만 설치되는가
- [ ] CVE 모니터링이 설정되어 있는가

## A7. 인증 (OWASP A07)

- [ ] 비밀번호 복잡도 검증(최소 8자, 대소문자+숫자+특수문자)이 적용되는가
- [ ] 로그인 성공 시 `session()->regenerate()`가 호출되는가
- [ ] 브루트포스 방어(로그인 실패 횟수 제한 + Throttler)가 적용되는가
- [ ] 쿠키의 `SameSite=Lax` 또는 `Strict`가 설정되어 있는가
- [ ] MFA(다중 인증)가 관리자 계정에 적용되어 있는가
- [ ] 계정 열거(Username Enumeration) 방지 응답이 적용되는가
- [ ] NIST 800-63b 비밀번호 정책이 적용되는가

## A8. 무결성 (OWASP A08)

- [ ] Webhook 서명 검증이 수행되는가
- [ ] 파일 업로드 시 MIME 타입 + 매직 바이트 검증이 포함되어 있는가
- [ ] `composer.lock`이 Git에 커밋되어 있는가
- [ ] 코드 리뷰 프로세스가 적용되어 있는가

## A9. 로깅 (OWASP A09)

- [ ] 로그인 실패가 `log_message()`로 기록되는가
- [ ] 권한 없는 접근 시도가 Filter에서 로깅되는가
- [ ] 민감 데이터(비밀번호, 토큰, 카드번호)가 로그에 기록되지 않는가
- [ ] 에러 메시지에 내부 시스템 정보(`$e->getMessage()`)가 노출되지 않는가
- [ ] 로그 인젝션 방지를 위한 인코딩이 적용되는가

## A10. SSRF (OWASP A10)

- [ ] 사용자 입력 URL로 서버 측 HTTP 요청 시 허용 도메인 화이트리스트가 적용되는가
- [ ] 내부 네트워크(10.x, 172.16.x, 192.168.x) 접근이 차단되는가
- [ ] raw 응답을 사용자에게 직접 전달하지 않는가
- [ ] HTTP 리다이렉션 추적이 제한되어 있는가

## A11. PHP 설정 보안 (PHP Cheat Sheet)

- [ ] `expose_php = Off`로 PHP 버전 정보가 숨겨져 있는가
- [ ] `display_errors = Off`가 프로덕션에서 설정되어 있는가
- [ ] `log_errors = On`으로 에러가 파일에 기록되는가
- [ ] `disable_functions`에 위험 함수(exec, system, passthru, eval)가 포함되어 있는가
- [ ] `open_basedir`이 프로젝트 디렉토리로 제한되어 있는가
- [ ] `session.cookie_httponly = 1`이 설정되어 있는가
- [ ] `session.cookie_secure = 1`이 설정되어 있는가 (HTTPS)
- [ ] `session.use_strict_mode = 1`이 설정되어 있는가
- [ ] `allow_url_include = Off`가 설정되어 있는가
- [ ] `upload_max_filesize`가 적절히 제한되어 있는가

## A12. 파일 관리 (Secure Coding Practices)

- [ ] 동적 include(`include $variable`)가 사용되지 않는가
- [ ] 업로드 디렉토리에서 PHP 실행이 차단되어 있는가
- [ ] 파일 경로에 사용자 입력이 포함되지 않아 Path Traversal이 불가능한가
- [ ] 업로드 파일에 대한 멀웨어 스캔이 적용되는가
- [ ] GET 파라미터에 민감 정보가 전달되지 않는가

## A13. 세션/JWT 보안

- [ ] 세션 토큰이 충분한 엔트로피(최소 128비트)로 생성되는가
- [ ] 로그아웃 시 세션이 완전히 무효화되는가
- [ ] JWT 토큰 수명이 적절히 제한되어 있는가
- [ ] JWT revocation 메커니즘이 구현되어 있는가

## A14. 테스트 (보안 네거티브 테스트)

- [ ] 보안 네거티브 테스트 케이스가 포함되어 있는가
- [ ] SAST/DAST가 CI/CD 파이프라인에 통합되어 있는가

## A15. Nginx 보안 설정

- [ ] `server_tokens off`가 설정되어 있는가
- [ ] 숨김 파일(`.git`, `.env`) 접근이 차단되어 있는가
- [ ] 민감 디렉토리(`app/`, `system/`, `writable/`, `vendor/`) 접근이 차단되어 있는가
- [ ] `fastcgi_hide_header X-Powered-By`가 설정되어 있는가
- [ ] `client_max_body_size`가 적절히 제한되어 있는가
- [ ] HTTP → HTTPS 301 리다이렉트가 설정되어 있는가
