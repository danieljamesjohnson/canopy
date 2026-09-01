# Phase 33: Make The Obvious Thing Obvious — Pattern Map

**Mapped:** 2026-09-01
**Files analyzed:** 6 modified + 1–2 new
**Analogs found:** 7 / 7 (one seam — the shared `× 25 / 60` helper — has no analog and must be created)

This file shows the implementer **existing shapes to copy**. The design is settled in
`33-UI-SPEC.md`; nothing here proposes design.

---

## File Classification

| File to modify/create | Role | Data flow | Closest analog | Match |
|---|---|---|---|---|
| `lib/screens/schedule/widgets/chunk_card.dart` — `_buildTrailingStatus()` | widget (file-private chip) | display-only render | `_PriorityChip` / `_ValenceBadge`, `goal_card.dart:246-356`; `_ValenceChip`, `chunk_card.dart:816+` | exact |
| `lib/screens/today/widgets/free_time_row.dart` | widget | display-only render | `_buildBreak()` compact-tier `Card`, `chunk_card.dart:186-235` | exact |
| `lib/screens/goals/goals_screen.dart` | screen (list + reorder) | CRUD/reorder | itself (`_buildReorderableSection`, lines 219-322) — collapse 3 calls to 1 | exact |
| `lib/screens/goals/widgets/goal_card.dart` | widget | display-only render | itself (the `Positioned` 5dp left border, lines 93-107) | exact |
| Weekly-progress read (new helper + call site) | service/utility (pure) | batch read/transform | `lib/services/quarterly_aggregation_service.dart` (pure-Dart aggregation over `List<CompletionLog>`) | role-match |
| `lib/screens/restoratives/restoratives_screen.dart` | screen | CRUD | `QuickAddField` usage in `goals_screen.dart:115-132`; `_ValenceBadge` for chip shape | role-match |
| `lib/screens/goals/goal_form_sheet.dart` fork | modal flow | request-response | `showAdaptiveFormModal` (`lib/widgets/adaptive_form_modal.dart`) + `_openAddSheet` (`goals_screen.dart:38-47`) | exact |

---

## 1. `chunk_card.dart` — `_buildTrailingStatus()` becomes a labelled chip

### What ships today (`chunk_card.dart:755-772`) — the thing being replaced

```dart
  /// Shared trailing status: completed check icon, skipped label, or (for
  /// unresolved chunks) the unchecked radio icon. Unchanged across densities
  /// except that compact only calls this for a resolved chunk.
  Widget _buildTrailingStatus(ThemeData theme) {
    return chunk.isCompleted
        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
        : chunk.isSkipped
        ? Text(
            'skipped',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        : Icon(
            Icons.radio_button_unchecked,
            color: theme.colorScheme.onSurfaceVariant,
          );
  }
```

**Two call sites only:**
- `chunk_card.dart:694` — the detailed/full title row: `const SizedBox(width: 8), _buildTrailingStatus(theme),` inside a `Row` whose first child is `Expanded(...)`. UI-SPEC item 6 (`flex: 0 0 auto`) is already satisfied by this shape: the sibling is `Expanded`, the chip is not.
- `chunk_card.dart:750` — compact tier, resolved only:
  ```dart
        if (isResolved) ...[const SizedBox(width: 8), _buildTrailingStatus(theme)],
  ```
  UI-SPEC item 1 says all three states get a chip, so this `if (isResolved)` guard is the line that changes. Its own doc comment (lines 726-731) explains why the guard exists ("dropping it for an unresolved chunk removes an empty icon slot") — that rationale is exactly what the phase overturns, so update the comment rather than leaving it contradicting the code.

### The chip shape to copy — `_ValenceBadge`, `goal_card.dart:246-298` (verbatim)

This is the codebase's canonical labelled, display-only, container-role chip. Note: **file-private class per file**, duplicated on purpose (`chunk_card.dart:810-815` documents that precedent explicitly). A `_StatusChip` file-private to `chunk_card.dart` matches the convention.

