---
문서명: Social 모듈 소프트웨어 요구사항 명세서 (SRS)
문서ID: SRS-SOCIAL-001
버전: v2.1
적용 표준: IEEE 29148:2018
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
대상 시스템: HongCafe Global Backend — Social Module
관련 문서:
  - social-sdd.md (SDD-SOCIAL-001)
  - social-idd.md (IDD-SOCIAL-001)
  - docs/api-specification.md
---

# SRS-SOCIAL-001: Social 모듈 소프트웨어 요구사항 명세서

> **IEEE 29148:2018** 준수 — Software Requirements Specification
> SNS 프로필·게시물 공유(HTML 응답), 그룹 목록 조회(JSON 응답)를 포함하는
> 3개 엔드포인트의 기능·비기능 요구사항을 정의한다.

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 HongCafe Global Backend의 **Social 모듈**에 대한 소프트웨어 요구사항을 IEEE 29148:2018 표준에 따라 명세한다. 대상 독자는 개발자, QA 엔지니어, 아키텍트이며, 구현·검증의 기준으로 활용된다.

### 1.2 Scope (범위)

Social 모듈은 다음 기능 영역을 포함한다.

| 기능 영역 | 주요 Controller | 엔드포인트 수 | HTTP 메서드 | 응답 형식 |
|-----------|----------------|--------------|------------|---------|
| SNS 프로필 공유 | `SnsShareController` | 1 | **POST** | **HTML** (JSON 아님) |
| SNS 게시물 공유 | `SnsShareController` | 1 | **POST** | **HTML** (JSON 아님) |
| 그룹 목록 조회 | `GrouplistController` | 1 | **POST** | JSON |

**핵심 설계 특성**: SNS 공유 엔드포인트는 JSON을 반환하지 않는다. OG(Open Graph) 태그가 포함된 HTML 페이지를 반환한다. 이는 Social 모듈의 가장 중요한 설계 특성이며, 모든 관련 문서에서 명시적으로 기술되어야 한다.

**모듈 경로**: `app/Modules/Social/`

**범위 외**: SNS OAuth 인증(`POST /api/sns/receive`)은 **Auth 모듈** 소관(`app/Modules/Auth/Controllers/SnsController.php`)이며 Social 모듈과 별개이다. Social 모듈은 SNS OAuth 흐름을 포함하지 않는다.

### 1.3 Definitions, Acronyms, and Abbreviations (정의 및 약어)

| 용어 | 정의 |
|------|------|
| SNS | Social Networking Service (소셜 네트워크 서비스) |
| OG Tags | Open Graph Protocol 메타태그 — SNS 크롤러가 공유 미리보기 생성에 사용 |
| OGP | Open Graph Protocol — SNS 미리보기 메타데이터 표준 |
| SNS 크롤러 | Twitter Bot, KakaoTalk Scraper, LINE Scraper 등 OG 태그 수집 봇 |
| 그룹 목록 | 상담사 그룹(조직) 목록 |
| GrouplistRepository | 그룹 데이터 접근 5개 메서드를 제공하는 Repository |
| HTML 응답 | JSON이 아닌 HTML 페이지 반환 — SNS 공유용 미리보기 페이지 |
| SnsRepository | Member 모듈 소속. `tb_sns_info` 기반 SNS 설정 정보 조회 |
| tb_items | 상담사(아이템) 목록 테이블 — 그룹 목록 조회의 실제 대상 테이블 |
| tb_grouplist_callee | 그룹-상담사 매핑 테이블 |
| tb_grouplist_opt | 그룹 옵션 설정 테이블 |
| FR | Functional Requirement (기능 요구사항) |
| NFR | Non-Functional Requirement (비기능 요구사항) |
| JWT | JSON Web Token (인증 토큰) |
| CDN | Content Delivery Network |
| SRS | Software Requirements Specification |

### 1.4 References (참조 문서)

