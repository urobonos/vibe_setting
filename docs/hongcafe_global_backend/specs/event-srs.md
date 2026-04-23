---
문서명: Event Module — Software Requirements Specification
문서 ID: SRS-EVENT-001
버전: v2.0
적용 표준: IEEE 29148:2018
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: HongCafe Global Backend — Event Module
관련 문서:
  - event-sdd.md (SDD-EVENT-001)
  - event-idd.md (IDD-EVENT-001)
  - docs/api-specification.md
---

# Event Module — Software Requirements Specification (SRS)

> IEEE 29148:2018 준수 | version: 2.0 | lastUpdated: 2026-04-15 | module: Event

---

## 1. Introduction (소개)

### 1.1 Purpose (목적)

본 문서는 HongCafe Global Backend Event 모듈의 소프트웨어 요구사항을 IEEE 29148:2018 표준에 따라 정의한다. Event 모듈은 이벤트 목록 조회, 키워드/쿠폰/출석/코인충전 이벤트 참여, 갱신 쿠폰 발급, 룰렛 이벤트 처리 등 7개 핵심 기능을 제공하며, 총 10개 엔드포인트를 포함한다.

This document defines software requirements for the Event module of the HongCafe Global Backend per IEEE 29148:2018. The Event module covers 7 functional areas across 10 endpoints including event list queries, reward-based event participation, roulette mechanics with VIP-grade probability weighting, and idempotent charge event handling.

### 1.2 Scope (범위)

- **모듈 경로**: `app/Modules/Event/`
- **Controllers**: `EventController` (332 lines), `RouletteController` (65 lines)
- **Services**: `EventRewardService` (563 lines, 7 GRADE_THRESHOLDS tiers), `RouletteService` (254 lines, VIP A-E 5 segments)
- **Repositories**: `EventRepository`, `RouletteRepository`
- **Constants**: `RENEWAL_COUPON_CODES`, `RENEWAL_EVENT_ID`
- **엔드포인트 수**: 10개
- **대상 사용자**: 인증된 회원 (Caller), 상담사 (Callee) 일부 포함
- **범위 외**: 이벤트 관리 어드민 기능, 보상 실물 배송 처리

### 1.3 Definitions, Acronyms, and Abbreviations (정의 및 약어)

| 용어 / Term | 정의 / Definition |
|------------|-----------------|
| FR | Functional Requirement (기능 요구사항) |
| NFR | Non-Functional Requirement (비기능 요구사항) |
| BC | Bounded Context |
| EP | Endpoint |
| VIP 등급 | A~E 5단계 등급 체계 (RouletteService 기준) |
| 룰렛 세그먼트 | 룰렛 회전 결과 구역 (5개 고정 세그먼트: 꽝/코인소량/코인중량/쿠폰/대박) |
| 멱등키 | Idempotency Key — 중복 요청 방지 고유 식별자 |
| GRADE_THRESHOLDS | 코인 충전 이벤트 보상 7 티어 상수 (EventRewardService 내 정의) |
| RENEWAL_COUPON_CODES | 갱신 쿠폰 코드 집합 상수 |
| RENEWAL_EVENT_ID | 갱신 이벤트 식별자 상수 |
| DB unique 제약 | DB 레벨 유니크 제약 — race condition 시에도 중복 방지 보장 |
| UTC | Coordinated Universal Time — DB/서버 기준 타임존 |
| camelCase | API 응답 필드 네이밍 컨벤션 |
| p95 | 95번째 백분위수 응답 시간 |

### 1.4 References (참조 문서)

| 문서 | 위치 |
|------|------|
| IEEE 29148:2018 — Systems and software engineering — Life cycle processes — Requirements engineering | 표준 |
| event-sdd.md (SDD-EVENT-001 v2.0) | `docs/specs/` |
| event-idd.md (IDD-EVENT-001 v2.0) | `docs/specs/` |
| docs/api-specification.md | `docs/` |
| OWASP Top 10 A07:2021 — Identification and Authentication Failures | https://owasp.org/Top10/A07_2021/ |
| PHP Manual — random_int() | https://www.php.net/manual/en/function.random-int.php |
| CLAUDE.md — 보안 정책, 멱등성 항목 | 프로젝트 루트 |

### 1.5 Overview (문서 구조)

