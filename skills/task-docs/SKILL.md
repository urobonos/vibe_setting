---
name: task-docs
description: >
  작업 문서 생명주기(분석→계획→결과)를 표준 템플릿으로 생성·이동한다.
  **신규 (2026-05-12~)** = `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 단일 통합 문서로 진행 후 완료 시 `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` 로 자동 이동 (working-lifecycle.sh hook).
  **기존 (역소급 면제, < 2026-05-12)** = `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/` 에 analyze/plan/result 3종 분리 그대로 보존.
  일일 작업 요약을 `~/.claude/docs/{product}/tasks/YYYYMMDD/summary.md`, 전체 이력을 `~/.claude/docs/{product}/tasks/history.md` 에 기록.
  모든 문서 파일은 `{yyyy-mm-dd}-` prefix 필수.
  보고용 산출물은 `~/.claude/docs/{product}/output/{category}/{제목}/{파일명}.md`, IEEE 산출물(SDP/SRS/SDD/IDD/STP/STD)은 `~/.claude/docs/{product}/specs/`.
  {product}는 basename $CWD (.claude→claude-harness 예외). 규칙은 글로벌 CLAUDE.md §File Paths 참조.
  **backlog 메모리 (2026-05-13~)** = 잔여 후속·시간 트리거·사용자 결정 보류 작업은 `~/.claude/projects/C--Users-PV--claude/memory/backlog_{slug}.md` 단일 파일로 보관. frontmatter `status: done` 시 `backlog-lifecycle.sh` hook 가 `~/.claude/docs/{product}/tasks/{YYYYMMDD}/backlog/{yyyy-mm-dd}-{slug}.md` 자동 이동. SSOT = CLAUDE.md §4 "backlog 메모리 정책".
triggers:
  - "/plan"
  - "/research"
  - "/task-docs"
  - "/task-docs specs"
  - "플랜 작성"
  - "계획 세워줘"
  - "리서치 해줘"
  - "분석 문서 작성"
  - "코드 분석 문서"
  - "영향 범위 조사 문서"
  - "task-docs"
  - "작업 문서 만들"
  - "작업 시작"
  - "working 문서"
  - "단일 통합 문서"
  - "unified 산출물"
  - "작업 완료"
  - "작업 완료 정리"
  - "tasks 이동"
  - "working 정리"
  - "backlog 추가"
  - "backlog 작성"
  - "backlog 완료"
  - "backlog 정리"
  - "backlog 이동"
  - "/backlog-done"
  - "SDP 작성"
  - "SRS 작성"
  - "SDD 작성"
  - "IDD 작성"
  - "STP 작성"
  - "STD 작성"
  - "/분석"
  - "/타당성"
  - "/계획"
  - "/실행"
  - "/검증"
  - "/리뷰"
  - "/배포"
  - "/회고"
version: 5.1.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Task Docs Skill

> **호출 방식:** 슬래시 — `/plan` (계획 문서) / `/research` (리서치 문서) / `/task-docs` (일반 진입) / `/task-docs specs` (IEEE 산출물) / `/working-done` (working/ 완료 → tasks/ 이동). 자연어 — frontmatter `triggers` 키워드 (`플랜 작성`, `작업 시작`, `작업 완료`, `working 정리`, `분석 문서 작성`, `SDP/SRS/SDD/IDD/STP/STD 작성` 등) 매칭 시 자동 호출. 슬래시·자연어 모두 본문 §"산출물 네이밍 규칙" 과 §"working/ 단일 통합 워크플로우" 절차를 동일하게 따른다.

> **[신규 정책 2026-05-12 시행]** 코드 작업 산출물은 **단일 통합 문서 1개**로 작성·보존된다 (이전 3종 분리 정책 종료, 역소급 면제 적용).
> - **진행 중:** `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` (글로벌 통합, product 분리 없음)
> - **완료 후:** `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` (`working-lifecycle.sh` hook 자동 이동)
> - **역소급 면제:** 생성일 < 2026-05-12 = 3종 분리 (`-analyze.md` / `-plan.md` / `-result.md`) 그대로 보존
> - 상세 워크플로우는 본문 §"working/ 단일 통합 워크플로우" 참조

작업 문서(신규: unified 1개 / 기존: analyze+plan+result 3종)와 일일 요약(summary)을 표준 템플릿으로 생성·관리한다.
보고용 산출물은 `~/.claude/docs/{product}/output/{category}/{제목}/{파일명}.md` 형식으로, 소프트웨어 개발 산출물 6종(SDP, SRS, SDD, IDD, STP, STD)은 `~/.claude/docs/{product}/specs/` 디렉토리에 생성·관리한다.

**전역 문서 인덱스 (자동):** docs 하위 모든 .md(output/tasks/specs/working 등) 는 `~/.claude/docs/indexing/{product}.md` 전역 인덱스에 `doc-index-maintain.sh` PostToolUse hook 이 자동 등록한다(영역/타이틀/경로/수정일). 본 스킬이 작성하는 산출물도 별도 조치 없이 자동 인덱싱되므로 index 갱신을 수동으로 신경 쓰지 않는다. **직접 편집 금지**(자동 재생성). 정책 SSOT = CLAUDE.md §File Paths "indexing/{product}.md 전역 문서 인덱스".

**`{product}` 결정 규칙:** `basename $CWD`. 단 `.claude` 는 `claude-harness` 로 치환. 구현은 `hooks/lib/product-resolver.sh`. 예:
- `C:/Works/hongcafe_global_backend` → `hongcafe_global_backend`
- `C:/Works/infra` → `infra`
- `C:/Users/PV/.claude` → `claude-harness`

## 경로 선택 규칙 (`tasks/` vs `output/`)

프롬프트 성격에 따라 산출물 경로를 구분한다. 혼용 금지.

> **Why:** `tasks/` 와 `output/` 가 섞이면 일일 요약 자동화·gate 강제·history.md 인덱싱이 모두 깨져 작업 추적성과 산출물 정합성이 동시에 붕괴된다.

| 구분 | `tasks/` | `output/` |
|---|---|---|
| **트리거 프롬프트** | 코드 작성·수정·리팩토링·디버깅·기능 추가·설정 변경 등 **코드/설정에 변경을 일으키는 요청** | 분석·조사·비교·리포트·문서 정리 등 **코드 변경 없이 결과물만 산출하는 요청** |
| **예시 프롬프트** | "회원가입 API 만들어줘", "버그 고쳐줘", "이 메서드 리팩토링해줘", "훅 추가해줘" | "이번주 진행내용 리포트", "아키텍처 패턴 비교해줘", "SNS 플로우 문서로 정리해줘", "분석해줘" |
| **산출물 구조** | `YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-{analyze\|plan\|result}.md` | `{제목}/{yyyy-mm-dd}-{제목}-{type}.md` (주제별 폴더, 하위 파일 여러 개 가능) |
| **Workflow** | 3-Team Workflow (Analyze → Plan → Execute) 적용 | 3-Team 비적용, 단일/다중 문서로 완결 |
| **Gate 요구** | ≥ 2 (실행 계획 승인 필요) | ≥ 1 (분석 방향 승인) |
| **history.md 기록** | 필수 | 선택 (규모가 크거나 의사결정 영향이 있으면 기록) |
| **summary.md 기록** | 일일 요약에 필수 포함 | 보고용 산출물은 요약 대상 아님 |

**판단 지침:** "이 프롬프트가 코드/설정을 바꾸게 하는가?" → 예 = `tasks/`, 아니오 = `output/`. 분석 후 바로 구현으로 이어지는 혼합형은 `tasks/` 로 통합해 analyze.md 에 분석을 녹이고 result.md 에 구현 결과를 기록한다. 별도 `output/` 폴더를 만들지 않는다.

**specs/** 는 IEEE 공식 산출물(SRS/SDD/IDD/SDP/STP/STD) 전용 경로로, `tasks/` · `output/` 과 별개다.

## 산출물 네이밍 규칙

모든 문서 파일은 **`{yyyy-mm-dd}-` 날짜 prefix 를 필수로** 가지며, 제네릭 단독 이름(analysis.md, report.md 등)은 금지한다. `~/.claude/hooks/output-naming-check.sh` 가 PreToolUse:Write|Edit 에서 강제 차단한다.

> 상세 형식·금지 패턴·예시는 `references/file-naming.md` 참조.

## 공통 규칙

1. **날짜별·작업별 누적 보관한다** — 기존 파일을 덮어쓰지 않는다. 새 작업마다 새 서브디렉토리를 생성한다.
   > **Why:** 덮어쓰기 허용 시 이전 작업의 분석·계획·결정 근거가 영구 소실되어, 회귀·재발 시 동일 분석을 처음부터 다시 수행해야 하고 history.md/summary.md 인덱싱이 깨진다.
2. **보고용 문서 산출물:** 사용자 요청 보고서는 `~/.claude/docs/{product}/output/{제목}/{yyyy-mm-dd}-{제목}-{type}.md` 형식으로 생성. `~/.claude/docs/{product}/tasks/`와 혼용하지 않는다.
   > **Why:** `tasks/` 와 `output/` 혼용 시 일일 요약 자동화·gate 강제·3-Team Workflow 적용 여부 판정이 모두 깨져 산출물 분류·승인 절차가 동시에 붕괴된다.
3. `{작업명}`은 작업 내용을 간결하게 표현하는 kebab-case 이름으로 한다 (예: `pay-refactor`, `callee-migration`).
4. `YYYYMMDD`는 폴더명용 작업 시작일(예: `20260324`), `{yyyy-mm-dd}`는 파일명 prefix 용 ISO-8601 표기(예: `2026-03-24`). 두 형식이 같은 날짜를 가리키도록 일치시킨다.
   > **Why:** 두 형식이 어긋나면 `ls` 시간순 정렬·grep 검색·hook 정합성 검증이 모두 깨져 동일 작업의 폴더·파일 매핑이 수동 처리로 회귀한다.
5. 사용자에게 보고하는 동시에 파일에도 동일 내용을 기록한다. 채팅으로만 보고하고 파일 생성을 누락하는 것은 지침 위반이다.
   > **Why:** 채팅 컨텍스트는 압축·세션 종료 시 휘발하므로, 파일로 영속화되지 않은 산출물은 history.md/summary.md 인덱싱과 추후 재개 시 복원 매체가 될 수 없다.
5b. **사용자 보고용 경로는 OS 정합 형식으로 변환한다.** Windows = 백슬래시 + 절대 경로 (`C:\Users\PV\.claude\docs\...`), POSIX = forward slash + 홈 표기 (`~/.claude/docs/...`). 산출물 경로 보고 / `tasks/`·`output/`·`specs/` 위치 안내 / 단계 문서 경로 출력 등 사용자에게 노출되는 모든 경로에 적용. Bash 도구 `command` 파라미터·Glob/Grep 패턴은 POSIX 그대로 (도구 내부용). 글로벌 CLAUDE.md §4.4 "경로 안내 형식 (OS 정합)" SSOT.
6. **팀 간 산출물 체이닝:** 다단계 작업에서 Team 2는 `analyze.md`를 Read한 뒤 기반으로 plan을 작성하고, Team 3는 `plan.md`를 Read한 뒤 기반으로 실행한다. 단, 분석 단독/소규모 작업은 단일 문서(예: `analyze.md`만, 또는 `result.md`만)로 완결할 수 있다. 작업 규모에 맞는 단계만 작성한다.
   > **Why:** Team 2/3가 선행 산출물 Read 없이 자체 컨텍스트로 진행하면 분석 단계의 트레이드오프·리스크 식별이 계획·실행에 반영되지 않아 동일 결론을 매 팀마다 재도출하는 비용이 발생하고, 의사결정 근거가 팀별로 분기된다.
7. **체크리스트 최대 생성 원칙:** 모든 문서(analyze, plan, result)에 검증 가능한 체크리스트(`- [ ]`)를 최대한 생성한다. 분석 항목, 작업 단계, 검증 조건, 보안 점검, 테스트 케이스 등 체크박스로 표현 가능한 항목은 전부 체크리스트로 작성한다. 서술형 나열보다 체크리스트를 우선한다.
   > **Why:** 서술형 나열은 후속 팀이 "어떤 항목이 끝났는지" 명확히 판정할 수 없어 누락·중복 작업을 유발하지만, 체크박스는 `- [x]`/`- [ ]` 상태 토글만으로 진행 상황·잔여 항목을 자동 추적 가능한 단일 매체가 된다.
8. **이전 문서 체크리스트 소거 의무:** 이전 팀 산출물을 참조하여 실행하는 팀은, 해당 문서의 체크리스트를 검증 후 체크 표시(`- [x]`)하고 판단 근거를 기록한다. 구체적으로:
   - **Team 2 (Plan):** `analyze.md`의 체크리스트를 읽고, plan 수립 시 반영 여부를 `analyze.md`에 직접 체크한다. (`- [x] 항목 — plan에 반영` 또는 `- [x] 항목 — 해당 없음 (사유)`)
   - **Team 3 (Execute):** `plan.md`의 체크리스트를 읽고, 실행 완료된 항목을 `plan.md`에 직접 체크한다. (`- [x] 항목 — 완료 (커밋 해시)` 또는 `- [x] 항목 — 스킵 (사유)`)
   - **Result 작성 시:** `result.md`의 Self-Critique 체크리스트는 Team 3 완료 후 자체 검증하며 체크한다.
   - 체크되지 않은 항목(`- [ ]`)이 남아있으면 잔여 이슈로 명시한다. 미체크 항목을 무시하고 넘어가는 것은 지침 위반이다.
   > **Why:** 이전 단계 체크리스트를 소거하지 않으면 plan→execute 사이에서 어떤 항목이 의식적으로 스킵됐고 어떤 게 단순 누락인지 구분할 수 없어, 잔여 이슈가 다음 사이클로 침묵 전이된다.
9. **기존 문서 수정 시 변경 로그 필수:** 이미 존재하는 문서를 수정할 때는 문서 마지막에 변경 로그를 추가한다. 변경 로그가 없으면 새로 생성하고, 있으면 행을 추가한다. 변경 로그 없이 기존 문서를 수정하는 것은 지침 위반이다.
   > **Why:** 변경 로그 없이 산출물을 덮어쓰면 누가 언제 무엇을 바꿨는지 추적이 불가능해 IEEE 적합성·승인 이력 검증이 깨지고, 회귀 시 원상 복구 근거가 사라진다.
   ```markdown
   ## 변경 로그
   | 날짜 | 내용 |
   |------|------|
   | YYYY-MM-DD | {변경 내용 요약} |
   ```
10. **문서 메타데이터 헤더 필수:** 모든 문서 생성 시 상단에 YAML 프론트매터 형식의 메타데이터를 포함한다. 문서 유형에 따라 필수/선택 필드가 다르며, 메타데이터 없는 문서 생성은 지침 위반이다.
    > **Why:** 메타데이터(문서 ID·버전·상태·생성일)는 grep·jq 자동 인덱싱·재검토 상태 전이의 단일 키이며, 누락 시 산출물 분류·승인 이력·연관 문서 매핑이 모두 수동 처리로 회귀한다.
    ```markdown
    ---
    문서명: {문서 제목}
    문서 ID: {파일명 기반 식별자, 예: auth-sdd, commerce-srs}
    버전: v1.0
    상태: 초안 | 검토중 | 승인됨
    생성일: YYYY-MM-DD
    최종 수정일: YYYY-MM-DD
    작성자: jypark
    검토자: {검토자, 해당 시}
    승인자: {승인자, 해당 시}
    대상 시스템: {모듈/BC명, 해당 시}
    관련 문서: {참조 문서 목록, 해당 시}
    ---
    ```
    **문서 유형별 필수 필드:**
    | 필드 | specs (SDP/SRS/SDD/IDD/STP/STD) | tasks (analyze/plan/result) | output (보고서) |
    |------|:-:|:-:|:-:|
    | 문서명 | ● | ● | ● |
    | 문서 ID | ● | — | — |
    | 버전 | ● | — | — |
    | 상태 | ● | ● | ● |
    | 생성일 | ● | ● | ● |
    | 최종 수정일 | ● | ● | ● |
    | 작성자 | ● | ● | ● |
    | 검토자 | ○ | — | ○ |
    | 승인자 | ○ | — | ○ |
    | 대상 시스템 | ● | ● | ○ |
    | 관련 문서 | ● | ○ | ○ |
    > ● 필수, ○ 선택(해당 시), — 불필요
    - **작성자 기본값:** 프로젝트 소유자는 `jypark`(박재영)이다. 별도 지정 없으면 작성자는 `jypark`으로 기입한다.
    - **기존 문서 수정 시:** `최종 수정일`을 갱신하고, specs 문서는 `버전`도 함께 올린다.
    - **상태 전이:** 초안 → 검토중 → 승인됨. 상태 변경 시 변경 로그(규칙 9)에도 기록한다.
11. **산출물 작성 첫 단계 = SSOT 헤더 골격 prepend 의무 (필수, 2026-05-11):** Write 도구로 `analyze.md` / `plan.md` / `result.md` 파일을 생성할 때 첫 단계로 `references/{analyze,plan,result}-template.md` 의 SSOT 헤더 골격을 그대로 복사·prepend 한 뒤 의미를 채운다. 자체 번호 헤더 (`## 2. 변경 범위`, `## 6. 변경 영향 기록` 등) 로 의미만 통합하는 자유 형식 작성은 hook 검증 우회로 간주되어 `doc-template-guard.sh` / `checklist-count-check.sh` 두 hook 가 PostToolUse exit 2 로 hard 차단한다.
    > **Why:** 2026-05-11 audit (claude-harness / hongcafe_global_backend / infra 일주일치 79건) 결과 비면제 산출물의 plan 100% 가 SSOT 정확 헤더 (`## 수정 대상`·`## Blueprint`·`## 작업 분해 (WBS)`·`## 실행 계획`) 를 우회한 자유 형식으로 작성되어 의미 일관성은 부분 보존되었으나 hook·grep·자동 검증 정합이 깨졌다. checklist hook 이 exit 0 (경고) 에 머물러 체크리스트 0건 plan 22건 누적 발생. SSOT 골격 우선 prepend 로 작성 시점 비용을 1회 들이고, 의미 채우기는 그 위에 올린다.
    > **위반 사례 (2026-05-11 audit):**
    > - `hongcafe_global_backend/tasks/20260511/mod-02-* batch (16건)/...-plan.md` — SSOT 헤더 무시, 자체 번호 헤더로 자유 작성
    > - `hongcafe_global_backend/tasks/20260507/{member-p1-1-alarm-home,p2-mypage-p2-p4-extend,spec-audit-fix-batch2}/...-result.md` — result 6섹션 전부 누락 + 체크리스트 0건
    > - `claude-harness/tasks/20260511/harness-cleanup/...-plan.md` — 압축형 자유 작성, 7개 섹션 헤더 미사용
    > - `infra/tasks/20260511/fe-cleanup-bugfix/...-{analyze,plan,result}.md` — 모든 강제 헤더 + 체크리스트 0건
    > **강제 hook (PostToolUse):**
    > - `doc-template-guard.sh` — analyze 12 헤더 / plan 11 헤더 / result 6 헤더 + Status 그룹 grep, 미충족 시 `[BLOCKED]` + exit 2
    > - `checklist-count-check.sh` — analyze≥30 / plan≥20 / result≥20, 미달 시 `[BLOCKED]` + exit 2 (역소급 면제: 생성일 < 2026-05-07 산출물은 hint 강등)
    > - `change-impact-section-check.sh` / `feasibility-section-check.sh` — 변경 영향 / 타당성 검토 섹션 추가 강제

