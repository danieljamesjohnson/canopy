# Phase 36: Connect Google Calendar Without Hunting For a URL - Pattern Map

**Mapped:** 2026-09-23
**Files analyzed:** ~9 new/modified artifacts (Dart sources, Hive schema, iOS config, tests)
**Analogs found:** 9 / 9 (all have at least a partial analog; none is a pure invention)

## CRITICAL — RESEARCH.md's architecture section is stale re: the web-flow package stack

CONTEXT.md's decision 4 was **revised, same day, to native iOS** ("Google: the client_secret is not
applicable to ... iOS", custom-URI-scheme redirect, `CFBundleURLTypes`) — this **reverses** the
premise RESEARCH.md's Summary/Architecture Patterns/Standard Stack sections were built on (a
`kIsWeb`-only flow using `flutter_web_auth_2`'s **popup + `postMessage`** pattern against a
**Web-application**-type OAuth client, with Finding B's whole discussion of whether that client type
even supports secret-free PKCE). Concretely, for the planner:

- **`flutter_web_auth_2` is still the right package**, but it must be driven through its **native
  platform path** (`ASWebAuthenticationSession` on iOS via a custom URL scheme callback), not its web
  `auth.html`/`postMessage`/`window.opener` path. The package supports both; RESEARCH.md only
  documents the one the phase no longer uses.
- **`googleapis_auth`'s `ClientId`/PKCE/`obtainAccessCredentialsViaCodeExchange` reasoning is
  UNCHANGED** — decision 1 (PKCE, no secret) is what iOS *does* support per Google's own docs
  (`client_secret` "not applicable" to iOS), so Finding B's entire "Web application clients may
  require a secret" risk is now most likely moot — that finding was specific to the Web-application
  client type this phase no longer registers. **Do not carry Finding B's mitigation (a) — "ship a
  client_secret" — into this phase's plan without re-confirming it is still relevant**; it may be a
  dead branch given the revision.
- **The Architecture Diagram's popup + `oauth-callback.html` + `tailscale serve :8446` machinery
  described in RESEARCH.md does not apply.** There is no static callback page, no `postMessage`, no
  tailnet HTTPS redirect URI to serve. The redirect is the **reversed iOS bundle ID** registered as
  `CFBundleURLTypes` in `Info.plist`, and the round trip stays entirely inside iOS via
  `ASWebAuthenticationSession`. Pitfall 2 (port 8146/8446 collision) is **moot for the OAuth
  round-trip itself** — it only still matters if the phase's own **UAT** build is served over the
  tailnet for unrelated reasons.
- **`kIsWeb` branching throughout Standard Stack/Architecture should become `Platform.isIOS`
  branching**, mirroring `DeviceCalendarSource.isAvailable()`'s existing `Platform.isIOS` check, not
  `kIsWeb`.
