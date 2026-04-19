---
name: task-docs
description: >
  작업 문서 생명주기(분석→계획→결과)를 docs/tasks/YYYYMMDD/{작업명}/ 디렉토리에 표준 템플릿으로 생성한다.
  일일 작업 요약을 docs/tasks/YYYYMMDD/summary.md에, 전체 이력을 docs/tasks/history.md에 기록한다.
  {작업명}-analyze.md, {작업명}-plan.md, {작업명}-result.md 3종 문서를 작업별 서브디렉토리에서 관리한다.
  보고용 산출물은 docs/output/{제목}/{파일명}.md에, 소프트웨어 개발 산출물(SDP/SRS/SDD/IDD/STP/STD)은 docs/specs/에 생성·관리한다.
triggers:
  - "/plan"
  - "/research"
  - "플랜 작성", "계획 세워줘"
  - "리서치 해줘", "분석 해줘", "코드 분석", "영향 범위 조사"
  - 3-Team 워크플로우의 Team 1(Analyze), Team 2(Plan), Team 3(Execute) 완료 시 자동 적용
  - "/task-docs specs", "SDP 작성", "SRS 작성", "SDD 작성", "IDD 작성", "STP 작성", "STD 작성"
mandatory: false
version: 3.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Task Docs Skill

작업 문서 3종(analyze, plan, result)과 일일 요약(summary)을 `docs/tasks/YYYYMMDD/` 디렉토리에 표준 템플릿으로 생성·관리한다.
보고용 산출물은 `docs/output/{제목}/{파일명}.md` 형식으로, 소프트웨어 개발 산출물 4종(SDP, SRS, SDD, IDD)은 `docs/specs/` 디렉토리에 생성·관리한다.

## 공통 규칙

1. **날짜별·작업별 누적 보관한다** — 기존 파일을 덮어쓰지 않는다. 새 작업마다 새 서브디렉토리를 생성한다.
2. **보고용 문서 산출물:** 사용자 요청 보고서는 `docs/output/{제목}/{파일명}.md` 형식으로 생성. `docs/tasks/`와 혼용하지 않는다.
3. `{작업명}`은 작업 내용을 간결하게 표현하는 kebab-case 이름으로 한다 (예: `pay-refactor`, `callee-migration`).
4. `YYYYMMDD`는 작업 시작일 기준이다 (예: `20260324`).
5. 사용자에게 보고하는 동시에 파일에도 동일 내용을 기록한다. 채팅으로만 보고하고 파일 생성을 누락하는 것은 지침 위반이다.
6. **팀 간 산출물 체이닝 필수:** Team 2는 반드시 `analyze.md`를 Read한 뒤 기반으로 plan을 작성한다. Team 3는 반드시 `plan.md`를 Read한 뒤 기반으로 실행한다. 이전 팀 산출물 파일이 없으면 해당 팀에 진입할 수 없다.
7. **체크리스트 최대 생성 원칙:** 모든 문서(analyze, plan, result)에 검증 가능한 체크리스트(`- [ ]`)를 최대한 생성한다. 분석 항목, 작업 단계, 검증 조건, 보안 점검, 테스트 케이스 등 체크박스로 표현 가능한 항목은 전부 체크리스트로 작성한다. 서술형 나열보다 체크리스트를 우선한다.
8. **이전 문서 체크리스트 소거 의무:** 이전 팀 산출물을 참조하여 실행하는 팀은, 해당 문서의 체크리스트를 검증 후 체크 표시(`- [x]`)하고 판단 근거를 기록한다. 구체적으로:
   - **Team 2 (Plan):** `analyze.md`의 체크리스트를 읽고, plan 수립 시 반영 여부를 `analyze.md`에 직접 체크한다. (`- [x] 항목 — plan에 반영` 또는 `- [x] 항목 — 해당 없음 (사유)`)
   - **Team 3 (Execute):** `plan.md`의 체크리스트를 읽고, 실행 완료된 항목을 `plan.md`에 직접 체크한다. (`- [x] 항목 — 완료 (커밋 해시)` 또는 `- [x] 항목 — 스킵 (사유)`)
   - **Result 작성 시:** `result.md`의 Self-Critique 체크리스트는 Team 3 완료 후 자체 검증하며 체크한다.
   - 체크되지 않은 항목(`- [ ]`)이 남아있으면 잔여 이슈로 명시한다. 미체크 항목을 무시하고 넘어가는 것은 지침 위반이다.
9. **기존 문서 수정 시 변경 로그 필수:** 이미 존재하는 문서를 수정할 때는 문서 마지막에 변경 로그를 추가한다. 변경 로그가 없으면 새로 생성하고, 있으면 행을 추가한다. 변경 로그 없이 기존 문서를 수정하는 것은 지침 위반이다.
   ```markdown
   ## 변경 로그
   | 날짜 | 내용 |
   |------|------|
   | YYYY-MM-DD | {변경 내용 요약} |
   ```
10. **문서 메타데이터 헤더 필수:** 모든 문서 생성 시 상단에 YAML 프론트매터 형식의 메타데이터를 포함한다. 문서 유형에 따라 필수/선택 필드가 다르며, 메타데이터 없는 문서 생성은 지침 위반이다.
    ```markdown
    ---
    문서명: {문서 제목}
    문서 ID: {파일명 기반 식별자, 예: auth-sdd, commerce-srs}
    버전: v1.0
    상태: 초안 | 검토중 | 승인됨
    생성일: YYYY-MM-DD
    최종 수정일: YYYY-MM-DD
    작성자: jypark
    검토자: {검토자, 해당 시}
    승인자: {승인자, 해당 시}
    대상 시스템: {모듈/BC명, 해당 시}
    관련 문서: {참조 문서 목록, 해당 시}
    ---
    ```
    **문서 유형별 필수 필드:**
    | 필드 | specs (SDP/SRS/SDD/IDD/STP/STD) | tasks (analyze/plan/result) | output (보고서) |
    |------|:-:|:-:|:-:|
    | 문서명 | ● | ● | ● |
    | 문서 ID | ● | — | — |
    | 버전 | ● | — | — |
    | 상태 | ● | ● | ● |
    | 생성일 | ● | ● | ● |
    | 최종 수정일 | ● | ● | ● |
    | 작성자 | ● | ● | ● |
    | 검토자 | ○ | — | ○ |
    | 승인자 | ○ | — | ○ |
    | 대상 시스템 | ● | ● | ○ |
    | 관련 문서 | ● | ○ | ○ |
    > ● 필수, ○ 선택(해당 시), — 불필요
    - **작성자 기본값:** 프로젝트 소유자는 `jypark`(박재영)이다. 별도 지정 없으면 작성자는 `jypark`으로 기입한다.
    - **기존 문서 수정 시:** `최종 수정일`을 갱신하고, specs 문서는 `버전`도 함께 올린다.
    - **상태 전이:** 초안 → 검토중 → 승인됨. 상태 변경 시 변경 로그(규칙 9)에도 기록한다.

## 파일 경로

```
docs/tasks/
├── history.md                    ← 전체 이력 인덱스 (YYYY.MM.DD 항목)
├── YYYYMMDD/
│   ├── summary.md                ← 일일 작업 요약
│   ├── {작업명}/
│   │   ├── {작업명}-analyze.md   ← Team 1 (Analyze) 분석 결과
│   │   ├── {작업명}-plan.md      ← Team 2 (Plan) 실행 계획 + Blueprint
│   │   └── {작업명}-result.md    ← Team 3 (Execute) 완료 결과

docs/output/
├── {제목}/                       ← 보고용 산출물 (kebab-case 주제별 폴더)
│   └── {파일명}.md
├── specs/                        ← 소프트웨어 개발 산출물 (SDP/SRS/SDD/IDD/STP/STD)
│   └── {모듈}-{문서타입}.md
```

