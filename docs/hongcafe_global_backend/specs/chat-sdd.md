---
문서명: Chat — Software Design Document
문서 ID: chat-sdd
버전: v2.1
적용 표준: IEEE 1016:2009
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Chat Module (HongCafe Global Backend)
관련 문서: chat-srs.md, chat-idd.md
---

# Chat — Software Design Document

> version: 2.1 | standard: IEEE 1016:2009 | lastUpdated: 2026-04-15 | module: Chat

---

## 1. Introduction

### 1.1 Purpose

This Software Design Document (SDD) describes the software design of the Chat Module of HongCafe Global Backend in conformance with IEEE 1016:2009. It covers design decisions, module decomposition, data structures, interface contracts, and architectural rationale derived from the Software Requirements Specification `chat-srs.md` v2.1.

### 1.2 Scope

This SDD covers the design of all components within `app/Modules/Chat/`: three controllers, three services, three repositories, six interfaces, and two configuration files. It addresses 52 endpoints (Chat 44, GoodsChat 6, ShopChat 2).

### 1.3 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|---|---|
| SDD | Software Design Document |
| BC | Bounded Context |
| ADR | Architecture Decision Record |
| DI | Dependency Injection |
| FSM | Finite State Machine |
| VO | Value Object |
| GoF | Gang of Four (Design Patterns, Gamma et al., 1994) |
| DDL | Data Definition Language |

### 1.4 References

| Document | Location |
|---|---|
| IEEE 1016:2009 — IEEE Standard for Information Technology — Systems Design — Software Design Descriptions | IEEE Standards |
| chat-srs.md v2.1 | `docs/specs/chat-srs.md` |
| chat-idd.md v2.1 | `docs/specs/chat-idd.md` |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| GoF Design Patterns | Gamma et al., 1994 |
| MySQL 8.0 Reference Manual | https://dev.mysql.com/doc/refman/8.0/en/ |
| HongCafe Global Backend CLAUDE.md | Project root `CLAUDE.md` |

### 1.5 Overview

This document is organized using the eight design viewpoints defined in IEEE 1016:2009.

| Section | IEEE 1016 Viewpoint | Content |
|---|---|---|
| §2 | Context Viewpoint | Module boundaries and external system relationships |
| §3 | Composition Viewpoint | Directory structure and component decomposition |
| §4 | Logical Viewpoint | Class design — Controller, Service, Repository, Entity/VO |
| §5 | Dependency Viewpoint | Inter-module dependencies and DI registration |
| §6 | Information Viewpoint | DB schema and data flow |
| §7 | Patterns Viewpoint | Applied design patterns and ADRs |
| §8 | Interface Viewpoint | Component interface contracts |
| §9 | Interaction Viewpoint | Sequence diagrams for primary and error flows |
| §10 | Feasibility Review | Design decision assessments |
| §11 | Change Impact Log | Change impact records |
| §12 | Document History | Revision history |

---

## 2. Context Viewpoint

### 2.1 Module Boundaries

The Chat Module is an independent Bounded Context within the HongCafe Global Backend Modular Monolith. It communicates with adjacent modules exclusively through declared interfaces (no direct cross-module repository access).

```text
+---------------------------------------------------------------+
|                   HongCafe Global Backend                     |
|  +----------------------------------------------------------+ |
|  |                    Chat Module                           | |
|  |  ChatController(44EP) / GoodsChatController(6EP)        | |
|  |  ShopChatController(2EP)                                | |
|  |  +----------------+  +-------------+  +-----------+    | |
|  |  | ChatConnection |  | ChatList    |  | SendBird  |    | |
|  |  | Service        |  | Service     |  | Service   |    | |
|  |  +-------+--------+  +-------------+  +-----+-----+    | |
|  |          |                                   |          | |
|  |  +-------v-----------------------------------v-------+  | |
|  |  |  ChatRepository(88) / GoodsChatRepo(3) / ShopRepo|  | |
|  |  +---------------------------+-----------------------+  | |
|  +----------------------------------------+----------------+ |
|                           Aurora MySQL |                      |
|  +--------------------+  +-------------+--------------------+ |
|  |  Member Module     |  |  Commerce Module                 | |
|  |  (tb_account)      |  |  (coin balance, settlement)      | |
|  +--------------------+  +----------------------------------+ |
+----------+------------------------------------+---------------+
           | REST HTTPS                         | REST HTTPS
   +-------v-------+                   +--------v--------+
   |  Next.js 16   |                   |  SendBird API   |
   |  Frontend     |                   |  (SaaS)         |
   +---------------+                   +-----------------+
```

