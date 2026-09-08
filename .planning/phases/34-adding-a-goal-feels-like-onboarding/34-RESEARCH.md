# Phase 34: Adding a Goal Feels Like Onboarding - Research

**Researched:** 2026-09-08
**Domain:** Flutter/Material 3 widget extraction and reuse (in-repo) — no external libraries, no network, no LLM.
**Confidence:** HIGH — every claim below was verified by reading the actual source files in this repo this session; nothing here required web research per the task's own instruction.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Tapping a preset creates the goal immediately, with defaults: option (a).** Ruled 2026-09-08 after
the owner saw all three options built and clickable side by side in `sketches/006-adding-a-goal/`
(served on `http://danserver:8150/`). The on-file recommendation was (b) — open the form pre-filled —
and **he overrode it**. He did so with variant A's cost rendered on screen in a red callout:
`type=timeTarget`, `budget=3.0 hrs/week`, `priority=Normal`, labelled *"the defect deleted on
2026-09-08, re-opened."* This was informed, not incidental.

**Build (a). Do not build (b) and call it (a).** Concretely: if a plan finds itself adding a
confirmation step, a pre-create form, or any interruption between the chip tap and the goal existing,
it has drifted. One tap creates.

**The mitigation that makes (a) safe:** the failed property in the "help" defect was visibility, not
absence-of-defaults. So (a) ships with: (1) the created goal row states its weekly budget on its
face, (2) tapping the row opens the full form.

**GOALADD-03 was amended:** *"no add path creates a goal with attributes that are hidden from the
user"* (not "attributes the user did not choose" — that was unsatisfiable under (a)). The test that
proves it must find the budget as **text on the created row**, never assert `budget == 3.0`
symbolically.

**The preset list:** eight names unchanged from `_goalPresets`, each gaining an emoji:
🏃 Exercise · 📚 Reading · 👨‍👩‍👧 Family time · 💻 Side project · 🌱 Learn something · 🌲 Outdoors ·
🎨 Creative time · 😴 Rest. Onboarding shares this list and gains the emoji too — that is the point.

### Claude's Discretion

Widget naming, file placement of the extracted chip widget, and test structure are unconstrained —
follow codebase conventions and the patterns already present in the two implementations being merged.

### Deferred Ideas (OUT OF SCOPE)

- Revising the preset wording/emoji — deferred to the owner's first sight of it on screen.
- Item 5's restorative tap count (nine chips, thumb-hittability) — asked five times across Phases
  32-33, closed unmeasured. If this phase's shared chip widget changes restoratives' chip geometry,
  this unknown becomes live again and must be raised at UAT. **Verified this session (Decision 3 of
  the UI-SPEC and confirmed below): this phase explicitly preserves `_QuickPickSection`'s exact
  geometry for restoratives — the unknown does NOT reopen unless the shared widget's implementation
  diverges from that preservation.**

### From 34-UI-SPEC.md (APPROVED — treat as settled, not re-litigated)

The UI-SPEC is the buildable contract for everything the ruling itself didn't cover. Its five
numbered Component & Interaction Contract decisions are load-bearing for planning and are restated
in `## Architecture Patterns` below with source-verified detail, not just paraphrase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GOALADD-01 | Adding a goal starts from pre-chosen options, not a blank form | New `GoalPresetPickerSheet` (UI-SPEC) opens instead of `GoalFormSheet` when the fork's goal door is chosen — see Architecture Patterns, "The flow, end to end" and the exact call-chain in Component Contract §5 below |
| GOALADD-02 | Typing your own is as easy as tapping one | "Add your own" is a one-tap button (not a field) that opens `GoalFormSheet` — Decision 2 below, and the existing `_openAddSheet`/`showAdaptiveFormModal` call is reused unchanged |
| GOALADD-03 (amended) | No add path creates a goal with attributes hidden from the user | `GoalCard._secondaryLine` (verified below, `goal_card.dart:176-191`) already renders `weeklyHourBudget` for every `timeTarget` goal — no new widget needed, just get the emoji and budget onto the created `Goal` and into "Just added" |
</phase_requirements>

## Summary

This phase is pure reuse-and-extract: the exact interaction (tap a preset chip, get an entity
immediately, still type your own) already ships twice in this codebase — `_ChipCloud` in
`onboarding_screen.dart` and `_QuickPickSection` in `restoratives_screen.dart`. The Goals screen is
the one add-surface that has neither. The two existing implementations **disagree** on chip family
(split InputChip/ActionChip vs. single toggling FilterChip) and on what a second tap does
(no-op/hidden vs. delete); the UI-SPEC has already resolved both disagreements (Decision 3, verified
below) so the planner does not need to re-litigate them — it needs to build the merge exactly as
specified and account for the concrete test breakage that merge causes in **two** files, not one.

The one genuinely new piece of logic is getting the preset's emoji onto the created `Goal` object.
`GoalsNotifier.quickAddGoals` (verified, `goals_notifier.dart:70-105`) takes only
`Iterable<String> names` and never touches `emojiTag` — every goal it creates has `emojiTag == null`
today. This method (or a sibling) must be extended to accept and persist an emoji per name, or the
preset emoji becomes decoration on the chip that never reaches the model — exactly the failure mode
CONTEXT.md flags by name.

