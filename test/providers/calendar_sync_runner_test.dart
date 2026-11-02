import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/calendar_source.dart';
import 'package:canopy/data/calendar/device_calendar_source.dart';
import 'package:canopy/data/calendar/google_calendar_source.dart';
import 'package:canopy/data/calendar/ics_calendar_source.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/calendar_sync_runner.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/services/calendar_sync_service.dart';

// Plan 36-15 — one sync function for both callers (check-in and the
// Calendars screen). Survivors are asserted by block id, never by count.

class _InMemoryBlocks implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> store = {};

  @override
  Future<List<CommitmentBlock>> getAll() async => store.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async => store[id];

  @override
  Future<void> save(CommitmentBlock block) async => store[block.id] = block;

  @override
  Future<void> delete(String id) async => store.remove(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

/// A repository whose `getAll` always fails — drives the never-throws test.
class _GetAllThrows extends _InMemoryBlocks {
  @override
  Future<List<CommitmentBlock>> getAll() async =>
      throw StateError('hive unavailable');
}

/// What EventKit hands the `DeviceCalendarSource` seam.
plugin.Event _devEvent({
  required String calendarId,
  required String uid,
  required DateTime start,
}) => plugin.Event(
  eventId: uid,
  instanceId: uid,
  calendarId: calendarId,
  title: 'Event $uid',
  startDate: start,
  endDate: start.add(const Duration(minutes: 60)),
  isAllDay: false,
  availability: plugin.EventAvailability.busy,
  status: plugin.EventStatus.confirmed,
  isRecurring: false,
);

/// Like the plugin: returns one future event per REQUESTED calendar id, so
/// what a source was built with is exactly what it answers for.
Future<List<plugin.Event>> _oneEventPerRequestedId({
  required DateTime start,
  required DateTime end,
  required List<String> calendarIds,
}) async {
  final n = DateTime.now().toUtc();
  final at = DateTime.utc(n.year, n.month, n.day + 3, 14);
  return [
    for (final id in calendarIds)
      _devEvent(calendarId: id, uid: 'evt-$id', start: at),
  ];
}

/// A source whose answer a test can swap between syncs.
class _ScriptedSource implements CalendarSource {
  List<CalendarEvent> events = [];
  bool throwOnList = false;

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
  }) async {
    if (throwOnList) throw StateError('network down');
    return events;
  }
}

CalendarEvent _allDay(String title) {
  final n = DateTime.now().toUtc();
  final day = DateTime.utc(n.year, n.month, n.day + 3);
  return CalendarEvent(
    uid: 'allday-$title',
    title: title,
    start: day,
    end: day.add(const Duration(days: 1)),
    isAllDay: true,
    status: CalendarEventStatus.confirmed,
    calendarId: 'cal-x',
  );
}

CommitmentBlock _handEntered(String id) => CommitmentBlock(
  id: id,
  name: 'Hand-entered $id',
  daysOfWeek: const [1],
  startMinutes: 540,
  endMinutes: 600,
);

String _icsFor({required DateTime start, required String uid}) {
  String stamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}T'
        '${two(d.hour)}${two(d.minute)}00Z';
  }

  return 'BEGIN:VCALENDAR\r\n'
      'VERSION:2.0\r\n'
      'PRODID:-//Canopy Test Fixtures//inline//EN\r\n'
      'BEGIN:VEVENT\r\n'
      'UID:$uid@canopy.test\r\n'
      'DTSTAMP:20260301T000000Z\r\n'
      'DTSTART:${stamp(start)}\r\n'
      'DTEND:${stamp(start.add(const Duration(hours: 1)))}\r\n'
      'SUMMARY:Event $uid\r\n'
      'STATUS:CONFIRMED\r\n'
      'END:VEVENT\r\n'
      'END:VCALENDAR\r\n';
}