---

## 1. Analyze ({작업명}/{작업명}-analyze.md)

Team 1 (Analyze)의 산출물. 코드 분석, 영향 범위 조사, 다각적 관점 분석 결과를 기록한다.

### 규칙
- Team 1 Lead(Analyst)가 멤버 분석 결과를 종합하여 생성한다.
- 분석 완료 후 이슈를 4단계(Critical/High/Medium/Low)로 분류한다.
- 트레이드오프 발견 시 3-Consultants 대안 비교표를 포함한다.

### 템플릿

```markdown
# {주제} 분석 ({날짜: YYYY-MM-DD})

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

---

## 1. Critical 이슈 (즉시 수정 필요)

### 1-1. {이슈 제목}
| 파일 | 줄 | 설명 |
|------|-----|------|
| `파일명` | 줄번호 | 설명 |

---

## 2. High 이슈 (릴리스 전 수정 필요)

### 2-1. {이슈 제목}
| 항목 | 상태 | 파일 |
|------|------|------|
| 항목명 | 상태 | 파일명 |

---

## 3. Medium 이슈 (권장 수정)

### 3-1. {이슈 제목}
| 패턴 | 영향 범위 |
|------|----------|
| 패턴명 | 범위 |

---

## 4. Low 이슈 (선택적 개선)

### 4-1. {이슈 제목}
- {설명}

---

## 5. 트레이드오프 (3-Consultants 소환 시)

| 관점 | Pragmatist | Visionary | Innovator |
|------|------------|-----------|-----------|
| 핵심 주장 | ... | ... | ... |
| 장점 | ... | ... | ... |
| 리스크 | ... | ... | ... |

---

## 6. 타당성 검토 (Feasibility Review)

| # | 권고 사항 | 공식 근거 | 출처 |
|---|----------|----------|------|
| 1 | {권고 내용} | {공식 문서/RFC/IEEE/OWASP 등 근거} | {URL 또는 문서명} |

> 앤트로픽 공식 문서, 프레임워크/라이브러리 공식 문서, 공신력 있는 기술 채널을 근거로 제시한다. 근거 없는 주장·권고는 지침 위반.

---

## 7. 변경 영향 기록 (Change Impact Log)

| # | 변경 사항 | 개선점 | 수행 이유 (Why) |
|---|----------|--------|----------------|
| 1 | {무엇이 변경되는가} | {어떤 개선이 있는가} | {왜 해야 하는가} |

> analyze/preplan 결과를 반영할 때, 변경 사항·개선점·수행 이유를 필수 기록한다. 이유 생략은 지침 위반.

---

## 8. 분석 체크리스트

> **최소 30개 이상**의 체크리스트를 포함해야 한다. 아래는 기본 항목이며, 분석 대상에 따라 항목을 추가·확장한다. hook이 최소 개수를 강제한다.

### 8-1. 범위 정의
- [ ] 분석 대상 파일/모듈 목록 확정
- [ ] 분석 제외 범위 명시
- [ ] 관련 BC(Bounded Context) 식별
- [ ] 영향받는 외부 시스템 식별
- [ ] 상위/하위 의존 모듈 식별
- [ ] 관련 설정 파일 목록화

### 8-2. 코드 품질
- [ ] 미사용 코드/import 존재 여부
- [ ] 중복 코드 패턴 식별
- [ ] DI 원칙 준수 여부
- [ ] 타입 선언(strict_types) 적용 여부
- [ ] 에러 핸들링 일관성
- [ ] 예외 처리 전략 통일성
- [ ] 로깅 패턴 일관성
- [ ] 네이밍 컨벤션 준수 (클래스/메서드/변수)
- [ ] 매직 넘버/하드코딩 상수 존재
- [ ] 순환 복잡도 과다 함수 (Cyclomatic Complexity)
- [ ] 메서드 길이 과다 (50줄+ 경고)
- [ ] 클래스 책임 단일성 (SRP 준수)
- [ ] 불필요/오래된 주석 존재
- [ ] TODO/FIXME/HACK 잔존 여부
- [ ] 반환 타입 선언 누락
- [ ] 파라미터 타입 선언 누락

### 8-3. 보안
- [ ] SQL Injection 취약점
- [ ] XSS 취약점 (Stored/Reflected/DOM)
- [ ] CSRF 방어 적용 여부
- [ ] 인증/인가 누락 엔드포인트
- [ ] 민감 정보 하드코딩 (API 키, 비밀번호, 토큰)
- [ ] 입력값 검증 누락
- [ ] 파일 업로드 검증 (타입/크기/확장자)
- [ ] 세션 관리 안전성 (만료/고정)
- [ ] CORS 설정 적절성
- [ ] Rate Limiting 적용 여부
- [ ] 암호화 알고리즘 적절성 (bcrypt/argon2)
- [ ] 로그 내 민감정보 노출
- [ ] HTTP 보안 헤더 (X-Frame-Options, CSP, HSTS)
- [ ] 디렉토리 트래버설 취약점
- [ ] 권한 상승(Privilege Escalation) 가능성
- [ ] Mass Assignment 취약점
- [ ] Open Redirect 취약점
- [ ] 에러 메시지 정보 노출 (스택 트레이스, DB 정보)

### 8-4. 아키텍처
- [ ] 레이어 간 의존 방향 준수 (Controller→Service→Repository)
- [ ] BC 간 직접 참조 금지 준수
- [ ] 설정/환경 값 외부화 여부
- [ ] SOLID 원칙 준수 (각 원칙별 점검)
- [ ] 순환 의존 존재 여부
- [ ] 공통 모듈 적절성 (과도한 God Class)
- [ ] 이벤트/메시지 계약 일관성
- [ ] 서비스 경계 명확성
- [ ] 에러 전파 경로 명확성
- [ ] 설정 관리 전략 (환경별 분리)
- [ ] 미들웨어/필터 적용 일관성

### 8-5. 성능
- [ ] N+1 쿼리 존재 여부
- [ ] 불필요한 DB 조회 (같은 데이터 중복 조회)
- [ ] 인덱스 활용 여부 (EXPLAIN 확인)
- [ ] 대량 데이터 처리 시 페이징/청킹
- [ ] 캐시 활용 가능 지점 식별
- [ ] 쿼리 실행 계획(EXPLAIN) 이상 여부
- [ ] 메모리 사용량 과다 패턴 (대량 배열 로딩)
- [ ] 외부 API 호출 최적화 (배치/병렬)
- [ ] 파일 I/O 효율성
- [ ] 비동기 처리 가능 지점 식별
- [ ] 느린 쿼리(Slow Query) 후보 식별
- [ ] 불필요한 JOIN/서브쿼리

### 8-6. 데이터
- [ ] 마이그레이션 필요 여부
- [ ] 인덱스 영향 확인
- [ ] 데이터 정합성 제약조건 (FK, UNIQUE, CHECK)
- [ ] 트랜잭션 범위 적절성
- [ ] 데이터 타입 적절성 (VARCHAR 길이, INT 범위)
- [ ] NULL 처리 일관성
- [ ] 외래 키 관계 정확성
- [ ] 소프트 삭제 vs 하드 삭제 전략
- [ ] 데이터 백업/복구 고려
- [ ] 시간대(timezone) 처리 일관성
- [ ] 문자셋/콜레이션 적절성

### 8-7. 테스트
- [ ] 기존 테스트 전체 통과 여부
- [ ] 변경 대상의 테스트 커버리지 존재 여부
- [ ] 엣지 케이스 테스트 존재 여부
- [ ] 모킹 전략 적절성 (과도한 모킹 여부)
- [ ] 테스트 데이터 격리 (테스트 간 간섭)
- [ ] 통합 테스트 존재 여부
- [ ] 회귀 테스트 범위 충분성
- [ ] 테스트 네이밍 명확성
- [ ] 경계값 테스트 존재 여부

### 8-8. 로깅/모니터링
- [ ] 적절한 로그 레벨 사용 (DEBUG/INFO/WARNING/ERROR)
- [ ] 에러 추적 가능성 (correlation ID 등)
- [ ] 메트릭 수집 지점 식별
- [ ] 알림 설정 적절성
- [ ] 감사 로그(Audit Log) 필요 여부
- [ ] 로그 포맷 일관성

### 8-9. 호환성
- [ ] PHP 버전 호환성 (8.4+ 기능 사용)
- [ ] 라이브러리/패키지 버전 충돌
- [ ] API 하위 호환성 (기존 클라이언트 영향)
- [ ] 브라우저 호환성 (프론트엔드 해당 시)
- [ ] 데이터베이스 버전 호환성

### 8-10. 문서/계약
- [ ] API 문서(Swagger/OpenAPI) 최신 상태
- [ ] 인터페이스 계약 변경 여부
- [ ] README/가이드 갱신 필요 여부
- [ ] 환경 변수 문서화 상태

---

## 9. 우선순위 권고

| 순위 | 카테고리 | 작업 | 등급 | 예상 파일 수 |
|------|---------|------|------|-------------|
| **1** | {카테고리} | {작업 설명} | {등급} | {파일 수} |
```

