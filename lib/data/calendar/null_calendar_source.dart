import 'calendar_event.dart';
import 'calendar_source.dart';

/// The always-safe fallback [CalendarSource] (D-35-12, CAL-04).
///
/// Used whenever no real source is configured or available for the current
/// platform: reports itself unavailable, returns empty lists, and never
/// throws. A platform with no calendar integration yet (or a user who has
/// configured nothing) gets a fully functional app with zero imported
/// commitments — never a crash.
class NullCalendarSource implements CalendarSource {
  @override
  Future<bool> isAvailable() async => false;

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
  }) async => const [];
}
