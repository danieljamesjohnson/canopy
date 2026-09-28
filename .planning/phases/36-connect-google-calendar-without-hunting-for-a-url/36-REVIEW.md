---
phase: 36-connect-google-calendar-without-hunting-for-a-url
reviewed: 2026-09-28T00:00:00Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - lib/data/calendar/calendar_event.dart
  - lib/data/calendar/calendar_overlap.dart
  - lib/data/calendar/calendar_source_factory.dart
  - lib/data/calendar/composite_calendar_source.dart
  - lib/data/calendar/device_calendar_source.dart
  - lib/data/calendar/google_auth_client.dart
  - lib/data/calendar/google_calendar_source.dart
  - lib/data/calendar/google_oauth_config.dart
  - lib/data/database/migrations.dart
  - lib/data/models/app_settings.dart
  - lib/data/models/app_settings.g.dart
  - lib/providers/settings_notifier.dart
  - lib/screens/schedule/checkin_screen.dart
  - lib/screens/settings/calendar_settings_screen.dart
  - lib/screens/settings/settings_screen.dart
  - tools/build-ios.sh
  - ios/Runner/Info.plist
  - ios/Flutter/Debug.xcconfig
  - ios/Flutter/Release.xcconfig
  - .gitignore
  - .github/workflows/ci.yml
  - android/app/build.gradle.kts
  - pubspec.yaml
  - test/data/calendar/calendar_overlap_test.dart
  - test/data/calendar/calendar_source_factory_test.dart
  - test/data/calendar/composite_calendar_source_test.dart
  - test/data/calendar/device_calendar_source_mapping_test.dart
  - test/data/calendar/google_auth_client_test.dart
  - test/data/calendar/google_calendar_source_test.dart
  - test/data/calendar/google_oauth_config_test.dart
  - test/data/migration_schema12_test.dart
  - test/data/migration_schema_test.dart
  - test/screens/settings/calendar_settings_screen_test.dart
  - test/screens/settings/settings_screen_calendar_row_test.dart
  - test/tools/build_ios_wrapper_test.dart
findings:
  critical: 0
  warning: 5
  info: 0
  total: 5
status: issues_found
---

# Phase 36: Code Review Report

**Reviewed:** 2026-09-28
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Reviewed the Google Calendar OAuth integration (native iOS, PKCE, no client secret) against the
priorities called out in the review brief: token handling, client-ID secrecy, read-only scope
enforcement, `CompositeCalendarSource` partial-failure semantics, `calendar_overlap.dart`'s
no-dedup contract, CAL-04 usability with no calendar access, and the two CLAUDE.md-documented test
traps (`find.byType` subclass matching, tight-constrained layout harnesses).

**The security-critical surfaces are clean.** No token or client secret is ever logged, printed,
or embedded in an exception message (`GoogleAuthException`/`GoogleSourceException` both discard the
original error object rather than stringify it). `.google-client-id` and the generated
`GoogleOAuth.xcconfig` are gitignored and have never been committed (checked git history directly,
not just `.gitignore`). `tools/build-ios.sh` never echoes the client ID, uses `set -euo pipefail`
throughout, and quotes every expansion. No mutating `CalendarApi` verb (`insert`/`update`/`patch`/
`delete`/`move`) is reachable anywhere under `lib/data/calendar/` or `lib/services/` (grep-confirmed),
and the OAuth scope requested is exactly the one `calendar.readonly` constant, asserted in tests
against a bare literal rather than re-derived. `calendar_overlap.dart` correctly never dedups,
filters, or reorders, matching D-36-03 — confirmed by both reading it and by the "nothing is
de-duplicated" widget test. The Hive schema 11→12 migration and its generated adapter are internally
consistent (`googleReconnectNeeded`'s `defaultValue: false` is correctly wired through the generated
`read()`). `flutter analyze` is clean and the full calendar-related test suite (`flutter test`, 119
tests across the files listed above) passes.

**What's left is a small set of real robustness/quality gaps**, all WARNING-tier — none of them lose
data, leak a credential, or grant write access, but each is a genuine defect a future user or
maintainer could hit. No BLOCKER-tier issue was found. No violation of either CLAUDE.md test trap
was found in the new/changed tests: `find.byType` is used only for genuinely leaf/non-subclassed
widgets (`CheckboxListTile`, `CircularProgressIndicator`, `SnackBar`, `AlertDialog`), while role-based
assertions (the denied card's color, the reconnect icon's tint) correctly use
`find.byWidgetPredicate`; there is no tight-constrained-harness pattern in this phase's tests (no
`SizedBox(height: N)` wrapping a widget under layout-collapse test).

