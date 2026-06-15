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

## Milestone: v1.3 — An Honest Day

**Shipped:** 2026-06-14
**Phases:** 3 (15-17) | **Plans:** 4

### What Was Built
- Phase 15: Engine honesty — habit ceiling for fair capacity sharing (CAP-01), multi-chunk priority demand for habits & outcomes (PRIORITY-02), always-run round-robin fill of open days (FILL-01/02), and generation-time streak write-back so the displayed streak can't diverge from the computed walk (STREAK-01).
- Phase 16: Priority model reconciliation — drag and the Low/Normal/High selector write one coherent `priorityWeight`; widget tests lock chip-rebuild correctness (PRIORITY-03) and replace the deprecated `setSurfaceSize` tests with true-modal-height reachability tests for all three goal types (GOALFORM-02).
- Phase 17: Time-anchored Home — `resolveNowState` sealed hierarchy + 1-min timer select Now/Next by the chunk whose clock window contains the current time, with honest pre-start and day-complete states (NOW-01/02).

### What Worked
- The discuss→plan→check→execute→review→verify chain kept catching real defects pre-ship: a priority surplus-pass fix so higher-priority time-targets get strictly more chunks (CR-01), a low-mood exhausted-goal over-scheduling fix via `clamp(0,1)` (CR-02), a `now()` boundary race, and a `GapBeforeNext` state added so finishing early never falsely shows "day complete" — exactly the milestone's honesty point.
- Re-review after the `--auto` fix loop converged to clean on every phase.
- The full milestone (all 9 requirements) was UAT-confirmed in the browser on the hosted debug web build — timing-dependent Home tests driven by mocking the browser clock (Playwright `page.clock.setFixedTime`) rather than waiting on wall-clock. This cleared every prior `human_needed` item at milestone close.

### What Was Inefficient
- The `milestone.complete` CLI's auto-extracted accomplishments and task count (2) were too raw/wrong to ship — the MILESTONES.md entry needed a manual rewrite (real count ~9 tasks).
- UAT frontmatter `status:` lagged reality again (Phase 15/17 sat at `testing` after passing 3/3 and 4/4), tripping the pre-close artifact audit. Same bookkeeping gap as the Nyquist `nyquist_compliant` flag.
- STATE.md decision log accumulated several `[Phase ?]` placeholders instead of real phase tags.

### Patterns Established
- Mock-the-clock browser UAT (Playwright fixed time) as the way to verify time-anchored UI without wall-clock waits.
- A shared `priorityWeight` model with consistent band thresholds (`≥0.75` High / `≤0.25` Low) read identically by the engine and every priority chip — zero divergent magic numbers across drag, form, and display.

### Key Lessons
- Write the honest negative state explicitly (`GapBeforeNext`): a "day complete" that fires when you merely finished early is the exact dishonesty the milestone set out to remove.
- Flip status frontmatter (`UAT status`, `nyquist_compliant`) as part of phase close, not at milestone close — the audit keeps surfacing the lag.

### Cost Observations
- Model mix: planners on opus; researchers/checkers/executors/reviewers/fixers/auditors on sonnet (balanced profile).
- All visual UAT cleared in-milestone this time (vs v1.2 where 12 items were deferred) — the hosted debug build + clock-mocking made browser verification cheap enough to finish.

## Milestone: v1.4 — Energy-Aware

**Shipped:** 2026-06-15
**Phases:** 3 (18-20) | **Plans:** 12

### What Was Built
- Phase 18: Responsive modals + desktop polish — one shared `showAdaptiveFormModal` (dialog ≥720dp / bottom sheet below) for every form caller, 720dp content constraints on home/schedule/goals, and POLISH-02 copy fixes (RESP-01/02/03, POLISH-01/02).
- Phase 19: Energy valence — additive Hive migration (schema 7→8) adding `EnergyValence` (int-index, neutral=0, crash-safe) + emoji tag to Goal; valence picker + emoji picker in the goal form; `_ValenceBadge`/`_ValenceChip` + emoji on goal card and schedule chunks; onboarding "what gives you energy?" Screen 4 (ENERGY-01/02/03/04, ONBOARD-01).
- Phase 20: Valence-aware engine — bounded restorative floor on low-mood days + reserved energy/high-priority slot on high-mood days, deterministic-unit-tested, zero regressions (VSCHED-01/02/03).

