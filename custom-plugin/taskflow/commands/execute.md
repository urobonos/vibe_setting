---
description: 실행 단계 진입 — §계획 step 인덱스를 step-01부터 순차 소비 + step별 상태 마킹 + working/ §실행 채움 + Self-Critique + QA 게이트(외부 참조 문서 존재 시 — 변경분 ↔ 문서 대조 단일 subagent, fail-closed) + Status 판정. Status: Done + ## Self-Critique 동시 시 working-lifecycle.sh 자동 발동 → tasks/ 이동 (unified + steps/ 분배).
allowed-tools: Bash, Edit, Write, MultiEdit, Read, Glob, Grep, Skill, Agent, PowerShell
argument-hint: "[작업명]  # 생략 시 진행 중 working/ 문서 식별"
---

실행 단계 진입 — working/ §계획 완료 후 **step 인덱스를 순차 소비**하며 실제 코드 변경을 수행하고, step별 상태를 마킹한 뒤 working/ §실행 섹션 + Self-Critique 작성 → **QA 게이트(외부 참조 문서 존재 시 — 변경분 ↔ 외부 문서 대조 단일 subagent)** 통과/skip 후 Status 판정.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 가장 최근 working/ 파일 자동 식별.

## 참조 범위 (사전 전수 조사, 필수)

진입 즉시 CLAUDE.md §4.3 "참조 범위 전수 조사" 절차(3 출처 전수 조사)를 수행하고, §4.4 위치 표기로 참조 결과 표를 화면 출력한 뒤 다음 단계로 진입한다. 3 출처 표·가시화 표 양식·`해당 없음` 행 생략 금지·직전 단계 sweep 재사용 규칙 = 모두 §4.3 SSOT.

- **등급 비례:** S = ② index 스캔만 / M·L = ①②③ 전수.

## 동작 5단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① working/ 문서 식별 + step 인덱스 확인 | 인자 매칭 또는 가장 최근 working/ 파일. `Status: Plan Complete` 마커 + §계획 "Step 분해" 인덱스 표 + step 평면 파일 존재 확인 | 대상 파일 + step 목록 |
| ② **step 순차 소비 루프** | step 인덱스가 있으면 step-01부터 의존 순서대로 소비 (아래 §"step 순차 소비"). 인덱스 없으면 §계획 수정 대상 표 순차 실행 (기존 동작) | 변경 적용 + step별 상태 마킹 |
| ③ §실행 섹션 채움 | 실행 요약 / 변경 내역 / Before/After 대조 / 테스트 결과 / 잔여 이슈 / 롤백 | Self-Critique ≥ 20 채움 (CLAUDE.md §4.3 "doc-unified-check.sh V4 임계" SSOT) |
| **③.5 QA 게이트 (조건부)** | **외부 참조 문서 존재 시에만** — worktree 변경분(신규 파일 포함) ↔ 외부 문서를 단일 subagent 가 대조 (아래 §"QA 게이트"). 외부 문서 없으면 skip. Status 마킹 *전* | **PASS / skip → ④ 진행 / FAIL → §잔여 이슈 + Status: Partial** |
| ④ Status 판정 | **QA PASS 또는 skip(사유 기록)** + 전 step Done = `Status: Done` (최후 write) / QA FAIL 또는 일부 step 미완 = `Status: Partial` + `## 잔여 작업` 섹션 (미완 step·QA findings 명시) | 자동 이동 트리거 또는 working/ 유지 |

> **터미널 제목 설정 (① 직후):** working/ 문서 식별로 작업명이 확정되면 PowerShell 도구로 `$Host.UI.RawUI.WindowTitle = "#{작업명}"` 실행 (예: `#auth-refactor`). 방식·전제·OS·실패 처리 = `custom-plugin/taskflow/commands/load.md` §"터미널 제목 설정 (SSOT)".

> **비필수 사이드이펙트 백로그 격리:** 구현 중 발견한 (① 필수요소 아님 + ② 문제·버그 아님 + ③ 사이드이펙트급) 3조건 충족 항목은 즉시 수정·코드 TODO 로 끌어올리지 말고(스코프 크리프 차단) backlog 메모리에만 기록 후 현재 step 계속. 하나라도 불충족 = 정상 처리. **실제 버그는 경미해도 미루지 않음.** SSOT = CLAUDE.md §4.5 "비필수 사이드이펙트 백로그 격리".

