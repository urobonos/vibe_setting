---
description: 작업 로드 — working/ 잔여 작업 + DISPATCH 분배 풀 스캔 후 본문·재진입 안내 + **`#tag` 배타 claim·로드(구 claim/consume 흡수, 2026-07-16)**. 짝 슬래시 = `/taskflow:save`. **기본 전체 잔존 노출 (cwd 필터 기본 해제) + 분배 풀 통합 + #tag 배타 claim**. **로드 전용 — `#tag`·`{작업명}` 미지정 시 목록 출력 후 정지, 잔여 작업 자동 실행 금지**
allowed-tools: Bash, Read, Glob, Grep, PowerShell, Edit
argument-hint: "[작업명|latest|all|{product}|#tag|#tag done]  # 인자 없음=전체 잔존 / #tag=분배 배타 claim+로드 / #tag done=완료"
---

다음 세션 시작 직후 호출하는 잔존 작업 로드 슬래시. `/taskflow:save` 분기 B (Status: Partial + `## 잔여 작업` 섹션) 로 working/ 에 보관된 작업을 다시 컨텍스트로 끌어온다. **동시에 `/taskflow:dispatch` 가 DISPATCH 풀에 등록한 `available` 분배 작업(`#tag`)도 함께 표시** — 세션 시작 시 "내 잔존 작업 + 집어갈 분배 작업"을 한 화면에 노출한다. 분배 작업도 load 가 `#tag` 로 직접 claim 한다 (아래 §"#tag claim" 참조).

**기본 전체 잔존 노출 (2026-06-18~ 변경):** 인자 없음(`/taskflow:load`) = product 구분 없이 working/ 내 **잔여 작업(미체크 `- [ ]` ≥ 1) 보유 문서 전부** 노출 (Status `Partial`/`Plan Complete`/`폐기` 무관 — 잔여가 있으면 모두). `latest` 만 `hooks/lib/product-resolver.sh` 의 `resolve_product` 로 현재 cwd → 본 product 안 자동 선택 (자동 선택은 라우팅 정확도가 중요하므로 cwd 매칭 유지). 좁혀 보려면 `/taskflow:load {product}` 명시. **Why:** 다레포 환경에서 본 product 잔존이 0건이어도 타 product 진행 작업을 한눈에 봐야 세션 연속성·작업 누락 방지가 된다 (구 cwd 1차 필터는 본 product 0건 시 빈 화면 → 누락 위험). **자동 선택(`latest`)만** cwd 라우팅을 유지해 잘못된 product 빨려듦을 방지한다.

## 동작 3단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① 잔존 작업 스캔 + 분배 풀 조회 + 빈 폴더 정리 | `~/.claude/docs/working/YYYYMMDD/` 전체 스캔 → `## 잔여 작업` 섹션의 미체크 `- [ ]` ≥1 보유 파일 추출 (Status 무관) → **인자 product 필터 (인자 없음 = 전체, 필터 없음)**. **+ DISPATCH 풀 `dispatch_list available` 조회 (`#tag` 표시, product 필터 동일).** **금일(`date +%Y%m%d`) 이전 폴더 중 `*.md` 파일 0건이면 해당 폴더 자동 삭제** (working/ → tasks/ 이동 후 남은 빈 껍데기 정리). | 전체 잔존 + 분배(`#tag`) 목록 + 빈 폴더 0건 |
| ② 인자 분기 처리 | 인자 없음 = 전체 목록 (=all) / `{작업명}` = 본문 출력 / `latest` = 본 product 가장 최근 1건 / `all` = 전체 product / `{product}` = 특정 product 잔존 | 본문 또는 목록 |
| ③ 재진입 안내 | 잔여 항목 미체크 박스 추출 + `/taskflow:auto {요약}` **제안까지만** (후속 슬래시 자동 호출 금지 — 아래 §"자동 실행 금지") | 다음 액션 결정 = 사용자 |

## 호출 방식

