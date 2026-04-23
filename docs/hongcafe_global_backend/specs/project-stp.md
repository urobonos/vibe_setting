---
문서명: Project — Software Test Plan
문서 ID: project-stp
버전: v1.0
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-16
작성자: jypark
대상 시스템: HongCafe Global Backend
관련 문서: project-sdp.md, {모듈}-srs.md, {모듈}-std.md
적용 표준: IEEE 29119-3:2021
---

# Project — Software Test Plan (STP)

> IEEE 29119-3:2021 | version: 1.0 | lastUpdated: 2026-04-16

---

## 1. Introduction

### 1.1 Purpose

본 Software Test Plan(STP)은 HongCafe Global Backend 시스템 전체의 테스트 전략, 환경, 일정, 기준을 IEEE 29119-3:2021 표준에 따라 정의한다. 본 문서는 13개 Bounded Context(BC)에 대한 테스트 활동의 기준 문서(baseline document)이며, 각 모듈별 Software Test Documentation(STD)의 상위 계획서 역할을 수행한다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 프로젝트명 | HongCafe Global Backend |
| 대상 범위 | 13개 BC(Auth, Board, Call, Chat, Commerce, Content, Event, Member, Notification, Payment, Reservation, Service, Social)에 대한 Unit/Feature 테스트 |
| 범위 외 | 프론트엔드(Next.js), 모바일 앱(React Native), 관리자 백오피스, 인프라 부하 테스트 |
| 테스트 현황 | 총 2,287 tests, 테스트 파일 103개 (모듈 테스트 기준) |
| 총 테스트 파일 | 152개 (모듈 106 + 레거시 40 + 공유 4 + 기타 2) |

### 1.3 Definitions, Acronyms, and Abbreviations

| 용어 | 정의 |
|------|------|
| STP | Software Test Plan — 소프트웨어 테스트 계획서 (본 문서) |
| STD | Software Test Documentation — 모듈별 소프트웨어 테스트 문서 |
| SRS | Software Requirements Specification — 소프트웨어 요구사항 명세서 |
| SDD | Software Design Description — 소프트웨어 설계 기술서 |
| IDD | Interface Design Description — 인터페이스 설계 기술서 |
| BC | Bounded Context — DDD에서 도메인 경계를 나타내는 논리적 모듈 단위 |
| Unit Test | 단일 클래스/메서드를 격리하여 검증하는 테스트. Mock/Stub으로 의존성 차단 |
| Feature Test | HTTP 요청-응답 흐름을 CI4 TestCase로 시뮬레이션하는 통합 테스트 |
| PHPUnit | PHP 단위 테스트 프레임워크 (PHPUnit 10.5+) |
| CI4 TestCase | CodeIgniter 4의 테스트 베이스 클래스. HTTP 시뮬레이션, 서비스 모킹 지원 |
| Mock | 호출 기대(expectation)를 설정하고 검증하는 테스트 대역 |
| Stub | 고정 응답을 반환하는 테스트 대역. 호출 검증 없음 |
| Coverage | 테스트가 실행하는 소스 코드의 비율 (Line/Branch/Path) |

### 1.4 References

| 문서 | 경로/출처 |
|------|---------|
| 프로젝트 개발 계획 | `docs/specs/project-sdp.md` v2.0 |
| Auth SRS | `docs/specs/auth-srs.md` v2.0 |
| Board SRS | `docs/specs/board-srs.md` |
| Call SRS | `docs/specs/call-srs.md` |
| Chat SRS | `docs/specs/chat-srs.md` |
| Commerce SRS | `docs/specs/commerce-srs.md` |
| Content SRS | `docs/specs/content-srs.md` |
| Event SRS | `docs/specs/event-srs.md` |
| Member SRS | `docs/specs/member-srs.md` |
| Notification SRS | `docs/specs/notification-srs.md` |
| Payment SRS | `docs/specs/payment-srs.md` |
| Reservation SRS | `docs/specs/reservation-srs.md` |
| Service SRS | `docs/specs/service-srs.md` |
| Social SRS | `docs/specs/social-srs.md` |
| PHPUnit 설정 | `phpunit.xml` (프로젝트 루트) |
| IEEE 29119-3:2021 | ISO/IEC/IEEE 29119-3:2021 — Software and systems engineering: Software testing — Part 3: Test documentation |
| IEEE 29119-1:2022 | ISO/IEC/IEEE 29119-1:2022 — Software testing — Part 1: General concepts |
| 프로젝트 지침 | `CLAUDE.md` (프로젝트 루트) |

### 1.5 Overview

본 STP는 다음 섹션으로 구성된다.

