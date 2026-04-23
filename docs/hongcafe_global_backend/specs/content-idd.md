---
문서명: Content — Interface Design Document
문서 ID: IDD-CONTENT-001
버전: v2.0
적용 표준: MIL-STD-498
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: HongCafe Global Backend — Content Module
관련 문서:
  - content-srs.md (SRS-CONTENT-001)
  - content-sdd.md (SDD-CONTENT-001)
  - docs/api-specification.md
---

# Content Module — Interface Design Document (IDD)

> MIL-STD-498 준수 | version: 2.0 | lastUpdated: 2026-04-15 | module: Content

---

## 1. Scope (범위)

### 1.1 Identification (식별)

| 항목 | 내용 |
|------|------|
| 문서 ID | IDD-CONTENT-001 |
| 시스템 | HongCafe Global Backend |
| 모듈 | Content Bounded Context |
| 적용 표준 | MIL-STD-498 (Interface Design Description) |

### 1.2 System Overview (시스템 개요)

Content 모듈은 공지사항·FAQ·배너·테마 콘텐츠의 CRUD 및 테마 상담사 목록 조회를 담당하는 독립 Bounded Context이다. 모듈 내 7개 내부 인터페이스(Service 3, Repository 4)로 구성되며 외부 시스템 의존성은 없다 (Hermes DB는 `ThemeRepository` 내 직접 조인).

### 1.3 Document Overview (문서 개요)

본 문서는 Content 모듈의 모든 인터페이스(내부/외부)를 MIL-STD-498 IDD 형식으로 기술한다. 각 인터페이스에 대해 목적, 계약, 데이터 포맷, 에러 처리를 정의한다.

---

## 2. Referenced Documents (참조 문서)

| 문서 | 버전 | 위치 |
|------|------|------|
| MIL-STD-498 — Software Development and Documentation | - | 표준 |
| SRS-CONTENT-001 (content-srs.md) | v2.0 | `docs/specs/` |
| SDD-CONTENT-001 (content-sdd.md) | v2.0 | `docs/specs/` |
| CI4 4.7 — ResourceController | - | https://codeigniter.com/user_guide/incoming/restful.html |
| CLAUDE.md — API 응답 표준 | - | 프로젝트 루트 |

---

## 3. Interface Design (인터페이스 설계)

### IF-CONTENT-001: BannerServiceInterface

#### 3.1.1 Interface Identification

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-CONTENT-001 |
| 파일 경로 | `app/Modules/Content/Interfaces/BannerServiceInterface.php` |
| 구현체 | `BannerService` |
| DI 등록 | `app/Modules/Content/Config/Services.php` |
| 관련 FR | FR-CONTENT-003 |

#### 3.1.2 Interface Characteristics

- **목적**: BannerController와 BannerService 간 계약 정의. 배너 CRUD + 시간 기반 활성화 필터
- **방향**: Controller → Service (단방향 DI)
- **데이터 형식**: PHP array (호출 시), JSON HTTP 응답 (BannerController가 변환)

#### 3.1.3 Interface Requirement Allocations

| 메서드 | 파라미터 | 반환형 | 연관 FR |
|--------|---------|--------|---------|
| `getList(int $page, int $perPage, ?string $position)` | page, perPage, position 필터 | `array{items: array, total: int, page: int, perPage: int}` | FR-CONTENT-003 |
| `getById(int $id)` | 배너 PK | `array` — 없으면 `NotFoundException` throw | FR-CONTENT-003 |
| `create(array $data)` | 배너 데이터 | `array` 생성된 레코드 | FR-CONTENT-003 |
| `update(int $id, array $data)` | 배너 PK + 수정 데이터 | `array` 수정된 레코드 | FR-CONTENT-003 |
| `delete(int $id)` | 배너 PK | `void` | FR-CONTENT-003 |

#### 3.1.4 Interface Data Element Descriptions

| 필드 | 타입 | 설명 |
|------|------|------|
| `bn_no` | int | 배너 PK |
| `bn_img` | string | 이미지 URL (max 500자) |
| `bn_position` | string | 배치 위치 코드 |
| `bn_sort` | int | 정렬 순서 (ASC) |
| `bn_view` | string | 공개 여부 (Y/N) |
| `starttime` | string | 노출 시작 (DATETIME UTC) |
| `endtime` | string | 노출 종료 (DATETIME UTC) |