```dart
class _ValenceBadge extends StatelessWidget {
  const _ValenceBadge({required this.valence});

  final EnergyValence valence;

  @override
  Widget build(BuildContext context) {
    if (valence == EnergyValence.neutral) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData icon;
    final Color chipColor;
    final Color onColor;
    final String label;

    if (valence == EnergyValence.gives) {
      icon = Icons.bolt;
      chipColor = colorScheme.tertiaryContainer;
      onColor = colorScheme.onTertiaryContainer;
      label = 'Gives';
    } else {
      // costs
      icon = Icons.hourglass_empty;
      chipColor = colorScheme.secondaryContainer;
      onColor = colorScheme.onSecondaryContainer;
      label = 'Costs';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Sizing / colour conventions, measured across both existing chips:**

| Property | `_ValenceBadge` (goal_card:276-296) | `_PriorityChip` (goal_card:334-353) |
|---|---|---|
| padding | `EdgeInsets.symmetric(horizontal: 8, vertical: 4)` | same |
| radius | `BorderRadius.circular(8)` | `BorderRadius.circular(10)` |
| icon size | `12` | `12` |
| gap icon→text | `SizedBox(width: 4)` | same |
| text style | `labelSmall` + `w600` | `labelMedium` + `w600` |
| fill / on-colour | `tertiaryContainer`/`onTertiaryContainer`, `secondaryContainer`/`onSecondaryContainer` | `primaryContainer`/`onPrimaryContainer`, `surfaceContainerHighest`/`onSurfaceVariant` |
| tap handling | none — `Container`, no `InkWell` | none |
| border | none (both are fill-only) | none |

UI-SPEC item 5 asks for a **border** on `To do` (`outlineVariant`) and a **dashed border** on `Skipped`. Neither existing chip has a border, so copy the border idiom from the break Card instead — `side: BorderSide(color: theme.colorScheme.outlineVariant)` (`chunk_card.dart:200`) — expressed on a `Container` as `border: Border.all(color: colorScheme.outlineVariant)`. For the dashed variant, the only dashed-stroke precedent in the tree is `_DashedRegionPainter` (`free_time_row.dart:82-122`, `_dashWidth = 2.0`, `_dashGap = 2.0`, `strokeWidth = 1`) — which item 9 deletes from `free_time_row.dart`; if a dashed chip border is built, that dash rhythm is the one to match.

**Do not add a tap target** (UI-SPEC items 3-4). The only completion affordances stay `_buildActionRow` (`chunk_card.dart:775-807`), which already labels both:

```dart
        Tooltip(
          message: 'Complete',
          child: FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete'),
            onPressed: () =>
                context.read<ScheduleNotifier>().markComplete(chunk.id),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
```

---

## 2. `free_time_row.dart` — filled card matching the break vocabulary

### Analog: the compact-tier break `Card`, `chunk_card.dart:186-235`

Exact construction (comments elided; see lines 189-195 for the margin rationale):

```dart
      return SizedBox(
        height: chunk.durationMinutes * kPixelsPerMinute,
        child: Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [ /* label + Skip rail */ ],
          ),
        ),
      );
```

| Property | Break card value | Note for `FreeTimeRow` |
|---|---|---|
| `color` | `theme.colorScheme.surfaceContainer` | UI-SPEC item 7 says "`surface` fill" — the break's actual role is `surfaceContainer`; matching the break vocabulary means matching this token |
| `margin` | `EdgeInsets.zero` (compact) / `EdgeInsets.symmetric(vertical: 4)` (full tier, line 246-249) | `FreeTimeRow` today uses `margin: const EdgeInsets.symmetric(vertical: 4)` (`free_time_row.dart:56`) with a comment saying it exists to line up with the break row — keep it |
| `shape` | `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: outlineVariant))` | copy verbatim; note the current dashed painter uses radius **8** (`_radius = 8.0`), so the radius changes 8 → 12 |
| `clipBehavior` | `Clip.antiAlias` | copy |

**Infinite-height trap, already paid for once.** `chunk_card.dart:166-185` documents that a `Row(crossAxisAlignment: stretch)` inside the timeline's ambient-unbounded `OverflowBox` throws `BoxConstraints forces an infinite height`, fixed by an explicit `height: chunk.durationMinutes * kPixelsPerMinute`. `FreeTimeRow` today deliberately fills the parent's allocated height via `Container(width: double.infinity)` + `CustomPaint` (`free_time_row.dart:51-57`) and has **no** duration for the `.until` constructor. A `Card` sizes to its child, so swapping the painter for a `Card` will collapse the row to label height unless the height is supplied — either keep the outer `Container`/`SizedBox.expand` wrapper or thread the height in the way the break card does.

**Copy is locked** (`free_time_row.dart:40-45`), do not touch:

```dart
  String _resolveLabel() {
    if (_untilMinutes != null) {
      return 'Free until ${formatMinutes(_untilMinutes)}';
    }
    return 'Free · ${formatDurationShort(_durationMinutes!)}';
  }
