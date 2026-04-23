---
문서명: Commerce 모듈 Goods 하위 API ↔ IEEE 대조 리포트
문서ID: IEEE-REVIEW-GOODS-20260421
상태: 초안
생성일: 2026-04-21
SSOT 방향: API → IEEE (API가 SSOT. IEEE를 API에 맞춰 수정)
작성자: jypark (agent: general-purpose, sonnet-4-6)
범위: goods-api.md / goods-api.yaml / commerce-{srs,sdd,idd,std}.md — Goods 섹션
대조 항목: 9개
이슈 ID 체계: COMMERCE-GOODS-DEF-NNN
---

# Commerce 모듈 Goods 하위 API ↔ IEEE 대조 리포트

## 요약

| 항목 | 값 |
|------|-----|
| API 입력 파일 | `api-docs/commerce/goods-api.md`, `api-docs/commerce/goods-api.yaml` |
| IEEE 입력 파일 | `docs/specs/commerce-{srs,sdd,idd,std}.md` Goods 섹션 |
| 코드 입력 파일 | `app/Modules/Commerce/Config/Routes.php` (api/goods + api/special-prices 그룹) |
| EP 수 (md / yaml / Routes / SRS) | **30 / 30 / 30 / 30** |
| 9개 항목 판정 | PASS 5 / WARN 3 / FAIL 1 |
| 이슈 수 | DEF 5건 (WARN 3, FAIL 1, [B] API 내부 불일치 1) |

### EP 수 상세

| 출처 | 일반사용자 EP | 상담사(callee) EP | 특가 EP | 합계 |
|------|:-----------:|:----------------:|:------:|:----:|
| goods-api.md | 19 | 10 | 1 | 30 |
| goods-api.yaml (paths 수) | 19 | 10 | 1 | 30 |
| Routes.php api/goods 그룹 | 19 | 10 | 0 | 29 |
| Routes.php api/special-prices 그룹 | 0 | 0 | 1 | 1 |
| Routes.php 합계 | — | — | — | **30** |
| SRS §1.2 (Goods 30 EP + SpecialPrice 1 EP = 31 → §1.2 Goods는 30으로 기술) | 19 | 10 | 1 | **30** |

> SRS §1.2 범위 선언: "Goods (30 EP), SpecialPrice (1 EP)" — 특가 EP 1개를 Goods가 아닌 SpecialPrice로 분리 카운트한다.
> goods-api.md는 특가 EP를 문서 내에 포함하여 30개로 집계한다. 모든 소스의 실질 카운트는 일치한다.

---

## 항목별 판정표

| # | 항목 | 판정 | 비고 |
|---|------|:----:|------|
| 1 | EP 목록 (md ↔ yaml ↔ Routes ↔ SRS FR Goods 섹션) | PASS | 30 EP 완전 일치 |
| 2 | EP-SRS 매핑 | PASS | 전 30 EP가 FR-007~FR-010 중 하나 이상에 귀속됨 |
| 3 | 인증/CSRF + `role:callee` 필터 (goods/callee-* EP) | **WARN** | `memosave`·`delete-opt`·`delete-file` 3개 EP 접근 주체 미명세 |
| 4 | X-Forwarded-Proto | PASS | yaml `$ref: XForwardedProto` 전 EP 적용 |
| 5 | 응답 스키마 | **WARN** | `buy-confirm` 응답 필드명 md/yaml ↔ IDD 불일치 |
| 6 | 환경별 URL | PASS | yaml servers 블록 prd/stg/dev 3개 모두 명시 |
| 7 | 비즈니스 규칙 (멱등/RBAC 3계층/이미지 MIME 이중 검증) | PASS | SRS NFR-001~007, FR-007~008 SDD·IDD에 전부 명세됨 |
| 8 | IDD 매핑 | **FAIL** | `memosave`·`delete-opt`·`delete-file` 소유권 에러 계약 IDD §4 미정의 |
| 9 | STD TC 커버리지 | **WARN** | `addr-second-list` 및 `callee-class-file-upload` STD TC 없음 |

**판정 기준**: PASS = 완전 일치 / WARN = 경미한 불일치·보완 권장 / FAIL = 계약 누락 또는 명백한 오류

