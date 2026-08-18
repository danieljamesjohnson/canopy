---
phase: 27-true-grid
plan: 02
subsystem: ui
tags: [flutter, layout, live-row, density-tiers, grid-02]

# Dependency graph
requires: ["27-01 (branch-free TimelineGeometry.yFor, kCompactLiveMinHeight placeholder)"]
provides:
  - "LiveRowCard with a required, non-nullable slotHeight and exactly two density tiers (compact >= kCompactLiveMinHeight, single-line below it)"
  - "The live row positioned through the same Positioned/ClipRect/OverflowBox path every other timeline row uses, with a duration-exact height: — the overlap plan 27-01 documented as a known intermediate-state defect is closed"
  - "The observed, verbatim full-suite failing-test list (8 tests, not the plan's forecast of 7) for plan 27-03 to work from"
affects: ["27-03 (repairs the 8 screen-level tests this plan's own <intermediate_state_notice> and this summary enumerate)", "27-04 (real-browser measurement of kCompactLiveMinHeight against the compact tier this plan actually builds)"]

tech-stack:
  added: []
  patterns:
    - "slotHeight-picks-the-tier, mirroring ChunkCardDensity's existing slot->density rule (26-UI-SPEC.md) rather than inventing a second mechanism"
    - "IconButton constraints + style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap) — the actual combination that measures an exact declared touch-target size in Material 3, since constraints alone only bounds the visible Material, not the invisible _InputPadding tap-target wrapper every ButtonStyleButton adds"
    - "Semantics(excludeSemantics: true, button:, onTap:) to keep a tap affordance announced to a screen reader when the visible subtree's semantics are otherwise stripped (same pattern as Phase 26's PD-13 IgnorePointer fix)"

key-files:
  created: []
  modified:
    - lib/screens/today/widgets/live_row_card.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_row_widgets_test.dart

key-decisions:
  - "Dropped IconButton's visualDensity: VisualDensity.compact (present in an earlier draft, matching the plan's literal text) in favor of style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap) alone — verified empirically that constraints + visualDensity.compact measures 40x40 (not 36x36) because Material 3's IconButton always wraps the visible Material in a separate _InputPadding that pads the tap target toward kMinInteractiveDimension independent of the explicit constraints, and that stacking both shrinkWrap AND visualDensity.compact undersizes the button to 28x28 because visualDensity also shrinks the tight constraints' own minimum. shrinkWrap alone against the unmodified 36x36 tight constraints is the only combination that measures exactly 36x36 (Task 3's acceptance criterion)."
  - "PD-27-06's tap gate is computed inline in _buildLiveRow (work chunk, not completed, not skipped) rather than reusing _buildChunkCard's onTap ternary verbatim — the goal lookups (_lookupGoalColor/_lookupGoalName/_toDisplayRationale) are duplicated at this call site per the plan's explicit instruction, since _buildChunkCard's onTap closure is not extractable without changing that function's signature."
  - "The full-suite failure count is 8, not the plan's forecast of 7 — investigated per the plan's own instruction ('stop and investigate... a real regression, not expected fallout') and found NOT to be a regression: it is the same class of fallout as the other 7, just missed by the forecast (see 'Full-Suite Failure List' below)."

requirements-completed: [GRID-02]

# Metrics
duration: ~45min
completed: 2026-08-18
---

# Phase 27 Plan 02: The live row's two density tiers Summary

**`LiveRowCard` now takes a required `slotHeight` and renders exactly two density tiers (compact with icon-only Complete/Skip, single-line with a tappable title+countdown row) instead of swelling past its clock-implied slot; the live row's `Positioned` in `today_screen.dart` now carries a duration-exact `height:` through the same `ClipRect`/`OverflowBox` path every other row uses.**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-08-18
- **Tasks:** 3/3
- **Files modified:** 3

## Accomplishments

