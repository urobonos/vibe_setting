# SNS (Lambda 트리거)

## SNS → Lambda 트리거 핸들러 패턴

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

> **Why (예외 재발생):** SNS → Lambda 직접 트리거에서 핸들러가 정상 종료(return)하면 SNS 는 "전달 성공" 으로 간주 — DLQ 로 보내지 않음. 처리 실패를 SNS 가 인식하려면 예외를 그대로 raise 해야 함.

## SNS 설정 규칙

| 항목 | 권장 설정 | Why (사유) |
|------|-----------|-----------|
| **메시지 필터링** | Subscription Filter Policy 사용 | 불필요한 Lambda 호출 방지 — 모든 메시지를 Lambda 가 받아 분기하면 호출 비용/콜드스타트 손해 |
| **메시지 포맷** | JSON (MessageStructure) | 구조화된 데이터 교환 — 단일 문자열은 다중 프로토콜 라우팅(이메일/SMS/HTTP) 시 변환 부담 |
| **DLQ** | SNS 구독에 DLQ 설정 | 전달 실패 메시지 보존 — 미설정 시 실패 메시지 영구 손실 |
| **Subject 활용** | 이벤트 타입을 Subject 로 전달 | 핸들러 내 라우팅 키로 사용 — body 파싱 없이 분기 가능, 필터 정책에서도 활용 |

## SNS → SQS → Lambda (Fan-out 패턴)

```
SNS Topic
  ├── SQS Queue A → Lambda A (주문 처리)
  ├── SQS Queue B → Lambda B (알림 발송)
  └── SQS Queue C → Lambda C (로그 기록)
```

- SNS 에서 직접 Lambda 를 트리거하면 재시도 제어가 어려우므로, **안정성이 필요한 경우 SNS → SQS → Lambda** 패턴을 권장. **Why:** SNS 직접 호출은 재시도 정책이 제한적이고 DLQ 도 SNS 구독 단위 — SQS 가 중간 버퍼 역할을 하면 Visibility Timeout/maxReceiveCount/DLQ 를 큐 단위로 정밀 제어 가능
- Fan-out 이 필요 없는 단순 트리거는 SNS → Lambda 직접 연결 허용
