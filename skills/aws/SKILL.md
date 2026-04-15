---
name: aws
description: >
  AWS 서비스 연동 스킬. Lambda(Python), SQS, SNS, Aurora MySQL, EC2, RDS Proxy, IAM, 보안 그룹을 다룬다.
  Lambda 함수 생성 시 Python 런타임 버전은 반드시 사용자에게 확인 후 결정한다.
  SQS/SNS는 Lambda 트리거 구성 중심이며 CI4 SDK 직접 연동은 포함하지 않는다.
  Lambda 핸들러 작성, IAM 최소 권한, 보안 그룹 설정, Aurora 연결 패턴을 정의한다.
triggers:
  - "Lambda 함수 만들어줘", "Lambda 작성", "Lambda 배포"
  - "SQS 트리거", "SNS 트리거", "이벤트 트리거"
  - "Aurora 연결", "RDS 연결", "DB 연결 패턴"
  - "EC2 설정", "인스턴스 생성", "보안 그룹 설정"
  - "RDS Proxy 설정", "커넥션 풀링"
  - "IAM 역할", "IAM 정책", "최소 권한"
  - AWS 관련 코드(Python Lambda, serverless.yml, SAM template) 작성/수정 시
version: 1.0.0
user-invocable: true
depends_on: [mysql8, security-audit]
conflicts_with: []
min_claude_md_version: "4.0"
---

# AWS Service Skill

AWS 서비스 연동을 위한 스킬. Lambda(Python)를 중심으로 SQS/SNS 트리거, Aurora MySQL 연결, EC2, RDS Proxy, IAM/보안 그룹 설정을 다룬다.

> **[Checkpoint 필수]** Lambda 함수를 새로 생성할 때, Python 런타임 버전을 반드시 사용자에게 확인받는다. 사용자에게 확인 후 버전을 지정한다.

---

## 1. Lambda (Python)

### 핸들러 기본 패턴

```python
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda 핸들러 진입점.

    @param event: 트리거 소스(SQS, SNS, API Gateway 등)에서 전달된 이벤트 데이터
    @param context: Lambda 런타임 컨텍스트 (함수명, 메모리, 제한시간 등)
    @return: 응답 객체 또는 처리 결과
    """
    try:
        logger.info(f"Event received: {json.dumps(event)}")

        result = process(event)

        return {
            "statusCode": 200,
            "body": json.dumps({"status": "success", "data": result})
        }
    except Exception as exception:
        logger.error(f"Handler error: {str(exception)}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"status": "error", "message": "Internal server error"})
        }


def process(event):
    """
    비즈니스 로직 처리.
    핸들러에서 분리하여 테스트 용이성을 확보한다.

    @param event: 이벤트 데이터
    @return: 처리 결과
    """
    # 비즈니스 로직 구현
    pass
```

### 핸들러 작성 규칙

| 규칙 | 설명 |
|------|------|
| **런타임 버전 확인** | Lambda 함수 신규 생성 시 Python 런타임 버전을 반드시 사용자에게 Checkpoint로 확인. 임의 지정 금지 |
| **핸들러 ≠ 비즈니스 로직** | `handler()`는 이벤트 파싱 + 응답 래핑만. 실제 로직은 별도 함수/모듈로 분리 |
| **환경변수 사용** | 시크릿, 엔드포인트, 설정값은 `os.environ.get()` 사용. 환경변수/시크릿 매니저로 관리한다 |
| **로깅 필수** | 모든 핸들러에 `logging` 모듈을 사용한다 |
| **에러 핸들링** | 최상위 `try-except`로 감싸고 에러 로깅. 내부 정보 외부 노출 금지 |
| **타임아웃 고려** | 외부 호출(DB, API)에 timeout 설정. Lambda 제한시간 내 완료 보장 |
| **멱등성** | SQS/SNS 트리거 시 동일 메시지 재처리에 안전해야 함 |

### 환경변수 관리

```python
# 환경변수에서 설정 로드 (하드코딩 절대 금지)
DB_HOST = os.environ.get("DB_HOST")
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
QUEUE_URL = os.environ.get("QUEUE_URL")
TOPIC_ARN = os.environ.get("TOPIC_ARN")
```

