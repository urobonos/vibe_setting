---
description: 분리 개발↔리뷰 루프를 **스텝 1개 = 프로세스 1개**로 돌린다 — 개발자·리뷰어·adversary 가 각각 독립 `claude -p` 로 뜨고 끝나면 사라지며, 상태는 오직 결과문서로 넘어간다. 메인 세션은 `RESULT.md` 하나만 흡수한다. 루프 계약은 `/taskflow:code` 를 그대로 상속한다. 짝 = `/taskflow:code`(메인 세션 내 실행) · `/taskflow:tick`(문서 기반 무인)
allowed-tools: Bash, Read, Glob, Grep, Skill
argument-hint: "{구현 요청} — 필수. 오래 걸리므로 run_in_background 로 띄운다"
---

**이 커맨드는 `/taskflow:code` 를 재정의하지 않는다.** 1단계 범위 확인 · 크기 게이트 · 루프 종료 조건 · 반박 판정 · BASELINE 교차 확인 · 적대적 검증 게이트 · 캡(정규 5 · 게이트 2) 전부 `custom-plugin/taskflow/commands/code.md` 가 SSOT 다. **여기 소관은 그 루프를 어디서 도느냐 하나뿐이다.**

## 어떻게 도는가

```
메인 세션
  └ bash ~/.claude/bin/code-loop.sh "{요청}"      ← run_in_background 로 띄운다
       │
       ├ claude -p [spec]              sonnet  → 00-spec.md (+ GATE 줄)
       │
       ├ dev-loop  (라운드당 프로세스 4개, 캡 5)
       │    claude -p [dev]            sonnet  → dev-NN.md
       │    claude -p [rev-correctness] sonnet ┐ 병렬
       │    claude -p [rev-design]      sonnet ┘
       │    claude -p [merge]          sonnet  → rev-NN.md (+ VERDICT 줄)
       │    └ 셸이 VERDICT 만 읽고 분기
       │
       ├ adv-loop  (캡 2)
       │    claude -p [adversary]      opus    → adv-MM.md (+ VERDICT 줄)
       │    BROKEN → dev 재진입(정규 캡 계상) → 리뷰 1라운드
       │
       └ claude -p [result]            sonnet  → RESULT.md  ← 메인은 이것만 읽는다
```

**각 `claude -p` 의 프롬프트 = 에이전트 정의 전문 + 작업 지시다.** Agent 도구로 spawn 하는 것이 아니라 **프로세스 자체가 그 역할을 수행한다.** 그래서 정의 파일(`agents/*.md`)이 그대로 계약으로 작동하고, 모델은 정의 frontmatter 와 일치시킨다.

## 왜 스텝마다 프로세스인가 — 실측

2026-09-16, tick/code 세션 40개에서 **메인 컨텍스트를 키우는 출처**를 쟀다.

| 출처 | 호출 | ≈토큰 | 비중 |
|------|------|-------|------|
| 본체 Bash | 7,449 | 2,091,609 | **73%** |
| 본체 Read | 458 | 498,196 | 17% |
| subagent 반환 전부 | 588 | 236,832 | 7.6% |

**subagent 반환은 이미 1,121자 안팎으로 절단돼 들어온다** (step-developer 1,132 · reviewer 1,121 · adversary 1,121 — 균일한 것이 절단의 증거다). 즉 루프가 메인을 키우는 경로는 subagent 가 아니라 **본체가 직접 돌리는 도구 호출**이고, 그건 프로세스를 끊는 것 말고 줄일 방법이 없다.

비용 환산도 같은 방향이다. 같은 40세션에서 opus cache_read 가 전체 비용의 69.3%, sonnet subagent 전부가 1.5% 였다. **모델 티어를 내려서 얻을 것이 1% 미만인 반면, 컨텍스트 누적을 끊으면 세션 길이별 실측으로 턴당 $0.271 → $0.109 다.**

### 왜 루프 전체를 headless 1개로 빼는 것으로는 부족한가

그렇게 하면 **누적이 메인에서 러너로 옮겨갈 뿐이다.** 러너가 5라운드를 warm 하게 들고 있으면 그 러너가 두 번째 장기 세션이 된다 — 실측에서 44% 를 쓴 세션이 11일간 안 끊은 대화형 세션이었던 것과 같은 모양이다.

그래서 라운드가 아니라 **스텝**을 프로세스 경계로 삼는다. **대가는 스텝마다 내는 `cache_write` 다 (read 의 20배 단가). 그래서 스텝 수를 늘리지 않는다** — 라운드당 4개가 상한이고, 여기에 스텝을 더 쪼개면 절감이 상쇄된다.

