---
description: 사이트 순회 결함 발견 → 발행 대상 레포의 이슈 규약대로 티켓 등재 후 정지. 순회·판정은 그 레포의 `tools/regression/` 이 하고 이 커맨드는 부르기만 한다(도구를 다시 만들지 않는다). 소진은 `/taskflow:tick` + `/taskflow:control` 소관. 짝 = `/taskflow:control`(대기 큐) · `/taskflow:tick`(소진)
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
argument-hint: "[html|json|browser|adversarial|all  # 기본 all]"
---

# 사이트 순회 (Site Sweep)

사이트를 순회해 결함을 찾고, **발행 대상 레포에 이미 있는 이슈 규약대로 티켓을 등재**한 뒤 멈춘다.

> **이 커맨드는 순회 도구를 갖고 있지 않다.** 순회·판정·안전 제외·세션 관리는 전부 대상 레포의 `tools/regression/` 이 한다. 여기가 하는 일은 **그 결과를 티켓으로 등재하는 것** 하나다.

> **용어 주의 — 이 하니스에서 "sweep" 은 세 곳에서 다른 뜻이다.** ① CLAUDE.md §4.3 "참조 범위 전수 조사 sweep"(문서 출처 훑기) ② 대상 레포의 "stale issue sweep"(등재된 이슈가 낡았는지 감사) ③ **본 커맨드 = 사이트 순회.**

## 왜 도구를 만들지 않는가

2026-09-04 에 한 번 만들었다가 폐기했다. 만든 것이 전부 이미 있었고, 있는 쪽이 더 정확했다.

| 문제 | 폐기한 자체 구현 | 실제로 쓰는 것 |
|---|---|---|
| 쓰기 EP 차단 | 호출 1-hop 추적 | `api-write-exclusions.tsv` — **호출 그래프 3단계** + `read`/`write`/`missing` 3분류 + 오탐 복구 경로 |
| 판정 | `BROKEN`/`UPHELD`/`BLOCKED` | `verdict.py::classify` + `adversarial.py` 4값(`REJECTED`/`CRASH`/`SILENT`/`SAME`) |
| 세션 수렴 감지 | 로그인 마커 정규식 | `verdict.py::is_login_page` + `capture.py` healthcheck |
| 라우트 실측 | (못 함 — 카탈로그 stale 을 구멍으로 남김) | `route-map.tsv` 488행 |
| 샌드박스 | (미배선으로 오판) | `sandbox-router.php` — `.env.sandbox` 를 부트 전에 심어 로컬 DB 강제 |
| 브라우저 축 | 2단계로 미룸 | `browser_probe.py` |

**교훈은 재사용 조사의 범위다.** `docs/` 만 훑고 `tools/` 를 안 봐서 세 라운드를 낭비했다. 대상 레포에 손대는 커맨드를 만들 때는 **그 레포의 `tools/` 를 먼저 읽어라.**

## 전제 — 이 셋이 안 맞으면 순회 결과가 거짓이 된다

**1. 샌드박스 위에서 돈다.** 원본 `.env` 는 JP dev Aurora 를 가리킨다. `sandbox-router.php` 없이 웹서버를 올리면 순회가 원격 개발 DB 를 바꾼다.

```bash
# 기동 (대상 레포에서)
pwsh tools/regression/sandbox-serve.ps1        # 기본 :8080
```

**2. 계정에 메뉴 권한이 있어야 한다.** "로그인했다" 와 "권한이 있다" 는 다른 질문이다. 권한 0건 계정도 로그인에 성공하고 익명과 다른 응답을 주므로 healthcheck 를 통과하는데, 실제로는 어느 화면도 안 열린다.

> 실측(2026-09-04) — 권한 없는 계정으로 86화면을 돌렸더니 결함이 17건에서 **4건으로 줄었다.** 고쳐진 게 아니라 도달하지 못한 것이다. **결함 건수가 줄어드는 것은 좋은 신호가 아니다 — 측정이 죽어도 똑같이 줄어든다.**

