---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 05
subsystem: calendar
tags: [composite-source, overlap-detection, calauth-01, calauth-03, mutation-testing, d-36-03]

requires:
  - phase: 36-01
    provides: "The google: id prefix convention and GoogleCalendarSource's harmless-with-no-token guarantee"
  - phase: 36-02
    provides: "GoogleAuthClient's connect()/authenticatedClient() seams this plan's factory composes over"
  - phase: 36-03
    provides: "CalendarInfo.sourceLabel ('Google'/'This device'), which this plan's overlap detector keys on directly"
provides:
  - "CompositeCalendarSource — fans two CalendarSources into one, catch-per-child/rethrow-only-if-all-failed, permission always notApplicable"
  - "detectSelectedCalendarOverlaps / hasCrossSourceSelection — the narrow double-tick rule plus its required coarse fallback (D-36-03)"
  - "iosCalendarSource() / defaultCalendarSource(googleAuth:) — the factory's iOS carve-out, Google-then-device, a no-op everywhere else"
  - "checkin_screen.dart now threads a real GoogleAuthClient into the sync path"
affects: [36-06]

actuals:
  tokens: 8600
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Pure top-level function factored out of an unfakeable dart:io.Platform check purely for testability (iosCalendarSource), mirroring the mapGoogleEvent/mapDeviceEvent pure-function/adapter split already established in this phase — the real Platform.isIOS read stays as unverifiable on danserver as DeviceCalendarSource's own existing check."
    - "sourceLabel-keyed cross-source matching: the overlap detector identifies which CalendarInfos are 'Google' vs 'This device' by the exact string each source stamps on itself, rather than inventing a second classification mechanism."

key-files:
  created:
    - lib/data/calendar/composite_calendar_source.dart
    - lib/data/calendar/calendar_overlap.dart
    - test/data/calendar/composite_calendar_source_test.dart
    - test/data/calendar/calendar_overlap_test.dart
    - test/data/calendar/calendar_source_factory_test.dart
  modified:
    - lib/data/calendar/calendar_source_factory.dart
    - lib/screens/schedule/checkin_screen.dart

key-decisions:
  - "GoogleCalendarSource is constructed with calendarIds: const [] in iosCalendarSource() — a documented, deliberate limitation, not an oversight. Unlike DeviceCalendarSource (plugin resolves empty to 'all') or IcsCalendarSource (its urls list IS its config), GoogleCalendarSource has no way to enumerate 'every calendar' on its own; it must be told which ids to query. Wiring AppSettings.selectedCalendarIds (filtered to the google: prefix) into this constructor is plan 36-06's job, since the picker that writes those ids doesn't exist yet. Until then, listCalendars() still shows the full Google account; listEvents() returns zero Google events. Logged as WINDOWS.md entry 5."
  - "iosCalendarSource() is a new, plain top-level function (not the Platform.isIOS branch itself) so the composition decision is directly testable on danserver — dart:io's Platform.isIOS cannot be forced inside flutter test (unlike Flutter's own defaultTargetPlatform, which calendar_settings_screen.dart uses and can force via debugDefaultTargetPlatformOverride). This mirrors the existing precedent that DeviceCalendarSource.isAvailable()'s own Platform.isIOS branch has never been directly unit-tested in this codebase."
  - "The overlap detector matches on CalendarInfo.sourceLabel's exact strings ('Google' / 'This device') to decide which side of a pair each calendar is on, rather than adding a second classification field — those are the exact strings 36-03 already established as the picker's group headers."

requirements-completed: [CALAUTH-01, CALAUTH-03]

