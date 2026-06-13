---
phase: 06-desktop-and-web-polish
plan: 01
subsystem: infra
tags: [hive, window_manager, flutter, testing, schema-migration]

requires:
  - phase: 02-data-and-storage
    provides: AppSettings Hive type at typeId 6; runMigrations(prefs) scaffold
provides:
  - window_manager: ^0.5.1 dependency available on desktop targets
  - AppSettings.moodSeedArgb int? field at @HiveField(5) — nullable; null = pre-check-in "curious"
  - Hive currentSchemaVersion bumped to 3 with _migration2to3 no-op
  - test/test_helpers/mood_pump.dart — pumpWithMood(tester, child, {moodIndex=3, extraProviders})
  - test/test_helpers/viewport.dart — setViewport(tester, size) with addTearDown lock
  - macOS host verified compatible (MainFlutterWindow already declares NSWindow)
affects: [theme_notifier, window_setup, responsive_shell, hover_affordances, Wave 4 widget tests]

tech-stack:
  added: [window_manager ^0.5.1]
  patterns:
    - "Hive additive schema bump: nullable field + no-op migration (continues Phase 2 _migration1to2 pattern)"
    - "Mood-pinned widget test pump helper (UI-SPEC §Widget Test Mood-Pinning Strategy)"
    - "Viewport teardown lock via addTearDown(tester.view.reset) (RESEARCH.md Pitfall 4)"

key-files:
  created:
    - test/test_helpers/mood_pump.dart
    - test/test_helpers/viewport.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - lib/data/models/app_settings.dart
    - lib/data/models/app_settings.g.dart
    - lib/data/database/migrations.dart
    - linux/flutter/generated_plugin_registrant.cc
    - linux/flutter/generated_plugins.cmake
    - macos/Flutter/GeneratedPluginRegistrant.swift
    - windows/flutter/generated_plugin_registrant.cc
    - windows/flutter/generated_plugins.cmake

key-decisions:
  - "window_manager pinned at ^0.5.1 (caret) to match every other dependency in pubspec; not added to dev_dependencies because lib/main.dart will import it for runtime window-min-size"
  - "AppSettings.moodSeedArgb is nullable int? (not int with default 0) — null is the semantic 'pre-check-in / curious' state per CONTEXT D-10. Avoids needing migration logic for pre-Phase-6 records (Hive returns null for missing fields)"
  - "_migration2to3 is intentionally a no-op — the schema bump is purely a version marker; the on-disk reader handles new nullable fields transparently"
  - "macOS Runner already extends NSWindow; no Swift edit required for window_manager compatibility"
  - "pumpWithMood does NOT instantiate a real ThemeNotifier — bypasses the 20-minute time-of-day ticker to keep widget-test color assertions order-independent (UI-SPEC: Test fixture: Time-of-day modulation disabled under flutter test)"

patterns-established:
  - "Pattern G (Hive additive bump): nullable field + same-shape no-op migration; pubspec/migrations/AppSettings change atomically in one commit"
  - "Pattern 5 (mood_pump): wrap test widget in MultiProvider + MaterialApp with ColorScheme.fromSeed(moodSeeds[i]); default moodIndex 3 = #4A8C7A"
  - "Pattern 6 (viewport): physicalSize+devicePixelRatio with addTearDown(view.reset)"

requirements-completed: [AC-3, AC-5, AC-6]

duration: 1h 5m
completed: 2026-05-13
---

# Phase 06 Plan 01: Foundations Summary

**Phase 6 foundations laid — window_manager available on desktop, Hive schema additively bumped to v3 with a nullable moodSeedArgb slot on AppSettings, and the two test helpers (pumpWithMood, setViewport) that every Phase 6 widget test will rely on are committed. macOS host verified compatible.**

## Performance

- **Duration:** ~65 min (includes an interrupted-and-resumed segment after a mid-run connection drop; orchestrator finished the remaining work directly in the same worktree)
- **Started:** 2026-05-12T15:05:07Z
- **Completed:** 2026-05-13T~06:50Z
- **Tasks:** 2/2 committed
- **Files modified:** 12 (2 created, 10 modified)

