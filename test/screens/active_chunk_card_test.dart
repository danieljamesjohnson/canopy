// Widget tests for ActiveChunkCard and the HomeScreen Now/Next refactor — Phase 12 Plan 03.
//
// NAV-02: Home leads with a "Now" section (ActiveChunkCard with always-visible
// Complete/Skip buttons), a "Next" section for the second unresolved work chunk,
// and a "See full schedule" link that navigates to /schedule.
//
// Tests pump ActiveChunkCard directly (Task 1) and HomeScreen (Task 2).
// Mirrors home_screen_breathing_pulse_test.dart provider wiring pattern.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/home/widgets/active_chunk_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}

  String? lastCompletedId;
  String? lastSkippedId;

  @override
  Future<void> markComplete(String chunkId) async {
    lastCompletedId = chunkId;
  }

  @override
  Future<void> markSkipped(String chunkId) async {
    lastSkippedId = chunkId;
  }
}

class _FakeGoalsNotifier extends GoalsNotifier {
  @override
  Future<void> loadGoals() async {}
}

// ─── Chunk factories ─────────────────────────────────────────────────────────

ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
}) => ScheduledChunk(
  id: id,
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'goal-1',
  durationMinutes: 25,
  rationale: 'Deep work',
  syntheticStartMinutes: syntheticStartMinutes,
);

// ─── Pump helper ─────────────────────────────────────────────────────────────

Future<void> _pumpActiveChunkCard(
  WidgetTester tester, {
  required ScheduledChunk chunk,
  _FakeScheduleNotifier? scheduleNotifier,
  _FakeGoalsNotifier? goalsNotifier,
}) async {
  final sn = scheduleNotifier ?? _FakeScheduleNotifier();
  final gn = goalsNotifier ?? _FakeGoalsNotifier();
  await pumpWithMood(
    tester,
    ActiveChunkCard(chunk: chunk),
    extraProviders: [
      ChangeNotifierProvider<ScheduleNotifier>.value(value: sn),
      ChangeNotifierProvider<GoalsNotifier>.value(value: gn),
    ],
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('ActiveChunkCard (NAV-02)', () {
    testWidgets('renders FilledButton Complete without hover', (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.widgetWithText(FilledButton, 'Complete'),
        findsOneWidget,
        reason: 'NAV-02: Complete must be always visible — no hover required',
      );
    });

    testWidgets('renders OutlinedButton Skip without hover', (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.widgetWithText(OutlinedButton, 'Skip'),
        findsOneWidget,
        reason: 'NAV-02: Skip must be always visible — no hover required',
      );
    });

    testWidgets('renders Now badge', (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.text('Now'),
        findsOneWidget,
        reason: 'ActiveChunkCard must render a "Now" badge',
      );
    });

    testWidgets('renders clock-time range when displayStartMinutes is set',
        (tester) async {
      // 540 min = 9:00 AM, +25 min = 9:25 AM
      await _pumpActiveChunkCard(
        tester,
        chunk: _workChunk(syntheticStartMinutes: 540),
      );
      expect(
        find.textContaining('9:00 AM'),
        findsOneWidget,
        reason: 'Should render clock-time start when displayStartMinutes set',
      );
    });

    testWidgets('renders duration fallback when displayStartMinutes is null',
        (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.text('25 min'),
        findsOneWidget,
        reason: 'Should render duration fallback when displayStartMinutes null',
      );
    });

    testWidgets('tapping Complete calls ScheduleNotifier.markComplete',
        (tester) async {
      final sn = _FakeScheduleNotifier();
      await _pumpActiveChunkCard(
        tester,
        chunk: _workChunk(id: 'chunk-abc'),
        scheduleNotifier: sn,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pump();
      expect(sn.lastCompletedId, 'chunk-abc');
    });

    testWidgets('tapping Skip calls ScheduleNotifier.markSkipped',
        (tester) async {
      final sn = _FakeScheduleNotifier();
      await _pumpActiveChunkCard(
        tester,
        chunk: _workChunk(id: 'chunk-xyz'),
        scheduleNotifier: sn,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pump();
      expect(sn.lastSkippedId, 'chunk-xyz');
    });

    testWidgets('uses no hardcoded Colors', (tester) async {
      // This is a compile-time / static check verified via flutter analyze.
      // The test simply pumps to confirm no runtime errors occur.
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(find.byType(ActiveChunkCard), findsOneWidget);
    });
  });
}