- 섹션 2: 전체 설명 — 이해관계자, 제약사항, 가정 및 의존성
- 섹션 3: 기능 요구사항 (FR-EVT-001~007) + 검증 방법
- 섹션 4: 비기능 요구사항 (NFR-EVT-001~005) + 정량 기준
- 섹션 5: 외부 인터페이스 요구사항
- 섹션 6: 유스케이스 (4건)
- 섹션 7: 요구사항 검증 매트릭스
- 섹션 8: 데이터 사전
- 섹션 9: 타당성 검토
- 섹션 10: 변경 영향 기록
- 섹션 11: 검토 체크리스트
- 섹션 12: 변경 로그

---

## 2. Overall Description (전체 설명)

### 2.1 Product Perspective (제품 관점)

Event 모듈은 HongCafe Global Backend Modular Monolith의 독립 Bounded Context이다. Shared 모듈의 `CoinServiceInterface` / `CouponServiceInterface`를 DI로 주입받아 보상을 지급하며, 모든 이벤트 참여는 단일 트랜잭션 내에서 원자적으로 처리된다. 룰렛 확률은 서버 측 `random_int()`(CSPRNG)로만 계산하며 클라이언트 입력으로 결정하지 않는다.

### 2.2 Stakeholders (이해관계자)

| 역할 | 관심사 |
|------|--------|
| 사용자 (Caller) | 이벤트 참여, 보상 수령, 룰렛 스핀 |
| 상담사 (Callee) | 일부 이벤트 참여 (VIP 등급 연동) |
| 운영팀 | 보상 한도 제어, 이벤트 기간 설정, 감사 로그 |
| 재무팀 | 코인 충전 이벤트 멱등성 (중복 보상 방지) |
| 보안팀 | 룰렛 확률 조작 방지, CSRF/JWT 검증 |
| 개발팀 | 트랜잭션 원자성, 단위 테스트 커버리지 |

### 2.3 Product Functions Summary (기능 요약)

| 기능 그룹 | EP 수 | 핵심 특성 |
|----------|------|---------|
| 이벤트 목록 조회 | 1 | 활성 이벤트, JWT 필수 |
| 이벤트 참여 이력 조회 | 1 | JWT 필수 |
| 키워드 이벤트 | 1 | case-insensitive, DB unique 제약, 트랜잭션 |
| 쿠폰 이벤트 | 1 | 1회 사용, 만료 검증, DateTimeImmutable |
| 출석 이벤트 | 1 | 연속 출석일 추적, UTC 기준 일일 1회 |
| 코인 충전 이벤트 | 1 | 7 tier GRADE_THRESHOLDS, 멱등키 필수 |
| 갱신 쿠폰 발급 | 1 | RENEWAL_COUPON_CODES, 만료일 30일 |
| 룰렛 스핀 | 1 | VIP A~E 5 segments, CSPRNG random_int() |
| 룰렛 이력/정보 | 2 | JWT 필수 |

### 2.4 Constraints (제약사항)

- 모든 이벤트 참여 EP는 JWT 인증 필수 (`hc_access` 쿠키)
- 상태 변경 POST EP는 CSRF 토큰 (`X-CSRF-TOKEN`) 검증 필수
- 룰렛 확률: 클라이언트 입력값으로 결정 금지 — 서버 측 `random_int()` (CSPRNG) 전용
- 코인 충전 이벤트: 멱등키 필수 (외부 결제 시스템 중복 콜백 대비)
- `declare(strict_types=1)` 모든 PHP 파일 필수
- `DateTimeImmutable` 강제 — `date()`, `time()` 사용 금지
- VIP 확률 가중치 `VIP_PROBABILITIES` 상수 — 런타임 변경 불가 (배포 필요)

### 2.5 Assumptions and Dependencies (가정 및 의존성)

| 항목 | 내용 |
|------|------|
| 가정 | 모든 날짜/시간은 UTC 기준. 사용자 표시는 프론트엔드에서 로컬 변환 |
| 가정 | VIP 등급은 `tb_account.vip_grade` 컬럼에 저장되며, RouletteRepository가 조회 |
| 가정 | GRADE_THRESHOLDS 7 티어 임계값은 코드 상수로 관리 (DB 저장 없음) |
| 의존성 | Shared/CoinServiceInterface — 코인 보상 지급 |
| 의존성 | Shared/CouponServiceInterface — 쿠폰 보상 지급 |
| 의존성 | PHP 8.4+ `random_int()` (CSPRNG) |
| 의존성 | Aurora MySQL DB unique 제약 — 중복 참여 방지 최종 보루 |

---

## 3. Functional Requirements (기능 요구사항)

### FR-EVT-001: 이벤트 목록 조회

**ID**: FR-EVT-001 | **우선순위**: P1 필수 | **출처**: API Specification §Event

#### 요구사항 세부 사항

