---
phase: 34-adding-a-goal-feels-like-onboarding
plan: 01
subsystem: ui
tags: [flutter, provider, hive, goals, material3, filterchip]

requires: []
provides:
  - "PresetChipGrid — the shared FilterChip grid (createOnly/toggle modes) generalizing restoratives' _QuickPickSection and onboarding's _ChipCloud"
  - "GoalPresetPickerSheet + kCommonGoals — the 8 (name, emoji) presets shared with onboarding"
  - "GoalsNotifier.addPresetGoal — the emoji-carrying sibling to quickAddGoals"
  - "GoalsNotifier._newDefaultGoal — one factory both creation paths now share"
affects: [34-02-onboarding-parity, 34-03-uat]

actuals:
  tokens: 9418
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "PresetChipMode enum (createOnly/toggle) to share one chip widget across surfaces with different removal semantics"
    - "Optimistic local Set<String> claiming state, mutated synchronously before an async save, to close a double-tap race that pumpAndSettle cannot observe"
    - "Deferred modal handoff: the picker sheet pops itself and calls a caller-supplied onRequestForm callback, so the next sheet opens only after the first modal's Future completes (one modal at a time)"

key-files:
  created:
    - lib/widgets/preset_chip_grid.dart
    - lib/screens/goals/widgets/goal_preset_picker_sheet.dart
    - test/screens/goals/goal_preset_picker_test.dart
  modified:
    - lib/providers/goals_notifier.dart
    - lib/screens/goals/goals_screen.dart
    - test/screens/goals_add_fork_test.dart

key-decisions:
  - "D-34-06 (planner's call, honored): addPresetGoal is a new sibling method, not a widened quickAddGoals — quickAddGoals returns Future<int> and 10 call sites would need touching for no gain."
  - "D-34-07 boundary (honored): PresetChipGrid owns the preset grid only; 'what you already have' (GoalCard list, Just Added list) stays per-surface."
  - "Every rendered-budget assertion reads 'X.X hrs/week' as text, never goal.weeklyHourBudget — per D-34-03's amendment to GOALADD-03."

patterns-established:
  - "PresetChipGrid.unclaimed(...) is the single definition of 'is this preset already claimed' (trim+lowercase), used by every caller to decide both filtering and section-gating."

requirements-completed: [GOALADD-01, GOALADD-02, GOALADD-03]

coverage:
  - id: D1
    description: "The goal door of the add-goal fork opens GoalPresetPickerSheet (a preset grid), never GoalFormSheet directly; all 8 kCommonGoals render as chips carrying both word and glyph."
    requirement: GOALADD-01
    verification:
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#GOALADD-01: the goal door opens the preset picker, and no goal form"
        status: pass
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#GOALADD-01: all 8 kCommonGoals render as chips carrying word AND glyph"
        status: pass
      - kind: unit
        ref: "test/screens/goals_add_fork_test.dart#the goal door opens the preset picker, not the goal form"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tapping a preset chip creates exactly one goal immediately (no confirmation, no form, no spinner); the created row renders '3.0 hrs/week' as text and its emoji, and the model itself carries emojiTag."
    requirement: GOALADD-03
    verification:
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#D-34-01: tapping Reading creates exactly one goal, no dialog, no form, no spinner in between"
        status: pass
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#GOALADD-03/D-34-03: the created row renders '3.0 hrs/week' as text"
        status: pass
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#D-34-04: the glyph renders on the created row AND the model carries emojiTag"
        status: pass
    human_judgment: false
  - id: D3
    description: "'Add your own' reaches a blank GoalFormSheet in one tap; the picker contains zero editable text fields; a Just Added row reaches that goal's form in edit mode; with all 8 presets claimed, Common is absent and Add your own remains; Done exits without prompting a form."
    requirement: GOALADD-02
    verification:
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#GOALADD-02: one tap on Add your own reaches a blank GoalFormSheet"
        status: pass
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#UI-SPEC Decision 2: the picker sheet contains no editable text field of any kind"
        status: pass
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#D-34-02: tapping a Just Added row reaches that goal's form in edit mode"
        status: pass
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#UI-SPEC Decision 5: with all 8 presets already claimed, Common is absent and Add your own still shows"
        status: pass
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#Done closes the sheet, leaving goals created this visit on the Goals screen"
        status: pass
    human_judgment: false
  - id: D4
    description: "A failed write restores the chip, shows no goal card, surfaces 'Could not save goal. Please try again.', and leaves the notifier holding nothing — the optimistic UI cannot lie about a goal that was never saved (T-34-01 mitigation)."
    verification:
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#a failed write restores the chip, shows no goal card, and surfaces the failure copy"
        status: pass
    human_judgment: false
  - id: D5
    description: "The tapped chip disappears synchronously in the same frame as the tap, before the async save resolves — closing the double-tap race (T-34-02 mitigation, UI-SPEC Decision 4)."
    verification:
      - kind: unit
        ref: "test/screens/goals/goal_preset_picker_test.dart#UI-SPEC Decision 4: the chip is gone one frame after the tap, while the save is still pending"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-09-08
