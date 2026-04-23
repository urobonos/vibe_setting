# 📋 Hostname 마이그레이션 결정 요청표 (2026-04-13)

| 항목 | 내용 |
|---|---|
| 작성자 | 명우현 |
| 작성일 | 2026-04-13 |
| 버전 | v3.0 |
| 상태 | Decision Pending |
| 대상 독자 | 백엔드 / 인프라 / 레거시 홍카페K팀 |
| 양식 | as-is 문서 \| 현재 정책 \| 권고안 \| 결정안 (4-column) |
| 연관 문서 | 🌐 플랫폼 IP 기반 노출 기준 — 갭 시나리오 분석서 (2026-04-09) / 📱 Android 네이티브 수정 요청서 / 📋 회원/인증 API 작업 이슈 결정 요청표 (D-01~D-22) / hostname-migration-plan.md / 🔍 기획검수 48건 vs IP 매트릭스 28케이스 갭 분석 (2026-04-16) |
| 회신 마감 | _________ (배정 필요) |

> **사용법**
> 1. 각 행의 **결정안** 칼럼에 ☐ 권고안 수용 / ☐ 대안 제시 / ☐ 유지 (사유 기재) 중 택1
> 2. 의존 관계가 있는 항목은 상위 결정이 하위 결정을 자동 결정
> 3. 전체 결정 확정 후 hostname-migration-plan.md v2.0으로 반영하여 마이그레이션 착수

---

## 0. 사전 확정 사항 (참고용 — 결정 요청 아님)

다음은 이미 다른 문서에서 의사결정이 완료된 사항입니다. 본 문서에서 재결정 요청하지 않습니다.

| 확정 사항 | 출처 | 비고 |
|---|---|---|
| **hostname 매핑**: `en.hongcafe.com`=EN, `jp.hongcafe.com`=JA, `www.hongcafe.com`=KR(레거시) | 📱 Android 네이티브 수정 요청서 §1 | Android v4.0.0이 이미 사용 중. *단 D-01 참조* |
| **GeoIP는 프론트 처리** (네이티브 미관여) | 📱 Android 네이티브 수정 요청서 §0 | "프론트에서 처리 가능한 부분은 전부 프론트에서 처리" |
| **7-Case 라우팅 모델** (1-A/1-B/1-C/2/3-A/3-B/4) | 🌐 플랫폼 IP 기반 노출 기준 §4-2 | Case 1-A=메인 도메인 GeoIP, 1-B=직접 도메인 우선, 1-C=리전 선택화면 |
| **GAP-1 혼합 전략** — 도메인 직접 접속 시 hostname 우선 / 메인 접속 시 GeoIP | 🌐 GAP §3-2, §4-1 | 본 마이그레이션의 라우팅 전제 |
| **GAP-2 제3국 IP** → 리전 선택화면 | 🌐 GAP §4-1 | Case 1-C 구현 필요 |
| **GAP-3 폴백** → 리전 선택화면 + 200ms timeout + MaxMind GeoLite2 | 🌐 GAP §4-1 | 현재 PHP GeoIP 구현은 수정 필요 |
| **GAP-6 회원 리전 정책** — 로그인 유지 재접속=마지막 선택 / 로그아웃 후=회원 국가 복원 | 🌐 GAP §4-1 | Case 3-A vs 3-B |
| **GAP-7 "언어 변경"** = 리전 전체 전환(콘텐츠/통화 포함) + 쿠키 30일 | 🌐 GAP §4-1 | UI 텍스트만 변경 X |
| **D-14 쿠키 속성** — `__Host-` prefix, HttpOnly, Secure, SameSite=Lax, **Cross-hostname session sharing: DENIED** | 📋 회원/인증 결정요청표 D-14 | jp/en/www 간 재로그인 필요 (SSO 미적용 확정) |
| **D-02/D-03 쿠키 이름** — `hc_access` (15min) / `hc_refresh` (7d) | 📋 회원/인증 결정요청표 D-02, D-03 | 백엔드 결정 진행 중 |
| **api 도메인** — `gl.hongcafe.com` (Production), `stg.gl.hongcafe.com` (Staging), `dev.gl.hongcafe.com` (Dev) | 📋 회원/인증 결정요청표 D-22 | 프론트 노출 도메인과 분리 |
| **FCM Topic 국가 분리** — `all_KR`/`all_JP`/`all_EN` | 📱 Android 네이티브 수정 요청서 N-2 | Web Push와 별도 |
| **next-intl `localePrefix: 'never'` + `domains` 설정 채택** | hostname-migration-plan.md §A1 | next-intl 공식 권고 |
| **Phase 1 backwards-compatible regex 전략** (에이전트 오케스트레이션 0 영향 보장) | hostname-migration-plan.md §A6 | 프론트 자체 결정 |

