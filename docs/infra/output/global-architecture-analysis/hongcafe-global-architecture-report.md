# 글로벌 서비스 아키텍처 분석 — HongCafe Global

## 작성 정보

| 항목 | 내용 |
|------|------|
| doc_id | OUT-global-architecture-analysis-20260422 |
| 작성자 | jypark |
| 작성일 | 2026-04-22 |
| 유형 | report |
| 상태 | 보류 |
| 범위 | 단일 EC2 내부 구조 (L2 API 라우팅, L3 GeoIP 판별 위치) |
| 관련 문서 | `hongcafe-global-multiregion-routing-report.md` (멀티리전 라우팅 시나리오) |

---

## 1. 전제 조건

| 항목 | 값 |
|------|---|
| 운영 규모 | MAU 1000 |
| 인프라 변경 계획 | 없음 |
| 비용 제약 | 저비용 필수 |
| 리전 | us-east-1 단일 (EC2 1대, t4g.small) |
| DB | Aurora 단일 + Hermes 단독 (향후 독립 DB 계획) |

---

## 2. 실측 인프라 (infrastructure.md v3.1, 2026-04-21)

| 항목 | 상태 |
|------|------|
| EC2 | 1대 (i-0183f9ab360cc9d80, prod_ec2_hongcafe_usa) |
| 3환경 | 단일 EC2 포트 분리 (PHP-FPM 8080/8081/8082, Next :3000/3001/3002) |
| 도메인 | prd/stg/dev.gl.hongcafe.com (동일 IP) |
| KOR Lambda | 미구현 |
| JP 인프라 | 없음 |
| API 라우팅 | `/api/*` → Next BFF → `/__php_api/` internal → PHP (loopback 트릭) |
| GeoIP 판별 | Next.js middleware (geoip-lite) |

### 2.1 현재 적용된 보안 통제

| 항목 | 상태 | 출처 |
|------|------|------|
| SSH 포트 | 20010 (기본 22 회피) | §3.1 |
| 접속 방식 | SSM Session Manager | §3.1 |
| SSL/TLS | Let's Encrypt ECDSA, SAN 3환경 | §7 |
| DB 접근 | Aurora RDS Proxy + IAM Auth | §8 |
| 인증 | JWT HttpOnly 쿠키 (PHP 직접 발급) | dev-guide §3.1 |
| 보안 헤더 | X-Content-Type-Options, X-Frame-Options, X-XSS-Protection | §4.6 |
| server_tokens | off (버전 노출 차단) | §4.6 |
| PHP `expose_php` | Off | §5.1 |
| PHP Filter 체인 | Auth / CSRF / RateLimit / Role | app/Config/Filters.php |

---

## 3. MAU 1000 부하 계산

| 지표 | 산식 | 수치 |
|------|------|------|
| DAU | MAU × 0.15 | ~150 |
| API 요청/일 | PV × 5 | ~14,000 |
| 월 API 요청 | × 30 | ~420k |
| 피크 RPS | 14,000 / 36,000초 | < 1 |
| 피크 동시접속 | — | < 30 |

PHP-FPM PRD `pm.max_children = 50` → MAU 5,000까지 증설 없이 소화 가능.

---

## 4. 논의 축

| 레이어 | 논점 | 현재 상태 |
|------|------|---------|
| L1. 트래픽 라우팅 | 멀티리전 여부 | 단일 EC2 — N/A |
| L2. API 라우팅 | Nginx→PHP 직결(A) vs Next 경유(B) | Pattern B |
| L3. GeoIP 판별 위치 | Nginx / Next / PHP | Next (geoip-lite) |

---

## 5. L1 (멀티리전) — 보류

### 5.1 재오픈 트리거

다음 중 2개 이상 충족 시:

- [ ] MAU 10,000 돌파
- [ ] JP/KR 사용자 비율 각각 20% 이상
- [ ] 지연 체감 불만 티켓 발생
- [ ] ap-northeast-1/2 EC2 추가 결재
- [ ] KOR Lambda 착수

### 5.2 도입 시 옵션

