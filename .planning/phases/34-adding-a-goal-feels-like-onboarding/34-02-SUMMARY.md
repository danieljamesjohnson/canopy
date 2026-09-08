---
phase: 34-adding-a-goal-feels-like-onboarding
plan: 02
subsystem: ui
tags: [flutter, provider, hive, goals, restoratives, onboarding, material3, filterchip]

requires:
  - phase: 34-adding-a-goal-feels-like-onboarding
    provides: "PresetChipGrid (createOnly/toggle), kCommonGoals, GoalsNotifier.addPresetGoal — all built in 34-01"
provides:
  - "Onboarding's two beats (goals, restoratives) render the shared PresetChipGrid instead of the private _ChipCloud, with emoji on every preset chip"
  - "A small private _AddedChipRow in onboarding_screen.dart — the surface-local 'what you already have' display D-34-07 requires alongside the shared grid"
  - "The restoratives screen's _QuickPickSection delegates to PresetChipGrid(toggle), with its rendered geometry pinned by literals measured against the pre-refactor widget"
  - "Direct widget-level test coverage for PresetChipGrid's two modes (9 tests) — the first tests that exercise the shared widget without going through a screen"
affects: [34-03-uat]

actuals:
  tokens: 6534
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "A shared grid widget owns ONLY the preset picker; each surface keeps its own private 'what you already have' display when it has no other list view for that job (D-34-07)"
    - "Geometry pinned by bare-literal Rect assertions measured against the pre-refactor widget, then re-run unchanged after the refactor — a measurement, not a claim (CLAUDE.md 'Assertions that cannot fail', trap 2)"

key-files:
  created:
    - test/screens/restoratives_chip_geometry_test.dart
    - test/widgets/preset_chip_grid_test.dart
  modified:
    - lib/screens/onboarding/onboarding_screen.dart
    - lib/screens/restoratives/restoratives_screen.dart
    - test/screens/onboarding_flow_test.dart

key-decisions:
  - "D-34-07 (plan's own ruling, honored): PresetChipGrid owns the preset grid only. Onboarding has no list view of its own, so a private _AddedChipRow (Wrap of removable InputChips, copied verbatim from the old _ChipCloud's 'added' branch) is kept in onboarding_screen.dart as the only display/removal surface for what was added this visit."
  - "D-34-08 (plan's own ruling, honored): onboarding's restoratives beat adopts kCommonRestoratives (9 items, matches the restoratives screen) instead of its own disagreeing 8-item _restorativePresets list, closing the near-duplicate defect ('Walk' in onboarding vs. 'Walk outside' on the restoratives screen)."
  - "Both onboarding beats use PresetChipMode.createOnly (not toggle) per the plan's resolution of the UI-SPEC's internal contradiction — the added-chip row already displays and removes claimed items, so toggle would render every claimed item twice."
  - "restoratives_screen.dart's _matchFor is kept (not folded into PresetChipGrid) because deletion needs an id and the shared widget deals only in names — exactly as the plan specified."

patterns-established:
  - "A geometry-pin test file (bare Rect literals, comment recording the pre-refactor measurement) is the pattern for proving 'this refactor moved zero pixels' on a screen with contested tap-target history, rather than an eyeballed diff."

requirements-completed: [GOALADD-01, GOALADD-03]