## 파일 경로

모든 산출물은 **글로벌 루트** `~/.claude/docs/` 하위에 생성한다. 프로젝트 레포 내부에는 생성하지 않는다.

```
~/.claude/docs/
├── working/                          ← **신규 2026-05-12~** (진행 중 단일 통합, product 분리 없음 — 글로벌 통합)
│   └── YYYYMMDD/
│       └── {yyyy-mm-dd}-{product}-{작업명}.md   ← 분석+계획+실행 통합, 완료 시 tasks/ 자동 이동
└── {product}/
    ├── tasks/
    │   ├── history.md                ← 전체 이력 인덱스 (YYYY.MM.DD 항목)
    │   └── YYYYMMDD/
    │       ├── summary.md            ← 일일 작업 요약
    │       └── {작업명}/
    │           ├── {yyyy-mm-dd}-{작업명}-unified.md           ← **신규 2026-05-12~** (working/ 자동 이동, 단일 통합 보존)
    │           ├── {yyyy-mm-dd}-{작업명}-analyze.md           ← (역소급 < 2026-05-12) Team 1 분석 결과
    │           ├── {yyyy-mm-dd}-{작업명}-plan.md              ← (역소급 < 2026-05-12) Team 2 계획 + Blueprint
    │           └── {yyyy-mm-dd}-{작업명}-result.md            ← (역소급 < 2026-05-12) Team 3 완료 결과
    ├── output/
    │   └── {category}/{제목}/        ← 보고용 산출물 (kebab-case 주제별 폴더)
    │       └── {yyyy-mm-dd}-{제목}-{type}.md   ← 날짜 prefix 필수
    └── specs/                        ← 소프트웨어 개발 산출물 (SDP/SRS/SDD/IDD/STP/STD)
        └── {모듈}-{문서타입}.md
```