- Everything **not** about the transport (PKCE math, token storage shape, `googleapis`'s typed
  Calendar client, the `showDeleted=true`/`singleEvents=true` findings, the `invalid_grant` error
  detection, Pitfall 3's three-way failure split) is transport-independent and **still applies
  unchanged**.

Flag this explicitly to the planner: **the plan's first task should still be an early, cheap
verification step**, but its content changes from "curl the token endpoint by hand against a
Web-application client" to "confirm `ASWebAuthenticationSession` + the registered `CFBundleURLTypes`
scheme actually round-trips a code from Google's consent page back into the running iOS app, and that
the code exchange succeeds with `ClientId(clientId, null)`" — a native-only check that **cannot be
verified on danserver** (no Xcode, no iOS device/simulator attached to this session). See "Not
verifiable on this machine" below.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/data/calendar/google_calendar_source.dart` (`GoogleCalendarSource implements CalendarSource`) | service/adapter | request-response (network, credential-holding) | `lib/data/calendar/ics_calendar_source.dart` | role-match (closest available; see below) |
| `lib/data/calendar/google_auth_client.dart` (PKCE + token lifecycle, split out per RESEARCH's own recommended structure) | service | event-driven (async external consent flow) + request-response (token exchange/refresh) | `lib/services/notification_service.dart` (`requestDarwinPermissions`) for the "leave app, await OS-level result" shape; `ics_calendar_source.dart`'s `IcsFetcher` typedef for the injectable-seam shape | partial (no true analog exists — see Q3 below) |
| `lib/data/models/app_settings.dart` (+4 `@HiveField(12..15)`) | model | CRUD (additive Hive fields) | `lib/data/models/app_settings.dart` itself, fields 9–11 (`selectedCalendarIds`, `icsUrls`, `lastCalendarSyncAt`), added in the immediately prior migration | exact |
| `lib/data/database/migrations.dart` (`_migration11to12`) | migration | batch (one-time schema transform) | `_migration10to11` (same file, lines 104-115) | exact |
| `lib/data/calendar/calendar_source_factory.dart` (extended routing) | config/routing | request-response | itself, current `Platform.isIOS` branch (lines 22-27) | exact |
| `lib/screens/settings/calendar_settings_screen.dart` (Google sign-in button + reconnect state) | component/screen | request-response + CRUD (toggle persisted settings) | itself — the existing `_ctaCard`/`_deniedCard`/`_groupedCalendarList`/`_isMobile` machinery | exact (extend in place, not a new screen) |
| `ios/Runner/Info.plist` (+`CFBundleURLTypes`) | config | — | itself — `NSCalendarsUsageDescription` block (lines 27-38) is the precedent for "additive, commented, CAL-0x-justified plist key" | exact (same file, no other analog needed) |
| `test/data/calendar/google_auth_client_test.dart` | test | unit, injected seam | `test/data/calendar/ics_calendar_source_test.dart` | role-match |
| `test/data/calendar/google_calendar_source_test.dart` | test | unit, injected seam | `test/data/calendar/ics_calendar_source_test.dart` + `test/data/calendar/device_calendar_source_mapping_test.dart` (pure top-level mapping functions) | exact (two-part pattern) |
| `test/data/migration_schema12_test.dart` (new file, following the `migration_schemaN_test.dart` naming precedent) | test | migration/round-trip | `test/data/migration_schema8_test.dart` | exact |
| `test/screens/settings/calendar_settings_screen_test.dart` (extended) | test | widget | itself | exact |

## Pattern Assignments

### `lib/data/calendar/google_calendar_source.dart` (service, request-response)

**Analog:** `lib/data/calendar/ics_calendar_source.dart` — closer than `DeviceCalendarSource` because
both are network-fetching, both need HTTPS enforcement, and both need a typed exception that
`CalendarSyncService` already knows how to catch generically. `DeviceCalendarSource` is the wrong
template for the top-level adapter shape (it wraps a synchronous OS plugin, not an HTTP round trip),
but its **mapping-function split** (pure top-level functions above the class, adapter class below) is
still worth copying for `Event → CalendarEvent` mapping — see Pattern below.

**Constructor / injected-seam shape** (copy from `ics_calendar_source.dart:52-57`):
```dart
class IcsCalendarSource implements CalendarSource {
  IcsCalendarSource({required List<String> urls, IcsFetcher? fetch})
    : _urls = urls,
      _fetch = fetch ?? _defaultFetch;

  final List<String> _urls;
  final IcsFetcher _fetch;
```
`GoogleCalendarSource` needs the equivalent shape but with **two** seams (RESEARCH's own
recommendation, unaffected by the native-iOS revision): a `GoogleAuthLauncher`-shaped seam for the
consent round trip and an injectable `http.Client`-or-equivalent for the Calendar API calls — same
idea as `IcsFetcher`, twice.

**Error type** (copy the shape from `ics_calendar_source.dart:21-28`):
```dart
class IcsSourceException implements Exception {
  IcsSourceException(this.message);
  final String message;
  @override
  String toString() => 'IcsSourceException: $message';
}
```
A `GoogleSourceException` (or similar) should follow this exact shape — but see Pitfall 3 in
RESEARCH.md: unlike `IcsSourceException`, which collapses every failure into one type,
`CalendarSyncService`/the settings screen need to **distinguish** an `invalid_grant` reconnect-needed
failure from an ordinary network failure. The exception type itself can stay this simple; the
distinguishing logic lives in `google_auth_client.dart`, one layer down (see below), which is why
RESEARCH's split into two files is right — don't collapse it back into one class to save a file.

**Reporting unavailability** (copy the shape from `ics_calendar_source.dart:60`):
```dart
@override
Future<bool> isAvailable() async => _urls.isNotEmpty;
```
`GoogleCalendarSource.isAvailable()` should follow the same one-line predicate shape: not-yet-connected
(no stored token) reads the same as ICS's "no URLs configured" — `false`, not a thrown exception. This
is also the CTA-vs-connected-state signal `calendar_settings_screen.dart` already keys off for the
desktop branch (`settings.icsUrls.isEmpty`) — the Google branch should key off the equivalent stored
token presence.

**`requestPermission()`:** Because this is OAuth consent, not an OS permission API, this verb's
semantics are closer to `DeviceCalendarSource.requestPermission()` (fires an interactive flow and maps
the *outcome* onto `CalendarPermissionState`) than to `IcsCalendarSource`'s
`notApplicable` no-op. Concretely: launching the `ASWebAuthenticationSession` consent flow and mapping
"user completed consent" → `granted`, "user cancelled the session" → `denied`. Copy
`DeviceCalendarSource.requestPermission()`'s one-line delegate-and-map shape
(`device_calendar_source.dart:150-159`), not its enum values.

### `lib/data/calendar/google_auth_client.dart` (service, event-driven + request-response)

**No true analog exists in this codebase** — this is the first artifact here that leaves the app,
waits on an external (OS-brokered) UI, and comes back with a result the app must interpret as
success/cancel/failure. The two partial analogs, and exactly what to take from each:

1. **`lib/services/notification_service.dart:requestDarwinPermissions()`** (lines 244-266) — the
   closest existing "request something from the OS, await it, don't crash if declined" shape:
   ```dart
   static Future<void> requestDarwinPermissions() async {
     if (kIsWeb) return;
     if (Platform.isIOS) {
       await _plugin
           .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
           ?.requestPermissions(alert: true, badge: true, sound: true);
       return;
     }
     ...
   }
   ```
   Copy its **platform-guard-first, no-silent-fallthrough** idiom (an explicit `if
   (Platform.isX)` per platform with a trailing comment for every no-op branch) — the same idiom
   `calendar_source_factory.dart`'s own doc comment says it follows. **Do not copy its "fire and
   forget, no return value" shape** — the OAuth flow must return an `AccessCredentials`-shaped result
   or throw, since callers (the settings screen) need to branch on success vs. cancel vs. failure,
   unlike a notification-permission prompt whose outcome the app never needs to branch on
   synchronously.
2. **`ics_calendar_source.dart:13` (`typedef IcsFetcher = Future<String> Function(Uri url);`)** — copy
   the **typedef-as-seam** idiom directly for the two seams RESEARCH.md recommends
   (`GoogleAuthLauncher`, `GoogleApiClientFactory`). This is the mechanism that lets
   `google_auth_client_test.dart` fake the interactive consent step entirely (no simulator, no real
   Google account) — the single most load-bearing pattern for keeping this phase's automated tests
   runnable on danserver.

**CALAUTH-03 detection logic** — no analog exists (this codebase has never previously needed to
distinguish "your credential is dead, reconnect" from "the network hiccupped"). RESEARCH.md's own code
example (the `ServerRequestFailedException` / `invalid_grant` check) is the right shape to build from
directly; there is no existing Canopy code to point the planner at instead. State this as "no analog —
new pattern, use RESEARCH.md's own example" rather than inventing a fake precedent.

### `lib/data/models/app_settings.dart` (model, additive Hive fields)

**Analog:** itself, the immediately-preceding migration (fields 9-11, `app_settings.dart:48-67`).

**Exact pattern to copy:**
```dart
/// [doc comment explaining the field, which requirement it serves, and the
///  additive-field guarantee — follow this file's own established voice]
@HiveField(12)
String? googleAccessToken;

@HiveField(13)
String? googleRefreshToken;

@HiveField(14)
DateTime? googleAccessTokenExpiresAt;

@HiveField(15)
bool googleReconnectNeeded = false;
```

**CURRENT schema version, verified directly (not assumed):** `lib/data/database/migrations.dart:3`
reads `const int currentSchemaVersion = 11;`, and `test/data/migration_schema8_test.dart:27-36`
(despite its filename, this file's own tests were updated in place to assert `equals(11)`, not `8` —
**the filename is stale relative to its content**, flag this for the planner: follow the file's actual
assertions, not its name) independently confirms 11. RESEARCH.md's "schema is at 11, v11→v12" claim is
**verified correct** — no drift found.

**The `@HiveField(defaultValue:)` lesson (35-03-SUMMARY.md), applied to these four fields:** all four
new fields should follow the **nullable-with-no-`defaultValue`** pattern (`String?`,
`DateTime?`) used by `lastCalendarSyncAt` (`app_settings.dart:66-67`, no `defaultValue` needed because
Hive CE's binary reader already returns `null` for a missing nullable field on an old record) — **NOT**
the `defaultValue:`-bearing pattern used by `selectedCalendarIds`/`icsUrls` (`List<String>` fields,
lines 53, 60). The crash Phase 35 hit was specifically a **non-nullable `List<String>` field missing
its `defaultValue:`** — Hive CE has no natural "empty" to fall back to for a collection type the way it
does for `null`/`false`/`0`. The one field here with a non-trivial default,
`googleReconnectNeeded = false`, is a plain `bool` — same safe category as
`eveningReminderEnabled`/`midDayNudgeEnabled` elsewhere in this file, which read back `false` for a
missing field with **no** `defaultValue:` annotation needed (Hive CE's binary reader already returns
`false` for a missing bool field — confirmed by `_migration4to5`'s own comment, `migrations.dart:51-58`).
**Do not add `@HiveField(15, defaultValue: false)`** — it would be redundant, not wrong, but every
other bool field in this class (5 of them) omits it, so adding it here would be an unexplained
inconsistency a reviewer would have to reason about.

**Token store placement — on `AppSettings`, not a separate box.** Precedent: `selectedCalendarIds` /
`icsUrls` / `lastCalendarSyncAt` already live on the single-record `AppSettings` box
(`app_settings.dart:5`, "Single-record box. Always stored at key 'settings'.") rather than in a
per-record box, even though they are conceptually "calendar connection state," not "app settings" in
the strictest sense. A new `google_tokens` box would be the first per-concern box Canopy has ever
introduced for something this size (four scalar fields) — the additive-field-on-`AppSettings` pattern
is cheaper, matches every precedent in this file, and keeps `runMigrations`'s single assert/invariant
(`migrations.dart:117-129`) covering the new fields for free. Name this precedent explicitly to the
planner: **extend `AppSettings`, do not create a new box.**

### `lib/data/database/migrations.dart` (migration)

**Analog:** `_migration10to11` (lines 104-115), copied verbatim in shape:
```dart
Future<void> _migration11to12() async {
  // Phase 36: AppSettings gains googleAccessToken (HiveField 12, String?),
  // googleRefreshToken (HiveField 13, String?), googleAccessTokenExpiresAt
  // (HiveField 14, DateTime?), and googleReconnectNeeded (HiveField 15,
  // bool, default false) — CALAUTH-02/03's persisted Google OAuth token
  // state. All additive fields — Hive CE binary reader returns null/false
  // for missing fields in existing records. Old records deserialize with
  // no Google connection, i.e. every pre-existing user must connect fresh.
  // No data transformation needed.
}
```
Append to `_migrations` list (line 9-21) and bump `currentSchemaVersion` to `12` (line 3). **Never
edit `_migration10to11` or any earlier entry** — the file's own comment at line 8 and the
`runMigrations` assert at lines 124-129 both exist specifically to catch a version bump that forgets
its migration entry, which is the exact class of bug this pattern protects against.

### `lib/data/calendar/calendar_source_factory.dart` (config/routing)

**Analog:** itself. Current shape (verbatim, lines 15-43):
```dart
CalendarSource defaultCalendarSource({List<String> icsUrls = const []}) {
  if (kIsWeb) { ... }
  if (Platform.isIOS) {
    return DeviceCalendarSource();
  }
  return icsUrls.isEmpty ? NullCalendarSource() : IcsCalendarSource(urls: icsUrls);
}
```
Google sign-in must slot into the **iOS branch specifically** per the native-iOS revision — not a new
top-level `kIsWeb`-adjacent branch as RESEARCH.md's now-superseded diagram implied. Fallback order is
therefore an **iOS-internal** question (connected Google token vs. `DeviceCalendarSource`), not an
iOS-vs-web question. The factory signature will need a new parameter (e.g. a stored Google token/flag)
threaded in the same way `icsUrls` already is — copy that exact parameter-threading shape
(`{List<String> icsUrls = const []}` → add `{bool googleConnected = false}` or equivalent), since
callers (`calendar_settings_screen.dart:96`, `settings_notifier`) already have the precedent for
passing persisted `SettingsNotifier` state into this factory function.

### `lib/screens/settings/calendar_settings_screen.dart` (component/screen)

**Analog:** itself — extend in place, do not create a new screen. Read directly, verified:

- **Where the Google button belongs:** inside `_buildMobileBody`'s CTA state (`_ctaCard`, called at
  lines 495-505 and again at 533-543 as the defensive fallback) — that is the existing iOS-only branch
  gated by `_isMobile` (line 93: `bool get _isMobile => !kIsWeb && defaultTargetPlatform ==
  TargetPlatform.iOS;`). **`_isMobile`'s current definition is exactly right for this phase too** — it
  already excludes Android/desktop/web, which matches decision 4's "no button in the hosted browser
  build" acceptance exactly. No change to `_isMobile` itself is needed; the Google button is a *second*
  CTA/action inside the branch `_isMobile` already selects, alongside (not replacing) the existing
  "Allow calendar access" device-permission CTA.
- **Which existing state widgets it reuses:**
  - `_ctaCard` (lines 243-288) — the same "not connected yet, here's why to connect" card shape, reused
    for "not signed into Google yet."
  - `_deniedCard` (lines 378-439) — CALAUTH-03's expired/revoked-token state is structurally the same
    shape as this card ("access is off, here's a button to fix it, everything else still works") — see
    "Visible degradation" below for exactly how to adapt it.
  - `_groupedCalendarList` (lines 441-490), grouped by `calendar.accountName` — Google's calendars
    should flow through this **same** list once connected (a Google account is just another
    `accountName` group), not a separate rendering path. This is the mechanism D-35-04 already chose
    for "show the user whether their Google account is attached" — reuse it rather than building a
    Google-specific list.
  - `_footer` (lines 166-218) — the sync-status line ("Synced Xm ago — N commitments imported") is
    generic over `CalendarSyncResult`/`settings.lastCalendarSyncAt` already; no Google-specific
    change needed here except possibly surfacing `googleReconnectNeeded` (see below).
- **How `_isMobile`/platform branching currently works (verbatim, line 93):**
  ```dart
  bool get _isMobile => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  ```
  D-35-15 narrowed this from `iOS || Android` to iOS-only when Android's calendar source moved off the
  device plugin (see the comment at lines 85-92). This phase does not need to touch this getter —
  Google sign-in is iOS-only by decision 4, which is exactly the set `_isMobile` already selects.

### iOS platform config — `ios/Runner/Info.plist`

**Current structure, read directly:** a single flat `<dict>` (lines 4-81), no existing
`CFBundleURLTypes` key anywhere in the file (confirmed via `grep`, zero matches across `ios/` and
`android/`). The most recent precedent for "add a commented, requirement-ID-justified key" is the
`NSCalendarsUsageDescription`/`NSCalendarsFullAccessUsageDescription` pair added in Phase 35
(lines 27-38), with its own explanatory comment block directly above (lines 27-34) citing CAL-01/CAL-02
and D-35-15.

**Where the new key belongs:** as a sibling key at the same top level, following that exact
comment-then-key convention — e.g. immediately after the `NSCalendarsFullAccessUsageDescription` block
(after line 38) or immediately before `LSRequiresIPhoneOS` (line 39), with a comment block citing
CALAUTH-01/CALAUTH-04 and explaining that the URL scheme is the **reversed Google OAuth client ID**
(not an arbitrary app-chosen scheme), mirroring how the Phase 35 comment explains *why* two similarly-
named keys are both required rather than just adding them silently.

**No analog exists in this repo for the `CFBundleURLTypes` key's own shape** (this is the first
inbound-URL-scheme registration Canopy has needed) — the pattern to follow is Google's own documented
shape (an array containing one dict with `CFBundleURLSchemes` = `[<reversed-client-id>]`), not a Canopy
precedent. Flag this as "no analog for the key's internal shape, only for the file's conventions
around it."

## Shared Patterns

### Injectable seams for external I/O
**Source:** `lib/data/calendar/ics_calendar_source.dart:13` (`typedef IcsFetcher`)
**Apply to:** `google_auth_client.dart` (auth launcher seam, API client factory seam),
`google_calendar_source.dart` (if it needs its own seam beyond what `google_auth_client.dart` already
injects)
```dart
typedef IcsFetcher = Future<String> Function(Uri url);
```

### Platform branching — explicit guard per platform, no silent fallthrough
**Source:** `lib/services/notification_service.dart` (repeated throughout, e.g. lines 33-46, 244-266),
`lib/data/calendar/calendar_source_factory.dart:16-43`
**Apply to:** `calendar_source_factory.dart`'s extended routing, `calendar_settings_screen.dart`'s
`_isMobile` usage (unchanged, already correct), `google_auth_client.dart`'s own iOS-only guard
```dart
if (kIsWeb) return; // or the equivalent early return with a comment explaining why
if (Platform.isIOS) { ... }
// Android/desktop: explicit no-op comment, never a silent fallthrough.
```

### Additive Hive fields — nullable-no-default vs. collection-needs-default
**Source:** `lib/data/models/app_settings.dart:53-67`, `35-03-SUMMARY.md`'s documented crash
**Apply to:** all four new `AppSettings` fields (Pattern Assignments section above has the exact
field-by-field reasoning)

### CalendarSource error collapsing — with Pitfall 3's exception
**Source:** `lib/data/calendar/ics_calendar_source.dart`'s single `IcsSourceException`, contrasted
with RESEARCH.md's Pitfall 3 (Google needs a **three-way** split, not ICS's one-way collapse)
**Apply to:** `google_calendar_source.dart`, `google_auth_client.dart`,
`lib/services/calendar_sync_service.dart` if it needs a new `CalendarSyncResult` state for
"reconnect needed" distinct from `failed`

## Visible Degradation (CALAUTH-03)

**Existing "stale/needs attention" pattern:** `calendar_settings_screen.dart`'s `_footer` (lines
166-218) renders `settings.lastCalendarSyncAt` as a relative-time status line ("Synced Xm ago"), and
`settings_screen.dart:39-41` renders a shorter version of the same thing on the main Settings screen.
**Neither currently has any concept of "stale because expired," only "never synced" vs. "synced at
time T."** There is no existing red/warning-colored state anywhere in this flow — `_deniedCard`
(lines 378-439) deliberately uses `theme.colorScheme.surface`, **not** the error role, with a comment
explicitly stating "a denied permission is a normal state, not a fault (CAL-04)."

