// Widget tests for ChunkCard always-visible action buttons — Phase 12 Plan 02.
//
// SCHED-03: Replaces the old hover-overlay pattern (AnimatedOpacity) with
// always-visible FilledButton.icon "Complete" + OutlinedButton.icon "Skip"
// buttons that require no hover gesture.
//
// This file replaces the Phase 6 hover-reveal tests which asserted
// AnimatedOpacity.opacity 0→1 on mouse enter/exit. Those tests are invalid
// after Phase 12 removes the hover overlay entirely.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

ScheduledChunk _unresolvedChunk() => ScheduledChunk(
  id: 'c1',
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'g1',
  durationMinutes: 45,
  rationale: 'Deep work',
);

ScheduledChunk _completedChunk() {
  final c = ScheduledChunk(
    id: 'c2',
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'g1',
    durationMinutes: 45,
    rationale: 'Deep work',
  );
  c.isCompleted = true;
  return c;
}

ScheduledChunk _skippedChunk() {
  final c = ScheduledChunk(
    id: 'c3',
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'g1',
    durationMinutes: 45,
    rationale: 'Deep work',
  );
  c.isSkipped = true;
  return c;
}

/// Fake ScheduleNotifier — stubs markComplete / markSkipped to avoid Hive.
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

void main() {
  group('ChunkCard always-visible action buttons (SCHED-03)', () {
    testWidgets('unresolved chunk shows FilledButton "Complete" without hover', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _unresolvedChunk()),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );
      // No hover gesture — buttons must be visible immediately.
      expect(
        find.widgetWithText(FilledButton, 'Complete'),
        findsOneWidget,
        reason:
            'SCHED-03: FilledButton "Complete" must be always visible on unresolved chunk',
      );
    });

    testWidgets('unresolved chunk shows OutlinedButton "Skip" without hover', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _unresolvedChunk()),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Skip'),
        findsOneWidget,
        reason:
            'SCHED-03: OutlinedButton "Skip" must be always visible on unresolved chunk',
      );
    });

    testWidgets('completed chunk shows no FilledButton or OutlinedButton', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _completedChunk()),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason:
            'SCHED-03: Resolved (completed) chunk must show no action buttons',
      );
      expect(
        find.byType(OutlinedButton),
        findsNothing,
        reason:
            'SCHED-03: Resolved (completed) chunk must show no action buttons',
      );
    });

    testWidgets('skipped chunk shows no FilledButton or OutlinedButton', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _skippedChunk()),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason:
            'SCHED-03: Resolved (skipped) chunk must show no action buttons',
      );
      expect(
        find.byType(OutlinedButton),
        findsNothing,
        reason:
            'SCHED-03: Resolved (skipped) chunk must show no action buttons',
      );
    });

    testWidgets('tapping Complete calls ScheduleNotifier.markComplete', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _unresolvedChunk()),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pump();
      expect(notifier.lastCompletedId, 'c1');
    });

    testWidgets('tapping Skip calls ScheduleNotifier.markSkipped', (
      tester,
    ) async {
      final notifier = _FakeScheduleNotifier();
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _unresolvedChunk()),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
        ],
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pump();
      expect(notifier.lastSkippedId, 'c1');
    });

    testWidgets(
      'no AnimatedOpacity hover overlay in tree for unresolved chunk',
      (tester) async {
        final notifier = _FakeScheduleNotifier();
        await pumpWithMood(
          tester,
          ChunkCard(chunk: _unresolvedChunk()),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
          ],
        );
        // AnimatedOpacity was the old hover reveal — must be gone entirely.
        expect(
          find.byType(AnimatedOpacity),
          findsNothing,
          reason: 'SCHED-03: Hover overlay (AnimatedOpacity) must be removed',
        );
      },
    );
  });
}