`browser_probe.py` 가 사이드바 링크 5개 미만이면 종료 코드 `2` 로 멈춘다. **그 게이트를 우회하지 마라.**

**3. 쓰기 EP 는 기본 제외다.** `--include-mutations` 를 켜지 마라. `autoRoute = true` 라 모든 컨트롤러 메서드가 GET 으로 열려 있고, `refundsuccess`·`paycoin`·`pbxerror3/index`(코인 차감)가 대상 목록에 그대로 있다.

## 1-iteration 흐름

```
/taskflow:sweep [축]
  │
  ├─ 0. 대상 판정      docs/wbs/issue/README.md 존재? → 그 규약 / 없으면 working/ fallback
  ├─ 1. 전제 확인 ★     샌드박스 기동 · 권한 계정 · 쓰기 제외 (하나라도 실패 = 중단)
  ├─ 2. 대역 확보       4중 실측 → 빈 구간에서 자름 → README 표에 행 등록
  ├─ 3. 순회           tools/regression/ 실행 (아래 §축별 호출)
  ├─ 4. 중복 2단       등재 존재? + 조치 커밋 존재? → 흡수 / stale / 신규
  ├─ 5. 등재           pending/{날짜}-ISS-{대역내}-{slug}.md · 0건이면 커버리지 파일
  └─ 6. 정지           머지·push 안 함. 소진 = /taskflow:tick + /taskflow:control
```

## 3단계 — 축별 호출

| 축 | 명령 | 잡는 것 |
|---|---|---|
| `html` | `python tools/regression/capture.py --label sweep-{날짜} --kind html` | 렌더 결함 · 500 |
| `json` | `python tools/regression/capture.py --label sweep-{날짜} --kind json` | API 응답 키 결손 |
| `browser` | `python tools/regression/browser_probe.py` | JS 실행 후 DOM — 서버 200 + 소스 무결을 동시에 통과하는 결함 (`ISS-600` 유형) |
| `adversarial` | `python tools/regression/adversarial.py` | 깨뜨릴 수 있나 (`CRASH`/`SILENT`/`SAME`) |

**`SAME` 을 통과로 읽지 마라.** 파라미터를 어떻게 비틀어도 응답이 같다면 그 값을 아무도 안 읽는다는 뜻이고, 필터가 죽어 있다는 신호일 수 있다.

세부 인자·종료 코드·화이트리스트는 `tools/regression/README.md` 가 SSOT 다. 여기에 복제하지 않는다.

## 2단계 — 대역 확보 (등재보다 먼저)

연번을 그때그때 따면 반드시 충돌한다. 각 worktree 는 자기 base 커밋의 `issue/` 만 본다.

```bash
ls docs/wbs/issue/*/ | grep -oE 'ISS-[0-9]{3}'                    # ① 로컬 3폴더
git fetch --quiet origin                                           # ②
git ls-tree -r --name-only origin/develop docs/wbs/issue/          # ③ 원격 실재
git log --all --oneline | grep -oE 'ISS-[0-9]{3}'                  # ④ 커밋 메시지
```

**`max+1` 로 자르지 않는다** — 모든 세션이 같은 규칙을 쓰면 같은 칸에서 다시 만난다. 표가 "이후 참여자" 몫으로 명시한 빈 구간에서 자르고 표에 행을 먼저 추가한다.

> **한계 — 4중 실측은 "예약 행" 을 못 본다.** 넷 다 실제 ISS 파일 또는 `ISS-NNN` 이 박힌 커밋만 찾는다. 순수 예약 행(README 표 1줄)은 미정착 상태에서 다른 worktree 에 안 보이고, **sweep 은 push 를 못 한다**(§3).
> **그래서:** worktree 이름을 `wip/{sid}-sweep-{YYYYMMDD}` 로 고정하고, 진입 시 `git worktree list | grep -- '-sweep-'` 로 미정착분을 먼저 찾는다. 있으면 `git show {branch}:docs/wbs/issue/README.md` 로 예약 행을 확인해 **그 대역을 피한다.** 미정착이 2개 이상 쌓이면 순회하지 말고 사용자에게 정착을 요청한다.

