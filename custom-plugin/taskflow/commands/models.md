---
description: 개발자·리뷰어 모델 전환 — code-loop 와 tick 이 같이 따르는 에이전트 정의의 model: 을 한 번에 바꾼다. 인자 없으면 현재 값 표시
allowed-tools: Bash
argument-hint: "[dev=opus|sonnet|haiku] [rev=opus|sonnet|haiku]  # 생략 = 현재 값 표시"
---

개발 루프의 모델 레벨을 바꾸는 단일 진입점이다. 역할별 모델은 에이전트 정의 frontmatter 의 `model:` 한 곳에만 있고, `custom-plugin/taskflow/bin/code-loop.sh` 와 `/taskflow:tick` 의 Agent spawn 이 모두 그 값을 읽는다. 그래서 여기서 바꾸면 두 경로가 함께 바뀐다.

```bash
bash ~/.claude/custom-plugin/taskflow/bin/set-models.sh $ARGUMENTS
```

| 역할 | 정의 파일 |
|---|---|
| `dev` | `agents/step-developer.md` |
| `rev` | `agents/reviewer-correctness.md` · `reviewer-design.md` · `cold-reviewer.md` |

- 실행 결과 표를 그대로 보고한다. 바뀐 파일은 git 추적 대상이라 커밋해야 다른 worktree·세션에도 남는다.
- **이미 돌고 있는 run 은 바뀌지 않는다** — code-loop 는 기동 시점에 모델을 읽는다.
- 한 번만 다른 모델로 돌리고 싶으면 정의를 바꾸지 말고 환경변수를 쓴다: `CODE_LOOP_MODEL_DEV=sonnet code-loop.sh …` (환경변수가 정의보다 우선).
- spec·merge·result 는 `CODE_LOOP_MODEL_SPEC`(기본 sonnet), adversary 는 `adversary.md`(opus 고정) — 이 커맨드의 대상이 아니다.

## 근거

2026-09-28 실측 (완료 run: sonnet-dev 9 · opus-dev 13): opus 개발자가 dev 라운드 2.2 → 1.4, run 당 환산 비용 $40.6 → $22.7, 벽시계 중앙 106 → 74분. 호출 1회는 opus 가 1.14배 비싸지만 호출 수가 1/3 로 줄었다. 표본이 작고 교차 배정이 아니었으므로 레벨은 다시 조정될 수 있다 — 그래서 이 전환을 한 줄 명령으로 둔다.
