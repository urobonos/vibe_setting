# IDD: HongCafe Global 인터페이스 설계 문서

> HongCafe Global 서비스의 서브시스템 간 인터페이스 계약(메시지 포맷, API, DB 스키마, 연결 방식)을 정의한다.

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-15 |
| 유형 | IDD |
| 상태 | 초안 |

---

## 내용

## 1. 개요

### 1.1 목적

본 문서는 HongCafe Global 인프라를 구성하는 서브시스템 간의 인터페이스를 정의한다. 각 컴포넌트가 주고받는 메시지 포맷, 데이터베이스 스키마, 연결 프로토콜, 에러 코드를 명세하여 독립적인 구현과 테스트를 가능하게 한다.

### 1.2 인터페이스 목록

| ID | 인터페이스 | 제공자 | 소비자 | 프로토콜 |
|----|-----------|--------|--------|---------|
| IF-01 | PHP → SNS FIFO 발행 | CI4 Backend | SNS FIFO Topic | HTTPS (AWS SDK) |
| IF-02 | SNS → SQS 팬아웃 | SNS FIFO | SQS FIFO (3개국) | AWS 내부 |
| IF-03 | SQS → Lambda 트리거 | SQS FIFO | Lambda (sqs_push) | AWS 이벤트 소스 매핑 |
| IF-04 | Lambda → Aurora DB | Lambda | Aurora MySQL (RDS Proxy) | pymysql + IAM Auth |
| IF-05 | Bitbucket → SSM → EC2 | Bitbucket Pipelines | EC2 deploy 스크립트 | AWS SSM send-command |
| IF-06 | Logpull → 원격 Aurora | Lambda (logpull) | USA/JPN Aurora | pymysql (크로스리전) |

### 1.3 관련 문서

| 문서 | 경로 |
|------|------|
| SRS | `docs/output/specs/hongcafe-global-srs.md` |
| Lambda Pub/Sub SDD | `docs/output/specs/lambda-pubsub-sdd.md` |
| PHP SNS Publisher SDD | `docs/output/specs/php-sns-publisher-sdd.md` |
| CI/CD Pipeline SDD | `docs/output/specs/cicd-pipeline-sdd.md` |
| Lambda CI/CD SDD | `docs/output/specs/lambda-cicd-sdd.md` |
| Lambda Logpull SDD | `docs/output/specs/lambda-logpull-sdd.md` |

---

## 2. IF-01: PHP → SNS FIFO 발행

### 2.1 개요

| 항목 | 값 |
|------|-----|
| 제공자 | CI4 Backend (`GlobalSyncService` → `SnsPublisher`) |
| 수신자 | SNS FIFO Topic (`prod_sns_hongcafe_global.fifo`, ap-northeast-2) |
| 프로토콜 | HTTPS (AWS SDK for PHP, 크로스리전) |
| 인증 | EC2 Instance Profile (IAM Role) |
| 상태 | **미구현** |

### 2.2 SNS Publish 파라미터

```
SnsClient::publish([
    'TopicArn'       => 'arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo',
    'Message'        => JSON 문자열 (2.3 참조),
    'MessageGroupId' => '{국가코드}:{엔티티타입}:{서브타입}:{entity_id}',
    // ContentBasedDeduplication=true → MessageDeduplicationId 불필요
])
```

### 2.3 Message 페이로드 (JSON)

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

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `pub_id` | int | **필수** | `global_sync_pub_log.pub_log_seq` — Lambda 멱등성 키 |
| `event_type` | string | **필수** | `account_create` / `account_update` / `coin_transfer` / `coin_adjust` |
| `entity_id` | int | **필수** | 대상 엔티티 ID (account ID) |
| `payload` | object | **필수** | event_type별 데이터 |
| `source_region` | string | 선택 | 발행 국가코드 (KR / US / JP) |
| `timestamp` | string | 선택 | ISO 8601 발행 시각 |

### 2.4 MessageGroupId 규칙