### 2.2 External System Relationships

| External System | Protocol | Purpose | Failure Mode |
|---|---|---|---|
| SendBird Platform API | REST HTTPS | Real-time group channel creation and message delivery | Return empty array (Graceful Degradation) |
| Hermes Server | REST HTTP / MySQL direct | Chat session call record registration for billing | Log error, continue |
| Firebase Cloud Messaging | FCM HTTP v1 | Push notification to callee and caller | Log error, non-blocking |
| AWS S3 | AWS SDK | Chat file upload and download | Return 500 `INTERNAL` |

---

## 3. Composition Viewpoint

### 3.1 Directory Structure

```text
app/Modules/Chat/
├── Controllers/
│   ├── ChatController.php           1600+ lines -- 44 endpoints
│   ├── GoodsChatController.php      213 lines -- 6 endpoints
│   └── ShopChatController.php       114 lines -- 2 endpoints
├── Services/
│   ├── ChatConnectionService.php    107 lines -- unified chat room creation
│   ├── ChatListService.php          200 lines -- PC list formatting
│   └── SendBirdService.php          116 lines -- SendBird API wrapper
├── Repositories/
│   ├── ChatRepository.php           88 methods (legacy-integrated)
│   ├── GoodsChatRepository.php      96 lines -- 3 methods
│   └── ShopChatRepository.php       98 lines -- 3 methods
├── Interfaces/
│   ├── ChatConnectionServiceInterface.php
│   ├── ChatListServiceInterface.php
│   ├── SendBirdServiceInterface.php
│   ├── ChatRepositoryInterface.php
│   ├── GoodsChatRepositoryInterface.php
│   └── ShopChatRepositoryInterface.php
└── Config/
    ├── Routes.php                    52 routes
    └── Services.php                  6 DI bindings
```

### 3.2 Endpoint Distribution

| Controller | Endpoint Count | Authentication | Responsibility |
|---|---|---|---|
| `ChatController` | 44 | JWT (optional for some) | Item list, chat connect, timing, message, file, status management |
| `GoodsChatController` | 6 | JWT | Product inquiry chat, estimate workflow |
| `ShopChatController` | 2 | JWT | O2O in-person consultation chat |

---

## 4. Logical Viewpoint

### 4.1 Controller Layer

| Class | EPs | Authentication | Description |
|---|---|---|---|
| `ChatController` | 44 | JWT (optional for some) | List, connect, timing, message, status |
| `GoodsChatController` | 6 | JWT | Product inquiry chat, estimate workflow |
| `ShopChatController` | 2 | JWT | In-person consultation chat |

All controllers inherit from `BaseController` and use `checkNeedLogin()` for JWT validation. The `role:callee` filter is applied as a route-level filter for callee-restricted endpoints.

### 4.2 Service Layer

| Class | Primary Method(s) | Description |
|---|---|---|
| `ChatConnectionService` | `connect(array $params, callable $findExistingRoom): array` | Unified chat room creation: block check, existing room lookup (callback), SendBird channel creation, room code generation (`CHAT-YYYYMMDDHHmmss-XXX`), DB save |
| `ChatListService` | `buildPcItemList(array $result, array $data, string $stCode, int $total): array` | PC item list formatting: tag, notice, point, phone number, comment mapping |
| `SendBirdService` | `createGroupChannel(array $userIds, string $customType, array $data): array`, `sendMessage(string $channelUrl, string $userId, string $message, ...): array` | SendBird API wrapper: group channel creation and message delivery |

### 4.3 Repository Layer

| Class | Method Count | Categories |
|---|---|---|
| `ChatRepository` | **88** | Item retrieval (15), comments (5), QnA (5), postings (5), favorites (3), chat room CRUD (10), timing (8), messages (5), status (10), settlement (5), greeting (2), miscellaneous (15) |
| `GoodsChatRepository` | 3 | `getGoodsRoom`, `cancelEstimate`, `updateEstimateMessageId` |
| `ShopChatRepository` | 3 | `getShopRoom`, `cancelEstimate`, `updateLastMessage` |

