# SDD: Lambda CI/CD 자동화

> SDD: Lambda CI/CD 자동화

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

HongCafe Global Lambda 함수(sqs_push 3개국 + logpull)의 빌드, 테스트, 배포를 Bitbucket Pipelines를 통해 자동화한다. 현재 수동 zip 업로드 방식을 대체하여 3개국 동시 배포, 롤백, Layer 관리를 체계화한다.

### 1.2 범위

| 항목 | 내용 |
|------|------|
| 대상 함수 | sqs_push (USA, KOR), logpull (KOR) — JPN은 infra 디렉토리 미생성 |
| CI/CD 도구 | Bitbucket Pipelines |
| 배포 방식 | AWS CLI `lambda update-function-code` (SSM 경유 아님, 직접 배포) |
| Layer 관리 | `lambda publish-layer-version` (조건부 실행) |
| 코드 위치 | `infra` 리포지토리 `lambda/` 디렉토리 |

### 1.3 관련 문서

| 문서 | 경로 |
|------|------|
| Lambda Pub/Sub SDD | `docs/output/specs/lambda-pubsub-sdd.md` |
| CI/CD Pipeline (BE/FE) SDD | `docs/output/specs/cicd-pipeline-sdd.md` |
| Infrastructure | `docs/infrastructure.md` |

---

## 2. 아키텍처

### 2.1 전체 배포 흐름

```
┌──────────────────────────────────────────────────────────┐
│ Bitbucket Pipelines (infra 리포지토리)                     │
│                                                          │
│  production 머지 (lambda/** 변경 감지)                    │
│       │                                                  │
│       ▼                                                  │
│  [Step 1] Ready to Deploy (수동 승인)                     │
│       │                                                  │
│       ▼                                                  │
│  [Step 2] Test                                           │
│       │  pytest lambda/                                  │
│       │                                                  │
│       ▼                                                  │
│  [Step 3] Package                                        │
│       │  zip -r function.zip (국가별)                     │
│       │                                                  │
│       ▼                                                  │
│  [Step 4] Deploy USA (us-east-1)                         │
│       │  aws lambda update-function-code                 │
│       │  aws lambda publish-version                      │
│       │  검증 (invoke --dry-run)                          │
│       │                                                  │
│       ▼                                                  │
│  [Step 5] Deploy KOR (ap-northeast-2)                    │
│       │  (동일 절차)                                      │
│       │                                                  │
│       ▼                                                  │
│  [Step 6] Deploy JPN (ap-northeast-1)                    │
│       │  (동일 절차)                                      │
│       │                                                  │
└──────────────────────────────────────────────────────────┘
```

### 2.2 BE/FE CI/CD와의 차이

| 항목 | BE/FE CI/CD | Lambda CI/CD |
|------|-------------|--------------|
| 배포 대상 | EC2 단일 인스턴스 | Lambda 3개 리전 |
| 배포 방식 | SSM send-command | AWS CLI 직접 호출 |
| 롤백 | symlink 재지정 | Lambda 버전/별칭 |
| 리포지토리 | BE/FE 각각 | infra 단일 리포 |
| 트리거 | production 머지 | production 머지 + 경로 필터 |

---

## 3. 파이프라인 상세

### 3.1 트리거 조건

```yaml
pipelines:
  branches:
    production:
      - step:
          condition:
            changesets:
              includePaths:
                - "lambda/**"
```

`lambda/` 하위 파일 변경이 있을 때만 파이프라인 실행. BE/FE 코드 변경은 트리거하지 않음.

### 3.2 빌드 스텝 (패키징)

```
패키징 전략: 국가별 개별 zip

lambda/
├── usa/sqs_push/    → function_usa_sqs_push.zip
├── kor/sqs_push/    → function_kor_sqs_push.zip
├── kor/logpull/     → function_kor_logpull.zip  (미생성)
└── shared/          → 각 zip에 공통 포함

> ⚠️ JPN 디렉토리(`lambda/jpn/`)는 미생성 상태. JPN 배포 추가 시 디렉토리 생성 필요.
```

```bash
# 패키징 예시 (USA sqs_push)
cd lambda
cp -r shared/ usa/sqs_push/shared/
cd usa/sqs_push
zip -r ../../function_usa_sqs_push.zip . -x "*.pyc" "__pycache__/*"
```

