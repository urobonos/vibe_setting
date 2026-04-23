# Architecture Analysis: Next.js FE ↔ Next.js BE ↔ PHP CI4 API

- **작성일**: 2026-04-23
- **작성 주체**: Claude (Opus 4.7, 1M context)
- **요청자**: 사용자
- **원 질문**: 서버에 아키텍처 패턴을 `Next.js FE ↔ Next.js BE ↔ PHP CI4 API`로 구성하려고 함. 이 구성의 장단점과 다른 패턴 추천, 근거 첨부

---

## 1. 배경 및 문맥

기존 인프라 자산:
- **EC2**: `prod_ec2_hongcafe_usa` (`i-0183f9ab360cc9d80`, us-east-1) 단일 인스턴스에 prd/stg/dev 3환경 공존
- **nginx 라우팅**: 외부 `443 /api/* → Next.js BFF`, `/__hongcafe_api__/api/* → PHP`, 내부 `127.0.0.1:{8080|8081|8082}/api/* → PHP` (loopback server)
- **PHP 런타임**: CI4 4.6+ / FPM 9080/9081/9082
- **현재 상태**: 외관상 이미 BFF(Backend-for-Frontend) 패턴이 부분 적용되어 있음. 즉 제안 구성은 **신규 도입이 아닌 현 구조의 명시적 공식화**에 가깝다.

## 2. 제안 구성 해석

```
┌───────────────────┐   HTTPS   ┌───────────────────┐   HTTP    ┌──────────────────┐
│   Next.js FE      │ ────────► │   Next.js BE      │ ────────► │   PHP CI4 API    │
│  (RSC / CSR)      │           │  (BFF Layer)      │           │  (도메인/DB)     │
│  브라우저 or       │           │  Route Handler    │           │  FPM + MySQL     │
│  Edge/Node SSR    │           │  Server Action    │           │                  │
└───────────────────┘           └───────────────────┘           └──────────────────┘
```

- **Next.js FE 책무**: UI 렌더링, 클라이언트 상호작용, RSC/streaming
- **Next.js BE 책무**: 세션·토큰 교환, 여러 CI4 엔드포인트 집계, 응답 슬리밍, 캐싱(fetch revalidate/ISR), 타입 generation 소비
- **PHP CI4 책무**: 도메인 비즈니스 로직, DB 트랜잭션, 인가(권한 검증), 캐시 원천

**분류**: BFF 패턴 (Sam Newman 정의) + Adapter Layer. 클라이언트 유형(웹 Next.js)에 최적화된 BFF 한 벌.

---

## 3. 장점 (Pros)

| 항목 | 내용 | 수혜 영역 |
|------|------|-----------|
| 관심사 분리 | UI/세션/집계는 Node, 도메인은 PHP | 유지보수 |
| 점진적 현대화 | 기존 CI4 자산 보존한 채 프런트 현대화 | 마이그레이션 |
| BFF의 정통적 이점 | 복수 API 병합, 필드 필터링, 캐싱 오너십 분리 | 성능·UX |
| 보안 경계 | 브라우저가 PHP 엔드포인트·토큰·스키마에 직접 닿지 않음 | 보안 |
| RSC/Streaming | Next.js App Router의 부분 하이드레이션·스트리밍 혜택 | 초기 로딩 |
| 현 인프라와 일치 | 이미 nginx에 BFF/loopback 분리 구현 완료 | 도입 비용 |
| 클라 워터폴 제거 | 여러 CI4 호출을 서버에서 병렬화 | p95 응답 |

## 4. 단점 (Cons)

| 항목 | 내용 | 완화책 |
|------|------|--------|
| 네트워크 홉 증가 | FE→BFF→PHP→DB (+10~50ms p95) | keepalive·HTTP/2, BFF·PHP 동일 호스트 내 loopback |
| 이중 런타임 운영 | Node + PHP-FPM 동시 관리 (배포·패치·모니터링 2배) | systemd unit 표준화, 공용 로그/메트릭 파이프라인 |
| 타입 drift | PHP DTO ↔ TypeScript 타입 수동 동기화 시 불일치 | OpenAPI 3.1 스펙 단일화 + `openapi-typescript` codegen |
| 캐시 중복 | Next.js `fetch` 캐시 + CI4 캐시 충돌 가능 | 데이터 종류별 오너 지정 ("동적=Next/준정적=CI4") |
| 인증 복잡도 | 세션·JWT 두 레이어에서 처리 시 토큰 교환 로직 필수 | BFF에서 httpOnly cookie→short-lived JWT 교환 전용 로직 |
| 메모리 비용 | 2프로세스 상주 | 인스턴스 사이징 재산정 (현 prd 메모리 여유 필요) |
| 디버깅 범위 | trace가 3계층 횡단 | OpenTelemetry trace propagation 도입 |

