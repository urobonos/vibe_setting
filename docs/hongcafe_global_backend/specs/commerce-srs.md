---
docId: SRS-COMMERCE-001
title: "Commerce Module — Software Requirements Specification"
standard: "IEEE 29148:2018"
version: "3.1"
status: "Approved"
createdAt: "2026-04-15"
updatedAt: "2026-04-21"
author: jypark
module: Commerce
relatedDocs:
  - id: SDD-COMMERCE-001
    path: commerce-sdd.md
  - id: IDD-COMMERCE-001
    path: commerce-idd.md
  - path: docs/api-specification.md
  - path: api-docs/commerce/items-api.md
  - path: api-docs/commerce/shop-api.md
  - path: api-docs/commerce/goods-api.md
---

# Commerce Module — Software Requirements Specification

> Standard: IEEE 29148:2018 | Version: 3.1 | Updated: 2026-04-21 | Module: Commerce

---

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) defines the functional requirements (FR) and non-functional requirements (NFR) for the Commerce module of HongCafe Global Backend, conforming to IEEE 29148:2018. The Commerce module governs the complete commerce lifecycle for consultation services, covering four sub-domains: Items, Shop, Goods, and SpecialPrice. It exposes 72 endpoints and integrates with Stripe, NaverPay, FCM, AWS S3, and an internal Chat API.

The intended audience is the development team, QA engineers, security reviewers, and project stakeholders. This document serves as the authoritative baseline for design (SDD-COMMERCE-001) and interface specifications (IDD-COMMERCE-001).

### 1.2 Scope

| Attribute | Value |
|-----------|-------|
| Module path | `app/Modules/Commerce/` |
| Sub-domains | Items (16 EP), Shop (26 EP), Goods (30 EP), SpecialPrice (1 EP) |
| Total endpoints | 72 |
| Controllers | `ItemsController` (1370 L), `ShopController` (1425 L), `GoodsController` (1805 L), `SpecialPriceController` (32 L) |
| Services | `GoodsPurchaseService`, `ItemListFormatter`, `ShopReservationService` |
| Repositories | `GoodsRepository`, `ItemsRepository`, `ShopRepository`, `ItemPriceLogRepository`, `SpecialPriceRepository` |
| Primary tables | `tb_items`, `tb_goods_sell`, `tb_shop_reservation`, `tb_comment`, `tb_item_price_log` |
| External dependencies | Stripe PHP SDK, NaverPay REST, FCM, AWS S3 / IMG_SERVER, Chat API (internal HTTP) |
| Stakeholders | Caller (end user), Callee (consultant), Payment Gateway systems, Administrator |

### 1.3 Definitions and Abbreviations

| Term | Definition |
|------|-----------|
| Caller | Authenticated end user. No `ce_code`. Assigned `UserRole::Caller`. |
| Callee | Consultant. Holds `ce_code`. Assigned `UserRole::Callee`. Route filter `role:callee` required on all Callee-exclusive endpoints. |
| gs_status | Order state integer on `tb_goods_sell`: 0 = Pending, 1 = Confirmed, 2 = Completed, 3 = Purchased, 4 = Cancelled, 5 = Refunded. |
| CalendarHelper | Stateless static helper generating monthly calendar arrays (CI4 Helper pattern). Shared by Commerce and Reservation modules. |
| ItemListFormatter | 346-line service applying a callback chain (Strategy + Chain of Responsibility) to normalize item list rows across five controllers. |
| EventListTrait | PHP trait encapsulating common event/special-price list retrieval logic, reused between Event and Commerce modules. |
| O2O | Online-to-Offline — in-person shop visit after online reservation. |
| Idempotency Key | UUID v4 value supplied to the Stripe PHP SDK `['idempotency_key']` option to prevent duplicate PaymentIntent creation on network retries. |
| MIME dual validation | Two-layer file type verification: (1) extension whitelist check, (2) `mime_content_type()` magic-byte inspection. Both layers must pass before S3/IMG_SERVER upload. |
| 1-hour advance rule | Available time slots are restricted to slots starting at least 60 minutes after the current UTC time. Filtering is performed server-side in `ShopReservationService::getAvailableTimeSlots()`. |
| 24-hour cancellation rule | Shop reservations may only be cancelled or modified up to 24 hours before the scheduled time. Requests within the 24-hour window receive HTTP 403 FORBIDDEN. |
| FR | Functional Requirement |
| NFR | Non-Functional Requirement |
| UC | Use Case |
| EP | Endpoint |
| PG | Payment Gateway |
| SRS | Software Requirements Specification |
| SDD | Software Design Document |
| IDD | Interface Design Document |

### 1.4 Document Organization

This SRS follows the clause structure of IEEE 29148:2018:

- Section 2: System Context
- Section 3: Functional Requirements (FR-001 through FR-010)
- Section 4: Non-Functional Requirements (NFR-001 through NFR-007)
- Section 5: Use Cases (UC-001 through UC-004)
- Section 6: Requirements Verification Checklist
- Section 7: Feasibility Review (IEEE 29148:2018 §5.2.9)
- Section 8: Change Impact Log
- Section 9: Change Log

---

## 2. System Context

### 2.1 System Overview

The Commerce module operates as a bounded context within a Modular Monolith architecture built on CodeIgniter 4.7+ / PHP 8.4+. All incoming HTTP requests pass through a filter chain — `ratelimit → csrftoken → auth → role:callee (where applicable)` — before reaching a controller. Controllers delegate business logic exclusively to typed Service classes and access data exclusively through Repository interfaces.

```
HTTP Request
  └─ CI4 Filter Chain (ratelimit → csrftoken → auth → role:callee)
       └─ Controller (ItemsController / ShopController / GoodsController / SpecialPriceController)
            ├─ Service (GoodsPurchaseService / ItemListFormatter / ShopReservationService)
            │    └─ Repository Interface → Repository Impl → Aurora MySQL (RDS Proxy IAM Auth)
            └─ External: Stripe SDK | NaverPay REST | FCM | AWS S3 | Chat API
```

### 2.2 User Roles and Privileges

