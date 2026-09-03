// Widget tests for showAdaptiveFormModal — Phase 18 Plan 01 (Wave 0 RED stubs).
//
// Covers RESP-01, RESP-02, RESP-03:
//
//   RESP-01: At >= 720dp width, showAdaptiveFormModal opens a Dialog (not a
//            BottomSheet); at < 720dp it opens a BottomSheet (not a Dialog).
//
//   RESP-02: At 720dp, the goal form dialog shows the type picker, Priority
//            control, and Save/Add button; the drag-handle Container (40x4) is
//            absent inside the Dialog; the Dialog contains a ConstrainedBox
//            with maxWidth == 560.
//
//   RESP-03: The commitment form caller also routes through the same helper —
//            shows a Dialog at 720dp.
//
// These tests FAIL (RED) because lib/widgets/adaptive_form_modal.dart does not
// exist yet. Once Plan 18-02 creates that file they will turn GREEN.
//
// Pattern sources (all carried over verbatim):
//   - _pumpModal helper structure: test/screens/goal_form_priority_test.dart
//   - setViewport: test/test_helpers/viewport.dart (auto-teardown; do NOT add
//     another addTearDown after calling setViewport)
//   - pumpWithMood: test/test_helpers/mood_pump.dart
//   - find.byType(Scrollable).first: goal_form_priority_test.dart line 287 comment
//   - In-memory repo stub: goal_form_priority_test.dart lines 31–53

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/commitments/commitment_form_sheet.dart';
import 'package:canopy/screens/goals/goal_form_sheet.dart';
import 'package:canopy/widgets/adaptive_form_modal.dart'; // does not exist yet — RED
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
import '../test_helpers/viewport.dart';

// ---------------------------------------------------------------------------
// In-memory GoalRepository — no Hive I/O.
// ---------------------------------------------------------------------------
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};

  @override
  Future<List<Goal>> getAll() async => _store.values.toList();

  @override
  Future<Goal?> getById(String id) async => _store[id];

  @override
  Future<void> save(Goal goal) async => _store[goal.id] = goal;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}

// ---------------------------------------------------------------------------
// In-memory CommitmentBlockRepository — no Hive I/O.
// ---------------------------------------------------------------------------
class _InMemoryCommitmentRepository implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> _store = {};

  @override
  Future<List<CommitmentBlock>> getAll() async => _store.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async => _store[id];

  @override
  Future<void> save(CommitmentBlock block) async => _store[block.id] = block;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