status: complete
---

# Phase 34 Plan 01: One Tap On A Preset Chip Creates A Goal You Can See Summary

**Ruling (a) shipped end to end: the goal door now opens a shared PresetChipGrid, a tap creates the
goal immediately via `GoalsNotifier.addPresetGoal`, and the created row states its own
'3.0 hrs/week' budget and emoji — the mitigation that makes (a) safe.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-09-08T13:00:00Z (approx.)
- **Completed:** 2026-09-08T13:53:50Z
- **Tasks:** 3
- **Files modified:** 6 (3 created, 3 modified)

## Accomplishments

- `lib/widgets/preset_chip_grid.dart`: a single shared `FilterChip` grid (`PresetChipMode.createOnly`
  / `toggle`) generalizing restoratives' `_QuickPickSection` and onboarding's `_ChipCloud` — the
  extract-and-reuse move this phase exists to make (no third private copy).
- `lib/screens/goals/widgets/goal_preset_picker_sheet.dart`: `GoalPresetPickerSheet` + `kCommonGoals`
  (8 presets, each with sketch-006's emoji). Tapping a preset chip creates the goal immediately —
  chip removal is synchronous with the tap (before the async save resolves), closing the double-tap
  race UI-SPEC Decision 4 names. "Add your own" and "Just added" rows each reach `GoalFormSheet` in
  one tap; "Done" exits without opening anything.
- `lib/providers/goals_notifier.dart`: extracted `_newDefaultGoal` so `quickAddGoals` and the new
  `addPresetGoal` share one definition of a fresh goal's defaults; `addPresetGoal` returns the
  created `Goal` (needed for the "Just added" card and the edit-sheet handoff) and returns `null` on
  a failed save without rethrowing.
- `lib/screens/goals/goals_screen.dart`: `_openAddSheet`'s goal-door branch now opens the picker;
  `GoalFormSheet` opens afterward only if the picker requested it (one modal at a time).
- A failed write (Task 3) restores the chip to the grid, shows zero cards, and surfaces the same
  `'Could not save goal. Please try again.'` copy `goal_form_sheet.dart` already ships.

## Task Commits

1. **Task 1: One tap on a preset chip creates a goal you can see — end to end** - `026bc93` (feat)
2. **Task 2: Add your own, Done, the empty grid, and the row that opens the form** - `c49d910` (feat)
3. **Task 3: A failed write must not leave a goal the user believes exists** - `9f06bf5` (fix)

## Files Created/Modified

- `lib/widgets/preset_chip_grid.dart` - new shared `PresetChipGrid` widget + `PresetChipMode` enum
- `lib/screens/goals/widgets/goal_preset_picker_sheet.dart` - new `GoalPresetPickerSheet` + `kCommonGoals`
- `lib/providers/goals_notifier.dart` - extracted `_newDefaultGoal`; added `addPresetGoal`
- `lib/screens/goals/goals_screen.dart` - `_openAddSheet` now opens the picker, deferring the form
- `test/screens/goals/goal_preset_picker_test.dart` - new: 13 tests proving GOALADD-01/02/03 and D-34-01..04
- `test/screens/goals_add_fork_test.dart` - repointed 2 tests that expected `GoalFormSheet` immediately

## Decisions Made

- **D-34-06 honored:** `addPresetGoal` is a new sibling method rather than a widened `quickAddGoals`
  — `quickAddGoals` returns `Future<int>` and the picker needs the created `Goal` object itself;
  widening would touch 10 call sites for no gain. `test/providers/goals_notifier_quick_add_test.dart`
  and `test/screens/quick_add_goals_test.dart` both pass with **zero edits** (verified via
  `git diff` against the pre-phase commit), proving the `_newDefaultGoal` extraction is a pure
  refactor of `quickAddGoals`'s internals.
- **No confirmation dialog, no pre-create form, no intermediate sheet** between the chip tap and the
  goal existing — ruling (a) verbatim. `_onCreate`'s ordering (`_claiming.add` synchronously, THEN
  `await addPresetGoal`) is the one functional requirement this plan calls out as testable, and it is
  tested (and mutation-tested — see below).
