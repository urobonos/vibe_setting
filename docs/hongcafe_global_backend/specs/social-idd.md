---
문서명: Social 모듈 인터페이스 설계 문서 (IDD)
문서ID: IDD-SOCIAL-001
버전: v2.1
적용 표준: MIL-STD-498
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
대상 시스템: HongCafe Global Backend — Social Module
관련 문서:
  - social-srs.md (SRS-SOCIAL-001)
  - social-sdd.md (SDD-SOCIAL-001)
  - docs/api-specification.md
---

# IDD-SOCIAL-001: Social 모듈 인터페이스 설계 문서

> **MIL-STD-498** 준수 — Interface Design Description
> Social 모듈의 내부 인터페이스(GrouplistRepositoryInterface),
> HTML 응답 특성, 데이터 포맷, 에러 코드, 모듈 간 의존성을 정의한다.

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 MIL-STD-498 IDD(Interface Design Description) 표준에 따라 Social 모듈의 모든 인터페이스를 명세한다. 내부 PHP 인터페이스, HTML 응답 계약, 데이터 포맷, DI 등록을 포함한다.

### 1.2 Scope (범위)

| 인터페이스 유형 | 항목 | 방향 |
|--------------|------|------|
| 내부 (PHP Interface) | `GrouplistRepositoryInterface` | GrouplistController → Repository |
| 응답 형식 예외 | SnsShareController HTML 응답 | Client ← SnsShareController |
| 모듈 간 의존 | `SnsRepository` (Member 모듈) | SnsShareController → Member 모듈 |
| 외부 시스템 | 없음 | Social 모듈은 외부 API 의존성 없음 |

**핵심 특성**: Social 모듈은 외부 API 의존성이 없다. SNS 공유 EP가 HTML을 반환한다는 점이 가장 중요한 인터페이스 특성이다.

**SNS Auth 범위 외**: `/api/sns/receive` (SNS OAuth 인증)는 **Auth 모듈** 소관이다. Social 모듈 인터페이스와 무관하다.

### 1.3 References (참조 문서)

| 문서 | 설명 |
|------|------|
| MIL-STD-498 | Software Development and Documentation |
| SRS-SOCIAL-001 | Social 모듈 소프트웨어 요구사항 명세서 |
| SDD-SOCIAL-001 | Social 모듈 소프트웨어 설계 문서 |
| CLAUDE.md | 프로젝트 보안 정책 및 DI 등록 규칙 |
| Open Graph Protocol | https://ogp.me — OG 메타태그 표준 |

---

## 2. Internal Interface Definitions (내부 인터페이스 정의)

### 2.1 GrouplistRepositoryInterface

**파일**: `app/Modules/Social/Interfaces/GrouplistRepositoryInterface.php`
**구현체**: `GrouplistRepository`
**DI 등록**: `app/Modules/Social/Config/Services.php`
**메서드 수**: 5개 (인터페이스 정의, CRUD 메서드 별도)

```php
<?php

declare(strict_types=1);

namespace App\Modules\Social\Interfaces;

use App\Modules\Shared\Interfaces\BaseRepositoryInterface;

interface GrouplistRepositoryInterface extends BaseRepositoryInterface
{
    /**
     * 그룹 목록 상단 배너 정보 조회.
     *
     * tb_banner에서 bn_position='main', bn_view='Y' 조건으로 조회.
     *
     * @param  string $st_code 사이트 코드 (기본값: 'hongcafe')
     * @param  string $bn_link 배너 링크 (기본값: '')
     * @return array<int, object> 배너 목록
     */
    public function getGroupBanner(string $st_code = 'hongcafe', string $bn_link = ''): array;

    /**
     * 그룹 코드로 그룹 옵션 정보 조회.
     *
     * tb_grouplist_opt 기반. gpt_status='ON' 조건.
     *
     * @param  string $gp_code 그룹 코드 (기본값: '')
     * @return array<int, object> 그룹 옵션 레코드 목록
     */
    public function getGroupInfo(string $gp_code = ''): array;

    /**
     * 그룹 소속 상담사 코드 목록 조회.
     *
     * tb_grouplist_callee JOIN tb_callee 쿼리.
     * gp_code, ce_level >= 0, gp_use='ON' 조건.
     *
     * @param  array $post 요청 데이터 (gp_code 포함)
     * @return array<int, array<string, mixed>> it_code 목록
     */
    public function getCalleelist(array $post): array;

    /**
     * 상담사(아이템) 목록 조회 (페이지네이션).
     *
     * tb_items AS it LEFT JOIN tb_callee AS ce.
     * it_status=3, ce_status=3 기본 필터.
     * limit+1로 조회하여 nextCheck 판단에 사용.
     *
     * @param  array $post 요청 데이터 (limit, offset, st_code, callee, on_flag, order 등)
     * @return array<int, object> 상담사 목록
     */
    public function getGrouplist(array $post): array;

    /**
     * 상담사(아이템) 전체 건수 조회 (페이지네이션 meta용).
     *
     * tb_items AS it LEFT JOIN tb_callee AS ce.
     * getGrouplist()와 동일한 필터 조건 적용.
     *
     * @param  array $post 요청 데이터 (st_code, callee, on_flag 등)
     * @return int 조건에 맞는 아이템 총 건수
     */
    public function getGrouplistCount(array $post): int;
}
```

