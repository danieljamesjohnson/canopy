---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 10
subsystem: calendar-settings
tags: [google-calendar, settings-notifier, windows-entry-6, calauth-03]
dependency-graph:
  requires: [36-09]
  provides: [settings-notifier.googleConnected]
  affects: [calendar_settings_screen]
tech-stack:
  added: []
  patterns:
    - "In-build ??= lazy future initialisation (mirrors _desktopFuture's existing idiom), now also used for the Google section's restore path"
key-files:
  created: []
  modified:
    - lib/providers/settings_notifier.dart
    - lib/screens/settings/calendar_settings_screen.dart
    - test/providers/settings_notifier_calendar_test.dart
    - test/screens/settings/calendar_settings_screen_test.dart
decisions:
  - "WR-05 (transient listCalendars() failure right after sign-in forces an unnecessary re-consent) is deliberately NOT fixed here — the restore path inherits the same connected:false fold _connectGoogle already uses on failure, by design, per the plan's explicit scope boundary. See 'WR-05 status' below."
metrics:
  duration: "~35 minutes"
  completed: 2026-10-06
status: complete
actuals:
  tokens: 4346
  tasks: 2
  commits: 2
  plan_head_before: 5a0134b19dde1e3ebe98572f90ce67c7fa3dfe96
  plan_head_after: 3314e3caba6a664ea76888251dae853f37b0fa8f
---

# Phase 36 Plan 10: Google section restores itself without re-launching consent Summary

Closed WINDOWS entry 6: re-opening Settings -> Calendars with a valid stored Google token now
shows the connected section (calendar rows + Disconnect) immediately, without ever calling
Google's `requestPermission()` — proven by a call-count assertion, not by inspection — while a
dead token still wins the CALAUTH-03 precedence check unchanged.

## What Was Built

**Task 1 — `SettingsNotifier.googleConnected`:** a new synchronous `bool` getter derived from the
same two cached fields `read()` null-guards on (`_googleAccessToken`,
`_googleAccessTokenExpiresAt`), ANDed with `!_googleReconnectNeeded`. It is the synchronous
counterpart of `read() != null && !reconnectNeeded`, needed inside `build()` which cannot await.
A past expiry still counts as connected on purpose — `GoogleAuthClient.authenticatedClient()`
refreshes a stale access token silently, and only a refresh classified dead sets
`reconnectNeeded`.

Six tests added in a new group (`test/providers/settings_notifier_calendar_test.dart`), one per
named state (empty repo -> false; write() -> true; setReconnectNeeded(true) -> false;
setReconnectNeeded(false) -> true; clear() -> false; past expiry -> still true). None derive
their expectation from `read()` or the getter's own expression.

**Task 2 — the Google section restores from persisted state:** a new
`Future<_GoogleState> _loadGoogleCalendars(SettingsNotifier)` resolves the Google source and
calls `listCalendars()` only — never `requestPermission()`. `_buildGoogleSection` now
initialises `_googleFuture` via the existing `??=`-in-build idiom (the same pattern
`_buildDesktopBody` already uses for `_desktopFuture`) when `_googleFuture` is null **and**
`settings.googleConnected` is true — placed **after** the unchanged, unmoved
`settings.reconnectNeeded` check, so CALAUTH-03's dead-token-wins ordering is untouched. On any
throw, `_loadGoogleCalendars` folds into the same `_GoogleState(connected: false)` shape
`_connectGoogle` already returns on its own failure path.

`_googleFuture`'s stale doc comment (which used to document the very limitation this plan fixes)
was rewritten to describe what actually happens now.

`_FakeCalendarSource` in the test file gained a `requestPermissionCount` counter. Four new tests
cover: a valid stored token renders the connected section with the CTA absent and
`requestPermissionCount == 0` (the load-bearing assertion); a dead token still wins the
reconnect card even with a token stored; no stored token still renders the plain CTA; and
confirming Disconnect leaves the CTA up and a subsequent fresh build (new widget instance, same
notifier) does not resurrect the connected view.

## Deviations from Plan

None — plan executed exactly as written. Both tasks matched their `<action>` sections without
needing an architectural change or an out-of-scope fix.

## Mutation Proofs (real observed failure text, both reverted)

**Task 1 — dropping the `!_googleReconnectNeeded` conjunct from `googleConnected`:**
```
after setReconnectNeeded(true) on a connected notifier it reports false — a dead token is not a connection [E]
  Expected: false
    Actual: <true>
```
Reverted immediately after observing this failure.

