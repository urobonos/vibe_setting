---
name: api-spec-audit
description: >
  API 명세(Routes / api-docs MD / OpenAPI YAML) ↔ IEEE 산출물(SRS / SDD / IDD) 9항목 정합성 자동 audit 스킬.
  EP 수 대조 → SRS 매핑 → 인증 정책 → 응답 스키마 → 환경별 URL → 에러 코드 → 페이지네이션 → 페이로드 키 케이스 → API 버전 9축 교차 검증.
  3개 모드 — `module` (단일 모듈, 예: commerce/auth/member), `endpoint` (단일 EP), `full` (전체 모듈 일괄).
  FAIL/WARN/PASS 등급 + 식별자 자동 생성 (`{MODULE}-{TYPE}-{CATEGORY}-{SEQ}` 형식, 예: COMMERCE-ITEMS-DEF-001).
  자동 트리거 (API 정합성·명세 검증·SRS 매핑 키워드) + `/api-spec-audit` 슬래시 커맨드. 산출물 = `output/audit/api-spec-audit/` 단일 마크다운.
triggers:
  - "API 명세 audit"
  - "API 명세 검증"
  - "API 정합성"
  - "API 정합 audit"
  - "Routes SRS 대조"
  - "Routes SDD 대조"
  - "API SDD 매핑"
  - "API SRS 매핑"
  - "OpenAPI YAML 검증"
  - "OpenAPI 정합성"
  - "스펙 정합성"
  - "스펙 audit"
  - "api-docs SRS"
  - "api-docs 정합"
  - "엔드포인트 명세 일치"
  - "EP 수 대조"
  - "IEEE 정합"
  - "/api-spec-audit"
version: 1.0.0
user-invocable: true
depends_on: [task-docs, security-audit, php8]
conflicts_with: []
min_claude_md_version: "4.0"
---

# API Spec Audit Skill

API 명세 (Routes / api-docs MD / OpenAPI YAML) 와 IEEE 산출물 (SRS / SDD / IDD) 의 정합성을 9축으로 교차 검증해 FAIL/WARN/PASS 등급 + 식별자를 자동 생성한다.

> **[용도 한정]** 명세-산출물 *정합성 검증* 전용. 신규 API 설계·구현은 본 스킬 대상이 아니다 — `php8` / `api-team`. 단순 코드 리뷰·리팩토링도 대상이 아니다.
> **Why:** 동일한 9축 매트릭스를 매번 cold context 로 재구성하면 (1) EP 수 단순 비교만으로 통과 처리해 응답 스키마 불일치를 놓치고, (2) 식별자 형식이 매번 달라져 이전 audit 결과와의 추적이 불가능해진다. 본 스킬은 매트릭스·식별자·등급 기준을 SSOT 로 고정해 결과 비교 가능성을 보장한다.

> **[실행 주체]** Claude 본체 단독. 매트릭스 9축은 read-only 분석으로 검증 가능 — 멀티 Agent spawn 불필요. 단 `full` 모드(전체 모듈 일괄 audit) 시 모듈별 병렬 Agent 분배는 Lead 판단으로 허용.

---

## 1. 호출 방식

### 1.1. 자동 트리거

frontmatter `triggers` 매칭 시 즉시 호출. 모호한 경우 한 줄 확인 후 진행.

**트리거 예시 (호출됨):**
- "commerce 모듈 API 정합 audit 돌려줘"
- "Routes 랑 SRS 대조해서 누락 EP 찾아"
- "OpenAPI YAML 이랑 SDD 응답 스키마 일치하는지 확인"

**트리거 안 됨 (의도된 차단):**
- "이 API 어떻게 만들지?" → php8 / api-team
- "SRS 새로 작성해줘" → task-docs (산출물 작성)
- "엔드포인트 디버그" → api-team debug

### 1.2. 슬래시 커맨드

```
/api-spec-audit module {MODULE}                     — 단일 모듈 9축 audit
/api-spec-audit endpoint {METHOD} {PATH}            — 단일 EP 9축 audit
/api-spec-audit full [--exclude={MODULE},...]       — 전체 모듈 일괄 audit
```

`{MODULE}` ∈ `auth | board | call | chat | commerce | content | event | member | notification | payment | reservation | service | shop | social | support` (실제 모듈은 `app/Modules/` SSOT — 본 표는 예시).

예: `/api-spec-audit module commerce` / `/api-spec-audit endpoint POST /v1/orders` / `/api-spec-audit full --exclude=archive`

---