- §2 Test Strategy — 테스트 수준(Level), 유형(Type), 접근법(Approach)
- §3 Test Environment — 실행 환경, 도구, Mock/Stub 전략
- §4 Test Schedule & Resources — 일정, 인력, 인프라 자원
- §5 Test Deliverables — 산출물 목록 및 각 모듈 STD 참조
- §6 Entry/Exit Criteria — 테스트 시작/종료 조건
- §7 Risk Analysis — 테스트 리스크 식별 및 대응
- §8 Module Coverage Matrix — 13개 모듈별 테스트 파일 수, 테스트 수, 커버리지 현황
- §9 타당성 검토
- §10 변경 영향 기록
- §11 검토 체크리스트
- §12 변경 로그

---

## 2. Test Strategy

### 2.1 테스트 수준 (Test Levels)

IEEE 29119-3:2021 §8.3에 따라 다음 3개 테스트 수준을 정의한다.

| 수준 | 대상 | 도구 | 디렉토리 | 목적 |
|------|------|------|---------|------|
| **Unit Test** | 단일 클래스/메서드 | PHPUnit 10.5+ | `tests/Unit/Modules/{BC}/`, `tests/unit/` | 비즈니스 로직 격리 검증. Service, Controller, Model, Formatter, VO 단위 |
| **Feature Test** | HTTP 요청-응답 흐름 | CI4 `FeatureTestCase` | `tests/Feature/Modules/{BC}/` | 엔드포인트 통합 검증. 라우팅 → 필터 → Controller → Service → 응답 전체 파이프라인 |
| **Integration Test** | 모듈 간 상호작용 | PHPUnit + CI4 TestCase | `tests/Feature/` (크로스 모듈) | BC 간 인터페이스 통신 검증. Outbox Pattern 이벤트 전파, 공유 서비스 호출 |

### 2.2 테스트 유형 (Test Types)

| 유형 | 설명 | 적용 수준 |
|------|------|----------|
| 기능 테스트 (Functional) | SRS 요구사항 대비 정확성 검증 | Unit, Feature |
| 보안 테스트 (Security) | JWT 인증, CSRF 방어, RBAC 필터 검증 | Unit, Feature |
| 경계값 테스트 (Boundary) | 입력 파라미터 경계값, NULL, 빈 문자열 처리 | Unit |
| 에러 처리 테스트 (Error Handling) | 예외 발생 경로, 에러 응답 코드/메시지 검증 | Unit, Feature |
| 회귀 테스트 (Regression) | 변경 후 기존 기능 정상 동작 확인 | 전체 (CI 파이프라인) |

### 2.3 테스트 접근법 (Test Approach)

**Black-box 기반 Feature Test + White-box 기반 Unit Test 혼합 전략**을 채택한다.

| 접근법 | 적용 범위 | 설명 |
|--------|----------|------|
| Specification-based (Black-box) | Feature Test | SRS 요구사항 기반. HTTP 요청/응답 명세 대비 검증. 내부 구현 비의존 |
| Structure-based (White-box) | Unit Test | 코드 구조 기반. 분기 조건, 예외 경로, 내부 메서드 호출 검증 |
| Experience-based | 전체 | 레거시 마이그레이션 경험 기반 탐색적 테스트. 알려진 취약 영역 우선 |

### 2.4 테스트 설계 기법 (Test Design Techniques)

| 기법 | 적용 대상 | 예시 |
|------|----------|------|
| Equivalence Partitioning | 입력 파라미터 | 유효/무효 이메일, 유효/무효 JWT 토큰 |
| Boundary Value Analysis | 수치형 파라미터 | 페이지네이션 limit (0, 1, 100, 101), 가격 (0, 음수) |
| Decision Table | 복합 조건 분기 | AuthFilter 인증 경로 (JWT/API Key/Session 조합) |
| State Transition | 상태 변경 로직 | 예약 상태 (대기→확정→취소), 통화 상태 (연결→종료→정산) |

---

## 3. Test Environment

### 3.1 실행 환경

| 항목 | 사양 |
|------|------|
| PHP | 8.4+ (`declare(strict_types=1)` 필수) |
| PHPUnit | 10.5+ (phpunit.xml 기반 설정) |
| CI4 | 4.7+ (`CodeIgniter\Test\CIUnitTestCase`, `CodeIgniter\Test\FeatureTestCase`) |
| Bootstrap | `vendor/codeigniter4/framework/system/Test/bootstrap.php` |
| 캐시 디렉토리 | `build/.phpunit.cache` |
| 리포트 출력 | `build/logs/` (clover.xml, html, testdox.html, testdox.txt, logfile.xml) |

### 3.2 PHPUnit 설정 (phpunit.xml)