```

**Item 9 (delete `_DashedRegionPainter`)** also invalidates the class doc at `free_time_row.dart:5-27` ("Renders no `Card`…", "It now draws the same dashed outline a break row uses") and the existing test `test/screens/today_row_widgets_test.dart:223-229` `'neither form renders a Card'`. That test is a Kind-A retired-mechanism test — the codebase's precedent for those is to **delete with a recorded reason in place**, see `today_row_widgets_test.dart:740-763`.

---

## 3. Goals — one ranked list; progress line replaces identity border

### How reorder works today

`goals_screen.dart:219-302`, `_buildReorderableSection` — one call per type group (lines 162-188):

```dart
    return SliverToBoxAdapter(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: group.length,
        itemBuilder: (ctx, i) => GoalCard(
          key: ValueKey(group[i].id),
          goal: group[i],
          onTap: () => _openEditSheet(context, group[i]),
          onEdit: () => _openEditSheet(context, group[i]),
          onArchive: () => notifier.archiveGoal(group[i].id),
          trailing: isMobileTouch ? /* ReorderableDelayedDragStartListener + drag_indicator */ : /* Tooltip + 44×44 */,
        ),
        // newIndex is post-removal — NO >oldIndex adjustment (Pitfall 1).
        onReorderItem: (oldIndex, newIndex) async {
          final reorderedGroup = [...group];
          final item = reorderedGroup.removeAt(oldIndex);
          reorderedGroup.insert(newIndex, item);
          final allOrdered = _buildFullOrderedIds(notifier, type, reorderedGroup);
          await notifier.reorderAllWithPriority(allOrdered);
        },
      ),
    );
```

`_buildFullOrderedIds` (`goals_screen.dart:307-322`) exists **only** to splice one reordered group back into the timeTarget → outcome → habit display order:

```dart
  List<String> _buildFullOrderedIds(
    GoalsNotifier notifier,
    GoalType type,
    List<Goal> reorderedGroup,
  ) {
    final timeTargetIds = type == GoalType.timeTarget
        ? reorderedGroup.map((g) => g.id).toList()
        : notifier.timeTargetGoals.map((g) => g.id).toList();
    ...
    return [...timeTargetIds, ...outcomeIds, ...habitIds];
  }
```

### What changes when three groups collapse to one list

**`reorderAllWithPriority` receives exactly the same shape of argument — `List<String>` of goal ids in display order — and needs no change.** (`goals_notifier.dart:145-158`):

```dart
  Future<void> reorderAllWithPriority(List<String> orderedIds) async {
    const double high = 0.75;
    const double low = 0.25;
    final n = orderedIds.length;
    for (var i = 0; i < n; i++) {
      final goal = _goals.where((g) => g.id == orderedIds[i]).firstOrNull;
      if (goal != null) {
        goal.sortOrder = i;
        goal.priorityWeight = n <= 1 ? high : high - (high - low) * i / (n - 1);
        await _repository.save(goal);
      }
    }
    await loadGoals();
  }