| 인자 | 동작 |
|------|------|
| 인자 없음 (`/taskflow:load`) | **전체 product 잔존 작업 목록** 표시 (잔여 미체크 `- [ ]` ≥1 보유 문서 전부, Status 무관 — `all` 과 동일) |
| `{작업명}` (`/taskflow:load auth-refactor`) | 파일명 매칭 → 해당 작업 본문 + 잔여 항목 표시 (product 무관, 직접 매칭) |
| `latest` (`/taskflow:load latest`) | **본 product 안** 가장 최근 잔존 작업 1건 자동 선택 → 본문 + 잔여 항목 표시. 본 product 잔존 0건 시 fallback 안내 (전체 latest 진입 옵션) |
| `all` (`/taskflow:load all`) | 전체 product 잔존 작업 목록 표시 (= 인자 없음과 동일) |
| `{product}` (`/taskflow:load hongcafe_global_backend`) | 특정 product 잔존 작업 목록 표시 |
| `#tag` (`/taskflow:load #auth-jwt`) | **분배 배타 claim + 문서 로드** (claim 흡수 — 아래 §"#tag claim") |
| `#tag done` (`/taskflow:load #auth-jwt done`) | **claim 작업 완료 마킹** (`dispatch_done`) |
| `#consume` (`/taskflow:load #consume`) | **available 자동 폴링·claim·소비 루프** (consume 흡수) |

## ① 잔존 작업 스캔 + 빈 폴더 정리

**REGISTRY 우선 조회 (2026-05-15 신설):** `~/.claude/docs/working/REGISTRY.md` 마크다운 표 우선 조회 → 본 세션 sid 와 비교해 `[active by other]` / `[paused]` / `[orphan]` 3분류. 그 다음 working/ 직접 grep 으로 보강.

