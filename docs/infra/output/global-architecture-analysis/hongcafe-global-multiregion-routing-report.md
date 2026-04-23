# 멀티리전 라우팅 패턴 비교 — HongCafe Global

## 작성 정보

| 항목 | 내용 |
|------|------|
| doc_id | OUT-multiregion-routing-report-20260422 |
| 작성자 | jypark |
| 작성일 | 2026-04-22 |
| 유형 | report |
| 상태 | 시나리오 평가 |
| 관련 문서 | `hongcafe-global-architecture-report.md` (단일 EC2 맥락 분석) |
| 본 문서 주 분석 범위 | **사용자 제시 3패턴 (① nginx geoip / ② 리버스 프록시 / ③ BFF) 중 택1** |
| 추가 대안 범위 | §A (GSLB / Anycast / Edge Worker) — 참고용 |

---

## 1. 전제 조건

| 항목 | 값 |
|------|---|
| 최종 목표 | 글로벌 서비스 (KR/JP/US 3개 리전) |
| 확정 방향 | 각 리전별 독립 서버 구성 + 독립 DB |
| 도메인 구조 | `www.hongcafe.com` (엔트리) + `us/jp/kr.hongcafe.com` (리전별) |
| 핵심 요구 | JP 사용자 → JP 서버, KR 사용자 → KR 서버, US 사용자 → US 서버 |
| 리전 오버라이드 | 첫 접속 IP 기반 + 이후 사용자 선택으로 변경 가능 |
| 현재 인프라 | 단일 EC2 (us-east-1) — 본 문서는 확장 시나리오 |
| 비용 제약 | 저비용 필수 |
| 본 문서 선택 제약 | **원 사용자 제시 3패턴(①②③) 중 택1** |

---

## 2. 사용자 제시 3패턴 정의

| # | 패턴 | 흐름 |
|---|------|------|
| ① | nginx - geoip | JP user → www.hongcafe.com → nginx(geoip2) → 302 → jp.hongcafe.com |
| ② | 리버스 프록시 | JP user → www.hongcafe.com → nginx → Next FE → php whoami → 302 → jp.hongcafe.com |
| ③ | BFF | JP user → www.hongcafe.com → nginx → Next FE → Next BE → php whoami → 302 → jp.hongcafe.com |

모두 공통 후단: `{region}.hongcafe.com` → 각 리전 EC2 → nginx → next → php → 독립 DB

---

## 3. 패턴별 상세 분석

### 3.1 ① nginx geoip + 302

**구조**:
```
[JP user] → www.hongcafe.com
             ↓
           edge-ec2 (t4g.nano)
             nginx + ngx_http_geoip2_module
             map $geoip2_country_code $geo_region { ... }
             map $cookie_hc_region $override { ... }
             return 302 https://$target.hongcafe.com$request_uri
             ↓
           jp.hongcafe.com (Simple A → JP EC2 EIP)
```

**nginx 설정 예시**:
```nginx
map $geoip2_country_code $geo_region {
    default "us";
    "KR"    "kr";
    "JP"    "jp";
    "US"    "us";
}
map $cookie_hc_region $override_region {
    default "";
    "KR"    "kr";
    "JP"    "jp";
    "US"    "us";
}

server {
    listen 443 ssl http2;
    server_name www.hongcafe.com;

    set $target $geo_region;
    if ($override_region != '') { set $target $override_region; }

    add_header Set-Cookie "hc_region=${target}; Domain=.hongcafe.com; Path=/; Max-Age=2592000; Secure; HttpOnly; SameSite=Lax" always;
    return 302 https://$target.hongcafe.com$request_uri;
}
```

**판별 위치**: edge-ec2의 nginx. MaxMind GeoLite2 DB 로컬 lookup.

**장점**:
- 가장 단순한 구조 (edge-ec2 하나만 추가)
- nginx 설정 경험 활용 (infrastructure.md §4)
- AWS 벤더만 사용 (Route53 + EC2)
- Let's Encrypt certbot 재사용
- MaxMind GeoLite2 무료 99.5%+

