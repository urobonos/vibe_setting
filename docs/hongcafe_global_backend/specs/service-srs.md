---
문서명: Service 모듈 소프트웨어 요구사항 명세서 (SRS)
문서ID: SRS-SVC-001
버전: v2.1
적용 표준: IEEE 29148:2018
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
대상 시스템: HongCafe Global Backend — Service Module
관련 문서:
  - service-sdd.md (SDD-SVC-001)
  - service-idd.md (IDD-SVC-001)
  - docs/api-specification.md
---

# SRS-SVC-001: Service 모듈 소프트웨어 요구사항 명세서

> **IEEE 29148:2018** 준수 — Software Requirements Specification
> 서비스 목록 조회, 차단(Reject) CRUD, Hermes 온콜 연동, a8.net 제휴 추적을 포함하는
> 7개 엔드포인트의 기능·비기능 요구사항을 정의한다.

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 HongCafe Global Backend의 **Service 모듈**에 대한 소프트웨어 요구사항을 IEEE 29148:2018 표준에 따라 명세한다. 대상 독자는 개발자, QA 엔지니어, 아키텍트이며, 구현·검증의 기준으로 활용된다.

### 1.2 Scope (범위)

Service 모듈은 다음 기능 영역을 포함한다.

| 기능 영역 | 주요 Controller | 엔드포인트 수 |
|-----------|----------------|--------------|
| 서비스 목록 조회 | `ServiceController` | 2 |
| 차단(Reject) CRUD | `RejectController` | 3 |
| Hermes 온콜 연동 | `HermesController` | 2 |

> **[Open Question OQ-3]** 서비스 상세 조회 EP (`GET /api/services/{id}`)는 본 SRS v2.0에 FR-SVC-002로 정의되어 있었으나, 실제 Routes.php, API 문서(md/yaml), 컨트롤러 어디에도 구현이 존재하지 않는다. 미구현 상태이므로 현 버전에서 "미구현 / 제품 결정 대기"로 표기하며, 구현 완료 시 별도 개정으로 반영한다.

**외부 시스템 연동**:
- Hermes DB (MySQL, `101.101.211.242`) — 온콜 상담사 상태 조회
- a8.net Affiliate Tracking API — 결제 전환 이벤트 전송 (cURL GET)

**모듈 경로**: `app/Modules/Service/`

### 1.3 Definitions, Acronyms, and Abbreviations (정의 및 약어)

| 용어 | 정의 |
|------|------|
| Hermes | 온콜 상담 서비스 외부 시스템. MySQL DB 주소: `101.101.211.242` |
| On-call | 즉시 연결 가능한 상담사와의 실시간 통화 서비스 |
| Reject | 특정 사용자·상담사 간 상호 차단 레코드. 테이블: `tb_reject` |
| a8.net | 일본 기반 제휴 마케팅 플랫폼 (Affiliate 8) |
| A8TrackingService | a8.net API cURL GET 호출로 결제 전환 이벤트를 기록하는 서비스 클래스 |
| HermesService | Hermes DB 연결 및 온콜 상담사 매핑을 처리하는 서비스 클래스 |
| ServiceRepository | 서비스 목록·상세 조회 10개 메서드를 제공하는 Repository |
| RejectRepository | 차단 CRUD 9개 메서드를 제공하는 Repository |
| HermesRepository | Hermes 외부 DB 연동 12개 메서드를 제공하는 Repository |
| FR | Functional Requirement (기능 요구사항) |
| NFR | Non-Functional Requirement (비기능 요구사항) |
| JWT | JSON Web Token (인증 토큰) |
| CRUD | Create, Read, Update, Delete |
| SRS | Software Requirements Specification |
| camelCase | API 응답 필드 네이밍 규칙 (`createdAt`, `ceCode` 등) |
| BC | Bounded Context (경계 컨텍스트) |
| DI | Dependency Injection (의존성 주입) |

### 1.4 References (참조 문서)

| 문서 | 설명 |
|------|------|
| IEEE 29148:2018 | Systems and software engineering — Life cycle processes — Requirements engineering |
| service-sdd.md (SDD-SVC-001) | Service 모듈 소프트웨어 설계 문서 |
| service-idd.md (IDD-SVC-001) | Service 모듈 인터페이스 설계 문서 |
| docs/api-specification.md | 전체 API 엔드포인트 명세 (~160개) |
| CLAUDE.md | 프로젝트 코딩 표준 및 아키텍처 지침 |
| OWASP API Security Top 10 2023 | API 보안 표준 (API5:2023 BFLA 준수) |

### 1.5 Overview (문서 구성)

