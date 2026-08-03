---
name: security-audit
description: >
  7개 도메인(공통/PHP·CI4/MySQL 8.x/AWS Lambda/CI·CD·공급망/Docker·컨테이너/프로세스) 통합 보안 감사 스킬.
  OWASP Top 10, CWE Top 25, OWASP ASVS L1, CIS MySQL Benchmark, OWASP Serverless Top 10,
  SLSA L1, CIS Docker Benchmark, OWASP SAMM, STRIDE 위협 모델링 등 14개 보안 프레임워크를 도메인별로 적용한다.
  코드 작성/수정/리뷰 시 보안 취약점을 감지하고 보고한다.
  보안 이슈 발견 시 즉시 Checkpoint를 발동하여 사용자에게 보고한다.
triggers:
  - "보안 감사"
  - "보안 점검"
  - "security audit"
  - "취약점 점검"
  - "OWASP"
  - "CWE"
  - "보안 리뷰"
  - "secure coding"
  - "보안 검토"
  - "/security-audit"
severity_levels:
  Critical: 즉시 Checkpoint 발동, 사용자 보고 후 수정
  High: working/ 통합 문서 §실행 [Security] 항목에 보고
  Medium: working/ 통합 문서 §실행 [Security] 항목에 참고 기록
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
version: 1.1.1
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
   **Why:** 보안 권고는 코드 영향이 크고 트레이드오프(가용성·UX·성능) 가 명확해, 공식 프레임워크 항목 번호 인용 없이 권고하면 사용자가 "이 위협이 실재하는가" 를 검증할 방법이 없어 권고 신뢰도가 LLM 환각 수준으로 떨어진다.
7. **변경 영향 기록 (Change Impact Log)** — 보안 감사 결과 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.
   **Why:** 보안 조치는 1년 후 "왜 이렇게 막아놨지" 추적 불가능 시 회귀 작업으로 무력화되거나, 동일 위협이 다른 경로로 재발해도 같은 분석을 처음부터 다시 해야 하는 비용이 누적된다.
8. **참조 출처 (Reference Location)** — 산출물을 파일로 저장 시 `## 참조 출처` 섹션 + `[참조: ...]` ≥ 1건 필수 — 감사 대상 코드의 파일:줄 위치를 기재한다. 강제: `doc-unified-check.sh V2` (output/ exit 2). 형식 예: `[참조: app/Filters/AuthFilter.php:88]`. 이는 6 "타당성 검토" 의 프레임워크 근거(`[Source: owasp-top10 §A01-2021]`)와 **별개**의 내용 provenance — 어디서 그 코드를 봤는가를 추적한다.

---

## 보안 정책

### CORS 정책 (7-2)
- Same-Origin 아키텍처(Nginx 리버스 프록시)이므로 **CORS 헤더 불필요**
- `Access-Control-Allow-Origin: *` 설정 금지
**Why:** 와일드카드 허용 시 임의 외부 사이트 JS 가 인증 쿠키 동반 fetch 로 사용자 자원에 접근해 CSRF·데이터 유출이 발생한다.
- 크로스 오리진 요청이 필요한 경우 Checkpoint 발동

### Cookie 보안 (7-3)
| 속성 | 값 | 비고 |
|------|-----|------|
| `SameSite` | `Lax` | Same-Origin 아키텍처에서 Strict 불필요. 외부 링크 유입 UX 보장 + CSRF 보조 방어 (Defense in Depth). `SameSite=None` **사용 금지** (크로스사이트 허용으로 CSRF 취약) |
| `HttpOnly` | `true` | JavaScript 접근 차단 (XSS 방어, `document.cookie` 접근 불가) |
| `Secure` | `true` | HTTPS에서만 전송. 개발 환경은 `ENVIRONMENT` 분기로 false 허용 |
| `prefix` | 프로젝트 지정 prefix | 쿠키명 충돌 방지. 구체 값은 프로젝트 `CLAUDE.md` 참조 |

**금지 사항**:
**Why:** 토큰을 JS 접근 가능한 위치(localStorage, response body, SameSite=None 쿠키)에 두면 XSS 1건·악성 광고 1건·CSRF 1건만으로 세션 전체가 탈취되어 인증 우회·계정 탈취가 즉시 발생한다.
- JWT/세션 토큰의 `localStorage` 저장 — XSS 시 탈취
- 로그인 응답 body 에 토큰 노출 — HttpOnly 쿠키로만 전달
- `SameSite=None` — 크로스사이트 허용으로 CSRF 취약

### 암호화 규격 (7-6)
- **알고리즘**: AES-256-CBC
- **IV(Initialization Vector)**: 매 암호화마다 랜덤 IV 생성 필수
**Why:** 동일 IV 재사용 시 같은 평문이 같은 암호문을 만들어 패턴 분석으로 키·평문 추론이 가능해진다 (CBC 모드 IV 재사용 = chosen-plaintext 공격 노출).
- CI4 Encryption 라이브러리 사용 시 `Config\Encryption`에 키/드라이버 명시

### CSRF + JWT 인증 정책 (7-4)

