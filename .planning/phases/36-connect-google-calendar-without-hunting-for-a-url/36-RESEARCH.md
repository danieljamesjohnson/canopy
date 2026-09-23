# Phase 36: Connect Google Calendar Without Hunting For a URL - Research

**Researched:** 2026-09-22 (transport sections revised 2026-09-23 — see banner below)
**Domain:** OAuth 2.0 (Authorization Code + PKCE) against Google Calendar API v3, **native iOS client**
**Confidence:** MEDIUM — no Context7/premium doc provider was available this session (config reported
`exa_search`/`brave_search`/`firecrawl` all `false`); every finding below is either read directly from
this repo's own source (`[VERIFIED: <path>:<lines>]`), fetched from Google's own developer docs via
`WebFetch` (`[CITED: developers.google.com/...]`), or corroborated by multiple independent third-party
reports (`[CITED: <source>]`, explicitly flagged as third-party). Nothing here was exercised against a
live Google Cloud project's token endpoint (no browser session, no device with the app installed).
Treat every claim about actual token-endpoint *behavior* as needing a cheap, early, real confirmation
step during implementation.

> ## ⚠ REVISION BANNER — 2026-09-23 — read this before anything else in the file
>
> **Decision 4 was reversed by the owner AFTER this research was first written, on the strength of
> this research's own Finding B.** The original premise was a **browser/web** PKCE flow: popup +
> `postMessage`, an HTTPS redirect on the tailnet origin, a static `oauth-callback.html`. **That
> premise is dead.** Google's "Web application" client type is a *confidential* client and will not
> complete a secret-free exchange — confirmed independently by the owner, matching this research's own
> Finding B — and a browser page cannot hold a secret regardless (it ships in the public bundle). The
> owner ruled: **build it native iOS**, using Google's own native-app guarantee that `client_secret`
> "is not applicable" to iOS clients and refresh tokens "are always returned for installed
> applications."
>
> **Already done, do not re-litigate:** an iOS OAuth client is registered in Google Cloud Console,
> keyed on bundle ID (no redirect URI, no JS origins); the bundle ID was renamed repo-wide from the
> `com.example.canopy` placeholder to **`com.danjjohnson.canopy`** `[VERIFIED:
> ios/Runner.xcodeproj/project.pbxproj:480,497,515,531,663 — read this session]`; the real client ID
> now exists at `.google-client-id` (`849693216860-ehc8v7i30r217tu9hd3c02cshccdigle.apps.googleusercontent.com`
> `[VERIFIED: read this session]`); the redirect is the reversed client ID,
> `com.googleusercontent.apps.849693216860-ehc8v7i30r217tu9hd3c02cshccdigle:/oauth2redirect`, to be
> registered via `CFBundleURLTypes` in `ios/Runner/Info.plist`, which currently has **no** such key
> `[VERIFIED: read this session — full file below]`; **UAT serving does NOT move to the tailnet TLS
> origin** — that entire consideration is void; **the button will not exist in the browser build** —
> accepted cost, browser keeps Phase 35's `.ics` path unchanged.
>
> **Sections below are marked either `REVISED — native iOS` (rewritten this pass, transport-specific)
> or `UNCHANGED — transport-independent` (still correct as originally written; the underlying Google
> Calendar API, token-lifecycle error shape, and data-mapping logic do not care how the token was
> obtained).** Superseded text is struck through and kept, not deleted, so the reasoning trail is
> visible rather than silently rewritten — the same discipline this project's own ROADMAP.md uses for
> reversed decisions.

## Summary

**REVISED — native iOS.** The summary below reflects the current (native-only) premise. The original
web-flow findings A and B are kept, struck through, and annotated — they are why the pivot happened,
and the planner should be able to see that reasoning rather than have it disappear.

**Finding B is now CONFIRMED, not a risk to test for — the owner independently verified it and ruled.**
Google's "Web application" client type is a confidential client that will not complete a secret-free
PKCE exchange, and a browser page cannot hold a secret regardless of transport (it ships in the public
bundle). This research's own citations
`[CITED: discuss.google.dev/t/authorization-code-flow-without-client-secret/168113;
github.com/manfredsteyer/angular-oauth2-oidc/issues/812]` turned out to be correct and load-bearing.
Google's own native-app documentation gives the clean way out: **iOS-registered clients are public
clients** — `client_secret` "is not applicable" to them, and "refresh tokens are always returned for
installed applications" `[CITED: developers.google.com/identity/protocols/oauth2/native-app — re-read
and re-confirmed this pass]`. That is exactly decision 1's "no secret" premise, just on the one client
type where Google actually honors it without a backend.

~~**Finding A (changes the recommended package/approach, does not change the scope decisions):**
`google_sign_in` — the obvious, highest-quality-looking candidate (flutter.dev publisher, 160/160 pub
points, ~1.9M downloads/30d) — **cannot deliver the token shape CALAUTH-03 needs on Flutter web.**
Google's own docs state its web implementation runs entirely on Google Identity Services' "token model":
access tokens expire in ~3600 seconds and **no refresh token is ever returned to the client** — the
user must be re-prompted, via a live button click, roughly hourly, not weekly
`[CITED: developers.google.com/identity/oauth2/web/guides/use-token-model; pub.dev/packages/google_sign_in]`.
That is a materially worse experience than the 7-day expiry the owner explicitly accepted, and it is an
architectural property of GIS's web token model, not a bug — no package configuration fixes it. This
research recommends `googleapis_auth` + `googleapis` + `flutter_web_auth_2` instead (detail below);
`google_sign_in` should not be used for this phase's Google Calendar token.~~ **Superseded by the pivot
to native — but re-examined below on its OWN, iOS-specific merits (not carried forward from the web
verdict), because the coordinator correctly flagged that GIS's web token-model reasoning does not
automatically transfer to Google's native iOS SDK. Short answer: `google_sign_in` is STILL not
recommended on iOS, but for a different, iOS-specific reason — see "Package re-decision for native iOS"
below.**

~~**Finding B (a real, unresolved risk to decision 1's exact shape — must be tested before the phase
builds on top of it):** ... The redirect URI the owner already registered
(`https://danserver.tailc2efd2.ts.net:8446/oauth-callback.html`, a Web-application-type client) may
therefore hit this wall. ... Recommendation: try (a) first if Finding B is confirmed, since it is the
smaller deviation from what's already built.~~ **This is exactly what happened — Finding B was
confirmed, and the owner chose the OTHER option this research had already named: re-register as a
public-client type (iOS, not "Desktop app", since the target is a phone, not a loopback-capable
desktop process) rather than ship a secret. That option was explicitly on this research's own list
before the pivot — worth noting because it means the pivot was not a surprise this research failed to
anticipate, just a branch it correctly named but didn't default to.**

**The ⭐ finding is UNCHANGED and still the best reason to prefer this whole path over ICS:** verified
against Google's own API reference, `events.list(singleEvents=true)` resolves each instance's
`start`/`end` to its actual (possibly rescheduled) time — the `originalStartTime` field exists
specifically to preserve where the occurrence *would* have been, which only makes sense if `start`
already reflects where it *actually is* `[CITED: developers.google.com/workspace/calendar/api/v3/reference/events]`.
Cancelled single occurrences require one deliberate choice this research settles: call `events.list`
with `showDeleted=true` (not the default `false`) so cancelled instances come back as minimal
`status:"cancelled"` stubs with `id`/`recurringEventId`/`originalStartTime` populated — mapping cleanly
onto this codebase's existing `SkipReason.cancelled` path — rather than being silently omitted, which is
what happens at the default `showDeleted=false`
`[CITED: developers.google.com/workspace/calendar/api/v3/reference/events/list]`. This is a genuine
capability the ICS path structurally cannot match (`WINDOWS.md` id 1, confirmed by reading
`ics_calendar_source.dart` directly this session) — this reasoning is entirely transport-independent and
applies exactly as strongly to the native iOS token as it would have to a web token.