### 3.3 테스트 스텝

```bash
pip install pytest pymysql boto3 moto
pytest lambda/tests/ -v --tb=short
```

테스트 범위:
- 메시지 파싱 (parse_message)
- 멱등성 체크 (is_already_processed)
- 이벤트 라우팅 (route_event)
- DB 연결 모듈 (moto mock)

### 3.4 배포 스텝

```bash
# 1. 코드 업데이트
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://function.zip \
  --region $DEPLOY_REGION

# 2. 배포 완료 대기
aws lambda wait function-updated \
  --function-name $FUNCTION_NAME \
  --region $DEPLOY_REGION

# 3. 버전 발행 (롤백용)
VERSION=$(aws lambda publish-version \
  --function-name $FUNCTION_NAME \
  --region $DEPLOY_REGION \
  --query 'Version' --output text)

# 4. 검증 (dry-run invoke)
aws lambda invoke \
  --function-name $FUNCTION_NAME \
  --region $DEPLOY_REGION \
  --invocation-type DryRun \
  /dev/null
```

### 3.5 다중 리전 배포 전략

**순차 배포 (USA → KOR → JPN)** 채택.

```
USA (us-east-1)     ──[배포]──[검증]──▶ 성공 시 계속
                                         │
KOR (ap-northeast-2) ──[배포]──[검증]──▶ 성공 시 계속
                                         │
JPN (ap-northeast-1) ──[배포]──[검증]──▶ 완료
```

| 전략 | 장점 | 단점 | 채택 |
|------|------|------|------|
| 순차 배포 | 단계별 검증, 실패 시 영향 최소화 | 배포 시간 길어짐 | **채택** |
| 병렬 배포 | 빠름 | 한 리전 실패 시 일부만 롤백 필요 | 비채택 |
| Canary | 점진적 트래픽 전환 | Lambda@Edge 아님, 복잡도 과잉 | 비채택 |

### 3.6 bitbucket-pipelines.yml 예시

```yaml
image: amazon/aws-cli

definitions:
  steps:
    - step: &deploy-lambda
        name: Deploy Lambda
        script:
          - cd lambda
          - cp -r shared/ ${COUNTRY}/sqs_push/shared/
          - cd ${COUNTRY}/sqs_push
          - zip -r ../../function.zip . -x "*.pyc" "__pycache__/*"
          - cd ../..
          - >
            aws lambda update-function-code
            --function-name ${FUNCTION_NAME}
            --zip-file fileb://function.zip
            --region ${DEPLOY_REGION}
          - >
            aws lambda wait function-updated
            --function-name ${FUNCTION_NAME}
            --region ${DEPLOY_REGION}
          - >
            aws lambda publish-version
            --function-name ${FUNCTION_NAME}
            --region ${DEPLOY_REGION}
          - >
            aws lambda invoke
            --function-name ${FUNCTION_NAME}
            --region ${DEPLOY_REGION}
            --invocation-type DryRun /dev/null

pipelines:
  branches:
    production:
      - step:
          name: 1. Ready to Deploy
          script:
            - echo "Lambda deployment ready"
      - step:
          name: 2. Test
          image: python:3.12-slim
          script:
            - pip install pytest pymysql boto3 moto
            - pytest lambda/tests/ -v --tb=short
      - step:
          name: 3. Deploy USA
          deployment: production-lambda-usa
          variables:
            COUNTRY: usa
            FUNCTION_NAME: prod_lambda_hongcafe_sqs_push_usa
            DEPLOY_REGION: us-east-1
          <<: *deploy-lambda
      - step:
          name: 4. Deploy KOR
          deployment: production-lambda-kor
          variables:
            COUNTRY: kor
            FUNCTION_NAME: prod_lambda_hongcafe_sqs_push_kor
            DEPLOY_REGION: ap-northeast-2
          <<: *deploy-lambda
      # JPN 스텝 — lambda/jpn/ 디렉토리 생성 후 활성화
      # - step:
      #     name: 5. Deploy JPN
      #     deployment: production-lambda-jpn
      #     variables:
      #       COUNTRY: jpn
      #       FUNCTION_NAME: prod_lambda_hongcafe_sqs_push_jpn
      #       DEPLOY_REGION: ap-northeast-1
      #     <<: *deploy-lambda
```

