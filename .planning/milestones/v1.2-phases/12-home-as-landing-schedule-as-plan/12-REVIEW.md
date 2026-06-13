---
phase: 12-home-as-landing-schedule-as-plan
reviewed: 2026-06-12T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/data/database/migrations.dart
  - lib/data/models/scheduled_chunk.dart
  - lib/router.dart
  - lib/screens/home/home_screen.dart
  - lib/screens/home/widgets/active_chunk_card.dart
  - lib/screens/schedule/schedule_screen.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/now_marker.dart
  - lib/utils/time_format.dart
  - test/data/migration_schema7_test.dart
  - test/screens/active_chunk_card_test.dart
  - test/screens/router_redirect_test.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-06-12
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Phase 12 refactors Home into the app's primary landing screen and demotes Schedule to a detail view. The routing, model, and widget work is structurally sound. No security vulnerabilities or data-loss risks were found. Four warnings were identified: one logic bug in the NowMarker placement algorithm that leaves the marker permanently misplaced after all past-time chunks are scanned, one dead field (`BreathingPulseCta.onPressed`) that can mislead callers, one silent `setState` call in `didChangeDependencies` that violates Flutter's contract, and a `hexToColor` + `_formatMinutes`/`_formatTimeRange` triplication across the codebase that will eventually diverge. Three info items cover hardcoded color literals, a magic fallback constant, and a redundant `_WrapperWidget` double-dispatch.

---

## Warnings

### WR-01: NowMarker placement algorithm has a forward-scan break that skips all past-time chunks after finding the first future one, but never advances past already-passed chunks — marker can end up before the wrong chunk

**File:** `lib/screens/schedule/schedule_screen.dart:120-130`

**Issue:** The NowMarker placement loop is intended to land the marker before "the first unresolved work chunk at or after the current wall time." The implementation has a subtle correctness gap:

1. `nowMarkerIndex ??= i` records the **first** unresolved work chunk as the fallback on first encounter.
2. The condition `(c.displayStartMinutes ?? 9999) >= nowMinutes` then immediately overwrites `nowMarkerIndex = i` and `break`s.

Because the `??=` fires unconditionally on first entry and `break` exits on the first chunk that satisfies `>= nowMinutes`, the algorithm is correct **only** when chunks are in strict time order and none lack a `displayStartMinutes`. However, when several consecutive unresolved chunks have `displayStartMinutes == null` (which is the documented normal state for discretionary chunks before a re-check-in), they all receive the fallback value `9999`, so the **very first** one triggers `>= nowMinutes` immediately and the marker is placed there — before the first unresolved chunk in the list — regardless of actual wall time. This means in a mixed list (some anchored, some discretionary) the marker can jump to an incorrect position.

Additionally, the two `DateTime.now()` calls on line 118-119 are in principle subject to a race across a minute boundary (both calls could straddle a minute tick), producing a one-minute jitter. This is cosmetic in practice but avoidable.

**Fix:**
```dart
final now = DateTime.now();
final nowMinutes = now.hour * 60 + now.minute;
int? nowMarkerIndex;

for (int i = 0; i < activeChunks.length; i++) {
  final c = activeChunks[i];
  if (c.chunkType != ChunkType.work || c.isCompleted || c.isSkipped) continue;

  // Always update fallback to keep it pointing at the LAST seen unresolved
  // chunk that has already started (or the first one if none have a time).
  final start = c.displayStartMinutes;
  if (start == null || start < nowMinutes) {
    // Chunk is either untimed or already in the past; treat it as current
    // until we find one that is in the future.
    nowMarkerIndex = i;
  } else {
    // First chunk at or after now — place marker here and stop.
    nowMarkerIndex = i;
    break;
  }
}
```
This also collapses the two `DateTime.now()` calls to one.

---

### WR-02: `BreathingPulseCta.onPressed` is a dead field — it is declared and required but never invoked inside the widget

**File:** `lib/screens/home/home_screen.dart:339,352`

**Issue:** `BreathingPulseCta` declares `required this.onPressed` and stores it as `final VoidCallback onPressed`, but `_BreathingPulseCtaState.build` never wraps `child` in a `GestureDetector` or `InkWell` that calls `widget.onPressed`. The widget is purely a decorative shadow container; the navigation callback is only on the inner `OutlinedButton` passed as `child`. The docstring even acknowledges this ("callers should attach the callback directly to their child widget as well"), but a *required* field that does nothing is a misrepresentation of the API contract. Any caller that relies on `onPressed` as the primary tap target (e.g., a test that bypasses the child widget) will silently get no action.

**Fix:** Either make the field optional (`VoidCallback? onPressed`) and wrap `child` in a `GestureDetector` that invokes it when non-null, or remove the field entirely and let callers attach callbacks only to the `child`. Given the docstring intent, making it optional with an outer `GestureDetector` is the safer choice:

```dart
// Make field optional
final VoidCallback? onPressed;

// In build():
return AnimatedBuilder(
  animation: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  builder: (context, child) {
    ...
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        decoration: ...,
        child: child,
      ),
    );
  },
  child: widget.child,
);
```

---

