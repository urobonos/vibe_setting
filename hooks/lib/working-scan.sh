#!/usr/bin/env bash
# working-scan.sh — working/ 태스크 문서 훑기 단일 SSOT (2026-07-23)
#
# 목적: working/ 스캔을 tick·control·load 에서 매번 인라인 grep 으로 재작성하던 drift 제거.
#       한 함수가 working/ 모든 문서(unified + step 평면)를 파싱해 구조화 TSV 로 반환.
#
# 2026-07-23 재작성: bash 이중 루프(파일마다 grep/echo/basename/sed 서브셸 + docs/*/ 이중 루프
#   = Windows Git Bash fork 수백~천 프로세스, 100초+) → find + awk 단일 패스(프로세스 2~3개).
#   + status 파싱을 '첫 상태 키워드'만 추출 — 실제 문서의 '상태: Partial (긴 부연 설명…)' 을
#     통째로 잡아 tick 의 정확 매칭(Pending/ReadyToMerge)이 실패하던 버그 수정.
#
# 사용:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/working-scan.sh"   # hooks/ 기준
#   working_scan [product|all] [min_age_min]
#   - min_age_min : 생략(0) = 필터 없음(기존 동작). N>0 = 최종 수정된 지 N분 초과인 문서만
#     (find -mmin +N). 방금 다른 세션이 저장한 문서를 무인이 바로 채가는 경합 완화용 — tick 전용.
#
# 출력 (TSV, 문서 1개당 1줄):
#   파일경로 \t date(YYYY-MM-DD) \t product \t 작업명 \t status \t is_step(0|1)
#   - status  = 문서 첫 '^Status:'(unified) / '^상태:'(step frontmatter) 라인의 **첫 상태 키워드**
#               (Plan Complete/In Progress/ReadyToMerge/NeedsDecision/Pending/Partial/Done/초안 등).
#               '상태: Partial (부연…)' → 'Partial'. 없으면 '-'.
#   - is_step = 1(파일명 '-step-NN-') / 0(unified)
#   - product = docs/{product}/ 디렉토리 prefix 매칭(가장 긴 것 우선). filter 지정 시 그 product 만.

WORKING_ROOT="${WORKING_ROOT:-$HOME/.claude/docs/working}"
WORKING_SCAN_DOCS_ROOT="${WORKING_SCAN_DOCS_ROOT:-$HOME/.claude/docs}"

