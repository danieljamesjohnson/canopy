---
phase: 18-responsive-modals-and-desktop-polish
plan: 05
subsystem: ui
tags: [flutter, material3, copy, polish, desktop, web]

# Dependency graph
requires:
  - phase: 18-02
    provides: adaptive_form_modal helper, GoalFormSheet isDialog parameter
  - phase: 18-03
    provides: CommitmentFormSheet isDialog parameter, commitments_screen caller migration
  - phase: 18-04
    provides: screen body content width constraints (720dp ConstrainedBox)
provides:
  - POLISH-02 copy fixes: context-specific goal form labels (Add Goal/Save Goal/Discard/Archive goal)
  - Commitment form Discard TextButton (both add and edit paths)
  - Delete confirm context-specific copy (Delete commitment / Keep commitment)
  - Full suite green at 257 tests passed
  - Debug web bundle compiles clean (flutter build web --debug --source-maps --pwa-strategy=none)
affects: [future phases that modify goal_form_sheet, commitment_form_sheet, commitments_screen]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Discard TextButton above FilledButton pattern: TextButton(Discard) + SizedBox(8) + FilledButton(save) — used in commitment_form_sheet"
    - "Context-specific CTA labels: _isEditMode ? 'Save Goal' : 'Add Goal' — clearer than generic Save/Add"
    - "Context-specific confirm/cancel: 'Delete commitment' / 'Keep commitment' instead of 'Delete' / 'Cancel'"

key-files:
  created: []
  modified:
    - lib/screens/goals/goal_form_sheet.dart
    - lib/screens/commitments/commitment_form_sheet.dart
    - lib/screens/commitments/commitments_screen.dart
    - test/screens/goal_form_priority_test.dart

key-decisions:
  - "Discard TextButton sits above the FilledButton (not in a Row) to give it full width and clear visual hierarchy — consistent with how goal_form_sheet.dart arranges its cancel+save row"
  - "goal_form_priority_test.dart tap finder updated from 'Add goal' to 'Add Goal' (Rule 1 auto-fix) — test was tightly coupled to the old label; updated to match POLISH-02 copy"

patterns-established:
  - "POLISH-02 copy convention: all destructive-confirm cancel buttons use 'Keep <noun>' pattern; primary CTA uses verb+noun ('Save Goal', 'Add Goal', 'Delete commitment')"

requirements-completed: [POLISH-02]

# Metrics
duration: ~25min
completed: 2026-06-15
---

# Phase 18 Plan 05: Copy Polish + Walkthrough Summary

**POLISH-02 copy fixes applied: context-specific "Add Goal"/"Save Goal"/"Discard"/"Archive goal" in goal form, "Discard" TextButton added to commitment form, "Delete commitment"/"Keep commitment" in delete confirm — full suite 257/257 green, debug web bundle builds clean**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-15T00:55:00Z (approx)
- **Completed:** 2026-06-15T01:20:21Z
- **Tasks:** 2 (+ 1 Rule 1 deviation auto-fix)
- **Files modified:** 4 (3 source + 1 test)

## Accomplishments

- Applied all 6 POLISH-02 FIX rows from UI-SPEC Copywriting Contract to goal_form_sheet.dart and commitments_screen.dart
- Added "Discard" TextButton to CommitmentFormSheet above the FilledButton (both add and edit modes); locked labels ('Add commitment', 'Save changes') untouched
- Updated goal_form_priority_test.dart tap finders from 'Add goal' to 'Add Goal' (Rule 1 auto-fix — copy rename broke two GOALFORM-02 tests)
- goal_form_copy_test.dart: 3/3 tests RED → GREEN
- Full suite: 257 tests passed, 1 skipped (pre-existing), 0 failures
- flutter analyze: 0 errors/warnings in modified files; 4 pre-existing info notes in unrelated test file
- Debug web bundle compiled clean: `flutter build web --debug --source-maps --pwa-strategy=none` → `✓ Built build/web`

## Task Commits

1. **Task 1: Apply POLISH-02 copy fixes and add commitment Discard button** - `d9b05b0` (feat)
2. **Rule 1 auto-fix: update goal_form_priority_test label refs** - `5aaac86` (fix)

**Plan metadata:** (docs commit recorded below after state updates)

## Files Created/Modified

- `lib/screens/goals/goal_form_sheet.dart` — Title 'Edit goal'→'Edit Goal'/'Add goal'→'Add Goal'; CTA 'Save'→'Save Goal'/'Add goal'→'Add Goal'; Cancel TextButton 'Cancel'→'Discard'; Archive TextButton 'Archive'→'Archive goal'
- `lib/screens/commitments/commitment_form_sheet.dart` — Added `TextButton('Discard')` + `SizedBox(8)` above the FilledButton in the save button block
- `lib/screens/commitments/commitments_screen.dart` — Delete confirm AlertDialog: 'Cancel'→'Keep commitment', 'Delete'→'Delete commitment'
- `test/screens/goal_form_priority_test.dart` — Two tap finders updated: `find.text('Add goal').last` → `find.text('Add Goal').last` (Rule 1 auto-fix)

Additional files reformatted by `dart format lib/` (CLAUDE.md requirement): resilient_box.dart, schedule_notifier.dart, goal_card.dart, active_chunk_card.dart, chunk_card.dart, schedule_generator.dart — no logic changes, staged in Task 1 commit.

## Decisions Made