- **섹션 2**: 전체 시스템 기술 (System Description)
- **섹션 3**: 기능 요구사항 (FR)
- **섹션 4**: 비기능 요구사항 (NFR)
- **섹션 5**: 유스케이스 (Use Cases)
- **섹션 6**: 엔드포인트 목록
- **섹션 7**: 타당성 검토 (Feasibility Review)
- **섹션 8**: 검증 체크리스트
- **섹션 9**: 변경 이력

---

## 2. Overall Description (전체 시스템 기술)

### 2.1 Product Perspective (시스템 위치)

Service 모듈은 HongCafe Global Backend Modular Monolith 아키텍처의 일부이다. 상담 서비스 목록, 차단 관계, Hermes 온콜 연동을 담당하며, 인접 모듈(Commerce, Member, Shared)과 Interface Only 원칙으로 통신한다.

```
[Client (Next.js)] ──→ [Nginx/ALB] ──→ [CodeIgniter 4.7+]
                                              │
                          ┌───────────────────┼───────────────────┐
                          │                   │                   │
                   ServiceController   RejectController   HermesController
                          │                   │                   │
                   ServiceRepository   RejectRepository   HermesRepository
                          │                   │                   │
                   Aurora MySQL         Aurora MySQL        Hermes DB
                   (tb_items)          (tb_reject)       (101.101.211.242)
                                                               │
                                                        [A8TrackingService]
                                                               │
                                                         a8.net API
```

### 2.2 Product Functions (주요 기능 요약)

1. 서비스(상담 유형) 목록·상세 조회 — 정렬·필터 지원
2. 사용자·상담사 간 차단(Reject) 등록, 해제, 목록 조회
3. Hermes 외부 DB 연동을 통한 온콜 상담사 상태 조회 및 연결 요청
4. a8.net 제휴 추적 — 결제 완료 시 전환 이벤트 비동기 전송

### 2.3 User Classes and Characteristics (사용자 분류)

| 사용자 유형 | 특성 | 접근 가능 기능 |
|------------|------|--------------|
| Caller (일반 사용자) | 로그인 필수 | 서비스 조회, 차단 CRUD, 온콜 요청 |
| Callee (상담사) | 로그인 + `ce_code` 보유 | 서비스 조회, 차단 CRUD |
| Anonymous | 인증 없음 | 서비스 목록/상세 조회 (공개 EP) |
| 시스템 (내부) | 결제 완료 이벤트 트리거 | a8.net 추적 이벤트 발송 |

### 2.4 Operating Environment (운영 환경)

| 항목 | 값 |
|------|----|
| 언어/프레임워크 | PHP 8.4+ / CodeIgniter 4.7+ |
| DB (내부) | Amazon Aurora MySQL 3.12.0 (MySQL 8.0.44 호환) |
| DB (외부 Hermes) | MySQL, `101.101.211.242` — 직접 TCP 연결 |
| 외부 API | a8.net (cURL GET) |
| 배포 환경 Production | `https://prd.gl.hongcafe.com` |
| 배포 환경 Staging | `https://stg.gl.hongcafe.com` |
| 배포 환경 Development | `https://dev.gl.hongcafe.com` |

### 2.5 Constraints (제약 사항)

- PHP `declare(strict_types=1)` 필수
- `DateTimeImmutable` 강제 (`date()`, `time()` 사용 금지)
- 모든 DB 조작은 Repository 계층에서만 수행
- Hermes DB는 내부 Aurora 커넥션 풀과 분리된 별도 커넥션 그룹 사용
- a8.net 추적 실패는 메인 비즈니스 로직에 영향을 주지 않아야 함
- Auto Routing 비활성화 (`setAutoRoute(false)`); 모든 EP는 `Routes.php`에 명시적 등록

### 2.6 Assumptions and Dependencies (전제 및 의존성)

- `A8_PID` 환경변수가 설정되어 있음을 전제로 한다.
- Hermes DB 접속 자격증명이 환경변수로 구성되어 있음을 전제로 한다.
- `tb_items` 테이블은 Commerce 모듈과 공유하며 스키마 변경 시 양 모듈 담당자 협의 필요.
- `tb_reject` 테이블은 Service 모듈 전용이며, UNIQUE KEY `(ce_code, cr_code)` 제약이 존재한다.
- JWT 인증 인프라(AuthFilter, JwtService)는 Shared/Auth 모듈이 제공한다고 가정한다.

---

## 3. Functional Requirements (기능 요구사항)

각 FR은 `[ID] | [우선순위] | [연관 UC]` 형식으로 추적 가능하다.

### FR-SVC-001: 서비스 목록 조회 (Service Listing)

**ID**: FR-SVC-001 | **우선순위**: P1 (필수) | **연관 UC**: UC-SVC-001

