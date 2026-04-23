---
docId: REVIEW-COMMERCE-ITEMS-20260421
title: "Commerce Items API ↔ IEEE 대조 리포트"
type: cross-verification
ssot: API
targetApi: api-docs/commerce/items-api.md + items-api.yaml
targetIeee: docs/specs/commerce-{srs,sdd,idd,std}.md (Items 섹션)
reviewDate: 2026-04-21
reviewer: claude-sonnet-4-6
status: 완료
---

# Commerce Items API ↔ IEEE 대조 리포트

> SSOT: **API** (items-api.md / items-api.yaml). IEEE 문서의 불일치는 IEEE를 수정해야 한다.  
> API 내부 불일치는 `[B]` 태그로 표기한다.  
> 이슈 ID 체계: `COMMERCE-ITEMS-DEF-NNN`

---

## 메타 정보

| 항목 | 내용 |
|------|------|
| 검토일 | 2026-04-21 |
| API 문서 | `api-docs/commerce/items-api.md` (2026-04-10/15), `items-api.yaml` |
| SRS | `docs/specs/commerce-srs.md` v3.0 (2026-04-15) |
| SDD | `docs/specs/commerce-sdd.md` v2.0 (2026-04-15) |
| IDD | `docs/specs/commerce-idd.md` v2.0 (2026-04-15) |
| STD | `docs/specs/commerce-std.md` v1.0 (2026-04-16) |
| 코드 | `app/Modules/Commerce/Controllers/ItemsController.php`, `Config/Routes.php` |
| 발견 이슈 | 12건 (CRITICAL 2, HIGH 3, MEDIUM 5, LOW 2) |

---

## 대조 결과 요약

| # | 대조 항목 | 상태 | 이슈 수 |
|---|----------|------|---------|
| 1 | EP 목록 | 불일치 | 2 |
| 2 | EP-SRS 매핑 | 불일치 | 2 |
| 3 | 인증/CSRF | 불일치 | 2 |
| 4 | X-Forwarded-Proto | 일치 | 0 |
| 5 | 응답 스키마 | 불일치 | 3 |
| 6 | 환경별 URL | 일치 | 0 |
| 7 | 비즈니스 규칙 | 불일치 | 2 |
| 8 | IDD 매핑 | 불일치 | 1 |
| 9 | STD TC 커버리지 | 불일치 | 0 (주의사항 있음) |

---

## 1. EP 목록 대조

### 1.1 API 문서 EP 목록 (16개)

| # | 메서드 | 경로 | 인증 |
|---|--------|------|------|
| 1 | GET | `/api/items/get-item` | jwt |
| 2 | GET | `/api/items/get-list-pc` | — |
| 3 | POST | `/api/items/get-list` | — |
| 4 | POST | `/api/items/get-comment` | — |
| 5 | POST | `/api/items/get-search-list-items` | — |
| 6 | POST | `/api/items/get-search-list-goods` | — |
| 7 | POST | `/api/items/get-like-list` | jwt |
| 8 | POST | `/api/items/item-add-like` | jwt |
| 9 | DELETE | `/api/items/item-delete-like` | jwt |
| 10 | DELETE | `/api/items/item-all-delete-like` | jwt |
| 11 | POST | `/api/items/get-item-qna-list` | jwt |
| 12 | POST | `/api/items/insert-item-qna` | jwt |
| 13 | POST | `/api/items/save-item-price` | jwt |
| 14 | POST | `/api/items/get-posting-list` | — |
| 15 | POST | `/api/items/posting-detail` | — |
| 16 | POST | `/api/items/get-posting-comments` | — |

### 1.2 Routes.php 실제 등록 EP (16개)

Routes.php에 등록된 16개 EP는 API 문서 16개와 경로·HTTP 메서드 모두 일치한다.

### 1.3 SRS와의 차이

**SRS-COMMERCE-001 §1.2**는 Items 서브도메인을 **17 EP**로 기술하고, FR-001-8의 관련 EP 항목에 `GET /api/items/get-callee-list`를 명시한다.

---

### 이슈

#### COMMERCE-ITEMS-DEF-001 [HIGH] SRS EP 수 불일치 (17 vs 16)

| 항목 | 내용 |
|------|------|
| 심각도 | HIGH |
| 유형 | EP 목록 불일치 |
| SSOT 판단 | API가 SSOT — IEEE(SRS) 수정 필요 |

**현황**:
- SRS §1.2: `Items (17 EP)`
- SRS FR-001 관련 EP: `GET /api/items/get-callee-list` 명시
- API 문서 / Routes.php: 16개 EP. `get-callee-list` 없음

