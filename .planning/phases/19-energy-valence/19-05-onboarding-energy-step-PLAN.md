---
phase: 19-energy-valence
plan: 05
type: execute
wave: 3
depends_on: ["19-02"]
files_modified:
  - lib/screens/onboarding/onboarding_screen.dart
autonomous: true
requirements: [ONBOARD-01]
must_haves:
  truths:
    - "Onboarding includes a 'What gives you energy?' step (Screen 4) before first schedule generation (ONBOARD-01)"
    - "Marking a goal energizing on Screen 4 and completing sets that goal's energyValence to gives"
    - "Skipping Screen 4 completes onboarding leaving goals at neutral; the existing 3-step flow is not broken"
  artifacts:
    - path: "lib/screens/onboarding/onboarding_screen.dart"
      provides: "_Screen4 widget, _StepDots totalPages 4, Screen 3 onComplete→_nextPage, valence applied in _completeOnboarding"
      contains: "_Screen4"
  key_links:
    - from: "lib/screens/onboarding/onboarding_screen.dart (_completeOnboarding)"
      to: "GoalsNotifier.saveGoal with energyValenceIndex = EnergyValence.gives.index"
      via: "step 3.5 applies valence to _screen4MarkedGoalIds + _screen4QuickGoals"
      pattern: "EnergyValence.gives.index"
---

<objective>
Insert onboarding Screen 4 ("What gives you energy?") that lets the user mark a couple of goals as
energy-giving (and quick-add an energizing goal), seeding restorative goals before first schedule
generation (ONBOARD-01).

Purpose: Without an onboarding seed, a brand-new user reaches their first schedule with every goal
at neutral and the valence feature invisible. This step plants energy-giving goals up front.

Output: A new _Screen4 page in the onboarding PageView; Screen 3's onComplete/onSkip rerouted to
_nextPage (was _completeOnboarding); _completeOnboarding applies EnergyValence.gives to marked +
quick-added goals; onboarding_screen4_test.dart flips RED→GREEN. The existing 3-step flow still
works when Screen 4 is skipped.
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

@lib/screens/onboarding/onboarding_screen.dart
</context>

<artifacts_this_plan_produces>
- `_OnboardingScreenState._screen4MarkedGoalIds` (Set<String>), `_screen4QuickGoals` (List<Goal>) — state
- `_Screen4` (StatefulWidget) — headline, sub-copy, goal rows w/ "Energizing" FilterChip, empty state, "Add something energizing" inline quick-add, Skip + "Let's go" CTA row
- `_StepDots(totalPages: 4)` (bumped from 3)
- Screen 3 `onComplete`/`onSkip` rerouted to `_nextPage`
- `_completeOnboarding` step 3.5: save quick-add goals + apply EnergyValence.gives to marked goals before setOnboardingComplete
</artifacts_this_plan_produces>

<note_on_flow_order>
Critical sequencing (19-RESEARCH §Onboarding Integration, Pitfall 3, Open Q1): Screen 3 currently
calls _completeOnboarding() directly — it MUST be changed to _nextPage() or Screen 4 is never reached.
_completeOnboarding saves goals in this order: (1) Screen 1 goal, (2) Screen 2 commitment, (3) Screen 3
habit, (3.5 NEW) save _screen4QuickGoals with gives + re-fetch marked goals from notifier and apply
gives, (4) setOnboardingComplete(true) LAST (gates the router redirect). The _isSaving guard must cover
Screen 4's both CTAs to prevent double-completion (Pitfall 5). Screen 4 displays pending goals passed
from parent state (they are saved by steps 1+3, then valence applied in 3.5) — do NOT read from
GoalsNotifier for Screen 4's display list since Screens 1/3 goals aren't persisted until completion.
</note_on_flow_order>

<tasks>

