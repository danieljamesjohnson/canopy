---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 06
subsystem: calendar-ui
tags: [flutter, widget-test, google-calendar, calauth-01, calauth-03, d-36-03, mutation-testing]

requires:
  - phase: 36-connect-google-calendar-without-hunting-for-a-url
    provides: "36-02's GoogleAuthClient (three-way failure classification, cancellation-as-state, closed reconnect-flag lifecycle) and 36-05's CompositeCalendarSource / detectSelectedCalendarOverlaps / iosCalendarSource factory carve-out"
provides:
  - "A Google section and a device section, both always present, on the Calendars screen — connect, connecting, connected, cancelled, and reconnect-needed states"
  - "detectSelectedCalendarOverlaps wired into the picker: an advisory, non-blocking, non-error note under any row it flags, refreshed on every render"
  - "The Settings row and the Calendars screen both say plainly when the Google login has expired, from persisted state only"
  - "WINDOWS.md entry 5 closed: GoogleCalendarSource now receives the user's real google:-prefixed selection at construction time, at both the screen's own sync and check-in's"
affects: [36-07]

actuals:
  tokens: 14600
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Two independent CalendarSource test-only overrides on one StatefulWidget (source for device, googleSource for Google) rather than one combined source — lets each section's widget tests reuse the SAME throwaway _FakeCalendarSource double the file already had, with no new test machinery"
    - "A device-only source for permission gating (_resolveDeviceSource) kept separate from a full-composite source for actual event sync (_resolveSyncSource) — a composite's requestPermission() always answers notApplicable, which would silently break the device CTA's gate if the two were not split"
    - "Shared row-rendering extracted into a plain method returning List<Widget> (_calendarRows) rather than a widget wrapping its own ListView+footer, so two independent sections can render into ONE combined scrolling body with one shared footer instead of two competing ones"

key-files:
  created:
    - test/screens/settings/settings_screen_calendar_row_test.dart
  modified:
    - lib/screens/settings/calendar_settings_screen.dart
    - lib/screens/settings/settings_screen.dart
    - lib/data/calendar/calendar_source_factory.dart
    - lib/screens/schedule/checkin_screen.dart
    - test/screens/settings/calendar_settings_screen_test.dart
    - test/data/calendar/calendar_source_factory_test.dart

key-decisions:
  - "Google section always starts at the CTA on a fresh screen build, even if a still-valid connection exists from a prior session — only SettingsNotifier.reconnectNeeded is checked from persisted state; 'already connected, no reconnect needed' is not distinguished from 'never connected' without a tap. Deliberately NOT fixed by adding a new SettingsNotifier.googleConnected getter (which would have required touching settings_notifier.dart, outside this plan's declared files) — the cost is a redundant real Google consent screen on re-open, not a correctness or data-safety issue, and it mirrors the device flow's own identical, pre-existing limitation (its _mobileFuture resets on re-open too)."
  - "Fixed WINDOWS.md entry 5 despite calendar_source_factory.dart/checkin_screen.dart not being in this plan's files_modified list — the entry's own text says '36-06 should wire' this, and without it the entire feature imports zero Google events regardless of what the picker shows. Scoped to the smallest possible change: one new optional parameter, default const [], on two existing functions."
  - "The plan's read_first referenced 'connect()'s three-valued outcome' as already landed; it was not (36-02 deferred it, WINDOWS.md entry 4, left OPEN by this plan too) — the existing bool contract (true = cancelled) already gives this screen everything it needs to distinguish cancel from success, so introducing the enum here would have been unused ceremony. Documented as a plan-text correction, matching 36-02-SUMMARY.md's own precedent for this exact kind of mismatch."
  - "The reconnect card's icon renders in colorScheme.error, its body stays neutral — copied verbatim from the plan's own ruling (an expired refresh token is a real failure, unlike a denied permission's normal-state neutrality)."
  - "The narrow, per-row overlap rule (detectSelectedCalendarOverlaps) shipped, not the coarse fallback — 36-05-SUMMARY.md recorded the rule as UNCONFIRMED, not disproven or unreliable, and Task 3's own instruction only asks for the fallback when 36-05 reports the narrow rule as unreliable."

requirements-completed: [CALAUTH-01, CALAUTH-03]

