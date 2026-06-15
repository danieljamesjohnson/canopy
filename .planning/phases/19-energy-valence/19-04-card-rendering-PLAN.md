---
phase: 19-energy-valence
plan: 04
type: execute
wave: 3
depends_on: ["19-02"]
files_modified:
  - lib/screens/goals/widgets/goal_card.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/screens/schedule/schedule_screen.dart
autonomous: true
requirements: [ENERGY-03, ENERGY-04]
must_haves:
  truths:
    - "A goal's emoji tag and non-neutral valence badge appear on its goal card (ENERGY-03b, ENERGY-04a)"
    - "A chunk shows its goal's emoji and valence chip so the day reads restorative-vs-draining at a glance (ENERGY-04b)"
    - "Neutral valence shows no badge anywhere"
  artifacts:
    - path: "lib/screens/goals/widgets/goal_card.dart"
      provides: "emoji in title row + file-private _ValenceBadge in secondary row"
      contains: "_ValenceBadge"
    - path: "lib/screens/schedule/widgets/chunk_card.dart"
      provides: "goalEmojiTag + goalValence params, emoji-prefixed name, file-private _ValenceChip"
      contains: "_ValenceChip"
    - path: "lib/screens/schedule/widgets/swipeable_chunk_card.dart"
      provides: "goalEmojiTag + goalValence pass-through params"
      contains: "goalValence"
    - path: "lib/screens/schedule/schedule_screen.dart"
      provides: "_lookupGoalValence + _lookupGoalEmojiTag helpers wired into both card call sites"
      contains: "_lookupGoalValence"
  key_links:
    - from: "lib/screens/schedule/schedule_screen.dart"
      to: "lib/screens/schedule/widgets/chunk_card.dart"
      via: "goalValence/goalEmojiTag props through SwipeableChunkCard"
      pattern: "goalValence:"
---

<objective>
Render valence and emoji wherever goals are listed and scheduled: the goal card (goals list) and
the schedule chunk card (via lookup helpers + pass-through props). Neutral valence shows nothing
(ENERGY-03b emoji on card, ENERGY-04a badge on card, ENERGY-04b valence+emoji on chunk).

Purpose: Make the day read restorative-vs-draining at a glance — the visibility side of the
valence feature.

Output: _ValenceBadge on goal_card, _ValenceChip on chunk_card (intentional file-private duplicate),
two new chunk→goal lookup helpers, and the chunk-card props plumbed through SwipeableChunkCard. The
goal_card and chunk_card valence tests flip RED→GREEN.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/19-energy-valence/19-UI-SPEC.md
@.planning/phases/19-energy-valence/19-PATTERNS.md
@.planning/phases/19-energy-valence/19-RESEARCH.md

@lib/screens/goals/widgets/goal_card.dart
@lib/screens/schedule/widgets/chunk_card.dart
@lib/screens/schedule/widgets/swipeable_chunk_card.dart
@lib/screens/schedule/schedule_screen.dart
</context>

<artifacts_this_plan_produces>
- goal_card.dart: emoji `Text` in title row (between type icon and name), `_ValenceBadge` (file-private) in secondary row, import energy_valence
- chunk_card.dart: `goalEmojiTag` (String?) + `goalValence` (EnergyValence?) params on ChunkCard and _WorkChunkContent; emoji prefixed to goal name; `_ValenceChip` (file-private visual duplicate of _ValenceBadge), import energy_valence
- swipeable_chunk_card.dart: `goalEmojiTag` + `goalValence` pass-through params forwarded to ChunkCard
- schedule_screen.dart: `_lookupGoalValence` + `_lookupGoalEmojiTag` helpers; both card call sites pass the two new props; import energy_valence
</artifacts_this_plan_produces>

<note_on_parallelism>
This plan owns goal_card.dart, chunk_card.dart, swipeable_chunk_card.dart, schedule_screen.dart —
disjoint from Plan 03 (goal_form_sheet.dart) and Plan 05 (onboarding_screen.dart), so all three
Wave-3 plans run in parallel with no file conflict. _ValenceBadge (goal_card) and _ValenceChip
(chunk_card) are INTENTIONALLY duplicated file-private widgets (same visual, different class) — do
NOT extract to a shared widget; this matches the existing _PriorityChip duplication pattern.
</note_on_parallelism>

