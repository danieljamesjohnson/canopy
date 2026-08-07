---
phase: 22-unified-today-screen
plan: 04
type: execute
wave: 3
depends_on: ["22-03"]
files_modified:
  - lib/router.dart
  - lib/widgets/responsive_shell.dart
  - lib/screens/home/home_screen.dart
  - lib/screens/home/widgets/active_chunk_card.dart
  - lib/screens/home/widgets/end_of_day_card.dart
  - lib/screens/home/widgets/review_banner.dart
  - lib/screens/schedule/schedule_screen.dart
  - lib/screens/schedule/widgets/now_marker.dart
  - lib/screens/today/widgets/end_of_day_card.dart
  - lib/screens/today/widgets/review_banner.dart
  - lib/screens/today/today_screen.dart
  - test/screens/router_redirect_test.dart
  - test/screens/content_width_constraint_test.dart
  - test/screens/home_screen_now_state_test.dart
  - test/screens/today_screen_now_state_test.dart
  - test/screens/active_chunk_card_test.dart
  - test/screens/home_screen_breathing_pulse_test.dart
  - test/screens/breathing_pulse_cta_test.dart
  - test/end_of_day_card_test.dart
autonomous: true
requirements: [UNIFY-02]
must_haves:
  truths:
    - "The shell offers three destinations — Today, Goals, Settings — and none of them is called Home or Schedule"
    - "Tapping a Chunk reminder notification lands on the working unified screen, with no change to main.dart"
    - "A /schedule deep link resolves to the unified route instead of a dead route"
    - "/schedule/checkin still resolves to the check-in screen — the legacy redirect does not swallow it"
    - "An un-onboarded user hitting /schedule still lands on /onboarding — the legacy redirect cannot bypass the gate"
    - "home_screen.dart, schedule_screen.dart, active_chunk_card.dart and now_marker.dart are gone, and nothing references them"
    - "The suite is green and flutter analyze is clean with no screen left orphaned"
  artifacts:
    - path: "lib/router.dart"
      provides: "Three shell branches, /today as initial location, and a /schedule redirect that preserves /schedule/checkin"
      contains: "'/today'"
    - path: "lib/widgets/responsive_shell.dart"
      provides: "Three destinations (Today/Goals/Settings) with the superseded four-destination lock note updated"
      contains: "label: 'Today'"
    - path: "test/screens/router_redirect_test.dart"
      provides: "UNIFY-02 regression coverage: /schedule redirect, /schedule/checkin survival, onboarding gate ordering, three destinations"
      contains: "/schedule/checkin"
    - path: "test/screens/today_screen_now_state_test.dart"
      provides: "The relocated now-state suite: pure resolveNowState units plus TodayScreen time-anchored widget cases"
      contains: "TodayScreen"
  key_links:
    - from: "lib/main.dart"
      to: "lib/router.dart"
      via: "router.go('/schedule') on notification tap, redirected to /today — main.dart is deliberately NOT edited"
      pattern: "matchedLocation == '/schedule'"
    - from: "lib/router.dart"
      to: "lib/screens/today/today_screen.dart"
      via: "branch 0 builder"
      pattern: "TodayScreen"
    - from: "lib/widgets/responsive_shell.dart"
      to: "lib/router.dart"
      via: "positional destination-to-branch order (Today=0, Goals=1, Settings=2)"
      pattern: "Today=0"
---

<objective>
Switch the app over to the merged destination and delete what the merge replaced. This is
UNIFY-02: the shell reflects the merge and every existing entry point — the daily Chunk-reminder
notification, any `/schedule` deep link, the check-in flow — lands somewhere real.

Purpose: plan 22-03 built `TodayScreen` beside the old screens without disturbing them. This plan
flips the router, collapses four destinations to three, retires `home_screen.dart`,
`schedule_screen.dart`, `active_chunk_card.dart` and `now_marker.dart`, and migrates the tests
that pointed at them. It also puts the old first-unresolved "now" scanner in the bin for good:
`_buildActiveChunkItems` dies with `schedule_screen.dart`.

