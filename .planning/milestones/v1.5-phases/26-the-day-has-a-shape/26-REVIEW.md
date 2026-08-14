---
phase: 26-the-day-has-a-shape
reviewed: 2026-08-11T00:00:00Z
depth: deep
files_reviewed: 16
files_reviewed_list:
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/screens/today/timeline.dart
  - lib/screens/today/timeline_geometry.dart
  - lib/screens/today/today_screen.dart
  - lib/screens/today/widgets/free_time_row.dart
  - lib/screens/today/widgets/hour_axis.dart
  - lib/screens/today/widgets/now_line.dart
  - lib/screens/today/widgets/now_marker.dart (deleted)
  - lib/screens/today/widgets/timeline_row_tile.dart
  - lib/utils/time_format.dart
  - test/screens/today_row_widgets_test.dart
  - test/screens/today_screen_now_state_test.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_timeline_model_test.dart
  - test/utils/time_format_test.dart
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: fixed
fix_report: 26-REVIEW-FIX.md
---

# Phase 26: Code Review Report

**Reviewed:** 2026-08-11
**Depth:** deep
**Files Reviewed:** 16
**Status:** fixed — see `26-REVIEW-FIX.md`

## Summary

This phase converts `TodayScreen`'s timeline to an absolutely-positioned `Stack` driven by a
single new arithmetic authority, `TimelineGeometry`. I traced every pixel-producing call site
(`_buildPositionedRow`'s four row arms, `HourAxisLine`, `NowLineOverlay`, and the scroll-on-open
`animateTo` target) back to `TimelineGeometry.yFor`/`heightFor`/`totalHeight` and found no
independent re-derivation anywhere — `grep` for `kPixelsPerMinute`/`kLiveRowReservedHeight`
outside `timeline_geometry.dart` turns up only comments. The `liveExtraPx` `>=`-at-`liveEnd`
convention is applied identically by `yFor` (today_screen.dart:1361 hour axis, :1307 now-line,
:707/:739/:765 rows) and by the now-line's chip-suppression boundary (`>= liveStart && <
liveEnd`), and both boundaries land on the exact same minute as `now_state.dart`'s
Active→Overdue transition (`currentMinutes >= windowEnd`), so I could not construct a case where
the line, a row, or the chip disagree about where a minute sits. Scroll safety holds: no
`initialScrollOffset`, `maxScrollExtent` is read only inside the post-frame callback, and the
one-shot flag is set synchronously before the callback is scheduled, matching the documented
T-22-08 discipline. The G-03 timer/lifecycle contract (1-minute ticker survives `paused`,
1-second ticker gated by `_isBackgrounded`, `build()` self-heals a dead `_nowTimer`) is intact
and unchanged by this phase's diff. `NowMarkerRow`'s deletion left no orphaned references —
`flutter analyze` is clean and the full suite (558 tests) passes. The `26-09` regression test
now correctly asserts against `LiveRowCard` (the widget the defect actually lived in), closing
the gap the earlier `ChunkCard`-scoped assertion left open, and the rest of the new test suite
(`TimelineGeometry`, `NowLineOverlay`, `HourAxisLine`, `ChunkCardDensity`) is table-driven,
recomputes expected values from the fixture's own numbers rather than hard-coded pixels, and
consistently full-unmounts between clock changes to avoid the stale-closure pitfall this
codebase has been bitten by before.

No blocker-level defects found. Two warnings (an orphaned dartdoc block that silently drops this
phase's own G-01/G-03 design rationale from generated docs, and a real block of duplicated
widget-building logic in `chunk_card.dart`) and one info-level dead-code note.

## Warnings

### WR-01: `NowLineOverlay`'s primary doc comment is severed from the class by a blank line

**File:** `lib/screens/today/widgets/now_line.dart:7-46`
**Issue:** The class's doc comment is written as one long block (lines 7-34) explaining the
widget's purpose, G-01 (chip gutter confinement) and G-03 (chip suppression over the live row).
Line 36 is a genuine blank line (no `///`), which splits the doc comment in two: dartdoc/IDE
hover only attach the *immediately preceding, contiguous* `///` block to a declaration, so only
the short second paragraph ("Carries NO `Semantics` node of its own...", lines 37-45) is actually
attached to `class NowLineOverlay`. The much larger first block — which is where the G-01/G-03
rationale actually lives, the exact kind of institutional knowledge this codebase leans on
heavily (see the `26-UI-SPEC.md` cross-references throughout) — becomes a dangling comment that
`dart doc` output and most IDEs' hover tooltips will not show against the class. A future agent
reading only the generated docs (rather than the raw source) will miss why `showChip` exists at
all.
**Fix:** Delete the stray blank line at line 36 so the whole block is one contiguous `///` run
immediately above `class NowLineOverlay`:
```dart
/// parameter away; without it the chip re-collides with the live row.
///
/// Carries NO `Semantics` node of its own. The call site in
/// `today_screen.dart` applies one labelled `excludeSemantics` node around
...
class NowLineOverlay extends StatelessWidget {
```