### 등급 기준

| 등급 | 기준 | 예시 |
|------|------|------|
| **Critical** | 즉시 수정 필수. 보안 취약점, 데이터 유실, 시스템 장애 | SQL Injection, 시크릿 노출, 레이어 역전 |
| **High** | 릴리스 전 수정. 기능 결함, 아키텍처 위반 | 보안 필터 미적용, try-catch 미적용 |
| **Medium** | 권장 수정. 코드 품질, 유지보수성, 성능 | DI 미적용, 중복 코드, N+1 쿼리 |
| **Low** | 선택적 개선. 네이밍, 문서화, 코드 스타일 | PHPDoc 누락, 미사용 코드 |

---

## 2. Plan ({작업명}/{작업명}-plan.md)

Team 2 (Plan)의 산출물. analyze.md 기반으로 실행 계획, Blueprint, 작업 분해를 기록한다.

### 규칙
- Team 2 Lead(Analyst)가 멤버 결과를 종합하여 생성한다.
- 사용자 승인 후에만 Team 3(Execute)으로 진입한다. 승인 없는 진행은 지침 위반이다.

### 템플릿

```markdown
# {작업 제목} 실행 계획 ({날짜: YYYY-MM-DD})

## 작업 등급: {S/M/L}

## 작업 목표
{작업의 명확한 목표 기술}

## 수정 대상
| # | 파일/모듈 | 변경 유형 | 설명 |
|---|----------|----------|------|
| 1 | `파일 경로` | 신규/수정/삭제 | {변경 내용} |

## Blueprint
### 디렉토리 구조
{Architect가 설계한 구조}

### 클래스/메서드 시그니처
{인터페이스 계약}

### 스키마 변경 (해당 시)
{Data가 설계한 스키마}

## 작업 분해 (WBS)
| # | 작업 | 의존관계 | 담당 | 예상 규모 |
|---|------|---------|------|-----------|
| 1 | {작업} | - | Worker | {S/M/L} |

## 실행 계획
- **Team 3 구성:** {Worker Lead + 멤버 목록}
- **구현 순서:** {레이어별/기능별 순서}

## 타당성 검토 (Feasibility Review)

| # | 설계/계획 항목 | 공식 근거 | 출처 |
|---|--------------|----------|------|
| 1 | {항목} | {근거} | {출처} |

## 변경 영향 기록 (Change Impact Log)

| # | 변경 사항 | 개선점 | 수행 이유 (Why) |
|---|----------|--------|----------------|
| 1 | {무엇이 변경되는가} | {어떤 개선이 있는가} | {왜 해야 하는가} |

## 실행 전 체크리스트

> **최소 20개 이상**의 체크리스트를 포함해야 한다. 아래는 기본 항목이며, 작업 특성에 따라 항목을 추가·확장한다. hook이 최소 개수를 강제한다.

### 설계 검증
- [ ] 기존 아키텍처 패턴과 일관성 유지
- [ ] BC 경계 침범 없음
- [ ] 신규 의존성 최소화
- [ ] 하위 호환성 확인 (API 변경 시)
- [ ] 설계 패턴 적절성 (Factory, Strategy, Repository 등)
- [ ] 인터페이스 계약 명확성 (입력/출력 타입)
- [ ] 에러 처리 전략 정의 (예외 계층, 에러 코드)
- [ ] 캐시 무효화 전략 (해당 시)
- [ ] 동시성/병렬 처리 고려
- [ ] 확장성 고려 (수평/수직 스케일링)
- [ ] 레이어 간 DTO 변환 전략
- [ ] 공통 코드 재사용 vs 중복 허용 판단

### 보안 검증
- [ ] 인증/인가 변경 시 보안 감사 통과
- [ ] 입력값 검증 포함 (화이트리스트 기반)
- [ ] 민감 정보 처리 방식 확인
- [ ] OWASP Top 10 해당 항목 점검
- [ ] 권한 모델 변경 영향 범위
- [ ] 암호화 적용 범위 (저장/전송)
- [ ] API 인증 토큰 처리 방식
- [ ] 파일 업로드 제한 정책 (해당 시)

### 테스트 계획
- [ ] 단위 테스트 작성 대상 식별
- [ ] 통합 테스트 필요 여부 확인
- [ ] 기존 테스트 영향 범위 확인
- [ ] 성능 테스트 필요 여부 판단
- [ ] 보안 테스트 필요 여부 판단
- [ ] 엣지 케이스 목록 작성
- [ ] 테스트 데이터 준비 계획
- [ ] 테스트 격리 전략 (DB 롤백 등)

### 배포/운영
- [ ] 마이그레이션 필요 시 롤백 계획
- [ ] 환경 변수 추가 시 전 환경 반영 계획
- [ ] 다운타임 여부 확인
- [ ] 배포 순서 정의 (DB → 코드 → 캐시)
- [ ] 모니터링 지표 추가 필요 여부
- [ ] 로그 기준 정의 (레벨, 포맷)
- [ ] 캐시 워밍업 필요 여부
- [ ] 기존 크론잡/배치 영향 확인

### 리스크 관리
- [ ] 실패 시 롤백 절차 정의
- [ ] 부분 배포 영향 범위 분석
- [ ] 데이터 정합성 보장 방안
- [ ] 외부 시스템 장애 시 대응 (Fallback/Circuit Breaker)
- [ ] 트래픽 급증 시 대응 방안

### 의존성 관리
- [ ] 신규 패키지/라이브러리 라이선스 확인
- [ ] 패키지 버전 호환성 확인
- [ ] 외부 서비스 SLA/가용성 확인
- [ ] 내부 모듈 의존 방향 검증

### 프로세스
- [ ] Checkpoint 발동 조건 해당 여부
- [ ] 보안 감사 필요 여부
- [ ] 타당성 검토 공식 근거 제시 완료
- [ ] 변경 영향 기록 (변경사항 + 개선점 + 수행 이유) 작성 완료
- [ ] 이전 analyze.md 체크리스트 소거 완료
- [ ] 작업 분해(WBS) 누락 항목 없음

## Status: Plan Complete — 사용자 승인 대기
```

