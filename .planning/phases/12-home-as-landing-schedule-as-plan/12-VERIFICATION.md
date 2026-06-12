---
phase: 12-home-as-landing-schedule-as-plan
verified: 2026-06-12T14:51:26Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Open the app after completing onboarding on a physical or simulator device. Confirm the landing screen is Home, not Goals."
    expected: "App opens to Home screen (title 'Canopy') showing the Now/Next layout or empty state, not the Goals screen."
    why_human: "Router redirect fires at runtime with live go_router state. The test proves the redirect logic is correct but an actual cold-start confirms the initialLocation + redirect chain end-to-end on device."
  - test: "With a generated schedule open the Home screen. Verify the 'Now' section shows a clock-time range (e.g. '9:25 AM – 9:50 AM') on the ActiveChunkCard."
    expected: "ActiveChunkCard renders a clock-time range when the current chunk has a syntheticStartMinutes or anchoredStartMinutes value."
    why_human: "Clock-time display depends on syntheticStartMinutes being persisted and non-null in a real schedule. Widget tests confirm the rendering path but a live schedule proves the data layer feeds real values through."
  - test: "On the Schedule screen verify the NowMarker ('Now' label with a colored dot and trailing line) appears before the correct chunk — the first unresolved work chunk at or after the current wall time."
    expected: "NowMarker divider sits immediately above the chunk you should be working on right now, not at the top of the list or before a past chunk."
    why_human: "NowMarker placement depends on real wall-clock time and live displayStartMinutes values. The static widget test cannot reproduce mixed anchored/discretionary schedules with real timestamps."
  - test: "Without hovering, confirm Complete and Skip buttons are visible on every unresolved work chunk in the Schedule screen AND on the ActiveChunkCard on the Home screen."
    expected: "Labeled 'Complete' (filled) and 'Skip' (outlined, error-colored) buttons appear immediately without any mouse interaction on both mouse/desktop and touch surfaces."
    why_human: "Always-visible affordance on actual hardware (touch) and desktop (mouse) cannot be tested by widget pump — widget tests confirm no hover-gate, but visual confirmation on both input modalities is needed."
  - test: "Tap Complete on an unresolved chunk from the Home screen. Confirm the chunk moves to resolved state and is no longer shown in the Now section."
    expected: "After tapping Complete, the Now section updates: the next unresolved chunk becomes the new current chunk (or 'All done today!' if none remain)."
    why_human: "End-to-end state mutation through the notifier across screens requires live execution to confirm ScheduleNotifier rebuilds the Home UI correctly."
---

# Phase 12: Home as Landing, Schedule as Plan — Verification Report