**단점**:
- edge-ec2 SPOF 추가
- DDoS 무방비 (AWS Shield Standard L3/L4만)
- origin IP 노출
- edge-ec2 장애 시 www 전체 다운
- API 은닉 L1·L2 모두 없음 (nginx rewrite로 L2 보완 가능)

**근거**: ngx_http_geoip2_module README, Nginx map module, RFC 7239, MaxMind GeoLite2 Accuracy Report 2025.

---

### 3.2 ② 리버스 프록시 (Next FE 판별)

**구조**:
```
[JP user] → www.hongcafe.com
             ↓
           edge-ec2
             nginx (단순 프록시)
             ↓
           Next FE (판별 로직)
             ↓ php whoami 호출
           PHP (edge 또는 원격 리전)
             ↓ 국가 응답
           Next FE가 302 응답
             ↓
           jp.hongcafe.com
```

**판별 위치**: edge-ec2의 Next FE. `/api/whoami` 엔드포인트로 php 호출 후 국가 확인.

**장점**:
- Next 레이어에서 오버라이드 로직 자유 구현
- Next middleware API(cookies, geo) 활용
- API 은닉 L2 자연 획득 (Next 뒤로 숨김)

**단점**:
- www 엔트리에 Next + php 스택 전체 세워야 함 (과잉)
- Next 판별 whoami 호출에 RTT 추가
- edge-ec2 스펙 증가 필요 (nano 불가, t4g.small+ 필요) → 비용 상승
- Next SPOF 추가
- 302만 하면 되는 작업에 런타임 2개 사용

**근거**: Next.js Middleware (nextjs.org/docs/app/building-your-application/routing/middleware), Next.js Request Cookies API.

---

### 3.3 ③ BFF (Next BE 판별)

**구조**:
```
[JP user] → www.hongcafe.com
             ↓
           edge-ec2
             nginx → Next FE → Next BE → php whoami
                                        ↓
                                      302 → jp.hongcafe.com
```

**판별 위치**: Next BE. API Route handler에서 판별 수행.

**장점**:
- BFF에서 인증·쿠키·오버라이드 로직 통합 가능
- 세밀한 로직 제어

**단점**:
- 홉 4개 (nginx → Next FE → Next BE → php)
- BFF 정당화 5조건 **0/5** (Sam Newman *Building Microservices* 2nd ed Ch.5)
  - 다중 클라이언트 ❌ (웹 단일)
  - MS 집계 ❌ (PHP 단일)
  - 독립 배포팀 ❌ (소규모)
  - OAuth confidential client ❌ (JWT HttpOnly 쿠키, PHP 직접 발급)
  - GraphQL ↔ REST ❌ (REST 단일)
- edge-ec2 스펙 최대 필요 (t4g.medium+)
- SPOF 3중 (nginx, Next FE, Next BE, php)

**근거**: Sam Newman *Building Microservices* 2nd ed Ch.5, Auth0 BFF pattern doc, WunderGraph "7 Key Lessons", AKF Partners BFF Dos and Don'ts.

---

## 4. 축별 비교 (원 3패턴)

| 축 | ① nginx geoip | ② Reverse Proxy | ③ BFF |
|----|:-:|:-:|:-:|
| 판별 위치 | edge-ec2 nginx | edge-ec2 Next FE | edge-ec2 Next BE |
| 홉 수 (www 엔트리) | 1 (nginx) | 3 (nginx+Next+php) | 4 (nginx+FE+BE+php) |
| edge-ec2 스펙 | t4g.nano (~$3) | t4g.small (~$15) | t4g.medium (~$30) |
| SPOF 수 | 1 (nginx) | 3 | 4 |
| 판별 지연 | <1ms (로컬 mmdb) | ~1ms + whoami RTT | 동 ② |
| 오버라이드 구현 | nginx map (중) | Next middleware (낮음) | 동 ② |
| API 은닉 L1 (IP) | ❌ | ❌ | ❌ |
| API 은닉 L2 (경로) | nginx rewrite로 선택 보완 | △ Next 경유로 부분 | ✅ Next 프록시 자연 |
| DDoS 방어 | AWS Shield Standard (L3/L4만) | 동 ① | 동 ① |
| 운영 복잡도 | 낮음 (nginx 설정만) | 중 (Next 배포 추가) | 높음 (Next 2레이어) |
| BFF 업계 정당화 | N/A | 불명 | **0/5** |
| 근거 | Nginx map / GeoIP2 | Next.js Middleware | Sam Newman 5조건 |

