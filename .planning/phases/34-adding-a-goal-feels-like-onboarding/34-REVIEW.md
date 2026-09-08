---
phase: 34-adding-a-goal-feels-like-onboarding
reviewed: 2026-09-08T00:00:00Z
depth: deep
files_reviewed: 11
files_reviewed_list:
  - lib/widgets/preset_chip_grid.dart
  - lib/screens/goals/widgets/goal_preset_picker_sheet.dart
  - lib/providers/goals_notifier.dart
  - lib/screens/goals/goals_screen.dart
  - lib/screens/onboarding/onboarding_screen.dart
  - lib/screens/restoratives/restoratives_screen.dart
  - test/screens/goals/goal_preset_picker_test.dart
  - test/widgets/preset_chip_grid_test.dart
  - test/screens/restoratives_chip_geometry_test.dart
  - test/screens/goals_add_fork_test.dart
  - test/screens/onboarding_flow_test.dart
findings:
  critical: 0
  warning: 5
  info: 2
  total: 7
status: findings_found
---

# Phase 34: Code Review Report

**Reviewed:** 2026-09-08
**Depth:** deep (cross-file, plus two reproductions run against the live code)
**Files Reviewed:** 11
**Status:** findings_found

## Summary

This is solid, carefully-documented work, and the two things the phase's own risk register worried
about most — ruling (a)'s "one tap creates, nothing interrupts" invariant, and the optimistic-UI
failure path (chip removed synchronously, restored on a failed write, `mounted` checked before every
post-await `context` use) — are both implemented correctly. I traced the failure path for a
`BuildContext`-across-`await` bug, a `setState`-after-dispose bug, and a `ScaffoldMessenger` lookup on
a popped context, and found none of the three; the `mounted` guard is present and correctly placed on
both the success and failure branches. The "assertions that cannot fail" test-authoring traps this
project has been bitten by before (`find.byType` on chip subclasses, tight-vs-loose constraint
harnesses, symbolic budget assertions) are all deliberately avoided in the new tests, and the
mutation-test claims in both plan summaries hold up on inspection — I re-ran the full new test suite
and it is green as claimed, and spot-checked the discriminating power of the load-bearing finders.

The defect I did find is real and reproducible: **the double-tap race the Goals-screen picker sheet
was built to close in this same phase was never carried over to the two onboarding beats that share
the underlying `addPresetGoal`/`PresetChipGrid` machinery.** I reproduced it directly against
`GoalsNotifier` (below) — a fast double-tap on the same onboarding preset chip creates two goals with
the identical name, silently. This is not a new regression (the pre-refactor `_ChipCloud` had the
identical gap), but the phase explicitly invented and shipped the fix for this exact race one screen
over, and the migration didn't ask "does the surface I'm moving onto this shared widget need the same
guard" — so the inconsistency is new even though the underlying gap is not. A second, milder version
of the same root cause (state read before an `await` resolves) causes two *different* presets tapped
in quick succession to collide on `sortOrder`/auto-assigned color, which I also reproduced. Both are
WARNING-level, not BLOCKER-level: no crash, no data loss, and the user can recover by archiving the
duplicate, but they are the kind of "you didn't ask for a second Reading" defect this project's
CLAUDE.md explicitly treats as the class worth catching.

Everything else is minor: a latent-but-currently-unreachable state-lifecycle inconsistency, an
accessibility semantic downgrade from `ActionChip` to `FilterChip` for a one-way create action, and
a couple of maintainability nits. No product-position violations — both `kCommonGoals` and
`kCommonRestoratives` are plain hard-coded `const` lists with zero dynamic derivation, matching
CLAUDE.md's "dumb app on purpose" charter. No security-relevant findings (no injection surface, no
secrets, no dynamic code execution — this is a local-storage Flutter UI change).

## Warnings

### WR-01: Onboarding's preset chips have no double-tap guard — a fast double-tap creates two identical goals/restoratives

