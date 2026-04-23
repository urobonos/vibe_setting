# SDD: Lambda Pub/Sub 데이터 싱크

> SDD: Lambda Pub/Sub 데이터 싱크

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-08 |
| 유형 | SDD |
| 상태 | 승인됨 |

---

## 내용

## 1. 개요

### 1.1 목적

HongCafe Global 서비스의 국가 간(USA ↔ KOR ↔ JPN) account/coin 데이터를 비동기로 동기화한다.
발행(Pub) 측 백엔드가 SNS FIFO에 이벤트를 게시하면, 각 국가의 Lambda가 SQS를 통해 수신하여 Aurora DB에 반영한다.

### 1.2 범위

| 항목 | 내용 |
|------|------|
| 발행 소스 | CI4 Backend (PHP) — 미구현 |
| 메시징 | AWS SNS FIFO → SQS FIFO (크로스리전) |
| 소비자 | AWS Lambda (Python 3.12) |
| 데이터 저장소 | Aurora MySQL (RDS Proxy, IAM Auth) |
| 대상 데이터 | account/coin 이벤트 (account_create, account_update, coin_transfer, coin_adjust) |
| 트리거 | SQS FIFO → Lambda (이벤트 드리븐) |

### 1.3 리전

| 리전 | 역할 | 상태 |
|------|------|------|
| us-east-1 | USA 프로덕션 | **Active (코드 배포 완료)** |
| ap-northeast-2 | KOR 프로덕션 + SNS 허브 | SQS 연결됨, Lambda 스켈레톤 |
| ap-northeast-1 | JPN 프로덕션 | SQS 연결됨, Lambda 미생성 |

---

## 2. 아키텍처

### 2.1 전체 흐름 — Hub-and-Spoke 패턴

```
                          ┌──────────────────────────────────────┐
                          │   SNS FIFO (KOR: ap-northeast-2)     │
                          │   prod_sns_hongcafe_global.fifo      │
                          │   ContentBasedDedup=true, KMS 암호화  │
                          └──┬──────────┬──────────┬─────────────┘
                             │          │          │
                    subscribe│          │          │subscribe
                             ▼          ▼          ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ SQS FIFO (USA)  │  │ SQS FIFO (KOR)  │  │ SQS FIFO (JPN)  │
│ us-east-1       │  │ ap-northeast-2  │  │ ap-northeast-1  │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │ trigger            │ trigger            │ trigger
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Lambda (USA)    │  │ Lambda (KOR)    │  │ Lambda (JPN)    │
│ ✅ 배포됨       │  │ ⬜ 스켈레톤     │  │ ⬜ 미생성       │
└────────┬────────┘  └─────────────────┘  └─────────────────┘
         │
    ┌────┴────────────────────┐
    │ SQS Trigger             │
    │ parse_message()         │
    │ → 멱등성 체크 (pub_id)  │
    │ → route_event()         │
    │ → sub_status 갱신       │
    └─────────────────────────┘
```

### 2.2 SQS 트리거 패턴

Lambda 함수는 SQS FIFO 큐에서 메시지를 수신하여 즉시 처리한다. `batchItemFailures` 패턴으로 부분 실패를 보고한다.

```
┌──────────────────────────────────────────────────────────┐
│                  handler.py                               │
│                  handler(event, context)                   │
│                                                          │
│   for record in event["Records"]:                        │
│     ┌─────────────────────────────────────────┐          │
│     │ 1. parse_message(body)                  │          │
│     │    → pub_id, event_type, entity_id,     │          │
│     │      payload 필수 필드 검증             │          │
│     │                                         │          │
│     │ 2. process_sync(msg)                    │          │
│     │    → is_already_processed(pub_id)       │          │
│     │    → sub_status = 1 (처리중)            │          │
│     │    → route_event(event_type)            │          │
│     │    → sub_status = 3 (완료)              │          │
│     └─────────────────────────────────────────┘          │
│                                                          │
│   return {"batchItemFailures": [...]}                    │
└──────────────────────────────────────────────────────────┘
```

### 2.3 데이터 흐름 상세