**설명**: `ServiceController`가 활성 서비스(상담 유형) 목록을 조회하여 반환한다. 2개의 실제 EP가 존재한다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 1.1 | `POST /api/services/get-service-list-mobile`로 서비스 목록을 반환한다 | API 호출 확인 |
| 1.2 | `POST /api/services/get-service-list-mobile-new`로 신규 서비스 목록을 반환한다 | API 호출 확인 |
| 1.3 | `ServiceRepository`를 통해 `tb_items`에서 데이터를 조회한다 | Unit Test |
| 1.4 | 응답 필드: camelCase 변환 적용 | 응답 JSON 검증 |
| 1.5 | 비활성 서비스는 목록에서 제외한다 | DB 상태값 확인 |

**입력 (EP 1)**: `POST /api/services/get-service-list-mobile` Body JSON
**입력 (EP 2)**: `POST /api/services/get-service-list-mobile-new` Body JSON
**출력**: `HTTP 200 { "data": [...] }` (camelCase JSON 배열)
**인증**: 없음 (공개 EP)
**CSRF**: 면제 (POST이나 공개 조회 EP — API Key 인증 없음, 내부 서비스 조회 목적)
**선행 조건**: 없음 (공개 또는 로그인 사용자 모두 접근 가능)
**후행 조건**: 활성 서비스 목록이 JSON 배열로 반환된다

---

### FR-SVC-002: 서비스 상세 조회 ⚠️ 미구현 — 제품 결정 대기

**ID**: FR-SVC-002 | **우선순위**: P1 (필수, 보류) | **연관 UC**: UC-SVC-001

> **[Open Question OQ-3 / SERVICE-DEF-002]** 본 FR은 SRS v2.0에 정의되어 있으나,
> 실제 `app/Modules/Service/Config/Routes.php`, API 문서(`service-api.md`, `service-api.yaml`),
> 컨트롤러(`ServiceController.php`) 어디에도 구현이 존재하지 않는다.
>
> **현재 상태**: **미구현 (Not Implemented)** — 제품 책임자(PO) 결정 대기
>
> **구현 결정 시**: 별도 개정(v2.2+)으로 EP URL, 인증, 응답 스키마를 SSOT(API 문서)에 맞춰 반영한다.
> **삭제 결정 시**: 다음 개정에서 본 FR을 제거하고 변경 이력에 기록한다.

**설명**: 서비스 ID로 단일 서비스 레코드를 조회하여 반환한다. (설계 의도만 기록)

**세부 요건** (설계 의도 — 미확정):

| # | 요건 | 상태 |
|---|------|------|
| 2.1 | 단건 서비스를 반환한다 | 미구현 |
| 2.2 | 응답 필드: 서비스 설명, 상담사 목록, 가격, 카테고리 (camelCase) | 미구현 |
| 2.3 | 존재하지 않는 ID 요청 시 `NOT_FOUND` (HTTP 404) 반환 | 미구현 |

**입력**: 미정 (구현 시 Routes.php 및 API 문서 SSOT 기준으로 확정)
**출력**: 미정

---

### FR-SVC-003: 차단 등록 (Reject Create)

**ID**: FR-SVC-003 | **우선순위**: P2 (중요) | **연관 UC**: UC-SVC-002

**설명**: 인증된 사용자가 특정 상대방을 차단하는 레코드를 생성한다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 3.1 | `POST /api/rejects/save-reject`로 차단 레코드를 삽입한다 | API 호출 확인 |
| 3.2 | `RejectRepository`를 통해 `tb_reject`에 레코드를 삽입한다 | Unit Test |
| 3.3 | 요청 필수 파라미터: `ce_code`, `cr_code`, `rj_code`, `rj_content` — 누락 시 `INVALID_INPUT` (HTTP 400) | 입력값 검증 테스트 |
| 3.4 | `tb_reject` UNIQUE KEY `(ce_code, cr_code)` 위반 시 `CONFLICT` (HTTP 409) 반환 | 중복 요청 테스트 |
| 3.5 | 차단 등록 후 예약 가용성 조회에 즉시 반영된다 | 통합 테스트 |
| 3.6 | JWT 인증 필수; 미인증 시 `UNAUTHORIZED` (HTTP 401) 반환 | 인증 테스트 |
| 3.7 | CSRF 토큰 (`X-CSRF-TOKEN` 헤더) 필수 | CSRF 검증 테스트 |

> **[SERVICE-DEF-004 / 페이즈 2 트랙 B]** 현재 Routes.php에서 `save-reject`에 `auth` 필터가 누락되어 있다. 요건 3.6은 코드 수정 완료 시 충족된다. 코드 수정은 페이즈 2 트랙 B에서 처리한다.