<tasks>

<task type="auto">
  <name>Task 1: Goal card — emoji in title + _ValenceBadge (ENERGY-03b, ENERGY-04a)</name>
  <files>lib/screens/goals/widgets/goal_card.dart</files>
  <read_first>
    - 19-PATTERNS.md §"lib/screens/goals/widgets/goal_card.dart" (lines 213-328) — _PriorityChip structure to clone for _ValenceBadge, exact title-row + secondary-row insertion points, import
    - 19-UI-SPEC.md §"3. Valence Badge on Goal Card" (lines 175-231) — badge structure, color slots, suppression of neutral, emoji-in-title placement (8dp gap)
    - 19-RESEARCH.md §"Valence color mapping" (lines 568-587) — gives=tertiaryContainer/bolt/'Gives', costs=secondaryContainer/hourglass_empty/'Costs'
  </read_first>
  <action>
    Add `import '../../../data/models/energy_valence.dart';`. Add a file-private `_ValenceBadge` class
    that clones `_PriorityChip`'s structure (Container padding 8h/4v, borderRadius 8, Row of Icon size 12 +
    SizedBox(4) + Text labelSmall w600), taking `required final EnergyValence valence`. It returns
    SizedBox.shrink() for neutral; gives → tertiaryContainer/onTertiaryContainer/Icons.bolt/'Gives';
    costs → secondaryContainer/onSecondaryContainer/Icons.hourglass_empty/'Costs'. MUST NOT use
    colorScheme.error. In the title row, between the type Icon and the Expanded goal-name Text, insert
    `if (goal.emojiTag != null) ...[ SizedBox(width:4), Text(goal.emojiTag!, style: TextStyle(fontSize:16)) ]`
    (keep an on-grid gap before the name per UI-SPEC). In the secondary row, after _PriorityChip, insert
    `if (goal.energyValence != EnergyValence.neutral) ...[ SizedBox(width:4), _ValenceBadge(valence: goal.energyValence) ]`.
    Run dart format + flutter analyze.
  </action>
  <verify>
    <automated>grep -q "import '../../../data/models/energy_valence.dart'" lib/screens/goals/widgets/goal_card.dart && grep -q 'class _ValenceBadge' lib/screens/goals/widgets/goal_card.dart && grep -q 'goal.emojiTag' lib/screens/goals/widgets/goal_card.dart && ! grep -q 'colorScheme.error' lib/screens/goals/widgets/goal_card.dart && flutter test test/screens/goal_card_valence_test.dart</automated>
  </verify>
  <done>Goal card shows emoji in title and _ValenceBadge (Gives/Costs) in secondary row; neutral shows no badge; no error color used; goal_card_valence_test.dart GREEN.</done>
</task>

