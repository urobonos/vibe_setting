---
문서명: Content — Software Design Document
문서 ID: SDD-CONTENT-001
버전: v2.0
적용 표준: IEEE 1016-2009
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: HongCafe Global Backend — Content Module
관련 문서:
  - content-srs.md (SRS-CONTENT-001)
  - content-idd.md (IDD-CONTENT-001)
  - docs/api-specification.md
---

# Content Module — Software Design Document (SDD)

> IEEE 1016-2009 준수 | version: 2.0 | lastUpdated: 2026-04-15 | module: Content

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 HongCafe Global Backend Content 모듈의 소프트웨어 설계를 IEEE 1016-2009 표준에 따라 기술한다. Content 모듈은 공지사항·FAQ·배너·테마 콘텐츠의 RESTful CRUD와 테마별 상담사 목록 조회를 담당하며, 총 16개 엔드포인트를 제공한다.

This document describes the software design for the Content module per IEEE 1016-2009. It covers architectural, component, interface, and data design decisions traceable to SRS-CONTENT-001.

### 1.2 Scope (범위)

본 문서가 다루는 설계 대상:
- Controller Layer: BannerController, FaqController, NoticeController, ThemeController
- Service Layer: BannerService, FaqService, NoticeService, ThemeService
- Repository Layer: BannerRepository, FaqRepository, NoticeRepository, ThemeRepository
- Configuration: Routes.php, Services.php (DI 바인딩)
- DB Schema: tb_banner, tb_faq (DDL 포함)

### 1.3 References (참조 문서)

| 문서 | 위치 |
|------|------|
| IEEE 1016-2009 — Software Design Descriptions | 표준 |
| SRS-CONTENT-001 (content-srs.md v2.0) | `docs/specs/` |
| IDD-CONTENT-001 (content-idd.md v2.0) | `docs/specs/` |
| OWASP Top 10 A03:2021 — Injection | https://owasp.org/Top10/A03_2021-Injection/ |
| CI4 4.7 ResourceController | https://codeigniter.com/user_guide/incoming/restful.html |

---

## 2. Stakeholders and Concerns (이해관계자 및 관심사)

| 이해관계자 | 설계 관심사 |
|----------|-----------|
| 개발팀 | ResourceController 패턴 준수, DI 바인딩, camelCase 변환 위치 |
| 운영팀 | 배너 시간 활성화 정확성, 인덱스 설계, 쿼리 성능 |
| 보안팀 | SQL Injection 방지 (ThemeRepository), CSRF 검증 체인 |
| QA팀 | 단위 테스트 가능 구조 (Service/Repository 분리) |
| 아키텍처팀 | 모듈 간 Interface Only 원칙, 중앙 Services.php 바인딩 금지 |

---

## 3. Design Viewpoints (설계 관점)

### VP-1: Context Viewpoint (컨텍스트 관점)

Content 모듈은 HongCafe Global Backend Modular Monolith의 독립 Bounded Context이다.

```
외부 클라이언트 (Next.js 16)
        │ HTTPS REST
        ▼
[Content Module]
  BannerController / FaqController / NoticeController / ThemeController
        │
        ▼
  BannerService / FaqService / NoticeService
        │
        ▼
  BannerRepository / FaqRepository / NoticeRepository / ThemeRepository
        │                                                    │
        ▼                                                    ▼
  Aurora MySQL (tb_banner, tb_faq, tb_notice)      Hermes DB (온콜 상태)
```

### VP-2: Composition Viewpoint (구성 관점)

```
app/Modules/Content/
├── Controllers/
│   ├── BannerController.php         ResourceController 상속
│   ├── FaqController.php            ResourceController 상속
│   ├── NoticeController.php         ResourceController 상속
│   └── ThemeController.php          커스텀 Controller (POST)
├── Services/
│   ├── BannerService.php            배너 CRUD + 시간 필터
│   ├── FaqService.php               FAQ CRUD
│   └── NoticeService.php            공지 CRUD
├── Repositories/
│   ├── BannerRepository.php         시간 기반 활성 배너 조회
│   ├── FaqRepository.php            상태/메뉴코드 필터
│   ├── NoticeRepository.php         날짜 역순 조회
│   └── ThemeRepository.php          온콜/가격 복합 조인 필터
├── Interfaces/                       7개 (Service 3 + Repository 4)
└── Config/
    ├── Routes.php                    resource() 3개 + POST 1개
    └── Services.php                  7개 DI 바인딩
```

