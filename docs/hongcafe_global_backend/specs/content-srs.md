---
문서명: Content Module — Software Requirements Specification
문서ID: SRS-CONTENT-001
버전: v2.1
적용 표준: IEEE 29148:2018
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-15
작성자: jypark
대상 시스템: HongCafe Global Backend — Content Module
관련 문서:
  - content-sdd.md (SDD-CONTENT-001)
  - content-idd.md (IDD-CONTENT-001)
  - docs/api-specification.md
---

# Content Module — Software Requirements Specification (SRS)

> IEEE 29148:2018 준수 | version: 2.1 | lastUpdated: 2026-04-15 | module: Content

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 HongCafe Global Backend Content 모듈의 소프트웨어 요구사항을 IEEE 29148:2018 표준에 따라 정의한다.
Content 모듈은 공지사항(Notice), FAQ, 배너(Banner), 테마(Theme) 콘텐츠에 대한 RESTful CRUD 관리 및 테마별 상담사 목록 조회 기능을 제공한다. 총 16개 엔드포인트를 포함하며, 관리자·사용자·상담사 세 이해관계자 그룹을 대상으로 한다.

This document defines software requirements for the Content module of the HongCafe Global Backend system per IEEE 29148:2018. The Content module covers RESTful CRUD management of notices, FAQs, banners, and theme-callee list queries across 16 endpoints.

### 1.2 Scope (범위)

- **모듈 경로**: `app/Modules/Content/`
- **Controllers**: `BannerController`, `FaqController`, `NoticeController` (ResourceController 상속), `ThemeController`
- **Services**: `BannerService`, `FaqService`, `NoticeService` (CRUD), `ThemeService`
- **Repositories**: `BannerRepository` (시간 기반 활성화), `FaqRepository`, `NoticeRepository`, `ThemeRepository` (복합 조인)
- **DB Tables**: `tb_banner` (starttime/endtime), `tb_faq` (max 500자), `tb_notice`
- **엔드포인트 수**: 16개 (Notice 5, FAQ 5, Banner 5, Theme 1)
- **대상 사용자**: 관리자 (콘텐츠 등록/수정), 사용자 (조회), 상담사 (테마 노출)
- **범위 외**: 콘텐츠 파일(이미지) 업로드 스토리지 관리, 광고 과금 로직

### 1.3 Definitions, Acronyms, and Abbreviations (정의 및 약어)

| 용어 / Term | 정의 / Definition |
|------------|-----------------|
| FR | Functional Requirement (기능 요구사항) |
| NFR | Non-Functional Requirement (비기능 요구사항) |
| BC | Bounded Context |
| EP | Endpoint |
| ResourceController | CI4 RESTful 리소스 패턴 — index/show/new/create/edit/update/delete 메서드 자동 매핑 |
| bn_position | 배너 배치 위치 코드 (main, side, popup 등) |
| faq_menu_code | FAQ 카테고리 분류 코드 |
| onFlag | 테마 상담사 온콜 상태 필터 (on/standby/off) |
| bn_sort | 배너 수동 정렬 순서 (정수, ASC) |
| UPSERT | INSERT or UPDATE on duplicate key |
| UTC | Coordinated Universal Time — DB/서버 기준 타임존 |
| camelCase | API 응답 필드 네이밍 컨벤션 (DB snake_case 변환 결과) |
| SSOT | Single Source of Truth |
| p95 | 95번째 백분위 응답 시간 |

### 1.4 References (참조 문서)

| 문서 | 위치 |
|------|------|
| IEEE 29148:2018 — Systems and software engineering — Life cycle processes — Requirements engineering | 국제 표준 |
| content-sdd.md (SDD-CONTENT-001) | `docs/specs/` |
| content-idd.md (IDD-CONTENT-001) | `docs/specs/` |
| docs/api-specification.md | `docs/` |
| CI4 4.7 ResourceController 공식 문서 | https://codeigniter.com/user_guide/incoming/restful.html |
| OWASP Top 10 2021 — A03 Injection | https://owasp.org/Top10/A03_2021-Injection/ |
| CLAUDE.md — 프로젝트 지침 | 프로젝트 루트 |