### 4.4 Entity and Value Object

The Chat Module currently passes data using legacy PHP arrays. Migration to Entity classes and Value Objects is planned incrementally on the `dev/migration` branch.

| Target | Current State | Migration Target | Branch |
|---|---|---|---|
| Chat room data | PHP `array` | `ChatRoom` Entity | `dev/migration` |
| Estimate data | PHP `array` | `GoodsSell` Entity | `dev/migration` |
| `connect()` return | PHP `array` | `ChatConnectionResult` VO | Post-Entity migration |

---

## 5. Dependency Viewpoint

### 5.1 DI Registration

All dependency injection bindings for the Chat Module are registered in `app/Modules/Chat/Config/Services.php`. Binding in the central `app/Config/Services.php` is prohibited.

| Interface | Concrete Class | Scope |
|---|---|---|
| `ChatConnectionServiceInterface` | `ChatConnectionService` | Shared (singleton) |
| `ChatListServiceInterface` | `ChatListService` | Shared (singleton) |
| `SendBirdServiceInterface` | `SendBirdService` | Shared (singleton) |
| `ChatRepositoryInterface` | `ChatRepository` | Shared (singleton) |
| `GoodsChatRepositoryInterface` | `GoodsChatRepository` | Shared (singleton) |
| `ShopChatRepositoryInterface` | `ShopChatRepository` | Shared (singleton) |

### 5.2 Cross-Module Dependencies

| Dependency Direction | Method | Description |
|---|---|---|
| Chat -> Member | `service('memberService')` | User and callee account lookup (`tb_account`) |
| Chat -> Commerce | `service('coinService')` | Coin balance inquiry and deduction |
| Chat -> Shared | `service('csrfTokenService')` | CSRF validation (cross-cutting) |

### 5.3 Filter Chain

All state-changing requests traverse the following filter chain in order:

```
ratelimit -> csrftoken -> auth -> role:callee (where applicable) -> Controller
```

---

## 6. Information Viewpoint

### 6.1 Core Tables

| Table | Description | Key Columns |
|---|---|---|
| `tb_chat_rooms` | Chat rooms | `cr_no`, `room_code`, `cr_type`, `cr_status`, `cr_last_message`, `cr_unread_caller`, timing fields |
| `tb_goods_sell` | Estimates and sales | `gs_no`, `gs_status` (0-5), `gs_price`, `messageId`, `cancel_date` |
| `tb_items` | Consultation items | `it_code`, `it_online`, `it_coin_price` |
| `tb_comment` | Reviews and comments | `cm_no`, `cm_parent` (threaded) |

### 6.2 Room Code Generation Rule

```
CHAT-{YYYYMMDDHHmmss}-{XXX}
      creation timestamp       random 3 characters
```

- Timestamp: UTC-based `DateTimeImmutable`, formatted as `YYYYMMDDHHmmss`
- Random segment: 3 alphanumeric characters generated at creation time
- UNIQUE constraint on `room_code` prevents collisions

### 6.3 tb_chat_rooms DDL

```sql
CREATE TABLE tb_chat_rooms (
    cr_no       INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    room_code   VARCHAR(30)     NOT NULL COMMENT 'CHAT-YYYYMMDDHHmmss-XXX',
    cr_type     ENUM('chat','goods','shop') NOT NULL,
    cr_status   VARCHAR(20)     DEFAULT 'standby',
    ac_id       VARCHAR(256)    NOT NULL,
    ce_code     VARCHAR(50)     NOT NULL,
    it_code     VARCHAR(50)     DEFAULT NULL,
    gd_code     VARCHAR(50)     DEFAULT NULL COMMENT 'goods chat',
    sh_code     VARCHAR(50)     DEFAULT NULL COMMENT 'shop chat',
    channel_url VARCHAR(200)    DEFAULT NULL COMMENT 'SendBird channel',
    cr_last_message TEXT        DEFAULT NULL,
    cr_unread_caller INT        DEFAULT 0,
    cr_last_date DATETIME       DEFAULT NULL,
    cr_start_time DATETIME      DEFAULT NULL,
    cr_end_time  DATETIME       DEFAULT NULL,
    cr_add_time  INT            DEFAULT 0 COMMENT 'extension time (seconds)',
    regist_date  DATETIME       DEFAULT CURRENT_TIMESTAMP,
    st_code      VARCHAR(20)    DEFAULT 'hongcafe',
    UNIQUE KEY uq_room_code (room_code),
    INDEX idx_ac_id  (ac_id),
    INDEX idx_ce_code (ce_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 6.4 GoodsSell FSM State Transitions

```
0 (pending) -> 1 (confirmed) -> 2 (work complete) -> 3 (purchase confirmed)
    \________________________________> 4 (cancelled, unidirectional, non-reversible)