```bash
# 0) 스캔 루트 — working/ 날짜 폴더(YYYYMMDD)만. working/dispatch/ 등 비-날짜 폴더는 잔여 스캔 대상 아님
WORKING_GLOB="$HOME/.claude/docs/working/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"

# 0-bis) product 식별 — 현재 cwd 기준 (worktree 안 호출 시 원본 repo 역해석)
source ~/.claude/hooks/lib/product-resolver.sh
CURRENT_PRODUCT=$(resolve_product "$PWD")

# 인자 분기 — TARGET_PRODUCT 결정
# $ARGUMENTS = harness 가 프롬프트 치환 시점에 대체. bash 블록은 별도 프로세스라 위치 인자($1)를 상속하지 않는다.
ARG="$ARGUMENTS"
case "$ARG" in
  ""|"all")     TARGET_PRODUCT="" ;;  # 인자 없음 = 전체 (2026-06-18 cwd 필터 기본 해제) / all = 동일
  "latest")     TARGET_PRODUCT="$CURRENT_PRODUCT" ;;  # latest 자동 선택만 본 product (라우팅 정확도 유지)
  *)
    # 작업명 매칭 시도 — 파일명 prefix `{yyyy-mm-dd}-{product}-${ARG}.md` 1건이라도 있으면 작업명 모드
    if compgen -G "$WORKING_GLOB/*-${ARG}.md" >/dev/null 2>&1; then
      TARGET_PRODUCT=""  # 작업명 직접 매칭 → product 필터 해제 (인자 분기 ②에서 처리)
    else
      TARGET_PRODUCT="$ARG"  # product 명으로 간주
    fi
    ;;
esac

# 1) REGISTRY 우선 — 다른 세션 점유 + paused 본 세션 잔존 식별
source ~/.claude/hooks/lib/registry-utils.sh
registry_list_active                 # status=active 전체 (본인 sid 아니면 다른 세션 점유)

# 2) 스캔 대상: ~/.claude/docs/working/YYYYMMDD/*.md
# 조건: ## 잔여 작업 섹션에 미체크 항목(- [ ]) ≥ 1 (Status 무관 — Partial/Plan Complete/폐기 등 잔여 있으면 전부) AND product 필터
#       (2026-06-18: Status: Partial 단독 → 잔여 미체크 기반으로 완화. "모든 잔여 작업" 노출)
grep -lE '^## 잔여 작업' $WORKING_GLOB/*.md 2>/dev/null \
  | while read cand; do
      # 미체크 항목(- [ ]) ≥ 1 인 문서만 통과 (잔여 작업 섹션 안에서)
      awk '/^## 잔여 작업/{fl=1;next} /^## /{fl=0} fl&&/^- \[ \]/{c++} END{exit !(c>0)}' "$cand" && echo "$cand"
    done \
  | while read f; do
      base=$(basename "$f")
      if [ -z "$TARGET_PRODUCT" ]; then
        echo "$f"   # 전체 (인자 없음 / all / 작업명 매칭)
      elif echo "$base" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-${TARGET_PRODUCT}-"; then
        echo "$f"
      fi
    done

# 2-bis) 타 product 요약 — latest 분기에서만 1줄 표시 (인자 없음은 이제 전체 노출이라 불필요)
if [ "$ARG" = "latest" ]; then
  OTHER_COUNT=$(grep -lE '^## 잔여 작업' $WORKING_GLOB/*.md 2>/dev/null \
    | while read cand; do
        awk '/^## 잔여 작업/{fl=1;next} /^## /{fl=0} fl&&/^- \[ \]/{c++} END{exit !(c>0)}' "$cand" && echo "$cand"
      done \
    | while read f; do
        base=$(basename "$f")
        echo "$base" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-${CURRENT_PRODUCT}-" && continue
        echo "$f"
      done | wc -l)
  echo "[타 product 잔존] $OTHER_COUNT 건 — '/taskflow:load all' 또는 '/taskflow:load {product}' 로 조회"
fi

# 3) 금일 이전 빈 폴더 자동 삭제 (working/ → tasks/ 이동 후 남은 빈 껍데기 정리)
TODAY=$(date +%Y%m%d)
for dir in ~/.claude/docs/working/*/; do
  base=$(basename "$dir")
  echo "$base" | grep -qE '^[0-9]{8}$' || continue
  [ "$base" -ge "$TODAY" ] && continue
  if [ -z "$(find "$dir" -maxdepth 1 -name '*.md' -print -quit 2>/dev/null)" ]; then
    rmdir "$dir" 2>/dev/null && echo "[CLEAN] removed empty working folder: $base"
  fi
done

# 4) DISPATCH 분배 풀 조회 — claim 가능(available) (여기는 목록 조회만 read-only; claim 은 #tag 분기)
source ~/.claude/hooks/lib/dispatch-utils.sh
# available 표시 — 분배 작업은 #tag prefix. product = 표 4번째 컬럼($4), working 잔존과 동일 필터(TARGET_PRODUCT)
dispatch_list available | awk -F"$DISPATCH_FS" -v p="$TARGET_PRODUCT" '
  $2=="tag" || $2=="" { next }
  (p=="" || $4==p) { printf "[분배 available] #%s | %s | %s\n", $2, $3, $4; next }
  { other++ }
  END { if (other) printf "[타 product 분배] %d 건 — /taskflow:load all 로 조회\n", other }
'
# claimed(점유 중) 카운트 요약 — 상세·claim 은 #tag 분기
CLAIMED_CNT=$(dispatch_list claimed | grep -cE '^\|')
[ "${CLAIMED_CNT:-0}" -gt 0 ] && echo "[분배 풀] claimed(점유 중) ${CLAIMED_CNT} 건 — 상세는 /taskflow:load"
```

각 파일에 대해 메타 추출:

| 필드 | 추출 방법 |
|------|---------|
| 날짜 | 파일명 `{yyyy-mm-dd}-` prefix |
| product | 파일명 `{yyyy-mm-dd}-{product}-...` — product-resolver 산출 `CURRENT_PRODUCT` 와 비교해 매칭 확정 (product 이름에 `-` 포함 가능성은 product-resolver 가 보장하지 않으나, 실제 운용 product 가 `_` 또는 단일 토큰이므로 prefix 매칭으로 충분) |
| 작업명 | 파일명 prefix `{yyyy-mm-dd}-{product}-` 제거 후 `.md` 제외 나머지 |
| 잔여 개수 | `## 잔여 작업` 섹션 안 `- [ ]` 카운트 |
| 마지막 수정 | `stat -c %y` |