```
① PHP Backend (국가 A)
   └─ SNS Publish (MessageGroupId: "KR:ACCOUNT:CREATE:7")

② SNS FIFO (KOR 중앙)
   └─ Fan-out → 3개 SQS (USA, KOR, JPN)

③ SQS → Lambda (SQS Trigger)
   └─ parse_message(): pub_id, event_type, entity_id, payload 파싱
   └─ is_already_processed(): pub_id 기반 멱등성 체크 (sub_status=3이면 SKIP)
   └─ sub_status = 1 (처리중 마킹)
   └─ route_event(): event_type별 핸들러 분기
   └─ sub_status = 3 (완료) 또는 sub_status = 2 + retry_count++ (실패)
```

---

## 3. 컴포넌트 상세

### 3.1 SNS FIFO Topic

```
이름:     prod_sns_hongcafe_global.fifo
리전:     ap-northeast-2 (KOR — 중앙 허브)
타입:     FIFO

설정:
  ContentBasedDeduplication: true  (메시지 본문 해시 기반 중복 제거)
  KmsMasterKeyId:            alias/aws/sns
  FifoThroughputScope:       MessageGroup

구독자 (3개):
  - arn:aws:sqs:us-east-1:241789449679:prod_sqs_hongcafe_usa.fifo
  - arn:aws:sqs:ap-northeast-2:241789449679:prod_sqs_hongcafe_kor.fifo
  - arn:aws:sqs:ap-northeast-1:241789449679:prod_sqs_hongcafe_jpn.fifo

Hub 선택 이유:
  - 단일 토픽으로 모든 국가에 fan-out (관리 단순화)
  - 크로스리전 SQS 구독은 AWS 공식 지원
```

### 3.2 SQS FIFO Queue (3개)

| 속성 | 값 |
|------|-----|
| 이름 패턴 | `prod_sqs_hongcafe_{country}.fifo` |
| VisibilityTimeout | 30초 |
| MessageRetentionPeriod | 4일 (345,600초) |
| MaximumMessageSize | 256KB (262,144바이트, AWS SQS 최대 한도) |
| ContentBasedDeduplication | false (SNS에서 관리) |
| DeduplicationScope | queue |
| FifoThroughputLimit | perQueue |
| SSE | SQS Managed |
| DLQ | **미설정** |

| 큐 | 리전 | SNS 구독 |
|---|---|---|
| `prod_sqs_hongcafe_usa.fifo` | us-east-1 | ✅ |
| `prod_sqs_hongcafe_kor.fifo` | ap-northeast-2 | ✅ |
| `prod_sqs_hongcafe_jpn.fifo` | ap-northeast-1 | ✅ |

### 3.3 Lambda (sqs_push)

#### 3.3.1 함수 목록

| 함수명 | 리전 | 상태 |
|--------|------|------|
| `prod_lambda_hongcafe_sqs_push_usa` | us-east-1 | **Active** |
| `prod_lambda_hongcafe_sqs_push_kor` | ap-northeast-2 | 스켈레톤 |
| `prod_lambda_hongcafe_sqs_push_jpn` | ap-northeast-1 | **미생성** (infra 디렉토리 미존재) |

#### 3.3.2 공통 스펙

| 속성 | 값 |
|------|-----|
| Runtime | Python 3.12 |
| Handler | `handler.handler` |
| Timeout | 60초 |
| Memory | 128MB |
| BatchSize | 1 |
| MaximumConcurrency | 10 |
| ReportBatchItemFailures | **활성** (`batchItemFailures` 반환) |

#### 3.3.3 USA Lambda 상세 (배포 완료)

```
VPC:
  SubnetIds:
    - subnet-0892353dc9e694aa8
    - subnet-00af5193cf5ecb58a
  SecurityGroupIds:
    - sg-0820dac6213285410
    - sg-0d55975cce72995ec
    - sg-01603171df95a3467
  VpcId: vpc-014e2e9f8b9a0f2c8

Layer:
  - prod_functionlayer_hongcafe_usa:1 (pymysql, ~1MB)

환경변수:
  DB_HOST: "prod-rdsproxy-hongcafe-usa.proxy-c47e2m0qmf7h.us-east-1.rds.amazonaws.com"
  DB_NAME: "athena"
  DB_USER: "admin"
  AWS_REGION: "us-east-1"

IAM Role: prod_lambda_hongcafe_sqs_push_usa-role-mycylnrd
```

