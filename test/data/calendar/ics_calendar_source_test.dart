import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:canopy/data/calendar/ics_calendar_source.dart';

/// Drives [IcsCalendarSource] over a fixture through the [IcsFetcher] seam
/// — no network. Mirrors the harness `test/services/calendar_sync_service_test.dart`
/// already established.
Future<String> _fixture(String name) =>
    File('test/fixtures/calendar/$name').readAsString();

void main() {
  tzdata.initializeTimeZones();

  group('IcsCalendarSource — recurrence exceptions (35-02, RESEARCH A4)', () {
    test(
      'RECURRENCE-ID and EXDATE are NOT applied by the chosen package stack '
      '— confirmed finding, WINDOWS.md entry 1 (explicitly out of scope '
      'for this plan; see the SUMMARY for the full finding and why no '
      'hand-rolled exception layer is added here)',
      () async {
        final text = await _fixture('recurring_with_exception.ics');
        final source = IcsCalendarSource(
          urls: ['https://example.com/feed.ics'],
          fetch: (_) async => text,
        );

        // The fixture's RRULE is FREQ=WEEKLY;COUNT=5 starting 2026-03-02 —
        // a window covering several weeks past the last occurrence.
        final events = await source.listEvents(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 4, 1),
          calendarIds: const [],
        );

        // Ordinary (non-exception) occurrences return at the base time —
        // this part of the assumption the package was chosen on DOES hold.
        for (final expectedStart in [
          DateTime.utc(2026, 3, 2, 14),
          DateTime.utc(2026, 3, 9, 14),
          DateTime.utc(2026, 3, 30, 14),
        ]) {
          expect(
            events.any((e) => e.start.isAtSameMomentAs(expectedStart)),
            isTrue,
            reason: 'ordinary occurrence at $expectedStart missing',
          );
        }

        // CONFIRMED FINDING: the RECURRENCE-ID override does NOT replace
        // the base occurrence it targets — the un-excluded base occurrence
        // at the ORIGINAL time is still returned...
        expect(
          events.any(
            (e) => e.start.isAtSameMomentAs(DateTime.utc(2026, 3, 16, 14)),
          ),
          isTrue,
          reason:
              'the un-excluded base occurrence at the ORIGINAL time is '
              'still present — RECURRENCE-ID does not suppress it '
              '(confirmed finding, not the ideal RFC 5545 behaviour)',
        );
        // ...and the override is returned as an ADDITIONAL, separate event
        // rather than a replacement.
        final overrideEvent = events.firstWhere(
          (e) => e.start.isAtSameMomentAs(DateTime.utc(2026, 3, 16, 16)),
          orElse: () => throw StateError('override occurrence missing'),
        );
        expect(
          overrideEvent.title,
          'Weekly sync (moved)',
          reason: 'the override event is present as an ADDITIONAL occurrence',
        );
        // It also carries no recurrenceId at all — not tied back to the
        // occurrence it was meant to replace (a further symptom of the
        // same gap, not a separate defect).
        expect(overrideEvent.recurrenceId, isNull);

        // CONFIRMED FINDING: EXDATE is not honored — the excluded
        // occurrence is still returned at its base time.
        expect(
          events.any(
            (e) => e.start.isAtSameMomentAs(DateTime.utc(2026, 3, 23, 14)),
          ),
          isTrue,
          reason:
              'EXDATE is not applied — the excluded occurrence is still '
              'returned (WINDOWS.md entry 1, confirmed finding)',
        );

        // Pins the exact current shape so a future change to either
        // dependency (or a hand-rolled fix, when one is eventually built)
        // is visible here as a deliberate, reviewed change to this test —
        // 5 base occurrences (including the un-excluded, un-replaced ones)
        // + 1 additional override event = 6.
        expect(events, hasLength(6));

        // Every occurrence that DOES carry a recurrenceId carries a
        // distinct one (this part of the original assumption holds even
        // though EXDATE/RECURRENCE-ID do not) — the override event above
        // is the sole exception, already asserted separately as null.
        final recurrenceIds = events
            .map((e) => e.recurrenceId)
            .whereType<String>()
            .toList();
        expect(recurrenceIds.toSet().length, recurrenceIds.length);
      },
    );
  });
}
