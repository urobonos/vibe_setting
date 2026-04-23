# SDD: Lambda logpull (KOR 중앙 로그 수집)

> SDD: Lambda logpull (KOR 중앙 로그 수집)

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

HongCafe Global 서비스는 USA(us-east-1), KOR(ap-northeast-2), JPN(ap-northeast-1) 3개국 Aurora DB에 동기화 수신 로그(`global_sync_sub_log`)를 분산 저장한다. 이 구조에서는 전체 동기화 상태를 한 곳에서 파악할 수 없고, 실패 건 감지를 위해 3개 리전 CloudWatch를 개별 확인해야 한다.

`prod_lambda_hongcafe_logpull_kor`은 KOR(ap-northeast-2)에 위치하여 USA/JPN Aurora의 동기화 로그를 주기적으로 수집하고, KOR Aurora 중앙 저장소에 통합한다. 이를 통해 단일 대시보드 모니터링, 실패 알림 중앙화, 발행-수신 정합성 검증이 가능해진다.

### 1.2 범위

| 항목 | 내용 |
|------|------|
| 수집 소스 | USA Aurora(us-east-1), JPN Aurora(ap-northeast-1) — `global_sync_sub_log` |
| 수집 대상 (추정) | `global_sync_pub_log` — 존재 여부 확인 필요 |
| 저장 위치 | KOR Aurora(ap-northeast-2) — `global_sync_monitor_log` |
| 트리거 | EventBridge (스케줄, 5분 또는 15분) |
| 런타임 | Python 3.12 |
| 상태 | **미구현** (계획 — `lambda/kor/logpull/` 디렉토리 미생성) |

### 1.3 관련 문서

| 문서 | 경로 |
|------|------|
| Lambda Pub/Sub SDD | `docs/output/specs/lambda-pubsub-sdd.md` |
| 인프라 구성 | `docs/infrastructure.md` |
| logpull 분석 | `docs/tasks/20260409/lambda-logpull/lambda-logpull-analyze.md` |
| Lambda 함수 목록 | `lambda/README.md` |

---

## 2. 아키텍처

### 2.1 전체 흐름

logpull은 KOR에 단독으로 위치하여 주기적으로 원격 국가 DB에 접근, 로그를 수집하여 KOR Aurora에 저장한다.

```
EventBridge (KOR, ap-northeast-2)
    rate(5 minutes) 또는 cron
         │
         ▼
prod_lambda_hongcafe_logpull_kor (ap-northeast-2)
         │
         ├──[크로스리전 접속]──> USA Aurora (us-east-1)
         │                       SELECT global_sync_sub_log
         │                       WHERE collected_at > watermark
         │
         ├──[크로스리전 접속]──> JPN Aurora (ap-northeast-1)
         │                       SELECT global_sync_sub_log
         │                       WHERE collected_at > watermark
         │
         ▼
KOR Aurora (ap-northeast-2)
    INSERT INTO global_sync_monitor_log
```

### 2.2 아키텍처 다이어그램 — Pub/Sub 시스템과의 관계