#### 3.3.4 코드 구조 (infra 리포지토리)

```
lambda/
├── README.md
├── shared/
│   └── db_connection.py          — Aurora RDS Proxy IAM Auth 연결 (공통 모듈)
├── usa/sqs_push/
│   └── handler.py                — USA 데이터 싱크 (Active)
└── kor/sqs_push/
    └── handler.py                — KOR 스켈레톤 (미구현)
```

> ⚠️ JPN 디렉토리(`lambda/jpn/`)는 미생성 상태. KOR 또는 USA 코드 복제 후 환경변수만 변경하여 배포 예정.

### 3.4 EventBridge Rule

| 속성 | 값 |
|------|-----|
| 이름 | `prod_lambda_hongcafe_sqs_push_usa_schedule` |
| 스케줄 | `rate(1 minute)` |
| 타겟 | `prod_lambda_hongcafe_sqs_push_usa` |
| 상태 | **Enabled (AWS 콘솔 설정)** |

> ⚠️ 현재 Lambda 코드(`handler.py`)에는 EventBridge 스케줄 이벤트를 처리하는 로직이 없다. `handler()` 함수는 SQS Records만 처리하며, EventBridge 트리거 시 빈 Records 배열로 정상 종료된다. 스케줄 기반 배치 처리가 필요한 경우 별도 핸들러 구현이 필요하다.

### 3.5 Publisher (CI4 Backend) — 미구현

```
상태: 미구현
위치: CI4 PHP Backend (향후 구현 예정)
역할: account/coin 변경 시 SNS FIFO에 메시지 발행
SDD: docs/output/specs/php-sns-publisher-sdd.md

예상 구현 위치:
  - app/Libraries/SnsPublisher.php
  - app/Services/GlobalSyncService.php
  - AWS SDK for PHP (aws/aws-sdk-php ^3.263) 사용
```

---

## 4. 메시지 포맷

### 4.1 MessageGroupId 규칙

```
형식: {국가코드}:{엔티티타입}:{서브타입}:{ID}
예시: KR:ACCOUNT:CREATE:7
      US:COIN:TRANSFER:42
      JP:COIN:ADJUST:9

국가코드 (앞 2자리): 발행 국가 판별에 사용
  KR → 한국
  US → 미국
  JP → 일본

event_type → 엔티티타입:서브타입 매핑:
  account_create  → ACCOUNT:CREATE
  account_update  → ACCOUNT:UPDATE
  coin_transfer   → COIN:TRANSFER
  coin_adjust     → COIN:ADJUST
```

### 4.2 SNS Message 페이로드 (JSON)

Lambda `handler.py`의 `parse_message()`가 검증하는 필수 필드:

```python
required_fields = ["pub_id", "event_type", "entity_id", "payload"]
```

**coin_transfer 이벤트 예시:**

```json
{
  "pub_id":        12345,
  "event_type":    "coin_transfer",
  "entity_id":     7,
  "payload": {
    "account_id":  7,
    "amount":      500,
    "currency":    "KRW",
    "action":      "charge"
  },
  "source_region": "US",
  "timestamp":     "2026-04-09T12:00:00+00:00"
}
```

**account_create 이벤트 예시:**

```json
{
  "pub_id":        12346,
  "event_type":    "account_create",
  "entity_id":     123,
  "payload": {
    "account_id":  123,
    "name":        "홍길동",
    "email":       "hong@example.com"
  },
  "source_region": "KR",
  "timestamp":     "2026-04-09T12:01:00+09:00"
}
```

| 필드 | 타입 | 필수 여부 | 설명 |
|------|------|-----------|------|
| `pub_id` | int | **필수** | `global_sync_pub_log.pub_log_seq` (멱등성 체크 키) |
| `event_type` | string | **필수** | account_create / account_update / coin_transfer / coin_adjust |
| `entity_id` | int | **필수** | 대상 엔티티 ID (account ID) |
| `payload` | object | **필수** | event_type별 데이터 |
| `source_region` | string | 선택 | 발행 국가코드 (KR / US / JP) |
| `timestamp` | string | 선택 | ISO 8601 발행 시각 |

### 4.3 이벤트 유형별 payload

