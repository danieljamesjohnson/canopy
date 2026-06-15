# Phase 19: Energy Valence - Pattern Map

**Mapped:** 2026-06-14
**Files analyzed:** 10 new/modified files
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/data/models/energy_valence.dart` | model (enum) | — | `lib/data/models/goal.dart` (GoalType enum) | exact |
| `lib/data/models/goal.dart` | model | CRUD | self (additive field pattern from prior migrations) | exact |
| `lib/data/models/goal.g.dart` | generated adapter | CRUD | self (current goal.g.dart) | exact |
| `lib/data/database/migrations.dart` | config | batch | self (_migration6to7 no-op entry) | exact |
| `lib/screens/goals/widgets/goal_card.dart` | component | request-response | self (_PriorityChip → _ValenceBadge) | exact |
| `lib/screens/schedule/widgets/chunk_card.dart` | component | request-response | self (_PriorityChip → _ValenceChip; goalPriorityWeight → goalValence prop pattern) | exact |
| `lib/screens/schedule/schedule_screen.dart` | component | request-response | self (_lookupGoalPriorityWeight → new _lookup* helpers) | exact |
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | component | request-response | self (goalPriorityWeight pass-through → new prop pass-through) | exact |
| `lib/screens/goals/goal_form_sheet.dart` | component | request-response | self (priority SegmentedButton → valence SegmentedButton) | exact |
| `lib/screens/onboarding/onboarding_screen.dart` | component | request-response | self (_Screen3 → _Screen4 pattern; _isSaving guard) | exact |
| `test/data/migration_schema8_test.dart` | test | — | `test/data/migration_schema7_test.dart` | exact |
| `test/screens/goal_form_valence_test.dart` | test | — | `test/data/migration_schema7_test.dart` (structure) | role-match |
| `test/screens/goal_card_valence_test.dart` | test | — | `test/data/migration_schema7_test.dart` (structure) | role-match |
| `test/screens/chunk_card_valence_test.dart` | test | — | `test/data/migration_schema7_test.dart` (structure) | role-match |
| `test/screens/onboarding_screen4_test.dart` | test | — | `test/data/migration_schema7_test.dart` (structure) | role-match |

---

## Pattern Assignments

### `lib/data/models/energy_valence.dart` (new enum file)

**Analog:** `lib/data/models/goal.dart` lines 8–23 (GoalType enum + comment convention)

**Enum declaration pattern** (goal.dart lines 8–23):
```dart
// ORDER IS FIXED — GoalType stored as int index; never reorder enum values.
// @HiveField 0: id (String)
// ...

/// Internal goal type — never shown in UI. UI uses plain-language descriptions.
enum GoalType { timeTarget, outcome, habit }
```

**New file must follow this pattern exactly:**
```dart
// lib/data/models/energy_valence.dart
// ORDER IS FIXED — stored as int index in Goal.energyValenceIndex.
// neutral = 0 so goals persisted without this field read as neutral.
// Never reorder these values.
enum EnergyValence { neutral, gives, costs }
```

Critical: `neutral` must be first (index 0). No `@HiveType` annotation — stored as raw `int` only.

---

### `lib/data/models/goal.dart` (MODIFIED — add HiveField 12 + 13)

**Analog:** `lib/data/models/goal.dart` lines 41–82 (existing HiveField pattern)

**Existing HiveField + enum-index pattern** (goal.dart lines 41–54):
```dart
@HiveField(0)
final String id;

@HiveField(1)
String name;

/// GoalType.index — store enum as int, never as string.
@HiveField(2)
int goalTypeIndex;

@HiveField(3)
bool isArchived = false;

GoalType get goalType => GoalType.values[goalTypeIndex];
```

**Additive nullable field pattern** (goal.dart lines 77–82):
```dart
// Habit specific (null for other GoalTypes)
@HiveField(10)
int? frequencyPerWeek; // sessions per week; null defaults to 7 (daily) in notifier

