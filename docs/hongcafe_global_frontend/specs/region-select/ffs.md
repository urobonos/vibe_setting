# Frontend Functional Spec — Region Select (수동 지역 선택)

> Source: as-built 코드(`app/[locale]/region-select/page.js`) + 감사 문서(`2026-04-15-geoip-country-routing-scenario-matrix.md`)
> Status: Draft (v1.0)
> Updated: 2026-04-17
> 범위: EN(en.hongcafe.com) / JP(jp.hongcafe.com) — KR은 fallback 옵션으로만 노출

---

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | Region Select (지역 수동 선택) |
| 사용자 목표 | GeoIP 자동 라우팅 결과가 부정확한 경우(VPN/봇/실패) 사용자가 수동으로 지역을 선택해 적절한 hostname/locale로 진입한다 |
| 퍼블리싱 상태 | **스캐폴드만 구현** — 라우트 + 3 옵션 링크 (Japan / English / Korea), 디자인 미적용 |
| 기능 연동 상태 | **미연동** — 현재 모든 옵션이 `/`로 동일 link, 실제 hostname 전환 로직 없음 |
| i18n 네임스페이스 | `regionSelect` |
| 지원 로케일 | `en`, `ja` |
| 뷰포트 기준 | 모바일 390x844 |

### 비즈니스 가치

- **GeoIP 한계 보완**: VPN/프록시/봇/lookup 실패 시 사용자가 직접 지역을 선택해 정확한 도메인으로 이동.
- **사용자 자율성**: 자동 매핑이 마음에 들지 않는 사용자가 수동으로 변경 가능 (예: 일본 거주 한국인이 EN 사이트 진입 후 JP 도메인 선택).
- **GeoIP 매트릭스 권고**: 감사 문서 §3-4 — VPN/proxy 사용자, EU/CN/RU 등 매핑 미정의 지역 사용자에게 fallback UX 제공.

### 도메인 흐름

```
진입점 (잠재적):
  ├── intro/login/main 헤더에 "Region" 링크 (미구현 — §6 미확정 #2)
  ├── GeoIP 실패 안내 후 "Choose your region" CTA (미구현 — §6 미확정 #3)
  └── 직접 URL 입력 (`/region-select`)
       ↓
/region-select 페이지
  ├── h1 "Select Your Region"
  ├── description "Choose the region that best matches your location"
  └── 3 옵션 (Japan / English / Korea)
       ↓
각 옵션 클릭 시 (현재 모두 `/`로 이동 — 유형 C 미구현)
  └── 향후: 선택 → hc_country 쿠키 강제 갱신 + 해당 hostname 리다이렉트
       ├── Japan → jp.hongcafe.com
       ├── English → en.hongcafe.com
       └── Korea → hongcafe.com (홍카페K, 본 프로젝트 범위 밖)
```

---

## 2. 라우트 구조

| 라우트 | 파일 경로 | 컴포넌트 | 타입 | i18n 네임스페이스 |
|--------|----------|---------|------|-----------------|
| `/[locale]/region-select` | `app/[locale]/region-select/page.js` | RegionSelectPage (Server) | Server only — 정적 렌더 | `regionSelect` |

> 현재 단일 Server Component (Client 인터랙션 없음 — Link 기반).

---

## 3. 페이지 정의

### 3-1. Region Select 홈

| 항목 | 내용 |
|------|------|
| 라우트 | `/[locale]/region-select` |
| Server Component | `app/[locale]/region-select/page.js` |
| Client Component | (없음 — Server에서 Link만 렌더) |
| 화면설계서 | (없음 — as-built 신규) |

#### UI 섹션 (위→아래, as-built)