**DB 스키마**: `tb_reject(rj_no PK, ce_code, cr_code, rj_code, rj_content, UNIQUE(ce_code, cr_code))`
**선행 조건**: JWT 인증 완료, 차단 대상 존재
**후행 조건**: `tb_reject`에 레코드 삽입, 예약 가용성 반영

---

### FR-SVC-004: 차단 해제 (Reject Delete)

**ID**: FR-SVC-004 | **우선순위**: P2 (중요) | **연관 UC**: UC-SVC-002

**설명**: 인증된 사용자가 기존에 등록한 차단을 해제한다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 4.1 | `DELETE /api/rejects/delete-reject`로 차단 레코드를 삭제한다 | API 호출 확인 |
| 4.2 | 요청 필수 파라미터: `rj_code` (차단 식별자) — 누락 시 `INVALID_INPUT` (HTTP 400) | 입력값 검증 테스트 |
| 4.3 | 차단 레코드가 미존재 또는 타인 소유일 경우 `NOT_FOUND` (HTTP 404) 반환 | 에러 케이스 테스트 |
| 4.4 | 차단 해제 후 해당 상대방과 다시 예약이 가능해진다 | 통합 테스트 |
| 4.5 | JWT 인증 및 CSRF 토큰 필수 | 인증 테스트 |

> **[SERVICE-DEF-004 / 페이즈 2 트랙 B]** 현재 Routes.php에서 `delete-reject`에 `auth` 필터가 누락되어 있다. 요건 4.5는 코드 수정 완료 시 충족된다. 코드 수정은 페이즈 2 트랙 B에서 처리한다.

---

### FR-SVC-005: 차단 목록 조회 (Reject List)

**ID**: FR-SVC-005 | **우선순위**: P2 (중요) | **연관 UC**: UC-SVC-002

**설명**: 인증된 상담사(Callee)가 본인의 차단 목록을 페이지네이션과 함께 조회한다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 5.1 | `POST /api/rejects/get-callee-reject-list`로 본인 차단 목록을 반환한다 | API 호출 확인 |
| 5.2 | 상담사 전용 EP — `role:callee` 필터 적용 (JWT + ce_code 보유 검증) | RBAC 테스트 |
| 5.3 | 응답에 차단 대상 닉네임(`crNick`), 차단 코드(`rjCode`), 날짜(`formattedDate`) 포함 | 응답 필드 검증 |
| 5.4 | JWT 인증 필수 (role:callee 필터 내부에서 수행) | 인증 테스트 |
| 5.5 | POST 메서드이나 조회 목적 EP — csrftoken 필터 현재 미등록 상태 | 비고 참조 |

> **[SERVICE-DEF-008]** `get-callee-reject-list`는 POST 메서드이나 Routes.php에서 `csrftoken` 필터가 등록되어 있지 않다. 이는 상담사 전용 조회 EP(GET 의미)로 판단되며, csrftoken 면제가 의도적인지 여부는 Open Question OQ-2로 관리한다. 현 명세는 실제 Routes.php를 SSOT로 반영한다.

**출력**:

```json
{
  "data": [ ... ],
  "meta": { "currentPage": 1, "perPage": 20, "total": 100, "lastPage": 5 }
}
```

---

### FR-SVC-006: Hermes 온콜 상담사 조회

**ID**: FR-SVC-006 | **우선순위**: P1 (필수) | **연관 UC**: UC-SVC-003

**설명**: `HermesController` + `HermesService` + `HermesRepository`를 통해 외부 Hermes DB에서 온콜 상담사를 조회한다. 2개의 실제 EP가 존재하며, 온콜 연결 요청 EP는 미구현 상태이다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 6.1 | `POST /api/hermes/get-on-call-callee`로 온콜 상담사 목록을 반환한다 (`auth:apikey` 필터) | API 호출 확인 |
| 6.2 | `POST /api/hermes/get-on-call-callee-hecode`로 온콜 상담사 heCode 목록을 반환한다 (`auth:apikey` 필터) | API 호출 확인 |
| 6.3 | `HermesRepository`가 외부 Hermes DB (`101.101.211.242`)에 접속하여 데이터를 조회한다 | 통합 테스트 |
| 6.4 | Hermes DB는 내부 Aurora MySQL과 별도 커넥션 그룹을 사용한다 | 설정 확인 |
| 6.5 | `HermesService`가 Hermes DB 결과와 내부 사용자 정보를 매핑하여 heCode 키 맵(`{ "HE001": {...} }`)으로 반환한다 | Unit Test |
| 6.6 | Hermes DB 연결 실패 시 `INTERNAL` (HTTP 500) 반환 및 에러 로그 기록 | 장애 시나리오 테스트 |
| 6.7 | API Key 인증 필수 (`X-Api-Key` 헤더) — 서버-서버 통신 전용 EP | 인증 테스트 |
| 6.8 | API Key 인증 EP이므로 CSRF 면제 (CLAUDE.md 보안 정책 — API Key 인증 시 CSRF 면제) | — |

