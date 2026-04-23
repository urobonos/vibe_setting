---
문서명: Chat — Interface Design Document
문서 ID: chat-idd
버전: v2.0
적용 표준: MIL-STD-498 (Interface Design Description)
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Chat Module (HongCafe Global Backend)
관련 문서: chat-sdd.md, chat-srs.md
---

# Chat — Interface Design Document

> version: 2.0 | standard: MIL-STD-498 IDD | lastUpdated: 2026-04-15 | module: Chat

---

## 1. Scope (범위)

### 1.1 Identification (식별)

본 문서는 HongCafe Global Backend Chat 모듈의 인터페이스 설계를 MIL-STD-498 Interface Design Description (IDD) 표준에 따라 명세한다.

| 항목 | 내용 |
|------|------|
| 문서 ID | chat-idd |
| 대상 시스템 | Chat Module — HongCafe Global Backend |
| 기반 SDD | `chat-sdd.md` v2.0 |
| 인터페이스 총수 | 내부 6개 / 외부 4개 |
| EP 총수 | 52개 (Chat 44 + GoodsChat 6 + ShopChat 2) |

### 1.2 System Overview (시스템 개요)

Chat 모듈은 HongCafe Global Backend Modular Monolith 아키텍처 내에서 실시간 채팅 상담 연결, 타이밍 제어, 상품채팅 견적 워크플로우, 매장채팅을 담당한다. SendBird (메시징), Hermes (통화 기록), FCM (푸시 알림), AWS S3 (파일 스토리지) 외부 시스템과 연동한다.

### 1.3 Document Overview (문서 개요)

본 IDD는 MIL-STD-498 §DI-IPSC-81436 기준에 따라 각 인터페이스를 5개 하위 섹션(식별자/데이터/통신/에러/흐름)으로 기술한다.

| 섹션 | 내용 |
|------|------|
| §2 | 내부 인터페이스 6개 (IF-INT-001~006) — PHP 시그니처 포함 |
| §3 | 외부 인터페이스 4개 (IF-EXT-001~004) — 프로토콜/인증/재시도 명세 |
| §4 | 이벤트 계약 (Events and Signals) |
| §5 | 에러 처리 계약 (Error Handling Contract) |
| §6 | 데이터 포맷 (Data Formats and Encoding) |
| §7 | 타당성 검토 |
| §8 | 변경 영향 기록 |
| §9 | 요구사항 추적성 매트릭스 |

---

## 2. References (참조 문서)

| 문서 | 위치 / 출처 |
|------|-----------|
| MIL-STD-498 — Software Development and Documentation | US DoD Standards |
| DI-IPSC-81436 — Interface Design Description (IDD) | MIL-STD-498 Data Item |
| chat-srs.md v2.0 | `docs/specs/chat-srs.md` |
| chat-sdd.md v2.0 | `docs/specs/chat-sdd.md` |
| SendBird Platform API Documentation v3 | https://sendbird.com/docs/chat/platform-api/v3 |
| RFC 7231 — HTTP/1.1 Semantics and Content | IETF |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| HongCafe Global Backend CLAUDE.md | 프로젝트 루트 `CLAUDE.md` |

---

## 3. Internal Interfaces (내부 인터페이스)

MIL-STD-498 IDD §3 — 각 내부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-INT-001: ChatConnectionServiceInterface

#### 3.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | ChatConnectionServiceInterface |
| 파일 경로 | `app/Modules/Chat/Interfaces/ChatConnectionServiceInterface.php` |
| 제공 컴포넌트 | `ChatConnectionService` |
| 소비 컴포넌트 | `GoodsChatController`, `ShopChatController` |

#### 3.1.2 Data Elements (데이터 요소)

**입력 — `$params` array:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `ac_id` | string | Y | Caller 사용자 ID (JWT 추출) |
| `ce_code` | string | Y | Callee 상담사 코드 |
| `it_code` | string | N | 아이템 코드 (일반 채팅) |
| `gd_code` | string | N | 상품 코드 (상품 채팅) |
| `sh_code` | string | N | 매장 코드 (매장 채팅) |
| `st_code` | string | Y | 서비스 코드 (기본: `hongcafe`) |
| `cr_type` | string | Y | 채팅 유형: `chat` / `goods` / `shop` |

**입력 — `$findExistingRoom` callable:**

```php
// GoodsChat 예시 callback
$findExistingRoom = function() use ($gdCode, $acId): ?object {
    return $this->goodsChatRepository->getGoodsRoom($gdCode, $acId);
};
```

**출력 — 반환 array:**

| 필드 | 타입 | 조건 | 설명 |
|------|------|------|------|
| `status` | string | 항상 | `'created'` / `'existing'` / `'rejected'` / `'error'` |
| `room_code` | string | status = created/existing | 채팅방 코드 (`CHAT-YYYYMMDDHHmmss-XXX`) |
| `channel_url` | string | status = created/existing | SendBird 채널 URL |
| `code` | string | status = error | 에러 코드 (`INSUFFICIENT_COIN`, `CALLEE_OFFLINE` 등) |

