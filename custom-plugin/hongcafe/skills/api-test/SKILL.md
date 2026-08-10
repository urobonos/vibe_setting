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
version: 1.1.1
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
- `{env}` = US `dev`(기본)·`stg`·`prd` / **JP `dev-jp`·`stg-jp`·`prd-jp`**. **prd 계열은 러너가 e2e·scenario 를 차단**(prefix 판정이라 `prd-jp` 도 포함 — 계정 생성 사고 방지).
- base = US `https://{env}.gl.hongcafe.com` / **JP `https://{dev|stg}.jp.hongcafe.com`·`https://jp.hongcafe.com`**(`gl` 세그먼트 없음). prefix 는 공통 `/__hongcafe_api__`.
- **개발 우선 리전 = JP.** 특별한 지시가 없으면 `dev-jp` 로 돌린다. **리전·환경마다 `encryption.key` 가 다르므로** AES 를 쓰는 모드(e2e / SNS 시나리오)는 대상 환경 키를 주입해야 한다 — 로컬 `.env` 키로 보내면 서버가 `DECRYPT_FAILED` 를 준다.

### exit code 계약 (2026-08-03 `10a9a971`~)

무인 호출(watch/CI)이 실패를 놓치지 않도록 3 모드 모두 실패 시 **exit 1** 이다. 종전엔 표에 `FAIL` 이 찍혀도 exit 0 이라 green 으로 통과했다.

| 상황 | exit |
|------|------|
| smoke·e2e·scenario step 실패 | **1** |
| 시나리오명 오타 / 미상 prelude / step 0개 | **1** |
| `scenario {domain}` 만 주고 목록 출력 | **0** (조회는 실패가 아니다) |
| AES 키 부재·형식 오류 | **1** (HTTP 호출 전 중단, 값 미출력) |

### known-red — 지금 상시 실패하는 것 (신규 회귀로 오판하지 말 것)

아래는 **이 러너가 드러낸 선재 결함**이며 exit code 도입 전에도 표 결과는 동일했다. 무인 호출에 물릴 때는 이 셋을 제외하거나 먼저 해소한다.

| 대상 | 증상 | 원인 |
|------|------|------|
| **`e2e` 모드 (전 환경)** | step 1 에서 403 `PHONE_NOT_VERIFIED` → 1/1 FAIL | `20c99af6`(2026-07-24, SNS 가입 SMS 본인확인 서버강제) 이후 `/api/sns/receive` 가 폰인증 선행을 요구하는데 `e2e()` 에 sms-send/verify step 이 없다. 폰인증까지 갖춘 경로는 아래 SNS 시나리오다 |
| commerce `public-browse` | `POST /api/shops/items` 404 `No products found.` | dev 상품 데이터 부재 |
| commerce `signup-purchases` | `goods-purchases` 404 | 동일 |

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

> **이 모드는 현재 red 다** (위 known-red). 폰인증 선행이 빠져 step 1 이 403 으로 막히므로 아래 "기대 결과" 는 **`20c99af6` 이전 기준**이다. 지금 가입 흐름을 검증하려면 SNS 시나리오(`scenario member sns-signup-marketing-consent dev-jp`)를 쓴다 — sms-send/verify 를 포함해 실제로 통과한다.

기대 결과(과거 기준): 가입 200(쿠키 4종 hc_access/refresh/csrf/hdata) → whoami 200 → coin-summary `remainCoin` > 0 (가입 코인) → coin-transactions `category=join` 1건.

위 SSM 블록의 `IID`/`REGION`/경로는 **US** 기준이다. JP 는 `IID=i-00e741e10d528c7e5`·`REGION=ap-northeast-1` 로 바꾼다. 이 블록은 아래 SNS 시나리오의 키 조달에도 그대로 재사용한다.

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
- **AES 키가 필요한 시나리오**: member `sns-signup-marketing-consent` · `sns-signup-marketing-consent-mixed` 2종뿐이다(SNS 가입 `data` 를 `@gen.snsdata` 로 암호화). 키 조달 = 위 e2e 절 SSM 블록 재사용 후 `HC_ENC_KEY` 주입. 나머지 시나리오는 키 없이 돈다.

### 마케팅 수신동의 회귀 가드 — 2종이 한 쌍이다

가입 2경로(이메일 `POST api/members` / SNS `POST api/sns/receive`)마다 `-mixed` 접미 시나리오가 짝으로 있다. **하나만 돌리면 가드가 반쪽이다.**

| 시나리오 | 보내는 값 | 잡는 것 |
|---------|---------|--------|
| `signup-marketing-consent` · `sns-signup-marketing-consent` | `Y/Y/Y` | 키 탈락 — 화이트리스트에서 빠지면 서버 기본값 `N` 이 나와 FAIL |
| `…-mixed` | `Y/N/Y` | blanket 매핑 — 전부 `Y` 로 하드코딩하는 오구현이면 `acEmailCf` 가 `Y` 로 나와 FAIL |

**왜 나눴나:** 서버 기본값이 `N/N/N` 이라 `Y/N/Y` 단독으로는 `N` 자리가 공집합이다 — "N 을 보냈다"와 "키가 아예 안 갔다"가 구분되지 않아, `acEmailCf` 를 payload 에서 빼도 통과했다(2026-08-03 실측 재현). 전부-`Y` 축이 그 구멍을 닫는다.

검증됨(2026-06-23): member `signup-profile-coin` 12/12 · board `posting-read` 3/3 · payment `signup-readonly` 10/10. 일부 완결 step(commerce `item-detail`, payment `order-create`)은 dev 데이터·simple_pay 수단 사전등록 의존.

검증됨(2026-08-03): SNS 2종 dev-jp 각 4/4 · 이메일 2종 dev 각 9/9 · 무회귀 14 시나리오 exit 0. mutation(마케팅 3키 각각 제거) 전건 FAIL + exit 1 로 가드 실효성 실측.

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