**Phase Goal:** The app lands on Home and the schedule reads as a real timed plan — every chunk shows a clock time, there is one unambiguous "what am I doing right now" view, and chunk actions are discoverable without hover.
**Verified:** 2026-06-12T14:51:26Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                                                    | Status     | Evidence                                                                                                      |
| --- | ------------------------------------------------------------------------------------------------------------------------ | ---------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | Completing onboarding and relaunching from cold start both land on Home, not Goals (NAV-01)                              | VERIFIED   | `router.dart:33` returns `'/home'`; `initialLocation: '/home'` at line 26; router_redirect_test.dart 6 cases pass including cold-launch assertion |
| 2   | Home leads with an active-day view — current chunk with start/end time + next chunk (NAV-02)                             | VERIFIED   | `home_screen.dart` renders Now label + `ActiveChunkCard(chunk: currentChunk)` (line 158), Next label + compact row (lines 160–231), "All done today!" when currentChunk==null; active_chunk_card_test.dart 14 cases pass |
| 3   | Every chunk shows a real clock time (e.g. "9:25 AM – 9:50 AM"), not a frequency label (SCHED-01)                       | VERIFIED   | `chunk_card.dart` calls `formatTimeRange(chunk.displayStartMinutes!, ...)` when `displayStartMinutes != null` (lines 200–208), falls back to `'${durationMinutes} min'` (lines 214–224); `active_chunk_card.dart` same pattern (lines 93–109); `time_format.dart` implements `formatTimeRange` with en-dash; chunk_card_goal_name_test.dart 2 SCHED-01 cases pass; HiveField(10) round-trip test confirms data persists |
| 4   | Schedule has a clear "now" marker and "next" indicator anchored to current time (SCHED-02)                               | VERIFIED   | `now_marker.dart` — `class NowMarker extends StatelessWidget`, ExcludeSemantics, Row with primary dot + "Now" label + trailing line; `schedule_screen.dart` `_buildActiveChunkItems` inserts `const NowMarker()` at `nowMarkerIndex` (line 142), null when no unresolved work chunks; WR-01 fix applied (start == null or start < nowMinutes advances fallback, first future chunk breaks) |
| 5   | Each chunk row has labeled complete and skip actions visible without hover on touch AND mouse (SCHED-03)                  | VERIFIED   | `chunk_card.dart` — `_HoverableChunkContent` (StatefulWidget) removed, replaced with `_WorkChunkContent` (StatelessWidget); `_hovered`, `onEnter`, `onExit`, `AnimatedOpacity`, `Positioned` hover overlay all deleted; always-visible `FilledButton.icon` "Complete" + `OutlinedButton.icon` "Skip" under `if (!isResolved)` (lines 261–297); chunk_card_hover_test.dart confirms `find.byType(AnimatedOpacity)` findsNothing; same pattern in `active_chunk_card.dart` (lines 136–168) |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact                                              | Expected                                                 | Status     | Details                                                                                                 |
| ----------------------------------------------------- | -------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------- |
| `lib/data/models/scheduled_chunk.dart`                | `@HiveField(10) int? syntheticStartMinutes` + `displayStartMinutes` getter | VERIFIED | Line 63: `@HiveField(10) int? syntheticStartMinutes`; line 71: `int? get displayStartMinutes => anchoredStartMinutes ?? syntheticStartMinutes` |
| `lib/data/models/scheduled_chunk.g.dart`              | Regenerated adapter, writeByte(11), field 10 write/read  | VERIFIED   | Line 37: `..writeByte(11)`; line 57: `..writeByte(10)` + `..write(obj.syntheticStartMinutes)`; line 27: `syntheticStartMinutes: (fields[10] as num?)?.toInt()` |
| `lib/data/database/migrations.dart`                   | `currentSchemaVersion = 7`, 7-entry `_migrations` list  | VERIFIED   | Line 3: `const int currentSchemaVersion = 7`; lines 9–17: 7 entries including `_migration6to7`; WR-06 assert at lines 82–87 |
| `test/data/migration_schema7_test.dart`               | Schema-7 persistence + migration-count regression test   | VERIFIED   | 6 test cases; round-trip Hive test with `Directory.systemTemp`; all 6 pass |
| `lib/router.dart`                                     | Post-onboarding redirect to /home (NAV-01)               | VERIFIED   | Line 33: `if (onboardingDone && onOnboarding) return '/home';`; line 26: `initialLocation: '/home'`; no `return '/goals'` in file |
| `lib/screens/schedule/widgets/chunk_card.dart`        | `formatTimeRange` call + always-visible action buttons   | VERIFIED   | Uses `formatTimeRange` from `time_format.dart` (import line 5); `FilledButton.icon` (line 267); `OutlinedButton.icon` (line 281); no `AnimatedOpacity`; no private `_formatTimeRange` or `_formatMinutes` |
| `lib/screens/schedule/widgets/now_marker.dart`        | `class NowMarker extends StatelessWidget`                | VERIFIED   | Line 8: `class NowMarker extends StatelessWidget`; ExcludeSemantics, all theme colors |
| `lib/screens/schedule/schedule_screen.dart`           | NowMarker insertion logic (`nowMarkerIndex`)             | VERIFIED   | 6 references to `nowMarkerIndex`; imports `now_marker.dart`; WR-01-corrected algorithm (no 9999 sentinel) |
| `lib/screens/home/widgets/active_chunk_card.dart`     | `class ActiveChunkCard` — Now badge + clock-time + actions | VERIFIED | Line 15: `class ActiveChunkCard extends StatelessWidget`; `FilledButton.icon` (line 140); `OutlinedButton.icon` (line 154); `displayStartMinutes` (lines 93, 96) |
| `lib/screens/home/home_screen.dart`                   | Now/Next layout + See full schedule link (NAV-02)        | VERIFIED   | `ActiveChunkCard` import (line 14) + usage (line 158); `context.go('/schedule')` (line 254); "Now" label (line 142); "Next" label (line 164); "All done today!" (line 153) |
| `lib/utils/time_format.dart`                          | `hexToColor`, `formatMinutes`, `formatTimeRange`         | VERIFIED   | All three functions implemented; en-dash in `formatTimeRange`; imported by both `chunk_card.dart` and `active_chunk_card.dart` |
| `test/screens/active_chunk_card_test.dart`            | NAV-02 widget test (14 cases)                            | VERIFIED   | 8 ActiveChunkCard cases + 6 HomeScreen Now/Next cases; all pass |

### Key Link Verification

