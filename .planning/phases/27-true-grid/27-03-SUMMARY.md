---
phase: 27-true-grid
plan: 03
subsystem: testing
tags: [flutter, layout, live-row, density-tiers, grid-02, regression-repair]

# Dependency graph
requires:
  - phase: 27-01
    provides: "TimelineGeometry.yFor() branch-free; kCompactLiveMinHeight placeholder"
  - phase: 27-02
    provides: "LiveRowCard's two density tiers, duration-exact Positioned slot, and the observed 8-test failing-list this plan works from"
provides:
  - "Full flutter test suite green again (567 tests) with no assertion weakened into vacuity to get there"
  - "LIVE-01 ('a running break reads as rest') covered on both live-row tiers — single-line via Semantics label, compact via the visible RESTING kicker"
  - "_chunkTitle's break-awareness repointed to its one surviving render site, the GapBeforeNext 'Up next' banner"
  - "The live row's rendered slot asserted duration-exact at the screen level, on both tiers (20dp/single-line, 100dp/compact), measured on the ClipRect — the positive replacement for the swell test deleted in 27-01"
  - "Complete/Skip reachable through the now-line by tooltip, not button label, matching the compact tier's icon-only chrome"
affects: ["27-04 (real-browser measurement of kCompactLiveMinHeight — this plan's green suite is necessary but explicitly NOT sufficient proof of that)"]

tech-stack:
  added: []
  patterns:
    - "find.byTooltip(...) scoped to find.byType(LiveRowCard) as the finder for icon-only Complete/Skip actions, replacing find.widgetWithText(FilledButton/OutlinedButton, ...) everywhere the live row is involved"
    - "tester.ensureSemantics() + find.bySemanticsLabel(RegExp(...)) to prove a visually-dropped kicker's meaning survives in the single-line tier's accessibility label"
    - "Measuring the live row's slot via find.ancestor(of: find.byType(LiveRowCard), matching: find.byType(ClipRect)) rather than getSize on LiveRowCard itself, which would report OverflowBox-permitted natural content height, not the duration-exact slot"

key-files:
  created: []
  modified:
    - test/screens/today_screen_now_state_test.dart
    - test/screens/today_screen_test.dart

key-decisions:
  - "Fixed an 8th failing test ('a running break gets the same countdown treatment') beyond the plan's forecast of 7 — 27-02-SUMMARY.md's own investigation already identified and cleared it as the same class of fallout (single-line tier's Row/Expanded split renders the countdown as its own Text with a leading ' · ' prefix, never the bare label), so it was repaired here rather than treated as a new regression requiring separate investigation"
  - "Repointed the between-chunks/overdue test's caveat comment into a positive assertion (LiveRowCard must not contain '10:30 AM' anywhere) now that the deleted 'Next ·' line no longer makes that assertion ambiguous — strictly stronger than the comment it replaces, not merely different"
  - "GapBeforeNext repointing test reused the exact same fixture shape (w1 completed, b1 unresolved short break, now=8:10) as today_screen_test.dart's pre-existing sibling test, rather than widening the gap via a later b1 start time — resolveNowState's GapBeforeNext branch only checks 'is the active window's chunk resolved AND has the next chunk's window not yet opened', so the existing fixture already produces a genuine ~15-minute gap without modification"
  - "Kept (did not delete) the now-vacuous FilledButton/OutlinedButton findsNothing assertions in the strengthened D-02 test, alongside the new tooltip/IconButton assertions — the old assertions do no harm and record what the shipped card used to render; the new assertions are what makes the test able to actually fail again"

requirements-completed: [GRID-02]

# Metrics
duration: ~35min
completed: 2026-08-18
---

# Phase 27 Plan 03: Repairing the screen-level test suite against the two-tier live row Summary

