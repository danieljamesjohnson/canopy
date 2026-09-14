import 'package:enough_icalendar/enough_icalendar.dart';
import 'package:http/http.dart' as http;
import 'package:rrule/rrule.dart';

import 'calendar_event.dart';
import 'calendar_source.dart';

/// Fetches the raw text of an `.ics` feed at [url]. The production default
/// (`_defaultFetch`) issues an HTTPS GET; tests supply a fixture-returning
/// fake here instead — this typedef is the seam that keeps the test suite
/// off the network entirely.
typedef IcsFetcher = Future<String> Function(Uri url);

/// Raised when a feed cannot be fetched or is not valid `.ics` text.
/// Never allowed to reach the UI — `CalendarSyncService.sync()` catches
/// every subclass of [Exception] around its call into a [CalendarSource]
/// and degrades to `CalendarSyncResult.failed`. Deliberately carries no
/// feed URL in its message (Security — Information Disclosure: some
/// subscription URLs embed a secret token in their path).
class IcsSourceException implements Exception {
  IcsSourceException(this.message);

  final String message;

  @override
  String toString() => 'IcsSourceException: $message';
}

Future<String> _defaultFetch(Uri url) async {
  final http.Response response;
  try {
    response = await http.get(url).timeout(const Duration(seconds: 10));
  } catch (_) {
    // Network failure, timeout, DNS error, etc. — normalise to our own
    // exception type so callers never need to know about `package:http`.
    throw IcsSourceException('feed fetch failed');
  }
  if (response.statusCode != 200) {
    throw IcsSourceException('feed fetch returned ${response.statusCode}');
  }
  return response.body;
}

/// Reads events from one or more subscribed `.ics` feeds (D-35-01: the
/// web/desktop calendar source, per D-35-12's per-platform switch).
///
/// Read-only by construction — see [CalendarSource]'s own doc comment.
/// `requestPermission` always returns [CalendarPermissionState.notApplicable]
/// because a URL subscription needs no OS permission at all.
class IcsCalendarSource implements CalendarSource {
  IcsCalendarSource({required List<String> urls, IcsFetcher? fetch})
    : _urls = urls,
      _fetch = fetch ?? _defaultFetch;

  final List<String> _urls;
  final IcsFetcher _fetch;

  @override
  Future<bool> isAvailable() async => _urls.isNotEmpty;

