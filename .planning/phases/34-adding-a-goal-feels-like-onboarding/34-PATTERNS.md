# Phase 34: Adding a Goal Feels Like Onboarding - Pattern Map

**Mapped:** 2026-09-08
**Files analyzed:** 9 (3 new, 6 modified)
**Analogs found:** 9 / 9

**Framing, restated because it governs every row below:** this phase is EXTRACT-AND-REUSE, not
invention. The hard constraint from CONTEXT.md is that a third private copy of the preset-chip idea
is the wrong answer. The two implementations being merged (`_ChipCloud` and `_QuickPickSection`) are
therefore reproduced here in full, side by side, so the planner does not need to re-open either
source file to see what the shared widget must absorb.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/widgets/preset_chip_grid.dart` (NEW — shared chip widget) | component | CRUD (create/toggle) | `lib/screens/restoratives/restoratives_screen.dart` `_QuickPickSection` (`:262-330`) | exact (this IS the shape being generalized) |
| `lib/screens/goals/widgets/goal_preset_picker_sheet.dart` (NEW — `GoalPresetPickerSheet`, `kCommonGoals`) | component (bottom-sheet/dialog content) | request-response (opens via `showAdaptiveFormModal`) | `lib/screens/goals/goal_form_sheet.dart` (sibling sheet, same modal contract) + `lib/screens/goals/widgets/add_kind_fork.dart` `_DoorTile` (for "Add your own" row) | role-match, composite |
| `lib/screens/goals/goals_screen.dart` (`_openAddSheet`, modified) | screen / controller | request-response | itself, `_openAddSheet` (`:127-143`) — one call site changes | exact (editing in place) |
| `lib/providers/goals_notifier.dart` (`quickAddGoals` or sibling, modified) | provider (service-like) | CRUD | itself, `quickAddGoals` (`:70-105`) | exact (editing in place) |
| `lib/screens/onboarding/onboarding_screen.dart` (`_ChipCloud` usages, `_goalPresets`, modified) | component | CRUD | itself — `_ChipCloud` (`:644-681`), `_goalPresets`/`_restorativePresets` (`:138-158`), `_GoalsBeat` (`:164-201`) | exact (editing in place) |
| `test/screens/goal_preset_picker_sheet_test.dart` (NEW) | test | request-response / CRUD | `test/screens/restoratives_quick_pick_test.dart` (full file, chip-tap idiom) | exact |
| `test/screens/goals_add_fork_test.dart` (modified, lines ~163-172, ~260-278) | test | request-response | itself | exact (editing in place) |
| `test/screens/onboarding_flow_test.dart` (modified, lines ~163-178, ~440-478) | test | CRUD | itself; chip finder idiom from `restoratives_quick_pick_test.dart:55` | exact |
| `test/providers/goals_notifier_test.dart` (NEW or extended — confirm existence at plan time; not found under `test/` in this pass) | test | CRUD (unit) | pattern: plain `flutter_test` unit test constructing `GoalsNotifier(repository: _InMemoryGoalRepository())` and asserting on `.goals` after calling the notifier method directly (no widget pump needed) — model this on the `_InMemoryGoalRepository` fake already in `goals_add_fork_test.dart:37-55` | role-match |

## Pattern Assignments

### `lib/widgets/preset_chip_grid.dart` (NEW shared widget)

**This is the highest-value extraction in the phase — both source implementations in full, so the
merge is mechanical rather than re-derived.**

**Analog A — `_QuickPickSection`** (`lib/screens/restoratives/restoratives_screen.dart:262-330`) —
**this is the shape that WINS per UI-SPEC Decision 3, Axis A:**

```dart
const List<(String name, String emoji)> kCommonRestoratives = [
  ('Walk outside', '🚶'),
  ('Music', '🎵'),
  // ... 9 entries total
];

class _QuickPickSection extends StatelessWidget {
  const _QuickPickSection({required this.notifier});
  final RestorativesNotifier notifier;