- **JWT 저장**: HttpOnly 쿠키 전용 (7-1). `Authorization: Bearer` 헤더 수동 주입 금지, 응답 body 토큰 노출 금지
- **CSRF 필수**: HttpOnly 쿠키는 브라우저가 자동 첨부하므로 CSRF 방어 필수
**Why:** HttpOnly 는 JS 탈취만 막을 뿐 cross-site form submit·image tag 요청에는 쿠키가 자동 첨부되어 사용자 권한으로 임의 상태 변경 요청이 발사된다.
- **CSRF 방식**: **Signed Double Submit Cookie (HMAC-SHA256)** — stateless JWT 아키텍처에 적합
  - **CI4 내장 CSRF 필터 사용 금지** — 세션 기반 토큰이 stateless JWT 아키텍처와 불일치. 별도 `CsrfTokenFilter` 커스텀 구현 사용
**Why:** 세션 storage 가 없는 stateless JWT 환경에서 세션 기반 토큰을 검증하면 토큰이 항상 누락·미스매치되어 정상 요청이 통째로 거부되거나, 검증을 건너뛰는 우회 코드가 들어와 CSRF 방어가 무력화된다.
  - 검증 흐름: 쿠키 ↔ 헤더 `hash_equals()` 동일성 비교 → HMAC 서명 검증 → TTL 만료 검증
  - 적용 대상: 상태 변경 요청(POST/PUT/DELETE). GET/HEAD/OPTIONS 생략
  - 면제: API Key 인증 요청(서버-서버 통신), 외부 webhook 수신 EP
- **토큰 갱신**: Refresh Token 별도 HttpOnly 쿠키, Access Token 짧은 만료(15분 권장). **Token Rotation + Reuse Detection** 필수 — 사용 완료된 `jti` 재제출 시 `family` 전체 무효화
**Why:** rotation 없이 long-lived refresh token 단일 사용 시 1회 탈취만으로 공격자가 무기한 access token 발급이 가능하며, reuse detection 없으면 정상 사용자·공격자 동시 갱신을 구분 못 해 탈취 사실 자체를 감지할 수 없다.
- **SameSite=Lax**: CSRF 보조 수단으로 병행 — Defense in Depth. Same-Origin 전제에서 Strict 불필요 (§7-3)
- **세부 규격**(쿠키명, TTL, Payload 스키마, 면제 EP 경로)은 프로젝트 `CLAUDE.md` 를 SSOT 로 따른다 — 감사 스킬에는 값을 하드코딩하지 않는다

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
- `forceGlobalSecureRequests = true` (프로덕션 HTTPS 강제) 병행 설정

**Why:** Phase 1 헤더는 모두 "기본 비활성" 이라 명시 설정 없이는 브라우저가 보호를 적용하지 않는다. `nosniff` 누락 시 MIME sniffing 으로 업로드 이미지가 JS 로 실행되고, `X-Frame-Options` 누락 시 clickjacking, HSTS 누락 시 첫 요청이 HTTP 로 떨어져 SSL Strip 공격 노출. 각 헤더는 1줄 비용 = 1개 공격 표면 차단으로 ROI 가 매우 높다.

### 외부 노출 API 보안 Phase 2 (7-10)

Phase 1(SecureHeaders, `forceGlobalSecureRequests`)에 추가로 적용하는 심화 방어. 도입 시점은 트래픽 지표·보안 감사 결과에 따라 결정한다.

| 항목 | 방식 | 도입 기준 |
|------|------|---------|
| **Nginx `limit_req`** | 로그인/결제 등 민감 EP rate limiting. burst + nodelay 옵션으로 정상 트래픽 허용 | 자동화 공격 징후, brute force 시도 감지 시 |
| **WAF (ModSecurity / AWS WAF)** | OWASP CRS(Core Rule Set) 기반 SQLi/XSS/Path Traversal 차단 | 트래픽 증가 또는 외부 보안 감사 권고 시 |
| **DDoS 차단** | AWS Shield Standard + CloudFront, 임계치 기반 자동 차단 | 외부 노출 EP 전체 상시 |
| **Bot 탐지** | 이상 패턴(User-Agent, 요청 빈도, 행동) 기반 차단 | 스크래핑/크레덴셜 스터핑 징후 시 |

**도입 절차**:
1. stg 환경 임계치 튜닝 (실사용 트래픽 95% 퍼센타일 + 여유분)
2. `limit_req_zone` / WAF 룰셋 dry-run (log only) 모드 관찰
3. False positive 확인 후 enforce 모드 전환
4. 차단 로그 모니터링 대시보드 필수 (CloudWatch Alarm 또는 Grafana)

**Why:** prod 직접 enforce 시 정상 사용자 트래픽이 false positive 로 차단돼 서비스 장애로 즉시 직결된다. dry-run → false positive 검증 → enforce 의 3단계는 보안 강화의 트레이드오프(사용성 손실)를 통제 가능한 수준으로 만들기 위한 표준 패턴이며, 단계 압축은 보안 + 가용성 양쪽을 모두 잃는 경로다.

**주의**:
- WAF 룰 변경은 트래픽 영향 큼 — Checkpoint 발동 필수
- rate limit 값은 프로젝트별 상이 — 서비스 성격(공용 API vs 인증 EP)에 맞춰 분리 설정

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

### High (통합 문서 §실행 [Security] 보고)

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
