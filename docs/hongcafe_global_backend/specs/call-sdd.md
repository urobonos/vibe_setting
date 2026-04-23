---
문서명: Call 모듈 소프트웨어 설계 문서 (SDD)
문서ID: SDD-CALL-001
버전: v2.0
상태: 승인됨
적용 표준: IEEE 1016-2009 (IEEE Standard for Information Technology — Systems Design — Software Design Descriptions)
생성일: 2026-04-15
최종수정일: 2026-04-15
작성자: jypark
대상 시스템: Call 모듈 (통화 연결·종료·정산·대시보드)
관련 문서:
  - call-srs.md (SRS-CALL-001, IEEE 29148:2018)
  - call-idd.md (IDD-CALL-001, MIL-STD-498)
  - api-docs/call/call-api.md
  - api-docs/call/callee-api.md
  - api-docs/call/pbx-api.md
변경 로그: "IEEE 표준 전면 전환. 3-Round Review PASS"
---

# Call 모듈 소프트웨어 설계 문서 (SDD)

> **문서 ID**: SDD-CALL-001 | **버전**: v2.0 | **상태**: 승인됨
> **적용 표준**: IEEE 1016-2009 | **작성자**: jypark | **작성일**: 2026-04-15

---

## 목차

1. [소개 (Introduction)](#1-소개)
2. [설계 관점 1: 맥락 관점 (Context Viewpoint)](#2-설계-관점-1-맥락-관점)
3. [설계 관점 2: 구성 관점 (Composition Viewpoint)](#3-설계-관점-2-구성-관점)
4. [설계 관점 3: 논리 관점 (Logical Viewpoint)](#4-설계-관점-3-논리-관점)
5. [설계 관점 4: 의존성 관점 (Dependency Viewpoint)](#5-설계-관점-4-의존성-관점)
6. [설계 관점 5: 정보 관점 (Information Viewpoint)](#6-설계-관점-5-정보-관점)
7. [설계 관점 6: 패턴 관점 (Patterns Use Viewpoint)](#7-설계-관점-6-패턴-관점)
8. [설계 관점 7: 인터페이스 관점 (Interface Viewpoint)](#8-설계-관점-7-인터페이스-관점)
9. [설계 관점 8: 상호작용 관점 (Interaction Viewpoint)](#9-설계-관점-8-상호작용-관점)
10. [설계 오버레이 (Design Overlay)](#10-설계-오버레이)
11. [요구사항-설계 추적성 매트릭스 (Traceability Matrix)](#11-요구사항-설계-추적성-매트릭스)
12. [아키텍처 결정 기록 (ADR)](#12-아키텍처-결정-기록)
13. [타당성 검토 (Feasibility Review)](#13-타당성-검토)
14. [변경 이력 (Change History)](#14-변경-이력)

---

## 1. 소개 (Introduction)

### 1.1 목적 (Purpose)

본 문서는 Call 모듈의 소프트웨어 설계를 IEEE 1016-2009 표준에 따라 8개 설계 관점(Viewpoint)으로 기술한다. Controller, Service, Repository 계층의 책임과 메서드 목록, DB 스키마 설계, 통화 생명주기(Call Lifecycle) 상태 기계, 코인 계산 공식, 시퀀스 다이어그램, 아키텍처 결정(ADR)을 포함하며, 상위 문서 SRS-CALL-001의 요구사항과 하위 문서 IDD-CALL-001의 인터페이스 명세 사이의 설계 가교 역할을 한다.

### 1.2 범위 (Scope)

본 문서는 `app/Modules/Call/` 디렉토리 내 모든 PHP 클래스의 설계를 다룬다.

- **Controller**: `CallController`(14 EP), `CalleeController`(39 EP), `PbxController`(13 EP)
- **Service**: 5개 — `CallCloseService`, `CallConnectionService`, `CalleeActivityService`, `CalleeManageService`, `PbxService`
- **Repository**: 5개 — `CallCloseRepository`, `CallRepository`, `CalleeRepository`(40+ 메서드), `CalleeManageRepository`, `PbxRepository`(22 메서드)
- **DB 테이블**: `tb_call_result`, `tb_coin`, `tb_alarm`, `tb_callee`, `tb_items`
- **외부 연동**: Hermes PBX (`http://hermes.peoplev.co.kr`), FCM

### 1.3 용어 정의 (Definitions)

| 용어 | 정의 |
|------|------|
| Viewpoint | IEEE 1016-2009 설계 관점 — 특정 관심사(concern)에 집중하는 설계 기술 방식 |
| Controller | HTTP 요청 수신, 유효성 검증, Service 호출, HTTP 응답 반환 담당 계층 |
| Service | 비즈니스 로직 및 트랜잭션 경계 담당 계층 |
| Repository | DB 접근 추상화 계층. CI4 Query Builder + `$db->query()` 사용 |
| DI | Dependency Injection — `service()` 함수로 주입 |
| ADR | Architecture Decision Record — 아키텍처 결정 이유와 결과 기록 |

### 1.4 참조 (References)

| 문서 | 설명 |
|------|------|
| IEEE 1016-2009 | IEEE Standard for Information Technology — Systems Design — Software Design Descriptions |
| SRS-CALL-001 v2.0 | Call 모듈 소프트웨어 요구사항 명세서 |
| IDD-CALL-001 v2.0 | Call 모듈 인터페이스 설계 문서 |
| CLAUDE.md | HongCafe Global Backend 프로젝트 지침 |

---

## 2. 설계 관점 1: 맥락 관점 (Context Viewpoint)

IEEE 1016-2009 §5.1 — 시스템 경계 및 외부 환경과의 상호작용

### 2.1 시스템 경계

Call 모듈은 HongCafe Global Backend Modular Monolith의 바운디드 컨텍스트(BC)이다. 외부 시스템, 내부 BC 및 인프라와 다음 경계를 형성한다.

```
╔══════════════════════════════════════════════════════════════╗
║                     Call Module BC                           ║
║  ┌─────────────┐  ┌─────────────────┐  ┌────────────────┐  ║
║  │ Call API    │  │  Callee API     │  │   PBX API      │  ║
║  │ (14 EP)     │  │  (39 EP)        │  │   (13 EP)      │  ║
║  │ JWT auth    │  │  JWT+role:callee │  │  API Key auth  │  ║
║  └──────┬──────┘  └────────┬────────┘  └────────┬───────┘  ║
║         └─────────────────┬┘                    │           ║
║              ┌────────────▼────────────────────┐│           ║
║              │         Service Layer (5)         ││          ║
║              │  CallCloseService                 ││          ║
║              │  CallConnectionService            ││          ║
║              │  CalleeActivityService            ││          ║
║              │  CalleeManageService             ◄┘│          ║
║              │  PbxService ─────────────────────┐ │          ║
║              └────────────┬──────────────────── │─┘          ║
║              ┌────────────▼────────────────────┐│           ║
║              │       Repository Layer (5)        ││           ║
║              └────────────┬──────────────────── ┘│           ║
╚══════════════════════════ │ ════════════════════ ▼══════════╝
                            │                   Hermes PBX
                    Aurora MySQL             (HTTP REST API)
                 (RDS Proxy IAM Auth)
                            │
                     ┌──────▼──────┐
                     │  Outbox     │   FCM
                     │  (Lambda/   │←─────────────
                     │   Cron)     │  Push Notify
                     └─────────────┘
```

### 2.2 외부 인터페이스 요약

| 외부 시스템 | 방향 | 프로토콜 | 인증 | 타임아웃 |
|----------|:---:|---------|------|---------|
| Next.js 프론트엔드 | 수신 | HTTPS REST | JWT (hc_access 쿠키) | N/A |
| Hermes PBX | 양방향 | HTTP REST | X-Hermes-Api-Key / X-Api-Key | 연결 3s, 응답 10s |
| FCM | 발신 | HTTPS | Service Account JSON | N/A (비동기) |
| Aurora MySQL | 발신 | MySQL Protocol | RDS Proxy IAM | N/A |
| Lambda/Cron | 발신 (Outbox) | DB Polling | IAM Role | N/A |

### 2.3 내부 BC 인터페이스

| 내부 BC | 연동 방식 | 공유 자원 |
|---------|---------|---------|
| Member BC | Interface Only (`service()` DI) | tb_account (읽기 전용) |
| Coin BC | Outbox 패턴 (global_sync_pub_log) | 코인 지급 이벤트 |
| Shared BC | 직접 참조 | Models, Entities, ValueObjects |

---

## 3. 설계 관점 2: 구성 관점 (Composition Viewpoint)

IEEE 1016-2009 §5.2 — 모듈 구조 및 컴포넌트 분해

### 3.1 모듈 디렉토리 구조

```
app/Modules/Call/
├── Config/
│   ├── Routes.php              — 66개 EP 명시적 등록 (setAutoRoute=false)
│   └── Services.php            — DI 바인딩 (중앙 Services.php 수정 금지)
├── Controllers/
│   ├── CallController.php      — 672 lines, 14 Endpoints (JWT auth)
│   ├── CalleeController.php    — 1652 lines, 39 Endpoints (JWT+role:callee)
│   └── PbxController.php       — 274 lines, 13 Endpoints (API Key auth)
├── Services/
│   ├── CallCloseService.php    — 통화 종료·정산·이벤트 (closeCall, closeAlert, getDurationToCoin)
│   ├── CallConnectionService.php — 통화 연결·검증 (validateCallEligibility, initiateCall, checkEventMarks)
│   ├── CalleeActivityService.php — 대시보드·통계 (getActivityData)
│   ├── CalleeManageService.php   — 비밀번호·상태·알람 (calleeCallDuration, calleePasswdChange, callCloseAlarm)
│   └── PbxService.php            — Hermes API 연동 (initConnect, callConnect, checkLive, coinInfo)
├── Repositories/
│   ├── CallCloseRepository.php   — 종료 정산 DB 연산
│   ├── CallRepository.php        — 통화 기록 조회·갱신
│   ├── CalleeRepository.php      — 상담사 데이터 (40+ 메서드)
│   ├── CalleeManageRepository.php — 상담사 설정 관리
│   └── PbxRepository.php         — PBX 기록 저장 (22 메서드)
├── Models/                       — CI4 Model (기본 CRUD)
└── Entities/                     — 도메인 Entity / Value Object
```

### 3.2 Controller 설계

#### 3.2.1 CallController (14 Endpoints, JWT auth)

**책임**: Caller(고객)의 통화 요청·연결·종료·내역 조회 처리.
**인증**: JWT (`hc_access` 쿠키). CSRF 적용 (POST/PUT/DELETE).
**필터 체인**: `ratelimit` → `csrftoken` → `auth`

| # | HTTP | Path | Controller 메서드 | 설명 |
|:-:|------|------|----------------|------|
| 1 | GET | `api/calls` | `index()` | 통화 내역 목록 조회 (paginate) |
| 2 | GET | `api/calls/{id}` | `show()` | 통화 상세 조회 |
| 3 | POST | `api/calls/request` | `requestCall()` | 통화 요청 (연결 시작) |
| 4 | POST | `api/calls/connect` | `connectCall()` | 통화 연결 확정 |
| 5 | POST | `api/calls/close` | `closeCall()` | 통화 종료 (정산 트리거) |
| 6 | GET | `api/calls/status/{id}` | `getStatus()` | 통화 상태 조회 |
| 7 | GET | `api/calls/history` | `getHistory()` | 통화 이력 조회 |
| 8 | GET | `api/calls/coin-preview` | `getCoinPreview()` | 예상 코인 차감량 조회 |
| 9 | POST | `api/calls/favorites` | `addFavorite()` | 즐겨찾기 추가 |
| 10 | DELETE | `api/calls/favorites/{id}` | `removeFavorite()` | 즐겨찾기 삭제 |
| 11 | GET | `api/calls/favorites` | `getFavorites()` | 즐겨찾기 목록 조회 |
| 12 | GET | `api/calls/callee-list` | `getCalleeList()` | 상담사 목록 조회 |
| 13 | GET | `api/calls/callee-detail/{id}` | `getCalleeDetail()` | 상담사 상세 조회 |
| 14 | POST | `api/calls/estimate-request` | `requestEstimate()` | 견적 요청 |

**주요 설계 사항**:
- `requestCall()`: `CallConnectionService::validateCallEligibility()` → `CallConnectionService::initiateCall()` 순서 호출. `X-Idempotency-Key` 헤더 검증 필수.
- `closeCall()`: `CallCloseService::closeCall()` 호출. 트랜잭션 결과 HTTP 200 반환. 정산 오류 시 HTTP 500 반환 및 로깅.
- `getCoinPreview()`: `CallCloseService::getDurationToCoin()` 직접 호출 (부수 효과 없는 순수 계산).

#### 3.2.2 CalleeController (39 Endpoints, JWT + role:callee)

**책임**: 상담사(Callee) 전용 기능. 대시보드, 프로필, 컨텐츠, 채팅, 견적, 알람 관리.
**인증**: JWT + `role:callee` 필터. 모든 EP에 `['filter' => 'role:callee']` 적용 필수.
**필터 체인**: `ratelimit` → `csrftoken` → `auth` → `role:callee`

| # | HTTP | Path | Controller 메서드 | 설명 |
|:-:|------|------|----------------|------|
| 1 | GET | `api/callees/dashboard` | `getDashboard()` | 대시보드 통계 조회 |
| 2 | GET | `api/callees/activity` | `getActivity()` | 활동 현황 (오늘/주/월) |
| 3 | GET | `api/callees/revenue` | `getRevenue()` | 수익 현황 조회 |
| 4 | GET | `api/callees/call-history` | `getCallHistory()` | 통화 이력 조회 |
| 5 | GET | `api/callees/profile` | `getProfile()` | 내 프로필 조회 |
| 6 | PUT | `api/callees/profile` | `updateProfile()` | 프로필 수정 |
| 7 | PUT | `api/callees/status` | `updateStatus()` | 상태 변경 (온라인/오프라인) |
| 8 | PUT | `api/callees/password` | `updatePassword()` | 비밀번호 변경 |
| 9 | GET | `api/callees/alarms` | `getAlarms()` | 알람 목록 조회 |
| 10 | PUT | `api/callees/alarms/{id}/read` | `markAlarmRead()` | 알람 읽음 처리 |
| 11 | PUT | `api/callees/alarm-settings` | `updateAlarmSettings()` | 알람 수신 설정 |
| 12 | GET | `api/callees/postings` | `getPostings()` | 내 게시물 목록 |
| 13 | POST | `api/callees/postings` | `createPosting()` | 게시물 작성 |
| 14 | PUT | `api/callees/postings/{id}` | `updatePosting()` | 게시물 수정 |
| 15 | DELETE | `api/callees/postings/{id}` | `deletePosting()` | 게시물 삭제 |
| 16 | GET | `api/callees/comments` | `getComments()` | 댓글 목록 조회 |
| 17 | DELETE | `api/callees/comments/{id}` | `deleteComment()` | 댓글 삭제 |
| 18 | GET | `api/callees/chats` | `getChatList()` | 채팅 목록 조회 |
| 19 | GET | `api/callees/chats/{id}` | `getChatDetail()` | 채팅 상세 조회 |
| 20 | POST | `api/callees/chats/{id}/reply` | `replyChat()` | 채팅 답장 |
| 21 | GET | `api/callees/estimates` | `getEstimates()` | 견적 요청 목록 |
| 22 | POST | `api/callees/estimates/{id}/accept` | `acceptEstimate()` | 견적 승인 |
| 23 | POST | `api/callees/estimates/{id}/reject` | `rejectEstimate()` | 견적 거절 |
| 24 | GET | `api/callees/goods/callee-list` | `getGoodsList()` | 상품 목록 |
| 25 | POST | `api/callees/goods/callee-create` | `createGoods()` | 상품 등록 |
| 26 | PUT | `api/callees/goods/callee-update/{id}` | `updateGoods()` | 상품 수정 |
| 27 | DELETE | `api/callees/goods/callee-delete/{id}` | `deleteGoods()` | 상품 삭제 |
| 28 | GET | `api/callees/shop/callee-items` | `getShopItems()` | 샵 아이템 목록 |
| 29 | POST | `api/callees/shop/callee-purchase` | `purchaseItem()` | 아이템 구매 |
| 30 | GET | `api/callees/callee-stats` | `getStats()` | 상세 통계 |
| 31 | GET | `api/callees/callee-reviews` | `getReviews()` | 리뷰 조회 |
| 32 | POST | `api/callees/callee-review-reply/{id}` | `replyReview()` | 리뷰 답변 |
| 33 | GET | `api/callees/callee-schedule` | `getSchedule()` | 상담 일정 조회 |
| 34 | POST | `api/callees/callee-schedule` | `createSchedule()` | 일정 등록 |
| 35 | PUT | `api/callees/callee-schedule/{id}` | `updateSchedule()` | 일정 수정 |
| 36 | DELETE | `api/callees/callee-schedule/{id}` | `deleteSchedule()` | 일정 삭제 |
| 37 | GET | `api/callees/callee-notices` | `getNotices()` | 공지사항 조회 |
| 38 | GET | `api/callees/callee-coin-history` | `getCoinHistory()` | 코인 내역 조회 |
| 39 | POST | `api/callees/callee-fcm-token` | `updateFcmToken()` | FCM 토큰 갱신 |

#### 3.2.3 PbxController (13 Endpoints, API Key auth)

**책임**: Hermes PBX 시스템 연동. 통화 이벤트 Callback 수신, 060 전화 처리.
**인증**: `X-Api-Key` 헤더 전용. JWT/세션 폴백 없음.
**CSRF**: 면제 (서버-서버 통신). EXCLUDED_PATHS 등록 필수.
**필터 체인**: `apikey`

| # | HTTP | Path | Controller 메서드 | 설명 |
|:-:|------|------|----------------|------|
| 1 | POST | `api/pbx/call-start` | `callStart()` | 통화 시작 Callback |
| 2 | POST | `api/pbx/call-end` | `callEnd()` | 통화 종료 Callback (정산 트리거) |
| 3 | POST | `api/pbx/call-miss` | `callMiss()` | 통화 부재 Callback |
| 4 | GET | `api/pbx/callee-status/{id}` | `getCalleeStatus()` | 상담사 상태 조회 |
| 5 | POST | `api/pbx/callee-connect` | `connectCallee()` | 상담사 연결 요청 |
| 6 | GET | `api/pbx/call-record/{id}` | `getCallRecord()` | 통화 기록 조회 |
| 7 | POST | `api/pbx/060-inbound` | `handleInbound()` | 060 인바운드 처리 |
| 8 | POST | `api/pbx/060-outbound` | `handleOutbound()` | 060 아웃바운드 처리 |
| 9 | GET | `api/pbx/available-callees` | `getAvailableCallees()` | 연결 가능 상담사 목록 |
| 10 | POST | `api/pbx/webhook/event` | `handleWebhookEvent()` | 일반 Webhook 이벤트 |
| 11 | GET | `api/pbx/status` | `getSystemStatus()` | PBX 시스템 상태 확인 |
| 12 | POST | `api/pbx/test-call` | `testCall()` | 테스트 통화 (개발 환경) |
| 13 | POST | `api/pbx/sync-records` | `syncRecords()` | 통화 기록 동기화 |

---

## 4. 설계 관점 3: 논리 관점 (Logical Viewpoint)

IEEE 1016-2009 §5.3 — 클래스·메서드·책임 설계

### 4.1 Service 계층 설계

#### 4.1.1 CallConnectionService

**책임**: 통화 연결 전 적격성 검증, 통화 시작 처리.
**관련 FR**: FR-001

```php
namespace App\Modules\Call\Services;

class CallConnectionService
{
    public const CALL_MIN_COIN = 5000;

    /**
     * 통화 연결 전 Caller/Callee 적격성 검증
     * 검증 항목: 코인 잔액 ≥ CALL_MIN_COIN, Callee 온라인, 중복 통화 없음
     */
    public function validateCallEligibility(int $callerId, int $calleeId): EligibilityResult;

    /**
     * 통화 시작 처리
     * 1. tb_call_result INSERT (status='insert')
     * 2. PbxService::initConnect() 호출 (Hermes API)
     * 3. CallInitResult { callId, pbxCallId } 반환
     */
    public function initiateCall(int $callerId, int $calleeId, string $idempotencyKey): CallInitResult;

    /**
     * Hermes Callback 수신 후 상태 On으로 갱신
     */
    public function confirmConnection(int $callId, string $pbxCallId): void;

    /**
     * 연결 실패 시 Miss 처리
     */
    public function markMissed(int $callId, string $reason): void;

    /**
     * 이벤트 마크 확인 (특별 이벤트 통화 여부)
     */
    public function checkEventMarks(int $callerId, int $calleeId): array;
}
```

#### 4.1.2 CallCloseService

**책임**: 통화 종료, 코인 정산, Outbox 이벤트 발행, 이벤트 처리.
**관련 FR**: FR-002, FR-009

```php
namespace App\Modules\Call\Services;

class CallCloseService
{
    public const COIN_TERM = 30;      // 초 — 코인 차감 주기
    public const FREE_DURATION = 30;  // 초 — 무료 통화 구간

    /**
     * 통화 종료 처리 — 정산, Outbox 발행, 이벤트 처리
     * 1. 통화 시간(초) 계산
     * 2. getDurationToCoin() 호출
     * 3. 트랜잭션: tb_coin 차감 + Outbox INSERT + tb_call_result 갱신
     * 4. 이벤트 처리 (Payback, Special Price, Roulette, First-call Coupon)
     * 5. FCM 알림 발송 (closeAlert)
     */
    public function closeCall(int $callId, DateTimeImmutable $endTime): CloseResult;

    /**
     * 코인 차감량 계산 (순수 함수, 부수 효과 없음)
     * 공식: ceil((durationSeconds - FREE_DURATION) / COIN_TERM) × ratePerTerm
     * FREE_DURATION 이하이면 0 반환
     */
    public function getDurationToCoin(int $durationSeconds, int $ratePerTerm): int;

    /**
     * 통화 종료 FCM 알림 발송 (Caller + Callee 양방향)
     */
    public function closeAlert(int $callId, int $callerId, int $calleeId): void;

    /**
     * 30초 미만 종료 처리 — Under30 상태 전환
     */
    public function markUnder30(int $callId): void;

    /**
     * 이벤트 처리 — Payback, Special Price, Roulette, First-call Coupon Outbox 발행
     */
    public function processEvents(int $callId, int $callerId, int $calleeId): void;
}
```

**코인 계산 구현**:
```php
public function getDurationToCoin(int $durationSeconds, int $ratePerTerm): int
{
    if ($durationSeconds <= self::FREE_DURATION) {
        return 0;
    }
    $billableSeconds = $durationSeconds - self::FREE_DURATION;
    $terms = (int) ceil($billableSeconds / self::COIN_TERM);
    return $terms * $ratePerTerm;
}
```

#### 4.1.3 CalleeActivityService

**책임**: 상담사 대시보드 데이터 집계, 통화 통계, 수익 현황 제공.
**관련 FR**: FR-004

```php
namespace App\Modules\Call\Services;

class CalleeActivityService
{
    /**
     * 상담사 대시보드 종합 데이터 — 오늘/주/월 통계 집계
     * 반환: DashboardData { todayStats, weekStats, monthStats, revenueStats }
     */
    public function getActivityData(int $calleeId): DashboardData;

    /**
     * 기간별 활동 통계
     * period: 'today' | 'week' | 'month'
     * 반환: ActivityStats { callCount, totalDuration, averageDuration }
     */
    public function getActivityStats(int $calleeId, string $period): ActivityStats;

    /**
     * 기간별 수익 통계
     * 반환: RevenueStats { totalCoins, paidCallCount, averageCoinPerCall }
     */
    public function getRevenueStats(int $calleeId, string $period): RevenueStats;

    /**
     * 통화 이력 페이지네이션 (CI4 paginate() 사용)
     * 반환: { data: array, meta: { currentPage, perPage, total, lastPage } }
     */
    public function getCallHistory(int $calleeId, int $page, int $perPage): PaginatedResult;
}
```

#### 4.1.4 CalleeManageService

**책임**: 상담사 비밀번호 변경, 온라인 상태 관리, 알람 설정.
**관련 FR**: FR-005

```php
namespace App\Modules\Call\Services;

class CalleeManageService
{
    /**
     * 상담사 통화 시간 관리 (calleeCallDuration)
     */
    public function calleeCallDuration(int $calleeId, int $durationSeconds): void;

    /**
     * 비밀번호 변경 (calleePasswdChange)
     * 현재 비밀번호 검증 → 신규 비밀번호 해싱 → DB 갱신
     */
    public function calleePasswdChange(int $calleeId, string $currentPassword, string $newPassword): void;

    /**
     * 통화 종료 알람 발송 (callCloseAlarm)
     * FCM을 통해 상담사에게 통화 종료 알림 발송
     */
    public function callCloseAlarm(int $calleeId, array $callData): void;

    /**
     * 온라인 상태 변경
     */
    public function updateOnlineStatus(int $calleeId, bool $isOnline): void;

    /**
     * FCM 토큰 갱신
     */
    public function updateFcmToken(int $calleeId, string $fcmToken): void;

    /**
     * 알람 수신 설정 변경
     */
    public function updateAlarmSettings(int $calleeId, AlarmSettings $settings): void;
}
```

#### 4.1.5 PbxService

**책임**: Hermes API HTTP 통신, PBX 연동 추상화.
**관련 FR**: FR-003, FR-010

```php
namespace App\Modules\Call\Services;

class PbxService
{
    // Hermes 기본 URL: http://hermes.peoplev.co.kr
    // 타임아웃: 연결 3초, 응답 10초

    /**
     * Hermes PBX에 060 연결 요청 (initConnect)
     * 반환: PbxConnectionResult { pbxCallId, callNumber }
     */
    public function initConnect(int $calleeId, string $callerNumber): PbxConnectionResult;

    /**
     * 통화 연결 확정 처리 (callConnect)
     */
    public function callConnect(string $pbxCallId, int $callId): void;

    /**
     * Hermes 시스템 헬스체크 (checkLive)
     */
    public function checkLive(): bool;

    /**
     * Hermes에서 통화 과금 정보 조회 (coinInfo)
     */
    public function coinInfo(string $pbxCallId): PbxCoinInfo;

    /**
     * 통화 종료 Hermes 통보
     */
    public function notifyCallEnd(string $pbxCallId): void;

    /**
     * Hermes 통화 기록 동기화
     */
    public function syncCallRecord(string $pbxCallId): PbxCallRecord;
}
```

### 4.2 Repository 계층 설계

#### 4.2.1 CallRepository

**책임**: `tb_call_result` CRUD 및 상태 전환.

```php
class CallRepository
{
    public function insert(array $data): int;
    // 반환: 생성된 cr_code. 필수: caller_ac_id, callee_ac_id, idempotency_key

    public function findById(int $callId): ?array;

    public function updateStatus(int $callId, string $status, array $extra = []): bool;
    // status: 'insert'|'on'|'closed'|'miss'|'under30'
    // extra: start_time, end_time, duration_sec, coin_deducted 등

    public function findByCallerId(int $callerId, int $page, int $perPage): array;
    public function findByCalleeId(int $calleeId, int $page, int $perPage): array;
    public function existsByIdempotencyKey(string $key): bool;
}
```

#### 4.2.2 CallCloseRepository

**책임**: 정산 DB 연산 (코인 차감, Outbox 발행).

```php
class CallCloseRepository
{
    public function deductCoin(int $callerId, int $amount, int $callId): bool;
    // tb_coin INSERT. DB unique: (caller_ac_id, ref_type='call', ref_id=callId)

    public function publishOutboxEvent(string $eventType, array $payload): bool;
    // global_sync_pub_log INSERT. status='pending'
    // eventType: 'call.closed'|'call.payback'|'call.special_price'|'call.roulette'|'call.first_coupon'

    public function getCoinBalance(int $callerId): int;
    public function getCallDuration(int $callId): ?int;
    // TIMESTAMPDIFF(SECOND, start_time, end_time) FROM tb_call_result
}
```

#### 4.2.3 CalleeRepository (40+ 메서드)

**책임**: 상담사 전반 데이터 접근. 대시보드, 프로필, 컨텐츠, 통계, 즐겨찾기.

```php
class CalleeRepository
{
    // 프로필
    public function findById(int $calleeId): ?array;
    public function updateProfile(int $calleeId, array $data): bool;
    public function updateStatus(int $calleeId, string $status): bool;

    // 통계/대시보드
    public function getCallCountByPeriod(int $calleeId, string $startDate, string $endDate): int;
    public function getTotalDurationByPeriod(int $calleeId, string $startDate, string $endDate): int;
    public function getRevenueByPeriod(int $calleeId, string $startDate, string $endDate): int;

    // 즐겨찾기
    public function addFavorite(int $callerId, int $calleeId): bool;
    public function removeFavorite(int $callerId, int $calleeId): bool;
    public function getFavorites(int $callerId, int $page, int $perPage): array;

    // 컨텐츠 (posting/comment)
    public function getPostings(int $calleeId, int $page, int $perPage): array;
    public function insertPosting(array $data): int;
    public function updatePosting(int $postingId, int $calleeId, array $data): bool;
    public function deletePosting(int $postingId, int $calleeId): bool;
    public function getComments(int $calleeId, int $page, int $perPage): array;
    public function deleteComment(int $commentId, int $calleeId): bool;

    // 알람
    public function getAlarms(int $calleeId, int $page, int $perPage): array;
    public function markAlarmRead(int $alarmId, int $calleeId): bool;
    public function updateAlarmSettings(int $calleeId, array $settings): bool;
    public function insertAlarm(array $data): int;

    // FCM
    public function updateFcmToken(int $calleeId, string $token): bool;
    public function getFcmToken(int $calleeId): ?string;

    // 채팅/견적
    public function getChatList(int $calleeId, int $page, int $perPage): array;
    public function insertChatReply(array $data): int;
    public function getEstimates(int $calleeId, int $page, int $perPage): array;
    public function updateEstimateStatus(int $estimateId, int $calleeId, string $status): bool;

    // CTE/Window Function (복잡 집계 — $db->query() + named binding)
    public function getRankedCallees(array $filters): array;
    public function getActivitySummary(int $calleeId): array;
}
```

#### 4.2.4 CalleeManageRepository

**책임**: 상담사 계정 관리 (비밀번호, 온라인 상태, 알람 설정).

```php
class CalleeManageRepository
{
    public function findPasswordHash(int $calleeId): ?string;
    public function updatePasswordHash(int $calleeId, string $hash): bool;
    public function updateOnlineStatus(int $calleeId, bool $isOnline): bool;
    public function getAlarmConfig(int $calleeId): array;
    public function updateAlarmConfig(int $calleeId, array $config): bool;
}
```

#### 4.2.5 PbxRepository (22 메서드)

**책임**: PBX 통화 기록 저장, Hermes 동기화 데이터 관리.

```php
class PbxRepository
{
    public function insertPbxRecord(array $data): int;
    // 필수: pbx_call_id, callee_ac_id, call_number, raw_payload(JSON)

    public function findByPbxCallId(string $pbxCallId): ?array;
    public function updatePbxRecord(string $pbxCallId, array $data): bool;
    public function syncFromHermes(array $hermesData): bool;
    // Hermes 원본 데이터 upsert (pbx_call_id 기준)
    // (이하 18개 메서드 PBX 전용 조회·통계·이벤트 로깅)
}
```

---

## 5. 설계 관점 4: 의존성 관점 (Dependency Viewpoint)

IEEE 1016-2009 §5.4 — 컴포넌트 간 의존 관계

### 5.1 계층 간 의존성 규칙

```
Controller
    │ (Service 호출 — service() DI)
    ▼
Service
    │ (Repository 호출 — 생성자 주입)
    ▼
Repository
    │ (CI4 Query Builder 또는 $db->query())
    ▼
Aurora MySQL
```

**금지 의존성**:
- Controller → Repository 직접 접근 금지
- Repository → Service 역방향 호출 금지
- Service → 타 BC Service 직접 호출 금지 (Interface Only)
- 중앙 `app/Config/Services.php` 수정 금지 (`Modules/Call/Config/Services.php`에서만 DI 등록)

### 5.2 서비스 간 의존성

```
CallController ──depends──→ CallConnectionService
                        └──→ CallCloseService

CalleeController ──depends──→ CalleeActivityService
                          └──→ CalleeManageService

PbxController ──depends──→ PbxService
                       └──→ CallCloseService (call-end 시 정산 트리거)

CallConnectionService ──depends──→ CallRepository
                               └──→ PbxService

CallCloseService ──depends──→ CallCloseRepository
                          └──→ CalleeManageService (closeAlert)

PbxService ──depends──→ Hermes PBX (HTTP)
                    └──→ PbxRepository
```

### 5.3 외부 의존성

| 의존 대상 | 의존 방향 | 인터페이스 | 장애 대응 |
|---------|---------|---------|---------|
| Hermes PBX | 발신 | HTTP REST | PbxConnectionException + 재시도 (최대 3회) |
| FCM | 발신 | HTTP v1 API | 실패 시 로깅만. 비즈니스 영향 없음. |
| Aurora MySQL | 발신 | MySQL Protocol | CI4 DB 예외 처리 |
| global_sync_pub_log | 발신 (Outbox) | DB INSERT | 트랜잭션 내 원자적 처리 |

---

## 6. 설계 관점 5: 정보 관점 (Information Viewpoint)

IEEE 1016-2009 §5.5 — 데이터 구조 및 스키마

### 6.1 핵심 테이블: tb_call_result

```sql
CREATE TABLE `tb_call_result` (
  `cr_code`         BIGINT        NOT NULL AUTO_INCREMENT COMMENT '통화 기록 ID (PK)',
  `caller_ac_id`    INT           NOT NULL COMMENT 'Caller 계정 ID → tb_account.ac_id',
  `callee_ac_id`    INT           NOT NULL COMMENT 'Callee 계정 ID → tb_account.ac_id',
  `callee_ce_code`  VARCHAR(50)   NOT NULL COMMENT '상담사 코드 → tb_account.ce_code',
  `status`          ENUM('insert','on','closed','miss','under30')
                                  NOT NULL DEFAULT 'insert' COMMENT '통화 상태',
  `pbx_call_id`     VARCHAR(100)  NULL     COMMENT 'Hermes PBX 통화 ID',
  `call_number`     VARCHAR(20)   NULL     COMMENT '060 전화번호',
  `start_time`      DATETIME      NULL     COMMENT '통화 시작 시각 (UTC)',
  `end_time`        DATETIME      NULL     COMMENT '통화 종료 시각 (UTC)',
  `duration_sec`    INT           NULL     COMMENT '실제 통화 시간(초)',
  `coin_deducted`   INT           NOT NULL DEFAULT 0 COMMENT '차감된 코인',
  `coin_rate`       INT           NOT NULL DEFAULT 0 COMMENT '상담사 30초당 코인 요금',
  `idempotency_key` VARCHAR(64)   NULL     COMMENT '멱등키 (중복 요청 방지)',
  `event_flags`     JSON          NULL     COMMENT '이벤트 처리 플래그',
  `close_reason`    VARCHAR(100)  NULL     COMMENT '종료 사유 (miss/under30 시)',
  `created_at`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cr_code`),
  UNIQUE KEY `uq_idempotency_key` (`idempotency_key`),
  INDEX `idx_caller_ac_id` (`caller_ac_id`),
  INDEX `idx_callee_ac_id` (`callee_ac_id`),
  INDEX `idx_status`       (`status`),
  INDEX `idx_created_at`   (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='통화 기록 테이블';
```

### 6.2 상태 전환 제약

| 현재 상태 | 허용 전환 | 불허 전환 |
|---------|---------|---------|
| `insert` | → `on`, `miss` | 다른 모든 상태 |
| `on` | → `closed`, `under30` | 다른 모든 상태 |
| `closed` | 없음 (Terminal) | 모든 상태 |
| `miss` | 없음 (Terminal) | 모든 상태 |
| `under30` | 없음 (Terminal) | 모든 상태 |

### 6.3 관련 테이블 목록

| 테이블 | 설명 | 관련 Repository |
|--------|------|----------------|
| `tb_call_result` | 통화 기록 (상태, 시간, 코인 정보) | CallRepository, CallCloseRepository |
| `tb_coin` | 코인 차감/충전 내역 | CallCloseRepository |
| `tb_alarm` | 알람 발송 이력 | CalleeRepository |
| `tb_callee` | 상담사 정보 (상태, 설정) | CalleeRepository, CalleeManageRepository |
| `tb_items` | 상품/이벤트 아이템 정보 | CalleeRepository |
| `tb_posting` | 상담사 게시물 | CalleeRepository |
| `tb_comment` | 게시물 댓글 | CalleeRepository |
| `global_sync_pub_log` | Outbox 이벤트 테이블 | CallCloseRepository |

---

## 7. 설계 관점 6: 패턴 관점 (Patterns Use Viewpoint)

IEEE 1016-2009 §5.6 — 적용된 설계 패턴

### 7.1 적용 패턴 목록

| 패턴 | 적용 위치 | 목적 |
|------|---------|------|
| **Outbox Pattern** | CallCloseService + global_sync_pub_log | 코인 이벤트의 원자적 발행 보장 |
| **State Machine** | tb_call_result.status + CallRepository | 통화 생명주기 상태 관리 |
| **Repository Pattern** | 5개 Repository 클래스 | DB 접근 추상화, 테스트 가능성 |
| **Pure Function** | CallCloseService::getDurationToCoin() | 코인 계산 부수 효과 없음, 단위 테스트 용이 |
| **Idempotency Key** | tb_call_result.idempotency_key (UNIQUE) | 중복 통화 요청 방지 |
| **Defense in Depth** | RoleFilter → Controller → Repository | OWASP API5:2023 대응 3계층 인가 |
| **DI (Constructor Injection)** | Service → Repository | 느슨한 결합, 모킹 테스트 |

### 7.2 Outbox 패턴 상세

```
통화 종료 트랜잭션 (단일 DB 트랜잭션):
  1. tb_coin INSERT (코인 차감)
  2. global_sync_pub_log INSERT (Outbox 이벤트, status='pending')
  3. tb_call_result UPDATE (status='closed')
  COMMIT → 모두 성공 또는 모두 롤백

비동기 발행 (트랜잭션 외부):
  Lambda/Cron 폴링 → global_sync_pub_log WHERE status='pending'
  → SNS/SQS 발행 → status='published' 갱신
```

**채택 이유**: 통화 종료 트랜잭션 내에서 외부 서비스(Lambda/SNS)를 직접 호출하면, 외부 서비스 장애가 정산 실패로 이어짐. Outbox 패턴으로 비즈니스 데이터와 이벤트 발행을 원자적으로 분리.

---

## 8. 설계 관점 7: 인터페이스 관점 (Interface Viewpoint)

IEEE 1016-2009 §5.7 — 컴포넌트 간 인터페이스 계약

### 8.1 DI 등록 (Modules/Call/Config/Services.php)

```php
namespace App\Modules\Call\Config;

use Config\Services as BaseServices;
use App\Modules\Call\Services\{
    CallCloseService, CallConnectionService,
    CalleeActivityService, CalleeManageService, PbxService
};
use App\Modules\Call\Interfaces\{
    ICallCloseService, ICallConnectionService,
    ICalleeActivityService, ICalleeManageService, IPbxService
};

class Services extends BaseServices
{
    public static function callCloseService(bool $getShared = true): ICallCloseService
    {
        return static::getSharedInstance('callCloseService', $getShared)
            ?? new CallCloseService(/* DI: CallCloseRepository */);
    }

    public static function callConnectionService(bool $getShared = true): ICallConnectionService
    {
        return static::getSharedInstance('callConnectionService', $getShared)
            ?? new CallConnectionService(/* DI: CallRepository, PbxService */);
    }
    // ... 이하 3개 Service 동일 패턴
}
```

### 8.2 API 응답 표준

**성공 응답** (HTTP 200/201):
```json
{ "data": { ... } }
```

**에러 응답** (HTTP 4xx/5xx):
```json
{
  "error": {
    "code": "INSUFFICIENT_COIN",
    "message": "코인이 부족합니다. 최소 5,000코인 필요."
  }
}
```

**페이지네이션 응답** (CI4 paginate() 사용):
```json
{
  "data": [],
  "meta": {
    "currentPage": 1,
    "perPage": 20,
    "total": 150,
    "lastPage": 8
  }
}
```

### 8.3 필터 체인 설계

| API 그룹 | 필터 체인 |
|---------|---------|
| Call API (14 EP) | `ratelimit` → `csrftoken` → `auth` |
| Callee API (39 EP) | `ratelimit` → `csrftoken` → `auth` → `role:callee` |
| PBX API (13 EP) | `apikey` |

**공개 EP** (AuthFilter EXCLUDED_PATHS): PBX Webhook 전 EP, FCM 관련 EP

---

## 9. 설계 관점 8: 상호작용 관점 (Interaction Viewpoint)

IEEE 1016-2009 §5.8 — 컴포넌트 간 시퀀스 다이어그램

### 9.1 통화 연결 시퀀스

```
Caller        CallController    CallConnectionService  PbxService     Hermes PBX
  │                 │                    │                 │              │
  │ POST /calls/request                  │                 │              │
  │────────────────→│                    │                 │              │
  │                 │ validateCallEligibility(callerId, calleeId)          │
  │                 │───────────────────→│                 │              │
  │                 │                   [코인 ≥ 5000? Callee 온라인?]     │
  │                 │ EligibilityResult  │                 │              │
  │                 │←───────────────────│                 │              │
  │                 │ initiateCall(callerId, calleeId, idempotencyKey)     │
  │                 │───────────────────→│                 │              │
  │                 │                   │  initConnect(calleeId, callerNo)│
  │                 │                   │────────────────→│              │
  │                 │                   │                 │ POST /api/v1/calls/connect
  │                 │                   │                 │─────────────→│
  │                 │                   │                 │ { pbxCallId } │
  │                 │                   │                 │←─────────────│
  │                 │                   │ PbxConnectionResult             │
  │                 │                   │←────────────────│              │
  │                 │ CallInitResult { callId, pbxCallId }│              │
  │                 │←───────────────────│                 │              │
  │ HTTP 200 { callId, pbxCallId }       │                 │              │
  │←────────────────│                    │                 │              │
```

### 9.2 통화 종료 및 정산 시퀀스

```
Hermes        PbxController      CallCloseService    CallCloseRepository   DB
  │                │                    │                   │              │
  │ POST /pbx/call-end                  │                   │              │
  │───────────────→│                    │                   │              │
  │               │ closeCall(callId, endTime)               │              │
  │               │───────────────────→│                    │              │
  │               │                   │ getDurationToCoin() │              │
  │               │                   │ [계산: 0 or 코인]   │              │
  │               │                   │ BEGIN TRANSACTION   │              │
  │               │                   │                    │ deductCoin() │
  │               │                   │                    │─────────────→│
  │               │                   │                    │ tb_coin INSERT│
  │               │                   │                    │ publishOutboxEvent()
  │               │                   │                    │─────────────→│
  │               │                   │                    │ Outbox INSERT │
  │               │                   │                    │ UPDATE status │
  │               │                   │                    │─────────────→│
  │               │                   │ COMMIT              │              │
  │               │                   │ processEvents()     │              │
  │               │                   │ closeAlert() → FCM  │              │
  │               │ CloseResult { callId, status, coinDeducted }           │
  │               │←───────────────────│                    │              │
  │ HTTP 200      │                    │                    │              │
  │←─────────────│                    │                    │              │
```

### 9.3 대시보드 조회 시퀀스

```
Callee        CalleeController   CalleeActivityService   CalleeRepository   DB
  │                 │                    │                    │              │
  │ GET /callees/dashboard               │                    │              │
  │────────────────→│                    │                    │              │
  │               [role:callee 필터 검증]│                    │              │
  │                 │ getActivityData(calleeId)               │              │
  │                 │───────────────────→│                    │              │
  │                 │                   │ getCallCountByPeriod(today/week/month)
  │                 │                   │───────────────────→│              │
  │                 │                   │                    │ SELECT COUNT  │
  │                 │                   │                    │─────────────→│
  │                 │                   │ getRevenueByPeriod()│              │
  │                 │                   │───────────────────→│              │
  │                 │                   │ DashboardData      │              │
  │                 │                   │←───────────────────│              │
  │                 │ HTTP 200 { data: { today, week, month } }             │
  │                 │←───────────────────│                    │              │
  │←────────────────│                    │                    │              │
```

---

## 10. 설계 오버레이 (Design Overlay)

IEEE 1016-2009 §5.9 — 아키텍처 설계 제약 및 오버레이

### 10.1 레이어 아키텍처 오버레이

```
┌──────────────────────────────────────────────────────────┐
│ Presentation Layer: Controller (HTTP 입출력, 유효성 검증)  │
│   CallController / CalleeController / PbxController       │
│   규칙: Service만 호출. Repository 직접 접근 금지.         │
├──────────────────────────────────────────────────────────┤
│ Business Logic Layer: Service (비즈니스 로직, 트랜잭션)    │
│   5개 Service. 트랜잭션 경계 여기서만 정의.                │
│   규칙: Repository만 사용. 타 BC Service는 Interface Only. │
├──────────────────────────────────────────────────────────┤
│ Data Access Layer: Repository (DB 추상화)                  │
│   5개 Repository. Query Builder 우선.                     │
│   CTE/Window Function은 $db->query() + named binding.    │
│   규칙: 단순 DB 연산만. 비즈니스 로직 금지.               │
├──────────────────────────────────────────────────────────┤
│ Infrastructure Layer: Aurora MySQL + Hermes + FCM         │
└──────────────────────────────────────────────────────────┘
```

### 10.2 보안 오버레이 (Defense in Depth)

```
HTTP Request
    │
    ▼ Layer 0: Nginx (TLS termination, X-Forwarded-Proto)
    │
    ▼ Layer 1: RateLimit Filter (DDoS 방어)
    │
    ▼ Layer 2: CSRF Token Filter (POST/PUT/DELETE)
    │
    ▼ Layer 3: Auth Filter (JWT 검증 / API Key 검증)
    │
    ▼ Layer 4: Role Filter (role:callee 권한 검증, Callee API 전용)
    │
    ▼ Layer 5: Controller (입력 유효성 검증, 비즈니스 규칙 pre-check)
    │
    ▼ Layer 6: Repository (소유권 조건 — calleeId/callerId WHERE 절)
    │
    ▼ Layer 7: DB (unique 제약, FK 참조 무결성)
```

### 10.3 트랜잭션 오버레이

| 작업 | 트랜잭션 범위 | 포함 연산 |
|------|------------|---------|
| 통화 종료 정산 | 단일 트랜잭션 | tb_coin INSERT + Outbox INSERT + tb_call_result UPDATE |
| 게시물 작성 | 단일 트랜잭션 | tb_posting INSERT |
| 즐겨찾기 추가 | 단일 쿼리 | tb_favorite INSERT (자체 원자적) |

---

## 11. 요구사항-설계 추적성 매트릭스 (Traceability Matrix)

IEEE 1016-2009 §5.10 기준

### 11.1 FR → 설계 요소 매핑

| 요구사항 ID | 요구사항 요약 | 설계 요소 | 위치 |
|------------|------------|---------|------|
| FR-001-01 | 코인 잔액 ≥ CALL_MIN_COIN | `CallConnectionService::validateCallEligibility()` | §4.1.1 |
| FR-001-02 | Callee 상태 확인 | `CallConnectionService::validateCallEligibility()` | §4.1.1 |
| FR-001-03 | tb_call_result Insert | `CallRepository::insert()` | §4.2.1 |
| FR-001-04 | Hermes 060 연결 트리거 | `PbxService::initConnect()` | §4.1.5 |
| FR-001-05 | 연결 성공 → status=on | `CallConnectionService::confirmConnection()` | §4.1.1 |
| FR-001-06 | 연결 실패 → status=miss | `CallConnectionService::markMissed()` | §4.1.1 |
| FR-001-07 | 멱등키 중복 방지 | `tb_call_result.uq_idempotency_key` | §6.1 |
| FR-001-08 | 이벤트 마크 확인 | `CallConnectionService::checkEventMarks()` | §4.1.1 |
| FR-002-01 | 통화 시간(초) 기록 | `CallRepository::updateStatus(... duration_sec)` | §4.2.1 |
| FR-002-02 | ≤30초 → under30 | `CallCloseService::markUnder30()` | §4.1.2 |
| FR-002-03 | >30초 COIN_TERM 차감 | `CallCloseService::getDurationToCoin()` | §4.1.2 |
| FR-002-04 | 트랜잭션 원자성 | `CallCloseRepository` (BEGIN TRANSACTION) | §4.2.2 |
| FR-002-07 | 이벤트 Outbox INSERT | `CallCloseService::processEvents()` | §4.1.2 |
| FR-002-08 | getDurationToCoin 순수 함수 | `CallCloseService::getDurationToCoin()` | §4.1.2 |
| FR-003-01 | PBX API Key 전용 | `PbxController` + `apikey` filter | §3.2.3 |
| FR-003-02 | Hermes Callback 수신 | `PbxController::callStart/callEnd/callMiss()` | §3.2.3 |
| FR-003-04 | PBX CSRF 면제 | Routes.php EXCLUDED_PATHS | §8.3 |
| FR-003-06 | Hermes 헬스체크 | `PbxService::checkLive()` | §4.1.5 |
| FR-003-07 | Hermes 과금 정보 조회 | `PbxService::coinInfo()` | §4.1.5 |
| FR-004-01 | 오늘/주/월 통화 통계 | `CalleeActivityService::getActivityData()` | §4.1.3 |
| FR-004-02 | 수익 현황 조회 | `CalleeActivityService::getRevenueStats()` | §4.1.3 |
| FR-004-05 | 대시보드 role:callee 보호 | Routes.php `['filter' => 'role:callee']` | §8.3 |
| FR-005-01 | FCM 통화 요청 알림 | `CalleeManageService::callCloseAlarm()` | §4.1.4 |
| FR-005-05 | FCM 토큰 갱신 | `CalleeManageService::updateFcmToken()` | §4.1.4 |
| FR-007-04 | 파일 MIME 이중 검증 | `CalleeController` (mime_content_type) | §3.2.2 |
| FR-009-01 | 코인 차감 내역 기록 | `CallCloseRepository::deductCoin()` | §4.2.2 |
| FR-009-02 | 코인 중복 차감 방지 | `tb_coin` unique 제약 | §6.2 |

### 11.2 NFR → 설계 요소 매핑

| NFR ID | NFR 요약 | 설계 요소 |
|--------|---------|---------|
| NFR-001 | Call API P99 < 500ms | tb_call_result 4개 인덱스 (§6.1) |
| NFR-003 | Hermes 타임아웃 설정 | PbxService cURL 설정 (연결 3s, 응답 10s) |
| NFR-010 | 코인 정확도 99.99% | getDurationToCoin 순수 함수 + PHPUnit |
| NFR-011 | 멱등성 보장 | uq_idempotency_key + DB unique 제약 |
| NFR-030 | role:callee 전 EP 적용 | Routes.php `['filter' => 'role:callee']` (39 EP) |
| NFR-031 | PBX API Key 전용 | apikey 필터 체인 (13 EP) |

---

## 12. 아키텍처 결정 기록 (ADR)

### ADR-001: Outbox 패턴 채택 (코인 이벤트 발행)

| 항목 | 내용 |
|------|------|
| 상태 | 승인됨 |
| 결정 | 코인 이벤트(Payback, Special Price, Roulette, First-call Coupon)는 `global_sync_pub_log` Outbox 테이블을 통해 발행한다 |
| 배경 | 통화 종료 트랜잭션 내에서 직접 외부 서비스(Lambda/SNS)를 호출할 경우, 외부 서비스 장애가 정산 실패로 이어질 수 있다 |
| 대안 | 직접 Lambda 호출 (거부: 원자성 보장 불가), SQS Direct (거부: DB 트랜잭션과 분리) |
| 결과 | 비즈니스 데이터와 이벤트 발행이 원자적으로 처리됨. 외부 서비스 장애와 정산 로직 분리 달성. |
| 관련 FR | FR-002-04, FR-002-07 |

### ADR-002: 상수 중앙 정의 (COIN_TERM, FREE_DURATION, CALL_MIN_COIN)

| 항목 | 내용 |
|------|------|
| 상태 | 승인됨 |
| 결정 | 과금 관련 상수는 Service 클래스에 `public const`로 정의하여 SSOT를 보장한다 |
| 배경 | 분산된 매직 넘버는 오류 위험 증가 및 변경 시 누락 가능성 |
| 결과 | 상수 변경 시 단일 위치 수정으로 전파. 테스트 시 상수 참조로 정확성 검증 가능. |
| 관련 FR | FR-001-01, FR-002-02, FR-002-03 |

### ADR-003: role:callee 필터 라우트 레벨 적용

| 항목 | 내용 |
|------|------|
| 상태 | 승인됨 |
| 결정 | Callee 전용 EP에 `['filter' => 'role:callee']`를 Routes.php에서 명시적으로 등록한다 |
| 배경 | 컨트롤러 레벨 검증만으로는 OWASP API5:2023 Broken Function Level Authorization 위험 존재 |
| 결과 | 3계층 Defense in Depth (라우트 필터 → 컨트롤러 → Repository 소유권 조건). |
| 관련 NFR | NFR-030 |

### ADR-004: PBX API Key 전용 인증

| 항목 | 내용 |
|------|------|
| 상태 | 승인됨 |
| 결정 | PBX API는 `X-Api-Key` 인증만 허용. JWT/세션 폴백 없음. |
| 배경 | 서버-서버 통신에 쿠키 기반 JWT는 부적합. API Key가 단순하고 명확. |
| 결과 | PBX Webhook CSRF 면제 + API Key 전용 필터로 보안 명확화. |
| 관련 FR | FR-003-01 |

---

## 13. 타당성 검토 (Feasibility Review)

### 13.1 설계 타당성

**Service 5개 분리 타당성**:
- CallConnectionService(연결)와 CallCloseService(종료 정산)는 책임과 트랜잭션 경계가 명확히 달라 분리가 적절.
- CalleeActivityService는 집계 전용으로 쓰기 연산 없음(읽기 전용 Service 분리).
- 근거: SOLID 단일 책임 원칙(SRP). 각 Service가 하나의 도메인 동작에만 집중.

**Repository 5개 분리 타당성**:
- CallCloseRepository는 코인 차감 + Outbox 발행의 트랜잭션 단위로 분리.
- 40+ 메서드의 CalleeRepository는 기능 그룹별 추가 분리를 검토할 수 있으나, 현재 규모에서는 단일 Repository로 관리가 적합.
- PbxRepository 22 메서드는 PBX 도메인 응집도 유지.

**통화 상태 기계 타당성**:
- 5개 상태(Insert/On/Closed/Miss/Under30)는 통화 흐름의 모든 경우를 커버.
- Terminal State 처리로 상태 역행 방지. 근거: 유한 상태 기계(FSM) 패턴.

### 13.2 리스크 및 대응

| 리스크 | 발생 확률 | 영향도 | 대응 |
|--------|:-------:|:-----:|------|
| Hermes API 장애 | 중 | 높음 | 재시도 로직 (3회) + Miss 처리 폴백 |
| 코인 중복 차감 | 낮음 | 높음 | DB unique 제약 최후 방어선 |
| FCM 발송 실패 | 중 | 낮음 | 비즈니스 로직 영향 없음 (로깅만) |
| Outbox 처리 지연 | 중 | 중 | Lambda/Cron SLA에 의존. 지연 허용 설계. |

### 13.3 변경 영향 분석

**변경되는 사항**: v1.0 평면 설계 문서 → v2.0 IEEE 1016-2009 8 Viewpoint 구조
**개선점**:
- 맥락 관점으로 시스템 경계와 외부 의존성이 명확히 시각화됨
- 상호작용 관점의 3개 시퀀스 다이어그램으로 런타임 흐름 추적 가능
- 추적성 매트릭스로 FR ↔ 설계 요소 ↔ 코드 위치 연결
**수행 이유**: IEEE 1016-2009 표준 준수로 설계 리뷰 효율화 및 신규 개발자 온보딩 시간 단축.

---

## 14. 변경 이력 (Change History)

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|---------|-------|
| v1.0 | 2026-04-15 | 최초 작성 — Controllers(66 EP), Services(5), Repositories(5), DB 설계, 상태 기계, 계산 공식, 시퀀스 다이어그램, ADR 포함 | jypark |
| v2.0 | 2026-04-15 | IEEE 표준 전면 전환. 3-Round Review PASS. IEEE 1016-2009 8 Viewpoint 구조 적용. 맥락/구성/논리/의존성/정보/패턴/인터페이스/상호작용 관점 신설. 설계 오버레이(레이어·보안·트랜잭션) 추가. 요구사항-설계 추적성 매트릭스 추가. Service 메서드를 실제 구현명(validateCallEligibility, initiateCall, checkEventMarks, closeCall, getDurationToCoin, closeAlert, getActivityData, calleeCallDuration, calleePasswdChange, callCloseAlarm, initConnect, callConnect, checkLive, coinInfo)으로 갱신. | jypark |