---

## 4. Layer 관리

### 4.1 Layer 빌드

```
현재 Layer: prod_functionlayer_hongcafe_usa:1 (pymysql)
빌드 방식: Docker + pip install → zip

구조:
  python/
  └── pymysql/       ← pip install pymysql -t python/
```

```bash
# Layer 빌드
mkdir -p layer/python
pip install pymysql -t layer/python/
cd layer && zip -r ../layer.zip python/
```

### 4.2 Layer 배포

Layer 변경은 드물므로 **조건부 수동 트리거** 방식 채택.

```bash
# Layer 발행 (각 리전)
aws lambda publish-layer-version \
  --layer-name prod_functionlayer_hongcafe_${COUNTRY} \
  --zip-file fileb://layer.zip \
  --compatible-runtimes python3.12 \
  --region ${DEPLOY_REGION}

# Lambda에 Layer 연결
aws lambda update-function-configuration \
  --function-name ${FUNCTION_NAME} \
  --layers arn:aws:lambda:${DEPLOY_REGION}:241789449679:layer:prod_functionlayer_hongcafe_${COUNTRY}:${VERSION} \
  --region ${DEPLOY_REGION}
```

### 4.3 Layer 버전 관리

| 항목 | 정책 |
|------|------|
| 버전 보관 | 최근 3개 버전 유지 |
| 업데이트 빈도 | pymysql 메이저 업데이트 시 |
| 호환성 | Lambda Runtime(Python 3.12)과 일치 확인 |

---

## 5. 환경 변수 관리

### 5.1 리전별 환경 변수

| 변수 | USA | KOR | JPN |
|------|-----|-----|-----|
| `DB_HOST` | `prod-rdsproxy-hongcafe-usa.proxy-...` | (KOR RDS Proxy) | (JPN RDS Proxy) |
| `DB_NAME` | `athena` | `athena` | `athena` |
| `DB_USER` | `admin` | `admin` | `admin` |
| `AWS_REGION` | `us-east-1` | `ap-northeast-2` | `ap-northeast-1` |

환경 변수는 Lambda 함수 설정에 직접 저장. 파이프라인에서는 변경하지 않음. 변경 필요 시 `aws lambda update-function-configuration` 별도 실행.

### 5.2 Bitbucket Repository Variables

| 변수명 | 용도 | Secured |
|--------|------|---------|
| `AWS_ACCESS_KEY_ID` | IAM 액세스 키 | Yes |
| `AWS_SECRET_ACCESS_KEY` | IAM 시크릿 키 | Yes |
| `AWS_DEFAULT_REGION` | 기본 리전 (us-east-1) | No |

---

## 6. 롤백

### 6.1 Lambda 버전 활용

배포 시 `publish-version`으로 버전을 발행하므로 롤백 시 이전 버전 코드로 복원 가능.

```bash
# 이전 버전 목록 확인
aws lambda list-versions-by-function \
  --function-name ${FUNCTION_NAME} \
  --region ${DEPLOY_REGION}

# 이전 버전 코드 다운로드 후 재배포
CODE_URL=$(aws lambda get-function \
  --function-name ${FUNCTION_NAME} \
  --qualifier ${PREVIOUS_VERSION} \
  --query 'Code.Location' --output text \
  --region ${DEPLOY_REGION})
curl -o rollback.zip "$CODE_URL"
aws lambda update-function-code \
  --function-name ${FUNCTION_NAME} \
  --zip-file fileb://rollback.zip \
  --region ${DEPLOY_REGION}
```

### 6.2 수동 롤백 절차

```
1. 문제 감지 (CloudWatch 에러 로그 또는 SQS 체류 증가)
2. 이전 버전 확인: aws lambda list-versions-by-function
3. $LATEST를 이전 코드로 복원:
   - 이전 버전의 코드를 다운로드하여 재배포
   - 또는 git revert + 파이프라인 재실행
4. 검증: DryRun invoke + CloudWatch 로그 확인
```

---

## 7. IAM 권한

### 7.1 HC-bitbucket-deploy 추가 권한

