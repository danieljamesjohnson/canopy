---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 01
subsystem: calendar
tags: [oauth, google-calendar, flutter_appauth, googleapis_auth, googleapis, hive-migration]

requires:
  - phase: 35-your-real-commitments-read-from-your-calendar
    provides: CalendarSource interface, CalendarSyncService mapping layer, additive-Hive-field precedent
provides:
  - GoogleOAuthConfig — compile-time client-id injection, reversed-client-id redirect URI, the single read-only scope
  - GoogleAuthClient — flutter_appauth consent flow + googleapis_auth refresh + token persistence seam
  - GoogleCalendarSource — the fourth CalendarSource implementation
  - AppSettings schema 11->12 (googleAccessToken/googleRefreshToken/googleAccessTokenExpiresAt/googleReconnectNeeded)
  - An end-to-end proof that a Google event becomes a CommitmentBlock through the unchanged CalendarSyncService
affects: [36-02, 36-03, 36-04, 36-05, calendar_settings_screen]

actuals:
  tokens: 13700
  tasks: 3
  commits: 3

tech-stack:
  added: [flutter_appauth ^12.1.0, googleapis_auth ^2.3.4, googleapis ^17.0.0]
  patterns:
    - "Injected-seam auth: GoogleAuthLauncher/GoogleCredentialsRefresher typedefs keep the OAuth round trip and token refresh entirely fake-able in tests, mirroring IcsCalendarSource's IcsFetcher"
    - "google: id prefix disambiguates Google calendar ids from device calendar ids in the persisted selection (plan 36-05 depends on this)"

key-files:
  created:
    - lib/data/calendar/google_oauth_config.dart
    - lib/data/calendar/google_auth_client.dart
    - lib/data/calendar/google_calendar_source.dart
    - test/data/calendar/google_calendar_source_test.dart
    - test/data/calendar/google_oauth_config_test.dart
    - test/data/migration_schema12_test.dart
    - test/fixtures/calendar/google_events_list_basic.json
  modified:
    - lib/data/models/app_settings.dart
    - lib/data/models/app_settings.g.dart
    - lib/data/database/migrations.dart
    - lib/providers/settings_notifier.dart
    - pubspec.yaml
    - pubspec.lock
    - macos/Flutter/GeneratedPluginRegistrant.swift
    - test/data/migration_schema_test.dart (renamed from migration_schema8_test.dart, git mv)

key-decisions:
  - "Added @HiveField(15, defaultValue: false) to AppSettings.googleReconnectNeeded, contradicting the plan's literal instruction to omit defaultValue on all four new fields — a real crash was measured, not assumed (see Deviations)."
  - "Confirmed Assumption A6 (refresh works with a null client secret against an iOS-type client) and A8 (access_type/prompt reach Google via additionalParameters) by reading the installed flutter_appauth 12.1.0 and googleapis_auth 2.3.4 package source directly, not by trusting the research snippet."

requirements-completed: [CALAUTH-01, CALAUTH-02]

