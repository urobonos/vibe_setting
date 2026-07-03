# Claude Code 글로벌 하네스 (Multi-Agent Orchestration v4.0)

`~/.claude/` — Claude Code 의 글로벌 설정 루트이자 멀티 에이전트 오케스트레이션 하네스입니다.
스킬·훅·슬래시 커맨드·산출물 생명주기를 SSOT 기반으로 강제하여, 일관된 분석 → 계획 → 실행 → 검증 워크플로우를 유지합니다.

> 행동 규약의 단일 SSOT 는 [`CLAUDE.md`](./CLAUDE.md) 입니다. 본 README 는 개요 안내용이며, 규칙 충돌 시 항상 `CLAUDE.md` 가 우선합니다.

---

## 디렉토리 구조

| 경로 | 역할 |
|------|------|
| `CLAUDE.md` | **헌법** — 모든 프로젝트에 적용되는 글로벌 지침 (Checkpoint·Guardrails·워크플로우·스킬 인벤토리) |
| `skills/` | 글로벌 스킬 정의 (`{skill}/SKILL.md`) — 현재 23개 |
| `commands/` | 슬래시 커맨드 정의 (`{name}.md`) — 현재 25개 |
| `hooks/` | 라이프사이클 훅 (`*.sh`) — 현재 53개. Gate·Checkpoint·산출물 강제 |
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
/분석 → /타당성 → /계획 → /실행 → /검증 → /리뷰 → /배포 → /회고
```

- **S 등급:** `/분석` → `/실행` → `/회고`
- **M 등급:** `/분석` → `/계획` → `/실행` → `/검증` → `/회고`
- **L 등급:** 8단계 전체
- 의견이 갈리면 어느 단계에서나 `/토론`(16 Agent) 또는 `/제안`(경량 단일 권고)을 끼워 호출합니다.

세션 관리: `/작업저장`(마감 저장) · `/작업로드`(재개) · `/working-done`(즉시 정리).

---

## 스킬 카탈로그

스킬 23개(user-invocable 21 + internal 2) + plugin 1. 자동화 등급 — **A** = 완전 자동(1회 트리거로 끝까지) / **B** = 부분 자동(분석 자동, 변경 적용은 사용자 결정) / **C** = 수동 진입점(단계별 결정).

### 오케스트레이션·팀

- **`orchestration`** `A` — 3-Team(Analyze → Plan → Execute) 통합 오케스트레이션. 9-Core + 3-Consultants 페르소나, Effort/Model/Task Sizing 기준, Communication Protocol, Vibe Coding Group을 정의한다. 다단계 구현(M·L 등급)의 기본 진입점.
- **`debate`** `A` (`/토론`) — 질문·트레이드오프·의견 갈림 시 4 에이전트팀(각 4 Agent = 총 16) 풀-병렬 spawn 토론. 각 팀원은 cold context로 독립 spawn돼 자기 관점만 발언하고 Lead가 종합한다. 토론만 수행하며 구현·커밋은 별도 워크플로우로 처리.
- **`dev-team`** `A` — HongCafe Global 다레포 개발 전용 팀(BE / 인프라 / 문서 / FE read-only). Lead가 task를 분석해 필요한 도메인 멤버만 1~4 spawn(api-team이 항상 3 spawn하는 것과 분리). api-team(영향분석) → dev-team(구현) handoff 패턴.
- **`api-team`** `A` — API 추가/오류 시 FE+BE+인프라 3-멤버 병렬 spawn 영향분석. `add` 모드는 3-레포 반영 체크리스트, `debug` 모드는 가설 우선순위. 인프라 멤버는 AWS CLI 실시간 조회(조회계 즉시, 변경계 승인).

### 검증·감사

- **`security-audit`** `A` — 7개 도메인(공통 / PHP·CI4 / MySQL / Lambda / CI·CD·공급망 / Docker / 프로세스) 통합 보안 감사. OWASP Top 10·CWE Top 25·ASVS L1 등 14개 프레임워크 적용. 취약점 발견 시 즉시 Checkpoint 발동.
- **`api-spec-audit`** `A` — API 명세(Routes / api-docs / OpenAPI) ↔ IEEE 산출물(SRS/SDD/IDD) 9축 정합성 audit. EP 수·인증·응답 스키마·환경별 URL·에러 코드·페이지네이션·키 케이스·API 버전을 교차 검증. module / endpoint / full 3모드.
- **`skill-validator`** `B` — 글로벌 + 프로젝트 로컬 스킬의 경로 정합성·구조 완전성·CLAUDE.md 규칙 정합·스킬 간 미스매치를 4 병렬 에이전트로 검증.
- **`workflow-enforcer`** `C` — orchestration 3-Team 승인 규칙 + §3 Checkpoint / §4 Guardrails를 체크리스트로 강제하는 게이트. 사용자 승인 없이 다음 팀으로 진입하는 것을 방지.

### 개발 스택

- **`php8`** `B` — PHP 8.4+ / CI 4.7+ Mono-repo Modular Monolith API. Controller → Service → Repository → Model 레이어, 모듈 간 직접 참조 금지(Interface 통신만), service() DI 강제. 신규 모듈은 9산출물 동반 필수(부분 구현 금지).
- **`mysql8`** `B` — MySQL 8.x 쿼리·최적화·스키마 설계. ANSI SQL 우선, N+1·Full Scan 방지, EXPLAIN FORMAT=TREE 필수. 인덱스 추가/수정은 사용자 승인, 타 DB 이관 고려해 전용 구문 시 ANSI 병기.
- **`aws`** `C` — AWS 서비스(Lambda / SQS / SNS / Aurora MySQL / EC2 / RDS Proxy / IAM / 보안그룹). Lambda 핸들러·IAM 최소권한·Aurora 연결 패턴 정의. 조회계는 즉시, 변경계는 사용자 승인.
- **`sns-oauth`** `A·B` — SNS OAuth(kakao / naver / google / apple) 표준 패턴. 4-provider 매트릭스(식별키·scope·콜백·토큰만료·client_secret)를 SSOT로 보유하고 encrypted payload·이메일 충돌·account-link 흐름을 표준화. add / verify / debug 3모드.
- **`prod-debug`** `C` — prd/stg/dev EC2 직접 접속 → 점검·수정 → 검증 → 로컬 반영 통합 진입점. connect / verify / sync 3모드 + 환경별 매트릭스(prd 최후수단 / stg 검증우선 / dev 일상). CloudTrail + 보조 audit log.
- **`debug-skill`** `B` — 다영역 디버깅(PHP / DB / AWS / 보안) 통합 진입점.

### 산출물·문서·연동

- **`task-docs`** `A` — 작업 문서 생명주기(분석 → 계획 → 결과). working/ 단일 통합 문서로 진행하다 완료 시 tasks/로 자동 이동(hook). history.md / summary.md 기록, 표준 템플릿 강제.
- **`report`** `A` — 일일·주간·월간 업무 리포트 생성. tasks/ 작업 이력을 product별로 스캔해 주제별 그룹화 + 진행률 판정.
- **`mirror-be-claude`** `A·C` — be 프로젝트 CLAUDE.md ↔ 글로벌 미러본 양방향 + api-docs 3-way(글로벌 ↔ be ↔ docs) 정합. verify(검증) / sync-from-be / sync-from-global 3모드.
- **`git-push`** `C` — Conventional Commits(`type(scope): 제목`) 포맷 정의 + 현재 브랜치 git push 즉시 실행. 커밋 메시지 포맷의 SSOT.
- **`skill-creator`** `C` — 스킬 생성·수정·최적화의 강제 진입점. skills/ 하위 모든 파일 수정은 본 스킬 경유(skill-edit-guard.sh가 락으로 강제).

### Internal (slash 호출 없음 — 자동 트리거/의존성용)

- **`global-context`** — HongCafe Global 다국가 서비스 컨텍스트(국가코드·Country Resolver·Feature Flag·i18n·타임존·환경 분리). 프로젝트 한정.
- **`simplify`** — 변경 코드의 재사용성·가독성·효율성 리뷰 후 이슈 픽스. Claude Code 내장 plugin(본체 파일 없음), `/리뷰` 보조 호출.

### 한글 워크플로우 슬래시 (thin wrapper)

8단계 작업 사이클을 슬래시로 명시 진입한다(자연어 키워드 자동 매칭도 동일 동작).

- **8단계 사이클:** `/분석`(진단) → `/타당성`(공식 근거) → `/계획`(step 분해) → `/실행`(구현) → `/검증`(e2e 5점) → `/리뷰`(Self-Critique) → `/배포`(push 안내) → `/회고`(이력 기록)
- **결정·조사:** `/토론`(16 Agent 토론) · `/제안`(경량 단일 권고) · `/조사`(웹 Research) · `/병렬`(Agent spawn 강제 병렬화)
- **세션·자동화:** `/자동진행`(묶음 승인 자동 진행) · `/작업저장`(마감 저장) · `/작업로드`(재개) · `/working-done`(즉시 정리) · `/프로세스`(세션 orphan 정리)
- **worktree 정착:** `/feature-create`(신규 분기) · `/feature-merge`(기존 분기 ff-only 머지)

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
