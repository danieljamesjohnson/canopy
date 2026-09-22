# Phase 36: Connect Google Calendar Without Hunting For a URL - Research

**Researched:** 2026-09-22
**Domain:** OAuth 2.0 (Authorization Code + PKCE) against Google Calendar API v3, from a Flutter web client
**Confidence:** MEDIUM — no Context7/premium doc provider was available this session (config reported
`exa_search`/`brave_search`/`firecrawl` all `false`); every finding below is either read directly from
this repo's own source (`[VERIFIED: <path>:<lines>]`), fetched from Google's own developer docs via
`WebFetch` (`[CITED: developers.google.com/...]`), or corroborated by multiple independent third-party
reports (`[CITED: <source>]`, explicitly flagged as third-party). Nothing here was exercised against a
live Google Cloud project — none exists yet (`.google-client-id` does not exist on disk, confirmed this
session). Treat every claim about actual token-endpoint *behavior* (as opposed to documented behavior)
as needing a cheap, early, real confirmation step — see "The PKCE / client_secret finding" below, which
is this research's most important result and directly bears on decision 1's shippability as currently
scaffolded.

## Summary

Two findings matter more than anything else in this document, and both are "say so now" findings per
the phase's own instructions.

**Finding A (changes the recommended package/approach, does not change the scope decisions):**
`google_sign_in` — the obvious, highest-quality-looking candidate (flutter.dev publisher, 160/160 pub
points, ~1.9M downloads/30d) — **cannot deliver the token shape CALAUTH-03 needs on Flutter web.**
Google's own docs state its web implementation runs entirely on Google Identity Services' "token model":
access tokens expire in ~3600 seconds and **no refresh token is ever returned to the client** — the
user must be re-prompted, via a live button click, roughly hourly, not weekly
`[CITED: developers.google.com/identity/oauth2/web/guides/use-token-model; pub.dev/packages/google_sign_in]`.
That is a materially worse experience than the 7-day expiry the owner explicitly accepted, and it is an
architectural property of GIS's web token model, not a bug — no package configuration fixes it. This
research recommends `googleapis_auth` + `googleapis` + `flutter_web_auth_2` instead (detail below);
`google_sign_in` should not be used for this phase's Google Calendar token.

**Finding B (a real, unresolved risk to decision 1's exact shape — must be tested before the phase
builds on top of it):** Google's OAuth server behavior for the **"Web application" client type**
(exactly the type `36-GOOGLE-CLOUD-SETUP.md` had the owner create) has been repeatedly reported —
independently, by multiple developers, including on Google's own developer forum — to **reject the
authorization-code token exchange with `400 invalid_request: client_secret is missing` even when PKCE
is used correctly**, contradicting the "no secret" premise of decision 1
`[CITED: discuss.google.dev/t/authorization-code-flow-without-client-secret/168113;
github.com/manfredsteyer/angular-oauth2-oidc/issues/812 — both third-party reports, not an official
Google statement that this is by design]`. Google's own client-type taxonomy only documents secret-free
PKCE + guaranteed refresh tokens for **"Desktop app" (installed application)** clients, which use
loopback (`http://127.0.0.1:PORT`) or a (now-discouraged) custom URI scheme redirect — **not** an
arbitrary HTTPS web origin `[CITED: developers.google.com/identity/protocols/oauth2/native-app]`. The
redirect URI the owner already registered (`https://danserver.tailc2efd2.ts.net:8446/oauth-callback.html`,
a Web-application-type client) may therefore hit this wall. **This must be the first thing the plan's
first task proves or disproves** — it is a ~15-minute manual check (build the auth URL by hand, exchange
the code with curl, read the response) and it is far cheaper to find out now than after building the
rest of the phase on top of an assumption that turns out to be wrong. If it fails, the two live options
are: (a) ship a client_secret anyway, injected the same way as the client ID (gitignored file,
build-time `--dart-define`, never committed) — satisfies CALAUTH-04's literal text ("no client secret
exists in the repository") but weakens the "nothing to leak" rationale in decision 1's own reasoning,
since the secret would still ship inside the public web bundle; or (b) re-register the Google Cloud
client as "Desktop app" type and restrict this phase to native desktop builds only, which contradicts
the web-first shape everything else in this phase (redirect URIs, UAT-on-web, the owner's own framing)
already assumes. Recommendation: try (a) first if Finding B is confirmed, since it is the smaller
deviation from what's already built.

**The good news, verified against Google's own API reference:** the ⭐ question — does the Google
Calendar API close `WINDOWS.md` entry 1 — is **yes, for moved occurrences**, with high confidence.
`events.list(singleEvents=true)` resolves each instance's `start`/`end` to its actual (possibly
rescheduled) time — the `originalStartTime` field exists specifically to preserve where the occurrence
*would* have been, which only makes sense if `start` already reflects where it *actually is*
`[CITED: developers.google.com/workspace/calendar/api/v3/reference/events]`. Cancelled single
occurrences require one deliberate choice this research settles: call `events.list` with
`showDeleted=true` (not the default `false`) so cancelled instances come back as minimal
`status:"cancelled"` stubs with `id`/`recurringEventId`/`originalStartTime` populated — mapping cleanly
onto this codebase's existing `SkipReason.cancelled` path — rather than being silently omitted, which is
what happens at the default `showDeleted=false` `[CITED: developers.google.com/workspace/calendar/api/v3/reference/events/list]`.
This is a genuine capability the ICS path structurally cannot match (`WINDOWS.md` id 1, confirmed by
reading `ics_calendar_source.dart` directly this session).

