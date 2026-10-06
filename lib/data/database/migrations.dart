import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/commitment_block_repository.dart';
import '../repositories/hive_commitment_block_repository.dart';

const int currentSchemaVersion = 13;

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
  _migration9to10,
  _migration10to11,
  _migration11to12,
  _migration12to13,
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

Future<void> _migration9to10() async {
  // Phase 35: CommitmentBlock gains externalEventId (HiveField 7, String?,
  // default null) and isFromCalendar (HiveField 8, bool, default false) —
  // read-only calendar-import support (CAL-01/CAL-03). Both additive fields
  // — Hive CE binary reader returns null/false for missing fields in
  // existing records. Old records deserialize with externalEventId == null
  // and isFromCalendar == false, i.e. every pre-existing commitment is
  // correctly treated as hand-entered. No data transformation needed.
}

Future<void> _migration10to11() async {
  // Phase 35: AppSettings gains selectedCalendarIds (HiveField 9,
  // List<String>, default []), icsUrls (HiveField 10, List<String>,
  // default []) and lastCalendarSyncAt (HiveField 11, DateTime?, default
  // null) — CAL-02's persisted calendar selection/feed/last-sync state.
  // All additive fields — Hive CE binary reader returns an empty list for
  // a missing non-nullable List<String> HiveField and null for a missing
  // nullable HiveField in existing records. Old records deserialize with
  // selectedCalendarIds == [], icsUrls == [] and lastCalendarSyncAt ==
  // null, i.e. every pre-existing user has no calendar configured. No data
  // transformation needed.
}

Future<void> _migration11to12() async {
  // Phase 36: AppSettings gains googleAccessToken (HiveField 12, String?),
  // googleRefreshToken (HiveField 13, String?), googleAccessTokenExpiresAt
  // (HiveField 14, DateTime?), and googleReconnectNeeded (HiveField 15,
  // bool, default false) — CALAUTH-01/02/03's persisted Google OAuth token
  // state. All additive fields — Hive CE binary reader returns null/false
  // for missing fields in existing records. Old records deserialize with
  // no Google connection, i.e. every pre-existing user must connect fresh.
  // No data transformation needed.
}

/// Deletes every [CommitmentBlock] in [repository] with `isFromCalendar ==
/// true`, returning how many were deleted. Never touches a block with
/// `isFromCalendar == false` — that is the one load-bearing safety property
/// here, since a hand-entered commitment has no other source it could be
/// re-derived from.
///
/// **Why this runs at all (WINDOWS entries 7 and 8, D-36-05):** phase 36's
/// device UAT found two calendar-import defects at once — entry 7, ticks
/// never reached the device source so events from calendars the owner never
/// selected were imported anyway, and entry 8, an all-day event imported as
/// a block spanning the whole working day, erasing six working days (incl.
/// Payday, which is on a calendar nobody would untick, settling that this is
/// not just entry 7's fault). `CalendarSyncService.sync()` was verified
/// three independent ways to never prune — it only ever upserts — so the
/// already-persisted fake blocks from both defects would otherwise survive
/// every future sync. The pre-fix imported set is untrustworthy on BOTH axes
/// these fixes changed (which calendars were read, which events were
/// imported): a shape-matching sweep (e.g. `startMinutes == 480 &&
/// endMinutes == 1320`) cannot work, because fixing entry 7 means the
/// holidays/birthdays calendars that produced these exact blocks are no
/// longer queried at all, so no pass driven by the CURRENT code could ever
/// reach them again to delete them by shape. The data is derived and fully
/// re-derivable from the calendar source on the next sync, so discarding all
/// of it and letting the next sync rebuild the correct set is the only
/// option that guarantees the next device judgment is made against post-fix
/// data (D-36-05; CLAUDE.md trap #4 names the date a UAT judged pre-fix data
/// and cost a round trip).
///
/// **Accepted cost (T-36-37, disposition accept):** for one check-in
/// immediately after this migration, if the calendar source cannot be read
/// at all (e.g. offline), there are no last-known imported blocks to
/// degrade to — D-35-13's guarantee is weakened for exactly that one window.
/// The remedy is one successful sync.
Future<int> purgeImportedCalendarBlocks(
  CommitmentBlockRepository repository,
) async {
  final blocks = await repository.getAll();
  var deleted = 0;
  for (final block in blocks) {
    if (block.isFromCalendar) {
      await repository.delete(block.id);
      deleted++;
    }
  }
  return deleted;
}

Future<void> _migration12to13() async {
  // Phase 36 gap closure (WINDOWS entries 7/8, D-36-05): one-time cleanup of
  // every previously-imported calendar block, since sync() never prunes and
  // the pre-fix imported set is untrustworthy. See
  // [purgeImportedCalendarBlocks]'s doc comment for the full reasoning.
  //
  // Deliberately NOT guarded against a closed box: HiveDatabase.init opens
  // every box (including 'commitment_blocks') before runMigrations is ever
  // called, so the box is always open here. A silent skip on a closed box
  // would hide a real failure rather than fixing one.
  await purgeImportedCalendarBlocks(HiveCommitmentBlockRepository());
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