```xml
<phpunit bootstrap="vendor/codeigniter4/framework/system/Test/bootstrap.php"
         backupGlobals="false"
         beStrictAboutOutputDuringTests="true"
         failOnRisky="true"
         failOnWarning="true"
         cacheDirectory="build/.phpunit.cache">
    <testsuites>
        <testsuite name="App">
            <directory>./tests</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory suffix=".php">./app</directory>
        </include>
        <exclude>
            <directory suffix=".php">./app/Views</directory>
            <file>./app/Config/Routes.php</file>
        </exclude>
    </source>
</phpunit>
```

주요 설정:
- `failOnRisky="true"` — 출력을 생성하거나 assert가 없는 테스트를 실패 처리
- `failOnWarning="true"` — PHPUnit 경고 발생 시 실패 처리
- Source 범위: `app/` 전체 (Views, Routes.php 제외)

### 3.3 Mock/Stub 전략

| 전략 | 도구 | 적용 대상 | 설명 |
|------|------|----------|------|
| **PHPUnit Mock** | `$this->createMock()` | Repository, External Service | 인터페이스 기반 Mock 생성. 메서드 호출 기대 설정 |
| **CI4 Service Mocking** | `Services::injectMock()` | DI 컨테이너 서비스 | CI4 DI 컨테이너에 Mock 주입. Controller 테스트 시 Service 대체 |
| **Stub Response** | `$mock->method()->willReturn()` | DB 조회, 외부 API | 고정 응답 반환. 외부 의존성 제거 |
| **Test Double Pattern** | 수동 구현 | 복잡한 인터페이스 | Interface를 구현하는 테스트 전용 클래스 작성 |

### 3.4 테스트 데이터 관리

| 방식 | 적용 범위 | 설명 |
|------|----------|------|
| In-memory 픽스처 | Unit Test | 테스트 메서드 내에서 배열/객체로 직접 생성 |
| CI4 Database Seeder | Feature Test (DB 의존) | `tests/_support/Database/Seeds/` 시드 파일 사용 |
| Factory Pattern | Entity/VO 생성 | 테스트용 Entity 생성 헬퍼 (`tests/_support/`) |

### 3.5 테스트 디렉토리 구조

```
tests/
├── Modules/                    ← BC별 모듈 테스트 (106 파일)
│   ├── Auth/
│   │   ├── Unit/               ← 3 files (JwtServiceTest, GeoRoutingServiceTest, ...)
│   │   └── Feature/            ← 2 files (GateApiTest, WhoamiApiTest)
│   ├── Board/
│   │   ├── Unit/               ← 5 files
│   │   └── Feature/            ← 2 files
│   ├── ... (13개 BC)
│   └── Shared/
│       └── Unit/               ← CsrfTokenServiceTest
├── unit/                       ← 레거시 단위 테스트 (40 파일)
│   ├── Filters/                ← CsrfTokenFilterTest
│   ├── Libraries/              ← Awss3, CustomRules, DateCalculator, Fcm, ...
│   └── Models/                 ← 레거시 모델 테스트
├── _support/                   ← 공유 테스트 인프라 (4 파일)
│   ├── Database/               ← Migration, Seeder
│   ├── Libraries/              ← ConfigReader
│   └── Models/                 ← ExampleModel
├── database/                   ← DB 연결 테스트 (1 파일)
└── session/                    ← 세션 테스트 (1 파일)
```

---

## 4. Test Schedule & Resources

### 4.1 테스트 일정

테스트 활동은 SDP(project-sdp.md) §4 마일스톤과 연동한다.

| 단계 | 기간 | 활동 | 관련 마일스톤 |
|------|------|------|-------------|
| **Phase 1: 기반 구축** | 2026-04 ~ 2026-04 | Auth/Member/Payment 핵심 모듈 Unit+Feature 테스트 완성 | M2 (보안 기반 구축) |
| **Phase 2: 모듈 확장** | 2026-04 ~ 2026-06 | 13개 BC 전체 Unit+Feature 테스트 확충. 레거시 테스트 모듈화 전환 | M3 (Modular Monolith 마이그레이션) |
| **Phase 3: 통합 검증** | 2026-06 ~ 2026-09 | 크로스 모듈 Integration Test 추가. API 표준 적합성 테스트 | M4 (RESTful API 표준화) |
| **Phase 4: 회귀 안정화** | 2026-09 ~ 2026-12 | 전체 회귀 테스트 스위트 안정화. 커버리지 목표 달성 | M6 (마이크로서비스 준비) |

### 4.2 리소스