**Repointed all 8 observed-failing screen-level tests (7 forecast + 1 unforecast fallout, both `today_screen_now_state_test.dart` and `today_screen_test.dart`) against the shipped GRID-02 two-tier `LiveRowCard`, added the positive duration-exact-slot replacement for plan 27-01's deleted swell test, and strengthened one test that had gone vacuous — full `flutter test` (567 tests) and `flutter analyze` both green, with no assertion deleted without either a repointed successor or a stated reason its subject no longer exists.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-08-18
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Repaired all 7 forecast failures in `test/screens/today_screen_now_state_test.dart`, plus the 8th (unforecast, but pre-investigated by 27-02-SUMMARY.md) failure in the same file:
  - **LIVE-01 split per PD-27-09** into a single-line-tier test (asserts the `'Right now: Taking a break, …'` semantics label via `tester.ensureSemantics()`/`find.bySemanticsLabel`, since the visible `RIGHT NOW — RESTING` kicker is dropped below `kCompactLiveMinHeight` by design) and a new compact-tier sibling (copies the existing long-break fixture, asserts the visible kicker survives at 100dp).
  - **`_chunkTitle`'s break-awareness repointed per PD-27-10** from the deleted live-row "Next ·" line to the `GapBeforeNext` "Up next" banner — the guard `today_screen.dart`'s own ~494-498 comment calls load-bearing can now fail again.
  - **Two progress-bar tests deleted outright** (`'live break still shows a progress bar (D-04)'`, `'the progress bar tracks the same value as the label'`) — the bar is gone from both tiers by design (the now-line's position within a duration-exact card IS the fraction elapsed); each deletion left a dated comment naming the reason so a future reader doesn't restore it.
  - **`'live work chunk still shows Complete/Skip'`** repointed to `find.byTooltip`, scoped to `LiveRowCard`, gained the missing Skip assertion.
  - **`'live break shows no Complete/Skip (D-02)'` strengthened** (not just repointed) — its old `FilledButton`/`OutlinedButton` finders now match widget types the live row cannot produce in either tier and would pass trivially; added `byTooltip`/`IconButton`-absence assertions so the gate can actually fail.
  - **The overdue-identity test** dropped its now-deleted `'Next ·'` assertion and gained a *stronger* positive one: `LiveRowCard` must not contain `'10:30 AM'` anywhere — the exact check the old comment said it "could not make."
  - **The 8th, unforecast failure** (`'a running break gets the same countdown treatment'`) repaired: the single-line tier's locked `Row`/`Expanded` split renders the countdown as its own `Text` carrying a leading `' · '` prefix, never as the bare label in one `Text` — repointed to `textContaining`, scoped to `LiveRowCard`.
- Repaired the 1 forecast failure in `test/screens/today_screen_test.dart` (the hit-test `IgnorePointer` proof) by switching its Complete finder from `widgetWithText(FilledButton, ...)` to `find.byTooltip('Complete')`, keeping both pre-tap now-line/card overlap assertions intact.
- Added the GRID-02 duration-exact-slot positive replacement plan 27-01 deferred here: two new tests in the `'Phase 26 — CAL-01 the day has a shape'` group, asserting the live row's `ClipRect` slot equals `5 * kPixelsPerMinute` (single-line tier, no kicker) and `25 * kPixelsPerMinute` (compact tier, kicker present) — both measured on the `ClipRect`, never on `LiveRowCard` itself (which would report `OverflowBox`-permitted natural content height, not the slot).
- Fixed one stale comment (`~502`) that justified an exact-match finder by citing the live row's now-deleted "Next · Reading at 10:50 AM" line.
- Full `flutter test`: **567 tests, all passed.** `flutter analyze`: no issues. `git diff --exit-code pubspec.yaml pubspec.lock`: empty (no dependency change). `grep -rn "liveExtraPx\|kLiveRowReservedHeight\|nextLine" lib/ test/`: 0 hits.

## Task Commits

Each task was committed atomically:

1. **Task 1: Repair and re-aim the six now-state live-row tests** - `a6b45b3` (test)
2. **Task 2: Fix the hit-test finder and assert the duration-exact live slot** - `aea7bab` (fix)

## Files Created/Modified

- `test/screens/today_screen_now_state_test.dart` — 7 tests repaired/repointed, 1 unforecast test repaired, 2 tests deleted (with reason comments), 1 test split into 2 (LIVE-01 tier coverage). Before: 31 `testWidgets`. After: 30 (net -1: two deleted, one added).
- `test/screens/today_screen_test.dart` — hit-test finder repointed to `byTooltip`; 2 new `GRID-02` duration-exact-slot tests added; 1 stale comment fixed. Before: 60 `testWidgets`. After: 62 (two added, none deleted).

## Decisions Made

See `key-decisions` in frontmatter above — summarized:

- Fixed the 8th (unforecast) failing test rather than deferring it, since 27-02-SUMMARY.md had already investigated and cleared it as expected fallout of the same UI change, not a new regression requiring separate triage.
- The overdue-identity test's repointed assertion is strictly stronger than what it replaces (a specific, previously-impossible negative check), not merely a like-for-like swap.
- Reused the existing `today_screen_test.dart` GapBeforeNext fixture shape verbatim for the repointed `_chunkTitle` test, since `resolveNowState`'s gap logic doesn't require widening the gap beyond what that shape already produces.
- Left the now-vacuous `FilledButton`/`OutlinedButton` assertions in place in the strengthened D-02 test alongside the new ones, rather than deleting them — harmless, and the new assertions are what actually restores the test's ability to fail.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Repaired an 8th failing test beyond the plan's forecast of 7**
- **Found during:** Task 1, running `flutter test test/screens/today_screen_now_state_test.dart` per the plan's own instruction to work from 27-02-SUMMARY.md's observed list, not the forecast.
- **Issue:** `'a running break gets the same countdown treatment'` asserted `find.text('30s left · until 8:30 AM')` (the bare `remainingLabel`) as a single `Text` widget. It fails because the single-line tier's locked `Row`/`Expanded` split (`27-UI-SPEC.md` "Single-line tier", explicit departure from a single concatenated string) renders the countdown as its own `Text` carrying a leading `' · '` prefix (`' · $remainingLabel'`), in a separate widget from the title — never as the bare label alone.
- **Fix:** Repointed to `find.textContaining('30s left · until 8:30 AM')`, scoped to `find.byType(LiveRowCard)`, with a comment explaining the tier's rendering shape and citing 27-02-SUMMARY.md's own investigation that already confirmed this is expected fallout, not a defect.
- **Files modified:** `test/screens/today_screen_now_state_test.dart`
- **Verification:** Full file green (48/48); full suite green (567/567).
- **Committed in:** `a6b45b3` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, Rule 1)
**Impact on plan:** Confined to a single test assertion in the file Task 1 already owned. No scope creep — this is the exact "real regression vs. expected fallout" investigation the plan's own `<read_first>` instructed, and 27-02-SUMMARY.md had already done the triage; this plan only had to apply the fix.