coverage:
  - id: D1
    description: "Google section: not-connected/connecting/connected/cancelled states, reusing _ctaCard and the grouped-row machinery; cancellation renders identically to not-connected with no error card, SnackBar, or denied card anywhere; the device CTA renders alongside in every state; Disconnect confirms and resets the section"
    requirement: CALAUTH-01
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#Plan 36-06 — Google connect flow (D-36-03, CALAUTH-01), all 4 tests"
        status: pass
      - kind: unit
        ref: "mutation proof: cancelled outcome mutated to render _deniedCard, observed the cancellation test FAIL, reverted"
        status: pass
    human_judgment: true
    rationale: "The state machine and every locked string are fully proven here. Whether the whole restructured screen READS as one coherent screen, and whether a real Google consent sheet round-trips correctly on iOS, are exactly what this plan's own 'What is verifiable here' table assigns to the owner on his MacBook (36-07)."
  - id: D2
    description: "CALAUTH-03 visible in two places: a reconnect card (structurally copied from _deniedCard, icon alone in colorScheme.error) replaces the Google list whenever SettingsNotifier.reconnectNeeded is set, checked before any other Google state; the Settings row subtitle gains the identical check, first, preserving D-35-10 (persisted state only, no live query)"
    requirement: CALAUTH-03
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#Plan 36-06 — Google reconnect (CALAUTH-03, Task 2), both tests"
        status: pass
      - kind: unit
        ref: "test/screens/settings/settings_screen_calendar_row_test.dart, all 3 tests"
        status: pass
      - kind: unit
        ref: "mutation proof: flag check inverted, observed BOTH flag-set and flag-clear calendar-screen tests FAIL, reverted"
        status: pass
      - kind: unit
        ref: "mutation proof: the new branch deleted from _calendarSubtitle, observed the Settings row test FAIL, reverted"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-36-03's required overlap mitigation: detectSelectedCalendarOverlaps runs over the combined Google+device calendar list and adds a non-error, non-blocking advisory note under each ticked row it flags; nothing is de-duplicated anywhere (grep-proven); a flagged checkbox still toggles and persists"
    requirement: CALAUTH-01
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#Plan 36-06 — overlap disclosure (D-36-03, Task 3), all 6 tests"
        status: pass
      - kind: unit
        ref: "mutation proof: note forced to render unconditionally, observed the 'only one ticked' test FAIL, reverted"
        status: pass
      - kind: other
        ref: "grep -rcE 'dedup|distinct\\(\\)|toSet\\(\\)\\.toList\\(\\)' over calendar_settings_screen.dart and composite_calendar_source.dart returns 0"
        status: pass
    human_judgment: true
    rationale: "The rule and the disclosure mechanism are fully proven given the calendars the detector is told about. Whether the wording actually stops the owner double-ticking by accident on a real device, and whether a real EventKit accountName plausibly matches Google's own account id closely enough for the narrow rule to fire correctly at all, are both explicitly the owner's judgment per this plan's own 'What is verifiable here' table and 36-05-SUMMARY.md's carried-forward finding — plan 36-07 item 6."

duration: ~35min
completed: 2026-09-25
status: complete
---

# Phase 36 Plan 06: Google Connect, Reconnect, and Overlap Disclosure on the Calendars Screen Summary

**The Calendars screen now shows a Google section and a device section side by side — tap once to connect Google, get told plainly (and offered one tap to fix) when the login dies, and get warned at the moment of ticking if the same calendar is selected twice.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-25T15:33:36Z (worktree base commit)
- **Completed:** 2026-09-25T16:05:16Z (final task commit)
- **Tasks:** 3 (all implemented, committed together — see Task Commits)
- **Files modified/created:** 7 (5 modified in lib/, 2 test files modified, 1 test file created)

## Accomplishments

