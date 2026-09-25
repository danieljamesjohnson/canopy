import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;

import 'calendar_event.dart';
import 'calendar_source.dart';
import 'google_auth_client.dart';

/// Raised for any Calendar API/network failure — same one-field shape as
/// `IcsSourceException`, so `CalendarSyncService`'s existing catch-all
/// degrades a Google failure exactly the way it already degrades an ICS
/// failure.
class GoogleSourceException implements Exception {
  GoogleSourceException(this.message);

  final String message;

  @override
  String toString() => 'GoogleSourceException: $message';
}

/// Produces the `http.Client` used for one Calendar API call — tests inject
/// a fake here to return canned JSON with no network involved; production
/// forwards to [GoogleAuthClient.authenticatedClient], which handles token
/// refresh first.
typedef GoogleApiClientFactory = Future<http.Client> Function();

/// Every Google calendar id this source hands out or accepts is prefixed
/// with this string, so a Google calendar id can never be confused with a
/// device calendar id in the persisted selection (plan 36-05 depends on this
/// being unambiguous). Stripped before ever being sent to Google.
const String _googleIdPrefix = 'google:';

/// The fourth [CalendarSource] implementation (CONTEXT decision 3) — reads
/// events from the signed-in Google account via `googleapis`'s typed
/// Calendar client.
///
/// Read-only by construction: the [CalendarSource] interface declares no
/// write verb, this file never calls a mutating `CalendarApi` verb, and the
/// read-only scope means Google would refuse a write call even if one were
/// attempted (CONTEXT decision 2, T-36-03).
class GoogleCalendarSource implements CalendarSource {
  GoogleCalendarSource({
    required GoogleAuthClient authClient,
    required List<String> calendarIds,
    GoogleApiClientFactory? apiClientFactory,
  }) : _authClient = authClient,
       _calendarIds = calendarIds,
       _apiClientFactory = apiClientFactory ?? authClient.authenticatedClient;

  final GoogleAuthClient _authClient;
  final List<String> _calendarIds;
  final GoogleApiClientFactory _apiClientFactory;

  @override
  Future<bool> isAvailable() async => _authClient.hasCredentials();

  @override
  Future<CalendarPermissionState> requestPermission() async {
    // A user cancellation maps to notDetermined, NOT denied — `denied`
    // drives the settings screen's denied card, which is the wrong surface
    // for someone who simply backed out of the consent sheet; notDetermined
    // returns them to the CTA with nothing on screen implying a fault.
    final cancelled = await _authClient.connect();
    return cancelled
        ? CalendarPermissionState.notDetermined
        : CalendarPermissionState.granted;
  }

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    final client = await _apiClientFactory();
    try {
      final api = CalendarApi(client);
      final result = await api.calendarList.list();
      return (result.items ?? const [])
          .where((entry) => entry.id != null)
          .map(
            (entry) => CalendarInfo(
              id: '$_googleIdPrefix${entry.id}',
              name: entry.summary ?? entry.id!,
              accountName: entry.id,
              accountType: 'Google',
              colorHex: entry.backgroundColor,
              isReadOnly: true,
            ),
          )
          .toList();
    } catch (_) {
      throw GoogleSourceException('failed to list Google calendars');
    } finally {
      client.close();
    }
  }

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async {
    // Empty means "every calendar this source is configured for" — the same
    // convention IcsCalendarSource.listEvents follows, and exactly what
    // CalendarSyncService.sync() passes.
    final targetIds = calendarIds.isEmpty ? _calendarIds : calendarIds;
    final client = await _apiClientFactory();
    try {
      final api = CalendarApi(client);
      final events = <CalendarEvent>[];
      for (final prefixedId in targetIds) {
        final googleId = _stripPrefix(prefixedId);
        String? pageToken;
        do {
          final response = await api.events.list(
            googleId,
            timeMin: start,
            timeMax: end,
            // Expands recurrences with exceptions applied — the defect the
            // ICS path provably cannot fix. Deliberate, not the API default.
            singleEvents: true,
            // Makes a cancelled occurrence come back as a stub instead of
            // silently vanishing. Deliberate, not the API default.
            showDeleted: true,
            pageToken: pageToken,
          );
          for (final item in response.items ?? const []) {
            final mapped = _mapEvent(item, calendarId: prefixedId);
            if (mapped != null) events.add(mapped);
          }
          pageToken = response.nextPageToken;
        } while (pageToken != null);
      }
      return events;
    } catch (_) {
      throw GoogleSourceException('failed to list Google events');
    } finally {
      client.close();
    }
  }

  String _stripPrefix(String id) =>
      id.startsWith(_googleIdPrefix)
          ? id.substring(_googleIdPrefix.length)
          : id;

  CalendarEvent? _mapEvent(Event event, {required String calendarId}) {
    final uid = event.id;
    if (uid == null) return null;
    final start = _resolveInstant(event.start);
    final end = _resolveInstant(event.end);
    if (start == null || end == null) return null;
    return CalendarEvent(
      uid: uid,
      title: event.summary ?? '',
      start: start,
      end: end,
      isAllDay: event.start?.date != null,
      status: _mapStatus(event.status),
      calendarId: calendarId,
    );
  }

  DateTime? _resolveInstant(EventDateTime? dateTime) {
    if (dateTime == null) return null;
    return dateTime.dateTime ?? dateTime.date;
  }

  CalendarEventStatus _mapStatus(String? status) => switch (status) {
    'cancelled' => CalendarEventStatus.cancelled,
    'tentative' => CalendarEventStatus.tentative,
    _ => CalendarEventStatus.confirmed,
  };
}