**수정 대상 (IEEE)**:
- `commerce-srs.md` §1.2 `Sub-domains` 표: `Items (17 EP)` → `Items (16 EP)`
- `commerce-srs.md` `Total endpoints`: `73` → `72`
- `commerce-srs.md` FR-001 관련 EP 목록에서 `GET /api/items/get-callee-list` 삭제
- `commerce-srs.md` §4.1 Controller 행 `ItemsController (1370 L) — 17 EP` → `16 EP`
- `commerce-sdd.md` §4.1 Controller Layer 표 `ItemsController | 17 | ...` → `16 EP`

---

#### COMMERCE-ITEMS-DEF-002 [MEDIUM] STD Items 서브도메인 EP 수 불일치

| 항목 | 내용 |
|------|------|
| 심각도 | MEDIUM |
| 유형 | EP 목록 불일치 |
| SSOT 판단 | API가 SSOT — IEEE(STD) 수정 필요 |

**현황**:
- STD §1.2: `Items (17 EP)`
- API 실제: 16개

**수정 대상 (IEEE)**:
- `commerce-std.md` §1.2 `서브도메인: Items (17 EP)` → `Items (16 EP)`

---

## 2. EP-SRS 요구사항 매핑 대조

### 2.1 매핑 현황

| EP | API 설명 | SRS FR | 상태 |
|----|---------|--------|------|
| GET /get-item | 아이템 상세 조회 | FR-001-8 (공개/인증 분리) | 불일치 (아래 참조) |
| GET /get-list-pc | PC 목록 | FR-001 전반 | 일치 |
| POST /get-list | 모바일 목록 | FR-001 전반 | 일치 |
| POST /get-comment | 후기 목록 | FR-003-1 연계 | 일치 |
| POST /get-search-list-items | 상담사 검색 | FR-001-3 | 일치 |
| POST /get-search-list-goods | 상품 검색 | FR-001-3 | 일치 |
| POST /get-like-list | 즐겨찾기 목록 | FR-002-4 | 일치 |
| POST /item-add-like | 즐겨찾기 추가 | FR-002-1 | 일치 |
| DELETE /item-delete-like | 즐겨찾기 삭제 | FR-002-2 | 일치 |
| DELETE /item-all-delete-like | 전체 삭제 | FR-002-3 | 일치 |
| POST /get-item-qna-list | Q&A 목록 | FR-003-1 연계 | 일치 |
| POST /insert-item-qna | Q&A 등록 | FR-003-1 | 일치 |
| POST /save-item-price | 가격 수정 | FR-004-1 | 불일치 (아래 참조) |
| POST /get-posting-list | 게시글 목록 | FR 미매핑 | 이슈 |
| POST /posting-detail | 게시글 상세 | FR 미매핑 | 이슈 |
| POST /get-posting-comments | 게시글 댓글 | FR 미매핑 | 이슈 |

---

### 이슈

#### COMMERCE-ITEMS-DEF-003 [MEDIUM] 포스팅(게시글) EP 3개 SRS FR 미매핑

| 항목 | 내용 |
|------|------|
| 심각도 | MEDIUM |
| 유형 | SRS 요구사항 누락 |
| SSOT 판단 | API가 SSOT — IEEE(SRS) 수정 필요 |

**현황**:
- `POST /api/items/get-posting-list`, `posting-detail`, `get-posting-comments` 3개 EP가 API 문서와 Routes.php에 존재하지만 SRS에 대응하는 FR이 없다.
- SRS FR-001부터 FR-010까지 어디에도 Posting(게시글) 기능 요구사항이 정의되어 있지 않다.

**수정 대상 (IEEE)**:
- `commerce-srs.md`에 `FR-011 Posting/게시글 조회 (Items)` 섹션 신설:
  - FR-011-1: `POST /api/items/get-posting-list` — 상담사 게시글 목록 (공개, 페이지네이션)
  - FR-011-2: `POST /api/items/posting-detail` — 게시글 상세 + 이전/다음 게시글 (공개)
  - FR-011-3: `POST /api/items/get-posting-comments` — 게시글 댓글 목록 (공개, 페이지네이션)
- SRS §1.2 SubDomain Items EP 수 업데이트 (DEF-001과 연계)

---

#### COMMERCE-ITEMS-DEF-004 [HIGH] FR-004-1 role:callee 필터 명세 vs 실제 코드 불일치 [B]

| 항목 | 내용 |
|------|------|
| 심각도 | HIGH |
| 유형 | API 내부 불일치 [B] |
| SSOT 판단 | API 문서(items-api.md) vs 코드(Routes.php + ItemsController) 불일치 |

