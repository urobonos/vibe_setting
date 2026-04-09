# AWS Well-Architected — Security Pillar

> 출처: https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/
> 최종 갱신: 2026-04-08

## 5대 보안 원칙

### 1. Identity and Access Management (IAM)
최소 권한 원칙으로 접근 제어.

- IAM 역할/정책으로 리소스 접근 제어
- 최소 필요 권한만 부여
- 불필요한 권한 정기 감사/제거

### 2. Infrastructure Protection
네트워크 보안과 리소스 격리로 비인가 접근 차단.

- VPC, 보안 그룹, 네트워크 ACL로 트래픽 제어
- 다층 방어(Defense-in-Depth) 구현
- 네트워크 경계 모니터링/제어

### 3. Data Protection
암호화와 데이터 분류로 민감 정보 보호.

- **저장 시 암호화**: AWS KMS 또는 S3 암호화
- **전송 시 암호화**: TLS/SSL
- 민감도 기반 데이터 분류 + 접근 제어

### 4. Detective Controls
모니터링과 로깅으로 보안 이벤트 식별/대응.

- **CloudTrail**: API 감사
- **AWS Config**: 리소스 규정 준수
- **CloudWatch**: 실시간 모니터링/알림
- 중앙 집중 로깅

### 5. Incident Response
보안 이벤트 대응 프로세스와 도구.

- 인시던트 대응 절차 수립/유지
- 일반적 보안 이벤트 자동 대응
- 정기적 대응 훈련

## 프로젝트 적용

| 원칙 | 프로젝트 대응 |
|------|-------------|
| IAM | RDS Proxy IAM Auth, Lambda 실행 역할 최소 권한 |
| Infrastructure | VPC, 보안 그룹(80/443/20010), SSM 접속 |
| Data | AES-256-CBC 암호화, HTTPS 전용, Aurora 암호화 |
| Detective | CloudWatch 로그, log_message() |
| Incident | Atomic Deploy 롤백, Lambda 모니터링 |
