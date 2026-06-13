# Phase 8: A Schedule You Can Read - Pattern Map

**Mapped:** 2026-06-10
**Files analyzed:** 13 (8 modified + 2 created + 3 test dirs extended/created)
**Analogs found:** 13 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/services/schedule_generator.dart` | service | transform | self (extend existing logic) | exact |
| `lib/data/models/scheduled_chunk.dart` | model | — | `lib/data/models/app_settings.dart` (HiveField addition pattern) | role-match |
| `lib/data/models/scheduled_chunk.g.dart` | generated | — | `lib/data/models/app_settings.g.dart` | exact (regenerate) |
| `lib/data/database/migrations.dart` | config | — | self (extend `_migrations` list) | exact |
| `lib/providers/schedule_notifier.dart` | provider | CRUD | self (`markSkipped` at line 142) | exact |
| `lib/screens/schedule/widgets/chunk_card.dart` | component | request-response | self (extend constructor + title area) | exact |
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | component | request-response | self (pass new `goalName` + `onTap` through) | exact |
| `lib/screens/schedule/schedule_screen.dart` | screen | request-response | self (`_lookupGoalColor` at line 129) | exact |
| `lib/screens/schedule/widgets/chunk_detail_sheet.dart` | component | request-response | `lib/screens/goals/goal_form_sheet.dart` | role-match |
| `lib/screens/focus/focus_screen.dart` | screen | event-driven | `lib/screens/end_of_day/end_of_day_summary_screen.dart` + `lib/screens/quarterly_review/quarterly_review_screen.dart` | role-match |
| `lib/router.dart` | config | — | self (`/summary` GoRoute at line 109) | exact |
| `test/services/schedule_generator_test.dart` | test | — | self (extend existing tests 1–9) | exact |
| `test/screens/chunk_card_goal_name_test.dart` | test | — | `test/screens/chunk_card_hover_test.dart` | exact |
| `test/screens/chunk_detail_sheet_test.dart` | test | — | `test/screens/chunk_card_hover_test.dart` | role-match |
| `test/providers/schedule_notifier_defer_test.dart` | test | — | `test/providers/theme_notifier_test.dart` | role-match |
| `test/screens/focus_screen_test.dart` | test | — | `test/screens/chunk_card_hover_test.dart` | role-match |

---

## Pattern Assignments

### `lib/services/schedule_generator.dart` (service, transform)

**Analog:** self — `lib/services/schedule_generator.dart`

**Imports pattern** (lines 1–5 — preserve exactly):
```dart
import 'dart:math';

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
```

**Core pattern — existing break insertion loop to replace** (lines 154–188):
```dart
// CURRENT — replace entirely in READ-02:
if (workChunks.isEmpty) return [];
final List<ScheduledChunk> result = [];
int workChunkCounter = 0;
for (final chunk in workChunks) {
  result.add(chunk);
  workChunkCounter++;
  if (workChunkCounter % longBreakEvery == 0) {
    result.add(ScheduledChunk(chunkTypeIndex: ChunkType.longBreak.index, ...));
  } else {
    result.add(ScheduledChunk(chunkTypeIndex: ChunkType.shortBreak.index, ...));
  }
}
return result;
```

**New algorithm structure (replaces lines 154–188):**
```dart
// STEP A: split work chunks into commitment vs discretionary streams
final commitmentChunks = workChunks
    .where((c) => c.anchoredStartMinutes != null)
    .toList()
  ..sort((a, b) => a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!));
final discretionaryChunks = workChunks
    .where((c) => c.anchoredStartMinutes == null)
    .toList();

// STEP B: assign syntheticStartMinutes to discretionary chunks
// (use a non-Hive transient field int? syntheticStartMinutes on ScheduledChunk)
_assignSyntheticStartTimes(
  discretionaryChunks: discretionaryChunks,
  commitmentChunks: commitmentChunks,
  longBreakEvery: longBreakEvery,
);