```
                    ┌──────────────────────────────────────┐
                    │   SNS FIFO (KOR: ap-northeast-2)     │
                    │   prod_sns_hongcafe_global.fifo      │
                    └──┬──────────┬──────────┬─────────────┘
                       │          │          │
              subscribe│          │          │subscribe
                       ▼          ▼          ▼
  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐
  │ SQS FIFO (USA)  │  │ SQS FIFO (KOR)   │  │ SQS FIFO (JPN)  │
  └────────┬────────┘  └────────┬─────────┘  └────────┬────────┘
           │                    │                      │
           ▼                    ▼                      ▼
  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐
  │ Lambda sqs_push │  │ Lambda sqs_push  │  │ Lambda sqs_push │
  │ (USA)           │  │ (KOR, 스켈레톤)  │  │ (JPN, 스켈레톤) │
  └────────┬────────┘  └──────────────────┘  └────────┬────────┘
           │                                           │
           ▼                                           ▼
  ┌─────────────────┐                       ┌─────────────────┐
  │ USA Aurora      │                       │ JPN Aurora      │
  │ global_sync_    │                       │ global_sync_    │
  │ sub_log         │◄─────────────────────►│ sub_log         │
  └────────▲────────┘      logpull 수집      └────────▲────────┘
           │                                           │
           └──────────────────┬────────────────────────┘
                              │ SELECT (크로스리전)
                              ▼
                    ┌─────────────────────────────────────┐
                    │ prod_lambda_hongcafe_logpull_kor     │
                    │ (KOR, ap-northeast-2)                │
                    │                                      │
                    │ EventBridge → 5분 주기               │
                    └──────────────┬──────────────────────┘
                                   │ INSERT
                                   ▼
                    ┌─────────────────────────────────────┐
                    │ KOR Aurora (ap-northeast-2)          │
                    │ global_sync_monitor_log              │
                    │ logpull_watermark                    │
                    └──────────────────────────────────────┘
```

### 2.3 크로스리전 접속 방식 선택

분석 문서(`analyze.md`)에서 비교한 3가지 옵션 중 **옵션 A (VPC Peering + 직접 접속)**을 중장기 권장안으로 선택한다. 단기 대안으로 **옵션 B (SNS/SQS 중계)**도 기술한다.

> **확인 필요:** VPC Peering 구성 예산 및 보안 정책 승인 후 최종 방식 결정. 현재 이 SDD는 옵션 A 기준으로 설계하되, 옵션 B 대안을 3.3절에 병기한다.

---

## 3. 컴포넌트 상세

### 3.1 Lambda 함수 스펙

| 속성 | 값 |
|------|-----|
| 함수명 | `prod_lambda_hongcafe_logpull_kor` |
| 리전 | ap-northeast-2 (KOR) |
| Runtime | Python 3.12 |
| Handler | `lambda_function.lambda_handler` (계획) |
| Timeout | 300초 (5분, 크로스리전 DB 접속 고려) |
| Memory | 256MB (다중 DB 커서 유지) |
| 트리거 | EventBridge `rate(5 minutes)` |
| VPC | KOR VPC 프라이빗 서브넷 (확인 필요) |
| Layer | KOR Lambda Layer (pymysql 포함, 확인 필요) |

**환경변수 (추정):**

```json
{
  "RDS_CONFIG_KOR": {
    "REGION": "ap-northeast-2",
    "ENDPOINT": "prod-rdsproxy-hongcafe-kor.proxy-xxxx.ap-northeast-2.rds.amazonaws.com",
    "PORT": 3306,
    "USER": "admin"
  },
  "RDS_CONFIG_USA": {
    "REGION": "us-east-1",
    "ENDPOINT": "prod-aurora-hongcafe-usa.cluster-xxxx.us-east-1.rds.amazonaws.com",
    "PORT": 3306,
    "USER": "logpull_reader"
  },
  "RDS_CONFIG_JPN": {
    "REGION": "ap-northeast-1",
    "ENDPOINT": "prod-aurora-hongcafe-jpn.cluster-xxxx.ap-northeast-1.rds.amazonaws.com",
    "PORT": 3306,
    "USER": "logpull_reader"
  },
  "COLLECT_INTERVAL_MINUTES": "5",
  "BATCH_SIZE": "500"
}
```

> **확인 필요:** KOR/JPN RDS Proxy 엔드포인트는 `infrastructure.md`에 미기재. 실제 구현 전 확인 필요.

### 3.2 코드 구조

기존 sqs_push Lambda 코드 구조와 일관성을 유지한다.

> ⚠️ sqs_push는 `handler.py` + `handler.handler` 방식을 사용하므로, logpull도 동일 패턴(`handler.py` + `handler.handler`) 채택을 권장한다. 아래 구조는 초기 설계안이며, 구현 시 파일명/핸들러명을 sqs_push와 통일할지 결정 필요.