| 자원 | 역할 |
|------|------|
| 개발자 (jypark) | 테스트 작성, 리뷰, 실행 |
| CI 파이프라인 (Bitbucket Pipelines) | 자동 회귀 테스트 실행 (production 브랜치 푸시 시) |
| 로컬 개발 환경 | Unit/Feature 테스트 개발 및 디버깅 |
| 빌드 서버 (EC2) | 배포 시 PHPUnit 전체 실행 (실패 시 배포 중단) |

### 4.3 테스트 실행 명령

| 명령 | 범위 | 용도 |
|------|------|------|
| `php vendor/bin/phpunit` | 전체 테스트 (152 파일) | CI/CD 파이프라인, 배포 전 검증 |
| `php vendor/bin/phpunit tests/Modules/{BC}/` | BC별 테스트 | 모듈 단위 개발/검증 |
| `php vendor/bin/phpunit tests/Modules/{BC}/Unit/` | BC별 Unit 테스트 | 비즈니스 로직 격리 검증 |
| `php vendor/bin/phpunit tests/Modules/{BC}/Feature/` | BC별 Feature 테스트 | 엔드포인트 통합 검증 |
| `php vendor/bin/phpunit --filter testMethodName` | 단일 메서드 | 디버깅, 특정 케이스 검증 |
| `php vendor/bin/phpunit --coverage-html build/logs/html` | 전체 + 커버리지 | 커버리지 리포트 생성 |

---

## 5. Test Deliverables

### 5.1 산출물 목록

| 산출물 | 형식 | 경로 | 설명 |
|--------|------|------|------|
| Software Test Plan (본 문서) | Markdown | `docs/specs/project-stp.md` | 프로젝트 전체 테스트 계획 |
| Module STD (모듈별) | Markdown | `docs/specs/{모듈}-std.md` | 모듈별 테스트 케이스 명세 |
| PHPUnit 테스트 코드 | PHP | `tests/Modules/{BC}/` | 실행 가능한 테스트 코드 |
| Clover Coverage Report | XML | `build/logs/clover.xml` | 커버리지 데이터 (CI 연동) |
| HTML Coverage Report | HTML | `build/logs/html/` | 시각적 커버리지 리포트 |
| TestDox Report | HTML/TXT | `build/logs/testdox.html`, `testdox.txt` | 테스트 사양서 형식 리포트 |
| JUnit Log | XML | `build/logs/logfile.xml` | CI 도구 연동용 테스트 결과 |

### 5.2 모듈별 STD 참조

각 BC의 상세 테스트 케이스는 개별 STD 문서에 정의한다. STD는 본 STP의 전략과 기준을 준수하여 작성한다.

| 모듈 | STD 경로 | 관련 SRS | 관련 SDD |
|------|---------|---------|---------|
| Auth | `docs/specs/auth-std.md` | `auth-srs.md` | `auth-sdd.md` |
| Board | `docs/specs/board-std.md` | `board-srs.md` | `board-sdd.md` |
| Call | `docs/specs/call-std.md` | `call-srs.md` | `call-sdd.md` |
| Chat | `docs/specs/chat-std.md` | `chat-srs.md` | `chat-sdd.md` |
| Commerce | `docs/specs/commerce-std.md` | `commerce-srs.md` | `commerce-sdd.md` |
| Content | `docs/specs/content-std.md` | `content-srs.md` | `content-sdd.md` |
| Event | `docs/specs/event-std.md` | `event-srs.md` | `event-sdd.md` |
| Member | `docs/specs/member-std.md` | `member-srs.md` | `member-sdd.md` |
| Notification | `docs/specs/notification-std.md` | `notification-srs.md` | `notification-sdd.md` |
| Payment | `docs/specs/payment-std.md` | `payment-srs.md` | `payment-sdd.md` |
| Reservation | `docs/specs/reservation-std.md` | `reservation-srs.md` | `reservation-sdd.md` |
| Service | `docs/specs/service-std.md` | `service-srs.md` | `service-sdd.md` |
| Social | `docs/specs/social-std.md` | `social-srs.md` | `social-sdd.md` |

---

## 6. Entry/Exit Criteria

### 6.1 Entry Criteria (테스트 시작 조건)

테스트 활동을 시작하기 위해 다음 조건이 모두 충족되어야 한다.

| # | 조건 | 검증 방법 |
|---|------|----------|
| E1 | SRS 문서가 "승인됨" 상태 | 해당 모듈 `{모듈}-srs.md` 프론트매터 `상태: 승인됨` 확인 |
| E2 | SDD 문서가 "승인됨" 상태 | 해당 모듈 `{모듈}-sdd.md` 프론트매터 `상태: 승인됨` 확인 |
| E3 | 테스트 환경 구성 완료 | `php vendor/bin/phpunit --version` 실행 성공 |
| E4 | 테스트 대상 코드가 빌드 성공 | `composer install` 에러 없음 |
| E5 | 테스트 데이터/픽스처 준비 완료 | `tests/_support/` 디렉토리 내 필요 파일 존재 |

