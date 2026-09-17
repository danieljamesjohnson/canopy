// Widget tests for the imported-commitment treatment on the Commitments
// screen — Phase 35 Plan 06 Task 1 (CAL-01/CAL-04, D-35-14, 35-UI-SPEC.md §3).
//
// Two CLAUDE.md-documented traps checked against every assertion below:
//   1. find.byType(X) compares runtimeType exactly and does not match
//      subclasses — used here only where "exactly this widget" is meant.
//      Role assertions ("any glyph", "any calendar icon") use
//      find.byWidgetPredicate/find.byIcon instead.
//   2. The read-only sheet's locked copy is asserted as rendered text
//      (find.text('...')) against the UI-SPEC's own string, never against a
//      constant the screen itself derives the string from.
//
// Every "both kinds in one screen" test pumps an imported AND a hand-entered
// row together and asserts each row separately by locating its own Card
// ancestor — a test with only imported rows could not catch a gate that
// accidentally suppresses affordances for every row (acceptance criteria).

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/commitments/commitments_screen.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// In-memory CommitmentBlockRepository — a throwaway double local to this
// file, mirroring test/services/calendar_sync_service_test.dart's shape.
// ---------------------------------------------------------------------------
class _InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
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

/// CommitmentsScreen reads ScheduleNotifier only to re-anchor today's
/// schedule after an add/edit (`_openAddSheet`'s `onSaved`); init() is
/// no-op'd to avoid Hive I/O, matching
/// test/screens/settings/calendar_settings_screen_test.dart's fake.
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

