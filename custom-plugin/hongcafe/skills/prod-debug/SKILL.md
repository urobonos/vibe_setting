---
name: prod-debug
description: >
  prd/stg/dev EC2 직접 접속 → 서버 점검·수정 → 검증 통과 → 로컬 반영 절차 통합 진입점.
  aws skill (SSM/SSH) wrapper + e2e 검증 (php8 §e2e) + 환경별 분기 매트릭스.
  3 모드 — `connect` (aws ssm start-session/send-command 접속·명령), `verify` (e2e 5점 + 비즈니스 로직 검증), `sync` (서버 → 로컬 반영, 사용자 명시 승인 필수).
  환경별 매트릭스 (prd 최후 수단 / stg 검증 우선 / dev 일상). CloudTrail audit 자동 + 본 정책 보조 audit log 신설.
  자동 트리거 (서버 디버그·prd 오류·ec2 직접 점검·서버 우선 키워드) + `/prod-debug` 슬래시 커맨드. 호출 주체 = Claude 본체. 산출물 = `output/audit/prod-debug-log/` 단일 마크다운.
triggers:
  - "서버 우선 디버그"
  - "서버에서 먼저 수정"
  - "ec2 직접 점검"
  - "ec2 직접 접속"
  - "prd 오류 점검"
  - "stg 오류 점검"
  - "ssm session"
  - "ssm start-session"
  - "서버 검증 통과"
  - "서버 → 로컬 반영"
  - "/prod-debug"
version: 1.0.0
user-invocable: true
depends_on: [aws, security-audit, php8]
conflicts_with: []
min_claude_md_version: "4.0"
---

# Prod-Debug Skill

prd / stg / dev API 오류 발생 시 **서버 우선 디버그 → 로컬 반영** 절차 통합 진입점. CLAUDE.md §4.3 "서버 우선 디버그 → 로컬 반영 흐름" SSOT 의 실 실행 wrapper.

> **[용도 한정]** 서버 우선 디버그·hotfix·검증 후 로컬 반영 전용. 로컬에서 새 기능 구현·리팩토링은 본 스킬 대상 아님 (`php8` / `api-team` / `/taskflow:execute` 영역).
> **Why:** 서버 수정 후 로컬 미반영 = 다음 정상 배포 시 erasure (배포 사고). 서버 우선 = 즉시 hotfix + 검증 후 안전 반영. CloudTrail audit + 본 정책 보조 audit = AWS 측 + 사용자 측 추적 분리.

> **[실행 주체]** Claude 본체 단독. SSM 변경 명령 / 서버 직접 수정 / 로컬 반영 모두 사용자 명시 승인 후 Claude 직접 실행 (aws skill §"실행 주체" 정합).

---

## 1. 호출 방식

### 1.1. 자동 트리거

frontmatter `triggers` 매칭 시 즉시 호출. 모호한 경우 한 줄 확인 후 진행.

**트리거 예시 (호출됨):**
- "prd 결제 API 가 500 응답인데 EC2 직접 점검해줘"
- "stg 서버에서 먼저 수정하고 검증 통과되면 로컬 반영"
- "SSM start-session 으로 i-12345 접속"

**트리거 안 됨 (의도된 차단):**
- "이 기능 새로 만들어줘" → `php8` / `api-team` / `/taskflow:execute`
- "로컬에서 디버그" → 일반 작업
- "Lambda 함수 작성" → `aws` 스킬

### 1.2. 슬래시 커맨드

```
/prod-debug                           # 진입점 (모드 선택 안내)
/prod-debug connect {env} {instance}  # 접속 모드 — env={prd|stg|dev}, instance=i-XXX
/prod-debug verify {env} {url}        # 검증 모드 — e2e 5점 매핑
/prod-debug sync {env} {paths}        # 로컬 반영 모드 — 검증 통과 후 사용자 명시 승인
```

---

## 2. 3 모드 상세

### 2.1. `connect` — EC2 SSM 접속·명령 실행

**진입 조건:** 사용자 명시 (slash 또는 트리거). IAM 권한 사전 확인 (`aws sts get-caller-identity`).

**자동화 절차 (Claude 본체 책임):**