### 프로젝트 구조

```
lambda/
├── functions/
│   ├── {feature_name}/
│   │   ├── handler.py          # Lambda 핸들러 (진입점)
│   │   ├── service.py          # 비즈니스 로직
│   │   ├── repository.py       # DB 접근 (Aurora 연결)
│   │   └── requirements.txt    # 함수별 의존성
│   └── shared/
│       ├── db_connection.py    # Aurora 연결 공통 모듈
│       ├── sqs_client.py       # SQS 클라이언트 공통 모듈
│       └── sns_client.py       # SNS 클라이언트 공통 모듈
├── layers/
│   └── common/                 # 공통 레이어 (boto3 확장, 유틸리티)
└── tests/
    ├── unit/
    │   └── test_{feature_name}.py
    └── fixtures/
        └── events/             # 테스트용 이벤트 JSON
```

### 레이어 사용

- 공통 라이브러리(`pymysql`, 유틸리티 등)는 **Lambda Layer**로 분리
- 레이어 변경 시 모든 연결 함수에 영향이므로 **Checkpoint 발동**

---

## 2. SQS (Lambda 트리거)

### SQS → Lambda 트리거 핸들러 패턴

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    SQS 트리거 Lambda 핸들러.
    배치로 전달된 메시지를 개별 처리한다.

    @param event: SQS 이벤트 (Records 배열 포함)
    @param context: Lambda 컨텍스트
    @return: 부분 실패 시 batchItemFailures 반환
    """
    batch_item_failures = []

    for record in event.get("Records", []):
        message_id = record.get("messageId")
        try:
            body = json.loads(record.get("body", "{}"))
            logger.info(f"Processing message: {message_id}")

            process_message(body)

        except Exception as exception:
            logger.error(f"Failed to process message {message_id}: {str(exception)}", exc_info=True)
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}


def process_message(body):
    """
    개별 SQS 메시지 처리 로직.

    @param body: 파싱된 메시지 본문
    """
    # 비즈니스 로직 구현
    pass
```

### SQS 설정 규칙

| 항목 | 권장 설정 | 사유 |
|------|-----------|------|
| **ReportBatchItemFailures** | 활성화 | 부분 실패 시 실패 메시지만 재처리. 전체 배치 재처리 방지 |
| **Visibility Timeout** | Lambda 타임아웃 x 6 | 처리 중 메시지가 다른 소비자에게 전달되지 않도록 |
| **DLQ (Dead Letter Queue)** | 필수 설정, maxReceiveCount = 3 | 3회 실패 시 DLQ로 이동. 무한 재시도 방지 |
| **Batch Size** | 1~10 (기본 10) | 처리 시간에 따라 조정 |
| **메시지 포맷** | JSON | 구조화된 데이터 교환 |

### 멱등성 보장

```python
import hashlib

def is_already_processed(message_id, db_connection):
    """
    메시지 중복 처리를 방지한다.
    처리 완료된 message_id를 DB에 기록하고 조회한다.

    @param message_id: SQS 메시지 ID
    @param db_connection: DB 연결 객체
    @return: 이미 처리된 메시지이면 True
    """
    cursor = db_connection.cursor()
    cursor.execute(
        "SELECT COUNT(*) FROM processed_messages WHERE message_id = %s",
        (message_id,)
    )
    count = cursor.fetchone()[0]
    return count > 0


def mark_as_processed(message_id, db_connection):
    """
    메시지를 처리 완료로 기록한다.

    @param message_id: SQS 메시지 ID
    @param db_connection: DB 연결 객체
    """
    cursor = db_connection.cursor()
    cursor.execute(
        "INSERT IGNORE INTO processed_messages (message_id, processed_at) VALUES (%s, NOW())",
        (message_id,)
    )
    db_connection.commit()
```

---

## 3. SNS (Lambda 트리거)

### SNS → Lambda 트리거 핸들러 패턴

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    SNS 트리거 Lambda 핸들러.
    SNS 메시지를 파싱하여 처리한다.

    @param event: SNS 이벤트 (Records 배열 포함)
    @param context: Lambda 컨텍스트
    """
    for record in event.get("Records", []):
        sns_message = record.get("Sns", {})
        subject = sns_message.get("Subject", "")
        message_body = json.loads(sns_message.get("Message", "{}"))
        message_id = sns_message.get("MessageId", "")

        logger.info(f"SNS message received: {message_id}, subject: {subject}")

        try:
            process_notification(subject, message_body)
        except Exception as exception:
            logger.error(f"Failed to process SNS message {message_id}: {str(exception)}", exc_info=True)
            raise  # SNS는 DLQ 연동 시 예외를 다시 발생시켜야 재시도됨