## Accomplishments
- Added `window_manager: ^0.5.1` to pubspec dependencies and regenerated plugin registrants for Linux/macOS/Windows. `pubspec.lock` is consistent.
- Bumped Hive `currentSchemaVersion` 2 → 3 with `_migration2to3` no-op; added `@HiveField(5) int? moodSeedArgb` to `AppSettings`; regenerated `app_settings.g.dart` cleanly via build_runner.
- Created `test/test_helpers/mood_pump.dart` (pumpWithMood) and `test/test_helpers/viewport.dart` (setViewport with addTearDown reset lock).
- Verified `macos/Runner/MainFlutterWindow.swift` already declares `class MainFlutterWindow: NSWindow` — window_manager macOS host requirement satisfied with no Swift edit.
- `flutter analyze` is clean on `lib/`. Existing test suite (54 tests) still passes — no regressions.

## Task Commits

Each task was committed atomically:

1. **Task 1: window_manager dep + Hive schema v3 for moodSeedArgb** — `e68f3a4` (feat)
2. **Task 2: pumpWithMood + setViewport helpers; verify macOS NSWindow host** — `33cde60` (test)

## Files Created/Modified

Created:
- `test/test_helpers/mood_pump.dart` — pumpWithMood helper, default moodIndex 3 = #4A8C7A test-fixture seed
- `test/test_helpers/viewport.dart` — setViewport helper with addTearDown(tester.view.reset)

Modified:
- `pubspec.yaml` — `window_manager: ^0.5.1` added under dependencies
- `pubspec.lock` — regenerated by `flutter pub get`
- `lib/data/models/app_settings.dart` — `@HiveField(5) int? moodSeedArgb` added with D-10 doc comment
- `lib/data/models/app_settings.g.dart` — regenerated to write/read field 5
- `lib/data/database/migrations.dart` — `currentSchemaVersion = 3`, `_migration2to3` no-op registered
- Linux/macOS/Windows plugin registrants — auto-regenerated for window_manager

## Verification

- `flutter pub get` → exit 0
- `dart run build_runner build --delete-conflicting-outputs` → app_settings.g.dart regenerated, writes/reads `moodSeedArgb` at slot 5
- `flutter analyze` (lib only) → 0 issues
- `flutter test` (existing suite) → all 54 tests pass
- `dart format` on the two new helpers → no changes (already canonical)
- Acceptance criteria from PLAN: all 14 grep gates green; macOS host verified compatible

## Known Transient (Documented)

`flutter analyze test/test_helpers/` reports 2 errors:
```
error • Target of URI doesn't exist: 'package:canopy/providers/theme_notifier.dart' • test/test_helpers/mood_pump.dart:12:8
error • Undefined name 'ThemeNotifier' • test/test_helpers/mood_pump.dart:30:16
```
This is explicitly anticipated by the plan (line 178) and CONTEXT — `ThemeNotifier.moodSeeds` is supplied by **Plan 06-02 (Wave 2)**. Plan 02's verify step re-runs `flutter analyze` end-to-end and these errors will clear there. The helper file is otherwise syntactically valid (`dart format` accepts it).

## Notes on the Resumed Run

The initial executor agent ran for ~57 min in worktree `agent-a3cf3afb0df0d1f10` and completed all Task 1 source edits (deps, Hive schema, adapter regen) before the upstream API connection dropped — no commit had been made and no SUMMARY existed at that point. The orchestrator inspected the worktree, found Task 1's edits intact, ran the verify gate (analyze clean, all grep gates green), committed Task 1, then executed Task 2 directly in the same worktree (helpers, macOS check, format gate, test suite), committed it, and wrote this SUMMARY. The worktree branch (`worktree-agent-a3cf3afb0df0d1f10`) and the two atomic commits above are the canonical record.