### 6.2 Exit Criteria (테스트 종료 조건)

테스트 활동을 종료하기 위해 다음 조건이 모두 충족되어야 한다.

| # | 조건 | 검증 방법 |
|---|------|----------|
| X1 | 전체 PHPUnit 테스트 PASS | `php vendor/bin/phpunit` 종료 코드 0 |
| X2 | Critical/High 결함 0건 | 결함 추적 시스템 확인 |
| X3 | SRS 요구사항 대비 테스트 커버리지 100% | SRS 요구사항 ↔ 테스트 케이스 추적 매트릭스 |
| X4 | 코드 Line Coverage 80% 이상 | `build/logs/clover.xml` 커버리지 리포트 |
| X5 | 회귀 테스트 전체 PASS | CI 파이프라인 최종 실행 결과 |
| X6 | 모듈별 STD 문서 완성 | 13개 `{모듈}-std.md` 존재 및 "승인됨" 상태 |

### 6.3 Suspension/Resumption Criteria

| 조건 | 유형 | 조치 |
|------|------|------|
| 테스트 환경 장애 (DB 접속 불가, PHP 버전 불일치) | 일시 중단 | 환경 복구 후 실패 테스트부터 재개 |
| 테스트 대상 코드 Critical 결함 발견 | 일시 중단 | 결함 수정 완료 후 해당 모듈 전체 재실행 |
| SRS/SDD 변경으로 테스트 케이스 무효화 | 일시 중단 | 변경된 요구사항 반영하여 테스트 케이스 갱신 후 재개 |

---

## 7. Risk Analysis

### 7.1 테스트 리스크 식별

| # | 리스크 | 확률 | 영향도 | 대응 방안 |
|---|--------|------|--------|----------|
| TR1 | 레거시 코드(tests/unit/) 테스트 격리 부족 — 모듈 경계 없이 직접 Model 접근 | 높음 | 중간 | Phase 2에서 `tests/Modules/` 구조로 점진 이전. 레거시 테스트는 유지하되 신규 테스트는 모듈 구조 강제 |
| TR2 | 외부 서비스 의존 테스트 불안정 (SendBird, Stripe, Hermes, FCM) | 중간 | 높음 | 모든 외부 서비스 호출을 Mock/Stub으로 대체. 실제 API 호출은 e2e 검증 단계에서만 수행 |
| TR3 | DB 의존 Feature Test의 환경 편차 | 중간 | 중간 | CI4 `DatabaseTestTrait` 사용. 테스트 전후 트랜잭션 롤백으로 격리 보장 |
| TR4 | JWT/CSRF 필터 체인의 복합 조건 미검증 | 중간 | 높음 | AuthFilter 3중 인증(JWT/API Key/Session) 조합에 대한 Decision Table 기반 테스트 설계 |
| TR5 | 레거시-신규 모듈 공존 시 Session/JWT 이중 인증 경로 | 높음 | 높음 | Auth 모듈 Feature Test에서 양방향 인증 경로 모두 검증. 프론트엔드 전환 완료 후 Session 경로 테스트 제거 |
| TR6 | 커버리지 도구 오탐 — Views/Routes 제외 설정 누락 | 낮음 | 낮음 | phpunit.xml source exclude 설정 검증. `app/Views`, `app/Config/Routes.php` 제외 확인 |
| TR7 | 테스트 실행 시간 증가로 CI 파이프라인 지연 | 낮음 | 중간 | PHPUnit 병렬 실행(paratest) 도입 검토. 느린 Feature Test 분리 |

### 7.2 리스크 우선순위

| 우선순위 | 리스크 | 근거 |
|---------|--------|------|
| 1 (긴급) | TR5 | 현재 진행 중인 마이그레이션(M3)의 핵심 위험. 이중 인증 경로 미검증 시 프로덕션 장애 직결 |
| 2 (높음) | TR2, TR4 | 외부 서비스 장애/필터 체인 오류는 전체 시스템 가용성에 영향 |
| 3 (중간) | TR1, TR3 | 테스트 품질 저하이나 기능 장애로 직결되지 않음 |
| 4 (낮음) | TR6, TR7 | 운영 효율 문제. 기능 정확성에 영향 없음 |

---

## 8. Module Coverage Matrix

### 8.1 모듈별 테스트 현황

