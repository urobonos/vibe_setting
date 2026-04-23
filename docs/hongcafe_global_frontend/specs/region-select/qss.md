# QA Scenario Sheet — Region Select

> Source: ffs.md v1.0 + as-built 코드(`app/[locale]/region-select/page.js`) + 감사 문서(`2026-04-15-geoip-country-routing-scenario-matrix.md`)
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR은 fallback 옵션으로만 노출

---

## 1. 테스트 환경

| 항목 | 값 |
|------|-----|
| 뷰포트 | 390×844 |
| 로케일/호스트 | EN: `en.hongcafe.com/region-select` / JP: `jp.hongcafe.com/region-select` |
| 베이스 URL (개발) | `http://en.localhost:3000/region-select`, `http://jp.localhost:3000/region-select` |
| 테스트 도구 | Playwright + (`__tests__/lib/geoip.test.js` 의존) |
| 빌드 검증 | `npm run build` + `npm run test` PASS |

---

## 2. Region Select 페이지 (`/[locale]/region-select`)

### 2-1. 렌더링 테스트 (as-built)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| RS-R-01 | EN 호스트 정상 로딩 | 없음 | `en.localhost:3000/region-select` 접근 | HTTP 200, 페이지 정상 렌더 | P0 |
| RS-R-02 | JP 호스트 정상 로딩 | 없음 | `jp.localhost:3000/region-select` 접근 | HTTP 200, 일본어 라벨 | P0 |
| RS-R-03 | 페이지 제목 | 없음 | h1 확인 | "Select Your Region" — text-[2.4rem] font-bold text-[#333333] mb-[2rem] | P0 |
| RS-R-04 | 설명 문구 | 없음 | p 확인 | "Choose the region that best matches your location" — text-[1.4rem] text-[#888888] mb-[3rem] | P1 |
| RS-R-05 | 옵션 컨테이너 | 없음 | div 확인 | `flex flex-col gap-[1.2rem]` — 3 옵션 세로 배치 | P0 |
| RS-R-06 | Japan 옵션 | 없음 | 첫 번째 Link | h-[5rem] rounded-[0.8rem] bg-[#f5f5f5] text-[1.6rem] font-medium text-[#333333] + "Japan" | P0 |
| RS-R-07 | English 옵션 | 없음 | 두 번째 Link | 동일 스타일 + "English" | P0 |
| RS-R-08 | Korea 옵션 | 없음 | 세 번째 Link | 동일 스타일 + "Korea" — ※ 본 프로젝트 범위 밖 (유형 D #5) | P1 |
| RS-R-09 | 컨테이너 padding | 없음 | div 검사 | `px-[2rem] pt-[4rem]` (디자인 미적용 임시 스타일 — 유형 D #4) | P2 |
| RS-R-10 | 옵션 순서 | 없음 | DOM 순서 | Japan → English → Korea (위→아래) | P1 |
| RS-R-11 | 메타데이터 title | 없음 | `document.title` | "Select Your Region — HONG CAFE" 또는 i18n 번역 | P1 |

### 2-2. i18n 테스트 (hostname 기반)

| # | 시나리오 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| RS-I-01 | EN 호스트 | `en.hongcafe.com/region-select` | regionSelect 네임스페이스 영어 (Select Your Region / Japan / English / Korea) | P0 |
| RS-I-02 | JP 호스트 | `jp.hongcafe.com/region-select` | regionSelect 네임스페이스 일본어 | P0 |
| RS-I-03 | KR 호스트 | `hongcafe.com/region-select` | 본 프로젝트 범위 밖 (홍카페K) | P2 |
| RS-I-04 | 옵션 라벨 일관성 | EN/JP 각각 확인 | "Japan"/"English"/"Korea"가 호스트별로 적절히 번역 (유형 C #6 — 지역명 vs 언어명 정책) | P2 |

### 2-3. 인터랙션 테스트 (as-built)

| # | 시나리오 | 사전조건 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|---------|
| RS-A-01 | Japan 클릭 (현재) | 없음 | Japan 버튼 클릭 | `<Link href="/">` — 현재 hostname 그대로 / 메인 이동 (유형 C #1 미구현) | P1 |
| RS-A-02 | English 클릭 (현재) | 없음 | English 버튼 클릭 | 동일 — `/` | P1 |
| RS-A-03 | Korea 클릭 (현재) | 없음 | Korea 버튼 클릭 | 동일 — `/` | P1 |
| RS-A-04 | (권고) Japan 클릭 → JP hostname 전환 | 유형 C #1 구현 후 | Japan 클릭 | `hc_country=JP` 쿠키 강제 갱신 + `https://jp.hongcafe.com`으로 리다이렉트 | P0 |
| RS-A-05 | (권고) English 클릭 → EN hostname | 유형 C #1 구현 후 | English 클릭 | `hc_country=US` + `https://en.hongcafe.com` | P0 |
| RS-A-06 | (권고) Korea 클릭 → 홍카페K | 유형 C #1 구현 후 | Korea 클릭 | (a) 외부 리다이렉트 `https://hongcafe.com` / (b) 모달 안내 (유형 D #5 결정 필요) | P0 |
| RS-A-07 | (권고) 동일 옵션 재선택 | 이미 JP 호스트 상태에서 Japan 클릭 | Japan 클릭 | hostname 변경 없이 메인으로 이동 | P2 |

### 2-4. 접근성 테스트

| # | 시나리오 | 검증 항목 | 기대 결과 | 우선순위 |
|---|---------|---------|---------|---------|
| RS-AC-01 | 옵션 키보드 Tab | Tab 순차 이동 | Japan → English → Korea 순서 포커스 | P1 |
| RS-AC-02 | Enter 키 활성화 | 옵션에 포커스 후 Enter | Link 활성화 — 페이지 이동 | P1 |
| RS-AC-03 | 시맨틱 마크업 | h1 사용 | `<h1>` 태그로 페이지 제목 명시 | P1 |
| RS-AC-04 | Link role | DOM 검사 | `<a href="/">` (next/link 렌더 결과) | P1 |
| RS-AC-05 | 색상 대비 | text-[#333333] on bg-[#f5f5f5] | WCAG AA 통과 | P2 |

---

## 3. 보안 검증 시나리오

| # | 시나리오 | 사전조건/입력값 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|--------------|----------|----------|---------|
| RS-SEC-01 | 옵션 클릭 시 외부 도메인 안전성 | (유형 C #1 구현 후) Korea 클릭 | network 캡처 | `https://hongcafe.com`만 허용 — 임의 호스트 redirect 불가 (server-side allowlist) | P0 |
| RS-SEC-02 | hc_country 쿠키 설정 정책 | (유형 C #1 구현 후) | 쿠키 검사 | production: `__Host-hc_country`, dev: `hc_country` + httpOnly + secure(prod) + sameSite=lax + 24h TTL | P0 |
| RS-SEC-03 | XSS via i18n 키 | i18n 메시지에 `<script>` 시도 | 텍스트 렌더 검사 | next-intl 자동 escape — 텍스트로만 노출 | P0 |
| RS-SEC-04 | 직접 접근 인증 불필요 | 비로그인 진입 | `/region-select` 접근 | 정상 렌더 (인증 미필요 페이지) | P1 |
| RS-SEC-05 | CSP 통과 | 페이지 로드 | 콘솔 에러 검사 | CSP 위반 없음 (외부 리소스 미사용) | P2 |

---

## 4. 크로스 페이지 플로우 (E2E)

| # | 플로우명 | 관련 페이지 | 실행 단계 | 기대 결과 | 우선순위 |
|---|---------|-----------|---------|---------|---------|
| RS-CF-01 | (권고) GeoIP 실패 → 자동 안내 → region-select | proxy.js → main → region-select | 알 수 없는 IP로 진입 → 메인에 안내 모달 → "Choose your region" 클릭 | `/region-select` 진입 (유형 C #3 미구현) | P0 |
| RS-CF-02 | (권고) JP 사용자가 EN 사이트 진입 후 수동 변경 | main → region-select → main(JP) | EN 호스트에서 region-select 진입 → Japan 선택 → JP 호스트 메인 | hostname 전환 + 한국어 콘텐츠 | P0 |
| RS-CF-03 | (권고) 모달 안내 후 KR 외부 리다이렉트 | region-select → 외부 | Korea 선택 | "홍카페K로 이동합니다" 모달 → 확인 → `https://hongcafe.com` (유형 D #5) | P1 |
| RS-CF-04 | 직접 URL 진입 | 외부 → region-select | 사용자가 즐겨찾기로 저장한 `/region-select` 링크 클릭 | 정상 렌더 | P2 |

---

## 5. 단위 테스트 게이트 (Vitest, 신설 권고)

| # | 시나리오 | 대상 파일 | 검증 |
|---|---------|----------|------|
| UT-RS-01 | (유형 C #1 구현 후) 옵션 매핑 | (신설) `lib/region.js` | Japan→`{country:'JP', host:'jp.hongcafe.com'}`, English→`{country:'US', host:'en.hongcafe.com'}`, Korea→`{country:'KR', host:'hongcafe.com'}` |
| UT-RS-02 | (유형 C #1 구현 후) hostname allowlist | (신설) `lib/region.js` | allowlist 외 호스트 입력 시 reject |
| UT-RS-03 | (유형 C #1 구현 후) 쿠키 강제 갱신 | Server Action | `cookies().set('hc_country', code, { ... })` |

---

## 6. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | as-built 스캐폴드 신규 시나리오 작성: 렌더링(RS-R-01~11), i18n(RS-I-01~04 hostname 기반), 인터랙션(RS-A-01~07 — 현재 미구현 + 권고 분기), 접근성(RS-AC-01~05), 보안(RS-SEC-01~05 — KR 외부 리다이렉트 allowlist/CSP), 크로스 플로우(RS-CF-01~04 — GeoIP 실패 fallback 진입), 단위 테스트(UT-RS-01~03 신설 권고). 유형 C/D 미구현 항목 시나리오에서 "권고" 표기로 분리 | 명우현 |
