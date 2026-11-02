import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/ics_calendar_source.dart';

/// Drives [IcsCalendarSource] over a fixture through the [IcsFetcher] seam
/// — no network. Mirrors the harness `test/services/calendar_sync_service_test.dart`
/// already established.
Future<String> _fixture(String name) =>
    File('test/fixtures/calendar/$name').readAsString();

Future<List<CalendarEvent>> _list(
  String fixture, {
  required DateTime start,
  required DateTime end,
}) async {
  final text = await _fixture(fixture);
  final source = IcsCalendarSource(
    urls: ['https://example.com/feed.ics'],
    fetch: (_) async => text,
  );
  return source.listEvents(start: start, end: end, calendarIds: const []);
}

/// Every occurrence whose start falls on the given UTC calendar date — used
/// to assert an occurrence is gone at ANY time of day, not just at the one
/// instant a correct implementation would have put it (a DST-drifted
/// occurrence an hour off must not slip past an "is it gone" check).
List<CalendarEvent> _onUtcDate(List<CalendarEvent> events, int month, int day) {
  return events.where((e) {
    final s = e.start.toUtc();
    return s.year == 2026 && s.month == month && s.day == day;
  }).toList();
}

List<DateTime> _sortedStarts(List<CalendarEvent> events) =>
    events.map((e) => e.start.toUtc()).toList()..sort();