// STEP C: interleave breaks for discretionary stream only
final List<ScheduledChunk> result = [...commitmentChunks];
int breakCounter = 0;
for (final chunk in discretionaryChunks) {
  result.add(chunk);
  breakCounter++;
  if (breakCounter % longBreakEvery == 0) {
    result.add(ScheduledChunk(chunkTypeIndex: ChunkType.longBreak.index,
        goalId: null, durationMinutes: 25, rationale: ''));
  } else {
    result.add(ScheduledChunk(chunkTypeIndex: ChunkType.shortBreak.index,
        goalId: null, durationMinutes: 5, rationale: ''));
  }
}

// STEP D: sort entire flat list by effective start time
result.sort((a, b) {
  final aStart = a.anchoredStartMinutes ?? a.syntheticStartMinutes ?? 9999;
  final bStart = b.anchoredStartMinutes ?? b.syntheticStartMinutes ?? 9999;
  return aStart.compareTo(bStart);
});

// STEP E: trim trailing break
while (result.isNotEmpty && result.last.chunkType != ChunkType.work) {
  result.removeLast();
}
return result;
```

**`_assignSyntheticStartTimes` helper** (pure, private, same file):
```dart
void _assignSyntheticStartTimes({
  required List<ScheduledChunk> discretionaryChunks,
  required List<ScheduledChunk> commitmentChunks,
  required int longBreakEvery,
}) {
  const int dayStart = 480; // 8:00 AM
  // Build commitment windows [{start, end}]
  final windows = <({int start, int end})>[];
  for (final c in commitmentChunks) {
    final s = c.anchoredStartMinutes!;
    final e = s + c.durationMinutes;
    if (windows.isNotEmpty && windows.last.end == s) {
      final prev = windows.removeLast();
      windows.add((start: prev.start, end: e));
    } else {
      windows.add((start: s, end: e));
    }
  }
  // Free slots
  final slots = <({int start, int end})>[];
  int cursor = dayStart;
  for (final w in windows) {
    if (cursor < w.start) slots.add((start: cursor, end: w.start));
    cursor = w.end;
  }
  slots.add((start: cursor, end: 1320)); // 10:00 PM cap
  // Pack discretionary into slots
  int discIdx = 0;
  int breakCount = 0;
  for (final slot in slots) {
    cursor = slot.start;
    while (cursor + 25 <= slot.end && discIdx < discretionaryChunks.length) {
      discretionaryChunks[discIdx].syntheticStartMinutes = cursor;
      cursor += 25;
      discIdx++;
      breakCount++;
      final isLong = breakCount % longBreakEvery == 0;
      final breakDur = isLong ? 25 : 5;
      if (cursor + breakDur <= slot.end && discIdx < discretionaryChunks.length) {
        cursor += breakDur;
      }
    }
  }
}
```

---

### `lib/data/models/scheduled_chunk.dart` (model, Hive schema addition)

**Analog:** `lib/data/models/scheduled_chunk.dart` (self) + existing HiveField(6)/(7) pattern

**Existing HiveField pattern to follow** (lines 44–48):
```dart
@HiveField(6)
bool isCompleted = false;

