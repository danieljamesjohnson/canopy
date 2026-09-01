// Widget tests for the restoratives quick-pick chip grid.
//
// Phase 33 Plan 04 — OBVIOUS-03, UI-SPEC items 22-23 and item 30.
//
// New ground, not a repoint: the restoratives screen had no dedicated screen
// test before this phase. Its coverage was indirect — through the model, the
// schema-8 migration, onboarding and the routing/content-width tests — so the
// nine chips, the add/remove round trip and the glyph-plus-word rule were all
// unasserted until now.
//
// The load-bearing assertions here were mutation-tested rather than assumed
// (CLAUDE.md, "Assertions that cannot fail"):
//   * "appears in the list below" was first written as
//     `find.text('Walk outside') → findsNWidgets(2)`, which passes for the
//     wrong reason — the chip's own label is one of the two. It is scoped to a
//     `Card` descendant here, and re-checked by deleting the row branch from
//     the screen's ListView, which turns it RED.
//   * the remove case was proven RED by making the deselect branch a no-op.

import 'package:canopy/data/models/restorative_item.dart';
import 'package:canopy/data/repositories/in_memory_restorative_item_repository.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/screens/restoratives/restoratives_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
import '../test_helpers/viewport.dart';

/// Pumps the screen over a fresh in-memory repository and returns the notifier
/// so tests can assert on what was actually persisted, not just what rendered.
Future<RestorativesNotifier> _pumpScreen(
  WidgetTester tester, {
  List<RestorativeItem> seed = const [],
}) async {
  final notifier = RestorativesNotifier(
    repository: InMemoryRestorativeItemRepository(),
  );
  for (final item in seed) {
    await notifier.saveItem(item);
  }
  await pumpWithMood(
    tester,
    const RestorativesScreen(),
    extraProviders: [
      ChangeNotifierProvider<RestorativesNotifier>.value(value: notifier),
    ],
  );
  // Settle the initState addPostFrameCallback loadItems call.
  await tester.pumpAndSettle();
  return notifier;
}

Finder _chip(String name) => find.widgetWithText(FilterChip, name);

void main() {
  group('Restoratives quick-pick (OBVIOUS-03, UI-SPEC 22-23)', () {
    testWidgets('all nine common restoratives render as chips on an empty list',
        (tester) async {
      final notifier = await _pumpScreen(tester);

      expect(notifier.items, isEmpty);
      expect(find.byType(FilterChip), findsNWidgets(9));
      for (final (name, _) in kCommonRestoratives) {
        expect(_chip(name), findsOneWidget, reason: 'missing chip: $name');
      }
    });

    testWidgets('one tap persists the restorative WITH the chip\'s emoji',
        (tester) async {
      final notifier = await _pumpScreen(tester);

      await tester.tap(_chip('Walk outside'));
      await tester.pumpAndSettle();

      expect(notifier.items.length, 1);
      expect(notifier.items.single.name, 'Walk outside');
      // saveItem, not quickAddItems: the emoji is the whole reason the chips
      // do not go through the bulk helper.
      expect(notifier.items.single.emojiTag, '🚶');
    });

    testWidgets('after adding, the chip reads selected and the item is listed',
        (tester) async {
      await _pumpScreen(tester);

      await tester.tap(_chip('Walk outside'));
      await tester.pumpAndSettle();

      expect(tester.widget<FilterChip>(_chip('Walk outside')).selected, isTrue);
      // Scoped to the row's Card on purpose. An unscoped
      // find.text('Walk outside') is satisfied by the chip's own label and
      // would pass even if the list below never rendered the item.
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Walk outside'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping an added chip removes it — no confirmation dialog',
        (tester) async {
      final notifier = await _pumpScreen(tester);

      await tester.tap(_chip('Walk outside'));
      await tester.pumpAndSettle();
      expect(notifier.items.length, 1);

      await tester.tap(_chip('Walk outside'));
      await tester.pumpAndSettle();

      expect(notifier.items, isEmpty);
      expect(tester.widget<FilterChip>(_chip('Walk outside')).selected, isFalse);
      // One tap adds, one tap removes (item 22). A confirm would defeat it.
      expect(find.text('Remove restorative?'), findsNothing);
    });

    testWidgets('an already-saved restorative renders selected on first build',
        (tester) async {
      // Seeded lowercase on purpose — this is what a hand-typed entry looks
      // like, and the chip must recognise it as the same thing rather than
      // offering to add a second copy.
      final notifier = await _pumpScreen(
        tester,
        seed: [RestorativeItem(name: 'music', sortOrder: 0)],
      );

      expect(tester.widget<FilterChip>(_chip('Music')).selected, isTrue);
      expect(notifier.items.length, 1);
    });

    testWidgets('the chips render in the empty state too', (tester) async {
      await _pumpScreen(tester);

      // Both together: the grid matters most when there is nothing yet, which
      // is exactly the case the FAB-and-dialog flow made expensive.
      expect(find.byType(FilterChip), findsNWidgets(9));
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('every chip is glyph PLUS word, never a bare glyph (item 30)',
        (tester) async {
      await _pumpScreen(tester);

      for (final (name, emoji) in kCommonRestoratives) {
        expect(find.text(name), findsOneWidget, reason: 'no word for $emoji');
        expect(find.text(emoji), findsOneWidget, reason: 'no glyph for $name');
      }
    });

    testWidgets('nine chips lay out on a phone without overflowing',
        (tester) async {
      // The 800x600 default viewport is wide enough to hide a layout defect
      // the owner would meet first on a phone, and this phase's whole subject
      // is what a screen looks like. An overflow here fails the test.
      setViewport(tester, const Size(390, 844));
      await _pumpScreen(tester);

      expect(find.byType(FilterChip), findsNWidgets(9));
      expect(_chip('Sit in the sun'), findsOneWidget);
    });
  });
}
