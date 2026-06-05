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

## 주요 스킬

| 분류 | 스킬 |
|------|------|
| 오케스트레이션 | `orchestration` · `debate` · `dev-team` · `api-team` |
| 검증·감사 | `security-audit` · `api-spec-audit` · `skill-validator` · `workflow-enforcer` |
| 개발 스택 | `php8` · `mysql8` · `aws` · `sns-oauth` · `prod-debug` |
| 산출물·문서 | `task-docs` · `report` · `mirror-be-claude` · `docset-ref` |
| 도구 연동 | `git-push` · `bitbucket-cli` · `notion-cli` · `skill-creator` |

전체 카탈로그와 자동화 등급(A/B/C)은 `CLAUDE.md` §5 "Skill & Slash Inventory" 참조.

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
