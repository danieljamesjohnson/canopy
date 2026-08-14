---
phase: 21-mood-scaled-breaks-honest-rationale
fixed_at: 2026-08-07T19:35:00Z
review_path: .planning/phases/21-mood-scaled-breaks-honest-rationale/21-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 21: Code Review Fix Report

**Fixed at:** 2026-08-07T19:35:00Z
**Source review:** .planning/phases/21-mood-scaled-breaks-honest-rationale/21-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope (fix_scope=critical_warning; critical: 0, warning: 2): 2
- Fixed: 2
- Skipped: 0

One additional finding outside the declared scope (IN-01, an Info-tier cosmetic
formatting issue) was also applied per explicit guidance provided alongside this
run's task — see "Additional fix outside declared scope" below. It is excluded
from the frontmatter counts above, which reflect `fix_scope: critical_warning` only.

## Fixed Issues

### WR-01: Two of six new cadence tests do not discriminate old vs. new behavior, contrary to the phase's own premise

**Files modified:** `test/services/schedule_generator_test.dart`
**Commit:** `b91a785`
**Applied fix:** Per the fix_guidance provided for this run, chose disclosure over
deletion — the mood=2 and mood=4 tests have genuine regression-lock value (they pin
the full five-point `_moodBreakCadence` table so a future edit can't silently change
those two tiers unnoticed), they just don't *prove* the phase's own claimed defect the
way the mood=1/mood=5 tests do. Renamed both test titles to explicitly say
"(regression lock — also true under the pre-BREAK-01 formula, does not by itself
prove the new table is wired up)", matching the honest self-labeling style the
existing mood=3 "(baseline unchanged)" test already used. No assertions, arithmetic,
or test bodies were changed — only the disclosure in the test names. Reformatted the
surrounding `test(...)` call structure (single-line → multi-line `test('title', () {
... })` wrapped form) to accommodate the longer title while staying within the file's
prevailing line-length convention; verified via `git diff` that no unrelated lines in
the file were touched. Full test file (62 tests) and full suite (348 tests) pass
after the change.

### WR-02: `_moodBreakCadence` has no explicit range validation on `moodIndex`, relying entirely on `Map.[]` returning null for a silent fallback

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** `de7e17d`
**Applied fix:** Per the fix_guidance provided for this run, took the minimal,
local fix rather than model-layer validation (would be scope creep into
persistence/migration, out of bounds for this phase). Added
`assert(moodIndex >= 1 && moodIndex <= 5)` at the top of `generate()`, matching the
existing `assert(freq >= 1 && freq <= 7)` pattern already used in
`computeDueWeekdays` — exactly the fix the reviewer suggested. This is a debug-only
guard (stripped in release builds); the pre-existing `?? 4` / `?? 8` fallbacks in
`_moodBreakCadence[moodIndex]` and `_moodCap[moodIndex]` remain the actual runtime
safety net for a corrupt/legacy Hive value, unchanged. No behavior change for any
in-range `moodIndex` (1-5) — verified via full test suite (348 tests) after the
change, plus `dart analyze` clean on the modified file.

## Additional fix outside declared scope

### IN-01: New single-line test definition exceeds the file's prevailing formatting style

**Files modified:** `test/services/schedule_generator_test.dart`
**Commit:** `a764b62`
**Note:** This finding is Info-tier and outside `fix_scope: critical_warning`, but
the task's fix_guidance explicitly called it out as "a one-command cosmetic fix" to
apply if it would not reformat unrelated code. Running `dart format` on the whole
file was tried first and rejected — the project's installed `dart format` reformats
~150 unrelated lines throughout the file (likely a formatter-version drift from
whatever produced the file's current state), which would violate "do not modify
files unrelated to the finding." Instead, manually wrapped only the single
over-length `test('TONE-01: under-pace time-target rationale reads as working
toward, not behind', () { ... });` call into the same multi-line
`test('title', () { ... }, )` form used elsewhere in the file (e.g. the adjacent
mood=3 BREAK-01 test), touching no other lines. Verified via `git diff` that the
change is scoped to that one test. Full test file (62 tests) and full suite
(348 tests) pass after the change.

## Skipped Issues

None — both in-scope findings (WR-01, WR-02) were fixed, and the out-of-scope
IN-01 finding was also applied per explicit guidance.

---

_Fixed: 2026-08-07T19:35:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
