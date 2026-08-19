---
description: prd/stg/dev EC2 직접 접속 → 서버 점검·수정 → 검증 → 로컬 반영 통합 진입점. prod-debug 스킬 thin wrapper.
argument-hint: "[connect|verify|sync] [env] [args]"
---

`/prod-debug` 슬래시 — 서버 우선 디버그 진입점. `prod-debug` 스킬 (3 모드 connect/verify/sync + 환경별 매트릭스) 의 thin wrapper.

## 인자

| 인자 | 동작 |
|------|------|
| (없음) | 모드 선택 안내 + 스킬 §1 호출 방식 출력 |
| `connect {env} {instance}` | SSM start-session / send-command 진입. env={prd\|stg\|dev}, instance=i-XXX |
| `verify {env} {url}` | e2e 5점 + 비즈니스 로직 검증. env / url 필수 |
| `sync {env} {paths}` | 서버 → 로컬 반영 (검증 통과 후 사용자 명시 승인) |

## 동작 3단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① 모드·환경 식별 | 인자 매칭 + 환경별 분기 매트릭스 (prd 최후 / stg 검증 우선 / dev 일상) | 모드 진입 |
| ② skill 호출 | `prod-debug` skill 본문 §2 (3 모드 상세) 따름 | 명령 실행 (조회계 즉시 / 변경계 사용자 명시) |
| ③ audit log 신설 | `~/.claude/docs/claude-harness/output/audit/prod-debug-log/{yyyy-mm-dd-HHMM}-{env}-{slug}/` | connect / verify / sync 별 3 파일 |

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

흐름 예시 (prd hotfix):

```
[사용자] /prod-debug connect prd i-0abc1234
   ↓
[Claude] 1) IAM/인스턴스 확인 (조회계 즉시)
        2) start-session 명령 안내 (대화형 = 사용자 직접):
           ! aws ssm start-session --target i-0abc1234
        3) 비대화형 명령 = 사용자 명시 승인 후 Claude 직접:
           aws ssm send-command --instance-ids i-0abc1234 --document-name AWS-RunShellScript ...
        4) audit log 신설 — output/audit/prod-debug-log/{...}/connect.md
   ↓
[사용자] /prod-debug verify prd https://api.prd.hongcafe.com/payment
   ↓
[Claude] e2e 5점 매핑 (env / 함수 / DB / curl / mock) + 회귀 매트릭스
        → 통과 시 sync 진입 안내, 실패 시 connect 재진입
   ↓
[사용자] /prod-debug sync prd {paths}
   ↓
[Claude] 1) 서버 변경 사항 추출 (git diff 또는 scp)
        2) 사용자 명시 승인 후 로컬 적용 (worktree 안 mutation)
        3) commit + 사용자 직접 push 안내 (`! git push ...`)
        4) audit log sync.md 신설
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.3 "서버 우선 디버그 → 로컬 반영 흐름" | 정책 SSOT (5 단계 + 환경별 매트릭스) |
| `hongcafe:prod-debug` 스킬 | 본 슬래시의 본체 스킬 (3 모드 상세) |
| `~/.claude/skills/aws/SKILL.md` §"실행 주체" | SSM 조회/변경 분리 패턴 |
| `backend:php8` 스킬 §"e2e 검증" | verify 모드 5점 매핑 |

## §3 Checkpoint 우선 적용

본 슬래시는 §3 5조건 (외부 시스템 / 비가역 / 광범위 영향) 매칭 다수 — **사용자 명시 승인 우선**.

| 모드 | 자동화 수준 |
|------|-----------|
| `connect` 조회계 (describe/get-command-invocation) | 자동 |
| `connect` 변경계 (send-command) | 사용자 명시 후 Claude 직접 |
| `verify` GET (curl 200) | 자동 |
| `verify` write (POST/PUT/DELETE) | 사용자 명시 |
| `sync` | 100% 사용자 명시 |

**worktree 적용 (CLAUDE.md §4.3 (a)):** `connect` / `verify` = read-only 또는 외부 시스템 (worktree 무관). `sync` = 로컬 mutation = **worktree 강제** (`worktree-enforce.sh` 차단 대상). 신규 작업 = `git worktree add ~/.claude/worktrees/{sid}-prod-debug-{env}-{slug} -b wip/{...}`.

## 환경별 분기 매트릭스 (skill SSOT cross-ref)

| 환경 | hotfix | 검증 강도 | 사용자 승인 |
|------|--------|---------|-----------|
| prd | 최후 수단 | e2e 5점 전체 + 회귀 매트릭스 | 매 단계 명시 |
| stg | 우선 검증 가능 | e2e 5점 + 회귀 매트릭스 | connect / verify 자동, sync 명시 |
| dev | 일상 작업 | 단위 테스트 + curl 200 | 자동 (사용자 명시 옵션) |

## 차별점 (다른 슬래시와)

| 슬래시 | 시점 | 범위 |
|--------|------|------|
| `/taskflow:verify` | 로컬 코드 e2e 5점 검증 | 로컬 환경 |
| **`/prod-debug verify`** | **서버 환경 e2e 5점 + 회귀 매트릭스** | **prd/stg/dev EC2** |
| `/taskflow:deploy` | git push / 머지 안내 (사용자 직접) | 로컬 → 원격 |
| **`/prod-debug sync`** | **서버 → 로컬 반영 (역방향)** | **EC2 → 로컬 commit** |

## 자동화 분류

`prod-debug` skill = **C (수동 진입점)** — 모드별 사용자 단계별 결정 필요 (`skill-inventory.md` §5.1 카운트 정합).