Output: a three-branch router with a `/schedule` redirect, a three-destination shell, four deleted
source files, two relocated widgets, and a test suite that is green with no orphaned coverage.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/22-unified-today-screen/22-CONTEXT.md
@.planning/phases/22-unified-today-screen/22-UI-SPEC.md
@.planning/phases/22-unified-today-screen/22-PATTERNS.md

@lib/router.dart
@lib/widgets/responsive_shell.dart
@lib/main.dart
@test/screens/router_redirect_test.dart
@test/screens/content_width_constraint_test.dart
@test/screens/home_screen_now_state_test.dart
@test/screens/active_chunk_card_test.dart
@test/screens/responsive_layout_test.dart
</context>

<decision_ids>
Decision IDs D-01 through D-09 and the plan set's multi-source coverage audit live in
`22-01-now-state-and-timeline-model-PLAN.md`. This plan implements **D-08** (keep `/schedule`
resolving via a redirect; the notification path must land on the working screen; remove the
"see full schedule" affordance) and **D-09** (four destinations become three; update the
superseded UI-SPEC lock note rather than violating it silently).

The naming choice from plan 22-01 lands here: destination label **"Today"**, route **`/today`**,
icon `Icons.today_outlined`. One word, not "Home", per 22-CONTEXT.md's "Deliberately NOT decided
here".
</decision_ids>

<route_strategy>
**Why `/schedule` stays declared instead of being deleted.**

22-PATTERNS.md section 3 proposes deleting the `/schedule` branch and adding a top-level redirect.
That is right for the bare path but would take `/schedule/checkin` down with it — a child route
cannot outlive its parent, and 22-CONTEXT.md is explicit that the check-in flow is not in this
phase's requirements and must not be restructured. `/schedule/checkin` has eleven call sites in
`lib/` and `test/`.

So the merged branch declares BOTH paths:

- `/today` renders `TodayScreen`. This is the canonical route and the router's `initialLocation`.
- `/schedule` is kept as a declared route purely so `/schedule/checkin` keeps a parent. The
  top-level `redirect:` normalises a bare `/schedule` to `/today` before its builder ever runs;
  the builder is a defensive fallback that renders `TodayScreen` anyway, so even a future
  regression in the redirect cannot produce the dead route UNIFY-02 exists to prevent.

**The redirect must match `matchedLocation` EXACTLY.** `state.matchedLocation` for
`/schedule/checkin` is `/schedule/checkin`, so an exact `== '/schedule'` comparison leaves the
child alone. A `startsWith` or a route-level redirect on the parent GoRoute would fire for the
child too and break the daily check-in — do not use either.

**Ordering inside the redirect callback is a security property, not a style choice.** The
onboarding gate runs FIRST; the `/schedule` normalisation runs after it. Reversing them would let
a `/schedule` deep link skip onboarding (threat T-22-13). A regression test pins this.

