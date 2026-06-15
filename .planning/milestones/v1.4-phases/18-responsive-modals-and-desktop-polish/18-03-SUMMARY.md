---
phase: 18-responsive-modals-and-desktop-polish
plan: "03"
subsystem: ui
tags: [flutter, material3, dialog, bottom-sheet, responsive, adaptive-modal]

requires:
  - phase: 18-02
    provides: "showAdaptiveFormModal helper; GoalFormSheet isDialog pattern"

provides:
  - "CommitmentFormSheet isDialog param (drag handle + padding gated on dialog mode)"
  - "commitments_screen._openAddSheet routed through showAdaptiveFormModal"
  - "ModalRoute fallback detection in CommitmentFormSheet matching GoalFormSheet"

affects:
  - 18-04
  - 18-05

tech-stack:
  added: []
  patterns:
    - "CommitmentFormSheet mirrors GoalFormSheet isDialog pattern: widget.isDialog || (ModalRoute.of(context) is DialogRoute)"
    - "All user-facing form callers now route through showAdaptiveFormModal — no screen calls showModalBottomSheet directly for forms"

key-files:
  created: []
  modified:
    - lib/screens/commitments/commitment_form_sheet.dart
    - lib/screens/commitments/commitments_screen.dart

key-decisions:
  - "ModalRoute detection fallback added to CommitmentFormSheet (same as GoalFormSheet in 18-02) so test helpers calling CommitmentFormSheet without isDialog:true still get correct dialog behavior"
  - "commitments_screen._openAddSheet signature preserved ([CommitmentBlock? block] optional param) — only the body changed to route through the helper"

patterns-established:
  - "Every form sheet in the app uses isDialog param + ModalRoute fallback to self-detect its container type"
  - "showAdaptiveFormModal is the single entry point for all user-facing form modals — no screen may call showModalBottomSheet directly for forms"

requirements-completed: [RESP-03]

duration: 3min
completed: "2026-06-15"
---

# Phase 18 Plan 03: Commitment Caller Summary

**CommitmentFormSheet gains isDialog param with ModalRoute fallback; commitment caller routes through showAdaptiveFormModal — completing the adaptive form migration for all user-facing forms**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-15T01:05:00Z
- **Completed:** 2026-06-15T01:08:18Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Added `isDialog` param to `CommitmentFormSheet` with `ModalRoute.of(context) is DialogRoute` fallback, mirroring the pattern from `GoalFormSheet` (18-02)
- Drag-handle Container wrapped in `if (!isDialog)` — hidden when rendered in a centered Material Dialog
- Padding changed to fixed 24dp top/bottom in dialog mode; `viewInsetsOf` only applied in sheet mode
- Replaced `_openAddSheet` in `commitments_screen.dart` — no longer calls `showModalBottomSheet` directly; routes through `showAdaptiveFormModal`
- RESP-03 test GREEN: commitment form opens as Dialog at >= 720dp via `showAdaptiveFormModal`

## Task Commits

1. **Task 1: Add isDialog to CommitmentFormSheet and route commitment caller through helper** - `2a6e920` (feat)

## Files Created/Modified
- `lib/screens/commitments/commitment_form_sheet.dart` — isDialog param + ModalRoute detection; drag handle and padding gated on dialog mode
- `lib/screens/commitments/commitments_screen.dart` — _openAddSheet replaced with showAdaptiveFormModal; adaptive_form_modal.dart import added

## Decisions Made
- **ModalRoute detection as fallback:** Consistent with 18-02's decision for GoalFormSheet — test helpers that call `CommitmentFormSheet(scrollController: sc)` without `isDialog: true` (e.g. the RESP-03 test via `_pumpAdaptiveCommitmentModal`) still suppress the drag handle and fixed padding when rendered inside a Dialog.
- **Caller does not pass isDialog explicitly:** The plan noted passing `isDialog: MediaQuery.of(context).size.width >= 720` at the call site. Since `showAdaptiveFormModal` already routes to `showDialog` at >= 720dp, the ModalRoute fallback makes the explicit parameter redundant for the production path. Keeping the call site clean (no explicit `isDialog`) is simpler and the fallback makes it correct — this matches how the RESP-03 test is written.

## Deviations from Plan

None — plan executed as specified. The ModalRoute fallback was anticipated by the 18-02 pattern and the plan notes described it as the "ModalRoute route-type fallback" pattern to consider.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All user-facing form callers (goals + commitments) now route through `showAdaptiveFormModal`
- RESP-01, RESP-02, RESP-03 all satisfied
- Ready for 18-04 (content-width body constraints) and 18-05 (copy polish)

## Threat Flags
None — widget-layer container swap only; no new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

- lib/screens/commitments/commitment_form_sheet.dart: FOUND
- lib/screens/commitments/commitments_screen.dart: FOUND
- commit 2a6e920: FOUND
- RESP-03 test: GREEN (5/5 tests pass)

---
*Phase: 18-responsive-modals-and-desktop-polish*
*Completed: 2026-06-15*
