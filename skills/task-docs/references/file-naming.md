# 산출물 네이밍 규칙 (파일명 규칙)

산출물 파일명은 **탐색 가능성(searchability)** + **시간성(chronology)** + **의미 자체완결성(self-describing)** 을 확보하도록 명명한다. 모든 문서는 **`{yyyy-mm-dd}-` 날짜 prefix 를 필수로** 가진다. 제네릭 단독 이름은 금지한다.

> **Why:** 날짜 prefix 가 없으면 같은 주제의 산출물이 시간순 정렬되지 않아 최신본 식별이 깨지고, `analysis.md` 같은 제네릭 이름은 여러 주제 간 충돌·덮어쓰기를 유발한다.

## 공통 필수 prefix

**모든 문서 파일은 다음 prefix 를 가진다:**

- `tasks/` 하위: `{yyyy-mm-dd}-{작업명}-{type}.md`
- `output/` 하위: `{yyyy-mm-dd}-{topic-slug}-{type}.md`

`{yyyy-mm-dd}` 는 작업 시작일(파일 최초 생성일) ISO-8601 표기 (예: `2026-04-27`). 파일을 같은 날 다시 수정하더라도 prefix 는 유지한다.

## `tasks/YYYYMMDD/{작업명}/` 하위 파일명 규칙

**형식:** `{yyyy-mm-dd}-{작업명}-{type}.md`

- `{type}`: 단계 식별자. 고정 값:
  - `analyze` — Team 1 (Analyze) 분석 결과
  - `plan` — Team 2 (Plan) 실행 계획
  - `result` — Team 3 (Execute) 완료 결과

**예시:**
```
tasks/20260427/pay-refactor/2026-04-27-pay-refactor-analyze.md
tasks/20260427/pay-refactor/2026-04-27-pay-refactor-plan.md
tasks/20260427/pay-refactor/2026-04-27-pay-refactor-result.md
```

> 예외: `tasks/YYYYMMDD/summary.md` (일일 요약) 와 `tasks/history.md` (전체 이력 인덱스) 는 단일 고정 파일이므로 prefix 가 붙지 않는다.

## `output/{topic-slug}/` 하위 파일명 규칙

**형식:** `{yyyy-mm-dd}-{topic-slug}-{type}.md` (kebab-case)

- `{topic-slug}`: 주제를 명확히 나타내는 kebab-case 식별자. 부모 폴더명과 **정확히 일치하거나 확장**(prefix 포함) 한다. 주제에 서비스명·도메인·작업 대상이 포함되면 함께 기입한다.
- `{type}`: 문서 유형 접미사. 허용 값 (확장 가능):
  - `analysis` — 분석 문서
  - `report` — 리포트·현황 보고
  - `recommendation` / `final-recommendation` — 권고안
  - `comparison` — 비교·대조
  - `guide` / `deployment-guide` — 가이드·운영 절차
  - `proposal` — 제안서
  - `reflection` / `checklist` — 회고·체크리스트
  - `summary` — 요약 (주제별 폴더 안에서만 허용)

## 금지 패턴

다음 이름은 시간성·주제 식별이 불가능하므로 차단한다:

- 날짜 prefix 누락: `analysis.md`, `report.md`, `pay-refactor-analyze.md` 등 (날짜가 앞에 없는 모든 파일)
- 제네릭 단독 이름: `analysis.md`, `analyze.md`, `result.md`, `report.md`, `recommendation.md`, `comparison.md`, `guide.md`, `proposal.md`, `summary.md`, `doc.md`, `notes.md`, `readme.md`

## 올바른 예시 (output/)

```
output/global-domain-architecture/2026-04-20-hongcafe-global-domain-cross-region-sso-analysis.md
output/architecture-nextjs-ci4-bff/2026-04-21-architecture-nextjs-ci4-bff-analysis.md
output/global-architecture-analysis/2026-04-22-hongcafe-global-architecture-final-recommendation.md
output/global-architecture-analysis/2026-04-22-hongcafe-global-multiregion-routing-report.md
output/nginx-geoip2-jp-kr-redirect/2026-04-23-nginx-geoip2-jp-kr-redirect-analysis.md
output/nginx-geoip2-jp-kr-redirect/2026-04-23-nginx-geoip2-jp-kr-redirect-deployment-guide.md
```

## 다중 파일이 한 주제 폴더에 있을 때

한 주제에 여러 산출물이 생길 수 있다(분석 + 권고 + 가이드 등). 각 파일은 자체 생성일 prefix 를 가지며 같은 `{topic-slug}` 를 공유한다.

```
output/hongcafe-sso-migration/
├── 2026-04-15-hongcafe-sso-migration-analysis.md
├── 2026-04-17-hongcafe-sso-migration-recommendation.md
└── 2026-04-22-hongcafe-sso-migration-deployment-guide.md
```

## 검증

`~/.claude/hooks/output-naming-check.sh` 가 PreToolUse:Write|Edit 에서 이 규칙을 강제한다 (date prefix 누락 + 제네릭 이름 차단). 위반 시 exit 2 로 차단한다.
