# Work History

## 2026.04.15

### 전체 프로젝트 문서 doc-template 양식 일괄 적용

- YAML 프론트매터 제거 → `## 작성 정보` 테이블 변환
- `## 체크리스트`, `## 변경 기록` 섹션 추가
- task 파일명 `{작업명}-` 접두어 적용 (infra 32건 리네임)
- specs 프론트매터 보강 (문서 ID, 버전, 관련 문서)
- 대상: infra 49건 + BE 67건 + FE 9건 = **총 125건**
- 기준 템플릿: `~/.claude/templates/doc-template.md`

### 지침/스킬 최적화 — frontend-guard 흡수 + Hook 통합 (22→14)

- `frontend-guard` 스킬 삭제 → `sensitive-file-guard.sh` hook에 흡수 (package.json/yarn.lock/pnpm-lock.yaml 차단 추가)
- Hook 통합 5개 그룹 실행 (13개 삭제 → 5개 신규):
  - `dangerous-command-guard` + `checkpoint-guard` → `dangerous-ops-guard.sh`
  - `git-commit-lint` + `single-purpose-commit` + `no-test-no-merge` → `git-quality-gate.sh`
  - `php-syntax-check` + `php-pattern-lint` → `php-quality.sh`
  - `edit-write-flag` + `hardcoded-secrets-lint` + `test-run-flag` → `post-action-tracker.sh`
  - `doc-checklist-guard` + `test-coexistence-check` + `notion-sync-reminder` → `doc-quality.sh`
- `settings.json` hook 등록 갱신 (hook 엔트리 22→16)
- 리스크 분석 결과: 스킬 분리(refs/), 보안 SSOT, 페르소나 외부화, 게이트 이관은 실익 없어 취소

## 2026.04.14

### task-docs 스킬 체크리스트 대폭 확장 + hook 강제 검증 추가

- `task-docs` 스킬 v2.1.0 → v3.0.0 업그레이드: analyze/plan/result 체크리스트 ~20개 → ~80/55/55개로 확장
- SDP/SRS/SDD/IDD specs 템플릿에 검토 체크리스트 신규 추가 (각 ~12~13개, 4카테고리)
- `doc-checklist-guard.sh` PostToolUse hook 신규 생성: 문서 파일 Write/Edit 시 체크리스트 최소 개수 강제 (analyze≥30, plan≥20, result≥20, specs≥8)
- `settings.json`에 hook 등록 완료

### 개발 스킬 Mental Dry-Run 규칙 추가 + session-completeness hook 버그 수정

- `php8`, `mysql8`, `aws` 3개 스킬에 Mental Dry-Run 섹션 추가: 코드 생성/수정 시 메모리 상 작성 → 2회 재검토 → 문제 없을 때만 실제 파일 반영
- `session-completeness-check.sh` hook 버그 수정: `.claude` 레포 면제 로직이 1번 검사(일일 기록)에 미적용 → 면제 선언을 최상단으로 이동하여 전체 검사에 적용

### 에이전트 팀(TeamCreate) → 서브에이전트(Agent) 전환

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 환경변수 제거 → TeamCreate/SendMessage 도구 비활성화
- `teams/` 디렉토리 전체 삭제 (과거 inbox JSON 10개 파일)
- `debate` 스킬 description: "Multi-Agent Team" → "Multi-Agent Subagent" 용어 통일

### docs 디렉토리 task-docs 스킬 표준 구조 정리

- `docs/work-history/` → `docs/tasks/` 이관 (history.md + 날짜별 파일)
- YYYYMMDD.md → YYYYMMDD/summary.md 전환 (6개 날짜)
- 보고용 산출물 `docs/output/` 이동 (claude-max-upgrade, context7-comparison)
- kpi-evaluation analyze.md 파일명 규칙 수정
- CLAUDE.md 참조 경로 수정

## 2026.04.13

### .claude 레포 정리 — 미커밋 변경 커밋 + 작업 이력 보충

- 지난주(4/6~4/12) 미완료 작업 조사: work-history, git log, monitoring reports 교차 확인
- 미커밋 변경사항 커밋: settings 권한 추가, report 템플릿 하이픈 구분자, 04.09 이력 보충, 모니터링 리포트 보정
- 04.10 작업 이력 신규 기록: <PROJECT_BE> 34커밋 (API 검증, CSRF 방어, respondLegacy 전환, SDD 19개)

