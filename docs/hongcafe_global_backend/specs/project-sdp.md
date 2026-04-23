---
문서명: HongCafe Global Backend — Software Development Plan
문서 ID: project-sdp
버전: v2.0
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: HongCafe Global Backend
관련 문서: CLAUDE.md, docs/infrastructure.md
적용 표준: IEEE/ISO/IEC 12207:2017
---

# Software Development Plan (SDP)

> IEEE/ISO/IEC 12207:2017 | version: 2.0 | lastUpdated: 2026-04-15

---

## 1. Introduction

### 1.1 Purpose

본 Software Development Plan(SDP)은 HongCafe Global Backend 시스템의 소프트웨어 생명주기 전 과정에 걸친 개발 계획을 정의한다. 이 문서는 개발 방법론, 아키텍처 전략, 마일스톤, 품질 보증, 리스크 관리 절차를 규정하며, 모든 프로젝트 이해관계자의 기준 문서(baseline document)로 사용된다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 프로젝트명 | HongCafe Global Backend |
| 목적 | 전화/채팅 상담 플랫폼의 글로벌 백엔드 시스템 — 레거시 모놀리스를 Modular Monolith로 점진 전환 |
| 범위 내 | 인증, 회원, 상담(통화/채팅), 커머스(상품/매장/아이템), 결제, 예약, 이벤트, 알림, 소셜 등 13개 Bounded Context |
| 범위 외 | 프론트엔드(Next.js 별도 리포지토리), 모바일 앱(React Native), 관리자 백오피스 |

### 1.3 Definitions, Acronyms, and Abbreviations

| 용어 | 정의 |
|------|------|
| BC | Bounded Context — DDD에서 도메인 경계를 나타내는 논리적 모듈 단위 |
| SDP | Software Development Plan — 소프트웨어 개발 계획서 |
| CI/CD | Continuous Integration / Continuous Deployment |
| JWT | JSON Web Token — 서명 기반 stateless 인증 토큰 |
| SSM | AWS Systems Manager — EC2 원격 명령 실행 서비스 |
| Aurora | Amazon Aurora MySQL — AWS 관리형 관계형 데이터베이스 |
| RDS Proxy | Amazon RDS Proxy — 데이터베이스 연결 풀링 및 IAM 인증 프록시 |
| DI | Dependency Injection — 의존성 주입 |
| PHPUnit | PHP 단위 테스트 프레임워크 |
| ADR | Architecture Decision Record — 아키텍처 결정 기록 |

### 1.4 References

| 문서 | 경로/출처 |
|------|---------|
| 프로젝트 지침 | `CLAUDE.md` (프로젝트 루트) |
| 인프라 명세 | `docs/infrastructure.md` |
| API 명세 | `docs/api-specification.md` |
| 작업 이력 | `docs/tasks/history.md` |
| IEEE 12207:2017 | ISO/IEC/IEEE 12207:2017 — Systems and software engineering: Software life cycle processes |

### 1.5 Overview

본 SDP는 다음 섹션으로 구성된다.

- §2 기술 스택 — 채택된 언어, 프레임워크, 인프라 컴포넌트
- §3 아키텍처 방식 — Modular Monolith 설계 원칙 및 모듈 구성
- §4 마일스톤 — 단계별 목표 및 산출물
- §5 개발 방법론 — 워크플로우, 커밋 컨벤션, 테스트 전략
- §6 형상관리 — VCS, 브랜치 전략, CI/CD 파이프라인
- §7 리스크 관리 — 식별된 리스크 및 대응 방안
- §8 품질 보증(QA) — 코딩 표준, 테스트 요구사항, 문서화 기준
- §9 타당성 검토
- §10 변경 영향 기록
- §11 검토 체크리스트
- §12 변경 로그

---

## 2. 기술 스택 (Technology Stack)

| 항목 | 버전 | 비고 |
|------|------|------|
| PHP | 8.4+ (프로덕션 8.5.3) | `declare(strict_types=1)` 필수 |
| CodeIgniter | 4.7+ | Modular Monolith 아키텍처 |
| MySQL | Amazon Aurora MySQL 3.12.0 (8.0.44 호환) | RDS Proxy IAM Auth |
| Next.js | 16 | 프론트엔드 (별도 리포지토리) |
| Nginx | 1.28.2 | 리버스 프록시 |
| PHP-FPM | 8.5.3 | Unix 소켓 통신 |
| Node.js | v24.14.0 | SSR / API 게이트웨이 |
| PM2 | v6.0.14 | 프로세스 관리 |

