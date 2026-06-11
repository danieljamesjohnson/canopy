---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Phases
status: completed
last_updated: "2026-06-11T21:36:24.849Z"
last_activity: 2026-06-11 -- Phase 10 Plan 03 complete (CLOSE-01 end-of-day card + evening reminder)
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 11
  completed_plans: 11
  percent: 80
---

# Execution State

**Project:** Canopy
**Created:** 2026-02-24
**Last session:** 2026-06-11T21:36:24.843Z

---

## Current Position

Phase: 10 (Close the Day) — COMPLETE
Plan: 3 of 3 (all plans done)
Next: Phase 11 — Quarterly Review Aggregation
Status: Phase 10 complete; all 3 plans delivered
Last activity: 2026-06-11 -- Phase 10 Plan 03 complete (CLOSE-01 end-of-day card + evening reminder)

Progress: [███████---] 73% (3/5 phases complete, 10/11 plans done)

---

## Completed Plans

| Phase | Plan | Summary | Completed |
|-------|------|---------|-----------|
| 01-foundation | 01-01 | All Phase 1 packages installed via pubspec.yaml with hive_ce_generator build.yaml config and clean 11-directory lib scaffold replacing the Flutter counter demo | 2026-02-24 |
| 01-foundation | 01-02 | 7 Hive entity classes (typeIds 0-6) with UUID v4 string IDs, int time storage, and build_runner-generated TypeAdapter .g.dart files; flutter analyze clean | 2026-02-24 |
| 01-foundation | 01-03 | go_router StatefulShellRoute with 4-tab NavigationBar, onboarding redirect via SettingsNotifier.refreshListenable, and 6 stub screens + 4 ChangeNotifier stubs | 2026-02-24 |

---

## Decisions

| Phase-Plan | Decision | Rationale |
|-----------|----------|-----------|
| 01-01 | Used hive_ce over Isar | RESEARCH.md confirmed hive_ce is the selected database (OQ-1 resolved at research phase) |
| 01-01 | MaterialApp used in main.dart placeholder (not MaterialApp.router) | go_router intentionally wired in plan 01-04 after all dependencies exist |
| 01-01 | All entity IDs will use UUID v4 strings | Compatible with eventual sync in v2; consistent from the start |
| 01-03 | createRouter(SettingsNotifier) factory function | Prevents GoRouter init before Provider tree exists |
| 01-03 | Onboarding and QuarterlyReview outside StatefulShellRoute shell | No bottom nav shown on those screens |
| 01-02 | Timestamp fields (generatedAt, recordedAt, completedAt) use DateTime; schedulable times use int | Timestamps record "when this happened"; schedulable times are minutes from midnight UTC |
| 01-02 | Enums stored as int index (goalTypeIndex, chunkTypeIndex, eventIndex) | Fragile across renames if stored as string; int index is safe |

