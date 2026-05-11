---
description: API 추가/디버그 시 FE+BE+인프라 3-멤버 병렬 spawn 영향분석 팀
allowed-tools: Skill, Bash, Read, Glob, Grep, Agent, Task
argument-hint: <add|debug> <METHOD> <PATH> [추가 컨텍스트]
---

`api-team` 스킬의 슬래시 진입점 (thin wrapper).

**SSOT:** 절차·페르소나·멤버 spawn prompt·인자 정규화·산출물 템플릿·가드 = `skills/api-team/SKILL.md`. 본 파일은 frontmatter (description / allowed-tools / argument-hint) 만 정의합니다.

호출 예: `/api-team add POST /v1/orders 주문 생성 API 추가` / `/api-team debug GET /v1/orders/{id} 500 internal error`
