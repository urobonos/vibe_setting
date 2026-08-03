# Unified 단일 통합 문서 — `working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` → `tasks/.../{yyyy-mm-dd}-{작업명}-unified.md`

2026-05-12 시행 단일 통합 문서 양식. 한 파일 안에 **`## 분석` + `## 계획` + `## 실행`** 3 섹션을 통합 작성하며, 완료 시 `working-lifecycle.sh` hook 이 자동으로 `tasks/` 로 이동한다.

## 규칙
- working/ 단계 (진행 중) — `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 단일 파일 (하위 폴더 금지).
- 작성 시 본 템플릿 골격을 그대로 prepend 후 의미만 채운다 (자체 번호 헤더 자유 작성 금지 — `doc-unified-check.sh V1` exit 2 차단).
- 필요한 섹션만 채울 수 있으나 헤더 자체는 SSOT 골격 그대로 유지 (분석 단독 = `## 계획` / `## 실행` 는 "해당 없음" 1행 허용).
- 체크리스트 ≥ 50개 (분석 ≥ 20 + 계획 ≥ 15 + 실행 Self-Critique ≥ 15).
- 완료 마커 = `Status: Done` (시작 라인) + `## Self-Critique` 섹션 동시 존재 → `working-lifecycle.sh` 자동 이동.
  - **⚠️ Status 는 반드시 단독 라인** — hook 정규식이 `^Status:[[:space:]]*Done[[:space:]]*$` **완전일치**라 `Status: Done — {요약}` 처럼 뒤에 설명·구분자(`—`/`-`)를 붙이면 **매칭 실패 → 자동 이동 안 됨**(조용히 실패, 경고 없음). 요약이 필요하면 **직전 줄에 인용문**(`> 완료 요약: …`)으로 분리하고 `Status: Done` 은 단독으로 둔다. (`상태: 완료` 도 동일 규칙.)
- 이동 후 `tasks/.../{yyyy-mm-dd}-{작업명}-unified.md` 로 영구 보존.
- **Status 단일 축 (단계별 필드 신설 금지):** `초안` → `Analysis Complete`(analyze) → `Plan Complete`(plan) → `In Progress`(execute) → `NeedsDecision`(판단 대기) → `Done`. 단계마다 별도 필드를 두지 않고 **한 라인을 덮어쓴다** — 두 벌이면 한쪽만 갱신될 때 tick 이 멈추거나 중복 claim 한다. 부착 주체·소비처 = `custom-plugin/taskflow/commands/{analyze,plan,tick}.md`, 파싱 = `hooks/lib/working-scan.sh`. step 평면 파일은 **별도 축**(`상태:` Pending→In Progress→ReadyToMerge→Done, SSOT = `plan.md` §"step 파일 양식").

## 템플릿

