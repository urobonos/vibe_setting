---
name: skill-creator
description: >
  스킬 생성·개선·평가 메타-스킬. 새 스킬을 처음부터 만들거나, 기존 스킬을 수정·최적화하거나,
  eval 평가로 성능을 측정한다. description 트리거 정확도 최적화도 지원.

  Create new skills, modify and improve existing skills, and measure skill performance.
  Use when users want to create a skill from scratch, edit, or optimize an existing skill,
  run evals to test a skill, benchmark skill performance with variance analysis,
  or optimize a skill's description for better triggering accuracy.
triggers:
  - "스킬 만들기", "스킬 만들어줘", "스킬 생성"
  - "스킬 수정", "스킬 개선", "스킬 업데이트"
  - "스킬 평가", "skill eval", "스킬 테스트"
  - "트리거 최적화", "description 최적화", "skill description"
  - "스킬 패키징", "skill package", ".skill 파일"
  - "/skill-creator"
version: 1.0.1
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

---

## ⚠️ 진입 시 필수 — Skill Edit Lock (글로벌 강제 룰)

본 스킬은 글로벌 CLAUDE.md "스킬 생성·수정·최적화 강제" 룰의 단일 진입점입니다. `.claude/skills/` 하위 모든 파일 수정은 `skill-edit-guard.sh` PreToolUse hook 이 차단하며, 본 스킬을 **명시적으로 호출**한 경우에만 락 파일로 우회 통과시킵니다.

**진입 직후 (Edit/Write 호출 전) 반드시 실행:**

```bash
touch /tmp/claude_skill_creator_active.lock
```

**작업 완전히 끝낸 직후 (반드시) 실행:**

```bash
rm /tmp/claude_skill_creator_active.lock
```

**Why:** 락 없이는 SKILL.md 자체도 수정 불가 — 사용자가 의도하지 않은 즉흥 스킬 편집을 hook 레벨에서 원천 차단하는 게 본 룰의 목적입니다. 세션 종료 시 `gate-init.sh` (SessionStart) 가 잔여 락을 자동 정리하므로 다음 세션에 영향 없음.

---

At a high level, the process of creating a skill goes like this:

- Decide what you want the skill to do and roughly how it should do it
- Write a draft of the skill
- Create a few test prompts and run claude-with-access-to-the-skill on them
- Help the user evaluate the results both qualitatively and quantitatively
  - While the runs happen in the background, draft some quantitative evals if there aren't any (if there are some, you can either use as is or modify if you feel something needs to change about them). Then explain them to the user (or if they already existed, explain the ones that already exist)
  - Use the `eval-viewer/generate_review.py` script to show the user the results for them to look at, and also let them look at the quantitative metrics
- Rewrite the skill based on feedback from the user's evaluation of the results (and also if there are any glaring flaws that become apparent from the quantitative benchmarks)
- Repeat until you're satisfied
- Expand the test set and try again at larger scale

Your job when using this skill is to figure out where the user is in this process and then jump in and help them progress through these stages. So for instance, maybe they're like "I want to make a skill for X". You can help narrow down what they mean, write a draft, write the test cases, figure out how they want to evaluate, run all the prompts, and repeat.

On the other hand, maybe they already have a draft of the skill. In this case you can go straight to the eval/iterate part of the loop.

Of course, you should always be flexible and if the user is like "I don't need to run a bunch of evaluations, just vibe with me", you can do that instead.

Then after the skill is done (but again, the order is flexible), you can also run the skill description improver, which we have a whole separate script for, to optimize the triggering of the skill.

Cool? Cool.

---

## Workflow Map (index)

