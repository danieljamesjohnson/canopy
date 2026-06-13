# Phase 12: Home as Landing, Schedule as Plan - Pattern Map

**Mapped:** 2026-06-12
**Files analyzed:** 10 new/modified files
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/data/models/scheduled_chunk.dart` | model | CRUD | `lib/data/models/scheduled_chunk.dart` (self — additive field) | exact |
| `lib/data/models/scheduled_chunk.g.dart` | generated | CRUD | `lib/data/models/scheduled_chunk.g.dart` (regenerated) | exact |
| `lib/data/database/migrations.dart` | config | CRUD | `lib/data/database/migrations.dart` (self — append entry) | exact |
| `lib/router.dart` | config | request-response | `lib/router.dart` (self — one-line fix) | exact |
| `lib/screens/schedule/widgets/chunk_card.dart` | component | request-response | `lib/screens/schedule/widgets/chunk_card.dart` (self — modify) | exact |
| `lib/screens/schedule/schedule_screen.dart` | component | request-response | `lib/screens/schedule/schedule_screen.dart` (self — modify) | exact |
| `lib/screens/home/widgets/active_chunk_card.dart` | component | request-response | `lib/screens/home/widgets/end_of_day_card.dart` | role-match |
| `lib/screens/home/home_screen.dart` | component | request-response | `lib/screens/home/home_screen.dart` (self — refactor) | exact |
| `lib/services/schedule_generator.dart` | service | transform | `lib/services/schedule_generator.dart` (self — set field before return) | exact |
| NowMarker widget (inline in `schedule_screen.dart`) | component | request-response | `lib/screens/home/widgets/review_banner.dart` | role-match |

---

## Pattern Assignments

### `lib/data/models/scheduled_chunk.dart` (model, CRUD)

**Analog:** Self — additive `@HiveField(10)` field.

**Current field declarations** (lines 23–62, with new field appended after line 58):
```dart
// Existing last two fields for numbering reference:
@HiveField(8)
bool isDeferred = false;

@HiveField(9)
String? commitmentId;

// ADD after commitmentId (line 58):
/// Synthetic start time assigned by ScheduleGeneratorService.
/// Persisted so clock times survive app restart.
@HiveField(10)
int? syntheticStartMinutes;
```

**Remove the transient declaration** at line 62 (the current `int? syntheticStartMinutes;` without `@HiveField`).

**Add displayStartMinutes getter** after the new field:
```dart
/// Unified accessor for clock-time display.
/// Always use this getter in UI code — never access anchoredStartMinutes
/// or syntheticStartMinutes directly.
int? get displayStartMinutes => anchoredStartMinutes ?? syntheticStartMinutes;
```

**Constructor** (lines 13–21) — add `this.syntheticStartMinutes` as optional named param since it will now be persisted:
```dart
ScheduledChunk({
  String? id,
  required this.chunkTypeIndex,
  this.goalId,
  required this.durationMinutes,
  this.anchoredStartMinutes,
  this.rationale = '',
  this.commitmentId,
  this.syntheticStartMinutes,   // NEW — was transient, now persisted
}) : id = id ?? _uuid.v4();
```

---

### `lib/data/database/migrations.dart` (config, CRUD)

**Analog:** Self — append migration entry, bump version constant.

**Version constant** (line 3):
```dart
// CURRENT:
const int currentSchemaVersion = 6;
// CHANGE TO:
const int currentSchemaVersion = 7;
```

**Migration list** (lines 9–16) — append seventh entry:
```dart
final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,
  _migration2to3,
  _migration3to4,
  _migration4to5,
  _migration5to6,
  _migration6to7,  // NEW — must be the 7th entry (index 6)
];
```

**New migration function** — copy the exact style of `_migration5to6` (lines 55–62):
```dart
Future<void> _migration6to7() async {
  // ScheduledChunk gains syntheticStartMinutes (HiveField 10, int?, null).
  // Additive nullable field — Hive CE binary reader returns null for missing
  // HiveField(10) in existing records. No data transformation needed.
}
```

**WR-06 assert** (lines 71–76) enforces `_migrations.length == currentSchemaVersion`. After this change: 7 entries, version 7. Count must match.

---

### `lib/router.dart` (config, request-response)

**Analog:** Self — one-word change in the redirect closure.

**Redirect guard** (line 33):
```dart
// CURRENT:
if (onboardingDone && onOnboarding) return '/goals';
// CHANGE TO:
if (onboardingDone && onOnboarding) return '/home';
```

No other changes. Import block (lines 1–18) and all routes are unchanged.

---

### `lib/screens/schedule/widgets/chunk_card.dart` (component, request-response)

**Analog:** Self — three modifications: (1) add `_formatTimeRange`, (2) replace secondary text block, (3) replace hover overlay with always-visible buttons.

**Existing imports** (lines 1–4) — unchanged:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
```