## 2. 9축 정합성 매트릭스 (SSOT)

| # | 축 | 검증 내용 | 데이터 소스 |
|---|----|----------|------------|
| **1** | **EP 수 대조** | Routes EP 수 = api-docs MD EP 수 = OpenAPI YAML EP 수 = SRS EP 수 (4-way) | `app/Config/Routes.php` + 모듈 라우트 / `api-docs/{module}.md` / `api-docs/{module}.yaml` / `specs/{module}-srs.md` |
| **2** | **SRS 매핑** | 각 EP 가 SRS 의 기능 요구사항 (FR-{N}) 에 매핑되어 있는가 | SRS `traceability matrix` 섹션 |
| **3** | **인증 정책** | Routes filter (`['auth']` 등) 와 SDD §인증 표, OpenAPI `security` 블록 3-way 일치 | Routes filter / `specs/{module}-sdd.md` §인증 / OpenAPI `security` |
| **4** | **응답 스키마** | api-docs MD 응답 예시, OpenAPI `components.schemas`, IDD 응답 모델 3-way 일치 | api-docs MD / OpenAPI YAML / `specs/{module}-idd.md` |
| **5** | **환경별 URL** | dev / staging / prod 환경별 base URL 이 OpenAPI `servers` + SDD §배포 + 실제 nginx 설정 3-way 일치 | OpenAPI `servers` / SDD §배포 / `infra/.../nginx.conf` (가능한 경우) |
| **6** | **에러 코드** | Controller 가 throw 하는 에러 코드 vs api-docs MD `에러 응답` vs IDD `에러 카탈로그` 3-way 일치 | Controller `throw new ApiException(...)` / api-docs MD / IDD |
| **7** | **페이지네이션** | list EP 가 동일 페이지네이션 규약 (cursor / offset / page-size 키 이름·기본값·최대값) 사용 | api-docs MD `요청 파라미터` / OpenAPI `parameters` / Controller validation |
| **8** | **페이로드 키 케이스** | 요청·응답 payload 키가 모듈 전체 일관 (snake_case vs camelCase) — 모듈 간 혼용 시 WARN | api-docs MD / OpenAPI / 실제 Controller validation 룰 |
| **9** | **API 버전** | Routes prefix (`/v1/`, `/v2/`), OpenAPI `info.version`, SRS §버전 3-way 일치 | Routes / OpenAPI `info.version` / SRS §버전 |

**축 우선순위 (debug/triage 시):**
- **CRITICAL**: 1 (EP 누락) · 3 (인증 누락 — 보안 영향) · 6 (에러 카탈로그 불일치 — 클라이언트 파싱 실패)
- **HIGH**: 2 (SRS 미매핑) · 4 (응답 스키마 불일치) · 5 (환경 URL 불일치)
- **MEDIUM**: 7 (페이지네이션 규약) · 8 (키 케이스) · 9 (버전)

---

## 3. 식별자 자동 생성 규칙

audit 결과 모든 발견 사항에 식별자를 부여해 추적성을 보장한다.

**형식:** `{MODULE}-{TYPE}-{CATEGORY}-{SEQ}`

| 필드 | 값 | 설명 |
|------|------|------|
| **MODULE** | 대문자 모듈명 | `COMMERCE`, `AUTH`, `MEMBER` 등 |
| **TYPE** | 3-letter 약어 | `EP`(엔드포인트) / `SCH`(스키마) / `ERR`(에러 코드) / `AUTH`(인증) / `URL`(환경 URL) / `VER`(버전) / `PAG`(페이지네이션) / `KEY`(키 케이스) / `MAP`(SRS 매핑) |
| **CATEGORY** | 3-letter 약어 | `MIS`(missing — 한쪽에만 존재) / `DEF`(definition mismatch — 정의 불일치) / `DUP`(duplicated) / `INV`(invalid format) |
| **SEQ** | 3자리 일련번호 | `001`, `002`, ... 모듈+타입+카테고리 단위로 시작 |

**예시:**
- `COMMERCE-EP-MIS-001` — commerce 모듈에서 Routes 에는 있으나 api-docs MD 에 정의 없는 EP
- `AUTH-SCH-DEF-003` — auth 모듈에서 OpenAPI 와 IDD 응답 스키마 정의 불일치 (3번째 발견)
- `MEMBER-AUTH-MIS-001` — member 모듈에서 Routes filter 에 auth 누락 (인증 적용 안 됨)

식별자는 audit 산출물 + 후속 수정 task PR 제목에 활용해 추적성 보존.

