# Phase 22: Unified Today Screen - Pattern Map

**Mapped:** 2026-08-07
**Files analyzed:** ~10 (2 screens to merge/delete, ~8 widgets, shell, router, main.dart caller)
**Analogs found:** all — this phase is a merge of two existing screens, so the closest analog to
the new file is almost always "the two files being merged," not a third file.

## 1. What each screen currently owns

### `lib/screens/home/home_screen.dart` (848 lines, `StatefulWidget` — needs state for the
1-minute timer)

| Responsibility | Lines | Keep / Duplicated? |
|---|---|---|
| `NowState` sealed class + `resolveNowState()` | 21–200 | **Move out** — see §2b. Not duplicated in schedule_screen.dart (schedule_screen only does a much cruder "first unresolved" scan, §2 NowMarker). |
| `_HomeScreenState` — 1-min `Timer.periodic`, lifecycle pause/resume (`didChangeAppLifecycleState`) | 215–283 | **Keep**, becomes the merged screen's ticker. Nothing in schedule_screen.dart ticks at all — schedule_screen is a `StatelessWidget`. This is the reason the merged screen must be Stateful. |
| Review-window check (`_checkReviewWindow`, Hive completion-log + quarterly-snapshot read) | 297–314 | Keep — unique to home_screen, no duplicate. |
| `_lastScheduleDateYmd` reset of `_eodCardDismissed` on new day (`didChangeDependencies`) | 284–295 | Keep — unique. |
| AppBar with re-check-in refresh action | 344–353 | **Duplicated** — schedule_screen.dart:62–66 has the identical `IconButton(Icons.refresh) → context.push('/schedule/checkin')`. Merge to one. |
| `ScheduleProgressBar` usage | 361 | **Duplicated** — schedule_screen.dart:101 uses the same widget identically (`schedule`, `moodColor`). Trivial merge. |
| Review banner / EOD card | 362–372 | Keep — unique to home. |
| "Now" + "Next" zone (`_buildNowContent`, `_buildPreStartContent`, `_buildGapBeforeNextContent`, `_buildDayCompleteContent`) | 373–540 | This IS the live-row concept the UI-SPEC wants inlined into the list instead of a separate zone — becomes Phase 23's live row, but the *state machine* driving it is exactly `resolveNowState`, reused as-is. |
| Goal-name/rationale lookup (`_lookupGoalName`) | 512–521 | **Duplicated** — schedule_screen.dart:335–339 `_lookupGoalName` (via `_resolveGoal`) does the same goalId→GoalsNotifier.goals lookup. Home's version is simpler (no Goal object cache); schedule's `_resolveGoal` pattern (319–326) is the better one to keep since chunk_card.dart-derived widgets also need color/priority/valence/emoji, all sharing `_resolveGoal`. |
| "See full schedule" link → `context.go('/schedule')` | 488–498 (`home_screen.dart:495`) | **Delete**, per CONTEXT.md — repointing it would link the merged screen to itself. |
| Empty state (`_buildEmptyState`) | 669–725 | **Duplicated concept, different copy** — schedule_screen.dart:426–494 has its own empty state with a web-only `MaterialBanner` and an "Add an event" affordance home's doesn't have. The merge must reconcile these into one empty state; schedule's is the more complete one (has `_openAddEvent` access), home's is simpler and has the breathing-pulse CTA (`BreathingPulseCta`, 735–848) which schedule's does not. **Risk:** the breathing-pulse CTA and the "Add an event" access are both real features from different screens — dropping either regresses a shipped feature. |
| `BreathingPulseCta` (top-level public widget) | 735–848 | Keep as-is; unrelated to the merge mechanics, just needs to keep being reachable from the merged empty state. |

### `lib/screens/schedule/schedule_screen.dart` (495 lines, `StatelessWidget`)