### WR-03: `didChangeDependencies` mutates state without calling `setState`, so the UI will not rebuild when `_eodCardDismissed` is reset

**File:** `lib/screens/home/home_screen.dart:57-65`

**Issue:** `didChangeDependencies` resets `_eodCardDismissed = false` (line 63) with a bare assignment, not wrapped in `setState(() { ... })`. Flutter's `State` contract requires `setState` to schedule a rebuild. Without it, the reset happens in memory but the widget is not marked dirty, so the `EndOfDayCard` will not reappear on a new schedule date until some other unrelated `setState` call happens to trigger a rebuild. This is a logic bug that can cause the EoD card to remain hidden across a date transition.

**Fix:**
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final notifier = context.read<ScheduleNotifier>();
  final newDateYmd = notifier.todaySchedule?.dateYmd;
  if (newDateYmd != _lastScheduleDateYmd) {
    setState(() {
      _lastScheduleDateYmd = newDateYmd;
      _eodCardDismissed = false;
    });
  }
}
```

---

### WR-04: `hexToColor`, `_formatMinutes`, and `_formatTimeRange` are duplicated across `lib/utils/time_format.dart`, `lib/screens/schedule/widgets/chunk_card.dart`, and `lib/screens/goals/widgets/goal_card.dart` — divergence risk

**File:** `lib/utils/time_format.dart:4-22` / `lib/screens/schedule/widgets/chunk_card.dart:7-23`

**Issue:** `hexToColor` is defined identically in three files (`time_format.dart`, `chunk_card.dart`, `goal_card.dart`), and `_formatMinutes`/`_formatTimeRange` are duplicated between `time_format.dart` and `chunk_card.dart`. The `time_format.dart` utility file was introduced (presumably in this phase) to provide a single canonical home, but `chunk_card.dart` was not updated to import it — it still carries its own private copies. Multiple sites importing `chunk_card.dart` to gain `hexToColor` (e.g., `end_of_day_summary_screen.dart`, `focus_screen.dart`, `donut_chart.dart`) will silently continue using the stale copy if `time_format.dart`'s implementation is ever changed.

**Fix:** Remove the top-level functions from `chunk_card.dart` and `goal_card.dart`, and have all callers import `package:canopy/utils/time_format.dart` directly:

```dart
// chunk_card.dart — delete lines 1-23 (hexToColor, _formatMinutes, _formatTimeRange)
// and add:
import '../../../utils/time_format.dart';

// Replace _formatTimeRange(... ) calls with formatTimeRange(...)
```

---

## Info

### IN-01: `ScheduleScreen._moodColors` duplicates the mood-seed palette already in `ThemeNotifier.moodSeeds` — two sources of truth for mood colors

**File:** `lib/screens/schedule/schedule_screen.dart:20-27`

**Issue:** `ScheduleScreen` declares its own `static const Map<int, Color> _moodColors` with five hardcoded `Color(0xFF...)` literals. `HomeScreen` correctly uses `ThemeNotifier.moodSeeds` for the same purpose. This is inconsistent: a future mood-palette change needs to be applied in two places and the two palettes are already different (Schedule uses `0xFF4A6275` for mood 1; ThemeNotifier would use whatever its seed is).

**Fix:** Replace the local map with a reference to `ThemeNotifier.moodSeeds`, matching the pattern already used in `HomeScreen`:
```dart
// Delete _moodColors map
final moodColor = ThemeNotifier.moodSeeds[mood] ?? ThemeNotifier.moodSeeds[3]!;
```

---

### IN-02: Magic sentinel value `9999` used for untimed chunks in NowMarker placement

**File:** `lib/screens/schedule/schedule_screen.dart:125`

**Issue:** `(c.displayStartMinutes ?? 9999) >= nowMinutes` uses `9999` as a sentinel meaning "treat as infinitely late." 9999 is past midnight of day 7 in minutes-from-midnight space (9999 / 60 = 166 hours), which works today, but silently breaks if `nowMinutes` is ever compared against a different range or if the sentinel is reused elsewhere with different semantics. A named constant makes intent explicit and avoids accidental future reuse.

**Fix:**
```dart
const int _kUntimedChunkSentinel = 9999; // beyond any same-day minute value
if ((c.displayStartMinutes ?? _kUntimedChunkSentinel) >= nowMinutes) { ...
```

---

### IN-03: `_HomeScreenState._shouldShowEodCard` is a one-line pass-through wrapper with no added value

**File:** `lib/screens/home/home_screen.dart:264-265`

**Issue:**
```dart
bool _shouldShowEodCard(List<ScheduledChunk> chunks) =>
    shouldShowEodCard(chunks);
```
The method exists solely to allow the docstring to reference a unit-testable top-level function. The wrapper adds no logic and the caller on line 130 could invoke `shouldShowEodCard(schedule.chunks)` directly. This is a minor maintainability issue — a reader must follow two hops to understand the call. The docstring justification (unit-testability) is addressed by the top-level function existing, not by the wrapper.

**Fix:** Remove the wrapper and call `shouldShowEodCard(schedule.chunks)` directly at the call site on line 130.

---

_Reviewed: 2026-06-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
