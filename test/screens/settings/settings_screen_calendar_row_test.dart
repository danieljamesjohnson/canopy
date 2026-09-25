// Widget tests for SettingsScreen's Calendars row subtitle — Plan 36-06
// Task 2, CALAUTH-03's second visible location (the Calendars screen itself
// is the first, calendar_settings_screen_test.dart's Google reconnect
// group).
//
// `_calendarSubtitle` is private to `_SettingsScreenState`, so these tests
// drive it the only way available from outside the file: render the real
// `SettingsScreen` and read the "Calendars" row's rendered subtitle text.
// `SettingsScreen.build()` only ever `context.watch`es `SettingsNotifier`
// directly (every other provider it reads is inside a button callback, none
// of which these tests ever trigger), so a single `SettingsNotifier`
// provider is enough to pump the whole screen — confirmed by reading the
// file directly before writing this test, not assumed.

import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _pumpSettingsScreen(
  WidgetTester tester,
  SettingsNotifier settings,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsNotifier>.value(
      value: settings,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen — Calendars row subtitle (Plan 36-06, CALAUTH-03)', () {
    testWidgets(
      'reconnectNeeded set gives the expired subtitle',
      (tester) async {
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setReconnectNeeded(true);
        await _pumpSettingsScreen(tester, settings);

        expect(
          find.text('Google sign-in expired — tap to reconnect'),
          findsOneWidget,
        );
        // Checked FIRST, before every other branch — a selection existing
        // at the same time must not override it.
        expect(find.text('Not connected'), findsNothing);
      },
    );

    testWidgets(
      'reconnectNeeded clear with a selection gives the existing subtitle '
      'unchanged',
      (tester) async {
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setSelectedCalendarIds(['cal-1', 'cal-2']);
        await _pumpSettingsScreen(tester, settings);

        expect(find.text('2 of 2 calendars selected · Not synced yet'), findsOneWidget);
        expect(
          find.text('Google sign-in expired — tap to reconnect'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'reconnectNeeded clear with nothing configured gives "Not connected" '
      'unchanged',
      (tester) async {
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await _pumpSettingsScreen(tester, settings);

        expect(find.text('Not connected'), findsOneWidget);
        expect(
          find.text('Google sign-in expired — tap to reconnect'),
          findsNothing,
        );
      },
    );
  });
}