**Can an expired-token state reuse `_deniedCard`, or does it need its own treatment?** Structurally,
yes — `_deniedCard`'s shape (icon, headline, explanatory body, a single action button, everything-else-
still-works reassurance) is exactly CALAUTH-03's required shape ("one-tap reconnect, never silently
stale"). Copy its **structure** verbatim. Do **not** reuse its neutral-surface color styling
unmodified without a decision: CALAUTH-03 is arguably a *more* urgent state than "you haven't turned
this on yet" (a `_deniedCard` scenario) since it means data the user is relying on is silently aging —
this is a genuine open call for the planner/owner, not a settled pattern. Flag it rather than silently
picking a color role.

**No analog exists for a persisted "needs reconnect" boolean driving UI state** — `googleReconnectNeeded`
(the new `AppSettings` field) is the first field in this codebase whose sole purpose is gating a
degraded-state UI branch. Build it following `_deniedCard`'s existing render shape but treat the
trigger condition itself (reading `settings.googleReconnectNeeded`) as new wiring, not a copy of
existing wiring.

## Tests

| Test need | Closest existing file | What to copy |
|---|---|---|
| `CalendarSource` impl with injected seam (auth + API) | `test/data/calendar/ics_calendar_source_test.dart` | Fixture-file-driven, no-network harness via the `IcsFetcher`-shaped seam (`_fixture()` helper, lines 11-12) |
| Pure mapping functions (Event → CalendarEvent) | `test/data/calendar/device_calendar_source_mapping_test.dart` | Testing the **top-level mapping functions directly**, not through the adapter class — the same split `device_calendar_source.dart` itself uses (pure functions above the class) |
| Hive migration/round-trip | `test/data/migration_schema8_test.dart` | Two-part structure: (1) a schema-constant test asserting `currentSchemaVersion` and the WR-06 invariant, (2) a Hive open/put/close/reopen/get round-trip proving old records read back with safe defaults and new records persist correctly. **Note the filename mismatch** (Phase 35 extended this file's *content* to assert `11` rather than creating `migration_schema11_test.dart`) — the planner should decide explicitly whether Phase 36 follows the same "extend in place" precedent or starts a fresh `migration_schema12_test.dart`; either is defensible, but pick one and say why, since the existing file's name is already inconsistent with its content. |
| Settings-screen widget test | `test/screens/settings/calendar_settings_screen_test.dart` | The `_FakeCalendarSource` throwaway-double pattern (lines 44-78, implements the full `CalendarSource` interface with configurable permission/calendars/events and an optional `Completer`-based gate for observing in-flight states), `debugDefaultTargetPlatformOverride` to force the iOS branch in a host test environment, and the file's own explicit two-trap checklist comment (lines 12-19) |

**CLAUDE.md's two documented traps, applied here:**
1. **`find.byType` vs. subclasses** — relevant if the Google CTA/reconnect card reuses `_deniedCard`'s
   internal widget tree (e.g. asserting on an `Icon`/`Card` role) rather than `_ctaCard`'s from-scratch
   tree; any assertion distinguishing "the reconnect card is showing" from "some other card is showing"
   must use `find.byWidgetPredicate`, not `find.byType`, if the two cards share a widget type (both use
   `Card`/`Icon` — verified, `_deniedCard` lines 385-421 and no `_ctaCard` `Card` wrapper — so they may
   actually differ enough that `byType` is safe; **verify this explicitly at test-writing time, don't
   assume**).
2. **Tight-vs-loose constraint harnesses** — less directly applicable here (no height-collapse-prone
   layout in this screen's new widgets, unlike Phase 33's `TimelineRowTile`), but the general discipline
   — pump through the real screen (`CalendarSettingsScreen`), not a constrained stand-in — still applies
   per the existing test file's own harness (it already does this, lines ~80+, not excerpted above for
   length).