### 1.5 Overview (문서 구조)

| 섹션 | 내용 |
|------|------|
| 섹션 2 | Overall Description — 이해관계자, 제약사항, 가정 및 의존성 |
| 섹션 3 | Functional Requirements (FR) — 4건 16개 EP + 검증 방법 |
| 섹션 4 | Non-Functional Requirements (NFR) — 정량 기준 포함 |
| 섹션 5 | External Interface Requirements |
| 섹션 6 | Use Cases |
| 섹션 7 | Requirements Verification Matrix |
| 섹션 8 | Data Dictionary |
| 섹션 9 | Feasibility Review |
| 섹션 10 | Change Impact Log |
| 섹션 11 | Review Checklist |
| 섹션 12 | Change Log |

---

## 2. Overall Description (전체 설명)

### 2.1 Product Perspective (제품 관점)

Content 모듈은 HongCafe Global Backend의 Modular Monolith 아키텍처 내 독립 Bounded Context로 존재한다. 공지사항·FAQ·배너는 관리자 전용 CRUD를 제공하며, 테마 목록은 모든 사용자에게 공개된다. 배너는 DB 쿼리 시점의 `starttime`/`endtime` 비교를 통해 시간 기반 노출 제어를 수행하며, 테마 목록은 외부 Hermes DB와 조인하여 온콜 상태를 실시간 반영한다.

### 2.2 Stakeholders (이해관계자)

| 역할 | 관심사 |
|------|--------|
| 관리자 | 콘텐츠 등록/수정/삭제, 배너 노출 시간 제어 |
| 사용자 (Caller) | 공지사항·FAQ·배너·테마 목록 조회 |
| 상담사 (Callee) | 테마 목록에 자신의 프로필 노출 |
| 개발팀 | ResourceController 패턴 준수, 쿼리 성능 |
| 운영팀 | 배너 시간 제어 정확성, 서비스 가용성 |

### 2.3 Product Functions Summary (기능 요약)

| 기능 그룹 | EP 수 | 핵심 특성 |
|----------|------|---------|
| 공지사항 CRUD | 5 | RESTful Resource, regist_date DESC |
| FAQ CRUD | 5 | 카테고리 필터, max_length[500] |
| 배너 CRUD | 5 | 시간 기반 활성화 (starttime ≤ NOW() ≤ endtime) |
| 테마 목록 | 1 | 온콜 필터, 복합 조인, limit/offset |

### 2.4 Constraints (제약사항)

- RESTful resource 라우트는 CI4 `$routes->resource()` 매크로로 자동 생성 — 수동 라우트 금지
- 배너 starttime/endtime은 DB datetime 타입, UTC 기준
- FAQ faq_question은 최대 500자 (CI4 max_length 검증)
- 테마 복합 쿼리는 `$db->query()` + `$db->escape()` — Query Builder 한계로 raw SQL 허용 (OWASP A03 준수)
- `declare(strict_types=1)` 모든 PHP 파일 필수
- `DateTimeImmutable` 강제 — `date()`, `time()` 사용 금지
- DB charset: `utf8mb4` 통일

### 2.5 Assumptions and Dependencies (가정 및 의존성)

| 항목 | 내용 |
|------|------|
| 가정 | 배너 관리자는 starttime/endtime을 UTC 기준으로 입력한다 |
| 가정 | FAQ 카테고리(faq_menu_code)는 별도 관리 테이블 없이 코드값으로 관리된다 |
| 의존성 | `ThemeRepository`는 외부 Hermes DB(101.101.211.242) 조인에 의존한다 |
| 의존성 | CI4 4.7+ `$routes->resource()` 메서드, `Model::paginate()`, `Model::pager` 프로퍼티 |
| 의존성 | PHP 8.4+ `DateTimeImmutable`, `random_int()` |

---

## 3. Functional Requirements (기능 요구사항)

### FR-CONTENT-001: 공지사항 CRUD