> **[Open Question OQ-1 / SERVICE-DEF-003]** 온콜 연결 요청 EP (`POST /api/hermes/on-call/connect`)는 SRS v2.0에 FR-SVC-006 요건 6.5로 정의되어 있었으나, 실제 Routes.php, API 문서, 컨트롤러 어디에도 구현이 존재하지 않는다.
> **현재 상태**: **미구현 (Not Implemented)** — 제품 결정 대기. 구현 완료 시 별도 개정으로 반영한다.

**선행 조건**: Hermes DB 접속 자격증명이 환경변수로 설정되어 있음, 유효한 API Key 존재
**후행 조건**: 온콜 상담사 목록 또는 heCode 목록이 반환됨

---

### FR-SVC-007: a8.net 제휴 추적 (Affiliate Tracking)

**ID**: FR-SVC-007 | **우선순위**: P3 (선택) | **연관 UC**: UC-SVC-004

**설명**: 결제 완료 이벤트 발생 시 `A8TrackingService`가 a8.net API에 전환 이벤트를 cURL GET으로 전송한다. 첫 결제(First Payment Conversion) 이벤트를 대상으로 한다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 7.1 | `A8TrackingService`가 a8.net API를 cURL GET으로 호출한다 | Unit Test (Mock) |
| 7.2 | 추적 파라미터: `pid`(프로그램 ID), `price`(결제 금액), `so`(주문 번호), `currency` | 요청 파라미터 검증 |
| 7.3 | a8.net API 호출 실패·타임아웃(3초) 시 에러 로그만 기록하고 계속 진행 | 실패 격리 테스트 |
| 7.4 | 결제 완료 처리 결과에 영향을 주지 않는다 (Fire-and-Forget) | 통합 테스트 |
| 7.5 | 첫 결제(First Payment Conversion) 이벤트만 전송한다 | 비즈니스 로직 테스트 |

**선행 조건**: `A8_PID` 환경변수 설정
**후행 조건**: a8.net 전환 이벤트 기록 (비동기, 실패 무시)

---

## 4. Non-Functional Requirements (비기능 요구사항)

### NFR-SVC-001: Hermes DB 연결 격리 (Isolation)

**ID**: NFR-SVC-001 | **우선순위**: P1 (필수)

| 항목 | 요건 |
|------|------|
| 커넥션 분리 | Hermes DB는 Aurora MySQL과 별도 DB 커넥션 그룹 사용 |
| 영향 차단 | Hermes DB 장애가 내부 커넥션 풀에 영향을 주어서는 안 됨 |
| 연결 타임아웃 | 5초 |
| 재시도 정책 | 없음 — 연결 실패 시 즉시 `INTERNAL` 에러 반환 |
| 자격증명 보호 | Hermes DB 비밀번호를 로그에 기록하지 않음 |

### NFR-SVC-002: a8.net 추적 격리 (Fire-and-Forget)

**ID**: NFR-SVC-002 | **우선순위**: P1 (필수)

| 항목 | 요건 |
|------|------|
| 실패 격리 | A8TrackingService 실패가 결제 로직에 영향을 주어서는 안 됨 |
| API 타임아웃 | 3초 |
| 실패 처리 | 에러 로그 기록 후 계속 진행 |
| 구현 방식 | `try-catch`로 감싸고 예외를 상위로 전파하지 않음 |

### NFR-SVC-003: 차단 반영 실시간성

**ID**: NFR-SVC-003 | **우선순위**: P2 (중요)

- 차단 등록·해제 후 다음 슬롯 조회 요청에서 즉시 반영되어야 한다.
- 캐시 사용 시 차단 변경 즉시 관련 캐시를 무효화한다.

### NFR-SVC-004: 보안 (Security)

**ID**: NFR-SVC-004 | **우선순위**: P1 (필수)

| 항목 | 요건 |
|------|------|
| 인증 | `RejectController` 전체 EP에 JWT 인증 필수. `HermesController` 전체 EP에 API Key 인증 필수 |
| 인가 | `RejectController`: 소유권 검증 (Layer 3 쿼리 조건). `get-callee-reject-list`: `role:callee` 필터 |
| CSRF | POST/DELETE 요청에 `X-CSRF-TOKEN` 헤더 필수. API Key 인증 EP 및 공개 조회 EP는 면제 |
| 자격증명 | Hermes DB 비밀번호 로그 기록 금지 |
| 필터 체인 | `ratelimit → csrftoken → auth → role:callee(해당 시) → Controller` |
| RBAC | OWASP API5:2023 3계층 Defense in Depth 준수 |
| JWT Cookie Path | Access Token: `/`, Refresh Token: `/` (커밋 a7be0b5 기준) |