---

## 이슈 상세

### COMMERCE-GOODS-DEF-001 — `memosave`·`delete-opt`·`delete-file` 접근 주체 미명세 (SRS FR-008)

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IEEE |
| 발견 위치 | `docs/specs/commerce-srs.md` FR-008 / `api-docs/commerce/goods-api.md` EP #14~#16 |
| 영향 범위 | SRS FR-008, IDD §4 에러 처리 계약, goods-api.md EP #14~#16 |

**내용**:

`goods-api.md` 일반사용자 섹션(19 EP)에 다음 3개 EP가 포함되어 있으며, Routes.php에도 `role:callee` 필터 없이 등록되어 있다.

| EP | md 분류 | md 인증 | Routes 필터 | 접근 주체 |
|----|---------|---------|------------|----------|
| `POST /api/goods/memosave` | 일반사용자 | `🔒 jwt` | 없음 | **불명확** |
| `DELETE /api/goods/delete-opt` | 일반사용자 | `🔒 jwt` | 없음 | **불명확** |
| `DELETE /api/goods/delete-file` | 일반사용자 | `🔒 jwt` | 없음 | **불명확** |

SRS FR-008은 Callee Goods 및 Shop Management를 다루지만, 위 3개 EP의 접근 주체(Caller인지 Callee인지)를 명시하지 않는다. FR-008-1에는 `update-goods`와 `delete-goods`만 role:callee 필수로 기술되어 있다.

**결론**: API(md/yaml/Routes)가 현재 일반사용자(Caller)도 접근 가능한 구조임을 명확히 반영한다. SRS FR-008 또는 별도 FR에 이 3개 EP의 접근 주체(Caller, jwt 인증 필수)와 소유권 검증 규칙을 명시해야 한다.

**수정 대상**:
1. `docs/specs/commerce-srs.md` FR-008 또는 FR-007 — `memosave`·`delete-opt`·`delete-file` 접근 주체 기술 추가
2. `docs/specs/commerce-idd.md` §4 — 3개 EP 소유권 에러 계약(403 FORBIDDEN) 추가

---

### COMMERCE-GOODS-DEF-002 — `buy-confirm` 응답 필드명 md/yaml ↔ IDD 불일치 [B]

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API 내부 불일치 [B] |
| 발견 위치 | `goods-api.md` EP #3 / `goods-api.yaml` `/api/goods/buy-confirm` / `commerce-idd.md` §2.1.3 |
| 영향 범위 | goods-api.md EP #3 응답, goods-api.yaml 응답 스키마, IDD §2.1.3 |

**내용**:

`POST /api/goods/buy-confirm`의 성공 응답 필드명이 소스 간 불일치한다.

| 소스 | 응답 필드명 |
|------|-----------|
| `goods-api.md` EP #3 응답 | `"msg": "구매가 확인되었습니다."` |
| `goods-api.yaml` MessageResponse schema | `data.msg` |
| `commerce-idd.md` §2.1.3 (IF-INT-001) | `"message": "販売した商品の購入が確定されました。"` |

IDD §2.1.5 JSON 예시도 `"data": { "message": "..." }` 형태로 `msg`가 아닌 `message`를 사용한다. 또한 IDD는 메시지 내용을 일본어로 고정하고 있으나 md/yaml은 한국어를 기재한다.

**결론**: API(md/yaml)에서 `msg` 키를 사용하므로 IDD §2.1.3 응답 명세를 `msg` 키로 수정해야 한다. 메시지 언어는 다국어 이슈로 별도 기술 부채로 관리 중 (IDD §7 타당성 검토 참조).

**수정 대상**:
1. `docs/specs/commerce-idd.md` §2.1.3 — 응답 필드명 `message` → `msg`
2. `docs/specs/commerce-idd.md` §2.1.5 — JSON 예시 `"message":` → `"msg":` 수정

---

### COMMERCE-GOODS-DEF-003 — IDD Goods 일반사용자 소유권 계약 미정의