### VP-3: Dependency Viewpoint (의존성 관점)

```
BannerController
  └─> BannerServiceInterface (DI — Modules/Content/Config/Services.php)
        └─> BannerRepositoryInterface (DI)
              └─> Aurora MySQL (tb_banner)

FaqController / NoticeController — 동일 패턴

ThemeController
  └─> ThemeRepositoryInterface (DI)
        └─> Aurora MySQL (JOIN Hermes DB)
```

**원칙**: 모듈 간 통신은 Interface Only. `app/Config/Services.php` 중앙 등록 금지.

### VP-4: Interface Viewpoint (인터페이스 관점)

인터페이스 상세는 IDD-CONTENT-001(content-idd.md) 참조.

| 인터페이스 | 타입 | 목적 |
|---------|------|------|
| `BannerServiceInterface` | 내부 | Controller → Service DI |
| `FaqServiceInterface` | 내부 | Controller → Service DI |
| `NoticeServiceInterface` | 내부 | Controller → Service DI |
| `BannerRepositoryInterface` | 내부 | Service → Repository DI |
| `FaqRepositoryInterface` | 내부 | Service → Repository DI |
| `NoticeRepositoryInterface` | 내부 | Service → Repository DI |
| `ThemeRepositoryInterface` | 내부 | Controller → Repository DI |
| HTTP REST API | 외부 | 클라이언트 ↔ Controller |

### VP-5: Interaction Viewpoint (상호작용 관점)

#### 배너 시간 기반 쿼리 흐름

```
클라이언트
  │-- GET /api/banners?bn_position=main&page=1 -->
  │
  BannerController
    │-- getList(page, perPage, position) -->
    │
    BannerService
      │-- getActiveBannerList(page, perPage, position) -->
      │
      BannerRepository
        │-- SELECT * FROM tb_banner
        │   WHERE bn_position = escape(pos)
        │     AND bn_view = 'Y'
        │     AND starttime <= NOW()
        │     AND endtime >= NOW()
        │   ORDER BY bn_sort ASC
        │   LIMIT ? OFFSET ? -->
        │
        Aurora MySQL
          │<-- 결과셋 (활성 배너만) ---
        │
      BannerRepository <-- array items, total
    BannerService <-- {items, total}
  BannerController <-- {items, meta}
클라이언트 <-- 200 {data:[...], meta:{currentPage, perPage, total, lastPage}}
```

### VP-6: State Viewpoint (상태 관점)

#### 배너 상태 전이

```
[등록] → bn_view='Y', starttime 미도래 → [대기]
[대기] → starttime 도달 → [활성] (NOW() 기준 자동)
[활성] → endtime 도달 → [만료] (NOW() 기준 자동)
[활성/대기/만료] → bn_view='N' 설정 → [비활성]
[비활성] → bn_view='Y' 재설정 → [활성 또는 대기]
```

상태 전이는 DB 쿼리 시점 자동 결정 — 별도 상태 컬럼 없음.

### VP-7: Algorithm Viewpoint (알고리즘 관점)

#### ThemeRepository 온콜 필터 알고리즘

```
입력: limit, offset, onFlag, price_min, price_max
1. 기본 SQL 조인 구성 (tb_theme JOIN Hermes 온콜 테이블)
2. onFlag 존재 시: WHERE 절에 온콜 상태 조건 추가 (escape 처리)
3. price_min 존재 시: AND price >= escape(price_min)
4. price_max 존재 시: AND price <= escape(price_max)
5. $db->query($sql, $params) 실행
6. 결과 배열에서 랜덤 태그 선택 (array_rand)
7. 숫자 포맷팅 (number_format)
출력: {data: [...], meta: {total, limit, offset}}
```

### VP-8: Resource Viewpoint (리소스 관점)

| 리소스 | 설명 |
|--------|------|
| DB 연결 | RDS Proxy IAM Auth (Connection Pool) |
| 인덱스 | idx_position_view (tb_banner), idx_status_menu (tb_faq) |
| 외부 DB | Hermes DB — ThemeRepository 단일 의존 지점 |
| 메모리 | 배너/FAQ 목록 응답 — CI4 Pager 메모리 최적화 |

---

## 4. Design Overlay (설계 결정 — ADR)

### ADR-CONTENT-001: CI4 ResourceController 상속

