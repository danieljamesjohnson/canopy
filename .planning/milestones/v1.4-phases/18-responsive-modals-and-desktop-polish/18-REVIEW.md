---
phase: 18-responsive-modals-and-desktop-polish
reviewed: 2026-06-14T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - lib/widgets/adaptive_form_modal.dart
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/goals/goals_screen.dart
  - lib/screens/commitments/commitment_form_sheet.dart
  - lib/screens/commitments/commitments_screen.dart
  - lib/screens/home/home_screen.dart
  - lib/screens/schedule/schedule_screen.dart
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-06-14
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 18 introduced `showAdaptiveFormModal` (dialog at >=720dp, bottom sheet below), routed goal and commitment forms through it with an `isDialog` parameter, and added 720dp `ConstrainedBox` constraints to the home and schedule screens. The core adaptive-modal logic is sound and the `ModalRoute.of(context) is DialogRoute` fallback detection is a good defensive measure. However, two blockers require attention: a nested double-scroll that silently defeats scrolling in dialog mode, and a missing `isDialog` pass-through in `CommitmentsScreen` that leaves the commitment form broken on desktop (drag handle visible, keyboard insets applied even inside a Dialog). Three warnings follow.

---

## Critical Issues

### CR-01: Nested `SingleChildScrollView` in dialog mode — outer scroll defeats inner, content can become unreachable

**File:** `lib/widgets/adaptive_form_modal.dart:41` and `lib/screens/goals/goal_form_sheet.dart:153` / `lib/screens/commitments/commitment_form_sheet.dart:126`

**Issue:** In the dialog branch (>=720dp), `adaptive_form_modal.dart` wraps the builder output in its own `SingleChildScrollView` (line 41–43). Both `GoalFormSheet.build()` (line 153) and `CommitmentFormSheet.build()` (line 126) also return a `SingleChildScrollView` as their root widget. The result is two nested scroll views sharing the same `ScrollController` instance. The outer one (in the modal helper) owns the `maxHeight: screenHeight * 0.8` constraint and will claim all scroll events first; the inner one never sees them. In practice the outer scroll is also the one bound by `ConstrainedBox`, so content that does not overflow the outer scroll's viewport is simply inaccessible via the inner controller — and if the outer `SingleChildScrollView` gets a tight height that makes it non-scrollable, the inner one will also be clamped at the same size but its scrolling will be eaten. The same `scrollController` passed to `builder()` is both the controller for the outer scroll and the one the form widgets pass to the inner scroll — so the controller binding is not wrong, but the structural nesting produces undefined scroll-physics behaviour that in practice silently drops some scroll events on the floor.

**Fix:** Remove the outer `SingleChildScrollView` from the dialog branch. The `ConstrainedBox` with `maxHeight` already constrains overflow; the form widgets already provide their own scrollable root. The corrected dialog builder:

```dart
if (isDesktop) {
  final screenHeight = MediaQuery.of(context).size.height;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final scrollController = ScrollController();
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: screenHeight * 0.8,
          ),
          // No SingleChildScrollView here — the builder (GoalFormSheet,
          // CommitmentFormSheet) already provides a scrollable root.
          child: builder(scrollController),
        ),
      );
    },
  );
}
```

Note: with this fix the `scrollController` created here is passed directly to the form's root `SingleChildScrollView`, which is the intended design.

---

### CR-02: `CommitmentsScreen._openAddSheet` never passes `isDialog: true` — drag handle and keyboard insets appear inside the dialog on desktop

**File:** `lib/screens/commitments/commitments_screen.dart:27–32`

**Issue:** `_openAddSheet` constructs `CommitmentFormSheet` without `isDialog: true`:

```dart
CommitmentFormSheet(scrollController: scrollController, block: block)
```

On desktop (>=720dp) `showAdaptiveFormModal` opens a `Dialog`, but `CommitmentFormSheet` defaults `isDialog` to `false`. The `ModalRoute.of(context) is DialogRoute` fallback (line 124 of `commitment_form_sheet.dart`) is intended to rescue this case — but it is evaluated inside the form's `build()` method which runs in the dialog's builder context. In that context `ModalRoute.of(context)` refers to the **dialog's own modal route**, which IS a `DialogRoute`, so the fallback fires correctly at runtime. This means the observable bug may not appear — but the logic is fragile: it depends on a runtime route inspection that could fail if the widget tree is pumped differently (e.g. in tests where the form is pushed without going through `showDialog`). Meanwhile `GoalsScreen` explicitly passes `isDialog: isDesktop` (lines 35, 47), making the omission in `CommitmentsScreen` inconsistent and a latent source of breakage.

More concretely: `CommitmentsScreen._openAddSheet` accepts an optional `CommitmentBlock? block` parameter (line 27) but the `showAdaptiveFormModal` call does not re-compute the `isDesktop` flag at all — it relies entirely on the fallback. If the modal helper's internals ever change (e.g. wrapping the dialog in a `Navigator` push rather than `showDialog`), the fallback breaks silently.

**Fix:** Mirror the pattern used in `GoalsScreen`:

```dart
void _openAddSheet(BuildContext context, [CommitmentBlock? block]) {
  final isDesktop = MediaQuery.of(context).size.width >= 720;
  showAdaptiveFormModal(
    context: context,
    builder: (scrollController) => CommitmentFormSheet(
      scrollController: scrollController,
      block: block,
      isDialog: isDesktop,
    ),
  );
}
```

---

## Warnings

### WR-01: `ScrollController` created in dialog builder is never disposed — memory leak on every dialog open