| 옵션 | 월 비용 | 보안 이득 | 근거 |
|------|------:|---------|------|
| Route53 Latency routing | ~$1 | DNSSEC 지원 | docs.aws.amazon.com/Route53 DNSSEC |
| Cloudflare Free DNS + Worker | $0 | **DDoS L3/L4/L7 무제한 흡수, Bot Fight Mode, SSL, origin IP 은닉** | cloudflare.com/plans/free |
| CloudFront CDN | ~$0 (1TB/월 무료) | AWS Shield Standard 자동 포함, origin IP 은닉 | aws.amazon.com/shield |

### 5.3 독립 DB cross-region failover 금지

- Route53 health check 자동 페일오버 금지 (타 리전 DB에 사용자 데이터 없음)
- 장애 시 유지보수 페이지(S3 정적) — fail-isolated, not fail-over
- 근거: AWS Well-Architected Reliability Pillar "Failover targets must have access to the same data"

### 5.4 단일 EC2 보안 리스크 (현재)

| 리스크 | 설명 | 완화 |
|-------|------|------|
| SPOF | EC2 탈취 = 전체 서비스 + 3환경 동시 침해 | EC2 MFA, SSM만 접속, 보안 그룹 최소화 |
| DDoS 노출 | origin IP 직접 공개 (54.198.20.157) | CF Free 도입 시 은닉 가능 |
| 3환경 격리 부재 | PRD/STG/DEV가 OS 레벨 공존 | PHP-FPM pool user 분리 여부 점검 필요 |

---

## 6. L2 (Pattern A vs Pattern B)

### 6.1 패턴 정의

| 패턴 | 구조 | 홉 |
|------|------|:-:|
| Pattern A | 브라우저 → Nginx → PHP (Next는 페이지 only) | 2 |
| Pattern B (현재) | 브라우저 → Nginx → Next → PHP | 3 |

### 6.2 축별 비교

| 축 | Pattern A | Pattern B | 근거 |
|------|:-:|:-:|------|
| 홉 수 | 2 | 3 | aws_nginx/conf.d 실설정 |
| Next 장애 시 API 생존 | ✅ | ❌ | 프로세스 격리 |
| FE 배포 시 API 순단 | 없음 | pm2 restart = 순단 | ecosystem.config.js |
| 4GB RAM 적합도 | ★★★★★ | ★★ | 5패턴 비교표 |
| BFF 업계 정당화 | N/A | 0/5 | Sam Newman *Building Microservices* 2nd ed Ch.5 |

### 6.3 보안 축별 비교

| 보안 축 | Pattern A | Pattern B (현재) | 근거 |
|--------|:-:|:-:|------|
| 공격 표면 구성 | Nginx + PHP 2계층 | Nginx + Node + PHP 3계층 | 레이어 수 = CVE 관리 대상 수 |
| API 엔드포인트 노출 | 브라우저에 직접 노출 | Next 뒤로 숨김 (약한 obscurity) | OWASP — obscurity는 방어 아님, Filter 체계가 실제 통제 |
| 인증/CSRF/Rate Limit | PHP Filter 1곳 | Node + PHP 2곳 (중복) | app/Filters/ 실존. Node 측 Filter 누락 시 bypass 위험 |
| IP 스푸핑 방어 | `set_real_ip_from` + `real_ip_recursive` (표준) | `clientIp.js` 자체 CIDR 파서 | Nginx realip module / RFC 7239 |
| 쿠키 관리 | PHP → 브라우저 직결 | `sessionBridge.js`가 중계 | 중계 레이어 = 실수 표면 증가 |
| SSRF 공격 벡터 | 없음 | **Next 서버가 PHP 외 경로 호출 가능하면 벡터 존재** | Pattern B 고유 리스크 |
| WAF 적용 일관성 | Nginx 1곳 | Nginx + Node 두 곳 필요 | 정책 드리프트 위험 |
| Node.js 보안 취약점 | N/A | npm 생태계 CVE 지속 대응 필요 | snyk.io Node 취약점 지수 |
| 보안 필터 실제 강도 | PHP 체인 동등 | PHP 체인 동등 | AuthFilter/CsrfTokenFilter/RateLimitFilter/RoleFilter 동일 적용 |
| **Auth0 BFF 권장 조건** | N/A | OAuth confidential client가 아님 → 권장 불해당 | auth0.com BFF pattern doc |

