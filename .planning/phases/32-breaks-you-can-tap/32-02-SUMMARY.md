---
phase: 32-breaks-you-can-tap
plan: 02
subsystem: ui
tags: [flutter, material3, geometry, widget-tests, accessibility, gesture]

requires:
  - phase: 32-01
    provides: kPixelsPerMinute=6.0, kBreakSkipButtonWidth=64.0, BreakSkipButton/BreakSkippedIndicator (lib/widgets/break_skip_button.dart), the non-live break compact tier rebuilt as Card+rail, SwipeableChunkCard's restored early return
provides:
  - the full/detailed break tier rebuilt onto the same Card+rail shape as the compact tier (TAPBREAK-01/03)
  - ChunkCardDensity.subCompact, _SubCompactRow, kSubCompactGripSize, _DashedBorderPainter, kSubCompactBreakMinHeight deleted outright
  - LiveRowCard's single-line tier gains a BreakSkipButton rail, gated on showActions, with the excluding-Semantics wrapper narrowed to the title/countdown subtree only
  - the live break's row no longer wrapped in any swipe shell (today_screen.dart's isLive arm collapsed to the plain Positioned/ClipRect/OverflowBox shape)
  - the Layer 1b Stack pass, _needsSlop, the confinement parameter (visualHeight/_confineReveal/_confineContent), and kBreakHitSlop/kMinBreakDragTarget all deleted — verified via a combined comment-filtered grep returning zero
affects: [32-03-breaks-you-can-tap]

actuals:
  tokens: 28162
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "A live row's single-line tier now follows the same excluding-Semantics-narrowing pattern the non-live compact tier established in 32-01: wrap only the non-interactive title/countdown subtree in Semantics(excludeSemantics: true), never the whole row, once a real interactive child (BreakSkipButton) is added alongside it."
    - "SizedBox(height: slotHeight) as the explicit-height fix for a Row(crossAxisAlignment: stretch) laid out inside an ambient unbounded OverflowBox(maxHeight: infinity) — applied identically at three call sites now (chunk_card.dart's compact tier from 32-01, its full tier, and live_row_card.dart's single-line tier), all sharing the identical BoxConstraints-forces-infinite-height root cause."

key-files:
  created: []
  modified:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/today/timeline_geometry.dart
    - lib/screens/today/today_screen.dart
    - lib/screens/today/widgets/live_row_card.dart
    - test/screens/today_row_widgets_test.dart
    - test/screens/today_screen_now_state_test.dart

key-decisions:
  - "The full break tier keeps D-31-04's Opacity(0.5) whole-row mute on skip (unlike the compact tier's lineThrough-only signal) — the UI-SPEC's own words ('the internal Row/Padding/icon layout otherwise matches what already ships today, unchanged') scope the redesign to the container and the trailing content only, not the resolved-state mechanism. Confirmed by restoring an existing 32-01-authored today_screen_test.dart assertion that would otherwise have needed weakening."
  - "The full tier's `Opacity(0.5)` wraps the entire Row, including the rail slot — the same scope the old whole-row wrapper had, not a narrower one invented for this phase."
  - "A break's isCompleted-driven check-circle icon (dead code even before this phase — a break can never complete, D-31-01) is not carried into the redesigned full tier; its one covering test is deleted, not repointed."
  - "The 'no new interaction is added to the break row' test's premise for the button axis is explicitly superseded by D-32-02 (the Skip rail IS the new interaction); the narrower, still-true claim it was actually guarding (no collapse/accordion affordance, no whole-row tap) survives as a rewritten assertion."
  - "Case C in today_screen_now_state_test.dart no longer proves 'a drag on a resolved break resolves nothing' (no drag exists on any break any more) — it proves the equivalent claim in the new mechanism: an already-skipped break's rail shows BreakSkippedIndicator, never a re-tappable BreakSkipButton."
  - "The throwing-repository test for the live single-line tier's Skip rail uses runZonedGuarded to capture the genuinely-unhandled async Future rejection markSkipped's WR-05 gap produces, rather than letting flutter_test's own zone report it as an immediate hard failure — the same documented gap this project already accepted for the non-live break's Skip button."
  - "The realistic-row-width overflow test uses 430dp (this project's own established real-device viewport convention) and app-realistic string lengths, not a stress-test string — flutter test's placeholder font inflates glyph width well beyond real Roboto metrics, so an artificially long fixture overflows for a harness reason unrelated to the rail's own narrowing of the Expanded region."

