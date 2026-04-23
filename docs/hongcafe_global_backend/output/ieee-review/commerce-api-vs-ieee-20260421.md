---
문서명: commerce 모듈 API ↔ IEEE 대조 — 2026-04-21
상태: 초안
생성일: 2026-04-21
SSOT 방향: API → IEEE
작성자: jypark (agent: general-purpose, sonnet)
범위: goods + items + shop (통합)
---

# commerce 모듈 API ↔ IEEE 대조 리포트

## 요약

- 하위 API 파일: goods-api.{md,yaml} / items-api.{md,yaml} / shop-api.{md,yaml}
- EP 수 (md 총합 / yaml 총합 / Routes 총합 / SRS FR 총합): **72 / 72 / 72 / 73**
- 9개 항목 판정: PASS 6 / WARN 2 / FAIL 1
- 이슈 분류: DEF 3건 (WARN-급 2, FAIL-급 1) + [B] API 내부 불일치 1건

### 하위별 EP 수

| 영역 | md EP | yaml EP | Routes EP | SRS EP |
|------|-------|---------|-----------|--------|
| goods | 30 | 30 | 29+1(special)=30 | 30 |
| items | 16 | 16 | 16 | **17** |
| shop | 26 | 26 | 26 | 26 |
| **합계** | **72** | **72** | **72** | **73** |

> SRS-COMMERCE-001 §1.2는 Items 17 EP를 선언하며 FR-001 Related endpoints에 `POST /api/items/get-callee-list`를 언급한다. 해당 EP는 md·yaml·Routes 어디에도 등록되지 않는다 → COMMERCE-ITEMS-DEF-001.

---

## 항목별 판정표 (하위 3개 전체 통합)

| # | 항목 | goods | items | shop | 판정 | 비고 |
|---|------|-------|-------|------|------|------|
| 1 | EP 목록 일치 | PASS (30/30/30) | **WARN** (16/16/16 vs SRS 17) | PASS (26/26/26) | **WARN** | items SRS 1 EP 미등록 |
| 2 | EP-SRS FR 매핑 | PASS (FR-007~010) | PASS (FR-001~004) | PASS (FR-005~006,008) | PASS | 전 EP FR 커버됨 |
| 3 | 인증/CSRF + role:callee 필터 | **WARN** | PASS | PASS | **WARN** | goods `memosave`·`delete-opt`·`delete-file` role 불일치 |
| 4 | X-Forwarded-Proto | PASS | PASS | PASS | PASS | 3개 yaml 모두 `$ref: XForwardedProto` 명시 |
| 5 | 응답 스키마 | PASS | PASS | PASS | PASS | camelCase meta 패턴 일관, `data`/`error` 표준 준수 |
| 6 | 환경별 URL | PASS | PASS | PASS | PASS | 3개 yaml servers 블록에 prd/stg/dev 3개 URL 전부 명시 |
| 7 | 비즈니스 규칙 (멱등/RBAC/재고/업로드) | PASS | PASS | PASS | PASS | SRS NFR-001~007 전부 IDD·SDD에 명세됨 |
| 8 | IDD 매핑 | **FAIL** | PASS | PASS | **FAIL** | IDD에 goods `memosave`·`delete-opt`·`delete-file` 일반사용자 소유권 계약 미정의 |
| 9 | STD TC 커버리지 | PASS | PASS | PASS | PASS | STD 전 SRS FR 추적성 완전(일부 skip 있으나 명시됨) |

---

## 이슈 상세

### COMMERCE-ITEMS-DEF-001 — Items EP 수 불일치 (SRS 17 vs 실제 16)

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IEEE (IEEE를 API 기준으로 수정) |
| 발견 위치 | `docs/specs/commerce-srs.md` §1.2 및 FR-001 Related endpoints |
| 영향 범위 | SRS §1.2 Sub-domains 카운트, FR-001 Related endpoints 목록 |