### 6.4 BFF 정당화 5개 조건 체크

| 조건 | 이 프로젝트 | 충족 |
|----------------|----------|:-:|
| 다중 클라이언트(모바일/웹/TV) | 웹 단일 | ❌ |
| 여러 마이크로서비스 집계 | PHP 단일 백엔드 | ❌ |
| FE/BE 독립 배포 주기 | 소규모 팀, 동일 주기 | ❌ |
| OAuth confidential client (BFF로 토큰 은닉) | JWT HttpOnly 쿠키, PHP 직접 발급 | ❌ |
| GraphQL ↔ REST 변환 | REST 단일 | ❌ |

### 6.5 67개 route handler 구성 (REF 문서 실측)

| 유형 | 건수 | Pattern A 전환 시 |
|------|:-:|----------|
| 순수 프록시 | ~60 | 삭제 |
| 로그인 브루트포스 | 2 | PHP LoginAttemptService로 이동 |

---

## 7. L3 (GeoIP 판별 위치)

| 축 | Nginx GeoIP2 | geoip-lite (현재) | CF-IPCountry | 근거 |
|------|:-:|:-:|:-:|------|
| lookup 지연 | <1ms | ~1ms | 0ms | nginx-module-geoip2 README |
| 장애 폴백 | `default=US` | Node crash = 전체 장애 | CF 장애 시 헤더 누락 | 공식 spec |
| DB 갱신 | geoipupdate cron | npm → 빌드 → 재배포 | CF 자동 | maxmind.com/geoipupdate |
| IP 추출 표준성 | `set_real_ip_from` + `real_ip_recursive` | 자체 CIDR 파서 | CF 보장 | Nginx realip module, RFC 7239 |
| 정확도 (국가) | 99.5%+ | 99.5%+ | 98%+ | MaxMind Accuracy Report 2025 |
| 비용 | $0 | $0 | $0 | 공식 가격 |
| downstream 공급 | PHP/Next/향후 | Next만 | PHP/Next | — |
| AL2023 aarch64 설치 | nginx.org / GetPageSpeed 리포 | 기본 | 외부 벤더 | AL2023 GeoIP 이슈 #350 |
| K8s crashloop 해당 | 없음 (standalone) | — | — | ingress-nginx #11457 |

### 7.1 보안 축별 비교

| 보안 축 | Nginx GeoIP2 | geoip-lite (현재) | 근거 |
|--------|:-:|:-:|------|
| X-Forwarded-For 조작 방어 | `real_ip_recursive on` + CIDR allowlist 표준 | 자체 파서 — edge case/IPv6 fallback 오류 가능 | RFC 7239, Nginx realip 문서 |
| GeoIP 결과 위변조 | Nginx에서 확정, downstream은 읽기만 | Next에서 결정 → PHP에 헤더 전달 → 내부 스푸핑 여지 | defence in depth 원칙 |
| IP 기반 차단/rate limit 일관성 | Nginx 1곳에서 일괄 (`$geoip2_country_code` + `limit_req`) | Node에서 판정 후 PHP가 재판정 — 정책 드리프트 | Nginx limit_req module |
| DB 파일 무결성 | geoipupdate 서명 검증 (MaxMind) | npm 패키지 서명 (npm audit) | maxmind.com/geoipupdate signing |
| CVE 노출 | Nginx + C 모듈 | Node + geoip-lite npm | snyk 취약점 지수 |
| 공격자에 GeoIP 로직 노출 | Nginx 내부 (비공개) | JS 번들에 일부 로직 노출 가능 | client 번들 검사 |

### 7.2 Nginx GeoIP2 도입 시 보안 체크리스트

