---
description: 작업 메타분석 — 계획까지 완료된(Status: Plan Complete) 여러 작업을 가로질러 스캔 → 의존·worktree·파일충돌 기준으로 동시진행 그룹 + 우선진행 순위 도출 → working/ 에 메타분석 문서 신규 생성 + 기존 계획 문서에 권고 블록 append. 자립형 커맨드 (본체 스킬 없음). `/taskflow:analyze`(단일 작업)과 구분되는 다작업 메타분석 진입점.
allowed-tools: Bash, Read, Glob, Grep, Agent, Write, Edit, Skill
argument-hint: "[product|all|작업명  # 생략 시 현재 cwd product 의 Plan Complete 전체]"
---

# 작업분석 (Multi-Task Meta-Analysis)

계획까지 완료된 작업들(`Status: Plan Complete`)을 **여러 작업에 걸쳐 가로질러 분석**해, 어느 작업들을 **동시에 진행**할 수 있고 어느 작업을 **먼저 진행**해야 하는지 도출하는 자립형 진입점. 결과를 working/ 에 메타분석 문서로 남기고, 분석 대상이 된 기존 계획 문서에는 "동시진행/우선순위 권고" 블록을 덧붙인다.

> **[용도 한정]** *여러 작업 간* 동시진행·우선순위 메타분석 전용. 단일 작업 1개의 분석은 `/taskflow:analyze`, 잔존 Partial 작업 로드는 `/taskflow:load`, 일괄 실행은 `/taskflow:auto` 이 담당한다. 본 커맨드는 그 사이 — **"무엇을 같이/먼저 할지" 계획 수립 진입점**이다.
> **Why:** 계획 완료 작업이 여러 개 쌓이면 어떤 걸 병렬로 돌리고 어떤 걸 먼저 해야 할지가 흐려진다. 매번 즉흥 판단하면 (1) 동일 파일·worktree 경합을 모르고 병렬 spawn 해 충돌나거나 (2) 선행 의존을 무시한 순서로 진행해 재작업이 생긴다. 본 커맨드가 **스캔 → 충돌·의존 매트릭스 → 권고** 골격을 SSOT 로 고정한다.

## 인자

- `$ARGUMENTS` = (선택) 분석 범위.
  - **생략** = 현재 cwd product 의 `Status: Plan Complete` 작업 전체 (tasks/ + working/ 양쪽).
  - **`all`** = 전 product 의 Plan Complete 작업 전체.
  - **`{product}`** (예: `hongcafe_global_backend`) = 특정 product 의 Plan Complete 작업.
  - **`{작업명}` 목록** = 명시한 작업들만 (공백/쉼표 구분).

## 동작 (5-Phase)

| Phase | 동작 | 도구 | 직렬·병렬 |
|-------|------|------|--------|
| **0** | **스캔** — `Status: Plan Complete` 문서를 **tasks/ + working/ 양쪽**에서 수집(위치 라벨 부착) + product 필터(인자 분기) | Bash, Grep, Glob | 직렬 |
| **1** | **메타데이터 추출** — 작업당 (등급 S/M/L · §계획 수정 대상 파일 목록 · WBS 의존 · worktree 전략 · Critical 이슈 유무) 파싱. 작업 수 多 시 작업별 `Explore` Agent **병렬 spawn** | Read, Grep, Agent(병렬) | **병렬** |
| **2** | **충돌·의존 매트릭스** — 작업 쌍별로 (파일 중복 / 동일 worktree 경합 / 상호 의존) 교차 판정 → **동시진행 그룹** + **우선진행 순위** 도출 | 본체 | 직렬 |
| **3** | **메타분석 문서 생성** — `working/YYYYMMDD/{yyyy-mm-dd}-{product}-작업분석-{slug}.md` 신규 Write (동시진행 그룹표 + 우선순위 매트릭스 + 근거) | Write | 직렬 |
| **4** | **기존 계획 문서 update** — 대상 계획 문서 각각에 "동시진행/우선순위 권고" 블록 **append** (§3 승인 후) | Edit | 직렬 |

> Phase 0~3 = read-only + working/ 신규 문서(면제 경로). Phase 4 = **기존 tasks/ 계획 문서 다파일 Edit → §3 광범위 매칭 → 사용자 명시 승인 후 실행** (아래 §3 절 참조).
> **전파(후속·비동기):** Phase 0~4 는 작업분석 *실행* 동작이다. 이후 분석 대상 작업이 완료(Done)되면 `working-lifecycle.sh` 가 작업분석 인덱스 표를 자동 역갱신한다 (아래 §전파 — Phase 번호 밖, 작업 완료 시점 트리거).

