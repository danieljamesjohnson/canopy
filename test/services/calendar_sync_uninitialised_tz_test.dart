// Deliberately its own file: `tz.local` is a process-wide `late` field, so
// "never initialised" can only be observed in an isolate where nothing has
// called `tz.setLocalLocation` — and this app never does on web
// (NotificationService.initialize returns before touching timezones there).
// Do NOT import calendar_sync_service_test.dart helpers or call
// `tz.setLocalLocation` / `tzdata.initializeTimeZones` anywhere in this file.
import 'package:flutter_test/flutter_test.dart';

import 'package:canopy/data/calendar/ics_calendar_source.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/services/calendar_sync_service.dart';

class _Repo implements CommitmentBlockRepository {
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

void main() {
  test('WINDOWS entry 11 — a zero-event sync from a verified source with '
      'tz.local never initialised neither throws nor event-prunes', () async {
    const url = 'https://example.com/feed.ics';
    final repo = _Repo();
    final stale = CommitmentBlock(
      id: 'stale-ics',
      name: 'Stale',
      daysOfWeek: const [],
      startMinutes: 540,
      endMinutes: 600,
      date: DateTime(2026, 3, 2),
      externalEventId: 'ics:${calendarIdHash(url)}:gone:',
      isFromCalendar: true,
    );
    await repo.save(stale);

    final result = await CalendarSyncService(
      source: IcsCalendarSource(
        urls: [url],
        fetch: (_) async =>
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//t//EN\r\n'
            'END:VCALENDAR\r\n',
      ),
      repository: repo,
      now: () => DateTime.utc(2026, 3, 1, 12),
    ).sync();

    // Sync still succeeds (it did before the event prune existed), and with
    // no usable local zone there is no "covered day", so nothing is deleted.
    expect(result.failed, isFalse);
    expect(await repo.getAll().then((l) => l.map((b) => b.id).toSet()), {
      'stale-ics',
    });
  });
}
