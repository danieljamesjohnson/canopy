# Phase 36: Connect Google Calendar Without Hunting For a URL - Context

**Gathered:** 2026-09-22
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via `workflow.skip_discuss`)

<domain>
## Phase Boundary

Connecting the calendar Canopy schedules around is a button, not a scavenger hunt — one tap to
Google's consent screen, read-only, and back to a list of your real calendars.

**This is an input-layer phase, exactly like Phase 35.** `GoogleCalendarSource` is a **fourth
implementation** of the `CalendarSource` interface Phase 35 built, slotting into the existing
`calendar_source_factory`. The scheduling engine does not change. `schedule_generator.dart` must stay
byte-identical.

**The owner's framing, which shapes the plan's shape:** *"I think this is something that isn't gonna
be hard to get right. Scaffolding is the part that will take a while."* He is right, and the
scaffolding is **his** — the Google Cloud project lives in his account. `36-GOOGLE-CLOUD-SETUP.md`
was written and handed to him up front so it proceeds in parallel rather than blocking at the end.
**Plans must assume the client ID may not exist yet when code is written**, and must not gate
buildable work behind it.

</domain>

<decisions>
## Implementation Decisions

### Already taken — do NOT re-litigate

1. **Authorization Code + PKCE, public client, NO client secret.** Implicit flow is deprecated and
   insecure for browser apps. **This repo is public as a work sample** — a phase requiring a committed
   secret would be unshippable. The client ID is injected at build time from the gitignored
   `.google-client-id`.
2. **Read-only scope** (`calendar.readonly` or `calendar.events.readonly` — research picks which).
   This makes **CAL-03 enforced by Google**, not by our code discipline. Stronger than either existing
   path.
3. **A fourth `CalendarSource` implementation, not a rewrite.** If this phase finds itself changing
   the interface, that is a signal something is wrong.
4. **NATIVE iOS client with a custom URI scheme. REVISED 2026-09-22 — reverses the original
   decision 4.** Google's *Web application* client is confidential and will not do a secret-free PKCE
   exchange; a browser page cannot hold a secret. Owner ruled **build it native**. Google: *"the
   `client_secret` is not applicable to ... iOS"* and *"refresh tokens are always returned for
   installed applications."*
   - Cloud Console registers an **iOS** client keyed on **bundle ID**. No redirect URI or JS origins.
   - Redirect is the reversed client ID, registered via `CFBundleURLTypes` in `Info.plist` (which
     currently has **no** `CFBundleURLTypes` key at all — it must be added).
   - **The tailnet HTTPS origin is irrelevant. UAT serving does NOT move.**
   - **The button will NOT exist in the hosted browser build.** Accepted cost, not an oversight.
     Browser keeps Phase 35's `.ics` path.
   - `google_sign_in`'s web flow was rejected on evidence: no refresh token, ~1 hour expiry, i.e.
     hourly re-consent — worse than the accepted 7-day cadence.
   - Bundle ID is still `com.example.canopy` and the OAuth client binds to it; surfaced to the owner
     as an explicit choice rather than decided silently.
5. **Google only. Apple is unaffected and unaddressed.** No equivalent public OAuth calendar API
   exists for Apple. **Do not attempt CalDAV with app-specific passwords.**

### The 7-day expiry — RULED and ACCEPTED, not a discovery

Google expires refresh tokens after **7 days** for apps in *Testing* publishing status. The owner was
shown this explicitly, with the cheaper no-expiry alternative offered alongside, and **chose to build
this anyway**. That is an informed override.

**Do not treat the expiry as a blocker mid-phase, and do not quietly pursue Google verification.**
What the phase must do is make it **degrade visibly** — CALAUTH-03. A silently stale calendar is the
failure mode that makes someone stop trusting the app, which is the same reasoning behind CAL-04.

The declined fallback — cron `tools/fetch-my-calendar.sh` hourly (no expiry, no consent screen, covers
Apple too) — remains available if verification proves unworkable. It is not deleted.

### Claude's discretion

Everything not fixed above. Discuss was skipped per `workflow.skip_discuss`.

</decisions>

<code_context>
## Existing Code Insights

Phase 35 built the machinery this extends. Read it before designing anything:

- **`lib/data/calendar/calendar_source.dart`** — the interface. Four read verbs, no write verb. Its
  shape is the whole reason this phase is an added class rather than a migration.
- **`lib/data/calendar/calendar_source_factory.dart`** — platform routing. Currently: iOS →
  `DeviceCalendarSource`; Android/web/desktop → `IcsCalendarSource`; otherwise `NullCalendarSource`.
  Google sign-in must slot in here, and the **fallback order matters** (see open question 4).
- **`lib/data/calendar/ics_calendar_source.dart`** — closest analog for a network-fetching source,
  including its `IcsFetcher` injection seam, which is how its tests avoid real HTTP.
- **`lib/services/calendar_sync_service.dart`** — the mapping layer. Event → `CommitmentBlock`. Every
  rule (all-day, cancelled, too-short, multi-day, overlap, timezones) already lives here and is
  proven. **A Google source should produce `CalendarEvent`s and reuse all of it.**
- **`lib/screens/settings/calendar_settings_screen.dart`** — the surface. Already has the three-state
  permission flow for iOS and the feed-URL flow for web/desktop. The Google button belongs here.
- **`lib/data/models/app_settings.dart`** — `selectedCalendarIds`, `icsUrls`, `lastCalendarSyncAt`
  already persist. Schema is at **11**; a token store is a further additive migration.
- **`lib/data/database/migrations.dart`** — all existing migrations are comment-only no-ops for
  additive nullable/defaulted fields. **Phase 35 found a real crash-on-upgrade** when a `List<String>`
  field lacked `@HiveField(defaultValue:)`; that lesson applies directly to any new token field.

</code_context>

<specifics>
## Specific Ideas

### Requirements

- **CALAUTH-01** — connecting Google Calendar is a button, not a manual URL hunt
- **CALAUTH-02** — Canopy holds a read-only Google token and cannot write, enforced by scope
- **CALAUTH-03** — an expired or revoked token degrades **visibly** with a one-tap reconnect, never a
  silently stale calendar
- **CALAUTH-04** — no client secret exists in the repository

### Open questions for research

1. **Which package, or none?** `google_sign_in` web support, `oauth2`, `flutter_appauth`, or a
   hand-rolled PKCE flow. **Weigh against Phase 35's own lesson:** a load-bearing path behind a
   low-adoption package is not defensible on a public repo — `firstfloor_calendar` was rejected on
   exactly that (52 weekly downloads, publisher/owner mismatch).
2. **Does this close `WINDOWS.md` entry 1 for the Google path?** Google's `events.list` supports
   `singleEvents=true`, documented to expand recurrences **with exceptions applied**. If true, a moved
   or deleted occurrence resolves correctly here — the defect the ICS path **provably cannot fix**
   (proven in 35-02 against the real stack). **Verify against the real API, not the docs.** If it
   holds, say so loudly: it changes which path the owner should prefer.
3. **Token storage and refresh.** Hive, like the rest of the app's persistence. What exactly does the
   7-day revocation look like on the wire — the error shape is what CALAUTH-03's visible degradation
   keys off.
4. **Factory fallback order.** iOS already has the device path; desktop has `.ics`. Where does Google
   sit relative to each, and does anything regress?

### Traps this phase is exposed to

- **CLAUDE.md trap #4** — any UAT judging generated days must ⟳ Re-check-in first, stated as its own
  mandatory first step.
- **Assertions that cannot fail** — mutation-prove load-bearing assertions. A compile error is not
  red. Phase 35 found two real crash bugs this way that no plan anticipated.
- **A test that passes for the wrong reason** — an OAuth test that never exercises the expiry path
  proves nothing about CALAUTH-03, which is the requirement most likely to be assumed rather than
  demonstrated.
- **The client ID may be absent at build time.** Code and tests must not require it. A build without
  `.google-client-id` should fail *clearly and early*, not produce a broken sign-in button.

</specifics>

<deferred>
## Deferred Ideas

- **Google verification / publishing the consent screen** — explicitly not now. The 7-day expiry is
  accepted instead.
- **Apple Calendar OAuth / CalDAV** — no public API; ruled out in the ROADMAP.
- **Writing to the user's calendar** — permanently out of scope, CAL-03.
- **Cron'ing `fetch-my-calendar.sh`** — the declined cheaper alternative; retained as a fallback.

</deferred>
