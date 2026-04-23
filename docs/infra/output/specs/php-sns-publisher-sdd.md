# SDD: PHP SNS Publisher

> SDD: PHP SNS Publisher

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-09 |
| 유형 | SDD |
| 상태 | 승인됨 |

---

## 내용

## 1. 개요

### 1.1 목적

HongCafe Global 국가 간(USA ↔ KOR ↔ JPN) account/coin 데이터 동기화 파이프라인에서
현재 **미구현 상태**인 발행(Pub) 측 컴포넌트를 설계한다.

CI4 PHP Backend에서 account/coin 변경 이벤트 발생 시 AWS SNS FIFO Topic에 메시지를 발행하여
각 국가 Lambda가 이를 수신·처리할 수 있도록 한다.

### 1.2 범위

| 항목 | 내용 |
|------|------|
| 발행 주체 | CI4 PHP Backend (PHP 8.5, CodeIgniter 4.7+) |
| 발행 대상 | AWS SNS FIFO (`prod_sns_hongcafe_global.fifo`, ap-northeast-2) |
| 이벤트 유형 | account_create, account_update, coin_transfer, coin_adjust |
| 발행 기록 | `global_sync_pub_log` 테이블 (Aurora MySQL, `athena` DB) |
| AWS SDK | `aws/aws-sdk-php ^3.263` (기존 설치됨) |

**범위 외:**
- Lambda 수신 측 로직 (Lambda Pub/Sub SDD 참조)
- SQS, SNS 인프라 프로비저닝 (기 구성 완료)
- KOR/JPN Lambda 완성 작업

### 1.3 관련 문서

| 문서 | 경로 | 참조 목적 |
|------|------|-----------|
| Lambda Pub/Sub SDD v2 | `docs/output/specs/lambda-pubsub-sdd.md` | 전체 아키텍처, 메시지 포맷, SNS/SQS 설정 |
| 인프라 구성 문서 | `docs/infrastructure.md` | EC2 환경, 배포 경로, AWS SDK 버전 |
| USA Lambda Handler | `lambda/usa/sqs_push/handler.py` | event_type 4종, parse_message 필수 필드 |

---

## 2. 아키텍처

### 2.1 전체 흐름 (CI4 → SNS → SQS → Lambda)

```
  [CI4 PHP Backend — EC2 prod_ec2_hongcafe_usa, us-east-1]
  ┌──────────────────────────────────────────────────────┐
  │  비즈니스 로직 (Model / Controller)                   │
  │       │ account/coin 변경 발생                        │
  │       ▼                                               │
  │  GlobalSyncService::publishEvent()                    │
  │       │ ① MessageGroupId 생성                         │
  │       │ ② global_sync_pub_log INSERT (pub_status=0)   │
  │       │ ③ SnsPublisher::publish()                     │
  │       │ ④ pub_status UPDATE (1=성공 / 2=실패)         │
  │       ▼                                               │
  │  SnsPublisher (app/Libraries/)                        │
  │       │ aws/aws-sdk-php SnsClient::publish()          │
  └───────┼───────────────────────────────────────────────┘
          │ HTTPS (크로스리전: us-east-1 → ap-northeast-2)
          ▼
  ┌──────────────────────────────────────┐
  │  SNS FIFO (ap-northeast-2, KOR 허브) │
  │  prod_sns_hongcafe_global.fifo       │
  │  ContentBasedDeduplication = true    │
  └──────┬──────────┬──────────┬─────────┘
         │          │          │  fan-out
         ▼          ▼          ▼
  ┌──────────┐ ┌──────────┐ ┌──────────┐
  │ SQS USA  │ │ SQS KOR  │ │ SQS JPN  │
  │ us-east-1│ │ap-ne-2   │ │ap-ne-1   │
  └────┬─────┘ └────┬─────┘ └────┬─────┘
       │             │             │
       ▼             ▼             ▼
  ┌──────────┐ ┌──────────┐ ┌──────────┐
  │ Lambda   │ │ Lambda   │ │ Lambda   │
  │ USA      │ │ KOR      │ │ JPN      │
  │ (Active) │ │(스켈레톤) │ │(스켈레톤) │
  └──────────┘ └──────────┘ └──────────┘
```