**ID**: FR-CONTENT-001 | **우선순위**: P1 필수 | **출처**: API Specification §Notice

#### 요구사항 세부 사항

- RESTful resource 5개 EP (index / show / create / update / delete) — `NoticeController` (`ResourceController` 상속)
- 목록 조회: `regist_date DESC` 정렬, CI4 Pager(`paginate()`) 기반 페이지네이션
- `create` / `update` / `delete`: 관리자 JWT 인증 필수
- 삭제는 Hard Delete (논리 삭제 없음)

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `nt_title` | required, max_length[200] |
| `nt_content` | required |
| `nt_status` | in_list[Y,N] |

#### 관련 API

| HTTP | 경로 | 인증 |
|------|------|------|
| GET | `/api/notices` | 공개 |
| GET | `/api/notices/:id` | 공개 |
| POST | `/api/notices` | JWT (관리자) |
| PUT | `/api/notices/:id` | JWT (관리자) |
| DELETE | `/api/notices/:id` | JWT (관리자) |

#### 검증 방법 (Verification Method)

- **시험 (Test)**: POST `/api/notices` — nt_title 200자 초과 시 HTTP 400 `INVALID_INPUT` 반환 확인
- **시험 (Test)**: GET `/api/notices` — meta에 currentPage, perPage, total, lastPage 포함 확인
- **검사 (Inspection)**: Routes.php에 `$routes->resource('notices')` 등록 확인

---

### FR-CONTENT-002: FAQ CRUD

**ID**: FR-CONTENT-002 | **우선순위**: P1 필수 | **출처**: API Specification §FAQ

#### 요구사항 세부 사항

- RESTful resource 5개 EP — `FaqController` (`ResourceController` 상속)
- 목록 조회: `faq_menu_code` 카테고리 필터링, `faq_status='y'`, `faq_order ASC`, `regist_date DESC`
- 기본값: `faq_status='n'`, `faq_type='all'`
- `create` / `update` / `delete`: 관리자 JWT 인증 필수

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `faq_question` | required, max_length[500] |
| `faq_answer` | required |
| `faq_menu_code` | max_length[50] |
| `faq_status` | in_list[y,n] |
| `faq_order` | integer |

#### 관련 API

| HTTP | 경로 | 인증 |
|------|------|------|
| GET | `/api/faqs` | 공개 |
| GET | `/api/faqs/:id` | 공개 |
| POST | `/api/faqs` | JWT (관리자) |
| PUT | `/api/faqs/:id` | JWT (관리자) |
| DELETE | `/api/faqs/:id` | JWT (관리자) |

#### 검증 방법 (Verification Method)

- **시험 (Test)**: POST `/api/faqs` — faq_question 501자 전달 시 HTTP 400 `INVALID_INPUT` 반환 확인
- **시험 (Test)**: GET `/api/faqs?faq_menu_code=general` — faq_status='y' 레코드만 반환 확인
- **검사 (Inspection)**: `FaqRepository::getActiveFaqList()` 쿼리에 faq_status 조건 존재 확인

---

### FR-CONTENT-003: 배너 CRUD (시간 기반 활성화)

**ID**: FR-CONTENT-003 | **우선순위**: P1 필수 | **출처**: API Specification §Banner

#### 요구사항 세부 사항

- RESTful resource 5개 EP — `BannerController` (`ResourceController` 상속)
- **시간 기반 활성화**: 조회 시 `starttime ≤ NOW() AND endtime ≥ NOW() AND bn_view='Y'` 조건 DB 쿼리 시점 적용
- `bn_position` 위치 필터 지원
- 정렬: `bn_sort ASC`, `regist_date DESC`

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `bn_img` | required, max_length[500] |
| `bn_link` | max_length[500] |
| `bn_position` | required, max_length[50] |
| `bn_view` | in_list[Y,N] |
| `starttime` | required, valid_date[DATETIME] |
| `endtime` | required, valid_date[DATETIME] |

#### 관련 API