coverage:
  - id: D1
    description: "CompositeCalendarSource: two sources fan out/in as one CalendarSource, a dead child doesn't erase a working one, and total failure still reads as failure"
    requirement: CALAUTH-03
    verification:
      - kind: unit
        ref: "test/data/calendar/composite_calendar_source_test.dart — all 9 tests covering the 7 behaviors"
        status: pass
      - kind: unit
        ref: "mutation proof: removed per-child catch, observed 'one child throws, other succeeds' test FAIL; reverted"
        status: pass
      - kind: unit
        ref: "mutation proof: made all-children-failed swallow instead of rethrow, observed 'every child throws' test FAIL; reverted"
        status: pass
    human_judgment: false
  - id: D2
    description: "detectSelectedCalendarOverlaps: a narrow, watched-failing-when-widened rule that flags a same-account/same-name double-tick and nothing else, plus the required coarse fallback"
    requirement: CALAUTH-03
    verification:
      - kind: unit
        ref: "test/data/calendar/calendar_overlap_test.dart — all 10 tests covering the 7 <behavior> lines plus hasCrossSourceSelection"
        status: pass
      - kind: unit
        ref: "mutation proof: widened to account-email-only match, observed 'same account, different names' test FAIL; reverted"
        status: pass
      - kind: unit
        ref: "mutation proof: dropped the both-ticked condition, observed 'only one ticked' test FAIL; reverted"
        status: pass
    human_judgment: true
    rationale: "The RULE is fully proven here against hand-built CalendarInfo lists. What the rule ASSUMES about a real device — that EventKit's accountName for a Google-added device calendar actually equals the email string Google's own API reports as the primary calendar's id — is genuinely unresolved on danserver (no iPhone, no EventKit) and is carried by name to plan 36-07 item 6, the owner's real double-tick check."
  - id: D3
    description: "The factory routes iOS to a Google+device composite when a client is supplied, and every other platform is unchanged; checkin_screen.dart actually syncs Google"
    requirement: CALAUTH-01
    verification:
      - kind: unit
        ref: "test/data/calendar/calendar_source_factory_test.dart — all 4 tests (composite order, device-alone, non-iOS untouched x2)"
        status: pass
      - kind: unit
        ref: "mutation proof: reversed child order, observed the ordering test FAIL; reverted"
        status: pass
      - kind: other
        ref: "git diff on calendar_source_factory.dart shows the web branch and trailing .ics branch changed only in comment text"
        status: pass
    human_judgment: true
    rationale: "Platform.isIOS itself (the real OS read that gates iosCalendarSource) is unverifiable on danserver — no Xcode, no iOS device. What IS proven here is the composition GIVEN isIOS is true, tested by calling iosCalendarSource() directly. Whether Google calendars actually arrive at check-in on a real signed-in iPhone is plan 36-07's to confirm."

duration: ~70min
completed: 2026-09-25
status: complete
---

# Phase 36 Plan 05: Composite Calendar Source, Overlap Detector, Factory Wiring Summary

**D-36-03 in code: `CompositeCalendarSource` fans Google and device calendars into one `CalendarSource` on iOS, `detectSelectedCalendarOverlaps` flags a same-account/same-name double-tick by a rule watched failing when widened, and `defaultCalendarSource(googleAuth:)` wires both together while leaving every other platform byte-for-byte unchanged.**

## Performance

- **Duration:** ~70 min
- **Completed:** 2026-09-25
- **Tasks:** 3 (all implemented and committed)
- **Files created:** 5 (2 lib, 3 test)
- **Files modified:** 2

## Accomplishments

