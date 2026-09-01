// Widget tests for the GoalsScreen as ONE ranked list.
//
// Phase 33 Plan 03 — OBVIOUS-02, UI-SPEC items 10-17 and the text policy
// (items 28-30). The screen used to render three type-filtered sections under
// three headers; it now renders a single ReorderableListView ordered by
// priorityWeight descending across every type, with a rank number per card and
// the goal type demoted to a chip.
//
// Two of these tests are proven able to fail by mutation, not assumed:
//   * the "no legend" test (item 15) — the one spec item with no grep of its
//     own, so it is asserted structurally here;
//   * the refresh-listener test — proven RED by removing the addListener call,
//     so the ProviderNotFoundException guard in goals_screen.dart cannot
//     quietly become the only path.

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_completion_log_repository.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/goals/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
import '../test_helpers/viewport.dart';

// ---------------------------------------------------------------------------
// In-memory repositories — no Hive I/O.
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

class _InMemoryScheduleRepository implements DailyScheduleRepository {
  DailySchedule? _stored;

  @override
  Future<List<DailySchedule>> getAll() async =>
      _stored == null ? [] : [_stored!];

  @override
  Future<DailySchedule?> getById(String id) async =>
      _stored?.id == id ? _stored : null;

  @override
  Future<void> save(DailySchedule schedule) async => _stored = schedule;

  @override
  Future<void> delete(String id) async {
    if (_stored?.id == id) _stored = null;
  }

  @override
  Future<DailySchedule?> getByDate(String dateYmd) async =>
      _stored?.dateYmd == dateYmd ? _stored : null;

  @override
  Future<DailySchedule?> getTodaysSchedule() async => _stored;
}

/// A real [ScheduleNotifier] with every repository injected, so constructing it
/// touches no Hive box — `init()` is never called. [fire] stands in for the
/// notification a completed chunk sends.
class _FakeSchedule extends ScheduleNotifier {
  _FakeSchedule({required InMemoryCompletionLogRepository logRepo})
    : super(
        repo: _InMemoryScheduleRepository(),
        logRepo: logRepo,
        goalRepo: _InMemoryGoalRepository(),
      );

  void fire() => notifyListeners();
}

const _fillKey = ValueKey('goal-progress-fill');

// The owner's bands (UI-SPEC item 14), file-private in goal_card.dart.
const _bandColours = [Color(0xFFE53935), Color(0xFFFFB300), Color(0xFF43A047)];

Goal _goal(
  String id,
  String name, {
  required GoalType type,
  required double priorityWeight,
  required int sortOrder,
  double? weeklyHourBudget,
}) => Goal(
  id: id,
  name: name,
  goalTypeIndex: type.index,
  color: '#4CAF50',
  priorityWeight: priorityWeight,
  sortOrder: sortOrder,
  weeklyHourBudget: weeklyHourBudget,
);

/// Six goals spanning all three types with distinct priority weights.
/// Names are deliberately free of the words a legend would use.
///
/// **`sortOrder` is deliberately the REVERSE of the priority order.** In the
/// running app the two agree, because `reorderAllWithPriority` writes
/// `sortOrder = i` and a descending `priorityWeight` in the same loop — and
/// `GoalsNotifier.loadGoals` sorts by `sortOrder`. A fixture where they agree
/// would therefore render in the right order even with the screen's sort
/// deleted, i.e. the ordering assertion could not fail. Scrambling them is what
/// makes it prove that the list keys on `priorityWeight`.
List<Goal> _sixGoals() => [
  _goal(
    'g1',
    'Alpha',
    type: GoalType.timeTarget,
    priorityWeight: 0.75,
    sortOrder: 5,
    weeklyHourBudget: 4.0,
  ),
  _goal(
    'g2',
    'Bravo',
    type: GoalType.outcome,
    priorityWeight: 0.65,
    sortOrder: 4,
  ),
  _goal(
    'g3',
    'Charlie',
    type: GoalType.habit,
    priorityWeight: 0.55,
    sortOrder: 3,
  ),
  _goal(
    'g4',
    'Delta',
    type: GoalType.timeTarget,
    priorityWeight: 0.45,
    sortOrder: 2,
    weeklyHourBudget: 2.0,
  ),
  _goal(
    'g5',
    'Echo',
    type: GoalType.outcome,
    priorityWeight: 0.35,
    sortOrder: 1,
  ),
  _goal(
    'g6',
    'Foxtrot',
    type: GoalType.habit,
    priorityWeight: 0.25,
    sortOrder: 0,
  ),
];

String _todayYmd() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

