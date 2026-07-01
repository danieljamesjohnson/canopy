import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal.dart';
import '../models/commitment_block.dart';
import '../models/daily_schedule.dart';
import '../models/scheduled_chunk.dart';
import '../models/completion_log.dart';
import '../models/quarterly_snapshot.dart';
import '../models/app_settings.dart';
import '../models/restorative_item.dart';
import 'migrations.dart';
import 'resilient_box.dart';

class HiveDatabase {
  /// Initialize Hive, register all TypeAdapters, open all boxes, run migrations.
  /// Must be awaited before runApp().
  static Future<void> init(SharedPreferences prefs) async {
    await Hive.initFlutter();

    // Register all adapters BEFORE opening any typed box.
    // typeId order must match master registry in RESEARCH.md.
    Hive.registerAdapter(GoalAdapter()); // typeId 0
    Hive.registerAdapter(CommitmentBlockAdapter()); // typeId 1
    Hive.registerAdapter(DailyScheduleAdapter()); // typeId 2
    Hive.registerAdapter(ScheduledChunkAdapter()); // typeId 3
    Hive.registerAdapter(CompletionLogAdapter()); // typeId 4
    Hive.registerAdapter(QuarterlySnapshotAdapter()); // typeId 5
    Hive.registerAdapter(AppSettingsAdapter()); // typeId 6
    Hive.registerAdapter(RestorativeItemAdapter()); // typeId 7

    // Open all boxes. Each open is resilient: if a box holds a record from an
    // older app version that the current adapters cannot deserialize, that box
    // is reset to empty instead of throwing an uncaught error that blanks the
    // app at startup (see resilient_box.dart and the debug write-up at
    // .planning/debug/stale-hive-data-startup-crash.md).
    await _openBox<Goal>('goals');
    await _openBox<CommitmentBlock>('commitment_blocks');
    await _openBox<DailySchedule>('daily_schedules');
    await _openBox<ScheduledChunk>(
      'scheduled_chunks',
    ); // standalone, not just embedded
    await _openBox<CompletionLog>('completion_logs');
    await _openBox<QuarterlySnapshot>('quarterly_snapshots');
    await _openBox<AppSettings>('app_settings');
    await _openBox<RestorativeItem>('restorative_items');

    await runMigrations(prefs);
  }

  /// Opens a typed box via the resilient helper, wiring in the real Hive
  /// open/delete calls. Kept private so [init] reads as a flat list of boxes.
  static Future<Box<T>> _openBox<T>(String name) => openBoxResilient<T>(
    name,
    (n) => Hive.openBox<T>(n),
    (n) => Hive.deleteBoxFromDisk(n),
  );
}