---

## 3. 아키텍처 방식 (Architecture Approach)

**Modular Monolith (Dual Mode)** — 레거시와 신규 모듈이 동일 프로세스 내 공존하며, BC 단위로 점진적으로 전환한다.

| 구분 | 위치 | 설명 |
|------|------|------|
| 신규 모듈 | `app/Modules/{BC}/` | Controller → Service → Repository → Model + Entity/VO |
| 레거시 유지 | `app/Controllers/Api/`, `app/Libraries/`, `app/Models/` | 마이그레이션 완료까지 유지 |
| 공유 모듈 | `Modules/Shared/` | Enums, Interfaces, Services, Traits |

**모듈 간 통신 원칙**: Interface Only (`service()` DI 강제). 직접 클래스 인스턴스화 금지.  
**DI 등록**: 모듈별 분산 (`Modules/{BC}/Config/Services.php`). 중앙 `app/Config/Services.php`에 바인딩 금지.

### 3.1 모듈 구성 (13개 Bounded Context)

| # | 모듈 | 엔드포인트 수 | 설명 |
|---|------|-------------|------|
| 1 | Auth | 4 | 인증/인가, JWT, Geo Routing |
| 2 | Board | 12 | 게시판, 문의, 댓글, 신고 |
| 3 | Call | 66 | 통화 연결/종료/정산, PBX, 상담사 관리 |
| 4 | Chat | 52 | 채팅 연결/관리, SendBird, 견적 |
| 5 | Commerce | 73 | 상품/매장/아이템, 예약, 구매/환불 |
| 6 | Content | 16 | 공지/FAQ/배너/테마 CRUD |
| 7 | Event | 10 | 키워드/쿠폰/출석/룰렛 이벤트 |
| 8 | Member | 49 | 회원 가입/로그인/프로필/마이페이지 |
| 9 | Notification | 2 | FCM 토큰 등록, 푸시 발송 |
| 10 | Payment | 11 | Stripe/Naver/Toss Pay, 자동결제 |
| 11 | Reservation | 8 | 예약 스케줄/등록/통화, 캘린더 |
| 12 | Service | 7 | 서비스 목록, 차단 관리, Hermes 연동 |
| 13 | Social | 3 | SNS 공유, 그룹 목록 |
| | **합계** | **~313** | |

### 3.2 아키텍처 결정 사항 (ADR)

| # | 결정 | 근거 | 대안 |
|---|------|------|------|
| ADR-001 | Modular Monolith (단일 배포 유닛) | 레거시-신규 공존 필요. 마이크로서비스 전환 전 중간 단계 | 완전 마이크로서비스 (조기 복잡도 증가) |
| ADR-002 | Interface Only 모듈 간 통신 | 미래 마이크로서비스 분리 준비. 결합도 최소화 | 직접 클래스 참조 (리팩터링 비용 증가) |
| ADR-003 | Outbox Pattern (크로스 도메인 이벤트) | 트랜잭션 내 비즈니스 데이터 + 이벤트 레코드 원자 커밋. 이벤트 유실 방지 | 동기 직접 호출 (강결합, 장애 전파) |
| ADR-004 | JWT HttpOnly 쿠키 전용 | XSS 탈취 방지. localStorage 금지 | Bearer 헤더 (XSS 취약) |

---

## 4. 마일스톤 (Milestones)

| # | 마일스톤 | 목표일 | 산출물 | 상태 |
|---|---------|--------|--------|------|
| M1 | 인프라 구축 (EC2/Aurora/CI/CD) | 2026-04-02 | 프로덕션 서버, 파이프라인 | 완료 |
| M2 | 보안 기반 구축 (JWT/CSRF/RBAC) | 2026-04-09 | AuthFilter, CsrfTokenFilter, RoleFilter | 완료 |
| M3 | 레거시 → Modular Monolith 마이그레이션 | 2026-06-30 | 13개 모듈 전환 완료 | 진행중 |
| M4 | RESTful API 표준화 | 2026-06-30 | 응답 표준, camelCase 변환 | 진행중 |
| M5 | 프론트엔드 Next.js 전환 | 2026-09-30 | SSR/CSR 전환 | 대기 |
| M6 | 마이크로서비스 준비 | 2026-12-31 | Outbox Pattern, 이벤트 기반 통신 | 대기 |

---

## 5. 개발 방법론 (Development Methodology)

### 5.1 워크플로우

3-Team 협업 모델 (Analyze → Plan → Execute):