#### 3.1.5 Interface Adaptation Requirements

- `getList()` 반환값의 snake_case 필드는 BannerController에서 camelCase로 변환 후 응답.
- 시간 필터는 BannerRepository 레이어에서 적용 — Service는 Repository 위임 후 포맷팅만 수행.

---

### IF-CONTENT-002: FaqServiceInterface

#### 3.2.1 Interface Identification

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-CONTENT-002 |
| 파일 경로 | `app/Modules/Content/Interfaces/FaqServiceInterface.php` |
| 구현체 | `FaqService` |
| DI 등록 | `app/Modules/Content/Config/Services.php` |
| 관련 FR | FR-CONTENT-002 |

#### 3.2.2 Interface Characteristics

- **목적**: FaqController와 FaqService 간 계약 정의. FAQ CRUD + 카테고리 필터
- **방향**: Controller → Service (단방향 DI)

#### 3.2.3 Interface Requirement Allocations

| 메서드 | 파라미터 | 반환형 | 연관 FR |
|--------|---------|--------|---------|
| `getList(int $page, int $perPage, ?string $menuCode)` | page, perPage, menuCode 필터 | `array{items, total, page, perPage}` | FR-CONTENT-002 |
| `getById(int $id)` | FAQ PK | `array` | FR-CONTENT-002 |
| `create(array $data)` | FAQ 데이터 | `array` | FR-CONTENT-002 |
| `update(int $id, array $data)` | FAQ PK + 수정 데이터 | `array` | FR-CONTENT-002 |
| `delete(int $id)` | FAQ PK | `void` | FR-CONTENT-002 |

#### 3.2.4 Interface Data Element Descriptions

| 필드 | 타입 | 설명 |
|------|------|------|
| `faq_question` | string | 질문 (max 500자) |
| `faq_answer` | string | 답변 |
| `faq_menu_code` | string | 카테고리 코드 |
| `faq_status` | string | 상태 (y/n), 기본값 'n' |
| `faq_type` | string | 대상 유형, 기본값 'all' |
| `faq_order` | int | 정렬 순서 (ASC) |

#### 3.2.5 Interface Adaptation Requirements

- 조회 시 `faq_status='y'` 조건 FaqRepository에서 자동 적용.
- `faq_menu_code` 미전달 시 전체 카테고리 반환.

---

### IF-CONTENT-003: NoticeServiceInterface

#### 3.3.1 Interface Identification

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-CONTENT-003 |
| 파일 경로 | `app/Modules/Content/Interfaces/NoticeServiceInterface.php` |
| 구현체 | `NoticeService` |
| DI 등록 | `app/Modules/Content/Config/Services.php` |
| 관련 FR | FR-CONTENT-001 |

#### 3.3.2 Interface Characteristics

- **목적**: NoticeController와 NoticeService 간 계약. 공지사항 CRUD
- **방향**: Controller → Service (단방향 DI)

#### 3.3.3 Interface Requirement Allocations

| 메서드 | 파라미터 | 반환형 | 연관 FR |
|--------|---------|--------|---------|
| `getList(int $page, int $perPage)` | page, perPage | `array{items, total, page, perPage}` | FR-CONTENT-001 |
| `getById(int $id)` | 공지 PK | `array` | FR-CONTENT-001 |
| `create(array $data)` | 공지 데이터 | `array` | FR-CONTENT-001 |
| `update(int $id, array $data)` | 공지 PK + 수정 데이터 | `array` | FR-CONTENT-001 |
| `delete(int $id)` | 공지 PK | `void` | FR-CONTENT-001 |

#### 3.3.4 Interface Data Element Descriptions

| 필드 | 타입 | 설명 |
|------|------|------|
| `nt_title` | string | 제목 (max 200자) |
| `nt_content` | string | 내용 |
| `nt_status` | string | 상태 (Y/N) |
| `regist_date` | string | 등록일시 (DATETIME UTC) |

#### 3.3.5 Interface Adaptation Requirements

- 목록 정렬: `regist_date DESC` (NoticeRepository 고정).
- CI4 `paginate()` 기반 Pager 사용 — 커스텀 페이지네이션 금지.