`{product}` 변환은 `hooks/lib/product-resolver.sh` 를 참조한다. bash 에서:
```bash
source ~/.claude/hooks/lib/product-resolver.sh
PRODUCT=$(resolve_product "$PWD")
DOCS=$(product_docs_root "$PWD")      # ~/.claude/docs/$PRODUCT
TASKS=$(product_tasks_dir "$PWD")     # ~/.claude/docs/$PRODUCT/tasks
```

---

## 단계별 산출물 — 본문은 references/ 분리

각 단계 문서의 상세 템플릿·체크리스트·예시는 references/ 파일에 분리됐다. 본문 작성 전 해당 references 파일을 정독 후 그대로 따른다.

| 정책 | 파일명 | 용도 | references |
|---|---|---|---|
| **신규 Unified (2026-05-12~)** | (진행) `working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` → (완료) `tasks/.../{yyyy-mm-dd}-{작업명}-unified.md` | 분석 + 계획 + 실행 단일 통합 (체크리스트 ≥ 50). working-lifecycle.sh hook 자동 이동 | `references/unified-template.md` |
| **역소급 1. Analyze** | `{yyyy-mm-dd}-{작업명}-analyze.md` | (< 2026-05-12 보존) Team 1 분석 결과 (이슈 4단계 분류, 체크리스트 ≥ 30) | `references/analyze-template.md` |
| **역소급 2. Plan** | `{yyyy-mm-dd}-{작업명}-plan.md` | (< 2026-05-12 보존) Team 2 실행 계획 + Blueprint + WBS (체크리스트 ≥ 20) | `references/plan-template.md` |
| **역소급 3. Result** | `{yyyy-mm-dd}-{작업명}-result.md` | (< 2026-05-12 보존) Team 3 완료 결과 + Self-Critique ≥ 20 + 잔여 이슈 | `references/result-template.md` |

