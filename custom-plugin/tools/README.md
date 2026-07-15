# tools — 개인 유틸리티 모음 (Claude Code 플러그인)

자잘한 개인 유틸리티 스킬을 담는 우산 플러그인입니다. `custom-plugin` 로컬 마켓플레이스(이름: `pv-local`)에 속합니다.

## 설치 (로컬, 영구)

```
/plugin marketplace add C:\Users\PV\.claude\custom-plugin
/plugin install tools@pv-local
```

`--plugin-dir` 은 세션 한정이므로 영구 설치는 위 마켓플레이스 방식을 사용합니다.

## 스킬

### 검색 (`search-*`)
- **`/tools:search-chat <패턴> [옵션]`** — Claude Code 세션 트랜스크립트(`~/.claude/projects/` 아래 JSONL) 정규식 검색. 엔진 `scripts/chat-search.py` (표준 라이브러리만). 주요 옵션: `--all --case --thinking --project --role --since --until --json --count --context --limit`
- **`/tools:search-docset`** — Dash docset 오프라인 기술 레퍼런스 검색(`~/.claude/docs/references/` docSet.dsidx SQLite + HTML 원문 추출). `/taskflow:feasibility` 이 공식 근거 자동 호출.

### CLI 외부 API (`cli-*`)
- **`/tools:cli-bitbucket`** — Bitbucket Cloud REST API (curl + API 토큰). 파이프라인 / PR / 브랜치 / 커밋 조회·관리.
- **`/tools:cli-notion`** — Notion API (curl + Bearer Token). 페이지·DB·블록 조작. **사용자 명시 요청 시에만** 실행(자동 반영 금지).

### 보고·평가 (`report-*`)
- **`/tools:report-work`** — 일일·주간·월간 업무 리포트 (tasks/ 이력 스캔).
- **`/tools:report-kpi`** — 분기 업적평가(70%) KPI 7영역.
- **`/tools:report-competency`** — 월간 역량평가(30%) 9항목.

## 토큰

`cli-*` 스킬 토큰은 `tools/.token/{cli-bitbucket,cli-notion}.token` 에 보관합니다 (`.gitignore` 의 `*.token` + `custom-plugin/` 이중 무시 — 커밋 제외). SKILL 은 `${CLAUDE_PLUGIN_ROOT}/.token/{name}.token` 으로 참조합니다.

## chat-search 직접 실행

```
python "C:\Users\PV\.claude\custom-plugin\tools\scripts\chat-search.py" <패턴> [옵션]
```

## 구조
```
tools/
├── .claude-plugin/plugin.json
├── .token/                       # API 토큰 (gitignore)
├── scripts/chat-search.py
├── agents/                       # report 수집 에이전트 4종
├── templates/                    # report 템플릿
└── skills/
    ├── search-chat/   search-docset/
    ├── cli-bitbucket/ cli-notion/
    └── report-work/   report-kpi/   report-competency/
```