| 문서 | 설명 |
|------|------|
| IEEE 29148:2018 | Systems and software engineering — Life cycle processes — Requirements engineering |
| social-sdd.md (SDD-SOCIAL-001) | Social 모듈 소프트웨어 설계 문서 |
| social-idd.md (IDD-SOCIAL-001) | Social 모듈 인터페이스 설계 문서 |
| docs/api-specification.md | 전체 API 엔드포인트 명세 (~160개) |
| api-docs/social/social-api.md | Social 모듈 API 문서 (SSOT) |
| CLAUDE.md | 프로젝트 코딩 표준 및 아키텍처 지침 |
| Open Graph Protocol | https://ogp.me — OG 메타태그 표준 |

### 1.5 Overview (문서 구성)

- **섹션 2**: 전체 시스템 기술 (System Description)
- **섹션 3**: 기능 요구사항 (FR)
- **섹션 4**: 비기능 요구사항 (NFR)
- **섹션 5**: 유스케이스 (Use Cases)
- **섹션 6**: 엔드포인트 목록
- **섹션 7**: 검증 체크리스트
- **섹션 8**: 변경 이력

---

## 2. Overall Description (전체 시스템 기술)

### 2.1 Product Perspective (시스템 위치)

Social 모듈은 HongCafe Global Backend Modular Monolith 아키텍처의 일부이다. SNS 공유 기능과 그룹 목록 조회를 담당하며, SNS 공유 EP는 표준 JSON API 응답 규칙의 예외 케이스다.

```
[SNS 크롤러 / 브라우저 (JSON body 포함 POST)]   [비인증 사용자 (JSON body 포함 POST)]
        │                                               │
        ▼                                               ▼
POST /api/sns-shares/profile-sns          POST /api/group-lists/get-list-group
POST /api/sns-shares/board-sns            (공개 EP — 인증 없음)
(공개 EP — 인증 없음)                               │
        │                                               ▼
        ▼                                    [GrouplistController]
[SnsShareController]                          └─> GrouplistRepository
  └─> SnsRepository (Member 모듈)               └─> tb_items + tb_callee +
  └─> echo view() — HTML 응답                       tb_grouplist_callee
       (OG Tags, locale 기반 뷰 경로)               └─> JSON 응답
```

### 2.2 Product Functions (주요 기능 요약)

1. **SNS 프로필 공유**: 상담사/회원 프로필 OG 태그 HTML 페이지 반환 (공개 EP, POST)
2. **SNS 게시물 공유**: 게시물/콘텐츠 OG 태그 HTML 페이지 반환 (공개 EP, POST)
3. **그룹 목록 조회**: 상담사 목록을 그룹 필터 기반으로 페이지네이션 조회 (공개 EP, POST)

### 2.3 User Classes and Characteristics (사용자 분류)

| 사용자 유형 | 특성 | 접근 가능 기능 |
|------------|------|--------------|
| SNS 크롤러 | 인증 없음, HTTP POST | SNS 프로필/게시물 공유 EP (HTML 반환) |
| Anonymous (브라우저) | 인증 없음 | SNS 공유 EP 직접 접근 → 프론트엔드 리다이렉트 |
| 비인증 사용자 | 인증 없음 | 그룹 목록 조회 (공개 EP) |

> **변경 이유 (SOCIAL-DEF-002, SOCIAL-DEF-008)**: `/api/group-lists/get-list-group`은 `AuthFilter::EXCLUDED_PATHS`에 명시적으로 등록된 공개 EP이다. Routes.php에 auth 필터가 없다. 따라서 "JWT 인증 완료" 사용자 분류를 "비인증 사용자"로 수정한다.
>
> **Open Question (OQ-1)**: 실제 프로덕션 인텐트가 공개인지 JWT 필수인지 확인 필요. Routes.php auth 필터 추가 여부는 의사결정 대기.

### 2.4 Operating Environment (운영 환경)

