import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/hive_database.dart';
import 'providers/goals_notifier.dart';
import 'providers/commitments_notifier.dart';
import 'providers/schedule_notifier.dart';
import 'providers/settings_notifier.dart';
import 'router.dart' show rootNavigatorKey, createRouter;
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await HiveDatabase.init(prefs);

  // SettingsNotifier is constructed before runApp so init() can load persisted
  // values. The same instance is passed to createRouter and registered via
  // ChangeNotifierProvider.value so no double-construction occurs.
  final settingsNotifier = SettingsNotifier();
  await settingsNotifier.init();

  final scheduleNotifier = ScheduleNotifier();
  await scheduleNotifier.init();

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

  runApp(CanopyApp(settingsNotifier: settingsNotifier, scheduleNotifier: scheduleNotifier));
}

class CanopyApp extends StatelessWidget {
  const CanopyApp({super.key, required this.settingsNotifier, required this.scheduleNotifier});

  final SettingsNotifier settingsNotifier;
  final ScheduleNotifier scheduleNotifier;

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
      ],
      child: MaterialApp.router(
        title: 'Canopy',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF3D6B4F)),
          useMaterial3: true,
        ),
        routerConfig: createRouter(settingsNotifier),
      ),
    );
  }
}
