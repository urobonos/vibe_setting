# Claude Code 글로벌 하네스 (Multi-Agent Orchestration v4.0)

`~/.claude/` — Claude Code 의 글로벌 설정 루트이자 멀티 에이전트 오케스트레이션 하네스입니다.
스킬·훅·슬래시 커맨드·산출물 생명주기를 SSOT 기반으로 강제하여, 일관된 분석 → 계획 → 실행 → 검증 워크플로우를 유지합니다.

> 행동 규약의 단일 SSOT 는 [`CLAUDE.md`](./CLAUDE.md) 입니다. 본 README 는 개요 안내용이며, 규칙 충돌 시 항상 `CLAUDE.md` 가 우선합니다.

---

## 디렉토리 구조

| 경로 | 역할 |
|------|------|
| `CLAUDE.md` | **헌법** — 글로벌 지침 (페르소나·Operating Philosophy·Checkpoint·Guardrails·워크플로우). 페르소나는 최상위 always-on 블록으로 인라인 (구 `PERSONA.md` 흡수) |
| `skills/` | 글로벌 스킬 (`{skill}/SKILL.md`) — **6개**. 하니스 전역 always-on 성격만 잔류, 도메인 묶음은 `custom-plugin/` 편입 |
| `custom-plugin/` | 로컬 플러그인 마켓플레이스 (`pv-local`) — `git`·`hongcafe`·`taskflow`·`tools` 4종, 스킬 **22개** + 커맨드 + 에이전트 |
| `commands/` | 글로벌 슬래시 커맨드 — **3개** (`orchestration`·`security-audit`·`진행률갱신`). 워크플로우·git 슬래시는 플러그인 편입 |
| `hooks/` | 라이프사이클 훅 (`*.sh`) — **47개**. Gate·Checkpoint·산출물·worktree 강제 |
| `hooks/lib/` | 훅 공용 라이브러리 (`hook-input.sh`·`path-utils.sh`·`registry-utils.sh`·`product-resolver.sh`·`git-guard.py`) |
| `hooks/tests/` | 가드 훅 회귀 테스트 (`run-guard-tests.sh`) |
| `bin/` | 하니스 유틸 스크립트 — 참조 무결성·스킬 린트·간트 진행률·훅 통계 등 9종 |
| `docs/` | 작업 산출물 통합 루트 (`{product}/tasks·output·specs`, `working/`, `indexing/`, `references/`, `참조문서/`) |
| `mirrors/` | 외부 프로젝트 CLAUDE.md 양방향 미러본 |
| `projects/` | 세션별 메모리·트랜스크립트 (`memory/MEMORY.md` 인덱스 + `BACKLOG.md`) |
| `worktrees/` | 소스 mutation 격리용 git worktree |
| `state/` | 세션 락·REGISTRY·DISPATCH 등 런타임 상태 (gitignore) |
| `settings.json` / `settings.local.json` | 하네스 설정 (후자는 gitignore 개인 override) |

---

## 핵심 개념

- **User Sovereignty + Checkpoint** — 비가역·광범위(3파일+)·트레이드오프·외부 시스템·권한 외 접근 시 즉시 중단하고 사용자 승인을 요청합니다 (`CLAUDE.md` §3).
- **Operating Philosophy 5원칙** — Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution / Concise Reporting. 전 하니스(스킬·훅·커맨드)를 관통하는 북극성입니다.
- **Agent-First 위임** — 탐색·다파일 분석·다단계 구현은 직접 처리하지 않고 Agent 도구(`Explore`/`general-purpose`/`Plan`)·팀 스킬로 위임합니다. 병렬 fan-out 상한 = `min(독립 항목, min(16, cores−2))`.
- **Gate / 자동 위임** — 묶음 승인 키워드(`자동 진행` 등)로 Gate 0→2 점프 후 self-critique 루프로 자동 반복 진행하고, 종료 시 sentinel(`[AUTO-ITERATE-DONE]` / `[AUTO-ITERATE-USER-DECISION]`)을 부착합니다 (`CLAUDE.md` §4.4).
- **worktree 항상 강제** — 모든 소스 mutation 은 worktree 안에서 수행해 원본 작업 트리를 영구 격리합니다 (`worktree-enforce.sh`).
- **git push·master 머지 전면 금지** — 어떤 분기·옵션에서도 Claude 자동 push / master·main 머지·체크아웃 금지, 사용자 직접만 (`branch-enforce.sh` + `git-guard.py`).
- **산출물 생명주기** — 진행 중 작업은 `docs/working/` 단일 통합 문서로 작성하고, `Status: Done` + `## Self-Critique` 동시 충족 시 훅이 `docs/{product}/tasks/` 로 자동 이동합니다.
- **코드 라이프사이클 게이트** — 코드 파일(php/js/ts/py/sql) 변경은 **전** 계획 문서 필수(`gate-enforce.sh` hard 차단), **후** `/taskflow:verify` → `/taskflow:review` 필수 체인.

