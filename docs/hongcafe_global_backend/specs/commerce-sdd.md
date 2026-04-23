---
문서명: Commerce 모듈 소프트웨어 설계 명세서 (SDD)
문서ID: SDD-COMMERCE-001
버전: v2.2
상태: 승인됨
생성일: 2026-04-15
최종수정일: 2026-04-21
작성자: jypark
적용 표준: IEEE 1016-2009
대상 시스템: HongCafe Global Backend — Commerce Module
관련 문서:
  - commerce-srs.md (SRS-COMMERCE-001)
  - commerce-idd.md (IDD-COMMERCE-001)
  - docs/api-specification.md
  - app/Modules/Commerce/
---

# Commerce 모듈 소프트웨어 설계 명세서 (SDD)

> IEEE 1016-2009 준수 (8 Viewpoint) | version: 2.2 | lastUpdated: 2026-04-21 | module: Commerce

---

## 1. 개요 (Overview)

### 1.1 목적 (Purpose)

본 문서는 HongCafe Global Backend Commerce 모듈의 내부 설계를 IEEE 1016-2009 8-Viewpoint 프레임워크에 따라 명세한다. Controller, Service, Repository, Interface의 구조와 책임, DB 스키마 설계, 주요 시퀀스 다이어그램, 아키텍처 결정 기록(ADR), Entity/VO 전환 계획을 포함한다.

This document specifies the internal design of the Commerce module conforming to IEEE 1016-2009 eight-viewpoint framework.

### 1.2 기반 SRS

| 항목 | 내용 |
|------|------|
| 기반 SRS | `commerce-srs.md` (SRS-COMMERCE-001) v3.1 |
| 아키텍처 패턴 | Modular Monolith — Layered (Controller → Service → Repository → Model) |
| 모듈 경로 | `app/Modules/Commerce/` |

---

## 2. 모듈 디렉토리 구조 (Module Directory Structure)

```text
app/Modules/Commerce/
├── Config/
│   ├── Routes.php                       # 72 라우트 명시적 등록 (setAutoRoute(false))
│   └── Services.php                     # DI 바인딩 8개 (모듈 분산, 중앙 등록 금지)
├── Controllers/
│   ├── ItemsController.php              # 1370 lines — 16 EP
│   ├── ShopController.php               # 1425 lines — 26 EP
│   ├── GoodsController.php              # 1805 lines — 30 EP
│   └── SpecialPriceController.php       # 32 lines — 1 EP (EventListTrait)
├── Services/
│   ├── GoodsPurchaseService.php         # 137 lines — confirmPurchase + FCM + 알람
│   ├── ItemListFormatter.php            # 346 lines — 목록 포맷 (callback 체인)
│   └── ShopReservationService.php       # 147 lines — 캘린더 + 타임슬롯
├── Repositories/
│   ├── GoodsRepository.php              # updateConfirm, 상품 CRUD
│   ├── ItemsRepository.php              # getItemAccountInfo, getItemCalleeInfo, getItemInfo
│   ├── ShopRepository.php               # 매장 CRUD, shopAbleReservTime
│   ├── ItemPriceLogRepository.php       # 가격 변경 이력
│   └── SpecialPriceRepository.php       # getPaybackOptOn, checkPaybackUser
├── Interfaces/                          # 8개 (Service 3 + Repository 5)
│   ├── GoodsPurchaseServiceInterface.php
│   ├── ItemListFormatterInterface.php
│   ├── ShopReservationServiceInterface.php
│   ├── GoodsRepositoryInterface.php
│   ├── ItemsRepositoryInterface.php
│   ├── ShopRepositoryInterface.php
│   ├── ItemPriceLogRepositoryInterface.php
│   └── SpecialPriceRepositoryInterface.php
└── Models/
    └── (Shared Models 참조: app/Modules/Shared/Models/)
```

---

## 3. Viewpoint 1 — 컨텍스트 뷰 (Context View)

IEEE 1016-2009 §5.3 Context Viewpoint: 모듈의 외부 시스템 경계와 의존 관계를 정의한다.

### 3.1 모듈 경계

```text
[외부 클라이언트 (Next.js)]
         │ HTTPS REST
         ▼
[Commerce Module]
   ├── Items 도메인  ──────────────► [AWS S3] (리뷰 이미지)
   ├── Shop 도메인   ──────────────► [Stripe / NaverPay] (결제/환불)
   ├── Goods 도메인  ──────────────► [FCM] (푸시 알림)
   │                ──────────────► [IMG_SERVER] (작업 파일)
   │                ──────────────► [Chat API] (채팅방 알림)
   └── SpecialPrice 도메인
         │
         ▼
[Aurora MySQL (RDS Proxy IAM Auth)]
  tb_items, tb_goods_sell, tb_shop_reservation,
  tb_comment, tb_item_price_log
```