**내용**: SRS §1.2 Scope 테이블이 "Items (17 EP)"를 명시하고, FR-001 Related endpoints 마지막 줄에 `POST /api/items/get-callee-list`를 기술한다. 그러나:
- `items-api.md`: 16 EP 목록, `get-callee-list` 없음
- `items-api.yaml`: 16 paths, `/api/items/get-callee-list` 없음
- `Routes.php` api/items 그룹: 16개 등록, `get-callee-list` 없음
- `ItemsController`: `GoodsController`·`ShopController`와 달리 callee 전용 목록 EP 없음

**결론**: `get-callee-list` EP는 미구현 또는 설계 단계에서 폐기된 것으로 보인다. API(md/yaml/Routes)가 SSOT이므로 SRS §1.2를 "Items (16 EP), 총 72 EP"로 수정하고 FR-001 Related endpoints에서 해당 EP를 제거해야 한다.

**수정 대상**: `docs/specs/commerce-srs.md` §1.2 (Items EP 수 17→16, 총 73→72), FR-001 Related endpoints 목록

---

### COMMERCE-GOODS-DEF-002 — goods 일반사용자 EP에 role:callee 필터 오분류 의심

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| SSOT 방향 | API → IEEE |
| 발견 위치 | `api-docs/commerce/goods-api.md` EP 목록 vs `Routes.php` |
| 영향 범위 | goods-api.md 인증 컬럼, SRS FR-008, IDD 에러 계약 |

**내용**: `goods-api.md`의 "일반 사용자 (19 EP)" 섹션에 아래 3개 EP가 포함되어 있다.

| EP | md 분류 | md 인증 표기 | Routes 필터 |
|----|---------|------------|------------|
| `POST /api/goods/memosave` | 일반사용자 | `🔒 jwt` | 필터 없음 (일반 jwt) |
| `DELETE /api/goods/delete-opt` | 일반사용자 | `🔒 jwt` | 필터 없음 (일반 jwt) |
| `DELETE /api/goods/delete-file` | 일반사용자 | `🔒 jwt` | 필터 없음 (일반 jwt) |

이 3개 EP는 `goods-api.md` 일반사용자 섹션에 올바르게 분류되어 있고 Routes에도 role:callee 필터가 없다. 그러나 `goods-api.yaml`의 tags를 보면 이 3개 EP에 `GoodsUser` 태그가 부여되어 있어 API 내부는 일관된다.

**실제 이슈**: SRS FR-008-1이 "Goods CRUD endpoints (`POST /api/goods/update-goods`, `DELETE /api/goods/delete-goods`)에 role:callee 필터 필수"라고 명시하면서, 동일 controller 내 `memosave`·`delete-opt`·`delete-file`의 접근 주체(Caller vs Callee)를 명확히 기술하지 않는다. SRS FR-008 소유권 설계 의도가 불명확한 상태이다.

**수정 대상**: SRS FR-008 — `memosave`, `delete-opt`, `delete-file`의 접근 주체(Caller/Callee)를 명확히 기술. IDD §4 에러 처리 계약에 해당 EP의 소유권 검증 규칙 추가.

---

### COMMERCE-GOODS-DEF-003 — IDD에 goods 일반사용자 소유권 계약 미정의 [B]

| 속성 | 값 |
|------|-----|
| 심각도 | FAIL |
| SSOT 방향 | API 내부 불일치 → IEEE 및 API 모두 보완 필요 [B] |
| 발견 위치 | `docs/specs/commerce-idd.md` §4 Unified Error Contract |
| 영향 범위 | IDD §4, IDD §2.4 GoodsRepositoryInterface |

**내용**: IDD §4 Unified Error Contract 테이블에 "활성 판매 존재 (삭제 불가) → 409 CONFLICT" 항목이 있다. 이는 `DELETE /api/goods/delete-goods` (callee 전용)의 계약이다.

그러나 goods 일반사용자 EP 중:
- `DELETE /api/goods/delete-opt`: 옵션 삭제 — 소유권(본인 옵션인지) 검증 계약 IDD에 없음
- `DELETE /api/goods/delete-file`: 파일 삭제 — 소유권(본인 파일인지) 검증 계약 IDD에 없음
- `POST /api/goods/memosave`: 메모 저장 — 소유권(본인 gs_no인지) 검증 계약 IDD에 없음