```markdown
---
문서명: {작업 제목} (Unified)
상태: 초안
생성일: {YYYY-MM-DD}
최종 수정일: {YYYY-MM-DD}
작성자: jypark
대상 시스템: {모듈/BC명, 해당 시}
관련 문서: {참조 문서 목록, 해당 시}
---

# {작업 제목} — 단일 통합 문서 ({YYYY-MM-DD})

> {1~2 줄 요약 — 작업 목적·범위·예상 산출물}

## 작성 정보
| 항목 | 내용 |
|------|------|
| 작업명 | {kebab-case 작업명} |
| product | {product 명, 예: claude-harness / hongcafe_global_backend / infra} |
| 점유 세션 (sid) | _(자동 — working-heartbeat.sh, REGISTRY.md 동기화)_ |
| 점유 시작 | _(자동 — working-heartbeat.sh, REGISTRY.md 동기화)_ |
| 개발언어/기술스택 | {php / lambda / aws / infra 등 관련 기술, 복수 시 쉼표 구분} |
| 작업 등급 | {S / M / L} |
| 시작일 | {YYYY-MM-DD} |
| 완료일 | {YYYY-MM-DD, 진행 중이면 - } |
| working 경로 | `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` |
| tasks 이동 경로 | `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` |

---

# § 분석 (Analyze)

## 분석 범위
- {분석 대상 레이어/파일/범위 목록}

## 분석 관점별 요약
| 관점 | 담당 | 핵심 발견 |
|------|------|-----------|
| 아키텍처 | Architect | {요약} |
| 보안 | Security | {요약} |
| 코드 품질 | Reviewer | {요약} |
| 테스트 | Tester | {요약} |
| 성능 | Performance | {요약} |
| 데이터 | Data | {요약} |

## 1. Critical 이슈 (즉시 수정 필요)

### 1-1. {이슈 제목}
| 파일 | 줄 | 설명 |
|------|-----|------|
| `파일명` | 줄번호 | 설명 |

## 2. High 이슈 (릴리스 전 수정 필요)

### 2-1. {이슈 제목}
| 항목 | 상태 | 파일 |
|------|------|------|
| 항목명 | 상태 | 파일명 |

## 3. Medium 이슈 (권장 수정)

### 3-1. {이슈 제목}
| 패턴 | 영향 범위 |
|------|----------|
| 패턴명 | 범위 |

## 4. Low 이슈 (선택적 개선)

### 4-1. {이슈 제목}
- {설명}

## 5. 트레이드오프 (3-Consultants 소환 시)

| 관점 | Pragmatist | Visionary | Innovator |
|------|------------|-----------|-----------|
| 핵심 주장 | ... | ... | ... |
| 장점 | ... | ... | ... |
| 리스크 | ... | ... | ... |

## 6. 우선순위 권고

| 순위 | 카테고리 | 작업 | 등급 | 예상 파일 수 |
|------|---------|------|------|-------------|
| **1** | {카테고리} | {작업 설명} | {등급} | {파일 수} |

---

# § 계획 (Plan)

## 작업 목표
{작업의 명확한 목표 기술}

## 수정 대상
| # | 파일/모듈 | 변경 유형 | 설명 |
|---|----------|----------|------|
| 1 | `파일 경로` | 신규/수정/삭제 | {변경 내용} |

## Blueprint

### 디렉토리 구조
{Architect 설계 구조}

### 클래스/메서드 시그니처
{인터페이스 계약}

### 스키마 변경 (해당 시)
{Data 설계 스키마}

## 작업 분해 (WBS)
| # | 작업 | 의존관계 | 담당 | 예상 규모 |
|---|------|---------|------|-----------|
| 1 | {작업} | - | Worker | {S/M/L} |

## Step 분해 (순차 실행 단위)

> WBS 를 step-01~nn 순차 실행 단위로 분해. 각 step 을 working/ 직속 평면 파일 `{yyyy-mm-dd}-{product}-{작업명}-step-NN-{slug}.md` (DEPTH=1, `output-naming-check.sh` 통과) 로 생성하고 아래 인덱스 표로 추적한다. 양식·파일 골격 SSOT = `custom-plugin/taskflow/commands/plan.md §"step 파일 양식"`. (S = 생략 가능 / M·L = 작업이 순차 단위로 나뉠 때 가치)

| step | 제목 | step 파일 | 의존 | 완료 기준(DoD) | 상태 |
|------|------|----------|------|---------------|------|
| 01 | {제목} | `...-step-01-{slug}.md` | - | {DoD} | Pending |
| 02 | {제목} | `...-step-02-{slug}.md` | 01 | {DoD} | Pending |

> `/taskflow:execute` 이 이 인덱스를 step-01 부터 의존 순서대로 순차 소비하며 상태를 `Pending → In Progress → Done` 으로 갱신한다. §3 매칭 step 은 `Pending(승인 대기)` 로 표기하고 `/taskflow:execute` 진입 전 사용자 명시 승인을 받는다.

## 실행 계획
- **Team 3 구성:** {Worker Lead + 멤버 목록 — 등급별 plan-template.md §등급별 플랜 구성 참조}
- **구현 순서:** {레이어별/기능별 순서}

---

# § 실행 (Execute / Result)

## 실행 요약
| 항목 | 내용 |
|------|------|
| 플랜 대비 달성도 | {100% / 부분 완료} |
| 총 변경 파일 수 | {N}개 |
| 커밋 수 | {N}개 |
| 실행 모드 | {3-Team / Vibe Coding Group} |

## 변경 내역
| # | 파일 | 변경 유형 | 설명 |
|---|------|----------|------|
| 1 | `파일 경로` | 신규/수정/삭제 | {변경 내용} |

## Before/After 대조
| 항목 | 최초 실행안 (사용자 지시) | 제안 반영안 (Claude 추가/수정) |
|------|------------------------|-----------------------------|
| 1 | {원래 요구사항} | {추가/수정된 부분} |

> 제안 추가가 0건이라면 "제안 추가: 없음 — 사용자 지시 그대로 반영" 명시.

## 테스트 결과
| 구분 | 건수 | 통과 | 실패 |
|------|------|------|------|
| Unit | {건수} | {통과} | {실패} |
| Feature | {건수} | {통과} | {실패} |

## 잔여 이슈
| # | 등급 | 설명 | 사유 |
|---|------|------|------|
| 1 | {Critical/High/Medium/Low} | {이슈 설명} | {미해소 사유} |

## 롤백 (Rollback)
| # | 변경 항목 | 롤백 절차 |
|---|---------|----------|
| 1 | {커밋/파일/스키마} | {복원 명령 또는 절차} |

---

# § 공통 (Cross-cutting)

## 타당성 검토 (Feasibility Review)

| # | 권고/설계 항목 | 공식 근거 | 출처 |
|---|------------|----------|------|
| 1 | {권고 내용} | {공식 문서/RFC/IEEE/OWASP 등} | [Source: {name} §{id}] |

> CLAUDE.md §4 — 라이브러리/아키텍처/API/보안/설계 작업 공식 문서 근거 필수. `[Source: <name> §<id>]` 형식 인용 ≥ 1건 강제 (`doc-unified-check.sh V6`).

## 참조 출처 (Reference Location)

> **무조건 필수 (2026-06-02~)** — 작성 내용의 **출처 위치**를 기록한다 (기획서 = 페이지, docs = 파일:줄). `## 타당성 검토`([Source: §id] 공식 기술표준) 와 **별개**의 내용 provenance. 강제: `doc-unified-check.sh V2` (exit 2 — `## 참조 출처` 섹션 + `[참조: ...]` ≥ 1건).