1. **Team 1 (Analyze)**: 요구사항 분석, 설계 초안 작성 (SRS/SDD/IDD)
2. **Team 2 (Plan)**: 설계 검토, 우선순위 결정, 작업 분해
3. **Team 3 (Execute)**: 구현, 단위 테스트, PR 제출

### 5.2 커밋 컨벤션

Conventional Commits (`type(scope): subject`) 적용.

| 타입 | 설명 |
|------|------|
| `feat` | 신규 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 리팩터링 (기능 변경 없음) |
| `docs` | 문서 변경 |
| `test` | 테스트 추가/수정 |
| `chore` | 빌드/CI/의존성 관련 변경 |

### 5.3 코드 리뷰

- PR 기반 리뷰 (Bitbucket Pull Request)
- 머지 전 최소 1명 Approved 필수
- 자동 테스트 통과 필수 (CI 파이프라인)

### 5.4 테스트 전략

```
tests/
├── Unit/Modules/{BC}/       ← BC별 단위 테스트
├── Feature/Modules/{BC}/    ← BC별 기능 테스트
└── _support/                ← 공유 픽스처, 헬퍼
```

| 명령 | 범위 |
|------|------|
| `php vendor/bin/phpunit` | 전체 테스트 |
| `php vendor/bin/phpunit tests/Unit/Modules/{BC}/` | BC별 단위 테스트 |
| `php vendor/bin/phpunit --filter testMethodName` | 단일 메서드 |

**원칙**: "No Test, No Merge" — 모든 수정은 단위 테스트 또는 실행 로그 증빙 동반.

---

## 6. 형상관리 (Configuration Management)

### 6.1 버전 관리

| 항목 | 내용 |
|------|------|
| VCS | Git (Bitbucket) |
| 브랜치 전략 | `master`(메인), `production`(배포), `dev/migration`(작업) |
| 태깅 | Semantic Versioning (v{MAJOR}.{MINOR}.{PATCH}) |

### 6.2 브랜치 정책

| 브랜치 | 용도 | 직접 푸시 |
|--------|------|----------|
| `master` | 메인 브랜치 (릴리스 기준) | 금지 (PR 필수) |
| `production` | 배포 브랜치 (수동 승인) | 금지 (PR 필수) |
| `dev/migration` | 마이그레이션 작업 (현재 활성) | 허용 |

### 6.3 배포 파이프라인

```
Bitbucket Push (production 브랜치)
  → Bitbucket Pipelines 트리거
    → AWS SSM Run Command → EC2 배포 스크립트
      → 릴리스 디렉토리 생성 (`/works/hongcafe-global/be/releases/{timestamp}`)
      → Composer install (--no-dev --optimize-autoloader)
      → PHPUnit 전체 실행 (실패 시 중단)
      → 성공: 심볼릭 링크 전환 (`current → releases/{timestamp}`) + PHP-FPM reload
      → 실패: 릴리스 디렉토리 삭제, 이전 `current` 유지 (자동 롤백)
      → 5-릴리스 보존 (오래된 릴리스 자동 정리)
```

### 6.4 환경별 URL

| 환경 | URL |
|------|-----|
| Production | `https://prd.gl.hongcafe.com` |
| Staging | `https://stg.gl.hongcafe.com` |
| Development | `https://dev.gl.hongcafe.com` |

---

## 7. 리스크 관리 (Risk Management)

| # | 리스크 | 확률 | 영향도 | 대응 방안 |
|---|--------|------|--------|----------|
| R1 | 레거시-신규 공존 복잡도 증가 | 높음 | 높음 | 모듈별 점진 전환, AuthFilter 3중 인증(JWT/API Key/Session) 병행 |
| R2 | DB charset 마이그레이션 실패 | 중간 | 높음 | utf8mb4 통일, 테이블 단위 ALTER, 스테이징 검증 필수 |
| R3 | Session → JWT 전환 불완전 | 높음 | 높음 | Dual auth 지원, 프론트엔드 전환 완료 후 Session 제거 |
| R4 | 외부 서비스 장애 (Hermes/SendBird/Stripe) | 중간 | 중간 | 타임아웃 설정, 재시도 정책, Fallback 처리 구현 |
| R5 | 060 전화 시스템 월간 한도 초과 | 낮음 | 중간 | 한도 체크 API, 사전 알림 시스템 |
| R6 | GeoLite2 DB 파일 갱신 누락 | 낮음 | 낮음 | MaxMind 월간 업데이트 일정 관리 |

