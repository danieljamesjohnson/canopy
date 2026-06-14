# Phase 17: Time-Anchored Home - Research

**Researched:** 2026-06-13
**Domain:** Flutter StatefulWidget lifecycle, dart:async Timer.periodic, chunk selection logic
**Confidence:** HIGH — all findings verified directly from codebase

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Claude's Discretion
All implementation choices — the injectable `now` parameter shape, private widget vs. inline builder, overdue indicator rendering.

### Deferred Ideas (OUT OF SCOPE)
None — discuss phase skipped.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOW-01 | "Now" reflects the chunk whose clock-time window contains the *current* time (not merely the first unresolved chunk); "Next" shows the following chunk. At 6pm with nothing checked off, the 8am chunk is no longer shown as "Now." | Selection logic is in `home_screen.dart` lines 104–111 (two-liner, no function). Replace with `_resolveNowState()` that reads `displayStartMinutes`/`durationMinutes` from `ScheduledChunk`. |
| NOW-02 | Before the day's first chunk and after the last resolved/ended chunk, Home shows a clear pre-start / day-complete state rather than a stale "Now." | The current fallback when `currentChunk == null` is "All done today!" (line 151). Replace with two distinct states: pre-start and day-complete. The new `_resolveNowState()` returns a discriminated result enum/sealed class so the `build` method can switch on it. |
</phase_requirements>

---

## Summary

Phase 17 reworks a single two-line chunk-selection expression in `_HomeScreenState.build()` (lines 104–111 of `lib/screens/home/home_screen.dart`) into a proper state-classification function `_resolveNowState()`. The function replaces "first unresolved" with "the chunk whose `[displayStartMinutes, displayStartMinutes + durationMinutes)` window contains `currentMinutesSinceMidnight`" and returns one of four states: pre-start, active (or overdue), or day-complete. A 1-minute `Timer.periodic` is added to `_HomeScreenState` so the "Now" zone updates as time passes, following the same lifecycle pattern (`WidgetsBindingObserver`, pause on backgrounded, resume on foreground) already used in `ThemeNotifier`.

The data model already has everything needed: `ScheduledChunk.displayStartMinutes` (a computed getter returning `anchoredStartMinutes ?? syntheticStartMinutes`) and `ScheduledChunk.durationMinutes`. No model changes, no new packages, no new screens. The only new UI elements are two private inline widgets (`_PreStartContent` and `_DayCompleteContent`) that reuse the existing `Padding/Column/Text` pattern already present in the "All done today!" fallback (line 151 of home_screen.dart).

**Primary recommendation:** Implement `_resolveNowState(DateTime Function() now)` as a pure function of `schedule.chunks` and the injected clock. Add a 1-minute timer that calls `setState()`. Add two inline state widgets. Update existing tests to use `syntheticStartMinutes` with a time-controlled fake.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Chunk-selection logic (`_resolveNowState`) | Frontend (StatefulWidget) | — | Pure function of schedule data + wall clock; no server round-trip. Lives in HomeScreen state, injectable for tests. |
| 1-minute periodic timer | Frontend (StatefulWidget lifecycle) | — | `Timer.periodic` in `initState`/`dispose` of `_HomeScreenState`; mirrors `FocusScreen` and `ThemeNotifier` patterns already in codebase. |
| Pre-start inline state | Frontend (StatefulWidget build) | — | Private widget or `if` branch inside `build`; reads first work chunk from selection result. |
| Day-complete inline state | Frontend (StatefulWidget build) | — | Private widget or `if` branch inside `build`; no chunk reference needed. |
| Clock-time window data | Data model (`ScheduledChunk`) | — | `displayStartMinutes` (getter) and `durationMinutes` are already on the model — no migration. |
| Test time injection | Test layer | — | `DateTime Function() now` parameter on `_resolveNowState`; fakes passed via `_FakeScheduleNotifierWithSchedule` subclass pattern already in test file. |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `dart:async` (built-in) | SDK | `Timer.periodic` for 1-minute tick | Already used in `ThemeNotifier` and `FocusScreen` — established project pattern. [VERIFIED: codebase grep] |
| `flutter/material.dart` (built-in) | SDK | `WidgetsBindingObserver` for lifecycle pause/resume | Already used by `ScheduleNotifier`, `ThemeNotifier`, `BreathingPulseCta`. [VERIFIED: codebase grep] |
| `provider` (existing dep) | ^6.x | `context.watch<ScheduleNotifier>()` already in use | No change to provider usage. [VERIFIED: codebase grep] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `time_format.dart` (local util) | n/a | `formatMinutes()` for pre-start "Your day starts at [TIME]" | Already imported in home_screen.dart — no new import. [VERIFIED: codebase grep] |