- **`CompositeCalendarSource`** (Task 1): fans an ordered list of `CalendarSource`s into one. `listCalendars()`/`listEvents()` merge every child's results in child order; `isAvailable()` is true if any child is; `requestPermission()` always returns `notApplicable` since permission is a per-child concept the settings screen already drives directly. The one judgement call — catch each child's `listEvents()` failure independently, rethrow only if every child failed — is written into the class doc comment along with the accepted gap it creates: a transient Google network blip while the device source keeps working produces no user-visible signal here (the expired-token case is signalled separately and independently, via `GoogleAuthClient`'s persisted reconnect flag from plan 36-02). `calendarIds` is passed through to every child unchanged, preserving each child's own "empty means all of mine" convention. A `children` getter was added for test introspection and factory-level ordering assertions.
- **`detectSelectedCalendarOverlaps`** (Task 2): a pure function over hand-built `CalendarInfo` lists that reports a `CalendarOverlap` pair only when the Google side's `accountName` matches the device side's exactly, their `name`s match case-insensitively once trimmed, and BOTH are in the current selection. It never de-duplicates, filters, or reorders anything — the doc comment states this prohibition and D-36-03's reason for it directly. `hasCrossSourceSelection` — the required coarse fallback — reports simply whether at least one Google and one device calendar are both ticked, regardless of whether any specific pair matches; it exists precisely so plan 36-06 can fall back to a general note if the narrow rule proves unreliable on a real device.
- **The factory** (Task 3): `defaultCalendarSource` gains an optional `GoogleAuthClient? googleAuth` parameter. On iOS, the new `iosCalendarSource()` function composes `GoogleCalendarSource` (first) and `DeviceCalendarSource` (second) when a client is supplied, or returns the device source alone otherwise — every existing caller (every test, and any caller that hasn't opted in) is unaffected. Every other platform's branch is untouched beyond comment text (confirmed by `git diff`). `checkin_screen.dart` now builds a real `GoogleAuthClient` from the `SettingsNotifier` it already reads and threads it through, so a signed-in account can actually sync at check-in rather than only ever populating a future picker.
- Full suite: **886/886 green** (863 baseline + 23 new: 9 composite, 10 overlap, 4 factory). `flutter analyze`: **No issues found!**. `lib/services/schedule_generator.dart`: byte-identical (`git diff --quiet` exits 0, checked after every commit).

## What is verifiable here, and what is not (per the plan's own framing)

**Fully proven on danserver:** the composite's fan-out/fan-in behavior including both failure-policy edges; the overlap detector's matching RULE, including that widening it to account-only or dropping the both-ticked condition both produce an observably wrong result; the factory's composition logic given `Platform.isIOS == true`; and that every non-iOS branch is provably unchanged.

**Not provable here, and not overclaimed:**
1. **The overlap detector's INPUTS.** The rule assumes a device calendar's `EventKit`-reported `accountName`, for a Google account added at the OS level, equals the email string Google's own Calendar API reports as its primary calendar's id (what `GoogleCalendarSource.listCalendars()` uses as `accountName` for every calendar it returns). This is a *plausible* assumption — `calendar_settings_screen.dart`'s own UI-SPEC example groups by `accountName` showing `"you@gmail.com"`, consistent with EventKit's usual behavior of naming an added account by its login email — but **no summary in this phase has captured a real device's `accountName` value for a Google-sourced calendar**, and Phase 35's own device gate (35-05 Task 3) that would exercise the device calendar list at all is still open per `STATE.md`. This is recorded as **unconfirmed, not disproven** — the evidence available does not say the matching is unreliable, only that nothing here can say it is reliable either. Per the plan's own instruction, the coarse fallback (`hasCrossSourceSelection`) is built regardless, so plan 36-06 has it available if the real device shows the narrow rule doesn't fire correctly. **Plan 36-07 item 6 — the owner ticking the same calendar under both sources on his own iPhone — is the only thing that settles this.**
2. **Whether `Platform.isIOS` genuinely gates `iosCalendarSource()` on a real device**, and whether a signed-in account's calendars genuinely arrive at check-in end-to-end. `dart:io`'s `Platform.isIOS` cannot be forced inside `flutter test` the way Flutter's own `defaultTargetPlatform` can (`calendar_settings_screen.dart` uses the latter and forces it via `debugDefaultTargetPlatformOverride`) — this file deliberately keeps `dart:io.Platform`, matching `device_calendar_source.dart`'s own pre-existing, never-directly-tested `Platform.isIOS` check. `iosCalendarSource()` was extracted as a plain top-level function specifically so the COMPOSITION decision (given `isIOS == true`, build what) is genuinely unit-tested, while the real OS read stays, like its precedent, unverifiable here and left to CI/the owner's device.

## Known Stubs

**`GoogleCalendarSource` is constructed with `calendarIds: const []` in `iosCalendarSource()`.** This is a real, working implementation with no placeholder logic — but with an empty constructor-time calendar list, `listCalendars()` still returns the full signed-in Google account (so the picker CAN display it), while `listEvents()` iterates zero calendar ids and returns no Google events at all. Unlike `DeviceCalendarSource` (whose plugin call resolves an empty list to "every calendar" internally) or `IcsCalendarSource` (whose configured feed-URL list IS the thing to iterate), `GoogleCalendarSource` has no way to discover "every calendar" on its own — it must be told which ids to query per Google's `events.list` API shape. Wiring `AppSettings.selectedCalendarIds` (filtered to the `google:` prefix) into this constructor is plan 36-06's job, since the calendar picker that actually writes Google-prefixed ids into that field doesn't exist yet. This plan's own file scope (`composite_calendar_source.dart`, `calendar_source_factory.dart`, `calendar_overlap.dart`, `checkin_screen.dart`) does not include `settings_notifier.dart`/`app_settings.dart`, and the plan's own Task 3 action text asks only for the `GoogleAuthClient` parameter to be threaded — not calendar-id selection. Logged as **WINDOWS.md entry 5** (kind: stub, phase 36) rather than silently left undocumented. This does NOT block this plan's own `<done>` claims about `CalendarSource`-level composition (both sources genuinely fan into one, structurally and by test) — it means end-to-end Google event import at check-in is real code with no data flowing through it yet, exactly until 36-06 lands.

## Task Commits

1. **Task 1: CompositeCalendarSource** — `fdf30f5` (feat)
2. **Task 2: detectSelectedCalendarOverlaps / hasCrossSourceSelection** — `3d2732a` (feat)
3. **Task 3: factory routes iOS to the composite, checkin_screen.dart threads a real client** — `29e167c` (feat)

_Plan metadata (this SUMMARY + REQUIREMENTS.md) is committed separately, per the worktree parallel-execution contract._

## Files Created/Modified

- `lib/data/calendar/composite_calendar_source.dart` — `CompositeCalendarSource`, fans/merges an ordered list of `CalendarSource`s
- `lib/data/calendar/calendar_overlap.dart` — `CalendarOverlap`, `detectSelectedCalendarOverlaps`, `hasCrossSourceSelection`
- `lib/data/calendar/calendar_source_factory.dart` — `googleAuth` param on `defaultCalendarSource`, new `iosCalendarSource()` seam, doc comment naming D-35-12 and D-36-03
- `lib/screens/schedule/checkin_screen.dart` — builds and threads a real `GoogleAuthClient` at check-in sync time
- `test/data/calendar/composite_calendar_source_test.dart` — 9 tests, all 7 `<behavior>` lines covered
- `test/data/calendar/calendar_overlap_test.dart` — 10 tests, all 7 `<behavior>` lines plus `hasCrossSourceSelection` covered
- `test/data/calendar/calendar_source_factory_test.dart` — new file, 4 tests (composite ordering, device-alone, two non-iOS-unaffected checks)

## Decisions Made

See `key-decisions` in the frontmatter: the `calendarIds: const []` limitation and why it's deliberately out of this plan's scope; the `iosCalendarSource()` testability extraction and why `Platform.isIOS` itself stays unverifiable here exactly like its `DeviceCalendarSource` precedent; and the `sourceLabel`-string matching approach in the overlap detector.

## Deviations from Plan

### Auto-fixed / adapted issues

**1. [Rule 3 — blocking, resolved by extraction] `Platform.isIOS` cannot be forced inside `flutter test`, so the plan's literal "assert that on iOS..." acceptance criterion could not be satisfied by branching through `defaultCalendarSource` directly**
- **Found during:** Task 3, while writing the factory test
- **Issue:** `calendar_source_factory.dart` (like `device_calendar_source.dart`) reads `dart:io`'s `Platform.isIOS`, which reflects the REAL host OS and is not overridable inside a `flutter test` run on Linux — unlike Flutter's own `defaultTargetPlatform`, which `calendar_settings_screen_test.dart` forces via `debugDefaultTargetPlatformOverride`. A literal test asserting "`defaultCalendarSource()` on iOS returns a composite" is therefore impossible to write honestly against the real entry point on danserver; writing one anyway (e.g. via some ad-hoc override) would either be vacuous or require inventing a new platform-override mechanism, which the plan explicitly said not to do.
- **Fix:** Extracted the composition decision (given `isIOS`, what to build) into a new plain top-level function, `iosCalendarSource({GoogleAuthClient? googleAuth})`, following this codebase's own precedent for making platform-dependent logic testable (`mapGoogleEvent`/`mapDeviceEvent`'s pure-function/adapter split). `defaultCalendarSource`'s `if (Platform.isIOS)` branch now just calls `iosCalendarSource(googleAuth: googleAuth)` — the real OS read is exactly as untested as `DeviceCalendarSource.isAvailable()`'s own pre-existing `Platform.isIOS` branch already was before this plan, not a regression.
- **Files modified:** `lib/data/calendar/calendar_source_factory.dart`, `test/data/calendar/calendar_source_factory_test.dart`
- **Verification:** `test/data/calendar/calendar_source_factory_test.dart` tests `iosCalendarSource()` directly (composite ordering, device-alone) and `defaultCalendarSource()` on the real test platform (confirming `googleAuth` has zero effect outside iOS). The mandatory ordering mutation proof (reverse child order) was run against `iosCalendarSource()` and observed failing correctly.
- **Committed in:** `29e167c` (Task 3 commit)

---

**Total deviations:** 1 (1 blocking issue resolved by a testability extraction, no behavior change to production logic). **Impact:** None reduce the plan's actual guarantees — the composition logic given `isIOS == true` is fully tested; only the real-OS-detection half (which was never testable here even before this plan, per `DeviceCalendarSource`'s own precedent) remains unverifiable on danserver, consistent with every other iOS-only check in this codebase.

