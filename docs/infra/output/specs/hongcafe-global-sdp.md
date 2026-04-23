# SDP: HongCafe Global 인프라 개발 계획서

> HongCafe Global 서비스 인프라의 개발 단계, 마일스톤, 리스크 관리를 정의하는 소프트웨어 개발 계획서.

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-15 |
| 유형 | SDP |
| 상태 | 초안 |

---

## 내용

## 1. 개요

### 1.1 목적

본 문서는 HongCafe Global 인프라 구성 요소의 개발 계획을 정의한다. 현재 구현 상태를 기준으로 잔여 작업을 단계별로 구성하고, 우선순위·의존성·리스크를 명시하여 체계적인 개발 진행을 지원한다.

### 1.2 프로젝트 범위

| 서브시스템 | 현재 상태 | 잔여 작업 |
|-----------|----------|----------|
| **CI/CD Pipeline (BE/FE)** | **운영 중** | 개선 사항만 (deploy-be.sh 결함 수정, FE OOM 대��) |
| **Data Sync (Lambda)** | **부분 구현** | USA 4종 핸들러 본문, KOR/JPN Lambda 완성 |
| **PHP Publisher** | **미구현** | 전체 구현 (SnsPublisher, GlobalSyncService, pub_log) |
| **Lambda CI/CD** | **미구현** | 파이프라인 YAML 작성, IAM 권한 추가 |
| **Logpull** | **미구현** | VPC Peering 또는 대안 방식 결정 후 구현 |

### 1.3 관련 문서

| 문서 | 경로 |
|------|------|
| SRS | `docs/output/specs/hongcafe-global-srs.md` |
| IDD | `docs/output/specs/hongcafe-global-idd.md` |
| SDD 5건 | `docs/output/specs/*-sdd.md` |
| 인프라 구성 | `docs/infrastructure.md` |

---

## 2. 개발 단계

### Phase 0: 인프라 안정화 (현재 진행 중)

**목표:** 현재 운영 중인 CI/CD 파이프라인의 알려진 결함 수정

| 작업 | 설명 | 우선순위 | 의존성 | SRS |
|------|------|---------|--------|-----|
| deploy-be.sh 결함 수정 | `set -e` PHPUnit 충돌, `chown apache:apache` → `nginx:nginx` | P0 | 없음 | FR-CD-03 |
| PHPUnit 283개 에러 수정 | Modular Monolith 리팩토링 후 테스트 미반영 | P0 | BE 리포 작업 | FR-CD-03 |
| FE OOM 대응 | STG 배포 시 npm run build OOM Kill | P1 | 없음 | FR-CD-04 |
| 고아 릴리즈 삭제 | `be_20260414090124` 불완전 릴리즈 | P2 | 없음 | — |

### Phase 1: Data Sync 파이프라인 완성

**목표:** USA Lambda의 4종 핸들러 본문 구현 + PHP Publisher 구현 → end-to-end 동기화 가동

**의존성 순서:** Publisher → Lambda 핸들러 (Publisher가 메시지를 발행해야 Lambda 테스트 가능)

#### Phase 1-A: PHP Publisher 구현

| 작업 | 설명 | 의존성 | SRS |
|------|------|--------|-----|
| `global_sync_pub_log` DDL | Aurora athena DB에 테이블 생성 | 없음 | FR-PB-02 |
| `SnsPublisher.php` | SNS FIFO 발행 래퍼 (app/Libraries/) | 없음 | FR-PB-01 |
| `GlobalSyncService.php` | 이벤트 분류, pub_log 관리 (app/Services/) | SnsPublisher | FR-PB-01 |
| `GlobalSyncPubLogModel.php` | pub_log CRUD (app/Models/) | DDL | FR-PB-02 |
| EC2 IAM Role SNS 권한 | `sns:Publish` 추가 | 없음 | FR-PB-01 |
| `.env` SYNC_REGION 추가 | 국가별 환경변수 | 없음 | FR-PB-05 |
| 배치 재시도 | `retryFailed()` Cron/Spark Command | GlobalSyncService | FR-PB-04 |
| 통합 지점 | Controller/Service에서 `publishEvent()` 호출 | 전체 | FR-PB-01 |

