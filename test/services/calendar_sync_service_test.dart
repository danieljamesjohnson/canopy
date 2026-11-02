import 'dart:convert';
import 'dart:io';

import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/calendar_source.dart';
import 'package:canopy/data/calendar/composite_calendar_source.dart';
import 'package:canopy/data/calendar/device_calendar_source.dart';
import 'package:canopy/data/calendar/google_auth_client.dart';
import 'package:canopy/data/calendar/google_calendar_source.dart';
import 'package:canopy/data/calendar/ics_calendar_source.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
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

// T-35-06: a feed claiming an implausible multi-YEAR "event" (2020-2030) —
// built inline since it exists purely to pin the DoS bound, not a shape a
// real calendar sends. The multi-day split must clip to the sync window
// rather than materialising one block per day of the claimed span.
const _implausibleMultiYearIcs = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Canopy Test Fixtures//inline//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
UID:inline-implausible-multi-year-event@canopy.test
DTSTAMP:20260301T000000Z
DTSTART:20200101T000000Z
DTEND:20300101T000000Z
SUMMARY:Implausible decade-long event
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''';

/// A repository whose `getAll` always fails — for the failed-path guard.
class _GetAllThrowsRepository extends InMemoryCommitmentBlockRepository {
  @override
  Future<List<CommitmentBlock>> getAll() async =>
      throw StateError('hive unavailable');
}

/// A plugin-shaped timed event on [calendarId] — what EventKit hands the
/// `DeviceCalendarSource` seam, so the tests below run the owner's real
/// device path (`mapDeviceEvent` -> `sync()`), not a stand-in.
plugin.Event _devEvent({
  required String calendarId,
  required String uid,
  required DateTime start,
  int minutes = 60,
  plugin.EventStatus status = plugin.EventStatus.confirmed,
}) => plugin.Event(
  eventId: uid,
  instanceId: uid,
  calendarId: calendarId,
  title: 'Event $uid',
  startDate: start,
  endDate: start.add(Duration(minutes: minutes)),
  isAllDay: false,
  availability: plugin.EventAvailability.busy,
  status: status,
  isRecurring: false,
);

/// A `DeviceEventsFetcher` that behaves like the plugin: returns only events
/// on the requested calendars that start inside [start, end). Mutable so a
/// test can delete an event between syncs, or make the whole fetch throw.
class _DeviceSeam {
  final List<plugin.Event> events = [];
  bool throwOnFetch = false;
  int calls = 0;

  Future<List<plugin.Event>> call({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async {
    calls++;
    if (throwOnFetch) throw StateError('network down');
    return events
        .where(
          (e) =>
              calendarIds.contains(e.calendarId) &&
              !e.startDate.isBefore(start) &&
              e.startDate.isBefore(end),
        )
        .toList();
  }
}

/// The imported block for ([calendarId], [uid]) — looked up by the exact
/// externalEventId `_buildBlock` produces, so the tests name blocks by id.
Future<CommitmentBlock> _blockFor(
  CommitmentBlockRepository repo,
  String calendarId,
  String uid,
) async => (await repo.getAll()).singleWhere(
  (b) => b.externalEventId == 'ics:${calendarIdHash(calendarId)}:$uid:',
);

Future<Set<String>> _repoIds(CommitmentBlockRepository repo) async =>
    (await repo.getAll()).map((b) => b.id).toSet();

CommitmentBlock _handEntered(String id) => CommitmentBlock(
  id: id,
  name: 'Hand-entered $id',
  daysOfWeek: const [1],
  startMinutes: 540,
  endMinutes: 600,
);

/// A [CalendarSource] that is NOT one of the three known concrete types —
/// the event prune must treat it as default-deny even when it succeeds.
class _UnknownSource implements CalendarSource {
  _UnknownSource(this.events);
  final List<CalendarEvent> events;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<CalendarPermissionState> requestPermission() async =>
      CalendarPermissionState.notApplicable;
  @override
  Future<List<CalendarInfo>> listCalendars() async => const [];
  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async => events;
}

/// Token store that is never actually used — a [GoogleCalendarSource] built
/// with an `apiClientFactory` seam never reaches it.
class _NoopTokenStore implements GoogleTokenStore {
  @override
  Future<GoogleTokens?> read() async => null;
  @override
  Future<void> write(GoogleTokens tokens) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> setReconnectNeeded(bool value) async {}
  @override
  bool get reconnectNeeded => false;
}

/// An http.Client answering every request with an empty Google `events.list`
/// page — a Google source that genuinely SUCCEEDS with no events.
class _EmptyEventsHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"items": []}')),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

GoogleCalendarSource _googleSource(
  List<String> ids, {
  required GoogleApiClientFactory factory,
}) => GoogleCalendarSource(
  authClient: GoogleAuthClient(store: _NoopTokenStore()),
  calendarIds: ids,
  apiClientFactory: factory,
);

/// A Google source whose client factory throws — what a missing or dead
/// token does (the factory is called before `listEvents`'s own try).
GoogleCalendarSource _failingGoogle(List<String> ids) =>
    _googleSource(ids, factory: () async => throw StateError('no token'));

/// A previously-imported block, seeded directly with the exact id shape
/// `_buildBlock` writes.
CommitmentBlock _importedBlock(
  String id,
  String calendarId,
  String uid,
  DateTime date, {
  bool fromCalendar = true,
}) => CommitmentBlock(
  id: id,
  name: id,
  daysOfWeek: const [],
  startMinutes: 540,
  endMinutes: 600,
  date: date,
  externalEventId: 'ics:${calendarIdHash(calendarId)}:$uid:',
  isFromCalendar: fromCalendar,
);

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
      'an all-day event imports zero blocks and is skipped and disclosed '
      '(D-36-05 RULED — supersedes D-35-06 import-as-blocking)',
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
        expect(result.imported, isEmpty);
        expect(result.skipped, hasLength(1));
        expect(result.skipped.single.reason, SkipReason.allDay);
        // Bare literal — the locked UI-SPEC Copywriting Contract string
        // (35-UI-SPEC.md "Skipped-event reason strings" row, Pitfall 6),
        // never re-derived from the enum or a constant the code also uses.
        expect(
          result.skipped.single.reason.label,
          'All-day — not imported automatically',
        );
        final persisted = await repo.getAll();
        expect(
          persisted,
          isEmpty,
          reason: 'the all-day event must leave no block in the repository',
        );
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
        // Asserted against the RENDERED reason string (UI-SPEC Copywriting
        // Contract), not just the enum name.
        expect(result.skipped.single.reason.label, 'Cancelled');
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
        // Asserted against the RENDERED reason string, not just the enum.
        expect(
          result.skipped.every(
            (s) => s.reason.label == 'Too short to schedule',
          ),
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
        expect(result.skipped.single.reason.label, 'Too short to schedule');
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

    test(
      'a feed claiming an implausible multi-year "event" splits into AT '
      'MOST kCalendarSyncWindowDays blocks, not one per claimed day '
      '(T-35-06)',
      () async {
        tz.setLocalLocation(tz.UTC);
        final service = CalendarSyncService(
          source: IcsCalendarSource(
            urls: ['https://example.com/feed.ics'],
            fetch: (_) async => _implausibleMultiYearIcs,
          ),
          repository: repo,
          now: () => DateTime(2026, 3, 1),
        );

        final result = await service.sync();

        // The sync window is [2026-03-01, 2026-03-15) — 14 days — so the
        // clipped split produces at most 15 blocks (both boundary dates
        // inclusive), never anywhere close to the ~3653 days the feed
        // itself claims.
        expect(result.imported.length, lessThanOrEqualTo(15));
        expect(result.imported.length, greaterThan(0));
        for (final block in result.imported) {
          final date = block.date!;
          expect(
            date.isBefore(DateTime(2026, 3, 1)),
            isFalse,
            reason: 'no block before the sync window start',
          );
          expect(
            date.isAfter(DateTime(2026, 3, 15)),
            isFalse,
            reason: 'no block after the sync window end',
          );
        }
      },
    );
  });

  group('WINDOWS entry 11 — selection prune: unticking a calendar removes the '
      'blocks imported from it, with no fetch required', () {
    // Sync clock for the service-level tests: noon UTC so the local date is
    // 2026-03-01 whatever the host zone (tz.local is pinned to UTC below).
    final now1 = DateTime.utc(2026, 3, 1, 12);
    final eventStart = DateTime.utc(2026, 3, 5, 14);

    setUp(() => tz.setLocalLocation(tz.UTC));

    DeviceCalendarSource deviceFor(_DeviceSeam seam, List<String> ids) =>
        DeviceCalendarSource(calendarIds: ids, fetchEvents: seam.call);

    // Sync #1: home + spunkl both ticked, one event each, plus one
    // hand-entered block. Returns the ids the tests then name.
    Future<({String home, String spunkl, String hand, _DeviceSeam seam})>
    syncOne() async {
      final seam = _DeviceSeam()
        ..events.addAll([
          _devEvent(calendarId: 'home', uid: 'evt-home', start: eventStart),
          _devEvent(calendarId: 'spunkl', uid: 'evt-spunkl', start: eventStart),
        ]);
      await repo.save(_handEntered('hand-1'));
      final result = await CalendarSyncService(
        source: deviceFor(seam, ['home', 'spunkl']),
        repository: repo,
        now: () => now1,
        configuredCalendarIds: ['home', 'spunkl'],
      ).sync();
      expect(result.failed, isFalse);
      return (
        home: (await _blockFor(repo, 'home', 'evt-home')).id,
        spunkl: (await _blockFor(repo, 'spunkl', 'evt-spunkl')).id,
        hand: 'hand-1',
        seam: seam,
      );
    }

    test('the owner scenario, through CommitmentsNotifier.syncFromCalendar '
        'and a real DeviceCalendarSource: Home -> spunkl removes the Home '
        'block, keeps spunkl and the hand-entered block', () async {
      // The notifier builds its own service with the real clock, so the
      // events are placed relative to DateTime.now(), mid-window.
      final n = DateTime.now().toUtc();
      final eventAt = DateTime.utc(n.year, n.month, n.day + 3, 14);
      Future<List<plugin.Event>> seam({
        required DateTime start,
        required DateTime end,
        required List<String> calendarIds,
      }) async => [
        for (final id in calendarIds)
          _devEvent(calendarId: id, uid: 'evt-$id', start: eventAt),
      ];
      final notifier = CommitmentsNotifier(repository: repo);
      await repo.save(_handEntered('hand-1'));

      await notifier.syncFromCalendar(
        source: DeviceCalendarSource(
          calendarIds: ['home', 'spunkl'],
          fetchEvents: seam,
        ),
        configuredCalendarIds: ['home', 'spunkl'],
      );
      final homeId = (await _blockFor(repo, 'home', 'evt-home')).id;
      final spunklId = (await _blockFor(repo, 'spunkl', 'evt-spunkl')).id;
      expect(await _repoIds(repo), equals({homeId, spunklId, 'hand-1'}));

      await notifier.syncFromCalendar(
        source: DeviceCalendarSource(
          calendarIds: ['spunkl'],
          fetchEvents: seam,
        ),
        configuredCalendarIds: ['spunkl'],
      );

      expect(await _repoIds(repo), equals({spunklId, 'hand-1'}));
      // The notifier reloaded, so the UI-facing list agrees with storage.
      expect(
        notifier.blocks.map((b) => b.id).toSet(),
        equals({spunklId, 'hand-1'}),
      );
    });

    test('a spunkl block that sync #2 did not produce (its event has left '
        'the window) survives — spunkl is still configured', () async {
      final one = await syncOne();

      // Ten days later the 5 March event is behind us and no longer
      // fetched; spunkl itself is still ticked.
      final result = await CalendarSyncService(
        source: deviceFor(one.seam, ['spunkl']),
        repository: repo,
        now: () => now1.add(const Duration(days: 10)),
        configuredCalendarIds: ['spunkl'],
      ).sync();

      expect(result.imported, isEmpty);
      expect(await _repoIds(repo), equals({one.spunkl, one.hand}));
    });

    test('a block written by the CURRENT sync is never deleted, even when '
        'its calendar is absent from configuredCalendarIds', () async {
      final one = await syncOne();

      // spunkl's event is still fetched (same clock), so sync #2 rewrites
      // its block in place; configuredCalendarIds is empty, so by
      // membership alone it would be pruned. Home is no longer fetched and
      // is genuinely stale.
      final result = await CalendarSyncService(
        source: deviceFor(one.seam, ['spunkl']),
        repository: repo,
        now: () => now1,
        configuredCalendarIds: const [],
      ).sync();

      expect(result.imported.map((b) => b.id), equals([one.spunkl]));
      expect(await _repoIds(repo), equals({one.spunkl, one.hand}));
    });

    test(
      'a fetch that throws still runs the selection prune: result.failed '
      'is true, home is gone, spunkl and the hand-entered block remain',
      () async {
        final one = await syncOne();
        one.seam.throwOnFetch = true;

        final result = await CalendarSyncService(
          source: deviceFor(one.seam, ['spunkl']),
          repository: repo,
          now: () => now1,
          configuredCalendarIds: ['spunkl'],
        ).sync();

        expect(result.failed, isTrue);
        expect(await _repoIds(repo), equals({one.spunkl, one.hand}));
      },
    );

    test('a failed fetch whose selection prune hits a repository error still '
        'returns failed rather than throwing (D-35-13)', () async {
      final seam = _DeviceSeam()..throwOnFetch = true;

      final result = await CalendarSyncService(
        source: deviceFor(seam, ['spunkl']),
        repository: _GetAllThrowsRepository(),
        now: () => now1,
        configuredCalendarIds: ['spunkl'],
      ).sync();

      expect(result.failed, isTrue);
    });

    test('configuredCalendarIds omitted (null): nothing is deleted', () async {
      final one = await syncOne();

      // Home is no longer in the source — with no selection supplied,
      // nothing may go.
      await CalendarSyncService(
        source: deviceFor(one.seam, ['spunkl']),
        repository: repo,
        now: () => now1,
      ).sync();

      expect(await _repoIds(repo), equals({one.home, one.spunkl, one.hand}));
    });

    test('configuredCalendarIds empty: every imported block not produced '
        'this sync is deleted; the hand-entered block survives', () async {
      final one = await syncOne();

      await CalendarSyncService(
        source: deviceFor(one.seam, const []),
        repository: repo,
        now: () => now1,
        configuredCalendarIds: const [],
      ).sync();

      expect(await _repoIds(repo), equals({one.hand}));
    });

    test('a block with isFromCalendar == false that carries a well-formed '
        'ics:<hash-of-home>: id survives — the isFromCalendar guard is '
        'load-bearing on its own, not masked by the id-shape check', () async {
      final one = await syncOne();
      final homeBlock = (await repo.getAll()).singleWhere(
        (b) => b.id == one.home,
      );
      final impostor = CommitmentBlock(
        id: 'impostor-1',
        name: 'Hand-entered, id copied from an import',
        daysOfWeek: const [],
        startMinutes: 540,
        endMinutes: 600,
        date: DateTime(2026, 3, 5),
        externalEventId: homeBlock.externalEventId,
        isFromCalendar: false,
      );
      await repo.save(impostor);
      expect(
        impostor.externalEventId,
        startsWith('ics:${calendarIdHash('home')}:'),
        reason: 'fixture must carry home\'s real hash to mean anything',
      );

      await CalendarSyncService(
        source: deviceFor(one.seam, ['spunkl']),
        repository: repo,
        now: () => now1,
        configuredCalendarIds: ['spunkl'],
      ).sync();

      // The genuine home import is gone; the impostor is not.
      expect(
        await _repoIds(repo),
        equals({one.spunkl, one.hand, 'impostor-1'}),
      );
    });

    test('a calendar block whose externalEventId does not match '
        '^ics:[0-9a-f]{8}: is never deleted', () async {
      final one = await syncOne();
      final odd = <String, String?>{
        'odd-null': null,
        'odd-legacy': 'device:legacy-id',
        'odd-short-hash': 'ics:abc:uid:',
        'odd-upper-hash': 'ics:ABCDEF12:uid:',
        'odd-long-hash': 'ics:abcdef123:uid:',
      };
      for (final entry in odd.entries) {
        await repo.save(
          CommitmentBlock(
            id: entry.key,
            name: entry.key,
            daysOfWeek: const [],
            startMinutes: 540,
            endMinutes: 600,
            date: DateTime(2026, 3, 5),
            externalEventId: entry.value,
            isFromCalendar: true,
          ),
        );
      }

      await CalendarSyncService(
        source: deviceFor(one.seam, const []),
        repository: repo,
        now: () => now1,
        configuredCalendarIds: const [],
      ).sync();

      // Everything well-formed and imported is gone; every odd one remains.
      expect(await _repoIds(repo), equals({one.hand, ...odd.keys}));
    });

    test('calendarIdHash is the token inside the id _buildBlock writes — one '
        'definition for building and matching', () async {
      final one = await syncOne();
      final block = (await repo.getAll()).singleWhere((b) => b.id == one.home);
      expect(
        block.externalEventId,
        equals('ics:${calendarIdHash('home')}:evt-home:'),
      );
    });
  });

  group('WINDOWS entry 11 — event prune: a deleted event disappears, but only '
      'from sources that answered, and only on days the fetch fully '
      'covered', () {
    // Noon UTC, tz.local pinned to UTC: today = 1 Mar, window end = 15 Mar
    // 12:00, so the fully covered days are 2..14 Mar inclusive.
    final now = DateTime.utc(2026, 3, 1, 12);
    DateTime mar(int d) => DateTime(2026, 3, d);

    setUp(() => tz.setLocalLocation(tz.UTC));

    DeviceCalendarSource deviceFor(_DeviceSeam seam, List<String> ids) =>
        DeviceCalendarSource(calendarIds: ids, fetchEvents: seam.call);

    Future<CalendarSyncResult> syncAt(CalendarSource source) =>
        CalendarSyncService(
          source: source,
          repository: repo,
          now: () => now,
        ).sync();

    // The mixed-source fixture: a composite of [a Google child that FAILS,
    // a device child for spunkl that succeeds], one live spunkl event, and a
    // spread of seeded blocks whose events the fetch no longer returns.
    Future<void> runMixed() async {
      final seam = _DeviceSeam()
        ..events.add(
          _devEvent(
            calendarId: 'spunkl',
            uid: 'still-there',
            start: DateTime.utc(2026, 3, 2, 14),
          ),
        );
      await repo.save(_handEntered('hand-1'));
      // Stale, spunkl, on fully covered days -> pruned.
      await repo.save(_importedBlock('stale-mar2', 'spunkl', 'gone-a', mar(2)));
      await repo.save(
        _importedBlock('stale-mar14', 'spunkl', 'gone-b', mar(14)),
      );
      // Stale, spunkl, but NOT on a fully covered day -> kept.
      await repo.save(_importedBlock('today-mar1', 'spunkl', 'gone-c', mar(1)));
      await repo.save(
        _importedBlock('past-feb28', 'spunkl', 'gone-d', DateTime(2026, 2, 28)),
      );
      await repo.save(
        _importedBlock('lastday-mar15', 'spunkl', 'gone-e', mar(15)),
      );
      // Re-produced by this very sync (same externalEventId) -> kept.
      await repo.save(
        _importedBlock('seed-kept', 'spunkl', 'still-there', mar(2)),
      );
      // Google child failed -> its absence proves nothing -> kept.
      await repo.save(_importedBlock('google-mar2', 'google:x', 'g-1', mar(2)));
      // Not from a calendar, id copied from a verified-calendar import -> kept.
      await repo.save(
        _importedBlock(
          'impostor-mar2',
          'spunkl',
          'impostor-uid',
          mar(2),
          fromCalendar: false,
        ),
      );

      final result = await syncAt(
        CompositeCalendarSource([
          _failingGoogle(['google:x']),
          deviceFor(seam, ['spunkl']),
        ]),
      );
      expect(result.failed, isFalse);
    }

    test('a spunkl block on a fully covered day whose event the answering '
        'source no longer returns is removed; the re-produced one and the '
        'hand-entered one stay', () async {
      await runMixed();
      final ids = await _repoIds(repo);

      expect(ids, isNot(contains('stale-mar2')));
      expect(ids, isNot(contains('stale-mar14')));
      expect(ids, contains('seed-kept'));
      expect(ids, contains('hand-1'));
    });

    test('a block dated TODAY (or earlier) whose event is not returned '
        'survives — today is never event-pruned', () async {
      await runMixed();
      final ids = await _repoIds(repo);

      expect(ids, contains('today-mar1'));
      expect(ids, contains('past-feb28'));
    });

    test('a block on the local date of windowEnd survives — the last day is '
        'only partially covered', () async {
      await runMixed();

      expect(await _repoIds(repo), contains('lastday-mar15'));
    });

    test('a google:x block on a covered day survives — the Google child '
        'failed, so absence proves nothing', () async {
      await runMixed();

      expect(await _repoIds(repo), contains('google-mar2'));
    });

    test('a block with isFromCalendar == false carrying a well-formed '
        'ics:<hash-of-spunkl>: id, dated tomorrow, on the verified calendar '
        'and absent from the fetch, survives — the isFromCalendar guard is '
        'the ONLY thing protecting it', () async {
      await runMixed();

      expect(await _repoIds(repo), contains('impostor-mar2'));
    });

    test('a source type outside the three known classes is default-deny: its '
        'calendar\'s stale block survives even though that source '
        'succeeded', () async {
      final seam = _DeviceSeam();
      await repo.save(_importedBlock('stale-spunkl', 'spunkl', 'gone', mar(2)));
      await repo.save(_importedBlock('stale-fake', 'fake-cal', 'gone', mar(2)));

      final result = await syncAt(
        CompositeCalendarSource([
          deviceFor(seam, ['spunkl']),
          _UnknownSource([
            CalendarEvent(
              uid: 'fake-live',
              title: 'Fake live',
              start: DateTime.utc(2026, 3, 3, 14),
              end: DateTime.utc(2026, 3, 3, 15),
              isAllDay: false,
              status: CalendarEventStatus.confirmed,
              calendarId: 'fake-cal',
            ),
          ]),
        ]),
      );

      // The unknown source really did answer and really did import.
      expect(result.failed, isFalse);
      expect(result.imported.map((b) => b.name), equals(['Fake live']));
      final ids = await _repoIds(repo);
      expect(ids, contains('stale-fake'));
      // ...while the known, succeeded device child's stale block is pruned,
      // so the survival above is default-deny and not "nothing pruned".
      expect(ids, isNot(contains('stale-spunkl')));
    });

    test('a spunkl event that comes back cancelled has its previously '
        'imported block removed', () async {
      final seam = _DeviceSeam()
        ..events.add(
          _devEvent(
            calendarId: 'spunkl',
            uid: 'cancel-me',
            start: DateTime.utc(2026, 3, 5, 14),
          ),
        );
      final source = deviceFor(seam, ['spunkl']);
      await syncAt(source);
      final blockId = (await _blockFor(repo, 'spunkl', 'cancel-me')).id;

      seam.events
        ..clear()
        ..add(
          _devEvent(
            calendarId: 'spunkl',
            uid: 'cancel-me',
            start: DateTime.utc(2026, 3, 5, 14),
            status: plugin.EventStatus.canceled,
          ),
        );
      final result = await syncAt(source);

      expect(result.skipped.map((e) => e.reason), [SkipReason.cancelled]);
      expect(await _repoIds(repo), isNot(contains(blockId)));
    });

    test('a bare (non-composite) DeviceCalendarSource that succeeds counts '
        'as one succeeded child: a deleted event\'s block goes', () async {
      final seam = _DeviceSeam()
        ..events.add(
          _devEvent(
            calendarId: 'spunkl',
            uid: 'will-delete',
            start: DateTime.utc(2026, 3, 5, 14),
          ),
        );
      final source = deviceFor(seam, ['spunkl']);
      await syncAt(source);
      final blockId = (await _blockFor(repo, 'spunkl', 'will-delete')).id;
      expect(await _repoIds(repo), contains(blockId));

      seam.events.clear();
      await syncAt(source);

      expect(await _repoIds(repo), isNot(contains(blockId)));
    });

    test('a bare IcsCalendarSource that succeeds is verified for its feed '
        'URL: a stale block on that feed goes, another feed\'s stays', () async {
      const url = 'https://example.com/feed.ics';
      await repo.save(_importedBlock('stale-ics', url, 'gone', mar(2)));
      await repo.save(
        _importedBlock('other-feed', 'https://other.test/x.ics', 'g', mar(2)),
      );

      await syncAt(
        IcsCalendarSource(
          urls: [url],
          fetch: (_) async =>
              'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//t//EN\r\n'
              'END:VCALENDAR\r\n',
        ),
      );

      final ids = await _repoIds(repo);
      expect(ids, isNot(contains('stale-ics')));
      expect(ids, contains('other-feed'));
    });

    test('a Google child that genuinely succeeds is verified for its '
        'calendars: a stale google: block goes, another account\'s stays',
        () async {
      await repo.save(_importedBlock('stale-g', 'google:x', 'gone', mar(2)));
      await repo.save(_importedBlock('other-g', 'google:y', 'gone', mar(2)));

      await syncAt(
        _googleSource(
          ['google:x'],
          factory: () async => _EmptyEventsHttpClient(),
        ),
      );

      final ids = await _repoIds(repo);
      expect(ids, isNot(contains('stale-g')));
      expect(ids, contains('other-g'));
    });

    test('when EVERY child fails the sync is failed and no event prune runs: '
        'a stale block on a covered day survives', () async {
      final seam = _DeviceSeam()..throwOnFetch = true;
      await repo.save(_importedBlock('stale-mar2', 'spunkl', 'gone', mar(2)));

      final result = await syncAt(
        CompositeCalendarSource([
          _failingGoogle(['google:x']),
          deviceFor(seam, ['spunkl']),
        ]),
      );

      expect(result.failed, isTrue);
      expect(await _repoIds(repo), contains('stale-mar2'));
    });
  });
}