#### 3.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DI 등록 | `app/Modules/Chat/Config/Services.php` |
| 패턴 | GoF Strategy 변형 — callable callback 주입 |

#### 3.1.4 Error Handling (에러 처리)

| 에러 조건 | 반환값 | 설명 |
|---------|------|------|
| 차단/거부된 사용자 | `['status' => 'rejected']` | Controller에서 403 응답 |
| 코인 잔액 부족 | `['status' => 'error', 'code' => 'INSUFFICIENT_COIN']` | Controller에서 400 응답 |
| 상담사 오프라인 | `['status' => 'error', 'code' => 'CALLEE_OFFLINE']` | Controller에서 409 응답 |
| SendBird API 오류 | `['status' => 'error', 'code' => 'INTERNAL']` | Controller에서 500 응답 |

#### 3.1.5 Data Flow (데이터 흐름)

```
GoodsChatController
  └─ ChatConnectionService::connect($params, $findExistingRoom)
        ├─ ChatRepository::isBlocked(ac_id, ce_code)
        ├─ $findExistingRoom() → GoodsChatRepository::getGoodsRoom()
        ├─ SendBirdService::createGroupChannel(userIds, customType)
        └─ ChatRepository::insertRoom(roomData)
```

**PHP 시그니처:**

```php
interface ChatConnectionServiceInterface
{
    /**
     * 채팅방 생성 통합 메서드.
     * @param array    $params            채팅 연결 파라미터 (ac_id, ce_code, cr_type 등)
     * @param callable $findExistingRoom  기존 채팅방 조회 callback (?object 반환)
     * @return array   ['status' => 'created'|'existing'|'rejected'|'error', ...]
     */
    public function connect(array $params, callable $findExistingRoom): array;
}
```

---

### IF-INT-002: ChatListServiceInterface

#### 3.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | ChatListServiceInterface |
| 파일 경로 | `app/Modules/Chat/Interfaces/ChatListServiceInterface.php` |
| 제공 컴포넌트 | `ChatListService` |
| 소비 컴포넌트 | `ChatController` |

#### 3.2.2 Data Elements (데이터 요소)

**입력:**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$result` | array | DB 조회 결과 로우 배열 |
| `$data` | array | 요청 파라미터 (정렬 방식, 필터 등) |
| `$stCode` | string | 서비스 코드 |
| `$total` | int | 총 결과 건수 |

**출력:** 포맷팅된 아이템 배열. 각 아이템에 태그/공지/포인트/전화번호/댓글 매핑 포함.

#### 3.2.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). DI 등록: `Chat/Config/Services.php`.

#### 3.2.4 Error Handling (에러 처리)

SendBird 오류 시 관련 필드 빈 값 반환. 예외 전파 없음.

#### 3.2.5 Data Flow (데이터 흐름)

```
ChatController::getListPc()
  └─ ChatListService::buildPcItemList($result, $data, $stCode, $total)
        ├─ 태그 포맷팅
        ├─ 공지 매핑
        ├─ 포인트 표기
        ├─ 전화번호 배치
        └─ 댓글 수 매핑
```

**PHP 시그니처:**

```php
interface ChatListServiceInterface
{
    public function buildPcItemList(array $result, array $data, string $stCode, int $total): array;
}
```

---

### IF-INT-003: SendBirdServiceInterface

#### 3.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-003 |
| 인터페이스명 | `SendBirdServiceInterface` |
| 파일 경로 | `app/Modules/Chat/Interfaces/SendBirdServiceInterface.php` |
| 제공 컴포넌트 | `SendBirdService` |
| 소비 컴포넌트 | `ChatConnectionService`, `GoodsChatController` |

#### 3.3.2 Data Elements (데이터 요소)

**createGroupChannel 입력:**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$userIds` | array | 채널 참여자 ID 배열 (`[admin, ce_code, ac_id]`) |
| `$customType` | string | 채널 커스텀 타입 (`goods_chat`, `shop_chat`, 등) |
| `$data` | array | 추가 채널 데이터 (선택적) |

**createGroupChannel 출력:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `channel_url` | string | SendBird 그룹 채널 URL |
| `name` | string | 채널명 |
| `created_at` | int | 생성 유닉스 타임스탬프 |

**sendMessage 입력:**

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `$channelUrl` | string | 대상 채널 URL |
| `$userId` | string | 발신자 사용자 ID |
| `$message` | string | 메시지 본문 |
| `$customType` | string | 메시지 커스텀 타입 (선택적) |
| `$data` | string | 메시지 메타데이터 JSON 문자열 (선택적) |

#### 3.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process). 내부에서 SendBird REST API HTTP 호출 |
| 타임아웃 | cURL 기본값 (30초) |
| 인증 | `Api-Token: {SENDBIRD_API_TOKEN}` 헤더 |

#### 3.3.4 Error Handling (에러 처리)

SendBird API HTTP 오류 또는 예외 발생 시 빈 배열(`[]`) 반환 + 에러 로그 기록. 예외 전파 없음 (Graceful Degradation, NFR-004).

