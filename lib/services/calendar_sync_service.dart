import 'package:timezone/timezone.dart' as tz;

import '../data/calendar/calendar_event.dart';
import '../data/calendar/calendar_source.dart';
import '../data/calendar/composite_calendar_source.dart';
import '../data/calendar/device_calendar_source.dart';
import '../data/calendar/google_calendar_source.dart';
import '../data/calendar/ics_calendar_source.dart';
import '../data/calendar/null_calendar_source.dart';
import '../data/models/commitment_block.dart';
import '../data/repositories/commitment_block_repository.dart';
import '../data/repositories/hive_commitment_block_repository.dart';
import '../utils/commitment_window.dart';

/// The rolling look-ahead window a sync imports events for (D-35-15).
const int kCalendarSyncWindowDays = 14;

/// Why one calendar event was not imported as a [CommitmentBlock].
///
/// `allDay` IS a member — D-36-05 (RULED 2026-10-06) supersedes D-35-06
/// (`import-as-blocking`, RULED 2026-09-14): an all-day entry is now always
/// skipped and disclosed, never imported. On the owner's iPhone the prior
/// behaviour erased six working days in a 12-day window (Vacation, a 38th
/// Birthday, Fall break, Payday, Indigenous Peoples' Day, Columbus Day) —
/// `Payday` in particular is on a calendar nobody would untick and is not a
/// commitment of time, so no per-calendar filtering could ever reach it.
enum SkipReason { tooShort, cancelled, allDay }

/// The user-facing copy for [SkipReason] — verbatim from the UI-SPEC's
/// Copywriting Contract "Skipped-event reason strings" row (35-UI-SPEC.md).
/// The skip is disclosed, never silent (CAL-04's spirit). The `allDay` case's
/// string was locked in Phase 35 for exactly this behaviour and orphaned when
/// D-35-06 initially declined it (35-UI-SPEC.md line ~303) — D-36-05 adopts
/// the behaviour the string was always written for. Reused verbatim.
extension SkipReasonLabel on SkipReason {
  String get label => switch (this) {
    SkipReason.tooShort => 'Too short to schedule',
    SkipReason.cancelled => 'Cancelled',
    SkipReason.allDay => 'All-day — not imported automatically',
  };
}

/// One event that was fetched but not imported, and why.
class SkippedEvent {
  SkippedEvent({required this.title, required this.reason});

  final String title;
  final SkipReason reason;
}

/// The outcome of one [CalendarSyncService.sync] call.
class CalendarSyncResult {
  CalendarSyncResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.syncedAt,
  });

  /// The blocks written (created or updated in place) this sync.
  final List<CommitmentBlock> imported;

  /// Events that were fetched but deliberately not imported.
  final List<SkippedEvent> skipped;

  /// True when the source could not be read at all (fetch or parse
  /// failure) — [imported] and [skipped] are both empty and nothing was
  /// imported or updated. A failed sync prunes nothing BY EVENT (absence from
  /// a failed answer proves nothing), but it DOES still apply the selection
  /// prune (WINDOWS entry 11) when the caller supplied
  /// `configuredCalendarIds`: that prune is decided by the user's own
  /// persisted selection and needs no fetch, so it is true whether or not
  /// the network is. A failed sync is not an error the UI needs to render;
  /// the day still generates from last-known blocks (D-35-13).
  final bool failed;

  final DateTime syncedAt;
}