```
lambda/kor/logpull/
├── lambda_function.py          — 엔트리포인트 (EventBridge 트리거 수신)
├── handlers/
│   ├── __init__.py
│   └── logpull_handler.py      — 국가별 로그 수집 오케스트레이터
├── collectors/
│   ├── __init__.py
│   ├── usa_collector.py        — USA Aurora 로그 수집
│   └── jpn_collector.py        — JPN Aurora 로그 수집
└── lib/
    ├── __init__.py
    └── multi_db_connection.py  — 다중 리전 DB 연결 관리
```

### 3.3 수집 대상 데이터

#### 3.3.1 `global_sync_sub_log` (각 국가 수신 로그)

수집 대상 컬럼 (lambda-pubsub-sdd.md 기준):

| 컬럼 | 타입 (추정) | 수집 이유 |
|------|-------------|---------|
| `sub_log_seq` | BIGINT, PK | watermark 기준, 원본 식별자 |
| `pub_country` | VARCHAR(2) | 발행 국가 (KR/US/JP) |
| `msg_id` | VARCHAR | 메시지 고유 ID (정합성 검증) |
| `msg_group_id` | VARCHAR | 이벤트 유형 (예: KR:ACCOUNT:CREATE:7) |
| `sub_status` | TINYINT | 처리 상태 (실패 감지 핵심) |
| `retry_count` | INT | 재시도 횟수 (장애 심각도 판단) |
| `last_error` | TEXT | 에러 내용 (원인 분석) |
| `reg_date` | DATETIME | 수신 일시 |

**수집 우선순위:**
1. `sub_status IN (0, 1, 2)` — 미완료/실패 건: 전건 수집
2. `sub_status = 3` — 완료 건: 통계 집계만 (건수, 최신 처리일시)

#### 3.3.2 `global_sync_pub_log` (각 국가 발행 로그, 확인 필요)

> **확인 필요:** `lambda/README.md` 아키텍처 다이어그램에 `global_sync_pub_log`가 언급되어 있으나, 실제 테이블 존재 여부 및 컬럼 구성은 각 국가 Aurora에서 `DESCRIBE global_sync_pub_log` 실행 후 확인 필요. 존재하는 경우 동일한 수집 로직 적용.

### 3.4 수집 방식 — 옵션 A: VPC Peering 직접 접속 (권장)

```
KOR Lambda (ap-northeast-2 VPC)
    │
    │ VPC Peering
    ├──────────────> USA VPC (us-east-1)
    │                └─ Aurora 클러스터 직접 접속 (RDS Proxy 제외)
    │                   host: prod-aurora-hongcafe-usa.cluster-xxxx.us-east-1.rds.amazonaws.com
    │
    └──────────────> JPN VPC (ap-northeast-1)
                     └─ Aurora 클러스터 직접 접속
                        host: prod-aurora-hongcafe-jpn.cluster-xxxx.ap-northeast-1.rds.amazonaws.com
```

**RDS Proxy 제외 이유:**
RDS Proxy는 동일 리전의 VPC 내 클라이언트만 지원한다. 크로스리전 접속은 Aurora 클러스터 엔드포인트에 직접 접속해야 한다.

**접속 계정:**
`logpull_reader` — SELECT 권한만 부여한 읽기 전용 DB 사용자. 최소 권한 원칙(Principle of Least Privilege) 적용.

### 3.5 수집 방식 — 옵션 B: SNS/SQS 중계 (단기 대안)

VPC Peering 구성이 지연되는 경우, 기존 SNS/SQS 인프라를 재사용하는 방식:

```
각 국가 Lambda (sqs_push or 별도 logpub)
    │ EventBridge rate(5 minutes)
    │ SELECT FROM global_sync_sub_log (로컬 Aurora)
    │ SNS Publish → prod_sns_hongcafe_logpull.fifo (KOR)
    │
    ▼
prod_sqs_hongcafe_logpull_kor.fifo (ap-northeast-2)
    │ SQS Trigger
    │
    ▼
prod_lambda_hongcafe_logpull_kor
    │ INSERT INTO global_sync_monitor_log
    ▼
KOR Aurora
```

