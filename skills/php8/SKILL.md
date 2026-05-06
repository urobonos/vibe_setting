---
name: php8
description: >
  PHP 8.4+ / CI 4.7+ Mono-repo Modular Monolith API 스킬.
  아키텍처: Modular Monolith. 레거시 코드(app/Libraries/ 등)는 마이그레이션 완료까지 유지.
  레이어: Controller → Service → Repository → Model + Entity/VO.
  모듈 간 직접 클래스 참조 금지(Interface 통신만), service() DI 강제,
  CI 4.7 Service Discovery 활용. QB 우선, raw query는 Repository에서만 named binding.
  신규 모듈은 부분 구현 절대 금지 — 9가지 산출물이 항상 함께 생성되어야 한다.
  **Why:** 부분 구현 모듈은 Interface·DI·Routes·테스트 중 하나라도 누락 시 다른 모듈에서 참조 불가능해 통합 시점에 폭발적 재작업 비용이 발생한다.
triggers:
  - "API 만들어줘"
  - "엔드포인트 추가"
  - "CRUD 만들어줘"
  - "CI4 컨트롤러 만들어줘"
  - "PHP 모델 만들어줘"
  - "서비스 만들어줘"
  - "app/Modules"
  - "app/Libraries"
  - "app/Controllers/Api"
  - "app/Models"
  - "Modular Monolith"
  - "/php8"
version: 3.1.0
user-invocable: true
depends_on: [mysql8, security-audit]
conflicts_with: []
min_claude_md_version: "4.0"
---

# PHP 8.4+ / CI 4.7+ Modular Monolith API Architect Skill

Mono-repo + **Modular Monolith** 아키텍처. 레거시 코드는 마이그레이션 완료까지 유지하되, 신규 개발은 모듈 구조 강제.

본 SKILL.md 는 **인덱스 + 핵심 강제룰**만 다루며, 상세 코드 패턴·체크리스트·구현 예시는 `references/*.md` 로 분리되어 있다.

---

## 듀얼 모드 판별

| 구분 | **Legacy** | **New (Modular Monolith)** |
|------|-----------|---------------------------|
| **적용 대상** | 기존 코드 수정 / 버그픽스 | 새 기능, 새 도메인 |
| **경로** | `app/Controllers/Api/`, `app/Libraries/`, `app/Models/` | `app/Modules/{BC}/` |
| **레이어** | Controller → Library/Service → Model (Repository 겸임) | Controller → Service → Repository → Model + Entity/VO |
| **DI** | `new Service()` 또는 기존 방식 허용 | `service()` 함수 강제 |
| **모듈 간 통신** | 직접 참조 허용 | **Interface Only** |
| **DB 접근** | Model에서 직접 | Repository에서 QB 우선 |

### 판별 기준
- `app/Libraries/`, `app/Models/`, `app/Controllers/Api/` 수정 → **Legacy 모드** 적용
- `app/Modules/` 하위 신규 생성/수정 → **New 모드** 적용
- 새 도메인(기존에 없던 기능) 개발 요청 → **New 모드**로 `app/Modules/{BC}/` 생성

---

## Legacy 모드 (기존 코드 유지)

기존 코드는 CI4 기본 플랫 MVC 구조를 유지한다. 레이어 구조를 강제로 변경하지 않는다.

| 레이어 | 경로 | 역할 |
|--------|------|------|
| **Controller** | `app/Controllers/Api/` | HTTP 처리, 입력 검증 |
| **Library/Service** | `app/Libraries/` | 비즈니스 로직 |
| **Model** | `app/Models/` | DB CRUD (Repository 겸임) |

**Legacy 수정 시 규칙:**
- 기존 패턴(네이밍, DI 방식, 디렉토리 위치)을 따른다
- 새 파일 추가가 아닌 기존 파일 수정일 경우, 해당 파일의 기존 스타일을 유지한다
- PSR-12, 보안 규칙, 주석 규칙은 Legacy에도 동일하게 적용

---

## 아키텍처 원칙 (New 모드)

| 원칙 | 설명 |
|------|------|
| **Mono-repo** | 단일 저장소에 모든 모듈(Bounded Context)을 포함 |
| **Modular Monolith** | 배포는 단일 애플리케이션, 내부는 모듈 경계로 분리 |
| **레이어 강제** | Controller → Service → Repository. 레이어 건너뛰기 금지 |
| **모듈 경계** | 모듈 간 직접 클래스 참조 금지. **Interface로만 통신** |
| **DI 강제** | `service()` 함수 사용. `new Service()`, `new Model()` 직접 호출 금지 |
| **Query Builder 우선** | QB 사용이 기본. CTE/Window Function 등 미지원 구문만 `$db->query()` + named binding 허용 (Repository에서만) |