### 등급별 플랜 구성

| 등급 | Plan 내용 | Team 3 구성 |
|------|----------|------------|
| **S** | 간략 (목표 + 수정 대상) | Lead + Worker 1 + Reviewer |
| **M** | 표준 (목표 + Blueprint + WBS) | Lead + Worker 2 + Reviewer + Tester |
| **L** | 상세 (전체 템플릿) | Lead + Worker 3 + Reviewer + Tester + Security + Performance |

---

## 3. Result ({작업명}/{작업명}-result.md)

Team 3 (Execute) 완료 후 결과를 기록한다.

### 규칙
- Team 3 완료 시 반드시 생성한다. 결과 파일 미생성은 지침 위반이다.
- Self-Critique 체크리스트 4항목을 모두 평가한다.
- 테스트 실행 결과를 포함한다.
- 잔여 이슈는 등급과 미해소 사유를 명시한다.

### 템플릿

```markdown
# {작업 제목} 결과 보고 ({날짜: YYYY-MM-DD})

## 실행 요약
| 항목 | 내용 |
|------|------|
| 작업 등급 | {S/M/L} |
| 실행 모드 | {3-Team / Vibe Coding Group} |
| 플랜 대비 달성도 | {100% / 부분 완료} |
| 총 변경 파일 수 | {N}개 |
| 커밋 수 | {N}개 |

## 변경 내역
| # | 파일 | 변경 유형 | 설명 |
|---|------|----------|------|
| 1 | `파일 경로` | 신규/수정/삭제 | {변경 내용} |

## Self-Critique 체크리스트

> **최소 20개 이상**의 체크리스트를 포함해야 한다. 아래는 기본 항목이며, 작업 특성에 따라 항목을 추가·확장한다. hook이 최소 개수를 강제한다.

### 보안
- [ ] 민감 정보 노출 없음 (로그, 응답, 에러 메시지)
- [ ] 인증/인가 누락 없음
- [ ] 입력값 검증 적용 (화이트리스트 기반)
- [ ] SQL Injection / XSS 방어 확인
- [ ] CSRF 방어 확인
- [ ] 파일 업로드 검증 확인 (해당 시)
- [ ] 권한 검증 완료 (수평/수직 권한 상승)
- [ ] 로그 내 민감정보 없음 (PII, 토큰, 비밀번호)
- [ ] HTTP 보안 헤더 적용 확인

### 로직
- [ ] 엣지 케이스 처리 완료
- [ ] 예외 흐름 정상 동작 (try-catch 범위)
- [ ] 사이드 이펙트 없음
- [ ] 기존 기능 영향 없음 (회귀 검증)
- [ ] NULL/빈값/기본값 처리 확인
- [ ] 경계값 처리 확인 (0, 음수, MAX)
- [ ] 동시성 이슈 없음 (Race Condition)
- [ ] 트랜잭션 범위 적절 (커밋/롤백)
- [ ] 무한 루프/재귀 위험 없음
- [ ] 타입 캐스팅 안전성

### 코드 품질
- [ ] 코딩 컨벤션 준수
- [ ] 불필요한 코드 없음 (디버깅 코드, console.log 등)
- [ ] 적절한 네이밍 (의도 명확)
- [ ] DI / 레이어 규칙 준수
- [ ] TODO/FIXME/HACK 정리
- [ ] 하드코딩 값 없음 (상수/설정으로 분리)
- [ ] 타입 선언 완전성 (파라미터, 반환값)
- [ ] 중복 코드 미발생 (기존 코드 대비)
- [ ] 매직 넘버 제거

### 테스트 커버리지
- [ ] 신규 코드 단위 테스트 작성
- [ ] 변경된 기존 코드 테스트 갱신
- [ ] 엣지 케이스 테스트 포함
- [ ] 전체 테스트 스위트 통과
- [ ] 성능 테스트 통과 (해당 시)
- [ ] 통합 테스트 통과 (해당 시)
- [ ] 테스트 격리 확인 (다른 테스트에 영향 없음)

### 배포 준비
- [ ] 마이그레이션 적용 확인 (해당 시)
- [ ] 마이그레이션 롤백 테스트 (해당 시)
- [ ] 환경 변수 추가 반영 (해당 시)
- [ ] 문서 갱신 — API 변경 시 Swagger/OpenAPI
- [ ] 캐시 무효화 처리 (해당 시)
- [ ] 모니터링/알림 설정 확인
- [ ] 배포 순서 확인 (DB→코드→캐시)

### 이전 문서 체크리스트 소거
- [ ] plan.md 체크리스트 전체 체크(`[x]`) 완료
- [ ] 미체크 항목 잔여 이슈로 명시적 기록
- [ ] analyze.md 이슈 전체 대응 확인

### 잔여 이슈
- [ ] Feedback Loop 미해소 이슈 목록 작성 (등급, 건수, 사유)
- [ ] 후속 작업 필요 시 다음 analyze 항목으로 이관
- [ ] 기술 부채 발생 시 등급 + 해소 계획 기록
- [ ] 알려진 제한사항 문서화

## 테스트 결과
| 구분 | 건수 | 통과 | 실패 |
|------|------|------|------|
| Unit | {건수} | {통과} | {실패} |
| Feature | {건수} | {통과} | {실패} |

## 잔여 이슈
| # | 등급 | 설명 | 사유 |
|---|------|------|------|
| 1 | {Critical/High/Medium/Low} | {이슈 설명} | {미해소 사유} |

## Status: {Done / Partial}
```

---

# Part 4. Context Persistence 연동

컨텍스트 압축이 임박할 때, 작업 문서(analyze.md, plan.md, result.md)가 **진행 상황 복원의 핵심 매체** 역할을 한다.

- **즉시 기록 원칙:** 각 팀 산출물은 팀 완료 즉시 파일에 기록한다. 메인 컨텍스트에만 보관하고 파일 생성을 미루지 않는다.
- **복원 시 활용:** 컨텍스트 압축 후 재개 시, 메모리에 저장된 "현재 단계 + 산출물 경로"를 읽고, 해당 파일을 Read하여 작업을 이어간다.

---

# Part 5. 소프트웨어 개발 산출물 — IEEE 표준 기반 (docs/specs/)

소프트웨어 개발 산출물 6종(SDP, SRS, SDD, IDD, STP, STD)을 `docs/specs/` 디렉토리에 플랫하게 관리한다.
보고용 산출물은 `docs/output/{제목}/{파일명}.md` 형식으로 주제별 폴더에 저장한다.

### 적용 표준

| 산출물 | 적용 표준 | 비고 |
|--------|----------|------|
| SDP | IEEE/ISO/IEC 12207:2017 + PMBOK | 프로젝트 전체 (1회성) |
| SRS | **IEEE/ISO/IEC 29148:2018** | 모듈(BC)별 |
| SDD | **IEEE 1016-2009** (Multi-Viewpoint) | 모듈(BC)별 |
| IDD | **MIL-STD-498 DI-IPSC-81436** | 모듈(BC)별 또는 시스템 간 |
| STP | **IEEE 29119-3:2021** | 프로젝트 전체 (1회성) |
| STD | **IEEE 829-2008** | 모듈(BC)별 |

## 공통 규칙