---

## working/ 단일 통합 워크플로우 (2026-05-12 시행, 필수)

> **SSOT:** 본 섹션 + `~/.claude/CLAUDE.md` §File Paths "working/ 단일 통합 문서" + `~/.claude/hooks/working-lifecycle.sh` (자동 이동 강제) + `~/.claude/commands/working-done.md` (수동 진입점) + `~/.claude/skills/task-docs/references/unified-template.md` (양식 SSOT).

### 1. 작업 시작 — working/ 단일 통합 문서 생성

신규 코드 작업 프롬프트 수신 시 (의도 정리·Gate 통과 직후):
1. **작업명 결정** — kebab-case 영문 (예: `auth-refactor`, `working-folder-intro`)
2. **product 결정** — `basename $CWD` (`.claude` → `claude-harness` 치환)
3. **working 파일 생성** — `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 단일 파일 (하위 폴더 금지)
4. **SSOT 골격 prepend (필수)** — `references/unified-template.md` 전체를 그대로 복사·prepend 후 의미만 채움. 자체 번호 헤더로 자유 작성 = hook 차단 (`doc-template-guard.sh` exit 2)
5. **섹션 작성 순서** — `## 분석` → `## 계획` → `## 실행` (필요한 섹션만 채움 허용, 단일 파일 구조는 유지)

