import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal.dart';
import '../models/commitment_block.dart';
import '../models/daily_schedule.dart';
import '../models/scheduled_chunk.dart';
import '../models/completion_log.dart';
import '../models/quarterly_snapshot.dart';
import '../models/app_settings.dart';
import 'migrations.dart';

class HiveDatabase {
  /// Initialize Hive, register all TypeAdapters, open all boxes, run migrations.
  /// Must be awaited before runApp().
  static Future<void> init(SharedPreferences prefs) async {
    await Hive.initFlutter();

    // Register all adapters BEFORE opening any typed box.
    // typeId order must match master registry in RESEARCH.md.
    Hive.registerAdapter(GoalAdapter());               // typeId 0
    Hive.registerAdapter(CommitmentBlockAdapter());    // typeId 1
    Hive.registerAdapter(DailyScheduleAdapter());      // typeId 2
    Hive.registerAdapter(ScheduledChunkAdapter());     // typeId 3
    Hive.registerAdapter(CompletionLogAdapter());      // typeId 4
    Hive.registerAdapter(QuarterlySnapshotAdapter()); // typeId 5
    Hive.registerAdapter(AppSettingsAdapter());        // typeId 6

    // Open all boxes.
    await Hive.openBox<Goal>('goals');
    await Hive.openBox<CommitmentBlock>('commitment_blocks');
    await Hive.openBox<DailySchedule>('daily_schedules');
    await Hive.openBox<ScheduledChunk>('scheduled_chunks'); // standalone, not just embedded
    await Hive.openBox<CompletionLog>('completion_logs');
    await Hive.openBox<QuarterlySnapshot>('quarterly_snapshots');
    await Hive.openBox<AppSettings>('app_settings');

    await runMigrations(prefs);
  }
}