| 속성 | 값 |
|------|-----|
| 심각도 | FAIL |
| SSOT 방향 | API 내부 불일치 → IEEE 및 API 보완 필요 [B] |
| 발견 위치 | `docs/specs/commerce-idd.md` §4 Unified Error Contract |
| 영향 범위 | IDD §4, IDD §2.4 GoodsRepositoryInterface, goods-api.md EP #14~#16 |

**내용**:

`commerce-idd.md` §4 Unified Error Contract에는 "활성 판매 존재 (삭제 불가) → 409 CONFLICT" 항목이 있다(Callee의 `delete-goods`에 해당). 그러나 goods 일반사용자 EP 중 소유권 검증이 필요한 3개 EP에 대한 에러 계약이 누락되어 있다.

| EP | 누락된 에러 계약 |
|----|----------------|
| `DELETE /api/goods/delete-opt` | 옵션 소유권 불일치 시 403 FORBIDDEN 계약 없음 |
| `DELETE /api/goods/delete-file` | 파일 소유권 불일치 시 403 FORBIDDEN 계약 없음 |
| `POST /api/goods/memosave` | 주문(gs_no) 소유권 불일치 시 403 FORBIDDEN 계약 없음 |

동시에 goods-api.md EP #14 (memosave), #15 (delete-opt), #16 (delete-file)의 요청 파라미터가 `{ - | - | object | - }` 형태로 미명세 상태이다.

**결론**: API 문서(md) 내에서 요청 파라미터가 미명세된 상태로, IDD 소유권 계약도 없다. API 내부 계약 불완전 [B] 판정. IEEE(IDD)를 API에 맞춰 보완하는 동시에 API 문서도 파라미터 명세 추가가 필요하다.

**수정 대상**:
1. `api-docs/commerce/goods-api.md` EP #14 (`memosave`), #15 (`delete-opt`), #16 (`delete-file`) — 요청 파라미터 상세 명세 추가
2. `api-docs/commerce/goods-api.yaml` 동일 3개 EP — requestBody schema 구체화
3. `docs/specs/commerce-idd.md` §4 — 소유권 검증 에러 계약(403 FORBIDDEN) 3건 추가
4. `docs/specs/commerce-idd.md` §2.4 GoodsRepositoryInterface — 소유권 검증 메서드 계약 추가

---

### COMMERCE-GOODS-DEF-004 — STD TC 커버리지 누락 (`addr-second-list`, `callee-class-file-upload`)

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| 발견 위치 | `docs/specs/commerce-std.md` §3.5 GoodsControllerTest, §5 Traceability Matrix |
| 영향 범위 | STD §3.5, STD §5 추적성 매트릭스 |

**내용**:

`commerce-std.md` GoodsControllerTest(TC-GC-001~028)와 Traceability Matrix를 검토한 결과, 다음 2개 EP에 대한 STD 테스트 케이스가 없다.

| EP | SRS FR | STD TC | 상태 |
|----|--------|--------|------|
| `POST /api/goods/addr-second-list` | FR-007-1 (일반 목록 조회로 분류 가능) | 없음 | **누락** |
| `POST /api/goods/callee-class-file-upload` | FR-008-2, FR-009-3 | 없음 | **누락** |

GoodsControllerTest는 28개 TC로 controller 메서드 존재 여부를 검증하지만, 위 2개 메서드(`addrSecondList`, `calleeClassFileUpload`)에 대한 TC가 없다.

**결론**: 이 2개 EP는 메서드 존재 확인 수준의 Unit TC조차 없다. `callee-class-file-upload`는 MIME 이중 검증(NFR-001) 및 FCM 발송(FR-009-3)이 포함된 중요 EP이므로 우선 추가가 필요하다.

**수정 대상**:
1. `docs/specs/commerce-std.md` §3.5 — TC-GC-029 (`testAddrSecondListMethodExists`), TC-GC-030 (`testCalleeClassFileUploadMethodExists`) 추가
2. `docs/specs/commerce-std.md` §5 — Traceability Matrix에 2개 TC 매핑 추가

---

### COMMERCE-GOODS-DEF-005 — Refresh Token Path 불일치 (md ↔ CLAUDE.md)

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| 발견 위치 | `api-docs/commerce/goods-api.md` JWT 인증 명세 테이블 |
| 영향 범위 | goods-api.md JWT 명세, goods-api.yaml `refreshCookieAuth` description |

