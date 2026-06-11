---
phase: 10-close-the-day
verified: 2026-06-11T21:30:00Z
status: human_needed
score: 9/9 must-haves verified
overrides_applied: 0
human_verification:
  - test: "On an iOS device (or simulator if available), enable the Evening reminder toggle in Settings and wait for 8:00pm (or set device clock to 7:59pm). Verify the notification fires with title 'Canopy' and body 'Time to close the day. See how your chunks went.'"
    expected: "Notification appears in the iOS notification tray at 8:00pm."
    why_human: "zonedSchedule firing is a real-time OS event on a physical device. No iOS simulator on this Linux machine. Cannot verify firing behavior programmatically."
  - test: "On an iOS device, tap the fired evening notification from the tray when the app is backgrounded."
    expected: "App opens to the /schedule (or /schedule/checkin) screen, not a crash."
    why_human: "Notification tap routing relies on the OS callback; requires a backgrounded app state on-device."
  - test: "Open the app on iOS after a day where one or more chunks were deferred (markDeferred called), then tap Start your day the next morning. Verify a chunk for the deferred goal appears in the newly generated schedule."
    expected: "The deferred goal's chunk appears in today's generated schedule as 'Carried over from yesterday'."
    why_human: "generateToday single-hop carry-in reads yesterday's persisted Hive schedule. End-to-end Hive persistence requires a real device run."
---

# Phase 10: Close the Day — Verification Report

**Phase Goal:** The daily loop has a discoverable end — users are offered an end-of-day summary, can defer chunks to tomorrow, and commitment time is attributed correctly in completion logs.
**Verified:** 2026-06-11T21:30:00Z
**Status:** human_needed (all automated truths VERIFIED; 3 on-device iOS items require human testing)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Completing a commitment-block chunk logs a CompletionLog with a non-empty goal identifier (CommitmentBlock.id), not an empty string | VERIFIED | `schedule_notifier.dart` line 173: `goalId: chunk.commitmentId ?? chunk.goalId ?? ''`; `schedule_generator.dart` line 223: `commitmentId: block.id`; confirmed by `commitment_attribution_test.dart` (5/5 pass) |
| 2 | Skipping or deferring a commitment-block chunk also logs the non-empty CommitmentBlock.id | VERIFIED | Same `chunk.commitmentId ?? chunk.goalId ?? ''` pattern at all three mark* log sites (markComplete line 173, markSkipped line 242, markDeferred line 310); `defer_carryover_test.dart` test "markDeferred on a commitment chunk logs commitmentId as goalId" passes |
| 3 | Existing Hive records load without error after the schema bump (additive migration, no data loss) | VERIFIED | `migrations.dart`: `currentSchemaVersion = 5`; `_migration4to5` no-op body; `assert(_migrations.length == currentSchemaVersion)` satisfied (5 entries, 5 versions); all new fields are nullable/defaulted |
| 4 | Deferring a chunk causes the same goal's demand to appear in the next morning's generated schedule with no manual action (single-hop carry-in) | VERIFIED | `schedule_notifier.dart` lines 120-127: prior-day `getByDate(yesterdayYmd)` lookup, `isDeferred && !isCompleted && goalId != null` filter, passed to `generate(deferredGoalIds:)`; generator lines 342-367 inject fresh-demand slots; `defer_carryover_test.dart` "deferred discretionary chunk re-appears" passes |
| 5 | markDeferred logs CompletionEvent.deferred (not skipped) | VERIFIED | `schedule_notifier.dart` line 312: `eventIndex: CompletionEvent.deferred.index`; `defer_carryover_test.dart` "markDeferred logs eventIndex == CompletionEvent.deferred.index" passes |
| 6 | A habit streak survives a deferral — a deferred day is treated as non-breaking (moved, not missed); a skip still resets | VERIFIED | `schedule_generator.dart` lines 82-98: `deferredDates` set built, `else if (deferredDates.contains(ymd)) { /* continue without increment or reset */ }` branch; `defer_carryover_test.dart` streak tests: deferred streak=2, skipped streak=0, both pass |
| 7 | Only discretionary goal chunks carry; commitment chunks (anchored to their day) do not defer-carry | VERIFIED | `schedule_notifier.dart` line 124: `c.goalId != null` filter naturally excludes commitment chunks (their goalId is null); `defer_carryover_test.dart` "deferred commitment chunk is NOT carried" passes |
| 8 | After ~6pm OR once >=50% of today's work chunks are resolved, the Home active-schedule view shows a dismissible end-of-day card that routes to the existing /summary screen; not shown on the empty-state branch | VERIFIED | `end_of_day_card.dart` lines 100-110: `shouldShowEodCard` top-level function with `hour >= 18 OR resolved/total >= 0.5`; `home_screen.dart` lines 110-115: insertion inside active-schedule branch only (`_eodCardDismissed` + `_shouldShowEodCard`); `context.push('/summary')`; `end_of_day_card_test.dart` 10/10 pass |
| 9 | Settings has an opt-in evening-reminder toggle (default OFF) that schedules/cancels a notification on id 2 with the desktop/web guard; reminder is (re)scheduled idempotently on app start | VERIFIED | `notification_service.dart` lines 190-237: `scheduleEveningReminder`/`cancelEveningReminder` on `id: 2` with `kIsWeb` + `Platform.isLinux\|\|isWindows` guards; `settings_notifier.dart` lines 24-40: fields default false/1200, init() hydration; `settings_screen.dart` lines 167-189: Evening reminder ListTile with Switch, `onTap: null`; `main.dart` lines 99-103: idempotent app-start scheduling when `eveningReminderEnabled` |

