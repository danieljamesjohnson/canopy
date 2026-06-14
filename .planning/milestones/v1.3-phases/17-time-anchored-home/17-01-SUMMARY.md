---
phase: 17-time-anchored-home
plan: "01"
subsystem: home-screen
tags: [time-anchoring, now-state, timer, lifecycle, tdd]
dependency_graph:
  requires: []
  provides: [resolveNowState, NowState, HomeScreen-now-injection, 1-min-timer]
  affects: [lib/screens/home/home_screen.dart, test/screens/home_screen_now_state_test.dart, test/screens/active_chunk_card_test.dart]
tech_stack:
  added: [dart:async Timer.periodic, WidgetsBindingObserver]
  patterns: [sealed-class-discriminated-result, injectable-clock-now-fn, timer-lifecycle-pause-resume]
key_files:
  created:
    - test/screens/home_screen_now_state_test.dart
  modified:
    - lib/screens/home/home_screen.dart
    - test/screens/active_chunk_card_test.dart
decisions:
  - "NowState variants and resolveNowState are top-level PUBLIC (no leading underscore) to enable pure unit tests without widget pump"
  - "All-null displayStartMinutes degenerate case returns DayComplete (not first-unresolved fallback) — documented departure from UI-SPEC"
  - "Overdue subtext 'Started [TIME]' not implemented — UI-SPEC marks it optional (Claude's discretion); omitted to keep card layout clean"
  - "_buildNowContent() extracted as a method (not inline switch expression) due to Dart parser restriction on switch expressions in widget children list literals"
metrics:
  duration_minutes: 7
  completed: "2026-06-14"
  tasks_completed: 3
  files_changed: 3
---

# Phase 17 Plan 01: Time-Anchored Home Now State — Summary

**One-liner:** Time-anchored NowState sealed hierarchy with `resolveNowState` pure function, 1-min timer, and pre-start/day-complete inline states replacing the stale "first unresolved chunk" selection.

## What Was Built

Home's "Now" zone now tells the truth about where the user is in their day. The old two-liner that selected the first unresolved work chunk (at 6pm showing the 8am chunk as "Now") is replaced with a proper clock-window state machine:

### `NowState` sealed hierarchy + `resolveNowState` (top-level, `home_screen.dart`)

Four public discriminated states:
- `PreStart(ScheduledChunk firstChunk)` — before the first chunk's window
- `Active(ScheduledChunk current, ScheduledChunk? next)` — inside a chunk window
- `Overdue(ScheduledChunk overdue, ScheduledChunk? next)` — past a window end, chunk unresolved
- `DayComplete()` — past the last window, or all resolved, or no timed chunks

`resolveNowState({required chunks, required now})` is a pure top-level function with injectable clock, exercisable in unit tests without a widget pump.

### 1-minute Timer + WidgetsBindingObserver lifecycle (`_HomeScreenState`)

- `Timer.periodic(1 min)` started in `initState`, cancelled in `dispose`
- `mounted` guard in the timer callback prevents setState-after-dispose (T-17-01)
- `didChangeAppLifecycleState`: cancel on `paused`, restart on `resumed` (no battery drain)
- `WidgetsBinding.instance.addObserver(this)` / `removeObserver(this)` in initState/dispose

### Pre-start and day-complete inline states (`_buildPreStartContent`, `_buildDayCompleteContent`)

- Pre-start: "Your day starts at [TIME]" heading + "[GOAL] · [DUR] min" body
- Day-complete: "That's a wrap" heading + "You've reached the end of today's schedule." body
- Both use `titleMedium w600` + `bodyMedium onSurfaceVariant` — no accent color, no emoji
- Next section hidden in both states (no active anchor)

### Migrated tests in `active_chunk_card_test.dart`

- "All done today!" assertion replaced with "That's a wrap" (NOW-02, line 337)
- NAV-02 chunks in `_scheduleWithTwoChunks()` given `syntheticStartMinutes` (540/600 min)
- `_pumpHomeScreen` accepts optional `now` parameter forwarded to `HomeScreen(now:)`
- All NAV-02 layout tests inject `() => DateTime(2026, 6, 13, 9, 5)` to ensure Active state

### New test file `test/screens/home_screen_now_state_test.dart`

7 pure unit tests (no widget pump):
1. pre-start: 6am, chunk at 480 min → `isA<PreStart>`, firstChunk.displayStartMinutes == 480
2. active: 9am, chunk 510–570 → `isA<Active>`, current.displayStartMinutes == 510
3. overdue: 10am, c1 510–570, c2 630–690 → `isA<Overdue>`, overdue.id == 'c1', next.id == 'c2'
4. day-complete (time-based): 6pm, chunk 480–540 → `isA<DayComplete>`
5. day-complete (all-resolved): c1 completed + c2 skipped, now inside window → `isA<DayComplete>`
6. active advances past resolved: c1 completed, c2 unresolved, now in c1 window → `isA<Active>`, current.id == 'c2'
7. degenerate all-null: no displayStartMinutes → `isA<DayComplete>` (documented departure)

