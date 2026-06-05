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

| 스킬 | 설명 | 등급 |
|------|------|------|
| `orchestration` | 3-Team(Analyze → Plan → Execute) 통합 워크플로우 | A |
| `debate` (`/토론`) | 4 에이전트팀 × 4 = 16 Agent 풀-병렬 spawn 토론 (의견 갈림·트레이드오프) | A |
| `dev-team` | HongCafe 다레포 개발 팀 (BE/인프라/문서/FE) — Lead 라우팅 1~4 spawn | A |
| `api-team` | API 추가/디버그 시 FE+BE+인프라 3-멤버 병렬 영향분석 | A |

### 검증·감사

| 스킬 | 설명 | 등급 |
|------|------|------|
| `security-audit` | 7개 도메인 통합 보안 감사 (OWASP/CWE 등 14개 프레임워크) | A |
| `api-spec-audit` | API 명세 ↔ IEEE 산출물(SRS/SDD/IDD) 9축 정합성 audit | A |
| `skill-validator` | 스킬 풀 검증 (frontmatter + 본문 품질, 4 병렬 에이전트) | B |
| `workflow-enforcer` | 3-Team Workflow Gate 강제 (Checkpoint 체크리스트) | C |

### 개발 스택

| 스킬 | 설명 | 등급 |
|------|------|------|
| `php8` | PHP 8.4+ / CI 4.7+ Modular Monolith API | B |
| `mysql8` | MySQL 8.x 쿼리·스키마·인덱스 (EXPLAIN 검증, 인덱스 변경은 승인) | B |
| `aws` | AWS 서비스 (Lambda/SQS/SNS/Aurora/EC2/IAM/보안그룹) | C |
| `sns-oauth` | SNS OAuth(kakao/naver/google/apple) 표준 패턴 (add/verify/debug) | A·B |
| `prod-debug` | prd/stg/dev EC2 직접 접속 → 점검·수정 → 검증 → 로컬 반영 | C |
| `debug-skill` | 다영역 디버깅 (PHP/DB/AWS/보안) | B |

### 산출물·문서·연동

| 스킬 | 설명 | 등급 |
|------|------|------|
| `task-docs` | 작업 문서 생명주기 (working → tasks 자동 이동, 표준 템플릿) | A |
| `report` | 일일·주간·월간 업무 리포트 생성 | A |
| `mirror-be-claude` | be CLAUDE.md ↔ 글로벌 미러본 + api-docs 3-way 동기화 | A·C |
| `git-push` | Conventional Commits + git push 즉시 실행 | C |
| `bitbucket-cli` | Bitbucket Cloud REST API (curl + 토큰) | C |
| `notion-cli` | Notion API curl 기반 CLI (사용자 명시 요청 시에만) | C |
| `skill-creator` | 스킬 생성·수정·최적화 강제 진입점 (skill-edit-guard 강제) | C |

### Internal (slash 호출 없음 — 자동 트리거/의존성용)

| 스킬 | 설명 |
|------|------|
| `docset-ref` | Dash docset 오프라인 기술 레퍼런스 검색 (`/타당성` 자동 호출) |
| `global-context` | HongCafe Global 다국가 서비스 컨텍스트 (프로젝트 한정) |
| `simplify` | 변경 코드 재사용성·가독성·효율성 리뷰 (Claude Code 내장 plugin, `/리뷰` 보조) |

### 한글 워크플로우 슬래시 (thin wrapper)

- **8단계 사이클:** `/분석` · `/타당성` · `/계획` · `/실행` · `/검증` · `/리뷰` · `/배포` · `/회고`
- **결정·조사:** `/토론`(16 Agent) · `/제안`(경량 단일 권고) · `/조사`(웹 Research) · `/병렬`(Agent 강제 병렬화)
- **세션·자동화:** `/자동진행` · `/작업저장` · `/작업로드` · `/working-done` · `/프로세스`
- **worktree 정착:** `/feature-create`(신규 분기) · `/feature-merge`(기존 분기 ff-only)

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