| Responsibility | Lines | Keep / Duplicated? |
|---|---|---|
| AppBar: title "Today", mood-colored background, Add-event / re-check-in / Start-focus / "View your day" popup menu | 51–98 | **Mostly unique** — home_screen's AppBar only has the refresh action. The merged screen's AppBar needs schedule's fuller action set (add event, focus entry, summary popup) plus home's title "Canopy" vs schedule's "Today" — CONTEXT.md says the merged destination's label is "not Home"; UI-SPEC's header shows "Today" as an in-body heading, not an AppBar title (§Structure: "Header — 'Today' + the date... Stays put; not a collapsing app bar" — this is a body element per the sketch, not `AppBar.title`). |
| `ScheduleProgressBar` | 101 | Duplicated (see above). |
| Restorative suggestions on low-mood days (`_buildRestorativeSuggestions`) | 130–201 | Keep — unique to schedule, no duplicate in home. Reads `RestorativesNotifier`, not touched by home_screen at all — new provider dependency the merged screen must add. |
| `_buildActiveChunkItems` + `NowMarker` insertion (crude scan: first unresolved chunk, or first chunk whose `displayStartMinutes >= nowMinutes`) | 203–244 | **This is the OLD, cruder "now" logic that `resolveNowState` was written to replace** (see Phase 17 note in §5). It is NOT the same algorithm as `resolveNowState` and must not survive the merge as a second, competing "now" detector — that would reintroduce the exact bug Phase 17 fixed. Drop this function; the merged list positions itself using `resolveNowState`'s classification instead. `NowMarker` the *widget* (visual divider) is still useful as a component, see §2. |
| `_buildSwipeableCard` / `SwipeableChunkCard` (Complete/Skip swipe gesture on live chunks) | 259–282 | Keep — this is the live-row action affordance UI-SPEC calls "Actions row — Complete / Skip — for work chunks only." home_screen's `ActiveChunkCard` duplicates Complete/Skip as buttons (not swipe) for the single "now" card; UI-SPEC's live row keeps the button form ("Actions row" with explicit labels, not swipe-only — SCHED-03 v1.2 requires labelled, hover-free actions). **Reconcile: the merged live row is `ActiveChunkCard`-style labelled buttons, not swipe.** Swipe interaction on regular (non-live) rows is a separate, still-valid affordance for the rest of the list. |
| Skipped-chunks `ExpansionTile` section | 284–314 | Keep — no equivalent in home_screen; UI-SPEC's row vocabulary (dimmed/struck-through "skipped") suggests these may now render inline in the single timeline instead of a collapsible section — a genuine design decision for planning, not just a code copy. |
| Goal lookups (`_resolveGoal` + 5 derived getters: color/name/priority/valence/emoji) | 316–362 | **Duplicated** with home's simpler `_lookupGoalName`/`_lookupGoalColor`/`_lookupGoalPriorityWeight` (home_screen.dart has 3 of the 5; schedule has all 5 plus emoji/valence). Merge onto schedule's fuller `_resolveGoal` pattern — home's versions are a subset. |
| `_openDetailSheet` → `ChunkDetailSheet` bottom sheet | 369–393 | Keep — no equivalent in home; tapping any non-live row in the merged timeline should open this, per existing behavior. |
| `_openAddEvent` → `showAdaptiveFormModal` + `CommitmentFormSheet` | 395–424 | Keep — inherited contract (RESP-01/02/03) explicitly called out in UI-SPEC "Inherited contracts." No home_screen equivalent. |
| Empty state (`_buildEmptyState`) | 426–494 | See home's empty-state row above — reconcile the two. |

## 2. Widget inventory