| Role | Authentication | Commerce Privileges |
|------|---------------|---------------------|
| Anonymous | None | Read-only item list/search/detail, special-price list |
| Caller | JWT (`hc_access` cookie) | Purchase, reservation, favourites, Q&A, review, order history |
| Callee | JWT + `role:callee` filter | All Caller privileges + goods/shop CRUD, file upload, schedule management, order confirmation |
| System | API Key (`X-Api-Key`) | PG callback endpoints (Stripe webhook, NaverPay callback) |

### 2.3 Assumptions and Dependencies

1. Aurora MySQL 3.12.0 (MySQL 8.0 compatible) is available and accessible via RDS Proxy IAM Auth.
2. Stripe PHP SDK and NaverPay REST credentials are supplied via environment variables (`STRIPE_SECRET_KEY`, `NAVER_PAY_*`).
3. FCM service account credentials are available in the deployment environment.
4. AWS S3 bucket and IMG_SERVER endpoint are configured and accessible from the application server.
5. The Chat API internal endpoint is reachable within the same VPC.
6. `setAutoRoute(false)` is enforced globally; all 72 routes are explicitly registered in `app/Modules/Commerce/Config/Routes.php`.

---

## 3. Functional Requirements

### FR-001 Item List and Search (Items — 16 EP)

**Summary**: Provide PC/mobile item listing with sorting, category/style filtering, keyword search, and normalized output via `ItemListFormatter`.

| Req ID | Requirement |
|--------|-------------|
| FR-001-1 | The system shall support 6 sort modes: `suggest` (recommended), `itemNew` (new items), `newRegist` (new registrations), `recent` (recent activity), `calling` (active call), `hot` (popular). |
| FR-001-2 | The system shall filter items by `it_counsel_field` (JSON array, category) and `it_style` (string, style). Multiple values shall be supported with OR logic within a field and AND logic across fields. |
| FR-001-3 | The system shall support keyword search against consultant name and item name. Empty keyword shall return unfiltered results. |
| FR-001-4 | All item list rows shall be normalized through the `ItemListFormatter::formatList()` callback chain in the fixed order: `formatRow → pointCalculator → setItemLabel → setViewTag → setClassOnline → postProcessor`. Skipping any stage is not permitted. |
| FR-001-5 | The system shall apply 5 label types per item: `partner`, `new`, `star`, `review`, `counsel` via `ItemListFormatter::setItemLabel()`. |
| FR-001-6 | Each item row in the response shall include: online status (`it_online`), point rating (`view_win_point`), tag list (`it_tag` parsed from JSON), and view tag (`view_tag`). |
| FR-001-7 | Paginated responses shall use CI4 built-in `Pager` exclusively. Response format: `{ "data": [...], "meta": { "currentPage", "perPage", "total", "lastPage" } }` with all keys in camelCase. |
| FR-001-8 | Item list, search, and detail endpoints shall be publicly accessible (no authentication required). Favourites and Q&A endpoints require JWT authentication. |

**Related endpoints**: `GET /api/items/get-item`, `GET /api/items/get-list-pc`, `POST /api/items/get-list`, and 13 additional Items endpoints.

> **Open Question (COMMERCE-ITEMS-DEF-001)**: `GET /api/items/get-callee-list` was previously listed here. This EP is absent from `items-api.md`, `items-api.yaml`, and `Routes.php` (16 EP total confirmed). Until a product decision is made, this EP is treated as not yet implemented and is excluded from the scope. Total EP count is corrected to 16.

---

### FR-002 Favourites CRUD (Items)

**Summary**: Authenticated Callers may add or remove consultant items from their favourites list.

| Req ID | Requirement |
|--------|-------------|
| FR-002-1 | The system shall allow adding a favourite via `POST /api/items/item-add-like`. JWT authentication is mandatory. Duplicate addition for the same `it_code` by the same user shall return HTTP 409 + error code `CONFLICT`. |
| FR-002-2 | The system shall allow single favourite deletion via `DELETE /api/items/item-delete-like`. Ownership verification (requesting user owns the favourite record) is mandatory before deletion. |
| FR-002-3 | The system shall allow bulk deletion of all favourites for the authenticated user via `DELETE /api/items/item-all-delete-like`. No ownership check is required at the row level since the filter is the authenticated user's identity. |
| FR-002-4 | The system shall provide a paginated favourites list. Response format follows FR-001-7 (camelCase `meta` object). |

**Related endpoints**: `POST /api/items/item-add-like`, `DELETE /api/items/item-delete-like`, `DELETE /api/items/item-all-delete-like`.

---

### FR-003 Q&A and Review Management (Items)

**Summary**: Q&A registration triggers FCM notifications to the Callee; review image uploads require MIME dual validation before S3 storage.

| Req ID | Requirement |
|--------|-------------|
| FR-003-1 | Q&A registration via `POST /api/items/insert-item-qna` requires JWT. Upon successful insert, the system shall dispatch an FCM push notification to the target Callee if and only if the Callee's `qna_fcm_use` column equals `'Y'`. |
| FR-003-2 | Review image uploads shall pass MIME dual validation (FR-NFR-001) before being stored in AWS S3. |
| FR-003-3 | On a user's first review submission for any item, the system shall automatically issue a coupon to that user. |
| FR-003-4 | A spam-prevention guard shall reject review re-submission by the same user on the same item within 5 minutes of the previous submission. Violation shall return HTTP 429 + error code `TOO_MANY_REQUESTS`. |
| FR-003-5 | Permitted MIME types for review images are: `image/jpeg` (jpg), `image/png` (png), `image/gif` (gif), `image/webp` (webp). All other types shall be rejected with HTTP 400 + `INVALID_INPUT`. |

**Related endpoints**: `POST /api/items/insert-item-qna`, `POST /api/mypage/insert-my-comment`.

---

### FR-004 Item Price Management (Items — Callee only)

**Summary**: Callees update their item prices; every change is persisted to the price-change audit log.