## Phase 0 — 스캔 (Plan Complete 수집)

```bash
# product 식별 — 현재 cwd 기준 (worktree 안 호출 시 원본 repo 역해석)
source ~/.claude/hooks/lib/product-resolver.sh
CURRENT_PRODUCT=$(resolve_product "$PWD")

# $ARGUMENTS = harness 프롬프트 치환. bash 블록은 위치 인자($1)를 상속하지 않는다.
ARG="$ARGUMENTS"
case "$ARG" in
  "")     TARGET_PRODUCT="$CURRENT_PRODUCT" ;;   # 기본 = 현재 cwd product
  "all")  TARGET_PRODUCT="" ;;                    # 전체
  *)      TARGET_PRODUCT="$ARG" ;;                # product 명 또는 작업명 (Phase 1 에서 매칭)
esac

# Plan Complete 문서 수집 — tasks/ + working/ 양쪽 (위치 라벨)
#  tasks/ : ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/*.md
#  working/: ~/.claude/docs/working/YYYYMMDD/*.md  (미실행 계획은 대개 여기 잔존)
#  날짜 폴더(YYYYMMDD)만 — load.md WORKING_GLOB 과 동일 표현 재사용 (backlog/·dispatch/ 등 비-날짜 폴더 배제)
grep -lE '^Status:\s*Plan Complete' \
  ~/.claude/docs/*/tasks/*/*/*.md \
  ~/.claude/docs/working/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/*.md 2>/dev/null \
  | while read f; do
      case "$f" in
        */working/*) loc="working" ;;
        *)           loc="tasks" ;;
      esac
      # product 추출: working = 파일명 prefix, tasks = 경로 세그먼트
      echo "$loc"$'\t'"$f"
    done
```

- **위치 라벨 필수** — `lifecycle` hook 은 `Status: Done` 에서만 working/ → tasks/ 로 옮기므로, **미실행 Plan Complete 는 대개 working/ 에 잔존**한다. tasks/ 만 보면 누락된다 → 양쪽 스캔이 기본값.
- **product 필터** — working/ 는 파일명 prefix `{yyyy-mm-dd}-{product}-`, tasks/ 는 경로 `docs/{product}/tasks/` 세그먼트로 판정. `all` = 필터 해제.
- 수집 0건이면 — "Plan Complete 작업 없음" 보고 후 종료 (메타분석 대상 없음).

## Phase 1 — 메타데이터 추출 (작업당)

각 작업 문서에서 다음을 파싱한다. 작업 수가 많으면(≥ 4) 작업별 `Explore` Agent 를 **병렬 spawn** 해 각 문서를 독립 정독시킨다 (cold context, race 없음).

| 필드 | 추출 위치 | 용도 |
|------|----------|------|
| 작업 등급 | §계획 "작업 등급" 또는 frontmatter | S=빠른 완료(우선 후보) / L=장기 |
| 수정 대상 파일 | §계획 "수정 대상" 표 | **파일 중복 = 병렬 충돌** 판정 입력 |
| WBS 의존 | §계획 "작업 분해(WBS)" 의존관계 열 | **선행 의존 = 우선순위** 판정 입력 |
| worktree 전략 | §계획 "실행 계획 > worktree" | 동일 worktree 경합 여부 |
| Critical 이슈 | §분석 "Critical 이슈" 유무 | **차단 해소 = 우선** 판정 입력 |
| product / 모듈 | 경로 + §계획 | 다른 product·모듈 = 병렬 안전 |

## Phase 2 — 충돌·의존 매트릭스 → 동시진행 그룹 + 우선순위

작업 쌍별로 교차 판정해 분류한다.

### 동시진행 가능 판정 (병렬 그룹)

| 기준 | 동시진행 가능 | 동시진행 불가 (직렬) |
|------|:------------:|:--------------------:|
| 수정 대상 파일 | 교집합 없음 | **교집합 있음** (동일 파일 mutation 경합) |
| product / 모듈 | 다른 product·모듈 | 동일 모듈 핵심 경로 공유 |
| worktree | 독립 worktree 가능 | 동일 worktree 강제 공유 |
| 상호 의존 | 없음 | **A 가 B 산출물 의존** |

> 한 기준이라도 "직렬"이면 두 작업은 **같은 병렬 그룹에 못 둔다**. 모두 "가능"인 작업끼리 묶어 동시진행 그룹 G1, G2 … 로 편성.

### 우선진행 순위 판정

