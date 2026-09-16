#!/usr/bin/env bash
# code-loop.sh — 분리 개발↔리뷰 루프를 "스텝 1개 = 프로세스 1개" 로 돌린다 (2026-09-16)
#
# 왜 스텝마다 프로세스인가:
#   메인에서 루프를 돌리면 루프가 태우는 도구 호출이 전부 메인 컨텍스트에 영구
#   누적되고 매 턴 cache_read 로 다시 읽힌다. 2026-09-16 실측(tick/code 세션 40개)
#   — 본체 Bash 7,449회 209만 토큰(73%) · 본체 Read 458회 49.8만(17%) · subagent
#   반환 588회 23.7만(7.6%). subagent 반환은 이미 1,121자 안팎으로 절단돼 들어오므로
#   줄일 여지가 없고, 남는 경로는 프로세스를 끊는 것뿐이었다.
#
#   루프 전체를 headless 1개로 빼는 것으로는 부족하다 — 그 러너가 라운드를 warm 하게
#   들고 있으면 누적이 메인에서 러너로 옮겨갈 뿐이다. 그래서 라운드가 아니라 스텝을
#   프로세스 경계로 삼는다. 어느 프로세스도 2스텝을 보지 않으므로 누적이 구조적으로 0이다.
#   대가는 스텝마다 cache_write 다 (read 의 20배 단가) — 그래서 스텝 수를 늘리지 않는다.
#
# 상태는 어디 있나:
#   전부 결과문서다. 프로세스 간에 넘어가는 것은 파일뿐이고, 셸은 VERDICT 줄만 읽어
#   분기한다. 판단(C·H·M 집계·반박 근거 3종 확인)은 여전히 모델이 하되 그 모델도 단발이다.
#
# 사용:
#   code-loop.sh "{구현 요청}"      루프 1회, RESULT.md 를 stdout 으로
#   code-loop.sh --resume {run}     중단된 run 을 마지막 스텝 다음부터
#   code-loop.sh status             run 목록
#
# 환경변수: CODE_LOOP_PERM(기본 auto) / CODE_LOOP_MODEL_{SPEC,DEV,REV,ADV}
# SSOT: custom-plugin/taskflow/commands/code-loop.md
set -uo pipefail

CLAUDE_HOME="$HOME/.claude"
STATE_DIR="$CLAUDE_HOME/state/code-loop"
CMD_DIR="$CLAUDE_HOME/custom-plugin/taskflow/commands"
AGENT_DIR="$CLAUDE_HOME/custom-plugin/taskflow/agents"
PERM="${CODE_LOOP_PERM:-auto}"

# 스텝별 모델 — 에이전트 정의 frontmatter 와 일치시킨다 (정의가 SSOT, 여기는 사본)
M_SPEC="${CODE_LOOP_MODEL_SPEC:-sonnet}"
M_DEV="${CODE_LOOP_MODEL_DEV:-sonnet}"
M_REV="${CODE_LOOP_MODEL_REV:-sonnet}"
# adversary 는 opus 고정이다. 이 역할만 "리뷰어가 통과시킨 것을 깨는" 일이고,
# 클린을 못 깨면 루프가 거기서 끝나므로 마지막 방어선의 판단력은 내리지 않는다
M_ADV="${CODE_LOOP_MODEL_ADV:-opus}"

DEV_CAP=5   # 정규 라운드 캡 (code.md §"루프 종료 조건")
ADV_CAP=2   # 적대적 게이트 캡 (code.md §"적대적 검증 게이트")

mkdir -p "$STATE_DIR"

make_slug() {
  local s
  s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//' | cut -c1-40)
  [ -n "$s" ] || s="run"
  printf '%s' "$s"
}

usage() { sed -n '2,30p' "$0" | sed 's/^# \?//'; }