- [ ] `/etc/nginx/geoip/GeoLite2-Country.mmdb` 권한 0644, 소유 root:nginx
- [ ] `/etc/geoipupdate.conf` 권한 0600 (MaxMind license key 보관)
- [ ] geoipupdate cron은 root 실행, 결과 파일만 nginx reload
- [ ] `auto_reload 60m` 설정 — DB 갱신 중 Nginx 재시작 불필요
- [ ] `set_real_ip_from`에 **신뢰하는 리버스 프록시 CIDR만** 등록 (CF 사용 시 CF IP 범위)
- [ ] `real_ip_recursive on`으로 XFF 체인 끝까지 순회
- [ ] 모듈 버전 불일치 방지 — nginx.org 또는 GetPageSpeed 공식 리포 고정

---

## 8. 보안 종합 관점

### 8.1 Pattern 전환의 보안 관점 득실

| 항목 | Pattern A 전환 시 | 근거 |
|------|---------|------|
| 공격 표면 | Node.js 레이어 제거 → CVE 관리 대상 감소 | snyk Node 취약점 통계 |
| 인증 Filter 누락 위험 | Filter 2곳 중복 → 1곳으로 단일화 | app/Filters/ 로 일원화 |
| SSRF 벡터 | Next의 내부 fetch 사용 감소로 벡터 축소 | Pattern B 고유 리스크 제거 |
| IP 추출 신뢰성 | Nginx realip 표준 적용 | `clientIp.js` 커스텀 파서 제거 |
| WAF/Rate limit 일관성 | Nginx 1곳 적용으로 일원화 | 정책 드리프트 제거 |
| 쿠키 중계 실수 위험 | PHP 직접 발급/검증으로 단순화 | `sessionBridge.js` 제거 |

### 8.2 보안상 중립 또는 우려 항목

| 항목 | 내용 | 완화 |
|------|------|------|
| API 엔드포인트 노출 증가 | 브라우저가 PHP 경로를 직접 봄 | PHP Filter 체인이 실제 통제 — obscurity 의존 금지 (OWASP) |
| Nginx 설정 복잡화 가능 | CORS, Rate limit, WAF 규칙 집중 | 이미 `/__api__/` 패턴 운영 경험 존재 |

### 8.3 저비용 보안 강화 옵션 (어느 선택지든 공통)

| 옵션 | 비용 | 이득 | 비고 |
|------|:-:|------|------|
| Cloudflare Free 전면 도입 | $0 | L3/L4/L7 DDoS 흡수, Bot Fight Mode, origin IP 은닉, SSL | 벤더 추가 |
| fail2ban | $0 | SSH/nginx 로그 기반 자동 차단 | OS 레벨 |
| Nginx `limit_req` 강화 | $0 | L7 DoS 방어 | 설정만 |
| ModSecurity OWASP CRS | $0 | WAF 규칙 | 설정/튜닝 비용 |
| AWS WAF (소규모) | ~$10/월 | 관리형 WAF 규칙 | ALB 필요 |
| AWS Shield Standard | $0 (자동) | L3/L4 DDoS 기본 보호 | AWS 리소스에 자동 적용 |

### 8.4 현재 점검 권고 (패턴 전환과 무관)

| 항목 | 확인 필요 | 근거 |
|------|---------|------|
| 3환경 PHP-FPM pool user 격리 | 현재 모두 `nginx`/`nginx` (§5.2) — PRD/STG/DEV 권한 격리 부재 | 환경별 user 분리 시 PRD 침해 격리 강화 |
| Let's Encrypt renewal hook 권한 | cron root 실행 — 표준 | §7.4 |
| JWT_SECRET, encryption.key 로테이션 정책 | .env 파일 기반 — 로테이션 기록 확인 필요 | §9.2 |
| Nginx `client_max_body_size 20M` | 업로드 크기 = DoS 페이로드 상한 | §4.6 |
| CORS `$http_origin` 동적 반영(PRD) | allowlist 검증 로직 확인 필요 | §4.5 |
| SSH 포트 20010 외부 노출 | Security Group `launch-wizard-1` | SSM 전용이면 폐쇄 가능 |

---

## 9. 스택·패턴 점수 평가 (A-F)

### 9.1 평가 기준

