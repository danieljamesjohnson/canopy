---
phase: 19-energy-valence
fixed_at: 2026-06-14T00:00:00Z
review_path: .planning/phases/19-energy-valence/19-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 19: Code Review Fix Report

**Fixed at:** 2026-06-14
**Source review:** `.planning/phases/19-energy-valence/19-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01: Screen 1 habit-type goal silently dropped during onboarding completion

**Files modified:** `lib/screens/onboarding/onboarding_screen.dart`
**Commit:** `427b1bd`
**Applied fix:** Replaced the type-based filter (`goalTypeIndex != GoalType.habit.index`) in `_completeOnboarding` with an object-identity check against `_screen3Habit`. The Screen 1 goal is now identified as `pendingGoals[0]` when that element is not the same object as `_screen3Habit`, rather than filtering by type. This correctly handles the case where a user selects GoalType.habit on Screen 1 (GoalTypePicker exposes all three types). Added a comment explaining why the type filter was dangerous.

**Verification note:** CR-01 was confirmed real: `GoalTypePicker` in `_Screen1` exposes all three goal types including `GoalType.habit`. The original filter would drop any Screen 1 goal whose type was habit.

---

### CR-02: Screen 4 quick-added goal "Energizing" chip permanently stuck selected

**Files modified:** `lib/screens/onboarding/onboarding_screen.dart`
**Commit:** `427b1bd`
**Applied fix (two parts):**

Part A: `_confirmQuickAdd` no longer pre-sets `energyValenceIndex: EnergyValence.gives.index` on the created goal. Instead it adds the goal's id to `_markedGoalIds` so the chip starts selected but can be toggled. The `isMarked` expression was simplified to `_markedGoalIds.contains(goal.id)` only — the `|| goal.energyValenceIndex == EnergyValence.gives.index` branch that permanently locked the chip was removed.

Part B: `_completeOnboarding` step 3.5 now conditionally applies `gives` valence to quick-goals only when their id remains in `_screen4MarkedGoalIds` (respecting any deselection), rather than unconditionally setting `gives` for every quick-goal.

**Test note:** `test/screens/onboarding_screen4_test.dart` was reviewed. The existing tests encode correct behavior (marking a goal gives it `gives` valence; skip leaves goals neutral). The CR-02 fix makes the deselect path work correctly without requiring test changes — the tests pass as-is because the "mark then Let's go" path still produces `gives` valence.

---

### WR-01: `energyValence` getter has no bounds guard — corrupt index causes RangeError crash

**Files modified:** `lib/data/models/goal.dart`
**Commit:** `eed308f`
**Applied fix:** Replaced the bare `EnergyValence.values[energyValenceIndex ?? 0]` expression with a multi-line getter that bounds-checks the index and returns `EnergyValence.neutral` for any index outside `[0, values.length)`. Safe default matches the field's documented semantics (neutral = 0, existing records without the field read as neutral).

---

### WR-02: In-flight quick-add text silently discarded when user taps "Let's go"

**Files modified:** `lib/screens/onboarding/onboarding_screen.dart`
**Commit:** `427b1bd`
**Applied fix:** Added a guard at the start of `_onComplete` that calls `_confirmQuickAdd()` when `_showQuickAdd` is true and `_quickAddController.text.trim()` is non-empty. This commits any in-progress typed goal before passing control to the parent callback.

---

### IN-01: `_lookupGoal*` helpers in ScheduleScreen perform repeated linear scans per chunk

**Files modified:** `lib/screens/schedule/schedule_screen.dart`
**Commit:** `7969e1d`
**Applied fix:** Added `_resolveGoal(BuildContext context, ScheduledChunk chunk)` helper that performs a single `.where((g) => g.id == chunk.goalId).firstOrNull` scan and returns the nullable `Goal`. All five `_lookupGoal*` methods now delegate to `_resolveGoal` instead of repeating the scan. Added `import '../../data/models/goal.dart'` (previously implicit through `GoalsNotifier` type inference; required once the explicit `Goal?` return type was added to `_resolveGoal`). The refactor preserves all existing behavior — the `_lookupGoalColor` null-check for `goal?.color` and `hexToColor` call is unchanged; the other four helpers use `?.` cascade reads from the resolved goal.

Assessment: clean, low-risk refactor; all existing behavior preserved; `flutter analyze` passed; IN-01 applied.

---

## Skipped Issues

None — all findings were fixed.

---

## Test / Analyze Results

- `flutter analyze` on changed files: no issues found
- `flutter analyze` (full project): 4 pre-existing info-level lint notes in `test/screens/active_chunk_card_test.dart` — none in files touched by these fixes
- `flutter test`: **281 passed, 1 skipped** (matches pre-fix baseline)
- `dart format lib/`: reformatted 2 files (goal.dart, onboarding_screen.dart); committed separately as `chore(19): dart format after phase-19 fixes`

---

_Fixed: 2026-06-14_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