**No new packages required.** The UI-SPEC Registry Safety section explicitly confirms this.

---

## Package Legitimacy Audit

No new packages are installed in this phase. Section not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
User views HomeScreen
        |
        v
_HomeScreenState.build()
        |
        +--> context.watch<ScheduleNotifier>()
        |         |
        |         v
        |    schedule.chunks (List<ScheduledChunk>)
        |         |
        v         v
_resolveNowState(now: _nowFn)
        |
        | filter: ChunkType.work && displayStartMinutes != null
        | sort: by displayStartMinutes ascending
        |
        +--> allWork.isEmpty          --> DayCompleteState()
        +--> currentMinutes < first   --> PreStartState(first)
        +--> currentMinutes >= end of last  --> DayCompleteState()
        +--> else: find lastWhere(start <= currentMinutes)
                   if resolved: advance to next unresolved
                   if none: DayCompleteState()
                   else: ActiveState(chunk, nextChunk?) or OverdueState(chunk, nextChunk?)
        |
        v
build() switches on result:
  PreStartState    --> _PreStartContent widget
  ActiveState      --> ActiveChunkCard(chunk) + Next row
  OverdueState     --> ActiveChunkCard(chunk, overdue=true) + Next row
  DayCompleteState --> _DayCompleteContent widget

Timer.periodic(1 min) --> setState() --> rebuild --> re-evaluates _resolveNowState
```

### Recommended Project Structure

No new directories. All changes are within:
```
lib/screens/home/
├── home_screen.dart       # Primary file — adds _resolveNowState(), timer, new private widgets
└── widgets/
    ├── active_chunk_card.dart   # No change
    ├── end_of_day_card.dart     # No change
    └── review_banner.dart       # No change

test/screens/
└── active_chunk_card_test.dart  # Existing file — update existing "all done" test + add 6 new tests
```

A new test file `test/screens/home_screen_now_state_test.dart` is the cleanest home for the time-parameterized tests; or the 6 new tests can be added to `active_chunk_card_test.dart` in a new group.

### Pattern 1: `_resolveNowState()` — pure function, injectable clock

**What:** A private method (or top-level function for testability) that takes `DateTime Function() now` and `List<ScheduledChunk> chunks` and returns a sealed class / discriminated enum result.

**When to use:** Called on every `build()` and on every timer tick (via `setState()`).

**Key design decision — sealed class vs enum:** Using a Dart sealed class gives the planner flexibility to carry typed payloads (the matched chunk, the next chunk, the first chunk's start time) without a parallel nullable lookup. The `switch` in `build()` exhausts all cases at compile time.

**Example (pseudocode for planner):**
```dart
// Source: codebase — home_screen.dart line 104 (current logic to replace)

// NEW — add to _HomeScreenState or extract as top-level:
sealed class _NowState {}
class _PreStart extends _NowState { final ScheduledChunk firstChunk; _PreStart(this.firstChunk); }
class _Active extends _NowState { final ScheduledChunk current; final ScheduledChunk? next; _Active(this.current, this.next); }
class _Overdue extends _NowState { final ScheduledChunk overdue; final ScheduledChunk? next; _Overdue(this.overdue, this.next); }
class _DayComplete extends _NowState {}

