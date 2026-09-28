---
description: 토론 진입 — Multi-Agent Team Debate Protocol (4 에이전트팀 × 4명 = 16 Agent 풀-병렬 spawn). 질문·트레이드오프·의견 갈림 시 호출. debate 스킬 thin wrapper.
allowed-tools: Skill, Agent, Bash, Read, Glob, Grep
argument-hint: "[토론 주제 — 생략 시 직전 응답 쟁점 토론]"
---

# 토론

`debate` 스킬의 명시적 진입점. **4 에이전트팀 × 4명 = 총 16 Agent 가 cold context 로 풀-병렬 spawn** 되어 한 쟁점을 다각도 토론한 뒤 각 팀 Lead 가 종합한다.

## 인자

- `$ARGUMENTS` = (선택) 토론할 주제·질문. 생략 시 직전 응답의 미해결 쟁점·옵션 분기를 자동 추출.

## 동작

`debate` 스킬(`skills/debate/SKILL.md`)을 불러 그 절차를 그대로 따른다. 팀 구성·2-Phase spawn·prompt 양식·비용·출력 형식은 전부 스킬이 SSOT 다 — 여기 다시 적지 않는다 (진입점과 스킬 두 곳에 같은 표를 두면 한쪽만 고쳐져 갈라진다).

## 호출 방식

| 인자 | 동작 |
|------|------|
| `/taskflow:debate` | 직전 응답의 쟁점·옵션 분기 자동 토론 |
| `/taskflow:debate {주제}` | 명시 주제 토론 |

## 트리거 제외

다음 케이스에서는 호출되지 않는다 (의도된 차단):
- 코드 작성/수정 요청 → `php8` / `api-team` / `/taskflow:execute`
- 플랜 요청 → `/taskflow:plan` / `task-docs`
- 단순 사실 확인 → 직접 답변

## §3 Checkpoint 우선 적용

본 슬래시는 토론만 수행한다. 토론 결과의 코드 반영·산출물 작성은 **별도 워크플로우** (`/taskflow:analyze` → `/taskflow:plan` → `/taskflow:execute`) 로 분리한다. 토론 즉시 mutation 도구 (Edit/Write/Bash mutation) 호출 금지. 16 Agent 풀-병렬 spawn = §3 "외부 API 호출" 매칭 (대량 토큰 소비) — 사용자 진행 승인 후 spawn.

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/custom-plugin/taskflow/skills/debate/SKILL.md` v4.0.2 | 토론 protocol 본체 — 16 Agent 풀-병렬 spawn 구조 |
| `~/.claude/skills/orchestration/SKILL.md` | 9-Core + 3-Consultants 페르소나 정의 (debate 멤버 출처) |
| `~/.claude/CLAUDE.md` §4.2 "에이전트 우선 위임" | 의견 갈림 → debate 위임 룰 |
| `~/.claude/custom-plugin/taskflow/commands/debate.md` (본 파일) | 슬래시 진입점 |

## 호출 예

```
/taskflow:debate                                              ← 직전 응답 쟁점 자동 추출 토론
/taskflow:debate 단일 SSOT vs 다중 진입점 어느 쪽이 나아       ← 명시 주제
/taskflow:debate OAuth 2.1 PKCE 적용 vs 기존 client_secret    ← 설계 트레이드오프
```

흐름 예시:

```
[사용자] /taskflow:debate task-docs 에 mode 인자 추가 vs 8 슬래시 분리 어느 쪽이 나아
   ↓
[Claude] Phase 0: 쟁점 정리 "단일 SSOT 인자 분기 vs 다중 진입점 신설"
        Phase 1: 12 멤버 Agent 병렬 spawn — 각 cold context 의견
        Phase 2: 4 Lead Agent 병렬 spawn — 팀별 종합
        Phase 3: Cross-Team 비교표 + 사용자 의견 확인
```