**`lib/main.dart` is deliberately NOT edited.** `router.go('/schedule')` on notification tap
(main.dart:86) flows through the redirect to `/today`. This is the least-invasive option
22-PATTERNS.md section 3.4 recommends, and it keeps the cold-launch WR-02 post-frame guard above
it untouched. A verify gate asserts main.dart still contains the original call.
</route_strategy>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Router branches, /schedule redirect, shell 4-to-3 (D-08, D-09, G2, G3, P6, P7)</name>
  <files>lib/router.dart, lib/widgets/responsive_shell.dart, test/screens/router_redirect_test.dart</files>
  <read_first>
    - lib/router.dart lines 24-94 — initialLocation, the redirect callback, and all four StatefulShellBranch declarations
    - lib/widgets/responsive_shell.dart lines 1-60 — the header comment citing the four-destination UI-SPEC lock, the _destinations record list, and _goBranch
    - lib/main.dart lines 70-92 — the notification tap callback that must keep working untouched
    - 22-UI-SPEC.md "Navigation contract (UNIFY-02)" — three destinations, NavigationRailLabelType.all retained, /schedule must keep resolving
    - test/screens/router_redirect_test.dart — the whole file; _pumpRouter's fake-notifier tree and the six existing cases, three of which change
    - the route_strategy section of this plan — the exact redirect semantics
  </read_first>
  <behavior>
    Existing cases that CHANGE (update the expectation and the test name, do not delete):
    - "onboardingComplete=true, /schedule deep link" now resolves to "/today", not "/schedule".
    - "onboardingComplete=true, /onboarding deep link" now redirects to "/today", not "/home".
    - "cold launch with onboardingComplete=true" now lands on "/today", not "/home".
    Existing cases that MUST STILL PASS UNCHANGED:
    - onboardingComplete=false with a /schedule deep link redirects to /onboarding.
    - onboardingComplete=false with a /goals deep link redirects to /onboarding.
    - onboardingComplete=true with a /goals deep link loads /goals.
    New UNIFY-02 cases:
    - onboardingComplete=true, router.go('/schedule') — the literal notification-tap call from
      main.dart:86 — resolves to "/today" (G3, D-08).
    - onboardingComplete=true, /schedule/checkin resolves to "/schedule/checkin" and is NOT
      swallowed by the /schedule redirect.
    - onboardingComplete=false, /schedule/checkin still redirects to /onboarding (the gate is
      ordered first — T-22-13).
    - onboardingComplete=true, /today loads /today.
    - At a 1200dp viewport with onboardingComplete=true, the NavigationRail has exactly three
      destinations, and none of their labels is "Home" or "Schedule" while one is "Today" (G2).
  </behavior>
  <action>
    Write the changed and new cases in `test/screens/router_redirect_test.dart` FIRST and confirm
    RED. Reuse the existing `_pumpRouter` helper and its fake-notifier tree unchanged — it already
    supplies SettingsNotifier, GoalsNotifier, RestorativesNotifier, ScheduleNotifier,
    CommitmentsNotifier and ThemeNotifier, which is exactly what TodayScreen's empty-state path
    needs. Update the `_FakeThemeNotifier` doc comment that names HomeScreen to name TodayScreen.
    For the destination-count case, read `tester.widget` of `find.byType(NavigationRail)` and
    assert on its `destinations` length and on the label Text of each destination.

    In `lib/router.dart`: import `screens/today/today_screen.dart` and drop the
    `screens/home/home_screen.dart` and `screens/schedule/schedule_screen.dart` imports. Change
    `initialLocation` to `/today`. In the redirect callback keep the two onboarding lines FIRST
    and change the already-onboarded target from `/home` to `/today`, then add one line after
    them: when `state.matchedLocation` equals exactly `/schedule`, return `/today`. Comment it
    with UNIFY-02, the exact-match requirement, and the fact that main.dart:86 depends on it.

    Collapse the branches from four to three. Branch 0 becomes the merged destination and declares
    two routes: `/today` building `const TodayScreen()`, and `/schedule` building
    `const TodayScreen()` with its existing `checkin` child route moved across verbatim. Delete
    the old `/home` route and the old standalone `/schedule` branch. Leave the Goals and Settings
    branches byte-identical — go_router renumbers branch indices from the array order, so no
    manual index arithmetic is needed anywhere (P6). Add a comment on the `/schedule` route
    explaining it exists to parent `/schedule/checkin` and as a dead-route backstop.

    In `lib/widgets/responsive_shell.dart`: replace the first two entries of `_destinations` with a
    single `(icon: Icons.today_outlined, label: 'Today')` and drop the
    `Icons.calendar_today_outlined / 'Schedule'` entry, leaving Today, Goals, Settings in that
    order. Update the comment above `_destinations` to read `(Today=0, Goals=1, Settings=2)`.
    Update the file-header comment block: the UI-SPEC "four destinations" icon-library lock is
    superseded by 22-UI-SPEC.md "Navigation contract (UNIFY-02)" — record that explicitly with a
    pointer to that document (D-09 requires updating the note, not silently violating it), and
    keep the D-11 720dp breakpoint note and the NavigationRailLabelType.all rule exactly as they
    are. Update the class doc comment's "four primary branches" wording. Change nothing about
    `_goBranch` or either navigation widget's construction — the collapse is otherwise mechanical.

    Do NOT touch `lib/main.dart`. Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>flutter test test/screens/router_redirect_test.dart && grep -q "initialLocation: '/today'" lib/router.dart && grep -q "matchedLocation == '/schedule'" lib/router.dart && grep -q "path: 'checkin'" lib/router.dart && grep -q 'TodayScreen' lib/router.dart && ! grep -q "path: '/home'" lib/router.dart && test "$(grep -c 'StatefulShellBranch(' lib/router.dart)" = "3" && grep -q "label: 'Today'" lib/widgets/responsive_shell.dart && ! grep -q "label: 'Schedule'" lib/widgets/responsive_shell.dart && ! grep -q "label: 'Home'" lib/widgets/responsive_shell.dart && grep -q "router.go('/schedule')" lib/main.dart && flutter analyze</automated>
  </verify>
  <done>The router has three branches with /today as the initial location, /schedule normalises to /today via an exact-match redirect that runs after the onboarding gate, /schedule/checkin still resolves, the shell shows Today/Goals/Settings with the superseded lock note updated, main.dart is unmodified, and every router_redirect_test case passes.</done>