#### 3.3.5 Data Flow (데이터 흐름)

```
ChatConnectionService
  └─ SendBirdService::createGroupChannel([admin, ce_code, ac_id], 'goods_chat')
        └─ callApi('POST', '/v3/group_channels', {...})
              └─ cURL → SendBird REST API
```

**PHP 시그니처:**

```php
interface SendBirdServiceInterface
{
    public function getAdminId(): string;
    public function callApi(string $endpoint, string $method, array $data = []): array;
    public function createGroupChannel(array $userIds, string $customType, array $data = []): array;
    public function sendMessage(
        string $channelUrl,
        string $userId,
        string $message,
        string $customType = '',
        string $data = ''
    ): array;
}
```

---

### IF-INT-004: ChatRepositoryInterface

#### 3.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-004 |
| 인터페이스명 | `ChatRepositoryInterface` |
| 파일 경로 | `app/Modules/Chat/Interfaces/ChatRepositoryInterface.php` |
| 제공 컴포넌트 | `ChatRepository` |
| 소비 컴포넌트 | `ChatController`, `GoodsChatController`, `ShopChatController`, `ChatConnectionService` |

#### 3.4.2 Data Elements (데이터 요소)

**메서드 카테고리별 분류 (총 88 메서드):**

| 카테고리 | 메서드 수 | 대표 메서드 |
|---------|--------|----------|
| 아이템 조회 | 15 | `getItemList()`, `getItemByCode()`, `getItemByGdCode()` |
| 댓글 | 5 | `getCommentList()`, `insertComment()` |
| Q&A | 5 | `insertItemQna()`, `getQnaList()` |
| 포스팅 | 5 | `getPostingList()`, `getPostingDetail()` |
| 즐겨찾기 | 3 | `addLike()`, `deleteLike()`, `getLikeList()` |
| 채팅방 CRUD | 10 | `insertRoom()`, `getRoomByCode()`, `updateRoomStatus()` |
| 타이밍 | 8 | `getRemainTime()`, `updateAddTime()`, `getLastResponseTime()` |
| 메시지 | 5 | `insertMessageLog()`, `markAsRead()` |
| 상태 관리 | 10 | `getCalleeStatus()`, `isBlocked()`, `updateAbsenceStatus()` |
| 정산 | 5 | `insertSettlement()`, `updateSettlement()` |
| 인사말 | 2 | `getGreeting()`, `updateGreeting()` |
| 기타 | 15 | `getRemainCoin()`, `getMemo()`, 등 |

#### 3.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 통신 방식 | 동기 PHP 메서드 호출 (In-Process) |
| DB 접근 | CI4 Query Builder 우선. CTE/Window Function은 `$db->query()` + named binding |
| DB 연결 | Aurora MySQL (RDS Proxy, IAM Auth) |

#### 3.4.4 Error Handling (에러 처리)

DB 쿼리 실패 시 CI4 Database Exception 전파. Controller에서 500 `INTERNAL` 응답.

**소유권 검증 패턴 (OWASP API1:2023 BOLA 대응):**
```sql
-- 채팅방 조회 시 소유권 조건 내장
WHERE room_code = :room_code AND (ac_id = :ac_id OR ce_code = :ce_code)
```

#### 3.4.5 Data Flow (데이터 흐름)

```
Controller/Service
  └─ ChatRepository::method()
        └─ CI4 Query Builder / $db->query()
              └─ Aurora MySQL (RDS Proxy)
```

---

### IF-INT-005: GoodsChatRepositoryInterface

#### 3.5.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-005 |
| 인터페이스명 | `GoodsChatRepositoryInterface` |
| 파일 경로 | `app/Modules/Chat/Interfaces/GoodsChatRepositoryInterface.php` |
| 제공 컴포넌트 | `GoodsChatRepository` |
| 소비 컴포넌트 | `GoodsChatController` |

#### 3.5.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `getGoodsRoom($gd_code, $ac_id)` | string, string | `?object` | 상품 코드 + 사용자 ID로 기존 채팅방 조회 |
| `cancelEstimate($gs_no)` | int | void | `gs_status=4`, `cancel_date = UTC NOW()` 설정 |
| `updateEstimateMessageId(array $post)` | array{gs_no, messageId} | void | SendBird `messageId` 사후 업데이트 |

#### 3.5.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). CI4 Query Builder. Aurora MySQL.

#### 3.5.4 Error Handling (에러 처리)

`getGoodsRoom` — 미존재 시 `null` 반환 (예외 없음).
`cancelEstimate` — 이미 취소된 레코드(`gs_status=4`) 접근 시 애플리케이션 레벨에서 사전 차단.

#### 3.5.5 Data Flow (데이터 흐름)

```php
interface GoodsChatRepositoryInterface
{
    public function getGoodsRoom(string $gdCode, string $acId): ?object;
    public function cancelEstimate(int $gsNo): void;
    public function updateEstimateMessageId(array $post): void;
}
```

---

### IF-INT-006: ShopChatRepositoryInterface