### 3.2 모듈 간 의존

| 의존 방향 | 대상 모듈 | 목적 | 통신 방식 |
|----------|----------|------|----------|
| Commerce → Shared | `Modules/Shared/` | BaseRepositoryInterface, 공통 Model | PHP DI |
| Commerce → Member | `MypageRepository::SetAlarm()` | 알람 이력 기록 | service() DI |
| Commerce → Notification | FCM 발송 | 주문/Q&A 알림 | service() DI |
| Commerce → Chat | Chat API | 작업 완료 채팅방 알림 | 내부 HTTP |

---

## 4. Viewpoint 2 — 구성 뷰 (Composition View)

IEEE 1016-2009 §5.4 Composition Viewpoint: 모듈 내부 컴포넌트 구조와 책임을 정의한다.

### 4.1 Controller Layer

| 클래스 | EP 수 | 인증 유형 | 주요 책임 |
|--------|-------|----------|----------|
| `ItemsController` | 16 | JWT (일부 공개) | 아이템 목록/검색/즐겨찾기/Q&A/가격/포스팅 |
| `ShopController` | 26 | JWT (공개 + callee 혼재) | 매장 예약/구매/환불/상담사 스케줄/확인/파일 |
| `GoodsController` | 30 | JWT (공개 + callee 혼재) | 상품 구매/환불/상담사 관리/클래스/FAQ |
| `SpecialPriceController` | 1 | 공개 | 특가 목록 (EventListTrait 위임) |

**필터 체인** (모든 인증 EP 공통):
```
ratelimit → csrftoken → auth → [role:callee] → Controller
```

**컨트롤러 설계 원칙**:
```php
// 컨트롤러는 입력 검증 + 서비스 위임 + 응답 포맷만 담당
// 비즈니스 로직은 Service 레이어에 위임
// camelCase 응답 변환 필수 (snake_case → camelCase)
public function buyConfirm(): ResponseInterface
{
    if (!$this->validate(['gs_no' => 'required|integer'])) {
        return $this->errorResponse('INVALID_INPUT', 400);
    }
    $result = $this->goodsPurchaseService->confirmPurchase(
        (int) $this->request->getPost('gs_no'),
        $this->currentUser->crCode
    );
    return $this->successResponse($result);
}
```

### 4.2 Service Layer

| 클래스 | 크기 | 인터페이스 | 주요 책임 |
|--------|------|----------|----------|
| `GoodsPurchaseService` | 137 lines | `GoodsPurchaseServiceInterface` | 구매 확인 → DB 갱신 → 상담사 FCM → 사용자 FCM → 알람 |
| `ItemListFormatter` | 346 lines | `ItemListFormatterInterface` | callback 체인 기반 목록 포맷 |
| `ShopReservationService` | 147 lines | `ShopReservationServiceInterface` | CalendarHelper 기반 캘린더 + 1시간 전 타임슬롯 |

#### GoodsPurchaseService 상세

| 메서드 | 입력 | 출력 | 설명 |
|--------|------|------|------|
| `confirmPurchase(int $gsNo, string $crCode)` | 주문번호, 구매자 코드 | `array` | gs_status=3 갱신 + 상담사 FCM + 사용자 FCM + SetAlarm() |

#### ItemListFormatter 상세 (callback 체인)

| 메서드 | 입력 | 출력 | 설명 |
|--------|------|------|------|
| `formatRow(array $row, array $options)` | 단일 행 배열 | `array` | 태그/공지/필드/온콜 기본 포맷 |
| `setItemLabel(array $item, string $part, array $labelTexts)` | 아이템, 파트 | `array` | 라벨 태깅 (partner/new/star/review/counsel) |
| `setViewTag(array $item, string $order, array $tagTexts)` | 아이템, 정렬 기준 | `array` | 정렬 기준별 보기 태그 |
| `setClassOnline(array $item)` | 아이템 | `array` | 클래스 온라인 여부 (Y/N) |
| `formatList(array $rows, ..., ?callable $pointCalculator, ?callable $postProcessor)` | 배열 + 콜백 | `array` | 전체 체인 실행 |

