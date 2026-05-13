/// Conditional re-export. Web builds get the stub (no `dart:io`); all other
/// platforms get the IO implementation. Pattern: RESEARCH.md §Pattern 3 +
/// dart.dev conditional imports.
///
/// `main.dart` imports only this file and calls `setupDesktopWindow()`; the
/// correct body resolves automatically per platform at compile time.
///
/// Traceability: D-11 (`window_manager` min 480×640 on Windows/macOS/Linux);
/// UI-SPEC §Interaction Contracts §Window Minimums.
library;

export 'window_setup_stub.dart' if (dart.library.io) 'window_setup_io.dart';