| Phase | What you do | Detailed reference |
|-------|-------------|--------------------|
| 1. Capture intent | Ask what the skill should do, when it should trigger, output format, whether to use test cases | `references/creating-skill.md` |
| 2. Interview & research | Edge cases, I/O formats, examples, success criteria, dependencies; research via MCPs/subagents | `references/creating-skill.md` |
| 3. Draft SKILL.md | Frontmatter (name, description, compatibility) + body; pushy description for triggering | `references/creating-skill.md` |
| 4. Anatomy & style | Folder layout, progressive disclosure, writing patterns, style guide | `references/skill-anatomy.md` |
| 5. Test cases | 2-3 realistic prompts → `evals/evals.json` (no assertions yet) | `references/test-cases-runs.md` |
| 6. Spawn runs | With-skill + baseline subagents in same turn; per-eval `eval_metadata.json` | `references/test-cases-runs.md` |
| 7. Draft assertions | While runs are in flight, write objective assertions and explain to user | `references/test-cases-runs.md` |
| 8. Capture timing | Save `total_tokens` / `duration_ms` to `timing.json` per run | `references/test-cases-runs.md` |
| 9. Grade & aggregate | `grading.json` (text/passed/evidence) → `python -m scripts.aggregate_benchmark` | `references/test-cases-runs.md` |
| 10. Launch viewer | `eval-viewer/generate_review.py` (use `--static` for headless) | `references/test-cases-runs.md` |
| 11. Read feedback | `feedback.json` → focus on non-empty entries | `references/test-cases-runs.md` |
| 12. Improve | Generalize, lean, explain why, bundle repeated work; apply and rerun | `references/feedback-iteration.md` |
| 13. Description optimization | 20 trigger-eval queries → `scripts.run_loop` → apply `best_description` | `references/description-optimization.md` |
| 14. Blind comparison (optional) | Independent agent judges A/B; analyze why winner won | `references/blind-comparison.md` |
| 15. Package | `python -m scripts.package_skill` (only if `present_files` available) | `references/packaging.md` |
| Environment | Claude.ai (no subagents) / Cowork (subagents, no display) adaptations | `references/claude-ai-cowork.md` |

`references/schemas.md` has the JSON schemas for `evals.json`, `eval_metadata.json`, `grading.json`, and `benchmark.json`.

---

## Communicating with the user

The skill creator is liable to be used by people across a wide range of familiarity with coding jargon. If you haven't heard (and how could you, it's only very recently that it started), there's a trend now where the power of Claude is inspiring plumbers to open up their terminals, parents and grandparents to google "how to install npm". On the other hand, the bulk of users are probably fairly computer-literate.

So please pay attention to context cues to understand how to phrase your communication! In the default case, just to give you some idea:

- "evaluation" and "benchmark" are borderline, but OK
- for "JSON" and "assertion" you want to see serious cues from the user that they know what those things are before using them without explaining them

It's OK to briefly explain terms if you're in doubt, and feel free to clarify terms with a short definition if you're unsure if the user will get it.

**한국어 사용자 응답 (필수):** 한국어로 발화한 사용자에게 응답할 때는 본 스킬 본문의 영어 표현을 의역하여 한국어 존댓말("~합니다", "~하겠습니다" 등) 로 전달합니다. 명사형/평서형 종결어미("~함", "~임") 는 반말로 인식되므로 금지합니다. 글로벌 CLAUDE.md "응답 톤 (필수 / 존댓말)" 룰을 적용합니다.

**Default Accept 룰 정합:** 본 스킬은 Anthropic 영어 템플릿 기반이라 "ALWAYS" / "NEVER" 같은 강제 어휘를 일부 사용하지만, 사용자 환경(글로벌 CLAUDE.md §4) 의 Default Accept 룰이 우선 적용됩니다. 즉 Claude 가 스킬 작업 중 제시하는 제안사항(리팩토링·명명·누락 처리 등) 은 사용자 별도 승인 대기 없이 반영하여 진행합니다. 단 §3 Checkpoint 5조건(비가역적 / 광범위 / 트레이드오프 / 외부 시스템 / 권한 외 접근) 은 Default Accept 에 우선 적용되어 사용자 승인 대기가 필요합니다.

---

## Creating a skill

Phases 1-3 (capture intent → interview → draft frontmatter) are described in detail in `references/creating-skill.md`. Read it when starting a new skill so you know what to ask, how to research, and how to populate the SKILL.md frontmatter (especially the `description` field, which is the primary triggering mechanism — keep it a little "pushy" to combat undertriggering).

### Skill Writing Guide

For the folder layout (`scripts/`, `references/`, `assets/`), the three-level progressive disclosure model, the Principle of Lack of Surprise, writing patterns (output formats, examples), and writing style, see `references/skill-anatomy.md`. Key reminders that stay in this body for visibility:

- Keep SKILL.md under 500 lines; if you're approaching this limit, add an additional layer of hierarchy with clear pointers to where the model should look next.
- Reference files clearly from SKILL.md with guidance on when to read them.
- When a skill supports multiple domains/frameworks, organize by variant (one file per cloud / framework / runtime under `references/`) so Claude reads only the relevant reference file. See `references/skill-anatomy.md` for the AWS/GCP/Azure-style example.
- Prefer the imperative form. Explain the *why* behind instructions instead of leaning on heavy-handed MUSTs.

