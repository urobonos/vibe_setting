---
문서명: Social 모듈 소프트웨어 설계 문서 (SDD)
문서ID: SDD-SOCIAL-001
버전: v2.1
적용 표준: IEEE 1016-2009
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
대상 시스템: HongCafe Global Backend — Social Module
관련 문서:
  - social-srs.md (SRS-SOCIAL-001)
  - social-idd.md (IDD-SOCIAL-001)
  - docs/api-specification.md
---

# SDD-SOCIAL-001: Social 모듈 소프트웨어 설계 문서

> **IEEE 1016-2009** 준수 — Software Design Description
> SnsShareController (profileSns → HTML with OG tags, boardSns → HTML),
> GrouplistController (getListGroup paginated)의 설계를 기술한다.

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 SRS-SOCIAL-001의 요구사항을 충족하기 위한 Social 모듈의 소프트웨어 설계를 IEEE 1016-2009 표준에 따라 기술한다. 아키텍처 결정(ADR), 컴포넌트 설계, 뷰 파일 설계, 시퀀스 다이어그램, 쿼리 설계를 포함한다.

### 1.2 Scope (범위)

- **모듈 경로**: `app/Modules/Social/`
- **컨트롤러**: `SnsShareController` (44 lines), `GrouplistController` (99 lines)
- **레포지토리**: `GrouplistRepository` (5 메서드 + CRUD)
- **뷰 파일**: locale-aware 경로 (`{locale}/Mobile/Pages/Content/ShareSnsProfile`, `ShareSnsBoard`)
- **외부 연동**: `SnsRepository` (Member 모듈) — `tb_sns_info` 조회

### 1.3 References (참조 문서)

| 문서 | 설명 |
|------|------|
| IEEE 1016-2009 | Software Design Descriptions |
| SRS-SOCIAL-001 | Social 모듈 소프트웨어 요구사항 명세서 |
| IDD-SOCIAL-001 | Social 모듈 인터페이스 설계 문서 |
| Open Graph Protocol | https://ogp.me — OG 메타태그 표준 |
| CLAUDE.md | 프로젝트 코딩 표준 및 아키텍처 지침 |

### 1.4 Design Viewpoints (설계 관점)

| Viewpoint | 설명 | 관련 섹션 |
|-----------|------|----------|
| Logical View | 컴포넌트 구조 및 책임 분리 | 섹션 3 |
| Process View | 요청 처리 흐름 및 시퀀스 | 섹션 5 |
| Data View | DB 테이블, 쿼리 설계 | 섹션 4 |
| Presentation View | HTML 뷰 파일 (OG 태그 구조, locale-aware) | 섹션 3.1 |

---

## 2. Module Structure Overview (모듈 구조 개요)

```
app/Modules/Social/
├── Config/
│   ├── Routes.php                         — 명시적 EP 등록 (Auto Routing 비활성)
│   └── Services.php                       — DI 바인딩 (Interface → Implementation)
├── Controllers/
│   ├── SnsShareController.php             (44 lines) — OG 태그 HTML 렌더링
│   └── GrouplistController.php            (99 lines) — 그룹 목록 JSON 조회
├── Repositories/
│   └── GrouplistRepository.php            — 5 메서드 + CRUD (그룹 데이터 접근)
├── Interfaces/
│   └── GrouplistRepositoryInterface.php   — Repository 계약 정의
├── Models/
│   ├── GrouplistModel.php                 — tb_grouplist_opt 모델
│   └── SnsModel.php                       — tb_sns_info 모델 (SnsRepository에서 사용)
└── Entities/
    └── Grouplist.php                      — Grouplist 엔티티
```

**뷰 파일 경로 (locale-aware)**:
```
{locale}/Mobile/Pages/Content/ShareSnsProfile   — 프로필 OG 태그 HTML 뷰
{locale}/Mobile/Pages/Content/ShareSnsBoard     — 게시물 OG 태그 HTML 뷰
```

> **설계 특성**: 뷰 파일은 Social 모듈 내부(`Modules/Social/Views/`)가 아닌 locale 기반 경로에 위치한다. `$this->locale` 프로퍼티(BaseApiController 상속)로 동적 경로를 결정한다.