## step 순차 소비 (단계 ②)

§계획 "Step 분해" 인덱스 표가 존재하면 step 을 **의존 순서대로 직렬 소비**한다. 각 step 처리 절차:

1. **선택:** 인덱스에서 상태 `Pending` 이고 선행 의존이 모두 `Done` 인 가장 낮은 번호 step 선택
2. **§3 게이트:** 해당 step 이 `Pending(승인 대기)` (§3 매칭) 이면 사용자 명시 승인 전까지 소비 금지 → 다음 진행 가능 step 으로 (없으면 중단)
3. **진입 마킹:** step 평면 파일 frontmatter `상태: Pending → In Progress`, unified 인덱스 표 상태 `In Progress`
4. **수행:** step 파일 `## 작업 내용` 체크리스트를 실제 변경(Edit/Write/MultiEdit/Bash)으로 처리, 완료 항목 `- [x]` 마킹. **풀사이클 step**(`## 분석(국소)`·`## 계획(접근)`·`## QA(자체 점검)`·`## 검증(국소 동작)` 보유 — plan.md §"풀사이클 step")이면: 진입 시 §분석·§계획 정독 → 개발 → §QA self-check `- [x]` → §검증 국소 동작 확인 `- [x]`. **step 국소 검증은 경량**(문법/컴파일/국소 실행, subagent·e2e 없음)
5. **DoD 검증:** `## 완료 기준 (DoD)` 충족 확인, 충족 시 `- [x]`
6. **완료 마킹:** step 파일 frontmatter `상태: In Progress → Done`, unified 인덱스 표 상태 `Done`
7. **다음:** 1번으로 — 진행 가능한 step 이 없을 때까지 반복

> **상태 마킹 위치:** step 평면 파일은 working/ 직속(DEPTH=1) → Edit 시 `output-naming-check.sh` 통과. step 파일에 `상태: Done` 이 들어가도 `## Self-Critique` 가 없고 파일명이 `-step-NN-` 패턴이라 `working-lifecycle.sh` 마스터 이동을 오트리거하지 않는다 (가드 존재).
> **중단/재개:** 루프 중단 시 인덱스 표의 `Done`/`In Progress`/`Pending` 상태가 재개 지점을 보존한다. `/taskflow:execute` 재호출 시 `Pending` 인 가장 낮은 step 부터 이어서 소비.
> **풀사이클 step ↔ 부모 통합 게이트 (오버헤드 회피):** 풀사이클 step 의 §QA·§검증은 **국소 자체점검**(그 step 이 자기 계획·DoD·국소 동작을 충족하는지)이다. 외부문서 대조 QA(③.5)·e2e 5점(`/taskflow:verify`)·Self-Critique·simplify(`/taskflow:review`) 같은 **무거운 통합 게이트는 전 step 완료 후 부모 unified 에서 1회** 수행하며 step 마다 반복하지 않는다 (step별 spawn = 토큰 N배 / step 은 부분기능이라 통합 e2e 무의미). step 국소 PASS ≠ 통합 PASS (층위 차이). 분담표 = plan.md §"풀사이클 step".

## QA 게이트 (단계 ③.5 — Status 판정 전, 조건부)

§실행 §Self-Critique 작성 후 Status 마킹 전, 변경분이 **외부 참조 문서**(기획서·제안서·`~/.claude/docs/참조문서/*`)의 요구를 충족하는지 cold-context subagent 가 검증한다. self-critique(자기 작성 §계획 대조)가 못 잡는 **comprehension drift**("사용자가 원한 걸 이해했나")만 노린다. 커밋은 만들지 않는다 — worktree 격리로 충분, 커밋은 정착/배포(`/taskflow:deploy`) 때만.

### 활성화 조건 (self-scoping — 없으면 QA 자체를 skip)

- **외부 참조 문서가 존재할 때만 QA 수행.** 기획서·제안서·참조문서가 없고 자기 작성 §계획만 있으면 **skip** — 계획 대조는 §Self-Critique + step DoD(②)가 이미 커버하므로 QA 는 중복·헛돈이다.
- 분기 기준 = **외부 문서 유무** (S/M/L 등급 무관). 외부 문서 있는 작업(외부 repo·기획 기반)에서만 가치 발생.
- **skip 시에도 §실행 §테스트 결과에 `QA(문서대조): 해당 없음 — 외부 참조 문서 없음` 행을 기록**한다 (침묵 skip 금지, auditable). doc-template-guard 가 이 행 부재를 차단(아래 §강제·한계).