@HiveField(11)
int streakCount = 0; // updated by Phase 4; read-only in Phase 2
```

**New fields to append after line 82 (after HiveField 11):**
```dart
// Phase 19: Energy valence. Stored as int index; getter converts.
// neutral = 0 so existing records without this field read correctly.
@HiveField(12)
int? energyValenceIndex;

// Phase 19: Optional emoji tag (single emoji character). null = no tag.
@HiveField(13)
String? emojiTag;

EnergyValence get energyValence =>
    EnergyValence.values[energyValenceIndex ?? 0];
```

**Constructor addition** (matching goal.dart lines 27–39 pattern):
```dart
Goal({
  String? id,
  required this.name,
  required this.goalTypeIndex,
  this.color,
  this.priorityWeight,
  this.sortOrder = 0,
  this.weeklyHourBudget,
  this.deadline,
  this.outcomeDescription,
  this.frequencyPerWeek,
  this.streakCount = 0,
  this.energyValenceIndex, // ADD
  this.emojiTag,           // ADD
}) : id = id ?? _uuid.v4();
```

**Import to add:** `import 'energy_valence.dart';` (alongside existing imports)

---

### `lib/data/models/goal.g.dart` (REGENERATED)

**Analog:** `lib/data/models/goal.g.dart` lines 1–60 (current generated adapter)

**Current read() field-dict pattern** (goal.g.dart lines 14–31):
```dart
@override
Goal read(BinaryReader reader) {
  final numOfFields = reader.readByte();
  final fields = <int, dynamic>{
    for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
  };
  return Goal(
    id: fields[0] as String?,
    name: fields[1] as String,
    goalTypeIndex: (fields[2] as num).toInt(),
    color: fields[4] as String?,
    priorityWeight: (fields[5] as num?)?.toDouble(),
    sortOrder: fields[6] == null ? 0 : (fields[6] as num).toInt(),
    weeklyHourBudget: (fields[7] as num?)?.toDouble(),
    deadline: fields[8] as DateTime?,
    outcomeDescription: fields[9] as String?,
    frequencyPerWeek: (fields[10] as num?)?.toInt(),
    streakCount: fields[11] == null ? 0 : (fields[11] as num).toInt(),
  )..isArchived = fields[3] as bool;
}
```

**Current write() header** (goal.g.dart line 37): `..writeByte(12)` — after regen this must become `..writeByte(14)` (14 fields). Do NOT hand-edit; run `dart run build_runner build --delete-conflicting-outputs` and verify the output shows `writeByte(14)`.

---

### `lib/data/database/migrations.dart` (MODIFIED — add _migration7to8 + bump version)

**Analog:** `lib/data/database/migrations.dart` lines 1–73 (all prior no-op migration entries)

**Version constant + list pattern** (migrations.dart lines 3–17):
```dart
const int currentSchemaVersion = 7;

typedef MigrationFn = Future<void> Function();

