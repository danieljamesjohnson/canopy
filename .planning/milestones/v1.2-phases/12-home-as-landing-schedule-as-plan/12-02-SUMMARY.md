---
phase: 12-home-as-landing-schedule-as-plan
plan: "02"
subsystem: navigation-and-schedule-ui
tags: [router, chunk-card, now-marker, material3, schedule]
dependency_graph:
  requires:
    - "@HiveField(10) int? syntheticStartMinutes on ScheduledChunk (12-01)"
    - "int? get displayStartMinutes on ScheduledChunk (12-01)"
  provides:
    - "router.dart redirect returns '/home' for onboarding-done users (NAV-01)"
    - "_formatTimeRange(int startMin, int endMin) in chunk_card.dart (SCHED-01)"
    - "clock-time secondary text reading displayStartMinutes in ChunkCard (SCHED-01)"
    - "always-visible FilledButton.icon Complete + OutlinedButton.icon Skip in ChunkCard (SCHED-03)"
    - "NowMarker StatelessWidget in lib/screens/schedule/widgets/now_marker.dart (SCHED-02)"
    - "nowMarkerIndex insertion logic in ScheduleScreen._buildActiveChunkItems (SCHED-02)"
  affects:
    - "lib/router.dart"
    - "lib/screens/schedule/widgets/chunk_card.dart"
    - "lib/screens/schedule/widgets/now_marker.dart"
    - "lib/screens/schedule/schedule_screen.dart"
    - "lib/screens/home/home_screen.dart"
    - "test/screens/router_redirect_test.dart"
    - "test/screens/chunk_card_hover_test.dart"
    - "test/screens/chunk_card_goal_name_test.dart"
tech_stack:
  added: []
  patterns:
    - "Router redirect guard: single-line change returning '/home' instead of '/goals'"
    - "_formatTimeRange helper extending _formatMinutes for START–END range strings"
    - "Always-visible FilledButton.icon + OutlinedButton.icon row replacing AnimatedOpacity hover overlay"
    - "NowMarker StatelessWidget: ExcludeSemantics + Row with lead line, primary dot, label, trailing line"
    - "nowMarkerIndex: single-pass scan computing insertion index before ListView build"
key_files:
  created:
    - lib/screens/schedule/widgets/now_marker.dart
  modified:
    - lib/router.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/schedule_screen.dart
    - lib/screens/home/home_screen.dart
    - test/screens/router_redirect_test.dart
    - test/screens/chunk_card_hover_test.dart
    - test/screens/chunk_card_goal_name_test.dart
decisions:
  - "[Phase 12-02]: Tooltip wrapper used for Complete/Skip buttons since FilledButton.icon and OutlinedButton.icon do not accept a tooltip parameter in Flutter 3.18; Tooltip widget satisfies the UI-SPEC accessibility requirement"
  - "[Phase 12-02]: ThemeNotifier fake added to router_redirect_test.dart MultiProvider since NAV-01 now renders HomeScreen (not GoalsScreen) and HomeScreen watches ThemeNotifier"
  - "[Phase 12-02]: NowMarker omitted when no unresolved work chunk exists (nowMarkerIndex stays null) — per RESEARCH Open Question 1 resolution"
  - "[Phase 12-02]: Swipe gestures (SwipeableChunkCard/Dismissible) coexist with always-visible buttons per UI-SPEC Chunk Action Contract; no changes to SwipeableChunkCard"
  - "[Phase 12-02]: _HoverableChunkContent renamed to _WorkChunkContent (StatefulWidget → StatelessWidget) since _hovered state is entirely removed"
metrics:
  duration: "15 minutes"
  completed: "2026-06-12"
  tasks: 3
  files: 8
---

# Phase 12 Plan 02: Schedule as Plan — Router, ChunkCard, NowMarker Summary

**One-liner:** Fixed post-onboarding router redirect to /home, added _formatTimeRange clock-time display and always-visible Complete/Skip buttons in ChunkCard, and created NowMarker widget inserted before the first unresolved work chunk in ScheduleScreen.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (TDD) | Router redirect to /home + update router_redirect_test | f17133d | lib/router.dart, test/screens/router_redirect_test.dart, lib/screens/home/home_screen.dart |
| 2 (TDD) | Clock-time display + always-visible Complete/Skip in ChunkCard | 84da090 | lib/screens/schedule/widgets/chunk_card.dart, test/screens/chunk_card_hover_test.dart, test/screens/chunk_card_goal_name_test.dart |
| 3 | NowMarker widget + insertion in ScheduleScreen | f41a35e | lib/screens/schedule/widgets/now_marker.dart, lib/screens/schedule/schedule_screen.dart |

## What Was Built

### lib/router.dart
- Changed redirect: `return '/goals'` → `return '/home'` for the `onboardingDone && onOnboarding` guard (NAV-01)
- No other changes — route table and imports unchanged