| HTTP | 경로 | 인증 |
|------|------|------|
| GET | `/api/banners` | 공개 |
| GET | `/api/banners/:id` | 공개 |
| POST | `/api/banners` | JWT (관리자) |
| PUT | `/api/banners/:id` | JWT (관리자) |
| DELETE | `/api/banners/:id` | JWT (관리자) |

#### 검증 방법 (Verification Method)

- **시험 (Test)**: 현재 시각보다 endtime이 과거인 배너 생성 후 GET `/api/banners` 응답에 해당 배너 미포함 확인
- **시험 (Test)**: starttime 누락 시 HTTP 400 `INVALID_INPUT` 반환 확인
- **분석 (Analysis)**: `BannerRepository::getActiveBannerList()` 쿼리 실행 계획 — `idx_position_view` 인덱스 사용 확인

---

### FR-CONTENT-004: 테마 목록 조회

**ID**: FR-CONTENT-004 | **우선순위**: P1 필수 | **출처**: API Specification §Theme

#### 요구사항 세부 사항

- `ThemeController::getThemeList()` — POST 단일 EP
- 온콜 상태 필터(`onFlag`: on/standby/off), 가격 범위 필터(`price_min`, `price_max`) 지원
- Hermes DB 서브쿼리 조인으로 온콜 상태 실시간 반영
- 랜덤 태그 선택(`itTag`), 숫자 포맷팅 처리
- 페이지네이션: limit/offset 방식 (CI4 기본 Pager 미사용 — 복합 쿼리 구조 예외)

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `limit` | integer, max_value[100] |
| `offset` | integer, min_value[0] |
| `onFlag` | in_list[on,standby,off] |
| `price_min` | decimal |
| `price_max` | decimal |

#### 관련 API

| HTTP | 경로 | 인증 |
|------|------|------|
| POST | `/api/themes/get-theme-list` | 공개 |

#### 검증 방법 (Verification Method)

- **시험 (Test)**: `onFlag=on` 전달 시 응답 데이터에 onlineStatus='off' 항목 미포함 확인
- **시험 (Test)**: `limit=0` 전달 시 빈 배열 반환 확인
- **검사 (Inspection)**: `ThemeRepository`의 모든 동적 값에 `$db->escape()` 적용 확인 (OWASP A03)

---

## 4. Non-Functional Requirements (비기능 요구사항)

### NFR-CONTENT-001: 아키텍처 — RESTful Resource 패턴

**ID**: NFR-CONTENT-001 | **우선순위**: P1 필수
**요구사항**: `BannerController`, `FaqController`, `NoticeController`는 CI4 `ResourceController`를 상속한다. 라우트는 `$routes->resource()` 자동 등록 — 수동 개별 등록 금지.
**측정 기준**: Routes.php에 `$routes->resource('banners')`, `$routes->resource('faqs')`, `$routes->resource('notices')` 3행 존재 (검사)

### NFR-CONTENT-002: 성능 — 배너/FAQ 목록 조회 응답 시간

**ID**: NFR-CONTENT-002 | **우선순위**: P2 중요
**요구사항**: 배너·FAQ 목록 조회 응답 시간 200ms 이하 (p95, DB 인덱스 활용 기준, 네트워크 RTT 제외)
**측정 기준**: Aurora MySQL EXPLAIN 결과 — `idx_position_view` (banner), `idx_status_menu` (faq) 인덱스 사용 확인. 스테이징 환경 k6 부하 테스트 p95 200ms 이하

### NFR-CONTENT-003: 비즈니스 — 배너 시간 활성화 정확도

**ID**: NFR-CONTENT-003 | **우선순위**: P1 필수
**요구사항**: 배너 노출 여부는 DB 쿼리 실행 시각(`NOW()`) 기준 실시간 결정. 크론잡 방식의 주기적 상태 업데이트 금지.
**측정 기준**: DB 쿼리 EXPLAIN에 `starttime ≤ NOW() AND endtime ≥ NOW()` 조건 확인 (검사)

### NFR-CONTENT-004: 보안 — 입력값 검증