## 2026.04.10

### <PROJECT_BE> — 전체 API 검증 + CSRF 방어 구현

- 전체 API 컨트롤러 검증 (12개 모듈 병렬 감사): Critical 6건, High 14건, Medium 30건+ 식별 및 수정
- SDD 문서 19개 파일 생성 (api-docs/, ~268개 엔드포인트)
- CSRF Signed Double Submit Cookie 방어 구현 (HMAC-SHA256, CsrfTokenService/Filter)
- respondLegacy → 표준 응답 전환 리팩토링 (Board, Call, Chat 등 10개 모듈)
- (:any) 와일드카드 → 명시적 라우트 전환 (Call, Chat, Member)
- Swagger YAML 17개 생성 + api-docs 경로 통합
- 총 34개 커밋, 테스트 2,269건 통과

## 2026.04.09

### KPI 정량평가 산출 + 주간 업무 리포트 + report 템플릿 수정

- Q1(1.1~3.31) KPI 정량평가 산출: DB설계 25건, 백엔드 75건, AWS 20건 = 총 120건, 소계 70.0/70
- 데이터 소스: 로컬 work-history 4개 프로젝트 + Notion "작업 목록" DB(7건) + 프로젝트 메모리 32파일
- 주간(4.6~4.9) 업무 리포트 생성
- `~/.claude/commands/report.md` 출력 형식 수정: `[글로벌][백엔드]` → `[글로벌]-[백엔드]-` 하이픈 구분자

### 주제별 커밋 정리 및 .gitignore 정비

- `.gitignore` 업데이트 — `docs/references/`(4.85GB docset), `*.token`, `skills.zip`, 캐시 파일 제외
- 10개 주제별 커밋 생성: CLAUDE.md 지침, hooks 12개, 스킬 6개 업데이트+4개 신규, docs/commands, monitoring, tasks/teams, settings
- API 토큰(`.token`) 커밋 방지 — gitignore 추가 후 재커밋

## 2026.04.08

### Claude Max 구독 업그레이드 타당성 보고서 작성

- `docs/output/claude-max-upgrade/justification.md` 생성 — Max 5 → Max 20 전환 근거 보고서
- `stats-cache.json` + `monitoring/reports/` 실측 데이터 기반 사용량 분석
- 30일간 203세션, 35,303메시지, Opus 88.9% 비중 정량 산출
- ROI 분석: 월 $100 추가 대비 10~16시간/월 생산시간 회수 논증

## 2026.04.07

### Hook 하니스 보완 — Analyze→Plan→Execute 순차 강제 완성

- `gate-enforce.sh` — Edit/Write 기준 gate>=1 → gate>=2로 변경 (Plan 승인까지 필수)
- `session-completeness-check.sh` — 경량 세션(gate=0) 예외 처리 추가
- `no-test-no-merge.sh` — 신규 hook, 커밋 시 테스트 실행 이력 검증
- `gate-enforce.sh` — Team 3 Agent spawn 시 worktree 격리 강제
- `gate-approve.sh` — 50자 초과 승인 메시지 리셋 버그 수정
- `notion-sync-check.sh` — Stop hook 차단 로직 보완

## 2026.04.06

### Claude Code 하니스 v3.2 → v4.0 대규모 업그레이드

- CLAUDE.md v4.0 전면 개편 (Session Init, Hierarchy, Checkpoint, Guardrails)
- 스킬 재구성: 3개 삭제, 5개 신규, 6개 업데이트
- Security Audit 체크리스트 7종 추가
- Hooks 12개 신규 + Conventional Commits v1.0.0 전환

### <PROJECT_BE> — Repository 패턴 전면 이관

- 전 모듈 Model→Repository 전환, getModel()/new Model() 29건 DI 전환
- 테스트 390건+ 추가·수정, 실패 테스트 67건 수정
- declare(strict_types=1) 471파일 일괄 적용
- Bitbucket Pipelines + RDS Proxy IAM 인증 hermes_db 확장