**내용**:

`goods-api.md` JWT 인증 명세 테이블에서 Refresh Token Path가 `/api/auth/refresh`로 기술되어 있다.

```
| Path | `/` | `/api/auth/refresh` |   ← goods-api.md 현재
```

그러나 CLAUDE.md 최신 명세 및 커밋 `a7be0b5` ("Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대")에 따라 Refresh Token Path는 `/`로 변경되었다.

```
| Path | `/` | `/` |   ← CLAUDE.md 및 실제 동작
```

`goods-api.yaml`의 `refreshCookieAuth` description에도 `Path=/api/auth/refresh` 문자열이 포함되어 있다.

**수정 대상**:
1. `api-docs/commerce/goods-api.md` JWT 인증 명세 — Refresh Token Path: `/api/auth/refresh` → `/`
2. `api-docs/commerce/goods-api.yaml` `refreshCookieAuth` description — Path 표기 수정

---

## 엔드포인트 매트릭스 (Goods 30 EP)

| 영역 | EP | Method | md | yaml | Routes | 필터 | SRS FR | STD TC | 판정 |
|------|-----|--------|:--:|:----:|:------:|:----:|--------|--------|:----:|
| goods-user | `/api/goods/get-list-mobile` | POST | O | O | O | — | FR-007-1 | TC-GA-002 | PASS |
| goods-user | `/api/goods/buy-item` | POST | O | O | O | jwt | FR-007-1 | TC-GA-003 | PASS |
| goods-user | `/api/goods/buy-confirm` | POST | O | O | O | jwt | FR-007-3 | TC-GPS-001,002,010 | PASS |
| goods-user | `/api/goods/goods-file` | GET | O | O | O | jwt | FR-008-8, FR-009-4 | TC-GC-005 | PASS |
| goods-user | `/api/goods/order-info` | POST | O | O | O | jwt | FR-007-1 | TC-GA-004 | PASS |
| goods-user | `/api/goods/get-buy-list` | POST | O | O | O | jwt | FR-007-1 | TC-GA-005 | PASS |
| goods-user | `/api/goods/goods-regist-info` | POST | O | O | O | jwt | FR-007-1 | TC-GC-016 | PASS |
| goods-user | `/api/goods/buy-cancel` | POST | O | O | O | jwt | FR-007-4 | TC-GC-017 | PASS |
| goods-user | `/api/goods/refund-success` | POST | O | O | O | jwt | FR-007-4, FR-006-5 | TC-GC-018 | PASS |
| goods-user | `/api/goods/get-cancel-list` | POST | O | O | O | jwt | FR-007-4 | TC-GC-019 | PASS |
| goods-user | `/api/goods/update-goods-view` | POST | O | O | O | jwt | FR-008-3 | TC-GC-020 | PASS |
| goods-user | `/api/goods/get-goods-faq-list-by-type` | POST | O | O | O | — | FR-007-1 | TC-GC-021 | PASS |
| goods-user | `/api/goods/insert-my-comment` | POST | O | O | O | jwt | FR-003-2, FR-003-4 | TC-GC-023 | PASS |
| goods-user | `/api/goods/memosave` | POST | O | O | O | jwt | FR-008 **(접근주체 미명세)** | TC-GC-024 | **WARN** |
| goods-user | `/api/goods/delete-opt` | DELETE | O | O | O | jwt | FR-008 **(접근주체 미명세)** | TC-GC-025 | **WARN** |
| goods-user | `/api/goods/delete-file` | DELETE | O | O | O | jwt | FR-008 **(접근주체 미명세)** | TC-GC-026 | **WARN** |
| goods-user | `/api/goods/get-my-class` | POST | O | O | O | jwt | FR-009-1 | TC-GC-027 | PASS |
| goods-user | `/api/goods/get-my-class-detail` | POST | O | O | O | jwt | FR-009-2 | TC-GC-028 | PASS |
| goods-user | `/api/goods/addr-second-list` | POST | O | O | O | — | FR-007-1 | **없음** | **WARN** |
| goods-callee | `/api/goods/get-calleebuy-list` | POST | O | O | O | role:callee | FR-008-1 | TC-GC-006 | PASS |
| goods-callee | `/api/goods/get-calleebuy-cnt` | POST | O | O | O | role:callee | FR-008-1 | TC-GC-007 | PASS |
| goods-callee | `/api/goods/callee-goods-confirm` | POST | O | O | O | role:callee | FR-008-5 | TC-GC-008 | PASS |
| goods-callee | `/api/goods/callee-goods-job` | POST | O | O | O | role:callee | FR-008-6 | TC-GC-009, TC-GC-010 | PASS |
| goods-callee | `/api/goods/callee-goods-file-upload` | POST | O | O | O | role:callee | FR-008-2 | TC-GC-010 | PASS |
| goods-callee | `/api/goods/update-goods` | POST | O | O | O | role:callee | FR-008-1 | TC-GC-011 | PASS |
| goods-callee | `/api/goods/delete-goods` | DELETE | O | O | O | role:callee | FR-008-1, FR-008-4 | TC-GC-012 | PASS |
| goods-callee | `/api/goods/delete-o2o` | DELETE | O | O | O | role:callee | FR-008-1 | TC-GC-013 | PASS |
| goods-callee | `/api/goods/preview-goods` | POST | O | O | O | role:callee | FR-008-3 | TC-GC-022 | PASS |
| goods-callee | `/api/goods/callee-class-file-upload` | POST | O | O | O | role:callee | FR-008-2, FR-009-3 | **없음** | **WARN** |
| special-price | `/api/special-prices/get-list` | POST | O | O | O | — (공개) | FR-010-1, 2, 3 | TC-SPA-001,002,003 | PASS |

