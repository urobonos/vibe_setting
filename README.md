# Claude Code 글로벌 하네스 (Multi-Agent Orchestration v4.0)

`~/.claude/` — Claude Code 의 글로벌 설정 루트이자 멀티 에이전트 오케스트레이션 하네스입니다.
스킬·훅·슬래시 커맨드·산출물 생명주기를 SSOT 기반으로 강제하여, 일관된 분석 → 계획 → 실행 → 검증 워크플로우를 유지합니다.

> 행동 규약의 단일 SSOT 는 [`CLAUDE.md`](./CLAUDE.md) 입니다. 본 README 는 개요 안내용이며, 규칙 충돌 시 항상 `CLAUDE.md` 가 우선합니다.

---

## 디렉토리 구조

| 경로 | 역할 |
|------|------|
| `CLAUDE.md` | **헌법** — 모든 프로젝트에 적용되는 글로벌 지침 (Checkpoint·Guardrails·워크플로우·스킬 인벤토리) |
| `skills/` | 글로벌 스킬 정의 (`{skill}/SKILL.md`) — 현재 19개 |
| `commands/` | 슬래시 커맨드 정의 (`{name}.md`) — 현재 6개 (워크플로우·git 슬래시는 `custom-plugin/` 플러그인 편입) |
| `hooks/` | 라이프사이클 훅 (`*.sh`) — 현재 54개. Gate·Checkpoint·산출물 강제 |
| `docs/` | 작업 산출물 통합 루트 (`{product}/tasks·output·specs`, `working/`, `indexing/`, `references/`) |
| `agents/` | 에이전트 정의 |
| `plugins/` | 플러그인 |
| `mirrors/` | 외부 프로젝트 CLAUDE.md 양방향 미러본 |
| `projects/` | 세션별 메모리·트랜스크립트 (`memory/MEMORY.md` 인덱스) |
| `worktrees/` | 소스 mutation 격리용 git worktree |
| `settings.json` / `settings.local.json` | 하네스 설정 (후자는 gitignore 개인 override) |

---

## 핵심 개념

- **User Sovereignty + Checkpoint** — 비가역·광범위·트레이드오프·외부 시스템·권한 외 접근 시 즉시 중단하고 사용자 승인을 요청합니다 (`CLAUDE.md` §3).
- **Agent-First 위임** — 탐색·다파일 분석·다단계 구현은 직접 처리하지 않고 Agent 도구(`Explore`/`general-purpose`/`Plan`)·팀 스킬로 위임합니다.
- **Gate / 자동 위임** — 묶음 승인 키워드(`자동 진행` 등)로 Gate 0→2 점프 후 self-critique 루프로 자동 반복 진행합니다 (`CLAUDE.md` §4.4).
- **worktree 항상 강제** — 모든 소스 mutation 은 worktree 안에서 수행해 원본 작업 트리를 영구 격리합니다.
- **산출물 생명주기** — 진행 중 작업은 `docs/working/` 단일 통합 문서로 작성하고, 완료 시 훅이 `docs/{product}/tasks/` 로 자동 이동합니다.

---

## 단계별 슬래시 워크플로우

작업 사이클을 슬래시 커맨드로 명시 진입합니다 (자연어 키워드 자동 매칭 + 직접 호출 동일 동작).

```
/taskflow:analyze → /taskflow:feasibility → /taskflow:plan → /taskflow:execute → /taskflow:verify → /taskflow:review → /taskflow:deploy → /taskflow:retro
```

- **S 등급:** `/taskflow:analyze` → `/taskflow:execute` → `/taskflow:retro`
- **M 등급:** `/taskflow:analyze` → `/taskflow:plan` → `/taskflow:execute` → `/taskflow:verify` → `/taskflow:retro`
- **L 등급:** 8단계 전체
- 의견이 갈리면 어느 단계에서나 `/taskflow:debate`(16 Agent) 또는 `/taskflow:suggest`(경량 단일 권고)을 끼워 호출합니다.

세션 관리: `/taskflow:save`(마감 저장) · `/taskflow:load`(재개) · `/taskflow:save now`(즉시 정리).

---

## 스킬 카탈로그