- Rewrote `LiveRowCard` (`lib/screens/today/widgets/live_row_card.dart`) against `27-UI-SPEC.md`: `slotHeight` is now required and non-nullable, `build()` is exactly `slotHeight >= kCompactLiveMinHeight ? _buildCompact(...) : _buildSingleLine(...)`, and the old unconstrained `build()` body, `progress`, and `nextLine` are deleted outright (PD-27-02, PD-27-03).
- `_buildCompact`: kicker+title (0dp gap, `w600` throughout, no `w700`), two 36×36 `IconButton`s (Complete/Skip, tooltip-accessible), a `SizedBox(height: 4)`, then the remaining-time line — no progress bar, no next line, no fourth item.
- `_buildSingleLine`: an `Expanded` title + a never-truncated `' · $remainingLabel'` suffix, full-opacity text, margin zero **vertically only** (PD-27-01) restating `kCardLeftInset`/`kTimelineRowInset` horizontally, wrapped in `Semantics(label: 'Right now: ...', excludeSemantics: true, button: onTap != null, onTap: onTap)` per PD-27-04 so the tap affordance survives semantics stripping.
- Routed the live row in `today_screen.dart`'s `_buildPositionedRow` through the same `Positioned(height: slot)` + `ClipRect`/`OverflowBox` path the non-live arm already uses — deleted the old no-`height:` branch and its stale `liveExtraPx` comment. Left it deliberately un-wrapped by `TimelineRowTile` (with a comment explaining why, since the two arms now look almost identical).
- Reworked `_buildLiveRow`: added a `slotHeight` parameter threaded straight to `LiveRowCard.slotHeight`; deleted the `nextChunk` lookup, the `nextLine` string, and the `progress` variable/its three assignments (kept every `remainingLabel` assignment byte-for-byte, including the Overdue branch's plain time-range copy); added the PD-27-06 tap handler (non-null only for an unresolved live work chunk, opening `ChunkDetailSheet` via the same `_lookupGoalColor`/`_lookupGoalName`/`_toDisplayRationale` triple `_buildChunkCard` already uses).
- Fixed the stale `liveExtraPx` comment at the `TimelineGeometry.forDay` call site to state what's actually true now (bounds retained as a future now-line-chip source, not a swell exception).
- Rewrote the `'LiveRowCard (D-01, Phase 23 seam)'` test group in `test/screens/today_row_widgets_test.dart` as `'LiveRowCard — two density tiers (GRID-02)'`: tier selection at the boundary (`kCompactLiveMinHeight` compact, `-1` single-line), tooltip-based Complete/Skip presence/tap, the 36×36 icon-button size assertion, the single-line title/remaining split, the `'Right now: ...'` semantics label, the tap affordance (present/absent by `onTap`), and both tiers' `Card` margin/shape/elevation.
- `flutter analyze` is clean across the whole project. `git diff --exit-code pubspec.yaml pubspec.lock` is empty (no dependency change) — verified after every task.

## Task Commits

Each task was committed atomically:

1. **Task 1: Give LiveRowCard two slot-height-selected tiers** - `7da0880` (feat)
2. **Task 2: Put the live row on the same positioning path as every other row** - `be64721` (fix)
3. **Task 3: Rewrite the LiveRowCard unit-test group against the two tiers** - `30e99b8` (test) — also carries the icon-button touch-target fix (Deviations below)

## Files Created/Modified

- `lib/screens/today/widgets/live_row_card.dart` — Rewritten: `slotHeight` required/non-nullable, `_buildCompact`/`_buildSingleLine`, `progress`/`nextLine` deleted, both tiers restate `kCardLeftInset`/`kTimelineRowInset`, Complete/Skip icon buttons use `IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)` to actually hit 36×36
- `lib/screens/today/today_screen.dart` — Live arm of `_buildPositionedRow` now returns a duration-exact `Positioned(height: slot)` through `ClipRect`/`OverflowBox`, un-wrapped by `TimelineRowTile`; `_buildLiveRow` gains `slotHeight`, drops `nextChunk`/`nextLine`/`progress`, adds the PD-27-06 `onTap` gate; stale `liveExtraPx` comment corrected
- `test/screens/today_row_widgets_test.dart` — `'LiveRowCard (D-01, Phase 23 seam)'` group replaced by `'LiveRowCard — two density tiers (GRID-02)'`, rebuilt against the new constructor and both tiers' behavior

## Decisions Made

- **`visualDensity: VisualDensity.compact` dropped from both `IconButton`s, in favor of `style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)` alone.** See Deviations below — this was discovered empirically while proving Task 3's 36×36 acceptance criterion, not assumed.
- **PD-27-06's tap gate duplicates `_buildChunkCard`'s goal lookups at the `_buildLiveRow` call site** rather than trying to share a closure, exactly as the plan instructed ("add them, matching `_buildChunkCard`'s usage exactly rather than inventing a variant").
- **`_liveSecondsRemaining` left byte-for-byte unmodified**, confirmed via `git diff` showing no line inside that method changed — it remains the single source of the countdown (P-5), unaffected by everything else this plan changed around it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Compact tier's Complete/Skip `IconButton`s measured 40×40 (then 28×28), not the declared 36×36, until `tapTargetSize: shrinkWrap` was added**
- **Found during:** Task 3, proving the acceptance criterion "each `tester.getSize` measures `Size(36, 36)`"
- **Issue:** The plan's own action text specifies `constraints: BoxConstraints.tightFor(width: 36, height: 36)` + `padding: EdgeInsets.zero` + `visualDensity: VisualDensity.compact` as sufficient to produce a 36×36 button, reasoning "the explicit `constraints` is what overrides Material's default 48dp `kMinInteractiveDimension`." Measured behavior contradicts this: Material 3's `IconButton` always wraps its visible `Material` in a separate, invisible `_InputPadding` render object that independently pads the *tap-test* area out toward `kMinInteractiveDimension` (48dp) minus a density adjustment — this happens regardless of the explicit `constraints:`, because `constraints:` only bounds the inner `ConstrainedBox`, not the outer `_InputPadding`. With `constraints: tightFor(36,36)` + `visualDensity: VisualDensity.compact`, the measured widget size was 40×40 (48 − 8 density adjustment on the outer wrapper). Adding `style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)` on top of the *original* `visualDensity: VisualDensity.compact` produced 28×28 instead — because `visualDensity` is applied a second time, to the *inner* tight constraints' own minimum, shrinking it below the intended 36.
- **Fix:** Removed `visualDensity: VisualDensity.compact` from both `IconButton`s; kept `constraints: BoxConstraints.tightFor(width: 36, height: 36)` and `padding: EdgeInsets.zero`; added `style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)`. This combination — tight constraints with no density adjustment on either the inner or outer layer — is what widget-test-measures exactly 36×36. Documented inline with the measured numbers (40×40, 28×28) so a future reader doesn't reintroduce `visualDensity` here on the strength of the plan's original (incorrect) reasoning.
- **Files modified:** `lib/screens/today/widgets/live_row_card.dart`
- **Verification:** `tester.getSize(...)` on both icon buttons' `IconButton` ancestor now returns exactly `Size(36, 36)`; full test group green.
- **Committed in:** `30e99b8` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, Rule 1)
**Impact on plan:** Confined to `live_row_card.dart`'s two `IconButton` widgets — a chrome-level correction to hit a plan-mandated, testable acceptance criterion. Does not change the declared 36×36 exception's rationale (still below the 44dp WCAG recommendation, still flagged for UAT confirmation) — it changes only how that 36×36 is actually achieved in Material 3.

