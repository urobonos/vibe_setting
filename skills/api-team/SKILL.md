---
name: api-team
description: >
  API 추가/오류 시 FE+BE+인프라 3-멤버 병렬 spawn 영향분석 팀.
  자동 트리거 (API 추가/엔드포인트 오류 키워드) + `/api-team` 슬래시 커맨드 호출.
  add 모드 = 3-레포 반영 체크리스트, debug 모드 = 3-레포 가설 우선순위.
  Lead = Claude 본체, 멤버 3명은 cold context 로 병렬 Agent spawn (Opus 4.7 고정).
  인프라 멤버는 폴더 read + AWS CLI 실시간 조회 (조회계 즉시, 변경계 사용자 승인).
triggers:
  - "API 추가" + ("영향" / "반영" / "체크" / "확인" / "점검")
  - "엔드포인트 추가" + ("영향" / "반영")
  - "라우트 추가" + ("영향" / "반영")
  - "엔드포인트" + ("오류" / "에러" / "500" / "안 됨" / "안됨" / "timeout" / "디버그")
  - "API" + ("오류" / "에러" / "500" / "디버그")
  - "풀스택 영향" / "FE BE 인프라" / "프엔 백 인프라"
  - 슬래시 커맨드: "/api-team"
version: 1.0.0
user-invocable: true
depends_on: [orchestration, php8, mysql8, aws, security-audit, global-context, task-docs]
conflicts_with: []
min_claude_md_version: "4.0"
---

# API Team Skill

API 엔드포인트 **추가** 또는 **오류** 발생 시, **프론트엔드 / 백엔드 / 인프라** 3개 레포(폴더)를 동시에 검토해 영향 범위를 매핑하거나 원인을 진단한다.

> **[용도 한정]** 본 스킬은 *풀스택 영향이 의심되는 API 작업* 전용. 단일 레포 작업에는 호출되지 않는다.
> **Why:** 단일 레포 질문에 3-멤버 병렬 spawn 을 띄우면 cold context 비용·토큰만 낭비되고 결론은 단일 멤버 답변과 동일해져 오케스트레이션 가치가 0 이 됨.

> **[실행 주체]** Lead = Claude 본체. 멤버 3명은 Agent 도구로 병렬 spawn (cold context). 모든 멤버는 `model: opus` 고정 (orchestration §1.1).
> **Why:** Lead context 와 멤버 context 가 섞이면 Lead 의 사전 가설이 멤버 결론에 오염되어 독립 검증 효과가 사라지고, model 이 mixed 면 멤버별 추론 깊이가 달라져 가설 우선순위 비교가 무의미해짐.

---

## 1. 호출 방식

### 1.1. 자동 트리거 (우선)

위 frontmatter `triggers` 패턴이 사용자 발화에 매칭되면 즉시 호출. 모호한 경우 Lead 가 한 줄 확인 후 진행.

**트리거 예시 (호출됨):**
- "주문 생성 API 추가했는데 풀스택 영향 체크"
- "/v1/orders POST 엔드포인트가 500 나는데 디버그"
- "결제 라우트 추가 — FE BE 인프라 반영 사항"

**트리거 안 됨 (의도된 차단):**
- "이 함수 뭐 함?" → 단일 BE 질문
- "API 응답 형식 뭐야?" → 단일 BE 조회
- "프론트엔드 코드 봐줘" → 단일 FE 작업

### 1.2. 슬래시 커맨드 (강제 호출)

```
/api-team add {METHOD} {PATH} [요지]
/api-team debug {METHOD} {PATH} [에러 메시지]
```

예: `/api-team add POST /v1/orders` / `/api-team debug GET /v1/orders/{id} 500 internal error`

---

## 2. 모드

### 2.1. add 모드

**입력:** 추가된(또는 추가 예정인) API 명세 — METHOD, PATH, 페이로드/응답 요지
**산출물:** 3-레포 **반영 체크리스트** (현재 상태 + 누락 + 권고)

### 2.2. debug 모드

**입력:** 오류가 난 엔드포인트 — METHOD, PATH, 에러 메시지/스택/HTTP 상태
**산출물:** 3-레포 **의심 영역 + 가설 우선순위** (P0/P1/P2)

---

## 3. 멤버 구성

