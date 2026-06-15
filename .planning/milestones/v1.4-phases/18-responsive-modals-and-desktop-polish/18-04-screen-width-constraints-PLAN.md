---
phase: 18-responsive-modals-and-desktop-polish
plan: 04
type: execute
wave: 2
depends_on: ["18-02"]
files_modified:
  - lib/screens/home/home_screen.dart
  - lib/screens/schedule/schedule_screen.dart
  - lib/screens/goals/goals_screen.dart
autonomous: true
requirements: [POLISH-01]
must_haves:
  truths:
    - "On desktop width, Home content is constrained to 720dp and top-centered, not full-bleed"
    - "On desktop width, the Schedule chunk list is constrained to 720dp while the progress bar stays full-width"
    - "On desktop width, the Goals list is constrained to 720dp and top-centered"
    - "Phone width behavior is unchanged (720dp constraint has no visible effect below 720dp)"
  artifacts:
    - path: "lib/screens/home/home_screen.dart"
      provides: "active-schedule body wrapped in Align(topCenter)+ConstrainedBox(720)"
      contains: "maxWidth: 720"
    - path: "lib/screens/schedule/schedule_screen.dart"
      provides: "ListView constrained to 720; ScheduleProgressBar full-width"
      contains: "maxWidth: 720"
    - path: "lib/screens/goals/goals_screen.dart"
      provides: "CustomScrollView wrapped in Align(topCenter)+ConstrainedBox(720)"
      contains: "maxWidth: 720"
  key_links:
    - from: "lib/screens/schedule/schedule_screen.dart"
      to: "ListView"
      via: "Align(topCenter)+ConstrainedBox(720) around ListView only, not the progress bar"
      pattern: "ConstrainedBox"
---

<objective>
Constrain primary-screen content width to 720dp on desktop so Home, Schedule, and Goals no longer stretch full-bleed at wide widths. This satisfies POLISH-01 using the existing `checkin_screen.dart` 480dp `ConstrainedBox` pattern, scaled to 720dp and top-centered with `Align(topCenter)`. Check-in already has its constraint and is out of scope.

Purpose: Make wide-window content read as a column, not a stretched phone layout — the layout half of "fit the screen it's used on".
Output: `home_screen.dart`, `schedule_screen.dart`, `goals_screen.dart` body wrappers.

NOTE on file ownership: this plan modifies `goals_screen.dart`, which 18-02 also modifies (the modal callers). It is sequenced to wave 2 (after 18-02) to avoid a same-wave write conflict. Apply ONLY the body-constraint wrap here — do not touch `_openAddSheet`/`_openEditSheet` (already done in 18-02).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-RESEARCH.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-PATTERNS.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-UI-SPEC.md

# Files this plan modifies + the precedent
@lib/screens/home/home_screen.dart
@lib/screens/schedule/schedule_screen.dart
@lib/screens/goals/goals_screen.dart
@lib/screens/schedule/checkin_screen.dart
</context>