## 결과문서 규약

경로 = `~/.claude/state/code-loop/{run}/` (`{run}` = `{타임스탬프}-{slug}`). **산출물이 아니라 루프 상태이므로 `docs/` 에 두지 않는다** — 레포에도, `docs/{product}/` 에도 남기지 않는다.

| 파일 | 쓰는 쪽 | 내용 |
|------|---------|------|
| `00-spec.md` | spec 스텝 | 요청 · 성공 기준 · 테스트 범위 · 비목표 · 커밋 type·scope · worktree 절대경로 · (형식 변경 시) 파급면·결함면 + `GATE:` 줄 |
| `dev-NN.md` | 개발자 | `FILES` / `TESTS` / `NOTES` / `BASELINE`(전·후) / **`WHY`** |
| `rev-NN-{correctness,design}.md` | 리뷰어 2인 | 각자의 판정 |
| `rev-NN.md` | merge 스텝 | 합본 + 반박 판정 결과 + `VERDICT:` 줄 |
| `adv-MM.md` | adversary | 재현 또는 시도 나열 + `VERDICT:` 줄 |
| `RESULT.md` | result 스텝 | 메인 반환용 — 변경 요약 · 라운드 로그 · 잔여 핸드오프 |

### VERDICT 계약 — 셸이 읽는 유일한 줄

판단은 모델이 하고 **분기는 셸이 한다.** 그 경계가 파일 마지막의 한 줄이다.

| 파일 | 허용 값 |
|------|---------|
| `00-spec.md` | `GATE: OK` · `GATE: TOO-LARGE` |
| `rev-NN.md` | `VERDICT: CLEAN` · `VERDICT: FINDINGS C=n H=n M=n` |
| `adv-MM.md` | `VERDICT: UPHELD` · `VERDICT: BROKEN` · `VERDICT: BROKEN-UNDECIDED` |

**줄이 없으면 루프를 중단한다 (fail-closed).** 셸은 "지적이 없다" 와 "판정을 못 받았다" 를 구분할 수 없고, 후자를 클린으로 읽으면 무검증 변경이 통과한다. `BROKEN-UNDECIDED` 만 예외로 캡에 넣지 않고 재스폰한다 — 코드 문제가 아니라 입력 조립 문제이기 때문이다 (code.md 의 `BROKEN: 판정 불가` 와 같은 처리).

### WHY 누적 — warm 유지를 대신하는 자리

`step-developer.md` 는 warm 유지를 의도로 명시한다 — *"앞 라운드에 무엇을 왜 했는지 기억하고 있어야 한다"*. 여기선 프로세스를 끊으므로 **그 기억을 문서가 진다.**

개발자는 `dev-NN.md` 에 `WHY` 를 반드시 남긴다: 무엇을 왜 그렇게 했는지, **남겨둔 선택지와 그 이유**, 반박(`REBUTTED`)이면 근거 3종(도달 불가 / 상위 처리 / 비목표 매칭) 중 무엇인지. 근거가 대화에 없으므로 **문서에 없으면 존재하지 않는 것과 같다.**

다음 라운드 개발자 입력에는 **`dev-*.md` 의 `WHY` 섹션만** 넣는다. 전문을 넣으면 프로세스를 끊은 값이 사라진다.

## dev-loop

```
NN = 1 .. 5
1. dev        fresh   입력 = 00-spec.md + rev-{NN-1}.md + dev-*.md 의 WHY
                      → dev-NN.md (FILES/TESTS/NOTES/BASELINE/WHY)
2. 리뷰어 2인  fresh 병렬  입력 = 00-spec.md + dev-NN.md + diff + rev-*.md 이력
                      → rev-NN-correctness.md · rev-NN-design.md
3. merge      fresh   합본 + REBUTTED 근거 3종 확인 + BASELINE 전·후 동일성 확인
                      → rev-NN.md + VERDICT
4. CLEAN → adv-loop / FINDINGS → NN+1 / 캡 소진 → adv 안 돈다 (깰 것이 없다)
```

3번이 `code.md` 가 "본체" 에 맡긴 일이다. **그 본체도 여기선 단발이다** — 판단은 하되 라운드를 들고 있지 않는다.

## adv-loop

