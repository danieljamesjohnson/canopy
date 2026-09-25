---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 02
subsystem: calendar
tags: [oauth, google-calendar, googleapis_auth, flutter_appauth, calauth-03, mutation-testing]

requires:
  - phase: 36-connect-google-calendar-without-hunting-for-a-url
    provides: "36-01's GoogleAuthClient with its GoogleCredentialsRefresher/GoogleAuthLauncher seams and the single generic failure branch this plan replaces"
provides:
  - "A three-way GoogleAuthClient failure classification: dead refresh token (400 + invalid_grant body) vs. network/5xx hiccup vs. malformed-but-not-dead 400 — only the first sets the persisted reconnect flag"
  - "translateGoogleLauncherError() — a top-level, directly testable cancellation-vs-failure boundary translation, replacing a bare catch-all"
  - "A closed reconnect-flag lifecycle: exactly two things clear it (a successful connect(), a successful silent refresh), exactly one thing sets it (a classified dead-token refresh failure), and disconnect() clears it independently"
  - "Two real-shape fixtures (google_invalid_grant.json, google_token_refresh_ok.json) driving the whole test file, not hand-typed string literals"
affects: [36-06, 36-07]

actuals:
  tokens: 6900
  tasks: 3
  commits: 1

tech-stack:
  added: []
  patterns:
    - "Fixture-driven fakes: the fake GoogleCredentialsRefresher decodes a JSON fixture and constructs the gauth.AccessCredentials/ServerRequestFailedException FROM it, so the discriminating test is driven by Google's real wire shape, not a hand-typed 'invalid_grant' string in a Dart literal"
    - "Recording every setReconnectNeeded call (reconnectNeededWrites list on the in-test fake), not just the final flag value, so an 'untouched' assertion proves zero writes happened rather than merely that the net effect looked the same"

key-files:
  created:
    - test/data/calendar/google_auth_client_test.dart
    - test/fixtures/calendar/google_invalid_grant.json
    - test/fixtures/calendar/google_token_refresh_ok.json
  modified:
    - lib/data/calendar/google_auth_client.dart

key-decisions:
  - "Kept connect() returning Future<bool> rather than introducing the plan's suggested three-valued outcome enum — see Deviations. All four Task 2 behaviors are fully satisfied by the existing contract; the enum is deferred to whichever plan (36-06) actually needs to touch google_calendar_source.dart's call site."
  - "responseContent is the PARSED JSON Map (Map<String, dynamic>), not a raw string or an already-summarized message — confirmed by reading googleapis_auth 2.3.4's own source (lib/src/utils.dart's requestJson, which throws with responseContent: jsonMap on any non-200 status). Assumption A3 is CONFIRMED, not merely re-asserted."
  - "FlutterAppAuthUserCancelledException CAN be constructed in a host test — it extends PlatformException with no platform-channel dependency (confirmed by reading flutter_appauth_platform_interface 12.1.0's source). The plan's own fallback (grep-only proof) was not needed; the translation is proven by a real unit test."

requirements-completed: [CALAUTH-03]