| 항목 | 값 |
|------|----|
| 언어/프레임워크 | PHP 8.4+ / CodeIgniter 4.7+ |
| DB (내부) | Amazon Aurora MySQL 3.12.0 (MySQL 8.0.44 호환) |
| 외부 시스템 | 없음 (Social 모듈은 외부 API 의존성 없음) |
| CDN | CloudFront (OG 이미지 URL에 사용) |
| 배포 환경 | Production: `https://prd.gl.hongcafe.com` |

### 2.5 Constraints (제약 사항)

- PHP `declare(strict_types=1)` 필수
- SNS 공유 EP는 JSON을 반환하지 않음 — CI4 `echo view()` 함수로 HTML 렌더링
- SNS 공유 EP는 POST 메서드로 JSON body를 수신한다 (경로 파라미터 없음)
- `AuthFilter` EXCLUDED_PATHS에 `api/sns-shares/profile-sns`, `api/sns-shares/board-sns`, `api/group-lists/get-list-group` 명시적 등록 완료
- 그룹 목록 조회 EP는 CI4 빌트인 respondPaginated 사용 (커스텀 페이지네이션 허용)

### 2.6 Assumptions and Dependencies (전제 및 의존성)

- SNS 크롤러는 쿠키/JWT 없이 POST 요청으로 접근한다.
- OG 이미지는 CDN(CloudFront) 경유 URL로 제공된다.
- `tb_items`, `tb_callee`, `tb_grouplist_callee`, `tb_grouplist_opt`, `tb_banner` 테이블이 존재한다.
- `SnsShareController`는 `SnsRepository`(Member 모듈)에서 `tb_sns_info` 기반 SNS 설정 정보를 조회한다.
- 뷰 파일은 locale-aware 경로(`{locale}/Mobile/Pages/Content/ShareSnsProfile`, `ShareSnsBoard`)로 제공된다.

> **Open Question (OQ-3)**: `tb_group`, `tb_group_callee` 테이블은 Social 모듈 코드에서 사용되지 않는다. 실제 DB에 존재하는지, 향후 신규 모듈 전환 계획이 있는지 확인 필요.

---

## 3. Functional Requirements (기능 요구사항)

### FR-SOC-001: SNS 프로필 공유 (Profile SNS Share — HTML Response)

**ID**: FR-SOC-001 | **우선순위**: P1 (필수) | **연관 UC**: UC-SOC-001

**설명**: SNS에 프로필을 공유하기 위한 OG 태그가 포함된 HTML 페이지를 반환한다. 요청은 POST JSON body로 수신하며, 응답은 JSON이 아닌 `text/html`이다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 1.1 | `POST /api/sns-shares/profile-sns`로 OG 태그 HTML 페이지를 반환한다 | HTTP 응답 확인 |
| 1.2 | `Content-Type: text/html` 응답을 반환한다 | 헤더 검증 |
| 1.3 | OG 태그 포함: `og:type`, `og:title`, `og:description`, `og:image`, `og:url`, `og:site_name` | HTML 파싱 확인 |
| 1.4 | Twitter Card 태그 포함: `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image` | HTML 파싱 확인 |
| 1.5 | `og:image` URL은 HTTPS CDN URL이어야 한다 | URL 검증 |
| 1.6 | 인증 불필요 (공개 EP) — AuthFilter EXCLUDED_PATHS 등록 | 인증 없이 접근 테스트 |
| 1.7 | 요청 본문은 JSON body이며 `getJsonInput()`으로 수신한다 | 요청 처리 확인 |
| 1.8 | `SnsRepository::getSnsInfo()`로 `tb_sns_info` 기반 SNS 설정 정보를 조회한다 | Unit Test |
| 1.9 | 뷰 파일 경로: `{locale}/Mobile/Pages/Content/ShareSnsProfile` (locale-aware) | 뷰 렌더링 확인 |
| 1.10 | 브라우저 직접 접근 시 `<script>`로 프론트엔드 URL로 리다이렉트한다 | 브라우저 동작 확인 |

