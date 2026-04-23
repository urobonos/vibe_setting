---
문서명: Commerce 모듈 인터페이스 설계 명세서 (IDD)
문서ID: IDD-COMMERCE-001
버전: v2.1
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
적용 표준: MIL-STD-498
대상 시스템: HongCafe Global Backend — Commerce Module
관련 문서:
  - commerce-srs.md (SRS-COMMERCE-001)
  - commerce-sdd.md (SDD-COMMERCE-001)
  - docs/api-specification.md
  - api-docs/commerce/items-api.yaml
  - api-docs/commerce/shop-api.yaml
  - api-docs/commerce/goods-api.yaml
---

# Commerce 모듈 인터페이스 설계 명세서 (IDD)

> MIL-STD-498 준수 (5-Subsection per IF) | version: 2.1 | lastUpdated: 2026-04-21 | module: Commerce

---

## 1. 개요 (Overview)

### 1.1 목적 (Purpose)

본 문서는 HongCafe Global Backend Commerce 모듈의 모든 인터페이스를 MIL-STD-498 IDD 표준에 따라 명세한다. 각 인터페이스는 (1) 목적, (2) 요청 명세, (3) 응답 명세, (4) 에러 계약, (5) JSON 예시의 5개 서브섹션으로 정의된다.

This document specifies all interfaces of the Commerce module conforming to MIL-STD-498 IDD standard. Each interface is defined with 5 subsections: purpose, request specification, response specification, error contract, and JSON examples.

### 1.2 인터페이스 목록 (Interface Inventory)

| 구분 | 인터페이스 ID | 인터페이스명 | 방향 | 프로토콜 |
|------|------------|-----------|------|---------|
| 내부 | IF-INT-001 | GoodsPurchaseServiceInterface | Controller → Service | PHP DI |
| 내부 | IF-INT-002 | ItemListFormatterInterface | Controller → Service | PHP DI |
| 내부 | IF-INT-003 | ShopReservationServiceInterface | Controller → Service | PHP DI |
| 내부 | IF-INT-004 | GoodsRepositoryInterface | Service → Repository | PHP DI |
| 내부 | IF-INT-005 | ItemsRepositoryInterface | Service → Repository | PHP DI |
| 내부 | IF-INT-006 | ShopRepositoryInterface | Service → Repository | PHP DI |
| 내부 | IF-INT-007 | ItemPriceLogRepositoryInterface | Service → Repository | PHP DI |
| 내부 | IF-INT-008 | SpecialPriceRepositoryInterface | Controller → Repository | PHP DI |
| 외부 | IF-EXT-001 | Stripe Payment Gateway | GoodsController/ShopController → Stripe | HTTPS REST (PHP SDK) |
| 외부 | IF-EXT-002 | NaverPay | ShopController → NaverPay | HTTPS REST |
| 외부 | IF-EXT-003 | FCM | GoodsPurchaseService → FCM | HTTPS REST |
| 외부 | IF-EXT-004 | AWS S3 / IMG_SERVER | ItemsController/GoodsController → Storage | AWS SDK / cURL |
| 외부 | IF-EXT-005 | Chat API | GoodsController/ShopController → Chat Module | 내부 HTTP |

---

## 2. 내부 인터페이스 (Internal Interfaces)

### IF-INT-001 GoodsPurchaseServiceInterface

#### 2.1.1 목적 (Purpose)

상품 구매 확정 프로세스를 캡슐화한다. `GoodsController::buyConfirm()`에서 호출되며, DB 갱신, 상담사 FCM, 사용자 FCM, 알람 이력 기록의 4단계를 단일 메서드로 제공한다.

**위치**: `app/Modules/Commerce/Interfaces/GoodsPurchaseServiceInterface.php`
**구현체**: `GoodsPurchaseService`
**소비자**: `GoodsController`

#### 2.1.2 요청 명세 (Request Specification)

```php
/**
 * 상품 구매 확정
 *
 * @param int    $gsNo   tb_goods_sell.gs_no (주문 번호 PK)
 * @param string $crCode 구매자 cr_code (tb_account.cr_code)
 * @return array         성공 시 메시지 배열
 * @throws NotFoundException  gs_no 미존재 시
 * @throws ForbiddenException 소유권 불일치 시
 */
public function confirmPurchase(int $gsNo, string $crCode): array;
```

#### 2.1.3 응답 명세 (Response Specification)

| 필드 | 타입 | 설명 |
|------|------|------|
| `message` | string | 처리 완료 메시지 (일본어 고정: "販売した商品の購入が確定されました。") |

#### 2.1.4 에러 계약 (Error Contract)

| 상황 | HTTP 코드 | 에러 코드 | 처리 |
|------|----------|----------|------|
| gs_no 미존재 | 404 | `NOT_FOUND` | 주문 재확인 |
| 소유권 불일치 | 403 | `FORBIDDEN` | — |
| gs_status 전이 불가 | 409 | `CONFLICT` | 현재 상태 확인 |
| FCM 발송 실패 | — | — | 로그만 기록, 트랜잭션 롤백 없음 |

#### 2.1.5 JSON 예시 (JSON Examples)

**요청** (`POST /api/goods/buy-confirm`):
```json
{
    "gs_no": 1234
}
```

**응답 (HTTP 200)**:
```json
{
    "data": {
        "message": "販売した商品の購入が確定されました。"
    }
}
```

**에러 응답 (gs_no 미존재)**:
```json
{
    "error": {
        "code": "NOT_FOUND",
        "message": "해당 주문을 찾을 수 없습니다."
    }
}
```

---

### IF-INT-002 ItemListFormatterInterface

#### 2.2.1 목적 (Purpose)

아이템 목록 포맷팅 로직을 callback 체인 패턴으로 캡슐화한다. `ItemsController`, `ChatController` 등 복수 컨트롤러가 동일 포맷 로직을 재사용한다. Strategy(pointCalculator, postProcessor) + Chain of Responsibility(formatRow→label→tag→classOnline) 복합 패턴 적용.

**위치**: `app/Modules/Commerce/Interfaces/ItemListFormatterInterface.php`
**구현체**: `ItemListFormatter`
**소비자**: `ItemsController`, `ChatController`

#### 2.2.2 요청 명세 (Request Specification)