## Warnings

### WR-01: `CompositeCalendarSource.listCalendars()` has no per-child failure isolation, unlike `listEvents()`

**File:** `lib/data/calendar/composite_calendar_source.dart:59-66`
**Issue:** The class's own doc comment states the "one judgement call in this class" is to "catch
each child's failure independently, and rethrow only when EVERY child failed" — and `listEvents()`
implements exactly that. `listCalendars()` does not:

```dart
Future<List<CalendarInfo>> listCalendars() async {
  final infos = <CalendarInfo>[];
  for (final child in _children) {
    infos.addAll(await child.listCalendars());   // no try/catch
  }
  return infos;
}
```

If any child's `listCalendars()` throws (e.g. `GoogleSourceException` from a Google API hiccup),
the whole call throws — including the device child's own perfectly good calendar list. This
contradicts the documented per-child tolerance and is inconsistent with `listEvents()`'s behavior
on the same class. Today this is latent rather than user-visible: grepping `lib/` shows
`CompositeCalendarSource.listCalendars()` is never actually invoked in production (the settings
screen calls `listCalendars()` only on the raw `GoogleCalendarSource`/`DeviceCalendarSource`
instances via `_resolveGoogleSource`/`_resolveDeviceSource`, never on the composite returned by
`_resolveSyncSource`/`defaultCalendarSource`). But it is public API, exercised directly by
`composite_calendar_source_test.dart`'s first test (happy path only, no failure case), and a
plausible future refactor (e.g. wiring the composite directly into the picker) would silently
reintroduce the exact "one dead Google token takes down the device list too" failure mode T-36-17/
T-36-18 were written to prevent for `listEvents()`.
**Fix:** Mirror `listEvents()`'s per-child try/catch, or narrow the class doc comment to state the
per-child tolerance applies to `listEvents()` only (and add a test proving `listCalendars()`'s
actual behavior, whichever is chosen).

### WR-02: The `'google:'` calendar-id prefix is a duplicated magic string, not a shared constant

**File:** `lib/data/calendar/google_calendar_source.dart:32`, `lib/screens/settings/calendar_settings_screen.dart:162`, `lib/screens/schedule/checkin_screen.dart:156-158`
**Issue:** `google_calendar_source.dart` defines `const String _googleIdPrefix = 'google:';` but it's
private (leading underscore), so the two other call sites that need the exact same prefix —
`CalendarSettingsScreen._googleSelectedIds` and `CheckinScreen._generate()`'s
`.where((id) => id.startsWith('google:'))` — hardcode the literal string independently instead of
importing a shared constant. All three currently agree, but nothing enforces that: a future rename
of the prefix in `google_calendar_source.dart` (e.g. to disambiguate from a second Google-like
source) would silently desynchronize the other two call sites, and `_googleSelectedIds`/the
checkin-time filter would then pass `GoogleCalendarSource` a list of zero calendar ids — check-in
would silently stop importing Google events with no error and no test would catch it, since the
existing tests each construct their own literal `'google:...'` ids rather than referencing a shared
source of truth either.
**Fix:** Export `_googleIdPrefix` as a public constant (e.g. `googleCalendarIdPrefix`) from
`google_calendar_source.dart` (or move it to `calendar_event.dart` alongside the other
cross-cutting calendar constants) and reference it from both `calendar_settings_screen.dart` and
`checkin_screen.dart`.

### WR-03: A Google calendar list with no detected primary entry mislabels its rows under "This device"

**File:** `lib/data/calendar/google_calendar_source.dart:207-213`, `lib/screens/settings/calendar_settings_screen.dart:554-557, 577`
**Issue:** `GoogleCalendarSource.listCalendars()` only sets `accountName` on every returned
`CalendarInfo` when a `primary == true` entry is found in the response:

```dart
String? accountEmail;
for (final entry in entries) {
  if (entry.primary == true) { accountEmail = entry.id; break; }
}
```