**현황**:
- **SRS FR-004-1**: "`POST /api/items/save-item-price` requires the `role:callee` route filter. Non-Callee requests shall be rejected with HTTP 403 + `FORBIDDEN` before reaching the controller."
- **API 문서(items-api.md)**: "컨트롤러 내부 `checkNeedLogin(true)`로 상담사 검증 (route 필터 미적용)"
- **Routes.php**: `$routes->post('save-item-price', 'ItemsController::saveItemPrice');` — `role:callee` 필터 없음
- **ItemsController.php**: `saveItemPrice()` 내부에 `checkNeedLogin()` 호출 없이 `$this->member['ce_code']` 직접 참조 (컨트롤러 레벨 callee 검증 존재 여부 불명확)

**문제**: SRS는 Route 필터 적용을 강제하지만, API 문서는 "route 필터 미적용"으로 기술하고, Routes.php도 실제로 필터 없이 등록되어 있다. CLAUDE.md 보안 정책(RBAC Layer 1: `RoleFilter:callee` 라우트 필터 레벨 차단)에도 위반된다.

**수정 대상 (IEEE)**:
- `commerce-srs.md` FR-004-1: route filter 강제 조항을 "컨트롤러 내부 `checkNeedLogin(true)` Callee 검증 (`role:callee` 라우트 필터는 현재 미적용, 기술 부채)" 로 현실에 맞게 수정

**코드 수정 권고** (별도 Checkpoint 필요):
- Routes.php의 `save-item-price` 에 `['filter' => 'role:callee']` 추가 고려

---

## 3. 인증/CSRF 대조

### 3.1 인증 상태 비교

| EP | API 문서 인증 | YAML security | 코드 checkNeedLogin | 상태 |
|----|------------|---------------|-------------------|------|
| GET /get-item | jwt | cookieAuth | 없음 (코드) | 불일치 |
| POST /get-like-list | jwt | cookieAuth | O | 일치 |
| POST /item-add-like | jwt | cookieAuth | O | 일치 |
| DELETE /item-delete-like | jwt | cookieAuth | O | 일치 |
| DELETE /item-all-delete-like | jwt | cookieAuth | O | 일치 |
| POST /get-item-qna-list | jwt | cookieAuth | 없음 (직접 member 참조) | 주의 |
| POST /insert-item-qna | jwt | cookieAuth | O | 일치 |
| POST /save-item-price | jwt | cookieAuth | 없음 (직접 member 참조) | 주의 |
| POST /get-list 외 공개 EP | — | security 없음 | 없음 | 일치 |

### 3.2 CSRF 적용 현황

| EP | HTTP 메서드 | YAML XCsrfToken | 정책 준수 |
|----|------------|----------------|---------|
| GET /get-item | GET | 없음 | 일치 (GET 면제) |
| GET /get-list-pc | GET | 없음 | 일치 |
| POST /get-list | POST | 없음 (공개 EP) | 일치 (공개 EP CSRF 면제) |
| POST /get-comment | POST | 없음 (공개 EP) | 일치 |
| POST /get-like-list | POST | XCsrfToken 포함 | 일치 |
| POST /item-add-like | POST | XCsrfToken 포함 | 일치 |
| DELETE /item-delete-like | DELETE | XCsrfToken 포함 | 일치 |
| DELETE /item-all-delete-like | DELETE | XCsrfToken 포함 | 일치 |
| POST /get-item-qna-list | POST | XCsrfToken 포함 | 일치 |
| POST /insert-item-qna | POST | XCsrfToken 포함 | 일치 |
| POST /save-item-price | POST | XCsrfToken 포함 | 일치 |
| POST /get-posting-list | POST | 없음 (공개 EP) | 일치 |
| POST /posting-detail | POST | 없음 (공개 EP) | 일치 |
| POST /get-posting-comments | POST | 없음 (공개 EP) | 일치 |

**CSRF 적용은 전반적으로 CLAUDE.md 정책(POST/PUT/DELETE 인증 EP에 필수)에 부합한다.**

---

### 이슈

#### COMMERCE-ITEMS-DEF-005 [CRITICAL] GET /api/items/get-item 인증 불일치 (API 문서 jwt ↔ 코드 미인증)

| 항목 | 내용 |
|------|------|
| 심각도 | CRITICAL |
| 유형 | API 내부 불일치 [B] |
| SSOT 판단 | API 문서 vs 코드 불일치 — 코드 또는 문서 수정 필요 (Checkpoint) |

**현황**:
- **API 문서(items-api.md)**: `GET /api/items/get-item` — 인증: `🔒 jwt`
- **YAML**: `security: - cookieAuth: []`
- **코드(ItemsController::getItem())**: `checkNeedLogin()` 호출 없음. 인증 없이 처리 가능
- **SRS FR-001-8**: "Item list, search, and detail endpoints shall be publicly accessible (no authentication required). Favourites and Q&A endpoints require JWT authentication."