</task>

<task type="auto">
  <name>Task 2: Delete the replaced screens and migrate their tests (P1, P5, P13, G4)</name>
  <files>lib/screens/home/home_screen.dart, lib/screens/home/widgets/active_chunk_card.dart, lib/screens/schedule/schedule_screen.dart, lib/screens/schedule/widgets/now_marker.dart, test/screens/home_screen_now_state_test.dart, test/screens/today_screen_now_state_test.dart, test/screens/active_chunk_card_test.dart, test/screens/content_width_constraint_test.dart</files>
  <read_first>
    - test/screens/home_screen_now_state_test.dart — the whole file. The pure resolveNowState group (lines 141-378) moves untouched; the HomeScreen widget group (lines 380 to end) is repointed
    - test/screens/active_chunk_card_test.dart — the whole file, to confirm against the coverage map below that nothing is lost by deleting it
    - test/screens/content_width_constraint_test.dart lines 106-138 and 184-205 — the HomeScreen pump helper to repoint and the permanently-skipped ScheduleScreen case to remove
    - 22-PATTERNS.md section 2 — the NowMarker entry: "the file has zero other callers, so if dropped it should be deleted, not left dead"
  </read_first>
  <action>
    **Coverage map — confirm each line before deleting anything.** `active_chunk_card_test.dart` is
    deleted rather than rewritten because every assertion it carries already has a home from plans
    22-02 and 22-03. Verify each of these exists and passes BEFORE running the delete:

    | Assertion in active_chunk_card_test.dart | Where it lives now |
    |---|---|
    | Complete renders as a labelled FilledButton with no hover | 22-02 today_row_widgets_test.dart, LiveRowCard group |
    | Skip renders as a labelled OutlinedButton | same |
    | A "Now" badge is present | same, as the "RIGHT NOW" kicker |
    | The goal name renders | same, as the title |
    | Tapping Complete calls markComplete with the chunk id | same |
    | Tapping Skip calls markSkipped with the chunk id | same |
    | The clock-time range renders | same (remainingLabel) plus chunk_card_goal_name_test.dart |
    | The card renders at all | same, find.byType(LiveRowCard) |
    | HomeScreen shows a "Now" section label | superseded by D-01 (there are no zones); 22-03 asserts the live row renders inline in the list |
    | HomeScreen shows a "Next" section label | 22-03 asserts the "Next ·" line inside the live row |
    | HomeScreen shows a "See full schedule" TextButton | INVERTED by D-08 — 22-03 asserts it is findsNothing |
    | A card renders for the current chunk | this task's today_screen_now_state_test.dart |
    | No card when every chunk is resolved | same |

    If any row of that map is not actually covered, STOP and report rather than deleting.

    **Check the map against the file, not the map against itself** (plan-checker finding,
    2026-08-07). Before `git rm`, enumerate every case in the file:

        grep -n 'testWidgets(' test/screens/active_chunk_card_test.dart

    The file holds **14** `testWidgets` cases; the map above lists 13 rows and omits two:
    - `'renders duration fallback when displayStartMinutes is null'` (~line 186) — likely moot
      under the new architecture, since a live row implies `Active`/`Overdue` and therefore a
      resolved start time. Confirm that reasoning holds against the built `TodayScreen` before
      dropping it; if the null-start path is still reachable for any row type, re-home it.
    - `'uses no hardcoded Colors'` (~line 222) — superseded by 22-02's grep gate against
      `Colors.` in `live_row_card.dart`. Confirm that gate exists and passes; it is the
      replacement, so it must be green before this deletion.

    Any case present in the grep output but absent from both the map and these two notes is an
    unreviewed assertion — STOP and report it rather than deleting the file.

    `git mv test/screens/home_screen_now_state_test.dart test/screens/today_screen_now_state_test.dart`.
    In the moved file: drop the `screens/home/home_screen.dart` and
    `screens/home/widgets/active_chunk_card.dart` imports, add `screens/today/today_screen.dart`
    and `screens/today/widgets/live_row_card.dart`, and keep the `screens/today/now_state.dart`
    import added in plan 22-01. Rename `_pumpHomeScreen` to `_pumpTodayScreen`, swap
    `HomeScreen(now: now)` for `TodayScreen(now: now)`, and add a `_FakeRestorativesNotifier`
    (overriding `loadItems` to a no-op) to its MultiProvider so the mood-gated restoratives read
    cannot reach Hive. Replace every `find.byType(ActiveChunkCard)` with
    `find.byType(LiveRowCard)`. Leave the entire `resolveNowState unit tests` group byte-identical
    — it is the strongest existing asset in this phase and must not be rewritten. Update the file
    header comment and the stale `_HomeScreenState` reference in the timer-count case to name
    TodayScreen. Where a case asserts a removed Now/Next section LABEL rather than the card, repoint
    it at the equivalent live-row assertion; where a case asserts one of the edge-state copies
    ("Your day starts at", "Up next", "That's a wrap"), leave the expectation exactly as it is —
    plan 22-03 preserved those strings word for word.

    `git rm test/screens/active_chunk_card_test.dart`.

    In `test/screens/content_width_constraint_test.dart`: swap the HomeScreen import for
    TodayScreen, rename `_pumpHomeScreenAt` to `_pumpTodayScreenAt`, pump `TodayScreen(now: ...)`
    with the same frozen clock, and add a `_FakeRestorativesNotifier` to its provider list. Delete
    the permanently-skipped "Schedule screen ListView region" case (lines 184-205) and its TODO
    comment — ScheduleScreen no longer exists and the TodayScreen case is now the single POLISH-01
    guard for this surface. Update the file header comment accordingly.

    Then delete the four replaced source files with `git rm`: `lib/screens/home/home_screen.dart`,
    `lib/screens/home/widgets/active_chunk_card.dart`, `lib/screens/schedule/schedule_screen.dart`,
    `lib/screens/schedule/widgets/now_marker.dart`. Deleting schedule_screen.dart is what finally
    removes `_buildActiveChunkItems`, the second "now" detector 22-PATTERNS.md section 5 flagged as
    the phase's top risk (P1). NowMarker has no other callers, so it is deleted rather than left
    dead (P5).

    Run `dart format lib/ test/`, `flutter analyze`, and the full suite.
  </action>
  <verify>
    <automated>! test -f lib/screens/home/home_screen.dart && ! test -f lib/screens/home/widgets/active_chunk_card.dart && ! test -f lib/screens/schedule/schedule_screen.dart && ! test -f lib/screens/schedule/widgets/now_marker.dart && ! test -f test/screens/active_chunk_card_test.dart && ! test -f test/screens/home_screen_now_state_test.dart && test -f test/screens/today_screen_now_state_test.dart && grep -q 'TodayScreen' test/screens/today_screen_now_state_test.dart && grep -q 'LiveRowCard' test/screens/today_screen_now_state_test.dart && ! grep -q 'ActiveChunkCard' test/screens/today_screen_now_state_test.dart && grep -q 'TodayScreen' test/screens/content_width_constraint_test.dart && ! grep -q 'skip: true' test/screens/content_width_constraint_test.dart && flutter analyze && flutter test</automated>
  </verify>
  <done>All four replaced source files are gone, the now-state suite lives at today_screen_now_state_test.dart pumping TodayScreen with its resolveNowState unit group untouched, active_chunk_card_test.dart is deleted with every assertion accounted for elsewhere, content_width_constraint_test.dart guards the merged screen, and the full suite is green.</done>
