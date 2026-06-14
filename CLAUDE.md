# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Get dependencies
flutter pub get

# Run the app (debug)
flutter run

# Run on a specific device
flutter run -d <device_id>

# Build for a platform
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
flutter build windows    # Windows

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze and lint
flutter analyze

# Format code
dart format lib/

# Clean build artifacts
flutter clean
```

## Local hosting for UAT

While we're still getting through the basics (early UAT), **host the DEBUG build, not
release** — diagnostics over speed, deliberately. Debug web builds emit full, unminified
Dart stack traces; release minifies everything to `main.dart.js:<n>`, which is unreadable
when something throws (this is exactly what blocked the stale-Hive-data crash triage). Do
**not** optimize for load speed at this stage — that concern was premature.

Serve it bound to all interfaces so the affected browser on the tailnet (danserver) can
reach it:

```bash
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8095 --debug
```

Reach it at `http://danserver:8095/`. Only switch back to `flutter build web --release`
(served via a static server) once the basics are solid.

## Architecture

This is a Flutter app targeting Android, iOS, Web, Windows, Linux, and macOS. Code is organized in layers under `lib/`:

- `lib/data/` — persistence. `database/` (Hive setup, migrations, `resilient_box`), `models/` (Hive-adapter models + generated `*.g.dart`), `repositories/` (an interface per aggregate with `hive_*` and `in_memory_*` implementations).
- `lib/providers/` — `ChangeNotifier` state holders (`schedule_notifier`, `goals_notifier`, `commitments_notifier`, `settings_notifier`, `theme_notifier`).
- `lib/screens/` — one folder per feature (home, onboarding, schedule, goals, commitments, focus, end_of_day, quarterly_review, settings).
- `lib/services/` — `schedule_generator`, `notification_service`, `export_service`, `quarterly_aggregation_service`.
- `lib/widgets/` (`responsive_shell`), `lib/platform/` (desktop window setup via conditional io/stub imports), `lib/utils/`, `lib/dev/` (dev data loader).
- `lib/main.dart` (~166 lines) is bootstrap only: window setup → `HiveDatabase.init` → construct notifiers → `runApp`. `lib/router.dart` builds the routing.

Key choices:

- **State management**: Provider + `ChangeNotifier` for cross-screen state (notifiers in `lib/providers/`); `StatefulWidget` + `setState()` for screen-local state only.
- **Routing**: `go_router` (`createRouter` in `lib/router.dart`) with a `refreshListenable` on `SettingsNotifier` and a `redirect` that gates everything behind `/onboarding` until `onboardingComplete`. A `rootNavigatorKey` lets notification taps navigate without a `BuildContext`.
- **Persistence**: Hive (per-aggregate boxes) for app data; `SharedPreferences` for settings bootstrap.
- **Theme**: Material 3 with `ColorScheme.fromSeed(Colors.deepOrangeAccent)`.
- **Linting**: `package:flutter_lints` via `analysis_options.yaml`.
- **Dart SDK**: `^3.10.3` | **Flutter**: `>=3.18.0-18.0.pre.54`.

Tests are in `test/` using `flutter_test`.