**핵심 설계 특성**: `SnsShareController`는 JSON을 반환하지 않는다. CI4 `echo view()` 함수를 통해 HTML 뷰를 렌더링하며 응답을 반환한다. 이는 Social 모듈에서 표준 JSON API 응답 규칙의 유일한 예외 케이스이다.

---

## 3. Component Design (컴포넌트 설계)

### 3.1 SnsShareController

**파일**: `app/Modules/Social/Controllers/SnsShareController.php`
**Lines**: 44
**상속**: `BaseApiController`
**역할**: SNS 공유용 OG 태그가 포함된 HTML 페이지 렌더링. JSON 응답 없음.

#### 메서드 목록

| 메서드 | HTTP | 경로 | 인증 | CSRF | 응답 형식 | 설명 |
|--------|------|------|------|------|---------|------|
| `profileSns()` | **POST** | `/api/sns-shares/profile-sns` | 없음 | 면제(공개) | **text/html** | 프로필 OG 태그 HTML |
| `boardSns()` | **POST** | `/api/sns-shares/board-sns` | 없음 | 면제(공개) | **text/html** | 게시물 OG 태그 HTML |

> **변경 이유 (SOCIAL-DEF-001, SOCIAL-DEF-003)**: 구 설계(`showProfile(int $userId)`, GET, 경로 파라미터)는 실제 구현(`profileSns()`, POST, JSON body)과 전면 불일치. SSOT(API)에 맞춰 전면 수정.

#### HTML 응답 구현 패턴

```php
// JSON 응답 아님 — HTML 뷰 렌더링 (echo view 패턴)
public function profileSns(): void
{
    $post = $this->getJsonInput();          // POST JSON body 수신
    $data = array_merge($post, $this->snsInfo); // SNS 설정 정보 병합
    echo view($this->locale . "/Mobile/Pages/Content/ShareSnsProfile", $data);
}
```

이 패턴은 표준 `BaseApiController`의 JSON 응답 헬퍼를 사용하지 않으며, CI4 내장 `echo view()` 함수를 직접 사용한다.

#### initController() 설계

```php
public function initController(...): void
{
    parent::initController(...);
    $this->snsRepository = service('snsRepository');   // Member 모듈 DI
    $this->snsInfo = $this->snsRepository->getSnsInfo(); // tb_sns_info 사전 조회
}
```

- `snsRepository`는 **Member 모듈**(`app/Modules/Member/Config/Services.php`)에 등록된 서비스이다.
- `getSnsInfo()`는 `tb_sns_info` 테이블에서 `st_code` 기반으로 SNS 설정 정보를 조회한다.

#### profileSns() 상세 설계

```
입력:
  POST JSON body (인증 없음)

처리 흐름:
  1. $post = $this->getJsonInput() — POST body 수신
  2. $data = array_merge($post, $this->snsInfo) — SNS 설정 정보 병합
  3. echo view("{locale}/Mobile/Pages/Content/ShareSnsProfile", $data) — HTML 렌더링
  4. HTTP 200 (void 반환, echo로 직접 출력)
```

#### boardSns() 상세 설계

```
입력:
  POST JSON body (인증 없음)

처리 흐름:
  1. $post = $this->getJsonInput() — POST body 수신
  2. $data = array_merge($post, $this->snsInfo) — SNS 설정 정보 병합
  3. echo view("{locale}/Mobile/Pages/Content/ShareSnsBoard", $data) — HTML 렌더링
  4. HTTP 200 (void 반환)
```

#### 라우트 등록 (Routes.php)

```php
// 공개 EP — 인증 필터 없음. AuthFilter::EXCLUDED_PATHS 명시적 등록 완료.
$routes->group('api', ['namespace' => 'App\Modules\Social\Controllers'], function ($routes) {
    $routes->post('sns-shares/profile-sns', 'SnsShareController::profileSns');
    $routes->post('sns-shares/board-sns',   'SnsShareController::boardSns');
    $routes->post('group-lists/get-list-group', 'GrouplistController::getListGroup');
});
```