**입력**: `POST /api/sns-shares/profile-sns` (JSON body, 인증 헤더 없음)
**출력**: `HTTP 200 text/html` (OG 태그 포함 HTML)
**선행 조건**: AuthFilter EXCLUDED_PATHS에 등록 완료
**후행 조건**: OG 태그가 포함된 HTML이 반환되어 SNS 미리보기가 표시됨

---

### FR-SOC-002: SNS 게시물 공유 (Board SNS Share — HTML Response)

**ID**: FR-SOC-002 | **우선순위**: P1 (필수) | **연관 UC**: UC-SOC-001

**설명**: 특정 게시물/콘텐츠를 SNS에 공유하기 위한 OG 태그가 포함된 HTML 페이지를 반환한다.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 2.1 | `POST /api/sns-shares/board-sns`로 OG 태그 HTML 페이지를 반환한다 | HTTP 응답 확인 |
| 2.2 | `Content-Type: text/html` 응답을 반환한다 | 헤더 검증 |
| 2.3 | OG 태그 포함: `og:type=article`, `og:title`, `og:description`, `og:image`, `og:url` | HTML 파싱 확인 |
| 2.4 | 인증 불필요 (공개 EP) | 인증 없이 접근 테스트 |
| 2.5 | 요청 본문은 JSON body이며 `getJsonInput()`으로 수신한다 | 요청 처리 확인 |
| 2.6 | `SnsRepository::getSnsInfo()`로 `tb_sns_info` 기반 SNS 설정 정보를 조회한다 | Unit Test |
| 2.7 | 뷰 파일 경로: `{locale}/Mobile/Pages/Content/ShareSnsBoard` (locale-aware) | 뷰 렌더링 확인 |

**입력**: `POST /api/sns-shares/board-sns` (JSON body, 인증 헤더 없음)
**출력**: `HTTP 200 text/html`

---

### FR-SOC-003: 그룹 목록 조회 (Group List — Paginated)

**ID**: FR-SOC-003 | **우선순위**: P1 (필수) | **연관 UC**: UC-SOC-002

**설명**: 그룹 필터 기반으로 상담사(아이템) 목록을 조회한다. 응답은 표준 JSON 포맷이며 페이지네이션을 지원한다. **공개 EP — 인증 불필요**.

**세부 요건**:

| # | 요건 | 검증 방법 |
|---|------|---------|
| 3.1 | `POST /api/group-lists/get-list-group`으로 그룹 내 상담사 목록을 JSON 반환한다 | API 호출 확인 |
| 3.2 | **인증 불필요** (공개 EP — EXCLUDED_PATHS 등록 완료) | 인증 없이 접근 테스트 |
| 3.3 | 요청 JSON body: `limit`(기본 24, `"all"` 가능), `offset`(기본 0), `gp_code`, `on_flag`, `order` 등 | 요청 필드 확인 |
| 3.4 | `GrouplistRepository::getCalleelist(array $post)` — 그룹 소속 상담사 코드 목록 조회 | Unit Test |
| 3.5 | `GrouplistRepository::getGrouplist(array $post)` — `tb_items` JOIN `tb_callee` 기반 상담사 목록 조회 | Unit Test |
| 3.6 | `GrouplistRepository::getGrouplistCount(array $post)` — 전체 건수 조회 | Unit Test |
| 3.7 | `limit !== 'all'`인 경우 `limit+1`로 조회하여 nextCheck 여부를 판단한다 | 응답 확인 |
| 3.8 | `it_tag` 필드는 comma 분리 후 배열로 변환한다 | 응답 필드 검증 |
| 3.9 | `item_label` 배열: `ce_level > 0` → `partner`, `it_new=Y` → `new` | 레이블 로직 확인 |
| 3.10 | `respondPaginated(items, total, perPage, offset)` 호출로 응답 구성 | 페이지네이션 테스트 |
| 3.11 | POST 요청이므로 CSRF 면제 조건 불일치 — CSRF 토큰 검증 적용 여부 확인 필요 | 필터 체인 확인 |