**체인 순서**: `formatRow → pointCalculator → setItemLabel → setViewTag → setClassOnline → postProcessor`

#### ShopReservationService 상세

| 메서드 | 입력 | 출력 | 설명 |
|--------|------|------|------|
| `buildCalendarData(string $ceCode, string $yearMonth, string $selectOn)` | 상담사코드, 연월 | `array` | CalendarHelper + 예약가능일 조회 |
| `getAvailableTimeSlots(array $post)` | 요청 파라미터 | `array` | 과거일 검증 + 1시간 전 필터 + AM/PM 분리 + 예약 가능 여부 |

### 4.3 Repository Layer

| 클래스 | 대응 테이블 | 상속 | 주요 추가 메서드 |
|--------|-----------|------|--------------|
| `GoodsRepository` | `tb_goods_sell` | BaseRepositoryInterface | `updateConfirm($gsNo)` |
| `ItemsRepository` | `tb_items` | BaseRepositoryInterface | `getItemAccountInfo()`, `getItemCalleeInfo()`, `getItemInfo()` |
| `ShopRepository` | `tb_shop_reservation` | BaseRepositoryInterface | `shopAbleReservTime()` |
| `ItemPriceLogRepository` | `tb_item_price_log` | BaseRepositoryInterface | 기본 CRUD |
| `SpecialPriceRepository` | (특가 테이블) | BaseRepositoryInterface | `getPaybackOptOn()`, `checkPaybackUser()` |

---

## 5. Viewpoint 3 — 논리 뷰 (Logical View)

IEEE 1016-2009 §5.5 Logical Viewpoint: 핵심 추상화, 도메인 모델, 상태 머신을 정의한다.

### 5.1 주문 상태 머신 (gs_status Finite State Machine)

```text
                   confirmPurchase()
[0: 대기(Pending)] ──────────────► [1: 확인(Confirmed)] ──► [2: 작업완료(Done)]
        │                                                            │
        │                                                    buyConfirm()
        │                                                            │
        └──── buyCancelO() ─────► [4: 취소(Cancelled)] ──►  [3: 구매확정(Settled)]
                                         │
                                  refundSuccess()
                                         │
                                  [5: 환불(Refunded)]
```

- 정방향 전이(`0→1→2→3`, `4→5`)만 허용
- 역방향 전이는 애플리케이션 레벨에서 명시적 차단
- 각 전이 시 `regist_date`, `cancel_date` 등 타임스탬프 기록

### 5.2 Entity/VO 전환 계획

Commerce 모듈은 현재 레거시 배열(`array`) 기반으로 데이터를 처리한다. 모듈형 모놀리스 마이그레이션 완료 후 아래 클래스로 전환 예정이다.

| 대상 | 현재 형태 | 전환 예정 클래스 | 우선순위 |
|------|---------|--------------|---------|
| 상품 주문 | `array $goodsSell` | `GoodsSellEntity` | P1 — gs_status 상태 머신 캡슐화 |
| 아이템 목록 행 | `array $row` | `ItemRowVO` | P2 — formatRow 출력 타입 확정 |
| 예약 슬롯 | `array $slot` | `ReservationSlotVO` | P2 — AM/PM 분리 로직 캡슐화 |

---

## 6. Viewpoint 4 — 의존성 뷰 (Dependency View)

IEEE 1016-2009 §5.6 Dependency Viewpoint: 컴포넌트 간 의존 방향과 DI 구성을 정의한다.

### 6.1 DI 등록 구조

```text
app/Modules/Commerce/Config/Services.php
  ├── GoodsPurchaseServiceInterface  → GoodsPurchaseService
  ├── ItemListFormatterInterface     → ItemListFormatter
  ├── ShopReservationServiceInterface → ShopReservationService
  ├── GoodsRepositoryInterface       → GoodsRepository
  ├── ItemsRepositoryInterface       → ItemsRepository
  ├── ShopRepositoryInterface        → ShopRepository
  ├── ItemPriceLogRepositoryInterface → ItemPriceLogRepository
  └── SpecialPriceRepositoryInterface → SpecialPriceRepository
```

**원칙**: 중앙 `app/Config/Services.php`에 바인딩 금지. 모듈별 분산 DI.

### 6.2 컴포넌트 의존 방향