### lib/screens/schedule/widgets/chunk_card.dart
- Added `_formatTimeRange(int startMin, int endMin)` returning `'${_formatMinutes(startMin)} – ${_formatMinutes(endMin)}'` (en-dash per UI-SPEC)
- Replaced secondary-text block: shows `_formatTimeRange(displayStartMinutes!, displayStartMinutes! + durationMinutes)` when `chunk.displayStartMinutes != null`, falls back to `'${durationMinutes} min'` when null; rationale text still renders below when goalName and displayRationale are present
- Removed hover overlay entirely: `_hovered` bool, `onEnter`/`onExit` callbacks, `AnimatedOpacity`+`Positioned` block all deleted
- Renamed `_HoverableChunkContent` (StatefulWidget) to `_WorkChunkContent` (StatelessWidget) — no state left after hover removal
- Added always-visible action row (rendered only when `!isResolved`): `Tooltip(message: 'Complete', child: FilledButton.icon(...markComplete...))` + `Tooltip(message: 'Skip', child: OutlinedButton.icon(...markSkipped...))` with `VisualDensity.compact`; Skip uses `colorScheme.error` foreground/border
- MouseRegion retained with `cursor: SystemMouseCursors.click` only — no content reveal
- Left color bar width corrected from 5dp to 4dp (UI-SPEC standardizes to 4dp)

### lib/screens/schedule/widgets/now_marker.dart (NEW)
- `class NowMarker extends StatelessWidget` with `const NowMarker({super.key})`
- Row: 40dp lead line (primary, opacity 0.6) + 8dp gap + 8dp circle dot (primary) + 8dp gap + "Now" label (labelMedium, primary, w600) + Expanded trailing line (primary, opacity 0.6)
- Wrapped in `ExcludeSemantics` (decorative)
- Margins: `EdgeInsets.symmetric(horizontal: 16, vertical: 4)`
- All colors from `Theme.of(context).colorScheme.primary`

### lib/screens/schedule/schedule_screen.dart
- Added `import 'widgets/now_marker.dart'`
- Extracted `_buildActiveChunkItems(BuildContext, List<ScheduledChunk>)` replacing the inline for-loop:
  - Computes `nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute`
  - Single-pass scan: `nowMarkerIndex ??= i` for first unresolved work chunk (fallback), advances to first where `(displayStartMinutes ?? 9999) >= nowMinutes` then `break`
  - When no unresolved work chunk exists, `nowMarkerIndex` is null → no NowMarker rendered
  - Inserts `const NowMarker()` at `nowMarkerIndex` before the chunk at that position
- Skipped-section appended after the items list (unchanged)

### lib/screens/home/home_screen.dart (deviation fix)
- Added try/catch to `_checkReviewWindow()` to guard against Hive boxes not open (see Deviations)

### test/screens/router_redirect_test.dart
- Added `_FakeThemeNotifier` (overrides `init()` and `isPreCheckin`) since HomeScreen now renders when redirect lands on /home
- Added `ThemeNotifier` to MultiProvider in `_pumpRouter`
- Updated the `/onboarding→/goals` assertion to `/onboarding→/home` (NAV-01)
- Added two new test cases: `/onboarding` redirects to `/home` and cold-launch lands on `/home`

### test/screens/chunk_card_hover_test.dart (rewritten)
- Replaced all AnimatedOpacity opacity assertions with always-visible pattern:
  - `find.widgetWithText(FilledButton, 'Complete')` findsOneWidget on unresolved (no hover)
  - `find.widgetWithText(OutlinedButton, 'Skip')` findsOneWidget on unresolved (no hover)
  - `find.byType(FilledButton/OutlinedButton)` findsNothing on completed and skipped chunks
  - Tap Complete → `notifier.lastCompletedId == chunk.id`
  - Tap Skip → `notifier.lastSkippedId == chunk.id`
  - `find.byType(AnimatedOpacity)` findsNothing
- Added `_FakeScheduleNotifier` (overrides markComplete/markSkipped to capture IDs)

### test/screens/chunk_card_goal_name_test.dart (extended)
- Added SCHED-01 group with two cases:
  - `syntheticStartMinutes=565` renders "9:25 AM – 9:50 AM"
  - No syntheticStartMinutes renders "25 min" fallback
- Added `_FakeScheduleNotifier` provider for button onPressed wiring

## Acceptance Criteria Verification