> **Open Question (OQ-2)**: `getListGroup()` 응답 필드가 레거시 snake_case(`it_code`, `it_nick`, `ce_level` 등)로 반환된다. API 문서(`groupCode`, `groupName`) 기준 camelCase 마이그레이션 계획 확인 필요.

**입력**: `POST /api/group-lists/get-list-group` (JSON body)

```json
{
  "limit": 24,
  "offset": 0,
  "gp_code": "GP001"
}
```

**출력**: `HTTP 200 application/json`

```json
{
  "data": [
    {
      "it_code": "IT001",
      "it_nick": "상담사명",
      "ce_level": 1,
      "it_tag": ["タロット", "占い"],
      "item_label": { "partner": "파트너" }
    }
  ],
  "meta": {
    "currentPage": 1,
    "perPage": 24,
    "total": 10,
    "lastPage": 1
  },
  "nextCheck": false
}
```

> **현황 주석**: 위 응답 필드는 현재 레거시 구현 기준이다. API 문서에서는 `groupCode`, `groupName` 등 camelCase 필드를 목표(TO-BE)로 기술하고 있다. 마이그레이션 완료 전까지 두 표기가 공존한다.

**선행 조건**: 없음 (공개 EP)
**후행 조건**: 그룹 내 상담사 목록과 페이지네이션 meta가 반환됨

---

## 4. Non-Functional Requirements (비기능 요구사항)

### NFR-SOC-001: SNS 공유 EP HTML 응답 특성

**ID**: NFR-SOC-001 | **우선순위**: P1 (필수)

