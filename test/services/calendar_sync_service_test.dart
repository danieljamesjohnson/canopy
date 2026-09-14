import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:canopy/data/calendar/ics_calendar_source.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/services/calendar_sync_service.dart';
import 'package:canopy/services/schedule_generator.dart';

/// In-memory implementation used only in tests (mirrors
/// test/repositories/goal_repository_test.dart's InMemoryGoalRepository
/// shape — a throwaway double defined inside the test file itself, not a
/// production in-memory implementation).
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

Future<String> _fixture(String name) =>
    File('test/fixtures/calendar/$name').readAsString();

// A 10-minute event — shorter than kMinCommitmentWindowMinutes (25) — built
// inline rather than as a fixture file, since it exists purely to exercise
// the "too short to hold a chunk" gate and isn't referenced elsewhere.
const _shortEventIcs = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Canopy Test Fixtures//inline//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
UID:inline-short-event-1@canopy.test
DTSTAMP:20260301T000000Z
DTSTART:20260303T140000Z
DTEND:20260303T141000Z
SUMMARY:Quick call
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

void main() {
  tzdata.initializeTimeZones();

  late InMemoryCommitmentBlockRepository repo;

  setUp(() {
    repo = InMemoryCommitmentBlockRepository();
  });

  tearDown(() {
    // Never leak a non-UTC tz.local override into later tests in the suite.
    tz.setLocalLocation(tz.UTC);
  });

  group('CalendarSyncService — one timed event, end to end (CAL-01)', () {
    test(
      'a fixture feed with one timed event produces exactly one persisted CommitmentBlock',
      () async {
        tz.setLocalLocation(tz.UTC);
        final text = await _fixture('one_timed_event.ics');
        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => text,
        );
        final service = CalendarSyncService(
          source: source,
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );

        final result = await service.sync();

        expect(result.failed, isFalse);
        expect(result.imported, hasLength(1));
        final block = result.imported.single;
        expect(block.name, 'Dentist appointment');
        expect(block.daysOfWeek, isEmpty);
        expect(block.date, DateTime(2026, 3, 2));
        expect(block.isFromCalendar, isTrue);
        expect(block.externalEventId, isNotNull);

        final persisted = await repo.getAll();
        expect(persisted, hasLength(1));
      },
    );

    test(
      'converts to LOCAL wall-clock under a non-UTC tz.local — the SEED-006 '
      'shape (D-35-08)',
      () async {
        // The fixture's DTSTART/DTEND are 14:00Z/15:30Z. America/New_York is
        // EST (UTC-5) on 2026-03-02 — DST does not start until 2026-03-08 —
        // so the correct LOCAL reading is 09:00-10:30, not the raw UTC
        // digits. Set explicitly per D-35-08: a fixture that only passes
        // because danserver's own system zone happens to be UTC proves
        // nothing.
        tz.setLocalLocation(tz.getLocation('America/New_York'));
        final text = await _fixture('one_timed_event.ics');
        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => text,
        );
        final service = CalendarSyncService(
          source: source,
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );

        final result = await service.sync();
        final block = result.imported.single;

        // Bare literals — NOT derived from the same expression the mapper
        // uses, so this assertion can actually fail (see the mutation proof
        // recorded in 35-01-SUMMARY.md).
        expect(block.startMinutes, 540); // 9:00am local
        expect(block.endMinutes, 630); // 10:30am local
        // A zero-meridian (treat-UTC-digits-as-local) conversion would have
        // produced 840/930 instead.
        expect(block.startMinutes, isNot(840));
      },
    );

    test(
      'the imported block chunks through the REAL ScheduleGeneratorService',
      () async {
        tz.setLocalLocation(tz.UTC);
        final text = await _fixture('one_timed_event.ics');
        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => text,
        );
        final service = CalendarSyncService(
          source: source,
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );
        final result = await service.sync();
        final block = result.imported.single;

        final generator = ScheduleGeneratorService();
        final chunks = generator.generate(
          goals: const [],
          blocks: [block],
          moodIndex: 3,
          date: DateTime(2026, 3, 2),
          completionLogs: const [],
        );

        final commitmentChunks = chunks
            .where((c) => c.commitmentId == block.id)
            .toList();
        expect(commitmentChunks, isNotEmpty);
        for (final chunk in commitmentChunks) {
          final chunkStart = chunk.anchoredStartMinutes;
          expect(chunkStart, isNotNull);
          expect(chunkStart!, greaterThanOrEqualTo(block.startMinutes));
          expect(chunkStart, lessThan(block.endMinutes));
        }
      },
    );

    test('syncing the same feed twice does not duplicate the block', () async {
      tz.setLocalLocation(tz.UTC);
      final text = await _fixture('one_timed_event.ics');
      final source = IcsCalendarSource(
        urls: ['https://example.com/feed.ics'],
        fetch: (_) async => text,
      );
      final service = CalendarSyncService(
        source: source,
        repository: repo,
        now: () => DateTime(2026, 3, 1),
      );

      final first = await service.sync();
      final second = await service.sync();

      expect(first.imported, hasLength(1));
      expect(second.imported, hasLength(1));
      expect(first.imported.single.id, second.imported.single.id);
      final persisted = await repo.getAll();
      expect(persisted, hasLength(1));
    });

    test(
      'a fetcher that throws returns failed and leaves prior blocks untouched',
      () async {
        tz.setLocalLocation(tz.UTC);
        final priorBlock = CommitmentBlock(
          name: 'Hand-entered',
          daysOfWeek: const [1],
          startMinutes: 600,
          endMinutes: 660,
        );
        await repo.save(priorBlock);

        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => throw Exception('network down'),
        );
        final service = CalendarSyncService(
          source: source,
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );

        final result = await service.sync();

        expect(result.failed, isTrue);
        expect(result.imported, isEmpty);
        expect(result.skipped, isEmpty);
        final persisted = await repo.getAll();
        expect(persisted, hasLength(1));
        expect(persisted.single.id, priorBlock.id);
      },
    );

    test(
      'a too-short event imports zero blocks and reports one skipped entry',
      () async {
        tz.setLocalLocation(tz.UTC);
        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => _shortEventIcs,
        );
        final service = CalendarSyncService(
          source: source,
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );

        final result = await service.sync();

        expect(result.failed, isFalse);
        expect(result.imported, isEmpty);
        expect(result.skipped, hasLength(1));
        expect(result.skipped.single.reason, SkipReason.tooShort);
        final persisted = await repo.getAll();
        expect(persisted, isEmpty);
      },
    );
  });
}