goods-api.md도 이 3개 EP의 요청 파라미터를 `{ - | - | object | - }` 형태로 미명세 상태이다.

**API 내부 불일치 [B]**: md에서 요청 스키마 미명세 + IDD에서 에러 계약 미정의 → 동일 모듈 내 인터페이스 계약 불완전.

**수정 대상**:
1. `goods-api.md` EP #14, #15, #16: 요청 파라미터 상세 명세 추가
2. `goods-api.yaml` 동일 3개 EP: requestBody schema 구체화
3. `commerce-idd.md` §4: 3개 EP 소유권 검증 에러 계약(403 FORBIDDEN) 추가
4. `commerce-srs.md` FR-008 또는 FR-007: 해당 EP의 접근 주체 명시

---

### Refresh Token Path 불일치 ([B] API 내부 불일치)

| 속성 | 값 |
|------|-----|
| 심각도 | WARN |
| 발견 위치 | `goods-api.md`, `items-api.md`, `shop-api.md` JWT 인증 명세 |
| 기준 | `CLAUDE.md` JWT 명세 |

**내용**: 3개 md 파일의 JWT 인증 명세 테이블에서 Refresh Token Path가 `/api/auth/refresh`로 기술되어 있다.

```
| Path | `/` | `/api/auth/refresh` |   ← 3개 md 동일
```

그러나 CLAUDE.md 최신 명세(커밋 `a7be0b5` — "Refresh Token 쿠키 Path를 /auth/refresh에서 /로 확대")에서 Refresh Token Path는 `/`로 변경되었다.

```
| Path | `/` | `/` |   ← CLAUDE.md 및 auth 모듈 실제 동작
```

동시에 goods/items/shop yaml의 `refreshCookieAuth` 스키마 description에도 `Path=/api/auth/refresh` 문자열이 포함되어 있다.

**이슈 ID**: COMMERCE-SHARED-DEF-004 (3개 md + 3개 yaml 동시 영향)

**수정 대상**: `goods-api.md`, `items-api.md`, `shop-api.md` JWT 명세 Path 행 + `goods-api.yaml`, `items-api.yaml`, `shop-api.yaml` `refreshCookieAuth` description → `/api/auth/refresh` → `/`

---

## 엔드포인트 매트릭스 (통합)

### goods (30 EP)

