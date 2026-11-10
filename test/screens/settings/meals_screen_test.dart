// Phase 37 (D-37-05): Settings → Meals — the same three rows as onboarding,
// for existing users; the Settings row that leads there; and meals kept off
// the Commitments screen. Mutation log: 37-02-SUMMARY.md.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/screens/commitments/commitments_screen.dart';
import 'package:canopy/screens/settings/meals_screen.dart';
import 'package:canopy/screens/settings/settings_screen.dart';
import 'package:canopy/utils/meals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Repo implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> store = {};
  @override
  Future<List<CommitmentBlock>> getAll() async => store.values.toList();
  @override
  Future<CommitmentBlock?> getById(String id) async => store[id];
  @override
  Future<void> save(CommitmentBlock block) async => store[block.id] = block;
  @override
  Future<void> delete(String id) async => store.remove(id);
  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

void main() {
  late _Repo repo;
  late CommitmentsNotifier commitments;

  setUp(() {
    repo = _Repo();
    commitments = CommitmentsNotifier(repository: repo);
  });

  CommitmentBlock lunchAt(int s, int e) => CommitmentBlock(
    id: 'lunch-1',
    name: 'Lunch',
    daysOfWeek: kAllWeekdays,
    startMinutes: s,
    endMinutes: e,
    kind: CommitmentBlock.kindLunch,
  );

  /// Pumps a home screen with a button that pushes MealsScreen, so "Looks
  /// good" has somewhere to pop back to — as it does from Settings.
  Future<void> pumpMeals(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<CommitmentsNotifier>.value(
        value: commitments,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MealsScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, String kind) =>
      tester.widget<Switch>(find.byKey(Key('meal-switch-$kind'))).value;

  testWidgets('with no meals saved: the three defaults, on; one tap saves '
      'them, returns, and says to Re-check-in', (tester) async {
    await pumpMeals(tester);
    expect(switchOn(tester, 'breakfast'), isTrue);
    expect(switchOn(tester, 'lunch'), isTrue);
    expect(switchOn(tester, 'dinner'), isTrue);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(find.text('12:00 PM'), findsOneWidget);
    expect(find.text('6:00 PM'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Looks good'));
    await tester.pumpAndSettle();

    expect(find.byType(MealsScreen), findsNothing);
    expect(
      find.text('Meals saved. Tap ⟳ Re-check-in to see them on today.'),
      findsOneWidget,
    );
    expect(repo.store.values.map((b) => b.kind).toSet(), {
      'breakfast',
      'lunch',
      'dinner',
    });
  });

  testWidgets('with lunch saved at 12:30-1:15: lunch shows those times, the '
      'others show off, and Looks good leaves exactly lunch', (tester) async {
    await repo.save(lunchAt(750, 795));
    await commitments.loadBlocks();
    await pumpMeals(tester);

    expect(switchOn(tester, 'breakfast'), isFalse);
    expect(switchOn(tester, 'lunch'), isTrue);
    expect(switchOn(tester, 'dinner'), isFalse);
    expect(find.text('12:30 PM'), findsOneWidget);
    expect(find.text('1:15 PM'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Looks good'));
    await tester.pumpAndSettle();
    expect(repo.store.values.single.id, 'lunch-1');
    expect(repo.store.values.single.startMinutes, 750);
  });

  testWidgets('switching lunch off there deletes it', (tester) async {
    await repo.save(lunchAt(720, 780));
    await commitments.loadBlocks();
    await pumpMeals(tester);
    await tester.tap(find.byKey(const Key('meal-switch-lunch')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Looks good'));
    await tester.pumpAndSettle();
    expect(repo.store, isEmpty);
  });

  group('the Settings row', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsNotifier>.value(
              value: SettingsNotifier(
                repository: InMemoryAppSettingsRepository(),
              ),
            ),
            ChangeNotifierProvider<CommitmentsNotifier>.value(
              value: commitments,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('invites setup when there are no meals', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Set breakfast, lunch and dinner'), findsOneWidget);
    });

    testWidgets('lists the saved meals by start time', (tester) async {
      await commitments.saveMeals(MealDraft.defaults());
      await pumpSettings(tester);
      expect(
        find.text('Breakfast 7:00a · Lunch 12:00p · Dinner 6:00p'),
        findsOneWidget,
      );
    });
  });

  testWidgets('meals do not appear on the Commitments screen', (tester) async {
    await repo.save(
      CommitmentBlock(
        name: 'Gym',
        daysOfWeek: const [1, 3, 5],
        startMinutes: 420,
        endMinutes: 480,
      ),
    );
    await commitments.saveMeals(MealDraft.defaults());
    final schedule = _FakeScheduleNotifier();
    addTearDown(schedule.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommitmentsNotifier>.value(value: commitments),
          ChangeNotifierProvider<ScheduleNotifier>.value(value: schedule),
        ],
        child: const MaterialApp(home: CommitmentsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Breakfast'), findsNothing);
  });
}