### 레이어별 책임 / 금지

| 레이어 | 책임 | 금지 |
|--------|------|------|
| **Controller** | Request 파싱, 입력 검증, 응답 반환 | DB 접근, 비즈니스 로직 |
| **Service** | 비즈니스 로직, 트랜잭션 관리 | 직접 `$this->response` 반환, DB 직접 접근 |
| **Repository** | Query Builder 쿼리, 데이터 접근 전담 | 비즈니스 판단, 응답 포맷팅 |
| **Entity/VO** | 도메인 규칙, 유효성 검증 | 외부 의존성 (DB, HTTP, Framework) |
| **Model** | 테이블 매핑, 필드 정의, 모델 레벨 검증 | 비즈니스 로직 (Repository에서만 사용) |

---

## 모듈 디렉토리 구조

> **상세:** PSR-4 매핑 + 9개 디렉토리 트리 + 네임스페이스 형태는 `references/module-structure.md` 참조.

각 모듈은 하나의 **Bounded Context(BC)** 를 담당하며, `app/Modules/{BC}/` 하위에 9개 폴더(Controllers/Services/Repositories/Models/Entities/ValueObjects/Interfaces/Exceptions/Config) 구조로 배치한다. PSR-4 네임스페이스는 BC별 개별 등록 — 누락 시 CI4 auto-discovery 가 클래스를 찾지 못해 라우트가 죽는다.

---

## 모듈 경계 규칙

> **상세:** Interface Only 통신 패턴 + Shared 모듈 배치 기준은 `references/module-boundary.md` 참조.

핵심: 모듈 간 직접 클래스 참조 **금지** — 항상 `Interfaces/` 하위 인터페이스로만 통신한다. 2개 이상 모듈에서 공통 사용되는 리소스는 `Modules/Shared/` 로 이동한다.

---

## 의존성 주입 (DI)

> **상세:** CI 4.7 Service Discovery + Services.php 풀 코드 + DI 사용 규칙은 `references/di.md` 참조.

핵심 강제룰:
- **`service()` 함수 필수**, `new Service()` / `new Repository()` / `new Model()` 직접 호출 **금지**
- 모듈별 `Modules/{BC}/Config/Services.php` 에 `BaseService` 상속 클래스로 바인딩 등록 (CI 4.7 자동 발견)
- 기본 싱글턴 (`getShared = true`), 테스트 시 `false` 로 새 인스턴스

---

## 의존성 관리 + 미적용 DDD

> **상세:** Composer 정책, lock 커밋 규칙, 미적용 DDD 요소(Aggregate Root / CQRS / Event Sourcing / Domain Event Bus) 사유는 `references/dependencies.md` 참조.

---

## 핵심 규칙

### New 모드 산출물 (9가지 동시 생성, 부분 구현 절대 금지) **[High]**

새 API 엔드포인트나 기능 요청 시 아래 **9가지를 반드시 동시에 생성**한다:
**Why:** 9가지 산출물은 New 모드 모듈이 동작·테스트·문서화·다른 모듈 참조까지 즉시 가능한 최소 완결 세트라, 하나라도 빠지면 후속 작업자가 누락분 탐지·재작성에 시간을 허비한다.

1. **Controller** (`Modules/{BC}/Controllers/`)
2. **Service + Interface** (`Modules/{BC}/Services/`, `Modules/{BC}/Interfaces/`)
3. **Repository + Interface** (`Modules/{BC}/Repositories/`, `Modules/{BC}/Interfaces/`)
4. **Model** (`Modules/{BC}/Models/`)
5. **Entity/VO** (`Modules/{BC}/Entities/`, `Modules/{BC}/ValueObjects/`) — 도메인 규칙이 필요한 경우
6. **모듈 DI 등록** (`Modules/{BC}/Config/Services.php`)
7. **PHPUnit 테스트** (Unit + Feature)
8. **모듈 Routes** (`Modules/{BC}/Config/Routes.php`)
9. **API 명세서** (`api-docs/{module}/{apiname}.md`)

부분 구현은 허용되지 않는다. (Entity/VO는 도메인 규칙이 단순 CRUD 수준이면 생략 가능)

### Legacy 모드 산출물

기존 코드 수정 시 기존 패턴을 따르되, 최소한 아래를 확인한다:
- 수정된 Controller/Library/Model의 사이드 이펙트 확인
- 테스트 코드 갱신 (있는 경우)
- PSR-12, 보안 규칙 준수