#### 3.6.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-006 |
| 인터페이스명 | `ShopChatRepositoryInterface` |
| 파일 경로 | `app/Modules/Chat/Interfaces/ShopChatRepositoryInterface.php` |
| 제공 컴포넌트 | `ShopChatRepository` |
| 소비 컴포넌트 | `ShopChatController` |

#### 3.6.2 Data Elements (데이터 요소)

| 메서드 | 입력 | 출력 | 설명 |
|-------|------|------|------|
| `getShopRoom($sh_code, $ac_id)` | string, string | `?object` | 매장 코드 + 사용자 ID로 기존 채팅방 조회 |
| `cancelEstimate($gs_no)` | int | void | 견적 취소 (`gs_status=4`) |
| `updateLastMessage(array $post)` | array | void | `cr_last_message`, `cr_last_date` 갱신 |

#### 3.6.3 Communication Attributes (통신 속성)

동기 PHP 메서드 호출 (In-Process). CI4 Query Builder. Aurora MySQL.

#### 3.6.4 Error Handling (에러 처리)

`getShopRoom` — 미존재 시 `null` 반환.

#### 3.6.5 Data Flow (데이터 흐름)

```php
interface ShopChatRepositoryInterface
{
    public function getShopRoom(string $shCode, string $acId): ?object;
    public function cancelEstimate(int $gsNo): void;
    public function updateLastMessage(array $post): void;
}
```

---

## 4. External Interfaces (외부 인터페이스)

MIL-STD-498 IDD §4 — 각 외부 인터페이스를 5개 하위 섹션으로 기술한다.

---

### IF-EXT-001: SendBird Platform API

#### 4.1.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | SendBird Platform API |
| 대상 시스템 | SendBird 메시징 플랫폼 (SaaS) |
| 연동 컴포넌트 | `SendBirdService` |
| 환경변수 | `SENDBIRD_API_URL`, `SENDBIRD_API_TOKEN` |

#### 4.1.2 Data Elements (데이터 요소)

**EP-1: 그룹 채널 생성**

```
HTTP Method : POST
URL         : {SENDBIRD_API_URL}/v3/group_channels
```

요청 페이로드:
```json
{
    "user_ids": ["admin_001", "CE-20260101-001", "user@example.com"],
    "custom_type": "goods_chat",
    "is_public": true,
    "operator_ids": ["admin_001"]
}
```

응답 페이로드 (HTTP 200):
```json
{
    "channel_url": "sendbird_group_channel_12345_abcdef",
    "name": "",
    "created_at": 1744704000
}
```

**EP-2: 메시지 전송**

```
HTTP Method : POST
URL         : {SENDBIRD_API_URL}/v3/group_channels/{channel_url}/messages
```

요청 페이로드:
```json
{
    "message_type": "MESG",
    "user_id": "CE-20260101-001",
    "message": "견적을 보내드립니다",
    "custom_type": "estimate",
    "data": "{\"gs_no\": 1234}"
}
```

응답 페이로드 (HTTP 200):
```json
{
    "message_id": 9876543,
    "type": "MESG",
    "created_at": 1744704060
}
```

#### 4.1.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 프로토콜 | HTTPS (REST) |
| 인증 방식 | `Api-Token: {SENDBIRD_API_TOKEN}` 요청 헤더 |
| 공통 헤더 | `Content-Type: application/json; charset=utf8` |
| 구현 방법 | PHP cURL |
| 타임아웃 | cURL 기본값 (30초) |

#### 4.1.4 Error Handling (에러 처리)

| 조건 | 처리 방식 |
|------|---------|
| HTTP 4xx/5xx 응답 | 빈 배열 반환 + ERROR 레벨 로그 기록 |
| cURL 연결 실패/타임아웃 | 빈 배열 반환 + ERROR 레벨 로그 기록 |
| 채널 생성 실패 | 전체 채팅 연결 트랜잭션 롤백 |
| 메시지 전송 실패 | 빈 배열 반환 (견적 레코드 DB 저장은 유지) |

**재시도 정책:** 현재 재시도 없음. 클라이언트 단에서 재시도 가능.

#### 4.1.5 Data Flow (데이터 흐름)

```
SendBirdService::createGroupChannel(userIds, customType)
  └─ callApi('POST', '/v3/group_channels', payload)
        └─ cURL POST {SENDBIRD_API_URL}/v3/group_channels
              └─ [성공] { channel_url, ... }
              └─ [실패] [] + 에러 로그

SendBirdService::sendMessage(channelUrl, userId, message, customType, data)
  └─ callApi('POST', '/v3/group_channels/{url}/messages', payload)
        └─ cURL POST {SENDBIRD_API_URL}/v3/group_channels/{url}/messages
              └─ [성공] { message_id, ... }
              └─ [실패] [] + 에러 로그
```

---

### IF-EXT-002: Hermes Server (통화 기록)

#### 4.2.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-002 |
| 인터페이스명 | Hermes 통화 기록 서버 |
| 대상 시스템 | Hermes 통화/채팅 세션 관리 서버 |
| 연동 컴포넌트 | `HermesRepository` |
| 용도 | 채팅 세션을 통화 기록으로 등록 (과금 추적) |

