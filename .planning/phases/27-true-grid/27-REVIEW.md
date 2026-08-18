---
phase: 27-true-grid
reviewed: 2026-08-18T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - lib/screens/today/timeline_geometry.dart
  - lib/screens/today/today_screen.dart
  - lib/screens/today/widgets/live_row_card.dart
  - test/screens/today_row_widgets_test.dart
  - test/screens/today_screen_now_state_test.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_timeline_model_test.dart
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
fixed_at: 2026-08-18T15:30:00Z
fix_report: 27-REVIEW-FIX.md
---

# Phase 27: Code Review Report

**Reviewed:** 2026-08-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed the full Phase 27 diff (`1fe5a75~1..HEAD`): the deletion of `liveExtraPx`/
`kLiveRowReservedHeight` from `TimelineGeometry`, the live row's move onto the shared
`Positioned(height:)` + `ClipRect`/`OverflowBox` path, the rebuilt `LiveRowCard` two-tier
widget, and the four touched test files.

**Core claims verified true by direct inspection, not just by trusting the summaries:**
- `TimelineGeometry.yFor()` (`timeline_geometry.dart:290-295`) is a single unconditional
  expression — no `if`, no branch, no remaining reference to a live-row exception anywhere in
  `lib/` or `test/` (`grep -rn "liveExtraPx|kLiveRowReservedHeight"` returns only a plain-text
  historical mention inside a doc comment, not a live symbol).
- `kCompactLiveMinHeight` (84.0) is used with the exact `>=` comparison the UI-SPEC specifies
  (`live_row_card.dart:79`), and the widget test at the exact boundary
  (`slotHeight: kCompactLiveMinHeight` → compact, `-1` → single-line) confirms no off-by-one.
- Both tiers restate `kCardLeftInset`/`kTimelineRowInset` on the `Card`'s own `margin` (compact:
  `top/bottom: 4`; single-line: `top/bottom: 0`, PD-27-01) — the previously-shipped
  horizontal-bleed regression `timeline_row_tile.dart`'s doc comment records is not reintroduced.
- No spike scaffolding (`kSpikeVariant`, `--dart-define`, nullable `slotHeight` branching) leaked
  into `lib/`.
- `flutter analyze` is clean and the full touched-file test run (190 tests across the four files)
  passes locally, independently re-run rather than taken on the summaries' word.
- No drift toward an in-app AI/LLM surface — this phase is pure layout/geometry work, consistent
  with `CLAUDE.md`'s "dumb app on purpose" constraint.

Two issues remain from the deletions/repairs that the summaries did not fully close out: a
hit-testing regression test that was weakened to work around a now-fixed intermediate defect and
was never restored, and two doc comments left referencing deleted concepts (the progress bar, the
"Next · …" line). Neither is a functional bug in shipped behavior; both degrade the suite's and
the code's reliability as a regression guard / accurate reference for the next agent who reads
them. Two additional info-level robustness/maintainability notes are recorded below.

