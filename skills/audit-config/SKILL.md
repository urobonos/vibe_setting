---
name: audit-config
description: >
  Claude Code 설정 전체(CLAUDE.md, settings, hooks, commands, skills, agents, memory)를
  정보망 베스트 프랙티스 대비 정량적으로 검증. 사용자가 /audit-config 명시적 요청 시에만 실행.
triggers:
  - "/audit-config"
  - "설정 감사"
  - "config audit"
version: 1.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Task: Claude Code 설정 감사

Explore 서브에이전트가 실행하는 검증 로직.
rubric.md를 SSOT로 참조하여 8카테고리 순차 검증 후 리포트를 생성한다.

## 검증 대상 파일

서브에이전트는 아래 파일들을 Read/Grep/Bash로 수집한다.

### 글로벌 설정
- `~/.claude/CLAUDE.md`
- `~/.claude/settings.json`
- `~/.claude/commands/*.md`
- `~/.claude/hooks/` (존재 시)

### 프로젝트 설정 ({project} = 인자로 전달된 경로)
- `{project}/CLAUDE.md`
- `{project}/.claude/settings.json`
- `{project}/.claude/settings.local.json`
- `{project}/.claude/skills/*/SKILL.md`
- `{project}/.claude/agents/*.md` (존재 시)
- `{project}/.claude/hooks/` (존재 시)

### 메모리
- `~/.claude/projects/{project-key}/memory/MEMORY.md`
- `~/.claude/projects/{project-key}/memory/*.md`

## 검증 프로토콜

8개 카테고리를 순차적으로 검증한다. 각 카테고리마다:

1. **파일 수집**: 해당 카테고리의 대상 파일을 Read로 로드
2. **항목별 판정**: rubric.md의 각 세부 항목에 대해 Y/N 판정 + 근거
3. **카테고리 점수 산출**: (Y 개수 / 전체 항목 수) x 100

### 카테고리 1: CLAUDE.md (글로벌)

대상: `~/.claude/CLAUDE.md`

- **1-1 줄 수 적정성**: `wc -l`로 줄 수 확인. 150줄 이하 Y.
- **1-2 부정어 비율**: "Do not", "Never", "NEVER", "금지", "절대", "하지 마", "엄금" 패턴 grep 후 전체 규칙 수 대비 비율 산출. 15% 미만 Y.
- **1-3 신호 대 잡음**: 각 규칙을 읽고 "Claude가 지침 없이도 올바르게 수행할 내용"인지 판단. 불필요 규칙 없으면 Y.
- **1-4 리프레이밍**: 1-2에서 발견된 부정어 중 "Prefer X over Y"로 리프레이밍 가능한 항목 존재 시 N. 목록 제시.
- **1-5 Hooks 위임**: 100% 강제 필요 규칙(보안, 포맷 등)이 CLAUDE.md에만 있고 hooks로 구현되지 않은 경우 N.

### 카테고리 2: CLAUDE.md (프로젝트)

대상: `{project}/CLAUDE.md`

- **2-1 프로젝트 특화도**: 프로젝트 고유 규칙인지 판단. 범용 규칙 포함 시 N.
- **2-2 글로벌 중복률**: 글로벌 CLAUDE.md와 텍스트 유사도 비교. 동일/유사 규칙 20% 이상 시 N.
- **2-3 아키텍처 명시**: 기술 스택, 디렉토리 구조, 네이밍 등 프로젝트 고유 아키텍처 명시 여부. 없으면 N.

### 카테고리 3: Settings 구조

대상: `~/.claude/settings.json`, `{project}/.claude/settings.json`, `{project}/.claude/settings.local.json`

- **3-1 계층 분리**: global과 local의 역할이 분리되었는지 확인.
- **3-2 권한 중복**: allowedTools/deniedTools 항목 비교. 중복 30% 이상 시 N.
- **3-3 최소 권한**: allowedTools에 사용되지 않는 도구가 포함되었는지 확인.
- **3-4 환경 일관성**: 참조된 경로/env가 실제 존재하는지 확인.

### 카테고리 4: Hooks 품질

대상: `~/.claude/hooks/`, `{project}/.claude/hooks/`, settings.json 내 hooks 설정

- **4-1 이벤트 커버리지**: PreToolCall, PostToolCall, Notification 중 활용되는 이벤트 확인.
- **4-2 타입 분류 적정**: command/prompt/agent 분류가 적절한지 확인.
- **4-3 Timeout 적정성**: timeout 값이 작업 복잡도에 맞는지 확인.
- **4-4 에러 핸들링**: 실패 시 에러 메시지/fallback 존재 여부.

hooks가 없는 경우: "hooks 미설정" 으로 기록하고 이벤트 커버리지 항목만 N, 나머지는 N/A로 처리 (점수 산출 시 N/A 항목 제외).

### 카테고리 5: Commands 구조

대상: `~/.claude/commands/*.md`