> **product 추출 정확도 노트:** 본 슬래시는 **product 필터링** 만 수행하므로 product 가 `-` 포함이어도 좌→우 prefix 매칭으로 안전 (CURRENT_PRODUCT 또는 인자 product 가 정답). product 가 미리 결정돼 있어서 작업명 토큰을 역추출할 필요 없음. 작업명 표시는 prefix 제거로 단순 분리.

## ② 인자 분기 처리

### 인자 없음 — 전체 잔존 목록 표시 (product 무관)

```
[Claude] 전체 잔존 작업 N건 (product 무관 · 잔여 미체크 - [ ] ≥1 · Status 무관):

  1. 2026-05-19 / infra / mono-lambda-precision-analysis
     ├─ Status: Partial | 잔여 5건
     └─ 진입: /taskflow:load mono-lambda-precision-analysis

  2. 2026-06-08 / infra / kor-jpn-build-ahead
     ├─ Status: Plan Complete | 잔여 4건   ← Partial 아니어도 잔여 있으면 포함
     └─ 진입: /taskflow:load kor-jpn-build-ahead

  3. 2026-06-16 / hongcafe_global_backend / qna-pii-retention
     ├─ Status: Partial | 잔여 2건
     └─ 진입: /taskflow:load qna-pii-retention

        분배 풀 claim 가능 (전체, #tag):

  #mod20-sns-token-svc | gantt-progress | available → /taskflow:load #mod20-sns-token-svc

  본 cwd product 안 가장 최근만 자동 선택: /taskflow:load latest
  특정 product 로 좁히기:                 /taskflow:load infra
  분배 작업 claim:                        /taskflow:load #mod20-sns-token-svc
```

### `{작업명}` — 본문 출력 (product 무관)

```bash
# 파일명 매칭 — product 필터 해제 (직접 작업명 지정 = 명시 의도). 날짜 폴더만 (dispatch/ 제외)
ls ~/.claude/docs/working/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/*-${작업명}.md 2>/dev/null
```

전체 본문 출력 후 `## 잔여 작업` 섹션 부각 + 재진입 제안.

> **cwd 미스매치 경고:** 본 product 와 다른 product 작업명 직접 지정 시 헤더에 `[경고] 본 cwd product=${CURRENT_PRODUCT}, 본 작업 product=${파일 product} — 작업 진행 전 cwd 확인 권장` 1줄 부착.

#### 무인 마커 일시 점유 — `allow` → `pause` (2026-07-29, read-only 계약 예외)

**작업명을 직접 지정한 로드는 "이 task 를 내가 처리한다" 는 명시 의도다.** 그 상태로 두면 tick 무인 루프가 같은 task 를 동시에 집어가므로, unified 마커가 `allow` 일 때만 `pause` 로 내린다.

```bash
source ~/.claude/hooks/lib/working-scan.sh
UNIFIED=$(working_scan all | awk -F'\t' -v t="$작업명" '$4==t && $6==0 {print $1}')
grep -qE '^(tick|무인):[[:space:]]*(allow|허용)' "$UNIFIED" || exit 0   # allow 아니면 손대지 않음
# → tick: pause (by {sid8}, {YYYY-MM-DD}) 로 교체 (전이 규약 SSOT = tick.md §pause)
```

- **`allow` 인 경우만** 쓴다. `deny`·마커 없음은 건드리지 않는다 (전이 폐쇄성 = `tick.md` §`pause` SSOT).
- 복원은 `/taskflow:save` 가 한다. 세션이 죽어 복원이 안 되면 `watch` C 트랙이 죽은 sid 의 `pause` 를 회수한다.
- 인자 없음·`all`·`{product}` 목록 분기는 **비대상** — 훑어보는 것과 집는 것은 다르다.