### 2. 진행 중 작성 — Gate / 양식 면제

- **Gate 면제:** working/ 경로는 `gate-enforce.sh` Gate-0 직행 면제 (`output/` 와 동일 정책 — CLAUDE.md §"output/ 경로 Gate-0 직행" 정합)
- **양식 면제 (진행 중):** `doc-template-guard.sh` working/ 경로 자체 면제 — 자유 양식 작성 허용. 양식 검증은 tasks/ 이동 후 `*-unified.md` 패턴으로 1회 발동
- **강제 (진행 중):** `output-naming-check.sh` — 파일명 prefix `{yyyy-mm-dd}-{product}-` 강제 + working/YYYYMMDD/ 직속 단일 파일 (하위 폴더 금지)

### 3. 작업 완료 — tasks/ 자동 이동 (OR 조건 트리거)

**트리거 1 — 본문 마커 자동 감지 (PostToolUse 자동):**
- `working-lifecycle.sh` PostToolUse hook 이 working/ 파일 저장 직후 다음 두 마커 동시 존재 검사:
  - `^Status:\s*Done` (시작 라인 패턴)
  - `## Self-Critique` 섹션 헤더 존재
- 둘 다 매칭 시 즉시 이동 절차 발동

**트리거 2 — 사용자 명시 키워드 (UserPromptSubmit / 슬래시):**
- 슬래시 `/working-done` 직접 호출
- 자연어 키워드 — `작업 완료` / `tasks 이동` / `working 정리` / `done` / `완료 저장`