def process_notification(subject, body):
    """
    SNS 알림 처리 로직.

    @param subject: SNS 메시지 제목 (라우팅 키로 활용)
    @param body: 파싱된 메시지 본문
    """
    # subject 기반 라우팅
    handlers = {
        "order.created": handle_order_created,
        "payment.completed": handle_payment_completed,
    }

    handler_function = handlers.get(subject)
    if handler_function:
        handler_function(body)
    else:
        logger.warning(f"Unknown SNS subject: {subject}")
```

### SNS 설정 규칙

| 항목 | 권장 설정 | 사유 |
|------|-----------|------|
| **메시지 필터링** | Subscription Filter Policy 사용 | 불필요한 Lambda 호출 방지 |
| **메시지 포맷** | JSON (MessageStructure) | 구조화된 데이터 교환 |
| **DLQ** | SNS 구독에 DLQ 설정 | 전달 실패 메시지 보존 |
| **Subject 활용** | 이벤트 타입을 Subject로 전달 | 핸들러 내 라우팅 키로 사용 |

### SNS → SQS → Lambda (Fan-out 패턴)

```
SNS Topic
  ├── SQS Queue A → Lambda A (주문 처리)
  ├── SQS Queue B → Lambda B (알림 발송)
  └── SQS Queue C → Lambda C (로그 기록)
```

- SNS에서 직접 Lambda를 트리거하면 재시도 제어가 어려우므로, **안정성이 필요한 경우 SNS → SQS → Lambda** 패턴을 권장
- Fan-out이 필요 없는 단순 트리거는 SNS → Lambda 직접 연결 허용

---

## 4. Aurora MySQL

### Lambda에서 Aurora 연결

```python
import pymysql
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 모듈 레벨에서 연결 객체 생성 (Lambda 컨테이너 재사용 시 연결 재활용)
connection = None