---

## 4. 등급 정의

| 등급 | 정의 | 처리 |
|------|------|------|
| **FAIL** | CRITICAL 축 (1·3·6) 위반 또는 다수 HIGH 축 위반 | Checkpoint 발동 후 즉시 수정 작업 분리 |
| **WARN** | HIGH 축 (2·4·5) 위반 또는 MEDIUM 축 다수 위반 | 산출물 기록 + 다음 sprint 반영 권고 |
| **PASS** | 9축 전체 정합 | 식별자 없이 통과 기록만 |

**Why CRITICAL/HIGH/MEDIUM 분리:** 사용자(jypark) 의 의사결정 패턴이 우선순위 매트릭스 기반이라 등급 = 처리 임계값을 명시해야 즉시 수정 vs 추후 반영을 구분 가능. 단일 PASS/FAIL 2등급은 의사결정 단계에서 우선순위 재계산 비용이 발생.

---

## 5. 작동 흐름

```
사용자 발화 (자동 매칭) 또는 /api-spec-audit {mode} {target}
  ↓
Claude 본체
  1. 입력 정규화 — mode, MODULE 또는 (METHOD,PATH) 추출
  2. 데이터 소스 수집 (read-only):
     - Routes (Config/Routes.php + 모듈 라우트)
     - api-docs MD (api-docs/{module}.md)
     - OpenAPI YAML (api-docs/{module}.yaml)
     - SRS / SDD / IDD (specs/{module}-{srs|sdd|idd}.md)
  3. 9축 매트릭스 순회 (1~9 순서로 검증)
  4. 각 축별 발견 사항 → 식별자 부여 + 등급 산정
  5. 종합 등급 결정 (FAIL/WARN/PASS)
  6. 산출물 작성 + 사용자 보고 (요약 3~5줄 + 산출물 경로)

  full 모드 추가 단계:
  - 모듈별 병렬 Agent spawn (Lead 판단, run_in_background=true)
  - 각 모듈 audit 결과 종합 → 모듈 매트릭스 표 생성
```

---

## 6. 산출물 형식

### 6.1. module 모드 — `{date}-{module}-audit.md`

```markdown
---
title: "{MODULE} 모듈 API 명세 정합성 audit"
type: api-spec-audit
date: {YYYY-MM-DD}
module: {MODULE}
overall_grade: {FAIL|WARN|PASS}
---

# {MODULE} 모듈 API 명세 정합성 audit

> 종합 등급: **{FAIL|WARN|PASS}** | FAIL {N}건 / WARN {N}건 / PASS {N}건

## 작성 정보
| 항목 | 값 |
| 모드 | module |
| 모듈 | {MODULE} |
| 데이터 소스 | Routes / api-docs MD / OpenAPI YAML / SRS / SDD / IDD |

## 1. EP 수 대조
| 소스 | EP 수 |
|------|------|
| Routes | {N} |
| api-docs MD | {N} |
| OpenAPI YAML | {N} |
| SRS | {N} |

| 식별자 | 등급 | 항목 | 위치 |
|--------|------|------|------|
| {MODULE}-EP-MIS-001 | FAIL | Routes 에만 존재: `POST /v1/{module}/foo` | `app/Modules/{Module}/Config/Routes.php:42` |

## 2. SRS 매핑
(... 표 ...)

## 3. 인증 정책
(... 표 ...)

## 4. 응답 스키마
(... 표 ...)

## 5. 환경별 URL
(... 표 ...)

## 6. 에러 코드
(... 표 ...)

## 7. 페이지네이션
(... 표 ...)

## 8. 페이로드 키 케이스
(... 표 ...)

## 9. API 버전
(... 표 ...)

## 종합 발견 사항 (식별자 일람)

| 식별자 | 등급 | 축 | 요약 | 권고 조치 |
|--------|------|----|------|----------|
| {MODULE}-EP-MIS-001 | FAIL | 1 | ... | ... |
| {MODULE}-AUTH-MIS-001 | FAIL | 3 | ... | ... |
| {MODULE}-SCH-DEF-003 | WARN | 4 | ... | ... |

## 타당성 검토
| 항목 | 근거 출처 |
| 9축 매트릭스 | sns-oauth/api-spec-audit SKILL.md §2 |
| 식별자 형식 | 본 스킬 §3 |
| 등급 임계값 | 본 스킬 §4 |

## 변경 영향 기록
(audit 단계 — 즉시 변경 없음. FAIL 항목은 별도 수정 task 분리)

## 변경 기록
| 날짜 | 작성자 | 변경 |
```