| 우선 신호 | 가중 |
|----------|------|
| Critical 이슈 보유 (차단·장애) | 최우선 |
| 다른 작업의 **선행 의존** (이게 끝나야 후속이 풀림) | 높음 |
| 등급 S (빠른 완료로 큐 비움) | 중간 |
| 외부 시점/의존 대기 (`target_date` 미도래 등) | **보류** (순위 제외) |

> 출력 = **동시진행 그룹표**(어떤 작업을 같은 응답에서 `/taskflow:parallel`로 돌릴 수 있는가) + **우선순위 매트릭스**(어떤 그룹·작업을 먼저). 각 판정엔 **근거 1줄**(어느 파일 중복/어느 의존)을 반드시 붙인다 — 근거 없는 "병렬 가능"은 충돌 사고의 원인.

## Phase 3 — 메타분석 문서 생성 (working/)

- 경로: `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-작업분석-{slug}.md`
  - `{slug}` = 분석 범위 요약 kebab-case (예: `plan-complete-batch`).
  - `all` 범위면 `{product}` = `global`.
- 평면 파일 (working/ DEPTH=1 → `output-naming-check.sh` 통과). ISO-8601 `YYYY-MM-DD-` prefix.
- 본문 = **대상 작업 인덱스**(아래 링크 표) + **동시진행 그룹표** + **우선순위 매트릭스** + **각 판정 근거**.
- 사용자 지시("working에 새로")에 따라 working/ 에 둔다. 내용상 `output/analysis` 성격이나 **지시 우선**.

### 대상 작업 인덱스 (참고 파일 전부 — 클릭 가능 링크) — **필수**

Phase 0~1 에서 스캔·정독한 **모든** 대상 작업을 빠짐없이 링크 표로 적는다. 이 표가 **참조 provenance**(무엇을 보고 이 메타분석을 만들었는가) + **전파 추적 단위**(완료 시 역갱신될 행) 의 SSOT 다.

| # | 작업명 | 위치 | 등급 | 계획 문서 | 수정 대상 코드 | 상태 |
|---|--------|------|:----:|----------|---------------|:----:|
| 1 | `{작업명}` | working / tasks | S/M/L | [{파일명}](~/.claude/docs/{product}/...절대경로...) | `Foo.php`, `routes.php` | ⏳ Plan |
| 2 | … | … | … | … | … | … |

- **작업명 컬럼 = 전파 매칭 키 (필수).** 값은 plan 파일명 `{yyyy-mm-dd}-{product}-{작업명}.md` 의 `{작업명}` 세그먼트와 **정확히 일치**해야 한다. (lifecycle hook 이 이 셀로 행을 찾는다 — `| {작업명} |` 정확 매칭.)
- **계획 문서 링크 = `~/.claude/docs/...` 절대(홈) 경로 (필수).** 상대 링크 금지 — 완료 시 hook 이 working/ 경로 문자열을 tasks/ 경로로 **치환 갱신**하므로 경로 표기를 절대형으로 통일해야 치환이 안정적이다. 현재 위치 기준으로 적는다(working/ 잔존 = working 경로 / 이미 완료 = tasks 경로). **링크 셀은 백틱으로 감싸지 말 것** — 코드스팬(`` `[..](..)` ``) 안의 마크다운 링크는 렌더러가 클릭 링크로 파싱하지 않는다(작업명 셀의 백틱은 placeholder 표기라 무관).
- **수정 대상 코드 = 각 계획 §"수정 대상" 표의 코드 파일 전부** (req1 "참고된 파일 전부"). 파일이 많으면 핵심 + `외 N건` 으로 축약 가능(전수 링크는 계획 문서 안에 있으므로 추적 가능).
- **상태 컬럼:** `⏳ Plan` (Plan Complete, 미완료) / `✓ Done` (완료 — 전파로 자동 갱신). 생성 시점엔 전부 `⏳ Plan`.
- 0건 행 없음 — 대상 작업 1개당 정확히 1행.

## Phase 4 — 기존 계획 문서 update (§3 승인 후)

분석 대상이 된 각 계획 문서에 권고 블록을 **append** 한다. **전면 재작성 금지** — `doc-unified-check.sh V1` / `output-naming-check.sh` / `doc-unified-check.sh V2` 양식·메타가 깨지지 않게 기존 본문은 보존하고 아래 블록만 덧붙인다.

```markdown
## 동시진행/우선순위 권고 (작업분석 {yyyy-mm-dd})

- **동시진행 그룹:** {G1 — 함께 진행 가능 작업 / 충돌 없음 근거}
- **우선순위:** {본 작업이 먼저/나중인가 + 근거}
- **충돌 주의:** {동일 파일·worktree 경합 시 직렬 강제 대상}
- 출처: `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-작업분석-{slug}.md`
```

