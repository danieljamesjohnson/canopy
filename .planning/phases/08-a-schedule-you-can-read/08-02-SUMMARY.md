---
phase: 08-a-schedule-you-can-read
plan: "02"
subsystem: schedule-ui
tags: [chunk-card, goal-name, rationale, bottom-sheet, defer, read-01, read-03, wave-0-green]
dependency_graph:
  requires:
    - isDeferred HiveField(8) on ScheduledChunk (08-01)
    - ScheduleNotifier markComplete/markSkipped (Phase 4)
    - GoalsNotifier.goals (Phase 2)
  provides:
    - goalName/displayRationale/onTap params on ChunkCard (READ-01)
    - _lookupGoalName/_toDisplayRationale in ScheduleScreen (READ-01)
    - ChunkDetailSheet bottom sheet with Complete/Skip/Defer/Start focus (READ-03)
    - ScheduleNotifier.markDeferred(chunkId) method (READ-03)
    - DailyScheduleRepository/CompletionLogRepository constructor injection on ScheduleNotifier
  affects:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/schedule/schedule_screen.dart
    - lib/screens/schedule/widgets/chunk_detail_sheet.dart (new)
    - lib/providers/schedule_notifier.dart
    - test/screens/chunk_card_goal_name_test.dart (GREEN)
    - test/screens/chunk_detail_sheet_test.dart (GREEN)
    - test/providers/schedule_notifier_defer_test.dart (GREEN)
tech_stack:
  added: []
  patterns:
    - GestureDetector inside Dismissible child for tap-vs-swipe gesture arena (T-08-03)
    - ScheduleNotifier constructor injection for DailyScheduleRepository/CompletionLogRepository (T-08-04)
    - Pre-resolved strings passed into presentational widgets (goalName, displayRationale)
    - showModalBottomSheet with notifier passed via constructor (Pitfall 5 mitigation)
key_files:
  created:
    - lib/screens/schedule/widgets/chunk_detail_sheet.dart
  modified:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/schedule/schedule_screen.dart
    - lib/providers/schedule_notifier.dart
    - test/screens/chunk_card_goal_name_test.dart
    - test/screens/chunk_detail_sheet_test.dart
    - test/providers/schedule_notifier_defer_test.dart
decisions:
  - goalName and displayRationale resolved in ScheduleScreen and passed as constructor params to keep ChunkCard purely presentational
  - GestureDetector placed inside MouseRegion.child (wrapping the Card), preserving horizontal Dismissible swipe reach
  - ScheduleNotifier repos made injectable via constructor optional params (repo/logRepo defaulting to Hive implementations) enabling Hive-free unit tests
  - displayRationale secondary text shown only when goalName is non-null (commitment chunks use anchoredStartMinutes secondary text instead)
  - markDeferred logs as CompletionEvent.skipped in Phase 8; dedicated deferred event deferred to Phase 10
metrics:
  duration: "~6 minutes"
  completed_date: "2026-06-11"
  tasks: 2
  files: 7
---

# Phase 8 Plan 02: A Schedule You Can Read — Legibility + Actions Summary

Goal names as primary card titles with readable rationale secondary text (READ-01), plus a ChunkDetailSheet bottom sheet with Complete/Skip/Defer actions and a minimal `markDeferred` notifier method (READ-03). All three Wave 0 stubs turned GREEN.

---

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | READ-01: goalName/displayRationale/onTap on ChunkCard + _lookupGoalName/_toDisplayRationale in ScheduleScreen | e6b0fae |
| 2 | READ-03: ChunkDetailSheet widget + markDeferred notifier + constructor injection + Wave 0 stubs GREEN | e1b2403 |
| 2b | Style: remove unused flutter/material.dart import from chunk_detail_sheet_test.dart | d167cc4 |

---

## What Was Built

### Task 1: READ-01 Goal-Name Titles + Readable Rationale (chunk_card + schedule_screen)

**`ChunkCard`** gained three new constructor params:
- `String? goalName` — resolved goal name displayed as `titleMedium/w600` primary title
- `String? displayRationale` — pre-mapped readable rationale displayed as `bodySmall` secondary text (only when `goalName` is non-null)
- `VoidCallback? onTap` — tap callback wired via `GestureDetector` inside the `MouseRegion` (Pitfall 4 / T-08-03: inside Dismissible child so horizontal swipes still reach Dismissible)

**`_HoverableChunkContent`** received the same three params and updated the title area:
- Primary: `goalName ?? (chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block')` at `titleMedium/w600`
- Secondary: `displayRationale` when provided + goalName is non-null, else `_formatMinutes(anchoredStartMinutes)` for commitment chunks
- `FontWeight.w600` (previously `FontWeight.bold` — corrected to exact spec token)

**`SwipeableChunkCard`** gained `goalName`, `displayRationale`, `onTap` and passes them to `ChunkCard`. The `onTap` is gated: `(chunk.isCompleted || chunk.isSkipped) ? null : onTap`.

