---
phase: 12-home-as-landing-schedule-as-plan
plan: "03"
subsystem: home-ui
tags: [home, active-chunk-card, now-next, nav-02, material3, tdd]
dependency_graph:
  requires:
    - "int? get displayStartMinutes on ScheduledChunk (12-01)"
    - "@HiveField(10) int? syntheticStartMinutes on ScheduledChunk (12-01)"
  provides:
    - "ActiveChunkCard StatelessWidget (lib/screens/home/widgets/active_chunk_card.dart)"
    - "HomeScreen Now/Next layout with currentChunk/nextChunk split (NAV-02)"
    - "See full schedule TextButton → context.go('/schedule') in HomeScreen (NAV-02)"
    - "lib/utils/time_format.dart shared formatMinutes/formatTimeRange/hexToColor"
    - "test/screens/active_chunk_card_test.dart NAV-02 widget test (14 cases)"
  affects:
    - "lib/screens/home/home_screen.dart"
    - "lib/screens/home/widgets/active_chunk_card.dart"
    - "lib/utils/time_format.dart"
    - "test/screens/active_chunk_card_test.dart"
tech_stack:
  added: []
  patterns:
    - "ActiveChunkCard: StatelessWidget + Card + 4dp left color bar + Stack layout"
    - "Tooltip wrapper for FilledButton.icon/OutlinedButton.icon (Flutter 3.18 no tooltip param)"
    - "unresolvedWork.first / unresolvedWork[1] for currentChunk/nextChunk split"
    - "context.go('/schedule') branch-switch (no back button) for See full schedule"
    - "TDD RED/GREEN: test file committed before implementation"
key_files:
  created:
    - lib/screens/home/widgets/active_chunk_card.dart
    - lib/utils/time_format.dart
    - test/screens/active_chunk_card_test.dart
  modified:
    - lib/screens/home/home_screen.dart
decisions:
  - "[Phase 12-03]: Formatters (formatMinutes, formatTimeRange, hexToColor) extracted to lib/utils/time_format.dart rather than duplicated locally — creating the shared util does not require editing chunk_card.dart (chunk_card.dart keeps its own private _formatMinutes/_formatTimeRange). Both files benefit without file-disjoint parallelism violation."
  - "[Phase 12-03]: Tooltip wrapper used for FilledButton.icon and OutlinedButton.icon in ActiveChunkCard — same pattern as 12-02 deviation; Flutter 3.18 lacks tooltip parameter on these constructors"
  - "[Phase 12-03]: Mood row relocated below Now/Next sections per UI-SPEC layout; Divider removed — the section labels provide visual separation"
  - "[Phase 12-03]: Empty state (_buildEmptyState) and ReviewBanner/EndOfDayCard/ScheduleProgressBar wiring left unchanged"
metrics:
  duration: "4 minutes"
  completed: "2026-06-12"
  tasks: 2
  files: 4
---

# Phase 12 Plan 03: Home as Landing — ActiveChunkCard + Now/Next Layout Summary

**One-liner:** Created ActiveChunkCard with "Now" badge and always-visible Complete/Skip buttons; refactored HomeScreen to Now/Next layout with currentChunk/nextChunk split, relocated mood row, and "See full schedule" TextButton (NAV-02).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Add failing test for ActiveChunkCard | eb78b5c | test/screens/active_chunk_card_test.dart |
| 1 (GREEN) | Implement ActiveChunkCard widget + shared utils | 097851e | lib/screens/home/widgets/active_chunk_card.dart, lib/utils/time_format.dart |
| 2 | HomeScreen Now/Next refactor + HomeScreen NAV-02 tests | 3afa76f | lib/screens/home/home_screen.dart, test/screens/active_chunk_card_test.dart |

## What Was Built

### lib/utils/time_format.dart (NEW)
- `hexToColor(String hex)` — public equivalent of chunk_card.dart's top-level hexToColor
- `formatMinutes(int minutes)` — public 12-hour formatter (mirrors _formatMinutes)
- `formatTimeRange(int startMin, int endMin)` — public START–END range formatter (mirrors _formatTimeRange)
- Imported by active_chunk_card.dart only; chunk_card.dart retains its own private copies (no edit required — file-disjoint parallelism preserved)

### lib/screens/home/widgets/active_chunk_card.dart (NEW)
- `class ActiveChunkCard extends StatelessWidget` — required `ScheduledChunk chunk`
- 4dp left color bar (goal color via `hexToColor` / fallback `colorScheme.primary`)
- Goal name via `context.read<GoalsNotifier>().goals` lookup (`titleMedium` w600)
- Clock-time range "START – END · N min" when `displayStartMinutes != null`; duration-only "N min" fallback
- "Now" badge: `Container` with `colorScheme.primary` background + `colorScheme.onPrimary` 12sp text
- Always-visible action row: `Tooltip` + `FilledButton.icon` (Complete) + `Tooltip` + `OutlinedButton.icon` (Skip, error-colored)
- All colors from `colorScheme` — zero `Colors.*` hardcoded references

### lib/screens/home/home_screen.dart (MODIFIED)
- Added `import 'widgets/active_chunk_card.dart'`
- Replaced `nextChunk` computation with `unresolvedWork` list → `currentChunk = unresolvedWork.firstOrNull`, `nextChunk = unresolvedWork.length > 1 ? unresolvedWork[1] : null`
- New layout under `hasScheduleToday` branch:
  1. ScheduleProgressBar (unchanged)
  2. ReviewBanner / EndOfDayCard (unchanged, conditional)
  3. "Now" section label (`labelMedium`, `onSurfaceVariant`, letterSpacing 0.8)
  4. `ActiveChunkCard(chunk: currentChunk)` OR "All done today!" text when `currentChunk == null`
  5. "Next" section label + compact chunk row when `nextChunk != null`
  6. Mood row (relocated below Now/Next; same widget code)
  7. "See full schedule" `TextButton` → `context.go('/schedule')`