| 축 | 가중치 | 근거 |
|----|:-:|------|
| 비용 | 25% | 사용자 명시 요구 (저비용 필수) |
| 운영/유지보수 | 20% | 소규모 팀, 부채 최소화 |
| 보안 | 20% | 외부 노출 서비스 |
| 신뢰성 (SPOF) | 15% | 단일 EC2 리스크 |
| 성능 | 10% | MAU 1000에서 체감 미미 |
| 확장성 | 10% | 미래 MAU 증가 대응 |

각 축 5점 만점 × 가중치 = 100점 환산.

### 9.2 학점 환산 기준

| 학점 | 점수 | 해석 |
|-----|:-:|------|
| A+ | 97–100 | 현재 맥락 최적 |
| A | 93–96 | 우수, 적극 권장 |
| A- | 90–92 | 우수 |
| B+ | 87–89 | 양호 |
| B | 83–86 | 양호 |
| B- | 80–82 | 양호 |
| C+ | 77–79 | 보통 |
| C | 73–76 | 보통 |
| C- | 70–72 | 보통, 개선 여지 |
| D+ | 67–69 | 미흡 |
| D | 63–66 | 미흡 |
| D- | 60–62 | 미흡, 부채 누적 |
| F | < 60 | 부적합, 교체 권고 |

### 9.3 L1 — 트래픽 라우팅/엣지 스택

| 스택 | 비용 | 운영 | 보안 | 신뢰성 | 성능 | 확장성 | 점수 | **학점** | 근거 |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|------|
| 현재 (DNS 기본 + origin 직결) | ★★★★★ | ★★★★★ | ★★☆☆☆ | ★★★☆☆ | ★★★☆☆ | ★☆☆☆☆ | 70 | **C-** | origin IP 54.198.20.157 직접 노출, DDoS 무방비 |
| Cloudflare Free (DNS+CDN+DDoS) | ★★★★★ | ★★★★☆ | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★★☆ | 92 | **A-** | DDoS L3/L4/L7 무제한, origin 은닉, Bot Fight, SSL |
| CloudFront CDN | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★★★☆ | ★★★★☆ | ★★★★☆ | 84 | **B** | 1TB/월 무료, Shield Standard, AWS 통합 |
| Route53 Latency routing | ★★★★☆ | ★★★☆☆ | ★★★☆☆ | ★★★★☆ | ★★★★★ | ★★★★★ | — | **N/A** | 멀티리전 EC2 전제 불충족 |
| Route53 + GSLB + Shield Adv | ★☆☆☆☆ | ★★☆☆☆ | ★★★★★ | ★★★★★ | ★★★★★ | ★★★★★ | — | **N/A** | $3000+/월, 대규모 전용 |

### 9.4 L2 — API 라우팅 패턴

| 패턴 | 비용 | 운영 | 보안 | 신뢰성 | 성능 | 확장성 | 점수 | **학점** | 근거 |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|------|
| Pattern A (Nginx → PHP 직결) | ★★★★★ | ★★★★★ | ★★★★☆ | ★★★★★ | ★★★★★ | ★★★★☆ | 95 | **A** | 홉 2, Filter 단일 적용, SSRF 벡터 제거, BFF 정당화 N/A |
| Pattern B (현재 BFF) | ★★★★☆ | ★★☆☆☆ | ★★★☆☆ | ★★☆☆☆ | ★★☆☆☆ | ★★★☆☆ | 55 | **F** | 홉 3, 67 route handler, Next 장애 = API 전멸, BFF 정당화 0/5 |
| Pattern B + OAuth BFF 활용 | ★★★★☆ | ★★☆☆☆ | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ | ★★★★☆ | 65 | **D** | confidential client 전제. 현재 JWT HttpOnly 쿠키는 해당 없음 |

### 9.5 L3 — GeoIP 판별 스택