cmd_status() {
  local found=0 d run rounds state
  for d in "$STATE_DIR"/*/; do
    [ -d "$d" ] || continue
    found=1; run=$(basename "$d")
    rounds=$(find "$d" -maxdepth 1 -name 'rev-*.md' 2>/dev/null | wc -l | tr -d ' ')
    if [ -f "$d/RESULT.md" ]; then state="완료"; else state="미완"; fi
    printf '%-46s %s  리뷰라운드 %s\n' "$run" "$state" "$rounds"
  done
  [ "$found" = 1 ] || echo "run 없음"
}

# 스텝 1개 = claude -p 1회. 출력 파일이 생겼는지로 성공을 판정한다 — exit 0 은
# 모델이 "못 하겠다"고 말하고 끝난 경우에도 나오므로 성공 신호가 못 된다
# $1 라벨 / $2 모델 / $3 산출 파일 / $4 프롬프트
run_step() {
  local label="$1" model="$2" out="$3" prompt="$4" rc try=0
  while [ "$try" -lt 2 ]; do
    try=$((try + 1))
    echo "--- $(date '+%T') [$label] model=$model try=$try"
    cd "$CLAUDE_HOME" || return 1
    claude -p --model "$model" --permission-mode "$PERM" "$prompt" < /dev/null 2>&1 \
      | sed 's/^/    /'
    rc=${PIPESTATUS[0]}
    if [ -s "$out" ]; then
      echo "--- [$label] ok ($(wc -c < "$out") bytes)"
      return 0
    fi
    echo "--- [$label] 산출 파일 없음: $out (exit=$rc)"
  done
  return 1
}

# 결과문서 끝의 기계 판독용 한 줄. 없으면 계약 위반이므로 빈 값을 돌려 fail-closed
verdict_of() {
  grep -h '^VERDICT:' "$1" 2>/dev/null | tail -1 | sed 's/^VERDICT:[[:space:]]*//'
}

# 에이전트 정의 전문을 프롬프트 앞에 붙인다. 이 프로세스가 곧 그 에이전트다
# (Agent 도구로 spawn 하는 게 아니라 프로세스 자체가 역할을 수행한다)
step_prompt() {
  printf '%s\n\n---\n\n%s\n' "$(cat "$1")" "$2"
}