### WR-02: `_buildDetailedContent` and `_buildFullContent` duplicate ~90 lines of widget structure

**File:** `lib/screens/schedule/widgets/chunk_card.dart:412-526`
**Issue:** `ChunkCardDensity.detailed` and `.full` both render the same `Row` → `Expanded` →
`Column` → title `Text` → time-range-or-duration `Text` → trailing status shell; the *only*
difference between the two methods is that `_buildDetailedContent` additionally renders the
rationale line, the priority chip, and the valence chip. As written, any future change to the
shared shell (e.g. adjusting the title's `overflow` behaviour, or the time-range/duration
fallback logic) has to be made identically in two places, and the two already show early signs
of drift risk — nothing enforces that they stay in sync beyond a human remembering to edit both.
**Fix:** Extract the shared shell into one method that renders title + time/duration + trailing
status + action row, and take the "extra" widgets (rationale/priority/valence) as an optional
`List<Widget>` (empty for `full`, populated for `detailed`):
```dart
Widget _buildContentShell(
  BuildContext context,
  ThemeData theme,
  bool isResolved, {
  List<Widget> extras = const [],
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_titleText, /* ... */),
                /* time range / duration fallback */,
                ...extras,
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildTrailingStatus(theme),
        ],
      ),
      if (!isResolved) ...[const SizedBox(height: 12), _buildActionRow(context, theme)],
    ],
  );
}
```

## Info

### IN-01: Untimed `ChunkRow`s add a dead zero-size `Positioned` to the Stack

**File:** `lib/screens/today/today_screen.dart:715-727`
**Issue:** When `chunk.displayStartMinutes == null`, `_buildPositionedRow` returns a
`Positioned(top: 0, left: 0, width: 0, height: 0, child: SizedBox.shrink())`, which is then added
to the Stack's non-live-rows loop (`today_screen.dart:1323-1331`) *in addition to* the real
`TimelineRowTile` the same chunk gets rendered as in the trailing untimed block
(`today_screen.dart:1402-1411`). It contributes nothing visually and the doc comment
acknowledges the generator never produces this case today, but it is dead code that a future
reader has to reason through to confirm is actually inert, and it churns an extra `Element` per
untimed chunk on every build for no benefit.
**Fix:** Filter untimed `ChunkRow`s out of the "every non-live row" loop instead of relying on
`_buildPositionedRow` to emit an inert placeholder:
```dart
for (final row in timelineRows)
  if (!(row is ChunkRow && row.isLive) &&
      !(row is ChunkRow && row.chunk.displayStartMinutes == null))
    _buildPositionedRow(context, row, geometry, nowState, liveSecondsLeft),
```

---

## Fix Status

All three findings (WR-01, WR-02, IN-01) were applied and committed. See `26-REVIEW-FIX.md` for
per-finding commit hashes and verification detail.

---

_Reviewed: 2026-08-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