---

## 5. 보안 관점 (원 3패턴)

### 5.1 보안 축별 비교

| 보안 축 | ① | ② | ③ |
|--------|:-:|:-:|:-:|
| origin IP 은닉 | ❌ (edge-ec2·리전 EC2 모두 노출) | ❌ | ❌ |
| DDoS 흡수 | AWS Shield Standard 자동 (L3/L4) | 동 ① | 동 ① |
| WAF 적용 | Nginx + ModSecurity 직접 설정 | Nginx + Next 2곳 | Nginx + Next + BE 3곳 |
| IP 스푸핑 방어 | `set_real_ip_from` + `real_ip_recursive` RFC 7239 표준 | 동 ① | 동 ① |
| 판별 위변조 | nginx 레벨 (신뢰) | Next 레벨 (Node CVE) | 동 ② |
| SSRF 공격 벡터 | 없음 | Next fetch 사용 시 벡터 | 동 ② |
| 인증 Filter 중복 | 없음 (PHP 단일) | Next + PHP 2중 | Next+BE + PHP 3중 |
| Node.js CVE 노출 | N/A | npm 생태계 지속 관리 | 동 ② |

### 5.2 API 엔드포인트 은닉 (Defense in Depth)

OWASP *"Security through obscurity is not security"* 원칙은 **은닉을 유일 방어로 쓰지 말라**는 뜻이지 **무의미하다가 아님**. Defense in depth에서 은닉은 유효한 보조 레이어.

| Level | 내용 | 공격 비용 증가 요인 |
|:-:|------|------|
| L1. Origin IP 은닉 | 백엔드 서버 IP를 공개 DNS에서 숨김 | DDoS·직접 공격 난이도 |
| L2. 실제 엔드포인트 경로 은닉 | 브라우저 경로 ≠ 내부 경로 | 자동화 스캐너·스크래퍼 비효율화 |
| L3. API 스키마 은닉 | OpenAPI/Swagger 비공개 또는 인증 필요 | 엔드포인트 구조 파악 난이도 |
| L4. 엔드포인트 난독화 | signed URL, 랜덤 경로 | 타겟 공격 차단 (MAU 10만+) |

**근거**: OWASP Testing Guide *"Information Gathering"*, NIST SP 800-53 SC-30 (Concealment and Misdirection), PCI-DSS 6.5.

### 5.3 원 3패턴의 은닉 수준

| 패턴 | L1 | L2 | L3 | 보완 방법 |
|------|:-:|:-:|:-:|------|
| ① | ❌ | nginx `rewrite` 규칙으로 선택 획득 | 환경별 Swagger 제어 별개 | nginx rewrite 추가 |
| ② | ❌ | △ Next 경유 부분 획득 | 동 ① | Next middleware 경로 리매핑 |
| ③ | ❌ | ✅ 자연 획득 | 동 ① | Swagger PRD 비활성만 추가 |

**결론**: 은닉 L2는 ③ > ② > ①. 단, ①도 nginx rewrite로 보완 가능 ($0, 설정만).

### 5.4 즉시 점검 항목 (패턴 무관 공통)

- [ ] Swagger UI (`/__api__/`, `/tools/`) PRD에서 비활성 또는 Basic Auth — infrastructure.md §4.5
- [ ] OpenAPI YAML 파일 웹 경로 노출 점검
- [ ] `server_tokens off` (적용 완료 — §2.1)
- [ ] PHP `expose_php = Off` (적용 완료)