```text
[ItemsController]   →  [ItemListFormatterInterface]  →  [ItemsRepositoryInterface]
[GoodsController]   →  [GoodsPurchaseServiceInterface] → [GoodsRepositoryInterface]
                    →  [MypageRepository::SetAlarm()]   (크로스 모듈 — service() 호출)
[ShopController]    →  [ShopReservationServiceInterface] → [ShopRepositoryInterface]
[SpecialPriceController] → (EventListTrait) → [SpecialPriceRepositoryInterface]
```

---

## 7. Viewpoint 5 — 정보 뷰 (Information View)

IEEE 1016-2009 §5.7 Information Viewpoint: 지속성 데이터 구조와 DB 스키마를 정의한다.

### 7.1 테이블 정의

| 테이블 | 설명 | 주요 컬럼 |
|--------|------|----------|
| `tb_items` | 상담 아이템 | it_code(PK), it_online, it_coin_price, it_tag(JSON), it_counsel_field(JSON), it_style |
| `tb_goods_sell` | 상품 판매/견적 | gs_no(PK), gs_status(0-5), gs_price, gd_code, ac_id, ce_code, cancel_date, messageId |
| `tb_shop_reservation` | 매장 예약 | sr_no(PK), ce_code, cr_code, sr_date, sr_time, sr_status, sr_price |
| `tb_comment` | 리뷰 | cm_no(PK), cm_point5, cm_img, cm_parent(self-ref), it_code |
| `tb_item_price_log` | 가격 변경 이력 | it_code, 변경전가격, 변경후가격, 변경일시 |

### 7.2 ERD (텍스트)

```text
[tb_items] 1──N [tb_goods_sell]         (it_code ← gd_code via tb_goods)
[tb_items] 1──N [tb_shop_reservation]   (it_code via ce_code)
[tb_items] 1──N [tb_comment]            (it_code)
[tb_items] 1──N [tb_item_price_log]     (it_code)
[tb_goods_sell] N──1 [tb_account]       (ac_id — 구매자)
[tb_goods_sell] N──1 [tb_account]       (ce_code — 판매자)
```

### 7.3 SQL DDL