> **왜 REGISTRY claim 이 아닌가.** claim 은 세션이 닫히면 `paused` 로 풀려 tick 이 즉시 재잡이한다. 세션을 껐다 켜며 task 를 하나씩 처리하는 흐름에서는 점유가 유지되지 않는다 — 마커는 문서 속성이라 세션 생명주기와 무관하다.
>
> **§"REGISTRY 갱신 책임 = 읽기 only" 와 상충하지 않는다.** 그 계약은 REGISTRY 를 안 건드린다는 뜻이고, 여기서 쓰는 것은 unified 마커 1줄이다. 본 슬래시의 유일한 mutation 이며 `{작업명}` 명시 지정에서만 발생한다.

### `latest` — 본 product 안 자동 선택

본 product 잔존 중 mtime 최신 1건 → `{작업명}` 분기와 동일하게 본문 출력. 본 product 잔존 0건 시:

```
[Claude] 본 product (${CURRENT_PRODUCT}) 잔존 작업 없음.
        타 product 잔존 5 건 중 가장 최근:
          2026-05-19 / infra / mono-lambda-precision-analysis

        진입 옵션:
          ① /taskflow:load mono-lambda-precision-analysis  — 직접 로드 (cwd 미스매치 경고)
          ② /taskflow:load all                              — 전체 목록
          ③ 보류 (잔여 작업 없음, 신규 작업 진행)
```

### `all` — 인자 없음의 명시적 별칭

동작은 위 §"인자 없음" 분기와 동일. 2026-06-18 cwd 필터 기본 해제 이후 별칭으로만 남았다.

### `{product}` — 특정 product 잔존 목록

작업명 매칭 실패 + 작업명 형식이 아닌 경우 product 명으로 간주. 해당 product 안 잔존 목록 표시.

## ③ 재진입 안내

> **터미널 제목 설정:** `{작업명}`·`latest` 로 특정 작업을 로드(본문 출력)한 경우 PowerShell 도구로 `$Host.UI.RawUI.WindowTitle = "#{작업명}"` 설정 (목록 표시 분기 `없음`·`all`·`{product}` 은 제외 — 로드한 단일 작업이 없으므로). 방식·전제 = 아래 §"터미널 제목 설정 (SSOT)".

### 잔존 작업 (working/ Partial) — 본문 표시 후 잔여 항목 요약

```
[Claude] 본 작업 잔여 3건:
  - [ ] CI4 Routes 캐시 무효화 — Auth 모듈 변경 후 캐시 재빌드 필요
  - [ ] integration test 추가 — login 흐름 e2e 1건 누락
  - [ ] CHANGELOG 1줄 보강 — 2026-05-14 항목

  재진입 옵션:
  ① /taskflow:auto 잔여 3건 일괄 처리                  ← 묶음 승인 모드 진입
  ② 개별 항목 직접 지시 (예: "Routes 캐시 무효화부터")
  ③ 분기 처리 (Critical 만 처리 후 보류)

  어느 옵션으로 진행하시겠습니까?
```

### 분배 작업 (DISPATCH available) — claim 안내

분배 작업은 load 가 `#tag` 로 직접 배타적 claim 한다 (아래 §"#tag claim" 참조). `#tag` 진입:

```
  분배 작업 claim:  /taskflow:load #hook-refactor-01      ← 배타적 claim + 분배 문서 로드
  분배 목록 조회:   /taskflow:load                         ← available 전체
```

**§3 Checkpoint 우선 적용:** 재진입 후 작업 수행은 §3 Checkpoint 매칭 시 별도 승인 요구. 본 슬래시는 **로드 (read-only)** 만 담당, 실제 작업 실행은 후속 슬래시 또는 사용자 지시.

### 자동 실행 금지 (2026-07-22 신설, 필수)

**`#tag` 또는 `{작업명}` 을 지시하지 않은 호출** (인자 없음 / `all` / `{product}` / `latest`) = 목록·본문 출력 + 재진입 안내까지만 하고 **그 턴에서 정지**한다. 잔여 항목을 골라 실행하거나 `/taskflow:execute`·`/taskflow:auto` 를 스스로 호출하는 것은 위반이다.