글로벌 스킬 6개 + 플러그인(`git`·`taskflow`·`tools`·`hongcafe`) 스킬 21 (HongCafe 도메인 12종은 2026-07-15 `hongcafe` 플러그인 이동). 자동화 등급 — **A** = 완전 자동(1회 트리거로 끝까지) / **B** = 부분 자동(분석 자동, 변경 적용은 사용자 결정) / **C** = 수동 진입점(단계별 결정).

### 오케스트레이션·팀

- **`orchestration`** `A` — 3-Team(Analyze → Plan → Execute) 통합 오케스트레이션. 9-Core + 3-Consultants 페르소나, Effort/Model/Task Sizing 기준, Communication Protocol, Vibe Coding Group을 정의한다. 다단계 구현(M·L 등급)의 기본 진입점.
- **`debate`** `A` (`/taskflow:debate`) — 질문·트레이드오프·의견 갈림 시 4 에이전트팀(각 4 Agent = 총 16) 풀-병렬 spawn 토론. 각 팀원은 cold context로 독립 spawn돼 자기 관점만 발언하고 Lead가 종합한다. 토론만 수행하며 구현·커밋은 별도 워크플로우로 처리.

### 검증·감사

- **`security-audit`** `A` — 7개 도메인(공통 / PHP·CI4 / MySQL / Lambda / CI·CD·공급망 / Docker / 프로세스) 통합 보안 감사. OWASP Top 10·CWE Top 25·ASVS L1 등 14개 프레임워크 적용. 취약점 발견 시 즉시 Checkpoint 발동.
- **`skill-validator`** `B` — 글로벌 + 프로젝트 로컬 스킬의 경로 정합성·구조 완전성·CLAUDE.md 규칙 정합·스킬 간 미스매치를 4 병렬 에이전트로 검증.

### 개발 스택

- **`aws`** `C` — AWS 서비스(Lambda / SQS / SNS / Aurora MySQL / EC2 / RDS Proxy / IAM / 보안그룹). Lambda 핸들러·IAM 최소권한·Aurora 연결 패턴 정의. 조회계는 즉시, 변경계는 사용자 승인.

### HongCafe 도메인 (플러그인 `custom-plugin/hongcafe`, 2026-07-15 이동)

- **`hongcafe:api-team`** `A` (`/hongcafe:api-team`) — API 추가/오류 시 FE+BE+인프라 3-멤버 병렬 spawn 영향분석. `add` 모드는 3-레포 반영 체크리스트, `debug` 모드는 가설 우선순위.
- **`hongcafe:dev-team`** `A` — HongCafe 다레포 개발 전용 팀(BE / 인프라 / 문서 / FE read-only). Lead 라우팅 1~4 spawn, api-team(영향분석) → dev-team(구현) handoff.
- **`hongcafe:api-spec-audit`** `A` (`/hongcafe:api-spec-audit`) — API 명세 ↔ IEEE 산출물(SRS/SDD/IDD) 9축 정합성 audit. module / endpoint / full 3모드.
- **`hongcafe:api-test`** `A·B` — BE API 러너(`tools/runner/runner.py`) 호출 — smoke(공개 EP) / e2e(자동가입→코인).
- **`hongcafe:php8`** `B` — PHP 8.4+ / CI 4.7+ Modular Monolith API. 레이어 규칙·DI 강제·9산출물 동반. e2e 5점 검증 SSOT.
- **`hongcafe:mysql8`** `B` — MySQL 8.x 쿼리·최적화·스키마 설계. ANSI 우선, EXPLAIN 필수, 인덱스 변경 사용자 승인.
- **`hongcafe:sns-oauth`** `A·B` — SNS OAuth(kakao/naver/google/apple) 4-provider 매트릭스 SSOT. add / verify / debug 3모드.
- **`hongcafe:prod-debug`** `C` (`/hongcafe:prod-debug`) — 서버 우선 디버그 → 로컬 반영. connect / verify / sync 3모드, prd 최후 수단.
- **`hongcafe:debug-skill`** `B` — 다영역 디버깅(PHP / DB / AWS / 보안) 통합 진입점.
- **`hongcafe:hongcafe-db-migration`** `C` — 소스 DB(NCP) → prd Aurora(US/JP) 안전 이관 (접속판별→dry-run→적재→PII위생→롤백).
- **`hongcafe:mirror-be-claude`** `A·C` — be CLAUDE.md ↔ 글로벌 미러 + api-docs 3-way 정합. verify / sync-from-be / sync-from-global.
- **`hongcafe:global-context`** (internal) — HongCafe Global 다국가 서비스 컨텍스트(국가코드·Feature Flag·i18n·타임존).

