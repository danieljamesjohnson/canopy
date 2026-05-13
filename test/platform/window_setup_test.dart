// Smoke test for setupDesktopWindow() — Phase 6 Plan 06 Task 3.
//
// Covers AC-3 row: "setupDesktopWindow() completes without throwing the
// macOS-settings ArgumentError on the test host" — analogue to
// `test/services/notification_service_test.dart`.
//
// On the dev's macOS host, `Platform.isMacOS` is true (dart:io reads the
// actual OS, not `defaultTargetPlatform`), so the function reaches the
// `windowManager.ensureInitialized()` call. The `window_manager` plugin
// platform channel is NOT registered in the test host → that call throws
// `MissingPluginException`. That exception is acceptable noise on the test
// host (analogous to the LateInitializationError documented in
// notification_service_test.dart). What we MUST guard against is the
// production code itself throwing — e.g. constructing an invalid `Size`,
// or referencing an undefined symbol after a plugin upgrade.

import 'package:canopy/platform/window_setup.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Required because the IO branch reaches windowManager which is a plugin
  // (platform-channel-backed).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setupDesktopWindow', () {
    test(
      'does not throw any unexpected error on the test host '
      '(MissingPluginException is acceptable; ArgumentError or TypeError is not)',
      () async {
        try {
          await setupDesktopWindow();
        } catch (e) {
          // MissingPluginException is the only acceptable test-host outcome
          // (the window_manager plugin platform channel is not registered
          // by `flutter_test`). Anything else — ArgumentError, TypeError,
          // StateError — would indicate a regression in the production code.
          expect(
            e,
            isA<MissingPluginException>(),
            reason:
                'setupDesktopWindow may only throw MissingPluginException on '
                'the test host (no plugin registration). A different exception '
                'class indicates a regression in production code.',
          );
        }
      },
    );
  });
}
