---
name: api-test
description: >-
  HongCafe 백엔드 API 테스트 러너(tools/runner/runner.py) 실행 진입점. "api 테스트", "코인 테스트
  돌려줘", "smoke 돌려줘", "회원가입 코인 e2e", "공개 EP 테스트", "hongcafe api 호출 검증" 등 HongCafe
  API(dev/stg/prd)를 클로드가 사람 개입 없이 자동 호출해 검증하려 할 때 사용한다. "시나리오 돌려줘", "회원
  시나리오", "게시판/커머스/결제 시나리오" 도 트리거. 3모드 — smoke(공개 EP 4종, 즉시) / e2e(자동가입→코인,
  SSM 키) / scenario(ep.json 카탈로그 기반 다단계 시나리오: 가입→도메인, 값 전달·검증). 브라우저 도구
  tools/api-test.html 의 클로드 자동 실행 버전.
triggers:
  - "api 테스트"
  - "smoke 돌려줘"
  - "smoke 테스트"
  - "코인 테스트 돌려줘"
  - "회원가입 코인 e2e"
  - "공개 EP 테스트"
  - "hongcafe api 호출 검증"
  - "시나리오 돌려줘"
  - "회원 시나리오"
  - "게시판 시나리오"
  - "커머스 시나리오"
  - "결제 시나리오"
  - "/api-test"
user-invocable: true
version: 1.1.0
---

# api-test

HongCafe BE 의 API 테스트 러너 `C:\Works\hongcafe_global_backend\tools\runner\runner.py` 를 실행하는 진입점이다. 브라우저 도구 `tools/api-test.html`(사람이 클릭) 의 **클로드 자동 실행 버전**으로, 러너는 `tools/shared/js/hc-tools.js` 의 `callApi` 를 Python(표준 urllib + cryptography)으로 재현한다.

## 3 모드

| 모드 | 명령 | 키 | 동작 |
|------|------|-----|------|
| smoke | `python {RUNNER} smoke {env}` | 불요 | 공개 EP 4종(gate / whoami / products·coin / auth·refresh) 자동 호출 → PASS/FAIL |
| e2e | `python {RUNNER} e2e {env}` | `HC_ENC_KEY` 필요 | 자동가입(AES `data`) → JWT 쿠키 → coin-summary(join coin) → coin-transactions |
| scenario | `python {RUNNER} scenario {domain} {시나리오} {env}` | 시나리오별 | ep.json 카탈로그 기반 다단계 실행 (값 전달 `{var}`/`saves`, prelude 가입선행, 검증) |

- `{RUNNER}` = `C:\Works\hongcafe_global_backend\tools\runner\runner.py`
- `{env}` = `dev`(기본) · `stg` · `prd`. **prd e2e 는 러너가 차단**(계정 생성 사고 방지).
- 환경별 base = `https://{env}.gl.hongcafe.com`, prefix `/__hongcafe_api__`.

## smoke 실행 (즉시 / 안전)

키 불요·읽기 전용이므로 승인 없이 바로 실행한다.

```
python C:\Works\hongcafe_global_backend\tools\runner\runner.py smoke dev
```

PowerShell 도구가 EPERM(`uv_spawn`)으로 실패하면 Bash 도구로 동일하게 실행한다.

## e2e 실행 (dev 키 SSM 조회 + 주입)

e2e 자동가입은 dev 서버의 `encryption.key` 가 필요하다. **로컬 `.env` 키는 dev 와 불일치(`DECRYPT_FAILED`)** 하므로, SSM 으로 dev 서버 키를 조회해 `HC_ENC_KEY` 로 주입한다.

> **§3 — SSM 으로 dev EC2 접속이므로 매 실행 사용자 승인 1회.** 키 값은 셸 변수 내부에서만 처리하고 화면·로그·문서에 출력하지 않는다.

절차 (Bash 도구 권장 — PowerShell EPERM 회피):

