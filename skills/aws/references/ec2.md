# EC2

## 인스턴스 프로비저닝 규칙

- 인스턴스 타입 선택 시 **사용자 확인 필수** (t3.micro vs t3.small 등). **Why:** 인스턴스 타입 = 비용/성능 트레이드오프 결정 — 운영 시 변경하려면 재시작 필요(다운타임)
- AMI 는 **Amazon Linux 2023** 또는 **Ubuntu 22.04 LTS** 기본. 다른 AMI 사용 시 사용자 확인. **Why:** 비표준 AMI 는 보안 패치 주기/유지보수 지원이 불확실
- 키페어는 **기존 키 사용 우선**, 신규 생성 시 사용자 승인. **Why:** 키페어는 한 번 생성 시 다운로드 기회 1회 — 분실 시 SSH 접근 불가

## 보안 그룹

```
sg-ec2:
  - Inbound:  사용자가 명시한 포트만 허용 (예: 22/SSH, 80/HTTP, 443/HTTPS)
  - Outbound: 0.0.0.0/0 허용 (기본) 또는 사용자 지정
  - SSH(22): 특정 IP 대역만 허용. 0.0.0.0/0 절대 금지 → Checkpoint 발동
```

> **Why (SSH 0.0.0.0/0 차단):** SSH 22 를 인터넷 전체에 개방하면 봇넷 brute-force 공격 즉시 시작 — 운영 인스턴스 침해 위험. 관리자 IP 제한 또는 SSM Session Manager 경유가 표준.

## IAM 역할 바인딩

- EC2 에는 **IAM Instance Profile** 을 통해 역할 부여. IAM Instance Profile 로 인증한다. **Why:** 액세스 키를 인스턴스에 직접 주입하면 키 노출/회전 부담 — Instance Profile 은 IMDS 를 통한 자동 토큰 회전
- S3, SQS 등 접근 시 Instance Profile 권한으로 처리

## 사용자 데이터 스크립트

```bash
#!/bin/bash
# 사용자 데이터 스크립트 규칙:
# - 시크릿은 SSM Parameter Store 또는 Secrets Manager 로 관리한다
# - 로그는 /var/log/user-data.log 에 기록
# - 실패 시 CloudWatch 에 알림 전송
```

> **Why (시크릿 분리):** user-data 는 EC2 콘솔/API 에서 평문 조회 가능 — 시크릿 인라인 시 IAM `ec2:DescribeInstanceAttribute` 권한 보유자 모두에게 노출.

## 자가 검증 체크리스트

- [ ] 보안 그룹에 SSH 0.0.0.0/0 미허용
- [ ] IAM Instance Profile 사용 (액세스 키 미사용)
- [ ] 사용자 데이터에 시크릿 하드코딩 미포함
- [ ] 인스턴스 타입/AMI 사용자 확인 완료