```

State 4 (cancelled) is terminal. No transition from state 4 to any other state is permitted.

---

## 7. Patterns Viewpoint

### 7.1 Applied Design Patterns

| Pattern | Location | Rationale |
|---|---|---|
| Strategy (GoF, callable variant) | `ChatConnectionService::connect(callable $findExistingRoom)` | GoodsChat and ShopChat share the same connection flow except for "existing room lookup". PHP callable injection avoids code duplication across three controllers while enabling mock injection in unit tests |
| Repository | `ChatRepository`, `GoodsChatRepository`, `ShopChatRepository` | Isolates DB access from business logic; enables independent unit testing of service layer via mock repositories |
| Facade | `SendBirdService` | Wraps complex SendBird REST API interactions behind a simple, testable interface |
| Template Method (planned) | `ChatRoom` and `GoodsSell` Entity migration | Will replace array-based data passing with typed Entity classes on `dev/migration` branch |

### 7.2 Architecture Decision Records

| ADR | Decision | Rationale | Alternative |
|---|---|---|---|
| ADR-001 | `ChatConnectionService` callable callback pattern | Goods and Shop connection flows are identical except for the "find existing room" step. PHP callable injection (GoF Strategy variant) unifies the shared flow without requiring duplication. Unit tests inject mock callables | Duplicate connection logic in each Controller |
| ADR-002 | SendBird as external messaging service | Self-hosting real-time messaging infrastructure on EC2 incurs ongoing operational overhead exceeding SaaS subscription costs. SendBird provides channel management, message history, and read-status out of the box. OWASP API3:2023 channel-level permission controls are built in | Self-hosted Socket.io + Redis Pub/Sub |
| ADR-003 | ChatRepository at 88 methods (legacy-integrated) | Immediate decomposition would require coordinated changes across all 52 endpoints simultaneously, creating unacceptable operational risk. Incremental separation on `dev/migration` is the adopted strategy | Immediate decomposition |
| ADR-004 | ENUM type for `cr_type` | Only three stable values exist (chat / goods / shop). ENUM provides DB-level type safety (OWASP API6:2023), efficient index usage, and rejects invalid values at the storage layer | VARCHAR(20) + CHECK constraint |
| ADR-005 | `cr_add_time` stored as INT (seconds) | Integer seconds arithmetic is simpler than PHP `DateInterval` or MySQL `TIME` type. The `TIME` type is limited to 839 hours and is inappropriate for cumulative extension increments | MySQL TIME type, PHP DateInterval |

---

## 8. Interface Viewpoint

### 8.1 Internal Interface Contracts

**ChatConnectionServiceInterface**

```php
public function connect(array $params, callable $findExistingRoom): array;
// Returns: ['status' => 'rejected'|'existing'|'created'|'error',
//           'room_code' => string, 'channel_url' => string]
```

**ChatListServiceInterface**

```php
public function buildPcItemList(
    array $result, array $data, string $stCode, int $total
): array;
```

**SendBirdServiceInterface**

```php
public function getAdminId(): string;
public function callApi(string $endpoint, string $method, array $data = []): array;
public function createGroupChannel(
    array $userIds, string $customType, array $data = []
): array;
public function sendMessage(
    string $channelUrl, string $userId, string $message,
    string $customType = '', string $data = ''
): array;
```

**ChatRepositoryInterface**

88 methods organized in the following categories: item retrieval (15), comments (5), QnA (5), postings (5), favorites (3), chat room CRUD (10), timing (8), messages (5), status (10), settlement (5), greeting (2), miscellaneous (15). Full signatures are specified in `chat-idd.md` §2.

**GoodsChatRepositoryInterface**

```php
public function getGoodsRoom(string $gdCode, string $acId): ?object;
public function cancelEstimate(int $gsNo): void;
public function updateEstimateMessageId(array $post): void;
```

**ShopChatRepositoryInterface**

```php
public function getShopRoom(string $gdCode, string $acId): ?object;
public function cancelEstimate(int $gsNo): void;
public function updateLastMessage(array $post): void;
```

### 8.2 API Response Contracts

All endpoints conform to the project-wide API response standard.

| Condition | HTTP Status | Response Body |
|---|---|---|
| Success (retrieve) | 200 | `{ "data": { ... } }` |
| Success (create) | 201 | `{ "data": { ... } }` |
| Error | 4xx / 5xx | `{ "error": { "code": "...", "message": "..." } }` |

DB `snake_case` fields are converted to API `camelCase` in all responses (e.g., `room_code` -> `roomCode`, `gs_no` -> `gsNo`).

---

## 9. Interaction Viewpoint

### 9.1 GoodsChat Connect — Normal Flow

```text
Client -> GoodsChatController::chatConnect()
           |- Product information retrieved
           |- ChatConnectionService::connect(params, findExistingRoom)
           |    |- Block and rejection check
           |    |- findExistingRoom callback: existing room lookup
           |    |- SendBirdService::createGroupChannel([admin, ce_code, ac_id])
           |    |- Room code generated: CHAT-YYYYMMDDHHmmss-XXX
           |    +- ChatRepository::insertRoom()
           +- HTTP 201 { "data": { "status": "created",
                                   "roomCode": "CHAT-...",
                                   "channelUrl": "sendbird_group_channel_..." } }