CompletionLog _completedToday(String goalId, String chunkId) => CompletionLog(
  chunkId: chunkId,
  goalId: goalId,
  dateYmd: _todayYmd(),
  eventIndex: CompletionEvent.completed.index,
);

/// Pumps the screen with [goals] seeded and waits for the post-frame load.
Future<GoalsNotifier> _pumpScreen(
  WidgetTester tester, {
  required List<Goal> goals,
  required InMemoryCompletionLogRepository logRepo,
  ScheduleNotifier? schedule,
}) async {
  // Tall viewport so all six cards lay out; the list is shrinkWrapped inside a
  // CustomScrollView and a 600dp default would clip the tail.
  setViewport(tester, const Size(800, 2400));

  final repo = _InMemoryGoalRepository();
  for (final g in goals) {
    await repo.save(g);
  }
  final notifier = GoalsNotifier(repository: repo);
  await notifier.loadGoals();

  await pumpWithMood(
    tester,
    GoalsScreen(completionLogRepository: logRepo),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
      if (schedule != null)
        ChangeNotifierProvider<ScheduleNotifier>.value(value: schedule),
    ],
  );

  // Settle the addPostFrameCallback: loadGoals() then _loadWeekProgress().
  await tester.pumpAndSettle();
  return notifier;
}

double _fillHeight(WidgetTester tester, String goalName) {
  final card = find.ancestor(
    of: find.text(goalName),
    matching: find.byType(Card),
  );
  return tester
      .getSize(find.descendant(of: card, matching: find.byKey(_fillKey)))
      .height;
}