> **변경 이유 (SOCIAL-DEF-005)**: v2.0의 IDD는 `getGroupBanner(): array` (파라미터 없음), `getGroupInfo(int $groupId)`, `getCalleelist(int $groupId)`, `getGrouplist(int $page=1, int $perPage=20)`, `getGrouplistCount(): int` (파라미터 없음)으로 정의했다. 실제 인터페이스 파일(`GrouplistRepositoryInterface.php`)의 시그니처는 위와 같다. SSOT에 맞춰 전면 수정.

**메서드 계약 요약**:

| 메서드 | 파라미터 | 반환형 | 예외/에러 조건 |
|--------|---------|--------|--------------|
| `getGroupBanner(string, string)` | st_code, bn_link | `array` | `DatabaseException` — DB 오류 |
| `getGroupInfo(string)` | gp_code | `array` | `DatabaseException` — DB 오류; 빈 배열 정상 반환 |
| `getCalleelist(array)` | post (gp_code 포함) | `array` | `DatabaseException` — DB 오류; 빈 배열 정상 반환 |
| `getGrouplist(array)` | post (limit, offset 등) | `array` | `DatabaseException` — DB 오류; 빈 배열 정상 반환 |
| `getGrouplistCount(array)` | post | `int` | `DatabaseException` — DB 오류; 0 정상 반환 |

> **Open Question (OQ-4)**: v2.0 IDD의 `GrouplistRepositoryInterface` 시그니처와 실제 인터페이스 파일이 불일치했다. 현재 인터페이스 파일(SSOT)이 `array $post` 패턴으로 이미 구현에 맞게 정의되어 있다. 추가 리팩토링 여부 확인 불필요.

---

## 3. SnsShareController Interface Characteristics (응답 형식 계약)

### 3.1 HTML 응답 반환 — JSON 응답 아님

`SnsShareController`는 Repository 인터페이스를 사용하지 않는다. Member 모듈의 `SnsRepository`를 통해 `tb_sns_info` 데이터를 조회하고 CI4 `echo view()` 함수로 HTML 뷰를 렌더링한다.

**중요 설계 결정**: SnsShareController의 응답 형식은 표준 JSON API와 다르다.

| 항목 | 표준 JSON API EP | SNS 공유 EP |
|------|----------------|------------|
| HTTP 메서드 | POST/GET/PUT/DELETE | **POST** |
| Content-Type | `application/json` | `text/html` |
| 응답 형식 | `{"data": {...}}` | HTML 문서 |
| 에러 응답 형식 | `{"error": {"code": ...}}` | HTML 에러 페이지 (또는 없음) |
| 인증 | JWT 필수 (경우에 따라) | 없음 (공개, EXCLUDED_PATHS) |
| CSRF | POST/PUT/DELETE 필수 | 면제 (EXCLUDED_PATHS 통과) |
| 사용 목적 | 앱/프론트엔드 통신 | SNS 크롤러 OG 태그 수집 |
| 반환 방식 | return $this->respond... | echo view() + void |

### 3.2 SnsShareController 의존성 구조

```
SnsShareController
  ├─> service('snsRepository')  ── DI ──→ SnsRepository (Member 모듈)
  │     └──→ SnsModel (tb_sns_info, Social 모듈 내 파일)
  │           └──→ Aurora MySQL (tb_sns_info)
  │
  └─> echo view("{locale}/Mobile/Pages/Content/ShareSnsProfile", $data)
      echo view("{locale}/Mobile/Pages/Content/ShareSnsBoard", $data)
              └──→ text/html 응답
```