**Task 2(a) — making the restore path call `requestPermission()` before `listCalendars()`:**
```
a valid stored token renders the connected section on first build, with the Connect CTA absent and
requestPermission never called [E]
  Expected: <0>
    Actual: <1>
```
This is the load-bearing `requestPermissionCount == 0` assertion firing exactly as the plan
predicted. Reverted immediately after observing this failure.

**Task 2(b) — removing the restore branch entirely (reverting to the pre-fix code):**
```
a valid stored token renders the connected section on first build, with the Connect CTA absent and
requestPermission never called [E]
  Expected: no matching candidates
    Actual: _TextWidgetFinder:<Found 1 widget with text "Connect Google Calendar": [...] >
   Which: means one was found but none were expected
```
The CTA-absent assertion firing when the restore branch is gone — exactly the defect WINDOWS
entry 6 describes. Reverted immediately after observing this failure.

All three mutations were introduced with `Edit`, run against the real test suite to confirm a
genuine (non-compile-error) red, then reverted back to the passing implementation before moving
on — no mutation was left in place across a commit boundary.

## CALAUTH-03 ordering — confirmed preserved

`settings.reconnectNeeded` is still the first check in `_buildGoogleSection`, unmoved and
unmodified; the new `googleConnected` restore branch is inserted strictly after it. The existing
"Plan 36-06 — Google reconnect (CALAUTH-03, Task 2)" test group (both pre-existing tests) passed
unchanged, and a new Task 2 test ("a dead token still wins...") independently re-proves the same
ordering with a token now present in storage — both reconnectNeeded=true scenarios render the
reconnect card, never the connected section, and `requestPermissionCount` stays 0 in both.

## 36-09's banner — confirmed still first and un-tinted

This plan's changes to `calendar_settings_screen.dart` touch only `_googleFuture`'s doc comment,
`_loadGoogleCalendars` (new method), and the body of `_buildGoogleSection` — `_buildMobileBody`
and `_buildDesktopBody` (where 36-09 placed `_skippedBanner(context)` first) were not touched.
Both of 36-09's own banner-position tests
("the disclosure renders ABOVE the Google section's 'Connect Google Calendar' button..." and
"the disclosure appears exactly once on screen — moved, not duplicated") were re-run as part of
the full suite and pass unchanged.

## WR-05 status — still open, not resolved here

**WR-05 is NOT resolved by this plan**, and this was a deliberate scope boundary, not an
oversight. `_loadGoogleCalendars`'s catch block folds any `listCalendars()` throw into
`_GoogleState(connected: false)` — the exact same shape `_connectGoogle` already uses on its own
failure path — so a transient listing failure immediately after a successful restore still shows
the plain "Connect Google Calendar" CTA rather than a distinct "temporarily unavailable" state.
The next tap would force a full, unnecessary re-consent, exactly as WR-05 describes.

Evidence this was not incidentally fixed: `_loadGoogleCalendars`'s own doc comment names WR-05
explicitly and states the inheritance is intentional ("introducing a fourth Google state would
need new user-visible copy... copy belongs to an owner-reviewed UI-SPEC, not to an agent"). No
test in this plan exercises a `listCalendars()` throw on the restore path with an assertion that
a distinct state renders — only the five behaviors the plan specified (connected, dead-token,
no-token, disconnect-then-rebuild) are covered.

## Verification Results

- `flutter test test/providers/settings_notifier_calendar_test.dart` — 15/15 passed (6 new).
- `flutter test test/screens/settings/calendar_settings_screen_test.dart test/screens/settings/settings_screen_calendar_row_test.dart` — 31/31 passed (4 new).
- `flutter test` (full suite) — **934/934 passed**, strictly above plan 36-09's closing count of 924 (10 new tests: 6 in Task 1, 4 in Task 2).
- `flutter analyze` — "No issues found!" (ran twice: after Task 1, and again after Task 2's revert).
- `git diff 8f62a56 -- lib/services/schedule_generator.dart` — empty. The scheduling engine is byte-identical.
- `lib/screens/settings/settings_screen.dart` — untouched (not in this plan's `files_modified`, and `git status` confirms no change).

## Self-Check

- FOUND: `lib/providers/settings_notifier.dart` has `bool get googleConnected`.
- FOUND: `lib/screens/settings/calendar_settings_screen.dart` has `_loadGoogleCalendars`.
- FOUND: both commits are ancestors of HEAD (verified below).