> 이 방식은 각 국가에 logpub Lambda 추가 배포가 필요하며, 관리 포인트가 증가한다. 옵션 A 구성 완료 후 logpub Lambda는 제거 가능.

---

## 4. 처리 로직

### 4.1 수집 주기

| 옵션 | 스케줄 | 적합한 경우 |
|------|--------|-----------|
| **5분 (권장)** | `rate(5 minutes)` | 실시간성 모니터링, 빠른 실패 감지 필요 시 |
| 15분 | `rate(15 minutes)` | 트래픽/비용 최소화 우선 시 |

> 초기 구현은 5분 주기로 설정하고, 실제 트래픽 규모 확인 후 조정.

### 4.2 수집 쿼리

#### 미완료/실패 건 전수 수집

```sql
-- USA/JPN Aurora에서 실행 (watermark 기반)
SELECT
    sub_log_seq,
    pub_country,
    msg_id,
    msg_group_id,
    sub_status,
    retry_count,
    last_error,
    reg_date
FROM global_sync_sub_log
WHERE sub_log_seq > %(last_collected_seq)s
  AND sub_status IN (0, 1, 2)
ORDER BY sub_log_seq ASC
LIMIT %(batch_size)s;
```

#### 완료 건 집계

```sql
-- 최근 수집 주기 내 완료 건 통계
SELECT
    pub_country,
    COUNT(*) AS completed_count,
    MAX(reg_date) AS latest_completed_at
FROM global_sync_sub_log
WHERE sub_log_seq > %(last_collected_seq)s
  AND sub_status = 3
GROUP BY pub_country;
```

### 4.3 중복 방지 — watermark 기반

watermark 방식: 마지막으로 수집한 `sub_log_seq`(PK, AUTO_INCREMENT)를 KOR Aurora의 `logpull_watermark` 테이블에 저장. 다음 실행 시 `WHERE sub_log_seq > last_seq`로 신규 건만 수집.

```
logpull_watermark 테이블:
  source_country VARCHAR(2) PK  -- 'US', 'JP'
  last_seq       BIGINT         -- 마지막 수집된 sub_log_seq
  collected_at   DATETIME       -- 마지막 수집 일시
```

**seq 기반 watermark 선택 이유:**
- `reg_date` (DATETIME) 기반은 동시 삽입 시 누락 가능성 있음
- AUTO_INCREMENT PK는 단조 증가가 보장되어 누락 없음
- FIFO 큐 방식이 아닌 직접 SELECT이므로 중복 없이 신규 건만 처리 가능

### 4.4 처리 흐름 — 의사코드

```
lambda_handler(event, context):
    # 1. EventBridge 트리거 확인
    if not is_scheduled_event(event):
        raise ValueError("Unsupported trigger type")

    # 2. KOR Aurora 연결 (watermark 조회 및 결과 저장용)
    kor_conn = get_connection(config=RDS_CONFIG_KOR)

    # 3. 국가별 수집 실행
    for source_country in ['US', 'JP']:
        watermark = get_watermark(kor_conn, source_country)
        source_conn = get_connection(config=RDS_CONFIG_{source_country})

        # 4. 원격 DB에서 로그 수집
        rows = collect_sub_logs(source_conn, watermark.last_seq, BATCH_SIZE)
        stats = collect_sub_log_stats(source_conn, watermark.last_seq)

        if not rows and not stats:
            continue

        # 5. KOR Aurora에 저장
        with kor_conn.cursor() as cursor:
            insert_monitor_logs(cursor, source_country, rows)
            upsert_monitor_stats(cursor, source_country, stats)
            update_watermark(cursor, source_country, max(row.sub_log_seq for row in rows))
        kor_conn.commit()
```

### 4.5 에러 핸들링

