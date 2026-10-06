# Phase 36 — Owner rulings

---

## D-36-05 — D-35-06 is REVISED: all-day events are skipped and disclosed, not imported

**Ruled 2026-10-06, at the device-UAT gate, against real calendar data.** This **supersedes D-35-06**
(`import-as-blocking`, ruled 2026-09-14). An all-day calendar entry is now **never imported**. It
appears in the skipped-events disclosure with an all-day reason. Timed events are unaffected.

**The rule, in one sentence a user can hold in their head:** timed events import; all-day events do
not.

### Why the earlier ruling was revised rather than defended

D-35-06 was decided **before anyone had seen it against a real calendar**, and `35-DECISIONS.md`
said so at the time — *"This must be confirmed by the owner in the UAT, not treated as settled."*
That confirmation has now happened and it failed. On the owner's iPhone, a 12-day window produced
**six** full-day `08:00–22:00` blocks: Vacation, a 38th Birthday, Fall break, **Payday**, Indigenous
Peoples' Day, Columbus Day. Six working days erased.

`Payday` is the entry that settles it. It is on a calendar nobody would untick, and it is **not a
commitment of time**. No amount of per-calendar filtering reaches it.

**This is explicitly NOT a duplicate of WINDOWS entry 7.** Entry 7 (ticks never reached the device
source, so every calendar imported) is a genuine bug and accounts for the holiday and birthday
calendars being present at all. But fixing entry 7 does **not** fix this: a calendar the owner
legitimately keeps ticked still contains birthdays, and `Payday` still lands. The two must be fixed
separately or entry 8 will reappear.

**The skip-and-disclose behaviour now being adopted was the original recommendation in Phase 35, and
it was declined.** It is being adopted now on evidence, not re-litigated on preference.

### The ambiguity in D-35-06 is now moot, and that is worth noting

`35-DECISIONS.md` records that D-35-06's question was malformed: its label said "full-day block", its
description said "the whole working day", and its preview rendered `08:00–18:00` while the app's real
constants are `08:00–22:00` (`ScheduleGeneratorService.dayStartMinutes`/`dayEndMinutes`). The owner
judged a 10-hour preview and shipped a 14-hour behaviour. That discrepancy was still carried as an
open UAT confirmation item. **This ruling closes it by removing the behaviour entirely** — there is no
longer a span to confirm. Do not plan work to reconcile the 10-vs-14-hour question.

### What this requires in code — and what it must NOT quietly change

- `SkipReason` gains an `allDay` member. Its doc comment currently reads *"`allDay` is deliberately
  NOT a member — D-35-06 ... means an all-day entry is imported, never skipped"* — that comment is now
  **wrong** and must be rewritten, not left standing beside contradicting code.
- `SkipReasonLabel.label` gains the all-day copy. **CORRECTED 2026-10-06 — this bullet originally said
  the string was NEW and therefore needed owner review. That was wrong, and the error would have sent a
  future agent to ask the owner for copy he had already approved.** The string already exists, locked, in
  `35-UI-SPEC.md`'s Copywriting Contract: **"All-day — not imported automatically"** (line ~160,
  "Pitfall 6"). That document's line ~303 goes further and locks the copy *for precisely this behaviour* —
  *"do not import as blocking; report via the skipped-events disclosure"* — explicitly so "the surface is
  ready either way" whichever way the then-open all-day question was ruled.
  **So Phase 35 fully specified skip-and-disclose, including its copy, and `D-35-06` then declined the
  behaviour and orphaned the string.** `D-36-05` adopts the behaviour the locked copy was always written
  for. **Reuse the string verbatim. No new copy, no checkpoint, nothing for an agent to invent.**
- `CalendarSyncService._mapEvent`'s `if (event.isAllDay)` branch returns
  `(blocks: const [], skip: SkipReason.allDay)` instead of building a working-window block.
- **`schedule_generator.dart` must not be touched.** It was byte-identical through all of Phase 36
  (git-verified) and nothing here requires it to change.
