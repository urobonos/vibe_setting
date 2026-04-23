# 반영 필요 사항 정리 — 글로벌 지침 / 스킬 / 인프라 프로젝트

## 작성 정보

| 항목 | 내용 |
|------|------|
| doc_id | OUT-global-architecture-reflection-20260422 |
| 작성자 | jypark |
| 작성일 | 2026-04-22 |
| 유형 | checklist |
| 상태 | 반영 대기 (사용자 승인 필요) |
| 근거 문서 | `hongcafe-global-architecture-final-recommendation.md` |

> **이 문서의 성격**
> 최종 권고 문서에서 도출된 반영 항목을 **3축(글로벌 지침 / 스킬 / 인프라 프로젝트)** 에 배분한 체크리스트다. 본 문서는 **변경 계획만 제시**하며, 실제 파일 수정은 항목별로 사용자 승인 후 진행한다.

---

## 요약 매트릭스

| 축 | 반영 항목 수 | 즉시 반영 | 승인 대기 |
|---|---|---|---|
| 글로벌 지침 (`~/.claude/CLAUDE.md`) | 3 | 0 | 3 |
| 스킬 (`~/.claude/skills/*`) | 7 | 0 | 7 |
| 인프라 프로젝트 (`C:\Works\infra`) | 6 | 0 | 6 |
| **총계** | **16** | **0** | **16** |

---

## 1. 글로벌 지침 반영 (`~/.claude/CLAUDE.md`)

### 1.1 의사결정 근거 문서화 원칙 강화

**근거**: 분석 §2.2 — `PND-007 RESOLVED` 상태만 있고 회의 내용·논의 과정·대안 기각 사유가 부재한 결정이 3개 문서에 "확정"으로 전파됨.

**반영 위치**: §4 Guardrails & Quality 에 신규 항목 추가

**반영 문구 초안**
```markdown
- **의사결정 근거 보존 (Decision Traceability, 필수):** 의사결정 문서(pending_decisions.tsv, ADR, PND-*, INFRASTRUCTURE_GUIDE 결정 섹션)에
  상태값(RESOLVED/OPEN)만 기록하는 것은 지침 위반이다. 필수 필드:
  (1) 결정 근거, (2) 대안 기각 사유, (3) 참석자/담당자, (4) 회의록/녹취 링크 또는 논의 스레드, (5) 재검토 트리거.
  근거 없는 "확정" 상태가 다른 문서로 전파되는 것을 방지한다.
```

### 1.2 "확정" 인용 시 근거 추적 의무

**근거**: 분석 §2.2, §6.2 — "Pattern A 확정(2026-04-06)"이 4자 보고서 전부에 기정사실로 인용됨.

**반영 위치**: §4 Guardrails & Quality

**반영 문구 초안**
```markdown
- **인용 검증 (Citation Verification, 필수):** 다른 문서에서 "확정"·"결정"·"합의" 표현을 인용할 때는
  원 출처의 결정 근거(§1.1 필수 필드)가 실제로 존재하는지 확인한 뒤에만 인용한다.
  상태값만 있고 근거가 없는 결정을 기정사실로 취급하여 분석의 전제로 삼는 것은 지침 위반이다.
```

### 1.3 교차 도메인 아키텍처 결정 조율 프로세스

**근거**: 분석 §2.1, §2.3 — 프론트(BFF 신설)와 백엔드/인프라(Pattern A)가 독립적으로 충돌하는 결정을 진행함.

**반영 위치**: §2 Hierarchy & Authority 또는 §3 Checkpoint 발동 조건

**반영 문구 초안**
```markdown
- **교차 도메인 결정 Checkpoint (필수):** 하나의 아키텍처 결정이 2개 이상 도메인(프론트·백엔드·인프라·보안)에 영향을 주는 경우,
  Checkpoint 를 발동하고 전 도메인 담당자 싱크를 확인한 뒤 진행한다.
  특정 도메인 단독으로 "확정" 처리된 결정이 타 도메인의 기존 설계와 충돌하는 것을 방지한다.
```

---

## 2. 스킬 반영

### 2.1 `task-docs` 스킬 — ADR 템플릿 도입

**근거**: 분석 §2.2 — 기존 `pending_decisions.tsv` 구조가 결정 근거를 강제하지 않음.