| 스택 | 비용 | 운영 | 보안 | 신뢰성 | 성능 | 확장성 | 점수 | **학점** | 근거 |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|------|
| Nginx GeoIP2 | ★★★★★ | ★★★★☆ | ★★★★★ | ★★★★★ | ★★★★★ | ★★★★★ | 96 | **A** | RFC 7239 realip, default 폴백, auto_reload, 모든 downstream 공급 |
| CF-IPCountry | ★★★★★ | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★★★ | ★★★★★ | 92 | **A-** | L1이 CF Free일 때 자동 제공. CF 장애 시 헤더 누락 fallback 필요 |
| PHP GeoIP2 (php-mod) | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★★★☆ | ★★★★☆ | ★★★☆☆ | 80 | **B-** | Next에 별도 공급 불가 (BFF 유지 시 중복) |
| 클라이언트 (navigator.language) | ★★★★★ | ★★★★★ | ★☆☆☆☆ | ★★☆☆☆ | ★★★★★ | ★★☆☆☆ | 65 | **D** | 사용자 조작 가능, 차단/제재 로직 부적합 |
| geoip-lite (현재) | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ | ★★☆☆☆ | ★★★★☆ | ★★☆☆☆ | 56 | **F** | 자체 CIDR 파서, Node crash=전체장애, npm 빌드 필요 |

### 9.6 조합 총점 (L1 × L2 × L3, 균등 평균)

| 조합 | L1 | L2 | L3 | 평균 | **학점** | 비용(월) | 투입 | 평가 |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|------|
| **현재** (origin 직결 + Pattern B + geoip-lite) | 70 | 55 | 56 | 60 | **D-** | $0 | 0 | 부채 누적 |
| 최소 개선 (CF Free + Pattern B + geoip-lite) | 92 | 55 | 56 | 68 | **D+** | $0 | 1일 | DDoS 방어만 즉시 획득 |
| 중간 (CF Free + Pattern B + CF-IPCountry) | 92 | 55 | 92 | 80 | **B-** | $0 | 1.5일 | geoip-lite 제거 |
| **추천 (목표)** ★ CF Free + Pattern A + Nginx GeoIP2 | 92 | 95 | 96 | 94 | **A** | $0 | 6~7일 | 모든 이득 수렴 |
| 대안 ★ CF Free + Pattern A + CF-IPCountry | 92 | 95 | 92 | 93 | **A** | $0 | 5~6일 | Nginx 모듈 설치 회피, CF 종속 |
| 이상 (멀티리전) Route53 + Pattern A + Nginx GeoIP2 | N/A | 95 | 96 | — | **N/A** | $1+EC2 | 수주 | 현재 전제 불충족 |

### 9.7 학점 요약

| 레이어 | 현재 | 추천 | 학점 변화 |
|------|:-:|:-:|:-:|
| L1 | C- (70) | A- (92) | +22 |
| L2 | F (55) | A (95) | +40 |
| L3 | F (56) | A (96) | +40 |
| **전체 조합** | **D- (60)** | **A (94)** | **+34** |

---

## 10. "Pattern A 확정" 근거 검증

### 10.1 파일시스템 검증

| REF 인용 | 실측 |
|------------|------|
| `docs/infra/INFRASTRUCTURE_GUIDE.md §3.1` | workspace에 없음 (사용자 로컬 별도 보관) |
| `docs/architecture/nextjs_ci4_api_architecture_patterns.md` | 파일 없음 |
| `/works/infra/docs/tasks/20260406/` | 없음 (20260407부터 시작) |
| "Pattern A" 용어 | workspace 전체 0건 |
| 2026-04-06 기록 | `hongcafe_global_backend/docs/output/cross-verification/report_20260406.md` 1건 — AI 작성 교차검증 보고서 |
| dev-guide.md §3.1 Reverse Proxy 그림 | 존재, "확정" 텍스트 없음 |

### 10.2 사용자 확인

- 2026-04-06 회의/합의: 있었던 것 같음 (불확실)
- INFRASTRUCTURE_GUIDE.md: 사용자 로컬 보관
- 당시 승인: 했던 듯

→ 의사결정 근거에서 "확정 사실"은 제외하고 기술·보안 비교만으로 판단.

---

## 11. 선택지

### 11.1 A — 지금 전환