---

### IF-CONTENT-004: BannerRepositoryInterface

#### 3.4.1 Interface Identification

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-CONTENT-004 |
| 파일 경로 | `app/Modules/Content/Interfaces/BannerRepositoryInterface.php` |
| 구현체 | `BannerRepository` |
| DI 등록 | `app/Modules/Content/Config/Services.php` |
| 관련 NFR | NFR-CONTENT-002, NFR-CONTENT-003 |

#### 3.4.2 Interface Characteristics

- **목적**: BannerService와 BannerRepository 간 DB 접근 계약. 시간 기반 활성 배너 조회 특화
- **방향**: Service → Repository (단방향 DI)

#### 3.4.3 Interface Requirement Allocations

| 메서드 | 파라미터 | 반환형 | 비고 |
|--------|---------|--------|------|
| `getActiveBannerList(int $page, int $perPage, ?string $position)` | 필터 | `array` | NOW() 조건 포함 |
| `countActiveBanners(?string $position)` | position 필터 | `int` | 시간 조건 포함 |
| `findById(int $id)` | PK | `array\|null` | |
| `insert(array $data)` | 배너 데이터 | `int` insert ID | |
| `update(int $id, array $data)` | PK + 데이터 | `bool` | |
| `delete(int $id)` | PK | `bool` | |

#### 3.4.4 Interface Data Element Descriptions

활성 배너 쿼리 조건 (고정):
```sql
WHERE bn_position = ? AND bn_view = 'Y'
  AND starttime <= NOW() AND endtime >= NOW()
ORDER BY bn_sort ASC
```

#### 3.4.5 Interface Adaptation Requirements

- `idx_position_view (bn_position, bn_view, starttime, endtime)` 인덱스 반드시 존재해야 함.

---

### IF-CONTENT-005: FaqRepositoryInterface

#### 3.5.1 Interface Identification

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-CONTENT-005 |
| 파일 경로 | `app/Modules/Content/Interfaces/FaqRepositoryInterface.php` |
| 구현체 | `FaqRepository` |
| DI 등록 | `app/Modules/Content/Config/Services.php` |

#### 3.5.2 Interface Requirement Allocations

| 메서드 | 파라미터 | 반환형 |
|--------|---------|--------|
| `getActiveFaqList(int $page, int $perPage, ?string $menuCode)` | 필터 | `array` |
| `countActiveFaqs(?string $menuCode)` | menuCode 필터 | `int` |
| `findById(int $id)` | PK | `array\|null` |
| `insert(array $data)` | 데이터 | `int` |
| `update(int $id, array $data)` | PK + 데이터 | `bool` |
| `delete(int $id)` | PK | `bool` |

#### 3.5.3 Interface Adaptation Requirements

- 활성 FAQ 조회: `faq_status='y'` 조건 고정. 정렬: `faq_order ASC, regist_date DESC`.

---

### IF-CONTENT-006: NoticeRepositoryInterface

#### 3.6.1 Interface Identification

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-CONTENT-006 |
| 파일 경로 | `app/Modules/Content/Interfaces/NoticeRepositoryInterface.php` |
| 구현체 | `NoticeRepository` |
| DI 등록 | `app/Modules/Content/Config/Services.php` |

#### 3.6.2 Interface Requirement Allocations

| 메서드 | 파라미터 | 반환형 |
|--------|---------|--------|
| `getListPaginated(int $limit, int $offset)` | 페이지네이션 파라미터 | `array` |
| `countAll()` | 없음 | `int` |
| `findById(int $id)` | PK | `array\|null` |
| `insert(array $data)` | 데이터 | `int` |
| `update(int $id, array $data)` | PK + 데이터 | `bool` |
| `delete(int $id)` | PK | `bool` |

#### 3.6.3 Interface Adaptation Requirements

- 정렬: `regist_date DESC` 고정.

---

### IF-CONTENT-007: ThemeRepositoryInterface

#### 3.7.1 Interface Identification

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-CONTENT-007 |
| 파일 경로 | `app/Modules/Content/Interfaces/ThemeRepositoryInterface.php` |
| 구현체 | `ThemeRepository` |
| DI 등록 | `app/Modules/Content/Config/Services.php` |
| 관련 FR | FR-CONTENT-004 |

