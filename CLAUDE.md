# Multi-Agent Orchestration: Full Specification (v4.0)

## File Paths
- **글로벌 설정:** `~/.claude/` (`C:\Users\PV\.claude\`)
- **글로벌 스킬:** `~/.claude/skills/{skill-name}/SKILL.md`
- **프로젝트 로컬 스킬:** `./.claude/skills/{skill-name}/SKILL.md`
- 스킬 파일을 생성하거나 수정할 때, **반드시 대상 경로(글로벌 vs 프로젝트 로컬)를 사용자에게 확인** 후 작업한다. 확인 없이 경로를 임의 결정하는 것은 지침 위반이다.
- **Notion 연동(요청 기반):** Notion 연동은 `notion_cli` 스킬(curl + Notion REST API, Bearer Token 기반)을 **단일 진입점**으로 사용한다. MCP 기반 `notion-fetch` / `replace_content` / `update_content` / `mcp__notion*` 도구는 제거됨. 연동 실행은 **사용자가 명시적으로 요청할 때만** 수행한다. 글로벌/프로젝트 CLAUDE.md 또는 스킬 문서를 수정했더라도 자동으로 Notion에 반영하지 않는다. 사용자가 "노션에 반영", "Notion 동기화", "notion 업데이트" 등 명시 요청한 경우에만 실행한다. 사용자 요청 없이 `notion_cli`를 선제 실행하는 것은 지침 위반이다.
- **Notion 수정 절차(요청 시):** `notion_cli` 스킬 절차를 따른다. (1) 대상 페이지/블록 조회(GET) → (2) 로컬 지침과 대조해 갱신 내용 작성 → (3) 블록 전체 교체(기존 자식 블록 삭제 후 재작성)를 기본으로 한다. 부분 패치(PATCH)보다 전체 교체를 우선한다.

---

## 1. Session Initialization (자동 실행)

작업 세션 시작 시 다음을 자동으로 수행한다.

1. 프로젝트 루트 구조 파악 + 현재 브랜치/커밋 확인
2. `docs/tasks/history.md` 로드 (작업 이력 요약)
3. `.claude/skills/` 전 스킬은 SessionStart 훅(`hooks/skill-preload.sh`)이 자동으로 전량 preload — Claude는 주입된 스킬 중 `triggers`에 부합하는 스킬만 활성 호출한다. (`audit-config`는 preload 제외되며 `/audit-config` 명시 호출 시에만 로드)

→ 완료 후 반드시 **"Context Loaded."** 보고

---

## 2. Hierarchy & Authority (Global Constitution)

- **User Sovereignty:** 사용자의 명시적 승인 없이 행동하지 않는다. 불확실한 지점은 반드시 `Checkpoint` 요청.
- **프로젝트 지침 제안:** 프로젝트 내 작업 중 프로젝트 지침(`CLAUDE.md`)에 추가가 필요하다고 판단될 경우, 임의로 추가하지 않고 반드시 사용자에게 추가 여부를 확인한다. 확인 없이 프로젝트 지침을 수정하는 것은 지침 위반이다.

---

## 3. Checkpoint 발동 조건

다음 조건 중 하나라도 해당할 경우, 작업을 즉시 중단하고 사용자 승인을 요청한다.

| 조건 | 예시 |
|------|------|
| **비가역적 작업** | 파일 삭제, DB 스키마 변경, 마이그레이션 실행 |
| **광범위한 영향 범위** | 3개 이상의 파일에 걸친 아키텍처 변경 |
| **요구사항 상충** | 성능 vs 가독성, 보안 vs 편의성 등 트레이드오프 발생 |
| **외부 시스템 연동** | 외부 API 호출, 환경변수 변경, 서드파티 설정 수정 |
| **권한 외 파일 접근** | `.env`, 설정 파일, 허가되지 않은 디렉토리 접근 시도 |

단순 오타·주석은 Checkpoint 없이 진행 가능. 버그 수정은 단일 파일 내 명백한 오기(off-by-one 등)만 예외. 불확실하면 Checkpoint 발동.

---

## 4. Guardrails & Quality

- **Proactive Correction:** 오타(철자)만 즉시 수정 가능. 문법·컨벤션·로직 수정은 Team 1 분석 후 승인 필요.
- **Readability:** 주석 없이 읽히는 명시적 코드. 전체 단어(fullName, index 등) 사용.
- **Validation ("No Test, No Merge"):** 모든 수정은 유닛 테스트 또는 실행 로그 증빙 동반.
- **Persistence (필수):** 모든 작업 완료 시 `docs/tasks/history.md`에 `YYYY.MM.DD` 항목으로 처리 내역을 기록하고, `docs/tasks/YYYYMMDD/summary.md`에 일일 작업 요약을 기록한다. 누락은 지침 위반.
- **타당성 검토 (Feasibility Review, 필수):** 모든 분석(analyze), 사전 계획(preplan), 설계(SDD/SRS/SDP/IDD) 산출물에 **"타당성 검토"** 섹션을 포함한다. 근거 확보는 `docset-ref` 스킬의 검색 절차를 따른다 (Docset SQLite 검색 → 마크다운 캐시 → WebFetch fallback). 근거 없는 주장·권고는 지침 위반이다.
- **변경 영향 기록 (Change Impact Log, 필수):** analyze/preplan 결과를 반영할 때, **변경되는 사항**, **개선점**, **왜 해야 하는지(수행 이유)**를 산출물에 필수 기록한다. 변경 사항만 나열하고 이유를 생략하는 것은 지침 위반이다.
- **산출물 유연성 (Flexible Deliverables):** 작업 성격에 따라 `analyze / plan / result` 중 필요한 단계만 작성한다. 분석 단독 세션은 `analyze.md` 하나로, 작은 구현 세션은 `result.md` 하나로 완결할 수 있다. 3종 쌍(analyze+plan+result)은 구현 규모가 큰 다단계 작업에만 요구된다.
- **Default Accept (제안 기본 수락):** 사용자는 Claude 가 코드 작업 중 제시하는 제안사항을 **기본적으로 수락**한다. 리팩토링·명명 개선·누락 처리·방어 코드 등 개선 제안은 별도 승인 대기 없이 반영해 작업을 진행한다. 단 §3 Checkpoint 발동 조건(비가역적 작업 / 광범위한 영향 범위 / 요구사항 상충 / 외부 시스템 연동 / 권한 외 파일 접근)은 본 항목에 **우선 적용**되며, 해당 조건은 여전히 사용자 승인 대기가 필수다.
- **Before/After 대조 보고 (필수):** 작업 완료 후 **최초 실행안**(사용자가 처음 지시한 최소 요구 사항)과 **제안에서 변경된 안**(Claude 가 추가/수정한 부분)을 대조해 보여준다. 파일/함수 단위 diff 또는 표 형태로 사용자가 한눈에 비교할 수 있어야 한다. 제안 반영 내역을 숨긴 채 최종안만 보고하는 것은 지침 위반이다.
- **롤백 가능 상태 유지 (필수):** 제안사항이 반영된 코드는 **롤백 가능한 상태**로 유지한다. 실천 방법: (1) 최초안과 제안안을 별도 커밋으로 분리 (`최초안 commit` → `제안 반영 commit`), 또는 (2) 제안 반영분을 명시적 diff/patch 로 제공하여 복원 경로를 보장. 단일 커밋에 최초안+제안을 섞어 넣어 분리 롤백이 불가능한 상태로 만들면 지침 위반이다.
- **Direct Execution (필수):** Bash 도구가 allow 목록에 있고 hook 이 exit 0 으로 통과시키는 모든 명령은 Claude 가 직접 실행한다. 사용자에게 `! <command>` 형태로 실행을 떠넘기거나 "다음 명령을 실행해 주세요" 텍스트로 응답하는 것은 지침 위반이다. 세부 원칙: (1) 로컬/조회 명령(`git status`/`log`/`diff`/`add`/`commit`, `aws *describe*`/`list*`/`get*`, `SELECT` 등)은 승인 대기 없이 즉시 Claude 가 Bash 도구로 실행한다. (2) 공유 상태 변경·비가역 명령(`git push`, `aws ssm send-command`, DB 변경 등)은 명령 내용·영향 범위·롤백 방법을 먼저 보고한 뒤, 사용자의 승인 의사 표시(`승인`, `해`, `진행`, `ok` 등) 확인 즉시 Claude 가 직접 Bash 도구를 호출한다. (3) Hook 의 stdout Checkpoint 경고(exit 0)는 "실행 차단"이 아닌 "승인 후 직접 실행" 신호로 해석한다. exit 2 (stderr 차단)인 경우에만 실제 차단이다. (4) "사용자 승인이 필요함"은 승인 요청 대상일 뿐 실행 주체의 이양이 아니다. 승인 후 다음 턴에서 실행하지 않고 텍스트만 출력하는 것은 지침 위반이다.
