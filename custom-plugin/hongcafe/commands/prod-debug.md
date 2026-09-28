---
description: prd/stg/dev EC2 직접 접속 → 서버 점검·수정 → 검증 → 로컬 반영 통합 진입점. prod-debug 스킬 thin wrapper.
argument-hint: "[connect|verify|sync] [env] [args]"
---

`/prod-debug` 슬래시 — 서버 우선 디버그 진입점. `prod-debug` 스킬(`skills/prod-debug/SKILL.md`)을 불러 그 절차를 그대로 따른다. 모드 상세·환경별 매트릭스·자동화 수준·§3 판정·audit log 경로는 전부 스킬이 SSOT 다 — 진입점에 다시 적으면 한쪽만 고쳐져 갈라진다 (실제로 이 파일의 자동화 표가 스킬의 조회계 send-command 자동 판정(2026-07-29)을 놓친 채 남아 있었다).

## 인자

| 인자 | 동작 |
|------|------|
| (없음) | 모드 선택 안내 + 스킬 §1 호출 방식 출력 |
| `connect {env} {instance}` | SSM start-session / send-command 진입. env={prd\|stg\|dev}, instance=i-XXX |
| `verify {env} {url}` | e2e 5점 + 비즈니스 로직 검증. env / url 필수 |
| `sync {env} {paths}` | 서버 → 로컬 반영 (검증 통과 후 사용자 명시 승인) |

## 자연어 trigger

- `서버 우선 디버그` / `ec2 직접 점검` / `prd 오류 점검` / `ssm session` / `서버에서 먼저 수정`

## 강제 hook

| Hook | 검증 | 차단 강도 |
|------|------|----------|
| `dangerous-ops-guard.sh` | `aws ssm send-command` 감지 시 stdout Checkpoint 경고 | exit 0 (실행 차단 X, 승인 후 직접 실행 신호) |
| `worktree-enforce.sh` | `sync` 모드 시 로컬 mutation = worktree 강제 | exit 2 (worktree 외 차단) |
| `branch-enforce.sh` | `sync` 후 `git push` = §3 절대 차단 영역, 사용자 직접만 | exit 2 (Claude 자동 push 차단) |

## 호출 예

```
/prod-debug                              ← 모드 선택 안내
/prod-debug connect prd i-0abc1234       ← prd 인스턴스 접속
/prod-debug verify stg https://api.stg.hongcafe.com/payment  ← stg 검증
/prod-debug sync stg app/Modules/Payment/Controllers/PaymentController.php  ← 로컬 반영
```

## §3 Checkpoint 우선 적용

외부 시스템·비가역 매칭이 많은 슬래시다 — 모드별 자동/승인 구분은 스킬 §5 를 따른다. `sync` 는 로컬 mutation 이라 worktree 안에서만 한다 (`worktree-enforce.sh`).
