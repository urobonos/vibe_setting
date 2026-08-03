---
description: e2e 5점 검증 진입 — env / 함수·클래스 정의 / DB 스키마 / 프로덕션 curl / mock 검증. `hongcafe:php8` §"e2e 검증" SSOT 기반.
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent
argument-hint: "[작업명]  # 생략 시 진행 중 working/ 문서 식별"
---

e2e 5점 검증 진입 — 코드 수정 완료 판단을 위한 환경/스키마/실 엔드포인트 검증.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 가장 최근 working/ 파일 자동 식별.

## 참조 범위 (사전 전수 조사, 필수)

진입 즉시 CLAUDE.md §4.3 "참조 범위 전수 조사" 절차(3 출처 전수 조사)를 수행하고, §4.4 위치 표기로 참조 결과 표를 화면 출력한 뒤 다음 단계로 진입한다. 3 출처 표·가시화 표 양식·`해당 없음` 행 생략 금지·직전 단계 sweep 재사용 규칙 = 모두 §4.3 SSOT.

- **등급 비례:** S = ② index 스캔만 / M·L = ①②③ 전수.

## e2e 5점 체크 (CLAUDE.md §4.3 "e2e 검증 필수")

| # | 점검 항목 | 검증 수단 | PASS 기준 |
|---|---------|---------|----------|
| 1 | env / 설정 | `grep -E "env\(|\.env|DOTENV"` | 환경 변수 정의 + 로드 경로 확인 |
| 2 | 함수·클래스 시그니처 | `grep -E "^(function|class|public function)"` | 신규/수정 시그니처 정의 + 호출부 정합 |
| 3 | DB 스키마 | `grep -E "schema\|migration\|table\|ALTER"` | 마이그레이션 적용 + Entity·Model·Repository 정합 |
| 4 | 프로덕션 curl | `curl -i` 또는 실제 엔드포인트 호출 | HTTP 200/201 + 응답 페이로드 검증 |
| 5 | mock 검증 분리 | mock/stub/fake 식별 키워드 + 프로덕션 데이터 비교 | mock 결과 ≠ 프로덕션 결과 분리 확인 |

## 동작 3단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① 5점 자동 실행 | working/ §실행 내용 기반 5점 키워드 grep + 실 명령 실행 | 5점 결과 (PASS/FAIL) |
| ② working/ §검증 표 채움 | 5점 결과를 § 검증 (Verify) 섹션 표에 기록 | 표 5행 |
| ③ FAIL 항목 처리 | FAIL ≥ 1건 = working/ §실행 §잔여 이슈 추가 + Status: Partial 권고 | 잔여 이슈 또는 통과 |

> **비필수 사이드이펙트 백로그 격리:** 검증 중 부수적으로 발견한 (① 필수요소 아님 + ② 문제·버그 아님 + ③ 사이드이펙트급) 3조건 충족 항목은 §잔여 이슈로 올리지 말고 backlog 메모리에만 기록. **실제 검증 FAIL·버그는 backlog 가 아니라 §잔여 이슈 + Status: Partial 로 처리** (②가 안전장치). SSOT = CLAUDE.md §4.5 "비필수 사이드이펙트 백로그 격리".

## 자연어 trigger

- `검증해줘` / `e2e 검증` / `verify`

## 강제 hook (신규 — 2026-05-15)

| Hook | 검증 | 차단 강도 |
|------|------|----------|
| `doc-unified-check.sh V5` | 5점 키워드 모두 존재 (env/함수/스키마/curl/mock) | exit 0 (5점 PASS) / exit 2 (일부 FAIL) |

**역소급 면제:** 생성일 < 2026-05-15 산출물은 hint 강등 (exit 0).

**settings.json 등록:** 본 hook 은 사용자 결정 영역 (자동 등록 안 함). 등록 필요 시 사용자 직접 PostToolUse:Edit\|Write 배열에 추가.

## 호출 예

```
/taskflow:verify                                  ← 진행 중 working/ §실행 5점 검증
/taskflow:verify auth-refactor                    ← 특정 작업 5점 검증
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.3 "e2e 검증 (필수)" | 정책 SSOT |
| `hongcafe:php8` 스킬 §"e2e 검증" | 5점 체크 SSOT |
| `~/.claude/skills/task-docs/references/unified-template.md` § 검증 | 양식 SSOT (5행 표 골격) |
| `~/.claude/hooks/doc-unified-check.sh V5` | 5점 PASS 강제 (신규) |

## §3 Checkpoint 우선 적용

- `curl` 프로덕션 호출 = 외부 시스템 연동 (Checkpoint 매칭). 단 read-only (GET) 는 자동 진행, write (POST/PUT/DELETE) 는 사용자 명시 승인 필수.
- 프로덕션 DB 직접 쿼리 = §3 매칭 — 사용자 승인 후 진행.

**worktree 적용 (CLAUDE.md §4.3 (a)):** 검증 자체는 read-only (curl·SELECT·mock 비교). 검증 실패 후 fix 동반 시 §실행 단계로 진입 → worktree 강제.

## Skip 조건

| 영역 | 진행 여부 |
|------|----------|
| 코드 (PHP / Lambda / SQL) 변경 | **필수** — 5점 (env / 함수·클래스 / DB 스키마 / curl / mock) |
| 단순 sh hook / 문서 / commands 수정 | 면제 — Self-Critique (`/taskflow:review`) 만으로 충분 |

## 짝 슬래시

앞 = `/taskflow:execute` / 뒤 = `/taskflow:review`. 본 슬래시 = **외부 환경 검증**(e2e 5점), review = 코드 내부 품질 — 상보적이라 코드 변경 시 둘 다 필수 체인이다(`execute.md` §"코드 변경 = verify + review 필수 체인"). 전체 맵 = `execute.md` §"워크플로우 맵" SSOT.

## Changelog

- 2026-08-03: 구 `## 차별점` 표 → `## 짝 슬래시` 포인터로 축약 (전체 맵 SSOT = `execute.md` §"워크플로우 맵") + `verify + review` 포인터 리터럴 정렬
- 2026-05-15: 신설