| 에러 유형 | 처리 방식 |
|----------|---------|
| 원격 Aurora 접속 실패 | 해당 국가 건너뛰고 다음 국가 처리, CloudWatch 에러 로그 |
| 수집 쿼리 실패 | 해당 국가 건너뛰기, watermark 갱신 안 함 (다음 주기 재시도) |
| KOR Aurora 저장 실패 | rollback 후 Lambda 실패 반환 (EventBridge 재시도 없음, 다음 주기에 재수집) |
| watermark 조회 실패 | 안전 기본값(0)으로 전체 재수집, 경고 로그 |
| Lambda Timeout | 수집 중 commit 완료된 건은 watermark 갱신됨, 미완료 건은 다음 주기에 처리 |

> **설계 방침:** logpull은 모니터링 목적의 보조 시스템이다. 수집 실패가 서비스 동기화 자체에 영향을 주어서는 안 된다. 따라서 개별 국가 수집 실패는 경고 처리하고 나머지 국가 수집을 계속 진행한다.

---

## 5. 데이터 모델

### 5.1 `global_sync_monitor_log` — 미완료/실패 건 상세

```sql
CREATE TABLE global_sync_monitor_log (
    monitor_log_seq  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '수집 로그 시퀀스',
    source_country   VARCHAR(2)    NOT NULL                COMMENT '수집 소스 국가 (US, JP)',
    sub_log_seq      BIGINT        NOT NULL                COMMENT '원본 sub_log_seq',
    pub_country      VARCHAR(2)    NOT NULL                COMMENT '발행 국가 (KR, US, JP)',
    msg_id           VARCHAR(128)  NOT NULL                COMMENT '메시지 고유 ID',
    msg_group_id     VARCHAR(128)  NOT NULL                COMMENT '메시지 그룹 ID',
    sub_status       TINYINT       NOT NULL DEFAULT 0      COMMENT '동기화 상태 (0=대기, 1=처리중, 2=실패, 3=완료)',
    retry_count      INT           NOT NULL DEFAULT 0      COMMENT '재시도 횟수',
    last_error       TEXT                                  COMMENT '마지막 에러 메시지',
    reg_date         DATETIME      NOT NULL                COMMENT '원본 수신 일시',
    collected_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'logpull 수집 일시',
    PRIMARY KEY (monitor_log_seq),
    UNIQUE KEY uq_source_sub_log (source_country, sub_log_seq),
    INDEX idx_sub_status (sub_status),
    INDEX idx_source_country (source_country),
    INDEX idx_collected_at (collected_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='크로스리전 동기화 수신 로그 중앙 수집';
```

### 5.2 `global_sync_monitor_stats` — 완료 건 집계

```sql
CREATE TABLE global_sync_monitor_stats (
    stats_seq           BIGINT   NOT NULL AUTO_INCREMENT COMMENT '통계 시퀀스',
    source_country      VARCHAR(2) NOT NULL              COMMENT '수집 소스 국가 (US, JP)',
    collected_at        DATETIME NOT NULL                COMMENT '집계 기준 수집 일시',
    completed_count     INT      NOT NULL DEFAULT 0      COMMENT '완료 건수',
    latest_completed_at DATETIME                         COMMENT '가장 최근 완료 일시',
    PRIMARY KEY (stats_seq),
    INDEX idx_source_collected (source_country, collected_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='크로스리전 동기화 완료 건 주기별 집계';
```

### 5.3 `logpull_watermark` — 수집 위치 추적

```sql
CREATE TABLE logpull_watermark (
    source_country VARCHAR(2) NOT NULL COMMENT '수집 소스 국가 (US, JP)',
    last_seq       BIGINT     NOT NULL DEFAULT 0 COMMENT '마지막 수집된 sub_log_seq',
    collected_at   DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '마지막 수집 일시',
    PRIMARY KEY (source_country)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='logpull watermark (수집 위치 추적)';

-- 초기값 삽입
INSERT INTO logpull_watermark (source_country, last_seq) VALUES ('US', 0), ('JP', 0);
```

### 5.4 기존 테이블과의 관계