| Req ID | Requirement |
|--------|-------------|
| FR-004-1 | Price update via `POST /api/items/save-item-price` is a Callee-exclusive action. The `role:callee` route filter is not currently applied at the route level (technical debt). Callee identity is verified inside the controller via `checkNeedLogin(true)` (RBAC Layer 2). Non-Callee requests shall be rejected with HTTP 403 + `FORBIDDEN` at the controller level. |
| FR-004-2 | On every price change the system shall write a record to `ItemPriceLogRepository` containing: `it_code`, previous price, new price, and change timestamp (`DateTimeImmutable::getTimestamp()`). |
| FR-004-3 | The system shall expose a read-only price-change history endpoint for Callee use, returning all log entries for the authenticated Callee's items in reverse-chronological order. |

**Related endpoints**: `POST /api/items/save-item-price`.

---

### FR-005 Shop Reservation Calendar and Time Slots (Shop — 26 EP)

**Summary**: `CalendarHelper` generates calendar data; `ShopReservationService` enforces the 1-hour advance rule and returns AM/PM-separated available slots.

| Req ID | Requirement |
|--------|-------------|
| FR-005-1 | Calendar data shall be built exclusively via `CalendarHelper::buildCalendarData()`. Direct date arithmetic in controllers or repositories is prohibited. |
| FR-005-2 | `POST /api/shop/order-reservation-time` shall return only time slots whose start time is at least 60 minutes after the current server UTC time. Past slots shall be silently removed before the response is built. |
| FR-005-3 | The time-slot response shall separate slots into AM (before 12:00) and PM (12:00 and after). Response format: `{ "data": { "am": [...], "pm": [...] } }`. |
| FR-005-4 | A request for a date in the past shall return `{ "data": { "status": "prev_mont", "am": [], "pm": [] } }` without error. |
| FR-005-5 | The columns `sales_time`, `rest_time`, and `can_reserv_time` are stored in the database using a pipe (`|`) delimiter. The service layer is responsible for splitting these values before processing. |
| FR-005-6 | Slots that overlap with an existing reservation or fall within the Callee's `rest_time` intervals shall be excluded from the available-slot list. |

**Related endpoints**: `POST /api/shop/reservation-calendar`, `POST /api/shop/order-reservation-time`.

---

### FR-006 Shop Purchase, Confirmation, Cancellation, and Refund (Shop)

**Summary**: Full lifecycle from reservation creation through visit completion, cancellation, and PG refund.

| Req ID | Requirement |
|--------|-------------|
| FR-006-1 | Reservation creation via `POST /api/shop/buy-shop` shall INSERT a row into `tb_shop_reservation`. The database-level `UNIQUE KEY uq_reservation (ce_code, sr_date, sr_time)` serves as the final concurrency guard against duplicate reservations. |
| FR-006-2 | Visit confirmation via `POST /api/shop/shop-confirm` shall update `sr_status` to indicate service completion. |
| FR-006-3 | Reservation cancellation via `POST /api/shop/shop-cancel` is permitted only when the current UTC time is more than 24 hours before the scheduled reservation time. Requests within the 24-hour window shall return HTTP 403 + `FORBIDDEN`. Timestamp comparison shall use `DateTimeImmutable`. |
| FR-006-4 | After a cancellation is approved, the system shall call the appropriate PG refund API (Stripe or NaverPay based on original payment method) and update `sr_status` upon confirmed refund. |
| FR-006-5 | The PG refund callback endpoint `POST /api/shop/refund-success` shall update `sr_status` to the final refunded state upon receipt of a confirmed callback from the PG. **Implementation note**: The current implementation returns a legacy HTML redirect response (`redirect()->to($CurrentURI)->alert(...)`) rather than a JSON API response. CSRF validation is to be evaluated for exemption for this endpoint (equivalent status to `api/stripe/webhook`). Future migration to JSON response is recommended. |
| FR-006-6 | Post-visit reviews may include images. All images shall pass MIME dual validation (NFR-001) before S3 upload. |
| FR-006-7 | `POST /api/shop/view-location-popup` shall return the location map popup HTML fragment or equivalent data for the target Callee. Authentication is not required (public EP). |
| FR-006-8 | `POST /api/shop/get-my-shop` shall return the paginated reservation history for the authenticated Caller. JWT authentication is required. Response format follows FR-001-7 (camelCase `meta` object). |
| FR-006-9 | `POST /api/shop/update-reschedule` shall allow the authenticated Caller to reschedule a reservation. Reschedule is permitted only when the current UTC time is more than 24 hours before the scheduled reservation time (NFR-003). |

**Related endpoints**: `POST /api/shop/buy-shop`, `POST /api/shop/shop-confirm`, `POST /api/shop/shop-cancel`, `POST /api/shop/refund-success`, `POST /api/shop/view-location-popup`, `POST /api/shop/get-my-shop`, `POST /api/shop/update-reschedule`.

---

### FR-007 Goods Purchase, Confirmation, Cancellation, and Refund (Goods — 30 EP)

**Summary**: End-to-end goods order lifecycle managed through `GoodsPurchaseService` with FCM notifications and strict state-machine enforcement.

| Req ID | Requirement |
|--------|-------------|
| FR-007-1 | Purchase request via `POST /api/goods/buy-item` shall INSERT a row in `tb_goods_sell` with `gs_status = 0` (Pending). Both estimate-based and immediate purchase modes are supported. |
| FR-007-2 | Immediately upon a successful purchase INSERT, the system shall dispatch an FCM push notification to the target Callee. |
| FR-007-3 | Purchase confirmation via `POST /api/goods/buy-confirm` shall be routed exclusively through `GoodsPurchaseService::confirmPurchase(int $gs_no, string $cr_code)`, which transitions `gs_status` to `3` (Purchased). |
| FR-007-4 | Order cancellation via `POST /api/goods/buy-cancel` shall transition `gs_status` to `4` (Cancelled). Where a refund is applicable, the system shall initiate a PG refund call. |
| FR-007-5 | The `gs_status` field shall enforce a strict forward-only state machine: `0 → 1 → 2 → 3` (normal flow) and `4 → 5` (cancellation/refund). Reverse transitions are not permitted. Any attempt to apply a reverse transition shall return HTTP 400 + `INVALID_INPUT`. |
| FR-007-6 | After `confirmPurchase()` succeeds, the system shall: (a) send an FCM notification to the Callee, (b) send an FCM notification to the Caller, and (c) write an alarm history entry via `MypageRepository::SetAlarm()`. All three steps must complete; partial completion shall be logged as an error. |
| FR-007-7 | All Stripe PaymentIntent creations shall include a `['idempotency_key' => uuid_v4()]` option in the SDK call. The generated key shall be stored in `tb_goods_sell` or `tb_shop_reservation` to enable server-side deduplication. |