**Existing `_formatMinutes` helper** (lines 12–18) — retain and add range variant below it:
```dart
// EXISTING — keep as-is:
String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour:${m.toString().padLeft(2, '0')} $suffix';
}

// ADD immediately after:
String _formatTimeRange(int startMin, int endMin) {
  return '${_formatMinutes(startMin)} – ${_formatMinutes(endMin)}';
}
```

**Secondary text block replacement** (lines 249–268 in `_HoverableChunkContentState.build`):
```dart
// REMOVE the if/else block that shows displayRationale OR anchoredStartMinutes:
// REPLACE WITH — clock time first, then rationale below it:
if (chunk.displayStartMinutes != null) ...[
  const SizedBox(height: 2),
  Text(
    _formatTimeRange(
      chunk.displayStartMinutes!,
      chunk.displayStartMinutes! + chunk.durationMinutes,
    ),
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  ),
] else ...[
  const SizedBox(height: 2),
  Text(
    '${chunk.durationMinutes} min',
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  ),
],
if (widget.goalName != null &&
    widget.displayRationale != null &&
    widget.displayRationale!.isNotEmpty) ...[
  const SizedBox(height: 2),
  Text(
    widget.displayRationale!,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  ),
],
```

**Hover overlay removal + always-visible action row** (lines 151–174 in `_HoverableChunkContentState`):

Remove:
- `bool _hovered = false;` state variable
- `onMarkComplete` / `onMarkSkipped` lambda variables that gate on `_hovered`
- `MouseRegion.onEnter` / `MouseRegion.onExit` callbacks (keep `MouseRegion` for cursor only)
- The entire `Positioned` + `AnimatedOpacity` block (lines 300–325)

Add below the main content `Expanded` column (inside the `Opacity` wrapper, after the `SizedBox(width: 8)` / status icon row, only when `!isResolved`):
```dart
if (!isResolved) ...[
  const SizedBox(height: 12),
  Row(
    children: [
      FilledButton.icon(
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Complete'),
        tooltip: 'Complete',
        onPressed: () =>
            context.read<ScheduleNotifier>().markComplete(chunk.id),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.skip_next_outlined),
        label: const Text('Skip'),
        tooltip: 'Skip',
        onPressed: () =>
            context.read<ScheduleNotifier>().markSkipped(chunk.id),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
  ),
],
```

`MouseRegion` retains cursor change only (no content reveal):
```dart
MouseRegion(
  cursor: SystemMouseCursors.click,
  child: GestureDetector(
    onTap: widget.onTap,
    // ...
  ),
),
```

---

### `lib/screens/schedule/schedule_screen.dart` (component, request-response)

**Analog:** Self — insert NowMarker computation and insertion into ListView.

**Existing imports** (lines 1–14) — add NowMarker import after swipeable_chunk_card:
```dart
// ADD after existing imports:
import 'widgets/now_marker.dart';
```

**NowMarker insertion in `build`** — replace the simple `for` loop in ListView children (line 93) with:
```dart
// Compute NowMarker insertion index once per build
final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
int? nowMarkerIndex;
for (int i = 0; i < activeChunks.length; i++) {
  final c = activeChunks[i];
  if (c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped) {
    if (nowMarkerIndex == null) nowMarkerIndex = i; // fallback: first unresolved
    if ((c.displayStartMinutes ?? 9999) >= nowMinutes) {
      nowMarkerIndex = i;
      break;
    }
  }
}

// In ListView children list:
final List<Widget> items = [];
for (int i = 0; i < activeChunks.length; i++) {
  if (i == nowMarkerIndex) items.add(const NowMarker());
  items.add(_buildSwipeableCard(context, activeChunks[i]));
}
// Then:
Expanded(
  child: ListView(
    children: [
      ...items,
      if (skippedChunks.isNotEmpty)
        _buildSkippedSection(context, skippedChunks),
    ],
  ),
),
```