- Reused `GoalCard` verbatim for the "Just added" list; no new summary widget, per the plan's Decision
  1 (`_secondaryLine` already renders the budget).

## Deviations from Plan

None — plan executed exactly as written. Two test-authoring corrections were made and are
documented under Issues Encountered below (both caught before commit, neither reflects a defect in
production code).

## Mutation Tests — actual RED output recorded

Per CLAUDE.md ("Assertions that cannot fail") and this plan's own acceptance criteria, every listed
mutation was actually introduced, run, observed RED, and reverted. All four Task 1 mutations, both
Task 2 mutations, and the one Task 3 mutation are recorded below with the real failure text.

### Task 1

**Mutation 1 — revert `_openAddSheet` to build `GoalFormSheet` directly.**
```
Expected: exactly one matching candidate
  Actual: _TypeWidgetFinder:<Found 0 widgets with type "GoalPresetPickerSheet": []>
   Which: means none were found but one was expected
```
(GOALADD-01 test failed as expected.) Reverted; confirmed byte-identical via `diff`.

**Mutation 2 — pass `emoji: null` from `onCreate`.**
```
Expected: exactly one matching candidate
  Actual: _DescendantWidgetFinder:<Found 0 widgets with text "📚" descending from widgets with type
"GoalCard" descending from widgets with type "GoalPresetPickerSheet": []>
   Which: means none were found but one was expected
```
(D-34-04 emoji test failed as expected — both the rendered-glyph and model assertions are on the
same line, so the render-side finder failing first is sufficient; the model assertion
`h.goals.goals.single.emojiTag` would equally have failed had it been reached.) Reverted; confirmed
byte-identical via `diff`.

**Mutation 3 — delete the `if (secondary != null)` render block in `goal_card.dart`.**
```
Expected: exactly one matching candidate
  Actual: _DescendantWidgetFinder:<Found 0 widgets with text "3.0 hrs/week" descending from widgets
with type "GoalCard" descending from widgets with type "GoalPresetPickerSheet": []>
   Which: means none were found but one was expected
```
(GOALADD-03/D-34-03 test failed as expected.) Reverted; confirmed byte-identical via `diff`.

**Mutation 4 — move `_claiming.add(...)` to after the `await`.**
```
Expected: no matching candidates
  Actual: _AncestorWidgetFinder:<Found 1 widget with type "FilterChip" that are ancestors of widget
with text "Reading": [FilterChip(...)]>
   Which: means one was found but none were expected
```
(UI-SPEC Decision 4 race test failed as expected — the chip was still present one frame after the
tap.) Reverted; confirmed byte-identical via `diff`.

### Task 2

**Mutation 1 — point "Add your own" at `_requestForm` with a non-null goal.**