<artifacts_this_phase_produces>
- Behavior: Home active-schedule `body:` Column wrapped in `Align(alignment: Alignment.topCenter, child: ConstrainedBox(maxWidth: 720, ...))`
- Behavior: Schedule body — `Expanded(ListView)` wrapped in `Align(topCenter)+ConstrainedBox(720)`; `ScheduleProgressBar` stays full-width
- Behavior: Goals body — `Consumer<GoalsNotifier>` `CustomScrollView` wrapped in `Align(topCenter)+ConstrainedBox(720)` (no outer scroll wrapper — avoids double-scroll)
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Constrain Home and Goals body content to 720dp</name>
  <files>lib/screens/home/home_screen.dart, lib/screens/goals/goals_screen.dart</files>
  <behavior>
    - Home active-schedule body Column wrapped in Align(topCenter)+ConstrainedBox(maxWidth: 720). AppBar/FAB unchanged.
    - Goals CustomScrollView (inside the Consumer builder) wrapped in Align(topCenter)+ConstrainedBox(maxWidth: 720), as the sole scrollable (no outer SingleChildScrollView/ListView — Pitfall 2 double-scroll).
    - Verified by 18-01 content_width_constraint_test.dart Home + Goals cases turning GREEN.
  </behavior>
  <read_first>
    - 18-PATTERNS.md §`lib/screens/home/home_screen.dart` — before/after body wrap, `Align(topCenter)` not `Center`
    - 18-PATTERNS.md §`lib/screens/goals/goals_screen.dart` (body constraint) — wrap the Consumer-returned CustomScrollView
    - lib/screens/schedule/checkin_screen.dart ~lines 222-225 — the 480dp ConstrainedBox precedent to mirror at 720
    - 18-RESEARCH.md §Pitfall 2 (double-scroll), §Open Questions #3 (Home has TWO body assignments — constrain the active-schedule body at ~line 354 only; the empty state at ~line 660 is already centered/narrow, leave it)
  </read_first>
  <action>
    Home (`home_screen.dart`): wrap the active-schedule `body:` Column (the assignment around line 354, NOT the empty-state body around line 660) in `Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: <existing Column>))` per POLISH-01. Use `Align(topCenter)`, never `Center` (Center vertically floats short content — 18-RESEARCH anti-pattern). Leave AppBar and FAB outside the constraint.

    Goals (`goals_screen.dart`): in the `Consumer<GoalsNotifier>` builder, wrap the returned `CustomScrollView` in `Align(topCenter)+ConstrainedBox(maxWidth: 720)` as the sole scrollable — do NOT add an outer scroll wrapper (Pitfall 2). Do NOT modify `_openAddSheet`/`_openEditSheet` (already migrated in 18-02). Do NOT touch the empty-state copy.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter test test/screens/content_width_constraint_test.dart 2>&amp;1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    content_width_constraint_test.dart Home and Goals cases GREEN (ConstrainedBox(maxWidth: 720) present in each body); `flutter analyze` clean for both files.
  </acceptance_criteria>
  <done>Home and Goals bodies constrained to 720dp, top-centered; POLISH-01 Home+Goals tests GREEN.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Constrain Schedule chunk list to 720dp (progress bar stays full-width)</name>
  <files>lib/screens/schedule/schedule_screen.dart</files>
  <behavior>
    - ScheduleProgressBar remains the full-width first child of the body Column.
    - The Expanded(ListView) is wrapped in Align(topCenter)+ConstrainedBox(maxWidth: 720) so only the chunk list is constrained.
    - Verified by 18-01 content_width_constraint_test.dart Schedule case (if not skipped) and by no overflow/double-scroll.
  </behavior>
  <read_first>
    - 18-PATTERNS.md §`lib/screens/schedule/schedule_screen.dart` — exact before/after, "ScheduleProgressBar stays full-width; constrain only the ListView inside Expanded"
    - 18-RESEARCH.md §Open Questions #2 (keep progress bar full-width per Material 3 convention) and §Pattern 3 IMPORTANT note
    - lib/screens/schedule/schedule_screen.dart ~lines 88-101 — current body Column
  </read_first>
  <action>
    In `schedule_screen.dart`, wrap the `ListView` inside the existing `Expanded` (in the body Column at ~lines 88-101) with `Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: <existing ListView>))`, per POLISH-01. Leave `ScheduleProgressBar` as the unconstrained full-width first child of the Column (18-RESEARCH §Open Questions #2). Do not change the chunk-item building logic.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter analyze lib/screens/schedule/schedule_screen.dart 2>&amp;1 | tail -8 &amp;&amp; flutter test test/screens/content_width_constraint_test.dart 2>&amp;1 | tail -15</automated>
  </verify>
  <acceptance_criteria>
    Schedule body has ConstrainedBox(maxWidth: 720) around the ListView with ScheduleProgressBar outside it; analyzer clean; content_width_constraint_test.dart stays/turns GREEN (Schedule case GREEN if implemented, otherwise its documented skip remains).
  </acceptance_criteria>
  <done>Schedule chunk list constrained to 720dp; progress bar full-width; analyzer clean.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Layout-only wrappers around existing scroll views; no data, network, auth, or persistence change. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-04-D | Denial of Service | unbounded layout | accept | ConstrainedBox is the mitigation against full-bleed/unbounded width, not a threat vector; no runtime input involved (18-RESEARCH §Security Domain: no new surface). |
| T-18-SC | Tampering | npm/pip/cargo installs | accept | No package installs — Flutter SDK widgets only (18-RESEARCH §Package Legitimacy Audit: N/A). |
</threat_model>

<verification>
- `flutter test test/screens/content_width_constraint_test.dart` Home/Goals (and Schedule if implemented) GREEN.
- `flutter analyze` clean for all three modified screens.
- `flutter test` at wave merge — no regression in home/schedule/goals widget tests.
</verification>

<success_criteria>
Home, Schedule, and Goals content is constrained to 720dp and top-centered on desktop, with the schedule progress bar full-width; phone width unchanged. POLISH-01 satisfied.
</success_criteria>

<output>
Create `.planning/phases/18-responsive-modals-and-desktop-polish/18-04-SUMMARY.md` when done.
</output>