**File:** `lib/screens/onboarding/onboarding_screen.dart:183-190` (goals beat) and `:261-273`
(restoratives beat)
**Issue:** `GoalPresetPickerSheet` (`goal_preset_picker_sheet.dart:56-104`) closes the double-tap race
with an optimistic `_claiming` set that hides a tapped chip in the same frame, before its `await
notifier.addPresetGoal(...)` resolves — this is UI-SPEC Decision 4 and it is correctly built and
mutation-tested in 34-01. Onboarding's `_GoalsBeat`/`_RestorativesBeat` wire the *same* `PresetChipGrid`
directly to `goalsNotifier.addPresetGoal(...)` / `notifier.saveItem(...)` with **no equivalent
claiming state**. Their `existingNames` comes straight from `notifier.goals`/`notifier.items`, which
does not update until `loadGoals()`'s `notifyListeners()` fires *after* the repository write
completes. Between the tap and that resolution, the chip is still visible and still unclaimed, so a
second tap (a real double-tap, or two taps a Hive-write's worth of milliseconds apart) fires a second
`addPresetGoal('Reading', ...)` before the first has landed.

I reproduced this directly against `GoalsNotifier` with a 20ms-delayed fake repository (mirroring the
delay the phase's own `_SlowSaveGoalRepository` test fixture uses) — two concurrent
`addPresetGoal('Reading', emoji: '📚')` calls produced **two goals both named "Reading"**:
```
goals count = 2: [Reading, Reading]
```
This is not a new regression — the pre-refactor `_ChipCloud`'s `onAdd: (name) =>
goalsNotifier.quickAddGoals([name])` had the identical gap — but the phase built and shipped the fix
for exactly this race one screen over in the same set of commits, and 34-02's migration onto the
shared widget did not ask whether the surface it was moving needed the same guard. The result is that
the two live call sites of the "one preset, one goal" idiom now disagree on race-safety with no note
in either plan's threat register.
**Fix:** Either (a) give `_GoalsBeat`/`_RestorativesBeat` their own `_claiming`-style optimistic set
the same shape as `GoalPresetPickerSheet`'s, or (b) hoist the claiming behavior into `PresetChipGrid`
itself (a `Set<String> _pending` alongside `existingNames`, cleared via a callback the create future
resolves) so every current and future caller gets the guard for free rather than needing to
remember to reimplement it.

### WR-02: Two different presets tapped before either save resolves can collide on `sortOrder` and `autoColor()`

**File:** `lib/providers/goals_notifier.dart:138-160` (`addPresetGoal`)
**Issue:** `nextSort` and (for the onboarding path) the color chosen elsewhere via `autoColor()` are
both computed by reading `_goals` synchronously at the top of `addPresetGoal`, before the `await
_repository.save(goal)` that follows. Two separate calls to `addPresetGoal` — e.g. tapping "Reading"
then immediately tapping "Exercise" in the Goals-screen picker, which is explicitly allowed since
`_claiming` only suppresses the *same* chip — both read the same stale `_goals` state if the first
call's repository write and subsequent `loadGoals()` haven't completed yet. I reproduced this against
`GoalsNotifier` with a 20ms-delayed fake repository:
```
sortOrder1=0 sortOrder2=0 color1=#4CAF50 color2=#4CAF50
```
Both new goals land with an identical `sortOrder` (and identical auto-assigned color). This defeats
the tie-break `goals_screen.dart:223-236` deliberately added — its own comment states Dart's
`List.sort` is "not documented as stable," and that comment is the whole reason the `sortOrder`
tie-break exists after the `priorityWeight` tie. With two goals sharing both a null `priorityWeight`
(0.5) and an identical `sortOrder`, the tie-break itself ties, and the two goals' relative order in
"Priority order" can shuffle between rebuilds — the exact class of legibility defect the surrounding
comment says it exists to prevent.
**Fix:** Compute `nextSort` (and the color index) from a value that's stable across concurrent calls —
e.g. track a `_nextSortOrder` counter on the notifier that's incremented synchronously at call time
rather than derived from `_goals.length`/`max` each time, or serialize preset-goal creation through a
short-lived queue.

### WR-03: `_claiming` is documented as transient but is never cleared on the success path

**File:** `lib/screens/goals/widgets/goal_preset_picker_sheet.dart:58-62, 77-104`
**Issue:** The doc comment on `_claiming` (lines 58-61) describes it as tracking "a tap whose save has
not resolved yet." `_onCreate` adds to it synchronously before the `await`, and removes from it **only
on the failure branch** (`setState(() => _claiming.remove(...))` inside the `else`). On success, the
name stays in `_claiming` for the remaining lifetime of the sheet's `State` object. Today this is
inert — the goal now exists in `notifier.goals` too, so the chip stays correctly hidden regardless —
and every path that could remove a just-created goal (tap the "Just Added" row → edit form → Archive)
first pops the picker sheet, discarding its `State` before the archive could matter. But the
implementation no longer matches its own contract, and the next feature that adds an in-sheet way to
undo/archive a just-created goal *without* dismissing the sheet first (a small, plausible addition)
would silently and permanently hide that preset's chip for the rest of the sheet's life, even though
the goal it once mapped to no longer exists.
**Fix:** Remove the name from `_claiming` in the success branch too (immediately, or once `loadGoals()`
completes) so the set's actual behavior matches its doc comment — belt-and-braces, since
`notifier.goals` alone should already suffice for hiding a genuinely-existing goal's chip.

### WR-04: Preset chips lose actionable semantics for assistive technology in `createOnly` mode

**File:** `lib/widgets/preset_chip_grid.dart:96-112`
**Issue:** Every preset — including in `createOnly` mode, where tapping performs a one-way, immediate,
irreversible create (the chip then vanishes) — renders as a `FilterChip` with `selected: false`
(`_buildChip`, `isClaimed` is hard-wired false whenever `mode != toggle`). To TalkBack/VoiceOver a
`FilterChip` announces with toggle/checkbox semantics ("not selected, double tap to toggle"), which
does not describe what actually happens on tap. Before this phase, onboarding used `ActionChip` for
exactly this create-only interaction (button semantics — matches the action). The migration to a
single shared `FilterChip` family (matching the restoratives screen's shipped look) is a deliberate,
documented visual choice in 34-02's summary, but the accessibility-semantics cost of that choice isn't
called out anywhere in the phase's threat register or UAT plan.
**Fix:** Either accept this as a known, explicit trade-off (state it in the phase's threat register so
it isn't rediscovered later as a "regression"), or give `createOnly` chips a `Semantics(button: true,
...)` wrapper that overrides the default checkable announcement to describe the actual one-way create
action.

### WR-05: Onboarding now depends on two unrelated feature screens purely for shared constants

**File:** `lib/screens/onboarding/onboarding_screen.dart:16-17`
**Issue:** `kCommonGoals` and `kCommonRestoratives` are each defined inside a screen-owned file
(`screens/goals/widgets/goal_preset_picker_sheet.dart` and `screens/restoratives/restoratives_screen.dart`
respectively) and onboarding reaches them via two separate `show` imports of those screens' own files.
This was left to "Claude's discretion" per 34-CONTEXT.md and isn't a bug, but it does mean onboarding —
conceptually the most "neutral" screen in the app — now has a compile-time dependency on two unrelated
feature screens' files just to read a constant list, rather than depending on `preset_chip_grid.dart`
(the widget these constants exist to feed) or a small shared constants module.
**Fix:** Consider relocating `kCommonGoals`/`kCommonRestoratives` next to `PresetChipGrid` in
`lib/widgets/preset_chip_grid.dart` (or a sibling `preset_lists.dart`), so all three consuming screens
depend on the shared widget's module rather than on each other's screen files. Low priority — purely a
dependency-direction nit, not a functional issue.

## Info

### IN-01: `_InMemoryGoalRepository` is duplicated verbatim across two test files

**File:** `test/screens/goals/goal_preset_picker_test.dart:35-51` and
`test/screens/goals_add_fork_test.dart:36-52`
**Issue:** Both files define an identical `_InMemoryGoalRepository` (the comment in
`goal_preset_picker_test.dart` even says "Mirrors `test/screens/goals_add_fork_test.dart`'s fake
exactly"). Harmless, but it's now the third or fourth in-memory `GoalRepository` fake in the test
suite (a couple more already existed pre-phase), and each copy is one more place a future repository
interface change has to be updated in sync.
**Fix:** Hoist a shared `InMemoryGoalRepository` fake (parallel to
`data/repositories/in_memory_restorative_item_repository.dart`, which already exists and is used by
these same tests for `RestorativesNotifier`) into `lib/data/repositories/` or a shared
`test/test_helpers/` fake, and have both files import it.

### IN-02: `PresetChipGrid.unclaimed(...)` is computed twice per build in the picker sheet

**File:** `lib/screens/goals/widgets/goal_preset_picker_sheet.dart:151-163`
**Issue:** `unclaimed(kCommonGoals, existingNames)` is computed once inside `PresetChipGrid.build()`
and a second time, redundantly, in the sheet's own build method just to decide whether to render the
16px spacer after the grid. Purely a readability/duplication nit — performance is explicitly out of
scope for this review, and the list is 8 items, but the two computations can drift if one call site's
`existingNames` is ever edited without the other.
**Fix:** Have `PresetChipGrid` expose whether it rendered anything (e.g. return a bool from a
`ValueListenableBuilder`-free helper, or let the caller pass the pre-computed `unclaimed(...)` list
directly as `presets` and skip the internal recomputation) so there's one source of the "is this
section empty" answer.

## What I checked and found correct (stated for completeness, not padding)

- **Ruling (a):** tapping a preset chip creates the goal with no confirmation dialog, no pre-create
  form, and no intermediate sheet — traced end to end in `_onCreate`/`_buildChip`/`onSelected`, and
  confirmed by the mutation test that reverts `_openAddSheet` to build `GoalFormSheet` directly.
- **Optimistic-UI failure path:** the chip is removed synchronously before the `await`; on failure the
  chip is restored, no "Just added" card is added (the card is only ever built from the notifier's
  returned `Goal`, so there is nothing to roll back), and the exact existing `'Could not save goal.
  Please try again.'` copy is shown. `mounted` is checked immediately after the `await` and before any
  further `context` use on both branches — no `BuildContext`-across-`await` bug, no
  `setState`-after-dispose, and `ScaffoldMessenger.of(context)` is called with the same pattern
  `goal_form_sheet.dart` already uses successfully.
- **Product position:** `kCommonGoals`/`kCommonRestoratives` are plain `const` lists; nothing in this
  diff calls an LLM, ranks by frequency/recency, or personalizes the preset list in any way.
- **Test-authoring traps:** the new tests scope every chip finder to avoid `find.byType` over-counting
  across the three surfaces sharing `PresetChipGrid`, use `find.byWidgetPredicate` where "any chip
  subtype" is meant, read rendered `'3.0 hrs/week'`/`'📚'` text rather than the model's own fields for
  the GOALADD-03 assertions (per its explicit amendment), and the one delayed-fake-repo test
  (`_SlowSaveGoalRepository`, 50ms) genuinely holds the async gap open across exactly one `pump()` — I
  confirmed the full new/changed test files still pass (23/23 in the three most load-bearing files).
- **Regression risk in the two migrated screens:** onboarding's `_AddedChipRow` (D-34-07) correctly
  preserves see-and-remove for both beats, and the restoratives screen's `_matchFor`-based id lookup is
  untouched and still id-based, not name-based, for deletion.

---

## Fixes Applied

**Fixed at:** 2026-09-08
**flutter analyze:** clean (no issues found)
**flutter test:** 740/740 passing (731 baseline + 9 new regression tests)

### WR-01 — fixed (two commits)

Fixed at the shared source, not per-surface, per the review's own suggested design:

- `lib/providers/goals_notifier.dart` — `addPresetGoal` gained a synchronous
  `_pendingPresetNames` guard: a second, concurrent call for the identical
  trimmed-lowercase name is now a no-op (returns `null`), while the FIRST tap
  still creates immediately with nothing gating or delaying it (ruling (a)
  untouched). This is the one method both the Goals-screen picker sheet and
  onboarding's goals beat call through, so one change protects both callers.
  Commit `d54d98b`.
- `lib/providers/restoratives_notifier.dart` — the review's WR-01 title and
  reproduction named onboarding's restoratives beat too, even though the
  numeric reproduction was goals-only. Added `addPresetItem`, mirroring the
  same guard exactly, and switched both existing ad hoc callers (onboarding's
  restoratives beat, and `restoratives_screen.dart`'s `_QuickPickSection`,
  which had the identical latent gap even though it predates this phase) onto
  it, so the restoratives side is closed too rather than left as a named-but-
  unfixed gap. Commit `2d176c2`.

Both changes are covered by new unit tests that reuse the reviewer's own
technique (a 20ms-delayed fake repository, not a widget-level test, since a
`pumpAndSettle` cannot hold the async gap open) —
`test/providers/goals_notifier_preset_race_test.dart` and
`test/providers/restoratives_notifier_preset_race_test.dart`. Each guard was
mutation-tested by hand: temporarily disabling it reproduced the exact RED
the review describes (2 goals both named "Reading"; 2 restoratives both
named "Nap"), then restoring the guard turned it GREEN again.

**Why not hoisted into `PresetChipGrid` itself** (the review's option (b)):
doing so would require changing `onCreate`'s signature from
`void Function(String, String)` to `Future<void> Function(String, String)` so
the grid could await completion and clear its own pending set — a change
that ripples into every test call site across
`test/widgets/preset_chip_grid_test.dart` (9 synchronous no-op closures) for
a benefit (defending direct notifier callers, e.g. a future MCP-server edge
per CLAUDE.md) that the notifier-level fix already delivers with a smaller,
more localized diff. The notifier-level fix also matches the reviewer's own
reproduction method exactly (called the notifier directly, not through the
widget), so it protects the actual code path that was measured.

### WR-02 — fixed

`lib/providers/goals_notifier.dart` — `addPresetGoal`'s `nextSort`/color
computation now reserves synchronously, offset by however many OTHER
`addPresetGoal` calls are already in flight for a different name, so two
different presets tapped before either save resolves can no longer read the
same stale `_goals` snapshot and collide. Same commit as WR-01's goals fix
(`d54d98b`) — both guards live in the same synchronous block for the same
reason (one in-flight-call bookkeeping set backs both). Covered by the same
test file, mutation-tested the same way (disabling the offset reproduced the
review's exact symptom: two goals with identical `sortOrder` and identical
auto-assigned `color`).

### WR-03 — fixed, cheap and safe, no new test

`lib/screens/goals/widgets/goal_preset_picker_sheet.dart` — `_claiming` is
now cleared in `_onCreate`'s success branch too, not only on failure, so its
actual behavior matches its own doc comment ("a tap whose save has not
resolved yet"). Commit `3c2b188`. No regression test accompanies this: there
is currently no code path that can observe the difference (every existing
route back to a claimed preset pops the sheet first, discarding its
`State`), so there is no behavior to assert against today — this is a
belt-and-braces contract fix, not a defect with a reproducible symptom yet.

### WR-04 — no change, judged as intended per UI-SPEC Decision 3

`34-UI-SPEC.md`'s "Decision 3, Axis A" explicitly and deliberately resolves
the `createOnly` chip family as a single-`FilterChip` shape ("the shared
widget follows `_QuickPickSection`'s single-`FilterChip`-family shape...
never a second visual family"), stating the visible consequence in detail.
The accessibility-semantics cost WR-04 identifies (a `FilterChip` announcing
toggle/checkbox semantics for what is actually a one-way create action) is a
real, uncalled-out cost of that documented decision, not an independent bug
— and the fix instructions for this pass explicitly prohibit changing the
ruled visual/semantic design. Recording it here, per the review's own
"accept as known trade-off, state it" option: **a `createOnly`-mode preset
chip's accessibility announcement does not describe its one-way,
irreversible create action** — a future accessibility pass should consider a
`Semantics(button: true, ...)` wrapper, but that is a new design decision,
not a defect fix, and is out of scope for this review-fix pass.

### WR-05 — no change, deferred as a non-functional nit

Reviewed the suggested relocation of `kCommonGoals`/`kCommonRestoratives`
next to `PresetChipGrid`. The review itself marks this "Low priority —
purely a dependency-direction nit, not a functional issue," and the actual
blast radius is larger than the finding implies: both constants are
re-exported via `show` clauses that several test files import from their
current locations (e.g.
`import 'package:canopy/screens/goals/widgets/goal_preset_picker_sheet.dart'
show kCommonGoals;`), so relocating them would touch import statements across
multiple test files for a change with zero behavioral effect. Deferred rather
than fixed — the dependency-direction cost the review names is real but small
and worth batching with a future touch of these files rather than justifying
its own commit and test-file churn now.

### IN-01, IN-02 — out of scope for this pass

This fix pass was scoped explicitly to WR-01 through WR-05 by the task that
launched it; neither Info finding (duplicated `_InMemoryGoalRepository` fake
across two test files; the double computation of
`PresetChipGrid.unclaimed(...)` in the picker sheet) was in scope, so both
were left untouched.

---

_Reviewed: 2026-09-08_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
_Fixed: 2026-09-08_
_Fixer: Claude (gsd-code-fixer)_