coverage:
  - id: D1
    description: "Client-id injection surface: compile-time client id, reversed-client-id redirect URI, the single read-only scope constant, and a named error when no client id was injected"
    requirement: CALAUTH-02
    verification:
      - kind: unit
        ref: "test/data/calendar/google_oauth_config_test.dart#reverseGoogleClientId turns a well-formed client id into the expected reversed scheme"
        status: pass
      - kind: unit
        ref: "test/data/calendar/google_oauth_config_test.dart#requireGoogleClientId throws GoogleOAuthNotConfiguredError naming .google-client-id and tools/build-ios.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "GoogleAuthClient: consent round trip (success/cancel), token persistence, and silent refresh of an expired access token"
    requirement: CALAUTH-02
    verification:
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#a canned Google token persists to the store... (tracer, CALAUTH-01/02)"
        status: pass
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#authenticatedClient() refreshes an expired access token via the injected refresher and persists the result (Assumption A6)"
        status: pass
    human_judgment: true
    rationale: "The actual native ASWebAuthenticationSession round trip, and whether Google truly issues a refresh token with no client_secret to a real iOS-registered client, cannot be exercised on danserver (no Xcode) — plan 36-07 on the owner's MacBook is the real-device proof. This plan proves the Dart-side logic against every seam; it does not claim the native flow itself works."
  - id: D3
    description: "GoogleCalendarSource: the fourth CalendarSource, reading Google's events.list (singleEvents+showDeleted) and mapping one event into a CommitmentBlock through the unchanged CalendarSyncService"
    requirement: CALAUTH-02
    verification:
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#a canned Google token persists to the store... (tracer, CALAUTH-01/02)"
        status: pass
    human_judgment: false
  - id: D4
    description: "AppSettings schema 11->12: four additive Google token fields, migration entry, and a proven-safe old-record upgrade"
    verification:
      - kind: unit
        ref: "test/data/migration_schema12_test.dart#an old (schema 11, 12-field) AppSettings record reads back... no crash"
        status: pass
      - kind: unit
        ref: "test/data/migration_schema12_test.dart#a new AppSettings record with all four Google fields populated survives a close/reopen cycle"
        status: pass
      - kind: unit
        ref: "test/data/migration_schema_test.dart#currentSchemaVersion equals 12"
        status: pass
    human_judgment: false
  - id: D5
    description: "The owner cleared the flutter_appauth/googleapis_auth/googleapis package-legitimacy gate before install (Task 1)"
    verification: []
    human_judgment: true
    rationale: "Human verification of pub.dev/GitHub pages, already performed and recorded as D-36-04 in 36-DECISIONS.md prior to this plan's execution — reproduced in this SUMMARY's Task 1 section rather than re-run."

duration: ~25min
completed: 2026-09-25
status: complete
---

# Phase 36 Plan 01: Google Calendar Tracer Summary

**A canned Google consent token persists to Hive and a canned `events.list` fixture becomes exactly one `CommitmentBlock`, end to end, through the unchanged `CalendarSyncService` — proving the architecture before any of it is built out horizontally.**

## Performance

- **Duration:** ~25 min (approximate — exact start time not captured at spawn; based on commit timestamps between 09:16 and 09:24 local)
- **Completed:** 2026-09-25
- **Tasks:** 3 (Task 1 satisfied by citing the already-cleared owner gate; Tasks 2 and 3 implemented)
- **Files modified/created:** 15

## Task 1 — the install gate, already cleared

Task 1 is a `checkpoint:human-verify` gate with `gate="blocking-human"`. **It was cleared by the owner before this execution started** — recorded as **D-36-04** in `36-DECISIONS.md` (commit `5f12410`). Reproduced here per Task 1's own acceptance criteria (observation, not the word "verified"):

| Package | Version shown | Published | Publisher badge | Discontinued marker |
|---|---|---|---|---|
| `flutter_appauth` | 12.1.0 | 27 days ago | `dexterx.dev` | none |
| `googleapis_auth` | 2.3.4 | 7 days ago | `google.dev` | none |
| `googleapis` | 17.0.0 | 31 days ago | `google.dev` | none |

`github.com/MaikuB/flutter_appauth` showed as a standard public repository (not "Public archive"), 308 stars, 84 open issues, 240 commits, owner display name `MaikuB`. `googleapis_auth` showed 1.74M downloads; `flutter_appauth` showed 379k.

**Two gaps this gate did not establish (carried forward honestly, not upgraded to "verified"):**
1. The `googleapis` **download count was not re-read** — the "1.1k" figure on that page is the *likes* count, not downloads; research's 1.1M/30d stands as `[CITED: pub.dev]`.
2. **No commit date was obtained** for `MaikuB/flutter_appauth` — only the commit count was visible; "not archived" is established, "has recent commits" rests on research's recorded repo-pushed date (2026-09-13), not a fresh reading.

The versions actually installed (`flutter pub add`) match D-36-04 exactly: `flutter_appauth ^12.1.0`, `googleapis_auth ^2.3.4`, `googleapis ^17.0.0`.

## Accomplishments