  @override
  Future<CalendarPermissionState> requestPermission() async =>
      CalendarPermissionState.notApplicable;

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    final infos = <CalendarInfo>[];
    for (final url in _urls) {
      final uri = _requireHttps(url);
      final text = await _fetch(uri);
      final calendar = _parseCalendar(text);
      infos.add(
        CalendarInfo(
          id: url,
          name: calendar.calendarName ?? url,
          isReadOnly: true,
        ),
      );
    }
    return infos;
  }

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async {
    final events = <CalendarEvent>[];
    for (final url in _urls) {
      if (calendarIds.isNotEmpty && !calendarIds.contains(url)) continue;
      final uri = _requireHttps(url);
      final text = await _fetch(uri);
      final calendar = _parseCalendar(text);
      for (final child in calendar.children) {
        if (child is! VEvent) continue;
        events.addAll(
          _expand(child, calendarId: url, start: start, end: end),
        );
      }
    }
    return events;
  }

  Uri _requireHttps(String url) {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      throw IcsSourceException('feed URL is not a valid URI');
    }
    // Security V6: never fetch a plaintext feed — a substituted-in-transit
    // .ics would be untrusted input from an unauthenticated source.
    if (uri.scheme != 'https') {
      throw IcsSourceException('feed URL must use HTTPS');
    }
    return uri;
  }

  VCalendar _parseCalendar(String text) {
    final VComponent parsed;
    try {
      parsed = VComponent.parse(text);
    } catch (_) {
      throw IcsSourceException('feed is not valid .ics text');
    }
    if (parsed is! VCalendar) {
      throw IcsSourceException('feed is not a VCALENDAR');
    }
    return parsed;
  }

  /// Expands one `VEVENT` into its concrete occurrences inside
  /// `[start, end)`.
  ///
  /// A non-recurring event yields at most one [CalendarEvent]. A recurring
  /// event (an `RRULE` present) is expanded via `package:rrule`'s
  /// `getInstances` — the API `enough_icalendar` itself does not provide
  /// (D-35-05 RULED). **`EXDATE`/`RDATE`/`RECURRENCE-ID` overrides are not
  /// applied here** — neither dependency handles them, and implementing
  /// that logic is out of this plan's scope; see 35-01-SUMMARY.md for the
  /// explicit scoping note. A moved or cancelled single occurrence of a
  /// recurring event will therefore still appear at its ORIGINAL time until
  /// that logic is added.
  List<CalendarEvent> _expand(
    VEvent event, {
    required String calendarId,
    required DateTime start,
    required DateTime end,
  }) {
    final uid = event.uid;
    final title = event.summary ?? '';
    final eventStart = event.start;
    final eventEnd = event.end;
    if (eventStart == null || eventEnd == null) return const [];
    final isAllDay = _isAllDay(event);
    final status = _mapStatus(event.status);
    final duration = eventEnd.difference(eventStart);

    final rawRule = event
        .getProperty<RecurrenceRuleProperty>(
          RecurrenceRuleProperty.propertyName,
        )
        ?.textValue;
    if (rawRule == null) {
      // Non-recurring: a single occurrence, only if it overlaps the window.
      if (eventStart.isBefore(end) && eventEnd.isAfter(start)) {
        return [
          CalendarEvent(
            uid: uid,
            title: title,
            start: eventStart,
            end: eventEnd,
            isAllDay: isAllDay,
            status: status,
            calendarId: calendarId,
          ),
        ];
      }
      return const [];
    }

    // Recurring: expand via rrule. Its getInstances requires every supplied
    // DateTime to be UTC (D-35-05 RULED point 2) — this UTC conversion is
    // purely for driving the occurrence math and is NEVER what reaches
    // CommitmentBlock; CalendarSyncService converts each occurrence's start
    // back to local wall-clock minutes before persisting (D-35-08).
    final RecurrenceRule recurrenceRule;
    try {
      recurrenceRule = RecurrenceRule.fromString('RRULE:$rawRule');
    } catch (_) {
      return const [];
    }
    final utcStart = eventStart.toUtc();
    final results = <CalendarEvent>[];
    final occurrences = recurrenceRule.getInstances(
      start: utcStart,
      after: start.toUtc(),
      includeAfter: true,
      before: end.toUtc(),
    );
    for (final occurrenceStart in occurrences) {
      // Deliberately left UTC-flagged (never `.toLocal()`, which would use
      // this MACHINE's real system timezone rather than the app's `tz.local`
      // override) — `CalendarSyncService` is the one place that converts to
      // local wall-clock, via `tz.TZDateTime.from(event.start, tz.local)`
      // (D-35-08), so every CalendarEvent this source emits stays in that
      // same UTC-or-floating shape regardless of whether it came from a
      // single event or an expanded recurrence.
      results.add(
        CalendarEvent(
          uid: uid,
          recurrenceId: occurrenceStart.toIso8601String(),
          title: title,
          start: occurrenceStart,
          end: occurrenceStart.add(duration),
          isAllDay: isAllDay,
          status: status,
          calendarId: calendarId,
        ),
      );
    }
    return results;
  }

  bool _isAllDay(VEvent event) {
    final startProperty = event.getProperty<DateTimeProperty>(
      DateTimeProperty.propertyNameStart,
    );
    final valueParameter =
        startProperty?[ParameterType.value] as ValueParameter?;
    return valueParameter?.valueType == ValueType.date;
  }

  CalendarEventStatus _mapStatus(EventStatus? status) {
    switch (status) {
      case EventStatus.cancelled:
        return CalendarEventStatus.cancelled;
      case EventStatus.tentative:
        return CalendarEventStatus.tentative;
      case EventStatus.confirmed:
      case EventStatus.unknown:
      case null:
        return CalendarEventStatus.confirmed;
    }
  }
}
