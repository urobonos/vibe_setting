---
문서명: social 모듈 API ↔ IEEE 대조 — 2026-04-21
상태: 초안
생성일: 2026-04-21
SSOT 방향: API → IEEE
작성자: jypark (agent: general-purpose, sonnet)
---

# social 모듈 API ↔ IEEE 대조 리포트

## 요약

- EP 수 (md / yaml / Routes / SRS FR): 3 / 3 / 3 / 3
- 9개 항목 판정: ✅ 3 / ⚠ 4 / ❌ 2
- 발견 이슈: 총 14건 (Critical 0 / High 4 / Medium 7 / Low 3)
- 분류: [A] IEEE 업데이트 필요 10건 / [B] API 내부 불일치 4건

---

## 항목별 판정표

| # | 항목 | 판정 | 비고 |
|---|------|------|------|
| 1 | EP 목록 (md ↔ yaml ↔ Routes ↔ SRS FR) | ⚠ | EP 수 일치(3건). 그러나 URL·HTTP 메서드가 API ↔ IEEE 간 전면 불일치 |
| 2 | EP-SRS 매핑 | ❌ | SRS FR URL/메서드가 실제 API와 완전 다름. FR-SOC-003 인증 요건도 불일치 |
| 3 | 인증/CSRF | ⚠ | md 내 Refresh Token Path 오기재. SRS/SDD FR-SOC-003 JWT 필수 vs 실제 공개 EP |
| 4 | X-Forwarded-Proto | ✅ | md·yaml 모두 명세 완비. CLAUDE.md 정책 준수 |
| 5 | 응답 스키마 | ⚠ | md·yaml 응답 스키마는 현실 구현과 다름. IDD 응답 포맷과도 불일치 |
| 6 | 환경별 URL | ✅ | md·yaml 서버 블록에 3개 환경 URL 모두 명세. 일치 |
| 7 | 비즈니스 규칙 (SNS OAuth 콜백·토큰 저장·CSRF 면제) | ❌ | SRS/SDD가 기술하는 EP 구조(GET /share/*)가 실제 구현(POST /api/sns-shares/*)과 전면 불일치. SNS Auth(/api/sns/receive) 미반영 |
| 8 | IDD 매핑 | ⚠ | IDD 인터페이스 계약(메서드 시그니처)이 실제 구현과 다름. GrouplistRepository 5개 메서드 시그니처 전면 불일치 |
| 9 | STD TC 커버리지 | ✅ | 35개 TC 모두 SRS FR/NFR과 추적. SKIP 6건 사유 명시됨. 기존 분류 내 완비 |

---

## 이슈 상세

### [A] IEEE 업데이트 필요

---

#### SOCIAL-DEF-001 [A] — High
**항목**: #1 EP 목록, #2 EP-SRS 매핑  
**대상**: `docs/specs/social-srs.md` (FR-SOC-001, FR-SOC-002, FR-SOC-003)  
**내용**:  
SRS 섹션 6 Endpoint Summary 및 FR 세부 요건에 기술된 URL/HTTP 메서드가 실제 API(SSOT)와 전면 다르다.

| 항목 | SRS 기술 | 실제 API (SSOT) |
|------|----------|----------------|
| FR-SOC-001 메서드·경로 | `GET /share/profile/{userId}` | `POST /api/sns-shares/profile-sns` |
| FR-SOC-002 메서드·경로 | `GET /share/post/{contentId}` | `POST /api/sns-shares/board-sns` |
| FR-SOC-003 메서드·경로 | `GET /api/social/groups` | `POST /api/group-lists/get-list-group` |

SRS가 기술하는 경로 체계(`/share/*`, `/api/social/groups`)는 Routes.php 어디에도 존재하지 않는다. SSOT 방향(API → IEEE)에 따라 SRS FR 섹션 전면 수정 필요.

---

#### SOCIAL-DEF-002 [A] — High
**항목**: #2 EP-SRS 매핑  
**대상**: `docs/specs/social-srs.md` (FR-SOC-003 세부 요건 3.1, 3.2)  
**내용**:  
FR-SOC-003 세부 요건이 인증·응답 구조에서 실제 구현과 다르다.

| 항목 | SRS 기술 | 실제 구현 (SSOT) |
|------|----------|----------------|
| 3.1 경로 | `GET /api/social/groups` | `POST /api/group-lists/get-list-group` |
| 3.2 인증 | JWT 인증 필수 (UNAUTHORIZED 401) | 인증 없음 (공개 EP — md 문서 기준) |
| 3.4 응답 필드 | `groupId, groupName, calleeCount, thumbnailUrl, isActive` | `it_code, it_nick, ce_level, it_tag` 등 레거시 snake_case 필드 |

---

#### SOCIAL-DEF-003 [A] — High
**항목**: #7 비즈니스 규칙  
**대상**: `docs/specs/social-sdd.md` (섹션 3.1, 3.2, 라우트 등록)  
**내용**:  
SDD 섹션 3.1 SnsShareController 설계가 실제 구현과 다르다.

| 항목 | SDD 기술 | 실제 구현 (SSOT) |
|------|----------|----------------|
| 메서드명 | `showProfile(int $userId)` | `profileSns()` — 경로 파라미터 없음 |
| 메서드명 | `showPost(int $contentId)` | `boardSns()` — 경로 파라미터 없음 |
| HTTP 메서드 | GET | POST |
| 경로 패턴 | `/share/profile/{userId}`, `/share/post/{contentId}` | `/api/sns-shares/profile-sns`, `/api/sns-shares/board-sns` |
| 데이터 수신 | 경로 파라미터 `$userId`, `$contentId` | JSON body `getJsonInput()` |
| DB 조회 대상 | `tb_account.ac_nick`, `profile_image_url` | `SnsRepository::getSnsInfo()` — `tb_sns_info` 기반 |
| 뷰 파일 경로 | `Modules\Social\Views\share_profile` | `{locale}/Mobile/Pages/Content/ShareSnsProfile` |

SDD 라우트 등록 코드 예시(섹션 3.1, 3.2)도 전면 교체 필요.

---

#### SOCIAL-DEF-004 [A] — High
**항목**: #7 비즈니스 규칙  
**대상**: `docs/specs/social-sdd.md` (섹션 3.2 GrouplistController), `docs/specs/social-srs.md` (FR-SOC-003)  
**내용**:  
SDD/SRS 기술 GrouplistController 설계가 실제 구현과 다르다.

| 항목 | SDD 기술 | 실제 구현 (SSOT) |
|------|----------|----------------|
| 메서드명 | `getGroupList()` | `getListGroup()` |
| HTTP 메서드 | GET | POST |
| 페이지네이션 파라미터 | `page`, `perPage` (쿼리스트링) | `limit`, `offset` (JSON body) |
| 추가 EP (SDD) | `getGroupDetail`, `getGroupCallees` | 존재하지 않음 (Routes.php에 미등록) |
| 인증 | JWT 필수 `['filter' => 'ratelimit,auth']` | 필터 없음 (Routes.php — 공개 EP) |
| DB 대상 테이블 | `tb_group`, `tb_group_callee` | `tb_items`, `tb_callee`, `tb_grouplist_callee`, `tb_grouplist_opt` |

---

#### SOCIAL-DEF-005 [A] — Medium
**항목**: #8 IDD 매핑  
**대상**: `docs/specs/social-idd.md` (섹션 2.1 GrouplistRepositoryInterface)  
**내용**:  
IDD에 정의된 `GrouplistRepositoryInterface` 5개 메서드 시그니처가 실제 구현체와 다르다.

| 메서드 | IDD 정의 | 실제 구현 (SSOT) |
|--------|----------|----------------|
| `getGroupBanner()` | `getGroupBanner(): array` (파라미터 없음) | `getGroupBanner(string $st_code='hongcafe', string $bn_link=''): array` |
| `getGroupInfo()` | `getGroupInfo(int $groupId): ?array` | `getGroupInfo(string $gp_code=''): array` (타입·이름·반환형 다름) |
| `getCalleelist()` | `getCalleelist(int $groupId): array` | `getCalleelist(array $post): array` |
| `getGrouplist()` | `getGrouplist(int $page=1, int $perPage=20): array` | `getGrouplist(array $post): array` |
| `getGrouplistCount()` | `getGrouplistCount(): int` | `getGrouplistCount(array $post): int` |

IDD 인터페이스 계약을 실제 구현 기준으로 전면 업데이트 필요.

---

#### SOCIAL-DEF-006 [A] — Medium
**항목**: #8 IDD 매핑  
**대상**: `docs/specs/social-idd.md` (섹션 4.1 그룹 목록 응답 포맷)  
**내용**:  
IDD 섹션 4.1~4.2 응답 포맷이 실제 API 응답 및 md 문서와 다르다.

- IDD 기술: `groupId, groupName, calleeCount, thumbnailUrl, isActive, itemLabels, createdAt, updatedAt`
- 실제 API md 기술: `groupCode, groupName, points, labels, items` + `meta.pagination`
- 실제 구현 (`GrouplistController.php`): `it_code, it_nick, it_tag, ce_level` 등 레거시 snake_case 필드

IDD 응답 포맷 섹션을 API md(SSOT) 기준으로 수정 필요.

---

#### SOCIAL-DEF-007 [A] — Medium
**항목**: #5 응답 스키마  
**대상**: `docs/specs/social-srs.md` (FR-SOC-003 출력 스펙)  
**내용**:  
SRS FR-SOC-003 출력 JSON 예시(`groupId, groupName, calleeCount, thumbnailUrl, isActive, itemLabels`)가 API md(SSOT) 응답 필드(`groupCode, groupName, points, labels, items`)와 다르다. SRS 출력 스펙을 API md 기준으로 교체 필요.

---

#### SOCIAL-DEF-008 [A] — Medium
**항목**: #2 EP-SRS 매핑, #7 비즈니스 규칙  
**대상**: `docs/specs/social-srs.md` (섹션 2.3 User Classes, 섹션 2.6 전제), `docs/specs/social-sdd.md`  
**내용**:  
SRS 섹션 2.3 사용자 분류 표에 "Caller(일반 사용자) — JWT 인증 완료 — 그룹 목록 조회"로 기재되어 있으나, 실제 `/api/group-lists/get-list-group`은 공개 EP(인증 없음)이다. SRS 섹션 2.6 전제 사항(`tb_group`, `tb_group_callee` 테이블)도 실제 조회 대상 테이블(`tb_items`, `tb_callee`, `tb_grouplist_callee`, `tb_grouplist_opt`)과 다르다.

---

#### SOCIAL-DEF-009 [A] — Medium
**항목**: #7 비즈니스 규칙 — SNS Auth 미반영  
**대상**: `docs/specs/social-srs.md`, `docs/specs/social-sdd.md`, `docs/specs/social-idd.md`, `docs/specs/social-std.md`  
**내용**:  
최근 커밋 `57f95e6 feat(sns-auth): /api/sns/receive 신설 + SnsAuthService`가 **Social 모듈이 아닌 Auth 모듈**(`app/Modules/Auth/Controllers/SnsController.php`, `app/Modules/Member/Services/SnsAuthService.php`)로 구현되었다. Social 모듈 IEEE 산출물에 반영 불필요. 단, 해당 EP가 Social 모듈의 SNS 관련 기능과 관계가 있음을 명확히 하기 위해 SRS 섹션 1.2 Scope 범주를 명시적으로 확인·유지할 필요가 있다. 현재 SRS Scope는 "SNS 공유(HTML 응답)"와 "그룹 목록 조회"만을 다루고 있어, SNS OAuth(/api/sns/receive)는 Auth·Member 모듈 소관임을 명기하는 것이 권장된다. Social IEEE 문서 수정 불필요이지만 Scope 주석 추가 권장.

---

#### SOCIAL-DEF-010 [A] — Low
**항목**: #7 비즈니스 규칙  
**대상**: `docs/specs/social-sdd.md` (섹션 2 Module Structure)  
**내용**:  
SDD 모듈 구조 다이어그램에 `Views/share_profile.php`, `Views/share_post.php` 파일이 명시되어 있으나, 실제 뷰 파일은 `{locale}/Mobile/Pages/Content/ShareSnsProfile` (locale-aware 경로)에 위치한다. SDD 뷰 파일 경로 섹션 수정 필요.

---

### [B] API 내부 불일치

---

#### SOCIAL-DEF-011 [B] — Medium
**항목**: #3 인증/CSRF  
**대상**: `api-docs/social/social-api.md` (JWT 인증 섹션)  
**내용**:  
md 문서 JWT 인증 표의 Refresh Token `Path` 필드가 `/api/auth/refresh`로 기재되어 있다. CLAUDE.md 정책(최근 커밋 `a7be0b5` fix: Refresh Token Path를 `/`로 확대)에 따라 Path는 `/`여야 한다.

| 항목 | md 기재 | CLAUDE.md 정책 (SSOT) |
|------|---------|----------------------|
| Refresh Token Path | `/api/auth/refresh` | `/` |

---

#### SOCIAL-DEF-012 [B] — Medium
**항목**: #5 응답 스키마  
**대상**: `api-docs/social/social-api.md`, `api-docs/social/social-api.yaml`  
**내용**:  
API 문서가 기술하는 그룹 목록 응답 스키마(`groupCode, groupName, points, labels, items` + `meta.pagination.currentPage` 등)와 실제 구현(`GrouplistController.php`)이 반환하는 필드(`it_code, it_nick, it_tag, ce_level` 등 레거시 snake_case)가 전혀 다르다. API 문서가 이상적 설계를 기술하고 있고 실제 코드는 레거시 구현임. 이는 마이그레이션 미완료 상태에서 발생한 API 문서 선행 작성으로 판단된다. 레거시 코드 마이그레이션 전까지 API 문서에 "설계 대상" 명기 또는 실제 응답 필드로 문서 수정 중 하나를 선택해야 한다.

---

#### SOCIAL-DEF-013 [B] — Low
**항목**: #1 EP 목록  
**대상**: `api-docs/social/social-api.md`, `api-docs/social/social-api.yaml`  
**내용**:  
API md·yaml 모두 3개 EP(`POST /api/sns-shares/profile-sns`, `POST /api/sns-shares/board-sns`, `POST /api/group-lists/get-list-group`)를 "인증: 불필요 (공개)"로 표기하고 있다. Routes.php도 필터 없이 등록되어 있으므로 일치한다. 다만, md 문서 상단 Base URL 표기가 `/api/sns-shares`, `/api/group-lists`로 두 개로 분리 기재되어 있어, OpenAPI YAML의 단일 서버 블록과 서술 스타일이 혼재한다. 문서 개선 권장 (blocking 이슈 아님).

---

#### SOCIAL-DEF-014 [B] — Low
**항목**: #5 응답 스키마  
**대상**: `api-docs/social/social-api.md`, `api-docs/social/social-api.yaml`  
**내용**:  
API 문서의 페이지네이션 meta 응답 구조가 md(`meta.pagination.currentPage`) vs CLAUDE.md 표준(`meta.currentPage` — 중첩 없음)과 다르다. CLAUDE.md 페이지네이션 규칙: `{ "data": [], "meta": { "currentPage", "perPage", "total", "lastPage" } }`. API 문서의 `meta.pagination` 중첩 구조는 CLAUDE.md 표준 위반이다.

---

## 엔드포인트 매트릭스

| # | Method | URL (API md/yaml/Routes) | 인증 (API) | SRS FR | SRS URL | 불일치 |
|---|--------|--------------------------|-----------|--------|---------|--------|
| 1 | POST | `/api/sns-shares/profile-sns` | — (공개) | FR-SOC-001 | `GET /share/profile/{userId}` | 메서드·경로 불일치 |
| 2 | POST | `/api/sns-shares/board-sns` | — (공개) | FR-SOC-002 | `GET /share/post/{contentId}` | 메서드·경로 불일치 |
| 3 | POST | `/api/group-lists/get-list-group` | — (공개) | FR-SOC-003 | `GET /api/social/groups` | 메서드·경로·인증 불일치 |

**SDD 등록 EP (미구현/미등록)**:

| Method | URL (SDD 기술) | Routes.php 존재 여부 |
|--------|---------------|---------------------|
| GET | `/api/social/groups/{groupId}` | 없음 |
| GET | `/api/social/groups/{groupId}/callees` | 없음 |

---

## SNS Auth 커밋 (`57f95e6`) Social 모듈 포함 여부 확인

| 확인 항목 | 결과 |
|----------|------|
| `app/Modules/Social/` 변경 여부 | **없음** — Social 모듈 파일 미포함 |
| 실제 변경 모듈 | `Auth`, `Member`, `Shared` |
| Social IEEE 반영 필요 여부 | **불필요** — Auth 모듈 소관 |
| 권장 조치 | SRS-SOCIAL-001 섹션 1.2 Scope에 "/api/sns/receive는 Auth 모듈 소관" 주석 추가 (SOCIAL-DEF-009) |

---

## Open Questions

| # | 질문 | 관련 이슈 |
|---|------|----------|
| OQ-1 | `/api/group-lists/get-list-group`은 현재 공개 EP(필터 없음)로 구현되어 있다. SRS/SDD는 JWT 인증 필수로 설계했다. 실제 프로덕션 인텐트는 공개인가, JWT 필수인가? Routes.php에 auth 필터 추가가 필요한가? | SOCIAL-DEF-002, SOCIAL-DEF-004 |
| OQ-2 | `GrouplistController::getListGroup()`의 응답 필드가 레거시 snake_case(`it_code`, `it_nick` 등)이다. API 문서 기준 신규 camelCase(`groupCode`, `groupName`)로 마이그레이션 계획이 있는가? 완료 전까지 API 문서를 현실 구현 기준으로 롤백할지, 또는 설계 목표(TO-BE)로 유지할지 결정 필요. | SOCIAL-DEF-012 |
| OQ-3 | SRS/SDD가 기술하는 View 파일 구조(`Modules/Social/Views/share_profile.php`, `share_post.php`)와 실제 locale 기반 경로(`{locale}/Mobile/Pages/Content/ShareSnsProfile`)가 다르다. 신규 모듈 전환 계획이 있는가? | SOCIAL-DEF-003, SOCIAL-DEF-010 |
| OQ-4 | `GrouplistRepository` 인터페이스(`GrouplistRepositoryInterface`)는 IDD 정의와 실제 구현 시그니처가 모두 다르다. 인터페이스를 실제 구현에 맞게 수정해야 하는가, 아니라면 구현체를 인터페이스에 맞게 리팩토링할 계획인가? | SOCIAL-DEF-005 |
| OQ-5 | API 문서 meta 페이지네이션 중첩(`meta.pagination.currentPage`)이 CLAUDE.md 표준(`meta.currentPage` 플랫 구조)과 다르다. API 문서를 CLAUDE.md 표준에 맞춰 수정하는가, 아니면 Social 모듈은 예외 적용인가? | SOCIAL-DEF-014 |