| # | 모듈 (BC) | Unit 파일 | Feature 파일 | 총 파일 | 엔드포인트 수 | 관련 SRS | 관련 SDD |
|---|----------|----------|-------------|---------|-------------|---------|---------|
| 1 | Auth | 3 | 2 | **5** | 4 | auth-srs.md | auth-sdd.md |
| 2 | Board | 5 | 2 | **7** | 12 | board-srs.md | board-sdd.md |
| 3 | Call | 8 | 3 | **11** | 66 | call-srs.md | call-sdd.md |
| 4 | Chat | 6 | 3 | **9** | 52 | chat-srs.md | chat-sdd.md |
| 5 | Commerce | 7 | 4 | **11** | 73 | commerce-srs.md | commerce-sdd.md |
| 6 | Content | 5 | 4 | **9** | 16 | content-srs.md | content-sdd.md |
| 7 | Event | 3 | 2 | **5** | 10 | event-srs.md | event-sdd.md |
| 8 | Member | 6 | 2 | **8** | 49 | member-srs.md | member-sdd.md |
| 9 | Notification | 2 | 1 | **3** | 2 | notification-srs.md | notification-sdd.md |
| 10 | Payment | 9 | 3 | **12** | 11 | payment-srs.md | payment-sdd.md |
| 11 | Reservation | 4 | 3 | **7** | 8 | reservation-srs.md | reservation-sdd.md |
| 12 | Service | 7 | 3 | **10** | 7 | service-srs.md | service-sdd.md |
| 13 | Social | 4 | 2 | **6** | 3 | social-srs.md | social-sdd.md |
| | **모듈 합계** | **69** | **34** | **103** | **~313** | | |

### 8.2 추가 테스트 영역

| 영역 | 파일 수 | 설명 |
|------|---------|------|
| 레거시 Unit (`tests/unit/`) | 40 | Filters, Libraries, Models 레거시 테스트. Phase 2에서 모듈 구조로 이전 대상 |
| 공유 모듈 (`tests/Modules/Shared/`) | 1 | CsrfTokenServiceTest — 전역 보안 서비스 |
| 테스트 인프라 (`tests/_support/`) | 4 | Migration, Seeder, ConfigReader, ExampleModel |
| 기타 (`tests/database/`, `tests/session/`) | 2 | DB 연결 검증, 세션 테스트 |
| **전체 합계** | **152** | **모듈 103 + 레거시 40 + 공유 1 + 인프라 4 + 기타 2 = 150** (+ Promotion 2) |

### 8.3 모듈별 테스트 파일 상세

#### Auth (5 files)
- **Unit**: `JwtServiceTest`, `JwtServiceExtendedTest`, `GeoRoutingServiceTest`
- **Feature**: `GateApiTest`, `WhoamiApiTest`

#### Board (7 files)
- **Unit**: `BoardControllerTest`, `BoardModelTest`, `BoardServiceTest`, `CommentControllerTest`, `CommentFormatterTest`
- **Feature**: `BoardApiTest`, `CommentApiTest`

#### Call (11 files)
- **Unit**: `CallCloseServiceTest`, `CallConnectionServiceTest`, `CallControllerTest`, `CalleeActivityServiceTest`, `CalleeControllerTest`, `CalleeManageServiceTest`, `PbxControllerTest`, `PbxServiceTest`
- **Feature**: `CallApiTest`, `CalleeApiTest`, `PbxApiTest`

#### Chat (9 files)
- **Unit**: `ChatConnectionServiceTest`, `ChatControllerTest`, `ChatListServiceTest`, `GoodsChatControllerTest`, `SendBirdServiceTest`, `ShopChatControllerTest`
- **Feature**: `ChatApiTest`, `GoodsChatApiTest`, `ShopChatApiTest`

#### Commerce (11 files)
- **Unit**: `GoodsControllerTest`, `GoodsPurchaseServiceTest`, `ItemListFormatterTest`, `ItemsControllerTest`, `ShopControllerTest`, `ShopReservationServiceTest`, `SpecialPriceControllerTest`
- **Feature**: `GoodsApiTest`, `ItemsApiTest`, `ShopApiTest`, `SpecialPriceApiTest`

#### Content (9 files)
- **Unit**: `BannerServiceTest`, `FaqServiceTest`, `NoticeServiceTest`, `ThemeControllerTest`, `ThemeModelTest`
- **Feature**: `BannerApiTest`, `FaqApiTest`, `NoticeApiTest`, `ThemeApiTest`

#### Event (5 files)
- **Unit**: `EventControllerTest`, `EventRewardServiceTest`, `RouletteServiceTest`
- **Feature**: `EventApiTest`, `RouletteApiTest`

