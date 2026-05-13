import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/hive_database.dart';
import 'platform/window_setup.dart';
import 'providers/goals_notifier.dart';
import 'providers/commitments_notifier.dart';
import 'providers/schedule_notifier.dart';
import 'providers/settings_notifier.dart';
import 'providers/theme_notifier.dart';
import 'router.dart' show rootNavigatorKey, createRouter;
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phase 6 Plan 03: enforces 480x640 window minimum on Win/macOS/Linux.
  // Web stub + mobile guard make this safe to call on every platform.
  await setupDesktopWindow();
  final prefs = await SharedPreferences.getInstance();
  await HiveDatabase.init(prefs);

  // SettingsNotifier is constructed before runApp so init() can load persisted
  // values. The same instance is passed to createRouter and registered via
  // ChangeNotifierProvider.value so no double-construction occurs.
  final settingsNotifier = SettingsNotifier();
  await settingsNotifier.init();

  final scheduleNotifier = ScheduleNotifier();
  await scheduleNotifier.init();

  // Phase 6 Plan 02: ThemeNotifier is the single source of truth for the
  // app's ColorScheme.fromSeed. Construct + init before runApp so the first
  // frame has the correct mood seed (or the curious pre-checkin seed).
  final themeNotifier = ThemeNotifier();
  await themeNotifier.init();

  // Initialize notification service before runApp.
  // Web: no-op (in-app banner used instead).
  await NotificationService.initialize();

  // Wire notification tap → navigate to check-in screen (AC-3).
  // Uses rootNavigatorKey from router.dart to navigate without a BuildContext.
  NotificationService.onTapCallback = (NotificationResponse response) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    // Navigate to check-in if no schedule exists, otherwise show schedule.
    if (scheduleNotifier.hasScheduleToday) {
      rootNavigatorKey.currentState?.pushNamed('/schedule');
    } else {
      rootNavigatorKey.currentState?.pushNamed('/schedule/checkin');
    }
  };

  runApp(CanopyApp(
    settingsNotifier: settingsNotifier,
    scheduleNotifier: scheduleNotifier,
    themeNotifier: themeNotifier,
  ));
}

class CanopyApp extends StatelessWidget {
  const CanopyApp({
    super.key,
    required this.settingsNotifier,
    required this.scheduleNotifier,
    required this.themeNotifier,
  });

  final SettingsNotifier settingsNotifier;
  final ScheduleNotifier scheduleNotifier;
  final ThemeNotifier themeNotifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GoalsNotifier>(create: (_) => GoalsNotifier()),
        ChangeNotifierProvider<CommitmentsNotifier>(
            create: (_) => CommitmentsNotifier()),
        // Use value providers for notifiers constructed before runApp so init()
        // can be awaited without double-construction.
        ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
        ChangeNotifierProvider<SettingsNotifier>.value(value: settingsNotifier),
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
      ],
      // Consumer<ThemeNotifier> narrows the rebuild scope to MaterialApp.router
      // only — the MultiProvider node above is not rebuilt on every 20-min
      // ticker tick (RESEARCH.md anti-pattern line 607).
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) => MaterialApp.router(
          title: 'Canopy',
          theme: theme.currentTheme,
          // D-09 / UI-SPEC §Mood Warming Transition lock: 500ms easeOutCubic
          // cross-fade between ColorScheme.fromSeed snapshots when the user
          // taps a mood (or when the 20-min tick redraws modulation).
          themeAnimationDuration: const Duration(milliseconds: 500),
          themeAnimationCurve: Curves.easeOutCubic,
          routerConfig: createRouter(settingsNotifier),
        ),
      ),
    );
  }
}