**Related endpoints**: `POST /api/goods/buy-item`, `POST /api/goods/buy-confirm`, `POST /api/goods/buy-cancel`, `POST /api/goods/cancel-success`.

---

### FR-008 Callee Goods and Shop Management (Goods/Shop — role:callee)

**Summary**: Callee-exclusive product and shop management including CRUD, file upload, schedule handling, and order acceptance.

| Req ID | Requirement |
|--------|-------------|
| FR-008-1 | Goods CRUD endpoints (`POST /api/goods/update-goods`, `DELETE /api/goods/delete-goods`) shall require the `role:callee` route filter. |
| FR-008-9 | `POST /api/goods/memosave` shall allow an authenticated Caller (JWT required, no `role:callee` filter) to save a memo note for a goods order (`gs_no`). Ownership verification — the `gs_no` must belong to the requesting Caller's `ac_id` — is mandatory. Violation shall return HTTP 403 + `FORBIDDEN`. **Open Question**: whether Callees may also invoke this endpoint is pending product confirmation. |
| FR-008-10 | `DELETE /api/goods/delete-opt` shall allow an authenticated Caller (JWT required, no `role:callee` filter) to delete a goods option record. Ownership verification — the option must belong to the requesting Caller — is mandatory. Violation shall return HTTP 403 + `FORBIDDEN`. **Open Question**: whether Callees may also invoke this endpoint is pending product confirmation. |
| FR-008-11 | `DELETE /api/goods/delete-file` shall allow an authenticated Caller (JWT required, no `role:callee` filter) to delete a goods file record. Ownership verification — the file must belong to the requesting Caller — is mandatory. Violation shall return HTTP 403 + `FORBIDDEN`. **Open Question**: whether Callees may also invoke this endpoint is pending product confirmation. |
| FR-008-2 | All file uploads (goods images, work files, class materials) shall pass MIME dual validation. Permitted types: `jpg, png, gif, webp` (images); `pdf, doc, docx, xls, xlsx, zip` (documents/archives). |
| FR-008-3 | The system shall provide goods preview and visibility toggle (`it_online`) endpoints accessible to Callees. |
| FR-008-4 | Deletion of a goods record is prohibited while any active order (`gs_status < 4`) references that record. Such requests shall return HTTP 409 + `CONFLICT`. |
| FR-008-5 | Order acceptance via `POST /api/goods/callee-goods-confirm` shall transition `gs_status` from `0` to `1`. |
| FR-008-6 | Work completion via `POST /api/goods/callee-goods-job` shall: (a) accept a work file with MIME dual validation, (b) upload the file to IMG_SERVER, (c) transition `gs_status` to `2`, and (d) send a chat-room notification via the internal Chat API. |
| FR-008-7 | Shop schedule management endpoints (`POST /api/shop/callee-shop-confirm`, `POST /api/shop/callee-o2o-job`) shall, upon completion, send a chat-room notification via the internal Chat API. |
| FR-008-8 | File download endpoints shall permit downloads only within 14 calendar days of the `regist_date` of the confirmed order (`gs_status = 3`). Requests outside this window shall return HTTP 403 + `FORBIDDEN`. Comparison shall use `DateTimeImmutable`. |

| FR-008-12 | `POST /api/shop/memosave` shall allow a Callee (`role:callee` filter) to save a memo note on a shop reservation. |
| FR-008-13 | `DELETE /api/shop/delete-opt` shall allow a Callee (`role:callee` filter) to delete a shop option record. |
| FR-008-14 | `POST /api/shop/update-shop` shall allow a Callee (`role:callee` filter) to update their shop profile information. |
| FR-008-15 | `POST /api/shop/update-shop-view` shall allow a Callee (`role:callee` filter) to toggle shop visibility (`shView` field). |
| FR-008-16 | `POST /api/shop/preview-shop` shall allow a Callee (`role:callee` filter) to preview their shop page before publication. |
| FR-008-17 | Schedule management endpoints (`POST /api/shop/schedule-add`, `DELETE /api/shop/schedule-delete`) shall allow a Callee (`role:callee` filter) to add or remove schedule entries. |
| FR-008-18 | Reservation query endpoints (`POST /api/shop/shop-reserve-day`, `POST /api/shop/shop-reserve-week`, `POST /api/shop/shop-reserve-month`) shall allow a Callee (`role:callee` filter) to view their reservation schedule for a given day, week, or month respectively. |

**Related endpoints**: `POST /api/goods/update-goods`, `DELETE /api/goods/delete-goods`, `POST /api/goods/callee-goods-confirm`, `POST /api/goods/callee-goods-job`, `POST /api/shop/callee-shop-confirm`, `POST /api/shop/callee-o2o-job`, `POST /api/shop/memosave`, `DELETE /api/shop/delete-opt`, `POST /api/shop/update-shop`, `POST /api/shop/update-shop-view`, `POST /api/shop/preview-shop`, `POST /api/shop/schedule-add`, `DELETE /api/shop/schedule-delete`, `POST /api/shop/shop-reserve-day`, `POST /api/shop/shop-reserve-week`, `POST /api/shop/shop-reserve-month`.

---

### FR-009 Class Management (Goods)

**Summary**: Callers access purchased class history and details; Callees upload class materials; download access is time-limited.

