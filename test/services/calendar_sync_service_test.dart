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

// The 25-minute/24-minute boundary itself — built inline (not a checked-in
// fixture file) since each exists purely to probe one side of
// kMinCommitmentWindowMinutes and isn't referenced elsewhere.
const _boundaryImportsIcs = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Canopy Test Fixtures//inline//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
UID:inline-boundary-imports-event@canopy.test
DTSTAMP:20260301T000000Z
DTSTART:20260303T130000Z
DTEND:20260303T132500Z
SUMMARY:Exactly 25 minutes
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

const _boundaryTooShortIcs = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Canopy Test Fixtures//inline//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
UID:inline-boundary-too-short-event@canopy.test
DTSTAMP:20260301T000000Z
DTSTART:20260303T140000Z
DTEND:20260303T142400Z
SUMMARY:Exactly 24 minutes
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

// An event crossing midnight — built inline for the same reason as the
// boundary fixtures above. Two blocks are expected (D-35-... multi-day
// splitting), neither inverted, and Canopy's own overnight-commitment scope
// boundary (no midnight-crossing HAND-ENTERED commitment support) is
// untouched by this — see CalendarSyncService's class doc comment.
const _overnightIcs = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Canopy Test Fixtures//inline//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
UID:inline-overnight-event@canopy.test
DTSTAMP:20260301T000000Z
DTSTART:20260304T230000Z
DTEND:20260305T020000Z
SUMMARY:Overnight flight
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

  group('CalendarSyncService — every shape a real calendar contains (35-02)', () {
    test(
      'an all-day event imports as one commitment spanning the working '
      'window, not skipped (D-35-06 RULED import-as-blocking)',
      () async {
        tz.setLocalLocation(tz.UTC);
        final text = await _fixture('all_day_event.ics');
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
        // Not in skipped — D-35-06 reversed the plan's original default.
        expect(result.skipped, isEmpty);
        final block = result.imported.single;
        expect(block.date, DateTime(2026, 3, 6));
        // Asserted against the app's OWN working-window constants, never a
        // hardcoded literal pair — a test asserting the literal pair
        // 480/1080 would pass for a user whose window differs and could
        // never fail (CLAUDE.md, "assertions that cannot fail"). See the
        // SUMMARY for why ScheduleGeneratorService.dayStartMinutes/
        // dayEndMinutes is the value used here.
        expect(block.startMinutes, ScheduleGeneratorService.dayStartMinutes);
        expect(block.endMinutes, ScheduleGeneratorService.dayEndMinutes);
      },
    );

    test(
      'a cancelled event is skipped as Cancelled; a tentative event in the '
      'same feed imports normally',
      () async {
        tz.setLocalLocation(tz.UTC);
        final text = await _fixture('cancelled_event.ics');
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

        expect(result.imported, hasLength(1));
        expect(result.imported.single.name, 'Maybe lunch');
        expect(result.skipped, hasLength(1));
        expect(result.skipped.single.reason, SkipReason.cancelled);
      },
    );

    test(
      'a too-short event, a zero-duration event, and a no-end-time event '
      'all import zero blocks and are each skipped as Too short to '
      'schedule; a real 30-minute event in the same feed imports',
      () async {
        tz.setLocalLocation(tz.UTC);
        final text = await _fixture('short_and_no_end_events.ics');
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

        expect(result.imported, hasLength(1));
        expect(result.imported.single.name, 'Real meeting');
        expect(result.skipped, hasLength(3));
        expect(
          result.skipped.every((s) => s.reason == SkipReason.tooShort),
          isTrue,
        );
      },
    );

    test('a 25-minute event imports — the boundary itself', () async {
      tz.setLocalLocation(tz.UTC);
      final source = IcsCalendarSource(
        urls: ['https://example.com/feed.ics'],
        fetch: (_) async => _boundaryImportsIcs,
      );
      final service = CalendarSyncService(
        source: source,
        repository: repo,
        now: () => DateTime(2026, 3, 1),
      );

      final result = await service.sync();

      expect(result.imported, hasLength(1));
      expect(result.skipped, isEmpty);
    });

    test(
      'a 24-minute event does not import — one minute short of the '
      'boundary, not a comfortable case either side of it',
      () async {
        tz.setLocalLocation(tz.UTC);
        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => _boundaryTooShortIcs,
        );
        final service = CalendarSyncService(
          source: source,
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );

        final result = await service.sync();

        expect(result.imported, isEmpty);
        expect(result.skipped, hasLength(1));
        expect(result.skipped.single.reason, SkipReason.tooShort);
      },
    );

    test(
      'a Fri 14:00 -> Sun 11:00 event splits into three one-off blocks, one '
      'per local calendar day, each end after its own start',
      () async {
        tz.setLocalLocation(tz.UTC);
        final text = await _fixture('multi_day_event.ics');
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

        expect(result.imported, hasLength(3));
        final byDate = {for (final b in result.imported) b.date: b};
        final fri = byDate[DateTime(2026, 3, 6)];
        final sat = byDate[DateTime(2026, 3, 7)];
        final sun = byDate[DateTime(2026, 3, 8)];
        expect(fri, isNotNull);
        expect(sat, isNotNull);
        expect(sun, isNotNull);
        expect(fri!.startMinutes, 840); // 14:00
        expect(fri.endMinutes, 1440); // midnight
        // The Saturday slice is a full day — neither end clipped by the
        // event's own start/end, both clipped by the day boundary.
        expect(sat!.startMinutes, 0);
        expect(sat.endMinutes, 1440);
        expect(sun!.startMinutes, 0);
        expect(sun.endMinutes, 660); // 11:00
        for (final block in result.imported) {
          expect(block.endMinutes, greaterThan(block.startMinutes));
        }
      },
    );

    test(
      'an 11pm->2am event splits into two blocks, neither inverted, '
      'without reopening the overnight-commitment scope boundary',
      () async {
        tz.setLocalLocation(tz.UTC);
        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => _overnightIcs,
        );
        final service = CalendarSyncService(
          source: source,
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );

        final result = await service.sync();

        expect(result.imported, hasLength(2));
        final byDate = {for (final b in result.imported) b.date: b};
        final firstNight = byDate[DateTime(2026, 3, 4)];
        final secondNight = byDate[DateTime(2026, 3, 5)];
        expect(firstNight, isNotNull);
        expect(secondNight, isNotNull);
        expect(firstNight!.startMinutes, 1380); // 23:00
        expect(firstNight.endMinutes, 1440); // midnight
        expect(secondNight!.startMinutes, 0);
        expect(secondNight.endMinutes, 120); // 02:00
      },
    );

    test(
      'an event in a foreign IANA timezone (Z-suffixed UTC) converts to the '
      'correct LOCAL minutes under a non-UTC tz.local',
      () async {
        // The fixture is UTC (14:00Z-15:00Z). Australia/Sydney is AEDT
        // (UTC+11) in March 2026 — DST does not end until early April — so
        // the correct LOCAL reading is 01:00-02:00 the NEXT calendar day.
        // Set explicitly: a fixture that only passes because danserver's
        // own system zone happens to be UTC proves nothing (SEED-006).
        tz.setLocalLocation(tz.getLocation('Australia/Sydney'));
        final text = await _fixture('foreign_timezone_event.ics');
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

        // Bare literals, not derived from the same expression the mapper
        // uses.
        expect(block.startMinutes, 60); // 01:00 local
        expect(block.endMinutes, 120); // 02:00 local
        expect(block.date, DateTime(2026, 3, 3));
      },
    );

    test(
      'DTSTART;TZID=America/Chicago + a matching VTIMEZONE block (the real '
      'Google Calendar form) resolves to the correct LOCAL minutes '
      '(closes WINDOWS.md entry 2 for the zoned form)',
      () async {
        // 14:00 America/Chicago on 2026-03-02 is CST (UTC-6; US DST does
        // not begin until 2026-03-08) = 20:00 UTC. Asia/Tokyo (UTC+9, no
        // DST) reads that instant as 05:00 the NEXT calendar day. Set
        // tz.local explicitly to a zone with zero relationship to Chicago
        // so a bug that merely echoes the raw digits back cannot pass by
        // accident.
        tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
        final text = await _fixture('tzid_with_vtimezone.ics');
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

        expect(block.startMinutes, 300); // 05:00 local
        expect(block.endMinutes, 360); // 06:00 local
        expect(block.date, DateTime(2026, 3, 3));
      },
    );

    test(
      'a floating DTSTART (no Z, no TZID) resolves against tz.local, not '
      'against the system clock (closes WINDOWS.md entry 2 for the '
      'floating form)',
      () async {
        // Floating means "this clock reading, in the viewer's own zone" —
        // the fixture's 14:00 must read back as 840 under ANY tz.local.
        // Asia/Tokyo is chosen deliberately: danserver's ACTUAL system
        // timezone (confirmed this session via `date`/`/etc/localtime`) is
        // America/Chicago, not UTC as CLAUDE.md's operating guide claims —
        // so a tz.local of America/Chicago would coincidentally agree with
        // the buggy system-local fallback and prove nothing (this was
        // caught by the mutation proof recorded in the SUMMARY: it produced
        // NO failure until the zone was changed to something that actually
        // differs from the real system zone). A zone equal to whatever the
        // system's real zone turns out to be is the SEED-006 trap exactly.
        tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
        final text = await _fixture('floating_time.ics');
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

        expect(block.startMinutes, 840); // 14:00, exactly as written
        expect(block.endMinutes, 900); // 15:00, exactly as written
        expect(block.date, DateTime(2026, 3, 2));
      },
    );

    test(
      'two overlapping events both import as separate blocks (D-35-09) — '
      'the calendar genuinely has the user double-booked',
      () async {
        tz.setLocalLocation(tz.UTC);
        final text = await _fixture('overlapping_events.ics');
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

        expect(result.imported, hasLength(2));
        expect(
          result.imported.map((b) => b.name),
          containsAll(['Overlap A', 'Overlap B']),
        );
      },
    );
  });
}