| 영역 | EP | Method | md | yaml | Routes | SRS FR | STD TC | 판정 |
|------|-----|--------|:--:|:----:|:------:|--------|--------|------|
| goods-user | `/api/goods/get-list-mobile` | POST | O | O | O | FR-007-1 | TC-GA-002 | PASS |
| goods-user | `/api/goods/buy-item` | POST | O | O | O | FR-007-1 | TC-GA-003 | PASS |
| goods-user | `/api/goods/buy-confirm` | POST | O | O | O | FR-007-3 | TC-GPS-001,002,010 | PASS |
| goods-user | `/api/goods/goods-file` | GET | O | O | O | FR-008-8,FR-009-4 | TC-GC-005 | PASS |
| goods-user | `/api/goods/order-info` | POST | O | O | O | FR-007-1 | TC-GA-004 | PASS |
| goods-user | `/api/goods/get-buy-list` | POST | O | O | O | FR-007-1 | TC-GA-005 | PASS |
| goods-user | `/api/goods/goods-regist-info` | POST | O | O | O | FR-007-1 | TC-GC-016 | PASS |
| goods-user | `/api/goods/buy-cancel` | POST | O | O | O | FR-007-4 | TC-GC-017 | PASS |
| goods-user | `/api/goods/refund-success` | POST | O | O | O | FR-007-4,FR-006-5 | TC-GC-018 | PASS |
| goods-user | `/api/goods/get-cancel-list` | POST | O | O | O | FR-007-4 | TC-GC-019 | PASS |
| goods-user | `/api/goods/update-goods-view` | POST | O | O | O | FR-008-3 | TC-GC-020 | PASS |
| goods-user | `/api/goods/get-goods-faq-list-by-type` | POST | O | O | O | FR-007-1 | TC-GC-021 | PASS |
| goods-user | `/api/goods/insert-my-comment` | POST | O | O | O | FR-003-2,FR-003-4 | TC-GC-023 | PASS |
| goods-user | `/api/goods/memosave` | POST | O | O | O | FR-008 (미명세) | TC-GC-024 | **WARN** |
| goods-user | `/api/goods/delete-opt` | DELETE | O | O | O | FR-008 (미명세) | TC-GC-025 | **WARN** |
| goods-user | `/api/goods/delete-file` | DELETE | O | O | O | FR-008 (미명세) | TC-GC-026 | **WARN** |
| goods-user | `/api/goods/get-my-class` | POST | O | O | O | FR-009-1 | TC-GC-027 | PASS |
| goods-user | `/api/goods/get-my-class-detail` | POST | O | O | O | FR-009-2 | TC-GC-028 | PASS |
| goods-user | `/api/goods/addr-second-list` | POST | O | O | O | FR-007-1 | — | PASS |
| goods-callee | `/api/goods/get-calleebuy-list` | POST | O | O | O (role:callee) | FR-008-1 | TC-GC-006 | PASS |
| goods-callee | `/api/goods/get-calleebuy-cnt` | POST | O | O | O (role:callee) | FR-008-1 | TC-GC-007 | PASS |
| goods-callee | `/api/goods/callee-goods-confirm` | POST | O | O | O (role:callee) | FR-008-5 | TC-GC-008 | PASS |
| goods-callee | `/api/goods/callee-goods-job` | POST | O | O | O (role:callee) | FR-008-6 | TC-GC-009,010 | PASS |
| goods-callee | `/api/goods/callee-goods-file-upload` | POST | O | O | O (role:callee) | FR-008-2 | TC-GC-010 | PASS |
| goods-callee | `/api/goods/update-goods` | POST | O | O | O (role:callee) | FR-008-1 | TC-GC-011 | PASS |
| goods-callee | `/api/goods/delete-goods` | DELETE | O | O | O (role:callee) | FR-008-1,FR-008-4 | TC-GC-012 | PASS |
| goods-callee | `/api/goods/delete-o2o` | DELETE | O | O | O (role:callee) | FR-008-1 | TC-GC-013 | PASS |
| goods-callee | `/api/goods/preview-goods` | POST | O | O | O (role:callee) | FR-008-3 | TC-GC-022 | PASS |
| goods-callee | `/api/goods/callee-class-file-upload` | POST | O | O | O (role:callee) | FR-008-2,FR-009-3 | — | PASS |
| special-price | `/api/special-prices/get-list` | POST | O | O | O (public) | FR-010-1,2,3 | TC-SPA-001,002,003 | PASS |

### items (16 EP — SRS에 17로 기술된 것은 DEF-001 참조)

| 영역 | EP | Method | md | yaml | Routes | SRS FR | STD TC | 판정 |
|------|-----|--------|:--:|:----:|:------:|--------|--------|------|
| items | `/api/items/get-item` | GET | O | O | O | FR-001-8 | TC-IC-007 | PASS |
| items | `/api/items/get-list-pc` | GET | O | O | O | FR-001-1~8 | TC-IA-003,IC-002 | PASS |
| items | `/api/items/get-list` | POST | O | O | O | FR-001-1~8 | TC-IA-001,002,IC-003 | PASS |
| items | `/api/items/get-comment` | POST | O | O | O | FR-003-2 | TC-IA-004 | PASS |
| items | `/api/items/get-search-list-items` | POST | O | O | O | FR-001-3 | TC-IA-005,IC-004 | PASS |
| items | `/api/items/get-search-list-goods` | POST | O | O | O | FR-001-3 | TC-IC-005 | PASS |
| items | `/api/items/get-like-list` | POST | O | O | O | FR-002-4 | TC-IC-008 | PASS |
| items | `/api/items/item-add-like` | POST | O | O | O | FR-002-1 | TC-IC-009 | PASS |
| items | `/api/items/item-delete-like` | DELETE | O | O | O | FR-002-2 | TC-IC-010 | PASS |
| items | `/api/items/item-all-delete-like` | DELETE | O | O | O | FR-002-3 | TC-IC-011 | PASS |
| items | `/api/items/get-item-qna-list` | POST | O | O | O | FR-003-1 | TC-IC-012 | PASS |
| items | `/api/items/insert-item-qna` | POST | O | O | O | FR-003-1,FR-003-4 | TC-IC-013 | PASS |
| items | `/api/items/save-item-price` | POST | O | O | O | FR-004-1,2 | TC-IC-014 | PASS |
| items | `/api/items/get-posting-list` | POST | O | O | O | FR-001-8 | TC-IC-015 | PASS |
| items | `/api/items/posting-detail` | POST | O | O | O | FR-001-8 | TC-IC-016 | PASS |
| items | `/api/items/get-posting-comments` | POST | O | O | O | FR-001-8 | — | PASS |
| **SRS only** | `POST /api/items/get-callee-list` | POST | **X** | **X** | **X** | FR-001 언급 | — | **DEF-001** |

