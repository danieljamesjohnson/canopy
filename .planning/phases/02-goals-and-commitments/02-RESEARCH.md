# Phase 2: Goals and Commitments - Research

**Researched:** 2026-02-26
**Domain:** Flutter CRUD UI, Provider/ChangeNotifier wiring, Hive entity expansion, onboarding flows
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Goal list presentation**
- Goals grouped by type using plain-language section headers (e.g. "Regular time" / "Working toward" / "Daily habits") — no internal enum labels ever shown
- Each goal card has a colored left border + small icon as the visual type indicator
- Card shows: name, type indicator (border + icon), color swatch; secondary line with weekly hours or streak count only if set — no stat overload
- Archived goals live on a separate screen accessed via overflow menu ("View archived") — main list stays clean

**Goal creation UX**
- Type picker: vertical card stack, one card per plain-language option, tap to select and highlight — deliberate and clear
- Required fields to save: name + type only; color defaults to a generated value, all other type-specific fields (hours, deadline, frequency) are optional and can be completed later
- Add/Edit Goal opens as an expandable bottom sheet; user can pull up to full screen if the form needs more space
- Reordering within a type group: long-press reveals drag handles on each card

**Commitment block entry**
- Time window: two standard time pickers (start time, end time) — clear and flexible
- Day selection: horizontal S M T W T F S chips, multi-select by tapping — standard, works well on mobile
- Commitment block card shows: name, color swatch, days + time range on one card (e.g. "9am – 5pm · Mon–Fri")
- Multiple commitment blocks supported; same list + Add button pattern as goals, no enforced limit

**Onboarding flow**
- Screen 1 type picker: same vertical card stack used in the main Add Goal sheet — consistent, no extra learning curve
- Skip on Screens 2 and 3: instant, single tap, no confirmation, no modal — preserves under-90-second pace
- Visual progression: step indicator dots (1–2–3) at top, screens slide left; no back navigation during onboarding
- After completing or skipping all onboarding screens: land on the Goals list screen so the user sees their created goal immediately

### Claude's Discretion

- Exact plain-language wording for the three section headers (e.g. "Regular time" vs "Time for something")
- Color palette and icon choices for each goal type
- Empty-state illustration/copy for the goals list
- Loading/saving state handling within sheets
- Exact spacing, typography, and animation curves

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| commitment-blocks | User can define fixed commitment blocks (name, days of week, start/end time window, color) that are always scheduled regardless of mood | Hive entity already exists (CommitmentBlock, typeId 1); HiveCommitmentBlockRepository already implemented; CommitmentsNotifier stub exists; showTimePicker + FilterChip pattern covers time/day UI |
| goal-types | User can set up goals across three types: time-target, outcome-focused, habit; internal enum never shown in UI | Goal entity (typeId 0) exists with GoalType enum; model needs field expansion (color, priority weight, type-specific fields, sort order); HiveGoalRepository already implemented; GoalsNotifier stub exists |

</phase_requirements>

---

## Summary

Phase 2 builds directly on the completed Phase 1 foundation. All the persistence infrastructure is in place: `Goal` (typeId 0) and `CommitmentBlock` (typeId 1) have Hive entities with generated TypeAdapters, repository interfaces with Hive implementations, and stub ChangeNotifiers wired into MultiProvider. The router already handles `/goals` and `/onboarding` as stub screens. No new packages are needed for the core functionality.

The primary technical work falls into four categories: (1) expanding the existing `Goal` model with additional fields (color, priority weight, sort order, type-specific fields) using hive_ce's additive field pattern and triggering a migration increment; (2) implementing GoalsNotifier and CommitmentsNotifier with real CRUD logic against the existing repositories; (3) building the Goals list screen, Add/Edit Goal bottom sheet, CommitmentBlock list screen, Add/Edit CommitmentBlock sheet, and Archived Goals screen; and (4) building the three-screen onboarding flow using PageView with step dots.

All UI patterns required are built-in Flutter Material 3: `DraggableScrollableSheet` for the expandable bottom sheet, `ReorderableListView` with `ReorderableDelayedDragStartListener` for long-press drag reorder, `showTimePicker` returning `TimeOfDay` for time window entry, `FilterChip` for day-of-week multi-select, and `PageView` with a custom dot indicator for onboarding. No additional pub.dev packages are needed. The `smooth_page_indicator` package could be used for the onboarding dots but adds an unnecessary dependency — a simple `AnimatedContainer` dot row is equally effective and keeps the dependency count flat.

**Primary recommendation:** Expand the Goal model fields (nullable for backward compatibility), bump schemaVersion to 2 with a no-op migration, implement GoalsNotifier and CommitmentsNotifier against existing repositories, build all screens using Flutter's built-in widgets, and wire the onboarding flow using PageView. No new packages required.

---

## Standard Stack