1. **단일 디렉토리:** 모든 산출물은 `docs/specs/`에 저장한다. 문서 타입별 하위 폴더를 만들지 않는다.
2. **파일 네이밍:** `{모듈 또는 주제}-{문서타입}.md` (kebab-case)
   - 예: `auth-srs.md`, `commerce-idd.md`, `project-sdp.md`, `project-stp.md`, `auth-std.md`
3. **Glob 패턴으로 타입별 조회 가능:** `specs/*-srs.md`, `specs/*-sdd.md` 등
4. **기존 파일 덮어쓰기 허용:** specs 문서는 요구사항·설계 변경 시 갱신한다. (tasks 문서와 다름)
5. **버전 관리:** 문서 상단 `version`과 `lastUpdated` 필드로 변경 이력을 추적한다.
6. **3회 IEEE 적합성 재검토 필수:** 문서 생성/갱신 후 반드시 Part 6의 3-Round Review를 수행한다. 재검토 미수행은 지침 위반이다.

---

## 5-1. SDP — Software Development Plan (IEEE/ISO 12207)

### 파일 경로
```
docs/specs/project-sdp.md
```

### 템플릿

```markdown
# Software Development Plan
> version: 1.0 | lastUpdated: YYYY-MM-DD | standard: IEEE/ISO/IEC 12207:2017

## 1. Introduction
### 1.1 Purpose
### 1.2 Scope (포함/제외 범위)
### 1.3 Definitions, Acronyms, Abbreviations
### 1.4 References (관련 표준/문서)
### 1.5 Overview (문서 구성 설명)

## 2. Project Overview
| 항목 | 내용 |
|------|------|
| 프로젝트명 | {프로젝트명} |
| 목적 | {비즈니스 목적} |
| 범위 | {포함/제외} |

## 3. Technical Stack
| 항목 | 버전 | 비고 |
|------|------|------|

## 4. Architecture
- {Modular Monolith, Dual Mode 등}

## 5. Milestones
| # | 마일스톤 | 목표일 | 산출물 | 상태 |
|---|---------|--------|--------|------|

## 6. Development Methodology
- {3-Team, Conventional Commits, 브랜치 전략}

## 7. Configuration Management
| 항목 | 내용 |
|------|------|
| VCS | Git (Bitbucket) |
| 브랜치 전략 | {전략} |
| CI/CD | {파이프라인} |

## 8. Risk Management
| # | 리스크 | 확률 | 영향도 | 대응 방안 |
|---|--------|------|--------|----------|

## 9. Quality Assurance
- 테스트 전략 (Unit / Feature / Integration)
- 코드 리뷰 프로세스
- 산출물 검토 프로세스 (3-Round IEEE Review)

## 10. 타당성 검토 (Feasibility Review)
| # | 항목 | 근거 | 출처 |
|---|------|------|------|

## 11. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 12. 검토 체크리스트
(IEEE 12207 기반 — 완전성/일관성/실행가능성/추적성 4축)

## 13. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```

---

## 5-2. SRS — Software Requirements Specification (IEEE 29148:2018)

### 파일 경로
```
docs/specs/{모듈}-srs.md
```

### 템플릿

```markdown
# {모듈명} — Software Requirements Specification
> version: 1.0 | lastUpdated: YYYY-MM-DD | module: {BC명} | standard: IEEE/ISO/IEC 29148:2018

## 1. Introduction
### 1.1 Purpose
| 항목 | 내용 |
|------|------|
| 모듈(BC) | {BC명} |
| 목적 | {비즈니스 문제} |
| 이해관계자 | {역할/시스템} |

### 1.2 Scope
### 1.3 Definitions, Acronyms, Abbreviations
| 용어 | 정의 |
|------|------|

### 1.4 References
- `{모듈}-sdd.md`, `{모듈}-idd.md`
- OWASP Top 10, RFC 등

### 1.5 Overview

## 2. Overall Description
### 2.1 Product Perspective (시스템 내 위치, 다른 모듈과의 관계)
### 2.2 Product Functions (주요 기능 요약)
### 2.3 User Characteristics (사용자 유형: Caller, Callee, Admin)
### 2.4 Constraints (기술적/비즈니스 제약)
### 2.5 Assumptions and Dependencies

## 3. Specific Requirements — Functional

### FR-001: {요구사항 제목}
| 항목 | 내용 |
|------|------|
| 설명 | {상세 설명} |
| 선행 조건 | {precondition} |
| 후행 조건 | {postcondition} |
| 입력 검증 | {CI4 Validation Rules: required, max_length 등} |
| 우선순위 | {필수/권장/선택} |
| 관련 API | `{HTTP Method} {URL}` |
| 검증 방법 | {Test/Inspection/Analysis/Demonstration} |

## 4. Specific Requirements — Non-Functional

| ID | 구분 | 요구사항 | 기준 (정량) | 검증 방법 |
|----|------|---------|------------|----------|
| NFR-001 | 성능 | {요구사항} | {예: 200ms 이내} | {Load Test} |
| NFR-002 | 보안 | {요구사항} | {기준} | {Security Audit} |

## 5. External Interface Requirements
### 5.1 User Interfaces (해당 시)
### 5.2 Hardware Interfaces (해당 시)
### 5.3 Software Interfaces (의존 모듈, 외부 시스템)
### 5.4 Communication Interfaces (프로토콜, 포트)

## 6. Use Cases

### UC-001: {유스케이스명}
- **액터:** {사용자/시스템}
- **정상 흐름:**
  1. {단계}
- **대안 흐름:** {예외/분기}
- **에러 흐름:** {실패 시나리오}

## 7. Verification Matrix

| FR/NFR ID | 요구사항 요약 | UC 매핑 | 검증 방법 | 테스트 케이스 | 설계 요소 (SDD) |
|-----------|-------------|---------|----------|-------------|---------------|
| FR-001 | {요약} | UC-001 | Test | {테스트명} | {Controller::method} |
| NFR-001 | {요약} | — | Load Test | {테스트명} | {인프라 설정} |

> **Traceability Matrix**: FR ↔ UC ↔ Test Case ↔ SDD Design Element 4방향 추적 필수.

## 8. Data Dictionary (부록)

| 데이터 항목 | 타입 | 범위/제약 | 설명 |
|-----------|------|----------|------|
| {필드명} | {string/int/...} | {max 500, enum 등} | {설명} |

## 9. 타당성 검토 (Feasibility Review)
| # | 요구사항/결정 | 공식 근거 | 출처 | 결론 |
|---|-------------|----------|------|------|

## 10. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 11. 검토 체크리스트 (IEEE 29148 기반)

### 완전성
- [ ] FR 전체 정의 (각 FR에 선행/후행 조건, 입력 검증, 검증 방법 포함)
- [ ] NFR 전체 정의 (정량 기준 + 검증 방법)
- [ ] External Interface Requirements 작성
- [ ] UC 정상/대안/에러 흐름 작성
- [ ] Verification Matrix 작성 (FR ↔ UC ↔ Test ↔ SDD 4방향)
- [ ] Data Dictionary 작성
- [ ] 제약사항/가정사항 명시
- [ ] 용어 정의 완료

### 일관성
- [ ] FR 간 상충 없음
- [ ] NFR 측정 기준 정량화
- [ ] UC와 FR 매핑 완전
- [ ] Verification Matrix 빈 셀 없음

### 검증 가능성
- [ ] 각 FR에 검증 방법(Test/Inspection/Analysis/Demonstration) 지정
- [ ] 각 NFR에 측정 방법 정의
- [ ] 수락 조건 명확

### 추적성
- [ ] FR ↔ UC 매핑
- [ ] FR ↔ API 엔드포인트 매핑
- [ ] FR ↔ SDD 설계 요소 매핑 (Verification Matrix)
- [ ] NFR ↔ 아키텍처 결정 연결

## 12. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```

