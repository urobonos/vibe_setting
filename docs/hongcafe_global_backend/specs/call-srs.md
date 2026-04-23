---
문서명: Call 모듈 소프트웨어 요구사항 명세서 (SRS)
문서ID: SRS-CALL-001
버전: v2.0
상태: 승인됨
적용 표준: IEEE 29148:2018 (ISO/IEC/IEEE 29148:2018 Systems and software engineering — Life cycle processes — Requirements engineering)
생성일: 2026-04-15
최종수정일: 2026-04-15
작성자: jypark
대상 시스템: Call 모듈 (통화 연결·종료·정산·대시보드·PBX 연동)
관련 문서:
  - call-sdd.md (SDD-CALL-001, IEEE 1016-2009)
  - call-idd.md (IDD-CALL-001, MIL-STD-498)
  - api-docs/call/call-api.md
  - api-docs/call/callee-api.md
  - api-docs/call/pbx-api.md
변경 로그: "IEEE 표준 전면 전환. 3-Round Review PASS"
---

# Call 모듈 소프트웨어 요구사항 명세서 (SRS)

> **문서 ID**: SRS-CALL-001 | **버전**: v2.0 | **상태**: 승인됨
> **적용 표준**: IEEE 29148:2018 | **작성자**: jypark | **작성일**: 2026-04-15

---

## 목차

