---
name: task-docs
description: >
  작업 문서 생명주기(분석→계획→결과)를 ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/ 디렉토리에 표준 템플릿으로 생성한다.
  일일 작업 요약을 ~/.claude/docs/{product}/tasks/YYYYMMDD/summary.md에, 전체 이력을 ~/.claude/docs/{product}/tasks/history.md에 기록한다.
  모든 문서 파일은 `{yyyy-mm-dd}-{작업명}-` prefix 를 필수로 가진다 (예: 2026-04-27-pay-refactor-analyze.md). 단계 문서는 analyze, plan, result 3종.
  보고용 산출물은 ~/.claude/docs/{product}/output/{제목}/{파일명}.md에, 소프트웨어 개발 산출물(SDP/SRS/SDD/IDD/STP/STD)은 ~/.claude/docs/{product}/specs/에 생성·관리한다.
  {product}는 basename $CWD (.claude→claude-harness 예외). 규칙은 글로벌 CLAUDE.md §File Paths 참조.
triggers:
  - "/plan"
  - "/research"
  - "플랜 작성", "계획 세워줘"
  - "리서치 해줘", "분석 해줘", "코드 분석", "영향 범위 조사"
  - 3-Team 워크플로우의 Team 1(Analyze), Team 2(Plan), Team 3(Execute) 완료 시 자동 적용
  - "/task-docs specs", "SDP 작성", "SRS 작성", "SDD 작성", "IDD 작성", "STP 작성", "STD 작성"
version: 4.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Task Docs Skill

작업 문서 3종(analyze, plan, result)과 일일 요약(summary)을 `~/.claude/docs/{product}/tasks/YYYYMMDD/` 디렉토리에 표준 템플릿으로 생성·관리한다.
보고용 산출물은 `~/.claude/docs/{product}/output/{제목}/{파일명}.md` 형식으로, 소프트웨어 개발 산출물 6종(SDP, SRS, SDD, IDD, STP, STD)은 `~/.claude/docs/{product}/specs/` 디렉토리에 생성·관리한다.

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
2. **보고용 문서 산출물:** 사용자 요청 보고서는 `~/.claude/docs/{product}/output/{제목}/{yyyy-mm-dd}-{제목}-{type}.md` 형식으로 생성. `~/.claude/docs/{product}/tasks/`와 혼용하지 않는다.
3. `{작업명}`은 작업 내용을 간결하게 표현하는 kebab-case 이름으로 한다 (예: `pay-refactor`, `callee-migration`).
4. `YYYYMMDD`는 폴더명용 작업 시작일(예: `20260324`), `{yyyy-mm-dd}`는 파일명 prefix 용 ISO-8601 표기(예: `2026-03-24`). 두 형식이 같은 날짜를 가리키도록 일치시킨다.
5. 사용자에게 보고하는 동시에 파일에도 동일 내용을 기록한다. 채팅으로만 보고하고 파일 생성을 누락하는 것은 지침 위반이다.
   > **Why:** 채팅 컨텍스트는 압축·세션 종료 시 휘발하므로, 파일로 영속화되지 않은 산출물은 history.md/summary.md 인덱싱과 추후 재개 시 복원 매체가 될 수 없다.
6. **팀 간 산출물 체이닝:** 다단계 작업에서 Team 2는 `analyze.md`를 Read한 뒤 기반으로 plan을 작성하고, Team 3는 `plan.md`를 Read한 뒤 기반으로 실행한다. 단, 분석 단독/소규모 작업은 단일 문서(예: `analyze.md`만, 또는 `result.md`만)로 완결할 수 있다. 작업 규모에 맞는 단계만 작성한다.
7. **체크리스트 최대 생성 원칙:** 모든 문서(analyze, plan, result)에 검증 가능한 체크리스트(`- [ ]`)를 최대한 생성한다. 분석 항목, 작업 단계, 검증 조건, 보안 점검, 테스트 케이스 등 체크박스로 표현 가능한 항목은 전부 체크리스트로 작성한다. 서술형 나열보다 체크리스트를 우선한다.
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

## 파일 경로

모든 산출물은 **글로벌 루트** `~/.claude/docs/{product}/` 하위에 생성한다. 프로젝트 레포 내부에는 생성하지 않는다.

```
~/.claude/docs/{product}/
├── tasks/
│   ├── history.md                    ← 전체 이력 인덱스 (YYYY.MM.DD 항목)
│   └── YYYYMMDD/
│       ├── summary.md                ← 일일 작업 요약
│       └── {작업명}/
│           ├── {yyyy-mm-dd}-{작업명}-analyze.md   ← Team 1 (Analyze) 분석 결과
│           ├── {yyyy-mm-dd}-{작업명}-plan.md      ← Team 2 (Plan) 실행 계획 + Blueprint
│           └── {yyyy-mm-dd}-{작업명}-result.md    ← Team 3 (Execute) 완료 결과
├── output/
│   └── {제목}/                                    ← 보고용 산출물 (kebab-case 주제별 폴더)
│       └── {yyyy-mm-dd}-{제목}-{type}.md          ← 날짜 prefix 필수
└── specs/                            ← 소프트웨어 개발 산출물 (SDP/SRS/SDD/IDD/STP/STD)
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

| 단계 | 파일명 | 용도 | references |
|---|---|---|---|
| **1. Analyze** | `{yyyy-mm-dd}-{작업명}-analyze.md` | Team 1 분석 결과 (이슈 4단계 분류, 트레이드오프, 분석 체크리스트 ≥ 30) | `references/analyze-template.md` |
| **2. Plan** | `{yyyy-mm-dd}-{작업명}-plan.md` | Team 2 실행 계획 + Blueprint + WBS (실행 전 체크리스트 ≥ 20). 사용자 승인 후 Team 3 진입 | `references/plan-template.md` |
| **3. Result** | `{yyyy-mm-dd}-{작업명}-result.md` | Team 3 완료 결과 + Self-Critique 체크리스트 ≥ 20 + 잔여 이슈 | `references/result-template.md` |

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