### 6.2. endpoint 모드 — `{date}-{method-path-slug}-endpoint-audit.md`

단일 EP 에 대해 9축을 모두 적용. 표 구조는 module 모드와 동일하지만 EP 1개 한정.

### 6.3. full 모드 — `{date}-full-audit.md`

전체 모듈 audit. 산출물에 다음 추가:

```markdown
## 모듈 매트릭스
| 모듈 | EP 수 | FAIL | WARN | PASS | 종합 |
|------|------|------|------|------|------|
| auth | 23 | 0 | 2 | 21 | WARN |
| commerce | 47 | 3 | 5 | 39 | FAIL |
| member | 31 | 0 | 0 | 31 | PASS |
...

## 모듈별 식별자 일람
(각 모듈 발견 사항을 평면 리스트로 통합 — 우선순위 정렬)
```

각 모듈 상세는 module 모드 산출물 별도 생성 후 본 산출물에서 링크.

---

## 7. 가드레일

- **CLAUDE.md §3 Checkpoint 5조건 우선:** FAIL 등급 발견 시 *광범위한 영향 범위* (인증 누락·EP 누락) 가능성으로 Checkpoint 자동 발동. 본 스킬 자동 호출도 Checkpoint 우선.
  **Why:** API 명세 정합성 위반은 단일 모듈 내 수정으로 끝나지 않고 클라이언트(FE/외부 연동) 까지 영향 — Checkpoint 없이 진행 시 audit 결과를 즉시 코드 수정으로 변환해 클라이언트 호환성을 깨뜨릴 수 있음.
- **audit 결과 자동 수정 금지:** CLAUDE.md §4 "audit 결과 자동 수정 금지" 룰 적용. 본 스킬은 *현황 진단 도구* 이며 FAIL/WARN 항목을 자동으로 수정 작업으로 변환하지 않는다. 사용자가 특정 식별자에 대해 명시적으로 수정 요청 시에만 별도 task 생성.
- **데이터 소스 부재 처리:** SRS/SDD/IDD 가 작성되지 않은 모듈은 해당 축 (2·3·4) 을 SKIP 처리하고 산출물에 명시. SRS 부재만으로 FAIL 처리하지 않는다 (SRS 작성 자체는 별도 task — `task-docs` 영역).
- **타 프로젝트 적용 시:** 9축 매트릭스 §2 와 식별자 형식 §3 은 본 스킬 SSOT 로 고정. 다른 프로젝트에서 추가 축 (예: gRPC schema, GraphQL resolver) 이 필요한 경우 §2 에 신규 축 추가 + 우선순위 재배치.

---

## 8. 산출물 위치 (단일)

```
~/.claude/docs/{product}/output/audit/api-spec-audit/
  └─ {YYYY-MM-DD}-{module|method-path-slug|full}-audit.md
```

> `{product}` = `basename $CWD` (단 `.claude` → `claude-harness` 예외). 변환 SSOT 는 `hooks/lib/product-resolver.sh` 의 `resolve_product` 함수.

**bash 사용 예:**
```bash
source ~/.claude/hooks/lib/product-resolver.sh
PRODUCT=$(resolve_product "$PWD")
OUTPUT_DIR=~/.claude/docs/$PRODUCT/output/audit/api-spec-audit
```

**카테고리 분류:** `audit/` (CLAUDE.md §File Paths 7 카테고리 중 자가 점검·정합성 검사). `verification/` 가 아닌 `audit/` 인 이유 — 본 스킬은 *지침/명세 준수 검사* 이지 *환경 간 동작 비교* 가 아님.

**파일명 규칙:**
- 날짜 prefix `YYYY-MM-DD-` 필수 (CLAUDE.md §File Paths 룰)
- module 모드: `{module}-audit.md` (예: `2026-05-06-commerce-audit.md`)
- endpoint 모드: `{method-path-slug}-endpoint-audit.md` (예: `2026-05-06-post-v1-orders-endpoint-audit.md`)
- full 모드: `full-audit.md` (예: `2026-05-06-full-audit.md`)

`output-naming-check.sh` hook 호환.

---

## 9. 변경 기록

| 버전 | 날짜 | 변경 |
|------|------|------|
| 1.0.0 | 2026-05-06 | 최초 작성 — 9축 매트릭스 / 식별자 자동 생성 / FAIL·WARN·PASS 3등급 / module·endpoint·full 3 모드 |