```
grep -c "return '/home'" lib/router.dart               → 1  ✓
grep -c "return '/goals'" lib/router.dart              → 0  ✓
flutter test test/screens/router_redirect_test.dart    → 6/6 pass  ✓

grep -c '_formatTimeRange' lib/screens/schedule/widgets/chunk_card.dart  → 3  ✓ (def + 2 call sites)
grep -c 'AnimatedOpacity' lib/screens/schedule/widgets/chunk_card.dart   → 0  ✓
grep -c 'FilledButton.icon' lib/screens/schedule/widgets/chunk_card.dart → 1  ✓
grep -c 'OutlinedButton.icon' lib/screens/schedule/widgets/chunk_card.dart → 1  ✓
flutter test chunk_card_hover_test.dart chunk_card_goal_name_test.dart   → 11/11 pass  ✓

grep -c 'class NowMarker' lib/screens/schedule/widgets/now_marker.dart   → 1  ✓
grep -c 'NowMarker' lib/screens/schedule/schedule_screen.dart            → 3  ✓ (import + insertion + method)
grep -c 'nowMarkerIndex' lib/screens/schedule/schedule_screen.dart       → 6  ✓
flutter analyze now_marker.dart schedule_screen.dart                     → No issues  ✓
flutter test (full suite)                                                 → 171/171 pass  ✓
```

## Hover Overlay Removal Confirmation

The hover overlay is **fully removed**, not just hidden at opacity 0:
- `_hovered` bool state: deleted
- `MouseRegion.onEnter` / `onExit` callbacks: deleted
- `Positioned` wrapping `AnimatedOpacity`: deleted
- `AnimatedOpacity` itself: deleted
- `_HoverableChunkContent` as `StatefulWidget`: converted to `_WorkChunkContent` as `StatelessWidget`

`MouseRegion` remains solely for `cursor: SystemMouseCursors.click` (desktop cursor affordance).

## NowMarker Omission Behavior

When all work chunks are resolved (no unresolved work chunk exists), `nowMarkerIndex` stays `null` throughout the scan loop. The `if (i == nowMarkerIndex)` condition is never true, so no `const NowMarker()` is inserted. This matches RESEARCH Open Question 1 resolution: "All done today!" makes the marker redundant.

## Swipe Gestures Coexistence

`SwipeableChunkCard` / `Dismissible` swipe-right-complete and swipe-left-skip are untouched. The always-visible buttons live inside `_WorkChunkContent` (inner `ChunkCard` content), which is composed inside `SwipeableChunkCard` — they are orthogonal input modalities as specified in UI-SPEC §Chunk Action Contract and RESEARCH Open Question 2.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing error handling] HomeScreen._checkReviewWindow unguarded Hive access**
- **Found during:** Task 1 (when NAV-01 redirect now renders HomeScreen in tests instead of GoalsScreen)
- **Issue:** `_checkReviewWindow()` directly instantiates `HiveCompletionLogRepository` and `HiveQuarterlySnapshotRepository` without a try/catch. When called from `initState` in test environments where Hive boxes are not open, the error propagates as an unhandled async Zone exception, causing test framework failures.
- **Fix:** Wrapped the method body in `try/catch (_)` with a comment explaining the safe fallback behavior (`_inReviewWindow` stays false).
- **Files modified:** `lib/screens/home/home_screen.dart`
- **Commit:** f17133d

**2. [Rule 1 - Bug] FilledButton.icon and OutlinedButton.icon have no `tooltip` parameter**
- **Found during:** Task 2 (compile error when following PATTERNS.md `tooltip:` property)
- **Issue:** The Flutter 3.18 `FilledButton.icon` and `OutlinedButton.icon` factory constructors do not accept a `tooltip` named parameter; PATTERNS.md pattern is incorrect for this Flutter version.
- **Fix:** Wrapped each button in a `Tooltip` widget with `message:` matching the button label ("Complete", "Skip"). This satisfies the UI-SPEC accessibility requirement (tooltip matching label text) correctly.
- **Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`
- **Commit:** 84da090

**3. [Rule 1 - Bug] `_HoverableChunkContent` left color bar width 5dp → 4dp**
- **Found during:** Task 2 (reviewing existing code while rewriting the widget)
- **Issue:** Existing code used `width: 5` for the left color bar; UI-SPEC standardizes to 4dp.
- **Fix:** Changed `width: 5` to `width: 4` and updated the matching `Padding(padding: const EdgeInsets.only(left: 5))` to `left: 4`.
- **Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`
- **Commit:** 84da090

## Known Stubs

None. All UI elements are fully wired to live data.

## Threat Flags

No new security surface introduced. All changes are local UI reorganization. The `markComplete`/`markSkipped` call sites reuse the existing validated notifier methods (idempotent guards per STRIDE T-12-03 — disposition: accept, already mitigated).

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/router.dart exists | FOUND |
| lib/screens/schedule/widgets/chunk_card.dart exists | FOUND |
| lib/screens/schedule/widgets/now_marker.dart exists | FOUND |
| lib/screens/schedule/schedule_screen.dart exists | FOUND |
| test/screens/router_redirect_test.dart exists | FOUND |
| test/screens/chunk_card_hover_test.dart exists | FOUND |
| test/screens/chunk_card_goal_name_test.dart exists | FOUND |
| commit f17133d (Task 1 - NAV-01 router redirect) | FOUND |
| commit 84da090 (Task 2 - SCHED-01/SCHED-03 ChunkCard) | FOUND |
| commit f41a35e (Task 3 - SCHED-02 NowMarker) | FOUND |