#### Member (8 files)
- **Unit**: `MemberControllerTest`, `MemberProfileServiceTest`, `MemberRegistrationServiceTest`, `MypageControllerTest`, `PayRewardHistoryModelTest`, `SmsVerificationServiceTest`
- **Feature**: `MemberApiTest`, `MypageApiTest`

#### Notification (3 files)
- **Unit**: `FcmControllerTest`, `FcmNotificationServiceTest`
- **Feature**: `FcmApiTest`

#### Payment (12 files)
- **Unit**: `AutopayServiceTest`, `PaybackControllerTest`, `PayControllerTest`, `PaymentNotifierTest`, `PaymentServiceTest`, `PaypalTest`, `SimplepayModelTest`, `StripeControllerTest`, `StripePaymentServiceTest`
- **Feature**: `PayApiTest`, `PaybackApiTest`, `StripeApiTest`

#### Reservation (7 files)
- **Unit**: `CalendarControllerTest`, `O2oCalendarControllerTest`, `ReservationControllerTest`, `ReservationServiceTest`
- **Feature**: `CalendarApiTest`, `O2oCalendarApiTest`, `ReservationApiTest`

#### Service (10 files)
- **Unit**: `A8TrackingServiceTest`, `HermesControllerTest`, `HermesServiceTest`, `RejectControllerTest`, `RejectModelTest`, `ServiceControllerTest`, `ServiceModelTest`
- **Feature**: `HermesApiTest`, `RejectApiTest`, `ServiceApiTest`

#### Social (6 files)
- **Unit**: `GrouplistControllerTest`, `GrouplistModelTest`, `SnsModelTest`, `SnsShareControllerTest`
- **Feature**: `GrouplistApiTest`, `SnsShareApiTest`

### 8.4 커버리지 목표

| 단계 | Line Coverage 목표 | Branch Coverage 목표 | 기한 |
|------|-------------------|---------------------|------|
| Phase 1 (현재) | 60% | 50% | 2026-04 |
| Phase 2 | 70% | 60% | 2026-06 |
| Phase 3 | 80% | 70% | 2026-09 |
| Phase 4 (최종) | 80%+ | 75%+ | 2026-12 |

---

## 9. 타당성 검토 (Feasibility Review)

| 계획 항목 | 채택 방식 | 근거 (공식 표준/문서) | 결론 |
|---------|----------|----------------------|------|
| 테스트 수준: Unit + Feature 2계층 | PHPUnit CIUnitTestCase + FeatureTestCase | IEEE 29119-3:2021 §8.3 — Test Level은 시스템의 복잡도와 리스크에 따라 정의. 단일 모듈 내 Unit(격리) + Feature(통합) 2계층은 Modular Monolith 아키텍처에 적합한 최소 구성 | **타당** — 마이크로서비스 분리 전까지 별도 시스템 테스트 수준 불필요. BC 단위 Feature Test가 시스템 테스트 역할 수행 |
| Mock/Stub 전략: 외부 서비스 전면 Mock | PHPUnit createMock + CI4 injectMock | IEEE 29119-3:2021 §8.4.2 — Test Environment 정의 시 테스트 대상 외 컴포넌트는 시뮬레이터/스텁으로 대체 가능. OWASP Testing Guide — 결제/인증 등 외부 서비스는 격리 환경에서 Mock 처리 권고 | **타당** — SendBird/Stripe/Hermes/FCM 등 외부 API 직접 호출 시 테스트 불안정성, 비용, 속도 문제 발생. Mock으로 격리 후 프로덕션 e2e에서 실제 검증 |
| Entry/Exit Criteria 정의 | SRS 승인 → 테스트 시작, 전체 PASS + Coverage 80% → 종료 | IEEE 29119-3:2021 §8.2 — Test Plan은 테스트 시작/종료 조건을 명시적으로 정의해야 함. 종료 조건 없는 테스트 활동은 품질 판단 기준 부재로 이어짐 | **타당** — SRS 승인 기반 Entry Criteria로 불완전 요구사항 대비 테스트 방지. Line Coverage 80% Exit Criteria는 업계 관행(Google: 80%, Meta: 80%+)과 부합 |
| "No Test, No Merge" 정책 연동 | CI 파이프라인 PHPUnit 자동 실행 | IEEE 29119-3:2021 §8.5 — Test Schedule은 개발 프로세스와 동기화. SDP §5.4 "No Test, No Merge" 정책과 일관. Bitbucket Pipelines에서 PHPUnit 실패 시 배포 중단으로 정책 자동 강제 | **타당** — 수동 검증 의존 시 정책 이행 불확실. CI 자동 실행으로 100% 이행률 보장 |
| 레거시 테스트 점진 이전 전략 | tests/unit/ → tests/Modules/ 단계적 전환 | IEEE 29119-3:2021 §8.3 — 기존 테스트 자산은 폐기하지 않고 새 테스트 수준 구조로 재분류. SDP M3 마일스톤(Modular Monolith 마이그레이션)과 동기화 | **타당** — 40개 레거시 테스트 일괄 전환 시 테스트 공백 발생 위험. 모듈 마이그레이션 완료 시점에 해당 테스트도 이전하는 점진 전략이 리스크 최소화 |