```
형식: {국가코드}:{엔티티타입}:{서브타입}:{entity_id}

event_type → 엔티티타입:서브타입 매핑:
  account_create  → ACCOUNT:CREATE
  account_update  → ACCOUNT:UPDATE
  coin_transfer   → COIN:TRANSFER
  coin_adjust     → COIN:ADJUST

예시:
  KR:ACCOUNT:CREATE:7
  US:COIN:TRANSFER:42
  JP:COIN:ADJUST:9
```

### 2.5 이벤트 유형별 payload 스키마

| event_type | payload 필수 필드 |
|---|---|
| `account_create` | `account_id: int`, `name: string`, `email: string` |
| `account_update` | `account_id: int`, `changed_fields: object` |
| `coin_transfer` | `account_id: int`, `amount: int`, `currency: string`, `action: string` |
| `coin_adjust` | `account_id: int`, `amount: int`, `reason: string` |

### 2.6 에러 처리

| 에러 유형 | HTTP/SDK 코드 | 처리 |
|----------|-------------|------|
| 네트워크 실패 | AwsException | `pub_status=2`, `retry_count++` |
| IAM 권한 부족 | 403 Forbidden | `pub_status=2`, 재시도 무의미 |
| 스로틀링 | 429 Throttling | `pub_status=2`, 지수 백오프 재시도 |
| 페이로드 직렬화 실패 | JsonException | 로그만, pub_log 미생성 |

---

## 3. IF-02: SNS → SQS 팬아웃

### 3.1 개요

| 항목 | 값 |
|------|-----|
| 소스 | SNS FIFO (`prod_sns_hongcafe_global.fifo`, ap-northeast-2) |
| 타겟 | SQS FIFO 3개 (USA, KOR, JPN) |
| 프로토콜 | AWS 내부 (크로스리전 구독) |
| 인증 | SQS 정책 (SourceArn 조건) |

### 3.2 구독 구성

| SQS Queue | 리전 | ARN |
|-----------|------|-----|
| `prod_sqs_hongcafe_usa.fifo` | us-east-1 | `arn:aws:sqs:us-east-1:241789449679:prod_sqs_hongcafe_usa.fifo` |
| `prod_sqs_hongcafe_kor.fifo` | ap-northeast-2 | `arn:aws:sqs:ap-northeast-2:241789449679:prod_sqs_hongcafe_kor.fifo` |
| `prod_sqs_hongcafe_jpn.fifo` | ap-northeast-1 | `arn:aws:sqs:ap-northeast-1:241789449679:prod_sqs_hongcafe_jpn.fifo` |

### 3.3 메시지 전달 방식

**Raw Message Delivery: 활성화 (확인 필요)**

Lambda `handler.py`의 `json.loads(record["body"])`에서 `pub_id`를 직접 파싱하는 구조로 볼 때, SQS 구독에 **Raw Message Delivery**가 활성화되어 SNS 래핑 없이 원본 JSON이 body에 직접 전달되는 것으로 추정된다.

- Raw Message Delivery **활성** 시: `record["body"]` = 원본 JSON (`{"pub_id":...}`)
- Raw Message Delivery **비활성** 시: `record["body"]` = SNS 래핑 JSON (`{"Type":"Notification","Message":"{\"pub_id\":...}"}`) → 2단 파싱 필요

> ⚠️ AWS 콘솔에서 SNS 구독의 Raw Message Delivery 설정을 확인해야 한다. 비활성 상태라면 Lambda 코드에 2단 파싱 로직 추가가 필요하다.

### 3.4 SQS 정책 (SendMessage 허용)

```json
{
  "Effect": "Allow",
  "Principal": { "Service": "sns.amazonaws.com" },
  "Action": "sqs:SendMessage",
  "Resource": "arn:aws:sqs:{region}:241789449679:prod_sqs_hongcafe_{country}.fifo",
  "Condition": {
    "ArnEquals": {
      "aws:SourceArn": "arn:aws:sns:ap-northeast-2:241789449679:prod_sns_hongcafe_global.fifo"
    }
  }
}
```