```

### 9.2 GoodsChat Connect — Error Flows

```text
Client -> GoodsChatController::chatConnect()
           |- ChatConnectionService::connect(params, findExistingRoom)
           |    |- [Blocked] ChatRepository::isBlocked(ac_id, ce_code) = true
           |    |         +- return { status: 'rejected' }
           |    |              -> HTTP 403 { "error": { "code": "REJECTED" } }
           |    |
           |    +- [Insufficient coins] Coin balance retrieved: insufficient
           |                  +- return { status: 'error', code: 'INSUFFICIENT_COIN' }
           |                       -> HTTP 400 { "error": { "code": "INSUFFICIENT_COIN" } }
           |
           +- [Callee offline] ChatRepository::getCalleeStatus() = 'off'
                              -> HTTP 409 { "error": { "code": "CALLEE_OFFLINE" } }
```

### 9.3 Estimate Workflow — State Transitions

```text
Callee -> POST /api/goods-chats/send-estimate
           |- tb_goods_sell INSERT (gs_status=0)
           +- SendBirdService::sendMessage() -> messageId stored

Caller -> POST /api/goods-chats/get-estimate -> returns gs_status

Caller -> [Confirm] gs_status transitions: 0 -> 1 -> 2 -> 3
Caller -> [Cancel]  POST /api/goods-chats/cancel-estimate
           |- gs_status = 4 (terminal, non-reversible)
           +- cancel_date = CURRENT_TIMESTAMP (UTC)
```

### 9.4 Timing and Absence Detection Flow

```text
Client polls POST /api/chats/get-remain-time every ~1 second
  +- Returns: (cr_start_time + cr_add_time) - NOW() in seconds (UTC)

Client polls POST /api/chats/absence-check periodically
  +- If (NOW() - last_response_time) > 300 seconds:
         cr_status updated to 'absent'
         Hermes::updateChatMiss() called