### 입력 (worktree 변경분 전체 — 신규 파일 포함)

| 항목 | 수단 |
|------|------|
| tracked 변경 | `git diff` (미커밋) |
| **untracked 신규 파일** | `git ls-files --others --exclude-standard` → 각 파일 전문 첨부 (**필수** — `git diff` 는 신규 파일을 안 본다) |
| /taskflow:auto 추가 | 위 + `git diff {merge-base}..HEAD` (worktree-first 루프 누적 커밋) |

> 신규 파일 누락 = 신규 기능 **false PASS** 의 주원인 → untracked 포함 필수. 변경분이 비거나(빈 diff) source 분기 미상이면 QA **중단 + 경고**(빈 diff 를 PASS 로 통과시키지 않음, fail-closed). diff 가 과대하면 `--name-only` + 파일 클러스터 분할 폴백 + COVERAGE 에 부분 커버 명시.

### 검증 (단일 subagent 1 pass)

변경분 전체 ↔ 가용 외부 문서를 **단일 general-purpose subagent** 가 cold context 로 대조한다 (3축 분할 폐기 — 분할은 illusory parallelism + 자기계획 축 중복이었다). 반환 양식:

```
QA-VERDICT: PASS | FAIL          (응답 첫 줄, 단일 토큰)
FINDINGS:
- [Critical|High|Medium|Low] {파일:줄 또는 요구 항목} — {어긋난 점/누락}   (PASS 시 "없음")
```

전달: (a) 외부 문서 경로 + 정독 지시, (b) 변경분(신규 파일 포함), (c) "문서 요구 충족 여부만 판정, **코드 수정 금지**", (d) 위 양식, (e) **"지적을 압축하지 마라 — 전건 열거"**.

> (e) 는 `cold-reviewer` 정의(`custom-plugin/taskflow/agents/cold-reviewer.md`)와 같은 이유다. 요약되거나 "그 외 유사 건" 으로 묶인 findings 는 아래 FAIL 라우팅('구현 누락' ↔ '계획이 문서와 어긋남')을 판별할 수 없다. **QA 축은 `cold-reviewer` 를 쓰지 않는다** — 그 정의는 코드 품질 리뷰용이고, 여기는 "외부 문서 요구 충족" 대조라 판정 대상이 다르다. 억지로 합치면 두 축이 함께 흐려진다.

### 판정 (fail-closed)

- **첫 줄 `QA-VERDICT:` 파싱** — `PASS`/`FAIL` 외 토큰·라인 누락·빈 응답·Agent 오류 = **FAIL**(fail-closed). FINDINGS 에 `Critical`·`High` 1건+ 존재 시 VERDICT 토큰 무관 **FAIL**.
- **PASS** → §실행 §테스트 결과에 `QA(문서대조): PASS` 행 기록 → `Status: Done`(최후 write). **FAIL** → §잔여 이슈에 FINDINGS + `Status: Partial`. fix 는 §실행 재진입(미커밋 파일 직접 수정 — `reset` 불필요).

### 게이트 불변식 + 강제·한계

- 순서: ③ Self-Critique → ③.5 QA(활성 시) → ④ `Status: Done` 최후 write.
- **강제 = doc-template-guard 가 'QA 행(PASS / FAIL / 해당 없음) 존재'를 검사**(아래 §강제 hook). 단 hook 은 QA *행*(artifact)만 강제하지 QA *실행*을 강제하지 못한다 — **침묵 skip 차단 수준**이며 '게이트'가 아니다. working/ 자동 이동 경로는 mv 라 hook 미발동(아래 known-limitations).
- **known-limitations (1줄):** (1) /taskflow:execute·/taskflow:auto 이 subagent 컨텍스트(`/taskflow:parallel`·팀 handoff)로 돌면 QA subagent 중첩 spawn 불가 → 메인 인라인 검토로 폴백. (2) /taskflow:auto QA-fix 재진입은 self-critique 5회 한도 공유(QA green 전 조기 종료 가능 — USER-DECISION 안전 종료). (3) FAIL 이 '계획이 외부 문서와 어긋남'=/taskflow:plan 재진입(재설계), '구현 누락'=/taskflow:execute 재진입. (4) working/→tasks/ 자동 이동은 mv 라 doc-template-guard 미발동 — QA 행 강제는 tasks/ 직접 편집 시에만 발동(자동 이동 케이스는 규율 의존, 정직히 명시).

