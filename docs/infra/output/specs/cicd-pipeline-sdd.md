# SDD: CI/CD Pipeline (BE/FE)

> SDD: CI/CD Pipeline (BE/FE)

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

본 문서는 HongCafe Global 서비스의 백엔드(BE)와 프론트엔드(FE) 배포 파이프라인을 정식 설계 문서로 기록한다. 현재 운영 중인 시스템을 대상으로 하며, 신규 설계가 아닌 기존 구현의 공식 문서화임을 명시한다.

**문서화 목적:**
- 운영 중인 파이프라인의 구조와 동작 방식을 명확히 기록
- 신규 팀원의 온보딩 기준 문서 역할
- 장애 대응 및 롤백 절차의 공식 참조 문서 역할
- 향후 개선 작업의 기준선(Baseline) 제공

### 1.2 범위

| 항목 | 범위 |
|------|------|
| **Backend** | Bitbucket Pipelines → SSM → EC2 (CodeIgniter 4, PHP-FPM 8.5.3) |
| **Frontend** | Bitbucket Pipelines → SSM → EC2 (Next.js 16, PM2, Node.js v24.14.0) |
| **배포 방식** | Atomic Deploy (symlink 전환) |
| **대상 환경** | 3환경: Production / Staging / Develop (단일 EC2 `prod_ec2_hongcafe_usa`, `i-0183f9ab360cc9d80`) |
| **배포 스크립트** | EC2 상주 외부 스크립트 (`deploy-be.sh`, `deploy-fe.sh`) |
| **제외 범위** | Lambda 배포, DB 프로비저닝, Nginx 설정 변경 |

### 1.3 관련 문서

| 문서 | 경로 |
|------|------|
| 인프라 전체 구성 | `docs/infrastructure.md` |
| BE 파이프라인 정의 | `hongcafe/ci-cd/backend/bitbucket-pipelines.yml` |
| FE 파이프라인 정의 | `hongcafe/ci-cd/frontend/bitbucket-pipelines.yml` |
| BE 배포 스크립트 | `hongcafe/ci-cd/scripts/deploy-be.sh` |
| FE 배포 스크립트 | `hongcafe/ci-cd/scripts/deploy-fe.sh` |
| Nginx 환경별 설정 | `hongcafe/server/nginx/conf.d/hongcafe-prd.conf` 등 |
| Lambda SDD | `docs/output/specs/lambda-pubsub-sdd.md` |

---

## 2. 아키텍처

### 2.1 전체 배포 흐름 (Bitbucket → SSM → EC2 스크립트)

배포 흐름은 Bitbucket Pipelines에서 시작하여 AWS SSM을 경유해 EC2 인스턴스의 **외부 배포 스크립트**를 실행한다. 파이프라인 YAML에 인라인 쉘 명령이 아닌, EC2에 상주하는 `deploy-be.sh` / `deploy-fe.sh`를 호출하는 구조이다.

**전체 흐름 단계:**

1. 개발자가 `production` / `staging` / `develop` 브랜치에 코드를 머지
2. Bitbucket Pipelines가 자동으로 파이프라인 실행
3. **스텝 1 (Ready to Deploy):** 수동 승인 게이트 (production/staging만, develop은 직접 배포)
4. **스텝 2 (Atomic Deploy):** `deployment: US-Env` 레이블 스텝 실행
   - Bitbucket Pipeline 컨테이너(amazon/aws-cli)에서 `aws ssm send-command` 호출
   - EC2에서 `bash /works/hongcafe-global/scripts/deploy-{be|fe}.sh $BITBUCKET_BRANCH` 실행
   - `aws ssm wait command-executed`로 완료 대기
   - `aws ssm get-command-invocation`으로 실행 결과 확인
   - 최종 상태가 `Success`가 아니면 파이프라인 실패 처리 (`exit 1`)

### 2.2 3환경 구성 (단일 EC2)

단일 EC2 인스턴스에서 브랜치별로 환경이 분리된다.