**범례**: O = 존재 / — = 없음(공개 EP) / X = 누락

---

## 9개 항목 상세 검토

### 항목 1: EP 목록 (md ↔ yaml ↔ Routes ↔ SRS FR Goods 섹션)

| 소스 | EP 수 | 판정 |
|------|:-----:|:----:|
| goods-api.md | 30 | — |
| goods-api.yaml (paths) | 30 | — |
| Routes.php (api/goods + api/special-prices) | 30 | — |
| SRS §1.2 Goods + SpecialPrice | 30 | — |
| **일치 여부** | | **PASS** |

**검토 결과**: 4개 소스 모두 30 EP로 완전 일치. SRS §1.2의 "Goods (30 EP), SpecialPrice (1 EP)" 분류와 goods-api.md의 통합 30 EP 기술 간 표현 차이는 있으나 실질 EP 수는 동일하다. 불일치 없음.

---

### 항목 2: EP-SRS FR 매핑

**검토 결과**: PASS

전 30 EP가 SRS FR-007(상품 구매/확인/취소/환불), FR-008(Callee 상품 관리), FR-009(클래스 관리), FR-010(특가) 중 하나 이상의 FR에 귀속된다. 단, `memosave`·`delete-opt`·`delete-file` 3개 EP에 대한 FR 귀속이 불명확한 것은 DEF-001에서 다룬다.

| FR | 귀속 EP 수 | 주요 EP |
|----|:----------:|--------|
| FR-007 | 9 | buy-item, buy-confirm, buy-cancel, refund-success, order-info, get-buy-list, get-cancel-list, get-list-mobile, goods-regist-info |
| FR-008 | 15 | get-calleebuy-list, get-calleebuy-cnt, callee-goods-confirm, callee-goods-job, callee-goods-file-upload, update-goods, delete-goods, delete-o2o, preview-goods, goods-file, update-goods-view, get-goods-faq-list-by-type, memosave*, delete-opt*, delete-file* |
| FR-009 | 4 | get-my-class, get-my-class-detail, callee-class-file-upload, goods-file (중복) |
| FR-010 | 1 | /api/special-prices/get-list |

---

### 항목 3: 인증/CSRF + `role:callee` 필터

**검토 결과**: WARN → DEF-001

**Callee EP (10개) — PASS**: 모두 `['filter' => 'role:callee']`로 Routes에 등록되어 있으며, goods-api.md/yaml에도 `jwt (callee)` 또는 `role:callee` 명시.

**일반사용자 EP 인증 현황 — WARN 3건**:

| EP | md 인증 | yaml security | Routes 필터 | 판정 |
|----|---------|--------------|------------|:----:|
| `get-list-mobile` | — | 없음 | 없음 | PASS (공개) |
| `buy-item` | jwt | cookieAuth | jwt | PASS |
| `buy-confirm` | jwt | cookieAuth | jwt | PASS |
| `goods-file` | jwt | cookieAuth | jwt | PASS |
| `order-info` | jwt | cookieAuth | jwt | PASS |
| `get-buy-list` | jwt | cookieAuth | jwt | PASS |
| `goods-regist-info` | jwt | cookieAuth | jwt | PASS |
| `buy-cancel` | jwt | cookieAuth | jwt | PASS |
| `refund-success` | jwt | cookieAuth | jwt | PASS |
| `get-cancel-list` | jwt | cookieAuth | jwt | PASS |
| `update-goods-view` | jwt | cookieAuth | jwt | PASS |
| `get-goods-faq-list-by-type` | — | 없음 | 없음 | PASS (공개) |
| `insert-my-comment` | jwt | cookieAuth | jwt | PASS |
| `memosave` | jwt | cookieAuth | 없음(jwt) | **WARN** (접근주체 미명세) |
| `delete-opt` | jwt | cookieAuth | 없음(jwt) | **WARN** (접근주체 미명세) |
| `delete-file` | jwt | cookieAuth | 없음(jwt) | **WARN** (접근주체 미명세) |
| `get-my-class` | jwt | cookieAuth | jwt | PASS |
| `get-my-class-detail` | jwt | cookieAuth | jwt | PASS |
| `addr-second-list` | — | 없음 | 없음 | PASS (공개) |

**CSRF 적용**: goods-api.yaml에서 POST/DELETE 인증 EP는 모두 `$ref: XCsrfToken` 파라미터 포함. 공개 EP에는 CSRF 헤더 없음. 일관성 PASS.

---

### 항목 4: X-Forwarded-Proto

**검토 결과**: PASS

`goods-api.yaml` 모든 EP에 `$ref: '#/components/parameters/XForwardedProto'` 포함. `components.parameters.XForwardedProto` 정의도 완전 (`type: string`, `enum: [https]`, `default: https`). goods-api.md 상단에도 필수 요청 헤더 테이블 명시. 완전 일치.

---

### 항목 5: 응답 스키마

**검토 결과**: WARN → DEF-002

**일치 항목**:
- 모든 성공 응답: `{ "data": { ... } }` 또는 `{ "data": [...], "meta": { ... } }` — camelCase meta 패턴 준수
- 에러 응답: `{ "error": { "code": "...", "message": "..." } }` — 표준 6종 코드(INVALID_INPUT, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, CONFLICT, INTERNAL) 준수
- 페이지네이션(get-list-mobile, get-calleebuy-list): `currentPage`, `perPage`, `total`, `lastPage` — camelCase 완전 준수
- `get-goods-faq-list-by-type`: `data.faqList` 배열 구조 — md/yaml 일치

**불일치 항목**:
- `buy-confirm` 응답 필드명: md/yaml에서 `"msg"`, IDD §2.1.3에서 `"message"` → DEF-002

**미명세 항목** (WARN, DEF-003 관련):
- `memosave` 요청 파라미터: md에서 `{ - | - | object | - }` 미명세
- `delete-opt` 요청 파라미터: md에서 미명세
- `delete-file` 요청 파라미터: md에서 미명세

---

### 항목 6: 환경별 URL

**검토 결과**: PASS

`goods-api.yaml` `servers` 블록:
```yaml
servers:
  - url: https://prd.gl.hongcafe.com   # Production
  - url: https://stg.gl.hongcafe.com   # Staging
  - url: https://dev.gl.hongcafe.com   # Development
```

CLAUDE.md 환경별 URL과 완전 일치. goods-api.md 상단 환경별 URL 테이블도 동일하게 기술.

---

### 항목 7: 비즈니스 규칙 (멱등/RBAC 3계층/이미지 MIME 이중 검증)

**검토 결과**: PASS