## No Analog Found / Partial Match Only

| File/Concern | Role | Data Flow | Reason |
|---|---|---|---|
| PKCE URL construction + `ASWebAuthenticationSession` round trip | new logic inside `google_auth_client.dart` | event-driven | First "leave the app, await an external consent UI, come back with a code" flow in this codebase. `notification_service.dart`'s permission-request shape is the closest partial match (platform-guard idiom only, not the round-trip shape itself) |
| `invalid_grant` / CALAUTH-03 detection | new logic inside `google_auth_client.dart` | request-response, error-branching | No prior 3-way failure classification exists in this codebase (`IcsSourceException` is deliberately 1-way) — build from RESEARCH.md's own code example, not from a Canopy precedent |
| `CFBundleURLTypes` key internals | `ios/Runner/Info.plist` | config | First inbound URL-scheme registration in this repo — file *conventions* have a precedent (Phase 35's commented `NSCalendars*` keys), the key's *own* shape does not |
| Persisted "needs reconnect" boolean gating a distinct UI state | `AppSettings.googleReconnectNeeded` + its settings-screen consumer | event-driven UI state | First field of this kind in the app — see "Visible Degradation" section above |

## Not Verifiable On This Machine

danserver has **no Xcode and no iOS simulator/device** (confirmed by the working environment; this
matches RESEARCH.md's own "A real browser session ... for UAT ... Not available on danserver" note,
now doubly true since the flow moved from browser-testable to iOS-native-only). Concretely, the
following cannot be exercised here and must be structured as owner-driven checkpoints rather than
agent-verifiable tasks:

- Whether `ASWebAuthenticationSession` + the registered `CFBundleURLTypes` scheme actually completes a
  round trip against Google's real consent screen (the phase's own "first task" verification, revised
  per the CRITICAL section above).
