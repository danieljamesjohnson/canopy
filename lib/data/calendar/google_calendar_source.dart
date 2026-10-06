import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

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
///
/// **Public and shared (WR-02 code review)** — `calendar_settings_screen.dart`
/// and `checkin_screen.dart` both need this exact prefix to filter the
/// persisted selection down to Google ids, and previously hardcoded their
/// own `'google:'` literal independently. Import and reference THIS
/// constant from any new call site instead of retyping the literal — a
/// future rename here must break the build at every site that still needs
/// updating, not silently desynchronize them.
const String googleCalendarIdPrefix = 'google:';

/// The exact filter `calendar_settings_screen.dart`'s `_googleSelectedIds`
/// and `checkin_screen.dart`'s `_generate()` both need on the user's
/// persisted calendar selection, to know which of the ticked ids are
/// Google's — factored out (WR-02 code review) so the filtering behavior
/// itself, not just the prefix string, has exactly one definition. Before
/// this, each call site re-implemented `.where((id) => id.startsWith(...))`
/// against its own copy of the prefix literal; a future change to what
/// counts as "a Google id" now only needs to change here.
List<String> filterGoogleCalendarIds(Iterable<String> ids) =>
    ids.where((id) => id.startsWith(googleCalendarIdPrefix)).toList();

/// The exact complement of [filterGoogleCalendarIds] — every id in the
/// user's persisted selection that is NOT a Google id, i.e. the device half
/// `DeviceCalendarSource` needs at construction time (WINDOWS entry 7,
/// CAL-02). Deliberately defined immediately below its Google counterpart,
/// in this one file, so a future change to what counts as "a Google id"
/// cannot update one filter and silently miss the other — the same failure
/// WR-02 was raised about, one level up. Do not create a third place that
/// knows the prefix.
List<String> filterDeviceCalendarIds(Iterable<String> ids) =>
    ids.where((id) => !id.startsWith(googleCalendarIdPrefix)).toList();

/// The user-facing label this source stamps on every calendar it returns
/// (D-36-03) — the picker's group-header text (plan 36-06), not an
/// identifier. Kept in exactly one place per [CalendarInfo.sourceLabel]'s
/// own contract.
const String _googleSourceLabel = 'Google';

/// Fallback [CalendarInfo.accountName] used only when `calendarList.list()`
/// returns no entry with `primary == true` (WR-03 code review, an edge case
/// — a restricted view, or a future API change). Without this fallback,
/// every calendar in that response would carry a null `accountName`, which
/// `_calendarRows` (calendar_settings_screen.dart) groups under the
/// empty-string bucket — rendered as the literal header `'This device'`, a
/// real mislabeling of the data source. A non-null label here also keeps
/// the calendar eligible for `detectSelectedCalendarOverlaps`, which
/// requires a non-null `accountName` on both sides before it can ever flag
/// a possible duplicate.
const String _googleFallbackAccountLabel = 'Google';

// ── Pure mapping functions ──────────────────────────────────────────────
//
// Deliberately top-level, taking plain googleapis-shaped values rather than
// reaching into the authenticated CalendarApi client — this is the seam
// that lets the mapping be unit-tested against fixture JSON with no
// network, mirroring device_calendar_source.dart's own pure/adapter split.
// Nothing below this comment can reach the adapter, the auth client, or the
// network; nothing above it needs any of those to prove correct.

/// Maps Google's `status` string onto this app's [CalendarEventStatus].
///
/// Mirrors `IcsCalendarSource._mapStatus`'s own default: anything that
/// isn't explicitly `cancelled` or `tentative` reads as confirmed.
CalendarEventStatus mapGoogleEventStatus(String? status) => switch (status) {
  'cancelled' => CalendarEventStatus.cancelled,
  'tentative' => CalendarEventStatus.tentative,
  _ => CalendarEventStatus.confirmed,
};

/// Resolves one Google `EventDateTime` to an absolute instant, or `null`
/// when [value] itself is `null` or carries neither a `dateTime` nor a
/// `date` (the minimal cancelled-stub shape Google returns for a deleted
/// instance).
///
/// A `dateTime` value already carries an explicit UTC `Z` or a numeric
/// offset — `googleapis`'s own `EventDateTime.fromJson` parses it with
/// `DateTime.parse`, which already resolves an offset to the correct
/// absolute instant (confirmed against the installed `googleapis` 17.0.0:
/// `DateTime.parse('...T19:00:00-05:00')` returns a UTC `DateTime` at the
/// right instant, `isUtc == true`, not a value re-anchored to any other
/// zone). This function therefore returns [EventDateTime.dateTime]
/// UNCHANGED. Never call `.toLocal()` on it, here or downstream — that
/// would re-anchor to THIS MACHINE's real system timezone rather than the
/// app's `tz.local` override, the exact trap `IcsCalendarSource
/// ._resolveInstant` documents (a mutation proof caught it in Phase 35).
///
/// A `date`-only value (all-day) carries no timezone info at all —
/// `DateTime.parse('yyyy-mm-dd')` resolves it as a system-local `DateTime`
/// at midnight, which is unsafe to use directly for the same reason. Only
/// the year/month/day are extracted and reinterpreted as midnight in the
/// app's `tz.local`, mirroring `IcsCalendarSource._resolveInstant`'s
/// floating-value discipline.
DateTime? resolveGoogleInstant(EventDateTime? value) {
  if (value == null) return null;
  final dateTime = value.dateTime;
  if (dateTime != null) return dateTime;
  final date = value.date;
  if (date == null) return null;
  return tz.TZDateTime(tz.local, date.year, date.month, date.day);
}