**ID**: NFR-CONTENT-004 | **우선순위**: P1 필수
**요구사항**: 모든 POST/PUT 요청은 CI4 Validation Rules (required, max_length, in_list 등)로 검증. 검증 실패 시 HTTP 400 + `INVALID_INPUT` 에러 코드 반환.
**측정 기준**: 각 FR 입력 검증 규칙 항목별 단위 테스트 통과 (시험)

### NFR-CONTENT-005: 보안 — SQL Injection 방지

**ID**: NFR-CONTENT-005 | **우선순위**: P1 필수
**요구사항**: `ThemeRepository`의 모든 동적 파라미터는 `$db->escape()` 또는 Query Builder 바인딩 적용. raw SQL 직접 문자열 결합 금지.
**측정 기준**: ThemeRepository 코드 리뷰 — 동적 값 직접 삽입 없음 확인 (검사, OWASP A03:2021)

### NFR-CONTENT-006: 성능 — 페이지네이션

**ID**: NFR-CONTENT-006 | **우선순위**: P2 중요
**요구사항**: 공지·FAQ·배너 목록 조회는 CI4 `Model::paginate()` 기반 페이지네이션 적용. 응답 meta: `{ currentPage, perPage, total, lastPage }` camelCase 통일.
**측정 기준**: GET `/api/notices?page=2` 응답 meta.currentPage === 2 확인 (시험)

---

## 5. External Interface Requirements (외부 인터페이스 요구사항)

### 5.1 HTTP API Interface

| 항목 | 명세 |
|------|------|
| 프로토콜 | HTTPS (X-Forwarded-Proto: https 필수) |
| 인증 헤더 | `hc_access` 쿠키 (JWT), `X-CSRF-TOKEN` (POST/PUT/DELETE) |
| 응답 Content-Type | `application/json` |
| 필드 네이밍 | 응답: camelCase / 요청: snake_case 또는 camelCase |
| 성공 응답 포맷 | GET/POST/PUT: `{ "data": ... }` — DELETE: `{ "message": "..." }` (단독, CI4 `ResourceController::respondDeleted()` 기본 출력 준수) |
| 에러 응답 포맷 | `{ "error": { "code": "...", "message": "..." } }` (HTTP 4xx/5xx) |

### 5.2 Database Interface

| 항목 | 명세 |
|------|------|
| DBMS | Amazon Aurora MySQL 3.12.0 (MySQL 8.0.44 호환) |
| 접속 | RDS Proxy IAM Auth |
| charset | utf8mb4 (서버/DB/테이블/컬럼 전 레벨) |
| 타임존 | UTC |
| 주요 테이블 | `tb_banner`, `tb_faq`, `tb_notice` |

### 5.3 External Hermes DB Interface

| 항목 | 명세 |
|------|------|
| 용도 | ThemeRepository 온콜 상태 서브쿼리 조인 |
| 접속 정보 | 101.101.211.242 (별도 DB 연결 설정) |
| 위험 | Hermes DB 장애 시 테마 목록 조회 불응답 가능 |

---

## 6. Use Cases (유스케이스)

### UC-CONTENT-001: 배너 시간 기반 자동 노출

- **액터**: 사용자 (비인증)
- **사전 조건**: `bn_position` 파라미터 전달
- **정상 흐름**:
  1. 사용자가 `GET /api/banners?bn_position=main` 요청
  2. `BannerRepository::getActiveBannerList()` — `starttime ≤ NOW() AND endtime ≥ NOW() AND bn_view='Y'` 필터
  3. `bn_sort ASC`, `regist_date DESC` 정렬 후 반환
  4. meta에 `currentPage`, `perPage`, `total`, `lastPage` 포함
- **대안 흐름**: 시간 외 배너 → 조회 결과에서 자동 제외 (삭제 아님)
- **에러 흐름**: 유효하지 않은 position → 빈 목록 반환 (HTTP 200)
- **사후 조건**: 현재 활성 배너 목록만 반환됨

### UC-CONTENT-002: FAQ 카테고리 필터 조회

- **액터**: 사용자
- **사전 조건**: 없음
- **정상 흐름**:
  1. `GET /api/faqs?faq_menu_code=general` 요청
  2. `faq_status='y'`, `faq_menu_code='general'` 필터 적용
  3. `faq_order ASC`, `regist_date DESC` 정렬 후 반환
