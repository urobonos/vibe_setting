---
description: 문서작업 — 특정 원본 파일(기획서/스펙/문서/코드)을 참조해 §분석·§계획을 채운 working/ 태스크 문서를 생성하고, 원본 경로 + 지문(sha256/size/mtime)을 박제해 이후 원본 변경을 감지한다. 점검 = `/taskflow:draft check`. 분석+계획까지 (실행은 `/taskflow:execute` 위임). 짝 = `/taskflow:execute`
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent
argument-hint: "<원본파일경로> [작업명]   |   check [작업명|all]"
---

특정 **원본 파일**을 참조해 분석·계획한 **working/ 태스크 문서**를 만들고, 그 문서에 **원본 경로 + 지문**을 박제한다. 이후 원본이 바뀌면 `/taskflow:draft check` 로 태스크가 stale 해졌는지 감지한다. 실제 코드 변경은 본 슬래시 비대상 — 생성된 태스크를 `/taskflow:execute` 으로 이어받는다.

## 두 모드

| 모드 | 호출 | 동작 |
|------|------|------|
| **생성** (기본) | `/taskflow:draft <원본파일경로> [작업명]` | 원본 정독 → §분석·§계획 채운 working 태스크 생성 + 원본 추적 지문 박제 |
| **점검** | `/taskflow:draft check [작업명\|all]` | 박제된 지문 vs 현재 원본 지문 비교 → 변경된 원본 경고 + 재점검 권고 |

## 핵심 원칙 — 원본 추적 (메타 박제 + 변경 감지)

> 동기화 강도 = **가벼운 박제 + 조회 시점 감지** (hook 없음, 가역). 원본↔태스크를 자동으로 양방향 변형하지 않는다. CLAUDE.md §4.4 "가역은 선제 강제 비추천, 사후 처리(데이터 가시화)" 부합.

- **박제:** 생성 시점 원본의 `sha256(앞12) / size / mtime` 을 태스크 문서 `## 원본 추적` 테이블에 스냅샷으로 기록. 위치 provenance 는 기존 `## 참조 출처` `[참조: ...]` 에 별도 기록 (`doc-unified-check.sh V2` 충족).
- **감지:** `check` 모드가 박제 지문 vs 현재 원본 지문을 비교. 다르면 `⚠ 변경됨` — **자동 갱신하지 않고 경고만** 한다 (재분석 여부는 사용자 결정).
- **권고:** 변경 감지 시 `/taskflow:draft` 재생성 (태스크 갱신) 을 안내.

## 생성 모드 — 동작 5단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① 원본 검증 + 지문 | 인자 경로 존재·읽기 확인 → `sha256(앞12)/size/mtime` 계산 | 원본 확정 + 지문 |
| ② 원본 정독 + 참조 보강 | 원본 전문 Read + 참조 범위(`indexing/{product}.md` 관련 항목) 보강 | 분석 입력 |
| ③ working 문서 생성 | `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 에 §분석 + §계획 채움 (`/taskflow:analyze`·`/taskflow:plan` 양식 재사용) | 태스크 문서 |
| ④ 원본 추적 박제 | §공통에 `## 참조 출처` `[참조: <원본>]` + `## 원본 추적` 지문 테이블 기록 | 추적 가능 태스크 |
| ⑤ 요약 + 다음 안내 | 작업명·원본·잔여 step 요약 + `/taskflow:execute`·`check` 진입 안내 | 다음 단계 진입점 |

> ②③ 분석·계획 양식은 `/taskflow:analyze`(관점별·Critical~Low·우선순위)·`/taskflow:plan`(WBS·step 분해) 의 working/ 섹션 골격과 동일. 본 슬래시는 그 앞에 **"특정 원본 파일 입력 + 지문 박제"** 를 더한 것. 양식 SSOT = `~/.claude/skills/task-docs/references/unified-template.md`.

## ④ 원본 추적 블록 양식 (태스크 문서 §공통에 박제)