| # | 내용/섹션 | 출처 유형 | 참조위치 |
|---|----------|----------|---------|
| 1 | {차용 내용 요약} | 기획서 / docs / 코드 / 웹 / 없음 | [참조: ...] |

> **형식:** 기획서 PDF `[참조: 화면설계서_v0.2.0 p.12]`(슬라이드형 `슬라이드 #12`) · 기획 md `[참조: 기획협의통합문서.md L120]`(또는 `§"헤딩"`) · 권고 tsv `[참조: 권고사항정리_v2.tsv #34]` · docs 내부 `[참조: docs/{product}/.../foo.md L40]` · 코드 `[참조: path/Foo.php:88]` · 웹 `[참조: 제목 — https://... (접속 YYYY-MM-DD)]` · 원본(차용 없음) `[참조: 없음 — 신규 분석]`.
> **인라인(권장):** 본문 차용 문장 옆 `[참조: ...]` 태그 직접 부착.

## 변경 영향 기록 (Change Impact Log)

| # | 변경 사항 | 개선점 | 수행 이유 (Why) |
|---|----------|--------|----------------|
| 1 | {무엇이 변경되는가} | {어떤 개선이 있는가} | {왜 해야 하는가} |

> CLAUDE.md §4 — 변경/개선/이유 3열 필수, 이유 생략 금지 (`doc-unified-check.sh V3`).

## 장기 영향 (Long-term Impact)

| # | 영향 영역 | 단기 (즉시) | 장기 (3~12개월) | 누적·전이·재발 형태 |
|---|---------|-----------|----------------|---------------------|
| 1 | {SSOT/모듈/데이터/산출물} | {당장 발생} | {누적되면 어떻게 되는가} | {동일 문제 재발 시나리오} |

## 재발 방지 (Regression Prevention)