**Score:** 9/9 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/data/models/scheduled_chunk.dart` | `commitmentId` @HiveField(9) | VERIFIED | Lines 57-58: `@HiveField(9) String? commitmentId` with doc comment |
| `lib/data/models/scheduled_chunk.g.dart` | Regenerated adapter with fields[9] | VERIFIED | Line 26: `commitmentId: fields[9] as String?`; line 56: `..write(obj.commitmentId)` |
| `lib/data/models/app_settings.dart` | `eveningReminderEnabled` HiveField(7) + `eveningReminderMinutes` HiveField(8) | VERIFIED | Lines 42-46: both fields with defaults false/1200 |
| `lib/data/models/app_settings.g.dart` | Regenerated adapter with fields[7]/fields[8] | VERIFIED | Lines 27-28: both fields decoded |
| `lib/data/database/migrations.dart` | `currentSchemaVersion = 5`, `_migration4to5` | VERIFIED | Line 3: version 5; lines 45-52: `_migration4to5` no-op; assert satisfied |
| `lib/services/schedule_generator.dart` | `commitmentId: block.id` on Step 1; `deferredGoalIds` parameter; `deferredDates` in `computeStreak` | VERIFIED | Line 223, line 202, lines 82-98 |
| `lib/providers/schedule_notifier.dart` | All three mark* log sites use `commitmentId ?? goalId ?? ''`; `markDeferred` logs `CompletionEvent.deferred`; `generateToday` single-hop carry-in | VERIFIED | Lines 173, 242, 310; line 312; lines 120-127 |
| `lib/screens/home/widgets/end_of_day_card.dart` | `class EndOfDayCard` + `shouldShowEodCard` top-level function | VERIFIED | Lines 10-93, lines 100-110 |
| `lib/screens/home/home_screen.dart` | `_eodCardDismissed` state, `_shouldShowEodCard` helper, EndOfDayCard insertion in active-schedule branch only | VERIFIED | Lines 45, 226-227, 110-115 |
| `lib/services/notification_service.dart` | `scheduleEveningReminder` + `cancelEveningReminder` on id 2 with web/desktop guards | VERIFIED | Lines 190-237 |
| `lib/providers/settings_notifier.dart` | `eveningReminderEnabled/Minutes` getters, `setEveningReminderEnabled` setter, init() hydration | VERIFIED | Lines 24-40, 85-91 |
| `lib/screens/settings/settings_screen.dart` | Evening reminder ListTile after mid-day row, Switch, `onTap: null` | VERIFIED | Lines 167-189 |
| `lib/main.dart` | Idempotent evening reminder scheduling on app start when enabled | VERIFIED | Lines 99-103 |
| `test/commitment_attribution_test.dart` | 5 CLOSE-03 regression tests | VERIFIED | 5/5 pass |
| `test/defer_carryover_test.dart` | 13 CLOSE-02 regression tests | VERIFIED | 13/13 pass |
| `test/end_of_day_card_test.dart` | 10 widget + trigger logic tests | VERIFIED | 10/10 pass |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `schedule_notifier.dart` | `CompletionLog.goalId` | `chunk.commitmentId ?? chunk.goalId ?? ''` at all three mark* log sites | WIRED | Confirmed at lines 173, 242, 310 |
| `schedule_generator.dart` Step 1 | `ScheduledChunk.commitmentId` | `commitmentId: block.id` in commitment chunk constructor | WIRED | Confirmed at line 223 |
| `schedule_notifier.dart generateToday` | `schedule_generator.dart generate()` | `deferredGoalIds` built from prior-day `isDeferred && !isCompleted && goalId != null` chunks | WIRED | Confirmed at lines 120-137 |
| `schedule_generator.dart computeStreak` | `CompletionEvent.deferred` | `deferredDates` index, `else if (deferredDates.contains(ymd))` non-breaking branch | WIRED | Confirmed at lines 82-98 |
| `home_screen.dart` | `end_of_day_card.dart` | `EndOfDayCard` inserted inside active-schedule branch with `_shouldShowEodCard` trigger | WIRED | Confirmed at lines 110-115 |
| `end_of_day_card.dart` | `/summary` | `context.push('/summary')` in `onGoToSummary` callback | WIRED | Confirmed at `home_screen.dart` line 114 |
| `main.dart` | `notification_service.dart scheduleEveningReminder` | App-start scheduling when `eveningReminderEnabled` is true | WIRED | Confirmed at lines 99-103 |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `EndOfDayCard` | `resolved`, `total` | `chunks` prop → `workChunks.where(...)` filter on live `ScheduledChunk` list | Yes — computed from real schedule data at render time | FLOWING |
| `SettingsNotifier.eveningReminderEnabled` | `_eveningReminderEnabled` | `settings?.eveningReminderEnabled ?? false` from Hive `AppSettings` in `init()` | Yes — reads from persisted HiveField(7) | FLOWING |
| `ScheduleNotifier.generateToday deferredGoalIds` | `deferredGoalIds` | `_repo.getByDate(yesterdayYmd)` Hive lookup, chunk filter | Yes — reads live Hive schedule data | FLOWING |

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| CLOSE-03: commitment chunk carries block.id in log | `flutter test test/commitment_attribution_test.dart` | 5/5 pass | PASS |
| CLOSE-02: markDeferred logs deferred event; streak non-breaking | `flutter test test/defer_carryover_test.dart` | 13/13 pass | PASS |
| CLOSE-01: EndOfDayCard renders correct data, trigger logic | `flutter test test/end_of_day_card_test.dart` | 10/10 pass | PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CLOSE-01 | 10-03-PLAN.md | Discoverable end-of-day moment (time-aware Home card + opt-in evening reminder) | SATISFIED | `end_of_day_card.dart`, `home_screen.dart`, `notification_service.dart`, `settings_notifier.dart`, `settings_screen.dart`, `main.dart` all wired; 10 tests pass |
| CLOSE-02 | 10-02-PLAN.md | Deferred chunks carry into next morning's generation | SATISFIED | `schedule_notifier.dart` carry-in, `schedule_generator.dart` deferredGoalIds + computeStreak deferred branch; 13 tests pass |
| CLOSE-03 | 10-01-PLAN.md | Commitment chunks attributed in completion logs (non-empty goal id) | SATISFIED | `commitmentId: block.id` in generator; `commitmentId ?? goalId ?? ''` at all three mark* sites; 5 tests pass |

All three requirement IDs declared across the phase plans are accounted for. No orphaned requirements mapped to Phase 10 in REQUIREMENTS.md beyond CLOSE-01, CLOSE-02, CLOSE-03.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none in Phase 10 files) | — | — | — | — |

Scanned all 16 created/modified Phase 10 files. No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, or `PLACEHOLDER` markers in Phase 10 source. No stub return patterns (`return null`, `return []`, `return {}`) in user-facing code paths. No hardcoded empty data flowing to rendering.

Pre-existing out-of-scope `onReorder` deprecation infos (5 items in `goals_screen.dart`, `adjustments_section.dart`, and prior test files) are unchanged from before Phase 10 and are explicitly noted as out-of-scope per CLAUDE.md.

---

## Human Verification Required

### 1. iOS Evening Notification Fires at 8:00pm

**Test:** On an iOS device, enable the Evening reminder toggle in Settings. Set device time to 7:59pm (or wait until 8:00pm). Verify the notification arrives.
**Expected:** Notification appears in the iOS notification tray with title "Canopy" and body "Time to close the day. See how your chunks went."
**Why human:** `zonedSchedule` firing is a real-time OS event requiring a live device. The Linux dev machine has no iOS simulator. The guard logic (kIsWeb + Platform.isLinux||isWindows) is verified in code but the actual notification schedule/delivery on iOS requires physical device testing.

### 2. iOS Notification Tap Routing

**Test:** With the Canopy app backgrounded on an iOS device, tap the fired evening notification from the notification tray.
**Expected:** App comes to foreground and navigates to `/schedule` (if a schedule exists today) or `/schedule/checkin` (if not). No crash.
**Why human:** The `onTapCallback` routing in `main.dart` (lines 77-85) wires to `router.go()` via `addPostFrameCallback`. Correctness of this routing after a cold-start notification tap requires a real backgrounded-app state on-device.

### 3. Deferred Carry-In End-to-End on Device

**Test:** On an iOS device: (1) generate a schedule, (2) defer one discretionary chunk via the chunk detail sheet, (3) the following morning, tap "Start your day" and complete the check-in. Verify the deferred goal appears in the new schedule with rationale "Carried over from yesterday."
**Expected:** The deferred goal's chunk appears in today's generated schedule.
**Why human:** The `generateToday` single-hop carry-in reads yesterday's Hive-persisted schedule via `_repo.getByDate(yesterdayYmd)`. End-to-end Hive write → persist → next-session read across a real day boundary requires a device run; the automated test uses in-memory fakes.

---

## Gaps Summary

None. All 9 observable truths are VERIFIED. All 16 artifacts exist, are substantive, and are wired with real data flowing. All 3 requirement IDs (CLOSE-01, CLOSE-02, CLOSE-03) are satisfied. 28/28 Phase 10 regression tests pass. The 3 human verification items are on-device iOS behaviors that cannot be verified on this Linux development machine.

---

_Verified: 2026-06-11T21:30:00Z_
_Verifier: Claude (gsd-verifier)_