**반영 내용**
- ADR(Architecture Decision Record) 템플릿 파일 추가
- 필드: 제목 / 상태 / 날짜 / 참석자 / 배경 / 고려 대안 / 기각 사유 / 결정 / 결과 / 재검토 트리거
- `pending_decisions.tsv` 와 ADR 연결 규칙 (PND-xxx ↔ ADR-xxx)

**경로**: `~/.claude/skills/task-docs/templates/adr.md` (신규)

### 2.2 `orchestration` 스킬 — 다관점 보고서 종합 템플릿

**근거**: 분석 §6, §4 — 4자 보고서 교차 검증 + v1/v2/v3 오류 정정 방식이 재사용 가능한 패턴.

**반영 내용**
- 표준 종합 문서 구조 추가:
  - `v{N} 오류 정정` 섹션 (버전 간 차이 명시)
  - `N자 합의 사항` 매트릭스
  - `쟁점별 팩트 검증` (보고서 주장 → 실코드 대조)
  - `최종 권고` + 대안과의 차이표

**경로**: `~/.claude/skills/orchestration/templates/multi-report-synthesis.md` (신규)

### 2.3 `security-audit` 스킬 — 체크리스트 보강

**근거**: 분석 §3.2, §3.4, §6.1 — 실코드에서 다음 패턴 검증:

**반영 내용 (체크리스트 항목 추가)**
- [ ] **CWE-204 (200 wrapping)**: 4xx/5xx 를 200 으로 래핑하는 핸들러 탐지
- [ ] **CSRF 서명 검증**: `hash_equals()` 사용 여부 (timing attack 방어)
- [ ] **JWT 폴백 차단**: Bearer 헤더 폴백 없는 HttpOnly 쿠키 전용 구조 확인
- [ ] **지리 헤더 신뢰성**: `X-Country-Code`·`X-Forwarded-For` 등이 `set_real_ip_from` 화이트리스트 배경에서만 신뢰되는지 확인
- [ ] **에러 매핑 (CWE-204 파생)**: 백엔드 에러 코드가 사용자 노출용 메시지로 정규화되는지 확인

**경로**: `~/.claude/skills/security-audit/SKILL.md` 체크리스트 섹션

### 2.4 `aws` 스킬 — Nginx GeoIP2 레시피 추가

**근거**: 분석 §7.5 Phase 0, §6.4 Pattern 1 — GeoIP 처리 Nginx 이관 필요.

**반영 내용**
- `ngx_http_geoip2_module` 설치 절차 (Amazon Linux 2023)
- `GeoLite2-Country.mmdb` 파일 경로·갱신 cron (MaxMind account 필요)
- Nginx `map $geoip2_data_country_code $x_country_code` 패턴
- `set_real_ip_from` ALB CIDR 설정
- `proxy_set_header X-Country-Code` 전달

**경로**: `~/.claude/skills/aws/SKILL.md` §신규 "Nginx GeoIP2" 섹션

### 2.5 `php8` 스킬 — CI4 국가 컨텍스트 필터 패턴

**근거**: 분석 §3.4 — `CountryResolverFilter`·`CountryResolver`·`CountryConfigService` 설계만 있고 미구현.

**반영 내용**
- CI4 Filter 우선순위 체인 권장안: `ratelimit → csrftoken → auth → country`
- `Config/Countries/{CODE}.php` 패턴 (통화·타임존·로케일·세율)
- JWT.country > Nginx `X-Country-Code` > Accept-Language 우선순위 로직 표준
- HttpOnly JWT + `hash_equals` CSRF 조합 레시피

**경로**: `~/.claude/skills/php8/SKILL.md` §신규 "국가 컨텍스트 필터" 섹션

### 2.6 `global-context` 스킬 — KR/JP/글로벌 3서비스 아키텍처 차이

**근거**: 분석 §2.3 — 서비스별 아키텍처 차이가 현재 스킬에 명시되지 않아 교차 오판 위험.

**반영 내용**

| 서비스 | 프레임워크 | BFF | 프론트엔드 |
|---|---|---|---|
| KR (hc3) | CI3 모놀리스 | 없음 | jQuery + 서버 렌더링 |
| JP (hongcafe-japan) | CI4 모놀리스 | 없음 | Vanilla JS + PHP 뷰 |
| 글로벌 (hongcafe_global_*) | CI4 + Next.js 16 | 있음 (의도적 신설) | React 19 + Next.js SSR |

- "KR/JP 패턴 따라서"라는 가정을 글로벌에 무비판 적용하지 말 것
- 글로벌 BFF 이관 로드맵(Phase 0-3) 위치 명시