| 비즈니스 규칙 | SRS 명세 | SDD 명세 | IDD 명세 | 판정 |
|-------------|---------|---------|---------|:----:|
| Stripe 멱등키 (PaymentIntent) | NFR-007, FR-007-7 | SDD §12.1 결제 idempotency_key | IDD IF-EXT-001 §3.1.2 | PASS |
| RBAC 3계층 (RoleFilter + checkNeedLogin + Repository 소유권) | SRS §6 Security Checklist | SDD §12.1 Security Overlay | IDD §4 에러 계약 403 FORBIDDEN | PASS |
| MIME 이중 검증 (확장자 + mime_content_type()) | NFR-001, FR-008-2, FR-008-6 | SDD §12.1 파일 업로드 | IDD IF-EXT-004 §3.4 | PASS |
| gs_status 단방향 전이 (0→1→2→3, 4→5) | FR-007-5 | SDD §5.1 FSM, ADR-004 | IDD IF-INT-001 §2.1.4 | PASS |
| 14일 다운로드 제한 | NFR-006, FR-008-8, FR-009-4 | SDD §12.1 | IDD IF-EXT-004 | PASS |
| 구매 확정 후 3단계 (Callee FCM + Caller FCM + SetAlarm) | FR-007-6 | SDD §10.1 시퀀스 | IDD IF-INT-001 | PASS |
| 5분 후기 중복 방지 | FR-003-4 | SDD §4.1 | IDD §4 429 TOO_MANY_REQUESTS | PASS |

---

### 항목 8: IDD 매핑

**검토 결과**: FAIL → DEF-003

**IDD 매핑 완전 항목**:

| Goods EP 그룹 | IDD 참조 | 상태 |
|-------------|---------|:----:|
| `buy-confirm` | IF-INT-001 GoodsPurchaseServiceInterface | PASS (DEF-002 응답 필드명 제외) |
| `buy-item` → `GoodsRepository` | IF-INT-004 GoodsRepositoryInterface | PASS |
| `callee-goods-job` → 파일 업로드 | IF-EXT-004 AWS S3 / IMG_SERVER | PASS |
| `callee-goods-job` → 채팅 알림 | IF-EXT-005 Chat API | PASS |
| `callee-goods-confirm` → FCM | IF-EXT-003 FCM | PASS |
| `get-list-mobile` → SpecialPriceRepository | IF-INT-008 | PASS |
| `buy-item` → Stripe | IF-EXT-001 Stripe | PASS |

**IDD 누락 항목 — FAIL**:

| EP | 누락 계약 |
|----|----------|
| `DELETE /api/goods/delete-opt` | IDD §4에 소유권 검증 에러 계약(403 FORBIDDEN) 없음 |
| `DELETE /api/goods/delete-file` | IDD §4에 소유권 검증 에러 계약(403 FORBIDDEN) 없음 |
| `POST /api/goods/memosave` | IDD §4에 소유권 검증 에러 계약(403 FORBIDDEN) 없음 |

IDD §4 Unified Error Contract에는 `403 FORBIDDEN`이 "비 상담사 접근" 및 "파일 다운로드 기간 초과" 두 경우만 정의되어 있다. 일반 사용자가 타인 소유 리소스에 접근하는 경우의 403 계약이 없다.

---

### 항목 9: STD TC 커버리지

**검토 결과**: WARN → DEF-004

**커버리지 현황**:

- STD 전체: 154 TC, 152 PASS, 2 SKIP (DEF-C-001, DEF-C-002 — 외부 의존)
- GoodsControllerTest: 28 TC — 메서드 존재 확인 방식
- GoodsPurchaseServiceTest: 10 TC (1 SKIP)
- GoodsApiTest (Feature): 5 TC

**누락 TC**:

| EP | 관련 SRS FR | STD TC | 심각도 |
|----|------------|--------|:------:|
| `POST /api/goods/addr-second-list` | FR-007-1 | 없음 | 저 |
| `POST /api/goods/callee-class-file-upload` | FR-008-2, FR-009-3 (MIME 검증 + FCM) | 없음 | **중** |

`callee-class-file-upload`는 MIME 이중 검증(NFR-001)과 FCM 발송(FR-009-3)이 포함된 중요 EP임에도 STD TC가 없다. SRS Traceability Matrix에서도 이 EP는 매핑되어 있지 않다.