## Full-Suite Failure List (observed, for plan 27-03)

`flutter test` (full suite): **566 tests, 558 passed, 8 failed.** The plan's `<intermediate_state_notice>` forecast exactly 7. All 7 forecasted failures occurred, under their real test names (one — "live break announces itself as rest" — is this plan's paraphrase of the actual test title `'live short break: kicker and title name the rest'`; same test, same assertion). One **additional, unforecast** failure occurred. Per the plan's own instruction ("If your run produces a failure NOT on this list, stop and investigate — it is a real regression, not expected fallout"), it was investigated (see below) and determined to be legitimate expected fallout, not a regression — just one the plan's forecast missed.

Verbatim list of the 8 failing tests, exactly as `flutter test` reports them:

`test/screens/today_screen_now_state_test.dart`
1. `'a running break gets the same countdown treatment'` — **NOT on the plan's forecast list.** Asserts `find.text('30s left · until 8:30 AM')` (the bare `remainingLabel`, unprefixed) finds one widget. Fails with `Found 0 widgets` because the single-line tier's `Row`/`Expanded` split (locked, `27-UI-SPEC.md`'s explicit departure from the spike's single concatenated string, "Do not collapse them back into one string") renders the remaining-time text as `' · 30s left · until 8:30 AM'` (with its `' · '` prefix) in a *separate* `Text` widget from the title, never as the bare label alone. This is the same class of fallout as the forecasted failures below — a pre-existing assertion against the tier's old single-concatenated-string layout — not a defect in this plan's implementation, which matches `27-UI-SPEC.md`'s locked contract exactly (verified independently by Task 3's own unit test asserting `find.text(' · <remainingLabel>')`).
2. `'between-chunks (overdue): 10am, c1 8:30–9:30, c2 10:30–11:30 → LiveRowCard (c1) + Next (c2)'` — its `Next ·` descendant expectation (forecast #1)
3. `'live break still shows a progress bar (D-04)'` (forecast #3)
4. `'live short break: kicker and title name the rest'` — the `RIGHT NOW — RESTING` assertion (forecast #2, "live break announces itself as rest")
5. `'next-is-a-break renders the reference name, not "Work block"'` (forecast #4)
6. `'live work chunk still shows Complete/Skip'` — `FilledButton` finder (forecast #5)
7. `'the progress bar tracks the same value as the label'` (forecast #6)

`test/screens/today_screen_test.dart`
8. `'hit-testing — a Complete tap still lands through the now-line (IgnorePointer proof)'` — `FilledButton` finder (forecast #7)

No other test files are affected. `test/screens/today_row_widgets_test.dart` (this plan's own test file) is fully green (52/52). `flutter analyze` reports no issues. `grep -rn "liveExtraPx\|kLiveRowReservedHeight" lib/ test/ | wc -l` prints `0`. `git diff --exit-code pubspec.yaml pubspec.lock` is empty.

## Known Stubs

None — no data source is stubbed; both tiers render real screen-injected data (`kicker`, `title`, `remainingLabel`) exactly as the shipped card did.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema changes. `onTap` opens the pre-existing `ChunkDetailSheet` over an already-loaded chunk (T-27-03's existing `chunkId` invariant, unchanged).

## Issues Encountered

- The 36×36 `IconButton` touch-target discrepancy (see Deviations above) — resolved within this plan, no open issue.
- The full-suite failure count exceeding the plan's forecast by one (see Full-Suite Failure List above) — investigated and resolved as "not a regression," no open issue, but flagged explicitly here so plan 27-03 has the complete, accurate work queue.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `LiveRowCard` has exactly two tiers, no progress bar, no next line, no nullable-slot fallback, and both tiers restate their horizontal insets — ready for plan 27-04's real-browser measurement of `kCompactLiveMinHeight` against this exact compact-tier layout.
- The live row's `Positioned` carries a duration-exact `height:` and is routed through `ClipRect`/`OverflowBox` like every other row — the overlap defect plan 27-01 documented as a known, deliberate intermediate-state visual regression is closed.
- **Plan 27-03's work queue is the 8 tests enumerated above** (not 7) — 7 in `test/screens/today_screen_now_state_test.dart`, 1 in `test/screens/today_screen_test.dart`. None require touching `test/screens/today_row_widgets_test.dart` (already green) or `lib/screens/today/widgets/live_row_card.dart` / `lib/screens/today/today_screen.dart` beyond what 27-03's own plan scopes.
- `kCompactLiveMinHeight` (`88.0`) remains an **UNMEASURED PLACEHOLDER** — no claim in this summary treats it as final or claims the compact tier fits its 100dp slot in a real browser; that measurement is explicitly plan 27-04's job, per `27-UI-SPEC.md`'s 9-step recipe.

---
*Phase: 27-true-grid*
*Completed: 2026-08-18*

## Self-Check: PASSED

All 4 referenced files (`lib/screens/today/widgets/live_row_card.dart`, `lib/screens/today/today_screen.dart`, `test/screens/today_row_widgets_test.dart`, `.planning/phases/27-true-grid/27-02-SUMMARY.md`) confirmed present on disk. All 3 task commit hashes (`7da0880`, `be64721`, `30e99b8`) confirmed present in `git log`.
