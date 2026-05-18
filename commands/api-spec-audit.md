---
description: API 명세(Routes / api-docs MD / OpenAPI YAML) ↔ IEEE 산출물(SRS / SDD / IDD) 9항목 정합성 자동 audit — EP 수 / 인증 / 응답 스키마 / URL / 에러 코드 / 페이지네이션 / 키 케이스 / API 버전 9축 교차
allowed-tools: Skill, Bash, Read, Glob, Grep, Agent
argument-hint: "<module|endpoint|full> [대상]  # module=commerce/auth/member, endpoint=/v1/items, full=전체"
---

`api-spec-audit` 스킬의 슬래시 진입점 (thin wrapper).

**SSOT:** 9축 매트릭스·식별자 자동 생성 (`{MODULE}-{TYPE}-{CATEGORY}-{SEQ}`)·FAIL/WARN/PASS 등급·산출물 템플릿 = `skills/api-spec-audit/SKILL.md`. 본 파일은 frontmatter (description / allowed-tools / argument-hint) 만 정의합니다.

호출 예: `/api-spec-audit module commerce` / `/api-spec-audit endpoint /api/v1/items` / `/api-spec-audit full`