| 브랜치 | 환경 | 경로 | PHP-FPM | Next.js | 수동 승인 |
|--------|------|------|---------|---------|----------|
| `production` | PRD | `/works/hongcafe-global/prd/` | `127.0.0.1:8080` | `:3000` | 필요 |
| `staging` | STG | `/works/hongcafe-global/stg/` | `127.0.0.1:8081` | `:3001` | 필요 |
| `develop` | DEV | `/works/hongcafe-global/dev/` | `127.0.0.1:8082` | `:3002` | 불필요 |

### 2.3 Atomic Deploy 패턴 (symlink 전환)

Atomic Deploy는 새 릴리즈 디렉토리를 완전히 준비한 후, 서비스 디렉토리의 symlink를 원자적으로 전환하는 배포 방식이다. symlink 전환 명령(`ln -sfn`)은 원자적(atomic) 연산이므로 전환 순간 다운타임이 발생하지 않는다.

**디렉토리 구조 (환경별):**

```
/works/hongcafe-global/
├── scripts/
│   ├── deploy-be.sh                              (BE 배포 스크립트)
│   └── deploy-fe.sh                              (FE 배포 스크립트)
├── ecosystem.config.js                            (PM2 3환경 설정)
├── prd/
│   ├── be -> releases/be_20260403120000           (symlink, 백엔드 활성 릴리즈)
│   ├── fe/                                        (Next.js 프론트엔드)
│   ├── config/
│   │   └── .env                                   (환경 설정 파일)
│   └── releases/
│       ├── be_20260409143022/                     (신규 릴리즈)
│       ├── be_20260403120000/                     (현재 활성)
│       └── ...                                    (최대 5개 보관)
├── stg/                                           (staging 동일 구조)
└── dev/                                           (develop 동일 구조)
```

**실패 시 처리:**
검증(테스트/빌드) 단계에서 실패하면 symlink를 전환하지 않고 신규 릴리즈 디렉토리를 즉시 삭제(`sudo rm -rf`)한다.