_NowState _resolveNowState({ required List<ScheduledChunk> chunks, required DateTime Function() now }) {
  final currentMinutes = now().hour * 60 + now().minute;
  final allWork = chunks
      .where((c) => c.chunkType == ChunkType.work && c.displayStartMinutes != null)
      .toList()
      ..sort((a, b) => a.displayStartMinutes!.compareTo(b.displayStartMinutes!));

  if (allWork.isEmpty) return _DayComplete();

  if (currentMinutes < allWork.first.displayStartMinutes!) {
    return _PreStart(allWork.first);
  }
  if (currentMinutes >= allWork.last.displayStartMinutes! + allWork.last.durationMinutes) {
    // Check if all resolved — also day-complete even if time hasn't passed
    return _DayComplete();
  }

  // Find the chunk whose window contains now (or the most recent past chunk)
  final candidates = allWork.where((c) => c.displayStartMinutes! <= currentMinutes).toList();
  var active = candidates.last;

  // If this chunk is resolved, advance to next unresolved
  while (active.isCompleted || active.isSkipped) {
    final idx = allWork.indexOf(active);
    if (idx + 1 >= allWork.length) return _DayComplete();
    active = allWork[idx + 1];
  }

  // Find next chunk after active
  final activeIdx = allWork.indexOf(active);
  final next = allWork.sublist(activeIdx + 1)
      .where((c) => !c.isCompleted && !c.isSkipped)
      .firstOrNull;

  final windowEnd = active.displayStartMinutes! + active.durationMinutes;
  if (currentMinutes >= windowEnd) {
    return _Overdue(active, next);
  }
  return _Active(active, next);
}
```

**Fallback when all chunks have `displayStartMinutes == null`:** The filter `allWork` yields empty → returns `_DayComplete()`. The old "first unresolved" behavior is NOT preserved in this fallback (UI-SPEC edge case table says "fall back to old behavior" but the CONTEXT.md says all choices are Claude's discretion — using day-complete is cleaner and avoids hidden state). **This is a planning decision the planner should call out explicitly.**

### Pattern 2: 1-Minute Timer Lifecycle (mirror ThemeNotifier)

**What:** A `Timer.periodic` in `_HomeScreenState.initState()` that calls `setState()` once per minute so `_resolveNowState()` is re-evaluated with fresh `DateTime.now()`.

**When to use:** Always — the timer must run whenever HomeScreen is in the widget tree and the app is in the foreground.

**Example:**
```dart
// Source: lib/providers/theme_notifier.dart lines 205-219 (lifecycle pattern)
// and lib/screens/focus/focus_screen.dart lines 55-71 (in-widget Timer pattern)

// In _HomeScreenState:
Timer? _nowTimer;

@override
void initState() {
  super.initState();
  _startNowTimer();
  WidgetsBinding.instance.addObserver(this); // for lifecycle pause/resume
  _checkReviewWindow();
}

void _startNowTimer() {
  _nowTimer?.cancel();
  _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (mounted) setState(() {}); // triggers rebuild → _resolveNowState re-runs
  });
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _startNowTimer();
  } else if (state == AppLifecycleState.paused) {
    _nowTimer?.cancel();
  }
}