- **5-1 설명 명확성**: 각 커맨드 첫 줄에 목적/사용법 명시 여부.
- **5-2 $ARGUMENTS 활용**: 인자 파싱 + fallback 유무.
- **5-3 서브에이전트 패턴**: 서브에이전트 사용 시 description/model/prompt 명시 여부.
- **5-4 Git 체크인**: 커맨드 파일이 git 관리 대상인지 확인 (git ls-files).

### 카테고리 6: Skills & Agents

대상: `{project}/.claude/skills/*/SKILL.md`, `{project}/.claude/agents/*.md`

- **6-1 SKILL.md 필수 필드**: frontmatter에 name, description 존재 여부.
- **6-2 Progressive Disclosure**: SKILL.md 본문 줄 수 확인 (500줄 이하). references/ 분리 여부.
- **6-3 도구 권한 범위**: 스킬이 명시한 도구 사용 범위가 최소 권한인지 판단.
- **6-4 에이전트 독립성**: agents/*.md 또는 context: fork 사용 여부.

### 카테고리 7: Memory 활용도

대상: `~/.claude/projects/{project-key}/memory/`

- **7-1 MEMORY.md 인덱스**: MEMORY.md 파일 존재 + 인덱스 목록 유지 여부.
- **7-2 카테고리 균형**: 메모리 파일들의 유형 분포 확인.
- **7-3 정합성**: 인덱스에 나열된 파일이 모두 실제 존재하는지 ls로 확인.
- **7-4 최신성**: `stat -f %Sm` 또는 `ls -lt`로 최근 수정일 확인. 30일 이내 업데이트 있으면 Y.

### 카테고리 8: 크로스컷 일관성

대상: 전체 파일 교차 검증

- **8-1 CLAUDE.md-Hooks 정합**: CLAUDE.md의 "금지/절대/NEVER" 규칙이 hooks로도 강제되는지 교차 확인.
- **8-2 Settings 계층 모순**: global과 local settings 간 충돌하는 설정 유무.
- **8-3 참조 경로 유효성**: 모든 설정 파일에서 참조하는 경로를 수집하여 실제 존재 여부 확인.
- **8-4 네이밍 일관성**: 커맨드/스킬/에이전트 이름이 kebab-case로 통일되었는지 확인.

## 리포트 출력 포맷

```
# Config Audit Report

- 프로젝트: {project path}
- 감사일: {YYYY-MM-DD}
- 루브릭: ~/.claude/skills/audit-config/rubric.md

## 카테고리별 점수

| # | 카테고리 | 가중치 | Y | N | N/A | 점수 | 가중 점수 |
|---|---------|-------|---|---|-----|------|----------|
| 1 | CLAUDE.md (글로벌) | 20% | {n} | {n} | {n} | {score} | {weighted} |
| 2 | CLAUDE.md (프로젝트) | 10% | {n} | {n} | {n} | {score} | {weighted} |
| 3 | Settings 구조 | 15% | {n} | {n} | {n} | {score} | {weighted} |
| 4 | Hooks 품질 | 15% | {n} | {n} | {n} | {score} | {weighted} |
| 5 | Commands 구조 | 10% | {n} | {n} | {n} | {score} | {weighted} |
| 6 | Skills & Agents | 10% | {n} | {n} | {n} | {score} | {weighted} |
| 7 | Memory 활용도 | 10% | {n} | {n} | {n} | {score} | {weighted} |
| 8 | 크로스컷 일관성 | 10% | {n} | {n} | {n} | {score} | {weighted} |
| **총점** | | **100%** | | | | | **{total}** |

**Gate: {PASS / REVIEW / FAIL}**

## 세부 판정

### 카테고리 {N}: {이름}

| 항목 | Y/N | 근거 |
|------|-----|------|
| {항목명} | {Y/N} | {1~2줄 근거} |

## 이슈 목록

| 우선순위 | 카테고리 | 항목 | 이슈 | 개선 제안 |
|---------|---------|------|------|----------|
| HIGH | {cat} | {item} | {문제 설명} | {구체적 개선 방법} |
| MED | ... | ... | ... | ... |
| LOW | ... | ... | ... | ... |

## 개선 로드맵 (FAIL 시만)

1. 즉시 (이번 주): HIGH 이슈 해결
2. 단기 (2주 내): MED 이슈 해결
3. 중기 (1개월 내): LOW 이슈 + 구조 개선
```

## 규칙

- 추측 금지 -- 파일을 직접 읽고 근거 기반 판정
- N/A 항목은 점수 산출에서 제외 (분모에서 제거)
- 이슈 우선순위: HIGH(보안/정합성), MED(효율/유지보수), LOW(스타일/권장)
- 한국어로 출력
- rubric.md가 SSOT -- rubric에 없는 항목 추가 검증 금지
- best-practices.md는 판정 근거 참조용 -- 추가 기준으로 사용 금지