```php
/**
 * 단일 행 기본 포맷 (태그, 공지, 필드, 온콜 상태)
 *
 * @param array $row     DB 조회 단일 행
 * @param array $options 포맷 옵션 (온라인 여부, 공지 등)
 * @return array         포맷된 행
 */
public function formatRow(array $row, array $options = []): array;

/**
 * 라벨 태깅 (partner/new/star/review/counsel)
 *
 * @param array  $item       단일 아이템 배열
 * @param string $part       상담 분야 코드
 * @param array  $labelTexts 라벨 텍스트 맵 (다국어)
 * @return array             라벨 추가된 아이템
 */
public function setItemLabel(array $item, string $part = '', array $labelTexts = []): array;

/**
 * 정렬 기준별 보기 태그 설정
 *
 * @param array  $item     단일 아이템 배열
 * @param string $order    정렬 기준 (suggest/itemNew/newRegist/recent/calling/hot)
 * @param array  $tagTexts 태그 텍스트 맵 (다국어)
 * @return array           태그 추가된 아이템
 */
public function setViewTag(array $item, string $order = '', array $tagTexts = []): array;

/**
 * 클래스 온라인 여부 설정
 *
 * @param array $item 단일 아이템 배열
 * @return array      class_online 필드가 추가된 아이템
 */
public function setClassOnline(array $item): array;

/**
 * 전체 callback 체인 실행
 * 체인 순서: formatRow → pointCalculator → setItemLabel → setViewTag → setClassOnline → postProcessor
 *
 * @param array         $rows            DB 조회 행 배열
 * @param array         $options         formatRow 옵션
 * @param string        $order           정렬 기준
 * @param string        $part            상담 분야
 * @param array         $labelTexts      라벨 텍스트 맵
 * @param array         $tagTexts        태그 텍스트 맵
 * @param callable|null $pointCalculator 포인트 계산 콜백 (컨트롤러별 Strategy)
 * @param callable|null $postProcessor   후처리 콜백 (컨트롤러별 커스텀)
 * @return array                         포맷된 아이템 목록
 */
public function formatList(
    array $rows,
    array $options = [],
    string $order = '',
    string $part = '',
    array $labelTexts = [],
    array $tagTexts = [],
    ?callable $pointCalculator = null,
    ?callable $postProcessor = null
): array;
```

#### 2.2.3 응답 명세 (Response Specification)

`formatList()` 반환 배열의 각 요소:

| 필드 | 타입 | 설명 |
|------|------|------|
| `itCode` | string | 아이템 코드 (camelCase) |
| `itTag` | array | 태그 목록 (JSON 파싱 결과) |
| `itCounselField` | array | 상담 분야 (JSON 파싱 결과) |
| `itemLabel` | object | `{partner, new, star, review, counsel}` 불리언 맵 |
| `viewTag` | string | 보기 태그 텍스트 (直近1ヶ月, 累計 등) |
| `viewWinPoint` | float | 평점 (소수점 1자리) |
| `classOnline` | string | 클래스 온라인 여부 (`Y` / `N`) |
| `itOnline` | int | 온콜 상태 (0: 오프라인, 1: 온라인) |

#### 2.2.4 에러 계약 (Error Contract)

| 상황 | 처리 |
|------|------|
| `$rows` 빈 배열 | 빈 배열 `[]` 반환 (예외 미발생) |
| pointCalculator 콜백 예외 | 호출자에서 try-catch로 처리 |
| DB 행 필드 누락 | 기본값(`''`, `[]`, `0`) 으로 채움 |

#### 2.2.5 JSON 예시 (JSON Examples)

**formatList() 반환 단일 요소**:
```json
{
    "itCode": "IT-20260101-001",
    "itTag": ["여성", "30대"],
    "itCounselField": ["연애", "결혼"],
    "itemLabel": {
        "partner": true,
        "new": false,
        "star": true,
        "review": true,
        "counsel": false
    },
    "viewTag": "直近1ヶ月",
    "viewWinPoint": 4.8,
    "classOnline": "Y",
    "itOnline": 1
}
```

---

### IF-INT-003 ShopReservationServiceInterface

#### 2.3.1 목적 (Purpose)

매장 예약 캘린더 데이터 생성과 가용 타임슬롯 계산을 캡슐화한다. 1시간 전 규칙 적용, AM/PM 분리, 과거 날짜 검증을 서버에서 처리하여 클라이언트 로직 최소화.

**위치**: `app/Modules/Commerce/Interfaces/ShopReservationServiceInterface.php`
**구현체**: `ShopReservationService`
**소비자**: `ShopController`

#### 2.3.2 요청 명세 (Request Specification)

```php
/**
 * CalendarHelper 기반 월간 캘린더 데이터 생성
 *
 * @param string $ceCode    상담사 코드 (ce_code)
 * @param string $yearMonth 조회 연월 (YYYYMM 형식, 기본값: 현재 월)
 * @param string $selectOn  선택 날짜 표시 여부
 * @return array            캘린더 데이터 (selectMonth, prevMonth, nextMonth, ableDate[])
 */
public function buildCalendarData(
    string $ceCode,
    string $yearMonth = '',
    string $selectOn = ''
): array;

/**
 * 가용 타임슬롯 조회 (1시간 전 필터 + AM/PM 분리)
 *
 * @param array $post 요청 파라미터 (ce_code, date, st_code 등)
 * @return array      { status, am[], pm[] }
 */
public function getAvailableTimeSlots(array $post): array;
```

#### 2.3.3 응답 명세 (Response Specification)

`buildCalendarData()` 반환:

| 필드 | 타입 | 설명 |
|------|------|------|
| `selectMonth` | string | 조회 월 (`YYYY-MM`) |
| `prevMonth` | string | 이전 월 (`YYYY-MM`) |
| `nextMonth` | string | 다음 월 (`YYYY-MM`) |
| `ableDate` | string[] | 예약 가능 날짜 배열 (`YYYY-MM-DD` 형식) |

`getAvailableTimeSlots()` 반환:

| 필드 | 타입 | 설명 |
|------|------|------|
| `status` | string | `success` / `prev_mont` / `no_reservation` |
| `am` | string[] | 오전 가용 슬롯 (HH:MM 형식) |
| `pm` | string[] | 오후 가용 슬롯 (HH:MM 형식) |

#### 2.3.4 에러 계약 (Error Contract)

| 상황 | status 값 | 처리 |
|------|----------|------|
| 과거 날짜 요청 | `prev_mont` | `am: [], pm: []` 반환. 예외 미발생 |
| 예약 불가 날짜 | `no_reservation` | `am: [], pm: []` 반환 |
| ce_code 미존재 | — | HTTP 404 `NOT_FOUND` |

#### 2.3.5 JSON 예시 (JSON Examples)

**캘린더 조회 요청** (`POST /api/shop/reservation-calendar`):
```json
{
    "ce_code": "CE-20260101-001",
    "yearMonth": "202604"
}
```

