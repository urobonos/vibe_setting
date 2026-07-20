---
name: dev-team
description: >
  HongCafe Global 다레포 개발 전용 팀 — BE / 인프라 / 문서 / FE(read-only) 4 도메인.
  Lead 라우팅으로 task 분석 후 필요 도메인 멤버만 1~4 spawn (api-team 항상 3 spawn 패턴과 분리).
  자동 트리거 = 명시적 다도메인 키워드만 (단일어 "개발"/"구현" 제외, api-team 우선권 보장).
  슬래시 = `/dev-team` 수동 진입점.
  BE / 인프라 / 문서 멤버 = `general-purpose` subagent (Edit/Write 가능).
  FE 멤버 = `Explore` subagent (mutation 도구 부재 = 기계적 read-only 강제).
  api-team(영향분석) → dev-team(실행) handoff 패턴. 분석과 구현 명확 분리.
triggers:
  - "BE 인프라 같이"
  - "BE 인프라 문서"
  - "FE BE 문서 같이"
  - "FE BE 인프라 문서"
  - "백 인프라 같이"
  - "백 프엔 문서"
  - "풀스택 개발"
  - "다레포 개발"
  - "다레포 구현"
  - "cross-repo 개발"
  - "/dev-team"
version: 1.0.3
user-invocable: true
depends_on: [orchestration, php8, mysql8, aws, security-audit, task-docs, global-context]
conflicts_with: [api-team]
min_claude_md_version: "4.0"
---

# Dev Team Skill

HongCafe Global 다레포 (BE / 인프라 / 문서 / FE) **실 코드 개발 전용** 팀. Lead = Claude 본체, 필요 도메인 멤버만 routing spawn. **api-team(영향분석) 과 명확 분리** — 본 스킬은 분석 단계 종료 후 구현 단계 진입점.

> **[용도 한정]** 실 mutation 동반 개발 작업 전용. 분석·진단·영향 매핑은 `api-team` 또는 단일 도메인 스킬(`php8`/`aws`/`mysql8`) 영역.
> **Why:** 분석 vs 구현 단계 명확 분리 = 단계별 사용자 결정점 확보 + cold context spawn 비용 최적화 + Lead 라우팅으로 필요 멤버만 호출.

> **[실행 주체]** Lead = Claude 본체 (task 분석 → 도메인 라우팅 → 멤버 spawn → 결과 통합). 멤버는 cold context 로 병렬 Agent spawn (opus 모델 고정).
> **Why:** Lead context 와 멤버 context 분리 = Lead 가설 오염 차단 + 멤버 독립 검증.

---

## 1. 호출 방식

### 1.1 자동 트리거

frontmatter `triggers` 매칭 시 호출. **단일어("개발"/"구현"/"코드 작성") 제외** — 일상 단일 도메인 작업 자동 spawn 폭증 차단.

**트리거 예시 (호출됨):**
- "BE 와 인프라 같이 작업해줘 — 신규 SQS 메시지 처리"
- "풀스택 개발 — 프엔 / 백 / 문서 같이 갱신"
- "다레포 개발 시작" / `/dev-team`

**트리거 안 됨 (의도된 차단):**
- "이 BE 코드 구현해줘" → `php8` 단일 도메인
- "Lambda 함수 추가" → `aws` 단일 도메인
- "API 추가 영향 점검" → `api-team` (분석 영역)
- "엔드포인트 디버그" → `api-team`

### 1.2 슬래시

```
/dev-team
```

수동 진입점 — 본 슬래시 자체가 명시 호출 신호.

### 1.3 api-team 와 handoff 패턴

| 단계 | 스킬 | 산출물 |
|------|------|--------|
| 1. 영향 분석 | `api-team` (add / debug 모드) | 3-레포 체크리스트 / 가설 우선순위 |
| 2. 구현 결정 | 사용자 명시 승인 | 어느 도메인 어떤 변경 |
| 3. **실 구현** | **`dev-team` (본 스킬)** | **commit / PR / 문서 갱신** |

한 작업 흐름에서 둘 다 호출되는 게 정상. 동시 호출은 비대상 (api-team 종료 후 dev-team 진입).

---

## 2. 멤버 구성 (4 도메인)

| 도메인 | 경로 | 권한 | subagent type | 의존 스킬 |
|--------|------|------|---------------|----------|
| **BE (PHP/CI4)** | `C:\Works\hongcafe_global_backend` | 읽기·생성·수정·참조 | `general-purpose` | `php8` + `mysql8` + `security-audit` + `global-context` |
| **인프라 (Lambda/EC2/CDK)** | `C:\Works\infra` | 읽기·생성·수정·참조 | `general-purpose` | `aws` + `security-audit` |
| **문서** | `C:\Works\hongcafe_global_docs` | 읽기·생성·수정·참조 | `general-purpose` | `task-docs` |
| **FE (Next.js)** | `C:\Works\hongcafe_global_frontend` | **읽기·참조만** | **`Explore`** | (없음, 기계적 read-only) |

**FE 멤버 강제 메커니즘:** `Explore` subagent type = `All tools except Agent, ExitPlanMode, Edit, Write, NotebookEdit`. mutation 도구 자체가 부재 → 페르소나 디시플린이 아닌 **기계적 강제**.

**인프라 영역 functional exemption:** `C:\Works\infra` 가 git 추적 없어 worktree 운영 불가 → `worktree-enforce.sh` functional exemption #8 (`C:/Works/infra/*`) 추가. 본 스킬 도입 시 동반 갱신.

---

## 3. Lead 라우팅 정책

Lead = Claude 본체가 task 분석 후 필요 도메인 멤버만 spawn (1~4명).