def get_connection():
    """
    Aurora MySQL 연결을 반환한다.
    Lambda 컨테이너 재사용 시 기존 연결을 재활용한다.
    연결이 끊어진 경우 재생성한다.

    @return: pymysql 연결 객체
    """
    global connection

    if connection is not None:
        try:
            connection.ping(reconnect=True)
            return connection
        except Exception:
            logger.warning("DB connection lost, reconnecting...")
            connection = None

    connection = pymysql.connect(
        host=os.environ.get("DB_HOST"),          # Writer 또는 Reader 엔드포인트
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD"),
        database=os.environ.get("DB_NAME"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
        read_timeout=10,
        write_timeout=10,
        autocommit=False
    )

    return connection
```

### Aurora 엔드포인트 규칙

| 엔드포인트 | 용도 | Lambda 환경변수 |
|-----------|------|----------------|
| **Writer (클러스터 엔드포인트)** | INSERT, UPDATE, DELETE | `DB_HOST_WRITER` |
| **Reader (리더 엔드포인트)** | SELECT (읽기 전용) | `DB_HOST_READER` |

- 읽기 전용 Lambda는 **Reader 엔드포인트**를 사용하여 Writer 부하를 줄인다
- 쓰기 작업이 포함된 Lambda는 **Writer 엔드포인트**를 사용한다
- Reader/Writer 엔드포인트를 하나의 환경변수로 통합하지 않는다

### 페일오버 대응

```python
import pymysql

MAX_RETRY = 3

def execute_with_failover(query, params=None, is_write=False):
    """
    Aurora 페일오버 시 재연결 후 재시도한다.

    @param query: 실행할 SQL 쿼리
    @param params: 바인딩 파라미터
    @param is_write: 쓰기 작업 여부 (True이면 Writer 엔드포인트)
    @return: 쿼리 결과
    """
    for attempt in range(MAX_RETRY):
        try:
            conn = get_connection()
            with conn.cursor() as cursor:
                cursor.execute(query, params)
                if is_write:
                    conn.commit()
                return cursor.fetchall()
        except pymysql.err.OperationalError as error:
            logger.warning(f"DB OperationalError (attempt {attempt + 1}/{MAX_RETRY}): {error}")
            global connection
            connection = None  # 연결 초기화하여 다음 시도 시 재연결
            if attempt == MAX_RETRY - 1:
                raise
```

### mysql8-skill 연동

Lambda에서 Aurora 쿼리 작성 시에도 `mysql8-skill`의 규칙을 동일하게 적용한다:
- 표준 ANSI SQL 우선
- `SELECT *` 금지, 필요 컬럼만 명시
- N+1 방지
- 쿼리 힌트 지양

---

## 5. EC2

### 인스턴스 프로비저닝 규칙

- 인스턴스 타입 선택 시 **사용자 확인 필수** (t3.micro vs t3.small 등)
- AMI는 **Amazon Linux 2023** 또는 **Ubuntu 22.04 LTS** 기본. 다른 AMI 사용 시 사용자 확인
- 키페어는 **기존 키 사용 우선**, 신규 생성 시 사용자 승인

### 보안 그룹

```
sg-ec2:
  - Inbound:  사용자가 명시한 포트만 허용 (예: 22/SSH, 80/HTTP, 443/HTTPS)
  - Outbound: 0.0.0.0/0 허용 (기본) 또는 사용자 지정
  - SSH(22): 특정 IP 대역만 허용. 0.0.0.0/0 절대 금지 → Checkpoint 발동
```

### IAM 역할 바인딩

- EC2에는 **IAM Instance Profile**을 통해 역할 부여. IAM Instance Profile로 인증한다
- S3, SQS 등 접근 시 Instance Profile 권한으로 처리

### 사용자 데이터 스크립트

```bash
#!/bin/bash
# 사용자 데이터 스크립트 규칙:
# - 시크릿은 SSM Parameter Store 또는 Secrets Manager로 관리한다
# - 로그는 /var/log/user-data.log에 기록
# - 실패 시 CloudWatch에 알림 전송
```

### 자가 검증 체크리스트

- [ ] 보안 그룹에 SSH 0.0.0.0/0 미허용
- [ ] IAM Instance Profile 사용 (액세스 키 미사용)
- [ ] 사용자 데이터에 시크릿 하드코딩 미포함
- [ ] 인스턴스 타입/AMI 사용자 확인 완료

---

## 6. RDS Proxy

### 역할

Lambda → Aurora MySQL 연결 시 **커넥션 풀 고갈(connection exhaustion)을 방지**하는 프록시 레이어.
Lambda의 동시 실행 수가 급증해도 RDS Proxy가 커넥션 풀을 관리하여 Aurora에 대한 연결 수를 제한한다.

### 설정 규칙

```
RDS Proxy 설정:
- Engine: MySQL
- IAM Authentication: 활성화 (Secrets Manager 연동)
- Idle Client Timeout: 1800초 (기본)
- Max Connections: Aurora 인스턴스 max_connections의 80%
- Connection Borrow Timeout: 120초
```

### Lambda 연결 패턴

```python
import pymysql
import os

# RDS Proxy 엔드포인트 사용 (Aurora 직접 엔드포인트 아님)
PROXY_ENDPOINT = os.environ['RDS_PROXY_ENDPOINT']
DB_NAME = os.environ['DB_NAME']

# IAM 인증 사용 시
import boto3
def get_auth_token():
    client = boto3.client('rds')
    return client.generate_db_auth_token(
        DBHostname=PROXY_ENDPOINT,
        Port=3306,
        DBUsername=os.environ['DB_USER'],
        Region=os.environ['AWS_REGION']
    )

connection = None

def get_connection():
    global connection
    if connection is None or not connection.open:
        connection = pymysql.connect(
            host=PROXY_ENDPOINT,
            user=os.environ['DB_USER'],
            password=get_auth_token(),  # IAM 인증 토큰
            database=DB_NAME,
            connect_timeout=5,
            ssl={'ssl': True}
        )
    return connection
```

### 핵심 규칙

- Lambda에서 Aurora는 RDS Proxy를 경유한다
- Aurora Writer/Reader 엔드포인트 대신 **Proxy 엔드포인트** 사용
- IAM 인증 활성화 시 **Secrets Manager에 DB 자격 증명 저장** 필수
- 페일오버 시 RDS Proxy가 자동으로 새 인스턴스로 라우팅 — 애플리케이션 레벨 재연결 로직 불필요
- VPC 내 Lambda + RDS Proxy + Aurora 모두 **동일 VPC, 프라이빗 서브넷** 배치

### 자가 검증 체크리스트

- [ ] Lambda가 Aurora 직접 엔드포인트 대신 Proxy 엔드포인트를 사용하는가
- [ ] IAM 인증이 활성화되어 있는가
- [ ] Secrets Manager에 DB 자격 증명이 저장되어 있는가
- [ ] Max Connections가 Aurora max_connections의 80% 이하인가
- [ ] Lambda, RDS Proxy, Aurora가 동일 VPC 프라이빗 서브넷에 있는가

---

## 7. IAM

### 최소 권한 원칙

Lambda 실행 역할에는 **필요한 권한만** 부여한다.

| Lambda 용도 | 필요 권한 |
|-------------|-----------|
| SQS 트리거 | `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` |
| SNS 트리거 | (SNS가 Lambda를 호출하므로 Lambda 쪽 SQS 권한 불필요, 리소스 기반 정책 사용) |
| Aurora 접근 | VPC 접근 (`ec2:CreateNetworkInterface`, `ec2:DescribeNetworkInterfaces`, `ec2:DeleteNetworkInterface`) |
| SQS 발행 | `sqs:SendMessage` (특정 큐 ARN에 한정) |
| SNS 발행 | `sns:Publish` (특정 토픽 ARN에 한정) |
| CloudWatch 로그 | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` |

### IAM 규칙

| 규칙 | 설명 |
|------|------|
| **와일드카드 리소스 제한** | `Resource`는 특정 ARN으로 제한한다 |
| **인라인 정책 지양** | 관리형 정책 또는 고객 관리형 정책 사용 |
| **역할 분리** | Lambda 함수별로 별도 IAM 역할 생성. 하나의 역할을 여러 함수가 공유하지 않음 |
| **액세스 키 미사용** | Lambda는 IAM 역할로 인증. 액세스 키 하드코딩/환경변수 주입 금지 |
| **키 관리** | EC2 등 외부 환경에서 AWS 접근 시 IAM 인스턴스 프로파일 또는 Secrets Manager 사용 |

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes"
            ],
            "Resource": "arn:aws:sqs:ap-northeast-1:123456789012:specific-queue-name"
        }
    ]
}
```

---

## 8. 보안 그룹

### Lambda VPC 설정

Lambda가 Aurora에 접근하려면 **VPC 내에 배치**해야 한다.

| 설정 | 권장값 |
|------|--------|
| **서브넷** | 프라이빗 서브넷 2개 이상 (Multi-AZ) |
| **보안 그룹** | Lambda 전용 보안 그룹 생성 |
| **NAT Gateway** | Lambda가 외부 API 호출 필요 시 NAT Gateway 필수 |

### 보안 그룹 규칙

#### Lambda 보안 그룹 (sg-lambda)

| 방향 | 프로토콜 | 포트 | 대상 | 사유 |
|------|----------|------|------|------|
| **Outbound** | TCP | 3306 | sg-aurora | Aurora 연결 |
| **Outbound** | TCP | 443 | 0.0.0.0/0 | AWS API 호출 (SQS, SNS 등) |

#### Aurora 보안 그룹 (sg-aurora)

| 방향 | 프로토콜 | 포트 | 대상 | 사유 |
|------|----------|------|------|------|
| **Inbound** | TCP | 3306 | sg-lambda | Lambda에서 DB 접근 허용 |
| **Inbound** | TCP | 3306 | sg-ec2 | EC2(CI4 서버)에서 DB 접근 허용 |

#### EC2 보안 그룹 (sg-ec2)

| 방향 | 프로토콜 | 포트 | 대상 | 사유 |
|------|----------|------|------|------|
| **Inbound** | TCP | 443 | ALB 보안 그룹 또는 0.0.0.0/0 | HTTPS 트래픽 |
| **Inbound** | TCP | 22 | 관리자 IP만 | SSH (특정 IP 제한 필수) |
| **Outbound** | TCP | 3306 | sg-aurora | Aurora 연결 |
| **Outbound** | TCP | 443 | 0.0.0.0/0 | 외부 API, AWS API 호출 |

### 보안 그룹 규칙

| 규칙 | 설명 |
|------|------|
| **0.0.0.0/0 Inbound 최소화** | SSH는 관리자 IP만, HTTP/HTTPS는 ALB 경유 |
| **보안 그룹 간 참조** | IP 대신 보안 그룹 ID로 참조 (sg-xxx). IP 변경에 안전 |
| **포트 범위 제한** | `0-65535` 같은 범위 대신 필요한 포트만 명시적으로 개방한다 |
| **변경 시 Checkpoint** | 보안 그룹 규칙 추가/수정/삭제 시 반드시 사용자 승인 |

---

## 9. 공통 규칙

### 시크릿 관리

| 구분 | 방법 | 금지 사항 |
|------|------|-----------|
| **Lambda** | 환경변수 + KMS 암호화 또는 Secrets Manager | 코드에 하드코딩 |
| **EC2** | IAM 인스턴스 프로파일 + Secrets Manager | 액세스 키 `.env` 파일 저장 |
| **Aurora** | Secrets Manager 자동 로테이션 권장 | 비밀번호 코드/환경변수 직접 기입 |

### 주석 규칙

Lambda Python 코드에도 `php8.x+ci4.x-skill` §6과 동일한 주석 규칙을 적용한다:
- 모든 함수에 docstring 필수 (`@param`, `@return` 포함)
- 복잡한 로직에 단계별 설명 주석
- 추상화 시 사유 주석

### 테스트

```python
import json
import pytest
from functions.{feature_name}.handler import handler, process_message