---

## 4. IF-03: SQS → Lambda 트리거

### 3.1 개요

| 항목 | 값 |
|------|-----|
| 소스 | SQS FIFO (`prod_sqs_hongcafe_{country}.fifo`) |
| 타겟 | Lambda (`prod_lambda_hongcafe_sqs_push_{country}`) |
| 매핑 | AWS Event Source Mapping |
| BatchSize | 1 |
| MaximumConcurrency | 10 |
| ReportBatchItemFailures | **활성** |

### 3.2 SQS 이벤트 구조 (Lambda 입력)

```json
{
  "Records": [
    {
      "messageId": "...",
      "receiptHandle": "...",
      "body": "{\"pub_id\":12345,\"event_type\":\"coin_transfer\",...}",
      "attributes": {
        "MessageGroupId": "KR:COIN:TRANSFER:7",
        "MessageDeduplicationId": "...",
        "SentTimestamp": "..."
      },
      "eventSource": "aws:sqs",
      "eventSourceARN": "arn:aws:sqs:us-east-1:241789449679:prod_sqs_hongcafe_usa.fifo"
    }
  ]
}
```

### 3.3 Lambda 출력 (batchItemFailures)

```json
{
  "batchItemFailures": [
    { "itemIdentifier": "실패한 messageId" }
  ]
}
```

- 빈 배열 반환 시: 전체 성공
- messageId 포함 시: 해당 메시지만 SQS에 재전송

### 3.4 Lambda 내부 처리 흐름

```
handler(event, context)
  └─ for record in event["Records"]:
       ├─ body = json.loads(record["body"])
       ├─ msg = parse_message(body)
       │    └─ 필수 필드 검증: pub_id, event_type, entity_id, payload
       ├─ process_sync(msg)
       │    ├─ get_connection() → Aurora 연결
       │    ├─ is_already_processed(pub_id) → sub_status=3 체크
       │    ├─ UPDATE sub_status = 1 (처리중)
       │    ├─ route_event(event_type, entity_id, payload)
       │    │    ├─ account_create  → handle_account_create()  [TODO]
       │    │    ├─ account_update  → handle_account_update()  [TODO]
       │    │    ├─ coin_transfer   → handle_coin_transfer()   [TODO]
       │    │    └─ coin_adjust     → handle_coin_adjust()     [TODO]
       │    ├─ 성공: UPDATE sub_status = 3
       │    └─ 실패: rollback, UPDATE sub_status = 2, retry_count++
       └─ 예외 시: batch_item_failures.append(messageId)
```

---

## 4. IF-04: Lambda → Aurora DB

### 4.1 연결 정보

| 항목 | 값 |
|------|-----|
| 방식 | RDS Proxy + IAM Auth Token |
| 라이브러리 | pymysql |
| 호스트 | `DB_HOST` 환경변수 (RDS Proxy 엔드포인트) |
| 포트 | 3306 |
| 사용자 | `DB_USER` 환경변수 (admin) |
| 데이터베이스 | `DB_NAME` 환경변수 (athena) |
| TLS | 필수 (`ssl={"ssl": True}`) |
| 토큰 생성 | `boto3.client("rds").generate_db_auth_token()` |

### 4.2 DB 스키마: global_sync_sub_log

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `sub_log_seq` | BIGINT, PK, AUTO_INCREMENT | 구독 로그 시퀀스 |
| `pub_id` | BIGINT | 발행 로그 ID (멱등성 체크 키) |
| `pub_country` | VARCHAR(2) | 발행 국가 (KR, US, JP) |
| `msg_id` | VARCHAR | SQS MessageId |
| `msg_group_id` | VARCHAR | MessageGroupId |
| `msg_body` | TEXT/JSON | 메시지 원본 |
| `reg_date` | DATETIME | 수신 일시 |
| `sub_status` | TINYINT, DEFAULT 0 | 0=대기, 1=처리중, 2=실패, 3=완료 |
| `retry_count` | INT, DEFAULT 0 | 재시도 횟수 |
| `last_error` | TEXT, NULLABLE | 에러 메시지 |