**이동 절차:**
1. working/ 파일 → `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md`
2. tasks/ 폴더 미존재 시 `mkdir -p`
3. 동일 파일명 충돌 시 `.bak-{timestamp}` 백업 후 덮어쓰기 (역소급 3종 산출물과는 suffix `-unified` 로 자연 구분, 충돌 없음)
4. working/ 원본 제거 (진행 중 상태 마커 클린업)
5. `~/.claude/docs/{product}/tasks/history.md` + `~/.claude/docs/{product}/tasks/YYYYMMDD/summary.md` 자동 갱신
6. Claude 본체에 stderr 로 이동 결과 보고 (조용한 처리, 사용자 대기 없음)

### 4. 사후 hook 검증 (tasks/ 이동 후 1회 발동)

이동 후 `tasks/.../{yyyy-mm-dd}-{작업명}-unified.md` 에 대해:
- `doc-template-guard.sh` — `*-unified.md` 패턴 검증, 합집합 ≈ 20개 필수 헤더 (analyze 11 + plan 5 + result 4 — 통합 변경 영향 / 타당성 검토는 합쳐서 1회) 누락 시 `[BLOCKED]` exit 2
- `checklist-count-check.sh` — 체크리스트 `- [ ]` + `- [x]` 합산 ≥ 30 (통합 문서 강제 하한 — 2026-05-13 ≥50 완화, 통합 문서라 중복 제거 허용)
- `change-impact-section-check.sh` — `## 변경 영향` 섹션 + 3열 표(변경/개선/이유) 존재
- `feasibility-section-check.sh` — `## 타당성 검토` 헤더 + `[Source: <name> §<id>]` 인용 ≥ 1건
- 모두 통과 시 `tasks/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` 가 영구 보존 산출물로 확정

### 5. 역소급 호환 (생성일 < 2026-05-12)

기존 3종 분리 산출물 (`-analyze.md` / `-plan.md` / `-result.md`) 은:
- **그대로 보존** — 분해/통합 변환 없음
- **수정 시 변경 로그만 추가**, 통합 변환 금지 (의미 손실 방지)
- 신규 작업이 같은 작업명 폴더를 재사용해도 `-unified.md` 와 공존 가능 (파일명 suffix 로 자연 구분)
- 모든 hook 양쪽 패턴 (analyze/plan/result + unified) 인식, 둘 중 어느 쪽이든 통과 가능

### 6. 글로벌 통합 — product 식별

`~/.claude/docs/working/` 단일 디렉토리에 전 product 작업 동시 진행 가능. 파일명 prefix 로 식별:
- `2026-05-12-claude-harness-working-folder-intro.md` ← claude-harness (글로벌 harness) 작업
- `2026-05-12-hongcafe_global_backend-auth-refactor.md` ← be 작업
- `2026-05-12-infra-rds-migration.md` ← infra 작업

product 별 분리 디렉토리는 두지 않는다. **Why:** 단일 디렉토리 = "현재 진행 중인 모든 작업"을 OS 파일 탐색기·`ls`·hook 일괄 스캔 한 번으로 파악 가능 (분리 시 product 별 폴더 순회 비용 발생).

### 7. 워크플로우 다이어그램

```
[사용자 작업 지시]
    ↓
[Echo-Back Confirm + Gate 통과]
    ↓
[작업명 + product 결정]
    ↓
[Write: working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md]
    ↓ (unified-template.md SSOT 골격 prepend)
[Edit: ## 분석 채움 → ## 계획 채움 → ## 실행 채움]
    ↓
[완료 마커: Status: Done + ## Self-Critique 작성]
    ↓ (또는 사용자 "작업 완료" 키워드 / /working-done 호출)
[working-lifecycle.sh PostToolUse hook 자동 발동]
    ↓
[tasks/YYYYMMDD/{작업명}/ 폴더 생성 → mv → working/ 원본 제거]
    ↓
[history.md + summary.md 자동 갱신]
    ↓
[doc-template-guard / checklist-count / change-impact / feasibility 사후 검증 1회]
    ↓
[영구 보존: tasks/.../{yyyy-mm-dd}-{작업명}-unified.md]
```

---

### 등급별 플랜 구성 (Plan 단계)

| 등급 | Plan 내용 | Team 3 구성 |
|------|----------|------------|
| **S** | 간략 (목표 + 수정 대상) | Lead + Worker 1 + Reviewer |
| **M** | 표준 (목표 + Blueprint + WBS) | Lead + Worker 2 + Reviewer + Tester |
| **L** | 상세 (전체 템플릿) | Lead + Worker 3 + Reviewer + Tester + Security + Performance |