| Req ID | Requirement |
|--------|-------------|
| FR-009-1 | Class history retrieval via `POST /api/goods/get-my-class` shall return only classes owned by the authenticated Caller, with paginated output conforming to FR-001-7. |
| FR-009-2 | Class detail retrieval via `POST /api/goods/get-my-class-detail` shall return the full details of a single purchased class. Ownership verification is mandatory. |
| FR-009-3 | Callee class file uploads shall pass MIME dual validation. Upon successful upload, the system shall dispatch an FCM notification to the purchasing Caller. |
| FR-009-4 | Class file downloads are permitted only when `gs_status = 3` and the download request is within 14 days of the order's `regist_date`. Violations return HTTP 403 + `FORBIDDEN`. |

**Related endpoints**: `POST /api/goods/get-my-class`, `POST /api/goods/get-my-class-detail`.

---

### FR-010 Special Price Events (SpecialPrice — 1 EP)

**Summary**: `EventListTrait`-based public endpoint returning special-price items with payback event information.

| Req ID | Requirement |
|--------|-------------|
| FR-010-1 | `POST /api/special-prices/get-list` is a public endpoint requiring no authentication. It shall be registered in `AuthFilter::EXCLUDED_PATHS`. |
| FR-010-2 | The system shall query `SpecialPriceRepository::getPaybackOptOn(string $st_code, string $it_code)` to determine payback event applicability and `checkPaybackUser()` to determine per-user payback eligibility. |
| FR-010-3 | `SpecialPriceController` shall use `EventListTrait`, applying the same list-construction pattern as the Event module. |

**Related endpoints**: `POST /api/special-prices/get-list`.

---

### FR-011 Posting / 게시글 조회 (Items)

**Summary**: Callee posting (게시글) list and detail retrieval. Public endpoints requiring no authentication.

| Req ID | Requirement |
|--------|-------------|
| FR-011-1 | `POST /api/items/get-posting-list` shall return a paginated list of postings for the specified Callee. No authentication is required. Response format follows FR-001-7 (camelCase `meta` object). |
| FR-011-2 | `POST /api/items/posting-detail` shall return the detail of a single posting, including the previous and next posting navigation links (`nextPrev`). The `isLike` field shall indicate whether the current authenticated user has liked the posting (if authenticated). No authentication required for basic detail access. |
| FR-011-3 | `POST /api/items/get-posting-comments` shall return a paginated list of comments for the specified posting. No authentication is required. Response format follows FR-001-7 (camelCase `meta` object). |

**Related endpoints**: `POST /api/items/get-posting-list`, `POST /api/items/posting-detail`, `POST /api/items/get-posting-comments`.

---

## 4. Non-Functional Requirements

### NFR-001 Security — MIME Dual Validation

| Attribute | Specification |
|-----------|---------------|
| Threat | Polyglot file upload enabling Remote Code Execution (RCE) via disguised executable files. |
| Mitigation | Two mandatory validation layers applied in sequence before any upload operation. |
| Layer 1 | Extension whitelist check against the permitted list. |
| Layer 2 | `mime_content_type()` magic-byte inspection of the uploaded file content. |
| Permitted image types | `jpg` (`image/jpeg`), `png` (`image/png`), `gif` (`image/gif`), `webp` (`image/webp`). |
| Permitted document types | `pdf`, `doc`, `docx`, `xls`, `xlsx`, `zip`. |
| Scope | All file upload endpoints: review images, Callee work files, class materials. |
| Violation response | HTTP 400 + `INVALID_INPUT`. File is not uploaded to S3 or IMG_SERVER. |

### NFR-002 Correctness — Reservation Concurrency Control

| Attribute | Specification |
|-----------|---------------|
| Threat | Race condition: two concurrent requests booking the same Callee + date + time slot. |
| Primary mitigation | Application-level duplicate check in `ShopReservationService` before INSERT. |
| Final guard | `UNIQUE KEY uq_reservation (ce_code, sr_date, sr_time)` on `tb_shop_reservation`. |
| Conflict response | HTTP 409 + `CONFLICT`. User is prompted to select a different time slot. |

### NFR-003 Business Rule — 24-Hour Cancellation Window

| Attribute | Specification |
|-----------|---------------|
| Rule | Shop reservations may be cancelled or rescheduled only more than 24 hours before the reservation time. |
| Time basis | UTC. All comparisons use `DateTimeImmutable`. `date()` and `time()` are prohibited. |
| Boundary handling | A request arriving exactly at the 24-hour mark is treated as within the window (HTTP 403). |
| Violation response | HTTP 403 + `FORBIDDEN`. |

### NFR-004 Business Rule — 1-Hour Advance Reservation

| Attribute | Specification |
|-----------|---------------|
| Rule | Available time slots exposed to the client include only slots starting at least 60 minutes after the current UTC time. |
| Enforcement point | Server-side, within `ShopReservationService::getAvailableTimeSlots()`. Client-side enforcement is not relied upon. |
| Effect | Past or near-future slots are silently omitted from the AM/PM arrays in the response. |

### NFR-005 Performance — Item List Response

| Attribute | Specification |
|-----------|---------------|
| Target | p95 latency < 500 ms for item list endpoints under standard load. |
| Measurement basis | 10-item pagination page, inclusive of DB query time and `ItemListFormatter` processing. |
| Index dependency | `IDX_it_online (it_online, st_code)` on `tb_items` must be present. |
| Monitoring | Response-time logging via application instrumentation. |

### NFR-006 Security — File Download Time Restriction

| Attribute | Specification |
|-----------|---------------|
| Rule | Purchased work files and class materials may only be downloaded within 14 calendar days of `gs_status = 3` (Purchased) being set. |
| Time basis | `regist_date` of the goods-sell record, compared using `DateTimeImmutable`. |
| Violation response | HTTP 403 + `FORBIDDEN`. |

### NFR-007 Reliability — Payment Idempotency

| Attribute | Specification |
|-----------|---------------|
| Applicable PGs | Stripe (PaymentIntent), NaverPay. |
| Stripe implementation | Every `PaymentIntent` creation call includes `['idempotency_key' => uuid_v4()]` in the SDK options array. |
| DB-level guard | The generated idempotency key is persisted to `tb_goods_sell` or `tb_shop_reservation` to enable application-level deduplication on retry. |
| Retry behaviour | A repeated call with the same idempotency key returns the original PG response without re-executing the payment operation. |