| # | 섹션 | 설명 |
|---|------|------|
| 1 | 컨테이너 | `<div className="px-[2rem] pt-[4rem]">` (디자인 미적용 — 임시 스캐폴드) |
| 2 | 제목 | `<h1 className="text-[2.4rem] font-bold text-[#333333] mb-[2rem]">` — `regionSelect.title` ("Select Your Region") |
| 3 | 설명 | `<p className="text-[1.4rem] text-[#888888] mb-[3rem]">` — `regionSelect.description` |
| 4 | 옵션 컨테이너 | `<div className="flex flex-col gap-[1.2rem]">` |
| 5 | Japan 옵션 | `<Link href="/" className="h-[5rem] rounded-[0.8rem] bg-[#f5f5f5] text-[1.6rem] font-medium text-[#333333]">` — `regionSelect.japan` |
| 6 | English 옵션 | 동일 스타일 — `regionSelect.english` |
| 7 | Korea 옵션 | 동일 스타일 — `regionSelect.korea` (※ KR은 본 프로젝트 범위 밖, 홍카페K로 안내 필요) |

> **유형 D — 디자인 미확정**: as-built는 디자인 적용 전 임시 스타일. 정식 화면설계서 추가 + Figma 시안 발급 후 §Phase 1 design-normalizer 재실행 필요.

#### 상태 관리

- 없음 (정적 페이지).

#### API 연동

- 없음 (옵션 클릭 시 `<Link href="/">`로 hostname 전환만 — 실제 쿠키 갱신/리다이렉트 미구현).

#### 인터랙션 (as-built)

