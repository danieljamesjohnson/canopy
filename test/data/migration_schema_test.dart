// Schema-version regression tests for the AppSettings/Hive schema constant,
// plus the Phase 19 Goal energy-valence round-trip.
//
// Renamed from migration_schema8_test.dart (Phase 36) to stop the filename
// encoding a version number that goes stale at every schema bump — this
// file's name had already drifted once (it asserted version 11 while still
// named "8" from Phase 35 onward, flagged in 36-PATTERNS.md). A per-phase
// migration round-trip test still gets its own numbered file
// (migration_schema12_test.dart); this file is the one place the CURRENT
// schema constant and the pre-Phase-36 Goal energy-valence fields are
// checked, and neither needs a version number in its name to stay correct.
//
// - currentSchemaVersion == 12 (WR-06 invariant)
// - Old Goal (no HiveField 12/13) reads as EnergyValence.neutral with no crash
// - New Goal with energyValenceIndex + emojiTag persists through a Hive round-trip

import 'dart:io';

import 'package:canopy/data/database/migrations.dart';
import 'package:canopy/data/models/energy_valence.dart'; // does not exist yet — RED
import 'package:canopy/data/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Schema constant tests (no Hive I/O needed)
  // ---------------------------------------------------------------------------

  // Bumped to 13 by the Phase 36 gap closure (WINDOWS entries 7/8,
  // D-36-05): a one-time DATA cleanup, not a field addition — the first of
  // its kind in this file. migration 12→13 purges every previously
  // calendar-imported CommitmentBlock (isFromCalendar == true) because
  // sync() never prunes and the pre-fix imported set is untrustworthy on
  // both the which-calendars and which-events axes this closure changed.
  // The WR-06 count invariant moves in lockstep. See
  // migration_schema13_test.dart for the Hive round-trip half.
  test('currentSchemaVersion equals 13', () {
    expect(currentSchemaVersion, equals(13));
  });

  // The WR-06 assert in migrations.dart enforces
  // _migrations.length == currentSchemaVersion at runtime in debug mode.
  // We confirm the constant value here; the assert is the count gate.
  test('currentSchemaVersion is consistent with WR-06 migration count', () {
    expect(currentSchemaVersion, equals(13));
  });

  // ---------------------------------------------------------------------------
  // Hive round-trip tests for Phase 19 fields (HiveField 12 + 13)
  // ---------------------------------------------------------------------------

  group('Goal Hive round-trip (Phase 19 fields 12 + 13)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_schema8_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(GoalAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    // ENERGY-01a: Old-record compatibility.
    // A Goal saved WITHOUT energyValenceIndex or emojiTag (both null) reads
    // back as EnergyValence.neutral with emojiTag == null and no exception.
    // This stands in for a pre-migration record: Hive CE's field-dict read
    // returns null for absent HiveField(12) and HiveField(13), and the
    // getter's `?? 0` coerces null → EnergyValence.values[0] = neutral.
    test('old Goal record (no energyValenceIndex/emojiTag) loads as neutral, '
        'no crash (ENERGY-01a)', () async {
      const boxName = 'goals_old_compat';

      // Write a Goal without the new fields (simulates a pre-migration record)
      final box = await Hive.openBox<Goal>(boxName);
      final oldGoal = Goal(
        id: 'old-goal-id',
        name: 'Old Goal',
        goalTypeIndex: GoalType.timeTarget.index,
        // energyValenceIndex: intentionally omitted — null
        // emojiTag: intentionally omitted — null
      );
      await box.put('old-goal-id', oldGoal);
      await box.close();

      // Reopen and read back — must not throw
      final reopened = await Hive.openBox<Goal>(boxName);
      final readBack = reopened.get('old-goal-id');
      expect(
        readBack,
        isNotNull,
        reason: 'Goal must be readable after round-trip',
      );
      expect(
        readBack!.energyValence, // getter on Goal — does not exist yet
        equals(EnergyValence.neutral),
        reason:
            'Goal without energyValenceIndex must load as EnergyValence.neutral '
            '(null ?? 0 → values[0] = neutral) — ENERGY-01a',
      );
      expect(
        readBack.emojiTag, // field on Goal — does not exist yet
        isNull,
        reason: 'Goal without emojiTag must load as null — ENERGY-01a',
      );
      await reopened.close();
    });

    // ENERGY-01b + ENERGY-03a: Round-trip for energyValenceIndex and emojiTag.
    // A Goal saved WITH energyValenceIndex = gives.index and a known emojiTag
    // reads back with both fields intact.
    test(
      'new Goal with energyValenceIndex + emojiTag persists across close/reopen '
      '(ENERGY-01b + ENERGY-03a)',
      () async {
        const boxName = 'goals_round_trip';
        const knownEmoji = '⚡';

        // Write
        final box = await Hive.openBox<Goal>(boxName);
        final newGoal = Goal(
          id: 'new-goal-id',
          name: 'Energizing Goal',
          goalTypeIndex: GoalType.habit.index,
          energyValenceIndex:
              EnergyValence.gives.index, // field does not exist yet — RED
          emojiTag: knownEmoji, // field does not exist yet — RED
        );
        await box.put('new-goal-id', newGoal);
        await box.close();

        // Read back from a freshly-opened box
        final reopened = await Hive.openBox<Goal>(boxName);
        final readBack = reopened.get('new-goal-id');
        expect(readBack, isNotNull);
        expect(
          readBack!.energyValence,
          equals(EnergyValence.gives),
          reason:
              'energyValenceIndex must survive a Hive close/reopen cycle '
              '(HiveField 12 round-trip) — ENERGY-01b',
        );
        expect(
          readBack.emojiTag,
          equals(knownEmoji),
          reason:
              'emojiTag must survive a Hive close/reopen cycle '
              '(HiveField 13 round-trip) — ENERGY-03a',
        );
        await reopened.close();
      },
    );
  });
}