**Goal color / name lookup** (lines 171–193) — unchanged, copy pattern verbatim for `ActiveChunkCard`.

---

### `lib/screens/home/widgets/active_chunk_card.dart` (component, request-response) — NEW

**Analog:** `lib/screens/home/widgets/end_of_day_card.dart` (same directory, same StatelessWidget + Card + colorScheme pattern)

**Imports pattern** — follow end_of_day_card.dart exactly for structure; add provider and notifier:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/goals_notifier.dart';
import '../../../providers/schedule_notifier.dart';
import '../../schedule/widgets/chunk_card.dart';  // for hexToColor, _formatMinutes (or extract shared helper)
```

Note: `hexToColor` and `_formatMinutes`/`_formatTimeRange` live in `chunk_card.dart` as top-level functions. Since they are not exported from a shared lib, either (a) duplicate them in `active_chunk_card.dart` or (b) extract to a shared `lib/utils/time_format.dart`. Prefer option (b) as the RESEARCH recommends avoiding duplication.

**Widget signature** — StatelessWidget accepting the chunk and delegating lookups via `context.read`:
```dart
class ActiveChunkCard extends StatelessWidget {
  const ActiveChunkCard({
    super.key,
    required this.chunk,
  });

  final ScheduledChunk chunk;
```

**Goal color lookup pattern** — copy from `ScheduleScreen._lookupGoalColor` (lines 171–177):
```dart
Color? _lookupGoalColor(BuildContext context) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  if (goal?.color != null) return hexToColor(goal!.color!);
  return null;
}
```

**Goal name lookup pattern** — copy from `ScheduleScreen._lookupGoalName` (lines 179–186):
```dart
String? _lookupGoalName(BuildContext context) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.name;
}
```

**Card structure** — follow `_HoverableChunkContent` Card shape + left color bar + `Opacity` + action buttons:
```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final goalColor = _lookupGoalColor(context);
  final goalName = _lookupGoalName(context);
  final barColor = goalColor ?? theme.colorScheme.primary;

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        // Left color bar — 4dp wide (UI-SPEC §Spacing)
        Positioned(
          left: 0, top: 0, bottom: 0, width: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goalName ?? (chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (chunk.displayStartMinutes != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_formatTimeRange(chunk.displayStartMinutes!, chunk.displayStartMinutes! + chunk.durationMinutes)} · ${chunk.durationMinutes} min',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 2),
                            Text(
                              '${chunk.durationMinutes} min',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // "Now" badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Always-visible action row
                Row(
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete'),
                      tooltip: 'Complete',
                      onPressed: () =>
                          context.read<ScheduleNotifier>().markComplete(chunk.id),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.skip_next_outlined),
                      label: const Text('Skip'),
                      tooltip: 'Skip',
                      onPressed: () =>
                          context.read<ScheduleNotifier>().markSkipped(chunk.id),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

### NowMarker widget (component, request-response) — NEW, inline or extracted

**Analog:** `lib/screens/home/widgets/review_banner.dart` (thin StatelessWidget, reads theme, no provider state)

**Recommend extracting** to `lib/screens/schedule/widgets/now_marker.dart` so `schedule_screen.dart` can import it cleanly.

**Full widget** (small — no large analog needed):
```dart
import 'package:flutter/material.dart';

/// Thin visual divider with a "Now" label inserted before the first unresolved
/// work chunk in ScheduleScreen's ListView.
class NowMarker extends StatelessWidget {
  const NowMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(width: 40, height: 1, color: color.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'Now',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Container(height: 1, color: color.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### `lib/screens/home/home_screen.dart` (component, request-response)

**Analog:** Self — structural refactor; existing provider wiring and scaffold pattern unchanged.

**Existing imports** (lines 1–15) — add ActiveChunkCard:
```dart
import 'widgets/active_chunk_card.dart';  // NEW
```

**Existing `nextChunk` computation** (lines 95–100) — split into current + next:
```dart
// REPLACE:
final nextChunk = schedule.chunks
    .where((c) => c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped)
    .firstOrNull;

// WITH:
final unresolvedWork = schedule.chunks
    .where((c) => c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped)
    .toList();
final currentChunk = unresolvedWork.isNotEmpty ? unresolvedWork.first : null;
final nextChunk = unresolvedWork.length > 1 ? unresolvedWork[1] : null;
```

**Section label style** — copy from existing "Up next" label (lines 147–154):
```dart
// Pattern for "Now" and "Next" section labels — matches existing letterSpacing 0.8 convention:
Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
  child: Text(
    'Now',    // or 'Next'
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
    ),
  ),
),
```

**All done state** — retain existing copy at lines 157–163:
```dart
if (currentChunk == null)
  const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      'All done today!',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  )