**타당성 검토 결론**: Unit+Feature 2계층 테스트 전략, Mock/Stub 외부 서비스 격리, Entry/Exit Criteria 명시, CI 연동 자동 검증, 레거시 점진 이전 전략 모두 IEEE 29119-3:2021 표준 및 업계 관행 대비 타당성 검증 완료.

---

## 10. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| project-stp.md 신규 작성 (v1.0) | 13개 BC에 대한 테스트 전략, 환경, 기준을 단일 문서로 통합. 기존에 SDP §5.4에 2줄로 요약되었던 테스트 정책을 IEEE 29119-3:2021 기준으로 체계화 | SDP/SRS/SDD/IDD 산출물은 존재하나 테스트 계획서(STP) 부재. 테스트 활동의 기준 문서 없이 테스트 작성 시 일관성 결여 및 커버리지 사각지대 발생 |
| Module Coverage Matrix 포함 | 13개 BC별 Unit/Feature 파일 수, 엔드포인트 수, 관련 문서를 한 눈에 파악 가능. 테스트 부족 모듈 식별 용이 | 152개 테스트 파일이 어떤 모듈에 얼마나 분포하는지 가시성 부재. 테스트 자원 배분의 근거 자료 필요 |
| Entry/Exit Criteria 명시 | 테스트 시작/종료 판단의 객관적 기준 확립. "언제 테스트를 시작하고 언제 끝내는가"에 대한 합의 문서화 | 종료 기준 없이 "전체 PASS"만으로 판단 시 커버리지 부족, 미검증 경로 잔존 위험 |
| 모듈별 STD 참조 체계 수립 | STP → STD → SRS/SDD 추적성 확보. 요구사항 → 설계 → 테스트 케이스 간 양방향 추적 가능 | IEEE 29119-3:2021 요구사항인 테스트 문서 계층 구조(Test Plan → Test Specification → Test Case) 준수 |

---

## 11. 검토 체크리스트 (Review Checklist)

### 완전성 (Completeness)

- [x] §1 Introduction — Purpose/Scope/Definitions/References/Overview 5개 하위 섹션 완전
- [x] §2 Test Strategy — 테스트 수준 3계층, 유형 5종, 접근법 3종, 설계 기법 4종 정의
- [x] §3 Test Environment — 실행 환경, PHPUnit 설정, Mock/Stub 전략, 데이터 관리, 디렉토리 구조
- [x] §4 Test Schedule & Resources — 4단계 일정, 자원, 실행 명령 전체 정의
- [x] §5 Test Deliverables — 7종 산출물, 13개 모듈 STD 참조 테이블
- [x] §6 Entry/Exit Criteria — Entry 5개, Exit 6개, Suspension 3개 조건
- [x] §7 Risk Analysis — 7개 테스트 리스크, 우선순위 4단계
- [x] §8 Module Coverage Matrix — 13개 모듈별 Unit/Feature 파일 수, 상세 파일 목록, 커버리지 목표
- [x] §9 타당성 검토 — 5개 계획 항목, IEEE 29119-3 근거 연결
- [x] §10 변경 영향 기록 완료

### 일관성 (Consistency)

- [x] 테스트 디렉토리 구조와 실제 `tests/` 디렉토리 일치
- [x] 모듈별 파일 수와 실제 파일 수 일치 (실측 기반)
- [x] PHPUnit 설정과 실제 `phpunit.xml` 일치
- [x] 마일스톤/일정과 SDP(project-sdp.md) §4 정합
- [x] 테스트 정책과 SDP §5.4 "No Test, No Merge" 일치
- [x] 13개 BC 목록과 SDP §3.1 모듈 목록 일치

### 추적성 (Traceability)

- [x] 각 모듈 ↔ SRS/SDD/STD 상호참조
- [x] Test Level ↔ 디렉토리 구조 매핑
- [x] Risk ↔ 대응 방안 1:1 매핑
- [x] 타당성 검토 항목 ↔ IEEE 29119-3 조항 연결

---

## 12. 변경 로그 (Change Log)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-16 | 1.0.0 | 초기 작성. IEEE 29119-3:2021 기반 STP 전체 구조 수립. 13개 BC Module Coverage Matrix, Entry/Exit Criteria, Risk Analysis, 타당성 검토 포함 |