coverage:
  - id: D1
    description: "_ChipCloud/_suggestionsFor/_goalPresets/_restorativePresets are deleted outright from onboarding_screen.dart; both beats render PresetChipGrid(createOnly) with kCommonGoals/kCommonRestoratives, so every preset chip on both onboarding beats now carries an emoji."
    requirement: GOALADD-01
    verification:
      - kind: unit
        ref: "test/screens/onboarding_flow_test.dart#tapping a preset chip adds that goal"
        status: pass
      - kind: other
        ref: "grep -vE '^\\s*(//|///)' lib/screens/onboarding/onboarding_screen.dart | grep -cE '_ChipCloud|_suggestionsFor|_goalPresets|_restorativePresets' == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "A goal or restorative added during onboarding can still be removed via the added-chip row's delete affordance, on BOTH beats — the plan-checker's added acceptance criterion, closing the gap where only the goals beat had been proven."
    requirement: GOALADD-01
    verification:
      - kind: unit
        ref: "test/screens/onboarding_flow_test.dart#the added chip's delete affordance removes a goal added during onboarding (beat 1, D-34-07/T-34-05)"
        status: pass
      - kind: unit
        ref: "test/screens/onboarding_flow_test.dart#the added chip's delete affordance removes a restorative added during onboarding (beat 2, D-34-07/T-34-05)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The preset's emoji reaches the created Goal model on the onboarding path, not only on the Goals-screen path (GOALADD-03 amendment)."
    requirement: GOALADD-03
    verification:
      - kind: unit
        ref: "test/screens/onboarding_flow_test.dart#tapping a preset chip adds that goal (emojiTag assertion)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The restoratives screen's _QuickPickSection now delegates to PresetChipGrid(toggle); its seven-test behaviour file passes with zero edits, and its rendered geometry at 390x844 is pinned by literals measured against the pre-refactor widget and reconfirmed unchanged after the refactor (T-34-04)."
    verification:
      - kind: unit
        ref: "test/screens/restoratives_quick_pick_test.dart (all 7 tests, zero edits)"
        status: pass
      - kind: unit
        ref: "test/screens/restoratives_chip_geometry_test.dart#the quick-pick grid geometry at 390x844 is pinned to pre-refactor measurements"
        status: pass
    human_judgment: false
  - id: D5
    description: "PresetChipGrid's two modes (createOnly hiding/no-remove-gesture, toggle selected/removable/never-empties) and its one case-insensitive matching rule are tested directly against the widget, with finders that discriminate chip subtype rather than assuming it."
    verification:
      - kind: unit
        ref: "test/widgets/preset_chip_grid_test.dart (9 tests)"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-08
status: complete
---

# Phase 34 Plan 02: Onboarding And Restoratives Migrate Onto The Shared Chip Widget Summary

**Deleted the third private preset-chip implementation before it could exist: onboarding now renders the same `PresetChipGrid` the Goals screen uses (34-01), the restoratives screen's shipped `_QuickPickSection` now delegates to it too, and the restoratives screen's contested tap-target geometry is proven unmoved by pre/post measurement rather than by eyeballing a diff.**

## Performance

- **Duration:** 45 min (approx.)
- **Started:** 2026-09-08T13:30:00Z (approx.)
- **Completed:** 2026-09-08T14:12:19Z
- **Tasks:** 3
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments

- `lib/screens/onboarding/onboarding_screen.dart`: `_ChipCloud`, `_suggestionsFor`, `_goalPresets` and
  `_restorativePresets` are deleted outright (not left unreferenced). Both beats now render
  `PresetChipGrid(mode: PresetChipMode.createOnly, alignment: WrapAlignment.center)` — the goals beat
  with `kCommonGoals` (gaining emoji for the first time), the restoratives beat with
  `kCommonRestoratives` (D-34-08's list swap). A new private `_AddedChipRow` — a `Wrap` of removable
  `InputChip`s, copied verbatim from `_ChipCloud`'s old "added" branch — is the surviving display of
  what was added this visit, per D-34-07.
- `lib/screens/restoratives/restoratives_screen.dart`: `_QuickPickSection`'s private `Wrap`/`_buildChip`
  is replaced by `PresetChipGrid(mode: PresetChipMode.toggle, heading: 'Common')`; `_matchFor` is kept
  for the id-based `onRemove` lookup, per the plan.
- `test/screens/restoratives_chip_geometry_test.dart` (new): pins the quick-pick grid's rendered
  geometry at 390x844 to bare-literal `Rect`s measured against the real, pre-refactor
  `RestorativesScreen` — confirmed unchanged after the refactor (see Geometry Measurements below).
- `test/widgets/preset_chip_grid_test.dart` (new): 9 tests exercising `PresetChipGrid` directly in both
  modes — the first tests that don't go through a screen to reach it.
- `test/screens/onboarding_flow_test.dart`: repointed both `ActionChip` finders to `FilterChip`, added
  an `emojiTag` assertion (GOALADD-03) to the existing preset-tap test, and added two new tests proving
  the added-chip removal affordance survives the migration on BOTH onboarding beats (the plan-checker's
  added acceptance criterion — the original plan only proved the goals beat).

## Task Commits

1. **Task 1: Onboarding adopts the shared grid and gains the emoji** - `24a8f69` (feat)
2. **Task 2: The restoratives screen swaps its implementation without moving a pixel** - `91265ae` (refactor)
3. **Task 3: Test the shared widget directly, in both modes** - `42d258d` (test)

## Files Created/Modified

- `lib/screens/onboarding/onboarding_screen.dart` - deleted `_ChipCloud`/`_suggestionsFor`/preset lists; both beats render `PresetChipGrid`; new `_AddedChipRow`
- `lib/screens/restoratives/restoratives_screen.dart` - `_QuickPickSection` delegates to `PresetChipGrid(toggle)`; `_buildChip` deleted, `_matchFor` kept
- `test/screens/onboarding_flow_test.dart` - repointed `ActionChip` → `FilterChip`; added emoji + two removal-affordance tests
- `test/screens/restoratives_chip_geometry_test.dart` - new: geometry pin, bare-literal `Rect` assertions
- `test/widgets/preset_chip_grid_test.dart` - new: 9 direct tests of `PresetChipGrid`'s two modes

## Visible Changes To Onboarding — for 34-03's UAT to read from

Stated plainly per the plan and D-34-07/D-34-08, since these change a screen the owner did not
directly ask about:

1. **Preset chips change family.** The old two-tier split (`InputChip` for added items, `ActionChip`
   with a generic `+` avatar for suggestions) is gone. Presets are now a single row of `FilterChip`s
   (matching the restoratives screen's shipped look); "added" items now live in a visually distinct
   row directly above the preset grid (`_AddedChipRow`), not interleaved with suggestions in one `Wrap`.
2. **Suggestion chips lose the generic `+` avatar and gain a real emoji** on every preset, on both
   beats — the goals beat shows emoji for the first time ever.
3. **Two stacked `Wrap`s instead of one flowing `Wrap`** — the added-chip row and the preset grid are
   now visually separate blocks with a 12px gap between them (only when something has been added).
4. **The restorative preset wording changes (D-34-08).** Onboarding's old 8-item list (`Walk`, `Music`,
   `Nap`, `Nature`, `Call a friend`, `Bath`, `Stretch`, `Games`) is replaced by the restoratives
   screen's 9-item `kCommonRestoratives` (`Walk outside`, `Music`, `Nap`, `Stretch`, `Shower`, `Read`,
   `Tea or coffee`, `Call someone`, `Sit in the sun`) — one more preset, several renamed, one dropped.
