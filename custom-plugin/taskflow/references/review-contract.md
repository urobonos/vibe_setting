# 분리 루프 공유 계약 (review-contract)

개발 Agent ↔ cold 리뷰어 분리 루프의 공유 규칙 SSOT. `code`·`code-loop`·`review`·`tick`·`watch` 가 이 파일을 참조한다 — 커맨드끼리 서로의 본문을 참조하지 않기 위해 커맨드 밖으로 뺐다 (2026-09-28, 원문 무수정 이동: `watch.md` §"코드 축" · `tick.md` §"step 개발"·§"하니스 자동 상속"·§"카탈로그 미등재 fallback").

## 코드 축 — 변경분 리뷰 (무인 코드리뷰 계약 SSOT)

**본 절이 무인 코드리뷰 계약의 SSOT 다 — `/taskflow:tick` 의 리뷰 루프도 같은 계약을 쓴다** (`tick.md` §"step 코드리뷰 루프" 는 여기 포인터). 계약이 두 곳에 복붙되면 갈라지고, 갈라지는 순간 tick 이 통과시킨 것을 watch 가 **다른 기준으로** 반려해 왕복이 되살아난다.

**`reviewer-correctness` · `reviewer-design` Agent 2개를 병렬 spawn** 해 **변경분만** 리뷰한다 (`subagent_type: taskflow:reviewer-correctness` · `taskflow:reviewer-design` — 플러그인 agent 는 `plugin:name` 형식이다. 정의 = `custom-plugin/taskflow/agents/reviewer-correctness.md` · `reviewer-design.md`). 전체 코드베이스 감사가 아니다.

- **본체가 조립하는 것은 입력뿐이다** — worktree diff(또는 커밋 범위) + 그 step 문서의 §계획·DoD + **개발 Agent 반환의 `BASELINE`**. 두 리뷰어는 **같은 입력**을 받는다.
- **`BASELINE` 을 빼지 않는다.** 리뷰어는 `근거: 실행` 을 계약으로 요구받는데(§6) 어느 명령이 이 변경을 덮는지를 매번 새로 찾는다 — 그 탐색이 전량 스위트로 넓히려는 유인이 되고, 이 환경에서 그건 실 테이블을 갈아엎는다. 개발 Agent 가 이미 돌려서 알고 있는 것을 전달만 하면 된다. 없으면(구 경로·문서 축) 그 사실을 입력에 명시한다 — 조용히 비우면 리뷰어가 스스로 찾는다.
- 리뷰 관점 7축은 **둘로 갈라져 있다** — 기능 정합(§1 경계값·예외·회귀·동시성 / §5 호출부 전수 / §6 실행 검증) = `reviewer-correctness`, 설계 정합(§2 보안 / §3 단순성 / §4 재사용 / §7 범위) = `reviewer-design`. 판정 등급·"코드 수정 금지"·반환 양식과 함께 **전부 agent 정의에 박혀 있다**. 여기서 다시 적지 않는다.
- **한 패스로 7축을 보지 않는다 (2026-08-19 축 분리).** 실측이 필요한 무거운 축(§6 돌려봐야 검증)이 얕아진다 — 구 `cold-reviewer` 정의 스스로가 그렇게 적어뒀다.
- 반환 = 리뷰어별 `VERDICT: CLEAN | FINDINGS` + Critical~Low 지적의 `file:line` (양식 SSOT = agent 정의).

**두 반환을 합치는 규칙 (본 절이 SSOT — 2인을 띄우는 모든 경로가 이걸 쓴다).**

| 상황 | 처리 |
|------|------|
| 같은 `file:line` 에 양쪽 지적 | **높은 등급을 채택**한다 |
| 상대 축 태그(`[design]`·`[correctness]`)가 붙은 지적 | **본체가 등급을 매기지 않는다.** 루프 경로면 다음 라운드에 해당 리뷰어가 판정하고, 1회 경로면 태그를 단 채로 잔여에 남긴다 |
| 한쪽 `CLEAN` · 한쪽 `FINDINGS` | 합본은 `FINDINGS` 다. 한 축이 깨끗한 것은 종료 근거가 아니다 |

**왜 프롬프트가 아니라 agent 정의인가.** 계약을 매번 프롬프트로 조립하면 라운드마다 문구가 달라지고 그 편차가 곧 리뷰 편차다(아래 §"watch 의 리뷰는 재확인이다" 가 인정하는 그 편차). 정의에 박아두면 spawn 마다 변하는 것이 diff 하나뿐이 된다.

