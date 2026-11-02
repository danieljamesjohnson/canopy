import 'package:enough_icalendar/enough_icalendar.dart';
import 'package:http/http.dart' as http;
import 'package:rrule/rrule.dart';
import 'package:timezone/timezone.dart' as tz;

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

  /// The feed URLs this source was constructed with — mirrors
  /// `DeviceCalendarSource.configuredCalendarIds`, the precedent. For this
  /// source a calendar id IS the feed URL (`calendarId: url` on every event).
  /// It exists so `CalendarSyncService` can tell which calendars a SUCCESSFUL
  /// answer actually covered (WINDOWS entry 11): `listEvents` throws on any
  /// URL failure, so an answer that returns at all covered every URL here.
  List<String> get configuredCalendarIds => List.unmodifiable(_urls);

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
      final vevents = calendar.children.whereType<VEvent>().toList();

      // RFC 5545 §3.8.4.4: a VEVENT carrying RECURRENCE-ID is not an event
      // of its own but an override of ONE occurrence of the series sharing
      // its UID (WINDOWS entry 1). Collect them first so the series can
      // suppress the occurrences they replace.
      final overridesByUid = <String, List<VEvent>>{};
      final masters = <VEvent>[];
      for (final event in vevents) {
        if (_recurrenceIdOf(event) != null) {
          overridesByUid.putIfAbsent(_uidOf(event), () => []).add(event);
        } else {
          masters.add(event);
        }
      }

      final seriesByUid = <String, _Series>{};
      for (final master in masters) {
        final uid = _uidOf(master);
        final series = _seriesOf(master);
        if (series != null) seriesByUid[uid] = series;
        events.addAll(
          _expand(
            master,
            overrides: overridesByUid[uid] ?? const [],
            calendarId: url,
            start: start,
            end: end,
          ),
        );
      }
      for (final entry in overridesByUid.entries) {
        for (final override in entry.value) {
          events.addAll(
            _expandOverride(
              override,
              series: seriesByUid[entry.key],
              calendarId: url,
              start: start,
              end: end,
            ),
          );
        }
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
      // EXDATE/RDATE are re-labelled before parsing so that enough_icalendar
      // never runs its own parser over them: it parses every comma-list
      // entry as a DATE-TIME regardless of `VALUE=DATE`, so an all-day
      // series with `EXDATE;VALUE=DATE:20260309,20260316` (Apple's shape)
      // threw a FormatException and failed the WHOLE feed. The re-labelled
      // properties keep their raw text and parameters, which
      // [_parseDateList] reads itself.
      final lines = VComponent.unfold(text).map(_aliasRecurrenceDates).toList();
      parsed = VComponent.parseLines(
        lines,
        customParser: _parseAliasedProperty,
      );
    } catch (_) {
      throw IcsSourceException('feed is not valid .ics text');
    }
    if (parsed is! VCalendar) {
      throw IcsSourceException('feed is not a VCALENDAR');
    }
    return parsed;
  }

  /// Expands one master `VEVENT` into its concrete occurrences inside
  /// `[start, end)` — closes WINDOWS entry 1.
  ///
  /// A non-recurring event (no `RRULE`, no `RDATE`) yields at most one
  /// [CalendarEvent], with a null [CalendarEvent.recurrenceId], exactly as
  /// before. A recurring event's occurrence set is built per RFC 5545
  /// §3.8.5: the `RRULE` instances (expanded via `package:rrule`, D-35-05)
  /// plus every `RDATE`, minus every `EXDATE`, minus every occurrence a
  /// same-UID `RECURRENCE-ID` override in [overrides] replaces (the
  /// override itself is emitted separately by [_expandOverride]).
  ///
  /// The `RRULE` is expanded in the event's OWN zone (its `DTSTART` TZID, or
  /// [tz.local] when floating), by feeding `package:rrule` the wall-clock
  /// digits on a UTC-flagged carrier and re-resolving each instance in that
  /// zone. Expanding the absolute UTC instant instead — what this did before
  /// — drifts every occurrence on the far side of a DST change by an hour,
  /// and then a TZID'd `EXDATE`/`RECURRENCE-ID` (Google's shape) no longer
  /// matches the occurrence it names.
  ///
  /// Each occurrence's [CalendarEvent.recurrenceId] is its start instant as
  /// a UTC ISO-8601 string — the same string a `RECURRENCE-ID` override of
  /// that occurrence is keyed by, so `CalendarSyncService`'s
  /// `externalEventId` for a moved occurrence equals the one the original
  /// was imported under and the existing block is updated, not duplicated.
  ///
  /// An event with no `DTEND` (and this app never consumes `DURATION`) is
  /// treated as a zero-duration point in time per RFC 5545 convention —
  /// [CalendarSyncService]'s existing `commitmentWindowTooShort` gate is
  /// what turns that into a reported skip, not a silent drop here.
  ///
  /// Not implemented: `RANGE=THISANDFUTURE` on a `RECURRENCE-ID` (treated as
  /// a single-occurrence override), and `RDATE;VALUE=PERIOD` uses only each
  /// period's start, with the series' own duration.
  List<CalendarEvent> _expand(
    VEvent event, {
    required List<VEvent> overrides,
    required String calendarId,
    required DateTime start,
    required DateTime end,
  }) {
    final uid = _uidOf(event);
    final title = event.summary ?? '';
    final startProperty = event.getProperty<DateTimeProperty>(
      DateTimeProperty.propertyNameStart,
    );
    if (startProperty == null) return const []; // no DTSTART: unmappable.
    final eventStart = _resolveInstant(startProperty);

    final endProperty = event.getProperty<DateTimeProperty>(
      DateTimeProperty.propertyNameEnd,
    );
    final eventEnd = endProperty == null
        ? eventStart
        : _resolveInstant(endProperty);

    final isAllDay = _isAllDay(event);
    final status = _mapStatus(event.status);
    final duration = eventEnd.difference(eventStart);

    final rawRule = event
        .getProperty<RecurrenceRuleProperty>(
          RecurrenceRuleProperty.propertyName,
        )
        ?.textValue;
    final rdates = event
        .getProperties<Property>(_rdateAlias)
        .expand(_parseDateList)
        .toList();
    if (rawRule == null && rdates.isEmpty) {
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

    final zone = _zoneFor(_timeOf(startProperty), fallback: tz.local);
    final utcStart = _plainUtc(eventStart);
    final windowStart = start.toUtc();
    final windowEnd = end.toUtc();
    // An occurrence is in the window when it STARTS in
    // [max(windowStart, DTSTART), windowEnd) — the same bounds the RRULE
    // expansion has always used (getInstances' includeAfter/before).
    final lowerBound = windowStart.isBefore(utcStart) ? utcStart : windowStart;
    bool inWindow(DateTime instant) =>
        !instant.isBefore(lowerBound) && instant.isBefore(windowEnd);

    final occurrences = <int, DateTime>{};
    void add(DateTime instant) {
      if (inWindow(instant)) {
        occurrences[instant.microsecondsSinceEpoch] = instant;
      }
    }

    if (rawRule == null) {
      // RDATE without RRULE: DTSTART is still the set's first occurrence.
      add(utcStart);
    } else {
      final RecurrenceRule recurrenceRule;
      try {
        recurrenceRule = RecurrenceRule.fromString(
          'RRULE:${_normaliseRule(rawRule, zone)}',
        );
      } catch (_) {
        return const [];
      }
      // package:rrule requires every DateTime to be UTC-flagged (D-35-05
      // RULED point 2); these carry the zone's WALL-CLOCK digits. The window
      // is widened by a day each side in wall-clock terms (no zone is more
      // than 14h from UTC) and the exact bound re-applied on real instants.
      final wallStart = _timeOf(startProperty).wall;
      final paddedAfter = _wallIn(
        lowerBound,
        zone,
      ).subtract(const Duration(days: 1));
      final wallAfter = paddedAfter.isBefore(wallStart)
          ? wallStart
          : paddedAfter;
      final wallBefore = _wallIn(windowEnd, zone).add(const Duration(days: 1));
      // getInstances asserts `before >= start`: a series whose first
      // occurrence is entirely after the window has nothing to expand yet
      // (a genuinely common shape — discovered in 35-01's Task 3).
      if (!wallStart.isAfter(wallBefore)) {
        for (final wall in recurrenceRule.getInstances(
          start: wallStart,
          after: wallAfter,
          includeAfter: true,
          before: wallBefore,
        )) {
          add(_instantIn(wall, zone));
        }
      }
    }
    for (final rdate in rdates) {
      add(_instantIn(rdate.wall, _zoneFor(rdate, fallback: zone)));
    }

    // Exclusions: EXDATE (any number of lines, each a comma list) and every
    // occurrence a RECURRENCE-ID override replaces. A DATE-form EXDATE
    // excludes by calendar date in the series' zone; a DATE-TIME one by
    // exact instant.
    final excludedInstants = <int>{};
    final excludedDates = <DateTime>{};
    for (final exdate
        in event.getProperties<Property>(_exdateAlias).expand(_parseDateList)) {
      if (exdate.isDate) {
        excludedDates.add(exdate.wall);
      } else {
        excludedInstants.add(
          _instantIn(
            exdate.wall,
            _zoneFor(exdate, fallback: zone),
          ).microsecondsSinceEpoch,
        );
      }
    }
    for (final override in overrides) {
      final recurrenceId = _recurrenceIdOf(override)!;
      excludedInstants.add(
        _instantIn(
          recurrenceId.wall,
          _zoneFor(recurrenceId, fallback: zone),
        ).microsecondsSinceEpoch,
      );
    }

    final kept = occurrences.values.where((instant) {
      if (excludedInstants.contains(instant.microsecondsSinceEpoch)) {
        return false;
      }
      final wall = _wallIn(instant, zone);
      return !excludedDates.contains(
        DateTime.utc(wall.year, wall.month, wall.day),
      );
    }).toList()..sort();

    // Every emitted start is a plain UTC-flagged DateTime (never
    // `.toLocal()`, which would use this MACHINE's real system timezone
    // rather than the app's `tz.local` override) — `CalendarSyncService` is
    // the one place that converts to local wall-clock (D-35-08).
    return [
      for (final occurrenceStart in kept)
        CalendarEvent(
          uid: uid,
          recurrenceId: _occurrenceKey(occurrenceStart),
          title: title,
          start: occurrenceStart,
          end: occurrenceStart.add(duration),
          isAllDay: isAllDay,
          status: status,
          calendarId: calendarId,
        ),
    ];
  }

  /// Emits the replacement occurrence a `RECURRENCE-ID` [override] describes
  /// (its own DTSTART/DTEND/SUMMARY), keyed by the occurrence it replaces —
  /// or nothing, when the override is `STATUS:CANCELLED` (the occurrence is
  /// simply gone; [_expand] has already suppressed the original). The
  /// window test is by overlap, like a single event, so an occurrence moved
  /// INTO the window appears even when its original time lay outside it.
  List<CalendarEvent> _expandOverride(
    VEvent override, {
    required _Series? series,
    required String calendarId,
    required DateTime start,
    required DateTime end,
  }) {
    final status = _mapStatus(override.status);
    if (status == CalendarEventStatus.cancelled) return const [];
    final startProperty = override.getProperty<DateTimeProperty>(
      DateTimeProperty.propertyNameStart,
    );
    if (startProperty == null) return const [];
    final recurrenceId = _recurrenceIdOf(override)!;
    final key = _occurrenceKey(
      _instantIn(
        recurrenceId.wall,
        _zoneFor(recurrenceId, fallback: series?.zone ?? tz.local),
      ),
    );

    final overrideStart = _plainUtc(_resolveInstant(startProperty));
    final endProperty = override.getProperty<DateTimeProperty>(
      DateTimeProperty.propertyNameEnd,
    );
    // RFC 5545: an override without its own DTEND keeps the series' length.
    final overrideEnd = endProperty != null
        ? _plainUtc(_resolveInstant(endProperty))
        : overrideStart.add(series?.duration ?? Duration.zero);
    if (!(overrideStart.isBefore(end) && overrideEnd.isAfter(start))) {
      return const [];
    }
    return [
      CalendarEvent(
        uid: _uidOf(override),
        recurrenceId: key,
        title: override.summary ?? '',
        start: overrideStart,
        end: overrideEnd,
        isAllDay: _isAllDay(override),
        status: status,
        calendarId: calendarId,
      ),
    ];
  }

  /// The zone and length of a master event — what an override of one of its
  /// occurrences inherits when it leaves them unstated.
  _Series? _seriesOf(VEvent master) {
    final startProperty = master.getProperty<DateTimeProperty>(
      DateTimeProperty.propertyNameStart,
    );
    if (startProperty == null) return null;
    final endProperty = master.getProperty<DateTimeProperty>(
      DateTimeProperty.propertyNameEnd,
    );
    final masterStart = _resolveInstant(startProperty);
    return _Series(
      zone: _zoneFor(_timeOf(startProperty), fallback: tz.local),
      duration: endProperty == null
          ? Duration.zero
          : _resolveInstant(endProperty).difference(masterStart),
    );
  }

  /// Resolves a `DTSTART`/`DTEND` [property] to the correct absolute
  /// instant — closes WINDOWS.md entry 2.
  ///
  /// `enough_icalendar` parses every value WITHOUT a trailing `Z` using
  /// Dart's plain `DateTime(y, m, d, h, mi, s)` constructor, which is
  /// anchored to THIS MACHINE's real system timezone — never to the ICS
  /// `TZID` parameter and never to the app's `tz.local` override (the gap
  /// discovered and documented in 35-01-SUMMARY.md). This is the one place
  /// that re-resolves the wall-clock reading against the CORRECT zone
  /// before anything else in the app sees it; `CalendarSyncService`
  /// remains the only place that then converts an already-correct instant
  /// to LOCAL wall-clock minutes (D-35-08) — this function never does that
  /// conversion itself, it only fixes what instant is being described.
  ///
  /// Zoned (`DTSTART;TZID=America/Chicago:...T140000` + a VTIMEZONE block —
  /// the form a real Google Calendar feed sends) is reinterpreted in the
  /// NAMED zone via the app's own IANA database, never via the embedded
  /// VTIMEZONE content; an unrecognised TZID falls through to floating.
  /// Floating (`DTSTART:...T140000` — no `Z`, no usable TZID) is, per
  /// RFC 5545, "this clock reading, in the viewer's own zone": [tz.local].
  DateTime _resolveInstant(DateTimeProperty property) {
    final raw = property.dateTime;
    if (raw.isUtc) return raw; // `...T140000Z` — already an absolute instant.
    final zone = _zoneFor(_timeOf(property), fallback: tz.local);
    return tz.TZDateTime(
      zone,
      raw.year,
      raw.month,
      raw.day,
      raw.hour,
      raw.minute,
      raw.second,
    );
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

/// What `EXDATE`/`RDATE` are re-labelled to before parsing (see
/// `IcsCalendarSource._parseCalendar`). `X-` names are reserved for
/// experimental use by RFC 5545, so no real feed property can collide.
const _exdateAlias = 'X-CANOPY-EXDATE';
const _rdateAlias = 'X-CANOPY-RDATE';

final _recurrenceDateLine = RegExp(
  r'^(EXDATE|RDATE)(?=[;:])',
  caseSensitive: false,
);

String _aliasRecurrenceDates(String line) => line.replaceFirstMapped(
  _recurrenceDateLine,
  (m) => m[1]!.toUpperCase() == 'EXDATE' ? _exdateAlias : _rdateAlias,
);

/// Keeps a re-labelled property's raw text verbatim, whatever its `VALUE`
/// parameter says — [_parseDateList] interprets it.
Property? _parseAliasedProperty(String name, String definition) {
  if (name != _exdateAlias && name != _rdateAlias) return null;
  return Property(definition, ValueType.text, parser: (_, text) => text);
}

/// A date or date-time exactly as written in the feed, before any zone is
/// applied. [wall] is a UTC-FLAGGED carrier of the written digits — never
/// an instant in itself; [instantIn] turns it into one.
class _IcsTime {
  const _IcsTime(
    this.wall, {
    required this.isDate,
    required this.isUtc,
    this.tzid,
  });

  final DateTime wall;
  final bool isDate;
  final bool isUtc;
  final String? tzid;
}

/// What an override inherits from its master when it leaves it unstated.
class _Series {
  const _Series({required this.zone, required this.duration});

  final tz.Location zone;
  final Duration duration;
}

String _uidOf(VEvent event) =>
    event.getProperty<TextProperty>(TextProperty.propertyNameUid)?.textValue ??
    '';

_IcsTime? _recurrenceIdOf(VEvent event) {
  final property = event.getProperty<DateTimeProperty>(
    DateTimeProperty.propertyNameRecurrenceId,
  );
  return property == null ? null : _timeOf(property);
}

_IcsTime _timeOf(DateTimeProperty property) {
  final raw = property.dateTime;
  final valueParameter = property[ParameterType.value] as ValueParameter?;
  return _IcsTime(
    DateTime.utc(
      raw.year,
      raw.month,
      raw.day,
      raw.hour,
      raw.minute,
      raw.second,
    ),
    isDate: valueParameter?.valueType == ValueType.date,
    isUtc: raw.isUtc,
    tzid: property.timezoneId,
  );
}

final _icsTimeText = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
);

/// Parses one re-labelled `EXDATE`/`RDATE` line: a comma list of DATE or
/// DATE-TIME values (or PERIODs, of which only the start is used), sharing
/// the line's own `TZID`. An unparseable entry is skipped rather than
/// failing the sync — a malformed exception date must not cost the user
/// every other event in the feed.
Iterable<_IcsTime> _parseDateList(Property property) sync* {
  final tzid = property[ParameterType.timezoneId]?.textValue;
  for (final entry in property.textValue.split(',')) {
    final text = entry.split('/').first.trim();
    final match = _icsTimeText.firstMatch(text);
    if (match == null) continue;
    int part(int i) => int.parse(match[i] ?? '0');
    yield _IcsTime(
      DateTime.utc(part(1), part(2), part(3), part(4), part(5), part(6)),
      isDate: match[4] == null,
      isUtc: match[7] != null,
      tzid: tzid,
    );
  }
}

/// The zone a written time is read in: UTC for a `Z` value, its `TZID` when
/// the app's IANA database knows it, else [fallback] (the series' own zone,
/// which is itself [tz.local] for a floating series).
tz.Location _zoneFor(_IcsTime time, {required tz.Location fallback}) {
  if (time.isUtc) return tz.UTC;
  final tzid = time.tzid;
  if (tzid != null) {
    try {
      return tz.getLocation(tzid);
    } catch (_) {
      // An unrecognised TZID (malformed feed) reads as floating rather than
      // crashing the sync.
    }
  }
  return fallback;
}

/// The absolute instant the wall-clock digits [wall] denote in [zone], as a
/// plain UTC-flagged DateTime.
DateTime _instantIn(DateTime wall, tz.Location zone) => _plainUtc(
  tz.TZDateTime(
    zone,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  ),
);

/// The wall-clock digits [instant] shows in [zone], on a UTC-flagged carrier.
DateTime _wallIn(DateTime instant, tz.Location zone) {
  final local = tz.TZDateTime.from(instant, zone);
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
  );
}