### What Worked
- The discuss-skipped → research → pattern-map → plan → plan-check → execute → verify → code-review → fix chain caught real, shippable-blocking defects every phase: two critical onboarding bugs in Phase 19 (habit-on-Screen-1 silent data loss; "Energizing" chip stuck-selected), and a CRITICAL double-place bug in Phase 20 (restorative floor + PRIORITY-03 both placing a gives+high-priority goal, count map overwritten not incremented) plus a determinism tiebreaker gap — all found by adversarial review, fixed, and pinned with a new regression test.
- The additive-migration discipline held: the migration-safety RED test (old record → neutral, no crash) was written Wave 0 first and proved the highest-risk path before any model change.
- Agent-driven real-browser walkthroughs (go-look-at, ANGLE/SwiftShader) cleared the visual `human_needed` items in-milestone (desktop goal dialog, onboarding Screen 4, valence pickers) instead of deferring them.

### What Was Inefficient
- `nyquist_compliant: false` frontmatter lag struck a third time — all three v1.4 VALIDATION.md files needed flipping to `true` at milestone close despite green tests. Same bookkeeping gap flagged in v1.3; still not flipped at phase close.
- The planner twice mis-wrote ROADMAP.md with the Write tool and had to restore from git mid-run — a recurring hazard when agents edit shared planning files.
- Pre-existing seeds/todos (SEED-001/002/003/004, goal-form-desktop-layout) surfaced in the pre-close audit even though several were consumed by this milestone — they were acknowledged rather than marked resolved at source.

### Patterns Established
- Intentional file-private widget duplication (`_ValenceBadge`/`_ValenceChip` mirroring `_PriorityChip`) over premature shared-widget extraction.
- Non-destructive semantic color encoding for state that isn't an error (valence → tertiary/secondaryContainer; `colorScheme.error` stays reserved for archive/delete).
- Enum-as-int-index Hive storage with the zero value as the safe default, so additive migrations never need a data transform.

### Key Lessons
- Adversarial code review earns its keep on engine logic: the Phase 20 double-place bug passed all 7 VSCHED tests + 288 existing tests because no test exercised gives+high-priority on a low day — the review found it by reading the pass-ordering, not by running tests.
- When several passes share mutable accounting state (`placedCountPerGoal`), read-increment (`(x ?? 0) + 1`), never hard-assign — pass reordering silently corrupts hard-assigned counts.

### Cost Observations
- Model mix: planners on opus; researchers/pattern-mappers/checkers/executors/reviewers/fixers/auditors/UI agents on sonnet.
- Run end-to-end autonomously (`/gsd-autonomous`) across all 3 phases including lifecycle; sequential execution (worktrees auto-degraded — local master ahead of origin).

## Cross-Milestone Trends

| Milestone | Phases | Plans | Notable |
|-----------|--------|-------|---------|
| v1.2 Phases | 3 | 7 | UI foundations rework + priority-drives-scheduling; review/verify chain caught a WCAG regression and a false-passing engine test |
| v1.3 An Honest Day | 3 | 4 | Engine honesty (capacity/streaks/priority/fill) + time-anchored Home; all 9 requirements browser-verified via clock-mocking; review loop caught a boundary race and a false day-complete state |
| v1.4 Energy-Aware | 3 | 12 | Responsive modals + energy valence model + valence-aware engine; additive Hive migration crash-safe; adversarial review caught 2 critical onboarding bugs + 1 critical engine double-place bug; 289/289 tests green |