```
[USA Aurora]                    [KOR Aurora]
global_sync_sub_log  ──수집──>  global_sync_monitor_log
(sub_log_seq PK)                (source_country='US', sub_log_seq)

[JPN Aurora]                    [KOR Aurora]
global_sync_sub_log  ──수집──>  global_sync_monitor_log
(sub_log_seq PK)                (source_country='JP', sub_log_seq)

                                [KOR Aurora]
                                logpull_watermark
                                (source_country PK, last_seq)

                                [KOR Aurora]
                                global_sync_sub_log  ← 기존 테이블 (KOR 자체 수신 로그)
                                (logpull 수집 대상 아님, 로컬에서 직접 관리)
```

> **설계 결정:** KOR 자체 `global_sync_sub_log`는 logpull 수집 대상이 아니다. KOR는 SNS 허브 리전이므로 로컬 Lambda가 직접 관리한다. logpull은 KOR가 직접 접근할 수 없는 USA/JPN 로그만 수집한다.

---

## 6. 보안

### 6.1 크로스리전 DB 접근 보안

#### VPC Peering 구성 (옵션 A 기준)

```
KOR VPC (ap-northeast-2) ──Peering──> USA VPC (us-east-1)
KOR VPC (ap-northeast-2) ──Peering──> JPN VPC (ap-northeast-1)
```

| 항목 | 설정 |
|------|------|
| VPC Peering 암호화 | 없음 (AWS 내부 백본 — 인터넷 경유 아님) |
| TLS | Aurora 연결 시 SSL 강제 (`ssl={"ssl": True}`, 기존 db_connection.py 패턴 동일) |
| 보안 그룹 | USA/JPN Aurora 보안 그룹 인바운드: KOR Lambda 보안 그룹 ID로 3306 허용 |
| 라우팅 | KOR VPC 라우팅 테이블에 Peering 라우트 추가 |

#### DB 사용자 최소 권한

```sql
-- USA/JPN Aurora에서 실행
CREATE USER 'logpull_reader'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT ON athena.global_sync_sub_log TO 'logpull_reader'@'%';
-- global_sync_pub_log 존재 시:
-- GRANT SELECT ON athena.global_sync_pub_log TO 'logpull_reader'@'%';
```

> **확인 필요:** 크로스리전 접속 시 IAM Auth(RDS Token)가 동작하는지 검증 필요. IAM Auth Token 생성은 리전 엔드포인트를 지정하므로 `boto3.client("rds", region_name="us-east-1")`처럼 대상 리전을 명시해야 한다.

### 6.2 Lambda IAM 역할

`prod_lambda_hongcafe_logpull_kor`의 IAM Role에 필요한 최소 권한:

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-db:connect"
      ],
      "Resource": [
        "arn:aws:rds-db:us-east-1:241789449679:dbuser:*/logpull_reader",
        "arn:aws:rds-db:ap-northeast-1:241789449679:dbuser:*/logpull_reader",
        "arn:aws:rds-db:ap-northeast-2:241789449679:dbuser:*/admin"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:ap-northeast-2:241789449679:log-group:/aws/lambda/prod_lambda_hongcafe_logpull_kor:*"
    }
  ]
}
```

### 6.3 VPC 구성

```
KOR Lambda logpull:
  VPC:           KOR VPC (ap-northeast-2) — 확인 필요
  Subnet:        프라이빗 서브넷 (확인 필요)
  Security Group: logpull 전용 SG 신규 생성 권장
                  Outbound: 3306 → USA VPC CIDR, JPN VPC CIDR
```

---

## 7. 알림/모니터링

### 7.1 CloudWatch 지표

| 지표 | 임계치 | 알림 조건 |
|------|--------|---------|
| Lambda 에러 수 | 3회 이상 / 15분 | logpull 자체 실패 |
| `sub_status != 3` 누적 건수 (US) | 100건 이상 | USA 동기화 대량 실패 |
| `sub_status != 3` 누적 건수 (JP) | 100건 이상 | JPN 동기화 대량 실패 |
| `retry_count > 3` 건수 | 10건 이상 | 반복 실패 누적 |
| Lambda Duration | 240,000ms (4분) | Timeout 임박 |

### 7.2 알림 경로

```
CloudWatch Alarm
    │
    ▼