| event_type | 트리거 조건 | payload 필수 필드 |
|---|---|---|
| `account_create` | 신규 계정 가입 (tb_account INSERT) | `account_id`, `name`, `email` |
| `account_update` | 계정 정보 수정 (tb_account UPDATE) | `account_id`, `changed_fields` |
| `coin_transfer` | 코인 충전/사용/환불 | `account_id`, `amount`, `currency`, `action` |
| `coin_adjust` | 관리자 코인 보정 | `account_id`, `amount`, `reason` |

### 4.4 SQS 수신 측 메시지 파싱

`handler.py`에서 SQS body를 직접 JSON 파싱한다:

```python
body = json.loads(record.get("body", "{}"))
msg = parse_message(body)
```

---

## 5. 처리 로직

### 5.1 SQS Handler (`handler.py` — `handler()`)

```
입력: SQS Records (BatchSize=1)
처리:
  for record in event["Records"]:
    1. body = json.loads(record["body"])
    2. parse_message(body) → 필수 필드 검증 (pub_id, event_type, entity_id, payload)
    3. process_sync(msg) → DB 연결 → 멱등성 체크 → 이벤트 라우팅
    4. 실패 시 batch_item_failures에 추가
출력: {"batchItemFailures": [{"itemIdentifier": messageId}, ...]}
```

### 5.2 parse_message()

```
입력: SQS body (dict)
처리:
  1. required_fields = ["pub_id", "event_type", "entity_id", "payload"]
  2. 누락 필드 → ValueError 발생
  3. source_region, timestamp는 선택 (없으면 빈 문자열)
출력: 파싱된 메시지 dict
```

### 5.3 process_sync()

```
입력: parse_message()에서 반환된 msg dict
처리:
  1. shared.db_connection.get_connection() → Aurora 연결
  2. is_already_processed(cursor, pub_id)
     → SELECT sub_status FROM global_sync_sub_log WHERE pub_id = %s AND sub_status = 3
     → 이미 완료(3)이면 SKIP
  3. UPDATE global_sync_sub_log SET sub_status = 1 WHERE pub_id = %s (처리중)
  4. route_event(cursor, conn, event_type, entity_id, payload)
     → event_type별 핸들러 분기 (4종)
  5-성공: UPDATE global_sync_sub_log SET sub_status = 3 WHERE pub_id = %s
  5-실패: rollback → UPDATE sub_status = 2, retry_count++, last_error 기록 → raise

> ⚠️ **INSERT 주체 미정의:** 현재 코드는 global_sync_sub_log에 대해 UPDATE만 수행한다. 최초 수신 시 해당 pub_id 행이 없으면 0건 UPDATE가 발생하여 상태 갱신이 무시된다. sub_log INSERT 시점(SQS 수신 즉시 Lambda가 INSERT / PHP 발행 시 pre-INSERT)을 확정하고 코드에 반영해야 한다.
```

**멱등성:**
- `pub_id` 기반 — `is_already_processed()`로 `sub_status=3` 이미 완료된 메시지 SKIP
- SQS 재전송 시 동일 `pub_id`로 중복 처리 방지

### 5.4 route_event()

```
입력: cursor, conn, event_type, entity_id, payload
처리:
  handlers = {
    "account_create":  handle_account_create,   ← TODO: 미구현
    "account_update":  handle_account_update,   ← TODO: 미구현
    "coin_transfer":   handle_coin_transfer,    ← TODO: 미구현
    "coin_adjust":     handle_coin_adjust,      ← TODO: 미구현
  }
  → event_type 매칭 → 핸들러 호출
  → 미정의 event_type → 경고 로그, 무시 처리 (예외 없음)
```

> ⚠️ 4종 핸들러 모두 현재 로그만 출력하는 TODO 상태. 실제 DB INSERT/UPDATE 로직은 미구현.

### 5.5 상태 전이

```
   ┌─────────┐
   │  0 대기  │ ← 초기값 (SQS 수신 → sub_log INSERT 시점)
   └────┬────┘
        │ process_sync() 시작
        ▼
   ┌──────────┐
   │ 1 처리중  │
   └────┬─────┘
        │
   ┌────┴────┐
   │         │
   ▼         ▼
┌──────┐  ┌──────┐
│3 완료│  │2 실패│ + retry_count++ + last_error
└──────┘  └──────┘
```

---