**캘린더 조회 응답 (HTTP 200)**:
```json
{
    "data": {
        "selectMonth": "2026-04",
        "prevMonth": "2026-03",
        "nextMonth": "2026-05",
        "ableDate": [
            "2026-04-16",
            "2026-04-17",
            "2026-04-18",
            "2026-04-21",
            "2026-04-22"
        ]
    }
}
```

> `ableDate`: CalendarHelper가 생성한 월 데이터에서 휴무일 및 예약 마감일을 제외한 결과.

**타임슬롯 조회 요청** (`POST /api/shop/order-reservation-time`):
```json
{
    "ce_code": "CE-20260101-001",
    "date": "2026-04-16"
}
```

**타임슬롯 조회 응답 (HTTP 200 — 정상)**:
```json
{
    "data": {
        "status": "success",
        "am": ["09:00", "09:20", "09:40", "10:00", "10:20"],
        "pm": ["13:00", "13:20", "14:00", "14:20", "15:00"]
    }
}
```

**타임슬롯 조회 응답 (HTTP 200 — 과거 날짜)**:
```json
{
    "data": {
        "status": "prev_mont",
        "am": [],
        "pm": []
    }
}
```

> - `am`/`pm`: 현재 시각 + 1시간 이후 슬롯만 포함.
> - 이미 예약된 슬롯과 `rest_time`(상담사 휴식)은 제외.
> - `sales_time | rest_time | can_reserv_time`을 파이프(`|`) 구분자로 분리하여 처리.
>
> **SSOT 정렬 노트 (COMMERCE-SHOP-DEF-005)**: `shop-api.md`/`shop-api.yaml`의 `order-reservation-time` 응답이 `data.timeSlots[]`로, `reservation-calendar` 응답이 `data.calendar{}`로 잘못 기술되어 있다. 본 IDD의 `data.{ status, am[], pm[] }` 구조 및 `data.{ selectMonth, prevMonth, nextMonth, ableDate[] }` 구조가 실제 `ShopReservationService` 동작과 일치하며, 이를 기준(SSOT)으로 한다. API 문서는 본 IDD 기준으로 갱신이 필요하다.

---

### IF-INT-004 GoodsRepositoryInterface

#### 2.4.1 목적 (Purpose)

`tb_goods_sell` 테이블에 대한 CRUD 및 상태 갱신 추상화. `BaseRepositoryInterface` 상속.

#### 2.4.2 요청 명세 (Request Specification)

```php
public function updateConfirm(int $gsNo): bool;
// gs_status를 다음 상태로 갱신 (상태 머신 단방향 전이 보장)
// 추가로 BaseRepositoryInterface의 insert(), update(), delete(), findById() 상속

/**
 * 주문(gs_no) 소유권 확인 (POST /api/goods/memosave — Caller only, FR-008-9)
 *
 * @param int    $gsNo 주문 번호 (tb_goods_sell.gs_no)
 * @param string $acId 요청자 계정 ID (tb_account.ac_id)
 * @return bool        요청자가 소유한 주문이면 true
 */
public function isOrderOwner(int $gsNo, string $acId): bool;

/**
 * 상품 옵션 소유권 확인 (DELETE /api/goods/delete-opt — Caller only, FR-008-10)
 *
 * @param int    $optNo 옵션 번호 (tb_goods_sell 연관 옵션 레코드)
 * @param string $acId  요청자 계정 ID
 * @return bool         요청자가 소유한 옵션이면 true
 */
public function isOptOwner(int $optNo, string $acId): bool;

/**
 * 상품 파일 소유권 확인 (DELETE /api/goods/delete-file — Caller only, FR-008-11)
 *
 * @param string $fileKey 파일 키 (파일 식별자)
 * @param string $acId    요청자 계정 ID
 * @return bool           요청자가 소유한 파일이면 true
 */
public function isFileOwner(string $fileKey, string $acId): bool;
```

#### 2.4.3 응답 명세 (Response Specification)

| 메서드 | 반환 타입 | 설명 |
|--------|---------|------|
| `updateConfirm()` | `bool` | 성공 시 `true`, 대상 미존재 시 `false` |
| `isOrderOwner()` | `bool` | 소유 확인 시 `true`, 불일치 시 `false` |
| `isOptOwner()` | `bool` | 소유 확인 시 `true`, 불일치 시 `false` |
| `isFileOwner()` | `bool` | 소유 확인 시 `true`, 불일치 시 `false` |

#### 2.4.4 에러 계약 (Error Contract)

| 상황 | 반환값 | 처리 |
|------|-------|------|
| gs_no 미존재 (`updateConfirm`) | `false` | 서비스 레이어에서 NotFoundException 변환 |
| DB 오류 | Exception | 서비스 레이어에서 InternalException 변환 |
| 소유권 불일치 (`isOrderOwner` / `isOptOwner` / `isFileOwner`) | `false` | 컨트롤러에서 HTTP 403 + `FORBIDDEN` 반환 (FR-008-9~11, §4 Unified Error Contract 참조) |

#### 2.4.5 JSON 예시 (JSON Examples)

해당 없음 (PHP 내부 DI 인터페이스).

---

### IF-INT-005 ItemsRepositoryInterface

#### 2.5.1 목적 (Purpose)

`tb_items` 및 연관 테이블 조회 추상화. 아이템-계정-상담사 JOIN 쿼리 제공.

#### 2.5.2 요청 명세 (Request Specification)

```php
/**
 * 아이템 + 계정 정보 JOIN 조회
 * @param string $select  SELECT 절 컬럼 목록
 * @param string $ceCode  상담사 코드
 * @param string $stCode  사이트 코드
 */
public function getItemAccountInfo(string $select, string $ceCode, string $stCode): ?array;

/**
 * 아이템 + 상담사 정보 JOIN 조회
 * @param string $select  SELECT 절 컬럼 목록
 * @param string $itCode  아이템 코드
 * @param string $stCode  사이트 코드
 */
public function getItemCalleeInfo(string $select, string $itCode, string $stCode): ?array;

/**
 * 아이템 단건 조회 (필드 지정)
 * @param array  $fields SELECT 컬럼 배열
 * @param string $select 검색 값
 * @param string $table  검색 컬럼명
 */
public function getItemInfo(array $fields, string $select, string $table): ?array;

/**
 * 아이템 상세 단건 조회 (GET /api/items/get-item)
 *
 * @param array $conditions 검색 조건 배열 (예: ['it_code' => 'IT-001', 'st_code' => 'hongcafe'])
 * @return array|null        ItemRow 배열 또는 null (미존재 시)
 */
public function getItem(array $conditions): ?array;
```

#### 2.5.3 응답 명세 (Response Specification)

