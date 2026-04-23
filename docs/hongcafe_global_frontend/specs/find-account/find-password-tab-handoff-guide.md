# Find Password 탭 — 파이프라인 진입 가이드

| 항목 | 내용 |
|------|------|
| 작성자 | 명우현 |
| 작성일 | 2026-04-17 |
| 상태 | Pending — Figma 핸드오프 대기 중 |
| 선행 문서 | `docs/specs/member-api.md` (캐노니컬), `docs/audits/2026-04-17-member-api-v2-integration-update-plan.md` |
| 관련 FFS | `docs/specs/find-account/ffs.md` |

> 본 문서는 Phase C 진입 시 `project-orchestrator` + `frontend-developer`가 1차로 읽어야 하는 가이드다.
> Figma node-id가 도착하면 `develop:` + URL로 정규 파이프라인을 실행한다.

---

## 1. 현재 상태

### 1.1 UI
- 탭 컨테이너: `app/[locale]/find-account/_components/FindAccountForm.js:223-234` ("Find Password" 버튼만 존재)
- 탭 패널: 동일 파일 L377-381 — `<p>{labels.findPasswordTodo}</p>` placeholder 1줄만
- 활성화 조건: `activeTab === 'findPassword'`

### 1.2 백엔드 EP (사용 가능)
| # | Method | URL | 용도 |
|---|--------|-----|------|
| 10 | POST | `/api/members/find-password-cert` | 임시 비밀번호 발급 (KR=알림톡, 해외=이메일). HTTP 204. |
| 12 | POST | `/api/members/reset-password` | 임시 비밀번호로 로그인 후 신규 비밀번호 재설정. HTTP 200 `[]`. |

### 1.3 프론트 자산
- 프록시 라우트: `app/api/members/find-password-cert/route.js`, `app/api/members/reset-password/route.js` (모두 `createApiHandler` 적용 완료)
- 클라이언트 헬퍼: `secureFetch`(`@/lib/fetchWithAuth`) 사용
- reCAPTCHA 헬퍼: `@/components/ReCaptchaEnterprise` (action 네이밍: `find_password` 권장)

---

## 2. EP #10 `find-password-cert` 정확 명세

```
POST /api/members/find-password-cert
인증: 불필요 (CSRF 면제)

Request Body:
  acCountry  string  Y  국가 코드 (US | JP | KR)
  crPhone    string  Y  등록된 전화번호 (numeric)
  acId       string  Y  이메일

Success: HTTP 204 (본문 없음)
  → 임시 비밀번호가 SMS(KR=알림톡) 또는 이메일(해외)로 발송됨

Error:
  400 INVALID_INPUT  필수 파라미터 누락
  403 FORBIDDEN      비정상 계정 (acStatus != 2)
  404 NOT_FOUND      이메일+전화번호 일치 계정 없음
  500 INTERNAL       발송 실패
```

### 호출 예시 (구현 참고)
```js
const data = await secureFetch('/api/members/find-password-cert', {
    method: 'POST',
    body: JSON.stringify({
        acCountry: 'US',
        crPhone: phoneNumber,
        acId: email,
    }),
});
// 204 응답은 errorMapper에서 { response: 'success', data: {} } 로 정규화됨
if (data && data.response === 'success') {
    // 임시 비밀번호 발송 안내 모달 표시
}
```

---

## 3. EP #12 `reset-password` 정확 명세

```
POST /api/members/reset-password
인증: 불필요 (CSRF 면제)

Request Body:
  acId           string  Y  이메일
  newPassword    string  Y  새 비밀번호 (8~128자, 2종 이상 조합 필수)
  newPasswordRe  string  Y  새 비밀번호 재입력 (matches[newPassword])

Password 검증 정규식 (4개 중 1개 이상 매칭 시 통과):
  ^.*(?=^.{8,128}$)(?=.*\d)(?=.*[a-zA-Z]).*$
  ^.*(?=^.{8,128}$)(?=.*\d)(?=.*[!@#$%^&+=]).*$
  ^.*(?=^.{8,128}$)(?=.*[a-zA-Z])(?=.*[!@#$%^&+=]).*$
  ^.*(?=^.{8,128}$)(?=.*\d)(?=.*[a-zA-Z])(?=.*[!@#$%^&+=]).*$
특수문자 허용 범위: !@#$%^&+=

Success: HTTP 200 []

Error:
  400 INVALID_INPUT  입력 검증 실패
  401 UNAUTHORIZED   계정 확인 실패
  500 INTERNAL       비밀번호 변경 실패
```

