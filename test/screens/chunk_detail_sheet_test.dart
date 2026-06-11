// Wave 0 stub for READ-03 (sheet) — turns green when Plan 08-02 creates
// lib/screens/schedule/widgets/chunk_detail_sheet.dart with goal name,
// rationale display, and three action buttons.
//
// Status: RED until Plan 08-02.
//
// To make this file compile before ChunkDetailSheet exists, a local no-op
// stub widget is defined below. Plan 08-02 should REMOVE the local stub
// and add the real import:
//   import 'package:canopy/screens/schedule/widgets/chunk_detail_sheet.dart';

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// LOCAL STUB — remove and replace with real import when Plan 08-02 lands.
// ---------------------------------------------------------------------------

/// Placeholder ChunkDetailSheet that renders NOTHING, so all the
/// find.text() expects below fail RED until the real widget is implemented.
class ChunkDetailSheet extends StatelessWidget {
  const ChunkDetailSheet({
    super.key,
    required this.chunk,
    required this.notifier,
    this.goalColor,
    this.goalName,
    required this.displayRationale,
  });

  final ScheduledChunk chunk;
  final ScheduleNotifier notifier;
  final Color? goalColor;
  final String? goalName;
  final String displayRationale;

  @override
  Widget build(BuildContext context) {
    // Stub renders nothing — causes all expects to fail RED.
    return const SizedBox.shrink();
  }
}

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
    testWidgets(
      'shows goal name, rationale, and three action buttons',
      (tester) async {
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

        // These expects are RED until Plan 08-02 replaces the stub widget.
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
      },
    );
  });
}