5. **The restoratives screen itself is not visually intended to change at all** — see the geometry
   measurements below.

## Geometry Measurements (restoratives screen, 390x844, Task 2)

Measured via a one-time `debugPrint(tester.getRect(...))` against the real `RestorativesScreen`
(empty item list) **before** the `PresetChipGrid` refactor, then baked into
`test/screens/restoratives_chip_geometry_test.dart` as bare literals, then re-run **unchanged** after
the refactor landed:

| Rect | Pre-refactor (measured) | Post-refactor (re-run) |
|---|---|---|
| `FilterChip('Walk outside')` | `Rect.fromLTRB(16.0, 96.0, 239.2, 144.0)` | identical |
| `FilterChip('Sit in the sun')` | `top: 376.0, bottom: 424.0` | identical |
| `Wrap` ancestor | `Rect.fromLTRB(16.0, 96.0, 371.7, 424.0)` | identical |

No number moved. The `.right` values (239.2, 371.7) carry float rounding noise from text layout
(actual values like `239.1999969482422`) and are asserted with `closeTo(..., 0.01)`; all `.left`/`.top`/
`.bottom` values are asserted exactly. The mutation test below confirms these literals discriminate
rather than merely existing.

## Decisions Made

- **D-34-07 honored:** `PresetChipGrid` owns the preset grid only. Onboarding's `_AddedChipRow` is the
  surface-local "what you already have" display the plan calls for — the same job `GoalCard` does for
  the Goals screen and `_RestorativeRow` does for the restoratives screen.
- **D-34-08 honored:** onboarding's restoratives beat adopts `kCommonRestoratives` verbatim rather than
  converting `_restorativePresets` to `(name, emoji)` pairs, closing the near-duplicate defect a
  case-insensitive matcher couldn't catch (a user tapping "Walk" in onboarding would otherwise still
  see an unclaimed "Walk outside" chip on the restoratives screen).
- Both onboarding beats use `createOnly`, not `toggle`, per the plan's resolution of the UI-SPEC's
  internal contradiction between Decision 3 Axis B and Decision 5's parenthetical — the added-chip row
  already shows and removes claimed items, so `toggle` would double-render them.
- `_matchFor` stays on `restoratives_screen.dart` rather than moving into `PresetChipGrid`, because
  deletion needs an id and the shared widget deals only in names — exactly as planned.

## Deviations from Plan

