# JTBD loop — converged (waiting for Dan)

**Job:** Capture what restores me separately from goals — add restorative
things (not goals) that only surface on low-energy days, and flag a goal that
also energizes me.
**Verdict:** ✓ converged — unanimous 4/4 adversarial jury, 0 objections. (2026-07-01)

The lane is left **waiting** (not retired), per instruction.

## What shipped (cycle 1, analyze-clean, 316 tests)

- `8fc03ec` **RestorativeItem** aggregate (Hive typeId 7, schema 8→9) kept
  deliberately separate from goals: never scheduled, never counted toward goal
  budgets/streaks, never in the Goals list.
  - Model + repo (interface/hive/in-memory) + `RestorativesNotifier`, wired
    into `main.dart` bootstrap + MultiProvider.
  - Management screen at **Goals → "What restores you"** (`/restoratives`):
    add/edit/remove a restorative with an optional emoji.
  - **Surfacing on low-energy days**: the Today screen shows restoratives as
    gentle chips when mood ≤ 2; a soft prompt links to set some up when empty.
  - The complementary half — **flag a goal that also energizes you** — already
    existed via `EnergyValence.gives` on `Goal` (editable in the goal form,
    protected by the schedule generator on low-mood days).
  - migration 8→9 (new empty box); schema-pin test → 9; new
    `restorative_item_test.dart` (Hive round-trip + notifier CRUD + sortOrder).

## Backlog — fidelity enhancements (not blockers; job is complete)

None block the outcome. Possible future polish:

1. **Reorder restoratives** — sortOrder is stored and honored, but there's no
   drag-to-reorder in the management screen yet (new items append).
2. **Restoratives in onboarding** — Screen 4 ("What gives you energy?") only
   flags goals as `gives`; it could also invite a first restorative or two.
3. **Surface threshold** — restoratives currently surface at mood ≤ 2 (same as
   the generator's `isLowMood`). If "low-energy" should also include a lighter
   day at mood 3, revisit the `mood <= 2` guard in schedule_screen.