현재 `HC-bitbucket-deploy` 유저는 SSM 권한만 보유. Lambda 배포를 위해 다음 권한 추가 필요.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaDeploy",
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:PublishVersion",
        "lambda:GetFunction",
        "lambda:InvokeFunction",
        "lambda:UpdateFunctionConfiguration",
        "lambda:PublishLayerVersion",
        "lambda:GetLayerVersion"
      ],
      "Resource": [
        "arn:aws:lambda:us-east-1:241789449679:function:prod_lambda_hongcafe_*",
        "arn:aws:lambda:ap-northeast-2:241789449679:function:prod_lambda_hongcafe_*",
        "arn:aws:lambda:ap-northeast-1:241789449679:function:prod_lambda_hongcafe_*",
        "arn:aws:lambda:*:241789449679:layer:prod_functionlayer_hongcafe_*"
      ]
    }
  ]
}
```

### 7.2 최소 권한 원칙

- `lambda:*` 와일드카드 사용 금지
- 리소스 ARN에 `prod_lambda_hongcafe_*` 접두사로 제한
- 3개 리전만 허용 (us-east-1, ap-northeast-2, ap-northeast-1)

---

## 8. 보안

| 항목 | 방식 |
|------|------|
| 코드 패키징 | `*.pyc`, `__pycache__/` 제외, `.env` 포함 금지 |
| 파이프라인 시크릿 | Bitbucket Secured Variables (AWS 키) |
| 전송 | HTTPS (AWS CLI 기본) |
| Layer | 동일 계정 내 프라이빗 Layer |

---

## 9. 타당성 검토

### 9.1 Bitbucket Pipelines 다중 리전 배포

**결론: 가능.**

Bitbucket Pipelines에서 AWS CLI를 통해 다중 리전 Lambda 배포가 가능하다. `--region` 파라미터로 리전을 지정하며, 각 스텝에서 다른 리전을 대상으로 실행한다. `amazon/aws-cli` 공식 이미지가 이미 사용 중이므로 추가 설정 불필요.

### 9.2 Layer 자동화

**결론: 가능, 단 조건부.**

`aws lambda publish-layer-version` 명령으로 파이프라인에서 Layer를 발행할 수 있다. 단, Layer 빌드에 Docker가 필요하고(Linux aarch64 호환 패키지), Bitbucket Pipelines는 Docker-in-Docker를 지원하므로 기술적 장벽 없음. Layer 변경 빈도가 낮으므로 수동 트리거 방식이 적합.

### 9.3 Lambda 버전 롤백

**결론: 가능, 제약 있음.**

`publish-version`으로 불변 버전을 생성하면 코드 스냅샷이 보존된다. 단, `$LATEST`가 항상 최신 배포를 가리키므로, 롤백 시 이전 버전 코드를 다시 `update-function-code`로 배포해야 한다. 별칭(Alias) 도입 시 `$LATEST` 대신 별칭을 SQS 트리거 대상으로 설정하면 즉시 버전 전환 롤백이 가능하나, 현재 구성에서는 별칭 미사용.

---

## 10. 변경 영향 기록

| 변경 사항 | 개선점 | 수행 이유 |
|-----------|--------|-----------|
| `bitbucket-pipelines.yml` 신규 작성 (Lambda) | 수동 배포 자동화 | 3개국 수동 zip 업로드는 오류 위험 높음 |
| HC-bitbucket-deploy IAM 정책 추가 | Lambda 배포 권한 확보 | 현재 SSM 권한만 있어 Lambda 배포 불가 |
| Lambda 버전 발행 도입 | 롤백 기반 확보 | 현재 버전 관리 없어 롤백 수단 없음 |
| 순차 배포 전략 (USA → KOR → JPN) | 단계별 검증으로 장애 전파 방지 | USA 검증 후 나머지 리전 배포 |
| Layer 조건부 배포 절차 | 의존성 관리 체계화 | pymysql 등 공통 라이브러리 버전 통제 |
| 경로 필터 (`lambda/**`) 트리거 | BE/FE 변경과 분리 | infra 리포 내 불필요한 Lambda 배포 방지 |

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
| 2026-04-15 | 현재 구조 동기화: Runtime 3.12, JPN 디렉토리 미생성 반영, JPN 파이프라인 스텝 비활성화, logpull 디렉토리 미생성 주석 | jypark |
| 2026-04-15 | 프론트매터 보강 (문서 ID, 버전, 관련 문서), 체크리스트/변경 기록 섹션 추가 | jypark |
