# Work History

## 2026.04.09

### 주제별 커밋 정리 및 .gitignore 정비

- `.gitignore` 업데이트 — `docs/references/`(4.85GB docset), `*.token`, `skills.zip`, 캐시 파일 제외
- 10개 주제별 커밋 생성: CLAUDE.md 지침, hooks 12개, 스킬 6개 업데이트+4개 신규, docs/commands, monitoring, tasks/teams, settings
- API 토큰(`.token`) 커밋 방지 — gitignore 추가 후 재커밋

## 2026.04.08

### Claude Max 구독 업그레이드 타당성 보고서 작성

- `docs/claude-max-upgrade-justification.md` 생성 — Max 5 → Max 20 전환 근거 보고서
- `stats-cache.json` + `monitoring/reports/` 실측 데이터 기반 사용량 분석
- 30일간 203세션, 35,303메시지, Opus 88.9% 비중 정량 산출
- ROI 분석: 월 $100 추가 대비 10~16시간/월 생산시간 회수 논증

## 2026.04.07

### Hook 하니스 보완 — Analyze→Plan→Execute 순차 강제 완성

- `gate-enforce.sh` — Edit/Write 기준 gate>=1 → gate>=2로 변경 (Plan 승인까지 필수)
- `session-completeness-check.sh` — 경량 세션(gate=0) 예외 처리 추가
- `no-test-no-merge.sh` — 신규 hook, 커밋 시 테스트 실행 이력 검증
- `gate-enforce.sh` — Team 3 Agent spawn 시 worktree 격리 강제
- `gate-approve.sh` — 50자 초과 승인 메시지 리셋 버그 수정
- `notion-sync-check.sh` — Stop hook 차단 로직 보완

## 2026.04.06

### Claude Code 하니스 v3.2 → v4.0 대규모 업그레이드

- CLAUDE.md v4.0 전면 개편 (Session Init, Hierarchy, Checkpoint, Guardrails)
- 스킬 재구성: 3개 삭제, 5개 신규, 6개 업데이트
- Security Audit 체크리스트 7종 추가
- Hooks 12개 신규 + Conventional Commits v1.0.0 전환

### <PROJECT_BE> — Repository 패턴 전면 이관

- 전 모듈 Model→Repository 전환, getModel()/new Model() 29건 DI 전환
- 테스트 390건+ 추가·수정, 실패 테스트 67건 수정
- declare(strict_types=1) 471파일 일괄 적용
- Bitbucket Pipelines + RDS Proxy IAM 인증 hermes_db 확장