```
MM = 1 .. 2
1. adversary  fresh(opus)  입력 = 00-spec.md + rev-*.md 전문 + dev-*.md + diff
                           → adv-MM.md + VERDICT
2. UPHELD           → 종료
   BROKEN           → dev 재진입(정규 캡 계상) → 리뷰 1라운드 → MM+1
   BROKEN-UNDECIDED → 입력 조립 오류. 캡에 넣지 않고 재스폰
```

**`BROKEN` 뒤 리뷰 1라운드는 뺄 수 없다.** adversary 는 깨는 역할이지 판정 역할이 아니라서, 그 수정분을 아무도 안 보면 무검증 변경이 클린을 달고 남는다. 이 라운드는 **정규 캡(5)에 계상한다** — 게이트 캡 2회가 정규 캡을 늘리는 통로가 되면 클린 직전에 라운드가 무한히 열린다.

**adversary 만 `opus` 고정이다.** 이 역할만 "리뷰어가 통과시킨 것을 깨는" 일이고, 못 깨면 루프가 거기서 끝나므로 마지막 방어선의 판단력은 내리지 않는다.

## 메인에 반환

러너는 `RESULT.md` 를 stdout 으로 내보낸다. **메인은 그것만 흡수한다 — 여기 없는 것은 메인에 존재하지 않는다.**

`RESULT.md` 가 없으면 루프가 완주하지 못한 것이고, 러너가 그 사실과 `--resume` 안내를 낸다. **조용히 성공으로 보이게 하지 않는다** — 메인이 잘못된 판단을 하는 것이 미완주보다 나쁘다.

**머지·push 하지 않는다 (§3).** worktree 와 커밋만 남기고 정착은 사용자가 한다.

## 재개

스텝 산출 파일이 이미 있으면 그 스텝을 건너뛴다. 중단된 run 은 `code-loop.sh --resume {run}` 으로 마지막 스텝 다음부터 이어진다 (`code-loop.sh status` 로 목록). **요청 원문은 `00-spec.md` 가 SSOT 다** — 재개할 때 요청을 다시 받지 않는다.

## 측정 — 이 커맨드를 계속 쓸 근거

`RESULT.md` 라운드 로그에 **dev 라운드 수 · adv 회차 · 각 VERDICT** 를 기록한다.

**개발자를 끊는 것이 이 커맨드의 유일한 실질 리스크다.** warm 유지보다 나쁘면 **라운드 수가 먼저 늘어난다** — 같은 지적이 재발하거나 반박 근거를 못 만들어서다. 비교 baseline = `/taskflow:code` 의 1라운드 클린율.

**라운드 수가 유의미하게 늘면 개발자만 warm 으로 되돌린다** (리뷰어·adversary 는 원래 cold 라 무관). 되돌릴 지점 = `bin/code-loop.sh` 의 dev 스텝 + 본 파일 §dev-loop.

## SSOT

| 조각 | SSOT |
|------|------|
| 루프 계약 전부 (1단계·크기 게이트·종료 조건·반박 판정·BASELINE·적대적 게이트·캡) | `custom-plugin/taskflow/commands/code.md` |
| 개발 Agent 계약 | `custom-plugin/taskflow/agents/step-developer.md` |
| 리뷰어 계약 2종 | `custom-plugin/taskflow/agents/reviewer-{correctness,design}.md` |
| 적대적 검증 계약 | `custom-plugin/taskflow/agents/adversary.md` |
| 리뷰어 합본 규약 | `custom-plugin/taskflow/commands/watch.md` §"코드 축" |
| **러너 (스텝 오케스트레이션 · VERDICT 분기 · 캡 · 재개)** | **`~/.claude/bin/code-loop.sh`** |
| worktree 생성·정착 | `custom-plugin/git/commands/{create,merge}.md` |

## Changelog

- 2026-09-16: 신설. 메인 컨텍스트 누적 실측(본체 Bash 73% · Read 17% · subagent 반환 7.6%)에 근거 — subagent 반환은 이미 절단돼 들어오므로 줄일 여지가 없고 남는 경로는 프로세스를 끊는 것뿐이었다. **루프 전체를 headless 1개로 빼는 안을 먼저 만들었다가 폐기했다**(러너가 라운드를 warm 하게 들면 누적이 메인에서 러너로 옮겨갈 뿐). 스텝을 경계로 삼는 현재 구조로 교체. 루프 계약 재정의 0 — 상태 매체만 warm → 결과문서로 바뀌었다. 드라이런 20케이스 통과(캡 소진·adv 재진입 계상·크기 게이트·VERDICT fail-closed·산출 미생성 재시도·재개 보존)
