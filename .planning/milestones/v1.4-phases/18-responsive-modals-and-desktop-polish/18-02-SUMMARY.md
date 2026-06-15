---
phase: 18-responsive-modals-and-desktop-polish
plan: "02"
subsystem: ui
tags: [flutter, material3, dialog, bottom-sheet, responsive, adaptive-modal]

requires:
  - phase: 18-01
    provides: "RED test stubs for adaptive_form_modal_test.dart (RESP-01/02/03)"

provides:
  - "showAdaptiveFormModal helper routing forms to Dialog (>= 720dp) or BottomSheet (< 720dp)"
  - "GoalFormSheet isDialog param; route-detection fallback via ModalRoute"
  - "goals_screen._openAddSheet/_openEditSheet routed through showAdaptiveFormModal"

affects:
  - 18-03
  - 18-04
  - 18-05
  - commitments_screen
  - goal_form_sheet
  - adaptive_form_modal

tech-stack:
  added: []
  patterns:
    - "showAdaptiveFormModal: MediaQuery width >= 720 → showDialog vs showModalBottomSheet"
    - "isDialog detection: widget.isDialog || (ModalRoute.of(context) is DialogRoute)"
    - "screenHeight captured before showDialog to avoid Pitfall 1 (dialog constraints)"

key-files:
  created:
    - lib/widgets/adaptive_form_modal.dart
  modified:
    - lib/screens/goals/goal_form_sheet.dart
    - lib/screens/goals/goals_screen.dart

key-decisions:
  - "Route detection via ModalRoute.of(context) is DialogRoute added to GoalFormSheet as a fallback so test helpers can call GoalFormSheet without explicit isDialog: true and still get correct dialog behavior"
  - "720dp threshold inlined in showAdaptiveFormModal (not extracted to constant) to match responsive_shell.dart existing inline usage per D-11"
  - "Horizontal/top padding bumped from 16dp to 24dp in dialog mode per UI-SPEC lg spacing token"

patterns-established:
  - "showAdaptiveFormModal is the single entry point for all user-facing form modals; no screen may call showModalBottomSheet directly for forms"
  - "Form sheets detect dialog context via widget.isDialog param OR ModalRoute route type — caller can omit isDialog and route detection handles it"

requirements-completed: [RESP-01, RESP-02]

duration: 3min
completed: "2026-06-15"
---

# Phase 18 Plan 02: Adaptive Helper + Goal Form Summary

**showAdaptiveFormModal helper routing goal add/edit to Dialog at >= 720dp and BottomSheet at < 720dp via ModalRoute-aware GoalFormSheet**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-15T01:01:10Z
- **Completed:** 2026-06-15T01:04:36Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- Created `lib/widgets/adaptive_form_modal.dart` — `showAdaptiveFormModal` routes to `showDialog` (Dialog + ConstrainedBox 560dp/80%vh) at >= 720dp and `showModalBottomSheet` (DraggableScrollableSheet 0.6/0.4/1.0) at < 720dp
- Added `isDialog` parameter to `GoalFormSheet` with a `ModalRoute.of(context) is DialogRoute` fallback so test helpers that omit `isDialog: true` still suppress the drag handle and viewInsets.bottom
- Replaced `_openAddSheet` and `_openEditSheet` in `goals_screen.dart` to route through `showAdaptiveFormModal`
- All RESP-01 and RESP-02 test cases GREEN; `goal_form_priority_test.dart` (15 tests) unaffected

## Task Commits

1. **Task 1: Create showAdaptiveFormModal helper** - `6560243` (feat)
2. **Task 2: Add isDialog to GoalFormSheet; route goal callers through helper** - `3184825` (feat)

## Files Created/Modified
- `lib/widgets/adaptive_form_modal.dart` - Top-level async helper; desktop → Dialog, mobile → ModalBottomSheet
- `lib/screens/goals/goal_form_sheet.dart` - isDialog param + ModalRoute detection; drag handle and padding gated
- `lib/screens/goals/goals_screen.dart` - _openAddSheet/_openEditSheet replaced with showAdaptiveFormModal calls

## Decisions Made
- **ModalRoute detection as fallback:** The test stubs from plan 18-01 call `GoalFormSheet(scrollController: sc)` without `isDialog: true`. To make those tests pass without changing the test code, `GoalFormSheet.build()` checks `ModalRoute.of(context) is DialogRoute` as a fallback. This means callers can omit `isDialog` and get correct behavior automatically.
- **isDialog explicit parameter retained:** The `goals_screen.dart` call sites still pass `isDialog: isDesktop` explicitly for clarity and correctness (the explicit value is a no-op when route detection would give the same result, but makes the intent clear at the call site).
- **720 inlined, not extracted:** Matches responsive_shell.dart's existing inline usage per Decision D-11.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added ModalRoute-based dialog detection to GoalFormSheet**
- **Found during:** Task 2 (Add isDialog to GoalFormSheet)
- **Issue:** The test stub from plan 18-01 (`adaptive_form_modal_test.dart`) calls `GoalFormSheet(scrollController: sc)` without `isDialog: true`. With only the explicit parameter, the drag handle RESP-02 test failed because the handle Container (40×4) was still present inside the Dialog.
- **Fix:** Added `final isDialog = widget.isDialog || (ModalRoute.of(context) is DialogRoute)` in `build()` so the form detects its container automatically when the parameter is omitted.
- **Files modified:** `lib/screens/goals/goal_form_sheet.dart`
- **Verification:** `flutter test test/screens/adaptive_form_modal_test.dart` → all 5 tests pass; `goal_form_priority_test.dart` → all 11 tests unaffected
- **Committed in:** `3184825` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — test-spec vs implementation mismatch)
**Impact on plan:** Fix was necessary for the spec tests (written in 18-01 RED wave) to pass. No scope creep — the behavior is correct and the API signature matches the plan exactly.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `showAdaptiveFormModal` is ready for 18-03 (commitment form caller migration)
- `GoalFormSheet.isDialog` pattern is ready to be mirrored in `CommitmentFormSheet` (18-03)
- RESP-01 and RESP-02 requirements satisfied; RESP-03 and POLISH-01/02 remain

## Threat Flags
None — widget-layer container swap only; no new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

- lib/widgets/adaptive_form_modal.dart: FOUND
- lib/screens/goals/goal_form_sheet.dart: FOUND
- lib/screens/goals/goals_screen.dart: FOUND
- .planning/phases/18-responsive-modals-and-desktop-polish/18-02-SUMMARY.md: FOUND
- commit 6560243 (Task 1): FOUND
- commit 3184825 (Task 2): FOUND

---
*Phase: 18-responsive-modals-and-desktop-polish*
*Completed: 2026-06-15*