/// Migration list. Index 0 = version 0→1, index 1 = version 1→2, etc.
/// Add new migrations here as schema changes; never modify existing entries.
final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,
  _migration2to3,
  _migration3to4,
  _migration4to5,
  _migration5to6,
  _migration6to7,
];
```

**No-op migration body pattern** (migrations.dart lines 65–73):
```dart
Future<void> _migration6to7() async {
  // ScheduledChunk gains syntheticStartMinutes (HiveField 10, int?, null).
  // Additive nullable field — Hive CE binary reader returns null for missing
  // HiveField(10) in existing records. No data transformation needed.
  // ...
}
```

**Two edits required (both in same commit):**
1. Change `const int currentSchemaVersion = 7;` → `const int currentSchemaVersion = 8;`
2. Append `_migration7to8,` to `_migrations` list
3. Add function body:
```dart
Future<void> _migration7to8() async {
  // Phase 19: Goal model gains energyValenceIndex (HiveField 12, int?, null)
  // and emojiTag (HiveField 13, String?, null). Both additive nullable fields —
  // Hive CE binary reader returns null for missing fields in existing records.
  // null energyValenceIndex → Goal.energyValence getter returns EnergyValence.neutral.
  // No data transformation needed.
}
```

**WR-06 assert** (migrations.dart lines 80–87) will fail at startup in debug mode if version and list length are out of sync — this is the correctness gate.

---

### `lib/screens/goals/widgets/goal_card.dart` (MODIFIED)

**Analog:** `lib/screens/goals/widgets/goal_card.dart` lines 224–280 (`_PriorityChip` file-private pattern)

**`_PriorityChip` structure to copy for `_ValenceBadge`** (goal_card.dart lines 229–280):
```dart
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priorityWeight});

  final double priorityWeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData icon;
    final Color chipColor;
    final Color onColor;
    final String label;

    if (priorityWeight >= 0.75) {
      icon = Icons.arrow_upward;
      chipColor = colorScheme.primaryContainer;
      onColor = colorScheme.onPrimaryContainer;
      label = 'High';
    } else if (priorityWeight <= 0.25) {
      icon = Icons.arrow_downward;
      chipColor = colorScheme.surfaceContainerHighest;
      onColor = colorScheme.onSurfaceVariant;
      label = 'Low';
    } else {
      return const SizedBox.shrink(); // Normal (0.5) — no chip
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
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

**`_ValenceBadge` must follow this structure exactly**, substituting:
- Constructor param: `required this.valence` (`EnergyValence`)
- Suppression condition: `if (valence == EnergyValence.neutral) return const SizedBox.shrink();`
- Colors: `tertiaryContainer`/`onTertiaryContainer` for `gives`; `secondaryContainer`/`onSecondaryContainer` for `costs`
- Icons: `Icons.bolt` for gives, `Icons.hourglass_empty` for costs
- Labels: `'Gives'` / `'Costs'`

**Title row modification** (goal_card.dart lines 122–159 — Row inside Column):
```dart
// Title row: icon + name + color swatch
Row(
  children: [
    Icon(
      _typeIcon(goal.goalType),
      size: 16,
      color: goalColor,
    ),
    const SizedBox(width: 6),
    // INSERT AFTER icon, BEFORE Expanded(child: Text(goal.name)):
    // if (goal.emojiTag != null) ...[
    //   const SizedBox(width: 4),
    //   Text(goal.emojiTag!, style: const TextStyle(fontSize: 16)),
    // ],
    Expanded(
      child: Text(
        goal.name,
        style: theme.textTheme.titleMedium,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    ...
  ],
),
```

**Secondary row modification** (goal_card.dart lines 161–178):
```dart
if (secondary != null || showPriorityChip) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      if (secondary != null)
        Expanded(child: Text(secondary, style: theme.textTheme.bodySmall)),
      if (showPriorityChip)
        _PriorityChip(priorityWeight: goal.priorityWeight ?? 0.5),
      // INSERT: valence badge after priority chip
      // if (goal.energyValence != EnergyValence.neutral) ...[
      //   const SizedBox(width: 4),
      //   _ValenceBadge(valence: goal.energyValence),
      // ],
    ],
  ),
],
```

**Import to add:** `import '../../../data/models/energy_valence.dart';`

---

### `lib/screens/schedule/widgets/chunk_card.dart` (MODIFIED)

**Analog:** `lib/screens/schedule/widgets/chunk_card.dart` lines 9–60 (ChunkCard constructor + `_WorkChunkContent` props) and lines 336–387 (`_PriorityChip` — intentional file-private duplicate)

**ChunkCard constructor pattern** (chunk_card.dart lines 9–42):
```dart
class ChunkCard extends StatelessWidget {
  const ChunkCard({
    super.key,
    required this.chunk,
    this.goalColor,
    this.goalName,
    this.displayRationale,
    this.goalPriorityWeight,
    this.onTap,
  });

  final ScheduledChunk chunk;
  final Color? goalColor;
  final String? goalName;
  final String? displayRationale;
  final double? goalPriorityWeight;
  final VoidCallback? onTap;
```

**Two new params to add to both `ChunkCard` and `_WorkChunkContent`:**
```dart
  final String? goalEmojiTag;   // nullable; null → no emoji prefix
  final EnergyValence? goalValence;  // nullable; null or neutral → no chip
```

**`_WorkChunkContent` title Text modification** (chunk_card.dart lines 197–205):
```dart
Text(
  goalName ??
      (chunk.rationale.isNotEmpty
          ? chunk.rationale
          : 'Work block'),
  style: theme.textTheme.titleMedium
      ?.copyWith(fontWeight: FontWeight.w600),
  overflow: TextOverflow.ellipsis,
),
```
Change to prepend emoji inline:
```dart
Text(
  '${goalEmojiTag != null ? "$goalEmojiTag " : ""}'
  '${goalName ?? (chunk.rationale.isNotEmpty ? chunk.rationale : "Work block")}',
  style: theme.textTheme.titleMedium
      ?.copyWith(fontWeight: FontWeight.w600),
  overflow: TextOverflow.ellipsis,
),
```

**Priority badge insertion point** (chunk_card.dart lines 249–256) — insert `_ValenceChip` after `_PriorityChip`:
```dart
// Priority badge below rationale (GOALS-02).
if (goalPriorityWeight != null && goalPriorityWeight != 0.5) ...[
  const SizedBox(height: 4),
  _PriorityChip(priorityWeight: goalPriorityWeight!),
],
// INSERT: valence chip after priority badge
// if (goalValence != null && goalValence != EnergyValence.neutral) ...[
//   const SizedBox(height: 4),
//   _ValenceChip(valence: goalValence!),
// ],
```

**`_ValenceChip` is a visual duplicate of `_ValenceBadge`** (see goal_card.dart _PriorityChip pattern above). Class name differs; visual spec identical. See chunk_card.dart lines 330–387 comment: _"Intentionally duplicated from goal_card.dart for file-disjoint parallelism"_.

**Import to add:** `import '../../../data/models/energy_valence.dart';`

---

### `lib/screens/schedule/schedule_screen.dart` (MODIFIED — 2 new lookup helpers)

**Analog:** `lib/screens/schedule/schedule_screen.dart` lines 222–252 (existing `_lookupGoalColor`, `_lookupGoalName`, `_lookupGoalPriorityWeight`)

**`_lookupGoalPriorityWeight` — exact pattern to copy** (schedule_screen.dart lines 241–252):
```dart
/// Resolves goal priority weight for a chunk by looking up its goalId in
/// GoalsNotifier. Returns null for commitment chunks (goalId == null) so
/// they show no priority badge.
double? _lookupGoalPriorityWeight(
  BuildContext context,
  ScheduledChunk chunk,
) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.priorityWeight;
}
```

**Two new helpers to append after `_lookupGoalPriorityWeight`:**
```dart
EnergyValence? _lookupGoalValence(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.energyValence;
}

String? _lookupGoalEmojiTag(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.emojiTag;
}
```

**`_buildSwipeableCard` call site** (schedule_screen.dart lines 169–190) — add the two new props:
```dart
Widget _buildSwipeableCard(BuildContext context, ScheduledChunk chunk) {
  final goalColor = _lookupGoalColor(context, chunk);
  final goalName = _lookupGoalName(context, chunk);
  final displayRationale = _toDisplayRationale(chunk.rationale);
  return SwipeableChunkCard(
    chunk: chunk,
    goalColor: goalColor,
    goalName: goalName,
    displayRationale: displayRationale,
    goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),
    // ADD:
    // goalEmojiTag: _lookupGoalEmojiTag(context, chunk),
    // goalValence: _lookupGoalValence(context, chunk),
    onTap: ...,
  );
}
```

**`_buildSkippedSection` call site** (schedule_screen.dart lines 208–215) — same new props on `ChunkCard` directly:
```dart
children: skippedChunks.map((chunk) {
  final goalColor = _lookupGoalColor(context, chunk);
  return ChunkCard(
    chunk: chunk,
    goalColor: goalColor,
    goalName: _lookupGoalName(context, chunk),
    displayRationale: _toDisplayRationale(chunk.rationale),
    goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),
    // ADD:
    // goalEmojiTag: _lookupGoalEmojiTag(context, chunk),
    // goalValence: _lookupGoalValence(context, chunk),
  );
}).toList(),
```

**Import to add:** `import '../../data/models/energy_valence.dart';`

---

### `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (MODIFIED — pass-through props)

**Analog:** `lib/screens/schedule/widgets/swipeable_chunk_card.dart` lines 14–91 (full file — pass-through wrapper pattern)

**Current constructor** (swipeable_chunk_card.dart lines 14–41):
```dart
class SwipeableChunkCard extends StatelessWidget {
  const SwipeableChunkCard({
    super.key,
    required this.chunk,
    this.goalColor,
    this.goalName,
    this.displayRationale,
    this.goalPriorityWeight,
    this.onTap,
  });

  final ScheduledChunk chunk;
  final Color? goalColor;
  final String? goalName;
  final String? displayRationale;
  final double? goalPriorityWeight;
  final VoidCallback? onTap;
```

**Two new params to add:**
```dart
  final String? goalEmojiTag;
  final EnergyValence? goalValence;
```

**Pass-through to ChunkCard** (swipeable_chunk_card.dart lines 81–89):
```dart
child: ChunkCard(
  chunk: chunk,
  goalColor: goalColor,
  goalName: goalName,
  displayRationale: displayRationale,
  goalPriorityWeight: goalPriorityWeight,
  // ADD:
  // goalEmojiTag: goalEmojiTag,
  // goalValence: goalValence,
  onTap: (chunk.isCompleted || chunk.isSkipped) ? null : onTap,
),
```

---

### `lib/screens/goals/goal_form_sheet.dart` (MODIFIED)

**Analog:** `lib/screens/goals/goal_form_sheet.dart` (full file — existing priority SegmentedButton pattern)

**State fields to add in `_GoalFormSheetState`** (after line 36, after `int? _frequencyPerWeek`):
```dart
EnergyValence _energyValence = EnergyValence.neutral;
String? _emojiTag;
```

**`initState()` additions** (goal_form_sheet.dart lines 41–63 — in edit branch after line 51):
```dart
if (goal != null) {
  _selectedType = goal.goalType;
  _nameController = TextEditingController(text: goal.name);
  _priorityWeight = goal.priorityWeight;
  _weeklyHourBudget = goal.weeklyHourBudget;
  _deadline = goal.deadline;
  _outcomeDescription = goal.outcomeDescription;
  _frequencyPerWeek = goal.frequencyPerWeek;
  // ADD:
  _energyValence = goal.energyValence;  // uses getter, never null
  _emojiTag = goal.emojiTag;
}
```

**`_save()` cascade additions** (goal_form_sheet.dart lines 89–97 — append to goal cascade):
```dart
goal
  ..name = _nameController.text.trim()
  ..goalTypeIndex = _selectedType!.index
  ..color = color
  ..priorityWeight = _priorityWeight
  ..weeklyHourBudget = _weeklyHourBudget
  ..deadline = _deadline
  ..outcomeDescription = _outcomeDescription
  ..frequencyPerWeek = _frequencyPerWeek
  // ADD:
  ..energyValenceIndex = _energyValence.index
  ..emojiTag = _emojiTag;
```

**Valence picker — copy Priority pattern** (goal_form_sheet.dart lines 225–247):
```dart
// Priority control — shown for all goal types
Row(
  children: [
    Text(
      'Priority',
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ],
),
SegmentedButton<double>(
  segments: const [
    ButtonSegment(value: 0.25, label: Text('Low')),
    ButtonSegment(value: 0.5, label: Text('Normal')),
    ButtonSegment(value: 0.75, label: Text('High')),
  ],
  selected: {_priorityWeight ?? 0.5},
  onSelectionChanged: (Set<double> val) =>
      setState(() => _priorityWeight = val.first),
),
const SizedBox(height: 16),
```

**Energy section to INSERT after the goal name TextField + SizedBox(height: 12)** (between lines 223 and 225):
```dart
// Energy valence — follow Priority label pattern exactly
Row(
  children: [
    Text(
      'Energy',
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ],
),
SegmentedButton<EnergyValence>(
  segments: const [
    ButtonSegment(
      value: EnergyValence.gives,
      label: Text('Gives energy'),
      icon: Icon(Icons.bolt),
    ),
    ButtonSegment(
      value: EnergyValence.neutral,
      label: Text('Neutral'),
      icon: Icon(Icons.remove),
    ),
    ButtonSegment(
      value: EnergyValence.costs,
      label: Text('Costs energy'),
      icon: Icon(Icons.hourglass_empty),
    ),
  ],
  selected: {_energyValence},
  onSelectionChanged: (Set<EnergyValence> val) =>
      setState(() => _energyValence = val.first),
),
const SizedBox(height: 8),

// Emoji tag button
_emojiTag == null
    ? OutlinedButton.icon(
        icon: const Icon(Icons.emoji_emotions_outlined),
        label: const Text('Add emoji'),
        onPressed: _pickEmoji,
      )
    : Row(
        children: [
          OutlinedButton(
            onPressed: _pickEmoji,
            child: Text(_emojiTag!,
                style: theme.textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _emojiTag = null),
          ),
        ],
      ),
const SizedBox(height: 8),
```

**`_pickEmoji()` method** — uses width check from `adaptive_form_modal.dart` pattern:
```dart
Future<void> _pickEmoji() async {
  final isDesktop = MediaQuery.of(context).size.width >= 720;
  String? picked;
  if (isDesktop) {
    picked = await showDialog<String>(
      context: context,
      builder: (_) => const _EmojiPickerDialog(),
    );
  } else {
    picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _EmojiPickerSheet(),
    );
  }
  if (picked != null) setState(() => _emojiTag = picked);
}
```

**Import to add:** `import '../../data/models/energy_valence.dart';`

---

### `lib/screens/onboarding/onboarding_screen.dart` (MODIFIED — add _Screen4, bump dots, change Screen 3 callback)

**Analog:** `lib/screens/onboarding/onboarding_screen.dart` (full file — _Screen3 structure for _Screen4)

**State additions to `_OnboardingScreenState`** (after line 34, after `bool _isSaving = false`):
```dart
// Screen 4 state
Set<String> _screen4MarkedGoalIds = {};
List<Goal> _screen4QuickGoals = [];
```

**`_StepDots` bump** (onboarding_screen.dart line 107):
```dart
_StepDots(currentPage: _currentPage, totalPages: 3),  // CHANGE to 4
```

**Screen 3 callback change** (onboarding_screen.dart lines 128–135):
```dart
_Screen3(
  onComplete: (habit) {
    _screen3Habit = habit;
    _completeOnboarding();  // CHANGE TO: _nextPage()
  },
  onSkip: _skipToComplete,  // CHANGE TO: _nextPage (skip goes to Screen 4 too)
  isSaving: _isSaving,
),
```

After the change:
```dart
_Screen3(
  onComplete: (habit) {
    _screen3Habit = habit;
    _nextPage();
  },
  onSkip: _nextPage,
  isSaving: _isSaving,
),
```

**`_completeOnboarding()` additions** (onboarding_screen.dart lines 54–96 — add step 3.5 before step 4):
```dart
// (3) Save Screen 3 habit if filled
if (_screen3Habit != null) {
  await goalsNotifier.saveGoal(_screen3Habit!);
}

// (3.5) NEW: Save Screen 4 quick-added goals, then apply valence to marked goals
for (final goal in _screen4QuickGoals) {
  goal.energyValenceIndex = EnergyValence.gives.index;
  await goalsNotifier.saveGoal(goal);
}
// Apply EnergyValence.gives to goals the user marked (Screen 1, Screen 3, quick-adds)
for (final id in _screen4MarkedGoalIds) {
  final goals = goalsNotifier.goals;
  final goal = goals.where((g) => g.id == id).firstOrNull;
  if (goal != null) {
    goal.energyValenceIndex = EnergyValence.gives.index;
    await goalsNotifier.saveGoal(goal);
  }
}

// (4) ALWAYS last — triggers router redirect
await settingsNotifier.setOnboardingComplete(true);
```

**`_Screen4` must follow `_Screen3` structure** (onboarding_screen.dart lines 450–572):
```dart
// _Screen3 constructor pattern:
class _Screen3 extends StatefulWidget {
  const _Screen3({
    required this.onComplete,
    required this.onSkip,
    required this.isSaving,
  });

  final ValueChanged<Goal?> onComplete;
  final VoidCallback onSkip;
  final bool isSaving;
```

**`_Screen4` constructor:**
```dart
class _Screen4 extends StatefulWidget {
  const _Screen4({
    required this.pendingGoals,   // goals from Screens 1+3 not yet persisted
    required this.onComplete,     // (markedIds, quickGoals) → void
    required this.onSkip,
    required this.isSaving,
  });

  final List<Goal> pendingGoals;
  final void Function(Set<String>, List<Goal>) onComplete;
  final VoidCallback onSkip;
  final bool isSaving;
```

**`_ScreenLayout` wrapper** (onboarding_screen.dart lines 578–599) — Screen 4 uses this same wrapper:
```dart
class _ScreenLayout extends StatelessWidget {
  const _ScreenLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32,
            ),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}
```

**Skip + CTA row pattern from _Screen3** (onboarding_screen.dart lines 552–568):
```dart
Row(
  children: [
    Expanded(
      child: TextButton(
        onPressed: widget.isSaving ? null : widget.onSkip,
        child: const Text('Skip'),
      ),
    ),
    const SizedBox(width: 8),
    ElevatedButton(
      onPressed: widget.isSaving ? null : _onComplete,
      child: const Text("Let's go"),
    ),
  ],
),
```

**Screen 4 passes `pendingGoals`** — parent constructs them from `_screen1NameController`/`_screen1Type` and `_screen3Habit` state, passing as display-only list. The `_completeOnboarding` steps (1)+(3) actually save them; Screen 4's marked IDs are applied in step (3.5) after saves complete.

**PageView addition** (onboarding_screen.dart lines 113–136):
```dart
children: [
  _Screen1(...),
  _Screen2(...),
  _Screen3(
    onComplete: (habit) { _screen3Habit = habit; _nextPage(); },
    onSkip: _nextPage,
    isSaving: _isSaving,
  ),
  // ADD:
  _Screen4(
    pendingGoals: _buildScreen4Goals(),  // helper constructs from state
    onComplete: (markedIds, quickGoals) {
      _screen4MarkedGoalIds = markedIds;
      _screen4QuickGoals = quickGoals;
      _completeOnboarding();
    },
    onSkip: _skipToComplete,
    isSaving: _isSaving,
  ),
],
```

**`_StepDots`** (onboarding_screen.dart lines 150–182) — unchanged code, only `totalPages` param changes from 3 to 4.

---

### `test/data/migration_schema8_test.dart` (NEW)

**Analog:** `test/data/migration_schema7_test.dart` (full file — exact structure to follow)

**File structure from migration_schema7_test.dart lines 1–114:**
```dart
// Regression test for schema version 7:
// - currentSchemaVersion == 7
// - ...

import 'dart:io';
import 'package:canopy/data/database/migrations.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  // Schema constant tests
  test('currentSchemaVersion equals 7', () {
    expect(currentSchemaVersion, equals(7));
  });

  // Hive round-trip test
  group('ScheduledChunk Hive round-trip (field 10)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_schema7_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(ScheduledChunkAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('syntheticStartMinutes persists across box close/reopen', () async {
      const boxName = 'chunks_round_trip';
      const knownValue = 565;

      final box = await Hive.openBox<ScheduledChunk>(boxName);
      final chunk = ScheduledChunk(chunkTypeIndex: 0, durationMinutes: 25,
          syntheticStartMinutes: knownValue);
      await box.put('test-key', chunk);
      await box.close();

      final reopened = await Hive.openBox<ScheduledChunk>(boxName);
      final readBack = reopened.get('test-key');
      expect(readBack!.syntheticStartMinutes, equals(knownValue));
      await reopened.close();
    });
  });
}
```

**New test file adapts this pattern:**
- Import `goal.dart`, `energy_valence.dart` instead of `scheduled_chunk.dart`
- Register `GoalAdapter()` (typeId 0)
- `currentSchemaVersion` test expects `equals(8)`
- Round-trip test writes a Goal with `energyValenceIndex` and `emojiTag`, closes, reopens, verifies both fields survive
- Additional test: Goal with NO `energyValenceIndex` set reads back as `EnergyValence.neutral` (this simulates old-record compatibility; create Goal without `energyValenceIndex`, save, reload, check getter)

---

## Shared Patterns

### Hive Additive Field Safety
**Source:** `lib/data/models/goal.g.dart` lines 14–31 (field-dict read mechanism)
**Apply to:** goal.dart model addition, migration entry, migration test

The generated `read()` maps fields by int key. A key absent from an old record returns `null` from `fields[N]`. New `int?` fields with `?? 0` in their getter and new `String?` fields with null-safe access are both safe with this mechanism. No data migration step is needed for additive nullable fields.

### File-Private Badge Widget Duplication
**Source:** `lib/screens/goals/widgets/goal_card.dart` lines 224–280 AND `lib/screens/schedule/widgets/chunk_card.dart` lines 336–387 (both define `_PriorityChip` separately)
**Apply to:** `_ValenceBadge` in goal_card.dart, `_ValenceChip` in chunk_card.dart

These are intentionally separate classes in separate files with identical visual logic. Do not extract to a shared widget. The existing comment in chunk_card.dart states this explicitly: _"Intentionally duplicated from goal_card.dart for file-disjoint parallelism"_.

### SegmentedButton Section Label
**Source:** `lib/screens/goals/goal_form_sheet.dart` lines 225–234 (Priority label row)
**Apply to:** Energy valence picker section label in goal_form_sheet.dart

```dart
Row(
  children: [
    Text(
      'Priority',  // → change to 'Energy'
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,       // w400 NOT w500 — locked by Phase 18
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ],
),
```

### Onboarding `_isSaving` Guard
**Source:** `lib/screens/onboarding/onboarding_screen.dart` lines 54–56 + lines 556–567
**Apply to:** `_Screen4` CTAs (both "Let's go" and "Skip")

```dart
// In _completeOnboarding():
if (_isSaving) return;
setState(() => _isSaving = true);

// In _Screen3 CTA row (pattern for Screen 4):
onPressed: widget.isSaving ? null : _onComplete,
// and:
onPressed: widget.isSaving ? null : widget.onSkip,
```

Both "Let's go" and "Skip" on Screen 4 must check `isSaving` — the guard prevents double-tap on any path to `_completeOnboarding()`.

### Chunk → Goal Property Lookup
**Source:** `lib/screens/schedule/schedule_screen.dart` lines 222–252
**Apply to:** Two new `_lookupGoalValence` and `_lookupGoalEmojiTag` helpers

All four existing lookup helpers (`_lookupGoalColor`, `_lookupGoalName`, `_lookupGoalPriorityWeight`, and the implicit color-only one) share the exact same structure: null-guard on `chunk.goalId`, read from `context.read<GoalsNotifier>().goals`, `where((g) => g.id == chunk.goalId).firstOrNull`, return the specific property. The two new helpers are verbatim copies of `_lookupGoalPriorityWeight` with return type and property access changed.

---

## No Analog Found

No files in this phase lack analogs. Every file has an exact match in the codebase.

---

## Metadata

**Analog search scope:** `lib/data/models/`, `lib/data/database/`, `lib/screens/goals/`, `lib/screens/schedule/`, `lib/screens/onboarding/`, `test/data/`
**Files scanned:** 12 source files + 1 test file
**Pattern extraction date:** 2026-06-14