---

## 8. 품질 보증 (Quality Assurance)

### 8.1 코딩 표준

| 규칙 | 내용 |
|------|------|
| 타입 선언 | 모든 PHP 파일 `declare(strict_types=1)` 필수 |
| 날짜/시간 | `DateTimeImmutable` 강제. `date()`, `time()` 사용 금지 |
| 타임존 | DB/서버 모두 UTC. 사용자 표시는 프론트엔드에서 로컬 변환 |
| 변수명 | 전체 단어 사용 (fullName, userIndex 등). 축약 금지 |
| 주석 | 주석 없이 읽히는 명시적 코드 우선. 복잡한 비즈니스 로직에만 주석 |
| Auto Routing | 비활성화 (`setAutoRoute(false)`). 모든 EP는 Routes.php에 명시적 등록 |

### 8.2 보안 표준

| 항목 | 요구사항 |
|------|---------|
| 인증 | JWT HttpOnly 쿠키 전용. Bearer 헤더 폴백 없음 |
| CSRF | Signed Double Submit Cookie (HMAC-SHA256). CI4 내장 CSRF 필터 미사용 |
| RBAC | 3계층 Defense in Depth (RoleFilter → checkNeedLogin → Repository 소유권) |
| 파일 업로드 | MIME 이중 검증 필수 (확장자 + `mime_content_type()`) |
| 쿠키 | HttpOnly, Secure, SameSite=Lax, prefix=hc_ |

### 8.3 API 응답 표준