`getItemAccountInfo()`, `getItemCalleeInfo()`, `getItemInfo()`: `?array` — 결과 존재 시 연관 배열, 미존재 시 `null`

`getItem()` 반환 `ItemRow` 필드 (API 응답의 `data.item` 객체에 대응):

| 필드 (DB) | 필드 (API camelCase) | 타입 | 설명 |
|----------|-------------------|------|------|
| `it_code` | `itCode` | string | 아이템 코드 (PK) |
| `it_counsel_field` | `itCounselField` | array | 상담 분야 (JSON 파싱) |
| `it_tag` | `itTag` | array | 태그 목록 (JSON 파싱) |
| `it_online` | `itOnline` | int | 온콜 상태 (0: 오프라인, 1: 온라인) |
| `it_coin_price` | `itCoinPrice` | int | 코인 가격 |
| `it_060_price` | `it060Price` | int | 60분 가격 |
| `it_style` | `itStyle` | string | 스타일 분류 |
| `it_name` | `itName` | string | 아이템명 |
| `it_new` | `itNew` | string | 신규 여부 (`Y`/`N`) |

> **Open Question (COMMERCE-ITEMS-DEF-007)**: `ItemsController::getItem()` 현재 구현체가 `$item = []` 빈 배열을 반환하는 상태로 미완성. 위 필드 목록은 `tb_items` 스키마와 IDD §5.2 ItemRow VO 기준의 설계 기준값이다. 구현 완성 시 실제 반환 필드를 검증하여 본 명세를 갱신해야 한다.

#### 2.5.4 에러 계약 (Error Contract)

| 상황 | 반환값 |
|------|-------|
| 조회 결과 없음 | `null` |
| DB 오류 | Exception 발생 |

#### 2.5.5 JSON 예시 (JSON Examples)

해당 없음 (PHP 내부 DI 인터페이스).

---

### IF-INT-006 ShopRepositoryInterface

#### 2.6.1 목적 (Purpose)

`tb_shop_reservation` 테이블 CRUD 및 예약 가능 타임슬롯 조회. `BaseRepositoryInterface` 상속.

#### 2.6.2 요청 명세 (Request Specification)

```php
// BaseRepositoryInterface 상속: insert(), update(), delete(), findById()
public function shopAbleReservTime(string $ceCode, string $date): ?array;
// sales_time, rest_time, can_reserv_time 조회 (파이프 구분 문자열 반환)

/**
 * 상담사 메모 저장 (POST /api/shop/memosave — Callee only)
 *
 * @param string $ceCode   상담사 코드
 * @param string $srNo     예약 번호
 * @param string $memoText 메모 내용
 * @return bool            성공 시 true
 */
public function saveMemo(string $ceCode, string $srNo, string $memoText): bool;

/**
 * 샵 옵션 삭제 (DELETE /api/shop/delete-opt — Callee only)
 *
 * @param string $ceCode 상담사 코드 (소유권 확인용)
 * @param int    $optNo  옵션 번호
 * @return bool          성공 시 true
 */
public function deleteOpt(string $ceCode, int $optNo): bool;

/**
 * 샵 프로필 정보 갱신 (POST /api/shop/update-shop — Callee only)
 *
 * @param string $ceCode 상담사 코드
 * @param array  $data   갱신할 필드 배열 (변경 대상 컬럼/값 포함)
 * @return bool          성공 시 true
 */
public function updateShop(string $ceCode, array $data): bool;

/**
 * 샵 공개 여부 토글 (POST /api/shop/update-shop-view — Callee only)
 *
 * @param string $ceCode  상담사 코드
 * @param string $shView  공개 여부 ('Y' | 'N')
 * @return array          갱신 후 { shView: string } 반환
 */
public function updateShopView(string $ceCode, string $shView): array;

/**
 * 샵 미리보기 데이터 조회 (POST /api/shop/preview-shop — Callee only)
 *
 * @param string $ceCode 상담사 코드
 * @return array|null    샵 전체 프로필 데이터 또는 null
 */
public function previewShop(string $ceCode): ?array;
```

#### 2.6.3 응답 명세 (Response Specification)

| 메서드 | 반환 타입 | 설명 |
|--------|---------|------|
| `shopAbleReservTime()` | `?array` | `{ sales_time: "09:00\|09:20\|...", rest_time: "12:00\|...", can_reserv_time: "09:00\|09:20\|..." }` |
| `saveMemo()` | `bool` | 성공 시 `true` |
| `deleteOpt()` | `bool` | 성공 시 `true` |
| `updateShop()` | `bool` | 성공 시 `true` |
| `updateShopView()` | `array` | `{ "shView": "Y" }` — 갱신 후 현재 공개 여부 |
| `previewShop()` | `?array` | 샵 전체 프로필 배열 또는 `null` |

#### 2.6.4 에러 계약 (Error Contract)

| 상황 | 반환값 | 처리 |
|------|-------|------|
| ce_code 또는 date 미존재 (`shopAbleReservTime`) | `null` | 서비스 레이어에서 no_reservation 처리 |
| optNo 소유권 불일치 (`deleteOpt`) | `false` | 서비스 레이어에서 ForbiddenException 변환 |
| ceCode 미존재 (`updateShop`, `updateShopView`, `previewShop`) | `false` / `null` | 서비스 레이어에서 NotFoundException 변환 |

#### 2.6.5 JSON 예시 (JSON Examples)

**updateShopView() 응답**:
```json
{ "shView": "Y" }
```

**previewShop() 호출 후 API 응답** (`POST /api/shop/preview-shop`):
```json
{
    "data": {
        "ceCode": "CE-20260101-001",
        "shView": "Y",
        "itName": "상담사 이름",
        "itOnline": 1
    }
}
```

---

### IF-INT-007 ItemPriceLogRepositoryInterface

#### 2.7.1 목적 (Purpose)

`tb_item_price_log` 테이블에 가격 변경 이력을 기록한다. `BaseRepositoryInterface` 상속.

#### 2.7.2 요청 명세 (Request Specification)

```php
// BaseRepositoryInterface 상속: insert(), findById()
// 가격 변경 시 insert()로 이력 행 삽입
// 컬럼: it_code, before_price, after_price, changed_at(DATETIME UTC)
```

#### 2.7.3 응답 명세 (Response Specification)

`insert()`: `bool` — 성공 시 `true`

#### 2.7.4 에러 계약 (Error Contract)

| 상황 | 처리 |
|------|------|
| DB 오류 | Exception 발생. 서비스 레이어 롤백 |

#### 2.7.5 JSON 예시 (JSON Examples)