**리뷰어는 코드를 고치지 않는다.** 두 정의 모두 Edit·Write 도구가 없는 것이 그 강제다 (`dev-team` FE 멤버를 `Explore` 로 두는 것과 같은 기계적 차단 — 지시문은 어길 수 있어도 없는 도구는 못 쓴다). `simplify` 처럼 수정까지 하는 경로를 타지 않는다 — 무인 루프가 리뷰하면서 코드를 바꾸면 리뷰 대상 자체가 움직인다.


## step 개발 (Agent 위임 — 본체는 코드를 쓰지 않는다, 필수)

step 개발은 **`step-developer` Agent 1개**에 위임하고(`subagent_type: taskflow:step-developer` — 플러그인 agent 는 `plugin:name` 형식이다. 정의 = `custom-plugin/taskflow/agents/step-developer.md`), tick 본체는 **지휘·기록·상태 전이만** 한다. 개발자와 "리뷰 지적 수정자" 가 같은 인격이면 자기가 고친 것을 자기가 통과시키는 확인 편향이 남는다 — 리뷰를 cold 로 뺀 것과 같은 이유다.

**코드를 쓰는 기준(단순성·재사용·"돌려봐야 검증"·호출부 전수·범위 고수)·금지사항·반환 양식은 agent 정의에 있다.** 리뷰어와 같은 이유로 프롬프트에 매번 적지 않는다. 본체가 조립하는 것은 **worktree 경로 + 그 step 의 §계획·§파급면·§결함면·DoD + (반려 소비 시) 호출부 grep 결과** 뿐이다.

| 주체 | 하는 일 |
|------|--------|
| tick 본체 | claim · worktree 생성 · 개발 Agent 지휘 · 리뷰어 spawn · 문서 기록 · 상태 전이 |
| **개발 Agent** (warm, 1개) | 코드 작성 + 리뷰 지적 수정 |
| 리뷰 Agent (cold, 라운드마다 신규) | 판정만 · 코드 수정 금지 (§"step 코드리뷰 루프") |
| **적대적 red-team** (cold, 게이트 1~2회) | 클린 반증만 · 코드 수정 금지 (§"적대적 검증 게이트") |

**개발 Agent 는 라운드마다 새로 뜨지 않는다.** 최초 1회 spawn 하고 리뷰 지적은 `SendMessage` 로 **같은 Agent** 에 이어 보낸다. 새로 띄우면 §계획·DoD·이미 쓴 코드를 매 라운드 다시 읽어야 하고, 리뷰 한도가 5회라 최악에 5회 재구축이다. 갈아끼우는 쪽은 리뷰어뿐이다.

**`isolation: worktree` 를 쓰지 않는다 (필수).** 본체가 만든 worktree 경로를 프롬프트로 넘겨 **그 안에서** 작업시킨다. isolation 을 켜면 하니스가 별도 worktree 를 파서 커밋이 그 step 의 `wip/*` 가 아닌 곳에 쌓이고, `머지 전 리뷰 포인트` 에 적은 경로와 실제 커밋 위치가 갈라진다 — watch 의 머지 사다리가 그 경로를 믿고 정착시키므로 어긋남이 조용히 진행된다. tick 은 단일 워커라 격리가 애초에 불필요하다 — 병렬이 필요하면 `tick-loop N` 이 **슬롯마다 독립 프로세스**를 띄우므로 프로세스 경계가 격리를 대신한다.

**Agent 는 코드만 쓴다.** §실행·`## 변경 영향 기록`·Before/After 는 **본체가** Agent 반환(`FILES`/`TESTS`/`NOTES`)으로 쓴다 (§"step 상세 기록" 재사용 — Agent 에 문서 양식을 가르치지 않는다).

**커밋도 본체가 한다.** 리뷰어가 보는 입력이 **미커밋 diff** 라 개발 Agent 가 중간에 커밋하면 리뷰어에게 빈 diff 가 간다. 커밋은 리뷰 루프가 클린이 된 뒤 4단계에서 본체가 한다 (`머지 전 리뷰 포인트` 기록과 같은 시점).

