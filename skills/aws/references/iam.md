# IAM

## 최소 권한 원칙

Lambda 실행 역할에는 **필요한 권한만** 부여한다.

> **Why:** 과도한 권한 부여 시 Lambda 코드 취약점이 곧바로 AWS 계정 전체 위협으로 확대 — 침해 시 영향 범위는 IAM 정책의 정확한 경계로 결정됨.

| Lambda 용도 | 필요 권한 |
|-------------|-----------|
| SQS 트리거 | `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` |
| SNS 트리거 | (SNS 가 Lambda 를 호출하므로 Lambda 쪽 SQS 권한 불필요, 리소스 기반 정책 사용) |
| Aurora 접근 | VPC 접근 (`ec2:CreateNetworkInterface`, `ec2:DescribeNetworkInterfaces`, `ec2:DeleteNetworkInterface`) |
| SQS 발행 | `sqs:SendMessage` (특정 큐 ARN 에 한정) |
| SNS 발행 | `sns:Publish` (특정 토픽 ARN 에 한정) |
| CloudWatch 로그 | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` |

## IAM 규칙

| 규칙 | 설명 / Why |
|------|-----------|
| **와일드카드 리소스 제한** | `Resource` 는 특정 ARN 으로 제한한다. **Why:** `Resource: "*"` 는 계정 내 모든 동종 리소스 접근 허용 — 권한 분리 무력화 |
| **인라인 정책 지양** | 관리형 정책 또는 고객 관리형 정책 사용. **Why:** 인라인 정책은 역할별 사본이 흩어져 동일 권한 변경 시 모든 역할 일일이 수정해야 함 |
| **역할 분리** | Lambda 함수별로 별도 IAM 역할 생성. 하나의 역할을 여러 함수가 공유하지 않음. **Why:** 단일 역할 침해 시 영향 범위가 그 역할을 쓰는 모든 함수 — 분리하면 함수별 격리 |
| **액세스 키 미사용** | Lambda 는 IAM 역할로 인증. 액세스 키 하드코딩/환경변수 주입 금지. **Why:** 액세스 키는 회전 부담 + 코드 노출 시 즉시 침해 — IAM 역할은 STS 임시 자격 증명을 자동 발급/갱신 |
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