### 2.2 컴포넌트 배치 (CI4 내 위치)

```
/works/hongcafe-global/be/   (CI4 프로젝트 루트)
└── app/
    ├── Libraries/
    │   └── SnsPublisher.php          ← AWS SNS SDK 래퍼 (발행 전용, 프레임워크 무관)
    ├── Services/
    │   └── GlobalSyncService.php     ← 비즈니스 로직 (이벤트 분류, pub_log 관리)
    └── Models/
        └── GlobalSyncPubLogModel.php ← global_sync_pub_log CRUD
```

| 컴포넌트 | 역할 | CI4 배치 위치 선택 이유 |
|----------|------|------------------------|
| `SnsPublisher` | AWS SNS 통신 전용 래퍼 | `Libraries` — 프레임워크 의존성 없는 순수 PHP 클래스 |
| `GlobalSyncService` | 이벤트 분류, pub_log 상태 관리, 예외 처리 | `Services` — 비즈니스 로직 조율 계층 |
| `GlobalSyncPubLogModel` | DB CRUD (`global_sync_pub_log`) | `Models` — CI4 Model 관례 |

---

## 3. 컴포넌트 상세

### 3.1 SnsPublisher 클래스 (`app/Libraries/SnsPublisher.php`)

#### 역할

AWS SDK for PHP `SnsClient`의 래퍼 클래스.
SNS FIFO Topic 발행에 필요한 파라미터 조립 및 예외 변환을 담당한다.
프레임워크 의존성이 없는 순수 PHP 클래스로 유지한다.

#### 클래스 설계

```
클래스:    \App\Libraries\SnsPublisher

의존성:
  Aws\Sns\SnsClient          (aws/aws-sdk-php ^3.263)
  Aws\Exception\AwsException

상수:
  TOPIC_ARN  = 'arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo'
  SNS_REGION = 'ap-northeast-2'

생성자:
  __construct()
    - SnsClient 인스턴스 생성
    - region: 'ap-northeast-2'
    - credentials: EC2 Instance Profile 자동 사용 (IAM Role)
      fallback: 환경변수 AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

메서드:
  publish(string $messageGroupId, array $messagePayload): string
    입력: $messageGroupId — SNS MessageGroupId (예: KR:ACCOUNT:CREATE:7)
          $messagePayload — SNS Message 페이로드 배열
    출력: string — SNS MessageId
    예외: \RuntimeException — SNS 발행 실패 시 (AwsException 래핑)
    처리:
      SnsClient::publish([
          'TopicArn'       => self::TOPIC_ARN,
          'Message'        => json_encode($messagePayload, JSON_UNESCAPED_UNICODE),
          'MessageGroupId' => $messageGroupId,
          // ContentBasedDeduplication=true → MessageDeduplicationId 불필요
      ])
```

**SNS FIFO Topic 설정 참조 (Lambda SDD 섹션 3.1):**

| 설정 항목 | 값 |
|---|---|
| Topic ARN | `arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo` |
| 리전 | ap-northeast-2 (KOR 중앙 허브) |
| ContentBasedDeduplication | `true` — 별도 MessageDeduplicationId 불필요 |
| KmsMasterKeyId | `alias/aws/sns` |
| FifoThroughputScope | `MessageGroup` |

### 3.2 GlobalSyncService 클래스 (`app/Services/GlobalSyncService.php`)

#### 역할

이벤트 분류, MessageGroupId 생성, pub_log 상태 관리, SNS 발행 오케스트레이션 담당.
호출 측(Controller, 상위 Service)의 HTTP 응답에 영향을 주지 않도록 예외를 격리한다.