> **[SERVICE-DEF-004 / 페이즈 2 트랙 B]**: 현재 `save-reject`, `delete-reject` Routes.php 등록 시 auth 필터가 누락됨. 이는 코드 버그로서 페이즈 2 트랙 B에서 수정 예정.

### NFR-SVC-005: 성능 (Performance)

**ID**: NFR-SVC-005 | **우선순위**: P2 (중요)

| 항목 | 목표 |
|------|------|
| 서비스 목록 조회 응답시간 | p95 500ms 이하 |
| 차단 목록 조회 응답시간 | p95 500ms 이하 |
| Hermes 온콜 조회 응답시간 | p95 2000ms 이하 (외부 DB 포함) |

---

## 5. Use Cases (유스케이스)

### UC-SVC-001: 사용자가 서비스 목록을 조회한다

```
액터: 사용자 (로그인 또는 비로그인)
사전 조건: 없음

주 시나리오:
  1. 사용자가 POST /api/services/get-service-list-mobile 또는
     POST /api/services/get-service-list-mobile-new 를 호출한다.
  2. ServiceController가 요청 body를 파싱한다.
  3. ServiceRepository.getMobileService() / getMobileServiceNew()로
     tb_items에서 활성 서비스를 조회한다.
  4. snake_case → camelCase 변환 후 HTTP 200 JSON 배열을 반환한다.

대안 시나리오:
  A1. 활성 서비스 없음 → 빈 배열 반환 (HTTP 200).
  A2. DB 오류 → INTERNAL (HTTP 500) 반환.
```

### UC-SVC-002: 사용자가 상담사를 차단한다

```
액터: 로그인 사용자 (Caller 또는 Callee)
사전 조건: JWT 인증 완료, 차단 대상 존재

주 시나리오:
  1. 사용자가 ce_code, cr_code, rj_code, rj_content를 포함하여
     POST /api/rejects/save-reject 를 호출한다.
  2. csrftoken 필터가 X-CSRF-TOKEN 헤더를 검증한다.
  3. auth 필터가 JWT를 검증하고 ac_id를 추출한다.
     (※ 페이즈 2 트랙 B: 현재 Routes.php에서 auth 필터 미등록 상태 — SERVICE-DEF-004)
  4. RejectRepository.insertReject()가 tb_reject에 레코드를 삽입한다.
  5. HTTP 200 성공 응답을 반환한다.

대안 시나리오:
  A1. 필수 파라미터 누락 → INVALID_INPUT (HTTP 400) 반환.
  A2. 이미 차단된 대상 → UNIQUE KEY 위반 → CONFLICT (HTTP 409) 반환.
  A3. JWT 미인증 → UNAUTHORIZED (HTTP 401) 반환.
  A4. CSRF 토큰 불일치 → FORBIDDEN (HTTP 403) 반환.
```

### UC-SVC-003: Hermes 온콜 상담사를 조회한다

```
액터: 내부 서비스 (API Key 인증)
사전 조건: 유효한 API Key, Hermes DB 연결 가능

주 시나리오:
  1. 내부 서비스가 POST /api/hermes/get-on-call-callee 를 호출한다
     (또는 POST /api/hermes/get-on-call-callee-hecode).
  2. auth:apikey 필터가 X-Api-Key 헤더를 검증한다.
  3. HermesService가 HermesRepository를 통해 Hermes DB에서 온콜 상담사 목록을 조회한다.
  4. he_code를 맵 키로 사용하여 { "HE001": {...}, "HE002": {...} } 형태로 반환한다.

대안 시나리오:
  A1. Hermes DB 연결 실패(타임아웃 5초 초과) → INTERNAL (HTTP 500) + 에러 로그.
  A2. API Key 미인증 → UNAUTHORIZED (HTTP 401) 반환.

미구현 시나리오 (Open Question OQ-1):
  - 온콜 연결 요청 EP는 현재 미구현 상태이다.
    구현 완료 시 별도 UC로 추가한다.
```

### UC-SVC-004: 결제 완료 후 a8.net 추적 이벤트가 발송된다

