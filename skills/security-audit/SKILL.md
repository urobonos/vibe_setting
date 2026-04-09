---
name: security-audit
description: >
  7개 도메인(공통/PHP·CI4/MySQL 8.x/AWS Lambda/CI·CD·공급망/Docker·컨테이너/프로세스) 통합 보안 감사 스킬.
  OWASP Top 10, CWE Top 25, OWASP ASVS L1, CIS MySQL Benchmark, OWASP Serverless Top 10,
  SLSA L1, CIS Docker Benchmark, OWASP SAMM, STRIDE 위협 모델링 등 14개 보안 프레임워크를 도메인별로 적용한다.
  코드 작성/수정/리뷰 시 보안 취약점을 감지하고 보고한다.
  보안 이슈 발견 시 즉시 Checkpoint를 발동하여 사용자에게 보고한다.
triggers:
  - 파일 수정/생성 시 자동
  - "보안 감사", "보안 점검", "security audit", "취약점 점검"
severity_levels:
  Critical: 즉시 Checkpoint 발동, 사용자 보고 후 수정
  High: result.md [Security] 항목에 보고
  Medium: result.md [Security] 항목에 참고 기록
  Low: 권고사항으로 기록, 수정 선택적
compatibility: >
  4등급 보안 감지 체계(Critical/High/Medium/Low)의 SSOT.
  보안 관련 규칙은 이 스킬이 단일 출처이다.
domain_triggers:
  공통: 모든 코드 변경 시 항상 적용
  PHP/CI4: app/ 하위 PHP 파일, composer.json 변경 시
  MySQL: 마이그레이션 파일, DB 스키마/쿼리 작업 시
  Lambda: Lambda 함수(Python), serverless.yml, IAM 정책 변경 시
  CI/CD: 파이프라인 설정, 의존성 파일 변경 시
  Docker: Dockerfile, docker-compose.yml, docker/ 하위 설정 파일, .dockerignore 변경 시
  프로세스: 아키텍처 변경, 설계 리뷰 시
version: 1.1.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Security Audit Skill

7개 도메인 통합 보안 감사 스킬. 작업 컨텍스트에 따라 해당 도메인의 체크리스트 파일을 Read하여 적용한다.

---

## 도메인별 체크리스트

| Part | 도메인 | 체크리스트 파일 | 적용 시점 |
|------|--------|---------------|----------|
| A | PHP/CI4 | `checklists/part-a-php-ci4.md` | app/ PHP 파일, composer.json 변경 시 |
| B | 공통 | `checklists/part-b-common.md` | 모든 코드 변경 시 |
| C | MySQL 8.x | `checklists/part-c-mysql.md` | 마이그레이션, DB 스키마/쿼리 작업 시 |
| D | Lambda/Python | `checklists/part-d-lambda.md` | Lambda 함수, IAM 정책 변경 시 |
| E | CI/CD + Docker | `checklists/part-e-cicd-docker.md` | 파이프라인, Dockerfile 변경 시 |
| F | 프로세스 | `checklists/part-f-process.md` | 아키텍처 변경, 설계 리뷰 시 |
| G | API 보안 | `checklists/part-g-api-security.md` | API 엔드포인트 생성/수정, 인증/인가 변경 시 |

---

## 출력 형식

보안 감사 수행 시 아래 순서로 보고한다:

1. **감사 범위** — 대상 파일/기능
2. **발견 사항** — Critical / High / Medium 등급별 정리
3. **권고 조치** — 각 발견 사항별 구체적 수정 방법
4. **설정 변경** — Filters, Security, Cors, Nginx 등 설정 파일 수정 사항
5. **보안 테스트** — 추가해야 할 테스트 케이스
6. **타당성 검토 (Feasibility Review)** — 각 권고 조치의 공식 근거를 명시한다. OWASP, CWE, ASVS, CIS Benchmark 등 적용한 프레임워크의 **정확한 버전과 항목 번호**를 출처로 기재한다. 근거 없는 보안 권고는 지침 위반.
7. **변경 영향 기록 (Change Impact Log)** — 보안 감사 결과 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.

---

## 보안 정책

### CORS 정책 (7-2)
- Same-Origin 아키텍처(Nginx 리버스 프록시)이므로 **CORS 헤더 불필요**
- `Access-Control-Allow-Origin: *` 설정 금지
- 크로스 오리진 요청이 필요한 경우 Checkpoint 발동

