// Widget tests for the Phase 22 Plan 02 Today-screen row vocabulary:
// TimelineRowTile (46dp time gutter), FreeTimeRow (named free time),
// ChunkCard's extended row treatments, and LiveRowCard (the swelled
// in-place current-activity card).
//
// Pure widget work — nothing here knows what time it is; the screen
// (plan 22-03) decides what's live and passes it in.

import 'package:canopy/screens/today/widgets/free_time_row.dart';
import 'package:canopy/screens/today/widgets/timeline_row_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

void main() {
  group('TimelineRowTile (D-04, D-06)', () {
    testWidgets('renders compact time text for a given startMinutes', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        const TimelineRowTile(startMinutes: 645, child: Text('Reading')),
      );
      expect(find.text('10:45'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets(
      'renders no time text but still lays out the child when startMinutes is null',
      (tester) async {
        await pumpWithMood(
          tester,
          const TimelineRowTile(
            startMinutes: null,
            child: Text('Free until 8:00 AM'),
          ),
        );
        expect(find.text('Free until 8:00 AM'), findsOneWidget);
        // No gutter time text rendered anywhere.
        expect(find.text('10:45'), findsNothing);
      },
    );

    testWidgets('gutter SizedBox is exactly kGutterWidth wide', (tester) async {
      await pumpWithMood(
        tester,
        const TimelineRowTile(startMinutes: 480, child: Text('Exercise')),
      );
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((box) => box.width == kGutterWidth),
        isTrue,
        reason: 'Expected a SizedBox of width kGutterWidth (46.0)',
      );
      expect(kGutterWidth, 46.0);
    });
  });

  group('FreeTimeRow (D-05, LOCKED copy)', () {
    testWidgets('leading form renders exactly "Free until 8:00 AM"', (
      tester,
    ) async {
      await pumpWithMood(tester, const FreeTimeRow.until(untilMinutes: 480));
      expect(find.text('Free until 8:00 AM'), findsOneWidget);
    });

    testWidgets('gap form renders exactly "Free · 1h 40m"', (tester) async {
      await pumpWithMood(tester, const FreeTimeRow.gap(durationMinutes: 100));
      expect(find.text('Free · 1h 40m'), findsOneWidget);
    });

    testWidgets('neither form renders a Card', (tester) async {
      await pumpWithMood(tester, const FreeTimeRow.until(untilMinutes: 480));
      expect(find.byType(Card), findsNothing);

      await pumpWithMood(tester, const FreeTimeRow.gap(durationMinutes: 100));
      expect(find.byType(Card), findsNothing);
    });
  });
}