## Issues Encountered

None beyond the deviation documented above.

## Next Phase Readiness

- Plan 36-06 (calendar picker UI) has a real `CompositeCalendarSource` to render against on iOS, `detectSelectedCalendarOverlaps` to call on tick, and `hasCrossSourceSelection` as its required fallback if the narrow rule proves unreliable on a real device.
- Plan 36-06 also needs to wire `AppSettings.selectedCalendarIds` (filtered to the `google:` prefix) into `GoogleCalendarSource`'s `calendarIds` constructor argument (currently `const []` — WINDOWS.md entry 5) — without this, a signed-in, calendar-selected Google account still imports nothing at check-in.
- **Genuinely unverifiable from danserver, carried to plan 36-07 by name:** whether a real iPhone's `EventKit`-reported `accountName` for a Google-added device calendar actually matches Google's own API `accountName` closely enough for the narrow overlap rule to fire correctly (item 6), and whether `Platform.isIOS`/the whole composition path behaves as coded on a real signed-in device.

## Self-Check: PASSED

All 5 created files confirmed present on disk (`test -f`): `lib/data/calendar/composite_calendar_source.dart`, `lib/data/calendar/calendar_overlap.dart`, `test/data/calendar/composite_calendar_source_test.dart`, `test/data/calendar/calendar_overlap_test.dart`, `test/data/calendar/calendar_source_factory_test.dart`. All 3 task commit hashes (`fdf30f5`, `3d2732a`, `29e167c`) confirmed present in `git log --oneline --all`. Full suite re-run before this SUMMARY was written: 886/886 green, `flutter analyze` clean, `schedule_generator.dart` byte-identical.

---
*Phase: 36-connect-google-calendar-without-hunting-for-a-url*
*Plan: 05*
*Completed: 2026-09-25*
