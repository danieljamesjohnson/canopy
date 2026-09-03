// Widget tests for the one-off (dated) commitment path in CommitmentFormSheet.
//
// Covers the "a human can enter an actual dated event" flow:
//   1. New commitment defaults to the recurring ("Repeats weekly") mode with
//      day chips visible.
//   2. Tapping "One-off date" swaps day chips for a date picker tile.
//   3. Picking a date and saving yields a CommitmentBlock with date set and
//      empty daysOfWeek.
//   4. Editing a dated block opens in one-off mode pre-selected.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/screens/commitments/commitment_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// In-memory CommitmentBlockRepository — no Hive I/O.
// ---------------------------------------------------------------------------
class _InMemoryCommitmentRepository implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> _store = {};
  CommitmentBlock? lastSaved;

  @override
  Future<List<CommitmentBlock>> getAll() async => _store.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async => _store[id];

  @override
  Future<void> save(CommitmentBlock block) async {
    _store[block.id] = block;
    lastSaved = block;
  }

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

Future<_InMemoryCommitmentRepository> _pumpForm(
  WidgetTester tester, {
  CommitmentBlock? existing,
}) async {
  final repo = _InMemoryCommitmentRepository();
  if (existing != null) repo._store[existing.id] = existing;
  final notifier = CommitmentsNotifier(repository: repo);
  await notifier.loadBlocks();

  final scrollController = ScrollController();
  await pumpWithMood(
    tester,
    SingleChildScrollView(
      child: CommitmentFormSheet(
        scrollController: scrollController,
        block: existing,
      ),
    ),
    extraProviders: [
      ChangeNotifierProvider<CommitmentsNotifier>.value(value: notifier),
    ],
  );
  return repo;
}

void main() {
  testWidgets('new commitment defaults to recurring mode with day chips', (
    tester,
  ) async {
    await _pumpForm(tester);

    // Mode toggle present, day chips shown, no date picker prompt.
    expect(find.text('Repeats weekly'), findsOneWidget);
    expect(find.text('One-off date'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Pick a date'), findsNothing);
  });

  testWidgets('switching to One-off date swaps day chips for a date picker', (
    tester,
  ) async {
    await _pumpForm(tester);

    await tester.tap(find.text('One-off date'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Pick a date'), findsOneWidget);
    expect(find.text('Days'), findsNothing);
  });

  testWidgets('picking a date and saving persists a dated block', (
    tester,
  ) async {
    final repo = await _pumpForm(tester);

    await tester.enterText(find.byType(TextField).first, 'Dentist');
    await tester.pump();

    await tester.tap(find.text('One-off date'));
    await tester.pumpAndSettle();

    // Open the date picker and accept its default (today).
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add commitment'));
    await tester.pumpAndSettle();

    final saved = repo.lastSaved;
    expect(saved, isNotNull);
    expect(saved!.name, 'Dentist');
    expect(saved.date, isNotNull, reason: 'one-off must persist a date');
    expect(
      saved.daysOfWeek,
      isEmpty,
      reason: 'one-off carries no recurring weekdays',
    );
  });

  testWidgets('editing a dated block opens in one-off mode', (tester) async {
    final block = CommitmentBlock(
      name: 'Appt',
      daysOfWeek: const [],
      startMinutes: 540,
      endMinutes: 600,
      date: DateTime(2026, 3, 23),
    );
    await _pumpForm(tester, existing: block);

    // One-off UI is active (date section shown, no day chips).
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Days'), findsNothing);
  });

  testWidgets('a sub-25-minute window blocks save and shows a warning', (
    tester,
  ) async {
    // A 10-minute window (09:00–09:10): too short to materialize a 25-min chunk.
    final block = CommitmentBlock(
      name: 'Quick call',
      daysOfWeek: const [1],
      startMinutes: 9 * 60,
      endMinutes: 9 * 60 + 10,
    );
    await _pumpForm(tester, existing: block);

    expect(
      find.text('End must be at least 25 minutes after start.'),
      findsOneWidget,
    );
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(saveButton.onPressed, isNull, reason: 'save must be disabled');
  });

  testWidgets(
    're-editing a PAST-dated one-off does not crash the date picker',
    (tester) async {
      // A stale appointment: its date is well in the past. Opening the picker
      // must not trip showDatePicker's initialDate >= firstDate assert.
      final past = DateTime(2000, 1, 1);
      final block = CommitmentBlock(
        name: 'Old appt',
        daysOfWeek: const [],
        startMinutes: 540,
        endMinutes: 600,
        date: past,
      );
      await _pumpForm(tester, existing: block);

      // Tap the date tile (renders the formatted past date "Jan 1, 2000").
      await tester.tap(find.text('Jan 1, 2000'));
      await tester.pumpAndSettle();

      // Picker opened without throwing; dismiss it.
      expect(tester.takeException(), isNull);
      expect(find.text('OK'), findsOneWidget);
    },
  );
}
