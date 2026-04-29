# Lambda (Python)

## 핸들러 기본 패턴

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

## 핸들러 작성 규칙

| 규칙 | 설명 |
|------|------|
| **런타임 버전 확인 (필수)** | Lambda 함수 신규 생성 시 Python 런타임 버전을 반드시 사용자에게 Checkpoint 로 확인. 임의 지정 금지. **Why:** 런타임 버전은 의존성/EOL/보안 패치 주기를 결정하는 비가역적 선택 — 한 번 정하면 패키지 호환성에 묶여 변경 비용이 큼 |
| **핸들러 ≠ 비즈니스 로직** | `handler()`는 이벤트 파싱 + 응답 래핑만. 실제 로직은 별도 함수/모듈로 분리. **Why:** 핸들러에 직접 비즈니스 로직을 두면 단위 테스트 시 Lambda 이벤트 객체를 매번 mocking 해야 함 — 분리하면 비즈니스 로직만 독립 테스트 가능 |
| **환경변수 사용 (필수)** | 시크릿, 엔드포인트, 설정값은 `os.environ.get()` 사용. 환경변수/시크릿 매니저로 관리한다. **Why:** 코드 하드코딩 시 다국가/다환경 배포 불가 + 시크릿이 git 에 노출 |
| **로깅 필수** | 모든 핸들러에 `logging` 모듈을 사용한다. **Why:** Lambda 는 stateless — CloudWatch 로그가 사후 디버깅 유일 수단 |
| **에러 핸들링** | 최상위 `try-except`로 감싸고 에러 로깅. 내부 정보 외부 노출 금지. **Why:** 미처리 예외는 5xx + 스택 트레이스 노출 위험 |
| **타임아웃 고려** | 외부 호출(DB, API)에 timeout 설정. Lambda 제한시간 내 완료 보장. **Why:** 외부 호출이 hang 되면 Lambda 가 무응답으로 timeout — 호출자에게 비용/레이턴시 손실 |
| **멱등성** | SQS/SNS 트리거 시 동일 메시지 재처리에 안전해야 함. **Why:** SQS at-least-once 전달 — 중복 메시지가 정상 동작이며, 멱등성 미보장 시 중복 결제/주문 같은 비즈니스 손해 발생 |

## 환경변수 관리

```python
# 환경변수에서 설정 로드 (하드코딩 절대 금지)
DB_HOST = os.environ.get("DB_HOST")
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
QUEUE_URL = os.environ.get("QUEUE_URL")
TOPIC_ARN = os.environ.get("TOPIC_ARN")
```

## 프로젝트 구조

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

## 레이어 사용

- 공통 라이브러리(`pymysql`, 유틸리티 등)는 **Lambda Layer**로 분리
- 레이어 변경 시 모든 연결 함수에 영향이므로 **Checkpoint 발동**. **Why:** 단일 레이어 변경이 N 개 함수에 동시 전파 — 회귀 위험이 함수 개수만큼 증식