@override
void dispose() {
  _nowTimer?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

**Critical:** `_HomeScreenState` does NOT currently mix in `WidgetsBindingObserver`. It must be added in this phase for the pause/resume timer behavior. `BreathingPulseCta` already uses this pattern (`with WidgetsBindingObserver`) — see home_screen.dart lines 373, 389, 409, 426.

### Pattern 3: `_PreStartContent` inline widget

**What:** A private `StatelessWidget` or inline builder rendering the pre-start state. Reuses the existing `Padding/Column/Text` pattern from the "All done today!" inline text (home_screen.dart lines 151-159).

**Example (structure only):**
```dart
// Source: lib/screens/home/home_screen.dart lines 151-159 (existing pattern to mirror)
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Your day starts at ${formatMinutes(firstChunk.displayStartMinutes!)}',
           style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('$goalName · ${firstChunk.durationMinutes} min',
           style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
    ],
  ),
)
```

**Note:** `goalName` for the first chunk requires `_lookupGoalName(context, firstChunk)` — the method already exists on `_HomeScreenState` (line 282).

### Pattern 4: `_DayCompleteContent` inline widget

**What:** Mirror of pre-start but with static copy ("That's a wrap" / "You've reached the end of today's schedule.").

**Example (structure only):**
```dart
// Source: same Padding pattern as pre-start, home_screen.dart lines 151-159
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text("That's a wrap",
           style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text("You've reached the end of today's schedule.",
           style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
    ],
  ),
)
```

### Anti-Patterns to Avoid

- **Putting `_resolveNowState` logic in `ScheduleNotifier`:** The notifier drives persistence and schedule generation. Adding wall-clock UI state logic there couples it to the view layer and makes the notifier non-deterministic by time. Keep it in `_HomeScreenState` or as a private top-level function in `home_screen.dart`.
- **Calling `DateTime.now()` directly in `build()`:** Always inject via `_nowFn` (a field on the state) so tests can override without mocking the global `DateTime.now`.
- **Checking `isCompleted || isSkipped` before finding the window:** The selection algorithm must first find the window (by clock time), then check resolution state of the window's chunk. Checking resolution first recreates the "first unresolved" bug.
- **Forgetting `WidgetsBinding.instance.removeObserver(this)` in `dispose()`:** Memory leak. The existing `BreathingPulseCta` shows the correct teardown (home_screen.dart line 426).
- **Timer without `mounted` guard:** Always check `if (mounted)` before `setState()` in the timer callback. `FocusScreen` line 60 and 68 show this pattern.
- **Using `DateTime.now().toUtc()`:** Use local time. `displayStartMinutes` is minutes from local midnight. `ThemeNotifier.modulateHsl` correctly uses `now.hour * 60 + now.minute` (local).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 1-minute tick | Custom event loop | `dart:async Timer.periodic` | Already in `ThemeNotifier` — same pattern, proven lifecycle |
| Lifecycle pause/resume | Manual flag + Timer restart | `WidgetsBindingObserver.didChangeAppLifecycleState` | Established pattern in `ScheduleNotifier` and `ThemeNotifier` |
| Time formatting | Custom `hh:mm AM/PM` formatter | `formatMinutes()` in `lib/utils/time_format.dart` | Already imported in home_screen.dart; tested implicitly |
| Goal name lookup | Direct Hive access | `_lookupGoalName(context, chunk)` in `_HomeScreenState` | Method already exists (line 282) |

**Key insight:** Every infrastructure piece needed for this phase already exists in the codebase. This phase is purely about wiring the existing pieces together with a new selection function.

---

## Common Pitfalls

### Pitfall 1: Local time vs. UTC
**What goes wrong:** `displayStartMinutes` is set as local minutes from midnight (e.g., `anchoredStartMinutes` from CommitmentBlock or `syntheticStartMinutes` from the generator using `now.hour * 60 + now.minute`). Using `DateTime.now().toUtc()` to compute `currentMinutes` would give wrong results in non-UTC timezones.
**Why it happens:** `DateTime.now()` is local; `.toUtc()` shifts the hour.
**How to avoid:** Compute `currentMinutes = now().hour * 60 + now().minute` from the LOCAL `DateTime`. This matches how `syntheticStartMinutes` is set in `schedule_generator.dart` (line: `startFloorMinutes: now.hour * 60 + now.minute`).
**Warning signs:** Tests pass at UTC+0 but fail in other timezone environments.

### Pitfall 2: setState-after-dispose in timer callback
**What goes wrong:** The timer fires after the widget is removed from the tree (e.g., user navigates away).
**Why it happens:** `Timer.periodic` callbacks run even after `dispose()` unless explicitly cancelled.
**How to avoid:** `if (mounted) setState(() {})` in every timer callback. Cancel in `dispose()`. See `FocusScreen` lines 60, 68, and `dispose()` at line 51.
**Warning signs:** Flutter debug mode prints "setState() called after dispose()".

### Pitfall 3: Chunks without `displayStartMinutes`
**What goes wrong:** Discretionary chunks generated before the `syntheticStartMinutes` feature was introduced may have `displayStartMinutes == null`. Including them in the clock-window sort causes a null-dereference.
**Why it happens:** `displayStartMinutes` is a nullable getter; only chunks with `anchoredStartMinutes` or `syntheticStartMinutes` have a clock time.
**How to avoid:** Filter to `c.displayStartMinutes != null` before the clock-window sort (as shown in the selection pseudo-code). Chunks excluded from the filter should NOT participate in "active" matching; they are treated as if they don't exist for time-anchoring purposes.
**Warning signs:** `Null check operator used on null value` crash when sorting.

### Pitfall 4: Forgetting `WidgetsBindingObserver` mixin on `_HomeScreenState`
**What goes wrong:** `WidgetsBinding.instance.addObserver(this)` compiles but the `didChangeAppLifecycleState` override is never called.
**Why it happens:** The mixin must be declared: `class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver`.
**How to avoid:** `_HomeScreenState` currently does NOT have this mixin — it must be added. Check `BreathingPulseCta` (line 372) or `ScheduleNotifier` (line 15) for the correct declaration.
**Warning signs:** Timer keeps running after the app is backgrounded (battery drain on mobile); no pause behavior in tests.

### Pitfall 5: "All done today!" text leaking into new tests
**What goes wrong:** Existing test `'shows "All done today!" when all chunks resolved'` passes a schedule where all chunks have `displayStartMinutes == null`. Under new logic, those chunks are excluded from the clock-window filter → `allWork.isEmpty` → `_DayComplete()` state → shows "That's a wrap" not "All done today!". The existing test breaks.
**Why it happens:** The old "all resolved" fallback showed "All done today!" regardless of time. The new logic replaces this with the day-complete state copy.
**How to avoid:** Update the existing test in `active_chunk_card_test.dart` (line 322) to expect "That's a wrap" (or the existing test can be repurposed to test the now-separate "no schedule" empty-state path). The plan must call this out as a required test migration.
**Warning signs:** `expect(find.text('All done today!'), findsOneWidget)` fails after implementation.

### Pitfall 6: `_resolveNowState` not receiving the injectable `now`
**What goes wrong:** If `_resolveNowState` calls `DateTime.now()` directly instead of accepting a `DateTime Function() now` parameter, widget tests cannot inject a fixed time and must use real wall-clock time — making tests order-dependent and fragile.
**Why it happens:** Easy to write `DateTime.now()` inline; the injectable pattern requires deliberate plumbing.
**How to avoid:** `_HomeScreenState` should store `DateTime Function() _nowFn = DateTime.now` as a field, passed to `_resolveNowState` on each call. In tests, override via a `_FakeScheduleNotifierWithSchedule` subclass or by passing the now function directly to a top-level `_resolveNowState` function.
**Warning signs:** Tests that pass at 9am fail at 6pm.

---

## Code Examples

Verified patterns from existing codebase:

### Existing chunk selection (LINES 104-111 of home_screen.dart — TO BE REPLACED)
```dart
// Source: lib/screens/home/home_screen.dart lines 104-111 [VERIFIED: codebase read]
final unresolvedWork = schedule.chunks
    .where(
      (c) =>
          c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped,
    )
    .toList();
final currentChunk = unresolvedWork.isNotEmpty ? unresolvedWork.first : null;
final nextChunk = unresolvedWork.length > 1 ? unresolvedWork[1] : null;
```

### displayStartMinutes getter (confirmed model)
```dart
// Source: lib/data/models/scheduled_chunk.dart lines 71-72 [VERIFIED: codebase read]
int? get displayStartMinutes => anchoredStartMinutes ?? syntheticStartMinutes;
```

### Timer.periodic lifecycle pattern (ThemeNotifier)
```dart
// Source: lib/providers/theme_notifier.dart lines 205-233 [VERIFIED: codebase read]
void _startTicker() {
  _ticker?.cancel();
  if (!_timeModulationEnabled || !_isForeground) return;
  _ticker = Timer.periodic(const Duration(minutes: 20), (_) {
    _resetIfDayChanged();
    notifyListeners();
  });
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  _isForeground = state == AppLifecycleState.resumed;
  if (_isForeground) {
    _resetIfDayChanged();
    _startTicker();
    notifyListeners();
  } else {
    _ticker?.cancel();
  }
}
```

### Existing "now null" inline text (PATTERN TO MIRROR for pre-start/day-complete)
```dart
// Source: lib/screens/home/home_screen.dart lines 150-159 [VERIFIED: codebase read]
if (currentChunk == null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      'All done today!',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  )
```

### Injectable `now` in ScheduleNotifier constructor (pattern to follow)
```dart
// Source: lib/providers/schedule_notifier.dart lines 24-34 [VERIFIED: codebase read]
ScheduleNotifier({
  DateTime Function() now = DateTime.now,
  DailyScheduleRepository? repo,
  ...
}) : _now = now, ...

final DateTime Function() _now;
```

### _pumpHomeScreen test helper (existing, to be extended)
```dart
// Source: test/screens/active_chunk_card_test.dart lines 105-136 [VERIFIED: codebase read]
Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required ScheduleNotifier scheduleNotifier,
}) async { ... }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| "First unresolved chunk" as Now | Clock-window `[start, end)` intersection | Phase 17 | At 6pm, correct chunk (or day-complete) shown rather than stale 8am chunk |
| "All done today!" when no current chunk | Pre-start / day-complete discriminated state | Phase 17 | UI distinguishes "hasn't started" from "finished" |
| No timer — Now only updates on user action | 1-minute `Timer.periodic` | Phase 17 | Now/Next advance passively as time passes |

**Deprecated/outdated by this phase:**
- `final unresolvedWork = ...` / `final currentChunk = ...` / `final nextChunk = ...` (lines 104-111): replaced by `_resolveNowState()`.
- `'All done today!'` text: replaced by "That's a wrap" in day-complete state and "Your day starts at [TIME]" in pre-start state.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `allWork.isEmpty` edge case (no work chunks with `displayStartMinutes`) should show day-complete (not fall back to "first unresolved"). | Architecture Patterns, Pitfall 3 | If falling back is desired, the planner must add a second code path; the UI-SPEC says "fall back to old behavior" but this research recommends day-complete as cleaner. Requires plan decision. |
| A2 | `_HomeScreenState` will store `DateTime Function() _nowFn = DateTime.now` as a field for injection in tests, rather than extracting `_resolveNowState` as a separate testable top-level function. | Architecture Patterns | If the planner prefers a top-level function (more testable), the function signature is `_NowState resolveNowState(List<ScheduledChunk>, DateTime Function())` — either approach works. |

---

## Open Questions

1. **Fallback for `displayStartMinutes == null` chunks**
   - What we know: UI-SPEC edge case table says "fall back to old 'first unresolved' behavior" when all work chunks have null start times.
   - What's unclear: This creates a code branch that must be maintained; the "old behavior" is the bug being fixed.
   - Recommendation: Show day-complete instead. Document as a known departure from UI-SPEC edge case language, since all chunks in recent schedules receive `syntheticStartMinutes` from the generator.

2. **`_nowFn` field on state vs. top-level function**
   - What we know: Both work. Top-level is more unit-testable (pure function tests without widget pump); field on state is simpler.
   - Recommendation: Extract as a top-level function `_NowState resolveNowState(List<ScheduledChunk>, DateTime Function())` so pure unit tests (no widget pump) can cover the algorithm. Widget tests exercise the integration.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is a pure code change to an existing Flutter widget. No new external tools, services, CLIs, databases, or runtimes required. The Flutter SDK is already installed at `/home/dan/development/flutter/bin`.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (built-in Flutter SDK) |
| Config file | none — `flutter test` discovers tests by convention |
| Quick run command | `flutter test test/screens/active_chunk_card_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOW-01 | Pre-start: 6am, first chunk at 8am → pre-start heading shown | widget | `flutter test test/screens/home_screen_now_state_test.dart` | ❌ Wave 0 |
| NOW-01 | Active: 9am, chunk 8:30–9:30 → ActiveChunkCard shown for that chunk | widget | same | ❌ Wave 0 |
| NOW-01 | Between-chunks: 10am, chunk1 8:30–9:30, chunk2 10:30–11:30 → overdue chunk1 shown as Now | widget | same | ❌ Wave 0 |
| NOW-01 | `_resolveNowState` unit: correct state returned for all 4 states | unit | `flutter test test/screens/home_screen_now_state_test.dart` | ❌ Wave 0 |
| NOW-02 | Day-complete (time-based): 6pm, all windows passed → "That's a wrap" shown | widget | same | ❌ Wave 0 |
| NOW-02 | Day-complete (all-resolved): all chunks isCompleted/isSkipped → "That's a wrap" | widget | same | ❌ Wave 0 |
| NOW-01 | Timer: after 1-minute tick, state transitions from pre-start to active | widget | same | ❌ Wave 0 |
| NOW-01/02 | Existing "All done today!" test updated to expect "That's a wrap" | widget | `flutter test test/screens/active_chunk_card_test.dart` | ✅ exists, needs update |
| NOW-01 | Next row hides in pre-start and day-complete states | widget | same | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/screens/active_chunk_card_test.dart test/screens/home_screen_now_state_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/screens/home_screen_now_state_test.dart` — all NOW-01 and NOW-02 new test scenarios
- [ ] Update `test/screens/active_chunk_card_test.dart` line 327: `find.text('All done today!')` → `find.text("That's a wrap")` (Pitfall 5)

*(Existing `active_chunk_card_test.dart` infrastructure — `_pumpHomeScreen`, fakes, `_FakeScheduleNotifierWithSchedule` — is reusable in the new test file with minimal duplication.)*

---

## Security Domain

This phase involves no authentication, sessions, access control, cryptography, or user-facing input fields. It is a pure UI state-display change to an existing local screen. Security domain: NOT APPLICABLE.

---

## Sources

### Primary (HIGH confidence)
- `lib/screens/home/home_screen.dart` — full file read; current chunk selection logic (lines 104-111), existing "All done today!" pattern (lines 150-159), `_lookupGoalName` (line 282)
- `lib/data/models/scheduled_chunk.dart` — confirmed `displayStartMinutes` getter, `durationMinutes`, `isCompleted`, `isSkipped`, `ChunkType`
- `lib/providers/theme_notifier.dart` — confirmed Timer.periodic lifecycle pattern, `WidgetsBindingObserver` mixin, pause/resume lifecycle
- `lib/providers/schedule_notifier.dart` — confirmed injectable `now` pattern (constructor parameter)
- `lib/screens/home/widgets/active_chunk_card.dart` — confirmed widget interface (takes `ScheduledChunk chunk`), no visual change needed
- `lib/screens/home/widgets/end_of_day_card.dart` — confirmed `shouldShowEodCard` is independent; both states can coexist
- `lib/utils/time_format.dart` — confirmed `formatMinutes(int minutes)` signature, already imported in home_screen.dart
- `test/screens/active_chunk_card_test.dart` — confirmed existing test patterns, fake classes, `_pumpHomeScreen` helper, test that will break (line 322)
- `test/test_helpers/mood_pump.dart` — confirmed `pumpWithMood` signature and `extraProviders` pattern
- `.planning/phases/17-time-anchored-home/17-UI-SPEC.md` — four-state model, copy contract, timer contract, component inventory

### Secondary (MEDIUM confidence)
- `lib/screens/focus/focus_screen.dart` — Timer.periodic in-widget pattern (alternative to ThemeNotifier's approach)
- `test/end_of_day_card_test.dart` — confirmed pattern for testing time-dependent logic via direct function calls

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; dart:async and flutter material are built-in
- Architecture: HIGH — all patterns verified from codebase reads; no external dependencies
- Pitfalls: HIGH — each pitfall is grounded in specific line numbers in existing code

**Research date:** 2026-06-13
**Valid until:** 2026-09-13 (stable — no external dependencies)
