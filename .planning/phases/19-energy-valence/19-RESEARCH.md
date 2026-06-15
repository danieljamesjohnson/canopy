# Phase 19: Energy Valence — Research

**Researched:** 2026-06-14
**Domain:** Flutter / Hive CE additive migration + Material 3 widget composition
**Confidence:** HIGH (all claims verified against actual codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Valence is a 3-value enum (gives / neutral / costs). Default neutral for existing goals.
- **Hive migration must be ADDITIVE and crash-safe**: new fields on the Goal adapter with new field indices; existing persisted goals load with valence=neutral and no emoji tag (no migration crash, no data loss).
- Goal form (create + edit) gets a gives/neutral/costs picker and an emoji tag picker.
- Valence + emoji render on the goal card (goals list) and on schedule chunks so the day reads restorative-vs-draining at a glance.
- Onboarding gains a "what gives you energy?" step that marks a couple of goals energy-giving before first schedule generation.
- Defer engine BEHAVIOR changes to Phase 20 (this phase is the valence MODEL + visibility + onboarding seed, not the scheduling logic).

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting (workflow.skip_discuss=true). Use ROADMAP phase goal, success criteria, and codebase conventions.

### Deferred Ideas (OUT OF SCOPE)
- Valence-aware scheduling BEHAVIOR (low days restorative, high days reserve a slot) → Phase 20 (VSCHED-01/02/03). This phase is model + visibility + onboarding seed only.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENERGY-01 | Goal carries energy valence (gives/neutral/costs), persisted via additive Hive migration; existing goals default to neutral | §Hive Migration Architecture + §Pitfall 1 |
| ENERGY-02 | User can set valence in the goal form on both create and edit | §Goal Form Integration |
| ENERGY-03 | User can attach an emoji tag to a goal; it persists and renders on the goal card | §Emoji Tag Storage + §Goal Card Changes |
| ENERGY-04 | Valence (and tag) visible where goals are listed and scheduled | §Goal Card Changes + §Chunk Card Changes |
| ONBOARD-01 | Onboarding includes "what gives you energy?" step seeding restorative goals before first use | §Onboarding Integration |
</phase_requirements>

---

## Summary

Phase 19 adds energy valence and emoji tags to the Goal model via a fully additive Hive CE migration, exposes them in the goal form and read-only display widgets, and inserts a new Screen 4 into onboarding. The Hive CE adapter pattern already used in this codebase handles additive fields correctly — the `read()` method in a generated adapter maps fields by integer key from a dict, so any key absent from an old record yields `null` from the map lookup. This is the exact pattern used by every prior migration (schema versions 1 through 7). The critical-path risk is real but well-mitigated by the existing infrastructure.

The schedule screen resolves goal data for chunks via in-screen `_lookup*` helper methods on `ScheduleScreen` that call `context.read<GoalsNotifier>().goals` and scan for `chunk.goalId`. The chunk → goal lookup for valence/emoji follows the identical pattern already used for color, name, and priority weight. Two new lookups (`_lookupGoalEmojiTag`, `_lookupGoalValence`) must be added alongside the existing four, and two new constructor props added to `ChunkCard` / `SwipeableChunkCard` / `_WorkChunkContent`.

The `EnergyValence` enum must NOT be a `@HiveType` — it is stored as an `int` index field on `Goal` (`energyValenceIndex`, HiveField 12). The getter `EnergyValence get energyValence => EnergyValence.values[energyValenceIndex ?? 0]` converts at read time. `neutral` at index 0 ensures old goals missing field 12 resolve correctly without any data transformation migration step. This is the exact same pattern used for `GoalType` (field 2, `goalTypeIndex`) and `ChunkType` (field 1, `chunkTypeIndex`).

**Primary recommendation:** Add `energyValenceIndex` (HiveField 12, `int?`, default 0) and `emojiTag` (HiveField 13, `String?`, default null) to `goal.dart`; regenerate the adapter; add migration entry `_migration7to8` (no-op body, same as every prior additive migration); bump `currentSchemaVersion` to 8; add two `_lookup*` methods on `ScheduleScreen` and two new props on `ChunkCard`/`SwipeableChunkCard`.

---

## Project Constraints (from CLAUDE.md)

| Directive | Implication for Phase 19 |
|-----------|--------------------------|
| Hive migrations are additive-only (never remove/rename fields) | New fields use new HiveField indices (12, 13); old fields untouched |
| UAT uses single-bundle debug web build (`flutter build web --debug --source-maps --pwa-strategy=none`) | Executor must use a fresh port; do not use `flutter run -d web-server` |
| State: Provider + ChangeNotifier for cross-screen; StatefulWidget + setState for local | Valence/emoji state in `_GoalFormSheetState`; no new notifier needed |
| `build_runner` is in dev_dependencies (`^2.4.13`) | Adapter regen required after adding `@HiveField` annotations |
| Regen command: `dart run build_runner build --delete-conflicting-outputs` | [VERIFIED: pubspec.yaml] |
| `flutter analyze` and `dart format lib/` before committing | Executor must run both |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Valence/emoji persistence | Data layer (Hive, `goal.dart` + `goal.g.dart`) | — | All goal data lives in the Hive goals box; no new box needed |
| Valence/emoji state in form | UI (StatefulWidget `_GoalFormSheetState`) | — | Local-only form state; follows existing priority/type pattern |
| Valence/emoji display on goal card | UI (`goal_card.dart`) | Data layer | File-private `_ValenceBadge` widget reads `goal.energyValence` directly |
| Valence/emoji display on chunk card | UI (`chunk_card.dart`) | Schedule screen | Props forwarded from `ScheduleScreen._lookup*` via `ChunkCard` constructor |
| Onboarding Screen 4 state | UI (`onboarding_screen.dart`, `_OnboardingScreenState`) | Notifier | `_screen4MarkedGoalIds` set in state; valence applied via `goalsNotifier.saveGoal` on complete |
| Chunk → goal data resolution | Schedule screen (`_lookup*` helpers) | `GoalsNotifier.goals` | Existing pattern; two new helpers added alongside existing four |

---

## Standard Stack

### Core (all verified against actual codebase)

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| `hive_ce` | ^2.19.3 | Typed persistent box for `Goal` | [VERIFIED: pubspec.yaml] |
| `hive_ce_flutter` | ^2.3.4 | Flutter adapter for Hive CE init | [VERIFIED: pubspec.yaml] |
| `hive_ce_generator` | ^1.11.1 | Code-gen for TypeAdapter from annotations | [VERIFIED: pubspec.yaml] |
| `build_runner` | ^2.4.13 | Drives `hive_ce_generator` | [VERIFIED: pubspec.yaml] |
| `provider` | ^6.1.5+1 | State management (`GoalsNotifier`) | [VERIFIED: pubspec.yaml] |
| Flutter Material 3 | SDK | `SegmentedButton`, `FilterChip`, `OutlinedButton` for valence picker + emoji affordance | [VERIFIED: CLAUDE.md] |

No new packages are required for this phase. All UI components use built-in Flutter Material 3 widgets.

### Adapter Regen Command

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run from project root after modifying `goal.dart` annotations. This replaces `goal.g.dart`. [VERIFIED: pubspec.yaml dev_dependencies]

---

## Package Legitimacy Audit

No new packages are installed in this phase. All tooling (hive_ce, hive_ce_generator, build_runner) is already in pubspec.yaml and was installed in prior phases.

**Packages removed due to SLOP verdict:** none
**Packages flagged as suspicious (SUS):** none

---

## Hive Migration Architecture

### How Hive CE Handles Missing Fields (the additive-safety mechanism)

[VERIFIED: lib/data/models/goal.g.dart, lib/data/models/scheduled_chunk.g.dart]

The generated `read()` method in `GoalAdapter` constructs a field dict keyed by `int`:

```dart
final numOfFields = reader.readByte();
final fields = <int, dynamic>{
  for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
};
```

When reading an old record that has 12 fields (HiveFields 0–11), `fields[12]` and `fields[13]` will be absent from the map. A Dart map lookup on a missing key returns `null`. The new constructor parameters (`energyValenceIndex`, `emojiTag`) will receive `null`, which is safe because:
- `energyValenceIndex` is `int?` with default `?? 0` in the getter — null → `EnergyValence.values[0]` = `EnergyValence.neutral`
- `emojiTag` is `String?` — null means no emoji tag

**This is identical to the pattern for all prior additive fields** (`streakCount` via `fields[11] == null ? 0 : ...`, `commitmentId` via `fields[9] as String?`, etc.). [VERIFIED: goal.g.dart, scheduled_chunk.g.dart]

### HiveField Index Registry (verified)

The Goal model currently uses HiveFields 0–11. [VERIFIED: lib/data/models/goal.dart]

| HiveField | Name | Type |
|-----------|------|------|
| 0 | id | String |
| 1 | name | String |
| 2 | goalTypeIndex | int |
| 3 | isArchived | bool |
| 4 | color | String? |
| 5 | priorityWeight | double? |
| 6 | sortOrder | int |
| 7 | weeklyHourBudget | double? |
| 8 | deadline | DateTime? |
| 9 | outcomeDescription | String? |
| 10 | frequencyPerWeek | int? |
| 11 | streakCount | int |
| **12** | **energyValenceIndex** | **int?** (NEW) |
| **13** | **emojiTag** | **String?** (NEW) |

Next free index after Phase 19: **14**. The UI-SPEC's guess of 12/13 is confirmed correct. [VERIFIED: goal.dart]

### TypeId Registry (no conflict)

| typeId | Adapter | File |
|--------|---------|------|
| 0 | GoalAdapter | goal.dart |
| 1 | CommitmentBlockAdapter | commitment_block.dart |
| 2 | DailyScheduleAdapter | daily_schedule.dart |
| 3 | ScheduledChunkAdapter | scheduled_chunk.dart |
| 4 | CompletionLogAdapter | completion_log.dart |
| 5 | QuarterlySnapshotAdapter | quarterly_snapshot.dart |
| 6 | AppSettingsAdapter | app_settings.dart |

`EnergyValence` enum must NOT be annotated with `@HiveType` — it is stored as an `int` index only. No new typeId is allocated. [VERIFIED: hive_database.dart + all model files]

### Schema Version Bump

Current `currentSchemaVersion` = 7. [VERIFIED: lib/data/database/migrations.dart]

Phase 19 must bump it to **8** and add `_migration7to8()` (no-op body) as index 7 in `_migrations`. The WR-06 assert (`_migrations.length == currentSchemaVersion`) will fail at startup in debug mode if the list length and constant don't match — this is an intentional correctness gate. [VERIFIED: migrations.dart]

---

## Architecture Patterns

### System Architecture Diagram

```
User taps "Add/Edit Goal"
         │
         ▼
GoalFormSheet (StatefulWidget)
  _energyValence: EnergyValence (local state)
  _emojiTag: String? (local state)
         │ on Save
         ▼
GoalsNotifier.saveGoal(goal)
         │
         ▼
HiveGoalRepository.save(goal)
  → Hive box<Goal>('goals').put(goal.id, goal)
  → GoalAdapter.write() serializes fields 0–13
         │
         ▼
         ┌─────────────────────────────────────────┐
         │ Goals Screen                             │
         │ GoalCard                                 │
         │   title row: emojiTag? + goal.name       │
         │   secondary row: _ValenceBadge (if ≠ neutral) │
         └─────────────────────────────────────────┘
         │
         ▼
         ┌─────────────────────────────────────────┐
         │ Schedule Screen                          │
         │ _lookupGoalValence(chunk) → EnergyValence│
         │ _lookupGoalEmojiTag(chunk) → String?     │
         │     ↓                                    │
         │ SwipeableChunkCard / ChunkCard           │
         │   _WorkChunkContent                      │
         │     title: emojiTag? + goalName          │
         │     _ValenceChip (if ≠ neutral)          │
         └─────────────────────────────────────────┘
         
Onboarding Screen 4 (new)
  _screen4MarkedGoalIds: Set<String>
  On _completeOnboarding():
    for each marked id → goal.energyValenceIndex = EnergyValence.gives.index
    → goalsNotifier.saveGoal(goal)
```

### Recommended Project Structure Changes

```
lib/data/models/
├── energy_valence.dart        # NEW — EnergyValence enum (plain Dart, no HiveType)
├── goal.dart                  # MODIFIED — add fields 12+13, add getter
├── goal.g.dart                # REGENERATED — via build_runner

lib/screens/goals/widgets/
├── goal_card.dart             # MODIFIED — _ValenceBadge, emoji in title row

lib/screens/schedule/widgets/
├── chunk_card.dart            # MODIFIED — _ValenceChip, emoji in title, new params

lib/screens/schedule/
├── schedule_screen.dart       # MODIFIED — 2 new _lookup* helpers, new props to SwipeableChunkCard

lib/screens/schedule/widgets/
├── swipeable_chunk_card.dart  # MODIFIED — 2 new constructor params forwarded to ChunkCard

lib/screens/goals/
├── goal_form_sheet.dart       # MODIFIED — valence picker, emoji picker, new state

lib/screens/onboarding/
├── onboarding_screen.dart     # MODIFIED — _Screen4, bump _StepDots to 4

lib/data/database/
├── migrations.dart            # MODIFIED — _migration7to8 + currentSchemaVersion=8
```

### Pattern 1: Additive HiveField (existing project pattern)

**What:** New nullable fields are added to a `@HiveType` class with a new `@HiveField(N)` index. Old records missing field N read as null. [VERIFIED: all migrations 1–7, goal.dart, scheduled_chunk.dart]

```dart
// In goal.dart — new fields appended after existing field 11
@HiveField(12)
int? energyValenceIndex; // null on old records → getter defaults to 0 (neutral)

@HiveField(13)
String? emojiTag; // null on old records → no tag shown

// Getter — never reads the raw int directly in UI code
EnergyValence get energyValence =>
    EnergyValence.values[energyValenceIndex ?? 0];
```

**When to use:** Every time a new persistent field is added to any Hive model.

### Pattern 2: Enum stored as int index (existing project pattern)

**What:** Enums are stored as their integer index, never as a string. A getter converts at read time. The enum ORDER IS FIXED and must never be reordered. [VERIFIED: goal.dart GoalType pattern, scheduled_chunk.dart ChunkType pattern]

```dart
// In lib/data/models/energy_valence.dart (new file)
// ORDER IS FIXED — stored as int index; never reorder enum values.
// neutral = 0 so missing HiveField(12) on old goals reads correctly.
enum EnergyValence { neutral, gives, costs }
```

**Critical:** `neutral` must be index 0 (first in enum declaration) so that `EnergyValence.values[null ?? 0]` = `EnergyValence.neutral`. [VERIFIED: matches existing pattern for GoalType.timeTarget at index 0]

### Pattern 3: Chunk → Goal property lookup (existing project pattern)

**What:** `ScheduleScreen` resolves goal properties for chunk display via private helper methods that read from `GoalsNotifier.goals` and scan by `chunk.goalId`. [VERIFIED: schedule_screen.dart _lookupGoalColor, _lookupGoalName, _lookupGoalPriorityWeight]

```dart
// In schedule_screen.dart — two new helpers following existing pattern
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

Props are then forwarded via `SwipeableChunkCard` (which passes through to `ChunkCard`) exactly as `goalPriorityWeight` and `goalName` are already forwarded. [VERIFIED: schedule_screen.dart + swipeable_chunk_card.dart]

### Pattern 4: File-private badge/chip widget (existing project pattern)

**What:** Display-only badge widgets are private to the file that contains them. The same visual widget is duplicated in `goal_card.dart` (`_PriorityChip`) and `chunk_card.dart` (`_PriorityChip`) rather than extracted to a shared widget. [VERIFIED: goal_card.dart + chunk_card.dart, UI-SPEC §Component Inventory item 4]

```dart
// File-private — in goal_card.dart
class _ValenceBadge extends StatelessWidget {
  const _ValenceBadge({required this.valence});
  final EnergyValence valence;
  @override
  Widget build(BuildContext context) { ... }
}

// File-private — in chunk_card.dart (visual duplicate, different class name)
class _ValenceChip extends StatelessWidget {
  const _ValenceChip({required this.valence});
  final EnergyValence valence;
  @override
  Widget build(BuildContext context) { ... }  // identical visual
}
```

### Pattern 5: Onboarding save flow (existing project pattern)

**What:** Onboarding state is held in `_OnboardingScreenState`. During `_completeOnboarding()`, goals created on Screens 1 and 3 are saved first, then `settingsNotifier.setOnboardingComplete(true)` is called last (triggering the router redirect). [VERIFIED: onboarding_screen.dart _completeOnboarding()]

Phase 19 inserts Step 4 between Screen 3's goal creation and `setOnboardingComplete`. The flow becomes:

```
Screen 3 onComplete → _screen3Habit = habit → _nextPage() (to Screen 4)
Screen 4 onComplete → apply EnergyValence.gives to _screen4MarkedGoalIds → _completeOnboarding()
Screen 4 onSkip    → _completeOnboarding() directly (no valence changes)
```

The `_isSaving` guard on `_completeOnboarding` prevents double-tap. Screen 4 inherits the same guard via `isSaving` prop.

### Anti-Patterns to Avoid

- **Annotating EnergyValence with @HiveType:** The enum has no registered adapter and must never be stored directly as a Hive object. Store as `int` index. Using `@HiveType` on a plain enum would require registering a new adapter in `hive_database.dart` (a new typeId) and is unnecessary complexity.
- **Storing EnergyValence as a String:** String storage breaks when enum values are renamed. The project convention is `int` index.
- **Modifying existing HiveField indices:** Reassigning indices to existing fields corrupts all persisted data. Only append new indices.
- **Calling _completeOnboarding() from Screen 3 when Screen 4 is added:** Screen 3's `onComplete` callback must call `_nextPage()` instead of `_completeOnboarding()` once Screen 4 is inserted. The current Screen 3 calls `_completeOnboarding()` directly — this must change.

---

## Goal Form Integration

### Existing Form State Fields (verified)

[VERIFIED: lib/screens/goals/goal_form_sheet.dart]

The form currently holds in `_GoalFormSheetState`:
- `GoalType? _selectedType`
- `TextEditingController _nameController`
- `TextEditingController _weeklyHoursController`
- `TextEditingController _descriptionController`
- `double? _priorityWeight`
- `double? _weeklyHourBudget`
- `DateTime? _deadline`
- `String? _outcomeDescription`
- `int? _frequencyPerWeek`

**Phase 19 adds:**
- `EnergyValence _energyValence = EnergyValence.neutral`
- `String? _emojiTag`

Both initialized in `initState()`:
- Edit mode: `_energyValence = goal.energyValence` (getter on Goal, never null), `_emojiTag = goal.emojiTag`
- Add mode: `_energyValence = EnergyValence.neutral`, `_emojiTag = null`

Both must be written in `_save()` via `goal..energyValenceIndex = _energyValence.index..emojiTag = _emojiTag`.

### Form Column Insertion Points

[VERIFIED: goal_form_sheet.dart build() Column children]

Current Column children order (relevant to insertion):
1. Drag handle (if !isDialog)
2. "Add/Edit Goal" title + SizedBox(12)
3. GoalTypePicker + SizedBox(12)
4. Goal name TextField + SizedBox(12)
5. **← INSERT: "Energy" label + SegmentedButton<EnergyValence> + SizedBox(8)**
6. **← INSERT: Emoji OutlinedButton + SizedBox(8)**
7. "Priority" label row
8. SegmentedButton<double> (priority) + SizedBox(16)
9. Type-specific fields
10. Archive button (edit mode)
11. Discard / Save row

The emoji picker uses `showAdaptiveFormModal` (already imported in goals_screen.dart) — but the emoji picker opened from within `GoalFormSheet` must use `showModalBottomSheet` / `showDialog` directly (not `showAdaptiveFormModal`) because `GoalFormSheet` itself is already inside a modal. The UI-SPEC calls for `showModalBottomSheet` (mobile) or `showDialog` (desktop) based on width — the existing `MediaQuery.of(context).size.width >= 720` check pattern from `adaptive_form_modal.dart` can be inlined.

---

## Chunk Card Changes

### Current ChunkCard Constructor Props (verified)

[VERIFIED: lib/screens/schedule/widgets/chunk_card.dart + swipeable_chunk_card.dart]

Both `ChunkCard` and `SwipeableChunkCard` currently accept:
- `chunk: ScheduledChunk` (required)
- `goalColor: Color?`
- `goalName: String?`
- `displayRationale: String?`
- `goalPriorityWeight: double?`
- `onTap: VoidCallback?`

**Phase 19 adds to both:**
- `goalEmojiTag: String?`
- `goalValence: EnergyValence?`

`SwipeableChunkCard` is a pass-through wrapper that forwards all props to `ChunkCard`. Both constructors must add the two new optional named parameters.

### Schedule Screen Callers (verified)

[VERIFIED: schedule_screen.dart _buildSwipeableCard() + _buildSkippedSection()]

Two sites call `ChunkCard` / `SwipeableChunkCard`:
1. `_buildSwipeableCard()` — creates `SwipeableChunkCard` (active chunks)
2. `_buildSkippedSection()` — creates `ChunkCard` directly (skipped chunks)

Both need the new `goalEmojiTag` and `goalValence` props added.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Emoji selection grid | Custom unicode picker | `GridView.count(crossAxisCount: 8)` with hardcoded 40-emoji list | Simple fixed set; no library needed per UI-SPEC |
| Adaptive sheet vs dialog | Custom routing logic | `showAdaptiveFormModal` pattern (inline `MediaQuery.size.width >= 720` check) | Already in codebase; consistent with Phase 18 |
| Hive enum storage | @HiveType on EnergyValence | `int` index field + getter | Existing project pattern for GoalType, ChunkType |
| Valence/emoji in chunk display | New field on ScheduledChunk | Lookup from GoalsNotifier at display time | Matches existing color/name/priority lookup pattern |

---

## Common Pitfalls

### Pitfall 1: Adapter regen writes old field count in `writeByte(N)` header

**What goes wrong:** After adding `@HiveField(12)` and `@HiveField(13)`, if build_runner is not re-run the old `goal.g.dart` with `writeByte(12)` (12 fields) is still in effect. New goals would be saved without the new fields. Old reads are fine; new saves are silently incomplete.

**Why it happens:** `goal.g.dart` is generated code. The source `goal.dart` can be modified but the generated file controls actual serialization until regenerated.

**How to avoid:** Run `dart run build_runner build --delete-conflicting-outputs` immediately after adding `@HiveField` annotations. Verify `goal.g.dart` shows `writeByte(14)` (14 fields) in the `write()` method.

**Warning signs:** `flutter analyze` will not catch this. Verify by inspecting `goal.g.dart` after regen.

### Pitfall 2: `neutral` not at index 0 in EnergyValence

**What goes wrong:** Old persisted goals with no `energyValenceIndex` field read `fields[12]` as `null`. The getter does `EnergyValence.values[null ?? 0]`, which is `EnergyValence.values[0]`. If `neutral` is not index 0, old goals load as the wrong valence (e.g. `gives` if it were placed first).

**Why it happens:** Dart enums are ordered by declaration; `values[0]` is the first declared value.

**How to avoid:** Declare `enum EnergyValence { neutral, gives, costs }` with `neutral` first. Comment `// neutral = 0 so missing HiveField reads correctly`. [VERIFIED: matches GoalType.timeTarget at index 0]

**Warning signs:** The migration safety test (test case 1 in Validation Architecture) catches this.

### Pitfall 3: Screen 3 onboarding still calling `_completeOnboarding()` directly

**What goes wrong:** Screen 3's `onComplete` callback currently calls `_completeOnboarding()` directly. After adding Screen 4, Screen 3's callback must call `_nextPage()` instead. If left unchanged, onboarding completes at Screen 3 and Screen 4 is never reached.

**Why it happens:** Screen 3 was the final screen; its CTA called the completion handler directly.

**How to avoid:** In `_OnboardingScreenState.build()`, change Screen 3's `onComplete` callback from calling `_completeOnboarding()` to calling `_nextPage()`. Also update `_StepDots(totalPages: 4)`. Screen 4's "Let's go" CTA then calls `_completeOnboarding()`.

**Warning signs:** `_currentPage` never reaches 3; the "Let's go" CTA on Screen 3 immediately closes onboarding.

### Pitfall 4: Emoji picker modal opened from inside a modal

**What goes wrong:** The emoji picker is opened from within `GoalFormSheet`, which itself runs inside a `Dialog` or `ModalBottomSheet`. Using `showAdaptiveFormModal` for the emoji picker would try to show a `Dialog` inside a `Dialog` — this works but can produce visual layering issues and the second dialog inherits the barrier incorrectly.

**Why it happens:** `showAdaptiveFormModal` is designed for top-level modal invocations from screen-level tap handlers.

**How to avoid:** For the emoji picker invoked from inside `GoalFormSheet`, use `showModalBottomSheet` (mobile) or `showDialog` (desktop) directly, with the width check inlined. The emoji picker is small (grid only) and does not need the full `DraggableScrollableSheet` treatment.

### Pitfall 5: `_isSaving` guard not propagated to Screen 4

**What goes wrong:** The `_isSaving` flag in `_OnboardingScreenState` prevents double-completion. Screen 3 accepts `isSaving` as a prop and disables its CTA while saving. Screen 4 must do the same — both "Let's go" and "Skip" must check `isSaving` before calling `_completeOnboarding()`.

**Why it happens:** New screen is added without consulting how the guard flows from parent state.

**How to avoid:** `_Screen4` must accept `isSaving: _isSaving` prop and disable both CTAs when saving.

### Pitfall 6: Schema version not bumped (or migration entry missing)

**What goes wrong:** The WR-06 assert in `migrations.dart` checks `_migrations.length == currentSchemaVersion` at startup. If `currentSchemaVersion` is bumped to 8 but the migration list stays at 7 entries (or vice versa), a `RangeError` is thrown at startup in debug mode.

**Why it happens:** Two separate edits in migrations.dart must be kept in sync: bump the constant AND add the migration function.

**How to avoid:** In `migrations.dart`, edit both `currentSchemaVersion = 8` and append `_migration7to8` (async no-op body) to `_migrations` in the same commit.

**Warning signs:** App crashes immediately on startup with `RangeError` in migrations.dart.

---

## Code Examples

### EnergyValence enum definition

```dart
// lib/data/models/energy_valence.dart (new file)
// ORDER IS FIXED — stored as int index in Goal.energyValenceIndex.
// neutral = 0 so goals persisted without this field read as neutral.
// Never reorder these values.
enum EnergyValence { neutral, gives, costs }
```

### Goal model additions

```dart
// In goal.dart — append after existing @HiveField(11) streakCount

// Phase 19: Energy valence. Stored as int index; getter converts.
// neutral = 0 so existing records without this field read correctly.
@HiveField(12)
int? energyValenceIndex;

// Phase 19: Optional emoji tag (single Unicode character). null = no tag.
@HiveField(13)
String? emojiTag;

EnergyValence get energyValence =>
    EnergyValence.values[energyValenceIndex ?? 0];
```

### Goal constructor additions

```dart
// In Goal() constructor — add optional named params
Goal({
  // ... existing params ...
  this.energyValenceIndex,
  this.emojiTag,
}) : id = id ?? _uuid.v4();
```

### Migration entry (no-op)

```dart
// In migrations.dart
const int currentSchemaVersion = 8;  // bumped from 7

// In _migrations list — append at index 7:
_migration7to8,

Future<void> _migration7to8() async {
  // Phase 19: Goal model gains energyValenceIndex (HiveField 12, int?, null)
  // and emojiTag (HiveField 13, String?, null). Both additive nullable fields —
  // Hive CE binary reader returns null for missing fields in existing records.
  // null energyValenceIndex → Goal.energyValence getter returns EnergyValence.neutral.
  // No data transformation needed.
}
```

### Valence color mapping (in _ValenceBadge / _ValenceChip)

```dart
// Pattern for both goal_card.dart and chunk_card.dart
(Color bg, Color fg, IconData icon, String label) _valenceStyle(
  BuildContext context,
  EnergyValence valence,
) {
  final cs = Theme.of(context).colorScheme;
  switch (valence) {
    case EnergyValence.gives:
      return (cs.tertiaryContainer, cs.onTertiaryContainer, Icons.bolt, 'Gives');
    case EnergyValence.costs:
      return (cs.secondaryContainer, cs.onSecondaryContainer, Icons.hourglass_empty, 'Costs');
    case EnergyValence.neutral:
      // Caller suppresses badge for neutral — this branch unreachable in practice
      return (cs.surfaceContainerHighest, cs.onSurfaceVariant, Icons.remove, '');
  }
}
```

### Chunk → goal lookup pattern for new fields

```dart
// In schedule_screen.dart — append after _lookupGoalPriorityWeight

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

---

## Onboarding Integration

### Current Screen Structure (verified)

[VERIFIED: lib/screens/onboarding/onboarding_screen.dart]

```
_OnboardingScreenState:
  PageController _controller
  int _currentPage
  GoalType? _screen1Type
  TextEditingController _screen1NameController
  CommitmentBlock? _screen2Block
  Goal? _screen3Habit
  bool _isSaving

build():
  _StepDots(currentPage, totalPages: 3)
  PageView(children: [_Screen1, _Screen2, _Screen3])

_completeOnboarding():
  (1) save Screen 1 goal if filled
  (2) save Screen 2 commitment if filled
  (3) save Screen 3 habit if filled
  (4) settingsNotifier.setOnboardingComplete(true)  ← always last
  (5) schedule morning notification
```

### Phase 19 Additions to _OnboardingScreenState

```
New state fields:
  Set<String> _screen4MarkedGoalIds = {}
  List<Goal> _screen4QuickGoals = []  // quick-added from Screen 4 inline field

Modified flow:
  Screen 3 onComplete → _screen3Habit = habit → _nextPage()  (was: _completeOnboarding)
  _StepDots(totalPages: 4)
  PageView(children: [_Screen1, _Screen2, _Screen3, _Screen4])

Screen 4 _completeWithValence():
  for each goal id in _screen4MarkedGoalIds:
    find goal in GoalsNotifier (or _screen4QuickGoals)
    goal.energyValenceIndex = EnergyValence.gives.index
    await goalsNotifier.saveGoal(goal)
  also save any _screen4QuickGoals not already saved
  await _completeOnboarding()

Screen 4 _skip():
  await _completeOnboarding()   // no valence changes
```

**Key constraint:** `_completeOnboarding()` saves goals in order: Screen 1, Screen 2 commitment, Screen 3 habit, then Screen 4 valence updates, then `setOnboardingComplete(true)`. The router redirect is gated on `onboardingComplete`, so it cannot fire until the final `setOnboardingComplete` call. [VERIFIED: onboarding_screen.dart]

### Screen 4 Goals List Source

Screen 4 shows goals to mark as energizing. The available goal pool at that point is:
- Screen 1 goal (if created) — saved to `GoalsNotifier` by `_completeOnboarding` step (1)
- Screen 3 habit (if created) — saved to `GoalsNotifier` by `_completeOnboarding` step (3)

**BUT:** `_completeOnboarding()` in the current flow saves goals. In Phase 19, Screen 4 runs BEFORE `_completeOnboarding()`. Goals from Screens 1 and 3 are NOT yet persisted when Screen 4 renders.

**Resolution:** Screen 4 must construct its display list from the parent state (not from `GoalsNotifier.goals`), because those goals haven't been saved yet. The `_OnboardingScreenState` must pass the Screen 1 goal object and Screen 3 habit object to `_Screen4` as constructor parameters so Screen 4 can display them without reading from Hive.

Alternatively, `_completeOnboarding` can be split: save Screens 1+3 goals first, then show Screen 4, then complete. Given the existing architecture where Screen 3's callback directly triggers `_completeOnboarding`, the cleanest approach is:

1. Screen 3's `onComplete` callback saves the habit immediately (not waiting for `_completeOnboarding`) then calls `_nextPage()`. Screen 1 goal is saved during `_completeOnboarding()` — but the name + type are available in `_screen1NameController` and `_screen1Type` state.

**Recommended approach:** Pass the pending goal objects (constructed in-memory, not yet saved) to Screen 4 as display-only items. Screen 4 stores marked IDs in `_screen4MarkedGoalIds`. During `_completeOnboarding()`, the existing steps (1)+(3) save the goals, then a new step (3.5) applies valence to the saved goals by re-fetching from the notifier.

This is the safest approach as it minimally restructures the existing flow.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hive (original) | Hive CE (community edition fork) | This project from start | `hive_ce` / `hive_ce_flutter` / `hive_ce_generator` are the packages; `package:hive` is NOT used |
| Direct Hive.box access in UI | Repository pattern (GoalRepository + HiveGoalRepository) | From start | UI code calls `GoalsNotifier`, not Hive directly |
| Shared badge widgets | File-private duplication (_PriorityChip in both goal_card.dart and chunk_card.dart) | Phase 14+ | UI-SPEC §4 documents this as intentional — follow it for _ValenceBadge/_ValenceChip |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The emoji picker inside GoalFormSheet should use inline showModalBottomSheet/showDialog rather than showAdaptiveFormModal | Goal Form Integration §Pitfall 4 | Low — either approach works; the main concern is nested dialog layering on desktop |
| A2 | Screen 4 displays goals from parent state (not yet persisted) rather than from GoalsNotifier.goals | Onboarding Integration | Medium — if Screen 1/3 goals are saved earlier, they'd be in GoalsNotifier; planner should verify the timing and choose the approach that minimizes flow restructuring |

---

## Open Questions

1. **Screen 4 goal source timing**
   - What we know: Goals from Screens 1 and 3 are saved inside `_completeOnboarding()`, which runs AFTER Screen 4
   - What's unclear: Should Screen 4 display goals from parent-state objects or should Screens 1/3 save earlier?
   - Recommendation: Pass pending goal objects (not yet saved) to Screen 4 as constructor params. `_completeOnboarding` then saves them (step 1+3) and applies valence (new step 3.5) before marking onboarding complete. This changes no existing timing.

2. **Quick-add goal in Screen 4 — save timing**
   - What we know: UI-SPEC specifies an inline quick-add flow on Screen 4; quick-added goal gets `energyValence: EnergyValence.gives` by default
   - What's unclear: Quick-added goals must also be saved during `_completeOnboarding()` — they go into a `_screen4QuickGoals` list and are saved in a new step between (3) and (4)
   - Recommendation: Add a `List<Goal> _screen4QuickGoals = []` state field; save them in step (3.5) alongside valence updates to marked goals.

---

## Environment Availability

No new external tools or services required. All build tools already in use:

| Dependency | Required By | Available | Version |
|------------|------------|-----------|---------|
| Flutter | All | ✓ | /home/dan/development/flutter/bin |
| dart run build_runner | Hive adapter regen | ✓ | ^2.4.13 (pubspec dev_deps) |
| hive_ce_generator | Adapter codegen | ✓ | ^1.11.1 (pubspec dev_deps) |

---

## Validation Architecture

`workflow.nyquist_validation` is absent from `.planning/config.json` → treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — standard `flutter test` runner |
| Quick run command | `flutter test test/data/ test/repositories/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENERGY-01a | Old Goal (no field 12/13) loads as EnergyValence.neutral, no crash | Persistence (Hive round-trip) | `flutter test test/data/migration_schema8_test.dart` | ❌ Wave 0 |
| ENERGY-01b | New Goal with energyValenceIndex persists across box close/reopen | Persistence (Hive round-trip) | `flutter test test/data/migration_schema8_test.dart` | ❌ Wave 0 |
| ENERGY-01c | currentSchemaVersion == 8 and _migrations.length == 8 (WR-06) | Unit | `flutter test test/data/migration_schema8_test.dart` | ❌ Wave 0 |
| ENERGY-02 | Valence picker renders in goal form; saves correctly | Widget | `flutter test test/screens/goal_form_valence_test.dart` | ❌ Wave 0 |
| ENERGY-03a | Emoji tag round-trips through save/reload | Persistence | `flutter test test/data/migration_schema8_test.dart` | ❌ Wave 0 |
| ENERGY-03b | Emoji renders on GoalCard title row when set | Widget | `flutter test test/screens/goal_card_valence_test.dart` | ❌ Wave 0 |
| ENERGY-04a | Valence badge renders on GoalCard for gives/costs; absent for neutral | Widget | `flutter test test/screens/goal_card_valence_test.dart` | ❌ Wave 0 |
| ENERGY-04b | Valence chip and emoji visible on ChunkCard when goal has valence/emoji | Widget | `flutter test test/screens/chunk_card_valence_test.dart` | ❌ Wave 0 |
| ONBOARD-01 | Marking a goal on Screen 4 and completing sets energyValence=gives | Widget | `flutter test test/screens/onboarding_screen4_test.dart` | ❌ Wave 0 |

### Critical Test: Migration Safety (ENERGY-01a)

This test is the most important. It must:
1. Write a `Goal` to Hive using the **old adapter** (12 fields, no HiveField 12/13)
2. Close the box
3. Reopen with the **new adapter** (14 fields)
4. Verify the loaded Goal has `energyValence == EnergyValence.neutral` and `emojiTag == null`
5. Verify no exception is thrown

Pattern: follow `test/data/migration_schema7_test.dart` which already tests the field-10 round-trip for ScheduledChunk using a temp dir and `Hive.init(tempDir.path)`. [VERIFIED: migration_schema7_test.dart]

### Sampling Rate

- **Per task commit:** `flutter test test/data/migration_schema8_test.dart` (migration safety)
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/data/migration_schema8_test.dart` — ENERGY-01 migration safety + round-trip tests
- [ ] `test/screens/goal_form_valence_test.dart` — ENERGY-02 valence picker widget test
- [ ] `test/screens/goal_card_valence_test.dart` — ENERGY-03b, ENERGY-04a badge/emoji on GoalCard
- [ ] `test/screens/chunk_card_valence_test.dart` — ENERGY-04b valence/emoji on ChunkCard
- [ ] `test/screens/onboarding_screen4_test.dart` — ONBOARD-01 Screen 4 completion sets valence

---

## Security Domain

`security_enforcement` not set in config → treat as enabled.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes (emoji tag) | `String?` stored as-is; single emoji character. No server submission — local-only Hive storage. Validate length/content in form: if provided, must be a single Unicode grapheme cluster. Reject multi-character strings. |
| V6 Cryptography | no | — |

**Emoji tag validation:** The `emojiTag` field is user-entered text stored locally in Hive. No injection risk (no server calls, no SQL). Validate in form save: `emojiTag?.characters.length == 1` using the `characters` package — but this package is not currently in pubspec. Since emoji are always selected from a fixed hardcoded grid (not free-text input), the value is always either `null` or one of 40 known emoji strings. Form validation can simply check `emojiTag == null || emojiTag!.isNotEmpty` without the characters package.

---

## Sources

### Primary (HIGH confidence — verified against actual codebase)

- `lib/data/models/goal.dart` — HiveField index registry (0–11), GoalType int-index pattern
- `lib/data/models/goal.g.dart` — Generated adapter: field-dict read pattern, writeByte(12) header
- `lib/data/database/migrations.dart` — currentSchemaVersion=7, WR-06 assert, all prior migration no-op pattern
- `lib/data/database/resilient_box.dart` — Crash recovery mechanism; how "incompatible data" is handled
- `lib/data/database/hive_database.dart` — TypeId registry (0–6), adapter registration order
- `lib/screens/onboarding/onboarding_screen.dart` — Screen 1/2/3 structure, _completeOnboarding flow
- `lib/screens/goals/goal_form_sheet.dart` — Existing state fields, _save() pattern
- `lib/screens/goals/widgets/goal_card.dart` — _PriorityChip file-private pattern, secondary row structure
- `lib/screens/schedule/widgets/chunk_card.dart` — _WorkChunkContent, _PriorityChip duplication pattern
- `lib/screens/schedule/schedule_screen.dart` — _lookup* helper pattern, chunk→goal resolution
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — Pass-through prop pattern
- `lib/widgets/adaptive_form_modal.dart` — Desktop/mobile modal routing, 720dp breakpoint
- `test/data/migration_schema7_test.dart` — Test pattern for Hive round-trip + schema version tests
- `test/data/resilient_box_test.dart` — Test pattern for box recovery
- `pubspec.yaml` — build_runner ^2.4.13, hive_ce_generator ^1.11.1 (adapter regen confirmed)
- `.planning/config.json` — nyquist_validation absent → enabled

### Secondary (MEDIUM confidence)

- `19-UI-SPEC.md` — Approved UI contract; data model section (HiveField 12/13 indices, enum order) confirmed against actual goal.dart

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against pubspec.yaml and actual source files
- Architecture: HIGH — all patterns verified against existing code
- Migration safety: HIGH — mechanism verified in goal.g.dart adapter + all 7 prior migrations
- Pitfalls: HIGH — all derived from actual code inspection, not speculation
- Onboarding Screen 4 timing: MEDIUM — A2 assumption; planner should resolve

**Research date:** 2026-06-14
**Valid until:** 2026-07-14 (stable codebase; no fast-moving external dependencies)
