import 'package:shared_preferences/shared_preferences.dart';

const int currentSchemaVersion = 9;

typedef MigrationFn = Future<void> Function();

/// Migration list. Index 0 = version 0→1, index 1 = version 1→2, etc.
/// Add new migrations here as schema changes; never modify existing entries.
final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,
  _migration2to3,
  _migration3to4,
  _migration4to5,
  _migration5to6,
  _migration6to7,
  _migration7to8,
  _migration8to9,
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

Future<void> _migration2to3() async {
  // Phase 6: AppSettings expanded with nullable moodSeedArgb (HiveField 5)
  // and nullable lastMoodSetYmdInt (HiveField 6). Both are part of this single
  // v3 schema bump — additive nullable ints supporting daily mood seed +
  // no-carry-forward rollover seam (D-10).
  // No data transformation needed — Hive binary reader returns null for missing
  // nullable fields in existing records (per Phase 2 _migration1to2 pattern).
}

Future<void> _migration3to4() async {
  // Phase 8: ScheduledChunk expanded with isDeferred (HiveField 8, bool, default false).
  // Additive bool field — Hive CE binary reader returns false for missing
  // HiveField(8) in existing ScheduledChunk records.
  // No data transformation needed.
}

Future<void> _migration4to5() async {
  // Phase 10: ScheduledChunk gains commitmentId (HiveField 9, String?, default null)
  // and AppSettings gains eveningReminderEnabled (HiveField 7, bool, default false)
  // and eveningReminderMinutes (HiveField 8, int, default 1200).
  // All additive nullable/defaulted fields — Hive CE binary reader returns
  // null/false/0 for missing fields in existing records.
  // No data transformation needed.
}

Future<void> _migration5to6() async {
  // CompletionLog gains commitmentId (HiveField 6, String?, default null) so the
  // commitment-block id no longer rides in goalId. Additive nullable field —
  // Hive CE binary reader returns null for missing HiveField(6) in existing
  // records; the CompletionLog.attributionId fallback (commitmentId ?? goalId)
  // keeps historical commitment logs resolving to the same aggregation key.
  // No data transformation needed.
}

Future<void> _migration6to7() async {
  // ScheduledChunk gains syntheticStartMinutes (HiveField 10, int?, null).
  // Additive nullable field — Hive CE binary reader returns null for missing
  // HiveField(10) in existing records. No data transformation needed.
  // Legacy schedules generated before this change will read syntheticStartMinutes
  // back as null; the displayStartMinutes "duration only" fallback is the
  // intended behavior until the next re-check-in regenerates and persists the
  // field with the new adapter (RESEARCH Pitfall 4).
}

Future<void> _migration7to8() async {
  // Phase 19: Goal model gains energyValenceIndex (HiveField 12, int?, null)
  // and emojiTag (HiveField 13, String?, null). Both additive nullable fields —
  // Hive CE binary reader returns null for missing fields in existing records.
  // null energyValenceIndex → Goal.energyValence getter returns EnergyValence.neutral.
  // No data transformation needed.
}

Future<void> _migration8to9() async {
  // New RestorativeItem aggregate (typeId 7) in its own 'restorative_items'
  // box — restorative activities kept separate from goals, surfaced only on
  // low-energy days. Brand-new empty box; no existing records to transform.
  // The box is opened in HiveDatabase.init before migrations run.
}

Future<void> runMigrations(SharedPreferences prefs) async {
  // WR-06: invariant — there must be exactly one migration entry per schema
  // version bump. If currentSchemaVersion is ever incremented without
  // appending a matching migration to _migrations, the loop below would index
  // _migrations[i] out of range and throw RangeError at startup for every
  // existing user. Asserting here fails loudly in debug/CI rather than at
  // user startup.
  assert(
    _migrations.length == currentSchemaVersion,
    '_migrations.length (${_migrations.length}) must equal '
    'currentSchemaVersion ($currentSchemaVersion) — a version bump is missing '
    'its migration entry.',
  );
  final int storedVersion = prefs.getInt('schemaVersion') ?? 0;
  // WR-08: refuse to silently downgrade the persisted schemaVersion.
  // If `storedVersion > currentSchemaVersion`, the app was rolled back
  // to an older build while Hive still has data from a newer schema.
  // Persisting `currentSchemaVersion` here would later cause the future
  // build (re-installed) to replay migrations that already ran. In
  // debug builds the assert surfaces the condition loudly; in release
  // we skip the persist so the stored value stays at the newer
  // version, preserving forward-migration correctness on next upgrade.
  assert(
    storedVersion <= currentSchemaVersion,
    'Stored schema version $storedVersion is ahead of currentSchemaVersion '
    '$currentSchemaVersion — refusing to downgrade. This usually means the '
    'app was rolled back; uninstall + reinstall is required.',
  );
  if (storedVersion > currentSchemaVersion) return;
  for (int i = storedVersion; i < currentSchemaVersion; i++) {
    await _migrations[i]();
  }
  await prefs.setInt('schemaVersion', currentSchemaVersion);
}
