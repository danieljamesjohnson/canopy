---
phase: 33-make-the-obvious-thing-obvious
plan: 04
subsystem: goals-ui
tags: [restoratives, goals, entry-points, filter-chip, fork, mutation-tested]
status: complete

requires:
  - "33-03 — goals_screen.dart's `_openAddSheet` / FAB path, as it stands after the ranked-list rewrite"
provides:
  - "kCommonRestoratives — the nine hard-coded common restoratives"
  - "_QuickPickSection — a nine-FilterChip grid on the restoratives screen; one tap adds, one tap removes"
  - "AddKind / showAddKindFork / showRestorativeQuickAdd — the front-door fork in front of the Goals FAB"
affects:
  - "33-05 (UAT + driven evidence) — S6 and S7 are exactly the two surfaces built here; the fork and the chips are what the screenshots capture"

tech_stack:
  added: []
  patterns:
    - "FilterChip for a tappable chip vs the file-private Container badge for a display-only one — the 33-PATTERNS §5 distinction, now with a shipped example of each"
    - "A dialog body as a StatefulWidget so it owns and disposes its TextEditingControllers (adaptive_form_modal.dart's WR-01 lesson, applied to controllers read during the exit frame)"
    - "A modal fork returning Future<T?> in front of an existing entry point, rather than changing the entry point's own return type"

key_files:
  created:
    - lib/screens/goals/widgets/add_kind_fork.dart
    - test/screens/restoratives_quick_pick_test.dart
    - test/screens/goals_add_fork_test.dart
  modified:
    - lib/screens/restoratives/restoratives_screen.dart
    - lib/screens/goals/goals_screen.dart
  deleted: []

decisions:
  - "The chips use `saveItem`, not `quickAddItems` — the bulk helper sets no emoji and the chips carry one, so a chip-added item would have fallen back to the generic 🌿"
  - "Chip deselect hard-deletes with no confirmation (T-33-11, accepted); the heavier `_confirmDelete` stays on the list rows, which can hold user-typed items the chips cannot restore"
  - "The name match is case-insensitive on the trimmed name, so a hand-typed 'music' and the 'Music' chip are one thing rather than two"
  - "The restoratives body became one ListView across both states rather than an `isEmpty ? … : …` split — the grid matters MOST when the list is empty"
  - "The quick-add dialog owns its controllers in a StatefulWidget: disposing them when `showDialog`'s future resolved threw 'A TextEditingController was used after being disposed' during the route's exit transition"
  - "The fork is in front of the FAB only; the quick-add text field stays a goal-only path (narrowing carried forward from 33-03, and put to the owner in 33-05's UAT)"

metrics:
  duration_minutes: 14
  completed: 2026-09-01

actuals:
  tokens: 8736
  tasks: 3
  commits: 4
---

# Phase 33 Plan 04: Restoratives Are A Tap, And Not Everything Is A Goal Summary

Nine common restoratives now cost one tap each instead of nine round trips through a dialog, and the
Goals FAB asks which kind of thing you are adding *before* any form exists — so "guitar energizes me"
no longer forces guitar to acquire a type, a weekly budget and a priority.

## What was built

