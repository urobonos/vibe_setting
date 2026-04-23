# QA Scenario Sheet — Legal Notices

> Source: ffs.md v1.0 + as-built 코드(`app/[locale]/legal/notices/page.js`) + 감사 문서(`2026-04-15-geolite2-attribution-relocation.md`)
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR 제외

---

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390×844 (모바일) + 데스크톱 — `app/[locale]/layout.js`의 SSOT wrapper `max-w-[43rem]` 상속 (2026-04-20 430px 일원화) |
| 로케일/호스트 | EN: `en.hongcafe.com/legal/notices` / JP: `jp.hongcafe.com/legal/notices` |
| 베이스 URL (개발) | `http://en.localhost:3000/legal/notices`, `http://jp.localhost:3000/legal/notices` |
| 테스트 도구 | Playwright |
| 빌드 검증 | `npm run build` 성공 |
| 라이선스 검증 도구 | (선택) `license-checker`, FOSSA — CI 통합 권고 |

---

## 2. Third-party Notices 페이지 (`/[locale]/legal/notices`)

### 2-1. 렌더링 테스트 (as-built)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| LN-R-01 | EN 호스트 정상 로딩 | 없음 | `en.localhost:3000/legal/notices` 접근 | HTTP 200, NoticesPage 정상 렌더 | P0 |
| LN-R-02 | JP 호스트 정상 로딩 | 없음 | `jp.localhost:3000/legal/notices` 접근 | HTTP 200, 일본어 본문 | P0 |
| LN-R-03 | main 컨테이너 | 없음 | DOM 검사 | `w-[100%] min-h-[100dvh] px-[2rem] py-[4rem]` (max-w는 layout.js wrapper 상속) | P1 |
| LN-R-04 | h1 페이지 제목 | 없음 | h1 확인 | `legal.noticesPageTitle` ("Third-party Notices") — text-[2rem] font-bold mb-[2rem] | P0 |
| LN-R-05 | intro 문단 | 없음 | p 확인 | `legal.noticesIntro` — mb-[3rem] | P0 |
| LN-R-06 | GeoLite2 섹션 | 없음 | `<section className="mb-[4rem]">` 확인 | h2 "GeoLite2 Country Database" + 3 항목 | P0 |
| LN-R-07 | h2 데이터셋 명 | 없음 | h2 확인 | "GeoLite2 Country Database" — text-[1.6rem] font-semibold mb-[1.2rem] | P1 |
| LN-R-08 | MaxMind attribution | 없음 | `<p data-geoip-attribution="maxmind">` 확인 | `legal.maxmindAttribution` ("This product includes GeoLite2 data created by MaxMind, available from https://www.maxmind.com") | P0 |
| LN-R-09 | data-attribute 마커 | 없음 | DOM 검사 | `data-geoip-attribution="maxmind"` 속성 — Apache TC-61 자동화 도구 식별용 | P1 |
| LN-R-10 | CC BY-SA 4.0 라이선스 링크 | 없음 | Link 확인 | href=`https://creativecommons.org/licenses/by-sa/4.0/` + `rel="license noreferrer"` + `target="_blank"` + underline + text-[#6335b4] | P0 |
| LN-R-11 | CC BY-SA 라벨 | 없음 | 텍스트 확인 | `legal.geoLicenseLabel` ("Creative Commons Attribution-ShareAlike 4.0 International License") | P0 |
| LN-R-12 | geoip-lite 패키지 링크 | 없음 | Link 확인 | href=`https://github.com/geoip-lite/node-geoip` + `rel="noreferrer"` + `target="_blank"` + underline | P0 |
| LN-R-13 | geoip-lite 라벨 | 없음 | 텍스트 확인 | `legal.geoPackageLabel` ("Delivered via the geoip-lite npm package") | P0 |
| LN-R-14 | Home 링크 | 없음 | Link 확인 | `<Link href="/" className="underline">` "← Home" — text-[1.2rem] text-[#999999] | P1 |
| LN-R-15 | 메타데이터 title | 없음 | `document.title` | "Third-party Notices — HONG CAFE" | P1 |

### 2-2. i18n 테스트 (hostname 기반)

| # | 시나리오 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| LN-I-01 | EN 호스트 | `en.hongcafe.com/legal/notices` | legal 네임스페이스 영어 (전 8 키) | P0 |
| LN-I-02 | JP 호스트 | `jp.hongcafe.com/legal/notices` | legal 네임스페이스 일본어 | P0 |
| LN-I-03 | KR 호스트 | `hongcafe.com/legal/notices` | 본 프로젝트 범위 밖 | P2 |
| LN-I-04 | 라이선스 URL i18n | EN/JP 모두 | `geoLicenseUrl`이 모두 `https://creativecommons.org/licenses/by-sa/4.0/` (현재 동일 — 향후 로케일별 대안 검토) | P2 |

### 2-3. 인터랙션 테스트 (as-built)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| LN-A-01 | CC BY-SA 4.0 외부 링크 | 없음 | CC BY-SA 링크 클릭 | 새 탭에서 `https://creativecommons.org/licenses/by-sa/4.0/` 열림 | P0 |
| LN-A-02 | geoip-lite GitHub 외부 링크 | 없음 | 링크 클릭 | 새 탭에서 `https://github.com/geoip-lite/node-geoip` 열림 | P0 |
| LN-A-03 | Home 링크 클릭 | 없음 | "← Home" 클릭 | `/` 메인 페이지 이동 | P0 |
| LN-A-04 | 외부 링크 noreferrer 동작 | 외부 링크 클릭 후 | 외부 사이트의 `document.referrer` 확인 | 빈 값 (referrer 차단) | P1 |
| LN-A-05 | 외부 링크 noopener 효과 | `rel="noreferrer"`는 noopener 효과 동반 | 외부 페이지에서 `window.opener` | null (reverse tabnabbing 방지) | P1 |

### 2-4. 접근성 테스트

| # | 시나리오 | 검증 항목 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| LN-AC-01 | 시맨틱 마크업 | h1/h2/section/p/main 사용 | 모든 시맨틱 태그 사용 | P1 |
| LN-AC-02 | 외부 링크 시각 표시 | underline 적용 | 외부 라이선스 링크에 `underline` 클래스 (시각 식별) | P1 |
| LN-AC-03 | 키보드 Tab 순서 | Tab 순차 이동 | CC BY-SA → geoip-lite → Home 순서 포커스 | P1 |
| LN-AC-04 | 색상 대비 | text-[#333333] on white | WCAG AA 통과 | P2 |
| LN-AC-05 | 외부 링크 aria-label | DOM 검사 | (권고) `aria-label="Opens in a new tab"` 또는 visible 텍스트로 명시 | P2 |

---

## 3. 라이선스 준수 검증

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| LN-LIC-01 | MaxMind attribution 본문 일치 | EULA §3 예시 문구 | `legal.maxmindAttribution` 비교 | "This product includes GeoLite Data created by MaxMind, available from https://www.maxmind.com" 형식과 일치 (커밋 메시지 검증) | P0 |
| LN-LIC-02 | CC BY-SA 4.0 라이선스 링크 정확성 | URL 검증 | `geoLicenseUrl` | `https://creativecommons.org/licenses/by-sa/4.0/` 정확히 일치 | P0 |
| LN-LIC-03 | rel="license" 속성 | 라이선스 링크 검사 | DOM 확인 | CC BY-SA 4.0 Link에 `rel="license noreferrer"` 명시 | P0 |
| LN-LIC-04 | NOTICE.md 동기화 | repo 루트 파일 | NOTICE.md ↔ /legal/notices 본문 비교 | 동일 attribution 텍스트 (개발자/사용자 이중 배치) | P0 |
| LN-LIC-05 | data-geoip-attribution 마커 | DOM 검사 | `<p data-geoip-attribution="maxmind">` | 자동화 도구가 attribution 위치 식별 가능 (Apache TC-61 선례) | P1 |
| LN-LIC-06 | DB 주간 갱신 (Dependabot) | `.github/dependabot.yml` | geoip-lite 업데이트 정책 | 주간 자동 PR 생성 (GeoLite EULA §6.3 — 30일 내 폐기) | P0 |
| LN-LIC-07 | 푸터 링크 (Phase C-1 의존) | layout footer | DOM 검사 | `<Link href="/legal/notices" rel="license">{t('noticesLinkLabel')}</Link>` — **현재 미적용 (유형 C #4)** | P0 |
| LN-LIC-08 | 매 페이지 시각 노출 미요구 | 라이선스 본문 검토 | 정책 문서 확인 | CC BY-SA 4.0 §3(a)(2) URI/hyperlink로 satisfy — 매 페이지 시각 노출 의무 없음 | P1 |

---

## 4. 보안 검증 시나리오

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| LN-SEC-01 | reverse tabnabbing 방지 | 외부 링크 클릭 후 | 외부 페이지에서 `window.opener` | null (rel="noreferrer"의 noopener 효과) | P0 |
| LN-SEC-02 | referrer 차단 | 외부 링크 클릭 후 | 외부 페이지에서 `document.referrer` | 빈 값 (rel="noreferrer") | P1 |
| LN-SEC-03 | XSS via i18n | `legal.maxmindAttribution`에 `<script>` 시도 | 텍스트 렌더 | next-intl 자동 escape — 텍스트로만 노출 | P0 |
| LN-SEC-04 | CSP 통과 | 페이지 로드 | 콘솔 에러 검사 | CSP 위반 없음 (외부 리소스 미사용 — 외부 도메인은 Link만) | P1 |
| LN-SEC-05 | 직접 접근 인증 불필요 | 비로그인 진입 | 페이지 접근 | 정상 노출 (인증 미필요) | P1 |
| LN-SEC-06 | SEO 인덱스 정책 | meta robots | meta 태그 | 라이선스 페이지는 인덱스 허용 (검색엔진이 attribution 가시성 보장) | P2 |

---

## 5. 크로스 페이지 플로우 (E2E)

| # | 플로우명 | 관련 페이지 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-----------|---------|---------|---------|
| LN-CF-01 | (권고) 푸터 → legal/notices | layout footer → /legal/notices | 메인에서 푸터 "Licenses" 클릭 | `/legal/notices` 정상 진입 (유형 C #4 layout 적용 후) | P0 |
| LN-CF-02 | legal/notices → CC BY-SA 4.0 | /legal/notices → external | CC BY-SA 링크 클릭 | 새 탭에서 creativecommons.org 열림 | P0 |
| LN-CF-03 | legal/notices → geoip-lite GitHub | /legal/notices → external | geoip-lite 링크 클릭 | 새 탭에서 github.com 열림 | P0 |
| LN-CF-04 | legal/notices → 메인 | /legal/notices → / | "← Home" 클릭 | `/` 정상 진입 | P0 |
| LN-CF-05 | 직접 URL 진입 | 외부 → /legal/notices | 사용자가 즐겨찾기 또는 외부 링크 클릭 | 정상 렌더 | P1 |

---

## 6. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | as-built 신규 페이지(`/legal/notices`, 커밋 `bd5d4ce`) + 감사 문서(`2026-04-15-geolite2-attribution-relocation.md`) 결론 기반 신규 시나리오 작성. 렌더링(LN-R-01~15) / i18n(LN-I-01~04) / 인터랙션(LN-A-01~05) / 접근성(LN-AC-01~05) / **§3 라이선스 준수 검증(LN-LIC-01~08)** / **§4 보안(LN-SEC-01~06 — reverse tabnabbing/CSP/XSS)** / 크로스 플로우(LN-CF-01~05). CC BY-SA 4.0 §3(a)(2), GeoLite EULA §3/§6.3, Apache TC-61 선례 준용. 푸터 "Licenses" 링크 layout 적용 미완료(LN-LIC-07/LN-CF-01) HIGH 표기 | 명우현 |