- **`출처:` 라인 = 전파 backlink (필수).** 반드시 **실제 작업분석 문서의 정확한 경로**(`.../` placeholder 가 아닌 실경로)를 적는다. lifecycle hook 이 plan 완료 시 이 라인의 `작업분석-*.md` 를 grep 해 역갱신할 작업분석 문서를 찾는다 (아래 §전파). placeholder 로 두면 전파가 끊긴다.

> Phase 4 는 **다파일 Edit = §3 광범위(3 파일+) → 사용자 명시 승인 필수**. 승인 전엔 Phase 3 메타분석 문서까지만 생성하고, 어느 계획 문서들을 update 할지 목록을 제시한 뒤 승인 키워드를 대기한다.

## 전파 (Propagation) — 관련 작업 완료 시 작업분석 문서로 역갱신

작업분석 문서는 **라이브 마스터 인덱스**다. 분석 대상 작업이 완료(`Status: Done` → working/ → tasks/ 자동 이동)되면, 그 완료가 작업분석 문서의 `대상 작업 인덱스` 표에 **자동 전파**된다. 별도 슬래시·수동 갱신 불필요.

**전파 흐름** (`hooks/working-lifecycle.sh` `move_working_to_tasks()` 확장):

1. plan 문서가 완료 이동될 때, hook 이 **이동 직전** 그 문서에서 작업분석 backlink (`작업분석-*.md` 출처) 를 grep.
2. backlink 가 가리키는 작업분석 문서를 열어 `| {작업명} |` 행을 찾는다 (작업명 = plan 파일명 `{date}-{product}-{작업명}.md` 세그먼트 = 인덱스 표 키 컬럼).
3. 해당 행 갱신: **상태 `⏳ Plan` → `✓ Done`** + **계획 문서 링크 working/ 경로 → tasks/ 실경로** (이동 후 `…/tasks/YYYYMMDD/{작업명}/{date}-{작업명}-unified.md`).
4. **best-effort 비차단** — 전파 로직이 실패해도 plan 이동 자체(기존 lifecycle 동작)엔 영향 없음.

**전파 활성 조건 (필수):** plan 문서에 **작업분석 backlink 가 심겨 있어야** 추적된다 = **Phase 4 권고 블록을 append 한 작업만** 전파 대상. Phase 4 미실행(권고 블록 미append) 작업은 backlink 가 없어 전파되지 않는다 — 의도된 저결합(권고를 안 단 작업은 추적도 안 함). 전파를 원하면 Phase 4 를 승인·실행해 backlink 를 심는다.

**다중 참조:** 한 plan 이 작업분석을 여러 번 받으면(재실행 누적) `출처:` backlink 가 여러 건 쌓인다. hook 은 **중복 제거 후 모든 작업분석 문서**를 갱신한다(첫 1건만 갱신 시 나머지가 `⏳ Plan` 으로 stale 잔존하는 것을 방지 — silent cap 금지).

> **깨진 링크 해소가 전파의 본질:** lifecycle hook 은 완료 시 plan 을 `working/` → `tasks/.../unified.md` 로 **mv 이동**(`working-lifecycle.sh::move_working_to_tasks`)한다. Phase 3 인덱스가 박은 working/ 링크는 완료 순간 깨진다 — 전파가 바로 그 링크를 tasks/ 실경로로 갱신 + 상태 `✓` 로 마킹해 마스터 인덱스를 **라이브**로 유지한다. SSOT: 본 절 + `hooks/working-lifecycle.sh` 전파 블록.

## 직병렬 실행 지침

**원칙:** Phase 0 → 1 → 2 → 3 → 4 는 **직렬**(이전 단계 출력 의존). 단 Phase 1 의 작업별 문서 정독은 **병렬 가능**.

| 태스크 | 직렬·병렬 | 방법 |
|--------|---------|-----|
| Phase 1 (작업 N개 메타데이터 추출) | **조건부 병렬** | 작업 ≥ 4 시 작업별 `Explore` Agent 동시 spawn (문서 독립, race 없음). `/taskflow:parallel /taskflow:survey` |
| Phase 0 → 1 → 2 → 3 → 4 | **직렬 필수** | 스캔 → 추출 → 매트릭스 → 문서 → update |

## 산출물

- `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-작업분석-{slug}.md` (Phase 3 신규)
- 기존 tasks/ 계획 문서들에 권고 블록 append (Phase 4, 승인 후)

## §3 Checkpoint 우선 적용

