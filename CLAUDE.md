# Multi-Agent Orchestration: Full Specification (v4.0)

## File Paths
- **글로벌 설정:** `~/.claude/` (`C:\Users\PV\.claude\`)
- **글로벌 스킬:** `~/.claude/skills/{skill-name}/SKILL.md`
- **프로젝트 로컬 스킬:** `./.claude/skills/{skill-name}/SKILL.md`
- **스킬 경로 결정 규칙 (자동):** 프로젝트 로컬 우선 탐색 → 없으면 글로벌. 양쪽 존재 시 프로젝트 로컬 우선. 신규 **생성** 시는 §3 Checkpoint 발동 (대상 경로 사용자 확인).
- **작업 산출물 경로 (글로벌 통합):** 모든 산출물(`tasks`, `output`, `specs`)은 **`~/.claude/docs/{product}/`** 아래 생성. 프로젝트 레포 내부에 더 이상 생성하지 않는다.
  - `{product}` = `basename $CWD` (단 `.claude` → `claude-harness`). 구현: `hooks/lib/product-resolver.sh`.
  - 전체 구조:
    ```
    ~/.claude/docs/
    ├── references/                       (글로벌 공용 docset·KB)
    ├── working/                          (진행 중 작업 단일 통합 문서 — product 분리 없음, 글로벌 통합)
    │   └── YYYYMMDD/
    │       └── {yyyy-mm-dd}-{product}-{작업명}.md   (단일 통합: 분석 + 계획 + 실행/결과)
    └── {product}/
        ├── tasks/
        │   ├── history.md
        │   └── YYYYMMDD/
        │       ├── summary.md
        │       └── {작업명}/
        │           ├── {yyyy-mm-dd}-{작업명}-unified.md          (신규 정책 2026-05-12~ : 단일 통합)
        │           └── {yyyy-mm-dd}-{작업명}-{analyze|plan|result}.md  (기존 3종 분리 — 2026-05-12 이전 보존)
        ├── output/{category}/{제목}/{yyyy-mm-dd}-{제목}-{type}.md   (카테고리화 필수, 날짜 prefix 필수)
        │     ↳ category ∈ { audit, verification, research, analysis, report, guide, archive }
        └── specs/{모듈}-{srs|sdd|idd|sdp|stp|std}.md  (IEEE 산출물)
    ```
  - **`output/` 카테고리 (필수):** 신규 산출물은 7 카테고리 중 하나에 배치. 평면 `output/{제목}/` 직접 배치 금지.
    - `audit` — 자가 점검·정합성 검사 / `verification` — 실제 동작 검증 / `research` — 외부 조사·권고안 / `analysis` — 도메인·영향·아키텍처 분석 / `report` — 정기·일회성 리포트 / `guide` — 가이드 / `archive` — 보관·임시·과거 스냅샷.
    - 분류 모호 시: audit → verification → research → analysis 순 판단.
    - **공유용 단일 통합 문서 (필수):** `output/report/.../{share,proposal,sharing}*.md` 패턴 = 작성 정보 박스 (6 메타 — 문서 ID / 버전 / 상태 / 작성자 / 작성일 / 대상 독자) + 필수 12 섹션 ((1) 한 줄 요약 (2) 왜/배경 (3) 무엇 (4) 어떻게 (5) 사용 시나리오 (6) 인터페이스 (7) 데이터 (8) 보안·성능·비용 (9) 일정 (10) 결정·권고·리스크 (11) 성공 지표 (12) 합의/참조). 강제: `hooks/output-report-share-guard.sh` PreToolUse exit 2.
  - **폴더·파일명 날짜 표기 (필수):** suffix `-YYYYMMDD` 금지. 항상 ISO-8601 `YYYY-MM-DD-` **prefix**.
    - 파일명: `{yyyy-mm-dd}-{topic-slug}-{type}.md`. 폴더명: `{yyyy-mm-dd}-{topic-slug}/` (단발성) 또는 `{topic-slug}/` (ongoing/누적형 — `daily-report` / `weekly-work-report` / `monthly-report` 등 화이트리스트).
    - 자동 면제: 부모 폴더 직속 자식이 모두 `YYYY-MM-DD-` prefix + 2건 이상 → 부모 폴더 누적형 자동 간주.
    - 강제: `output-naming-check.sh` SSOT.
- **working/ 단일 통합 문서 (필수, 2026-05-12~):** 진행 중 작업 = `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 단일 통합 파일. `## 분석`·`## 계획`·`## 실행` 3 섹션 통합, 각 섹션은 필수 하위섹션 (타당성 검토 / 변경 영향 기록 / Critical~Low 4분류 / Blueprint / WBS / Self-Critique / 장기 영향 / 재발 방지 / SSOT 일관성) 보유.
  - **자동 이동:** `^Status:\s*Done` (시작 라인) + `## Self-Critique` 섹션 동시 존재 시 `working-lifecycle.sh` PostToolUse hook 가 `tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` 로 이동. 사용자 명시 키워드 (`작업 완료` / `tasks 이동` / `working 정리` / `done`) 도 동일 트리거.
  - **충돌 처리:** 동명 파일 존재 시 `.bak-{timestamp}` 백업 후 덮어쓰기. 3종 분리 (역소급) 와 공존 가능 (파일명 suffix `-unified` 로 구분).
  - **product 식별:** 글로벌 1개 디렉토리 통합, 파일명 prefix `{product}-` 로 식별.
  - **`tasks/` 산출물 정책 + 역소급 면제:** 신규 (≥ 2026-05-12) = `-unified.md` 1개. 기존 3종 (< 2026-05-12) = 그대로 보존. 4개 hook (doc-template-guard / output-naming-check / checklist-count-check / session-completeness-check) 양쪽 패턴 인식.
  - **작성 책임:** `task-docs` 스킬 진입점. `references/unified-template.md` SSOT 골격 prepend 후 의미 채움.
  - SSOT: 본 룰 + `hooks/working-lifecycle.sh` + `skills/task-docs/SKILL.md` + `skills/task-docs/references/unified-template.md`.
- **Active Task Registry (필수, 2026-05-15~):** 다세션 환경 진행 작업 가시화 = `~/.claude/docs/working/REGISTRY.md` 단일 마크다운 표 + `~/.claude/state/sessions/{slug}/{sid}.lock` 세션별 lifecycle 마커. **자동 갱신 hook 4종:** (a) PreToolUse Edit/Write `working/*.md` → `working-register.sh` (entry add + lock create + 동일 slug 다른 sid active 점유 시 stderr 경고). (b) PostToolUse → `working-heartbeat.sh` (last_update + lock mtime touch). (c) Stop → `working-release.sh` (본 세션 active → paused + lock 제거). (d) SessionStart → `working-stale-cleanup.sh` (24h 초과 lock 제거 + REGISTRY status=stale). `working-lifecycle.sh` Done 자동 이동 시 entry 일괄 제거. **충돌 정책:** 강제 차단 X (exit 0 + stderr 경고만) — 사용자 결정 우선. **추적 제외:** `.gitignore` 자동 매칭 (sessions/ + docs/ 패턴). **조회 진입점:** `/작업로드` ① 단계 (REGISTRY 우선 조회 + `[active by other]` / `[paused]` / `[orphan]` 3분류). SSOT: `hooks/lib/registry-utils.sh` + `working-{register,heartbeat,release,stale-cleanup}.sh` + 본 단락.
- **`tasks/` vs `output/` 용도 구분 (필수):** 혼용은 지침 위반.
  - **`tasks/` → 개발 작업 프롬프트 전용.** 코드/설정 변경 발생 시. 진행 중 = working/ 단일 통합 → 완료 시 자동 이동.
  - **`output/` → 분석·문서 생성 프롬프트 전용.** 코드 변경 없는 결과물만 산출 시. Gate ≥ 1 만으로 충분.
  - 판단 애매: "이 프롬프트가 코드를 바꾸게 하는가?" → 예 = `tasks/`, 아니오 = `output/`.
  - `specs/` = IEEE 공식 산출물 (SRS/SDD/IDD/SDP/STP/STD) 전용. `api-docs/` = API 명세 전용. 별개 경로.
- **api-docs 3-way 미러링 (필수, 2026-05-18 재설계):** `mirror-be-claude` 스킬이 단일 명시 진입점. 자동 PostToolUse hook (`mirror-docs.sh`) **폐기** — 정책 ↔ 실 사용 어긋남 (be 가 실 SSOT 인데 글로벌 → 외부 단방향이라 IDE / be cwd 편집 미감지). 산출물 = `output/analysis/2026-05-18-mirror-policy-redesign/`.
  - 동기화 대상: `~/.claude/docs/hongcafe_global_backend/api-docs/` ↔ `C:\Works\hongcafe_global_backend\api-docs\` ↔ `C:\Works\hongcafe_global_docs\be\api-docs\`.
  - 명시 진입: `/mirror-be-claude verify` (3-way 정합 read-only 검증) → 차이 발견 시 `/mirror-be-claude sync-from-be` (be → 글로벌 + docs) 또는 `/mirror-be-claude sync-from-global` (글로벌 → be, §3 매칭).
  - 보조 자동: `mirror-sanity-check.sh` SessionStart hook 가 매 세션 시작 시 mtime 경량 drift 감지 → stderr 경고만 (exit 0, 자동 sync 안 함). 사용자에게 `verify` 명시 호출 유도.
  - **specs/ 미러링 제거됨 (2026-05-04):** 글로벌 `~/.claude/docs/{product}/specs/` 가 SSOT.
  - SSOT: `skills/mirror-be-claude/SKILL.md` + `hooks/mirror-sanity-check.sh` + 본 단락.
- **외부 프로젝트 CLAUDE.md 미러링:** `~/.claude/mirrors/{product}/CLAUDE.md` 가 외부 프로젝트 (현재: `hongcafe_global_backend`) CLAUDE.md 양방향 미러본. `mirror-claude-md.sh` PostToolUse hook 가 양쪽 Edit/Write 시 반대편 자동 cp. 단일 작성자 last-write-wins. 글로벌 미러본 = `.gitignore` 추적 제외. 수동 진입점 = `mirror-be-claude` 스킬 (3 모드 — `verify` / `sync-from-be` / `sync-from-global`, 후자 §3 Checkpoint). 다른 프로젝트 확장 = `~/.claude/mirrors/{product}/` 패턴 동일 적용. SSOT: `hooks/mirror-claude-md.sh` + `skills/mirror-be-claude/SKILL.md`.
- **Notion 연동 (요청 기반):** `notion-cli` 스킬 단일 진입점. 사용자 명시 요청 ("노션에 반영"·"Notion 동기화") 시에만 실행. 자동 반영 금지.

---

## 1. Session Initialization (자동 실행)

세션 시작 시:

1. 프로젝트 루트 구조 + 현재 브랜치/커밋 확인
2. `~/.claude/docs/{product}/tasks/history.md` 로드
3. `.claude/skills/` 전 스킬 SessionStart 훅 (`hooks/skill-preload.sh`) 자동 preload

→ 완료 후 **"Context Loaded."** 보고

---

## 2. Hierarchy & Authority (Global Constitution)

- **User Sovereignty:** 사용자 명시 승인 없이 행동하지 않는다. 불확실 시 `Checkpoint` 요청.
- **프로젝트 지침 제안:** 프로젝트 `CLAUDE.md` 추가 필요 판단 시 임의로 추가하지 않고 사용자 확인. 무단 수정은 지침 위반.

---

## 3. Checkpoint 발동 조건

다음 조건 중 하나라도 해당 시 즉시 중단 + 사용자 승인 요청:

| 조건 | 예시 |
|------|------|
| **비가역적 작업** | 파일 삭제, DB 스키마 변경, 마이그레이션 실행 |
| **광범위한 영향 범위** | 3개 이상 파일에 걸친 아키텍처 변경 |
| **요구사항 상충** | 성능 vs 가독성, 보안 vs 편의성 등 트레이드오프 |
| **외부 시스템 연동** | 외부 API 호출, 환경변수 변경, 서드파티 설정 수정 |
| **권한 외 파일 접근** | `.env`, 설정 파일, 허가되지 않은 디렉토리 접근 시도 |

**Checkpoint 는 항상 작동한다.** 단순 오타·주석·명백한 오기 (off-by-one 등 단일 파일 내 단순 수정) 외 모든 변경은 조건 매칭 시 무조건 승인 요청. "사소해 보임"·"이전 승인"·"Auto mode 활성"을 이유로 생략하는 것은 지침 위반. 불확실 시 발동이 기본값.

---

## 4. Guardrails & Quality

> **카테고리 인덱스:**
> - **§4.1 코드 품질·산출물:** 장기 관점 / Proactive Correction / Readability / Validation / Persistence / 타당성 검토 / 변경 영향 기록 / 산출물 유연성 / Before-After 대조 / 롤백 / 세션 내 commit 수정 / Co-Authored-By 금지
> - **§4.2 실행·위임·자동화:** 에이전트 우선 위임 / 실행 책임 / Hook 차단 자가 복구 / Hook 우회 금지 / audit 자동 수정 금지
> - **§4.3 게이트·워크플로우:** 묶음 승인 Fast-Track / output Gate-0 / 브랜치·worktree·push·머지 통합 정책 / skill-creator 진입점 / 로컬 수정 사전 승인 / e2e 검증 / 단계별 슬래시 워크플로우 (8 단계 + 토론)
> - **§4.4 응답 형식 + 자동 위임:** 응답 톤 / 응답 간결 / 답변 깊이 / 자동 위임 정책 (Echo-Back / 우선순위 / 4축 자동화) / 경로 안내 형식
> - **§4.5 산출물 생명주기:** working/ 자동 이동 / backlog 메모리 정책
>
> **역소급 면제 (필수):** 신규/강화 강제 룰은 도입 이전 산출물에 역소급 적용하지 않는다. 시점 단락 SSOT = `~/.claude/docs/claude-harness/changelog.md`.

### §4.1 코드 품질·산출물

- **장기 관점 분석·계획·실행 (필수):** **분석** = 증상만 보지 않고 근본 원인 + 재발 가능성 + 인접 SSOT (룰/템플릿/hook) 영향 범위. **계획** = 단기 패치 + 재발 방지 + SSOT 일관성 + 마이그레이션 비용. **실행** = 임시 우회·hardcode·주석 처리 금지. **Why:** 단기 fix 누적 = SSOT 분기·산출물 정합성 붕괴. **How to apply:** S = "장기 영향" 1줄. M·L = working/ 통합 문서에 **"장기 영향 / 재발 방지 / SSOT 일관성"** 3섹션 필수. 강제: `task-docs` 템플릿 + `workflow-enforcer` Gate. §3 Checkpoint 우선 적용. 역소급 면제 = changelog.md 참조.
- **Proactive Correction:** 오타만 즉시 수정. 문법·컨벤션·로직은 Team 1 분석 후 승인.
- **Readability:** 주석 없이 읽히는 명시적 코드. 전체 단어 (fullName, index) 사용.
- **Validation ("No Test, No Merge"):** 모든 수정은 유닛 테스트 또는 실행 로그 증빙 동반.
- **Persistence (필수):** 작업 완료 시 `~/.claude/docs/{product}/tasks/history.md` + `YYYYMMDD/summary.md` 기록. 강제: `session-completeness-check.sh`.
- **타당성 검토 (필수):** (1) 분석·사전 계획·설계 (SDD/SRS/SDP/IDD), (2) 라이브러리·프레임워크 선택, (3) 아키텍처 결정, (4) API 설계·계약 변경, (5) 보안·인증 패턴 — 예외 없이 "타당성 검토" 섹션 포함. 근거 = `docset-ref` 스킬. "통상적"·"일반적으로" 모호 표현으로 검토 대체 금지. 일반 코드 수정·버그 픽스·리팩토링·명명·주석·typo 는 본 룰 비대상.
- **변경 영향 기록 (필수):** analyze/preplan 반영 시 **변경되는 사항** + **개선점** + **수행 이유** 필수 기록.
- **산출물 유연성:** 신규 (≥ 2026-05-12) = working/ 단일 통합 1개. 한 파일 안 3 섹션 중 필요한 섹션만 채움. 기존 (< 2026-05-12) = 3종 분리 보존.
- **Before/After 대조 보고 (필수 / 무조건 진행):** 작업 완료 후 최초 실행안 vs 제안 변경분 diff/표 형태 보고. 제안 추가 0건이면 **"제안 추가: 없음 — 사용자 지시 그대로 반영"** 명시. 숨긴 채 최종안만 보고하는 것은 지침 위반.
- **롤백 가능 상태 (필수):** 제안 반영 코드는 롤백 가능 상태 유지. (1) 최초안/제안안 별도 커밋 분리 또는 (2) 명시적 diff/patch 제공. 단일 커밋에 섞어 분리 롤백 불가능하게 만들면 위반.
- **세션 내 commit 수정 (필수):** 본 세션 commit 수정 시 **`git revert` 금지**. 대신 **`git reset --soft HEAD~N`** + 새 commit. **push 흐름:** (1) push 전 = reset → 수정 → 새 commit. (2) push 후 = 사용자 명시 승인 + `--force-with-lease`. **Why:** revert 누적 = PR 노이즈 + 추적성 깨짐. **제약:** 공동 작업 브랜치 (production/staging/develop/main/master) = reset 금지, `git revert` 유지. 본 룰 = 단일 작업자 단기 feature 브랜치 한정.
- **Co-Authored-By 라인 금지 (필수):** git commit 메시지에 `Co-Authored-By: Claude ...` 포함 금지. 강제: `dangerous-ops-guard.sh`.

### §4.2 실행·위임·자동화

- **에이전트 우선 위임 (필수):** 사용자 요청 = default Agent 도구 (Explore / general-purpose / Plan) 또는 팀 스킬 (api-team / debate / orchestration / security-audit) 위임. 직접 작업 예외 = (1) 단일 파일 trivial 수정 (오타·1~3줄 패치) (2) 단발성 조회 1회 (3) 위임 비용 > 작업 비용. **트리거 매핑:** 코드베이스 탐색 → `Explore` / 다파일 영향 분석 → Team 1 / 다단계 구현 (M·L) → 3-Team / 설계 결정 → `Plan` / API 추가·디버깅 → `api-team` / 의견 갈림 → `debate` / 보안 검토 → `security-audit`. **판정:** "cold context 로 분리해서 검증할 가치가 있나?" → 예 = 위임. 직접 작업 시 사유 1줄 보고. §3 Checkpoint 우선 적용. Lead = Claude 본체 책임 (Agent 결과 종합 보고).
- **실행 책임 (필수):** Claude 는 실행 주체. 사용자에게 떠넘기지 않는다. (1) **승인 대기 떠넘기기 금지** — 코드 작업 중 개선 제안은 사용자 기본 수락 전제로 별도 승인 대기 없이 반영. (2) **명령 실행 떠넘기기 금지** — Bash allow + hook exit 0 통과 명령은 Claude 가 Bash 도구로 직접 호출. `! <command>` 안내문이나 "실행해 주세요" 텍스트 대체 금지. 로컬/조회 = 즉시 실행. 공유 상태 변경·비가역 = 영향·롤백 보고 → 승인 키워드 후 같은 턴 직접 실행. exit 0 경고 = "승인 후 직접 실행" 신호 (exit 2 만 차단). (3) **인프라 떠넘기기 금지** — 토큰/과부하/인프라 핑계 전가 금지. 529/Overloaded = 자동 재시도. "토큰 많이 들 수 있다" 류 경고 금지 (유료 Max 구독자). §3 Checkpoint 5조건은 본 룰에 우선.
- **Hook 차단 자가 복구 (필수):** hook 이 "파일 미생성 — 차단" 메시지 시 "생성해주세요" 되묻지 말고 Claude 가 직접 작성해서 통과. 조건 = (a) 이미 사용자 승인 받은 진행 맥락 (b) 차단 메시지 명시 경로·역할 정확히 따름. 자가 작성 후 "hook 지적 누락분 채움" 짧게 보고 후 승인 키워드 대기.
- **Hook 우회 임의 파일 생성 금지 (필수):** hook 차단 회피 목적 파일 생성·커밋 금지. 정당한 누락분 보완과 다름. 무관한 파일/hook 경로 위장 더미 파일 생성 = 위반. 차단 정당하지 않다고 판단 시 사용자 보고.
- **audit 결과 자동 수정 금지 (필수):** audit (예: `/api-spec-audit`·`/security-audit`) N 판정에 자동 "개선 제안"·"수정 계획" 덧붙이지 않는다. audit = 현황 진단 도구, 무조건 고쳐야 하는 task 아님. 사용자 명시 수정 요청 시에만 개선안 제시.
- **사용자 직접 실행 명령 스크립트화 (필수, 2026-05-20 신설):** §3 비가역·외부 시스템 변경 명령 (git push / git merge / git checkout `{main|master|origin/...}` / git worktree remove / git branch -D / rm -rf / DB 마이그·롤백 / aws cli 변경계 등) 을 사용자에게 직접 실행 요청할 때, **`! <command>` 텍스트 안내 대신 실행 가능 스크립트 파일을 작성**하고 사용자에게 1줄 실행 명령만 안내한다. **양식:** (1) 파일 경로 = `~/.claude/docs/scripts/{yyyy-mm-dd-HHMM}-{sid8}-{slug}.sh` (functional exemption #5 `*/.claude/docs/*` 매칭, worktree-enforce 자동 통과). (2) shebang `#!/usr/bin/env bash` + `set -euo pipefail` 헤더 + 명령 본문 + 마지막에 echo 완료 보고. (3) `chmod +x` 부착. (4) 사용자 안내 = `! bash ~/.claude/docs/scripts/{file}.sh` 단일 라인. **Why:** 텍스트 안내 복사 오타·multi-line 누락·env var 전개 사고 차단 + .sh 파일 자체 = 명령 audit log + 동일 명령 재실행 가능. **트리거 범위:** §3 비가역 / 외부 시스템 변경에 한정. 일상 단일 라인 조회 명령(`ls` / `git status` / `git log` 등)은 그대로 텍스트 안내. **면제:** 단일 라인 + 비파괴 + env var 무관 시 텍스트 안내 허용 (양식 강제 비용 > 오타 위험 시). **GC:** `hooks/scripts-cleanup.sh` SessionStart hook 가 `find ~/.claude/docs/scripts -name '*.sh' -mtime +7 -delete` 자동 정리. **§3 우선 적용 + Claude 본체 먼저 실행 (2026-05-20 갱신):** Claude 본체가 스크립트 작성 후 **먼저 `bash {script}` 직접 호출 시도**한다. hook 차단·권한 오류·기타 실패 발생 시에만 사용자에게 `! bash {script}` 직접 실행을 안내한다. **§3 절대 차단 영역 (스크립트 본문에 매칭) 은 처음부터 사용자 직접 안내 — Claude 자동 호출 시도조차 금지:** `git push` / master·main 머지·체크아웃 / `git worktree remove` / `git branch -D` / DB 마이그·롤백 / `rm -rf` / aws cli 변경계 등. **Why:** 안전한 스크립트는 매번 사용자 burden = 자동화 가치, 막힌 경우만 알리는 게 효율 (사용자 2026-05-20 명시 결정). §3 절대 룰은 그대로 유지.

### §4.3 게이트·워크플로우

- **묶음 승인 Fast-Track (Gate 0→2):** 사용자 묶음 승인 키워드 입력 시 `gate-approve.sh` 가 Gate 0/1 → 2 점프. **Claude 측 활용:** M/L 코드 작업에서 분석/계획 단일 사이클 압축 가능 시 묶어 보고 → 1회 승인. 단 §3 Checkpoint·아키텍처 결정·트레이드오프가 분석 단계에 걸린 작업은 단계별 보고. **자동 순차 진행:** `gate-init.sh` 가 gate=2 (EXECUTE) 초기화. 단계별 키워드 매번 요구 폐기. §3 Checkpoint 5조건 보호 = `dangerous-ops-guard.sh` / `branch-enforce.sh` / `git-quality-gate.sh` / `output-naming-check.sh` / `author-field-check.sh` 별 hook 담당.
- **`output/` 경로 Gate-0 직행:** `~/.claude/docs/{product}/output/` 하위 = 면제 경로, Gate-0 즉시 Edit/Write 허용. `settings.local.json` (gitignore, 개인 override) 도 Gate-0 면제. 글로벌 `settings.json` (git 추적, 공유) = Gate ≥ 1 유지.
- **`checklist-count-check.sh` 임계:** `unified` 양식 = ≥ 30. analyze ≥ 30 / plan ≥ 20 / result Self-Critique ≥ 20. SSOT: `hooks/checklist-count-check.sh` L54.
- **브랜치·worktree·push·머지 통합 정책 (필수, 2026-05-20 재정의):** 단일 SSOT = `hooks/worktree-enforce.sh` + `hooks/worktree-prompt-detect.sh` + `commands/{자동진행,feature-create,feature-merge}.md` + `hooks/branch-enforce.sh` (잔존 영역) + `skills/git-push/SKILL.md`.
  - **(a) worktree 항상 강제 (전 영역):** 모든 소스 mutation 작업은 worktree 안에서 수행. cwd 또는 FILE_PATH 가 worktree (`*/worktrees/*`) 가 아니고 functional exemption 8건 매칭 안 됨 → `worktree-enforce.sh` PreToolUse exit 2 차단. **사용자 작업 키워드 매칭 시** UserPromptSubmit `worktree-prompt-detect.sh` 안내 stderr 주입 → Claude 본체 즉시 `git worktree add ~/.claude/worktrees/{sid}-{slug} -b wip/{sid}-{slug}` 실행. **claude-harness 영역 (`~/.claude/`) 면제 폐기 (2026-05-20)** — 본 영역도 worktree 강제.
  - **(b) feature 분기 = 사용자 요청 시 생성:** 신규 feature 생성 = `/feature-create` (worktree → 신규 feature 정착). 기존 feature 수정 = `/feature-merge` (worktree → 기존 feature ff-only 머지). 자동 강제 폐기 (구 `branch-enforce.sh` §(2) retire) — 사용자 작업 의도 트리거 시에만.
  - **(c) Functional exemption 8건 (`worktree-enforce.sh` SSOT):**
    1. `*/worktrees/*` — worktree 자체
    2. `*/state/sessions/*.lock` — session lock (working-register/heartbeat/release hook 자기참조)
    3. `*/projects/*/memory/*` — auto memory
    4. `/tmp/claude_*` — gate/stop/echo marker
    5. `*/.claude/docs/*` — 산출물 (working/REGISTRY.md 포함, Gate-0 직행 정합)
    6. `*/.claude/settings.json` — git untracked, worktree 동기화 불가능
    7. `*/.claude/settings.local.json` — git untracked
    8. `C:/Works/infra/*` — dev-team 인프라 영역 (git 미추적, 2026-05-20 dev-team 도입 동반 추가)
  - **(d) `git push` 전면 금지:** 어떤 분기·시나리오에서도 Claude 자동 `git push` 금지 (feature/source/personal/relay 모두 포함, `--delete`·`--force-with-lease` 포함). 사용자 직접 (`! git push ...`) 만 허용. 강제: `branch-enforce.sh` §(1) shlex 토큰화 exit 2 (잔존).
  - **(e) master/main 머지·체크아웃 절대 금지:** `git merge {main|master|origin/main|origin/master|refs/heads/main|refs/heads/master|upstream/main|upstream/master}` / `git checkout {위 target}` / `git switch {위 target}` + chained 명령 모두 자동 호출 금지. 사용자 직접만. 강제: `branch-enforce.sh` §(1.5) 잔존. worktree 정착 시 source = main/master 이면 정착 절대 금지 — PR 절차로 대체.
  - **(f) ff-only 머지 + worktree 정리:** worktree 정착 명령 (`/feature-create`·`/feature-merge`) = **사용자 직접 (`! ` prefix) 실행 권장**. Claude 자동 머지 금지 — §3 Checkpoint "비가역적 작업" 매칭. 정착 후 `git worktree remove` + `git branch -D wip/*`.
  - **Why:** push/머지 사고는 자동화 1회 실수로 즉시 발생, 사용자 직접 1라인 비용은 거의 0. worktree 항상 강제 = 원본 working tree 영구 격리, 사고 영구 차단. claude-harness 면제 폐기 = (A) 통일 강제 — 본 영역도 SSOT 룰 작업 사고 차단. 시점 단락 = changelog.md 참조.
  - **산출물 SSOT:** `~/.claude/docs/working/20260520/2026-05-20-claude-harness-worktree-always-policy.md` + `~/.claude/docs/claude-harness/output/guide/2026-04-30-branch-workflow/` (구 정책 참조).
- **스킬 생성·수정·최적화 — skill-creator 강제 진입점 (필수):** `.claude/skills/{skill}/` 하위 모든 파일 생성·수정·최적화 = `skill-creator` 스킬 경유 필수. `skill-edit-guard.sh` PreToolUse hook 가 Edit/Write 시도를 exit 2 차단, 락 파일 (`~/.claude/.skill-creator-active.lock`) 존재 시에만 우회. **진입 절차:** (1) `/skill-creator` 또는 "스킬 만들기/수정/개선/최적화" 트리거 → (2) `touch ~/.claude/.skill-creator-active.lock` → (3) Edit/Write → (4) 종료 시 `rm` 락. 세션 종료 시 `gate-init.sh` 가 잔여 락 자동 정리.
- **로컬 수정 사전 승인 + 서버 우선 검증 (필수):** 프로덕션·공유 환경 영향 코드는 로컬 수정 전 (1) 서버 원인 파악 + 테스트, (2) 수정 필요 사항 목록 사용자 제시, (3) 승인 후 로컬 수정. 서버 로그로 원인 파악 후 즉시 로컬 수정·커밋·푸시·머지 = 지침 위반.
- **e2e 검증 (필수):** 코드 수정 완료 판단 = 유닛 테스트 통과 + 환경/스키마/실 엔드포인트 검증. 5점 체크 (env / 함수·클래스 정의 / DB 스키마 / 프로덕션 curl / mock 검증) 세부는 `php8` 스킬 §"e2e 검증" SSOT.
- **단계별 슬래시 워크플로우 (필수, 2026-05-15 도입):** 작업 사이클을 8 단계 슬래시 + `/토론` 으로 명시 진입한다. 자연어 키워드 자동 매칭 + 직접 슬래시 호출 모두 동일 동작. **키워드 → 슬래시 매핑:**

  | 자연어 키워드 | 진입 슬래시 | 동작 / 강제 hook |
  |--------------|----------|-----------------|
  | "분석해줘" / "코드 분석" / 작업 진단 | `/분석` | working/ §분석 채움 (관점별 요약 / Critical~Low / 우선순위 권고). `doc-template-guard.sh` unified §분석 헤더 강제 |
  | "타당성 검토" / "공식 근거 확인" | `/타당성` | `docset-ref` 호출 + working/ §타당성 검토 `[Source:...]` ≥ 1건. `feasibility-section-check.sh` 권고 (hint only, exit 0 + stderr 경고. 행동 룰 = §4.1 "타당성 검토 (필수)" 본문 SSOT) |
  | "계획 짜줘" / "플랜 작성" | `/계획` | working/ §계획 채움 (수정 대상 / Blueprint / WBS). Status: Plan Complete |
  | "구현" / "실행" / "작업 진행" | `/실행` | working/ §실행 + Self-Critique + Status: Done/Partial. Done + Self-Critique 동시 시 working-lifecycle 자동 이동 |
  | "검증" / "e2e" / "테스트" | `/검증` | env / 함수·클래스 / DB 스키마 / 프로덕션 curl / mock 5점 체크. `verify-e2e-check.sh` 강제 |
  | "리뷰" / "코드 리뷰" / "Self-Critique" | `/리뷰` | Self-Critique 체크리스트 ≥ 20 + `simplify` 보조 (§4.3 L132 SSOT) |
  | "머지" / "push" / "배포" | `/배포` | `git-push` + `branch-enforce` 통합 안내. **Claude 자동 push·master 머지 금지**, 사용자 직접 (`! ` prefix) |
  | "회고" / "세션 마감" / "retro" | `/회고` | history.md + summary.md 기록 (Persistence 강제) |
  | "토론" / "의견 갈림" / "트레이드오프" | `/토론` | 4 에이전트팀 × 4 Agent = 16 Agent 풀-병렬 spawn. 비용 4×, 의견 깊이 ↑ |

  **권장 호출 순서:** `/분석` → `/타당성` (병행 가능) → `/계획` → `/실행` → `/검증` → `/리뷰` → `/배포` → `/회고`. `/분석` 과 `/타당성` 은 동시 진행 가능 — 분석 진행 중 공식 근거가 필요해지면 `/타당성` 을 끼워 호출. 작업 등급별 압축:
  - **S 등급** = `/분석` → `/실행` → `/회고` (3 단계)
  - **M 등급** = `/분석` → `/계획` → `/실행` → `/검증` → `/회고` (5 단계)
  - **L 등급** = 8 단계 전체

  의견 갈림 시 어느 단계에서나 `/토론` 끼워 호출 가능. **§3 Checkpoint 우선 적용:** 단계 진입은 hook (`doc-template-guard.sh` / `checklist-count-check.sh` / `verify-e2e-check.sh` / `branch-enforce.sh`) 가 양식 강제. 사용자 명시 승인 룰은 그대로 유지 (특히 `/배포` = §3 비가역 매칭). **SSOT:** `~/.claude/commands/{분석,타당성,계획,실행,검증,리뷰,배포,회고,토론}.md` 9 파일.

### §4.4 응답 형식 + 자동 위임

- **응답 톤 (필수 / 존댓말):** 항상 존댓말. "~함"·"~임"·"~할까"·"~인데" 명사형/평서형 금지. 단답 ("진행") 도 "진행하겠습니다" 풀어 응답. 표·목록 안 짧은 항목 외 모든 서술 문장 적용.
- **장기 관점 추천 (필수):** 제안·추천·옵션 제시 시 **단기 효율보다 장기 누적 비용·복잡도·유지보수성** 우선 판단. **Why:** 단기 OK 옵션 누적 = SSOT 분기·hook 복잡도·기능 graveyard 증가, 6~12개월 후 유지보수 폭증. **How to apply:** (1) "(추천)" 표시는 장기 관점 best 옵션에 부착. (2) 단기 OK / 장기 부담 큰 옵션은 "단기 OK, 장기 SSOT 분기·복잡도 누적 가능" 명시 경고. (3) 신설 hook / 슬래시 / SSOT 추가 권고 시 = "6개월 후에도 필요한가" 자가 점검 1회 거치고 추천. (4) 기존 시스템 폐기 권고 시 = "검증 안 된 시스템 / 사용 빈도 낮음 / 누적 복잡도 vs 가치" 천칭에 올려 폐기 우선 고려. (5) 임시 우회·hardcode·feature flag = 장기 부담 누적, 거의 항상 비추천. (6) 메모리·hook·skill 추가 시 = "지금 만들면 유지보수 책임" 인지 후 신설. SSOT: 본 룰 + `orchestration` §"Communication Protocol".
- **응답 간결 (Concise Reporting, 필수):** 보고·결과·분석 출력 = **결론·핵심 표·diff** 위주 압축. 사족·진행 서술 제거. 기본 형태 = 결론 1~2줄 + 표/diff 1개 + 잔여 액션 1줄. **면제 영역:** Before/After 대조 / 타당성 검토 / 변경 영향 기록 / `tasks/` 산출물. 보조 강제: `agent-first-banner.sh` + `orchestration` §"Concise Reporting".
- **답변 깊이 (Anticipatory Depth, 필수):** "이걸 들으면 사용자가 뭘 더 궁금해할까" 선제 고려 후 한 단계 더 깊이 응답. **적용 영역 분리:** 본 룰 = 사용자 질문 답변 우선. 작업 진행/완료 보고 = "응답 간결" 룰 우선.
- **자동 위임 정책 (Autonomous Iteration, 필수):** 묶음 승인 키워드 (`자동 진행` / `자동으로 진행` / `권장으로 진행` / `auto 진행` 등) 입력 = "Claude 가 알아서 끝까지 진행 + 문제없다고 판단될 때까지 자체 반복" 해석. 본 룰은 Echo-Back Confirm·권고안 자동 채택·우선순위 매트릭스·4축 자동화를 통합 정의한다.
  - **(1) Echo-Back Confirm (최초 진입):** 코드/분석 mutation 지시 첫 응답 시 = 첫 단락에 사용자 의도 정리 (echo back) + 마지막 줄 승인 요청. 승인 키워드 수신 전 mutation 도구 (Edit/Write/MultiEdit/NotebookEdit/Bash mutation) 호출 금지. read-only 도구 (Read/Glob/Grep/git status·log·diff/aws describe·list·get/SELECT) 1~2건 허용. 펜딩 마커 = `/tmp/claude_echo_pending_${SESSION_ID}`. **트리거:** mutation 키워드 (만들/구현/추가/수정/리팩/디버그/픽스/생성/삭제/변경/제거/통합/분리/적용/연결/리네임/개선/최적화) + 분석 키워드 (분석/조사/비교/검토/점검/audit/리뷰/파악/대조/매핑/추적/영향) + 실행/배포 키워드 (실행/돌려/배포/마이그레이션/롤백). **면제 영역:** (a) 단순 조회·잡담 (b) 단답 10자 미만 (c) 부정 컨텍스트 (취소/보류/no/cancel) (d) 승인 키워드 단독 (e) 펜딩 마커 존재 (정정/추가 지시) (f) 묶음 승인 후 60분 후속 면제 (`/tmp/claude_gate_${SESSION_ID}` = 2, mtime 60분 이내).
  - **(2) 권고안 자동 채택:** 묶음 승인 키워드 입력 시 = 직전 응답 권고안 **기본 옵션 (가장 안전한 첫 번째)** 즉시 채택. 옵션 분기 재제시 / "어느 옵션?" 의례적 재확인 금지. 분기 필요 = 사용자 명시 요청 또는 §3 Checkpoint 매칭 시에만. **권고 제시 시 (사전):** 기본 옵션 명확화 + 트레이드오프 1줄 + 비기본 옵션 조건 안내 3가지 포함.
  - **(3) 4축 자동화:**
    - **(a) 후속 권고 자동 채택** — 직전 응답 후속 권고·잔여 액션·옵션 분기를 다시 묻지 않고 기본 옵션으로 모두 끝까지 진행. **backlog/USER-DECISION 발생 시 = `/자동진행` 진입 시 `/debate` (16 Agent) 1회 spawn 으로 정책 결정 위임 (bounded, 5 안전장치 = pre-filter / budget cap 1회 / 정책 결정 only / 종료 조건 재정의 / 조건부 자동 적용 + 재토론 금지). ≥3팀 합의 시 §3 매칭 재검사 후 자동 적용, 분산 시 USER-DECISION sentinel + 재토론 X. SSOT = `commands/자동진행.md` §"Backlog 토론 spawn 정책 (bounded)".**
    - **(b) self-critique 루프 (Claude 본체 책임)** — 각 단계 완료 직후 산출물·코드·실행 결과 직접 검증, FAIL/WARN/오류·hook 차단·테스트 실패·양식 누락 0건일 때까지 자동 반복 (개선·재실행). stateless hook 단독 강제 불가 — 판정은 Claude 본체 메모리 기반, hook 은 reminder 주입만. **재시도 5회 한도.** **§3 Checkpoint 매칭 분기:** self-critique 루프 중 §3 5조건 (비가역·광범위·요구사항 상충·외부 시스템·권한 외 접근) 매칭 항목 발견 시 **직접 수정 금지** — 즉시 사용자 보고 + 명시 승인 대기 후 재진입. 본 분기 = §3 우선 적용 룰의 self-critique 영역 명문화.
    - **(c) 종료 sentinel 자동 부착** — 모든 작업 + self-critique 통과 후 응답 **마지막 줄** sentinel 부착: **`[AUTO-ITERATE-DONE]`** (잔여 0건) / **`[AUTO-ITERATE-USER-DECISION]`** (사용자 결정 영역 잔여 — §3 매칭·옵션 분기·외부 시스템 변경). 자연어 표현 ("작업 완료") 만으로는 hook 통과 불가.
    - **(d) Stop 자동 차단 + 재진입** — gate=2 활성 + 작업 미완료 + sentinel 미부착 시 `auto-iterate-stop-guard.sh` (Stop hook) 가 exit 2 차단 → 자동 재진입. 카운터 (`/tmp/claude_iterate_count_${SESSION_ID}`) **5회 한도.** **§3 매칭 시 차단 우선:** 재진입 시점에 `dangerous-ops-guard.sh` / `sensitive-file-guard.sh` / `branch-enforce.sh` 가 §3 5조건 매칭을 먼저 검사 — 매칭 시 재진입이 별 hook exit 2 로 차단되므로 자동 루프가 §3 보호 우회 통로로 작동하지 않는다.
  - **(4) 종료 조건:** (a) self-critique 0건 FAIL/WARN + 후속 권고 잔여 0건, (b) 사용자 `중단`/`보류`/`멈춰` 입력 (stop marker `/tmp/claude_stop_requested_${SESSION_ID}` 트리거), (c) §3 Checkpoint 5조건 매칭 (사용자 승인 필수), (d) 재시도 또는 Stop 재진입 5회 초과.
  - **(5) 우선순위 매트릭스 (deadlock 방지):** **§3 Checkpoint > 실행 책임 > 본 룰 (자동 위임) > Auto mode > Echo-Back Confirm.** Auto mode 활성 신호도 §3 / 실행 책임 / Echo-Back 진입을 위반하지 않는 범위에서만 적용. 사용자 명시 Auto mode 강행 요청해도 §3 발동 시 승인 대기 우선. **§3 우선 적용:** 비가역 (파일 삭제·force push·DB 변경)·광범위 (3파일+ 아키텍처 변경, **본 룰 자체 수정/삭제 포함**)·외부 시스템 변경 = 본 룰 무관하게 사용자 명시 승인 필수. Stop 자동 차단 (3d) 도 §3 매칭 시 별 hook (dangerous-ops-guard / sensitive-file-guard / branch-enforce) 가 차단 — 재진입이 보호 우회 통로로 작동하지 않는다.
  - **승인 키워드 SSOT:** `hooks/gate-approve.sh` 정규식 본문 (단답 승인 / 접미사 흡수 / 묶음 승인 / 부정 컨텍스트 차단 / 위치 제약 모두 hook SSOT). 본문 별도 나열하지 않음.
  - **SSOT:** 본 룰 + `hooks/gate-approve.sh` (키워드 + stop marker 생성) + `hooks/prompt-echo-confirm.sh` (Echo-Back) + `hooks/auto-iterate-reminder.sh` (PostToolUse reminder 주입) + `hooks/auto-iterate-stop-guard.sh` (Stop 차단 + 재진입).
- **경로 안내 형식 (OS 정합, 필수):** 사용자 노출 경로 = **Windows** = `C:\Users\PV\.claude\docs\...` 백슬래시 절대 경로. **POSIX** = `~/.claude/docs/...` 또는 절대 경로. **양식 적용:** (1) 산출물 경로·코드 위치·도구 결과 보고 = OS 정합. (2) Bash 도구 `command` 파라미터 = POSIX 유지 (도구 내부용). (3) Glob/Grep 패턴 = `/` 그대로. (4) PowerShell 도구 = 백슬래시 + 큰따옴표. (5) 세션 OS 판정 = SessionStart `Platform`/`OS Version`. **면제:** 코드·스키마·hook·스킬 정의 등 OS 무관 식별자 (예: `app/Modules/Member/Models/MemberModel.php`) = forward slash 유지. 보조 강제: `task-docs` 스킬 §"공통 규칙".

### §4.5 산출물 생명주기

- **working/ 자동 이동 3 진입점 (필수):** working/ → tasks/ 이동 트리거 = 3 경로로 명확 분리. 사용 시점·진입점 혼동 방지.
  - **(1) 정상 마감 — `/작업저장`:** 세션 마감 직전 권장 진입점. worktree 정착 안내 + working/ 본문 마무리 + 잔여 작업 판정 (Done = tasks/ 이동 / Partial = working/ 유지). 짝 슬래시 = `/작업로드`.
  - **(2) 긴급 단순 이동 — `/working-done`:** 본문 마무리 후 즉시 정리. Self-Critique·잔여 판정 생략, 단순 파일 이동만. `/작업저장` 보다 가볍지만 잔여 추적 책임은 사용자.
  - **(3) 자동 — `working-lifecycle.sh` PostToolUse:** `Status: Done` (시작 라인) + `## Self-Critique` 섹션 동시 존재 시 hook 가 즉시 이동. `/실행` 진입 후 본문 마무리하면 자연스럽게 트리거.
  - **선택 기준:** 정상 종료 = (1), 본문은 완료지만 추가 단계 생략 시 = (2), `/실행` 중 자연 마무리 시 = (3).
  - SSOT: `commands/작업저장.md` + `commands/working-done.md` + `hooks/working-lifecycle.sh`.
- **backlog 메모리 정책 (필수):** 본 세션 잔여 후속·시간 트리거·사용자 결정 보류 = `~/.claude/projects/.../memory/backlog_{slug}.md` 단일 파일. **양식 (frontmatter):** `name` (kebab-case) / `description` (1줄) / `type: backlog` / `status: pending|in_progress|done` / `source` / `target_date` (선택) / `product` (기본 claude-harness) / `created` / `completed` (status=done 시 hook 자동 채움). MEMORY.md `## Backlog` 섹션 entry 추가 필수. **자동 이동:** (a) `status: done` 마커 → `backlog-lifecycle.sh` PostToolUse hook 가 `tasks/{YYYYMMDD}/backlog/{yyyy-mm-dd}-{slug}.md` 자동 이동 + MEMORY.md entry 제거 + history.md/summary.md 갱신. (b) 사용자 명시 키워드 (`backlog 완료`/`backlog 정리`/`backlog 이동`/`/backlog-done`) = 일괄 스캔 이동. §3 Checkpoint 우선 적용. SSOT: `hooks/backlog-lifecycle.sh` + `skills/task-docs/SKILL.md` §"backlog 메모리 워크플로우".

---

## 5. Skill & Slash Inventory

> **목적:** user-invocable skill 카탈로그 SSOT. 신규/삭제/rename 시 본 표 갱신.
> **SSOT 일관성:** skill frontmatter `user-invocable: true` ↔ 본 표 ↔ `commands/{name}.md` (있다면) ↔ CLAUDE.md 멘션.

### 5.1 user-invocable Skills (호출 가능 진입점)

> **자동화 컬럼:** A = 완전 자동 (사용자 1회 트리거로 끝까지) / B = 부분 자동 (분석은 자동, 변경 적용은 사용자 결정) / C = 수동 진입점 (사용자 단계별 결정 필수). SSOT = `output/analysis/2026-05-13-automation-skill-classification/` §3.

| Skill | 용도 (1줄) | Slash | commands/.md | 자동화 |
|-------|----------|-------|-------------|--------|
| api-spec-audit | API 명세 ↔ IEEE 산출물 9축 정합성 audit | `/api-spec-audit` | ✓ | A |
| api-team | API 추가/디버그 FE+BE+인프라 3-멤버 영향분석 | `/api-team` | ✓ | A |
| aws | AWS 서비스 (CLI / CloudWatch / Lambda 등) | `/aws` | ✗ (skill 진입) | C |
| bitbucket-cli | Bitbucket Cloud REST API (curl + 토큰) | `/bitbucket-cli` | ✗ (skill 진입) | C |
| debate | Multi-Agent Subagent Debate (4그룹 12 서브에이전트) | `/debate` | ✓ | A |
| debug-skill | 다영역 디버깅 (PHP / DB / AWS / 보안) | `/debug-skill` | ✗ (skill 진입) | B |
| dev-team | HongCafe Global 다레포 개발 전용 팀 (BE / 인프라 / 문서 / FE read-only). Lead 라우팅 1~4 spawn. api-team(영향분석)→dev-team(구현) handoff | `/dev-team` | ✗ (skill 진입) | A |
| feature-create | worktree → 신규 feature 분기 정착 (사용자 직접 머지) | `/feature-create` | ✓ | C |
| feature-merge | worktree → 기존 feature 분기 ff-only 머지 (사용자 직접 머지) | `/feature-merge` | ✓ | C |
| git-push | Conventional Commits + git push 즉시 실행 | `/git-push` | ✗ (skill 진입) | C |
| mirror-be-claude | be 프로젝트 CLAUDE.md ↔ 글로벌 미러본 동기화 | `/mirror-be-claude` | ✗ (skill 진입) | A (verify·sync-from-be) / C (sync-from-global) |
| mysql8 | MySQL 8.x 쿼리·스키마·인덱스 | `/mysql8` | ✗ (skill 진입) | B |
| notion-cli | Notion API curl 기반 CLI | `/notion-cli` | ✗ (skill 진입) | C |
| orchestration | 3-Team (Analyze → Plan → Execute) 통합 | `/orchestration` | ✗ (skill 진입) | A |
| php8 | PHP 8.4+ / CI 4.7+ Modular Monolith | `/php8` | ✗ (skill 진입) | B |
| report | 일일·주간·월간 업무 리포트 생성 | `/report` | ✓ | A |
| security-audit | 7개 도메인 통합 보안 감사 (OWASP/CWE 등) | `/security-audit` | ✓ | A |
| skill-creator | 스킬 생성·수정·최적화 강제 진입점 | `/skill-creator` | ✗ (skill 진입) | C |
| skill-validator | skill 풀 검증 (frontmatter + 본문 품질) | `/skill-validator` | ✗ (skill 진입) | B |
| sns-oauth | SNS OAuth (kakao/naver/google/apple) 표준 패턴 | `/sns-oauth` | ✗ (skill 진입) | A (verify) / B (add·debug) |
| task-docs | 작업 문서 생명주기 (analyze → plan → result) | `/task-docs` | ✗ (skill 진입) | A |
| workflow-enforcer | 3-Team Workflow Gate 강제 (Checkpoint 체크리스트) | `/workflow-enforcer` | ✗ (skill 진입) | C |
| working-done | working/ 단일 통합 문서 → tasks/ 자동 이동 트리거 | (사용자 직접 입력) | ✓ | A |
| 자동진행 | 묶음 승인 모드 진입 — 잔여 액션 / 인자 작업 자동 진행 | `/자동진행` | ✓ | A |
| 작업저장 | 세션 마감 — worktree 정착 안내 + working/ 문서 마무리 + 잔여 작업 판정 (Done / Partial 분기) | `/작업저장` | ✓ | A |
| 작업로드 | 세션 재개 — working/ Status: Partial 잔존 작업 스캔 + 본문/잔여 표시 + 재진입 안내 (read-only) | `/작업로드` | ✓ | A |
| 분석 | 작업 분석 단계 진입 — working/ §분석 섹션 채움 (관점별 요약 / Critical~Low / 우선순위 권고) (thin wrapper) | `/분석` | ✓ | A |
| 타당성 | 타당성 검토 단계 진입 — docset-ref 호출 + 공식 근거 인용 ≥ 1건 (thin wrapper) | `/타당성` | ✓ | A |
| 계획 | 작업 계획 단계 진입 — working/ §계획 섹션 채움 (수정 대상 / Blueprint / WBS) (thin wrapper) | `/계획` | ✓ | A |
| 실행 | 작업 실행 단계 진입 — working/ §실행 섹션 + Self-Critique + Status 판정 (thin wrapper) | `/실행` | ✓ | A |
| 검증 | e2e 5점 검증 진입 — env / 함수 / 스키마 / curl / mock (thin wrapper) | `/검증` | ✓ | A |
| 리뷰 | Self-Critique + simplify 스킬 보조 리뷰 (thin wrapper) | `/리뷰` | ✓ | A |
| 배포 | git-push + branch-enforce 통합 배포 안내 (사용자 직접 실행) (thin wrapper) | `/배포` | ✓ | C |
| 회고 | history.md + summary.md 자동 기록 + 세션 마감 정리 (thin wrapper) | `/회고` | ✓ | A |
| 토론 | 4 에이전트팀 × 4 Agent = 16 Agent 풀-병렬 spawn 토론 진입 (한글 진입점, `/debate` 호환) (thin wrapper) | `/토론` | ✓ | A |
| 병렬 | Modifier 슬래시 — `/병렬 /{인자 슬래시}` 형식으로 단일 응답 내 Agent spawn 강제 병렬화. 매 응답마다 명시 입력 필요 (60분 활성 marker 폐기, 2026-05-18). hook 의존 0 | `/병렬` | ✓ | A |
| 프로세스 | Claude Code 프로세스 + 세션 sid 매핑 조회 + REGISTRY/lock orphan 분류·정리. 3 모드 — 기본 (read-only), `cleanup` (orphan 정리), `kill` (좀비 PID 종료 명령 안내, 사용자 직접) | `/프로세스` | ✓ | B |

**자동화 분류 카운트:** A = 23 (api-spec-audit · api-team · debate · dev-team · orchestration · report · security-audit · task-docs · working-done · 자동진행 · 작업저장 · 작업로드 · 분석 · 타당성 · 계획 · 실행 · 검증 · 리뷰 · 회고 · 토론 · 병렬 + mirror-be-claude verify·sync-from-be + sns-oauth verify) / B = 6 (debug-skill · mysql8 · php8 · skill-validator · 프로세스 + sns-oauth add·debug) / C = 10 (aws · bitbucket-cli · feature-create · feature-merge · git-push · notion-cli · skill-creator · workflow-enforcer · 배포 + mirror-be-claude sync-from-global). **A 그룹만 `/loop` · `/schedule` 결합 권장** (SSOT = `output/guide/2026-05-13-loop-schedule-combination/`).
> **혼합 분류 카운트 방식 (필수):** mirror-be-claude (A/C) · sns-oauth (A/B) 처럼 모드별 자동화 강도가 다른 skill 은 **각 모드별로 분리 카운트**. 행 1줄 = 1 표기 (`A (verify·sync-from-be) / C (sync-from-global)`), 카운트는 모드 단위. 표 행 단순 카운트 (skill 단일 count) 와 다름.

### 5.2 Internal Skills (자동 트리거 / 의존성용, slash 호출 없음)

| Skill | 용도 (1줄) | 비고 | 자동화 |
|-------|----------|------|--------|
| docset-ref | Dash docset 오프라인 기술 레퍼런스 검색 | `타당성 검토` (§4.1) 자동 호출용 — frontmatter `user-invocable: false` | A |
| global-context | HongCafe Global 다국가 서비스 컨텍스트 | 프로젝트 한정 | A |
| simplify | 변경 코드 재사용성·가독성·효율성 리뷰 후 이슈 픽스 | Claude Code 내장 plugin skill — `~/.claude/skills/` 본체 없음, available-skills 카탈로그 등재. `/리뷰` 보조 호출용 (Skill 도구) | B |

### 5.3 Claude Code 내장 Slash (참고)
`/help` `/clear` `/loop` `/fast` `/config` — Claude Code 자체 명령.

### 5.4 동기화 규칙
- skill 신규 추가 → 본 표에 1줄 추가 (자동화 컬럼 A/B/C 분류 + 모드별 분리 필요 시 명시).
- skill rename → 폴더명 + SKILL.md frontmatter name + 본 표 동시 갱신.
- skill 삭제 → 본 표에서 제거 + 의존성 grep (`depends_on` 그래프) 후 영향 skill 갱신.
- skill 자동화 강도 변경 → 분석 산출물 갱신 + 본 표 자동화 컬럼 + §5.1 카운트 행 갱신.
- **depends_on 방향성 (필수):** A 가 B 의 출력/SSOT/산출물을 소비 시 `A.depends_on = [B]` **단방향** 명시. 양방향 (A↔B) / 순환 (A→B→C→A) 금지. 의존 = 정적 참조, 동적 호출은 워크플로우. 강제 hook = `skill-validator` 강화 후보 (별 작업). 시점 단락 = changelog.md 참조.
- **version 컨벤션 (필수):** SKILL.md frontmatter `version` = semver 2.0.0. **Major** = 진입점·메인 모드·triggers 의미 변경 / **Minor** = 새 모드·trigger 추가 / **Patch** = 양식 보강·버그 픽스. 신규 스킬 = `1.0.0` 시작. 역소급 면제 — 도입 이전 version 값 보존.
- **min_claude_md_version 갱신 (필수):** CLAUDE.md 메이저 업그레이드 (v4→v5) 시 일괄 갱신 금지. 영향받는 스킬만 개별 갱신. 기본 동작 = 기존 값 유지.