---

## 6. 비용 관점 (MAU 1000~10,000 기준)

| 패턴 | edge-ec2 스펙 | edge-ec2 월비용 | Route53 | SSL | 합계 (edge만) |
|------|:-:|------:|------:|:-:|------:|
| ① nginx geoip | t4g.nano (0.5 vCPU, 512MB) | ~$3 | ~$1 | Let's Encrypt | **~$4** |
| ② Reverse Proxy | t4g.small (2 vCPU, 2GB) | ~$15 | ~$1 | Let's Encrypt | **~$16** |
| ③ BFF | t4g.medium (2 vCPU, 4GB) | ~$30 | ~$1 | Let's Encrypt | **~$31** |

※ 각 리전 EC2 비용(~$50/월 × 3리전)은 모든 패턴 공통이므로 제외.

**결론**: ① 비용 최소, ③ 비용 최대 (약 8배 차이). MAU 1000 규모에선 ① 외 선택 정당화 어려움.

---

## 7. 학점 평가 (A–F)

### 7.1 평가 기준 및 가중치

| 축 | 가중치 | 근거 |
|----|:-:|------|
| 비용 | 22% | 저비용 필수 |
| 운영 복잡도 | 13% | 소규모 팀 |
| 보안 | 18% | 외부 노출 서비스 |
| 성능 (판별 지연) | 22% | 사용자 체감 |
| 신뢰성 (SPOF) | 14% | edge-ec2 단일점 |
| 확장성 | 9% | 미래 리전 추가 |
| 사용자 리전 오버라이드 | 2% | §3.7 요구사항 (기본 필수) |

### 7.2 패턴별 학점

| 패턴 | 비용 | 운영 | 보안 | 성능 | 신뢰성 | 확장성 | 오버라이드 | 점수 | **학점** |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **① nginx geoip + 302** | ★★★★ | ★★★★ | ★★★ | ★★★★★ | ★★★ | ★★★★ | ★★★★ | **80** | **B-** |
| ② Reverse Proxy | ★★ | ★★ | ★★★ | ★★★ | ★★ | ★★★ | ★★★★ | 60 | **D-** |
| ③ BFF | ★ | ★ | ★★ | ★★ | ★★ | ★★ | ★★★★ | 48 | **F** |

**판정**:
- **① B-** — 원 3패턴 중 유일하게 합격선
- ② D- — Next 레이어 불필요한 홉
- ③ F — BFF 정당화 0/5, 비용 8배

### 7.3 근거 상세

#### ① nginx geoip + 302 — 80/B-

| 축 | 점수 | 근거 |
|----|:-:|------|
| 비용 | ★★★★ | t4g.nano ~$3 + Route53 ~$1 = ~$4/월 |
| 운영 | ★★★★ | nginx 설정만, infrastructure.md §4 경험 재사용 |
| 보안 | ★★★ | DDoS 무방비, origin IP 노출, L2 은닉은 rewrite로 보완 필요 |
| 성능 | ★★★★★ | lookup <1ms, 홉 1개 |
| 신뢰성 | ★★★ | edge-ec2 SPOF 1개 |
| 확장성 | ★★★★ | 리전 추가 시 map 블록 확장 |
| 오버라이드 | ★★★★ | map + cookie 조합 |

#### ② Reverse Proxy — 60/D-

| 축 | 점수 | 근거 |
|----|:-:|------|
| 비용 | ★★ | t4g.small ~$15 + Route53 ~$1 = ~$16/월 |
| 운영 | ★★ | nginx + Next 2레이어 배포 |
| 보안 | ★★★ | Next CVE 관리 지속 |
| 성능 | ★★★ | whoami RTT 추가 |
| 신뢰성 | ★★ | SPOF 3중 (nginx, Next, php) |
| 확장성 | ★★★ | Next 재배포 필요 |
| 오버라이드 | ★★★★ | Next middleware 자유 |

#### ③ BFF — 48/F

