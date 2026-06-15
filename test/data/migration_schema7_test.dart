// Regression test for schema version 7 features:
// - ScheduledChunk.syntheticStartMinutes persists through a Hive round-trip
// - ScheduledChunk.displayStartMinutes resolves correctly
//
// Note: Schema version assertions (currentSchemaVersion == 7) were removed when
// Phase 19 bumped the schema to 8. The current schema version is tested in
// migration_schema8_test.dart. The ScheduledChunk round-trip tests remain here
// as permanent regression coverage for HiveField 10 (Phase 17 feature).

import 'dart:io';

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Hive round-trip test for field 10 (syntheticStartMinutes)
  // ---------------------------------------------------------------------------

  group('ScheduledChunk Hive round-trip (field 10)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_schema7_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(ScheduledChunkAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('syntheticStartMinutes persists across box close/reopen', () async {
      const boxName = 'chunks_round_trip';
      const knownValue = 565; // 9:25 AM in minutes from midnight

      // Write
      final box = await Hive.openBox<ScheduledChunk>(boxName);
      final chunk = ScheduledChunk(
        chunkTypeIndex: 0, // work
        durationMinutes: 25,
        syntheticStartMinutes: knownValue,
      );
      await box.put('test-key', chunk);
      await box.close();

      // Read back from a freshly-opened box
      final reopened = await Hive.openBox<ScheduledChunk>(boxName);
      final readBack = reopened.get('test-key');
      expect(readBack, isNotNull);
      expect(
        readBack!.syntheticStartMinutes,
        equals(knownValue),
        reason:
            'syntheticStartMinutes must survive a Hive close/reopen cycle '
            '(field 10 round-trip)',
      );
      await reopened.close();
    });
  });

  // ---------------------------------------------------------------------------
  // displayStartMinutes getter logic
  // ---------------------------------------------------------------------------

  group('displayStartMinutes getter', () {
    test('returns anchoredStartMinutes when set', () {
      final chunk = ScheduledChunk(
        chunkTypeIndex: 0,
        durationMinutes: 25,
        anchoredStartMinutes: 540, // 9:00 AM
        syntheticStartMinutes: 565,
      );
      expect(chunk.displayStartMinutes, equals(540));
    });

    test('returns syntheticStartMinutes when anchoredStartMinutes is null', () {
      final chunk = ScheduledChunk(
        chunkTypeIndex: 0,
        durationMinutes: 25,
        syntheticStartMinutes: 565,
      );
      expect(chunk.displayStartMinutes, equals(565));
    });

    test('returns null when both are null', () {
      final chunk = ScheduledChunk(
        chunkTypeIndex: 0,
        durationMinutes: 25,
      );
      expect(chunk.displayStartMinutes, isNull);
    });
  });
}