### Core (all already in pubspec.yaml — no additions needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| hive_ce | ^2.19.3 | Persist Goal and CommitmentBlock entities | Already installed; entities exist; adapters generated |
| provider | ^6.1.5+1 | GoalsNotifier and CommitmentsNotifier wired to UI | Already in MultiProvider at app root |
| go_router | ^17.1.0 | `/goals`, `/onboarding`, `/goals/archived` routes | Already installed; router stubs in place |
| shared_preferences | ^2.5.4 | onboardingComplete flag; read/set via SettingsNotifier | Already installed; SettingsNotifier already reads it |
| uuid | ^4.5.3 | UUID v4 for new Goal and CommitmentBlock IDs | Already installed |
| intl | ^0.20.2 | Time formatting (e.g. "9am", "5pm") for commitment card display | Already installed |
| flutter (Material) | SDK | DraggableScrollableSheet, ReorderableListView, showTimePicker, FilterChip, PageView, AnimatedContainer, ChoiceChip | Built-in Material 3 |

### No New Dependencies Required

Phase 2 needs no new pub.dev packages. Every UI primitive required is available in the Flutter Material SDK:

| UI Need | Widget / API |
|---------|--------------|
| Expandable bottom sheet | `showModalBottomSheet` + `DraggableScrollableSheet` |
| Long-press drag reorder | `ReorderableListView` + `ReorderableDelayedDragStartListener` |
| Time pickers | `showTimePicker` → `TimeOfDay` → convert to `int` minutes |
| Day-of-week chips | `FilterChip` (multi-select), `Wrap` or horizontal `Row` |
| Type picker cards | `InkWell` + `Card` (or `GestureDetector` + `Container`) |
| Onboarding page slide | `PageView` (with `NeverScrollableScrollPhysics` — programmatic only) |
| Step dots | `AnimatedContainer` in a `Row` |
| Goal list grouping | `SliverList` + `SliverToBoxAdapter` for headers in `CustomScrollView` |
| Color swatch | `Container` with `BoxDecoration(color: ...)` |
| Left border | `Container` with `BoxDecoration(border: Border(left: BorderSide(...)))` |

### Optional (Not Recommended for This Phase)

| Package | Why Skip |
|---------|----------|
| smooth_page_indicator | Adds dependency for onboarding dots; `AnimatedContainer` dot row achieves the same effect |
| flutter_colorpicker | Not needed — goal colors are auto-generated from a curated palette, not user-picked |

---

## Architecture Patterns

### What Phase 1 Built (Phase 2 Builds On)

```
lib/
├── main.dart                          # MultiProvider with GoalsNotifier, CommitmentsNotifier, SettingsNotifier stubs
├── router.dart                        # /goals, /onboarding routes (stub screens)
├── data/
│   ├── models/
│   │   ├── goal.dart                  # Goal (typeId 0): id, name, goalTypeIndex, isArchived — NEEDS EXPANSION
│   │   ├── commitment_block.dart      # CommitmentBlock (typeId 1): id, name, daysOfWeek, startMinutes, endMinutes, color — COMPLETE
│   ├── repositories/
│   │   ├── hive_goal_repository.dart          # getAll, getById, save, delete, getActive — COMPLETE
│   │   ├── hive_commitment_block_repository.dart  # getAll, getById, save, delete, getByDayOfWeek — COMPLETE
│   └── database/
│       ├── hive_database.dart         # Init, adapter registration, box opening — COMPLETE
│       └── migrations.dart           # currentSchemaVersion = 1; _migration0to1 no-op — NEEDS VERSION BUMP
├── providers/
│   ├── goals_notifier.dart            # Empty stub — NEEDS FULL IMPLEMENTATION
│   ├── commitments_notifier.dart      # Empty stub — NEEDS FULL IMPLEMENTATION
│   └── settings_notifier.dart         # onboardingComplete bool + setOnboardingComplete — COMPLETE (but needs SharedPreferences wiring)
└── screens/
    ├── goals/goals_screen.dart        # Stub — NEEDS FULL IMPLEMENTATION
    └── onboarding/onboarding_screen.dart  # Stub — NEEDS FULL IMPLEMENTATION
```

### New Files Phase 2 Creates

```
lib/
├── screens/
│   ├── goals/
│   │   ├── goals_screen.dart             # Replace stub: grouped list + FAB
│   │   ├── archived_goals_screen.dart    # New: archived goals list
│   │   ├── goal_form_sheet.dart          # New: expandable bottom sheet for add/edit
│   │   └── widgets/
│   │       ├── goal_card.dart            # New: colored border card + icon
│   │       └── goal_type_picker.dart     # New: vertical card stack (shared with onboarding)
│   ├── commitments/
│   │   ├── commitments_screen.dart       # New: commitment block list (accessed from Goals overflow or Settings)
│   │   └── commitment_form_sheet.dart    # New: bottom sheet for add/edit
│   └── onboarding/
│       └── onboarding_screen.dart        # Replace stub: 3-screen PageView flow
```

### Pattern 1: Expanding a Hive Entity Without Breaking Existing Data

**What:** Add new nullable fields to `Goal` with new `@HiveField` indices. The TypeAdapter generated by hive_ce_generator reads only the fields present in binary data; missing fields return `null` (for nullable types) or default values.

**Critical rule:** Never reuse a `@HiveField` index. New fields always get the next unused index. Existing users' data read back will have `null` for any new field — code must handle this.

**When to use:** Every time Phase 2 adds fields to Goal.