### 코드 변경 = verify + review 필수 체인 (2026-07-08)

**코드 파일(php/js/ts/py/sql) 변경 작업은** ③.5 QA(외부문서 시) 이후 `Status: Done` 부착 **전에** 다음을 **필수 실행**한다 (선택 슬래시 → 필수 체인 승격 — "코드 생성 시 QA 전부 타게"):
1. **`/taskflow:verify`** — e2e 5점(env / 함수·클래스 / DB 스키마 / 프로덕션 curl / mock). §검증 표 기록.
2. **`/taskflow:review`** — Self-Critique 보강 + simplify.

- ③.5 comprehension-QA(변경분↔외부문서)는 **self-scoped 유지** — 외부문서 없으면 self-critique 와 중복이라 무조건화 대상 아님. 무조건화되는 것은 **verify + review**다.
- 코드 변경 없는 작업(문서·sh 훅·commands·설정)은 §Skip 조건대로 `review` 만으로 충분(verify 면제 — verify.md L101 정합).
- **강제 강도:** plan-before(코드 전 계획)는 `gate-enforce.sh` **hard 차단** / verify+review(코드 후 QA)는 **규율**(QA-after 천장 — hook 은 §검증 표 artifact 존재만 검사 가능, 실행 진위 강제 불가). hook 백스톱은 backlog `qa-after-stop-backstop`. SSOT = CLAUDE.md §4.3 "코드 라이프사이클 게이트".

## 결정 escalation ladder (§실행 중 결정 요구 발생 시)

step 소비 중 "사용자가 결정해야 할 것 같다"고 느끼는 지점이 생기면, **바로 `[AUTO-ITERATE-USER-DECISION]` 을 붙이지 않는다.** 먼저 분류하고, 자체 해소 가능한 것만 해소한 뒤 잔여를 넘긴다. **본 섹션이 분류 판별식의 단일 SSOT** — CLAUDE.md·auto.md·`auto-iterate-reminder.sh` 는 여기를 포인터로 참조한다.

### 분류 판별식

**단일 판별 질문:** *"충분히 조사하면 Claude 혼자 정답을 확정할 수 있는가?"*

**권한형 (즉시 USER-DECISION) — 하나라도 해당하면 확정:**

| 코드 | 조건 | 예시 |
|------|------|------|
| P1 | §3 Checkpoint 5조건 매칭 | 파일 삭제 / DB 스키마 / 3파일+ 아키텍처 / 외부 API / `.env` |
| P2 | 사용자 선호·사업 판단 (기술적 정답 없음) | "이번 스프린트에 넣을까" / UX 문구 |
| P3 | 외부 상태 변경 | `git push` / master 머지 / 배포 / production DB |
| P4 | 하니스 룰·가드 자체 수정 | CLAUDE.md 정책 변경, hook 가드 완화 |

**정보 부족형 (ladder 진입) — P1~P4 전부 비해당 + 하나 해당:**

| 코드 | 조건 | 해소 수단 |
|------|------|----------|
| I1 | 코드베이스 조사로 답이 확정됨 | 영향 범위 / 기존 계약 / 호출부 |
| I2 | 설계 대안 비교로 우열이 갈림 | 근거 문서 / 기존 패턴 |
| I3 | 계획 미기재 세부 구현 선택 | 기존 코드 컨벤션 추종 |

- **fail-safe 기본값 (필수):** **판정 불확실 = 권한형.** §3 "불확실 시 발동이 기본값" 을 그대로 상속한다.
- **판정 기준은 "무엇을 묻는가"가 아니라 "무엇을 하게 되는가"** 다. "이 필드 nullable 로 할까"는 조사로 확정되면 I1 이지만, **DB 스키마 변경을 수반하는 순간 P1 로 승격**된다.

### Ladder 흐름