- 인증된 사용자(Caller/Callee)만 이벤트 목록 조회 가능 (JWT 필수)
- 응답: 이벤트 ID, 이벤트명, 이벤트 유형, 시작일, 종료일, 상태
- 종료된 이벤트는 목록에서 제외 (현재 날짜 기준 자동 필터)
- 정렬: 시작일 기준 내림차순

#### 관련 API

| HTTP | 경로 | 인증 | CSRF |
|------|------|------|------|
| GET | `/api/events` | JWT | 면제 |

#### 검증 방법 (Verification Method)

- **시험 (Test)**: JWT 없이 GET `/api/events` 요청 → HTTP 401 `UNAUTHORIZED` 반환 확인
- **시험 (Test)**: 종료된 이벤트가 응답 목록에 미포함됨 확인
- **검사 (Inspection)**: `EventRepository::findActiveEvents()` 쿼리에 날짜 조건 존재 확인

---

### FR-EVT-002: 키워드 이벤트 참여

**ID**: FR-EVT-002 | **우선순위**: P1 필수 | **출처**: API Specification §Event/keyword

#### 요구사항 세부 사항

- 유효한 키워드 제출 시 보상(코인 또는 쿠폰) 지급
- 동일 사용자 + 동일 키워드 중복 참여 불가 (DB unique 제약)
- 이벤트 기간 외 키워드 제출 거부
- 키워드 대소문자 구분 없이 검증 (case-insensitive)
- 보상 지급 실패 시 트랜잭션 롤백 처리 (이력 포함 원자적 롤백)

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `eventId` | required, integer, greater_than[0] |
| `keyword` | required, string, min_length[1], max_length[100] |

#### 관련 API

| HTTP | 경로 | 인증 | CSRF |
|------|------|------|------|
| POST | `/api/events/keyword` | JWT | 필수 |

#### 응답 / 에러

```
200: { "data": { "rewardType": "coin|coupon", "rewardAmount": int, "couponCode": string|null } }
409: { "error": { "code": "CONFLICT", "message": "이미 참여한 이벤트입니다." } }
400: { "error": { "code": "INVALID_INPUT", "message": "유효하지 않은 키워드입니다." } }
```

#### 검증 방법

- **시험**: 동일 keyword 재제출 → HTTP 409 `CONFLICT` 반환 확인
- **시험**: CSRF 토큰 없이 POST → HTTP 403 또는 419 반환 확인
- **검사**: `EventRepository::findParticipation()` DB unique 제약 존재 확인

---

### FR-EVT-003: 쿠폰 이벤트 참여

**ID**: FR-EVT-003 | **우선순위**: P1 필수 | **출처**: API Specification §Event/coupon

#### 요구사항 세부 사항

- 유효한 쿠폰 코드 제출 시 지정된 보상 지급
- 쿠폰 코드는 단 1회 사용 가능 — 사용 후 상태 `used`로 변경
- 쿠폰 유효 기간 검증 (DateTimeImmutable 사용)
- 만료된 쿠폰 → `EXPIRED_COUPON` (400) 반환
- 이미 사용된 쿠폰 → `CONFLICT` (409) 반환

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `eventId` | required, integer, greater_than[0] |
| `couponCode` | required, string, min_length[6], max_length[50] |

#### 관련 API

| HTTP | 경로 | 인증 | CSRF |
|------|------|------|------|
| POST | `/api/events/coupon` | JWT | 필수 |

#### 검증 방법

- **시험**: 만료된 쿠폰 코드 제출 → HTTP 400 `INVALID_INPUT` 반환 확인
- **시험**: 동일 쿠폰 코드 2회 제출 → 2번째 요청 HTTP 409 `CONFLICT` 반환 확인
- **검사**: 쿠폰 상태 업데이트 트랜잭션 내 보상 지급 원자성 확인

---

### FR-EVT-004: 출석 이벤트 처리

**ID**: FR-EVT-004 | **우선순위**: P1 필수 | **출처**: API Specification §Event/attendance

#### 요구사항 세부 사항

- 하루 1회 출석 체크 가능 (UTC 기준 00:00~23:59)
- 연속 출석일 수 추적 — 연속 기록 단절 시 1일부터 재시작
- `EventRewardService::processAttendance()` 연속 출석 보상 로직 적용
- 당일 출석 완료 상태에서 재시도 → `CONFLICT` (409) 반환

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `eventId` | required, integer, greater_than[0] |

#### 관련 API

| HTTP | 경로 | 인증 | CSRF |
|------|------|------|------|
| POST | `/api/events/attendance` | JWT | 필수 |

#### 검증 방법