patterns-established:
  - "A per-task commit boundary was reconstructed by checking out shared files to their prior-task state and re-applying only that task's own edits (verified against a saved final-state backup for byte-identical correctness) — necessary because Tasks 1-3 all touch overlapping files (today_screen.dart, timeline_geometry.dart, today_row_widgets_test.dart) and the plan's own 'commit per task' contract still had to hold."

requirements-completed: [TAPBREAK-01, TAPBREAK-03]

coverage:
  - id: D1
    description: "Both non-live break tiers (compact 30dp, full 180dp) render the identical bordered Card + 64dp Skip rail shape; the hairline sub-compact tier and its dashed painter are deleted from the tree, not merely unreferenced"
    requirement: "TAPBREAK-03"
    verification:
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#short break: \"Short break\" label, a bordered Card, no dashed painter"
        status: pass
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#long break: \"Long break\" label, the same bordered Card at greater weight (G-02)"
        status: pass
      - kind: integration
        ref: "test/screens/today_screen_test.dart#SEEBREAK-01 tier boundary (Phase 32, TAPBREAK-03 rewrite)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A live 5-minute break's single-line tier gains a tappable, screen-reader-reachable Skip rail — the regression this whole task exists to prevent (a running break with zero ways to skip it)"
    requirement: "TAPBREAK-01"
    verification:
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#a live 5-minute break renders a tappable, screen-reader-reachable Skip rail — this row is NOT skip-less"
        status: pass
      - kind: integration
        ref: "test/screens/today_screen_now_state_test.dart#Case A — a live short break can be skipped by its Skip rail"
        status: pass
    human_judgment: false
  - id: D3
    description: "The live break's row is no longer wrapped in any swipe mechanism — SwipeableRowShell's live-break call site is deleted, and the combined retirement grep over lib/ and test/ (kBreakHitSlop, kMinBreakDragTarget, kSubCompactBreakMinHeight, kSubCompactGripSize, _SubCompactRow, _DashedBorderPainter, _needsSlop, visualHeight) returns zero non-comment references"
    requirement: "TAPBREAK-01"
    verification:
      - kind: unit
        ref: "grep -rn --include='*.dart' -E 'kBreakHitSlop|kMinBreakDragTarget|kSubCompactBreakMinHeight|kSubCompactGripSize|_SubCompactRow|_DashedBorderPainter|_needsSlop|visualHeight' lib/ test/ | grep -vE ':[0-9]+: *//' | wc -l"
        status: pass
    human_judgment: false
  - id: D4
    description: "Work-chunk swipe (both directions, both reveals, confirmDismiss wiring) and goal reordering are byte-for-byte unaffected by the retirement sweep"
    verification:
      - kind: unit
        ref: "grep -c 'confirmDismiss' lib/screens/schedule/widgets/swipeable_chunk_card.dart (unchanged at 2)"
        status: pass
      - kind: unit
        ref: "test/screens/goal_card_drag_handle_test.dart (full file)"
        status: pass
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#an unresolved WORK chunk's Dismissible still offers the full horizontal direction"
        status: pass
    human_judgment: false
  - id: D5
    description: "Whether the compact/full tier's content visually 'reads as a section of the day' at true Roboto metrics, and whether the full-height rail reads sensibly on the 180dp long break, are real-device/human judgments outside flutter test's placeholder-font harness"
    human_judgment: true
    rationale: "This project's own carried-forward invariant (flutter test's placeholder font inflates glyph widths) means no widget test can settle a perceptual/legibility claim — explicitly deferred to 32-03's real-browser check and blocking human UAT, per 32-RESEARCH.md's own verification protocol."
    verification: []

duration: ~110min
completed: 2026-08-27
status: complete
---

# Phase 32 Plan 02: Both Break Tiers Share One Card, and Every Retired Mechanism Is Gone Summary