- 투입: 5~6일 (1인)
- 이득: SPOF 제거, FE 배포 순단 제거, 코드 60+ 삭제, geoip-lite 탈출, 보안 표면·CVE 관리 대상 축소
- 학점 이동: **D- → A** (+34)
- 손익분기: FE 배포 월 4회 이상 또는 신규 API 추가 많을 때

### 11.2 B — 조건부 지연

- 트리거: MAU 3,000 OR JP/KR 비율 20%+ OR Next.js 장애 1회 OR Node.js/geoip-lite Critical CVE
- 중간 정책: 신규 API route handler 추가 금지, 신규는 Nginx → PHP 직결
- 즉시 이행: **CF Free 도입만 선행** → 학점 **D- → D+** (+8, 1일 투입)
- 이유: MAU 1000 구간 Pattern A 전환 ROI 낮음 (피크 RPS<1)

### 11.3 C — 영구 보류

- Pattern B를 공식 아키텍처로 재정의
- 정당화 조건: 모바일 앱 등 다중 클라이언트 계획 확정 시 (BFF가 OAuth confidential client로 기능)
- 리스크: BFF 업계 기준 0/5 상태 고정 + Node.js 레이어 CVE 영구 관리

---

## 12. 결론

**2026-04-22 시점 의사결정: 보류**

| 레이어 | 상태 |
|------|------|
| L1 멀티리전 | 인프라 변경 계획 없음 — 논의 대상 아님. 보안 측면은 Cloudflare Free 검토 가치 있음 |
| L2 Pattern A 전환 | 기술·보안 우위 있으나 MAU 1000 ROI 낮음 — 선택지 B 권고, 결정 보류 |
| L3 GeoIP 판별 위치 | L2와 연동, 함께 보류 |

### 재검토 트리거

| 트리거 | 영향 레이어 |
|--------|:-:|
| MAU 3,000 | L2, L3 |
| MAU 10,000 또는 JP/KR 비율 20%+ | L1, L2, L3 |
| Next.js 장애로 API 전체 다운 | L2 |
| FE 배포 시 API 순단 민원 | L2 |
| ap-northeast-1/2 EC2 추가 | L1 |
| Node.js / geoip-lite / npm 의존성 Critical CVE | L2, L3 |
| DDoS 공격 발생 | L1 (CF Free 즉시 도입) |

### 보류와 무관하게 즉시 실행 권고

- §8.4 보안 점검 항목 순차 확인 (3환경 pool user 격리, CORS allowlist, SSH 포트 정책)
- Cloudflare Free 도입 검토 (학점 D- → D+, $0)

---

## 13. Sources

### 업계

- Sam Newman, *Building Microservices* 2nd ed., Ch.5
- WunderGraph, "7 Key Lessons Building BFFs"
- AKF Partners, "BFF Pattern Dos and Don'ts"
- Auth0, "Backend For Frontend Pattern"
- Duende, "BFF Security Framework"
- OWASP Top 10 2021, A05:2021 Security Misconfiguration
- AWS Well-Architected Framework, Reliability + Security Pillar

### 기술

- ngx_http_geoip2_module — github.com/leev/ngx_http_geoip2_module
- Nginx realip module 공식 문서
- MaxMind GeoLite2 Accuracy Report 2025
- MaxMind geoipupdate 서명 검증 가이드
- Amazon Linux 2023 GeoIP 모듈 이슈 #350
- Kubernetes ingress-nginx GeoIP2 이슈 #11457, #8059
- Route53 Latency-based Routing 공식 문서
- Route53 DNSSEC
- Cloudflare Free plan — cloudflare.com/plans/free
- AWS Shield Standard — aws.amazon.com/shield
- snyk.io Node.js 취약점 지수

### 표준

- RFC 7231 §5.3.5 (Accept-Language)
- RFC 7239 (Forwarded HTTP Extension)
- ISO 3166-1 alpha-2

### 내부

- `/works/infra/docs/infrastructure.md` v3.1
- `/works/hongcafe_global_backend/docs/output/project-reference/hongcafe-global-dev-guide.md`
- `/works/hongcafe_global_backend/app/Config/Filters.php` (Filter 체인)
- REF-geoip-architecture-analysis (사용자 제공)