- **시험**: 동일 날짜 2회 출석 체크 → 2번째 요청 HTTP 409 `CONFLICT` 확인
- **시험**: 연속 출석 3일 후 1일 누락 → `consecutiveDays` 값이 1로 초기화됨 확인
- **분석**: `getConsecutiveAttendanceDays()` — CTE 또는 Window Function 쿼리 정확성 검증

---

### FR-EVT-005: 코인 충전 이벤트 처리 (7-Tier)

**ID**: FR-EVT-005 | **우선순위**: P1 필수 | **출처**: API Specification §Event/charge

#### 요구사항 세부 사항

- `EventRewardService`의 `GRADE_THRESHOLDS` 7 티어 기반 보상 산정
- 충전 금액이 특정 구간(tier)을 초과하면 해당 구간의 보상 지급
- 동일 충전 트랜잭션 중복 보상 방지 — 멱등키(idempotency key) 필수
- 충전 이벤트 참여 이력 기록

#### GRADE_THRESHOLDS 7 Tiers

| Tier | min | max | 코인 | 쿠폰 |
|------|-----|-----|------|------|
| 1 | 1,000 | 4,999 | 50 | - |
| 2 | 5,000 | 9,999 | 150 | - |
| 3 | 10,000 | 29,999 | 300 | TIER3 |
| 4 | 30,000 | 49,999 | 500 | TIER4 |
| 5 | 50,000 | 99,999 | 1,000 | TIER5_PREMIUM |
| 6 | 100,000 | 199,999 | 2,000 | TIER6_VIP |
| 7 | 200,000 | PHP_INT_MAX | 5,000 | TIER7_SPECIAL |

#### 입력 검증 규칙

| 필드 | 규칙 |
|------|------|
| `eventId` | required, integer, greater_than[0] |
| `chargeAmount` | required, integer, greater_than[0] |
| `idempotencyKey` | required, string, min_length[16], max_length[128] |

#### 관련 API

| HTTP | 경로 | 인증 | CSRF |
|------|------|------|------|
| POST | `/api/events/charge` | JWT | 필수 |

#### 검증 방법

- **시험**: 동일 idempotencyKey 2회 제출 → 2번째 HTTP 409 반환 확인
- **시험**: chargeAmount=10000 → tier 3 보상(코인 300 + TIER3 쿠폰) 지급 확인
- **분석**: DB unique 제약 `(account_id, idempotency_key)` 인덱스 존재 확인

---

### FR-EVT-006: 갱신 쿠폰 발급

**ID**: FR-EVT-006 | **우선순위**: P2 중요 | **출처**: API Specification §Event/renewal-coupon

#### 요구사항 세부 사항

- 회원 등급, 활동 이력 등 갱신 조건 충족 여부 검증
- 이미 유효한 갱신 쿠폰 보유 시 추가 발급 거부 → `CONFLICT` (409)
- `RENEWAL_COUPON_CODES` 상수에서 코드 선택, `RENEWAL_EVENT_ID`로 이벤트 연결
- 발급 쿠폰에 만료일 설정 필수 (`DateTimeImmutable::modify('+30 days')`)

#### 관련 API

| HTTP | 경로 | 인증 | CSRF |
|------|------|------|------|
| POST | `/api/events/renewal-coupon` | JWT | 필수 |

#### 검증 방법

- **시험**: 유효 갱신 쿠폰 보유 상태에서 재발급 요청 → HTTP 409 `CONFLICT` 확인
- **시험**: 발급된 쿠폰의 `expiresAt` = 발급일 + 30일 확인
- **검사**: `RENEWAL_COUPON_CODES` 상수 존재 및 `issueRenewalCoupon()` 분기 확인

---

### FR-EVT-007: 룰렛 이벤트 처리 (VIP 등급 확률)

**ID**: FR-EVT-007 | **우선순위**: P1 필수 | **출처**: API Specification §Event/roulette

#### 요구사항 세부 사항

- VIP 등급(A~E)에 따라 룰렛 세그먼트별 확률 가중치 다르게 적용
- 룰렛 세그먼트 5개 고정: 꽝(0), 코인소량(50), 코인중량(200), 쿠폰(1), 대박(1000코인)
- `RouletteService::getWeightedRandomSegment()` — 누적 합산(cumulative sum) + `random_int()` CSPRNG
- 일일 룰렛 참여 횟수 제한 (이벤트 설정 기반)
- 룰렛 결과: 서버 측 확률 계산만 허용. 클라이언트 입력 값으로 결정 금지
- 룰렛 당첨 이력 DB 기록 (세그먼트 인덱스, VIP 등급, 확률 포함)

