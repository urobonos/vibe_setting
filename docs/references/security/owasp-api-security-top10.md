# OWASP API Security Top 10 — 2023

> **출처:** https://owasp.org/API-Security/editions/2023/en/0x11-t10/
> **갱신일:** 2026-04-09

---

## 요약표

| ID | 항목 | 핵심 위험 |
|----|------|-----------|
| API1 | Broken Object Level Authorization | 객체 ID 조작으로 미인가 데이터 접근 |
| API2 | Broken Authentication | 인증 우회/토큰 손상으로 계정 탈취 |
| API3 | Broken Object Property Level Authorization | 속성 수준 접근 제어 부재, Mass Assignment |
| API4 | Unrestricted Resource Consumption | 리소스 제한 없어 DoS/비용 폭증 |
| API5 | Broken Function Level Authorization | 관리자 함수 접근 제어 부재 |
| API6 | Unrestricted Access to Sensitive Business Flows | 비즈니스 흐름 자동화 악용 (scalping 등) |
| API7 | Server Side Request Forgery (SSRF) | 내부 서비스 접근 유도 |
| API8 | Security Misconfiguration | 보안 설정 오류/누락 |
| API9 | Improper Inventory Management | API 자산 관리 부실 |
| API10 | Unsafe Consumption of APIs | 제3자 API 데이터 과신 |

---

## API1:2023 — Broken Object Level Authorization (BOLA)

### 설명
API가 객체 수준 접근 제어를 검증하지 못할 때 발생. 공격자는 요청 내 객체 ID(순차적 정수, UUID, 문자열)를 조작하여 미인가 데이터에 접근한다.

### 공격 시나리오
1. **전자상거래:** `/shops/{shopName}/revenue_data.json` 패턴 노출 → 전체 스토어 매출 데이터 접근
2. **차량 제어 API:** VIN 소유권 미검증 → 타인 차량 엔진 시작/도어 잠금 제어
3. **문서 서비스 GraphQL:** 권한 확인 없이 ID만으로 타인 문서 삭제

### 예방
- 모든 객체 접근 시 로그인 사용자의 접근 권한 검증
- GUID 같은 예측 불가능한 값을 레코드 ID로 사용
- Authorization 테스트 작성 및 실패 시 배포 차단

---

## API2:2023 — Broken Authentication

### 설명
인증 메커니즘이 모든 사용자에게 노출되어 공격 대상이 됨. 잘못 구현 시 토큰 손상, 계정 탈취로 이어짐.

### 취약 조건
- Credential stuffing/brute force 허용 (captcha/lockout 없음)
- 약한 비밀번호 허용
- URL에 토큰/비밀번호 전송
- 비밀번호 확인 없이 이메일/비밀번호 변경 허용
- `{"alg":"none"}` JWT 수용, 만료 미검증
- 평문/약한 해시 비밀번호

### 공격 시나리오
1. **GraphQL Batching:** 분당 3회 제한을 단일 요청에 수백 개 mutation 배치로 우회
2. **이메일 변경:** 비밀번호 확인 없이 `PUT /account {email: "attacker@..."}` → 비밀번호 리셋으로 계정 탈취

### 예방
- MFA 구현
- Anti-brute force (rate limiting, captcha, account lockout)
- 민감 작업(이메일 변경 등) 시 재인증 요구
- API key는 사용자 인증이 아닌 클라이언트 인증에만 사용

---

## API3:2023 — Broken Object Property Level Authorization

### 설명
객체 속성 수준의 접근 제어 부족. 인증된 사용자가 접근 불가한 속성을 읽거나 수정할 수 있음.

### 공격 시나리오
1. **정보 노출:** 데이팅 앱 신고 시 `fullName`, `recentLocation` 등 민감 정보 응답에 포함
2. **Mass Assignment:** 마켓플레이스 예약 승인 시 `total_stay_price` 필드 삽입하여 가격 변조
3. **상태 우회:** 비디오 설명 수정 시 `blocked: false` 추가하여 차단 해제

### 예방
- `to_json()`, `to_string()` 등 범용 메서드 사용 회피
- 클라이언트가 수정 가능한 속성만 명시적 허용 (allowlist)
- Schema 기반 응답 검증으로 반환 데이터 최소화

---

## API4:2023 — Unrestricted Resource Consumption

### 설명
API가 클라이언트 상호작용/리소스 소비를 제한하지 않을 때 발생. 실행 시간, 메모리, 파일 크기, 레코드 수 등의 제한 부재.

### 공격 시나리오
1. **SMS 비용 악용:** forgot password API 수만 회 호출 → $0.05/건 × 수만 건 = 수천 달러 손실
2. **GraphQL 배치:** 단일 요청에 수백 개 이미지 업로드 → 서버 메모리 고갈
3. **클라우드 비용:** 파일 크기 증가 → 전체 클라이언트 재다운로드 → 월 $13 → $8,000