```bash
IID=i-0183f9ab360cc9d80; REGION=us-east-1; ENV=dev
PF=/tmp/ssmk.json
echo '{"commands":["grep -m1 ^encryption.key /works/hongcafe-global/'"$ENV"'/config/be/.env"]}' > "$PF"
WPF=$(cygpath -m "$PF")          # Git Bash /tmp -> Windows aws.exe 경로 변환 (필수)
CMD_ID=$(aws ssm send-command --instance-ids $IID --region $REGION \
  --document-name AWS-RunShellScript --parameters "file://$WPF" \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id $IID --region $REGION 2>/dev/null || true
RAW=$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id $IID --region $REGION --query StandardOutputContent --output text)
KEYLINE=$(echo "$RAW" | grep '^encryption.key' | head -1)
VAL=$(echo "$KEYLINE" | cut -d= -f2- | sed 's/hex2bin://' | tr -cd '0-9a-fA-F')
echo "dev key loaded: length=${#VAL} (value hidden)"   # 값 미출력
export HC_ENC_KEY=$VAL
python C:/Works/hongcafe_global_backend/tools/runner/runner.py e2e $ENV
unset HC_ENC_KEY
```

기대 결과: 가입 200(쿠키 4종 hc_access/refresh/csrf/hdata) → whoami 200 → coin-summary `remainCoin` > 0 (가입 코인) → coin-transactions `category=join` 1건.

## scenario 실행 (ep.json 카탈로그)

도메인별 `scenarios/{domain}.ep.json` 에 EP 카탈로그 + 시나리오를 선언하면 러너가 step 을 순차 실행한다. **코드 수정 없이 ep.json 만으로 시나리오 추가 가능.**

```
python C:\Works\hongcafe_global_backend\tools\runner\runner.py scenario member signup-profile-coin dev
python C:\Works\hongcafe_global_backend\tools\runner\runner.py scenario board posting-read dev
```

- **도메인**: `member`(가입→프로필→코인) · `board`(게시글 read-drill) · `commerce`(조회) · `payment`(충전상품→수단). `scenario {domain}` 만 주면 사용 가능한 시나리오 목록 출력.
- **ep.json 구조**: `endpoints`(method/path/auth/payload/saves/headers) + `scenarios`(steps). `"extends":"member"` 로 가입 EP 재사용.
- **값 전달**: payload 의 `{var}` 는 `vars`(`@gen.email`/`nick`/`phone`) + step 응답 `saves`(dot 경로, 예 `data.crPhone`)로 치환. `headers` 의 `{uuidv4}` 자동 생성(멱등키).
- **prelude**: step 에 `{"prelude":"signup-login"}` → 가입+로그인 8 step 자동 선행(JWT 확보) 후 인증 EP 실행. JWT 는 쿠키 jar 로 자동 유지.
- **검증**: step 의 `expect`(상태코드) / `check`(응답 필드 dot 경로 값). 실패 시 체인 중단.
- **시나리오 추가**: `{domain}.ep.json` 의 `scenarios` 에 step 배열 추가. 또는 "X 시나리오 만들어줘" → 클로드가 ep.json EP 조합으로 작성.

검증됨(2026-06-23): member `signup-profile-coin` 12/12 · board `posting-read` 3/3 · payment `signup-readonly` 10/10. 일부 완결 step(commerce `item-detail`, payment `order-create`)은 dev 데이터·simple_pay 수단 사전등록 의존.

## Windows / SSM 함정 (SSOT)

- SSM document = **`AWS-RunShellScript`** (`AWS-RunShellCommand` 아님 — `InvalidDocument` 발생).
- **PowerShell 도구 EPERM(`uv_spawn`)** 빈발 → **Bash 도구로 전환**.
- Git Bash `/tmp` 경로는 Windows `aws.exe` 가 못 읽음 → **`cygpath -m`** 변환 후 `file://`.
- `.js` Write 는 `sensitive-file-guard` 차단(FE Read-only) — 러너가 Python 인 이유. `.py`/`.ps1` 은 허용.

## 제약

- 실제 코인 **충전(Stripe / PayPal / toss / naver_pay)은 외부 스크립트로 자동 완결 불가**(브라우저 결제창 / 서명검증). `simple_pay`(서버 동기완료)만 후보이나 간편결제 수단 사전등록이 필요하다.
- e2e 는 dev DB 에 테스트 계정(`sns_test_*@example.com`)을 매회 생성(fresh random email/phone, dev 데이터라 정리 불요).

## 참조

- 러너 본체 · README: `C:\Works\hongcafe_global_backend\tools\runner\`
- 메모리: `reference_api_test_runner` (위치 · 키 경로 · SSM 패턴 SSOT)
- dev EC2 = `i-0183f9ab360cc9d80` (us-east-1), dev 코드 = `/works/hongcafe-global/dev/`