> **중요**: EXCLUDED_PATHS 등록은 `app/Filters/AuthFilter.php`에서 관리한다. Routes.php에 별도 필터 지정 없음.

#### View 파일 설계

뷰 파일은 locale-aware 경로에 위치한다. Social 모듈 내부 Views 디렉토리가 아님에 주의한다.

| 뷰 파일 | 경로 | 용도 |
|---------|------|------|
| ShareSnsProfile | `{locale}/Mobile/Pages/Content/ShareSnsProfile` | 프로필 OG 태그 HTML |
| ShareSnsBoard | `{locale}/Mobile/Pages/Content/ShareSnsBoard` | 게시물 OG 태그 HTML |

뷰 파일 내 모든 동적 값은 CI4 `esc()` 함수로 XSS를 방지한다.

---

### 3.2 GrouplistController

**파일**: `app/Modules/Social/Controllers/GrouplistController.php`
**Lines**: 99
**상속**: `BaseApiController`
**역할**: 그룹 기반 상담사 목록 JSON 조회. 공개 EP. 페이지네이션 지원.

#### 메서드 목록

| 메서드 | HTTP | 경로 | 인증 | CSRF | 응답 형식 | 설명 |
|--------|------|------|------|------|---------|------|
| `getListGroup()` | **POST** | `/api/group-lists/get-list-group` | 없음 | 면제(공개) | JSON | 그룹 목록 (페이지네이션) |

> **미구현 EP**: 구 SDD에 기술된 `getGroupDetail`, `getGroupCallees` EP는 Routes.php에 등록되지 않으며 구현체가 없다. 해당 EP는 **미구현** 상태이다.

#### getListGroup() — 상세 설계

```
처리 흐름:
  1. $data = $this->getJsonInput() — POST body 수신
     (limit, offset, gp_code, on_flag, order, st_code, it_status 등)

  2. GrouplistRepository::getCalleelist($data)
     → tb_grouplist_callee JOIN tb_callee
     → gp_code 기반 그룹 소속 상담사 코드(it_code) 목록 조회

  3. $data['callee'] = comma-joined string of it_code values

  4. GrouplistRepository::getGrouplist($data)
     → tb_items AS it JOIN tb_callee AS ce
     → it_status=3, ce_status=3 기본 필터
     → $data['callee'] 있으면 WHERE IN(it_code) 적용
     → limit+1로 조회 (nextCheck 판단)

  5. 결과 처리:
     - it_tag: explode(',') → 배열 변환
     - it_notice: mb_strlen() 계산
     - notice_regist_date: 경과 시간(hours) 계산
     - it_counsel_field: json_decode()
     - it_counsel_field_search: explode(',')
     - item_label: ce_level>0 → 'partner', it_new=Y → 'new'
     - setItemPoint(): 포인트 계산 (BaseApiController 헬퍼)
     - view_tag / view_win_point / view_win_comment 계산

  6. $perPage = (limit !== 'all') ? (int)$limit : count($items)
     $total = GrouplistRepository::getGrouplistCount($data)
     respondPaginated($items, $total, $perPage, $offset) 반환

  7. 결과 없음 → respondError('INTERNAL', lang('Error.items.list.empty'), 500)
```

#### 라우트 등록 (Routes.php)

```php
// 공개 EP — 필터 없음. AuthFilter::EXCLUDED_PATHS 등록 완료.
$routes->post('group-lists/get-list-group', 'GrouplistController::getListGroup');
```

> **변경 이유 (SOCIAL-DEF-004)**: 구 SDD는 `getGroupList()`, GET, `page`/`perPage` 쿼리스트링, `['filter' => 'ratelimit,auth']`로 기술했다. 실제 구현은 `getListGroup()`, POST, `limit`/`offset` JSON body, 필터 없음이다. 전면 수정.

---

## 4. Data Design (데이터 설계)

### 4.1 실제 사용 테이블

