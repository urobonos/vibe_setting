# SRS: HongCafe Global 인프라 요구사항 명세서

> HongCafe Global 서비스의 인프라 구성 요소(데이터 싱크, CI/CD, 모니터링)에 대한 소프트웨어 요구사항을 정의한다.

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-15 |
| 유형 | SRS |
| 상태 | 초안 |

---

## 내용

## 1. 개요

### 1.1 목적

본 문서는 HongCafe Global 서비스의 인프라 소프트웨어 요구사항을 정의한다. 국가 간 데이터 동기화, CI/CD 자동화, 중앙 로그 수집 시스템의 기능적·비기능적 요구사항을 명세하여 설계(SDD) 및 개발의 기준선을 제공한다.

### 1.2 범위

| 서브시스템 | 설명 | SDD 참조 |
|-----------|------|----------|
| **Data Sync** | 국가 간(USA ↔ KOR ↔ JPN) account/coin 비동기 동기화 | `lambda-pubsub-sdd.md` |
| **Publisher** | CI4 Backend → SNS FIFO 이벤트 발행 | `php-sns-publisher-sdd.md` |
| **CI/CD Pipeline** | BE/FE Bitbucket Pipelines + SSM Atomic Deploy | `cicd-pipeline-sdd.md` |
| **Lambda CI/CD** | Lambda 함수 자동 빌드/배포 | `lambda-cicd-sdd.md` |
| **Logpull** | KOR 중앙 로그 수집 및 모니터링 | `lambda-logpull-sdd.md` |

### 1.3 용어 정의

| 용어 | 정의 |
|------|------|
| Hub-and-Spoke | KOR SNS FIFO를 중앙 허브로, 각 국가 SQS를 스포크로 연결하는 팬아웃 패턴 |
| Atomic Deploy | symlink 전환을 통한 무중단 배포 방식 |
| pub_id | `global_sync_pub_log.pub_log_seq` — 발행 로그 시퀀스, 멱등성 체크 키 |
| sub_status | 동기화 수신 상태 (0=대기, 1=처리중, 2=실패, 3=완료) |
| pub_status | 발행 상태 (0=대기, 1=성공, 2=실패, 9=영구실패) |

### 1.4 관련 문서

| 문서 | 경로 |
|------|------|
| 인프라 구성 | `docs/infrastructure.md` |
| Lambda Pub/Sub SDD | `docs/output/specs/lambda-pubsub-sdd.md` |
| PHP SNS Publisher SDD | `docs/output/specs/php-sns-publisher-sdd.md` |
| CI/CD Pipeline SDD | `docs/output/specs/cicd-pipeline-sdd.md` |
| Lambda CI/CD SDD | `docs/output/specs/lambda-cicd-sdd.md` |
| Lambda Logpull SDD | `docs/output/specs/lambda-logpull-sdd.md` |
| IDD | `docs/output/specs/hongcafe-global-idd.md` |

---

## 2. 기능 요구사항

### 2.1 Data Sync (FR-DS)

| ID | 요구사항 | 우선순위 | 현재 상태 |
|----|---------|---------|----------|
| FR-DS-01 | 국가 A에서 발생한 account/coin 변경 이벤트가 SNS FIFO를 통해 모든 국가 SQS에 팬아웃되어야 한다 | P0 | SNS/SQS 인프라 구성 완료 |
| FR-DS-02 | 각 국가 Lambda는 SQS 메시지를 수신하여 `parse_message()`로 필수 필드(pub_id, event_type, entity_id, payload)를 검증해야 한다 | P0 | USA 구현 완료 |
| FR-DS-03 | `pub_id` 기반 멱등성 체크로 중복 처리를 방지해야 한다 (`is_already_processed()`) | P0 | USA 구현 완료 |
| FR-DS-04 | `route_event()`는 4종 이벤트 유형(account_create, account_update, coin_transfer, coin_adjust)을 분기 처리해야 한다 | P0 | 분기 구현 완료, 핸들러 본문 TODO |
| FR-DS-05 | 처리 상태를 `sub_status`로 관리해야 한다 (0→1→3 성공 / 0→1→2 실패) | P0 | USA 구현 완료 |
| FR-DS-06 | `batchItemFailures`로 부분 실패를 SQS에 보고하여 실패 메시지만 재전송되어야 한다 | P1 | USA 구현 완료 |
| FR-DS-07 | KOR Lambda는 USA와 동일한 처리 로직을 수행해야 한다 | P1 | 스켈레톤 |
| FR-DS-08 | JPN Lambda는 USA와 동일한 처리 로직을 수행해야 한다 | P2 | 미생성 |

