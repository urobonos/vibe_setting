---
description: tick 무인 루프 기동·정지 — `/taskflow:tick` 을 **매번 새 프로세스**로 반복 실행해 컨텍스트 누적을 0 으로 만든다. harness `/loop` 이 한 세션에 iteration 을 쌓아 컨텍스트가 5배까지 늘던 문제의 대안. detach 기동이라 호출한 세션을 블로킹하지 않는다. 짝 = `/taskflow:tick`(1회분) · `/taskflow:control`(대기 큐)
allowed-tools: Bash
argument-hint: "[간격 — 60 / 30m / 1h, 생략 시 1800초] [N — 병렬 슬롯 수, 생략 시 1] | --once | stop [슬롯] | status"
---

`~/.claude/bin/tick-loop.sh` 의 thin wrapper. 로직 재구현 0 — 인자를 그대로 넘긴다.

```bash
bash ~/.claude/bin/tick-loop.sh "$@"
```

## 왜 `/loop` 이 아니라 이것인가

**`/loop 30m /taskflow:tick` 은 한 세션에 iteration 을 누적한다.** 2026-07-28 실측 — 세션 746244a3 이 step 7개를 530턴에 담는 동안 턴당 컨텍스트가 **116K → 595K (5.1배)** 로 늘었고, 그날 전체 토큰의 **97% 가 cache_read** 였다. 즉 비용의 대부분은 생성이 아니라 **같은 컨텍스트를 매 턴 다시 읽는 것**이다.

tick 은 설계상 stateless 다 — 상태는 working/ 문서와 REGISTRY 에 있고, 커맨드 자신이 "로직 재구현 0" 을 표방한다. **컨텍스트를 들고 있을 이유가 없다.** 프로세스를 끊으면 매 iteration 이 시작값으로 리셋된다 (headless 실측 첫 턴 76.8K — 대화형보다 40K 낮다. UI 관련 시스템 프롬프트 섹션이 빠진다).

| | `/loop 30m /taskflow:tick` | `/taskflow:tick-loop 30m` |
|---|---|---|
| iteration 간 컨텍스트 | 누적 (턴당 352K 까지) | **리셋 (76.8K 시작)** |
| 모델 | 세션 모델 | **sonnet** (`--model`) |
| 호출한 세션 | 그 세션에서 돎 | **detach — 블로킹 0** |

## 4 모드

| 호출 | 동작 |
|------|------|
| `/taskflow:tick-loop [간격] [N]` | detach 기동 **N 개**(기본 1). 빈 슬롯을 찾아 배정하고 즉시 반환 |
| `/taskflow:tick-loop --once` | **1회만** 실행하고 출력을 그대로 보여준다 (검증용, detach 안 함) |
| `/taskflow:tick-loop stop [슬롯]` | **graceful 정지** — 진행 중 tick 은 완주시킨다. 슬롯 생략 시 전체 |
| `/taskflow:tick-loop stop --now [슬롯]` | 즉시 정지 — 진행 중 tick 을 중단한다 |
| `/taskflow:tick-loop status` | 전 슬롯 생존 + 각 로그 마지막 줄 |

간격은 `60`(초) / `30m` / `1h` 를 받고 생략 시 1800초, 하한 10초. 모델·권한은 환경변수로 바꾼다 — `TICK_LOOP_MODEL`(기본 `sonnet`) · `TICK_LOOP_PERM`(기본 `auto`) · `TICK_LOOP_STOP_WAIT`(graceful 대기 상한, 기본 1800초).

**`auto` 는 실측으로 고른 값이다.** 2026-07-28 A/B — `acceptEdits` 는 sensitive file 승인 요청에서 멈춰 tick 이 파일을 못 고치고, `dontAsk` 는 "묻지 않고 **거부**" 라 Write 도구 자체가 차단된다("don't ask mode" 권한 정책). 무인 루프에는 승인할 사람이 없으므로 둘 다 쓸 수 없다.

### graceful stop