---

## 5-3. SDD — Software Design Document (IEEE 1016-2009 Multi-Viewpoint)

### 파일 경로
```
docs/specs/{모듈}-sdd.md
```

### 템플릿

```markdown
# {모듈명} — Software Design Document
> version: 1.0 | lastUpdated: YYYY-MM-DD | module: {BC명} | standard: IEEE 1016-2009

## 1. Introduction
### 1.1 Purpose
| 항목 | 내용 |
|------|------|
| 모듈(BC) | {BC명} |
| 아키텍처 패턴 | {Modular Monolith — Layered} |
| 기반 SRS | `{모듈}-srs.md` v{버전} |

### 1.2 Scope
### 1.3 Definitions
### 1.4 References

## 2. Design Stakeholders & Concerns
| 이해관계자 | 관심사 | 관련 Viewpoint |
|-----------|--------|---------------|
| 개발자 | 클래스 구조, 코드 패턴 | Logical, Composition |
| DBA | 스키마, 인덱스, 성능 | Information |
| 프론트엔드 | API 계약, 응답 포맷 | Interface |
| 운영팀 | 에러 처리, 로깅, 모니터링 | Design Overlay |

## 3. Design Viewpoints

### VP-1. Context Viewpoint (시스템 경계)
- 시스템 경계 다이어그램 (외부 엔티티, 외부 시스템)
- 모듈이 의존하는 외부 시스템 목록

### VP-2. Composition Viewpoint (모듈 분해)
```text
app/Modules/{BC}/
├── Controllers/
├── Services/
├── Repositories/
├── Models/
├── Entities/
└── Config/
```

### VP-3. Logical Viewpoint (클래스/인터페이스)

#### Controller Layer
| 클래스 | 메서드 | HTTP | URL | 설명 |
|--------|--------|------|-----|------|

#### Service Layer
| 클래스 | 메서드 | 입력 | 출력 | 설명 |
|--------|--------|------|------|------|

#### Repository Layer
| 클래스 | 메서드 | 쿼리 유형 | 설명 |
|--------|--------|----------|------|

#### Entity / Value Object
| 클래스 | 타입 | 속성 | 설명 |
|--------|------|------|------|

### VP-4. Dependency Viewpoint (의존 관계)
- 모듈 간 의존 방향도 (Interface Only 원칙)
- DI 등록 (Config/Services.php)
- 순환 의존 없음 확인

### VP-5. Information Viewpoint (데이터 모델)

#### 테이블 정의
| 테이블 | 설명 | 주요 컬럼 |
|--------|------|----------|

#### ERD (텍스트)
```text
[테이블A] 1──N [테이블B]
```

#### SQL DDL
```sql
CREATE TABLE {table} (...) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 인덱스 전략
| 테이블 | 인덱스명 | 컬럼 | 유형 | 사유 |
|--------|---------|------|------|------|

### VP-6. Interface Viewpoint (외부 인터페이스 요약)
- IDD 참조: `{모듈}-idd.md`
- 주요 외부 연동 목록

### VP-7. Interaction Viewpoint (시퀀스/상태 머신)

#### 정상 흐름 시퀀스
```text
Client → Controller → Service → Repository → DB
```

#### 에러 흐름 시퀀스
```text
Client → Controller → 검증 실패 → 400/403/409
```

#### 상태 머신 (해당 시)
```text
[상태A] → [상태B] → [상태C]
```

### VP-8. Patterns Viewpoint (설계 패턴 / ADR)
| # | 결정 | 적용 패턴 | 근거 | 대안 |
|---|------|----------|------|------|

## 4. Design Overlay (Cross-Cutting Concerns)

### 4.1 보안 설계
- 인증/인가 (JWT, role:callee, AuthFilter)
- 입력 검증 (CI4 Validation)
- XSS/SQL Injection 방지

### 4.2 에러 처리 전략
- 에러 코드 체계 (`INVALID_INPUT`, `NOT_FOUND`, `UNAUTHORIZED`, ...)
- 예외 계층 (Controller catch → BaseApiController::respond*)

### 4.3 로깅/모니터링
- 로그 레벨 기준, 로그 포맷
- 감사 로그(audit) 해당 여부

### 4.4 트랜잭션 전략
- 트랜잭션 경계 (Repository 레벨)
- 분산 트랜잭션 해당 여부 (Outbox Pattern)

## 5. Design Rationale (ADR 상세)
| # | 결정 | 근거 | 대안 | 트레이드오프 |
|---|------|------|------|------------|

## 6. Traceability Matrix (SRS → SDD)

| SRS FR | SDD 설계 요소 | Controller::method | Service::method | Repository::method | DB 테이블 |
|--------|-------------|-------------------|-----------------|-------------------|----------|
| FR-001 | {설계요소} | {Controller::m} | {Service::m} | {Repository::m} | {table} |

## 7. 타당성 검토 (Feasibility Review)
| # | 설계 결정 | 공식 근거 | 출처 | 결론 |
|---|----------|----------|------|------|

## 8. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 9. 검토 체크리스트 (IEEE 1016 기반)

### 완전성
- [ ] 8개 Viewpoint 전체 작성
- [ ] Design Overlay (보안/에러/로깅/트랜잭션) 작성
- [ ] Entity/VO 전체 정의
- [ ] SQL DDL 포함
- [ ] 시퀀스 (정상+에러) 작성
- [ ] 상태 머신 (해당 시) 작성
- [ ] Traceability Matrix (SRS FR → SDD) 작성

### 일관성
- [ ] SRS 요구사항과 설계 매핑 완전 (Traceability Matrix 빈 셀 없음)
- [ ] 클래스 시그니처와 실제 구현 일치
- [ ] DB 스키마와 Entity 속성 일치

### 구현 가능성
- [ ] 클래스 간 의존 방향 명확 (VP-4)
- [ ] DB 인덱스 전략 성능 고려
- [ ] 트랜잭션 경계 정의

### 추적성
- [ ] SRS FR ↔ Controller 매핑
- [ ] Entity ↔ DB 테이블 매핑
- [ ] ADR 근거와 대안 기록

## 10. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```

---

## 5-4. IDD — Interface Design Document (MIL-STD-498 DI-IPSC-81436)

### 파일 경로
```
docs/specs/{모듈}-idd.md
```

### 템플릿