### Test Cases

After writing the skill draft, come up with 2-3 realistic test prompts — the kind of thing a real user would actually say. Share them with the user, then save the prompts to `evals/evals.json` (assertions come later). The full schema and the run/grade/viewer flow are in `references/test-cases-runs.md`.

---

## Running and evaluating test cases

This section is one continuous sequence — don't stop partway through. Do NOT use `/skill-test` or any other testing skill.

Put results in `<skill-name>-workspace/` as a sibling to the skill directory, organized as `iteration-N/eval-<ID>/{with_skill,without_skill|old_skill}/`. Don't create directories upfront — make them as you go.

The full step-by-step flow lives in `references/test-cases-runs.md`. The phases are:

1. **Spawn all runs** (with-skill AND baseline) in the same turn, one subagent each. Baseline = no skill (creating new) or snapshot of old skill (improving existing). Write `eval_metadata.json` per eval with a descriptive `eval_name`.
2. **Draft assertions** while runs are in progress. Objective, descriptive names. Update `eval_metadata.json` and `evals/evals.json`. Explain to the user what they'll see in the viewer.
3. **Capture timing** from each task notification immediately to `timing.json` (`total_tokens`, `duration_ms`) — it's not persisted elsewhere.
4. **Grade, aggregate, launch viewer**:
   - Grade each run via `agents/grader.md` → `grading.json` with fields `text`/`passed`/`evidence` (the viewer depends on these exact field names). Use scripts for programmatic checks.
   - `python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>` → `benchmark.json` + `benchmark.md`.
   - Analyst pass per `agents/analyzer.md` (non-discriminating assertions, flaky evals, time/token tradeoffs).
   - Launch `eval-viewer/generate_review.py` (use `--static <output_path>` in Cowork/headless). For iteration 2+, pass `--previous-workspace`. Always use `generate_review.py` — don't write custom HTML.
5. **Read `feedback.json`** when the user signals done. Empty feedback = fine. Kill the viewer (`kill $VIEWER_PID 2>/dev/null`).

The viewer's "Outputs" tab shows prompt/output/previous-output/formal-grades/feedback per test case; the "Benchmark" tab shows pass rates, timing, tokens, per-eval breakdowns, analyst observations. See `references/test-cases-runs.md` for the full description and schemas.

---

## Improving the skill

This is the heart of the loop. You've run the test cases, the user has reviewed the results, and now you need to make the skill better based on their feedback.

Four guiding principles (full discussion in `references/feedback-iteration.md`):

1. **Generalize from the feedback.** The skill needs to work on millions of prompts, not just the few you're iterating on. Avoid overfitty fiddly changes; try different metaphors or patterns.
2. **Keep the prompt lean.** Remove things that aren't pulling their weight. Read transcripts, not just outputs.
3. **Explain the why.** ALL-CAPS MUSTs/NEVERs are a yellow flag — reframe and explain reasoning.
4. **Look for repeated work across test cases.** If subagents independently wrote the same helper script, bundle it in `scripts/`.

Take your time and really mull things over. Write a draft revision, then look at it anew and improve it.

### The iteration loop

After improving the skill: apply changes → rerun all test cases into `iteration-<N+1>/` (including baseline) → launch reviewer with `--previous-workspace` → wait for feedback → read and improve again.

Stop when: user is happy / all feedback is empty / you're not making meaningful progress.

---

## Advanced: Blind comparison

For situations where the user asks "is the new version actually better?", there's a blind comparison system using `agents/comparator.md` and `agents/analyzer.md`. Optional, requires subagents, most users won't need it. Details in `references/blind-comparison.md`.

---

## Description Optimization

The description field is the primary triggering mechanism. After creating or improving a skill, offer to optimize it for better triggering accuracy.