```

Consequences the implementer must hold:

1. `_buildFullOrderedIds` becomes **dead** — with one list, `onReorderItem` can pass the reordered id list straight through. Delete it rather than leaving it unused (Pitfall 2's ordering rule dies with it, since there is no longer a three-group display order to mirror).
2. The single list's source must be goals sorted by `priorityWeight` descending (UI-SPEC item 11). `GoalsNotifier` today exposes `goals` sorted by `sortOrder` (`loadGoals`, lines 46-51) and three type-filtered getters (lines 19-26). Because `reorderAllWithPriority` writes `sortOrder = i` **and** a monotonically descending `priorityWeight` in the same loop, `sortOrder` ascending and `priorityWeight` descending are already the same order — sorting the existing `notifier.goals` is sufficient; a new notifier getter is optional, not required.
3. The three type-filtered getters stay used by `allEmpty` and the quick-add hint count (`goals_screen.dart:97-104`, `125-129`) — replace those with `notifier.goals.isEmpty` / `notifier.goals.length` rather than deleting the getters (they are also used elsewhere and by `_buildFullOrderedIds`'s tests).
4. `_buildSectionHeader` (lines 204-217) becomes dead once the type sections go.
5. `key: ValueKey(group[i].id)` and the `buildDefaultDragHandles: false` + `trailing:` drag-handle arrangement carry over unchanged — that trailing slot is also what suppresses `GoalCard`'s hover icons (`goal_card.dart:78`, `showHoverIcons = widget.trailing == null`), so a rank gutter must go on the **leading** side, not in `trailing`.

### The 5dp left border → vertical progress line

Existing shape to modify — `goal_card.dart:90-107`:

```dart
        child: Stack(
          children: [
            // Colored left border — sized by Stack to match content height
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: goalColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            ),
            // Content — determines Stack size
            Padding(padding: const EdgeInsets.only(left: 5), child: Row(...)),
```

**UI-SPEC item 18 (backstop) bites exactly here:** this `Positioned(top:0, bottom:0)` is sized by the Stack, i.e. by the card's own content height. A fill expressed as a *fraction of that* is a fraction of a varying height, which is the defect found in the sketch. Use a fixed-geometry track (e.g. an outer `SizedBox(height: <const>)` holding track + fill) rather than `FractionallySizedBox` inside this `Positioned`.

The identity colour survives only at the 16dp swatch (`goal_card.dart:158-165`):

```dart
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: goalColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
```

Note the WR-03 hover gate immediately above it (lines 147-157) — the swatch is swapped for a `SizedBox(16,16)` on hover so the hover icons don't paint over it. Keep that gate.

**`_PriorityChip` removal (item 17):** delete `goal_card.dart:300-356` and its two use sites (`goal_card.dart:80` `showPriorityChip`, `169-185` the secondary-row guard and the widget). Two test files assert it directly — `test/screens/goal_card_priority_chip_test.dart` and `test/screens/goal_card_priority_chip_rebuild_test.dart` (Kind A, retire with a recorded reason). Note `chunk_card.dart` has its **own** priority badge (`test/screens/chunk_card_priority_badge_test.dart` proves `High`/`Low` render on a chunk row) — **that one is out of scope; do not delete it by name-matching.**

**Goal colour helper** — `lib/utils/time_format.dart:4-6`:

```dart
Color hexToColor(String hex) {
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}
```
used as `goal.color != null ? hexToColor(goal.color!) : theme.colorScheme.primary` (`goal_card.dart:74-76`). Palette source of truth: `GoalsNotifier.colorPalette` (`goals_notifier.dart:28-43`), 8 hex strings, assigned by `autoColor()` / index-modulo in `quickAddGoals`.

---

## 4. Weekly progress from `CompletionLog`

### Model — `lib/data/models/completion_log.dart` (Hive typeId 4, append-only)

Fields that matter: `goalId` (`''` for commitment chunks), `dateYmd` (`'YYYY-MM-DD'` string), `eventIndex` → `CompletionEvent get event => CompletionEvent.values[eventIndex];`, and:

```dart
  /// The id this log aggregates under: the commitment block id for commitment
  /// chunks, otherwise the goal id. Use this (not [goalId]) when grouping or
  /// classifying logs for reporting.
  String get attributionId => commitmentId ?? goalId;
```
`enum CompletionEvent { completed, skipped, deferred }`.

### Repository — `lib/data/repositories/completion_log_repository.dart`

```dart
abstract class CompletionLogRepository {
  Future<List<CompletionLog>> getAll();
  Future<CompletionLog?> getById(String id);
  Future<void> append(CompletionLog entry);
  Future<List<CompletionLog>> getByDate(String dateYmd);
  Future<List<CompletionLog>> getByGoalId(String goalId);
}
```
Implementations: `HiveCompletionLogRepository` (box `'completion_logs'`) and `InMemoryCompletionLogRepository` (tests, `in_memory_completion_log_repository.dart:13-32`).

### Every existing read of `CompletionLog`

| Site | How it reads | Note |
|---|---|---|
| `lib/providers/schedule_notifier.dart:133-136` | `getByGoalId` per active goal into a local `allLogs`, passed to `_generator.generate(completionLogs: allLogs)` | **private local, not exposed** |
| `lib/services/schedule_generator.dart:318-380` | `_completedChunksThisWeek`, `_remainingHours`, `_demandForTimeTarget`, `_timeTargetRationale` | the arithmetic (below) |
| `lib/services/quarterly_aggregation_service.dart` | pure functions over `List<CompletionLog>` — `hoursPerGoal`, `notSpentCount`, `totalCompleted`, `_inRange` | **the closest architectural analog for a new shared helper** |
| `lib/screens/quarterly_review/quarterly_review_screen.dart:31-85` | injectable `CompletionLogRepository?` param, defaults to `HiveCompletionLogRepository()` | **the screen-reads-a-repo-directly precedent, with a test seam** |
| `lib/screens/today/today_screen.dart:259` | `await HiveCompletionLogRepository().getAll()` in a try/catch inside `_checkReviewWindow` | catches "Hive boxes not yet open (test environment or cold start)" |
| `lib/screens/settings/settings_screen.dart:216` | `getAll()` → `ExportService.exportCompletionLog` | export only |
| `lib/dev/dev_data_loader.dart` | seeds logs | dev only |

**Answer to the phase's critical question: no provider or notifier exposes `CompletionLog` to the UI layer.** `ScheduleNotifier` holds a `CompletionLogRepository _logRepo` (line 37) but every read is a method-local; its public surface is `todaySchedule`, `hasScheduleToday`, `moodIndex`, `isLoading` and the mutators (`generateToday`, `addEventToday`, `markComplete`, `markSkipped`, `markDeferred`). So the Goals screen must either read a repo directly (Quarterly Review's precedent) or gain a new notifier/helper.

### The arithmetic to share — `schedule_generator.dart:313-341` (verbatim, and out of scope to edit)

```dart
  /// Returns the Monday of the week containing [date].
  DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  /// Counts completed (not skipped) time-target chunks this week for [goalId].
  int _completedChunksThisWeek(
    String goalId,
    List<CompletionLog> logs,
    DateTime today,
  ) {
    final weekStart = _weekStart(today);
    return logs.where((l) {
      if (l.goalId != goalId) return false;
      if (l.event != CompletionEvent.completed) return false;
      final logDate = DateTime.parse(l.dateYmd);
      return !logDate.isBefore(weekStart) && !logDate.isAfter(today);
    }).length;
  }

  /// Remaining weekly hours for [goal], clamped to [0, weeklyHourBudget].
  double _remainingHours(Goal goal, List<CompletionLog> logs, DateTime date) {
    if (goal.weeklyHourBudget == null) return 0;
    final completedHrs =
        _completedChunksThisWeek(goal.id, logs, date) * 25.0 / 60.0;
    return (goal.weeklyHourBudget! - completedHrs).clamp(
      0.0,
      goal.weeklyHourBudget!,
    );
  }
```

Notes the implementer needs:

- **Week start is Monday**, derived from `date.weekday - 1`, and the window is inclusive on both ends (`!isBefore(weekStart) && !isAfter(today)`) — i.e. week-to-date, not the full week.
- **The filter uses `l.goalId`, not `attributionId`** — commitment logs (`goalId == ''`) fall out naturally.
- **`× 25 / 60` appears twice in the generator already** — line 336 (`_remainingHours`) and line 376 (`_timeTargetRationale`). A third independent copy in the Goals screen is exactly what UI-SPEC item 21 forbids.
- **The 25 is already a public constant** — `schedule_generator.dart:87`:
  ```dart
  /// The duration, in minutes, of one discretionary or commitment work
  /// chunk — matches the literal `25` used throughout this file's own
  /// packing passes ... Exposed for the same IN-01 reason as the break
  /// constants above.
  static const int workChunkMinutes = 25;
  ```
  It has a live consumer outside the service: `schedule_notifier.dart:427` — `const workMinutes = ScheduleGeneratorService.workChunkMinutes;`. **This is the cleanest existing seam**: a new pure helper referencing `ScheduleGeneratorService.workChunkMinutes` shares the constant without touching `schedule_generator.dart` and without a second literal.
- **The shape to copy for the new helper** is `QuarterlyAggregationService` — a stateless pure-Dart class taking `List<CompletionLog>` plus date bounds and returning numbers, tested standalone at `test/services/quarterly_aggregation_test.dart`. Its `hoursPerGoal` (line ~13) and `_inRange` (line ~129) are the closest functions.
- **Habits** (UI-SPEC item 19, `doneDays / frequencyPerWeek`) have no existing weekly-count helper; `Goal.frequencyPerWeek` and `Goal.streakCount` are the fields (`goal_card.dart:60-63` reads `streakCount`). Distinct days = distinct `dateYmd` values among the week's completed logs.
- **Outcome goals** (item 16): `Goal` carries only `deadline` / `outcomeDescription` for outcomes — `goal_card.dart:65-67` returns `null` for the outcome secondary line for exactly this reason.

---

## 5. Restoratives — quick-pick chip grid

### `RestorativesNotifier` full API surface (`lib/providers/restoratives_notifier.dart`, 71 lines)

| Member | Signature | Behaviour |
|---|---|---|
| ctor | `RestorativesNotifier({RestorativeItemRepository? repository})` | defaults to `HiveRestorativeItemRepository()`; pass in-memory in tests |
| `items` | `List<RestorativeItem> get items` | `List.unmodifiable(_items)`, sorted by `sortOrder` |
| `isEmpty` | `bool get isEmpty` | |
| `loadItems` | `Future<void> loadItems()` | `_repository.getAll()` + `notifyListeners()` |
| `saveItem` | `Future<void> saveItem(RestorativeItem item)` | create **or** update, then `loadItems()` |
| `quickAddItems` | `Future<int> quickAddItems(Iterable<String> names)` | **the bulk helper** — trims, drops blanks, appends after `max(sortOrder)+1`, stops on first save failure and returns the honest saved count, reloads once |
| `deleteItem` | `Future<void> deleteItem(String id)` | hard delete by id, then `loadItems()` |

`quickAddItems` is the natural hook for a tap-to-add chip (`quickAddItems([name])`); removal is `deleteItem(item.id)` after matching by name against `notifier.items`. `RestorativeItem` construction with an emoji is shown at `restoratives_screen.dart:115-121`:

```dart
      await notifier.saveItem(
        RestorativeItem(
          name: name,
          emojiTag: emoji,
          sortOrder: notifier.items.length,
        ),
      );
```
(`quickAddItems` sets no emoji — the row falls back to `'🌿'` at `restoratives_screen.dart:264`.)

### The frictionless-entry analog — `QuickAddField` as used by Goals (`goals_screen.dart:115-132`)

```dart
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: QuickAddField(
                        onSubmit: (names) => notifier.quickAddGoals(names),
                        autofocus: allEmpty,
                        multiAddNoun: 'goals',
                        addTooltip: 'Add goal',
                        helperText:
                            'Enter after each, or paste a list — refine details later',
                        hintText: _quickAddHint(...),
                      ),
                    ),
                  ),