#### Phase 1-B: USA Lambda 핸들러 완성

| 작업 | 설명 | 의존성 | SRS |
|------|------|--------|-----|
| `handle_account_create()` | tb_account INSERT 로직 | pub_log 테이블 | FR-DS-04 |
| `handle_account_update()` | tb_account UPDATE 로직 | 없음 | FR-DS-04 |
| `handle_coin_transfer()` | 코인 이동 반영 로직 | 없음 | FR-DS-04 |
| `handle_coin_adjust()` | 관리자 코인 보정 로직 | 없음 | FR-DS-04 |
| end-to-end 테스트 | PHP → SNS → SQS → Lambda → Aurora 검증 | Phase 1-A 완료 | FR-DS-01~06 |

### Phase 2: 다국가 확장

**목표:** KOR/JPN Lambda 완성, Lambda CI/CD 자동화

| 작업 | 설명 | 의존성 | SRS |
|------|------|--------|-----|
| KOR Lambda 코드 | USA handler.py 복제 + 환경변수 조정 | Phase 1-B | FR-DS-07 |
| KOR VPC/Layer/Env | AWS 콘솔 설정 | 없음 | FR-DS-07 |
| JPN Lambda 생성 | `lambda/jpn/` 디렉토리 + AWS Lambda 생성 | Phase 1-B | FR-DS-08 |
| JPN VPC/Layer/Env | AWS 콘솔 설정 | 없음 | FR-DS-08 |
| Lambda CI/CD 파이프라인 | Bitbucket Pipelines YAML, IAM 권한 | 코드 완성 | FR-LC-01~03 |
| DLQ 설정 | 3개 SQS에 FIFO DLQ 추가 | 없음 | NFR-A-03 |

### Phase 3: 모니터링 (선택)

**목표:** 중앙 로그 수집 및 장애 감지

| 작업 | 설명 | 의존성 | SRS |
|------|------|--------|-----|
| VPC Peering 구성 | KOR ↔ USA, KOR ↔ JPN | 보안 정책 승인 | FR-LP-01 |
| logpull Lambda 구현 | `lambda/kor/logpull/` 코드 작성 | VPC Peering | FR-LP-01~03 |
| CloudWatch Alarm | Lambda 에러율, SQS 체류 시간 알림 | Phase 2 | — |
| EventBridge 활용 결정 | 배치 재처리 핸들러 구현 또는 Rule 비활성화 | Phase 1-B | — |

---

## 3. 마일스톤

| # | 마일스톤 | 기준 | 의존 Phase |
|---|---------|------|-----------|
| M0 | CI/CD 안정화 | deploy-be.sh 수정, PHPUnit 통과, 배포 성공 | Phase 0 |
| M1 | end-to-end 동기화 가동 | PHP 발행 → USA Lambda 처리 → Aurora 반영 검증 | Phase 1 |
| M2 | 3개국 동기화 가동 | KOR/JPN Lambda 배포, 전 국가 동기화 검증 | Phase 2 |
| M3 | 모니터링 운영 | logpull 가동, CloudWatch 알림 수신 확인 | Phase 3 |

---

## 4. 현재 진행 상황

### 4.1 구현 완료

| 구성 요소 | 상태 | 비고 |
|-----------|------|------|
| SNS FIFO Topic | ✅ 생성 완료 | ap-northeast-2 |
| SQS FIFO Queue (3개) | ✅ 생성 완료 | USA/KOR/JPN |
| USA Lambda (sqs_push) | ✅ 배포 완료 | 4종 핸들러 TODO |
| KOR Lambda (sqs_push) | ⬜ 스켈레톤 | 로그만 출력 |
| BE/FE CI/CD Pipeline | ✅ 운영 중 | 3환경 배포 |
| SSL/TLS | ✅ 적용 완료 | Let's Encrypt SAN |
| SDD 문서 5건 | ✅ 작성 완료 | 2026-04-15 현재 구조 동기화 |
| SRS/IDD/SDP | ✅ 작성 완료 | 2026-04-15 |

### 4.2 미구현

