import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/screens/today/widgets/end_of_day_card.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ScheduledChunk _makeWork({
  bool completed = false,
  bool skipped = false,
  bool deferred = false,
}) {
  final c = ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    durationMinutes: 25,
  );
  c.isCompleted = completed;
  c.isSkipped = skipped;
  c.isDeferred = deferred;
  return c;
}

ScheduledChunk _makeBreak() => ScheduledChunk(
  chunkTypeIndex: ChunkType.shortBreak.index,
  durationMinutes: 5,
);

Widget _pumpCard({
  required List<ScheduledChunk> chunks,
  required VoidCallback onDismiss,
  required VoidCallback onGoToSummary,
}) {
  return MaterialApp(
    home: Scaffold(
      body: EndOfDayCard(
        chunks: chunks,
        onDismiss: onDismiss,
        onGoToSummary: onGoToSummary,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Widget tests
// ---------------------------------------------------------------------------

void main() {
  group('EndOfDayCard widget', () {
    testWidgets('renders title, computed subtitle, and CTA button', (
      tester,
    ) async {
      // 3 work chunks, 2 resolved
      final chunks = [
        _makeWork(completed: true),
        _makeWork(skipped: true),
        _makeWork(),
        _makeBreak(), // break chunks must not count
      ];

      await tester.pumpWidget(
        _pumpCard(chunks: chunks, onDismiss: () {}, onGoToSummary: () {}),
      );

      expect(find.text('How did today go?'), findsOneWidget);
      expect(find.text('2 of 3 chunks done'), findsOneWidget);
      expect(find.text('Close the day'), findsOneWidget);
    });

    testWidgets('close IconButton fires onDismiss', (tester) async {
      bool dismissed = false;
      final chunks = [_makeWork()];

      await tester.pumpWidget(
        _pumpCard(
          chunks: chunks,
          onDismiss: () => dismissed = true,
          onGoToSummary: () {},
        ),
      );

      await tester.tap(find.byTooltip('Dismiss'));
      expect(dismissed, isTrue);
    });

    testWidgets('Close the day button fires onGoToSummary', (tester) async {
      bool navigated = false;
      final chunks = [_makeWork()];

      await tester.pumpWidget(
        _pumpCard(
          chunks: chunks,
          onDismiss: () {},
          onGoToSummary: () => navigated = true,
        ),
      );

      await tester.tap(find.text('Close the day'));
      expect(navigated, isTrue);
    });

    testWidgets('deferred chunk counts as resolved', (tester) async {
      final chunks = [_makeWork(deferred: true), _makeWork()];

      await tester.pumpWidget(
        _pumpCard(chunks: chunks, onDismiss: () {}, onGoToSummary: () {}),
      );

      expect(find.text('1 of 2 chunks done'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Trigger logic unit tests (shouldShowEodCard top-level function)
  // -------------------------------------------------------------------------

  group('shouldShowEodCard trigger logic', () {
    // NOTE: shouldShowEodCard accepts an injectable `now` seam specifically
    // so both branches (hour >= 18, and resolved/total >= 0.5) can be tested
    // deterministically. Every test below calls the function through that
    // seam rather than recomputing its internal arithmetic and asserting
    // against the test's own fixture — a test that never calls the function
    // under test would keep passing even if the function were broken.

    test('returns false when work chunks empty and hour < 18', () {
      // No work chunks — the 50% branch's empty-list guard returns false —
      // and the hour is pinned below 18 so the time branch cannot fire.
      final chunks = [_makeBreak(), _makeBreak()];
      expect(
        shouldShowEodCard(chunks, now: () => DateTime(2026, 1, 1, 10, 0)),
        isFalse,
      );
    });

    test('returns false when <50% resolved and hour < 18', () {
      // 1 of 3 resolved = 33% — below the 50% threshold — with the hour
      // pinned below 18 so the time branch cannot fire either.
      final chunks = [_makeWork(completed: true), _makeWork(), _makeWork()];
      expect(
        shouldShowEodCard(chunks, now: () => DateTime(2026, 1, 1, 10, 0)),
        isFalse,
      );
    });

    test(
      'returns true when ≥50% resolved (ratio branch fires regardless of hour)',
      () {
        // 2 of 3 resolved = 66.7% — above threshold.
        final chunks = [
          _makeWork(completed: true),
          _makeWork(skipped: true),
          _makeWork(),
        ];
        final workChunks = chunks
            .where((c) => c.chunkType == ChunkType.work)
            .toList();
        final resolved = workChunks
            .where((c) => c.isCompleted || c.isSkipped || c.isDeferred)
            .length;
        final ratio = resolved / workChunks.length;
        expect(ratio, greaterThanOrEqualTo(0.5));
        // Because ratio >= 0.5, shouldShowEodCard returns true independent of hour.
        expect(shouldShowEodCard(chunks), isTrue);
      },
    );

    test('returns true when exactly 50% resolved', () {
      // 1 of 2 resolved = 50% — at the boundary (>= 0.5).
      final chunks = [_makeWork(completed: true), _makeWork()];
      expect(shouldShowEodCard(chunks), isTrue);
    });

    test(
      'returns true when hour >= 18, even with a resolved ratio below 50%',
      () {
        // 1 of 3 resolved = 33% — below the 50% threshold — but the hour
        // branch (previously untested for "true") should fire regardless.
        final chunks = [_makeWork(completed: true), _makeWork(), _makeWork()];
        expect(
          shouldShowEodCard(chunks, now: () => DateTime(2026, 1, 1, 19, 0)),
          isTrue,
        );
      },
    );

    test('all chunks deferred counts as 100% resolved → trigger true', () {
      final chunks = [_makeWork(deferred: true), _makeWork(deferred: true)];
      expect(shouldShowEodCard(chunks), isTrue);
    });
  });
}