#### 클래스 설계

```
클래스:    \App\Services\GlobalSyncService

의존성:
  SnsPublisher
  GlobalSyncPubLogModel

환경변수:
  SYNC_REGION — 국가코드 (US / KR / JP), .env에 서버별 설정

메서드:
  publishEvent(string $eventType, int $entityId, array $payload): void
    1. buildMessageGroupId($eventType, $entityId) 호출
       → {SYNC_REGION}:{엔티티타입}:{서브타입}:{entityId}
    2. global_sync_pub_log INSERT (pub_status=0)
       → pub_log_seq 획득 (= pub_id)
    3. 메시지 페이로드 조립
       {pub_id, event_type, entity_id, payload, source_region, timestamp}
    4. SnsPublisher::publish($messageGroupId, $messagePayload)
       → 성공: pub_status=1, sns_message_id 기록, published_at=NOW()
       → 실패: pub_status=2, retry_count++, last_error 기록
       → 예외 재전파하지 않음 (발행 실패가 비즈니스 트랜잭션 롤백 방지)

  retryFailed(): void
    → pub_status=2 AND retry_count < 5 레코드 조회
    → publishEvent() 재호출 (배치 재시도 전용)
```

### 3.3 이벤트 유형 (Lambda handler 기반)

Lambda `handler.py`의 `route_event()` 함수에서 정의된 4종 event_type과 정합성을 맞춘다.

| event_type | 트리거 조건 | MessageGroupId 서브타입 | payload 필수 필드 |
|---|---|---|---|
| `account_create` | 신규 계정 가입 (tb_account INSERT) | `ACCOUNT:CREATE` | `account_id`, `name`, `email` |
| `account_update` | 계정 정보 수정 (tb_account UPDATE) | `ACCOUNT:UPDATE` | `account_id`, `changed_fields` |
| `coin_transfer` | 코인 충전/사용/환불 | `COIN:TRANSFER` | `account_id`, `amount`, `currency`, `action` |
| `coin_adjust` | 관리자 코인 보정 | `COIN:ADJUST` | `account_id`, `amount`, `reason` |

### 3.4 통합 지점

**채택 방식: Service Layer 명시적 호출**

CI4 Model에서 account/coin 변경 완료 후, 호출 측(Controller 또는 상위 Service)에서
`GlobalSyncService`를 명시적으로 호출한다.

```
[Controller / 상위 Service]
  ├─ AccountModel->save()    ← DB 저장
  └─ service('globalSync')->publishEvent('account_create', $entityId, $payload)
                             ← 발행 (pub_log INSERT → SNS → pub_log UPDATE)
```

CI4 `service()` 헬퍼로 DI 컨테이너에서 싱글톤 인스턴스를 획득한다.
`Config/Services.php`에 `globalSync` 등록 필요.

**비채택 방식: CI4 Events 후킹**

CI4 `Events::on('post_model_save', ...)` 방식은 암묵적 의존성으로 인해
디버깅 난이도가 높고, 선택적 발행(일부 Model 저장은 발행 불필요)이 어렵다.

---

## 4. 메시지 포맷

### 4.1 SNS Publish 파라미터 전체 구조

```
SnsClient::publish() 파라미터:

TopicArn:        arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo
MessageGroupId:  {국가코드}:{엔티티타입}:{서브타입}:{entity_id}
Message:         JSON 문자열 (4.2 참조)
```

### 4.2 SNS Message 페이로드 (JSON)

Lambda `handler.py`의 `parse_message()`가 검증하는 필수 필드와 정확히 일치해야 한다.