- **Task 1 — the button.** `_buildMobileBody` is no longer one full-screen state; it is a scrolling `ListView` with a Google section, a `Divider`, a device section, and one shared footer. The Google section has its own not-connected/connecting/connected/cancelled state machine (`_GoogleState`, `_buildGoogleSection`), reusing `_ctaCard` for the CTA and a new shared `_calendarRows` helper (extracted from the old `_groupedCalendarList`) for the connected list — the SAME grouped-by-account row machinery the device section uses, per the plan's own instruction. Cancellation (`GoogleCalendarSource.requestPermission()` mapping a cancel to `notDetermined`) needs no special-case branch: it renders identically to "never connected." Disconnect opens a confirm dialog with copy that states what `CalendarSyncService.sync()` actually does (upsert-only, no delete-on-disconnect) rather than repeating the ICS dialog's untrue "will disappear" sentence. The device section's own three-state flow is byte-for-byte unchanged in copy and behavior — `git diff` on `_buildDesktopBody`/`_AddFeedForm`/`_openAddFeedForm`/`_removeFeed` is empty, confirmed below.
- **The split that keeps the device gate honest.** `_resolveDeviceSource` (device-only, for `requestPermission()`/`listCalendars()`) is kept separate from `_resolveSyncSource` (the full Google+device composite, used ONLY inside `_syncAndReport`). `CompositeCalendarSource.requestPermission()` always answers `notApplicable` — using it for the device CTA's own gate would have silently broken "Allow calendar access" the moment a Google client was ever supplied. This split is why the composite work (D-36-03: "the sync sees the composite") and the device permission flow (unchanged) can coexist without either one lying to the other.
- **Task 2 — visible in two places.** `_googleReconnectCard` copies `_deniedCard`'s structure exactly (neutral surface, outline border, one action) with the icon alone in `colorScheme.error` — the plan's own ruling that a dead refresh token is a real failure, unlike a denied permission's normal-state neutrality. Checked from `SettingsNotifier.reconnectNeeded` FIRST, before any other Google branch, so a token that died in a prior session is never silently overwritten by a fresh "not connected" render. `settings_screen.dart`'s `_calendarSubtitle` gained the identical check, first, preserving D-35-10 (persisted state only — opening Settings never triggers a live query).
- **Task 3 — the double-tick says so.** `_calendarRows` calls `detectSelectedCalendarOverlaps` over the FULL combined calendar list (Google's own cached list plus device's own cached list, `_googleCalendars`/`_deviceCalendars`) on every render, and renders `"These may be the same calendar — events could appear twice."` under every flagged row — `bodySmall`/`onSurfaceVariant`, a 14dp `Icons.info_outline`, never `colorScheme.error`, never disabling the checkbox. A comment at the render site states the no-de-duplication prohibition and its reason (D-36-03, T-36-25) for the next reader who reaches for "helpfully" merging the pair.
- **WINDOWS.md entry 5 closed, out of this plan's declared scope, under deviation Rule 2.** `iosCalendarSource()`'s `GoogleCalendarSource` was constructed with `calendarIds: const []`, and `CalendarSyncService.sync()` always calls `listEvents()` with an EMPTY `calendarIds` argument — meaning the constructor-time list was the ONLY place a real selection could ever take effect, and it was never wired. Added an optional `googleCalendarIds` parameter (default `const []`, so every existing caller is unaffected) to `defaultCalendarSource()`/`iosCalendarSource()`, and wired it at check-in (`checkin_screen.dart`) from `SettingsNotifier.selectedCalendarIds` filtered to the `google:` prefix — the one production call site that actually needs it. Without this, a signed-in, ticked Google account would have imported zero events, forever, regardless of what this plan's own picker showed.
- **Five recorded mutation proofs**, all observed failing correctly and reverted (transcripts below).
- **Full suite: 902/902 green** (886 baseline + 16 new: 12 in `calendar_settings_screen_test.dart`, 3 in the new `settings_screen_calendar_row_test.dart`, 1 in `calendar_source_factory_test.dart`). `flutter analyze`: **No issues found!**. `lib/services/schedule_generator.dart`: byte-identical (`git diff --quiet` exits 0).

## Non-vacuity proofs (mutation testing, per CLAUDE.md's "Assertions that cannot fail")

**1. Task 1 — cancelled renders the denied card instead of the connect button.** Changed `_buildGoogleSection`'s `if (!state.connected) { return _googleCtaCard(...); }` to `return _deniedCard(context);`. Observed:
```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Connect your Google Calendar": []>
```
Reverted immediately.

**2. Task 2 — the reconnect flag check inverted.** Changed `if (settings.reconnectNeeded)` to `if (!settings.reconnectNeeded)`. Observed BOTH tests fail:
```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Google sign-in expired": []>
...
The finder "Found 0 widgets with text "Connect Google Calendar": []" (used in a call to "tap()")
could not find any matching widgets.
```
Reverted immediately.