### 4.3 DB 스키마: global_sync_pub_log

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `pub_log_seq` | BIGINT, PK, AUTO_INCREMENT | 발행 로그 시퀀스 (= pub_id) |
| `pub_country` | VARCHAR(2), NOT NULL | 발행 국가 |
| `event_type` | VARCHAR(30), NOT NULL | 이벤트 유형 |
| `entity_id` | BIGINT, NOT NULL | 대상 엔티티 ID |
| `msg_group_id` | VARCHAR(100), NOT NULL | MessageGroupId |
| `msg_body` | JSON, NOT NULL | 발행 메시지 본문 |
| `sns_message_id` | VARCHAR(100), NULLABLE | SNS 응답 MessageId |
| `pub_status` | TINYINT, DEFAULT 0 | 0=대기, 1=성공, 2=실패, 9=포기 |
| `retry_count` | INT, DEFAULT 0 | 재시도 횟수 |
| `last_error` | TEXT, NULLABLE | 에러 메시지 |
| `published_at` | DATETIME, NULLABLE | SNS 발행 완료 일시 |
| `reg_date` | DATETIME, NOT NULL | 생성 일시 |
| `mod_date` | DATETIME, NULLABLE | 수정 일시 |

### 4.4 SQL 인터페이스

**멱등성 체크:**
```sql
SELECT sub_status FROM global_sync_sub_log WHERE pub_id = %s AND sub_status = 3 LIMIT 1
```

**상태 갱신:**
```sql
-- 처리중
UPDATE global_sync_sub_log SET sub_status = 1 WHERE pub_id = %s
-- 완료
UPDATE global_sync_sub_log SET sub_status = 3 WHERE pub_id = %s
-- 실패
UPDATE global_sync_sub_log SET sub_status = 2, retry_count = retry_count + 1, last_error = %s WHERE pub_id = %s
```

---

## 5. IF-05: Bitbucket → SSM → EC2

### 5.1 SSM send-command 인터페이스

```bash
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["bash /works/hongcafe-global/scripts/deploy-{be|fe}.sh $BITBUCKET_BRANCH"]}' \
  --timeout-seconds 600
```

### 5.2 deploy 스크립트 인터페이스

| 스크립트 | 입력 | 출력 |
|---------|------|------|
| `deploy-be.sh` | `$1` = branch (production/staging/develop) | exit 0 (성공) / exit 1 (실패) |
| `deploy-fe.sh` | `$1` = branch (production/staging/develop) | exit 0 (성공) / exit 1 (실패) |

**브랜치 → 환경 매핑:**

| 입력 (branch) | 환경 (ENV) | DEPLOY_PATH |
|---------------|-----------|-------------|
| `production` | `prd` | `/works/hongcafe-global/prd/` |
| `staging` | `stg` | `/works/hongcafe-global/stg/` |
| `develop` | `dev` | `/works/hongcafe-global/dev/` |

### 5.3 SSM 결과 확인

| 상태 | 의미 | 파이프라인 결과 |
|------|------|----------------|
| `Success` | EC2 명령 정상 완료 | 파이프라인 성공 |
| `Failed` | EC2 명령 실패 (exit 1) | 파이프라인 실패 |
| `TimedOut` | SSM 타임아웃 | 파이프라인 실패 |
| `InProgress` | 실행 중 (wait 타임아웃 후) | 파이프라인 실패 |

---

## 6. IF-06: Logpull → 원격 Aurora

### 6.1 개요

| 항목 | 값 |
|------|-----|
| 제공자 | USA/JPN Aurora (`global_sync_sub_log`) |
| 소비자 | Lambda (`prod_lambda_hongcafe_logpull_kor`, ap-northeast-2) |
| 프로토콜 | pymysql (크로스리전 직접 접속, VPC Peering 경유) |
| 인증 | IAM Auth (logpull_reader 읽기 전용 사용자) |
| 상태 | **미구현** (VPC Peering 승인 대기) |

