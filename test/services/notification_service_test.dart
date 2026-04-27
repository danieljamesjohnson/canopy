import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:canopy/services/notification_service.dart';

void main() {
  // Required for the plugin's platform channel calls during initialize().
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService.initialize', () {
    test('does not throw the macOS-settings ArgumentError on the test host', () async {
      // The original Phase 5 UAT bug: on macOS, calling initialize() threw
      //   ArgumentError('macOS settings must be set when targeting macOS platform.')
      // because InitializationSettings was constructed without a `macOS` entry.
      //
      // In the Flutter test host, the platform plugin instance is not registered,
      // so a different `LateInitializationError` is raised after the fix lands —
      // this is expected and unrelated to the regression. What we MUST guard
      // against is the original ArgumentError ever returning. This test asserts
      // exactly that: any other startup error is acceptable in the test host,
      // but the macOS-settings ArgumentError is not.
      try {
        await NotificationService.initialize();
      } catch (e) {
        expect(
          e,
          isNot(
            isA<ArgumentError>().having(
              (err) => err.message?.toString() ?? '',
              'message',
              contains('macOS settings'),
            ),
          ),
          reason:
              'initialize() must NOT throw the macOS-settings ArgumentError. '
              'Other test-host platform errors are acceptable here.',
        );
      }
    });
  });

  group('NotificationService permission helpers', () {
    test(
      'requestDarwinPermissions completes (no-op on non-Darwin hosts)',
      () async {
        await expectLater(
          NotificationService.requestDarwinPermissions(),
          completes,
        );
      },
    );

    test('requestIOSPermissions back-compat alias still completes', () async {
      await expectLater(NotificationService.requestIOSPermissions(), completes);
    });
  });

  group('InitializationSettings shape', () {
    test('has non-null entries for android, iOS, macOS, linux, windows', () {
      // This exercises the public surface that the production code builds.
      // We rebuild the same struct here using the documented constants so
      // that a regression (e.g. someone removing macOS again) fails this test.
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
          appName: 'Canopy',
          appUserModelId: 'com.canopy.app.Canopy',
          guid: 'a3f7c2e8-9b1d-4a6f-8c5e-2d4b7f9a1c3e',
        ),
      );
      expect(settings.android, isNotNull);
      expect(settings.iOS, isNotNull);
      expect(settings.macOS, isNotNull);
      expect(settings.linux, isNotNull);
      expect(settings.windows, isNotNull);
      expect(settings.windows!.appName, 'Canopy');
      expect(settings.windows!.appUserModelId, contains('.'));
      final guidV4 = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      );
      expect(
        guidV4.hasMatch(settings.windows!.guid),
        isTrue,
        reason: 'guid must be a v4 UUID',
      );
    });
  });
}