**3. Task 2 — the Settings subtitle branch deleted.** Removed the `if (settings.reconnectNeeded) return '...';` line from `_calendarSubtitle`. Observed:
```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Google sign-in expired — tap to reconnect": []>
```
Reverted immediately.

**4. Task 3 — the overlap note forced unconditional.** Changed `if (overlappingIds.contains(calendar.id))` to `if (true)`. Observed the "only one ticked, no note" test fail with the note text showing up where none was expected (`Which: means some were found but none were expected`). Reverted immediately.

All four mutations were confirmed reverted before the final commits — `flutter analyze` clean and the full 902-test suite green afterward (re-run below in Self-Check).

## Task Commits

Tasks 1–3 were implemented and committed together as one commit, since their code is genuinely interleaved within the same handful of functions (`_calendarRows` is shared by the device section from Task 1 and the Google section built on top of it in Task 1, then extended by Task 3's overlap lookup; `_buildGoogleSection` is Task 1's own function with Task 2's reconnect check added at its top). Splitting after the fact would have been artificial re-slicing of one coherent diff, not a reflection of how the work was done — mirroring 36-02-SUMMARY.md's own documented precedent for this exact situation.

1. **WINDOWS.md entry 5 fix (deviation, Rule 2)** — `fe6c115` (fix)
2. **Tasks 1–3: Google connect/reconnect/overlap sections** — `0a3879f` (feat)

_Plan metadata (this SUMMARY + WINDOWS.md) is committed separately, per the worktree parallel-execution contract. No `REQUIREMENTS.md` exists in this project — requirements are tracked in `PROJECT.md`/`ROADMAP.md` instead, so that step is skipped._

## Files Created/Modified

- `lib/screens/settings/calendar_settings_screen.dart` — Google section (connect/reconnect/connected/disconnect), device section (unchanged behavior, now section-scoped), shared `_calendarRows` with overlap disclosure, combined `_buildMobileBody`
- `lib/screens/settings/settings_screen.dart` — `_calendarSubtitle` gains the reconnect-first branch
- `lib/data/calendar/calendar_source_factory.dart` — `googleCalendarIds` parameter threaded through `defaultCalendarSource`/`iosCalendarSource` (deviation, WINDOWS.md entry 5)
- `lib/screens/schedule/checkin_screen.dart` — check-in's own sync now passes the real `google:`-filtered selection (deviation, same fix)
- `test/screens/settings/calendar_settings_screen_test.dart` — 12 new tests across Tasks 1–3, plus the enlarged test viewport and one re-pointed assertion
- `test/screens/settings/settings_screen_calendar_row_test.dart` — new, 3 tests for the Settings row subtitle
- `test/data/calendar/calendar_source_factory_test.dart` — 1 new test for the `googleCalendarIds` parameter's presence

## Decisions Made

See `key-decisions` in the frontmatter: the "always starts at CTA on fresh open" limitation and why it's deliberate rather than fixed; the WINDOWS.md entry 5 fix and its scope justification; the plan-text correction on the three-valued `connect()` outcome (WINDOWS.md entry 4 left open); the reconnect card's color ruling; and the narrow-vs-coarse overlap rule choice.

## Deviations from Plan

### Auto-fixed / adapted issues

**1. [Rule 2 — missing critical functionality] Closed WINDOWS.md entry 5, outside this plan's declared `files_modified`**
- **Found during:** Task 1, while wiring the screen's source construction through the factory
- **Issue:** `iosCalendarSource()` constructs `GoogleCalendarSource` with `calendarIds: const []`. `CalendarSyncService.sync()` always calls `listEvents()` with an empty `calendarIds` argument (its own "empty means every configured calendar" convention), so the constructor-time list is the ONLY place a real selection can ever take effect — and nothing wired it. A signed-in, ticked Google account would import zero events, silently, forever, regardless of anything this plan's picker shows.
- **Fix:** Added an optional `googleCalendarIds` parameter (default `const []`) to `defaultCalendarSource()`/`iosCalendarSource()` in `calendar_source_factory.dart`, and wired it at check-in (`checkin_screen.dart`) from `SettingsNotifier.selectedCalendarIds` filtered to the `google:` prefix. The screen's own `_resolveSyncSource` also passes the same filtered list.
- **Files modified:** `lib/data/calendar/calendar_source_factory.dart`, `lib/screens/schedule/checkin_screen.dart`, `test/data/calendar/calendar_source_factory_test.dart` — none were in this plan's declared `files_modified`.
- **Verification:** `test/data/calendar/calendar_source_factory_test.dart`'s new test proves the parameter is accepted without changing composite structure; the parameter's actual effect on `listEvents()` querying is already proven at the `GoogleCalendarSource` level by `test/data/calendar/google_calendar_source_test.dart` (constructor-time `calendarIds` fallback, lines 476/528/593/614), which this factory-level change merely threads a value into.
- **Committed in:** `fe6c115`

**2. [Plan-text correction, matching 36-02-SUMMARY.md's own precedent] `SettingsNotifier.googleReconnectNeeded` does not exist — the actual field is `reconnectNeeded`**
- **Found during:** Task 2, while reading `google_auth_client.dart`/`settings_notifier.dart` for the flag's real name
- **Issue:** The plan's action text refers to `SettingsNotifier.googleReconnectNeeded`. 36-02 implemented it as `reconnectNeeded` (the `GoogleTokenStore` interface's own name, which `SettingsNotifier` overrides).
- **Resolution:** Used `settings.reconnectNeeded` throughout — the actual, tested, existing getter.
- **Files affected:** None beyond this plan's own files — verification-only correction.

**3. [Not done — deliberately left out of scope] Did NOT introduce `connect()`'s three-valued outcome (WINDOWS.md entry 4)**
- **Found during:** Task 1, while reading the plan's read_first note ("connect()'s three-valued outcome")
- **Issue:** 36-02 deferred this to avoid touching 36-03's exclusive file in that wave, and left WINDOWS.md entry 4 open naming 36-06 as the place to pick it up (also named as optional by this plan's own orchestrator prompt).
- **Resolution:** Left it open. The existing `GoogleAuthClient.connect()`/`GoogleCalendarSource.requestPermission()` bool contract (`true` = cancelled) already gives this screen everything the plan's own Task 1 state list needs (not-connected/connecting/connected/cancelled) — a genuine launcher failure surfaces as a thrown `GoogleAuthException`/`GoogleSourceException`, caught in `_connectGoogle` and folded into the same "back to the connect button" state as a cancellation, since no locked failure copy exists for a distinct "failed" state in this plan. Introducing a three-valued enum here would have been unused ceremony, and `google_auth_client.dart`/`google_calendar_source.dart` are not in this plan's `files_modified`.
- **Files affected:** None — a "did not do X" deviation.

