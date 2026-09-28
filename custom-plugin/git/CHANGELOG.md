# git 플러그인 변경 이력

각 커맨드·에이전트 본문의 `## Changelog` 를 옮겨 모은 파일이다 (2026-09-28). 본문은 실행 때마다 로드되므로 이력은 여기에만 쓴다.

## commands/merge.md

- 2026-08-19: **`/taskflow:code` 산 worktree 전용 squash 정착 분기 추가** — 리뷰 루프가 라운드마다 쌓은 중간 커밋은 리뷰를 통과한 적이 없고, 린터 `--fix` 커밋이 `git blame` 을 오염시킨다. **기존 ff-only 경로(`/taskflow:tick`·`/taskflow:watch`·`/taskflow:save`)는 건드리지 않았다** — CLAUDE.md §4.3(f)·`watch.md` 머지 사다리 L1~L3 가 ff-only 를 전제한다. 커밋 포맷은 push 스킬 포인터(재정의 0), push 는 여전히 사용자 직접
