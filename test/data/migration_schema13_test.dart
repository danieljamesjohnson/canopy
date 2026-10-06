// Tests for the Phase 36 gap-closure schema 12→13 bump: a one-time cleanup
// that discards every previously-imported calendar block (WINDOWS entries
// 7/8, D-36-05). See migration_schema_test.dart for the schema-constant
// assertions (currentSchemaVersion == 13) — this file is the per-phase
// migration round-trip test, following the migration_schema12_test.dart
// naming precedent.
//
// The survival invariant under test is `isFromCalendar == false` — asserted
// by SURVIVING BLOCK ID in every test here, never by count alone, because a
// count-only assertion passes even if the WRONG block survived.
//
// Mutation-proofed (see 36-09-SUMMARY.md for the observed output): removing
// the `isFromCalendar` predicate from `purgeImportedCalendarBlocks` made the
// first test below fail because the hand-entered block's id went missing
// from the survivors — the real data-loss failure this migration must never
// produce. Reverted immediately after observing it.

import 'dart:io';

import 'package:canopy/data/database/migrations.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory double — mirrors
/// test/services/calendar_sync_service_test.dart's
/// InMemoryCommitmentBlockRepository shape (a throwaway double defined
/// inside the test file, not a production in-memory implementation).
class _InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> _store = {};

  @override
  Future<List<CommitmentBlock>> getAll() async => _store.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async => _store[id];

  @override
  Future<void> save(CommitmentBlock block) async => _store[block.id] = block;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