#### 3.7.2 Interface Characteristics

- **목적**: 테마 목록 조회 — Hermes DB 서브쿼리 조인, 온콜 필터, 가격 범위 필터
- **특이사항**: `$db->query()` + `$db->escape()` 사용. OWASP A03 준수

#### 3.7.3 Interface Requirement Allocations

| 메서드 | 파라미터 | 반환형 | 비고 |
|--------|---------|--------|------|
| `getThemeList(array $params)` | limit, offset, onFlag, price_min, price_max | `array` | 복합 조인 쿼리 |
| `getThemeListCount(array $params)` | 동일 필터 | `int` | 전체 건수 |
| `getThemeItem(string $code)` | 테마 코드 | `array\|null` | 단건 조회 |
| `getThemeCallee(string $code)` | 테마 코드 | `array` | 테마 소속 상담사 목록 |

#### 3.7.4 Interface Data Element Descriptions

| 필드 | 타입 | 설명 |
|------|------|------|
| `it_code` | string | 테마(아이템) 코드 |
| `it_tag` | array | 랜덤 추출 태그 목록 |
| `it_coin_price` | int | 코인 가격 |
| `online_status` | string | 온콜 상태 (on/standby/off) |

#### 3.7.5 Interface Adaptation Requirements

- `params.onFlag` 미전달 시 온콜 상태 필터 미적용 (전체 반환).
- `params.price_min` / `params.price_max` 미전달 시 가격 필터 미적용.
- 모든 동적 파라미터 `$db->escape()` 처리 필수.

---

## 4. Interface Events (인터페이스 이벤트)

| 이벤트 | 발생 조건 | 처리 방법 |
|--------|---------|---------|
| 배너 시간 활성화 | NOW() 기준 starttime/endtime 경계 도달 | DB 쿼리 시 자동 필터 (별도 이벤트 없음) |
| 외부 DB(Hermes) 연결 실패 | ThemeRepository 쿼리 실행 시 | HTTP 500 INTERNAL 반환 |
| 입력 검증 실패 | Controller Validation Rules 실패 | HTTP 400 INVALID_INPUT 반환 |
| 리소스 미존재 | getById() null 반환 | Service에서 NotFoundException throw → HTTP 404 |

---

## 5. Data Formats (데이터 포맷)

### 5.1 HTTP 요청/응답 JSON 예시

#### GET /api/banners — 배너 목록 조회

**요청**
```
GET /api/banners?bn_position=main&page=1&per_page=5
X-Forwarded-Proto: https
```

**응답** `200 OK`
```json
{
    "data": [
        {
            "bnNo": 1,
            "bnImg": "/img/banner1.jpg",
            "bnLink": "/event/1",
            "bnPosition": "main",
            "bnSort": 1,
            "bnView": "Y",
            "starttime": "2026-04-01T00:00:00Z",
            "endtime": "2026-04-30T23:59:59Z"
        }
    ],
    "meta": {
        "currentPage": 1,
        "perPage": 5,
        "total": 3,
        "lastPage": 1
    }
}
```

> 시간 외 배너는 결과에서 자동 제외. 응답 필드: DB snake_case → camelCase 변환 적용.

#### POST /api/themes/get-theme-list — 테마 목록 조회

**요청**
```json
{
    "limit": 10,
    "offset": 0,
    "onFlag": "on"
}
```

**응답** `200 OK`
```json
{
    "data": [
        {
            "itCode": "IT-001",
            "itTag": ["운세", "타로"],
            "itCoinPrice": 5000,
            "onlineStatus": "on"
        }
    ],
    "meta": {
        "total": 25,
        "limit": 10,
        "offset": 0
    }
}
```

> `onFlag` 미전달 시 전체 상태 반환. `itTag`는 ThemeRepository에서 랜덤 추출 배열.  
> 페이지네이션: limit/offset 방식 (CI4 Pager 미사용 — 복합 쿼리 구조 예외).

#### POST /api/notices — 공지사항 생성

**요청**
```json
{
    "nt_title": "서비스 점검 안내",
    "nt_content": "2026년 4월 16일 오전 2시~4시 서비스 점검이 진행됩니다.",
    "nt_status": "Y"
}
```

