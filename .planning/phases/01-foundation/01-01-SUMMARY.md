---
phase: 01-foundation
plan: "01"
subsystem: project-scaffold
tags: [dependencies, directory-structure, pubspec, hive-ce, flutter-setup]
dependency_graph:
  requires: []
  provides: [all-phase-1-packages, lib-directory-structure, clean-main-dart]
  affects: [01-02, 01-03, 01-04]
tech_stack:
  added:
    - hive_ce ^2.19.3
    - hive_ce_flutter ^2.3.4
    - go_router ^17.1.0
    - provider ^6.1.5+1
    - shared_preferences ^2.5.4
    - uuid ^4.5.3
    - intl ^0.20.2
    - path_provider ^2.1.5
    - hive_ce_generator ^1.11.1 (dev)
    - build_runner ^2.4.13 (dev)
  patterns: [directory-per-feature, gitkeep-scaffold]
key_files:
  created:
    - pubspec.yaml (updated with all Phase 1 deps)
    - pubspec.lock
    - build.yaml
    - lib/main.dart (minimal CanopyApp placeholder)
    - lib/data/models/.gitkeep
    - lib/data/repositories/.gitkeep
    - lib/data/database/.gitkeep
    - lib/providers/.gitkeep
    - lib/screens/home/.gitkeep
    - lib/screens/onboarding/.gitkeep
    - lib/screens/goals/.gitkeep
    - lib/screens/schedule/.gitkeep
    - lib/screens/quarterly_review/.gitkeep
    - lib/screens/settings/.gitkeep
  modified:
    - test/widget_test.dart (updated to reference CanopyApp)
decisions:
  - "Used hive_ce over Isar — RESEARCH.md confirmed hive_ce is the selected database (OQ-1 resolved)"
  - "MaterialApp used in placeholder (not MaterialApp.router) — go_router wired in plan 01-04 intentionally"
  - "All entity IDs will use UUID v4 strings, not auto-increment integers"
metrics:
  duration: "2 minutes"
  completed_date: "2026-02-24"
  tasks_completed: 2
  files_created: 15
  files_modified: 1
---

# Phase 1 Plan 01: Dependencies and Directory Scaffold Summary

**One-liner:** All Phase 1 packages installed via pubspec.yaml with hive_ce_generator build.yaml config and clean 11-directory lib scaffold replacing the Flutter counter demo.

## What Was Done

### Task 1: Add all Phase 1 dependencies to pubspec.yaml and create build.yaml

Updated `pubspec.yaml` to include the full Phase 1 runtime and dev dependency stack. Created `build.yaml` at the project root to configure hive_ce_generator for TypeAdapter code generation.

**Packages added (runtime):**
- `hive_ce: ^2.19.3` — local database
- `hive_ce_flutter: ^2.3.4` — Flutter integration for hive_ce
- `go_router: ^17.1.0` — declarative routing with Web URL support
- `provider: ^6.1.5+1` — ChangeNotifier state management
- `shared_preferences: ^2.5.4` — primitive key-value settings storage
- `uuid: ^4.5.3` — UUID v4 string IDs for all entities
- `intl: ^0.20.2` — date/time formatting
- `path_provider: ^2.1.5` — platform-specific file paths for Hive init

**Packages added (dev):**
- `hive_ce_generator: ^1.11.1` — TypeAdapter code generation
- `build_runner: ^2.4.13` — code generation runner

`flutter pub get` resolved 71 new dependencies without conflicts. Exit code 0 confirmed.

### Task 2: Create project directory structure and minimal main.dart placeholder

Created 10 leaf directories under `lib/` with `.gitkeep` files:
- `lib/data/models/` — Hive entity models
- `lib/data/repositories/` — repository interfaces
- `lib/data/database/` — database init and migration runner
- `lib/providers/` — ChangeNotifier classes
- `lib/screens/home/` — home screen
- `lib/screens/onboarding/` — onboarding screen
- `lib/screens/goals/` — goals screen
- `lib/screens/schedule/` — schedule screen
- `lib/screens/quarterly_review/` — quarterly review screen
- `lib/screens/settings/` — settings screen

Replaced `lib/main.dart` (Flutter counter demo) with minimal `CanopyApp` StatelessWidget:
- Imports only `package:flutter/material.dart`
- `main()` calls `runApp(const CanopyApp())`
- `CanopyApp` returns `MaterialApp` with Material 3 theme (`ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent)`)
- Home is `Scaffold(body: Center(child: Text('Canopy')))`
- No `MyHomePage`, no `_counter`, no `FloatingActionButton`

`flutter analyze` reports **No issues found.**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated widget_test.dart to reference CanopyApp**
- **Found during:** Task 2 (post-analyze)
- **Issue:** `test/widget_test.dart` still referenced `MyApp` and counter widgets after `lib/main.dart` was replaced, causing `flutter analyze` to report 1 error (`creation_with_non_type`)
- **Fix:** Replaced the counter smoke test with a minimal `CanopyApp` render test; removed the now-unused `package:flutter/material.dart` import from the test file
- **Files modified:** `test/widget_test.dart`
- **Commit:** 8fb1a77

## Verification Results

| Check | Result |
|-------|--------|
| `flutter pub get` exit code | 0 (success) |
| `flutter analyze` issues | 0 |
| `hive_ce` in pubspec.yaml | Confirmed |
| `go_router` in pubspec.yaml | Confirmed |
| 10 lib subdirectories created | Confirmed |
| `lib/main.dart` has no counter code | Confirmed |
| `build.yaml` created | Confirmed |

## Commits

| Task | Hash | Description |
|------|------|-------------|
| Task 1 | 800d7fd | chore(01-01): add all Phase 1 dependencies and create build.yaml |
| Task 2 | 8fb1a77 | feat(01-01): create project directory structure and minimal main.dart placeholder |