#### VIP 등급별 확률 가중치 (VIP_PROBABILITIES)

| VIP | 꽝(0) | 코인소량(1) | 코인중량(2) | 쿠폰(3) | 대박(4) | 합계 |
|-----|------|-----------|-----------|--------|--------|------|
| A | 10 | 30 | 30 | 20 | 10 | 100 |
| B | 20 | 30 | 25 | 15 | 10 | 100 |
| C | 30 | 30 | 20 | 15 | 5 | 100 |
| D | 40 | 30 | 15 | 10 | 5 | 100 |
| E | 50 | 30 | 10 | 8 | 2 | 100 |

#### 관련 API

| HTTP | 경로 | 인증 | CSRF |
|------|------|------|------|
| POST | `/api/events/roulette/spin` | JWT | 필수 |
| GET | `/api/events/roulette/history` | JWT | 면제 |
| GET | `/api/events/roulette/info` | JWT | 면제 |

#### 검증 방법

- **시험**: VIP A 등급 사용자 1000회 스핀 → 대박(세그먼트 4) 출현율 약 10% 근사값 확인 (통계적 검증)
- **시험**: 일일 참여 횟수 초과 시 HTTP 429 반환 확인
- **검사**: `getWeightedRandomSegment()` — 각 가중치 배열 합계 100 확인
- **검사**: `spin()` 내 클라이언트 입력값으로 세그먼트 인덱스 결정하는 로직 없음 확인

---

## 4. Non-Functional Requirements (비기능 요구사항)

### NFR-EVT-001: 중복 참여 방지 및 멱등성

**ID**: NFR-EVT-001 | **우선순위**: P1 필수  
**요구사항**: 모든 이벤트 참여 요청에 DB unique 제약으로 중복 방지. 동시 요청(race condition) 시에도 DB 레벨에서 유일성 보장. 코인 충전 이벤트는 멱등키 필수.  
**측정 기준**: 동일 키로 동시 100개 요청 → 1건만 성공, 99건 HTTP 409 반환 (시험, k6 동시 부하)

### NFR-EVT-002: 보상 한도 제어

**ID**: NFR-EVT-002 | **우선순위**: P1 필수  
**요구사항**: 사용자당 이벤트별 일일 보상 한도 초과 불가. 총 코인 보상 한도는 이벤트 설정에 따름. 한도 초과 시 보상 지급 중단.  
**측정 기준**: `EventRewardService` 한도 검증 로직 단위 테스트 — 한도 도달 시 보상 미지급 확인 (시험)

### NFR-EVT-003: 응답 성능

**ID**: NFR-EVT-003 | **우선순위**: P2 중요  
**요구사항**: 이벤트 목록 조회 200ms 이하 (p95). 이벤트 참여 처리 500ms 이하 (p95). 룰렛 확률 계산 50ms 이내 완료.  
**측정 기준**: 스테이징 환경 k6 부하 테스트 — 각 EP별 p95 임계값 이하 (시험)

### NFR-EVT-004: 보안 — 인증/확률 조작 방지

**ID**: NFR-EVT-004 | **우선순위**: P1 필수  
**요구사항**: 모든 이벤트 참여 EP JWT 인증 필수 (`hc_access` 쿠키). POST EP CSRF 토큰 필수. 룰렛 확률 조작 방지 — 클라이언트 입력값 사용 금지, `random_int()` CSPRNG 전용.  
**측정 기준**: 코드 리뷰 — `spin()` 내 `random_int()` 사용 + 클라이언트 파라미터 세그먼트 결정 코드 없음 확인 (검사, OWASP A07:2021)

### NFR-EVT-005: 감사 로그 보존

**ID**: NFR-EVT-005 | **우선순위**: P2 중요  
**요구사항**: 이벤트 참여 이력(참여일시, 사용자 ID, 이벤트 ID, 보상 내용) DB 영구 보존. 룰렛 당첨 이력 — 세그먼트 인덱스, VIP 등급, 확률값 포함 기록.  
**측정 기준**: 이벤트 참여 성공 후 `tb_event_participation` 레코드 존재 확인 (시험)

---

## 5. External Interface Requirements (외부 인터페이스 요구사항)

### 5.1 HTTP API Interface

| 항목 | 명세 |
|------|------|
| 프로토콜 | HTTPS (X-Forwarded-Proto: https 필수) |
| 인증 | `hc_access` 쿠키 (JWT) |
| CSRF | `X-CSRF-TOKEN` 헤더 (POST) |
| 응답 형식 | `application/json`, camelCase 키 |

### 5.2 Database Interface