**완전 커버 항목 (Goods 관련 SRS FR → STD TC 매핑)**:

| SRS FR | STD TC | 상태 |
|--------|--------|:----:|
| FR-007-1 (상품 구매 INSERT) | TC-GA-003 | PASS |
| FR-007-3 (confirmPurchase) | TC-GPS-001, TC-GPS-002, TC-GPS-010 | PASS |
| FR-007-4 (취소) | TC-GC-017 | PASS |
| FR-007-5 (상태 머신) | TC-GPS-001, TC-GPS-002 | PASS |
| FR-008-1 (Callee CRUD) | TC-GC-011, TC-GC-012 | PASS |
| FR-008-2 (MIME — callee-goods-file-upload) | TC-GC-010 | PASS |
| FR-008-3 (preview/visibility) | TC-GC-022, TC-GC-020 | PASS |
| FR-008-4 (활성주문 삭제 방지) | TC-GPS-001, TC-GPS-002 | PASS |
| FR-008-5 (주문 수락) | TC-GC-008 | PASS |
| FR-008-6 (작업 완료 + 파일) | TC-GC-009, TC-GC-010 | PASS |
| FR-008-8 (14일 다운로드) | TC-GC-005 | PASS |
| FR-009-1 (클래스 이력) | TC-GC-027 | PASS |
| FR-009-2 (클래스 상세) | TC-GC-028 | PASS |
| FR-009-3 (callee-class-file-upload) | **없음** | **WARN** |
| FR-010-1,2,3 (special-prices) | TC-SPA-001,002,003 | PASS |

---

## 이슈 요약표

| ID | 심각도 | 항목 | 발견 위치 | 수정 대상 |
|----|:------:|------|---------|---------|
| COMMERCE-GOODS-DEF-001 | WARN | 항목 3 | SRS FR-008 | SRS FR-008, IDD §4 |
| COMMERCE-GOODS-DEF-002 | WARN [B] | 항목 5 | goods-api.md, IDD §2.1.3 | goods-api.md, goods-api.yaml, IDD §2.1.3, IDD §2.1.5 |
| COMMERCE-GOODS-DEF-003 | FAIL [B] | 항목 8 | commerce-idd.md §4 | goods-api.md, goods-api.yaml, IDD §4, IDD §2.4 |
| COMMERCE-GOODS-DEF-004 | WARN | 항목 9 | commerce-std.md §3.5 | STD §3.5, STD §5 |
| COMMERCE-GOODS-DEF-005 | WARN | 항목 3/공통 | goods-api.md JWT 명세 | goods-api.md, goods-api.yaml |

**[B]**: API 내부 불일치. IEEE를 API 기준으로 수정하는 동시에 API도 보완 필요.

---

## Open Questions

1. **`memosave`·`delete-opt`·`delete-file` 접근 주체 확정**: 이 3개 EP는 Caller(구매자)가 사용하는가, Callee(상담사)도 사용 가능한가? Routes에 `role:callee` 필터 없으므로 현재는 JWT 인증 사용자 누구나 접근 가능. SRS/IDD에 접근 주체 및 소유권 검증 규칙을 명시해야 한다. (DEF-001, DEF-003 선행 해결 필요)

2. **`buy-confirm` 응답 키 `msg` vs `message` 실제 동작 확인**: 실제 `GoodsController::buyConfirm()` 구현체가 `msg`를 반환하는지 `message`를 반환하는지 코드 확인 후 IDD 수정 방향 결정 필요. (DEF-002)

3. **`callee-class-file-upload` TC 추가 우선순위**: MIME 이중 검증(NFR-001) + FCM(FR-009-3) 포함 EP이므로 TC 추가 긴급도가 높다. 다음 테스트 작업 세션에서 우선 처리할지 확인 필요. (DEF-004)

4. **Refresh Token Path 일괄 수정 승인**: `goods-api.md` 및 `goods-api.yaml`의 `/api/auth/refresh` → `/` 수정 진행 승인 여부 확인 필요. 동일 이슈가 `items-api.md`, `shop-api.md`에도 존재하므로 일괄 수정이 효율적. (DEF-005)