1. **IAM / 인스턴스 확인 (조회계, 즉시 실행):**
   ```bash
   aws sts get-caller-identity
   aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-XXX"
   ```
2. **대화형 디버그 (start-session):** Claude 가 직접 실행 안 함 (대화형 = 사용자 직접). 사용자에게 명령 안내:
   ```
   ! aws ssm start-session --target i-XXX --region ap-northeast-2
   ```
3. **비대화형 명령 (send-command):** 사용자 명시 승인 후 Claude 직접 실행:
   ```bash
   aws ssm send-command \
     --instance-ids i-XXX \
     --document-name "AWS-RunShellScript" \
     --parameters 'commands=["tail -n 100 /var/log/nginx/error.log","systemctl status php-fpm"]' \
     --region ap-northeast-2
   ```
4. **결과 조회 (조회계, 즉시):**
   ```bash
   aws ssm get-command-invocation --command-id <ID> --instance-id i-XXX
   ```

**진단 순서 (레이어 우선, 2026-06-02~):** 500·전역 오류 진단 시 **라우팅·진입점 레이어를 먼저 확정**한다 — `nginx -T` 또는 진입점 prefix 로 "어느 레이어가 응답했는지" 판별 → **그 다음** app 로그(CI4 / php-fpm / logger). app 로그부터 파면 잘못된 레이어에서 헛돈다.
- **HongCafe 경로 분리:** 공개 `/api/` = BFF(Next.js) ≠ BE. **BE 직접 진입점 = `/__hongcafe_api__/api/`**. 배포 경로 = `/works/hongcafe-global/{env}/be`.
- **근거:** 2026-06-01 prd 디버그에서 공개 `/api/` 전역 500 을 BE 다운으로 오진 → CI4로그·php-fpm·env-flip·logger 4 레이어 헛발질 후 `nginx -T` 로 BFF≠BE 발각 (audit 2026-06-02 "진단 효율" 5/10 핵심 감점). SSOT 메모리: `reference_be-bff-routing-layers`.

**audit log 보조:** Claude 가 본 모드 실행 시 `~/.claude/docs/claude-harness/output/audit/prod-debug-log/{yyyy-mm-dd-HHMM}-{slug}/{yyyy-mm-dd}-{slug}-connect.md` 신설 — 인스턴스 ID / 명령 / 결과 요약 / 사용자 결정 추적.

### 2.2. `verify` — e2e 5점 + 비즈니스 로직 검증

**진입 조건:** 서버 수정 후 검증 단계. `connect` 모드 결과로 발견된 수정 사항이 적용된 상태.

**검증 매트릭스 (php8 §"e2e 검증" SSOT):**

| # | 항목 | 검증 방법 |
|---|------|---------|
| 1 | env | `aws ssm send-command "printenv \| grep -E 'DB_|AWS_'"` (민감값 마스킹) |
| 2 | 함수·클래스 정의 | `aws ssm send-command "grep -rn 'function targetFunc' /var/www/"` |
| 3 | DB 스키마 | `mysql --execute='DESCRIBE target_table'` (read-only) |
| 4 | 프로덕션 curl | `curl -i https://api.{env}.hongcafe.com/endpoint` (단순 200 OK + 비즈니스 로직 정상 응답 본문 검증) |
| 5 | mock 검증 | 로컬 phpunit / postman collection 동일 시나리오 |

**검증 통과 정의 (5점 PASS 명문):**
- (1) curl 200 OK
- (2) 응답 본문 비즈니스 로직 정상 (필드·값 매칭)
- (3) 로그 ERROR/WARN 0건 (수정 시점 이후)
- (4) 회귀 매트릭스 PASS (관련 endpoint 그룹 모두 정상)
- (5) DB 스키마·env 변경 없음 (또는 변경 시 사용자 명시 인지)

**audit log:** `prod-debug-log/.../{slug}-verify.md` — 5 항목별 PASS/FAIL + 회귀 결과.

### 2.3. `sync` — 서버 → 로컬 반영 (사용자 명시 승인 필수)

**진입 조건:** `verify` 5점 모두 PASS + 사용자 명시 승인 (`/taskflow:auto sync` 또는 명시 입력).

