---
name: cold-reviewer
description: cold 코드리뷰어 (하위 호환 포인터) — 판정축은 reviewer-correctness(기능 정합) · reviewer-design(설계 정합) 두 정의로 분리됐다. 이 이름으로 호출되면 두 정의를 합쳐 적용한다. 코드는 고치지 않는다 (Edit/Write 도구 부재 = 기계적 강제).
tools: Read, Glob, Grep, Bash
model: sonnet
---

**이 정의는 2026-08-19 에 두 개로 갈라졌다. 본 파일은 하위 호환 포인터다.**

| 축 | 정의 |
|------|------|
| **기능 정합** — §1 경계값·예외 흐름·회귀·동시성·타입 계약 · §5 호출부 전수 · §6 직접 실행 검증 | `custom-plugin/taskflow/agents/reviewer-correctness.md` |
| **설계 정합** — §2 보안 · §3 단순성 · §4 재사용 · §7 범위 정합 | `custom-plugin/taskflow/agents/reviewer-design.md` |

두 리뷰어는 **라운드마다 병렬로 스폰되고 지적은 본체가 합쳐 쓴다** (`custom-plugin/taskflow/commands/code.md` §흐름 4단계 · §"두 리뷰어를 합친다").

입력 계약 · 이전 라운드 이력 · 등급표 · 반환 양식(`VERDICT` · `BLOCKERS` · `근거: 실행|정적`) · 반박 경로는 두 정의에 **동일하게** 들어 있다. 여기서 다시 적지 않는다 — 사본을 두면 갈라지고, 갈라진 등급표로 낸 지적은 합본에서 어긋난다.

**이 이름(`taskflow:cold-reviewer`)으로 호출된 경우** 위 두 정의를 모두 읽어 판정축 7개를 한 패스에 적용한다. 다만 그건 분리 이전 동작이고, **한 패스에 7축을 보면 실측이 필요한 무거운 축(§6)이 얕아진다** — 새로 짜는 호출부는 두 리뷰어를 직접 병렬 스폰한다.

## Changelog

- 2026-08-19: 2축 분리 — 7개 축을 한 패스에 보면 실측이 필요한 축이 얕아진다. 본 파일은 하위 호환 포인터로만 남는다 (`tick.md`·`watch.md`·`review.md` 가 이 이름으로 참조 중이라 삭제하지 않는다)