> **변경 이유 (SOCIAL-DEF-004, SOCIAL-DEF-008)**: 구 SDD는 `tb_group`, `tb_group_callee`를 기술했다. 실제 코드는 `tb_items`, `tb_callee`, `tb_grouplist_callee`, `tb_grouplist_opt`, `tb_banner`를 사용한다.

| 테이블 | 용도 | 사용 메서드 |
|--------|------|-----------|
| `tb_items` | 상담사(아이템) 목록 — 그룹 목록 조회의 핵심 테이블 | `getGrouplist()` |
| `tb_callee` | 상담사 정보 | `getGrouplist()`, `getGrouplistCount()`, `getCalleelist()` |
| `tb_grouplist_callee` | 그룹-상담사 매핑 | `getCalleelist()` |
| `tb_grouplist_opt` | 그룹 옵션 설정 (GrouplistModel) | `getGroupInfo()` |
| `tb_banner` | 그룹 목록 배너 | `getGroupBanner()` |
| `tb_sns_info` | SNS 설정 정보 (Member 모듈 SnsModel) | `getSnsInfo()` |

> **Open Question (OQ-3)**: `tb_group`, `tb_group_callee` 테이블의 DB 존재 여부 및 신규 모듈 전환 계획 확인 필요.

### 4.2 GrouplistRepository — 메서드별 쿼리 설계

#### getGroupBanner(string $st_code='hongcafe', string $bn_link='')

```sql
SELECT *
FROM tb_banner
WHERE bn_position = 'main'
  AND st_code = :st_code
  AND bn_link = :bn_link
  AND bn_view = 'Y'
```

#### getGroupInfo(string $gp_code='')

```sql
SELECT *
FROM tb_grouplist_opt
WHERE gp_code = :gp_code
  AND gpt_status = 'ON'
```

#### getCalleelist(array $post)

```sql
SELECT gc.it_code
FROM tb_grouplist_callee AS gc
LEFT JOIN tb_callee AS ce ON gc.ce_code = ce.ce_code
WHERE gc.gp_code = :gp_code
  AND ce.ce_level >= 0
  AND gc.gp_use = 'ON'
```

#### getGrouplist(array $post) — 상담사 목록 (페이지네이션)

```sql
SELECT {itemSelect}, ce.ce_level
FROM tb_items AS it
LEFT JOIN tb_callee AS ce ON it.ce_code = ce.ce_code
WHERE it_status = :it_status   -- 기본 3
  AND ce.ce_status = '3'
  AND st_code = :st_code
  [AND it.it_code IN (:callee_list)]  -- gp_code 기반 필터 시
  [AND it.it_online = 'on' AND it.ca_status = 'standby']  -- on_flag=standby 시
ORDER BY {order_clause}   -- order 파라미터에 따라 동적
LIMIT :limit OFFSET :offset   -- limit+1 조회
```

#### getGrouplistCount(array $post)

```sql
SELECT COUNT(*) AS total
FROM tb_items AS it
LEFT JOIN tb_callee AS ce ON it.ce_code = ce.ce_code
WHERE it_status = :it_status
  AND ce.ce_status = '3'
  AND st_code = :st_code
  [AND it.it_code IN (:callee_list)]
  [AND it.it_online = 'on' AND it.ca_status = 'standby']
```

---

## 5. Sequence Diagrams (시퀀스 다이어그램)

### 5.1 SNS 프로필 공유 시퀀스

```
SNS Crawler / Browser
  └──→ POST /api/sns-shares/profile-sns
        │  (JSON body, 인증 헤더 없음)
        ▼
  [AuthFilter] ── EXCLUDED_PATHS 확인 ──→ api/sns-shares/profile-sns 통과 (필터 스킵)
        │
        ▼
  SnsShareController::profileSns()  [initController에서 snsInfo 사전 조회 완료]
        │
        ├── $post = getJsonInput()
        │
        ├── $data = array_merge($post, $this->snsInfo)
        │     └── snsInfo: SnsRepository::getSnsInfo() (Member 모듈)
        │           └──→ Aurora MySQL: SELECT ... FROM tb_sns_info WHERE st_code=:st_code
        │
        ├──→ echo view("{locale}/Mobile/Pages/Content/ShareSnsProfile", $data)
        │         → HTML 렌더링
        │
        └──→ HTTP 200 Content-Type: text/html (void)
```

