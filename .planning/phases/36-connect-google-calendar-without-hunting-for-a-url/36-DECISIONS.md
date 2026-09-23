# Phase 36 — Owner rulings

---

## D-36-01 — Build it native, not in the browser

**Ruled 2026-09-22.** The phase was originally scoped as a browser PKCE flow. That premise died on
contact with Google: the **Web application** client type is a *confidential* client that will not
complete a secret-free exchange, and a browser page cannot hold a secret — it ships in the bundle.

The owner asked the clarifying question that resolved it: *"when I login to google on an app, how
does that work? Is that OAuth? I just want that."* The answer is that the familiar experience is a
**native** flow, and Google supports it explicitly — *"the `client_secret` is **not applicable** to
requests from clients registered as Android, iOS, or Chrome applications"*, and *"refresh tokens are
**always** returned for installed applications."*

**Accepted cost, stated plainly:** the sign-in button will **not** exist in the hosted browser build
at `danserver:8161`. The browser keeps Phase 35's `.ics` path. The owner cannot see this feature
without building on his MacBook.

---

## D-36-02 — Bundle ID renamed to `com.danjjohnson.canopy`

**Ruled 2026-09-23.** The OAuth client binds to the bundle ID, so renaming first means registering
once rather than registering against the `com.example` placeholder and re-registering later.
`STATE.md` had carried `com.example.canopy` as a known App Store blocker since Phase 35; this closes
it. Done repo-wide (iOS, macOS, Android namespace + applicationId + Kotlin package directory, Linux),
plus the macOS and Windows copyright strings that still literally read `com.example` and would have
shipped inside built binaries.

**Not verifiable here.** No Xcode, no Android SDK. `flutter analyze` clean and 821/821 green is the
extent of the proof; the first Mac build is what confirms the Xcode project still resolves.

---

## D-36-03 — Both iOS sources coexist; the user ticks per calendar

**Ruled 2026-09-23, AGAINST the recommendation, with the failure mode on screen.**

On iOS there are now two routes to the same Google calendar: the **device** source (no login, shipped
in Phase 35, reads the OS store which already aggregates Google) and the new **Google** source. The
options put to the owner were: signing in *replaces* the device source; **both coexist and the user
picks per calendar**; or device stays default with sign-in opt-in.

He chose **both**, having been shown the exact footgun in the option's own preview: ticking the same
underlying calendar from both sources yields **every meeting twice**.

**Why it is defensible despite the risk:** it is the only option that keeps device-only calendars
(iCloud Personal, a local calendar, a subscribed feed added at OS level) reachable while signed in to
Google. Replace-on-sign-in would silently drop them — a quieter but arguably worse failure, because
the user would not know what went missing.

### The mitigation that keeps this ruling honest — REQUIRED, not optional

This is the same shape as Phase 34's D-(a) ruling, and the precedent is recorded in `STATE.md`:

> *"(a)'s danger is not that a default exists, it is that the default is **invisible**. The 'help'
> goal became a three-hour weekly commitment because nothing on screen ever said so."*

Here: **the danger is not that both sources exist, it is that double-ticking is invisible until the
day comes back doubled.** A user who ticks `dan@gmail.com` under GOOGLE and `dan@gmail.com` under
THIS DEVICE has, from the UI's point of view, done nothing unusual — two different rows, two
different groups, both legitimately tickable.

**So the phase must make the overlap visible at the moment of ticking**, not after a check-in:

- Detect when a calendar selected under one source plausibly refers to the same underlying calendar
  as one selected under the other. Google exposes calendar IDs that are email-shaped; the device
  source exposes an account name. **Research must settle how reliably these can be matched** — and if
  matching is unreliable, say so rather than shipping a detector that misses.
- When an overlap is selected, **say so on the picker itself**, in the UI-SPEC's voice: plain,
  non-alarming, naming the consequence ("these may be the same calendar — events could appear
  twice"). Not an error, not a block. The owner chose this configuration and must remain able to
  make it.
- **Do not silently de-duplicate.** Quietly dropping one side would contradict the ruling and hide a
  state the user deliberately created. Make it visible; let him decide.

**If reliable matching turns out to be impossible**, that is a finding to report, not to paper over —
and the fallback is a general note on the picker rather than a per-row detector that fires wrongly. A
detector that cries wolf is worse than none.

### What the UAT must ask

The owner must be shown a real double-tick on a real device and asked whether the warning reads
clearly enough to stop him doing it by accident. This cannot be settled by a widget test — it is a
perceptual judgment, the class this project's green suites have missed repeatedly.

---

## Correction on the record — the recurrence advantage does NOT apply to the device path

Earlier in this phase the orchestrator told the owner that the Google path "fixes the
duplicate-meeting bug the ICS path provably cannot." **That is true of the `.ics` path and NOT of the
device path**, and the distinction was not made clearly at first.

Phase 35's research (Assumption A1) records that `device_calendar_plus.listEvents()` returns
**already-expanded per-occurrence instances with exceptions applied**. So on iOS the device source is
expected to handle moved and deleted occurrences correctly already, and Google sign-in adds **no
recurrence advantage there**.

What sign-in actually adds on iOS is narrower and should be described as such: it works **without**
the Google account being added at OS level, and it is the login experience the owner asked for. The
recurrence fix remains a genuine advantage over the **`.ics`** path only — which is what the browser
and Android use.

**Note the caveat on the caveat:** A1 is itself marked in Phase 35's research as *"the single most
load-bearing claim in the whole phase... must be the first thing verified on a real device"* — and it
has **not** been verified, because `35-05`'s device gate is still open. So "the device path already
handles this" is an expectation, not an established fact.