```
결정 요구 감지
  ├─ [분류] P1~P4 해당? ──── 예 ──→ 즉시 [AUTO-ITERATE-USER-DECISION] (종료)
  │                     └─ 불확실 ──→ 즉시 [AUTO-ITERATE-USER-DECISION] (fail-safe)
  └─ 아니오 (I1~I3 확실)
       ├─ [L1] /taskflow:analyze 재진입 (항목당 최대 1회)
       │        ├─ 해소 → step 소비 복귀 + 로그 기록
       │        └─ 미해소 ↓
       ├─ [L2] /taskflow:plan 재진입 (항목당 최대 1회)
       │        ├─ 해소 → step 소비 복귀 + 로그 기록
       │        └─ 미해소 ↓
       └─ [AUTO-ITERATE-USER-DECISION] + 조사 결과 첨부 (맨몸 질문 금지)
```

### bounded 규약

- **항목당** analyze 1회 + plan 1회. 항목 = 개별 결정 요구 1건.
- **self-critique 5회 한도와 별도 카운터** — 공유 시 `auto.md` known-limitation("QA green 전 조기 종료")이 악화된다.
- 동일 항목 재진입 금지 — `auto.md` §"재토론 금지 원칙"과 동형.
- 카운터는 파일이 아니라 **아래 로그 표의 행 수**로 관리한다 (hook 신설 회피, artifact 겸용).

### ladder 로그 표 (artifact — §실행에 기록)

```markdown
## 결정 Escalation 로그
| # | 결정 항목 | 분류 | L1 analyze | L2 plan | 결과 |
|---|---------|------|-----------|---------|------|
| 1 | {무엇을 결정해야 했나} | I1~I3 또는 P1~P4 | 수행/생략 | 수행/생략 | 자체 해소 / USER-DECISION |
```

> 권한형(P*)도 L1·L2 `생략` + 결과 `USER-DECISION` 으로 **명시 기록**한다 (침묵 skip 금지 — 오분류를 사후 발견하는 유일한 표면).
>
> **결정 수용 시 갱신 (필수):** 사용자가 그 항목에 결정을 입력하면 같은 행 `결과` 를 `USER-DECISION` → `사용자 결정: {선택} ({YYYY-MM-DD})` 로 덮어쓰고 판단 근거를 1줄 덧붙인다. 행을 새로 추가하지 않는다 (bounded 카운터가 행 수 기반이라 중복 행은 재진입 한도를 왜곡한다). 상태 복귀·REGISTRY 까지의 전체 절차 = `tick.md` §"결정 수용" SSOT.

### 강제 강도 + §3 우회 차단

| 레이어 | 수단 | 강도 |
|--------|------|------|
| 분류·ladder 이행 | Claude 본체 규율 | **강제 불가** (아래 known-limitation) |
| 두 메커니즘 상기 | `auto-iterate-reminder.sh` 매 턴 주입 | **실효 레버** |
| 로그 표 존재 | working 문서 artifact | 침묵 skip 차단 |
| §3 보호 | `dangerous-ops-guard` / `sensitive-file-guard` / `branch-enforce` PreToolUse exit 2 | **hard 차단 (무손상)** |
| 가드 완화 시도 | auto mode classifier `[Self-Modification]` | **hard 차단** |

**ladder 는 §3 보호 우회 통로가 아니다.** P1~P4 매칭 또는 판정 불확실 시 ladder 진입 자체가 금지되며, 설령 오분류해도 위 두 hard 차단 레이어가 도구 레벨에서 막는다.

> **known-limitation:** Stop hook 은 assistant 의 **최종 출력 텍스트만** 볼 수 있다 (tool call 이력·중간 추론 구조 미제공). 따라서 `auto-iterate-stop-guard.sh` 는 sentinel 문자열 존재만 확인할 뿐 ladder 경유 여부를 판정하지 못한다. 이는 §"QA 게이트"의 artifact-only 천장과 **동일 구조**이며, 강제는 규율 + reminder + 로그 표로 근사한다.

## 직병렬 실행 지침