기본 `stop` 은 **진행 중이던 tick 을 죽이지 않는다.** 그 iteration 을 끝까지 마치게 두고, 다음 iteration 으로 넘어가지 않게 막는다. 작업 도중에 끊으면 step 이 어중간한 상태로 남기 때문이다.

```
graceful stop 요청 — 3개 슬롯, 진행 중 tick 은 완주합니다
  tick 종료 1/3 (slot 1)
  tick 종료 2/3 (slot 3)
  tick 종료 3/3 (slot 2)
전체 정지 완료
```

- **신호는 시그널이 아니라 파일**(`state/tick-loop/{슬롯}.stop`)이다. 시그널은 루프가 자식 claude 를 기다리는 동안 지연되고, 그때 자식을 죽이면 애초에 graceful 이 아니다.
- **대기 중에도 1초 안에 반응한다** — `sleep` 을 통째로 하지 않고 1초 단위로 쪼개 플래그를 확인한다.
- 대기 상한(기본 30분) 안에 안 끝나면 남은 슬롯 수를 알리고 `--now` 를 안내한다. 무한 대기는 터미널을 잠근다.
- **`--now` 를 남겨둔 이유** — tick 1회가 20분 걸리는 경우가 실재하므로 "지금 당장" 이 필요한 상황이 있다.

## 병렬 실행

**슬롯마다 독립 프로세스다.** 상태는 `state/tick-loop/{슬롯}.{pid,log}` 로 분리되고, 기동 시 빈 슬롯을 찾아 배정한다. 이미 쓰는 슬롯은 건너뛰므로 **여러 세션에서 띄워도 서로를 덮어쓰지 않는다.**

```
/taskflow:tick-loop 30m 3     ← 3개 병렬
/taskflow:tick-loop 30m       ← 빈 슬롯 하나에 1개 추가
/taskflow:tick-loop stop 2    ← 2번만 정지
/taskflow:tick-loop stop      ← 전체 정지
```

**왜 안전한가** — tick 이 `registry_claim`(lock 안 확인+add 원자)으로 step 을 배타 점유한다. 동시에 돌아도 같은 step 을 중복 작업하지 않고, 못 잡은 쪽은 `TAKEN` 을 받아 다음 후보로 넘어간다.

**동시 상한은 `min(16, cores−2)`** — §4.2 병렬 fan-out 과 같은 식이다(새 기준을 만들지 않는다). 초과 요청은 상한으로 줄이고 그 사실을 알린다.

### 왜 `tick-team` 이 없어졌나 (2026-08-04 폐기, 재제안 방지 기록)

**"leader 가 워커 Agent 를 spawn 해 병렬로 돌린다" 는 설계를 다시 제안하지 마라.** `/taskflow:tick-team` 이 정확히 그거였고, 아래 4축 실측 대조에서 3축이 열세라 §3 승인으로 폐기했다.

| | **`tick-loop N`** (채택) | `tick-team N` (폐기) |
|---|---|---|
| 워커 단위 | **독립 프로세스** | leader 프로세스 안의 subagent |
| leader 컨텍스트 | **없음** | **누적** (워커 보고를 계속 받는다) |
| 장애 격리 | **하나 죽어도 무관** | **leader 죽으면 전부 죽는다** |
| 기동 비용 | 슬롯마다 세션 시작 컨텍스트 | worktree 격리 200~500ms/워커 (유일한 우위) |

**결정적인 것은 leader 컨텍스트 누적이다.** 무인 루프의 존재 이유가 "컨텍스트 누적 0" 인데 leader 를 두는 순간 그 축이 무너진다 — 워커 보고가 leader 에 쌓여 장시간 운용에서 leader 가 먼저 한계에 닿는다. 기동 비용 우위(200~500ms)는 30분 주기 루프에서 무의미하다.

**병렬 자체는 사라지지 않았다** — 위 §"병렬 실행" 이 같은 축을 슬롯(독립 프로세스)으로 재구현했고, 배타 점유는 어느 쪽이든 `registry_claim` 원자성이 보장한다. 즉 tick-team 의 고유 payload 는 **병렬 축에 한해** 폐기 시점에 이미 없었다 (SSOT 2개 — §"하니스 자동 상속"·§"카탈로그 미등재 fallback" — 은 실재했고 `tick.md` 로 이관했다).