### 5.2 그룹 목록 조회 시퀀스

```
Client (비인증)
  └──→ POST /api/group-lists/get-list-group
        │  JSON body: { "limit": 24, "offset": 0, "gp_code": "..." }
        ▼
  [AuthFilter] ── EXCLUDED_PATHS 확인 ──→ 통과 (필터 스킵, 인증 없음)
        │
        ▼
  GrouplistController::getListGroup()
        │
        ├── $data = getJsonInput()
        │
        ├──→ GrouplistRepository::getCalleelist($data)
        │         └──→ Aurora MySQL: tb_grouplist_callee JOIN tb_callee
        │               → it_code 목록 반환
        │
        ├── $data['callee'] = comma-joined it_code string
        │
        ├──→ GrouplistRepository::getGrouplist($data)   [limit+1]
        │         └──→ Aurora MySQL: tb_items AS it LEFT JOIN tb_callee AS ce
        │               WHERE it_status=3, ce_status=3, st_code=...
        │               [WHERE IN callee list]
        │
        ├── 결과 처리:
        │   it_tag → 배열 / item_label → {partner, new} / setItemPoint()
        │   nextCheck = (count(result) > limit)
        │
        ├──→ GrouplistRepository::getGrouplistCount($data)
        │         └──→ Aurora MySQL: COUNT(*)
        │
        └──→ respondPaginated($items, $total, $perPage, $offset)
              HTTP 200 { "data": [...], "meta": { ... }, "nextCheck": ... }
```

### 5.3 SNS 게시물 공유 시퀀스

```
SNS Crawler / Browser
  └──→ POST /api/sns-shares/board-sns
        │  (JSON body, 인증 헤더 없음)
        ▼
  [AuthFilter] ── EXCLUDED_PATHS 확인 ──→ api/sns-shares/board-sns 통과
        │
        ▼
  SnsShareController::boardSns()
        │
        ├── $post = getJsonInput()
        ├── $data = array_merge($post, $this->snsInfo)
        ├──→ echo view("{locale}/Mobile/Pages/Content/ShareSnsBoard", $data)
        └──→ HTTP 200 Content-Type: text/html (void)
```

---

## 6. ADR (Architecture Decision Records)

### ADR-SOC-001: SNS 공유 EP HTML 응답 결정

**결정**: SNS 공유 EP(`/api/sns-shares/profile-sns`, `/api/sns-shares/board-sns`)는 JSON이 아닌 HTML을 반환한다.
**근거**: SNS 크롤러(Twitter, KakaoTalk, LINE)는 공유 링크 접근 시 OG 태그가 포함된 HTML 페이지를 파싱한다. JSON 응답은 OG 미리보기 생성에 사용될 수 없다.
**결과**: 해당 EP는 표준 JSON API 응답 규칙(`{ "data": {} }`)의 예외 케이스. SRS NFR-SOC-001에 명시.
**영향**: API 문서에서 응답 형식을 `text/html`로 명시해야 한다.

### ADR-SOC-002: SNS 공유 EP POST 메서드 + 공개 접근

**결정**: SNS 공유 EP는 POST 메서드를 사용하며 JWT 인증 없이 공개 접근을 허용한다.
**근거**: 실제 구현이 POST + JSON body 패턴을 사용한다. AuthFilter::EXCLUDED_PATHS에 명시적 등록으로 인증을 우회한다.
**결과**: Routes.php에 필터 없이 `$routes->post(...)` 등록. EXCLUDED_PATHS 등록 완료.
**보안 고려**: OG 태그에는 SNS 설정 정보만 포함. 민감정보 노출 금지.

### ADR-SOC-003: GrouplistRepository 5개 메서드 목적별 분리