`SnsShareController`는 GrouplistRepositoryInterface를 사용하지 않는다.

### 3.3 뷰 데이터 인터페이스 (PHP array → view)

```php
// profileSns() → view("{locale}/.../ShareSnsProfile", $data) 전달 구조
// $data = array_merge($post, $snsInfo)
// $post: POST JSON body (클라이언트 전송 데이터)
// $snsInfo: SnsRepository::getSnsInfo() 반환값 (sns_type 키 기반 연관 배열)
```

- 뷰 파일이 수신하는 데이터 구조는 `$post`와 `$snsInfo`의 merge 결과이다.
- 뷰 파일 내 모든 동적 출력 값은 `esc()` 함수로 XSS를 방지한다.

---

## 4. Data Format Definitions (데이터 포맷 정의)

### 4.1 그룹 목록 응답 포맷 (JSON — 현재 구현 기준)

> **변경 이유 (SOCIAL-DEF-006)**: v2.0 IDD는 `groupId`, `groupName`, `calleeCount`, `thumbnailUrl`, `isActive`, `itemLabels`, `createdAt`, `updatedAt` camelCase 필드를 기술했다. 실제 구현은 `tb_items` 기반 레거시 snake_case 필드를 반환한다.

```json
{
  "data": [
    {
      "it_code": "IT001",
      "it_nick": "상담사명",
      "ce_level": 1,
      "it_tag": ["タロット", "占い"],
      "item_label": { "partner": "파트너", "new": "신규" },
      "it_online": "on",
      "ca_status": "standby",
      "view_tag": "최근 3개월",
      "view_win_point": 4.5,
      "view_win_comment": 120
    }
  ],
  "meta": {
    "currentPage": 1,
    "perPage": 24,
    "total": 100,
    "lastPage": 5
  },
  "nextCheck": false
}
```

> **Open Question (OQ-2)**: 현재 응답 필드는 레거시 snake_case 기반이다. API 문서(`groupCode`, `groupName` 등 camelCase)는 TO-BE 목표를 기술한다. 마이그레이션 완료 전까지 두 표기가 공존한다. 마이그레이션 계획 및 전환 시점 확인 필요.

### 4.2 미구현 EP 응답 포맷

구 IDD v2.0에 정의된 "그룹 상세 응답 포맷"(`groupId`, `callees` 포함)은 **미구현 EP**(`/api/social/groups/{groupId}`)에 해당한다. Routes.php에 등록되지 않았으며 구현체가 없다. 해당 포맷 정의는 삭제한다.

> **Open Question**: `GrouplistController::getGroupDetail`, `getGroupCallees` EP 구현 계획 확인 필요.

### 4.3 SNS 공유 응답 포맷 (HTML)

프로필 공유 HTML 응답 (HTTP 200):
```html
<!DOCTYPE html>
<html lang="{locale}">
<head>
  <meta charset="UTF-8">
  <!-- Open Graph Protocol (https://ogp.me) -->
  <meta property="og:type"        content="profile">
  <meta property="og:title"       content="{displayName} | HongCafe">
  <meta property="og:description" content="{profileDescription}">
  <meta property="og:image"       content="{cdnImageUrl}">
  <meta property="og:url"         content="https://prd.gl.hongcafe.com/...">
  <meta property="og:site_name"   content="HongCafe">
  <!-- Twitter Card -->
  <meta name="twitter:card"       content="summary_large_image">
  <meta name="twitter:title"      content="{displayName} | HongCafe">
  <meta name="twitter:description" content="{profileDescription}">
  <meta name="twitter:image"      content="{cdnImageUrl}">
  <title>{displayName} | HongCafe</title>
</head>
<body>
  <script>window.location.href = '{frontendProfileUrl}';</script>
</body>
</html>
```

### 4.4 DB → API 필드 매핑 (현재 구현 기준)

#### tb_items 주요 응답 필드

| DB 컬럼 (snake_case) | 응답 키 | 변환 처리 |
|---------------------|--------|---------|
| `it_code` | `it_code` | 그대로 |
| `it_nick` | `it_nick` | 그대로 |
| `ce_level` | `ce_level` | 그대로 |
| `it_tag` | `it_tag` | comma 분리 → 배열 |
| `it_counsel_field` | `it_counsel_field` | json_decode() |
| `it_counsel_field_search` | `it_counsel_field_search` | comma 분리 → 배열 |
| (계산) | `item_label` | `{partner, new}` 조건 기반 |
| (계산) | `view_tag` | "최근 3개월" 고정 |
| (계산) | `view_win_point` | m3_cm_point5 |
| (계산) | `view_win_comment` | m3_cm_cnt_num |