| # | 재발 위험 패턴 | 감지 수단 (hook/lint/test) | 차단 강도 | 잔여 리스크 |
|---|-------------|---------------------------|----------|-------------|
| 1 | {시나리오} | {hook / lint / 테스트 / 리뷰} | {차단(exit 2) / 경고 / 문서만} | {0 또는 N} |

## SSOT 일관성 (SSOT Consistency)

| # | SSOT (룰/템플릿/hook) | 본 작업이 어긋나는 지점 | 갱신 필요 | 갱신 항목 |
|---|---------------------|----------------------|--------|----------|
| 1 | {CLAUDE.md §X / SKILL.md / hook} | {불일치 지점} | Y/N | {갱신 텍스트} |

> CLAUDE.md §4.1 강제 3섹션 — S(단발) = 1행 "해당 없음 (사유)" 허용, M·L = 실질 시나리오 1건+ 필수.

---

# § 타당성 검토 (Feasibility — 선택, /taskflow:feasibility 진입 시)

## 공식 근거 인용
| # | 권고/설계 항목 | 공식 근거 | 출처 |
|---|------------|----------|------|
| 1 | {권고 내용} | {공식 문서/RFC/IEEE/OWASP} | [Source: {name} §{id}] |

> `doc-unified-check.sh V6` — `[Source: <name> §<id>]` ≥ 1건 강제 (헤더 존재 시).
> CLAUDE.md §4.1 5영역 (분석·설계 / 라이브러리·프레임워크 / 아키텍처 / API 설계 / 보안·인증) 진입 시 필수.

---

# § 검증 (Verify — 선택, /taskflow:verify 진입 시)

## e2e 5점 체크
| # | 점검 항목 | 결과 (PASS/FAIL) | 근거 |
|---|---------|----------------|------|
| 1 | env / 설정 | - | - |
| 2 | 함수/클래스 시그니처 | - | - |
| 3 | DB 스키마 | - | - |
| 4 | 프로덕션 curl | - | - |
| 5 | mock 검증 분리 | - | - |

> `doc-unified-check.sh V5` — 5건 모두 PASS 시 통과, 일부 FAIL 시 exit 2.
> SSOT: hongcafe:php8 §"e2e 검증" + CLAUDE.md §4.3 "e2e 검증 (필수)".

---

# § 리뷰 (Review — 선택, /taskflow:review 진입 시)

## simplify 스킬 결과
- 코드 재사용성 / 가독성 / 효율성 리뷰 결과 요약.

## Self-Critique 보강
(§ 실행 §Self-Critique 체크리스트와 동일 — 미체크 항목 채움)

> 진입점: `/taskflow:review` (~/.claude/custom-plugin/taskflow/commands/review.md) + `simplify` 스킬 보조.

---

# § 회고 (Retrospective — 선택, /taskflow:retro 진입 시)

## 본 세션 변경 내역 요약
| # | 변경 사항 | 영향 영역 |
|---|----------|---------|
| 1 | {변경} | {영역} |

## history.md / summary.md 기록 확인
- [ ] `~/.claude/docs/{product}/tasks/history.md` 항목 추가
- [ ] `~/.claude/docs/{product}/tasks/YYYYMMDD/summary.md` 항목 추가

## 잘된 점 / 개선점
- 잘된 점: {1~2줄}
- 개선점: {1~2줄}

> 진입점: `/taskflow:retro` (~/.claude/custom-plugin/taskflow/commands/retro.md). CLAUDE.md §4.1 "Persistence (필수)" 정합.

---

## 참조 문서 검토 결과 (프로젝트별 적용)

> **적용 대상:** 프로젝트 CLAUDE.md 에 §"분석·계획 시 참조 강제 룰" 정의 시 본 섹션 필수. 미정의 product 는 "해당 없음 (적용 룰 없음)" 1행으로 면제 (예: `hongcafe_global_backend` 만 6항목 강제).

### A. 합의된 권고안 일치
- [ ] TSV 행 #N 정합 — {요지}

### B. 기획안 슬라이드 매핑
- 미국 화면설계서: 슬라이드 #{번호 범위} ({화면명})