```markdown
# {모듈명} — Interface Design Document
> version: 1.0 | lastUpdated: YYYY-MM-DD | module: {BC명} | standard: MIL-STD-498 DI-IPSC-81436

## 1. Scope
### 1.1 Identification
| 항목 | 내용 |
|------|------|
| 모듈(BC) | {BC명} |
| 기반 SDD | `{모듈}-sdd.md` v{버전} |
| 인터페이스 수 | 내부 {N}개 / 외부 {N}개 |

### 1.2 Purpose

## 2. Referenced Documents
- `{모듈}-srs.md`, `{모듈}-sdd.md`

## 3. Interface Design — 내부 인터페이스

### IF-INT-001: {인터페이스명}

#### 3.1.1 Interface Identifier & Diagram
| 항목 | 내용 |
|------|------|
| 제공 모듈 | {BC명} |
| 소비 모듈 | {BC명} |
| 방식 | {직접 호출 / 이벤트 / 공유 서비스} |

#### 3.1.2 Data Elements (메서드 시그니처)
```php
public function method(Type $param): ReturnType;
```

#### 3.1.3 Communication Methods
| 항목 | 내용 |
|------|------|
| 동기/비동기 | {동기} |
| 프로토콜 | {service() DI / HTTP / Queue} |

#### 3.1.4 Error Handling
| 예외 | HTTP | 에러 코드 | 소비자 대응 |
|------|------|----------|------------|

#### 3.1.5 Flow Control / Sequencing
- {호출 순서, 선행 조건}

## 4. Interface Design — 외부 인터페이스

### IF-EXT-001: {인터페이스명}

#### 4.1.1 Interface Identifier & Diagram
| 항목 | 내용 |
|------|------|
| 대상 시스템 | {외부 서비스명} |
| 프로토콜 | {REST/gRPC/WebSocket/DB직접접속} |
| 인증 방식 | {API Key/OAuth/JWT/DB Credentials} |
| Base URL | `{URL}` |
| 타임아웃 | {초} |
| 재시도 정책 | {횟수, 간격, Backoff} |

#### 4.1.2 Data Elements (요청/응답)
| HTTP | URL | 요청 | 응답 | 설명 |
|------|-----|------|------|------|

#### 4.1.3 요청/응답 JSON 예시
```json
// 요청
{ ... }
// 응답
{ ... }
```

#### 4.1.4 Error Handling
| HTTP Status | 에러 코드 | 설명 | 소비자 대응 |
|------------|----------|------|------------|

#### 4.1.5 Communication Methods
| 항목 | 내용 |
|------|------|
| 동기/비동기 | {동기} |
| 연결 관리 | {Connection Pool / 요청별 생성} |
| 장애 대응 | {Circuit Breaker / Graceful Degradation / Retry} |

## 5. Event Contracts

| 이벤트명 | 발행 모듈 | 구독 모듈 | 트리거 | 페이로드 | 설명 |
|---------|----------|----------|--------|---------|------|

## 6. Data Formats

### DTO / Value Object
| DTO | 필드 | 타입 | 필수 | 설명 |
|-----|------|------|------|------|

### 공통 응답 포맷
```json
// 성공
{ "data": {...} }
// 에러
{ "error": { "code": "...", "message": "..." } }
// 페이지네이션
{ "data": [], "meta": { "currentPage", "perPage", "total", "lastPage" } }
```

## 7. Requirements Traceability

| SRS FR | IDD 인터페이스 | SDD 설계 요소 | 비고 |
|--------|-------------|-------------|------|
| FR-001 | IF-INT-001 | Controller::method | |

## 8. 타당성 검토 (Feasibility Review)
| # | 설계 결정 | 공식 근거 | 출처 | 결론 |
|---|----------|----------|------|------|

## 9. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 10. 검토 체크리스트 (MIL-STD-498 기반)

### 완전성
- [ ] 내부 IF 전체 정의 (각 IF에 5개 하위 섹션: Identifier/Data/Communication/Error/Flow)
- [ ] 외부 IF 전체 정의 (각 IF에 5개 하위 섹션 + JSON 예시)
- [ ] 이벤트 계약 전체 정의
- [ ] DTO/VO 전체 정의
- [ ] Requirements Traceability 작성

### 일관성
- [ ] SDD 클래스 ↔ 인터페이스 매핑 일치
- [ ] 요청/응답 포맷 일관성 (camelCase)
- [ ] 에러 코드 체계 통일
- [ ] 인증 방식 일관성

### 계약 명확성
- [ ] 각 IF에 PHP 메서드 시그니처 (타입 포함)
- [ ] 외부 IF에 타임아웃/재시도/장애대응 정의
- [ ] 요청/응답 JSON 예시 포함
- [ ] 하위 호환성 보장 방안

### 추적성
- [ ] SRS FR ↔ IDD IF 매핑
- [ ] SDD Class ↔ IDD IF 매핑
- [ ] 외부 IF ↔ 에러 처리 매핑

## 11. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```

---

## 트리거 조건

| 트리거 | 생성 문서 |
|--------|----------|
| 프로젝트 착수 / 마일스톤 시작 | SDP |
| 모듈(BC) 신규 개발 착수 | SRS → SDD → IDD (순차) |
| 요구사항 변경 | SRS 갱신 → Verification Matrix 동기화 |
| 설계 변경 | SDD 갱신 → Traceability Matrix + IDD 동기화 확인 |
| 외부 연동 추가 | IDD 갱신 (IF-EXT 추가) |
| 사용자 명시 요청 (`/task-docs specs`) | 지정 문서 생성 |

---

## 5-5. STP — Software Test Plan (IEEE 29119-3:2021)

### 파일 경로
```
docs/specs/project-stp.md
```

### 필수 섹션

```markdown
---
문서명: Project — Software Test Plan
문서 ID: project-stp
버전: v{버전}
상태: {초안|승인됨}
생성일: {YYYY-MM-DD}
최종 수정일: {YYYY-MM-DD}
작성자: jypark
대상 시스템: HongCafe Global Backend
관련 문서: project-sdp.md, {모듈}-srs.md, {모듈}-std.md
적용 표준: IEEE 29119-3:2021
---

# Project — Software Test Plan (STP)

> IEEE 29119-3:2021 | version: {버전} | lastUpdated: {YYYY-MM-DD}

## 1. Introduction
### 1.1 Purpose
### 1.2 Scope
### 1.3 Definitions
### 1.4 References
### 1.5 Overview

## 2. Test Strategy
- 테스트 수준: Unit / Feature / Integration
- 접근법 (구조적, 행위적, 경험 기반)
- 설계 기법

## 3. Test Environment
- PHP/PHPUnit/CI4 버전
- phpunit.xml 설정
- Mock/Stub 전략

## 4. Test Schedule & Resources
- SDP 마일스톤 연동

## 5. Test Deliverables
- 모듈별 STD 참조 테이블

## 6. Entry/Exit Criteria
- Entry 조건 (테스트 시작 요건)
- Exit 조건 (테스트 종료 요건)
- Suspension 조건

## 7. Risk Analysis
- 테스트 리스크 식별 및 대응

## 8. Module Coverage Matrix
- 13개 모듈별 테스트 파일 수, 테스트 수, 커버리지 목표

## 9. 타당성 검토 (Feasibility Review)

## 10. 변경 영향 기록

## 11. 변경 로그
```

---

## 5-6. STD — Software Test Documentation (IEEE 829-2008)

### 파일 경로
```
docs/specs/{모듈}-std.md
```

### 필수 섹션

```markdown
---
문서명: {Module} — Software Test Documentation
문서 ID: {module}-std
버전: v{버전}
상태: {초안|승인됨}
생성일: {YYYY-MM-DD}
최종 수정일: {YYYY-MM-DD}
작성자: jypark
대상 시스템: {Module} Module
관련 문서: {module}-srs.md, {module}-sdd.md, {module}-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# {Module} — Software Test Documentation (STD)

> IEEE 829-2008 | version: {버전} | lastUpdated: {YYYY-MM-DD} | module: {Module}

## 1. Introduction
### 1.1 Purpose
### 1.2 Scope
### 1.3 References
- SRS/SDD/IDD 상호참조 필수

## 2. Test Items
- 테스트 대상 클래스/메서드 목록 (Unit/Feature 구분)

## 3. Test Cases
| TC ID | 테스트 메서드 | 설명 | 입력 | 기대결과 | 우선순위 |
|-------|-------------|------|------|---------|---------|
- 실제 테스트 파일의 메서드명을 가공 없이 기재

## 4. Test Execution Results
| 항목 | 값 |
|------|-----|
| 총 TC | {N} |
| PASS | {N} |
| FAIL | {N} |
| SKIP | {N} |
| 최종 실행일 | {YYYY-MM-DD} |

## 5. Traceability Matrix
| SRS 요구사항 ID | 요구사항 요약 | TC ID | 커버리지 |
|----------------|-------------|-------|---------|
- SRS FR/NFR ↔ TC 매핑 필수

## 6. Defects & Issues
| DEF ID | 설명 | 심각도 | 상태 |
|--------|------|--------|------|

## 7. 변경 로그
```