**원칙:** step 순차 소비는 의존 순서 **직렬 필수**. 단 동일 의존 레벨의 독립 step(상호 의존 없음)은 단일 응답 내 병렬 가능. 한 step 내부의 독립 파일 변경도 병렬 가능. 동일 파일 mutation·순서 의존 = 직렬 fallback (race 가드). 강제 병렬 modifier = `/taskflow:parallel`.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| step 간 (의존 있음) | **직렬 필수** | 선행 step `Done` 후 후행 step 진입 |
| step 간 (동일 레벨, 의존 없음) | **조건부 병렬** | 상호 의존 없는 step 병렬 소비. 다모듈 = `/taskflow:parallel /taskflow:execute` |
| step 내부: 의존 없는 독립 파일 | **조건부 병렬** | 병렬 Edit / Agent spawn. **동일 파일·순서 의존 = 직렬 fallback** |
| ① → ② → ③ → ③.5 → ④ 골격 | **직렬 필수** | 계획 확인 → step 소비 → §실행 기록 → QA 게이트(조건부) → Status 판정 |

## 자연어 trigger

- `실행 시작` / `구현 시작` / `execute`

## 강제 hook

| Hook | 검증 | 차단 강도 |
|------|------|----------|
| `doc-unified-check.sh V1` | unified §실행 헤더 (실행 요약 / Self-Critique / 테스트 결과 / 잔여 이슈 / Status: Done\|Partial) L128~143 | exit 2 (tasks/ 이동 후) |
| `doc-unified-check.sh V4` | unified 체크리스트 = 작업 등급 비례 S≥8/M≥14/L≥20 (§4.3 SSOT) | exit 2 |
| `output-naming-check.sh` | step 평면 파일 Edit = working/ DEPTH=1 통과 | exit 2 (위반 시) |
| `working-lifecycle.sh` | `^Status:\s*Done` + `## Self-Critique` 동시 시 PostToolUse 자동 이동 — unified → tasks/, step 평면 → tasks/.../steps/NN-{slug}.md 분배 | (lifecycle 트리거) |
| QA 행 기록 (규율) | **QA 활성 시 §실행 §테스트 결과에 `QA(문서대조): PASS\|FAIL\|해당 없음` 행 기록** (auditable claim). **hook 완전강제 없음** — working-lifecycle=전 product 영향, doc-template-guard=자동이동 mv 미발동(둘 다 부적합). fail-open 은 **self-scoping(외부 문서 시만 QA)** 으로 표면 자체를 축소해 관리 | (규율 + 표면 축소) |

## 자동 이동 트리거

> **QA 게이트 정합:** QA 활성(외부 문서 존재) 시 `Status: Done` 은 QA PASS(또는 skip 사유 기록) 후 write 한다. 단 working/→tasks/ 자동 이동은 mv 라 doc-template-guard 미발동 — QA 행 강제는 tasks/ 직접 편집 시에만 (자동 이동 케이스는 규율 의존, §"QA 게이트" known-limitations 명시).

```
Status: Done   (시작 라인)
+
## Self-Critique  (섹션 존재)
   ↓ PostToolUse hook (working-lifecycle.sh)
~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/
├── {yyyy-mm-dd}-{작업명}-unified.md          ← unified 마스터
└── steps/NN-{slug}.md                         ← step 평면 파일 분배 이동
```

## 호출 예

