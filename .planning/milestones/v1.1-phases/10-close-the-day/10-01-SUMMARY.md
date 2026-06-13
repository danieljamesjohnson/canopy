---
phase: 10-close-the-day
plan: "01"
subsystem: database
tags: [hive, hive_ce, build_runner, migration, schedule_generator, schedule_notifier, commitment_attribution]

# Dependency graph
requires:
  - phase: 09-an-engine-that-budgets
    provides: ScheduleGeneratorService.generate(), ScheduleNotifier.markComplete/markSkipped/markDeferred, InMemoryCompletionLogRepository test seam
provides:
  - ScheduledChunk.commitmentId (HiveField 9) — commitment block id carrier field
  - AppSettings.eveningReminderEnabled (HiveField 7) — evening reminder opt-in
  - AppSettings.eveningReminderMinutes (HiveField 8) — reminder time in minutes from midnight
  - Hive migration 4→5 (_migration4to5 no-op) with assert satisfied
  - Regenerated scheduled_chunk.g.dart and app_settings.g.dart adapters
  - schedule_generator.dart Step 1 sets commitmentId: block.id on commitment chunks
  - All three mark* log sites use chunk.commitmentId ?? chunk.goalId ?? '' fallback
  - CLOSE-03 regression test suite (5 tests)
affects: [10-02, 10-03, 11-review-aggregation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Hive additive-field migration pattern (nullable/defaulted new fields + no-op migration body)
    - commitmentId ?? goalId ?? '' fallback expression for all mark* completion log sites
    - TDD RED/GREEN cycle for notifier log-site verification

key-files:
  created:
    - test/commitment_attribution_test.dart
  modified:
    - lib/data/models/scheduled_chunk.dart
    - lib/data/models/scheduled_chunk.g.dart
    - lib/data/models/app_settings.dart
    - lib/data/models/app_settings.g.dart
    - lib/data/database/migrations.dart
    - lib/services/schedule_generator.dart
    - lib/providers/schedule_notifier.dart

key-decisions:
  - "commitmentId stored as HiveField 9 on ScheduledChunk; goalId == null preserved so goalId == Goal-id invariant stays intact for existing guards (getByGoalId, streak write-back, summary screen filters)"
  - "All three mark* sites (markComplete, markSkipped, markDeferred) updated with commitmentId ?? goalId ?? '' — not just markComplete — for consistent attribution across all event types"
  - "evening-reminder HiveFields 7-8 co-located with commitmentId in the single migration 4→5 so Wave 2 plans are free of schema churn"

patterns-established:
  - "chunk.commitmentId ?? chunk.goalId ?? '' — canonical log-site expression for any new mark* methods in Phase 10 Wave 2"
  - "TDD RED commit (test(10-0N):) before feat commit (feat(10-0N):) for all behavior-adding tasks"

requirements-completed: [CLOSE-03]

# Metrics
duration: 5min
completed: 2026-06-11
---

# Phase 10 Plan 01: Data-Layer Foundation & Commitment Attribution Summary

**Hive schema v4→5 with commitmentId (HiveField 9) on ScheduledChunk and evening-reminder fields (HiveFields 7-8) on AppSettings; commitment-chunk logs now carry CommitmentBlock.id via chunk.commitmentId ?? goalId ?? '' at all three mark* sites (CLOSE-03)**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-11T20:40:09Z
- **Completed:** 2026-06-11T20:45:07Z
- **Tasks:** 2
- **Files modified:** 7 (plus 1 new test file)

## Accomplishments
- Added `commitmentId` (HiveField 9, String?) to ScheduledChunk and two evening-reminder fields (HiveFields 7-8) to AppSettings as additive Hive fields with no data transform required
- Bumped schemaVersion 4→5 with `_migration4to5` no-op; the `assert(_migrations.length == currentSchemaVersion)` invariant is satisfied
- Regenerated `scheduled_chunk.g.dart` and `app_settings.g.dart` with build_runner; both adapters correctly encode/decode new fields
- Set `commitmentId: block.id` in `schedule_generator.dart` Step 1 so commitment chunks carry the block id from the moment they are created
- Fixed all three `mark*` log sites in `schedule_notifier.dart` to use `chunk.commitmentId ?? chunk.goalId ?? ''` so commitment time stops being logged with an empty goal id (CLOSE-03)
- Added 5-test regression suite (`test/commitment_attribution_test.dart`) — all pass; full suite of 128 tests green

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Hive fields + migration 4→5 + regenerate adapters** - `0201899` (feat)
2. **Task 2: RED — failing commitment attribution tests** - `f1af782` (test)
3. **Task 2: GREEN — set commitmentId in generator + fix all three log sites** - `4cf571e` (feat)

## Files Created/Modified
- `lib/data/models/scheduled_chunk.dart` — Added `String? commitmentId` @HiveField(9) with constructor param
- `lib/data/models/scheduled_chunk.g.dart` — Regenerated adapter; encodes fields[9] as commitmentId
- `lib/data/models/app_settings.dart` — Added `bool eveningReminderEnabled` @HiveField(7) and `int eveningReminderMinutes` @HiveField(8)
- `lib/data/models/app_settings.g.dart` — Regenerated adapter; encodes fields[7] and fields[8]
- `lib/data/database/migrations.dart` — Bumped currentSchemaVersion 4→5; appended `_migration4to5` to list
- `lib/services/schedule_generator.dart` — Step 1 commitment chunk constructor now includes `commitmentId: block.id`
- `lib/providers/schedule_notifier.dart` — markComplete, markSkipped, markDeferred all use `chunk.commitmentId ?? chunk.goalId ?? ''`
- `test/commitment_attribution_test.dart` — New: 5 CLOSE-03 regression tests

## Decisions Made
- `goalId` is kept null on commitment chunks (not overloaded with block.id) to preserve the `goalId == Goal-id` invariant used by `getByGoalId`, streak write-back, and the end-of-day summary screen's `gid.isEmpty` filter
- The `markDeferred` site was updated in this plan (not Plan 02) because the plan instructed applying the same fallback if touched; this is consistent with the PATTERNS.md change-site spec
- Pre-existing `onReorder` deprecation warnings (5 issues in goals_screen.dart, adjustments_section.dart, and test files) are out-of-scope — they exist before this plan and are unrelated to the changes here

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `flutter analyze` initially reported `unused_import` and `no_leading_underscores_for_local_identifiers` lint issues in the new test file (introduced by this plan). Fixed inline before committing: removed unused `CompletionLogRepository` import and renamed `_buildNotifier` helper to `buildNotifier`.

## Threat Flags

No new threat surface beyond what is documented in the plan's threat model (T-10-01, T-10-02). The additive Hive fields and log-site fix introduce no new network endpoints, auth paths, or trust boundary changes.

## Next Phase Readiness
- Schema v5 is live; Plan 02 (CLOSE-02 defer-to-tomorrow carryover) and Plan 03 (CLOSE-01 end-of-day card + evening reminder) can proceed without further schema work
- `commitmentId` is set end-to-end: generated → logged → queryable. Phase 11 aggregation can read non-empty commitment goalIds from CompletionLog

---
*Phase: 10-close-the-day*
*Completed: 2026-06-11*
