import 'package:timezone/timezone.dart' as tz;

import '../data/calendar/calendar_event.dart';
import '../data/calendar/calendar_source.dart';
import '../data/calendar/null_calendar_source.dart';
import '../data/models/commitment_block.dart';
import '../data/repositories/commitment_block_repository.dart';
import '../data/repositories/hive_commitment_block_repository.dart';
import '../utils/commitment_window.dart';

/// The rolling look-ahead window a sync imports events for (D-35-15).
const int kCalendarSyncWindowDays = 14;

/// Why one calendar event was not imported as a [CommitmentBlock].
///
/// `tooShort` is the only reason this plan produces — the all-day and
/// cancelled-event rules are plan 35-02's territory (see
/// `CalendarSyncService.sync`'s doc comment).
enum SkipReason { tooShort }

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
/// This plan implements the single happy-path mapping only: a timed event
/// becomes one localised block, gated by the existing
/// [commitmentWindowTooShort] check, upserted by [CommitmentBlock.externalEventId]
/// so a repeat sync never duplicates. All-day events, cancelled events, and
/// multi-day/overnight splitting are explicitly **plan 35-02's** job — see
/// that plan's mapping rules.
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
      final block = _mapToBlock(event, existing);
      if (block == null) {
        skipped.add(
          SkippedEvent(title: event.title, reason: SkipReason.tooShort),
        );
        continue;
      }
      await _repository.save(block);
      imported.add(block);
    }

    return CalendarSyncResult(
      imported: imported,
      skipped: skipped,
      failed: false,
      syncedAt: syncedAt,
    );
  }

  /// Maps one [CalendarEvent] occurrence to a [CommitmentBlock], or null if
  /// it's gated out (too short — the only rule this plan implements).
  ///
  /// Converts to the device's LOCAL zone via the app's existing `timezone`
  /// stack, exactly as `notification_service.dart` already does —
  /// `tz.TZDateTime.from(event.start, tz.local)` then
  /// `hour * 60 + minute`. No conversion to the zero meridian happens here
  /// (D-35-08) — [CommitmentBlock.startMinutes]/[CommitmentBlock.endMinutes]
  /// are local wall-clock, matching every other writer of those fields.
  CommitmentBlock? _mapToBlock(
    CalendarEvent event,
    List<CommitmentBlock> existing,
  ) {
    final localStart = tz.TZDateTime.from(event.start, tz.local);
    final localEnd = tz.TZDateTime.from(event.end, tz.local);
    final startMinutes = localStart.hour * 60 + localStart.minute;
    final endMinutes = localEnd.hour * 60 + localEnd.minute;
    if (commitmentWindowTooShort(startMinutes, endMinutes)) return null;

    final externalEventId =
        'ics:${_stableHash(event.calendarId)}:${event.uid}:'
        '${event.recurrenceId ?? ''}';
    final existingBlock = existing
        .where((b) => b.externalEventId == externalEventId)
        .firstOrNull;

    return CommitmentBlock(
      id: existingBlock?.id,
      name: event.title,
      daysOfWeek: const [],
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      date: DateTime(localStart.year, localStart.month, localStart.day),
      externalEventId: externalEventId,
      isFromCalendar: true,
    );
  }
}