```
/taskflow:execute                      ← 진행 중 working/ step 인덱스 순차 소비 시작
/taskflow:execute auth-refactor        ← 특정 작업 step 순차 소비
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.1 "장기 관점 분석·계획·실행" + §4.2 "에이전트 우선 위임" | 정책 SSOT |
| `~/.claude/skills/task-docs/SKILL.md` | 본 슬래시의 본체 스킬 |
| `~/.claude/skills/task-docs/references/unified-template.md` § 실행 | unified 양식 SSOT |
| `~/.claude/custom-plugin/taskflow/commands/plan.md` §"step 파일 양식" | step 분해·인덱스 양식 SSOT (본 슬래시가 소비) |
| `~/.claude/hooks/doc-unified-check.sh V1` L128~143 | unified §실행 헤더 강제 |
| `~/.claude/hooks/working-lifecycle.sh` | Status: Done 자동 이동 + step 분배 본체 |
| `~/.claude/custom-plugin/taskflow/commands/execute.md` §"QA 게이트" (본 파일) | QA 게이트 절차 SSOT (활성화 조건 / 단일 subagent / fail-closed 판정 / known-limitations) |
| `~/.claude/custom-plugin/taskflow/commands/execute.md` §"결정 escalation ladder" (본 파일) | **분류 판별식 (P1~P4 / I1~I3) + fail-safe + ladder 절차 + bounded + 로그 표 SSOT** — CLAUDE.md·auto.md·reminder hook 이 참조 |
| `~/.claude/custom-plugin/taskflow/commands/analyze.md` §"단계 전이 (→ plan)" | 순방향 전이 조건 (T1·T2) SSOT — 본 슬래시의 짝 |

## §3 Checkpoint 우선 적용

§실행 단계는 §3 5조건 매칭 시 직접 변경 금지:
- 비가역 (`rm` / `git push` / `git reset --hard` / DB migration)
- 광범위 (3 파일 + 아키텍처)
- 요구사항 상충 (트레이드오프)
- 외부 시스템 연동
- 권한 외 파일 접근 (`.env` 등)

매칭 시 사용자 명시 승인 키워드 대기 후 재진입. **step 단위 적용:** §3 매칭 step 은 인덱스 상태 `Pending(승인 대기)` 로 두고 소비를 건너뛴다 (위 §"step 순차 소비" 2번). 나머지 진행 가능 step 은 계속 소비.

**QA 게이트 (③.5) = read-only 분석:** 단일 subagent 는 변경분 ↔ 외부 문서 대조 진단만 (코드 수정 금지) → §3 비매칭. QA 는 커밋도 만들지 않는다 (worktree 미커밋 상태). QA FAIL 후 fix 는 §실행 재진입 = 그때 §3 5조건 재검사. QA 게이트 자체가 §3 우회 통로로 작동하지 않는다.

**worktree 적용 (CLAUDE.md §4.3 (a)):** 본 슬래시 = 코드/설정 mutation 직접 발생. cwd ∉ worktree (`*/worktrees/*`) + functional exemption 미매칭 → `worktree-enforce.sh` exit 2 차단. **2026-05-20 정책 = `~/.claude/` 영역 포함 모든 영역 worktree 강제.** `working/` mutation(step 평면 파일 상태 마킹 포함)은 exemption #5 자동 통과.

## Skip 조건

| 등급 | 진행 여부 |
|------|----------|
| S / M / L | **항상 필수** — 코드 변경이 발생하는 모든 작업의 핵심 단계 |
| (코드 변경 없는 분석·문서 작업) | 면제 — `/taskflow:analyze` / `/taskflow:plan` / `/taskflow:retro` 만으로 종결 |
| (step 인덱스 없는 작업) | step 순차 소비 생략 — §계획 수정 대상 표 순차 실행 (기존 동작, 하위 호환) |
| QA 게이트 (③.5) — 외부 참조 문서 없음 (자기 §계획만) | **skip** — 계획 대조는 Self-Critique + step DoD 가 커버. `QA(문서대조): 해당 없음` 행만 기록 |
| QA 게이트 (③.5) — 외부 참조 문서 존재 (기획·제안·참조문서) | **수행** — 변경분 ↔ 외부 문서 단일 subagent 대조 (등급 무관) |

## 차별점 (다른 슬래시와)

| 슬래시 | 시점 | 범위 |
|--------|------|------|
| `/taskflow:draft` | 원본 파일(기획서/스펙) 기반 시작 | working/ §분석·§계획 + 원본 지문(sha256) 박제 (짝 = execute) |
| `/taskflow:analyze` | 작업 시작 | working/ §분석 |
| `/taskflow:plan` | §분석 완료 후 | working/ §계획 + step-01~nn 분해 |
| **`/taskflow:execute`** | §계획 완료 후 | step 인덱스 순차 소비 + working/ §실행 + Self-Critique + **QA 게이트(③.5)** + Status |
| `/taskflow:verify` | §실행 도중/직후 | e2e 5점 (env / 함수 / 스키마 / curl / mock) |
| `/taskflow:review` | §실행 직후 | Self-Critique 보강 + simplify |

> **QA 게이트(③.5) vs /taskflow:verify·/taskflow:review:** QA 게이트 = "구현 ↔ **외부 문서**(기획·제안) 대조(comprehension drift)" — 외부 문서 있을 때만. `/taskflow:verify` = 환경·런타임(e2e 5점), `/taskflow:review` = 코드 내부 품질(Self-Critique·simplify). 상보적 — QA 게이트는 /taskflow:execute **내부 조건부**(Status 전, 단일 subagent), /taskflow:verify·/taskflow:review는 **별도 슬래시**.

## Changelog

- 2026-05-15: 신설
- 2026-05-29: step 순차 소비 연동
- 2026-06-05: QA 게이트 추가