```markdown
## 참조 출처 (Reference Location)
| # | 내용/섹션 | 출처 유형 | 참조위치 |
|---|----------|----------|---------|
| 1 | 본 태스크 전체 근거 원본 | 기획서/docs/코드 | [참조: <원본 경로 또는 파일명 위치>] |

## 원본 추적 (Source Tracking)
> `/taskflow:draft` 생성. 원본 변경 감지용 지문 스냅샷(생성 시점). 점검 = `/taskflow:draft check {작업명}`.

| # | 원본 | 경로 | sha256(앞12) | size | mtime (생성 시점) |
|---|------|------|--------------|------|-------------------|
| 1 | {원본명} | `{절대경로}` | `3b78649e2304` | 7643B | 2026-06-10 10:42:48 |
```

> **`## 참조 출처`(위치 provenance) 와 `## 원본 추적`(변경 감지 지문) 은 별개 역할.** 전자는 `doc-unified-check.sh V2` 강제 필드(어디서 차용했나), 후자는 본 슬래시 신규(원본이 바뀌었나). 둘 다 기록.

### ① 지문 계산 (Bash)

```bash
# $ARGUMENTS = harness 프롬프트 치환. bash 블록은 위치 인자($1)를 상속하지 않으므로 명시적으로 재구성
set -- $ARGUMENTS
SRC="${1/#\~/$HOME}"                        # 원본 경로. $ARGUMENTS 는 리터럴이라 선행 ~ 를 $HOME 로 명시 확장
[ -f "$SRC" ] || { echo "원본 없음: $SRC"; exit 1; }
SRC_ABS=$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")
HASH=$(sha256sum "$SRC" | cut -c1-12)
SIZE=$(stat -c %s "$SRC")
MTIME=$(stat -c %y "$SRC" | cut -d'.' -f1)
echo "원본: $SRC_ABS | sha256:$HASH | ${SIZE}B | $MTIME"
```

## 점검 모드 — `/taskflow:draft check [작업명|all]`

박제된 지문 vs 현재 원본 지문을 비교한다 (read-only, 변경만 보고).

```bash
# 대상 문서 수집: 작업명 매칭(working/+tasks/) 또는 all(## 원본 추적 보유 전체)
set -- $ARGUMENTS                           # $ARGUMENTS → 위치 토큰 ($1=check, $2=작업명/all)
ARG="${2:-all}"
if [ "$ARG" = "all" ]; then
  DOCS=$(grep -lE '^## 원본 추적' ~/.claude/docs/working/*/*.md ~/.claude/docs/*/tasks/*/*/*.md 2>/dev/null)
else
  DOCS=$(ls ~/.claude/docs/working/*/*-${ARG}.md ~/.claude/docs/*/tasks/*/${ARG}/*.md 2>/dev/null)
fi

for DOC in $DOCS; do
  echo "── $(basename "$DOC")"
  # ## 원본 추적 섹션의 데이터 행만 파싱 → 경로(3열)·지문(4열)
  awk '/^## 원본 추적/{f=1;next} /^## /{f=0} f&&/^\| *[0-9]/{print}' "$DOC" \
    | while IFS='|' read -r _ num name path hash rest; do
        p=$(echo "$path" | tr -d '`' | sed 's/^ *//;s/ *$//')
        h=$(echo "$hash" | tr -d '`' | sed 's/^ *//;s/ *$//')
        [ -z "$p" ] && continue
        if [ ! -f "$p" ]; then echo "  ✗ 원본 없음: $p"; continue; fi
        cur=$(sha256sum "$p" | cut -c1-12)
        if [ "$cur" = "$h" ]; then
          echo "  ✓ 최신: $p"
        else
          echo "  ⚠ 변경됨: $p  (박제 $h → 현재 $cur)"
        fi
      done
done
```

변경(`⚠`) 발견 시 출력 말미에 안내:

```
  변경된 원본 N건 — 권고:
  /taskflow:draft <원본> {작업명}  ← 태스크 재생성 (원본 최신 반영)