| 금지 | 대신 |
|------|------|
| 잔여 미체크 항목을 그 턴에 착수 | 항목 나열 + "어느 옵션으로 진행하시겠습니까?" 로 종료 |
| 후속 슬래시(`/taskflow:execute`·`/taskflow:auto`) 자동 호출 | 진입 명령 **문자열만** 제시 |
| "가장 급한 것부터 처리하겠습니다" 류 자율 선택 | 우선순위 **권고**만, 선택은 사용자 |

**gate=2 (묶음 승인 모드) 에서도 동일.** 자동 위임 정책의 "권고안 자동 채택"(CLAUDE.md §4.4 (2))은 **직전 응답의 권고**에 적용되는 것이지, load 가 방금 발견한 잔존 작업 목록에는 적용되지 않는다 (사용자가 승인한 대상이 아니다). 따라서 목록 분기 응답은 self-critique 통과 후 마지막 줄에 **`[AUTO-ITERATE-DONE]`** 을 부착해 Stop 루프를 정상 종료시킨다.

**예외 = 같은 프롬프트에 실행 의사가 함께 있을 때만** (예: `/taskflow:load latest 이어서 진행해`, `/taskflow:load #auth-jwt` 후 사용자가 실행 지시). `#tag` claim 도 claim + 문서 로드까지가 기본값 — 실행은 별도 지시.

**Why:** load 는 "무엇이 남았는지 보는" 진입점이다. 조회가 착수로 미끄러지면 사용자가 의도하지 않은 작업이 gate=2 아래에서 끝까지 굴러간다 — 되돌리는 비용이 조회 편의보다 훨씬 크다.

## #tag — 분배 claim + 로드 (claim/consume 흡수, 2026-07-16)

`#tag` 인자 = 구 `/taskflow:claim` 흡수. DISPATCH 풀에서 배타적 claim 후 분배 문서 로드. **claim 은 read-only 목록과 달리 lock mutation** (load 의 유일한 mutation 분기). 짝 = plan 의 병렬 그룹 자동 등록(`plan.md §"병렬 그룹 다세션 분배"`).

> **점유 선확인 = `dispatch_claim` 내장:** 배타 lock + `TAKEN` 거부가 타 세션 침범을 원천 차단한다 (별도 §0 게이트 불요 — lock 이 곧 게이트). 어떤 분배 작업을 하기로 판단했더라도 분배 문서를 직접 열지 말고 **항상 이 claim 을 먼저** 거친다 (claim 이 `TAKEN` 이면 타 세션 소유).

```bash
source ~/.claude/hooks/lib/dispatch-utils.sh
SID8="${CLAUDE_SESSION_ID:0:8}"
[ -z "$SID8" ] && SID8="<현재 세션 sid 8자 — Claude 본체 기입>"
OUT=$(dispatch_claim "{tag}" "$SID8"); RC=$?
RESULT="${OUT%%|*}"; DOC="${OUT#*|}"
```

| RESULT (rc) | 처리 |
|-------------|------|
| `CLAIMED`/`ALREADY_YOURS`/`STOLEN` (0) | 분배 문서(`$DOC`) 본문 로드 + 터미널 제목 `#{tag}` 설정 + 진입 안내 (`/taskflow:execute`·`/taskflow:auto` 위임) |
| `TAKEN:<sid>` (3) | **거부** — 타 세션 점유, 다른 태그 선택 또는 24h 후 |
| `DONE` (4) | **거부** — 이미 완료 |
| `NOTFOUND` (2) | available 목록 재표시 + 오타 확인 |

> **`#tag done`:** `dispatch_done "{tag}" "$SID8"` — status=done + lock 정리 (claim 본인 sid 만 정상).

### consume 흡수 (자동 폴링)

`/taskflow:load #consume` (권장 `/loop /taskflow:load #consume`) = available 풀을 자동 폴링·claim·소비 연속 (구 `/taskflow:consume` 흡수). 풀이 빌 때까지 건별 `dispatch_claim` → `/taskflow:execute` 위임 → `dispatch_done`. worker 세션 무인 소비.

## 터미널 제목 설정 (SSOT, claim.md 이전 2026-07-16)

