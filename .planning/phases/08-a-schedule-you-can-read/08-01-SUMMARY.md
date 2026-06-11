---
phase: 08-a-schedule-you-can-read
plan: "01"
subsystem: schedule-generator
tags: [hive-schema, schedule-generator, ordering, wave-0-stubs, read-02]
dependency_graph:
  requires: []
  provides:
    - isDeferred HiveField(8) on ScheduledChunk (READ-03 prerequisite)
    - transient syntheticStartMinutes field on ScheduledChunk (generator sort key)
    - schemaVersion 4 with no-op _migration3to4
    - READ-02 ordering: synthetic start times, commitment/discretionary split, trailing-break trim
    - Four Wave 0 test stubs (chunk_card_goal_name, chunk_detail_sheet, schedule_notifier_defer, focus_screen)
  affects:
    - lib/data/models/scheduled_chunk.dart (isDeferred, syntheticStartMinutes)
    - lib/data/models/scheduled_chunk.g.dart (regenerated adapter)
    - lib/data/database/migrations.dart (v4, _migration3to4)
    - lib/services/schedule_generator.dart (ordering + break pass rewritten)
    - test/services/schedule_generator_test.dart (Tests 6/7 updated, 10-13 added)
    - test/screens/chunk_card_goal_name_test.dart (new)
    - test/screens/chunk_detail_sheet_test.dart (new)
    - test/providers/schedule_notifier_defer_test.dart (new)
    - test/screens/focus_screen_test.dart (new)
tech_stack:
  added: []
  patterns:
    - Hive additive-only schema bump (bool field at new HiveField index)
    - discretionary/commitment stream split in pure-Dart service
    - syntheticStartMinutes transient field for sort key
    - Wave 0 local-stub test pattern (compile + fail RED until implementation lands)
key_files:
  created:
    - test/screens/chunk_card_goal_name_test.dart
    - test/screens/chunk_detail_sheet_test.dart
    - test/providers/schedule_notifier_defer_test.dart
    - test/screens/focus_screen_test.dart
  modified:
    - lib/data/models/scheduled_chunk.dart
    - lib/data/models/scheduled_chunk.g.dart
    - lib/data/database/migrations.dart
    - lib/services/schedule_generator.dart
    - test/services/schedule_generator_test.dart
decisions:
  - Break chunks inserted after discretionary work chunks get syntheticStartMinutes = workChunk.syntheticStartMinutes + 25, so the Step D sort keeps them positioned correctly after their preceding chunk.
  - Discretionary chunks that do not fit in any free slot are removed from the result (Open Question 1 resolved: drop overflow).
  - Tests 6 and 7 were updated from the old expected behavior (trailing break present) to the correct new behavior (trailing break trimmed) — these were testing the broken pre-READ-02 behavior.
  - Wave 0 stubs use local placeholder classes (ChunkDetailSheet, FocusScreen) so they compile before the real implementations exist; markDeferred is invoked via `dynamic` dispatch so it throws NoSuchMethodError until Plan 02 adds the method.
metrics:
  duration: "~7 minutes"
  completed_date: "2026-06-11"
  tasks: 3
  files: 9
---

# Phase 8 Plan 01: Data Layer Foundation & Wave 0 Stubs Summary

Data-layer and service-layer foundation for Phase 8: `isDeferred` HiveField(8) + transient `syntheticStartMinutes` field, schema v4 with no-op migration, regenerated adapter, READ-02 generator rewrite (commitment/discretionary split, synthetic start time assignment, sort-by-start-time, trailing-break trim), and four Wave 0 test stub files that fail RED until Plans 02/03 turn them green.

---

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Add isDeferred HiveField(8) + syntheticStartMinutes, bump schema to v4, regenerate adapter | eb93522 |
| 2 | Rewrite generator ordering/break pass for READ-02; add Tests 10-13 | a97bbdd |
| 3 | Create four Wave 0 test stub files (READ-01/03/04) | ba406ad |

---

## What Was Built

### Task 1: Hive Schema Addition

`ScheduledChunk` gained two new fields:
- `@HiveField(8) bool isDeferred = false` — persisted; supports the READ-03 defer action
- `int? syntheticStartMinutes` — transient (no `@HiveField`); assigned by the generator as a sort key for discretionary chunks; not stored in Hive

`migrations.dart` was bumped from `currentSchemaVersion = 3` to `4`. A no-op `_migration3to4` was added mirroring the `_migration2to3` pattern — no data transformation is needed because Hive CE returns `false` for a missing bool field in existing records.

The Hive TypeAdapter was regenerated via `flutter pub run build_runner build --delete-conflicting-outputs`. The generated `ScheduledChunkAdapter.read()` includes `..isDeferred = fields[8] as bool`.