---

## 워크플로우 — 두 축

### 축 1. 대화형 8단계 사이클

```
/taskflow:analyze → /taskflow:feasibility → /taskflow:plan → /taskflow:execute → /taskflow:verify → /taskflow:review → /taskflow:deploy → /taskflow:retro
```

| 단계 | 슬래시 | 하는 일 |
|------|--------|---------|
| 1 | `/taskflow:analyze` | working/ §분석 채움 — Critical~Low 4분류 · 우선순위 권고 · 장기 영향 |
| 2 | `/taskflow:feasibility` | `tools:search-docset` 호출 → §타당성 검토에 공식 근거 인용 ≥ 1건 |
| 3 | `/taskflow:plan` | §계획 채움 + `step-01~nn` 평면 파일 분해 + `Status: Plan Complete` 부착 |
| 4 | `/taskflow:execute` | 구현 + 결정 escalation ladder(권한형 P1~P4 / 정보부족형 I1~I3) |
| 5 | `/taskflow:verify` | e2e 5점 — env / 함수·클래스 정의 / DB 스키마 / 프로덕션 curl / mock |
| 6 | `/taskflow:review` | Self-Critique 10항목 + cold 판정 1회 + `simplify` 보조 |
| 7 | `/taskflow:deploy` | push·머지 **절차 안내만** (Claude 자동 실행 금지) |
| 8 | `/taskflow:retro` | history.md + summary.md 기록 + working-lifecycle 호출 |

- **등급 압축:** S = 분석 → 실행 → 회고 / M = 분석 → 계획 → 실행 → 검증 → 회고 / L = 8단계 전체
- 자연어 키워드 자동 매칭 동일 동작 ("분석해줘" → `/taskflow:analyze`, "검증/e2e" → `/taskflow:verify` …)
- 의견이 갈리면 어느 단계에서나 `/taskflow:debate`(16 Agent) 또는 `/taskflow:suggest`(경량 단일 권고) 삽입

### 축 2. 무인 루프 (생산 ↔ 소비)

문서로 분해된 step 을 사람 개입 없이 굴리는 축입니다. **생산**이 step 을 `ReadyToMerge` 까지 밀어올리고, **소비**가 대기 큐를 리뷰·정착시킵니다.

| 슬래시 | 역할 |
|--------|------|
| `/taskflow:tick` | 1-iteration 러너 — cwd 무관 전체 스캔 → step 1건 claim → 개발 → **cold Agent 코드리뷰 루프(클린까지)** → verify → `Status: ReadyToMerge`. 머지·push 안 함 |
| `/taskflow:tick-loop` | tick 을 **매번 새 프로세스**로 반복 기동 (컨텍스트 누적 0). detach 라 호출 세션 비블로킹 |
| `/taskflow:tick-team` | 병렬 오케스트레이터 — leader 가 워커를 동적 spawn/kill, 각 워커가 `registry_claim`(원자) 으로 step 자율 점유 |
| `/taskflow:watch` | 감시 루프 — 스냅샷 대비 diff 로 **변경분만** 검증, `ReadyToMerge` 는 리뷰 후 머지 사다리(ff-only → 범위 cherry-pick → 개별)로 정착, 지적 시 `Pending` 복귀. 1시간+ 무진행 병목 해소 |
| `/taskflow:control` | 대기 큐 대시보드 (read-only) — `ReadyToMerge` step + `NeedsDecision` task + 완료 게이트 상태 |
| `/taskflow:code` | 분리 루프 1회 — `step-developer` 가 worktree 에서 구현, `cold-reviewer` 가 클린까지 판정. 짠 쪽과 본 쪽 분리가 값 |

### 문서·세션 관리