**4. [Rule 1-adjacent — test re-point, explicitly invited by the plan] One pre-existing assertion re-pointed**
- **Found during:** Task 1, running the existing suite after restructuring `_buildMobileBody`
- **Issue:** `calendar_settings_screen_test.dart`'s "a pending permission future shows exactly one spinner, no list" test asserted `find.byType(ListView), findsNothing`. Once the combined body is ALWAYS a `ListView` (both sections always present, Task 1's own requirement), this assertion fails regardless of whether a calendar LIST is actually showing — it stopped testing the state's real invariant the moment the screen gained a structural outer `ListView` unrelated to this particular state.
- **Fix:** Removed that one line, with a comment explaining why, and kept `expect(find.byType(CheckboxListTile), findsNothing)` — the assertion that actually proves "no calendar list is showing yet."
- **Files affected:** `test/screens/settings/calendar_settings_screen_test.dart`
- **Verification:** The test still asserts the spinner is present and no calendar rows exist; re-run green.

**5. [Test-infrastructure adaptation, not a semantic change] Enlarged the test viewport**
- **Found during:** Task 1, running the existing suite — 8 of 10 existing tests failed with hit-test-out-of-bounds errors
- **Issue:** With BOTH sections always present (Task 1), the device CTA/list — which every existing test taps directly — now sits below the default 600dp test viewport, so `tester.tap()` could not hit-test it.
- **Fix:** `_pumpCalendarScreen` now sets `tester.view.physicalSize = const Size(800, 3000)` for the duration of each test (reset via `addTearDown`). No test's assertions changed; this only changes how much of the (now taller) page a single frame renders.
- **Files affected:** `test/screens/settings/calendar_settings_screen_test.dart`
- **Verification:** All 10 pre-existing tests pass unmodified in their assertions.