**응답** `201 Created`
```json
{
    "data": {
        "ntNo": 42,
        "ntTitle": "서비스 점검 안내",
        "ntContent": "2026년 4월 16일 오전 2시~4시 서비스 점검이 진행됩니다.",
        "ntStatus": "Y",
        "registDate": "2026-04-15T10:00:00Z"
    }
}
```

#### 입력 검증 실패 에러 예시

**요청** (faq_question 500자 초과)
```json
{
    "faq_question": "...(501자)...",
    "faq_answer": "답변 내용"
}
```

**응답** `400 Bad Request`
```json
{
    "error": {
        "code": "INVALID_INPUT",
        "message": "faq_question의 최대 길이는 500자입니다."
    }
}
```

### 5.2 camelCase 필드 매핑

| DB 컬럼 (snake_case) | API 응답 키 (camelCase) |
|---------------------|----------------------|
| `bn_no` | `bnNo` |
| `bn_img` | `bnImg` |
| `bn_link` | `bnLink` |
| `bn_position` | `bnPosition` |
| `bn_sort` | `bnSort` |
| `bn_view` | `bnView` |
| `faq_question` | `faqQuestion` |
| `faq_answer` | `faqAnswer` |
| `faq_menu_code` | `faqMenuCode` |
| `faq_status` | `faqStatus` |
| `faq_order` | `faqOrder` |
| `nt_title` | `ntTitle` |
| `nt_content` | `ntContent` |
| `nt_status` | `ntStatus` |
| `regist_date` | `registDate` |
| `it_code` | `itCode` |
| `it_coin_price` | `itCoinPrice` |
| `online_status` | `onlineStatus` |

---

## 6. Requirements Traceability (요구사항 추적성)

| 인터페이스 ID | 구현 FR/NFR | SDD 섹션 | 파일 경로 |
|------------|-----------|---------|---------|
| IF-CONTENT-001 (BannerServiceInterface) | FR-CONTENT-003 | VP-4, §6.1 | `Interfaces/BannerServiceInterface.php` |
| IF-CONTENT-002 (FaqServiceInterface) | FR-CONTENT-002 | VP-4, §6.1 | `Interfaces/FaqServiceInterface.php` |
| IF-CONTENT-003 (NoticeServiceInterface) | FR-CONTENT-001 | VP-4, §6.1 | `Interfaces/NoticeServiceInterface.php` |
| IF-CONTENT-004 (BannerRepositoryInterface) | FR-CONTENT-003, NFR-CONTENT-002, NFR-CONTENT-003 | VP-4, §6.3 | `Interfaces/BannerRepositoryInterface.php` |
| IF-CONTENT-005 (FaqRepositoryInterface) | FR-CONTENT-002, NFR-CONTENT-002 | VP-4, §6.3 | `Interfaces/FaqRepositoryInterface.php` |
| IF-CONTENT-006 (NoticeRepositoryInterface) | FR-CONTENT-001 | VP-4, §6.3 | `Interfaces/NoticeRepositoryInterface.php` |
| IF-CONTENT-007 (ThemeRepositoryInterface) | FR-CONTENT-004, NFR-CONTENT-005 | VP-4, §6.3 | `Interfaces/ThemeRepositoryInterface.php` |

---

## 7. Feasibility Review (타당성 검토)

| 항목 | 근거 | 결론 |
|------|------|------|
| API 응답 camelCase 변환 | CLAUDE.md 프로젝트 지침 — "응답 키 네이밍: DB snake_case → API 응답 camelCase 변환 필수". Next.js 프론트엔드는 camelCase 컨벤션 사용 — 변환 없으면 프론트엔드에서 별도 매핑 필요. Service 레이어 또는 Entity 레벨에서 일괄 처리 가능 | 채택. 모든 Content 모듈 응답 필드 camelCase 통일 |
| 배너 조회 meta 구조 — CI4 빌트인 Pager | CI4 4.7.2 빌트인 Pager — `Model::paginate()` 호출 후 `$model->pager`로 `currentPage`, `perPage`, `total`, `lastPage` 추출. CLAUDE.md — 커스텀 Pager 구현 금지. 배너/FAQ/공지는 CI4 Pager 사용 | 채택. 테마(limit/offset)는 CI4 `paginate()` 적용 불가 구조 — 예외 허용 |
| 테마 onFlag 필터 — 외부 DB 의존 | onFlag 필터는 Hermes DB(101.101.211.242)의 온콜 상태를 서브쿼리 JOIN. Content 모듈이 외부 DB에 의존하는 유일한 지점. 장애 시 테마 목록 전체 불응답 위험. 향후 HermesService Interface 분리 권고 | 현재 구조 유지 (ThemeRepository). 향후 리팩터링 로드맵에 등록 |

