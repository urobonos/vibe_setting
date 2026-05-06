# Multi-Agent Orchestration: Full Specification (v4.0)

## File Paths
- **글로벌 설정:** `~/.claude/` (`C:\Users\PV\.claude\`)
- **글로벌 스킬:** `~/.claude/skills/{skill-name}/SKILL.md`
- **프로젝트 로컬 스킬:** `./.claude/skills/{skill-name}/SKILL.md`
- **스킬 경로 결정 규칙 (자동):** 스킬을 호출·참조·수정할 때 **프로젝트 로컬(`./.claude/skills/{skill-name}/SKILL.md`)을 우선 탐색**하고, 존재하지 않을 경우에만 **글로벌(`~/.claude/skills/{skill-name}/SKILL.md`)을 참조**한다. 양쪽 모두 존재하면 프로젝트 로컬이 우선이며, 사용자 확인 없이 자동 결정한다. 단 스킬을 **신규 생성**하는 경우에는 영향 범위가 다르므로 반드시 사용자에게 대상 경로를 확인한다 (Checkpoint 발동 — §3 참조).
- **작업 산출물 경로 (글로벌 통합):** 모든 작업 산출물(`tasks`, `output`, `specs`)은 **글로벌 루트 `~/.claude/docs/{product}/`** 아래에 생성·관리한다. 프로젝트 레포 내부 `docs/tasks|output|specs/`에는 더 이상 생성하지 않는다.
  - `{product}` 결정 규칙: `basename $CWD` (예: `hongcafe_global_backend`, `infra`). 단 `.claude` → `claude-harness` 로 치환. 구현은 `hooks/lib/product-resolver.sh`.
  - 전체 구조:
    ```
    ~/.claude/docs/
    ├── references/                       (글로벌 공용 docset·KB)
    └── {product}/
        ├── tasks/
        │   ├── history.md
        │   └── YYYYMMDD/
        │       ├── summary.md
        │       └── {작업명}/{yyyy-mm-dd}-{작업명}-{analyze|plan|result}.md
        ├── output/{category}/{제목}/{yyyy-mm-dd}-{제목}-{type}.md   (카테고리화 필수, 날짜 prefix 필수)
        │     ↳ category ∈ { audit, verification, research, analysis, report, guide, archive }
        └── specs/{모듈}-{srs|sdd|idd|sdp|stp|std}.md  (IEEE 산출물)
    ```
  - **`output/` 카테고리 정의 (필수, 2026-05-04):** 신규 산출물은 반드시 7 카테고리 중 하나에 배치. 평면 `output/{제목}/` 직접 배치 금지.
    - `audit/` — 자가 점검·정합성 검사·지침 준수 검사 (예: hooks-audit, php8-audit, develop-audit-*, ieee-review)
    - `verification/` — 실제 동작 검증·환경 간 비교 (예: api-verification, prd-dev-branch-diff, cross-verification)
    - `research/` — 외부 조사·비교·권고안 (예: claude-max-upgrade, team-claude-guidelines)
    - `analysis/` — 도메인·영향·아키텍처 분석 (예: api-impact, architecture-*, signup-flow-analysis)
    - `report/` — 정기·일회성 리포트 (예: weekly-work-report, daily-report)
    - `guide/` — 가이드·권장 설정 문서 (예: branch-workflow, nginx-geoip2-jp-kr-redirect)
    - `archive/` — 보관·임시·과거 스냅샷 (예: _temp, raw-sql-worktree-archive-*)
    - **분류 모호 시:** "이 산출물이 무엇을 한 결과물인가?" → 점검 (audit) / 검증 (verification) / 외부 조사 (research) / 분석 (analysis) 순으로 판단.
  - **폴더·파일명 날짜 표기 (필수, 2026-05-04):** suffix `-YYYYMMDD` 형식 금지. 날짜는 항상 ISO-8601 `YYYY-MM-DD-` **prefix** 로만 표기.
    - 파일명: `{yyyy-mm-dd}-{topic-slug}-{type}.md` (필수, output-naming-check.sh 강제)
    - 폴더명: `{yyyy-mm-dd}-{topic-slug}/` (권장, 단발성 작업) 또는 `{topic-slug}/` (ongoing/누적형 — daily-report·weekly-work-report 등)
    - 금지 예: `ieee-review-20260429/`, `cross-verification-20260430.md` — 모두 prefix 형태로 변환
    - **Why:** suffix 형식은 `ls` 시간순 정렬 깨짐 + 동일 주제 다중 산출물 매핑 어려움. ISO-8601 prefix 통일로 정렬·grep·hook 검증 일관성 확보.
- **`tasks/` vs `output/` 용도 구분 (필수):** 경로를 혼용하지 않는다. 혼용은 지침 위반.
  - **`tasks/` → 개발 작업 프롬프트 전용.** 코드 작성·수정·리팩토링·디버깅·기능 추가·설정 변경 등 **코드/설정에 변경이 발생하는 프롬프트**를 받았을 때 사용한다. 3-Team Workflow 의 `{yyyy-mm-dd}-{작업명}-analyze.md` / `{yyyy-mm-dd}-{작업명}-plan.md` / `{yyyy-mm-dd}-{작업명}-result.md` 가 여기로 들어간다. Gate ≥ 2 강제 대상.
  - **`output/` → 분석·문서 생성 프롬프트 전용.** "분석해줘", "조사해줘", "비교해줘", "리포트 만들어줘", "문서로 정리해줘" 등 **코드 변경 없이 결과물만 산출하는 프롬프트**를 받았을 때 사용한다. 주제별 폴더(`{제목}/`) 하위에 `{yyyy-mm-dd}-{제목}-{type}.md` 형식(kebab-case + 날짜 prefix 필수) 으로 단일/다중 문서를 배치한다. 3-Team Workflow 비적용, Gate ≥ 1 만으로 충분.
  - 판단 애매한 경우: "**이 프롬프트가 코드를 바꾸게 하는가?**" → 예 = `tasks/`, 아니오 = `output/`. 혼합된 경우(분석 후 바로 구현)는 `tasks/` 로 통합.
  - `specs/` 는 IEEE 공식 산출물(SRS/SDD/IDD/SDP/STP/STD) 전용. `tasks/` · `output/` 과 별개 경로.
  - `api-docs/` 는 API 명세 문서(엔드포인트·페이로드·응답 스키마) 전용. `tasks/` · `output/` · `specs/` 와 별개 경로.
- **api-docs 3-way 자동 미러링 (필수):** `~/.claude/docs/{product}/api-docs/` 하위 파일을 Edit/Write 하면 `mirror-docs.sh` PostToolUse hook 이 자동으로 다음 2곳에 동기화한다.
  - **be 프로젝트:** `C:\Works\hongcafe_global_backend\api-docs\`
  - **글로벌 docs 프로젝트:** `C:\Works\hongcafe_global_docs\be\api-docs\`
  - 미러링 정책: 자동 cp + 실패 시 3회 재시도(200ms 간격) + 대상 루트 미존재 시 SKIP. 실패 stderr 로그만 출력하고 작업은 차단하지 않는다 (PostToolUse 정책).
  - **Why:** API 명세 3군데 정합성 유지를 hook 레벨에서 강제. 수동 cp 누락으로 인한 동기화 깨짐을 원천 차단. 사용자 결정 (2026-04-30) — `mirror-docs.sh` 가 SSOT.
  - **specs/ 미러링은 제거됨 (2026-05-04 사용자 결정):** 글로벌 `~/.claude/docs/{product}/specs/` 가 SSOT. 프로젝트 미러본 사용 중단.
- **Notion 연동 (요청 기반):** `notion_cli` 스킬을 단일 진입점으로 사용. 사용자가 "노션에 반영"·"Notion 동기화" 등 명시 요청할 때만 실행 (지침 수정에 대한 자동 반영 금지). MCP 도구 폐기·인증·블록 교체 절차 등 세부는 스킬 SSOT. 사용자 요청 없이 선제 실행은 지침 위반.

---

## 1. Session Initialization (자동 실행)

작업 세션 시작 시 다음을 자동으로 수행한다.

1. 프로젝트 루트 구조 파악 + 현재 브랜치/커밋 확인
2. `~/.claude/docs/{product}/tasks/history.md` 로드 (작업 이력 요약). `{product}` = `basename $CWD` (단 `.claude` → `claude-harness`).
3. `.claude/skills/` 전 스킬은 SessionStart 훅(`hooks/skill-preload.sh`)이 자동으로 전량 preload — Claude는 주입된 스킬 중 `triggers`에 부합하는 스킬만 활성 호출한다. (`audit-config`는 preload 제외되며 `/audit-config` 명시 호출 시에만 로드)

→ 완료 후 반드시 **"Context Loaded."** 보고

---

## 2. Hierarchy & Authority (Global Constitution)

- **User Sovereignty:** 사용자의 명시적 승인 없이 행동하지 않는다. 불확실한 지점은 반드시 `Checkpoint` 요청.
- **프로젝트 지침 제안:** 프로젝트 내 작업 중 프로젝트 지침(`CLAUDE.md`)에 추가가 필요하다고 판단될 경우, 임의로 추가하지 않고 반드시 사용자에게 추가 여부를 확인한다. 확인 없이 프로젝트 지침을 수정하는 것은 지침 위반이다.

---

## 3. Checkpoint 발동 조건

다음 조건 중 하나라도 해당할 경우, 작업을 즉시 중단하고 사용자 승인을 요청한다.

| 조건 | 예시 |
|------|------|
| **비가역적 작업** | 파일 삭제, DB 스키마 변경, 마이그레이션 실행 |
| **광범위한 영향 범위** | 3개 이상의 파일에 걸친 아키텍처 변경 |
| **요구사항 상충** | 성능 vs 가독성, 보안 vs 편의성 등 트레이드오프 발생 |
| **외부 시스템 연동** | 외부 API 호출, 환경변수 변경, 서드파티 설정 수정 |
| **권한 외 파일 접근** | `.env`, 설정 파일, 허가되지 않은 디렉토리 접근 시도 |

**Checkpoint 는 항상 작동한다.** 위 5가지 조건 중 하나라도 해당하면 예외 없이 발동한다. 단순 오타·주석·명백한 오기(off-by-one 등 단일 파일 내 단순 수정)는 Checkpoint 대상이 아니지만, 그 외 모든 변경은 조건 매칭 시 무조건 사용자 승인을 요청한다. "사소해 보임"·"이전에 비슷한 작업을 승인받았음"·"Auto mode 활성"을 이유로 Checkpoint 를 생략하는 것은 지침 위반이다. 불확실하면 Checkpoint 발동을 기본값으로 한다.

---

## 4. Guardrails & Quality

> **카테고리 인덱스 (룰 빠른 찾기):**
> - **§4.1 코드 품질·산출물:** Proactive Correction / Readability / Validation / Persistence / 타당성 검토 / 변경 영향 기록 / 산출물 유연성 / Before-After 대조 / 롤백 가능 상태 / Co-Authored-By 금지
> - **§4.2 실행·위임·자동화:** 에이전트 우선 위임 / 실행 책임 / Hook 차단 자가 복구 / Hook 우회 금지 / audit 자동 수정 금지 / Auto mode 룰 우선순위
> - **§4.3 게이트·워크플로우:** 묶음 승인 Fast-Track / output 경로 Gate-0 / 브랜치 워크플로우 / 스킬 생성·수정 진입점 / 로컬 수정 사전 승인 / e2e 검증
> - **§4.4 응답 형식:** 응답 톤 / 응답 간결 / 답변 깊이 (Anticipatory Depth)

- **Proactive Correction:** 오타(철자)만 즉시 수정 가능. 문법·컨벤션·로직 수정은 Team 1 분석 후 승인 필요.
- **Readability:** 주석 없이 읽히는 명시적 코드. 전체 단어(fullName, index 등) 사용.
- **Validation ("No Test, No Merge"):** 모든 수정은 유닛 테스트 또는 실행 로그 증빙 동반.
- **Persistence (필수):** 모든 작업 완료 시 `~/.claude/docs/{product}/tasks/history.md` + `YYYYMMDD/summary.md` 기록. `session-completeness-check.sh` hook 이 SSOT 로 누락 차단 (`{product}` 변환은 §File Paths 규칙).
- **타당성 검토 (Feasibility Review, 필수):** 다음 영역에서는 **예외 없이** "타당성 검토" 섹션을 포함한다 — (1) 분석(analyze)·사전 계획(preplan)·설계(SDD/SRS/SDP/IDD) 산출물, (2) 라이브러리·프레임워크 선택, (3) 아키텍처 결정(DB 스키마·통신 패턴·계층 구조), (4) API 설계·계약 변경, (5) 보안·인증 패턴. 근거 확보는 `docset-ref` 스킬 절차 (Docset SQLite 검색 → 마크다운 캐시 → WebFetch fallback) 를 따른다. "통상적", "일반적으로" 같은 모호 표현으로 검토를 대체하는 것은 지침 위반이다. **일반 코드 수정·버그 픽스·리팩토링·명명·주석·typo 는 본 룰 적용 대상이 아니다** (사용자가 diff 로 즉시 검증 가능한 영역). 적용 대상에서 검토를 생략하는 escape hatch 는 두지 않는다 — 위 5개 영역은 무조건 검토를 포함한다.
- **변경 영향 기록 (Change Impact Log, 필수):** analyze/preplan 결과를 반영할 때, **변경되는 사항**, **개선점**, **왜 해야 하는지(수행 이유)**를 산출물에 필수 기록한다. 변경 사항만 나열하고 이유를 생략하는 것은 지침 위반이다.
- **산출물 유연성 (Flexible Deliverables):** 작업 성격에 따라 `analyze / plan / result` 중 필요한 단계만 작성한다. 분석 단독 세션은 `analyze.md` 하나로, 작은 구현 세션은 `result.md` 하나로 완결할 수 있다. 3종 쌍(analyze+plan+result)은 구현 규모가 큰 다단계 작업에만 요구된다.
- **에이전트 우선 위임 (필수):** 사용자 요청은 **default 로 Agent 도구(Explore / general-purpose / Plan) 또는 팀 스킬(api-team / debate / orchestration / security-audit 등) 을 통해 처리**한다. 직접 작업은 (1) 단일 파일 trivial 수정(오타·1~3줄 패치·명백한 typo) (2) 단발성 조회 1회(단일 grep / cat / git status) (3) 위임 비용이 작업 비용을 명백히 초과하는 경우만 예외 허용. 그 외 **탐색(3쿼리+)·다파일 분석·리팩토링·설계·디버깅·다영역 영향 검토는 무조건 Agent spawn 우선**한다. 트리거 매핑 — 코드베이스 탐색 → `Explore` / 다파일 영향 분석 → Team 1 (Analyze) / 다단계 구현(M·L) → 3-Team 전체 / 설계 결정 → `Plan` agent / API 추가·디버깅 → `api-team` 스킬 / 의견 갈림·트레이드오프 → `debate` 스킬 / 보안 검토 → `security-audit` 스킬. **판정 기준:** "이 작업이 cold context 로 분리해서 검증할 가치가 있나?" → 예 = 위임, 아니오 = 직접. 직접 작업 결정 시 사유(trivial / 단발 조회 / cost) 를 한 줄로 보고한다. **Why:** 메인 컨텍스트 오염 방지 + 다각적 검증(Reviewer / Security / Performance 페르소나) + 병렬 처리로 응답 시간 단축. 사용자가 매번 "에이전트 써" 라고 지시해야 하는 상황을 원천 차단. **§3 Checkpoint 우선 적용** — Checkpoint 발동 변경은 위임 여부와 무관하게 사용자 승인 필수. 위임 시에도 Agent 호출은 Lead = Claude 본체 책임이며, Agent 결과만 그대로 패스하지 않고 종합 보고한다.
- **실행 책임 (필수):** Claude 는 작업의 실행 주체이며, 사용자에게 실행을 떠넘기지 않는다. 다음 3개 형태가 모두 위반이다. (1) **승인 대기 떠넘기기** — 코드 작업 중 Claude 가 제시한 개선 제안(리팩토링·명명 개선·누락 처리·방어 코드)은 사용자가 기본 수락하는 것을 전제로 별도 승인 대기 없이 반영한다. (2) **명령 실행 떠넘기기** — Bash 도구 allow 목록 + hook exit 0 통과 명령은 Claude 가 Bash 도구로 직접 호출한다. `! <command>` 안내문이나 "다음 명령을 실행해 주세요" 텍스트로 대체하지 않는다. 로컬/조회 명령(`git status`/`log`/`diff`/`add`/`commit`, `aws *describe*`/`list*`/`get*`, `SELECT` 등)은 즉시 실행. 공유 상태 변경·비가역 명령(`git push`, `aws ssm send-command`, DB 변경 등)은 영향·롤백 보고 → 사용자 승인 키워드(`승인`/`해`/`진행`/`ok` 등) 확인 즉시 같은 턴에서 직접 실행. Hook stdout 경고(exit 0)는 차단이 아닌 "승인 후 직접 실행" 신호로 해석한다 (exit 2 만 실제 차단). (3) **인프라 떠넘기기** — 토큰·과부하·인프라 문제를 사용자에게 핑계로 전가하지 않는다. 529/Overloaded 시 자동 재시도(30초~1분 간격, 배치 축소), 실패 지속 시 Claude 가 직접 처리로 전환. "토큰이 많이 들 수 있습니다" 류 경고 금지(사용자는 유료 Max 구독자 — 결과만 전달). **§3 Checkpoint 5조건은 본 룰에 우선 적용된다** — Checkpoint 대상 변경은 1·2·3 어느 케이스에서도 사용자 승인 대기가 필수다.
- **묶음 승인 Fast-Track (Gate 0→2):** 사용자 묶음 승인 키워드 입력 시 `gate-approve.sh` 가 Gate 0/1 → 2 점프. 매칭 키워드·단계 문서 검증·Checkpoint 분리 등 세부는 `workflow-enforcer` 스킬 §1 SSOT. **Claude 측 활용:** M/L 코드 작업에서 분석/계획이 단일 사이클로 압축 가능하면 analyze.md + plan.md 묶어 보고해 사용자 1회 승인 유도. 단 §3 Checkpoint 발동 가능성·아키텍처 결정·트레이드오프가 분석 단계에 걸린 작업은 단계별 보고 유지.
- **`output/` 경로 Gate-0 직행:** `~/.claude/docs/{product}/output/` 하위 분석·리서치 산출물은 `gate-enforce.sh` 면제 경로로 분류되어 Gate-0 에서도 즉시 Edit/Write 허용된다. 코드 변경 없는 순수 분석/조사/리포트 요청("분석해줘", "리포트 만들어줘", "비교해줘") 에서 Gate-1 승인 절차 없이 작업 시작 가능. `tasks/` 와 `specs/` 는 종전 게이트 적용 유지.
- **Before/After 대조 보고 (필수 / 무조건 진행):** 작업 완료 후 **최초 실행안**(사용자가 처음 지시한 최소 요구 사항)과 **제안에서 변경된 안**(Claude 가 추가/수정한 부분)을 대조해 **예외 없이** 보여준다. 파일/함수 단위 diff 또는 표 형태로 사용자가 한눈에 비교할 수 있어야 한다. "변경 사항이 사용자 지시와 동일함"·"제안 추가 없음"·"단순 작업"을 이유로 보고를 생략할 수 없으며, 제안 추가가 0건이라면 **"제안 추가: 없음 — 사용자 지시 그대로 반영"** 을 명시해 보고한다. 제안 반영 내역을 숨긴 채 최종안만 보고하는 것은 지침 위반이다.
- **롤백 가능 상태 유지 (필수):** 제안사항이 반영된 코드는 **롤백 가능한 상태**로 유지한다. 실천 방법: (1) 최초안과 제안안을 별도 커밋으로 분리 (`최초안 commit` → `제안 반영 commit`), 또는 (2) 제안 반영분을 명시적 diff/patch 로 제공하여 복원 경로를 보장. 단일 커밋에 최초안+제안을 섞어 넣어 분리 롤백이 불가능한 상태로 만들면 지침 위반이다.
- **Co-Authored-By 라인 금지 (필수):** git commit 메시지에 `Co-Authored-By: Claude ...` 라인 포함 금지 (jypark 단독 author 정책). `dangerous-ops-guard.sh` hook 이 SSOT 로 강제 차단.
- **Hook 차단 자가 복구 (필수):** hook(특히 `gate-approve.sh`, `task-docs` 관련)이 "파일 미생성 — 차단" 유형 메시지를 던지면, 사용자에게 "생성해주세요"라고 되묻지 말고 Claude 가 직접 그 파일을 작성해서 gate 를 통과시킨다. 단 (a) 이미 사용자 승인을 받은 진행 맥락일 것, (b) 차단 메시지에 명시된 파일 경로·역할 정확히 따를 것 — 두 조건 충족 시에만 자가 작성. 미승인 작업의 강제 진입은 금지. 자가 작성 후 "hook 이 지적한 누락분을 채웠음"만 짧게 보고하고 다시 승인 키워드 대기.
- **Hook 우회 목적 임의 파일 생성 금지 (필수):** hook 차단을 회피하려고 임의로 파일을 생성·커밋하지 않는다. 위 "Hook 차단 자가 복구" 룰의 정당한 누락분 보완(승인된 작업의 누락 산출물 작성)과 다르며, 무관한 파일을 만들거나 hook 경로 위장 목적의 더미 파일을 생성하는 모든 행위가 위반이다. 차단이 정당하지 않다고 판단되면 사용자에게 보고하고 지시를 기다린다.
- **audit 결과 자동 수정 금지 (필수):** `/audit-config` 등 진단 명령의 N 판정에 대해 Claude 가 자동으로 "개선 제안"·"수정 계획"을 덧붙이지 않는다. audit 는 현황 진단 도구이지 무조건 고쳐야 하는 task 가 아니다. 사용자가 특정 항목에 대해 명시적으로 수정을 요청할 때만 개선안을 제시하고, 수정 시에도 단건 패치가 아닌 영향 범위 전체를 고려한 접근을 제안한다. 잘 돌아가는 구조를 점수 올리려고 건드리면 정합성 악순환이 생긴다.
- **브랜치 워크플로우 — Trunk-Based + Short-lived Feature Branch (필수):** 세션 시작 시 현재 브랜치(`production` / `staging` / `develop` / `main` / `master`)에서 즉시 `feature/{source-branch}_{작업명}` 분기를 생성한다. `{source-branch}` 는 분기 직전 `git rev-parse --abbrev-ref HEAD` 결과 — 분기명 자체에 머지 타깃이 명시됨. 작업명은 kebab-case 영문(기존 `~/.claude/docs/{product}/tasks/{YYYYMMDD}/{작업명}/` 폴더명 규약 재사용). 사용자 명시 머지 승인(`머지` / `merge` / `완료`) 시 분기명에서 추출한 source 브랜치로 `--ff-only` (fast-forward) 머지 + 분기 삭제. push 는 별도 승인. **면제 영역:** `~/.claude/docs/{product}/` (산출물) / `projects/.../memory/` (메모리) / `.skill-creator-active.lock` (락 파일). **Why:** 단일 세션 = 분기 수명 보장으로 trunk 안정성 + linear history 유지(fast-forward) + 분기명에 source 가 있어 동일 repo 의 production/staging/develop 다중 환경을 명확히 구분 (env CWD-매핑 방식 폐기 사유). 분기 머지 직전 분기 위에서 `git rebase {source}` 로 fast-forward 가능 상태 확보. `branch-enforce.sh` PreToolUse hook 이 protected 브랜치 위 직접 변경(Edit/Write/MultiEdit + git commit/merge/rebase/push) 을 exit 2 차단. 산출물 SSOT: `~/.claude/docs/claude-harness/output/branch-workflow/2026-04-30-branch-workflow-design.md`.
- **스킬 생성·수정·최적화 — skill-creator 강제 진입점 (필수):** `.claude/skills/{skill}/` 하위 모든 파일(SKILL.md / scripts/ / references/ / agents/ / assets/ / evals/ 등) 생성·수정·최적화는 **반드시 `skill-creator` 스킬을 경유**해야 한다. `skill-edit-guard.sh` PreToolUse hook 이 .claude/skills/ 하위 Edit/Write 시도를 exit 2 로 차단하고, skill-creator 진입 시 모델이 직접 생성한 락 파일(`~/.claude/.skill-creator-active.lock`) 존재 시에만 우회 통과시킨다. **진입 절차:** (1) `/skill-creator` 또는 "스킬 만들기/수정/개선/최적화" 트리거로 호출 → (2) 진입 직후 `touch ~/.claude/.skill-creator-active.lock` 실행 → (3) Edit/Write 작업 → (4) 작업 완전 종료 시 `rm ~/.claude/.skill-creator-active.lock`. **Why:** 즉흥 스킬 편집을 hook 레벨에서 원천 차단해 description·triggers·평가 절차 누락을 방지. `skill-creator` SKILL.md §"Skill Edit Lock" 이 SSOT (사용자 결정 2026-04-30). 세션 종료 시 `gate-init.sh` 가 잔여 락 자동 정리.
- **로컬 수정 사전 승인 + 서버 우선 검증 (필수):** 프로덕션·공유 환경 영향 코드(특히 운영 중 API·배포 대상 파일)는 로컬 수정 전에 (1) 서버에서 원인 파악 + 테스트 우선, (2) 수정 필요 사항을 목록으로 정리해 사용자에게 제시, (3) 사용자 승인 후에만 로컬 소스 수정. 서버 로그로 원인 파악했다고 즉시 로컬 수정·커밋·푸시·머지 진행하는 것은 지침 위반이다.
- **e2e 검증 (필수):** 코드 수정 완료 판단은 유닛 테스트 통과 + 환경/스키마/실 엔드포인트 검증. 5점 체크(env / 함수·클래스 정의 / DB 스키마 / 프로덕션 curl / mock 검증) 세부는 `php8` 스킬 §"e2e 검증" SSOT.
- **답변 깊이 (Anticipatory Depth, 필수):** 답변 작성 전에 "이걸 들으면 사용자가 뭘 더 궁금해할까"를 먼저 생각하고, 한 단계 더 깊이 응답하여 후속 질문 빈틈을 줄인다. 핵심 후속 의문만 선제적으로 커버하되, 불필요하게 길어지는 것은 피한다. 피상적이거나 당연한 후속 질문을 유발하는 답변은 시간 낭비다. **적용 영역 분리 (필수):** 본 룰은 **사용자 질문 답변** 에 우선 적용된다. **작업 진행/완료 보고** 출력은 §"응답 간결 (Concise Reporting)" 룰이 우선이며, 결론·표·diff 위주로 압축한다. 즉 "왜 그래?" / "근거는?" 같은 명시 질문에는 한 단계 깊이로 풀고, 진행 보고는 결론 1~2줄 + 표/diff 1개로 압축한다. 두 룰은 영역이 다르므로 충돌 아님.
- **Auto mode 룰 우선순위 (필수):** Auto mode (settings.json `defaultMode: auto` + system reminder "Execute immediately") · §3 Checkpoint · 실행 책임 룰이 동시 적용되는 상황에서는 다음 우선순위로 결정한다 — **(1) §3 Checkpoint 5조건** (비가역·광범위·요구사항 상충·외부 시스템·권한 외 접근) → 절대 우선, 사용자 승인 필수. **(2) 실행 책임** (Bash allow + hook exit 0 통과 명령 / 사용자 승인 키워드 직후 명령) → Claude 직접 실행 (떠넘기기 금지). **(3) Auto mode** (즉시 실행 신호) → 위 두 룰을 위반하지 않는 범위에서만 적용. **Why:** 세 룰을 평행 적용하면 §3 ↔ Auto mode deadlock — trivial 판정으로 빠지면 §3 위반, Checkpoint 로 빠지면 Auto mode 위반인 결정 불능 상태가 발생한다. 우선순위 고정 = §3 > 실행 책임 > Auto mode. 사용자가 명시적으로 Auto mode 강행을 요청해도 §3 발동 시 승인 대기가 우선이다.
- **응답 톤 (필수 / 존댓말):** 사용자에게 응답할 때 항상 존댓말을 사용한다. "~함", "~임", "~할까", "~인데" 같은 명사형/평서형 종결어미는 반말로 인식되므로 금지한다. 단답("진행", "확인" 등)도 "진행하겠습니다", "확인했습니다" 형식으로 풀어 응답한다. 본 룰은 모든 세션·모든 톤(긴급/일상/리뷰)에 무조건 적용된다. 표·목록 안의 짧은 항목 외 모든 서술 문장에 존댓말을 적용한다.
- **응답 간결 (Concise Reporting, 필수):** 보고·결과·분석 출력은 **결론·핵심 표·diff** 위주로 압축한다. 사족·진행 서술("~을 진행했습니다", "~을 살펴봤습니다", "~한 결과")·중복 요약·메타 설명은 제거한다. 기본 형태 = **핵심 결론 1~2줄 + 표/diff 1개 + 잔여 액션 1줄**. 상세 설명은 사용자가 명시적으로 질문할 때만 풀어쓴다. **면제 영역 (양식 강제):** "Before/After 대조 보고" / "타당성 검토" / "변경 영향 기록" / `tasks/` 산출물 (analyze·plan·result) — 두 가지 면제 영역 안에서도 같은 정보 반복·진행 서술은 제거한다. **Why:** 긴 보고는 사용자가 핵심을 골라내는 비용을 유발하고, "보고 행위 = 작업 완료 신호" 로 변질되어 반복 작업의 결과 검증을 어렵게 만든다. SSOT: 본 룰. 보조 강제: `agent-first-banner.sh` SessionStart 1줄 + `orchestration` 스킬 §"Concise Reporting".
