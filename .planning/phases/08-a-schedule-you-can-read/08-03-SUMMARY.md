---
phase: 08-a-schedule-you-can-read
plan: "03"
subsystem: focus-mode
tags: [focus-screen, timer, go-router, read-04, wave-0-green]
dependency_graph:
  requires:
    - ChunkDetailSheet "Start focus" button (08-02, context.push('/focus', extra: chunk.id))
    - ScheduleNotifier.markComplete (Phase 4)
    - GoalsNotifier.goals (Phase 2)
    - isDeferred HiveField(8) on ScheduledChunk (08-01)
  provides:
    - FocusScreen StatefulWidget with Timer.periodic 25-min countdown (READ-04)
    - /focus GoRoute outside StatefulShell with guarded String-extra cast
    - ScheduleScreen AppBar IconButton 'Start focus' focus entry affordance
  affects:
    - lib/screens/focus/focus_screen.dart (new)
    - lib/router.dart
    - lib/screens/schedule/schedule_screen.dart
    - test/screens/focus_screen_test.dart (GREEN)
tech_stack:
  added: []
  patterns:
    - Timer.periodic(Duration(seconds:1)) in StatefulWidget for 1s countdown clock
    - _timer?.cancel() in dispose() prevents setState-after-dispose (T-08-06)
    - GoRoute extra-cast guard (state.extra is! String → harmless Scaffold fallback, T-08-05)
    - context.push('/focus', extra: chunkId) preserves back stack vs context.go
    - ScheduleNotifier/GoalsNotifier accessed via context.watch/context.read in screen
key_files:
  created:
    - lib/screens/focus/focus_screen.dart
  modified:
    - lib/router.dart
    - lib/screens/schedule/schedule_screen.dart
    - test/screens/focus_screen_test.dart
decisions:
  - Timer.periodic in StatefulWidget (not ChangeNotifier) — screen-local state only; notifier timer would cause 1500 notifyListeners() calls per session
  - context.push('/focus', extra: chunkId) used at both entry points — preserves back stack; context.go would replace stack
  - state.extra is! String guard before cast — T-08-05 mitigation; malformed extra returns harmless Scaffold not crash
  - _markedComplete flag prevents double-calling markComplete if user taps the button twice
  - GoalsNotifier.goals accessed via context.read (not watch) for goal name/color lookup — goal data is stable; no reactive rebuild needed
metrics:
  duration: "~3 minutes"
  completed_date: "2026-06-11"
  tasks: 2
  files: 4
---

# Phase 8 Plan 03: A Schedule You Can Read — Focus Mode Summary

`/focus` full-screen route with 25-min `Timer.periodic` countdown, goal name highlight, `markComplete`-on-finish, and a break suggestion derived from the next chunk. Both entry points (detail-sheet "Start focus" + schedule AppBar `IconButton`) wire to the route. Wave 0 focus stub turned GREEN.

---

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | READ-04: FocusScreen StatefulWidget with timer, break suggestion, dispose cancel | e076d5a |
| 2 | /focus GoRoute (guarded) + schedule-screen focus entry affordance | 8b08486 |

---

## What Was Built

### Task 1: FocusScreen with countdown timer, completion + break suggestion (READ-04)

**`lib/screens/focus/focus_screen.dart`** — new `StatefulWidget`:

- **Timer states** (per UI-SPEC Surface 4 table):
  - Not started (1500s remaining): shows `'25:00'` in `displaySmall/w300` circular progress ring + `FilledButton('Start 25 min timer')` + `TextButton('Skip timer')`
  - Running: counts down MM:SS each second; `FilledButton('Pause')` + `OutlinedButton('Done early')`
  - Paused (`_secondsRemaining < 1500` and `!_isRunning`): frozen MM:SS; `FilledButton('Resume')` + `OutlinedButton('Done early')`
  - Finished / Done early / Skip timer: timer area hidden; break suggestion + `FilledButton('Mark complete')` + `TextButton('Back to schedule')`

- **Layout**: transparent AppBar with `BackButton`, 4dp full-width goal color bar, `primaryContainer` card with goal name (`titleMedium/w600`) + rationale, `CircularProgressIndicator(value: _secondsRemaining/1500)` ring, button row.

- **Break suggestion**: derived from next chunk — `shortBreak` → `'Nice work. Take a 5 min break.'`; `longBreak` → `'Great focus block. Take a 25 min break.'`; none → `"You're done for now."`

- **Dispose safety**: `_timer?.cancel()` before `super.dispose()` (Pitfall 1 / T-08-06 mitigation). `if (mounted)` guard in timer callback prevents setState-after-dispose if user pops before cancel.

- **Early-resolve guard**: if the received `chunkId` belongs to an already-completed/skipped chunk, `WidgetsBinding.addPostFrameCallback` pops immediately without rendering.

- **`_markedComplete` flag**: prevents double-calling `ScheduleNotifier.markComplete` if the button is tapped multiple times.

**`test/screens/focus_screen_test.dart`** — Wave 0 stub replaced with real import:
- Added `_FakeScheduleNotifier` and `_FakeGoalsNotifier` test doubles passed via `extraProviders` to `pumpWithMood` — avoids Hive bootstrap in widget tests.
- Both tests GREEN: timer label/button visible on first render; no setState-after-dispose exception on dispose.

### Task 2: Register /focus route (guarded) + schedule-screen focus entry affordance

**`lib/router.dart`**:
- Import added: `screens/focus/focus_screen.dart`
- `/focus` `GoRoute` added outside `StatefulShellRoute` (after `/summary` block, same outside-shell pattern)
- Builder guards the extra cast: `if (state.extra is! String) return const Scaffold(body: SizedBox.shrink())` (T-08-05 mitigation / ASVS V5)
- Existing `router_redirect_test.dart` — 5/5 tests still GREEN

**`lib/screens/schedule/schedule_screen.dart`**:
- `IconButton(Icons.center_focus_strong_outlined, tooltip: 'Start focus')` added to `AppBar.actions`
- Finds first unresolved work chunk (`chunkType == ChunkType.work && !isCompleted && !isSkipped`) via `.where().firstOrNull`
- Calls `context.push('/focus', extra: firstChunk.id)` when a chunk exists; no-op when all work is resolved

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None. All production code is wired end-to-end. Auto-advance to next chunk (Phase 10) and the closed focus loop remain deferred per CONTEXT.md.

---

## Threat Surface Scan

Both plan threat model mitigations applied:

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-08-05 | `state.extra is! String` guard in `/focus` route builder — returns harmless Scaffold instead of unsafe cast crash |
| T-08-06 | `_timer?.cancel()` in `dispose()` + `if (mounted)` guard in Timer callback |

No new security-relevant surface introduced beyond the plan's threat model.

---

## Self-Check: PASSED

### Files exist:
- `lib/screens/focus/focus_screen.dart` ✓
- `lib/router.dart` (contains `/focus` and `FocusScreen`) ✓
- `lib/screens/schedule/schedule_screen.dart` (contains `context.push('/focus'`) ✓

### Commits exist:
- e076d5a (Task 1) ✓
- 8b08486 (Task 2) ✓

### Test results:
- `flutter test test/screens/focus_screen_test.dart` → 2 passed (GREEN) ✓
- `flutter test test/screens/router_redirect_test.dart` → 5 passed (GREEN) ✓
- `flutter test` (full suite) → 102 passed (GREEN) ✓
- `flutter analyze` → 0 new errors (5 pre-existing onReorder deprecation warnings in unrelated files, carried forward from 08-02) ✓