## 6. 데이터 모델

### 6.1 global_sync_sub_log (코드 추론)

| 컬럼 | 타입 (추정) | 설명 |
|------|-------------|------|
| `sub_log_seq` | BIGINT, PK, AUTO_INCREMENT | 구독 로그 시퀀스 |
| `pub_id` | BIGINT | 발행 로그 ID (멱등성 체크 키) |
| `pub_country` | VARCHAR(2) | 발행 국가 (KR, US, JP) |
| `msg_id` | VARCHAR | SQS MessageId |
| `msg_group_id` | VARCHAR | SQS MessageGroupId (예: KR:ACCOUNT:CREATE:7) |
| `msg_body` | TEXT/JSON | SQS 메시지 원본 |
| `reg_date` | DATETIME | 수신 일시 |
| `sub_status` | TINYINT, DEFAULT 0 | 0=대기, 1=처리중, 2=실패, 3=완료 |
| `retry_count` | INT, DEFAULT 0 | 재시도 횟수 |
| `last_error` | TEXT, NULLABLE | 마지막 에러 메시지 |

> ※ 실제 스키마는 Aurora athena DB에서 `DESCRIBE global_sync_sub_log`로 확인 필요

### 6.2 tb_account (코인 관련 필드)

| 컬럼 | 용도 |
|------|------|
| `ac_id` | 계정 ID (PK) |
| `ac_free_charge_coin` | 무료 충전 코인 |
| `ac_free_use_coin` | 무료 사용 코인 |
| `ac_pay_charge_coin` | 유료 충전 코인 |
| `ac_pay_use_coin` | 유료 사용 코인 |
| `ac_charge_coin` | 총 충전 코인 |
| `ac_use_coin` | 총 사용 코인 |
| `ac_refund_coin` | 환불 코인 |
| `ac_remain_coin` | 잔여 코인 |
| `ac_remain_free_coin` | 잔여 무료 코인 |
| `ac_remain_pay_coin` | 잔여 유료 코인 |
| `last_update_date` | 마지막 수정 일시 |

---

## 7. DB 연결

### 7.1 RDS Proxy + IAM Auth

```
방식:     IAM Auth Token (비밀번호 없음)
Proxy:    prod-rdsproxy-hongcafe-usa.proxy-c47e2m0qmf7h.us-east-1.rds.amazonaws.com
Port:     3306
User:     admin
DB:       athena
TLS:      필수
```

### 7.2 연결 관리 (`shared/db_connection.py`)

```
환경변수:
  DB_HOST     — RDS Proxy 엔드포인트
  DB_NAME     — 데이터베이스명 (athena)
  DB_USER     — DB 사용자 (admin)
  AWS_REGION  — 리전 (us-east-1, 기본값)

연결 방식:
  - boto3 RDS client → generate_db_auth_token() → IAM 인증 토큰 생성
  - pymysql.connect(host, user, password=token, database, ssl=True)
  - Lambda 컨테이너 재사용 시 기존 연결 재활용 (ping(reconnect=True))
  - 연결 실패 시 재연결 (글로벌 변수 초기화)

설정:
  - charset: utf8mb4
  - cursorclass: DictCursor
  - connect_timeout: 5초
  - read_timeout: 10초
  - write_timeout: 10초
  - autocommit: False (pymysql 기본값, 파라미터 생략 — 수동 commit)
```

---

## 8. 보안

| 항목 | 방식 |
|------|------|
| Lambda → Aurora | RDS Proxy + IAM Auth (토큰 기반) |
| SNS 암호화 | KMS (`alias/aws/sns`) |
| SQS 암호화 | SQS Managed SSE |
| VPC | Lambda(USA), RDS Proxy, Aurora — 동일 VPC 프라이빗 서브넷 |
| TLS | RDS Proxy 강제 (비 TLS 접속 거부) |
| SNS 정책 | SourceAccount 조건으로 동일 계정만 허용 |
| SQS 정책 | SourceArn 조건으로 지정 SNS 토픽만 SendMessage 허용 |

---

## 9. 미구현 / 개선 필요 사항

### 9.1 미구현