void main() {
  group('GoalsScreen renders one ranked list', () {
    testWidgets('exactly one ReorderableListView — the three sections '
        'collapsed to one', (tester) async {
      await _pumpScreen(
        tester,
        goals: _sixGoals(),
        logRepo: InMemoryCompletionLogRepository(),
      );

      // The structural proof. The three retired section headers used the
      // strings 'Regular time', 'Working toward' and 'Daily habits', but those
      // first two are now CHIP LABELS on the cards — so asserting on the text
      // could not distinguish a collapsed list from a sectioned one. The list
      // count can.
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('every rank 1..6 renders', (tester) async {
      await _pumpScreen(
        tester,
        goals: _sixGoals(),
        logRepo: InMemoryCompletionLogRepository(),
      );

      for (var rank = 1; rank <= 6; rank++) {
        expect(
          find.text('$rank'),
          findsOneWidget,
          reason: 'rank $rank must render exactly once',
        );
      }
    });

    testWidgets('card order follows priorityWeight descending, across types', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        goals: _sixGoals(),
        logRepo: InMemoryCompletionLogRepository(),
      );

      // _sixGoals() is listed in descending priority order (though its
      // sortOrder is the reverse — see the fixture note); the rendered
      // y-coordinates must increase in that same order. Types are interleaved
      // on purpose — a surviving type grouping would reorder these.
      const inPriorityOrder = [
        'Alpha',
        'Bravo',
        'Charlie',
        'Delta',
        'Echo',
        'Foxtrot',
      ];
      final ys = [
        for (final name in inPriorityOrder)
          tester.getTopLeft(find.text(name)).dy,
      ];
      for (var i = 1; i < ys.length; i++) {
        expect(
          ys[i],
          greaterThan(ys[i - 1]),
          reason:
              '${inPriorityOrder[i]} (lower priority) must render below '
              '${inPriorityOrder[i - 1]}',
        );
      }
    });

    testWidgets('a freshly quick-added slate — every priorityWeight null — '
        'still ranks in a stable, defined order', (tester) async {
      // quickAddGoals leaves priorityWeight null (-> 0.5) on every goal it
      // creates, so a new user's whole slate is one big tie. Dart's List.sort
      // is not documented as stable, so without the sortOrder tie-break the
      // ranks could reshuffle between rebuilds — which would be a worse
      // legibility defect than the one this screen fixes.
      final tied = [
        for (var i = 0; i < 4; i++)
          Goal(
            id: 'q$i',
            name: 'Tied$i',
            goalTypeIndex: GoalType.timeTarget.index,
            color: '#4CAF50',
            sortOrder: i,
          ),
      ];

      await _pumpScreen(
        tester,
        goals: tied,
        logRepo: InMemoryCompletionLogRepository(),
      );

      final ys = [
        for (var i = 0; i < 4; i++) tester.getTopLeft(find.text('Tied$i')).dy,
      ];
      for (var i = 1; i < ys.length; i++) {
        expect(
          ys[i],
          greaterThan(ys[i - 1]),
          reason: 'ties must fall back to sortOrder, not to sort luck',
        );
      }

      // And the order survives a rebuild rather than reshuffling.
      await tester.pump();
      final again = [
        for (var i = 0; i < 4; i++) tester.getTopLeft(find.text('Tied$i')).dy,
      ];
      expect(again, ys);
    });

    testWidgets('heading is "Priority order" and the quick-add helper text is '
        'gone', (tester) async {
      await _pumpScreen(
        tester,
        goals: _sixGoals(),
        logRepo: InMemoryCompletionLogRepository(),
      );

      expect(find.text('Priority order'), findsOneWidget);
      expect(find.text('Your goals'), findsNothing);
      expect(find.text('Drag to prioritize. Tap to edit.'), findsNothing);
      expect(
        find.text('Enter after each, or paste a list — refine details later'),
        findsNothing,
      );
    });
  });

  group('GoalsScreen has no legend and no key (UI-SPEC item 15)', () {
    testWidgets('no band words, no percentage readout, and no swatches beyond '
        'one per goal', (tester) async {
      await _pumpScreen(
        tester,
        goals: _sixGoals(),
        logRepo: InMemoryCompletionLogRepository(),
      );

      // The absence of a key is a DECISION, not an omission (33-UI-SPEC
      // "Accepted risk"). This test is what stops a future reader "fixing" it.
      for (final word in ['Red', 'Amber', 'Yellow', 'Green', 'Legend', 'Key']) {
        expect(
          find.text(word),
          findsNothing,
          reason:
              'a legend labelled "$word" would explain a scale that the '
              'owner decided needs no explanation',
        );
      }

      // The per-card percentage readout was cut on sight in sketch 004.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('%') ?? false),
        ),
        findsNothing,
        reason: 'no percentage is printed anywhere on this screen',
      );

      // One identity swatch per goal and not one more — an extra row of
      // swatches would be a key by another name. byWidgetPredicate, not
      // byType: byType compares runtimeType exactly (CLAUDE.md trap 1).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNWidgets(6),
      );
    });
  });

  group('GoalsScreen reads real weekly progress', () {
    testWidgets('a goal with completed logs this week renders a banded fill', (
      tester,
    ) async {
      final logRepo = InMemoryCompletionLogRepository();
      // Alpha is a timeTarget with a 4.0 hr/week budget. Two completed chunks
      // = 2 x 25 / 60 = 0.833 hrs -> 0.208 of the budget.
      await logRepo.append(_completedToday('g1', 'c1'));
      await logRepo.append(_completedToday('g1', 'c2'));

      await _pumpScreen(tester, goals: _sixGoals(), logRepo: logRepo);

      final card = find.ancestor(
        of: find.text('Alpha'),
        matching: find.byType(Card),
      );
      final fill = find.descendant(of: card, matching: find.byKey(_fillKey));
      expect(
        fill,
        findsOneWidget,
        reason: 'the screen -> service -> repository wiring must actually run',
      );

      final colour =
          (tester.widget<DecoratedBox>(fill).decoration as BoxDecoration).color;
      expect(colour, isIn(_bandColours));

      // Bravo is an outcome goal: no target in the model, so no fill at all.
      final bravo = find.ancestor(
        of: find.text('Bravo'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: bravo, matching: find.byKey(_fillKey)),
        findsNothing,
      );
    });

    testWidgets('the fill grows when ScheduleNotifier notifies — the refresh '
        'listener is live, not just guarded', (tester) async {
      final logRepo = InMemoryCompletionLogRepository();
      await logRepo.append(_completedToday('g1', 'c1'));
      await logRepo.append(_completedToday('g1', 'c2'));

      final schedule = _FakeSchedule(logRepo: logRepo);
      addTearDown(schedule.dispose);

      await _pumpScreen(
        tester,
        goals: _sixGoals(),
        logRepo: logRepo,
        schedule: schedule,
      );

      final before = _fillHeight(tester, 'Alpha');
      expect(before, greaterThan(0));

      // Two more chunks completed on Today, then the notification that a
      // completion actually sends.
      await logRepo.append(_completedToday('g1', 'c3'));
      await logRepo.append(_completedToday('g1', 'c4'));
      schedule.fire();
      await tester.pumpAndSettle();

      expect(
        _fillHeight(tester, 'Alpha'),
        greaterThan(before),
        reason:
            'indexedStack keeps this screen mounted across tab switches, so '
            'without the listener the bar would still show the pre-completion '
            'value — CLAUDE.md trap 4 in miniature',
      );
    });
  });
}