### C. 체크리스트 검증
- [ ] checklist/{파일명} #L{행} 충족 — 근거: {...}

### D. API 문서 사전 검토
- 기존 EP 충돌: {N건}
- 페이로드 키 케이스: camelCase ✓
- 에러 코드 표준 6종: ✓
- HTTP 상태 코드 정합 (RFC 7231): ✓

### E. IEEE 산출물 정합
- SRS: {ID 목록}
- SDD: {ID 목록}
- IDD: {ID 목록}
- 추적성 매트릭스 갱신: {요}/{불요}

### F. 레거시 비교 (다국가 통합 프로젝트 전용)
| 항목 | KR 레거시 | JP 레거시 | 신규 글로벌 | 변경 의도 |
|------|---------|---------|----------|--------|
| {항목} | `path:line` | `path:line` | `path:line` | {사유} |

---

# § 체크리스트 (≥ 50개)

## 분석 체크리스트 (≥ 20)

### 범위 정의
- [ ] 분석 대상 파일/모듈 목록 확정
- [ ] 분석 제외 범위 명시
- [ ] 관련 BC(Bounded Context) 식별
- [ ] 영향받는 외부 시스템 식별
- [ ] 상위/하위 의존 모듈 식별

### 코드 품질
- [ ] 미사용 코드/import 존재 여부
- [ ] 중복 코드 패턴 식별
- [ ] DI 원칙 준수 여부
- [ ] 타입 선언 적용 여부
- [ ] 에러 핸들링 일관성
- [ ] 네이밍 컨벤션 준수
- [ ] 매직 넘버/하드코딩 상수 존재
- [ ] TODO/FIXME/HACK 잔존 여부

### 보안
- [ ] SQL Injection 취약점
- [ ] XSS 취약점
- [ ] CSRF 방어 적용 여부
- [ ] 인증/인가 누락 엔드포인트
- [ ] 민감 정보 하드코딩
- [ ] 입력값 검증 누락
- [ ] 권한 상승 가능성

## 계획 체크리스트 (≥ 15)

### 설계 검증
- [ ] 기존 아키텍처 패턴 일관성
- [ ] BC 경계 침범 없음
- [ ] 신규 의존성 최소화
- [ ] 하위 호환성 확인
- [ ] 인터페이스 계약 명확성
- [ ] 에러 처리 전략 정의

### 테스트 계획
- [ ] 단위 테스트 작성 대상 식별
- [ ] 통합 테스트 필요 여부
- [ ] 기존 테스트 영향 범위
- [ ] 엣지 케이스 목록 작성

### 배포/운영
- [ ] 마이그레이션 롤백 계획
- [ ] 환경 변수 추가 시 반영 계획
- [ ] 다운타임 여부 확인
- [ ] 배포 순서 정의
- [ ] 모니터링 지표 추가 필요 여부

### 프로세스
- [ ] Checkpoint 발동 조건 해당 여부
- [ ] 타당성 검토 공식 근거 제시 완료
- [ ] 변경 영향 기록 작성 완료
- [ ] 장기 영향 / 재발 방지 / SSOT 일관성 3섹션 작성

## Self-Critique 체크리스트 (≥ 15)

### 보안
- [ ] 민감 정보 노출 없음 (로그, 응답, 에러)
- [ ] 인증/인가 누락 없음
- [ ] 입력값 검증 적용
- [ ] SQL Injection / XSS 방어 확인

### 로직
- [ ] 엣지 케이스 처리 완료
- [ ] 예외 흐름 정상 동작
- [ ] 사이드 이펙트 없음
- [ ] 기존 기능 영향 없음 (회귀 검증)
- [ ] NULL/빈값/기본값 처리 확인
- [ ] 동시성 이슈 없음

### 코드 품질
- [ ] 코딩 컨벤션 준수
- [ ] 불필요한 코드 없음
- [ ] 적절한 네이밍
- [ ] 하드코딩 값 없음

### 테스트 커버리지
- [ ] 신규 코드 단위 테스트 작성
- [ ] 전체 테스트 스위트 통과