### 이슈 등급 기준 (Analyze 단계)

| 등급 | 기준 | 예시 |
|------|------|------|
| **Critical** | 즉시 수정 필수. 보안 취약점, 데이터 유실, 시스템 장애 | SQL Injection, 시크릿 노출, 레이어 역전 |
| **High** | 릴리스 전 수정. 기능 결함, 아키텍처 위반 | 보안 필터 미적용, try-catch 미적용 |
| **Medium** | 권장 수정. 코드 품질, 유지보수성, 성능 | DI 미적용, 중복 코드, N+1 쿼리 |
| **Low** | 선택적 개선. 네이밍, 문서화, 코드 스타일 | PHPDoc 누락, 미사용 코드 |

> **비필수 사이드이펙트 백로그 격리 (등급 부여 전 사전 필터):** 위 4등급을 부여하기 전에 — 발견 항목이 **① 필수요소 아님 + ② 실제 문제·버그 아님 + ③ 사이드이펙트급** 3조건을 **모두** 충족하면 Critical~Low 행을 부여하지 말고 backlog 메모리에만 기록한다 (아래 §"backlog 메모리 워크플로우"). 하나라도 불충족 = 정상 등급 부여. **실제 버그는 경미해도 Low 로라도 분류하지 backlog 로 미루지 않는다.** SSOT = CLAUDE.md §4.5 "비필수 사이드이펙트 백로그 격리".

---

## backlog 메모리 워크플로우

> SSOT = CLAUDE.md §4.5 "backlog 메모리 정책" + "비필수 사이드이펙트 백로그 격리" + `hooks/backlog-lifecycle.sh`. 본 섹션은 task-docs 진입점에서의 운영 요약이다 (CLAUDE.md 가 참조하는 SSOT 섹션).

본 세션의 **잔여 후속 / 시간 트리거 / 사용자 결정 보류** 작업, 그리고 **코드 작업 중 발견한 비필수·무해·사이드이펙트급 항목**은 working/ 문서·산출물·코드 TODO 로 끌어올리지 않고 backlog 메모리 단일 파일에 격리 기록한다.

### 파일 양식

- 경로: `~/.claude/projects/C--Users-PV--claude/memory/backlog_{slug}.md` (단일 파일, slug = kebab-case)
- frontmatter: `name` / `description` (1줄) / `type: backlog` / `status: pending|in_progress|done` / `source` / `target_date` (선택) / `product` (기본 claude-harness) / `created` / `completed` (status=done 시 hook 자동 채움)
- MEMORY.md `## Backlog` 섹션에 entry 1줄 추가 필수 — `- [slug](backlog_{slug}.md) — 한 줄 요약`
- **별도 경량 backlog 신설 금지** — 본 양식 외 임시 메모·인라인 TODO 로 대체하지 않는다.

### 비필수 사이드이펙트 격리 판단 (코드 작업 중, CLAUDE.md §4.5)

코드 작업(`/분석`·`/계획`·`/실행`·`/검증`·`/리뷰`) 중 발견한 항목을 다음 표로 판정한다.

| 조건 | 판정 |
|------|------|
| **① 현재 작업 필수요소 아님 + ② 실제 문제·버그 아님 + ③ 사이드이펙트급(부수적·경미)** — 3조건 **모두** 충족 | **backlog 에만 기록** 후 현재 작업 계속 (등급 행·step·즉시 수정 금지) |
| 3조건 중 **하나라도 불충족** | 본 규칙 비대상 — `/분석` Critical~Low 정상 분류·처리 |
| **실제 버그·문제** (경미해 보여도) | **backlog 금지** — 정상 처리 (②가 안전장치) |
| **§3 Checkpoint 매칭** | 크기·필수성 무관 사용자 보고 (본 규칙과 무관) |

> **Why:** 비필수·무해 항목을 본 작업에 끌어들이면 스코프 크리프 + 산출물 노이즈 + 집중 분산. backlog 격리 = 추적 보존 + 현재 작업 순도 유지. judgment 룰이라 hook 기계 강제 불가 — 격리 판단은 Claude 본체.

### 완료 → tasks/ 자동 이동

- `status: done` 마커 → `backlog-lifecycle.sh` (PostToolUse) 가 `~/.claude/docs/{product}/tasks/{YYYYMMDD}/backlog/{yyyy-mm-dd}-{slug}.md` 로 자동 이동 + MEMORY.md entry 제거 + history.md / summary.md 갱신
- 사용자 명시 키워드 (`backlog 완료` / `backlog 정리` / `backlog 이동` / `/backlog-done`) → memory 디렉토리 일괄 스캔 이동
- §3 Checkpoint 우선 적용

---

# Part 4. Context Persistence 연동

컨텍스트 압축이 임박할 때, 작업 문서(analyze.md, plan.md, result.md)가 **진행 상황 복원의 핵심 매체** 역할을 한다.

- **즉시 기록 원칙:** 각 팀 산출물은 팀 완료 즉시 파일에 기록한다. 메인 컨텍스트에만 보관하고 파일 생성을 미루지 않는다.
- **복원 시 활용:** 컨텍스트 압축 후 재개 시, 메모리에 저장된 "현재 단계 + 산출물 경로"를 읽고, 해당 파일을 Read하여 작업을 이어간다.

