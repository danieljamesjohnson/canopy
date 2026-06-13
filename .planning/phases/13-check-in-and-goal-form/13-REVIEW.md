---
phase: 13-check-in-and-goal-form
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/screens/schedule/checkin_screen.dart
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/goals/widgets/goal_type_picker.dart
  - test/screens/checkin_screen_test.dart
  - test/screens/checkin_screen_widget_test.dart
  - test/widgets/goal_type_picker_test.dart
findings:
  critical: 2
  warning: 3
  info: 1
  total: 6
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the luminance-adaptive foreground color + emoji hover/pressed state changes in
`checkin_screen.dart`, the compacted `GoalTypePicker` cards in `goal_type_picker.dart`,
the reduced spacers in `goal_form_sheet.dart`, and the corresponding test files. The
GoalTypePicker and GoalFormSheet changes are sound. The check-in screen contains one
WCAG regression (hardcoded `Colors.white` in the acknowledgment body that the PR's own
luminance logic was written to fix) and one unhandled-error path in the decision screen
that silently drops exceptions from `generateToday`. Two additional warnings cover
hover/pressed state leak scenarios and test-pump fragility.

---

## Critical Issues

### CR-01: Hardcoded `Colors.white` in acknowledgment body regresses the WCAG fix

**File:** `lib/screens/schedule/checkin_screen.dart:423-435`

**Issue:** `_buildAcknowledgmentBody` uses `Colors.white` on both the `ackText` label
(line 423) and the "Swipe up to begin" hint (line 434). The background color for the
acknowledgment body is `ThemeNotifier.moodSeeds[mood]!` (line 389), which for mood 5
(amber `#E8C547`, luminance ≈ 0.55) gives white text a ~1.9:1 contrast ratio — a hard
WCAG AA fail. This is the exact failure CHECKIN-01 was designed to fix, and the fix is
fully applied in `_buildDecisionBody` (which uses `_onBgColor`), but the acknowledgment
body was not updated. `_onBgColor` already exists and handles all five moods correctly.
The PR comment on line 60-74 of `checkin_screen.dart` explicitly calls out moods 4 and
5 as requiring dark text, yet the final state of the screen — the one the user sees after
committing — still shows white text on amber.

**Fix:**

```dart
// In _buildAcknowledgmentBody, replace the hardcoded Colors.white references
// with _onBgColor. The getter is already correct and depends only on _selectedMood,
// which is guaranteed non-null when _scheduleGenerated is true.

Text(
  ackText,
  textAlign: TextAlign.center,
  style: TextStyle(           // remove 'const'
    color: _onBgColor,        // was: Colors.white
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.4,
  ),
),
const SizedBox(height: 48),
Text(
  'Swipe up to begin',
  style: TextStyle(
    color: _onBgColor.withAlpha(179),   // was: Colors.white.withAlpha(179)
    fontSize: 14,
    letterSpacing: 1.2,
  ),
),
```

Additionally, the `bgColor` local variable at line 389 is computed independently from
`_backgroundColor` (the getter). They will agree in practice because `_selectedMood` is
set before `_scheduleGenerated` becomes `true`, but it is cleaner to use the getter
directly:

```dart
final bgColor = _backgroundColor; // use the existing getter
```

---

### CR-02: `_commitAndProceed` has no error handling — exceptions are silently dropped

**File:** `lib/screens/schedule/checkin_screen.dart:125-139`

**Issue:** `_commitAndProceed` calls `await context.read<ScheduleNotifier>().generateToday(...)` when `lighterDay: true`, but has no try/catch. Callers pass `_commitAndProceed` as a `VoidCallback` via the lambda `() => _commitAndProceed(lighterDay: true)` (line 366). Because the returned `Future` is silently dropped, any exception thrown by `generateToday` (e.g. a Hive I/O error) flows into the Flutter zone error handler unhandled. In release builds this is invisible to the user. The "Lighter day" card tap effectively disappears: the spinner never appears (there is no `_isGenerating`-equivalent guard in `_commitAndProceed`), the decision screen stays up, and the user has no idea the save failed.

By contrast, `_generate()` correctly wraps `generateToday` in try/catch and shows a `SnackBar`.

**Fix:**

```dart
Future<void> _commitAndProceed({required bool lighterDay}) async {
  try {
    if (lighterDay) {
      await context.read<ScheduleNotifier>().generateToday(
        moodIndex: _selectedMood!,
        goals: context.read<GoalsNotifier>().goals,
        blocks: context.read<CommitmentsNotifier>().blocks,
        lighterDay: true,
      );
    }
    if (mounted) {
      setState(() => _scheduleGenerated = true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }
}
```

---

## Warnings

### WR-01: Emoji pressed state can leak `true` when the mood button triggers navigation

**File:** `lib/screens/schedule/checkin_screen.dart:252-257`

**Issue:** The emoji `GestureDetector` sets `_pressedMoods[mood] = true` in `onTapDown`
(line 252) and resets it in `onTapUp` (line 254) or `onTapCancel` (line 256). However,
the `onTap` handler (line 241) calls `context.read<ThemeNotifier>().setMoodSeed(...)`.
`setMoodSeed` is async and triggers `notifyListeners()`, which may cause the widget tree
to rebuild. The rebuild is synchronous (frame scheduling), so `onTapUp` fires first and
the reset happens before the rebuild — this is normally fine.