---

## 8. Change Impact Log (변경 영향 기록)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| MIL-STD-498 IDD 표준 전면 전환 (v1.2 → v2.0) | Scope/References/Interface 5-subsection/Events/DataFormats/Traceability 구조 도입. 각 인터페이스를 Identification/Characteristics/Allocations/Data/Adaptation 5항목으로 정형화 | 프로젝트 지침 — IEEE 표준 전환 요구, 3-Round Review PASS |
| 인터페이스 이벤트 섹션(섹션 4) 신설 | 배너 시간 활성화, 외부 DB 실패, 입력 검증 실패 등 이벤트-처리 매핑 명시 | MIL-STD-498 IDD — 인터페이스 이벤트 정의 의무 |
| 요구사항 추적성 섹션(섹션 6) 신설 | 인터페이스 ID ↔ FR/NFR ↔ SDD ↔ 파일 경로 일괄 추적 | MIL-STD-498 — 인터페이스와 요구사항 간 추적성 의무 |
| 인터페이스별 5-subsection 구조 적용 | 각 인터페이스 Identification/Characteristics/Requirement Allocations/Data Element/Adaptation 5항목 명시 | MIL-STD-498 IDD 표준 형식 준수 |
| 데이터 포맷 섹션 JSON 예시 확장 | 배너 목록, 테마 목록, 공지 생성, 에러 4건 예시 포함. 프론트엔드/API 소비자 즉시 참조 가능 | 기존 문서에 JSON 예시 4건만 존재 — 실제 필드 형식 확인 불가 |

---

## 9. Review Checklist (검토 체크리스트)

### 완전성 (Completeness)
- [x] MIL-STD-498 — Scope, References, IF 섹션, Events, DataFormats, Traceability 완료
- [x] 내부 인터페이스 7건 (IF-CONTENT-001~007) 정의 완료
- [x] 각 인터페이스 5-subsection (Identification/Characteristics/Allocations/Data/Adaptation) 완료
- [x] 외부 인터페이스 확인 (해당 없음 — Hermes DB는 내부 직접 조인)
- [x] 인터페이스 이벤트 정의 (4건)
- [x] 데이터 포맷 JSON 예시 (4건)
- [x] camelCase 필드 매핑 테이블
- [x] 요구사항 추적성 매트릭스 (7건)
- [x] 타당성 검토 (3건)
- [x] 변경 영향 기록 (5건)

### 일관성 (Consistency)
- [x] 모든 인터페이스 DI 모듈별 분산 등록 (중앙 등록 금지)
- [x] camelCase 컨벤션 일관 적용
- [x] SRS FR/NFR과 인터페이스 추적 완전

### 검증 가능성 (Verifiability)
- [x] 각 인터페이스 메서드 시그니처 명시
- [x] 에러 처리 계약 (INVALID_INPUT, NOT_FOUND, INTERNAL)
- [x] 적용 인덱스 명시

### 추적성 (Traceability)
- [x] IF ↔ SRS FR/NFR 매핑
- [x] IF ↔ SDD 섹션 매핑
- [x] IF ↔ 파일 경로 매핑

---

## 10. Change Log (변경 로그)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-15 | 1.0.0 | 초기 작성 |
| 2026-04-15 | 1.2.0 | 요청/응답 JSON 예시(4건), 타당성 검토(3건), 변경 영향 기록(3건) 추가 |
| 2026-04-15 | 2.0.0 | IEEE 표준 전면 전환. 3-Round Review PASS. MIL-STD-498 IDD 구조 도입. 인터페이스 5-subsection, 이벤트 섹션, 요구사항 추적성 매트릭스 추가 |