| 구성 요소 | Phase | 차단 요인 |
|-----------|-------|----------|
| PHP Publisher | 1-A | 없음 (착수 가능) |
| USA 4종 핸들러 본문 | 1-B | Publisher 선행 권장 |
| KOR/JPN Lambda 완성 | 2 | Phase 1 완료 필요 |
| Lambda CI/CD | 2 | 코드 완성 필요 |
| Logpull | 3 | VPC Peering 승인 |

---

## 5. 리스크 관리

| ID | 리스크 | 영향 | 확률 | 대응 |
|----|--------|------|------|------|
| R1 | PHPUnit 283개 에러 수정 지연 | BE 배포 파이프라인 사용 불가 | 높음 | 테스트 스킵 임시 방안 + 단계적 수정 |
| R2 | 크로스리전 SNS 발행 레이턴시 | 사용자 응답 지연 | 낮음 | 비동기 발행으로 HTTP 응답과 분리 |
| R3 | VPC Peering 보안 승인 지연 | Logpull 구현 지연 | 중간 | 옵션 B(SNS/SQS 중계) 대안 보유 |
| R4 | SQS DLQ 미설정 상태 장기화 | 실패 메시지 소실 (4일 retention 후) | 중간 | Phase 2에서 DLQ 설�� 우선 |
| R5 | 단일 EC2 장애 | 3환경 전체 서비스 중단 | 낮음 | AWS Auto Recovery, 정기 AMI 백업 |
| R6 | EventBridge Rule 코드 미대응 | 1분 주기 불필요한 Lambda 실행 | 낮음 | Rule 비활성화 또는 핸들러 구현 |

---

## 6. 개발 방법론

### 6.1 브랜치 전략

| 브랜치 | 용도 | 배포 환경 |
|--------|------|----------|
| `develop` | 개발/테스트 | DEV (자동 배포) |
| `staging` | QA/검증 | STG (수동 승인) |
| `production` | 릴리즈 | PRD (수동 승인) |

### 6.2 코드 리뷰 및 품질

- Bitbucket PR 기반 코드 리뷰
- PHPUnit (BE), npm run build 검증 (FE)
- Lambda: pytest (Phase 2 Lambda CI/CD에서 자동화)

### 6.3 문서 관리

| 문서 유형 | 위치 | 갱신 시점 |
|-----------|------|----------|
| SDD | `docs/output/specs/` | 설계 변경 시 |
| SRS/IDD/SDP | `docs/output/specs/` | 요구사항/인터페이스/계획 변경 시 |
| 작업 이력 | `docs/tasks/history.md` | 매 작업 완료 시 |
| 인프라 구성 | `docs/infrastructure.md` | EC2/AWS 설정 변경 시 |

---

## 7. 타당성 검토

### 7.1 Phase 순서의 적합성

**결론: 적합.**

Phase 0(안정화) → Phase 1(핵심 기능) → Phase 2(확장) → Phase 3(모니터링) 순서는 의존성 그래프를 반영한다. Publisher가 없으면 Lambda end-to-end 테스트가 불가능하고, 단일 국가(USA) 검증 없이 다국가 확장은 리스크가 크다. Logpull은 동기화 자체가 아닌 모니터링이므로 최후 단계가 적합하다.

### 7.2 단일 EC2 운영의 지속 가능성

**결론: 현 규모에서 지속 가능, 성장 시 분리 필요.**

3환경을 단일 EC2에서 운영하는 구조는 현재 트래픽 규모에서 충분하다. PHP-FPM Pool과 PM2 프로세스로 환경이 분리되어 있어 간섭은 제한적이다. 다만 PRD 트래픽이 증가하면 STG/DEV와의 리소스 경쟁이 발생할 수 있으므로, 트래픽 모니터링 후 환경별 인스턴스 분리를 검토해야 한다.

---

## 체크리스트

- [x] 개발 단계 정의
- [x] 마일스톤 설정
- [x] 현재 진행 상황 매핑
- [x] 리스크 관리 계획
- [x] 타당성 검토 포함

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 최초 작성 — SDD 5건 + SRS 기반 개발 계획 수립 | jypark |
