---
phase: 02-goals-and-commitments
plan: 02
subsystem: providers
tags: [notifiers, hive, persistence, state-management]
dependency_graph:
  requires: [02-01]
  provides: [GoalsNotifier, CommitmentsNotifier, SettingsNotifier]
  affects: [03-goals-ui, 04-commitments-ui, 05-onboarding-ui]
tech_stack:
  added: []
  patterns: [ChangeNotifier, repository-backed notifier, single-instance provider]
key_files:
  created: []
  modified:
    - lib/providers/goals_notifier.dart
    - lib/providers/commitments_notifier.dart
    - lib/providers/settings_notifier.dart
    - lib/main.dart
decisions:
  - "GoalsNotifier.reorder adjusts sortOrder only within the type group; cross-type ordering not supported"
  - "SettingsNotifier constructed in main() before runApp so init() can be awaited before router evaluates redirect"
  - "Commitment blocks are hard-deleted; goals are archive-only — enforced at notifier layer"
metrics:
  duration: "2 minutes"
  completed: "2026-02-26"
requirements: [goal-types, commitment-blocks]
---

# Phase 02 Plan 02: Notifier Implementation Summary

**One-liner:** GoalsNotifier (CRUD + reorder + archive), CommitmentsNotifier (CRUD), and SettingsNotifier wired to AppSettings Hive persistence so onboardingComplete survives app restarts.

## What Was Built

Three ChangeNotifier implementations replacing Phase 1 stubs:

**GoalsNotifier** (`lib/providers/goals_notifier.dart`)
- `loadGoals()` — fetches active goals from `HiveGoalRepository`, sorted by `sortOrder`
- `saveGoal(Goal)` — persists and reloads
- `archiveGoal(String id)` — sets `isArchived = true`, saves; never deletes
- `getArchivedGoals()` — returns archived goals sorted by name (read-only, no notify)
- `reorder(GoalType, int oldIndex, int newIndex)` — reorders within type group, updates `sortOrder` fields, saves each changed goal
- `autoColor()` — next palette color based on `_goals.length % 8`
- Computed getters: `timeTargetGoals`, `outcomeGoals`, `habitGoals`

**CommitmentsNotifier** (`lib/providers/commitments_notifier.dart`)
- `loadBlocks()` — fetches all commitment blocks, notifies
- `saveBlock(CommitmentBlock)` — persists and reloads
- `deleteBlock(String id)` — hard-deletes (unlike goals which archive)

**SettingsNotifier** (`lib/providers/settings_notifier.dart`)
- `init()` — reads AppSettings from Hive on startup, caches `onboardingComplete`
- `setOnboardingComplete(bool)` — now async; creates AppSettings record if box is empty, persists to Hive before notifying

**main.dart** — `SettingsNotifier` constructed before `runApp()`; `init()` awaited after `HiveDatabase.init()` so persisted flag is loaded before go_router evaluates the onboarding redirect.

## Commits

| Hash | Message |
|------|---------|
| 35237f4 | feat(02-02): implement GoalsNotifier and CommitmentsNotifier |
| 99b8379 | feat(02-02): wire SettingsNotifier to AppSettings Hive persistence |

## Verification

- `flutter analyze` — zero issues (all 4 files, full project)
- `flutter test` — 6/6 tests pass (goal_repository_test.dart unaffected)
- All public methods confirmed present per plan specification

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Structural] SettingsNotifier moved from StatelessWidget.build to main()**
- **Found during:** Task 2
- **Issue:** Plan instructs calling `await settingsNotifier.init()` in `main()` after `HiveDatabase.init()`, but the existing `main.dart` constructed `SettingsNotifier` inside `CanopyApp.build()` — making pre-runApp initialization impossible
- **Fix:** Moved `SettingsNotifier` construction to `main()`, passed instance as a constructor parameter to `CanopyApp`, and called `init()` before `runApp()`
- **Files modified:** `lib/main.dart`
- **Commit:** 99b8379

## Self-Check: PASSED