- `/taskflow:draft` — 원본 파일(기획서/스펙) 참조해 §분석·§계획 생성 + 원본 지문(sha256) 박제 → 이후 원본 변경 감지 (`draft check`)
- `/taskflow:survey` — 다작업 메타분석. `Plan Complete` 여러 건을 가로질러 의존·worktree·파일충돌 기준 동시진행 그룹 + 우선순위 도출
- `/taskflow:load` / `/taskflow:save` — 재개 / 마감 저장 (`save now` = 판정 생략 즉시 이동), `#tag` 배타 claim 포함
- `/taskflow:auto` — 묶음 승인 자동 진행 + 외부 참조 문서 QA 게이트(fail-closed)
- `/taskflow:ps` — 세션 sid 매핑 + REGISTRY/lock orphan 분류·정리 (`cleanup`/`kill` 모드)
- `/taskflow:parallel` — Modifier. `/taskflow:parallel /{인자}` 로 단일 응답 내 Agent spawn 강제 병렬화
- `/taskflow:research` — 질문 분해 → 주제별 Agent 병렬 웹 검색 → 인용 포함 보고서를 `output/research/` 저장

---

## 스킬 카탈로그

글로벌 스킬 **6개** + 플러그인 스킬 **22개**. 자동화 등급 — **A** = 완전 자동(1회 트리거로 끝까지) / **B** = 부분 자동(분석 자동, 변경 적용은 사용자 결정) / **C** = 수동 진입점(단계별 결정).

### 글로벌 (`skills/`)

- **`orchestration`** `A` (`/orchestration`) — 3-Team(Analyze → Plan → Execute) 통합 오케스트레이션. 9-Core + 3-Consultants 페르소나, Effort/Model/Task Sizing 기준, Communication Protocol, Vibe Coding Group. 다단계 구현(M·L)의 기본 진입점
- **`security-audit`** `A` (`/security-audit`) — 7개 도메인(공통 / PHP·CI4 / MySQL / Lambda / CI·CD·공급망 / Docker / 프로세스) 통합 보안 감사. OWASP Top 10·CWE Top 25·ASVS L1 등 14개 프레임워크. 취약점 발견 시 즉시 Checkpoint
- **`task-docs`** `A` — 작업 문서 생명주기 SSOT. working/ 단일 통합 문서 → 완료 시 tasks/ 자동 이동, 표준 템플릿·backlog 메모리 워크플로우 정의
- **`skill-creator`** `C` — 스킬 생성·수정·최적화의 **강제 진입점**. `skills/` 하위 모든 파일 수정은 본 스킬 경유 (`skill-edit-guard.sh` 락 강제)
- **`skill-validator`** `B` — 글로벌 + 프로젝트 로컬 스킬의 경로 정합성·구조 완전성·CLAUDE.md 규칙 정합·스킬 간 미스매치를 4 병렬 에이전트로 검증
- **`aws`** `C` — AWS(Lambda / SQS / SNS / Aurora MySQL / EC2 / RDS Proxy / IAM / 보안그룹). 조회계 즉시, 변경계 사용자 승인

### `custom-plugin/hongcafe` — HongCafe 도메인 12종

- **`hongcafe:api-team`** `A` — API 추가/오류 시 FE+BE+인프라 3-멤버 병렬 spawn 영향분석. `add` = 3-레포 반영 체크리스트, `debug` = 가설 우선순위
- **`hongcafe:dev-team`** `A` — 다레포 개발 팀(BE / 인프라 / 문서 / FE read-only). Lead 라우팅 1~4 spawn, api-team(영향분석) → dev-team(구현) handoff
- **`hongcafe:api-spec-audit`** `A` — API 명세 ↔ IEEE 산출물(SRS/SDD/IDD) 9축 정합성 audit
- **`hongcafe:api-test`** `A·B` — BE API 러너 호출 — smoke(공개 EP 4종) / e2e(자동가입→코인) / scenario(ep.json 다단계)
- **`hongcafe:php8`** `B` — PHP 8.4+ / CI 4.7+ Modular Monolith. 레이어 규칙·DI 강제·9산출물 동반. **e2e 5점 검증 SSOT**
- **`hongcafe:mysql8`** `B` — MySQL 8.x 쿼리·최적화·스키마 설계. ANSI 우선, EXPLAIN 필수, 인덱스 변경 승인
- **`hongcafe:query-tuning`** `B` — 이미 느린 쿼리의 실서버 진단·재작성·폐기 판단. 측정 우선, 인덱스 미적용 원인, ESR 복합 인덱스 설계, 안티패턴 카탈로그
- **`hongcafe:sns-oauth`** `A·B` — SNS OAuth(kakao/naver/google/apple) 4-provider 매트릭스 SSOT. add / verify / debug
- **`hongcafe:prod-debug`** `C` — 서버 우선 디버그 → 로컬 반영. connect / verify / sync, prd 는 최후 수단
- **`hongcafe:debug-skill`** `B` — 단일 레포 디버깅 표준 7단계 + 영역별 P0~P2 의심 매트릭스
- **`hongcafe:hongcafe-db-migration`** `C` — 소스 DB(NCP) → prd Aurora(US/JP) 이관 (접속판별 → dry-run → 적재 → PII위생 → 롤백)
- **`hongcafe:mirror-be-claude`** `A·C` — be CLAUDE.md ↔ 글로벌 미러 + api-docs 3-way 정합. verify / sync-from-be / sync-from-global
- **`hongcafe:global-context`** (internal) — 다국가 서비스 컨텍스트(국가코드·Country Resolver·Feature Flag·i18n·타임존)

