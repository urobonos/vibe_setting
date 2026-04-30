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

AWS 서비스 연동을 위한 스킬. Lambda(Python) 를 중심으로 SQS/SNS 트리거, Aurora MySQL 연결, EC2, RDS Proxy, IAM/보안 그룹 설정을 다룬다.

> **[Checkpoint 필수]** Lambda 함수를 새로 생성할 때, Python 런타임 버전을 반드시 사용자에게 확인받는다. 사용자에게 확인 후 버전을 지정한다.
> **Why:** 런타임 버전은 라이브러리 호환성·EOL 일정·콜드 스타트 성능에 직결되며 배포 후 변경 시 의존성 재테스트 비용이 발생 — 신규 생성 시점에 사용자 환경 표준과 맞춰야 재배포 사고를 방지.

> **[실행 주체]** AWS CLI / SSM / S3 / Lambda 등 모든 `aws` 명령은 Claude 가 Bash 도구로 **직접 실행**한다. 사용자에게 `! aws ...` 형태로 떠넘기거나 "실행해 주세요" 텍스트로 응답하는 것은 지침 위반이다.
> - **조회 계열 (즉시 실행):** `aws * describe-*`, `list-*`, `get-command-invocation`, `get-parameter`, `s3 ls`, `logs filter-log-events` 등. 승인 대기 없이 Claude 가 바로 실행한다.
> - **변경/원격 실행 계열 (승인 후 직접 실행):** `aws ssm send-command` (프로덕션 원격 명령), `aws s3 rm`/`cp`, `aws lambda update-*`, `aws iam put-*` 등. 명령 내용·영향 범위·롤백 방법을 먼저 보고한 뒤, 사용자 승인 확인 즉시 Claude 가 도구로 호출한다.
> - **Hook 경고 해석:** `dangerous-ops-guard.sh` 가 `aws ssm send-command` 감지 시 stdout 에 Checkpoint 경고를 주입하지만 `exit 0` 이므로 실행 자체는 차단되지 않는다. 경고 = "승인 후 직접 실행" 신호이지 "실행 금지" 신호가 아니다.
> **Why:** AWS 변경 명령은 사용자가 텍스트로 받아 수동 실행하면 컨텍스트 단절·오타·세션 ENV 차이로 잘못된 리전/계정에 적용될 위험 — Claude 가 도구로 실행하면 명령·결과·로그가 한 turn 에 묶여 감사 가능. 반대로 변경 계열은 무승인 자동 실행 시 비가역(s3 rm·lambda update) — 두 단 분리가 안전·실행성 양립의 SSOT.

---

## 1. 도메인 선택 가이드

본 스킬은 도메인별 references 로 분리되어 있다. 작업 시나리오에 맞춰 필요한 파일만 읽는다.

| 작업 시나리오 | 읽을 references | 핵심 패턴 |
|--------------|----------------|-----------|
| Lambda 함수 신규 작성 | `references/lambda.md` | 핸들러 분리, 환경변수, 로깅, 멱등성 |
| SQS 트리거 Lambda | `references/lambda.md` + `references/sqs.md` | batchItemFailures, DLQ, 멱등성 |
| SNS 트리거 Lambda | `references/lambda.md` + `references/sns.md` | Subject 라우팅, 예외 재발생, DLQ |
| Lambda → Aurora 연결 | `references/lambda.md` + `references/aurora.md` + `references/rds-proxy.md` | RDS Proxy 경유, IAM 인증, 페일오버 |
| EC2 인스턴스 프로비저닝 | `references/ec2.md` + `references/security-groups.md` | SSH IP 제한, IAM Instance Profile |
| 메시징 파이프라인 (SNS+SQS+Lambda) | `references/messaging-architecture.md` + `references/sns.md` + `references/sqs.md` | Outbox Pattern, FIFO 순서 보장 |
| 보안 그룹 신규/변경 | `references/security-groups.md` | SG 간 참조, 0.0.0.0/0 금지 |
| IAM 정책 작성 | `references/iam.md` | 최소 권한, ARN 한정 |
| S3 / CloudFront 설정 | `references/s3-cloudfront.md` | OAC, 버저닝, CRR |

> **Why (도메인 분리):** SKILL.md 본문에 8개 도메인을 모두 펼쳐두면 자동 호출 시마다 800줄 이상이 컨텍스트에 로드 — 작업 시나리오와 무관한 도메인까지 모두 읽음. 본문은 선택 가이드만 두고 상세는 references/ 로 위임하면 시나리오별 필요 도메인만 컨텍스트에 진입.

---

## 2. 공통 규칙

### 2.1. 시크릿 관리

| 구분 | 방법 | 금지 사항 |
|------|------|-----------|
| **Lambda** | 환경변수 + KMS 암호화 또는 Secrets Manager | 코드에 하드코딩 |
| **EC2** | IAM 인스턴스 프로파일 + Secrets Manager | 액세스 키 `.env` 파일 저장 |
| **Aurora** | Secrets Manager 자동 로테이션 권장 | 비밀번호 코드/환경변수 직접 기입 |

> **Why:** 시크릿 노출 시 비가역적 영향 — 토큰 회전, 권한 재배포, 침해 사후 조사 비용이 모두 발생. KMS/Secrets Manager 는 회전/감사 자동화 인프라.

### 2.2. 다국가 배포 환경 분리

다국가 서비스는 국가별 `.env` + `deploy.sh` 로 배포를 분리한다. 코드는 동일하게 유지하고 환경변수만 국가별로 주입.