| 축 | 점수 | 근거 |
|----|:-:|------|
| 비용 | ★ | t4g.medium ~$30 + Route53 ~$1 = ~$31/월 |
| 운영 | ★ | nginx + Next FE + Next BE 3레이어 |
| 보안 | ★★ | BFF 정당화 0/5 + Node CVE |
| 성능 | ★★ | 홉 4개 |
| 신뢰성 | ★★ | SPOF 4중 |
| 확장성 | ★★ | BFF 구조 재배포 |
| 오버라이드 | ★★★★ | Next BE 자유 |

---

## 8. 권장 단계적 전환 경로

### 8.1 단계별 구성

| 단계 | 내용 | 조건 | 소요 |
|:-:|------|------|:-:|
| 0 (현재) | 단일 EC2 (us-east-1) | — | — |
| 1 | edge-ec2 (t4g.nano) 생성 + nginx + GeoIP2 모듈 | MAU 1,000 | 0.5일 |
| 2 | `www.hongcafe.com` DNS → edge-ec2, nginx map + 302 설정 | 1 완료 후 | 0.5일 |
| 3 | 프론트에 Region Selector UI + 쿠키 세팅 | 2 완료 후 | 1~2일 |
| 4 | JP 리전 EC2 + 독립 DB 추가, `jp.hongcafe.com` Simple A | MAU 3,000 또는 JP 20%+ | 2~3주 |
| 5 | KR 리전 추가 | KR 20%+ | 1~2주 |
| 6 | nginx rewrite로 API 은닉 L2 보강 (선택) | 보안 감사 시점 | 0.5일 |

### 8.2 단계별 학점 이동

| 단계 | 학점 | 비용/월 |
|:-:|:-:|------:|
| 0 | D- (62) | $0 |
| 1~3 | B- (80) | $4 |
| 4~5 | B- 유지 | $4 + 리전 EC2 |
| 6 | B (83) | 동 + $0 (설정만) |

---

## 9. 재검토 트리거

| 트리거 | 액션 |
|--------|------|
| MAU 3,000 돌파 | 단계 4 (JP 리전 추가) |
| JP/KR 비율 20%+ | 단계 4~5 |
| DDoS 공격 발생 | §A 대안 검토 (CF Free 즉시 도입) |
| edge-ec2 장애 빈발 | §A 대안 검토 (Edge Worker 전환) |
| MAU 100,000+ | §A 대안 검토 (Global Accelerator) |
| 보안 감사 지적 | 단계 6 (rewrite 은닉) |

---

## 10. 결론 (원 3패턴 제약)

### 10.1 원 3패턴 평가 요약

| 패턴 | 학점 | 월 비용 | 판정 |
|------|:-:|:-:|------|
| **① nginx geoip + 302** | **B- (80)** | **~$4** | **권고** |
| ② Reverse Proxy | D- (60) | ~$16 | 기각 (Next 과잉) |
| ③ BFF | F (48) | ~$31 | 기각 (BFF 정당화 0/5) |

### 10.2 권고

**① nginx geoip + 302 채택**.

- edge-ec2 (t4g.nano) + nginx + ngx_http_geoip2_module
- `map $geoip2_country_code` + `map $cookie_hc_region` 조합
- `return 302 https://$target.hongcafe.com$request_uri` + `Set-Cookie hc_region`
- 학점 B- (80)
- 월 비용 ~$4

### 10.3 한계와 보완 필요 사항

| 한계 | 보완 방법 | 추가 비용 |
|------|---------|------:|
| DDoS 무방비 | §A.3 Cloudflare Free 추가 검토 | $0 |
| origin IP 노출 | 동 위 | $0 |
| edge-ec2 SPOF | §A.3 Edge Worker로 대체 시 해소 | $0 |
| API 은닉 L2 부재 | nginx `rewrite` 규칙 추가 (단계 6) | $0 |

**원 3패턴 제약을 해제하면 §A 추가 대안에서 학점 상승 가능**. 특히 ⑥ CF Free + Worker는 $0로 A (94) 달성.

---

# §A. 추가 대안 (원 3패턴 외)