해당 없음 (PHP 내부 DI 인터페이스).

---

### IF-INT-008 SpecialPriceRepositoryInterface

#### 2.8.1 목적 (Purpose)

특가/페이백 이벤트 데이터 조회 추상화. `BaseRepositoryInterface` 상속.

#### 2.8.2 요청 명세 (Request Specification)

```php
/**
 * 페이백 옵션 활성화 여부 조회
 * @param string $stCode 사이트 코드
 * @param string $itCode 아이템 코드
 * @return array|null 페이백 설정 배열
 */
public function getPaybackOptOn(string $stCode, string $itCode): ?array;

/**
 * 사용자 페이백 대상 여부 확인
 * @param string $esCode 이벤트 코드
 * @param string $itCode 아이템 코드
 * @param string $acId   계정 ID
 * @param string $stCode 사이트 코드
 * @return bool 대상 여부
 */
public function checkPaybackUser(
    string $esCode,
    string $itCode,
    string $acId,
    string $stCode
): bool;
```

#### 2.8.3 응답 명세 (Response Specification)

| 메서드 | 반환 타입 | 설명 |
|--------|---------|------|
| `getPaybackOptOn()` | `?array` | 페이백 설정 배열 또는 `null` |
| `checkPaybackUser()` | `bool` | 대상이면 `true` |

#### 2.8.4 에러 계약 (Error Contract)

| 상황 | 반환값 |
|------|-------|
| 이벤트 미존재 | `null` / `false` |

#### 2.8.5 JSON 예시 (JSON Examples)

**특가 목록 응답** (`POST /api/special-prices/get-list`):
```json
{
    "data": [
        {
            "itCode": "IT-20260101-001",
            "itName": "プロカウンセリング",
            "originalPrice": 5000,
            "specialPrice": 3000,
            "discountRate": 40,
            "paybackEnabled": true,
            "paybackAmount": 300
        }
    ],
    "meta": {
        "currentPage": 1,
        "perPage": 10,
        "total": 5,
        "lastPage": 1
    }
}
```

---

## 3. 외부 인터페이스 (External Interfaces)

### IF-EXT-001 Stripe Payment Gateway

#### 3.1.1 목적 (Purpose)

매장/상품 결제 처리 및 환불. Stripe PHP SDK를 통해 PaymentIntent 생성, 확정, 환불을 처리한다. 멱등키로 이중 청구를 방지한다.

#### 3.1.2 요청 명세 (Request Specification)

| 항목 | 값 |
|------|-----|
| 대상 시스템 | Stripe Payment Gateway |
| 프로토콜 | HTTPS REST (Stripe PHP SDK) |
| 인증 | Secret Key (`STRIPE_SECRET_KEY` 환경변수) |
| SDK | `stripe/stripe-php` Composer 패키지 |
| 멱등키 | `['idempotency_key' => uuid_v4()]` — 모든 PaymentIntent 생성 시 필수 |

**주요 호출 패턴**:
```php
$paymentIntent = \Stripe\PaymentIntent::create([
    'amount'   => $amount,
    'currency' => 'jpy',
    'metadata' => ['order_id' => $orderId],
], ['idempotency_key' => $idempotencyKey]);
```

#### 3.1.3 응답 명세 (Response Specification)

| 항목 | 설명 |
|------|------|
| 결제 생성 성공 | `client_secret` 반환 → 프론트엔드 Stripe.js로 전달 |
| 환불 성공 | `Stripe\Refund` 객체 반환. `tb_goods_sell.gs_status` 또는 `tb_shop_reservation.sr_status` 갱신 |

#### 3.1.4 에러 계약 (Error Contract)

| Stripe 에러 | HTTP 코드 | 에러 코드 | 처리 |
|-----------|----------|----------|------|
| 카드 거절 | 400 | `INVALID_INPUT` | 다른 카드 안내 |
| 잘못된 금액 | 400 | `INVALID_INPUT` | 금액 재확인 |
| 네트워크 오류 | 500 | `INTERNAL` | 멱등키로 재시도 |
| Webhook 서명 불일치 | 400 | `INVALID_INPUT` | 보안 로그 기록 |

#### 3.1.5 JSON 예시 (JSON Examples)

**PaymentIntent 생성 요청 (내부)**:
```json
{
    "amount": 3000,
    "currency": "jpy",
    "metadata": {
        "order_id": "GS-20260416-001",
        "ac_id": "AC-001"
    }
}
```

**PaymentIntent 생성 응답**:
```json
{
    "client_secret": "pi_3Qxxx_secret_yyy",
    "id": "pi_3Qxxx",
    "status": "requires_payment_method"
}
```

**환불 성공 웹훅 (`charge.refunded`)**:
```json
{
    "type": "charge.refunded",
    "data": {
        "object": {
            "id": "ch_3Qxxx",
            "amount_refunded": 3000,
            "refunded": true
        }
    }
}
```

---

### IF-EXT-002 NaverPay

#### 3.2.1 목적 (Purpose)

한국 사용자의 NaverPay 결제 처리 및 환불. Reserve → Approve 2단계 플로우.

#### 3.2.2 요청 명세 (Request Specification)

| 항목 | 값 |
|------|-----|
| 대상 시스템 | NaverPay |
| 프로토콜 | HTTPS REST |
| 인증 | Partner ID + Secret Key (환경변수) |
| 멱등키 | merchantPayKey 필드로 주문 고유 식별 |

#### 3.2.3 응답 명세 (Response Specification)

| 단계 | 설명 |
|------|------|
| Reserve | 결제 URL(`paymentUrl`) 발급. 프론트엔드로 전달 |
| Approve | 결제 최종 확정. `paymentId` 저장 |
| Cancel | 취소 완료. `tb_shop_reservation.sr_status = 'cancelled'` 갱신 |

#### 3.2.4 에러 계약 (Error Contract)

| 상황 | HTTP 코드 | 에러 코드 |
|------|----------|----------|
| 결제 실패 | 400 | `INVALID_INPUT` |
| 중복 merchantPayKey | 409 | `CONFLICT` |
| NaverPay 서버 오류 | 500 | `INTERNAL` |

#### 3.2.5 JSON 예시 (JSON Examples)

**Reserve 응답**:
```json
{
    "code": "Success",
    "message": "",
    "body": {
        "paymentId": "NPay_20260416_001",
        "paymentUrl": "https://pay.naver.com/..."
    }
}
```

---

### IF-EXT-003 FCM (Firebase Cloud Messaging)

#### 3.3.1 목적 (Purpose)

주문 확인/완료 알림, Q&A 등록 알림을 상담사/사용자에게 푸시 발송한다.

