---
phase: 17-time-anchored-home
fixed_at: 2026-06-13T00:00:00Z
review_path: .planning/phases/17-time-anchored-home/17-REVIEW.md
iteration: 2
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 17: Code Review Fix Report

**Fixed at:** 2026-06-13
**Source review:** .planning/phases/17-time-anchored-home/17-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 2 (1 Critical, 1 Warning)
- Fixed: 2
- Skipped: 0

**Test suite:** 243 tests pass (was 240 — 3 new tests added for gap state).
`flutter analyze lib/screens/home/home_screen.dart` — no issues found; switch exhaustiveness confirmed clean.

---

## Fixed Issues

### CR-01: `resolveNowState` returns `DayComplete` mid-morning when unresolved future chunks remain

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** 9491085
**Applied fix:**

Added `GapBeforeNext extends NowState` to the sealed hierarchy:

```dart
/// Current chunk is resolved and the next chunk's window has not yet opened.
/// The day is NOT complete — future unresolved work remains.
class GapBeforeNext extends NowState {
  final ScheduledChunk next;
  GapBeforeNext(this.next);
}
```

Replaced the gap guard's unconditional `return DayComplete()` in the advance-loop with a scan of remaining chunks for any unresolved future work:

```dart
if (candidate.displayStartMinutes! > currentMinutes) {
  final remaining = allWork
      .sublist(idx + 1)
      .where((c) => !c.isCompleted && !c.isSkipped)
      .firstOrNull;
  if (remaining != null) return GapBeforeNext(remaining);
  return DayComplete();
}
```

`DayComplete` is now returned in the gap case only when all future chunks are also resolved. When unresolved future work exists, `GapBeforeNext(remaining)` is returned instead.

Added `_buildGapBeforeNextContent` rendering an "Up next" heading and "Next up at [TIME]" body with calm inline copy (no accent, no day-complete language), matching the pre-start visual treatment per the UI-SPEC tone contract.

Added the `GapBeforeNext` arm to the exhaustive switch in `_buildNowContent`:

```dart
case GapBeforeNext(:final next):
  return _buildGapBeforeNextContent(context, next);
```

Updated the `resolveNowState` algorithm doc comment to document the new state and updated the `nextChunk` extraction comment (GapBeforeNext is excluded from the Next section — it renders its own inline "up next" content).

Verification: `flutter analyze lib/screens/home/home_screen.dart` → No issues found. The new sealed subtype is handled in every switch in the file.

Trace of the milestone scenario (CR-01 report, exact trace):
- c1=9:00–9:25 (resolved), c2=9:25–9:50 (pending), now=9:10 → `GapBeforeNext(c2)` ✓
- c1=9:00–9:25 (resolved), c2=10:00–10:25 (pending), now=9:30 → `GapBeforeNext(c2)` ✓
- c1=9:00–9:25 (resolved), c2=10:00–10:25 (skipped), now=9:30 → `DayComplete` ✓

---

### WR-01: Gap regression test asserts the wrong expected result and locks in CR-01

**Files modified:** `test/screens/home_screen_now_state_test.dart`
**Commit:** 30ea1c4
**Applied fix:**

Rewrote the `'gap (WR-01 regression)'` unit test to assert `isA<GapBeforeNext>()` with `next.id == 'c2'`. Added explicit `isNot(isA<DayComplete>())` and `isNot(isA<Active>())` assertions. Removed the misleading `reason: '... DayComplete (honest state)'` string.

Added two new unit tests:

**Near-gap companion:** now=9:10, c1=9:00–9:25 resolved, c2=9:25–9:50 pending → `GapBeforeNext(c2)`. Covers the imminent-next-window case (15 min gap) not exercised by the original 35-minute gap test.

**Gap with all-resolved future:** c1 done, c2 also skipped, now=9:30 → `DayComplete`. Confirms `DayComplete` is still returned when all future chunks are resolved. Maintains coverage of the genuinely-done-early path so `DayComplete` is not under-tested by the CR-01 fix.

Added one new widget test:

**Gap state widget:** pumps `HomeScreen` in the gap scenario (c1 resolved 9:00–9:25, c2 pending 10:00, now=9:30). Asserts:
- `find.text('Up next')` → findsOneWidget
- `find.textContaining('10:00 AM')` → findsOneWidget
- `find.text("That's a wrap")` → findsNothing
- `find.byType(ActiveChunkCard)` → findsNothing

Full test suite (`flutter test`): **243 tests, all passed.**

---

## Skipped Issues

None — all findings were fixed.

---

_Fixed: 2026-06-13_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