```
액터: 시스템 (결제 완료 이벤트 트리거)
사전 조건: A8_PID 환경변수 설정, 첫 결제 이벤트

주 시나리오:
  1. 결제 완료 처리 후 A8TrackingService.track()을 호출한다.
  2. A8TrackingService가 a8.net API에 cURL GET으로 전환 이벤트를 전송한다.
  3. 전송 성공 시 info 로그를 기록한다.

대안 시나리오:
  A1. cURL 타임아웃(3초) 또는 에러 → try-catch로 에러 로그만 기록.
  A2. 결제 완료 처리에는 영향 없음 (Fire-and-Forget).
```

---

## 6. Endpoint Summary (엔드포인트 요약)

> **SSOT**: `app/Modules/Service/Config/Routes.php` + `api-docs/service/service-api.md`
> v2.0에서 정의된 RESTful URL은 실제 구현과 불일치하였다. v2.1에서 실제 EP 기준으로 전면 교체한다.

| # | Controller | Method | Path | 설명 | 인증 | CSRF |
|---|-----------|--------|------|------|------|------|
| 1 | ServiceController | POST | `/api/services/get-service-list-mobile` | 서비스 목록 조회 (모바일) | 없음 | 면제 |
| 2 | ServiceController | POST | `/api/services/get-service-list-mobile-new` | 서비스 목록 조회 (신규) | 없음 | 면제 |
| 3 | RejectController | POST | `/api/rejects/save-reject` | 차단 등록 | JWT | 필수 |
| 4 | RejectController | DELETE | `/api/rejects/delete-reject` | 차단 해제 | JWT | 필수 |
| 5 | RejectController | POST | `/api/rejects/get-callee-reject-list` | 차단 목록 조회 (상담사 전용) | JWT + role:callee | 면제(※주1) |
| 6 | HermesController | POST | `/api/hermes/get-on-call-callee` | 온콜 상담사 목록 | API Key | 면제(API Key) |
| 7 | HermesController | POST | `/api/hermes/get-on-call-callee-hecode` | 온콜 상담사 heCode 목록 | API Key | 면제(API Key) |

**미구현 EP (Open Question)**:

| EP | 설명 | 상태 |
|----|------|------|
| `GET /api/services/{id}` | 서비스 상세 조회 | 미구현 — 제품 결정 대기 (OQ-3) |
| `POST /api/hermes/on-call/connect` | 온콜 연결 요청 | 미구현 — 제품 결정 대기 (OQ-1) |

> **※주1**: `get-callee-reject-list`는 POST 메서드이나 csrftoken 필터가 Routes.php에 미등록 상태. 의도 여부는 OQ-2로 관리. 현 명세는 실제 코드 기준을 SSOT로 반영.
> **※주2**: EP #3, #4는 Routes.php에서 auth 필터 미등록 상태(SERVICE-DEF-004 / 페이즈 2 트랙 B). 코드 수정 완료 시 인증 요건 충족.

---

## 7. Feasibility Review (타당성 검토)

| 요건 | 채택 패턴/표준 | 근거 출처 | 검토 결과 |
|------|-------------|----------|---------|
| Hermes DB 별도 커넥션 그룹 | CI4 Database — Multiple Connections | CodeIgniter 4 공식 문서: "You can configure more than one database" — `$db` 그룹명으로 복수 커넥션 구성 가능 | 적합. `$db = db_connect('hermes')` 방식으로 Aurora 커넥션과 완전 분리. 장애 전파 차단 |
| a8.net Fire-and-Forget (try-catch 격리) | Resilience — Bulkhead Pattern | Microsoft Resilience Patterns: Bulkhead Pattern — "Isolate elements of an application into pools so that if one fails, the others will continue to function" | 적합. A8TrackingService를 try-catch로 격리하여 외부 API 장애가 결제 로직에 전파되지 않음. 타임아웃 3초 설정으로 응답 지연 방지 |
| tb_reject UNIQUE KEY 중복 방지 | DB constraint 기반 낙관적 동시성 제어 | MySQL 8.0 공식 문서: "UNIQUE indexes enforce the constraint at the storage engine level… even under concurrent inserts" | 필수 준수. 동시 차단 등록 요청 시 race condition 발생 가능 → DB UNIQUE KEY가 최후 방어선. 애플리케이션 레벨 중복 검사와 이중 방어 |
| CI4 Pager 사용 | CI4 Pagination 공식 가이드 | CodeIgniter 4 공식 문서 Pagination 섹션: "The Model::paginate() method will automatically set the page count for the pager" | 적합. CI4 내장 Pager는 `paginate()` + `pager` 프로퍼티로 표준화된 meta 응답 생성. 커스텀 구현 금지(CLAUDE.md 지침) |
| 3계층 RBAC Defense in Depth | OWASP API5:2023 — BFLA (Broken Function Level Authorization) | OWASP API Security Top 10 2023: "API5:2023 — Broken Function Level Authorization: Implement a consistent and easy-to-analyze authorization model" | 필수 준수. Layer1(RoleFilter) + Layer2(checkNeedLogin) + Layer3(Repository 소유권 쿼리) 3계층으로 단일 계층 우회 시에도 보호 |