<task type="auto">
  <name>Task 1: Reroute Screen 3 + add _Screen4 widget + step dots (ONBOARD-01 UI)</name>
  <files>lib/screens/onboarding/onboarding_screen.dart</files>
  <read_first>
    - 19-PATTERNS.md §"onboarding_screen.dart" (lines 686-855) — state additions, _StepDots bump, Screen 3 callback change, _Screen4 constructor, _ScreenLayout wrapper, CTA row, PageView addition
    - 19-UI-SPEC.md §"5. Onboarding Energy Step" (lines 246-316) — full content structure, goal-row ListTile + FilterChip, empty state, quick-add, copy
    - 19-UI-SPEC.md §Copywriting (lines 383-391) — exact strings (headline, sub-copy, "Energizing", "Add something energizing", "Skip", "Let's go", empty state)
    - 19-RESEARCH.md §"Pitfall 3" (lines 471-479) + §"Pitfall 5" (lines 489-495) — Screen 3 reroute + isSaving guard
    - lib/screens/onboarding/onboarding_screen.dart (full) — _Screen3 structure, _ScreenLayout, _StepDots, _isSaving
  </read_first>
  <action>
    Add `import '../../data/models/energy_valence.dart';` if not already present. Add state fields
    `Set<String> _screen4MarkedGoalIds = {};` and `List<Goal> _screen4QuickGoals = [];`. Change
    `_StepDots(... totalPages: 3)` to `totalPages: 4`. Change Screen 3's `onComplete` from calling
    _completeOnboarding to `(habit) { _screen3Habit = habit; _nextPage(); }` and its `onSkip` to `_nextPage`
    (skip still advances to Screen 4). Add a `_Screen4` StatefulWidget modeled on _Screen3 wrapped in
    _ScreenLayout: headline Text("What gives you energy?", headlineSmall), SizedBox(8), sub-copy
    Text("Pick one or two activities that leave you feeling good. We'll make sure to include them on hard
    days.", bodyMedium/onSurfaceVariant), SizedBox(24), a goal row per pendingGoal (ListTile with leading
    emoji Text, title goal name, trailing FilterChip label "Energizing" selected when in markedIds, avatar
    Icons.bolt when selected), an empty-state Text("No goals yet — add one below.", centered/onSurfaceVariant)
    when there are no pending goals, SizedBox(16), an "Add something energizing" OutlinedButton.icon that
    reveals an inline name TextField + Icons.check_circle_outlined confirm (NOT a modal) which appends a
    Goal(name, GoalType.timeTarget, weeklyHourBudget: 3.0, energyValenceIndex: EnergyValence.gives.index)
    to a local quick-goals list, Spacer(), then the CTA Row: Expanded TextButton "Skip" + ElevatedButton
    "Let's go". Both CTAs disabled when isSaving. _Screen4 constructor takes pendingGoals (List<Goal>),
    onComplete (void Function(Set<String>, List<Goal>)), onSkip (VoidCallback), isSaving (bool). Add
    _Screen4 as the 4th child of the PageView, building pendingGoals from a helper that constructs display
    Goals from _screen1NameController/_screen1Type and _screen3Habit state; its onComplete sets
    _screen4MarkedGoalIds + _screen4QuickGoals then calls _completeOnboarding; its onSkip calls the existing
    skip-to-complete path. Run dart format + flutter analyze.
  </action>
  <verify>
    <automated>grep -q 'class _Screen4' lib/screens/onboarding/onboarding_screen.dart && grep -q 'totalPages: 4' lib/screens/onboarding/onboarding_screen.dart && grep -q 'What gives you energy?' lib/screens/onboarding/onboarding_screen.dart && ! grep -q 'onComplete: (habit) {[^}]*_completeOnboarding' lib/screens/onboarding/onboarding_screen.dart && flutter analyze lib/screens/onboarding/onboarding_screen.dart</automated>
  </verify>
  <done>_Screen4 exists with headline/sub-copy/goal rows/empty state/quick-add/Skip+Let's go; step dots show 4; Screen 3 advances to Screen 4 instead of completing; analyze clean.</done>
</task>