```

## 인자

> bash 블록은 harness 프롬프트 치환값 `$ARGUMENTS` 를 `set -- $ARGUMENTS` 로 위치 토큰 분해한 뒤 `$1`/`$2` 로 참조한다 (bash 블록은 위치 인자를 상속하지 않음 — 직접 `$1` 참조 시 항상 빈 값).

- **생성:** `$1` = 원본 파일 경로 (필수). `$2` = 작업명 kebab-case (생략 시 원본 파일명 slug 자동 — 예: `design-v2.md` → `design-v2`).
- **점검:** `$1` = `check`. `$2` = 작업명 또는 `all` (생략 시 `all`).

## 강제 hook

| Hook | 검증 | 비고 |
|------|------|------|
| `doc-unified-check.sh V2` | `## 참조 출처` + `[참조: ...]` ≥ 1건 | working/ 면제, tasks/ 이동 후 검증 — ④에서 미리 충족 |
| `doc-unified-check.sh V1` | unified §분석·§계획 헤더 | working/ 면제, tasks/ 이동 시 검증 |
| `doc-unified-check.sh V4` | unified 체크리스트 임계 | working/ 면제, tasks/ 이동 시 검증 |

> `## 원본 추적` 은 신규 섹션 — 강제 hook 없음(가벼운 박제 원칙). `check` 가 유일한 소비자.

## §3 Checkpoint 우선 적용

- 본 슬래시 = working/ 문서 생성 (Gate-0 면제 경로) + 원본 **읽기**. 원본 파일을 **수정하지 않는다** (단방향 read).
- **분석·계획까지만.** 실제 코드 변경은 생성된 태스크를 `/taskflow:execute`·`/taskflow:auto` 이 이어받는 시점에 worktree 강제 + §3 guard 적용.
- 원본·태스크가 §3 매칭(외부 시스템·비가역) 작업을 기술하면 태스크 §계획에 "§3 — 실행 시 사용자 명시 승인 필수" 명시.
- `check` = read-only (sha256 비교만). 변경 감지해도 **자동 갱신 안 함** (사용자 결정).

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/skills/task-docs/references/unified-template.md` | 태스크 문서 §분석·§계획·§공통 골격 (본 슬래시가 채우는 양식) |
| `~/.claude/custom-plugin/taskflow/commands/analyze.md` · `~/.claude/custom-plugin/taskflow/commands/plan.md` | §분석·§계획 채움 절차 (본 슬래시가 재사용) |
| `~/.claude/hooks/doc-unified-check.sh V2` | `## 참조 출처` 강제 (④에서 충족) |
| **`~/.claude/custom-plugin/taskflow/commands/execute.md`** | **생성된 태스크의 다음 소비자 — 코드 변경 + step 순차 소비** |
| `~/.claude/hooks/lib/product-resolver.sh` | working 파일명 `{product}` 산출 |

## 호출 예

```
/taskflow:draft ~/.claude/docs/참조문서/기획협의통합문서.md            ← 기획서 기반 태스크 생성 (작업명 자동)
/taskflow:draft ~/Downloads/api-spec-v2.yaml api-v2-reflect           ← 스펙 파일 + 명시 작업명
/taskflow:draft app/Modules/Member/Services/MemberService.php member-refactor  ← 코드 파일 기반
/taskflow:draft check member-refactor                                 ← 특정 태스크 원본 변경 점검
/taskflow:draft check all                                             ← 원본 추적 보유 전체 점검
```

## 차별점 (다른 슬래시와)

| 슬래시 | 입력 | 산출 | 원본 추적 |
|--------|------|------|----------|
| `/taskflow:analyze` · `/taskflow:plan` | 작업명 (참조문서 자동 스캔) | working §분석·§계획 | 없음 (참조 출처 기록만) |
| **`/taskflow:draft`** | **특정 원본 파일 경로** | **working §분석·§계획 + 지문 박제** | **있음 (`check` 로 변경 감지)** |
| `/taskflow:execute` | 계획 완료 태스크 | 코드 변경 | - |

## Changelog

- 2026-06-23: 신설
