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

## Architecture

This is a Flutter app targeting Android, iOS, Web, Windows, Linux, and macOS. Currently it is the default Flutter starter template.

- **State management**: Provider + `ChangeNotifier` for cross-screen state (notifiers in `lib/providers/`); `StatefulWidget` + `setState()` for screen-local state only
- **Routing**: Single-screen `MaterialApp` with no routing library
- **Theme**: Material 3 with `ColorScheme.fromSeed(Colors.deepOrangeAccent)`
- **Linting**: `package:flutter_lints` via `analysis_options.yaml`
- **Dart SDK**: `^3.10.3` | **Flutter**: `>=3.18.0-18.0.pre.54`

All application code lives in `lib/main.dart`. The test suite is in `test/widget_test.dart` and uses Flutter's built-in `flutter_test` widget testing framework.