#### 4.2.2 Data Elements (데이터 요소)

| 메서드 | 동작 | 설명 |
|-------|------|------|
| `insertCall($roomCode, $acId, $ceCode)` | 통화 기록 등록 | 채팅 연결 시 (chat-connect 이후) |
| `updateChatClose($roomCode, $duration)` | 통화 종료 업데이트 | 채팅 정상 종료 시 (chat-closed) |
| `updateChatMiss($roomCode)` | 부재 처리 업데이트 | 5분 무응답 부재 감지 시 (absence-check) |

#### 4.2.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 연동 방식 | REST (HTTP) 또는 MySQL 직접 접속 (환경 설정에 따라) |
| 인증 | 내부 네트워크 (VPC 내부 통신) |

#### 4.2.4 Error Handling (에러 처리)

Hermes 연동 실패 시 채팅 세션에 영향 없이 에러 로그 기록. 과금 추적 누락 방지를 위해 실패 건은 별도 재처리 대기열 관리 필요 (현재 미구현, 향후 개선 과제).

#### 4.2.5 Data Flow (데이터 흐름)

```
ChatController::chatConnect()
  └─ HermesRepository::insertCall(room_code, ac_id, ce_code)
        └─ [DB 직접 또는 REST] Hermes Server

ChatController::chatClosed()
  └─ HermesRepository::updateChatClose(room_code, duration)

ChatController::absenceCheck() [부재 확정 시]
  └─ HermesRepository::updateChatMiss(room_code)
```

---

### IF-EXT-003: Firebase Cloud Messaging (FCM)

#### 4.3.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-003 |
| 인터페이스명 | Firebase Cloud Messaging (FCM) |
| 대상 시스템 | FCM 푸시 알림 서비스 |
| 연동 컴포넌트 | `Fcm` 클래스 (stCode별 인스턴스) |
| 용도 | 상담사/사용자 푸시 알림 전송 |

#### 4.3.2 Data Elements (데이터 요소)

**FCM 알림 트리거 목록:**

| 트리거 EP | 알림 수신자 | 알림 내용 |
|---------|-----------|---------|
| `insert-item-qna` | Callee (상담사) | Q&A 등록 알림 |
| `chat-request-time-add` | Callee | Caller 시간 연장 요청 |
| `chat-time-add` (승인/거부) | Caller | 연장 승인/거부 결과 |
| `chat-closed` | 양측 | 채팅 종료 알림 |
| `goods-chats/chat-connect` | Callee | 상품 채팅 연결 요청 |
| `shop-chats/chat-connect` | Callee | 매장 채팅 연결 요청 |

#### 4.3.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| 인스턴스 전략 | `stCode`별 FCM 인스턴스 생성 (다중 브랜드 지원) |
| 인증 | FCM 서버 키 (환경변수, stCode별 분리) |
| 프로토콜 | FCM REST API (HTTP v1) |

#### 4.3.4 Error Handling (에러 처리)

FCM 전송 실패 시 에러 로그 기록. 알림 전송 실패는 비즈니스 로직(채팅/견적 처리)에 영향 없음.

#### 4.3.5 Data Flow (데이터 흐름)

```
ChatController::insertItemQna()
  └─ Fcm::getInstance($stCode)->send($ceToken, $title, $body, $data)
        └─ FCM REST API → 상담사 디바이스 푸시
```

---

### IF-EXT-004: AWS S3 (파일 스토리지)

#### 4.4.1 Identifier (식별자)

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-004 |
| 인터페이스명 | AWS S3 / Naver Cloud Object Storage |
| 대상 시스템 | AWS S3 (또는 Naver Cloud Object Storage) |
| 연동 컴포넌트 | `Awss3` 라이브러리 |
| 용도 | 채팅 파일 업로드 및 다운로드 |

#### 4.4.2 Data Elements (데이터 요소)

**업로드 입력:**

| 항목 | 내용 |
|------|------|
| 파일 | 멀티파트 업로드 파일 객체 |
| 파일명 | 서버 생성 UUID 기반 파일명 |
| 저장 경로 | `chat/{room_code}/{filename}` |
| 허용 MIME | 이미지(image/jpeg, image/png, image/gif, image/webp), 문서(application/pdf) 등 화이트리스트 |

**다운로드 출력:** Pre-signed URL 또는 직접 바이너리 스트림 반환.

#### 4.4.3 Communication Attributes (통신 속성)

| 항목 | 내용 |
|------|------|
| SDK | PHP AWS SDK v3 / Naver Cloud SDK |
| 인증 | IAM Role 기반 (EC2 인스턴스 프로파일) |
| 보안 | 업로드 전 MIME 타입 이중 검증 필수 (NFR-005) |

#### 4.4.4 Error Handling (에러 처리)

S3 업로드 실패 시 500 `INTERNAL` 응답. 임시 파일 정리 후 에러 로그 기록.