---

## 5. Use Cases

### UC-001 Goods Purchase → Order Acceptance → Work Completion → Purchase Confirmation

```
Actors    : Caller (buyer), Callee (consultant)
Pre-cond  : Caller holds valid JWT (hc_access cookie). Callee holds role:callee.
Post-cond : gs_status = 3, alarm history written to MypageRepository.

Main Flow:
  1. Caller calls POST /api/goods/buy-item.
     System INSERTs tb_goods_sell with gs_status = 0 (Pending).
  2. System dispatches FCM push to Callee (FR-007-2).
  3. Callee calls POST /api/goods/callee-goods-confirm.
     System transitions gs_status 0 → 1 (Confirmed) (FR-008-5).
  4. Callee completes work, calls POST /api/goods/callee-goods-job with file attachment.
     System validates MIME dual (NFR-001), uploads to IMG_SERVER,
     transitions gs_status 1 → 2 (Completed), sends chat-room notification (FR-008-6).
  5. System dispatches FCM to Caller notifying completion (FR-007-6).
  6. Caller calls POST /api/goods/buy-confirm.
     System invokes GoodsPurchaseService::confirmPurchase(gs_no, cr_code).
     Service: GoodsRepository::updateConfirm() → gs_status 2 → 3,
              Callee FCM, Caller FCM, MypageRepository::SetAlarm() (FR-007-6).
  7. System returns HTTP 200 { "data": { "message": "販売した商品の購入が確定されました。" } }.

Exception Flows:
  4a. File MIME validation fails → HTTP 400 INVALID_INPUT. gs_status unchanged.
  6a. gs_no not found → HTTP 404 NOT_FOUND.
  6b. gs_status in invalid transition state → HTTP 400 INVALID_INPUT.
  8a. Callee attempts delete-goods while active order (gs_status < 4) exists → HTTP 409 CONFLICT.
```

### UC-002 Shop Reservation → Visit Confirmation → Cancellation

```
Actors    : Caller
Pre-cond  : Caller holds valid JWT.
Post-cond (normal): sr_status = 'done'. Review submission enabled.
Post-cond (cancel): sr_status = 'cancelled'. Refund processed via PG.

Main Flow:
  1. Caller calls POST /api/shop/reservation-calendar.
     ShopReservationService::buildCalendarData() → CalendarHelper produces monthly grid.
     Response includes ableDate list (FR-005-1).
  2. Caller calls POST /api/shop/order-reservation-time.
     ShopReservationService::getAvailableTimeSlots() applies:
       - Past-date check → status: prev_mont if applicable (FR-005-4).
       - 1-hour advance filter (NFR-004).
       - Overlap and rest_time exclusion (FR-005-6).
     Response: { "data": { "am": [...], "pm": [...] } }.
  3. Caller calls POST /api/shop/buy-shop.
     System INSERTs tb_shop_reservation.
     UNIQUE KEY uq_reservation guards against concurrent duplicates (NFR-002).
  4. Caller visits shop. Calls POST /api/shop/shop-confirm.
  5. Callee calls POST /api/shop/callee-shop-confirm to acknowledge.
     sr_status → 'done'.

Alternative Flow (24-hour advance cancellation):
  A1. Caller calls POST /api/shop/shop-cancel (> 24 h before reservation).
  A2. System validates 24-hour window (NFR-003). Proceeds if valid.
  A3. System calls PG refund API (Stripe or NaverPay) (FR-006-4).
  A4. PG callback POST /api/shop/refund-success received. sr_status → 'cancelled'.

Exception Flows:
  3a. Concurrent booking hits UNIQUE constraint → HTTP 409 CONFLICT.
  A1a. Cancellation within 24-hour window → HTTP 403 FORBIDDEN.
```

### UC-003 Item Search → Favourite → Q&A Submission

```
Actors    : Caller (authenticated)
Pre-cond  : Caller holds valid JWT.
Post-cond : Favourite stored. Q&A registered. Callee FCM received (if qna_fcm_use='Y').

Main Flow:
  1. Caller calls POST /api/items/get-list with sort and filter params.
     System executes ItemListFormatter::formatList() chain (FR-001-4).
     Response: paginated item list with labels and view tags (FR-001-5, FR-001-6, FR-001-7).
  2. Caller calls POST /api/items/item-add-like (FR-002-1).
     System checks for duplicate. INSERT favourite record on success.
  3. Caller calls POST /api/items/insert-item-qna (FR-003-1).
     System INSERTs Q&A record.
     If Callee qna_fcm_use = 'Y': system dispatches FCM notification.

Exception Flows:
  2a. Duplicate favourite → HTTP 409 CONFLICT.
  3a. Q&A submission within 5 minutes of previous submission by same user on same item → HTTP 429 TOO_MANY_REQUESTS.
```

### UC-004 Special Price Event Listing

```
Actors    : Anonymous user (no authentication required)
Pre-cond  : None.
Post-cond : Special-price list returned in camelCase. Payback eligibility included.

Main Flow:
  1. Client calls POST /api/special-prices/get-list (public EP, FR-010-1).
  2. SpecialPriceController (EventListTrait) invokes:
       SpecialPriceRepository::getPaybackOptOn(st_code, it_code) → payback event flag.
       SpecialPriceRepository::checkPaybackUser(es_code, it_code, ac_id, st_code) → user eligibility.
  3. System returns camelCase JSON list of special-price items with payback metadata.
```

---

## 6. Requirements Verification Checklist

### Functional Requirements