---
- [Phase 01-04]: SettingsNotifier constructed before MultiProvider so same instance passed to createRouter and ChangeNotifierProvider.value
- [Phase 01-04]: Migration runner stores schemaVersion as int in SharedPreferences; _migrations list is index-based, additive-only
- [Phase 01-04]: CompletionLog and QuarterlySnapshot repository interfaces have no delete/update — append-only enforced at interface level
- [Phase 02-01]: Nullable fields (color, priorityWeight, weeklyHourBudget, deadline, etc.) degrade gracefully for existing Hive records; non-nullable int fields (sortOrder=0, streakCount=0) use field declaration defaults
- [Phase 02-01]: No-op _migration1to2 added to migration list so schemaVersion increments atomically even for additive-only Hive schema changes
- [Phase 02-02]: SettingsNotifier constructed in main() before runApp so init() can be awaited before router evaluates redirect
- [Phase 02-02]: Commitment blocks are hard-deleted; goals are archive-only enforced at notifier layer
- [Phase 02-03]: DraggableScrollableSheet constructed inline in showModalBottomSheet builder so scrollController flows correctly to GoalFormSheet.scrollController
- [Phase 02-03]: Type-specific fields reset to null when GoalType changes in form sheet to avoid stale cross-type data
- [Phase 02-03]: /goals/archived added as child route inside Goals StatefulShellBranch so bottom nav bar remains visible
- [Phase 02-04]: CommitmentsScreen placed outside StatefulShellRoute — no bottom nav shown (settings-style)
- [Phase 02-04]: Goals overflow menu uses context.push('/commitments') so back navigation returns to Goals
- [Phase 02-05]: _Screen1 is StatefulWidget with addListener/removeListener in initState/dispose to avoid StatefulBuilder listener accumulation
- [Phase 02-05]: router.dart redirect after onboarding returns /goals not /home so user sees their created goal immediately
- [Phase 02-05]: setOnboardingComplete(true) is strictly last in _completeOnboarding — saves all awaited before router redirect fires
- [Phase 03-01]: Commitment chunks excluded from discretionary capacity — fixed anchored slots counted separately
- [Phase 03-01]: daysRemaining floors at 1 via max(1,...) to prevent division-by-zero in urgency score
- [Phase 03-01]: Phase 3 uses placeholder chunksRemaining=2.0 in urgency formula; replaced with CompletionLog in Phase 4
- [Phase 03-02]: ScheduleNotifier constructed before runApp so init() can be awaited; passed via ChangeNotifierProvider.value to avoid double-construction
- [Phase 03-02]: Stub screens (CheckinScreen, AcknowledgmentScreen) created in Plan 02 so router.dart compiles; replaced by full implementations in Plans 03 and 04
- [Phase 03-03]: Inline AnimatedSwitcher (Path A) used for acknowledgment — avoids second route and keeps mood state in one widget
- [Phase 03-03]: AcknowledgmentScreen kept as standalone widget for future route use even though Phase 3 uses inline approach
- [Phase 03-03]: Swipe-up threshold primaryVelocity < -300 logical pixels/second for deliberate gesture
- [Phase 03-04]: hexToColor() copied into chunk_card.dart (not imported from goal_card.dart) to keep schedule widgets self-contained; schedule_screen.dart imports from chunk_card.dart
- [Phase 03-04]: context.read<GoalsNotifier>() used inside ListView.builder for goal color lookup to avoid unnecessary rebuild cascade
- [Phase 03-04]: HomeScreen AppBar title is 'Canopy'; mood color map declared as static const in each screen for two-screen simplicity
- [Phase 03-05]: Habit ordering and timeless habit/weekly-goal display after work blocks are out-of-scope for Phase 3 — flagged as future enhancements
- [Phase 04-01]: Dismissible with confirmDismiss=false used for swipe gesture detection so cards stay in place
- [Phase 04-01]: Skipped chunks rendered in ExpansionTile at bottom of schedule list, hidden when empty
- [Phase 04-chunk-tracking-and-notifications]: flutter_local_notifications v21 uses all-named-parameter API; RESEARCH.md positional pattern updated accordingly
- [Phase 04-chunk-tracking-and-notifications]: rootNavigatorKey passed as navigatorKey to GoRouter so notification tap callbacks can navigate without BuildContext (AC-3)
- [Phase 04-chunk-tracking-and-notifications]: iOS notification permission deferred to post-first-check-in via NotificationService.requestIOSPermissions() in checkin_screen.dart
- [Phase ?]: Break chunks interleaved after discretionary work chunks get syntheticStartMinutes = workChunk.syntheticStartMinutes + 25 so Step D sort keeps them correctly positioned
- [Phase ?]: Overflow discretionary chunks (no free slot found) are dropped from result — syntheticStartMinutes stays null and removeWhere filters them before Step C build
- [Phase ?]: Timer.periodic in StatefulWidget (not ChangeNotifier) for FocusScreen — screen-local state avoids 1500 notifyListeners calls per session
- [Phase ?]: state.extra is! String guard in /focus route builder — T-08-05 mitigation; malformed extra returns harmless Scaffold not crash
- [Phase 09-01]: computeDueWeekdays and computeStreak exposed as public static methods on ScheduleGeneratorService so Plan 03 (ScheduleNotifier) can call them without duplicating logic
- [Phase 09-01]: Floor-div weekday spread i*7~/freq+1 used exclusively — round-based formula gives wrong results (freq=3 → Mon/Wed/SAT instead of Mon/Wed/Fri)
- [Phase 09-01]: lighterDay=true default in generate(); lighter day drops one mood tier (next-lower cap) for moods 3-5
- [Phase 09-01]: chunksRemaining=2.0 placeholder removed; urgency = priority / daysRemaining (max 1)
- [Phase ?]: ENGINE-06 UI half: SegmentedButton<double> priority control (Low/Normal/High → 0.25/0.5/0.75) added to GoalFormSheet for all goal types, wired to existing _priorityWeight state and save path
- [Phase 10-01]: commitmentId stored as HiveField 9 on ScheduledChunk; goalId == null preserved so goalId == Goal-id invariant stays intact for existing guards
- [Phase 10-01]: All three mark* sites (markComplete, markSkipped, markDeferred) use chunk.commitmentId ?? chunk.goalId ?? '' for consistent attribution
- [Phase 10-01]: evening-reminder HiveFields 7-8 co-located in single migration 4→5 so Wave 2 plans are free of schema churn
- [Phase 10-02]: Deferred days contribute 0 to streak count (non-breaking, no-increment); skip still resets; deferredGoalIds injection after Steps 2-4 consumes residual capacity only
- [Phase 10-02]: goalId != null filter in carry-in lookup naturally excludes commitment chunks (their goalId is null per Plan 01 design); no separate commitmentId check needed
- [Phase 10-03]: shouldShowEodCard extracted as top-level function in end_of_day_card.dart (not private on _HomeScreenState) for direct widget-test exercisability without full HomeScreen pump
- [Phase 10-03]: onTap: null on evening reminder ListTile; fixed 8pm (1200 minutes) per CONTEXT.md decision; no time-picker UI this phase
- [Phase 10-03]: EndOfDayCard insertion strictly inside the active-schedule branch (hasScheduleToday == true path); _buildEmptyState is unchanged