> **이행 목표 (TO-BE)**: API 문서에서는 `groupCode`, `groupName`, `points`, `labels`, `items` camelCase 필드를 목표로 기술하고 있다. 마이그레이션 완료 시 camelCase 표기로 전환 예정.

---

## 5. Error Code Definitions (에러 코드 정의)

### 5.1 Social 모듈 에러 코드 목록

| HTTP 상태코드 | 에러 코드 | 발생 상황 | 대상 Controller | 응답 형식 |
|-------------|---------|---------|----------------|--------|
| 500 | `INTERNAL` | 그룹 목록 조회 실패 (빈 결과) | GrouplistController | JSON |
| 200 | (없음) | SNS 공유 정상 응답 | SnsShareController | **HTML** |

> **변경 이유**: v2.0 IDD에는 `UNAUTHORIZED (401)`, `NOT_FOUND (404)` 에러 코드가 GrouplistController에 정의되어 있었다. 실제 구현은 공개 EP이므로 401이 발생하지 않으며, 404 처리도 구현되지 않았다. 현재 구현 기준 `INTERNAL (500)` 에러만 존재한다.

### 5.2 JSON 에러 응답 포맷 (GrouplistController)

```json
{
  "error": {
    "code": "INTERNAL",
    "message": "에러 메시지 (lang() 키 기반)"
  }
}
```

### 5.3 HTML 에러 응답 (SnsShareController)

SNS 공유 EP는 에러 시에도 HTML을 반환한다. 현재 구현에서 명시적 404 처리 코드는 없으며, 뷰 렌더링 결과에 따라 출력이 결정된다.

**원칙**: SnsShareController는 어떠한 경우에도 JSON을 반환하지 않는다.

---

## 6. DI Registration (의존성 주입 등록)

### 6.1 GrouplistRepository DI

**파일**: `app/Modules/Social/Config/Services.php`

```php
<?php

declare(strict_types=1);

namespace App\Modules\Social\Config;

use CodeIgniter\Config\BaseService;
use App\Modules\Social\Interfaces\GrouplistRepositoryInterface;
use App\Modules\Social\Repositories\GrouplistRepository;

class Services extends BaseService
{
    public static function grouplistRepository(bool $getShared = true): GrouplistRepositoryInterface
    {
        if ($getShared) {
            return static::getSharedInstance('grouplistRepository');
        }

        return new GrouplistRepository();
    }
}
```

### 6.2 SnsRepository DI (Member 모듈 소관)

`SnsShareController`에서 `service('snsRepository')`로 사용하지만, DI 등록은 **Member 모듈**(`app/Modules/Member/Config/Services.php`)에서 관리한다. Social 모듈의 `Services.php`에는 등록하지 않는다.

**원칙**:
- 중앙 `app/Config/Services.php`에 바인딩 금지 — 모듈별 분산 등록 강제
- `SnsShareController`의 `snsRepository` 의존은 Member 모듈 Services를 통해 해소된다

---

## 7. Module Dependencies (모듈 간 의존성)

### 7.1 Social 모듈 → 타 모듈 의존성

| 의존 방향 | 대상 모듈 | 방식 | 용도 |
|---------|---------|------|------|
| Social(SnsShare) → Member | `service('snsRepository')` DI | SNS 설정 정보(`tb_sns_info`) 조회 |

### 7.2 타 모듈 → Social 모듈 의존성

Social 모듈을 직접 의존하는 타 모듈은 없다. SNS 공유 기능은 프론트엔드 또는 직접 URL 접근으로만 트리거된다.

**참고**: `SnsModel` 파일은 `app/Modules/Social/Models/SnsModel.php`에 위치하지만, 이를 사용하는 `SnsRepository`는 Member 모듈에 있다. 파일 위치 ≠ 모듈 소속.

### 7.3 의존성 다이어그램

