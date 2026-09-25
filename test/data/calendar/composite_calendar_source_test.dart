import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/calendar_source.dart';
import 'package:canopy/data/calendar/composite_calendar_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Throwaway in-test double — a full [CalendarSource] implementation with
/// every return value configurable, and an optional exception to throw from
/// [listEvents]. Mirrors this codebase's existing fake-double pattern (e.g.
/// `calendar_settings_screen_test.dart`'s `_FakeCalendarSource`).
class _FakeCalendarSource implements CalendarSource {
  _FakeCalendarSource({
    this.available = true,
    this.calendars = const [],
    this.events = const [],
    this.permission = CalendarPermissionState.notApplicable,
    Object? throwOnListEvents,
  }) : _throwOnListEvents = throwOnListEvents;

  final bool available;
  final List<CalendarInfo> calendars;
  final List<CalendarEvent> events;
  final CalendarPermissionState permission;
  final Object? _throwOnListEvents;

  /// Records the exact `calendarIds` this fake was called with, so a test
  /// can assert the composite passed it through unchanged.
  List<String>? capturedCalendarIds;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<CalendarPermissionState> requestPermission() async => permission;

  @override
  Future<List<CalendarInfo>> listCalendars() async => calendars;

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async {
    capturedCalendarIds = calendarIds;
    if (_throwOnListEvents != null) throw _throwOnListEvents;
    return events;
  }
}

void main() {
  final start = DateTime(2026, 1, 1);
  final end = DateTime(2026, 1, 8);

  CalendarInfo info(String id, {String? sourceLabel}) => CalendarInfo(
    id: id,
    name: id,
    isReadOnly: true,
    sourceLabel: sourceLabel,
  );

  CalendarEvent event(String uid, String calendarId) => CalendarEvent(
    uid: uid,
    title: uid,
    start: start,
    end: start.add(const Duration(hours: 1)),
    isAllDay: false,
    status: CalendarEventStatus.confirmed,
    calendarId: calendarId,
  );

  group('CompositeCalendarSource', () {
    test(
      'listCalendars returns every child\'s calendars, in child order, with '
      'each child\'s own sourceLabel intact',
      () async {
        final google = _FakeCalendarSource(
          calendars: [info('google:a', sourceLabel: 'Google')],
        );
        final device = _FakeCalendarSource(
          calendars: [info('device-b', sourceLabel: 'This device')],
        );
        final composite = CompositeCalendarSource([google, device]);

        final result = await composite.listCalendars();

        expect(result.map((c) => c.id).toList(), ['google:a', 'device-b']);
        expect(result[0].sourceLabel, 'Google');
        expect(result[1].sourceLabel, 'This device');
      },
    );

    test('listEvents returns the union of every child\'s events', () async {
      final google = _FakeCalendarSource(events: [event('g1', 'google:a')]);
      final device = _FakeCalendarSource(events: [event('d1', 'device-b')]);
      final composite = CompositeCalendarSource([google, device]);

      final result = await composite.listEvents(
        start: start,
        end: end,
        calendarIds: const [],
      );

      expect(result.map((e) => e.uid).toSet(), {'g1', 'd1'});
    });

    test(
      'one child throws and the other succeeds: the successful child\'s '
      'events are returned, and no exception escapes',
      () async {
        final google = _FakeCalendarSource(
          throwOnListEvents: Exception('dead Google token'),
        );
        final device = _FakeCalendarSource(events: [event('d1', 'device-b')]);
        final composite = CompositeCalendarSource([google, device]);

        final result = await composite.listEvents(
          start: start,
          end: end,
          calendarIds: const [],
        );

        expect(result.map((e) => e.uid).toList(), ['d1']);
      },
    );

    test(
      'every child throws: the exception propagates, so CalendarSyncService '
      'degrades to a failed sync exactly as it does today for a single '
      'source',
      () {
        final google = _FakeCalendarSource(
          throwOnListEvents: Exception('Google is down'),
        );
        final device = _FakeCalendarSource(
          throwOnListEvents: Exception('device calendar is down'),
        );
        final composite = CompositeCalendarSource([google, device]);

        expect(
          () => composite.listEvents(
            start: start,
            end: end,
            calendarIds: const [],
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('isAvailable is true when any child is available', () async {
      final composite = CompositeCalendarSource([
        _FakeCalendarSource(available: false),
        _FakeCalendarSource(available: true),
      ]);

      expect(await composite.isAvailable(), isTrue);
    });

    test('isAvailable is false when no child is available', () async {
      final composite = CompositeCalendarSource([
        _FakeCalendarSource(available: false),
        _FakeCalendarSource(available: false),
      ]);

      expect(await composite.isAvailable(), isFalse);
    });

    test(
      'requestPermission returns notApplicable — permission is a per-child '
      'concept the settings screen drives per source, not a composite '
      'concern',
      () async {
        final composite = CompositeCalendarSource([
          _FakeCalendarSource(permission: CalendarPermissionState.granted),
          _FakeCalendarSource(permission: CalendarPermissionState.denied),
        ]);

        expect(
          await composite.requestPermission(),
          CalendarPermissionState.notApplicable,
        );
      },
    );

    test(
      'an empty calendarIds argument is passed through to every child '
      'unchanged, preserving each child\'s own "empty means all of mine" '
      'convention',
      () async {
        final google = _FakeCalendarSource();
        final device = _FakeCalendarSource();
        final composite = CompositeCalendarSource([google, device]);

        await composite.listEvents(
          start: start,
          end: end,
          calendarIds: const [],
        );

        expect(google.capturedCalendarIds, const <String>[]);
        expect(device.capturedCalendarIds, const <String>[]);
      },
    );

    test(
      'a non-empty calendarIds argument is also passed through to every '
      'child unchanged',
      () async {
        final google = _FakeCalendarSource();
        final device = _FakeCalendarSource();
        final composite = CompositeCalendarSource([google, device]);

        await composite.listEvents(
          start: start,
          end: end,
          calendarIds: const ['a', 'b'],
        );

        expect(google.capturedCalendarIds, const ['a', 'b']);
        expect(device.capturedCalendarIds, const ['a', 'b']);
      },
    );
  });
}