```
API (`lib/widgets/quick_add_field.dart:30-64`): `required onSubmit: Future<int> Function(List<String>)`, `required hintText`, optional `helperText`, `autofocus`, `multiAddNoun`, `addTooltip`, `controller` (a `QuickAddController` whose `flush()` commits typed-but-unentered text before navigation). Its doc says it was extracted so "onboarding (goals AND restoratives) can reuse the exact same drop-free entry behavior" — `quickAddItems` already matches `onSubmit`'s signature exactly.

**Note item 28:** `helperText` above is one of the two strings the text policy removes.

### Screen scaffolding to preserve (`restoratives_screen.dart:185-220`)

`Scaffold` → `AppBar('What restores you')` → `Consumer<RestorativesNotifier>` → `Align(topCenter)` + `ConstrainedBox(maxWidth: 720)` (the same 720dp content-width idiom as `goals_screen.dart:108-109`, enforced by `test/screens/content_width_constraint_test.dart`) → `ListView.builder(padding: EdgeInsets.only(bottom: 88))` → `FloatingActionButton.extended`. `initState` loads via `addPostFrameCallback` (lines 20-26), identical to `goals_screen.dart:30-36`.

For the chip grid itself, the closest layout precedent is a `Wrap` — there is none in these files, so build it fresh; the chip *visual* should follow `_ValenceBadge` above, but a quick-pick chip **is** tappable, so it needs a real tap target (Material `FilterChip`/`ActionChip` is the idiomatic choice and carries its own semantics; `_ValenceBadge`'s `Container` deliberately does not).

---

## 6. The goal/restorative front-door fork

### How the goal form is opened today — `goals_screen.dart:38-59`

```dart
  void _openAddSheet(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => GoalFormSheet(
        scrollController: scrollController,
        isDialog: isDesktop,
      ),
    );
  }

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
Called from the extended FAB (`goals_screen.dart:196-200`) and from `GoalCard`'s `onTap`/`onEdit` (lines 242-243). **The fork belongs in front of `_openAddSheet` only — `_openEditSheet` must not fork** (editing an existing goal has already answered the question).

