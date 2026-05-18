---
description: Multi-Agent Team Debate Protocol — 4 에이전트팀 (각 팀 4 Agent = 총 16 Agent) 풀-병렬 spawn 토론. 의견 갈림·트레이드오프·아키텍처 결정 시 호출
allowed-tools: Skill, Bash, Read, Glob, Grep, Agent
argument-hint: "<토론 주제>  # 예: 'RDS Proxy vs Lambda 직접 연결'"
---

`debate` 스킬의 슬래시 진입점 (thin wrapper).

**SSOT:** 4그룹 페르소나·팀별 spawn prompt·Lead 종합 절차·결과 보고 양식 = `skills/debate/SKILL.md`. 본 파일은 frontmatter (description / allowed-tools / argument-hint) 만 정의합니다.

호출 예: `/debate "RDS Proxy vs Lambda 직접 연결"` / `/debate "Modular Monolith vs Microservices"` / `/debate "API 키 캐시 전략"`

**Note:** `/토론` 슬래시도 동일 진입 (별 thin wrapper, 2026-05-15 신설).