| From                                    | To                                        | Via                                         | Status  | Details                                                                              |
| --------------------------------------- | ----------------------------------------- | ------------------------------------------- | ------- | ------------------------------------------------------------------------------------ |
| `chunk_card.dart`                       | `ScheduleNotifier.markComplete/markSkipped` | `context.read<ScheduleNotifier>()` in button `onPressed` | WIRED | Lines 271–272 and 285–286; chunk_card_hover_test.dart tap assertions pass          |
| `chunk_card.dart`                       | `ScheduledChunk.displayStartMinutes`      | `formatTimeRange(chunk.displayStartMinutes!, ...)` | WIRED | Lines 200–207; chunk_card_goal_name_test.dart SCHED-01 cases pass                 |
| `schedule_screen.dart`                  | `NowMarker`                               | `const NowMarker()` at `nowMarkerIndex`     | WIRED   | Line 142; import at line 14; 6 nowMarkerIndex references                            |
| `active_chunk_card.dart`                | `ScheduleNotifier.markComplete/markSkipped` | `context.read<ScheduleNotifier>()` in button `onPressed` | WIRED | Lines 143–145 and 157–159; active_chunk_card_test.dart tap assertions pass        |
| `home_screen.dart`                      | `/schedule`                               | `context.go('/schedule')` in TextButton     | WIRED   | Line 254; active_chunk_card_test.dart "See full schedule" test passes              |
| `active_chunk_card.dart`                | `ScheduledChunk.displayStartMinutes`      | `formatTimeRange(chunk.displayStartMinutes!, ...)` | WIRED | Lines 93–96; active_chunk_card_test.dart clock-time case passes                   |

### Data-Flow Trace (Level 4)

| Artifact                          | Data Variable          | Source                                                              | Produces Real Data | Status      |
| --------------------------------- | ---------------------- | ------------------------------------------------------------------- | ------------------ | ----------- |
| `active_chunk_card.dart`          | `chunk.displayStartMinutes` | `ScheduledChunk.displayStartMinutes` getter → `anchoredStartMinutes ?? syntheticStartMinutes`; `syntheticStartMinutes` persisted as `@HiveField(10)` | Yes — Hive round-trip test confirms persistence | FLOWING |
| `chunk_card.dart` (`_WorkChunkContent`) | `chunk.displayStartMinutes` | Same path as above | Yes | FLOWING |
| `home_screen.dart`                | `currentChunk`, `nextChunk` | `schedule.chunks.where(work && !completed && !skipped).toList()` → `first` / `[1]`; `schedule` from `ScheduleNotifier.todaySchedule` (Hive-backed) | Yes — provider reads live Hive data | FLOWING |
| `schedule_screen.dart`            | `activeChunks`         | `schedule.chunks.where(!isSkipped).toList()`; `schedule` from `ScheduleNotifier.todaySchedule` | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior                                            | Command                                                                                                              | Result        | Status  |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------- | ------- |
| `syntheticStartMinutes` persists across Hive close/reopen | `flutter test test/data/migration_schema7_test.dart` | 6/6 pass      | PASS    |
| Router redirects onboarding-done user to /home      | `flutter test test/screens/router_redirect_test.dart` | 6/6 pass (incl. cold-launch /home case) | PASS |
| Chunk card shows always-visible Complete/Skip (no hover) | `flutter test test/screens/chunk_card_hover_test.dart` | 7/7 pass; `find.byType(AnimatedOpacity)` findsNothing confirmed | PASS |
| Clock-time range "9:25 AM – 9:50 AM" renders for displayStartMinutes=565 | `flutter test test/screens/chunk_card_goal_name_test.dart` | 4/4 pass; SCHED-01 group passes | PASS |
| HomeScreen Now/Next layout + See full schedule      | `flutter test test/screens/active_chunk_card_test.dart` | 14/14 pass    | PASS    |
| Full suite regression                               | `flutter test`                                                                                                       | 185/185 pass  | PASS    |

### Probe Execution

No phase-declared probes. No conventional `scripts/*/tests/probe-*.sh` files found.

### Requirements Coverage

| Requirement | Source Plan | Description                                                          | Status    | Evidence                                                                          |
| ----------- | ----------- | -------------------------------------------------------------------- | --------- | --------------------------------------------------------------------------------- |
| SCHED-01    | 12-01, 12-02 | Every chunk shows a real clock time, not a frequency label          | SATISFIED | `@HiveField(10) syntheticStartMinutes` persisted; `displayStartMinutes` getter; `formatTimeRange` in `chunk_card.dart` and `active_chunk_card.dart`; SCHED-01 tests pass |
| NAV-01      | 12-02       | App lands on Home, not Goals, after onboarding or cold start         | SATISFIED | `router.dart` returns `'/home'` for `onboardingDone && onOnboarding`; `initialLocation: '/home'`; router_redirect_test passes |
| SCHED-02    | 12-02       | Schedule surfaces clear now/next framing anchored to current time    | SATISFIED | `NowMarker` widget + `nowMarkerIndex` insertion logic in `schedule_screen.dart`; WR-01 algorithm fix applied; omitted when all chunks resolved |
| SCHED-03    | 12-02       | Chunk complete/skip actions discoverable without hover               | SATISFIED | `AnimatedOpacity` hover overlay fully removed; `FilledButton.icon` "Complete" + `OutlinedButton.icon` "Skip" always visible; chunk_card_hover_test.dart 7/7 pass |
| NAV-02      | 12-03       | Home leads with live day — current + next chunk, no mere duplication | SATISFIED | `ActiveChunkCard` with Now badge + clock-time + actions; Now/Next labels; "All done today!" state; "See full schedule" link; active_chunk_card_test.dart 14/14 pass |