coverage:
  - id: D1
    description: "Three-way refresh-failure classification: dead refresh token (400 + invalid_grant) sets the reconnect flag and leaves tokens in place; network/timeout/5xx and a 400-without-invalid_grant both throw GoogleAuthException without touching the flag; an unexpired access token never calls the refresher at all"
    requirement: CALAUTH-03
    verification:
      - kind: unit
        ref: "test/data/calendar/google_auth_client_test.dart#Task 1 group, all 6 behaviors"
        status: pass
      - kind: unit
        ref: "mutation proof: widened classification to status-code-only, observed the 400-invalid_request test FAIL (see Non-vacuity proofs), reverted"
        status: pass
      - kind: unit
        ref: "mutation proof: made the network-failure branch also set the flag, observed the socket-error and Task-3 network-failure tests FAIL, reverted"
        status: pass
    human_judgment: true
    rationale: "Proves the classification given Google's documented error shape. Whether Google's real token endpoint actually emits that exact body after a real 7-day expiry is explicitly NOT settled here — that is the owner's device check, plan 36-07 item 5 (see 'What is verifiable here' in the plan)."
  - id: D2
    description: "Cancellation is a real state, not an error: a cancelled connect() writes nothing, sets no flag, and does not throw; a genuine launcher failure still throws GoogleAuthException and still writes nothing; the boundary translation (FlutterAppAuthUserCancelledException -> null, anything else -> GoogleAuthException) is extracted and directly unit-tested"
    requirement: CALAUTH-03
    verification:
      - kind: unit
        ref: "test/data/calendar/google_auth_client_test.dart#Task 2 groups, all 4 behaviors + 2 translateGoogleLauncherError tests"
        status: pass
      - kind: unit
        ref: "mutation proof: made the cancelled path call clear(), observed the re-consent-while-connected test FAIL with 'Null check operator used on a null value', reverted"
        status: pass
    human_judgment: true
    rationale: "The translation itself IS proven here (a real FlutterAppAuthUserCancelledException was constructed and passed directly). What is NOT proven here — carried to 36-07 by name (Assumption A7) — is whether every native cancellation path on a real device (Cancel button, swipe-dismiss) actually throws this exact exception type."
  - id: D3
    description: "The reconnect flag has a complete, closed lifecycle: a successful connect() or silent refresh clears it; a failed refresh (any reason), a cancelled connect(), leave it untouched; disconnect() clears it independently. Documented on GoogleTokenStore.reconnectNeeded's declaration."
    requirement: CALAUTH-03
    verification:
      - kind: unit
        ref: "test/data/calendar/google_auth_client_test.dart#Task 3 group, all 5 lifecycle behaviors"
        status: pass
      - kind: unit
        ref: "mutation proof: cleared the flag unconditionally at the top of the refresh path, observed the 'refresh fails on network, flag stays true' test FAIL, reverted"
        status: pass
    human_judgment: false

duration: ~90min (approximate — exact start time not captured at spawn; based on session activity and commit timestamp 2026-09-25T15:00:36Z)
completed: 2026-09-25
status: complete
---

# Phase 36 Plan 02: CALAUTH-03 Failure Classification Summary

**A dead Google refresh token, an offline phone, and a hiccuping Google API are now three distinguishable code paths in `GoogleAuthClient`, each proven by a test watched failing under a deliberate mutation of the discriminating condition.**

## Performance

- **Duration:** ~90 min (approximate)
- **Completed:** 2026-09-25
- **Tasks:** 3 (all implemented — no checkpoints in this plan)
- **Files modified/created:** 4 (1 modified, 3 created)

## Accomplishments

- **Task 1 — three-way classification.** `_isExpiredOrRevokedRefreshToken()` requires all three conditions together (the `googleapis_auth` exception type, `statusCode == 400`, and `responseContent['error'] == 'invalid_grant'`) before setting the persisted reconnect flag. Everything else — a socket/timeout error, a 503, a 400 that names a different error code — throws `GoogleAuthException` and leaves the flag exactly as it was. An unexpired access token never touches the refresher seam at all. Six tests, one per `<behavior>` line, all fixture-driven (see below).
- **Task 2 — cancellation is a state, not an error.** Extracted `translateGoogleLauncherError()` from the production launcher's catch clause into a top-level, directly-testable function. Replaced the prior bare `catch (_) { throw GoogleAuthException(...) }` with a narrow `catch (e)` that routes through the translation function — the acceptance criterion's grep for a bare catch-all now returns 0. A cancelled `connect()` while an existing connection is present leaves the existing tokens (and the reconnect flag) completely untouched — proven by a test, and by a mutation that made the cancel path destructive and watched it fail.
- **Task 3 — the flag's lifecycle is closed.** Added `await _store.setReconnectNeeded(false)` on a successful refresh (it was previously only cleared on a successful `connect()`). Five lifecycle tests prove: `connect()` success clears it, refresh success clears it, a network-failing refresh leaves it TRUE, a cancelled `connect()` leaves it TRUE, and `disconnect()` clears it independently of the "expired" concept. The five-outcome contract is documented on `GoogleTokenStore.reconnectNeeded`'s declaration (see Deviations for why not on `AppSettings`).
- **Two real-shape fixtures** (`google_invalid_grant.json`, `google_token_refresh_ok.json`) are decoded inside the fake `GoogleCredentialsRefresher` and used to construct the actual `gauth.ServerRequestFailedException`/`gauth.AccessCredentials` the tests assert against — so the discrimination is driven by Google's documented wire shape, not a string literal typed into the test file.
- **Full suite: 847/847 green** (830 from 36-01 + 17 new). `flutter analyze`: **No issues found!** `lib/services/schedule_generator.dart` is **byte-identical** (`git diff --quiet` exits 0, checked after the final commit).