6 widget tests (`HomeScreen(now: ...)` seam):
1. pre-start at 6am → finds "Your day starts at"; no ActiveChunkCard
2. active at 9am → finds ActiveChunkCard; no pre-start or day-complete text
3. between-chunks at 10am → ActiveChunkCard (c1 overdue) + "Next" label
4. day-complete at 6pm → "That's a wrap"; no ActiveChunkCard
5. all-resolved → "That's a wrap"; no ActiveChunkCard
6. timer/lifecycle: pump at 7:59, advance clock to 8:01, pump(1 min) → transitions to ActiveChunkCard; background/resume cycle does not throw

## Deliberate Departures

### 1. All-null `displayStartMinutes` degenerate case → `DayComplete` (not "first unresolved")

**17-RESEARCH.md Open Question 1 (RESOLVED):** When all work chunks have `displayStartMinutes == null` (after the null filter, `allWork.isEmpty`), `resolveNowState` returns `DayComplete()` rather than re-introducing the old "first unresolved" fallback that this phase exists to remove. This case is effectively unreachable in practice — the generator always assigns `syntheticStartMinutes`. Documented inline in the `DayComplete` class doc.

### 2. Overdue "Started [TIME]" subtext not implemented

The UI-SPEC marks this as "Claude's discretion." It was omitted to keep the card layout clean — the overdue chunk still shows its own clock-time range on the `ActiveChunkCard`, which communicates the same information. This can be added in a future phase if user research shows a need.

### 3. `_buildNowContent()` extracted as a method (not inline switch expression)

Dart's parser raised "unexpected token 'case'" errors when a switch expression (using `=>` arrow syntax) was placed directly inside a `children: [...]` list literal in a widget tree. Extracting the switch to a private method `_buildNowContent(context, nowState)` resolves the parse issue while producing identical behavior. The method returns the correct `Widget` for each sealed class variant.

## Implementation Notes

### `now`-injection seam

`HomeScreen({super.key, this.now})` accepts an optional `DateTime Function()? now`. In `_HomeScreenState`:

```dart
late final DateTime Function() _nowFn = widget.now ?? DateTime.now;
```

This defaults to `DateTime.now` at runtime and is overridden in tests via `HomeScreen(now: () => DateTime(2026, 6, 13, 9, 0))`.

### `NowState` visibility

`NowState`, `PreStart`, `Active`, `Overdue`, `DayComplete`, and `resolveNowState` are all top-level PUBLIC symbols (no leading underscore). This is a deliberate design choice to enable pure unit tests (`expect(state, isA<PreStart>())`). They are conceptually internal to the Home Now zone — not part of any public API surface intended for use outside `home_screen.dart`.

### Key invariant enforced

`resolveNowState` finds the clock window FIRST (by `displayStartMinutes` time comparison), then checks resolution. This prevents re-creating the "first unresolved" bug: `Active.current` is the chunk for the current time, even if a prior chunk is still unresolved.

## Test Results

- Full suite: 239 tests, all passed
- `flutter analyze lib/screens/home/home_screen.dart`: no issues found
- Spot checks:
  - `resolveNowState` in definition AND in build(): confirmed
  - `Timer.periodic`: confirmed
  - `"That's a wrap"`: confirmed in production code
  - `"All done today"` count: 0 in home_screen.dart, 0 in active_chunk_card_test.dart

## Deviations from Plan

None — plan executed exactly as written, with two minor implementation notes documented above (switch extraction, overdue subtext omission both noted as intentional in the plan itself).

## TDD Gate Compliance

- Task 1 (`test(17-01)` RED gate): Both test files written; compilation failed on missing `HomeScreen(now:)` seam and `resolveNowState` symbols — confirmed RED state.
- Task 2 (`feat(17-01)` GREEN gate for unit tests): `resolveNowState` + `NowState` hierarchy + `HomeScreen(now:)` seam landed; 7 unit tests GREEN; widget tests still failing (timer not wired).
- Task 3 (`feat(17-01)` GREEN gate for widget tests): Timer, lifecycle, `build()` switch wired; all 27 target-file tests GREEN.

## Self-Check: PASSED

Files exist:
- `lib/screens/home/home_screen.dart` — FOUND
- `test/screens/home_screen_now_state_test.dart` — FOUND
- `test/screens/active_chunk_card_test.dart` — FOUND (migrated)

Commits exist:
- d8c4841 (test RED) — FOUND
- 316fc3b (feat NowState + resolveNowState) — FOUND
- 5ca7964 (feat timer + wiring) — FOUND