#### 4.4.5 Data Flow (데이터 흐름)

```
ChatController::fileUpload()
  ├─ [1] 파일 수신 (multipart/form-data)
  ├─ [2] MIME 타입 이중 검증 (확장자 + mime_content_type())
  ├─ [3] Awss3::upload($file, $path)
  │         └─ AWS S3 PutObject API
  └─ [4] 200 { "data": { "fileUrl": "https://..." } }

ChatController::chatFileDown()
  ├─ [1] room_code + 파일명 검증 (참여자 소유권 확인)
  ├─ [2] Awss3::getPresignedUrl($path)
  └─ [3] 302 Redirect 또는 바이너리 스트림
```

---

## 5. Events and Signals (이벤트 계약)

MIL-STD-498 IDD §5 — 시스템 이벤트 트리거, 대상, 처리 흐름을 명세한다.

| 이벤트 ID | 이벤트명 | 트리거 EP | 발신 컴포넌트 | 수신 시스템 | 처리 내용 |
|---------|--------|---------|------------|-----------|---------|
| EVT-001 | Q&A 등록 알림 | `POST /api/chats/insert-item-qna` | ChatController | FCM | Q&A 등록 시 해당 상담사에 푸시 알림 전송 |
| EVT-002 | 시간 연장 요청 알림 | `POST /api/chats/chat-request-time-add` | ChatController | FCM | Caller 연장 요청 시 Callee에 푸시 알림 |
| EVT-003 | 시간 연장 결과 알림 | `POST /api/chats/chat-time-add` | ChatController | FCM | Callee 승인/거부 결과 Caller에 푸시 알림 |
| EVT-004 | 채팅 종료 알림 | `POST /api/chats/chat-closed` | ChatController | FCM | 채팅 종료 시 양측에 푸시 알림 + Hermes 종료 처리 |
| EVT-005 | 견적 메시지 전송 | `POST /api/goods-chats/send-estimate` | GoodsChatController | SendBird | 견적 레코드 생성 후 SendBird 채널에 견적 메시지 전송 |
| EVT-006 | 상품채팅 연결 알림 | `POST /api/goods-chats/chat-connect` | GoodsChatController | FCM | 상품 채팅 연결 요청 시 Callee 알림 |
| EVT-007 | 매장채팅 연결 알림 | `POST /api/shop-chats/chat-connect` | ShopChatController | FCM | 매장 채팅 연결 요청 시 Callee 알림 |
| EVT-008 | 부재 처리 이벤트 | `POST /api/chats/absence-check` (5분 초과 시) | ChatController | Hermes | 부재 확정 → Hermes `updateChatMiss()` 호출 |

---

## 6. Data Formats and Encoding (데이터 포맷 및 인코딩)

MIL-STD-498 IDD §6 — 인터페이스 데이터 포맷, DTO 정의, 인코딩 규칙을 명세한다.

### 6.1 공통 인코딩 규칙

| 항목 | 규칙 |
|------|------|
| 문자 인코딩 | UTF-8 (utf8mb4) 전 레벨 통일 |
| 날짜/시각 | ISO 8601 형식 (`YYYY-MM-DD HH:MM:SS`). UTC 기준 |
| API 응답 키 | DB `snake_case` → API `camelCase` 변환 필수 (`created_at` → `createdAt`) |
| 성공 응답 | `{ "data": {...} }` (HTTP 200/201) |
| 에러 응답 | `{ "error": { "code": "...", "message": "..." } }` (HTTP 4xx/5xx) |

### 6.2 채팅방 DTO (ChatRoom)

| 필드명 (API) | 필드명 (DB) | 타입 | 설명 |
|-------------|-----------|------|------|
| `roomCode` | `room_code` | string | `CHAT-YYYYMMDDHHmmss-XXX` |
| `crType` | `cr_type` | string | `chat` / `goods` / `shop` |
| `crStatus` | `cr_status` | string | `standby` / `on` / `closed` / `absent` |
| `channelUrl` | `channel_url` | string | SendBird 그룹 채널 URL |
| `crLastMessage` | `cr_last_message` | string | 마지막 메시지 내용 |
| `crUnreadCaller` | `cr_unread_caller` | int | Caller 미읽음 메시지 수 |
| `crLastDate` | `cr_last_date` | datetime | 마지막 메시지 시각 (UTC) |
| `crStartTime` | `cr_start_time` | datetime | 채팅 시작 시각 (UTC) |
| `crEndTime` | `cr_end_time` | datetime | 채팅 종료 시각 (UTC) |
| `crAddTime` | `cr_add_time` | int | 연장 시간 합계 (초) |

### 6.3 견적 DTO (GoodsSell)

| 필드명 (API) | 필드명 (DB) | 타입 | 설명 |
|-------------|-----------|------|------|
| `gsNo` | `gs_no` | int | 견적 번호 (PK) |
| `gsPrice` | `gs_price` | int | 견적 금액 |
| `gsStatus` | `gs_status` | int | FSM 상태 (0~4) |
| `messageId` | `messageId` | string | SendBird 메시지 ID |
| `cancelDate` | `cancel_date` | datetime\|null | 취소 일시 (UTC, nullable) |

