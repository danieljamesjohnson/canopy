import 'package:shared_preferences/shared_preferences.dart';

const int currentSchemaVersion = 2;

typedef MigrationFn = Future<void> Function();

/// Migration list. Index 0 = version 0→1, index 1 = version 1→2, etc.
/// Add new migrations here as schema changes; never modify existing entries.
final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,
];

Future<void> _migration0to1() async {
  // Phase 1 initial schema. No data transformation required.
}

Future<void> _migration1to2() async {
  // Phase 2: Goal model expanded with nullable fields (color, priorityWeight,
  // deadline, outcomeDescription, weeklyHourBudget, frequencyPerWeek) and
  // int fields with defaults (sortOrder=0, streakCount=0).
  // No data transformation needed — Hive binary reader returns null for missing
  // nullable fields and 0 for missing int fields in existing records.
}

Future<void> runMigrations(SharedPreferences prefs) async {
  final int storedVersion = prefs.getInt('schemaVersion') ?? 0;
  for (int i = storedVersion; i < currentSchemaVersion; i++) {
    await _migrations[i]();
  }
  await prefs.setInt('schemaVersion', currentSchemaVersion);
}