### `showAdaptiveFormModal` — both paths (`lib/widgets/adaptive_form_modal.dart:17-53`)

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
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 1.0,
        expand: false, snap: true, snapSizes: const [0.6, 1.0],
        builder: (ctx, scrollController) => builder(scrollController),
      ),
    );
  }
}
```

Two ways to insert the fork, both consistent with existing code:

- **Reuse `showAdaptiveFormModal`** with a builder that returns a fork widget first and swaps to `GoalFormSheet` on choice — keeps one modal for both breakpoints, and the desktop `Dialog` is `barrierDismissible: true` so a cancel works with no extra wiring. `_DialogForm` owns and disposes the `ScrollController` (lines 78-95); the mobile path hands the `DraggableScrollableSheet`'s controller through. A fork panel has no scroll needs but must still accept the `ScrollController` parameter.
- **A separate small chooser before it** — the codebase's precedent for a small two-choice modal is `restoratives_screen.dart:126-150` (`showDialog<bool>` returning a value, `if (confirmed == true && context.mounted)`). Returning `Future<T?>` from `showDialog` and branching on the result is the established shape; `showAdaptiveFormModal` returns `Future<void>` and would need a return-type change to be used the same way.

Note `GoalFormSheet` requires `scrollController` and takes `isDialog` (`goal_form_sheet.dart:9-20`), and the caller computes `isDesktop` with the same inline `>= 720` breakpoint (`adaptive_form_modal.dart:14-16` explains that no constant is introduced, deliberately).

### The second entry point — `onboarding_screen.dart:378-404`

```dart
          SegmentedButton<EnergyValence>(
            showSelectedIcon: false,
            // Order is deliberate: drains on the left, lifts on the right (UAT G-01).
            // Do not "restore" positive-first — this was flipped intentionally and
            // must stay in sync with goal_form_sheet.dart's analogous control.
            segments: const [
              ButtonSegment(value: EnergyValence.costs, label: Text('Drains'), icon: Icon(Icons.battery_2_bar, size: 18)),
              ButtonSegment(value: EnergyValence.neutral, label: Text('Neutral'), icon: Icon(Icons.remove, size: 18)),
              ButtonSegment(value: EnergyValence.gives, label: Text('Lifts'), icon: Icon(Icons.bolt, size: 18)),
            ],
            selected: {goal.energyValence},
            onSelectionChanged: (sel) {
              goal.energyValenceIndex = sel.first.index;
              context.read<GoalsNotifier>().saveGoal(goal);
            },
          ),