- **에러 흐름**: 존재하지 않는 FAQ ID → HTTP 404 `NOT_FOUND`
- **사후 조건**: 활성 FAQ 목록 반환됨

### UC-CONTENT-003: 테마 온콜 필터 조회

- **액터**: 사용자 (비인증)
- **사전 조건**: 없음
- **정상 흐름**:
  1. `POST /api/themes/get-theme-list` + `onFlag=on`
  2. Hermes DB 서브쿼리 조인으로 온콜 상담사 필터
  3. 가격 범위 추가 필터 적용
  4. 랜덤 태그 선택, 숫자 포맷팅 후 반환
- **대안 흐름**: `onFlag` 미전달 — 전체 상태(on/standby/off) 반환
- **에러 흐름**: Hermes DB 장애 → HTTP 500 `INTERNAL`
- **사후 조건**: 조건에 맞는 테마 목록 반환됨

---

## 7. Requirements Verification Matrix (요구사항 검증 매트릭스)

| 요구사항 ID | 설명 | 검증 방법 | 검증 조건 | 추적 (SDD) |
|------------|------|---------|---------|----------|
| FR-CONTENT-001 | 공지사항 CRUD (5 EP) | 시험, 검사 | CRUD 성공/실패, meta 포함 | SDD §3-1 NoticeController |
| FR-CONTENT-002 | FAQ CRUD (5 EP) | 시험, 검사 | max_length[500], 카테고리 필터 | SDD §3-1 FaqController |
| FR-CONTENT-003 | 배너 CRUD + 시간 기반 활성화 | 시험, 분석 | starttime/endtime 실시간 필터 | SDD §3-3 BannerRepository |
| FR-CONTENT-004 | 테마 목록 (온콜/가격 필터) | 시험, 검사 | onFlag 필터, $db->escape() | SDD §3-3 ThemeRepository |
| NFR-CONTENT-001 | ResourceController 패턴 | 검사 | $routes->resource() 3건 | SDD §2 디렉토리 구조 |
| NFR-CONTENT-002 | 조회 응답 200ms 이하 (p95) | 시험 (k6) | 스테이징 부하 테스트 | SDD §3-3 인덱스 |
| NFR-CONTENT-003 | 배너 시간 활성화 정확도 | 검사 | NOW() 조건 쿼리 확인 | SDD ADR-2 |
| NFR-CONTENT-004 | 입력값 검증 | 시험 | 400 INVALID_INPUT 반환 | SDD §3-1 입력 검증 |
| NFR-CONTENT-005 | SQL Injection 방지 | 검사 | $db->escape() 적용 확인 | SDD §3-3 ThemeRepository |
| NFR-CONTENT-006 | 페이지네이션 meta | 시험 | meta camelCase 4 키 포함 | SDD §3-2 Service Layer |

---

## 8. Data Dictionary (데이터 사전)

### tb_banner

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `bn_no` | INT UNSIGNED | PK AUTO_INCREMENT | 배너 식별자 |
| `bn_img` | VARCHAR(500) | NOT NULL | 이미지 URL |
| `bn_link` | VARCHAR(500) | NULL | 클릭 링크 URL |
| `bn_name` | VARCHAR(200) | NULL | 배너 명칭 |
| `bn_position` | VARCHAR(50) | NOT NULL | 배치 위치 코드 |
| `bn_sort` | INT | DEFAULT 0 | 정렬 순서 (ASC) |
| `bn_view` | ENUM('Y','N') | DEFAULT 'Y' | 공개 여부 |
| `starttime` | DATETIME | NOT NULL | 노출 시작 시각 (UTC) |
| `endtime` | DATETIME | NOT NULL | 노출 종료 시각 (UTC) |
| `regist_date` | DATETIME | DEFAULT CURRENT_TIMESTAMP | 등록 일시 (UTC) |

**인덱스**: `INDEX idx_position_view (bn_position, bn_view, starttime, endtime)`

