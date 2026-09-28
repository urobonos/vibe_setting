# custom-plugin — 플러그인 생성·수정 가이드

`pv-local` 마켓플레이스(`.claude-plugin/marketplace.json`, directory source)의 플러그인 5종: `backend` · `git` · `hongcafe` · `taskflow` · `tools`.
공식 기준 = [플러그인에 컴포넌트 추가하기](https://code.claude.com/docs/ko/plugins/components) · [manifest 참조](https://code.claude.com/docs/ko/plugins/manifest-reference).

## 1. 디렉토리 레이아웃 (공식 기본 위치)

```
{plugin}/
├── .claude-plugin/
│   └── plugin.json        # manifest — name 만 필수
├── skills/{name}/SKILL.md # 스킬 (신규 기능은 여기)
├── commands/{name}.md     # 커맨드 (이전 형식 — 기존 파일만 유지)
├── agents/{name}.md       # 서브에이전트
├── hooks/hooks.json       # hook 등록 (settings.json hooks 와 같은 형태)
├── monitors/monitors.json # 세션 백그라운드 모니터
├── output-styles/{name}.md
├── themes/{slug}.json
├── workflows/{name}.js    # Workflow 스크립트
├── bin/                   # 실행 파일·보조 스크립트·그 테스트(bin/tests/) — 플러그인 활성 중 Bash PATH 에 추가
├── settings.json          # agent · subagentStatusLine 두 키만 유효
├── .mcp.json              # MCP 서버
└── .lsp.json              # LSP 서버
```

필요한 것만 만든다. 빈 폴더를 미리 만들지 않는다.

**`scripts/` 는 쓰지 않는다 (이 레포 관례).** 공식 문서상 `scripts/` 는 자동 발견되지 않는 관례 폴더일 뿐이라, 실행 파일과 보조 스크립트를 `bin/` 한 곳에 둔다. hook 본체는 `hooks/` 에 둔다.

### 로컬 확장 (공식 레이아웃 밖, 이 레포 관례)

| 경로 | 용도 |
|------|------|
| `references/` | 여러 커맨드·에이전트가 공유하는 계약(SSOT). 특정 스킬 소속이 아닐 때만. 스킬 전용 참조는 `skills/{name}/references/` |
| `CHANGELOG.md` | 변경 이력. 커맨드·에이전트 본문에 쓰지 않는다 (본문은 호출·spawn 마다 전량 로드) |
| `README.md` | 플러그인별 설명 (선택) |

## 2. 컴포넌트별 규칙

| 컴포넌트 | 호출 이름 | 주의 |
|----------|-----------|------|
| 스킬 `skills/review/SKILL.md` | `/{plugin}:review` | `description` 으로 자동 호출 판단. 지원 파일 동봉 가능 |
| 커맨드 `commands/about.md` | `/{plugin}:about` | 하위 폴더 = 세그먼트 추가(`commands/db/migrate.md` → `/{plugin}:db:migrate`) |
| 에이전트 `agents/x.md` | `{plugin}:x` (`subagent_type`) | frontmatter 의 `hooks`·`mcpServers`·`permissionMode`·`initialPrompt` 는 **무시됨** — 플러그인 hooks·.mcp.json 으로 |
| hook `hooks/hooks.json` | — | 세션이 플러그인을 로드할 때 등록, 이후 모든 이벤트에서 발생 (스킬 사용과 무관). 범위는 `matcher` 로 좁힌다 |
| 실행 파일 `bin/x` | 베어 명령 `x` | `chmod +x`. 사용자 PATH 뒤에 붙어 시스템 명령을 가리지 못함 |

- **모델 자동 호출 끄기:** frontmatter `disable-model-invocation: true` — 스킬 목록·자동 호출에서 빠지고 사용자 직접 입력은 유지.
- **플러그인 루트 `CLAUDE.md` 는 로드되지 않는다.** 지침은 스킬로 쓴다.

## 3. 경로 참조

| 변수 | 값 | 쓰는 곳 |
|------|-----|---------|
| `${CLAUDE_PLUGIN_ROOT}` | 플러그인 설치 디렉토리 | 스킬·커맨드·에이전트 본문, hook·모니터 명령, MCP·LSP 설정에서 치환. hook 프로세스엔 환경변수로도 전달 |
| `${CLAUDE_PLUGIN_DATA}` | `~/.claude/plugins/data/{id}/` — 업데이트에도 유지 | 캐시·의존성·상태 저장 |
| `${CLAUDE_PROJECT_DIR}` | 프로젝트 루트 | hook |

- hook `command` 에서는 `"\"${CLAUDE_PLUGIN_ROOT}/hooks/x.sh\""` 처럼 **큰따옴표로 감싼다** (셸 단어 분리 방지).
- `${CLAUDE_PLUGIN_ROOT}` 아래에 **상태를 쓰지 않는다** — 버전마다 경로가 바뀐다. 상태는 `${CLAUDE_PLUGIN_DATA}` 또는 `~/.claude/state/`.
- 기존 본문의 `~/.claude/custom-plugin/{plugin}/...` 절대경로는 directory source 라 동작한다. 신규 작성은 `${CLAUDE_PLUGIN_ROOT}` 를 쓴다.

## 4. 경계 — 플러그인 vs 글로벌 하니스

| 둔다 | 기준 |
|------|------|
| **플러그인 안** | 그 플러그인 개념에 속하는 hook·lib·bin. taskflow = working/ 문서 생명주기(`working-*`)·단계 게이트(`gate-*`)·자동 위임(`auto-iterate-*`)·backlog·세션 완결성·share 문서 가드·code-loop 러너와 그 게이트 판정(`hooks/lib/code-loop-gate.sh`) |
| **글로벌 `~/.claude/hooks/`** | 도메인 무관 안전 가드 (worktree-enforce · branch-enforce · dangerous-ops-guard · sensitive-file-guard 등), 글로벌 hook 도 쓰는 공유 lib (`log-helper` · `hook-input` · `path-utils` · `product-resolver` · `registry-utils` · `working-scan`) |

- 의존 방향은 **플러그인 → 글로벌** 한쪽만. 글로벌 hook·lib 가 플러그인 파일을 source 하지 않는다. 플러그인 hook 은 공유 lib 를 `$HOME/.claude/hooks/lib/` 로 참조하고, 플러그인 소유 lib 는 자기 `hooks/lib/` 에서 상대경로로 읽는다.
- **플러그인을 끄면 그 hook 도 꺼진다.** taskflow 를 비활성화하면 단계 게이트·working 생명주기 강제도 멈춘다 — 의도된 동작.

## 5. 결합 금지

- **커맨드·에이전트는 다른 커맨드 본문의 절(§)을 참조하지 않는다.** 두 번째 소비자가 생기면 그 규칙을 `references/` 로 올린다. 커맨드 본문을 SSOT 로 두면 그 커맨드를 끄거나 고칠 때 다른 쪽이 조용히 깨진다.
- 같은 규칙을 복붙하지 않는다 — 갈라진다. 공유는 references 한 곳.

## 6. 생성·수정 체크리스트

1. 신규 기능 → 스킬로 (`skill-creator` 경유 필수 — `rules/harness-authoring.md`).
2. 위치는 §1 레이아웃, 경계는 §4.
3. 이력은 `CHANGELOG.md` 에. 본문에 `## Changelog` 를 늘리지 않는다.
4. 검증: 플러그인 폴더에서 `claude plugin validate .` → 세션에서 `/reload-plugins` 또는 새 세션.
5. hook 은 이동·수정 전후 출력을 실제로 돌려 diff 한다 (SessionStart 는 `echo '{"cwd":"..."}' | bash hook.sh`).
6. 경로 이동 후 옛 경로 grep 0건 확인 (`git grep` — changelog 이력 줄 제외).