```
Lambda parse_message() 필수 필드:
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
| `pub_id` | int | **필수** | `global_sync_pub_log.pub_log_seq` (Lambda 멱등성 체크 키) |
| `event_type` | string | **필수** | account_create / account_update / coin_transfer / coin_adjust |
| `entity_id` | int | **필수** | 대상 엔티티 ID (account ID) |
| `payload` | object | **필수** | event_type별 데이터 (섹션 3.3 참조) |
| `source_region` | string | 선택 | 발행 국가코드 (KR / US / JP) |
| `timestamp` | string | 선택 | ISO 8601 발행 시각 |

### 4.3 MessageGroupId 생성 규칙

Lambda SDD 섹션 4.1과 동일한 규칙을 따른다.

```
형식: {국가코드}:{엔티티타입}:{서브타입}:{entity_id}

국가코드 (환경변수 SYNC_REGION):
  SYNC_REGION=KR → "KR"
  SYNC_REGION=US → "US"
  SYNC_REGION=JP → "JP"

event_type → 엔티티타입:서브타입 매핑:
  account_create  → ACCOUNT:CREATE
  account_update  → ACCOUNT:UPDATE
  coin_transfer   → COIN:TRANSFER
  coin_adjust     → COIN:ADJUST

예시:
  KR 서버, account_create, entity_id=7   → "KR:ACCOUNT:CREATE:7"
  US 서버, coin_transfer,  entity_id=42  → "US:COIN:TRANSFER:42"
  JP 서버, coin_adjust,    entity_id=9   → "JP:COIN:ADJUST:9"
```

### 4.4 SQS 수신 측 메시지 구조 (참조용)

PHP Publisher는 SNS 래핑을 직접 처리하지 않는다.
SNS → SQS 전달 시 SNS가 자동 래핑하며, Lambda 수신 측이 2단 파싱을 수행한다.

```json
{
  "Type":      "Notification",
  "MessageId": "...",
  "TopicArn":  "arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo",
  "Message":   "{\"pub_id\":12345,\"event_type\":\"coin_transfer\",...}",
  "Timestamp": "2026-04-09T03:00:00.000Z"
}
```

---

## 5. 처리 로직

### 5.1 발행 흐름 (pub_log INSERT → SNS publish → pub_log UPDATE)

```
GlobalSyncService::publishEvent(event_type, entity_id, payload)
│
├─ [1] MessageGroupId 생성
│       {SYNC_REGION}:{엔티티타입}:{서브타입}:{entity_id}
│
├─ [2] global_sync_pub_log INSERT
│       pub_status = 0 (발행 대기)
│       → pub_log_seq 획득 (= pub_id)
│
├─ [3] SNS Message 페이로드 조립
│       {pub_id, event_type, entity_id, payload, source_region, timestamp}
│
├─ [4] SnsPublisher::publish(messageGroupId, messagePayload)
│       SnsClient::publish() 호출 (ap-northeast-2)
│       → 성공: sns_message_id 반환
│       → 실패: AwsException → RuntimeException 변환
│
├─ [5-성공] global_sync_pub_log UPDATE
│       pub_status  = 1 (발행 완료)
│       sns_message_id = 반환된 MessageId
│       published_at   = NOW()
│       mod_date       = NOW()
│
└─ [5-실패] global_sync_pub_log UPDATE
        pub_status  = 2 (발행 실패)
        retry_count = retry_count + 1
        last_error  = 예외 메시지
        mod_date    = NOW()
        → 예외 재전파하지 않음 (발행 실패가 비즈니스 트랜잭션 롤백 방지)
        → CI4 log_message('error', ...) 기록