| 항목 | 상태 | 영향 |
|------|------|------|
| **PHP Publisher** | 미구현 | 현재 이벤트 발행 불가 — 시스템 동작 안 함 |
| **USA 4종 핸들러 본문** | TODO (로그만 출력) | route_event() 분기는 되지만 실제 DB 반영 안 됨 |
| **KOR Lambda 코드** | 스켈레톤 | SQS 수신은 되지만 처리 안 됨 |
| **JPN Lambda** | 미생성 | infra 디렉토리 미존재, AWS Lambda 미생성 |
| **KOR/JPN VPC, Layer, Env** | 미설정 | DB 접근 불가 |
| **logpull Lambda** | 계획 | 로그 수집 기능 미구현 |

### 9.2 개선 필요

| 항목 | 현재 | 권장 | 사유 |
|------|------|------|------|
| **DLQ** | 없음 (3개 큐 모두) | FIFO DLQ 생성 + maxReceiveCount=3 | 실패 메시지 격리 불가 |
| **VisibilityTimeout** | 30초 | 360초 (Lambda Timeout × 6) | AWS 권장 ([문서](https://docs.aws.amazon.com/lambda/latest/dg/with-sqs.html)) |
| **MessageRetention** | 4일 | 14일 | 장애 복구 시간 확보 |
| **EventBridge 활용** | 설정됨, 코드 미대응 | 배치 재처리 핸들러 구현 또는 Rule 비활성화 | 현재 EventBridge 트리거 시 아무 동작 안 함 |
| **global_sync_pub_log** | 미확인 | 발행 로그 테이블 필요 | 발행 추적/재시도 |
| **CloudWatch Alarm** | 없음 | Lambda 에러율, SQS 체류 시간 | 장애 감지 |

---

## 10. 인프라 파일 참조

### 10.1 AWS 리소스

| 리소스 | ARN / 식별자 |
|--------|--------------|
| SNS Topic | `arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo` |
| SQS USA | `arn:aws:sqs:us-east-1:241789449679:prod_sqs_hongcafe_usa.fifo` |
| SQS KOR | `arn:aws:sqs:ap-northeast-2:241789449679:prod_sqs_hongcafe_kor.fifo` |
| SQS JPN | `arn:aws:sqs:ap-northeast-1:241789449679:prod_sqs_hongcafe_jpn.fifo` |
| Lambda USA | `prod_lambda_hongcafe_sqs_push_usa` (us-east-1) |
| Lambda KOR | `prod_lambda_hongcafe_sqs_push_kor` (ap-northeast-2) |
| Lambda JPN | `prod_lambda_hongcafe_sqs_push_jpn` (ap-northeast-1, **미생성**) |
| EventBridge | `prod_lambda_hongcafe_sqs_push_usa_schedule` (us-east-1, **코드 미대응**) |
| RDS Proxy | `prod-rdsproxy-hongcafe-usa.proxy-c47e2m0qmf7h.us-east-1.rds.amazonaws.com` |
| VPC | `vpc-014e2e9f8b9a0f2c8` (us-east-1) |
| Lambda Layer | `prod_functionlayer_hongcafe_usa:1` (pymysql) |

### 10.2 로컬 infra 프로젝트

| 파일 | 경로 |
|------|------|
| USA 핸들러 | `lambda/usa/sqs_push/handler.py` |
| KOR 핸들러 | `lambda/kor/sqs_push/handler.py` |
| DB 연결 모듈 | `lambda/shared/db_connection.py` |
| Lambda 현황 | `lambda/README.md` |

---

## 체크리스트

- [x] 설계 문서 초안 작성
- [x] 아키텍처 다이어그램 포함
- [x] 인터페이스 계약 정의
- [x] 에러 처리 전략 명시
- [x] 보안 고려사항 포함
- [ ] 코드 구현 완료 (4종 핸들러 TODO)
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 검증
- [ ] 운영 배포 확인

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 현재 코드 기준 전면 동기화: Runtime 3.12, Handler명, SQS 단일 트리거, pub_id 멱등성, batchItemFailures 활성, 환경변수(DB_HOST/DB_NAME/DB_USER/AWS_REGION), 이벤트 기반 메시지 포맷, JPN 미생성 상태 반영, EventBridge 코드 미대응 명시 | jypark |
| 2026-04-15 | 프론트매터 보강, 체크리스트/변경 기록 섹션 추가 | jypark |