/// Maps one Google `Event` onto this app's uniform [CalendarEvent], or
/// `null` when it carries no usable start at all (see the null-guard
/// below).
///
/// **`originalStartTime` is read and then deliberately discarded**, except
/// as the last-resort fallback below. It names where a recurring occurrence
/// WOULD have started before it moved — using it as the occurrence's actual
/// start is precisely the duplicate-meeting bug this whole path exists to
/// fix (`WINDOWS.md` entry 1, scoped to the `.ics` path only — see this
/// file's class doc comment). `singleEvents: true` has already applied the
/// move; this function must not "correct" it back. Do not "fix" the unused
/// look of this field by wiring it into the primary start — a future reader
/// who does that reintroduces the bug.
///
/// `uid`/`recurrenceId` follow [CalendarEvent]'s documented contract, the
/// mirror image of `device_calendar_source.dart`'s `mapDeviceEvent`: when
/// Google's `recurringEventId` is present, it — the SERIES id — becomes
/// [CalendarEvent.uid], and this occurrence's own `id` becomes
/// [CalendarEvent.recurrenceId]. A non-recurring event has no
/// `recurringEventId`, so its own `id` is both its uid and its only
/// occurrence identity ([CalendarEvent.recurrenceId] stays null).
CalendarEvent? mapGoogleEvent(Event event, {required String calendarId}) {
  final uid = event.recurringEventId ?? event.id;
  if (uid == null) return null;

  final ownStart = resolveGoogleInstant(event.start);
  final fallbackStart = resolveGoogleInstant(event.originalStartTime);
  // The null-guard the mandatory second mutation proof targets (recorded in
  // 36-03-SUMMARY.md): a cancelled stub can carry NEITHER a usable `start`
  // NOR a usable `originalStartTime` at all — Google's minimal shape for a
  // deleted instance (only id/status/recurringEventId populated). Without
  // this check, the force-unwrap on the next line throws "Null check
  // operator used on a null value" instead of this function returning a
  // clean null.
  if (ownStart == null && fallbackStart == null) return null;
  final start = ownStart ?? fallbackStart!;
  final end = resolveGoogleInstant(event.end) ?? start;

  return CalendarEvent(
    uid: uid,
    recurrenceId: event.recurringEventId != null ? event.id : null,
    // Cancelled stubs routinely carry no summary at all — an ordinary
    // shape, not an edge case worth throwing over.
    title: event.summary ?? '',
    start: start,
    end: end,
    isAllDay: event.start?.date != null,
    status: mapGoogleEventStatus(event.status),
    calendarId: calendarId,
  );
}

// ── The adapter ──────────────────────────────────────────────────────────

/// The fourth [CalendarSource] implementation (CONTEXT decision 3) — reads
/// events from the signed-in Google account via `googleapis`'s typed
/// Calendar client.
///
/// Read-only by construction, but on a STRONGER footing than
/// `DeviceCalendarSource`'s equivalent guarantee, and the phase can
/// demonstrate the difference rather than merely claim it. The device path
/// rests on this app simply never calling a write verb — enforced by code
/// review and by `flutter analyze` confirming every [CalendarSource]
/// implementation satisfies exactly this interface (see
/// `calendar_source.dart`'s own doc comment). This path rests on something
/// stronger: the OAuth token itself is INCAPABLE of writing, because Google
/// issued it for the `calendar.readonly` scope alone (CONTEXT decision 2,
/// CALAUTH-02, T-36-09) — Google refuses a write call at the API layer even
/// if this code attempted one. Both halves are machine-checked, not just
/// asserted: no mutating `CalendarApi` verb is reachable anywhere in
/// `lib/data/calendar/` (grep-proven), and the scope handed to the auth
/// client is exactly one element, asserted against a bare literal in
/// `google_calendar_source_test.dart` — never re-derived from the constant
/// it checks.
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
      final entries = result.items ?? const [];
      // The PRIMARY entry's id IS the account email (Google's documented
      // convention) — a secondary or subscribed calendar's own id is not an
      // account identifier (often synthetic, e.g. ending in
      // `@group.calendar.google.com` or a holiday feed's opaque id).
      // Grouping (the settings picker) and plan 36-05's overlap detector
      // both need one shared account value per source, so every calendar in
      // this response uses the primary entry's id, never its own.
      String? accountEmail;
      for (final entry in entries) {
        if (entry.primary == true) {
          accountEmail = entry.id;
          break;
        }
      }
      // WR-03: guarantee a non-null accountName even when no primary entry
      // was found — see _googleFallbackAccountLabel's own doc comment.
      accountEmail ??= _googleFallbackAccountLabel;
      return entries
          .where((entry) => entry.id != null)
          .map(
            (entry) => CalendarInfo(
              id: '$googleCalendarIdPrefix${entry.id}',
              name: entry.summary ?? entry.id!,
              accountName: accountEmail,
              accountType: 'Google',
              colorHex: entry.backgroundColor,
              isReadOnly: true,
              sourceLabel: _googleSourceLabel,
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
            final mapped = mapGoogleEvent(item, calendarId: prefixedId);
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

  String _stripPrefix(String id) => id.startsWith(googleCalendarIdPrefix)
      ? id.substring(googleCalendarIdPrefix.length)
      : id;
}
