---
phase: 19-energy-valence
plan: 05
subsystem: ui
tags: [flutter, onboarding, energy-valence, hive, material3]

# Dependency graph
requires:
  - phase: 19-02
    provides: "Goal.energyValenceIndex (HiveField 12), EnergyValence enum, EnergyValence.gives.index"

provides:
  - "_Screen4 widget in onboarding PageView — headline, sub-copy, goal rows with FilterChip, empty state, inline quick-add, Skip + Let's go CTAs"
  - "_StepDots totalPages bumped from 3 to 4"
  - "Screen 3 onComplete/onSkip rerouted to _nextPage() (was _completeOnboarding)"
  - "_completeOnboarding step 3.5: save quick-added goals + apply EnergyValence.gives to marked goals"
  - "onboarding_screen4_test.dart GREEN (3/3 tests pass)"

affects: [phase-20-energy-scheduling, onboarding-flow, goals-persistence]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pending-goal caching via _getPendingGoalsForScreen4(): same Goal objects displayed on Screen 4 and saved in _completeOnboarding, giving stable UUIDs for the marked-ID set"
    - "Cache invalidation on Screen 3 exit: _screen4PendingGoals = null in both onComplete and onSkip callbacks before _nextPage()"
    - "_isSaving guard extended to Screen 4 both CTAs (Pitfall 5 mitigation)"

key-files:
  created: []
  modified:
    - lib/screens/onboarding/onboarding_screen.dart
    - test/screens/onboarding_screen4_test.dart

key-decisions:
  - "Pending goal caching: _getPendingGoalsForScreen4() caches Goal objects so marked IDs remain stable across PageView rebuilds. Without caching, every setState() would recreate Goal objects with new UUIDs, making the marked-ID set stale."
  - "Screen 1 goal saved via cached pending object (not a new Goal()) so that the ID marked on Screen 4 matches the ID saved at step (1)"
  - "Test navigation fix: updated _navigateToScreen4() to select a goal type and tap Continue (Screen 1's actual button) rather than the non-existent Next button assumed by the pre-written RED test"
  - "FilterChip tap added to the valence-assertion test case — pre-written test had the assertion but no explicit marking action"

patterns-established:
  - "Pending-goal caching in multi-step forms: when display objects need stable IDs for selection tracking, cache them at transition time rather than recreating on each build"

requirements-completed: [ONBOARD-01]

# Metrics
duration: 15min
completed: 2026-06-15
---

# Phase 19 Plan 05: Onboarding Energy Step Summary

**Onboarding Screen 4 "What gives you energy?" seeds EnergyValence.gives on marked goals before first schedule via stable-ID pending-goal caching and a new _completeOnboarding step 3.5**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-15T02:34:00Z
- **Completed:** 2026-06-15T02:49:07Z
- **Tasks:** 2 (implemented together in one commit)
- **Files modified:** 2

## Accomplishments

- Inserted `_Screen4` as page index 3 of the onboarding PageView, following the `_Screen3` / `_ScreenLayout` patterns
- Rerouted Screen 3's `onComplete` and `onSkip` to call `_nextPage()` (was `_completeOnboarding()`), with cache invalidation of `_screen4PendingGoals` at that transition point
- Added `_completeOnboarding` step 3.5 that saves quick-add goals with `gives` valence, then re-fetches marked goals from the notifier (now persisted by steps 1+3) and applies `gives` before `setOnboardingComplete(true)`
- Fixed pre-written RED test navigation (used `Continue` not `Next`) and added the missing FilterChip tap in the valence assertion test; all 3 Screen 4 tests GREEN; full 281-test suite passes

## Task Commits

1. **Tasks 1+2: _Screen4 + valence step 3.5 + isSaving guard** - `d6ca5c2` (feat)

**Plan metadata:** (see final metadata commit below)

## Files Created/Modified

- `lib/screens/onboarding/onboarding_screen.dart` - Added _Screen4, _screen4MarkedGoalIds/QuickGoals state, _getPendingGoalsForScreen4() caching helper, step 3.5 in _completeOnboarding, bumped _StepDots to 4, rerouted Screen 3 callbacks
- `test/screens/onboarding_screen4_test.dart` - Fixed navigation helper (Continue button), added FilterChip tap for the valence assertion test