## 4단계 — 중복 판정 (2단, 직렬)

**등재 여부만 보면 안 된다.** 실측(2026-08-26 stale 감사)에서 pending 118건 중 **15건(12.7%)이 이미 해소된 상태**로 남아 있었다.

| ① 기등재? | ② 조치 커밋? | 판정 |
|---|---|---|
| 있음 | 없음 | **흡수** — 새 번호 안 딴다. 기존 이슈에 근거만 보탠다 |
| 있음 | 있음 | **stale** — 기존 이슈는 `resolved` 대상. 재현됐다면 신규 등재(회귀) |
| 없음 | — | **신규 등재** |

등재 후 `bash docs/wbs/scripts/2026-08-14-iss-doctor.sh` 로 번호 충돌을 사후 검출한다(전 브랜치 `git ls-tree`).

## 5단계 — 등재

```
docs/wbs/issue/pending/{YYYY-MM-DD}-ISS-{대역내 번호}-{slug}.md
```

양식·frontmatter·상태 전이는 그 레포 `issue/README.md` §2 를 따른다. **결함 0건이면 커버리지 파일에 남긴다** — 이슈 파일이 없으면 "안 봤다" 와 "봤는데 없었다" 가 구분되지 않는다. `UPHELD` 는 U1~U4 를 다 채웠을 때만 쓴다.

## 6단계 — 정지

**머지·push·코드 수정 안 한다**(§3). 등재까지가 끝이다.

```
전제: 샌드박스 :8080 · 계정 권한 {N}메뉴 · 쓰기 제외 ON
대역: ISS-NNN~NNN (잔여 N)
순회: {축} — 대상 N건 / CRASH N · SILENT N · SAME N · REJECTED N
등재: N건 (흡수 N · stale N)
잔여: 사용자 정착 대기 — worktree {경로}
```

## SSOT (재사용 조각)

| 조각 | SSOT |
|------|------|
| 순회·판정·안전 제외·세션·브라우저 축 | 대상 레포 `tools/regression/README.md` |
| 샌드박스 기동 | 대상 레포 `tools/regression/sandbox-serve.ps1` · `sandbox-router.php` |
| 이슈 규약 · 채번 대역 | 대상 레포 `docs/wbs/issue/README.md` |
| UPHELD 4요건 · 0건 스윕 기록 | 대상 레포 `docs/wbs/issue/` 커버리지 파일 |
| 번호 충돌 사후 검출 | 대상 레포 `docs/wbs/scripts/2026-08-14-iss-doctor.sh` §3 |
| 소진 | `commands/tick.md` · `commands/control.md` |

## §3 Checkpoint 우선 적용

- **머지·push 금지** — 사용자 직접만
- **`--include-mutations` 금지** — 켜면 쓰기 EP 가 호출된다. 사용자 명시 승인 영역
- **자격증명** — `tools/regression/config.ini` `[auth]` 경로 또는 `--cookie-file`. 하니스가 따로 갖지 않는다
- **대상 레포 쓰기** = worktree 안에서만 (§4.3-a). 정착은 사용자 소관

## 짝 슬래시

`/taskflow:control`(대기 큐 리뷰) · `/taskflow:tick`(소진). 워크플로우 맵 = `commands/execute.md` §"워크플로우 맵".

## Changelog

- 2026-09-04: 신설. 초안은 순회 도구를 자체 구현했으나 콜드 리뷰 2라운드 + 적대적 검증이 안전 판정을 세 번 뚫었고, 그 과정에서 대상 레포 `tools/regression/` 이 같은 문제를 이미 더 정확히 풀어둔 것을 발견해 **자체 구현을 폐기하고 wrapper 로 전환**했다.