**Goal model expansion needed:**
```dart
// lib/data/models/goal.dart — add fields 4-10, keep fields 0-3 unchanged

@HiveField(4)
String color;                     // hex string, e.g. '#4CAF50'; auto-generated if null

@HiveField(5)
double priorityWeight;            // scheduling weight 0.0–1.0; default 0.5

@HiveField(6)
int sortOrder;                    // position within type group; default 0

// Time-target fields (null for other types)
@HiveField(7)
double? weeklyHourBudget;         // null unless goalType == timeTarget

// Outcome fields (null for other types)
@HiveField(8)
DateTime? deadline;               // null unless goalType == outcome

@HiveField(9)
String? outcomeDescription;       // null unless goalType == outcome

// Habit fields (null for other types)
@HiveField(10)
int? frequencyPerWeek;            // null unless goalType == habit; default 7 = daily

@HiveField(11)
int streakCount;                  // current streak; default 0; updated by Phase 4
```

After adding fields, regenerate adapters:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Then bump `currentSchemaVersion` to 2 in `migrations.dart` and add a no-op `_migration1to2`. Existing Goal records will read back with `null` for new fields — initialize defaults in the notifier or constructor.

### Pattern 2: GoalsNotifier with Repository

**What:** GoalsNotifier holds the in-memory list of active goals, calls HiveGoalRepository for persistence, and notifies listeners. UI only reads from the notifier — it never calls the repository directly.

**Pattern (Provider best practice):**
```dart
// lib/providers/goals_notifier.dart
class GoalsNotifier extends ChangeNotifier {
  final GoalRepository _repository = HiveGoalRepository();

  List<Goal> _goals = [];
  List<Goal> get goals => List.unmodifiable(_goals);

  // Grouped views for the list screen
  List<Goal> get timeTargetGoals =>
      _goals.where((g) => g.goalType == GoalType.timeTarget).toList();
  List<Goal> get outcomeGoals =>
      _goals.where((g) => g.goalType == GoalType.outcome).toList();
  List<Goal> get habitGoals =>
      _goals.where((g) => g.goalType == GoalType.habit).toList();

  Future<void> loadGoals() async {
    _goals = await _repository.getActive();
    _goals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> saveGoal(Goal goal) async {
    await _repository.save(goal);
    await loadGoals();
  }

  Future<void> archiveGoal(String id) async {
    final goal = await _repository.getById(id);
    if (goal == null) return;
    goal.isArchived = true;
    await _repository.save(goal);
    await loadGoals();
  }

  Future<void> reorder(GoalType type, int oldIndex, int newIndex) async {
    // Update sortOrder for goals within the type group
    final group = _goalsOfType(type);
    if (newIndex > oldIndex) newIndex--;
    final moved = group.removeAt(oldIndex);
    group.insert(newIndex, moved);
    for (int i = 0; i < group.length; i++) {
      group[i].sortOrder = i;
      await _repository.save(group[i]);
    }
    await loadGoals();
  }

  List<Goal> _goalsOfType(GoalType type) =>
      _goals.where((g) => g.goalType == type).toList();
}
```

**Initialization:** Call `goalsNotifier.loadGoals()` in the `initState` of `GoalsScreen` (or in an `init` method called once from a screen that reads the notifier). Do not call it from `main()` — that adds startup latency. Use `context.read<GoalsNotifier>().loadGoals()` inside the first frame.

### Pattern 3: DraggableScrollableSheet for Add/Edit Bottom Sheet

**What:** `showModalBottomSheet` with `isScrollControlled: true` and `DraggableScrollableSheet` inside. The sheet opens at ~60% screen height and can be dragged to full screen.

**Key parameters:**
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,   // allows sheet to go full-screen
  useSafeArea: true,
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    minChildSize: 0.4,
    maxChildSize: 1.0,
    expand: false,
    snap: true,
    snapSizes: const [0.6, 1.0],
    builder: (context, scrollController) => GoalFormSheet(
      scrollController: scrollController,
    ),
  ),
);
```

**GoalFormSheet takes the scrollController and passes it to a `SingleChildScrollView`** so dragging and content scrolling don't conflict. This is the critical requirement — the scrollController from DraggableScrollableSheet must be used by the scroll view inside.

**Source:** [DraggableScrollableSheet Flutter API](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html)

### Pattern 4: ReorderableListView with Long-Press Drag Handles

**What:** `ReorderableListView` with `buildDefaultDragHandles: false` (so we control the drag handle widget), and each item wrapped with `ReorderableDelayedDragStartListener` (long-press triggers drag).

**Key facts:**
- `ReorderableListView` by default on desktop shows drag handles permanently; on mobile, long-press anywhere triggers drag. Setting `buildDefaultDragHandles: false` disables this on all platforms.
- `ReorderableDelayedDragStartListener` wraps the drag handle widget and initiates drag after long-press.
- Each child in `ReorderableListView` must have a unique `Key`.

```dart
ReorderableListView(
  buildDefaultDragHandles: false,
  onReorder: (oldIndex, newIndex) => notifier.reorder(type, oldIndex, newIndex),
  children: goals.asMap().entries.map((entry) {
    final goal = entry.value;
    return GoalCard(
      key: ValueKey(goal.id),
      goal: goal,
      trailing: ReorderableDelayedDragStartListener(
        index: entry.key,
        child: const Icon(Icons.drag_handle),
      ),
    );
  }).toList(),
)
```

**Source:** [ReorderableListView Flutter API](https://api.flutter.dev/flutter/material/ReorderableListView-class.html), [ReorderableDelayedDragStartListener](https://api.flutter.dev/flutter/widgets/ReorderableDelayedDragStartListener-class.html)

### Pattern 5: showTimePicker and Minutes-from-Midnight Conversion

**What:** The existing `CommitmentBlock` model stores times as `int` minutes from midnight UTC. The UI uses `showTimePicker` which returns a `TimeOfDay`. Convert bidirectionally.

```dart
// TimeOfDay → int (minutes from midnight)
int timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