```

Its twin in the goal form — `goal_form_sheet.dart:261-284` — same three segments, different labels (`Costs energy` / `Neutral` / `Gives energy`) and icons (`hourglass_empty` / `remove` / `bolt`), `selected: {_energyValence}`, `onSelectionChanged: (val) => setState(() => _energyValence = val.first)`. **Both carry a comment saying the two must stay in sync and the order must not be "restored" positive-first** — any change to one is a change to both. UI-SPEC item 25 forbids adding a fourth `EnergyValence` option to either.

---

## Shared Patterns

### Container-role chips, file-private per file
**Source:** `goal_card.dart:246-298` (`_ValenceBadge`), `goal_card.dart:305-356` (`_PriorityChip`), `chunk_card.dart:816+` (`_ValenceChip`).
**Applies to:** the new chunk status chip, the goal-type chip, the restorative quick-pick chip.
The duplication is deliberate and documented (`chunk_card.dart:812-813`: *"Visual duplicate of `_ValenceBadge` in goal_card.dart — intentionally file-private per the existing `_PriorityChip` duplication pattern"*; `free_time_row.dart:78-81` states the same rule for painters). **Do not "fix" it by extracting a shared chip widget** unless the plan says so explicitly — that would contradict three separate in-code charters.

Never the error slot for status chips (`goal_card.dart:245`). The error slot is reserved for the destructive Skip button (`chunk_card.dart:800-801`).

### Content width and screen scaffolding
`Align(alignment: Alignment.topCenter)` + `ConstrainedBox(maxWidth: 720)` around the body, on both Goals (`goals_screen.dart:106-109`) and Restoratives (`restoratives_screen.dart:205-211`). Enforced by `test/screens/content_width_constraint_test.dart`.

### Load-on-mount
```dart
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<GoalsNotifier>().loadGoals(),
    );
```
`goals_screen.dart:33-35`, mirrored at `restoratives_screen.dart:23-25`.

### Desktop-hover vs mobile-touch branch
```dart
    final isMobileTouch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
```
`goals_screen.dart:230-232`, `restoratives_screen.dart:246-248`, plus the `AnimatedOpacity(duration: 120ms, curve: Curves.easeOut)` hover fade in `goal_card.dart:206-231` and `restoratives_screen.dart:282-301`.

### Retiring a mechanism
This codebase deletes dead mechanism rather than leaving it unreferenced, and records why in place — `chunk_card.dart:15-23` (the `subCompact` enum value), `today_row_widgets_test.dart:740-763` (its tests). Items 9 (`_DashedRegionPainter`), 17 (`_PriorityChip`), and the now-dead `_buildFullOrderedIds` / `_buildSectionHeader` all fall under this rule.

---

## Test conventions

**Location:** `test/screens/` for widget tests, one file per narrow concern, named `<subject>_<concern>_test.dart`. `test/providers/`, `test/services/`, `test/data/`, `test/utils/`, `test/repositories/` for the rest.

**Pump helper — `test/test_helpers/mood_pump.dart`:**
```dart
Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async
```
Wraps `child` in `MaterialApp(theme: ColorScheme.fromSeed(ThemeNotifier.moodSeeds[moodIndex]), home: Scaffold(body: child))`, optionally under a `MultiProvider`. **Every widget test in these areas uses it** — do not hand-roll a `pumpWidget`. (`test/test_helpers/viewport.dart` is the other helper, for breakpoint tests.)

**Stub factories are file-local top-level functions**, e.g. `test/screens/goal_card_priority_chip_test.dart:13-19`:
```dart
Goal _stubGoal(String id, String name, {double? priorityWeight}) => Goal(
      id: id, name: name, goalTypeIndex: 0, color: '#4CAF50',
      priorityWeight: priorityWeight,
    );