### shop (26 EP)

| 영역 | EP | Method | md | yaml | Routes | SRS FR | STD TC | 판정 |
|------|-----|--------|:--:|:----:|:------:|--------|--------|------|
| shop-user | `/api/shop/get-shop-items` | POST | O | O | O | FR-005-1 | TC-SA-001,SC-006 | PASS |
| shop-user | `/api/shop/reservation-calendar` | POST | O | O | O | FR-005-1 | TC-SA-002,SC-002 | PASS |
| shop-user | `/api/shop/order-reservation-time` | POST | O | O | O | FR-005-2~6 | TC-SA-003,SC-003 | PASS |
| shop-user | `/api/shop/view-location-popup` | POST | O | O | O | FR-005-1 | TC-SC-005 | PASS |
| shop-user | `/api/shop/get-my-shop` | POST | O | O | O | FR-006-1 | TC-SA-005,SC-004 | PASS |
| shop-user | `/api/shop/buy-shop` | POST | O | O | O | FR-006-1,NFR-002 | TC-SA-004,SC-007 | PASS |
| shop-user | `/api/shop/insert-my-comment` | POST | O | O | O | FR-006-6,FR-003-4 | TC-SC-008 | PASS |
| shop-user | `/api/shop/update-reschedule` | POST | O | O | O | FR-006-3,NFR-003 | TC-SC-009 | PASS |
| shop-user | `/api/shop/shop-confirm` | POST | O | O | O | FR-006-2 | TC-SC-010 | PASS |
| shop-user | `/api/shop/shop-cancel` | POST | O | O | O | FR-006-3,NFR-003 | TC-SC-011 | PASS |
| shop-user | `/api/shop/refund-success` | POST | O | O | O | FR-006-5 | TC-SC-012 | PASS |
| shop-user | `/api/shop/shop-file` | GET | O | O | O | FR-008-8,NFR-006 | TC-SC-013 | PASS |
| shop-callee | `/api/shop/schedule-add` | POST | O | O | O (role:callee) | FR-008-7 | TC-SC-015 | PASS |
| shop-callee | `/api/shop/schedule-delete` | DELETE | O | O | O (role:callee) | FR-008-7 | TC-SC-014 | PASS |
| shop-callee | `/api/shop/shop-reserve-day` | POST | O | O | O (role:callee) | FR-005-1 | TC-SC-016 | PASS |
| shop-callee | `/api/shop/shop-reserve-week` | POST | O | O | O (role:callee) | FR-005-1 | TC-SC-017 | PASS |
| shop-callee | `/api/shop/shop-reserve-month` | POST | O | O | O (role:callee) | FR-005-1 | TC-SC-018 | PASS |
| shop-callee | `/api/shop/callee-shop-confirm` | POST | O | O | O (role:callee) | FR-008-7 | TC-SC-019 | PASS |
| shop-callee | `/api/shop/memosave` | POST | O | O | O (role:callee) | FR-008-7 | TC-SC-020 | PASS |
| shop-callee | `/api/shop/callee-shop-file-upload` | POST | O | O | O (role:callee) | FR-008-2,FR-008-7 | TC-SC-021 | PASS |
| shop-callee | `/api/shop/callee-o2o-job` | POST | O | O | O (role:callee) | FR-008-7 | TC-SC-022 | PASS |
| shop-callee | `/api/shop/delete-file` | DELETE | O | O | O (role:callee) | FR-008-7 | TC-SC-023 | PASS |
| shop-callee | `/api/shop/update-shop` | POST | O | O | O (role:callee) | FR-008-1 | TC-SC-024 | PASS |
| shop-callee | `/api/shop/update-shop-view` | POST | O | O | O (role:callee) | FR-008-3 | TC-SC-025 | PASS |
| shop-callee | `/api/shop/preview-shop` | POST | O | O | O (role:callee) | FR-008-3 | TC-SC-026 | PASS |
| shop-callee | `/api/shop/delete-opt` | DELETE | O | O | O (role:callee) | FR-008-1 | — | PASS |