<task type="auto">
  <name>Task 2: Chunk card + swipeable + schedule lookups (ENERGY-04b)</name>
  <files>lib/screens/schedule/widgets/chunk_card.dart, lib/screens/schedule/widgets/swipeable_chunk_card.dart, lib/screens/schedule/schedule_screen.dart</files>
  <read_first>
    - 19-PATTERNS.md §"chunk_card.dart" (lines 332-402) — new params, _WorkChunkContent emoji-prefix title change, _ValenceChip insertion after _PriorityChip
    - 19-PATTERNS.md §"swipeable_chunk_card.dart" (lines 484-528) — pass-through params
    - 19-PATTERNS.md §"schedule_screen.dart" (lines 406-480) — two new _lookup helpers + both call sites (_buildSwipeableCard, _buildSkippedSection)
    - 19-UI-SPEC.md §"4. Valence + Emoji on Chunk Card" (lines 233-244) — emoji inline in title, chip after rationale, resolved-chunk Opacity inherited
    - 19-RESEARCH.md §"Chunk Card Changes" (lines 406-435) + §"Chunk → goal lookup" (lines 589-607)
  </read_first>
  <action>
    chunk_card.dart: add `import '../../../data/models/energy_valence.dart';`. Add `final String? goalEmojiTag;`
    and `final EnergyValence? goalValence;` to ChunkCard's constructor/fields AND forward them into
    _WorkChunkContent (add the same two fields there). In _WorkChunkContent's goal-name Text, prepend the
    emoji inline: build the string as `'${goalEmojiTag != null ? "$goalEmojiTag " : ""}${goalName ?? (chunk.rationale.isNotEmpty ? chunk.rationale : "Work block")}'`
    keeping the existing titleMedium w600 + ellipsis style. After the existing _PriorityChip block, insert
    `if (goalValence != null && goalValence != EnergyValence.neutral) ...[ SizedBox(height:4), _ValenceChip(valence: goalValence!) ]`.
    Add a file-private `_ValenceChip` class that is the visual duplicate of goal_card's _ValenceBadge (same
    colors/icons/labels/structure) — keep the existing "intentionally duplicated" convention; do NOT import
    or share goal_card's widget.
    swipeable_chunk_card.dart: add the same two params to its constructor/fields and forward them in the
    `child: ChunkCard(...)` call.
    schedule_screen.dart: add `import '../../data/models/energy_valence.dart';`; append `_lookupGoalValence`
    and `_lookupGoalEmojiTag` helpers as verbatim copies of `_lookupGoalPriorityWeight` (null-guard goalId,
    read GoalsNotifier.goals, where(id==goalId).firstOrNull) returning goal?.energyValence and goal?.emojiTag.
    In both `_buildSwipeableCard` and `_buildSkippedSection`, pass
    `goalEmojiTag: _lookupGoalEmojiTag(context, chunk)` and `goalValence: _lookupGoalValence(context, chunk)`.
    Run dart format + flutter analyze.
  </action>
  <verify>
    <automated>grep -q 'class _ValenceChip' lib/screens/schedule/widgets/chunk_card.dart && grep -q 'goalValence' lib/screens/schedule/widgets/swipeable_chunk_card.dart && grep -q '_lookupGoalValence' lib/screens/schedule/schedule_screen.dart && grep -q '_lookupGoalEmojiTag' lib/screens/schedule/schedule_screen.dart && flutter test test/screens/chunk_card_valence_test.dart</automated>
  </verify>
  <done>ChunkCard renders emoji-prefixed name + _ValenceChip for non-neutral valence; SwipeableChunkCard forwards both props; schedule_screen has both lookups wired into both call sites; chunk_card_valence_test.dart GREEN; flutter analyze clean.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| persisted Goal → display widgets | Goal.emojiTag / Goal.energyValence (already validated/constrained at write time in Plan 03) are read for display. Read-only rendering; no new write surface. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-19-05 | Information Disclosure / display correctness | _lookupGoalValence/_lookupGoalEmojiTag over commitment chunks | mitigate | Both helpers null-guard `chunk.goalId == null` (verbatim from the existing priority lookup), so commitment chunks (no goal) render no emoji/valence rather than mis-resolving another goal's data. |
| T-19-06 | (display) | neutral valence | mitigate | Explicit `!= EnergyValence.neutral` guard at both render sites prevents spurious badges; matches UI-SPEC suppression rule. |
| T-19-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this phase (19-RESEARCH §Package Legitimacy Audit). |
</threat_model>

<verification>
- `flutter test test/screens/goal_card_valence_test.dart test/screens/chunk_card_valence_test.dart` — GREEN.
- `flutter analyze` clean.
- Grep confirms `colorScheme.error` not used for the valence badge/chip; _ValenceBadge and _ValenceChip remain separate file-private classes.
</verification>

<success_criteria>
- ENERGY-03b: emoji renders on goal card title.
- ENERGY-04a: valence badge on goal card for gives/costs, absent for neutral.
- ENERGY-04b: valence chip + emoji visible on chunk card; commitment chunks unaffected.
</success_criteria>

<output>
Create `.planning/phases/19-energy-valence/19-04-SUMMARY.md` when done.
</output>
