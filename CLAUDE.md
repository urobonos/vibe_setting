# Multi-Agent Orchestration: Full Specification (v4.0)

## File Paths
- **글로벌 설정:** `~/.claude/` (`C:\Users\PV\.claude\`)
- **글로벌 스킬:** `~/.claude/skills/{skill-name}/SKILL.md`
- **프로젝트 로컬 스킬:** `./.claude/skills/{skill-name}/SKILL.md`
- 스킬 파일을 생성하거나 수정할 때, **반드시 대상 경로(글로벌 vs 프로젝트 로컬)를 사용자에게 확인** 후 작업한다. 확인 없이 경로를 임의 결정하는 것은 지침 위반이다.
- **Notion 문서 동기화:** 글로벌 지침(`CLAUDE.md`) 또는 스킬 파일(`~/.claude/skills/`)을 생성·수정·삭제할 때, Notion의 **"클로드코드_문서"**에도 변경 내용을 반영한다. 지침/스킬 수정 완료 후 Notion 업데이트를 누락하는 것은 지침 위반이다.
- **Notion 수정 절차:** (1) `notion-fetch`로 현재 내용 다운로드 → (2) 로컬 지침과 대조하여 갱신 내용 작성 → (3) `replace_content`로 전체 덮어쓰기. 부분 패치(`update_content`)보다 전체 교체를 기본으로 한다.

---

## 1. Session Initialization (자동 실행)

작업 세션 시작 시 다음을 자동으로 수행한다.

1. 프로젝트 루트 구조 파악 + 현재 브랜치/커밋 확인
2. `docs/work-history/history.md` 로드 (작업 이력 요약)
3. `.claude/skills/` 스킬 목록 확인, 작업 유형에 맞는 스킬 로드

→ 완료 후 반드시 **"Context Loaded."** 보고

---

## 2. Hierarchy & Authority (Global Constitution)

- **User Sovereignty:** 사용자의 명시적 승인 없이 행동하지 않는다. 불확실한 지점은 반드시 `Checkpoint` 요청.

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
- **Persistence (필수):** 모든 작업 완료 시 `docs/work-history/history.md`에 `YYYY.MM.DD` 항목으로 처리 내역을 기록한다. 누락은 지침 위반.