  /// Case-insensitive, trimmed match — the idiom to reuse verbatim.
  RestorativeItem? _matchFor(String name) {
    final needle = name.trim().toLowerCase();
    return notifier.items
        .where((i) => i.name.trim().toLowerCase() == needle)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Common', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, emoji) in kCommonRestoratives)
                _buildChip(name, emoji),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String name, String emoji) {
    final match = _matchFor(name);
    return FilterChip(
      avatar: Text(emoji),
      label: Text(name),
      selected: match != null,
      onSelected: (selected) {
        if (selected) {
          notifier.saveItem(
            RestorativeItem(name: name, emojiTag: emoji, sortOrder: notifier.items.length),
          );
        } else if (match != null) {
          notifier.deleteItem(match.id);   // toggle mode: no confirmation
        }
      },
    );
  }
}
```

**Analog B — `_ChipCloud`** (`lib/screens/onboarding/onboarding_screen.dart:644-681`) — **the shape
being REPLACED, kept here only so the planner knows exactly what call sites must change and why:**

```dart
class _Entry {
  const _Entry(this.id, this.name, this.emoji);
  final String id;
  final String name;
  final String? emoji;
}

List<String> _suggestionsFor(List<String> presets, List<_Entry> added) {
  final have = {for (final e in added) e.name.toLowerCase()};
  return [for (final p in presets) if (!have.contains(p.toLowerCase())) p];
}