### 2.4 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│  Bitbucket (Cloud)                                                  │
│                                                                     │
│  production/staging/develop 브랜치 머지                              │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────┐                                           │
│  │ Step 1              │ ◄── 담당자 수동 승인 (develop은 생략)       │
│  │ "Ready to Deploy"   │                                           │
│  └──────────┬──────────┘                                           │
│             │ 승인 후 자동 진행                                      │
│             ▼                                                       │
│  ┌──────────────────────────────┐                                  │
│  │ Step 2                       │  amazon/aws-cli 컨테이너 실행     │
│  │ "Remote Deploy"              │                                  │
│  │ deployment: US-Env           │                                  │
│  └──────────┬───────────────────┘                                  │
└─────────────┼───────────────────────────────────────────────────────┘
              │ aws ssm send-command
              │ → bash deploy-{be|fe}.sh $BITBUCKET_BRANCH
              │ (IAM: HC-bitbucket-deploy)
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  AWS SSM (us-east-1)                                                │
│  Document: AWS-RunShellScript                                       │
│  Target: i-0183f9ab360cc9d80                                        │
│  Timeout: 600초                                                     │
└─────────────┬───────────────────────────────────────────────────────┘
              │ SSM Agent 경유
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  EC2: prod_ec2_hongcafe_usa (Amazon Linux 2023, aarch64)            │
│                                                                     │
│  deploy-be.sh $BRANCH          deploy-fe.sh $BRANCH                │
│  ┌────────────────────┐        ┌────────────────────┐              │
│  │ branch→env 매핑    │        │ branch→env 매핑    │              │
│  │ prd/stg/dev        │        │ prd/stg/dev        │              │
│  │                    │        │                    │              │
│  │ git clone          │        │ git clone          │              │
│  │ composer install   │        │ npm ci             │              │
│  │ phpunit            │        │ npm run build      │              │
│  │                    │        │                    │              │
│  │ 성공: symlink      │        │ 성공: symlink      │              │
│  │   + chown writable │        │   + pm2 restart    │              │
│  │   + cache:clear    │        │   + pm2 save       │              │
│  │   + reload php-fpm │        │                    │              │
│  │ 실패: rm release   │        │ 실패: rm release   │              │
│  └────────────────────┘        └────────────────────┘              │
│                                                                     │
│  ┌──────────────────────────────────────────────┐                  │
│  │ Nginx (환경별 conf.d)                         │                  │
│  │  prd: /api/* → PHP-FPM :8080 / * → :3000    │                  │
│  │  stg: /api/* → PHP-FPM :8081 / * → :3001    │                  │
│  │  dev: /api/* → PHP-FPM :8082 / * → :3002    │                  │
│  └──────────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 파이프라인 구성

### 3.1 공통 구성

| 항목 | 값 |
|------|-----|
| Pipeline 이미지 | `amazon/aws-cli` (Docker Hub) |
| 트리거 브랜치 | `production`, `staging`, `develop` |
| 스텝 수 | 2개 (production/staging), 1개 (develop) |
| 파이프라인 파일 위치 | 각 리포지토리 루트 `bitbucket-pipelines.yml` |
| SSM Timeout | 600초 |
| Deployment 환경 | `US-Env` (전 환경 공통) |

**공통 환경 변수 (Bitbucket Repository/Deployment 변수):**

| 변수명 | Secured | 설명 |
|--------|---------|------|
| `AWS_ACCESS_KEY_ID` | Yes | IAM `HC-bitbucket-deploy` 액세스 키 |
| `AWS_SECRET_ACCESS_KEY` | Yes | IAM `HC-bitbucket-deploy` 시크릿 키 |
| `AWS_DEFAULT_REGION` | No | `us-east-1` |
| `INSTANCE_ID` | No | `i-0183f9ab360cc9d80` |

### 3.2 파이프라인 YAML 구조 (BE/FE 공통 패턴)

```yaml
image: amazon/aws-cli

definitions:
  steps:
    - step: &atomic-deploy
        name: Remote Deploy
        script:
          - >
            export COMMAND_ID=$(aws ssm send-command
            --instance-ids "$INSTANCE_ID"
            --document-name "AWS-RunShellScript"
            --parameters "{\"commands\":[\"bash /works/hongcafe-global/scripts/deploy-{be|fe}.sh $BITBUCKET_BRANCH\"]}"
            --timeout-seconds 600
            --query "Command.CommandId" --output text) &&
            aws ssm wait command-executed ... || true &&
            aws ssm get-command-invocation ... --output table &&
            export FINAL_STATUS=... &&
            if [ "$FINAL_STATUS" != "Success" ]; then exit 1; fi

pipelines:
  branches:
    production:
      - step: { name: "Ready to Deploy (PRD)", script: [echo "Deploying..."] }
      - step: { <<: *atomic-deploy, deployment: US-Env }
    staging:
      - step: { name: "Ready to Deploy (STG)", script: [echo "Deploying..."] }
      - step: { <<: *atomic-deploy, deployment: US-Env }
    develop:
      - step: { <<: *atomic-deploy, deployment: US-Env }
```

**핵심:** 파이프라인 YAML에는 배포 로직이 없고, SSM으로 EC2 상주 스크립트를 호출할 뿐이다. 배포 로직 수정은 EC2의 `deploy-be.sh` / `deploy-fe.sh`를 직접 수정한다.

### 3.3 브랜치별 파이프라인 차이

| 브랜치 | 수동 승인 | 스텝 수 | deploy 스크립트 인자 | 대상 환경 |
|--------|----------|---------|---------------------|----------|
| `production` | 필요 (Step 1) | 2 | `production` → `prd` | `/works/hongcafe-global/prd/` |
| `staging` | 필요 (Step 1) | 2 | `staging` → `stg` | `/works/hongcafe-global/stg/` |
| `develop` | 불필요 | 1 | `develop` → `dev` | `/works/hongcafe-global/dev/` |

---

## 4. 배포 스크립트 상세

### 4.1 Backend 배포 (`deploy-be.sh`)

**파일 위치:** EC2 `/works/hongcafe-global/scripts/deploy-be.sh`
**infra 동기화:** `hongcafe/ci-cd/scripts/deploy-be.sh`

**브랜치 → 환경 매핑:**

```bash
case "${BRANCH}" in
    production) ENV="prd" ;;
    staging)    ENV="stg" ;;
    develop)    ENV="dev" ;;
esac
DEPLOY_PATH="/works/hongcafe-global/${ENV}"
```

**실행 흐름:**

```
[1/3] Cloning Repository
  sudo mkdir -p ${DEPLOY_PATH}/releases/be_YYYYMMDDHHMMSS
  sudo chown -R ssm-user:ssm-user ${DEPLOY_PATH}
  git clone -b ${BRANCH} git@bitbucket.org:peoplev_dev/hongcafe_global_backend.git .

[2/3] Installing Dependencies
  composer install --optimize-autoloader --no-interaction

[3/3] Running Tests
  ln -sfn ${DEPLOY_PATH}/config/.env ${RELEASE_DIR}/.env    ← 테스트 전 .env symlink
  ./vendor/bin/phpunit --no-coverage

[성공 시 — Promote]
  sudo ln -sfn ${RELEASE_DIR} ${DEPLOY_PATH}/be              ← Atomic symlink 전환
  sudo chown -R apache:apache ${DEPLOY_PATH}/be/writable/    ← writable 디렉토리 권한
  php spark cache:clear                                       ← 캐시 초기화
  sudo systemctl reload php-fpm                               ← PHP-FPM graceful reload
  ls -1t | tail -n +6 | xargs -r sudo rm -rf                 ← 최대 5개 보관

[실패 시 — Abort]
  sudo rm -rf ${RELEASE_DIR}
  exit 1
```

**SDD 대비 실제 코드 차이점:**
- `.env` symlink: 테스트 전(3단계)에 생성 (테스트에 환경변수 필요)
- `php spark migrate --all`: **미실행** (배포 스크립트에 마이그레이션 단계 없음)
- `chown apache:apache writable/`: CI4 writable 디렉토리 권한 설정 포함

### 4.2 Frontend 배포 (`deploy-fe.sh`)

**파일 위치:** EC2 `/works/hongcafe-global/scripts/deploy-fe.sh`
**infra 동기화:** `hongcafe/ci-cd/scripts/deploy-fe.sh`

**실행 흐름:**

```
[1/4] Cloning Repository
  source /home/ssm-user/.nvm/nvm.sh                          ← nvm 로드
  git clone -b ${BRANCH} git@bitbucket.org:peoplev_dev/hongcafe_global_frontend.git .

[2/4] Installing Dependencies
  npm ci

[3/4] Building
  npm run build

[4/4 성공 시 — Promote]
  sudo ln -sfn ${RELEASE_DIR} ${DEPLOY_PATH}/fe              ← Atomic symlink 전환
  pm2 delete "hongcafe-fe-${ENV}" 2>/dev/null || true         ← 기존 PM2 프로세스 삭제
  pm2 start /works/hongcafe-global/ecosystem.config.js \
    --only "hongcafe-fe-${ENV}"                               ← ecosystem.config.js로 시작
  pm2 save                                                    ← PM2 프로세스 목록 저장
  ls -1dt fe_* | tail -n +6 | xargs -r sudo rm -rf           ← fe_ 접두사만 정리

[실패 시 — Abort]
  sudo rm -rf ${RELEASE_DIR}
  exit 1
```

**PM2 프로세스 관리:**
- 환경별 프로세스명: `hongcafe-fe-prd`, `hongcafe-fe-stg`, `hongcafe-fe-dev`
- `ecosystem.config.js`로 중앙 관리 (포트, cwd, NODE_ENV 설정)
- `pm2 save`로 프로세스 목록 영속화

### 4.3 PM2 ecosystem.config.js

```javascript
// /works/hongcafe-global/ecosystem.config.js
module.exports = {
  apps: [
    { name: 'hongcafe-fe-prd', cwd: '/works/.../prd/fe', env: { PORT: 3000, NODE_ENV: 'production' } },
    { name: 'hongcafe-fe-stg', cwd: '/works/.../stg/fe', env: { PORT: 3001, NODE_ENV: 'production' } },
    { name: 'hongcafe-fe-dev', cwd: '/works/.../dev/fe', env: { PORT: 3002, NODE_ENV: 'development' } },
  ],
};
```

---

## 5. SSM 실행 상세

### 5.1 send-command 구조

```bash
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["bash /works/hongcafe-global/scripts/deploy-be.sh $BITBUCKET_BRANCH"]}' \
  --timeout-seconds 600 \
  --query "Command.CommandId" \
  --output text
```

### 5.2 명령 실행 흐름

```
Bitbucket Pipeline 컨테이너
│
├─① export COMMAND_ID=$(aws ssm send-command ... --output text)
│
├─② aws ssm wait command-executed ... || true
│     └─ 타임아웃 시 || true로 계속 진행
│
├─③ aws ssm get-command-invocation ... --output table
│     └─ Status, 표준 출력, 표준 에러를 파이프라인 로그에 출력
│
└─④ export FINAL_STATUS=$(aws ssm get-command-invocation ... --query "Status" --output text)
      if [ "$FINAL_STATUS" != "Success" ]; then exit 1; fi
```

### 5.3 타임아웃/실패 처리

| 시나리오 | EC2 내부 동작 | Bitbucket 결과 |
|---------|-------------|----------------|
| git clone 실패 | `exit 1` → 릴리즈 디렉토리 남음 | 파이프라인 실패 |
| composer install 실패 | `exit 1` → 릴리즈 디렉토리 남음 | 파이프라인 실패 |
| phpunit 실패 | `rm -rf` 릴리즈 디렉토리 | 파이프라인 실패 |
| npm run build 실패 | `rm -rf` 릴리즈 디렉토리 | 파이프라인 실패 |
| SSM 타임아웃 | EC2 명령 계속 실행 중 | `|| true` 후 재확인 |

---

## 6. 보안

### 6.1 IAM (HC-bitbucket-deploy)

```
IAM User: HC-bitbucket-deploy
연결 정책: BitbucketDeploySSM

허용 권한:
  - ssm:SendCommand
  - ssm:GetCommandInvocation
```

### 6.2 SSH 키 관리

| 항목 | 값 |
|------|-----|
| 키 파일 경로 | `/home/ssm-user/.ssh/id_ed25519` |
| 알고리즘 | Ed25519 |
| 용도 | Bitbucket 리포지토리 클론 |
| StrictHostKeyChecking | `no` |

### 6.3 Nginx 서빙 (환경별 TCP 포트)

| 환경 | Nginx conf | PHP-FPM | Next.js |
|------|-----------|---------|---------|
| PRD | `hongcafe-prd.conf` | `127.0.0.1:8080` (TCP) | `:3000` |
| STG | `hongcafe-stg.conf` | `127.0.0.1:8081` (TCP) | `:3001` |
| DEV | `hongcafe-dev.conf` | `127.0.0.1:8082` (TCP) | `:3002` |

---

## 7. 롤백

### 7.1 백엔드 롤백

```bash
# 1. 사용 가능한 이전 릴리즈 확인
ls -1dt /works/hongcafe-global/{env}/releases/be_*

# 2. 이전 릴리즈로 symlink 재지정
sudo ln -sfn /works/hongcafe-global/{env}/releases/be_이전버전 /works/hongcafe-global/{env}/be

# 3. PHP-FPM graceful reload
sudo systemctl reload php-fpm
```

### 7.2 프론트엔드 롤백

```bash
# 1. 이전 릴리즈로 symlink 재지정
sudo ln -sfn /works/hongcafe-global/{env}/releases/fe_이전버전 /works/hongcafe-global/{env}/fe

# 2. PM2 프로세스 재시작
pm2 delete hongcafe-fe-{env} 2>/dev/null
pm2 start /works/hongcafe-global/ecosystem.config.js --only hongcafe-fe-{env}
pm2 save
```

---

## 8. 타당성 검토

### 8.1 SSM send-command + 외부 스크립트 방식의 적합성

**결론: 적합.**

파이프라인 YAML에 인라인 쉘 대신 EC2 상주 스크립트를 호출하는 방식은 배포 로직 수정 시 파이프라인 재실행 없이 스크립트만 수정하면 되어 운영 유연성이 높다. `set -euo pipefail`로 스크립트 안전성을 확보하고, 브랜치→환경 매핑을 스크립트 내부에서 처리하여 파이프라인 중복을 최소화한다.

### 8.2 Atomic Deploy 패턴의 안정성

**결론: 검증된 패턴.**

`ln -sfn`은 커널 수준의 원자적 연산. 검증 실패 시 즉각 디렉토리 삭제. 릴리즈 5개 보관으로 최대 5단계 롤백 가능.

### 8.3 3환경 단일 EC2의 적합성

**결론: 현 규모에서 적합.**

PHP-FPM Pool과 PM2 프로세스를 환경별로 분리하고, Nginx conf.d에서 도메인별 라우팅. 환경 간 리소스 격리는 프로세스 수준이며, 트래픽 증가 시 환경별 인스턴스 분리가 필요할 수 있다.

---

## 9. 변경 영향 기록

### 9.1 현재 시스템 대비 개선 권고 사항

| 항목 | 변경 내용 | 개선점 | 수행 이유 |
|------|-----------|--------|-----------|
| BE 릴리즈 정리 로직 | `ls -1t` → `ls -1dt be_*` 필터 적용 | FE 릴리즈 의도치 않은 삭제 방지 | BE 정리 명령이 fe_ 디렉토리를 포함할 수 있는 잠재적 버그 |
| FE 서비스 재시작 방식 | `pm2 delete + start` → `pm2 reload` | 배포 시 순간 서비스 다운 방지 | Next.js 배포 중 사용자 접속 오류 가능성 제거 |
| SSH StrictHostKeyChecking | `no` → `accept-new` + known_hosts 등록 | MITM 공격 취약점 해소 | 호스트 키 검증 없이 연결 시 위험 |
| Pipeline 이미지 버전 | `amazon/aws-cli` (latest) → `amazon/aws-cli:2.x.x` | CI 환경 재현성 확보 | latest 변경 시 파이프라인 동작 변경 가능 |
| IAM 인증 방식 | Long-term 액세스 키 → OIDC | 키 노출 위험 제거 | 장기 자격증명 유출 위험, OIDC 단기 자격증명이 모범 사례 |
| DB 마이그레이션 | deploy-be.sh에 미포함 | 배포 시 자동 마이그레이션 | 현재 수동 실행 필요 |

---

## 체크리스트

- [x] 설계 문서 초안 작성
- [x] 아키텍처 다이어그램 포함
- [x] 인터페이스 계약 정의
- [x] 에러 처리 전략 명시
- [x] 보안 고려사항 포함
- [x] 코드 구현 완료
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 검증
- [x] 운영 배포 확인

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 현재 구조 기준 전면 동기화: 3환경(prd/stg/dev) 지원 반영, 외부 스크립트 방식(deploy-be.sh/deploy-fe.sh), 디렉토리 경로(/works/.../\{env\}/), Deployment 레이블(US-Env), PHP-FPM TCP 포트(8080/8081/8082), PM2 ecosystem.config.js, BE migrate 미포함 반영, chown apache:apache writable/ 반영 | jypark |
| 2026-04-15 | 프론트매터 보강, 체크리스트/변경 기록 섹션 추가 | jypark |