| 멤버 | 경로 | git | 활용 스킬 | 검토 영역 |
|------|------|-----|----------|----------|
| **FE** | `C:\Works\hongcafe_global_frontend` | ✅ | global-context (i18n) | `app/`, `components/`, `hooks/`, `i18n/`, `.env.local`, `bitbucket-pipelines.yml`, OpenAPI 스펙(`.spectral.yaml`) |
| **BE** | `C:\Works\hongcafe_global_backend` | ✅ | php8, mysql8, security-audit, global-context | `app/Modules/`, `.env`, `.env.example`, `database/`, `api-docs/`, `phpunit.xml.dist`, `bitbucket-pipelines.yml` |
| **INF** | `C:\Works\infra` (폴더, git 없음) | ❌ | aws, security-audit | `hongcafe/`, `lambda/`, `local-stack/`, `.ssm-deploy-cleanup.json` + **AWS CLI 실시간 조회** |

### 3.1. INF 멤버 AWS CLI 정책

- **조회계 (즉시 실행):** `aws *describe-*`, `aws *list-*`, `aws *get-*`, `aws s3 ls`, `aws logs filter-log-events` 등.
- **변경계 (사용자 승인 후 Lead 가 직접 실행):** `aws ssm send-command`, `aws lambda update-*`, `aws iam put-*` 등. INF 멤버는 *권고만* 보고하고 실행은 Lead 가 사용자 승인 후 직접.
- aws 스킬 §AWS-2 직접 실행 룰 적용.

### 3.2. BE 멤버 phpunit 정책

- phpunit 실행 시 `phpunit-prd-guard` hook 자동 적용 — `.env database.default.hostname` 가 prod 패턴이면 차단.
- BE 멤버는 phpunit 실행 *권고만* 하고 실제 실행은 Lead 가 사용자 승인 후 진행.

---

## 4. 작동 흐름

```
사용자 발화 (자동 매칭) 또는 /api-team {add|debug} {METHOD} {PATH}
  ↓
Lead (Claude 본체)
  1. 입력 정규화 — METHOD, PATH, (debug) 에러 메시지 추출
  2. PATH 슬러그 생성 — 예: "POST /v1/orders/{id}" → "post-v1-orders-id"
  3. 산출물 경로 사전 준비 (product 변환):
     source ~/.claude/hooks/lib/product-resolver.sh
     PRODUCT=$(resolve_product "$PWD")   # basename $PWD (단 .claude → claude-harness)
     ~/.claude/docs/$PRODUCT/output/api-impact/
       └─ {YYYY-MM-DD}-{slug}-{add|debug}.md
  4. 3명 병렬 Agent spawn (run_in_background=true)
       ├─ FE  멤버: model=opus, subagent_type=general-purpose
       ├─ BE  멤버: model=opus, subagent_type=general-purpose
       └─ INF 멤버: model=opus, subagent_type=general-purpose
  5. 모든 멤버 완료 대기 (자동 알림)
  6. 결과 종합:
       - 충돌 탐지 (예: BE 라우트 추가 vs FE 호출 부재)
       - 누락 탐지 (예: BE env 추가 vs INF env 미반영)
       - 가설 충돌 시 우선순위 재조정
  7. 산출물 1개 작성 + 사용자 보고
```

---

## 5. 산출물 형식

### 5.1. add 모드 — `{date}-{slug}-add.md`