If Google's `calendarList.list()` response never contains a primary entry (an edge case, but not
impossible — e.g. a restricted view, or a future API change), every Google calendar in that
response gets `accountName: null`. `_calendarRows` — now shared between the device section and the
new Google section as of this phase — groups by `calendar.accountName ?? ''` and renders the
group header as literally `'This device'` for the empty-string bucket:

```dart
entry.key.isEmpty ? 'This device' : entry.key,
```

That fallback text was previously safe because only device calendars (which genuinely have no
account concept when local) ever hit it. Now that the same function renders the Google section too,
a null-`accountName` Google calendar would be grouped under a header that actively asserts it's a
device calendar — a real mislabeling of data source, not just a missing group name, and it would
also silently prevent that calendar from ever being flagged by the overlap detector (which requires
a non-null `accountName` on both sides).
**Fix:** Either guarantee `GoogleCalendarSource.listCalendars()` always has a non-null account label
(e.g. fall back to a fixed `'Google'` account bucket instead of `null` when no primary is found), or
have `_calendarRows` use `calendar.sourceLabel` rather than a shared empty-string convention to
decide the "no account" fallback text.

### WR-04: Token expiry check has no safety buffer before use

**File:** `lib/data/calendar/google_auth_client.dart:250`
**Issue:**

```dart
if (tokens.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
  return gauth.authenticatedClient(http.Client(), _toAccessCredentials(tokens));
}
```

A token that expires in the next few hundred milliseconds is treated as valid and handed straight
to the caller with no refresh. By the time the resulting `http.Client` actually reaches Google
(network latency, any queued work before the request fires), the token can have expired server-side,
so the Calendar API call fails with an auth error that `GoogleCalendarSource` then wraps as a
generic `GoogleSourceException` — a sync failure the user sees as "showing your last-known
calendars" even though a proactive refresh one call earlier would have avoided it entirely. This
is a narrow race window, not a systemic failure, but it's an unforced one: nothing prevents adding
margin here.
**Fix:** Compare against `DateTime.now().toUtc().add(const Duration(seconds: 30))` (or similar) so a
token that's about to expire gets refreshed proactively instead of raced.

### WR-05: A transient `listCalendars()` failure right after a successful Google sign-in reverts the UI to "not connected" despite a valid, persisted connection

**File:** `lib/screens/settings/calendar_settings_screen.dart:719-749`
**Issue:** `_connectGoogle()` wraps the whole post-permission flow in one catch-all:

```dart
final permission = await source.requestPermission(); // persists tokens on success
if (permission != CalendarPermissionState.granted) {
  return const _GoogleState(connected: false);
}
final calendars = await source.listCalendars();       // can throw AFTER tokens are persisted
...
} catch (_) {
  return const _GoogleState(connected: false);
}
```

`source.requestPermission()` calls `GoogleAuthClient.connect()`, which persists the new tokens to
Hive (via `SettingsNotifier`) as soon as the interactive consent succeeds — before `listCalendars()`
is ever called. If `listCalendars()` then throws (a transient network blip, a `GoogleSourceException`
from any Calendar API hiccup), the catch returns `_GoogleState(connected: false)`, so the screen
renders the plain "Connect Google Calendar" CTA again — indistinguishable from having never
connected — even though a valid token pair is now sitting in `SettingsNotifier`/Hive. The class doc
comment explicitly accepts folding a genuine API failure into "no error copy, same as cancelled",
but doesn't address the knock-on effect: tapping "Connect Google Calendar" again calls
`GoogleAuthClient.connect()` again, which always launches a fresh interactive consent screen
(`additionalParameters: {'prompt': 'consent'}` forces re-consent unconditionally) — so the user is
made to sign in a second time for a connection that, from the token store's perspective, already
succeeded the first time. No data is lost and `reconnectNeeded` is correctly left `false` (this
isn't CALAUTH-03's case), but the UI's connected/not-connected signal genuinely disagrees with
persisted state for the rest of this screen session.
**Fix:** On a `listCalendars()` failure after a successful `requestPermission()`, prefer a state
that reflects "connected, but couldn't load your calendars right now" (with a retry that calls
`listCalendars()` again, not `requestPermission()`) rather than folding it into the same
`connected: false` state used for an actual cancellation.

---

_Reviewed: 2026-09-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