```
deploy/
├── us/
│   ├── .env
│   └── deploy.sh
├── kr/
│   ├── .env
│   └── deploy.sh
└── jp/
    ├── .env
    └── deploy.sh
```

**규칙**:
- 국가별 `.env` 로 DB 접속, API 키, 외부 서비스 엔드포인트, Aurora/RDS Proxy 엔드포인트 분리
- 배포 스크립트(`deploy.sh`) 도 국가별 분리 — 리전, 인스턴스 ID, CloudFront 배포 차이
- CI/CD 파이프라인에서 `COUNTRY` 환경변수로 대상 국가 지정
- 상세는 `global-context` §8 "배포 환경 분리" 참조

### 2.3. 주석 규칙

Lambda Python 코드에도 `php8` 코딩 표준 (`~/.claude/skills/php8/references/coding-standards.md`) 과 동일한 규칙을 적용한다:
- 모든 함수에 docstring 필수 (`@param`, `@return` 포함)
- 복잡한 로직에 단계별 설명 주석
- 추상화 시 사유 주석

> **Why:** Lambda 핸들러는 SQS/SNS/HTTP 등 트리거별 이벤트 스키마가 모호 — docstring 없이 배포되면 retry/timeout 디버깅 시 호출자(트리거 종류·payload 키)를 코드만 보고 역추적해야 한다. 표준 적용 시 ops 인계·인시던트 응답 시간이 단축.

### 2.4. 테스트

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

## 3. Mental Dry-Run (코드 사전 검증, 필수)

AWS 관련 코드 생성·수정 시, **실제 파일에 기록하기 전에** 다음 절차를 반드시 수행한다.

1. **1차 작성** — 응답(메모리) 상에서만 코드를 작성한다. 실제 파일에는 기록하지 않는다.
2. **1차 재검토** — 작성한 코드를 스킬 규칙·자가 검증 체크리스트 기준으로 검토한다.
3. **2차 재검토** — 엣지 케이스, 사이드 이펙트, 기존 코드와의 정합성을 추가 검토한다.
4. **파일 반영** — 2회 검토 후 문제가 없다고 판단될 경우에만 실제 파일에 기록한다.

> 검토 중 문제가 발견되면 메모리 상에서 수정 후 다시 1차 재검토부터 반복한다.

> **Why:** AWS 코드는 IAM 정책, 보안 그룹, 시크릿 처리 등 비가역적 영향이 큰 영역 — 사전 검토 없이 파일 반영 시 잘못된 코드가 배포 흐름으로 진입할 위험.

---

## 4. 자가 검증 체크리스트

AWS 관련 코드 작성/수정 시 반드시 확인:

> **Why:** AWS 코드 결함 중 IAM 권한 과다·SG 0.0.0.0/0·DLQ 누락·하드코딩 시크릿은 사후 발견 시 비용·보안 리스크가 큼. 체크리스트는 review 단계가 아닌 작성 시점에 강제해 PR 단계 재작업을 줄이는 SSOT.

- [ ] Lambda 핸들러와 비즈니스 로직이 분리되어 있는가
- [ ] 환경변수로 설정값을 관리하고 있는가 (하드코딩 없음)
- [ ] SQS 트리거 시 `batchItemFailures` 부분 실패 처리가 구현되어 있는가
- [ ] SQS 에 DLQ 가 설정되어 있는가
- [ ] 멱등성이 보장되는가 (중복 메시지 안전 처리)
- [ ] Aurora 연결 시 Reader/Writer 엔드포인트를 구분하고 있는가
- [ ] Aurora 연결에 타임아웃과 페일오버 재시도가 구현되어 있는가 (RDS Proxy 미사용 시)
- [ ] IAM 역할이 최소 권한 원칙을 준수하는가 (와일드카드 Resource 없음)
- [ ] Lambda IAM 역할로 인증하고, 액세스 키를 사용하지 않는가
- [ ] 보안 그룹이 필요한 포트만 개방하고 보안 그룹 간 참조를 사용하는가
- [ ] 모든 함수에 docstring 이 있는가
- [ ] 테스트 코드가 포함되어 있는가

---

## 참고: EC2 인증서 파일

| 항목 | 값 |
|------|-----|
| 설정 파일 | `~/.claude/.config` (`EC2_HOST`, `EC2_USER`, `EC2_PEM`) |
| 용도 | EC2 SSH 접속용 (현재 키 불일치로 사용 불가) |
| 접속 방식 | **SSM Session Manager** 경유 필수 |

> **Why:** 현재 PEM 키 불일치로 SSH 접근 불가 + 22 포트 외부 노출 시 brute-force 위험. SSM 은 IAM 인증 + 세션 로그가 CloudTrail 에 자동 기록되어 감사 가능 — 운영 표준은 SSM 단일 경로.

## 참고: .env 비밀번호 관리 가이드

| 환경 | 방식 | 비고 |
|------|------|------|
| **개발 (로컬)** | `.env` 파일에 평문 저장 허용 | `.gitignore` 로 커밋 차단 필수 |
| **프로덕션 (EC2)** | `/works/<PROJECT>/config/.env` symlink | 릴리즈별 `.env` symlink 참조, 서버 내 파일 직접 관리 |

> **Why:** `.env` 가 git 에 한 번이라도 커밋되면 history rewrite 비용 + 키 회전 + 침해 사후 조사가 동시에 발생. `.gitignore` 강제 + pre-commit 검사가 git 레벨 1차 방어선.

> 프로덕션 DB 비밀번호가 `.env` 평문 저장인 점은 현재 운영 방식. 향후 AWS Secrets Manager 전환 권장.