#### 3.3.2 요청 명세 (Request Specification)

| 항목 | 값 |
|------|-----|
| 대상 시스템 | Firebase Cloud Messaging |
| 프로토콜 | HTTPS REST (FCM v1 API) |
| 인증 | Firebase Service Account (환경변수) |
| 발송 조건 | `qna_fcm_use='Y'` — 상담사 FCM 수신 설정 확인 후 발송 |

#### 3.3.3 응답 명세 (Response Specification)

| 결과 | 처리 |
|------|------|
| 성공 | FCM message ID 반환 |
| 실패 | 로그 기록만. 트랜잭션 롤백 없음 |

#### 3.3.4 에러 계약 (Error Contract)

| 상황 | 처리 |
|------|------|
| FCM 서버 오류 | 로그 기록 후 무시. 비즈니스 로직에 영향 없음 |
| 토큰 만료 | 토큰 갱신 후 재시도 (최대 1회) |

#### 3.3.5 JSON 예시 (JSON Examples)

**FCM 발송 페이로드**:
```json
{
    "message": {
        "token": "device-fcm-token-here",
        "notification": {
            "title": "購入確定",
            "body": "販売した商品の購入が確定されました。"
        },
        "data": {
            "gs_no": "1234",
            "type": "goods_confirm"
        }
    }
}
```

> 현재 알림 메시지는 일본어 고정. 다국어 확장 시 `lang('commerce.goods_buy_confirmed', [], 'ja')` 형태로 전환 권장.

---

### IF-EXT-004 AWS S3 / IMG_SERVER

#### 3.4.1 목적 (Purpose)

리뷰 이미지(AWS S3), 상담사 작업 파일(IMG_SERVER) 업로드/다운로드/삭제. 모든 업로드 전 MIME 이중 검증 필수.

#### 3.4.2 요청 명세 (Request Specification)

| 항목 | 값 |
|------|-----|
| S3 대상 | 리뷰 이미지 (`review/` 경로) |
| IMG_SERVER 대상 | 상담사 작업 파일, 클래스 파일 |
| S3 프로토콜 | AWS SDK (`Awss3` 라이브러리) |
| IMG_SERVER 프로토콜 | cURL |
| MIME 검증 | 확장자 whitelist + `mime_content_type()` (서버 레벨) |
| 허용 타입 (이미지) | jpg, png, gif, webp |
| 허용 타입 (문서) | pdf, doc, docx, xls, xlsx, zip |
| 다운로드 제한 | 구매 확정(`gs_status=3`) 후 14일 이내 |

#### 3.4.3 응답 명세 (Response Specification)

| 동작 | 응답 |
|------|------|
| 업로드 성공 | S3 URL 또는 IMG_SERVER 파일 경로 반환 |
| 다운로드 | Pre-signed URL 발급 (유효기간 제한) |
| 삭제 | 성공 여부 `bool` |

#### 3.4.4 에러 계약 (Error Contract)

| 상황 | HTTP 코드 | 에러 코드 |
|------|----------|----------|
| MIME 검증 실패 | 400 | `INVALID_INPUT` |
| 파일 크기 초과 | 400 | `INVALID_INPUT` |
| S3 업로드 실패 | 500 | `INTERNAL` |
| 다운로드 기간 초과 | 403 | `FORBIDDEN` |

#### 3.4.5 JSON 예시 (JSON Examples)

**파일 업로드 성공 응답**:
```json
{
    "data": {
        "fileUrl": "https://s3.ap-northeast-1.amazonaws.com/hongcafe-review/2026/04/review_1234.jpg",
        "fileName": "review_1234.jpg"
    }
}
```

**MIME 검증 실패 응답**:
```json
{
    "error": {
        "code": "INVALID_INPUT",
        "message": "허용되지 않는 파일 형식입니다. (jpg, png, gif, webp, pdf, doc, docx, xls, xlsx, zip만 허용)"
    }
}
```

---

### IF-EXT-005 Chat API (Internal HTTP)

#### 3.5.1 목적 (Purpose)

상담사 작업 완료(`callee-o2o-job`, `callee-goods-job`) 시 관련 채팅방에 시스템 알림 메시지를 발송한다.

#### 3.5.2 요청 명세 (Request Specification)

| 항목 | 값 |
|------|-----|
| 대상 시스템 | Chat 모듈 (내부 HTTP 호출) |
| 프로토콜 | 내부 HTTPS REST |
| 인증 | Internal API Key (서버 간 통신) |
| 발송 조건 | 상담사 작업 파일 업로드 완료 후 |

#### 3.5.3 응답 명세 (Response Specification)

| 결과 | 처리 |
|------|------|
| 성공 | 채팅방에 시스템 메시지 전송 완료 |
| 실패 | 로그 기록. 작업 완료 처리 자체는 롤백 없음 |

#### 3.5.4 에러 계약 (Error Contract)

| 상황 | 처리 |
|------|------|
| Chat API 서버 오류 | try-catch로 격리. 작업 완료 트랜잭션에 영향 없음 |
| 채팅방 미존재 | 로그 기록 후 무시 |

#### 3.5.5 JSON 예시 (JSON Examples)

**Chat API 요청 (내부)**:
```json
{
    "room_id": "CHAT-20260416-001",
    "message_type": "system",
    "content": "상담사가 작업을 완료했습니다. 파일을 확인해 주세요.",
    "metadata": {
        "gs_no": 1234,
        "file_url": "https://img-server.hongcafe.com/works/file_1234.pdf"
    }
}
```

**Chat API 응답 (HTTP 200)**:
```json
{
    "data": {
        "messageId": "MSG-20260416-001",
        "sentAt": "2026-04-16T10:30:00Z"
    }
}
```

---

## 4. 에러 처리 계약 통합 (Unified Error Contract)

