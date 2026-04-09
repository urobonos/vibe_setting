# OWASP Top 10 — 2021

> 출처: https://owasp.org/Top10/
> 최종 갱신: 2026-04-08

| ID | Name | 설명 | 주요 CWE |
|----|------|------|----------|
| A01 | Broken Access Control | 접근 제어 실패. 권한 없는 사용자가 리소스에 접근 | CWE-200, CWE-201, CWE-352 |
| A02 | Cryptographic Failures | 암호화 실패. 민감 데이터 노출, 약한 알고리즘 | CWE-259, CWE-327, CWE-331 |
| A03 | Injection | SQL/NoSQL/OS/LDAP 인젝션. 신뢰되지 않은 데이터가 명령에 삽입 | CWE-79, CWE-89, CWE-78 |
| A04 | Insecure Design | 설계 단계 결함. 위협 모델링 부재, 보안 설계 패턴 미적용 | CWE-209, CWE-256, CWE-501 |
| A05 | Security Misconfiguration | 보안 설정 오류. 기본값 미변경, 불필요한 기능 활성화 | CWE-16, CWE-611 |
| A06 | Vulnerable and Outdated Components | 취약하거나 오래된 구성요소 사용 | CWE-1104 |
| A07 | Identification and Authentication Failures | 인증/식별 실패. 브루트포스, 약한 비밀번호 | CWE-287, CWE-297, CWE-384 |
| A08 | Software and Data Integrity Failures | 소프트웨어/데이터 무결성 실패. CI/CD 파이프라인 보안 | CWE-829, CWE-494, CWE-502 |
| A09 | Security Logging and Monitoring Failures | 보안 로깅/모니터링 실패. 침입 탐지 불가 | CWE-117, CWE-223, CWE-532, CWE-778 |
| A10 | Server-Side Request Forgery (SSRF) | 서버측 요청 위조. 서버가 공격자 지정 URL로 요청 | CWE-918 |

## 프로젝트 적용 매핑

| OWASP | 프로젝트 대응 |
|-------|-------------|
| A01 | JWT 인증 필터 + CI4 Route 필터 + Scope 기반 접근 제어 |
| A02 | AES-256-CBC + IV 필수, HttpOnly 쿠키 |
| A03 | Query Builder 우선, named binding, CI4 입력 검증 |
| A04 | Modular Monolith + Interface 경계 + Checkpoint 승인 |
| A05 | SecureHeaders 필터, CSRF 필터, .env 환경 분리 |
| A06 | composer.lock 커밋, Dependabot/Snyk 권고 |
| A07 | JWT Access 15분 만료, Refresh 별도 쿠키, SameSite=Strict |
| A08 | Bitbucket Pipelines CI/CD, Atomic Deploy |
| A09 | log_message() 에러 기록, CloudWatch |
| A10 | 외부 URL 요청 제한, allowlist 기반 |