```markdown
---
title: "{METHOD} {PATH} — 3-레포 반영 체크리스트"
type: api-impact-add
date: {YYYY-MM-DD}
endpoint: "{METHOD} {PATH}"
---

# {METHOD} {PATH} — 3-레포 반영 체크리스트

> {요지 1~2 문장}

## 작성 정보
| 항목 | 값 |
| 호출 모드 | add |
| 엔드포인트 | {METHOD} {PATH} |
| 검토자 | FE / BE / INF 3 멤버 병렬 |

## 분석 결과

### 5.1.1. FE 레이어 (Next.js)
| 반영 필요 사항 | 현재 상태 | 누락 | 권고 |
|---------------|----------|------|------|
| 호출 함수 (`hooks/api/use{Resource}.ts`) | 존재 / 부재 | … | … |
| 타입 정의 (`types/api.ts`) | … | … | … |
| 에러 핸들링 / Toast | … | … | … |
| i18n 메시지 키 | … | … | … |

### 5.1.2. BE 레이어 (CodeIgniter 4)
| 반영 필요 사항 | 현재 상태 | 누락 | 권고 |
|---------------|----------|------|------|
| 라우트 (`app/Config/Routes.php` 또는 모듈 라우트) | … | … | … |
| Controller | … | … | … |
| Service | … | … | … |
| Repository / Entity | … | … | … |
| DB 마이그레이션 | … | … | … |
| `.env.example` 신규 키 | … | … | … |
| api-docs OpenAPI 스펙 | … | … | … |
| phpunit 테스트 | … | … | … |

### 5.1.3. 인프라 레이어 (AWS)
| 반영 필요 사항 | 현재 상태 | 누락 | 권고 |
|---------------|----------|------|------|
| Lambda env 변수 | … | … | … |
| Security Group 룰 | … | … | … |
| RDS Proxy 풀링 | … | … | … |
| IAM 정책 | … | … | … |
| SSM 배포 스크립트 | … | … | … |
| CloudWatch 알람 | … | … | … |

## 충돌·누락 종합 (Lead)
- (예) BE 가 `.env.example` 에 `ORDER_QUEUE_URL` 추가 / INF Lambda env 미설정 → **누락 P0**

## 타당성 검토
| 항목 | 근거 출처 |
| (각 권고의 공식 문서·스킬 룰 출처) | … |

## 변경 영향 기록
| 변경 사항 | 개선점 | 수행 이유 |
| … | … | … |

## 체크리스트 (≥30개)
- [ ] FE 호출 함수 존재 확인
- [ ] FE 타입 정의 동기화
- [ ] (중략 — 각 레이어 항목을 체크박스화)

## 변경 기록
| 날짜 | 작성자 | 변경 |
```

### 5.2. debug 모드 — `{date}-{slug}-debug.md`

```markdown
# {METHOD} {PATH} — 3-레포 가설 우선순위

> 에러: "{에러 메시지 요약}"

## 작성 정보
| 항목 | 값 |
| 호출 모드 | debug |
| 엔드포인트 | {METHOD} {PATH} |
| 에러 | {요약} |

## 분석 결과

### 가설 우선순위 표
| 우선순위 | 의심 영역 | 레이어 | 근거 | 검증 방법 |
|---------|----------|-------|------|----------|
| P0 | (예) Lambda env `DB_PASSWORD` 누락 | INF | aws lambda get-function-configuration 결과에 키 없음 | `aws lambda get-function-configuration --function-name X` 재실행 |
| P0 | (예) BE Repository SQL NULL 처리 누락 | BE | `app/Modules/Orders/Repository.php:42` LEFT JOIN 결과 미체크 | phpunit 테스트 + 실제 호출 |
| P1 | (예) FE 토큰 만료 처리 부재 | FE | `hooks/api/useOrders.ts` 401 핸들링 없음 | 토큰 만료 시뮬레이션 |
| P2 | (예) RDS Proxy 커넥션 한계 | INF | CloudWatch 메트릭 임계 근접 | RDSProxy 메트릭 조회 |

## 재현·검증 절차
1. (예) AWS CloudWatch 로그 확인 명령
2. (예) BE 로그 grep 패턴
3. (예) FE Network 탭 확인 항목

## 충돌·누락 종합 (Lead)
- 멤버 간 가설 충돌 시 Lead 판단 근거 명시

## 타당성 검토
| 항목 | 근거 출처 |

## 변경 영향 기록
(debug 단계에서 즉시 변경 없음 — 추가 분석 후 별도 작업으로 분리)

## 체크리스트 (≥30개)
- [ ] CloudWatch 로그 수집 완료
- [ ] BE phpunit 재현 시도
- [ ] (중략)

## 변경 기록
```

---

## 6. 멤버 spawn prompt 템플릿

Lead 는 다음 템플릿을 채워 3개 멤버를 동시 spawn 한다. 모든 멤버는 **read-only 분석** (Edit/Write 사용 금지, Bash 는 INF 멤버의 `aws *describe*/list*/get*` 만).
**Why:** 멤버가 코드를 직접 수정하면 Lead 종합 단계 전에 변경이 발생해 충돌·누락 탐지가 불가능해지고, 3명이 동시에 같은 파일을 건드려 race condition·롤백 불능 상태가 발생함.