| 상황 | HTTP 코드 | 에러 코드 | 소비자 대응 |
|------|----------|----------|-----------|
| 입력값 검증 실패 | 400 | `INVALID_INPUT` | 입력값 수정 후 재시도 |
| MIME 검증 실패 | 400 | `INVALID_INPUT` | 허용 파일 형식 확인 |
| 미인증 | 401 | `UNAUTHORIZED` | 로그인 (hc_access 쿠키 갱신) |
| 비 상담사 접근 | 403 | `FORBIDDEN` | role:callee 권한 안내 |
| 24시간 취소 규칙 위반 | 403 | `FORBIDDEN` | 24시간 전 취소 안내 |
| 파일 다운로드 기간 초과 | 403 | `FORBIDDEN` | 구매 후 14일 이내만 허용 안내 |
| `DELETE /api/goods/delete-opt` — 옵션 소유권 불일치 | 403 | `FORBIDDEN` | 본인 소유 옵션만 삭제 가능. 요청 파라미터의 옵션 번호가 요청자의 ac_id와 연결된 주문에 속하지 않을 때 반환. (FR-008-10) |
| `DELETE /api/goods/delete-file` — 파일 소유권 불일치 | 403 | `FORBIDDEN` | 본인 소유 파일만 삭제 가능. 요청 파라미터의 파일 키가 요청자의 ac_id와 연결된 주문에 속하지 않을 때 반환. (FR-008-11) |
| `POST /api/goods/memosave` — 주문(gs_no) 소유권 불일치 | 403 | `FORBIDDEN` | 본인 주문에만 메모 저장 가능. 요청 파라미터의 gs_no가 요청자의 ac_id와 연결되지 않을 때 반환. (FR-008-9) |
| 상품/매장 미존재 | 404 | `NOT_FOUND` | 재조회 |
| 예약 시간 중복 | 409 | `CONFLICT` | 다른 시간 선택 |
| 즐겨찾기 중복 (`POST /api/items/item-add-like` — 동일 it_code 중복 추가) | 409 | `CONFLICT` | 중복 추가 안내. FR-002-1 준수 |
| 활성 판매 존재 (삭제 불가) | 409 | `CONFLICT` | 판매 완료 후 삭제 안내 |
| Q&A 스팸 방지 (`POST /api/items/insert-item-qna` — 5분 이내 동일 아이템 재작성) | 429 | `TOO_MANY_REQUESTS` | 5분 후 재시도. FR-003-4 준수 |
| Stripe PG 오류 | 500 | `INTERNAL` | 멱등키로 재시도 |
| S3/IMG_SERVER 업로드 오류 | 500 | `INTERNAL` | 재시도 |
| FCM 발송 실패 | — | — | 로그만 기록 (클라이언트 노출 없음) |
| Chat API 실패 | — | — | 로그만 기록 (클라이언트 노출 없음) |

---

## 5. 데이터 포맷 정의 (Data Format Definitions)

### 5.1 GoodsSell DTO

| 필드 (DB) | 필드 (API camelCase) | 타입 | 설명 |
|----------|-------------------|------|------|
| `gs_no` | `gsNo` | int | 주문 번호 (PK) |
| `gd_code` | `gdCode` | string | 상품 코드 |
| `gs_status` | `gsStatus` | int | 주문 상태 (0-5) |
| `gs_price` | `gsPrice` | int | 가격 |
| `ac_id` | `acId` | string | 구매자 |
| `ce_code` | `ceCode` | string | 판매자 (상담사) |
| `cancel_date` | `cancelDate` | datetime\|null | 취소 일시 (UTC) |
| `messageId` | `messageId` | string | SendBird 견적 메시지 ID |

### 5.2 ItemRow VO

| 필드 (DB) | 필드 (API camelCase) | 타입 | 설명 |
|----------|-------------------|------|------|
| `it_code` | `itCode` | string | 아이템 코드 |
| `it_tag` | `itTag` | array | 태그 목록 (JSON 파싱) |
| `it_counsel_field` | `itCounselField` | array | 상담 분야 (JSON 파싱) |
| `item_label` | `itemLabel` | object | `{partner, new, star, review, counsel}` |
| `view_tag` | `viewTag` | string | 보기 태그 |
| `view_win_point` | `viewWinPoint` | float | 평점 |
| `class_online` | `classOnline` | string | Y / N |

### 5.3 ReservationSlot VO

| 필드 | 타입 | 설명 |
|------|------|------|
| `status` | string | `success` / `prev_mont` / `no_reservation` |
| `am` | string[] | 오전 슬롯 (HH:MM) |
| `pm` | string[] | 오후 슬롯 (HH:MM) |

---

## 6. 체크리스트 (Interface Verification Checklist)

### 완전성

- [x] 내부 인터페이스 전체 정의 (8건, IF-INT-004 소유권 검증 3메서드 추가, IF-INT-005 getItem() 추가, IF-INT-006 5개 메서드 추가, 5-Subsection 완전)
- [x] 외부 인터페이스 전체 정의 (5건, 5-Subsection 완전)
- [x] 에러 처리 계약 통합 정의 (18건 — goods 소유권 403 3건, 즐겨찾기 409 상세화, Q&A 429 상세화 추가)
- [x] 데이터 포맷 DTO/VO 정의 (3종)
- [x] JSON 예시 전체 EP 커버 (buy-confirm, calendar, timeslot, special-price, S3, FCM, Chat API, updateShopView, previewShop)

### 일관성

