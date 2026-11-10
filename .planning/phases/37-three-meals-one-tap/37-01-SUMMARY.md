---
phase: 37-three-meals-one-tap
plan: 01
status: complete
commits: [10647ab]
requirements: [MEAL-03, MEAL-04]
---

# 37-01 Summary — meals in the model and the engine

**Shipped in `10647ab`.**

- `CommitmentBlock.kind` is **HiveField(9)**, a nullable `String?` with values `breakfast`, `lunch`
  and `dinner`. Before using it I confirmed it was free: fields 0–8 were in use, and the old
  generated adapter wrote exactly 9. The adapter was regenerated with build_runner. There was **no
  schema bump and no migration**. Because the field is nullable, a record written before Phase 37
  reads back with `kind == null`, which `test/data/commitment_block_kind_test.dart` proves against
  real pre-37 9-field bytes.
- `ChunkType.meal` was **appended** at index 3, so the persisted indices 0–2 do not move.
- `lib/utils/meals.dart` holds `MealSlot` (labels, emoji and default times), `MealDraft`,
  `kMinMealMinutes = 10` and `kAllWeekdays`.
- `ScheduleGeneratorService`:
  - `buildCommitmentChunks` has a meal branch. A meal becomes one `ChunkType.meal` chunk for each
    piece of its window that `subtractWindows(yieldTo)` leaves, and pieces under 10 minutes are
    dropped.
  - New helpers: `mealWindowsOn` and `yieldWindowsFor`. A meal yields to meetings only. A
    hand-entered block yields to meetings and meals. A calendar block yields to nothing.
  - `generate()` uses them.
- `ScheduleNotifier._yieldCommitmentsToMeetings` now also rebuilds a meal that a synced meeting
  carves, and makes Work yield to meals on that path too.
- `CommitmentsNotifier.saveMeals(drafts)` upserts one block per switched-on meal, keyed by `kind`,
  on all seven days. It deletes a meal that is switched off and never touches ordinary
  commitments. There is also a `mealBlocks` getter.
- The only change to `ChunkCard` was the meal card needed so the exhaustive `switch` compiles; the
  rest of the UI is in 37-02. `test/services/schedule_generator_test.dart` got the matching
  `case ChunkType.meal` in its lattice switch.

## The riskiest assumption: proven

A 7:00–7:30 breakfast survives `generate()` and is the day's first chunk. Discretionary packing
still starts at 08:00 (`breakfast at 7:00 vs the 08:00 day start`). It is also proven on the
emulator (see 37-VERIFICATION.md).

## Mutation log

Each mutant was applied, then the target test was run, then the change was reverted with a
backup copy.

| # | Mutant | Killed by |
|---|---|---|
| M1 | meal branch disabled (`if (false)`), so a meal falls through to the 25+5 lattice | 6 tests in `schedule_generator_meals_test.dart` |
| M2 | 10-minute floor → 0 | "a leftover piece under 10 minutes is dropped", "a 9-minute one is not" |
| M3 | Work yields to meetings only (`return meetings`) | "Work 9-5 with lunch 12-1…", "a meeting over lunch and Work" |
| M4 | meal ignores meetings (`const []`) | 4 "the meeting wins" tests |
| M5 | meal yields to meals too, so it erases itself | 5 tests |
| M6 | generated reader `fields[9] as String` (non-nullable) | old-binary test: `type 'Null' is not a subtype of type 'String'` |
| M7 | `saveMeals` does not delete a switched-off meal | "saving again updates in place…" |
| M8 | `saveMeals` never updates in place, so duplicates appear | same |
| M9 | `MealDraft.fromBlocks` without the "none saved → defaults" rule | "MealDraft.fromBlocks…" |
| — | notifier loop skips meals | "a 12:30-13:30 meeting leaves lunch 12:00-12:30…" |

The notifier test for Work yielding to meals on sync was watched failing before the fix existed:
real RED, not a compile error.

The M9 mutant was **left in place by accident for one step**. `lib/utils/meals.dart` was untracked,
so `git checkout` could not restore it. I caught this from the file-change notice and restored it
by hand before committing. Lesson for future mutation runs: restore from a backup copy, not from git.