### 6.1. FE 멤버 prompt

```
당신은 Next.js 프론트엔드 영향 분석 멤버입니다.

레포: C:\Works\hongcafe_global_frontend
모드: {add | debug}
엔드포인트: {METHOD} {PATH}
{add 모드: 페이로드/응답 요지}
{debug 모드: 에러 메시지/HTTP 상태}

분석 영역 (read-only):
1. app/ — 페이지/라우트 구조에서 해당 API 호출 위치
2. components/ — UI 컴포넌트의 API 의존
3. hooks/api/ — React Query / SWR 등 호출 hook 정의
4. i18n/ — 응답 메시지·에러 메시지 번역 키
5. types/ 또는 schema/ — TypeScript 타입 정의
6. .env.local — 환경변수 참조
7. bitbucket-pipelines.yml — 빌드/배포 영향
8. .spectral.yaml — OpenAPI lint 룰 영향

출력 형식 ({add | debug} 모드별 표):
{add: "반영 필요 사항 / 현재 상태 / 누락 / 권고" 표}
{debug: "의심 영역 / 우선순위 / 근거 / 검증 방법" 표}

제약:
- Edit / Write 도구 사용 금지 (read-only 분석)
- 단정 금지: "X 누락" 이 아닌 "X 미발견 (검색 범위 명시)"
- global-context 스킬 룰 (i18n 키, ISO 3166 alpha-2, DateTimeImmutable) 위반 사항 발견 시 별도 표기

응답 길이: 표 + 간단 주석. 서론·결론 불필요.
```

### 6.2. BE 멤버 prompt

```
당신은 CodeIgniter 4 PHP 백엔드 영향 분석 멤버입니다.

레포: C:\Works\hongcafe_global_backend
모드: {add | debug}
엔드포인트: {METHOD} {PATH}
{add: 페이로드/응답 요지}
{debug: 에러 메시지/스택}

분석 영역 (read-only):
1. app/Modules/{도메인}/ — 라우트/Controller/Service/Repository/Entity
2. app/Config/Routes.php — 글로벌 라우트
3. database/Migrations/ — 스키마 변경 이력
4. .env / .env.example — 환경변수 참조
5. api-docs/ — OpenAPI 스펙
6. phpunit.xml.dist + tests/ — 테스트 커버리지
7. bitbucket-pipelines.yml — 빌드/배포

활용 스킬 룰:
- php8: strict_types 선언, mixed 반환 금지, DI 강제 (new Service() 금지)
- mysql8: SELECT * 금지, N+1 방지, named binding, FORCE INDEX 금지
- security-audit: AuthCookieService SSOT, CSRF Double Submit Cookie, JWT localStorage 금지
- global-context: API 응답 i18n 키, UTC 고정, DateTimeImmutable 전용

출력 형식: {모드별 표}

제약:
- Edit / Write 금지
- phpunit 실행 권고 시 phpunit-prd-guard 적용 (prd DB 직결 차단)
- 단정 금지

응답 길이: 표 + 간단 주석.
```

### 6.3. INF 멤버 prompt

```
당신은 AWS 인프라 영향 분석 멤버입니다.

폴더: C:\Works\infra (git 없음 — 파일 read 만)
모드: {add | debug}
엔드포인트: {METHOD} {PATH}
{debug: 에러 메시지}

분석 영역:
1. 폴더 read (read-only):
   - hongcafe/ — 프로덕션 환경 IaC/스크립트
   - lambda/ — Lambda 함수 코드/설정
   - local-stack/ — 로컬 개발 환경
   - .ssm-deploy-cleanup.json — SSM 배포 자동화 흔적
2. AWS CLI 실시간 조회 (조회계 즉시 실행 가능):
   - aws lambda get-function-configuration
   - aws lambda list-event-source-mappings
   - aws ec2 describe-security-groups
   - aws rds describe-db-proxies / describe-db-proxy-targets
   - aws iam get-role-policy / list-attached-role-policies
   - aws logs filter-log-events (CloudWatch 에러 필터)
   - aws ssm describe-parameters / get-parameter

활용 스킬 룰:
- aws: RDS Proxy 경유 강제, SSH 0.0.0.0/0 금지, 환경변수 시크릿 관리, 하드코딩 금지
- security-audit: IAM 최소 권한, SG 인바운드 최소화

출력 형식: {모드별 표}

제약:
- 변경계 명령 (aws lambda update-*, ssm send-command 등) 절대 실행 금지 — 권고만
  **Why:** INF 멤버는 cold context 라 사용자 승인 없이 prod Lambda env·SSM 을 바꾸면 즉시 운영 장애로 번지고 롤백 경로도 멤버 컨텍스트 종료와 함께 소실됨.
- Edit / Write 금지
- 조회계 명령 실행 결과는 핵심만 발췌 (raw output 그대로 붙이지 말 것)

응답 길이: 표 + 핵심 명령 결과 발췌.
```