---

## 1. 결정 매트릭스 (한눈)

| ID | 항목 | 담당 | 우선순위 | 권고안 | 결정안 |
|---|---|---|---|---|---|
| **H-01** | KR 정식 hostname 통일 (`www.hongcafe.com` vs `hongcafe.com`) | 인프라/레거시 | <span style="color:red">P1</span> | `www.hongcafe.com` (Android 기준) | ☐ |
| **H-02** | apex `hongcafe.com` 308 redirect → `www.hongcafe.com` | 인프라/레거시 | <span style="color:red">P1</span> | 활성화 | ☐ |
| **H-03** | DNS A/AAAA 등록 현황 — `en.hongcafe.com`, `jp.hongcafe.com` | 인프라 | <span style="color:red">P1</span> | 현재 등록 여부 + 신규 등록 절차 확인 | ☐ |
| **H-04** | nginx `X-Forwarded-Host` 헤더 전파 | 인프라 | <span style="color:red">P1</span> | 활성화 (next-intl 필수) | ☐ |
| **H-05** | Wildcard `*.hongcafe.com` SSL 발급 방법 | 인프라 | <span style="color:red">P1</span> | LetsEncrypt DNS-01 자동 갱신 | ☐ |
| **H-06** | 통합 프로젝트 nginx vhost 분리 운영 | 인프라 | <span style="color:red">P1</span> | en/jp 별도 vhost + 공통 upstream | ☐ |
| **H-07** | 308 redirect 룰 (`/en/...`, `/ja/...` → 신 hostname) 활성화 시점 | 인프라 | <span style="color:orange">P2</span> | dual-mode 종료 시점 | ☐ |
| **H-08** | CDN/Reverse proxy의 vhost별 캐싱 분리 | 인프라 | <span style="color:orange">P2</span> | subdomain별 별도 캐시 키 | ☐ |
| **B-01** | 백엔드 회원 DB `ac_country` 필드 보장 | 백엔드 | <span style="color:red">P1</span> | 모든 신규 가입 시 NOT NULL + 변경 시 audit log | ☐ |
| **B-02** | 백엔드 발송 이메일/푸시 링크의 hostname 정책 | 백엔드 | <span style="color:red">P1</span> | 사용자 `ac_country` 기준 분기 | ☐ |
| **B-03** | 소셜 OAuth callback URL — 신규 hostname 등록 | 백엔드 | <span style="color:red">P1</span> | en/jp 양쪽 redirect URI 사전 등록 | ☐ |
| **B-04** | Web Push (FCM Web SDK) 사용 여부 + VAPID 키 정책 | 백엔드 | <span style="color:orange">P2</span> | 미사용 (또는 subdomain별 분리 VAPID) | ☐ |
| **B-05** | D-14 쿠키 정책 확정 시점 (cross-reference) | 백엔드 | <span style="color:red">P1</span> | 회원/인증 결정요청표 D-14 우선 확정 | ☐ |
| **L-01** | 레거시 홍카페K 쿠키 이름 충돌 검토 | 레거시 홍카페K팀 | <span style="color:red">P1</span> | 레거시 cookie name 목록 공유 + 충돌 검증 | ☐ |
| **L-02** | 신규 subdomain 신설에 대한 레거시팀 동의 | 레거시 홍카페K팀 | <span style="color:red">P1</span> | 명시적 합의 | ☐ |
| **O-01** | Cutover freeze window 일정 | Product/Ops | <span style="color:red">P1</span> | 트래픽 최저 시간대 (배정 필요) | ☐ |
| **O-02** | 배포 전략 (Big-bang / Dual-mode / Canary) | Product/Ops | <span style="color:orange">P2</span> | Dual-mode 1~2주 | ☐ |
| **S-01** | Google Search Console 신규 property 등록 권한 | 마케팅/SEO | <span style="color:orange">P2</span> | 권한 보유자 확인 + 등록 일정 | ☐ |
| **S-02** | hreflang/sitemap.xml/robots.txt subdomain별 분리 작업 담당 | 마케팅/SEO/FE | <span style="color:yellow">P3</span> | FE 구현 + 마케팅 검증 | ☐ |
| **R-01** | 제3국 IP 폴백 전략 (GeoIP 실패/미매핑 국가) | Product/FE | <span style="color:red">P1</span> | 리전 선택화면(`/region-select`) | ☐ |
| **R-02** | VPN/Tor 의심 IP 처리 정책 | Product | <span style="color:red">P1</span> | 선택화면 노출 (기획검수 REG-010) vs 정상 취급 (매트릭스) | ☐ |
| **R-03** | URL 리전 vs 회원 국가 불일치 시 세션 유지 옵션 | Product | <span style="color:red">P1</span> | 세션 쿠키 방식 확정 필요 (REG-014-2 '검토' 단계) | ☐ |