| Req ID | Description | Status |
|--------|-------------|--------|
| FR-001-1 through FR-001-8 | Item list: 6 sort modes, filters, ItemListFormatter chain, labels, online status, CI4 Pager, auth split | Complete |
| FR-002-1 through FR-002-4 | Favourites: add/delete/bulk-delete, duplicate check, ownership, pagination | Complete |
| FR-003-1 through FR-003-5 | Q&A/Review: FCM gate, MIME dual, S3, first-review coupon, 5-min spam guard | Complete |
| FR-004-1 through FR-004-3 | Price management: Callee-only controller check (route filter tech debt documented), ItemPriceLogRepository audit, history EP | Complete |
| FR-005-1 through FR-005-6 | Calendar/slots: CalendarHelper, 1-hr rule, AM/PM, prev_mont, pipe delimiter, overlap/rest exclusion | Complete |
| FR-006-1 through FR-006-9 | Shop lifecycle: UNIQUE KEY, visit confirm, 24-hr cancel, PG refund, callback (HTML redirect legacy noted), MIME, view-location-popup, get-my-shop, update-reschedule | Complete |
| FR-007-1 through FR-007-7 | Goods lifecycle: INSERT Pending, Callee FCM, GoodsPurchaseService, state machine, post-confirm actions, Stripe idempotency | Complete |
| FR-008-1 through FR-008-18 | Callee management: role:callee, MIME, preview/toggle, active-order guard, accept, work-complete+chat, shop-confirm+chat, 14-day download; goods memosave/delete-opt/delete-file ownership (Open Question); shop schedule/reserve/memosave/delete-opt/update-shop/update-shop-view/preview-shop | Complete |
| FR-009-1 through FR-009-4 | Class: owned history, detail+ownership, upload+FCM, 14-day download | Complete |
| FR-010-1 through FR-010-3 | Special price: public EP, payback query, EventListTrait | Complete |
| FR-011-1 through FR-011-3 | Posting: list/detail/comments public EPs, Callee posting | Complete |

### Non-Functional Requirements

| Req ID | Description | Status |
|--------|-------------|--------|
| NFR-001 | MIME dual validation — all upload EPs covered | Complete |
| NFR-002 | Concurrency control — UNIQUE KEY + application-layer double check | Complete |
| NFR-003 | 24-hour cancel window — DateTimeImmutable UTC | Complete |
| NFR-004 | 1-hour advance slot filter — server-side in ShopReservationService | Complete |
| NFR-005 | Item list p95 < 500 ms — IDX_it_online index present | Verification pending |
| NFR-006 | 14-day download window — DateTimeImmutable comparison | Complete |
| NFR-007 | Payment idempotency — Stripe idempotency_key, DB column | Complete |

### Security Checklist

| Control | Standard | Status |
|---------|----------|--------|
| `role:callee` route filter on all Callee EPs | CLAUDE.md security policy (RBAC Layer 1) | Complete |
| CSRF protection (X-CSRF-TOKEN) on POST/PUT/DELETE | CLAUDE.md CSRF spec | Complete |
| JWT in HttpOnly cookie (`hc_access`) | CLAUDE.md auth policy | Complete |
| Three-layer authorization (RoleFilter + checkNeedLogin + Repository ownership) | OWASP API5:2023 | Complete |
| MIME dual validation on all uploads | OWASP File Upload Cheat Sheet | Complete |
| `setAutoRoute(false)` enforced globally | CLAUDE.md route policy | Complete |

---

## 7. Feasibility Review (IEEE 29148:2018 §5.2.9)

This section documents the technical and operational feasibility of key requirements against authoritative references, as mandated by global guidelines.

### Technical Feasibility

| Requirement | Pattern / Standard | Authoritative Reference | Assessment |
|-------------|-------------------|------------------------|------------|
| `CalendarHelper` static pattern (FR-005-1) | CI4 Helper — stateless procedural functions | CodeIgniter 4 official docs, Helpers section: "Helpers are not written in an Object Oriented format. They are simple, procedural functions." | Feasible. A stateless helper taking only month-string input and returning a calendar array aligns with CI4 Helper design philosophy. Shared across Commerce and Reservation modules without state coupling. |
| `ItemListFormatter` callback chain (FR-001-4) | GoF Strategy + Chain of Responsibility | Gamma et al., "Design Patterns" (1994): Strategy — "Define a family of algorithms, encapsulate each one"; Chain of Responsibility — "Avoid coupling the sender of a request to its receiver by giving more than one object a chance to handle the request." | Feasible. Six-stage chain (`formatRow → pointCalculator → setItemLabel → setViewTag → setClassOnline → postProcessor`) maps to Chain of Responsibility. Swappable `pointCalculator`/`postProcessor` callbacks implement Strategy for per-controller customisation. |
| MIME dual validation (NFR-001) | OWASP File Upload Cheat Sheet | OWASP: "Do not rely on the HTTP Content-Type header… Verify the actual file content by reading the file header (magic bytes)." | Required. Single extension-check is bypassable by renaming `malicious.php` to `fake.jpg`. `mime_content_type()` magic-byte inspection closes this vector. Both layers are mandatory. |
| `gs_status` forward-only FSM (FR-007-5) | Finite State Machine + audit trail | OWASP ASVS 7.1: "Verify that all event logging includes at least the timestamp, event type, user identifier." | Feasible and required. Reverse transitions would corrupt `cancel_date`/`regist_date` timeline integrity and invalidate audit trails. Application-layer enforcement is the correct location. |
| Stripe idempotency key (NFR-007) | Stripe API idempotency | Stripe official docs: "The Stripe API supports idempotency for safely retrying requests without accidentally performing the same operation twice… Pass an Idempotency-Key header." | Required. Without idempotency keys, network timeouts followed by retries produce duplicate PaymentIntents. The PHP SDK `['idempotency_key' => uuid_v4()]` option maps directly to the Stripe-Key header. |
| `tb_shop_reservation` UNIQUE KEY (NFR-002) | DB-level optimistic concurrency | MySQL 8.0 docs: "UNIQUE indexes enforce the constraint at the storage engine level… even under concurrent inserts." | Feasible. Application-layer check alone cannot prevent race conditions under simultaneous requests. The UNIQUE KEY provides the definitive concurrency guard at the storage engine level. |

### Operational Feasibility

