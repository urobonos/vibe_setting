---
parent_skill: orchestration
section: vibe-coding-group
생성일: 2026-05-11
---

# Vibe Coding Group Protocol

> **부모 스킬:** [`../SKILL.md`](../SKILL.md). 본 파일은 SKILL.md §5 Vibe Coding Group 분리 산출물.

사용자가 "바이브코딩" 지시 시 활성화. 3-Team 대신 Lead가 미니 사이클을 자체 완결하는 경량 모드.

## 5.1. 3-Team vs Vibe Group

| 항목 | 3-Team | Vibe Group |
|------|--------|------------|
| 트리거 | 기본값 | "바이브코딩" |
| 구조 | 3팀 순차 | 도메인별 자율 팀 병렬 |
| Context Passing | 팀 간 순차 전달 | Lead 내부 자체 해결 |
| 적합 | 복잡·대규모·보안 민감 | 독립 기능 병렬, CRUD, 리팩토링 |

## 5.2. Vibe Group 등급

| 등급 | 기준 | Group 수 | 승인 |
|------|------|---------|------|
| **S** | 단일 독립 기능 | 1개 | 1회 |
| **M** | 2~3개 독립 기능 | 2~3개 병렬 | 1회 |
| **L** | 4개+ 독립 기능 | 4개+ 병렬 | 2회 |

## 5.3. 미니 사이클 (6단계)

1. **분석:** Read/Grep/Glob으로 탐색, 영향 범위 파악
2. **설계:** 방향 자체 판단, 아키텍처 정합성 확인
3. **개발:** 직접 구현 또는 멤버 spawn
4. **검수:** Reviewer 관점 자체 리뷰
5. **QA:** 테스트 작성/실행
6. **반환:** diff + 테스트 결과 + 이슈 대시보드

- Critical/High → Stage 3으로 회귀 (최대 3회)
- 3회 미해소 → Orchestrator 에스컬레이션

## 5.4. Lead 페르소나

```
[Lead Authority] Orchestrator 권한을 위임받은 Vibe Group Lead.
- 미니 사이클 6단계를 자체 완결하여 "완제품" 반환.
- 필요 시 멤버/3-Consultants spawn 가능.
- 반환 후 즉시 terminate.

[Vibe Group Task]
- Group ID: {Group-ID}
- 작업 목표: {Task Goal}
- 작업 범위: {파일/모듈 목록}
```

## 5.5. 3-Team 전환 조건
- Group 간 인터페이스 충돌 2건+
- Critical 3회 회귀 미해소
- 사용자 명시적 요청

전환 시 기존 결과물은 Team 3(Execute)의 입력으로 취급.