- **An existing all-day block already in Hive on the owner's device will not delete itself.** The
  six observed blocks are persisted `CommitmentBlock` records. A sync that stops *importing* all-day
  events is not the same as one that *removes* what a previous sync wrote — whether the upsert path
  prunes them must be checked on real device data, not assumed. If it does not, the owner needs either
  a migration or an explicit instruction, and the UAT must not be judged against a day still holding
  stale blocks (see CLAUDE.md trap #4).

  **ANSWERED 2026-10-06 from the code, and the answer is NO — `sync()` never prunes.** Verified three
  independent ways: `CalendarSyncService.sync()` contains no `delete` or `remove` call at all; the only
  four `.delete(` call sites in `lib/` are `restoratives_notifier`, `schedule_notifier` (×2, schedule
  re-anchoring) and the user-initiated `commitments_notifier.removeBlock` — **none in the calendar path**;
  and the codebase already admits it in a comment at `calendar_settings_screen.dart:789-791`, which
  declines to reuse the ICS dialog's *"will disappear the next time you sync"* sentence because *"that
  sentence is not true today; `sync()` only ever upserts."*
  **So the six fake blocks would survive every re-sync.** This is a real second defect, handled by this
  closure as a schema 12→13 one-time cleanup (plan `36-09`), with `isFromCalendar == false` as the
  mutation-proven survival invariant so nothing hand-entered is touched.
  **Why the cleanup clears ALL imported blocks rather than only all-day-shaped ones** — a shape-matching
  sweep cannot work: fixing WINDOWS entry 7 means the holidays and birthdays calendars **will no longer be
  queried at all**, so no event-driven or shape-driven pass could ever reach `Columbus Day` or the
  `38th Birthday`. The pre-fix set is untrustworthy on both axes this closure changes, it is derived
  data, and the next sync re-derives it exactly.
  **Accepted cost, recorded rather than buried:** for one post-upgrade **offline** check-in there are no
  last-known imported blocks to degrade to, weakening `D-35-13` for that single window.
  **A broader standing defect was found in the same reading and is NOT fixed here:** `sync()` never
  pruning means unticking a calendar, or deleting an event in the calendar app, leaves imported blocks
  forever — and `35-UI-SPEC.md`'s **locked** "Remove this calendar?" copy tells the user the opposite.
  Logged as WINDOWS entry 11, open. It is deliberately out of scope: a window-scoped prune is unsafe
  while `CompositeCalendarSource` swallows per-child failures and returns a partial list with no error
  signal, because pruning on that would delete a healthy source's blocks on a network blip.

### Options considered and rejected

| Option | Why not |
|---|---|
| Non-blocking day marker (show the title, don't consume time) | The better end state, and **not rejected on merit — deferred on size.** `CommitmentBlock` has no non-blocking concept; every field is a blocking window. Needs HiveField 9, generator changes, and a new timeline affordance. That is a phase, not gap closure. Owner chose plain skip for 36 without committing to a follow-up phase. |
| Per-calendar "all-day blocks my day" tick | Adds a second per-calendar decision on top of the import tick, and still cannot reach `Payday` on a kept calendar. |
| Keep D-35-06, untick holiday/birthday calendars | Depends entirely on entry 7 being fixed, and still blanks a day for any all-day event on a calendar the owner wants. |

**The accepted cost, stated plainly:** a genuine `Vacation` all-day entry no longer blanks its day.
The owner adds a one-off commitment, or simply does not check in. This was on screen when the ruling
was made.

**This makes WINDOWS entry 10 load-bearing rather than cosmetic.** The skipped-events disclosure is
now the *only* channel through which the owner learns his Vacation was not imported. Entry 10 records
that the disclosure exists, is tested, and he did not notice it on device. Fixing entry 8 without
entry 10 trades six visible fake blocks for one invisible omission.

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

## D-36-04 — The three pub packages are cleared for install

**Ruled 2026-09-25**, clearing `36-01` Task 1's `blocking-human` gate. The orchestrator loaded the
four pages and put the readings in front of the owner; he approved the install.

**What was on the pages on 2026-09-25** — observations, not the word "verified":

| Package | Version shown | Published | Publisher badge | Discontinued marker |
|---|---|---|---|---|
| `flutter_appauth` | 12.1.0 | 27 days ago | `dexterx.dev` | none |
| `googleapis_auth` | 2.3.4 | 7 days ago | `google.dev` | none |
| `googleapis` | 17.0.0 | 31 days ago | `google.dev` | none |

`github.com/MaikuB/flutter_appauth` showed as a standard public repository — **not** "Public archive"
— 308 stars, 84 open issues, 240 commits, owner display name `MaikuB`. `googleapis_auth` showed
1.74M downloads; `flutter_appauth` showed 379k.

**Every version is exactly what `36-RESEARCH.md` recorded**, so the ~14-day freshness horizon its
registry claims carried is satisfied by re-reading rather than by assumption. Open issues on
`flutter_appauth` are **down** from research's 102 to 84, and `googleapis_auth` downloads are **up**
from 1.6M. Nothing moved in a direction that changes the verdict.

**Two things this gate did NOT establish, recorded so the SUMMARY does not overclaim:**

1. The `googleapis` **download count was not re-read.** The "1.1k" figure on that page is the *likes*
   count; the orchestrator initially misread it as downloads and corrected itself before asking. So
   research's 1.1M/30d stands as `[CITED: pub.dev]`, not re-verified.
2. **No commit date was obtained** for `MaikuB/flutter_appauth` — the rendered page showed the commit
   *count* but not the date of the most recent one. "Not archived" is established; "has recent
   commits" rests on the repo-pushed date research recorded (2026-09-13), not on a fresh reading.

Neither gap is load-bearing for the ruling: the decisive facts are the verified publishers, the
absent discontinued markers, the unarchived repo, and versions matching research exactly.

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

**UPDATE 2026-10-06 — A1 is now VERIFIED, and this Correction therefore STANDS.** The caveat above is
resolved and is kept only as history. Proven on the owner's iPhone by reading the device's own Hive
(not by asking him what was on screen): `Canopy test` imported **twice** — `2026-10-06 09:00` (the
base occurrence) and `2026-10-13 09:10` (the single occurrence he moved, at its **new** time).
`device_calendar_plus` does return expanded occurrences with exceptions applied.

The orchestrator first logged the opposite as a bug (WINDOWS entry 9: "a moved occurrence does not
appear at all") and **withdrew it** after reading the data — it is waived with the evidence, not
deleted. Had that report been correct it would have *reversed* this Correction and made the Google
path worth materially more. It did the opposite: Google sign-in still adds **no recurrence advantage
on the device path**. What it adds remains narrower and should keep being described as such — it works
without the Google account added at OS level, and it is the login experience the owner asked for.