The full procedure (generating 20 trigger-eval queries with realistic detail, reviewing them with the user via `assets/eval_review.html`, running `python -m scripts.run_loop` with the session's model ID, applying `best_description`) lives in `references/description-optimization.md`. That file also explains how skill triggering actually works — Claude only consults skills for tasks it can't easily handle on its own, so eval queries should be substantive enough that Claude would actually benefit from the skill.

---

## Package and Present (only if `present_files` tool is available)

Check whether you have access to the `present_files` tool. If you do, run `python -m scripts.package_skill <path/to/skill-folder>` and direct the user to the resulting `.skill` file. Skip otherwise. See `references/packaging.md`.

---

## Environment-specific instructions

The core workflow (draft → test → review → improve → repeat) is the same everywhere, but mechanics differ by environment:

- **Claude.ai** (no subagents): run test cases serially yourself, skip baselines/benchmarking/blind-comparison/description-optimization, present results inline instead of via the browser viewer.
- **Cowork** (subagents but no display): full workflow works, but use `--static` for the viewer; remember to GENERATE THE EVAL VIEWER *BEFORE* evaluating inputs yourself so the human sees examples first.
- **Updating an existing skill** (any environment): preserve the original `name` and directory name; copy to a writeable location (e.g., `/tmp/skill-name/`) before editing if the install path is read-only; stage in `/tmp/` first when packaging manually.

Full guidance in `references/claude-ai-cowork.md`.

---

## 인벤토리 동기화 규칙 (CLAUDE.md §5.4 carrier)

> CLAUDE.md §5.4 가 본 절을 절차 SSOT 로 참조한다. 스킬 생성·수정·rename·삭제 시 아래를 함께 처리한다.

- **신규 추가:** CLAUDE.md §5.1 표에 1줄 추가 — 자동화 A/B/C 분류, 모드별 강도 상이 시 분리 표기 (`A (verify) / C (sync)` 형) + **카운트는 모드 단위** (행 단순 카운트 아님).
- **rename:** 폴더명 + frontmatter `name` + §5.1 표 동시 갱신.
- **삭제:** §5.1 표 제거 + `depends_on` grep 후 영향 스킬 갱신.
- **자동화 강도 변경:** 분석 산출물 + §5.1 자동화 컬럼 + 카운트 행 갱신.
- **depends_on 방향성:** A 가 B 의 출력/SSOT/산출물을 소비할 때만 `A.depends_on = [B]` **단방향** 명시. 양방향(A↔B)·순환(A→B→C→A) 금지. 의존 = 정적 참조 (동적 호출은 워크플로우).
- **version 컨벤션 (semver):** **Major** = 진입점·메인 모드·triggers 의미 변경 / **Minor** = 새 모드·trigger 추가 / **Patch** = 양식 보강·버그 픽스. 신규 스킬 = `1.0.0`. 역소급 면제 — 도입 이전 version 값 보존.
- **min_claude_md_version:** CLAUDE.md 메이저 업그레이드 시 일괄 갱신 금지 — 영향받는 스킬만 개별 갱신, 기본 = 기존 값 유지.
- **dual entry slash:** 동일 진입점 한·영 병행 신설 = SSOT 분기 위험으로 비추천 (외부 docs 참조·타 skill 호환 사유 있을 때만 허용). 기존 허용분 = `/토론` ↔ `/debate` — 양쪽 §5.1 표 + `commands/토론.md` 에 "동일 (영문 슬래시 호환)" 명문 동기화 필수.

## Reference files

The `agents/` directory contains instructions for specialized subagents. Read them when you need to spawn the relevant subagent.

- `agents/grader.md` — How to evaluate assertions against outputs
- `agents/comparator.md` — How to do blind A/B comparison between two outputs
- `agents/analyzer.md` — How to analyze why one version beat another

The `references/` directory has additional documentation:

- `references/schemas.md` — JSON structures for evals.json, grading.json, etc.
- `references/creating-skill.md` — Capture intent, interview, frontmatter
- `references/skill-anatomy.md` — Folder layout, progressive disclosure, patterns, style
- `references/test-cases-runs.md` — Test cases, runs, grading, aggregation, viewer, feedback
- `references/feedback-iteration.md` — Improvement principles and iteration loop
- `references/blind-comparison.md` — Optional A/B comparison flow
- `references/description-optimization.md` — Trigger eval queries and the optimization loop
- `references/packaging.md` — Package and present
- `references/claude-ai-cowork.md` — Claude.ai- and Cowork-specific adaptations

---

Repeating one more time the core loop here for emphasis:

- Figure out what the skill is about
- Draft or edit the skill
- Run claude-with-access-to-the-skill on test prompts
- With the user, evaluate the outputs:
  - Create benchmark.json and run `eval-viewer/generate_review.py` to help the user review them
  - Run quantitative evals
- Repeat until you and the user are satisfied
- Package the final skill and return it to the user.

Please add steps to your TodoList, if you have such a thing, to make sure you don't forget. If you're in Cowork, please specifically put "Create evals JSON and run `eval-viewer/generate_review.py` so human can review test cases" in your TodoList to make sure it happens.

Good luck!