**The full (30-minute) break tier joins the compact tier's bordered-Card-plus-Skip-rail shape, a live 5-minute break gains the same tappable Skip rail (closing the regression that would have shipped it with zero skip mechanism), and eight retired symbols — three geometry constants, a grip constant, a density value, a hairline row class, a dashed painter, and a confinement parameter one indirection deeper than the UI-SPEC's own checklist audited — are proven gone from the tree by a single combined grep, not left present-but-uncalled.**

## Performance

- **Duration:** ~110 min
- **Started:** 2026-08-27 (session start)
- **Completed:** 2026-08-27
- **Tasks:** 3 completed
- **Files modified:** 7 (0 created, 7 modified)

## Accomplishments

- `chunk_card.dart`'s full/detailed break tier rebuilt onto the identical bordered `Card` + `BreakSkipButton` rail shape the compact tier (32-01) already uses — same `RoundedRectangleBorder(12)`/`surfaceContainer` container, same `Row(crossAxisAlignment: stretch)` + `Expanded` label + `SizedBox(width: kBreakSkipButtonWidth)` rail structure — while keeping the tier's own distinguishing treatment (heavier `titleMedium`/`w500` title, leading `self_improvement` icon, taller padding, restored `vertical: 4` margin, and D-31-04's existing `Opacity(0.5)` mute) unchanged.
- `ChunkCardDensity.subCompact`, `_SubCompactRow`, `kSubCompactGripSize`, `_DashedBorderPainter`, and `kSubCompactBreakMinHeight` deleted outright — the hairline tier the phase's own charter identifies as the exact regression waiting to reproduce at the new scale.
- `LiveRowCard._buildSingleLine` gains a trailing `BreakSkipButton` rail, gated on `showActions` exactly like the compact tier gates its own icons — the screen already asked for "at least one action, Skip only" for a live break; this tier had simply been ignoring it. The excluding `Semantics` wrapper is narrowed to the title/countdown subtree only, proven by a `find.bySemanticsLabel('Skip Short break')` assertion that the button's own semantics node is reachable.
- `today_screen.dart`'s live break arm collapses into the identical `Positioned`/`ClipRect`/`OverflowBox` shape the live work arm already uses — no grown envelope, no `SwipeableRowShell` wrap. The swipe removal and the rail addition landed in the same commit (Task 2), so no window ever existed in which a running break had zero ways to be skipped.
- Every symbol this phase retired is deleted, not left unreferenced: `_needsSlop`, the Layer 1b Stack pass, the confinement parameter chain (`SwipeableChunkCard`'s and `SwipeableRowShell`'s `visualHeight`/`_confineReveal`/`_confineContent` — one indirection deeper than the UI-SPEC's own retirement checklist audited, per `32-RESEARCH.md` Pitfall 2), and `kBreakHitSlop`/`kMinBreakDragTarget`. A combined comment-filtered grep for all eight retired symbols across `lib/` and `test/` returns zero matches.
- Goal reordering (`goals_screen.dart`'s unrelated `Icons.drag_indicator` usage) and every work-chunk swipe behaviour are untouched — `chunk_card.dart` now has zero `drag_indicator` references, `swipeable_chunk_card.dart`'s `confirmDismiss` count is unchanged at 2, and `test/screens/goal_card_drag_handle_test.dart` passes unmodified.
- Suite reconciled by explicit classification: 11 tests deleted (retired sub-compact-tier mechanism), 4 rewritten (break-vocabulary tests now assert the Card the tier gained instead of the dashed painter it lost), 1 helper deleted, 3 new tests added (the live single-line tier's not-skip-less regression, a throwing-repository test, and a realistic-width overflow test) — `flutter test` 629 → 621 (net −8), fully green, zero skipped.

## Task Commits

1. **Task 1: The long break joins the same shape, and the hairline tier is retired** — `bf5605e` (feat)
2. **Task 2: The running break gets its button in the same commit that takes its swipe away** — `9eddbe2` (feat)
3. **Task 3: The dead-mechanism sweep — delete it, do not merely stop calling it** — `75f85a9` (feat)

## Files Created/Modified

- `lib/screens/schedule/widgets/chunk_card.dart` — full break tier rebuilt as Card+rail (Opacity(0.5) mute retained); `ChunkCardDensity.subCompact`, `_SubCompactRow`, `kSubCompactGripSize`, `_DashedBorderPainter` deleted; both `_WorkChunkContent` switch expressions lose their now-impossible `subCompact` arms.
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — `SwipeableRowShell`'s `visualHeight`/`_confineReveal`/`_confineContent` deleted; `SwipeableChunkCard`'s own `visualHeight` pass-through parameter deleted; the reveal-icon size expression collapses to the unconfined `28.0` branch; unused `dart:math` import removed.
- `lib/screens/today/timeline_geometry.dart` — `kSubCompactBreakMinHeight` deleted (Task 1); `kBreakHitSlop`/`kMinBreakDragTarget` deleted (Task 3).
- `lib/screens/today/today_screen.dart` — the live break arm of `_buildPositionedRow` collapses to the live work arm's own shape (Task 2); `_needsSlop`, the Layer 1b Stack pass, and Layer 1a's third exclusion clause deleted, and `_buildChunkCard`'s `visualHeight` parameter/call site removed (Task 3).
- `lib/screens/today/widgets/live_row_card.dart` — `_buildSingleLine` gains the `BreakSkipButton`/`BreakSkippedIndicator` rail (gated on `showActions`), the excluding `Semantics` wrapper narrowed to the title/countdown subtree, and an explicit `SizedBox(height: slotHeight)` wrapper (same infinite-height fix `chunk_card.dart`'s tiers already needed).
- `test/screens/today_row_widgets_test.dart` — see per-file counts below.
- `test/screens/today_screen_now_state_test.dart` — Case A and Case C rewritten in place (`tester.tap()` on `BreakSkipButton` replacing `dragFrom`); Case B and Case D untouched.

## Test Reconciliation — Per-File Counts

### `test/screens/today_row_widgets_test.dart`
- **Deleted (11):** 3 `SEEBREAK-01: sub-compact...` tests, 2 `D-31-04: ...sub-compact break...` tests, the 3-case `D-31-06 — the sub-compact grip glyph` group, `SEEBREAK-01: SwipeableChunkCard forwards subCompact for a break`, `completed break also renders the check icon`, and one iteration lost from the `for (final density in [full, compact, subCompact])` loop (now `[full, compact]` — 3 generated tests become 2).
- **Rewritten in place (4):** `short break: ...no Card, dashed outline` → `...a bordered Card, no dashed painter`; `long break: ...` (same rewrite); `full short break renders both the label and its duration text` → `...renders the label and a Skip rail, not duration text`; `D-31-04: an unresolved full-tier break is unchanged...` → adds the Skip-rail assertion, drops the now-false "still reads its duration" claim; `no new interaction is added to the break row` → `no collapse/accordion affordance is added...` (narrowed, not deleted); `single-line tier has no InkWell when onTap is null` → scoped with `showActions: false`.
- **Helper deleted (1):** `_pumpBreakCardUnbounded` (Phase 29) — its only callers were the deleted sub-compact tests.
- **Added (3):** the live single-line tier's not-skip-less regression test (with `find.bySemanticsLabel` proof), the throwing-repository test (`_ThrowingScheduleNotifier`, `runZonedGuarded`), and the realistic-430dp-width overflow test.

### `test/screens/today_screen_now_state_test.dart`
- **Rewritten in place (2):** Case A (`tester.tap()` on `BreakSkipButton` replacing `dragFrom`, same skip/complete/chunk-id assertions) and Case C (its subject shifts from "a drag on a resolved break resolves nothing" to "a resolved break's rail shows the resolved indicator, never a re-tappable button" — the mechanism it originally tested no longer exists for ANY break, resolved or not).
- **Unchanged:** Case B (no drag, kept per the plan's own instruction) and Case D (no drag, kept).

### Before/after suite totals
- **Before (32-01 baseline, confirmed):** 629/629 green.
- **After:** 621/621 green (11 deleted, 3 added: 629 − 11 + 3 = 621).

## Combined Retirement Grep — Verbatim Output

```
$ grep -rn --include='*.dart' -E 'kBreakHitSlop|kMinBreakDragTarget|kSubCompactBreakMinHeight|kSubCompactGripSize|_SubCompactRow|_DashedBorderPainter|_needsSlop|visualHeight' lib/ test/ | grep -vE ':[0-9]+: *//' | wc -l
0
```

No output — zero non-comment references across `lib/` and `test/` for all eight retired symbols. No retired symbol turned out to still have a live caller.

## How the Excluding-Semantics Wrapper Was Narrowed (Live Single-Line Tier)

Before this task, `LiveRowCard._buildSingleLine` wrapped its entire content (title + countdown) in `Semantics(excludeSemantics: true, ...)`, which was correct while the row had no focusable child. Adding the `BreakSkipButton` rail as a sibling inside that same wrapper would have swallowed the button's own `Semantics(button: true, ...)` node entirely — visibly rendered, tappable, and invisible to a screen reader (the exact trap `32-UI-SPEC.md` names for the non-live card, restated because its own proposed snippet for this tier didn't address it).

The fix: the excluding wrapper now covers only the title/countdown `Expanded` subtree; the `BreakSkipButton` sits as a separate sibling in the outer `Row`, outside that wrapper, so its own semantics node is never merged or excluded. This is proven — not asserted by inspection — by a widget test that pumps a live 5-minute break and asserts `find.bySemanticsLabel('Skip Short break')` resolves to exactly one widget from inside the live row (`test/screens/today_row_widgets_test.dart`, the `Phase 32 (TAPBREAK-01)` group's first test).

## Decisions Made

- Kept D-31-04's `Opacity(0.5)` whole-row mute for the full break tier (compact tier stays `lineThrough`-only, from 32-01) — see key-decisions in frontmatter for the full rationale and the pre-existing test that confirmed it.
- Case C in `today_screen_now_state_test.dart` was adapted rather than deleted: its literal drag-based mechanism is gone for every break, but its underlying claim ("a resolved chunk must not advertise a gesture it no longer accepts") survives as "a resolved break's rail shows the indicator, never a re-tappable button."
- The "no new interaction is added to the break row" test's original premise is explicitly superseded by D-32-02 (the Skip rail is the new interaction, by owner ruling); its narrower true subject (no collapse/accordion, no whole-row tap) survives as a rewritten assertion rather than a deleted one.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Full break tier's redesign initially dropped D-31-04's `Opacity(0.5)` resolved-state mute, breaking a pre-existing 32-01 test**
- **Found during:** Task 1, running the full suite after the first pass of the full-tier redesign
- **Issue:** My first implementation of the full tier followed the compact tier's pattern exactly (lineThrough only, no whole-row Opacity), which is a reasonable-looking generalization but is wrong for this tier: `today_screen_test.dart`'s pre-existing "a mixed day renders every row independently" test explicitly asserts an `Opacity` ancestor of the unresolved long break's title exists with `opacity: 1.0` — a claim that fails with "Bad state: No element" once the wrapper is removed entirely, not merely retyped.
- **Fix:** Re-read `32-UI-SPEC.md`'s own words for the full tier ("the internal Row/Padding/icon layout otherwise matches what already ships today, unchanged") and restored the `Opacity(0.5)` wrapper around the tier's entire Row (label side + rail), matching its pre-existing scope exactly. The compact tier's own drop of this wrapper (32-01) stands as a deliberate, different design choice for that tier only.
- **Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`
- **Verification:** `flutter test test/screens/today_screen_test.dart --plain-name "a mixed day renders every row independently"` passes; both new D-31-04 full-tier tests (skipped and unresolved) pass without modification.
- **Committed in:** `bf5605e` (Task 1)

**2. [Rule 1 - Bug] Full tier needed the same explicit-height `SizedBox` fix 32-01 established for the compact tier**
- **Found during:** Task 1, before the Opacity fix above — the redesigned full tier's `Row(crossAxisAlignment: stretch)` also throws `BoxConstraints forces an infinite height` under the same ambient unbounded `OverflowBox` every non-live chunk card is laid out inside.
- **Fix:** Applied the identical `SizedBox(height: chunk.durationMinutes * kPixelsPerMinute)` wrapper 32-01 already used for the compact tier — a continuation of an established fix, not a new root cause.
- **Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`
- **Verification:** No `RenderFlex`/`BoxConstraints` exceptions in the full suite.
- **Committed in:** `bf5605e` (Task 1)

**3. [Rule 1 - Bug] The live single-line tier needed the same `SizedBox(height: slotHeight)` fix, for the same reason**
- **Found during:** Task 2, first pass of `LiveRowCard._buildSingleLine`'s rail addition — the same `CrossAxisAlignment.stretch`-against-unbounded-height issue, this time inside `today_screen.dart`'s `OverflowBox(maxHeight: double.infinity)` wrapping the live row.
- **Fix:** Wrapped the tier's returned `Card` in `SizedBox(height: slotHeight)` — the widget already carries `slotHeight` as a constructor parameter, so no new plumbing was needed.
- **Files modified:** `lib/screens/today/widgets/live_row_card.dart`
- **Verification:** No layout exceptions across the LiveRowCard test group at any `slotHeight`.
- **Committed in:** `9eddbe2` (Task 2)

**4. [Rule 1 - Bug] "no new interaction is added to the break row" test broke on the redesigned long-break tier and needed scoping, not deletion**
- **Found during:** Task 1, running the full suite
- **Issue:** This 22-02-era test asserted `find.byType(GestureDetector), findsNothing` and `CustomPaint` `isNotEmpty` against the OLD dashed-painter tier. The redesigned tier's `BreakSkipButton` uses `InkWell`, which itself is built on an internal `GestureDetector` — a real interactive child the old assertion never anticipated — and the dashed painter it also checked for is gone.
- **Fix:** Reclassified as Kind C: the test's real, still-true subject (no collapse/accordion affordance was added) survives; the parts of its premise D-32-02 explicitly reverses (no interaction at all, a dashed painter) do not. Rewrote to assert `ExpansionTile` absence and exactly one `InkWell` (the rail, and nothing else).
- **Files modified:** `test/screens/today_row_widgets_test.dart`
- **Verification:** Test passes; the rewrite is documented inline with its own comment explaining the supersession.
- **Committed in:** `bf5605e` (Task 1)

**5. [Rule 1 - Bug] "completed break also renders the check icon" test asserted an unreachable production state**
- **Found during:** Task 1, running the full suite
- **Issue:** This test pumped an artificial `_breakChunk(completed: true)` fixture that can never occur in production (`isCompleted` is permanently false for any break, D-31-01) and asserted the old full tier's dead `Icons.check_circle` completed-branch, which this task's rebuild does not carry forward.
- **Fix:** Deleted with a comment explaining why — not repointed at a state the app can never produce.
- **Files modified:** `test/screens/today_row_widgets_test.dart`
- **Verification:** Suite green without it; no other test covers this dead branch because nothing needs to.
- **Committed in:** `bf5605e` (Task 1)

**6. [Rule 1 - Bug] The throwing-repository test's first draft let `flutter_test` report the expected async exception as a hard test failure instead of an acknowledged one**
- **Found during:** Task 2, first run of the new "with a throwing repository..." test
- **Issue:** `tester.takeException()` does not retroactively capture an unhandled async `Future` rejection that `flutter_test`'s own zone already reported as an immediate `EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK` hard failure — the exact, expected behaviour of `BreakSkipButton`'s fire-and-forget `onTap` hitting `_ThrowingScheduleNotifier.markSkipped`'s rejection.
- **Fix:** Wrapped the `tester.tap()`/`tester.pump()` pair in `runZonedGuarded`, capturing the error at the zone boundary instead of letting it propagate as a bare test failure — the same documented, accepted gap (`32-RESEARCH.md`: `markSkipped`'s WR-05 revert-and-rethrow has no `catchError` at any button call site) made observable rather than swallowed.
- **Files modified:** `test/screens/today_row_widgets_test.dart`
- **Verification:** Test passes, acknowledging the caught error and asserting the rail stays tappable afterward.
- **Committed in:** `9eddbe2` (Task 2)

**7. [Rule 1 - Bug] The realistic-row-width overflow test's first draft overflowed for a harness-font reason unrelated to the rail**
- **Found during:** Task 2, first run of the new "at a realistic row width..." test
- **Issue:** An initial 390dp-wide test using a stress-length title and countdown string overflowed by 108–145px — not because of a real defect, but because `flutter test`'s placeholder font inflates glyph width well beyond real Roboto metrics (this project's own carried-forward invariant), and the chosen strings were unrealistically long for the width being tested.
- **Fix:** Switched to 430dp (this project's own established real-device viewport convention, already used in `timeline_geometry.dart`'s measurement recipes) and app-realistic string lengths matching the real `_buildLiveRow` format.
- **Files modified:** `test/screens/today_row_widgets_test.dart`
- **Verification:** `flutter test --plain-name "realistic"` passes with `tester.takeException()` asserted null.
- **Committed in:** `9eddbe2` (Task 2)

---

**Total deviations:** 7 auto-fixed (Rule 1 — all bugs surfaced by running the actual suite against the redesigned production code, none discretionary scope changes).
**Impact on plan:** All seven were necessary corrections to make the plan's own design run correctly (three production layout fixes, four test-authoring fixes). No scope creep beyond what Tasks 1–2's own design changes unavoidably required.

## Observations (not deviations — recorded for the record)

- `grep -c 'drag_indicator' lib/screens/goals/goals_screen.dart` returns **3**, not the plan's stated "2" — one is a doc comment (`// mobile using Icons.drag_indicator...`), two are code. This file was never touched by this plan; the discrepancy is in the plan's own literal grep count (which apparently expected code-only occurrences), not a regression. The intended guard — goal reordering unaffected — holds: `chunk_card.dart` now has zero `drag_indicator` references, and `test/screens/goal_card_drag_handle_test.dart` passes unmodified.
- Per-task commits were reconstructed by checking out shared files (`today_screen.dart`, `timeline_geometry.dart`, `test/screens/today_row_widgets_test.dart`) to their prior-task-committed state and re-applying only the next task's own edits, verified against a saved final-state backup for byte-identical correctness at each step, and confirmed green (`flutter analyze` + `flutter test`) at every intermediate checkpoint (618/618 after Task 1, 621/621 after Task 2, 621/621 after Task 3) before committing — necessary because all three tasks touch overlapping files.

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Every artifact this plan produces is committed and test-proven: both non-live break tiers on one shape, the live single-line tier's Skip rail, and a fully-verified retirement of eight symbols across three files.
- **32-03's real-browser fit check and the phase's blocking human UAT are unaffected and still pending** — this plan's own testable claims (D1–D4 in the coverage block) are all proven; the perceptual questions (does the compact tier's content read as a section of the day at true Roboto metrics, does the full-height rail read sensibly on the 180dp long break) were never this plan's job to answer, and are explicitly deferred (D5).
- The free/gap-row visual divergence from the new break-card language (a break is now a filled Card, a free-time gap is still dashed) remains out of scope for this plan, as `32-01-PLAN.md`/`32-RESEARCH.md` already flagged — carried forward to 32-03's UAT, not silently resolved here.

## Self-Check: PASSED

- `lib/screens/schedule/widgets/chunk_card.dart` — FOUND, full tier rebuilt confirmed by Read
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — FOUND, `visualHeight`/`_confineReveal`/`_confineContent` absence confirmed
- `lib/screens/today/timeline_geometry.dart` — FOUND, `kSubCompactBreakMinHeight`/`kBreakHitSlop`/`kMinBreakDragTarget` absence confirmed via grep
- `lib/screens/today/today_screen.dart` — FOUND, single Layer-1a pass with two exclusion clauses confirmed
- `lib/screens/today/widgets/live_row_card.dart` — FOUND, `BreakSkipButton` rail + narrowed Semantics confirmed
- Commit `bf5605e` — FOUND in `git log`
- Commit `9eddbe2` — FOUND in `git log`
- Commit `75f85a9` — FOUND in `git log`
- `flutter test` — 621/621 passing (verified this session)
- `flutter analyze` — clean (verified this session)
- Combined retirement grep — 0 matches (verified this session)

---
*Phase: 32-breaks-you-can-tap*
*Completed: 2026-08-27*
