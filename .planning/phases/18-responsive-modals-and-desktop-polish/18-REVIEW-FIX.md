---
phase: 18-responsive-modals-and-desktop-polish
fixed_at: 2026-06-15T01:34:28Z
review_path: .planning/phases/18-responsive-modals-and-desktop-polish/18-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 18: Code Review Fix Report

**Fixed at:** 2026-06-15T01:34:28Z
**Source review:** .planning/phases/18-responsive-modals-and-desktop-polish/18-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01 + WR-01: Nested SingleChildScrollView in dialog mode / ScrollController leak

**Files modified:** `lib/widgets/adaptive_form_modal.dart`
**Commit:** aaf874b
**Applied fix:** Extracted dialog content into a private `_DialogForm` StatefulWidget.
This simultaneously fixes CR-01 (removes the outer `SingleChildScrollView` that wrapped
the builder output — the form widgets already provide their own scrollable root, so the
nested scroll with a shared controller was causing undefined scroll-physics behavior) and
WR-01 (the controller is now created in `_DialogFormState` via `late final` and disposed
in `dispose()`, eliminating the memory leak that occurred when the controller was
allocated in the `showDialog` builder closure with no cleanup path).

The `_DialogForm` widget owns `ConstrainedBox(maxWidth: 560, maxHeight: 80%)` and passes
the properly-lifecycle-managed `ScrollController` directly to the builder (form widget's
own root `SingleChildScrollView`).

### CR-02: CommitmentsScreen._openAddSheet never passed isDialog: true

**Files modified:** `lib/screens/commitments/commitments_screen.dart`
**Commit:** 18c78ca
**Applied fix:** Added `final isDesktop = MediaQuery.of(context).size.width >= 720;`
and passed `isDialog: isDesktop` to `CommitmentFormSheet`, mirroring the explicit
pattern used in `GoalsScreen._openAddSheet` and `GoalsScreen._openEditSheet`.
The `ModalRoute.of(context) is DialogRoute` fallback in `CommitmentFormSheet.build()`
remains as a safety net but is no longer relied upon as the sole detection mechanism.

### WR-02: CommitmentFormSheet._save had no error handling

**Files modified:** `lib/screens/commitments/commitment_form_sheet.dart`
**Commit:** 299c9c3
**Applied fix:** Wrapped `saveBlock()` in `try/catch` and added a `ScaffoldMessenger`
snackbar on failure, mirroring the pattern in `GoalFormSheet._save` (lines 99–110).
Previously a `saveBlock()` exception would propagate uncaught, leaving the form open
with no user-visible feedback.

### WR-03: CommitmentFormSheet allowed endMinutes <= startMinutes

**Files modified:** `lib/screens/commitments/commitment_form_sheet.dart`
**Commit:** c88cb12
**Applied fix:** Added `_endMinutes > _startMinutes` as a third condition in `_canSave`.
This guards against zero-duration and inverted (end <= start) blocks being persisted,
which would produce incorrect free-time window calculations in the schedule generator.

### IN-01: Ambiguous day chip labels

**Files modified:** `lib/screens/commitments/commitment_form_sheet.dart`
**Commit:** bf1535b
**Applied fix:** Changed `const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S']` to
`const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']`. The previous labels
duplicated 'T' for Tuesday and Thursday, and 'S' for Saturday and Sunday.

### IN-02: CommitmentsScreen body ListView lacked 720dp content-width constraint

**Files modified:** `lib/screens/commitments/commitments_screen.dart`
**Commit:** a55231e
**Applied fix:** Wrapped both the `ListView.builder` and `_emptyState()` paths in
`Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: ...))`,
matching the pattern used on HomeScreen, GoalsScreen, and ScheduleScreen.

## Post-fix verification

- `flutter analyze lib/widgets/adaptive_form_modal.dart` — no issues
- `flutter analyze lib/screens/commitments/commitments_screen.dart` — no issues
- `flutter analyze lib/screens/commitments/commitment_form_sheet.dart` — no issues
- `flutter analyze` (full codebase) — 4 pre-existing info-level warnings in
  `test/screens/active_chunk_card_test.dart` (unrelated to changes, present before fixes)
- `flutter test` — **257 passed, 1 skipped** (same as baseline; skipped test is the
  pre-existing schedule screen ConstrainedBox test marked TODO(18-04))
- `adaptive_form_modal_test.dart` RESP-01, RESP-02, RESP-03 — all GREEN
- `dart format lib/` — 1 file reformatted (`adaptive_form_modal.dart`, minor whitespace)

---

_Fixed: 2026-06-15T01:34:28Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