class TestHandler:
    """Lambda 핸들러 테스트."""

    def test_sqs_trigger_success(self):
        """SQS 트리거 정상 처리를 검증한다."""
        event = {
            "Records": [
                {
                    "messageId": "test-message-001",
                    "body": json.dumps({"action": "test", "data": {"id": 1}})
                }
            ]
        }
        result = handler(event, None)
        assert result["batchItemFailures"] == []

    def test_sqs_trigger_partial_failure(self):
        """SQS 배치 부분 실패 시 실패 메시지만 반환한다."""
        event = {
            "Records": [
                {"messageId": "msg-ok", "body": json.dumps({"valid": True})},
                {"messageId": "msg-fail", "body": "invalid json"},
            ]
        }
        result = handler(event, None)
        failed_ids = [item["itemIdentifier"] for item in result["batchItemFailures"]]
        assert "msg-fail" in failed_ids
        assert "msg-ok" not in failed_ids

    def test_handler_with_empty_event(self):
        """빈 이벤트 수신 시 에러 없이 처리한다."""
        result = handler({"Records": []}, None)
        assert result["batchItemFailures"] == []
```

---

## 10. 메시징 아키텍처 (SNS + SQS + Lambda)

| 구성 요소 | 역할 | 비고 |
|-----------|------|------|
| **SNS** | 이벤트 발행 (Pub) | 토픽별 도메인 이벤트 분류 |
| **SQS (FIFO)** | 이벤트 구독 (Sub) | 순서 보장, 중복 제거(deduplication) |
| **Lambda** | 이벤트 처리 | SQS 트리거, 배치 부분 실패 처리 |

- SNS → SQS → Lambda 파이프라인이 기본 패턴
- FIFO 큐 사용 시 `MessageGroupId`로 순서 보장 범위 지정
- DLQ(Dead Letter Queue) 필수 설정 — 3회 재시도 후 DLQ 이동

## 11. S3 / CloudFront 스토리지 정책

| 항목 | 설정 |
|------|------|
| **S3 버킷** | 국가별 분리 또는 prefix 분리 (`us/`, `kr/`, `jp/`) |
| **CloudFront** | S3 Origin Access Control(OAC)로 직접 접근 차단 |
| **CRR (Cross-Region Replication)** | 글로벌 확장 시 리전 간 복제 검토 (비용 대비 레이턴시 이점 평가) |
| **버저닝** | 프로덕션 버킷 버저닝 활성화 |
| **수명 주기** | 비활성 객체 90일 후 Glacier 전환 검토 |

- S3 퍼블릭 접근 차단 (Block Public Access 활성화)
- CloudFront 캐시 무효화는 배포 스크립트에 포함

---

## Mental Dry-Run (코드 사전 검증, 필수)

AWS 관련 코드 생성·수정 시, **실제 파일에 기록하기 전에** 다음 절차를 반드시 수행한다.

1. **1차 작성** — 응답(메모리) 상에서만 코드를 작성한다. 실제 파일에는 기록하지 않는다.
2. **1차 재검토** — 작성한 코드를 스킬 규칙·자가 검증 체크리스트 기준으로 검토한다.
3. **2차 재검토** — 엣지 케이스, 사이드 이펙트, 기존 코드와의 정합성을 추가 검토한다.
4. **파일 반영** — 2회 검토 후 문제가 없다고 판단될 경우에만 실제 파일에 기록한다.

> 검토 중 문제가 발견되면 메모리 상에서 수정 후 다시 1차 재검토부터 반복한다.

---

## 자가 검증 체크리스트

AWS 관련 코드 작성/수정 시 반드시 확인:
- [ ] Lambda 핸들러와 비즈니스 로직이 분리되어 있는가
- [ ] 환경변수로 설정값을 관리하고 있는가 (하드코딩 없음)
- [ ] SQS 트리거 시 `batchItemFailures` 부분 실패 처리가 구현되어 있는가
- [ ] SQS에 DLQ가 설정되어 있는가
- [ ] 멱등성이 보장되는가 (중복 메시지 안전 처리)
- [ ] Aurora 연결 시 Reader/Writer 엔드포인트를 구분하고 있는가
- [ ] Aurora 연결에 타임아웃과 페일오버 재시도가 구현되어 있는가
- [ ] IAM 역할이 최소 권한 원칙을 준수하는가 (와일드카드 Resource 없음)
- [ ] Lambda IAM 역할로 인증하고, 액세스 키를 사용하지 않는가
- [ ] 보안 그룹이 필요한 포트만 개방하고 보안 그룹 간 참조를 사용하는가
- [ ] 모든 함수에 docstring이 있는가
- [ ] 테스트 코드가 포함되어 있는가

---

## 참고: EC2 인증서 파일

| 항목 | 값 |
|------|-----|
| 설정 파일 | `~/.claude/.config` (`EC2_HOST`, `EC2_USER`, `EC2_PEM`) |
| 용도 | EC2 SSH 접속용 (현재 키 불일치로 사용 불가) |
| 접속 방식 | **SSM Session Manager** 경유 필수 |

## 참고: .env 비밀번호 관리 가이드

| 환경 | 방식 | 비고 |
|------|------|------|
| **개발 (로컬)** | `.env` 파일에 평문 저장 허용 | `.gitignore`로 커밋 차단 필수 |
| **프로덕션 (EC2)** | `/works/<PROJECT>/config/.env` symlink | 릴리즈별 `.env` symlink 참조, 서버 내 파일 직접 관리 |

> 프로덕션 DB 비밀번호가 `.env` 평문 저장인 점은 현재 운영 방식. 향후 AWS Secrets Manager 전환 권장.