**두 Agent 모두 모델이 정의에 고정돼 있다 — 리뷰어·개발자 모두 `sonnet`.** `tick-loop.sh:29` 의 세션 기본값이 `sonnet` 이라(`${TICK_LOOP_MODEL:-sonnet}`) **모델을 생략하면 무인 경로에서만 sonnet 을 상속**한다 — `orchestration` §1.1 이 전제하는 "생략 = opus 상속" 이 여기서만 깨진다. 값이 지금 세션 기본값과 우연히 같아도 **명시는 유지한다** (기본값이 바뀌면 조용히 따라 움직인다). 본체(claim·문서 기록·상태 전이)는 기계적이라 sonnet 으로 충분하다. **리뷰어가 최종 방어선이라는 사실은 하향 후에도 변하지 않는다** — 개발자는 §계획·DoD 라는 대조 기준을 받고 들어가지만 리뷰어는 그것을 만들어내야 하고, 놓친 결함은 리뷰어 쪽에서만 새어 나간다. 관측 = 반려 라운드 수 + **머지 후 결함** (Changelog 2026-08-10).

**라운드 종료마다 변경 실재를 확인한다.** Agent 가 코드를 쓰지 않고 텍스트만 돌려주는 실패 모드가 실재한다.

```bash
git -C "$WORKTREE" status --porcelain      # 빈 결과 = 개발 실패 (리뷰로 넘기지 않는다)
```

빈 결과를 그대로 리뷰에 넘기면 리뷰어가 빈 diff 를 `[High]` 판정 불가로 되돌려 라운드만 소진된다.

**hook 은 자동 상속된다** (아래 §"하니스 자동 상속"). 개발 Agent 의 Write·Bash 에도 worktree-enforce·dangerous-ops-guard·§3 가드가 걸리므로 룰 재주입이 불요하다. 미등재 세션 대응은 §"카탈로그 미등재 fallback".

## 하니스 자동 상속 (2026-07-23 실측)

**subagent 도구 호출에도 PreToolUse hook 이 적용된다** — subagent 의 Write 를 `worktree-enforce` 가, `rm -rf` 를 `dangerous-ops-guard` 가 차단함을 실측 확인(2026-07-23, Agent probe). 따라서 tick 이 spawn 하는 개발·리뷰 Agent 에도 하니스 룰(gate·worktree·§3 가드)이 **자동 상속**되고, Skill 도구로 `/taskflow:tick` 을 호출하는 쪽(`tick-loop` 의 자식 세션)도 tick 명세의 claim/auto/step 로직을 그대로 물려받는다 → **호출자별 룰 재구현 0.**

이것이 무인 경로가 "§3 우회 통로" 가 아닌 기계적 근거다 — 지시문이 아니라 hook 이 막는다.

## 카탈로그 미등재 fallback (SSOT — slash·agent 공통)

**카탈로그는 세션 시작 시 로드된다.** 그래서 정의를 만든 **당일 세션**에서는 신규 slash·신규 agent 가 미등재고, 다음 세션부터 정상 호출된다. 무인 루프는 그 하루를 멈출 수 없으므로 fallback 을 탄다.

| 대상 | 미등재 시 |
|------|----------|
| **slash** (`taskflow:tick` 등 Skill 호출) | 그 커맨드 문서의 해당 단계를 `bash` 로 직접 수행 (예: tick 1단계 = `working_scan` + `registry_claim`) |
| **agent** (`taskflow:reviewer-correctness` · `taskflow:reviewer-design` · `taskflow:step-developer` · `taskflow:adversary`) | `general-purpose` 로 spawn 하되 **정의 파일 전문을 프롬프트 앞에 붙이고 `model` 을 호출 파라미터로 명시** — 리뷰어 = `sonnet`, 개발자 = `sonnet`, `taskflow:adversary` = `opus`. **리뷰어 2개는 fallback 에서도 각각 띄운다** (한 프롬프트에 두 정의를 합치면 축 분리 이유였던 §6 얕아짐이 그대로 돌아온다) |

**agent fallback 에서 `model` 을 생략하면 안 된다.** 정의를 안 타면 모델도 세션 기본값을 상속한다(`tick-loop.sh` = sonnet). 지금은 두 값이 우연히 목표값과 같지만 **세션 기본값이 바뀌면 양쪽 다 조용히 흔들린다.** 상속에 기대지 말고 두 값을 각각 적는다. 계약 없이 도는 것보다 정의 전문을 붙여 도는 편이 낫다.