**`schedule_screen.dart`** additions:
- `_lookupGoalName(context, chunk)` — mirrors `_lookupGoalColor` exactly; null for commitment chunks (no goalId)
- `_toDisplayRationale(String)` — static mapping: `'Habit'→'Daily habit'`, `'Outcome goal'→'Working toward your goal'`, `'Weekly goal'→'Your weekly time goal'`; other values pass through
- `_buildSwipeableCard` updated to compute `goalName` + `displayRationale` and pass them through
- `_openDetailSheet` helper method (used by the onTap lambda) pre-resolves the ScheduleNotifier and opens `ChunkDetailSheet` via `showModalBottomSheet`
- Import added for `chunk_detail_sheet.dart`

### Task 2: READ-03 ChunkDetailSheet + markDeferred + Constructor Injection

**`chunk_detail_sheet.dart`** (new) — `StatelessWidget` with:
- Drag handle (centered, 32×4px, `onSurfaceVariant` at 0.4 alpha)
- Goal color mini-bar (4×48px) + goal name (`titleMedium/w600`) + rationale (`bodyMedium/1.5`)
- For unresolved chunks: 'Start focus' `TextButton.icon` (pushes `/focus`) + 'Mark complete' `FilledButton.icon` + 'Skip chunk' `OutlinedButton.icon` + 'Defer to later' `TextButton.icon` (error color)
- For resolved chunks: 'Completed'/'Skipped' badge only, no action buttons
- `ScheduleNotifier` received via constructor (Pitfall 5 / T-08-04: no `context.read` in sheet build)

**`schedule_notifier.dart`** additions:
- `markDeferred(String chunkId)` — mirrors `markSkipped` exactly; additionally sets `chunk.isDeferred = true` so the Wave 1 schema change is exercised; guards on `chunk.isDeferred` (idempotent)
- Constructor injection: `DailyScheduleRepository? repo` and `CompletionLogRepository? logRepo` optional params (default to Hive implementations); enables in-memory fake repos in tests without Hive bootstrap

**Wave 0 tests turned GREEN:**

| Test file | From | To |
|-----------|------|----|
| `test/screens/chunk_card_goal_name_test.dart` | RED (goalName param missing) | GREEN |
| `test/screens/chunk_detail_sheet_test.dart` | RED (stub renders nothing) | GREEN |
| `test/providers/schedule_notifier_defer_test.dart` | RED (NoSuchMethodError on markDeferred) | GREEN |

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Unused import in chunk_detail_sheet_test.dart**
- **Found during:** Task 2, flutter analyze run
- **Issue:** The original Wave 0 stub imported `package:flutter/material.dart` for the local `StatelessWidget` stub class. After Plan 02 replaced the stub with a real import, that import became unused and triggered a lint warning.
- **Fix:** Removed the unused `package:flutter/material.dart` import from `test/screens/chunk_detail_sheet_test.dart`.
- **Files modified:** `test/screens/chunk_detail_sheet_test.dart`
- **Commit:** d167cc4

**2. [Rule 2 - Missing critical functionality] ScheduleNotifier lacked constructor injection for test isolation**
- **Found during:** Task 2, attempt to use `_InMemoryScheduleRepository` in `schedule_notifier_defer_test.dart`
- **Issue:** The Wave 0 test stub had prepared fake repos but the notifier's `_repo` and `_logRepo` were `final` fields initialized directly to `HiveDailyScheduleRepository()` and `HiveCompletionLogRepository()`. The test would have failed because `init()` always went to Hive regardless of the fake repos. Plan comments noted "Plan 08-02 will add constructor injection."
- **Fix:** Added optional `repo` and `logRepo` constructor params defaulting to the Hive implementations. Production code path unchanged; test code passes in-memory fakes.
- **Files modified:** `lib/providers/schedule_notifier.dart`, `test/providers/schedule_notifier_defer_test.dart`
- **Commit:** e1b2403

---

## Known Stubs

None. All production code is wired. The `focus_screen_test.dart` Wave 0 stub (for Plan 08-03 / READ-04) remains RED as expected — it is explicitly out of scope for Plan 02.

---

## Threat Surface Scan

No new security-relevant surface introduced beyond the threat model in the plan:
- `ChunkDetailSheet` passes `ScheduleNotifier` via constructor (T-08-04 mitigation applied)
- `GestureDetector` inside `Dismissible` child (T-08-03 mitigation applied)
- No new network endpoints, auth paths, file access, or schema changes

---

## Self-Check: PASSED

### Files exist:
- `lib/screens/schedule/widgets/chunk_card.dart` ✓
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` ✓
- `lib/screens/schedule/schedule_screen.dart` ✓
- `lib/screens/schedule/widgets/chunk_detail_sheet.dart` ✓
- `lib/providers/schedule_notifier.dart` ✓

### Commits exist:
- e6b0fae (Task 1) ✓
- e1b2403 (Task 2) ✓
- d167cc4 (style fix) ✓

### Test results:
- `flutter test test/screens/chunk_card_goal_name_test.dart` → 2 passed (GREEN) ✓
- `flutter test test/screens/chunk_detail_sheet_test.dart` → 2 passed (GREEN) ✓
- `flutter test test/providers/schedule_notifier_defer_test.dart` → 1 passed (GREEN) ✓
- `flutter analyze` → 0 new errors (5 pre-existing info-level deprecation warnings for `onReorder` in unrelated files) ✓
- `focus_screen_test.dart` → 1 failing RED (expected Wave 0 stub, out of scope for Plan 02) ✓