## Issues Encountered

None beyond the one documented deviation above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Full `flutter test` (567 tests) and `flutter analyze` are both green — the wave gate `27-VALIDATION.md` requires before the real-browser measurement step.
- **A green suite is necessary but explicitly NOT sufficient proof this phase worked** (`27-VALIDATION.md`'s own load-bearing split): `flutter test`'s placeholder-font harness cannot see whether the compact tier actually fits its 100dp slot without clipping, whether the single-line tier stays under 20dp, or whether the painted hour spacing is uniform. Those are plan 27-04's job — a real-browser measurement of `kCompactLiveMinHeight` and the `measure_hours.py` `UNIFORM` check — not claimed here.
- No assertion in either edited file references a progress bar, a `'Next ·'` line, or a `FilledButton`/`OutlinedButton` inside `LiveRowCard` anymore (verified via grep, both files, both this plan's own acceptance criteria and the repo-wide `liveExtraPx|kLiveRowReservedHeight|nextLine` check).
- `kCompactLiveMinHeight` (`88.0`) remains an **UNMEASURED PLACEHOLDER** — nothing in this plan treats it as final; that measurement is explicitly plan 27-04's job.

## Known Stubs

None — this plan is test-only; no `lib/` file was created or modified.

## Threat Flags

None — test-only plan, no new network endpoints, auth paths, file access, or schema changes (matches the plan's own threat model: "none introduced").

---
*Phase: 27-true-grid*
*Completed: 2026-08-18*

## Self-Check: PASSED

All 3 referenced files (`test/screens/today_screen_now_state_test.dart`, `test/screens/today_screen_test.dart`, `.planning/phases/27-true-grid/27-03-SUMMARY.md`) confirmed present on disk. Both task commit hashes (`a6b45b3`, `aea7bab`) confirmed present in `git log`.