// int (minutes from midnight) → TimeOfDay
TimeOfDay minutesToTimeOfDay(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

// Display string for commitment card (e.g. "9am – 5pm")
String formatTimeRange(int startMinutes, int endMinutes) {
  final start = minutesToTimeOfDay(startMinutes);
  final end = minutesToTimeOfDay(endMinutes);
  return '${_formatTime(start)} – ${_formatTime(end)}';
}

String _formatTime(TimeOfDay t) {
  final suffix = t.hour < 12 ? 'am' : 'pm';
  final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  return t.minute == 0 ? '$hour$suffix' : '$hour:${t.minute.toString().padLeft(2, '0')}$suffix';
}
```

For the picker itself:
```dart
final result = await showTimePicker(
  context: context,
  initialTime: minutesToTimeOfDay(block.startMinutes),
);
if (result != null) {
  setState(() => _startMinutes = timeOfDayToMinutes(result));
}
```

**Source:** [showTimePicker Flutter API](https://api.flutter.dev/flutter/material/showTimePicker.html)

### Pattern 6: FilterChip for Day-of-Week Multi-Select

**What:** Seven `FilterChip` widgets in a horizontal `Row` or `Wrap`. `CommitmentBlock.daysOfWeek` stores ISO weekday integers (1=Monday … 7=Sunday).

```dart
// Day labels aligned to ISO 8601 weekday (1=Mon, 7=Sun)
const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const dayValues = [1, 2, 3, 4, 5, 6, 7]; // ISO weekdays

Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: List.generate(7, (i) => FilterChip(
    label: Text(dayLabels[i]),
    selected: selectedDays.contains(dayValues[i]),
    onSelected: (selected) {
      setState(() {
        selected
            ? selectedDays.add(dayValues[i])
            : selectedDays.remove(dayValues[i]);
      });
    },
  )),
)
```

### Pattern 7: Vertical Card Stack Type Picker

**What:** Three tappable cards in a `Column`, each with a title (plain-language description) and a subtitle. Selected card has highlighted border or background. This widget is shared between the onboarding screen and the Add Goal sheet — extract as `GoalTypePicker` widget that takes `selectedType` and `onTypeSelected` callback.

```dart
// lib/screens/goals/widgets/goal_type_picker.dart
class GoalTypePicker extends StatelessWidget {
  const GoalTypePicker({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final GoalType? selectedType;
  final ValueChanged<GoalType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TypeCard(
          goalType: GoalType.timeTarget,
          title: 'I want to spend regular time on something',
          subtitle: 'e.g. family, health, a hobby',
          icon: Icons.access_time_outlined,
          selected: selectedType == GoalType.timeTarget,
          onTap: () => onTypeSelected(GoalType.timeTarget),
        ),
        const SizedBox(height: 8),
        _TypeCard(
          goalType: GoalType.outcome,
          title: 'I\'m working toward a specific outcome',
          subtitle: 'e.g. finish a project, reach a goal',
          icon: Icons.flag_outlined,
          selected: selectedType == GoalType.outcome,
          onTap: () => onTypeSelected(GoalType.outcome),
        ),
        const SizedBox(height: 8),
        _TypeCard(
          goalType: GoalType.habit,
          title: 'I want to build a daily habit',
          subtitle: 'e.g. exercise, journaling, meditation',
          icon: Icons.repeat_outlined,
          selected: selectedType == GoalType.habit,
          onTap: () => onTypeSelected(GoalType.habit),
        ),
      ],
    );
  }
}
```

### Pattern 8: Onboarding with PageView (No Back Navigation, Programmatic Only)

**What:** `PageView` with `physics: const NeverScrollableScrollPhysics()` so only the "Next"/"Skip" buttons advance pages — no swipe back. A `PageController` drives page transitions. Step dots built from `AnimatedContainer`.

```dart
class OnboardingScreen extends StatefulWidget { ... }
class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  Goal? _firstGoal;
  CommitmentBlock? _firstBlock;

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _skip() {
    // Instant — no animation, no confirmation
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    // Save any goals/blocks created
    if (_firstGoal != null) {
      await context.read<GoalsNotifier>().saveGoal(_firstGoal!);
    }
    if (_firstBlock != null) {
      await context.read<CommitmentsNotifier>().saveBlock(_firstBlock!);
    }
    await context.read<SettingsNotifier>().setOnboardingComplete(true);
    // Router redirect fires automatically (SettingsNotifier notifies GoRouter)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(currentPage: _currentPage, totalPages: 3),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _Screen1(onNext: (goal) { _firstGoal = goal; _nextPage(); }),
                  _Screen2(onNext: (block) { _firstBlock = block; _nextPage(); }, onSkip: _nextPage),
                  _Screen3(onComplete: _completeOnboarding, onSkip: _completeOnboarding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step dots (no package needed):**
```dart
class _StepDots extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        width: i == currentPage ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: i == currentPage
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      )),
    );
  }
}
```

### Pattern 9: Goal Color — Auto-Generated Hex Palette

**What:** The model stores color as a hex String (e.g. `'#4CAF50'`). When a user creates a goal without picking a color, auto-assign from a curated palette by cycling through indices. Convert hex ↔ `Color` for rendering.

**Color palette (Claude's discretion — 8 visually distinct Material colors):**
```dart
const _goalColorPalette = [
  '#4CAF50', // Green
  '#2196F3', // Blue
  '#FF9800', // Orange
  '#9C27B0', // Purple
  '#F44336', // Red
  '#00BCD4', // Cyan
  '#FF5722', // Deep Orange
  '#607D8B', // Blue Grey
];

String autoColor(int existingGoalCount) =>
    _goalColorPalette[existingGoalCount % _goalColorPalette.length];
```

**Hex string → `Color` for rendering:**
```dart
Color hexToColor(String hex) {
  final sanitized = hex.replaceAll('#', '');
  return Color(int.parse('FF$sanitized', radix: 16));
}
```

**Source:** Standard Dart/Flutter hex color pattern (no external package needed).

### Pattern 10: Grouped Goals List with SliverList

**What:** Goals screen shows three sections with plain-language headers. Use `CustomScrollView` with `SliverToBoxAdapter` for each section header and `SliverList` for each group. This avoids nested scrolling issues that arise with `Column` inside `ListView`.

```dart
CustomScrollView(
  slivers: [
    if (goalsNotifier.timeTargetGoals.isNotEmpty) ...[
      SliverToBoxAdapter(child: _SectionHeader('Regular time')),
      SliverList(delegate: SliverChildBuilderDelegate(
        (context, i) => GoalCard(goal: goalsNotifier.timeTargetGoals[i]),
        childCount: goalsNotifier.timeTargetGoals.length,
      )),
    ],
    if (goalsNotifier.outcomeGoals.isNotEmpty) ...[
      SliverToBoxAdapter(child: _SectionHeader('Working toward')),
      SliverList(...),
    ],
    if (goalsNotifier.habitGoals.isNotEmpty) ...[
      SliverToBoxAdapter(child: _SectionHeader('Daily habits')),
      SliverList(...),
    ],
    if (/* all empty */ ...) SliverFillRemaining(child: _EmptyState()),
  ],
)
```

**Note on reorder within groups:** Each type group needs its own `ReorderableListView`. Since `ReorderableListView` does not compose naturally inside a `CustomScrollView` Sliver, use `ReorderableListView.builder` with `shrinkWrap: true` and disable the list's own scrolling (`physics: NeverScrollableScrollPhysics()`). The outer `CustomScrollView` handles scrolling.

### Anti-Patterns to Avoid

- **setState in goal/commitment screens:** The ROADMAP explicitly requires no setState in these screens. All state goes through Provider (GoalsNotifier, CommitmentsNotifier). Local form state within a bottom sheet (text field values, currently selected type, selected days) is acceptable as local StatefulWidget state — but persisting or loading data must go through the notifier.
- **Direct repository calls from screens:** Screens call `context.read<GoalsNotifier>().someMethod()`, never `HiveGoalRepository().save(goal)` directly. The notifier is the only entry point to persistence.
- **Showing GoalType enum labels in UI:** Never interpolate `goal.goalType.name` or `GoalType.timeTarget.toString()` into any displayed string. All displayed text uses plain-language equivalents.
- **Using pageView swipe to navigate onboarding:** Physics must be `NeverScrollableScrollPhysics()`. The back swipe gesture contradicts the "no back navigation during onboarding" decision.
- **Hard-deleting goals:** Archive only. `GoalRepository.delete` exists but must not be called from the UI in Phase 2. Archive sets `isArchived = true` and calls `repository.save()`.
- **Reusing @HiveField indices:** When expanding Goal, start new fields at index 4 (or the next unused index after reading the generated adapter). Reusing indices corrupts existing data.
- **Not bumping schemaVersion:** Adding new fields to Goal without bumping `currentSchemaVersion` means the migration runner won't record the schema change, making future migrations fragile. Bump to 2 with a no-op migration even though no data transformation is needed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Expandable bottom sheet | Custom Stack/Positioned overlay | `showModalBottomSheet` + `DraggableScrollableSheet` | Flutter handles safe area, barrier, focus, keyboard avoidance; DraggableScrollableSheet handles drag physics |
| Drag-to-reorder list | Custom gesture detection + animation | `ReorderableListView` + `ReorderableDelayedDragStartListener` | Flutter handles drag proxy, scroll during drag, and onReorder callback |
| Time picker | Custom hour/minute scroll wheels | `showTimePicker` | Flutter Material 3 time picker; handles 12/24 hour, input mode, localization |
| Page step dots animation | Full animation library | `AnimatedContainer` in a `Row` | 10 lines of code; `AnimatedContainer` handles width/color interpolation |
| Color hex parsing | Regex or manual bit math | `Color(int.parse('FF$hex', radix: 16))` | One expression; no package needed |

**Key insight:** The Flutter Material SDK covers all UI primitives needed for this phase. Resist the impulse to add pub.dev packages for things the SDK handles well. The zero-new-packages approach keeps the dependency graph flat and prevents version conflict risk.

---

## Common Pitfalls

### Pitfall 1: Adding Non-Nullable Hive Fields Without Defaults

**What goes wrong:** A new field `int sortOrder` (non-nullable) is added to `Goal`. Existing Goal records stored in Hive don't have this field. When the app reads old records, the TypeAdapter returns `0` for missing int fields (Hive's binary format stores 0 for missing numerics) — this is actually fine for int. But if a non-nullable field is a complex type or String, existing records crash on read.

**How to avoid:** New fields that are semantically optional should be typed as nullable (`String? color`, `double? weeklyHourBudget`). Fields that need a default (like `sortOrder`) should be primitives (int defaults to 0 in the binary reader for missing fields) or initialized via `??` in the getter. When in doubt, make the field nullable and handle null in the notifier.

**Warning signs:** `Null check operator used on a null value` crash on app launch on a device that has existing Goal data.

### Pitfall 2: DraggableScrollableSheet Scroll Conflict

**What goes wrong:** The form inside the bottom sheet doesn't scroll; only the sheet itself moves. Or vice versa — the sheet won't move to full-screen because the inner scroll view consumes all gestures.

**Why it happens:** The `ScrollController` provided by `DraggableScrollableSheet.builder` must be passed to the `SingleChildScrollView` (or `ListView`) inside. If you create a separate `ScrollController`, the two scroll views fight over gestures.

**How to avoid:** Always use the `scrollController` parameter from the builder callback as the `controller` for the inner scrollable widget. Never create a separate ScrollController inside GoalFormSheet.

**Warning signs:** Sheet opens but won't scroll content; or content scrolls but sheet won't expand to full-screen.

### Pitfall 3: ReorderableListView Inside CustomScrollView

**What goes wrong:** `ReorderableListView` inside a `CustomScrollView` Sliver throws layout errors or doesn't scroll correctly.

**Why it happens:** `ReorderableListView` has its own scroll handling. When embedded in an already-scrolling parent, the two scroll systems conflict.

**How to avoid:** Use `ReorderableListView.builder` with `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()`. Let the outer `CustomScrollView` handle all scrolling. Wrap the `ReorderableListView` in a `SliverToBoxAdapter`.

**Warning signs:** `RenderViewport does not support returning intrinsic dimensions` error; or layout overflow in debug mode.

### Pitfall 4: SettingsNotifier Not Wired to SharedPreferences

**What goes wrong:** `SettingsNotifier.setOnboardingComplete(true)` works in-memory (triggers router redirect) but the flag is not persisted. On app restart, onboarding shows again.

**Why it happens:** The Phase 1 `SettingsNotifier` stub has `_onboardingComplete = false` hardcoded — it was left as a stub to be wired to SharedPreferences in Phase 2.

**How to avoid:** In Phase 2, wire `SettingsNotifier` to either `SharedPreferences` (already a dependency) or the `AppSettings` Hive entity (typeId 6, already in the box). The `AppSettings` entity already has `onboardingComplete: bool`. Use it — read it in `SettingsNotifier`'s constructor/`init` method and write it in `setOnboardingComplete`.

**Warning signs:** Onboarding appears every app launch despite completing it; or the `onboardingComplete` value is always `false` after a hot restart (which clears memory).

### Pitfall 5: GoalType Enum Index Instability

**What goes wrong:** A developer reorders the `GoalType` enum values (e.g., puts `habit` first). All existing Goals read the wrong type because Hive stores the index integer (`0, 1, 2`), not the name.

**Why it happens:** The `STATE.md` decision "Enums stored as int index" means GoalType.values[0] must always be `timeTarget`, [1] always `outcome`, [2] always `habit`. Reordering the enum declaration changes the indices.

**How to avoid:** Treat the GoalType enum order as immutable. Add a comment: `// ORDER IS FIXED — stored as int index in Hive`. If a new type is ever needed, append it at the end.

**Warning signs:** Existing goals display in the wrong type section after a code change.

### Pitfall 6: Onboarding Router Redirect Race

**What goes wrong:** After `setOnboardingComplete(true)`, the router redirects before the save operations (goal, commitment block) complete. The new goal doesn't appear on the Goals screen.

**Why it happens:** `SettingsNotifier.setOnboardingComplete` calls `notifyListeners()` synchronously, which triggers go_router's `refreshListenable` and immediately re-evaluates the redirect. If the Hive save is still in progress, the Goals screen loads with stale data.

**How to avoid:** In `_completeOnboarding()`, await all save operations before calling `setOnboardingComplete`. Then call `goalsNotifier.loadGoals()` to refresh before the redirect fires — but since the Goals screen will load and call `loadGoals()` in its `initState`, this is handled automatically. The key is: call `setOnboardingComplete` last, after all saves are awaited.

```dart
Future<void> _completeOnboarding() async {
  if (_firstGoal != null) {
    await context.read<GoalsNotifier>().saveGoal(_firstGoal!);
  }
  if (_firstBlock != null) {
    await context.read<CommitmentsNotifier>().saveBlock(_firstBlock!);
  }
  // setOnboardingComplete triggers redirect — call last
  await context.read<SettingsNotifier>().setOnboardingComplete(true);
}
```

---

## Code Examples

### Goal Card with Colored Left Border and Type Icon

```dart
// lib/screens/goals/widgets/goal_card.dart
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.trailing});
  final Goal goal;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(goal.color ?? '#607D8B');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _openEditSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Colored left border
            Container(
              width: 5,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_typeIcon(goal.goalType), size: 16,
                            color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(goal.name,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        // Color swatch
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    if (_secondaryLine(goal) != null) ...[
                      const SizedBox(height: 2),
                      Text(_secondaryLine(goal)!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(GoalType type) => switch (type) {
    GoalType.timeTarget => Icons.access_time_outlined,
    GoalType.outcome    => Icons.flag_outlined,
    GoalType.habit      => Icons.repeat_outlined,
  };

  String? _secondaryLine(Goal g) {
    if (g.goalType == GoalType.timeTarget && g.weeklyHourBudget != null) {
      return '${g.weeklyHourBudget!.toStringAsFixed(1)} hrs/week';
    }
    if (g.goalType == GoalType.habit && g.streakCount > 0) {
      return '${g.streakCount}-day streak';
    }
    return null;
  }
}
```

### CommitmentsNotifier Pattern

```dart
// lib/providers/commitments_notifier.dart
class CommitmentsNotifier extends ChangeNotifier {
  final CommitmentBlockRepository _repository = HiveCommitmentBlockRepository();

  List<CommitmentBlock> _blocks = [];
  List<CommitmentBlock> get blocks => List.unmodifiable(_blocks);

  Future<void> loadBlocks() async {
    _blocks = await _repository.getAll();
    notifyListeners();
  }

  Future<void> saveBlock(CommitmentBlock block) async {
    await _repository.save(block);
    await loadBlocks();
  }

  Future<void> deleteBlock(String id) async {
    await _repository.delete(id);
    await loadBlocks();
  }
}
```

### Commitment Block Form — Day + Time Entry

```dart
// lib/screens/commitments/commitment_form_sheet.dart (key UI section)
// State fields:
String _name = '';
List<int> _selectedDays = [];
int _startMinutes = 540;  // 9:00am default
int _endMinutes = 1020;   // 5:00pm default
String _color = '#FF5722';

// Day chips
Wrap(
  spacing: 4,
  children: List.generate(7, (i) {
    final day = [1,2,3,4,5,6,7][i];
    final label = ['M','T','W','T','F','S','S'][i];
    return FilterChip(
      label: Text(label),
      selected: _selectedDays.contains(day),
      onSelected: (v) => setState(() =>
          v ? _selectedDays.add(day) : _selectedDays.remove(day)),
    );
  }),
)

// Time pickers
Row(children: [
  Expanded(child: OutlinedButton(
    onPressed: () async {
      final t = await showTimePicker(
        context: context,
        initialTime: minutesToTimeOfDay(_startMinutes),
      );
      if (t != null) setState(() => _startMinutes = timeOfDayToMinutes(t));
    },
    child: Text(formatMinutes(_startMinutes)),
  )),
  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
  Expanded(child: OutlinedButton(
    onPressed: () async {
      final t = await showTimePicker(
        context: context,
        initialTime: minutesToTimeOfDay(_endMinutes),
      );
      if (t != null) setState(() => _endMinutes = timeOfDayToMinutes(t));
    },
    child: Text(formatMinutes(_endMinutes)),
  )),
])
```

### Commitment Block Card Display

```dart
// "9am – 5pm · Mon–Fri" format
String formatDays(List<int> days) {
  const names = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
  // Compact range: Mon-Fri if consecutive
  final sorted = [...days]..sort();
  // For MVP: join with comma or show range
  return sorted.map((d) => names[d]).join('–');
}
```

### Migration Bump

```dart
// lib/data/database/migrations.dart
const int currentSchemaVersion = 2;  // bumped from 1

final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,  // add this
];

Future<void> _migration1to2() async {
  // Phase 2: Goal model gains new fields (color, priorityWeight, sortOrder,
  // weeklyHourBudget, deadline, outcomeDescription, frequencyPerWeek, streakCount).
  // hive_ce handles missing fields via null/default in the adapter — no data
  // transformation required. This migration records the schema version bump.
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Custom bottom sheet with Stack | `showModalBottomSheet` + `DraggableScrollableSheet` | Material 3 compliant; handles keyboard avoidance, barrier, safe area automatically |
| Long-press + custom gesture recognizer for drag | `ReorderableDelayedDragStartListener` | Built into Flutter SDK; no gesture conflict handling required |
| onboarding_flutter or intro_slider packages | `PageView` + `AnimatedContainer` dots | Zero dependency; same visual quality; full control over content |
| smooth_page_indicator package for dots | `AnimatedContainer` Row | Same visual effect; eliminates one dependency |
| Manual color int packing/unpacking | `Color(int.parse('FF$hex', radix: 16))` | One expression; standard Dart radix parsing |

---

## Open Questions

1. **SettingsNotifier SharedPreferences vs AppSettings Hive entity**
   - What we know: `AppSettings` Hive entity (typeId 6) has `onboardingComplete: bool`. `SettingsNotifier` currently holds `_onboardingComplete` in memory only.
   - What's unclear: Whether to wire `SettingsNotifier` to read/write `SharedPreferences` directly (simpler, already a dependency) or to read/write the `AppSettings` Hive box (keeps all persistence in Hive).
   - Recommendation: Use the `AppSettings` Hive entity since it already exists and is designed for this purpose. `SettingsNotifier` injects `HiveAppSettingsRepository` and loads on init. This keeps all persistence in one system. SharedPreferences is then only for the migration runner's `schemaVersion` key (already established in Phase 1).

2. **CommitmentBlock screen location in navigation**
   - What we know: The router has `/goals` in the bottom nav. Commitment blocks are a separate concept from goals but closely related.
   - What's unclear: Whether commitment blocks get their own bottom nav tab or live under the Goals screen (e.g., via a tab or overflow menu).
   - Recommendation: Phase 2 should put commitment blocks accessible from the Goals screen overflow menu ("Manage commitments") or as a second tab within the Goals screen. The Phase 3 schedule screen is the primary place users will observe commitment blocks in action. Adding a separate bottom nav tab for commitments adds nav complexity. Access via Goals screen overflow is lighter weight.

3. **Onboarding Screen 1 — goal type picker before or after naming the goal?**
   - What we know: Screen 1 asks "What's the one thing you most want to make time for?" and creates the first goal. The type picker (vertical card stack) must appear to let the user classify their answer.
   - What's unclear: Whether the name text field comes before or after the type picker. Leading with the open question ("What do you want to make time for?") then showing type picker is more conversational.
   - Recommendation: Name text field first ("What is it?"), then type picker ("How do you think about it?"). This matches the conversational tone specified in CONTEXT.md. The type picker reveals after the user starts typing (or is always visible — simpler to implement and avoids animation complexity).

---

## Sources

### Primary (HIGH confidence)

- [DraggableScrollableSheet Flutter API](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html) — parameters, snap behavior, scrollController requirement
- [ReorderableListView Flutter API](https://api.flutter.dev/flutter/material/ReorderableListView-class.html) — buildDefaultDragHandles, ReorderableDelayedDragStartListener
- [ReorderableDelayedDragStartListener Flutter API](https://api.flutter.dev/flutter/widgets/ReorderableDelayedDragStartListener-class.html) — long-press drag initiation
- [showTimePicker Flutter API](https://api.flutter.dev/flutter/material/showTimePicker.html) — TimeOfDay return type, Material 3 support
- [TimeOfDay Flutter API](https://api.flutter.dev/flutter/material/TimeOfDay-class.html) — hour/minute properties
- [Material 3 Bottom Sheets spec](https://m3.material.io/components/bottom-sheets/guidelines) — standard and modal sheet types
- Phase 1 codebase: `lib/data/models/goal.dart`, `lib/data/models/commitment_block.dart`, `lib/providers/goals_notifier.dart`, `lib/data/repositories/hive_goal_repository.dart`, `lib/router.dart`, `lib/data/database/hive_database.dart`, `lib/data/database/migrations.dart`

### Secondary (MEDIUM confidence)

- [smooth_page_indicator pub.dev](https://pub.dev/packages/smooth_page_indicator) — reviewed and deemed unnecessary; AnimatedContainer covers the use case
- WebSearch: "Flutter hive_ce add new fields existing entity backward compatibility" — confirmed nullable fields + new HiveField indices is the correct additive approach; missing fields default to null in existing records
- WebSearch: "Flutter ReorderableListView drag handles 2025" — confirmed ReorderableDelayedDragStartListener for long-press; buildDefaultDragHandles: false disables platform defaults
- WebSearch: "Flutter PageView onboarding 2025" — confirmed NeverScrollableScrollPhysics pattern for programmatic-only navigation; AnimatedContainer dot pattern

### Tertiary (LOW confidence)

- WebSearch: hive_ce GitHub issue #781 (isar/hive) — context about adapter behavior for missing fields; original hive package, not hive_ce specifically, but behavior is consistent

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already installed and verified in Phase 1; no new packages
- Architecture patterns: HIGH — all patterns use documented Flutter Material SDK APIs; verified against official docs
- Hive field expansion: HIGH — additive field pattern with nullable types is standard; migration runner pattern already established
- Onboarding PageView: HIGH — standard Flutter PageView with documented physics parameter
- Open questions: MEDIUM — recommendations are reasoned but need implementation-time confirmation

**Research date:** 2026-02-26
**Valid until:** 2026-03-28 (stable packages; Flutter SDK APIs are highly stable)