### 예방
- Rate limiting (시간당/분당 요청 수 제한)
- 입력 매개변수 최대 크기 정의 (문자열, 배열, 파일)
- 컨테이너/Serverless로 메모리, CPU, 프로세스 수 제한
- 서비스 제공자 지출 한도/청구 알림 설정

---

## API5:2023 — Broken Function Level Authorization

### 설명
함수 수준 인증 부재로 공격자가 관리자 기능에 접근. 복잡한 접근 제어 정책에서 흔히 발생.

### 공격 시나리오
1. **초대 시스템:** `GET /api/invites/{guid}` 조사 후 `POST /api/invites/new` 관리자 엔드포인트 발견 → 관리자 계정 생성
2. **Admin API:** `GET /api/admin/v1/users/all`에 인증 검사 부재 → 일반 사용자가 전체 사용자 목록 접근

### 예방
- **Deny all by default** 원칙
- 모든 관리 컨트롤러에서 역할/그룹 기반 인증 검사
- API 엔드포인트를 비즈니스 로직과 함께 리뷰

---

## API6:2023 — Unrestricted Access to Sensitive Business Flows

### 설명
민감한 비즈니스 흐름(구매, 예약, 댓글)을 자동화로 악용. 기술적 취약점이 아닌 비즈니스 로직 악용.

### 공격 시나리오
1. **Scalping:** 게임 콘솔 출시일 자동화 대량 구매 → 재판매
2. **항공 티켓:** 전체 좌석 90% 예약 → 가격 인하 후 취소/재구매
3. **Referral 악용:** 스크립트로 자동 가입 → 리퍼럴 크레딧 수천 개 적립

### 예방
- 과도한 사용이 위험한 비즈니스 흐름 식별
- Device fingerprinting (헤드리스 브라우저 탐지)
- CAPTCHA / 생체 인증
- 비정상 패턴 분석 (봇 vs 사람)
- Tor/프록시 IP 차단

---

## API7:2023 — Server Side Request Forgery (SSRF)

### 설명
사용자 제공 URL을 검증 없이 서버에서 fetch할 때 발생. 방화벽/VPN 뒤 내부 서비스에 접근 유도.

### 공격 시나리오
1. **프로필 사진 URL:** `{"picture_url": "localhost:8080"}` → 응답 시간으로 내부 포트 스캐닝
2. **Webhook:** `http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-default-ssm` → AWS 자격증명 탈취

### 예방
- 리소스 fetching을 내부 네트워크에서 격리
- Allow list: 허용 도메인, URL scheme, port 명시
- HTTP 리다이렉션 비활성화
- 원본 응답을 클라이언트에 직접 전송하지 않음

---

## API8:2023 — Security Misconfiguration

### 설명
API 스택 전체 수준(네트워크~애플리케이션)에서 보안 설정 오류 또는 누락.

### 공격 시나리오
1. **JNDI Lookup:** 로깅 유틸리티 기본 설정으로 원격 코드 실행 (Log4Shell 유형)
2. **Cache-Control 누락:** 개인 메시지가 브라우저 캐시에 저장 → 파일시스템에서 검색 가능

### 예방
- 모든 API 통신 TLS 필수
- 불필요한 HTTP verb 비활성화
- 적절한 CORS 정책 및 Security Headers 설정
- 요청 Content-Type 제한
- 에러 응답 스키마 정의 (스택 트레이스 노출 방지)

---

## API9:2023 — Improper Inventory Management

### 설명
API 자산(호스트, 버전, 엔드포인트)에 대한 가시성 부족. 구형 버전, beta API에 보안 미적용.

### 공격 시나리오
1. **Beta API:** 공식 API에만 rate-limiting 적용, beta 호스트 미적용 → 6자리 토큰 brute force로 비밀번호 리셋
2. **Third-party 유출:** 27만 명 동의로 5천만 명 정보 탈취 (데이터 흐름 미모니터링)

### 예방
- 모든 API 호스트, 환경(prod/staging/test), 버전 문서화
- 통합 서비스/데이터 흐름 inventory 및 민감도 평가
- CI/CD 파이프라인에 자동 API 문서화 포함
- 구형 API 버전 보안 역이식(backport) 검토

---

## API10:2023 — Unsafe Consumption of APIs

### 설명
제3자 API 데이터를 사용자 입력보다 더 신뢰하여 보안 기준 약화. transport security, input validation 등이 느슨해짐.

### 공격 시나리오
1. **SQLi via Third-Party:** 제3자 서비스에 SQLi payload 저장 → API가 검증 없이 DB 저장 → 데이터 유출
2. **Blind Redirect:** 제3자 API 손상 → 308 리다이렉트 → 의료 정보가 공격자 서버로 전송
3. **Repository Name Injection:** `'; drop db;--` 저장소명 → "safe input"으로 간주되어 SQLi 실행

### 예방
- 제3자 API 보안 평가 수행
- 모든 API 상호작용 TLS 필수
- 수신 데이터 항상 검증/sanitize 후 사용
- 리다이렉트 allowlist 설정, blindly follow 금지
