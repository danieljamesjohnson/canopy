// Wave 0 stub for READ-03 (sheet) — turns green after Plan 08-02 creates
// lib/screens/schedule/widgets/chunk_detail_sheet.dart.
//
// Status: GREEN after Plan 08-02.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/schedule/widgets/chunk_detail_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ScheduledChunk _workChunk() => ScheduledChunk(
  id: 'c1',
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'g1',
  durationMinutes: 25,
  rationale: 'Habit',
);

/// Minimal fake ScheduleNotifier that does not touch Hive.
class _FakeScheduleNotifier extends ScheduleNotifier {
  _FakeScheduleNotifier() : super();

  @override
  Future<void> init() async {
    // No-op — skips Hive bootstrap.
  }
}

void main() {
  group('ChunkDetailSheet (READ-03)', () {
    testWidgets('shows goal name, rationale, and three action buttons', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();

      await pumpWithMood(
        tester,
        ChunkDetailSheet(
          chunk: _workChunk(),
          notifier: notifier,
          goalName: 'Morning Run',
          displayRationale: 'Daily habit',
        ),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );

      expect(
        find.text('Morning Run'),
        findsOneWidget,
        reason: 'READ-03: sheet must display the goal name',
      );
      expect(
        find.text('Daily habit'),
        findsOneWidget,
        reason: 'READ-03: sheet must display the rationale',
      );
      expect(
        find.text('Mark complete'),
        findsOneWidget,
        reason: 'READ-03: sheet must show a Mark complete action',
      );
      expect(
        find.text('Skip chunk'),
        findsOneWidget,
        reason: 'READ-03: sheet must show a Skip chunk action',
      );
      expect(
        find.text('Defer to later'),
        findsOneWidget,
        reason: 'READ-03: sheet must show a Defer to later action',
      );
    });

    testWidgets('resolved chunk shows status badge and no action buttons', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();
      final chunk = ScheduledChunk(
        id: 'c2',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'g1',
        durationMinutes: 25,
        rationale: 'Habit',
      )..isCompleted = true;

      await pumpWithMood(
        tester,
        ChunkDetailSheet(
          chunk: chunk,
          notifier: notifier,
          goalName: 'Morning Run',
          displayRationale: 'Daily habit',
        ),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );

      expect(
        find.text('Completed'),
        findsOneWidget,
        reason: 'READ-03: resolved chunk shows Completed badge',
      );
      expect(
        find.text('Mark complete'),
        findsNothing,
        reason: 'READ-03: no action buttons on resolved chunk',
      );
    });
  });
}