Future<void> _pumpCommitmentsScreen(
  WidgetTester tester, {
  required List<CommitmentBlock> blocks,
}) async {
  final blockRepo = _InMemoryCommitmentBlockRepository();
  for (final block in blocks) {
    await blockRepo.save(block);
  }
  final commitments = CommitmentsNotifier(repository: blockRepo);
  await commitments.loadBlocks();

  final scheduleNotifier = _FakeScheduleNotifier();
  await scheduleNotifier.init();
  addTearDown(scheduleNotifier.dispose);

  // A real GoRouter — the AppBar action, the empty-state CTA, and the
  // read-only sheet's "Manage calendars" button all call context.push, which
  // requires an ancestor GoRouter (today_screen_test.dart's established
  // pattern). '/settings/calendars' renders a marker Text so navigation can
  // be asserted without a NavigatorObserver.
  final router = GoRouter(
    initialLocation: '/commitments',
    routes: [
      GoRoute(
        path: '/commitments',
        builder: (context, state) => const CommitmentsScreen(),
      ),
      GoRoute(
        path: '/settings/calendars',
        builder: (context, state) => const Text('calendars-screen-marker'),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CommitmentsNotifier>.value(value: commitments),
        ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

/// Runs [body] under [platform], guaranteeing the foundation debug variable
/// is reset via try/finally (goal_card_drag_handle_test.dart's established
/// pattern — debugAssertAllFoundationVarsUnset fires if reset happens in
/// tearDown instead, since that assertion runs BEFORE tearDown callbacks).
Future<void> _underPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

CommitmentBlock _importedStandup() => CommitmentBlock(
  name: 'Team standup',
  daysOfWeek: const [1, 2, 3, 4, 5],
  startMinutes: 540,
  endMinutes: 570,
  isFromCalendar: true,
  externalEventId: 'ics:abc123:standup:',
);

CommitmentBlock _handEnteredGym() => CommitmentBlock(
  name: 'Gym',
  daysOfWeek: const [1, 3, 5],
  startMinutes: 420,
  endMinutes: 480,
);

void main() {
  group('Imported commitment glyph (CAL-01/D-35-11, UI-SPEC §3)', () {
    testWidgets(
      'a row for a block with isFromCalendar: true renders the calendar '
      'glyph and its semantics label; a hand-entered block renders neither',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpCommitmentsScreen(
          tester,
          blocks: [_importedStandup(), _handEnteredGym()],
        );

        // Exactly one glyph in the whole screen — the AppBar action
        // (Icons.calendar_month_outlined) and the empty-state CTA
        // (Icons.calendar_month, not shown here since the list is
        // populated) both use a different icon, so this predicate cannot
        // accidentally match either of them.
        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.calendar_today_outlined,
          ),
          findsOneWidget,
          reason: 'exactly the imported row carries the calendar glyph',
        );
        // The row's InkWell merges its descendants' semantics into one node
        // (label + name + subtitle), so the glyph's own label survives only
        // as a substring of the merged label — RegExp.hasMatch (substring),
        // not the exact-match default bySemanticsLabel(String) applies.
        expect(
          find.bySemanticsLabel(RegExp('Imported from your calendar')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });

  group('Imported rows offer no edit/delete affordance (D-35-14)', () {
    testWidgets(
      'mobile: the imported row has no delete IconButton; the hand-entered '
      'row keeps its delete IconButton unchanged',
      (tester) async {
        await _underPlatform(TargetPlatform.android, () async {
          await _pumpCommitmentsScreen(
            tester,
            blocks: [_importedStandup(), _handEnteredGym()],
          );

          // Exactly one delete IconButton on the whole screen — the
          // hand-entered row's. The imported row offers none.
          expect(
            find.widgetWithIcon(IconButton, Icons.delete_outline),
            findsOneWidget,
          );

          final importedCard = find.ancestor(
            of: find.text('Team standup'),
            matching: find.byType(Card),
          );
          final handEnteredCard = find.ancestor(
            of: find.text('Gym'),
            matching: find.byType(Card),
          );
          expect(
            find.descendant(
              of: importedCard,
              matching: find.byIcon(Icons.delete_outline),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: handEnteredCard,
              matching: find.byIcon(Icons.delete_outline),
            ),
            findsOneWidget,
          );
        });
      },
    );

    testWidgets(
      'desktop: the imported row has no hover edit/delete row; the '
      'hand-entered row keeps both, unchanged',
      (tester) async {
        await _underPlatform(TargetPlatform.macOS, () async {
          await _pumpCommitmentsScreen(
            tester,
            blocks: [_importedStandup(), _handEnteredGym()],
          );

          final importedCard = find.ancestor(
            of: find.text('Team standup'),
            matching: find.byType(Card),
          );
          final handEnteredCard = find.ancestor(
            of: find.text('Gym'),
            matching: find.byType(Card),
          );

          expect(
            find.descendant(
              of: importedCard,
              matching: find.byType(AnimatedOpacity),
            ),
            findsNothing,
            reason: 'imported row renders no hover-reveal mechanism at all',
          );
          expect(
            find.descendant(
              of: handEnteredCard,
              matching: find.byType(AnimatedOpacity),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: handEnteredCard,
              matching: find.widgetWithIcon(IconButton, Icons.edit_outlined),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: handEnteredCard,
              matching: find.widgetWithIcon(IconButton, Icons.delete_outline),
            ),
            findsOneWidget,
          );
        });
      },
    );
  });

  group('Tapping a row (D-35-14)', () {
    testWidgets(
      'tapping the imported row opens the read-only sheet with its locked '
      'body copy, not CommitmentFormSheet',
      (tester) async {
        await _pumpCommitmentsScreen(tester, blocks: [_importedStandup()]);

        await tester.tap(find.text('Team standup'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'This commitment comes from your calendar. To change it, edit '
            'the event in your calendar app — the update appears here after '
            'the next sync.',
          ),
          findsOneWidget,
        );
        expect(find.text('Edit commitment'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Save changes'), findsNothing);
      },
    );

    testWidgets(
      'tapping the hand-entered row opens CommitmentFormSheet, not the '
      'read-only sheet',
      (tester) async {
        await _pumpCommitmentsScreen(tester, blocks: [_handEnteredGym()]);

        await tester.tap(find.text('Gym'));
        await tester.pumpAndSettle();

        expect(find.text('Edit commitment'), findsOneWidget);
        expect(
          find.textContaining('This commitment comes from your calendar'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping "Manage calendars" in the read-only sheet navigates to the '
      'Calendars settings screen',
      (tester) async {
        await _pumpCommitmentsScreen(tester, blocks: [_importedStandup()]);

        await tester.tap(find.text('Team standup'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Manage calendars'));
        await tester.pumpAndSettle();

        expect(find.text('calendars-screen-marker'), findsOneWidget);
      },
    );
  });

  group('Long calendar event titles (UI-SPEC UI Considerations, long-text)', () {
    testWidgets(
      'a 120-character imported name renders on one line with an ellipsis '
      'and produces no overflow error',
      (tester) async {
        const source =
            'Weekly Sync: Product + Engineering + Design + Marketing + Sales '
            '+ Customer Success All-Hands Standing Meeting Every Single Week '
            'Forever And Ever Amen';
        final name120 = source.substring(0, 120);
        expect(name120.length, 120);

        final imported = CommitmentBlock(
          name: name120,
          daysOfWeek: const [1, 2, 3, 4, 5],
          startMinutes: 540,
          endMinutes: 570,
          isFromCalendar: true,
        );
        await _pumpCommitmentsScreen(tester, blocks: [imported]);

        final nameText = tester.widget<Text>(find.text(name120));
        expect(nameText.maxLines, 1);
        expect(nameText.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Empty state and AppBar action (UI-SPEC §3)', () {
    testWidgets(
      'the empty state shows the existing copy plus the "Import from your '
      'calendar" button',
      (tester) async {
        await _pumpCommitmentsScreen(tester, blocks: const []);

        expect(find.text('No commitments yet'), findsOneWidget);
        expect(
          find.text('Add your regular jobs, classes, or appointments'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Import from your calendar'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the AppBar action is present on the empty state',
      (tester) async {
        await _pumpCommitmentsScreen(tester, blocks: const []);
        expect(
          find.widgetWithIcon(IconButton, Icons.calendar_month_outlined),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the AppBar action is present on the populated state',
      (tester) async {
        await _pumpCommitmentsScreen(tester, blocks: [_handEnteredGym()]);
        expect(
          find.widgetWithIcon(IconButton, Icons.calendar_month_outlined),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the empty-state CTA navigates to the Calendars settings screen',
      (tester) async {
        await _pumpCommitmentsScreen(tester, blocks: const []);
        await tester.tap(find.text('Import from your calendar'));
        await tester.pumpAndSettle();
        expect(find.text('calendars-screen-marker'), findsOneWidget);
      },
    );
  });
}
