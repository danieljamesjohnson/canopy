/// Web stub.
///
/// This file MUST stay free of any platform-specific imports (no IO library,
/// no native window plugin). Such imports would defeat the conditional export
/// in `window_setup.dart` and break Web compilation. The absence of those
/// imports is a tested invariant (see Plan 06's
/// `test/platform/window_setup_test.dart`).
///
/// Traceability: D-11 (Web is explicitly excluded from the window-min-size
/// guarantee per CONTEXT.md and UI-SPEC §Window Minimums).
library;

Future<void> setupDesktopWindow() async {
  // No-op on Web — no platform window plugin available here.
}