### Cookie 보안 (7-3)
| 속성 | 값 | 비고 |
|------|-----|------|
| `SameSite` | `Strict` | 크로스 사이트 요청 시 쿠키 미전송 |
| `HttpOnly` | `true` | JavaScript 접근 차단 |
| `Secure` | `true` | HTTPS에서만 전송 |
| `prefix` | `hc_` | 홍카페 프로젝트 접두어 |

### 암호화 규격 (7-6)
- **알고리즘**: AES-256-CBC
- **IV(Initialization Vector)**: 매 암호화마다 랜덤 IV 생성 필수
- CI4 Encryption 라이브러리 사용 시 `Config\Encryption`에 키/드라이버 명시

### CSRF + JWT 인증 정책 (7-4)

- **JWT 저장**: HttpOnly 쿠키 전용 (7-1)
- **CSRF 필수**: HttpOnly 쿠키는 브라우저가 자동 첨부하므로 CSRF 방어 필수
- **CSRF 방식**: CI4 CSRF 필터 적용 (Session-Based 권장, Cookie-Based는 Same-site 공격 방어 불가)
- **토큰 갱신**: Refresh Token은 별도 HttpOnly 쿠키, Access Token은 짧은 만료(15분 권장)
- **SameSite=Strict**: CSRF 보조 수단으로 병행 (단독 방어 불가 — OWASP)

### SecureHeaders 필터 (7-9)
- Phase 1 즉시 적용 헤더:

| 헤더 | 값 |
|------|-----|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `X-XSS-Protection` | `0` (CSP로 대체) |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |

- CI4 `app/Filters/SecureHeadersFilter.php`로 구현, 글로벌 필터 등록

---

## Quick Reference: 자동 감지 통합 패턴

### Critical (즉시 Checkpoint)

```
# 하드코딩된 시크릿
(?i)(api[_-]?key|secret[_-]?key|password|token|credential)\s*[=:]\s*['"][A-Za-z0-9+/=]{8,}['"]

# SQL Injection
\$db->query\s*\(\s*["'].*\.\s*\$
"SELECT.*"\s*\.\s*\$

# 위험 함수
\beval\s*\(
(exec|system|passthru|shell_exec|popen|proc_open)\s*\(

# 역직렬화
unserialize\s*\(\s*\$
pickle\.loads\s*\(

# CI4 자동 라우팅
setAutoRoute\s*\(\s*true\s*\)

# 프로덕션 부적합 코드
\bFakeLogin\b
\bvar_dump\s*\(

# Lambda 인증 미설정
"authorizationType"\s*:\s*"NONE"

# 공급망 시크릿 노출
echo\s+\$\{\{\s*secrets\.

# Docker: 시크릿 이미지 포함
COPY\s+\.env
ARG\s+.*(PASSWORD|SECRET|KEY|TOKEN)\s*=

# Docker: :latest 태그
FROM\s+\S+:latest
```

### High (result.md 보고)

```
# CSRF/CORS 비활성화
\$CSRFProtection\s*=\s*false
'allowedOrigins'\s*=>\s*\[\s*'\*'\s*\]

# 확장자만 체크하는 파일 검증
getExtension\(\)

# 인증 필터 미적용
\$routes->(get|post|put|delete|resource)\(

# 에러 내부정보 노출
\$exception->getMessage\(\).*respond

# PHP 위험 함수
\bextract\s*\(
\bassert\s*\(\s*['"]

# IAM 과도한 권한
"Action"\s*:\s*"\*"
"Resource"\s*:\s*"\*"

# Docker: root 실행 (Dockerfile에 USER 미지정)
# → Dockerfile 읽기 시 USER 지시어 부재 여부로 판단

# Docker: 시크릿 환경변수 평문 노출 (docker-compose)
environment:.*PASSWORD|environment:.*SECRET|environment:.*KEY

# Nginx: CORS 와일드카드
add_header\s+Access-Control-Allow-Origin\s+\*

# PHP: memory_limit 무제한
memory_limit\s*=\s*-1
```

### Medium (참고 기록)

```
# @ 에러 억제
@\$

# exit/die
\b(die|exit)\s*\(

# HTTP 200으로 에러 반환
return\s+\$this->respond\(.*error.*,\s*200\)
```