---

## 아키텍처 레이어

> **상세 코드 템플릿:** 각 레이어(Controller/Service/Repository/Entity) 의 풀 코드 예시는 `references/layer-templates.md` 참조.

---

## PHP / CI4 코딩 표준

> **상세:** PSR 준수 / 파일명 규칙 / 추상화·구체화 범위 / 보안 검증 / 사이드 이펙트 / 주석 규칙 / 날짜·시간 처리 풀셋은 `references/coding-standards.md` 참조.

핵심 강제룰 (요약):
- 모든 PHP 파일에 `declare(strict_types=1);` **필수**.
  **Why:** strict_types 미선언 시 PHP 가 `"5"` → `5` 같은 암묵적 캐스팅을 허용해 ID 비교·금액 계산에서 silent 데이터 오염이 발생한다.
- 함수/메서드 반환 타입에 `mixed` 사용 **금지**. 구체 타입 명시.
  **Why:** mixed 반환은 호출처에서 모든 타입 분기를 떠안게 되어 정적 분석·IDE 자동완성·Phpstan 검증을 모두 무력화한다.
- `date()`, `time()` 사용 **금지** — `DateTimeImmutable` 필수, UTC 통일.
  **Why:** `date()`/`time()` 은 서버 default timezone 에 묶여 다국가 서비스에서 KR/JP/US 시간대가 뒤섞이고, mutable 객체는 의도치 않은 시점 변경으로 도메인 로직이 오염된다.
- 보안: `security-audit` 스킬 규칙 (SQLi, XSS, CSRF, Mass Assignment) **필수** 준수.
  **Why:** 단일 SQLi/XSS 취약점도 다국가 서비스에서는 GDPR·개인정보 유출 사고로 이어져 서비스 중단 + 법적 제재 + 신뢰 손실이 동시에 발생한다.
- 추상화 대상(다른 모듈에서 참조하는 Service / Repository / 외부 시스템 연동)은 Interface 선행 + 추상화 사유 주석 **필수**.
  **Why:** 사유 주석 없는 Interface 는 시간이 지나면 "왜 추상화했는지" 망각되어 무분별한 메서드 추가로 ISP 원칙이 깨진다.

---

## 검증 표준

Controller에서 1차 검증, Model 검증은 2차 안전망:

| 필드 유형 | 검증 규칙 |
|-----------|-----------|
| 필수 문자열 | `required\|min_length[2]\|max_length[100]` |
| 이메일 | `required\|valid_email` |
| 양의 정수 | `required\|integer\|greater_than[0]` |
| 열거형 | `required\|in_list[active,inactive]` |
| 선택적 필드 | `permit_empty\|...` |

---

## 테스트 코드

> **상세:** 디렉토리 구조 + Unit Test (Repository Mock 주입) + Feature Test (HTTP 엔드포인트) 풀 코드는 `references/testing.md` 참조.

핵심: Unit/Feature 1차 분류 → 모듈별 2차 분류. Service 검증은 Repository Interface mock 으로, API 엔드포인트는 `FeatureTestTrait` 으로 200/201/400/404 검증.

---

## 모듈 Routes 설정

> **상세:** API URL 규격 (`/{module}/{resource}`) + 모듈 Routes 등록 + 메인 자동 로드 패턴은 `references/routes.md` 참조.

핵심 강제룰:
- **API 버전 prefix `/v1/`, `/v2/` 금지** (폐기 확정 — 헤더/필드 기반 협상으로 단일 URL 운영)
  **Why:** URL 버전 분기는 라우트·컨트롤러·문서가 N배로 늘어나며 폐기 시 클라이언트 마이그레이션 비용이 누적된다.
- module 명: BC 의 kebab-case (BC 디렉토리명과 다를 수 있음, 예: `Call` BC → `/phone-consult/`)

---

## Filter 패턴 + 인증/인가 구현 **[Critical]**

> **상세:** Filter 체인 6단계 + CsrfTokenFilter / AuthFilter / RoleFilter 풀 코드 + JWT 발급 패턴 + Cookie 발급 규격은 `references/auth-filters.md` 참조.

핵심 강제룰 (정책/알고리즘/TTL 규격은 `security-audit` §7-2/§7-3/§7-4/§7-6/§7-9/§7-10 SSOT — 본 스킬은 코드 패턴만):
- Filter 체인 순서 고정: `ratelimit → csrftoken → auth → role:{name} → CountryResolver → Controller → SecureHeaders`
- 쿠키 ↔ 헤더 비교는 **반드시 `hash_equals()`** — `===`/`==` **금지** (타이밍 공격 방어).
  **Why:** `===`/`==` 는 첫 불일치 바이트에서 즉시 반환해 응답 시간 차이로 토큰을 추정할 수 있는 사이드채널이 노출되며, `hash_equals()` 는 상수 시간 비교로 이를 차단한다.