class _ChipCloud extends StatelessWidget {
  const _ChipCloud({required this.added, required this.suggestions, required this.onAdd, required this.onRemove});
  final List<_Entry> added;
  final List<String> suggestions;
  final void Function(String name) onAdd;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in added)
          InputChip(
            avatar: e.emoji != null ? Text(e.emoji!) : null,
            label: Text(e.name),
            backgroundColor: colorScheme.secondaryContainer,
            onDeleted: () => onRemove(e.id),
          ),
        for (final s in suggestions)
          ActionChip(avatar: const Icon(Icons.add, size: 18), label: Text(s), onPressed: () => onAdd(s)),
      ],
    );
  }
}
```

Call site to change, `_GoalsBeat` (`onboarding_screen.dart:164-201`):
```dart
class _GoalsBeatState extends State<_GoalsBeat> {
  @override
  Widget build(BuildContext context) {
    return _ScreenLayout(
      child: Consumer<GoalsNotifier>(
        builder: (context, goals, _) {
          final added = [for (final g in goals.goals) _Entry(g.id, g.name, g.emojiTag)];
          final goalsNotifier = context.read<GoalsNotifier>();
          return Column(
            children: [
              const _BeatTitle('What are your goals?'),
              const SizedBox(height: 16),
              _ChipCloud(
                added: added,
                suggestions: _suggestionsFor(_goalPresets, added),
                onAdd: (name) => goalsNotifier.quickAddGoals([name]),
                // ...
```
`_goalPresets` today (`onboarding_screen.dart:138-147`) is a bare `List<String>` — this is the list
CONTEXT.md requires converting to `(name, emoji)` pairs (i.e. becomes/aliases `kCommonGoals`).

**Merge instructions (from UI-SPEC Decision 3, restated as an implementation checklist):**
1. One `Wrap(spacing: 8, runSpacing: 8)` of `FilterChip`s only — no `InputChip`/`ActionChip` split.
2. Avatar is always `Text(emoji)` — no generic `Icons.add` avatar.
3. Add a `mode` parameter (e.g. an enum `ChipGridMode { createOnly, toggle }`):
   - `toggle` (restoratives, unchanged): `selected: match != null`, `onSelected` creates when
     unselected, calls a delete callback when selected — this is `_QuickPickSection` verbatim.
   - `createOnly` (goals + onboarding, both beats): once matched, the chip is **omitted from the
     grid entirely** (filter it out before building the `Wrap`, same idea as `_suggestionsFor` but
     applied to hide rather than to separate into two chip families) — never rendered
     selected/disabled, no tap can remove.
4. The "already claimed" check in both modes is the same one-line idiom — reuse `_matchFor`'s body
   (trim + lowercase + `.where(...).firstOrNull`) generalized over `Iterable<String> existingNames`
   so it doesn't couple to `RestorativeItem` or `Goal` specifically. Caller passes in
   `notifier.items.map((i) => i.name)` or `notifier.goals.map((g) => g.name)`.
5. `kCommonGoals` mirrors `kCommonRestoratives`'s exact shape: `const List<(String name, String
   emoji)>`, 8 entries, doc comment stating it is deliberately hard-coded (copy
   `restoratives_screen.dart:9-17`'s comment almost verbatim — it already states the CLAUDE.md "dumb
   app" rationale this list needs too).

### `lib/screens/goals/widgets/goal_preset_picker_sheet.dart` (NEW)

**Analog for the sheet shell/chrome:** `lib/widgets/adaptive_form_modal.dart` (full file, reproduced
below) — no changes needed to this file, `GoalPresetPickerSheet` just needs to be a
`Widget Function(ScrollController)` like `GoalFormSheet` already is:

```dart
Future<void> showAdaptiveFormModal({
  required BuildContext context,
  required Widget Function(ScrollController scrollController) builder,
}) async {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= 720;
  if (isDesktop) {
    final screenHeight = MediaQuery.of(context).size.height;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: _DialogForm(builder: builder, maxHeight: screenHeight * 0.8),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 1.0],
        builder: (ctx, scrollController) => builder(scrollController),
      ),
    );
  }
}
```

**Analog for "Add your own" row (a tappable Card/InkWell row, not a field):**
`_DoorTile` — `lib/screens/goals/widgets/add_kind_fork.dart:204-262`:

```dart
class _DoorTile extends StatelessWidget {
  const _DoorTile({required this.icon, required this.title, required this.consequence, required this.onTap});
  final IconData icon;
  final String title;
  final String consequence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(consequence, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```
"Add your own" should copy this row shape (icon + label, `InkWell`, `Card`), NOT a `TextFormField` —
per UI-SPEC Decision 2, the whole point is that this control must not be a field wearing a new
location.

**Analog for "the created row shows its budget" (no new widget — reuse `GoalCard` as-is):**
`lib/screens/goals/widgets/goal_card.dart:176-191` (`_secondaryLine`, verified still true):

```dart
String? _secondaryLine(Goal g) {
  switch (g.goalType) {
    case GoalType.timeTarget:
      if (g.weeklyHourBudget != null) {
        return '${g.weeklyHourBudget!.toStringAsFixed(1)} hrs/week';
      }
      return null;
    case GoalType.habit:
      if (g.streakCount > 0) return '${g.streakCount}-day streak';
      return null;
    case GoalType.outcome:
      return null;
  }
}
```
Rendered at `goal_card.dart:308-329` — emoji-then-name title row, then (if non-null) the secondary
line at `bodySmall` 4dp below:
```dart
Row(children: [
  if (goal.emojiTag != null) ...[
    Text(goal.emojiTag!, style: const TextStyle(fontSize: 16)),
    const SizedBox(width: 4),
  ],
  Expanded(child: Text(goal.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
]),
if (secondary != null) ...[
  const SizedBox(height: 4),
  Text(secondary, style: theme.textTheme.bodySmall),
],
```
**No changes needed to `goal_card.dart`.** The "Just added" list in the new sheet should render
`GoalCard` instances directly for each goal created this visit — this is why no new summary widget
is warranted.

### `lib/screens/goals/goals_screen.dart` — `_openAddSheet` (the one call site to change)

**Current code, `goals_screen.dart:127-143`:**
```dart
Future<void> _openAddSheet(BuildContext context) async {
  final kind = await showAddKindFork(context);
  if (kind == null || !context.mounted) return;
  if (kind == AddKind.restorative) {
    await showRestorativeQuickAdd(context);
    return;
  }
  if (!context.mounted) return;
  final isDesktop = MediaQuery.of(context).size.width >= 720;
  await showAdaptiveFormModal(
    context: context,
    builder: (scrollController) => GoalFormSheet(
      scrollController: scrollController,
      isDialog: isDesktop,
    ),
  );
}
```
**Change:** in the `kind == AddKind.goal` tail, replace the `GoalFormSheet` builder with
`GoalPresetPickerSheet` — same `showAdaptiveFormModal` call, same `isDesktop` computation, only the
`builder` differs. `GoalFormSheet` becomes reachable only from inside the new sheet.

**Unchanged, reused as-is** — `_openEditSheet` (`goals_screen.dart:147-157`), the exact call the new
sheet's "tap a Just Added row" and "Add your own" gestures should invoke:
```dart
void _openEditSheet(BuildContext context, Goal goal) {
  final isDesktop = MediaQuery.of(context).size.width >= 720;
  showAdaptiveFormModal(
    context: context,
    builder: (scrollController) => GoalFormSheet(
      scrollController: scrollController,
      goal: goal,
      isDialog: isDesktop,
    ),
  );
}
```

### `lib/providers/goals_notifier.dart` — `quickAddGoals` (the emoji-plumbing gap)

**Current code, `goals_notifier.dart:70-105`, error-handling pattern included:**
```dart
Future<int> quickAddGoals(Iterable<String> names) async {
  final cleaned = names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
  if (cleaned.isEmpty) return 0;

  final startCount = _goals.length;
  var nextSort = _goals.isEmpty
      ? 0
      : _goals.map((g) => g.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

  var saved = 0;
  for (var i = 0; i < cleaned.length; i++) {
    final goal = Goal(
      name: cleaned[i],
      goalTypeIndex: GoalType.timeTarget.index,
      color: _colorPalette[(startCount + i) % _colorPalette.length],
      weeklyHourBudget: 3.0,
      sortOrder: nextSort++,
    );
    try {
      await _repository.save(goal);
      saved++;
    } catch (_) {
      break;                 // honest partial count, no throw — copy this exactly
    }
  }
  await loadGoals();
  return saved;
}
```
**Error-handling pattern to copy for any new/widened method:** try/catch around the single
`_repository.save(goal)` call, `break` (not `rethrow`) on failure, return the count that actually
landed. This is the shape the UI-SPEC's error-row requirement (restore the chip, show the existing
`goal_form_sheet.dart:113` SnackBar copy) must compose with — the notifier reports honestly, the
widget decides what to do with a `saved == 0` result for a single-name call.

**Emoji gap, confirmed:** `Goal`'s constructor above never passes `emojiTag` — every goal this method
creates today has `emojiTag == null`. Widening the signature (Assumption A1 in RESEARCH.md — either
change `Iterable<String> names` to `Iterable<(String name, String? emoji)>`, or add a sibling method)
is Claude's discretion per CONTEXT.md; grep `quickAddGoals(` across `lib/` at plan time before
choosing (RESEARCH.md found exactly one existing call site: `_GoalsBeat.onAdd` at
`onboarding_screen.dart:199`).

### Test analogs

**Closest model for the new `goal_preset_picker_sheet_test.dart` (or similarly named) file:**
`test/screens/restoratives_quick_pick_test.dart` — full pump/find idiom, reproduced:

```dart
Future<RestorativesNotifier> _pumpScreen(WidgetTester tester, {List<RestorativeItem> seed = const []}) async {
  final notifier = RestorativesNotifier(repository: InMemoryRestorativeItemRepository());
  for (final item in seed) {
    await notifier.saveItem(item);
  }
  await pumpWithMood(
    tester,
    const RestorativesScreen(),
    extraProviders: [ChangeNotifierProvider<RestorativesNotifier>.value(value: notifier)],
  );
  await tester.pumpAndSettle();   // settle the initState addPostFrameCallback load
  return notifier;
}

Finder _chip(String name) => find.widgetWithText(FilterChip, name);

testWidgets('one tap persists the restorative WITH the chip\'s emoji', (tester) async {
  final notifier = await _pumpScreen(tester);
  await tester.tap(_chip('Walk outside'));
  await tester.pumpAndSettle();
  expect(notifier.items.length, 1);
  expect(notifier.items.single.name, 'Walk outside');
  expect(notifier.items.single.emojiTag, '🚶');
});
```

Directly reusable idioms for the new file:
- `Finder _chip(String name) => find.widgetWithText(FilterChip, name)` — **do not** use bare
  `find.byType(FilterChip)` once the shared widget ships onto three screens (RESEARCH.md Pitfall 3;
  `onboarding_screen.dart:522-539` already has an unrelated `FilterChip` row that a bare type-finder
  would over-count).
- Scope "does it render in the list/receipt too" checks to a `Card`/`GoalCard` descendant, not a bare
  `find.text(name)` (`restoratives_quick_pick_test.dart:99-108` comment states exactly why — the
  chip's own label satisfies an unscoped finder).
- **For the double-tap race (UI-SPEC Decision 4), do NOT copy `pumpAndSettle` here** — every existing
  test in this codebase defaults to `pumpAndSettle`, which cannot observe a single-frame race. Use
  `await tester.tap(...)` then `await tester.pump()` (one frame only) before asserting the chip is
  already gone.

**In-memory repository fake to reuse directly (no new fake needed):**
`test/screens/goals_add_fork_test.dart:37-55`:
```dart
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
  Future<List<Goal>> getActive() async => _store.values.where((g) => !g.isArchived).toList();
}
```

**Exact breakage to repoint in `test/screens/goals_add_fork_test.dart`** (lines verified this
session):
```dart
// :163-172 — WILL FAIL, goal door now opens GoalPresetPickerSheet first:
testWidgets('the goal door opens the goal form', (tester) async {
  await _pumpGoals(tester);
  await _tapAdd(tester);
  await tester.tap(find.text(_goalDoor));
  await tester.pumpAndSettle();
  expect(find.byType(GoalFormSheet), findsOneWidget);   // <- repoint to GoalPresetPickerSheet,
  expect(find.text(_goalDoor), findsNothing);           //    or tap "Add your own" first
});
```
Line 260-278 has the identical shape (asserts `GoalFormSheet` immediately after tapping the goal
door) and needs the same repoint.

**Not affected** (verified, so the planner doesn't waste time): the fork-shows-both-doors test
(`:147-161`, still asserts `GoalFormSheet` absence — still true, now takes an extra step to reach
it), the restorative-door test (`:174-218`, untouched surface), the cancel-fork test (`:220-233`),
and `_openEditSheet` coverage (`:235-258`, untouched call).

## Shared Patterns

### Case-insensitive "is this preset already claimed" matching
**Source:** `_matchFor` in `restoratives_screen.dart:271-276` and `_suggestionsFor` in
`onboarding_screen.dart:631-639` — two independent implementations of the same one-line rule, already
in agreement.
**Apply to:** the shared chip widget's internal matching logic (generalized to `Iterable<String>`
rather than a concrete model type), used identically by Goals, onboarding's goals beat, and
onboarding's restoratives beat.
```dart
final needle = name.trim().toLowerCase();
return items.where((i) => i.name.trim().toLowerCase() == needle).firstOrNull;
```

### Responsive modal chrome (bottom sheet on mobile, dialog on desktop)
**Source:** `showAdaptiveFormModal` — `lib/widgets/adaptive_form_modal.dart:17-53` (full file
reproduced above).
**Apply to:** `GoalPresetPickerSheet` — call it exactly as `_openAddSheet` already calls it for
`GoalFormSheet`, no changes to the helper itself.

### Honest-partial-count creation with silent-break error handling
**Source:** `GoalsNotifier.quickAddGoals` — `lib/providers/goals_notifier.dart:87-102`.
**Apply to:** whatever emoji-carrying creation path this phase adds — `try { await
_repository.save(goal); saved++; } catch (_) { break; }`, never throw, return the real count.

### Failure copy for a failed goal save
**Source:** `goal_form_sheet.dart:113` — `'Could not save goal. Please try again.'` (verified to
exist by RESEARCH.md; not independently re-read this session, cited at the exact line RESEARCH.md
gives).
**Apply to:** the UI-SPEC's required error-row behavior — on a failed preset-chip create, restore the
chip and show this exact SnackBar copy, matching the form path's existing wording rather than
inventing new copy.

### Chip-tap test idiom: scoped finder, no bare type finder
**Source:** `test/screens/restoratives_quick_pick_test.dart:55` (`Finder _chip(String name) =>
find.widgetWithText(FilterChip, name)`) and `:99-108`'s `Card`-scoped text check.
**Apply to:** every new/modified test touching the shared chip widget across all three screens.

## No Analog Found

None — every file in this phase's scope has a direct or role-match analog already in the codebase;
this is consistent with RESEARCH.md's own finding that "every piece of machinery this phase needs
already exists somewhere in this repo, built and tested."

## Metadata

**Analog search scope:** `lib/screens/onboarding/`, `lib/screens/restoratives/`,
`lib/screens/goals/`, `lib/screens/goals/widgets/`, `lib/widgets/`, `lib/providers/goals_notifier.dart`,
`test/screens/`.
**Files scanned:** 9 source files + 2 test files read directly this session (all cited above with
line numbers); RESEARCH.md's own citations cross-checked against source rather than re-derived from
scratch.
**Pattern extraction date:** 2026-09-08
