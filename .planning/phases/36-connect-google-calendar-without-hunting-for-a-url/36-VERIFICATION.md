---
phase: 36-connect-google-calendar-without-hunting-for-a-url
verified: 2026-09-28T00:00:00Z
status: gaps_found
score: 6/6 truths verified here on danserver; 8 truths correctly deferred to the owner's device (not counted as verified, not failed). SUPERSEDED IN PART — see the 2026-10-06 addendum below; the device gate has since run and found 3 defects.
behavior_unverified: 0
overrides_applied: 0
# GAPS BELOW WERE NOT FOUND BY THIS VERIFIER. They were found by the owner's real-device
# UAT on 2026-10-06, after this report was written on 2026-09-28, and are recorded here
# because /gsd-plan-phase --gaps reads this file and 36-UAT.md as its ONLY inputs — it does
# NOT read WINDOWS.md, where they were originally logged. Full detail: WINDOWS.md entries
# 7/8/10, 36-UAT.md "Your answers", and the addendum section in this file.
# status changed human_needed -> gaps_found: the human gate DID run and returned findings.
# A device re-visit is still required afterwards (human_verification below still stands).
gaps:
  - id: windows-7
    requirement: CAL-02
    gap: "sync() always calls listEvents(calendarIds: const []) and iosCalendarSource() builds DeviceCalendarSource() with no ids, so device_calendar_plus resolves empty to EVERY calendar. The user's ticked selection is persisted and rendered but never reaches the device source."
    evidence: "Owner's iPhone 2026-10-06, read from the device's own Hive: AppSettings.selectedCalendarIds held exactly one id (CF8A6881-...) while imported CommitmentBlocks carried at least four distinct calendar ids, including a holidays and a birthdays calendar."
    files: ["lib/services/calendar_sync_service.dart", "lib/data/calendar/calendar_source_factory.dart"]
    why_missed: "The device path is iOS-only and could never execute on danserver; 35-05's device gate was open the whole time. Google's half of the same wiring WAS done (WINDOWS entry 5), which made the device half look done by association."
  - id: windows-8
    requirement: D-36-05
    gap: "All-day events import as a blocking 08:00-22:00 CommitmentBlock, erasing the whole working day. Target behaviour is now RULED: skip and disclose, never import."
    evidence: "Owner's iPhone 2026-10-06: SIX working days erased in a 12-day window — Vacation, a 38th Birthday, Fall break, Payday, Indigenous Peoples' Day, Columbus Day."
    files: ["lib/services/calendar_sync_service.dart"]
    ruling: "D-36-05 (2026-10-06) SUPERSEDES D-35-06. Read 36-DECISIONS.md D-36-05 before planning — it names the required changes, the now-false SkipReason doc comment, the new UI-SPEC copy string, and that schedule_generator.dart must NOT be touched."
    not_a_duplicate_of: "windows-7 — a legitimately-ticked calendar still contains birthdays, and Payday lands regardless. Fixing 7 does not fix 8."
    open_question: "The six blocks are ALREADY PERSISTED Hive records. A sync that stops importing all-day events is not the same as one that PRUNES what an earlier sync wrote. If not pruned, the next UAT must not judge a day still holding them (CLAUDE.md trap #4)."
  - id: windows-6
    requirement: CALAUTH-03
    gap: "Re-opening the Calendars screen always shows the 'Connect Google Calendar' CTA even when a valid token is stored — only reconnectNeeded (a dead token) is read from persisted state, never a valid-but-unconfirmed connection. Tapping re-launches real consent and re-issues a token, so this is UX friction, not wrong data."
    evidence: "Logged by the 36-06 orchestrator 2026-09-25 and carried in 36-UAT.md's 'Orchestrator observations' so the owner would not report it cold. Compounded by code-review finding WR-05: a transient listCalendars() failure right after a successful sign-in reverts to the same CTA."
    files: ["lib/providers/settings_notifier.dart", "lib/screens/settings/calendar_settings_screen.dart"]
    added: "2026-10-06 — ADDED TO THIS CONTRACT LATE, and the reason is worth keeping. Entry 6 was real and open in WINDOWS.md but was never in this frontmatter, so a future --gaps re-run against this file alone would not have reproduced plan 36-10's existence. Same silent-invisibility failure as the three gaps above: WINDOWS.md is not a planning input. Flagged by gsd-plan-checker as an INFO advisory."
    note: "Sequenced LAST (plan 36-10, wave 3) so it cannot jeopardise gaps 7/8/10 landing. It is the one remaining open entry a reasonable person reports as a bug."
  - id: windows-10
    requirement: CAL-04 spirit / disclosure discoverability
    gap: "The skipped-events disclosure exists and is tested, but the owner did not notice it on device and asked for 'a reminder at the top'. Not missing — not discoverable."
    evidence: "Owner-reported from real use, 2026-10-06."
    files: ["lib/screens/settings/calendar_settings_screen.dart"]
    coupled_to: "windows-8 — once all-day events are silently skipped, this disclosure becomes the ONLY channel through which a dropped Vacation is communicated. Fixing 8 without 10 trades six visible fake blocks for one invisible omission."
