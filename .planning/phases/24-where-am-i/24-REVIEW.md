---
phase: 24-where-am-i
reviewed: 2026-08-08T23:17:26Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/screens/today/now_state.dart
  - lib/screens/today/timeline.dart
  - lib/screens/today/today_screen.dart
  - lib/screens/today/widgets/now_marker.dart
  - lib/utils/time_format.dart
  - test/screens/today_row_widgets_test.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_timeline_model_test.dart
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 24: Code Review Report

**Reviewed:** 2026-08-08T23:17:26Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the full diff range (`10c9067^..HEAD`, 4 plans across 24-01..24-04) against the two locked
invariants (`timeline.dart` never reads the clock; `buildTimeline` never re-sorts `chunks`), the D-01
single-clock-sample discipline, the D-02 one-shot centre-on-open contract, and the 24-UI-SPEC.md
design contract.

`buildTimeline`'s marker-insertion logic (`timeline.dart:84-131`) and the NOW-02 leading-row
suppression guard are both correct and match 24-UI-SPEC.md's ordering/suppression rules exactly —
traced through PreStart/Active/Overdue/GapBeforeNext/DayComplete, duplicate-start, sub-threshold-gap,
and degenerate (all-`start == null`) cases; the `markerInserted` latch prevents double emission in
every case checked, and `showMarker`'s null/Active guard correctly matches every state's own
"nowMinutes < next boundary" invariant proven from `resolveNowState`'s own logic. The two one-shot
scroll flags (`_didCentreLiveRow` / `_didCentreMarker`) are genuinely independent, reset together on
the same day-boundary condition, and the mutual-exclusion via `hasLiveRow` correctly keeps `Overdue`
on the live-row path only — confirmed by the plan's own transition regression test and re-run here
(`flutter test` green, `flutter analyze` clean).

One real defect was found and confirmed with a throwaway reproduction test (see WR-01): the
`NowMarkerRow`'s `Semantics` wrapper only encloses the `NowMarker` widget, not the
`TimelineRowTile` gutter that renders alongside it, so the row still emits two separate
screen-reader nodes — the exact "double announcement" 24-UI-SPEC.md says this design was chosen to
avoid. A second, lower-severity item (WR-02) is a pre-existing single-clock-sample violation in the
same file that this phase did not introduce but that matches, line for line, the defect class the
phase's own gate (commit `a8966b4`) just finished purging elsewhere — flagged because the review
brief specifically asked to hunt for exactly this. Two Info-level test-quality nits round out the
findings; no test in the new/changed suites depends on the real wall clock.

## Warnings

### WR-01: NowMarkerRow's accessibility merge doesn't include the time gutter — screen readers get two nodes, not one

**File:** `lib/screens/today/today_screen.dart:593-603`
**Issue:** The `Semantics(label: 'Now — ...', excludeSemantics: true, ...)` wrapper is placed around
`NowMarker()` only, then passed in as `TimelineRowTile`'s `child:`. `TimelineRowTile.build()`
(`lib/screens/today/widgets/timeline_row_tile.dart:72-87`) lays the gutter's `Text(formatMinutesCompact(...))`
out as a **sibling** of that `child` inside a `Row`, not a descendant of it — so `excludeSemantics`
never reaches the gutter text. I confirmed this with a throwaway widget test built from the exact
production wiring (`TimelineRowTile(startMinutes: 754, child: Semantics(..., child: NowMarker()))`
under `tester.ensureSemantics()`): `find.bySemanticsLabel('12:34p')` finds a node **and**
`find.bySemanticsLabel('Now — 12:34 PM')` finds a separate node — two nodes, not one (test deleted
after confirming; not left in the tree).

This directly contradicts 24-UI-SPEC.md's stated rationale for choosing `Semantics(excludeSemantics:
true)` over the old widget's `ExcludeSemantics`: "one clean announcement, not a double one," and "The
full `formatMinutes` string is still available to screen-reader users via the `Semantics` label
above; it's redundant only as *visible* text, not as spoken text" — which only holds if the gutter
text is *not* independently spoken. As shipped, a screen-reader user tabbing through the row hears
the raw compact gutter string ("12:34p," an unlabeled, oddly-abbreviated form) immediately followed
by the properly labeled "Now — 12:34 PM" — a redundant, differently-formatted double announcement
for the one row this phase specifically designed to read as a single clean one.

**Fix:** Move the `Semantics` wrapper outside `TimelineRowTile` so it encloses the whole row
(gutter included), not just the inner widget:
```dart
case NowMarkerRow(:final minutes):
  return KeyedSubtree(
    key: _nowMarkerKey,
    child: Semantics(
      label: 'Now — ${formatMinutes(minutes)}',
      excludeSemantics: true,
      child: TimelineRowTile(
        startMinutes: minutes,
        child: const NowMarker(),
      ),
    ),
  );