### 2.2 Publisher (FR-PB)

| ID | 요구사항 | 우선순위 | 현재 상태 |
|----|---------|---------|----------|
| FR-PB-01 | CI4 Backend에서 account/coin 변경 시 SNS FIFO에 메시지를 발행해야 한다 | P0 | **미구현** |
| FR-PB-02 | 발행 기록을 `global_sync_pub_log` 테이블에 저장해야 한다 (pub_status 관리) | P0 | **미구현** |
| FR-PB-03 | SNS 발행 실패 시 비즈니스 트랜잭션을 롤백하지 않고 `pub_status=2`로 마킹해야 한다 | P0 | **미구현** |
| FR-PB-04 | `pub_status=2` AND `retry_count < 5`인 레코드를 배치 재시도해야 한다 (5분 주기) | P1 | **미구현** |
| FR-PB-05 | MessageGroupId는 `{국가코드}:{엔티티타입}:{서브타입}:{entity_id}` 형식이어야 한다 | P0 | **미구현** |

### 2.3 CI/CD Pipeline (FR-CD)

| ID | 요구사항 | 우선순위 | 현재 상태 |
|----|---------|---------|----------|
| FR-CD-01 | production/staging 브랜치 머지 후 수동 승인 게이트를 거쳐야 한다 | P0 | 구현 완료 |
| FR-CD-02 | develop 브랜치는 수동 승인 없이 직접 배포되어야 한다 | P0 | 구현 완료 |
| FR-CD-03 | BE: git clone → composer install → phpunit → 성공 시 symlink 전환 + php-fpm reload | P0 | 구현 완료 |
| FR-CD-04 | FE: git clone → npm ci → npm run build → 성공 시 symlink 전환 + pm2 restart | P0 | 구현 완료 |
| FR-CD-05 | 테스트/빌드 실패 시 릴리즈 디렉토리를 삭제하고 기존 서비스를 유지해야 한다 | P0 | 구현 완료 |
| FR-CD-06 | 릴리즈는 최대 5개까지 보관하여 롤백을 지원해야 한다 | P1 | 구현 완료 |
| FR-CD-07 | 3환경(prd/stg/dev)이 독립적으로 배포되어야 한다 | P0 | 구현 완료 |

### 2.4 Lambda CI/CD (FR-LC)

| ID | 요구사항 | 우선순위 | 현재 상태 |
|----|---------|---------|----------|
| FR-LC-01 | `lambda/**` 경로 변경 시 Lambda 배포 파이프라인이 트리거되어야 한다 | P1 | **미구현** |
| FR-LC-02 | 국가별 개별 zip 패키징 후 순차 배포(USA → KOR)해야 한다 | P1 | **미구현** |
| FR-LC-03 | 배포 시 `publish-version`으로 롤백 기반을 확보해야 한다 | P1 | **미구현** |

### 2.5 Logpull (FR-LP)

| ID | 요구사항 | 우선순위 | 현재 상태 |
|----|---------|---------|----------|
| FR-LP-01 | USA/JPN Aurora의 `global_sync_sub_log`를 KOR Aurora에 주기적으로 수집해야 한다 | P2 | **미구현** |
| FR-LP-02 | watermark 기반으로 중복 없이 신규 건만 수집해야 한다 | P2 | **미구현** |
| FR-LP-03 | 수집 실패가 서비스 동기화에 영향을 주어서는 안 된다 | P2 | **미구현** |

---

## 3. 비기능 요구사항

### 3.1 성능 (NFR-P)

| ID | 요구사항 | 기준 |
|----|---------|------|
| NFR-P-01 | Lambda SQS 처리 시간 | 단건 60초 이내 (Lambda Timeout) |
| NFR-P-02 | SNS→SQS→Lambda 전파 지연 | 5초 이내 (정상 상태) |
| NFR-P-03 | BE 배포 총 소요 시간 | 10분 이내 (clone~reload) |
| NFR-P-04 | FE 배포 총 소요 시간 | 10분 이내 (clone~pm2 start) |
| NFR-P-05 | PHP SNS 발행 응답 시간 | 크로스리전 HTTPS 포함 5초 이내 |

