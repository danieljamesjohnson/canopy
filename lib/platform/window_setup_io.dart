import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Size;
import 'package:window_manager/window_manager.dart';

/// Desktop-only window setup.
///
/// On Windows / macOS / Linux this calls `windowManager.ensureInitialized()`
/// and locks the minimum window size to **480 × 640 logical pixels** per
/// **D-11** (`.planning/phases/06-desktop-and-web-polish/06-CONTEXT.md`) and
/// **UI-SPEC §Interaction Contracts §Window Minimums** (locked values).
///
/// On every other platform (Web, Android, iOS) this is a guarded no-op.
/// Order of guards follows PATTERNS.md §Pattern B — `kIsWeb` **first** so
/// `Platform.is*` is never evaluated on Web (`dart:io`'s `Platform` throws on
/// Web at runtime). Even though this file is only compiled in when
/// `dart.library.io` is present, the `kIsWeb` early-return is kept to match
/// the established gating pattern in `lib/services/notification_service.dart`.
Future<void> setupDesktopWindow() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(480, 640));
}