**결정**: BannerController, FaqController, NoticeController는 CI4 `ResourceController`를 상속한다.  
**근거**: CI4 공식 문서 — `$routes->resource()` 한 줄로 5~7개 라우트 자동 생성. HTTP 메서드와 Controller 메서드 자동 매핑. 보일러플레이트 제거. `only`/`except` 옵션으로 불필요 라우트 제한 가능.  
**대안**: 수동 라우트 등록 — 라우트 등록 오류 위험, 개발 생산성 저하.  
**결과**: 수동 라우트 금지. ResourceController 상속 강제.

### ADR-CONTENT-002: 시간 기반 배너 활성화 — DB 쿼리 시점 필터

**결정**: 배너 노출 여부는 DB 쿼리 실행 시 `starttime ≤ NOW() AND endtime ≥ NOW()` 조건으로 실시간 결정한다.  
**근거**: MySQL `NOW()` 함수는 쿼리 실행 시각 기준. `idx_position_view` 복합 인덱스로 Range Scan 최적화. 크론잡 방식 대비 실시간 정확성 보장, 운영 복잡도 절감.  
**대안**: 크론잡으로 `bn_view` 주기적 업데이트 — 크론 주기(1분) 오차, 추가 운영 작업 필요.  
**결과**: `BannerRepository::getActiveBannerList()` 쿼리에 NOW() 조건 고정. 인덱스 필수 유지.

### ADR-CONTENT-003: ThemeRepository raw SQL + `$db->escape()`

**결정**: ThemeRepository는 `$db->query()` + `$db->escape()`를 사용한다.  
**근거**: 온콜 상태 Hermes DB 서브쿼리 JOIN + 가격 범위 필터 조합은 CI4 Query Builder 단독 표현 불가. OWASP A03:2021 Injection 가이드 — 동적 쿼리는 파라미터 바인딩 또는 이스케이프 필수.  
**대안**: Query Builder 전환 — 서브쿼리 + JOIN 복합 구조 표현 한계.  
**결과**: raw SQL 허용. 모든 동적 값 `$db->escape()` 필수. OWASP A03 준수.

---

## 5. Traceability Matrix (추적성 매트릭스)

| SRS 요구사항 | 설계 컴포넌트 | 파일 경로 |
|------------|------------|---------|
| FR-CONTENT-001 (공지사항 CRUD) | NoticeController, NoticeService, NoticeRepository | `Controllers/NoticeController.php`, `Services/NoticeService.php`, `Repositories/NoticeRepository.php` |
| FR-CONTENT-002 (FAQ CRUD) | FaqController, FaqService, FaqRepository | `Controllers/FaqController.php`, `Services/FaqService.php`, `Repositories/FaqRepository.php` |
| FR-CONTENT-003 (배너 CRUD + 시간 활성화) | BannerController, BannerService, BannerRepository | `Controllers/BannerController.php`, `Services/BannerService.php`, `Repositories/BannerRepository.php` |
| FR-CONTENT-004 (테마 목록) | ThemeController, ThemeRepository | `Controllers/ThemeController.php`, `Repositories/ThemeRepository.php` |
| NFR-CONTENT-001 (ResourceController 패턴) | BannerController, FaqController, NoticeController | Routes.php — `$routes->resource()` |
| NFR-CONTENT-002 (응답 200ms) | BannerRepository, FaqRepository | idx_position_view, idx_status_menu 인덱스 |
| NFR-CONTENT-003 (배너 시간 활성화 정확도) | BannerRepository | ADR-CONTENT-002 |
| NFR-CONTENT-004 (입력값 검증) | 모든 Controller | CI4 Validation Rules |
| NFR-CONTENT-005 (SQL Injection 방지) | ThemeRepository | ADR-CONTENT-003 |
| NFR-CONTENT-006 (페이지네이션 meta) | 모든 Service (getList) | CI4 `Model::paginate()` + `pager` |

---

## 6. Component Design (컴포넌트 설계)

### 6.1 Controller Layer

| 클래스 | 패턴 | EP 수 | 핵심 책임 |
|--------|------|------|---------|
| `BannerController` | ResourceController | 5 | 입력 검증 → BannerService 위임 → camelCase 응답 |
| `FaqController` | ResourceController | 5 | 입력 검증 → FaqService 위임 → camelCase 응답 |
| `NoticeController` | ResourceController | 5 | 입력 검증 → NoticeService 위임 → camelCase 응답 |
| `ThemeController` | Custom | 1 | 입력 검증 → ThemeRepository 위임 → 응답 |