Not independently re-verified here (out of this review's scope, and already honestly flagged as
incomplete by the phase's own artifacts): the real-device UAT checkpoint in `27-04-SUMMARY.md`
Task 3 (36×36dp touch targets, now-line legibility, "132dp shorter" scroll feel) is explicitly
still PENDING as of that summary. That is a process-completeness gap the phase has already
disclosed, not something this review is flagging as newly discovered.

## Warnings

### WR-01: Hit-test regression test bypasses real hit-testing after the defect it worked around was fixed

**Disposition: fixed** — commit `9c2ef68`. Restored the real `tester.tap(find.text('Reading'))`.
Verified two ways: (1) `flutter test` passes with the real tap on current `HEAD`; (2) temporarily
reverted `today_screen.dart`'s live-row `Positioned(height: slot)` back to `height: null`
(simulating the pre-27-02 defect) in the isolated fix worktree and re-ran the same test — it failed
with an off-target hit, confirming the restored test is a meaningful regression guard again. The
production revert was discarded before committing; only the test file changed.

**File:** `test/screens/today_screen_test.dart:497-534`
**Issue:** The test `'tapping an unresolved non-live work row opens ChunkDetailSheet'` was
changed in plan 27-01 (commit `aed0949`) from a real `tester.tap(find.text('Reading'))` to a
direct `chunkCard.onTap!()` invocation, with a comment explaining that plan 27-01's own geometry
fix (deleting `liveExtraPx`) temporarily made the live row's card paint over the row beneath it
with no `height:` bound, so a geometric tap landed on the overlapping live card instead of the
target `ChunkCard`. That overlap was itself a documented, intentional intermediate-state defect,
explicitly deferred to plan 27-02.

Plan 27-02 (commit `be64721`) fixed it: the live row now goes through the identical
`Positioned(height: slot)` + `ClipRect`/`OverflowBox` path every other row uses
(`today_screen.dart:765-784`), so c3 (the live break in this fixture) and c4 ("Reading") are
verifiably non-overlapping — confirmed independently in this review both by inspecting the
positioning code and by the sibling test `'two clock-contiguous chunks: the second slot top
equals the first slot top plus the first slot height'` (`today_screen_test.dart:665-694`), which
proves c4's top is exactly c3's top plus c3's height with the current fixture shapes.

Plan 27-03 touched this same test (commit `aea7bab`) to remove a stale comment, but did not
restore the real `tester.tap()` call even though the defect that justified bypassing it was
already gone by that point. As shipped, this test can no longer catch an actual hit-testing
regression (e.g. a future change that re-introduces an overlap, adds an `IgnorePointer` in the
wrong place, or renders a decoy widget on top) — it only proves that the `ChunkCard.onTap`
callback, once located and invoked directly, opens `ChunkDetailSheet`. That is a materially
weaker claim than the test's own name ("tapping … opens ChunkDetailSheet").

**Fix:**
```dart
testWidgets(
  'tapping an unresolved non-live work row opens ChunkDetailSheet',
  (tester) async {
    await pumpDay(tester);
    await tester.ensureVisible(find.text('Reading'));
    await tester.tap(find.text('Reading'));
    await tester.pump();
    expect(find.byType(ChunkDetailSheet), findsOneWidget);
  },
);
```
Restore the geometric tap now that plan 27-02's fix makes it safe again; if it fails, that is
exactly the regression this test exists to catch.

### WR-02: Stale doc comments reference concepts this phase deleted

**Disposition: fixed** — commit `c144f8f`. Both doc comments rewritten to describe current
behavior; the progress-bar removal is kept as a dated parenthetical rather than deleted outright,
per this codebase's convention of keeping amendment history.

**File:** `lib/screens/today/today_screen.dart:822-823`, `:873-874`
**Issue:** Two doc comments still describe deleted mechanisms as if they exist:
- `_chunkTitle`'s doc comment (line 822) says it is "used everywhere a chunk is named EXCEPT the
  live row itself (the `"Next · …"` line, the edge-state bodies)" — the live row's `"Next · …"`
  line was deleted this phase (GRID-02); the parenthetical now names a UI element that no longer
  exists anywhere in the file.
- `_liveSecondsRemaining`'s doc comment (line 873-874) says it "Feeds the live row's
  remaining-time label, its progress bar, AND the fast-timer decision" — the progress bar was
  deleted this phase (GRID-02, confirmed via `grep -rn "LinearProgressIndicator" lib/screens/
  today/` returning zero hits under `lib/screens/today/`). Only two consumers remain, not three,
  and the "all three read this one value, they can never disagree (P-5)" reasoning that follows is
  now describing a pairing that no longer has a third member.
**Fix:**
```dart
// today_screen.dart:822
/// Builds the *reference* title string for a chunk — used everywhere a
/// chunk is named EXCEPT the live row itself (see [_liveTitle]) and the
/// edge-state bodies' break-awareness call sites.

// today_screen.dart:873
/// The single source of "how much of the current activity is left," in
/// whole seconds. Feeds the live row's remaining-time label AND the
/// fast-timer decision ([_syncFastTimer]) — because both read this one
/// value, they can never disagree (P-5).
```

## Info

### IN-01: Single-line tier's countdown suffix has no overflow guard

**Disposition: fixed** — commit `e813e5d`. Added a comment above the countdown `Text` naming the
known, accepted overflow risk at large accessibility text scales. Layout behavior is unchanged, per
the finding's own guidance (the UI-SPEC's non-truncation rule stays in force).

**File:** `lib/screens/today/widgets/live_row_card.dart:251`
**Issue:** `Text(' · $remainingLabel', maxLines: 1, style: style)` is a non-`Expanded` sibling of
the `Expanded` title `Text` inside a `Row`. `27-UI-SPEC.md`'s "Single-line tier" section locks
this as deliberate ("the remaining-time suffix never truncates … only the title … sacrifices
characters"), so the *intent* is correct, but the mechanism only protects the countdown from being
squeezed by the title — if the countdown string itself (plus zero-width title) still exceeds the
available row width, this produces a `RenderFlex` overflow rather than a graceful clip/ellipsis.
Under default text scale and the app's typical `remainingLabel` lengths this is very unlikely to
trigger, and `27-VALIDATION.md` explicitly scopes large accessibility text scales as "Not covered
by this phase's verification, and deliberately so" — so this is not a regression this phase needs
to fix, but it is a latent robustness gap worth a defensive `overflow: TextOverflow.clip` (already
implicit) plus a code comment recording the known risk, so a future agent chasing an overflow
report at a large text scale isn't starting from zero.
**Fix:** Add a short comment above the `Text(' · $remainingLabel', ...)` noting the known,
accepted overflow risk at large accessibility text scales (per `27-VALIDATION.md`'s explicit
scoping), so it reads as a documented trade rather than an oversight the next reader has to
re-discover.

### IN-02: Duplicated Complete/Skip `IconButton` blocks invite drift

**Disposition: fixed** — commit `d378b9a`. Extracted `_buildActionIcon`; each call site still
states its own icon, color, tooltip, and callback, with the sizing/tap-target rationale comment
now living in one place.

**File:** `lib/screens/today/widgets/live_row_card.dart:150-199`
**Issue:** The compact tier's Complete and Skip `IconButton`s are two independently-written
~25-line blocks that differ only in icon, color, tooltip string, and `onPressed` callback — every
other property (`constraints`, `padding`, `style: IconButton.styleFrom(tapTargetSize:
MaterialTapTargetSize.shrinkWrap)`) is duplicated verbatim. This is exactly the kind of duplication
that already caused friction once in this same plan: the 27-02 deviation log records that the
36×36dp touch-target fix (removing `visualDensity: VisualDensity.compact`, adding
`tapTargetSize: shrinkWrap`) had to be applied to *both* blocks by hand. A future change to one
(e.g. a new icon size, a disabled state) risks being applied to only one button if not caught in
review.
**Fix:**
```dart
Widget _buildActionIcon({
  required IconData icon,
  required Color color,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return IconButton(
    icon: Icon(icon),
    color: color,
    tooltip: tooltip,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: onPressed,
  );
}
```
Call it twice with the icon/color/tooltip/callback that differ, keeping the touch-target-sizing
rationale comment in one place instead of two.

---

_Reviewed: 2026-08-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