**Primary recommendation (REVISED — native iOS):** Build `GoogleCalendarSource` as an **iOS-only**
fourth `CalendarSource` using `flutter_appauth` (wraps the certified AppAuth-iOS SDK: PKCE handled
internally, `ASWebAuthenticationSession` for the consent screen, a dedicated
`FlutterAppAuthUserCancelledException` for the cancel case) for the interactive authorize+exchange step,
then hand the resulting tokens to `googleapis_auth`'s `AccessCredentials`/`refreshCredentials` for
ongoing silent refresh and to `googleapis`'s typed Calendar v3 client for API calls — preserving this
research's original, still-valid `ServerRequestFailedException`-based CALAUTH-03 detection logic
unchanged. Persist the token as four new nullable `AppSettings` fields (schema v11 → v12, following the
exact additive-field pattern already proven safe in this codebase — unchanged from the original
recommendation). Register `CFBundleURLTypes` in `ios/Runner/Info.plist` with the reversed client ID as
the URL scheme (exact XML in Code Examples below).

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
4. **NATIVE iOS client with a custom URI scheme. REVISED 2026-09-22 — reverses the original decision 4**
   (verbatim from `36-CONTEXT.md`, itself updated by the owner; the struck-through text below is what
   this decision *used to* say, kept for trail visibility):
   ~~HTTPS redirect URI — the tailnet origin `https://danserver.tailc2efd2.ts.net:8446`... UAT serving
   moves to the TLS origin for this phase.~~
   Google's *Web application* client is confidential and will not do a secret-free PKCE exchange; a
   browser page cannot hold a secret. Owner ruled **build it native**. Google: *"the `client_secret` is
   not applicable to ... iOS"* and *"refresh tokens are always returned for installed applications."*
   - Cloud Console registers an **iOS** client keyed on **bundle ID**. No redirect URI or JS origins.
   - Redirect is the reversed client ID, registered via `CFBundleURLTypes` in `Info.plist` (which
     currently has **no** `CFBundleURLTypes` key at all — confirmed by reading the file directly this
     session, see Code Examples).
   - **The tailnet HTTPS origin is irrelevant. UAT serving does NOT move.**
   - **The button will NOT exist in the hosted browser build.** Accepted cost, not an oversight. Browser
     keeps Phase 35's `.ics` path.
   - `google_sign_in`'s web flow was rejected on evidence: no refresh token, ~1 hour expiry, hourly
     re-consent — worse than the accepted 7-day cadence.
   - `36-CONTEXT.md`'s own text still reads "Bundle ID is still `com.example.canopy`" — **that line is
     now stale**: the rename already happened
     `[VERIFIED: git log — "chore: com.example.canopy -> com.danjjohnson.canopy across all platforms",
     commit 900b7c5, and ios/Runner.xcodeproj/project.pbxproj now reads `com.danjjohnson.canopy` at
     every `PRODUCT_BUNDLE_IDENTIFIER` occurrence, read this session]`. The Google Cloud iOS client must
     be registered against **`com.danjjohnson.canopy`**, not the placeholder CONTEXT.md still names —
     flag this explicitly for the planner so it isn't silently missed.
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
| CALAUTH-01 | Connecting Google Calendar is a button, not a manual URL hunt | **REVISED:** Standard Stack (native flow via `flutter_appauth`, `ASWebAuthenticationSession`), Architecture Patterns Pattern 1 — button exists on iOS only, not in the browser build (accepted cost, see Revision Banner) |
| CALAUTH-02 | Canopy holds a read-only Google token and cannot write, enforced by scope | UNCHANGED. Scope verification (`calendar.readonly` — see "Scope choice, verified" below); `CalendarSource` interface has no write verb (`[VERIFIED: lib/data/calendar/calendar_source.dart:16-39]`) |
| CALAUTH-03 | An expired or revoked token degrades visibly with a one-tap reconnect, never a silently stale calendar | UNCHANGED, transport-independent. "Token lifecycle on the wire" section — exact `invalid_grant` shape, distinguishing signal, and `ServerRequestFailedException` fields (unchanged: this research recommends keeping `googleapis_auth`'s refresh/error surface for the ongoing-refresh path even though `flutter_appauth` handles the initial interactive exchange) |
| CALAUTH-04 | No client secret exists in the repository | **REVISED — now cleanly satisfied, not merely "genuinely at risk."** An iOS-type Google Cloud client is a public client: no secret is issued, none needs injecting, none can leak. Finding B's original risk (Web-application-type client forcing a secret) is why the phase pivoted away from that client type entirely. |
</phase_requirements>

## Architectural Responsibility Map

**REVISED — native iOS.** "Browser / Client" below now means the native iOS app process, not a web
page; the tier taxonomy's closest fit is still "Client" (there is still no backend anywhere in this
app), but the mechanism is now a native SDK/certified library, not JS running in a tab.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| OAuth consent UI (`ASWebAuthenticationSession` sheet, Google's own hosted page) | Client (native iOS) | — | Google hosts its own consent screen inside an OS-provided, cookie-isolated browser sheet; the app only launches it and awaits the result |
| PKCE code_verifier/challenge generation | Client (native iOS — handled INSIDE `flutter_appauth`'s AppAuth-iOS SDK, not hand-rolled Dart) | — | AppAuth generates and manages PKCE internally as part of `authorizeAndExchangeCode()` — a change from the original web plan, which hand-rolled this in Dart. Never sent to any Canopy-controlled server (there still isn't one). |
| Authorization code → token exchange | Client (native iOS, via `flutter_appauth`) | — | Still no backend; the exchange happens directly from the device to `oauth2.googleapis.com`, same trust boundary as before, different library performing it |
| Token storage (access/refresh token, expiry) | Client (Hive — same persistence tier as before) | — | UNCHANGED. Same `AppSettings` fields, same schema-migration mechanism; Hive on iOS is filesystem-backed rather than IndexedDB-backed, but the app-level design is identical |
| Calendar data fetch (`calendarList.list`, `events.list`) | Client (native iOS) | — | UNCHANGED reasoning — direct client→Google API calls, same shape as `IcsCalendarSource`'s direct client→feed-URL calls, using `googleapis`'s typed client regardless of transport |
| Event → `CommitmentBlock` mapping | Client (`CalendarSyncService`) | — | UNCHANGED — reused unchanged (CONTEXT.md decision 3) |
| Scheduling engine | Client (`schedule_generator.dart`) | — | UNCHANGED — explicitly out of scope; byte-identical per CONTEXT.md |

The "no backend exists, so a confidential-client secret has nowhere safe to live" reasoning that drove
Finding B still holds as an explanation of *why* the Web-application client type was wrong for this app
— it just resolved by moving to a client type (iOS) that Google itself treats as public, rather than by
inventing a backend tier that still doesn't exist.

## Standard Stack

### Package re-decision for native iOS — REVISED, answers the coordinator's specific question

The coordinator asked directly: does the web-grounds rejection of `google_sign_in` transfer to iOS,
given its iOS implementation wraps Google's native Sign-In SDK rather than GIS's browser token model?
**Checked specifically. The answer is: the ~1-hour/no-refresh-token reasoning does NOT transfer — but
`google_sign_in` is still not recommended, for a different, iOS-specific reason.**

On iOS, `google_sign_in`'s design intentionally does **not** hand the app a raw, storable
`refresh_token` string at all. Its documented mechanism for durable/offline access is `serverAuthCode`
— a one-time code the app is meant to **send to its own backend**, which exchanges it and manages the
refresh token **server-side**: *"the one-time authorization code is retrieved in your sign-in callback
and securely passed to your server, where your backend server then exchanges the authorization code for
access and refresh tokens... manage server tokens for that user entirely on the server side"*
`[CITED: developers.google.com/identity/sign-in/ios/offline-access]`. Canopy has no backend, on any
platform, by explicit and permanent design (CLAUDE.md, `.planning/PROJECT.md`'s Out of Scope) — so the
package's own intended mechanism for a durable token is structurally unusable here, independent of the
web-vs-native distinction. Day-to-day, silent re-authentication on iOS is instead handled *opaquely*
inside the SDK's own Keychain-backed session (`authorizationClient.authorizationForScopes()`), which is
real and does work — but it gives the app no raw token to persist in Hive, no way to inspect the
underlying token endpoint's error shape, and (unverified, flagged as an open question below) no
certainty that its silent-restore failure is even distinguishable from a network error the way
CALAUTH-03 requires. This is the opposite of CALAUTH-02/03's architecture, which explicitly wants
Canopy to hold and inspect the token itself.

`flutter_appauth`'s architecture is the reverse: it hands the app the raw `accessToken`, `refreshToken`,
and `accessTokenExpirationDateTime` directly, because it wraps the AppAuth-iOS SDK, which is built
specifically for apps that manage their OWN token lifecycle (the standard shape for a mobile app with no
backend) rather than assuming one exists. That is exactly this app's architecture, and it is why this
research now recommends `flutter_appauth` as primary, not `google_sign_in`, on iOS — a different reason
than the web verdict, arriving at the same practical conclusion.

| Package | Weekly downloads (30d/4, `[VERIFIED: pub.dev API]`) | Publisher (verified?) | GitHub owner vs. publisher domain | Last release | Open issues (`[VERIFIED: GitHub API, this session]`) | Explicit iOS support | Verdict for THIS requirement |
|---------|--------------------------------------------------------|-------------------------|--------------------------------------|----------------|-----------------------------------------------------------|-------------------------|-------------------------------|
| `google_sign_in` | ~446K/wk (1,911,595/30d) | `flutter.dev` ✓ verified | `github.com/flutter/packages` — matches | 2025-09-17 (v7.2.0) | 256 (whole monorepo, not package-specific) | Yes, first-class | **Rejected for iOS too** — no raw refresh token exposed to the app; its own durable-access design (`serverAuthCode`) assumes a backend Canopy doesn't have. Silent SDK-managed refresh is real but opaque to CALAUTH-03's error-shape requirement. |
| `flutter_appauth` | ~84K/wk (359,615/30d) | `dexterx.dev` ✓ verified | `github.com/MaikuB` (Michael Bui) — **personal domain, confirmed same person via search, not a mismatch** `[CITED: search corroboration]` | 2026-08-29 (v12.1.0), repo last pushed 2026-09-13 (10 days before this research) | 102 | Yes — wraps AppAuth-iOS, `ASWebAuthenticationSession` (iOS 12+) / `SFSafariViewController` (pre-12) | **Recommended.** Certified AppAuth reference implementation, PKCE handled internally, raw tokens exposed to the app, dedicated `FlutterAppAuthUserCancelledException` for the cancel case. |
| `flutter_web_auth_2` | ~114K/wk (487,142/30d) | `femtopedia.de` ✓ verified | `github.com/ThexXTURBOXx` — plausible personal/project domain, verified via pub.dev's DNS-TXT publisher check | 2026-08-12 (v5.1.0), repo last pushed 2026-09-08 | 30 | Yes — **does use `ASWebAuthenticationSession` on iOS despite the "web" name** `[CITED: pub.dev/packages/flutter_web_auth_2]` | **Viable but redundant now.** It only captures a redirect URL — you'd still hand-roll PKCE math and the token exchange on top of it (the original web-plan's design). `flutter_appauth` does all three (PKCE, session launch, code exchange) through one certified library, which is the better fit now that a generic redirect-capture tool isn't the missing piece. |

**Recommendation, stated plainly:** `flutter_appauth` for the interactive authorize+exchange step (owns
PKCE, the `ASWebAuthenticationSession` sheet, and cancellation); `googleapis_auth`'s
`AccessCredentials`/`refreshCredentials`/`ServerRequestFailedException` for ongoing silent refresh and
CALAUTH-03 error detection (this part of the original research is UNCHANGED — see "Keep" note in the
Revision Banner); `googleapis`'s typed Calendar v3 client for the actual data calls (UNCHANGED). Do NOT
add `flutter_web_auth_2` — it would be a redundant second way to do what `flutter_appauth` already owns.

### Core

| Library | Version (verified via `pub.dev` API, 2026-09-22) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_appauth` | ^12.1.0 (published 2026-08-29) `[VERIFIED: pub.dev API]` | **REVISED — new, primary.** The interactive authorize+exchange step: builds the PKCE request internally, launches `ASWebAuthenticationSession`, exchanges the code, returns `accessToken`/`refreshToken`/`accessTokenExpirationDateTime` | Certified wrapper around AppAuth-iOS (the reference OAuth/OIDC native-app implementation); 102 open issues against an actively-maintained repo (pushed 10 days before this research) is normal for a widely-used native plugin, not a red flag on its own |
| `googleapis_auth` | ^2.3.4 (published 2026-09-17) `[VERIFIED: pub.dev API]` | UNCHANGED role, narrowed scope: ongoing silent refresh (`refreshCredentials`) and CALAUTH-03 error-shape detection (`ServerRequestFailedException` — `statusCode` + `responseContent`) — no longer used for the *initial* code exchange, which `flutter_appauth` now owns | Published by Google itself (`publisher: google.dev`, verified), 150/160 pub points, 1.6M downloads/30d. Still the cleanest way to keep this research's already-verified `invalid_grant` detection code (see Code Examples). |
| `googleapis` | ^17.0.0 (published 2026-08-24) | UNCHANGED. Typed Calendar API v3 client (`CalendarApi`, `Events.list(...)`, `CalendarList.list(...)`) — avoids hand-parsing Google's JSON schema for `recurringEventId`/`originalStartTime`/`status` | Published by `google.dev` (verified), 1.1M downloads/30d. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `http` | ^1.6.0 (already a dependency `[VERIFIED: pubspec.yaml:44]`) | UNCHANGED. `googleapis_auth`/`googleapis` both accept an injectable `http.Client`, which is also the seam that keeps tests off the network, mirroring `IcsFetcher`'s existing pattern | Pass a fake `http.Client` in tests, same idiom as `IcsCalendarSource`'s `IcsFetcher` typedef |

~~`crypto` (Dart-team `dart.dev` publisher) — `sha256` for the PKCE `code_challenge` (S256 method)~~
**No longer needed as a direct dependency.** `flutter_appauth` generates and verifies the PKCE
`code_verifier`/`code_challenge` internally via AppAuth-iOS — this app no longer needs to do that math
itself, which is a genuine simplification the pivot bought, not just a cost.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `flutter_appauth` | `google_sign_in` | **Rejected for iOS — see the dedicated comparison above.** Different reason than the web rejection (no raw refresh token exposed; its durable-auth design assumes a backend Canopy doesn't have), same practical conclusion. |
| `flutter_appauth` | `flutter_web_auth_2` (+ hand-rolled PKCE + `googleapis_auth`'s code exchange) | **Viable but redundant.** This was the original web-plan's design, ported to iOS. `flutter_appauth` already does everything this combination would, through one certified library, with less hand-rolled surface (no PKCE math to write or test). |
| `flutter_appauth` | `oauth2` (dart.dev) | Same as the original verdict — general-purpose, PKCE-capable, maintained by the Dart core team, but doesn't understand Google's `invalid_grant` shape or wrap a certified native SDK. `flutter_appauth` is the better native-specific fit. |
| A committed client secret | PKCE-only, no secret | UNCHANGED conclusion, now cleanly achieved rather than merely hoped for: an iOS-type Google Cloud client genuinely issues no secret. |

**Installation:**
```bash
flutter pub add flutter_appauth googleapis_auth googleapis
```

## Package Legitimacy Audit

> The project's `gsd-tools package-legitimacy check` seam only supports `npm|pypi|crates` ecosystems —
> it has no `pub` (Dart/Flutter) mode. The table below was built by hand from the `pub.dev` public API
> (`https://pub.dev/api/packages/<name>/score`, called directly this session) plus a `WebFetch` read of
> each package's own pub.dev page for publisher/platform claims. Every download/points/publisher figure
> below is `[VERIFIED: pub.dev API]`; every "recommended for this use" judgment is this research's own,
> not the seam's.

**REVISED — native iOS stack.** `flutter_web_auth_2` and `crypto` are removed (no longer part of the
recommended stack — see Standard Stack); `flutter_appauth` moves from "not recommended for this phase"
to primary, with the reasoning updated (see Standard Stack's dedicated comparison, not the old
web-support gap).

| Package | Registry | Published | Downloads/30d | Publisher (verified?) | GitHub owner matches publisher? | Verdict | Disposition |
|---------|----------|-----------|----------------|------------------------|----------------------------------|---------|-------------|
| `flutter_appauth` | pub.dev | 2026-08-29 (v12.1.0) | 359,615 | `dexterx.dev` ✓ verified | `github.com/MaikuB` (Michael Bui) — personal domain, confirmed same maintainer, not a mismatch | OK | **Approved, now primary** — see Standard Stack's iOS-specific comparison. |
| `googleapis_auth` | pub.dev | 2026-09-17 (v2.3.4) | 1,619,416 | `google.dev` ✓ verified | `github.com/google/googleapis.dart` — yes | OK | Approved — role narrowed to ongoing refresh + error detection, unchanged from original research |
| `googleapis` | pub.dev | 2026-08-24 (v17.0.0) | 1,115,123 | `google.dev` ✓ verified | `github.com/google/googleapis.dart` — yes | OK | Approved, unchanged |
| `google_sign_in` | pub.dev | 2025-09-17 (v7.2.0) | 1,911,595 | `flutter.dev` ✓ verified | `github.com/flutter/packages` — yes | OK (package itself is legitimate) | **Not recommended for this use, on iOS-specific grounds** (re-examined this pass, not carried forward from the web verdict) — see Standard Stack. Legitimacy is not the problem; architecture fit is. |
| ~~`flutter_web_auth_2`~~ | pub.dev | 2026-08-12 (v5.1.0) | 487,142 | `femtopedia.de` ✓ verified | `github.com/ThexXTURBOXx` — plausible | OK (package itself is legitimate) | **Removed from the recommended stack** — redundant now that `flutter_appauth` owns the whole interactive flow. Not a legitimacy concern; a design simplification. |
| ~~`crypto`~~ | pub.dev | (Dart-team package, long-lived) | very high | `dart.dev` ✓ verified | `github.com/dart-lang/core` — yes | OK | **Removed** — no longer needed; `flutter_appauth` handles PKCE internally. |

**Packages removed due to `[SLOP]` verdict:** none — every candidate considered is a real, well-adopted,
verified-publisher package. This phase's risk was never slopsquatting; Finding B (now resolved) was a
platform-configuration risk, not a package-legitimacy one.
**Packages flagged as suspicious `[SUS]`:** none.

## Architecture Patterns

### System Architecture Diagram — REVISED, native iOS

```
 User taps "Connect Google Calendar" (iOS only — see Factory Routing)
        │
        ▼
 flutter_appauth.authorizeAndExchangeCode(
   AuthorizationTokenRequest(
     clientId,                              // from .google-client-id
     'com.googleusercontent.apps.<id>:/oauth2redirect',  // reversed client ID
     serviceConfiguration: AuthorizationServiceConfiguration(
       authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
       tokenEndpoint: 'https://oauth2.googleapis.com/token',
     ),
     scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
     // PKCE code_verifier/code_challenge generated INTERNALLY by AppAuth-iOS —
     // this app never touches that math (a genuine simplification vs. the
     // original web plan).
   ),
 )
        │
        ▼
 iOS presents an ASWebAuthenticationSession sheet (iOS 12+) — a system-owned,
 cookie-isolated browser context, NOT a popup this app controls
        │
        ├─ user consents ──▶ iOS matches the redirect scheme
        │                    (com.googleusercontent.apps.<id>) against
        │                    CFBundleURLTypes, dismisses the sheet, and
        │                    AppAuth-iOS exchanges the code for tokens
        │                    INSIDE the same native call — the Dart await
        │                    resolves directly with an
        │                    AuthorizationTokenResponse{accessToken,
        │                    refreshToken, accessTokenExpirationDateTime}
        │
        └─ user dismisses the sheet ──▶ FlutterAppAuthUserCancelledException
                    │                    — a REAL state, not an error to
                    │                    swallow: reset to the not-connected
                    ▼                    CTA silently, no error SnackBar
              (back to the "Connect Google Calendar" button, unchanged)
        │
        ▼ (on success)
 Persist 4 new AppSettings fields (Hive) — schema v11→v12 — UNCHANGED design

 ── Later, on every sync ──

 CalendarSyncService.sync()
        │
        ▼
 GoogleCalendarSource.listEvents() / listCalendars()
        │
        ├─ access token still valid → call Calendar API directly
        ├─ access token expired (401) → silently refresh via
        │     googleapis_auth.refreshCredentials(clientId, credentials, httpClient)
        │     — UNCHANGED from original research, retry once, no user-visible change
        └─ refresh_token itself dead (400 invalid_grant) → ServerRequestFailedException
                    │            — UNCHANGED detection logic — sets CalendarSyncResult's
                    │              "reconnect needed" state (see Token Lifecycle section)
                    ▼
              CALAUTH-03 degradation path
        │
        ▼
 googleapis.CalendarApi(authClient).events.list(
   calendarId, singleEvents: true, showDeleted: true,
   timeMin, timeMax)                       — UNCHANGED
        │
        ▼
 Map Event → CalendarEvent (this phase's new mapping function,
   mirrors device_calendar_source.dart's mapDeviceEvent shape) — UNCHANGED
        │
        ▼
 CalendarSyncService._mapEvent() — REUSED UNCHANGED
        │
        ▼
 CommitmentBlock (Hive) → schedule_generator.dart (UNCHANGED, byte-identical)
```

**What's genuinely different from the original web diagram:** no popup this app manages, no
`postMessage` bridging, no `oauth-callback.html` static page, no hand-rolled PKCE math, and a NEW real
UI state (user-cancelled) that the original web-plan's diagram never called out explicitly. **What's
identical:** everything from "Persist 4 new AppSettings fields" onward — the whole sync/refresh/mapping
pipeline doesn't know or care which library obtained the token it's holding.

### Recommended Project Structure — REVISED

```
lib/data/calendar/
├── calendar_source.dart              # unchanged interface
├── calendar_source_factory.dart      # extended: iOS branch gains a Google-connected
│                                      #   check alongside the existing Device branch —
│                                      #   see Factory Routing (a NEW open question this
│                                      #   pivot introduces, not present in the web plan)
├── google_calendar_source.dart       # NEW — the fourth CalendarSource
├── google_auth_client.dart           # NEW — flutter_appauth interactive flow +
│                                      #   googleapis_auth refresh + token persistence,
│                                      #   separate from the CalendarSource itself so it
│                                      #   can be unit-tested independently (mirrors the
│                                      #   split between IcsCalendarSource and IcsFetcher)
├── device_calendar_source.dart       # unchanged
├── ics_calendar_source.dart          # unchanged — still the WEB/desktop/Android path
└── null_calendar_source.dart         # unchanged
```

### Pattern 1: Injectable seams, mirroring `IcsFetcher` — REVISED signature, same idea

`IcsCalendarSource` keeps itself testable with one typedef:

```dart
// Source: lib/data/calendar/ics_calendar_source.dart:13 [VERIFIED — read this session]
typedef IcsFetcher = Future<String> Function(Uri url);
```

`GoogleCalendarSource` needs the same shape at (at least) two seams — UNCHANGED in spirit, the auth
seam's return type changes to match `flutter_appauth`'s output type rather than `googleapis_auth`'s:

```dart
// Recommended shape (this research's own — updated for flutter_appauth)
typedef GoogleAuthLauncher = Future<AuthorizationTokenResponse> Function(
  String clientId,
  List<String> scopes,
);
// AuthorizationTokenResponse (flutter_appauth) is then converted to
// googleapis_auth's AccessCredentials for use with googleapis's CalendarApi —
// a small adapter function, not a design change.

typedef GoogleApiClientFactory = http.Client Function(AccessCredentials);  // unchanged
```

A test can then fake `GoogleAuthLauncher` to return a pre-baked `AuthorizationTokenResponse` (skipping
the `ASWebAuthenticationSession` sheet entirely — flutter_test cannot drive a real native sheet anyway)
and fake the underlying `http.Client` to return canned Calendar API JSON responses (including a fixture
with a moved and a cancelled recurring instance, and a fixture that reproduces the exact
`400 invalid_grant` body from the "Token Lifecycle" section below) — all without a device, a network
call, or a real Google account. **Also add a fake `GoogleAuthLauncher` that throws
`FlutterAppAuthUserCancelledException`**, so the reset-to-CTA behavior is proven, not assumed — this is
new relative to the original research, which had no cancellation case to test since a popup close isn't
modeled the same way. This is the direct, still-correct answer to research question 7.

### Pattern 2: Token storage as additive `AppSettings` fields — UNCHANGED, transport-independent

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

- ~~**Do not persist the PKCE `code_verifier` anywhere durable...**~~ **MOOT under the native flow.**
  AppAuth-iOS generates, holds, and consumes the `code_verifier` entirely inside the native SDK's own
  in-memory session for the duration of one `authorizeAndExchangeCode()` call — this app's Dart code
  never sees it at all, so there is nothing for this app to accidentally persist. A genuine
  simplification the pivot bought.
- **Do not swallow `FlutterAppAuthUserCancelledException` as a generic error.** This is new relative to
  the original research (which had no explicit cancellation case for a popup-based flow) and is exactly
  what the coordinator flagged: a user tapping "Cancel" on the consent sheet is a normal, expected state,
  not a failure. Catch it specifically and reset to the not-connected CTA — mirroring this screen's own
  existing pattern of not surprising the user (`_mobileFuture == null` → CTA state,
  `[VERIFIED: lib/screens/settings/calendar_settings_screen.dart:76-79]`). Do NOT show an error SnackBar
  for a cancellation; that would be exactly the kind of unnecessary alarm CLAUDE.md's "notify vs.
  record" philosophy (a different section, same spirit) warns against overusing.
- **Do not call `events.list` with the default `showDeleted=false`.** UNCHANGED — still transport-
  independent. It silently omits cancelled recurring-instance exceptions, which is the exact defect
  class `WINDOWS.md` entry 1 already tracks for the ICS path — reproducing it on the Google path after
  specifically choosing Google to *close* that entry would be a real regression hiding behind a green
  build.
- **Do not conflate a 401 from the Calendar API itself with a 400 `invalid_grant` from the token
  endpoint.** UNCHANGED — still transport-independent. They are different endpoints, different status
  codes, and require completely different responses (silent retry vs. visible reconnect) — see Token
  Lifecycle below.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Calendar API JSON → Dart models | A hand-parsed `jsonDecode` reader for `Events`/`Event`/`CalendarListEntry` | `googleapis`'s typed `CalendarApi` | UNCHANGED reasoning — the exact field set this phase depends on (`recurringEventId`, `originalStartTime`, `status`) took three separate official-doc fetches to fully pin down — a hand-rolled parser is where a subtly wrong field name would hide unnoticed. |
| ~~Popup + redirect capture on Flutter web~~ **PKCE + native consent sheet + code exchange, on iOS** | ~~Hand-rolled `window.open` + `postMessage` + a bespoke `oauth-callback.html`~~ A hand-rolled `ASWebAuthenticationSession` platform channel + hand-rolled PKCE math | **REVISED:** `flutter_appauth` | Wraps the certified AppAuth-iOS reference implementation — PKCE, session launch, code exchange, and cancellation detection all come from one library built specifically for this exact problem, rather than three separate concerns this app would otherwise own. |
| Ongoing token refresh + typed error surface | A hand-rolled `http.post` to `oauth2.googleapis.com/token` with manual JSON parsing of success/error bodies | `googleapis_auth`'s `refreshCredentials` / `ServerRequestFailedException` | UNCHANGED role, narrowed to the ongoing-refresh path (the initial exchange now goes through `flutter_appauth` instead) — still published by Google itself, still tracks Google's own token-endpoint error shape (`statusCode`, `responseContent`) without this codebase needing to encode Google-specific error parsing logic by hand. |

**Key insight:** every "don't hand-roll" item above is a place where the *shape* of Google's API is
easy to get approximately right and subtly wrong — a wrong field name, a missed `showDeleted` default,
an unhandled `window.opener == null` case — and where a well-adopted, Google- or verified-publisher
package has already paid down that risk. This mirrors Phase 35's own `enough_icalendar`+`rrule` choice
almost exactly, down to the "reject the low-adoption alternative" reasoning CONTEXT.md explicitly asks
this research to apply.

## Common Pitfalls

### Pitfall 1: The "Web application" client type does not support secret-free PKCE (Finding B) — CONFIRMED, now historical context

**What goes wrong:** Building the whole phase assuming decision 1 ("no client secret") works against a
**Web application**-type client, only to discover at UAT time that the token exchange fails with `400
invalid_request: client_secret is missing`.
**Status update:** This is no longer a hypothesis to test — **the owner independently verified it and
reversed decision 4 as a direct result.** Recorded here as the reason the phase pivoted, not as an open
risk. The phase's Google Cloud client is now **iOS type**, which does not have this problem at all
(`client_secret` "is not applicable" to it `[CITED: developers.google.com/identity/protocols/oauth2/native-app]`).
**Residual risk, restated for the new client type:** confirm the *iOS* client's token exchange also
succeeds with no secret, against the owner's actual registered client — very likely fine per Google's
own explicit statement, but this research has now been wrong once about an unverified token-endpoint
claim (well, correctly cautious, but the point stands: verify before building deeply on top of it) and
the cost of checking is the same ~15 minutes it was before.
**Warning signs:** A `400` response containing the string `client_secret` anywhere in the body — if this
recurs even against the new iOS client, something is misregistered (most likely the bundle ID — see
Pitfall 4 below), not a repeat of the original platform-level issue.

### ~~Pitfall 2: Port 8146 already serves a DIFFERENT build with an active service worker~~ — VOID

**This pitfall no longer applies and is kept only so a reader scanning past it isn't confused by its
absence.** It was about the tailnet HTTPS origin (`danserver.tailc2efd2.ts.net:8446`) colliding with a
different build on the same local port. Decision 4's reversal makes the entire tailnet-origin
consideration irrelevant to this phase — "UAT serving does NOT move," per `36-CONTEXT.md`'s own revised
text. The underlying facts this pitfall reported (port 8146 does host a different, service-worker-
registering build) remain true and are still worth knowing for **other** phases that might touch web
UAT serving, just not this one.

### Pitfall 3: Conflating "offline" with "your login expired" — UNCHANGED, transport-independent

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

### Pitfall 4 (NEW): Bundle ID mismatch between the Google Cloud client and the built app

**What goes wrong:** The Google Cloud iOS client is registered against a specific bundle identifier. If
that string doesn't exactly match the app's actual `CFBundleIdentifier` at runtime, sign-in fails —
typically as `invalid_client` or the consent sheet simply not completing, per
`36-GOOGLE-CLOUD-SETUP.md`'s own troubleshooting table (`[VERIFIED: read this session]`: *"`invalid_client`
/ nothing happens on tap | bundle ID mismatch — the client's bundle ID must equal the app's
CFBundleIdentifier exactly"*).
**Why it happens:** This project's bundle ID changed mid-phase (`com.example.canopy` →
`com.danjjohnson.canopy`, confirmed via git log this session) — a real, concrete opportunity for the
Google Cloud registration and the actual shipped bundle ID to drift apart if the Cloud Console client
was created (or re-created) against the wrong one, or if a build variant (debug vs. release, or a
future distribution bundle ID with a suffix) doesn't match.
**How to avoid:** Confirm the Google Cloud iOS client's registered bundle ID is exactly
`com.danjjohnson.canopy` before relying on it — this is a five-second visual check in Cloud Console, not
a code fix, and worth stating as an explicit plan step given the mid-phase rename.
**Warning signs:** `invalid_client` from Google, or the `ASWebAuthenticationSession` sheet never
completing / immediately erroring without ever showing Google's consent UI.

### Pitfall 5 (NEW): This flow cannot be built-and-verified end-to-end on danserver at all

**What goes wrong:** Assuming any part of the interactive flow (the consent sheet appearing, a
successful code exchange, cancellation handling) can be confirmed by running tests or scripts on
danserver.
**Why it happens:** danserver has no Xcode and cannot build or run an iOS app — a pre-existing,
already-documented project constraint (`ROADMAP.md`'s Phase 36 entry, "iOS cannot be built on danserver.
Unchanged. Any device verification is the owner's MacBook." `[VERIFIED: read this session]`), which this
pivot makes load-bearing in a way it wasn't for the original web plan (where danserver COULD serve and
the whole flow WAS testable via a browser over the tailnet).
**How to avoid:** Everything network-independent (PKCE-adjacent unit tests — though there's now less of
that math to test directly, since AppAuth owns it — token-refresh/error-classification unit tests,
mapping-function unit tests, the Hive migration) can and should be built and verified on danserver.
Everything else (the actual "Connect Google Calendar" tap, the consent sheet, a real cancellation, a real
reconnect after expiry) is a human checkpoint on the owner's MacBook/device, full stop — plan it as such
explicitly rather than discovering it at UAT time.
**Warning signs:** A plan task that says "verify the sign-in button works" without naming whose device it
runs on.

## Code Examples

### `ios/Runner/Info.plist` — the exact `CFBundleURLTypes` block to add (REVISED, new)

Read directly this session: the file currently has **no** `CFBundleURLTypes` key at all
(`[VERIFIED: ios/Runner/Info.plist — full file read this session, 83 lines, no such key present]`). The
scheme value below is the reversed form of the real client ID already at `.google-client-id`
(`[VERIFIED: cat .google-client-id, this session]`) — **only the scheme goes in `CFBundleURLSchemes`,
without the trailing `:/oauth2redirect` path**, since iOS's URL-type registration routes by scheme only;
AppAuth matches the full redirect URI (including the path) at runtime, not iOS's launch services.

```xml
<!-- Insert as a new top-level key, alongside the existing CAL-01/CAL-02 comment block
     (Info.plist:27-34) this project already uses for calendar-related keys — same house
     style, explaining WHY the key exists. -->
<key>CFBundleURLTypes</key>
<array>
	<dict>
		<key>CFBundleTypeRole</key>
		<string>Editor</string>
		<key>CFBundleURLSchemes</key>
		<array>
			<string>com.googleusercontent.apps.849693216860-ehc8v7i30r217tu9hd3c02cshccdigle</string>
		</array>
	</dict>
</array>
```

`[VERIFIED: shape confirmed against pub.dev/packages/flutter_appauth's own iOS setup instructions,
fetched this session — the generic `<your_custom_scheme>` placeholder replaced with the real, verbatim
value from this repo's own `.google-client-id`, not a guess]`.

### The interactive authorize + exchange, via `flutter_appauth` (REVISED — replaces the hand-rolled PKCE + `googleapis_auth` code-exchange example)

```dart
// Source: flutter_appauth's authorizeAndExchangeCode signature, confirmed via
// pub.dev + GitHub this session [CITED]. PKCE is handled internally — this app
// never builds code_verifier/code_challenge itself.
const clientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'); // see Build-Time Injection
const redirectUri =
    'com.googleusercontent.apps.849693216860-ehc8v7i30r217tu9hd3c02cshccdigle:/oauth2redirect';

try {
  final AuthorizationTokenResponse result = await appAuth.authorizeAndExchangeCode(
    AuthorizationTokenRequest(
      clientId,
      redirectUri,
      serviceConfiguration: const AuthorizationServiceConfiguration(
        authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
        tokenEndpoint: 'https://oauth2.googleapis.com/token',
      ),
      scopes: const ['https://www.googleapis.com/auth/calendar.readonly'],
      // access_type/prompt are passed via additionalParameters where the
      // typed API doesn't expose them directly — confirm the exact parameter
      // name against the installed package version at implementation time.
      additionalParameters: const {'access_type': 'offline', 'prompt': 'consent'},
    ),
  );
  // result.accessToken / result.refreshToken / result.accessTokenExpirationDateTime
  // — convert to googleapis_auth's AccessCredentials for the CalendarApi + refresh path:
  final credentials = AccessCredentials(
    AccessToken('Bearer', result.accessToken!, result.accessTokenExpirationDateTime!.toUtc()),
    result.refreshToken,
    const ['https://www.googleapis.com/auth/calendar.readonly'],
  );
  // ... persist credentials' three fields into the 4 new AppSettings Hive fields (unchanged design)
} on FlutterAppAuthUserCancelledException {
  // A REAL state, not an error — see Anti-Patterns and Pitfall 4's sibling note.
  // Reset silently to the not-connected CTA. No SnackBar, no reconnect flag set.
}
```

### Detecting the CALAUTH-03 case (UNCHANGED — this is exactly the original research's code, reused verbatim, only the surrounding acquisition step changed above)

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

**Design note on which library owns refresh (REVISED — a deliberate choice, stated so the planner
doesn't have to re-derive it):** `flutter_appauth` also has its own `token()` method that could perform
the refresh grant, which would keep the whole token lifecycle inside one library with one error-shape
story (`PlatformException`/`FlutterAppAuthUserCancelledException`-style errors instead of
`ServerRequestFailedException`). This research recommends the split shown above — `flutter_appauth` for
the interactive step only, `googleapis_auth` for ongoing refresh — specifically **to preserve the
CALAUTH-03 detection code this research already verified** (`ServerRequestFailedException.statusCode`/
`responseContent`) rather than re-deriving an equivalent check against `flutter_appauth`'s own error
shape, which this research has not inspected. `ClientId(identifier, null)` (no secret) should work
identically for the refresh grant against an iOS-type client, per the same "refresh tokens are always
returned for installed applications" guarantee — flagged as Assumption A6 below, since it was not
exercised live.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| OAuth 2.0 Implicit Grant for browser apps | Authorization Code + PKCE | Google deprecated implicit-grant guidance well before this phase; still documented but explicitly marked insecure `[CITED: developers.google.com/identity/protocols/oauth2/javascript-implicit-flow]` | Already reflected correctly in CONTEXT.md decision 1 — no change needed |
| Custom URI scheme redirects (general guidance) | Loopback (`127.0.0.1:PORT`) redirects, where the platform allows it | Google's own native-app doc states custom schemes are discouraged in general "due to the risk of app impersonation" `[CITED: developers.google.com/identity/protocols/oauth2/native-app]` | **REVISED — now directly relevant, and this phase is on the "discouraged" side of it, by necessity.** iOS has no equivalent of a loopback listener reachable from a system browser sheet the way a desktop process does; the reversed-client-ID custom scheme is the standard, Google-documented mechanism for iOS specifically (distinct from the more general "installed application" loopback guidance, which targets desktop). This is not a corner being cut — it's the correct, Google-sanctioned mechanism for this specific platform — but worth flagging explicitly since the same source doc that recommends AGAINST custom schemes in general is also the one this phase's whole redirect mechanism depends on for iOS. App-impersonation risk on iOS specifically is mitigated by Apple's own app-ID/entitlement system, which is a different (and adequate) protection than the general warning is about. |

**Deprecated/outdated:** Nothing this phase would have reached for is itself deprecated — the original
risk here (Finding B, a platform-behavior mismatch for the Web-application client type) is now resolved
by the pivot, not by anything becoming un-deprecated.

## Assumptions Log

**REVISED.** A1's claim is now confirmed (promoted out of the "assumed" bucket — the owner verified it
independently). A2 and A5 are void under the native pivot (kept, struck through, for trail visibility).
A3/A4 are unchanged — they were never about transport. A6/A7/A8 are new, specific to the native flow.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | ~~Google's "Web application" client type actually enforces `client_secret`...~~ **CONFIRMED — no longer an assumption.** The owner independently verified this and reversed decision 4 as a direct, stated consequence. | Finding B, Pitfall 1 | N/A — resolved. Recorded for history, not as a live risk. |
| A2 | ~~The popup+`postMessage` pattern is the correct shape for `oauth-callback.html`...~~ **VOID.** There is no `oauth-callback.html`, no popup this app manages, and no `postMessage` bridging under the native flow. | Architecture Patterns (superseded diagram) | N/A — the whole mechanism this assumption was about no longer exists in the plan. |
| A3 | `ServerRequestFailedException.responseContent` actually contains the raw parseable body (including the `invalid_grant` string) rather than an already-summarized message | UNCHANGED — Token Lifecycle / Code Examples | UNCHANGED reasoning — if wrong, a two-line fix once the actual package source is read at implementation time. Still not exercised against a live error this session. |
| A4 | `googleapis`'s generated `Event` model actually exposes `recurringEventId`, `originalStartTime`, and `status` with the field names/types this research assumes | UNCHANGED — Standard Stack, Don't Hand-Roll | UNCHANGED reasoning — transport-independent, low risk given `googleapis` is a mechanical 1:1 generation from Google's own discovery document. |
| A5 | ~~The owner's registered redirect URIs (`.../oauth-callback.html` on both origins) will be accepted as-is by Google if option (a) [ship a secret] is chosen...~~ **VOID.** Option (a) was not chosen; the owner chose the other path this research had already named (re-register as a public client type). No redirect URI is registered at all for an iOS client — Google derives it from the reversed client ID. | Finding B, Summary | N/A — moot. |
| A6 (NEW) | `googleapis_auth.refreshCredentials` with `ClientId(identifier, null)` (no secret) succeeds against an **iOS-registered** client id, the same way the initial code exchange does | Code Examples, "Design note on which library owns refresh" | If wrong, the refresh step needs to move to `flutter_appauth`'s own `token()` method instead, which would also mean re-deriving the CALAUTH-03 `invalid_grant` detection against `flutter_appauth`'s error shape (`PlatformException` fields) rather than `ServerRequestFailedException`'s. Worth a quick implementation-time check — likely fine per Google's "refresh tokens are always returned for installed applications" framing, which reads as a property of the client type, not the specific grant call. |
| A7 (NEW) | `FlutterAppAuthUserCancelledException` reliably fires for every user-cancellation path on every supported iOS version (both the `ASWebAuthenticationSession` "Cancel" button and a swipe-to-dismiss, if that's even possible on that sheet type) | Anti-Patterns, Pitfall 4's sibling cancellation note, Code Examples | If some cancellation paths instead surface as a generic `PlatformException` or hang, the CTA-reset logic needs a broader catch clause. Documented as the package's stated mechanism `[CITED: pub.dev/packages/flutter_appauth]` but not exercised live — genuinely needs a real-device check, which is exactly the kind of thing Pitfall 5 says can't happen on danserver. |
| A8 (NEW) | `flutter_appauth`'s `AuthorizationTokenRequest` accepts `access_type`/`prompt` via `additionalParameters` with those exact string keys, and Google's token endpoint honors them the same way through this path as through a hand-built auth URL | Code Examples | If the parameter names or mechanism differ in the actual installed version, the practical effect is a missing `refresh_token` on reconnect after the 7-day expiry (since `access_type=offline`/`prompt=consent` control that) — this would surface immediately and obviously in manual testing (a reconnect that doesn't actually refresh anything), not silently. Confirm against the actual package source/example at implementation time. |

## Open Questions

**REVISED — Q1 is resolved, Q2 is reframed for the native reality, Q3 stands largely as originally
written, and a genuinely NEW question (Q4) is introduced by the pivot itself.**

1. ~~Does Google's "Web application" client type genuinely require `client_secret`...~~ **RESOLVED.**
   The owner verified this independently and ruled. No longer open.

2. **REVISED — Does the interactive flow work reliably, and how is it verified, given danserver cannot
   build or run iOS at all (not just "sandboxed automation is unreliable," as the original web-framed
   question said, but a hard, total absence of any local verification surface)?**
   - What we know: this project already carries the constraint "iOS cannot be built on danserver...
     Any device verification is the owner's MacBook" (`ROADMAP.md`, Phase 36 Constraints,
     `[VERIFIED: read this session]`) — pre-existing and unrelated to this research, but now the ONLY
     verification path for this phase's headline feature, where the original web plan would have let
     danserver serve and test the whole thing itself.
   - What's unclear: nothing structurally — same as before, this is "use the existing device-gate
     discipline" (already applied elsewhere in this project for `DeviceCalendarSource`), not a new
     unknown to resolve.
   - Recommendation: plan a human-driven UAT checkpoint on the owner's actual device for the connect
     flow (consent sheet appears with the correct read-only scope description, cancellation resets
     cleanly, a real reconnect-after-expiry works) — automated tests on danserver should cover
     everything downstream of a successful/failed/cancelled token result, exactly as `DeviceCalendarSource`
     already separates its pure mapping functions (danserver-testable) from the plugin call itself
     (device-only) — see `lib/data/calendar/device_calendar_source.dart`'s own doc comment,
     `[VERIFIED: read this session]`, which is the established precedent for exactly this split.

3. **UNCHANGED in substance — should `GoogleCalendarSource` ever extend to other platforms (Android,
   desktop), each needing its own separate Google Cloud client registration and its own transport
   (Android client type + custom scheme; "Desktop app" type + loopback)?**
   - What we know: this phase's Google Cloud client is iOS-specific and cannot serve any other platform
     without a new, separate registration — this was true before the pivot (a "Desktop app" client would
     have been separately needed) and remains true after it.
   - What's unclear: whether the owner wants this as a near-term follow-up.
   - Recommendation: explicitly out of scope for this phase — flag as a natural, separate future phase.

4. **NEW — introduced by this pivot, not present in the original web-scoped research: on iOS, where
   does `GoogleCalendarSource` sit relative to the EXISTING `DeviceCalendarSource`?**
   - What we know: iOS already has a working, no-OAuth calendar path (`DeviceCalendarSource`, via
     EventKit) that already reads a Google account's calendar if the user has added it at the OS level
     (`[VERIFIED: lib/data/calendar/device_calendar_source.dart:110-113 — "reads every calendar the user
     has added at the OS level — iCloud, Google, Exchange, subscribed feeds"]`). The original web-scoped
     research never had to consider this overlap, because Google-on-web and Device-on-iOS were disjoint
     platforms. **They are no longer disjoint — both now target iOS.**
   - What's unclear: does `GoogleCalendarSource` REPLACE `DeviceCalendarSource` on iOS (contradicting
     D-35-12's "one active source type per platform" unless Google explicitly supersedes Device), become
     a user-chosen ALTERNATIVE presented alongside the existing permission-CTA flow, or something else?
     CALAUTH-01's own wording ("connecting GOOGLE Calendar is a button") reads as an explicit, named,
     additional action — not a replacement of the existing "Allow calendar access" CTA — which leans
     toward "alternative, user's choice," but this is this research's own inference, not a decision
     already made anywhere in CONTEXT.md or the ROADMAP.
   - Recommendation: **flag this explicitly for the planner or the owner** rather than silently picking
     one. This research's inclination, stated with the reasoning shown, not as a locked answer: offer
     Google Sign-In as an ADDITIONAL, explicit button on the existing iOS calendar settings screen
     (`_buildMobileBody`), separate from the existing "Allow calendar access" CTA — a user who already
     grants Device access gets everything including their Google calendar with no OAuth at all; a user
     who specifically wants the read-only-enforced-by-Google guarantee (CALAUTH-02's stronger promise
     than Device access, which is read+write-capable at the OS permission level even though this app
     never calls write) can choose Google Sign-In instead. D-35-12's "one active source type" rule would
     then need a narrow, explicit carve-out for this specific pairing, stated as such rather than quietly
     violated.

## Environment Availability — REVISED

**The tailscale/port entries from the original research are removed entirely** — decision 4's reversal
makes "UAT serving does NOT move," per `36-CONTEXT.md`'s own text, and the whole tailnet-origin
consideration (including the port-8146 collision this research previously flagged as Pitfall 2) is moot
for this phase. `Pitfall 2` above is kept, struck through, rather than silently deleted.

| Dependency | Required By | Available | Version | Fallback |
|------------|--------------|-----------|---------|----------|
| Flutter SDK | Building the iOS app | ✓ | 3.44.1 (stable), Dart 3.12.1 `[VERIFIED: flutter --version, run this session via /home/dan/development/flutter/bin]` | — |
| `.google-client-id` (gitignored, owner-provided) | Any actual OAuth flow — auth, token exchange, Calendar API calls | **✓ — now exists** `[VERIFIED: cat .google-client-id, this session: 849693216860-ehc8v7i30r217tu9hd3c02cshccdigle.apps.googleusercontent.com]` — this is new since the original research pass, when it did not exist yet | — | No longer needed: the live ID is present, so the "buildable work must not gate on it" caveat from the original research is now moot for the ID itself. It still does not remove the "no Xcode on danserver" constraint below. |
| Xcode / an iOS build toolchain | Building, running, or verifying ANY part of the interactive flow | **✗ — does not exist on danserver, structurally, permanently** (pre-existing project constraint, `[VERIFIED: ROADMAP.md Phase 36 Constraints — "iOS cannot be built on danserver." — read this session]`) | — | **No fallback exists or should be invented.** All device/UAT verification is the owner's MacBook — see Pitfall 5 and Open Question 2. Everything platform-independent (mapping functions, token-refresh error classification, Hive migration) remains fully testable on danserver via `flutter test`. |
| iOS Google Cloud client registered against `com.danjjohnson.canopy` | Sign-in succeeding at all | Unconfirmed from this session — cannot be checked without Google Cloud Console access, which this research does not have | — | Owner confirms directly in Cloud Console (five-second check) — see Pitfall 4. |
| Google Calendar API enabled on the owner's Cloud project | Every API call | Unconfirmed — depends on the owner completing `36-GOOGLE-CLOUD-SETUP.md` step 2 (UNCHANGED from original research — this step didn't change in the revision) | — | The setup doc's own troubleshooting table already covers this (403 → "Calendar API not enabled") — no new fallback needed. |

**Missing dependencies with no fallback:**
- Xcode/iOS toolchain on danserver — permanent, by design, not something this phase should try to work
  around. All interactive verification is the owner's device.

**Missing dependencies with fallback:**
- None beyond what's noted above.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with the Flutter SDK, already used project-wide — no new framework) |
| Config file | none — standard `flutter test` discovery of `test/**/*_test.dart` |
| Quick run command | `flutter test test/data/calendar/google_calendar_source_test.dart test/data/calendar/google_auth_client_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map — REVISED (CALAUTH-01 row changed; others unchanged)

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| CALAUTH-01 | **REVISED.** Tapping "Connect Google Calendar" calls `flutter_appauth` with the correct `clientId`/`redirectUri` (the reversed-client-ID scheme)/`scopes`; on success, tokens are persisted; **on `FlutterAppAuthUserCancelledException`, the screen resets to the not-connected CTA with no error shown** (new case, absent from the original web-scoped test plan) | unit, via the fake `GoogleAuthLauncher` seam | `flutter test test/data/calendar/google_auth_client_test.dart` | ❌ Wave 0 |
| CALAUTH-02 | UNCHANGED. The requested scope is exactly `calendar.readonly`; no write verb exists anywhere in `GoogleCalendarSource` | unit + static (interface conformance, same proof `calendar_source.dart`'s own doc comment already relies on: `flutter analyze` confirming only read verbs) | `flutter test test/data/calendar/google_calendar_source_test.dart` | ❌ Wave 0 |
| CALAUTH-03 | UNCHANGED. A `400 invalid_grant` refresh failure sets the reconnect flag and surfaces the CTA; a network failure does NOT | unit, using injected fake `http.Client` returning a fixture matching the exact `invalid_grant` JSON body | `flutter test test/data/calendar/google_calendar_source_test.dart` | ❌ Wave 0 (fixture file also needed: `test/fixtures/calendar/google_invalid_grant.json`) |
| CALAUTH-04 | UNCHANGED in behavior, now trivially satisfied rather than merely aimed for — no secret exists to inject at all for a public iOS client. The build-fails-clearly requirement still applies to the CLIENT ID (still build-time injected, see Build-Time Injection section) | integration/manual — a build-time check, not a `flutter test` assertion | a new `tools/`-level check, exercised manually and via the build wrapper script itself | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** the quick-run command above.
- **Per wave merge:** `flutter test` (full suite) — this project's precedent (Phases 27-32) makes clear
  a green full suite is necessary but never sufficient on its own for a UI-facing phase.
- **Phase gate:** full suite green (runnable entirely on danserver), PLUS a human-driven UAT checkpoint
  on the owner's own device for the actual consent-sheet/cancel/reconnect flow — **REVISED reasoning:**
  no assertion in `flutter test` can observe a real `ASWebAuthenticationSession` sheet, and more
  fundamentally, danserver has no iOS toolchain at all to even attempt it (see Pitfall 5) — a stronger,
  structural version of the same gap the original web-scoped research flagged for headless-Chromium
  automation.

### Wave 0 Gaps — REVISED

- [ ] `test/data/calendar/google_auth_client_test.dart` — the interactive step: fake `GoogleAuthLauncher`
      returning a success `AuthorizationTokenResponse`, a fake throwing `FlutterAppAuthUserCancelledException`
      (**new — no analog in the original web-scoped test plan**), then the conversion to `AccessCredentials`;
      separately, `googleapis_auth` refresh (success and `invalid_grant` failure)
- [ ] `test/data/calendar/google_calendar_source_test.dart` — `listCalendars`/`listEvents` mapping,
      including a fixture with a moved recurring instance and a `showDeleted=true` cancelled instance
      (UNCHANGED from original research — transport-independent)
- [ ] `test/fixtures/calendar/google_events_list_recurring_moved.json` — UNCHANGED, a realistic
      `events.list` response shape, built from Google's documented field set (`recurringEventId`,
      `originalStartTime`, `status`), not a live capture (none available this session)
- [ ] `test/fixtures/calendar/google_invalid_grant.json` — UNCHANGED — `{"error": "invalid_grant",
      "error_description": "Token has been expired or revoked."}`, matching the documented/reported real
      shape
- [ ] `test/data/database/migrations_test.dart` (existing file, presumably — verify) needs a new case for
      the v11→v12 migration, following the exact precedent of the v9→v10 and v10→v11 entries already in
      `migrations.dart` (UNCHANGED)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | Yes | OAuth 2.0 Authorization Code + PKCE (this phase's whole subject) — delegated entirely to Google; Canopy never sees or stores a password |
| V3 Session Management | Yes | **REVISED:** Token stored in Hive, filesystem-backed on iOS (not IndexedDB — that was the web-specific detail; the app-level design is unchanged, only the underlying storage medium differs by platform); no cookie/session-fixation surface exists since there is no Canopy backend |
| V4 Access Control | Yes | Enforced by Google's scope grant (`calendar.readonly`), not by Canopy's own code discipline — this is explicitly the point of decision 2 (CAL-03 "enforced by Google itself") |
| V5 Input Validation | Yes | The `state` param on the auth request must be verified on return (CSRF/session-fixation protection, standard OAuth practice) — not called out elsewhere in this research, adding it here |
| V6 Cryptography | Yes | **REVISED:** PKCE `code_challenge` (SHA-256) generated internally by AppAuth-iOS via `flutter_appauth` — no longer this app's own `crypto`-package code (see Standard Stack) — still never hand-rolled hashing, just owned by a different, still-certified layer |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|------------------------|
| CSRF / authorization-code injection into the callback | Spoofing / Tampering | UNCHANGED in principle — AppAuth-iOS generates and verifies its own `state` internally as part of PKCE + the authorization request, so this app doesn't hand-roll it, but the protection is the same idea |
| ~~Client secret exposure (if Finding B forces option (a))~~ | — | **VOID.** No secret exists for an iOS-type client — the risk this row was hedging against doesn't apply. |
| Token exfiltration via a compromised app / another app reading this app's storage | Information Disclosure | **REVISED for native:** Hive on iOS is filesystem-backed inside the app's own sandbox, not IndexedDB — iOS's app-sandbox model is a materially different (generally stronger) trust boundary than a browser origin was. Worth noting as a genuine, if secondary, benefit of the pivot rather than only a cost. |
| App impersonation via the custom URL scheme (another app registering the same `com.googleusercontent.apps.<id>` scheme and intercepting the redirect) | Spoofing | This is the exact risk Google's own native-app doc cites as the reason custom schemes are "discouraged" in general (State of the Art table above). Mitigated on iOS by Apple's own app-ID/entitlement model, which governs which installed app actually receives a given URL scheme — worth confirming this app's own scheme doesn't collide with anything already registered, though a reversed Google client ID is namespaced specifically to avoid exactly this collision by construction. |

## Sources

**REVISED — new sources from this revision pass are marked `(this pass)`; everything else is from the
original 2026-09-22 session and still valid.**

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
- `developers.google.com/identity/sign-in/ios/offline-access` (this pass) — `serverAuthCode`'s
  backend-oriented design, the basis for the iOS-specific `google_sign_in` rejection
- `pub.dev/packages/flutter_appauth` (this pass) — iOS setup (`CFBundleURLTypes`), example usage
  (`authorizeAndExchangeCode`), `FlutterAppAuthUserCancelledException`
- `pub.dev/packages/flutter_appauth/example` (this pass) — confirmed no bundled Google-specific example
  exists (Duende IdentityServer is the only example shown); the redirect-URI shape and cancellation
  exception name were cross-confirmed against the README fetch instead

### Secondary (CITED — third-party, consistent across independent sources)

- `discuss.google.dev/t/authorization-code-flow-without-client-secret/168113` — Google's own developer
  forum, multiple developers reporting the Web-application-type `client_secret` requirement — **this
  finding is now independently confirmed by the owner's own investigation, not just third-party reports**
- `github.com/manfredsteyer/angular-oauth2-oidc/issues/812` — independent corroboration of the same
  `400 client_secret is missing` failure
- `nango.dev/blog/google-oauth-invalid-grant-token-has-been-expired-or-revoked` and consistent
  corroborating results (CData KB, Google AdWords API group threads) — the `400 invalid_grant` /
  `"Token has been expired or revoked."` error shape for expired/revoked refresh tokens — UNCHANGED,
  transport-independent, still the basis for the CALAUTH-03 detection code
- ~~`pub.dev/packages/flutter_web_auth_2` and `github.com/ThexXTURBOXx/flutter_web_auth_2`~~ — kept for
  history; no longer part of the recommended stack (see Standard Stack)
- Search-aggregated description of `googleapis_auth`'s `obtainAccessCredentialsViaCodeExchange` (`codeVerifier`
  param), `ClientId` (`secret` nullable), and `ServerRequestFailedException` (`statusCode`,
  `responseContent`) fields — pub.dev documentation pages, several of which 404'd directly and were
  reconstructed via search-index snippets; **flag for implementation-time confirmation by reading the
  actual installed package source**, per Assumption A3 — `ServerRequestFailedException` is now used only
  for the ongoing-refresh path, not the initial exchange, but the same caveat applies
- `github.com/MaikuB` search results (this pass) — confirmed the `dexterx.dev` publisher domain belongs
  to Michael Bui (`MaikuB`), the same person who owns the `flutter_appauth` GitHub repo — not a
  publisher/owner mismatch of the kind Phase 35 flagged for `firstfloor_calendar`

### Tertiary (repo-internal, read directly this session — `[VERIFIED]`)

- `lib/data/calendar/calendar_source.dart` — interface, all four verbs
- `lib/data/calendar/calendar_source_factory.dart` — current platform routing
- `lib/data/calendar/ics_calendar_source.dart` — `IcsFetcher` seam pattern, recurrence expansion,
  timezone handling
- `lib/data/calendar/device_calendar_source.dart` — mapping-function/adapter split pattern; **(this
  pass)** also its class doc comment describing what it already reads on iOS (relevant to Open Question 4)
- `lib/data/calendar/calendar_event.dart` — `CalendarEventStatus`, `CalendarEvent`, `CalendarInfo` shapes
- `lib/services/calendar_sync_service.dart` — `SkipReason`, mapping rules, `CalendarSyncResult`
- `lib/screens/settings/calendar_settings_screen.dart` — settings UI branch structure, CORS note
  (Google ICS specifically fails via CORS on web — direct evidence for why Google OAuth should replace,
  not merely supplement, the web ICS path)
- `lib/data/models/app_settings.dart` — existing `@HiveField` indices, additive-field pattern
- `lib/data/database/migrations.dart` — `currentSchemaVersion`, migration list invariant/assert
- `.planning/WINDOWS.md` — entry 1 (EXDATE/RDATE/RECURRENCE-ID gap), verbatim
- `tools/fetch-my-calendar.sh` — documented CORS failure for Google's own ICS URL from a browser origin
- ~~`tools/serve-pwa.py`~~ / ~~`tailscale serve status`~~ — kept for history; the pitfall they supported
  (port 8146 collision) is void under the native pivot
- `pubspec.yaml` — existing dependency versions, Dart SDK constraint (`^3.10.3`)
- **(this pass)** `ios/Runner/Info.plist` — full file read, confirmed no `CFBundleURLTypes` key present
- **(this pass)** `ios/Runner.xcodeproj/project.pbxproj` — confirmed `PRODUCT_BUNDLE_IDENTIFIER =
  com.danjjohnson.canopy` at every occurrence
- **(this pass)** `.google-client-id` — read directly, confirmed the real client ID now on disk
- **(this pass)** `git log` / `git show 33af16a` — the decision-4 reversal commit and its diff against
  `36-CONTEXT.md`/`36-GOOGLE-CLOUD-SETUP.md`, and the separate bundle-ID-rename commit `900b7c5`
- **(this pass)** `ROADMAP.md` Phase 36 Constraints — "iOS cannot be built on danserver... Any device
  verification is the owner's MacBook," the basis for Pitfall 5 and Open Question 2
- **(this pass)** `api.github.com/repos/MaikuB/flutter_appauth`,
  `api.github.com/repos/ThexXTURBOXx/flutter_web_auth_2`, `api.github.com/repos/flutter/packages` — open
  issue counts and last-push dates for the Package Legitimacy Audit

## Metadata

**REVISED confidence breakdown (native iOS transport):**
- Standard stack: MEDIUM — `flutter_appauth`'s registry facts are `[VERIFIED: pub.dev API]` and its
  README/example claims are `[CITED]` from direct fetches this pass; its exact `AuthorizationTokenRequest`
  parameter shape for `access_type`/`prompt` (Assumption A8) and whether `googleapis_auth`'s refresh
  grant accepts a null secret against an iOS-type client (Assumption A6) are both flagged for
  implementation-time confirmation, same discipline as the original pass's Assumption A3.
- Architecture: HIGH for what's transport-independent (token storage, mapping, error classification —
  all `[VERIFIED]` or `[CITED]` against this repo's own precedent, unchanged from the original pass);
  MEDIUM for the native-specific parts (`ASWebAuthenticationSession` behavior, cancellation handling) —
  corroborated by `flutter_appauth`'s own documentation but, per Pitfall 5, genuinely cannot be verified
  live from this session at all (no iOS toolchain on danserver, ever).
- Pitfalls: HIGH for Pitfall 4 (bundle-ID mismatch — directly derived from this repo's own git history
  and the setup doc's own troubleshooting table, both read this session) and Pitfall 5 (Xcode absence —
  a pre-existing, already-documented project constraint, not new information); the Finding-B-derived
  Pitfall 1 moved from MEDIUM to effectively resolved (owner-confirmed) rather than staying an open risk;
  Pitfall 2 (VOID) needs no confidence rating — it no longer applies. Pitfall 3 unchanged (HIGH,
  transport-independent).
- **Open Question 4 (factory routing on iOS between `DeviceCalendarSource` and `GoogleCalendarSource`)
  is a genuinely new, unresolved product-shape question this pivot introduced** — not present at all in
  the original web-scoped research, since Google and Device never used to target the same platform. This
  is the single largest remaining gap in this research and should be resolved (by the planner or the
  owner) before Factory Routing code is written, not discovered mid-implementation.

**Research date:** 2026-09-22 (transport sections revised 2026-09-23)
**Valid until:** ~14 days for the Google-API-specific claims (stable, slow-moving public API,
transport-independent, unaffected by this revision); the native-transport-specific claims
(`flutter_appauth`'s exact parameter shapes, cancellation-exception coverage) should be treated as
needing reconfirmation the moment implementation actually begins, since — unlike the original web plan,
where danserver itself could have verified the live flow — **no session on this machine will ever be
able to exercise this flow live**, making a real-device implementation-time check more load-bearing here
than it would be for almost any other phase in this project.