/// A stable (deterministic, cross-run) hash of [input].
///
/// Used to build a short opaque token for a feed URL inside
/// `externalEventId` without ever storing the URL itself in that field.
/// Deliberately NOT `String.hashCode` — that hash's algorithm is not a
/// documented part of the Dart language and is not guaranteed stable across
/// SDK versions, which would silently break the upsert key on a Dart
/// upgrade. FNV-1a 32-bit: simple, dependency-free, deterministic.
String _stableHash(String input) {
  const int fnvPrime = 0x01000193;
  int hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// The calendar token inside every imported [CommitmentBlock.externalEventId]
/// (`ics:<calendarIdHash>:<uid>:<recurrenceId><daySuffix>`).
///
/// One definition, used both to BUILD the id (`_buildBlock`) and to TEST
/// membership in the selection prune (WINDOWS entry 11) — so the two cannot
/// drift apart. [calendarId] must be the exact string the user's
/// configuration stores and the source stamps on [CalendarEvent.calendarId]:
/// the raw EventKit id for device events, the `google:`-prefixed id for
/// Google events, the feed URL for ICS events.
String calendarIdHash(String calendarId) => _stableHash(calendarId);

/// Matches the `ics:<8 hex>:` head of an imported block's externalEventId and
/// captures the calendar hash. A block whose id does not match is never
/// pruned — unrecognised shapes are left alone, not guessed at.
final RegExp _importedIdPattern = RegExp(r'^ics:([0-9a-f]{8}):');

/// Syncs a [CalendarSource]'s events into [CommitmentBlock]s (CAL-01).
///
/// Follows `CommitmentsNotifier`'s constructor-injected-repository-with-
/// production-default idiom. Every imported occurrence becomes a one-off,
/// date-anchored [CommitmentBlock] — no RRULE string ever enters
/// `CommitmentBlock` (D-35-07); `daysOfWeek` stays the user's own
/// hand-entered weekly commitments and this service never writes to it.
///
/// Mapping rules (35-02, all-day revised by D-36-05):
/// - A **cancelled** event is skipped with [SkipReason.cancelled]. A
///   tentative event imports normally (no per-attendee decline filtering —
///   RESEARCH Assumption A2).
/// - An **all-day** event (D-36-05 RULED 2026-10-06, superseding D-35-06's
///   `import-as-blocking`) is always skipped with [SkipReason.allDay] and
///   disclosed — never imported as a block. Confirmed against real calendar
///   data: the prior behaviour erased six working days in a 12-day window on
///   the owner's device. See 36-DECISIONS.md D-36-05 for the full record.
/// - A **multi-day** (or midnight-crossing) timed event is split into one
///   slice per local calendar day it touches, each clipped to that day's
///   `0..1440` window, each independently re-gated by
///   [commitmentWindowTooShort] — this also naturally subsumes the
///   single-day "too short / zero duration / no end time" cases, which are
///   just a multi-day split of length one.
/// - **Overlapping** events are imported exactly as given (D-35-09) — no
///   overlap detection here.
///
/// Every surviving slice is upserted by [CommitmentBlock.externalEventId]
/// so a repeat sync never duplicates; a multi-day event's per-day slices
/// each get their own id suffix so they don't collide with each other.
///
/// Prune rules (WINDOWS entry 11 — before this, `sync()` only ever upserted,
/// so an unticked calendar's blocks and a deleted event's block stayed on the
/// schedule forever). A block is only ever a prune candidate when
/// `isFromCalendar == true` AND its externalEventId has the
/// `ics:<8 hex>:` shape; a hand-entered block can never be deleted, because
/// it has no source to be re-derived from. A block written by the current
/// sync is never deleted by it.
/// - **Selection prune** (needs no fetch; runs even when the fetch fails):
///   when `configuredCalendarIds` is supplied, every candidate whose
///   [calendarIdHash] is not the hash of a configured id is deleted. Null
///   (the default) disables it.
/// - **Event prune** (only for sources that verifiably answered, only on days
///   the fetch fully covered): a candidate on a calendar owned by a source
///   that succeeded this sync (a `CompositeCalendarSource` reports which
///   children did via `listEventsByChild`; an unknown source type is
///   default-deny), dated strictly after today and strictly before the
///   window's last local day, and not re-produced by this sync, is deleted.
///   A cancelled event is not re-produced, so its block goes too. Today is excluded because EventKit's partial-overlap semantics
///   for an event that already ended this morning are not verified on
///   hardware; the window's last day is only partially fetched. **Accepted
///   cost:** an event deleted today keeps its block for the rest of today.
class CalendarSyncService {
  CalendarSyncService({
    CalendarSource? source,
    CommitmentBlockRepository? repository,
    DateTime Function()? now,
    Iterable<String>? configuredCalendarIds,
  }) : _source = source ?? NullCalendarSource(),
       _repository = repository ?? HiveCommitmentBlockRepository(),
       _now = now ?? DateTime.now,
       _configuredCalendarHashes = configuredCalendarIds
           ?.map(calendarIdHash)
           .toSet();

  final CalendarSource _source;
  final CommitmentBlockRepository _repository;
  final DateTime Function() _now;

  /// The [calendarIdHash]es of the calendars the user currently has ticked,
  /// or null when the caller supplied no selection (selection prune off).
  final Set<String>? _configuredCalendarHashes;

  Future<CalendarSyncResult> sync() async {
    final syncedAt = _now();
    final windowEnd = syncedAt.add(
      const Duration(days: kCalendarSyncWindowDays),
    );

    final List<CalendarEvent> events;
    // The sources that verifiably ANSWERED this sync. Only their absence-of-
    // an-event means anything (WINDOWS entry 11); a swallowed per-child
    // failure inside a composite must never authorise a delete.
    final List<CalendarSource> succeeded;
    try {
      final source = _source;
      if (source is CompositeCalendarSource) {
        final byChild = await source.listEventsByChild(
          start: syncedAt,
          end: windowEnd,
          calendarIds: const [],
        );
        events = byChild.events;
        succeeded = byChild.succeeded;
      } else {
        events = await source.listEvents(
          start: syncedAt,
          end: windowEnd,
          calendarIds: const [],
        );
        // A non-composite source that returned at all answered in full.
        succeeded = [source];
      }
    } catch (_) {
      // T-35-01/Security V5: any fetch/parse failure degrades to a failed
      // result and nothing is rethrown into the UI. A failed fetch imports
      // nothing and prunes nothing BY EVENT — absence from a failed answer
      // proves nothing. The SELECTION prune still runs (WINDOWS entry 11):
      // it is decided by the user's own configuration, needs no fetch, and
      // is true whether or not the network is. It is best-effort here — a
      // repository error must not turn a failed sync into a thrown one
      // (D-35-13: this path has never thrown).
      try {
        await _applyPrune(await _repository.getAll(), writtenIds: const {});
      } catch (_) {
        // Stale blocks stay until the next sync; never rethrown.
      }
      return CalendarSyncResult(
        imported: const [],
        skipped: const [],
        failed: true,
        syncedAt: syncedAt,
      );
    }

    final existing = await _repository.getAll();
    final imported = <CommitmentBlock>[];
    final skipped = <SkippedEvent>[];

    for (final event in events) {
      final mapped = _mapEvent(
        event,
        existing,
        windowStart: syncedAt,
        windowEnd: windowEnd,
      );
      if (mapped.skip != null) {
        skipped.add(SkippedEvent(title: event.title, reason: mapped.skip!));
        continue;
      }
      for (final block in mapped.blocks) {
        await _repository.save(block);
        imported.add(block);
      }
    }

    await _applyPrune(
      existing,
      writtenIds: {
        for (final b in imported)
          if (b.externalEventId != null) b.externalEventId!,
      },
      eventPrune: _eventPruneWindow(succeeded, syncedAt, windowEnd),
    );

    return CalendarSyncResult(
      imported: imported,
      skipped: skipped,
      failed: false,
      syncedAt: syncedAt,
    );
  }

  /// Deletes the stale imported blocks in [existing] (a snapshot read BEFORE
  /// this sync's upserts). [writtenIds] are the externalEventIds this sync
  /// wrote — those are never deleted. Each block id is deleted at most once.
  ///
  /// [eventPrune] is null on the failed-fetch path (no event prune without a
  /// verified answer). When present, a block is event-pruned only when its
  /// calendar hash is in `verifiedHashes` and its date is strictly between
  /// `after` and `before` (local calendar dates).
  Future<void> _applyPrune(
    List<CommitmentBlock> existing, {
    required Set<String> writtenIds,
    ({Set<String> verifiedHashes, DateTime after, DateTime before})? eventPrune,
  }) async {
    final doomed = <String>{};
    final configured = _configuredCalendarHashes;
    if (configured != null) {
      for (final block in existing) {
        // Each prune carries its OWN isFromCalendar guard (T-36-44) rather
        // than sharing one: a hand-entered block is unrecoverable if
        // deleted, and each guard is independently mutation-proven.
        if (!block.isFromCalendar) continue;
        final hash = _importedCalendarHash(block);
        if (hash == null) continue;
        if (writtenIds.contains(block.externalEventId)) continue;
        if (!configured.contains(hash)) doomed.add(block.id);
      }
    }
    if (eventPrune != null && eventPrune.verifiedHashes.isNotEmpty) {
      for (final block in existing) {
        // Its own isFromCalendar guard, separate from the selection prune's.
        if (!block.isFromCalendar) continue;
        final hash = _importedCalendarHash(block);
        if (hash == null) continue;
        if (!eventPrune.verifiedHashes.contains(hash)) continue;
        if (writtenIds.contains(block.externalEventId)) continue;
        final date = block.date;
        if (date == null) continue;
        final day = DateTime(date.year, date.month, date.day);
        if (day.isAfter(eventPrune.after) && day.isBefore(eventPrune.before)) {
          doomed.add(block.id);
        }
      }
    }
    for (final id in doomed) {
      await _repository.delete(id);
    }
  }

  /// The event prune's inputs, or null when it must not run: the verified
  /// calendars plus the only days the fetch covered end to end — strictly
  /// after the local date of [syncedAt] (today), strictly before the local
  /// date of [windowEnd] (a partial last day).
  ///
  /// Local dates are computed exactly as `_mapEvent` does (same `tz.local`,
  /// same y/m/d truncation) so "covered day" means the same thing here as
  /// where blocks are dated. Returns null — no event prune, default-deny —
  /// when there is nothing verified to prune, and ALSO when `tz.local` cannot
  /// be read: it is a `late` field that is never initialised on web
  /// (`NotificationService.initialize` returns before `tz.initializeTimeZones`
  /// there) or in a test that never set it, and a zero-event sync, which used
  /// to succeed without ever touching `tz.local`, must not start throwing.
  ({Set<String> verifiedHashes, DateTime after, DateTime before})?
  _eventPruneWindow(
    List<CalendarSource> succeeded,
    DateTime syncedAt,
    DateTime windowEnd,
  ) {
    final verified = _verifiedCalendarHashes(succeeded);
    if (verified.isEmpty) return null;
    try {
      final localSyncStart = tz.TZDateTime.from(syncedAt, tz.local);
      final localWindowEnd = tz.TZDateTime.from(windowEnd, tz.local);
      return (
        verifiedHashes: verified,
        after: DateTime(
          localSyncStart.year,
          localSyncStart.month,
          localSyncStart.day,
        ),
        before: DateTime(
          localWindowEnd.year,
          localWindowEnd.month,
          localWindowEnd.day,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// The [calendarIdHash]es of every calendar the [succeeded] sources
  /// verifiably covered — the only calendars whose blocks the event prune may
  /// touch. **Default-deny is the safety property:** only the three concrete
  /// source types whose `configuredCalendarIds` is known to be exactly what
  /// their `listEvents` answered for are recognised; any other type
  /// (including a nested composite, or a test fake) contributes nothing, so
  /// an unknown source can never authorise a delete.
  Set<String> _verifiedCalendarHashes(List<CalendarSource> succeeded) {
    final ids = <String>[];
    for (final child in succeeded) {
      ids.addAll(switch (child) {
        DeviceCalendarSource() => child.configuredCalendarIds,
        GoogleCalendarSource() => child.configuredCalendarIds,
        IcsCalendarSource() => child.configuredCalendarIds,
        _ => const <String>[],
      });
    }
    return ids.map(calendarIdHash).toSet();
  }

  /// The calendar hash from [block]'s well-formed `ics:<hash>:` id, or null
  /// when the id is absent or has any other shape — an unrecognised id is
  /// never a prune candidate. This checks the id SHAPE only; the caller is
  /// responsible for the `isFromCalendar` guard (see [_applyPrune]).
  String? _importedCalendarHash(CommitmentBlock block) {
    final id = block.externalEventId;
    if (id == null) return null;
    return _importedIdPattern.firstMatch(id)?.group(1);
  }

  /// Maps one [CalendarEvent] occurrence to zero or more [CommitmentBlock]s.
  ///
  /// [windowStart]/[windowEnd] are the SAME sync-window bounds passed to
  /// [CalendarSource.listEvents] — required here (not just there) so a
  /// multi-day split can be clipped to them (T-35-06): the ICS source's own
  /// overlap filter only requires an event to TOUCH the window, so an event
  /// whose feed-supplied span runs far outside the window (a malformed or
  /// implausible multi-year "event") must not turn into thousands of
  /// day-slices — the worst case stays bounded by [kCalendarSyncWindowDays].
  ///
  /// Returns a non-null [SkipReason] (and an empty block list) when the
  /// WHOLE event is skipped — cancelled, all-day (D-36-05), or every
  /// day-slice it produces is too short to hold a chunk. Otherwise returns
  /// one block per surviving local calendar day.
  ({List<CommitmentBlock> blocks, SkipReason? skip}) _mapEvent(
    CalendarEvent event,
    List<CommitmentBlock> existing, {
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    if (event.status == CalendarEventStatus.cancelled) {
      return (blocks: const [], skip: SkipReason.cancelled);
    }

    if (event.isAllDay) {
      // D-36-05 (RULED 2026-10-06, supersedes D-35-06 `import-as-blocking`):
      // an all-day event is always skipped and disclosed, never imported.
      // On the owner's iPhone the old blocking behaviour erased six working
      // days in a 12-day window (Vacation, a 38th Birthday, Fall break,
      // Payday, Indigenous Peoples' Day, Columbus Day) — see this file's
      // class doc comment and 36-DECISIONS.md D-36-05.
      return (blocks: const [], skip: SkipReason.allDay);
    }

    // Converts to the device's LOCAL zone via the app's existing `timezone`
    // stack, exactly as `notification_service.dart` already does —
    // `tz.TZDateTime.from(event.start, tz.local)`. No conversion to the
    // zero meridian happens here (D-35-08).
    final localStart = tz.TZDateTime.from(event.start, tz.local);
    final localEnd = tz.TZDateTime.from(event.end, tz.local);
    final eventStartDate = DateTime(
      localStart.year,
      localStart.month,
      localStart.day,
    );
    final eventEndDate = DateTime(localEnd.year, localEnd.month, localEnd.day);

    // T-35-06: clip the day RANGE to the sync window before splitting — a
    // feed-supplied span (not the parse-time overlap check, which only
    // requires the event to TOUCH the window) is otherwise unbounded.
    final localWindowStart = tz.TZDateTime.from(windowStart, tz.local);
    final localWindowEnd = tz.TZDateTime.from(windowEnd, tz.local);
    final windowStartDate = DateTime(
      localWindowStart.year,
      localWindowStart.month,
      localWindowStart.day,
    );
    final windowEndDate = DateTime(
      localWindowEnd.year,
      localWindowEnd.month,
      localWindowEnd.day,
    );
    final startDate = eventStartDate.isBefore(windowStartDate)
        ? windowStartDate
        : eventStartDate;
    final endDate = eventEndDate.isAfter(windowEndDate)
        ? windowEndDate
        : eventEndDate;
    final dayCount = endDate.difference(startDate).inDays + 1;
    if (dayCount <= 0) {
      // The event's span and the sync window do not actually overlap on
      // any local calendar day (can happen at a window edge) — nothing to
      // import, nothing to report as skipped either; this is not the
      // event's fault.
      return (blocks: const [], skip: null);
    }

    final blocks = <CommitmentBlock>[];
    for (var i = 0; i < dayCount; i++) {
      final day = startDate.add(Duration(days: i));
      // "First/last" here means the EVENT's own first/last day, not the
      // window's — a day that only appears because we clipped FORWARD to
      // windowStartDate (the event actually started earlier) is not the
      // event's first day, so it gets a full 0..1440 slice like any other
      // interior day; likewise for a day clipped BACK from the event's
      // real end.
      final isEventFirstDay = day.isAtSameMomentAs(eventStartDate);
      final isEventLastDay = day.isAtSameMomentAs(eventEndDate);
      final sliceStart = isEventFirstDay
          ? localStart.hour * 60 + localStart.minute
          : 0;
      final sliceEnd = isEventLastDay
          ? localEnd.hour * 60 + localEnd.minute
          : 1440;
      // Every slice — including a single-day event's only slice — is
      // re-gated by the SAME shared rule that guards hand-entry and
      // onboarding. This is also how a too-short, zero-duration, or
      // no-end-time event is caught: each is just a one-day split whose
      // only slice fails this gate.
      if (commitmentWindowTooShort(sliceStart, sliceEnd)) continue;
      blocks.add(
        _buildBlock(
          event: event,
          existing: existing,
          date: day,
          startMinutes: sliceStart,
          endMinutes: sliceEnd,
          // Only a genuinely multi-day split needs a per-day id suffix —
          // a single-day event keeps the tracer's original externalEventId
          // shape so already-synced blocks are not orphaned.
          daySuffix: dayCount > 1 ? day : null,
        ),
      );
    }

    if (blocks.isEmpty) {
      return (blocks: const [], skip: SkipReason.tooShort);
    }
    return (blocks: blocks, skip: null);
  }

  CommitmentBlock _buildBlock({
    required CalendarEvent event,
    required List<CommitmentBlock> existing,
    required DateTime date,
    required int startMinutes,
    required int endMinutes,
    required DateTime? daySuffix,
  }) {
    final suffix = daySuffix == null
        ? ''
        : ':${daySuffix.year.toString().padLeft(4, '0')}'
              '${daySuffix.month.toString().padLeft(2, '0')}'
              '${daySuffix.day.toString().padLeft(2, '0')}';
    final externalEventId =
        'ics:${calendarIdHash(event.calendarId)}:${event.uid}:'
        '${event.recurrenceId ?? ''}$suffix';
    final existingBlock = existing
        .where((b) => b.externalEventId == externalEventId)
        .firstOrNull;

    return CommitmentBlock(
      id: existingBlock?.id,
      name: event.title,
      daysOfWeek: const [],
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      date: date,
      externalEventId: externalEventId,
      isFromCalendar: true,
    );
  }
}