- Whether the iOS OAuth client Google issues actually returns a refresh token with no `client_secret`,
  as decision 4 asserts Google's own docs promise for installed/iOS apps — this needs the owner's real
  Google Cloud project and a real device/simulator.
- The actual `ASWebAuthenticationSession` cancel-UX (what `flutter_web_auth_2` returns when the user
  dismisses the sheet) — needs a real iOS run.
- Building/running `flutter build ios` or any iOS target at all — no Xcode on this machine.

Everything else — PKCE math, the Hive migration, the `googleapis`-typed mapping functions (given
fixture JSON), the settings-screen widget tests (driven via `debugDefaultTargetPlatformOverride`, no
real iOS needed), and the factory routing logic — **is** verifiable here via `flutter test` /
`flutter analyze`, matching the existing precedent every other `CalendarSource` implementation's test
suite already establishes.

## Metadata

**Analog search scope:** `lib/data/calendar/`, `lib/data/models/`, `lib/data/database/`,
`lib/services/`, `lib/screens/settings/`, `lib/providers/`, `ios/Runner/`, `test/data/calendar/`,
`test/data/`, `test/screens/settings/`
**Files scanned:** 13 read directly this session (calendar_source.dart, device_calendar_source.dart,
ics_calendar_source.dart, null_calendar_source.dart, calendar_source_factory.dart, app_settings.dart,
migrations.dart, notification_service.dart, calendar_settings_screen.dart, Info.plist,
ics_calendar_source_test.dart, calendar_settings_screen_test.dart, migration_schema8_test.dart) plus
targeted greps across `test/`, `ios/`, `android/`, and `lib/`
**Pattern extraction date:** 2026-09-23