run_loop() {
  local request="$1" run="$2" resume="${3:-}" dir="$STATE_DIR/$2"
  mkdir -p "$dir"
  echo "=== $(date '+%F %T') code-loop 시작 (run=$run perm=$PERM)"
  echo "=== 결과문서: $dir"

  local common="결과문서 디렉토리: $dir
루프 계약 SSOT = $CMD_DIR/code.md · 결과문서 규약 SSOT = $CMD_DIR/code-loop.md
필요한 문서는 직접 Read 한다. 머지·push 하지 않는다."

  # ── 1단계: 범위 확정 + worktree ───────────────────────────────────────
  if [ ! -s "$dir/00-spec.md" ]; then
    local spec_body="$common

code.md 의 1단계(범위 확인)와 크기 게이트를 그대로 수행해 $dir/00-spec.md 를 쓴다.
담을 것: 요청 · 성공 기준(검증 가능하게) · 테스트 범위(케이스 단위) · 비목표 ·
커밋 type·scope · worktree 경로 · 형식 변경이면 파급면·결함면.
worktree 는 여기서 실제로 만들고 그 절대 경로를 문서에 박는다.
마지막 줄에 기계 판독용으로 정확히 한 줄을 쓴다:
  GATE: OK          (성공 기준 3개 이하 — 진행)
  GATE: TOO-LARGE   (4개 이상 — /taskflow:plan 으로 넘길 것)

구현 요청:
$request"
    if ! run_step spec "$M_SPEC" "$dir/00-spec.md" "$spec_body"; then
      echo "!!! 1단계 실패 — 중단"
      return 1
    fi
  fi

  if grep -q '^GATE:[[:space:]]*TOO-LARGE' "$dir/00-spec.md"; then
    echo "=== 크기 게이트: 성공 기준 4개 이상 — 이 커맨드로 받지 않는다."
    echo "=== /taskflow:plan 경로를 쓴다. spec: $dir/00-spec.md"
    return 2
  fi

  # ── dev-loop ──────────────────────────────────────────────────────────
  local n nn verdict=""
  for n in $(seq 1 "$DEV_CAP"); do
    nn=$(printf '%02d' "$n")
    echo "=== dev-loop 라운드 $n/$DEV_CAP"

    if [ ! -s "$dir/dev-$nn.md" ]; then
      local prev_rev="" whys=""
      if [ "$n" -gt 1 ]; then
        prev_rev="직전 지적: $dir/rev-$(printf '%02d' $((n - 1))).md 를 읽고 전건 처리한다."
        whys=$(ls "$dir"/dev-*.md 2>/dev/null | tr '\n' ' ')
      fi
      local dev_body="$common

너는 이 라운드의 개발자다. 앞 라운드를 기억하지 못하므로 문서로만 이어받는다.
먼저 $dir/00-spec.md 를 읽어 범위·성공 기준·비목표·worktree 경로를 확인한다.
${whys:+앞 라운드 기록: $whys — 각 파일의 WHY 섹션만 읽는다. 전문은 읽지 않는다.}
$prev_rev

구현 후 $dir/dev-$nn.md 를 쓴다. 섹션:
  FILES / TESTS / NOTES / BASELINE(착수 전·반환 전 같은 명령) / WHY
WHY 에는 무엇을 왜 그렇게 했는지 + 남겨둔 선택지와 이유 + 반박(REBUTTED)이면 근거
3종(도달 불가 / 상위 처리 / 비목표 매칭) 중 무엇인지를 적는다. 다음 라운드의 나는
이 WHY 만 보므로 여기 없으면 없는 것이다.
코드만 쓴다 — 커밋하지 않는다."
      if ! run_step "dev-$nn" "$M_DEV" "$dir/dev-$nn.md" \
           "$(step_prompt "$AGENT_DIR/step-developer.md" "$dev_body")"; then
        echo "!!! dev-$nn 실패 — 중단"
        return 1
      fi
    fi

    # 리뷰어 2인 병렬 — 판정축이 갈라져 있어 서로를 안 봐도 된다
    if [ ! -s "$dir/rev-$nn.md" ]; then
      local hist=""
      [ "$n" -gt 1 ] && hist="라운드 이력: $dir/rev-*.md — 이미 닫힌 판정을 다시 열지 않는다."
      local rev_body="$common

너는 이 라운드의 콜드 리뷰어다. $dir/00-spec.md (대조 기준) 와 $dir/dev-$nn.md
(이번 변경 + BASELINE) 를 읽고, worktree 의 diff 를 실제로 돌려 판정한다.
$hist"

      run_step "rev-$nn-correctness" "$M_REV" "$dir/rev-$nn-correctness.md" \
        "$(step_prompt "$AGENT_DIR/reviewer-correctness.md" \
           "$rev_body
판정 결과를 $dir/rev-$nn-correctness.md 에 쓴다.")" &
      local p1=$!
      run_step "rev-$nn-design" "$M_REV" "$dir/rev-$nn-design.md" \
        "$(step_prompt "$AGENT_DIR/reviewer-design.md" \
           "$rev_body
판정 결과를 $dir/rev-$nn-design.md 에 쓴다.")" &
      local p2=$!
      wait $p1; local r1=$?
      wait $p2; local r2=$?
      if [ $r1 -ne 0 ] || [ $r2 -ne 0 ]; then
        echo "!!! 리뷰어 실패 (correctness=$r1 design=$r2) — 중단"
        return 1
      fi

      # 합본 + 반박 판정 — code.md 가 "본체" 에 맡긴 일이고, 그 본체도 여기선 단발이다
      local merge_body="$common

두 리뷰어 판정을 합쳐 $dir/rev-$nn.md 를 쓴다.
  입력: $dir/rev-$nn-correctness.md · $dir/rev-$nn-design.md · $dir/dev-$nn.md · $dir/00-spec.md
  합본 규칙 SSOT = $CMD_DIR/watch.md 의 코드 축 절
  REBUTTED 가 있으면 code.md 의 반박 판정 절에 있는 근거 3종을 직접 확인해
  수용·기각을 판정하고, 수용분은 REBUTTED-ACCEPTED 로 표시한다 (다음 라운드 재개봉 차단).
  BASELINE 전·후 명령이 다르거나 없으면 그 사실을 적는다 (관측 실패 — 라운드로 세지 않는다).
마지막 줄에 기계 판독용으로 정확히 한 줄:
  VERDICT: CLEAN                      (Critical·High·Medium 모두 0)
  VERDICT: FINDINGS C=n H=n M=n       (하나라도 잔존)"
      if ! run_step "merge-$nn" "$M_SPEC" "$dir/rev-$nn.md" "$merge_body"; then
        echo "!!! 합본 실패 — 중단"
        return 1
      fi
    fi

    verdict=$(verdict_of "$dir/rev-$nn.md")
    echo "=== 라운드 $n 판정: ${verdict:-(VERDICT 줄 없음)}"
    case "$verdict" in
      CLEAN*)
        break ;;
      FINDINGS*)
        if [ "$n" -eq "$DEV_CAP" ]; then
          echo "=== 캡 $DEV_CAP 소진 — 적대적 게이트를 돌리지 않는다 (깰 것이 없다)"
        fi ;;
      *)
        echo "!!! VERDICT 줄이 없다 — 계약 위반. 중단"
        return 1 ;;
    esac
  done

  # ── adv-loop ──────────────────────────────────────────────────────────
  local adv_verdict="(skipped)"
  case "$verdict" in
    CLEAN*)
      local m mm nn2
      for m in $(seq 1 "$ADV_CAP"); do
        mm=$(printf '%02d' "$m")
        echo "=== adv-loop $m/$ADV_CAP"
        if [ ! -s "$dir/adv-$mm.md" ]; then
          local adv_body="$common

리뷰어들이 통과시킨 클린을 깬다. 입력:
  대조 기준      $dir/00-spec.md
  클린 판정 근거  $dir/rev-*.md 전문 (REBUTTED-ACCEPTED 포함)
  변경·BASELINE  $dir/dev-*.md + worktree diff