## Performance Metrics

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 01-foundation | 01-01 | 2 minutes | 2 | 16 |
| 01-foundation | 01-02 | 5 minutes | 2 | 15 |
| 01-foundation | 01-03 | 4 minutes | 2 | 11 |

---
| Phase 01-foundation P01-04 | 10 | 3 tasks | 16 files |
| Phase 02-goals-and-commitments P02-01 | 2 | 2 tasks | 3 files |
| Phase 02-goals-and-commitments P02-02 | 2 minutes | 2 tasks | 4 files |
| Phase 02-goals-and-commitments P02-03 | 2 minutes | 2 tasks | 6 files |
| Phase 02-goals-and-commitments P02-04 | 4 minutes | 2 tasks | 4 files |
| Phase 02-goals-and-commitments P02-05 | 3 minutes | 1 tasks | 2 files |
| Phase 03-schedule-generation-and-morning-check-in P03-01 | 8 | 2 tasks | 2 files |
| Phase 03-schedule-generation-and-morning-check-in P03-02 | 2 | 2 tasks | 6 files |
| Phase 03-schedule-generation-and-morning-check-in P03-03 | 8 | 2 tasks | 2 files |
| Phase 03-schedule-generation-and-morning-check-in P03-04 | 2 | 2 tasks | 4 files |
| Phase 03-schedule-generation-and-morning-check-in P03-05 | 5 | 2 tasks | 0 files |
| Phase 04-chunk-tracking-and-notifications P04-01 | 3 | 4 tasks | 2 files |
| Phase 04-chunk-tracking-and-notifications P04-02 | 5 | 2 tasks | 9 files |
| Phase 08-a-schedule-you-can-read P01 | 7 minutes | 3 tasks | 9 files |
| Phase 08-a-schedule-you-can-read P02 | 6 minutes | 2 tasks | 7 files |
| Phase 08-a-schedule-you-can-read P03 | 3 minutes | 2 tasks | 4 files |
| Phase 09-an-engine-that-budgets P01 | 9min | 2 tasks | 3 files |
| Phase 09-an-engine-that-budgets P02 | 25min | 1 tasks | 2 files |
| Phase 09-an-engine-that-budgets P03 | 5min | 2 tasks | 4 files |
| Phase 10-close-the-day P10-01 | 5min | 2 tasks | 8 files |
| Phase 10-close-the-day P10-02 | 5min | 2 tasks | 3 files |
| Phase 10-close-the-day P10-03 | 10min | 2 tasks | 7 files |

## Blockers

None.

---

## Stopped At

Phase 10 complete (all 3 plans done). Next: Phase 11 — Quarterly Review Aggregation (REVIEW-01)