### 산출물·문서·연동

- **`task-docs`** `A` — 작업 문서 생명주기(분석 → 계획 → 결과). working/ 단일 통합 문서로 진행하다 완료 시 tasks/로 자동 이동(hook). history.md / summary.md 기록, 표준 템플릿 강제.
- **`tools:report-work`** `A` (플러그인 · `custom-plugin/tools`) — 일일·주간·월간 업무 리포트 생성. tasks/ 작업 이력을 product별로 스캔해 주제별 그룹화 + 진행률 판정. (인사평가 `tools:report-competency`·`tools:report-kpi` 동거)
- **`git:push`** `C` — Conventional Commits(`type(scope): 제목`) 포맷 정의 + 현재 브랜치 git push 즉시 실행. 커밋 메시지 포맷의 SSOT. (`custom-plugin/git` 플러그인)
- **`skill-creator`** `C` — 스킬 생성·수정·최적화의 강제 진입점. skills/ 하위 모든 파일 수정은 본 스킬 경유(skill-edit-guard.sh가 락으로 강제).

### Internal (slash 호출 없음 — 자동 트리거/의존성용)

- **`simplify`** — 변경 코드의 재사용성·가독성·효율성 리뷰 후 이슈 픽스. Claude Code 내장 plugin(본체 파일 없음), `/taskflow:review` 보조 호출.

### 한글 워크플로우 슬래시 (thin wrapper)

8단계 작업 사이클을 슬래시로 명시 진입한다(자연어 키워드 자동 매칭도 동일 동작).

- **8단계 사이클:** `/taskflow:analyze`(진단) → `/taskflow:feasibility`(공식 근거) → `/taskflow:plan`(step 분해) → `/taskflow:execute`(구현) → `/taskflow:verify`(e2e 5점) → `/taskflow:review`(Self-Critique) → `/taskflow:deploy`(push 안내) → `/taskflow:retro`(이력 기록)
- **결정·조사:** `/taskflow:debate`(16 Agent 토론) · `/taskflow:suggest`(경량 단일 권고) · `/taskflow:research`(웹 Research) · `/taskflow:parallel`(Agent spawn 강제 병렬화)
- **세션·자동화:** `/taskflow:auto`(묶음 승인 자동 진행) · `/taskflow:save`(마감 저장) · `/taskflow:load`(재개) · `/taskflow:save now`(즉시 정리) · `/taskflow:ps`(세션 orphan 정리)
- **worktree 정착:** `/git:create`(신규 분기) · `/git:merge`(기존 분기 ff-only 머지) — `custom-plugin/git` 플러그인

> 전체 인벤토리·자동화 등급 카운트·동기화 규칙의 SSOT 는 `CLAUDE.md` §5 "Skill & Slash Inventory" 입니다.

---

## 산출물 경로 정책

모든 산출물은 `~/.claude/docs/{product}/` 아래에 생성합니다 (`{product}` = `basename $CWD`, `.claude` → `claude-harness`).

```
docs/
├── references/            글로벌 공용 docset·KB
├── indexing/{product}.md  전역 문서 인덱스 (훅 자동 생성, 직접 편집 금지)
├── working/               진행 중 작업 단일 통합 문서
└── {product}/
    ├── tasks/             개발 작업 프롬프트 (코드 변경 동반)
    ├── output/{category}/ 분석·문서 결과물 (audit/verification/research/analysis/report/guide/archive)
    └── specs/             IEEE 산출물 (SRS/SDD/IDD/SDP/STP/STD)
```

---

## 참고

- 규칙 변경 이력: `docs/claude-harness/changelog.md`
- 메모리 인덱스: `projects/.../memory/MEMORY.md`
- 스킬 수정은 반드시 `skill-creator` 경유 (`skill-edit-guard.sh` 강제)