| 항목 | 요건 |
|------|------|
| 응답 형식 | `text/html` (JSON 아님) |
| OG 표준 | Open Graph Protocol (https://ogp.me) 준수 |
| Twitter Card | `summary_large_image` 타입 사용 |
| JSON 응답 예외 | 표준 `{ "data": {} }` JSON 응답 규칙 적용 안 함 |
| HTTP 메서드 | POST (경로 파라미터 없음, JSON body 수신) |

### NFR-SOC-002: SNS 공유 EP 인증·CSRF

**ID**: NFR-SOC-002 | **우선순위**: P1 (필수)

| 항목 | 요건 |
|------|------|
| 인증 면제 | EXCLUDED_PATHS에 `api/sns-shares/profile-sns`, `api/sns-shares/board-sns` 등록 완료 |
| CSRF | POST 메서드이나 공개 EP로 EXCLUDED_PATHS 통과 — 실질적 CSRF 검증 면제 |
| 접근 허용 | Twitter Bot, KakaoTalk Scraper, LINE Scraper 등 무인증 접근 허용 |

**보안 고려**: 공개되는 OG 태그 데이터는 SNS 설정 정보만 포함. 개인식별 민감정보 노출 금지.

### NFR-SOC-003: SNS 공유 응답 성능

**ID**: NFR-SOC-003 | **우선순위**: P2 (중요)

| 항목 | 목표 |
|------|------|
| 응답시간 | p95 300ms 이하 |
| 캐시 | 향후 Redis 캐시 적용 고려 (반복 크롤러 대응) |
| 이미지 URL | CDN URL 사용으로 원본 서버 부하 방지 |

### NFR-SOC-004: 그룹 목록 조회 인증·성능

**ID**: NFR-SOC-004 | **우선순위**: P1 (필수)

| 항목 | 요건 |
|------|------|
| 인증 | **없음** (공개 EP — EXCLUDED_PATHS 등록 완료) |
| 응답시간 | p95 500ms 이하 |
| 페이지네이션 | `respondPaginated` 사용 |

### NFR-SOC-005: OG 이미지 URL 보안

**ID**: NFR-SOC-005 | **우선순위**: P2 (중요)

| 항목 | 요건 |
|------|------|
| URL 형식 | HTTPS 절대 경로 필수 |
| 경유 | CDN(CloudFront) URL 사용 |
| 원본 노출 | S3 원본 URL 직접 노출 금지 |
| 대체 이미지 | 이미지 미존재 시 기본 placeholder 이미지 URL 사용 |

---

## 5. Use Cases (유스케이스)

### UC-SOC-001: SNS 크롤러/사용자가 프로필/게시물 OG 태그를 수집한다

```
액터: SNS 크롤러 (Twitter Bot, KakaoTalk Scraper, LINE Scraper) / 일반 사용자
사전 조건: 없음 (공개 EP)

주 시나리오 (프로필):
  1. 사용자가 프로필 공유 링크를 SNS에 게시한다.
  2. SNS 크롤러가 POST /api/sns-shares/profile-sns 를 요청한다.
     (JSON body 포함, 인증 쿠키/JWT 없음)
  3. AuthFilter가 EXCLUDED_PATHS 확인 — api/sns-shares/profile-sns 통과 (필터 스킵)
  4. SnsShareController::profileSns()가 호출된다.
  5. getJsonInput()으로 POST body를 수신한다.
  6. SnsRepository::getSnsInfo() (Member 모듈)로 tb_sns_info 데이터를 조회한다.
  7. $data = array_merge($post, $snsInfo) 로 뷰 데이터를 구성한다.
  8. echo view("{locale}/Mobile/Pages/Content/ShareSnsProfile", $data)로 HTML을 렌더링한다.
  9. HTTP 200 Content-Type: text/html 로 반환한다.
  10. SNS에서 미리보기(썸네일, 제목, 설명)를 표시한다.

대안 시나리오:
  A1. 브라우저 직접 접근: <script>로 프론트엔드 프로필 페이지로 리다이렉트.

사후 조건: SNS 공유 시 미리보기가 정상 표시된다.
```

```
주 시나리오 (게시물):
  1-9. 프로필 시나리오와 동일
     경로: POST /api/sns-shares/board-sns
     뷰:  {locale}/Mobile/Pages/Content/ShareSnsBoard
```

### UC-SOC-002: 사용자가 그룹 목록을 조회한다

```
액터: 비인증 사용자 (공개 EP)
사전 조건: 없음

주 시나리오:
  1. 사용자가 POST /api/group-lists/get-list-group 을 호출한다.
     JSON body: { "limit": 24, "offset": 0, "gp_code": "..." }
  2. AuthFilter가 EXCLUDED_PATHS 확인 — 통과 (필터 스킵)
  3. GrouplistController::getListGroup() 가 호출된다.
  4. getJsonInput()으로 $data를 수신한다.
  5. GrouplistRepository::getCalleelist($data) — 그룹 소속 상담사 코드 목록 조회
     (tb_grouplist_callee JOIN tb_callee)
  6. 상담사 코드 목록을 $data['callee'] comma-joined string으로 구성한다.
  7. GrouplistRepository::getGrouplist($data) — tb_items JOIN tb_callee 기반 조회
  8. limit+1 trick으로 nextCheck 여부 판단
  9. it_tag comma 분리 → 배열 변환, item_label 구성, 포인트 계산
  10. GrouplistRepository::getGrouplistCount($data) — 총 건수 조회
  11. respondPaginated($items, $total, $perPage, $offset) 반환

대안 시나리오:
  A1. 결과 없음: respondError('INTERNAL', ..., 500) 반환.
  A2. limit='all': 페이지네이션 없이 전체 반환.

사후 조건: 그룹 내 상담사 목록과 페이지네이션 meta가 화면에 표시된다.
```

---

## 6. Endpoint Summary (엔드포인트 요약)

| # | Controller | Method | Path | 설명 | 인증 | CSRF | 응답형식 |
|---|-----------|--------|------|------|------|------|--------|
| 1 | SnsShareController | **POST** | `/api/sns-shares/profile-sns` | 프로필 OG 태그 HTML | 없음 | 면제(공개) | **text/html** |
| 2 | SnsShareController | **POST** | `/api/sns-shares/board-sns` | 게시물 OG 태그 HTML | 없음 | 면제(공개) | **text/html** |
| 3 | GrouplistController | **POST** | `/api/group-lists/get-list-group` | 그룹 목록 조회 (페이지네이션) | 없음 | 면제(공개) | application/json |

**미구현 EP (Routes.php 미등록)**:

| Method | URL (구 SDD 기술) | 상태 |
|--------|-----------------|------|
| GET | `/api/social/groups/{groupId}` | **미구현** — Routes.php에 없음 |
| GET | `/api/social/groups/{groupId}/callees` | **미구현** — Routes.php에 없음 |

> **주의**: EP #1, #2는 표준 JSON API 응답 형식(`{ "data": {} }`)의 예외 케이스이다. EP #3은 공개 EP이다.

---

## 7. Verification Checklist (검증 체크리스트)

| ID | 요건 | 구현 확인 | 테스트 확인 | 비고 |
|----|------|---------|-----------|------|
| FR-SOC-001 | SNS 프로필 HTML 응답 (text/html) | - | - | JSON 아님 주의 |
| FR-SOC-001 | POST 메서드, JSON body 수신 | - | - | GET 아님 주의 |
| FR-SOC-001 | OG 태그 완전성 (6개 필수 태그) | - | - | og:type, title, desc, image, url, site_name |
| FR-SOC-001 | Twitter Card 태그 포함 | - | - | twitter:card |
| FR-SOC-001 | 공개 EP (AuthFilter EXCLUDED_PATHS) | ✓ | - | api/sns-shares/profile-sns 등록 완료 |
| FR-SOC-001 | SnsRepository::getSnsInfo() 사용 | - | - | Member 모듈 의존 |
| FR-SOC-001 | 뷰 경로: locale-aware | - | - | {locale}/Mobile/Pages/Content/ShareSnsProfile |
| FR-SOC-002 | SNS 게시물 HTML 응답 (og:type=article) | - | - | |
| FR-SOC-003 | 그룹 목록 공개 EP (인증 없음) | ✓ | - | EXCLUDED_PATHS 등록 완료 |
| FR-SOC-003 | getCalleelist(array $post) 활용 | - | - | |
| FR-SOC-003 | getGrouplist(array $post) 활용 | - | - | tb_items 기반 |
| FR-SOC-003 | getGrouplistCount(array $post) 활용 | - | - | |
| FR-SOC-003 | nextCheck 로직 (limit+1 trick) | - | - | |
| FR-SOC-003 | it_tag 배열 변환 | - | - | comma 분리 |
| NFR-SOC-001 | POST 수신, HTML echo view() | - | - | |
| NFR-SOC-002 | EXCLUDED_PATHS 등록 확인 | ✓ | - | AuthFilter |
| NFR-SOC-005 | OG 이미지 HTTPS CDN URL | - | - | S3 직접 노출 금지 |

---

## 8. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS |
| v2.1 | 2026-04-21 | jypark | **API SSOT 대조 반영** (SOCIAL-DEF-001~009): EP URL/메서드 전면 수정(GET→POST, /share/*→/api/sns-shares/*, /api/social/groups→/api/group-lists/get-list-group), FR-SOC-003 인증 없음으로 수정, 응답 필드 실제 구현 기준 수정, 미구현 EP 명기, SNS Auth 범위 외 명기(SOCIAL-DEF-009), EXCLUDED_PATHS 현황 반영, UC 흐름 전면 수정, Open Question 3건 명기 |
