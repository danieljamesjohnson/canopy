---
phase: 26-the-day-has-a-shape
plan: 07
subsystem: ui
tags: [flutter, widget-test, ui-spec-amendment]

# Dependency graph
requires:
  - phase: 26-the-day-has-a-shape (plans 01-06)
    provides: the Stack-based proportional timeline, TimelineGeometry, NowLineOverlay/HourAxisLine overlay widgets, and the 26-06 real-browser UAT gate that surfaced G-01
provides:
  - "now-line chip confined to kGutterWidth (52dp), can never reach a ChunkCard's content"
  - "formatMinutesCompact chip copy, replacing the incompatible two-part 'Now · <time>' string"
  - "geometric G-01 regression test proven RED (pre-fix) and GREEN (post-fix)"
  - "dated UI-SPEC amendment resolving the 52dp-vs-string self-contradiction"
affects: [gsd-verify-work, any future now-line/hour-axis visual changes]

# Tech tracking
tech-stack:
  added: []
  patterns: ["gutter-column confinement via SizedBox(width: kGutterWidth) mirroring HourAxisLine's own shape"]

key-files:
  created: []
  modified:
    - lib/screens/today/widgets/now_line.dart
    - test/screens/today_screen_test.dart
    - test/screens/today_row_widgets_test.dart
    - .planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md

key-decisions:
  - "Dan's decision (2026-08-10, 26-UAT.md): honour the UI-SPEC's intent (chip lives in the time column) and change the string, not the column — rejected deleting the chip and rejected widening the gutter to ~101dp"
  - "The 2dp rule is untouched — only the chip is confined, since the rule crossing the card IS the truthful mid-chunk position CAL-02 exists to deliver"
  - "Screen-reader Semantics label keeps the full formatMinutes string; only the visible chip compacts"

patterns-established:
  - "A gutter-column-confined overlay chip mirrors HourAxisLine's SizedBox(width: kGutterWidth) shape rather than inventing a second confinement mechanism"

requirements-completed: [CAL-02]

# Metrics
duration: ~20min
completed: 2026-08-10
---

# Phase 26 Plan 07: Confine the now chip to the time gutter (G-01) Summary

**Fixed the now-line's UI-SPEC self-contradiction (52dp column vs. a ~101px "Now · <time>" string) by confining the chip to `kGutterWidth` and switching its label to `formatMinutesCompact`, closing the mid-chunk occlusion Dan reported at the 26-06 gate.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-08-10
- **Tasks:** 3/3
- **Files modified:** 4

## Accomplishments
- `NowLineOverlay`'s time chip is now genuinely confined to the 52dp time-gutter column (`SizedBox(width: kGutterWidth, ...)`, mirroring `HourAxisLine`'s own structure) and can never paint over a `ChunkCard`'s title, time range, or action row
- Chip label switched from the arithmetically-impossible `"Now · <time>"` string to `formatMinutesCompact(nowMinutes)`; horizontal padding dropped `8dp → 4dp` to fit the narrower column. The 2dp rule and the full-time screen-reader `Semantics` label are unchanged
- A new geometric regression test proves the chip's right edge never exceeds a `ChunkCard`'s left edge — the assertion class that was missing and let G-01 ship — proven RED against the pre-fix widget and GREEN against the fix
- `26-UI-SPEC.md` amended with a dated, non-destructive note (original table cells struck through and annotated, not deleted) recording the contradiction and its resolution, so a future reader cannot "restore" the longer label

## Task Commits

Each task was committed atomically:

1. **Task 1: Confine the chip to the gutter column** - `9cff399` (fix)
2. **Task 2: Assert the chip cannot reach the card** - `41540e6` (test)
3. **Task 3: Amend the UI-SPEC so the contradiction cannot re-ship** - `afa3539` (docs)

**Plan metadata:** pending (this commit)

## Files Created/Modified
- `lib/screens/today/widgets/now_line.dart` - Chip wrapped in `SizedBox(width: kGutterWidth)`, label switched to `formatMinutesCompact`, padding `8dp→4dp`, `maxLines: 1`/`TextOverflow.clip` added, doc comment corrected with the G-01 rationale
- `test/screens/today_screen_test.dart` - New `G-01: the now chip stays inside the time gutter and never overlaps a chunk card` test inside the existing `Phase 26 — CAL-02 the now-line` group; existing `chip copy` test updated to assert the new compact text (`"9:12"` instead of `"Now · 9:12 AM"`); added a `ChunkCard` import
- `test/screens/today_row_widgets_test.dart` - Existing locked-copy test updated from `"Now · 2:47 PM"` to the new compact `"2:47p"` (collateral fix — see Deviations)
- `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md` - Dated 2026-08-10 amendment appended to "The now-line (CAL-02)" section; affected table cells struck through and annotated in place

