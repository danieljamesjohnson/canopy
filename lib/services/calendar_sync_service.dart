import 'package:timezone/timezone.dart' as tz;

import '../data/calendar/calendar_event.dart';
import '../data/calendar/calendar_source.dart';
import '../data/calendar/null_calendar_source.dart';
import '../data/models/commitment_block.dart';
import '../data/repositories/commitment_block_repository.dart';
import '../data/repositories/hive_commitment_block_repository.dart';
import '../utils/commitment_window.dart';
import 'schedule_generator.dart';

/// The rolling look-ahead window a sync imports events for (D-35-15).
const int kCalendarSyncWindowDays = 14;

/// Why one calendar event was not imported as a [CommitmentBlock].
///
/// `allDay` is deliberately NOT a member — D-35-06 (RULED 2026-09-14,
/// `import-as-blocking`) means an all-day entry is imported, never skipped.
enum SkipReason { tooShort, cancelled }

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
  /// failure) — [imported] and [skipped] are both empty and no blocks were
  /// touched. A failed sync is not an error the UI needs to render; the day
  /// still generates from last-known blocks (D-35-13).
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

/// Syncs a [CalendarSource]'s events into [CommitmentBlock]s (CAL-01).
///
/// Follows `CommitmentsNotifier`'s constructor-injected-repository-with-
/// production-default idiom. Every imported occurrence becomes a one-off,
/// date-anchored [CommitmentBlock] — no RRULE string ever enters
/// `CommitmentBlock` (D-35-07); `daysOfWeek` stays the user's own
/// hand-entered weekly commitments and this service never writes to it.
///
/// Mapping rules (35-02):
/// - A **cancelled** event is skipped with [SkipReason.cancelled]. A
///   tentative event imports normally (no per-attendee decline filtering —
///   RESEARCH Assumption A2).
/// - An **all-day** event (D-35-06 RULED `import-as-blocking`) is imported
///   as one block spanning the app's configured working window
///   ([ScheduleGeneratorService.dayStartMinutes]..[dayEndMinutes]) on its
///   own local calendar day — NOT `0..1440`. See 35-DECISIONS.md for why.
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
class CalendarSyncService {
  CalendarSyncService({
    CalendarSource? source,
    CommitmentBlockRepository? repository,
    DateTime Function()? now,
  }) : _source = source ?? NullCalendarSource(),
       _repository = repository ?? HiveCommitmentBlockRepository(),
       _now = now ?? DateTime.now;

  final CalendarSource _source;
  final CommitmentBlockRepository _repository;
  final DateTime Function() _now;

  Future<CalendarSyncResult> sync() async {
    final syncedAt = _now();
    final windowEnd = syncedAt.add(
      const Duration(days: kCalendarSyncWindowDays),
    );

    final List<CalendarEvent> events;
    try {
      events = await _source.listEvents(
        start: syncedAt,
        end: windowEnd,
        calendarIds: const [],
      );
    } catch (_) {
      // T-35-01/Security V5: any fetch/parse failure degrades to a failed
      // result. Already-persisted blocks are left untouched below (we
      // return before reading or writing the repository at all), and
      // nothing is rethrown into the UI.
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

    return CalendarSyncResult(
      imported: imported,
      skipped: skipped,
      failed: false,
      syncedAt: syncedAt,
    );
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
  /// WHOLE event is skipped — cancelled, or every day-slice it produces is
  /// too short to hold a chunk. Otherwise returns one block per surviving
  /// local calendar day.
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
      // D-35-06 RULED `import-as-blocking`: the whole configured working
      // window on the event's own local calendar day — NOT 0..1440. See
      // this file's class doc comment and 35-DECISIONS.md.
      final localDay = tz.TZDateTime.from(event.start, tz.local);
      final block = _buildBlock(
        event: event,
        existing: existing,
        date: DateTime(localDay.year, localDay.month, localDay.day),
        startMinutes: ScheduleGeneratorService.dayStartMinutes,
        endMinutes: ScheduleGeneratorService.dayEndMinutes,
        daySuffix: null,
      );
      return (blocks: [block], skip: null);
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
    final eventEndDate = DateTime(
      localEnd.year,
      localEnd.month,
      localEnd.day,
    );

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
        'ics:${_stableHash(event.calendarId)}:${event.uid}:'
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