---

## 5. 대안 패턴

### A. 2-Tier 직접 연결 (Next.js FE ↔ PHP CI4 API)

- **구성**: Next.js Route Handler 최소화, CI4가 직접 API 제공
- **장점**: 홉 감소, 운영 단순, 타입 한 벌
- **단점**: 집계 로직이 클라로 유출 → 워터폴/민감 데이터 노출
- **적합**: API 소스 1~2개, 트래픽 중소, 단일 클라이언트

### B. API Gateway + CI4 마이크로서비스화

- **구성**: Next.js FE → Kong/Traefik/AWS API Gateway → CI4(+ 추가 서비스)
- **장점**: 인증·Rate Limit·로깅을 게이트웨이가 흡수, 언어 독립
- **단점**: Gateway 학습·운영비용, UI-맞춤 집계는 별도 BFF 필요, 로컬 개발 복잡
- **적합**: 다중 서비스·다중 클라이언트(모바일/파트너사) 확장 로드맵

### C. GraphQL Federation / BFF

- **구성**: Next.js FE → GraphQL Yoga/Apollo BFF → CI4(REST) 리졸버
- **장점**: 필드 단위 페칭, 스키마 단일화, over-fetching 제거
- **단점**: GraphQL 학습, 캐싱 모델 변화(persisted queries 필요), 파일 업로드/스트리밍 약점
- **적합**: 도메인 모델 풍부 + 여러 화면이 동일 엔터티 교차 사용

### D. Strangler Fig (점진적 Node 이전)

- **구성**: 신규 기능은 Next.js Route Handler + Prisma/Drizzle로 직접 DB 접근, 기존 기능만 CI4 유지
- **장점**: 신규 개발 속도 극대화, 장기 CI4 의존 제거 경로
- **단점**: 두 코드베이스가 동일 DB 공유 시 트랜잭션 경계·락 이슈, 비즈니스 규칙 중복 리스크
- **적합**: 장기 마이그레이션 로드맵 명확, DB 오너십을 Node로 이전할 계획

---

## 6. 비교 표

| 패턴 | 홉 수 | 운영 복잡도 | 현 자산 활용 | 확장성 | 권장 시점 |
|------|-------|-------------|--------------|--------|-----------|
| 제안 (Next BFF) | 3 | 중 | 최상 (그대로) | 중~상 | 지금 |
| A. 2-Tier | 2 | 하 | 상 | 하 | 스타트업 MVP |
| B. API Gateway | 3~4 | 상 | 중 (재구성) | 상 | 멀티서비스화 |
| C. GraphQL | 3 | 중~상 | 중 (래핑 필요) | 상 | 복잡 도메인 |
| D. Strangler | 2~3 | 상 (과도기) | 감소 추세 | 최상 (목적지) | 장기 이전 결정 |

---

## 7. 권장안

**현 상황 기준 제안 구성(BFF) 유지 + 다음 보강**:

1. **OpenAPI 3.1 단일 진실원**: CI4에서 OpenAPI 스펙 생성 → Next BE에서 `openapi-typescript`로 타입 자동 생성. drift 방지.
2. **BFF는 얇게**: 비즈니스 로직 금지, 집계·인증교환·캐싱·필드필터링만 허용 (규칙으로 명문화).
3. **관측성 3-tier trace**: OpenTelemetry로 FE→BE→PHP trace-id 전파. 홉 증가로 인한 지연 가시화.
4. **캐시 오너 명시**: "동적 = Next fetch revalidate", "준정적 = CI4 캐시". 한 계층이 오너.
5. **장기 전략 병행**: Strangler Fig(대안 D) 로드맵 수립 → 신규 도메인은 Next BE에서 DB 직접 접근으로 수렴할지 판단 게이트 설치.

