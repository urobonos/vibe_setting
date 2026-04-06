---
name: skill-validator
description: >
  글로벌(~/.claude/skills/)과 프로젝트 로컬(.claude/skills/) 스킬 파일의
  경로 정합성, 구조 완전성, CLAUDE.md 규칙 정합성을 3개 병렬 에이전트로 자동 검증한다.
triggers:
  - "스킬 검증", "skill validate", "스킬 점검"
version: 1.0.0
depends_on: []
conflicts_with: []
min_claude_md_version: "3.2"
---

# Skill Validator Skill

스킬 파일의 품질을 3개 병렬 에이전트로 자동 검증하고, 통합 QA 리포트를 생성한다.

---

## 1. 실행 절차

```
1. [Discovery] — Glob으로 글로벌/프로젝트 양쪽 스킬 파일 수집
2. [User Confirmation] — 발견된 스킬 목록을 사용자에게 보고, 검증 진행 여부 확인
3. [Parallel Validation] — 3개 에이전트 병렬 spawn
4. [Report Synthesis] — 결과 취합, 통합 QA 리포트 생성
5. [User Review] — 리포트 제시 후 사용자 확인
```

---

## 2. Discovery 단계

아래 경로에서 스킬 파일을 탐색한다:

```
글로벌: ~/.claude/skills/*/SKILL.md
프로젝트 로컬: .claude/skills/*/SKILL.md (또는 .claude/skills/*.md)
```

발견된 파일을 테이블로 정리:
```
| # | 스킬명 | 경로 | 위치 (글로벌/로컬) |
|---|--------|------|-------------------|
```

---

## 3. Parallel Validation — 3개 에이전트 규격

### Agent-A: 경로 정합성 검증 (Path Validator)

**목표:** 모든 스킬 파일이 올바른 위치에 있는지 확인.

**검사 항목:**
| # | 검사 | 심각도 | Pass 조건 |
|---|------|--------|-----------|
| A-1 | 글로벌 스킬이 `~/.claude/skills/{name}/SKILL.md` 구조인가 | **High** | 디렉토리 + SKILL.md 파일 존재 |
| A-2 | 프로젝트 로컬에 글로벌과 동일 이름의 스킬이 중복 존재하는가 | **High** | 중복 없음 |
| A-3 | 프로젝트 로컬에만 존재하는 스킬이 있는가 (글로벌로 이동 필요 여부) | **Medium** | 의도적 로컬 스킬이 아닌 경우 경고 |
| A-4 | 스킬 디렉토리명과 frontmatter의 `name` 필드가 일치하는가 | **Low** | 일치 |

**반환 형식:**
```
| 스킬 | A-1 | A-2 | A-3 | A-4 | 판정 |
|------|-----|-----|-----|-----|------|
| {name} | PASS/FAIL | PASS/FAIL | PASS/WARN | PASS/FAIL | PASS/FAIL |
```

### Agent-B: 구조 완전성 검증 (Structure Validator)

**목표:** 각 스킬 파일이 필수 섹션을 포함하는지 확인.

**필수 섹션 체크리스트:**
| # | 필수 섹션 | 심각도 | 검사 방법 |
|---|-----------|--------|-----------|
| B-1 | YAML frontmatter (`---` 블록) | **High** | 파일 시작이 `---`로 시작하는지 |
| B-2 | `name` 필드 | **High** | frontmatter 내 `name:` 존재 |
| B-3 | `description` 필드 | **High** | frontmatter 내 `description:` 존재 |
| B-4 | triggers 또는 적용 시점 정의 | **Medium** | `triggers:` 또는 "적용 시점" 섹션 존재 |
| B-5 | 검사 항목/규칙 정의 | **Medium** | 테이블 또는 체크리스트 형태의 규칙 존재 |
| B-6 | 심각도 등급 정의 | **Low** | Critical/High/Medium/Low 중 1개 이상 사용 |

**반환 형식:**
```
| 스킬 | B-1 | B-2 | B-3 | B-4 | B-5 | B-6 | 판정 |
|------|-----|-----|-----|-----|-----|-----|------|
| {name} | PASS/FAIL | ... | ... | ... | ... | ... | PASS/FAIL |
```

### Agent-C: CLAUDE.md 정합성 검증 (Consistency Validator)

**목표:** 스킬 내용이 CLAUDE.md 규칙과 모순되지 않는지 확인.

**검사 항목:**
| # | 검사 | 심각도 | 검사 방법 |
|---|------|--------|-----------|
| C-1 | 심각도 등급이 CLAUDE.md §7 체계(Critical/High/Medium)와 호환되는가 | **High** | 스킬 내 심각도가 §7 정의와 일치 |
| C-2 | Checkpoint 발동 조건이 §3과 모순되지 않는가 | **High** | 스킬이 §3보다 낮은 기준으로 Checkpoint를 생략하지 않는지 |
| C-3 | 스킬 내 도구 사용 규칙이 §4 PAEV와 충돌하지 않는가 | **High** | Pre-Plan 없이 도구 사용을 허용하는 규칙이 없는지 |
| C-4 | `compatibility` 필드가 정의된 경우 실제로 호환되는가 | **Medium** | 선언된 호환성이 실제 내용과 일치 |

**반환 형식:**
```
| 스킬 | C-1 | C-2 | C-3 | C-4 | 판정 |
|------|-----|-----|-----|-----|------|
| {name} | PASS/FAIL | ... | ... | ... | PASS/FAIL |
```

---

## 4. 통합 QA 리포트 형식

```
## 🔍 Skill Validation Report

**검증 일시:** {YYYY-MM-DD HH:mm}
**검증 대상:** {N}개 스킬 (글로벌 {n1}개, 로컬 {n2}개)

### 종합 결과
| 스킬 | 경로(A) | 구조(B) | 정합성(C) | 최종 |
|------|---------|---------|-----------|------|
| {name} | PASS/FAIL | PASS/FAIL | PASS/FAIL | PASS/FAIL |

### FAIL 상세
| 스킬 | 항목 | 심각도 | 설명 | 권고 조치 |
|------|------|--------|------|-----------|

### 통계
- 전체: {N}개
- PASS: {n}개
- FAIL: {n}개
- WARN: {n}개
```

---

## 5. 가드레일

- Discovery에서 발견된 스킬 목록을 **반드시 사용자에게 보고** 후 검증 진행
- 스킬 파일을 **수정하지 않는다** — 읽기 전용 검증만 수행
- FAIL 항목에 대한 수정은 리포트 제시 후 사용자 승인 시에만 진행