| 단계 | §3 매칭 | 처리 |
|------|---------|------|
| Phase 0~2 (스캔·추출·매트릭스) | 비매칭 | read-only — 즉시 진행 |
| Phase 3 (working/ 신규 문서) | 비매칭 | functional exemption #5 (`*/.claude/docs/*`) Gate-0 직행 |
| **Phase 4 (계획 문서 다파일 update)** | **§3 광범위 (3 파일+)** | **update 대상 목록 제시 → 사용자 명시 승인 후 append** |

- 본 커맨드는 **분석·권고 도구** — 권고된 동시진행/우선순위의 **실제 실행(코드 변경·worktree)은 범위 밖**. 후속 `/taskflow:auto` · `/taskflow:parallel /taskflow:auto` · `/taskflow:execute` 로 분리한다.
- 메타분석이 "이 작업들 병렬 진행" 을 권고해도, 실제 병렬 spawn·worktree·정착은 §3 보호(`worktree-enforce` / `branch-enforce` / `dangerous-ops-guard`)를 그대로 거친다. 본 커맨드가 §3 우회 통로로 작동하지 않는다.

## 짝 슬래시

`/taskflow:analyze` 가 **단일** 작업 1개를 보는 자리에서, 본 슬래시는 **여러** Plan Complete 작업을 가로질러 본다 (동시진행 그룹 + 우선순위). 실행은 아래 §"후속 진입점" 으로 넘긴다. 전체 맵 = `execute.md` §"워크플로우 맵" SSOT.

## 후속 진입점 (응집)

작업분석 결과는 **실행 진입점**으로 이어진다:

```
/taskflow:survey            → 동시진행 그룹 G1{A,B} / G2{C} + 우선순위 도출
   ↓
/taskflow:parallel /taskflow:auto G1   → G1 의 A·B 를 동시 spawn 실행 (충돌 없음 확인됨)
   ↓
/taskflow:auto C          → 후속 그룹 순차 실행
```

## 호출 방식

| 인자 | 동작 |
|------|------|
| `/taskflow:survey` | 현재 cwd product 의 Plan Complete 작업 메타분석 |
| `/taskflow:survey all` | 전 product Plan Complete 메타분석 |
| `/taskflow:survey hongcafe_global_backend` | 특정 product Plan Complete 메타분석 |
| `/taskflow:survey auth-refactor commerce-price` | 명시 작업들만 메타분석 |

### 호출 예

```
/taskflow:survey                                  ← 본 product 계획완료 작업 동시진행/우선순위 분석
/taskflow:survey all                              ← 전체 product 가로질러 분석
/taskflow:survey hongcafe_global_backend          ← be 계획완료 작업만
```

## 트리거 제외 (의도된 차단)

| 케이스 | 대체 |
|--------|------|
| 단일 작업 1개 분석 | `/taskflow:analyze` |
| 잔존 Partial 작업 로드 | `/taskflow:load` |
| 작업 실제 실행·구현 | `/taskflow:auto` / `/taskflow:execute` |
| 의견 갈림·우열 역전 결정 | `/taskflow:debate` (16 Agent) |

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/custom-plugin/taskflow/commands/survey.md` (본 파일) | 자립형 진입점 — 다작업 메타분석 5-Phase 골격 |
| available-skills 카탈로그 (하니스 세션 자동 등재) | 커맨드 등록 — 플러그인 커맨드는 §5.1 인벤토리 대상 외 (`skill-inventory.md` §"플러그인 이동 (2026-07-06)" SSOT) |
| `~/.claude/hooks/lib/product-resolver.sh` | cwd → product 산출 (Phase 0 필터) |
| `~/.claude/custom-plugin/taskflow/commands/plan.md` §"step 파일 양식" / Status: Plan Complete | 스캔 대상 마커·WBS 구조 SSOT |
| `~/.claude/custom-plugin/taskflow/commands/auto.md` · `~/.claude/custom-plugin/taskflow/commands/parallel.md` | 분석 결과 후속 실행 진입점 |
| `~/.claude/hooks/working-lifecycle.sh` | Plan Complete 가 working/ 에 잔존하는 이유 (Done 만 tasks/ 이동) + **전파** (완료 이동 시 작업분석 인덱스 행 역갱신 — `move_working_to_tasks()` 전파 블록) |

## Changelog

- 2026-08-06: working/ 스캔 루트를 날짜 폴더(YYYYMMDD)로 한정 — backlog/·dispatch/ 등 비-날짜 폴더 제외 (선행 `working-scan.sh` a7081c6 · `working-lifecycle.sh` 7a5512a 와 동일 축)
- 2026-08-03: 구 `## 차별점` 표 → `## 짝 슬래시` 포인터로 축약 (전체 맵 SSOT = `execute.md` §"워크플로우 맵")
- 2026-06-09: 신설
