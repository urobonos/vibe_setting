#!/bin/bash
# ISS 단위 선착순 claim — 다세션이 같은 결함 번호를 동시에 집는 것을 막는다.
#
# 왜 REGISTRY 로 안 되나: REGISTRY 는 **slug 축**이다. 같은 ISS 를 세션마다 다른 slug 로
# 잡으면(iss-basemodel-axis-batch / iss-batch-axis-12) 충돌이 그 표에 안 보인다.
#
# 왜 grep 으로 안 세나: 2026-09-16 실측 — 같은 5세션을 본문 `ISS-\d{3}` 로 세면 겹침 7건,
# step 파일명으로 세면 0건이 나왔다. 본문은 **참조를 소유로** 읽고(문서 drift 점검 대상으로
# 언급한 번호까지 잡는다), 파일명은 명명 관습에 의존해 과소집계한다. 추정 축이 둘 다 틀리므로
# **선언만 본다** — working 통합 문서 frontmatter 의 `ISS:` 한 줄이 claim 축이다.
#
#   ISS: ISS-137 ISS-162 ISS-181     # 이 세션이 고치는 번호
#   ISS: 없음                         # ISS 작업 아님 (빈 칸 금지 — 규약 §1)
#
# 선착 판정 = REGISTRY `started` 오름차순, 동률이면 sid 사전순(결정적). 죽은 세션은
# claim 을 양보한다 — 안 그러면 종료된 세션이 그 번호를 영구 동결시킨다.
# `paused` 는 점유 유지다 ("paused 는 비었다는 뜻이 아니다").
#
# SSOT: docs/claude-harness/tasks/20260916/iss-claim-arbitration/

ISS_CLAIM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$ISS_CLAIM_LIB_DIR/working-scan.sh" 2>/dev/null || return 1

ISS_CLAIM_REGISTRY="${REGISTRY_PATH:-$HOME/.claude/docs/working/REGISTRY.md}"

# frontmatter `ISS:` 한 줄에서 번호만 뽑는다. `없음`·빈 값이면 아무것도 내지 않는다.
# 첫 `---` 블록만 본다 — 본문의 같은 글자는 claim 이 아니다.
iss_claim_declared() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk '
    NR==1 && $0!="---" { exit }
    NR>1 && /^---[[:space:]]*$/ { exit }
    /^ISS:/ { sub(/^ISS:[[:space:]]*/, ""); sub(/#.*/, ""); print; exit }
  ' "$file" | grep -oE 'ISS-[0-9]{3}' | sort -u
}

# REGISTRY 에서 working_file 의 basename 으로 sid·started·status·slug 를 찾는다.
# 경로 표기가 `/c/Users/...` 와 `C:/Users/...` 로 섞여 있어 절대경로 비교는 못 쓴다.
iss_claim_registry_row() {
  local base="$1"
  awk -F'|' -v b="$base" '
    NF>8 {
      n=split($9, p, "/"); if (p[n]=="") n--
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", p[n])
      if (p[n]==b) {
        for (i=2;i<=7;i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
        printf "%s\t%s\t%s\t%s\n", $4, $5, $7, $2   # sid started status slug
        exit
      }
    }
  ' "$ISS_CLAIM_REGISTRY" 2>/dev/null
}

# 전체 claim 인덱스. 출력: ISS \t sid \t started \t status \t slug \t path
# step 평면 파일은 제외한다 — 마스터의 부분집합이라 두 번 세면 자기 자신과 충돌한다.
iss_claim_index() {
  local product="${1:-all}"
  local path date prod task status is_step base row sid started st slug iss
  while IFS=$'\t' read -r path date prod task status is_step; do
    [ -n "$path" ] || continue
    [ "${is_step:-0}" = "1" ] && continue
    base="${path##*/}"
    row=$(iss_claim_registry_row "$base")
    IFS=$'\t' read -r sid started st slug <<< "$row"
    [ -n "$sid" ] || { sid="-"; started="-"; st="-"; slug="$task"; }
    while read -r iss; do
      [ -n "$iss" ] || continue
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$iss" "$sid" "$started" "$st" "$slug" "$path"
    done < <(iss_claim_declared "$path")
  done < <(working_scan "$product")
}

# 충돌 목록. 인자로 sid8 을 주면 **그 세션이 후착인 것만** 낸다 (패스 판정용).
# 출력: ISS \t 선착sid \t 선착started \t 선착slug \t 후착sid,후착sid...
iss_claim_conflicts() {
  local mine="${1:-}" product="${2:-all}"
  iss_claim_index "$product" | sort -t$'\t' -k1,1 -k3,3 -k2,2 | awk -F'\t' -v mine="$mine" '
    function flush(   i, others, first_sid) {
      if (n < 2) return
      first_sid = sid[1]
      others = ""
      for (i = 2; i <= n; i++) others = others (others == "" ? "" : ",") sid[i]
      if (mine != "") {
        # 내가 후착일 때만 낸다. 내가 선착이면 패스할 이유가 없다.
        found = 0
        for (i = 2; i <= n; i++) if (sid[i] == mine) found = 1
        if (!found) return
      }
      printf "%s\t%s\t%s\t%s\t%s\n", cur, first_sid, started[1], slug[1], others
    }
    { if ($1 != cur) { flush(); cur = $1; n = 0 }
      n++; sid[n] = $2; started[n] = $3; slug[n] = $5 }
    END { flush() }
  '
}

# 죽은 세션의 claim 을 걸러낸 충돌 목록. 선착이 죽었으면 그 줄을 내지 않는다
# — 종료된 세션이 번호를 영구 점유하면 후착이 영원히 패스한다.
iss_claim_conflicts_live() {
  local mine="${1:-}" product="${2:-all}"
  local iss first started slug others
  while IFS=$'\t' read -r iss first started slug others; do
    [ -n "$iss" ] || continue
    working_session_alive "$first" || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$iss" "$first" "$started" "$slug" "$others"
  done < <(iss_claim_conflicts "$mine" "$product")
}
