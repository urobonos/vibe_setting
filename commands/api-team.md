---
description: API 추가/디버그 시 FE+BE+인프라 3-멤버 병렬 spawn 영향분석 팀
allowed-tools: Skill, Bash, Read, Glob, Grep, Agent, Task
argument-hint: <add|debug> <METHOD> <PATH> [추가 컨텍스트]
---

API 추가/오류 시 FE+BE+인프라 3-멤버 병렬 영향 분석을 수행한다.

> **[SSOT 일원화]** 본 슬래시 커맨드는 `api-team` 스킬의 thin wrapper. 인자 형식·진입 신호만 본 파일에서 정의하며, **모든 절차·페르소나·멤버 spawn prompt·산출물 템플릿·가드는 `skills/api-team/SKILL.md` 가 SSOT**. 두 파일 내용 충돌 시 skill SSOT 우선.

## 사용법

```
/api-team add {METHOD} {PATH} [요지]
/api-team debug {METHOD} {PATH} [에러 메시지]
```

**예시:**
- `/api-team add POST /v1/orders 주문 생성 API 추가`
- `/api-team debug GET /v1/orders/{id} 500 internal error`

## 인자 형식

1. **첫 번째 = 모드** — `add` (3-레포 반영 체크리스트) / `debug` (3-레포 가설 우선순위). 누락·오타 시 한 줄 확인 후 진행.
2. **두 번째 = HTTP METHOD** — GET / POST / PUT / DELETE / PATCH 등.
3. **세 번째 = PATH** — `/v1/orders` 같은 엔드포인트 (`{id}` path parameter 포함 가능).
4. **나머지 = 모드별 컨텍스트** — `add`: 추가 요지 / `debug`: 에러 메시지·HTTP 상태·스택 발췌.

## 절차

`api-team` 스킬 §1 (호출 방식) → §2 (모드) → §4 (작동 흐름 — 입력 정규화·3-멤버 병렬 spawn·결과 종합·산출물 작성) → §6 (멤버 spawn 템플릿) → §7 (가드) 를 그대로 따른다.

산출물 경로: `~/.claude/docs/claude-harness/output/api-impact/{YYYY-MM-DD}-{slug}-{add|debug}.md` (Gate-0 직행, gate-enforce.sh 면제).