```sql
-- 상품 판매/견적 테이블
CREATE TABLE tb_goods_sell (
    gs_no       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    gd_code     VARCHAR(50)  NOT NULL,
    ac_id       VARCHAR(256) NOT NULL COMMENT '구매자',
    ce_code     VARCHAR(50)  NOT NULL COMMENT '판매자(상담사)',
    gs_status   TINYINT      DEFAULT 0
                COMMENT '0:대기,1:확인,2:작업완료,3:구매확정,4:취소,5:환불',
    gs_price    INT          DEFAULT 0,
    gs_type     VARCHAR(20)  DEFAULT NULL,
    messageId   VARCHAR(100) DEFAULT NULL COMMENT 'SendBird 견적 메시지 ID',
    cancel_date DATETIME     DEFAULT NULL,
    regist_date DATETIME     DEFAULT CURRENT_TIMESTAMP,
    st_code     VARCHAR(20)  DEFAULT 'hongcafe',
    INDEX idx_gd_code  (gd_code),
    INDEX idx_ac_id    (ac_id),
    INDEX idx_gs_status (gs_status, gd_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 매장 예약 테이블 (동시성 제어: UNIQUE KEY)
CREATE TABLE tb_shop_reservation (
    sr_no       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ce_code     VARCHAR(50)  NOT NULL,
    cr_code     VARCHAR(50)  NOT NULL,
    sr_date     DATE         NOT NULL,
    sr_time     VARCHAR(10)  NOT NULL,
    sr_status   VARCHAR(20)  DEFAULT 'standby',
    sr_price    INT          DEFAULT 0,
    regist_date DATETIME     DEFAULT CURRENT_TIMESTAMP,
    st_code     VARCHAR(20)  DEFAULT 'hongcafe',
    INDEX idx_ce_date (ce_code, sr_date),
    UNIQUE KEY uq_reservation (ce_code, sr_date, sr_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

> `UNIQUE KEY uq_reservation (ce_code, sr_date, sr_time)`: InnoDB 레벨에서 동시 예약 충돌을 차단한다. Race Condition 시 `Duplicate entry` 오류가 HTTP 409 + `CONFLICT`로 변환된다.

### 7.4 인덱스 전략

| 테이블 | 인덱스명 | 컬럼 | 목적 |
|--------|---------|------|------|
| `tb_items` | `IDX_it_online` | `it_online, st_code` | 목록 필터 성능 (온라인 상담사 필터링) |
| `tb_goods_sell` | `IDX_gs_status` | `gs_status, gd_code` | 주문 상태별 조회 |
| `tb_shop_reservation` | `IDX_ce_date` | `ce_code, sr_date` | 캘린더 조회 성능 |
| `tb_comment` | `IDX_cm_it_code` | `it_code, cm_parent` | 아이템별 댓글/대댓글 |

---

## 8. Viewpoint 6 — 패턴 뷰 (Patterns View)

IEEE 1016-2009 §5.8 Patterns Viewpoint: 재사용 설계 패턴과 적용 컨텍스트를 정의한다.

### 8.1 적용 패턴 목록

| 패턴 | 적용 컴포넌트 | 근거 |
|------|-------------|------|
| Strategy | `ItemListFormatter` — `pointCalculator`, `postProcessor` 콜백 | 컨트롤러별 계산/후처리 알고리즘 교체 가능 |
| Chain of Responsibility | `ItemListFormatter::formatList()` — `formatRow → label → tag → classOnline` 순서 | 처리 단계 체인, 각 단계 독립 |
| Template Method | `EventListTrait` — `SpecialPriceController` 적용 | 이벤트 목록 공통 흐름 정의, 하위 클래스/트레이트 구체화 |
| Facade | `GoodsPurchaseService::confirmPurchase()` | DB 갱신 + FCM + 알람의 복잡한 흐름을 단일 메서드로 캡슐화 |
| Repository | 5개 Repository 클래스 | DB 접근 추상화. Controller/Service는 Interface만 참조 |
| Dependency Inversion | 8개 Interface + DI 바인딩 | Controller → Interface, 구현체 교체 시 상위 레이어 무변경 |

---

## 9. Viewpoint 7 — 인터페이스 뷰 (Interface View)

IEEE 1016-2009 §5.9 Interface Viewpoint: 컴포넌트 간 계약을 정의한다. 상세는 `commerce-idd.md` 참조.

### 9.1 Service Interface 요약

| 인터페이스 | 소비자 | 핵심 메서드 |
|-----------|-------|-----------|
| `GoodsPurchaseServiceInterface` | GoodsController | `confirmPurchase(int $gsNo, string $crCode): array` |
| `ItemListFormatterInterface` | ItemsController, ChatController | `formatList(array $rows, ...): array` |
| `ShopReservationServiceInterface` | ShopController | `buildCalendarData(...)`, `getAvailableTimeSlots(...)` |

### 9.2 Repository Interface 요약

| 인터페이스 | 추가 메서드 |
|-----------|-----------|
| `GoodsRepositoryInterface` | `updateConfirm($gsNo)` |
| `ItemsRepositoryInterface` | `getItemAccountInfo()`, `getItemCalleeInfo()`, `getItemInfo()` |
| `ShopRepositoryInterface` | `shopAbleReservTime()` |
| `SpecialPriceRepositoryInterface` | `getPaybackOptOn()`, `checkPaybackUser()` |

---

## 10. Viewpoint 8 — 상호작용 뷰 (Interaction View)

IEEE 1016-2009 §5.10 Interaction Viewpoint: 주요 시나리오의 컴포넌트 간 상호작용을 정의한다.

### 10.1 상품 구매 확정 시퀀스

```text
Client
  └──► GoodsController::buyConfirm()
         ├── checkNeedLogin(true)                          [인증 검증]
         ├── validate(['gs_no' => 'required|integer'])     [입력 검증]
         └── GoodsPurchaseService::confirmPurchase(gs_no, cr_code)
               ├── GoodsRepository::updateConfirm(gs_no)  → gs_status=3
               ├── FCM 알림: 상담사 (qna_fcm_use='Y' 조건)
               ├── FCM 알림: 사용자
               └── MypageRepository::SetAlarm()            [알람 이력]
         └── HTTP 200 { "data": { "message": "販売した商品の購入が確定されました。" } }
```

### 10.2 매장 예약 타임슬롯 조회 시퀀스

```text
Client
  └──► ShopController::orderReservationTime()
         └── ShopReservationService::getAvailableTimeSlots(post)
               ├── 과거일 검증 → status='prev_mont' (조기 반환)
               ├── ShopRepository::shopAbleReservTime()    [DB 조회]
               ├── sales_time | rest_time | can_reserv_time 파이프 분리
               ├── DateTimeImmutable 기반 현재 시각 + 1시간 필터
               ├── AM(오전) / PM(오후) 분리
               └── 예약 가능 여부 확인 (기존 예약 슬롯 제외)
         └── HTTP 200 { "data": { "status": "success", "am": [...], "pm": [...] } }
