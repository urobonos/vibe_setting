# Frontend Functional Spec — Legal Notices (제3자 라이선스 고지)

> Source: as-built 코드(`app/[locale]/legal/notices/page.js`, 커밋 `bd5d4ce`) + 감사 문서(`docs/audits/2026-04-15-geolite2-attribution-relocation.md`) + 루트 `NOTICE.md`
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | Legal Notices (제3자 라이선스 / Attribution 페이지) |
| 사용자 목표 | MaxMind GeoLite2 / geoip-lite npm 패키지 등 제3자 라이브러리·데이터에 대한 라이선스 고지를 사용자가 확인 가능하도록 노출 |
| 퍼블리싱 상태 | **구현 완료 — 임시 디자인** (커밋 `bd5d4ce`) — 단일 페이지 + Server 정적 렌더 |
| 기능 연동 상태 | **연동 완료** — `messages/{en,ja,ko}.json`의 `legal.*` 키 + 외부 라이선스 URL Link |
| i18n 네임스페이스 | `legal` |
| 지원 로케일 | `en`, `ja` |
| 라이선스 준수 근거 | CC BY-SA 4.0 §3(a)(2) — "URI or hyperlink to a resource" 형태 attribution 허용 (감사 §3.1 #4) |
| 뷰포트 기준 | 모바일 + 데스크톱 — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]` 적용 (2026-04-20 430px 일원화) |

### 비즈니스 가치 / 법적 준수

- **MaxMind GeoLite EULA §3** + **CC BY-SA 4.0 §3(a)(2)**에 따른 attribution 의무 이행.
- 매 페이지 노출 의무는 **없음** (감사 §3.1 #5) — `/legal/notices` 단일 페이지 + 푸터/하단 링크로 satisfy.
- **이중 배치**: 루트 `NOTICE.md` (개발자/배포자용) + `/legal/notices` (사용자용 i18n 본문).
- **DB 주간 갱신 의무**: GeoLite EULA §6.3 — 30일 내 구버전 폐기 → `.github/dependabot.yml`로 geoip-lite 주간 업데이트 자동화.

### 도메인 흐름

```
진입점:
  ├── 푸터 "Licenses" 링크 (rel="license") — Phase C-1 layout 의존
  ├── intro 페이지의 GeoIP 사용 안내 (미구현 — §6 #4)
  └── 직접 URL (`/legal/notices`)
       ↓
/legal/notices Server Component
  ├── h1 "Third-party Notices"
  ├── intro 문구
  ├── GeoLite2 Country Database 섹션
  │     ├── MaxMind attribution (data-geoip-attribution="maxmind")
  │     ├── CC BY-SA 4.0 라이선스 외부 링크 (rel="license noreferrer" target="_blank")
  │     └── geoip-lite npm 패키지 외부 링크 (rel="noreferrer" target="_blank")
  └── ← Home 링크
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/legal/notices` | `app/[locale]/legal/notices/page.js` | NoticesPage (Server) | Server only — 정적 | `legal` |

> 디자인: 임시 스타일 (layout.js wrapper의 `max-w-[43rem]` 상속 + Tailwind text-[14px] gray-on-white). 정식 디자인 재발급 시 design-normalizer 재실행 필요.

---

## 3. 페이지 정의

### 3-1. Third-party Notices 페이지

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/legal/notices` |
| Server Component | `app/[locale]/legal/notices/page.js` |
| Client Component | (없음 — 정적 콘텐츠 + Link만) |
| 화면설계서 | (없음 — 감사 권고로 신설) |

#### UI 섹션 (위→아래, as-built)

| # | 섹션 | 설명 |
|---|------|------|
| 0 | main 컨테이너 | `w-[100%] min-h-[100dvh] px-[2rem] py-[4rem] text-[1.4rem] leading-[2rem] text-[#333333]` — max-w / mx-[auto]는 `app/[locale]/layout.js`의 SSOT wrapper에서 상속 (2026-04-20 430px 일원화) |
| 1 | h1 페이지 제목 | `legal.noticesPageTitle` ("Third-party Notices") — text-[2rem] font-bold mb-[2rem] |
| 2 | intro 문단 | `legal.noticesIntro` — mb-[3rem] |
| 3 | GeoLite2 섹션 | `<section className="mb-[4rem]">` |
| 3a | h2 데이터셋 명 | "GeoLite2 Country Database" — text-[1.6rem] font-semibold mb-[1.2rem] |
| 3b | MaxMind attribution | `<p data-geoip-attribution="maxmind">` — `legal.maxmindAttribution` ("This product includes GeoLite2 data created by MaxMind, available from https://www.maxmind.com") |
| 3c | CC BY-SA 4.0 라이선스 링크 | `<Link href="https://creativecommons.org/licenses/by-sa/4.0/" rel="license noreferrer" target="_blank" className="underline text-[#6335b4]">` — `legal.geoLicenseLabel` |
| 3d | geoip-lite 패키지 링크 | `<Link href="https://github.com/geoip-lite/node-geoip" rel="noreferrer" target="_blank">` — `legal.geoPackageLabel` |
| 4 | Home 링크 | `<Link href="/" className="underline">` "← Home" — text-[1.2rem] text-[#999999] |

#### 상태 관리

- 없음 (Server Component, 정적 콘텐츠).

#### API 연동

- 없음.

#### 인터랙션

| 액션 | 동작 |
|------|------|
| CC BY-SA 4.0 링크 클릭 | 외부 이동 — `https://creativecommons.org/licenses/by-sa/4.0/` (새 탭, `rel="license noreferrer"`) |
| geoip-lite 링크 클릭 | 외부 이동 — `https://github.com/geoip-lite/node-geoip` (새 탭, `rel="noreferrer"`) |
| Home 링크 클릭 | `/` 이동 (`<Link>`) |

#### 비즈니스 규칙 / 라이선스 의무

| 규칙 | 설명 / 근거 |
|------|------------|
| **단일 페이지 attribution** | CC BY-SA 4.0 §3(a)(2) — "URI or hyperlink to a resource that includes the required information"으로 satisfy. 매 페이지 시각 노출 불필요 (감사 §3.1 #4, #5) |
| **rel="license"** | CC BY-SA 4.0 라이선스 링크에 `rel="license"` 속성 — HTML5 표준 attribution 시그널 |
| **`data-geoip-attribution="maxmind"` 마커** | 자동화 도구가 attribution 위치를 식별할 수 있도록 data-attribute 명시 (감사 §3.1 #6 Apache TC-61 선례 준용) |
| **이중 배치 (NOTICE.md + 페이지)** | geoip-lite README의 보수적 해석("documentation에 attribution 표시")까지 방어 (감사 §3.2 반대 의견 B) |
| **DB freshness 의무** | GeoLite EULA §6.3 — 30일 내 구버전 폐기. Dependabot 주간 자동 업데이트 (`.github/dependabot.yml`)로 자동 준수 |
| **노출 의무 위치 (감사 결정)** | (a) 푸터 단일 "Licenses" 링크 (`rel="license"`) — Phase C-1 layout 의존, (b) `/legal/notices` 페이지 본문 |

#### 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 외부 링크 클릭 시 동일 탭 이동 | `target="_blank"`로 새 탭 강제 — 사용자가 본 사이트에 머무를 수 있도록 |
| `rel="noreferrer"` 누락 시 reverse tabnabbing 위험 | 모든 외부 링크에 `rel="noreferrer"` 적용 (`legal/notices/page.js:31, 42`) |
| 비로그인 직접 진입 | 인증 미필요 페이지 — 정상 노출 |
| i18n 키 누락 | `getTranslations`가 fallback locale로 폴백 (next-intl 기본 동작) |
| 봇 진입 | 정상 노출 (SEO 가치 — 라이선스 attribution 인덱스 가능) |

#### i18n (legal 네임스페이스)

| 키 | en 값 | 용도 |
|----|------|------|
| `noticesPageTitle` | Third-party Notices | h1 |
| `noticesIntro` | This product uses the following third-party software and data: | 인트로 문단 |
| `maxmindAttribution` | This product includes GeoLite2 data created by MaxMind, available from https://www.maxmind.com | MaxMind attribution 본문 |
| `geoLicenseLabel` | Creative Commons Attribution-ShareAlike 4.0 International License | CC BY-SA 라벨 |
| `geoLicenseUrl` | https://creativecommons.org/licenses/by-sa/4.0/ | CC BY-SA URL (i18n으로 관리 — 향후 로케일별 대안 URL 가능) |
| `geoPackageLabel` | Delivered via the geoip-lite npm package | geoip-lite 라벨 |
| `geoPackageUrl` | https://github.com/geoip-lite/node-geoip | geoip-lite URL |
| `noticesLinkLabel` | Licenses | 푸터 링크 라벨 (Phase C-1 layout 사용) |

#### 의존성 (as-built)

| 의존성 | 용도 |
|--------|------|
| `next/link` | 외부/내부 링크 |
| `next-intl/server` (`getTranslations`) | i18n 메시지 |
| `messages/{en,ja,ko}.json` (`legal.*`) | i18n 번역 |
| 루트 `NOTICE.md` | 개발자/배포자용 attribution 원문 |
| `.github/dependabot.yml` | geoip-lite 주간 업데이트 (DB freshness §6.3 준수) |

---

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 파일 경로 | 사용 페이지 | 비고 |
|---------|----------|-----------|------|
| (없음 — 단일 정적 페이지) | — | — | 향후 LicenseSection 분리 가능 |

---

## 5. 크로스 도메인 의존성

| 의존 도메인 | 의존 방향 | 설명 |
|-----------|----------|------|
| layout | layout → legal-notices | 푸터 "Licenses" 링크가 본 페이지로 이동 (Phase C-1) |
| `lib/geoip.js` | (간접) geoip-lite 사용 → legal-notices에 attribution | GeoLite2 라이선스 의무 ↔ proxy.js GeoIP 라우팅 |
| `proxy.js` middleware | 동일 | proxy.js의 GeoIP lookup이 본 페이지의 attribution을 정당화 |
| 외부 (CC BY-SA / GitHub geoip-lite) | legal-notices → external | 사용자가 라이선스 원문 확인 |

---

## 6. 미확정 사항 (v1.0)

> 분류: **유형 A** = as-built 구현 완료 / **유형 B** = 감사 권고 미반영 / **유형 C** = 추가 구현 필요 / **유형 D** = 정책·디자인 확정 필요

| # | 우선순위 | 유형 | 항목 | 설명 | 근거 |
|---|---------|------|------|------|------|
| 1 | **[MUST]** | A | 단일 페이지 + 푸터 링크 attribution | CC BY-SA 4.0 §3(a)(2) — URI/hyperlink로 satisfy. 매 페이지 시각 노출 불필요 | 감사 권고안 1 |
| 2 | **[MUST]** | A | NOTICE.md + 페이지 이중 배치 | Apache TC-61 선례 준용 | 감사 권고안 2 |
| 3 | **[MUST]** | A | DB 주간 갱신 Dependabot | GeoLite EULA §6.3 (30일 내 구버전 폐기) | 감사 권고안 3 |
| 4 | **[HIGH]** | C | 푸터 "Licenses" 링크 (Phase C-1 의존) | layout footer에 `<Link href="/legal/notices" rel="license">{t('noticesLinkLabel')}</Link>` 단일 요소 추가 — 현재 layout에 미적용 | 감사 권고안 1 |
| 5 | **[HIGH]** | D | 디자인 시안 발급 | 현재 임시 스타일 (Tailwind 기본). Figma 시안 발급 후 design-normalizer 재실행 | 디자인 |
| 6 | **[MEDIUM]** | C | KR 호스트(홍카페K) attribution 정책 | 본 프로젝트 범위 밖이나 GeoLite 데이터를 공유한다면 동일 attribution 의무 | 백엔드 정책 |
| 7 | **[MEDIUM]** | C | 추가 제3자 라이선스 섹션 | Stripe / SendBird / NicePay / Google reCAPTCHA Enterprise / Apple Sign In / OAuth provider 등 외부 의존성 라이선스 | 법무 검토 |
| 8 | **[MEDIUM]** | D | i18n URL i18n 처리 | `geoLicenseUrl`이 `messages/*.json`에 키로 존재 — JP/KR 로케일별 대안 URL이 있는지 검토 (현재는 모두 동일 .org URL) | 법무 |
| 9 | **[LOW]** | C | 푸터 외 진입점 | mypage, 회원가입 약관 동의 영역 등에 보조 진입점 추가 검토 | UX |
| 10 | **[LOW]** | C | SEO meta tag | 라이선스 페이지에 적절한 noindex 또는 follow 정책 결정 | SEO |
| 11 | **[LOW]** | A | external 링크 보안 | `rel="license noreferrer"` + `target="_blank"` — reverse tabnabbing 방지 | as-built |
| 12 | **[LOW]** | A | data-geoip-attribution 마커 | 자동화 도구가 attribution 위치를 식별 가능 (Apache TC-61 선례) | as-built |

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | as-built 신규 페이지(`/legal/notices`, 커밋 `bd5d4ce`) 기반 신규 작성. 감사 문서(`2026-04-15-geolite2-attribution-relocation.md`) 결론(레이아웃 전면 노출 제거 + 단일 페이지 + 푸터 링크 + NOTICE.md 이중 배치) 반영. CC BY-SA 4.0 §3(a)(2) URI 형태 attribution 정당성, GeoLite EULA §6.3 DB 갱신 의무, Apache TC-61 선례 준용, 디자인 미적용 임시 스타일 명시. 미확정 사항 12건(푸터 링크 layout 적용/디자인 시안/추가 라이선스 섹션) | 명우현 |