### tb_faq

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `faq_no` | INT UNSIGNED | PK AUTO_INCREMENT | FAQ 식별자 |
| `faq_question` | VARCHAR(500) | NOT NULL | 질문 (최대 500자) |
| `faq_answer` | TEXT | NOT NULL | 답변 |
| `faq_menu_code` | VARCHAR(50) | NULL | 카테고리 코드 |
| `faq_status` | ENUM('y','n') | DEFAULT 'n' | 활성화 여부 |
| `faq_type` | VARCHAR(20) | DEFAULT 'all' | 대상 유형 |
| `faq_order` | INT | DEFAULT 0 | 정렬 순서 (ASC) |
| `regist_date` | DATETIME | DEFAULT CURRENT_TIMESTAMP | 등록 일시 (UTC) |

**인덱스**: `INDEX idx_status_menu (faq_status, faq_menu_code)`

### tb_notice

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `nt_no` | INT UNSIGNED | PK AUTO_INCREMENT | 공지사항 식별자 |
| `nt_title` | VARCHAR(200) | NOT NULL | 제목 (최대 200자) |
| `nt_content` | TEXT | NOT NULL | 내용 |
| `nt_status` | ENUM('Y','N') | DEFAULT 'Y' | 게시 상태 |
| `regist_date` | DATETIME | DEFAULT CURRENT_TIMESTAMP | 등록 일시 (UTC) |

### API 응답 camelCase 매핑

| DB 컬럼 (snake_case) | API 응답 키 (camelCase) |
|---------------------|----------------------|
| `bn_no` | `bnNo` |
| `bn_img` | `bnImg` |
| `bn_position` | `bnPosition` |
| `bn_sort` | `bnSort` |
| `faq_question` | `faqQuestion` |
| `faq_menu_code` | `faqMenuCode` |
| `nt_title` | `ntTitle` |
| `nt_content` | `ntContent` |
| `regist_date` | `registDate` |

---

## 9. Feasibility Review (타당성 검토)

| 항목 | 근거 | 결론 |
|------|------|------|
| CI4 ResourceController 패턴 | CI4 4.7 공식 문서 — `$routes->resource('notices')` 호출 시 index/show/new/create/edit/update/delete 7개 라우트 자동 생성. Controller가 `ResourceController`를 상속하면 HTTP 메서드와 메서드명 자동 매핑. 보일러플레이트 제거. `only`/`except` 옵션으로 불필요 라우트 제한 가능. | 채택. 표준 패턴으로 신뢰성 높음. 구조적 일관성과 개발 생산성 모두 확보 |
| 시간 기반 배너 활성화 (DB 쿼리 vs 크론) | **DB 쿼리 시점 필터**: 요청마다 `starttime ≤ NOW() ≤ endtime` 조건 WHERE 절 적용. 정확한 실시간 제어, 크론 지연 없음. `INDEX idx_position_view` Range Scan 최적화. Aurora MySQL `NOW()` 함수는 쿼리 실행 시각 기준으로 정확한 실시간 제어 가능. **크론잡 방식**: 주기적 bn_view UPDATE — 크론 주기(1분) 오차, 운영 부담 증가. | DB 쿼리 시점 필터 채택. 실시간 제어 정확성 보장, 인덱스 설계로 성능 확보 |
| ThemeRepository `$db->escape()` — SQL Injection 방지 | OWASP Top 10 A03:2021 Injection — "Use of parameterized queries or stored procedures". CI4 Query Builder는 바인딩 자동 처리. `$db->query()` raw SQL 사용 시 `$db->escape()` 수동 이스케이프 필수. ThemeRepository는 JOIN + 서브쿼리 조합으로 Query Builder 단독 표현 불가 — raw SQL + `$db->escape()` 조합이 현실적 최선. | `$db->escape()` 필수 적용. OWASP A03 준수. 향후 Query Builder로 전환 가능 범위 단계적 리팩터링 검토 |

---