```

---

## 10. Feasibility Review

> Basis: GoF Design Patterns (Gamma et al., 1994), OWASP API Security Top 10 2023, MySQL 8.0 Reference Manual

| Review ID | Topic | Conclusion | Rationale | Alternative | Trade-offs |
|---|---|---|---|---|---|
| FEA-001 | ChatConnectionService callable pattern | GoF Strategy variant is appropriate | GoodsChat and ShopChat differ only in "existing room lookup"; all other steps are identical. PHP callable injection is more concise than Template Method. Mock callable injection enables easy unit testing. Type safety is supplemented by explicit Interface | Duplicate in each Controller (3x duplication) | Callback: high flexibility, requires Interface for type safety. Template Method: type-safe but increases class count |
| FEA-002 | ENUM for `tb_chat_rooms.cr_type` | ENUM is appropriate | Three fixed values (chat/goods/shop) with low expansion probability. MySQL ENUM provides efficient index usage and DB-level type safety addressing OWASP API6:2023. Invalid type values rejected at storage layer | VARCHAR(20) + CHECK constraint | ENUM: type-safe and space-efficient. Adding a value requires `ALTER TABLE` |
| FEA-003 | `room_code` VARCHAR(30) UNIQUE | Single UNIQUE index is appropriate | `CHAT-YYYYMMDDHHmmss-XXX` format is 24 characters maximum. UNIQUE KEY simultaneously enforces uniqueness and serves as the primary lookup index for chat room retrieval | UUID v4 (36 characters) | room_code: human-readable with embedded timestamp. UUID: globally unique but less readable |
| FEA-004 | Legacy array-based data passing | Incremental Entity migration adopted | Immediate migration requires modifying all 88 ChatRepository methods simultaneously — unacceptably high risk. Incremental conversion of ChatRoom and GoodsSell on `dev/migration` branch minimizes operational disruption | Immediate full Entity migration | Incremental: operational stability, temporary dual maintenance. Immediate: better code quality, high short-term risk |
| FEA-005 | `cr_add_time` INT (seconds) | Integer seconds storage is appropriate | Integer seconds arithmetic is simpler than PHP `DateInterval`. Intuitive for addition and comparison. Maximum extension time is well within INT range (2^31 seconds) | MySQL TIME type, PHP DateInterval | INT: simple arithmetic, broad compatibility. TIME: limited to 839 hours, inappropriate for cumulative extension |

---

## 11. Change Impact Log

| Change Item | Impact Scope | Improvement | Rationale |
|---|---|---|---|
| Restructured to IEEE 1016:2009 eight viewpoints | Entire document restructured | Context, Composition, Logical, Dependency, Information, Patterns, Interface, and Interaction viewpoints explicitly address all design dimensions required by IEEE 1016:2009 | IEEE 1016:2009 compliance: eight viewpoints required |
| Dependency Viewpoint added (§5) | New section | DI registration table and filter chain explicitly documented; cross-module dependency direction made visible | IEEE 1016:2009 Dependency Viewpoint requirement |
| Patterns Viewpoint added (§7) | New section | Design patterns (Strategy, Repository, Facade) and ADRs (5 items) formally documented with rationale and alternatives | IEEE 1016:2009 Patterns Viewpoint requirement |
| Interaction Viewpoint expanded (§9) | New section | Four sequence flows (normal connect, error flows, estimate FSM, timing/absence) formally specified in text-based sequence notation | IEEE 1016:2009 Interaction Viewpoint requirement |
| tb_chat_rooms DDL added (§6.3) | Information Viewpoint §6 | Actual DDL specified; developers and DBAs reference a single document for schema creation | Schema migration guideline compliance |
| Entity/VO migration plan added (§4.4) | Logical Viewpoint §4 | Current array-based state and migration plan documented; shares `dev/migration` work direction with team | Architectural transparency |
| Full English rewrite | All sections | All Korean content converted to English per IEEE standard requirements | IEEE standard compliance |
| Version v1.2 -> v2.1 | Document header and revision log | IEEE standard conversion, eight-viewpoint restructuring, and English rewrite reflected as major version | Document history clarification |

---

## 12. Document History

| Date | Version | Changes | Author |
|---|---|---|---|
| 2026-04-15 | 1.0.0 | Initial draft | jypark |
| 2026-04-15 | 1.2.0 | Feasibility review (5 items), change impact log (6 items), tb_chat_rooms DDL, Entity/VO section, error flow sequence added | jypark |
| 2026-04-15 | 2.1.0 | Full restructure to IEEE 1016:2009 eight viewpoints. All Korean content converted to English. Context, Composition, Logical, Dependency, Information, Patterns, Interface, Interaction viewpoints structured. ADRs (5), DI table, filter chain, FSM state transition, four sequence flows added | jypark |