SNS Topic (알림용, 별도 — 기존 prod_sns_hongcafe_global.fifo와 분리)
prod_sns_hongcafe_alert (ap-northeast-2)
    │
    ├──> 이메일 (운영팀)
    └──> Slack Webhook (확인 필요)
```

### 7.3 대시보드 구성 (CloudWatch Dashboard)

```
[prod_hongcafe_sync_monitor]

┌─────────────────────────────────────────────────────────┐
│  국가별 동기화 현황 (최근 1시간)                           │
│                                                          │
│  USA: 완료 ████████████ 9,850건 | 실패 ██ 12건           │
│  JPN: 완료 ████████████ 4,320건 | 실패 █  3건            │
│                                                          │
│  logpull 실행 횟수: 12/12 (성공률 100%)                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  실패 건 상세 (sub_status != 3, retry_count > 0)         │
│                                                          │
│  [테이블: global_sync_monitor_log WHERE sub_status != 3] │
└─────────────────────────────────────────────────────────┘
```

---

## 8. 타당성 검토

### 8.1 크로스리전 Aurora 접근 — VPC Peering 실현 가능성

**AWS 공식 지원 여부:**
AWS VPC Peering은 서로 다른 리전 간(inter-region VPC Peering)을 지원한다. 동일 AWS 계정 내 us-east-1 ↔ ap-northeast-2 ↔ ap-northeast-1 VPC 간 Peering 구성이 가능하다.

> 근거: AWS 공식 문서 "VPC Peering Basics" — inter-region peering은 IPv4/IPv6 모두 지원, 동일 계정 및 다른 계정 간 모두 가능.

**제약 사항:**
- VPC CIDR이 겹치면 Peering 불가 — 현재 3개 VPC CIDR 확인 필요
- 라우팅 테이블에 양방향 라우트 추가 필요
- Security Group은 Peering 상대 VPC의 CIDR 또는 SG ID로 허용 규칙 추가

**RDS Proxy 크로스리전 불가:**
RDS Proxy는 동일 리전 VPC 내 클라이언트만 지원하는 것이 AWS 설계 제약이다. 크로스리전 접속 시 Aurora 클러스터 엔드포인트 직접 사용이 필요하다. Aurora 클러스터 엔드포인트는 VPC 내 프라이빗 DNS로 해석되므로, VPC Peering + 라우팅 설정 완료 후 접근 가능하다.

### 8.2 Lambda 다중 리전 DB 동시 접속

Lambda 단일 실행 내에서 us-east-1, ap-northeast-2, ap-northeast-1 Aurora에 동시(순차) 접속은 기술적으로 가능하다. 기존 `shared/db_connection.py`의 `get_connection()` 패턴을 리전별로 확장하여 구현한다.

**주의 사항:**
- 연결당 TCP 소켓 1개 사용 — 3개 연결 시 Lambda 메모리/소켓 리소스 여유 있음 (256MB 기준)
- 크로스리전 접속은 레이턴시가 높음 (us-east-1 ↔ ap-northeast-2 약 150ms RTT 추정). 타임아웃을 `connect_timeout=10`으로 여유 있게 설정 필요.
- Lambda Timeout은 300초로 설정하여 충분한 실행 시간 확보

### 8.3 VPC Peering 비용/복잡성

**비용 (추정):**

| 항목 | 비용 |
|------|------|
| Peering 연결 자체 | 무료 |
| 크로스리전 데이터 전송 | $0.01~0.02/GB (리전 간 요율) |
| 예상 월 전송량 | 동기화 로그 건당 약 500B × 10,000건/일 × 30일 = 약 150MB/월 |
| 예상 월 비용 | < $0.01 (무시 가능) |

**복잡성:**
- VPC Peering 3쌍 설정 (us-east-1 ↔ ap-northeast-2, ap-northeast-2 ↔ ap-northeast-1, us-east-1 ↔ ap-northeast-1) — KOR logpull만 USA/JPN에 접속하면 되므로 실제로는 2쌍(KOR-USA, KOR-JPN)만 필요
- 라우팅 테이블 6개 항목 추가 (양방향)
- 보안 그룹 2개 인바운드 규칙 추가

> **결론:** 기술적 실현 가능성 있음. 비용은 무시할 수준. 구성 복잡성은 중간 수준이나 일회성 작업. VPC CIDR 겹침 여부 사전 확인이 필수 선행 조건.

---

## 9. 변경 영향 기록

### 9.1 변경 사항

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 모니터링 방식 | 3개 리전 CloudWatch 개별 확인 | KOR Aurora 중앙 집계 + 단일 대시보드 |
| 실패 감지 | 각 리전 Lambda 에러 로그 개별 확인 | CloudWatch Alarm → SNS 중앙 알림 |
| 정합성 검증 | 불가 | global_sync_monitor_log 기반 발행-수신 대조 가능 |
| 신규 Lambda | 없음 | `prod_lambda_hongcafe_logpull_kor` 추가 |
| 신규 테이블 (KOR Aurora) | 없음 | `global_sync_monitor_log`, `global_sync_monitor_stats`, `logpull_watermark` |
| 인프라 변경 | 없음 | VPC Peering 2쌍, 보안 그룹 규칙, EventBridge Rule |

### 9.2 개선점

1. **운영 효율 향상:** 장애 감지 시간이 단축된다. 현재는 각 리전 CloudWatch를 수동으로 확인해야 하지만, logpull 도입 후 단일 알림으로 즉시 감지 가능.
2. **감사 추적 강화:** 전체 동기화 이력이 KOR 중앙 DB에 보관되어 감사/컴플라이언스 대응에 활용 가능.
3. **정합성 보장:** 발행된 메시지가 모든 국가에서 처리 완료되었는지 KOR 한 곳에서 검증 가능.

### 9.3 수행 이유

현재 KOR/JPN Lambda가 스켈레톤 상태이고 전체 Pub/Sub 시스템이 완성 단계에 가까워지고 있다. 시스템이 실제 프로덕션 트래픽을 처리하기 시작하면, 분산된 로그를 통합 모니터링하지 않으면 장애 감지가 지연되고 데이터 불일치가 뒤늦게 발견될 위험이 있다. logpull은 이 위험을 선제적으로 해소하는 모니터링 인프라다.

---

## 10. 미확인 항목 / 구현 전 확인 필요

| 항목 | 확인 방법 | 우선순위 |
|------|---------|---------|
| KOR Aurora RDS Proxy 엔드포인트 | infrastructure.md 업데이트 또는 AWS 콘솔 확인 | 높음 |
| JPN Aurora RDS Proxy 엔드포인트 | 동상 | 높음 |
| 3개 VPC CIDR 범위 | AWS 콘솔 VPC 탭 확인 | 높음 (Peering 전 필수) |
| `global_sync_pub_log` 테이블 존재 여부 | 각 국가 Aurora에서 `SHOW TABLES LIKE 'global_sync_pub_log'` | 중간 |
| `global_sync_sub_log` 실제 컬럼 확인 | `DESCRIBE global_sync_sub_log` (lambda-pubsub-sdd 추정값 검증) | 높음 |
| KOR Lambda VPC/Subnet 정보 | AWS 콘솔 또는 infrastructure.md 보완 | 높음 |
| IAM Auth 크로스리전 동작 여부 | 테스트 환경에서 `boto3.client("rds", region_name="us-east-1").generate_db_auth_token(...)` 검증 | 중간 |
| Slack Webhook 알림 연동 여부 | 운영팀 확인 | 낮음 |

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
| 2026-04-15 | 현재 구조 동기화: Runtime 3.12, 디렉토리 미생성 상태 명시 | jypark |
| 2026-04-15 | 프론트매터 보강 (문서 ID, 버전, 관련 문서), 체크리스트/변경 기록 섹션 추가 | jypark |