---

## 8. Verification Checklist (검증 체크리스트)

| ID | 요건 | 구현 확인 | 테스트 확인 | 비고 |
|----|------|---------|-----------|------|
| FR-SVC-001 | 서비스 목록 sort/filter 지원 | - | - | ServiceRepository |
| FR-SVC-001 | camelCase 응답 변환 | - | - | |
| FR-SVC-002 | NOT_FOUND(404) 반환 | - | - | 미존재 ID |
| FR-SVC-003 | CONFLICT(409) 중복 차단 | - | - | UNIQUE KEY |
| FR-SVC-004 | 소유권 검증 (ac_id) | - | - | Layer 3 쿼리 |
| FR-SVC-005 | CI4 Pager 페이지네이션 | - | - | meta 필드 확인 |
| FR-SVC-006 | Hermes 별도 커넥션 그룹 | - | - | DB config 분리 |
| FR-SVC-006 | Hermes 실패 시 INTERNAL(500) | - | - | 에러 로그 포함 |
| FR-SVC-007 | A8TrackingService try-catch 격리 | - | - | 결제 로직 무영향 |
| NFR-SVC-001 | Hermes 타임아웃 5초 설정 | - | - | 커넥션 설정 확인 |
| NFR-SVC-002 | a8.net API 타임아웃 3초 | - | - | cURL 옵션 |
| NFR-SVC-004 | Hermes DB 비밀번호 로그 미기록 | - | - | 로그 마스킹 |

---

## 9. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS |
| v2.1 | 2026-04-15 | jypark | 타당성 검토(섹션 7) 추가. 변경 영향 기록 및 운영환경 URL 3개 완비. IEEE 29148:2018 완전 준수 |
| v2.1 | 2026-04-21 | jypark | **API ↔ IEEE 대조 리포트(service-api-vs-ieee-20260421.md) [A] 이슈 반영**: EP URL/메서드 실제 코드 기준으로 전면 교체(SERVICE-DEF-001,002). FR-SVC-001 2개 EP 반영. FR-SVC-002 미구현 표기(OQ-3). FR-SVC-003/004 입력 파라미터 4개 및 에러 코드 정정. FR-SVC-005 POST+role:callee 반영(SERVICE-DEF-008). FR-SVC-006 Hermes 2개 EP+API Key 인증 반영, 연결 EP 미구현 표기(OQ-1). NFR-SVC-004 Refresh Token Path `/` 수정(SERVICE-DEF-007). UC 시나리오 실제 EP URL 반영. 섹션 6 EP 표 전면 갱신. |

### 변경 영향 기록 (v2.1)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| 섹션 6 EP URL/메서드 전면 교체 | IEEE 문서가 실제 API와 일치하여 개발·QA 혼선 제거 | Routes.php + API md/yaml이 SSOT; SRS v2.0의 RESTful URL은 실제 구현과 불일치 |
| FR-SVC-002 미구현 표기 (OQ-3) | 미구현 EP를 "미구현 / 제품 결정 대기"로 명시적 관리 | 코드·API 문서 어디에도 없는 EP를 요구사항에서 유효한 것처럼 기술하면 개발팀 혼란 초래 |
| FR-SVC-003/004 입력 파라미터 4개로 수정 | 실제 입력 계약이 문서에 반영되어 프론트엔드 연동 명세 정확성 확보 | IDD 4.3에 2개 필드만 명세되어 있었으나 실제 코드는 4개 필수 |
| FR-SVC-005 POST+role:callee 반영 | 메서드와 인증 요건이 실제 라우트와 일치 | v2.0이 GET으로 잘못 기술하여 CSRF 면제 근거가 부정확 |
| FR-SVC-006 API Key 인증 반영 | Hermes EP 접근 주체(내부 서비스)가 명확히 명세됨 | v2.0이 JWT 인증으로 잘못 기술 |
| Hermes 연결 EP 미구현 표기 (OQ-1) | 미구현 EP를 투명하게 관리하여 제품 결정 트래킹 가능 | 구현 없는 EP가 요구사항에 유효한 것처럼 포함되면 검증 체크리스트 오류 초래 |
| NFR-SVC-004 Refresh Token Path `/` 수정 | 보안 정책 문서가 최신 운영 설정과 일치 | 커밋 a7be0b5에서 Path가 `/`로 변경되었으나 문서에 미반영 |