| 항목 | 규칙 |
|------|------|
| 성공 | `{ "data": {...} }` (HTTP 200/201) |
| 에러 | `{ "error": { "code": "ERROR_CODE", "message": "..." } }` (HTTP 4xx/5xx) |
| 필드명 | DB `snake_case` → API 응답 `camelCase` 변환 필수 |
| 에러 코드 | 현상 서술형, suffix 없음 (`INVALID_INPUT`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`, `INTERNAL`) |

### 8.4 문서화 기준

| 산출물 | 요구사항 |
|--------|---------|
| API 문서 | Markdown + OpenAPI 3.0.3 YAML 동시 생성 필수 (`api-docs/{BC}/{API}.md` + `.yaml`) |
| 설계 문서 | SRS + SDD + IDD 세트로 모듈별 작성 (`docs/specs/`) |
| 타당성 검토 | 모든 분석/설계 산출물에 필수 포함. 공식 표준 근거 필수 |
| 변경 영향 기록 | 변경 사항, 개선점, 수행 이유 3항목 필수 |
| 작업 이력 | 매 작업 완료 후 `docs/tasks/history.md` 갱신 필수 |

---

## 9. 타당성 검토 (Feasibility Review)

| 계획 항목 | 채택 방식 | 근거 (공식 표준/문서) | 결론 |
|---------|----------|----------------------|------|
| 아키텍처: Modular Monolith | 단일 배포 유닛 내 BC별 격리 | IEEE 12207:2017 §6.4 — 시스템 아키텍처는 점진적 발전(incremental evolution)을 지원해야 함. Modular Monolith는 마이크로서비스 준비 단계로 적합 | **타당** — 레거시 공존 조건에서 조기 마이크로서비스 분리 대비 복잡도 대폭 감소 |
| CI/CD: Atomic Deploy (심볼릭 링크) | 릴리스 디렉토리 + 심볼릭 링크 전환 | AWS Well-Architected Framework — Operational Excellence 원칙. 배포 자동화 + 즉각 롤백 지원이 서비스 가용성 향상에 직결 | **타당** — 심볼릭 링크 전환으로 다운타임 없는 배포(zero-downtime deploy) 구현. 롤백은 링크 재전환으로 즉시 처리 |
| 테스트: "No Test, No Merge" 정책 | PR 전 PHPUnit 통과 필수 | IEEE 12207:2017 §6.4.6 — Verification 프로세스: 소프트웨어 요소가 요구사항을 충족하는지 검증 필수. CLAUDE.md "No Test, No Merge" 정책과 일치 | **타당** — CI 파이프라인 내 자동 테스트로 검증 일관성 보장 |
| 보안: JWT + Signed Double Submit Cookie | stateless 인증 + CSRF 방어 이중화 | OWASP Top 10 2021 — A01 Broken Access Control, A07 Identification and Authentication Failures. OWASP CSRF Prevention Cheat Sheet — Double Submit Cookie Pattern 권고 | **타당** — JWT HttpOnly 쿠키로 XSS 탈취 방지. HMAC 서명으로 쿠키 위변조 방지. 전통적 세션보다 stateless 구조에 적합 |

**타당성 검토 결론**: Modular Monolith 아키텍처, Atomic Deploy CI/CD, PHPUnit 기반 테스트 정책, JWT+CSRF 보안 조합 모두 IEEE 12207:2017 및 업계 표준(AWS Well-Architected, OWASP) 대비 타당성 검증 완료.

---

## 10. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| IEEE 12207:2017 표준 전면 전환 (v2.0) | §1 Introduction 하위 섹션(1.1~1.5) 추가로 문서 목적·범위·용어·참조·구조를 명확화. 국제 표준 준수로 이해관계자 간 공통 언어 확립 | 글로벌 지침 SDP 형식 요구사항 — IEEE 12207 준수 필수. v1.0은 표준 구조 없이 요약 나열 수준으로 품질 기준 미달 |
| §8 품질 보증(QA) 섹션 신설 (v2.0) | 코딩 표준, 보안 표준, API 응답 표준, 문서화 기준을 단일 섹션으로 통합. 개발자가 준수해야 할 품질 요구사항을 일목요연하게 참조 가능 | CLAUDE.md에 분산된 표준을 SDP에 집약하여 새 팀원 온보딩 시 단일 참조 문서 역할 수행 |
| §9 타당성 검토 섹션 추가 (v2.0) | 아키텍처·CI/CD·테스트·보안 계획에 IEEE/OWASP/AWS 표준 기반 근거 확보 | 글로벌 지침("타당성 검토" 섹션 필수 포함) 준수. 근거 없는 계획 수립 방지 |
| §10 변경 영향 기록 섹션 추가 (v2.0) | 변경 사항·개선점·수행 이유 표 형식 명시로 문서 추적성 강화 | 글로벌 지침("변경 영향 기록" 필수 기록) 준수 |

---

## 11. 검토 체크리스트 (Review Checklist)

### 완전성 (Completeness)

- [x] §1 Introduction — 목적/범위/용어/참조/개요 5개 하위 섹션 완전
- [x] §2 기술 스택 전체 기재 (8개 컴포넌트)
- [x] §3 아키텍처 방식 — Modular Monolith 원칙, 13개 BC 목록, ADR 4건
- [x] §4 마일스톤 — 6개 마일스톤, 목표일/산출물/상태 전체 정의
- [x] §5 개발 방법론 — 워크플로우, 커밋 컨벤션, 코드 리뷰, 테스트 전략
- [x] §6 형상관리 — VCS, 브랜치 정책, CI/CD 파이프라인, 환경별 URL
- [x] §7 리스크 관리 — 6개 리스크, 확률/영향도/대응 방안 전체 정의
- [x] §8 품질 보증 — 코딩/보안/API/문서화 표준 전체 정의
- [x] §9 타당성 검토 — 4개 계획 항목, 공식 표준 근거 연결
- [x] §10 변경 영향 기록 완료

### 일관성 (Consistency)

- [x] 기술 스택과 실제 프로젝트(CLAUDE.md) 일치
- [x] 마일스톤 간 의존관계 정합
- [x] 형상관리 전략과 실제 브랜치 일치
- [x] 배포 파이프라인과 `docs/infrastructure.md` 정합
- [x] 품질 기준과 CLAUDE.md 표준 일치

### 실행 가능성 (Feasibility)

- [x] 마일스톤 목표일 현실적 (현재 날짜 2026-04-15 기준)
- [x] 리스크 대응 방안 구체적 (기술적 방법 명시)
- [x] 개발 방법론 팀 역량 대비 적절
- [x] 테스트 전략 현재 코드베이스와 정합

### 추적성 (Traceability)

- [x] 각 마일스톤에 산출물 명시
- [x] 각 ADR에 근거 및 대안 기록
- [x] 리스크 식별 → 대응 방안 1:1 매핑
- [x] 타당성 검토 항목 ↔ 공식 표준 연결

---

## 12. 변경 로그 (Change Log)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-15 | 1.0.0 | 초기 작성 |
| 2026-04-15 | 2.0.0 | IEEE 표준 전면 전환. 3-Round Review PASS (구조/내용/상호참조). §1 Introduction 하위 섹션(1.1~1.5) 추가, §8 Quality Assurance 신설, §9 타당성 검토, §10 변경 영향 기록 추가. 적용 표준: IEEE/ISO/IEC 12207:2017 |