All 5 requirements assigned to Phase 12 in REQUIREMENTS.md are satisfied. No orphaned requirements.

### Anti-Patterns Found

| File                              | Line  | Pattern            | Severity | Impact                                               |
| --------------------------------- | ----- | ------------------ | -------- | ---------------------------------------------------- |
| *(none)*                          | —     | —                  | —        | No TBD/FIXME/XXX markers; no stub returns; no unresolved debt markers found in any phase-modified file |

Code review findings (WR-01 through WR-04) were all resolved in REVIEW-FIX.md commit e5a9e6c/ec5fc09/c419652/8a2f60e. Post-fix code is clean.

Note: `schedule_screen.dart` retains a local `static const Map<int, Color> _moodColors` (code review IN-01) that duplicates `ThemeNotifier.moodSeeds`. This is an info-level inconsistency raised in the review but classified as informational (not a warning) and not in scope for this phase's must-haves. It does not affect any phase success criterion.

### Human Verification Required

#### 1. Cold-Start Landing Screen

**Test:** On a device or simulator with onboarding already complete, force-quit the app and relaunch from cold start.
**Expected:** App opens directly to the Home screen (AppBar title "Canopy"), showing the Now/Next layout with the active schedule, not the Goals screen or onboarding.
**Why human:** The go_router `initialLocation` + `redirect` chain fires at runtime with live `SettingsNotifier` state. Tests exercise the redirect logic but a real cold launch confirms the initialLocation + redirect round-trip on device.

#### 2. Clock-Time Range on a Live Schedule

**Test:** After a morning check-in generates a real schedule, open the Home screen. Inspect the ActiveChunkCard in the "Now" section.
**Expected:** The card shows a clock-time range like "9:25 AM – 9:50 AM · 25 min" (not just "25 min") for the current work chunk.
**Why human:** Clock-time display requires `syntheticStartMinutes` to be non-null in a real schedule. Widget tests confirm the rendering path given a synthetic chunk; a live schedule confirms the schedule generator populates and persists the field end-to-end.

#### 3. NowMarker Placement with Mixed Schedule

**Test:** Open the Schedule screen mid-day with a real schedule containing both past and future chunks.
**Expected:** The "Now" divider (colored dot + trailing line) appears before the first unresolved work chunk that is at or after the current wall time — not at the top, not before an already-past chunk.
**Why human:** NowMarker placement depends on real wall-clock time and live `displayStartMinutes` values in a mixed anchored/discretionary schedule. The static widget test cannot reproduce this combination with real timestamps.

#### 4. Always-Visible Buttons on Touch Surface

**Test:** On a touch device (or iOS/Android simulator), open the Schedule screen and verify Complete and Skip buttons are visible immediately on unresolved chunk rows — no tap, swipe, or hover needed.
**Expected:** "Complete" (filled button) and "Skip" (outlined, error-colored button) are rendered below the chunk title on every unresolved work chunk without any interaction.
**Why human:** Touch affordance cannot be tested with `flutter_test` widget pumping — confirms no platform-specific hide logic exists that widget tests might miss.

#### 5. Complete Action from Home Screen

**Test:** From the Home screen's Now section, tap the "Complete" button on the ActiveChunkCard.
**Expected:** The Now section immediately updates — either the next unresolved chunk becomes the new current chunk (with its own ActiveChunkCard) or "All done today!" appears if no chunks remain.
**Why human:** Cross-screen state mutation through `ScheduleNotifier` and rebuild of `HomeScreen` requires live execution to confirm the Provider-driven rebuild chain works correctly end-to-end.

### Gaps Summary

No gaps found. All 5 must-have truths are VERIFIED, all required artifacts exist and are substantive and wired, all key links are confirmed, the full 185/185 test suite passes, code review warnings (WR-01 through WR-04) are all resolved per REVIEW-FIX.md, and no debt markers (TBD/FIXME/XXX) exist in any phase-modified file.

Status is `human_needed` because 5 behavioral checks require live device verification: cold-start landing, clock-time on real schedule, NowMarker placement with real timestamps, always-visible buttons on touch, and end-to-end Complete action from Home.

---

_Verified: 2026-06-12T14:51:26Z_
_Verifier: Claude (gsd-verifier)_