// ---------------------------------------------------------------------------
// _pumpAdaptiveModal — goal form variant
//
// Modeled on _pumpModal in goal_form_priority_test.dart lines 102–138.
// Captures a BuildContext via Builder, then calls showAdaptiveFormModal
// WITHOUT awaiting (Future only resolves on dismiss), then pumpAndSettle.
// ---------------------------------------------------------------------------
Future<void> _pumpAdaptiveGoalModal(WidgetTester tester, Size viewport) async {
  setViewport(tester, viewport);

  final repo = _InMemoryGoalRepository();
  final notifier = GoalsNotifier(repository: repo);
  await notifier.loadGoals();

  late BuildContext capturedCtx;
  await pumpWithMood(
    tester,
    Builder(
      builder: (ctx) {
        capturedCtx = ctx;
        return const SizedBox.shrink();
      },
    ),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
    ],
  );

  // Do NOT await — Future only resolves on dismiss.
  showAdaptiveFormModal(
    context: capturedCtx,
    builder: (sc) => GoalFormSheet(scrollController: sc),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// _pumpAdaptiveCommitmentModal — commitment form variant
// ---------------------------------------------------------------------------
Future<void> _pumpAdaptiveCommitmentModal(
  WidgetTester tester,
  Size viewport,
) async {
  setViewport(tester, viewport);

  final repo = _InMemoryCommitmentRepository();
  final notifier = CommitmentsNotifier(repository: repo);
  await notifier.loadBlocks();

  late BuildContext capturedCtx;
  await pumpWithMood(
    tester,
    Builder(
      builder: (ctx) {
        capturedCtx = ctx;
        return const SizedBox.shrink();
      },
    ),
    extraProviders: [
      ChangeNotifierProvider<CommitmentsNotifier>.value(value: notifier),
    ],
  );

  // Do NOT await — Future only resolves on dismiss.
  showAdaptiveFormModal(
    context: capturedCtx,
    builder: (sc) => CommitmentFormSheet(scrollController: sc),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RESP-01 — Dialog vs BottomSheet routing', () {
    testWidgets(
      'at 720dp (>= breakpoint): goal form opens as Dialog, not BottomSheet',
      (tester) async {
        await _pumpAdaptiveGoalModal(tester, const Size(720, 900));

        expect(
          find.byType(Dialog),
          findsOneWidget,
          reason:
              'RESP-01: showAdaptiveFormModal must route to Dialog at >= 720dp',
        );
        expect(
          find.byType(BottomSheet),
          findsNothing,
          reason: 'RESP-01: BottomSheet must not appear at >= 720dp',
        );
      },
    );

    testWidgets(
      'at 719dp (< breakpoint): goal form opens as BottomSheet, not Dialog',
      (tester) async {
        await _pumpAdaptiveGoalModal(tester, const Size(719, 900));

        expect(
          find.byType(BottomSheet),
          findsOneWidget,
          reason:
              'RESP-01: showAdaptiveFormModal must route to BottomSheet at < 720dp',
        );
        expect(
          find.byType(Dialog),
          findsNothing,
          reason: 'RESP-01: Dialog must not appear at < 720dp',
        );
      },
    );
  });

  group('RESP-02 — Dialog content and sizing', () {
    testWidgets(
      'at 720dp: goal form dialog — type picker, Priority, Save present; '
      'drag-handle Container (40×4) absent inside Dialog',
      (tester) async {
        await _pumpAdaptiveGoalModal(tester, const Size(720, 900));

        // RESP-02: type picker visible (GoalTypePicker renders its first card).
        expect(
          find.byType(Dialog),
          findsOneWidget,
          reason: 'RESP-02: Dialog must be shown at 720dp',
        );

        // Priority control visible without requiring scroll (dialog is large
        // enough at 720x900 to show all form content).
        expect(
          find.byType(SegmentedButton<double>),
          findsOneWidget,
          reason: 'RESP-02: Priority SegmentedButton must be visible in dialog',
        );

        // Save/Add button present (ElevatedButton).
        expect(
          find.byType(ElevatedButton),
          findsOneWidget,
          reason: 'RESP-02: Save/Add ElevatedButton must be visible in dialog',
        );

        // Drag-handle Container (40×4) must NOT be present inside the Dialog.
        // The handle is a Container with width=40 and height=4; when isDialog
        // is true (18-02 impl) this widget is removed from the Column.
        final dialogFinder = find.byType(Dialog);
        final handleContainerFinder = find.descendant(
          of: dialogFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints != null &&
                w.constraints!.maxWidth == 40 &&
                w.constraints!.maxHeight == 4,
          ),
        );
        expect(
          handleContainerFinder,
          findsNothing,
          reason:
              'RESP-02: drag-handle Container (40×4) must be absent inside '
              'Dialog when isDialog is true',
        );
      },
    );

    testWidgets(
      'at 720dp: Dialog contains a ConstrainedBox with maxWidth == 560.0',
      (tester) async {
        await _pumpAdaptiveGoalModal(tester, const Size(720, 900));

        // Use find.descendant to locate ConstrainedBox within the Dialog.
        // ALWAYS use find.byType(Scrollable).first for scrollable args —
        // find.byType(SingleChildScrollView) causes a runtime cast failure.
        final constrainedBoxFinder = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(ConstrainedBox),
        );
        expect(
          constrainedBoxFinder,
          findsWidgets,
          reason:
              'RESP-02: at least one ConstrainedBox must exist inside the Dialog',
        );

        final boxes = tester.widgetList<ConstrainedBox>(constrainedBoxFinder);
        expect(
          boxes.any((b) => b.constraints.maxWidth == 560.0),
          isTrue,
          reason:
              'RESP-02: Dialog must contain a ConstrainedBox(maxWidth: 560)',
        );
      },
    );
  });

  group('RESP-03 — Commitment form routes through same helper', () {
    testWidgets(
      'at 720dp: commitment form opens as Dialog via showAdaptiveFormModal',
      (tester) async {
        await _pumpAdaptiveCommitmentModal(tester, const Size(720, 900));

        expect(
          find.byType(Dialog),
          findsOneWidget,
          reason:
              'RESP-03: CommitmentFormSheet must open as Dialog at >= 720dp '
              'when shown via showAdaptiveFormModal',
        );
        expect(
          find.byType(BottomSheet),
          findsNothing,
          reason: 'RESP-03: BottomSheet must not appear at >= 720dp',
        );
      },
    );
  });
}