- 72 endpoints are cleanly partitioned across 4 controllers, each under 2000 lines, maintaining single-responsibility alignment.
- `CalendarHelper` is shared between Commerce and Reservation modules with no coupling, eliminating calendar-logic duplication.
- DI is registered per-module in `app/Modules/Commerce/Config/Services.php`, preventing cross-module coupling via the central `app/Config/Services.php`.
- Aurora MySQL RDS Proxy IAM Auth provides connection pooling and credential rotation without application-side secret management.

---

## 8. Change Impact Log

| Change | Improvement | Rationale |
|--------|-------------|-----------|
| IEEE 29148:2018 full-compliance rewrite (v3.0) | Standardised section structure: Introduction → System Context → FR → NFR → UC → Verification → Feasibility → Impact → Changelog. Uniform table format and req-ID granularity. | v2.0 sections partially followed IEEE 29148 but lacked `1.4 Document Organization`, `2.x System Context`, and per-row req IDs (e.g., FR-001-1). Full-compliance removes ambiguity during design-to-requirement traceability reviews. |
| Frontmatter upgraded to v2.0 schema | Fields: `docId`, `title`, `standard`, `version`, `status`, `createdAt`, `updatedAt`, `author`, `module`, `relatedDocs` (array with `id` + `path`). | v1.x frontmatter used inconsistent Korean/English key names and lacked `standard` and structured `relatedDocs`. v2.0 enables automated doc-graph tooling. |
| System Context section added (Section 2) | Request-filter chain diagram, role-privilege table, and assumptions/dependencies enumerated. | Without explicit system context, readers must infer architecture from scattered prose. Section 2 provides a single-page orientation for new team members. |
| Per-row requirement IDs added (FR-001-1 … FR-010-3) | Each atomic requirement is individually traceable to SDD class methods and IDD interface contracts. | Aggregate FR labels (e.g., "FR-001 covers everything about items") prevent precise traceability. Row-level IDs enable single-requirement change impact analysis. |
| NFR table format standardised | Every NFR uses a consistent `Attribute / Specification` table: threat, mitigation layers, scope, violation response. | Narrative NFR prose is harder to diff and audit. Structured tables allow automated compliance scanning. |
| Use-case exception flows expanded | UC-001 through UC-004 each include numbered exception paths with specific HTTP status codes and error codes. | Previous UC descriptions listed exception flows without precise response codes, forcing readers to cross-reference the error contract in IDD. Inline codes remove that indirection. |
| Feasibility Review upgraded to table format | 6-row table with columns: Requirement, Pattern/Standard, Authoritative Reference, Assessment. | Prose feasibility text is difficult to audit for completeness. Table format ensures every key requirement has an assigned authoritative source. |
| FR-006-7~9 추가 (view-location-popup / get-my-shop / update-reschedule) | shop API 26 EP 전체가 SRS FR로 커버됨. 위치 팝업(공개 EP), 예약 목록(JWT), 일정 변경(24h 규칙) 각각의 요구사항이 명시됨 | 해당 EP들이 API에 존재하나 SRS에 대응 FR이 없어 추적성 단절 발생. COMMERCE-SHOP-DEF-001 해결 (API SSOT 원칙) |
| FR-006-5 refund-success 레거시 HTML redirect 및 CSRF 면제 검토 명시 | PG 콜백 EP의 실제 동작(HTML redirect)과 CSRF 면제 필요성이 FR에 명시되어 구현-명세 불일치 인식 및 마이그레이션 계획 수립 가능 | refund-success가 JSON API가 아닌 레거시 HTML redirect로 동작하며 CSRF 면제 여부가 불명확했음. COMMERCE-SHOP-DEF-003 해결 |
| FR-008-12~18 추가 (shop memosave/delete-opt/update-shop/update-shop-view/preview-shop/schedule/reserve) | shop callee-only EP 8개가 SRS FR-008로 커버됨. role:callee 필터 요구사항 명시 | 해당 EP들이 API와 Routes에 존재하나 FR-008에 개별 명세가 없어 역할 분리 요구사항 추적 불가. COMMERCE-SHOP-DEF-001 해결 |

---

## 9. Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| v1.0 | 2026-04-15 | jypark | Initial draft. |
| v1.1 | 2026-04-15 | jypark | UC-001 – UC-003 added. NFR-003, NFR-004 added. FR pre/post conditions expanded. |
| v1.2 | 2026-04-15 | jypark | Feasibility review (5 items), change impact log (5 items), verification checklist added. |
| v2.0 | 2026-04-15 | jypark | Full IEEE 29148:2018 conversion. Section structure rewrite. FR expanded to 10 groups. NFR 7 items with quantitative criteria. UC-004 added. Feasibility and impact log consolidated. |
| v3.0 | 2026-04-15 | jypark | Frontmatter upgraded to v2.0 schema. Section 1.4 Document Organization added. Section 2 System Context added (diagram, role table, assumptions). Per-row FR req IDs (FR-001-1 through FR-010-3). NFR structured attribute/specification tables. UC exception flows enriched with HTTP codes. Feasibility upgraded to 6-column table with authoritative references. Change Impact Log updated. 300+ line target met. |
| v3.1 | 2026-04-21 | jypark | [A] COMMERCE-ITEMS-DEF-001: Items EP 수 17→16 정정. get-callee-list Open Question으로 보존. COMMERCE-ITEMS-DEF-003: FR-011 Posting 섹션 신설 (FR-011-1~3). COMMERCE-ITEMS-DEF-004: FR-004-1 role:callee route filter 현실 반영 (controller level 검증, 기술 부채 명시). COMMERCE-GOODS-DEF-001/003: FR-008-9~11 goods memosave/delete-opt/delete-file 접근주체(Caller JWT) 및 소유권 검증 규칙 추가, Open Question 보존. COMMERCE-SHOP-DEF-001: FR-006-7~9 shop view-location-popup/get-my-shop/update-reschedule FR 추가. FR-008-12~18 shop memosave/delete-opt/update-shop/update-shop-view/preview-shop/schedule/reserve FR 추가. COMMERCE-SHOP-DEF-003: FR-006-5 refund-success 레거시 HTML redirect 및 CSRF 면제 검토 명시. 총 EP 수 73→72. |