- Removed `Divider(height: 1)` between mood row and sections (section labels provide separation)
- Empty state (`_buildEmptyState`) unchanged
- `_lookupGoalName` unchanged (reused for Next chunk compact row)

### test/screens/active_chunk_card_test.dart (NEW)
- `ActiveChunkCard (NAV-02)` group (8 cases): Complete/Skip always visible, Now badge, clock-time range, duration fallback, tap callbacks, no-hardcoded-Colors smoke test
- `HomeScreen Now/Next layout (NAV-02)` group (6 cases): Now label, ActiveChunkCard rendered, Next label, See full schedule TextButton, All done today!, no ActiveChunkCard when resolved
- Uses `_FakeScheduleNotifierWithSchedule` (overrides `hasScheduleToday`/`todaySchedule`/`moodIndex`) and `_FakeThemeNotifier` to avoid Hive

## Formatter Extraction Decision

**Choice: create `lib/utils/time_format.dart` (Option b from plan).**

The plan offered two options:
- (a) Duplicate formatters locally in `active_chunk_card.dart`
- (b) Extract to a shared util, provided it does not require editing `chunk_card.dart`

Option (b) was chosen. `chunk_card.dart` (owned by plan 12-02) was NOT modified — it keeps its own private `_formatMinutes` and `_formatTimeRange`. `time_format.dart` exports public equivalents consumed only by `active_chunk_card.dart`. This satisfies the file-disjoint parallelism constraint while avoiding code duplication.

## Mood Row Relocation Confirmation

The mood row (emoji + description `Row`) was relocated from above the "Up next" section to below the Now/Next sections, as specified in UI-SPEC § Component Inventory #1 HomeScreen layout. The widget code is identical; only its position in the `Column.children` list changed.

## Empty State Confirmation

`_buildEmptyState` (the "No schedule yet" + BreathingPulseCta branch triggered when `!hasScheduleToday`) is completely unchanged. All tests from prior phases continue to pass (185/185 full suite green).

## Acceptance Criteria Verification

```
grep -c 'class ActiveChunkCard' active_chunk_card.dart        → 1  ✓
grep -c 'FilledButton.icon' active_chunk_card.dart            → 1  ✓
grep -c 'OutlinedButton.icon' active_chunk_card.dart          → 1  ✓
grep -c 'displayStartMinutes' active_chunk_card.dart          → 2  ✓
grep -c 'Colors\.' active_chunk_card.dart                     → 0  ✓
flutter analyze active_chunk_card.dart                        → No issues  ✓

grep -c 'ActiveChunkCard' home_screen.dart                    → 1 (usage; import uses filename)  ~✓
  (import 'widgets/active_chunk_card.dart' present at line 14)
grep -c "context.go('/schedule')" home_screen.dart            → 1  ✓
grep -c 'See full schedule' home_screen.dart                  → 2 (comment + Text)  ✓
grep -c 'currentChunk' home_screen.dart                       → 3  ✓
flutter test test/screens/active_chunk_card_test.dart         → 14/14 pass  ✓
flutter test (full suite)                                     → 185/185 pass  ✓
```

Note: `grep -c 'ActiveChunkCard' home_screen.dart` returns 1, not 2. The import line uses the filename `active_chunk_card.dart` (not the class name). The class is imported and used — the criterion intent is satisfied even though the grep literal count is 1.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FilledButton.icon and OutlinedButton.icon have no `tooltip` parameter in Flutter 3.18**
- **Found during:** Task 1 (compile failure when following PATTERNS.md pattern with `tooltip:` as a named parameter)
- **Issue:** `FilledButton.icon` and `OutlinedButton.icon` constructors do not accept a `tooltip` parameter in Flutter 3.18 — this was already documented as Deviation 2 in the 12-02 SUMMARY.
- **Fix:** Wrapped each button in a `Tooltip(message: '...')` widget. Satisfies UI-SPEC Accessibility Contract.
- **Files modified:** `lib/screens/home/widgets/active_chunk_card.dart`
- **Commit:** 097851e

## Known Stubs

None. All UI elements are fully wired to live data from GoalsNotifier and ScheduleNotifier.

## Threat Flags

No new security surface introduced beyond what the STRIDE register (T-12-05, T-12-06, T-12-SC) already covers. ActiveChunkCard reuses the existing idempotent `markComplete`/`markSkipped` notifier methods. Goal name/color is user-owned local data. No packages added.

## TDD Gate Compliance

- RED gate commit: `eb78b5c` — `test(12-03): add failing test for ActiveChunkCard (NAV-02)` (compilation error: no ActiveChunkCard class)
- GREEN gate commit: `097851e` — `feat(12-03): implement ActiveChunkCard widget with Now badge and actions` (all 8 ActiveChunkCard tests pass)
- REFACTOR: not needed — implementation was clean on first pass
- Task 2 extended the same test file (GREEN pattern, no separate RED/GREEN cycle needed since HomeScreen tests depend on Task 1 completion)

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/screens/home/widgets/active_chunk_card.dart exists | FOUND |
| lib/utils/time_format.dart exists | FOUND |
| test/screens/active_chunk_card_test.dart exists | FOUND |
| lib/screens/home/home_screen.dart exists | FOUND |
| commit eb78b5c (RED gate) | FOUND |
| commit 097851e (GREEN gate) | FOUND |
| commit 3afa76f (Task 2 — HomeScreen + tests) | FOUND |
