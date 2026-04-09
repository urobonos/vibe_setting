# OWASP ASVS — Application Security Verification Standard

> **출처:** https://owasp.org/www-project-application-security-verification-standard/
> **버전:** ASVS 5.0.0 (2025-05-30 릴리스)
> **갱신일:** 2026-04-09

---

## 개요

ASVS는 웹 애플리케이션의 기술적 보안 통제를 테스트하기 위한 표준이며, 보안 개발 요구사항 목록을 제공한다.

## 검증 수준 (Verification Levels)

| 수준 | 대상 | 설명 |
|------|------|------|
| **L1** | 모든 애플리케이션 | 기본 보안 — 자동 도구로 대부분 검증 가능. OWASP Top 10 대응 수준 |
| **L2** | 민감 데이터 처리 | 심층 보안 — 대부분의 비즈니스 애플리케이션 권장 수준 |
| **L3** | 가장 높은 보안 요구 | 의료, 금융, 군사 — 침투 테스트 + 소스 코드 리뷰 필수 |

---

## 검증 카테고리 (Chapters)

### V1. Architecture, Design and Threat Modeling (아키텍처·설계·위협 모델링)
- 보안 아키텍처 문서화
- 컴포넌트 분리 및 최소 신뢰 원칙
- 위협 모델링 (STRIDE) 수행

### V2. Authentication (인증)
- 비밀번호 최소 길이 12자 이상
- 비밀번호 해싱: bcrypt, scrypt, Argon2
- MFA 구현 (SMS 보다 TOTP/FIDO2 권장)
- Credential stuffing/brute force 방어
- 세션 타임아웃 설정

### V3. Session Management (세션 관리)
- 세션 ID 충분한 엔트로피 (128비트+)
- 로그인 후 세션 ID 재생성
- 로그아웃 시 서버 측 세션 무효화
- 동시 세션 제한
- 세션 쿠키: Secure, HttpOnly, SameSite 속성

### V4. Access Control (접근 제어)
- Deny by default 원칙
- 모든 요청에서 접근 제어 검증
- 서버 측 접근 제어 (클라이언트 의존 금지)
- RBAC 또는 ABAC 구현
- 수직/수평 권한 상승 방지

### V5. Validation, Sanitization and Encoding (검증·살균·인코딩)
- 모든 입력 서버 측 검증
- SQL Injection 방어: Parameterized Query 필수
- XSS 방어: 출력 인코딩
- OS Command Injection 방어
- Path Traversal 방어
- 파일 업로드: 타입, 크기, 확장자 검증

### V6. Stored Cryptography (암호화)
- 검증된 알고리즘만 사용 (AES-256, RSA-2048+)
- 키 관리: 하드코딩 금지, 키 저장소 사용
- 비밀번호: bcrypt(cost 12+) 또는 Argon2id
- 난수: CSPRNG 사용

### V7. Error Handling and Logging (에러 처리·로깅)
- 에러 메시지에 민감 정보 미포함
- 스택 트레이스 프로덕션 미노출
- 보안 이벤트 로깅 (로그인 실패, 접근 거부 등)
- 로그 무결성 보호
- 중앙 로그 수집 및 모니터링

### V8. Data Protection (데이터 보호)
- 민감 데이터 분류 체계 수립
- 전송 중 TLS 1.2+ 필수
- 저장 시 암호화 (AES-256)
- 캐시 제어: Cache-Control, Pragma 헤더
- 개인 데이터 최소 수집 원칙

### V9. Communication (통신)
- TLS 1.2+ 강제 (TLS 1.0/1.1 비활성화)
- 유효한 인증서 사용 (자체 서명 금지)
- HSTS 헤더 설정
- 인증서 고정 (Certificate Pinning) — 모바일 앱

### V10. Malicious Code (악성 코드)
- 의존성 무결성 검증 (SRI, lock 파일)
- 백도어/로직 폭탄 탐지
- 안전한 업데이트 메커니즘

### V11. Business Logic (비즈니스 로직)
- 비즈니스 흐름 순서 강제 (건너뛰기 방지)
- Rate limiting 구현
- 비정상 사용 패턴 탐지
- 재전송 공격 (Replay Attack) 방어

### V12. Files and Resources (파일·리소스)
- 파일 업로드: 안전한 저장 경로, 실행 권한 제거
- 파일 크기 제한
- 파일 타입 서버 측 검증 (매직 바이트)
- 경로 조작 방지

### V13. API and Web Service (API·웹 서비스)
- RESTful: HTTP 메서드 적절한 사용
- 입력 검증: JSON Schema 또는 XML Schema
- CORS 정책 적절한 설정
- Rate limiting (API별)
- API 버전 관리

### V14. Configuration (설정)
- 기본 자격증명 변경
- 불필요한 기능/서비스 비활성화
- 보안 헤더 설정 (CSP, X-Frame-Options 등)
- 의존성 최신 버전 유지
- 서버 버전 정보 미노출

---

## PHP/CI4 프로젝트 L1 우선순위

| 우선순위 | 카테고리 | 핵심 조치 |
|----------|----------|-----------|
| **필수** | V2 인증 | bcrypt 해싱, MFA, brute force 방어 |
| **필수** | V3 세션 | Secure/HttpOnly/SameSite 쿠키, 세션 재생성 |
| **필수** | V4 접근 제어 | CI4 Filters + deny-by-default |
| **필수** | V5 입력 검증 | Parameterized Query, 출력 인코딩 |
| **높음** | V7 로깅 | 보안 이벤트 로깅, 스택 트레이스 미노출 |
| **높음** | V8 데이터 보호 | TLS 필수, 민감 데이터 암호화 |
| **높음** | V13 API | JSON Schema 검증, CORS, Rate limiting |
| **중간** | V6 암호화 | 키 관리, CSPRNG |
| **중간** | V14 설정 | 보안 헤더, 기본 자격증명 변경 |

---

## 참고 자료

- [ASVS 5.0.0 PDF](https://github.com/OWASP/ASVS/raw/v5.0.0/5.0/OWASP_Application_Security_Verification_Standard_5.0.0_en.pdf)
- [ASVS GitHub](https://github.com/OWASP/ASVS)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