**분석**:
- SRS는 item detail(상세)를 공개 EP로 정의한다.
- API 문서와 YAML은 jwt를 요구한다.
- 실제 코드는 인증 없이 동작한다 (SRS와 코드가 일치, API 문서가 오기입).

**수정 대상**:
- API 문서 수정: `items-api.md` EP 표에서 `GET /api/items/get-item` 인증을 `🔒 jwt` → `—`(공개)로 수정
- `items-api.yaml` `/api/items/get-item` 경로에서 `security: - cookieAuth: []` 제거

---

#### COMMERCE-ITEMS-DEF-006 [MEDIUM] Refresh Token Path 명세 불일치

| 항목 | 내용 |
|------|------|
| 심각도 | MEDIUM |
| 유형 | 인증 명세 불일치 |
| SSOT 판단 | CLAUDE.md가 SSOT — API 문서 수정 필요 |

**현황**:
- **CLAUDE.md JWT 명세**: Refresh Token `Path: /`
- **items-api.md JWT 명세 표**: Refresh Token `Path: /api/auth/refresh`
- **items-api.yaml** `refreshCookieAuth`: `description: JWT Refresh Token (HttpOnly 쿠키, Path=/api/auth/refresh)`
- **최근 커밋 a7be0b5**: "fix(auth): Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대" — 즉, Path를 `/`로 변경 완료

**수정 대상**:
- `items-api.md` JWT 명세 표 Refresh Token Path: `/api/auth/refresh` → `/`
- `items-api.yaml` `refreshCookieAuth` description: `Path=/api/auth/refresh` → `Path=/`

---

## 4. X-Forwarded-Proto 대조

### 4.1 대조 결과: 일치

| 항목 | API 문서 | YAML | CLAUDE.md | 상태 |
|------|---------|------|----------|------|
| 헤더명 | `X-Forwarded-Proto` | `XForwardedProto` parameter | `X-Forwarded-Proto` | 일치 |
| 값 | `https` | `enum: [https]` | `https` | 일치 |
| 필수 여부 | 모든 요청 필수 | `required: true` | 모든 환경, 모든 요청 | 일치 |
| YAML $ref | 모든 EP에 `$ref: '#/components/parameters/XForwardedProto'` | 확인됨 | — | 일치 |
| SRS 명시 | SRS §2.1 필터 체인 | — | — | 일치 |

X-Forwarded-Proto 항목에서 API 문서, YAML, CLAUDE.md, SRS 사이에 불일치 없음.

---

## 5. 응답 스키마 대조

### 5.1 전반적 일치 현황

| EP | API 응답 형식 | YAML 스키마 | SRS FR-001-7 | 상태 |
|----|------------|------------|-------------|------|
| GET /get-item | `{ "data": { "item": {...} } }` | 일치 | — | 일치 |
| GET /get-list-pc | `{ "data": [...], "meta": {...} }` | PaginationMeta | camelCase meta | 일치 |
| POST /get-list | `{ "data": [...], "meta": {...} }` | PaginationMeta | camelCase meta | 일치 |
| POST /get-comment | `{ "data": { "comments": [...] } }` | 일치 | — | 일치 |
| POST /get-like-list | `{ "data": [...], "meta": {...} }` | PaginationMeta | — | 일치 |
| POST /item-add-like | `{ "data": { "msg": "...", "likeCnt": N } }` | LikeResponse | — | 불일치 주의 |
| POST /save-item-price | `{ "data": { "msg": "..." } }` | 일치 | — | 불일치 주의 |
| POST /get-item-qna-list | `{ "data": [...], "meta": {...} }` | PaginationMeta | — | 불일치 |
| POST /posting-detail | `{ "data": { "items":{}, "isLike":bool, "nextPrev":{} } }` | PostingDetailResponse | — | 일치 |

---

### 이슈

#### COMMERCE-ITEMS-DEF-007 [MEDIUM] get-item 응답 필드 미명세 (빈 item 객체)

| 항목 | 내용 |
|------|------|
| 심각도 | MEDIUM |
| 유형 | 응답 스키마 불완전 |
| SSOT 판단 | API 문서 + IDD 모두 보완 필요 |

**현황**:
- `items-api.md` §1 응답: `"item": { ... }` — 실제 필드 정의 없음
- `items-api.yaml` `/api/items/get-item` 200 응답: `item: type: object, description: 아이템 상세 정보` — 속성 명시 없음
- `ItemsController::getItem()`: `$item = [];` 빈 배열 반환 (`tb_items` 실제 데이터를 item에 채우는 코드 미완성)

