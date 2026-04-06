# Config Audit Best Practices Reference

> rubric.md 항목별 판정 근거. 각 항목에 출처 URL 포함.

## 1. CLAUDE.md (글로벌) — rubric 1-1 ~ 1-5

### 1-1. 줄 수 적정성
- CLAUDE.md는 advisory (80% 준수율). 짧고 명확할수록 준수율 높음.
- 150줄 임계치는 경험적 기준. Anthropic 공식 문서에 구체적 수치 없음 ("keep it concise" 수준).
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices

### 1-2. 부정어 비율
- "Do not..." 패턴 대신 "Prefer X over Y" 리프레이밍 권장.
- 부정어가 많을수록 모델의 해석 오류율 증가.
- 15% 임계치는 경험적 기준. Anthropic 공식 문서에 구체적 비율 없음 ("리프레이밍 권장" 수준).
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices

### 1-3. 신호 대 잡음
- "Claude가 지침 없이도 맞게 하겠는가?" 필터링. 자명한 규칙은 제거.
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices

### 1-4. 리프레이밍
- 부정 지시("Never use X") -> 긍정 지시("Prefer Y over X, because...").
- why를 설명하면 모델이 맥락에 맞게 유연하게 적용.
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices

### 1-5. Hooks 위임
- 100% 강제 규칙(보안, 포맷)은 hooks로 결정적 검증.
- CLAUDE.md는 advisory이므로 위반 가능성 존재.
- 출처: https://docs.anthropic.com/en/docs/claude-code/hooks

## 2. CLAUDE.md (프로젝트) — rubric 2-1 ~ 2-3

### 2-1. 프로젝트 특화도
- 프로젝트 CLAUDE.md에는 해당 프로젝트에만 적용되는 규칙만 작성.
- 범용 규칙은 글로벌 CLAUDE.md에 배치.
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices

### 2-2. 글로벌 중복률
- 글로벌과 프로젝트 CLAUDE.md 간 중복은 유지보수 부담 + 불일치 위험.
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices

### 2-3. 아키텍처 명시
- 프로젝트 고유 기술 스택, 디렉토리 구조, 컨벤션을 명시해야 Claude가 정확히 따름.
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices

## 3. Settings 구조 — rubric 3-1 ~ 3-4

### 3-1. 계층 분리
- global settings.json: 모든 프로젝트 공통 설정.
- project settings.local.json: 프로젝트 특화 설정. git 미추적.
- 출처: https://docs.anthropic.com/en/docs/claude-code/settings

### 3-2. 권한 중복
- 동일 permission이 양쪽에 있으면 local이 우선하나, 의도 파악 어려움.
- 출처: https://eesel.ai/blog/claude-code-settings-json

### 3-3. 최소 권한
- allowedTools는 실제 사용하는 도구만 포함.
- 불필요한 권한은 보안 리스크.
- 출처: https://docs.anthropic.com/en/docs/claude-code/settings

### 3-4. 환경 일관성
- settings에 참조된 경로/환경변수가 실제 존재해야 런타임 오류 방지.
- 출처: 일반 엔지니어링 원칙

## 4. Hooks 품질 — rubric 4-1 ~ 4-4

### 4-1. 이벤트 커버리지
- 주요 이벤트: PreToolCall, PostToolCall, Notification, Stop.
- 필요한 이벤트만 선택적으로 구현.
- 출처: https://docs.anthropic.com/en/docs/claude-code/hooks

### 4-2. 타입 분류 적정
- command hook: 결정적 검증 (lint, format check).
- prompt hook: LLM 판단 필요 (코드 품질 평가).
- agent hook: 다중 턴 워크플로우.
- 출처: https://docs.anthropic.com/en/docs/claude-code/hooks

### 4-3. Timeout 적정성
- 기본 10초. 복잡한 빌드/테스트는 연장 필요.
- 너무 짧으면 실패, 너무 길면 블로킹.
- 출처: https://docs.anthropic.com/en/docs/claude-code/hooks

### 4-4. 에러 핸들링
- hook 실패 시 사용자에게 명확한 에러 메시지 전달.
- silent failure 방지.
- 출처: https://docs.anthropic.com/en/docs/claude-code/hooks