총 **22건** (P1: 16건 / P2: 5건 / P3: 1건)

---

## 2. P1 — Critical (마이그레이션 자체 차단)

### H-01. KR 정식 hostname 통일

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 🌐 플랫폼 IP 기반 노출 기준 §3-2: *"hongcafe.com = KR"* / 📱 Android 네이티브 수정 요청서 §1: *"www.hongcafe.com = KR"* |
| **현재 정책** | **두 문서가 다름**. Android는 `https://www.hongcafe.com/?devicerole=android` 사용. GAP 분석은 apex `hongcafe.com` 사용. 어느 것이 정식인지 미확정. |
| **권고안** | **`www.hongcafe.com` 통일** (Android 기준). 이유: ① Android v3.9.3 운영 중 ② SharedPreferences로 `KR` 저장 시 `www.` URL로 로드 ③ 기존 PHP 백엔드가 `www.` 기준으로 운영 중일 가능성 높음. apex `hongcafe.com`은 H-02로 308 redirect 처리. |
| **결정안** | ☐ 권고안 수용 / ☐ 대안 / ☐ 유지: ___________ |

---

### H-02. apex `hongcafe.com` 308 redirect

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 미정의 (현재 apex 도착 시 동작 미확인) |
| **현재 정책** | apex `hongcafe.com`에 직접 접근 시의 동작이 명시 안 됨. GAP 분석서는 apex를 메인 도메인으로 가정하고 GeoIP 분기. Android는 `www.` 기준. |
| **권고안** | apex `hongcafe.com` → `www.hongcafe.com` 308 영구 redirect. 이유: ① H-01 결정과 일관 ② 사용자가 apex를 입력해도 동일 KR 서비스 도달 ③ SEO 신호 통합 (Google이 apex/www를 단일로 인식). 단 GAP-1의 "메인 도메인 GeoIP 분기"는 **`www.hongcafe.com`이 메인 역할**로 재정의. |
| **결정안** | ☐ 권고안 수용 / ☐ 대안 (apex가 메인) / ☐ 유지: ___________ |

---

### H-03. DNS A/AAAA 등록 현황

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 📱 Android 네이티브 수정 요청서가 `jp.hongcafe.com`, `en.hongcafe.com`을 사용 중이라고 명시 |
| **현재 정책** | Android v3.9.3은 hardcoded `www.hongcafe.com`만 사용. `jp./en.`은 v4.0.0에서 추가 예정. **현재 두 subdomain의 DNS 등록 상태 미확인**. |
| **권고안** | 즉시 확인: ① DNS provider (Route53 / Cloudflare / GoDaddy 등) ② 현재 `en.hongcafe.com`, `jp.hongcafe.com`의 A/AAAA 레코드 존재 여부 ③ 미등록 시 신규 등록 절차 + 소요 시간 ④ TTL 설정 (cutover 시 단축 권장 60s) |
| **미결정 시 영향** | Phase 4 인프라 작업 차단 → 마이그레이션 일정 산정 불가 |
| **결정안** | DNS provider: ___________ / 등록 현황: ☐ 둘 다 등록 ☐ 일부만 ☐ 미등록 / 신규 등록 가능: ☐ Yes ☐ No |

---

### H-04. nginx `X-Forwarded-Host` 헤더 전파