## Assumption resolutions (this plan's own required findings)

- **Assumption A3 — CONFIRMED, not merely re-asserted.** Read `googleapis_auth` 2.3.4's installed source directly (`lib/src/utils.dart`, the `ClientExtensions.requestJson` extension method). On any non-200 response it throws `ServerRequestFailedException(message, statusCode: response.statusCode, responseContent: jsonMap)` where `jsonMap` is the **parsed JSON `Map<String, dynamic>`** — not a raw string, not an already-summarized message. The classification function therefore checks `content['error'] == 'invalid_grant'` directly on the typed map rather than string-matching a `.toString()` — a strictly more correct approach than the research's own sketched `body.contains('invalid_grant')`, made possible by having actually read the source.
- **Assumption A7 — narrowed, not fully resolved.** `FlutterAppAuthUserCancelledException extends PlatformException` and takes only plain-Dart constructor arguments (`code`, optional `message`/`stacktrace`, required `platformErrorDetails`, itself all-optional named fields) — confirmed by reading `flutter_appauth_platform_interface` 12.1.0's source. It **can** be constructed in a host test with no platform channel, so `translateGoogleLauncherError()`'s translation is proven directly by a passing unit test, better than the plan's own anticipated fallback (a grep-only proof). What remains unconfirmed — and is carried forward to plan 36-07's device checkpoint by name — is whether every native cancellation path on a real iOS device (the Cancel button, and a possible swipe-to-dismiss) actually surfaces as this specific exception type, versus some other `PlatformException` or a hang.

## Non-vacuity proofs (mutation testing, per CLAUDE.md's "Assertions that cannot fail")

Four mutations were introduced, run against the suite, observed to fail the correct test with the expected message, and reverted. This plan is explicitly the one CLAUDE.md flags as most likely to pass vacuously, so all four are recorded verbatim.

**1. Status-code-only classification (Task 1 acceptance criterion).** Changed `_isExpiredOrRevokedRefreshToken` to `return true;` immediately after the `statusCode != 400` check, dropping the body check entirely. Observed:
```
Task 1 ... refresh fails with statusCode 400 but a body that does NOT name invalid_grant: flag is NOT set
Expected: false
  Actual: <true>
```
Reverted immediately.

**2. Network failure also sets the flag (Task 1 acceptance criterion).** Changed the refresh catch block to `await _store.setReconnectNeeded(true);` unconditionally, before the throw. Observed both a Task 1 test and the Task 3 lifecycle test fail:
```
Task 3 ... flag set, then a refresh that fails on the network: flag is still TRUE afterwards
Expected: empty
  Actual: [true]
```
(The socket-error and 503 Task 1 tests also failed, as expected, since they assert `reconnectNeededWrites` is empty.) Reverted immediately.

**3. Destructive cancellation (Task 2 acceptance criterion).** Made the `tokens == null` branch in `connect()` call `await _store.clear();` before returning `true`. Observed:
```
Task 2 ... launcher returns null when a previous connection already exists: the existing tokens are still there afterwards, untouched
Null check operator used on a null value
test/data/calendar/google_auth_client_test.dart 313:21  main.<fn>.<fn>
```
Reverted immediately.