**One necessary test-authoring adjustment, not a defect:** the plan's geometry-pin literals were
specified as exact doubles (e.g. `expect(firstChipRect.top, 108.0)`). The actual pre-refactor
measurement put the first chip's top at `96.0`, not `108.0` — the plan's illustrative number was just
an example (`e.g. expect(firstChipRect.top, 132.0)`), not a real measurement, and the task's own
instructions were to measure first and bake in whatever was actually observed. Additionally, two of
the four pinned values (`.right` on the first chip and the `Wrap`) came back with floating-point
rounding noise from text layout (`239.1999969482422` rather than `239.2`) and needed `closeTo(x, 0.01)`
rather than an exact literal — using an exact literal there would have made the pin permanently red for
a reason unrelated to layout drift, which would have defeated the test's purpose on day one. Both
adjustments are within the task's own instructions ("read the numbers", "bake those measured numbers
in as bare literals") and do not weaken the pin: a real layout drift still fails every one of these
assertions, as the mutation test below confirms.

No other deviations — the rest of the plan executed exactly as written.

## Mutation Tests — actual RED output recorded

Per CLAUDE.md ("Assertions that cannot fail") and this plan's own acceptance criteria, every listed
mutation was introduced, run, observed RED, and reverted (confirmed byte-identical via `git diff`
against the task's own commit).

### Task 1 — pass `emoji: null` from `_GoalsBeat`'s `onCreate`

```
Expected: '📚'
  Actual: <null>
   Which: not an <Instance of 'String'>
```
(`tapping a preset chip adds that goal`'s new `emojiTag` assertion failed as expected — GOALADD-03.)
Reverted; confirmed byte-identical via `git diff`.

### Task 2 — change `PresetChipGrid`'s `Wrap` spacing from 8 to 12

```
Expected: <376.0>
  Actual: <432.0>
```
(The geometry test's `lastChipRect.top` assertion failed as expected — the pinned literals
discriminate a real layout drift, not merely exist.) Reverted; confirmed byte-identical via `git diff`.

### Task 3, mutation 1 — drop the case-insensitive comparison from `PresetChipGrid.unclaimed`

```
Expected: no matching candidates
  Actual: _AncestorWidgetFinder:<Found 1 widget with type "FilterChip" that are ancestors of widget
with text "Reading": [FilterChip(...)]>
   Which: means one was found but none were expected
```
(The `'  reading  '` case-insensitivity test failed as expected — the "Reading" preset reappeared
because `p.$1.trim().toLowerCase()` no longer lower-cased the preset side of the comparison.) Reverted;
confirmed byte-identical via `git diff`.

### Task 3, mutation 2 — make `createOnly` render claimed presets as `selected` instead of hiding them

```
Expected: no matching candidates
  Actual: _AncestorWidgetFinder:<Found 1 widget with type "FilterChip" that are ancestors of widget
with text "Reading": [FilterChip(...)]>
   Which: means one was found but none were expected
```
(Removing both the `createOnly` filter on `visible` and the `mode == PresetChipMode.toggle` guard on
`isClaimed` made three tests go RED at once — the single-claimed-preset hiding test, the
all-claimed-empties-the-grid test, and the empty-heading test — all correctly, since all three assert
the hiding behaviour this mutation removes.) Reverted; confirmed byte-identical via `git diff`.

## Issues Encountered

None beyond the geometry-literal adjustment documented under Deviations above.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Every rendered path (onboarding's two beats, the restoratives screen) is wired to a real
notifier and a real repository; nothing here renders a hardcoded empty value or placeholder text.

## Threat Flags

None. This plan swaps widget implementations on two already-shipped screens and adds tests; it
introduces no new network endpoint, auth path, file access pattern, or schema change at a trust
boundary. T-34-04 and T-34-05 (the two threats this plan's threat register named) are both mitigated
as specified, with tests.

## Next Phase Readiness

- No private copy of the preset-chip idea remains in `lib/` — the phase's charter ("a third private
  copy is the wrong answer") is satisfied: three surfaces (Goals, onboarding x2, restoratives) all
  render the one `PresetChipGrid`.
- 34-03's UAT can read the "Visible Changes To Onboarding" list above directly rather than re-deriving
  it from a diff.
- Full suite green: **731 passing** (up from the 719 baseline at the start of 34-01, +2 from 34-01,
  +12 from this plan: 2 onboarding removal tests, 1 geometry test, 9 `PresetChipGrid` tests).
  `flutter analyze` clean throughout.
- No blockers.

## Self-Check: PASSED

All 5 created/modified files confirmed present on disk; all 3 task commit hashes (`24a8f69`,
`91265ae`, `42d258d`) confirmed present in `git log`.

---
*Phase: 34-adding-a-goal-feels-like-onboarding*
*Plan: 02*
*Completed: 2026-09-08*
