---
name: debate-to-commit
description: >
  3-Consultants 토론 → 구현 → 검증 → 커밋까지 E2E 자동화 워크플로우.
  사용자의 주제에 대해 멀티 페르소나 토론을 수행하고, 합의된 권고안을 코드에 반영하며,
  검증 후 구조화된 커밋 메시지로 커밋한다. 모든 Phase 전환 시 사용자 승인을 받는다.
triggers:
  - "토론 후 커밋", "debate and commit", "debate-to-commit"
  - "토론 결과 반영해줘"
version: 1.0.0
depends_on: [debate-protocol, security-audit]
conflicts_with: []
min_claude_md_version: "3.2"
---

# Debate-to-Commit Skill

주제에 대한 멀티 페르소나 토론 → 코드 반영 → 검증 → 커밋의 4-Phase E2E 워크플로우.

---

## 전체 흐름

```
PHASE 1 (Debate) → 사용자 승인
    → PHASE 2 (Implement) → 자동 진행
        → PHASE 3 (Validate) → 이슈 발견 시 사용자 확인
            → PHASE 4 (Commit) → 사용자 승인 → git commit
```

**승인 게이트: Phase 1 완료 후, Phase 4 커밋 전 — 최소 2회**

---

## PHASE 1: Debate (3-Consultants 토론)

### 실행 절차

1. 사용자의 주제를 수신한다
2. 주제의 핵심 쟁점을 1~2문장으로 정리한다
3. 3-Consultants를 Agent 도구로 spawn한다:

| Consultant | 관점 | 핵심 질문 |
|------------|------|-----------|
| **Pragmatist** | 최소 비용, 빠른 구현, 단순성 | "가장 빠르고 안전한 방법은?" |
| **Visionary** | 확장성, 유지보수성, 미래 지향 | "장기적으로 올바른 방법은?" |
| **Innovator** | 제3의 대안, 리스크 분석 | "더 나은 방법은 없는가?" |

4. 각 Consultant의 의견을 종합하여 비교표를 작성한다
5. **종합 권고안(Recommendation)**을 도출한다
6. 사용자에게 제시하고 **승인을 대기**한다

### 출력 형식

```
## 🔄 Debate: {주제}

### Consultant 의견
| 관점 | Pragmatist | Visionary | Innovator |
|------|------------|-----------|-----------|
| 핵심 주장 | ... | ... | ... |
| 장점 | ... | ... | ... |
| 리스크 | ... | ... | ... |

### 종합 권고안
> {권고 내용 요약}

### 구현 계획
1. {파일}: {변경 내용}
2. {파일}: {변경 내용}
...

### [Status] Phase 1 Complete — 사용자 승인 대기
> 위 권고안대로 구현을 진행할까요?
> 특정 Consultant의 방향을 선호하시면 말씀해 주세요.
```

**사용자 승인 없이 Phase 2로 진입하는 것은 지침 위반이다.**

---

## PHASE 2: Implement (구현)

### 실행 절차

1. Phase 1에서 승인된 권고안의 구현 계획에 따라 코드를 수정한다
2. Edit/Write 도구로 파일을 변경한다
3. 변경 사항을 실시간 로깅한다

### 변경 추적 형식

```
## 📝 Implementation Log

| # | 파일 | 변경 유형 | 내용 요약 |
|---|------|-----------|-----------|
| 1 | {path} | 수정/생성/삭제 | {요약} |
```

### 가드레일
- 승인된 권고안의 범위를 **초과하는 변경 금지**
- 범위 외 변경이 필요한 경우 즉시 Checkpoint 발동
- 각 변경은 권고안의 어느 항목에 해당하는지 매핑

---

## PHASE 3: Validate (검증)

### 실행 절차

1. 변경된 파일을 Read로 재확인하여 권고안과 일치하는지 검증
2. Grep으로 잔존 문제 패턴 스캔 (security-audit-skill의 Critical/High 패턴)
3. 기존 테스트 실행 가능 시 `php vendor/bin/phpunit` 실행

### 검증 체크리스트

```
## ✅ Validation Checklist

| # | 검증 항목 | 결과 | 비고 |
|---|-----------|------|------|
| 1 | 권고안 대비 구현 완전성 | PASS/FAIL | |
| 2 | 보안 패턴 스캔 (Critical) | PASS/FAIL | |
| 3 | 보안 패턴 스캔 (High) | PASS/FAIL | |
| 4 | 테스트 실행 결과 | PASS/FAIL/SKIP | |
| 5 | 범위 외 변경 여부 | PASS/FAIL | |
```

### 이슈 발견 시
- Critical/High 이슈: Phase 2로 자동 재진입 (Feedback Loop, 최대 3회)
- Medium/Low 6건 이상: 사용자 확인 후 진행
- 전체 PASS: Phase 4로 진행

---

## PHASE 4: Commit (커밋)

### 실행 절차

1. `git status`로 변경 파일 확인
2. `git diff`로 전체 diff 생성
3. 커밋 메시지를 아래 형식으로 생성
4. diff + 커밋 메시지를 사용자에게 제시
5. **사용자 승인 후에만** `git add` + `git commit` 실행

### 커밋 메시지 형식

```
debate({topic}): {synthesis summary}

Consultants:
- Pragmatist: {핵심 주장 1줄}
- Visionary: {핵심 주장 1줄}
- Innovator: {핵심 주장 1줄}

Recommendation: {채택된 방향}

Changes:
- {파일1}: {변경 요약}
- {파일2}: {변경 요약}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

### 출력 형식

```
## 🚀 Commit Preview

### 변경 파일
{git status 결과}

### Diff 요약
{핵심 변경 diff — 대규모 시 함수 단위 요약}

### 커밋 메시지
{위 형식의 커밋 메시지}

### [Status] Phase 4 Complete — 커밋 승인 대기
> 위 내용으로 커밋할까요?
```

**사용자 승인 없이 git commit을 실행하는 것은 지침 위반이다.**

---

## 전체 가드레일

1. **Phase 전환 시 승인:** Phase 1→2, Phase 3→4(커밋) 전환 시 반드시 사용자 승인
2. **범위 준수:** 승인된 권고안 범위 내에서만 변경. 범위 초과 시 Checkpoint
3. **롤백 가능성:** Phase 4 커밋 전이므로 `git checkout`으로 언제든 원복 가능
4. **보안 감사 연동:** Phase 3에서 security-audit-skill의 패턴을 적용하여 보안 검증
5. **PAEV 호환:** 이 스킬의 전체 흐름은 CLAUDE.md §4 PAEV Loop의 특수화된 구현이다
