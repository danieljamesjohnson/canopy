---
phase: 35-your-real-commitments-read-from-your-calendar
plan: 04
subsystem: ui
tags: [flutter, calendar, settings, provider, go_router]

requires:
  - phase: 35-01
    provides: "CalendarSource interface, NullCalendarSource, defaultCalendarSource platform switch, CalendarSyncService, CommitmentsNotifier.syncFromCalendar"
  - phase: 35-03
    provides: "AppSettings.selectedCalendarIds/icsUrls/lastCalendarSyncAt and their SettingsNotifier setters"
provides:
  - "CalendarSettingsScreen: mobile CTA-gated permission flow (not-yet-requested / in-flight / granted-grouped-by-account / granted-empty / denied-neutral-card) and desktop/web ICS feed-URL flow (add/remove, fetch-validated)"
  - "/settings/calendars route and the Settings screen's Calendar section row"
  - "checkin_screen.dart now syncs from the persisted feed configuration instead of a no-op empty source, and persists lastCalendarSyncAt on success"
affects: ["35-05", "35-06"]

actuals:
  tokens: 14712
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "CTA-gated permission request: the mobile branch never calls CalendarSource.requestPermission() automatically — only in response to a tap on 'Allow calendar access' — so opening the screen never surprises the user with a native OS prompt, while still satisfying D-35-10's 'read live, never persist' rule"
    - "defaultTargetPlatform (not dart:io Platform) for the screen's own mobile/desktop branch decision, testable via debugDefaultTargetPlatformOverride — matches commitments_screen.dart/goals_screen.dart/restoratives_screen.dart's existing isMobileTouch idiom"
    - "debugDefaultTargetPlatformOverride must be set/reset via try/finally bracketing the test body itself, not setUp/tearDown — Flutter's debugAssertAllFoundationVarsUnset invariant check runs before tearDown callbacks"

key-files:
  created:
    - lib/screens/settings/calendar_settings_screen.dart
    - test/screens/settings/calendar_settings_screen_test.dart
  modified:
    - lib/router.dart
    - lib/screens/settings/settings_screen.dart
    - lib/screens/schedule/checkin_screen.dart
    - test/screens/checkin_screen_widget_test.dart
    - test/screens/cold_launch_morning_loop_test.dart

key-decisions:
  - "Mobile permission flow is CTA-gated (tap 'Allow calendar access' before requestPermission() is ever called), not eagerly auto-fired on screen open. RESEARCH.md's own permission-status switch groups notDetermined with the CAL-04 fallback bucket, meaning the screen itself — not the source — must own the 'not yet asked' pre-state; auto-firing on open would also risk popping a native OS dialog the instant the user opens Settings > Calendars, before any explanatory copy is on screen."
  - "The Settings entry row's 'Calendars' subtitle is computed synchronously from persisted SettingsNotifier state only — no live CalendarSource query happens just from opening the main Settings list (that would either flicker or, on a real device, risk an OS prompt). This means the locked 'Calendar access denied' subtitle text has no reachable code path yet: 35-03 deliberately added no persisted denial field (D-35-10), and mobile has no real device source until 35-05."
  - "The device-row subtitle template '{n} of {m} calendars selected' is approximated as '{n} of {n}' — the total-available count (m) is not knowable synchronously without a live device query, and no such total is persisted. 35-05's real DeviceCalendarSource is the natural place to give this row a true signal."
  - "The footer's sync status and skipped-events disclosure are driven by a REAL sync (CommitmentsNotifier.syncFromCalendar → the actual CalendarSyncService mapping), triggered automatically once a source becomes configured (permission granted on mobile, icsUrls non-empty on desktop) — not a hand-built result. This lets Task 2's skipped-events test exercise the real 35-02 mapping/reason-string logic rather than re-deriving it."
  - "'Open Settings' (denied card) is a real, reachable button with no OS deep-link wired yet — this screen imports no plugin package (acceptance-criteria enforced), and 35-05's DeviceCalendarSource is the plan that lands the actual OS settings hand-off."

patterns-established:
  - "A settings detail screen with a live, tap-gated permission flow: Future<State>? starts null (CTA state), sets to a Future on tap, FutureBuilder renders the in-flight/resolved states — reusable shape for any future OS-permission-backed settings surface."

requirements-completed: [CAL-02, CAL-04]