본 섹션은 **사용자 제시 3패턴 외의 업계 표준 대안**을 참고용으로 정리한다. 원 제약을 해제할 경우 학점 상승이 가능한 선택지.

## A.1 ④ GSLB — Route53 Latency-based Routing

**구조**:
```
[JP user] → DNS 질의 → Route53 Latency routing
                       │ 실측 RTT 기반
                       └─ jp.hongcafe.com IP 반환
                ↓
              jp.hongcafe.com (각 리전 EC2)
```

**특징**:
- DNS 레벨에서 자동 리전 판별 — 판별 지연 0
- AWS 관리형, cross-region RTT 0회
- 월 ~$1 (Hosted zone $0.50 + 쿼리 $0.60/M)

**한계**:
- DNS는 쿠키 인식 불가 → **리전 오버라이드 단독 불가**
- 오버라이드는 서브도메인 분리(kr/jp/us) 또는 앱 레이어 302로 보완 필요
- 원 3패턴 대비 DB 갱신·설정 단순

**학점** (오버라이드 축 반영): **B (86)**. 서브도메인 분리로 오버라이드 보완 시.

**근거**: docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-latency.html, aws.amazon.com/route53/pricing.

## A.2 ⑤ Anycast — AWS Global Accelerator

**구조**:
```
[JP user] → 단일 Anycast IP (BGP)
             ↓
           AWS 엣지 POP (JP 근처)
             ↓
           jp-alb → JP EC2
```

**특징**:
- BGP 네트워크 계층 라우팅 — DNS 캐시 영향 없음
- 30초 이내 장애 자동 전환
- Shield Standard 자동, Anycast IP만 공개

**한계**:
- **$18.25/월 고정비** + 데이터 처리비 $0.015/GB
- MAU 100,000 미만에서 과투자
- 오버라이드 역시 서브도메인 또는 앱 레이어 필요

**학점**: **B- (80)**. MAU 100K+ 환경에서 재평가 필요.

**근거**: aws.amazon.com/global-accelerator/pricing, Netflix Tech Blog "Active-Active for Multi-Regional Resiliency".

## A.3 ⑥ Edge Computing — Cloudflare Worker (Free)

**구조**:
```
[JP user] → Cloudflare POP (가장 가까운 POP 자동)
             ↓
           Worker (CF-IPCountry + 쿠키 확인)
             ↓ 302 또는 직접 fetch
           jp.hongcafe.com (CF proxied, JP EC2 origin)
```