## 5. Commands 구조 — rubric 5-1 ~ 5-4

### 5-1. 설명 명확성
- 커맨드 파일 첫 줄에 목적, 사용법, 컨텍스트 오염 여부 명시.
- 출처: https://docs.anthropic.com/en/docs/claude-code/slash-commands

### 5-2. $ARGUMENTS 활용
- 사용자 입력 파싱 + 미입력 시 합리적 기본값 제공.
- 출처: https://docs.anthropic.com/en/docs/claude-code/slash-commands

### 5-3. 서브에이전트 패턴
- 서브에이전트 위임 시 description, model, prompt 3요소 명시.
- 메인 컨텍스트 오염 방지.
- 출처: Boris Cherny — https://www.howborisusesclaudecode.com/

### 5-4. Git 체크인
- 팀 공유 커맨드는 git으로 버전 관리.
- 개인 전용은 .local 또는 gitignore 처리.
- 출처: Boris Cherny — https://www.howborisusesclaudecode.com/

## 6. Skills & Agents — rubric 6-1 ~ 6-4

### 6-1. SKILL.md 필수 필드
- frontmatter에 name, description 필수.
- description은 트리거링 정확도에 직결.
- 출처: Claude Code Extensions Guide (Skill Creator 스킬 참조)

### 6-2. Progressive Disclosure
- SKILL.md 본문 500줄 이하 권장.
- 대용량 참조는 references/ 디렉토리로 분리.
- 출처: Claude Code Extensions Guide (Skill Creator 스킬 참조)

### 6-3. 도구 권한 범위
- 스킬이 사용하는 도구는 최소 권한 원칙.
- 불필요한 Write/Bash 권한 지양.
- 출처: 일반 보안 원칙 + Claude Code Extensions Guide

### 6-4. 에이전트 독립성
- 에이전트는 독립 컨텍스트 윈도우에서 실행 (context: fork).
- 메인 컨텍스트 오염 방지.
- 출처: Claude Code Extensions Guide (Skill Creator 스킬 참조)

## 7. Memory 활용도 — rubric 7-1 ~ 7-4

### 7-1. MEMORY.md 인덱스
- MEMORY.md에 모든 메모리 파일의 이름 + 1줄 설명 인덱스 유지.
- 출처: https://docs.anthropic.com/en/docs/claude-code/memory

### 7-2. 카테고리 균형
- user preferences, feedback, project context, reference 등 다양한 유형 보관.
- 한 유형에 편중되면 컨텍스트 효율 저하.
- 출처: https://docs.anthropic.com/en/docs/claude-code/memory

### 7-3. 정합성
- 인덱스에 나열된 파일이 실제 존재해야 참조 오류 방지.
- 출처: 일반 데이터 정합성 원칙

### 7-4. 최신성
- 오래된 메모리는 현재 컨텍스트와 불일치 가능.
- 주기적 정리/업데이트 권장.
- 출처: https://docs.anthropic.com/en/docs/claude-code/memory

## 8. 크로스컷 일관성 — rubric 8-1 ~ 8-4

### 8-1. CLAUDE.md-Hooks 정합
- CLAUDE.md에 "절대 금지"로 명시된 규칙은 hooks로도 강제해야 완전성 확보.
- 출처: https://docs.anthropic.com/en/docs/claude-code/best-practices + hooks 문서 교차

### 8-2. Settings 계층 모순
- global에서 허용한 도구를 local에서 차단하거나 그 반대가 없어야 함.
- 출처: https://docs.anthropic.com/en/docs/claude-code/settings

### 8-3. 참조 경로 유효성
- CLAUDE.md, SKILL.md 등에서 참조하는 모든 파일 경로가 실제 존재.
- 깨진 참조는 실행 시 오류 유발.
- 출처: 일반 소프트웨어 엔지니어링 원칙

### 8-4. 네이밍 일관성
- 커맨드: kebab-case (audit-config, doc-review)
- 스킬 디렉토리: kebab-case
- 에이전트: kebab-case
- 통일된 네이밍으로 검색성, 예측 가능성 확보.
- 출처: Boris Cherny + 일반 컨벤션