```
[SNS Crawler / Browser (POST)]
  └──→ SnsShareController ──(service() DI)──→ SnsRepository (Member 모듈)
                              │                    └──→ SnsModel (tb_sns_info)
                              │                          └──→ Aurora MySQL
                              └──(echo view())──→ {locale}/Mobile/Pages/Content/
                                                       └──→ text/html 응답

[Client (POST, 비인증)]
  └──→ GrouplistController ──(service() DI)──→ GrouplistRepositoryInterface
                                                    └──→ GrouplistRepository
                                                          ├──→ tb_items + tb_callee
                                                          ├──→ tb_grouplist_callee
                                                          ├──→ tb_grouplist_opt
                                                          └──→ tb_banner
                                                                └──→ application/json 응답
```

---

## 8. Security Interface Contracts (보안 인터페이스 계약)

### 8.1 XSS 방지 계약 (뷰 파일)

뷰 파일(`{locale}/Mobile/Pages/Content/ShareSnsProfile`, `ShareSnsBoard`) 내 동적 출력 값은 CI4 `esc()` 함수를 통해 HTML 이스케이프된다.

```php
// 올바른 사용 (XSS 방지)
<meta property="og:title" content="<?= esc($ogTitle) ?>">

// 잘못된 사용 (XSS 취약)
<meta property="og:title" content="<?= $ogTitle ?>">
```

### 8.2 OG 이미지 URL 보안 계약

| 항목 | 계약 |
|------|------|
| 프로토콜 | HTTPS 필수 (HTTP URL 허용 금지) |
| 도메인 | CDN(CloudFront) 도메인만 허용 |
| S3 직접 URL | 노출 금지 (`amazonaws.com` URL 사용 금지) |
| 미존재 이미지 | 기본 placeholder 이미지 URL로 대체 |

### 8.3 SNS 공유 EP 공개 접근 보안 계약

| 항목 | 계약 |
|------|------|
| 공개 데이터 | SNS 설정 정보 + 요청 body 병합 결과 |
| 민감정보 | 이메일, 전화번호, 결제정보 노출 금지 |
| EXCLUDED_PATHS | `api/sns-shares/profile-sns`, `api/sns-shares/board-sns` 등록 완료 |

---

## 9. Interface Checklist (인터페이스 체크리스트)

| 항목 | 확인 | 비고 |
|------|------|------|
| GrouplistRepositoryInterface 5개 메서드 — array $post 시그니처 | ✓ | 실제 인터페이스 파일 확인 완료 |
| getGroupBanner(string $st_code, string $bn_link) | ✓ | |
| getGroupInfo(string $gp_code) | ✓ | |
| getCalleelist(array $post) | ✓ | |
| getGrouplist(array $post) | ✓ | |
| getGrouplistCount(array $post) | ✓ | |
| DI 바인딩 (모듈별 Services.php) | ✓ | 중앙 등록 금지 |
| SnsRepository DI — Member 모듈 소관 명기 | ✓ | |
| SnsShareController HTML 응답 계약 명시 (POST, echo view) | ✓ | JSON 응답 금지 |
| 뷰 경로 locale-aware | ✓ | {locale}/Mobile/Pages/Content/ |
| SNS 공유 에러 시 HTML 반환 (JSON 에러 반환 금지) | - | |
| OG 이미지 HTTPS CDN URL 강제 | - | S3 직접 노출 금지 |
| AuthFilter EXCLUDED_PATHS 등록 완료 | ✓ | AuthFilter.php 확인 |
| 미구현 EP (getGroupDetail, getGroupCallees) 명기 | ✓ | |
| SNS Auth (/api/sns/receive) 범위 외 명기 | ✓ | Auth 모듈 소관 |
| 에러 메시지 lang() 키 사용 (GrouplistController) | - | 하드코딩 금지 |
| 외부 시스템 의존성 없음 확인 | ✓ | FCM, 외부 API 없음 |
| 역방향 의존성 없음 확인 | ✓ | 타 모듈이 Social에 의존 없음 |

---

## 10. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-15 | jypark | 최초 작성 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS |
| v2.1 | 2026-04-21 | jypark | **API SSOT 대조 반영** (SOCIAL-DEF-005,006,009): GrouplistRepositoryInterface 5개 메서드 시그니처 전면 수정(int→string/array $post 패턴), 응답 포맷 실제 구현 기준 수정(groupId→it_code 등 snake_case), 미구현 EP 응답 포맷 삭제, SnsRepository(Member모듈) 의존 추가, HTTP메서드 POST 명기, 뷰 경로 locale-aware 수정, 에러 코드 수정(401/404→INTERNAL만), SNS Auth 범위 외 명기, Open Question 2건 명기 |