**설계 원칙**:
- Controller는 입력 검증과 응답 포맷팅만 담당. 비즈니스 로직 금지.
- `checkNeedLogin(true)` — JWT 이중 검증 (write EP)
- 응답: DB snake_case → camelCase 변환 (Service 레이어 또는 Entity)

### 6.2 Service Layer (공통 CRUD 패턴)

| 메서드 | 입력 | 출력 | 설명 |
|--------|------|------|------|
| `getList(page, perPage, filter)` | int, int, array | `{items, total, page, perPage}` | offset 계산 → Repository 조회 + count |
| `getById(id)` | int | array | 없으면 `NotFoundException` throw |
| `create(data)` | array | array | insert → find → return (camelCase) |
| `update(id, data)` | int, array | array | 존재 체크 → 허용 필드 필터 → update |
| `delete(id)` | int | void | 존재 체크 → delete |

### 6.3 Repository Layer

| 클래스 | 특이사항 |
|--------|---------|
| `BannerRepository` | `getActiveBannerList()`: bn_view='Y' + starttime ≤ NOW() ≤ endtime + bn_position 필터, bn_sort ASC. Query Builder 사용 |
| `FaqRepository` | `getActiveFaqList()`: faq_status='y' + faq_menu_code 필터, faq_order ASC. Query Builder 사용 |
| `NoticeRepository` | `getListPaginated()`: regist_date DESC. CI4 `paginate()` 사용 |
| `ThemeRepository` | 복합 조인: 온콜 상태 서브쿼리, onFlag/가격 범위 필터. `$db->query()` + `$db->escape()` |

---

## 7. SQL DDL (데이터 스키마)

### tb_banner