void main() {
  late _InMemoryBlocks blocks;
  late InMemoryAppSettingsRepository settingsRepo;
  late CommitmentsNotifier commitments;
  late SettingsNotifier settings;

  setUp(() async {
    tz.setLocalLocation(tz.UTC);
    blocks = _InMemoryBlocks();
    settingsRepo = InMemoryAppSettingsRepository();
    commitments = CommitmentsNotifier(repository: blocks);
    settings = SettingsNotifier(repository: settingsRepo);
    await settings.init();
  });

  Set<String> ids() => blocks.store.keys.toSet();

  String importedId(String calendarId, String uid) => blocks.store.values
      .singleWhere(
        (b) =>
            b.externalEventId?.startsWith(
              'ics:${calendarIdHash(calendarId)}:$uid:',
            ) ??
            false,
      )
      .id;

  test(
    'configuredCalendarIdsFor is the union of the ticked ids and the feed URLs',
    () async {
      await settings.setSelectedCalendarIds(['home', 'google:abc']);
      await settings.addIcsUrl('https://example.com/a.ics');
      expect(
        configuredCalendarIdsFor(settings),
        equals({'home', 'google:abc', 'https://example.com/a.ics'}),
      );
    },
  );

  group('Owner scenario: Home -> spunkl, through runCalendarSync and a real '
      'DeviceCalendarSource built from settings the way production does', () {
    DeviceCalendarSource deviceFromSettings() => DeviceCalendarSource(
      calendarIds: filterDeviceCalendarIds(settings.selectedCalendarIds),
      fetchEvents: _oneEventPerRequestedId,
    );

    test('after unticking home and syncing again, home\'s block is gone, '
        'spunkl\'s and the hand-entered block remain', () async {
      await blocks.save(_handEntered('hand-1'));
      await settings.setSelectedCalendarIds(['home', 'spunkl']);

      final first = await runCalendarSync(
        commitments: commitments,
        settings: settings,
        source: deviceFromSettings(),
      );
      expect(first.failed, isFalse);
      final homeId = importedId('home', 'evt-home');
      final spunklId = importedId('spunkl', 'evt-spunkl');
      expect(ids(), equals({homeId, spunklId, 'hand-1'}));

      await settings.setSelectedCalendarIds(['spunkl']);
      final second = await runCalendarSync(
        commitments: commitments,
        settings: settings,
        source: deviceFromSettings(),
      );

      expect(second.failed, isFalse);
      expect(ids(), equals({spunklId, 'hand-1'}));
      // The notifier the UI listens to agrees with the repository.
      expect(
        commitments.blocks.map((b) => b.id).toSet(),
        equals({spunklId, 'hand-1'}),
      );
    });
  });

  group('WINDOWS entry 10 — the skipped list is recorded by the sync', () {
    test('a sync that skips an all-day event persists it: this notifier AND '
        'a NEW notifier over the same repository after init() both name it '
        'with SkipReason.allDay', () async {
      final source = _ScriptedSource()..events = [_allDay('Vacation')];

      final result = await runCalendarSync(
        commitments: commitments,
        settings: settings,
        source: source,
      );

      expect(result.failed, isFalse);
      expect(settings.lastCalendarSyncSkipped.map((e) => e.title), [
        'Vacation',
      ]);
      expect(settings.lastCalendarSyncSkipped.single.reason, SkipReason.allDay);

      final relaunched = SettingsNotifier(repository: settingsRepo);
      await relaunched.init();
      expect(relaunched.lastCalendarSyncSkipped.map((e) => e.title), [
        'Vacation',
      ]);
      expect(
        relaunched.lastCalendarSyncSkipped.single.reason,
        SkipReason.allDay,
      );
      expect(relaunched.lastCalendarSyncAt, result.syncedAt);
    });

    test('a failed sync after a successful one leaves lastCalendarSyncAt and '
        'the skipped list exactly as the successful one left them, and '
        'returns failed: true', () async {
      final source = _ScriptedSource()..events = [_allDay('Vacation')];
      final ok = await runCalendarSync(
        commitments: commitments,
        settings: settings,
        source: source,
      );
      final okAt = settings.lastCalendarSyncAt;
      expect(okAt, ok.syncedAt);

      source.throwOnList = true;
      final bad = await runCalendarSync(
        commitments: commitments,
        settings: settings,
        source: source,
      );

      expect(bad.failed, isTrue);
      expect(settings.lastCalendarSyncAt, okAt);
      expect(settings.lastCalendarSyncSkipped.map((e) => e.title), [
        'Vacation',
      ]);
      final relaunched = SettingsNotifier(repository: settingsRepo);
      await relaunched.init();
      expect(relaunched.lastCalendarSyncAt, okAt);
      expect(relaunched.lastCalendarSyncSkipped.map((e) => e.title), [
        'Vacation',
      ]);
    });

    test(
      'a later successful sync with nothing skipped clears the list',
      () async {
        final source = _ScriptedSource()..events = [_allDay('Vacation')];
        await runCalendarSync(
          commitments: commitments,
          settings: settings,
          source: source,
        );
        source.events = [];
        await runCalendarSync(
          commitments: commitments,
          settings: settings,
          source: source,
        );
        expect(settings.lastCalendarSyncSkipped, isEmpty);
      },
    );
  });

  test('runCalendarSync never throws: a repository fault while syncing '
      'degrades to failed: true and records nothing', () async {
    final faulty = CommitmentsNotifier(repository: _GetAllThrows());
    final result = await runCalendarSync(
      commitments: faulty,
      settings: settings,
      source: _ScriptedSource(),
    );
    expect(result.failed, isTrue);
    expect(settings.lastCalendarSyncAt, isNull);
  });

  group('the icsUrls half of the union is load-bearing — a REAL '
      'IcsCalendarSource with nothing ticked', () {
    const feed = 'https://example.com/work.ics';

    test('a past-dated block imported from feed u survives a sync whose '
        'settings hold u only in icsUrls', () async {
      final n = DateTime.now().toUtc();
      DateTime at(int dayOffset) =>
          DateTime.utc(n.year, n.month, n.day + dayOffset, 14);
      final pastStart = at(-2);
      final futureStart = at(3);
      final ics = [
        _icsFor(start: pastStart, uid: 'past-evt'),
        _icsFor(start: futureStart, uid: 'future-evt'),
      ];

      // Feed served with ONLY the past event for the first (past-dated)
      // import, then ONLY the future event for the real runner sync, so the
      // past block is outside this sync's window and is not re-written.
      var served = ics[0];
      IcsCalendarSource source() =>
          IcsCalendarSource(urls: [feed], fetch: (_) async => served);

      // A genuine ICS-imported block dated in the past: the sync clock is
      // three days ago, so the event two days ago is inside THAT window.
      final seed = await CalendarSyncService(
        source: source(),
        repository: blocks,
        now: () => n.subtract(const Duration(days: 3)),
      ).sync();
      expect(seed.failed, isFalse);
      final pastId = importedId(feed, 'past-evt@canopy.test');
      expect(blocks.store[pastId]!.isFromCalendar, isTrue);
      expect(blocks.store[pastId]!.date!.isBefore(DateTime.now()), isTrue);

      // The owner's real configuration: nothing ticked, the feed in icsUrls.
      expect(settings.selectedCalendarIds, isEmpty);
      await settings.addIcsUrl(feed);
      served = ics[1];

      final result = await runCalendarSync(
        commitments: commitments,
        settings: settings,
        source: source(),
      );

      expect(result.failed, isFalse);
      final futureId = importedId(feed, 'future-evt@canopy.test');
      // Both survive, by id: the new block, and the past-dated one that only
      // the feed URL being in the configured set keeps.
      expect(ids(), containsAll({pastId, futureId}));
      expect(ids(), equals({pastId, futureId}));
    });
  });
}