void main() {
  tzdata.initializeTimeZones();

  setUp(() => tz.setLocalLocation(tz.UTC));

  group('IcsCalendarSource — recurrence exceptions (WINDOWS entry 1)', () {
    group('Google-style zoned series (TZID=America/Chicago, crosses DST)', () {
      // RRULE:FREQ=WEEKLY;COUNT=8;BYDAY=MO from Mon 2026-03-02 09:00 Chicago:
      // Mar 2, 9, 16, 23, 30, Apr 6, 13, 20. US DST starts 2026-03-08, so the
      // first is 15:00Z (CST) and every later one is 14:00Z (CDT).
      final windowStart = DateTime.utc(2026, 3, 1);
      final windowEnd = DateTime.utc(2026, 5, 1);

      test('a single EXDATE line removes that occurrence', () async {
        final events = await _list(
          'recurring_overrides_tzid.ics',
          start: windowStart,
          end: windowEnd,
        );
        expect(
          _onUtcDate(events, 3, 23),
          isEmpty,
          reason:
              'EXDATE;TZID=America/Chicago:20260323T090000 must remove '
              'the Mar 23 occurrence',
        );
      });

      test('a comma-list EXDATE on a second EXDATE line removes every date '
          'it names', () async {
        final events = await _list(
          'recurring_overrides_tzid.ics',
          start: windowStart,
          end: windowEnd,
        );
        expect(_onUtcDate(events, 4, 6), isEmpty, reason: 'Apr 6 EXDATE');
        expect(_onUtcDate(events, 4, 13), isEmpty, reason: 'Apr 13 EXDATE');
      });

      test('a RECURRENCE-ID override REPLACES the occurrence it identifies '
          '— the original instant is gone, the override appears at its new '
          'time, keyed by the original occurrence', () async {
        final events = await _list(
          'recurring_overrides_tzid.ics',
          start: windowStart,
          end: windowEnd,
        );
        expect(
          _onUtcDate(events, 3, 16),
          isEmpty,
          reason:
              'the Mar 16 occurrence was moved by a RECURRENCE-ID '
              'override and must not also appear at its original time',
        );
        final moved = events
            .where((e) => e.title == 'Team standup (moved to Tue)')
            .toList();
        expect(moved, hasLength(1));
        // Tue Mar 17 14:00 CDT = 19:00Z.
        expect(moved.single.start, DateTime.utc(2026, 3, 17, 19));
        expect(moved.single.end, DateTime.utc(2026, 3, 17, 20));
        // The override carries the ORIGINAL occurrence's key, so a sync that
        // already imported Mar 16 updates that block rather than adding one.
        expect(moved.single.recurrenceId, '2026-03-16T14:00:00.000Z');
      });

      test(
        'an override with STATUS:CANCELLED removes the occurrence',
        () async {
          final events = await _list(
            'recurring_overrides_tzid.ics',
            start: windowStart,
            end: windowEnd,
          );
          expect(
            _onUtcDate(events, 3, 30),
            isEmpty,
            reason: 'the Mar 30 occurrence is cancelled by an override',
          );
        },
      );

      test('expands in the event\'s own zone, so occurrences after a DST '
          'change keep their wall-clock time', () async {
        final events = await _list(
          'recurring_overrides_tzid.ics',
          start: windowStart,
          end: windowEnd,
        );
        // 09:00 CDT on Mar 9 is 14:00Z — not 15:00Z (which is what expanding
        // the series in UTC from a CST DTSTART would produce: 10:00 CDT).
        expect(_onUtcDate(events, 3, 9).map((e) => e.start), [
          DateTime.utc(2026, 3, 9, 14),
        ]);
      });

      test('pins the whole surviving set', () async {
        final events = await _list(
          'recurring_overrides_tzid.ics',
          start: windowStart,
          end: windowEnd,
        );
        expect(_sortedStarts(events), [
          DateTime.utc(2026, 3, 2, 15), // CST
          DateTime.utc(2026, 3, 9, 14), // CDT
          DateTime.utc(2026, 3, 17, 19), // moved override
          DateTime.utc(2026, 4, 20, 14),
        ]);
        final ids = events.map((e) => e.recurrenceId).toList();
        expect(ids, everyElement(isNotNull));
        expect(ids.toSet().length, ids.length);
      });

      test('an override moved INTO the window appears even though the '
          'occurrence it replaces is outside it', () async {
        final events = await _list(
          'recurring_overrides_tzid.ics',
          start: DateTime.utc(2026, 3, 17),
          end: DateTime.utc(2026, 3, 18),
        );
        expect(events.map((e) => e.title), ['Team standup (moved to Tue)']);
      });

      test('an override moved OUT of the window removes the original without '
          'emitting anything', () async {
        final events = await _list(
          'recurring_overrides_tzid.ics',
          start: DateTime.utc(2026, 3, 16),
          end: DateTime.utc(2026, 3, 17),
        );
        expect(events, isEmpty);
      });
    });

    test('UTC (Z) series: EXDATE removes, RECURRENCE-ID replaces', () async {
      final events = await _list(
        'recurring_with_exception.ics',
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 4, 1),
      );
      expect(_sortedStarts(events), [
        DateTime.utc(2026, 3, 2, 14),
        DateTime.utc(2026, 3, 9, 14),
        DateTime.utc(2026, 3, 16, 16), // moved override (was 14:00Z)
        // Mar 23 EXDATE'd
        DateTime.utc(2026, 3, 30, 14),
      ]);
      final moved = events.singleWhere((e) => e.title == 'Weekly sync (moved)');
      expect(moved.recurrenceId, '2026-03-16T14:00:00.000Z');
    });

    test('all-day series: EXDATE;VALUE=DATE with a comma list removes each '
        'date (and does not make the whole feed unparseable)', () async {
      tz.setLocalLocation(tz.getLocation('America/New_York'));
      final events = await _list(
        'recurring_all_day_exdate.ics',
        start: DateTime.utc(2026, 3, 1),
        end: DateTime.utc(2026, 4, 1),
      );
      // Floating all-day dates resolve to local (New York) midnight.
      expect(
        events.map((e) => tz.TZDateTime.from(e.start, tz.local).day).toList()
          ..sort(),
        [2, 23],
      );
      expect(events, everyElement(predicate<CalendarEvent>((e) => e.isAllDay)));
    });

    test('RDATE adds occurrences (TZID and UTC forms, comma list, with and '
        'without an RRULE)', () async {
      final events = await _list(
        'recurring_rdate.ics',
        start: DateTime.utc(2026, 3, 1),
        end: DateTime.utc(2026, 4, 1),
      );
      final physio = events.where((e) => e.title == 'Physio').toList();
      expect(_sortedStarts(physio), [
        DateTime.utc(2026, 3, 3, 15), // DTSTART, 09:00 CST
        DateTime.utc(2026, 3, 10, 14), // RRULE, 09:00 CDT
        DateTime.utc(2026, 3, 12, 14), // RDATE;TZID 09:00 CDT
        DateTime.utc(2026, 3, 20, 15), // RDATE in UTC
      ]);
      for (final e in physio) {
        expect(e.end.difference(e.start), const Duration(hours: 1));
      }
      final piano = events.where((e) => e.title == 'Piano lesson').toList();
      expect(_sortedStarts(piano), [
        DateTime.utc(2026, 3, 4, 22), // DTSTART, 16:00 CST
        DateTime.utc(2026, 3, 11, 21), // RDATE, 16:00 CDT
        DateTime.utc(2026, 3, 18, 21), // RDATE, 16:00 CDT
      ]);
      final ids = events.map((e) => e.recurrenceId).toList();
      expect(ids, everyElement(isNotNull));
      expect(ids.toSet().length, ids.length);
    });

    test('a plain non-recurring event still has a null recurrenceId (its '
        'existing sync key is unchanged)', () async {
      final events = await _list(
        'one_timed_event.ics',
        start: DateTime.utc(2026, 3, 1),
        end: DateTime.utc(2026, 4, 1),
      );
      expect(events, hasLength(1));
      expect(events.single.recurrenceId, isNull);
    });

    test('a UTC UNTIL still includes the last occurrence of a series zoned '
        'EAST of UTC (expansion is wall-clock, UNTIL is an instant)', () async {
      // Apple writes UNTIL as the last occurrence's own UTC instant: 09:00
      // Berlin (CET, +1) on Mar 6 = 08:00Z. Compared naively against the
      // 09:00 wall-clock carrier, the last occurrence would be cut off.
      const text = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Apple Inc.//macOS 15.3//EN
BEGIN:VEVENT
DTSTART;TZID=Europe/Berlin:20260302T090000
DTEND;TZID=Europe/Berlin:20260302T100000
RRULE:FREQ=DAILY;UNTIL=20260306T080000Z
DTSTAMP:20260301T090000Z
SUMMARY:Daily check-in
UID:2D7B9E10-4C3F-4A86-B1E5-8F0C6A2D3B47
END:VEVENT
END:VCALENDAR
''';
      final source = IcsCalendarSource(
        urls: ['https://example.com/feed.ics'],
        fetch: (_) async => text,
      );
      final events = await source.listEvents(
        start: DateTime.utc(2026, 3, 1),
        end: DateTime.utc(2026, 4, 1),
        calendarIds: const [],
      );
      expect(_sortedStarts(events), [
        for (var day = 2; day <= 6; day++) DateTime.utc(2026, 3, day, 8),
      ]);
    });

    test('a weekly WKST=SU rule (Google\'s default) is expanded, not '
        'silently dropped', () async {
      // package:rrule 0.2.x throws on any WKST but MO; before WINDOWS entry
      // 1's fix that throw was caught and the whole series vanished.
      final events = await _list(
        'recurring_overrides_tzid.ics',
        start: DateTime.utc(2026, 3, 1),
        end: DateTime.utc(2026, 3, 3),
      );
      expect(events.map((e) => e.title), ['Team standup']);
    });
  });
}
