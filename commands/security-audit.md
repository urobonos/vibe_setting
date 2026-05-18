---
description: 7개 도메인(공통/PHP·CI4/MySQL 8.x/AWS Lambda/CI·CD·공급망/Docker·컨테이너/프로세스) 통합 보안 감사 — OWASP Top 10 / CWE Top 25 / OWASP ASVS L1 등 14개 보안 프레임워크 적용
allowed-tools: Skill, Bash, Read, Glob, Grep, Agent
argument-hint: "[모듈|경로]  # 생략 시 변경 파일 자동 식별"
---

`security-audit` 스킬의 슬래시 진입점 (thin wrapper).

**SSOT:** 절차·14개 보안 프레임워크·도메인별 트리거·4등급 (Critical/High/Medium/Low) 판정 기준·산출물 템플릿 = `skills/security-audit/SKILL.md`. 본 파일은 frontmatter (description / allowed-tools / argument-hint) 만 정의합니다.

호출 예: `/security-audit member` / `/security-audit app/Modules/Commerce/` / `/security-audit` (변경 파일 자동)
