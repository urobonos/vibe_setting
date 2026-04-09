# AWS Security Best Practices

> **출처:** AWS Well-Architected Framework — Security Pillar
> **갱신일:** 2026-04-09

---

## 7가지 설계 원칙 (Design Principles)

### 1. 강력한 신원 기반 (Implement a Strong Identity Foundation)
- 최소 권한 원칙 (Principle of Least Privilege)
- 직무 분리 (Separation of Duties)
- 중앙화된 Identity Management
- 장기 정적 자격증명 (Long-term Static Credentials) 제거 → IAM Role 사용

### 2. 추적 가능성 유지 (Maintain Traceability)
- 실시간 모니터링, 알림, 감사 (Audit)
- 로그/메트릭 수집을 시스템에 통합
- 자동 조사 및 조치 실행 (CloudTrail, CloudWatch, GuardDuty)

### 3. 모든 계층에 보안 적용 (Apply Security at All Layers)
- 심층 방어 (Defense in Depth):
  - Edge of Network → VPC → Load Balancing → Instance → OS → Application → Code

### 4. 보안 자동화 (Automate Security Best Practices)
- Infrastructure as Code (IaC) 기반 보안 제어
- 버전 제어 템플릿으로 관리

### 5. 데이터 보호 (Protect Data in Transit and at Rest)
- 민감도 수준별 데이터 분류
- 암호화 (Encryption), 토큰화 (Tokenization), 접근 제어

### 6. 데이터에서 사람 제거 (Keep People Away from Data)
- 직접 접근/수동 처리 최소화
- 자동화 도구 활용

### 7. 보안 사건 대비 (Prepare for Security Events)
- Incident Management 프로세스 구현
- 사건 대응 시뮬레이션 정기 실행
- 자동화 도구로 탐지→조사→복구 가속

---

## 7가지 보안 영역

| 영역 | 핵심 AWS 서비스 |
|------|----------------|
| Security Foundations | AWS Organizations, Control Tower |
| IAM | IAM, IAM Identity Center (SSO), STS |
| Detection | CloudTrail, GuardDuty, Security Hub, Config |
| Infrastructure Protection | VPC, WAF, Shield, Network Firewall |
| Data Protection | KMS, Certificate Manager, Macie |
| Incident Response | Detective, Systems Manager, Lambda |
| Application Security | Inspector, CodeGuru, WAF |

---

## 서비스별 보안 체크리스트

### IAM
- [ ] 루트 계정 MFA 활성화, 일상 작업에 루트 사용 금지
- [ ] 역할 기반 접근 제어 (RBAC) — 사용자 대신 Role 사용
- [ ] IAM 정책 최소 권한 원칙 적용
- [ ] 장기 Access Key 제거 → IAM Role + STS 임시 자격증명
- [ ] IAM Access Analyzer로 미사용 권한 탐지
- [ ] 서비스 계정에 Permission Boundary 설정

### S3
- [ ] Block Public Access 활성화 (계정 수준 + 버킷 수준)
- [ ] 버저닝 활성화 (프로덕션 버킷)
- [ ] 서버 측 암호화: SSE-S3 또는 SSE-KMS
- [ ] CloudFront OAC로 직접 접근 차단
- [ ] S3 Access Logs 활성화
- [ ] 수명 주기 정책: 비활성 객체 Glacier 전환
- [ ] MFA Delete 활성화 (중요 버킷)

### RDS (MySQL)
- [ ] 저장 시 암호화 (Encryption at Rest) — KMS
- [ ] 전송 중 암호화 (SSL/TLS 강제)
- [ ] Security Group: 애플리케이션 서버만 3306 허용
- [ ] IAM Database Authentication 활성화 (지원 시)
- [ ] 자동 백업 활성화 + 보존 기간 설정
- [ ] Multi-AZ 배포 (프로덕션)
- [ ] Enhanced Monitoring 활성화
- [ ] RDS Proxy: 커넥션 풀링 + IAM 인증

### Lambda
- [ ] 최소 권한 실행 역할 (Execution Role) — 필요한 서비스만
- [ ] VPC 배치 (내부 리소스 접근 필요 시)
- [ ] 환경변수 암호화 (KMS)
- [ ] 함수 URL 사용 시 인증 모드 설정 (AWS_IAM)
- [ ] Provisioned Concurrency 또는 Reserved Concurrency로 DoS 방어
- [ ] 런타임 버전 정기 업데이트

### CloudFront
- [ ] HTTPS 강제 (Viewer Protocol Policy: redirect-to-https)
- [ ] Origin Access Control (OAC) 설정
- [ ] 커스텀 SSL 인증서 (ACM)
- [ ] Geo Restriction (필요 시)
- [ ] WAF 연동

### VPC
- [ ] 퍼블릭/프라이빗 서브넷 분리
- [ ] NAT Gateway: 프라이빗 서브넷 아웃바운드만
- [ ] Security Group: 최소 포트만 개방, SG 간 참조 사용
- [ ] NACL: 서브넷 수준 추가 방어
- [ ] VPC Flow Logs 활성화
- [ ] VPC Endpoint: S3, DynamoDB 등 AWS 서비스 프라이빗 접근

---

## 참고 자료

- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [AWS Security Best Practices Whitepaper](https://docs.aws.amazon.com/whitepapers/latest/aws-security-best-practices/welcome.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