**Primary recommendation:** Extract one shared preset-chip widget from `_QuickPickSection`'s shape
(single `FilterChip` family, `mode` parameter distinguishing Goals'/onboarding's `createOnly`
behaviour from restoratives' unchanged `toggle` behaviour), wire it into a new
`GoalPresetPickerSheet` opened from `goals_screen.dart:_openAddSheet` in place of the direct
`GoalFormSheet` call, extend `GoalsNotifier` with an emoji-carrying create path, and update the two
test files whose assertions this changes (`goals_add_fork_test.dart` and, less obviously,
`onboarding_flow_test.dart` — see Common Pitfalls).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Preset chip rendering + tap handling | Widget layer (`lib/screens/.../widgets/`) | — | Pure presentation + local optimistic state; no business logic belongs here |
| "Which presets are claimed" (name matching) | Widget/screen layer, reading notifier state | Provider (`GoalsNotifier`/`RestorativesNotifier`) | The matching rule (`_matchFor`-style, case-insensitive trim) is a query over already-loaded in-memory state, not a repository concern |
| Goal creation with emoji + defaults | Provider (`GoalsNotifier`) | Data layer (`GoalRepository`) | `quickAddGoals`-style bulk/defaulted creation is exactly this notifier's existing responsibility; extending it (not duplicating it in the widget) keeps one source of defaults |
| Persistence | Data layer (`HiveGoalRepository` via `GoalRepository`) | — | Unchanged — this phase adds a parameter, not a new repository method |
| Navigation (fork → picker sheet → form) | Screen layer (`goals_screen.dart`) | — | `_openAddSheet`/`_openEditSheet` already own this; extend, do not parallel |

This phase has no server, no CDN, no browser-specific tier — it is 100% client-side Flutter state and
local Hive persistence, consistent with the rest of this codebase.

## Standard Stack

No new dependencies. This phase uses only Material 3 widgets already used elsewhere in this codebase:
`FilterChip`, `Wrap`, `Card`, `InkWell`, `ElevatedButton`/`FilledButton`, `TextButton` — confirmed by
the UI-SPEC's own Design System table and by reading the two source files. `pubspec.yaml` requires no
edits for this phase.

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages (native Flutter/Material 3 only, per
the UI-SPEC's own "Design System" table: `Tool: none`). No `pubspec.yaml` change is expected; if a
plan proposes adding one, that is itself a red flag for scope creep in this phase.

## Architecture Patterns

### The two existing implementations, read in full — signatures, state, and every divergence

**`_ChipCloud`** — `lib/screens/onboarding/onboarding_screen.dart:644-681`

```dart
class _ChipCloud extends StatelessWidget {
  const _ChipCloud({
    required this.added,
    required this.suggestions,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_Entry> added;            // _Entry(id, name, emoji) at :624
  final List<String> suggestions;      // plain names, no emoji carried through this widget
  final void Function(String name) onAdd;
  final void Function(String id) onRemove;
  // build(): a single Wrap(spacing:8, runSpacing:8) containing
  //   for added:      InputChip(avatar: Text(emoji)?, label, backgroundColor: secondaryContainer, onDeleted: () => onRemove(id))
  //   for suggestions: ActionChip(avatar: Icon(Icons.add, size:18), label, onPressed: () => onAdd(s))
}
```
- **Tracks "already added"** via `_suggestionsFor(presets, added)` (`:633-639`) — a free function
  that lowercases+trims both sides and filters presets already present, called fresh from the
  `Consumer<GoalsNotifier>` builder on every rebuild (no local `Set` state of its own).
- **Two visually distinct chip families in one `Wrap`**: `InputChip` (added, removable via built-in
  `onDeleted` × affordance) vs. `ActionChip` (suggestion, `+` avatar). Once a preset is added it
  moves from the ActionChip group to the InputChip group — it does **not** just vanish.
- **No selected/toggle state anywhere** — an added preset is never shown "selected"; there is no
  gesture that re-adds a removed one by tapping the same visual chip (removal only via the InputChip's
  × / `onDeleted`).
- Currently carries **no emoji into presets at all** — `_goalPresets` (`:138-147`) is `List<String>`,
  no emoji; `_restorativePresets` (`:149-158`) is likewise bare strings. Emoji only ever flows through
  when the preset came from `added` (an already-saved goal/restorative that happens to have an
  `emojiTag`), never from the preset list itself. **This confirms CONTEXT.md's plan to convert
  `_goalPresets` to `(name, emoji)` pairs is a real change to this list's shape, not a decoration.**

**`_QuickPickSection`** — `lib/screens/restoratives/restoratives_screen.dart:262-330`, list at `:18-28`

```dart
const List<(String name, String emoji)> kCommonRestoratives = [ /* 9 entries */ ];

class _QuickPickSection extends StatelessWidget {
  const _QuickPickSection({required this.notifier});
  final RestorativesNotifier notifier;

  RestorativeItem? _matchFor(String name) {           // :271-276
    final needle = name.trim().toLowerCase();
    return notifier.items.where((i) => i.name.trim().toLowerCase() == needle).firstOrNull;
  }

  // build(): Padding(16,12,16,8) > Column > Text('Common', titleSmall) + SizedBox(8)
  //   + Wrap(spacing:8, runSpacing:8) of _buildChip(name, emoji) for each of kCommonRestoratives

  Widget _buildChip(String name, String emoji) {       // :301-329
    final match = _matchFor(name);
    return FilterChip(
      avatar: Text(emoji),
      label: Text(name),
      selected: match != null,
      onSelected: (selected) {
        if (selected) {
          notifier.saveItem(RestorativeItem(name: name, emojiTag: emoji, sortOrder: notifier.items.length));
        } else if (match != null) {
          notifier.deleteItem(match.id);   // NO confirmation
        }
      },
    );
  }
}
```
- **Tracks "already added"** by re-deriving `_matchFor` **per chip, per build**, reading directly from
  `notifier.items` (no separate suggestions list, no local state) — a stateless, always-fresh query.
- **One chip family**: `FilterChip` for every preset, always with an emoji `avatar`. `selected` is
  literally `match != null` — the chip's own visual selected state IS the "already added" signal.
- **Re-tap behavior**: tapping an already-selected chip calls `notifier.deleteItem(match.id)` with
  **no confirmation dialog** — this is a real, silent-delete affordance for restoratives.
- Uses `saveItem`, explicitly **not** `notifier.quickAddItems` — the code comment (`:309-311`)
  states why: `quickAddItems` sets no emoji, so a chip-added item would fall back to the generic 🌿
  seen in `_RestorativeRow` (`:373`) instead of the chip's own emoji.

### Every divergence between the two, restated for the planner

| Axis | `_ChipCloud` (onboarding) | `_QuickPickSection` (restoratives) | UI-SPEC's resolution for the shared widget |
|---|---|---|---|
| Chip family | Two: `InputChip` (added) + `ActionChip` (suggestion) | One: `FilterChip`, toggled `selected` | **`FilterChip` only** — the `_QuickPickSection` shape wins (Decision 3, Axis A) |
| Avatar | `Text(emoji)` only if entry has one; suggestions get a generic `Icons.add` | Always `Text(emoji)` | Always emoji avatar, no generic `+` |
| "Already added" tracking | Filter suggestions list against `added`, recomputed from `Consumer` state | `_matchFor` query per chip per build | Same idea, generalized to read `GoalsNotifier.goals` for the goals surface (Decision 5) |
| Re-tap on already-added preset | Not possible — no gesture exists (removal is via InputChip's ×) | Deletes with **no confirmation** | **Goals/onboarding use `createOnly`: the chip is hidden entirely once claimed — no delete-by-retap.** Restoratives keeps `toggle` unchanged. (Decision 3, Axis B) |
| Emoji in the preset list itself | None today (`_goalPresets`/`_restorativePresets` are bare `List<String>`) | Yes, `(name, emoji)` tuples from day one | `kCommonGoals` becomes `(name, emoji)`, mirroring `kCommonRestoratives`'s shape exactly |
| Create call | `onAdd(name)` → caller's `quickAddGoals([name])` / `quickAddItems([name])` (bulk helper, no emoji) | `notifier.saveItem(RestorativeItem(...emojiTag: emoji...))` (single-item, carries emoji) | Goals path needs a **new** emoji-carrying creation call — `quickAddGoals` cannot be reused as-is (see next section) |

**Verified consequence for onboarding, not previously called out:** because the shared widget follows
`_QuickPickSection`'s single-`FilterChip` shape (UI-SPEC Decision 3), `_ChipCloud`'s two call sites —
`_GoalsBeat` (`:196-201`) and `_RestorativesBeat` (`:264-269`) — change chip family too, not just the
Goals screen. This is stated in the UI-SPEC ("Visible change: onboarding's `_ChipCloud` usages...
visibly change from the two-tier Input/Action split to the single-row `FilterChip` grid"), and it has
a **direct, verified test consequence** — see Common Pitfalls below.

### `GoalsNotifier.quickAddGoals` — exact signature, defaults, and the emoji gap

Verified at `lib/providers/goals_notifier.dart:70-105`:

```dart
Future<int> quickAddGoals(Iterable<String> names) async {
  final cleaned = names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
  if (cleaned.isEmpty) return 0;
  final startCount = _goals.length;
  var nextSort = _goals.isEmpty ? 0 : _goals.map((g) => g.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  var saved = 0;
  for (var i = 0; i < cleaned.length; i++) {
    final goal = Goal(
      name: cleaned[i],
      goalTypeIndex: GoalType.timeTarget.index,      // GoalType.timeTarget.index == 0 (goal.dart:27)
      color: _colorPalette[(startCount + i) % _colorPalette.length],
      weeklyHourBudget: 3.0,
      sortOrder: nextSort++,
    );
    try { await _repository.save(goal); saved++; } catch (_) { break; }
  }
  await loadGoals();
  return saved;
}
```

**Confirmed: this method never sets `emojiTag`.** `Goal`'s constructor (`lib/data/models/goal.dart:31-45`)
defaults `emojiTag` to `null` when not passed, and `quickAddGoals` never passes it. Every goal this
method creates today has `emojiTag == null`. `priorityWeight` is also never set → stays `null`, which
`GoalCard`/scheduling code elsewhere treats as "Normal" (0.5) — confirmed at
`goal_form_sheet.dart:327`: `ButtonSegment(value: 0.5, label: Text('Normal'))`. This matches the
sketch's stated defaults exactly: `type=timeTarget`, `budget=3.0 hrs/week`, `priority=Normal` (=
`priorityWeight: null`).

**What a minimal emoji-carrying path needs:** `quickAddGoals(Iterable<String> names)` takes only
names — there is no parallel-array or tuple-list overload. Two viable shapes, either satisfies the
requirement:
1. Change the parameter to `Iterable<(String name, String? emoji)>` (or a similar pair type) and set
   `emojiTag: emoji` on the constructed `Goal` inside the existing loop — minimal diff, but changes
   the signature every existing call site uses (`_GoalsBeat` at `onboarding_screen.dart:199`,
   `_RestorativesBeat`'s goal-side equivalent does not apply — restoratives don't call this — and any
   test calling `goals.quickAddGoals([...])` with bare strings).
2. Add a **new** method (e.g. `createGoalFromPreset(String name, {String? emoji})`) that creates one
   goal at a time with the same defaults plus `emojiTag`, leaving `quickAddGoals` untouched for its
   existing bulk/no-emoji callers (`_GoalsBeat`'s onboarding flow, which has no emoji in
   `_goalPresets` today either — though CONTEXT.md's plan converts that list to carry emoji too, so
   onboarding likely wants the emoji-carrying path as well).

Given CONTEXT.md's explicit statement that "Onboarding shares this list and therefore gains the
emoji too — that is the point, not a side effect," **the emoji-carrying path is needed by both
surfaces**, which favors option 1 (widen `quickAddGoals` itself) over adding a parallel method,
since onboarding's `_GoalsBeat.onAdd` callback (`onboarding_screen.dart:199`,
`(name) => goalsNotifier.quickAddGoals([name])`) will also need to pass an emoji once `_goalPresets`
carries one. **This is a planning decision, not a settled fact** — CONTEXT.md leaves "Claude's
discretion" open on implementation shape; flagging both options here rather than picking one.

**Regression-test note carried forward from CONTEXT.md, re-verified against the actual code:**
`quickAddGoals`'s existing doc comment (`:59-69`) already states "Returns the count actually added"
and reports a failure by breaking the loop rather than throwing — any test of the emoji path should
follow this same honest-partial-count contract, not assume all-or-nothing.

### `GoalCard._secondaryLine` — the UI-SPEC's claim VERIFIED TRUE

Verified at `lib/screens/goals/widgets/goal_card.dart:176-191`:

```dart
String? _secondaryLine(Goal g) {
  switch (g.goalType) {
    case GoalType.timeTarget:
      if (g.weeklyHourBudget != null) {
        return '${g.weeklyHourBudget!.toStringAsFixed(1)} hrs/week';
      }
      return null;
    case GoalType.habit:
      if (g.streakCount > 0) {
        return '${g.streakCount}-day streak';
      }
      return null;
    case GoalType.outcome:
      return null;
  }
}
```

**The UI-SPEC's claim holds exactly.** Called at `:202` (`final secondary = _secondaryLine(goal);`)
and rendered at `:326-329`:
```dart
if (secondary != null) ...[
  const SizedBox(height: 4),
  Text(secondary, style: theme.textTheme.bodySmall),
],
```
— directly below the name row, above the type/valence chip `Wrap`, at `bodySmall`, no color override
(inherits the theme default). Since every preset-created `Goal` is `GoalType.timeTarget` with
`weeklyHourBudget: 3.0` (per `quickAddGoals`'s current defaults, unchanged by this phase), this line
**always renders** — `'3.0 hrs/week'` verbatim — for a freshly created preset goal. **No new widget
work is needed for GOALADD-03's mitigation; `GoalCard` already does the right thing once the created
`Goal` has the right `goalType`/`weeklyHourBudget` (which it already does — the missing piece is only
`emojiTag`, not the budget line).**

**What renders for a goal type with no weekly budget** (verified, not exercised by this phase but
relevant to the "hidden attribute" contract): `GoalType.outcome` → `_secondaryLine` returns `null` →
the `if (secondary != null)` block is skipped entirely, no secondary line at all. The card's left
progress track (`_ProgressLine`, `:503-553`) separately renders an **empty grey track** for a `null`
`weekProgress` (Phase 33's locked rule, item 16) — never red. This case does not occur for any of the
8 presets (all default to `timeTarget` + budget), but the UI-SPEC is correct that if a future preset
defaulted to `outcome`, `_secondaryLine` returning `null` would silently satisfy the compiler while
violating GOALADD-03 in spirit — worth a one-line comment if a future change touches preset defaults,
not a blocker for this phase.

### `add_kind_fork.dart` / `goals_screen.dart` — the exact call chain, verified end to end

`_DoorTile` shape (used for "Something to make time for" / "Something that restores you", and the
model for the UI-SPEC's "Add your own" row) — `add_kind_fork.dart:204-262`: a `Card` +
`InkWell(onTap)` + `Row(Icon(icon, color: primary), SizedBox(12), Column(title, consequence))`.

`showAddKindFork(BuildContext)` — `add_kind_fork.dart:41-82`: `showDialog<AddKind>` returning
`AddKind.goal` or `AddKind.restorative` or `null` (dismissed/cancelled).

**Current chain**, `goals_screen.dart:127-143`:
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
**This is the one place to change.** The `kind == AddKind.goal` branch (the `if (!context.mounted) …
showAdaptiveFormModal(… GoalFormSheet …)` tail) is what must instead open `GoalPresetPickerSheet` via
the same `showAdaptiveFormModal` call (same bottom-sheet/dialog chrome, same 720dp breakpoint — this
is literally the same call with a different `builder`). `GoalFormSheet` becomes reachable only from
inside that new sheet (via "Add your own" or tapping a "Just added" row), not from `_openAddSheet`
directly.

`_openEditSheet(context, Goal goal)` — `goals_screen.dart:147-157`: unchanged by this phase, confirmed
— it calls `showAdaptiveFormModal` with `GoalFormSheet(..., goal: goal, ...)` directly, no fork. UI-SPEC
step 7 ("tapping a row in 'Just added' pops this sheet and opens `GoalFormSheet` in edit mode ...
reusing `_openEditSheet`'s existing call") is achievable by literally calling this existing method —
verified it takes exactly `(BuildContext, Goal)` and does exactly what's needed, no changes required
to this method itself.

`showAdaptiveFormModal` — `lib/widgets/adaptive_form_modal.dart:17-53`: takes
`{required BuildContext context, required Widget Function(ScrollController) builder}`, picks
`Dialog` (≥720dp) vs `showModalBottomSheet` + `DraggableScrollableSheet` (<720dp) purely from
`MediaQuery.of(context).size.width`. **No changes needed to this widget** — `GoalPresetPickerSheet`
just needs to be a `Widget Function(ScrollController)`-shaped builder like `GoalFormSheet` already is,
and it inherits the same chrome for free.

### Recommended file placement (discretion area — a suggestion, not a requirement)

Following this codebase's existing pattern (`lib/screens/goals/widgets/`, `lib/screens/goals/widgets/add_kind_fork.dart`):
```
lib/screens/goals/widgets/
├── add_kind_fork.dart          # existing — unchanged except the goal-door call site in goals_screen.dart
├── goal_preset_picker_sheet.dart   # NEW — GoalPresetPickerSheet, kCommonGoals
└── goal_card.dart              # existing — unchanged
lib/widgets/
└── preset_chip_grid.dart       # NEW (or similar name) — the shared chip widget, since it's used by
                                  #   both lib/screens/goals/ and lib/screens/restoratives/ and
                                  #   lib/screens/onboarding/ — none of those three should own it
```
`kCommonGoals` living beside `GoalPresetPickerSheet` mirrors `kCommonRestoratives` living beside
`_QuickPickSection` in the same file — the established precedent.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Case-insensitive "is this preset already a goal" check | A new matching helper from scratch | The `_matchFor`/`_suggestionsFor` idiom (trim + lowercase, `.where(...).firstOrNull`) already used twice in this codebase | Two independent implementations of the same one-line rule already exist and agree; a third would be the thing CLAUDE.md's "dumb app" ethos and this codebase's own extraction charter both argue against |
| Bottom-sheet/dialog responsive chrome | A new modal wrapper | `showAdaptiveFormModal` (unchanged, just given a new `builder`) | Already handles the 720dp breakpoint, `ScrollController` lifecycle (a documented past bug, WR-01), and safe-area — reinventing it risks reintroducing the disposed-controller bug it fixes |
| "Show budget on the created row" | A new summary widget | `GoalCard` as-is (verified above) | `_secondaryLine` already renders exactly this string for exactly this goal shape |

**Key insight:** every piece of machinery this phase needs already exists somewhere in this repo,
built and tested. The actual net-new code is: (1) the shared chip widget's `mode` parameter, (2) the
new `GoalPresetPickerSheet` composing existing pieces, (3) the emoji-plumbing change to
`GoalsNotifier`. Anything larger than that is scope creep.

## Common Pitfalls

### Pitfall 1: Fixing `goals_add_fork_test.dart` and believing the job is done
**What goes wrong:** `goals_add_fork_test.dart` has the obviously-affected assertions; a planner might
update only that file and consider testing done.
**Why it happens:** UI-SPEC's own "Known test impact" section only names `goals_add_fork_test.dart`.
**How to avoid:** Also update `test/screens/onboarding_flow_test.dart` — verified below.
**Warning signs:** `flutter test` failing on `ActionChip` lookups after the shared widget ships.

**Exact breakage, verified by reading both files this session:**

In `test/screens/goals_add_fork_test.dart`:
- **Line 163-172**, `'the goal door opens the goal form'`: taps `_goalDoor`, then asserts
  `find.byType(GoalFormSheet), findsOneWidget` immediately. **Will fail** — the goal door now opens
  `GoalPresetPickerSheet` first. Needs repointing to either assert `GoalPresetPickerSheet` appears, or
  to additionally tap "Add your own" before finding `GoalFormSheet`.
- **Line 260-278**, `'on a phone both doors and both consequence lines still fit'`: taps `_goalDoor`
  then immediately asserts `find.byType(GoalFormSheet), findsOneWidget`. **Will fail** for the same
  reason — and this test's actual point (overflow-free layout on a 390×844 viewport) should probably
  be re-pointed at `GoalPresetPickerSheet`'s own layout, or split into a new test for the picker sheet.
- **NOT affected** (verified, listed so the planner doesn't waste time on them): line 135-145 (single
  add path — asserts `TextField`/`FloatingActionButton` absence, unrelated to what the goal door
  opens), line 147-161 (fork shows both doors — unaffected, `GoalFormSheet` absence check still holds
  since it now takes an *extra* step to reach), line 174-218 (restorative door — untouched surface),
  line 220-233 (cancelling the fork — untouched), line 235-258 (`_openEditSheet` — untouched, verified
  above).

In `test/screens/onboarding_flow_test.dart` (**this breakage is NOT mentioned anywhere in the
UI-SPEC or CONTEXT.md — found by tracing UI-SPEC Decision 3 through to its test consequences**):
- **Line 163-178**, `'tapping a preset chip adds that goal'`: `find.widgetWithText(ActionChip,
  'Reading')`. **Will fail** once `_ChipCloud`'s goals-beat usage moves to the shared
  `FilterChip`-based widget (UI-SPEC Decision 3, Axis A, explicitly says onboarding's goals beat
  "visibly changes from the two-tier Input/Action split to the single-row `FilterChip` grid").
- **Line 440-478** (the large-text-scale reachability test): `find.widgetWithText(ActionChip,
  'Reading')` at line 467. **Will fail** for the identical reason.
- **No `InputChip` references exist in this test file** (verified via grep) — so the "added" side of
  `_ChipCloud`'s old two-family split has no direct test coverage to break, but the suggestion-chip
  (`ActionChip`) side does, twice.

### Pitfall 2: A test asserting `goal.weeklyHourBudget == 3.0` instead of finding the text
**What goes wrong:** exactly the shape CLAUDE.md's "Assertions that cannot fail" section warns about
— `kBreakHitSlop` (Phase 31) and the progress-track constants (Phase 33) were both bitten by this.
**Why it happens:** it's the easier assertion to write, and it does exercise the real code path today.
**How to avoid:** the regression test for GOALADD-03's mitigation must do what
`restoratives_quick_pick_test.dart` already does for the analogous restoratives case (verified
pattern, see Code Examples) — find the literal rendered string (`'3.0 hrs/week'`) scoped to the
created row's `Card`/`GoalCard`, not read the constant back off the model.
**Warning signs:** a test that would still pass if `GoalCard._secondaryLine`'s render call were
deleted and the string were hardcoded elsewhere — or one that would still pass if the emoji-plumbing
fix were never made.

### Pitfall 3: `find.byType(FilterChip)` after the shared widget ships, without disambiguating surfaces
**What goes wrong:** once Goals, restoratives, and onboarding's two beats all render `FilterChip`
grids from the same shared widget, a bare `find.byType(FilterChip)` inside a screen that also has
other `FilterChip`s (e.g. the onboarding job beat's day-of-week `FilterChip`s at
`onboarding_screen.dart:522-539`) will over-count.
**Why it happens:** CLAUDE.md already flags that `find.byType(X)` doesn't discriminate subtypes; the
sibling risk here is a widget *type* used for two different purposes on the same screen.
**How to avoid:** scope with `find.widgetWithText(FilterChip, 'name')` (the idiom
`restoratives_quick_pick_test.dart:55` already establishes: `Finder _chip(String name) =>
find.widgetWithText(FilterChip, name);`), not a bare type finder — verified this idiom already exists
and already handles this correctly for the one screen (`_JobBeat`) that currently mixes `FilterChip`
uses.
**Warning signs:** a chip-count assertion (`findsNWidgets(8)`) that would also pass if the day-of-week
row were somehow rendered on the same screen.

### Pitfall 4: The double-tap race (Decision 4) being "fixed" with `pumpAndSettle`
**What goes wrong:** a test using `await tester.pumpAndSettle()` immediately after the tap cannot
observe a race that only exists for the single frame between the tap and the async save resolving.
**Why it happens:** `pumpAndSettle` is the default idiom in every existing test in this codebase
(`restoratives_quick_pick_test.dart`, `goals_add_fork_test.dart` both use it almost exclusively) —
copying that habit here defeats the exact thing being tested.
**How to avoid:** CONTEXT.md/UI-SPEC Decision 4 is explicit: "tap once, pump exactly one frame (not
`pumpAndSettle`), and assert the tapped chip is already gone before the future completes." Use
`await tester.tap(...)` then `await tester.pump()` (single frame, no settle) before the assertion.
**Warning signs:** a "no double-create" test that passes even when the chip's removal is wired to wait
for `loadGoals()` to complete (i.e., it would pass against the very bug it's meant to catch) — this is
a mutation-testing case worth running deliberately per CLAUDE.md's standing instruction.

## Code Examples

### The exact restoratives test idiom to copy for the new goal-preset chip tests

```dart
// Source: test/screens/restoratives_quick_pick_test.dart:55, :72-85, :112-131
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
This is the shape a goal-preset-chip test should follow — pump the screen/sheet over an in-memory
repository, tap by label (not by type alone), assert both the notifier state (`goals.goals.single.
emojiTag`) and the rendered text (`'3.0 hrs/week'` on the created row), exactly as
`restoratives_quick_pick_test.dart` does for `emojiTag` and as Pitfall 2 above requires for the budget
line.

### Existing in-memory repository harness for Goals (already exists, reuse directly)

```dart
// Source: test/screens/goals_add_fork_test.dart:37-55
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
  Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}
```
No new repository fake is needed for this phase's tests — this one, or the project's existing
`in_memory_completion_log_repository.dart`/`in_memory_restorative_item_repository.dart` (both already
imported by `goals_add_fork_test.dart`), cover everything the new sheet's tests need.

## State of the Art

Not applicable in the usual sense (no external library versioning). The one in-repo "old → new"
worth recording:

| Old Approach | Current/New Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Goals screen: bare `QuickAddField` at top of list, created goals with an un-chosen `3.0 hrs/week` budget | Guided fork → (this phase) preset picker sheet, `QuickAddField` deleted from Goals screen entirely | Commit `1587fff`, 2026-09-08 | This phase must NOT reintroduce a `TextField`/`QuickAddField` anywhere in the new flow — UI-SPEC Decision 2 is explicit that "Add your own" is a button, not a field, precisely because that field's shape was the defect |
| `_ChipCloud`'s InputChip/ActionChip split (onboarding, restoratives via `_restorativePresets`) | Restoratives already migrated to single-`FilterChip` `_QuickPickSection` (Phase 33) | Phase 33, 2026-09-01/08 | This phase extends that migration to Goals and (per UI-SPEC Decision 3) to onboarding's remaining `_ChipCloud` usages too |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Widening `quickAddGoals`'s signature (option 1) is preferable to adding a parallel emoji-carrying method (option 2) | Architecture Patterns, `quickAddGoals` section | Low — both are correct per CONTEXT.md's discretion clause; this is a recommendation, not a locked decision, and either satisfies GOALADD-03 |
| A2 | The new shared chip widget should live in `lib/widgets/` rather than duplicated per-screen | Architecture Patterns, file placement | Low — CONTEXT.md explicitly grants discretion here; stated as a suggestion following the "extract, don't triplicate" instruction, not asserted as required |

**All other claims in this research were verified this session by reading the cited source file and
line range** — the two-item table above is the complete list of claims that go beyond what was
directly read.

## Open Questions

1. **Should `quickAddGoals`'s signature change, or should a new method be added?**
   - What we know: both satisfy the phase's requirements; CONTEXT.md leaves this to discretion.
   - What's unclear: whether changing `quickAddGoals`'s parameter type breaks any other call site not
     surfaced by this research (only `_GoalsBeat` in onboarding was found calling it with bare
     strings — verified via grep of `quickAddGoals(` across `lib/`).
   - Recommendation: the planner should grep `quickAddGoals(` at plan time (cheap, exact) before
     committing to a signature change, and prefer whichever shape keeps the diff smaller.

2. **Exact widget name(s) for the new sheet and shared chip widget.**
   - What we know: UI-SPEC calls the sheet `GoalPresetPickerSheet` "for this document; naming is
     planner/executor discretion."
   - What's unclear: nothing blocking — purely a naming choice.
   - Recommendation: keep `GoalPresetPickerSheet` as named in the UI-SPEC so the design doc and the
     code stay traceable to each other.

## Environment Availability

Skipped — this phase has no external dependencies (no new packages, no services, no CLIs beyond the
existing `flutter`/`dart` toolchain already used by every phase in this project).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with the Flutter SDK — `pubspec.yaml:44-45`, `sdk: flutter`) |
| Config file | none — no `dart_test.yaml`; conventions live in `test/test_helpers/` (`mood_pump.dart`, `viewport.dart`) |
| Quick run command | `flutter test test/screens/goals_add_fork_test.dart test/screens/onboarding_flow_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GOALADD-01 | Goal door opens preset picker, not blank form | widget | `flutter test test/screens/goals_add_fork_test.dart -N "goal door opens the goal form"` (needs repointing) | ✅ exists, needs edit |
| GOALADD-01 | Preset tap creates a goal immediately, no interruption | widget | new test in a new `goal_preset_picker_sheet_test.dart` | ❌ Wave 0 |
| GOALADD-02 | "Add your own" reaches `GoalFormSheet` in one tap, same as a preset | widget | new test, same file as above | ❌ Wave 0 |
| GOALADD-03 | Created row shows budget as text; emoji lands on the model | widget + unit | new test (text-finder, per Pitfall 2) + `goals_notifier_test.dart`-style unit test for the emoji plumbing | ❌ Wave 0 (check if `goals_notifier_test.dart` already exists — not found under `test/` in this research pass; confirm at plan time) |

### Sampling Rate
- **Per task commit:** `flutter test test/screens/goals_add_fork_test.dart test/screens/onboarding_flow_test.dart test/screens/restoratives_quick_pick_test.dart` (the three files this phase's changes can affect)
- **Per wave merge:** `flutter test` (full suite — this project's own carried-forward lesson is that
  narrow probes have repeatedly missed real defects, e.g. the commitment-block gap in Phase 30)
- **Phase gate:** Full suite green before `/gsd-verify-work`, AND the human UAT specified in
  34-CONTEXT.md (`<uat>` section) — this is a feel-judged flow change, the class this project's green
  suites have missed six times already (27, 29, 31, 32×2, 33).

### Wave 0 Gaps
- [ ] `test/screens/goal_preset_picker_sheet_test.dart` (or similar name) — covers GOALADD-01,
      GOALADD-02, the empty-grid case (Decision 5), the double-tap race (Decision 4), and the
      error/rollback path (UI-SPEC's probe-caught error row)
- [ ] Confirm at plan time whether `test/providers/goals_notifier_test.dart` (or similar) exists for
      unit-testing the emoji-plumbing change to `quickAddGoals`/its replacement — not found in this
      research pass under `test/`; if absent, one small unit test suffices (no widget pump needed)
- [ ] `test/screens/goals_add_fork_test.dart` lines 163-172 and 260-278 — repoint per Pitfall 1
- [ ] `test/screens/onboarding_flow_test.dart` lines 163-178 and 467 — repoint per Pitfall 1
      (verified, NOT flagged by the UI-SPEC's own "known test impact" note)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This app has no auth surface anywhere (single-user local app) |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | marginal | "Add your own" collects a name via `GoalFormSheet`'s existing `TextFormField`/validator, unchanged by this phase — no new input surface is introduced (preset taps carry no user-typed input) |
| V6 Cryptography | no | No secrets, no network calls, no crypto anywhere in this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Double-tap race creating a duplicate goal | Repudiation-adjacent (unintended duplicate state, not a security boundary) | Synchronous optimistic local state removing the chip before the async save resolves (UI-SPEC Decision 4, verified as testable via single-`pump()`, no `pumpAndSettle`) |
| Silent data loss on save failure (chip already gone, goal never persisted) | Tampering-adjacent (user believes state exists that doesn't) | UI-SPEC's own probe-caught error row: on a failed create, restore the chip and surface the existing `'Could not save goal. Please try again.'` SnackBar copy (verified at `goal_form_sheet.dart:113`) |

This phase carries no meaningful attack surface beyond the UI-SPEC's own already-resolved
error/race handling above — there is no network, no auth, and no new persisted secret.

## Sources

### Primary (HIGH confidence — read directly this session)
- `lib/screens/onboarding/onboarding_screen.dart` — full file read, `_ChipCloud`/`_goalPresets`/`_suggestionsFor`/`_GoalsBeat` verified line-by-line
- `lib/screens/restoratives/restoratives_screen.dart` — full file read, `_QuickPickSection`/`kCommonRestoratives`/`_matchFor` verified line-by-line
- `lib/providers/goals_notifier.dart` — `quickAddGoals`, `archiveGoal`, `saveGoal`, `loadGoals` all read
- `lib/data/models/goal.dart` — full `Goal` class + `GoalType` enum read, field order confirmed
- `lib/screens/goals/widgets/goal_card.dart` — full file read, `_secondaryLine` and `_ProgressLine` verified
- `lib/screens/goals/goals_screen.dart` — full file read, `_openAddSheet`/`_openEditSheet` call chain verified
- `lib/screens/goals/widgets/add_kind_fork.dart` — full file read, `_DoorTile`/`showAddKindFork` verified
- `lib/screens/goals/goal_form_sheet.dart` — save/archive error-copy and priority-label lines read
- `lib/widgets/adaptive_form_modal.dart` — full file read, breakpoint/builder contract verified
- `test/screens/goals_add_fork_test.dart` — full file read, every test case's pass/fail status under this phase's change assessed
- `test/screens/restoratives_quick_pick_test.dart` — full file read, established test idiom extracted
- `test/screens/onboarding_flow_test.dart` — targeted read (chip-related lines) confirming `ActionChip` breakage
- `.planning/phases/34-adding-a-goal-feels-like-onboarding/34-CONTEXT.md` — user decisions, read in full
- `.planning/phases/34-adding-a-goal-feels-like-onboarding/34-UI-SPEC.md` — design contract, read in full, claims cross-checked against code rather than restated
- `.planning/STATE.md` — project history/carry-forward invariants, read for context

### Secondary / Tertiary
None — this was scoped as a pure codebase-research task and no web research was performed, per the
task's own explicit instruction.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; every widget used is already used elsewhere in this repo
- Architecture: HIGH — every call chain and signature quoted above was read directly this session
- Pitfalls: HIGH — both flagged test-breakage locations were found by reading the actual test files, not inferred; the double-tap and symbolic-assertion pitfalls are direct restatements of this project's own documented CLAUDE.md history (Phases 30/31/33)

**Research date:** 2026-09-08
**Valid until:** No expiry driver here (no external dependency versions to go stale) — valid until the
source files cited above change. If `_ChipCloud`, `_QuickPickSection`, `GoalsNotifier`, or `GoalCard`
are touched by an intervening phase before Phase 34 is planned/executed, re-verify the affected
sections.