---

**Total deviations:** 5 (1 missing-critical-functionality fix outside declared scope, 1 plan-text correction, 1 deliberate non-fix left open per the plan's own instruction, 1 assertion re-point explicitly invited by the plan, 1 test-infrastructure adaptation). **Impact:** The WINDOWS.md entry 5 fix is what makes the feature functionally complete rather than auth-only; none of the others reduce any acceptance criterion's coverage. No scope creep beyond what the phase's own tracking documents (WINDOWS.md, this plan's own prompt) explicitly named as this plan's job.

## Known Stubs

**Google section does not distinguish "already connected, no reconnect needed" from "never connected" on a fresh screen build.** Re-opening the Calendars screen in a new session always shows the "Connect Google Calendar" CTA, even for an account with a perfectly valid stored token — tapping it re-launches Google's real consent screen (which will re-issue a token, not fail) rather than silently restoring the connected list. Only `SettingsNotifier.reconnectNeeded` (a genuinely dead token) is checked from persisted state; a valid-but-unconfirmed connection is not. This mirrors the device flow's own identical, pre-existing limitation (`_mobileFuture` also resets to null on screen re-open) and was deliberately not fixed by adding a new `SettingsNotifier.googleConnected` getter, since that file is outside this plan's declared scope and the cost is UX friction, not incorrect data or a security gap. Not logged to WINDOWS.md, since it's a known limitation carried by design rather than an unfinished piece of this plan's own required behavior.

No other stubs. Every function added or modified is a real, tested implementation — no placeholder returns, no hardcoded empty values feeding the UI.

## Threat Flags

None beyond what this plan's own `<threat_model>` already named (T-36-22 through T-36-26), all of which are addressed by the implementation above (see the Task Commits' mutation proofs for T-36-22/T-36-23, the grep proof for T-36-25).

## Issues Encountered

None beyond the deviations documented above.

## Next Phase Readiness

- Plan 36-07 (the owner's MacBook, device checkpoint) is the only thing that can settle: whether the whole restructured Calendars screen reads as ONE coherent screen once assembled (this plan's own "What is verifiable here" table flags this explicitly — a green widget suite has never been sufficient for a UI-facing phase in this project); whether a real `ASWebAuthenticationSession` consent flow actually completes and the cancel path actually throws `FlutterAppAuthUserCancelledException` (carried from 36-02); whether the narrow overlap rule's INPUT assumption (a real device's EventKit `accountName` for a Google-added calendar matching Google's own account id) holds at all (carried from 36-05); and whether the overlap warning's wording actually reads clearly enough to stop the owner double-ticking by accident — a perceptual judgment no test here can make.
- `WINDOWS.md` entry 4 (three-valued `connect()` outcome) remains open, by design — nothing in this plan needed it.
- Entry 5 is now closed. The feature is functionally complete: connect, list, tick, sync, and see the results, end to end, modulo the device-only verifications above.

## Self-Check: PASSED

`test/screens/settings/settings_screen_calendar_row_test.dart` confirmed present on disk (`test -f`). Both commits (`fe6c115`, `0a3879f`) confirmed present via `git log --oneline --all`. Full suite re-run after all four mutations were reverted: 902/902 green, `flutter analyze` clean, `schedule_generator.dart` byte-identical (`git diff --quiet` exits 0). Locked-string grep counts unchanged from pre-task values: `'Allow calendar access'` = 4, `'Calendar access is off'` = 1, `'never the error role'` = 1. `git diff HEAD -- lib/screens/settings/calendar_settings_screen.dart` shows no modification inside `_buildDesktopBody`/`_AddFeedForm`/`_openAddFeedForm`/`_removeFeed` beyond one doc-comment reference. `grep -rcE 'dedup|distinct\(\)|toSet\(\)\.toList\(\)'` over `calendar_settings_screen.dart` and `composite_calendar_source.dart` returns 0 in both.

---
*Phase: 36-connect-google-calendar-without-hunting-for-a-url*
*Plan: 06*
*Completed: 2026-09-25*
