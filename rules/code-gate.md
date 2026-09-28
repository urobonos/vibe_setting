---
paths:
  - "**/*.php"
  - "**/*.js"
  - "**/*.ts"
  - "**/*.py"
  - "**/*.sql"
---

# 코드 변경 룰 (CLAUDE.md §4.1·§4.3 에서 이관, 2026-09-28)

- **코드 라이프사이클 게이트 (필수, 2026-07-08):** 코드 파일(php/js/ts/py/sql) 변경 = **전** 세션 §계획 문서 필수 (`gate-enforce.sh` PreToolUse **hard 차단** — 상태값·override 키워드·면제·fail-open 조건은 차단 메시지가 전량 출력) + **후** `/taskflow:verify`(e2e 5점)·`/taskflow:review` 필수 체인 (**규율** — hook 은 §검증 표 artifact 만 검사). SSOT = `hooks/{gate-enforce,gate-approve}.sh` + `custom-plugin/taskflow/commands/execute.md`.
- **e2e 검증 (필수):** 코드 수정 완료 판단 = 유닛 테스트 + 5점 체크 (env/함수·클래스/DB 스키마/프로덕션 curl/mock) — 세부 = `backend:php8` 스킬 §"e2e 검증" SSOT.
- **Validation ("No Test, No Merge"):** 수정 = 테스트/실행 증빙 동반 — 강제·면제 = `git-quality-gate.sh` SSOT.
- **Readability:** 주석 없이 읽히는 명시적 코드. 전체 단어 (fullName, index) 사용.