else
  ActiveChunkCard(chunk: currentChunk),
```

**"See full schedule" link** — new TextButton after Next section, before mood row:
```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  child: TextButton(
    onPressed: () => context.go('/schedule'),
    child: const Text('See full schedule'),
  ),
),
```

**Mood row** — move below Now/Next sections (unchanged widget code, just relocated in Column children).

**`_lookupGoalName`** (lines 247–252) — unchanged, retained for Next chunk row rendering.

---

### `lib/services/schedule_generator.dart` (service, transform)

**Analog:** Self — `syntheticStartMinutes` is already set on chunks during `_assignSyntheticStartTimes` (confirmed at lines 514, 536). No code change needed here after the `@HiveField(10)` annotation is added and `build_runner` regenerates the adapter. The save in `ScheduleNotifier.generateToday` will automatically persist the field because Hive's generated `write` method will include `writeByte(10)` after regeneration.

**Verification step** — after running `build_runner`, confirm in `lib/data/models/scheduled_chunk.g.dart` that `write` opens with `writeByte(11)` (11 fields) and includes:
```dart
..writeByte(10)
..write(obj.syntheticStartMinutes)
```

---

## Shared Patterns

### Provider read pattern
**Source:** `lib/screens/schedule/schedule_screen.dart` lines 29, 173–177
**Apply to:** `ActiveChunkCard`, `NowMarker` insertion logic, refactored `HomeScreen`
```dart
// Watch for rebuilds:
final scheduleNotifier = context.watch<ScheduleNotifier>();
// Read for one-shot action calls (inside callbacks):
context.read<ScheduleNotifier>().markComplete(chunk.id);
context.read<ScheduleNotifier>().markSkipped(chunk.id);
// Read goals for lookup (no rebuild needed):
final goals = context.read<GoalsNotifier>().goals;
```

### Theme color access
**Source:** `lib/screens/schedule/widgets/chunk_card.dart` lines 156–161
**Apply to:** All new/modified widgets
```dart
final theme = Theme.of(context);
// Bar color with resolved-state fallback:
final barColor = chunk.isCompleted || chunk.isSkipped
    ? Colors.grey.shade400
    : (widget.goalColor ?? theme.colorScheme.primary);
// Secondary text color:
theme.colorScheme.onSurfaceVariant
// Error color for Skip button:
theme.colorScheme.error
```

### Card shape + left color bar
**Source:** `lib/screens/schedule/widgets/chunk_card.dart` lines 181–204
**Apply to:** `ActiveChunkCard`
```dart
Card(
  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  clipBehavior: Clip.antiAlias,
  child: Stack(children: [
    Positioned(
      left: 0, top: 0, bottom: 0,
      width: 4,  // UI-SPEC standardizes to 4dp (was 5dp in ChunkCard — fix both)
      child: DecoratedBox(decoration: BoxDecoration(
        color: barColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      )),
    ),
    // content...
  ]),
),
```

### go_router navigation
**Source:** `lib/screens/home/home_screen.dart` line 109; `lib/screens/schedule/schedule_screen.dart` lines 52, 62
**Apply to:** "See full schedule" link in HomeScreen
```dart
// Branch switch (no back button) — use context.go:
context.go('/schedule');
// Stack push (back button retained) — use context.push:
context.push('/schedule/checkin');
```

---

## No Analog Found

All files have close analogs in the codebase. No entries here.

---

## Metadata

**Analog search scope:** `lib/` (all subdirectories)
**Files scanned:** 10 primary analogs read in full
**Pattern extraction date:** 2026-06-12