<task type="auto">
  <name>Task 2: Apply valence on complete + isSaving guard (ONBOARD-01 persistence)</name>
  <files>lib/screens/onboarding/onboarding_screen.dart</files>
  <read_first>
    - 19-PATTERNS.md §"_completeOnboarding additions" (lines 726-750) — step 3.5 placement before setOnboardingComplete
    - 19-RESEARCH.md §"Phase 19 Additions to _OnboardingScreenState" (lines 639-681) — save order, re-fetch marked goals from notifier after they're saved
    - 19-RESEARCH.md §"Pitfall 5" (lines 489-495) — both Screen 4 CTAs honor isSaving
    - lib/screens/onboarding/onboarding_screen.dart — existing _completeOnboarding step order + _isSaving guard
  </read_first>
  <action>
    In _completeOnboarding, after the existing step (3) saves the Screen 3 habit and BEFORE the final
    setOnboardingComplete(true), insert step (3.5): for each goal in _screen4QuickGoals set
    energyValenceIndex = EnergyValence.gives.index and await goalsNotifier.saveGoal(goal); then for each id
    in _screen4MarkedGoalIds, re-fetch the goal from goalsNotifier.goals (now persisted by steps 1/3),
    set its energyValenceIndex = EnergyValence.gives.index, and await goalsNotifier.saveGoal(goal). Keep
    setOnboardingComplete(true) strictly last (router-redirect gate). Confirm the existing `if (_isSaving)
    return; setState(() => _isSaving = true);` guard at the top of _completeOnboarding is intact and that
    _Screen4's "Let's go" and "Skip" both pass through isSaving-disabled CTAs (no second path bypasses the
    guard). The Skip path applies no valence (goals stay neutral). Run dart format + flutter analyze.
  </action>
  <verify>
    <automated>grep -q 'EnergyValence.gives.index' lib/screens/onboarding/onboarding_screen.dart && grep -q '_screen4QuickGoals' lib/screens/onboarding/onboarding_screen.dart && grep -q '_screen4MarkedGoalIds' lib/screens/onboarding/onboarding_screen.dart && flutter test test/screens/onboarding_screen4_test.dart</automated>
  </verify>
  <done>Completing onboarding with marked/quick-added goals persists them with energyValence=gives before setOnboardingComplete; Skip leaves goals neutral; _isSaving guard covers both CTAs; onboarding_screen4_test.dart GREEN.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| onboarding input → persisted Goals + onboarding-complete flag | Screen 4 marks/creates goals and triggers the final setOnboardingComplete that opens the router. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-19-07 | Denial of Service (double-completion / partial save) | _completeOnboarding re-entry | mitigate | Existing `_isSaving` guard kept and extended to both Screen 4 CTAs (Pitfall 5); setOnboardingComplete(true) stays strictly last so a mid-save abort cannot leave onboarding "done" with goals unsaved. |
| T-19-08 | Tampering (broken onboarding flow) | Screen 3 onComplete reroute | mitigate | Screen 3 changed to _nextPage and grep-verified it no longer calls _completeOnboarding; onboarding_screen4_test.dart exercises the full reach-and-complete path so a regression that skips Screen 4 fails RED. |
| T-19-04 | Improper Input Validation (V5) | quick-add goal name | accept | Quick-add reuses Screen 1's existing free-text goal-name handling (no new validation surface); valence is the fixed enum value gives; emoji not set here. Local Hive only — no injection surface (19-RESEARCH §Security Domain). |
| T-19-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this phase (19-RESEARCH §Package Legitimacy Audit). |
</threat_model>

<verification>
- `flutter test test/screens/onboarding_screen4_test.dart` — GREEN.
- `flutter analyze` clean.
- Grep confirms Screen 3 no longer calls _completeOnboarding directly; step dots = 4.
- Wave-3 merge gate (run after all of 03/04/05): full `flutter test` GREEN.
</verification>

<success_criteria>
- ONBOARD-01: a "What gives you energy?" step seeds energy-giving goals before first schedule.
- Marked + quick-added goals persist with energyValence=gives; Skip leaves neutral.
- Existing 3-step onboarding remains functional (no completion regression).
</success_criteria>

<output>
Create `.planning/phases/19-energy-valence/19-05-SUMMARY.md` when done.
</output>