| 항목 | 명세 |
|------|------|
| DBMS | Amazon Aurora MySQL 3.12.0 (MySQL 8.0.44 호환) |
| 주요 테이블 | `tb_event`, `tb_event_participation`, `tb_event_keyword`, `tb_roulette_history` |
| 트랜잭션 | 이벤트 참여 + 보상 지급 단일 트랜잭션 |

### 5.3 Internal Module Interface

| 의존 모듈 | 인터페이스 | 용도 |
|---------|---------|------|
| Shared/Coin | `CoinServiceInterface` | 코인 보상 지급 |
| Shared/Coupon | `CouponServiceInterface` | 쿠폰 보상 지급 |

---

## 6. Use Cases (유스케이스)

### UC-EVT-001: 사용자 이벤트 목록 조회

- **액터**: 인증된 회원 (Caller / Callee)
- **사전 조건**: JWT 인증 완료 (hc_access 쿠키 유효)
- **정상 흐름**:
  1. 사용자가 이벤트 목록 페이지 요청
  2. EventController → EventRepository::findActiveEvents() 조회
  3. 활성 이벤트 목록 JSON 반환
- **대안 흐름**: 활성 이벤트 없음 → 빈 배열 반환 (HTTP 200)
- **에러 흐름**: JWT 미인증 → HTTP 401
- **사후 조건**: 현재 활성 이벤트 목록이 사용자에게 표시됨

### UC-EVT-002: 키워드 이벤트 참여

- **액터**: 인증된 회원 (Caller)
- **사전 조건**: JWT 인증 완료, 이벤트 기간 내
- **정상 흐름**:
  1. 사용자가 키워드 입력 후 제출
  2. EventController 입력 검증
  3. `EventRewardService::validateAndRewardKeyword()` — 기간/유효성/중복 검증
  4. 트랜잭션 내: 참여 이력 기록 + 보상 지급
  5. 보상 정보 반환
- **대안 흐름**:
  - 중복 참여 → HTTP 409 `CONFLICT`
  - 유효하지 않은 키워드 → HTTP 400 `INVALID_INPUT`
- **사후 조건**: 보상이 사용자 계정에 지급되고 참여 이력이 기록됨

### UC-EVT-003: 룰렛 스핀

- **액터**: 인증된 회원 (Caller)
- **사전 조건**: JWT 인증 완료, 일일 참여 횟수 미초과
- **정상 흐름**:
  1. 사용자가 룰렛 스핀 요청
  2. `RouletteService::spin()` — VIP 등급 조회
  3. `VIP_PROBABILITIES[grade]` 가중치 배열 로드
  4. `getWeightedRandomSegment()` — 누적 합산 + `random_int()` → 세그먼트 인덱스 선택
  5. 트랜잭션 내: 당첨 이력 기록 + 보상 지급
  6. 결과 반환
- **대안 흐름**: 일일 참여 횟수 초과 → HTTP 429
- **사후 조건**: 룰렛 당첨 이력 기록 + 보상 지급

### UC-EVT-004: 출석 체크

- **액터**: 인증된 회원 (Caller)
- **사전 조건**: JWT 인증 완료, 당일 미출석
- **정상 흐름**:
  1. 사용자가 출석 체크 요청
  2. `EventRewardService::processAttendance()` — 당일 출석 여부 검증
  3. 연속 출석일 수 계산 (CTE 또는 Window Function)
  4. 연속일 기반 보상 산정
  5. 출석 기록 저장 + 보상 지급
  6. 결과 반환
- **대안 흐름**: 당일 출석 완료 → HTTP 409 `CONFLICT`
- **사후 조건**: 출석 기록과 보상 지급 완료

---

## 7. Requirements Verification Matrix (요구사항 검증 매트릭스)