| 액션 | 동작 |
|------|------|
| Japan 클릭 | `<Link href="/">` — 현재 hostname 그대로 / 미동작 (유형 C #1) |
| English 클릭 | 동일 |
| Korea 클릭 | 동일 |

> **유형 C — 미구현**: 향후 옵션 클릭 시 `hc_country` 쿠키 강제 설정(JP/US/KR) + 해당 hostname으로 리다이렉트(`window.location.replace('https://jp.hongcafe.com')`) 필요. Server에서 cookies() 설정 후 redirect()로 처리하는 게 안전.

#### 비즈니스 규칙

| 규칙 | 설명 |
|------|------|
| KR 옵션 노출 정책 | as-built는 3 옵션 모두 노출. KR 사용자는 홍카페K(`hongcafe.com`)로 안내 — 현재 본 프로젝트는 EN/JP만 호스팅 |
| GeoIP 우회 권한 | 사용자 수동 선택은 GeoIP 결과보다 우선 — `hc_country` 쿠키 강제 갱신 + 24h TTL |
| 봇 처리 | 봇은 region-select 진입해도 GeoIP 쿠키 미설정 (proxy.js의 isBot 가드) |
| URL 정책 | locale prefix 미사용 (hostname 라우팅과 일관) — 현재 `/[locale]/region-select` 폴더 구조는 next-intl 내부용 |

#### 엣지 케이스

| 케이스 | 처리 (현재 / 권고) |
|--------|------------------|
| KR 옵션 선택 (EN/JP 호스트에서) | **현재**: `/`로 이동 (동일 호스트 메인). **권고**: `https://hongcafe.com` 외부 리다이렉트 + 사용자 안내 |
| 이미 선택된 옵션 재선택 | 동일 — `/`로 이동 (현재 hostname 유지) |
| JS 비활성 사용자 | `<Link>`는 `<a href>` 렌더링 — 동작 가능 |
| 봇 진입 | 페이지 정상 노출 (i18n 라우팅으로 locale 결정), 쿠키 미발급 |
| 직접 URL 진입 (cross-origin) | 정상 표시 — 인증 불필요 |

#### i18n (regionSelect 네임스페이스)

| 키 | en 값 | 용도 |
|----|------|------|
| `title` | Select Your Region | 페이지 제목 |
| `description` | Choose the region that best matches your location | 안내 문구 |
| `japan` | Japan | JP 옵션 라벨 |
| `english` | English | EN 옵션 라벨 |
| `korea` | Korea | KR 옵션 라벨 |

#### 의존성 (as-built)

| 의존성 | 용도 |
|--------|------|
| `next/link` | 옵션 Link |
| `next-intl/server` (`getTranslations`) | i18n 메시지 |

---

## 4. 도메인 내 공유 컴포넌트

| 컴포넌트 | 파일 경로 | 사용 페이지 | 비고 |
|---------|----------|-----------|------|
| (없음 — 단일 Server 페이지) | — | — | 향후 RegionOptionList Client 분리 검토 |

---

## 5. 크로스 도메인 의존성

| 의존 도메인 | 의존 방향 | 설명 |
|-----------|----------|------|
| intro | intro → region-select | GeoIP 실패 시 진입 (미구현) |
| (전역 layout) | layout → region-select | 헤더에 "Change region" 링크 (미구현) |
| `lib/geoip.js` (`COUNTRY_LOCALE_MAP`) | region-select → geoip | 옵션과 매핑 동기화 (JP/US/KR) |
| `proxy.js` middleware | region-select → proxy | hc_country 쿠키 강제 갱신 후 hostname 리다이렉트 |

---

## 6. 미확정 사항 (v1.0)

> 분류: **유형 A** = as-built 구현 완료 / **유형 B** = 감사 권고 미반영 / **유형 C** = 추가 구현 필요 / **유형 D** = 정책·디자인 확정 필요

| # | 우선순위 | 유형 | 항목 | 설명 | 근거 |
|---|---------|------|------|------|------|
| 1 | **[CRITICAL]** | C | 옵션 클릭 시 hostname 전환 + 쿠키 갱신 | 현재 모든 옵션이 `/`로만 이동. Server Action 또는 Client에서 `hc_country` 쿠키 강제 설정 + `window.location.replace(targetHostname)` 필요 | as-built 미구현 |
| 2 | **[HIGH]** | D | 진입점 정의 | 헤더/푸터/intro 어디서 region-select로 진입할지 — 디자인 확정 필요 | 디자인 |
| 3 | **[HIGH]** | C | GeoIP 실패 안내 + region-select CTA | proxy.js GeoIP `success=false` 시 메인 페이지에 "위치를 정확히 감지하지 못했습니다 — 직접 선택" 안내 | 감사 IP 시나리오 매트릭스 #4 |
| 4 | **[HIGH]** | D | 디자인 시안 | as-built는 임시 스타일. Figma 시안 발급 후 design-normalizer SDD 추출 → publisher 재실행 | 디자인 |
| 5 | **[HIGH]** | D | KR 옵션 정책 | (a) 옵션 노출 + 외부 hongcafe.com 리다이렉트 / (b) 옵션 제거 / (c) 옵션 노출하되 "홍카페K로 이동" 모달 안내 | 비즈니스 정책 |
| 6 | **[MEDIUM]** | C | 옵션 라벨 다국어 | "Japan/English/Korea" → JP 호스트에서는 "日本/英語/韓国" 등 지역명 일관성 검토 | i18n 카피 |
| 7 | **[MEDIUM]** | C | 추가 지역 확장 | EU(GDPR)/CN/SEA 등 추가 지역 진출 시 옵션 확장 + locale 추가 | 사업 확장 |
| 8 | **[MEDIUM]** | A | 정적 Server Component | Client 인터랙션 없이 Link만으로 동작 — Server fetch 없음 | as-built |
| 9 | **[LOW]** | C | 선택 후 안내 모달 | 호스트 전환 전 "JP 도메인으로 이동합니다" 모달 표시 | UX |
| 10 | **[LOW]** | C | 지역 깃발 아이콘 | 옵션에 국기 아이콘 추가 검토 (디자인 확정 시) | UX |

---

## 7. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | as-built 스캐폴드 코드(`app/[locale]/region-select/page.js`) 기준 신규 작성. 3 옵션(Japan/English/Korea)이 모두 `/`로 동일 link인 임시 상태 명시. 디자인 미적용/hostname 전환 로직 미구현/진입점 미정의 등 핵심 미확정 사항 10건 도출. 감사 문서(`2026-04-15-geoip-country-routing-scenario-matrix.md`) GeoIP 실패 fallback 권고 반영. KR 옵션 정책(범위 밖 도메인 안내) 결정 필요 표기 | 명우현 |
