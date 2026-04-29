# SQS (Lambda 트리거)

## SQS → Lambda 트리거 핸들러 패턴

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

## SQS 설정 규칙

| 항목 | 권장 설정 | Why (사유) |
|------|-----------|-----------|
| **ReportBatchItemFailures** | 활성화 | 부분 실패 시 실패 메시지만 재처리 — 미설정 시 배치 1건 실패로 10건 모두 재처리되어 멱등성 부담/처리량 저하 |
| **Visibility Timeout** | Lambda 타임아웃 × 6 | 처리 중 메시지가 다른 소비자에게 전달되지 않도록 — Lambda 처리 시간 + 재시도 여유 확보 |
| **DLQ (Dead Letter Queue)** | 필수 설정, maxReceiveCount = 3 | 3회 실패 시 DLQ 로 이동하여 무한 재시도 방지 — 영구 실패 메시지가 큐를 점유하면 정상 메시지 처리 지연 |
| **Batch Size** | 1~10 (기본 10) | 처리 시간에 따라 조정 — 큰 배치는 처리량 ↑ 이지만 부분 실패 시 재처리 범위도 ↑ |
| **메시지 포맷** | JSON | 구조화된 데이터 교환 — 문자열/바이너리는 스키마 진화 시 호환성 깨짐 |

## 멱등성 보장

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

> **Why (멱등성 패턴):** SQS 는 at-least-once 전달 보장 — 동일 메시지가 2회 이상 도착하는 것이 정상 동작. 중복 처리를 막지 않으면 결제 중복, 재고 중복 차감 등 비즈니스 손해 직결. `INSERT IGNORE` + 유니크 제약으로 DB 레벨에서 중복 차단이 가장 안전.