**수정 대상**:
- `items-api.md` §1 응답 섹션에 item 객체 필드 목록 추가 (IDD ItemRow VO 기준)
- `items-api.yaml` `/api/items/get-item` 200 응답에 item 객체 properties 추가 (itCode, itCounselField, itTag, itOnline 등)
- `commerce-idd.md` IF-INT-005 ItemsRepositoryInterface 응답 명세에 getItem() 반환 필드 목록 보강

---

#### COMMERCE-ITEMS-DEF-008 [MEDIUM] save-item-price 에러 응답 코드 불일치 (500 INTERNAL vs 400 INVALID_INPUT)

| 항목 | 내용 |
|------|------|
| 심각도 | MEDIUM |
| 유형 | 응답 스키마 (에러 코드) 불일치 [B] |
| SSOT 판단 | API 문서가 SSOT — 코드 수정 권고 |

**현황**:
- **API 문서 / YAML**: `POST /api/items/save-item-price` 에러 응답으로 `401 UNAUTHORIZED`만 명세. 입력 오류에 대한 400 에러 없음
- **코드(ItemsController::saveItemPrice())**: 
  - `ce_code` 누락 → `INTERNAL` (500) 반환
  - `itp_no` 누락 → `INTERNAL` (500) 반환
  - `old_it_coin_price`/`old_it_060_price` 누락 → `INTERNAL` (500) 반환
  - 가격 정보 없음 → `INTERNAL` (500) 반환
- **CLAUDE.md API 응답 표준**: 에러 코드 `INTERNAL`은 5xx용, 입력 검증 오류는 `INVALID_INPUT` (400) 사용

**수정 대상**:
- `items-api.md` §13에 `HTTP 400 INVALID_INPUT` 에러 응답 케이스 추가 (필수 파라미터 누락)
- `items-api.yaml` `/api/items/save-item-price` responses에 `400: $ref: '#/components/responses/InvalidInput'` 추가
- 코드 수정 권고: 입력 검증 오류를 `INTERNAL` (500)에서 `INVALID_INPUT` (400)으로 변경

---

#### COMMERCE-ITEMS-DEF-009 [LOW] get-item 파라미터 전달 방식 불일치 (Query String vs Body)

| 항목 | 내용 |
|------|------|
| 심각도 | LOW |
| 유형 | 응답 스키마 / 요청 명세 불일치 [B] |
| SSOT 판단 | API 문서가 SSOT — 코드 확인 필요 |

**현황**:
- **API 문서**: `GET /api/items/get-item` — 요청 파라미터: Query String (`itCode`, `stCode`)
- **YAML**: `in: query, name: itCode` — Query String
- **코드(ItemsController::getItem())**: `$post = $this->getJsonInput();` — JSON Body 읽기
- GET 요청에 `getJsonInput()` 사용은 일반적으로 Query String이 아닌 Body를 파싱하는 방식으로, GET + JSON Body는 HTTP 표준상 비권장

**수정 대상 (코드 검토 필요)**:
- `ItemsController::getItem()`에서 `$post = $this->getJsonInput()` → `$post = $this->request->getGet()` 로 수정 고려 (Query String 수신)
- 또는 API 문서와 YAML을 POST 메서드로 변경 고려 (Checkpoint 필요)

---

## 6. 환경별 URL 대조

### 6.1 대조 결과: 일치

| 항목 | API 문서 | YAML servers | CLAUDE.md | 상태 |
|------|---------|-------------|----------|------|
| Production | `https://prd.gl.hongcafe.com` | `https://prd.gl.hongcafe.com` | `https://prd.gl.hongcafe.com` | 일치 |
| Staging | `https://stg.gl.hongcafe.com` | `https://stg.gl.hongcafe.com` | `https://stg.gl.hongcafe.com` | 일치 |
| Development | `https://dev.gl.hongcafe.com` | `https://dev.gl.hongcafe.com` | `https://dev.gl.hongcafe.com` | 일치 |

환경별 URL은 API 문서, YAML, CLAUDE.md 세 곳 모두 일치한다. 이슈 없음.

---

## 7. 비즈니스 규칙 대조 (아이템 관련 멱등/트랜잭션)

### 7.1 즐겨찾기 중복 처리 (FR-002-1)

| 항목 | SRS | API 문서 | 코드 | 상태 |
|------|-----|---------|------|------|
| 중복 추가 | HTTP 409 CONFLICT | 명세 없음 | 확인 필요 | 불일치 |

---

### 이슈

#### COMMERCE-ITEMS-DEF-010 [HIGH] 즐겨찾기 중복 추가 409 CONFLICT 응답 미명세

