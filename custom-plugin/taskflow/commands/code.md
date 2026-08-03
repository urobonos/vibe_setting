---
description: 분리 루프 1회 — 지금 이 요청을 `step-developer` 가 worktree 안에서 구현하고 `cold-reviewer` 가 클린까지 판정한다. 짠 쪽과 본 쪽을 갈라놓는 것이 값이다. 문서·상태 전이 없음, 머지 안 함(§3). 짝 = `/taskflow:tick`(문서 기반 무인) · `/taskflow:execute`(대화형 self review)
allowed-tools: Bash, Read, Glob, Grep, Agent, Skill, PowerShell
argument-hint: "{구현 요청} — 필수. 생략 시 진행 중 working/ step 을 쓰려면 /taskflow:tick 을 쓴다"
---

**짠 쪽과 본 쪽을 갈라놓는 루프**를 지금 이 요청에 1회 돌린다. 페르소나가 값이 아니다 — 본체는 이미 같은 사고방식을 갖고 있고(`PERSONA.md` 매 턴 주입), 그럼에도 자기가 방금 쓴 코드에서는 과설계가 안 보인다. `BoardController.php:947` 이 `tests/Modules/Board` **199 tests green** 인 채로 통과한 게 그 증거다.

## 무엇을 하지 않는가

**대상을 고르지 않는다.** claim·의존 판정·Status 분기가 없다 — 지금 받은 요청이 대상이다. 그게 `/taskflow:tick` 과의 유일한 실질 차이다.

**문서를 만들지 않는다.** working/ 문서·§실행·상태 전이가 없다. 결과는 응답으로 보고한다. 문서가 필요한 규모면 `/taskflow:plan` → `/taskflow:tick` 이 맞다.

**머지·push 하지 않는다 (§3).** worktree 와 커밋만 남기고 정착은 사용자가 한다.

## 흐름

```
1. 범위 확인 : 요청 → 대상 파일·성공 기준 1~3줄로 확정 (이게 리뷰 대조 기준이 된다)
2. worktree  : git -C {repo} worktree add ~/.claude/worktrees/{sid8}-{slug} -b wip/{sid8}-{slug}
3. 개발      : subagent_type: taskflow:step-developer  (요청 + 성공 기준 + worktree 경로)
4. 리뷰 루프 : subagent_type: taskflow:cold-reviewer   (라운드마다 새로)
              → 지적 ≥1 이면 개발 Agent 에 SendMessage → 재리뷰 (클린까지, 5회)
5. 보고      : 변경 요약 + 라운드별 지적 수 + 잔여. 커밋만 남기고 정지
```

각 단계 계약은 전부 기존 SSOT 를 그대로 쓴다 — **본 커맨드에 재정의가 없다.**

| 조각 | SSOT |
|------|------|
| 개발 Agent 계약 (코드 기준·금지사항·반환 양식·`model: opus`) | `custom-plugin/taskflow/agents/step-developer.md` |
| 리뷰어 계약 (판정축·등급·반환 양식·수정 불가) | `custom-plugin/taskflow/agents/cold-reviewer.md` |
| 루프 운영 (warm 유지·`isolation` 금지·변경 실재 확인·5회 한도) | `custom-plugin/taskflow/commands/tick.md` §"step 개발" + §"step 코드리뷰 루프" |
| worktree 생성·정착 절차 | `custom-plugin/git/commands/{create,merge}.md` |

## 대조 기준 — 1단계를 건너뛰지 않는다

문서 기반 경로는 §계획·DoD 가 리뷰 기준이 된다. 여기엔 그게 없으므로 **1단계에서 확정한 성공 기준이 그 자리를 대신한다.** 이걸 안 적고 개발에 들어가면 `cold-reviewer` 가 대조할 것이 없어 `VERDICT: FINDINGS` + `[High] 판정 불가` 로 되돌아온다 (fail-closed — 정의에 그렇게 박혀 있다).

성공 기준은 검증 가능해야 한다. "동작하게" 는 기준이 아니다 — "이 함수가 X 입력에 Y 를 반환" 또는 "기존 테스트 N개 green 유지" 처럼 쓴다.

## 5회를 소진하면

지적이 남은 채로 정지하고 보고한다. **클린이 아닌 것을 클린으로 만들지 않는다.** worktree 는 그대로 두므로 이어서 `/taskflow:code` 를 다시 부르거나 직접 고치면 된다.

지적이 §3(비가역·외부 시스템·광범위 아키텍처)에 걸리거나 요청 범위 자체를 바꿔야 풀리면 고치지 말고 정지 + 보고한다 (`execute.md` §"결정 escalation ladder" 정합).

## 언제 이걸 쓰고 언제 다른 걸 쓰나

| 상황 | 진입점 |
|------|--------|
| 지금 이 요청을 분리 루프로 맡기고 싶다 | **`/taskflow:code`** |
| working/ 문서의 step 을 진행하고 싶다 | `/taskflow:tick {작업명}` |
| 무인으로 계속 돌리고 싶다 | `/taskflow:tick-loop` |
| 대화하며 같이 짜고 싶다 | `/taskflow:execute` |

## §3 Checkpoint 우선 적용

- 본 커맨드는 §3 우회 통로가 아니다. 개발 Agent 의 Write·Bash 에도 `worktree-enforce`·`dangerous-ops-guard`·`branch-enforce` 가 그대로 걸린다 (`tick-team.md` §"하니스 자동 상속" 실측).
- **머지·push·master/main 접근은 하지 않는다.** worktree 정착은 사용자 명시 승인 후 `/git:create`·`/git:merge`.

## 호출 예

```
/taskflow:code MemberService 의 코인 차감을 트랜잭션으로 묶어라
/taskflow:code BoardRepository 에 소프트 삭제 필터를 추가하고 호출부 전건 반영
```

## Changelog

- 2026-07-31: 신설 — tick 의 루프 코어를 문서·claim 없이 단발로 쓰는 진입점. 로직 재구현 0(계약 전부 포인터)
