import 'package:flutter_test/flutter_test.dart';

import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/calendar_source_factory.dart';
import 'package:canopy/data/calendar/ics_calendar_source.dart';
import 'package:canopy/data/calendar/null_calendar_source.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/services/calendar_sync_service.dart';

/// In-memory implementation used only in tests (mirrors
/// test/services/calendar_sync_service_test.dart's InMemoryCommitmentBlockRepository
/// shape — a throwaway double defined inside the test file itself).
class InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
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
  group(
    'NullCalendarSource — every call is a safe empty answer, never throws '
    '(CAL-04)',
    () {
      late NullCalendarSource source;

      setUp(() {
        source = NullCalendarSource();
      });

      test('isAvailable is false', () async {
        expect(await source.isAvailable(), isFalse);
      });

      test('requestPermission returns notApplicable', () async {
        expect(
          await source.requestPermission(),
          CalendarPermissionState.notApplicable,
        );
      });

      test('listCalendars returns an empty list', () async {
        expect(await source.listCalendars(), isEmpty);
      });

      test('listEvents returns an empty list', () async {
        final events = await source.listEvents(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 31),
          calendarIds: const ['some-calendar-id'],
        );
        expect(events, isEmpty);
      });

      test('none of the four interface methods throws', () async {
        // If any of these completed with an error rather than a value, this
        // test would fail — that's the discriminating power here, not the
        // returned value itself (covered individually above).
        await expectLater(source.isAvailable(), completes);
        await expectLater(source.requestPermission(), completes);
        await expectLater(source.listCalendars(), completes);
        await expectLater(
          source.listEvents(
            start: DateTime(2026, 1, 1),
            end: DateTime(2026, 1, 31),
            calendarIds: const [],
          ),
          completes,
        );
      });
    },
  );

  group(
    'A sync against NullCalendarSource leaves hand-entered commitments '
    'exactly as they were (CAL-04)',
    () {
      test(
        'imports nothing, deletes nothing, reports no failure, and the two '
        'pre-seeded blocks survive with their original ids and fields '
        'unchanged',
        () async {
          final repo = InMemoryCommitmentBlockRepository();
          final gym = CommitmentBlock(
            name: 'Gym',
            daysOfWeek: const [1, 3, 5],
            startMinutes: 360,
            endMinutes: 420,
          );
          final standup = CommitmentBlock(
            name: 'Standup',
            daysOfWeek: const [1, 2, 3, 4, 5],
            startMinutes: 540,
            endMinutes: 555,
          );
          await repo.save(gym);
          await repo.save(standup);

          final service = CalendarSyncService(
            source: NullCalendarSource(),
            repository: repo,
            now: () => DateTime(2026, 3, 1),
          );

          final result = await service.sync();

          expect(result.failed, isFalse);
          expect(result.imported, isEmpty);
          expect(result.skipped, isEmpty);

          final persisted = await repo.getAll();
          expect(persisted, hasLength(2));

          // Compare the SAME two blocks by id and field, not merely a count
          // — a count-only assertion would pass even if the sync replaced
          // both blocks with two different ones.
          final persistedGym = persisted.firstWhere((b) => b.id == gym.id);
          expect(persistedGym.name, 'Gym');
          expect(persistedGym.daysOfWeek, [1, 3, 5]);
          expect(persistedGym.startMinutes, 360);
          expect(persistedGym.endMinutes, 420);

          final persistedStandup = persisted.firstWhere(
            (b) => b.id == standup.id,
          );
          expect(persistedStandup.name, 'Standup');
          expect(persistedStandup.daysOfWeek, [1, 2, 3, 4, 5]);
          expect(persistedStandup.startMinutes, 540);
          expect(persistedStandup.endMinutes, 555);
        },
      );
    },
  );

  group('defaultCalendarSource — the platform switch (D-35-12)', () {
    test('returns NullCalendarSource when no feed URLs are configured', () {
      expect(defaultCalendarSource(icsUrls: const []), isA<NullCalendarSource>());
      expect(defaultCalendarSource(), isA<NullCalendarSource>());
    });

    test(
      'returns IcsCalendarSource on this (desktop) test platform when a '
      'feed URL is configured',
      () {
        final source = defaultCalendarSource(
          icsUrls: const ['https://example.com/a.ics'],
        );
        expect(source, isA<IcsCalendarSource>());
      },
    );
  });
}