> **worktree 는 N 배로 늘어난다.** 각 tick 이 자기 worktree 를 만들므로 진행 가능 step 보다 많은 슬롯은 전부 "진행 가능 없음" 으로 헛돌며 시작 컨텍스트만 태운다. `/taskflow:control` 로 대기 물량을 보고 N 을 정한다.

## §3 Checkpoint

- **기동 = 사용자의 명시 호출이 승인이다.** Claude 가 자발적으로 이 커맨드를 호출하지 않는다.
- **정지도 사용자 몫이다.** no-op 이 여러 번 이어져도 그것은 정지 근거가 아니다 — 무인 루프는 조용한 게 정상 동작이다. SSOT = 메모리 `feedback_no-autonomous-loop-kill`.
- 루프 안에서 도는 것은 `/taskflow:tick` 이므로 **머지·push·task Done 은 여전히 안 한다** (tick.md §3 그대로 상속). worktree·gate·dangerous-ops 가드도 각 tick 프로세스에서 정상 작동한다.
- `--permission-mode auto` 는 **권한 프롬프트**만 자동화한다. hook(worktree·gate·dangerous-ops·branch-enforce)은 permission-mode 와 무관하게 그대로 돌며 §3 매칭 조작을 exit 2 로 차단하므로, 이 커맨드가 §3 우회 통로가 되지 않는다.

## 로그

슬롯별로 `~/.claude/state/tick-loop/{슬롯}.log` 에 append (`{슬롯}` = 슬롯 번호 `1`~`min(16, cores-2)`, 단발 실행은 `once`). headless 라 화면 출력이 없어 이 파일이 유일한 추적 수단이다. **회전하지 않으므로** 장기 운용 시 크기를 확인한다.

## SSOT

| 조각 | SSOT |
|------|------|
| **러너 본체** | `~/.claude/bin/tick-loop.sh` |
| iteration 1회분 로직 | `custom-plugin/taskflow/commands/tick.md` |
| 대기 큐 소비 | `custom-plugin/taskflow/commands/control.md` |
| 정지 금지 근거 | 메모리 `feedback_no-autonomous-loop-kill` |

## 호출 예

```
/taskflow:tick-loop --once      ← 검증: 1회 돌려 permission·모델 확인
/taskflow:tick-loop 30m         ← 30분 간격 1개
/taskflow:tick-loop 30m 3       ← 30분 간격 3개 병렬
/taskflow:tick-loop status      ← 전 슬롯 상태
/taskflow:tick-loop stop 2      ← 2번 슬롯만 정지
/taskflow:tick-loop stop        ← 전체 정지
```

## Changelog

- 2026-08-04: **`/taskflow:tick-team` 폐기 흡수 (§3 사용자 승인).** 병렬 축은 본 커맨드의 슬롯(독립 프로세스)이 이미 대체하고 있었고, 4축 대조 3축 열세(워커 단위·leader 컨텍스트 누적·장애 격리)가 근거. 대조표는 §"왜 `tick-team` 이 없어졌나" 로 남겨 재제안을 막는다. tick-team 이 갖고 있던 SSOT 2개(`하니스 자동 상속`·`카탈로그 미등재 fallback`)는 `tick.md` 로 이관
- 2026-07-28: graceful stop — 진행 중 tick 을 완주시키고 다음 iteration 만 막는다. 즉시 중단 = `stop --now`. 시그널 대신 플래그 파일
- 2026-07-28: 병렬 슬롯 — `tick-loop <간격> <N>`, 상태를 `state/tick-loop/{슬롯}.*` 로 분리. 상한 `min(16, cores−2)`
- 2026-07-28: 자식 kill 시 루프 잔존 픽스 (exit ≥128 break, `trap INT TERM`, `stop` 이 자식 먼저 kill)
- 2026-07-28: 신설 — `/loop` 의 컨텍스트 누적(실측 5.1배) 대안. 매 iteration 새 프로세스 + detach