- Discard TextButton placed above FilledButton in a Column (not in a Row with the save button), matching the goal_form_sheet pattern where cancel/archive sit above the Row. Gives the button full width and clear visual hierarchy.
- Did not change 'Add goal' label on the FloatingActionButton.extended in goals_screen.dart — the UI-SPEC only specifies form copy; FAB label is a separate element not listed in the Copywriting Contract FIX rows.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] goal_form_priority_test.dart broke on 'Add goal' → 'Add Goal' rename**
- **Found during:** Task 2 (full suite run)
- **Issue:** Two GOALFORM-02 tests used `find.text('Add goal').last` to tap the save ElevatedButton. POLISH-02 renamed the CTA to 'Add Goal'. `find.text('Add goal')` evaluated to empty list → `Bad state: No element` at `.last` → test crashed.
- **Fix:** Updated both `find.text('Add goal').last` calls to `find.text('Add Goal').last` and updated inline comments.
- **Files modified:** `test/screens/goal_form_priority_test.dart`
- **Verification:** `flutter test` — 257/257 passed
- **Committed in:** `5aaac86` (separate fix commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 bug — test label mismatch after copy rename)
**Impact on plan:** Necessary correctness fix. No scope creep.

## Desktop Walkthrough Triage — PENDING HUMAN VERIFICATION

**Status: AWAITING MANUAL SIGN-OFF**

The debug web bundle compiled successfully and is ready to serve. The interactive visual walkthrough at >= 720dp in a real GPU-backed browser has NOT been performed by this agent — per the execution notes, the agent does not have access to a real GPU browser and cannot perform or evaluate the visual triage autonomously.

### What was verified (automated / static)

| Check | Result | Method |
|-------|--------|--------|
| Debug web build compiles | PASS | `flutter build web --debug --source-maps --pwa-strategy=none` → `✓ Built build/web` |
| Goal form dialog mode: isDialog parameter present, drag handle conditionally hidden | PASS | Code review + adaptive_form_modal_test.dart RESP-02 test |
| GoalFormSheet: title/CTA/Discard/Archive labels correct | PASS | goal_form_copy_test.dart 3/3 GREEN |
| CommitmentFormSheet: Discard TextButton present above FilledButton | PASS | Code review + goal_form_copy_test.dart |
| commitments_screen delete dialog: Keep/Delete commitment labels | PASS | goal_form_copy_test.dart |
| Home screen body: ConstrainedBox(maxWidth: 720) present | PASS | Code review (confirmed from 18-04) |
| Goals screen body: ConstrainedBox(maxWidth: 720) present | PASS | Code review (confirmed from 18-04) |
| Known nit (goal form bottom sheet on desktop) resolved | PASS | 18-02 adaptive helper + RESP-01/02/03 tests GREEN |
| Schedule screen ScheduleProgressBar full-width, ListView constrained | PASS | Code review (confirmed from 18-04) |

### What requires human verification (browser walkthrough)

The POLISH-02 walkthrough protocol (UI-SPEC §POLISH-02 Audit Scope, 18-VALIDATION.md §Manual-Only Verifications) requires a human to:

1. Serve the debug build: `cd /home/dan/CodeProjects/canopy/build/web && python3 -m http.server <fresh-port> --bind 0.0.0.0`
2. Open at `http://danserver:<port>/` in a real GPU-backed browser at >= 720dp width
3. Walk Home → Schedule → Goals → Check-in + goal Add/Edit modal + commitment Add/Edit modal

**Human verify checklist:**
- [ ] (1) Goal Add opens as a centered dialog (not bottom sheet); type picker + Priority + Save Goal visible without scroll
- [ ] (2) Goal Edit opens as a centered dialog; "Edit Goal" title, "Save Goal" CTA, "Discard" button, "Archive goal" button all present
- [ ] (3) Commitment Add opens as a centered dialog; "Discard" TextButton above "Add commitment" FilledButton
- [ ] (4) Commitment Edit opens as a centered dialog; "Discard" TextButton above "Save changes" FilledButton
- [ ] (5) Delete commitment confirm: shows "Delete commitment" and "Keep commitment" buttons
- [ ] (6) Home/Schedule/Goals content is a centered ~720dp column, not full-bleed, on a wide viewport
- [ ] (7) No high-friction nits found (clipping, cramping, layout breakage) — or list them here

**To serve the build:**
```bash
cd /home/dan/CodeProjects/canopy/build/web && python3 -m http.server 8096 --bind 0.0.0.0
# Then open http://danserver:8096/ in a real browser at desktop width
```
(Use port 8096 or another fresh port that has never served a release build — see CLAUDE.md Two traps §1)

**Reply "approved" or list issues to close POLISH-02.**

## Issues Encountered

- None beyond the Rule 1 auto-fix documented above.

## Known Stubs

None — all copy changes are wired to live UI labels (not placeholder text).

## Threat Flags

None — this plan makes only string-literal copy changes and adds a TextButton. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- POLISH-02 is functionally complete from an automated-verification standpoint
- The interactive desktop walkthrough at >= 720dp in a real browser is the final sign-off gate for Phase 18
- All three responsive modal form sheets and all four constrained-width screens are wired correctly per the adaptive helper (Phase 18-02/03/04)
- Full test suite is green at 257 tests; debug web bundle builds clean
- Phase 18 can be declared complete once the human walkthrough approves (or any high-friction nits found are fixed in a follow-up commit)

## Self-Check: PASSED

All key files confirmed present on disk. Both task commits verified in git log. Copy string assertions confirmed in source files.

---
*Phase: 18-responsive-modals-and-desktop-polish*
*Completed: 2026-06-15*