The leak occurs in a specific scenario: the user rapidly taps "Let's go" while still
holding down an emoji button. If `onTapDown` fires on the emoji, then `onTap` fires on
"Let's go" (starting `_generate`), and the widget transitions via AnimatedSwitcher before
the emoji's `onTapUp`/`onTapCancel` can fire, `_pressedMoods[mood]` remains `true` for
the lifetime of the `_CheckinScreenState` instance. If the user navigates back and the
same state instance is reused (e.g. via Navigator's back-then-forward), the emoji will
render with a stale pressed background.

**Fix:** Clear `_pressedMoods` when transitioning out of the check-in body:

```dart
setState(() {
  _isGenerating = true;
  _pressedMoods.clear(); // clear any stale pressed state before transition
});
```

Add this clear to `_generate()` at line 94.

---

### WR-02: `_commitAndProceed(lighterDay: true)` reads `context` inside async gap without a pre-check

**File:** `lib/screens/schedule/checkin_screen.dart:129-134`

**Issue:** The `context.read<GoalsNotifier>().goals` and `context.read<CommitmentsNotifier>().blocks`
calls at lines 131-132 are evaluated synchronously as arguments before the `await`, so
they are safe. However, the `context.read<ScheduleNotifier>()` on line 129 is also
evaluated before the `await` — the notifier reference is captured first, then the method
is called asynchronously. This is technically correct but relies on a subtle evaluation
order. If the code is ever refactored to move the argument evaluation after the `await`
(a common refactor mistake), it will introduce a use-after-dispose context bug. Consider
capturing the needed values before the `await` explicitly:

```dart
Future<void> _commitAndProceed({required bool lighterDay}) async {
  if (lighterDay) {
    final scheduleNotifier = context.read<ScheduleNotifier>();
    final goals = context.read<GoalsNotifier>().goals;
    final blocks = context.read<CommitmentsNotifier>().blocks;
    await scheduleNotifier.generateToday(
      moodIndex: _selectedMood!,
      goals: goals,
      blocks: blocks,
      lighterDay: true,
    );
  }
  if (mounted) {
    setState(() => _scheduleGenerated = true);
  }
}
```

This makes the intent explicit and protects against future accidental context-after-await
bugs.

---

### WR-03: Test pump sequence insufficient for two-await `_generate()` in widget test

**File:** `test/screens/checkin_screen_widget_test.dart:174-177`

**Issue:** `_tapMoodAndGenerate` uses two sequential `pump()` calls to drain the async
work in `_generate()`. However, `_generate()` contains two `await` points:
1. `await context.read<ScheduleNotifier>().generateToday(...)`
2. `await NotificationService.requestIOSPermissions()`

Each `await` of a `Future` that completes asynchronously requires its own microtask
drain. Two `pump()` calls drain two microtask queues, but the `Future` chain inside
`_FakeScheduleNotifier.generateToday` may itself schedule multiple microtasks (Dart
`async` methods schedule at least one microtask for the implicit `await` wrapping).
`pumpAndSettle` at the end saves this for the AnimatedSwitcher, but if either `Future`
takes more than two microtask turns the test will observe the widget still in the
generating state and find `'Ready to start?'` not present.

In the current `_FakeScheduleNotifier`, `generateToday` completes synchronously (no
`await` inside), so two pumps happen to be enough. But if the fake is ever updated to
add a realistic async delay, all four tests in this file will silently fail in confusing
ways.

**Fix:** Replace the two sequential `pump()` calls with `pumpAndSettle` or use
`tester.pump(Duration.zero)` inside a loop that checks for the expected widget, or at
minimum document the fragility:

```dart
await tester.tap(find.text("Let's go"));
// Use pumpAndSettle to drain all async work from _generate() regardless
// of how many microtask turns the fake or real notifier takes.
await tester.pumpAndSettle();
```

If `pumpAndSettle` has issues with the 300ms AnimatedSwitcher timer, use a bounded pump:

```dart
await tester.tap(find.text("Let's go"));
await tester.pump(); // start the async
await tester.pump(const Duration(milliseconds: 500)); // drain + animate
```

---

## Info

### IN-01: `GoalsNotifier` and `CommitmentsNotifier` missing from `addTearDown` in widget test

**File:** `test/screens/checkin_screen_widget_test.dart:141-144`

**Issue:** `_pumpCheckin` disposes `scheduleNotifier` and `themeNotifier` in `addTearDown`
but does not dispose `goalsNotifier` or `commitmentsNotifier`. These `ChangeNotifier`
subclasses have no registered external listeners or timers in their current implementation,
so the omission causes no test failure today. However if either notifier gains a timer
or external subscription in a future phase, the missing teardowns will cause resource
leaks between test runs and potentially test ordering interference.

**Fix:**

```dart
addTearDown(() {
  scheduleNotifier.dispose();
  themeNotifier.dispose();
  goalsNotifier.dispose();       // add
  commitmentsNotifier.dispose(); // add
});
```

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