```sql
CREATE TABLE tb_banner (
    bn_no       INT UNSIGNED   AUTO_INCREMENT PRIMARY KEY,
    bn_img      VARCHAR(500)   NOT NULL,
    bn_link     VARCHAR(500)   DEFAULT NULL,
    bn_name     VARCHAR(200)   DEFAULT NULL,
    bn_position VARCHAR(50)    NOT NULL,
    bn_sort     INT            DEFAULT 0,
    bn_view     ENUM('Y','N')  DEFAULT 'Y',
    starttime   DATETIME       NOT NULL,
    endtime     DATETIME       NOT NULL,
    regist_date DATETIME       DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_position_view (bn_position, bn_view, starttime, endtime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### tb_faq

```sql
CREATE TABLE tb_faq (
    faq_no       INT UNSIGNED   AUTO_INCREMENT PRIMARY KEY,
    faq_question VARCHAR(500)   NOT NULL,
    faq_answer   TEXT           NOT NULL,
    faq_menu_code VARCHAR(50)   DEFAULT NULL,
    faq_status   ENUM('y','n') DEFAULT 'n',
    faq_type     VARCHAR(20)    DEFAULT 'all',
    faq_order    INT            DEFAULT 0,
    regist_date  DATETIME       DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_status_menu (faq_status, faq_menu_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

> **비고**: tb_notice DDL은 `database/schema/` 경로의 스키마 파일을 참조한다.

---

## 8. Entity / VO Design Direction (Entity 설계 방향)

Content 모듈은 현재 CI4 ResourceController 기반으로 raw array를 반환한다. Entity 전환 시 다음 방향을 따른다.

| 항목 | 내용 |
|------|------|
| 전환 대상 | BannerRepository, FaqRepository, NoticeRepository |
| 전환 방식 | CI4 `Entity` 클래스 상속. `$casts` 속성으로 타입 캐스팅 정의 |
| camelCase 변환 | Entity `jsonSerialize()` 또는 Service 레이어에서 일괄 수행 |
| 우선순위 | 마이그레이션 완료 후 단계적 전환 — 현재 단계 raw array 유지 |

---

## 9. Feasibility Review (타당성 검토)

| 항목 | 근거 | 결론 |
|------|------|------|
| CI4 ResourceController 설계 | CI4 4.7 공식 문서 — `ResourceController` 상속 시 HTTP 메서드(GET/POST/PUT/DELETE)와 Controller 메서드(index/show/create/update/delete)가 자동 매핑. `$routes->resource('banners')` 한 줄로 5개 라우트 생성. 개별 라우트 등록 오류 원천 제거. `only`/`except` 옵션으로 불필요 라우트 제한 가능 | 채택. 구조적 일관성과 개발 생산성 모두 확보 |
| 시간 기반 배너 DB 쿼리 시점 필터 | `INDEX idx_position_view(bn_position, bn_view, starttime, endtime)` 복합 인덱스로 Range Scan 최적화. MySQL `NOW()` 함수는 쿼리 실행 시각 기준 — 정확한 실시간 제어. Aurora MySQL 3.x에서 `BETWEEN starttime AND endtime` 조건과 복합 인덱스 결합은 검증된 패턴 | 채택. 크론잡 방식 대비 운영 복잡도 절감, 실시간 정확성 보장 |
| ThemeRepository `$db->escape()` | OWASP A03:2021 — 동적 쿼리는 파라미터 바인딩 또는 이스케이프 필수. CI4 `$db->escape()`는 MySQL `mysql_real_escape_string`에 준하는 이스케이프 수행. ThemeRepository는 JOIN + 가격 범위 + 서브쿼리 조합 — raw SQL + `$db->escape()` 조합이 현실적 최선 | 채택. OWASP A03 준수. 향후 Query Builder 전환 범위 단계적 리팩터링 검토 |

---

## 10. Change Impact Log (변경 영향 기록)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| IEEE 1016-2009 표준 전면 전환 (v1.2 → v2.0) | VP-1~VP-8 8개 관점 구조 도입. Context/Composition/Dependency/Interface/Interaction/State/Algorithm/Resource 관점 명시. 국제 표준 준수로 문서 심사 통과 | 프로젝트 지침 — IEEE 표준 전환 요구, 3-Round Review PASS |
| 추적성 매트릭스(섹션 5) 신설 | SRS FR/NFR ↔ 설계 컴포넌트 ↔ 파일 경로 일괄 추적. 요구사항 누락 방지 | IEEE 1016-2009 — 설계 요소와 요구사항 간 추적성 의무 |
| Design Overlay (ADR) 섹션 강화 | ADR-CONTENT-001~003 근거 공식 문서/OWASP 기준 보강 | 근거 없는 설계 결정은 지침 위반 — 타당성 검토 의무 |
| 이해관계자 및 관심사(섹션 2) 신설 | 개발/운영/보안/QA/아키텍처 5개 그룹 관심사 명시 | IEEE 1016-2009 §5.3 — 이해관계자 및 관심사 정의 의무 |
| 배너 상태 전이 다이어그램(VP-6) 추가 | 배너 상태(대기/활성/만료/비활성) 전이 조건 시각화 — 구현 오해 방지 | 기존 문서에 배너 상태 전이 명시 없어 구현자 판단에 의존 |

---

## 11. Review Checklist (검토 체크리스트)

### 완전성 (Completeness)
- [x] IEEE 1016-2009 — VP-1~VP-8 8개 설계 관점 완료
- [x] 이해관계자 및 관심사 정의 (5개 그룹)
- [x] Context/Composition/Dependency/Interface Viewpoint 완료
- [x] Interaction/State/Algorithm/Resource Viewpoint 완료
- [x] ADR 3건 (근거 포함)
- [x] 추적성 매트릭스 (SRS FR/NFR → 설계 컴포넌트)
- [x] SQL DDL (tb_banner, tb_faq)
- [x] Entity/VO 설계 방향
- [x] 타당성 검토 3건
- [x] 변경 영향 기록 5건

### 일관성 (Consistency)
- [x] SRS-CONTENT-001 FR/NFR 모두 추적 대상 포함
- [x] Interface Only 원칙 준수 확인
- [x] DI 모듈별 분산 (중앙 등록 금지) 확인

### 검증 가능성 (Verifiability)
- [x] ADR별 검증 가능한 근거 명시
- [x] 시퀀스 다이어그램 구현 가이드 포함

### 추적성 (Traceability)
- [x] SRS → SDD 추적성 매트릭스 완료
- [x] SDD → IDD 인터페이스 참조 완료

---

## 12. Change Log (변경 로그)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-15 | 1.0.0 | 초기 작성 |
| 2026-04-15 | 1.2.0 | 타당성 검토(3건), 변경 영향 기록(4건), SQL DDL(tb_banner/tb_faq), Entity/VO 섹션, 배너 시퀀스 다이어그램 추가 |
| 2026-04-15 | 2.0.0 | IEEE 표준 전면 전환. 3-Round Review PASS. VP-1~VP-8 8개 설계 관점, 이해관계자 섹션, 추적성 매트릭스, 배너 상태 전이 다이어그램, Design Overlay ADR 강화 |