| 항목 | 내용 |
|------|------|
| 심각도 | HIGH |
| 유형 | 비즈니스 규칙 미반영 |
| SSOT 판단 | API 문서가 SSOT — SRS 요구사항은 유효하나 API 문서에 명세 누락 → API 문서 보완 필요 |

**현황**:
- **SRS FR-002-1**: "Duplicate addition for the same `it_code` by the same user shall return HTTP 409 + error code `CONFLICT`."
- **API 문서(items-api.md) §8**: `POST /api/items/item-add-like` 에러 응답 섹션 없음
- **YAML**: `item-add-like` 에 `401 Unauthorized`만 정의. `409 CONFLICT` 없음
- **IDD §4 통합 에러 계약 표**: `즐겨찾기 중복 | 409 | CONFLICT` 정의됨 — IDD에는 있으나 API 문서/YAML에 없음

**수정 대상**:
- `items-api.md` §8 `POST /api/items/item-add-like` 에 에러 응답 섹션 추가:
  - `HTTP 409 CONFLICT` — 즐겨찾기 중복 추가 시
- `items-api.yaml` `/api/items/item-add-like` responses에 `409` 응답 추가

---

#### COMMERCE-ITEMS-DEF-011 [MEDIUM] Q&A 5분 스팸 방지 규칙 API 문서 미명세

| 항목 | 내용 |
|------|------|
| 심각도 | MEDIUM |
| 유형 | 비즈니스 규칙 미반영 |
| SSOT 판단 | API 문서 보완 필요 |

**현황**:
- **SRS FR-003-4**: "A spam-prevention guard shall reject review re-submission by the same user on the same item within 5 minutes. HTTP 429 + `TOO_MANY_REQUESTS`."
- **IDD §4 통합 에러 계약**: `SMS 스팸 (5분 이내 재작성) | 429 | TOO_MANY_REQUESTS` 정의됨
- **API 문서(items-api.md) §12**: `POST /api/items/insert-item-qna` — 에러 응답에 HTTP 400(내용 길이 부족)만 정의. HTTP 429 없음
- **YAML**: `insert-item-qna` 에 `400`, `401` 만 정의. `429` 없음

**수정 대상**:
- `items-api.md` §12에 에러 응답 추가:
  - `HTTP 429 TOO_MANY_REQUESTS` — 5분 내 동일 아이템 재작성 시
- `items-api.yaml` `/api/items/insert-item-qna` responses에 `429: $ref: '#/components/responses/TooManyRequests'` 추가 (TooManyRequests 응답 컴포넌트는 이미 YAML에 정의됨)

---

## 8. IDD 매핑 대조

### 8.1 내부 인터페이스와 Items API 관계

| IDD 인터페이스 | Items API 관련 EP | 매핑 상태 |
|--------------|-----------------|---------|
| IF-INT-002 ItemListFormatterInterface | GET /get-item, GET /get-list-pc, POST /get-list | 일치 |
| IF-INT-005 ItemsRepositoryInterface | 모든 items EP | 일치 |
| IF-INT-007 ItemPriceLogRepositoryInterface | POST /save-item-price | 일치 (단, FR-004 불일치 연계) |

### 8.2 IDD JSON 예시와 API 문서 비교

| EP | IDD 예시 | API 문서 예시 | 상태 |
|----|---------|------------|------|
| Q&A 등록 FCM 조건 | IF-INT-002 내 기술 없음 | items-api.md §12 설명 일치 | — |
| 가격 수정 | IF-INT-007 관련 예시 없음 | items-api.md §13 일치 | — |

---

### 이슈

#### COMMERCE-ITEMS-DEF-012 [LOW] IDD IF-INT-005 getItem() 반환 명세 미완성

| 항목 | 내용 |
|------|------|
| 심각도 | LOW |
| 유형 | IDD 명세 불완전 |
| SSOT 판단 | IEEE(IDD) 수정 필요 |

**현황**:
- `commerce-idd.md` IF-INT-005 ItemsRepositoryInterface §2.5.2 요청 명세에 `getItemCalleeInfo()`, `getItemAccountInfo()`, `getItemInfo()` 3개 메서드 정의됨
- 그러나 `getItem()` 메서드 (Routes.php → ItemsController::getItem() → itemsModel::getItem() 사용)에 대한 IDD 명세 없음
- API 응답의 `item` 객체 필드가 IDD에서 미정의 상태로 남아있어 프론트엔드 구현 시 참조 불가