working_scan() {
  local filter="${1:-all}" min_age_min="${2:-0}"
  [ -d "$WORKING_ROOT" ] || return 0

  # product 목록 1회 산출 (docs/*/ basename, working·references 제외) — 파일마다 순회 안 함
  local prod_list
  prod_list=$(cd "$WORKING_SCAN_DOCS_ROOT" 2>/dev/null && ls -d */ 2>/dev/null \
    | sed 's:/$::' | grep -vxE 'working|references' | tr '\n' ' ')

  local age_opt=()
  [ "${min_age_min:-0}" -gt 0 ] 2>/dev/null && age_opt=(-mmin "+$min_age_min")

  # find(1) + awk(1) 단일 패스 — 파일명 파싱·product 매칭·status 첫 키워드 전부 awk 내부
  find "$WORKING_ROOT" -mindepth 2 -maxdepth 2 -name '*.md' "${age_opt[@]}" -print0 2>/dev/null | xargs -0 -r awk \
    -v filter="$filter" -v products="$prod_list" '
    function emit() {
      if (path=="" || product=="") return
      if (filter!="all" && product!=filter) return
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", path, date, product, task, status, is_step
    }
    BEGIN {
      np=split(products, P, " ")
      # 상태 키워드 — 실제 status 값이 부연보다 앞서 매칭되도록 두 단어형·특이형을 앞에 둔다
      nk=split("Plan Complete|Analysis Complete|In Progress|ReadyToMerge|NeedsDecision|Pending|Partial|Done|초안|완료|폐기|Abandoned", KW, "|")
    }
    FILENAME != seen {
      emit()
      seen=FILENAME; path=FILENAME
      n=split(FILENAME, pp, "/"); fname=pp[n]
      # 날짜 폴더(YYYYMMDD)만 태스크로 본다 — backlog/·dispatch/ 등 비-날짜 폴더는 사용자 관리
      #   잔여물이지 tick 이 claim 할 대상이 아니다. product 매칭에 기댈 수 없다 — 파일명 규약
      #   `{yyyy-mm-dd}-{slug}.md` 에 product 토큰이 없는데 slug 앞머리가 docs/ 디렉토리명과
      #   겹치면 통과한다(실측: `hooks-guard-followups` → product=hooks). `^[0-9]{8}$` 는 이미
      #   working-heartbeat.sh·working-lifecycle.sh·working-register.sh·output-naming-check.sh·
      #   load.md 5곳이 쓰는 판정식 — 그대로 재사용해 극성이 갈라지는 걸 막는다.
      #   find 의 -not -path 가 아니라 여기서 거르는 이유: root 자신에 backlog 성분이 있으면
      #   (예: WORKING_ROOT=…/backlog/working) find 패턴이 전 태스크를 조용히 삼킨다(실측).
      #   -mindepth/-maxdepth 2 라 pp[n-1] 은 항상 root 직속 폴더다.
      if (pp[n-1] !~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/) { path=""; next }
      if (fname ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { date=substr(fname,1,10) } else { path=""; next }
      rest=substr(fname,12); sub(/\.md$/,"",rest)
      is_step=(fname ~ /-step-[0-9]+-/)?1:0
      product=""; task=""; best=0
      for (i=1;i<=np;i++) {
        pfx=P[i]"-"
        if (substr(rest,1,length(pfx))==pfx && length(P[i])>best) { product=P[i]; task=substr(rest,length(pfx)+1); best=length(P[i]) }
      }
      if (is_step) sub(/-step-[0-9]+-.*$/,"",task)
      status="-"; got=0
    }
    !got && /^(Status|상태):/ {
      line=$0; sub(/^(Status|상태):[[:space:]]*/,"",line)
      for (i=1;i<=nk;i++) if (index(line,KW[i])) { status=KW[i]; break }
      got=1
    }
    END { emit() }
  '
}

# 미해소 반려 지적 수 — `### 반려 N회` 블록 ~ 다음 `## ` 헤더 전까지의 `- [ ]` 개수.
#   working_rejections <문서경로>   → 정수 1줄 (0 = 없음 / 파일 없음)
#
# 왜 별도 함수인가: step 파일의 완료 게이트(working_gate_blockers)는 `상태:` 만 보고
#   미체크박스를 보지 않는다(미체크박스 검사 = is_step=0 전용). 그래서 watch 반려 지적은
#   게이트를 전혀 막지 못하고, 이 축을 보는 주체가 watch(머지 차단)와 tick(반려 소비 모드)
#   둘뿐이다. 판정식이 두 커맨드 문서에 복붙되면 곧 갈라지므로 여기가 SSOT.
#   소비처: custom-plugin/taskflow/commands/{watch,tick}.md
working_rejections() {
  [ -f "$1" ] || { echo 0; return 0; }
  awk '/^#+ 반려 [0-9]+회/{inb=1;next} inb && /^## /{inb=0} inb && /^[[:space:]]*- \[ \]/{c++} END{print c+0}' "$1"
}

# 정체 문서 — "진행 주체가 있어야 하는데 없는" 것만 뽑는다.
#   working_stalled [product|all] [min_age_sec]   (기본 WORKING_STALL_SEC=3600 = 1시간)
#
# 출력 (TSV, 문서 1개당 1줄):
#   경과분 \t status \t is_step \t claim \t product \t 작업명 \t 경로
#   - claim = REGISTRY 의 그 slug 상태(active/paused/needs-decision/ready-to-merge) 또는 none.
#             step 은 `{작업명}-step-NN` slug 로, unified 는 `{작업명}` 로 조회한다.
#             같은 slug 에 sid 가 여럿이면 active 를 우선 채택(하나라도 살아있으면 점유 중).
#
# 제외 상태 = NeedsDecision(사용자 판단 대기) · Done/완료/폐기/Abandoned(종결) ·
#   Partial(사용자 마감분) · ReadyToMerge(watch B 트랙 소관). 남는 건 In Progress·Pending·
#   Plan Complete·Analysis Complete·초안·무상태(-) 뿐이라 "누가 진행했어야 하는데 멈춘 것"만 남는다.
#   이 제외가 없으면 실측상 Done 32 + Partial 8 + NeedsDecision 5 = 45건이 매 iteration
#   정체로 잡혀 노이즈가 신호를 덮는다 (2026-07-29 실측).
#
# 결정 대기 제외는 **두 축 모두**다 — 문서 `상태:` 가 NeedsDecision 이 아니어도 REGISTRY claim
#   이 needs-decision 이면 그 작업은 사용자 판단에 걸려 있다. 실측 2건(문서 Pending ↔ claim
#   needs-decision)이 이 경우라, 상태 축만 보면 결정 대기건을 정체로 오분류해 건드리게 된다.
#
# 나이 필터는 working_scan 의 min_age_min 을 그대로 재사용한다 — 파일마다 stat 서브셸을
#   띄우지 않기 위함(이 파일이 재작성된 이유와 같은 제약). stat 은 상태 제외를 통과한
#   소수 건에만 경과분 산출용으로 돈다.
#
# **정체를 나열하는 게 아니라 병목을 특정한다.** 각 후보에 tick 의 claim 게이트를 순서대로
#   물어 **첫 실패 게이트**를 낸다. "왜 안 잡히나" 에 답이 없으면 해소할 것도 없기 때문이다.
#   실측(2026-07-29)으로 이 구분이 필요함이 드러났다 — 정체 12건 중 마커 부재 0건,
#   REGISTRY active 0건이었고 대부분은 **tick 이 지금도 잡을 수 있는데 도는 tick 이 없을 뿐**
#   이었다. 그건 병목이 아니라 미가동이라 watch 가 제거할 대상이 아니다.
#
# 게이트 (tick.md §1~2단계 순서 그대로):
#   G1 마커     `tick: allow` 없음            → report (자동 부착 = §3 사용자 결정)
#   G2 사용자   unified NeedsDecision/Done    → report (사용자 영역)
#   G3 claim    REGISTRY active               → 세션 살아있으면 none(진행 중) / 죽었으면 stale
#   G4 상태     step 이 Pending 이 아님       → pending 복귀 (tick 진행 조건 밖이므로 영구 이탈)
#   OK          전부 통과                     → 병목 없음. claim 가능한데 루프가 안 돔
#
#   G4 는 step 전용이다. unified 의 In Progress·Plan Complete·초안·무상태는 tick 2단계상
#   **유효 진입 상태**라 병목이 아니다 (그 표를 보면 In Progress = "이어감").
#
#   선행 의존(tick §2-bis)은 별도 게이트로 두지 않는다 — 선행이 막는 유일한 해소 가능 사유가
#   "선행이 죽은 In Progress" 이고 그건 그 선행 자신이 G4 로 잡히기 때문이다. G4 를 고치면
#   그 step 에 의존하던 후속들이 함께 풀린다. 인덱스 표 '의존' 컬럼 파싱은 하지 않는다
#   (형식 편차가 커서 파서가 곧 깨진다 — `## 변경 파일` 을 거부한 것과 같은 이유).
#
# 출력 (TSV, 문서 1개당 1줄):
#   경과분 \t status \t is_step \t claim \t gate \t 처리 \t product \t 작업명 \t 경로
#   - claim = REGISTRY 의 그 slug 상태 또는 none. step 은 `{작업명}-step-NN`, unified 는 `{작업명}`.
#             같은 slug 에 sid 가 여럿이면 active 우선(하나라도 살아있으면 점유 중).
#   - 처리  = stale(claim 해제) / pending(상태 복귀) / report(보고) / none(손대지 않음)
#
#   소비처: custom-plugin/taskflow/commands/watch.md (§"C 트랙 — 정체 해소")

# sid8 세션 생존 판정 — transcript mtime 이 WORKING_SESSION_DEAD_SEC(기본 3600) 안이면 살아있다.
#   REGISTRY active 인데 세션이 죽었으면 registry_claim 이 영원히 TAKEN 을 반환해(그 함수는
#   $7=="active" 만 보고 막는다) tick 이 그 slug 를 다시는 못 잡는다 — 그게 G3 병목이다.
working_session_alive() {
  local sid8="$1" newest mt
  [ -n "$sid8" ] && [ "$sid8" != "-" ] || return 1
  newest=$(ls -t "$HOME"/.claude/projects/*/"$sid8"*.jsonl 2>/dev/null | head -1)
  [ -n "$newest" ] || return 1
  mt=$(stat -c %Y "$newest" 2>/dev/null) || return 1
  [ $(( $(date +%s) - mt )) -lt "${WORKING_SESSION_DEAD_SEC:-3600}" ]
}

working_stalled() {
  local scope="${1:-all}" min_age_sec="${2:-${WORKING_STALL_SEC:-3600}}"
  local reg="${REGISTRY_PATH:-$HOME/.claude/docs/working/REGISTRY.md}"
  local min_min=$(( min_age_sec / 60 ))
  [ "$min_min" -lt 1 ] && min_min=1

  local now all_docs path status is_step claim claim_sid prod task mt age uni ustatus gate act
  now=$(date +%s)
  all_docs=$(working_scan "$scope")          # 나이 무관 전체 — unified 상태·마커 조회용

  working_scan "$scope" "$min_min" | awk -F'\t' -v reg="$reg" '
    BEGIN {
      while ((getline line < reg) > 0) {
        if (line !~ /^\|/) continue
        if (split(line, C, "|") < 8) continue
        s = C[2]; sid = C[4]; st = C[7]
        gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", sid)
        gsub(/^[ \t]+|[ \t]+$/, "", st)
        if (s == "" || s == "slug" || s ~ /^-+$/) continue
        if (!(s in R) || st == "active") { R[s] = st; D[s] = sid }
      }
      close(reg)
    }
    {
      path = $1; prod = $3; task = $4; status = $5; is_step = $6
      if (status == "NeedsDecision" || status == "Done" || status == "완료" ||
          status == "폐기" || status == "Abandoned" || status == "Partial" ||
          status == "ReadyToMerge") next

      slug = task
      if (is_step == 1) {
        # 파일명에서 step 번호를 뽑아 REGISTRY slug(`{작업명}-step-NN`) 를 복원
        nn = path
        if (match(nn, /-step-[0-9]+-/)) slug = task substr(nn, RSTART, RLENGTH - 1)
      }
      claim = (slug in R) ? R[slug] : "none"
      if (claim == "needs-decision") next      # 사용자 판단 대기 — 상태 축과 별개로 제외
      # 빈 필드를 내보내지 않는다 — `IFS=$'\t' read` 는 탭이 IFS 공백류라 연속 탭을 하나로
      # 합쳐서, 빈 칸 하나가 뒤 필드를 통째로 밀어버린다(실측: task 가 비어 unified 조회가
      # 전건 실패 → 전부 G1 오판). 없는 값은 "-" 로 채운다.
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", path, status, is_step, claim,
             ((slug in D && D[slug] != "") ? D[slug] : "-"), prod, task
    }
  ' | while IFS=$'\t' read -r path status is_step claim claim_sid prod task; do
    mt=$(stat -c %Y "$path" 2>/dev/null) || continue
    age=$(( (now - mt) / 60 ))

    uni=$(printf '%s\n' "$all_docs" | awk -F'\t' -v t="$task" -v p="$prod" '$3==p && $4==t && $6==0 {print $1"\t"$5; exit}')
    ustatus=${uni#*$'\t'}; uni=${uni%%$'\t'*}
    # G2 는 **문서 전체의 Status/상태 줄**을 본다 — working_scan 은 첫 줄만 읽는데,
    # frontmatter 와 본문이 어긋난 문서가 실측 3건 있다(예: frontmatter NeedsDecision ↔
    # 본문 In Progress). 첫 줄만 믿고 진행 판정을 내리면 결정 대기건을 무인 진행시킨다.
    # 그래서 **어느 줄에라도** NeedsDecision/Done 이 있으면 막는 쪽(보수)으로 채택한다.
    # 어느 쪽이 정본인지 판정하지 않는다 — 그건 문서 형식 추론이라 틀리면 사고가 크다.
    [ -n "$uni" ] && grep -qE '^(Status|상태):.*(NeedsDecision|Done)' "$uni" 2>/dev/null \
      && ustatus="NeedsDecision"

    if [ -z "$uni" ] || ! grep -qE '^(tick|무인):[[:space:]]*(allow|허용)' "$uni" 2>/dev/null; then
      gate="G1-마커없음";   act="report"
    elif [ "$ustatus" = "NeedsDecision" ] || [ "$ustatus" = "Done" ]; then
      gate="G2-사용자대기"; act="report"
    elif [ "$claim" = "active" ]; then
      if working_session_alive "$claim_sid"; then gate="G3-진행중"; act="none"
      else                                        gate="G3-orphan"; act="stale"; fi
    elif [ "$is_step" = "1" ] && [ "$status" != "Pending" ]; then
      gate="G4-미Pending";  act="pending"
    else
      gate="OK";            act="none"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$age" "$status" "$is_step" "$claim" "$gate" "$act" "$prod" "$task" "$path"
  done | sort -rn
}

# task 완료 게이트 — 특정 task 의 unified + 모든 step 을 스캔해 미해결건을 라인별로 출력.
# 출력이 있으면(=미해결 존재) 완료(Done) 차단. 출력 0줄 = 게이트 통과.
#   working_gate_blockers <product> <작업명>
# 검사: 미머지 step(ReadyToMerge/Done 외) / step NeedsDecision / unified NeedsDecision / 미체크박스 / 잔여 섹션
working_gate_blockers() {
  local product="$1" taskname="$2"
  [ -n "$product" ] && [ -n "$taskname" ] || return 0
  local path date prod task st is_step
  working_scan "$product" | while IFS=$'\t' read -r path date prod task st is_step; do
    [ "$task" = "$taskname" ] || continue
    if [ "$is_step" = 1 ]; then
      case "$st" in
        ReadyToMerge|Done|완료) : ;;
        NeedsDecision) echo "판단 대기 step: $(basename "$path")" ;;
        *) echo "미처리 step: $(basename "$path") (상태=$st)" ;;
      esac
    else
      [ "$st" = "NeedsDecision" ] && echo "판단 미해결: NeedsDecision"
      grep -qE '^\s*- \[ \]' "$path" 2>/dev/null && echo "미체크박스 잔존: $(grep -cE '^\s*- \[ \]' "$path")건"
      grep -qE '^##[[:space:]]+(잔여|TODO|Follow-up)' "$path" 2>/dev/null && echo "잔여 섹션 존재"
    fi
  done
}
