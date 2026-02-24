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
  runApp(const CanopyApp());
}

class CanopyApp extends StatelessWidget {
  const CanopyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // SettingsNotifier is constructed first so it can be passed to createRouter.
    // The same instance is registered in MultiProvider so widgets can read it.
    final settingsNotifier = SettingsNotifier();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GoalsNotifier>(create: (_) => GoalsNotifier()),
        ChangeNotifierProvider<CommitmentsNotifier>(create: (_) => CommitmentsNotifier()),
        ChangeNotifierProvider<ScheduleNotifier>(create: (_) => ScheduleNotifier()),
        // Use value provider for settingsNotifier since we constructed it above.
        ChangeNotifierProvider<SettingsNotifier>.value(value: settingsNotifier),
      ],
      child: MaterialApp.router(
        title: 'Canopy',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
          useMaterial3: true,
        ),
        routerConfig: createRouter(settingsNotifier),
      ),
    );
  }
}