| 요구사항 ID | 설명 | 검증 방법 | 검증 조건 | 추적 (SDD) |
|------------|------|---------|---------|----------|
| FR-EVT-001 | 이벤트 목록 조회 | 시험, 검사 | JWT 필수, 종료 이벤트 제외 | SDD §2.1 EventController |
| FR-EVT-002 | 키워드 이벤트 참여 | 시험, 검사 | DB unique 제약, 트랜잭션 | SDD §3.1 EventRewardService |
| FR-EVT-003 | 쿠폰 이벤트 참여 | 시험 | 1회 사용, 만료 검증 | SDD §3.1.2 |
| FR-EVT-004 | 출석 이벤트 처리 | 시험, 분석 | 연속일 추적, UTC 기준 | SDD §3.1.3 |
| FR-EVT-005 | 코인 충전 이벤트 (7 tier) | 시험, 분석 | 멱등키, GRADE_THRESHOLDS | SDD §3.1.4 |
| FR-EVT-006 | 갱신 쿠폰 발급 | 시험, 검사 | RENEWAL_COUPON_CODES, 만료일 | SDD §3.1.5 |
| FR-EVT-007 | 룰렛 이벤트 (VIP 확률) | 시험, 검사 | random_int() CSPRNG, 5 segments | SDD §3.2 RouletteService |
| NFR-EVT-001 | 중복 참여 방지 | 시험 (동시 부하) | 100 동시 요청 → 1 성공 | SDD ADR-EVT-002 |
| NFR-EVT-002 | 보상 한도 제어 | 시험 | 한도 초과 시 미지급 | SDD §3.1 |
| NFR-EVT-003 | 응답 성능 p95 | 시험 (k6) | 목록 200ms, 참여 500ms | SDD §4 Repository |
| NFR-EVT-004 | 보안/확률 조작 방지 | 검사 | random_int() + 클라이언트 입력 미사용 | SDD ADR-EVT-001 |
| NFR-EVT-005 | 감사 로그 | 시험 | 참여 성공 후 이력 레코드 존재 | SDD §4.1 EventRepository |

---

## 8. Data Dictionary (데이터 사전)

### 이벤트 참여 관련 테이블 (논리 구조)

| 테이블 | 목적 | 핵심 제약 |
|--------|------|---------|
| `tb_event` | 이벤트 마스터 | event_id PK, start_date, end_date |
| `tb_event_participation` | 참여 이력 | UNIQUE(account_id, event_id, keyword) |
| `tb_event_keyword` | 유효 키워드 목록 | event_id + keyword (case-insensitive) |
| `tb_roulette_history` | 룰렛 당첨 이력 | account_id, event_id, segment_index, vip_grade |

### GRADE_THRESHOLDS 상수 구조

```php
private const GRADE_THRESHOLDS = [
    1 => ['min' => 1000,   'max' => 4999,        'coin' => 50,   'coupon' => null],
    2 => ['min' => 5000,   'max' => 9999,        'coin' => 150,  'coupon' => null],
    3 => ['min' => 10000,  'max' => 29999,       'coin' => 300,  'coupon' => 'TIER3'],
    4 => ['min' => 30000,  'max' => 49999,       'coin' => 500,  'coupon' => 'TIER4'],
    5 => ['min' => 50000,  'max' => 99999,       'coin' => 1000, 'coupon' => 'TIER5_PREMIUM'],
    6 => ['min' => 100000, 'max' => 199999,      'coin' => 2000, 'coupon' => 'TIER6_VIP'],
    7 => ['min' => 200000, 'max' => PHP_INT_MAX, 'coin' => 5000, 'coupon' => 'TIER7_SPECIAL'],
];
```

### API 응답 camelCase 매핑

| DB 컬럼 (snake_case) | API 응답 키 (camelCase) |
|---------------------|----------------------|
| `event_id` | `eventId` |
| `event_name` | `eventName` |
| `event_type` | `eventType` |
| `start_date` | `startDate` |
| `end_date` | `endDate` |
| `reward_type` | `rewardType` |
| `reward_amount` | `rewardAmount` |
| `coupon_code` | `couponCode` |
| `consecutive_days` | `consecutiveDays` |
| `segment_index` | `segmentIndex` |
| `vip_grade` | `vipGrade` |
| `expires_at` | `expiresAt` |
| `created_at` | `createdAt` |

---

## 9. Feasibility Review (타당성 검토)

