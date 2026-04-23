오늘 날짜 기준 업무 리포트를 생성한다.

## 데이터 소스

모든 작업 산출물은 **글로벌 루트** `~/.claude/docs/{product}/tasks/` 하위에 통합 관리된다.

- 탐색 루트: `~/.claude/docs/*/tasks/`
- `{product}` 식별: 디렉토리명이 곧 product 이름 (`basename` 기반)

## product → [태그] 매핑

| product 디렉토리 | 태그 |
|---|---|
| `hongcafe_global_backend` | `[백엔드]` |
| `hongcafe_global_frontend` | `[프론트]` |
| `infra` | `[인프라]` |
| `claude-harness` | `[하니스]` |
| `hongcafe3` / `hongcafe-japan` 등 레거시 | `[레거시]` |
| 그 외 | `[{product}]` (원본 이름 그대로) |

> 매핑에 없는 신규 product 가 나오면 원본 이름 그대로 표기하고 사용자에게 매핑 등록 여부를 확인한다.

## 수행 절차

1. `~/.claude/docs/*/tasks/` 글로브로 **모든 product 디렉토리** 일괄 스캔.
2. 각 product 의 `history.md` 에서 오늘(`YYYY.MM.DD`) 항목을 우선 확인.
3. 오늘 일자 작업 폴더 `~/.claude/docs/{product}/tasks/YYYYMMDD/` 하위 서브디렉토리를 순회:
   - `analyze.md`만 존재 → **분석 중 (30%)**
   - `analyze.md` + `plan.md` → **계획 완료 (50%)**
   - `analyze.md` + `plan.md` + `result.md` → **완료**
   - `*analyze.md` 또는 `*result.md` 단독 (산출물 유연성, CLAUDE.md §4) → 해당 문서의 체크리스트 체크 비율로 진행률 추정 (체크 0% = 30%, 50~99% = 50%, 100% = 완료)
4. `YYYYMMDD/summary.md` 에서 완료/진행 중 구분 문구를 참고로 삼는다.
5. `YYYYMMDD/todo.md` 가 있으면 미완료 항목은 `(미착수)` 로 추가.
6. 진행률 판정이 서로 상충하면 `history.md` 기록을 우선.

## 출력 형식

```
📋 업무 리포트 — YYYY.MM.DD

[글로벌]-[인프라]-EC2 PHP 설정 반영 (완료)
[글로벌]-[인프라]-Lambda Pub/Sub SDD 작성 (완료)
[글로벌]-[인프라]-Lambda 비즈니스 로직 구현 (30%)
[글로벌]-[백엔드]-API 인증 필터 추가 (50%)
[글로벌]-[프론트]-로그인 페이지 구현 (완료)
[글로벌]-[하니스]-docs 경로 글로벌 이관 (50%)
[글로벌]-[인프라]-CloudFront + HTTPS 적용 (미착수)
```

## 규칙

- 각 줄은 `[글로벌]-[태그]-업무내용 (진행률%/완료/미착수)` 형식.
- `[글로벌]` 은 항상 앞에 붙이고, 하이픈(`-`) 으로 구분, 두 번째 태그로 product 태그 (위 매핑 표) 부여.
- 여러 product 에 걸친 공통 작업(CloudFront / 도메인 / 전역 인프라 등)은 가장 대표적인 태그 1개로 분류하되, 공통 성격이면 `[공통]` 사용.
- 진행률은 task 디렉토리 산출물 기준으로 자동 판단.
- `todo.md` 의 미완료 항목은 `(미착수)` 로 표시.
- 오늘 작업이 없는 product 는 리포트에서 제외 (과거 진행 중 건이 남아있으면 `(진행중)` 으로 별도 표시).
- 출력은 간결하게, 한 줄에 하나의 업무.

## 주간/월간 확장

- 주간: `~/.claude/docs/*/tasks/YYYYMMDD/` 를 최근 7일 범위로 확장 스캔.
- 월간: 최근 30일 범위. 각 날짜의 `summary.md` 타이틀만 수집해도 충분.
- 인자 예시:
  - `/report` — 오늘
  - `/report weekly` — 이번 주 월~오늘
  - `/report monthly` — 이번 달 1일~오늘