재현 없이 지적하지 않는다. 결과를 $dir/adv-$mm.md 에 쓰고 마지막 줄에 정확히 한 줄:
  VERDICT: UPHELD           (못 깼다 — 시도 나열 필수)
  VERDICT: BROKEN           (깼다 — 재현 명령·출력 필수)
  VERDICT: BROKEN-UNDECIDED (입력이 부족해 판정 못 함)"
          if ! run_step "adv-$mm" "$M_ADV" "$dir/adv-$mm.md" \
               "$(step_prompt "$AGENT_DIR/adversary.md" "$adv_body")"; then
            echo "!!! adv-$mm 실패 — 중단"
            return 1
          fi
        fi
        adv_verdict=$(verdict_of "$dir/adv-$mm.md")
        echo "=== adv 판정: ${adv_verdict:-(없음)}"
        case "$adv_verdict" in
          UPHELD*)
            break ;;
          BROKEN-UNDECIDED*)
            # 입력 조립이 틀린 것이지 코드 문제가 아니다 — 캡에 넣지 않고 재스폰
            rm -f "$dir/adv-$mm.md"
            echo "=== 입력 조립 오류 — 캡에 넣지 않고 재스폰"
            continue ;;
          BROKEN*)
            # code.md: BROKEN 수정분은 반드시 리뷰 1라운드를 거친다. 그 라운드는 정규 캡에
            # 계상한다 — 게이트 캡이 정규 캡을 늘리는 통로가 되면 클린 직전에 라운드가 무한히 열린다
            n=$((n + 1))
            if [ "$n" -gt "$DEV_CAP" ]; then
              echo "=== 정규 캡 소진 — 재현물을 잔여로 넘긴다"
              break
            fi
            echo "=== BROKEN — dev-loop 재진입 (라운드 $n, 정규 캡 계상)"
            nn2=$(printf '%02d' "$n")
            local fix_body="$common
적대적 검증이 깼다: $dir/adv-$mm.md 의 재현 명령·출력을 읽고 고친다.
범위는 $dir/00-spec.md 그대로다. $dir/dev-$nn2.md 를 쓴다 (FILES/TESTS/NOTES/BASELINE/WHY)."
            if ! run_step "dev-$nn2(adv)" "$M_DEV" "$dir/dev-$nn2.md" \
                 "$(step_prompt "$AGENT_DIR/step-developer.md" "$fix_body")"; then
              echo "!!! adv 수정 실패 — 중단"
              return 1
            fi
            echo "=== adv 수정분 리뷰는 재개 실행이 이어받는다 — --resume $run"
            ;;
          *)
            echo "!!! adv VERDICT 줄이 없다 — 계약 위반. 중단"
            return 1 ;;
        esac
      done ;;
  esac

  # ── 반환 ──────────────────────────────────────────────────────────────
  local result_body="$common

$dir 의 결과문서 전부를 읽고 메인 세션에 돌려줄 $dir/RESULT.md 를 쓴다.
담을 것: 변경 요약(파일·무엇을) · 라운드 로그(dev 라운드 수 · adv 회차 · 각 VERDICT) ·
잔여 핸드오프(범위밖·Low·재현물) · worktree 경로와 커밋 여부.
이것만 메인이 읽는다 — 여기 없는 것은 메인에 존재하지 않는다. 간결하게 쓴다."
  if ! run_step result "$M_SPEC" "$dir/RESULT.md" "$result_body"; then
    echo "!!! RESULT.md 생성 실패"
  fi

  echo "=== $(date '+%F %T') code-loop 종료 (dev=$verdict adv=$adv_verdict)"
  if [ -s "$dir/RESULT.md" ]; then
    echo
    echo "───────── RESULT.md ─────────"
    cat "$dir/RESULT.md"
    return 0
  fi
  echo
  echo "!!! RESULT.md 없음 — 이어서: code-loop.sh --resume $run"
  ls -1 "$dir" 2>/dev/null | sed 's/^/    /'
  return 1
}

case "${1:-}" in
  ""|-h|--help)
    usage ;;
  status)
    cmd_status ;;
  --resume)
    if [ -z "${2:-}" ]; then
      echo "run 이름이 필요하다. 목록 = code-loop.sh status"; exit 1
    fi
    if [ ! -s "$STATE_DIR/$2/00-spec.md" ]; then
      echo "재개 불가 (00-spec.md 없음): $2"; exit 1
    fi
    run_loop "" "$2" resume ;;
  *)
    run_loop "$1" "$(date '+%Y%m%d-%H%M%S')-$(make_slug "$1")" ;;
esac