**Primary recommendation:** Build `GoogleCalendarSource` as a `kIsWeb`-only fourth `CalendarSource`
using `googleapis_auth` (PKCE code exchange + refresh, typed `ServerRequestFailedException` for
CALAUTH-03's error-shape detection) and `googleapis`'s typed Calendar v3 client (avoids hand-rolled JSON
parsing of `recurringEventId`/`originalStartTime`/`status`), with `flutter_web_auth_2` bridging the
popup redirect back to the running app via the already-registered `oauth-callback.html`. Persist the
token as four new nullable `AppSettings` fields (schema v11 → v12, following the exact additive-field
pattern already proven safe in this codebase). Before writing any of that: spend 15 minutes confirming
Finding B against the owner's actual Google Cloud project, because it determines whether decision 1
ships as designed or needs a documented, owner-visible amendment.

## User Constraints

<user_constraints>
### Locked Decisions (from 36-CONTEXT.md — do not re-litigate)

1. **Authorization Code + PKCE, public client, NO client secret.** Implicit flow is deprecated and
   insecure for browser apps. This repo is public as a work sample — a phase requiring a committed
   secret would be unshippable. The client ID is injected at build time from the gitignored
   `.google-client-id`.
2. **Read-only scope** (`calendar.readonly` or `calendar.events.readonly` — research picks which). This
   makes CAL-03 enforced by Google, not by our code discipline.
3. **A fourth `CalendarSource` implementation, not a rewrite.** If this phase finds itself changing the
   interface, that is a signal something is wrong.
4. **HTTPS redirect URI — the tailnet origin** `https://danserver.tailc2efd2.ts.net:8446`, already
   fronted by `tailscale serve`. `http://danserver:8161` is disqualified (Google requires HTTPS;
   localhost is the only exemption). UAT serving moves to the TLS origin for this phase.
   `http://localhost:8161` is registered as the documented fallback.
5. **Google only. Apple is unaffected and unaddressed.** No equivalent public OAuth calendar API exists
   for Apple. Do not attempt CalDAV with app-specific passwords.

### The 7-day expiry — RULED and ACCEPTED, not a discovery

Google expires refresh tokens after 7 days for apps in Testing publishing status. The owner was shown
this explicitly and chose to build it anyway. Do not treat the expiry as a blocker, and do not quietly
pursue Google verification. What the phase must do is make it degrade visibly (CALAUTH-03). The declined
fallback (cron `tools/fetch-my-calendar.sh` hourly) remains available if verification proves unworkable.

### Claude's Discretion

Everything not fixed above. Discuss was skipped per `workflow.skip_discuss`. In particular: which
package(s), factory fallback order, exact token storage shape, and how CALAUTH-03's degradation is
implemented are all open to this research's recommendation.

### Deferred Ideas (OUT OF SCOPE)

- Google verification / publishing the consent screen — explicitly not now.
- Apple Calendar OAuth / CalDAV — no public API; ruled out in the ROADMAP.
- Writing to the user's calendar — permanently out of scope, CAL-03.
- Cron'ing `fetch-my-calendar.sh` — the declined cheaper alternative; retained as a fallback.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CALAUTH-01 | Connecting Google Calendar is a button, not a manual URL hunt | Standard Stack (PKCE flow via `googleapis_auth` + `flutter_web_auth_2`), Architecture Patterns Pattern 1 |
| CALAUTH-02 | Canopy holds a read-only Google token and cannot write, enforced by scope | Scope verification (`calendar.readonly` — see "Scope choice, verified" below); `CalendarSource` interface has no write verb (`[VERIFIED: lib/data/calendar/calendar_source.dart:16-39]`) |
| CALAUTH-03 | An expired or revoked token degrades visibly with a one-tap reconnect, never a silently stale calendar | "Token lifecycle on the wire" section — exact `invalid_grant` shape, distinguishing signal, and `ServerRequestFailedException` fields |
| CALAUTH-04 | No client secret exists in the repository | Build-time injection section; Finding B above (the one place this requirement is genuinely at risk, not from carelessness but from a platform constraint) |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| OAuth consent UI (popup, Google's own hosted page) | Browser / Client | — | Google hosts its own consent screen; the app only opens and waits for it |
| PKCE code_verifier/challenge generation | Browser / Client (Dart running in the browser) | — | Must be generated client-side per request; never sent to any Canopy-controlled server (there is none) |
| Authorization code → token exchange | Browser / Client | — | No backend exists in this app; the exchange happens directly from the Flutter web client to `oauth2.googleapis.com`, exactly like the existing `IcsCalendarSource` talks directly to feed URLs |
| Token storage (access/refresh token, expiry) | Browser / Client (Hive, IndexedDB-backed on web) | — | Same persistence tier as every other `AppSettings` field; no server-side session exists |
| Calendar data fetch (`calendarList.list`, `events.list`) | Browser / Client | — | Direct client→Google API calls, same shape as `IcsCalendarSource`'s direct client→feed-URL calls |
| Event → `CommitmentBlock` mapping | Browser / Client (`CalendarSyncService`) | — | Reused unchanged (CONTEXT.md decision 3) — `GoogleCalendarSource` only needs to *produce* `CalendarEvent`s |
| Scheduling engine | Browser / Client (`schedule_generator.dart`) | — | Explicitly out of scope; byte-identical per CONTEXT.md |

Every capability in this phase lives in the Browser/Client tier — there is no backend anywhere in this
app, which is exactly why Google's platform-level "Web application clients need a client_secret"
behavior (Finding B) is a real problem rather than a non-issue: a genuine confidential-client backend
tier that could hold a secret safely does not exist here.

## Standard Stack

### Core

| Library | Version (verified via `pub.dev` API, 2026-09-22) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `googleapis_auth` | ^2.3.4 (published 2026-09-17) `[VERIFIED: pub.dev API — package score endpoint]` | PKCE authorization-code exchange (`obtainAccessCredentialsViaCodeExchange`, accepts a `codeVerifier` param), refresh (`refreshCredentials`/`autoRefreshingClient`), typed `AccessCredentials`, typed `ServerRequestFailedException` (`statusCode` + `responseContent`) | Published by Google itself (`publisher: google.dev`, verified), 150/160 pub points, 1.6M downloads/30d. It is the same library `googleapis` itself depends on for auth, so there is no second auth stack to keep in sync. |
| `googleapis` | ^17.0.0 (published 2026-08-24) | Typed Calendar API v3 client (`CalendarApi`, `Events.list(...)`, `CalendarList.list(...)`) — avoids hand-parsing Google's JSON schema for `recurringEventId`/`originalStartTime`/`status` | Published by `google.dev` (verified), 1.1M downloads/30d. Removes an entire class of "we mis-typed a field name" risk that a hand-rolled `http` + `jsonDecode` approach would carry for a schema this research had to fetch three separate doc pages to fully pin down. |
| `flutter_web_auth_2` | ^5.1.0 (published 2026-08-12) | Opens the OAuth URL in a popup, captures the redirect to `oauth-callback.html`, returns the resulting callback URL to Dart — the one piece of browser plumbing genuinely worth not hand-rolling | Publisher `femtopedia.de` (verified), 487K downloads/30d, all-platform tags including `platform:web`. Its documented web setup (`web/auth.html`, `window.opener.postMessage`, `localStorage` fallback) is **exactly** the popup+postMessage+static-callback-page shape that `36-GOOGLE-CLOUD-SETUP.md`'s redirect URI already commits to — using it validates, rather than contradicts, the owner's completed setup step `[CITED: pub.dev/packages/flutter_web_auth_2; github.com/ThexXTURBOXx/flutter_web_auth_2]`. |
| `crypto` | latest (Dart-team `dart.dev` publisher) | `sha256` for the PKCE `code_challenge` (S256 method) | Already the standard, minimal way to do this in Dart; RFC 7636's S256 method needs exactly one hash call. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `http` | ^1.6.0 (already a dependency `[VERIFIED: pubspec.yaml:44]`) | Nothing new — `googleapis_auth`/`googleapis` both accept an injectable `http.Client`, which is also the seam that keeps tests off the network, mirroring `IcsFetcher`'s existing pattern | Pass a fake `http.Client` in tests, same idiom as `IcsCalendarSource`'s `IcsFetcher` typedef |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `googleapis_auth` + `googleapis` | `google_sign_in` | **Rejected — architecturally cannot deliver a refresh token on Flutter web.** See Finding A above. This is not a downgrade in package quality (it is the highest-scoring candidate on paper); it is a hard capability gap for this specific requirement. |
| `googleapis_auth` + `googleapis` | `flutter_appauth` | **Rejected for this phase — no Flutter web support at all** (confirmed via its own pub.dev page: "Platform Support: Android, iOS, and macOS. Web is not listed"). Excellent choice for a *future* native-desktop/mobile Google OAuth phase using the loopback "Desktop app" client type, but that is a different client registration and a different phase. |
| `googleapis_auth` + `googleapis` | `oauth2` (dart.dev) | Viable, general-purpose, PKCE-capable, and maintained by the Dart core team itself — a legitimate second choice. Not recommended as primary because it does not understand Google's specific `invalid_grant` error shape or provide typed Calendar API models; you would still hand-roll both of those on top of it, which `googleapis`/`googleapis_auth` already provide. |
| Hand-rolled popup + `postMessage` bridging | `flutter_web_auth_2` | Hand-rolling this is not hard (~40-60 lines of JS + Dart interop) but re-derives exactly what a 487K-download, verified-publisher package already does correctly, including the `localStorage` fallback for browsers that break `window.opener`. Not worth re-deriving per Phase 35's own "don't hand-roll a solved problem" lesson. |
| A committed client secret | PKCE-only, no secret | This is decision 1, restated — but see Finding B: this alternative may not be *available* as configured, not by choice but by Google's platform behavior for the registered client type. The plan's first task must resolve this before the rest of the phase assumes it. |

**Installation:**
```bash
flutter pub add googleapis_auth googleapis flutter_web_auth_2 crypto
```

## Package Legitimacy Audit

> The project's `gsd-tools package-legitimacy check` seam only supports `npm|pypi|crates` ecosystems —
> it has no `pub` (Dart/Flutter) mode. The table below was built by hand from the `pub.dev` public API
> (`https://pub.dev/api/packages/<name>/score`, called directly this session) plus a `WebFetch` read of
> each package's own pub.dev page for publisher/platform claims. Every download/points/publisher figure
> below is `[VERIFIED: pub.dev API]`; every "recommended for this use" judgment is this research's own,
> not the seam's.

| Package | Registry | Published | Downloads/30d | Publisher (verified?) | GitHub owner matches publisher? | Verdict | Disposition |
|---------|----------|-----------|----------------|------------------------|----------------------------------|---------|-------------|
| `googleapis_auth` | pub.dev | 2026-09-17 (v2.3.4) | 1,619,416 | `google.dev` ✓ verified | `github.com/google/googleapis.dart` — yes | OK | Approved |
| `googleapis` | pub.dev | 2026-08-24 (v17.0.0) | 1,115,123 | `google.dev` ✓ verified | `github.com/google/googleapis.dart` — yes | OK | Approved |
| `flutter_web_auth_2` | pub.dev | 2026-08-12 (v5.1.0) | 487,142 | `femtopedia.de` ✓ verified | `github.com/ThexXTURBOXx/flutter_web_auth_2` — plausible (femtopedia.de is the maintainer's own domain per pub.dev's verified-publisher badge) | OK | Approved |
| `crypto` | pub.dev | (Dart-team package, long-lived) | very high (part of Dart's standard toolkit) | `dart.dev` ✓ verified | `github.com/dart-lang/core` — yes | OK | Approved |
| `google_sign_in` | pub.dev | 2025-09-17 (v7.2.0) | 1,911,595 | `flutter.dev` ✓ verified | `github.com/flutter/packages` — yes | OK (package itself is legitimate) | **Not recommended for this use** — see Finding A. Legitimacy is not the problem; capability is. |
| `flutter_appauth` | pub.dev | 2026-08-29 (v12.1.0) | 359,615 | `dexterx.dev` ✓ verified | `github.com/MaikuB/flutter_appauth` — plausible | OK (package itself is legitimate) | **Not recommended for this use** — no web platform support, confirmed. Good fit for a future native-only phase. |

**Packages removed due to `[SLOP]` verdict:** none — every candidate considered is a real, well-adopted,
verified-publisher package. This phase's risk is not slopsquatting; it is picking a package whose
*capability* doesn't match the requirement (Finding A) or building on a Google Cloud client
*configuration* whose behavior may not match the decision it was set up to serve (Finding B).
**Packages flagged as suspicious `[SUS]`:** none.

## Architecture Patterns

### System Architecture Diagram

```
 User taps "Connect Google Calendar"
        │
        ▼
 GoogleCalendarSource generates PKCE code_verifier (in-memory, never persisted)
 + derives code_challenge (SHA256, base64url)
        │
        ▼
 flutter_web_auth_2 opens a POPUP to
   accounts.google.com/o/oauth2/v2/auth?
     client_id=...&redirect_uri=.../oauth-callback.html&
     response_type=code&scope=calendar.readonly&
     code_challenge=...&code_challenge_method=S256&
     access_type=offline&prompt=consent&state=...
        │                              (main Flutter tab stays open,
        ▼                               its Dart state — including the
 User consents on Google's OWN page     code_verifier — is never lost)
        │
        ▼
 Google redirects the POPUP to
   https://danserver.tailc2efd2.ts.net:8446/oauth-callback.html?code=...&state=...
        │
        ▼
 oauth-callback.html (plain static JS, not Flutter)
   window.opener.postMessage({url: location.href}, origin)
   window.close()
        │
        ▼
 flutter_web_auth_2 in the MAIN tab receives the callback URL
        │
        ▼
 googleapis_auth.obtainAccessCredentialsViaCodeExchange(
   clientId, code, redirectUrl, codeVerifier: ...)
        │
        ├─ success ──▶ AccessCredentials{accessToken, refreshToken, expiry}
        │                    │
        │                    ▼
        │              Persist 4 new AppSettings fields (Hive) — schema v11→v12
        │
        └─ ServerRequestFailedException(statusCode, responseContent)
                    │
                    ▼
              CALAUTH-03 degradation path (see Token Lifecycle section)

 ── Later, on every sync ──

 CalendarSyncService.sync()
        │
        ▼
 GoogleCalendarSource.listEvents() / listCalendars()
        │
        ├─ access token still valid → call Calendar API directly
        ├─ access token expired (401) → silently refresh via stored refresh_token,
        │                                retry once, no user-visible change
        └─ refresh_token itself dead (400 invalid_grant) → CalendarSyncResult
                                                             signals "reconnect needed"
                                                             (a NEW state, distinct from
                                                             the existing `failed` bool —
                                                             see Token Lifecycle section)
        │
        ▼
 googleapis.CalendarApi(authClient).events.list(
   calendarId, singleEvents: true, showDeleted: true,
   timeMin, timeMax)
        │
        ▼
 Map Event → CalendarEvent (this phase's new mapping function,
   mirrors device_calendar_source.dart's mapDeviceEvent shape)
        │
        ▼
 CalendarSyncService._mapEvent() — REUSED UNCHANGED
        │
        ▼
 CommitmentBlock (Hive) → schedule_generator.dart (UNCHANGED, byte-identical)
```

### Recommended Project Structure

```
lib/data/calendar/
├── calendar_source.dart              # unchanged interface
├── calendar_source_factory.dart      # extended: kIsWeb + google-connected branch
├── google_calendar_source.dart       # NEW — the fourth CalendarSource
├── google_auth_client.dart           # NEW — PKCE flow + token persistence, separate
│                                      #   from the CalendarSource itself so it can be
│                                      #   unit-tested independently (mirrors the split
│                                      #   between IcsCalendarSource and its IcsFetcher)
├── device_calendar_source.dart       # unchanged
├── ics_calendar_source.dart          # unchanged
└── null_calendar_source.dart         # unchanged
```

### Pattern 1: Injectable seams, mirroring `IcsFetcher`

`IcsCalendarSource` keeps itself testable with one typedef:

```dart
// Source: lib/data/calendar/ics_calendar_source.dart:13 [VERIFIED — read this session]
typedef IcsFetcher = Future<String> Function(Uri url);
```

`GoogleCalendarSource` needs the same shape at (at least) two seams, since it has two genuinely
different kinds of side effect the ICS source doesn't: interactive browser consent, and a token
refresh that can fail in a way that must be distinguishable from a network failure.

```dart
// Recommended shape (this research's own — no existing analog for the auth seam)
typedef GoogleAuthLauncher = Future<AccessCredentials> Function(
  ClientId clientId,
  List<String> scopes,
);

typedef GoogleApiClientFactory = http.Client Function(AccessCredentials);
```

A test can then fake `GoogleAuthLauncher` to return a pre-baked `AccessCredentials` (skipping the
popup entirely) and fake the underlying `http.Client` to return canned Calendar API JSON responses
(including a fixture with a moved and a cancelled recurring instance, and a fixture that reproduces the
exact `400 invalid_grant` body from the "Token Lifecycle" section below) — all without a browser, a
network call, or a real Google account. This is the direct answer to research question 7.

### Pattern 2: Token storage as additive `AppSettings` fields

```dart
// Existing shape, read this session — the pattern to extend, not replace:
// lib/data/models/app_settings.dart:53-67 [VERIFIED]
@HiveField(9, defaultValue: <String>[])
List<String> selectedCalendarIds = [];

@HiveField(10, defaultValue: <String>[])
List<String> icsUrls = [];

@HiveField(11)
DateTime? lastCalendarSyncAt;
```

Next available field index is **12** `[VERIFIED: lib/data/models/app_settings.dart:6-68 — every
existing @HiveField index (0,1,4,2,3,5,6,7,8,9,10,11) read directly, 12 is the first unused one]`.
Recommended new fields, all nullable (no `defaultValue` needed — an upgrading user simply has no Google
token, exactly like `lastCalendarSyncAt`'s own precedent):

```dart
@HiveField(12)
String? googleAccessToken;

@HiveField(13)
String? googleRefreshToken;

@HiveField(14)
DateTime? googleAccessTokenExpiresAt;

@HiveField(15)
bool googleReconnectNeeded = false;  // set true on invalid_grant; CALAUTH-03's persisted flag
```

`currentSchemaVersion` moves 11 → 12 in `lib/data/database/migrations.dart:3` `[VERIFIED — read this
session]`, with a new `_migration11to12` entry appended to the `_migrations` list (never edit existing
entries — the file's own `runMigrations` has an `assert(_migrations.length == currentSchemaVersion...)`
guard at line 124-129 that fails loudly if a version bump ships without its migration, exactly the
class of bug Phase 35 found and documented as `WINDOWS.md` entry 3 for a *different* field).

### Anti-Patterns to Avoid

- **Do not persist the PKCE `code_verifier` anywhere durable (Hive, `localStorage`).** It is single-use,
  short-lived by design (RFC 7636), and never needed again after one token exchange. Keep it in a
  plain Dart field for the lifetime of one connect attempt. Because this phase uses the popup+postMessage
  pattern (not a full-page navigation), the main Flutter tab never unloads during the flow, so an
  in-memory field survives the whole round trip without ever touching browser storage — a full-page
  redirect would require `sessionStorage` instead, which this design deliberately avoids needing.
- **Do not call `events.list` with the default `showDeleted=false`.** It silently omits cancelled
  recurring-instance exceptions, which is the exact defect class `WINDOWS.md` entry 1 already tracks for
  the ICS path — reproducing it on the Google path after specifically choosing Google to *close* that
  entry would be a real regression hiding behind a green build.
- **Do not conflate a 401 from the Calendar API itself with a 400 `invalid_grant` from the token
  endpoint.** They are different endpoints, different status codes, and require completely different
  responses (silent retry vs. visible reconnect) — see Token Lifecycle below.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Calendar API JSON → Dart models | A hand-parsed `jsonDecode` reader for `Events`/`Event`/`CalendarListEntry` | `googleapis`'s typed `CalendarApi` | The exact field set this phase depends on (`recurringEventId`, `originalStartTime`, `status`) took three separate official-doc fetches to fully pin down this session — a hand-rolled parser is where a subtly wrong field name would hide until a real recurring event exercised it in production, unnoticed by any fixture-based test that didn't happen to cover that exact shape. |
| Popup + redirect capture on Flutter web | Hand-rolled `window.open` + `postMessage` + a bespoke `oauth-callback.html` | `flutter_web_auth_2` | Already handles the `window.opener` null case (a real, filed issue against this exact package: `github.com/ThexXTURBOXx/flutter_web_auth_2/issues/44`) with a `localStorage` fallback. Re-deriving this is re-deriving a solved problem, the same lesson Phase 35 already applied to `enough_icalendar`/`rrule`. |
| PKCE code exchange + refresh + typed error surface | A hand-rolled `http.post` to `oauth2.googleapis.com/token` with manual JSON parsing of success/error bodies | `googleapis_auth`'s `obtainAccessCredentialsViaCodeExchange` / `refreshCredentials` / `ServerRequestFailedException` | Published by Google itself, tracks Google's own token-endpoint error shape (`statusCode`, `responseContent`) without this codebase needing to encode Google-specific error parsing logic by hand. |

**Key insight:** every "don't hand-roll" item above is a place where the *shape* of Google's API is
easy to get approximately right and subtly wrong — a wrong field name, a missed `showDeleted` default,
an unhandled `window.opener == null` case — and where a well-adopted, Google- or verified-publisher
package has already paid down that risk. This mirrors Phase 35's own `enough_icalendar`+`rrule` choice
almost exactly, down to the "reject the low-adoption alternative" reasoning CONTEXT.md explicitly asks
this research to apply.

## Common Pitfalls

### Pitfall 1: The "Web application" client type may not support secret-free PKCE (Finding B)

**What goes wrong:** Building the whole phase assuming decision 1 ("no client secret") works as
configured, only to discover at UAT time that the token exchange fails with `400 invalid_request:
client_secret is missing`.
**Why it happens:** Google's OAuth server appears to enforce `client_secret` for clients registered as
"Web application" type regardless of PKCE — a platform behavior, not a bug in this app's code.
Documented only by consistent third-party reports, not an unambiguous official statement, which is why
this needs an early, cheap, direct check rather than being trusted either way.
**How to avoid:** Make "confirm the token exchange succeeds with no client_secret, against the owner's
actual Google Cloud project" the literal first task of the first plan — before any Dart implementation
work. It costs one `curl` round trip once `.google-client-id` exists.
**Warning signs:** A `400` response containing the string `client_secret` anywhere in the body.

### Pitfall 2: Port 8146 already serves a DIFFERENT build with an active service worker

**What goes wrong:** Serving Phase 36's debug UAT build on the same local port the tailnet HTTPS origin
(`8446`) is already proxying to would reproduce CLAUDE.md trap #1 (stale service worker serving a
mismatched shell → blank page), except worse — it would look like Google's OAuth *specifically* is
broken, sending the investigation in the wrong direction.
**Why it happens:** `tailscale serve status`, run directly this session, shows
`https://danserver.tailc2efd2.ts.net:8446` already proxying to `http://127.0.0.1:8146`
`[VERIFIED: tailscale serve status, run this session]`, and that local port is already bound — `ps`
shows `python3 tools/serve-pwa.py 8146 --dir build/web`, started 2026-09-10, i.e. the PWA/installable-app
work from the previous commit `[VERIFIED: process table + tools/serve-pwa.py:54,101-104 — read this
session, confirms it checks for and serves `flutter_service_worker.js`, i.e. it is a release-shaped,
service-worker-registering build]`. Serving Phase 36's `--pwa-strategy=none` debug build on port 8146
would collide with that SW exactly as CLAUDE.md's trap #1 describes.
**How to avoid:** Pick a **fresh local port never used for any Canopy build before** (e.g. `8147`) for
Phase 36's debug UAT server, and repoint the tailnet mapping: `tailscale serve --bg --https=8446
http://127.0.0.1:8147`. The **public** port (`8446`) is what Google's redirect-URI registration cares
about — the local proxy target is free to move without touching the Google Cloud configuration at all.
**Warning signs:** The tailnet URL loads a stale UI, or the debug banner / unminified stack traces this
project relies on for triage are absent even though a debug build was just built and deployed.

### Pitfall 3: Conflating "offline" with "your login expired"

**What goes wrong:** CALAUTH-03 exists specifically to prevent a silently-stale calendar. Routing every
sync failure (network blip, DNS hiccup, genuine `invalid_grant`) through one generic "reconnect" banner
would produce a *different* dishonest state: nagging the user to re-auth when nothing is actually wrong
with their Google connection, which erodes trust exactly as CLAUDE.md's "assertions that cannot fail"
section warns against for a different kind of green-but-wrong test.
**Why it happens:** It is tempting to catch every exception from `GoogleCalendarSource.listEvents()`
the same way `IcsCalendarSource` catches every exception into one `IcsSourceException` →
`CalendarSyncResult.failed`. That collapsing is correct for the ICS path (there is only one kind of
failure — fetch/parse). It is wrong for Google, which has three genuinely distinct failure kinds (see
Token Lifecycle section).
**How to avoid:** Only the `ServerRequestFailedException` with `statusCode == 400` and a
`responseContent` containing `invalid_grant` sets the persisted `googleReconnectNeeded` flag and drives
the visible reconnect CTA. Everything else (timeouts, DNS, a transient 5xx from Google) degrades exactly
like the existing ICS failure path already does — `CalendarSyncResult.failed = true`, the existing
"Calendar sync failed — showing your last-known calendars" SnackBar, no reconnect nagging.
**Warning signs:** A test that asserts "any thrown exception → reconnect banner" — that test would pass
for the wrong reason (mirrors CLAUDE.md's own "assertions that cannot fail" pattern #1/#2 — the
assertion needs to discriminate on *which* exception, not just that one was thrown).

## Code Examples

### Building the authorization URL (hand-rolled — stable, well-documented Google endpoint)

```dart
// PKCE code_verifier/code_challenge — RFC 7636, S256 method.
// No package currently in this app's dependency tree generates this; it is
// ~10 lines and low-risk enough not to add a dependency for.
final verifier = base64UrlEncode(List.generate(64, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');
final challenge = base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
  'client_id': clientId.identifier,
  'redirect_uri': redirectUri,          // must exactly match a registered URI
  'response_type': 'code',
  'scope': 'https://www.googleapis.com/auth/calendar.readonly',
  'code_challenge': challenge,
  'code_challenge_method': 'S256',
  'access_type': 'offline',             // required to receive a refresh_token
  'prompt': 'consent',                  // forces refresh_token on every connect,
                                         // not just the very first one — needed
                                         // because a user reconnecting after a
                                         // 7-day expiry must get a NEW refresh
                                         // token, not silently get none.
  'state': stateNonce,                  // CSRF protection — verify on return
});
```

### The code exchange, via `googleapis_auth`

```dart
// Source: googleapis_auth's obtainAccessCredentialsViaCodeExchange signature,
// confirmed via pub.dev search this session — accepts an optional codeVerifier
// for PKCE [CITED: pub.dev/documentation/googleapis_auth (search index), 2026-09-22]
final credentials = await obtainAccessCredentialsViaCodeExchange(
  httpClient,
  ClientId(clientId, null),   // secret intentionally null — see Finding B
  code,
  codeVerifier: verifier,
);
```

### Detecting the CALAUTH-03 case

```dart
try {
  final refreshed = await refreshCredentials(clientId, credentials, httpClient);
  // ... use refreshed.accessToken
} on ServerRequestFailedException catch (e) {
  // Source: pub.dev/documentation/googleapis_auth — ServerRequestFailedException
  // exposes statusCode (int?) and responseContent (Object?) [CITED]
  final body = e.responseContent?.toString() ?? '';
  if (e.statusCode == 400 && body.contains('invalid_grant')) {
    // THIS, specifically, is CALAUTH-03's case — the 7-day (or revoked) expiry.
    await settings.setGoogleReconnectNeeded(true);
  } else {
    // Any other failure (network, 5xx, malformed response) — degrade like the
    // existing ICS path already does; do NOT set the reconnect flag.
    throw IcsSourceException.analog(...); // or an equivalent GoogleSourceException
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| OAuth 2.0 Implicit Grant for browser apps | Authorization Code + PKCE | Google deprecated implicit-grant guidance well before this phase; still documented but explicitly marked insecure `[CITED: developers.google.com/identity/protocols/oauth2/javascript-implicit-flow]` | Already reflected correctly in CONTEXT.md decision 1 — no change needed |
| Custom URI scheme redirects for installed apps | Loopback (`127.0.0.1:PORT`) redirects | Google's own native-app doc states custom schemes are discouraged "due to the risk of app impersonation" `[CITED: developers.google.com/identity/protocols/oauth2/native-app]` | Not directly relevant to this phase's web-only scope, but relevant if a future phase adds native-desktop Google OAuth — use loopback, not a custom scheme, for that phase |

**Deprecated/outdated:** Nothing this phase would have reached for is itself deprecated — the risk here
is a platform-behavior mismatch (Finding B), not stale guidance.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | Google's "Web application" client type actually enforces `client_secret` at token exchange even with correct PKCE, for the specific client the owner already created | Finding B, Pitfall 1 | If wrong (i.e. it actually works secret-free as decision 1 assumes), no harm — the plan's first-task verification step simply confirms success quickly and everything proceeds as designed. If Finding B is right and unverified, the phase could be built entirely on a broken premise. **This is the single highest-value thing to verify before deep implementation.** |
| A2 | The popup+`postMessage` pattern is the correct shape for `oauth-callback.html` (as opposed to a full-page-navigation + `sessionStorage` pattern) | Architecture Patterns, Anti-Patterns | If wrong, the code_verifier persistence strategy (in-memory only) would need to move to `sessionStorage`, and the callback page's JS would need to redirect rather than `postMessage`+close. Low risk to discover late — it fails loudly and immediately in manual testing (the popup either closes itself and updates the app, or doesn't), not silently. |
| A3 | `ServerRequestFailedException.responseContent` actually contains the raw parseable body (including the `invalid_grant` string) rather than an already-summarized message | Token Lifecycle / Code Examples | If wrong, the CALAUTH-03 detection logic in the code example needs to inspect a different field or wrap the underlying `http.Response` directly instead of relying on the exception. This is a two-line fix once the actual package source is read at implementation time — flagged rather than blocking because pub.dev's own class doc page (fetched this session) describes exactly this field, but was not exercised against a live error. |
| A4 | `googleapis`'s generated `Event` model actually exposes `recurringEventId`, `originalStartTime`, and `status` with the field names/types this research assumes | Standard Stack, Don't Hand-Roll | If wrong (unlikely — `googleapis` is a mechanical 1:1 generation from Google's own API discovery document, and this research confirmed the underlying REST field names directly against Google's own reference docs), the mapping function in `GoogleCalendarSource` needs field-name adjustments only, not a design change. |
| A5 | The owner's registered redirect URIs (`.../oauth-callback.html` on both the tailnet HTTPS origin and `localhost:8161`) will be accepted as-is by Google if Finding B is confirmed and option (a) — ship a client_secret via the same gitignored-file mechanism as the client ID — is chosen | Finding B, Summary | If Google's enforcement is stricter than "just add a secret" (e.g. it also disallows PKCE `code_challenge` alongside a Web-application-type token exchange for some other reason not surfaced in this research), a second round of investigation would be needed. Low likelihood — the third-party reports found describe exactly the "add the secret and it works" resolution, not a deeper block. |

## Open Questions

1. **Does Google's "Web application" client type genuinely require `client_secret`, for THIS owner's
   specific Google Cloud project?**
   - What we know: multiple independent third-party reports (a Google developer forum thread, a GitHub
     issue against an unrelated OAuth library) describe exactly this failure for Web-application-type
     clients using PKCE with no secret.
   - What's unclear: whether this is universal Google platform behavior or has ever varied by account
     type, project age, or a Google-side rollout — no primary Google documentation states it as a firm
     rule for this specific client type (the general web-server-flow doc marks `client_secret`
     ambiguously as "Optional").
   - Recommendation: the plan's first task resolves this directly against the owner's project, cheaply,
     before any further implementation work depends on the answer.

2. **Does the popup approach work reliably inside the sandboxed environment this project already
   documents fighting (CLAUDE.md's headless-Chromium GPU-loss trap, service-worker traps)?**
   - What we know: manual/interactive UAT (a real browser, a real human clicking "Connect") is how this
     project has verified every prior UI-facing phase; `go-look-at`/headless automation is explicitly
     documented as unreliable for this kind of interactive, stateful flow.
   - What's unclear: nothing structurally — this is a "use the existing UAT discipline, don't invent a
     new one" note, not a real unknown.
   - Recommendation: plan a human-driven UAT checkpoint for the connect flow itself (popup appears,
     consent screen shows the correct read-only scope description, popup closes, app updates) —
     automated tests should cover everything downstream of a successful/failed token exchange, not the
     popup interaction itself.

3. **Should `GoogleCalendarSource` ever be offered on native desktop builds (Windows/Linux/macOS),
   given Flutter's desktop targets could in principle run a real loopback listener?**
   - What we know: this would require a *separate* Google Cloud client registration ("Desktop app"
     type), which does not exist yet — only the "Web application" client the owner already set up.
   - What's unclear: whether the owner wants this as a near-term follow-up or considers ICS-on-desktop
     sufficient indefinitely.
   - Recommendation: explicitly out of scope for this phase (see Factory Routing section) — flag as a
     natural, but separate, future phase rather than silently gold-plating this one.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|--------------|-----------|---------|----------|
| Flutter SDK | Building the debug web bundle | ✓ | 3.44.1 (stable), Dart 3.12.1 `[VERIFIED: flutter --version, run this session via /home/dan/development/flutter/bin]` | — |
| `.google-client-id` (gitignored, owner-provided) | Any actual OAuth flow — auth, token exchange, Calendar API calls | ✗ — does not exist on disk yet `[VERIFIED: ls check this session]` | — | None needed at the code-writing stage: CONTEXT.md explicitly requires plans "must not gate buildable work behind it." All non-network-dependent code (PKCE math, Hive migration, mapping functions, UI scaffolding) can be built and unit-tested now; only the live end-to-end flow needs the real ID. |
| `tailscale serve` HTTPS origin (`:8446`) | The registered redirect URI | ✓ — already proxying to `127.0.0.1:8146` `[VERIFIED: tailscale serve status, run this session]` | — | **Local proxy target must move to a fresh port before this phase's debug build is served** — see Pitfall 2. The public port itself needs no change. |
| Port 8146 (currently bound) | — | ✗ for this phase's use — already serves a different, service-worker-registering PWA build `[VERIFIED: ps + tools/serve-pwa.py:54,101-104, this session]` | — | Use a new port (e.g. 8147) for this phase's UAT server. |
| Google Calendar API enabled on the owner's Cloud project | Every API call | Unconfirmed — depends on the owner completing `36-GOOGLE-CLOUD-SETUP.md` step 2 | — | The setup doc's own troubleshooting table already covers this (403 → "Calendar API not enabled") — no new fallback needed here. |
| A real browser session (owner's device) for UAT | Verifying the actual consent screen, popup behavior, and reconnect flow | Not available on danserver (headless, no owner Google session) | — | Same posture as every other phase requiring device/browser UAT — a human checkpoint task, not an automatable one. |

**Missing dependencies with no fallback:**
- A real Google Cloud client ID + the owner's own Google account for end-to-end verification — this is
  the owner's parallel-track work per `36-GOOGLE-CLOUD-SETUP.md`, already anticipated by CONTEXT.md.

**Missing dependencies with fallback:**
- None beyond the port reassignment noted above, which has a clear, low-cost fallback.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with the Flutter SDK, already used project-wide — no new framework) |
| Config file | none — standard `flutter test` discovery of `test/**/*_test.dart` |
| Quick run command | `flutter test test/data/calendar/google_calendar_source_test.dart test/data/calendar/google_auth_client_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| CALAUTH-01 | Tapping "Connect Google Calendar" launches the PKCE auth URL with correct params (client_id, PKCE challenge, scope, redirect_uri) | unit | `flutter test test/data/calendar/google_auth_client_test.dart` | ❌ Wave 0 |
| CALAUTH-02 | The requested scope is exactly `calendar.readonly`; no write verb exists anywhere in `GoogleCalendarSource` | unit + static (interface conformance, same proof `calendar_source.dart`'s own doc comment already relies on: `flutter analyze` confirming only read verbs) | `flutter test test/data/calendar/google_calendar_source_test.dart` | ❌ Wave 0 |
| CALAUTH-03 | A `400 invalid_grant` refresh failure sets the reconnect flag and surfaces the CTA; a network failure does NOT | unit, using injected fake `http.Client` returning a fixture matching the exact `invalid_grant` JSON body | `flutter test test/data/calendar/google_calendar_source_test.dart` | ❌ Wave 0 (fixture file also needed: `test/fixtures/calendar/google_invalid_grant.json`) |
| CALAUTH-04 | The build fails clearly when `.google-client-id`/the dart-define is absent — NOT silently producing a broken button | integration/manual — a build-time check, not a `flutter test` assertion (see Build-Time Injection section) | a new `tools/`-level check, exercised manually and via the build wrapper script itself | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** the quick-run command above.
- **Per wave merge:** `flutter test` (full suite) — this project's precedent (Phases 27-32) makes clear
  a green full suite is necessary but never sufficient on its own for a UI-facing phase.
- **Phase gate:** full suite green, PLUS a human-driven UAT checkpoint for the actual popup/consent/
  reconnect flow — no assertion in `flutter test` can observe a real Google consent screen or a real
  browser popup, the same category of gap CLAUDE.md's headless-Chromium trap already documents for
  screenshots.

### Wave 0 Gaps

- [ ] `test/data/calendar/google_auth_client_test.dart` — PKCE URL construction, code exchange (success
      and `invalid_grant` failure), refresh (success and failure)
- [ ] `test/data/calendar/google_calendar_source_test.dart` — `listCalendars`/`listEvents` mapping,
      including a fixture with a moved recurring instance and a `showDeleted=true` cancelled instance
- [ ] `test/fixtures/calendar/google_events_list_recurring_moved.json` — a realistic `events.list`
      response shape, built from Google's documented field set (`recurringEventId`, `originalStartTime`,
      `status`), not a live capture (none available this session)
- [ ] `test/fixtures/calendar/google_invalid_grant.json` — `{"error": "invalid_grant", "error_description":
      "Token has been expired or revoked."}`, matching the documented/reported real shape
- [ ] `test/data/database/migrations_test.dart` (existing file, presumably — verify) needs a new case for
      the v11→v12 migration, following the exact precedent of the v9→v10 and v10→v11 entries already in
      `migrations.dart`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | Yes | OAuth 2.0 Authorization Code + PKCE (this phase's whole subject) — delegated entirely to Google; Canopy never sees or stores a password |
| V3 Session Management | Yes | Token stored in Hive (this app's existing persistence tier, IndexedDB-backed on web); no cookie/session-fixation surface exists since there is no Canopy backend |
| V4 Access Control | Yes | Enforced by Google's scope grant (`calendar.readonly`), not by Canopy's own code discipline — this is explicitly the point of decision 2 (CAL-03 "enforced by Google itself") |
| V5 Input Validation | Yes | The `state` param on the auth request must be verified on return (CSRF/session-fixation protection, standard OAuth practice) — not called out elsewhere in this research, adding it here |
| V6 Cryptography | Yes | PKCE `code_challenge` (SHA-256, `crypto` package — never hand-rolled hashing) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|------------------------|
| CSRF / authorization-code injection into the callback | Spoofing / Tampering | The `state` param, generated fresh per attempt and verified on the callback, exactly as RFC 6749 recommends; PKCE itself also protects against a stolen authorization code being replayed by a different client, per its own design purpose |
| Client secret exposure (if Finding B forces option (a)) | Information Disclosure | Same mitigation already used for the client ID: gitignored file, `--dart-define` injection, never committed. Explicitly document (in code comments, mirroring `fetch-my-calendar.sh`'s own pattern of explaining WHY) that this is a known, accepted deviation from "no secret exists to leak," not an oversight |
| Token exfiltration via a compromised browser extension / XSS reading Hive-on-web (IndexedDB) | Information Disclosure | No new mitigation this phase can add beyond what already exists — this is the same trust boundary every other piece of app data already lives inside. Worth stating explicitly rather than silently, since it is a slightly different risk profile than a native app's OS-level keychain |
| A malicious page registering itself to receive the `postMessage` from the OAuth popup | Spoofing | `flutter_web_auth_2`'s documented pattern verifies the message origin (`window.opener.postMessage(..., window.location.origin)`) rather than using a wildcard `*` target — confirm this at implementation time by reading the actual generated `web/auth.html` template the package provides |

## Sources

### Primary (CITED — official documentation, fetched directly this session)

- `developers.google.com/workspace/calendar/api/v3/reference/events/list` — `singleEvents`/`showDeleted`
  parameter semantics
- `developers.google.com/workspace/calendar/api/v3/reference/events` — `status`, `recurringEventId`,
  `originalStartTime` field definitions
- `developers.google.com/identity/protocols/oauth2/native-app` — Desktop app client type, PKCE, loopback
  redirect, "refresh tokens are always returned for installed applications"
- `developers.google.com/identity/protocols/oauth2/web-server` — web-server flow token exchange
  parameters, `access_type=offline` for refresh tokens
- `developers.google.com/identity/oauth2/web/guides/use-token-model` — GIS token model: no refresh
  token, ~3600s access token lifetime
- `developers.google.com/identity/oauth2/web/guides/use-code-model` — GIS authorization-code model
  requires a backend to exchange the code
- `developers.google.com/identity/protocols/oauth2/javascript-implicit-flow` — implicit flow deprecated,
  PKCE recommended instead
- `pub.dev` package score API (`/api/packages/<name>/score`) — downloads, publisher, pub points for
  every package in the Standard Stack / Alternatives tables (`[VERIFIED: tool call this session]`)

### Secondary (CITED — third-party, consistent across independent sources)

- `discuss.google.dev/t/authorization-code-flow-without-client-secret/168113` — Google's own developer
  forum, multiple developers reporting the Web-application-type `client_secret` requirement
- `github.com/manfredsteyer/angular-oauth2-oidc/issues/812` — independent corroboration of the same
  `400 client_secret is missing` failure
- `nango.dev/blog/google-oauth-invalid-grant-token-has-been-expired-or-revoked` and consistent
  corroborating results (CData KB, Google AdWords API group threads) — the `400 invalid_grant` /
  `"Token has been expired or revoked."` error shape for expired/revoked refresh tokens
- `pub.dev/packages/flutter_web_auth_2` and `github.com/ThexXTURBOXx/flutter_web_auth_2` — web setup
  instructions (`web/auth.html`, `postMessage`, `localStorage` fallback)
- Search-aggregated description of `googleapis_auth`'s `obtainAccessCredentialsViaCodeExchange` (`codeVerifier`
  param), `ClientId` (`secret` nullable), and `ServerRequestFailedException` (`statusCode`,
  `responseContent`) fields — pub.dev documentation pages, several of which 404'd directly and were
  reconstructed via search-index snippets; **flag for implementation-time confirmation by reading the
  actual installed package source**, per Assumption A3

### Tertiary (repo-internal, read directly this session — `[VERIFIED]`)

- `lib/data/calendar/calendar_source.dart` — interface, all four verbs
- `lib/data/calendar/calendar_source_factory.dart` — current platform routing
- `lib/data/calendar/ics_calendar_source.dart` — `IcsFetcher` seam pattern, recurrence expansion,
  timezone handling
- `lib/data/calendar/device_calendar_source.dart` — mapping-function/adapter split pattern
- `lib/data/calendar/calendar_event.dart` — `CalendarEventStatus`, `CalendarEvent`, `CalendarInfo` shapes
- `lib/services/calendar_sync_service.dart` — `SkipReason`, mapping rules, `CalendarSyncResult`
- `lib/screens/settings/calendar_settings_screen.dart` — settings UI branch structure, CORS note
  (Google ICS specifically fails via CORS on web — direct evidence for why Google OAuth should replace,
  not merely supplement, the web ICS path)
- `lib/data/models/app_settings.dart` — existing `@HiveField` indices, additive-field pattern
- `lib/data/database/migrations.dart` — `currentSchemaVersion`, migration list invariant/assert
- `.planning/WINDOWS.md` — entry 1 (EXDATE/RDATE/RECURRENCE-ID gap), verbatim
- `tools/fetch-my-calendar.sh` — documented CORS failure for Google's own ICS URL from a browser origin
- `tools/serve-pwa.py` — service-worker-serving behavior confirming Pitfall 2
- `tailscale serve status` (live command output, this session) — port mapping confirming Pitfall 2
- `pubspec.yaml` — existing dependency versions, Dart SDK constraint (`^3.10.3`)

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — every package's registry facts are `[VERIFIED: pub.dev API]`; the
  auth-library API surface (`googleapis_auth`) is corroborated across multiple search-index snippets and
  one direct doc fetch, but two direct doc-page fetches 404'd, so exact method signatures should be
  confirmed against the installed package source at implementation time (Assumption A3).
- Architecture: MEDIUM-HIGH — the popup+`postMessage` pattern is independently corroborated by
  `flutter_web_auth_2`'s own documented setup AND by general SPA-OAuth pattern literature; the
  Hive/`AppSettings` extension pattern is `[VERIFIED]` directly against this repo's own precedent.
- Pitfalls: HIGH for Pitfall 2 (directly observed this session via live commands against this machine);
  MEDIUM for Pitfall 1/Finding B (consistent third-party reports, no unambiguous first-party Google
  statement); HIGH for Pitfall 3 (derived directly from this repo's own existing `CalendarSyncResult`
  shape and CLAUDE.md's own documented failure pattern).

**Research date:** 2026-09-22
**Valid until:** ~14 days for the Google-API-specific claims (stable, slow-moving public API); the
Finding B client-type/secret behavior should be treated as needing reconfirmation the moment
implementation actually begins, regardless of elapsed time, since it was never exercised live this
session.