- [x] SDD 클래스 ↔ 인터페이스 매핑 일치
- [x] 에러 코드 체계 통일 (프로젝트 표준: `INVALID_INPUT`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`, `INTERNAL`)
- [x] DB snake_case ↔ API camelCase 변환 명시
- [x] JSON 예시 ↔ 데이터 포맷 DTO 일치

### 추적성

- [x] SDD 클래스 ↔ IDD 인터페이스 매핑
- [x] 외부 IF ↔ 에러 처리 계약 매핑
- [x] JSON 예시 ↔ SRS UC 매핑 (UC-001, UC-002, UC-003, UC-004)

---

## 7. 타당성 검토 (Feasibility Review)

MIL-STD-498 §5 — 인터페이스 설계 결정의 기술적 실현 가능성을 공식 근거와 함께 검토한다.

| 설계 결정 | 채택 패턴/표준 | 근거 출처 | 검토 결과 |
|-----------|-------------|----------|---------|
| Interface Only 모듈 간 통신 | Dependency Inversion Principle (SOLID) | Robert C. Martin "Clean Architecture": "High-level modules should not depend on low-level modules. Both should depend on abstractions." | 적합. GoodsController → GoodsPurchaseServiceInterface 의존. 구현체 교체 시 Controller 무변경. Mock 주입으로 단위 테스트 용이 |
| Stripe PHP SDK + idempotency_key | Stripe API Best Practices | Stripe 공식 문서: "Supply an idempotency key when making any API request to prevent duplicate operations if a request fails and is retried." | 필수 준수. 네트워크 타임아웃 후 재시도 시 PaymentIntent 중복 생성 방지. `['idempotency_key' => uuid_v4()]` 적용 |
| FCM 실패 격리 (비즈니스 로직 무영향) | 결함 격리 패턴 (Bulkhead Pattern) | Netflix OSS Hystrix 패턴: "Isolate points of access to remote services... to stop cascading failures." | 적합. FCM 발송 실패가 구매 확정 트랜잭션을 롤백하지 않도록 try-catch로 격리. 로그만 기록 |
| MIME 이중 검증 (S3 업로드 전) | OWASP File Upload Cheat Sheet | OWASP: "Ensure the file is processed as expected... verify the file is a valid image after upload." AWS S3도 업로드 전 클라이언트 측 검증 권고 | 필수 준수. S3 업로드 전 mime_content_type() 매직 바이트 검사. 악성 파일 S3 저장 사전 차단 |
| AM/PM 타임슬롯 분리 서버 처리 | UX 패턴 + 보안 | Nielsen Norman Group 사용성 지침: 오전/오후 섹션 분리가 예약 UI 인지 부하 감소에 유효. 서버 처리로 1시간 전 규칙 우회 방지 | 적합. 서버에서 필터링 + 분리 제공. 클라이언트는 렌더링만. 규칙 우회 불가 |
| FCM 다국어 — 현재 일본어 고정 | 국제화(i18n) 정책 | 프로젝트 global-context — 1차 타겟 일본. lang() 키 사용 원칙이나 FCM 서버 발송은 수신자 언어와 무관 | 검토 필요. 현재 일본어 하드코딩. 다국어 확장 시 `lang('commerce.goods_buy_confirmed', [], 'ja')` 전환 권장 (기술 부채 등록) |

---

## 8. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|-------|---------|
| MIL-STD-498 5-Subsection 구조 적용 | 각 인터페이스가 목적/요청/응답/에러/예시 5개 관점에서 완전 정의됨 | 단순 시그니처 나열에서 벗어나 계약 완전성 확보. 신규 개발자가 문서만으로 인터페이스 이해 가능 |
| JSON 예시 전체 인터페이스 커버 | buy-confirm, calendar, timeslot, special-price, S3, FCM, Chat API 전 EP 예시 제공 | IDD에 시그니처만 있고 JSON 예시 없으면 프론트엔드 팀 시행착오 발생 → 예시 추가로 개발 리드타임 단축 |
| 에러 처리 계약 통합표 신설 | 14개 에러 상황을 단일 표로 통합. 소비자 대응 방법 명시 | 분산된 에러 계약으로 인한 클라이언트 에러 핸들링 누락 위험 → 통합 참조 테이블로 일관성 보장 |
| FCM 격리 설계 문서화 | 알림 실패가 비즈니스 트랜잭션에 영향 없음을 명시 | FCM 장애 시 구매 확정 롤백 여부에 대한 개발자 혼란 방지 |
| 데이터 포맷 DB↔API 변환 명시 | snake_case(DB) → camelCase(API) 변환 규칙을 DTO 표에 명시 | 변환 누락으로 인한 프론트엔드 필드명 불일치 버그 방지 |
| GoodsRepositoryInterface 소유권 검증 메서드 3개 추가 (IF-INT-004: isOrderOwner/isOptOwner/isFileOwner) | goods Caller EP(memosave/delete-opt/delete-file)의 소유권 검증 계약이 Repository 인터페이스 레벨에서 명시됨. §4 에러 계약과의 추적성 확보 | FR-008-9~11 요구사항(Caller 소유권 검증 필수)이 Repository 인터페이스에 미반영된 상태였음. 계약 부재 시 구현체가 소유권 검증을 누락할 위험 — 인터페이스 계약으로 검증 강제화 (OWASP API5:2023 준수) |
| IF-INT-003 §2.3.5 SSOT 정렬 노트 추가 (COMMERCE-SHOP-DEF-005) | IDD의 `data.{ status, am[], pm[] }` 및 `data.{ selectMonth, prevMonth, nextMonth, ableDate[] }` 구조가 ShopReservationService 실제 동작 기준(SSOT)임을 명시. API 문서 갱신 요청 포함 | shop-api.md/yaml은 `data.timeSlots[]` / `data.calendar{}` 구조로 잘못 기술되어 있으며, IDD가 더 정확하다. 3자 불일치(API/IDD/코드) 상태를 IDD에서 명시적으로 지적하여 API 문서 갱신 작업 추적성 확보 |
| IF-INT-006 ShopRepositoryInterface에 5개 메서드 추가 (COMMERCE-SHOP-DEF-007) | shop EP 5개(memosave/delete-opt/update-shop/update-shop-view/preview-shop)의 Repository 계약이 인터페이스 레벨에서 명시됨. 5-Subsection(목적/요청/응답/에러/예시) 완전 | IF-INT-006에 shopAbleReservTime만 정의되어 있어 callee-only 5개 EP의 Repository 계약이 누락된 상태였음. 계약 부재 시 구현체 시그니처 불일치 위험 — 인터페이스 계약으로 구현 강제화 |

---

## 9. 변경 로그 (Change Log)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| v1.0 | 2026-04-15 | jypark | 초기 작성 |
| v1.1 | 2026-04-15 | jypark | PHP 시그니처 추가, 외부 IF 상세화, 에러 10건, DTO 3종, 데이터 포맷 추가 |
| v1.2 | 2026-04-15 | jypark | JSON 예시 3종 추가, 타당성 검토 5건, 변경 영향 기록 4건 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS. MIL-STD-498 적용. 내부 IF 8건 전체 5-Subsection(목적/요청/응답/에러/예시) 재작성. 외부 IF 5건 5-Subsection 완전 상세화. JSON 예시 전체 커버. 에러 처리 계약 통합표(14건) 신설. 데이터 포맷 DB↔API camelCase 변환 명시. 타당성 검토 6건(FCM 다국어 개선 필요 포함) 재작성. |
| v2.1 | 2026-04-21 | jypark | [A] COMMERCE-GOODS-DEF-003: §4 통합 에러 계약에 goods 일반사용자 소유권 403 계약 3건 추가 (delete-opt/delete-file/memosave FR-008-9~11). IF-INT-004 GoodsRepositoryInterface에 소유권 검증 메서드 3개 추가 (isOrderOwner/isOptOwner/isFileOwner, FR-008-9~11). 즐겨찾기 중복 409 항목 상세화 (FR-002-1 명시). Q&A 429 항목 상세화 (FR-003-4 명시). COMMERCE-ITEMS-DEF-007/012: IF-INT-005에 getItem() 메서드 시그니처 + ItemRow 반환 필드 목록 추가. COMMERCE-SHOP-DEF-005: IF-INT-003 §2.3.5 JSON 예시에 SSOT 정렬 노트 추가 (am/pm, selectMonth/ableDate 구조가 IDD 기준). COMMERCE-SHOP-DEF-007: IF-INT-006에 saveMemo/deleteOpt/updateShop/updateShopView/previewShop 5개 메서드 시그니처 + 응답/에러/예시 추가. |
