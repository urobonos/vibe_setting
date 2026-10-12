# code-loop.sh 사용법 (운영 치트시트)

러너를 **고치기 전에 먼저 본다** — 대부분의 "이번만 다르게"는 환경변수로 끝난다.
설계·계약·결과문서 규약 SSOT = `../commands/code-loop.md`. 이 파일은 실행 레시피만 둔다.

## 기동·조회·재개

```bash
bash ~/.claude/custom-plugin/taskflow/bin/code-loop.sh "{구현 요청}"   # run_in_background 로 띄운다 (10분 넘음)
bash ~/.claude/custom-plugin/taskflow/bin/code-loop.sh status          # run 목록·상태
bash ~/.claude/custom-plugin/taskflow/bin/code-loop.sh --resume {run}  # 중단된 run 을 마지막 스텝 다음부터
tail -f ~/.claude/state/code-loop/{run}/run.log                        # 진행 로그
```

결과는 `~/.claude/state/code-loop/{run}/RESULT.md` 하나만 읽는다. 머지·push 는 하지 않는다.

## 환경변수 — 지정하면 그 run 에만 적용된다

| 변수 | 기본 | 비고 |
|---|---|---|
| `CODE_LOOP_MODEL_{DEV,REV}` · `CODE_LOOP_EFFORT_{DEV,REV}` | 자동 등급 | **지정한 역할은 자동 판단·승격을 모두 건너뛴다** |
| `CODE_LOOP_MODEL_ADV` · `CODE_LOOP_EFFORT_ADV` | opus · 자동 | red team |
| `CODE_LOOP_MODEL_SPEC` | `opus:medium` | spec 단계 (`모델:effort` 형식) |
| `CODE_LOOP_MODEL_SUM` | `sonnet` | merge·RESULT 요약 단계 |
| `CODE_LOOP_TIER` | `auto` | `off` = 자동 등급 끄고 에이전트 정의 frontmatter 모델 고정 |
| `CODE_LOOP_DEV_CAP` | `5` | 리뷰 라운드 캡, `0` = 무제한 |
| `CODE_LOOP_ADV_CAP` | `2` | red team 회차 캡, `0` = 무제한 |
| `CODE_LOOP_STEP_TIMEOUT_MIN` | 스텝별 | 전 스텝 시간 상한 일괄 재정의(분) |
| `CODE_LOOP_PERM` | `auto` | headless 권한 모드 |
| `CODE_LOOP_ISSUE_SYNC_CMD` | `wbs-sheet-sync.sh` | 이슈 전이 뒤 시트 동기화 명령 (테스트 stub 용) |

요청에 `ISS-N` 이 있으면 시작 때 이슈 문서를 pending → progress 로 옮기고, 끝날 때(어떤 종료든) 이력 1행을 남긴 뒤 시트에 동기화한다. resolved 전이는 하지 않는다 — `commands/code-loop.md` §이슈 문서 상태 전이.

자동 등급(`TIER=auto`, 지정 안 한 dev·rev): 시작 = max(위험영역 최소치, spec 의 `TIER:` 줄), effort 는 medium.
리뷰 3라운드째·red team 1회 깸 → opus:high, 2회 이상 → opus:xhigh 로 승격.

## 자주 쓰는 레시피

```bash
# 토큰 절약 — dev·rev 를 sonnet:medium 고정 (승격 없음). 해제 = 다음 run 에 안 붙이면 끝
CODE_LOOP_MODEL_DEV=sonnet CODE_LOOP_EFFORT_DEV=medium \
CODE_LOOP_MODEL_REV=sonnet CODE_LOOP_EFFORT_REV=medium \
  bash ~/.claude/custom-plugin/taskflow/bin/code-loop.sh "{요청}"

# haiku 5.5 지정 — 기본값은 아니다. 모델 값은 opus · sonnet · haiku 아무거나 역할별로 넣는다
# (haiku 4.5 는 결과문서 경로 ~/.claude 쓰기가 CLI 에서 거부된다. 별칭 `haiku` = 5.5 라 통과)
CODE_LOOP_MODEL_SUM=haiku bash ~/.claude/custom-plugin/taskflow/bin/code-loop.sh "{요청}"

# red team 회차를 이번만 늘리기/줄이기
CODE_LOOP_ADV_CAP=5 bash ~/.claude/custom-plugin/taskflow/bin/code-loop.sh "{요청}"

# 중단 run 재개 — 기동 때 붙인 환경변수는 재개 때 다시 붙여야 한다 (run 에 저장되지 않음)
CODE_LOOP_MODEL_DEV=sonnet ... bash ~/.claude/custom-plugin/taskflow/bin/code-loop.sh --resume {run}
```

기본값 자체를 바꿔야 할 때만 러너를 고친다 (반영 = worktree → dryrun → ff 머지, 가동 중 run 0 일 때).
테스트: `bash ~/.claude/custom-plugin/taskflow/bin/tests/code-loop-dryrun.sh` — 전체 1시간+, AF(시간상한)는 부하에 flaky.

## 종료 코드

`0` 완주(`[미수렴]` 여부는 RESULT 첫 줄) · `1` 실패·중단 · `2` 크기 게이트 · `3` 착수 불가 반환 · `4` adv 캡 도달 · `75` 사용량 한도(해제 뒤 `--resume`) · `143` TERM
