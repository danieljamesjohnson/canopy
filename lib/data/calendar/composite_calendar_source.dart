import 'calendar_event.dart';
import 'calendar_source.dart';

/// Combines multiple [CalendarSource]s into one (D-36-03's carve-out for iOS
/// — see `calendar_source_factory.dart`'s own doc comment for why this
/// overrides D-35-12's "one active source type per platform" rule).
///
/// **Per-child failure policy — the one judgement call in this class, and it
/// needs to be written down here, not just implemented:** catch each
/// child's failure independently, and rethrow only when EVERY child failed.
/// The alternative — failing the whole sync when any one child fails —
/// would mean one expired Google token silently stops the owner's iCloud
/// calendar from importing, which is a worse outcome than the gap this
/// choice accepts (T-36-17, T-36-18).
///
/// **The accepted gap, stated plainly:** when one child fails and another
/// succeeds, this returns the successful child's events with no error
/// surfaced at all — a transient Google network failure, while the device
/// source keeps working, produces no user-visible signal here. The
/// expired-token case IS signalled separately and does not depend on this
/// return value: [GoogleAuthClient]'s persisted reconnect flag (plan 36-02)
/// is set independently, the moment a refresh is classified as dead. A
/// plain network blip against Google, while the device source works, is
/// genuinely silent — a known, deliberate limit, not an oversight.
///
/// Every child is queried with the SAME `calendarIds` argument, unchanged —
/// each child keeps its own "empty means all of mine" convention
/// (T-36-20); this class adds no fetching or filtering of its own.
class CompositeCalendarSource implements CalendarSource {
  CompositeCalendarSource(this._children);

  final List<CalendarSource> _children;

  /// The ordered list of sources this composite fans out to and merges
  /// results from. Exposed for tests/introspection (e.g. asserting the
  /// factory's Google-before-device ordering, D-36-03) — [CompositeCalendarSource]
  /// itself never reorders or filters this list beyond what the constructor
  /// was given.
  List<CalendarSource> get children => List.unmodifiable(_children);

  @override
  Future<bool> isAvailable() async {
    for (final child in _children) {
      if (await child.isAvailable()) return true;
    }
    return false;
  }

  @override
  Future<CalendarPermissionState> requestPermission() async =>
      // Permission is a per-child concept: Google's OAuth consent and the
      // device's OS-level permission are two different models with two
      // different UI flows, each already driven directly by the settings
      // screen for its own child. A composite that guessed one answer for
      // two different permission models would be lying about which one it
      // means.
      CalendarPermissionState.notApplicable;

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    // WR-01 code review: mirrors listEvents()'s own per-child tolerance
    // below — this class's doc comment states that policy applies to the
    // whole class, not just listEvents(), and listCalendars() previously
    // didn't honor it: one child's failure (e.g. a dead Google token) took
    // down the other child's perfectly good calendar list too.
    final infos = <CalendarInfo>[];
    var anySucceeded = false;
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final child in _children) {
      try {
        infos.addAll(await child.listCalendars());
        anySucceeded = true;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
      }
    }
    if (!anySucceeded && _children.isNotEmpty) {
      Error.throwWithStackTrace(
        lastError ?? StateError('all calendar sources failed'),
        lastStackTrace ?? StackTrace.current,
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
    var anySucceeded = false;
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final child in _children) {
      try {
        events.addAll(
          await child.listEvents(
            start: start,
            end: end,
            calendarIds: calendarIds,
          ),
        );
        anySucceeded = true;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
      }
    }
    if (!anySucceeded && _children.isNotEmpty) {
      Error.throwWithStackTrace(
        lastError ?? StateError('all calendar sources failed'),
        lastStackTrace ?? StackTrace.current,
      );
    }
    return events;
  }
}