**`restoratives_screen.dart`** — `kCommonRestoratives`, the nine names verbatim from sketch 005, with
a doc comment stating out loud that the list is hard-coded and stays that way (no suggestion engine,
no ranking, no LLM — `CLAUDE.md`'s dumb-on-purpose position, UI-SPEC item 23). Above them,
`_QuickPickSection`: a `Wrap` of nine `FilterChip`s, each `avatar: Text(emoji)` + `label: Text(name)`,
glyph **plus** word. Selecting saves a `RestorativeItem` carrying the chip's emoji; deselecting
deletes it, with no confirmation. The body became a single `ListView` so the grid renders in the
empty state too — the case the FAB-and-dialog flow made expensive. The `Align(topCenter)` +
`ConstrainedBox(maxWidth: 720)` wrapper, the AppBar, the FAB, `_openEditDialog`, `_submit`,
`_confirmDelete` and `_RestorativeRow` are untouched.

**`add_kind_fork.dart`** (new) — `AddKind`, `showAddKindFork` and `showRestorativeQuickAdd`. The fork
is an `AlertDialog` titled `What are you adding?` over two `Card`-framed door tiles, each stating its
own consequence in one line (UI-SPEC item 27):

| door | consequence line |
|---|---|
| `Something to make time for` | `Gets a type, a weekly budget and a priority. Canopy schedules it.` |
| `Something that restores you` | `Never scheduled. Never counted toward a budget or a streak.` |

The second door leads to a name + optional-emoji dialog and nothing else. No goal form is constructed
on that path at any point.

**`goals_screen.dart`** — `_openAddSheet` is now `async` and asks first. `_openEditSheet` is
byte-identical: editing an existing goal has already answered the question.

| Grep | Expected | Actual |
|---|---|---|
| `kCommonRestoratives` in `restoratives_screen.dart` | ≥ 2 | 2 |
| entries in the const | 9 | 9 |
| `FilterChip` in `restoratives_screen.dart` | ≥ 1 | 2 |
| `ConstrainedBox` in `restoratives_screen.dart` | 1 | 1 — the 720dp wrapper survives |
| `Something to make time for` / `Something that restores you` / `Never scheduled` | 1 each | 1, 1, 1 |
| `showAddKindFork` in `goals_screen.dart` | 1 | 1 — one entry point, not two |
| `EnergyValence` in `add_kind_fork.dart` | 0 | 0 — no fourth valence option anywhere |
| `GoalFormSheet` in `goals_add_fork_test.dart` | ≥ 3 | 9 |
| `testWidgets(` in the two new files | ≥ 7 / ≥ 5 | 8 / 6 |

The fences held. `git diff --name-only 1c95ea0..HEAD` is exactly five files — `goals_screen.dart`,
`add_kind_fork.dart`, `restoratives_screen.dart` and the two new test files. No
`goal_form_sheet.dart`, no `onboarding_screen.dart`, no `restorative_item.dart`, no `*.g.dart`, no
`schedule_generator.dart`, no `pubspec.yaml`. No new Hive type, no adapter, no migration.

## Nine assertions were proven able to fail, not assumed

`CLAUDE.md`'s "Assertions that cannot fail" section says a compile error is a weak form of red. Every
load-bearing assertion here was mutation-tested against a real defect and then reverted, and
`git diff --stat` was checked clean afterwards so no mutation survived into a commit.

**On the chips** (`restoratives_quick_pick_test.dart`):

| Mutation | Result |
|---|---|
| rows never render (`if (notifier.isEmpty \|\| true)`) | 1 RED — "the item is listed" |
| deselect calls `saveItem(match)` instead of `deleteItem(match.id)` | 1 RED — the remove case |
| name match becomes case-sensitive | 1 RED — the already-saved case |
| `avatar: Text(emoji)` + `label: Text(name)` collapsed to `label: Text(emoji)` | 6 RED — including item 30 |
| chip saves without `emojiTag` | 1 RED — the emoji case |

The first of those matters most. "The item appears in the list below" was **first written** as
`find.text('Walk outside') → findsNWidgets(2)`, which passes for the wrong reason: the chip's own
label is one of the two, so the assertion is partly satisfied by the thing it is not testing. It is
scoped to a `Card` descendant now, and the mutation above is what proves the scoping did something.

The one deliberate no-op: mutating the deselect branch to `else if (match == null)` produced a
compile error rather than a failing assertion (a null-safety error on `match.id`). That is the weak
red `CLAUDE.md` warns about, so it was re-run as `saveItem(match)` — a mutation that compiles, runs,
and leaves the item present — before the assertion was trusted.

**On the fork** (`goals_add_fork_test.dart`):

| Mutation | Result |
|---|---|
| restorative door falls through to `showAdaptiveFormModal` | 1 RED — the T-33-12 test |
| no fork at all; the FAB goes straight to the goal form | 4 RED (test 5, the edit path, correctly stays green) |
| `GoalCard.onTap` routed through `_openAddSheet`, i.e. the edit path forks | 1 RED — the edit-path test |
| the restorative door's consequence line watered down to `Not a goal.` | 1 RED — the item-27 test |

## A real defect, found by the tests before anyone saw it

`showRestorativeQuickAdd` was first written the way the plan describes it — controllers created in
the function, disposed in a `finally` after `await showDialog`. It threw on every run:

```
A TextEditingController was used after being disposed.
Once you have called dispose() on a TextEditingController, it can no longer be used.
```

`showDialog`'s future resolves the moment `Navigator.pop` is called, while the route is still running
its exit transition and still rebuilding the text fields. Disposing there is too early. This is the
same lesson `adaptive_form_modal.dart:55-67` already records for its `ScrollController` (WR-01), so
the fix is that pattern applied here: a file-private `_RestorativeQuickAddDialog` `StatefulWidget`
that owns both controllers and disposes them in `dispose()`, i.e. when the route is actually gone.
The provider, messenger and navigator refs are captured before the `await` (Pitfall 6), since the
route is popped mid-method.

Worth stating plainly: the plan's own instruction ("Dispose both `TextEditingController`s") was
correct about the requirement and wrong about the mechanism, and only running the test surfaced it.
`restoratives_screen.dart`'s existing `_openEditDialog` sidesteps this by never disposing at all —
it leaks two controllers per open. That is pre-existing and out of scope here (logged below), but it
is why the plan's shape looked like the local convention.

## Deviations from Plan

**1. [Rule 1 — Bug] The quick-add dialog's controller lifecycle**

- **Found during:** Task 3, on the first run of `goals_add_fork_test.dart`
- **Issue:** disposing the controllers when `showDialog`'s future resolved threw
  `A TextEditingController was used after being disposed` during the route's exit transition, which
  cascaded into a `_FocusInheritedScope` build-scope assertion and failed three of the five tests.
- **Fix:** moved the dialog body into a file-private `StatefulWidget` that owns and disposes both
  controllers, per `adaptive_form_modal.dart`'s WR-01 precedent.
- **Files modified:** `lib/screens/goals/widgets/add_kind_fork.dart`
- **Commit:** `d5a3ee4`

**2. [Rule 2 — Missing coverage] Phone-width cases on both new surfaces**

- **Found during:** Task 3 review
- **Issue:** the 800×600 default test viewport is wide enough to hide a layout defect the owner meets
  first on a phone, and below the 720dp breakpoint the goal door takes the **bottom-sheet** path
  rather than the dialog path — a whole branch nothing asserted. In a phase whose entire subject is
  what a screen looks like, that gap is the Phase-32 failure mode in miniature.
- **Fix:** one 390×844 case added to each new file (8 and 6 cases now, both still above the plan's
  floor of 7 and 5).
- **Files modified:** both new test files
- **Commit:** `46d9e21`

## Scope notes, surfaced rather than buried

**The fork is in front of the FAB only.** The quick-add text field above the Goals list stays a
goal-only path. That is deliberate and was accepted before this plan started; it is recorded in
`_openAddSheet`'s own doc comment so a future reader does not treat it as an oversight, and 33-05's
UAT asks the owner to rule on it. It was neither silently widened nor silently dropped.

**`drive.cjs --tap` is not in this plan.** The orchestrator's brief listed it under "what this plan
delivers", but `33-04-PLAN.md` has three tasks and none of them touch `drive.cjs`, and
`33-05-PLAN.md` carries it in its **own** `must_haves.artifacts` and adds it in its own Task 2
("`--tap` already exists — Task 2 added it, because seeding the fixture needed it first"). Building
it here would have duplicated 33-05's work against a tool this plan never invokes. Flagged rather
than quietly skipped, because 33-05 depends on it existing.

**Pre-existing, not fixed (out of scope):** `restoratives_screen.dart`'s `_openEditDialog` creates
two `TextEditingController`s per open and never disposes them. It is the same defect class as
deviation 1 and the same fix would apply, but it is untouched by this plan's files-modified contract
and fixing it would have meant editing a method the plan explicitly says to keep unchanged.

## Verification

- `flutter analyze` — clean across the repo.
- `flutter test` — **678 passing**, up from the 664 baseline: +14 (8 chips, 6 fork). No test was
  changed or retired; `goal_form_valence_test.dart` and `onboarding_flow_test.dart` pass untouched,
  which is what proves the two `EnergyValence` controls were not disturbed.
- `content_width_constraint_test.dart` passes — the 720dp wrapper survived the body restructure.
- The nine names match sketch 005 verbatim, in order.

## Threat mitigations

| ID | Disposition | Status |
|---|---|---|
| T-33-11 | accept | One-tap delete ships with no confirmation, as specified. The heavier `_confirmDelete` is retained on the list rows. |
| T-33-12 | **mitigate** | Pinned by `goals_add_fork_test.dart` case 3, which asserts `GoalFormSheet` never mounts **and** `goalsNotifier.goals` stays empty. Mutation-proven: routing the door to `showAdaptiveFormModal` turns it RED. |
| T-33-13 | accept | `maxLength: 2` on the emoji field, matching the existing dialog. |
| T-33-14 | accept | No packages installed; `pubspec.yaml` untouched. |

No new threat surface. Nothing crosses a network boundary, touches auth, reads a file, or changes a
schema.

## Known Stubs

None. The nine hard-coded restoratives are a recorded charter (UI-SPEC item 23), not a placeholder —
there is no future plan that "wires them up", and doing so would violate the product position.

## A note on the `actuals.tokens` scale

Recorded as `chars/4` over the realized diff (`git diff 1c95ea0..HEAD -- lib test | wc -c` = 34,945
→ 8,736), which is the documented method. **This phase's four plans have not all used that method:**
33-01 recorded 7,438 (consistent with it), while 33-03 recorded 71,000 for a ~1,900-line change whose
diff is nowhere near 284,000 characters. Do not read 8,736 against 33-03's 71,000 as a 8× efficiency
gain — it is two different rulers. Flagged here rather than silently inflating this number to match,
because a flattering figure corrupts every later projection.

## State updates

Deliberately **not** performed by this executor, per the orchestrator's instruction: `STATE.md` and
`ROADMAP.md` are untouched and no `gsd-tools` state/phase write verb was run (those verbs have a
known data-loss bug on a `STATE.md` shaped like this one). The orchestrator owns phase-level state
after the wave. `.planning/REQUIREMENTS.md` does not exist in this project, so there was nothing to
mark for OBVIOUS-03.

## Self-Check: PASSED

Files asserted present:

- `lib/screens/goals/widgets/add_kind_fork.dart` — FOUND
- `lib/screens/restoratives/restoratives_screen.dart` — FOUND
- `lib/screens/goals/goals_screen.dart` — FOUND
- `test/screens/restoratives_quick_pick_test.dart` — FOUND
- `test/screens/goals_add_fork_test.dart` — FOUND

Commits asserted present: `e2a2b2e`, `58ba58a`, `d5a3ee4`, `46d9e21` — all FOUND in `git log`.