```

### 5.2 에러 핸들링 (SNS 실패 시 pub_status 마킹)

| 예외 유형 | 원인 | 처리 |
|-----------|------|------|
| `AwsException` (네트워크) | SNS 엔드포인트 접근 불가 | pub_status=2, retry_count++, last_error 기록 |
| `AwsException` (권한) | IAM Role sns:Publish 권한 없음 | pub_status=2, last_error 기록 (재시도 무의미) |
| `AwsException` (스로틀링) | SNS 요청 한도 초과 | pub_status=2, retry_count++, 지수 백오프 후 재시도 |
| `\JsonException` | payload 직렬화 실패 | pub_log INSERT 전 발생 → 로그만, pub_log 없음 |
| DB 예외 (pub_log INSERT) | Aurora 연결 실패 | pub_log 없음, 예외 로깅, SNS 발행 시도 안 함 |

**핵심 원칙:** SNS 발행 실패는 DB 저장(account/coin 변경)을 롤백하지 않는다.
발행 실패는 `pub_status = 2`로 마킹하고 배치 재시도가 처리한다.

### 5.3 재시도 전략

**동기 재시도 불채택:** HTTP 응답 중 블로킹 재시도는 응답 지연 유발.

**채택: 배치 재시도**

```
재시도 대상:  pub_status = 2 AND retry_count < 5
재시도 방법:  GlobalSyncService::retryFailed() (Cron 또는 CI4 Spark Command)
재시도 주기:  5분 간격
최대 재시도:  5회
5회 초과 시:  pub_status = 9 (영구 실패), 수동 처리 필요
```

### 5.4 상태 전이

```
  ┌──────────┐
  │ 0 대기   │ ← global_sync_pub_log INSERT 직후
  └────┬─────┘
       │ SnsPublisher::publish() 시도
  ┌────┴──────┐
  │           │
  ▼           ▼
┌──────┐  ┌──────────┐
│1 성공│  │ 2 실패   │ ← retry_count++
└──────┘  └────┬─────┘
               │ 배치 재시도 (retry_count < 5)
          ┌────┴──────┐
          │           │
          ▼           ▼
        ┌──────┐  ┌───────────┐
        │1 성공│  │9 영구실패 │ ← retry_count >= 5
        └──────┘  └───────────┘