| 항목 | 근거 | 결론 |
|------|------|------|
| 룰렛 확률 계산 — PHP `random_int()` CSPRNG | PHP 공식 문서 — `random_int()`는 암호학적으로 안전한 의사 난수 생성기(CSPRNG)를 사용. `rand()`, `mt_rand()`와 달리 예측 불가. 룰렛 확률 조작 방지 필수 (OWASP A07:2021 — 불충분한 엔트로피). 클라이언트 입력값으로 세그먼트 결정 시 조작 가능하므로 서버 측 전용 처리 강제 | 채택. `random_int()` CSPRNG 서버 전용 사용. 클라이언트 입력 기반 결정 금지 |
| 멱등키 (코인 충전 이벤트) | CLAUDE.md — "정산/결제는 멱등키(idempotency key) 필수. 트랜잭션은 DB unique 제약으로 중복 방지". 결제 콜백 재시도, 네트워크 오류 시 동일 요청 중복 발생 가능. DB unique 제약(account_id, idempotency_key)으로 최종 방어 | 채택. 멱등키 + DB unique 제약 이중 방어. CLAUDE.md 지침 준수 |
| 이벤트 참여 트랜잭션 원자성 | 참여 이력 기록 성공 후 보상 지급 실패 시 데이터 불일치 발생. 트랜잭션으로 묶어 원자성 보장 — 롤백 시 이력도 함께 롤백. InnoDB 트랜잭션 지원(Aurora MySQL 확인) | 채택. 이벤트 참여 + 보상 지급 단일 트랜잭션 강제 |
| VIP 확률 가중치 하드코딩 | 확률값은 게임 설계 시점에 확정되며 런타임 중 변경 불필요. DB 저장 시 조회 오버헤드 + 확률값 무결성 검증 부담 증가. 변경 빈도 낮아 코드 상수(`VIP_PROBABILITIES`) 관리가 현실적. 변경 시 배포 필요 — 허용 가능한 트레이드오프 | 채택. VIP_PROBABILITIES 서비스 내 상수. 변경 시 배포 프로세스로 통제 |

---

## 10. Change Impact Log (변경 영향 기록)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| IEEE 29148:2018 표준 전면 전환 (v1.0 → v2.0) | Introduction 5섹션, Overall Description 5섹션 신설. FR별 검증 방법 추가. 요구사항 추적성 강화 | 프로젝트 지침 — IEEE 표준 전환 요구, 3-Round Review PASS |
| FR별 검증 방법(Verification Method) 추가 | Test/Inspection/Analysis 방법 + 구체적 조건 명시. QA 팀 검증 계획 수립 자동화 가능 | IEEE 29148:2018 §9.5.10 — FR별 검증 방법 의무 |
| NFR 정량 측정 기준 명시 | p95 응답 시간(목록 200ms, 참여 500ms, 룰렛 계산 50ms) 수치화. 성능 테스트 합격 기준 명확화 | 기존 NFR에 p95 기준 없어 성능 테스트 합격 판단 불가 |
| GRADE_THRESHOLDS 7 티어 테이블 신설 | 티어 임계값을 SRS에서 직접 확인 가능. 구현 시 상수값 오입력 방지 | 기존 SRS에 티어 수치 없어 구현자가 소스 코드 직접 확인 필요 |
| VIP 확률 가중치 테이블 신설 | A~E 5등급 × 5 세그먼트 확률 분포 명시. 통계적 검증 시나리오 도출 가능 | 기존 SRS에 확률 분포 없어 테스트 기대값 계산 불가 |

---

## 11. Review Checklist (검토 체크리스트)

### 완전성 (Completeness)
- [x] IEEE 29148:2018 — 1.1~1.5 Introduction 5섹션 완료
- [x] IEEE 29148:2018 — 2.1~2.5 Overall Description 5섹션 완료
- [x] FR 7건 (FR-EVT-001~007) + 검증 방법 포함
- [x] FR별 입력 검증 규칙 명시
- [x] NFR 5건 (NFR-EVT-001~005) + 정량 측정 기준
- [x] 외부 인터페이스 요구사항 (HTTP, DB, 내부 모듈)
- [x] 유스케이스 4건 (정상/대안/에러 흐름)
- [x] 요구사항 검증 매트릭스 (12건)
- [x] 데이터 사전 (GRADE_THRESHOLDS, VIP 확률, camelCase 매핑)
- [x] 타당성 검토 4건
- [x] 변경 영향 기록 5건

### 일관성 (Consistency)
- [x] FR-EVT-007 룰렛 확률 NFR-EVT-004 보안과 일관성 확보
- [x] 멱등키 요구 (FR-EVT-005) NFR-EVT-001과 일관성 확보
- [x] camelCase 컨벤션 일관 적용

### 검증 가능성 (Verifiability)
- [x] 각 FR 검증 방법 + 구체적 조건 명시
- [x] NFR 정량 수치 (p95, 동시 요청 100건 등)

### 추적성 (Traceability)
- [x] FR/NFR ↔ SDD 섹션 추적 (검증 매트릭스)
- [x] FR ↔ 유스케이스 매핑

---

## 12. Change Log (변경 로그)

| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-04-15 | 1.0.0 | 최초 작성 — Event Module SRS |
| 2026-04-15 | 2.0.0 | IEEE 표준 전면 전환. 3-Round Review PASS. Introduction 5섹션, Overall Description 5섹션, FR 검증 방법, NFR 정량 기준, GRADE_THRESHOLDS 테이블, VIP 확률 테이블, 검증 매트릭스, 데이터 사전, 타당성 검토 4건 추가 |