</task>

<task type="auto">
  <name>Task 3: Tidy the orphaned directories and sweep for dead references (P8, D-09)</name>
  <files>lib/screens/home/widgets/end_of_day_card.dart, lib/screens/home/widgets/review_banner.dart, lib/screens/today/widgets/end_of_day_card.dart, lib/screens/today/widgets/review_banner.dart, lib/screens/today/today_screen.dart, test/end_of_day_card_test.dart, test/screens/home_screen_breathing_pulse_test.dart, test/screens/breathing_pulse_cta_test.dart</files>
  <read_first>
    - lib/screens/home/widgets/end_of_day_card.dart — the EndOfDayCard widget plus the top-level shouldShowEodCard function at line 99, and the doc comment naming HomeScreen
    - lib/screens/home/widgets/review_banner.dart — the doc comment naming HomeScreen
    - test/screens/responsive_layout_test.dart — confirm 22-PATTERNS.md section 3.5 still holds: it builds its own dummy four-branch router and asserts no real destination count
  </read_first>
  <action>
    `lib/screens/home/` now contains only two widgets whose screen no longer exists. Move them
    next to their sole consumer: `git mv lib/screens/home/widgets/end_of_day_card.dart
    lib/screens/today/widgets/end_of_day_card.dart` and the same for `review_banner.dart`. Fix
    the relative import depth inside both files, update the two import lines in
    `lib/screens/today/today_screen.dart`, and update the single import in
    `test/end_of_day_card_test.dart`. Update both files' doc comments to say "the Today screen"
    instead of "HomeScreen". Confirm `lib/screens/home/` is now empty and remove the directory.

    `git mv test/screens/home_screen_breathing_pulse_test.dart
    test/screens/breathing_pulse_cta_test.dart` — its subject moved to
    `lib/screens/today/widgets/breathing_pulse_cta.dart` in plan 22-03 and its name should follow.
    Update its header comment; its import was already corrected in that plan, so no code change is
    needed.

    Confirm 22-PATTERNS.md section 3.5's prediction (P8): `test/screens/responsive_layout_test.dart`
    tests the breakpoint mechanism against its own self-contained dummy router and does NOT assert
    a real destination count, so the four-to-three collapse needs no edit there. Verify by grepping
    for a hardcoded 4 and by running the file unchanged. If a stale count assertion HAS crept in,
    fix it and say so in the summary — do not leave it silently failing.

    Final dead-reference sweep across `lib/` and `test/`: there must be no remaining occurrence of
    `HomeScreen`, `ScheduleScreen`, `ActiveChunkCard`, `NowMarker`, or the string `'/home'` —
    including in comments, which are how stale mental models get inherited. Where a comment
    legitimately describes history, rewrite it to name the Today screen rather than deleting the
    context. Then run `dart format`, `flutter analyze`, and the full suite one final time and record
    the resulting test count in the summary alongside the pre-phase count.
  </action>
  <verify>
    <automated>test -f lib/screens/today/widgets/end_of_day_card.dart && test -f lib/screens/today/widgets/review_banner.dart && ! test -d lib/screens/home && test -f test/screens/breathing_pulse_cta_test.dart && ! test -f test/screens/home_screen_breathing_pulse_test.dart && ! grep -rn --include=*.dart -E 'HomeScreen|ScheduleScreen|ActiveChunkCard|NowMarker' lib test && ! grep -rn --include=*.dart "'/home'" lib test && flutter test test/screens/responsive_layout_test.dart && flutter analyze && flutter test</automated>
  </verify>
  <done>lib/screens/home/ is gone, the end-of-day card and review banner live beside the Today screen, the breathing-pulse test is named after its subject, responsive_layout_test.dart passes unchanged, no dead reference to either old screen survives anywhere in lib/ or test/, and the full suite is green with flutter analyze clean.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| deep link / URL bar to the app shell | On web any path is reachable directly. The go_router redirect callback is the only gate between an arbitrary path and an authenticated-equivalent surface (post-onboarding app state). |