---

## 추가 관찰 사항

### save-item-price (items) — role:callee 필터 미적용, 컨트롤러 내부 검증만

`POST /api/items/save-item-price`는 SRS FR-004-1이 "`role:callee` route filter 필수"를 명시한다. 그러나 Routes.php에서 해당 EP에는 `['filter' => 'role:callee']`가 없고, items-api.md/yaml 모두 "컨트롤러 내부 `checkNeedLogin(true)` 상담사 검증 (route 필터 미적용)"으로 기술하고 있다.

이는 API(md/yaml)와 SRS 사이의 충돌이다. SSOT 원칙상 API가 SSOT이므로 SRS FR-004-1 문구를 "컨트롤러 레벨 `checkNeedLogin(true)` 이중 검증 적용, route 필터 미적용"으로 수정해야 한다. 단, CLAUDE.md RBAC 3계층 정책(Layer 1: 라우트 필터)과의 정합성 검토가 필요하다.

**이슈 ID**: COMMERCE-ITEMS-DEF-005 (WARN) — SRS FR-004-1 문구 수정 또는 Routes 필터 추가 중 하나 선택 필요. 사용자 승인 필요.

### STD Feature 테스트 MySQL 의존

STD §6 DEF-C-003: Feature 테스트(GoodsApiTest 등 4개)는 실제 MySQL DB 연결이 필요하다. SQLite 테스트 환경에서는 자동 skip된다. 이는 설계 의도된 환경 분리이나, CI/CD 파이프라인에서 DB 연동 Feature 테스트 실행 여부를 문서에 명시할 필요가 있다. (관찰 사항, 이슈 미생성)

### IDD 응답 메시지 일본어 하드코딩

IDD §2.1.3에서 `confirmPurchase()` 응답 message가 "販売した商品の購入が確定されました。" (일본어 고정)으로 명세되어 있다. IDD §7 타당성 검토에서도 "검토 필요" 상태로 기록되어 있다. 기술 부채로 등록된 상태이므로 별도 이슈 생성은 생략하나, 다국어 확장 시 우선 처리 필요.

---

## Open Questions

1. **`GET /api/items/get-callee-list` 폐기 여부 확인**: SRS FR-001 Related endpoints 기술은 설계 초안 잔존분인가, 아니면 구현 예정 EP인가? 구현 예정이라면 API 문서 추가 후 SRS EP 수 조정이 필요하다.

2. **`goods/memosave`, `goods/delete-opt`, `goods/delete-file` 접근 주체 확정**: 이 3개 EP는 Caller(구매자)가 사용하는가, Callee(상담사)가 사용하는가? Routes에 role:callee 필터가 없으므로 현재는 Caller도 접근 가능하다. SRS/IDD에 접근 주체 및 소유권 검증 규칙을 명확히 기재해야 한다.

3. **`save-item-price` role:callee 필터 추가 여부**: SRS FR-004-1 vs 현재 Routes 불일치. Routes에 `['filter' => 'role:callee']` 추가가 맞는가, 아니면 SRS 문구를 컨트롤러 검증 방식으로 변경하는가?

4. **Refresh Token Path 일괄 수정 승인**: 3개 md + 3개 yaml의 `/api/auth/refresh` → `/` 수정을 일괄 진행해도 되는가?