**자동화 절차:**

1. **서버 변경 사항 추출 (조회계):**
   - 옵션 A — 서버에 git 설치 시: `aws ssm send-command "git diff --no-color HEAD"` 결과 캡처
   - 옵션 B — git 미설치 시: `scp` / `aws s3 cp` 으로 파일 회수
2. **로컬 적용 (사용자 명시 승인 후):**
   - 옵션 A — diff 본문 = `git apply` 로 로컬 적용
   - 옵션 B — 파일 직접 덮어쓰기 (worktree 생성 후 mutation)
3. **로컬 git commit (사용자 직접 실행 권장):**
   ```bash
   ! git add {paths}
   ! git commit -m "fix({module}): {issue} — prod-debug sync from {env}"
   ```
4. **푸시·머지:** 사용자 직접만 (Claude 자동 push 금지, §4.3 (d) 정합).

**audit log:** `prod-debug-log/.../{slug}-sync.md` — 추출 방식 / 적용 파일 / commit hash / 사용자 승인 시점.

---

## 3. 환경별 분기 매트릭스 (CLAUDE.md §4.3 SSOT)

| 환경 | hotfix 권장 | 검증 강도 | 사용자 승인 |
|------|-----------|---------|------------|
| **prd** | **최후 수단** — stg 검증 후 정상 CI/CD 우선. 본 흐름 = hotfix 필요 시만 | e2e 5점 전체 + 회귀 매트릭스 PASS | 매 단계 명시 |
| **stg** | 서버 우선 검증 가능 | e2e 5점 + 회귀 매트릭스 | connect / verify 자동, sync 명시 |
| **dev** | 일상 작업 가능 | 단위 테스트 + curl 200 | 자동 (사용자 명시 옵션) |

---

## 4. aws skill wrapper 패턴 (의존성 정합)

본 스킬은 `aws` 스킬의 SSM/SSH/CloudTrail 영역 wrapper. depends_on = `[aws, security-audit, php8]`.

| aws skill 영역 | prod-debug 활용 |
|-------------|---------------|
| §"실행 주체" 조회/변경 분리 | connect 모드 = describe-instance/get-command-invocation 즉시 / send-command 사용자 승인 후 직접 |
| Lambda·Aurora·EC2·IAM 정의 | EC2 인스턴스 ID / IAM 권한 (SSM:StartSession / SSM:SendCommand / SSM:GetCommandInvocation 필요) |
| `dangerous-ops-guard.sh` 경고 | send-command 감지 시 stdout Checkpoint 경고 (exit 0) — "승인 후 직접 실행" 신호 |

`security-audit` 의존:
- 서버 직접 수정 = CIS AWS Foundations Benchmark 준수 (Section 3 Logging — CloudTrail 자동 활성화)
- IAM 최소 권한 원칙 (SSM 권한만 부여)

`php8` 의존:
- e2e 5점 매핑 (env / 함수·클래스 / DB 스키마 / curl / mock) — §"e2e 검증" SSOT

---

## 5. §3 Checkpoint 우선 적용

본 스킬은 §3 5조건 매칭 영역 다수 — 사용자 명시 승인 우선:

| 조건 | 본 스킬 매칭 |
|------|---------|
| 비가역적 작업 | SSM send-command **변경계** (서버 명령 실행) / sync (로컬 commit) — 사용자 명시 |
| 광범위 영향 | 다중 인스턴스 send-command — 사용자 명시 |
| 외부 시스템 연동 | aws ssm API 호출 = §3 매칭 — 사용자 명시 (aws skill §"실행 주체" 정합). **조회계 예외는 아래 참조** |
| 권한 외 파일 접근 | 서버 `/etc/`·`.env` 접근 시 사용자 명시 |

**§3 우선 적용 - 모드별 자동화 수준:**
- `connect` 조회계 (describe/get-command-invocation) = 자동
- `connect` **send-command 조회계** (아래 §"조회계 send-command 자동 판정") = 자동
- `connect` 변경계 (send-command) = 사용자 명시 후 Claude 직접
- `verify` curl 200 OK (조회) = 자동
- `verify` write (POST/PUT/DELETE) = 사용자 명시
- `sync` = 100% 사용자 명시

