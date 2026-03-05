import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/hive_database.dart';
import 'providers/goals_notifier.dart';
import 'providers/commitments_notifier.dart';
import 'providers/schedule_notifier.dart';
import 'providers/settings_notifier.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await HiveDatabase.init(prefs);

  // SettingsNotifier is constructed before runApp so init() can load persisted
  // values. The same instance is passed to createRouter and registered via
  // ChangeNotifierProvider.value so no double-construction occurs.
  final settingsNotifier = SettingsNotifier();
  await settingsNotifier.init();

  runApp(CanopyApp(settingsNotifier: settingsNotifier));
}

class CanopyApp extends StatelessWidget {
  const CanopyApp({super.key, required this.settingsNotifier});

  final SettingsNotifier settingsNotifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GoalsNotifier>(create: (_) => GoalsNotifier()),
        ChangeNotifierProvider<CommitmentsNotifier>(
            create: (_) => CommitmentsNotifier()),
        ChangeNotifierProvider<ScheduleNotifier>(
            create: (_) => ScheduleNotifier()),
        // Use value provider for settingsNotifier since we constructed it above.
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
