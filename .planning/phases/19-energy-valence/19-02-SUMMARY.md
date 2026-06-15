---
phase: 19-energy-valence
plan: 02
subsystem: database
tags: [hive, hive-ce, dart, flutter, migration, enum, build_runner]

# Dependency graph
requires:
  - phase: 19-01
    provides: RED test stubs (migration_schema8_test.dart, wave 0) establishing test gates
provides:
  - EnergyValence enum (neutral/gives/costs, neutral=0, no @HiveType)
  - Goal.energyValenceIndex (HiveField 12, int?, additive nullable)
  - Goal.emojiTag (HiveField 13, String?, additive nullable)
  - Goal.energyValence getter (EnergyValence.values[energyValenceIndex ?? 0])
  - Regenerated GoalAdapter (writeByte 12 → 14, reads fields[12]/[13])
  - currentSchemaVersion = 8, _migration7to8 no-op, WR-06 assert satisfied
  - migration_schema8_test.dart GREEN (ENERGY-01a old-record-neutral, ENERGY-01b/ENERGY-03a round-trip)
affects: [19-03-goal-card-ui, 19-04-chunk-card-ui, 19-05-goal-form-ui, 19-06-onboarding]

# Tech tracking
tech-stack:
  added: []  # No new packages — build_runner/hive_ce_generator already present
  patterns:
    - "Additive nullable HiveField: append int?/String? fields at next free index; old records read null; getter default resolves to enum index 0"
    - "Enum stored as int index (not @HiveType): plain Dart enum, getter converts, ORDER IS FIXED comment"
    - "Schema version + migration list must be bumped in the same commit (WR-06 assert)"
    - "Per-schema migration test: migration_schemaN_test.dart owns the currentSchemaVersion==N assertion"

key-files:
  created:
    - lib/data/models/energy_valence.dart
    - test/data/migration_schema8_test.dart  # flipped RED→GREEN
  modified:
    - lib/data/models/goal.dart
    - lib/data/models/goal.g.dart
    - lib/data/database/migrations.dart
    - test/data/migration_schema7_test.dart  # removed stale version assertions

key-decisions:
  - "EnergyValence is a plain Dart enum with no @HiveType — stored as int index in Goal.energyValenceIndex (HiveField 12), following the existing GoalType/ChunkType pattern"
  - "neutral = index 0: old goals (no HiveField 12) read energyValenceIndex as null, getter returns EnergyValence.values[0] = neutral — additive-safe with zero data migration"
  - "No repository changes needed: HiveGoalRepository.save(goal) stores the whole Goal object; the regenerated adapter handles serialization transparently"
  - "migration_schema7_test.dart version assertions removed (stale after bump to 8); ScheduledChunk round-trip tests preserved as permanent regression coverage"

patterns-established:
  - "Per-schema migration test owns the currentSchemaVersion==N assertion; prior-schema test is updated to remove the stale assertion when the version advances"

requirements-completed: [ENERGY-01]

# Metrics
duration: 5min
completed: 2026-06-15
---

# Phase 19 Plan 02: Data Model Migration Summary

**Additive Hive migration adding EnergyValence enum and Goal fields 12/13 (energyValenceIndex, emojiTag) with schema bump 7→8, regenerated adapter (writeByte 14), and GREEN migration_schema8 test proving old-record-neutral compatibility**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-15T02:23:21Z
- **Completed:** 2026-06-15T02:28:41Z
- **Tasks:** 2 (+ 1 Rule 1 auto-fix)
- **Files modified:** 6

## Accomplishments

- Created `lib/data/models/energy_valence.dart` with `enum EnergyValence { neutral, gives, costs }` — neutral at index 0 ensures existing goals without HiveField 12 default to neutral via the getter's `?? 0` coercion
- Added HiveField 12 (`int? energyValenceIndex`) and HiveField 13 (`String? emojiTag`) to `Goal`, plus the `energyValence` getter and optional constructor params; import wired
- Regenerated `goal.g.dart` via `dart run build_runner build --delete-conflicting-outputs`: `writeByte(12)` became `writeByte(14)`; `read()` now maps `fields[12]` (int?) and `fields[13]` (String?) with null-safe casts
- Bumped `currentSchemaVersion` from 7 to 8 and appended `_migration7to8` no-op (matching prior additive migration style); WR-06 assert (`_migrations.length == currentSchemaVersion`) now holds (8 == 8)
- `migration_schema8_test.dart` flipped from RED to GREEN: all 4 tests pass (version==8, ENERGY-01a old-record→neutral, ENERGY-01b valence round-trip, ENERGY-03a emoji round-trip)

## Task Commits

Each task was committed atomically:

1. **Task 1: EnergyValence enum + Goal fields 12/13 + getter + constructor params** - `b02d2ce` (feat)
2. **Task 2: Regenerate adapter + bump schema 7→8 + add _migration7to8** - `c7d25b8` (feat)
3. **Rule 1 auto-fix: Remove stale schema version assertions from migration_schema7_test.dart** - `442927c` (fix)