coverage:
  - id: D1
    description: "Settings shows a Calendar section with a 'Calendars' row whose subtitle states the real state (Not connected / N of N selected / N calendar(s) subscribed), each with a synced-relative-time suffix"
    requirement: "CAL-02"
    verification:
      - kind: manual_procedural
        ref: "code inspection — settings_screen.dart _calendarSubtitle; no automated widget test pumps SettingsScreen's Calendar row in this plan"
        status: unknown
    human_judgment: true
    rationale: "No widget test in this plan pumps SettingsScreen itself to assert the row's rendered subtitle text across all four states — Task 2's tests target CalendarSettingsScreen, not the Settings list row. Verifiable by a human opening Settings in the running app."
  - id: D2
    description: "The calendar picker lists exactly the calendars the source reports, grouped by account, with a checkbox each — CAL-02, mutation-proofed"
    requirement: "CAL-02"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#granted with several calendars across two accounts renders the fake's exact list, grouped by account (CAL-02)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Ticking/unticking a calendar persists immediately through SettingsNotifier, no Save step"
    requirement: "CAL-02"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#tapping a checkbox persists the calendar id in the notifier selection"
        status: pass
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#unticking a calendar removes the id from the notifier selection"
        status: pass
    human_judgment: false
  - id: D4
    description: "A denied/restricted permission renders a NEUTRAL outlined card, never the error color — CAL-04, mutation-proofed"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#denied renders the neutral card and Open Settings — never the error role (CAL-04)"
        status: pass
    human_judgment: false
  - id: D5
    description: "With permission denied, hand-entered commitments remain fully reachable and editable — nothing on the Commitments screen depends on a calendar source existing"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#CommitmentsScreen renders and stays fully interactive independent of any calendar permission state"
        status: pass
    human_judgment: false
  - id: D6
    description: "Granted with zero calendars renders the empty state, not a blank screen; a pending permission future renders exactly one spinner and nothing else"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#granted with zero calendars renders the empty state, no checkbox"
        status: pass
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#a pending permission future shows exactly one spinner, no list"
        status: pass
    human_judgment: false
  - id: D7
    description: "A long device-reported calendar name ellipsizes on one line and never overflows"
    requirement: "CAL-02"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#a 120-character calendar name renders on one line with no overflow"
        status: pass
    human_judgment: false
  - id: D8
    description: "A sync failure surfaces the locked SnackBar copy and previously-imported commitments stay on screen; check-in now syncs the actually-configured feed instead of a no-op empty source, and persists lastCalendarSyncAt on success only"
    requirement: "CAL-02"
    verification:
      - kind: manual_procedural
        ref: "code inspection — calendar_settings_screen.dart _syncAndReport (SnackBar only on result.failed, setLastCalendarSyncAt only on !result.failed) and checkin_screen.dart's mirrored success-only persist; no automated test forces a sync failure in this plan"
        status: unknown
    human_judgment: true
    rationale: "Forcing an actual fetch/parse failure through the fake source and asserting the SnackBar text would require a scenario Task 2's behavior list did not name; verifiable by a human via the add-URL form's own validation failure path (already covered) or a real unreachable feed in 35-06's UAT."
  - id: D9
    description: "The skipped-events disclosure line and its detail sheet render the real 35-02 skip reasons (Cancelled, Too short to schedule) for events the fake source reports"
    requirement: "CAL-02"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#a sync result with 2 skipped events renders the disclosure and the sheet lists both, with their reasons"
        status: pass
    human_judgment: false

duration: 90min
completed: 2026-09-15
status: complete
---

# Phase 35 Plan 04: The Calendars screen — every state in the design contract Summary

**`CalendarSettingsScreen` with a CTA-gated mobile permission flow and a fetch-validated desktop/web ICS feed-URL flow, wired to a real sync (not a placeholder), reachable from Settings, and never error-tinting a denied permission.**

## Performance

- **Duration:** ~90 min
- **Completed:** 2026-09-15
- **Tasks:** 3
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments

- `lib/screens/settings/calendar_settings_screen.dart` (new, ~800 lines): the full CAL-02/CAL-04 surface —
  mobile branch (not-yet-requested CTA → in-flight spinner → granted-grouped-by-account list / granted-empty
  / denied-neutral-card, tap-gated so the OS prompt never fires just from opening the screen) and
  desktop/web branch (no-URL CTA → feed list with fetch-validated add and confirmed remove). A shared footer
  (sync status + skipped-events disclosure sheet + "Sync now") is driven by a REAL sync through
  `CommitmentsNotifier.syncFromCalendar`, not a hand-built result.
- `/settings/calendars` route added as a sibling of `/settings/past-reviews`; Settings screen gains a
  "Calendar" section with a `ListTile` whose subtitle is computed synchronously from persisted
  `SettingsNotifier` state (no live permission query from the main Settings list).
- `checkin_screen.dart`'s tracer-era no-op (`defaultCalendarSource()` with an empty argument list) is closed:
  it now builds the source from `SettingsNotifier.icsUrls` and persists `lastCalendarSyncAt` on success only.
- 9 widget tests in `test/screens/settings/calendar_settings_screen_test.dart` cover every state in the
  design contract's inventory, driven by a throwaway fake `CalendarSource`; two mutation proofs performed
  and reverted (below).

## Task Commits

1. **Task 1: The Calendars screen — every state in the design contract** — `6426f47` (feat)
2. **Task 2: Prove the picker shows the device's list and the denial stays usable** — `7ff9add` (test)
3. **Task 3: Wire the configured source into the real sync trigger** — `f0bc10f` (feat)

**Plan metadata:** this commit (`docs(35-04): complete plan` — see Final Commit below)

## Files Created/Modified

- `lib/screens/settings/calendar_settings_screen.dart` — the new screen (created in Task 1, extended in Task 3 with "Sync now" and the CORS doc comment)
- `test/screens/settings/calendar_settings_screen_test.dart` — the 9-test CAL-02/CAL-04 proof, plus two mutation proofs performed and reverted
- `lib/router.dart` — `/settings/calendars` route
- `lib/screens/settings/settings_screen.dart` — "Calendar" section + `Calendars` row + `_calendarSubtitle`/`_relativeSyncTime`
- `lib/screens/schedule/checkin_screen.dart` — real feed configuration passed to `defaultCalendarSource`, `lastCalendarSyncAt` persisted on success
- `test/screens/checkin_screen_widget_test.dart` — added a `SettingsNotifier` to the provider tree (Task 3 deviation, see below)
- `test/screens/cold_launch_morning_loop_test.dart` — same fix (Task 3 deviation, see below)

## Decisions Made

**Mobile permission flow is CTA-gated, not eagerly auto-fired on screen open.** `CalendarSource.requestPermission()`
is only ever called from the "Allow calendar access" button's `onPressed`, never automatically in `initState`
or `build`. This resolves a real tension in the plan's own source material: D-35-10 says "query live... on
every build" (arguing for eager), but the UI-SPEC's own state table lists "Not yet requested" (a CTA with
a button) as a *distinct* state from "Requesting (in flight)" — and 35-RESEARCH.md's permission-status
switch statement explicitly groups `notDetermined` into the same "fall back to Null/CAL-04" bucket as
`denied`/`restricted`, meaning the SCREEN, not the plugin call, must own the "never asked yet" pre-state.
Auto-firing on open would also mean opening Settings > Calendars could pop a native OS permission dialog
before the user has seen any explanation — bad UX this design avoids. "Live, never cached" is satisfied
because nothing about the eventual result is ever written to `AppSettings`/Hive; it's re-derived from
scratch (starting at `null`) every time the widget is constructed.

**The Settings entry row does not query CalendarSource live.** Unlike the detail screen, the Settings list's
"Calendars" row subtitle is computed purely from persisted `SettingsNotifier` fields
(`selectedCalendarIds`/`icsUrls`/`lastCalendarSyncAt`). Doing a live query there risked either a visible
flicker (`FutureBuilder` inside a summary row) or, on a real device once 35-05 lands, an unwanted permission
prompt from simply opening the Settings tab. Consequence: the locked "Calendar access denied" subtitle text
has no reachable code path in this plan — recorded as a known limitation below, not silently glossed over.

**`{n} of {m} calendars selected` is approximated as `{n} of {n}`.** The total-available count on the device
is not knowable synchronously from the main Settings row without a live query, and 35-03 deliberately
persists no such total. This is a real, acknowledged gap the eventual `DeviceCalendarSource` (35-05) is the
natural place to close.