**경로**: `~/.claude/skills/global-context/SKILL.md` §신규 "서비스별 아키텍처 차이"

### 2.7 `debate` 스킬 — 4자 보고서 교차 검증 프로토콜

**근거**: 분석 §1, §6 — 이견 있는 4자 보고서를 실코드 대조로 검증한 방법이 재사용 가능한 프로토콜.

**반영 내용**
- N자 토론 결론 도출 전 필수 단계:
  - (1) 각 주장을 실코드(또는 1차 소스)와 대조
  - (2) "확정"·"합의" 인용의 원 출처 근거 추적
  - (3) 합의 사항 / 쟁점 사항 분리 매트릭스
- 토론 결과물에 `쟁점별 팩트 검증` 섹션 필수화

**경로**: `~/.claude/skills/debate/SKILL.md` §신규 "다관점 종합 프로토콜"

---

## 3. 인프라 프로젝트 반영 (`C:\Works\infra`)

### 3.1 프로젝트 CLAUDE.md 신설

**현 상태**: `C:\Works\infra\CLAUDE.md` 파일 부재 (루트 디렉토리 확인 완료 — `.claude/`, `docs/`, `hongcafe/`, `lambda/` 만 존재).

**반영 내용**
- 글로벌 서비스 아키텍처 결정 상태 섹션:
  - "선택적 Pattern A 채택 여부" TBD 상태 명시
  - Phase 0-3 로드맵 링크 (`docs/output/global-architecture-analysis/hongcafe-global-architecture-final-recommendation.md`)
- KR/JP vs 글로벌 아키텍처 차이 (3자 비교표)
- BFF 유지/이관 라우트 분류 현황 (58개 이관 대상 / 10개 유지)
- 프로젝트 디렉토리 지도 (`hongcafe/`, `lambda/`, `docs/` 역할)

**경로**: `C:\Works\infra\CLAUDE.md` (신설)

### 3.2 메모리 `project_nginx_api_routing.md` 업데이트

**현 상태**: 기존 메모리에 3환경 nginx 라우팅 기록 있음.

**반영 내용**
- `__hongcafe_api__` 용도 명시 (Stripe webhook 등 외부 연동이 BFF 우회)
- FPM 포트 9080/9081/9082 확정 (메모리 `reference_ec2_hongcafe.md` 정정 연동)
- X-Country-Code 미구현 상태 기록
- set_real_ip_from 미설정 상태 기록

**경로**: `~/.claude/projects/C--Works-infra/memory/project_nginx_api_routing.md`

### 3.3 신규 메모리 `project_global_bff_status.md`

**근거**: 분석 §3, §7 — 글로벌 BFF 의 신설 맥락·로드맵·미구현 상태를 세션 간 유지.

**반영 내용**
- BFF 신설 배경 (우현이 의도적 설계, KR/JP에 없던 구조)
- 68개 route 분류 (58 순수 / 2 OAuth / 2 브루트포스 / 1 커스텀 / N legacyMode 미확인)
- Phase 0-3 로드맵 현 단계
- 백엔드 미구현 필터 (`CountryResolverFilter`·`CountryResolver`·`CountryConfigService`)

**경로**: `~/.claude/projects/C--Works-infra/memory/project_global_bff_status.md` (신규)

### 3.4 `docs/decisions/` 디렉토리 신설 (ADR 축적)

**근거**: 분석 §2.2 — PND-xxx 의 근거 부재 문제 재발 방지.

**반영 내용**
- ADR-001: 선택적 Pattern A 채택 (팀 재승인 후)
- ADR-002: Nginx GeoIP2 이관
- ADR-003: 글로벌 라우팅 방식 (nginx geoip+302 vs CF Worker)
- 기존 `pending_decisions.tsv` PND-007 재검토 링크