**결정**: 그룹 관련 조회를 단일 다목적 메서드 대신 목적별 5개 메서드로 분리한다.
**근거**: 단일 다목적 메서드는 컨트롤러 수준에서 불필요한 데이터를 매번 조회한다. 목적별 분리로 쿼리 최적화와 명확한 의도 표현이 가능하다.
**결과**: `getGroupBanner`, `getGroupInfo`, `getCalleelist`, `getGrouplist`, `getGrouplistCount` 5개로 분리. 모두 `array $post` 타입 파라미터(getGroupBanner 제외) 사용.
**영향**: 각 메서드를 독립적으로 단위 테스트 가능.

### ADR-SOC-004: SnsShareController의 SnsRepository (Member 모듈) 의존

**결정**: `SnsShareController`는 `SnsRepository`(Member 모듈)를 통해 `tb_sns_info` 데이터를 조회한다.
**근거**: SNS 공유 설정 정보(`tb_sns_info`)는 Member 모듈에서 관리된다. `service('snsRepository')`를 통해 DI로 접근한다.
**결과**: `SnsShareController::initController()`에서 `snsRepository` 서비스를 초기화하고 `getSnsInfo()`를 사전 호출한다.
**영향**: SnsModel(`tb_sns_info`)은 Social 모듈 내 파일이지만, Repository는 Member 모듈에 위치한다.

### ADR-SOC-005: GrouplistController — tb_items 기반 실제 조회

**결정**: `GrouplistController`는 `tb_group` 대신 `tb_items` 테이블 기반으로 상담사 목록을 조회한다.
**근거**: 실제 그룹 목록 기능은 그룹별로 필터링된 상담사(아이템) 목록을 반환하는 것이다. `tb_grouplist_callee`에서 그룹 소속 상담사 코드를 조회한 후, `tb_items`에서 상세 정보를 조회한다.
**결과**: `getCalleelist` → `getGrouplist` 2-step 조회 패턴 사용.
**영향**: 응답 필드가 `tb_items` 기반 레거시 snake_case(`it_code`, `it_nick` 등)로 반환된다.

---

## 7. Design Checklist (설계 체크리스트)

| 항목 | 확인 | 비고 |
|------|------|------|
| SnsShareController POST 메서드 수신 (getJsonInput) | - | GET 아님 |
| echo view() HTML 응답 구현 (JSON 응답 사용 금지) | - | |
| locale-aware 뷰 경로 사용 | - | {locale}/Mobile/Pages/Content/ |
| SnsRepository (Member 모듈) DI 연동 | - | service('snsRepository') |
| SNS 공유 EP EXCLUDED_PATHS 등록 | ✓ | AuthFilter.php 확인 완료 |
| GrouplistController POST 메서드 수신 | - | |
| getCalleelist → getGrouplist 2-step 조회 | - | |
| limit+1 nextCheck 로직 | - | |
| it_tag comma 분리 → 배열 | - | |
| item_label 구성 (partner, new) | - | |
| GrouplistRepository 5개 메서드 array $post 시그니처 | ✓ | Interface 파일 확인 완료 |
| respondPaginated 페이지네이션 | - | |
| 단위 테스트: GrouplistRepository | - | |
| 명시적 Routes.php 등록 (Auto Routing 비활성) | ✓ | |
| getGroupDetail, getGroupCallees — **미구현** 명기 | ✓ | Routes.php 미등록 |

---

## 8. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS |
| v2.1 | 2026-04-21 | jypark | **API SSOT 대조 반영** (SOCIAL-DEF-001,003,004,008,010): SnsShareController 메서드명·HTTP메서드·경로·데이터수신 전면 수정(showProfile→profileSns, GET→POST, 경로파라미터→JSON body), 뷰 경로 locale-aware 수정(Modules\Social\Views\→{locale}/Mobile/Pages/Content/), SnsRepository(Member모듈) 의존 추가, GrouplistController 메서드명·HTTP메서드·파라미터·인증 수정(getGroupList→getListGroup, GET→POST, page/perPage→limit/offset, JWT필수→공개), 미구현 EP(getGroupDetail,getGroupCallees) 명기, 실제 사용 테이블 전면 수정(tb_group→tb_items 등), 쿼리 설계 실제 구현 기준 전면 수정, ADR 2건 추가 |