- `Authorization: Bearer` 헤더 폴백 **금지** — JWT 는 HttpOnly 쿠키 전용.
  **Why:** Bearer 헤더는 JS 에서 읽고 쓸 수 있어 XSS 1건만 발생해도 전체 사용자 세션이 탈취되며, HttpOnly 쿠키는 JS 접근이 원천 차단된다.
- `samesite=None` 쿠키 발급 **금지** — `Lax` 강제.
  **Why:** `samesite=None` 은 임의 외부 도메인이 사용자 쿠키를 동반한 요청을 보낼 수 있게 해 CSRF 토큰이 탈취된 단일 시점에 전체 계정 변조가 가능해진다.
- RBAC 3계층 Defense in Depth (라우트 필터 / Controller 검증 / Repository `WHERE owner_id` 쿼리) — 단일 Layer 신뢰 **금지**.

---

## API 명세서 (API Docs)

> **API 명세 templates:** API Markdown 명세 작성 템플릿은 `references/api-docs-template.md` 참조. 본문 작성 시 그대로 따른다.

---

## API 응답 표준

> **상세:** HTTP 상태코드 SSOT 원칙 + 에러 코드 표(현상 서술형) + 페이지네이션 메타 키 + Swagger YAML 참조는 `references/api-response.md` 참조.

핵심: HTTP 상태코드가 성공/실패의 SSOT, body `status` 필드는 보조. DB `snake_case` → API 응답 `camelCase` 변환 **필수**. 에러 코드는 현상 서술형 (`INVALID_INPUT` / `UNAUTHORIZED` / `FORBIDDEN` / `NOT_FOUND` / `CONFLICT` / `INTERNAL`), `_ERROR`/`_FAILED` suffix 금지.

### Swagger OpenAPI YAML

> **Swagger 스펙 template:** OpenAPI/Swagger YAML 템플릿은 `references/swagger-template.md` 참조.

---

## 출력 형식

> **상세:** New 모드 12단계 출력 순서 + Legacy 모드 4단계 + 에러 응답 표준 JSON 예시는 `references/output-format.md` 참조.

---

## Mental Dry-Run + 자가 검증 체크리스트

> **상세:** 4단계 Mental Dry-Run 절차 + New/Legacy 모드별 전체 체크리스트는 `references/checklist.md` 참조.

핵심 강제룰:
- 코드 생성·수정 시 **실제 파일 기록 전** Mental Dry-Run 4단계 (1차 작성 → 1차 재검토 → 2차 재검토 → 파일 반영) **필수**. 검토 중 문제 발견 시 1차 재검토부터 반복.
- 모드 판별이 **최우선** — Legacy 수정인지 New 모듈 생성인지 먼저 결정 후 해당 체크리스트 적용.

---

## CI4 베스트 프랙티스 + e2e 검증

> **상세:** PHP 8.x 기능별 활용 가이드 + e2e 5점 체크 풀셋은 `references/best-practices.md` 참조.

### e2e 검증 (필수, 글로벌 CLAUDE.md §4 SSOT)

코드 수정 후 유닛 테스트 통과만으로 완료 판단 **금지**. 5점 체크 통과 전 머지/배포 **금지**.

1. **env 의존성** — 새 env 변수 참조 시 `.env.example` 추가 + 서버 `.env` 존재 확인. **Why:** 누락 env 는 로컬 mock 으로 숨겨졌다 배포 후 500 으로 드러남.
2. **함수/클래스 호출 3점 체크** — 정의 존재 / `Config/Services.php` · autoload 등록 / 헬퍼 로딩. **Why:** 호출 코드만으로 정의 보장 안 됨, 런타임 에러로만 드러남.
3. **DB INSERT 전 스키마 대조** — `NOT NULL` + `DEFAULT` 없는 컬럼 전수 확인. **Why:** 누락 컬럼은 INSERT 실패 → 500 직행.
4. **프로덕션 API 호출** — 배포 후 curl 로 실제 엔드포인트 200 확인. **Why:** 로컬 통과 ≠ 배포 환경 통과 (env / DI / autoload 차이).
5. **테스트 mock 경고** — mock 으로 대체한 함수/서비스가 실제 정의 존재하는지 grep 확인. **Why:** mock 통과는 의존성 부재를 숨겨 false negative 를 만든다.