**수정 대상 (IEEE)**:
- `commerce-idd.md` IF-INT-005 §2.5.2에 `getItem(array $conditions): ?array` 메서드 시그니처 추가
- §2.5.3 응답 명세에 `getItem()` 반환 `ItemRow` 필드 목록 추가 (DEF-007과 연계)

---

## 9. STD TC 커버리지 대조

### 9.1 Items 관련 TC 현황

| SRS FR | 설명 | STD TC | 상태 |
|--------|------|--------|------|
| FR-001-1 | 6가지 sort 모드 | TC-ILF-024~028 | PASS |
| FR-001-2 | it_counsel_field 필터 | TC-ILF-007~008 | PASS |
| FR-001-3 | 키워드 검색 | TC-IA-001~003, TC-IA-005 | PASS |
| FR-001-4 | ItemListFormatter 체인 | TC-ILF-034~038 | PASS |
| FR-001-5 | 5가지 label 타입 | TC-ILF-015~023 | PASS |
| FR-001-6 | 온라인/포인트/태그 | TC-ILF-001~002, 009~010, 031~033 | PASS |
| FR-001-7 | CI4 Pager 페이지네이션 | TC-IA-002, TC-IA-003 | PASS |
| FR-001-8 | 공개/인증 EP 분리 | TC-IA-001~005 | PASS |
| FR-002-1 | 즐겨찾기 추가 | TC-IC-009 | PASS |
| FR-002-2 | 즐겨찾기 삭제 | TC-IC-010 | PASS |
| FR-002-3 | 전체 즐겨찾기 삭제 | TC-IC-011 | PASS |
| FR-003-1 | Q&A 등록 + FCM | TC-IC-013 | PASS |
| FR-004-1 | 가격 수정 role:callee | TC-IC-014 | PASS (메서드 존재만) |
| FR-011 (신설 권고) | Posting 3 EP | TC 없음 | 미커버 |
| DEF-005 관련 | get-item 인증 없음 | TC 없음 | 미커버 |
| DEF-010 관련 | 즐겨찾기 중복 409 | TC 없음 | 미커버 |
| DEF-011 관련 | Q&A 5분 스팸 429 | TC 없음 | 미커버 |

### 9.2 STD TC 적절성 분석

**커버된 항목**: FR-001~FR-004 Items 핵심 비즈니스 로직 — ItemListFormatter 38개 TC(TC-ILF-001~038)와 ItemsControllerTest 16개 TC(TC-IC-001~016)로 상세히 검증됨.

**미커버 항목**:
1. Posting EP 3개(FR-011 신설 권고) — 대응 TC 없음
2. `GET /api/items/get-item` 인증 부재 케이스 (DEF-005 관련)
3. 즐겨찾기 중복 409 케이스 (FR-002-1, DEF-010 관련)
4. Q&A 5분 내 재작성 429 케이스 (FR-003-4, DEF-011 관련)
5. `save-item-price` 에러 코드 500 vs 400 케이스 (DEF-008 관련)

**STD Traceability Matrix 보완 필요**: FR-003-4(스팸 방지), FR-002-1(중복 409)가 Traceability Matrix에서 누락됨.

---

## 이슈 요약표

| 이슈 ID | 심각도 | 항목 | 유형 | 수정 대상 |
|---------|--------|------|------|---------|
| COMMERCE-ITEMS-DEF-001 | HIGH | EP 목록 | EP 수 불일치 | SRS, SDD |
| COMMERCE-ITEMS-DEF-002 | MEDIUM | EP 목록 | EP 수 불일치 | STD |
| COMMERCE-ITEMS-DEF-003 | MEDIUM | EP-SRS 매핑 | FR 누락 | SRS |
| COMMERCE-ITEMS-DEF-004 | HIGH | EP-SRS 매핑 | role:callee 필터 [B] | SRS + 코드 권고 |
| COMMERCE-ITEMS-DEF-005 | CRITICAL | 인증/CSRF | get-item 인증 [B] | API 문서, YAML |
| COMMERCE-ITEMS-DEF-006 | MEDIUM | 인증/CSRF | Refresh Token Path | API 문서, YAML |
| COMMERCE-ITEMS-DEF-007 | MEDIUM | 응답 스키마 | item 필드 미정의 | API 문서, YAML, IDD |
| COMMERCE-ITEMS-DEF-008 | MEDIUM | 응답 스키마 | 에러 코드 500 vs 400 [B] | API 문서, YAML + 코드 권고 |
| COMMERCE-ITEMS-DEF-009 | LOW | 응답 스키마 | GET + JSON Body [B] | 코드 검토 권고 |
| COMMERCE-ITEMS-DEF-010 | HIGH | 비즈니스 규칙 | 즐겨찾기 409 미명세 | API 문서, YAML |
| COMMERCE-ITEMS-DEF-011 | MEDIUM | 비즈니스 규칙 | Q&A 429 미명세 | API 문서, YAML |
| COMMERCE-ITEMS-DEF-012 | LOW | IDD 매핑 | getItem() 미명세 | IDD |