human_verification:
  - test: "Run 36-UAT.md Section A (items A1-A6, Phase 35's still-open device gate) and Section B (items 1-8, Phase 36 itself) on the owner's MacBook, per the mandatory Step 0 re-check-in discipline stated at the top of that document."
    expected: "Every item in 36-UAT.md's 'Your answers' section filled in with specific, non-'it seems to work' answers, and an overall verdict recorded."
    why_human: "No Xcode/iOS device exists on danserver. The consent round-trip, the durable-refresh-token claim (Assumption A6), the cancellation-path exception shape on a real device (Assumption A7), the CALAUTH-03 wording distinction between 'expired' and 'offline', and the double-tick warning's perceptual clarity (D-36-03) are all only observable on real hardware with a real Google account."
---

# Phase 36: Connect Google Calendar Without Hunting For a URL — Verification Report

**Phase Goal:** Connecting the calendar Canopy schedules around is a button, not a scavenger hunt —
one tap to Google's consent screen, read-only, and back to a list of your real calendars.

**Verified:** 2026-09-28
**Status:** human_needed
**Re-verification:** No — initial verification

## Why this phase cannot reach `passed`, and why that is correct

Plan `36-07` is deliberately parked at a `blocking-human` checkpoint. Task 1 (writing `36-UAT.md`) is
done and committed (`441fa3a`); Task 2 (the owner building on his MacBook) and Task 3 (recording his
answers) have not happened — `36-UAT.md`'s "Your answers" section is entirely blank, confirmed by
reading the file. There is correctly no `36-07-SUMMARY.md`. Nothing that requires Xcode, a real
Google account, or a physical iPhone can be settled on danserver, which has neither Xcode nor an
iOS device and never will. This verifier's job is to confirm everything that COULD be built and
tested here actually was — not to manufacture a `passed` the phase was never designed to reach at
this point in its lifecycle.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | CALAUTH-02: the only scope requested is read-only, named once, no mutating verb reachable | ✓ VERIFIED | `kGoogleCalendarReadonlyScope = 'https://www.googleapis.com/auth/calendar.readonly'` defined once in `google_oauth_config.dart`, referenced only in `google_auth_client.dart` (2 sites: `connect()`, `_toAccessCredentials()`). `grep -rnE "\.(insert|update|patch|delete|move)\(" lib/data/calendar/ lib/services/` — zero matches. Only `CalendarApi(client)` construction sites (2) both call read-only list methods. |
| 2 | CALAUTH-04: no client secret exists in tracked source | ✓ VERIFIED | `grep -rniE "client_secret\|clientSecret"` across `lib/`, `ios/`, `android/`, `tools/` — zero matches. `.google-client-id` (the client **ID**, not a secret) is gitignored and `git log --all -- .google-client-id` shows it was never committed. For a native/installed Google OAuth client, Google issues no secret at all (D-36-01's own researched premise) — so CALAUTH-04 is satisfied both by construction and by grep. |
| 2b | Does the committed client **ID** in `36-RESEARCH.md` (QUESTIONS.md Q-01) affect CALAUTH-04? | ✓ Reasoned, does not affect the requirement | CALAUTH-04's text is scoped to "client secret," not client ID. A PKCE public client ID is not sensitive by the OAuth spec (no code exchange is possible without the PKCE verifier, which was never committed). QUESTIONS.md Q-01 correctly frames this as a posture inconsistency (CONTEXT decision 1 wanted the ID out of the repo entirely) worth an owner call — but it is explicitly not a secret leak and does not fail CALAUTH-04 as written. Still open in QUESTIONS.md, unresolved by design (owner's call, not blocking). |
| 3 | CALAUTH-03: three-way failure classification is real and the reconnect flag has a closed lifecycle | ✓ VERIFIED | Read `google_auth_client.dart` in full. `_isExpiredOrRevokedRefreshToken()` requires `ServerRequestFailedException` + `statusCode == 400` + body's `error == 'invalid_grant'` — all three, narrower than a status-code-only check (mutation-tested per 36-02-SUMMARY, and reasoning confirmed by reading the function). Flag set exactly once (dead-token classification), cleared in exactly two places (successful `connect()`, successful silent refresh in `authenticatedClient()`), untouched on network/5xx/malformed-400/cancellation, and independently cleared on `disconnect()`. This is a state-machine/lifecycle truth — verified behaviorally, not just by presence: `google_auth_client_test.dart` (part of the 125-test run below) exercises the dead-token path, the network-failure path (flag untouched), and the cancellation path (flag untouched) via injected fixtures built from Google's real wire shape (`google_invalid_grant.json`, `google_token_refresh_ok.json`), and all pass. |
| 4 | CALAUTH-03: expiry is visible in two places (screen + Settings row) | ✓ VERIFIED (code + widget test) | `settings_screen_calendar_row_test.dart` and `calendar_settings_screen_test.dart` both assert on `reconnectNeeded` driving distinct rendered states (reconnect card vs. Settings row subtitle), both passing in the run below. Whether the two messages actually read as "expired" vs. "offline" in visually distinguishable prose to a human is UAT item 5 — correctly deferred. |
| 5 | CALAUTH-01: the button exists and reaches a real consent launcher, gated to iOS only | ✓ VERIFIED (code) | `calendar_settings_screen.dart:642-643` renders `'Connect Google Calendar'` wired to `_startGoogleConnect` → `_connectGoogle` → `GoogleCalendarSource.requestPermission()` → `GoogleAuthClient.connect()` → the real `flutter_appauth` launcher (`_defaultLauncher`, the only `lib/` import of that package). Gated by `_isMobile` (`!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`) — confirms D-36-01's accepted cost that the button does not exist in the browser build is intentional, not a gap. Whether tapping it actually shows Google's real account picker is UAT item 1 — correctly deferred. |
| 6 | Schema 11→12 is additive; an old record reads back with no crash | ✓ VERIFIED | Fields 12-14 (`googleAccessToken`, `googleRefreshToken`, `googleAccessTokenExpiresAt`) are nullable (`String?`/`DateTime?`) — safe by construction under `hive_ce_generator`'s cast behavior (per QUESTIONS.md Q-02's finding that only *non-nullable* fields without `defaultValue:` crash). Field 15 (`googleReconnectNeeded`, non-nullable `bool`) correctly carries `defaultValue: false`, avoiding exactly the defect class QUESTIONS.md Q-02 flagged elsewhere in this file. `migration_schema12_test.dart`'s two tests (old 12-field record reads back with all four Google fields null/false, no crash; new record round-trips) both pass in the run below — this is genuine behavioral proof, not presence-only. |
| 7 | `lib/services/schedule_generator.dart` is byte-identical to pre-phase state | ✓ VERIFIED | `git diff d4bbaab^ HEAD -- lib/services/schedule_generator.dart` (`d4bbaab` = phase 36's first commit) returns empty output and empty `--stat`. No commit in `git log --oneline -- lib/services/schedule_generator.dart` falls inside phase 36's commit range. |
| 8 | D-36-03's REQUIRED mitigation: overlap warning exists, fires at tick time, and nothing de-duplicates | ✓ VERIFIED | Read `calendar_overlap.dart` in full. `detectSelectedCalendarOverlaps()`'s own doc comment states it "never de-duplicates, filters, or reorders," and the function's body only ever reads `calendars`/`selectedIds` and returns a new `List<CalendarOverlap>` — no mutation of either input anywhere. Confirmed behaviorally: `calendar_settings_screen_test.dart`'s test named exactly `"nothing is de-duplicated in the selection — ticking both sides of an overlap keeps BOTH ids, proving the duplicate is disclosed, not silently prevented"` passes in the run below. No other file in `lib/` calls `.toSet()` or any dedup-shaped operation on `selectedCalendarIds` (grep-checked). This directly answers the "say so loudly if you find one" instruction: **no violation found.** |
| 9 | WINDOWS entry 5 (fixed this phase): `selectedCalendarIds` reaches `GoogleCalendarSource` | ✓ VERIFIED | `calendar_source_factory.dart:106` constructs `GoogleCalendarSource(authClient: googleAuth, calendarIds: googleCalendarIds)` where `googleCalendarIds` is `AppSettings.selectedCalendarIds` filtered via `filterGoogleCalendarIds()` (shared `google:` prefix constant, WR-02 fixed). Both call sites that need the filtered selection — `calendar_settings_screen.dart:161` and `checkin_screen.dart:157` — use the same shared `filterGoogleCalendarIds()`/`googleCalendarIdPrefix` rather than independent literals, confirming code review's WR-02 was actually fixed in commit `956daea`, not just claimed. `WINDOWS.md` entry 5 is marked `status: fixed` with a `resolved_at` timestamp, consistent with the code. |

**Score:** 9/9 danserver-verifiable truths verified. See "Correctly Deferred" below for the truths this
phase's own design puts out of reach here.

### All four code-review WARNINGs (WR-01 through WR-04) confirmed actually fixed in the latest commits

The review (`36-REVIEW.md`, `f3b47c4`) found 0 critical / 5 warning. Commits `e89c766`, `956daea`,
`ae94a93`, `26727dc` (all dated after the review, tagged `fix(36): ... (WR-0N)`) claim to fix four of
the five. Verified each against current code, not the commit message:

- **WR-01** (`listCalendars()` had no per-child failure isolation): `composite_calendar_source.dart`'s
  `listCalendars()` now has the same catch-per-child/rethrow-only-if-all-failed shape as `listEvents()`,
  with an explicit code comment citing WR-01. Confirmed by reading the code.
- **WR-02** (duplicated `'google:'` magic string): `googleCalendarIdPrefix` is now a public constant in
  `google_calendar_source.dart`, and both other call sites (`calendar_settings_screen.dart`,
  `checkin_screen.dart`) import and use `filterGoogleCalendarIds()`/the shared constant rather than a
  hardcoded literal. Confirmed by grep — no remaining hardcoded `'google:'` literal outside the
  constant's own definition and its internal uses.
- **WR-03** (no-primary-entry mislabels rows under "This device"): `google_calendar_source.dart` now
  has a documented fallback (comment cites WR-03) guaranteeing a non-null `accountName`. Confirmed by
  reading the code around the `primary == true` search.
- **WR-04** (no expiry safety margin): `google_auth_client.dart` now has `_expiryMargin = Duration(seconds: 30)`
  applied in `authenticatedClient()`'s refresh-or-not check, with a comment citing WR-04. Confirmed by
  reading the code.
- **WR-05** (transient `listCalendars()` failure after successful permission reverts UI to
  "not connected" despite a valid persisted token) has **not** been fixed — no commit references it,
  and `calendar_settings_screen.dart`'s `_connectGoogle()` catch-all still folds a post-token
  `listCalendars()` failure into `connected: false`. This is UX-only (no data loss, `reconnectNeeded`
  correctly untouched per the review's own scoping) and was never claimed fixed — WINDOWS.md does not
  list it as an entry, so it is neither a phase gap nor a regression, just an acknowledged remaining
  warning. Flagging it here so it isn't silently forgotten.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/data/calendar/google_auth_client.dart` | full three-way failure classification + closed reconnect lifecycle | ✓ VERIFIED | Present, substantive, wired into `GoogleCalendarSource` and exercised by 125 passing tests |
| `lib/data/calendar/google_calendar_source.dart` | 4th CalendarSource, mapping, scope enforcement | ✓ VERIFIED | Present, substantive, wired |
| `lib/data/calendar/google_oauth_config.dart` | client-id injection, scope constant, redirect URI | ✓ VERIFIED | Present, single source of truth for the scope |
| `lib/data/calendar/composite_calendar_source.dart` | fans Google+device, per-child isolation on both methods | ✓ VERIFIED | WR-01 fix confirmed present |
| `lib/data/calendar/calendar_overlap.dart` | detector, never de-dups | ✓ VERIFIED | No-dedup contract confirmed by reading + passing test |
| `tools/build-ios.sh` | only supported iOS build entrypoint, fails loudly without `.google-client-id` | ✓ VERIFIED (script logic; not run — needs Xcode) | Present, referenced correctly by `36-UAT.md`'s build instructions; `test/tools/build_ios_wrapper_test.dart` passes (shell/Dart reversal-rule agreement) |
| `lib/screens/settings/calendar_settings_screen.dart` | Connect button, reconnect card, overlap note, all gated to iOS | ✓ VERIFIED | Present, wired, `_isMobile` gate confirmed |
| `.planning/phases/.../36-UAT.md` | the owner's device script | ✓ VERIFIED as an artifact | Exists, 289 lines, covers all 8 Phase 36 items + Phase 35's Section A; "Your answers" section confirmed blank (Task 2/3 correctly not yet run) |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `GoogleAuthClient.connect()` | `GoogleTokenStore.write`/`setReconnectNeeded(false)` | direct calls in `connect()` | ✓ WIRED | Read directly |
| `authenticatedClient()`'s refresh failure | `setReconnectNeeded(true)` only on classified dead-token | `_isExpiredOrRevokedRefreshToken()` guard | ✓ WIRED | Confirmed + behaviorally tested |
| `AppSettings.selectedCalendarIds` | `GoogleCalendarSource(calendarIds:)` | `filterGoogleCalendarIds()` in factory + both screen call sites | ✓ WIRED | WINDOWS entry 5 fix confirmed |
| `detectSelectedCalendarOverlaps()` | picker row note | `calendar_settings_screen.dart` (per `36-06-SUMMARY.md`, confirmed by passing overlap-disclosure tests) | ✓ WIRED | Test named "the note is not error-tinted" and 4 related tests pass |
| `.google-client-id` | `Info.plist` CFBundleURLTypes + `--dart-define` | `tools/build-ios.sh` | ⚠️ Verifiable only up to script logic here | Cannot confirm Xcode actually substitutes the build setting — that is UAT items 1/3/4 |

### Behavioral Spot-Checks / Test Run

Ran the phase's calendar-related test directories **once** (not the full suite, not repeated per
must-have): `test/data/calendar/`, `test/data/migration_schema12_test.dart`,
`test/data/migration_schema_test.dart`, `test/screens/settings/calendar_settings_screen_test.dart`,
`test/screens/settings/settings_screen_calendar_row_test.dart`, `test/tools/build_ios_wrapper_test.dart`.

**Result: 125/125 passed.** This includes the named tests that directly prove the behavior-dependent
truths above (reconnect-flag lifecycle, no-dedup contract, schema round-trip, WR-fix regressions).
`flutter analyze`: **No issues found.**

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|---|---|---|---|
| CALAUTH-01 | connecting Google Calendar is a button, not a manual URL hunt | **Code present and tested here; user-facing behavior unconfirmed on device** | Button exists, correctly gated to iOS, wired to a real consent launcher (code-verified). Whether tapping it produces Google's actual account picker on a real phone is UAT item 1 — open. |
| CALAUTH-02 | Canopy holds a read-only Google token and cannot write, enforced by scope | ✓ SATISFIED (as far as danserver can prove) | Single named scope, no mutating verb reachable, grep-confirmed. Google's own consent-screen wording (the stronger, Google-stated guarantee) is UAT item 2 — open, but does not weaken this requirement's own satisfaction, since the enforcement is server-side by Google regardless of what the consent screen says. |
| CALAUTH-03 | expired/revoked token degrades visibly with one-tap reconnect, never silently stale | **Code present and behaviorally tested here; the human-perceptible wording distinction is unconfirmed** | Three-way classification and full flag lifecycle verified behaviorally (tests, not just presence). The literal requirement — "degrades **visibly**" and reads differently from an offline failure — is inherently a UI/copy judgment; UAT item 5 explicitly tests whether the expired-message and offline-message read as two different sentences. Open. |
| CALAUTH-04 | no client secret exists in the repository | ✓ SATISFIED | Grep-confirmed empty, confirmed unreachable by construction (native client, no secret issued), and QUESTIONS.md Q-01's client-ID (not secret) exposure reasoned through and found not to violate this requirement as written. |

**Orphaned requirements:** None found — all four requirement IDs given in the task are covered by
declared `requirements:` fields across the 7 plans.

### Anti-Patterns Found

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any file touched by this phase
(checked via the phase's own key-files lists and the review's 29-file list). No stub return values,
no hardcoded-empty props flowing to render. The one genuine gap identified (WR-05, unfixed) is
tracked above under its own heading rather than as a silent anti-pattern, since it was explicitly
scoped as WARNING-tier, non-data-loss, non-security in the code review.

## Correctly Deferred to the Owner's Hardware

None of the following can be settled on danserver — no Xcode, no iOS device, ever. Each is code-present
and test-covered as far as an injected seam can prove, and each is explicitly the subject of a
`36-UAT.md` item:

1. **Whether tapping the button actually shows Google's real account picker** (CALAUTH-01, UAT item 1) — `ASWebAuthenticationSession` + the registered redirect scheme round-tripping is unprovable without Xcode.
2. **Google's real consent-screen wording naming read-only access** (CALAUTH-02, UAT item 2) — the exact string Google renders is outside this repo's control and only visible on a real consent sheet.
3. **Whether both cancellation paths (Cancel button, swipe-dismiss) throw the one exception type the code catches** (Assumption A7, UAT item 3) — the code proves one type is translated correctly; whether every real iOS dismissal path throws it is unverified.
4. **Whether Google actually issues a durable refresh token to a secret-free iOS client, surviving an app restart** (Assumption A6, UAT item 4) — this is the premise the entire native-flow decision (D-36-01) rests on, and it has never been observed against Google's real token endpoint.
5. **Whether the expired-token message and the offline message read as two genuinely different sentences** (CALAUTH-03's literal "degrades visibly" requirement, UAT item 5) — a perceptual/wording judgment, exactly the class of thing this project's own CLAUDE.md documents as having been missed by green suites five times.
6. **Whether the double-tick overlap warning reads clearly enough to stop the owner doing it by accident** (D-36-03's REQUIRED mitigation, UAT item 6) — the detector's logic and its non-dedup behavior are code/test-verified above; whether the resulting UI copy actually reads as intended to a human is explicitly out of reach for a widget test, per D-36-03's own text.
7. **Whether Google's real 7-day token-expiry endpoint emits the exact `400 + invalid_grant` body shape the code classifies on** (part of Assumption A3) — the revoke-by-hand half is testable in one sitting (UAT item 5); the natural 7-day expiry is explicitly deferred to "about a week from now" per `36-UAT.md`'s own note.
8. **Whether the whole restructured Calendars screen reads as ONE coherent screen** (36-06's own stated open question) — a visual/UX coherence judgment, not inferable from widget tests per this project's own documented pattern (Phases 27, 29, 31, 32 twice).

Additionally, **Phase 35's Assumption A1** (whether `device_calendar_plus.listEvents()` returns
already-expanded occurrences with exceptions applied) remains unverified and load-bearing for this
phase's own "correction on the record" in `36-DECISIONS.md` — `36-UAT.md` Section A carries this
forward correctly as a prerequisite to Section B's item 6.

## Genuinely Missing or Wrong

**None found.** Every artifact, key link, and danserver-verifiable truth this phase's own must-haves
list (across all 7 plans) claimed was checked directly against the code and, where the claim was
behavior-dependent (reconnect lifecycle, no-dedup contract, schema migration safety), against a
passing named test — not merely against symbol presence. The one open code-review item (WR-05) was
never claimed fixed by any commit or SUMMARY, so its absence is not a discrepancy between claim and
reality; it's accurately an acknowledged residual warning.

The QUESTIONS.md Q-01 (client ID exposure) and Q-02 (stale migration-comment premise) items are both
correctly out of this phase's declared scope, correctly not silently absorbed into a "done" claim by
any SUMMARY, and correctly still open for the owner.

## Human Verification Required

See `36-UAT.md` in this phase directory — the instrument this phase itself built for exactly this
purpose. It is comprehensive: it cross-references every "unverified" statement from every 36-0N
SUMMARY against the specific UAT item that settles it (see its own "Cross-check" table), carries
forward Phase 35's still-open device gate as a prerequisite (Section A), and states the mandatory
Step 0 re-check-in discipline up front. This verifier did not restate its contents — the summary
above ("Correctly Deferred") maps each deferred truth to its UAT item number; do not judge any of
those from source code, only from a completed run of that document.

## Gaps Summary

**⚠ THIS SECTION WAS ACCURATE ON 2026-09-28 AND IS NOW SUPERSEDED. See the addendum below.**

No gaps. The phase's danserver-reachable work is complete, tested behaviorally (not just present),
and every code-review warning that was claimed fixed is genuinely fixed in the current tree. The
phase is correctly blocked on the owner's MacBook, which is the only place its remaining
requirements can be observed — this is the plan's own design (`36-07`, `gate="blocking-human"`), not
an execution shortfall.

---

_Verified: 2026-09-28_
_Verifier: Claude (gsd-verifier)_

---

## ADDENDUM 2026-10-06 — the device gate RAN, and it found three defects

**Added by the orchestrator, not by `gsd-verifier`. The 2026-09-28 report above is unaltered** —
nothing in it was wrong for what it set out to check, and it is not being rewritten to look
prescient.

**What changed:** the `blocking-human` gate this report correctly stopped at is no longer
hypothetical. The owner built Phase 36 on his MacBook and ran it on his real iPhone on **2026-10-06**.
He stopped the sitting partway through, by his own call, once the findings made the rest not worth
judging. `status` therefore moves `human_needed` → `gaps_found`: the human step *happened* and
returned results. `## Human Verification Required` still stands for the re-visit afterwards.

### Why these gaps are recorded in this file at all

`/gsd-plan-phase <N> --gaps` takes exactly two inputs: **this file** and **`36-UAT.md`**. It does
**not** read `WINDOWS.md`. The three defects were originally logged only to `WINDOWS.md` and
`STATE.md`, and `36-UAT.md`'s answers section was left blank (`36-07` Task 3 was never done). Had
gap-closure planning run against those two files as they stood, it would have read `gaps: []` and a
blank UAT, found **no evidence any defect existed**, and planned nothing — while three real defects sat
in a file it never opens. Both inputs have now been filled in from the same evidence.

### The three gaps — see frontmatter `gaps:` for the structured form

| Gap | What it breaks | Fixed by fixing the others? |
|---|---|---|
| **Entry 7** — ticked calendar selection never reaches the device source; the plugin imports every calendar | **CAL-02 violated** | No |
| **Entry 8** — all-day events import as blocking `08:00–22:00`; six working days erased in 12 days | Schedule unusable in normal use | **No — and explicitly not by entry 7.** `Payday` sits on a calendar nobody would untick |
| **Entry 10** — skipped-events disclosure exists and is tested but is not discoverable | Disclosure's purpose | No — and it becomes **more** load-bearing once entry 8 is fixed |

**Entry 8's target behaviour is settled, not open:** `D-36-05` (ruled 2026-10-06) supersedes `D-35-06`
— all-day events are **skipped and disclosed, never imported**. Do not re-ask the owner, and do not
plan work on `D-35-06`'s old 10-vs-14-hour span question, which `D-36-05` closes by removing the
behaviour.

### What the device gate also PROVED, which this report could not

**Phase 35 Assumption A1 is VERIFIED on real hardware** — the single most load-bearing claim of Phase
35. `device_calendar_plus` does return expanded occurrences with exceptions applied: `Canopy test`
imported twice, at `2026-10-06 09:00` (base) and `2026-10-13 09:10` (the moved occurrence, **at its new
time**). This **confirms** `36-DECISIONS.md`'s "Correction on the record" — Google sign-in adds no
recurrence advantage on the device path.

**This nearly went the other way, and the near-miss is the most transferable lesson of the sitting.**
The owner first reported the moved occurrence as missing entirely; it was filed as a bug (`WINDOWS.md`
entry 9) that would have *reversed* that Correction. It was withdrawn after the device's Hive was read
directly and showed the event present all along — absent from *Today* only because the moved instance
falls a week out, and Today renders today. Entry 9 is **waived with its evidence, not deleted**.

**The method, which outperformed asking what was on screen and should be reached for first next
time:** `xcrun devicectl device copy from --device <id> --domain-type appDataContainer
--domain-identifier com.danjjohnson.canopy --source / --destination <dir>`, then a throwaway test that
`Hive.init(dir)`s and dumps the box through the project's own adapters. It settled both real defects
*and* overturned the false alarm. Three of this project's green-suite misses were cases where a screen
was described rather than data read.

_Addendum: 2026-10-06 — orchestrator, from WINDOWS.md entries 7–10 and the STATE.md device-UAT record._