## 10. Change Impact Log (변경 영향 기록)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| IEEE 29148:2018 표준 전면 전환 (v1.2 → v2.0) | 1.1 목적, 1.2 범위, 1.3 정의, 1.4 참조, 1.5 구조 섹션 신설. 요구사항 추적성 강화. 국제 표준 준수로 문서 심사 통과 가능성 증대 | 프로젝트 지침 — IEEE 표준 전환 요구 |
| FR별 검증 방법(Verification Method) 추가 | 시험/검사/분석 방법 명시로 테스트 시나리오 자동 도출 가능. QA 팀이 요구사항 단위로 검증 계획 수립 가능 | IEEE 29148:2018 §9.5.10 — FR별 검증 방법 정의 의무 |
| NFR 정량 측정 기준 명시 | p95 200ms, max_value[100] 등 수치 기준 명시로 성능 테스트 합격 기준 명확화 | 기존 NFR에 측정 기준 없어 검증 불가 — SLA 수준 명시로 배포 전 테스트 기준 제공 |
| 요구사항 검증 매트릭스(섹션 7) 신설 | FR/NFR ↔ SDD 추적, 검증 방법, 조건 일괄 관리. 요구사항 누락 방지 | IEEE 29148:2018 — 요구사항 추적성 매트릭스 필수 |
| 데이터 사전(섹션 8) 신설 + tb_notice 추가 | tb_banner, tb_faq, tb_notice 스키마 및 camelCase 매핑 포함으로 구현자 참조 기준 단일화 | 설계 문서와 요구사항 문서 간 스키마 정보 중복 제거, SSOT 확립 |

---

## 11. Review Checklist (검토 체크리스트)

### 완전성 (Completeness)

- [x] IEEE 29148:2018 — 1.1~1.5 Introduction 섹션 완료
- [x] IEEE 29148:2018 — 2.1~2.5 Overall Description 섹션 완료
- [x] FR 전체 정의 (4건, 16개 EP) + 검증 방법 포함
- [x] FR별 입력 검증 규칙 명시
- [x] NFR 전체 정의 (6건) + 정량 측정 기준 포함
- [x] 외부 인터페이스 요구사항 (섹션 5) 완료
- [x] 유스케이스 정상/대안/에러 흐름 (3건)
- [x] 요구사항 검증 매트릭스 (섹션 7) 완료
- [x] 데이터 사전 (섹션 8, 3 테이블) 완료
- [x] 타당성 검토 (섹션 9, 3건)
- [x] 변경 영향 기록 (섹션 10, 5건)

### 일관성 (Consistency)

- [x] FR 간 상충 없음
- [x] NFR 측정 기준 구체적 (p95, max_value 등)
- [x] 유스케이스와 FR 매핑 완전
- [x] camelCase 컨벤션 일관 적용

### 검증 가능성 (Verifiability)

- [x] 각 FR에 검증 방법(Test/Inspection/Analysis) 명시
- [x] 수락 조건 명확 (CRUD 성공/실패, 시간 필터)
- [x] NFR 정량 기준 수치화

### 추적성 (Traceability)

- [x] FR ↔ API 엔드포인트 매핑
- [x] FR ↔ 유스케이스 매핑
- [x] FR/NFR ↔ SDD 섹션 추적 (검증 매트릭스)

---

## 12. Change Log (변경 로그)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-15 | 1.0.0 | 초기 작성 |
| 2026-04-15 | 1.1.0 | 유스케이스 3건, 제약사항, 용어 정의, NFR 2건 추가. FR 선행/후행 조건 보강 |
| 2026-04-15 | 1.2.0 | FR 입력 검증 규칙 추가, NFR-006(응답 시간) 추가, 타당성 검토, 변경 영향 기록 신설 |
| 2026-04-15 | 2.0.0 | IEEE 표준 전면 전환. Introduction 5섹션, Overall Description 5섹션, FR 검증 방법, NFR 정량 기준, 외부 인터페이스, 검증 매트릭스, 데이터 사전 추가 |
| 2026-04-15 | 2.1.0 | tb_notice 데이터 사전 추가, Data Dictionary SSOT 완성, NFR 서술 강화 |