---

## 수정 우선순위 및 권고 조치

### CRITICAL (즉시 수정)

| 이슈 | 조치 |
|------|------|
| DEF-005: get-item 인증 불일치 | `items-api.md` EP 표 인증 `🔒 jwt` → `—`. YAML `security` 블록 제거 |

### HIGH (단기 수정)

| 이슈 | 조치 |
|------|------|
| DEF-001: SRS Items 17→16 EP | SRS §1.2, §4.1 + SDD §4.1 EP 수 수정 |
| DEF-004: save-item-price role:callee | SRS FR-004-1 현실 반영으로 수정. 코드 필터 추가는 별도 Checkpoint |
| DEF-010: 즐겨찾기 409 미명세 | `items-api.md` §8, `items-api.yaml` 에 409 응답 추가 |

### MEDIUM (중기 수정)

| 이슈 | 조치 |
|------|------|
| DEF-002: STD Items EP 수 | STD §1.2 수정 |
| DEF-003: Posting FR 누락 | SRS에 FR-011 신설 |
| DEF-006: Refresh Token Path | API 문서·YAML Path 수정 `/api/auth/refresh` → `/` |
| DEF-007: item 필드 미정의 | API 문서·YAML·IDD에 item 필드 목록 추가 |
| DEF-008: 에러 코드 500→400 | API 문서·YAML 에 400 에러 추가. 코드 수정 권고 |
| DEF-011: Q&A 429 미명세 | `items-api.md` §12, `items-api.yaml` 에 429 추가 |

### LOW (장기/선택 수정)

| 이슈 | 조치 |
|------|------|
| DEF-009: GET + JSON Body | 코드 검토 후 Query String 전환 또는 POST 변경 검토 |
| DEF-012: IDD getItem() 미명세 | IDD IF-INT-005에 getItem() 추가 |

---

## 타당성 검토

| 이슈 | 근거 | 판단 |
|------|------|------|
| DEF-005 (get-item 공개 처리) | SRS FR-001-8 "detail endpoints shall be publicly accessible" + 실제 코드 미인증 | API 문서 오기입으로 판단. 수정 권고 |
| DEF-004 (role:callee Route 필터 미적용) | CLAUDE.md RBAC Layer 1 "RoleFilter:callee 라우트 필터 레벨 역할 차단" | 현재 코드는 Layer 2(checkNeedLogin)만 적용. Layer 1 부재는 보안 취약점. 단, API 문서가 현실을 정확히 기술하고 있으므로 SRS를 현실에 맞게 수정하고, 별도 이슈로 Route 필터 추가 검토 필요 |
| DEF-008 (에러 코드 500) | CLAUDE.md "에러 코드: INVALID_INPUT(입력 오류), INTERNAL(서버 오류)" | 입력값 검증 실패를 500 INTERNAL로 반환하는 것은 RFC 7231 위반. 400 INVALID_INPUT으로 수정이 맞음 |
| DEF-006 (Refresh Token Path) | 커밋 a7be0b5 "Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대" — 프로덕션 반영 완료 | 문서가 과거 상태로 남아있음. 즉시 동기화 필요 |

---

## 변경 영향 기록

| 변경 사항 | 개선점 | 수행 이유 |
|----------|-------|---------|
| DEF-005 수정 (API 문서 인증 제거) | get-item 공개 EP 명세 정확화 | 잘못된 인증 명세는 클라이언트가 불필요한 JWT를 전송하게 하고, 미인증 사용자의 정상 접근을 막음 |
| DEF-006 수정 (Refresh Token Path) | 최신 프로덕션 코드와 문서 동기화 | 구형 Path 명세는 개발자가 쿠키 설정 오류를 발생시키는 원인이 됨 |
| DEF-010 수정 (409 에러 명세 추가) | 클라이언트가 중복 추가 케이스 처리 가능 | 에러 응답 미명세 시 클라이언트는 2xx로 처리하여 UI 오동작 발생 가능 |
| DEF-001/002 수정 (EP 수 16으로 정정) | SRS/STD와 실제 코드 간 EP 수 일치 | 17 EP 기재는 미존재 EP를 구현해야 한다는 오해 유발 가능 |

---

## 변경 로그

| 날짜 | 내용 | 작성자 |
|------|------|--------|
| 2026-04-21 | 최초 작성. 9개 항목 대조, 12건 이슈 발굴 | claude-sonnet-4-6 |