@HiveField(7)
bool isSkipped = false;
```

**New field — add after HiveField(7)**:
```dart
@HiveField(8)
bool isDeferred = false;
```

**Transient field — add after class fields (NOT a HiveField, not persisted)**:
```dart
// Synthetic start time assigned during generation; NOT stored in Hive.
// Used as sort key for discretionary chunks in ScheduleGeneratorService.
int? syntheticStartMinutes;
```

**Constructor** (line 13): `syntheticStartMinutes` is not in the constructor — it is assigned post-construction by `_assignSyntheticStartTimes`. No constructor change needed beyond adding `isDeferred` with its default.

---

### `lib/data/database/migrations.dart` (config, schema version bump)

**Analog:** self — `lib/data/database/migrations.dart`

**Version constant pattern** (line 3):
```dart
const int currentSchemaVersion = 3;  // → bump to 4
```

**Migration list pattern** (lines 9–13):
```dart
final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,
  _migration2to3,
  _migration3to4,  // ADD
];
```

**No-op migration pattern to copy** (lines 27–33):
```dart
Future<void> _migration2to3() async {
  // Phase 6: AppSettings expanded with nullable moodSeedArgb (HiveField 5)
  // and nullable lastMoodSetYmdInt (HiveField 6). Both are part of this single
  // v3 schema bump — additive nullable ints supporting daily mood seed +
  // no-carry-forward rollover seam (D-10).
  // No data transformation needed — Hive binary reader returns null for missing
  // nullable fields in existing records (per Phase 2 _migration1to2 pattern).
}
```

**New migration to add** (copy structure exactly):
```dart
Future<void> _migration3to4() async {
  // Phase 8: ScheduledChunk expanded with isDeferred (HiveField 8, bool, default false).
  // Additive bool field — Hive CE binary reader returns false for missing
  // HiveField(8) in existing ScheduledChunk records.
  // No data transformation needed.
}
```

---

### `lib/providers/schedule_notifier.dart` (provider, CRUD)

**Analog:** self — `markSkipped` at lines 142–163

**`markSkipped` pattern to mirror exactly** (lines 142–163):
```dart
Future<void> markSkipped(String chunkId) async {
  if (_todaySchedule == null) return;
  final chunk = _todaySchedule!.chunks
      .where((c) => c.id == chunkId)
      .firstOrNull;
  if (chunk == null || chunk.isSkipped) return;

  chunk.isSkipped = true;
  await _repo.save(_todaySchedule!);

  final dateYmd = _todaySchedule!.dateYmd;
  await _logRepo.append(
    CompletionLog(
      chunkId: chunkId,
      goalId: chunk.goalId ?? '',
      dateYmd: dateYmd,
      eventIndex: CompletionEvent.skipped.index,
    ),
  );

  notifyListeners();
}
```

**New `markDeferred` method** (add after `markSkipped`, same pattern):
```dart
/// Marks the chunk with [chunkId] as deferred (Phase 8: visual skip only;
/// full cross-day carryover wired in Phase 10 CLOSE-02).
Future<void> markDeferred(String chunkId) async {
  if (_todaySchedule == null) return;
  final chunk = _todaySchedule!.chunks
      .where((c) => c.id == chunkId)
      .firstOrNull;
  if (chunk == null || chunk.isDeferred) return;

  chunk.isDeferred = true;
  chunk.isSkipped = true;   // drives existing schedule_screen.dart partition
  await _repo.save(_todaySchedule!);

  final dateYmd = _todaySchedule!.dateYmd;
  await _logRepo.append(
    CompletionLog(
      chunkId: chunkId,
      goalId: chunk.goalId ?? '',
      dateYmd: dateYmd,
      eventIndex: CompletionEvent.skipped.index, // Phase 8: log as skipped
    ),
  );

  notifyListeners();
}
```

---

### `lib/screens/schedule/widgets/chunk_card.dart` (component, request-response)

**Analog:** self — `_HoverableChunkContent` at lines 106–276

**Constructor signature change** (line 23 — add two params):
```dart
// OLD:
class ChunkCard extends StatelessWidget {
  const ChunkCard({super.key, required this.chunk, this.goalColor});
  final ScheduledChunk chunk;
  final Color? goalColor;

// NEW — add goalName and onTap:
class ChunkCard extends StatelessWidget {
  const ChunkCard({
    super.key,
    required this.chunk,
    this.goalColor,
    this.goalName,      // resolved goal name; null for commitment/break chunks
    this.onTap,         // only wired for non-resolved work chunks
  });
  final ScheduledChunk chunk;
  final Color? goalColor;
  final String? goalName;
  final VoidCallback? onTap;
```

**Pass through to `_HoverableChunkContent`** (line 39):
```dart
// OLD:
case ChunkType.work:
  return _HoverableChunkContent(chunk: chunk, goalColor: goalColor);
// NEW:
case ChunkType.work:
  return _HoverableChunkContent(
    chunk: chunk,
    goalColor: goalColor,
    goalName: goalName,
    onTap: onTap,
  );
```

**`_HoverableChunkContent` constructor change** (line 107):
```dart
// OLD:
const _HoverableChunkContent({required this.chunk, this.goalColor});
final ScheduledChunk chunk;
final Color? goalColor;
// NEW:
const _HoverableChunkContent({
  required this.chunk,
  this.goalColor,
  this.goalName,
  this.onTap,
});
final ScheduledChunk chunk;
final Color? goalColor;
final String? goalName;
final VoidCallback? onTap;
```

**Title area change** (lines 187–213 in `_HoverableChunkContentState.build`):
```dart
// OLD (line 187–195):
Text(
  chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block',
  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  overflow: TextOverflow.ellipsis,
),
// NEW — goalName is primary; rationale maps to readable secondary:
Text(
  goalName ?? (chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block'),
  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  overflow: TextOverflow.ellipsis,
),
if (goalName != null && chunk.rationale.isNotEmpty) ...[
  const SizedBox(height: 2),
  Text(
    widget.onTap != null ? '' : '', // displayRationale passed from screen
    // NOTE: pass displayRationale as a separate String? param (pre-mapped in screen)
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  ),
],
```

**Simpler approach: add `displayRationale` param** (avoids mapping logic in card):
```dart
// ChunkCard constructor also adds:
final String? displayRationale;  // pre-mapped in schedule_screen.dart
// In title area, after goal name Text:
if (displayRationale != null && displayRationale!.isNotEmpty) ...[
  const SizedBox(height: 2),
  Text(
    displayRationale!,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  ),
],
```

**Tap wiring — wrap `Card` child in `GestureDetector`** (inner of the MouseRegion, before Card):
```dart
// Wrap the Card in a GestureDetector inside the MouseRegion child:
child: GestureDetector(
  onTap: widget.onTap,
  child: Card(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    // ... existing card content unchanged
  ),
),
```

---

### `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (component, request-response)

**Analog:** self — lines 14–67

**Constructor change** (lines 14–20 — add `goalName`, `displayRationale`, `onTap`):
```dart
// OLD:
class SwipeableChunkCard extends StatelessWidget {
  const SwipeableChunkCard({super.key, required this.chunk, this.goalColor});
  final ScheduledChunk chunk;
  final Color? goalColor;
// NEW:
class SwipeableChunkCard extends StatelessWidget {
  const SwipeableChunkCard({
    super.key,
    required this.chunk,
    this.goalColor,
    this.goalName,
    this.displayRationale,
    this.onTap,
  });
  final ScheduledChunk chunk;
  final Color? goalColor;
  final String? goalName;
  final String? displayRationale;
  final VoidCallback? onTap;
```

**Pass-through to ChunkCard** (lines 30–31 and 64):
```dart
// Break card (line 30–31):
return ChunkCard(chunk: chunk, goalColor: goalColor);
// Work card (line 64):
child: ChunkCard(
  chunk: chunk,
  goalColor: goalColor,
  goalName: goalName,
  displayRationale: displayRationale,
  onTap: (chunk.isCompleted || chunk.isSkipped) ? null : onTap,
),
```

---

### `lib/screens/schedule/schedule_screen.dart` (screen, request-response)

**Analog:** self — `_lookupGoalColor` at lines 128–135

**New `_lookupGoalName` method** (add after `_lookupGoalColor` at line 135):
```dart
// Source: schedule_screen.dart:129–135 — exact same structure
String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.name;
}
```

**Rationale mapping helper** (add as static const or method):
```dart
static String _toDisplayRationale(String rationale) {
  switch (rationale) {
    case 'Habit': return 'Daily habit';
    case 'Outcome goal': return 'Working toward your goal';
    case 'Weekly goal': return 'Your weekly time goal';
    default: return rationale; // commitment block names pass through
  }
}
```

**`_buildSwipeableCard` change** (lines 99–102 — add goalName, displayRationale, onTap):
```dart
// OLD:
Widget _buildSwipeableCard(BuildContext context, ScheduledChunk chunk) {
  final goalColor = _lookupGoalColor(context, chunk);
  return SwipeableChunkCard(chunk: chunk, goalColor: goalColor);
}
// NEW:
Widget _buildSwipeableCard(BuildContext context, ScheduledChunk chunk) {
  final goalColor = _lookupGoalColor(context, chunk);
  final goalName = _lookupGoalName(context, chunk);
  final displayRationale = _toDisplayRationale(chunk.rationale);
  return SwipeableChunkCard(
    chunk: chunk,
    goalColor: goalColor,
    goalName: goalName,
    displayRationale: displayRationale,
    onTap: (chunk.isCompleted || chunk.isSkipped)
        ? null
        : () => _openDetailSheet(context, chunk, goalColor, goalName, displayRationale),
  );
}
```

**Detail sheet opener** (new private method):
```dart
void _openDetailSheet(
  BuildContext context,
  ScheduledChunk chunk,
  Color? goalColor,
  String? goalName,
  String displayRationale,
) {
  final notifier = context.read<ScheduleNotifier>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChunkDetailSheet(
      chunk: chunk,
      notifier: notifier,
      goalColor: goalColor,
      goalName: goalName,
      displayRationale: displayRationale,
    ),
  );
}
```

**Focus entry point** (add to `AppBar.actions` list after the existing `IconButton` on line 47):
```dart
// First unresolved work chunk — passed as chunkId to /focus
IconButton(
  icon: const Icon(Icons.center_focus_strong_outlined),
  tooltip: 'Start focus',
  onPressed: () {
    final firstChunk = schedule.chunks.firstWhereOrNull(
      (c) => c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped,
    );
    if (firstChunk != null) context.push('/focus', extra: firstChunk.id);
  },
),
```

---

### `lib/screens/schedule/widgets/chunk_detail_sheet.dart` (component, request-response) — NEW

**Analog:** `lib/screens/goals/goal_form_sheet.dart`

**Imports pattern** (copy from goal_form_sheet.dart, adapted):
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
```

**Drag handle pattern** (goal_form_sheet.dart lines 134–144):
```dart
Center(
  child: Container(
    width: 32,
    height: 4,
    margin: const EdgeInsets.only(top: 12, bottom: 8),
    decoration: BoxDecoration(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(2),
    ),
  ),
),
```

**StatelessWidget structure** (ChunkDetailSheet receives pre-resolved notifier):
```dart
class ChunkDetailSheet extends StatelessWidget {
  const ChunkDetailSheet({
    super.key,
    required this.chunk,
    required this.notifier,
    this.goalColor,
    this.goalName,
    required this.displayRationale,
  });

  final ScheduledChunk chunk;
  final ScheduleNotifier notifier;
  final Color? goalColor;
  final String? goalName;
  final String displayRationale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isResolved = chunk.isCompleted || chunk.isSkipped;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 0, 16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle (goal_form_sheet.dart pattern, line 134–144)
          Center(child: Container(width: 32, height: 4, ...)),
          // Goal color bar + name row
          Row(children: [
            Container(width: 4, height: 48,
              decoration: BoxDecoration(
                color: goalColor ?? colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              )),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goalName ?? displayRationale,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
                if (displayRationale.isNotEmpty)
                  Text(displayRationale,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ],
            )),
          ]),
          const Divider(height: 24),
          if (!isResolved) ...[
            // Start focus — TextButton above actions
            SizedBox(width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.center_focus_strong_outlined),
                label: const Text('Start focus'),
                onPressed: () {
                  context.pop();
                  context.push('/focus', extra: chunk.id);
                },
              )),
            const SizedBox(height: 8),
            // Complete
            SizedBox(width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark complete'),
                onPressed: () {
                  notifier.markComplete(chunk.id);
                  context.pop();
                },
              )),
            const SizedBox(height: 8),
            // Skip
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.skip_next_outlined),
                label: const Text('Skip chunk'),
                onPressed: () {
                  notifier.markSkipped(chunk.id);
                  context.pop();
                },
              )),
            const SizedBox(height: 8),
            // Defer
            SizedBox(width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('Defer to later'),
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () {
                  notifier.markDeferred(chunk.id);
                  context.pop();
                },
              )),
          ] else ...[
            // Resolved state badge only
            Text(chunk.isCompleted ? 'Completed' : 'Skipped',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

**How to open** (from `schedule_screen.dart`):
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => ChunkDetailSheet(...),
);
```

---

### `lib/screens/focus/focus_screen.dart` (screen, event-driven) — NEW

**Analog:** `lib/screens/end_of_day/end_of_day_summary_screen.dart` (outside-shell full-screen StatelessWidget pattern) + `lib/screens/quarterly_review/quarterly_review_screen.dart` (StatefulWidget with `dispose()` pattern)

**Imports pattern** (end_of_day_summary_screen.dart lines 1–8, adapted):
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../providers/schedule_notifier.dart';
import '../schedule/widgets/chunk_card.dart'; // for hexToColor if needed
```

**StatefulWidget + dispose pattern** (quarterly_review_screen.dart lines 18–54):
```dart
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.chunkId});
  final String chunkId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  Timer? _timer;
  int _secondsRemaining = 1500; // 25 * 60
  bool _isRunning = false;
  bool _isDone = false;

  @override
  void dispose() {
    _timer?.cancel(); // CRITICAL: prevent setState after dispose
    super.dispose();
  }
  // ...
}
```

**Timer.periodic pattern** (no existing analog — standard dart:async):
```dart
void _start() {
  setState(() => _isRunning = true);
  _timer = Timer.periodic(const Duration(seconds: 1), (t) {
    if (_secondsRemaining <= 0) {
      t.cancel();
      setState(() { _isDone = true; _isRunning = false; });
      return;
    }
    setState(() => _secondsRemaining--);
  });
}

void _pause() {
  _timer?.cancel();
  setState(() => _isRunning = false);
}

void _doneEarly() {
  _timer?.cancel();
  setState(() { _isDone = true; _isRunning = false; });
}

String get _timerDisplay {
  final m = _secondsRemaining ~/ 60;
  final s = _secondsRemaining % 60;
  return '${m}:${s.toString().padLeft(2, '0')}';
}
```

**AppBar pattern** (end_of_day_summary_screen.dart lines 52–59, simplified):
```dart
AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  leading: const BackButton(),
  title: const Text(''),
),
```

**Provider access pattern** (end_of_day_summary_screen.dart lines 19–27):
```dart
// In build():
final scheduleNotifier = context.watch<ScheduleNotifier>();
final schedule = scheduleNotifier.todaySchedule;
```

**Break suggestion pattern** (no existing analog — pure logic):
```dart
String _breakSuggestion(ScheduleNotifier notifier) {
  final chunks = notifier.todaySchedule?.chunks ?? [];
  final idx = chunks.indexWhere((c) => c.id == widget.chunkId);
  if (idx == -1 || idx + 1 >= chunks.length) return "You're done for now.";
  final next = chunks[idx + 1];
  if (next.chunkType == ChunkType.shortBreak) return 'Nice work. Take a 5 min break.';
  if (next.chunkType == ChunkType.longBreak) return 'Great focus block. Take a 25 min break.';
  return "You're done for now.";
}
```

---

### `lib/router.dart` (config, route registration)

**Analog:** self — `/summary` GoRoute at lines 109–112

**Existing outside-shell pattern to copy** (lines 109–112):
```dart
// End-of-day summary is outside the shell — no bottom nav shown.
GoRoute(
  path: '/summary',
  builder: (context, state) => const EndOfDaySummaryScreen(),
),
```

**New `/focus` GoRoute to add** (append after `/summary` block):
```dart
// Focus mode is outside the shell — no bottom nav shown (same pattern as /summary).
GoRoute(
  path: '/focus',
  builder: (context, state) {
    if (state.extra is! String) return const Scaffold(body: SizedBox.shrink());
    return FocusScreen(chunkId: state.extra as String);
  },
),
```

**Import to add** (after line 6, alongside other screen imports):
```dart
import 'screens/focus/focus_screen.dart';
```

**Navigation call site** (from detail sheet or schedule screen):
```dart
context.push('/focus', extra: chunk.id); // push, not go — preserves back stack
```

---

## Test Pattern Assignments

### `test/services/schedule_generator_test.dart` (extend existing)

**Analog:** self — tests 1–9 (lines 1–218)

**Test helpers to reuse** (lines 23–56):
```dart
// makeHabit(), makeOutcome(), makeBlock(), workCount() are all reusable as-is.
// Also add:
int workChunksOf(List<ScheduledChunk> result) =>
    result.where((c) => c.chunkType == ChunkType.work).length;
bool hasTrailingBreak(List<ScheduledChunk> result) =>
    result.isNotEmpty && result.last.chunkType != ChunkType.work;
```

**Test 10 template** (copy structure from Test 6 at lines 149–169):
```dart
test('Test 10: commitment block + discretionary — no breaks between commitment chunks', () {
  final block = makeBlock(); // Mon-Fri, 540-600 → 2 anchored chunks
  final result = sut.generate(
    goals: [makeHabit()],
    blocks: [block],
    moodIndex: 3,
    date: monday,
  );
  // Commitment chunks (at 540, 565) must be adjacent — no break between them
  final idx540 = result.indexWhere((c) => c.anchoredStartMinutes == 540);
  final idx565 = result.indexWhere((c) => c.anchoredStartMinutes == 565);
  expect(idx565, idx540 + 1, reason: 'No break between consecutive commitment chunks');
});
```

---

### `test/screens/chunk_card_goal_name_test.dart` (new)

**Analog:** `test/screens/chunk_card_hover_test.dart` (lines 1–101)

**Pump helper** (chunk_card_hover_test.dart lines 13–14):
```dart
import '../test_helpers/mood_pump.dart';
// Use pumpWithMood(tester, ChunkCard(...)) — no extra providers needed
// since goalName is passed as a String parameter (pre-resolved).
```

**Chunk factory pattern** (chunk_card_hover_test.dart lines 15–21):
```dart
ScheduledChunk _workChunk() => ScheduledChunk(
  id: 'c1',
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'g1',
  durationMinutes: 25,
  rationale: 'Habit',
);
```

**Test structure to follow** (chunk_card_hover_test.dart lines 38–101):
```dart
void main() {
  group('ChunkCard goal name display', () {
    testWidgets('goalName appears as primary titleMedium text', (tester) async {
      await pumpWithMood(tester, ChunkCard(
        chunk: _workChunk(),
        goalName: 'Morning Run',
        displayRationale: 'Daily habit',
      ));
      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.text('Daily habit'), findsOneWidget);
    });
    // ...
  });
}
```

---

### `test/providers/schedule_notifier_defer_test.dart` (new)

**Analog:** `test/providers/theme_notifier_test.dart` (lines 1–60+)

**Binding init pattern** (theme_notifier_test.dart line 24):
```dart
TestWidgetsFlutterBinding.ensureInitialized();
```

**Listener counting helper** (theme_notifier_test.dart lines 16–19):
```dart
class _CountingListener {
  int count = 0;
  void call() => count++;
}
```

**Notifier test structure** — for `markDeferred`, needs an `InMemoryDailyScheduleRepository` fake or equivalent. Follow the `InMemoryAppSettingsRepository` pattern at `lib/data/repositories/in_memory_app_settings_repository.dart`.

---

### `test/screens/chunk_detail_sheet_test.dart` (new)

**Analog:** `test/screens/chunk_card_hover_test.dart`

**Pump pattern** — `ChunkDetailSheet` receives a `ScheduleNotifier` instance directly; use `pumpWithMood` with a mock/stub `ScheduleNotifier` passed as constructor param (no Provider needed since sheet doesn't use `context.read` — it receives the notifier directly).

---

### `test/screens/focus_screen_test.dart` (new)

**Analog:** `test/screens/chunk_card_hover_test.dart` + quarterly_review_test.dart for full-screen navigation test

**Key timer test pattern** — use `tester.binding.clock` and `fake_async` or just verify `Timer.cancel` is called by pumping the widget and popping it:
```dart
testWidgets('Timer.cancel called on dispose (no leak)', (tester) async {
  await pumpWithMood(tester, FocusScreen(chunkId: 'c1'));
  // Start timer
  await tester.tap(find.text('Start 25 min timer'));
  await tester.pump();
  // Navigate away → dispose fires
  await tester.binding.setSurfaceSize(null);
  // No setState-after-dispose exception = pass
});
```

---

## Shared Patterns

### Goal Lookup (applies to schedule_screen.dart, end_of_day_summary_screen.dart analog)
**Source:** `lib/screens/schedule/schedule_screen.dart` lines 128–135
```dart
Color? _lookupGoalColor(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  if (goal?.color != null) return hexToColor(goal!.color!);
  return null;
}
// _lookupGoalName mirrors this exactly — same null check, same where().firstOrNull
```
**Apply to:** `schedule_screen.dart` (add `_lookupGoalName` immediately after `_lookupGoalColor`), `end_of_day_summary_screen.dart` already uses the same `goals.where((g) => g.id == gid).firstOrNull` pattern at line 39.

### Outside-Shell Full-Screen Route
**Source:** `lib/router.dart` lines 109–112
```dart
GoRoute(
  path: '/summary',
  builder: (context, state) => const EndOfDaySummaryScreen(),
),
```
**Apply to:** `/focus` route registration (same position in routes list, after `/summary`).

### `showModalBottomSheet` Presentation
**Source:** `lib/screens/goals/goals_screen.dart` (calls `showModalBottomSheet`) + `lib/screens/goals/goal_form_sheet.dart` (the sheet widget)
```dart
// In the calling widget:
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (ctx) => DraggableScrollableSheet(
    // goal_form_sheet passes scrollController from DraggableScrollableSheet
  ),
);
// ChunkDetailSheet is simpler — no DraggableScrollableSheet needed;
// use plain Column with mainAxisSize: MainAxisSize.min inside Padding.
```
**Apply to:** `_openDetailSheet` in `schedule_screen.dart`.

### Hive No-Op Migration
**Source:** `lib/data/database/migrations.dart` lines 27–33
```dart
Future<void> _migration2to3() async {
  // Additive nullable fields — no data transformation needed.
}
```
**Apply to:** `_migration3to4` for `isDeferred` HiveField(8).

### `dispose()` Resource Cleanup
**Source:** `lib/screens/quarterly_review/quarterly_review_screen.dart` lines 51–54
```dart
@override
void dispose() {
  _outerController.dispose();
  super.dispose();
}
```
**Apply to:** `FocusScreen._FocusScreenState.dispose()` — call `_timer?.cancel()` before `super.dispose()`.

### Test `pumpWithMood` Helper
**Source:** `test/test_helpers/mood_pump.dart` lines 24–48
```dart
Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async { ... }
```
**Apply to:** All new widget tests (`chunk_card_goal_name_test.dart`, `chunk_detail_sheet_test.dart`, `focus_screen_test.dart`).

---

## No Analog Found

All files have close analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively, though two patterns are standard Flutter SDK with no prior project example:

| File | Pattern | Reason |
|------|---------|--------|
| `lib/screens/focus/focus_screen.dart` (Timer.periodic) | event-driven timer | No prior `Timer.periodic` usage in project; use dart:async standard pattern as documented in RESEARCH.md §Pattern 6 |
| `test/providers/schedule_notifier_defer_test.dart` (fake repo) | unit test with fake repo | No existing `InMemoryDailyScheduleRepository`; either create one mirroring `InMemoryAppSettingsRepository` at `lib/data/repositories/in_memory_app_settings_repository.dart`, or use a minimal hand-rolled fake in the test file itself |

---

## Metadata

**Analog search scope:** `lib/` (all subdirectories), `test/` (all subdirectories)
**Files scanned:** 15 source files + 8 test files
**Pattern extraction date:** 2026-06-10

**Real file paths confirmed:**
- Migration file: `lib/data/database/migrations.dart` (currentSchemaVersion = 3 at line 3)
- End-of-day summary screen: `lib/screens/end_of_day/end_of_day_summary_screen.dart`
- Quarterly review screen: `lib/screens/quarterly_review/quarterly_review_screen.dart`
- Router outside-shell pattern: `lib/router.dart` lines 109–112 (`/summary`)
- Existing schedule generator test: `test/services/schedule_generator_test.dart` (9 tests, lines 1–218)
- Chunk card hover test (widget test template): `test/screens/chunk_card_hover_test.dart`
- pumpWithMood helper: `test/test_helpers/mood_pump.dart`