### 6.4 ChatConnectionService 반환 DTO

```json
// status: created (신규 채팅방 생성)
{
    "status": "created",
    "room_code": "CHAT-20260415143022-A7B",
    "channel_url": "sendbird_group_channel_12345_abcdef"
}

// status: existing (기존 채팅방 재연결)
{
    "status": "existing",
    "room_code": "CHAT-20260414110000-XYZ",
    "channel_url": "sendbird_group_channel_99999_xyz123"
}

// status: rejected (차단)
{
    "status": "rejected"
}

// status: error (에러)
{
    "status": "error",
    "code": "CALLEE_OFFLINE"
}
```

### 6.5 견적 전송 API 요청/응답 예시

```json
// 요청: POST /api/goods-chats/send-estimate
// Header: X-CSRF-TOKEN: {csrf_token}
// Cookie: hc_access={jwt_token}
{
    "room_code": "CHAT-20260415143022-A7B",
    "gs_no": 1234,
    "gs_price": 50000,
    "message": "견적을 보내드립니다. 작업 기간 3일 예상입니다."
}

// 응답: HTTP 200
{
    "data": {
        "gsNo": 1234,
        "messageId": "9876543"
    }
}
```

### 6.6 페이지네이션 응답 포맷

```json
// POST /api/chats/get-posting-list
{
    "data": [
        { "postingNo": 1, "title": "...", "createdAt": "2026-04-15 14:30:00" }
    ],
    "meta": {
        "currentPage": 1,
        "perPage": 20,
        "total": 150,
        "lastPage": 8
    }
}
```

---

## 7. Feasibility Review (타당성 검토)

> 근거: OWASP API Security Top 10 2023, SendBird Platform API 공식 문서 v3, RFC 7231, MIL-STD-498

| 검토 ID | 검토 항목 | 결론 | 근거 | 대안 | 트레이드오프 |
|--------|----------|------|------|------|------------|
| FEA-001 | **SendBird Api-Token 헤더 인증** | 환경변수 관리 적절 | `SENDBIRD_API_TOKEN` 환경변수 분리로 코드베이스 노출 방지. OWASP API8:2023(Security Misconfiguration) 준수. TLS(HTTPS) 구간으로 헤더 암호화 보장 | `Authorization: Bearer {token}` 헤더 방식 | Api-Token: SendBird 표준 방식. 변경 시 SendBird 정책 위반 가능성 — 현행 유지 |
| FEA-002 | **Graceful Degradation (빈 배열 반환)** | SendBird 장애 격리 적절 | SendBird API 오류 시 예외 전파 없이 빈 배열 반환 + 로깅. 비필수 기능(목록 조회) 장애가 전체 서비스를 중단시키지 않음. NFR-004 준수 | 예외 전파 (500 응답) | Graceful Degradation: UX 연속성↑, 오류 무시 위험. 예외 전파: 오류 명확, 사용자 혼란 |
| FEA-003 | **FCM stCode별 인스턴스 생성** | 다중 브랜드 지원 설계 타당 | 브랜드(st_code)별 FCM 서버 키 분리 가능. 브랜드 간 교차 알림 방지 (OWASP API5:2023 BFLA 대응). 신규 브랜드 추가 시 인스턴스만 확장 | 단일 FCM 인스턴스 | 다중 인스턴스: 브랜드 격리↑, 인스턴스 관리 복잡. 단일: 구현 단순, 브랜드 격리 불가 |
| FEA-004 | **견적 messageId 저장 (tb_goods_sell.messageId)** | SendBird 메시지 추적 필수 설계 | `messageId`로 견적 DB 레코드와 SendBird 메시지를 연결. 견적 취소 시 SendBird 메시지 업데이트 가능. `update-estimate-message-id` EP 별도 분리로 멱등성 보장 | 메시지 ID 미저장 (단방향 전송) | 저장: 양방향 추적↑, 취소/갱신 가능. 미저장: 구현 단순, 메시지 동기화 불가 |
| FEA-005 | **ChatConnectionService::connect 반환 타입 array** | 레거시 호환 유지, 단계적 개선 필요 | PHP array 반환으로 현재 타입 안전성 부재. ChatRoom Entity 전환 이전까지 array 유지가 리스크 최소화. 전환 후 `ChatConnectionResult` VO 도입 예정 | `ChatConnectionResult` VO 즉시 도입 | array: 레거시 호환, 타입 불안전. VO: 타입 안전, Entity 전환 완료 후 적용 |

---

## 8. Change Impact Log (변경 영향 기록)