| OS notification payload to in-app navigation | NotificationService.onTapCallback calls router.go with a hardcoded path. The payload chooses nothing; the path is compiled in. |
| shell branch index to route | ResponsiveShell passes a positional index into navigationShell.goBranch; the destination list and the branch array must stay in the same order. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-22-13 | Elevation of Privilege | the /schedule redirect bypassing the onboarding gate | mitigate | The onboarding checks stay FIRST in the redirect callback and the /schedule normalisation is appended after them. Two regression cases pin it: onboardingComplete=false with /schedule and with /schedule/checkin must both land on /onboarding. This preserves the existing T-router-1 mitigation from Phase 6. |
| T-22-14 | Denial of Service | a dead /schedule route stranding the daily Chunk-reminder notification | mitigate | Belt and braces: the top-level redirect normalises /schedule to /today AND the declared /schedule route builds TodayScreen, so neither a redirect regression nor a redirect miss can produce a blank screen. A regression case asserts main.dart's exact call resolves to /today, and a verify gate asserts main.dart itself is unmodified. |
| T-22-15 | Denial of Service | the /schedule redirect swallowing /schedule/checkin and breaking the morning check-in | mitigate | Exact matchedLocation equality only — no startsWith, no route-level parent redirect. A regression case asserts /schedule/checkin resolves to itself. |
| T-22-16 | Tampering (navigation correctness) | destination-to-branch index drift after the four-to-three collapse | mitigate | Goals and Settings branches are left byte-identical and go_router renumbers from array order; the _destinations comment is updated to the new mapping; a widget case asserts the rail has exactly three destinations with the expected labels. |
| T-22-17 | Repudiation (silent coverage loss) | deleting active_chunk_card_test.dart drops assertions nobody re-homed | mitigate | An explicit thirteen-row coverage map is checked off against live, passing tests before the delete, with a STOP instruction if any row is unmet. |
| T-22-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this plan. Routing uses the already-declared go_router dependency. |
</threat_model>

