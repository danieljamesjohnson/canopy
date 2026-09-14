// Uniform shapes every CalendarSource implementation normalises into.
//
// Plain Dart classes — none of these are ever persisted directly, so none
// carry Hive annotations. CalendarEvent is the per-occurrence shape that
// CalendarSyncService maps into a one-off CommitmentBlock (D-35-07).

/// The confirmation state of a single calendar event occurrence.
enum CalendarEventStatus {
  /// The organizer has confirmed the event will happen.
  confirmed,

  /// The event is provisional and may not happen.
  tentative,

  /// The event (or this occurrence of it) was cancelled. A cancelled
  /// occurrence is display-only context here — Phase 35-01's mapper does not
  /// yet filter on it; that rule taxonomy lands in plan 35-02.
  cancelled,
}

/// The result of asking a [CalendarSource] for OS-level calendar permission.
enum CalendarPermissionState {
  /// The user has granted read access.
  granted,

  /// The user explicitly denied read access.
  denied,

  /// The platform restricts access (e.g. parental controls, MDM policy) and
  /// no prompt is available.
  restricted,

  /// The user has not yet been asked.
  notDetermined,

  /// This source has no concept of OS permission at all (e.g. a subscribed
  /// `.ics` feed needs none). Distinct from [denied] — there is nothing to
  /// grant or deny.
  notApplicable,
}

/// A single normalised calendar event occurrence, as returned by
/// [CalendarSource.listEvents].
///
/// One recurring source event expands into one [CalendarEvent] per
/// occurrence within the requested window — [uid] is shared across all of an
/// event's occurrences, [recurrenceId] (when non-null) distinguishes one
/// occurrence from its siblings.
class CalendarEvent {
  CalendarEvent({
    required this.uid,
    this.recurrenceId,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    required this.status,
    required this.calendarId,
  });

  /// The event's stable identity across all its occurrences (ICS `UID`).
  final String uid;

  /// This occurrence's own identity when [uid] recurs (ICS `RECURRENCE-ID`).
  /// Null for a non-recurring event or for the "master" definition of a
  /// recurring one.
  final String? recurrenceId;

  /// The event's display title (ICS `SUMMARY`).
  final String title;

  /// This occurrence's start instant.
  final DateTime start;

  /// This occurrence's end instant.
  final DateTime end;

  /// True when the source marked this as an all-day event. Phase 35-01 only
  /// carries this flag through — deciding what an all-day event becomes on
  /// the schedule is D-35-06 / plan 35-02's job.
  final bool isAllDay;

  /// This occurrence's confirmation state.
  final CalendarEventStatus status;

  /// The identifier of the calendar (or feed URL, for ICS) this event came
  /// from — echoes back the id the caller passed to `listEvents`.
  final String calendarId;
}

/// Metadata about one calendar a [CalendarSource] can read from, as returned
/// by [CalendarSource.listCalendars].
class CalendarInfo {
  CalendarInfo({
    required this.id,
    required this.name,
    this.accountName,
    this.accountType,
    this.colorHex,
    required this.isReadOnly,
  });

  /// Stable identifier for this calendar — an OS calendar id on-device, or
  /// the feed URL itself for an ICS subscription.
  final String id;

  /// Display name (e.g. "Work", "Family", or an ICS feed's `X-WR-CALNAME`).
  final String name;

  /// The account this calendar belongs to, when the source can report one
  /// (e.g. "dan@gmail.com"). Null for sources with no account concept.
  final String? accountName;

  /// The account type, when the source can report one (e.g. "Google",
  /// "iCloud"). Null for sources with no account concept.
  final String? accountType;

  /// The calendar's display color, as a hex string, when known.
  final String? colorHex;

  /// Always true today — CAL-03 means Canopy never writes to a calendar, so
  /// every [CalendarSource] implementation reports every calendar as
  /// read-only regardless of what the OS itself would allow.
  final bool isReadOnly;
}