```
and `test/screens/chunk_card_priority_badge_test.dart:7-12`:
```dart
ScheduledChunk _stubWorkChunk({String? goalId}) => ScheduledChunk(
  chunkTypeIndex: ChunkType.work.index,
  goalId: goalId,
  durationMinutes: 25,
  rationale: 'test',
);
```

**Repository fakes:** either the shipped in-memory repos (`InMemoryCompletionLogRepository`, `InMemoryRestorativeItemRepository`) or a file-private class in the test — `test/screens/goals_screen_heading_test.dart:19-37` declares `class _InMemoryGoalRepository implements GoalRepository` with a `Map<String, Goal> _store`. Screen tests seed the repo, `await notifier.loadGoals()` **before** pump, then `await tester.pump()` once more "to settle the addPostFrameCallback loadGoals call" (line 66).

**Assertions are on user-visible strings and icons** — `find.text('High')`, `find.byIcon(Icons.arrow_upward)`, `find.byType(Card)`. Every test file opens with a comment naming the phase and requirement id it covers.

### Existing coverage for the files this phase touches

| Subject | Test files |
|---|---|
| `chunk_card.dart` | `chunk_card_goal_name_test.dart`, `chunk_card_hover_test.dart`, `chunk_card_priority_badge_test.dart`, `chunk_card_valence_test.dart`, plus density/break tiers in `today_row_widgets_test.dart` and `lattice_break_pair_test.dart` |
| `goal_card.dart` | `goal_card_drag_handle_test.dart`, `goal_card_hover_test.dart`, **`goal_card_priority_chip_test.dart`**, **`goal_card_priority_chip_rebuild_test.dart`**, `goal_card_valence_test.dart` |
| `goals_screen.dart` | **`goals_screen_heading_test.dart`** (asserts both `'Your goals'` and `'Drag to prioritize. Tap to edit.'` — both strings change), `goals_screen_quick_add_test.dart` (asserts the helper text being removed by item 28) |
| `free_time_row.dart` | `today_row_widgets_test.dart:210-230` — locked-copy tests **keep**; `'neither form renders a Card'` (line 223) **inverts** |
| restoratives | **No dedicated screen test.** Coverage is indirect: `test/data/restorative_item_test.dart` (model), `test/data/migration_schema8_test.dart`, `test/screens/onboarding_flow_test.dart`, `router_redirect_test.dart`, `content_width_constraint_test.dart` |
| goal form / modal | `goal_form_copy_test.dart`, `goal_form_priority_test.dart`, `goal_form_valence_test.dart`, `adaptive_form_modal_test.dart`, `test/widgets/goal_type_picker_test.dart` |
| the new progress helper | model on `test/services/quarterly_aggregation_test.dart` (pure service, no widget pump) |

Bold entries are tests whose **premise** the phase changes, not just their expected value.

---

## No Analog Found

| Thing | Role | Why no analog |
|---|---|---|
| A shared `chunks × 25 / 60` weekly-progress helper | service (pure) | No such helper exists; `QuarterlyAggregationService` is the closest *shape* but computes quarter-scoped hours, not week-to-date-against-budget. Must be written, using `ScheduleGeneratorService.workChunkMinutes` for the 25. |
| A UI-layer seam for `CompletionLog` | provider | No notifier exposes it. Closest precedents: `QuarterlyReviewScreen`'s injectable `CompletionLogRepository?` constructor param, or `today_screen.dart:259`'s direct `HiveCompletionLogRepository().getAll()` in a try/catch. |
| A tappable chip **grid** | widget | No `Wrap`-of-chips exists in these screens; only single non-tappable badges. |
| A rank-number leading gutter on a card | widget | `goal_card.dart`'s only leading element is the 5dp border; the `trailing` slot is taken by the drag handle. |

---

## Metadata

**Search scope:** `lib/` (all), `test/` (index + 5 representative files)
**Files read in full:** `goal_card.dart`, `goals_screen.dart`, `goals_notifier.dart`, `restoratives_notifier.dart`, `restoratives_screen.dart`, `adaptive_form_modal.dart`, `free_time_row.dart`, `completion_log.dart`, `mood_pump.dart`
**Files read in part:** `chunk_card.dart` (1-40, 143-262, 660-840), `schedule_generator.dart` (80-95, 300-385), `schedule_notifier.dart` (110-160), `goal_form_sheet.dart` (1-60, 255-310), `onboarding_screen.dart` (375-425), `quick_add_field.dart` (1-80), `today_screen.dart` (245-280)
**Date:** 2026-09-01