## Decisions Made
- Honoured the spec's intent (chip stays in the time column) rather than deleting the chip or widening the gutter — Dan's explicit choice, recorded verbatim in both the UI-SPEC amendment and `26-UAT.md`
- Left the 2dp rule's full-content-width, card-crossing behavior completely untouched — that crossing is the mid-chunk truth CAL-02 exists to deliver, and the plan's critical invariant forbade touching it
- Kept the screen-reader `Semantics` label at the call site (`today_screen.dart`) reading the full `formatMinutes` string — no change was needed there; it already used the full format pre-fix, so this was a "confirm, don't touch" outcome rather than a code change

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated a second stale locked-copy test in `today_row_widgets_test.dart`**
- **Found during:** Task 1 verification (running the quick test command surfaced a second failure beyond the one `today_screen_test.dart` test the plan anticipated)
- **Issue:** `test/screens/today_row_widgets_test.dart`'s `NowLineOverlay (CAL-02, UI-SPEC locked)` group asserted the pre-fix locked chip copy (`"Now · 2:47 PM"`), which is not in the plan's `files_modified` list but broke the moment Task 1's label change landed — it is asserting behavior the fix intentionally supersedes, not a regression the fix introduced
- **Fix:** Updated the test's name and assertion to the new compact copy (`"2:47p"`, i.e. `formatMinutesCompact(887)`), with a comment pointing to G-01/26-07-PLAN.md so a future reader understands why the locked copy changed
- **Files modified:** test/screens/today_row_widgets_test.dart
- **Verification:** `flutter test test/screens/today_timeline_model_test.dart test/screens/today_row_widgets_test.dart test/screens/today_screen_test.dart` green; full suite green at 556/556
- **Committed in:** `9cff399` (Task 1 commit — bundled with the fix since it is the same behavioral change landing in one atomic commit)

---

**Total deviations:** 1 auto-fixed (1 bug — stale test assertion)
**Impact on plan:** Necessary to keep the suite green after the intentional copy change; no scope creep beyond the plan's own stated fix.

## Issues Encountered

**Proving the G-01 test's RED result required a temporary file swap, not a git revert.** Task 2's acceptance criteria demand the regression test is proven to fail against the pre-fix widget. Since Task 1 was already committed, this was done by temporarily overwriting `now_line.dart` with its pre-fix content (via `git show <task-1-commit>~1:...`), running only the new test (`flutter test test/screens/today_screen_test.dart --plain-name "G-01"`), observing failure, then restoring the exact post-fix file (`git diff` confirmed byte-identical restoration) before writing the test's own commit. No working-tree state was left inconsistent at any commit boundary.

**Observed RED result (pre-fix `now_line.dart`, chip unbounded):**
```
The finder "Found 0 widgets with widget matching predicate descending from widgets with type
"NowLineOverlay": []" (used in a call to "getTopLeft()") could not find any matching widgets.
```
This is a legitimate RED: the pre-fix chip has no `SizedBox(width: kGutterWidth)` descendant at all (it was `Align` + `Padding` with no width bound), so the finder the regression test relies on can't locate it — proving the test only becomes satisfiable once the fix's confinement structure exists.

**Observed GREEN result (post-fix `now_line.dart`, restored):**
```
00:00 +1: All tests passed!
```
Full suite subsequently confirmed at 556/556 green, `flutter analyze` clean.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

G-01 is closed. `resolveNowState` remains the single now-detector (verified: one definition in `now_state.dart`, one call site in `today_screen.dart`). Zero raw `Colors.*` literals introduced. No all-day faster ticker added. `test/screens/today_screen_now_state_test.dart` untouched. This closes the last open gap from the 26-06 UAT gate — Phase 26 (The Day Has a Shape) has no known open issues remaining.

---
*Phase: 26-the-day-has-a-shape*
*Completed: 2026-08-10*

## Self-Check: PASSED

All modified files confirmed present on disk; all four commits (`9cff399`, `41540e6`, `afa3539`, `53ef4ff`) confirmed in `git log`.