| 구분 | 내용 |
|---|---|
| **as-is 문서** | `infra/nginx/conf.d/nextjs.conf:73-76` — `proxy_set_header Host $host` 만 명시. `X-Forwarded-Host` 미설정. |
| **현재 정책** | Next.js middleware(`proxy.js`)는 next-intl `domains` 라우팅을 위해 `X-Forwarded-Host` 헤더가 필요. 미전파 시 host 감지 실패 → fallback 동작. |
| **권고안** | nginx vhost에 `proxy_set_header X-Forwarded-Host $host;` 추가. **옵션 없음**. 미적용 시 라우팅 전면 회귀. |
| **출처** | next-intl 공식 routing/middleware: *"the host is read from the `x-forwarded-host` header, with a fallback to `host`"* (<https://next-intl.dev/docs/routing/middleware>) |
| **결정안** | ☐ 활성화 / ☐ 대안: ___________ |

---

### H-05. Wildcard `*.hongcafe.com` SSL 발급 방법

| 구분 | 내용 |
|---|---|
| **as-is 문서** | `infra/nginx/conf.d/nextjs.conf:20` — `server_name yourdomain.com` (placeholder). SSL 인증서 경로 미확인. |
| **현재 정책** | 현재 인증서 발급 방식 / 만료일 / 갱신 자동화 여부 미확인. |
| **권고안** | ① **LetsEncrypt wildcard (DNS-01 challenge)** + certbot 자동 갱신. 무료, 90일 자동 갱신, 업계 표준. DNS provider API 통합 필요. ② 사내 CA 또는 유료 CA 사용 시 갱신 일정 명시 필요. |
| **확인 필요** | 현재 인증서 발급 방식 / 만료일 / 갱신 자동화 / `*.hongcafe.com` 또는 SAN(en + jp + www) 발급 가능 여부 |
| **결정안** | 발급 방법: ☐ LetsEncrypt wildcard ☐ SAN ☐ 사내 CA ☐ 유료 / 갱신 자동화: ☐ Yes ☐ No |

---

### H-06. 통합 프로젝트 nginx vhost 분리 운영

| 구분 | 내용 |
|---|---|
| **as-is 문서** | `infra/nginx/conf.d/nextjs.conf` 단일 vhost (placeholder server_name) |
| **현재 정책** | 통합 프로젝트(Next.js)와 레거시 홍카페K(PHP)가 동일 인프라에서 운영되는지, 별도 인프라인지 미확인 |
| **권고안** | ① **`en.hongcafe.com`, `jp.hongcafe.com`** → Next.js 통합 프로젝트 upstream으로 라우팅. ② **`www.hongcafe.com`, `hongcafe.com`** → 레거시 홍카페K(PHP) upstream 유지 (변경 없음). ③ 두 vhost가 동일 nginx 인스턴스를 공유하는지 / 분리되는지 확인 필요. |
| **결정안** | 인프라 구성: ☐ 단일 nginx 통합 ☐ 분리 nginx ☐ 기타: ___________ |

---

### B-01. 백엔드 회원 DB `ac_country` 필드 보장

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 회원/인증 API 결정요청표 D-04: `JoinUser` request body에 `ac_country` required 필드 존재 |
| **현재 정책** | 7-Case 모델 Case 2 ("회원 국가 기준 서비스 출력")의 작동을 위해 모든 회원의 `ac_country` 필드가 채워져야 함. **기존 회원의 `ac_country` 충진 상태 미확인**. |
| **권고안** | ① 신규 가입 시 `ac_country` NOT NULL 보장 (D-04와 연계). ② 기존 회원 중 `ac_country` NULL이면 첫 로그인 시 강제 입력 또는 가입 시점 IP에서 추론. ③ `ac_country` 변경 가능 여부 + 변경 시 audit log 정책 (GAP-10 §4-1 권고: 회원 국적 vs 서비스 리전 분리). |
| **미결정 시 영향** | Case 2 작동 불가 → 회원 사용자가 잘못된 hostname으로 라우팅 |
| **결정안** | ☐ 권고안 수용 / ☐ 대안 / ☐ 유지: ___________ / **기존 NULL 회원 수**: ___________ |

---

### B-02. 백엔드 발송 이메일/푸시 링크의 hostname 정책

| 구분 | 내용 |
|---|---|
| **as-is 문서** | as-is는 단일 도메인(`www.hongcafe.com`) 사용. 분기 정책 없음. |
| **현재 정책** | 비밀번호 재설정 링크, 이메일 인증 링크, 푸시 알림 deeplink 등의 hostname 미정의. |
| **권고안** | 사용자의 `ac_country` 기준 분기. `JP` → `https://jp.hongcafe.com/...`, `EN` → `https://en.hongcafe.com/...`, `KR` → `https://www.hongcafe.com/...`. **B-01 (`ac_country` 보장) 의존**. |
| **미결정 시 영향** | 일본 사용자가 영어 이메일로 이메일 인증 → UX 마찰. 또는 잘못된 hostname 도착 시 재로그인 강요(D-14 cross-hostname DENIED 정책). |
| **결정안** | ☐ ac_country 기반 분기 / ☐ 항상 en.hongcafe.com / ☐ 기타: ___________ |

---

### B-03. 소셜 OAuth Callback URL — 신규 hostname 등록

| 구분 | 내용 |
|---|---|
| **as-is 문서** | as-is에 소셜 로그인 사용 여부 + provider 목록 미확인. CLAUDE.md/기획서에 SNS 로그인 언급 있음. |
| **현재 정책** | OAuth provider(Google, Apple, LINE, Kakao 등) 콘솔에 redirect URI를 사전 등록해야 함. 신규 hostname(`en.hongcafe.com`, `jp.hongcafe.com`)이 등록되지 않으면 cutover 직후 OAuth 전면 실패. |
| **권고안** | ① **사용 중인 OAuth provider 전체 목록 공유** ② 각 provider 콘솔에 신규 redirect URI 사전 등록 (`https://en.hongcafe.com/api/auth/callback/...`, `https://jp.hongcafe.com/api/auth/callback/...`) ③ cutover 1주 전까지 등록 완료 |
| **미결정 시 영향** | cutover 직후 SNS 로그인 사용자 전면 차단 |
| **결정안** | **사용 provider 목록**: ___________ / 신규 hostname 등록 가능: ☐ Yes ☐ No / 등록 완료 예정일: ___________ |

---

### B-05. D-14 쿠키 정책 확정 시점 (Cross-Reference)

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 📋 회원/인증 결정요청표 D-14 (2026-04-13 작성, 결정 진행 중) |
| **현재 정책** | D-14 권고안: `__Host-` prefix, HttpOnly, Secure, SameSite=Lax, **Cross-hostname session sharing: DENIED**. 본 hostname 마이그레이션의 쿠키 정책은 D-14 결정에 종속. |
| **권고안** | D-14 권고안을 그대로 채택. 별도 결정 불필요. **D-14의 confirm 시점이 본 마이그레이션의 Phase 3 진입 조건**. |
| **결정안** | D-14 권고안 채택 ☐ Yes ☐ No / 확정 예정일: ___________ |

---

### L-01. 레거시 홍카페K 쿠키 이름 충돌 검토

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 레거시 홍카페K(PHP CodeIgniter4)의 쿠키 정책 미확인 |
| **현재 정책** | 통합 프로젝트(Next.js)는 `hc_access`, `hc_refresh`, `hc_csrf`, `hc_csrf_meta`, `hc_country`, `hc_fp` 쿠키 사용 (D-02/D-03/D-14 확정 후). **레거시 홍카페K도 `hc_*` 또는 `PHPSESSID` 등의 쿠키를 `www.hongcafe.com`에 발급 중일 가능성**. |
| **권고안** | ① 레거시 홍카페K가 발급하는 모든 쿠키 이름 + Domain 속성 공유 ② 통합 프로젝트와 이름 충돌 검증 (D-14가 `__Host-` prefix를 사용하면 Domain attribute 미설정으로 host-only → 충돌 없음. **단 prefix 미사용 시 충돌 가능**). ③ 충돌 발견 시 통합 프로젝트 쿠키 이름을 `hcg_*` (global) 등으로 변경. |
| **미결정 시 영향** | 사용자가 한 host에서 다른 host로 이동 시 쿠키 덮어쓰기 → 인증 실패 / 데이터 노출 가능 |
| **결정안** | **레거시 쿠키 이름 목록**: ___________ / 충돌 검증: ☐ 충돌 없음 ☐ 충돌 발견 (조치 필요) |

---

### L-02. 신규 Subdomain 신설에 대한 레거시팀 동의

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 📱 Android 네이티브 수정 요청서가 `jp.hongcafe.com`, `en.hongcafe.com`을 사용 중이라고 명시 |
| **현재 정책** | 두 subdomain이 이미 사용 중인지 미확인. 사용 중이라면 레거시팀이 이미 동의했을 가능성. 미사용이라면 신설 동의 필요. |
| **권고안** | 레거시 홍카페K팀의 명시적 합의 문서화. ① subdomain 신설 동의 ② DNS 권한 위임 또는 등록 절차 합의 ③ 향후 운영 책임 주체 명시 (통합 프로젝트팀 vs 레거시팀) |
| **결정안** | 동의 ☐ Yes ☐ No / 책임 주체: ___________ |

---

### O-01. Cutover Freeze Window 일정

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 미정의 |
| **현재 정책** | 마이그레이션 cutover는 ① DNS 변경 ② nginx vhost 갱신 ③ 신규 SSL 활성화 ④ 308 redirect 룰 활성화 ⑤ 모니터링 강화가 동시에 가능한 시점이 필요. 트래픽 최저 시간대 권장. |
| **권고안** | 평일 새벽 또는 주말 새벽. dual-mode 1~2주 시작 시점 + 종료 시점 모두 배정 필요. |
| **회신 형식** | 구체적 일자 (YYYY-MM-DD) 또는 sprint 번호 |
| **결정안** | Dual-mode 시작: ___________ / Dual-mode 종료(308 활성화): ___________ |

---

### R-01. 제3국 IP 폴백 전략 (GeoIP 실패/미매핑 국가)

| 구분 | 내용 |
|---|---|
| **기획검수 원문** | REG-008: GeoIP 실패 또는 JP/KR/US 외 제3국 IP일 때의 처리 방침 — **미확정 (3가지 선택지)** |
| **매트릭스 상태** | Case 1-C, 5-2, 6-1에서 **리전 선택화면(`/region-select`)**으로 독자 확정 |
| **갭 분석 판정** | 매트릭스가 기획 미확정을 선점. 3가지 선택지: (A) `en.hongcafe.com` 자동 fallback (B) 가장 가까운 리전 자동 선택 (C) 리전 선택화면 노출 |
| **권고안** | **(C) 리전 선택화면**이 가장 안전 (Google 자동 리다이렉트 회피 권고 §3.1 #4, MaxMind 변동성 §3.1 #6). 단 기획 결정권자가 (A) 자동 fallback을 선택할 수 있으므로 확정 요청. |
| **미결정 시 영향** | `proxy.js` 4단 reconcile 구현 차단 → Phase II 전체 보류 |
| **결정안** | ☐ (A) en 자동 fallback / ☐ (B) 가까운 리전 자동 / ☐ (C) 선택화면 / ☐ 기타: ___________ |

---

### R-02. VPN/Tor 의심 IP 처리 정책

| 구분 | 내용 |
|---|---|
| **기획검수 원문** | REG-010: VPN 의심 시 **선택화면 노출** (기획검수 결정) |
| **매트릭스 상태** | Case 6-1, 6-2에서 **정상 취급**(GeoIP 결과 사용)으로 독자 판단 — **기획과 직접 모순** |
| **갭 분석 판정** | 매트릭스의 "정상 취급"은 트레이드오프 기반 의도적 반전이었으나, 기획 결정을 번복하는 권한이 엔지니어링에 없음 |
| **선택지** | (A) 기획 REG-010 준수: VPN 의심 → 선택화면 (B) 매트릭스 유지: VPN → 정상 취급 (MaxMind 결과) (C) 하이브리드: 1차 정상 취급, 명시적 신고/이상 감지 시 선택화면 |
| **권고안** | VPN/Tor 감지 자체가 불완전(Tor exit node list 변동, 상용 VPN 미감지)하므로 **(B) 정상 취급**이 엔지니어링적으로 현실적. 단 기획 REG-010이 "선택화면"을 확정했으므로 Product 확인 필요. |
| **미결정 시 영향** | `proxy.js` VPN 분기 로직 미구현. 기획/엔지니어링 모순 해소 필요 |
| **결정안** | ☐ (A) 기획 준수 (선택화면) / ☐ (B) 정상 취급 / ☐ (C) 하이브리드 / ☐ 기타: ___________ |

---

### R-03. URL 리전 vs 회원 국가 불일치 — 세션 유지 옵션

| 구분 | 내용 |
|---|---|
| **기획검수 원문** | REG-014-2: 이번 세션만 URL 리전 유지 옵션 — **'검토' 단계** (미확정) |
| **매트릭스 상태** | Case 3-A-1에서 `hc_region_override` 세션 쿠키를 사용하여 **'확정'으로 격상** |
| **갭 분석 판정** | 매트릭스가 '검토'를 '확정'으로 선점. 쿠키 이름, TTL, 우선순위 미확정. |
| **확정 필요 사항** | ① 세션 쿠키 방식 채택 여부 ② `hc_region_override` 쿠키 TTL (세션=브라우저 닫기까지 vs 24h vs 무기한) ③ 회원 `ac_country`와의 우선순위 (REG-002 "회원국가 최우선" vs hostname 우선 재배치) ④ 배너 UI에서 "계속 이 리전 유지" vs "내 리전으로 이동" 선택지 |
| **권고안** | 세션 쿠키 방식은 합리적이나, TTL과 우선순위는 사용자 행동 데이터 기반으로 Product가 결정해야 함 |
| **미결정 시 영향** | `RegionMismatchBanner` 컴포넌트 미구현, URL 리전 충돌 시 사용자 혼란 |
| **결정안** | 세션 쿠키 채택: ☐ Yes ☐ No / TTL: ☐ 세션 ☐ 24h ☐ 무기한 ☐ 기타 / 배너 UI: ☐ 2버튼(유지+이동) ☐ 1버튼(이동만) ☐ 기타: ___________ |

---

## 3. P2 — High (인프라/SEO 보조 작업)

### H-07. 308 Redirect 룰 활성화 시점

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 미정의 |
| **현재 정책** | 구 URL(`/en/login` 등 prefix 형식)이 외부에서 참조될 가능성. cutover 후 308 redirect로 신 URL로 영구 이전. |
| **권고안** | **dual-mode 종료 시점에 활성화**. dual-mode 기간 동안은 두 URL 병행 → 회귀 발견 시 즉시 롤백. nginx에 `location ~ ^/en/(.*)$ { return 308 https://en.hongcafe.com/$1; }` 추가. |
| **결정안** | ☐ 권고안 수용 / ☐ 즉시 활성화 / ☐ 활성화 안 함 |

---

### H-08. CDN/Reverse Proxy vhost별 캐싱 분리

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 현재 사용 중인 CDN/캐시 솔루션 미확인 |
| **현재 정책** | CDN 캐시 키가 hostname을 포함하지 않으면 en/jp 콘텐츠 혼선 가능 |
| **권고안** | subdomain별 별도 캐시 키 (`vhost-aware caching`). CloudFront 경우 cache behavior에 hostname 포함, Cloudflare 경우 cache key custom 설정. |
| **결정안** | CDN 솔루션: ___________ / vhost 분리 캐시: ☐ Yes ☐ No |

---

### B-04. Web Push (FCM Web SDK) 정책

| 구분 | 내용 |
|---|---|
| **as-is 문서** | Android는 FCM Topic 사용(`all_KR`/`all_JP`/`all_EN`). Web Push 사용 여부 미확인. |
| **현재 정책** | Web Push는 origin(scheme + host + port)별로 분리됨. `en.hongcafe.com`과 `jp.hongcafe.com`은 별도 origin → 별도 VAPID 키 + 별도 Service Worker 등록 필요. |
| **권고안** | ① **현재 미사용이면 no-op**. ② 사용 중이면 subdomain별 VAPID 키 생성 + 백엔드 DB에 `push_endpoint`를 region별로 분리 저장. |
| **결정안** | Web Push 사용: ☐ Yes ☐ No / 사용 시 정책: ___________ |

---

### O-02. 배포 전략 (Big-bang / Dual-mode / Canary)

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 미정의 |
| **현재 정책** | 구 URL 사용자 트래픽이 존재하는 상태에서 신 URL로 cutover하는 방식 결정. |
| **권고안** | **B. Dual-mode 1~2주**. 구 URL 유지 + 신 URL 활성화 → 회귀 발견 시 즉시 롤백 + SEO 인덱스 안전 전환. ① Big-bang: 단순하나 롤백 어려움 ② Canary: 가장 안전하나 SEO 신호 혼동 위험. |
| **결정안** | ☐ A. Big-bang / ☐ B. Dual-mode / ☐ C. Canary / ☐ 기타 |

---

### S-01. Google Search Console 신규 Property 등록

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 미정의 (Search Console 권한자 미확인) |
| **현재 정책** | 신규 subdomain별 Search Console property 등록 필요. hreflang 인식 + sitemap 제출 + 색인 모니터링. |
| **권고안** | ① 현재 hongcafe.com Search Console 권한 보유자 확인 ② `en.hongcafe.com`, `jp.hongcafe.com` 신규 property 등록 ③ DNS TXT 또는 HTML 파일 검증 ④ 마이그레이션 1주 전까지 완료. |
| **결정안** | 권한 보유자: ___________ / 등록 가능: ☐ Yes ☐ No |

---

## 4. P3 — Medium

### S-02. hreflang/sitemap.xml/robots.txt 작업 담당

| 구분 | 내용 |
|---|---|
| **as-is 문서** | 통합 프로젝트는 hreflang/sitemap 모두 미구현 (현재 0개 페이지) |
| **현재 정책** | Google Search Central 권고: 모든 페이지에 hreflang head tag, subdomain별 sitemap.xml/robots.txt 분리 발급. |
| **권고안** | ① **FE 구현**: `generateMetadata()` 6개 함수 + `lib/i18nMeta.js` 헬퍼 + `app/sitemap.js` + `app/robots.js` ② **마케팅 검증**: Search Console에서 hreflang 인식 확인 + sitemap 제출 |
| **출처** | <https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites> |
| **결정안** | ☐ 권고안 수용 (FE+마케팅 협업) / ☐ FE 단독 / ☐ 기타 |

---

## 5. 의존 관계 그래프

```
H-01 (KR hostname 통일) ──┐
                          ├─→ H-02 (apex 308) ──→ H-03 (DNS) ──┐
L-01 (쿠키 충돌) ─────────┤                                    │
L-02 (subdomain 동의) ────┘                                    │
                                                               ├─→ H-04 (X-Forwarded-Host)
                                                               │   └─→ H-05 (Wildcard SSL)
                                                               │       └─→ H-06 (vhost 분리)
                                                               │           └─→ O-01 (cutover 일정)
                                                               │               └─→ O-02 (배포 전략)
                                                               │                   ├─→ H-07 (308 활성화)
                                                               │                   └─→ H-08 (CDN 캐싱)
                                                               │
B-05 (D-14 쿠키 확정) ─→ B-01 (ac_country) ─→ B-02 (이메일 URL)
B-03 (OAuth callback) ─────────────────────────────────────────┤
B-04 (Web Push) ───────────────────────────────────────────────┤
                                                               │
S-01 (Search Console) ─→ S-02 (hreflang/sitemap) ──────────────┘

R-01 (제3국 IP 폴백) ──┐
R-02 (VPN 처리 정책) ──┼─→ proxy.js 4단 reconcile (Phase II)
R-03 (세션 리전 유지) ──┘    └─→ region-select 전체 구현
                              └─→ RegionMismatchBanner
```

**Critical Path 8건** (P1 의존성 최상위):
1. **H-01 / L-01 / L-02** — KR hostname + 레거시 합의가 모든 것의 출발
2. **H-03** — DNS 등록 가능 여부가 인프라 작업 가능 여부 결정
3. **H-04** — `X-Forwarded-Host` 전파는 next-intl 동작 필수 (옵션 없음)
4. **B-05** — D-14 쿠키 정책 확정
5. **O-01** — Cutover 일정 배정
6. **R-01** — 제3국 IP 폴백이 proxy.js reconcile 로직 결정
7. **R-02** — VPN 정책이 proxy.js 분기 로직 결정 (기획 vs 매트릭스 모순 해소)
8. **R-03** — 세션 유지 방식이 RegionMismatchBanner + 쿠키 설계 결정

---

## 6. 회신 양식 (Quick Reference)

답변 시 다음 형식 권장:

```
H-01: 권고안 수용
H-02: 권고안 수용
H-03: DNS provider = Cloudflare / 등록 현황 = 둘 다 등록 / 신규 등록 가능 = Yes
H-04: 활성화
H-05: LetsEncrypt wildcard / 자동 갱신 Yes
H-06: 단일 nginx 통합
H-07: 권고안 수용 (dual-mode 종료 시점)
H-08: CDN = CloudFront / vhost 분리 = Yes
B-01: 권고안 수용 / 기존 NULL 회원 수 = 0
B-02: ac_country 기반 분기
B-03: provider = Google,Apple,LINE / 등록 가능 = Yes / 완료 예정 = 2026-05-08
B-04: Web Push 미사용
B-05: D-14 권고안 채택 / 확정 예정 = 2026-04-20
L-01: 레거시 쿠키 = ['PHPSESSID', 'ck_login_member', 'hdata'] / 충돌 없음
L-02: 동의 Yes / 책임 주체 = 통합 프로젝트팀
O-01: Dual-mode 시작 = 2026-05-15 / 종료 = 2026-05-29
O-02: B. Dual-mode
S-01: 권한 보유자 = ___ / 등록 가능 = Yes
S-02: 권고안 수용 (FE + 마케팅 협업)
```

또는 본 문서를 직접 수정하여 ☐를 ☑로 표시.

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|---|---|---|---|
| v1.0 | 2026-04-13 | 초안 작성 (Section A 7항목, Section B 19항목) | 명우현 |
| v2.0 | 2026-04-13 | Notion 발견 반영 — 7-Case 모델/D-14 쿠키/Android 매핑은 사전 확정 사항으로 이동. 진짜 미결정 19건만 추출. 기존 결정요청표(D-XX 4컬럼) 양식과 통일 | 명우현 |
| v3.0 | 2026-04-16 | 갭 분석(기획검수 48건 vs IP 매트릭스 28케이스) 반영. R-01(제3국 IP 폴백)/R-02(VPN 정책)/R-03(세션 리전 유지) 3건 추가 — 매트릭스가 기획 미확정(REG-008/010/014-2)을 독자 선점한 것을 격하. 총 19→22건. 의존 관계 그래프에 R-01~R-03 추가, Critical Path 5→8건 확장 | 명우현 |

## 8. 참고 문헌

1. 🌐 플랫폼 IP 기반 노출 기준 — 갭 시나리오 분석서 (2026-04-09): 7-Case 모델 + GAP-1~10 권고안
2. 📱 Android 네이티브 수정 요청서 (통합 프로젝트): hostname 매핑 + FCM Topic 정책
3. 📋 회원/인증 API 작업 이슈 결정 요청표 (2026-04-13): D-02/D-03/D-14 쿠키 정책
4. Google Search Central — Multi-Regional Sites: <https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites>
5. MDN — HTTP Cookies: <https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies>
6. RFC 6265 — HTTP State Management: <https://www.rfc-editor.org/rfc/rfc6265>
7. RFC 7538 — HTTP 308: <https://www.rfc-editor.org/rfc/rfc7538>
8. next-intl Routing Middleware: <https://next-intl.dev/docs/routing/middleware>
9. Internal: `docs/specs/hostname-migration-plan.md`
10. 🔍 기획검수 48건 vs IP 매트릭스 28케이스 갭 분석 v1.0 (2026-04-16): `docs/audits/2026-04-16-planning-spec-vs-ip-scenario-gap-analysis.md`