### 조회계 send-command 자동 판정 (2026-07-29~)

무인 `/taskflow:tick` 이 서버 조회로 검증을 완결할 수 있게, `send-command` 를 **조회계/변경계로 기계 판정**한다. 판정 주체는 Claude 가 아니라 `hooks/dangerous-ops-guard.sh` 다 — 산문 룰로 두면 판정자가 자기 자신이라 안전장치가 못 된다 (`grep x y` 와 `grep x y; rm -rf /` 는 같은 명령 형태로 들어온다).

- **조회계 판정 시** `[SSM-READONLY-OK]` 출력 → 사용자 승인 없이 Claude 직접 실행.
- **그 외 전부** 기존 Checkpoint 경고 → 사용자 명시 승인 후 실행. **판정 불가도 여기로 (fail-closed).**
- 화이트리스트·탈락 조건(prd 마커·체이닝·리다이렉트·명령치환)의 **SSOT = `hooks/dangerous-ops-guard.sh` §"SSM send-command"**. 여기 복붙하지 않는다 (drift 방지).
- **인스턴스로 env 를 가르지 않는다** — 2026-07-29 실측상 리전당 SSM 인스턴스가 1대뿐이고(us-east-1 `i-0183f9ab360cc9d80` / ap-northeast-1 `i-00e741e10d528c7e5`) 그 한 대가 prd/dev/stg 를 함께 호스팅한다(env = `/works/hongcafe-global/{env}/be` 경로). 그래서 명령 본문의 prd 마커를 배제하는 방식이다.
- **잔여 위험 (명시):** 하니스 내장 classifier 는 이 hook 과 별개로 동작하므로 조회계라도 내용에 따라 차단될 수 있다. 또한 env 무관 시스템 조회(`systemctl status`·`tail /var/log/nginx/*`)는 prd 마커가 없어 통과하지만 실제로는 공용 인프라를 본다.

---

## 6. 산출물

`~/.claude/docs/claude-harness/output/audit/prod-debug-log/{yyyy-mm-dd-HHMM}-{env}-{slug}/`

| 파일 | 내용 |
|------|------|
| `{yyyy-mm-dd}-{slug}-connect.md` | 인스턴스 / SSM 명령 / 결과 / 사용자 결정 |
| `{yyyy-mm-dd}-{slug}-verify.md` | e2e 5점 PASS/FAIL + 회귀 매트릭스 |
| `{yyyy-mm-dd}-{slug}-sync.md` | 추출 방식 / 적용 파일 / commit hash |

**Why audit log 신설:** CloudTrail = AWS API 호출 자동 audit (인프라 측). 본 audit log = 사용자 결정·로컬 반영 추적 (사용자 측). 양 영역 cross-ref 분리 = SSOT 분기 X.

---

## 7. SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.3 "서버 우선 디버그 → 로컬 반영 흐름" | 정책 SSOT (5 단계 흐름 본문) |
| `~/.claude/skills/aws/SKILL.md` §"실행 주체" | SSM 조회/변경 분리 패턴 |
| `~/.claude/skills/php8/SKILL.md` §"e2e 검증" | verify 모드 5점 매핑 SSOT |
| `~/.claude/skills/security-audit/SKILL.md` | CIS AWS / IAM 최소 권한 |
| `~/.claude/commands/prod-debug.md` | 슬래시 진입점 thin wrapper |

---

## 8. 호출 예

```
[사용자] prd 결제 API 500 응답 → ec2 직접 점검해줘
   ↓
[Claude] 1) connect — aws sts get-caller-identity + ssm describe-instance
        2) 사용자 명시 승인 후 send-command "tail -n 100 /var/log/php-fpm/error.log"
        3) 결과 → 원인 식별 (예: redis 연결 풀 고갈)
        4) 사용자 명시 승인 후 send-command "echo 'maxclients = 200' >> /etc/redis/redis.conf && systemctl restart redis"
        5) verify — curl /api/payment + 회귀 매트릭스 PASS
        6) sync — git diff (서버 → 로컬) → 사용자 명시 후 로컬 commit + 사용자 직접 push
        7) audit log 3 파일 자동 생성
```