void main() {
  group('purgeImportedCalendarBlocks — pure function (T-36-35)', () {
    test(
      'deletes exactly the 3 calendar-imported blocks and leaves both '
      'hand-entered blocks present, identified by id',
      () async {
        final repo = _InMemoryCommitmentBlockRepository();

        final importedDaySpanning = CommitmentBlock(
          name: 'Vacation',
          daysOfWeek: const [],
          startMinutes: 480,
          endMinutes: 1320,
          date: DateTime(2026, 10, 10),
          externalEventId: 'ics:aaa:vacation',
          isFromCalendar: true,
        );
        final importedTimed1 = CommitmentBlock(
          name: 'Dentist',
          daysOfWeek: const [],
          startMinutes: 540,
          endMinutes: 600,
          date: DateTime(2026, 10, 11),
          externalEventId: 'ics:aaa:dentist',
          isFromCalendar: true,
        );
        final importedTimed2 = CommitmentBlock(
          name: 'Standup',
          daysOfWeek: const [],
          startMinutes: 570,
          endMinutes: 600,
          date: DateTime(2026, 10, 12),
          externalEventId: 'ics:aaa:standup',
          isFromCalendar: true,
        );
        final handEnteredWeekly = CommitmentBlock(
          name: 'Gym',
          daysOfWeek: const [1, 3, 5],
          startMinutes: 420,
          endMinutes: 480,
        );
        final handEnteredOneOff = CommitmentBlock(
          name: 'Haircut',
          daysOfWeek: const [],
          startMinutes: 600,
          endMinutes: 660,
          date: DateTime(2026, 10, 14),
        );

        for (final block in [
          importedDaySpanning,
          importedTimed1,
          importedTimed2,
          handEnteredWeekly,
          handEnteredOneOff,
        ]) {
          await repo.save(block);
        }

        final deletedCount = await purgeImportedCalendarBlocks(repo);

        expect(deletedCount, equals(3));
        final survivors = await repo.getAll();
        final survivorIds = survivors.map((b) => b.id).toSet();
        expect(
          survivorIds,
          equals({handEnteredWeekly.id, handEnteredOneOff.id}),
          reason:
              'only the two hand-entered blocks must survive, identified by '
              'id — not by count alone (a count-only assertion would pass '
              'even if the wrong block survived)',
        );
      },
    );

    test(
      'over a repository with nothing imported, returns 0 and deletes '
      'nothing',
      () async {
        final repo = _InMemoryCommitmentBlockRepository();
        final handEntered = CommitmentBlock(
          name: 'Gym',
          daysOfWeek: const [1, 3, 5],
          startMinutes: 420,
          endMinutes: 480,
        );
        await repo.save(handEntered);

        final deletedCount = await purgeImportedCalendarBlocks(repo);

        expect(deletedCount, equals(0));
        final survivors = await repo.getAll();
        expect(survivors.map((b) => b.id).toList(), equals([handEntered.id]));
      },
    );

    test('over an empty repository, returns 0 and deletes nothing', () async {
      final repo = _InMemoryCommitmentBlockRepository();

      final deletedCount = await purgeImportedCalendarBlocks(repo);

      expect(deletedCount, equals(0));
      expect(await repo.getAll(), isEmpty);
    });
  });

  group(
    'schema 12→13 — driven through the REAL runMigrations against a real '
    'on-disk Hive box',
    () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('hive_schema13_test_');
        Hive.init(tempDir.path);
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(CommitmentBlockAdapter());
        }
      });

      tearDown(() async {
        await Hive.close();
        tempDir.deleteSync(recursive: true);
      });

      test(
        'an imported block is purged, a hand-entered block survives by id, '
        'and the persisted schemaVersion reads 13',
        () async {
          final box = await Hive.openBox<CommitmentBlock>('commitment_blocks');
          final importedBlock = CommitmentBlock(
            name: 'Columbus Day',
            daysOfWeek: const [],
            startMinutes: 480,
            endMinutes: 1320,
            date: DateTime(2026, 10, 12),
            externalEventId: 'ics:bbb:columbus-day',
            isFromCalendar: true,
          );
          final handEnteredBlock = CommitmentBlock(
            name: 'Gym',
            daysOfWeek: const [1, 3, 5],
            startMinutes: 420,
            endMinutes: 480,
          );
          await box.put(importedBlock.id, importedBlock);
          await box.put(handEnteredBlock.id, handEnteredBlock);

          SharedPreferences.setMockInitialValues({'schemaVersion': 12});
          final prefs = await SharedPreferences.getInstance();

          await runMigrations(prefs);

          final survivingIds = box.values.map((b) => b.id).toSet();
          expect(
            survivingIds,
            equals({handEnteredBlock.id}),
            reason:
                'the hand-entered block must survive BY ID and the '
                'calendar-imported one must be gone — a count-only '
                'assertion would pass even if the wrong block survived',
          );
          expect(
            prefs.getInt('schemaVersion'),
            equals(13),
            reason: 'the migration must persist the new schema version',
          );
        },
      );

      test(
        'is idempotent — running runMigrations a second time from the '
        'now-current version changes nothing and does not throw',
        () async {
          final box = await Hive.openBox<CommitmentBlock>('commitment_blocks');
          final handEnteredBlock = CommitmentBlock(
            name: 'Gym',
            daysOfWeek: const [1, 3, 5],
            startMinutes: 420,
            endMinutes: 480,
          );
          await box.put(handEnteredBlock.id, handEnteredBlock);

          SharedPreferences.setMockInitialValues({'schemaVersion': 12});
          final prefs = await SharedPreferences.getInstance();
          await runMigrations(prefs);
          // Second run — storedVersion is now already 13, so the loop body
          // must not execute again.
          await runMigrations(prefs);

          final survivingIds = box.values.map((b) => b.id).toSet();
          expect(survivingIds, equals({handEnteredBlock.id}));
          expect(prefs.getInt('schemaVersion'), equals(13));
        },
      );

      test(
        'correct on an empty box — no blocks, nothing to purge, migration '
        'still persists the new schema version',
        () async {
          await Hive.openBox<CommitmentBlock>('commitment_blocks');

          SharedPreferences.setMockInitialValues({'schemaVersion': 12});
          final prefs = await SharedPreferences.getInstance();

          await runMigrations(prefs);

          expect(prefs.getInt('schemaVersion'), equals(13));
        },
      );

      test(
        'correct on a box containing only hand-entered blocks — all survive '
        'by id',
        () async {
          final box = await Hive.openBox<CommitmentBlock>('commitment_blocks');
          final a = CommitmentBlock(
            name: 'Gym',
            daysOfWeek: const [1, 3, 5],
            startMinutes: 420,
            endMinutes: 480,
          );
          final b = CommitmentBlock(
            name: 'Haircut',
            daysOfWeek: const [],
            startMinutes: 600,
            endMinutes: 660,
            date: DateTime(2026, 10, 14),
          );
          await box.put(a.id, a);
          await box.put(b.id, b);

          SharedPreferences.setMockInitialValues({'schemaVersion': 12});
          final prefs = await SharedPreferences.getInstance();

          await runMigrations(prefs);

          final survivingIds = box.values.map((block) => block.id).toSet();
          expect(survivingIds, equals({a.id, b.id}));
          expect(prefs.getInt('schemaVersion'), equals(13));
        },
      );
    },
  );
}