1. [소개 (Introduction)](#1-소개)
2. [전체 설명 (Overall Description)](#2-전체-설명)
3. [이해관계자 요구사항 (StRS)](#3-이해관계자-요구사항)
4. [시스템 요구사항 명세 (SyRS)](#4-시스템-요구사항-명세)
5. [소프트웨어 요구사항 명세 (SwRS)](#5-소프트웨어-요구사항-명세)
6. [데이터 딕셔너리 (Data Dictionary)](#6-데이터-딕셔너리)
7. [외부 인터페이스 요구사항 (External Interface Requirements)](#7-외부-인터페이스-요구사항)
8. [검증 매트릭스 (Verification Matrix)](#8-검증-매트릭스)
9. [타당성 검토 (Feasibility Review)](#9-타당성-검토)
10. [변경 이력 (Change History)](#10-변경-이력)

---

## 1. 소개 (Introduction)

### 1.1 목적 (Purpose)

본 문서는 HongCafe Global 백엔드의 **Call 모듈**에 대한 소프트웨어 요구사항을 IEEE 29148:2018 표준에 따라 정의한다. Call 모듈은 통화 연결, 종료 정산, PBX 연동, 상담사 대시보드, 알람, 즐겨찾기, 컨텐츠 관리, 채팅·견적, 포인트(코인) 관리, 060 전화 연동을 포괄하는 시스템에서 가장 규모가 큰 바운디드 컨텍스트(Bounded Context)이다.

본 문서의 독자는 소프트웨어 개발자, 테스트 엔지니어, 시스템 아키텍트, 운영팀이며, 하위 문서인 SDD-CALL-001(설계)과 IDD-CALL-001(인터페이스)의 상위 기준 문서로 기능한다.

### 1.2 범위 (Scope)

**시스템 명칭**: HongCafe Global Backend — Call Module

**포함 범위**:

| 컴포넌트 | Endpoint 수 | 인증 방식 | 설명 |
|----------|:-----------:|----------|------|
| Call API | 14 | JWT (hc_access 쿠키) | 통화 요청, 연결, 종료, 내역 조회, 즐겨찾기, 견적 요청 |
| Callee API | 39 | JWT + role:callee 필터 | 상담사 전용. 대시보드, 프로필, 컨텐츠, 채팅, 견적, 알람 |
| PBX API | 13 | API Key (X-Api-Key) | Hermes PBX 연동, 060 전화 처리, Callback 수신 |
| **합계** | **66** | | |

**제외 범위**: 결제(Payment) 모듈, 회원가입/인증(Auth) 모듈, 게시판(Board) 모듈은 별도 SRS에서 정의한다.

### 1.3 정의, 두문자어, 약어 (Definitions, Acronyms, and Abbreviations)

| 용어 / 약어 | 정의 |
|------------|------|
| Caller | 통화를 요청하는 고객 (일반 회원). `tb_account.ce_code` 미존재. |
| Callee | 상담사. `tb_account.ce_code` 존재 여부로 판별 (`UserRole::Callee`). |
| BC | Bounded Context — 도메인 모듈 경계 단위 |
| COIN_TERM | 코인 차감 주기 = **30초** |
| FREE_DURATION | 무료 통화 구간 = **30초** (이하 통화는 코인 차감 없음) |
| CALL_MIN_COIN | 통화 가능 최소 코인 = **5,000** |
| PBX | Private Branch Exchange. Hermes 시스템 경유 060 전화 처리 |
| Outbox | 크로스 도메인 이벤트 발행 테이블 (`global_sync_pub_log`) |
| JWT | JSON Web Token. HMAC-SHA256, `hc_access` HttpOnly 쿠키 전용 |
| FCM | Firebase Cloud Messaging — 모바일 Push 알림 |
| Hermes | 내부 PBX 시스템. 기본 URL: `http://hermes.peoplev.co.kr` |
| SSOT | Single Source of Truth — 단일 진실의 원천 |
| DI | Dependency Injection |
| ADR | Architecture Decision Record |
| SRS | Software Requirements Specification (IEEE 29148:2018) |
| SDD | Software Design Description (IEEE 1016-2009) |
| IDD | Interface Design Description (MIL-STD-498) |
| FR | Functional Requirement — 기능 요구사항 |
| NFR | Non-Functional Requirement — 비기능 요구사항 |
| P0 | 최고 우선순위. 미구현 시 릴리스 차단. |
| P1 | 높은 우선순위. 릴리스 전 구현 권장. |
| P2 | 중간 우선순위. 다음 스프린트 이전 가능. |

### 1.4 참조 문서 (References)

| 문서 | 출처 |
|------|------|
| IEEE 29148:2018 | ISO/IEC/IEEE 29148:2018 Systems and software engineering — Life cycle processes — Requirements engineering |
| IEEE 1016-2009 | IEEE Standard for Information Technology — Systems Design — Software Design Descriptions |
| MIL-STD-498 | Military Standard — Software Development and Documentation |
| OWASP API Security Top 10:2023 | https://owasp.org/API-Security/ |
| RFC 7231 | Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content |
| CLAUDE.md (프로젝트 지침) | HongCafe Global Backend 프로젝트 루트 |

---

## 2. 전체 설명 (Overall Description)

### 2.1 제품 관점 (Product Perspective)

Call 모듈은 HongCafe Global 백엔드(Modular Monolith 아키텍처)의 핵심 바운디드 컨텍스트로, 다음 외부 시스템 및 내부 모듈과 상호작용한다.

```
┌─────────────────────────────────────────────────────────────┐
│                   HongCafe Global Backend                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Call Module (BC)                   │   │
│  │  ┌───────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ Call API  │  │  Callee API  │  │   PBX API    │  │   │
│  │  │  (14 EP)  │  │   (39 EP)   │  │   (13 EP)    │  │   │
│  │  └─────┬─────┘  └──────┬───────┘  └──────┬───────┘  │   │
│  │        └───────────────┼─────────────────┘           │   │
│  │                    Services (5)                       │   │
│  │              Repositories (5) → DB                   │   │
│  └──────────────────────────────────────────────────────┘   │
│        │                │               │                    │
│   Member BC        Coin BC         Shared BC                 │
└─────────────────────────────────────────────────────────────┘
         │                                │
    Hermes PBX                           FCM
 (http://hermes.peoplev.co.kr)   (Firebase Cloud Messaging)
```

**관련 내부 모듈**:
- **Member BC**: Caller/Callee 계정 정보 (tb_account). Interface Only 연동.
- **Coin BC**: 코인 잔액 조회·차감. Outbox 패턴을 통한 이벤트 기반 연동.
- **Shared BC**: `Modules/Shared/` — 공유 Model, Entity, ValueObject, Interface.

### 2.2 제품 기능 (Product Functions)

Call 모듈은 아래 10개 기능 영역을 제공한다:

| 기능 영역 | 설명 | 주요 Actor |
|----------|------|-----------|
| 통화 연결 | 코인 검증 → PBX 연결 트리거 → 상태 전환 | Caller, Hermes |
| 통화 종료·정산 | 통화 시간 계산 → 코인 차감 → Outbox 발행 | Hermes (Callback) |
| PBX 연동 | Hermes Callback 수신 및 060 전화 처리 | Hermes PBX |
| 상담사 대시보드 | 통화 통계·수익 현황 집계 조회 | Callee |
| 상담사 알람 | FCM Push 알림 발송 및 알람 이력 관리 | System, Callee |
| 즐겨찾기 | 상담사 즐겨찾기 추가·삭제·조회 | Caller |
| 컨텐츠 관리 | 게시물·댓글 CRUD | Callee |
| 채팅·견적 | 채팅 내역 조회·답장, 견적 요청·응답 | Caller, Callee |
| 포인트(코인) 관리 | 코인 차감 내역 조회, 이벤트 처리 | Caller |
| 060 전화 연동 | 인바운드/아웃바운드 060 처리 | Hermes PBX |

### 2.3 사용자 특성 (User Characteristics)

| 사용자 | 역할 | 기술 수준 | 주요 관심사 |
|--------|------|---------|-----------|
| Caller (고객) | 일반 회원 | 비기술자 | 통화 연결 편의성, 코인 차감 투명성 |
| Callee (상담사) | 등록 상담사 | 비기술자 | 수익 정산 정확성, 대시보드 실시간성 |
| 운영자 | 내부 운영팀 | 중간 기술자 | 통화 로그, 정산 내역, 이벤트 관리 |
| Hermes PBX | 외부 시스템 | 서버-서버 | API Key 기반 연동 신뢰성 |

### 2.4 제약사항 (Constraints)

| 제약 유형 | 제약 내용 |
|----------|---------|
| 언어/프레임워크 | PHP 8.4+ (프로덕션 8.5.3), CodeIgniter 4.7+ |
| DB | Amazon Aurora MySQL 3.12.0 (MySQL 8.0.44 Compatible) |
| 인증 방식 | JWT (`hc_access` HttpOnly 쿠키). localStorage 저장 금지. |
| 자동 라우팅 | 비활성화 (`setAutoRoute(false)`). 모든 EP 명시적 등록 필수. |
| DB 문자셋 | `utf8mb4` 통일 (서버/DB/테이블/컬럼 전 레벨) |
| 타임존 | UTC 통일. 서버/DB 모두 UTC. 사용자 표시는 프론트엔드에서 로컬 변환. |
| 날짜 API | `DateTimeImmutable` 강제. `date()`, `time()` 사용 금지. |
| 엄격 타입 | `declare(strict_types=1)` 모든 PHP 파일 필수. |

### 2.5 가정 및 의존성 (Assumptions and Dependencies)

- Hermes PBX 시스템(`http://hermes.peoplev.co.kr`)이 운영 상태임을 가정한다.
- FCM 서비스 계정 JSON이 서버 환경변수에 설정되어 있음을 가정한다.
- Aurora MySQL RDS Proxy IAM 인증이 구성되어 있음을 가정한다.
- `global_sync_pub_log` Outbox 테이블이 DB에 존재함을 의존한다.
- Lambda/Cron이 Outbox 테이블을 폴링하여 SNS/SQS로 발행함을 의존한다.

---

## 3. 이해관계자 요구사항 (StRS — Stakeholder Requirements Specification)

IEEE 29148:2018 §6.2 기준

### 3.1 이해관계자 식별

| 이해관계자 ID | 역할 | 이해관계자 | 요구사항 범주 |
|-------------|------|-----------|-------------|
| STK-001 | 고객 (Caller) | 일반 회원 | 통화 연결 편의성, 코인 차감 투명성, 즐겨찾기 |
| STK-002 | 상담사 (Callee) | 등록 상담사 | 수익 정산 정확성, 대시보드 실시간성, 알람 관리 |
| STK-003 | 운영자 | 내부 운영팀 | 통화 로그 추적, 정산 내역 검증, 이벤트 관리 |
| STK-004 | 시스템 관리자 | 인프라팀 | 가용성 99.9%, 응답시간, 보안 감사 로그 |
| STK-005 | 외부 시스템 | Hermes PBX | API Key 기반 연동 신뢰성, Callback 처리 |

### 3.2 이해관계자 요구사항 목록

| StRS ID | 이해관계자 | 요구사항 내용 | 관련 FR/NFR |
|---------|-----------|-------------|------------|
| StRS-001 | STK-001 | 나는 상담사에게 손쉽게 통화를 요청하고 연결되기를 원한다 | FR-001 |
| StRS-002 | STK-001 | 나는 통화 후 차감된 코인 내역을 투명하게 확인하기를 원한다 | FR-002, FR-009 |
| StRS-003 | STK-001 | 나는 자주 이용하는 상담사를 즐겨찾기에 등록하기를 원한다 | FR-006 |
| StRS-004 | STK-001 | 나는 상담사에게 견적을 요청하기를 원한다 | FR-008 |
| StRS-005 | STK-002 | 나는 오늘/이번 주/이번 달 통화 건수와 수익을 실시간으로 확인하기를 원한다 | FR-004 |
| StRS-006 | STK-002 | 나는 통화 요청이 오면 즉시 Push 알림을 받기를 원한다 | FR-005 |
| StRS-007 | STK-002 | 나는 내 게시물과 댓글을 직접 관리하기를 원한다 | FR-007 |
| StRS-008 | STK-002 | 나는 채팅 요청에 답장하고 견적을 처리하기를 원한다 | FR-008 |
| StRS-009 | STK-003 | 나는 모든 통화 기록을 조회하고 정산 오류를 추적하기를 원한다 | FR-002, NFR-001 |
| StRS-010 | STK-005 | Hermes 시스템은 통화 이벤트 Callback을 안정적으로 전달하기를 원한다 | FR-003, FR-010 |

---

## 4. 시스템 요구사항 명세 (SyRS — System Requirements Specification)

IEEE 29148:2018 §6.3 기준

### 4.1 시스템 기능 요구사항

| SyRS ID | 시스템 요구사항 | 관련 StRS |
|---------|--------------|---------|
| SyRS-001 | 시스템은 Caller와 Callee 간 실시간 통화를 Hermes PBX를 경유하여 중개해야 한다 | StRS-001 |
| SyRS-002 | 시스템은 통화 종료 시 30초 단위 코인 차감을 원자적으로 처리해야 한다 | StRS-002 |
| SyRS-003 | 시스템은 Hermes로부터 통화 이벤트 Callback을 수신하고 상태를 동기화해야 한다 | StRS-010 |
| SyRS-004 | 시스템은 상담사에게 FCM을 통한 실시간 Push 알림을 발송해야 한다 | StRS-006 |
| SyRS-005 | 시스템은 코인 이벤트(Payback, Roulette 등)를 Outbox 패턴으로 비동기 발행해야 한다 | StRS-002 |
| SyRS-006 | 시스템은 Callee API 전 Endpoint에 role:callee 인가 필터를 적용해야 한다 | StRS-007, StRS-008 |
| SyRS-007 | 시스템은 PBX API를 API Key 전용 인증으로 보호해야 한다 | StRS-010 |

### 4.2 시스템 비기능 요구사항

| SyRS ID | 구분 | 시스템 요구사항 |
|---------|------|--------------|
| SyRS-010 | 성능 | Call API 응답시간 P99 < 500ms (DB 조회 포함) |
| SyRS-011 | 성능 | Hermes API 타임아웃: 연결 3초, 응답 10초 |
| SyRS-012 | 가용성 | 시스템 가용성 99.9% 이상 (월간 기준) |
| SyRS-013 | 정확성 | 코인 차감 정확도 99.99% 이상 (COIN_TERM 단위 오류율 < 0.01%) |
| SyRS-014 | 실시간성 | 상담사 상태 갱신 지연 < 5초 (P95) |
| SyRS-015 | 보안 | JWT + HttpOnly 쿠키 전용. localStorage 저장 금지. |

---

## 5. 소프트웨어 요구사항 명세 (SwRS — Software Requirements Specification)

IEEE 29148:2018 §6.4 기준

### 5.1 기능 요구사항 (Functional Requirements)

---

#### FR-001: 통화 연결 (Call Connection)

**관련 SyRS**: SyRS-001, SyRS-003
**관련 서비스**: `CallConnectionService`
**사전 조건**: Caller 로그인 상태, 코인 잔액 ≥ CALL_MIN_COIN(5,000)
**사후 조건**: `tb_call_result` 레코드 생성 (status=Insert), Hermes API 호출 완료

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-001-01 | 시스템은 통화 요청 시 Caller의 코인 잔액이 CALL_MIN_COIN(5,000) 이상인지 검증해야 한다. 잔액 부족 시 HTTP 400 / INSUFFICIENT_COIN 반환. | P0 | 단위 테스트 |
| FR-001-02 | 시스템은 통화 요청 시 Callee의 상태(온라인/오프라인/통화중)를 확인해야 한다. 오프라인/통화중이면 HTTP 409 / CALLEE_UNAVAILABLE 반환. | P0 | 단위 테스트 |
| FR-001-03 | 시스템은 통화 시작 시 `tb_call_result`에 status='insert' 레코드를 원자적으로 생성해야 한다. | P0 | 통합 테스트 |
| FR-001-04 | 시스템은 PBX(Hermes)를 통해 060 전화 연결을 트리거해야 한다. Hermes 응답의 `pbx_call_id`를 `tb_call_result.pbx_call_id`에 기록해야 한다. | P0 | 통합 테스트 |
| FR-001-05 | 통화 연결 성공 Callback 수신 시 status='on'으로 전환하고 start_time(UTC)을 기록해야 한다. | P0 | 통합 테스트 |
| FR-001-06 | 통화 연결 실패(Hermes 오류, Callee 무응답) 시 status='miss'로 전환하고 close_reason을 기록해야 한다. | P1 | 단위 테스트 |
| FR-001-07 | 시스템은 `X-Idempotency-Key` 헤더 값으로 중복 통화 요청을 방지해야 한다. 동일 키 재요청 시 HTTP 409 / CONFLICT 반환. | P0 | 단위 테스트 |
| FR-001-08 | 시스템은 이벤트 마크(EventMark)를 확인하여 특별 이벤트 통화 여부를 식별해야 한다. | P1 | 단위 테스트 |

**통화 연결 흐름**:
```
Caller → POST /api/calls/request
  → CallConnectionService::validateCallEligibility()
      → 코인 잔액 ≥ 5,000? No → HTTP 400 INSUFFICIENT_COIN
      → Callee 상태 온라인? No → HTTP 409 CALLEE_UNAVAILABLE
  → CallConnectionService::initiateCall()
      → tb_call_result INSERT (status='insert')
      → PbxService::initConnect()
          → Hermes POST /api/v1/calls/connect
  → HTTP 200 { callId, pbxCallId }
```

---

#### FR-002: 통화 종료 및 정산 (Call Close and Coin Settlement)

**관련 SyRS**: SyRS-002, SyRS-005
**관련 서비스**: `CallCloseService`
**관련 테이블**: `tb_call_result`, `tb_coin`, `global_sync_pub_log`
**사전 조건**: 통화 상태 = 'on'
**사후 조건**: 코인 차감 완료, 통화 상태 = 'closed' 또는 'under30', Outbox 이벤트 발행

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-002-01 | 시스템은 통화 종료 시 실제 통화 시간을 초(int) 단위로 기록해야 한다. start_time과 end_time의 차이로 계산. | P0 | 단위 테스트 |
| FR-002-02 | FREE_DURATION(30초) 이하 통화는 코인 차감 없이 status='under30'으로 기록해야 한다. | P0 | 단위 테스트 |
| FR-002-03 | FREE_DURATION(30초) 초과 통화는 COIN_TERM(30초) 단위로 코인을 차감해야 한다. 공식: `ceil((duration - 30) / 30) × ratePerTerm`. | P0 | 단위 테스트 |
| FR-002-04 | 코인 차감, Outbox 이벤트 발행, tb_call_result 상태 갱신은 하나의 DB 트랜잭션 내에서 원자적으로 수행해야 한다. | P0 | 통합 테스트 |
| FR-002-05 | 시스템은 정산 완료 후 FCM으로 Caller/Callee에게 통화 종료 알림을 발송해야 한다. | P1 | 통합 테스트 |
| FR-002-06 | 시스템은 통화 종료 시 status='closed'로 전환하고 end_time(UTC), duration_sec, coin_deducted를 기록해야 한다. | P0 | 단위 테스트 |
| FR-002-07 | 이벤트 처리(Payback, Special Price, Roulette, First-call Coupon)는 정산 트랜잭션과 동일 트랜잭션 내 Outbox INSERT로 수행해야 한다. | P1 | 단위 테스트 |
| FR-002-08 | `getDurationToCoin()` 메서드는 순수 함수(pure function)로 구현하여 부수 효과 없이 차감 코인 수를 반환해야 한다. | P0 | 단위 테스트 |

**코인 계산 공식**:
```
차감 코인 = ceil((durationSeconds - FREE_DURATION) / COIN_TERM) × ratePerTerm

상수: FREE_DURATION = 30, COIN_TERM = 30
조건: durationSeconds ≤ FREE_DURATION → 0 반환

예시 (ratePerTerm = 500코인):
  ≤ 30초  → 0코인
  31~60초 → 500코인
  61~90초 → 1,000코인
  91~120초 → 1,500코인
```

---

#### FR-003: PBX 연동 (Hermes PBX Integration)

**관련 SyRS**: SyRS-003, SyRS-007
**관련 서비스**: `PbxService`
**외부 시스템**: `http://hermes.peoplev.co.kr`

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-003-01 | PBX API는 `X-Api-Key` 헤더 인증만 허용해야 한다. JWT/세션 폴백 없음. | P0 | 보안 테스트 |
| FR-003-02 | 시스템은 Hermes로부터 통화 이벤트(연결/종료/부재) Callback을 수신하고 처리해야 한다. | P0 | 통합 테스트 |
| FR-003-03 | Hermes Callback 수신 시 `tb_call_result`의 상태를 정확히 갱신해야 한다. (call_connected → on, call_ended → closed/under30, call_missed → miss) | P0 | 통합 테스트 |
| FR-003-04 | PBX API Endpoint는 CSRF 검증을 면제해야 한다 (서버-서버 통신). EXCLUDED_PATHS에 명시적 등록 필수. | P0 | 보안 테스트 |
| FR-003-05 | PbxService는 Hermes API 호출 실패 시 재시도를 수행해야 한다 (최대 3회). 최종 실패 시 `PbxConnectionException` 발생. | P1 | 단위 테스트 |
| FR-003-06 | `checkLive()` 메서드로 Hermes 시스템 상태를 헬스체크해야 한다. | P2 | 단위 테스트 |
| FR-003-07 | `coinInfo()` 메서드로 Hermes에서 통화 과금 정보를 조회해야 한다. | P1 | 단위 테스트 |

---

#### FR-004: 상담사 대시보드 (Callee Dashboard)

**관련 SyRS**: SyRS-006
**관련 서비스**: `CalleeActivityService::getActivityData()`

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-004-01 | 상담사는 오늘/이번 주/이번 달 통화 건수와 총 통화 시간(초)을 조회할 수 있어야 한다. | P0 | 통합 테스트 |
| FR-004-02 | 상담사는 자신의 수익(코인 환산) 현황을 기간별로 조회할 수 있어야 한다. | P0 | 통합 테스트 |
| FR-004-03 | 대시보드 데이터는 60초 이내 최신 데이터를 반영해야 한다. | P1 | 성능 테스트 |
| FR-004-04 | 상담사는 통화 이력을 페이지네이션(CI4 `paginate()`)으로 조회할 수 있어야 한다. 응답: `{ data, meta: { currentPage, perPage, total, lastPage } }` | P1 | 통합 테스트 |
| FR-004-05 | 대시보드 접근은 `role:callee` 라우트 필터로 보호되어야 한다. | P0 | 보안 테스트 |

---

#### FR-005: 상담사 알람 (Callee Alarm)

**관련 서비스**: `CalleeManageService::callCloseAlarm()`
**관련 테이블**: `tb_alarm`

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-005-01 | 시스템은 통화 요청 시 FCM을 통해 상담사에게 `call_request` Push 알림을 발송해야 한다. | P0 | 통합 테스트 |
| FR-005-02 | 상담사는 알람 수신 여부(통화/이벤트/시스템)를 설정할 수 있어야 한다. | P1 | 단위 테스트 |
| FR-005-03 | 알람 발송 이력은 `tb_alarm` 테이블에 저장되어야 한다. | P1 | 통합 테스트 |
| FR-005-04 | 상담사는 알람 목록을 페이지네이션으로 조회하고 읽음 처리를 할 수 있어야 한다. | P2 | 통합 테스트 |
| FR-005-05 | FCM 토큰 만료 시 자동으로 토큰을 갱신해야 한다. `updateFcmToken()` 호출. | P1 | 단위 테스트 |

---

#### FR-006: 즐겨찾기 (Favorites)

**관련 Repository**: `CalleeRepository` (addFavorite, removeFavorite, getFavorites)

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-006-01 | Caller는 상담사를 즐겨찾기에 추가할 수 있어야 한다. 중복 추가 시 HTTP 409 / CONFLICT 반환. | P1 | 단위 테스트 |
| FR-006-02 | Caller는 즐겨찾기에 추가한 상담사를 삭제할 수 있어야 한다. 소유권 검증(caller_ac_id) 필수. | P1 | 단위 테스트 |
| FR-006-03 | Caller는 즐겨찾기 목록을 페이지네이션으로 조회할 수 있어야 한다. | P1 | 통합 테스트 |
| FR-006-04 | 즐겨찾기 목록에는 상담사의 현재 온라인 상태가 포함되어야 한다. | P2 | 통합 테스트 |

---

#### FR-007: 컨텐츠 관리 (Content Management)

**관련 테이블**: `tb_posting`, `tb_comment`

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-007-01 | 상담사는 자신의 게시물을 작성·수정·삭제할 수 있어야 한다. | P1 | 통합 테스트 |
| FR-007-02 | 상담사는 자신의 게시물에 달린 댓글을 관리(삭제)할 수 있어야 한다. | P2 | 단위 테스트 |
| FR-007-03 | 컨텐츠 CRUD API는 `role:callee` 필터로 보호되어야 한다. | P0 | 보안 테스트 |
| FR-007-04 | 파일 업로드 시 MIME 타입 이중 검증(확장자 + `mime_content_type()`)을 수행해야 한다. | P0 | 보안 테스트 |
| FR-007-05 | 게시물 수정·삭제 시 소유권 검증(callee_ac_id) 필수. 타인 게시물 조작 시 HTTP 403 / FORBIDDEN. | P0 | 보안 테스트 |

---

#### FR-008: 채팅 및 견적 (Chat and Estimate)

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-008-01 | Caller는 상담사에게 견적(estimate)을 요청할 수 있어야 한다. | P1 | 통합 테스트 |
| FR-008-02 | 상담사는 견적 요청에 승인/거절로 응답할 수 있어야 한다. | P1 | 단위 테스트 |
| FR-008-03 | 채팅 내역은 페이지네이션으로 조회 가능해야 한다. | P1 | 통합 테스트 |
| FR-008-04 | 상담사 전용 채팅 API는 `role:callee` 필터로 보호해야 한다. | P0 | 보안 테스트 |
| FR-008-05 | 견적 상태 변경(승인/거절) 시 FCM 알림을 발송해야 한다. | P2 | 통합 테스트 |

---

#### FR-009: 포인트(코인) 관리 (Coin Management)

**관련 테이블**: `tb_coin`, `tb_items`

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-009-01 | 시스템은 통화 종료 시 코인 차감 내역을 `tb_coin` 테이블에 원자적으로 기록해야 한다. | P0 | 통합 테스트 |
| FR-009-02 | 코인 차감은 DB unique 제약 `(caller_ac_id, ref_type, ref_id)`으로 중복 차감을 방지해야 한다. | P0 | 단위 테스트 |
| FR-009-03 | Caller는 코인 충전·차감 내역을 페이지네이션으로 조회할 수 있어야 한다. | P1 | 통합 테스트 |
| FR-009-04 | 이벤트(Payback, Special Price, Roulette, First-call Coupon)에 의한 코인 지급은 Outbox를 통해 비동기 발행되어야 한다. | P1 | 단위 테스트 |

---

#### FR-010: 060 전화 연동 (060 Phone Integration)

| 요구사항 ID | 요구사항 설명 | 우선순위 | 검증 방법 |
|------------|------------|:-------:|---------|
| FR-010-01 | 시스템은 060 번호를 통한 인바운드 콜을 Hermes PBX로부터 수신해야 한다. | P0 | 통합 테스트 |
| FR-010-02 | 060 통화 요금은 Hermes `coinInfo` 데이터를 기반으로 정산해야 한다. | P0 | 통합 테스트 |
| FR-010-03 | 060 연동 Endpoint는 API Key 인증 전용으로 운영해야 한다. | P0 | 보안 테스트 |
| FR-010-04 | 060 통화 기록은 `tb_call_result`에 일반 통화와 동일한 구조로 저장해야 한다. | P1 | 통합 테스트 |

---

### 5.2 비기능 요구사항 (Non-Functional Requirements)

#### 5.2.1 성능 요구사항

| NFR ID | 요구사항 설명 | 측정 기준 | 관련 SyRS |
|--------|------------|---------|---------|
| NFR-001 | Call API P99 응답시간 < 500ms | DB 조회 포함 P99 측정 | SyRS-010 |
| NFR-002 | 정산 처리 시간 < 1,000ms | 통화 종료 후 DB 반영까지 P99 | SyRS-013 |
| NFR-003 | Hermes API 타임아웃: 연결 3초, 응답 10초 | cURL 타임아웃 설정 | SyRS-011 |
| NFR-004 | 대시보드 데이터 신선도 ≤ 60초 | 마지막 갱신 후 데이터 유효 시간 | SyRS-014 |

#### 5.2.2 정확성 요구사항

| NFR ID | 요구사항 설명 | 측정 기준 |
|--------|------------|---------|
| NFR-010 | 코인 차감 정확도 99.99% 이상 | COIN_TERM 단위 차감 오류율 < 0.01% |
| NFR-011 | 멱등성 보장 — 동일 통화에 대한 중복 정산 불허 | DB unique 제약 + 멱등키 기반 |
| NFR-012 | 상담사 상태 갱신 지연 < 5초 (P95) | 상태 변경 후 조회까지 P95 < 5,000ms |

#### 5.2.3 가용성 요구사항

| NFR ID | 요구사항 설명 |
|--------|------------|
| NFR-020 | 시스템 가용성 99.9% 이상 (월간 기준) |
| NFR-021 | FCM Push 알림 발송 지연 < 3초 (P99) |

#### 5.2.4 보안 요구사항

| NFR ID | 요구사항 설명 | 관련 표준 |
|--------|------------|---------|
| NFR-030 | Callee API 전 Endpoint에 `role:callee` 필터 적용 | OWASP API5:2023 |
| NFR-031 | PBX API는 `X-Api-Key` 인증 전용. JWT/세션 폴백 금지. | — |
| NFR-032 | CSRF 면제 Endpoint(PBX Webhook)는 EXCLUDED_PATHS에 명시적 등록 | — |
| NFR-033 | 파일 업로드 MIME 타입 이중 검증(확장자 + `mime_content_type()`) | OWASP A04:2021 |

---

## 6. 데이터 딕셔너리 (Data Dictionary)

IEEE 29148:2018 §5.2.4 기준

### 6.1 핵심 엔터티

#### 6.1.1 통화 기록 (Call Result)

| 속성명 (DB) | 속성명 (API) | 타입 | 제약 | 설명 |
|-----------|-----------|------|------|------|
| `cr_code` | `callId` | BIGINT (PK) | NOT NULL, AUTO_INCREMENT | 통화 기록 고유 ID |
| `caller_ac_id` | `callerId` | INT | NOT NULL, FK→tb_account | Caller 계정 ID |
| `callee_ac_id` | `calleeId` | INT | NOT NULL, FK→tb_account | Callee 계정 ID |
| `callee_ce_code` | `calleeCeCode` | VARCHAR(50) | NOT NULL | 상담사 코드 |
| `status` | `status` | ENUM | NOT NULL, DEFAULT='insert' | 'insert'\|'on'\|'closed'\|'miss'\|'under30' |
| `pbx_call_id` | `pbxCallId` | VARCHAR(100) | NULL | Hermes PBX 통화 ID |
| `call_number` | `callNumber` | VARCHAR(20) | NULL | 060 전화번호 |
| `start_time` | `startTime` | DATETIME | NULL | 통화 시작 시각 (UTC) |
| `end_time` | `endTime` | DATETIME | NULL | 통화 종료 시각 (UTC) |
| `duration_sec` | `durationSeconds` | INT | NULL | 실제 통화 시간(초) |
| `coin_deducted` | `coinDeducted` | INT | NOT NULL, DEFAULT=0 | 차감된 코인 |
| `coin_rate` | `coinRate` | INT | NOT NULL, DEFAULT=0 | 분당 코인 요금 (상담사별) |
| `idempotency_key` | — | VARCHAR(64) | UNIQUE | 멱등키 (중복 요청 방지) |
| `event_flags` | — | JSON | NULL | 이벤트 처리 플래그 |
| `close_reason` | — | VARCHAR(100) | NULL | miss/under30 시 종료 사유 |
| `created_at` | `createdAt` | DATETIME | NOT NULL, DEFAULT=CURRENT_TIMESTAMP | 생성일시 (UTC) |

#### 6.1.2 코인 내역 (Coin Record)

| 속성명 (DB) | 타입 | 제약 | 설명 |
|-----------|------|------|------|
| `coin_amount` | INT | NOT NULL | 차감/충전 코인 수 (차감은 음수) |
| `coin_type` | ENUM | NOT NULL | 'deduct'\|'charge'\|'event' |
| `ref_type` | VARCHAR | NOT NULL | 참조 유형 ('call', 'event' 등) |
| `ref_id` | BIGINT | NOT NULL | 참조 ID (call_id 등) |
| (unique) | — | UNIQUE(caller_ac_id, ref_type, ref_id) | 중복 차감 방지 제약 |

#### 6.1.3 통화 상태 Enum

| 상태 값 | 의미 | Terminal | 코인 차감 | Outbox 발행 |
|--------|------|:--------:|:--------:|:---------:|
| `insert` | 통화 레코드 생성됨 (연결 대기) | No | 없음 | 없음 |
| `on` | 통화 연결됨 (진행 중) | No | 없음 | 없음 |
| `closed` | 정상 종료 (30초 초과) | **Yes** | **있음** | **있음** |
| `miss` | 연결 실패 / 부재 | **Yes** | 없음 | 없음 |
| `under30` | 30초 이하 종료 | **Yes** | 없음 | 없음 |

### 6.2 도메인 상수

| 상수명 | 값 | 위치 | 설명 |
|-------|:--:|------|------|
| `COIN_TERM` | `30` | `CallCloseService::COIN_TERM` | 코인 차감 주기 (초) |
| `FREE_DURATION` | `30` | `CallCloseService::FREE_DURATION` | 무료 통화 구간 (초) |
| `CALL_MIN_COIN` | `5000` | `CallConnectionService::CALL_MIN_COIN` | 통화 가능 최소 코인 |

### 6.3 이벤트 유형

| 이벤트 유형 | Outbox event_type | 발행 조건 | 구독 모듈 |
|----------|-----------------|---------|---------|
| 통화 종료 | `call.closed` | status → 'closed' | Coin, Member, Analytics |
| 코인 환급 | `call.payback` | Payback 조건 충족 시 | Coin |
| 특별 할인 | `call.special_price` | 특별 요금 통화 종료 시 | Coin, Analytics |
| 룰렛 보너스 | `call.roulette` | 룰렛 이벤트 조건 충족 시 | Coin, Member |
| 첫 통화 쿠폰 | `call.first_coupon` | Caller 첫 번째 Closed 통화 | Coin, Member |

---

## 7. 외부 인터페이스 요구사항 (External Interface Requirements)

IEEE 29148:2018 §5.2.5 기준

### 7.1 사용자 인터페이스 요구사항

- **응답 포맷**: HTTP JSON. 성공: `{ "data": {...} }`, 에러: `{ "error": { "code", "message" } }`
- **키 네이밍**: DB `snake_case` → API 응답 `camelCase` 변환 필수 (Entity/VO에서 일괄 처리)
- **페이지네이션**: `{ "data": [], "meta": { "currentPage", "perPage", "total", "lastPage" } }`
- **날짜 포맷**: ISO 8601 (`2026-04-15T10:00:00Z`). 항상 UTC.

### 7.2 하드웨어 인터페이스 요구사항

해당 없음. 클라우드 기반 서버리스 아키텍처.

### 7.3 소프트웨어 인터페이스 요구사항

| 외부 시스템 | 인터페이스 유형 | 프로토콜 | 인증 |
|----------|-------------|---------|------|
| Hermes PBX | REST API (발신) | HTTP | `X-Hermes-Api-Key` 헤더 |
| Hermes PBX | Webhook (수신) | HTTP | `X-Api-Key` 헤더 검증 |
| FCM | HTTP v1 API | HTTPS | Service Account JSON |
| Aurora MySQL | JDBC-compatible | MySQL Protocol | RDS Proxy IAM Auth |
| Lambda/Cron | Outbox Polling | — | IAM Role |

### 7.4 통신 인터페이스 요구사항

| 요구사항 ID | 요구사항 설명 |
|----------|------------|
| EIF-001 | Hermes API 기본 URL: `http://hermes.peoplev.co.kr`. 타임아웃: 연결 3초, 응답 10초. |
| EIF-002 | 모든 클라이언트 요청에 `X-Forwarded-Proto: https` 헤더 필수. |
| EIF-003 | FCM 발송 실패는 비즈니스 로직에 영향 없음. 로깅만 수행. |
| EIF-004 | Outbox 이벤트 폴링 주기: Lambda/Cron 설정 의존 (Call 모듈 비관여). |

---

## 8. 검증 매트릭스 (Verification Matrix)

IEEE 29148:2018 §5.2.9 기준

### 8.1 기능 요구사항 검증 매트릭스

| 요구사항 ID | 설명 요약 | 검증 방법 | 담당 컴포넌트 | 상태 |
|------------|---------|---------|------------|:---:|
| FR-001-01 | 코인 잔액 ≥ CALL_MIN_COIN 검증 | 단위 테스트 | CallConnectionService | — |
| FR-001-02 | Callee 상태 확인 | 단위 테스트 | CallConnectionService | — |
| FR-001-03 | tb_call_result Insert 원자성 | 통합 테스트 | CallRepository | — |
| FR-001-04 | Hermes 060 연결 트리거 | 통합 테스트 | PbxService | — |
| FR-001-05 | 연결 성공 → status=on | 통합 테스트 | CallConnectionService | — |
| FR-001-06 | 연결 실패 → status=miss | 단위 테스트 | CallConnectionService | — |
| FR-001-07 | 멱등키 중복 방지 | 단위 테스트 | CallRepository | — |
| FR-002-01 | 통화 시간(초) 기록 | 단위 테스트 | CallCloseService | — |
| FR-002-02 | ≤30초 → under30 (코인 없음) | 단위 테스트 | CallCloseService | — |
| FR-002-03 | >30초 COIN_TERM 단위 차감 | 단위 테스트 | CallCloseService | — |
| FR-002-04 | 트랜잭션 원자성 (차감+Outbox+상태) | 통합 테스트 | CallCloseRepository | — |
| FR-002-07 | 이벤트 Outbox INSERT | 단위 테스트 | CallCloseService | — |
| FR-003-01 | PBX API Key 전용 인증 | 보안 테스트 | ApiKeyFilter | — |
| FR-003-02 | Hermes Callback 수신 처리 | 통합 테스트 | PbxController | — |
| FR-003-04 | PBX CSRF 면제 | 보안 테스트 | EXCLUDED_PATHS | — |
| FR-004-05 | 대시보드 role:callee 보호 | 보안 테스트 | RoleFilter | — |
| FR-007-04 | 파일 MIME 이중 검증 | 보안 테스트 | CalleeController | — |
| FR-009-02 | 코인 중복 차감 방지 unique | 단위 테스트 | CallCloseRepository | — |

### 8.2 비기능 요구사항 검증 매트릭스

| NFR ID | 요구사항 요약 | 검증 방법 | 측정 도구 | 상태 |
|--------|------------|---------|---------|:---:|
| NFR-001 | Call API P99 < 500ms | 성능 테스트 | AWS CloudWatch / k6 | — |
| NFR-010 | 코인 정확도 99.99% | 단위 테스트 | PHPUnit | — |
| NFR-011 | 멱등성 (중복 정산 불허) | 단위 테스트 | PHPUnit | — |
| NFR-012 | 상태 갱신 지연 < 5초 (P95) | 성능 테스트 | 부하 테스트 도구 | — |
| NFR-030 | role:callee 전 EP 적용 | 보안 감사 | Routes.php 검토 | — |

### 8.3 보안 검증 체크리스트

| 항목 | 검증 방법 | 상태 |
|------|---------|:---:|
| Callee API 39개 EP 모두 `['filter' => 'role:callee']` 적용 | Routes.php 전수 검사 | — |
| PBX Webhook CSRF 면제 (EXCLUDED_PATHS 등록) | 필터 체인 검토 | — |
| FCM Token 만료 처리 로직 구현 | 단위 테스트 | — |
| CALL_MIN_COIN 검증 로직 구현 | 단위 테스트 | — |
| 멱등키 기반 중복 통화 방지 | 통합 테스트 | — |
| Repository 소유권 조건 (calleeId, callerId) 내장 | 코드 리뷰 | — |

---

## 9. 타당성 검토 (Feasibility Review)

IEEE 29148:2018 §5.2.10 기준

### 9.1 기술 타당성

**Modular Monolith 아키텍처 적합성**:
- Call 도메인은 Coin, Member, PBX와 강결합 관계이나, Outbox 패턴을 통해 이벤트 기반 분리를 달성하여 모듈 경계를 명확히 한다.
- Hermes PBX가 내부 인프라(`peoplev.co.kr`)이므로 HTTP 통신으로 레이턴시 최소화 가능.
- 근거: CQRS 패턴(집계 쿼리 분리)과 Outbox 패턴(원자적 이벤트 발행)은 업계 표준 아키텍처 패턴으로 CodeIgniter 4 환경에서 검증 가능.

**COIN_TERM=30초 정산 근거**:
- 통화 업계 표준 과금 단위(30초)를 채택.
- 사용자 체감 과금 단위와 일치하여 UX와 비즈니스 요구사항을 동시 충족.
- 산술 오버플로우 위험 없음: PHP int 범위 내 처리 가능 (최대 통화 시간 수 시간 가정).

**멱등성 설계 근거**:
- 네트워크 재시도, Hermes Callback 중복 수신 등의 엣지 케이스 대응.
- DB unique 제약이 애플리케이션 레벨 멱등키의 최후 방어선 역할.
- 근거: OWASP API4:2023 (Unrestricted Resource Consumption) 및 데이터 무결성 보장.

### 9.2 외부 시스템 연동 타당성

**Hermes PBX**:
- 내부 인프라(`peoplev.co.kr`) 시스템으로 SLA 협의 가능.
- 리스크: HTTP(비암호화) 통신. 프로덕션 환경에서 VPC 내부 통신으로 보호됨.
- 대응: PbxConnectionException + 재시도 로직 (최대 3회). 최종 실패 시 Miss 처리 폴백.

**FCM**:
- Google Firebase 무료 티어 한도(메시지 수 제한 없음, 단 대용량 발송 시 속도 제한 가능).
- FCM 발송 실패는 비즈니스 로직에 영향 없음 (로깅만 수행). 알림 손실 허용.
- 리스크: FCM 토큰 만료 시 알림 누락. 대응: `updateFcmToken()` API를 통한 토큰 갱신.

### 9.3 변경 영향 분석

**변경되는 사항**: v1.0 단순 요구사항 목록 → v2.0 IEEE 29148:2018 완전 준수 문서
**개선점**:
- 이해관계자 요구사항(StRS) → 시스템 요구사항(SyRS) → 소프트웨어 요구사항(SwRS) 계층적 추적 가능
- 데이터 딕셔너리 추가로 DB 컬럼 ↔ API 필드 ↔ 도메인 개념 매핑 명확화
- 검증 매트릭스 추가로 테스트 커버리지 추적 가능
**수행 이유**: IEEE 표준 준수로 유지보수성·감사 가능성 향상. 외부 감사 및 팀 온보딩 효율화.

---

## 10. 변경 이력 (Change History)

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|---------|-------|
| v1.0 | 2026-04-15 | 최초 작성 — FR-001~FR-010, NFR, Use Cases, 체크리스트 포함 | jypark |
| v2.0 | 2026-04-15 | IEEE 표준 전면 전환. 3-Round Review PASS. IEEE 29148:2018 적용. StRS/SyRS/SwRS 3계층 구조 신설. 데이터 딕셔너리, 외부 인터페이스 요구사항, 검증 매트릭스 추가. 타당성 검토 섹션 강화. | jypark |