### 3.1 라우팅 판정 기준

| Task 특성 | spawn 도메인 |
|----------|-------------|
| 단일 도메인 명백 | 본 스킬 비대상 — 단일 도메인 스킬(`php8`/`aws`) 직접 |
| BE + 인프라 cross-cutting | BE + 인프라 (2) |
| 풀스택 (FE 영향 확인 필요) | BE + 인프라 + FE (3, FE = Explore read-only) |
| 문서 갱신 동반 | + 문서 (3~4) |
| 전 도메인 | 4 멤버 풀스폰 |

**판정 questioning 우선:** "이 task 는 cold context 로 분리 검증할 가치가 있나?" → 예 = spawn / 아니오 = Lead 단독.

### 3.2 worktree 운영 (advisor 권고: primary 1개 단순화)

multi-repo 4 worktree 풀운영 = 머지 4× 마찰. 권고 패턴:
- dev-team 1회 호출 = **primary repo 1개** (task 주 도메인) 으로 worktree 1개
- 보조 도메인 멤버 = primary worktree 안에서 read-only 분석 (다른 repo Read 도구로 참조)
- cross-cutting 명백 시에만 별 worktree 추가 (예외)
- 정착 = primary worktree 1개 사용자 직접 머지 (`/git:create` 또는 `/git:merge`)

---

## 4. 멤버 spawn prompt 템플릿

### 4.1 BE 멤버 (general-purpose)

```
도메인 = PHP/CI4 BE (C:\Works\hongcafe_global_backend, vibe_setting 기반 worktree)
권한 = 읽기·생성·수정·참조 (Edit/Write/MultiEdit 가능, git 작업 사용자 직접)
의존 스킬 = php8 / mysql8 / security-audit / global-context
작업: {Lead 가 주는 BE 영역 task}
산출: {수정 파일 list + commit 메시지 + 검증 결과}
제약:
  - branch-enforce 잔존 룰 준수 (push 자동 X, master/main 자동 머지 X)
  - mutation = worktree 안에서만
  - DB 스키마 변경 = 사용자 승인 후 (mysql8 §"인덱스 추가/수정")
```

### 4.2 인프라 멤버 (general-purpose)

```
도메인 = Lambda / EC2 / CDK (C:\Works\infra, functional exemption #8 매칭)
권한 = 읽기·생성·수정·참조 + AWS CLI (조회계 즉시, 변경계 사용자 승인)
의존 스킬 = aws / security-audit
작업: {Lead 가 주는 인프라 영역 task}
산출: {수정 파일 list + AWS 리소스 변경 안 / 사용자 승인 필요 항목}
제약:
  - AWS 변경계 명령 (deploy / put / delete) = 사용자 명시 승인 후
  - Lambda Python 런타임 버전 = 사용자 확인 (aws §"Lambda")
```

### 4.3 문서 멤버 (general-purpose)

```
도메인 = 문서 (C:\Works\hongcafe_global_docs)
권한 = 읽기·생성·수정·참조
의존 스킬 = task-docs
작업: {Lead 가 주는 문서 갱신 task — 산출물 / 가이드 / README 등}
산출: {수정 파일 list + 양식 정합 확인}
제약:
  - 산출물 경로 정합 (CLAUDE.md §File Paths 7 카테고리)
  - 날짜 prefix 필수 (YYYY-MM-DD-)
```

### 4.4 FE 멤버 (Explore — read-only)

```
도메인 = Next.js FE (C:\Works\hongcafe_global_frontend, read-only)
권한 = 읽기·참조만 (Edit/Write/NotebookEdit 도구 부재 = 기계적 강제)
의존 스킬 = (없음)
작업: {Lead 가 주는 FE 영향 점검 task}
산출: {영향받는 컴포넌트 / 호출부 / 타입 정의 list — 분석 결과만}
제약:
  - mutation 불가능 (subagent type 기계적 강제)
  - 발견된 변경 필요 사항은 권고 표 형태로 보고, Lead 가 사용자 승인 받아 별 처리
```

---

## 5. 산출물

| 산출물 | 경로 |
|--------|------|
| 작업 진행 중 통합 문서 | `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{슬러그}.md` |
| 완료 후 tasks/ 자동 이동 | `~/.claude/docs/{product}/tasks/YYYYMMDD/{슬러그}/{yyyy-mm-dd}-{슬러그}-unified.md` |
| FE 영향 권고 (별도 분리 필요 시) | `~/.claude/docs/{product}/output/analysis/{날짜}-{제목}/` |

---

## 6. §3 Checkpoint 우선 적용

- BE / 인프라 / 문서 멤버 mutation = worktree 안 + branch-enforce 잔존 룰 우선 (push / master 머지 금지)
- 인프라 멤버 AWS 변경계 명령 = 사용자 명시 승인 필수
- FE 영향 점검 결과 = 권고만, mutation 별 처리
- 정착 명령 (ff-merge / worktree remove / branch -D) = 사용자 직접 (§4.2 신룰 적용 — .sh 스크립트 + `! bash {path}`)

---

## 7. SSOT

- 본문 정책: CLAUDE.md §4.2 (실행 책임) + §4.3 (worktree 항상 강제) + §5.1 (카탈로그)
- 멤버 spawn = Agent 도구 (Lead 본체 호출)
- handoff 패턴 = api-team (분석) → 본 스킬 (구현)
- functional exemption: `worktree-enforce.sh` 본문 (#8 `C:/Works/infra/*` 동반 추가)
- 의존 스킬 정의 본체: `skills/{php8,aws,mysql8,security-audit,task-docs,global-context,orchestration}/SKILL.md`