```

---

## 6. 데이터 모델

### 6.1 global_sync_pub_log

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `pub_log_seq` | BIGINT, PK, AUTO_INCREMENT | 발행 로그 시퀀스 (= pub_id) |
| `pub_country` | VARCHAR(2), NOT NULL | 발행 국가 (US, KR, JP) |
| `event_type` | VARCHAR(30), NOT NULL | 이벤트 유형 |
| `entity_id` | BIGINT, NOT NULL | 대상 엔티티 ID |
| `msg_group_id` | VARCHAR(100), NOT NULL | SNS MessageGroupId |
| `msg_body` | JSON, NOT NULL | 발행 메시지 본문 |
| `sns_message_id` | VARCHAR(100), NULLABLE | SNS 응답 MessageId |
| `pub_status` | TINYINT, DEFAULT 0 | 0=대기, 1=성공, 2=실패, 9=영구실패 |
| `retry_count` | INT, DEFAULT 0 | 재시도 횟수 |
| `last_error` | TEXT, NULLABLE | 마지막 에러 메시지 |
| `published_at` | DATETIME, NULLABLE | SNS 발행 완료 일시 |
| `reg_date` | DATETIME, NOT NULL | 생성 일시 |
| `mod_date` | DATETIME, NULLABLE | 수정 일시 |

**인덱스:**

| 인덱스 | 컬럼 | 용도 |
|--------|------|------|
| PRIMARY | `pub_log_seq` | PK |
| IDX_pub_status | `pub_status`, `retry_count` | 재시도 대상 조회 |
| IDX_entity | `entity_id`, `event_type` | 엔티티별 발행 이력 조회 |

### 6.2 tb_account 연계

Publisher는 `tb_account` 테이블을 직접 수정하지 않는다. `tb_account` 변경이 발생한 후(기존 비즈니스 로직) 변경된 필드값을 payload에 담아 SNS로 발행한다.

---

## 7. 보안

| 항목 | 방식 |
|------|------|
| AWS SDK 인증 | EC2 Instance Profile (IAM Role) 우선 사용 |
| 환경변수 fallback | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (.env) |
| SNS 접근 정책 | Topic 정책에 EC2 IAM Role ARN `sns:Publish` 허용 |
| 크로스리전 통신 | HTTPS (SDK 기본, TLS 1.2+) |
| 메시지 암호화 | SNS Topic KMS 암호화 (`alias/aws/sns`) |
| 민감 데이터 | payload에 PII 불포함 (코인 수치만 전달) |

**필요 IAM 권한:**

```json
{
  "Effect": "Allow",
  "Action": "sns:Publish",
  "Resource": "arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo"
}
```

---

## 8. 타당성 검토

### 8.1 AWS SNS FIFO 크로스리전 발행

**결론: 가능.**

SNS FIFO Topic은 특정 리전에 생성되지만, 다른 리전의 클라이언트(EC2, Lambda 등)에서 HTTPS 엔드포인트를 통해 크로스리전 발행이 가능하다. PHP SDK에서 SnsClient 생성 시 `region` 파라미터를 `ap-northeast-2`로 지정하면 해당 리전 엔드포인트로 요청이 전달된다.

**고려사항:** 크로스리전 HTTPS 호출이므로 us-east-1 → ap-northeast-2 간 네트워크 레이턴시(~100-200ms)가 추가된다. 비동기 발행이므로 사용자 응답 시간에 미치는 영향은 제한적이나, 동기 호출 시 타임아웃 설정(5초)을 권장한다.

**근거:** AWS SNS Developer Guide — Publishing to a FIFO topic, AWS SDK for PHP SNS publish API reference.

### 8.2 PHP SDK SNS FIFO 지원

**결론: 완전 지원.**

`aws/aws-sdk-php` 3.x는 SNS FIFO Topic의 `MessageGroupId`, `MessageDeduplicationId` 파라미터를 완전 지원한다. 프로젝트에 이미 `^3.263` 버전이 설치되어 있으므로 추가 설치 불필요.

### 8.3 CI4 통합 적합성

**결론: 적합.**

CI4 4.7+의 `Services` 패턴으로 `GlobalSyncService`를 등록하면 `service('globalSync')` 호출로 DI 컨테이너에서 싱글톤 인스턴스를 획득할 수 있다. Library/Service/Model 3계층 분리는 CI4 관례에 부합하며, 단위 테스트 시 SnsPublisher를 Mock으로 교체하여 테스트 가능하다.

---

## 9. 변경 영향 기록

| 변경 사항 | 개선점 | 수행 이유 |
|-----------|--------|-----------|
| `SnsPublisher` 신규 생성 | SNS FIFO 발행 기능 확보 | Pub/Sub 파이프라인 발행 측 미구현 해소 |
| `GlobalSyncService` 신규 생성 | 이벤트 분류/로깅/에러 처리 일원화 | 비즈니스 로직과 AWS 통신 분리 |
| `GlobalSyncPubLogModel` 신규 생성 | 발행 기록 추적/재시도 기반 확보 | 발행 실패 감지 및 복구 수단 |
| `global_sync_pub_log` 테이블 생성 | 발행 이력 감사, 재시도 큐 역할 | Lambda SDD 9.2 권고사항 반영 |
| EC2 IAM Role에 SNS Publish 권한 추가 | 크로스리전 SNS 발행 가능 | 현재 EC2 Role에 SNS 권한 없음 |
| `.env`에 `SYNC_REGION` 환경변수 추가 | 국가별 MessageGroupId 접두사 결정 | 동일 코드로 3개국 배포 지원 |

---

## 체크리스트

- [x] 설계 문서 초안 작성
- [x] 아키텍처 다이어그램 포함
- [x] 인터페이스 계약 정의
- [x] 에러 처리 전략 명시
- [x] 보안 고려사항 포함
- [ ] 코드 구현 완료
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 검증
- [ ] 운영 배포 확인

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 프론트매터 보강 (문서 ID, 버전, 관련 문서), 체크리스트/변경 기록 섹션 추가 | jypark |