**Worker 구현 예시**:
```javascript
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.hostname !== 'www.hongcafe.com') return fetch(request);

    const cookie = request.headers.get('cookie') || '';
    const cookieRegion = cookie.match(/hc_region=([A-Z]{2})/)?.[1];
    const geoRegion = request.cf.country;
    const region = (cookieRegion || geoRegion || 'US').toUpperCase();

    const targetMap = { KR: 'kr', JP: 'jp', US: 'us' };
    const sub = targetMap[region] || 'us';
    const target = `https://${sub}.hongcafe.com${url.pathname}${url.search}`;

    const headers = new Headers({ Location: target });
    if (!cookieRegion) {
      headers.append(
        'Set-Cookie',
        `hc_region=${region}; Domain=.hongcafe.com; Path=/; Max-Age=2592000; Secure; HttpOnly; SameSite=Lax`
      );
    }
    return new Response(null, { status: 302, headers });
  }
};
```

**특징**:
- CF Free 플랜 $0 (Workers 100K req/일 무료)
- DDoS L3/L4/L7 무제한 흡수
- origin IP 자동 은닉 (API 은닉 L1)
- Worker 경로 rewrite로 API 은닉 L2 가능
- Universal SSL 자동
- 쿠키 + GeoIP 일괄 처리 (오버라이드 ★★★★★)
- 멀티리전 확장 시 origin 맵에 리전 추가만

**한계**:
- Cloudflare 벤더 종속
- Free 한도 초과 시 $0.30/M (MAU 1K~10K에선 도달 불가)

**학점**: **A (94)**. 현재 상황·목표 모두 최고점.

**근거**: developers.cloudflare.com/workers, cloudflare.com/plans/free, Cloudflare Workers Runtime API.

## A.4 대안 포함 통합 비교

| 패턴 | 월 비용 | 학점 | 오버라이드 | API 은닉 | DDoS |
|------|:-:|:-:|:-:|:-:|:-:|
| ① nginx geoip (원 3패턴) | ~$4 | B- (80) | map+cookie | nginx rewrite로 보완 | Shield Std만 |
| ② Reverse Proxy (원 3패턴) | ~$16 | D- (60) | Next middleware | △ Next 경유 | 동 ① |
| ③ BFF (원 3패턴) | ~$31 | F (48) | Next BE | ✅ 자연 | 동 ① |
| ④ GSLB (대안) | ~$1 | B (86) | 서브도메인 필요 | ❌ | Shield Std |
| ⑤ Anycast (대안) | ~$18 | B- (80) | 서브도메인 필요 | Anycast IP만 | Shield Std |
| **⑥ CF Worker (대안)** | **$0** | **A (94)** | **Worker 일괄** | **L1+L2 자연** | **L3/L4/L7 무제한** |
| ④+⑥ 조합 (대안) | ~$1 | A (93) | Worker 우선 | 동 ⑥ | 동 ⑥ |

## A.5 언제 대안을 검토할 것인가

| 상황 | 검토 대안 |
|------|------|
| DDoS 공격 발생 | ⑥ CF Free 즉시 도입 |
| edge-ec2 장애 빈발 | ⑥ Edge Worker로 edge-ec2 대체 |
| MAU 100,000+ | ⑤ Anycast + ⑥ Worker 병행 |
| 3리전 안정화 후 | ④ GSLB + ⑥ Worker 병행 |
| AWS 벤더만 유지 + DDoS 필요 | CloudFront + Lambda@Edge + AWS Shield Advanced |

## A.6 원 3패턴 제약 해제 시 권고

**⑥ CF Free + Worker** — $0, A (94), 모든 요구 일괄 충족.

1. Cloudflare Free 가입 + 도메인 이관
2. CF Worker 배포 (쿠키+GeoIP+302+rewrite 일괄)
3. 프론트 Region Selector UI
4. Route53 Simple A × 3 (각 리전 서브도메인, CF proxied ON)

**MAU 3,000 도달 시**: Worker origin 맵에 JP/KR origin 추가 (코드 수정만).

**투입**: 3~4일, **비용**: $0.

---

## 11. Sources

### 11.1 BFF / 아키텍처 업계

- Sam Newman, *Building Microservices* 2nd ed., Ch.5 — BFF 정당화 5조건
- Auth0, "Backend For Frontend Pattern" — auth0.com/blog/backend-for-frontend-pattern
- WunderGraph, "7 Key Lessons Building BFFs" — wundergraph.com/blog/seven_key_lessons_building_bffs
- AKF Partners, "BFF Pattern Dos and Don'ts" — akfpartners.com
- Duende, "BFF Security Framework" — duendesoftware.com/products/bff
- Netflix Tech Blog, "Active-Active for Multi-Regional Resiliency"
- Google SRE Book, Ch.5 "Eliminating Toil"
- AWS Well-Architected Framework — Performance Efficiency · Reliability · Security · Cost Optimization Pillar

### 11.2 AWS

- Route53 Latency-based Routing — docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-latency.html
- Route53 Pricing — aws.amazon.com/route53/pricing
- Route53 DNSSEC
- AWS Global Accelerator — aws.amazon.com/global-accelerator
- AWS Global Accelerator Pricing ($18.25/월 + $0.015/GB) — aws.amazon.com/global-accelerator/pricing
- AWS Shield Standard — aws.amazon.com/shield
- AWS API Gateway pricing — aws.amazon.com/api-gateway/pricing
- AWS Lambda@Edge — docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-at-the-edge.html

### 11.3 Cloudflare

- Cloudflare Free plan — cloudflare.com/plans/free
- Cloudflare Workers Runtime API — developers.cloudflare.com/workers/runtime-apis/request/#incomingrequestcfproperties
- Cloudflare Workers Cookies API — developers.cloudflare.com/workers/examples/cache-using-fetch
- Cloudflare Anycast Network — cloudflare.com/network
- Cloudflare Universal SSL — developers.cloudflare.com/ssl
- Cloudflare DNS Zone Setup — developers.cloudflare.com/dns/zone-setups
- Cloudflare Learning — DDoS — cloudflare.com/learning/ddos
- Cloudflare Bot Fight Mode — cloudflare.com/application-services/products/bot-management
- Cloudflare Access (Zero Trust Free 50 사용자) — developers.cloudflare.com/cloudflare-one/applications

### 11.4 GeoIP / MaxMind / Nginx 모듈

- MaxMind GeoLite2 — maxmind.com/geolite2
- MaxMind GeoLite2 Accuracy Report 2025
- MaxMind geoipupdate — maxmind.com/geoipupdate
- ngx_http_geoip2_module (Apache 2.0) — github.com/leev/ngx_http_geoip2_module
- Nginx realip module — nginx.org/en/docs/http/ngx_http_realip_module.html
- Nginx map module — nginx.org/en/docs/http/ngx_http_map_module.html
- Nginx limit_req module — nginx.org/en/docs/http/ngx_http_limit_req_module.html
- Amazon Linux 2023 GeoIP 모듈 이슈 #350
- Kubernetes ingress-nginx GeoIP2 이슈 #11457, #8059 (K8s 한정)

### 11.5 보안 레퍼런스

- OWASP Top 10 2021 — A05:2021 Security Misconfiguration
- OWASP — "Security through obscurity is not security" (defense in depth 보조 레이어로만 유효)
- OWASP Testing Guide — "Information Gathering"
- OWASP API Security Top 10 — owasp.org/API-Security
- NIST SP 800-53 SC-30 — Concealment and Misdirection
- PCI-DSS 6.5 — Common Coding Vulnerabilities 방지 요건
- snyk.io Node.js 취약점 지수 — snyk.io/vuln/npm
- npm audit — docs.npmjs.com/cli/v10/commands/npm-audit

### 11.6 표준 / RFC

- RFC 1035 — Domain Name System
- RFC 6265 — HTTP State Management Mechanism (Cookies)
- RFC 7231 §5.3.5 — Accept-Language
- RFC 7239 — Forwarded HTTP Extension
- ISO 3166-1 alpha-2 — 국가 코드

### 11.7 Region Override / UX 레퍼런스

- Next.js Middleware — nextjs.org/docs/app/building-your-application/routing/middleware
- Next.js Request Cookies API — nextjs.org/docs/app/api-reference/functions/cookies
- MDN HTTP Cookies — developer.mozilla.org/en-US/docs/Web/HTTP/Cookies
- MDN Set-Cookie header — developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
- Shopify Markets — shopify.dev/docs/storefronts/themes/markets
- Google Search Central "Managing multi-regional and multilingual sites" — developers.google.com/search/docs/specialty/international
- Google `hreflang` 태그 가이드 — developers.google.com/search/docs/specialty/international/localized-versions
- Vercel Edge Middleware (비교 참조) — vercel.com/docs/edge-network/edge-middleware

### 11.8 내부 문서

- `/works/infra/docs/infrastructure.md` v3.1 (2026-04-21)
- `/works/infra/docs/output/global-architecture-analysis/hongcafe-global-architecture-report.md`
- `/works/hongcafe_global_backend/docs/output/project-reference/hongcafe-global-dev-guide.md`
- `/works/hongcafe_global_backend/app/Config/Filters.php`
- `/works/hongcafe_global_backend/docs/output/cross-verification/report_20260406.md`
- REF-geoip-architecture-analysis (사용자 제공)
- global-context SKILL (`~/.claude/skills/global-context/SKILL.md`)
