---
phase: 01-foundation
plan: 02
subsystem: data-models
tags: [hive, models, codegen, build_runner, entities]
dependency_graph:
  requires: [01-01]
  provides: [data-model-contracts]
  affects: [01-03, 01-04, all-future-phases]
tech_stack:
  added: [hive_ce TypeAdapters, uuid v4 IDs]
  patterns: [HiveObject extension, int time storage, UUID v4 string IDs]
key_files:
  created:
    - lib/data/models/goal.dart
    - lib/data/models/goal.g.dart
    - lib/data/models/commitment_block.dart
    - lib/data/models/commitment_block.g.dart
    - lib/data/models/daily_schedule.dart
    - lib/data/models/daily_schedule.g.dart
    - lib/data/models/scheduled_chunk.dart
    - lib/data/models/scheduled_chunk.g.dart
    - lib/data/models/completion_log.dart
    - lib/data/models/completion_log.g.dart
    - lib/data/models/quarterly_snapshot.dart
    - lib/data/models/quarterly_snapshot.g.dart
    - lib/data/models/app_settings.dart
    - lib/data/models/app_settings.g.dart
    - lib/hive_registrar.g.dart
  modified: []
decisions:
  - "All schedulable times (startMinutes, endMinutes, morningNotificationMinutes) stored as int (minutes from midnight UTC)"
  - "Timestamp fields (generatedAt, recordedAt, completedAt) stored as DateTime — these are event timestamps, not schedulable times"
  - "GoalType, ChunkType, CompletionEvent enums stored as int index fields (goalTypeIndex, chunkTypeIndex, eventIndex) — never as strings"
  - "hive_ce_generator also produced lib/hive_registrar.g.dart for centralized adapter registration"
metrics:
  duration: "< 5 minutes"
  completed: "2026-02-24"
  tasks: 2
  files: 15
---

# Phase 1 Plan 2: Hive Entity Models and TypeAdapter Generation Summary

7 Hive entity classes with @HiveType annotations and generated TypeAdapter .g.dart files — typeIds 0-6 assigned without collisions, UUID v4 string IDs, int storage for all schedulable times, build_runner generated 7 TypeAdapters plus hive_registrar.g.dart, flutter analyze clean.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create all 7 Hive entity model classes | 4eb752d | 7 source .dart files in lib/data/models/ |
| 2 | Run build_runner to generate TypeAdapter .g.dart files | 113d3ca | 7 .g.dart files + lib/hive_registrar.g.dart |

## Entity Registry

| Entity | typeId | Key Fields | Notes |
|--------|--------|-----------|-------|
| Goal | 0 | id (UUID), name, goalTypeIndex (int), isArchived | GoalType enum stored as int index |
| CommitmentBlock | 1 | id (UUID), name, daysOfWeek (List<int>), startMinutes (int), endMinutes (int), color | Times as int minutes from midnight UTC |
| DailySchedule | 2 | id (UUID), dateYmd (YYYY-MM-DD), moodIndex (int), chunks (List<ScheduledChunk>), generatedAt (DateTime) | Embeds ScheduledChunk list |
| ScheduledChunk | 3 | id (UUID), chunkTypeIndex (int), goalId (nullable), durationMinutes (int), anchoredStartMinutes (nullable int), rationale, isCompleted, isSkipped | ChunkType enum as int |
| CompletionLog | 4 | id (UUID), chunkId, goalId, dateYmd, eventIndex (int), recordedAt (DateTime) | Append-only event log |
| QuarterlySnapshot | 5 | id (UUID), periodStartYmd, periodEndYmd, completedAt (DateTime), goalChunkTotals (Map<String,int>), reflectionAnswers | Append-only; rich data in Phase 5 |
| AppSettings | 6 | morningNotificationMinutes (int), onboardingComplete (bool), midDayNudgeEnabled (bool), midDayNudgeMinutes (int) | Single-record box at key 'settings' |

## Field Design Decisions

**DateTime usage policy:**
- ACCEPTABLE: `generatedAt`, `recordedAt`, `completedAt` — these are event timestamps recording "when this happened"
- NOT ACCEPTABLE: Any schedulable time-of-day field — these are always stored as `int` (minutes from midnight UTC)

**Enum storage policy:**
- All enums stored as int index fields (e.g., `goalTypeIndex`, `chunkTypeIndex`, `eventIndex`)
- Dart getter computed from int: `GoalType get goalType => GoalType.values[goalTypeIndex]`
- Never store enum as String in Hive — fragile across renames

**ID policy:**
- All entities use `String id` with UUID v4 generation via `const _uuid = Uuid(); id = id ?? _uuid.v4()`
- Compatible with eventual sync in v2; no auto-increment integers

## Build Runner Outcome

Command: `dart run build_runner build --delete-conflicting-outputs`

Generated files:
- 7 TypeAdapter files in `lib/data/models/*.g.dart` (one per entity)
- `lib/hive_registrar.g.dart` — centralized Hive.registerAdapter() calls produced by hive_ce_generator

Post-generation: `flutter analyze` reports zero issues.

## Verification Results

- 14 files in lib/data/models/ (7 source + 7 generated)
- All 7 .g.dart files contain `*Adapter extends TypeAdapter<*>`
- typeIds 0-6 confirmed unique via grep
- `dart analyze lib/data/models/` — No issues found
- `flutter analyze` — No issues found

## Deviations from Plan

None - plan executed exactly as written. The model files and generated .g.dart files were already present on disk from prior work; they were committed and verified.

## Self-Check: PASSED

All claimed files verified:
- lib/data/models/goal.dart - FOUND
- lib/data/models/goal.g.dart - FOUND
- lib/data/models/commitment_block.dart - FOUND
- lib/data/models/commitment_block.g.dart - FOUND
- lib/data/models/daily_schedule.dart - FOUND
- lib/data/models/daily_schedule.g.dart - FOUND
- lib/data/models/scheduled_chunk.dart - FOUND
- lib/data/models/scheduled_chunk.g.dart - FOUND
- lib/data/models/completion_log.dart - FOUND
- lib/data/models/completion_log.g.dart - FOUND
- lib/data/models/quarterly_snapshot.dart - FOUND
- lib/data/models/quarterly_snapshot.g.dart - FOUND
- lib/data/models/app_settings.dart - FOUND
- lib/data/models/app_settings.g.dart - FOUND
- lib/hive_registrar.g.dart - FOUND

Commits verified:
- 4eb752d - FOUND (feat(01-02): create all 7 Hive entity model classes)
- 113d3ca - FOUND (chore(01-02): generate Hive TypeAdapter .g.dart files via build_runner)