**The footer's sync status and skipped-events disclosure are driven by a real sync**, triggered automatically
once a source becomes "configured" (permission just granted on mobile, `icsUrls` non-empty on desktop) —
reusing `CommitmentsNotifier.syncFromCalendar` → the real `CalendarSyncService` mapping from 35-01/35-02,
not a hand-built `CalendarSyncResult`. This let Task 2's skipped-events test exercise the actual mapping
logic (a cancelled event and a 10-minute too-short event) and assert on the real, locked reason strings
("Cancelled", "Too short to schedule") rather than re-deriving them.

**"Open Settings" has no OS deep-link wired.** The button is real, reachable, and correctly labelled, but its
`onPressed` is a documented no-op — this screen imports no device-calendar plugin (enforced by Task 1's own
acceptance grep), and the real OS hand-off requires the plugin API 35-05's `DeviceCalendarSource` introduces.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `checkin_screen.dart`'s new `SettingsNotifier` dependency broke two pre-existing widget tests**
- **Found during:** Task 3, running the full suite after wiring `checkin_screen.dart` to read `SettingsNotifier.icsUrls`
- **Issue:** `test/screens/checkin_screen_widget_test.dart` and `test/screens/cold_launch_morning_loop_test.dart`
  both pump `CheckinScreen` inside a `MultiProvider` tree that did not include a `SettingsNotifier` —
  `context.read<SettingsNotifier>()` in `_generate()` threw `ProviderNotFoundException` the moment the mood
  "Let's go" button was tapped.
- **Fix:** Added an in-memory `SettingsNotifier(repository: InMemoryAppSettingsRepository())` to each
  provider tree. A fresh instance defaults to `icsUrls: []`, which is exactly what `defaultCalendarSource`
  needs to produce the same `NullCalendarSource`/no-op sync behavior these tests already relied on
  pre-Phase-35 — so the fix does not change what either test is actually proving.
- **Files modified:** `test/screens/checkin_screen_widget_test.dart`, `test/screens/cold_launch_morning_loop_test.dart`
- **Verification:** `flutter test` — 786/786 green (777 pre-existing baseline + 9 new)
- **Committed in:** `f0bc10f` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — an unavoidable consequence of Task 3's own explicit scope: wiring `checkin_screen.dart` to a real `SettingsNotifier` dependency necessarily changes what any pre-existing test pumping `CheckinScreen` must provide).
**Impact on plan:** This directly contradicts the plan's own `<verification>` footer line "no pre-existing test edited" — recorded here rather than silently satisfied, per this repo's stated preference for honesty over a flattering checklist. The alternative (not fixing) would have left the app's real regression-test suite red, or Task 3's action item ("build the source from the persisted configuration") unimplemented. Both existing tests' actual assertions (mood → acknowledgment flow; seeded-goal → generated schedule) are unchanged — only the provider tree gained the dependency the production code now genuinely has.

## Mutation Proofs (required by acceptance criteria)

### Proof 1 — CAL-02: the picker-list assertion actually discriminates

`_groupedCalendarList` in `calendar_settings_screen.dart` was temporarily changed to iterate a hardcoded
single-calendar list instead of the `calendars` parameter passed in from the fake source:

```dart
final hardcoded = [CalendarInfo(id: 'x', name: 'Hardcoded', isReadOnly: true)];
for (final calendar in hardcoded) { ... }
```

Running `flutter test test/screens/settings/calendar_settings_screen_test.dart --name "CAL-02"` with this
defect in place:

```
Expected: exactly 3 matching candidates
  Actual: _TypeWidgetFinder:<Found 1 widget with type "CheckboxListTile": [
            CheckboxListTile(dependencies: [InheritedCupertinoTheme, _InheritedTheme,
_LocalizationsScope-[GlobalKey#255e4]]),
          ]>
   Which: is not enough
one row per calendar the fake reported
```

The defect was then reverted (`git diff --stat -- lib/screens/settings/calendar_settings_screen.dart`
empty relative to the Task 1 commit); `flutter analyze` and the full suite are green on the reverted code.

### Proof 2 — CAL-04: the denied-card color assertion actually discriminates

`_deniedCard`'s `Card(color: theme.colorScheme.surface, ...)` was temporarily changed to
`color: theme.colorScheme.errorContainer`. Running
`flutter test test/screens/settings/calendar_settings_screen_test.dart --name "denied renders"` with this
defect in place:

```
Expected: not Color:<Color(alpha: 1.0000, red: 0.9765, green: 0.8706, blue: 0.8627, colorSpace: ColorSpace.sRGB)>
  Actual: Color:<Color(alpha: 1.0000, red: 0.9765, green: 0.8706, blue: 0.8627, colorSpace: ColorSpace.sRGB)>
a denied permission is not an error (CAL-04)
```

The defect was then reverted; `flutter analyze` and the full suite are green on the reverted code
(confirmed via `git diff --stat` against the Task 1 commit being empty for this file at that point).

## Issues Encountered

**`debugAssertAllFoundationVarsUnset` fired when `debugDefaultTargetPlatformOverride` was set/reset via
`setUp`/`tearDown`.** Flutter's own invariant check runs *before* `tearDown` callbacks execute, so every
test in the file failed with "The value of a foundation debug variable was changed by the test" even
though `tearDown` did reset it. Fixed by moving the set/reset into a `try/finally`-bracketed helper
(`_withMobilePlatform`) wrapping each test body directly — the same pattern already established in
`test/screens/goal_card_drag_handle_test.dart`, re-discovered rather than copied verbatim since the plan's
`<read_first>` didn't point at that file for this plan.

**`find.byTooltip(...)` did not return the `IconButton` it decorates.** The CAL-04 Commitments-screen test
initially tried `tester.widget<IconButton>(find.byTooltip('Delete commitment'))`, which threw
`type 'RawTooltip' is not a subtype of type 'IconButton'` — `find.byTooltip` returns the `Tooltip`
wrapper, not the button inside it. Fixed with `find.widgetWithIcon(IconButton, Icons.delete_outline)`.

## Known Stubs

- **"Open Settings" (denied card) has no OS deep-link.** `onPressed: () {}` with a doc comment explaining
  the plugin dependency (`device_calendar_plus`) this screen deliberately does not import. Resolved by
  35-05's `DeviceCalendarSource` plan, which is the first plan with a reason to add that import.
- **Settings entry row "Calendar access denied" subtitle has no reachable code path.** No permission-denial
  signal is persisted (by design, D-35-10) and mobile has no real device source until 35-05 — the row
  currently reads "Not connected" for both "never asked" and "denied," which is honest but not the exact
  locked text for the denied case specifically. See Decisions Made above.
- **`{n} of {m} calendars selected` approximated as `{n} of {n}`.** No persisted "total calendars on device"
  count exists to supply the real `m`. See Decisions Made above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `CalendarSettingsScreen` is fully built and reachable at `/settings/calendars`; its mobile branch is
  ready for 35-05 to inject a real `DeviceCalendarSource` — the screen's own contract (CTA-gated
  `requestPermission()`, `listCalendars()`, grouping by `accountName`) requires no changes on this
  screen's side, only a real implementation behind the interface.
- The desktop/web ICS branch is fully functional today (add/remove feeds, fetch-validated, real sync) and
  is what 35-06's UAT will exercise via `flutter build web --debug`.
- `checkin_screen.dart` now syncs the actually-configured feed on every check-in, closing the tracer's
  deliberate no-op (D-35-13) — 35-06's UAT can rely on a check-in actually importing events from a
  configured feed, not just the Calendars screen's own manual sync.
- The two known-stub gaps (Open Settings deep-link, denied-row subtitle text, {m} approximation) are all
  scoped to 35-05's device-permission work and don't block 35-06's UAT, which runs on web/desktop.

## Self-Check: PASSED

All 7 created/modified files confirmed present via `test -f`: `lib/screens/settings/calendar_settings_screen.dart`,
`test/screens/settings/calendar_settings_screen_test.dart`, `lib/router.dart`, `lib/screens/settings/settings_screen.dart`,
`lib/screens/schedule/checkin_screen.dart`, `test/screens/checkin_screen_widget_test.dart`,
`test/screens/cold_launch_morning_loop_test.dart`. All 3 commits (`6426f47`, `7ff9add`, `f0bc10f`) confirmed
present in `git log --oneline --all`. No missing items.

---
*Phase: 35-your-real-commitments-read-from-your-calendar*
*Completed: 2026-09-15*