작업·분배 진행 슬래시가 진입 시 터미널 창 제목을 태스크명으로 설정한다 (다세션 병렬 창 식별). 본 섹션이 방식·형식의 단일 SSOT — `/taskflow:execute`·`/taskflow:auto`·`/taskflow:save`·`load #consume` 이 값만 다르게 참조한다.

| 항목 | 값 |
|------|-----|
| **방식** | **PowerShell 도구**로 `$Host.UI.RawUI.WindowTitle = "{제목}"` (Bash 도구 금지 — 별도 PTY라 OSC 미반영, 검증 완료) |
| **형식** | 분배(claim) = `#{tag}` / 워킹(execute·auto·load) = `#{작업명}` |
| **원복** | 세션 마감(`/taskflow:save`) = `$Host.UI.RawUI.WindowTitle = (Split-Path -Leaf $PWD)` |
| **전제** | `settings.json` env `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` (자동 제목 override 차단) |
| **OS·실패** | Windows(PowerShell) 전용. 비-Windows·실패 시 무시하고 진행 |

## §3 Checkpoint 우선 적용

- 본 슬래시 = **잔존 스캔 read-only** (Read / Glob / Grep / Bash 조회계 + 빈 폴더 `rmdir`) + **`#tag` claim 시 lock mutation** (dispatch_claim). working/ 파일 자체 수정 없음.
- **`#tag` claim = 회복 가능** (`dispatch_release` 로 available 복귀) — 사용자 승인 없이 진행 가능. claim 후 실제 코드 변경이 §3 매칭이면 그 시점 각 guard hook 강제.
- **DISPATCH 분배 풀 목록 조회(`dispatch_list`) = read-only.** `#tag` claim(`dispatch_claim` = DISPATCH.md + lock mutation) 은 본 슬래시가 직접 수행한다 (아래 §"#tag claim").
- **빈 폴더 정리 예외 사유:** (1) `*.md` 파일 0건만 대상 → 데이터 손실 0, (2) `rmdir` 는 비어 있지 않은 폴더 자동 실패 → 안전 잠금, (3) 금일 폴더는 보호 (진행 중일 수 있음). §3 Checkpoint "비가역 작업" 매칭이지만 무해 정리로 한정 — 매 호출 사용자 승인 면제.
- **본 슬래시는 실행 트리거가 아니다.** 실제 작업 진행 = 사용자 선택 후 후속 슬래시 호출 (`/taskflow:auto` 등) 또는 직접 지시. `#tag`·`{작업명}` 미지정 호출의 정지 규칙 = 위 §"자동 실행 금지" SSOT.
- 잔존 작업 파일 자체 삭제·이동 = 본 슬래시 비대상 — `/taskflow:save` 또는 `/taskflow:save now` 영역.

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §File Paths "working/ 단일 통합 문서" | working/ 경로 정책 |
| **`~/.claude/hooks/lib/product-resolver.sh`** | **cwd → product 산출 (worktree 안 호출 시 원본 repo 역해석)** |
| **`~/.claude/hooks/lib/dispatch-utils.sh`** | **DISPATCH 분배 풀 조회(`dispatch_list`, read-only) + `#tag` claim/done(`dispatch_claim`/`dispatch_done`, mutation) — 본 슬래시가 직접 호출** |
| `~/.claude/hooks/working-lifecycle.sh` | working/ → tasks/ 이동 본체 (본 슬래시는 read-only, 호출 안 함) |
| `~/.claude/skills/task-docs/references/unified-template.md` | unified 양식 (Status / 잔여 작업 섹션 위치) |
| **`~/.claude/custom-plugin/taskflow/commands/save.md`** | **짝 슬래시 — Status: Partial 마킹 + `## 잔여 작업` 섹션 작성 (잔존 작업 생성자)** |
| `~/.claude/custom-plugin/taskflow/commands/auto.md` | 잔여 일괄 처리 시 후속 진입점 |
| `~/.claude/custom-plugin/taskflow/commands/load.md` (본 파일) | 잔존 작업 식별·표시 + `#tag` claim 진입점 |
| **REGISTRY 갱신 책임 (audit M13 명문 2026-05-20)** | **읽기 only — active/paused/orphan 3분류 표시. mutation 0 (본 슬래시는 read-only, 갱신은 작업저장 영역)** |