### Task 2: Generator Ordering/Break Pass Rewrite (READ-02)

The existing uniform break-insertion loop was replaced with a 5-step algorithm:

**Step A** — splits `workChunks` into `commitmentChunks` (anchored, sorted by `anchoredStartMinutes`) and `discretionaryChunks`.

**Step B** — `_assignSyntheticStartTimes`: builds merged commitment windows, derives free time slots from dayStart=480 to dayEnd=1320, and greedily packs each discretionary chunk's `syntheticStartMinutes`. Break chunks in the slot-packer receive their own `syntheticStartMinutes = workChunk.syntheticStartMinutes + 25` so the Step D sort positions them correctly.

**Step C** — builds result: commitment chunks first (no breaks between them), then each discretionary chunk followed by its short/long break. Break chunks get `syntheticStartMinutes` set for the sort.

**Step D** — sorts by `anchoredStartMinutes ?? syntheticStartMinutes ?? 9999`.

**Step E** — trims trailing non-work chunks (`while result.last.chunkType != ChunkType.work`).

Existing tests 6 and 7 were updated (see Deviations). New tests 10-13 were added covering the four READ-02 behaviors.

### Task 3: Wave 0 Test Stubs

Four stub test files were created. Each compiles cleanly and runs with failing tests:

| File | Failure Mode |
|------|-------------|
| `chunk_card_goal_name_test.dart` | `find.text('Morning Run')` fails — ChunkCard doesn't accept `goalName` yet |
| `chunk_detail_sheet_test.dart` | Local stub renders nothing — action labels not found |
| `schedule_notifier_defer_test.dart` | HiveError on `notifier.init()` — ScheduleNotifier uses Hive directly |
| `focus_screen_test.dart` | Local stub renders nothing — timer label not found |

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tests 6 and 7 were testing broken pre-READ-02 behavior**
- **Found during:** Task 2, when the new generator produced 4/3 chunks instead of 8/6
- **Issue:** Tests 6 and 7 asserted `result.length == 8/6` including a trailing break at the very end — the behavior READ-02 explicitly removes. The tests were written against the old broken generator.
- **Fix:** Updated both tests to reflect the correct READ-02 behavior: trailing break is trimmed, so Test 6 expects `result.length == 7` (W SB W SB W SB W) and Test 7 expects `result.length == 5` (W SB W SB W). Both tests updated with `reason:` annotations explaining the READ-02 requirement.
- **Files modified:** `test/services/schedule_generator_test.dart`
- **Commit:** a97bbdd

**2. [Rule 1 - Bug] Break chunks in result had no syntheticStartMinutes, causing sort to place them after all work chunks**
- **Found during:** Task 2, first test run showing Tests 6/7 getting 4/3 chunks instead of 7/5
- **Issue:** After Step D sort, break chunks with `anchoredStartMinutes == null` and `syntheticStartMinutes == null` sorted to sort-key 9999 (end of list). Step E then trimmed all of them, resulting in bare work chunks with no intervening breaks at all.
- **Fix:** In Step C, each newly-created break chunk receives `breakChunk.syntheticStartMinutes = chunk.syntheticStartMinutes! + chunk.durationMinutes` (i.e., work chunk start + 25). This positions the break immediately after its preceding work chunk in the sort.
- **Files modified:** `lib/services/schedule_generator.dart`
- **Commit:** a97bbdd

---

## Known Stubs

None in production code. The four Wave 0 test stub files contain local placeholder classes (`ChunkDetailSheet`, `FocusScreen`) that render nothing — these are deliberate test scaffolds, not production stubs.

Pre-existing (out of scope): `lib/services/schedule_generator.dart` line 101 has `// Phase 3 uses placeholder chunksRemaining = 2.0` — logged to deferred-items.

---

## Self-Check: PASSED

### Files exist:
- `lib/data/models/scheduled_chunk.dart` ✓
- `lib/data/models/scheduled_chunk.g.dart` ✓
- `lib/data/database/migrations.dart` ✓
- `lib/services/schedule_generator.dart` ✓
- `test/services/schedule_generator_test.dart` ✓
- `test/screens/chunk_card_goal_name_test.dart` ✓
- `test/screens/chunk_detail_sheet_test.dart` ✓
- `test/providers/schedule_notifier_defer_test.dart` ✓
- `test/screens/focus_screen_test.dart` ✓

### Commits exist:
- eb93522 (Task 1) ✓
- a97bbdd (Task 2) ✓
- ba406ad (Task 3) ✓

### Test results:
- `flutter test test/services/schedule_generator_test.dart` → 14 passed ✓
- Wave 0 stubs: 4 RED (expected), 1 passing (dispose-no-leak, expected) ✓
- `flutter analyze` → 0 new errors (5 pre-existing info deprecation warnings unrelated to this plan) ✓