**4. Unconditional flag clear (Task 3 acceptance criterion).** Added `await _store.setReconnectNeeded(false);` unconditionally at the top of the refresh path, before the `try` block. Observed:
```
Task 3 ... flag set, then a refresh that fails on the network: flag is still TRUE afterwards
Expected: true
  Actual: <false>
```
Reverted immediately.

All four mutations were confirmed reverted before the final commit — `git diff` against the committed state showed no residual mutation code, and the full 847-test suite passed clean afterward.

## Task Commits

All three tasks were implemented and committed together as a single commit, since their changes are tightly interleaved within the same handful of functions in one file (Task 1's classification function is called from the same catch block Task 3 completes; Task 2's extracted translation function sits between them). Splitting after the fact into three commits would have been artificial re-slicing of a single coherent diff, not a reflection of how the work was actually done — recorded here as a process note, not a plan deviation.

1. **Tasks 1–3: three-way classification, cancellation translation, closed lifecycle** — `61852dc` (feat)

_Plan metadata (this SUMMARY + REQUIREMENTS.md) is committed separately, per the worktree parallel-execution contract._

## Files Created/Modified

- `lib/data/calendar/google_auth_client.dart` — added `_isExpiredOrRevokedRefreshToken()`, `translateGoogleLauncherError()`, the reconnect-flag-clearing call on refresh success, and the five-outcome doc comment on `GoogleTokenStore.reconnectNeeded`
- `test/data/calendar/google_auth_client_test.dart` — new file, 17 tests across all three tasks plus the boundary-translation function
- `test/fixtures/calendar/google_invalid_grant.json` — new, Google's real `invalid_grant` error shape
- `test/fixtures/calendar/google_token_refresh_ok.json` — new, a successful token-refresh response shape

## Decisions Made

- Kept `connect()` returning `Future<bool>` rather than the plan's suggested three-valued outcome enum (see Deviations — this is the plan's own biggest deviation and is explained there, not just in frontmatter).
- Confirmed `responseContent` is the parsed JSON `Map`, not a raw/summarized string (Assumption A3) — see above.
- Confirmed `FlutterAppAuthUserCancelledException` is host-test-constructible (Assumption A7, partially) — see above.

## Deviations from Plan

### Auto-fixed / adapted issues

**1. [Scope-boundary conflict, resolved in favor of the wave's file-ownership contract] Did NOT introduce the three-valued `connect()` outcome type Task 2's action text describes**
- **Found during:** Task 2, while planning the change
- **Issue:** The plan's action text asks for `connect()` to return "an explicit three-valued outcome rather than a bare bool — connected, cancelled, or failed — as a small enum or sealed result in this file, so plan 36-06's screen branches on a named state instead of inferring one from a null." But `connect()`'s only two callers outside tests are `lib/data/calendar/google_calendar_source.dart:63` (`final cancelled = await _authClient.connect();` used in a ternary) and its own test in `test/data/calendar/google_calendar_source_test.dart:132` — **both files explicitly declared as plan 36-03's exclusive ownership** in this wave's parallel-execution contract, and neither is in this plan's own `files_modified`. Changing the return type would break both files' compilation.
- **Resolution:** Kept `connect()` returning `Future<bool>` (`true` = cancelled) exactly as 36-01 left it. All four of Task 2's `<behavior>` lines are fully satisfied by the existing contract — verified by the four Task 2 tests and the translation-function tests, none of which required a signature change. The `translateGoogleLauncherError()` extraction (the other half of Task 2's ask) was implemented in full, since it required no signature change and lives entirely inside this plan's one file.
- **Files affected:** None outside this plan's declared scope — this is a "did not do X" deviation, not a code change.
- **Recommendation:** Whichever plan next touches `google_calendar_source.dart`'s `requestPermission()` (likely 36-06, which needs to distinguish cancelled/failed on the settings screen) should introduce the three-valued type in the same change that updates that call site, rather than landing an unused type here now.