---

# Part 5. 소프트웨어 개발 산출물 — IEEE 표준 기반 (~/.claude/docs/{product}/specs/)

소프트웨어 개발 산출물 6종(SDP, SRS, SDD, IDD, STP, STD)을 `~/.claude/docs/{product}/specs/` 디렉토리에 플랫하게 관리한다.
보고용 산출물은 `~/.claude/docs/{product}/output/{제목}/{파일명}.md` 형식으로 주제별 폴더에 저장한다.

### 적용 표준

| 산출물 | 적용 표준 | 비고 |
|--------|----------|------|
| SDP | IEEE/ISO/IEC 12207:2017 + PMBOK | 프로젝트 전체 (1회성) |
| SRS | **IEEE/ISO/IEC 29148:2018** | 모듈(BC)별 |
| SDD | **IEEE 1016-2009** (Multi-Viewpoint) | 모듈(BC)별 |
| IDD | **MIL-STD-498 DI-IPSC-81436** | 모듈(BC)별 또는 시스템 간 |
| STP | **IEEE 29119-3:2021** | 프로젝트 전체 (1회성) |
| STD | **IEEE 829-2008** | 모듈(BC)별 |

## 공통 규칙

1. **단일 디렉토리:** 모든 산출물은 `~/.claude/docs/{product}/specs/`에 저장한다. 문서 타입별 하위 폴더를 만들지 않는다.
2. **파일 네이밍:** `{모듈 또는 주제}-{문서타입}.md` (kebab-case)
   - 예: `auth-srs.md`, `commerce-idd.md`, `project-sdp.md`, `project-stp.md`, `auth-std.md`
3. **Glob 패턴으로 타입별 조회 가능:** `specs/*-srs.md`, `specs/*-sdd.md` 등
4. **기존 파일 덮어쓰기 허용:** specs 문서는 요구사항·설계 변경 시 갱신한다. (tasks 문서와 다름)
5. **버전 관리:** 문서 상단 `version`과 `lastUpdated` 필드로 변경 이력을 추적한다.
6. **3회 IEEE 적합성 재검토 필수:** 문서 생성/갱신 후 반드시 Part 6의 3-Round Review를 수행한다. 재검토 미수행은 지침 위반이다.
   > **Why:** SRS↔SDD↔IDD 3종 문서는 상호 참조가 정합해야 추적성 매트릭스가 성립하며, 단일 패스 작성에 의존하면 누락 섹션·placeholder·교차 불일치가 그대로 "승인됨" 상태로 굳어진다.

---

## IEEE 산출물 본문 — references 분리

> **본문 작성 전 필수:** 각 산출물(SDP/SRS/SDD/IDD/STP/STD) 의 상세 템플릿·체크리스트는 아래 references 파일에서 정독 후 그대로 따른다. SKILL.md 본문에는 분리됨.
>
> | Type | 표준 | references 파일 |
> |---|---|---|
> | SDP | IEEE/ISO 12207 | `references/ieee-sdp.md` |
> | SRS | IEEE 29148:2018 | `references/ieee-srs.md` |
> | SDD | IEEE 1016-2009 Multi-Viewpoint | `references/ieee-sdd.md` |
> | IDD | MIL-STD-498 DI-IPSC-81436 | `references/ieee-idd.md` |
> | STP | IEEE 29119-3:2021 | `references/ieee-stp.md` |
> | STD | IEEE 829-2008 | `references/ieee-std.md` |
>
> IEEE 산출물 트리거 조건(언제 어떤 문서를 생성/갱신할지)은 `references/ieee-idd.md` 끝의 트리거 조건 표 참조.

---

# Part 6. 3-Round IEEE 적합성 재검토

소프트웨어 개발 산출물(SDP/SRS/SDD/IDD/STP/STD) 생성 또는 갱신 후, **반드시 3회 재검토를 수행한다**. 재검토를 거치지 않은 산출물은 "초안" 상태로 간주하며, "승인됨" 상태로 전환할 수 없다.

| Round | 검증 영역 | 통과 기준 |
|---|---|---|
| **Round 1** | 구조 검증 (IEEE 필수 섹션 존재 여부) | 모든 필수 섹션 존재 + 빈 섹션 없음 |
| **Round 2** | 내용 검증 (Verification/Traceability + 내용 깊이 + Design Overlay) | 모든 체크 항목 통과. 1건 미통과 시 보강 후 재수행 |
| **Round 3** | 상호 참조 일관성 (SRS ↔ SDD ↔ IDD) | 모든 체크 항목 통과. 불일치 발견 시 원인 문서 수정 후 재수행 |

3회 재검토 완료 후 문서의 프론트매터 `상태`를 `초안` → `승인됨`으로 변경하고, 변경 로그에 Round 1/2/3 PASS 기록을 추가한다. 재검토 미수행 또는 미통과 상태에서 "승인됨"으로 상태 전환하는 것은 지침 위반이다.

> 각 Round 의 상세 체크리스트(SRS/SDD/IDD 구조·내용·상호참조 항목)는 `references/ieee-review-3round.md` 참조.