### 이전 단계 검증
- [ ] 분석 체크리스트 전체 체크(`[x]`) 완료
- [ ] 계획 체크리스트 전체 체크(`[x]`) 완료
- [ ] 미체크 항목 잔여 이슈로 기록

---

## 변경 기록

| 날짜 | 내용 |
|------|------|
| {YYYY-MM-DD} | 초안 작성 (working/) |
| {YYYY-MM-DD} | tasks/ 자동 이동 (working-lifecycle.sh) |

---

> 완료 요약: {한 줄 요약 — 요약은 여기 인용문에. 아래 Status 라인엔 붙이지 않는다}
Status: {초안 | Analysis Complete | Plan Complete | In Progress | NeedsDecision | Done}
```

> **Status 라인은 문서 전체에 단 1개다** (2026-07-28 교정). 이전 템플릿은 `Status: Plan Complete` 와 `Status: Done` 을 **두 줄로 나란히** 실어 단계 전이를 예시했는데, 골격을 그대로 prepend 하는 사용 방식(§규칙) 상 두 줄이 함께 복사됐다. 여기에 작성자가 헤더 Status 를 따로 채우면서 **한 파일에 Status 가 2~3줄 생기는 drift 가 87건 누적**됐다 (`tasks/` 전수 실측, 2026-07-28 정정). `working-scan.sh` 는 첫 줄만 파싱하므로 어느 줄이 남았느냐로 tick·control 판정이 갈렸다. 단계 전이는 **줄을 추가하지 말고 그 한 줄을 덮어쓴다** (§규칙 "Status 단일 축").
>
> **`Status: Done` 은 단독 라인이어야 한다** — 자동 이동 hook 이 완전일치라 `Status: Done — 요약` 형태는 탈락한다(§규칙 참조). 요약은 직전 인용문(`> 완료 요약: …`)으로 분리한다.

## 등급별 워크플로우

| 등급 | 진행 방식 | 통합 문서 분량 |
|------|----------|---------------|
| **S** | 분석/계획/실행 모두 압축. 분석 = Critical 만, 계획 = 수정 대상 표만, 실행 = 변경 내역 + Self-Critique. | ~ 200 줄 |
| **M** | 표준 통합. 분석 = Critical~Medium + 트레이드오프, 계획 = Blueprint + WBS, 실행 = 전체. | ~ 400 줄 |
| **L** | 상세 통합. 전체 템플릿. 3-Team 워크플로우 병행. | ~ 600+ 줄 |

## 자동 이동 트리거 (working-lifecycle.sh)

| 트리거 | 조건 | 발동 시점 |
|--------|------|---------|
| 본문 마커 자동 | `^Status:[[:space:]]*Done[[:space:]]*$` (**완전일치** — 뒤에 설명 부기 시 탈락) + `## Self-Critique` 동시 존재 | PostToolUse (Edit/Write 직후) |
| 사용자 명시 | `/taskflow:save now` 슬래시 또는 `working-lifecycle.sh` 자연어(`작업 완료` / `tasks 이동` / `done`) 키워드 | UserPromptSubmit |

## 사후 hook 검증 (tasks/ 직접 Edit/Write 시)

> **주의 (2026-07-15 교정):** working/ → tasks/ 자동 이동은 `working-lifecycle.sh` 내부 shell `mv` 라 PostToolUse hook 이 **발동하지 않는다** (`execute.md` §"QA 게이트" known-limitations 동일 자인). 아래 검증의 실효 발동 표면 = tasks/ 문서를 **직접 Edit/Write** 하는 순간뿐이다.

| Hook | 검증 항목 | 차단 강도 |
|------|---------|----------|
| `doc-unified-check.sh V1` | `*-unified.md` 패턴 분기 — analyze + plan + result 합집합 ≈ 20 헤더 | exit 2 |
| `doc-unified-check.sh V4` | 체크리스트 ≥ 30 | exit 2 |
| `doc-unified-check.sh V3` | `## 변경 영향` + 3열 표 | exit 0 (경고) |
| `doc-unified-check.sh V6` | `## 타당성 검토` + `[Source:...]` ≥ 1 | exit 0 (경고) |