---

## 8. 타당성 검토 (Feasibility Review)

| 주장 | 근거 출처 | 신뢰도 |
|------|-----------|--------|
| BFF 패턴 정의 및 장단점 | Sam Newman, "Pattern: Backends For Frontends" (samnewman.io/patterns/architectural/bff/, 2015 공표, 현재까지 표준 참조) | 높음 |
| BFF vs API Gateway 구분 | Microsoft Azure Architecture Center, "Backends for Frontends pattern" (learn.microsoft.com/azure/architecture/patterns/backends-for-frontends) | 높음 |
| Strangler Fig 패턴 정의 | Martin Fowler, "StranglerFigApplication" (martinfowler.com/bliki/StranglerFigApplication.html, 2004) | 높음 |
| Next.js Route Handler / 데이터 페칭 모델 | Next.js 공식 docs — App Router Data Fetching (nextjs.org/docs/app/building-your-application/data-fetching) | 높음 |
| GraphQL Federation 구조 | Apollo Federation docs (apollographql.com/docs/federation/) | 높음 |
| OpenAPI 기반 타입 codegen | `openapi-typescript` (github.com/openapi-ts/openapi-typescript) | 중 (OSS 사실 표준) |
| "BFF는 얇게 유지" 원칙 | ThoughtWorks Tech Radar "BFF" 항목 (2017~) + Phil Calçado "The Back-end for Front-end Pattern (BFF)" | 중~높음 |
| 홉 증가로 인한 p95 영향 범위 | 일반적 마이크로서비스 성능 분석 문헌 (Newman, "Building Microservices" 2nd ed., Ch. 13) | 중 (실제 값은 현장 측정 필요) |

**검증 한계**:
- 본 문서의 p95 지연 수치(10~50ms)는 단일 데이터센터·loopback 환경 일반 경험값이며, 실제 측정 권장.
- GraphQL/Gateway 비교는 조직 규모·팀 숙련도에 크게 의존 — 정량 비교는 현장 POC로 보완 필요.
- 오프라인 Docset 인덱스(`docset-ref`)로 Next.js 공식 문서 원문 대조는 후속 작업으로 분리 가능.

---

## 9. 변경되는 사항 / 개선점 / 수행 이유

- **변경되는 사항**
  - 신규 파일 1개: 본 분석 문서. 코드·인프라 실변경 없음 (순수 분석 문서).
- **개선점**
  - 현 nginx 라우팅(`/api/→BFF`, `loopback:/api/→PHP`)에 이미 반영된 BFF 구조의 **공식 근거·장단점·대안·권장안**을 단일 문서로 확보.
  - OpenAPI codegen·OTel trace·캐시 오너·Strangler 로드맵 4개 후속 과제 명시.
- **수행 이유**
  - 사용자가 현 구조를 "신규 도입"으로 인식할 가능성 차단 (이미 부분 구현 상태임을 명시).
  - 향후 팀 내 아키텍처 논의 시 공통 레퍼런스 제공.
  - 대안 비교 표를 통해 경로 전환 결정의 의사결정 기준점 확보.

---

## 10. Before/After 대조

| 구분 | 최초 요청 | 제안에서 변경된 안 |
|------|-----------|--------------------|
| 요청 범위 | 제안 구성 장단점 + 대안 추천 + 근거 | (동일) |
| 분석 깊이 | (명시 없음) | 비교 표·타당성 검토·권장안 보강 추가 |
| 산출물 | 채팅 답변 | 분석 문서화 (본 파일) |
| 후속 작업 | (명시 없음) | 4개 보강 과제(OpenAPI/OTel/캐시/Strangler) 제안 |

롤백 경로: 본 파일 삭제 1회로 완전 원복 가능 (인프라·코드 변경 0).

---

## 11. 잔여 / Next Actions

- [ ] 사용자 승인 후 결정: 제안 구성 유지 vs 대안 A/B/C/D 중 전환
- [ ] 유지 선택 시: OpenAPI 스펙 생성 위치 결정 (CI4 어노테이션 vs 수기 YAML)
- [ ] OTel trace 도입 우선순위 확인
- [ ] 장기 Strangler Fig 로드맵 착수 여부
