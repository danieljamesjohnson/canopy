import 'calendar_event.dart';

/// A source of read-only calendar data.
///
/// CAL-03 ("Canopy never writes to the user's calendar") is enforced by this
/// interface's own shape rather than by a runtime check: there is no verb
/// here that could mutate a calendar, so no implementation can, and
/// `flutter analyze` — confirming every implementation satisfies exactly
/// this interface and nothing else — is the whole proof. Do not add a write
/// verb "for symmetry" with a repository interface; this one is deliberately
/// one-directional.
///
/// Follows `lib/data/repositories/commitment_block_repository.dart`'s shape:
/// a bare `abstract class`, no state, no constructor, one `Future` verb per
/// capability.
abstract class CalendarSource {
  /// Whether this source can currently produce events at all (e.g. an ICS
  /// source with no configured URLs, or a device source with calendar
  /// access permanently unavailable on this platform, returns false).
  Future<bool> isAvailable();

  /// Requests OS-level permission to read calendar data, if this source's
  /// platform has such a concept. Sources with no permission concept (e.g.
  /// a subscribed ICS feed) return [CalendarPermissionState.notApplicable].
  Future<CalendarPermissionState> requestPermission();

  /// Lists the calendars this source can read from.
  Future<List<CalendarInfo>> listCalendars();

  /// Lists event occurrences starting in `[start, end)` across
  /// [calendarIds]. Implementations expand any recurrence themselves —
  /// callers always receive one [CalendarEvent] per concrete occurrence,
  /// never a recurrence rule.
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  });
}