DateTime _plainUtc(DateTime instant) => DateTime.fromMicrosecondsSinceEpoch(
  instant.microsecondsSinceEpoch,
  isUtc: true,
);

/// An occurrence's identity: its start instant as a UTC ISO-8601 string.
/// Identical to what this source emitted before WINDOWS entry 1's fix, so
/// already-imported occurrences keep their `externalEventId`.
String _occurrenceKey(DateTime instant) => _plainUtc(instant).toIso8601String();

/// Adapts a feed's RRULE to what `package:rrule` accepts when expanded on a
/// wall-clock carrier in [zone]:
///
/// - `WKST` is dropped: `package:rrule` 0.2.x throws on anything but
///   `WKST=MO`, and Google writes `WKST=SU` on weekly series — so before
///   this, every such series silently produced NO occurrences at all. WKST
///   only changes the result for a weekly rule with `INTERVAL>1` whose
///   `BYDAY` includes Sunday alongside other days; that narrow case is
///   expanded with Monday weeks (accepted, documented imprecision).
/// - A UTC `UNTIL` is re-expressed as [zone]'s wall clock, since the
///   instances it is compared against are wall-clock digits too.
String _normaliseRule(String rawRule, tz.Location zone) {
  final parts = <String>[];
  for (final part in rawRule.split(';')) {
    final upper = part.toUpperCase();
    if (upper.startsWith('WKST=')) continue;
    if (upper.startsWith('UNTIL=') && upper.endsWith('Z')) {
      final match = _icsTimeText.firstMatch(part.substring(6).trim());
      if (match != null && match[4] != null) {
        int p(int i) => int.parse(match[i]!);
        final wall = _wallIn(
          DateTime.utc(p(1), p(2), p(3), p(4), p(5), p(6)),
          zone,
        );
        String two(int v) => v.toString().padLeft(2, '0');
        parts.add(
          'UNTIL=${wall.year.toString().padLeft(4, '0')}${two(wall.month)}'
          '${two(wall.day)}T${two(wall.hour)}${two(wall.minute)}'
          '${two(wall.second)}Z',
        );
        continue;
      }
    }
    parts.add(part);
  }
  return parts.join(';');
}