<verification>
- `flutter test test/screens/router_redirect_test.dart` — GREEN, including the four new UNIFY-02 cases.
- `flutter test test/screens/today_screen_now_state_test.dart test/screens/content_width_constraint_test.dart test/screens/responsive_layout_test.dart` — GREEN.
- `flutter test` — full suite green; the summary records the pre-phase and post-phase counts and explains the delta (cases moved from active_chunk_card_test.dart into today_row_widgets_test.dart, today_screen_test.dart and today_screen_now_state_test.dart, plus the removed permanently-skipped ScheduleScreen case).
- `flutter analyze` — clean.
- `git status` shows four source deletions, one test deletion, and four renames.
- Grep confirms no `HomeScreen`, `ScheduleScreen`, `ActiveChunkCard`, `NowMarker` or `'/home'` anywhere in `lib/` or `test/`.
- Grep confirms `lib/main.dart` still contains `router.go('/schedule')` — the notification path works through the redirect, not through an edit.
</verification>

<success_criteria>
- UNIFY-02 met in full: the shell reflects the merge (three destinations, none called Home or
  Schedule), a notification tap lands on the working unified screen, a `/schedule` deep link
  resolves to `/today`, and `/schedule/checkin` is untouched.
- G2: the destination list no longer points at two separate screens for the same content.
- G3: the Chunk-reminder path is regression-tested end to end at the router level.
- G4 / D-08: the "see full schedule" affordance is gone along with the file that held it.
- D-09: the superseded four-destination lock note is rewritten with a pointer to 22-UI-SPEC.md's
  navigation contract, not silently violated.
- P1 finally closed: the second "now" detector no longer exists anywhere in the codebase.
- The suite is green and `flutter analyze` is clean, with every deleted test's coverage accounted
  for in writing.
</success_criteria>

<output>
Create `.planning/phases/22-unified-today-screen/22-04-SUMMARY.md` when done.
</output>