---

## 7. Lead 종합 절차 (멤버 결과 합치기)

1. 3개 멤버 응답을 *그대로 concat 하지 않는다*. 충돌·누락 탐지 단계 필수.
2. **충돌 탐지 패턴 예시:**
   - BE 가 `.env.example` 에 새 키 추가 권고 / INF 가 Lambda env 에 해당 키 미발견 → **누락 P0**
   - FE 가 응답 필드 X 사용 / BE 응답에 X 없음 → **계약 불일치 P0**
   - BE phpunit 통과 / INF aws CLI 결과 prod 환경 미반영 → **배포 누락 P1**
3. **가설 우선순위 재조정 (debug 모드):**
   - 멤버별 P0 가 충돌하면 Lead 가 근거 강도 비교 후 단일 P0 선정
   - 충돌하는 가설 모두 표에 보존하고 Lead 판단 근거 명시
4. 산출물 작성 → 사용자 보고 (요약 3~5 줄 + 산출물 경로)

---

## 8. 가드레일

- **모드 자동 판별 실패 시:** add/debug 키워드가 모두 없으면 Lead 가 한 줄 확인 후 진행
- **레포 경로 변경:** SKILL.md frontmatter `triggers` 가 아닌 본 §3 표를 단일 출처(SSOT)로 사용. 경로 이전 시 본 표만 갱신
- **멤버 spawn 실패 (529/Overloaded):** orchestration §빠른 실행 정책 적용 — 30초~1분 자동 재시도, 실패 지속 시 Lead 가 직접 처리로 전환 (본 스킬은 *오케스트레이션 도움 도구* 이지 강제 분리가 아님)
- **CLAUDE.md §3 Checkpoint 5조건 우선:** 본 스킬의 자동 호출도 Checkpoint 5조건 (비가역, 광범위 영향, 트레이드오프, 외부 시스템, 권한 외 접근) 발동 시 사용자 승인 우선
  **Why:** api-team 자동 트리거가 Checkpoint 를 우회하면 사용자 의사 확인 없이 prod 영향 분석·AWS 조회·3-멤버 spawn 이 자동 진행되어 글로벌 헌법(User Sovereignty) 이 무력화됨.

---

## 9. 출력 산출물 위치 (단일)

```
~/.claude/docs/{product}/output/api-impact/
  └─ {YYYY-MM-DD}-{METHOD-slug-PATH-slug}-{add|debug}.md
```

> `{product}` = `basename $CWD` (단 `.claude` → `claude-harness` 예외). 변환 SSOT 는 `hooks/lib/product-resolver.sh` 의 `resolve_product` 함수 — task-docs §File Paths 와 동일 규칙. 다른 cwd (예: `C:\Works\hongcafe_global_backend`) 에서 호출 시 자동으로 해당 product 경로로 산출.

**bash 사용 예:**
```bash
source ~/.claude/hooks/lib/product-resolver.sh
PRODUCT=$(resolve_product "$PWD")
OUTPUT_DIR=~/.claude/docs/$PRODUCT/output/api-impact
```

**파일명 슬러그 규칙:**
- METHOD 소문자: `post`, `get`, `put`, `delete`
- PATH 변환: `/` → `-`, `{}` → 제거, 공백 → `-`
- 예: `POST /v1/orders/{id}/cancel` → `2026-04-29-post-v1-orders-id-cancel-add.md`

산출물 1개에 3-멤버 결과 종합 (분리 파일 X). output-naming-check hook 호환.