| Widget | Renders | Called by | Merged screen: keep / absorb / drop |
|---|---|---|---|
| `lib/screens/home/widgets/active_chunk_card.dart` (247 lines) | The single "Now" card: goal name, time range, "Now" badge, priority chip, Complete/Skip filled/outlined buttons | `home_screen.dart:532,534` (Active/Overdue states) | **Absorb** — becomes the template for UI-SPEC's "live row" swelled-card treatment (labelled Complete/Skip, no swipe). Needs restyling to `primaryContainer`/kicker-line/progress-bar per UI-SPEC, but the button row and goal-lookup logic transplant directly. |
| `lib/screens/home/widgets/end_of_day_card.dart` (113 lines) | Dismissible EOD prompt card, `Key('end_of_day_card')` | `home_screen.dart:368` | Keep as-is, unrelated to the list/now merge. |
| `lib/screens/home/widgets/review_banner.dart` (78 lines) | Dismissible quarterly-review banner, `Key('review_banner')` | `home_screen.dart:363` | Keep as-is. |
| `lib/screens/schedule/widgets/chunk_card.dart` (468 lines) | Base card for a single chunk (work/break/commitment), incl. `_WorkChunkContent`, `_ValenceChip`, `_PriorityChip` | `schedule_screen.dart:302` (skipped section) and wrapped by `SwipeableChunkCard` | **Keep, becomes THE row renderer** for the unified timeline's completed/skipped/upcoming rows — it already has the row-type styling primitives UI-SPEC describes (work/break visual distinction). Note the standing tech-debt flag in `22-UI-SPEC.md`: `Colors.green.shade600` hardcoded — do not add more raw-color rows when extending this file for the new row types (free-time, commitment-tertiary). |
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (103 lines) | Wraps `ChunkCard` in a `Dismissible`-style swipe-to-complete/skip gesture | `schedule_screen.dart:263` (`_buildSwipeableCard`) | Keep for non-live rows in the timeline; the live row itself uses the button form, not swipe (see above). |
| `lib/screens/schedule/widgets/chunk_detail_sheet.dart` (166 lines) | Bottom sheet with full chunk detail, opened on tap | `schedule_screen.dart:385` (`_openDetailSheet`) | Keep as-is. |
| `lib/screens/schedule/widgets/now_marker.dart` (46 lines) | Thin decorative divider + "Now" label, `ExcludeSemantics`-wrapped | `schedule_screen.dart:240` (via `_buildActiveChunkItems`) | **Drop as a separate divider** — UI-SPEC's live row *replaces* the marker-before-a-plain-row pattern with an in-place swelled card; there's no longer a plain row + separate "Now" marker line, so a floating divider has no place to sit. If planning wants a visual anchor for the auto-scroll-to-center behavior (UI-SPEC "On open, the list scrolls the current row to centre"), that's a `Scrollable.ensureVisible`/`ScrollController` job on the swelled card itself, not this widget. Confirm with planner before literally deleting — the file has zero other callers (`grep` confirms only schedule_screen.dart references it), so if dropped it should be deleted, not left dead. |
| `lib/screens/schedule/widgets/schedule_progress_bar.dart` (49 lines) | Top-of-screen linear progress bar, `schedule` + `moodColor` | Both screens, identically | Keep, single instance in merged screen (was literally duplicated code, now naturally de-duplicates). |

**Widgets NOT under either `widgets/` folder but load-bearing:** `CommitmentFormSheet`
(`lib/screens/commitments/commitment_form_sheet.dart`, via `_openAddEvent`) and
`RestorativesNotifier`-driven suggestion card (inline in schedule_screen.dart, not extracted to
its own file) — both must be pulled into the merged screen's provider/import list.

## 2b. `resolveNowState` / `NowState` relocation

Currently: `sealed class NowState` + its 4 subtypes (`PreStart`, `Active`, `Overdue`,
`GapBeforeNext`, `DayComplete`) and `NowState resolveNowState({...})` live at
`lib/screens/home/home_screen.dart:21–200`, deliberately public (no leading underscore) "so unit
tests can assert `isA<PreStart>()` without a widget pump" (comment at line 24).

Two test files currently import it from `home_screen.dart`:
- `test/screens/active_chunk_card_test.dart` — imports `package:canopy/screens/home/home_screen.dart` (line 15) for `resolveNowState`/`NowState` in fixture setup, plus `active_chunk_card.dart` (line 16) for the widget itself.
- `test/screens/home_screen_now_state_test.dart` — same import (line 13), plus the `group('resolveNowState unit tests (NOW-01/NOW-02)', ...)` block (line 141) that is the primary unit-test suite for the state machine (pre-start/active/overdue/day-complete/gap-before-next cases, lines 142–320+).

**Recommendation:** since `home_screen.dart` is being deleted (merged into the new unified
screen file), `resolveNowState`/`NowState` should move to a standalone file — e.g.
`lib/screens/today/now_state.dart` (or wherever the merged screen's directory ends up,
matching whatever name planning picks per CONTEXT.md "not Home") — imported by both the new
screen and the two test files. This is a pure function with zero widget dependencies (doc
comment: "Pure function — no side effects"), so extracting it costs nothing and removes the
awkwardness of tests importing a whole screen file just for a data type.
**Both test files' imports need updating** from
`package:canopy/screens/home/home_screen.dart` to whatever the new location is — mechanical
but must not be missed, or the merge will not compile.

## 3. Shell / router pattern

`lib/widgets/responsive_shell.dart:45–50` — `_destinations` is a `static const List` of 4
`(icon, label)` records, positionally matched to `router.dart`'s branch order (comment at
line 43: "Order matches the branch order in `createRouter` (Home=0, Goals=1, Schedule=2,
Settings=3)"). `_goBranch` (line 52) calls `navigationShell.goBranch(index, ...)` — **the
shell has no other index-dependent logic**; `NavigationRail`/`NavigationBar` both derive
`selectedIndex`/`onDestinationSelected` straight from `navigationShell.currentIndex` and
`_goBranch`, so **the safest 4→3 collapse is entirely mechanical**:

1. In `router.dart:37-93`, delete the `/schedule` `StatefulShellBranch` (currently branch
   index 2, lines 65–78) and change the `/home` branch's route + builder to the unified
   screen (or rename `/home` → the new path — CONTEXT.md doesn't lock the path, only that
   the label isn't "Home"). Leave Goals and Settings branches untouched — go_router
   re-numbers indices from the branches array order automatically, no manual index math
   needed.
2. In `responsive_shell.dart:45-50`, delete the `Icons.calendar_today_outlined /
   'Schedule'` entry and rename/re-icon the first entry from `Icons.home_outlined /
   'Home'` to the merged label+icon. `_destinations` order must still match the new
   `branches` order (now 3 entries) — same convention as today, just one fewer row.
3. Add the `/schedule` **redirect** in `router.dart`'s existing `redirect:` callback
   (lines 29–36) — e.g. `if (state.matchedLocation == '/schedule') return
   '<new-path>';` — rather than as a branch. This is additive to the existing redirect
   function (which already handles onboarding gating) and does not touch branch indices at
   all, satisfying CONTEXT.md's "Keeping `/schedule` as a redirect... is acceptable and
   probably safest."
4. `lib/main.dart:86` (`router.go('/schedule')` inside `NotificationService.onTapCallback`)
   needs **no code change** if step 3's redirect is in place — `router.go('/schedule')`
   will redirect through to the unified route automatically, same mechanism go_router
   already uses for the onboarding gate. This is the least-invasive option and avoids
   touching `main.dart` at all.
5. `test/screens/responsive_layout_test.dart` (lines 1–60+) builds its own **4-branch**
   dummy `GoRouter` independent of the real `router.dart`/`responsive_shell.dart`
   destinations (`_DummyBranch` labels A/B/C/D) — it is testing the breakpoint mechanism
   generically, not the real destination list, so it does **not** need updating for the
   3-vs-4 count change. Confirm this stays true; if a future edit hardcodes "4" as an
   assertion elsewhere in that file, that's the one place a stale count could sneak in.

## 4. Test analogs

| Existing test | Covers | Use as template for |
|---|---|---|
| `test/screens/home_screen_now_state_test.dart` | Pure unit tests of `resolveNowState` (group at line 141, states pre-start/active/overdue/day-complete/gap-before-next) plus (per its own header comment) HomeScreen time-anchored widget tests | The **unit-test half** of the merged screen's now-state coverage — reuse directly once the import path is fixed (§2b). This is the strongest existing template; don't rewrite these cases, just relocate/repoint. |
| `test/screens/active_chunk_card_test.dart` | Widget-pumps `ActiveChunkCard` with `_FakeScheduleNotifier`, `_FakeGoalsNotifier`, `_FakeThemeNotifier`, `_FakeScheduleNotifierWithSchedule` (fixture classes at lines 25–57+), using `pumpWithMood` from `test/test_helpers/mood_pump.dart` | The **widget-pump-with-fakes half** — reuse the same fake-notifier classes and `pumpWithMood` helper for testing the merged live row. `_FakeScheduleNotifierWithSchedule` in particular builds a realistic `DailySchedule` fixture with clock-anchored chunks (comment at line 267 explicitly discusses `resolveNowState` clock-window selection), so it's the closest existing "build a schedule fixture for now-state tests" helper. |
| `test/screens/content_width_constraint_test.dart` | Pumps `HomeScreen` (and `GoalsScreen`) at various viewport sizes asserting the 720dp `ConstrainedBox` (`_pumpHomeScreenAt`, lines 106+); uses `_FakeScheduleNotifier` override of `hasScheduleToday => false` (empty-state path) to avoid a full schedule fixture | POLISH-01's "keeps the 720dp content constraint" requirement — mechanically the same test needs to point at the merged screen instead of `HomeScreen`; the empty-state-only fake pattern (no Hive needed) is the cheapest way to smoke-test layout without wiring a real schedule. |
| `test/screens/responsive_layout_test.dart` | `ResponsiveShell` breakpoint swap (NavigationBar↔NavigationRail at 480/720/1200dp) via a self-contained dummy 4-branch router (not the real one) | Update destination count expectations only if the test asserts count directly (see §3 point 5) — otherwise no changes needed since it doesn't reference real destinations. |
| `test/screens/router_redirect_test.dart` | Full `createRouter()` + fake notifiers (`_FakeSettingsNotifier`, `_FakeGoalsNotifier`, `_FakeScheduleNotifier` — lines 20–60+), asserts `router.routerDelegate.currentConfiguration.uri.path` after redirect, using `setViewport` from `test/test_helpers/viewport.dart` | **Best template for UNIFY-02's redirect requirement.** Add a case: `router.go('/schedule')` then assert the resolved path is the unified route — same fake-notifier + `MultiProvider` wiring already proven here to sidestep Hive I/O. |
| `test/screens/home_screen_breathing_pulse_test.dart` | Pumps `BreathingPulseCta` / reduced-motion behavior in isolation (per home_screen.dart:734 comment, "so Plan 06 Task 3 can pump it in isolation without HomeScreen's full provider tree") | Confirms `BreathingPulseCta` is already extracted for isolated testing — no change needed if the merged empty-state keeps using it; just repoint the import if the widget moves. |

**Shared fakes/helpers already in place, reuse rather than reinvent:**
`test/test_helpers/mood_pump.dart` (`pumpWithMood`), `test/test_helpers/viewport.dart`
(`setViewport`), and the per-test-file `_FakeScheduleNotifier` / `_FakeGoalsNotifier` /
`_FakeThemeNotifier` / `_FakeSettingsNotifier` pattern (each test file defines its own minimal
subclass overriding only what it reads — no shared fake file exists, that's the established
convention here, not an oversight).

## 5. Closest precedent — Phase 12 and Phase 17 constraints

- **Phase 12** (`.planning/milestones/v1.2-phases/12-home-as-landing-schedule-as-plan/`) did
  the inverse: it *split* one screen into Home (landing) + Schedule (plan). Its
  `12-CONTEXT.md` "Existing Code Insights" section is the historical record of *why* the
  two screens diverged in the first place — worth a quick read during planning to make sure
  the merge doesn't just re-fuse the two files naively and reintroduce whatever motivated
  the original split (this phase's CONTEXT.md doesn't cite a specific regression risk from
  Phase 12, so nothing concrete to flag beyond "read it before assuming the merge is a
  clean inverse").
- **Phase 17** (`.planning/milestones/v1.3-phases/17-time-anchored-home/`) added
  `resolveNowState` specifically to fix a bug where "Now" showed the first *unresolved*
  chunk rather than the chunk whose *clock window* contains the current time (NOW-01,
  17-CONTEXT.md line 28: "At 6pm with nothing checked off, the 8am chunk is no longer shown
  as 'Now'"). **Constraint the merge must not regress:** `schedule_screen.dart`'s own
  `_buildActiveChunkItems` (§1 above, lines 203–244) still uses the *old*, cruder
  first-unresolved-or-time-order scan for `NowMarker` placement — it was never migrated to
  `resolveNowState` because schedule_screen.dart doesn't import home_screen.dart. **If the
  merge is done carelessly (e.g. keeping schedule_screen's list-building code and only
  bolting `ActiveChunkCard` on top), the merged screen could end up with two disagreeing
  "now" detectors** — `resolveNowState` driving the live-row card and the old scan driving
  where `NowMarker`/list position sits. The correct merge uses `resolveNowState` as the
  single source of truth for the list's "now" position and drops
  `_buildActiveChunkItems`'s scanning logic entirely (row-type widget selection stays,
  just not the now-detection).
- Neither archived phase's `PATTERNS.md` needs to be re-read line-by-line for this phase —
  both are superseded by the current CONTEXT.md/UI-SPEC, which already cites the specific
  file:line insights that matter (`resolveNowState` location, the 1-minute timer, the
  `/schedule` callers).

## Metadata

**Analog search scope:** `lib/screens/home/`, `lib/screens/schedule/`, `lib/widgets/`,
`lib/router.dart`, `lib/main.dart`, `test/screens/`, `test/test_helpers/`,
`.planning/milestones/v1.2-phases/12-*/`, `.planning/milestones/v1.3-phases/17-*/`.
**Files scanned:** ~25 (2 screens, 8 widget files, shell, router, main.dart excerpt, 6 test
files, 2 test helpers, 2 archived phase CONTEXT.md files).
**Pattern extraction date:** 2026-08-07
