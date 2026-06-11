import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/hive_database.dart';
import 'platform/window_setup.dart';
import 'providers/goals_notifier.dart';
import 'providers/commitments_notifier.dart';
import 'providers/schedule_notifier.dart';
import 'providers/settings_notifier.dart';
import 'providers/theme_notifier.dart';
import 'router.dart' show createRouter;
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phase 6 Plan 03: enforces 480x640 window minimum on Win/macOS/Linux.
  // Web stub + mobile guard make this safe to call on every platform.
  //
  // WR-05: window-min-size enforcement is a polish nice-to-have, not a
  // startup blocker. If the window_manager plugin fails (transient
  // platform-channel error, OS version mismatch, sandboxed-Linux quirk),
  // log + continue so Hive and providers still initialize and the app
  // can launch with a default-sized window.
  try {
    await setupDesktopWindow();
  } catch (e, st) {
    debugPrint('setupDesktopWindow failed (continuing): $e\n$st');
  }
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

  // LOOP-01: construct GoalsNotifier and CommitmentsNotifier before runApp and
  // await their load methods so the scheduling engine always receives the
  // user's real saved data on any cold launch — not empty in-memory lists.
  // Registered via ChangeNotifierProvider.value (not lazy create:) so the
  // same pre-loaded instances are exposed to the widget tree.
  final goalsNotifier = GoalsNotifier();
  await goalsNotifier.loadGoals();

  final commitmentsNotifier = CommitmentsNotifier();
  await commitmentsNotifier.loadBlocks();

  // Initialize notification service before runApp.
  // Web: no-op (in-app banner used instead).
  await NotificationService.initialize();

  // LOOP-04: capture the GoRouter instance so the notification tap callback
  // can navigate via router.go() instead of Navigator.pushNamed() — named
  // routes do not exist under go_router and previously caused a crash.
  final router = createRouter(settingsNotifier);

  // Wire notification tap → navigate to check-in screen (AC-3).
  // Uses the GoRouter instance to navigate without a BuildContext.
  // WR-02: defer navigation to the next frame so that a notification tap
  // delivered during the cold-launch window (before MaterialApp.router
  // has completed its first build) cannot call router.go() before the
  // router has a registered navigator — which would throw GoException.
  NotificationService.onTapCallback = (NotificationResponse response) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navigate to check-in if no schedule exists, otherwise show schedule.
      if (scheduleNotifier.hasScheduleToday) {
        router.go('/schedule');
      } else {
        router.go('/schedule/checkin');
      }
    });
  };

  // LOOP-04: auto-schedule the morning notification at startup when enabled,
  // so it fires without the user toggling the Settings switch off/on.
  // scheduleMorningNotification is idempotent (cancels ID 0 first).
  if (settingsNotifier.morningNotificationEnabled) {
    await NotificationService.scheduleMorningNotification(
      settingsNotifier.morningNotificationMinutes,
    );
  }

  runApp(
    CanopyApp(
      settingsNotifier: settingsNotifier,
      scheduleNotifier: scheduleNotifier,
      themeNotifier: themeNotifier,
      goalsNotifier: goalsNotifier,
      commitmentsNotifier: commitmentsNotifier,
      router: router,
    ),
  );
}

class CanopyApp extends StatelessWidget {
  const CanopyApp({
    super.key,
    required this.settingsNotifier,
    required this.scheduleNotifier,
    required this.themeNotifier,
    required this.goalsNotifier,
    required this.commitmentsNotifier,
    required this.router,
  });

  final SettingsNotifier settingsNotifier;
  final ScheduleNotifier scheduleNotifier;
  final ThemeNotifier themeNotifier;
  final GoalsNotifier goalsNotifier;
  final CommitmentsNotifier commitmentsNotifier;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Use value providers for all notifiers constructed before runApp so
        // init()/load() can be awaited without double-construction.
        ChangeNotifierProvider<GoalsNotifier>.value(value: goalsNotifier),
        ChangeNotifierProvider<CommitmentsNotifier>.value(
          value: commitmentsNotifier,
        ),
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
          routerConfig: router,
        ),
      ),
    );
  }
}
