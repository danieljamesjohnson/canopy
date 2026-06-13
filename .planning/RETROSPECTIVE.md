# Canopy — Living Retrospective

## Milestone: v1.2 — Phases ("Make It Usable")

**Shipped:** 2026-06-13
**Phases:** 3 (12-14) | **Plans:** 7

### What Was Built
- Phase 12: Home as landing; schedule reads as a real timed plan (clock times, now/next, labeled complete/skip).
- Phase 13: Check-in legibility (luminance-adaptive contrast + hover/pressed) and a post-commit lighter-day decision screen replacing the inline toggle; compact goal form that fits the viewport.
- Phase 14: Goals screen as a prioritization view (heading, drag_indicator, reorder-writes-priority) with a consistent priority visual language across goal cards and schedule cards; priority now measurably drives scheduling (habit sort + time-target composite score), proven by deterministic engine tests.

### What Worked
- The discuss→ui-spec→research→pattern-map→plan→check→execute→review→verify chain caught real defects before they shipped: a code review found a `Colors.white` regression that silently undid the CHECKIN-01 WCAG fix, and a false-passing Step 4 priority test (moodIndex=1 where the engine gates Step 4 off) that would have given false confidence in PRIORITY-01.
- File-disjoint wave planning let both plans per phase run cleanly even under sequential (worktree-degraded) execution.
- UI-SPEC as an authoritative contract resolved the labelSmall-vs-labelMedium ambiguity consistently across three duplicated `_PriorityChip` copies.

### What Was Inefficient
- Worktree isolation auto-degraded to sequential (HEAD diverged from fork base on the `plan/phase-12` branch), so the two file-disjoint plans per phase ran serially instead of in parallel.
- A code-review subagent wrote a stray `planning/` (dot-less) duplicate directory that needed manual cleanup.
- VALIDATION.md `nyquist_compliant` frontmatter was never flipped to `true` post-execution (tests pass; bookkeeping gap).

### Patterns Established
- Auto-approving in-plan `checkpoint:human-verify` tasks during autonomous runs and re-surfacing them as a single consolidated phase-level human-validation gate (then deferring to `*-UAT.md`).
- Standardize duplicated display widgets on the UI-SPEC typography table as the single source of truth.

### Key Lessons
- A passing test isn't a meaningful test: gate the assertions on a condition the implementation actually exercises (the Step 4 moodIndex bug).
- Re-review after auto-fix earns its cost — it caught the same error-handling gap in a sibling method (`_save`/`_archive`) the first pass missed.

### Cost Observations
- Model mix: planners on opus; researchers/checkers/executors/reviewers/fixers/auditors on sonnet.
- Visual UAT (12 items across phases 12-14) deferred by user choice — code-validated, human sign-off pending.

## Cross-Milestone Trends

| Milestone | Phases | Plans | Notable |
|-----------|--------|-------|---------|
| v1.2 Phases | 3 | 7 | UI foundations rework + priority-drives-scheduling; review/verify chain caught a WCAG regression and a false-passing engine test |