## 호출 예

```
/taskflow:load                       ← 전체 product 잔존 작업 목록 (잔여 미체크 ≥1, Status 무관)
/taskflow:load latest                ← 본 product 안 가장 최근 1건 자동 선택 + 본문 출력
/taskflow:load all                   ← 전체 product 잔존 작업 목록 (= 인자 없음)
/taskflow:load hongcafe_global_backend   ← 특정 product 잔존 작업 목록
/taskflow:load auth-refactor         ← 특정 작업 본문 + 잔여 항목 표시 (product 무관)
```

세션 재개 흐름 예시 (본 cwd = `C:\Users\PV\.claude` → product = `claude-harness`):

```
[사용자] /taskflow:load
   ↓
[Claude] ① 전체 잔존 스캔 (product 무관 · 잔여 미체크 ≥1 · Status 무관) → 6건:
           1. 2026-05-19 / infra / mono-lambda-precision-analysis  (Partial, 잔여 5)
           2. 2026-06-08 / infra / kor-jpn-build-ahead             (Plan Complete, 잔여 4)
           …  (본 cwd product=claude-harness 잔존 0건이어도 타 product 6건 모두 노출)
        ② 전체 목록 표시 + 특정 작업 진입 안내
   ↓
[사용자] /taskflow:load mono-lambda-precision-analysis
   ↓
[Claude] ② 해당 작업 본문 출력 + 잔여 5건 부각
        ③ 재진입 안내 (/taskflow:auto / 개별 지시 / 분기 처리)
   ↓
[사용자] /taskflow:auto 잔여 5건
   ↓
[Claude] (자동진행 모드 진입 → 작업 수행 → /taskflow:save 으로 마무리)
```

cwd 미스매치 예시 (본 cwd = `C:\Works\hongcafe_global_backend`, 본 product 잔존 0건):

```
[사용자] /taskflow:load latest
   ↓
[Claude] product=hongcafe_global_backend, 본 product 잔존 0건.
        타 product 잔존 5 건 중 최신: 2026-05-19 / infra / mono-lambda-precision-analysis
        진입 옵션 (①~③) 안내
   ↓
[사용자] /taskflow:load all                  ← 명시 진입 (또는 인자 없는 /taskflow:load 와 동일)
   ↓
[Claude] 전체 잔존 목록 표시
```

## 차별점 (다른 슬래시와)

| 슬래시 | 시점 | 동작 |
|--------|------|------|
| `/taskflow:auto` | 작업 시작·중간 | 묶음 승인 모드 진입 (실행, mutation 허용) |
| `/taskflow:save now` | 작업 완료 직후 | working/ → tasks/ 즉시 이동 모드, 판정 생략 (mutation) |
| `/taskflow:save` | 세션 마감 직전 | worktree + 문서 + 잔여 저장 (mutation) |
| **`/taskflow:load`** | **다음 세션 시작 직후 / 타 세션·에이전트** | **전체 product 잔존(잔여 미체크 ≥1, Status 무관) + DISPATCH `available`(`#tag`) 식별 + 본문 표시 + 빈 폴더 자동 정리 + `#tag` 배타적 claim(mutation: lock, 구 claim 흡수). `latest` 만 본 cwd product 자동 선택** |

## Changelog

- 2026-07-29: `{작업명}` 로드 시 `tick: allow` → `pause (by sid, 날짜)` 하강 (본 슬래시의 유일한 mutation). 복원 = `/taskflow:save`
- 2026-07-22: 자동 실행 금지 명문화 — `#tag`·`{작업명}` 미지정 호출은 출력 후 정지
- 2026-07-16: `#tag` 배타 claim·로드 흡수 (구 claim/consume)
- 2026-06-18: cwd 필터 기본 해제 — 인자 없음 = 전 product 잔여 노출
- 2026-06-15: 분배 풀 통합
- 2026-05-14: 신설