> **중요**: 명세상 reset-password는 인증 불필요지만, 백엔드 의도는 "임시 비밀번호로 로그인 후" 호출. 즉 `acId`만으로는 무한히 비밀번호 재설정이 가능해 보이나, 실제로는 임시 비밀번호 발급 흐름을 거친 사용자만 acId를 알고 있는 시나리오를 가정. **프론트 보안 설계 시점에 백엔드와 재확인 필요** (rate-limit 의존 여부).

---

## 4. UI 구성 권고 (Figma 도착 전 임시 가이드)

### 4.1 옵션 A — 단계 분리 (권장 기본)
1. Step 1 (현재 탭 내부): 국가 선택 + 전화번호 입력 + 이메일 입력 + reCAPTCHA + "임시 비밀번호 받기" 버튼 → EP #10 호출 → 성공 시 안내 모달 ("등록된 이메일/SMS로 임시 비밀번호를 발송했습니다") + "신규 비밀번호 설정하기" CTA
2. Step 2 (별도 페이지 또는 모달 인라인): 이메일(readOnly) + 신규 비밀번호 + 신규 비밀번호 확인 → EP #12 호출 → 성공 시 로그인 페이지 리다이렉트

### 4.2 옵션 B — 단일 탭 인라인 모달
- 발송 성공 후 동일 화면에서 모달로 신규 비밀번호 입력. **단점**: 임시 비밀번호 수신 후 다시 진입하는 사용자 경로가 끊김 (별도 진입점 필요).

### 4.3 결정 항목 (Figma 도착 시 확정)
- [ ] Step 2 진입 경로 (별도 라우트 `/find-account/reset` vs 모달)
- [ ] 임시 비밀번호 입력 단계 존재 여부 (현재 명세는 acId만 받으므로 명시적 입력 단계 불필요)
- [ ] 비밀번호 강도 게이지 표시 여부

---

## 5. i18n 신규 키 (Figma 텍스트 확정 후 추가)

`messages/{en,ja,ko}.json` `findAccount` 네임스페이스에 추가 필요한 후보:

```json
{
    "findPasswordEmailLabel": "...",
    "findPasswordEmailPlaceholder": "...",
    "findPasswordSubmitBtn": "...",
    "findPasswordSentNotice": "...",
    "findPasswordResetTitle": "...",
    "newPasswordLabel": "...",
    "newPasswordPlaceholder": "...",
    "newPasswordConfirmLabel": "...",
    "newPasswordConfirmPlaceholder": "...",
    "errPasswordWeak": "...",
    "errPasswordMismatch": "...",
    "errAccountNotFound": "...",
    "errSendFailed": "..."
}
```

> 기존 `findPasswordTodo` 키는 탭 구현 완료 시 제거.

---

## 6. 회귀 영향 범위

- `FindAccountForm.js` 단일 파일 + 신규 `FindPasswordPanel.js`(또는 분리) + 신규 라우트(옵션 A 채택 시 `/find-account/reset`)
- 약관 모달 영향 없음 (Find Password는 동의 단계 없음)
- 기존 Find ID 탭 동작에 영향 없음 (탭 분기 로직 동일)

---

## 7. 파이프라인 진입 체크리스트

- [ ] Figma URL + node-id 수신 (사용자 제공)
- [ ] `develop: <Figma URL>` 명령으로 `project-orchestrator` 자동 소환
- [ ] Phase 1 design-normalizer: `app/[locale]/find-account/_components/` 하위에 SDD 추출
- [ ] Phase 1.5 Build Spec: 본 문서의 §2~§4를 참조하여 `OAUTH_DATA` 마커 불요, `INPUT_CHILDREN` 마커 사용
- [ ] Phase 2 publisher: 신규 컴포넌트 생성 + i18n 키 추가 + 라우트 추가(옵션 A)
- [ ] Phase 2-B qa-engineer: EP #10/#12 mock 기반 functional test
- [ ] Phase 2.5 static_audit: §22-50 readOnly 무근거 추가 금지 (이메일 필드는 Step 2에서만 readOnly)
- [ ] Phase 3 Visual Regression
- [ ] Phase 4 FINAL_REPORT