## Files Created/Modified

- `lib/data/models/energy_valence.dart` — NEW: plain Dart enum EnergyValence { neutral, gives, costs }; no @HiveType
- `lib/data/models/goal.dart` — Added import, HiveField 12/13 fields, energyValence getter, constructor params; comment registry updated
- `lib/data/models/goal.g.dart` — REGENERATED: writeByte(14), reads fields[12]/[13] with null-safe casts
- `lib/data/database/migrations.dart` — currentSchemaVersion 7→8; _migration7to8 added (list + function body)
- `test/data/migration_schema8_test.dart` — Flipped RED→GREEN (was compile-failing; now 4 passing tests)
- `test/data/migration_schema7_test.dart` — Removed stale currentSchemaVersion==7 assertions; ScheduledChunk tests preserved

## Decisions Made

- No repository changes: `HiveGoalRepository.save(goal)` stores the whole Goal object; the regenerated adapter handles fields 12/13 transparently. Zero per-field repo edits needed.
- `EnergyValence` enum is a plain Dart enum with no `@HiveType`. Stored as `int` index only — follows the existing `GoalType` and `ChunkType` pattern. No new typeId allocated.
- `neutral` declared first (index 0) so `EnergyValence.values[null ?? 0]` = `EnergyValence.neutral` for old records — the critical additive-safety invariant.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stale currentSchemaVersion==7 assertions broke after correct schema bump**
- **Found during:** Post-task full suite regression run (`flutter test`)
- **Issue:** `migration_schema7_test.dart` had two tests asserting `currentSchemaVersion equals 7`. After bumping the schema to 8, these correctly-bumped tests started failing. The test intent was WR-06 compliance at schema 7 — that role is now owned by `migration_schema8_test.dart`.
- **Fix:** Removed the two stale version assertions from `migration_schema7_test.dart`; updated the file header comment to document the reason. The ScheduledChunk field-10 round-trip tests (the useful regression coverage) were preserved unchanged.
- **Files modified:** `test/data/migration_schema7_test.dart`
- **Verification:** `flutter test test/data/` — all 12 data tests GREEN
- **Committed in:** `442927c`

---

**Total deviations:** 1 auto-fixed (Rule 1 — stale test assertions broken by intended schema bump)
**Impact on plan:** Auto-fix was necessary for correct test suite state. No scope creep. The removed assertions were literally testing a value that was intentionally changed.

## Issues Encountered

- Pre-existing Wave 0 RED test stubs from Plan 01 (`chunk_card_valence_test.dart` failing to compile, `goal_card_valence_test.dart` running but asserting UI widgets that don't exist yet) remain red. These are expected — they target Plan 19-03 UI changes. The `chunk_card_valence_test.dart` references `ChunkCard.goalValence` (undefined); `goal_card_valence_test.dart` now COMPILES (because `energyValence` getter exists) but widget assertions fail (because `_ValenceBadge` doesn't exist yet). Both test files advance toward green with each subsequent plan.
- `flutter analyze` on the full project shows 6 errors all in `test/screens/chunk_card_valence_test.dart` (pre-existing RED stub compile errors). All modified source files analyze clean.

## Known Stubs

None — this plan is pure data layer. No UI rendering, no hardcoded empty values.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema trust-boundary changes beyond what the plan's threat model anticipated. The additive HiveField additions are the exact surface documented as T-19-02 and T-19-03 in the plan's threat register; both dispositions are `mitigate` and the mitigations are implemented (additive nullable fields, neutral=0 invariant, writeByte(14) verified, migration test pins the contract).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Data model is complete and stable. Plan 19-03 (UI: `_ValenceBadge` in `goal_card.dart`, `_ValenceChip` and emoji in `chunk_card.dart`, new props on `SwipeableChunkCard`) can proceed immediately.
- `goal_card_valence_test.dart` now COMPILES (was RED at import of `energy_valence.dart`); it will go fully GREEN once `goal_card.dart` is updated in Plan 19-03.
- `chunk_card_valence_test.dart` will compile once `ChunkCard.goalValence` / `ChunkCard.goalEmojiTag` params are added in Plan 19-03.
- No blockers.

## Self-Check: PASSED

- FOUND: lib/data/models/energy_valence.dart
- FOUND: lib/data/models/goal.dart (with HiveField 12/13)
- FOUND: lib/data/models/goal.g.dart (writeByte(14))
- FOUND: lib/data/database/migrations.dart (currentSchemaVersion=8, _migration7to8)
- FOUND: .planning/phases/19-energy-valence/19-02-SUMMARY.md
- FOUND commit: b02d2ce (Task 1)
- FOUND commit: c7d25b8 (Task 2)
- FOUND commit: 442927c (Rule 1 auto-fix)

---
*Phase: 19-energy-valence*
*Completed: 2026-06-15*