```

### 10.3 특가 목록 조회 시퀀스

```text
Client (비인증)
  └──► SpecialPriceController (EventListTrait::getList())
         └── SpecialPriceRepository::getPaybackOptOn(st_code, it_code)
         └── SpecialPriceRepository::checkPaybackUser(es_code, it_code, ac_id, st_code)
         └── HTTP 200 { "data": [...] }
```

---

## 11. 설계 결정 기록 (Architecture Decision Records)

### ADR-001 ItemListFormatter callback 체인 패턴

**결정**: 5개 컨트롤러에 산재한 포맷 로직을 `ItemListFormatter` callback 체인으로 통합한다.

**이유**: 포맷 로직 변경 시 5개 파일 수정 필요 → 단일 Service 수정으로 변경 범위 최소화. pointCalculator/postProcessor 콜백으로 컨트롤러별 커스텀 처리 허용.

**근거**: GoF Strategy + Chain of Responsibility 복합 적용. "Design Patterns" (Gamma et al., 1994).

**대안 기각**: 각 컨트롤러 인라인 포맷 — 중복 코드 346 lines × 5 = 과잉 중복.

### ADR-002 CalendarHelper static 메서드

**결정**: 매장 캘린더 생성 로직을 `CalendarHelper` static 메서드로 구현한다.

**이유**: 상태 없는 순수 날짜 계산 함수. Commerce/Reservation 모듈이 공유 가능.

**근거**: CodeIgniter 4 공식 문서 Helpers 섹션 — "Helpers are not written in an Object Oriented format. They are simple, procedural functions."

**대안 기각**: 인스턴스 메서드 — 불필요한 인스턴스 생성 오버헤드. 직접 날짜 계산 — 캘린더 로직 중복.

### ADR-003 EventListTrait (SpecialPriceController)

**결정**: `SpecialPriceController`는 `EventListTrait`을 적용하여 1개 EP를 32 lines로 구현한다.

**이유**: Event 모듈과 동일한 이벤트 목록 패턴. 별도 Service 계층은 1개 EP에 과잉.

**대안 기각**: 독립 Service 클래스 — 1개 EP에 불필요한 추상화 오버헤드.

### ADR-004 gs_status 단방향 전이만 허용

**결정**: 주문 상태(gs_status)는 정방향 전이(`0→1→2→3`, `4→5`)만 애플리케이션 레벨에서 허용한다.

**이유**: 역방향 전이는 cancel_date/regist_date 타임라인 정합성을 훼손한다. 감사 추적(audit trail) 무효화 위험.

**근거**: OWASP ASVS 7.1 — "Verify that all event logging includes at least the timestamp, event type, user identifier."

### ADR-005 tb_shop_reservation UNIQUE KEY 기반 동시성 제어

**결정**: 예약 중복 방지를 DB UNIQUE KEY에 최종 위임한다.

**이유**: 애플리케이션 레벨 중복 검사만으로는 Race Condition 발생 가능. InnoDB UNIQUE KEY는 동시 INSERT 충돌 시 Duplicate entry 오류 반환.

**근거**: MySQL 8.0 공식 문서 — "UNIQUE indexes enforce the constraint at the storage engine level... even under concurrent inserts."

---

## 12. 설계 오버레이 (Design Overlay)

### 12.1 보안 오버레이 (Security Overlay)

| 계층 | 적용 보안 제어 |
|------|-------------|
| 라우트 | `['filter' => 'role:callee']` — callee 전용 EP |
| 컨트롤러 | `checkNeedLogin(true)` — ce_code 이중 검증 |
| Repository | WHERE 절 소유권 조건 내장 (`ac_id`, `ce_code`) |
| 파일 업로드 | MIME 이중 검증 (`mime_content_type()` + 확장자 whitelist) |
| 결제 | Stripe idempotency_key + DB UNIQUE 이중 방어 |

### 12.2 추적성 오버레이 (Traceability Overlay)

| SRS FR | SDD 컴포넌트 | 구현 클래스 |
|--------|------------|-----------|
| FR-001 | ItemsController + ItemListFormatter | `ItemsController::getList()` |
| FR-002 | ItemsController | `ItemsController::itemAddLike()` 등 |
| FR-003 | ItemsController + S3 + FCM | `ItemsController::insertItemQna()` |
| FR-004 | ItemsController + ItemPriceLogRepository | `ItemsController::saveItemPrice()` |
| FR-005 | ShopController + ShopReservationService | `ShopReservationService::getAvailableTimeSlots()` |
| FR-006 (FR-006-1~6) | ShopController + Stripe/NaverPay | `ShopController::shopCancel()`, `ShopController::refundSuccess()` (레거시 HTML redirect, CSRF 면제 검토 대상) |
| FR-006 (FR-006-7~9) | ShopController | `ShopController::viewLocationPopup()` (공개 EP), `ShopController::getMyShop()` (JWT), `ShopController::updateReschedule()` (24h 규칙) |
| FR-007 | GoodsController + GoodsPurchaseService | `GoodsPurchaseService::confirmPurchase()` |
| FR-008 (FR-008-1~8, FR-008-12~18) | GoodsController (role:callee) + ShopController (role:callee) | `GoodsController::calleeGoodsJob()`, `ShopController::memosave()` 등 |
| FR-008 (FR-008-9~11) | GoodsController (Caller, jwt) + GoodsRepository (소유권 검증) | `GoodsController::memosave()`, `GoodsController::deleteOpt()`, `GoodsController::deleteFile()` — role:callee 필터 없음, Repository 소유권 검증 필수 (FR-008-9~11, Open Question 보존) |
| FR-009 | GoodsController | `GoodsController::getMyClass()` |
| FR-010 | SpecialPriceController + EventListTrait | `SpecialPriceController::getList()` |
| FR-011 | ItemsController | `ItemsController::getPostingList()`, `ItemsController::postingDetail()`, `ItemsController::getPostingComments()` |

---

## 13. 체크리스트 (Design Verification Checklist)

### 완전성

- [x] 4 Controller, 3 Service, 5 Repository 전체 정의
- [x] DB 테이블 정의 5개 + ERD + DDL
- [x] 인덱스 전략 4개 정의
- [x] gs_status 상태 머신 정의
- [x] 시퀀스 다이어그램 3건 작성
- [x] ADR 5건 기록
- [x] Entity/VO 전환 계획 명시
- [x] 8 Viewpoint 전체 작성
- [x] 설계 오버레이 2종 (보안, 추적성)

### 일관성

- [x] SRS FR ↔ Controller 메서드 매핑 완전 (FR-001~FR-011, FR-008-9~11 Caller/callee 분리 반영)
- [x] Repository ↔ DB 테이블 매핑 완전
- [x] Service 메서드 시그니처 구체적
- [x] DDL 인덱스 ↔ 인덱스 전략 표 일치

### 추적성

- [x] SRS FR ↔ SDD 컴포넌트 매핑 (Traceability Overlay)
- [x] ADR 근거와 대안 기각 이유 기록
- [x] 외부 인터페이스 → IDD 참조 명시

---

## 14. 타당성 검토 (Feasibility Review)

IEEE 1016-2009 §4.3 — 설계 결정의 기술적 실현 가능성을 공식 근거와 함께 검토한다.

| 설계 결정 | 채택 패턴/표준 | 근거 출처 | 검토 결과 |
|-----------|-------------|----------|---------|
| ItemListFormatter callback 체인 | GoF Strategy + Chain of Responsibility | Gamma et al. "Design Patterns" (1994): Strategy §5.9, Chain of Responsibility §5.2 | 적합. 5개 컨트롤러 포맷 중복 제거. 콜백 교체로 확장성 확보 |
| CalendarHelper static | CI4 Helpers 패턴 | CI4 공식 문서 Helpers 섹션 — "not written in OO format, simple procedural functions" | 적합. stateless 순수 함수. Commerce/Reservation 공유 |
| MIME 이중 검증 | OWASP File Upload Cheat Sheet | OWASP: "Verify the actual file content by reading the file header (magic bytes)" | 필수 준수. Content-Type 위조 공격(Polyglot File) 차단 |
| UNIQUE KEY 동시성 제어 | DB constraint 기반 낙관적 제어 | MySQL 8.0 공식 문서: "UNIQUE indexes enforce... even under concurrent inserts" | 적합. Race Condition 최후 방어선 |
| gs_status 단방향 전이 | FSM + 감사 추적 | OWASP ASVS 7.1 — 이벤트 로그 타임스탬프 일관성 | 적합. 역방향 전이는 감사 추적 무효화 위험 |

---

## 15. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|-------|---------|
| tb_goods_sell DDL 추가 | 실제 스키마와 문서 일치. idx_gs_status 인덱스 명문화 | DDL 누락 시 개발자가 DB 실물 직접 확인 필요 → 원스톱 참조 가능 |
| tb_shop_reservation DDL + UNIQUE KEY | uq_reservation으로 DB 레벨 동시성 차단 명문화 | 동시 요청 Race Condition 방지 최후 방어선 문서화 |
| Entity/VO 전환 계획 섹션 | 마이그레이션 로드맵 가시화. 전환 우선순위 명시 | 레거시 배열 기반 코드의 타입 안전성 부재 → 점진적 전환 계획으로 기술 부채 추적 |
| 8 Viewpoint 구조 적용 | IEEE 1016-2009 표준 준수. 각 관점에서 설계를 독립적으로 검토 가능 | 단일 설계 서술에서 관점별 분리로 리뷰 효율성 제고 |
| 설계 오버레이 2종 추가 | 보안 제어 계층별 매핑 + FR ↔ 구현 클래스 추적성 | 보안 설계와 기능 추적성을 별도 뷰로 가시화 |
| Traceability Overlay FR-008 행 세분화 (FR-008-1~8/12~18 vs FR-008-9~11) | goods Caller EP(memosave/delete-opt/delete-file)가 role:callee 없는 별도 행으로 명시됨. 구현 클래스 및 소유권 검증 Repository 추가 | SRS v3.1 FR-008-9~11 추가에도 불구하고 SDD Traceability Overlay가 FR-008 전체를 "GoodsController (role:callee)"로 표기하면 접근 주체 오해 유발. Caller jwt EP를 분리하여 RBAC 3계층 설계 의도를 명확히 반영 (DEF-001 연계) |
| Traceability Overlay FR-006 행 세분화 (FR-006-1~6 vs FR-006-7~9) | shop 레거시 HTML redirect(refund-success) 및 신규 FR(view-location-popup/get-my-shop/update-reschedule)이 별도 행으로 명시됨 | SRS v3.1 FR-006-7~9 추가(view-location-popup 공개 EP, get-my-shop JWT, update-reschedule 24h 규칙)가 SDD Traceability Overlay에 미반영 시 추적성 단절 발생. COMMERCE-SHOP-DEF-001 반영 (SRS API SSOT 원칙) |

---

## 16. 변경 로그 (Change Log)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| v1.0 | 2026-04-15 | jypark | 초기 작성 |
| v1.1 | 2026-04-15 | jypark | ERD, 인덱스 전략, 시퀀스 2건, Service 메서드 시그니처, Controller 인증 컬럼 추가 |
| v1.2 | 2026-04-15 | jypark | SQL DDL 추가, Entity/VO 전환 섹션, 타당성 검토 5건, 변경 영향 기록 4건 |
| v2.0 | 2026-04-15 | jypark | IEEE 표준 전면 전환. 3-Round Review PASS. IEEE 1016-2009 8-Viewpoint 구조 전면 적용. Context/Composition/Logical/Dependency/Information/Patterns/Interface/Interaction 8 Viewpoint 완전 작성. 설계 오버레이 2종(보안, 추적성) 추가. ADR 5건 이유/근거/대안 상세화. Traceability Overlay 신설. |
| v2.1 | 2026-04-21 | jypark | [A] COMMERCE-ITEMS-DEF-001: ItemsController EP 수 17→16 정정 (routes.php/디렉토리 구조/컨트롤러 레이어 표). COMMERCE-ITEMS-DEF-003: Traceability Overlay에 FR-011 Posting 매핑 추가. 총 라우트 수 73→72 반영. SRS v3.1 기준 갱신. |
| v2.2 | 2026-04-21 | jypark | [A] COMMERCE-GOODS-DEF-001: §12.2 Traceability Overlay FR-008 행을 callee 그룹(FR-008-1~8, 12~18)과 Caller 그룹(FR-008-9~11: memosave/delete-opt/delete-file, jwt, role:callee 필터 없음, Repository 소유권 검증 필수)으로 세분화. Open Question 보존. |
| v2.3 | 2026-04-21 | jypark | [A] COMMERCE-SHOP-DEF-001: §12.2 Traceability Overlay FR-006 행을 FR-006-1~6(ShopController+Stripe/NaverPay, shopCancel/refundSuccess 레거시 CSRF 검토)과 FR-006-7~9(view-location-popup 공개 EP, get-my-shop JWT, update-reschedule 24h)로 세분화. SRS v3.1 FR-006-7~9 반영. |