## Decisions Made

**Pending-goal caching:** `_getPendingGoalsForScreen4()` caches the Goal objects on first call and clears the cache in Screen 3's exit callbacks. Without this, every `setState()` rebuild would create new Goal instances with fresh UUIDs — the ID the user marked on Screen 4 would be stale by the time `_completeOnboarding()` ran. The cached objects are reused as-is in step (1) (Screen 1 goal save), giving step (3.5) a stable ID to look up in `goalsNotifier.goals`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test navigation used non-existent "Next" button on Screen 1**
- **Found during:** Task 1 verification (running onboarding_screen4_test.dart)
- **Issue:** The pre-written RED test's `_navigateToScreen4()` helper called `find.text('Next')` — Screen 1's button is "Continue", not "Next". The `if (nextBtn.evaluate().isNotEmpty)` guard silently no-oped, leaving the test stuck on Screen 1, so Screen 4's headline was never found.
- **Fix:** Updated `_navigateToScreen4()` to select a goal type ("I want to spend regular time on something") and enter a name ("Test Goal"), then tap "Continue" to advance Screen 1. Similarly fixed the second test (valence assertion) which also used `find.text('Next')`.
- **Files modified:** test/screens/onboarding_screen4_test.dart
- **Committed in:** d6ca5c2

**2. [Rule 1 - Bug] Pre-written test expected gives valence without ever marking a goal**
- **Found during:** Task 2 verification (semantics of the valence assertion test)
- **Issue:** The "Let's go" test asserted `morningRun.energyValence == EnergyValence.gives` but never tapped the "Energizing" FilterChip. Without marking the goal, valence stays neutral and the assertion would fail.
- **Fix:** Added `await tester.tap(find.text('Energizing'))` before tapping "Let's go".
- **Files modified:** test/screens/onboarding_screen4_test.dart
- **Committed in:** d6ca5c2

**3. [Rule 1 - Bug] UUID mismatch between displayed pending goals and goals saved in _completeOnboarding**
- **Found during:** Design review of _completeOnboarding step (1)
- **Issue:** The original plan called `_buildScreen4Goals()` in `build()` (creating new Goal UUIDs on every render) but step (1) of `_completeOnboarding` created yet another new Goal with a different UUID. The marked-ID set would reference display-goal UUIDs that never matched saved-goal UUIDs, so step (3.5) would always miss the mark.
- **Fix:** Replaced `_buildScreen4Goals()` with `_getPendingGoalsForScreen4()` which caches the list on first call and is invalidated (set to null) in Screen 3's exit callbacks. Step (1) of `_completeOnboarding` now reuses the same cached Goal object, giving a stable ID chain from display → marking → save → valence application.
- **Files modified:** lib/screens/onboarding/onboarding_screen.dart
- **Committed in:** d6ca5c2

---

**Total deviations:** 3 auto-fixed (all Rule 1 bugs)
**Impact on plan:** All fixes required for correct behavior. The UUID mismatch fix was the most critical — without it, the Screen 4 valence-marking feature would silently no-op for all goals.

## Issues Encountered

None beyond the auto-fixed deviations above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- ONBOARD-01 fulfilled: a "What gives you energy?" step seeds EnergyValence.gives goals before first schedule generation
- Phase 20 (valence-aware scheduling) can now read goal.energyValence and make scheduling decisions
- Wave 3 merge gate: full `flutter test` passes (281 tests, 1 pre-existing skip)

## Self-Check

- [x] `lib/screens/onboarding/onboarding_screen.dart` exists and contains `_Screen4`, `totalPages: 4`, `EnergyValence.gives.index`
- [x] `test/screens/onboarding_screen4_test.dart` — 3/3 GREEN
- [x] Full suite: 281 passed, 1 skipped (pre-existing)
- [x] Commit d6ca5c2 exists

## Self-Check: PASSED

---
*Phase: 19-energy-valence*
*Completed: 2026-06-15*