### STD 작성 규칙

1. **테스트 파일 기반:** 실제 `tests/Modules/{Module}/` 하위 파일의 메서드명을 TC로 등록한다. 가상 TC를 만들지 않는다.
2. **SRS 매핑 필수:** Traceability Matrix에서 SRS의 모든 FR/NFR이 최소 1개 TC에 매핑되거나, 미커버 사유를 명시한다.
3. **결과 실측:** PASS/FAIL/SKIP 수치는 PHPUnit 실행 결과 기반이다. 추정값을 쓰지 않는다.

---

# Part 6. 3-Round IEEE 적합성 재검토

소프트웨어 개발 산출물(SDP/SRS/SDD/IDD/STP/STD) 생성 또는 갱신 후, **반드시 3회 재검토를 수행한다**. 재검토를 거치지 않은 산출물은 "초안" 상태로 간주하며, "승인됨" 상태로 전환할 수 없다.

## Round 1: 구조 검증 (Structure Compliance)

IEEE 필수 섹션 존재 여부를 체크리스트로 검증한다.

### SRS (IEEE 29148) 구조 체크
- [ ] §1 Introduction (Purpose, Scope, Definitions, References, Overview)
- [ ] §2 Overall Description (Perspective, Functions, Users, Constraints, Assumptions)
- [ ] §3 Functional Requirements (각 FR에 선행/후행/검증방법 포함)
- [ ] §4 Non-Functional Requirements (정량 기준 + 검증 방법)
- [ ] §5 External Interface Requirements
- [ ] §6 Use Cases (정상/대안/에러 흐름)
- [ ] §7 Verification Matrix (FR ↔ UC ↔ Test ↔ SDD 4방향)
- [ ] §8 Data Dictionary
- [ ] §9 타당성 검토
- [ ] §10 변경 영향 기록

### SDD (IEEE 1016) 구조 체크
- [ ] §1 Introduction (Purpose, Scope, Definitions, References)
- [ ] §2 Design Stakeholders & Concerns
- [ ] §3 VP-1~VP-8 (Context/Composition/Logical/Dependency/Information/Interface/Interaction/Patterns)
- [ ] §4 Design Overlay (보안/에러/로깅/트랜잭션)
- [ ] §5 Design Rationale (ADR)
- [ ] §6 Traceability Matrix (SRS FR → SDD)
- [ ] §7 타당성 검토
- [ ] §8 변경 영향 기록

### IDD (MIL-STD-498) 구조 체크
- [ ] §1 Scope (Identification, Purpose)
- [ ] §2 Referenced Documents
- [ ] §3 내부 IF (각 IF에 5-subsection: Identifier/Data/Communication/Error/Flow)
- [ ] §4 외부 IF (각 IF에 5-subsection + JSON 예시)
- [ ] §5 Event Contracts
- [ ] §6 Data Formats (DTO + 공통 응답 포맷)
- [ ] §7 Requirements Traceability
- [ ] §8 타당성 검토
- [ ] §9 변경 영향 기록

**Round 1 통과 기준:** 모든 필수 섹션이 존재하고, 빈 섹션(placeholder만)이 없을 것.

## Round 2: 내용 검증 (Content Quality)

각 섹션의 내용 깊이와 정확성을 검증한다.

### Verification / Traceability 검증
- [ ] SRS Verification Matrix에 빈 셀 없음 (모든 FR에 UC/Test/SDD 매핑)
- [ ] SDD Traceability Matrix에 빈 셀 없음 (모든 FR에 Controller/Service/Repository/Table 매핑)
- [ ] IDD Requirements Traceability에 빈 셀 없음

### 내용 깊이 검증
- [ ] FR에 입력 검증 규칙(CI4 Validation) 명시
- [ ] NFR에 정량 기준 (ms, TPS, 횟수 등) 명시
- [ ] SDD에 실제 PHP 클래스/메서드명 사용 (추상적 placeholder 아님)
- [ ] SDD에 SQL DDL (CREATE TABLE) 포함
- [ ] SDD에 정상 + 에러 시퀀스 모두 포함
- [ ] IDD에 PHP 메서드 시그니처 (파라미터 타입, 반환 타입) 포함
- [ ] IDD에 요청/응답 JSON 예시 포함
- [ ] 타당성 검토에 공식 문서(OWASP/RFC/IEEE/CI4 docs) 근거 명시
- [ ] 변경 영향 기록에 변경 사항 + 개선점 + 수행 이유 3열 완비

### Design Overlay 검증 (SDD)
- [ ] 보안 설계 (인증/인가/입력검증/XSS/SQLi) 기술
- [ ] 에러 처리 전략 (에러 코드 체계, 예외 계층) 기술
- [ ] 트랜잭션 전략 (경계, 롤백 정책) 기술

**Round 2 통과 기준:** 모든 체크 항목 통과. 1건이라도 미통과 시 해당 섹션 보강 후 Round 2 재수행.

## Round 3: 상호 참조 일관성 (Cross-Reference Consistency)

SRS ↔ SDD ↔ IDD 3개 문서 간 상호 참조가 정합한지 검증한다.

### SRS → SDD 정합성
- [ ] SRS의 모든 FR이 SDD Traceability Matrix에 매핑됨
- [ ] SRS의 API 엔드포인트와 SDD Controller 메서드 1:1 매핑
- [ ] SRS 제약사항이 SDD Design Overlay에 반영됨
- [ ] SRS NFR이 SDD 인덱스 전략/캐시 설계에 반영됨

### SDD → IDD 정합성
- [ ] SDD VP-3의 Service Interface가 IDD 내부 IF에 전체 매핑
- [ ] SDD VP-6의 외부 연동이 IDD 외부 IF에 전체 매핑
- [ ] SDD Entity/VO가 IDD DTO와 필드 일치
- [ ] SDD Design Overlay의 에러 코드가 IDD 에러 처리 계약과 일치

### SRS → IDD 정합성
- [ ] SRS External Interface Requirements가 IDD 외부 IF에 전체 매핑
- [ ] IDD Requirements Traceability의 SRS FR 참조가 정확

### 버전/참조 정합성
- [ ] SDD의 "기반 SRS" 버전이 실제 SRS 버전과 일치
- [ ] IDD의 "기반 SDD" 버전이 실제 SDD 버전과 일치
- [ ] 상호 참조 문서의 "관련 문서" 필드가 양방향으로 기재

**Round 3 통과 기준:** 모든 체크 항목 통과. 불일치 발견 시 원인 문서 수정 후 Round 3 재수행.

## 재검토 결과 기록

3회 재검토 완료 후, 문서의 프론트매터 `상태`를 `초안` → `승인됨`으로 변경하고, 변경 로그에 다음을 기록한다:

```markdown
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| YYYY-MM-DD | x.x.x | 3-Round IEEE Review 통과. Round 1(구조)/Round 2(내용)/Round 3(상호참조) 전체 PASS |
```

**재검토 미수행 또는 미통과 상태에서 "승인됨"으로 상태 전환하는 것은 지침 위반이다.**