First attempt at the create-mode proof used `expect(find.text('Add Goal'), findsOneWidget)`, which
turned out to be ambiguous on the UNMUTATED code too: `GoalFormSheet` renders the literal text
`'Add Goal'` in TWO places in create mode (the sheet title AND the submit button), so
`findsOneWidget` failed with "too many" even with no mutation applied — an unrelated pre-existing bug
in my own test, not a mutation (documented under Issues Encountered below). Replaced it with
`'Edit Goal'`/`'Save Goal'` absence checks (each renders ONLY in edit mode, so there is no ambiguity)
before mutation-testing this task's assertion. With that fix in place and the mutation applied, the
test goes RED as expected:
```
Expected: no matching candidates
  Actual: _TextWidgetFinder:<Found 1 widget with text "Edit Goal": [Text("Edit Goal", ...
titleLarge..., textAlign: center, ...)]>
   Which: means one was found but none were expected
```
This was the only failing test in the file under this mutation. Reverted; confirmed byte-identical
via `diff`.

**Mutation 2 — drop the `unclaimed(...).isNotEmpty` gate so the heading always renders.**
```
Expected: no matching candidates
  Actual: _TextWidgetFinder:<Found 1 widget with text "Common": [Text("Common", ...)]>
   Which: means one was found but none were expected
```
(UI-SPEC Decision 5 test failed as expected — only that test failed once the create-mode assertion
was fixed; no other test in the file was affected by this mutation.) Reverted; confirmed
byte-identical via `diff`.

### Task 3

**Mutation — make the null branch a no-op (chip stays gone, no SnackBar).**
```
Expected: exactly one matching candidate
  Actual: _AncestorWidgetFinder:<Found 0 widgets with type "FilterChip" that are ancestors of
widgets with text "Reading": []>
   Which: means none were found but one was expected
```
(The chip-restored assertion — the first of the three end-state checks in the test body — failed as
expected; `expect()` stops at the first failure, so the SnackBar assertion below it was never
reached, but it would equally have failed since the no-op mutation shows no SnackBar either.)
Reverted; confirmed byte-identical via `diff`.

## Issues Encountered

Two test-authoring corrections, both caught and fixed before the relevant commit — neither reflects
a defect in shipped production code:

1. **Over-counted `GoalCard` finder.** The Goals screen behind the (still-open) picker sheet also
   renders a `GoalCard` for a newly-saved goal via its own `Consumer<GoalsNotifier>`, so an unscoped
   `find.byType(GoalCard)` found 2 widgets instead of 1 in the budget-line and emoji tests. Fixed by
   scoping to `find.descendant(of: find.byType(GoalPresetPickerSheet), matching: find.byType(GoalCard))`.
2. **Ambiguous `'Add Goal'` text finder.** `GoalFormSheet` renders the literal string `'Add Goal'`
   twice in create mode (the sheet title AND the submit button), so `find.text('Add Goal'),
   findsOneWidget` failed even without any mutation. Replaced with `'Edit Goal'`/`'Save Goal'`
   absence checks, which unambiguously distinguish create from edit mode.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `PresetChipGrid` and `kCommonGoals` are ready for 34-02 to adopt in onboarding's goals beat
  (replacing `_ChipCloud`/`_goalPresets`) and in onboarding's restoratives beat (replacing the
  private restoratives chip logic there), per D-34-07's boundary (this widget owns the preset grid
  only; "what you already have" stays per-surface).
- `test/screens/restoratives_chip_geometry_test.dart` (34-02) should confirm restoratives' shipped
  chip geometry is unchanged now that it will route through the shared widget — flagged in
  34-CONTEXT.md as a previously-unmeasured tap-target question (Item 5, Phases 32-33) that reopens if
  geometry drifts even slightly.
- No blockers. Full suite green (719 passing, up from the 706 baseline), `flutter analyze` clean.

## Self-Check: PASSED

All 7 created/modified files confirmed present on disk; all 3 task commit hashes (`026bc93`,
`c49d910`, `9f06bf5`) confirmed present in `git log`.

---
*Phase: 34-adding-a-goal-feels-like-onboarding*
*Plan: 01*
*Completed: 2026-09-08*