**2. [Doc-comment relocated to stay in scope] Task 3's "doc comment on the flag's declaration in AppSettings" was placed on `GoogleTokenStore.reconnectNeeded` instead**
- **Found during:** Task 3
- **Issue:** `lib/data/models/app_settings.dart` (where `googleReconnectNeeded`'s `@HiveField` declaration lives) is not in this plan's `files_modified` and is not this plan's file to touch under the wave's stay-in-your-files contract.
- **Resolution:** Placed the same five-outcome documentation on `GoogleTokenStore.reconnectNeeded`'s declaration in `google_auth_client.dart` instead — arguably the more useful location anyway, since it's the seam any future caller (including plan 36-06's screen) actually reads, not the Hive model underneath it.
- **Files affected:** `lib/data/calendar/google_auth_client.dart` only (already in scope).

**3. [Plan-text correction] The acceptance criterion's grep pattern named a method that does not exist**
- **Found during:** Verifying Task 1's acceptance criteria
- **Issue:** The plan's literal text says `grep -rl 'setGoogleReconnectNeeded(' lib/ | wc -l` should be `2`. The actual method (established by 36-01, confirmed by reading the file) is `setReconnectNeeded`, not `setGoogleReconnectNeeded` — the plan's grep pattern would return `0` regardless of correctness, a false-negative-proof check.
- **Resolution:** Ran the equivalent check against the real method name: `grep -rl 'setReconnectNeeded(' lib/` returns exactly 2 files (`settings_notifier.dart` defining it, `google_auth_client.dart` calling it) — the intended invariant holds.
- **Files affected:** None — verification-only correction.

---

**Total deviations:** 3 (1 scope-boundary conflict resolved by omission, 1 doc-comment relocation, 1 plan-text correction). **Impact:** None reduce CALAUTH-03's coverage — all four Task 2 behaviors and all five Task 3 lifecycle behaviors are fully tested regardless of the enum's absence. The scope-boundary decision specifically prevents a guaranteed merge conflict / broken build against plan 36-03, running concurrently in this same wave.

## Known Stubs

None. Every function added or modified is a real, tested implementation — no placeholder returns, no hardcoded empty values feeding UI.

## Issues Encountered

None beyond the deviations documented above.

## Next Phase Readiness

- CALAUTH-03's classification, cancellation, and lifecycle contracts are fully implemented and tested against `GoogleAuthClient`'s existing seams — no network, no device, no native sheet required for any of it (RESEARCH Pitfall 5).
- Plan 36-06 (the settings screen wiring) can rely on `GoogleTokenStore.reconnectNeeded`'s documented five-outcome contract directly, and should introduce the three-valued `connect()` outcome type in the same change that updates `google_calendar_source.dart`'s `requestPermission()` call site, per this plan's Deviation 1.
- Plan 36-07 (the owner's MacBook, device checkpoint) still owns two genuinely unverifiable-from-danserver claims, both carried forward by name: whether Google's real token endpoint actually emits the exact `invalid_grant` body shape after a real 7-day expiry (Assumption A3's remaining half — the shape itself, not the field it lives in, which IS confirmed), and whether every native cancellation path actually throws `FlutterAppAuthUserCancelledException` (Assumption A7's remaining half).

## Self-Check: PASSED

All 3 created files confirmed present on disk (`test -f`): `test/data/calendar/google_auth_client_test.dart`, `test/fixtures/calendar/google_invalid_grant.json`, `test/fixtures/calendar/google_token_refresh_ok.json`. Commit `61852dc` confirmed present via `git log --oneline --all`. Full suite re-run after all four mutations were reverted: 847/847 green, `flutter analyze` clean, `lib/services/schedule_generator.dart` byte-identical.

---
*Phase: 36-connect-google-calendar-without-hunting-for-a-url*
*Plan: 02*
*Completed: 2026-09-25*
