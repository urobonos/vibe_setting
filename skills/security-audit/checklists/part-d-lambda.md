# Part D: AWS Lambda / Serverless 보안 체크리스트

**적용 시점:** Lambda 함수 코드(Python), serverless.yml/SAM 설정, IAM 역할/정책 변경 시

| 기반 표준 | URL |
|----------|-----|
| OWASP Serverless Top 10 | https://owasp.org/www-project-serverless-top-10/ |
| AWS Lambda Security | https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html |
| AWS Well-Architected Security Pillar | https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html |
| AWS Foundational Security Standard | https://docs.aws.amazon.com/securityhub/latest/userguide/fsbp-standard.html |
| OWASP Cloud Top 10 | https://owasp.org/www-project-cloud-native-application-security-top-10/ |

---

## D1. 인젝션 및 입력 검증 (Serverless Top 10)

- [ ] event 데이터를 검증 없이 쿼리/명령에 직접 사용하지 않는가
- [ ] SQL Injection 방지를 위해 파라미터 바인딩이 사용되는가
- [ ] XXE 방지를 위해 XML 파서 외부 엔티티가 비활성화되어 있는가
- [ ] XSS/CSP 방어가 API Gateway 응답에 적용되어 있는가
- [ ] 안전하지 않은 역직렬화(pickle.loads 등)가 사용되지 않는가

## D2. 인증 및 접근 제어

- [ ] authorizationType이 "NONE"으로 설정되지 않았는가
- [ ] IAM 정책에 `"Action": "*"` 또는 `"Resource": "*"`가 없는가
- [ ] 함수별 개별 IAM 실행 역할이 할당되어 있는가 (AWS Lambda Docs)
- [ ] Permissions Boundary가 설정되어 있는가 (AWS Lambda Docs)
- [ ] 임시 자격증명(STS)만 사용되고 장기 자격증명이 없는가 (Well-Architected)
- [ ] API Gateway에 인증/인가 메커니즘(Cognito, Lambda Authorizer)이 적용되어 있는가

## D3. 시크릿 및 데이터 보호

- [ ] 시크릿이 환경변수 직접 참조가 아닌 Secrets Manager를 통해 로드되는가
- [ ] 환경 변수가 KMS로 암호화되어 있는가 (AWS Lambda Docs)
- [ ] 데이터 분류 체계가 정의되어 있는가 (Well-Architected)
- [ ] 태그(Tag)에 민감 정보가 포함되지 않는가 (AWS Lambda Docs)
- [ ] 전송 중 데이터가 TLS 1.2+ 로 암호화되는가

## D4. 네트워크 및 인프라

- [ ] DB 접근 시 VPC 내에서 실행되는가
- [ ] 외부 호출 시 HTTPS 엔드포인트만 사용하는가
- [ ] TLS 1.3이 권장되고 PFS 암호화 스위트가 사용되는가 (Well-Architected)
- [ ] WAF/API Gateway가 DDoS 방어를 위해 구성되어 있는가
- [ ] VPC 엔드포인트를 통해 AWS 서비스에 접근하는가 (인터넷 경유 최소화)

## D5. 로깅 및 모니터링

- [ ] 에러 응답에 traceback이 포함되지 않는가
- [ ] CloudTrail Lambda 이벤트 로깅이 활성화되어 있는가 (AWS Lambda Docs)
- [ ] GuardDuty Lambda Protection이 활성화되어 있는가 (AWS Lambda Docs)
- [ ] 로그가 중앙 수집(CloudWatch Logs)되고 있는가
- [ ] 보안 이벤트에 대한 자동 알림/교정이 설정되어 있는가 (Well-Architected)
- [ ] Lambda 호출 메트릭(에러율, 스로틀링)이 모니터링되는가

## D6. 런타임 및 설정

- [ ] Lambda timeout이 명시적으로 설정되어 있는가
- [ ] Lambda memory가 명시적으로 설정되어 있는가
- [ ] Reserved Concurrency가 설정되어 DoS 방어가 적용되는가 (AWS Lambda Docs)
- [ ] DLQ(Dead Letter Queue)가 구성되어 실패 이벤트가 보존되는가 (AWS Lambda Docs)
- [ ] 임시 파일(/tmp) 사용 후 정리가 수행되는가 (컨테이너 재사용 시 데이터 유출 방지)
- [ ] RDS Proxy를 통해 DB에 접속하는가 (연결 풀링 + 자격증명 관리)

## D7. 코드 무결성 및 배포

- [ ] Code Signing이 `Enforce` 모드로 설정되어 있는가 (AWS Lambda Docs)
- [ ] Lambda Layer에 서명 검증이 적용되는가 (AWS Lambda Docs)
- [ ] IaC(CloudFormation/SAM/CDK) 전용 배포가 사용되는가 (콘솔 수동 배포 금지)
- [ ] SAST/DAST가 배포 파이프라인에 통합되어 있는가

## D8. 의존성 관리

- [ ] `requirements.txt`에 정확한 버전이 고정(`==`)되어 있는가
- [ ] `pip-audit` 결과 Critical CVE가 없는가
- [ ] 중앙 패키지 관리 정책이 적용되어 있는가

## D9. 거버넌스 및 컴플라이언스

- [ ] SCP(Service Control Policy)로 Lambda 관련 위험 작업이 제한되어 있는가 (Well-Architected)
- [ ] FIPS 엔드포인트가 필요한 규제 환경에서 FIPS 지원이 설정되어 있는가
- [ ] 정기 침투 테스트가 수행되는가 (Well-Architected)