```
Add a widget test asserting exactly one relevant semantics node exists for the marker row (see IN-02
— this exact gap is why the double-node regression shipped with a fully green suite).

### WR-02: `_buildHeader` re-reads the clock independently of `build()`'s single `nowDt` sample (pre-existing, same invariant class the phase just fixed elsewhere)

**File:** `lib/screens/today/today_screen.dart:335`
**Issue:** `_buildHeader` (called from `build()`'s render path) does
`DateFormat('EEE d MMM').format(_nowFn())` — a second, independent call to the clock-injection seam,
rather than using the `nowDt` that `build()` already sampled once at line 985 for
`resolveNowState`/`_liveSecondsRemaining`/`nowMinutes`/the EOD card. This is not part of this phase's
diff (confirmed via `git blame`: commit `34192396`, 2026-08-07, one day before phase 24 started), but
it is the exact D-01 defect class the phase's own post-merge gate just found and fixed in the
end-of-day card (`a8966b4`) — "every widget test that pumped this screen silently changed behaviour
at 6pm local time" was caused by precisely this pattern (a widget reading its own clock instead of
the threaded sample). This instance's practical blast radius is small (it only affects the visible
"EEE d MMM" calendar-date string, and the two reads could only visibly disagree if a build straddles
a midnight rollover between the two calls), but it is a real, currently-live violation of the locked
invariant this review was specifically asked to re-check for, in a file this phase heavily edited.

**Fix:** Thread `nowDt` into `_buildHeader` the same way `_shouldShowEodCard` was just fixed to take
it, and drop the internal `_nowFn()` call:
```dart
Widget _buildHeader(BuildContext context, DailySchedule schedule, int mood, DateTime nowDt) {
  ...
  Text(DateFormat('EEE d MMM').format(nowDt), ...)
  ...
}
// call site: _buildHeader(context, schedule, mood, nowDt)
```

## Info

### IN-01: Test name overclaims what it asserts

**File:** `test/screens/today_row_widgets_test.dart:227-233`
**Issue:** `'no hardcoded Colors literal reaches the widget tree'` renders `NowMarker` and only
asserts `findsOneWidget` — it does not inspect any color value. The test's own comment concedes "the
real check is a static grep gate," so this test would still pass unchanged if a raw `Colors.red`
literal were added to the widget tomorrow. (Note: this mirrors a pre-existing identically-named test
at line 405 for `ChunkCard`, so it's a pattern this phase followed rather than invented — still worth
tightening.)
**Fix:** Either delete the test (the acceptance-criterion grep gate already covers this, per the
comment) or rename it to what it actually verifies (e.g., `'renders successfully under the seeded
theme (mood 3)'`).

### IN-02: No test exercises the now-marker's Semantics wiring at all

**File:** `test/screens/today_row_widgets_test.dart`, `test/screens/today_screen_test.dart`
**Issue:** Neither file has a single assertion against `Semantics`/`excludeSemantics`/
`find.bySemanticsLabel` for the now-marker, despite the accessibility treatment being the single most
narratively-justified design decision in 24-UI-SPEC.md (an entire "Verdict on the recovered pre-merge
widget" table devoted to it). This is exactly the coverage gap that let WR-01 ship with `flutter test`
fully green (503/503) and `flutter analyze` clean.
**Fix:** Add a widget test pumping `TimelineRowTile(startMinutes: ..., child: Semantics(...,
child: NowMarker()))` (or the full `TodayScreen` marker row) under `tester.ensureSemantics()` and
assert `find.bySemanticsLabel('Now — <time>')` finds exactly one node **and** that the gutter's raw
compact-time string is not independently reachable as its own node — this would have caught WR-01
directly.

---

_Reviewed: 2026-08-08T23:17:26Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