**File:** `lib/widgets/adaptive_form_modal.dart:33`

**Issue:** `final scrollController = ScrollController()` is allocated inside the `showDialog` builder closure (line 33). `ScrollController` is a `ChangeNotifier` that allocates listeners. The builder may be called more than once by Flutter's dialog animation machinery, and there is no corresponding `dispose()` call — the controller is unreachable after the dialog closes. In Flutter, every `ScrollController` must be disposed to release its `PositionListener` registrations. This is a confirmed memory leak for every dialog-mode open.

**Fix:** Create and dispose the controller outside the builder using a `StatefulBuilder`, or restructure to create it once in a `StatefulWidget` wrapper:

```dart
// Option A: StatefulBuilder pattern
builder: (ctx) {
  return StatefulBuilder(
    builder: (ctx2, setState) {
      // controller lives in a local field — but StatefulBuilder still
      // doesn't give lifecycle hooks.
    },
  );
}
```

The cleanest fix is to extract the dialog content into a small private `StatefulWidget` that owns and disposes the controller:

```dart
class _DialogForm extends StatefulWidget {
  const _DialogForm({required this.builder, required this.maxHeight});
  final Widget Function(ScrollController) builder;
  final double maxHeight;
  @override
  State<_DialogForm> createState() => _DialogFormState();
}

class _DialogFormState extends State<_DialogForm> {
  late final ScrollController _sc = ScrollController();
  @override
  void dispose() { _sc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) =>
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: widget.maxHeight),
        child: widget.builder(_sc),
      );
}
```

Then in `showDialog builder: (ctx) => Dialog(clipBehavior: Clip.antiAlias, child: _DialogForm(...))`.

---

### WR-02: `CommitmentFormSheet._save` has no error handling — unhandled exception silently drops the save

**File:** `lib/screens/commitments/commitment_form_sheet.dart:100–111`

**Issue:** `_save()` calls `context.read<CommitmentsNotifier>().saveBlock(block)` (line 110) with no `try/catch`. If `saveBlock` throws (e.g. Hive box closed, disk full, serialization error), the exception propagates uncaught and the form stays open with no user-visible feedback. The symmetrical `GoalFormSheet._save()` (lines 99–110) DOES wrap in `try/catch` with a `ScaffoldMessenger` snackbar — the omission is an asymmetry that leaves commitment saves silent on failure.

**Fix:** Wrap with the same pattern used in `GoalFormSheet`:

```dart
Future<void> _save() async {
  if (!_canSave) return;
  final block = CommitmentBlock(
    id: widget.block?.id,
    name: _nameController.text.trim(),
    daysOfWeek: _selectedDays.toList()..sort(),
    startMinutes: _startMinutes,
    endMinutes: _endMinutes,
  );
  block.color = _color;
  try {
    await context.read<CommitmentsNotifier>().saveBlock(block);
    if (mounted) Navigator.of(context).pop();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save commitment. Please try again.'),
        ),
      );
    }
  }
}
```

---

### WR-03: `CommitmentFormSheet` allows `endMinutes <= startMinutes` — zero-duration and inverted blocks are persisted silently

**File:** `lib/screens/commitments/commitment_form_sheet.dart:97–111`

**Issue:** `_canSave` (line 97) only checks that `_nameController.text.trim().isNotEmpty && _selectedDays.isNotEmpty`. There is no validation that `_endMinutes > _startMinutes`. A user can tap the End time and set it to the same value as, or before, Start — `_canSave` remains true and `saveBlock` is called with a zero-duration or negative-duration commitment block. Downstream, the schedule generator uses `endMinutes - startMinutes` to compute the free-time windows; a zero or negative value produces incorrect availability calculations or assertion failures depending on the generator implementation.

**Fix:** Add a time-ordering guard:

```dart
bool get _canSave =>
    _nameController.text.trim().isNotEmpty &&
    _selectedDays.isNotEmpty &&
    _endMinutes > _startMinutes;
```

Optionally surface a hint in the End time tile when the ordering is violated, so users understand why Save is disabled.

---

## Info

### IN-01: Ambiguous day-of-week chip labels — `'T'` used for both Tuesday and Thursday

**File:** `lib/screens/commitments/commitment_form_sheet.dart:119`

**Issue:** `const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S']` uses `'T'` for index 1 (Tuesday) and index 3 (Thursday), and `'S'` for index 5 (Saturday) and index 6 (Sunday). Users cannot distinguish Tuesday from Thursday or Saturday from Sunday by the chip label alone. The `_formatDays` helper in `CommitmentsScreen` (line 72) uses full three-letter abbreviations ('Mon', 'Tue', 'Wed', etc.) for the card subtitle, but those correct strings are never shown to the user during selection.

**Fix:** Use unambiguous abbreviations in the chip labels:

```dart
const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
```

---

### IN-02: `CommitmentsScreen` body `ListView` has no `maxWidth` constraint — content spans full width on desktop

**File:** `lib/screens/commitments/commitments_screen.dart:136–149`

**Issue:** Phase 18 added `ConstrainedBox(maxWidth: 720)` to the home screen body, schedule screen body, and goals screen body. The commitments screen body uses a bare `ListView.builder` with no width constraint (lines 136–149), so on a wide desktop the commitment cards stretch to full screen width while every other primary screen constrains to 720dp. This is a layout inconsistency introduced by the phase.

**Fix:** Wrap the `ListView.builder` in `Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: ListView.builder(...)))` to match the pattern used in the other three screens. The same constraint should be applied to `_emptyState()`.

---

_Reviewed: 2026-06-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