### `custom-plugin/taskflow` — 워크플로우 (스킬 1 + 커맨드 24)

- **`taskflow:debate`** `A` — 4 에이전트팀 × 4명 = **16 Agent** 풀-병렬 spawn 토론. 각 팀원 cold context 독립 spawn, Lead 종합. 토론만 수행(구현·커밋 별도)
- 커맨드 24종 = 위 [워크플로우 두 축](#워크플로우--두-축) 참조

### `custom-plugin/tools` — 유틸리티 6종

- **`tools:report-work`** `A` — 일일·주간·월간 업무 리포트. tasks/ 이력을 product별 스캔 → 주제별 그룹화 + 진행률 판정
- **`tools:report-kpi`** `A` — 분기 업적평가(70%). KPI 7영역 산정 + 세부의견 + 인사 제출본
- **`tools:report-competency`** `A` — 월간 역량평가(30%). 9항목 산정 + 직전 확정 대비 Before/After
- **`tools:search-docset`** `B` — Dash docset 오프라인 기술 레퍼런스 검색. **타당성 검토 근거 SSOT**
- **`tools:search-chat`** `B` — 세션 트랜스크립트 정규식 검색
- **`tools:cli-bitbucket`** / **`tools:cli-notion`** `C` — Bitbucket REST / Notion API curl 기반 CLI

### `custom-plugin/git` — git 워크플로우

- **`git:push`** `C` — Conventional Commits(`type(scope): 제목`) 포맷 **SSOT**. 실제 push 는 사용자 직접
- `/git:create` — worktree(wip) → 신규 feature 분기 생성·ff-only 정착
- `/git:merge` — worktree(wip) → 기존 feature 분기 ff-only 머지·정착

### Internal (slash 호출 없음)

- **`simplify`** — 변경 코드의 재사용성·가독성·효율성 리뷰 후 픽스. Claude Code 내장, `/taskflow:review` 보조 호출

> 전체 인벤토리·자동화 등급 카운트·동기화 규칙의 SSOT 는 `docs/references/skill-inventory.md` 입니다 (`CLAUDE.md` §5 에서 외부화).

---

## 에이전트 (`custom-plugin/*/agents/`)

| 에이전트 | 소속 | 역할 |
|----------|------|------|
| `taskflow:cold-reviewer` | taskflow | cold 코드리뷰어 — worktree 변경분을 기능 오류(경계값·예외 흐름·회귀·동시성) 우선 판정. **Edit/Write 도구 부재 = 코드 수정 기계적 차단** |
| `taskflow:step-developer` | taskflow | tick 루프의 step 개발자 — 지정 worktree 안에서 해당 step 구현 + 리뷰 지적 수정. 문서·커밋은 안 함 |
| `tools:git-collector` | tools | 인사평가용 git 커밋 통계 (기간 내 커밋 수·타입·테마) |
| `tools:gantt-collector` | tools | 인사평가용 간트/WBS 달성률 실측 |
| `tools:history-collector` | tools | 인사평가용 history.md 정량 완료 항목 추출 |
| `tools:docs-index-collector` | tools | 인사평가용 `indexing/*.md` 전역 산출물 분류·집계 |

---

## 훅 (47개) — 카테고리별

| 카테고리 | 주요 훅 | 강제 내용 |
|----------|---------|-----------|
| **Gate·승인** | `gate-init` `gate-approve` `gate-enforce` | Gate 0→2 묶음 승인, 코드 변경 전 계획 문서 hard 차단 |
| **자동 위임** | `prompt-echo-confirm` `auto-iterate-reminder` `auto-iterate-stop-guard` | Echo-Back Confirm, self-critique 루프 재진입(5회 한도), sentinel 검사 |
| **git 안전** | `worktree-enforce` `branch-enforce` `dangerous-ops-guard` `git-quality-gate` `phpunit-prd-guard` | worktree 강제, push·master 머지 차단, Co-Authored-By 금지, No Test No Merge |
| **산출물** | `working-lifecycle` `working-register` `working-release` `working-heartbeat` `working-stale-cleanup` `doc-unified-check` `doc-index-maintain` `output-naming-check` `output-report-share-guard` `doc-quality` `author-field-check` | working/ 자동 이동, V1~V8 통합 검증, 인덱스 재생성, 날짜 prefix·7분류 네이밍 |
| **세션** | `session-start` `session-checkpoint` `session-report` `session-completeness-check` `pre-idle-selfcheck` `persona-reminder` | 페르소나 주입, history/summary 기록 강제 |
| **스킬·미러** | `skill-edit-guard` `skill-lint-after-edit` `mirror-claude-md` `mirror-sanity-check` `claude-settings-sync` | skill-creator 경유 강제, CLAUDE.md 양방향 미러 |
| **보안·정책** | `sensitive-file-guard` `audit-no-autofix-guard` `audit-marker-set` `script-request-enforce` `rollback-state-guard` | 민감 파일 접근, audit 자동수정 금지, 실행요청 스크립트화 |
| **기타** | `agent-first-banner` `gantt-ownership-reminder` `decision-record-reminder` `backlog-lifecycle` `php-quality` `hook-health-check` `post-action-tracker` `scripts-cleanup` | Agent-First 배너, 간트 소유권 대조, 결정 기록, backlog 자동 이동 |

회귀 테스트: `hooks/tests/run-guard-tests.sh`

---

## `bin/` 유틸 스크립트

| 스크립트 | 용도 |
|----------|------|
| `audit-references.sh` | 하니스 전체 참조 무결성 검사 (죽은 경로·스킬·훅 링크 탐지, `custom-plugin` 포함) |
| `lint-skills.sh` | 스킬 정적 검증 (풀 검증 전 30초 사전 체크) |
| `gantt-progress.py` | 간트 진행률 실측·갱신 (경량 모드 = 재실측 불요) |
| `aggregate-hook-stats.sh` | 훅 실행 통계 집계 |
| `why-line-coverage.sh` | 룰 Why 문장 커버리지 측정 |
| `tick-loop.sh` | tick 무인 루프 프로세스 러너 |
| `docs-commit.sh` · `mirror-apidocs.sh` · `dev-stack.sh` | 문서 커밋 / api-docs 미러 / 개발 스택 기동 |

---

## 산출물 경로 정책

모든 산출물은 `~/.claude/docs/{product}/` 아래에 생성합니다 (`{product}` = `basename $CWD`, `.claude` → `claude-harness`). 레포 내부 생성은 금지입니다.

```
docs/
├── references/            글로벌 공용 docset·KB (skill-inventory.md 등)
├── 참조문서/               사용자 제공 참조 문서
├── indexing/{product}.md  전역 문서 인덱스 (훅 자동 생성, 직접 편집 금지)
├── working/               진행 중 작업 단일 통합 문서 (YYYYMMDD/) + REGISTRY.md
└── {product}/
    ├── tasks/             개발 작업 프롬프트 (코드 변경 동반) + history.md
    ├── output/{category}/ 코드 변경 없는 결과물 — audit / verification / research / analysis / report / guide / archive
    └── specs/             IEEE 산출물 (SRS / SDD / IDD / SDP / STP / STD)
```

- **`tasks/` vs `output/`** 판단 = "이 프롬프트가 코드를 바꾸는가?" (혼용 = 위반)
- 폴더·파일명 = ISO-8601 `YYYY-MM-DD-` **prefix** (suffix 금지)
- 진행 중 = `working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 단일 파일, `## 분석` · `## 계획` · `## 실행` 3섹션

---

## 참조 범위 전수 조사

`/taskflow:{analyze,plan,execute,verify,review}` 진입 시 3 출처를 전수 확인한 뒤 결과 표를 출력합니다.

1. `docs/참조문서/*` — 사용자 제공 참조 문서
2. `docs/indexing/{product}.md` — 전수 스캔 후 관련 항목만 본문 정독 (토큰 폭발 회피)
3. 현재 레포 레거시 영역

등급 비례: S = ② 만 / M·L = ①②③ 전수. 직전 단계 sweep 은 같은 세션·같은 문서면 재사용합니다.

---

## 참고

- 규칙 변경 이력: `docs/claude-harness/changelog.md` (역소급 면제 시점의 SSOT)
- 스킬 인벤토리: `docs/references/skill-inventory.md`
- 메모리 인덱스: `projects/.../memory/MEMORY.md` + `BACKLOG.md`
- 스킬 수정은 반드시 `skill-creator` 경유 (`skill-edit-guard.sh` 강제)
- 커밋 포맷은 `git:push` 스킬 SSOT — `git push` 는 항상 사용자 직접 실행