| 변경 항목 | 영향 범위 | 개선점 | 수행 이유 |
|----------|----------|--------|----------|
| MIL-STD-498 IDD 표준 전면 전환 | 전체 문서 구조 재편 | Scope(§1), References(§2), 인터페이스별 5-subsection(식별자/데이터/통신/에러/흐름), Events(§5), DataFormats(§6), Requirements Traceability(§9) 신설 | 3-Round Review PASS 요건 충족. MIL-STD-498 기준 인터페이스 문서로 완전성 확보 |
| 버전 v1.2 → v2.0 | 문서 헤더, 변경 로그 | MIL-STD-498 전환 반영하는 메이저 버전 갱신 | 문서 이력 명확화 |
| 인터페이스별 5-subsection 구조화 | IF-INT-001~006, IF-EXT-001~004 전체 | 식별자/데이터/통신속성/에러처리/데이터흐름 5항목 완전 기술. 구현자 단독 참조 가능한 완결성 확보 | MIL-STD-498 DI-IPSC-81436 IDD 요건 준수 |
| Events and Signals 신설 (§5) | 신규 섹션 | 이벤트 8건 전체 트리거-발신-수신-처리 명세. 이벤트 누락 방지 | MIL-STD-498 IDD 이벤트 계약 요건 준수 |
| Data Formats 확장 (§6) | 기존 §5 데이터 포맷 확장 | 공통 인코딩 규칙, camelCase 변환 규칙, 페이지네이션 포맷, 견적 요청/응답 JSON 예시, ChatConnectionService 4개 status 반환 예시 추가 | 구현자 코딩 표준 단일 참조 가능. API 응답 표준 준수 확인 |
| Requirements Traceability Matrix 신설 (§9) | 신규 섹션 | SRS FR/NFR → IDD 인터페이스 매핑 16건. 인터페이스 누락 방지 | MIL-STD-498 DI-IPSC-81436 추적성 요건 준수 |

---

## 9. Requirements Traceability Matrix (요구사항 추적성 매트릭스)

MIL-STD-498 DI-IPSC-81436 §9 — SRS FR/NFR과 IDD 인터페이스 간 추적성.

| SRS 요구사항 ID | 요구사항명 | 연관 인터페이스 | 인터페이스 타입 |
|---------------|---------|-------------|-------------|
| FR-001 | 아이템 목록/검색 | IF-INT-002 (`ChatListService`), IF-INT-004 (`ChatRepository`) | 내부 |
| FR-002 | 채팅 연결/생성 | IF-INT-001 (`ChatConnectionService`), IF-INT-004, IF-EXT-001 (SendBird), IF-EXT-002 (Hermes) | 내부+외부 |
| FR-003 | 타이밍/시간 관리 | IF-INT-004 (타이밍 메서드) | 내부 |
| FR-004 | 상태 관리 | IF-INT-004 (상태 메서드), IF-EXT-002 (Hermes Miss 처리) | 내부+외부 |
| FR-005 | 메시지/파일 관리 | IF-INT-004 (메시지 메서드), IF-EXT-004 (S3) | 내부+외부 |
| FR-006 | 즐겨찾기/Q&A/가격 | IF-INT-004 (즐겨찾기/QnA), IF-EXT-003 (FCM Q&A 알림) | 내부+외부 |
| FR-007 | 포스팅 조회 | IF-INT-004 (포스팅 메서드) | 내부 |
| FR-008 | 상품채팅/견적 | IF-INT-001, IF-INT-003 (SendBird), IF-INT-005 (`GoodsChatRepository`) | 내부 |
| FR-009 | 매장채팅 | IF-INT-001, IF-INT-003, IF-INT-006 (`ShopChatRepository`) | 내부 |
| FR-010 | 상담사 채팅 관리 | IF-INT-004 (인사말/상태 메서드) | 내부 |
| NFR-001 | SendBird API 성능 | IF-EXT-001 (cURL 타임아웃 30초) | 외부 |
| NFR-003 | 채팅방 접근 보안 | IF-INT-004 (소유권 조건 쿼리) | 내부 |
| NFR-004 | Graceful Degradation | IF-EXT-001 (빈 배열 반환 정책) | 외부 |
| NFR-005 | 파일 업로드 보안 | IF-EXT-004 (MIME 이중 검증 후 업로드) | 외부 |
| NFR-006 | 부재 감지 임계값 | IF-INT-004 (`getLastResponseTime`), IF-EXT-002 (`updateChatMiss`) | 내부+외부 |
| CON-001 | SendBird Token 환경변수 관리 | IF-EXT-001 (`SENDBIRD_API_TOKEN` 환경변수) | 외부 |

---

## 10. Document History (변경 로그)

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-04-15 | 1.0.0 | 초기 작성 | jypark |
| 2026-04-15 | 1.1.0 | PHP 시그니처 추가, SendBird EP 상세화, 이벤트 계약 4건, 에러 7건, DTO 3종 추가 | jypark |
| 2026-04-15 | 1.2.0 | 타당성 검토 5건, 변경 영향 기록 5건, SendBird/견적 API JSON 예시 추가 | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 IDD 표준 전면 전환. 3-Round Review PASS. Scope, References, 인터페이스별 5-subsection 구조화(IF-INT 6개/IF-EXT 4개), Events(8건), DataFormats(인코딩 규칙+DTO+JSON 예시), Requirements Traceability Matrix(16건) 신설 | jypark |