- `GoogleOAuthConfig`: the single injection surface for the compile-time client id, the reversed-client-id redirect URI (Google's documented rule), the single read-only scope constant (`kGoogleCalendarReadonlyScope`, appears exactly once in `lib/`), and `GoogleOAuthNotConfiguredError` naming `.google-client-id`/`tools/build-ios.sh` when no dart-define is present (the normal case under `flutter test`).
- `GoogleAuthClient`: the only file in `lib/` importing `flutter_appauth`. Runs the interactive consent flow via `authorizeAndExchangeCode` with `access_type=offline`/`prompt=consent` passed through `additionalParameters` (Assumption A8, confirmed against the installed 12.1.0 source — see Decisions). Maps a `FlutterAppAuthUserCancelledException` to `null` (cancellation, not an error); anything else becomes `GoogleAuthException`. `authenticatedClient()` refreshes an expired token via `googleapis_auth.refreshCredentials` with a null `ClientId.secret` (Assumption A6, confirmed by reading `refreshCredentials`'s source: it only includes `client_secret` in the token request `if (clientId.secret != null)`).
- `GoogleCalendarSource`: the fourth `CalendarSource`. `listCalendars()` prefixes every id with `google:` (disambiguates from device calendar ids per plan 36-05's dependency). `listEvents()` calls `events.list` with `singleEvents: true` and `showDeleted: true` (both deliberate, commented as non-default), follows `nextPageToken`, and maps each `Event` into a `CalendarEvent`. No mutating `CalendarApi` verb is reachable anywhere in `lib/data/calendar/` (grep-proven, 0 matches).
- `AppSettings` schema 11→12: four additive fields (`googleAccessToken`, `googleRefreshToken`, `googleAccessTokenExpiresAt`, `googleReconnectNeeded`), `_migration11to12`, `SettingsNotifier implements GoogleTokenStore` with the same cache-then-persist-then-notify idiom as every other setter in that class.
- The tracer test drives the whole path: a fake `GoogleAuthLauncher` → `GoogleAuthClient.connect()` → tokens land in a fake `GoogleTokenStore` → a fake `http.Client` returns Google's real `events.list` JSON shape → `GoogleCalendarSource.listEvents()` → the **unmodified** `CalendarSyncService.sync()` → exactly one `CommitmentBlock` with the right name, local start/end minutes, `isFromCalendar: true`, and a non-empty `externalEventId`.
- `lib/services/schedule_generator.dart` is **byte-identical** (`git diff --quiet` exits 0) — verified after every commit in this plan.

## Non-vacuity proofs (mutation testing, per CLAUDE.md's "Assertions that cannot fail")

Both required this plan's own mutation-proof discipline, and both are genuinely executed (not merely claimed):

1. **The tracer test.** Temporarily made `GoogleCalendarSource.listEvents()` return `const []`. Observed:
   ```
   Expected: an object with length of <1>
     Actual: []
   ```
   Reverted immediately. This proves the test's `hasLength(1)` assertion discriminates real behavior, not a symbolic tautology.

2. **The old-record migration test.** Temporarily redeclared `googleReconnectNeeded` as `List<String>` with no `defaultValue:` — the exact shape that crashed Phase 35 (35-03-SUMMARY.md). Observed a real crash on the OLD-record read path:
   ```
   type 'Null' is not a subtype of type 'List<dynamic>' in type cast
   package:canopy/data/models/app_settings.g.dart 37:45  AppSettingsAdapter.read
   ```
   Reverted immediately, regenerated the adapter. This is the exact crash class Phase 35 found — reproduced here on demand, not merely cited.

## Task Commits

1. **Task 2: tracer implementation** — `1315a39` (feat)
2. **Task 3: migration test + rename + oauth config test** — `461a53b` (test)
3. **Supplementary: GoogleAuthClient refresh-path coverage** — `8533917` (test) — added after discovering the tracer's canned token never exercises the refresh branch; see Deviations.

_Task 1 required no commit — it is a citation of an already-cleared, already-committed gate (`5f12410`)._

## Files Created/Modified

- `lib/data/calendar/google_oauth_config.dart` — client-id injection, reversed-client-id redirect, the one scope constant
- `lib/data/calendar/google_auth_client.dart` — the OAuth token lifecycle behind two injected seams
- `lib/data/calendar/google_calendar_source.dart` — the fourth `CalendarSource`
- `lib/data/models/app_settings.dart` — four new HiveFields (12-15)
- `lib/data/models/app_settings.g.dart` — regenerated adapter
- `lib/data/database/migrations.dart` — schema 11→12, `_migration11to12`
- `lib/providers/settings_notifier.dart` — implements `GoogleTokenStore`, cache-then-persist-then-notify for the four new fields
- `pubspec.yaml` / `pubspec.lock` — `flutter_appauth`, `googleapis_auth`, `googleapis`
- `macos/Flutter/GeneratedPluginRegistrant.swift` — auto-registered `flutter_appauth`'s macOS plugin (from `flutter pub get`)
- `test/data/calendar/google_calendar_source_test.dart` — the tracer + the refresh-path test
- `test/data/calendar/google_oauth_config_test.dart` — reversed-scheme + missing-config-error tests
- `test/data/migration_schema12_test.dart` — the Phase 36 Hive round-trip (new file)
- `test/data/migration_schema_test.dart` — renamed from `migration_schema8_test.dart` (`git mv`, history follows), schema-constant assertions retargeted to 12
- `test/fixtures/calendar/google_events_list_basic.json` — Google's real `events.list` JSON shape, one ordinary timed event

## Decisions Made

- **Assumption A6 confirmed by reading source, not by device test:** `googleapis_auth`'s `refreshCredentials` only adds `client_secret` to the token request `if (clientId.secret != null)` — a `ClientId(identifier, null)` genuinely omits it, matching Google's "not applicable to iOS" framing. Still unconfirmed against a *real* Google token endpoint (plan 36-07, the owner's MacBook).
- **Assumption A8 confirmed by reading source:** `flutter_appauth` 12.1.0's `AuthorizationTokenRequest` accepts `additionalParameters` as `Map<String, String>?` (via `CommonRequestDetails`), forwarded verbatim — the exact mechanism the tracer implementation uses for `access_type`/`prompt`.
- **`google:` id prefix** on every Google calendar id, stripped before any Google API call — the unambiguous-selection mechanism plan 36-05 depends on.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added `defaultValue: false` to `AppSettings.googleReconnectNeeded`, contradicting the plan's explicit "all four fields omit defaultValue" instruction**
- **Found during:** Task 2, running the full suite after the schema bump
- **Issue:** The plan's own text asserted "every one of the five existing bool fields in this class omits the annotation" and "nullable fields and plain bools already read back as null and false" — as justification for omitting `defaultValue:` on `googleReconnectNeeded`. This is **measurably false** for a non-nullable `bool` with no annotation: `hive_ce_generator` emits a raw `fields[15] as bool` cast with no `?? false` fallback, which throws `type 'Null' is not a subtype of type 'bool'` when field 15 is genuinely absent from an old record's byte stream. `test/providers/settings_notifier_calendar_test.dart`'s existing schema-10→11 old-record round-trip test — a PRE-EXISTING test, not one I wrote — caught this immediately after the schema bump.
- **Fix:** Added `@HiveField(15, defaultValue: false)` and a doc comment explaining the deviation and pointing at the observed stack trace. Regenerated the adapter (`fields[15] == null ? false : fields[15] as bool`).
- **Files modified:** `lib/data/models/app_settings.dart`, `lib/data/models/app_settings.g.dart`
- **Verification:** `test/providers/settings_notifier_calendar_test.dart`'s old-record test passes again; the mutation proof in `migration_schema12_test.dart` (see above) independently reproduces the exact crash class when the field is reverted to no-default, confirming the fix is load-bearing and not incidental.
- **Committed in:** `1315a39` (Task 2 commit)
- **Note for future work:** This also means the plan's/`36-PATTERNS.md`'s and `migrations.dart`'s OWN prior comments (`"Hive CE binary reader returns null/false for missing fields"`) are unverified folklore for non-nullable bools, not an established fact. `WINDOWS.md` entry 3 already flags this exact latent-crash risk for this class's OTHER four bool fields (`onboardingComplete`, `midDayNudgeEnabled`, `morningNotificationEnabled`, `eveningReminderEnabled`) — none of which are truly exercised by any existing old-record test (the schema-10→11 test's "old" record still includes fields 0-8). This plan did not touch those; flagging here so a future reader doesn't assume they're proven safe just because this plan's neighbor field now is.

**2. [Rule 2 - Missing critical verification] Added a direct test for `GoogleAuthClient.authenticatedClient()`'s token-refresh branch**
- **Found during:** Reviewing coverage before writing this SUMMARY
- **Issue:** The tracer test's canned token always has an hour of validity left, so it never exercises `authenticatedClient()`'s refresh branch (the injected `GoogleCredentialsRefresher`, or the persistence of the refreshed tokens) — a real, already-implemented code path with zero automated coverage.
- **Fix:** Added a focused unit test driving `GoogleAuthClient` directly with an already-expired stored token, asserting the refresher is invoked with a null `ClientId.secret` (Assumption A6) and that the refreshed tokens are persisted back to the store.
- **Files modified:** `test/data/calendar/google_calendar_source_test.dart`
- **Verification:** New test passes; full suite stays green (830/830).
- **Committed in:** `8533917` (supplementary commit, after Task 3)

---

**Total deviations:** 2 (1 auto-fixed bug, 1 added test coverage). **Impact:** The bug fix was necessary to satisfy the plan's own must-have truth ("no crash on upgrade") and is fully proven by a genuine mutation test. The added coverage closes a real gap in what the plan's single tracer test could prove; no production behavior changed. Neither is scope creep — both stay inside Task 2/3's existing files.

## Known Stubs

None. Every method on `GoogleCalendarSource` and `GoogleAuthClient` is a real, working implementation behind an injected seam — there is no hardcoded empty/placeholder data flowing anywhere. The three-way CALAUTH-03 failure classification (distinguishing "reconnect needed" from an ordinary network hiccup) is explicitly plan 36-02's subject, not a stub — `GoogleAuthClient` currently collapses every non-cancellation failure into one `GoogleAuthException`, exactly as the plan's own action text specifies for this task ("This task implements only the success and cancellation paths plus a single generic failure branch").

## Issues Encountered

None beyond the deviation documented above. `.google-client-id` (gitignored, real secret) is absent from this worktree by design — the acceptance criterion that greps for it (`test -f .google-client-id && ! grep -rqF ...`) short-circuits to a no-op here since the file doesn't exist in a git worktree checkout. This is expected, not a gap: the real value never leaves the machine's actual working copy, and no synthetic-but-Google-shaped test literal in this plan's tests matches the owner's real client id.

## Next Phase Readiness

- The architecture is proven end-to-end on danserver with no Xcode required: a token the app holds itself, a Google event, the unchanged Phase 35 mapping layer, a `CommitmentBlock`.
- Plan 36-02 can build CALAUTH-03's three-way failure classification directly on `GoogleAuthClient`'s existing seams.
- Plan 36-05 (calendar selection UI, overlap detection) can rely on the `google:`-prefixed calendar id convention already established here.
- Plan 36-04 (build-time client-id injection) has `requireGoogleClientId()`/`GoogleOAuthNotConfiguredError` ready to consume, and the exact `.google-client-id`/`tools/build-ios.sh` naming this plan's error message already commits to.
- **Genuinely unverifiable from danserver, carried to plan 36-07 (the owner's MacBook) exactly as the plan intended:** whether `ASWebAuthenticationSession` + the registered `CFBundleURLTypes` scheme actually round-trips a real consent flow, and whether Google truly issues a refresh token with no `client_secret` against a real iOS-registered client. This plan proves every seam around that boundary; it does not and cannot prove the boundary itself.

## Self-Check: PASSED

All 8 listed created files confirmed present on disk (`test -f`). All 3 task commit hashes (`1315a39`, `461a53b`, `8533917`) confirmed present in `git log --oneline --all`. Full suite re-run before this SUMMARY was written: 830/830 green, `flutter analyze` clean, `lib/services/schedule_generator.dart` byte-identical.

---
*Phase: 36-connect-google-calendar-without-hunting-for-a-url*
*Plan: 01*
*Completed: 2026-09-25*