**경로**: `C:\Works\infra\docs\decisions\` (신설) — 기존 `docs/infra/`·`docs/architecture/`·`docs/plans/` 와 명확히 구분

### 3.5 기존 리포트 2건에 교차 참조 추가

**근거**: 권고 문서 간 상호 탐색성 확보.

**반영 내용**
- `docs/output/global-architecture-analysis/hongcafe-global-architecture-report.md` 상단 "관련 문서" 에 추가:
  - `hongcafe-global-architecture-final-recommendation.md` (4자 종합 + 최종 권고)
- `docs/output/global-architecture-analysis/hongcafe-global-multiregion-routing-report.md` 동일 반영

### 3.6 `docs/infra/INFRASTRUCTURE_GUIDE.md` §3.1 수정

**근거**: 분석 §2.2 — "2026-04-06 회의, 재영+성민 합의" 문구 근거 부재.

**반영 내용 (2가지 옵션)**
- **옵션 A (재승인)**: 팀이 Pattern A 를 재승인한 경우 — 근거·참석자·회의록 링크 보강
- **옵션 B (수정)**: 근거 부재를 명시하고 "선택적 Pattern A" 로 권고 수정 — `hongcafe-global-architecture-final-recommendation.md` 링크 연결

---

## 4. 우선순위 배분

### 4.1 높음 (메모리·프로젝트 지침 — 세션 연속성 직접 영향)

- [ ] **3.2** 메모리 `project_nginx_api_routing.md` 보강
- [ ] **3.3** 신규 메모리 `project_global_bff_status.md`
- [ ] **3.1** 프로젝트 CLAUDE.md 신설

### 4.2 중간 (글로벌 지침 — 향후 세션 전반 영향)

- [ ] **1.1** 의사결정 근거 문서화 원칙
- [ ] **1.2** "확정" 인용 검증
- [ ] **1.3** 교차 도메인 Checkpoint

### 4.3 중간 (스킬 — 재사용 패턴)

- [ ] **2.1** `task-docs` ADR 템플릿
- [ ] **2.3** `security-audit` 체크리스트 보강
- [ ] **2.6** `global-context` 서비스 아키텍처 차이

### 4.4 낮음 (스킬 — 특정 도메인 레시피)

- [ ] **2.2** `orchestration` 다관점 종합 템플릿
- [ ] **2.4** `aws` Nginx GeoIP2 레시피
- [ ] **2.5** `php8` 국가 컨텍스트 필터
- [ ] **2.7** `debate` 교차 검증 프로토콜

### 4.5 낮음 (인프라 프로젝트 — 후속 정리)

- [ ] **3.4** `docs/decisions/` 디렉토리
- [ ] **3.5** 기존 2리포트 교차 참조
- [ ] **3.6** `INFRASTRUCTURE_GUIDE.md` §3.1 재승인/수정

---

## 5. 후속 절차

1. 사용자는 이 체크리스트를 검토하고 반영할 항목을 선택한다.
2. 선택된 항목에 대해:
   - **글로벌 지침 수정**: CLAUDE.md 지침상 지침 파일은 직접 수정 전 사용자 승인 필요.
   - **스킬 수정**: `~/.claude/skills/*` vs `./.claude/skills/*` (글로벌 vs 프로젝트 로컬) 경로 필수 확인 — CLAUDE.md §File Paths 조.
   - **프로젝트 지침·메모리**: 사용자 확인 후 작업.
3. Notion 반영이 필요하면 `notion_cli` 스킬로 별도 요청 시에만 수행 (CLAUDE.md Notion 연동 규칙).

---

## 6. 근거 요약 — 최종 권고 문서와의 매핑

| 반영 항목 | 근거 섹션 |
|---|---|
| 1.1 의사결정 근거 | §2.2 "Pattern A 확정 근거 추적 결과" |
| 1.2 인용 검증 | §2.2 결론 + §6.2 #7 "확정 무효" |
| 1.3 교차 도메인 | §2.1 "소통 부재", §2.3 "BFF 신설" |
| 2.1 ADR | §2.2 PND-007 근거 부재 |
| 2.2 다관점 종합 | §6 전체 쟁점별 팩트 검증 |
| 2.3 보안 체크리스트 | §3.2 200 래핑, §3.4 hash_equals |
| 2.4 GeoIP2 | §7.5 Phase 0, §6.4 Pattern 1 |
| 2.5 CI4 필터 | §3.4 CountryResolverFilter 미구현 |
| 2.6 3서비스 차이 | §2.3 |
| 2.7 교차 검증 | §1 전체 분석 프로토콜 |
| 3.1 프로젝트 지침 | §7.3 라우트별 분류, §7.5 Phase 로드맵 |
| 3.2 nginx 메모리 | §3.1 현 nginx 실설정 |
| 3.3 BFF 메모리 | §3 전체 + §7 권고 |
| 3.4 decisions 디렉토리 | §2.2 |
| 3.5 교차 참조 | §참고 문서 섹션 |
| 3.6 INFRASTRUCTURE_GUIDE | §2.2 |