### 3.2 가용성 (NFR-A)

| ID | 요구사항 | 기준 |
|----|---------|------|
| NFR-A-01 | BE/FE 배포 시 다운타임 | BE 무중단 (symlink + reload), FE 순간 중단 (pm2 delete + start) |
| NFR-A-02 | 배포 실패 시 롤백 | symlink 재지정으로 5분 이내 복구 |
| NFR-A-03 | Lambda 실패 시 재처리 | SQS 재전송 + batchItemFailures |

### 3.3 보안 (NFR-S)

| ID | 요구사항 | 기준 |
|----|---------|------|
| NFR-S-01 | Lambda→Aurora 인증 | RDS Proxy + IAM Auth Token (비밀번호 미사용) |
| NFR-S-02 | SNS/SQS 암호화 | SNS: KMS, SQS: SQS Managed SSE |
| NFR-S-03 | CI/CD IAM | 최소 권한 (SSM send-command만) |
| NFR-S-04 | EC2 SSH | SSM Session Manager 경유 (SSH 포트 비노출) |
| NFR-S-05 | 환경 변수 | Bitbucket Secured Variables, EC2 .env 파일 시스템 관리 |
| NFR-S-06 | TLS | RDS Proxy 강제, SNS HTTPS, Nginx SSL (Let's Encrypt) |

### 3.4 확장성 (NFR-SC)

| ID | 요구사항 | 기준 |
|----|---------|------|
| NFR-SC-01 | 국가 추가 | SQS 구독 + Lambda 배포 + 환경변수로 국가 추가 가능 |
| NFR-SC-02 | 이벤트 유형 추가 | `route_event()` handlers dict에 핸들러 추가로 확장 |
| NFR-SC-03 | 환경 추가 | deploy 스크립트 branch→env 매핑 추가로 확장 |

---

## 4. 제약 조건

| 항목 | 제약 |
|------|------|
| AWS 리전 | us-east-1 (USA), ap-northeast-2 (KOR), ap-northeast-1 (JPN) |
| 단일 EC2 | 3환경(prd/stg/dev)이 단일 인스턴스에서 운영 |
| FIFO 제약 | SNS/SQS FIFO — 초당 300 메시지 또는 배치 시 3,000 메시지 |
| Bitbucket Pipelines | 빌드 시간 제한 (Plan별 상이), Docker 이미지 `amazon/aws-cli` |
| Aurora MySQL | 3.12.0 (Compatible MySQL 8.0.44) |
| PHP | 8.5.3, CodeIgniter 4.7+ |
| Python | 3.12 (Lambda Runtime) |

---

## 5. 타당성 검토

### 5.1 Hub-and-Spoke 패턴의 3개국 동기화 적합성

**결론: 적합.**

단일 SNS FIFO Topic에서 3개국 SQS로 팬아웃하는 구조는 AWS 공식 지원 기능(크로스리전 SQS 구독)이다. 국가 추가 시 SQS 구독만 추가하면 되어 확장이 용이하다. FIFO 초당 300 메시지 제한은 현재 예상 트래픽 대비 충분하다.

**근거:** AWS SNS Developer Guide — FIFO topics, Cross-region SQS subscriptions.

### 5.2 Atomic Deploy의 무중단 배포 보장

**결론: BE는 보장, FE는 순간 중단.**

`ln -sfn`은 커널 수준 원자적 연산으로 BE(PHP-FPM) 전환 시 다운타임이 없다. FE(Next.js)는 `pm2 delete + start` 방식이므로 순간 중단이 발생하며, `pm2 reload` 전환으로 개선 가능하다.

**근거:** Linux `rename(2)` syscall atomicity, PM2 Cluster Mode reload documentation.

---

## 체크리스트

- [x] 기능 요구사항 정의
- [x] 비기능 요구사항 정의
- [x] 제약 조건 명시
- [x] 타당성 검토 포함
- [x] 현재 구현 상태 매핑

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 최초 작성 — 기존 SDD 5건 기반 요구사항 추출 | jypark |