### 6.2 접속 정보

| 대상 | 호스트 (계획) | 포트 | 사용자 | 권한 |
|------|-------------|------|--------|------|
| USA Aurora | `prod-aurora-hongcafe-usa.cluster-xxxx.us-east-1.rds.amazonaws.com` | 3306 | `logpull_reader` | SELECT only |
| JPN Aurora | `prod-aurora-hongcafe-jpn.cluster-xxxx.ap-northeast-1.rds.amazonaws.com` | 3306 | `logpull_reader` | SELECT only |
| KOR Aurora | KOR RDS Proxy (로컬) | 3306 | `admin` | SELECT/INSERT/UPDATE |

> ⚠️ RDS Proxy는 동일 리전 VPC 내 클라이언트만 지원. 크로스리전 접속은 Aurora 클러스터 엔드포인트에 직접 접속해야 한다.

### 6.3 수집 쿼리 인터페이스

```sql
-- 미완료/실패 건 수집 (watermark 기반)
SELECT sub_log_seq, pub_country, msg_id, msg_group_id, sub_status, retry_count, last_error, reg_date
FROM global_sync_sub_log
WHERE sub_log_seq > %(last_collected_seq)s AND sub_status IN (0, 1, 2)
ORDER BY sub_log_seq ASC LIMIT %(batch_size)s;
```

### 6.4 저장 대상 테이블 (KOR Aurora)

- `global_sync_monitor_log` — 미완료/실패 건 상세
- `global_sync_monitor_stats` — 완료 건 집계
- `logpull_watermark` — 수집 위치 추적 (source_country PK, last_seq)

상세 DDL은 `lambda-logpull-sdd.md` 섹션 5 참조.

---

## 7. 상태 코드 종합

### 7.1 sub_status (동기화 수신)

| 코드 | 의미 | 전이 |
|------|------|------|
| 0 | 대기 | 초기 → 1 |
| 1 | 처리중 | → 3 (성공) / → 2 (실패) |
| 2 | 실패 | retry 대상 |
| 3 | 완료 | 최종 |

### 7.2 pub_status (발행)

| 코드 | 의미 | 전이 |
|------|------|------|
| 0 | 대기 | INSERT 직후 → 1 (성공) / → 2 (실패) |
| 1 | 성공 | 최종 |
| 2 | 실패 | retry → 1 (성공) / → 9 (포기) |
| 9 | 영구실패 | retry_count >= 5, 수동 처리 |

---

## 8. 타당성 검토

### 8.1 크로스리전 SNS→SQS 인터페이스

**결론: 가능.**

AWS SNS FIFO는 크로스리전 SQS 구독을 공식 지원한다. ap-northeast-2(KOR)의 SNS Topic에서 us-east-1(USA), ap-northeast-1(JPN)의 SQS Queue로 메시지를 전달할 수 있다. 전달 지연은 리전 간 네트워크 거리에 따라 100-500ms 수준이다.

**근거:** AWS SNS Developer Guide — Subscribing an Amazon SQS queue to an Amazon SNS topic in a different Region.

### 8.2 pub_id 기반 멱등성의 안정성

**결론: 안정.**

`pub_id`는 `global_sync_pub_log.pub_log_seq` (AUTO_INCREMENT PK)로 단조 증가가 보장된다. Lambda에서 `SELECT ... WHERE pub_id = %s AND sub_status = 3`으로 완료 여부를 체크하므로, SQS 재전송 시 동일 메시지의 중복 처리가 방지된다. 단, `sub_log`에 `pub_id`가 존재하지 않는 경우(최초 수신)의 INSERT 로직은 별도 확인 필요.

---

## 체크리스트

- [x] 인터페이스 목록 정의
- [x] 메시지 포맷 명세
- [x] DB 스키마 명세
- [x] 에러 코드/상태 코드 정의
- [x] 타당성 검토 포함

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 최초 작성 — SDD 5건 기반 인터페이스 추출 | jypark |
